<#
.SYNOPSIS
    pc-optimizer · Fase 2: software, arranque y consumo.

.DESCRIPTION
    SOLO LECTURA. No desactiva, desinstala ni detiene nada.
    Recolecta:
      - Programas de inicio (registro Run, carpetas Startup) con su estado habilitado/deshabilitado.
      - Tareas programadas de terceros que corren al iniciar sesión o al arrancar.
      - Servicios automáticos de terceros.
      - Procesos que más RAM y CPU consumen (agrupados por nombre).
      - Antivirus registrados en el Centro de seguridad.
      - Software instalado que coincide con patrones conocidos (references/bloatware.md).
    Genera "hallazgos" ordenados por severidad.

    Sin administrador. Compatible con Windows PowerShell 5.1 y PowerShell 7+.

.PARAMETER OutFile
    Ruta donde guardar el JSON. Por defecto: $env:TEMP\pc-optimizer\software.json

.PARAMETER SegundosMuestreo
    Segundos entre las dos lecturas de CPU por proceso (default 3).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\software.ps1
#>
[CmdletBinding()]
param(
    [string]$OutFile = (Join-Path $env:TEMP 'pc-optimizer\software.json'),
    [int]$SegundosMuestreo = 3,
    [int]$TopProcesos = 15
)

$ErrorActionPreference = 'Stop'
# Si algo se escapa de Invoke-Seguro, reportar la línea exacta en vez de un error genérico.
trap {
    Write-Error ("software.ps1 falló en la línea {0}: {1}`n{2}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message, $_.InvocationInfo.Line.Trim())
    break
}
$script:errores   = New-Object System.Collections.Generic.List[string]
$script:hallazgos = New-Object System.Collections.Generic.List[object]
$script:limites   = New-Object System.Collections.Generic.List[string]

# ---------------------------------------------------------------- helpers
function Invoke-Seguro {
    param([string]$Nombre, [scriptblock]$Bloque)
    try { & $Bloque }
    catch { $script:errores.Add("${Nombre}: $($_.Exception.Message)"); $null }
}

function Add-Hallazgo {
    param(
        [ValidateSet('Critica','Alta','Media','Baja','Info')][string]$Severidad,
        [string]$Codigo, [string]$Detalle, [string]$Recomendacion
    )
    $script:hallazgos.Add([ordered]@{
        severidad = $Severidad; codigo = $Codigo; detalle = $Detalle; recomendacion = $Recomendacion
    })
}

function ConvertTo-MB { param($Bytes) if ($null -eq $Bytes) { return $null }; [math]::Round([double]$Bytes / 1MB, 0) }

# Extrae la ruta del ejecutable de una línea de comando ("C:\x y\a.exe" -arg  |  C:\a.exe /arg)
function Get-RutaEjecutable {
    param([string]$Comando)
    if (-not $Comando) { return $null }
    $c = [Environment]::ExpandEnvironmentVariables($Comando.Trim())
    if ($c -match '^"([^"]+)"') { return $Matches[1] }
    if ($c -match '^(.+?\.(exe|com|bat|cmd|lnk|dll))(\s|,|$)') { return $Matches[1] }
    return ($c -split '\s+')[0]
}

function Get-Empresa {
    param([string]$Ruta)
    if (-not $Ruta) { return $null }
    try {
        if (Test-Path -LiteralPath $Ruta -PathType Leaf) { return (Get-Item -LiteralPath $Ruta).VersionInfo.CompanyName }
    } catch { }
    return $null
}

# ---------------------------------------------------------------- patrones (mantener en sincronía con references/bloatware.md)
$patrones = @(
    # Antivirus de prueba / promocionales
    @{ cat = 'antivirus_prueba';  sev = 'Media'; re = 'McAfee(?!.*WebAdvisor)|Norton(?!.*Safe Web)|TotalAV|Total AV|Avast Free|AVG AntiVirus Free|Avira Security'
       nota = 'Antivirus que suele venir de prueba o promocional. Windows Defender es suficiente para la mayoría; tener dos antivirus activos degrada el rendimiento.' }
    # "Optimizadores" y limpiadores
    @{ cat = 'optimizador';       sev = 'Media'; re = 'CCleaner|Advanced SystemCare|IObit|Driver Booster|Driver Easy|DriverPack|Reimage|Restoro|PC Accelerate|Wise Care|Glary Utilities|Auslogics|WinOptimizer|Fortect|Outbyte'
       nota = 'Los limpiadores de registro y "aceleradores" no mejoran el rendimiento real; varios corren en segundo plano o instalan software adicional.' }
    # Utilidades del fabricante pesadas (gaming/RGB)
    @{ cat = 'utilidad_fabricante_pesada'; sev = 'Baja'; re = 'Armoury Crate|MSI Center|Dragon Center|OMEN Gaming Hub|Alienware Command Center|Corsair iCUE|NZXT CAM|Razer Synapse|Razer Cortex|Lenovo Legion Zone'
       nota = 'Controla ventiladores, RGB o perfiles de energía: NO desinstalar a ciegas. Revisar si se usa y qué servicios deja corriendo.' }
    # Utilidades de soporte del fabricante
    @{ cat = 'utilidad_soporte';  sev = 'Info'; re = 'SupportAssist|HP Support Assistant|HP Wolf|Lenovo Vantage|MyASUS|Acer Care Center|Dell Update|HP Smart'
       nota = 'Útil para drivers y BIOS. Se puede quitar del inicio si se actualiza manualmente.' }
    # Promocional / adware leve
    @{ cat = 'promocional';       sev = 'Baja'; re = 'WildTangent|McAfee WebAdvisor|Norton Safe Web|Avast Secure Browser|AVG Secure Browser|Ask Toolbar|Conduit|Bing Bar|Booking\.com|ExpressVPN.*Trial'
       nota = 'Software promocional preinstalado o instalado de rebote con otro programa.' }
)
# Apps de la Store promocionales (nombre de paquete)
$patronAppx = 'king\.com|Disney|BytedancePte|TikTok|Facebook|Instagram|AmazonVideo|PrimeVideo|LinkedIn|Clipchamp|BubbleWitch|CandyCrush|Hulu'

function Find-Patron {
    param([string]$Texto)
    if (-not $Texto) { return $null }
    foreach ($p in $patrones) { if ($Texto -match $p.re) { return $p } }
    return $null
}

# ---------------------------------------------------------------- contexto
$os = Invoke-Seguro 'os' { Get-CimInstance Win32_OperatingSystem }
$ramTotalBytes = if ($os) { [double]$os.TotalVisibleMemorySize * 1KB } else { $null }
$hilos = (Get-CimInstance Win32_Processor | Measure-Object NumberOfLogicalProcessors -Sum).Sum
if (-not $hilos) { $hilos = [Environment]::ProcessorCount }

# ---------------------------------------------------------------- programas de inicio
# Estado según Explorer\StartupApproved (lo mismo que muestra el Administrador de tareas):
# primer byte par = habilitado, impar = deshabilitado. Sin entrada = habilitado.
function Get-Aprobados {
    param([string]$Raiz)
    $r = @{}
    foreach ($sub in 'Run', 'Run32', 'StartupFolder') {
        $k = "$Raiz\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\$sub"
        $p = Get-ItemProperty $k -ErrorAction SilentlyContinue
        if (-not $p) { continue }
        foreach ($prop in $p.PSObject.Properties) {
            if ($prop.Name -like 'PS*') { continue }
            $bytes = $prop.Value
            # [int] explícito: en Windows PowerShell 5.1, [byte] -band [int] lanza "Los tipos de argumentos no coinciden".
            if ($bytes -is [byte[]] -and $bytes.Length -gt 0) { $r["$sub|$($prop.Name)"] = ((([int]$bytes[0]) -band 1) -eq 0) }
        }
    }
    $r
}
$aprobadosHKCU = Invoke-Seguro 'inicio_aprobados_HKCU' { Get-Aprobados 'HKCU:' }
$aprobadosHKLM = Invoke-Seguro 'inicio_aprobados_HKLM' { Get-Aprobados 'HKLM:' }
if (-not $aprobadosHKCU) { $aprobadosHKCU = @{} }
if (-not $aprobadosHKLM) { $aprobadosHKLM = @{} }

$inicio = New-Object System.Collections.Generic.List[object]

$fuentesRun = @(
    @{ ruta = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';             ambito = 'Usuario';  sub = 'Run';   aprob = $aprobadosHKCU }
    @{ ruta = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run';             ambito = 'Equipo';   sub = 'Run';   aprob = $aprobadosHKLM }
    @{ ruta = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; ambito = 'Equipo';   sub = 'Run32'; aprob = $aprobadosHKLM }
)
foreach ($f in $fuentesRun) {
    Invoke-Seguro "inicio_$($f.ruta)" {
        $p = Get-ItemProperty $f.ruta -ErrorAction SilentlyContinue
        if (-not $p) { return }
        foreach ($prop in $p.PSObject.Properties) {
            if ($prop.Name -like 'PS*') { continue }
            $clave = "$($f.sub)|$($prop.Name)"
            $hab = if ($f.aprob.ContainsKey($clave)) { $f.aprob[$clave] } else { $true }
            $exe = Get-RutaEjecutable ([string]$prop.Value)
            $inicio.Add([ordered]@{
                nombre = $prop.Name; origen = "Registro ($($f.ambito))"; habilitado = $hab
                comando = [string]$prop.Value; empresa = Get-Empresa $exe
            })
        }
    } | Out-Null
}

$carpetas = @(
    @{ ruta = [Environment]::GetFolderPath('Startup');       ambito = 'Usuario'; aprob = $aprobadosHKCU }
    @{ ruta = [Environment]::GetFolderPath('CommonStartup'); ambito = 'Equipo';  aprob = $aprobadosHKLM }
)
foreach ($c in $carpetas) {
    Invoke-Seguro "inicio_carpeta_$($c.ambito)" {
        if (-not $c.ruta -or -not (Test-Path $c.ruta)) { return }
        Get-ChildItem $c.ruta -File | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
            $clave = "StartupFolder|$($_.Name)"
            $hab = if ($c.aprob.ContainsKey($clave)) { $c.aprob[$clave] } else { $true }
            $inicio.Add([ordered]@{
                nombre = $_.BaseName; origen = "Carpeta Inicio ($($c.ambito))"; habilitado = $hab
                comando = $_.FullName; empresa = $null
            })
        }
    } | Out-Null
}
$script:limites.Add('Las apps de la Microsoft Store que arrancan con Windows (p. ej. Teams nuevo, Spotify Store) no se listan aquí; revisarlas en Configuración > Aplicaciones > Inicio.')

# ---------------------------------------------------------------- tareas programadas de terceros al inicio
$tareas = @(Invoke-Seguro 'tareas' {
    Get-ScheduledTask | Where-Object {
        $_.State -ne 'Disabled' -and $_.TaskPath -notlike '\Microsoft\*'
    } | ForEach-Object {
        $t = $_
        $tiposTrigger = @($t.Triggers | ForEach-Object { $_.CimClass.CimClassName })
        $alInicio = @($tiposTrigger | Where-Object { $_ -in 'MSFT_TaskLogonTrigger', 'MSFT_TaskBootTrigger' }).Count -gt 0
        if ($alInicio) {
            $accion = $t.Actions | Select-Object -First 1
            [ordered]@{
                nombre   = $t.TaskName
                ruta     = $t.TaskPath
                estado   = [string]$t.State
                disparo  = (($tiposTrigger | ForEach-Object { $_ -replace '^MSFT_Task|Trigger$', '' }) -join ', ')
                ejecuta  = if ($accion) { $accion.Execute } else { $null }
                autor    = $t.Author
            }
        }
    }
})
$tareas = @($tareas | Where-Object { $_ })

# ---------------------------------------------------------------- servicios automáticos de terceros
$servicios = @(Invoke-Seguro 'servicios' {
    Get-CimInstance Win32_Service -Filter "StartMode='Auto'" | ForEach-Object {
        $exe = Get-RutaEjecutable $_.PathName
        $enWindows = $exe -and $env:windir -and $exe.StartsWith($env:windir, [StringComparison]::OrdinalIgnoreCase)
        if ($enWindows) { return }   # svchost y binarios del sistema
        $empresa = Get-Empresa $exe
        if ($empresa -match 'Microsoft') { return }
        [ordered]@{
            nombre    = $_.Name
            mostrado  = $_.DisplayName
            estado    = $_.State
            empresa   = $empresa
            ejecutable = $exe
        }
    }
})
$servicios = @($servicios | Where-Object { $_ })

# ---------------------------------------------------------------- procesos
$porRam = @(Invoke-Seguro 'procesos_ram' {
    Get-Process | Group-Object ProcessName | ForEach-Object {
        $ws = ($_.Group | Measure-Object WorkingSet64 -Sum).Sum
        [pscustomobject]@{ nombre = $_.Name; instancias = $_.Count; ram_mb = ConvertTo-MB $ws
                           ram_pct = if ($ramTotalBytes) { [math]::Round($ws / $ramTotalBytes * 100, 1) } else { $null } }
    } | Sort-Object ram_mb -Descending | Select-Object -First $TopProcesos
})

# CPU actual: la clase formateada calcula entre dos consultas; la primera se descarta.
$porCpu = @(Invoke-Seguro 'procesos_cpu' {
    $null = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process
    Start-Sleep -Seconds $SegundosMuestreo
    Get-CimInstance Win32_PerfFormattedData_PerfProc_Process |
        Where-Object { $_.Name -ne '_Total' -and $_.Name -ne 'Idle' } |
        ForEach-Object { [pscustomobject]@{ nombre = ($_.Name -replace '#\d+$', ''); cpu = [double]$_.PercentProcessorTime } } |
        Group-Object nombre | ForEach-Object {
            [pscustomobject]@{ nombre = $_.Name; instancias = $_.Count
                               cpu_pct = [math]::Round((($_.Group | Measure-Object cpu -Sum).Sum) / $hilos, 1) }
        } | Where-Object { $_.cpu_pct -gt 0 } | Sort-Object cpu_pct -Descending | Select-Object -First $TopProcesos
})

# ---------------------------------------------------------------- memoria reservada (commit)
# La RAM en uso (working set) no explica la memoria comprometida: un proceso puede reservar mucho y tener poco en RAM.
# PrivateMemorySize64 = "Tamaño de confirmación" del Administrador de tareas.
$procesosTodos = @(Invoke-Seguro 'procesos_lista' { Get-Process })
$totalPrivadaBytes = [double](($procesosTodos | Measure-Object PrivateMemorySize64 -Sum).Sum)
$porPrivada = @(Invoke-Seguro 'procesos_privada' {
    $procesosTodos | Group-Object ProcessName | ForEach-Object {
        [pscustomobject]@{ nombre = $_.Name; instancias = $_.Count
                           reservada_mb = ConvertTo-MB (($_.Group | Measure-Object PrivateMemorySize64 -Sum).Sum) }
    } | Sort-Object reservada_mb -Descending | Select-Object -First $TopProcesos
})

$perfMem = Invoke-Seguro 'memoria_commit' { Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory }
$commitBytes = if ($perfMem) { [double]$perfMem.CommittedBytes } else { $null }
$commitLimite = if ($perfMem) { [double]$perfMem.CommitLimit } else { $null }
$commitPct = if ($commitBytes -and $commitLimite) { [math]::Round($commitBytes / $commitLimite * 100, 0) } else { $null }
$sinAtribuirGB = if ($commitBytes) { [math]::Round(($commitBytes - $totalPrivadaBytes) / 1GB, 1) } else { $null }

# WSL 2 / Docker: la VM reserva memoria del host. Sin límite en .wslconfig puede tomar hasta el 50% de la RAM.
$wslCorriendo = @($procesosTodos | Where-Object { $_.ProcessName -like 'vmmem*' }).Count -gt 0
$wslConfigRuta = Join-Path $env:USERPROFILE '.wslconfig'
$wslLimite = $null
if (Test-Path -LiteralPath $wslConfigRuta) {
    Invoke-Seguro 'wslconfig' {
        foreach ($linea in Get-Content -LiteralPath $wslConfigRuta) {
            if ($linea -match '^\s*memory\s*=\s*(\S+)') { $script:wslLimite = $Matches[1] }
        }
    } | Out-Null
}

$memoria = [ordered]@{
    comprometida_gb        = if ($commitBytes) { [math]::Round($commitBytes / 1GB, 1) } else { $null }
    limite_gb              = if ($commitLimite) { [math]::Round($commitLimite / 1GB, 1) } else { $null }
    comprometida_pct       = $commitPct
    reservada_procesos_gb  = [math]::Round($totalPrivadaBytes / 1GB, 1)
    sin_atribuir_gb        = $sinAtribuirGB   # VMs (WSL/Hyper-V), drivers y kernel
    wsl_corriendo          = $wslCorriendo
    wslconfig_existe       = (Test-Path -LiteralPath $wslConfigRuta)
    wsl_limite_memoria     = $wslLimite
}

# ---------------------------------------------------------------- antivirus (Centro de seguridad)
$antivirus = @(Invoke-Seguro 'antivirus' {
    Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct | ForEach-Object {
        $hex = '{0:x6}' -f [int]$_.productState
        [ordered]@{
            nombre        = $_.displayName
            activo        = ($hex.Substring(2, 2) -in '10', '11')
            actualizado   = ($hex.Substring(4, 2) -eq '00')
            estado_hex    = $hex
        }
    }
})
$antivirus = @($antivirus | Where-Object { $_ })
if ($antivirus.Count -eq 0) { $script:limites.Add('No se pudo leer el Centro de seguridad (normal en Windows Server).') }

# ---------------------------------------------------------------- software instalado
$instalado = @(Invoke-Seguro 'instalado' {
    $claves = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    Get-ItemProperty $claves -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 -and -not $_.ParentKeyName } |
        Sort-Object DisplayName -Unique |
        ForEach-Object {
            [pscustomobject]@{
                nombre     = $_.DisplayName
                editor     = $_.Publisher
                version    = $_.DisplayVersion
                instalado  = $_.InstallDate
                tamano_mb  = if ($_.EstimatedSize) { [math]::Round([double]$_.EstimatedSize / 1KB, 0) } else { $null }
            }
        }
})
$instalado = @($instalado | Where-Object { $_ })

$coincidencias = @($instalado | ForEach-Object {
    $p = Find-Patron "$($_.nombre) $($_.editor)"
    if ($p) {
        [ordered]@{ nombre = $_.nombre; editor = $_.editor; categoria = $p.cat; severidad = $p.sev; nota = $p.nota }
    }
})

$appxPromo = @(Invoke-Seguro 'appx' {
    Get-AppxPackage | Where-Object { $_.Name -match $patronAppx -and -not $_.IsFramework } |
        ForEach-Object { [ordered]@{ paquete = $_.Name; editor = $_.Publisher -replace '^CN=([^,]+).*', '$1' } }
})
$appxPromo = @($appxPromo | Where-Object { $_ })

# ================================================================ hallazgos
# 1. Antivirus
$avActivos = @($antivirus | Where-Object { $_.activo })
$avTerceros = @($avActivos | Where-Object { $_.nombre -notmatch 'Defender' })
if ($avTerceros.Count -ge 2) {
    Add-Hallazgo 'Alta' 'VARIOS_ANTIVIRUS' "Hay $($avTerceros.Count) antivirus de terceros activos: $(($avTerceros | ForEach-Object { $_.nombre }) -join ', ')." `
        'Dejar uno solo. Dos motores escaneando a la vez multiplican el uso de disco y CPU.'
}
foreach ($av in $antivirus) {
    if ($av.activo -and -not $av.actualizado) {
        Add-Hallazgo 'Media' 'ANTIVIRUS_DESACTUALIZADO' "El antivirus '$($av.nombre)' reporta firmas desactualizadas." `
            'Si es una prueba vencida, desinstalarlo para que Windows Defender vuelva a protegerse solo.'
    }
}
if ($avActivos.Count -eq 0 -and $antivirus.Count -gt 0) {
    Add-Hallazgo 'Alta' 'SIN_ANTIVIRUS_ACTIVO' 'Ningún antivirus aparece activo en el Centro de seguridad.' `
        'Revisar Seguridad de Windows. No es un problema de rendimiento, pero sí de riesgo.'
}

# 2. Programas de inicio
$inicioHab = @($inicio | Where-Object { $_.habilitado })
if ($inicioHab.Count -ge 10) {
    Add-Hallazgo 'Media' 'MUCHOS_PROGRAMAS_INICIO' "$($inicioHab.Count) programas arrancan con Windows." `
        'Deshabilitar en Administrador de tareas > Aplicaciones de arranque los que no se usen a diario (deshabilitar no desinstala).'
}
elseif ($inicioHab.Count -ge 6) {
    Add-Hallazgo 'Baja' 'PROGRAMAS_INICIO' "$($inicioHab.Count) programas arrancan con Windows." `
        'Revisar la lista y deshabilitar los que no se usen a diario.'
}

# 3. Software por patrón
foreach ($grupo in ($coincidencias | Group-Object { $_.categoria })) {
    $muestra = $grupo.Group[0]
    $nombres = ($grupo.Group | ForEach-Object { $_.nombre }) -join ', '
    $rec = switch ($muestra.categoria) {
        'antivirus_prueba' { 'Confirmar si tiene licencia paga. Si no, desinstalarlo desde Configuración > Aplicaciones (y la herramienta de borrado del fabricante si deja restos).' }
        'optimizador'      { 'Desinstalar. Revisar después si dejó navegadores, barras o "drivers updaters" adicionales.' }
        'utilidad_fabricante_pesada' { 'Preguntar al usuario si la usa. Si solo controla RGB, quitarla del inicio; si controla ventiladores/energía, mantenerla.' }
        'utilidad_soporte' { 'Mantener o quitar del inicio; no desinstalar si es la vía de actualización de BIOS/drivers.' }
        default            { 'Desinstalar si el usuario no lo reconoce como propio.' }
    }
    Add-Hallazgo $muestra.severidad ('SW_' + $muestra.categoria.ToUpper()) "$($muestra.nota) Encontrado: $nombres." $rec
}
if ($appxPromo.Count -gt 0) {
    Add-Hallazgo 'Baja' 'APPS_STORE_PROMO' "Apps promocionales de la Store: $(($appxPromo | ForEach-Object { $_.paquete }) -join ', ')." `
        'Desinstalar las que el usuario no use. Liberan poco espacio; el beneficio es menos ruido y notificaciones.'
}

# 4. Procesos
if ($porRam.Count -gt 0 -and $porRam[0].ram_pct -ge 25) {
    $top = $porRam[0]
    Add-Hallazgo 'Info' 'PROCESO_RAM_ALTA' "'$($top.nombre)' ($($top.instancias) procesos) usa $($top.ram_mb) MB ($($top.ram_pct)% de la RAM)." `
        'Normal en navegadores con muchas pestañas o IDEs. Si no se esperaba, investigar.'
}
$cpuAlto = @($porCpu | Where-Object { $_.cpu_pct -ge 20 })
foreach ($p in $cpuAlto) {
    Add-Hallazgo 'Info' 'PROCESO_CPU_ALTA' "'$($p.nombre)' estaba usando $($p.cpu_pct)% del CPU durante el muestreo." `
        'Si es un proceso de fondo (indexado, antivirus, actualizador) y el equipo estaba en reposo, revisarlo.'
}

if ($porPrivada.Count -gt 0 -and $commitPct -ge 85) {
    $top3 = ($porPrivada | Select-Object -First 3 | ForEach-Object { "$($_.nombre) $([math]::Round($_.reservada_mb / 1024, 1)) GB" }) -join ', '
    Add-Hallazgo 'Info' 'MAYOR_MEMORIA_RESERVADA' "Procesos que más memoria reservan: $top3." `
        'Esta es la memoria que cuenta para el límite de commit, aunque no esté toda en RAM.'
}
if ($wslCorriendo -and -not $wslLimite) {
    $sev = if ($commitPct -ge 85) { 'Alta' } else { 'Baja' }
    Add-Hallazgo $sev 'WSL_SIN_LIMITE_MEMORIA' "WSL 2 (Docker/distros Linux) está corriendo sin límite de memoria en .wslconfig. Memoria sin atribuir a procesos: $sinAtribuirGB GB." `
        ("Crear o editar $wslConfigRuta con [wsl2] y memory=4GB a 8GB según la RAM, y ejecutar 'wsl --shutdown' para aplicarlo. " +
         'Docker Desktop respeta este límite cuando usa el backend WSL 2.')
}
elseif ($sinAtribuirGB -ge 4 -and $commitPct -ge 85) {
    Add-Hallazgo 'Info' 'MEMORIA_SIN_ATRIBUIR' "$sinAtribuirGB GB comprometidos no pertenecen a ningún proceso visible." `
        'Suele ser una VM (Hyper-V, VMware, WSL, emulador de Android) o un driver. Revisar qué máquinas virtuales están encendidas.'
}

# 5. Servicios
$servCorriendo = @($servicios | Where-Object { $_.estado -eq 'Running' })
if ($servCorriendo.Count -ge 25) {
    Add-Hallazgo 'Baja' 'MUCHOS_SERVICIOS_TERCEROS' "$($servCorriendo.Count) servicios de terceros corriendo." `
        'Revisar la lista con el usuario; no deshabilitar servicios de drivers (Intel, Realtek, NVIDIA, AMD) sin saber qué hacen.'
}

# ================================================================ salida
$orden = @{ Critica = 0; Alta = 1; Media = 2; Baja = 3; Info = 4 }
# Windows PowerShell 5.1: @($ListaGenerica) dentro de un literal @{} lanza "Los tipos de argumentos no coinciden".
# Convertir las listas a arreglos ANTES de armar el literal.
$entradasInicio = $inicio.ToArray()
$hallazgosFinal = @($script:hallazgos | Sort-Object { $orden[$_.severidad] })
$limitesFinal   = $script:limites.ToArray()
$erroresFinal   = $script:errores.ToArray()
$resultado = [ordered]@{
    script        = 'pc-optimizer/software.ps1'
    version       = '1.1'
    generado      = (Get-Date).ToString('s')
    solo_lectura  = $true
    inicio        = [ordered]@{ habilitados = $inicioHab.Count; total = $inicio.Count; entradas = $entradasInicio }
    tareas_inicio = $tareas
    servicios_terceros_auto = [ordered]@{ corriendo = $servCorriendo.Count; total = $servicios.Count; lista = $servicios }
    procesos      = [ordered]@{ top_ram = $porRam; top_reservada = $porPrivada; top_cpu = $porCpu; segundos_muestreo_cpu = $SegundosMuestreo }
    memoria       = $memoria
    antivirus     = $antivirus
    software_marcado = $coincidencias
    apps_store_promocionales = $appxPromo
    total_programas_instalados = $instalado.Count
    hallazgos     = $hallazgosFinal
    limites       = $limitesFinal
    errores       = $erroresFinal
}

$json = $resultado | ConvertTo-Json -Depth 8
$dir = Split-Path $OutFile -Parent
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[System.IO.File]::WriteAllText($OutFile, $json, (New-Object System.Text.UTF8Encoding($false)))

$json
Write-Host ""
Write-Host "JSON guardado en: $OutFile" -ForegroundColor Cyan
