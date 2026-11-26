# Funciones compartidas por los demas scripts.
$ErrorActionPreference = 'Stop'

$Raiz = Split-Path -Parent $PSScriptRoot
$CarpetaConfig = Join-Path $Raiz 'config'

function Leer-Json([string]$Ruta) {
    if (-not (Test-Path $Ruta)) { throw "No existe el archivo: $Ruta" }
    return (Get-Content -Raw -Encoding UTF8 $Ruta | ConvertFrom-Json)
}

# Guarda JSON en UTF-8 sin BOM (lo que esperan DayZ y Expansion).
function Guardar-Json($Objeto, [string]$Ruta) {
    $texto = $Objeto | ConvertTo-Json -Depth 32
    Guardar-Texto $texto $Ruta
}

function Guardar-Texto([string]$Texto, [string]$Ruta) {
    $dir = Split-Path -Parent $Ruta
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($Ruta, $Texto, (New-Object System.Text.UTF8Encoding $false))
}

function Copia-Seguridad([string]$Ruta) {
    if (Test-Path $Ruta) {
        $marca = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item $Ruta "$Ruta.$marca.bak" -Force
    }
}

function Leer-Ajustes {
    $ajustes = Leer-Json (Join-Path $CarpetaConfig 'ajustes.json')
    # Un ajustes.local.json (no se sube a git) puede sobrescribir valores.
    $local = Join-Path $CarpetaConfig 'ajustes.local.json'
    if (Test-Path $local) {
        $extra = Leer-Json $local
        foreach ($p in $extra.PSObject.Properties) {
            $ajustes | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
        }
    }
    return $ajustes
}

function Leer-Mods {
    $mods = (Leer-Json (Join-Path $CarpetaConfig 'mods.json')).Mods
    return @($mods | Where-Object { $_.Activo })
}

function Titulo([string]$Texto) {
    Write-Host ''
    Write-Host ('=' * 70) -ForegroundColor DarkCyan
    Write-Host "  $Texto" -ForegroundColor Cyan
    Write-Host ('=' * 70) -ForegroundColor DarkCyan
}

function Ok([string]$Texto)    { Write-Host "  [OK] $Texto" -ForegroundColor Green }
function Aviso([string]$Texto) { Write-Host "  [!]  $Texto" -ForegroundColor Yellow }
function Info([string]$Texto)  { Write-Host "       $Texto" }
