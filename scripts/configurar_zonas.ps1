# Aplica config\zonas.json y config\expansion\ al servidor:
#  - Zonas seguras de Expansion alrededor de los traders
#  - Zonas donde NO se puede construir (traders y zonas PvP + distancia minima)
#  - NPCs de los traders (.map)
#  - Categoria "Coleccionables" y trader "Coleccionista"
# Hay que arrancar el servidor UNA vez antes, para que Expansion cree sus archivos por defecto.
# Ejecutalo con el servidor APAGADO.
. (Join-Path $PSScriptRoot 'comun.ps1')

$aj = Leer-Ajustes
$zonas = Leer-Json (Join-Path $CarpetaConfig 'zonas.json')
$Servidor = $aj.CarpetaServidor
$Mision = Join-Path $Servidor "mpmissions\$($aj.Mision)"
$Ajustes = Join-Path $Mision 'expansion\settings'
$Perfil = Join-Path $Servidor 'profiles\ExpansionMod'

$safeFile = Join-Path $Ajustes 'SafeZoneSettings.json'
$bbFile   = Join-Path $Ajustes 'BaseBuildingSettings.json'
if (-not (Test-Path $safeFile) -or -not (Test-Path $bbFile) -or -not (Test-Path (Join-Path $Perfil 'Traders'))) {
    throw 'No encuentro los ajustes de Expansion. Arranca el servidor una vez (2-INICIAR-SERVIDOR.bat), espera a que cargue, cierralo y vuelve a ejecutar esto.'
}
if (Get-Process -Name 'DayZServer_x64' -ErrorAction SilentlyContinue) {
    throw 'El servidor esta encendido. Cierralo antes (si no, sobrescribira estos cambios al guardar).'
}

function Es-Cero($v) { return ([double]$v[0] -eq 0 -and [double]$v[2] -eq 0) }
function Vec($v) { return @([double]$v[0], [double]$v[1], [double]$v[2]) }

$traders = @($zonas.Traders | Where-Object { $_.Activo })
$pvp     = @($zonas.ZonasPvP | Where-Object { $_.Activo })

foreach ($t in $traders) {
    if (Es-Cero $t.Centro) { throw "El trader '$($t.Nombre)' esta activo pero su Centro es 0,0,0. Pon las coordenadas reales." }
    foreach ($n in $t.NPCs) {
        if (Es-Cero $n.Posicion) { throw "El NPC $($n.Clase) ($($n.Trader)) de '$($t.Nombre)' tiene Posicion 0,0,0." }
    }
}
foreach ($z in $pvp) {
    if (Es-Cero $z.Centro) { throw "La zona PvP '$($z.Nombre)' esta activa pero su Centro es 0,0,0." }
}

# ------------------------------------------------ 1) Archivos de mercado propios
Titulo '1/4  Mercado: Coleccionables y Coleccionista'
foreach ($sub in 'Market', 'Traders') {
    $origen = Join-Path $CarpetaConfig "expansion\$sub"
    $destino = Join-Path $Perfil $sub
    New-Item -ItemType Directory -Force -Path $destino | Out-Null
    foreach ($f in Get-ChildItem $origen -Filter *.json) {
        Copy-Item $f.FullName (Join-Path $destino $f.Name) -Force
        Ok "$sub\$($f.Name)"
    }
}

# ------------------------------------------------ 2) Zonas seguras
Titulo '2/4  Zonas seguras (traders)'
$safe = Leer-Json $safeFile
Copia-Seguridad $safeFile
$circulos = New-Object System.Collections.ArrayList
foreach ($t in $traders) {
    [void]$circulos.Add([pscustomobject]@{ Center = (Vec $t.Centro); Radius = [double]$t.RadioZonaSegura })
    Ok "$($t.Nombre): radio $($t.RadioZonaSegura) m"
}
$safe | Add-Member -NotePropertyName Enabled -NotePropertyValue ([int]($traders.Count -gt 0)) -Force
$safe | Add-Member -NotePropertyName CircleZones -NotePropertyValue @($circulos) -Force
Guardar-Json $safe $safeFile
if ($traders.Count -eq 0) { Aviso 'No hay traders activos: zonas seguras desactivadas.' }

# ------------------------------------------------ 3) Zonas sin construccion
Titulo '3/4  Zonas donde no se puede construir'
$bb = Leer-Json $bbFile
Copia-Seguridad $bbFile
$prefijo = '[auto] '
# Conserva las zonas que hayas anadido a mano (las que no empiezan por [auto])
$lista = New-Object System.Collections.ArrayList
foreach ($z in @($bb.Zones)) { if ($z -and -not "$($z.Name)".StartsWith($prefijo)) { [void]$lista.Add($z) } }

foreach ($t in $traders) {
    $r = [double]$t.RadioZonaSegura + [double]$zonas.DistanciaMinimaBasesATraders
    [void]$lista.Add([pscustomobject]@{
        Name = "$prefijo$($t.Nombre)"; Center = (Vec $t.Centro); Radius = $r
        Items = @(); IsWhitelist = 1
        CustomMessage = "No se puede construir a menos de $($zonas.DistanciaMinimaBasesATraders) m de un trader."
    })
    Ok "$($t.Nombre): sin bases en $r m"
}
foreach ($z in $pvp) {
    $r = [double]$z.Radio + [double]$zonas.DistanciaMinimaBasesAPvP
    [void]$lista.Add([pscustomobject]@{
        Name = "$prefijo$($z.Nombre)"; Center = (Vec $z.Centro); Radius = $r
        Items = @(); IsWhitelist = 1
        CustomMessage = "No se puede construir a menos de $($zonas.DistanciaMinimaBasesAPvP) m de una zona PvP."
    })
    Ok "$($z.Nombre): sin bases en $r m (zona PvP $($z.Radio) m + $($zonas.DistanciaMinimaBasesAPvP) m)"
}
$bb | Add-Member -NotePropertyName Zones -NotePropertyValue @($lista) -Force
$bb | Add-Member -NotePropertyName ZonesAreNoBuildZones -NotePropertyValue 1 -Force
Guardar-Json $bb $bbFile

# ------------------------------------------------ 4) NPCs de traders
Titulo '4/4  NPCs de los traders'
$mapFile = Join-Path $Mision 'expansion\traders\zonas_auto.map'
$lineas = New-Object System.Collections.ArrayList
$cultura = [System.Globalization.CultureInfo]::InvariantCulture
foreach ($t in $traders) {
    foreach ($n in $t.NPCs) {
        $traderJson = Join-Path $Perfil "Traders\$($n.Trader).json"
        if (-not (Test-Path $traderJson)) { Aviso "No existe Traders\$($n.Trader).json - revisa el nombre." }
        $pos = ($n.Posicion | ForEach-Object { ([double]$_).ToString('0.###', $cultura) }) -join ' '
        $ori = ([double]$n.Orientacion).ToString('0.###', $cultura) + ' 0 0'
        $linea = "$($n.Clase).$($n.Trader)|$pos|$ori"
        if ($n.Ropa) { $linea += "|$($n.Ropa)" }
        [void]$lineas.Add($linea)
    }
}
if ($lineas.Count -gt 0) {
    Guardar-Texto (($lineas -join "`r`n") + "`r`n") $mapFile
    Ok "$($lineas.Count) NPCs escritos en $mapFile"
} elseif (Test-Path $mapFile) {
    Remove-Item $mapFile
    Aviso 'Sin traders activos: se ha quitado zonas_auto.map'
}

# ------------------------------------------------ Resumen para PVEZ
Titulo 'Zonas PvP para configurar en PVEZ'
if ($pvp.Count -eq 0) { Aviso 'No hay zonas PvP activas en config\zonas.json.' }
foreach ($z in $pvp) {
    Info ("{0}:  X={1}  Z={2}  Radio={3} m" -f $z.Nombre, $z.Centro[0], $z.Centro[2], $z.Radio)
}
Info 'PVEZ guarda sus zonas en su propia configuracion: crea estas mismas zonas desde su menu de admin'
Info 'o su archivo de configuracion (mira la pagina del mod en el Workshop).'
Write-Host ''
Ok 'Hecho. Ya puedes arrancar el servidor.'
