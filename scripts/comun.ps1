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

# ---------------------------------------------------------------------------------------------
# Lectura de los nombres de objetos (classnames) de un mod sin types.xml, desde sus .pbo.
# Lee config.bin (binarizado, formato "raP") o config.cpp (texto) y devuelve las clases de
# CfgVehicles con scope = 2 (las que se pueden crear en el juego).
# ---------------------------------------------------------------------------------------------
function Leer-Asciiz([System.IO.BinaryReader]$br) {
    $bytes = New-Object System.Collections.Generic.List[byte]
    while ($true) { $b = $br.ReadByte(); if ($b -eq 0) { break }; $bytes.Add($b) }
    return [System.Text.Encoding]::UTF8.GetString($bytes.ToArray())
}
function Leer-IntComprimido([System.IO.BinaryReader]$br) {
    $valor = 0; $desp = 0
    while ($true) { $b = $br.ReadByte(); $valor = $valor -bor (($b -band 0x7F) -shl $desp); if (($b -band 0x80) -eq 0) { break }; $desp += 7 }
    return $valor
}
function Saltar-ArrayRap([System.IO.BinaryReader]$br) {
    $n = Leer-IntComprimido $br
    for ($i = 0; $i -lt $n; $i++) {
        $t = $br.ReadByte()
        switch ($t) { 0 { [void](Leer-Asciiz $br) } 1 { [void]$br.ReadSingle() } 2 { [void]$br.ReadInt32() } 3 { Saltar-ArrayRap $br } 4 { [void](Leer-Asciiz $br) } default { [void]$br.ReadInt32() } }
    }
}
# Lee el cuerpo de una clase rap: devuelve @{ Clases = @(@{Nombre;Offset}); Scope = int o $null }
function Leer-ClaseRap([System.IO.BinaryReader]$br, [long]$offset) {
    $br.BaseStream.Position = $offset
    [void](Leer-Asciiz $br)   # clase padre
    $n = Leer-IntComprimido $br
    $clases = New-Object System.Collections.ArrayList; $scope = $null
    for ($i = 0; $i -lt $n; $i++) {
        $t = $br.ReadByte()
        switch ($t) {
            0 { $nom = Leer-Asciiz $br; $off = $br.ReadUInt32(); [void]$clases.Add(@{ Nombre = $nom; Offset = [long]$off }) }
            1 {
                $sub = $br.ReadByte(); $nom = Leer-Asciiz $br
                switch ($sub) { 0 { [void](Leer-Asciiz $br) } 1 { [void]$br.ReadSingle() } 2 { $v = $br.ReadInt32(); if ($nom -ieq 'scope') { $scope = $v } } 4 { [void](Leer-Asciiz $br) } default { [void]$br.ReadInt32() } }
            }
            2 { [void](Leer-Asciiz $br); Saltar-ArrayRap $br }
            3 { [void](Leer-Asciiz $br) }
            4 { [void](Leer-Asciiz $br) }
            5 { [void]$br.ReadUInt32(); [void](Leer-Asciiz $br); Saltar-ArrayRap $br }
            default { throw "Entrada rap desconocida ($t)" }
        }
    }
    return @{ Clases = $clases; Scope = $scope }
}
function Clases-DeConfigBin([byte[]]$datos) {
    $res = New-Object System.Collections.ArrayList
    $ms = New-Object System.IO.MemoryStream(, $datos)
    $br = New-Object System.IO.BinaryReader($ms)
    try {
        if ($datos.Length -lt 16 -or $datos[0] -ne 0 -or $datos[1] -ne 0x72 -or $datos[2] -ne 0x61 -or $datos[3] -ne 0x50) { return @() }
        $raiz = Leer-ClaseRap $br 16
        foreach ($c in $raiz.Clases) {
            if ($c.Nombre -ine 'CfgVehicles') { continue }
            $veh = Leer-ClaseRap $br $c.Offset
            foreach ($hija in $veh.Clases) {
                $info = Leer-ClaseRap $br $hija.Offset
                if ($info.Scope -eq 2) { [void]$res.Add($hija.Nombre) }
            }
        }
    } catch { } finally { $br.Close() }
    return @($res)
}
function Clases-DeConfigCpp([string]$texto) {
    # Aproximado: clases de CfgVehicles que declaran scope = 2
    $res = New-Object System.Collections.ArrayList
    $i = $texto.IndexOf('CfgVehicles', [StringComparison]::OrdinalIgnoreCase)
    if ($i -lt 0) { return @() }
    foreach ($m in [regex]::Matches($texto.Substring($i), '(?s)class\s+(\w+)\s*(?::\s*\w+)?\s*\{([^{}]*)')) {
        if ($m.Groups[2].Value -match 'scope\s*=\s*2\s*;') { [void]$res.Add($m.Groups[1].Value) }
    }
    return @($res)
}
function Clases-DePbo([string]$ruta) {
    $res = New-Object System.Collections.ArrayList
    $fs = [System.IO.File]::OpenRead($ruta)
    $br = New-Object System.IO.BinaryReader($fs)
    try {
        $entradas = New-Object System.Collections.ArrayList
        $primera = $true
        while ($true) {
            $nombre = Leer-Asciiz $br
            $metodo = $br.ReadUInt32(); $orig = $br.ReadUInt32(); [void]$br.ReadUInt32(); [void]$br.ReadUInt32(); $tam = $br.ReadUInt32()
            if ($primera -and $nombre -eq '' -and $metodo -eq 0x56657273) {
                while ((Leer-Asciiz $br) -ne '') { [void](Leer-Asciiz $br) }   # extensiones (prefix, ...)
                $primera = $false; continue
            }
            $primera = $false
            if ($nombre -eq '') { break }
            [void]$entradas.Add(@{ Nombre = $nombre; Metodo = $metodo; Tam = [long]$tam })
        }
        $pos = $fs.Position
        foreach ($e in $entradas) {
            $hoja = ($e.Nombre -split '[\\/]')[-1]
            if ($e.Metodo -eq 0 -and ($hoja -ieq 'config.bin' -or $hoja -ieq 'config.cpp')) {
                $fs.Position = $pos
                $datos = $br.ReadBytes([int]$e.Tam)
                if ($hoja -ieq 'config.bin') { foreach ($c in (Clases-DeConfigBin $datos)) { [void]$res.Add($c) } }
                else { foreach ($c in (Clases-DeConfigCpp ([System.Text.Encoding]::UTF8.GetString($datos)))) { [void]$res.Add($c) } }
            }
            $pos += $e.Tam
        }
    } catch { } finally { $br.Close() }
    return @($res)
}
function Clases-DeMod([string]$carpetaMod) {
    $todas = New-Object System.Collections.Generic.HashSet[string]([StringComparer]::OrdinalIgnoreCase)
    foreach ($pbo in Get-ChildItem $carpetaMod -Recurse -File -Filter *.pbo -ErrorAction SilentlyContinue) {
        foreach ($c in (Clases-DePbo $pbo.FullName)) { [void]$todas.Add($c) }
    }
    return @($todas | Sort-Object)
}
