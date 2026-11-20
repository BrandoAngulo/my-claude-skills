<#
.SYNOPSIS
    pc-optimizer · Fase 3a: espacio en disco (sistema y usuario).

.DESCRIPTION
    SOLO LECTURA. No borra, no mueve, no comprime nada.
    Escaneo DIRIGIDO (no recorre todo el disco):
      - Volúmenes y espacio libre.
      - Archivos de sistema grandes: hiberfil.sys, pagefile.sys, swapfile.sys.
      - Papelera, carpetas temporales, caché de Windows Update, Windows.old.
      - Volcados de memoria (.dmp, .hprof) y crash dumps.
      - Cachés de navegadores (Chrome, Edge, Brave, Firefox).
      - Descargas: tamaño, archivos grandes e instaladores viejos.
      - Archivos grandes (>= -MinGB) dentro del perfil del usuario, con límite de tiempo.
    Las cachés de herramientas de desarrollo (Docker, Ollama, Gradle, npm, JetBrains, Android SDK...)
    las analiza dev-caches.ps1; aquí solo se marcan como "ver dev-caches".

    Cada hallazgo trae un nivel: seguro / revisar / no_tocar, y la acción sugerida (como texto, nunca se ejecuta).
    Sin administrador. Compatible con Windows PowerShell 5.1 y PowerShell 7+.

.PARAMETER MinGB
    Tamaño mínimo para listar un archivo grande del perfil (default 1 GB).

.PARAMETER SegundosEscaneo
    Tiempo máximo para el recorrido del perfil (default 90 s). Si se agota, el resultado se marca como parcial.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\disco.ps1
#>
[CmdletBinding()]
param(
    [string]$OutFile = (Join-Path $env:TEMP 'pc-optimizer\disco.json'),
    [double]$MinGB = 1,
    [int]$SegundosEscaneo = 90,
    [int]$DiasInstaladorViejo = 30
)

$ErrorActionPreference = 'Stop'
trap {
    Write-Error ("disco.ps1 falló en la línea {0}: {1}`n{2}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message, $_.InvocationInfo.Line.Trim())
    break
}
# NOTA PS 5.1: no usar @($ListaGenerica) dentro de un literal @{} (usar .ToArray()), ni [byte] -band [int].
$script:errores       = New-Object System.Collections.Generic.List[string]
$script:hallazgos     = New-Object System.Collections.Generic.List[object]
$script:items         = New-Object System.Collections.Generic.List[object]
$script:requiereAdmin = New-Object System.Collections.Generic.List[string]

# ---------------------------------------------------------------- helpers
function Invoke-Seguro {
    param([string]$Nombre, [scriptblock]$Bloque)
    try { & $Bloque }
    catch { $script:errores.Add("${Nombre}: $($_.Exception.Message)"); $null }
}

function Add-Hallazgo {
    param([ValidateSet('Critica','Alta','Media','Baja','Info')][string]$Severidad,
          [string]$Codigo, [string]$Detalle, [string]$Recomendacion)
    $script:hallazgos.Add([ordered]@{ severidad = $Severidad; codigo = $Codigo; detalle = $Detalle; recomendacion = $Recomendacion })
}

function ConvertTo-GB { param($Bytes) if ($null -eq $Bytes) { return $null }; [math]::Round([double]$Bytes / 1GB, 2) }

# Suma recursiva con .NET (rápida), sin seguir enlaces/junctions, tolerante a "acceso denegado", con límite de tiempo.
function Get-TamanoCarpeta {
    param([string]$Ruta, [int]$Segundos = 20)
    $res = [ordered]@{ ruta = $Ruta; existe = $false; bytes = [double]0; archivos = 0; parcial = $false; denegado = $false }
    if (-not $Ruta -or -not [System.IO.Directory]::Exists($Ruta)) { return $res }
    $res.existe = $true
    $limite = (Get-Date).AddSeconds($Segundos)
    $pila = New-Object System.Collections.Generic.Stack[string]
    $pila.Push($Ruta)
    while ($pila.Count -gt 0) {
        if ((Get-Date) -gt $limite) { $res.parcial = $true; break }
        $dir = $pila.Pop()
        try {
            $di = New-Object System.IO.DirectoryInfo($dir)
            foreach ($f in $di.GetFiles()) { $res.bytes += [double]$f.Length; $res.archivos++ }
            foreach ($d in $di.GetDirectories()) {
                if ((([int]$d.Attributes) -band 1024) -eq 0) { $pila.Push($d.FullName) }
            }
        } catch { $res.denegado = $true }
    }
    $res
}

# Registra un ítem medido.
function Add-Item {
    param([string]$Categoria, [string]$Nombre, [string]$Ruta, [double]$Bytes,
          [ValidateSet('seguro','revisar','no_tocar','ver_dev_caches')][string]$Nivel,
          [string]$Accion, [string]$Nota = '', [bool]$Parcial = $false)
    $script:items.Add([ordered]@{
        categoria = $Categoria; nombre = $Nombre; ruta = $Ruta; tamano_gb = ConvertTo-GB $Bytes
        nivel = $Nivel; accion = $Accion; nota = $Nota; parcial = $Parcial
    })
}

function Measure-Y-Registra {
    param([string]$Categoria, [string]$Nombre, [string]$Ruta, [string]$Nivel, [string]$Accion,
          [string]$Nota = '', [double]$MinimoMB = 50, [int]$Segundos = 20)
    $t = Get-TamanoCarpeta -Ruta $Ruta -Segundos $Segundos
    if (-not $t.existe) { return }
    if ($t.denegado -and $t.bytes -eq 0) { $script:requiereAdmin.Add("$Nombre ($Ruta)"); return }
    if ($t.bytes -ge ($MinimoMB * 1MB)) {
        $n = $Nota; if ($t.denegado) { $n = ($n + ' Algunas subcarpetas no se pudieron leer sin admin.').Trim() }
        Add-Item $Categoria $Nombre $Ruta $t.bytes $Nivel $Accion $n $t.parcial
    }
}

$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
$sysDrive = $env:SystemDrive          # normalmente C:
$sysRoot  = "$sysDrive\"
$perfil   = $env:USERPROFILE
$local    = $env:LOCALAPPDATA
$roaming  = $env:APPDATA

# ---------------------------------------------------------------- volúmenes
$volumenes = @(Invoke-Seguro 'volumenes' {
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
        [ordered]@{
            unidad = $_.DeviceID; etiqueta = $_.VolumeName
            total_gb = ConvertTo-GB $_.Size; libre_gb = ConvertTo-GB $_.FreeSpace
            usado_pct = if ($_.Size) { [math]::Round((1 - $_.FreeSpace / $_.Size) * 100, 0) } else { $null }
            es_sistema = ($_.DeviceID -eq $sysDrive)
        }
    }
})
$volumenes = @($volumenes | Where-Object { $_ })
$otrasUnidades = @($volumenes | Where-Object { -not $_.es_sistema -and $_.libre_gb -ge 20 })

# ---------------------------------------------------------------- archivos de sistema en la raíz
# Sin admin, Get-Item sobre C:\pagefile.sys falla (archivo en uso), pero listar la raíz sí devuelve el tamaño.
$archivosRaiz = @{}
Invoke-Seguro 'raiz_listado' {
    foreach ($f in (New-Object System.IO.DirectoryInfo($sysRoot)).GetFiles('*.sys')) { $archivosRaiz[$f.Name.ToLower()] = $f }
} | Out-Null

# HibernateEnabled no siempre existe (equipos que nunca la cambiaron): se usa el valor por defecto y, si no, la existencia de hiberfil.sys.
$hibernacion = $null
$regPower = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -ErrorAction SilentlyContinue
if ($regPower -and $null -ne $regPower.HibernateEnabled)             { $hibernacion = ([int]$regPower.HibernateEnabled -eq 1) }
elseif ($regPower -and $null -ne $regPower.HibernateEnabledDefault) { $hibernacion = ([int]$regPower.HibernateEnabledDefault -eq 1) }
elseif ($archivosRaiz.ContainsKey('hiberfil.sys'))                   { $hibernacion = $true }

Invoke-Seguro 'raiz_sistema' {
    foreach ($nombre in 'hiberfil.sys', 'pagefile.sys', 'swapfile.sys') {
        $ruta = Join-Path $sysRoot $nombre
        if (-not $archivosRaiz.ContainsKey($nombre)) { continue }
        $fi = $archivosRaiz[$nombre]
        switch ($nombre) {
            'hiberfil.sys' {
                Add-Item 'sistema' 'Archivo de hibernación' $ruta $fi.Length 'revisar' `
                    'powercfg /h off  (requiere admin; desactiva hibernar e Inicio rápido)' `
                    'Seguro de quitar si el usuario no hiberna. En portátiles que se cierran y se guardan días, conviene mantenerlo.'
            }
            'pagefile.sys' {
                Add-Item 'sistema' 'Archivo de paginación' $ruta $fi.Length 'no_tocar' '' `
                    'Nunca eliminar. Solo se ajusta el tamaño, y con poca RAM conviene dejarlo administrado por Windows.'
            }
            'swapfile.sys' {
                Add-Item 'sistema' 'Swap de apps de la Store' $ruta $fi.Length 'no_tocar' '' 'Lo administra Windows.'
            }
        }
    }
} | Out-Null

# ---------------------------------------------------------------- papelera (de todos los discos, vía Shell)
Invoke-Seguro 'papelera' {
    $shell = New-Object -ComObject Shell.Application
    $bin = $shell.NameSpace(10)
    $total = [double]0; $n = 0
    foreach ($it in $bin.Items()) { $total += [double]$it.ExtendedProperty('Size'); $n++ }
    if ($total -gt 0) {
        Add-Item 'usuario' "Papelera de reciclaje ($n elementos)" 'Papelera' $total 'revisar' `
            'Vaciar la papelera desde el escritorio' 'Confirmar con el usuario que no hay nada que recuperar.'
    }
} | Out-Null

# ---------------------------------------------------------------- temporales y Windows Update
Measure-Y-Registra 'temporales' 'Temporales del usuario' $env:TEMP 'seguro' `
    'Configuración > Sistema > Almacenamiento > Archivos temporales (o borrar el contenido de %TEMP% con las apps cerradas)' `
    'Los archivos en uso no se dejan borrar; es normal.'
Measure-Y-Registra 'temporales' 'Temporales de Windows' (Join-Path $env:windir 'Temp') 'seguro' `
    'Configuración > Sistema > Almacenamiento > Archivos temporales'
Measure-Y-Registra 'temporales' 'Descargas de Windows Update' (Join-Path $env:windir 'SoftwareDistribution\Download') 'seguro' `
    'Configuración > Sistema > Almacenamiento > Archivos temporales > "Limpieza de Windows Update"' `
    'No borrar a mano mientras haya una actualización en curso.'
Measure-Y-Registra 'sistema' 'Instalación anterior de Windows (Windows.old)' (Join-Path $sysRoot 'Windows.old') 'revisar' `
    'Configuración > Sistema > Almacenamiento > Archivos temporales > "Instalaciones anteriores de Windows"' `
    'Permite volver a la versión anterior de Windows. Se borra sola a los 10 días; quitarla elimina esa opción.' -Segundos 30
Measure-Y-Registra 'sistema' 'Archivos de actualización ($WINDOWS.~BT)' (Join-Path $sysRoot '$WINDOWS.~BT') 'revisar' `
    'Archivos temporales > "Archivos temporales de instalación de Windows"'

# ---------------------------------------------------------------- volcados de memoria
Measure-Y-Registra 'volcados' 'Crash dumps de aplicaciones' (Join-Path $local 'CrashDumps') 'seguro' `
    'Borrar el contenido de la carpeta' 'Solo sirven para diagnosticar un fallo concreto.' -MinimoMB 20
Measure-Y-Registra 'volcados' 'Minidumps de Windows' (Join-Path $env:windir 'Minidump') 'seguro' `
    'Archivos temporales > "Archivos de volcado de memoria de errores del sistema"' '' -MinimoMB 20
Invoke-Seguro 'memory_dmp' {
    $m = Get-Item -LiteralPath (Join-Path $env:windir 'MEMORY.DMP') -Force -ErrorAction SilentlyContinue
    if ($m) {
        Add-Item 'volcados' 'Volcado completo de memoria (MEMORY.DMP)' $m.FullName $m.Length 'seguro' `
            'Archivos temporales > "Archivos de volcado de memoria de errores del sistema"' `
            'Es de un pantallazo azul pasado. Si los pantallazos se repiten, guardarlo antes para diagnóstico.'
    }
} | Out-Null

# ---------------------------------------------------------------- navegadores
$navegadores = @(
    @{ n = 'Chrome';  base = Join-Path $local 'Google\Chrome\User Data' }
    @{ n = 'Edge';    base = Join-Path $local 'Microsoft\Edge\User Data' }
    @{ n = 'Brave';   base = Join-Path $local 'BraveSoftware\Brave-Browser\User Data' }
)
foreach ($nav in $navegadores) {
    if (-not (Test-Path -LiteralPath $nav.base)) { continue }
    Invoke-Seguro "cache_$($nav.n)" {
        $total = [double]0; $parcial = $false
        $perfiles = Get-ChildItem -LiteralPath $nav.base -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' }
        foreach ($p in $perfiles) {
            foreach ($sub in 'Cache', 'Code Cache', 'GPUCache', 'Service Worker\CacheStorage') {
                $t = Get-TamanoCarpeta (Join-Path $p.FullName $sub) 10
                $total += $t.bytes; if ($t.parcial) { $parcial = $true }
            }
        }
        if ($total -ge 200MB) {
            Add-Item 'navegadores' "Caché de $($nav.n)" $nav.base $total 'seguro' `
                "En $($nav.n): Configuración > Privacidad > Borrar datos de navegación > solo 'Imágenes y archivos en caché'" `
                'No borra contraseñas, historial ni sesiones si solo se marca la caché. Se vuelve a llenar con el uso.' $parcial
        }
    } | Out-Null
}
$ff = Join-Path $local 'Mozilla\Firefox\Profiles'
if (Test-Path -LiteralPath $ff) {
    Invoke-Seguro 'cache_firefox' {
        $total = [double]0
        Get-ChildItem -LiteralPath $ff -Directory | ForEach-Object { $total += (Get-TamanoCarpeta (Join-Path $_.FullName 'cache2') 10).bytes }
        if ($total -ge 200MB) {
            Add-Item 'navegadores' 'Caché de Firefox' $ff $total 'seguro' `
                "Firefox: Ajustes > Privacidad > Cookies y datos del sitio > Limpiar datos > solo 'Contenido web en caché'"
        }
    } | Out-Null
}

# ---------------------------------------------------------------- Descargas
$descargas = Invoke-Seguro 'ruta_descargas' {
    (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
}
if (-not $descargas) { $descargas = Join-Path $perfil 'Downloads' }

$descargasInfo = $null
$descargasGrandes = @()
$instaladoresViejos = @()
if (Test-Path -LiteralPath $descargas) {
    $t = Get-TamanoCarpeta $descargas 30
    $descargasInfo = [ordered]@{ ruta = $descargas; tamano_gb = ConvertTo-GB $t.bytes; archivos = $t.archivos; parcial = $t.parcial }

    $extInstalador = '.exe', '.msi', '.msix', '.iso', '.img', '.zip', '.7z', '.rar', '.dmg', '.apk'
    $fechaCorte = (Get-Date).AddDays(-$DiasInstaladorViejo)
    $archivosDesc = @(Invoke-Seguro 'descargas_archivos' { Get-ChildItem -LiteralPath $descargas -File -Force -ErrorAction SilentlyContinue })
    $archivosDesc = @($archivosDesc | Where-Object { $_ })

    $descargasGrandes = @($archivosDesc | Where-Object { $_.Length -ge 100MB } | Sort-Object Length -Descending |
        Select-Object -First 30 | ForEach-Object {
            [ordered]@{ nombre = $_.Name; tamano_gb = ConvertTo-GB $_.Length; modificado = $_.LastWriteTime.ToString('yyyy-MM-dd') }
        })
    $viejos = @($archivosDesc | Where-Object { $extInstalador -contains $_.Extension.ToLower() -and $_.LastWriteTime -lt $fechaCorte })
    $instaladoresViejos = @($viejos | Sort-Object Length -Descending | Select-Object -First 40 | ForEach-Object {
        [ordered]@{ nombre = $_.Name; tamano_gb = ConvertTo-GB $_.Length; modificado = $_.LastWriteTime.ToString('yyyy-MM-dd') }
    })
    $bytesViejos = [double](($viejos | Measure-Object Length -Sum).Sum)
    if ($bytesViejos -ge 500MB) {
        Add-Item 'descargas' "Instaladores y comprimidos de más de $DiasInstaladorViejo días ($($viejos.Count))" $descargas $bytesViejos 'revisar' `
            'Mover a un disco externo o a la nube, o borrar los que ya se instalaron' `
            'Las ISO y los instaladores de licencias pagas conviene guardarlos fuera del disco, no borrarlos.'
    }
}

# ---------------------------------------------------------------- archivos grandes en el perfil (recorrido con límite)
# Rutas que analiza dev-caches.ps1 o que nunca se tocan desde aquí.
$reglasRuta = @(
    @{ re = '\\Docker\\wsl\\';                               nivel = 'ver_dev_caches'; nota = 'Disco virtual de Docker: se compacta, no se borra. Ver dev-caches.' }
    @{ re = '\\Packages\\[^\\]*(Ubuntu|Debian|Linux|WSL)[^\\]*\\LocalState\\ext4\.vhdx$'; nivel = 'no_tocar'; nota = 'Disco de una distro WSL: borrarlo elimina la distro completa.' }
    @{ re = '\\\.ollama\\models\\';                          nivel = 'ver_dev_caches'; nota = 'Modelo de Ollama: decidir con `ollama list` y el uso en proyectos.' }
    @{ re = '\\Android\\Sdk\\';                              nivel = 'ver_dev_caches'; nota = 'Android SDK.' }
    @{ re = '\\\.android\\avd\\';                            nivel = 'ver_dev_caches'; nota = 'Emulador de Android (AVD).' }
    @{ re = '\\\.gradle\\|\\\.m2\\|\\npm-cache\\|\\Pub\\Cache\\|\\JetBrains\\'; nivel = 'ver_dev_caches'; nota = 'Caché de desarrollo.' }
    @{ re = '\\AppData\\Roaming\\Claude\\vm_bundles\\';       nivel = 'no_tocar'; nota = 'Máquina virtual de la app de Claude.' }
    @{ re = '\\(postgres_data|pgdata|mysql_data|mysql|mongodata|mongo_data|data\\db|mariadb|redis_data)\\|\\base\\\d+\\\d+$|\.(ibd|mdf|ldf|ndf|sqlite3?|db)$';
       nivel = 'no_tocar'; nota = 'Archivo de una base de datos: borrarlo corrompe la base. Se gestiona desde el motor de BD.' }
    @{ re = '\\AppData\\Local\\Packages\\';                  nivel = 'no_tocar'; nota = 'Datos de una app de la Store.' }
    @{ re = '\\OneDrive[^\\]*\\';                            nivel = 'revisar';  nota = 'Está en OneDrive: borrarlo aquí lo borra también en la nube.' }
    @{ re = '\.(hprof|dmp|mdmp)$';                           nivel = 'seguro';   nota = 'Volcado de memoria de un fallo. Solo sirve para diagnosticar ese fallo.' }
    @{ re = '\.(iso|img)$';                                  nivel = 'revisar';  nota = 'Imagen de disco: mover a un disco externo si se quiere conservar.' }
    @{ re = '\.(vhdx?|vmdk|qcow2|vdi)$';                     nivel = 'revisar';  nota = 'Disco de máquina virtual: confirmar si la VM se sigue usando.' }
    @{ re = '\.(ost)$';                                      nivel = 'revisar';  nota = 'Caché de Outlook: se reduce bajando el período sin conexión en Outlook, no borrando el archivo.' }
    @{ re = '\.(mp4|mkv|mov|avi)$';                          nivel = 'revisar';  nota = 'Video: decisión del usuario.' }
)
function Get-Clasificacion {
    param([string]$Ruta)
    foreach ($r in $reglasRuta) { if ($Ruta -match $r.re) { return $r } }
    return @{ nivel = 'revisar'; nota = '' }
}

# Carpetas que no vale la pena recorrer (millones de archivos pequeños) o que se analizan aparte.
$saltar = @('node_modules', '.git', '.venv', 'venv', '__pycache__', 'site-packages', '.next', 'target', 'build', '.dart_tool',
            'Temporary Internet Files', 'INetCache', 'Code Cache', 'GPUCache', 'Cache')

# Rutas completas que dev-caches.ps1 mide aparte: no recorrerlas aquí ahorra la mayor parte del tiempo.
$saltarRutas = '\\AppData\\Local\\(Pub|npm-cache|pip|Yarn|pnpm|JetBrains|Google\\Chrome|Microsoft\\Edge|BraveSoftware|Packages|Microsoft\\WindowsApps)$|' +
               '\\\.(gradle|m2|nuget|cargo|rustup|pub-cache|npm|vscode|cursor|antigravity[^\\]*)$|\\AppData\\Roaming\\(npm|Code|Cursor)$'

$grandes = New-Object System.Collections.Generic.List[object]
$escaneo = [ordered]@{ ruta = $perfil; min_gb = $MinGB; segundos_limite = $SegundosEscaneo; carpetas = 0; parcial = $false; segundos = 0 }
Invoke-Seguro 'escaneo_perfil' {
    $inicio = Get-Date
    $limite = $inicio.AddSeconds($SegundosEscaneo)
    $minBytes = [double]($MinGB * 1GB)
    # Cola (por niveles): si se agota el tiempo, al menos quedan revisados los niveles de arriba,
    # que es donde suelen estar los archivos grandes del usuario (Documentos, Descargas, Videos).
    $pila = New-Object System.Collections.Generic.Queue[string]
    $pila.Enqueue($perfil)
    while ($pila.Count -gt 0) {
        if ((Get-Date) -gt $limite) { $escaneo.parcial = $true; break }
        $dir = $pila.Dequeue(); $escaneo.carpetas++
        try {
            $di = New-Object System.IO.DirectoryInfo($dir)
            foreach ($f in $di.GetFiles()) {
                if ($f.Length -ge $minBytes) {
                    $c = Get-Clasificacion $f.FullName
                    $grandes.Add([ordered]@{
                        ruta = $f.FullName; tamano_gb = ConvertTo-GB $f.Length
                        modificado = $f.LastWriteTime.ToString('yyyy-MM-dd'); nivel = $c.nivel; nota = $c.nota
                    })
                }
            }
            foreach ($d in $di.GetDirectories()) {
                if ((([int]$d.Attributes) -band 1024) -ne 0) { continue }
                if ($saltar -contains $d.Name) { continue }
                if ($d.FullName -match $saltarRutas) { continue }
                $pila.Enqueue($d.FullName)
            }
        } catch { }
    }
    $escaneo.segundos = [int]((Get-Date) - $inicio).TotalSeconds
} | Out-Null
$grandesOrdenados = @($grandes.ToArray() | Sort-Object { $_.tamano_gb } -Descending)

# Los volcados del perfil (.hprof, .dmp) se suman como ítem seguro.
$volcadosPerfil = @($grandesOrdenados | Where-Object { $_.nivel -eq 'seguro' })
if ($volcadosPerfil.Count -gt 0) {
    $bytesVolcados = [double](($volcadosPerfil | ForEach-Object { $_.tamano_gb } | Measure-Object -Sum).Sum) * 1GB
    Add-Item 'volcados' "Volcados de memoria en el perfil ($($volcadosPerfil.Count))" $perfil $bytesVolcados 'seguro' `
        'Borrar los archivos listados en archivos_grandes con nivel "seguro"' 'Típicos: java_error_in_*.hprof de IntelliJ/DataGrip/Android Studio.'
}

# ================================================================ hallazgos
$volSis = $volumenes | Where-Object { $_.es_sistema } | Select-Object -First 1
$itemsArr = $script:items.ToArray()
$recuperableSeguroGB = [math]::Round((($itemsArr | Where-Object { $_.nivel -eq 'seguro' } | ForEach-Object { [double]$_.tamano_gb } | Measure-Object -Sum).Sum), 1)
$recuperableRevisarGB = [math]::Round((($itemsArr | Where-Object { $_.nivel -eq 'revisar' } | ForEach-Object { [double]$_.tamano_gb } | Measure-Object -Sum).Sum), 1)

if ($volSis) {
    if ($volSis.usado_pct -ge 95) {
        Add-Hallazgo 'Alta' 'DISCO_CASI_LLENO' "$($volSis.unidad) al $($volSis.usado_pct)% ($($volSis.libre_gb) GB libres)." `
            'Liberar espacio ya: con menos de 5% libre fallan actualizaciones y Windows se vuelve lento.'
    } elseif ($volSis.usado_pct -ge 85) {
        Add-Hallazgo 'Media' 'DISCO_LLENO' "$($volSis.unidad) al $($volSis.usado_pct)% ($($volSis.libre_gb) GB libres)." `
            'Liberar espacio empezando por los ítems de nivel "seguro".'
    }
}
if ($recuperableSeguroGB -ge 1) {
    Add-Hallazgo 'Media' 'RECUPERABLE_SEGURO' "Hay unos $recuperableSeguroGB GB que se pueden liberar sin riesgo (temporales, cachés, volcados)." `
        'Ver los ítems con nivel "seguro". Ninguno borra datos del usuario.'
}
if ($recuperableRevisarGB -ge 1) {
    Add-Hallazgo 'Info' 'RECUPERABLE_REVISAR' "Hay unos $recuperableRevisarGB GB que dependen de una decisión del usuario (hibernación, descargas, ISOs, papelera)." `
        'Revisar uno por uno con el usuario.'
}
if ($hibernacion -eq $true) {
    $hib = $itemsArr | Where-Object { $_.nombre -eq 'Archivo de hibernación' } | Select-Object -First 1
    if ($hib -and $hib.tamano_gb -ge 4 -and $volSis -and $volSis.usado_pct -ge 85) {
        Add-Hallazgo 'Baja' 'HIBERNACION_ACTIVA' "La hibernación ocupa $($hib.tamano_gb) GB con el disco al $($volSis.usado_pct)%." `
            'Si el usuario no usa "Hibernar", desactivarla con powercfg /h off (admin).'
    }
}
$devGB = [math]::Round((($grandesOrdenados | Where-Object { $_.nivel -eq 'ver_dev_caches' } | ForEach-Object { [double]$_.tamano_gb } | Measure-Object -Sum).Sum), 1)
if ($devGB -ge 5) {
    Add-Hallazgo 'Info' 'ARCHIVOS_DESARROLLO' "$devGB GB en archivos grandes de herramientas de desarrollo (Docker, Ollama, SDKs)." `
        'Analizarlos con dev-caches.ps1 antes de tocarlos.'
}
if ($otrasUnidades.Count -gt 0 -and $volSis -and $volSis.usado_pct -ge 85) {
    $u = ($otrasUnidades | ForEach-Object { "$($_.unidad) ($($_.libre_gb) GB libres)" }) -join ', '
    Add-Hallazgo 'Info' 'OTRA_UNIDAD_DISPONIBLE' "Hay espacio en otra unidad: $u." `
        'Mover allí archivos personales grandes (videos, ISOs, instaladores). Si es una partición del mismo disco, no mejora la velocidad, solo el espacio.'
}
if ($escaneo.parcial) {
    Add-Hallazgo 'Info' 'ESCANEO_PARCIAL' "El recorrido del perfil se cortó a los $SegundosEscaneo s ($($escaneo.carpetas) carpetas revisadas)." `
        'Para el panorama completo, usar WizTree o correr con -SegundosEscaneo mayor.'
}
if (-not $esAdmin) { $script:requiereAdmin.Add('Tamaño de puntos de restauración (vssadmin list shadowstorage)') }

# ================================================================ salida
$orden = @{ Critica = 0; Alta = 1; Media = 2; Baja = 3; Info = 4 }
$hallazgosFinal = @($script:hallazgos.ToArray() | Sort-Object { $orden[$_.severidad] })
$itemsFinal     = @($itemsArr | Sort-Object { [double]$_.tamano_gb } -Descending)
$wiztree = @('C:\Program Files\WizTree\WizTree64.exe', 'C:\Program Files\WizTree\WizTree.exe') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

$resultado = [ordered]@{
    script            = 'pc-optimizer/disco.ps1'
    version           = '1.1'
    generado          = (Get-Date).ToString('s')
    solo_lectura      = $true
    volumenes         = $volumenes
    hibernacion_activa = $hibernacion
    recuperable       = [ordered]@{ seguro_gb = $recuperableSeguroGB; revisar_gb = $recuperableRevisarGB; desarrollo_gb = $devGB }
    items             = $itemsFinal
    descargas         = [ordered]@{ info = $descargasInfo; grandes = $descargasGrandes; instaladores_viejos = $instaladoresViejos }
    archivos_grandes  = [ordered]@{ escaneo = $escaneo; lista = $grandesOrdenados }
    wiztree           = $wiztree
    hallazgos         = $hallazgosFinal
    requiere_admin    = $script:requiereAdmin.ToArray()
    errores           = $script:errores.ToArray()
}

$json = $resultado | ConvertTo-Json -Depth 8
$dir = Split-Path $OutFile -Parent
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[System.IO.File]::WriteAllText($OutFile, $json, (New-Object System.Text.UTF8Encoding($false)))

$json
Write-Host ""
Write-Host "JSON guardado en: $OutFile" -ForegroundColor Cyan
