<#
.SYNOPSIS
    pc-optimizer · Fase 1: diagnóstico de hardware y cuellos de botella.

.DESCRIPTION
    SOLO LECTURA. No modifica nada del sistema.
    Recolecta CPU, RAM, discos, GPU, energía, virtualización, batería y uptime,
    y genera una lista de "hallazgos" ordenada por severidad según la tabla del SKILL.md.

    Funciona sin administrador. Lo que necesita admin (desgaste/temperatura del disco,
    a veces la batería) se lista en "requiere_admin".

    Compatible con Windows PowerShell 5.1 y PowerShell 7+.

.PARAMETER OutFile
    Ruta donde guardar el JSON. Por defecto: $env:TEMP\pc-optimizer\hardware.json

.PARAMETER SegundosMuestreo
    Segundos para muestrear el rendimiento del CPU (default 5).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\hardware.ps1
#>
[CmdletBinding()]
param(
    [string]$OutFile = (Join-Path $env:TEMP 'pc-optimizer\hardware.json'),
    [int]$SegundosMuestreo = 5
)

$ErrorActionPreference = 'Stop'
trap {
    Write-Error ("hardware.ps1 falló en la línea {0}: {1}`n{2}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message, $_.InvocationInfo.Line.Trim())
    break
}
$script:errores       = New-Object System.Collections.Generic.List[string]
$script:hallazgos     = New-Object System.Collections.Generic.List[object]
$script:requiereAdmin = New-Object System.Collections.Generic.List[string]

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
        severidad     = $Severidad
        codigo        = $Codigo
        detalle       = $Detalle
        recomendacion = $Recomendacion
    })
}

function ConvertTo-GB { param($Bytes) if ($null -eq $Bytes) { return $null }; [math]::Round([double]$Bytes / 1GB, 1) }

$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

# ---------------------------------------------------------------- sistema
$os = Invoke-Seguro 'os' { Get-CimInstance Win32_OperatingSystem }
$cs = Invoke-Seguro 'computersystem' { Get-CimInstance Win32_ComputerSystem }
$enclosure = Invoke-Seguro 'enclosure' { Get-CimInstance Win32_SystemEnclosure }
$baterias = @(Invoke-Seguro 'battery' { Get-CimInstance Win32_Battery })
$baterias = @($baterias | Where-Object { $_ })

$tiposPortatil = 8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32
$esPortatil = ($baterias.Count -gt 0) -or
              (@($enclosure.ChassisTypes | Where-Object { $tiposPortatil -contains $_ }).Count -gt 0)

$uptimeDias = $null
if ($os) { $uptimeDias = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalDays, 1) }

$sistema = [ordered]@{
    equipo        = $env:COMPUTERNAME
    fabricante    = $cs.Manufacturer
    modelo        = $cs.Model
    portatil      = $esPortatil
    windows       = $os.Caption
    version       = $os.Version
    build         = $os.BuildNumber
    powershell    = $PSVersionTable.PSVersion.ToString()
    es_admin      = $esAdmin
    uptime_dias   = $uptimeDias
}

# ---------------------------------------------------------------- CPU
$cpus = @(Invoke-Seguro 'cpu' { Get-CimInstance Win32_Processor })
$cpu0 = $cpus | Select-Object -First 1

# Muestreo de rendimiento: clases CIM (no se traducen, a diferencia de los contadores de rendimiento).
$muestras = @()
$muestras = Invoke-Seguro 'cpu_muestreo' {
    $r = @()
    for ($i = 0; $i -lt $SegundosMuestreo; $i++) {
        $p = Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'"
        $r += [pscustomobject]@{ uso = [double]$p.PercentProcessorUtility; rendimiento = [double]$p.PercentProcessorPerformance }
        Start-Sleep -Seconds 1
    }
    $r
}
$usoProm = $null; $rendProm = $null
if ($muestras) {
    $usoProm  = [math]::Round(($muestras | Measure-Object uso -Average).Average, 0)
    $rendProm = [math]::Round(($muestras | Measure-Object rendimiento -Average).Average, 0)
}

$cpu = [ordered]@{
    modelo                 = if ($cpu0) { $cpu0.Name.Trim() } else { $null }
    sockets                = $cpus.Count
    nucleos                = ($cpus | Measure-Object NumberOfCores -Sum).Sum
    hilos                  = ($cpus | Measure-Object NumberOfLogicalProcessors -Sum).Sum
    mhz_base               = $cpu0.MaxClockSpeed
    uso_promedio_pct       = $usoProm
    rendimiento_vs_base_pct = $rendProm   # 100 = velocidad base; >100 turbo; <100 frenado
    segundos_muestreo      = $SegundosMuestreo
}

# ---------------------------------------------------------------- RAM
$modulos = @(Invoke-Seguro 'ram_modulos' { Get-CimInstance Win32_PhysicalMemory })
$modulos = @($modulos | Where-Object { $_ })
$arrays  = @(Invoke-Seguro 'ram_ranuras' { Get-CimInstance Win32_PhysicalMemoryArray | Where-Object { $_.Use -eq 3 } })
$ranuras = ($arrays | Measure-Object MemoryDevices -Sum).Sum
$perfMem = Invoke-Seguro 'ram_perf' { Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory }

$tiposMem = @{ 20 = 'DDR'; 21 = 'DDR2'; 24 = 'DDR3'; 26 = 'DDR4'; 34 = 'DDR5' }
$formatos = @{ 8 = 'DIMM'; 12 = 'SODIMM' }

$ramTotal = $null; $ramLibre = $null; $ramUsoPct = $null
if ($os) {
    $ramTotal  = [double]$os.TotalVisibleMemorySize * 1KB
    $ramLibre  = [double]$os.FreePhysicalMemory * 1KB
    $ramUsoPct = [math]::Round((1 - $ramLibre / $ramTotal) * 100, 0)
}
$instaladaGB = ConvertTo-GB (($modulos | Measure-Object Capacity -Sum).Sum)

$ram = [ordered]@{
    instalada_gb       = $instaladaGB
    visible_gb         = ConvertTo-GB $ramTotal
    uso_pct            = $ramUsoPct
    comprometida_gb    = if ($perfMem) { ConvertTo-GB $perfMem.CommittedBytes } else { $null }
    limite_commit_gb   = if ($perfMem) { ConvertTo-GB $perfMem.CommitLimit } else { $null }
    ranuras_totales    = $ranuras
    modulos_instalados = $modulos.Count
    modulos            = @($modulos | ForEach-Object {
        [ordered]@{
            ranura          = $_.DeviceLocator
            banco           = $_.BankLabel
            capacidad_gb    = ConvertTo-GB $_.Capacity
            mhz_configurado = $_.ConfiguredClockSpeed
            mhz_maximo      = $_.Speed
            tipo            = if ($tiposMem.ContainsKey([int]$_.SMBIOSMemoryType)) { $tiposMem[[int]$_.SMBIOSMemoryType] } else { "codigo $($_.SMBIOSMemoryType)" }
            formato         = if ($formatos.ContainsKey([int]$_.FormFactor)) { $formatos[[int]$_.FormFactor] } else { "codigo $($_.FormFactor)" }
            fabricante      = $_.Manufacturer
            parte           = if ($_.PartNumber) { $_.PartNumber.Trim() } else { $null }
        }
    })
}

# ---------------------------------------------------------------- discos
$fisicos = @(Invoke-Seguro 'discos_fisicos' { Get-PhysicalDisk })
$fisicos = @($fisicos | Where-Object { $_ })
$discoC  = Invoke-Seguro 'particion_C' { (Get-Partition -DriveLetter C).DiskNumber }

function Get-TipoMedio {
    param($d)
    $m = [string]$d.MediaType
    if ($m -eq 'SSD' -or $m -eq 'HDD') { return $m }
    if ([string]$d.BusType -eq 'NVMe') { return 'SSD (inferido por NVMe)' }
    if ($d.SpindleSpeed -gt 0 -and $d.SpindleSpeed -lt 100000) { return 'HDD (inferido por RPM)' }
    if ($d.SpindleSpeed -eq 0) { return 'SSD (inferido, 0 RPM)' }
    return 'Desconocido'
}

$listaFisicos = @($fisicos | ForEach-Object {
    $d = $_
    $fiab = $null
    if ($esAdmin) {
        $fiab = Invoke-Seguro "fiabilidad_$($d.DeviceId)" {
            $c = $d | Get-StorageReliabilityCounter
            [ordered]@{
                desgaste_pct          = $c.Wear
                temperatura_c         = $c.Temperature
                errores_lectura       = $c.ReadErrorsTotal
                errores_escritura     = $c.WriteErrorsTotal
                horas_encendido       = $c.PowerOnHours
            }
        }
    }
    [ordered]@{
        id          = [string]$d.DeviceId
        nombre      = $d.FriendlyName
        tipo        = Get-TipoMedio $d
        bus         = [string]$d.BusType
        tamano_gb   = ConvertTo-GB $d.Size
        salud       = [string]$d.HealthStatus
        estado      = [string]$d.OperationalStatus
        es_sistema  = ($null -ne $discoC -and [string]$d.DeviceId -eq [string]$discoC)
        fiabilidad  = $fiab
    }
})
if (-not $esAdmin) { $script:requiereAdmin.Add('Desgaste, temperatura y errores del disco (Get-StorageReliabilityCounter)') }

$volumenes = @(Invoke-Seguro 'volumenes' { Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' }) | Where-Object { $_ } | ForEach-Object {
    [ordered]@{
        unidad     = $_.DeviceID
        etiqueta   = $_.VolumeName
        sistema_archivos = $_.FileSystem
        total_gb   = ConvertTo-GB $_.Size
        libre_gb   = ConvertTo-GB $_.FreeSpace
        usado_pct  = if ($_.Size) { [math]::Round((1 - $_.FreeSpace / $_.Size) * 100, 0) } else { $null }
    }
}
$volumenes = @($volumenes)

# ---------------------------------------------------------------- GPU
$controladoras = @(Invoke-Seguro 'gpu' { Get-CimInstance Win32_VideoController })
$controladoras = @($controladoras | Where-Object { $_ })

# VRAM real desde el registro (AdapterRAM de WMI se queda en 4 GB máximo por ser uint32).
$vramRegistro = @{}
Invoke-Seguro 'gpu_vram_registro' {
    $clase = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    Get-ChildItem $clase -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '^\d{4}$' } |
        ForEach-Object {
            $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($p -and $p.DriverDesc) {
                $q = $p.'HardwareInformation.qwMemorySize'
                if ($q) { $vramRegistro[$p.DriverDesc] = [double]$q }
            }
        }
} | Out-Null

$patronDedicada = 'NVIDIA|GeForce|Quadro|RTX|GTX|Radeon RX|Radeon Pro|Arc A\d|Arc B\d'
$gpus = @($controladoras | ForEach-Object {
    $vram = if ($vramRegistro.ContainsKey($_.Name)) { $vramRegistro[$_.Name] } else { [double]$_.AdapterRAM }
    $fechaDriver = $_.DriverDate
    [ordered]@{
        nombre           = $_.Name
        tipo             = if ($_.Name -match $patronDedicada) { 'Dedicada' } elseif ($_.Name -match 'Basic Display|Básico') { 'Sin driver' } else { 'Integrada' }
        vram_gb          = ConvertTo-GB $vram
        driver_version   = $_.DriverVersion
        driver_fecha     = if ($fechaDriver) { $fechaDriver.ToString('yyyy-MM-dd') } else { $null }
        driver_dias      = if ($fechaDriver) { [int]((Get-Date) - $fechaDriver).TotalDays } else { $null }
        resolucion       = if ($_.CurrentHorizontalResolution) { "$($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution)" } else { $null }
        hz               = $_.CurrentRefreshRate
    }
})

# ---------------------------------------------------------------- energía
$planes = @{
    '381b4222-f694-41f0-9685-ff5bb260df2e' = 'Equilibrado'
    '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' = 'Alto rendimiento'
    'a1841308-3bcb-4fc1-a3ff-8dc3ff5e9f29' = 'Economizador'
    'e9a42b02-d5df-448d-aa00-03f14749eb61' = 'Máximo rendimiento'
}
$modosOverlay = @{
    '961cc777-2547-4f9d-8174-7d86181b8a7a' = 'Mejor eficiencia energética'
    'ded574b5-45a0-4f42-8737-46345c09c238' = 'Mejor rendimiento'
    '00000000-0000-0000-0000-000000000000' = 'Equilibrado'
}
$planGuid = $null; $planNombre = $null
Invoke-Seguro 'plan_energia' {
    $salida = (powercfg /getactivescheme) -join ' '
    if ($salida -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\s*\(([^)]*)\)') {
        $script:planGuid = $Matches[1].ToLower(); $script:planNombre = $Matches[2]
    }
} | Out-Null

$overlayAC = $null; $overlayDC = $null
Invoke-Seguro 'modo_energia' {
    $k = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' -ErrorAction Stop
    if ($k.ActiveOverlayAcPowerScheme) { $script:overlayAC = $k.ActiveOverlayAcPowerScheme.ToLower() }
    if ($k.ActiveOverlayDcPowerScheme) { $script:overlayDC = $k.ActiveOverlayDcPowerScheme.ToLower() }
} | Out-Null

function Get-NombreOverlay { param($g) if (-not $g) { return $null }; if ($modosOverlay.ContainsKey($g)) { $modosOverlay[$g] } else { "desconocido ($g)" } }

$enCorriente = $null
if ($baterias.Count -gt 0) { $enCorriente = ($baterias[0].BatteryStatus -eq 2) }

$energia = [ordered]@{
    plan_guid        = $planGuid
    plan             = if ($planGuid -and $planes.ContainsKey($planGuid)) { $planes[$planGuid] } else { $planNombre }
    modo_conectado   = Get-NombreOverlay $overlayAC
    modo_bateria     = Get-NombreOverlay $overlayDC
    conectado_ahora  = $enCorriente
}

# ---------------------------------------------------------------- virtualización
# Si hay hipervisor activo (Hyper-V/WSL2), VirtualizationFirmwareEnabled reporta False aunque esté activa.
$hipervisor = [bool]$cs.HypervisorPresent
$virt = [ordered]@{
    hipervisor_activo        = $hipervisor
    firmware_habilitada      = $cpu0.VirtualizationFirmwareEnabled
    efectiva                 = ($hipervisor -or [bool]$cpu0.VirtualizationFirmwareEnabled)
}

# ---------------------------------------------------------------- batería
$bateria = $null
if ($baterias.Count -gt 0) {
    # BatteryStaticData suele requerir admin: sin admin falla con "Error genérico", no es un error del script.
    $diseno = $null
    try { $diseno = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity } catch { }
    $actual = Invoke-Seguro 'bateria_actual' { (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity | Select-Object -First 1).FullChargedCapacity }
    $bateria = [ordered]@{
        carga_pct        = $baterias[0].EstimatedChargeRemaining
        capacidad_diseno = $diseno
        capacidad_actual = $actual
        salud_pct        = if ($diseno -and $actual) { [math]::Round($actual / $diseno * 100, 0) } else { $null }
    }
    if (-not $bateria.salud_pct) {
        $script:requiereAdmin.Add('Salud de la batería (o usar: powercfg /batteryreport)')
    }
}

# ================================================================ hallazgos
# 1. Disco del sistema
$discoSistema = $listaFisicos | Where-Object { $_.es_sistema } | Select-Object -First 1
$hayOtroSSD   = @($listaFisicos | Where-Object { -not $_.es_sistema -and $_.tipo -like 'SSD*' }).Count -gt 0

if ($discoSistema -and $discoSistema.tipo -like 'HDD*') {
    $extra = if ($hayOtroSSD) { ' Ya hay un SSD en el equipo: migrar Windows a ese SSD.' } else { '' }
    Add-Hallazgo 'Critica' 'WINDOWS_EN_HDD' "Windows (C:) está en un disco mecánico: $($discoSistema.nombre)." `
        ("Instalar o clonar Windows en un SSD (NVMe si hay ranura M.2) y dejar el HDD para datos. Ninguna limpieza lo compensa." + $extra)
}
elseif ($null -eq $discoSistema) {
    Add-Hallazgo 'Info' 'DISCO_SISTEMA_DESCONOCIDO' 'No se pudo identificar en qué disco físico está C:.' `
        'Revisar en Administrador de tareas > Rendimiento > Disco cuál contiene C: y si es SSD o HDD.'
}

foreach ($d in $listaFisicos) {
    if ($d.salud -and $d.salud -ne 'Healthy' -and $d.salud -ne '0') {
        Add-Hallazgo 'Critica' 'DISCO_SALUD' "El disco '$($d.nombre)' reporta salud: $($d.salud)." `
            'Respaldar los datos de inmediato antes de cualquier otra acción.'
    }
    if ($d.fiabilidad -and $d.fiabilidad.desgaste_pct -ge 80) {
        Add-Hallazgo 'Critica' 'DISCO_DESGASTE' "El disco '$($d.nombre)' tiene $($d.fiabilidad.desgaste_pct)% de desgaste." `
            'Respaldar y planear reemplazo.'
    }
}

# 2. RAM
if ($instaladaGB -and $instaladaGB -le 8 -and $ramUsoPct -ge 80) {
    Add-Hallazgo 'Alta' 'RAM_SATURADA' "RAM de $instaladaGB GB al $ramUsoPct% de uso." `
        'Reducir programas de inicio (Fase 2). Si sigue alta en reposo, ampliar RAM.'
}
elseif ($instaladaGB -and $instaladaGB -le 8) {
    Add-Hallazgo 'Media' 'RAM_JUSTA' "Solo $instaladaGB GB de RAM (uso actual $ramUsoPct%)." `
        'Suficiente para ofimática; corta para desarrollo con IDE + emulador o Docker. Considerar 16 GB.'
}
elseif ($ramUsoPct -ge 85) {
    Add-Hallazgo 'Media' 'RAM_ALTA' "RAM de $instaladaGB GB al $ramUsoPct% de uso." `
        'Ver en la Fase 2 qué procesos la ocupan (Docker/WSL "vmmem", navegadores, IDEs).'
}

# Memoria comprometida cerca del límite: Windows ya está paginando a disco y lo siguiente que se abra va lento.
$commitPct = $null
if ($perfMem -and $perfMem.CommitLimit) { $commitPct = [math]::Round([double]$perfMem.CommittedBytes / [double]$perfMem.CommitLimit * 100, 0) }
$ram['comprometida_pct'] = $commitPct
if ($commitPct -ge 85) {
    Add-Hallazgo 'Alta' 'MEMORIA_COMPROMETIDA' "Memoria comprometida al $commitPct% del límite ($($ram.comprometida_gb) de $($ram.limite_commit_gb) GB): el sistema depende del archivo de paginación." `
        'Cerrar lo que no se use (contenedores Docker, VMs, emuladores, pestañas). Si es la situación normal de trabajo, el equipo necesita más RAM.'
}

if ($modulos.Count -eq 1 -and $ranuras -ge 2) {
    Add-Hallazgo 'Alta' 'RAM_UN_CANAL' "Un solo módulo de RAM instalado ($ranuras ranuras reportadas): funciona en single channel." `
        'Agregar un módulo igual (misma capacidad y velocidad) para activar dual channel. Pesa más con GPU integrada. Verificar en el manual si alguna ranura es RAM soldada.'
}
elseif ($modulos.Count -eq 1) {
    Add-Hallazgo 'Info' 'RAM_UN_MODULO' 'Un solo módulo de RAM reportado y no se pudo confirmar si hay ranuras libres.' `
        'Revisar en Administrador de tareas > Memoria > "Ranuras usadas".'
}
if ($modulos.Count -ge 2 -and @($modulos | Select-Object -ExpandProperty Capacity -Unique).Count -gt 1) {
    Add-Hallazgo 'Baja' 'RAM_DISPAREJA' 'Módulos de RAM de distinta capacidad: dual channel solo parcial (flex mode).' `
        'Si se amplía RAM, usar módulos iguales.'
}
$mhzDistintos = @($modulos | Where-Object { $_.ConfiguredClockSpeed -and $_.Speed -and $_.ConfiguredClockSpeed -lt $_.Speed })
if ($mhzDistintos.Count -gt 0 -and -not $esPortatil) {
    Add-Hallazgo 'Baja' 'RAM_BAJO_SU_VELOCIDAD' 'La RAM corre por debajo de su velocidad nominal.' `
        'En equipos de escritorio, revisar en BIOS si hay perfil XMP/EXPO desactivado.'
}

# 3. CPU y energía
if ($planGuid -eq 'a1841308-3bcb-4fc1-a3ff-8dc3ff5e9f29' -or $overlayAC -eq '961cc777-2547-4f9d-8174-7d86181b8a7a') {
    Add-Hallazgo 'Media' 'ENERGIA_AHORRO' "Plan o modo de energía en ahorro (plan: $($energia.plan); modo conectado: $($energia.modo_conectado))." `
        'Usar "Equilibrado" o "Mejor rendimiento" cuando esté conectado a la corriente.'
}
if ($usoProm -ge 60 -and $rendProm -and $rendProm -lt 70) {
    Add-Hallazgo 'Media' 'CPU_FRENADO' "Con el CPU al $usoProm% de uso, rinde al $rendProm% de su velocidad base." `
        'Posible throttling térmico o por energía: revisar plan de energía, perfil del software del fabricante, ventiladores y polvo.'
}
elseif ($usoProm -ge 60) {
    Add-Hallazgo 'Info' 'CPU_OCUPADO' "El CPU estaba al $usoProm% durante el muestreo." `
        'Revisar qué procesos lo consumen (Fase 2).'
}

# 4. Espacio del disco de sistema
$volC = $volumenes | Where-Object { $_.unidad -eq 'C:' } | Select-Object -First 1
if ($volC -and $volC.usado_pct -ge 85) {
    Add-Hallazgo 'Media' 'DISCO_LLENO' "C: al $($volC.usado_pct)% ($($volC.libre_gb) GB libres de $($volC.total_gb) GB)." `
        'Liberar espacio (Fase 3). Windows se degrada con menos de 10-15% libre.'
}

# 5. Virtualización
if (-not $virt.efectiva) {
    Add-Hallazgo 'Media' 'VIRTUALIZACION_OFF' 'Virtualización no detectada como habilitada.' `
        'Si el uso es desarrollo: activar VT-x/AMD-V en la BIOS (requisito para emuladores, Docker y WSL2).'
}

# 6. GPU
foreach ($g in $gpus) {
    if ($g.tipo -eq 'Sin driver') {
        Add-Hallazgo 'Media' 'GPU_SIN_DRIVER' "La pantalla usa '$($g.nombre)': no hay driver de video instalado." `
            'Instalar el driver del fabricante (Intel/AMD/NVIDIA o el del modelo del equipo).'
    }
    elseif ($g.driver_dias -gt 365) {
        Add-Hallazgo 'Baja' 'GPU_DRIVER_VIEJO' "Driver de '$($g.nombre)' con $($g.driver_dias) días ($($g.driver_fecha))." `
            'Actualizar desde el fabricante.'
    }
}

# 7. Batería
if ($bateria -and $bateria.salud_pct -and $bateria.salud_pct -lt 70) {
    Add-Hallazgo 'Baja' 'BATERIA_DESGASTADA' "La batería conserva el $($bateria.salud_pct)% de su capacidad original." `
        'Considerar reemplazo si la autonomía es un problema.'
}

# 8. Uptime
if ($uptimeDias -gt 7) {
    Add-Hallazgo 'Baja' 'UPTIME_ALTO' "El equipo lleva $uptimeDias días sin reiniciar." `
        'Reiniciar (con Inicio rápido activo, "Apagar" no reinicia el kernel; usar "Reiniciar").'
}

# ================================================================ salida
$orden = @{ Critica = 0; Alta = 1; Media = 2; Baja = 3; Info = 4 }
$hallazgosOrdenados = @($script:hallazgos | Sort-Object { $orden[$_.severidad] })

$resultado = [ordered]@{
    script            = 'pc-optimizer/hardware.ps1'
    version           = '1.0'
    generado          = (Get-Date).ToString('s')
    solo_lectura      = $true
    sistema           = $sistema
    cpu               = $cpu
    ram               = $ram
    discos            = [ordered]@{ fisicos = $listaFisicos; volumenes = $volumenes; disco_sistema_id = $discoC }
    gpu               = $gpus
    energia           = $energia
    virtualizacion    = $virt
    bateria           = $bateria
    hallazgos         = $hallazgosOrdenados
    requiere_admin    = $script:requiereAdmin.ToArray()   # .ToArray(): ver nota en software.ps1 sobre @() en PS 5.1
    errores           = $script:errores.ToArray()
}

$json = $resultado | ConvertTo-Json -Depth 8

$dir = Split-Path $OutFile -Parent
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[System.IO.File]::WriteAllText($OutFile, $json, (New-Object System.Text.UTF8Encoding($false)))

$json
Write-Host ""
Write-Host "JSON guardado en: $OutFile" -ForegroundColor Cyan
