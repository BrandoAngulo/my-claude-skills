<#
.SYNOPSIS
    Instala el hook commit-msg que quita las líneas de atribución a IA (Co-Authored-By: Claude, Claude-Session, etc.)
    en todos los repos git que encuentre bajo las carpetas indicadas.

.DESCRIPTION
    - Si el repo ya tiene un commit-msg propio, lo renombra a commit-msg.previo y el hook nuevo lo ejecuta después
      (no se pierde nada).
    - Si el repo ya tiene este mismo hook, lo actualiza.
    - Si el repo usa core.hooksPath (husky, lefthook, etc.), NO lo toca y lo reporta: ahí hay que agregarlo a mano
      en la carpeta de hooks del proyecto.
    - -Simular muestra qué haría sin cambiar nada.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\instalar-hook-commit.ps1 -Simular
    powershell -ExecutionPolicy Bypass -File .\instalar-hook-commit.ps1
    powershell -ExecutionPolicy Bypass -File .\instalar-hook-commit.ps1 -Raices C:\work,D:\proyectos
#>
[CmdletBinding()]
param(
    [string[]]$Raices = @((Join-Path $env:USERPROFILE 'Documents'), (Join-Path $env:USERPROFILE 'Desktop')),
    [int]$Profundidad = 5,
    [switch]$Simular
)

$ErrorActionPreference = 'Stop'
$hook  = Join-Path $PSScriptRoot 'commit-msg'
$marca = 'hook-sin-atribucion-ia'
if (-not (Test-Path -LiteralPath $hook)) { throw "No encuentro el hook en $hook" }
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) { throw 'git no está en el PATH.' }

$saltar = 'node_modules', '.venv', 'venv', 'vendor', 'build', 'dist', 'target', '.dart_tool'
$repos = New-Object System.Collections.Generic.List[string]
foreach ($raiz in $Raices) {
    if (-not (Test-Path -LiteralPath $raiz)) { continue }
    $cola = New-Object System.Collections.Generic.Queue[object]
    $cola.Enqueue(@($raiz, 0))
    while ($cola.Count -gt 0) {
        $item = $cola.Dequeue(); $dir = $item[0]; $nivel = $item[1]
        if (Test-Path -LiteralPath (Join-Path $dir '.git') -PathType Container) { $repos.Add($dir); continue }
        if ($nivel -ge $Profundidad) { continue }
        try {
            foreach ($d in (New-Object System.IO.DirectoryInfo($dir)).GetDirectories()) {
                if ((([int]$d.Attributes) -band 1024) -ne 0) { continue }   # enlaces / junctions
                if ($saltar -contains $d.Name -or $d.Name.StartsWith('.')) { continue }
                $cola.Enqueue(@($d.FullName, ($nivel + 1)))
            }
        } catch { }
    }
}

$resumen = New-Object System.Collections.Generic.List[object]
foreach ($repo in $repos) {
    $hooksPath = (& git -C $repo config --get core.hooksPath 2>$null)
    if ($hooksPath) {
        $resumen.Add([pscustomobject]@{ Repo = $repo; Resultado = "OMITIDO: usa core.hooksPath ($hooksPath). Agregar a mano." }); continue
    }
    $destDir = Join-Path $repo '.git\hooks'
    $dest    = Join-Path $destDir 'commit-msg'
    $accion  = 'instalado'
    if (Test-Path -LiteralPath $dest) {
        $contenido = Get-Content -LiteralPath $dest -Raw -ErrorAction SilentlyContinue
        if ($contenido -and $contenido.Contains($marca)) {
            $accion = 'actualizado'
        } else {
            $accion = 'instalado (el commit-msg anterior quedó como commit-msg.previo y se sigue ejecutando)'
            if (-not $Simular) { Move-Item -LiteralPath $dest -Destination (Join-Path $destDir 'commit-msg.previo') -Force }
        }
    }
    if (-not $Simular) {
        if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -LiteralPath $hook -Destination $dest -Force
    }
    $resumen.Add([pscustomobject]@{ Repo = $repo; Resultado = $(if ($Simular) { "[simulación] $accion" } else { $accion }) })
}

$resumen | Format-Table -AutoSize -Wrap | Out-String -Width 250 | Write-Host
"{0} repos encontrados." -f $repos.Count
if ($Simular) { 'Simulación: no se cambió nada. Quita -Simular para instalar.' }
