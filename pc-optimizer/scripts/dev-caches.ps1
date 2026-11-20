<#
.SYNOPSIS
    pc-optimizer · Fase 3b: cachés y artefactos de herramientas de desarrollo.

.DESCRIPTION
    SOLO LECTURA. No ejecuta ningún prune, rm, clean ni uninstall: solo los sugiere como texto.
    Detecta qué herramientas existen y mide solo esas:
      Docker (imágenes, contenedores, volúmenes, build cache, disco .vhdx y cuánto se puede compactar)
      WSL (distros y tamaño de su disco)
      Ollama (modelos, tamaño real por modelo, blobs huérfanos)
      Android SDK (system-images usadas o no por algún AVD, build-tools, NDK, AVDs)
      JetBrains (cachés de versiones viejas), Gradle, Maven, npm, Yarn, pnpm, pip, Pub/Flutter, FVM, NuGet, JDKs, VS Code/Cursor
      node_modules dentro de las carpetas de proyectos
    Fase 4 (contexto): busca en las carpetas de proyectos si algún archivo menciona cada modelo de Ollama
    o cada versión de Gradle, para no marcar como basura algo que un proyecto usa.

    Sin administrador. Compatible con Windows PowerShell 5.1 y PowerShell 7+.

.PARAMETER Proyectos
    Carpetas donde están los proyectos. Por defecto: Documentos, Escritorio, source\repos y Projects si existen.

.PARAMETER SegundosBusqueda
    Tiempo máximo para buscar referencias y node_modules en los proyectos (default 60 s).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\dev-caches.ps1
    powershell -ExecutionPolicy Bypass -File .\dev-caches.ps1 -Proyectos D:\proyectos,C:\work
#>
[CmdletBinding()]
param(
    [string]$OutFile = (Join-Path $env:TEMP 'pc-optimizer\dev-caches.json'),
    [string[]]$Proyectos,
    [int]$SegundosBusqueda = 60
)

$ErrorActionPreference = 'Stop'
trap {
    Write-Error ("dev-caches.ps1 falló en la línea {0}: {1}`n{2}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message, $_.InvocationInfo.Line.Trim())
    break
}
# NOTA PS 5.1: no usar @($ListaGenerica) dentro de un literal @{} (usar .ToArray()), ni [byte] -band [int].
$script:errores   = New-Object System.Collections.Generic.List[string]
$script:hallazgos = New-Object System.Collections.Generic.List[object]
$script:items     = New-Object System.Collections.Generic.List[object]

$perfil  = $env:USERPROFILE
$local   = $env:LOCALAPPDATA
$roaming = $env:APPDATA

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

function Add-Item {
    param([string]$Herramienta, [string]$Nombre, [string]$Ruta, [double]$Bytes,
          [ValidateSet('seguro','revisar','no_tocar')][string]$Nivel,
          [string]$Accion, [string]$Nota = '', [bool]$Parcial = $false)
    $script:items.Add([ordered]@{
        herramienta = $Herramienta; nombre = $Nombre; ruta = $Ruta; tamano_gb = ConvertTo-GB $Bytes
        nivel = $Nivel; accion = $Accion; nota = $Nota; parcial = $Parcial
    })
}

function Get-TamanoCarpeta {
    param([string]$Ruta, [int]$Segundos = 20)
    $res = [ordered]@{ existe = $false; bytes = [double]0; archivos = 0; parcial = $false }
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
            foreach ($d in $di.GetDirectories()) { if ((([int]$d.Attributes) -band 1024) -eq 0) { $pila.Push($d.FullName) } }
        } catch { }
    }
    $res
}

# Mide una carpeta y la registra si pesa al menos MinimoMB.
function Measure-Carpeta {
    param([string]$Herramienta, [string]$Nombre, [string]$Ruta, [string]$Nivel, [string]$Accion,
          [string]$Nota = '', [double]$MinimoMB = 100, [int]$Segundos = 25)
    $t = Get-TamanoCarpeta $Ruta $Segundos
    if ($t.existe -and $t.bytes -ge ($MinimoMB * 1MB)) { Add-Item $Herramienta $Nombre $Ruta $t.bytes $Nivel $Accion $Nota $t.parcial }
    $t
}

# Ejecuta un programa externo con límite de tiempo (docker puede quedarse colgado si el daemon no responde).
function Invoke-Externo {
    param([string]$Exe, [string]$Argumentos, [int]$Segundos = 30)
    $r = [ordered]@{ ok = $false; salida = ''; codigo = $null; timeout = $false }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Exe; $psi.Arguments = $Argumentos
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $p = [System.Diagnostics.Process]::Start($psi)
    $tarea = $p.StandardOutput.ReadToEndAsync()
    $null = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($Segundos * 1000)) {
        try { $p.Kill() } catch { }
        $r.timeout = $true
        return $r
    }
    $r.salida = $tarea.Result
    $r.codigo = $p.ExitCode
    $r.ok = ($p.ExitCode -eq 0)
    $r
}

# "12.3GB", "512MB", "1.2kB", "0B" -> bytes
function ConvertFrom-TamanoDocker {
    param([string]$Texto)
    if (-not $Texto) { return [double]0 }
    if ($Texto -match '^\s*([\d\.]+)\s*([kKMGT]?B)') {
        $n = [double]::Parse($Matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
        switch ($Matches[2].ToUpper()) { 'KB' { return $n * 1KB } 'MB' { return $n * 1MB } 'GB' { return $n * 1GB } 'TB' { return $n * 1TB } default { return $n } }
    }
    [double]0
}

function Get-Comando { param([string]$Nombre) $c = Get-Command $Nombre -ErrorAction SilentlyContinue | Select-Object -First 1; if ($c) { $c.Source } else { $null } }

# ---------------------------------------------------------------- carpetas de proyectos (para la Fase 4)
if (-not $Proyectos -or $Proyectos.Count -eq 0) {
    $candidatas = @(
        [Environment]::GetFolderPath('MyDocuments'),
        [Environment]::GetFolderPath('Desktop'),
        (Join-Path $perfil 'source\repos'), (Join-Path $perfil 'Projects'), (Join-Path $perfil 'proyectos'),
        (Join-Path $perfil 'dev'), (Join-Path $perfil 'code'), 'C:\dev', 'C:\proyectos', 'D:\proyectos'
    )
    $Proyectos = @($candidatas | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique)
}

# Recorre los proyectos una sola vez: busca node_modules y textos que mencionen los términos dados.
function Find-EnProyectos {
    param([string[]]$Raices, [string[]]$Terminos, [int]$Segundos)
    $ext = '.py', '.js', '.mjs', '.cjs', '.ts', '.tsx', '.json', '.yml', '.yaml', '.toml', '.env', '.md', '.txt', '.ini', '.cfg',
           '.dart', '.java', '.kt', '.kts', '.gradle', '.properties', '.go', '.rs', '.php', '.cs', '.sh', '.ps1', '.bat'
    # _resultados: los JSON de esta misma skill mencionan los modelos y se contarían como "referencias" falsas.
    $saltar = 'node_modules', '.git', '.venv', 'venv', '__pycache__', 'site-packages', '.dart_tool', 'build', 'dist', 'target', '.next', '.gradle', '.idea', '_resultados'
    $dirSalida = Split-Path ([System.IO.Path]::GetFullPath($OutFile)) -Parent
    # La carpeta de la propia skill (reglas.md cita modelos y versiones como ejemplos) tampoco cuenta.
    $dirSkill = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } else { $null }
    $refs = @{}; foreach ($t in $Terminos) { $refs[$t] = New-Object System.Collections.Generic.List[string] }
    # Límite de palabra: "qwen3-vl:2b" NO debe coincidir con "qwen3-vl:2b-instruct", pero "gradle-8.7" sí con "gradle-8.7-bin".
    $regex = @{}
    foreach ($t in $Terminos) {
        $regex[$t] = New-Object System.Text.RegularExpressions.Regex(
            ([regex]::Escape($t) + '(?![\w\.]|-(?!bin\b|all\b))'),
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    $nodeModules = New-Object System.Collections.Generic.List[string]
    $res = [ordered]@{ refs = $refs; node_modules = $nodeModules; parcial = $false; archivos_leidos = 0 }
    $limite = (Get-Date).AddSeconds($Segundos)
    $cola = New-Object System.Collections.Generic.Queue[string]
    foreach ($r in $Raices) { $cola.Enqueue($r) }
    while ($cola.Count -gt 0) {
        if ((Get-Date) -gt $limite) { $res.parcial = $true; break }
        $dir = $cola.Dequeue()
        try {
            $di = New-Object System.IO.DirectoryInfo($dir)
            foreach ($d in $di.GetDirectories()) {
                if ((([int]$d.Attributes) -band 1024) -ne 0) { continue }
                if ($d.Name -eq 'node_modules') { $nodeModules.Add($d.FullName); continue }
                if ($saltar -contains $d.Name) { continue }
                if ($dirSalida -and $d.FullName -eq $dirSalida) { continue }
                if ($dirSkill -and $d.FullName -eq $dirSkill) { continue }
                $cola.Enqueue($d.FullName)
            }
            if ($Terminos.Count -eq 0) { continue }
            foreach ($f in $di.GetFiles()) {
                if ($f.Length -gt 1MB -or -not ($ext -contains $f.Extension.ToLower())) { continue }
                $texto = $null
                try { $texto = [System.IO.File]::ReadAllText($f.FullName) } catch { continue }
                $res.archivos_leidos++
                foreach ($t in $Terminos) {
                    if ($refs[$t].Count -lt 3 -and $texto.IndexOf($t, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and $regex[$t].IsMatch($texto)) {
                        $refs[$t].Add($f.FullName)
                    }
                }
            }
        } catch { }
    }
    $res
}

# ================================================================ Docker
$docker = $null
$dockerExe = Get-Comando 'docker'
$vhdxCandidatos = @(
    (Join-Path $local 'Docker\wsl\disk\docker_data.vhdx'),
    (Join-Path $local 'Docker\wsl\data\ext4.vhdx'),
    $(if ($env:ProgramData) { Join-Path $env:ProgramData 'DockerDesktop\vm-data\DockerDesktop.vhdx' })
) | Where-Object { $_ }
$vhdx = $vhdxCandidatos | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if ($dockerExe -or $vhdx) { Invoke-Seguro 'docker' {
    $script:docker = [ordered]@{ cli = $dockerExe; corriendo = $false; vhdx = $vhdx; vhdx_gb = $null; usado_gb = $null; compactable_gb = $null
                          build_cache_gb = $null; imagenes_sin_uso = @(); contenedores_detenidos = @(); volumenes_huerfanos = @() }
    if ($vhdx) { $docker.vhdx_gb = ConvertTo-GB (Get-Item -LiteralPath $vhdx -Force).Length }

    if ($dockerExe) {
        $df = Invoke-Seguro 'docker_df' { Invoke-Externo $dockerExe 'system df -v --format "{{json .}}"' 90 }
        if ($df -and $df.ok -and $df.salida.Trim().StartsWith('{')) {
            $docker.corriendo = $true
            $j = $df.salida | ConvertFrom-Json

            $imgs = @($j.Images | Where-Object { $_ })
            $sinUso = @($imgs | Where-Object { [int]$_.Containers -eq 0 })
            $docker.imagenes_sin_uso = @($sinUso | ForEach-Object {
                [ordered]@{ imagen = "$($_.Repository):$($_.Tag)"; unico_gb = ConvertTo-GB (ConvertFrom-TamanoDocker $_.UniqueSize); creada = $_.CreatedSince }
            } | Sort-Object { $_.unico_gb } -Descending)
            $bytesSinUso = [double](($sinUso | ForEach-Object { ConvertFrom-TamanoDocker $_.UniqueSize } | Measure-Object -Sum).Sum)

            $cont = @($j.Containers | Where-Object { $_ })
            $detenidos = @($cont | Where-Object { $_.State -ne 'running' })
            $docker.contenedores_detenidos = @($detenidos | ForEach-Object {
                [ordered]@{ nombre = $_.Names; imagen = $_.Image; estado = $_.Status; volumenes = $_.LocalVolumes }
            })

            $vols = @($j.Volumes | Where-Object { $_ })
            $huerfanos = @($vols | Where-Object { [int]$_.Links -eq 0 -and (ConvertFrom-TamanoDocker $_.Size) -gt 0 })
            $docker.volumenes_huerfanos = @($huerfanos | ForEach-Object {
                [ordered]@{ nombre = $_.Name; tamano_gb = ConvertTo-GB (ConvertFrom-TamanoDocker $_.Size) }
            } | Sort-Object { $_.tamano_gb } -Descending)

            $bc = @($j.BuildCache | Where-Object { $_ })
            $bytesBuild = [double](($bc | ForEach-Object { ConvertFrom-TamanoDocker $_.Size } | Measure-Object -Sum).Sum)
            $docker.build_cache_gb = ConvertTo-GB $bytesBuild

            $bytesImgs = [double](($imgs | ForEach-Object { ConvertFrom-TamanoDocker $_.UniqueSize } | Measure-Object -Sum).Sum)
            $bytesImgs += [double](($imgs | ForEach-Object { ConvertFrom-TamanoDocker $_.SharedSize } | Measure-Object -Maximum).Maximum)
            $bytesCont = [double](($cont | ForEach-Object { ConvertFrom-TamanoDocker $_.Size } | Measure-Object -Sum).Sum)
            $bytesVols = [double](($vols | ForEach-Object { ConvertFrom-TamanoDocker $_.Size } | Measure-Object -Sum).Sum)
            $usado = $bytesImgs + $bytesCont + $bytesVols + $bytesBuild
            $docker.usado_gb = ConvertTo-GB $usado

            if ($bytesBuild -ge 500MB) {
                Add-Item 'Docker' 'Build cache' '' $bytesBuild 'seguro' 'docker builder prune -a -f' 'Capas intermedias de builds. El próximo build tarda más, nada más.'
            }
            if ($bytesSinUso -ge 500MB) {
                Add-Item 'Docker' "Imágenes sin ningún contenedor ($($sinUso.Count))" '' $bytesSinUso 'seguro' 'docker image prune -a' `
                    'Solo borra imágenes que no usa ningún contenedor, ni siquiera uno detenido. Se vuelven a descargar con docker pull.'
            }
            if ($huerfanos.Count -gt 0) {
                $bytesH = [double](($huerfanos | ForEach-Object { ConvertFrom-TamanoDocker $_.Size } | Measure-Object -Sum).Sum)
                Add-Item 'Docker' "Volúmenes sin contenedor ($($huerfanos.Count))" '' $bytesH 'no_tocar' '' `
                    'Pueden ser bases de datos de proyectos. NUNCA usar docker volume prune ni system prune --volumes. Revisar uno por uno con el usuario.'
            }
            if ($vhdx -and $docker.vhdx_gb) {
                $comp = [math]::Round($docker.vhdx_gb - $docker.usado_gb, 1)
                $docker.compactable_gb = $comp
                if ($comp -ge 5) {
                    Add-Item 'Docker' 'Espacio vacío dentro del disco de Docker (.vhdx)' $vhdx ($comp * 1GB) 'revisar' `
                        ("Cerrar Docker Desktop (Quit) > wsl --shutdown > diskpart (admin): select vdisk file=`"$vhdx`" / attach vdisk readonly / compact vdisk / detach vdisk") `
                        'El .vhdx no se encoge solo al borrar imágenes. Compactar después de los prune. Detiene los contenedores mientras tanto.'
                }
            }
        } elseif ($df -and $df.timeout) {
            $script:errores.Add('docker: no respondió en 90 s (¿Docker Desktop iniciando o colgado?).')
        } else {
            Add-Hallazgo 'Info' 'DOCKER_DETENIDO' "Docker está instalado pero no está corriendo. Su disco virtual ocupa $($docker.vhdx_gb) GB." `
                'Abrir Docker Desktop y volver a correr este script para ver qué se puede limpiar dentro.'
        }
    }
} | Out-Null }

# ================================================================ WSL (distros)
$wsl = @(Invoke-Seguro 'wsl_registro' {
    Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Get-ItemProperty $_.PSPath
        if (-not $p.DistributionName) { return }
        $base = [Environment]::ExpandEnvironmentVariables([string]$p.BasePath) -replace '^\\\\\?\\', ''
        $disco = Join-Path $base 'ext4.vhdx'
        $tam = if (Test-Path -LiteralPath $disco) { (Get-Item -LiteralPath $disco -Force).Length } else { $null }
        [ordered]@{ distro = $p.DistributionName; disco = $disco; tamano_gb = ConvertTo-GB $tam
                    es_docker = ($p.DistributionName -like 'docker-desktop*') }
    }
})
$wsl = @($wsl | Where-Object { $_ })
foreach ($d in ($wsl | Where-Object { -not $_.es_docker -and $_.tamano_gb -ge 5 })) {
    Add-Item 'WSL' "Distro $($d.distro)" $d.disco ([double]$d.tamano_gb * 1GB) 'no_tocar' '' `
        "Contiene todo el Linux de esa distro. Si ya no se usa: wsl --unregister $($d.distro) (BORRA la distro). Si se usa, se puede compactar igual que el disco de Docker."
}

# ================================================================ Ollama
$ollama = $null
# OLLAMA_MODELS puede apuntar a una carpeta vacía mientras los modelos siguen en la ruta por defecto (o al revés).
# Se revisan las dos y se analiza la que de verdad tiene modelos.
$ollamaDefecto = Join-Path $perfil '.ollama\models'
function Get-ConteoManifests { param([string]$r)
    $m = Join-Path $r 'manifests'
    if ($r -and (Test-Path -LiteralPath $m)) { @(Get-ChildItem -LiteralPath $m -File -Recurse -ErrorAction SilentlyContinue).Count } else { 0 }
}
$ollamaModelos = $null
$nEnv = if ($env:OLLAMA_MODELS) { Get-ConteoManifests $env:OLLAMA_MODELS } else { 0 }
$nDef = Get-ConteoManifests $ollamaDefecto
if ($nEnv -gt 0) { $ollamaModelos = $env:OLLAMA_MODELS } elseif ($nDef -gt 0) { $ollamaModelos = $ollamaDefecto }
if ($env:OLLAMA_MODELS -and $nEnv -eq 0 -and $nDef -gt 0) {
    Add-Hallazgo 'Media' 'OLLAMA_RUTA_INCONSISTENTE' "La variable OLLAMA_MODELS apunta a '$($env:OLLAMA_MODELS)', que no tiene modelos, pero hay $nDef modelos en '$ollamaDefecto'." `
        'Decidir una sola ubicación: mover los modelos a la carpeta de OLLAMA_MODELS (con Ollama cerrado) o quitar la variable. Si Ollama se reinicia con la variable puesta, "ollama list" saldrá vacío y volverá a descargar los modelos, duplicando el espacio.'
}
if ($env:OLLAMA_MODELS -and $nEnv -gt 0 -and $nDef -gt 0) {
    Add-Hallazgo 'Media' 'OLLAMA_MODELOS_DUPLICADOS' "Hay modelos en dos carpetas: '$($env:OLLAMA_MODELS)' (en uso) y '$ollamaDefecto' ($nDef manifests)." `
        'Los de la ruta por defecto no los usa Ollama mientras OLLAMA_MODELS esté definida: confirmar y liberar esa carpeta.'
}
if ($ollamaModelos) {
    Invoke-Seguro 'ollama' {
        $blobsDir = Join-Path $ollamaModelos 'blobs'
        $blobs = @{}
        foreach ($b in (Get-ChildItem -LiteralPath $blobsDir -File -ErrorAction SilentlyContinue)) { $blobs[$b.Name] = [double]$b.Length }
        $usados = @{}
        $modelos = New-Object System.Collections.Generic.List[object]
        $raizManifests = Join-Path $ollamaModelos 'manifests'
        foreach ($m in (Get-ChildItem -LiteralPath $raizManifests -File -Recurse)) {
            $rel = $m.FullName.Substring($raizManifests.Length).TrimStart('\') -split '\\'
            # registry\namespace\modelo\tag  ->  modelo:tag (o namespace/modelo:tag si no es "library")
            if ($rel.Count -lt 4) { continue }
            $nombre = if ($rel[1] -eq 'library') { "$($rel[2]):$($rel[3])" } else { "$($rel[1])/$($rel[2]):$($rel[3])" }
            $j = Get-Content -LiteralPath $m.FullName -Raw | ConvertFrom-Json
            $capas = @($j.layers) + @($j.config) | Where-Object { $_ }
            $bytes = [double]0
            $susBlobs = New-Object System.Collections.Generic.List[string]
            foreach ($c in $capas) {
                $archivo = ([string]$c.digest) -replace ':', '-'
                if ($blobs.ContainsKey($archivo)) { $bytes += $blobs[$archivo]; $usados[$archivo] = $true; $susBlobs.Add($archivo) }
            }
            $id = (Get-FileHash -LiteralPath $m.FullName -Algorithm SHA256).Hash.ToLower()
            # Manifests internos sin nombre (p. ej. "llamacpp:<64 hex>"): el tag es el SHA-256 del propio manifest.
            # Caso real observado: el manifest con nombre de un modelo incluye como capa el blob "sha256-<tag>" de su manifest
            # interno, y el interno apunta a otros pesos (formato llama.cpp). Es decir: el interno es PARTE del modelo, no un alias.
            $interno = ($rel[3] -match '^[0-9a-f]{64}$')
            $modelos.Add([ordered]@{ modelo = $nombre; id = $id.Substring(0, 12); id_completo = $id; tamano_gb = ConvertTo-GB $bytes
                                     modificado = $m.LastWriteTime.ToString('yyyy-MM-dd'); interno = $interno
                                     tag_id = if ($interno) { $rel[3] } else { $null }; blobs = $susBlobs.ToArray() })
        }
        # Clasificar los internos: "parte de" un modelo con nombre (ese modelo lo referencia) o "resto" de un modelo ya borrado.
        $nombrados = @($modelos.ToArray() | Where-Object { -not $_.interno })
        $blobsNombrados = @{}
        foreach ($n in $nombrados) { foreach ($b in $n.blobs) { $blobsNombrados[$b] = $true } }
        foreach ($i in @($modelos.ToArray() | Where-Object { $_.interno })) {
            $tag = $i.tag_id
            $blobDelInterno = "sha256-$tag"
            $dueno = $nombrados | Where-Object { $_.id_completo -eq $tag -or ($_.blobs -contains $blobDelInterno) } | Select-Object -First 1
            $propios = @($i.blobs | Where-Object { -not $blobsNombrados.ContainsKey($_) } | Select-Object -Unique)
            $i['parte_de'] = if ($dueno) { $dueno.modelo } else { $null }
            $i['unico_gb'] = ConvertTo-GB ([double](($propios | ForEach-Object { $blobs[$_] } | Measure-Object -Sum).Sum))
            $i['blobs_propios'] = $propios
        }
        $huerfanos = @($blobs.Keys | Where-Object { -not $usados.ContainsKey($_) })
        $bytesHuerfanos = [double](($huerfanos | ForEach-Object { $blobs[$_] } | Measure-Object -Sum).Sum)
        $modelosOrdenados = @($modelos.ToArray() | Sort-Object { $_.tamano_gb } -Descending)
        $script:ollama = [ordered]@{ carpeta = $ollamaModelos; modelos = $modelosOrdenados
                                     blobs_huerfanos = $huerfanos.Count; huerfanos_gb = ConvertTo-GB $bytesHuerfanos }
        if ($bytesHuerfanos -ge 200MB) {
            Add-Item 'Ollama' "Blobs huérfanos ($($huerfanos.Count))" $blobsDir $bytesHuerfanos 'seguro' `
                'Reiniciar Ollama (al iniciar borra los blobs sin modelo) o borrarlos a mano con Ollama cerrado' `
                'Restos de descargas interrumpidas o de modelos borrados.'
        }
    } | Out-Null
}

# ================================================================ Android SDK
$android = $null
$sdk = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $local 'Android\Sdk')) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
$avdDir = if ($env:ANDROID_AVD_HOME) { $env:ANDROID_AVD_HOME } else { Join-Path $perfil '.android\avd' }
if ($sdk) {
    Invoke-Seguro 'android' {
        # Imágenes que usa algún AVD (image.sysdir.1 en config.ini)
        $usadas = @{}
        $avds = New-Object System.Collections.Generic.List[object]
        if (Test-Path -LiteralPath $avdDir) {
            foreach ($a in (Get-ChildItem -LiteralPath $avdDir -Directory -Filter '*.avd')) {
                $cfg = Join-Path $a.FullName 'config.ini'
                $img = $null
                if (Test-Path -LiteralPath $cfg) {
                    foreach ($l in Get-Content -LiteralPath $cfg) { if ($l -match '^image\.sysdir\.1\s*=\s*(.+)$') { $img = ($Matches[1].Trim() -replace '/', '\').TrimEnd('\') } }
                }
                if ($img) { $usadas[$img.ToLower()] = $true }
                $t = Get-TamanoCarpeta $a.FullName 15
                $avds.Add([ordered]@{ avd = $a.BaseName; imagen = $img; tamano_gb = ConvertTo-GB $t.bytes })
            }
        }
        $imagenes = New-Object System.Collections.Generic.List[object]
        $si = Join-Path $sdk 'system-images'
        if (Test-Path -LiteralPath $si) {
            foreach ($api in Get-ChildItem -LiteralPath $si -Directory) {
                foreach ($variante in Get-ChildItem -LiteralPath $api.FullName -Directory) {
                    foreach ($abi in Get-ChildItem -LiteralPath $variante.FullName -Directory) {
                        $rel = "system-images\$($api.Name)\$($variante.Name)\$($abi.Name)"
                        $t = Get-TamanoCarpeta $abi.FullName 15
                        $enUso = $usadas.ContainsKey($rel.ToLower())
                        $imagenes.Add([ordered]@{ imagen = $rel; tamano_gb = ConvertTo-GB $t.bytes; usada_por_avd = $enUso })
                        if (-not $enUso -and $t.bytes -ge 500MB) {
                            $pkg = $rel -replace '\\', ';'
                            Add-Item 'Android SDK' "Imagen de sistema sin AVD: $rel" $abi.FullName $t.bytes 'revisar' `
                                "Android Studio > SDK Manager > desmarcar, o: sdkmanager --uninstall `"$pkg`"" `
                                'Ningún emulador la usa. Se puede volver a descargar.'
                        }
                    }
                }
            }
        }
        foreach ($sub in 'build-tools', 'ndk') {
            $carp = Join-Path $sdk $sub
            if (-not (Test-Path -LiteralPath $carp)) { continue }
            $vers = @(Get-ChildItem -LiteralPath $carp -Directory | Sort-Object { try { [version]($_.Name -replace '[^\d\.].*$', '') } catch { [version]'0.0' } } -Descending)
            $viejas = @($vers | Select-Object -Skip 2)
            foreach ($v in $viejas) {
                $t = Get-TamanoCarpeta $v.FullName 10
                if ($t.bytes -ge 100MB) {
                    $notaSdk = 'Solo si ningún proyecto la fija en build.gradle (buildToolsVersion / ndkVersion).'
                    # Flutter usa por defecto un NDK concreto (flutter.ndkVersion), que no tiene por qué ser el más nuevo instalado.
                    # Caso real: NDK 27.0.12077973 marcado como "viejo" era justo el que usan los proyectos Flutter.
                    if ($sub -eq 'ndk' -and (Get-Comando 'flutter')) {
                        $notaSdk += ' Flutter está instalado: su NDK por defecto suele no ser el más nuevo. Ver flutter.ndkVersion en el SDK de Flutter antes de quitarlo.'
                    }
                    Add-Item 'Android SDK' "$sub $($v.Name) (hay versiones más nuevas)" $v.FullName $t.bytes 'revisar' `
                        "SDK Manager > SDK Tools > Show Package Details > desmarcar $sub $($v.Name)" $notaSdk
                }
            }
        }
        $script:android = [ordered]@{ sdk = $sdk; avds = $avds.ToArray(); system_images = $imagenes.ToArray() }
        foreach ($a in $avds) {
            if ($a.tamano_gb -ge 4) {
                Add-Item 'Android SDK' "Emulador (AVD) $($a.avd)" (Join-Path $avdDir "$($a.avd).avd") ([double]$a.tamano_gb * 1GB) 'revisar' `
                    'Device Manager > el AVD > Wipe Data (lo deja limpio) o Delete' 'Contiene las apps y datos instalados en ese emulador.'
            }
        }
    } | Out-Null
}

# ================================================================ JetBrains (cachés de versiones viejas)
$jbLocal = Join-Path $local 'JetBrains'
if (Test-Path -LiteralPath $jbLocal) {
    Invoke-Seguro 'jetbrains' {
        $dirs = @(Get-ChildItem -LiteralPath $jbLocal -Directory | Where-Object { $_.Name -match '^([A-Za-z]+?)(\d{4}\.\d+)$' } | ForEach-Object {
            $null = $_.Name -match '^([A-Za-z]+?)(\d{4}\.\d+)$'
            [pscustomobject]@{ dir = $_; producto = $Matches[1]; version = [version]$Matches[2] }
        })
        foreach ($g in ($dirs | Group-Object producto)) {
            $orden = @($g.Group | Sort-Object version -Descending)
            foreach ($viejo in ($orden | Select-Object -Skip 1)) {
                Measure-Carpeta 'JetBrains' "Caché de $($viejo.dir.Name) (hay $($orden[0].dir.Name))" $viejo.dir.FullName 'seguro' `
                    "Borrar la carpeta con el IDE cerrado" 'Solo cachés e índices de una versión que ya no se usa. La configuración está en Roaming y no se toca.' 50 | Out-Null
            }
        }
    } | Out-Null
}

# ================================================================ cachés de paquetes
$gestores = @(
    @{ h = 'Gradle';  n = 'Caché de Gradle';        r = Join-Path $perfil '.gradle\caches';       nivel = 'seguro';  a = 'Con Android Studio/IntelliJ cerrados: borrar .gradle\caches (o gradle --stop y luego borrar)'; nota = 'Se vuelve a descargar en el próximo build (el primero tarda).' }
    @{ h = 'Maven';   n = 'Repositorio de Maven';    r = Join-Path $perfil '.m2\repository';       nivel = 'revisar'; a = 'Borrar .m2\repository o solo las carpetas de dependencias viejas'; nota = 'Se vuelve a descargar. Si hay artefactos instalados a mano (mvn install de proyectos propios), se pierden.' }
    @{ h = 'npm';     n = 'Caché de npm';            r = Join-Path $local 'npm-cache';             nivel = 'seguro';  a = 'npm cache clean --force'; nota = '' }
    @{ h = 'Yarn';    n = 'Caché de Yarn';           r = Join-Path $local 'Yarn\Cache';            nivel = 'seguro';  a = 'yarn cache clean'; nota = '' }
    @{ h = 'pnpm';    n = 'Store de pnpm';           r = Join-Path $local 'pnpm\store';            nivel = 'seguro';  a = 'pnpm store prune'; nota = 'prune solo quita lo que ningún proyecto usa.' }
    @{ h = 'pip';     n = 'Caché de pip';            r = Join-Path $local 'pip\Cache';             nivel = 'seguro';  a = 'pip cache purge'; nota = '' }
    @{ h = 'Flutter'; n = 'Caché de Pub (Dart/Flutter)'; r = Join-Path $local 'Pub\Cache';        nivel = 'revisar'; a = 'flutter pub cache clean  (luego flutter pub get en cada proyecto)'; nota = 'Se vuelve a descargar; borra también paquetes activados con dart pub global.' }
    @{ h = 'NuGet';   n = 'Paquetes de NuGet';       r = Join-Path $perfil '.nuget\packages';      nivel = 'seguro';  a = 'dotnet nuget locals all --clear'; nota = '' }
    @{ h = 'VS Code'; n = 'Caché de VS Code';        r = Join-Path $roaming 'Code\CachedData';     nivel = 'seguro';  a = 'Borrar Code\CachedData y Code\Cache con VS Code cerrado'; nota = '' }
    @{ h = 'VS Code'; n = 'VSIX descargados de VS Code'; r = Join-Path $roaming 'Code\CachedExtensionVSIXs'; nivel = 'seguro'; a = 'Borrar la carpeta con VS Code cerrado'; nota = '' }
    @{ h = 'Cursor';  n = 'Caché de Cursor';         r = Join-Path $roaming 'Cursor\CachedData';   nivel = 'seguro';  a = 'Borrar con Cursor cerrado'; nota = '' }
)
foreach ($g in $gestores) { Invoke-Seguro "cache_$($g.h)" { Measure-Carpeta $g.h $g.n $g.r $g.nivel $g.a $g.nota 200 30 | Out-Null } | Out-Null }

# Gradle wrapper: distribuciones descargadas por versión (los proyectos fijan la suya).
$gradleDists = @()
$gw = Join-Path $perfil '.gradle\wrapper\dists'
if (Test-Path -LiteralPath $gw) {
    $gradleDists = @(Get-ChildItem -LiteralPath $gw -Directory | ForEach-Object {
        $t = Get-TamanoCarpeta $_.FullName 10
        [ordered]@{ distribucion = $_.Name; tamano_gb = ConvertTo-GB $t.bytes; ruta = $_.FullName }
    })
}

# JDKs descargados por IntelliJ y versiones de Flutter de FVM
$jdks = @()
$jdkDir = Join-Path $perfil '.jdks'
if (Test-Path -LiteralPath $jdkDir) {
    $jdks = @(Get-ChildItem -LiteralPath $jdkDir -Directory | ForEach-Object {
        [ordered]@{ jdk = $_.Name; tamano_gb = ConvertTo-GB (Get-TamanoCarpeta $_.FullName 10).bytes }
    })
    if ($jdks.Count -ge 3) {
        $bytesJdk = [double](($jdks | ForEach-Object { [double]$_.tamano_gb } | Measure-Object -Sum).Sum) * 1GB
        Add-Item 'JDK' "JDKs descargados ($($jdks.Count))" $jdkDir $bytesJdk 'revisar' `
            'IntelliJ > Project Structure > SDKs: quitar los que no use ningún proyecto, luego borrar su carpeta' 'Cada proyecto fija su JDK; revisar antes.'
    }
}
$fvm = @()
foreach ($fd in @((Join-Path $perfil 'fvm\versions'), (Join-Path $local 'fvm\versions'))) {
    if (Test-Path -LiteralPath $fd) {
        $fvm += @(Get-ChildItem -LiteralPath $fd -Directory | ForEach-Object {
            [ordered]@{ version = $_.Name; ruta = $_.FullName; tamano_gb = ConvertTo-GB (Get-TamanoCarpeta $_.FullName 15).bytes }
        })
    }
}
if ($fvm.Count -ge 2) {
    $bytesFvm = [double](($fvm | ForEach-Object { [double]$_.tamano_gb } | Measure-Object -Sum).Sum) * 1GB
    Add-Item 'Flutter' "Versiones de Flutter en FVM ($($fvm.Count))" '' $bytesFvm 'revisar' 'fvm remove <versión> para las que ningún proyecto usa' `
        'Cada proyecto fija su versión en .fvmrc / .fvm\fvm_config.json.'
}

# ================================================================ Fase 4: contexto en los proyectos
$terminos = New-Object System.Collections.Generic.List[string]
if ($ollama) { foreach ($m in $ollama.modelos) { if (-not $m.interno) { $terminos.Add($m.modelo) } } }
foreach ($d in $gradleDists) { $terminos.Add(($d.distribucion -replace '-(bin|all)$', '')) }
$busqueda = $null
if ($Proyectos.Count -gt 0) {
    $busqueda = Invoke-Seguro 'busqueda_proyectos' { Find-EnProyectos $Proyectos $terminos.ToArray() $SegundosBusqueda }
}

if ($ollama) {
    # Manifests internos: si un modelo con nombre lo referencia, es PARTE de ese modelo (no tocar).
    # Si nadie lo referencia, es un resto de un modelo ya borrado que retiene sus blobs.
    $restos = @($ollama.modelos | Where-Object { $_.interno -and -not $_.parte_de -and $_.unico_gb -gt 0 })
    $blobsProtegidos = @{}
    foreach ($x in @($ollama.modelos | Where-Object { $_.interno -and $_.parte_de })) { foreach ($b in $x.blobs) { $blobsProtegidos[$b] = $true } }
    if ($restos.Count -gt 0) {
        $blobsRestos = @{}
        foreach ($x in $restos) { foreach ($b in $x.blobs_propios) { if (-not $blobsProtegidos.ContainsKey($b)) { $blobsRestos[$b] = $true } } }
        $bytesRestos = [double](($blobsRestos.Keys | ForEach-Object { (Get-Item -LiteralPath (Join-Path $ollama.carpeta "blobs\$_")).Length } | Measure-Object -Sum).Sum)
        $ids = ($restos | ForEach-Object { $_.tag_id.Substring(0, 12) }) -join ', '
        Add-Item 'Ollama' "Restos internos de modelos ya borrados ($($restos.Count))" (Join-Path $ollama.carpeta 'manifests') $bytesRestos 'revisar' `
            "Con Ollama cerrado, borrar los manifests internos con ID $ids; al volver a abrir Ollama, sus blobs quedan huérfanos y se eliminan" `
            'Manifests sin nombre (no salen en "ollama list") cuyo modelo ya se borró. Retienen blobs que ningún modelo con nombre usa. Comparar los IDs con un "ollama list" anterior si se quiere saber qué modelo eran.'
    }
    foreach ($m in $ollama.modelos) {
        if ($m.interno) { $m['referencias'] = @(); continue }
        # @(...) obligatorio: un if que devuelve un arreglo de 1 elemento lo convierte en texto suelto.
        $r = @(if ($busqueda) { $busqueda.refs[$m.modelo].ToArray() })
        $m['referencias'] = $r
        if ($r.Count -eq 0 -and $m.tamano_gb -ge 0.5) {
            $nota = 'Ningún archivo de los proyectos revisados lo menciona.'
            if ($m.modelo -notmatch ':(latest|.*instruct.*|.*thinking.*)$' -and $m.modelo -match '^qwen3') {
                $nota += ' Ojo: en qwen3/qwen3-vl la etiqueta sin sufijo es la variante "thinking", distinta de "-instruct".'
            }
            Add-Item 'Ollama' "Modelo $($m.modelo)" $ollama.carpeta ([double]$m.tamano_gb * 1GB) 'revisar' "ollama rm $($m.modelo)" `
                ($nota + ' Confirmar con el usuario: puede usarse desde scripts fuera de estas carpetas.')
        }
    }
}
foreach ($d in $gradleDists) {
    $clave = $d.distribucion -replace '-(bin|all)$', ''
    $r = @(if ($busqueda) { $busqueda.refs[$clave].ToArray() })
    $d['referencias'] = $r
    if ($r.Count -eq 0 -and $d.tamano_gb -ge 0.1) {
        Add-Item 'Gradle' "Distribución $($d.distribucion)" $d.ruta ([double]$d.tamano_gb * 1GB) 'seguro' 'Borrar la carpeta' `
            'Ningún gradle-wrapper.properties de los proyectos la pide. Si alguno la necesita, se descarga sola.'
    }
}

# node_modules
$nodeModules = @()
if ($busqueda) {
    $nodeModules = @($busqueda.node_modules.ToArray() | ForEach-Object {
        $t = Get-TamanoCarpeta $_ 5
        $padre = Split-Path $_ -Parent
        [ordered]@{ ruta = $_; tamano_gb = ConvertTo-GB $t.bytes; parcial = $t.parcial
                    proyecto_modificado = (Get-Item -LiteralPath $padre).LastWriteTime.ToString('yyyy-MM-dd') }
    } | Sort-Object { $_.tamano_gb } -Descending)
    $viejos = @($nodeModules | Where-Object { [datetime]$_.proyecto_modificado -lt (Get-Date).AddDays(-90) })
    $bytesNM = [double](($viejos | ForEach-Object { [double]$_.tamano_gb } | Measure-Object -Sum).Sum) * 1GB
    if ($bytesNM -ge 500MB) {
        Add-Item 'Node' "node_modules de proyectos sin cambios en 90 días ($($viejos.Count))" '' $bytesNM 'seguro' `
            'Borrar cada node_modules listado; se regenera con npm install / pnpm install' 'Ver lista en node_modules.'
    }
}

# ================================================================ hallazgos
$itemsArr = $script:items.ToArray()
$sumar = { param($nivel) [math]::Round((($itemsArr | Where-Object { $_.nivel -eq $nivel } | ForEach-Object { [double]$_.tamano_gb } | Measure-Object -Sum).Sum), 1) }
$seguroGB  = & $sumar 'seguro'
$revisarGB = & $sumar 'revisar'
if ($seguroGB -ge 2) {
    Add-Hallazgo 'Media' 'DEV_RECUPERABLE_SEGURO' "Unos $seguroGB GB en cachés de desarrollo se pueden liberar sin perder nada (se regeneran)." `
        'Ver ítems de nivel "seguro". Cerrar los IDEs antes.'
}
if ($revisarGB -ge 2) {
    Add-Hallazgo 'Info' 'DEV_RECUPERABLE_REVISAR' "Unos $revisarGB GB dependen de decisiones (modelos, imágenes de Android, JDKs, compactar Docker)." `
        'Revisar uno por uno con el usuario; varios se usan en proyectos.'
}
if ($docker -and $docker.compactable_gb -ge 10) {
    Add-Hallazgo 'Media' 'DOCKER_COMPACTAR' "El disco de Docker ocupa $($docker.vhdx_gb) GB pero solo tiene $($docker.usado_gb) GB de datos." `
        'Compactar el .vhdx (ver acción del ítem). Hacerlo DESPUÉS de los prune para recuperar también ese espacio.'
}
if ($docker -and @($docker.volumenes_huerfanos).Count -gt 0) {
    Add-Hallazgo 'Info' 'DOCKER_VOLUMENES_HUERFANOS' "$(@($docker.volumenes_huerfanos).Count) volúmenes de Docker sin contenedor, con datos." `
        'No borrarlos en bloque: pueden ser bases de datos. Preguntar proyecto por proyecto.'
}
if ($busqueda -and $busqueda.parcial) {
    Add-Hallazgo 'Info' 'BUSQUEDA_PARCIAL' "La búsqueda en proyectos se cortó a los $SegundosBusqueda s ($($busqueda.archivos_leidos) archivos leídos)." `
        'Las referencias pueden estar incompletas: no borrar modelos solo porque "no aparecen". Usar -Proyectos con la carpeta exacta.'
}

# ================================================================ salida
$orden = @{ Critica = 0; Alta = 1; Media = 2; Baja = 3; Info = 4 }
$hallazgosFinal = @($script:hallazgos.ToArray() | Sort-Object { $orden[$_.severidad] })
$itemsFinal     = @($itemsArr | Sort-Object { [double]$_.tamano_gb } -Descending)
$herramientas = [ordered]@{
    docker = [bool]$docker; wsl = ($wsl.Count -gt 0); ollama = [bool]$ollama; android_sdk = [bool]$sdk
    jetbrains = (Test-Path -LiteralPath $jbLocal); gradle = (Test-Path -LiteralPath (Join-Path $perfil '.gradle'))
    node = [bool](Get-Comando 'node'); flutter = [bool](Get-Comando 'flutter'); python = [bool](Get-Comando 'python')
}

$resultado = [ordered]@{
    script        = 'pc-optimizer/dev-caches.ps1'
    version       = '1.4'
    generado      = (Get-Date).ToString('s')
    solo_lectura  = $true
    herramientas  = $herramientas
    proyectos_revisados = $Proyectos
    recuperable   = [ordered]@{ seguro_gb = $seguroGB; revisar_gb = $revisarGB }
    items         = $itemsFinal
    docker        = $docker
    wsl           = $wsl
    ollama        = $ollama
    android       = $android
    gradle_wrapper = $gradleDists
    jdks          = $jdks
    fvm           = $fvm
    node_modules  = $nodeModules
    busqueda      = if ($busqueda) { [ordered]@{ parcial = $busqueda.parcial; archivos_leidos = $busqueda.archivos_leidos } } else { $null }
    hallazgos     = $hallazgosFinal
    errores       = $script:errores.ToArray()
}

$json = $resultado | ConvertTo-Json -Depth 8
$dir = Split-Path $OutFile -Parent
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[System.IO.File]::WriteAllText($OutFile, $json, (New-Object System.Text.UTF8Encoding($false)))

$json
Write-Host ""
Write-Host "JSON guardado en: $OutFile" -ForegroundColor Cyan
