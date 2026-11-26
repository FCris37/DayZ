# Aplica la configuracion del proyecto a los archivos de Expansion del servidor:
#   1. Mercado: Coleccionables, Coleccionista y categorias de los mods (BBP, MuchStuffPack, retro)
#   2. Zonas seguras de los traders
#   3. Zonas donde no se puede construir + candados en vallas/puertas BBP
#   4. NPCs de los traders
#   5. Patrullas de bandidos (IA) en las zonas PvP
#   6. Garaje, zombis, animales, vehiculos vanilla, minimapa y stamina
#   7. Quests propias: busqueda del tesoro, pieles y diarios
# Hay que arrancar el servidor UNA vez antes (Expansion crea sus archivos por defecto) y
# ejecutar esto con el servidor APAGADO. Se puede repetir cuantas veces quieras.
. (Join-Path $PSScriptRoot 'comun.ps1')

$aj = Leer-Ajustes
$zonas = Leer-Json (Join-Path $CarpetaConfig 'zonas.json')
$todosMods = @((Leer-Json (Join-Path $CarpetaConfig 'mods.json')).Mods | Where-Object { $_.Activo })
$Servidor = $aj.CarpetaServidor
$Mision = Join-Path $Servidor "mpmissions\$($aj.Mision)"
$AjustesMision = Join-Path $Mision 'expansion\settings'
$Perfil = Join-Path $Servidor 'profiles\ExpansionMod'
$AjustesPerfil = Join-Path $Perfil 'Settings'
$prefijo = '[auto] '
$cultura = [System.Globalization.CultureInfo]::InvariantCulture

$safeFile = Join-Path $AjustesMision 'SafeZoneSettings.json'
$bbFile   = Join-Path $AjustesMision 'BaseBuildingSettings.json'
if (-not (Test-Path $safeFile) -or -not (Test-Path $bbFile) -or -not (Test-Path (Join-Path $Perfil 'Traders'))) {
    throw 'No encuentro los ajustes de Expansion. Arranca el servidor una vez (2-INICIAR-SERVIDOR.bat), espera a que cargue del todo, cierralo y vuelve a ejecutar esto.'
}
if (Get-Process -Name 'DayZServer_x64' -ErrorAction SilentlyContinue) {
    throw 'El servidor esta encendido. Cierralo antes (si no, sobrescribira estos cambios al guardar).'
}

function Es-Cero($v) { return ([double]$v[0] -eq 0 -and [double]$v[2] -eq 0) }
function Vec($v) { return @([double]$v[0], [double]$v[1], [double]$v[2]) }
function Poner($obj, [string]$campo, $valor) { $obj | Add-Member -NotePropertyName $campo -NotePropertyValue $valor -Force }
function Num($v) { return ([double]$v).ToString('0.###', $cultura) }

$traders = @($zonas.Traders | Where-Object { $_.Activo })
$pvp     = @($zonas.ZonasPvP | Where-Object { $_.Activo })

foreach ($t in $traders) {
    if (Es-Cero $t.Centro) { throw "El trader '$($t.Nombre)' esta activo pero su Centro es 0,0,0." }
    foreach ($n in $t.NPCs) {
        if (Es-Cero $n.Posicion) { throw "El NPC $($n.Clase) ($($n.Trader)) de '$($t.Nombre)' tiene Posicion 0,0,0. Pon la posicion real (con la altura Y del suelo)." }
    }
}
foreach ($z in $pvp) {
    if (Es-Cero $z.Centro) { throw "La zona PvP '$($z.Nombre)' esta activa pero su Centro es 0,0,0." }
}

# ======================================================================= 1) Mercado
Titulo '1/7  Mercado'
$dirMarket = Join-Path $Perfil 'Market'
$dirTraders = Join-Path $Perfil 'Traders'
foreach ($sub in 'Market', 'Traders') {
    foreach ($f in Get-ChildItem (Join-Path $CarpetaConfig "expansion\$sub") -Filter *.json) {
        Copy-Item $f.FullName (Join-Path (Join-Path $Perfil $sub) $f.Name) -Force
        Ok "$sub\$($f.Name)"
    }
}

# Categorias generadas a partir del types.xml de cada mod
$generadas = @{}
# "Mercado" puede ser una categoria o una lista de categorias (p. ej. armas por un lado y accesorios por otro)
$listaMercados = foreach ($mm in ($todosMods | Where-Object { $_.Mercado })) {
    foreach ($cc in @($mm.Mercado)) { [pscustomobject]@{ Mod = $mm; Cat = $cc } }
}
foreach ($par in @($listaMercados)) {
    $m = $par.Mod; $c = $par.Cat
    $tiposDir = Join-Path $Mision "mods_ce\$($m.Carpeta.TrimStart('@'))"
    $tiposFiles = @(Get-ChildItem $tiposDir -Filter *.xml -ErrorAction SilentlyContinue)
    if ($tiposFiles.Count -eq 0) { Aviso "$($m.Carpeta): no hay types.xml en la mision (ejecuta el instalador). Categoria '$($c.Nombre)' omitida."; continue }

    # Objetos que ya estan en otra categoria (Expansion no permite repetirlos)
    $existentes = @{}
    foreach ($f in Get-ChildItem $dirMarket -Filter *.json) {
        if ($f.BaseName -eq $c.Archivo) { continue }
        try { foreach ($i in (Leer-Json $f.FullName).Items) { $existentes[$i.ClassName.ToLower()] = $true } } catch { }
    }
    foreach ($k in $generadas.Keys) { $existentes[$k] = $true }

    $items = New-Object System.Collections.ArrayList
    $todosTipos = foreach ($tf in $tiposFiles) { ([xml](Get-Content -Raw -Encoding UTF8 $tf.FullName)).types.type }
    foreach ($t in $todosTipos) {
        $n = "$($t.name)"
        if (-not $n -or $n -notmatch $c.Filtro -or $existentes.ContainsKey($n.ToLower())) { continue }
        $existentes[$n.ToLower()] = $true; $generadas[$n.ToLower()] = $true
        [void]$items.Add([pscustomobject]@{
            ClassName = $n; MaxPriceThreshold = [int]$c.PrecioMax; MinPriceThreshold = [int]$c.PrecioMin
            SellPricePercent = -1; MaxStockThreshold = 50; MinStockThreshold = 0; QuantityPercent = -1
            SpawnAttachments = @(); Variants = @()
        })
    }
    if ($items.Count -eq 0) { Aviso "$($m.Carpeta): ningun objeto cumple el filtro '$($c.Filtro)'."; continue }
    Guardar-Json ([pscustomobject]@{
        m_Version = 12; DisplayName = $c.Nombre; Icon = 'Deliver'; Color = 'FBFCFEFF'
        IsExchange = 0; InitStockPercent = 0.0; Items = @($items)
    }) (Join-Path $dirMarket "$($c.Archivo).json")

    $traderFile = Join-Path $dirTraders "$($c.Trader).json"
    if (Test-Path $traderFile) {
        $tr = Leer-Json $traderFile
        $entrada = "$($c.Archivo):$($c.Modo)"
        $cats = @(@($tr.Categories) | Where-Object { $_ -and -not "$_".StartsWith("$($c.Archivo):") -and "$_" -ne $c.Archivo })
        Poner $tr 'Categories' @($cats + $entrada)
        Guardar-Json $tr $traderFile
        Ok "$($c.Nombre): $($items.Count) objetos -> trader $($c.Trader)"
    } else {
        Aviso "$($c.Nombre): no existe el trader $($c.Trader). Categoria creada pero sin trader."
    }
}

# ======================================================================= 1b) Mercado central
Titulo '1b    Mercado central'
$lineasMercado = New-Object System.Collections.ArrayList
$posAbe = $null
$objetosFile = Join-Path $Servidor 'profiles\DayZKit\objetos.json'
$mc = $zonas.Mercado
if ($mc -and $mc.Activo) {
    if (Es-Cero $mc.Centro) { throw 'El Mercado esta activo pero su Centro es 0,0,0.' }
    $cx = [double]$mc.Centro[0]; $cy = [double]$mc.Centro[1]; $cz = [double]$mc.Centro[2]
    $rad = [math]::PI / 180
    function Norm([double]$a) { while ($a -gt 180) { $a -= 360 }; while ($a -le -180) { $a += 360 }; return $a }
    function Sen([double]$g) { return [math]::Sin($g * $rad) }
    function Cos_([double]$g) { return [math]::Cos($g * $rad) }
    $objetos = New-Object System.Collections.ArrayList
    function Obj([string]$clase, [double]$x, [double]$z, [double]$yaw, [double]$alt) {
        [void]$objetos.Add([pscustomobject]@{ Clase = $clase; X = [math]::Round($x, 3); Z = [math]::Round($z, 3); Yaw = [math]::Round((Norm $yaw), 2); Altura = $alt })
    }

    # --- Traders combinados (uno por caseta)
    function Crear-Combo([string]$archivo, [string]$nombre, $lista) {
        $base = $null; $cats = New-Object System.Collections.ArrayList; $items = [pscustomobject]@{}
        foreach ($t in $lista) {
            $f = Join-Path $dirTraders "$t.json"
            if (-not (Test-Path $f)) { Aviso "Caseta '$nombre': no existe el trader $t"; continue }
            $tr = Leer-Json $f
            if (-not $base) { $base = $tr }
            foreach ($c in @($tr.Categories)) { if ($c -and -not $cats.Contains($c)) { [void]$cats.Add($c) } }
            if ($tr.Items) { foreach ($p in $tr.Items.PSObject.Properties) { $items | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force } }
        }
        if (-not $base) { return $false }
        Poner $base 'DisplayName' $nombre
        Poner $base 'Categories' @($cats)
        Poner $base 'Items' $items
        Guardar-Json $base (Join-Path $dirTraders "$archivo.json")
        return $true
    }

    # Casetas en forma de U: repartidas por el circulo dejando libre un hueco de
    # "AperturaEntrada" grados hacia la direccion "Entrada" (0 = norte, 90 = este).
    $casetas = @($mc.Casetas)
    $n = $casetas.Count
    $R = [double]$mc.Radio
    $g = [double]$mc.Entrada
    $ap = [double]$mc.AperturaEntrada
    $techo = $mc.Techo
    for ($i = 0; $i -lt $n; $i++) {
        $c = $casetas[$i]
        $archivo = 'Mercado_' + ($c.Nombre -replace '[^A-Za-z0-9]', '')
        $titulo = if ($c.Titulo) { $c.Titulo } else { $c.Nombre }
        if (-not (Crear-Combo $archivo $titulo @($c.Traders))) { continue }
        if ($n -gt 1) { $theta = $g + $ap / 2 + $i * (360.0 - $ap) / ($n - 1) } else { $theta = $g + 180 }
        $nx = $cx + $R * (Sen $theta); $nz = $cz + $R * (Cos_ $theta)
        $yaw = Norm ($theta + 180)                      # el NPC mira al centro del mercado
        $fx = Sen $yaw; $fz = Cos_ $yaw                 # hacia delante (clientes)
        $rx = Sen ($yaw + 90); $rz = Cos_ ($yaw + 90)   # a su derecha
        if ($techo) {
            # Un tejado sobre el vendedor y el mostrador, y otro delante para los clientes
            Obj $techo ($nx + $fx * 0.4) ($nz + $fz * 0.4) $yaw 0
            Obj $techo ($nx + $fx * 3.0) ($nz + $fz * 3.0) $yaw 0
        }
        Obj 'StaticObj_Misc_Table_Market'   ($nx + $fx * 1.0) ($nz + $fz * 1.0) ($yaw - 180) 0
        Obj 'ExpansionPointLight'           ($nx + $fx * 1.0) ($nz + $fz * 1.0) 0 2.3
        if ($c.Cartel -and $mc.Carteles -ne $false) { Obj $c.Cartel ($nx + $fx * 1.6 + $rx * 2.6) ($nz + $fz * 1.6 + $rz * 2.6) ($yaw + 180) 0 }
        # Exposicion: objetos fijos (no se pueden coger) sobre el mostrador y en el suelo junto al vendedor
        $expo = @($c.Exposicion | Where-Object { $_ })
        for ($k = 0; $k -lt $expo.Count; $k++) {
            $o = if ($expo.Count -gt 1) { -0.8 + 1.6 * $k / ($expo.Count - 1) } else { 0 }
            Obj $expo[$k] ($nx + $fx * 1.0 + $rx * $o) ($nz + $fz * 1.0 + $rz * $o) ($yaw + 90 + 25 * (($k % 3) - 1)) 0.9
        }
        $suelo = @($c.Suelo | Where-Object { $_ })
        for ($k = 0; $k -lt [math]::Min(2, $suelo.Count); $k++) {
            $lado = if ($k -eq 0) { 1 } else { -1 }
            Obj $suelo[$k] ($nx + $rx * 1.1 * $lado - $fx * 0.1) ($nz + $rz * 1.1 * $lado - $fz * 0.1) ($yaw + 30 * $lado) 0
        }
        Obj 'StaticObj_Misc_WoodenCrate_3x' ($nx - $fx * 0.8 + $rx * 1.6) ($nz - $fz * 0.8 + $rz * 1.6) $yaw 0
        Obj 'StaticObj_Misc_BoxWooden'      ($nx - $fx * 0.8 - $rx * 1.6) ($nz - $fz * 0.8 - $rz * 1.6) $yaw 0
        # El NPC muestra el nombre de la caseta en espanol (palabra clave name: de Expansion)
        $equipo = @(); if ($c.Ropa) { $equipo += $c.Ropa }; $equipo += "name:$titulo"
        [void]$lineasMercado.Add("$($c.NPC).$archivo|$(Num $nx) $(Num $nz)|$(Num $yaw) 0 0|$($equipo -join ',')")
        Ok ("Caseta {0}: {1}" -f $c.Nombre, (@($c.Traders) -join ' + '))
    }

    # --- Centro: bandera (al fondo, opuesta a la entrada) y Abe el Cazatesoros mirando a la entrada
    Obj 'ExpansionPropFlagExpansion' ($cx + 3 * (Sen ($g + 180))) ($cz + 3 * (Cos_ ($g + 180))) $g 0
    $posAbe = @(($cx + 1 * (Sen $g)), 0, ($cz + 1 * (Cos_ $g)))
    Ok "Centro: bandera y Abe el Cazatesoros (entrada hacia $g grados)"

    # --- Decoracion
    if ($mc.Decoracion) {
        $antes = $objetos.Count
        # Farolas entre casetas y a los lados de la entrada
        for ($i = 0; $i -lt $n - 1; $i++) {
            $t1 = $g + $ap / 2 + ($i + 0.5) * (360.0 - $ap) / ($n - 1)
            Obj 'Land_Power_Pole_Wood1_Lamp_Amp' ($cx + ($R + 3) * (Sen $t1)) ($cz + ($R + 3) * (Cos_ $t1)) ($t1 + 180) 0
        }
        foreach ($lado in -1, 1) {
            $t1 = $g + $lado * ($ap / 2 - 12)
            Obj 'Land_Power_Pole_Wood1_Lamp_Amp' ($cx + ($R + 2) * (Sen $t1)) ($cz + ($R + 2) * (Cos_ $t1)) ($t1 + 180) 0
        }
        # Detras de cada caseta: palets y barriles; delante: flores a los lados del tejado
        for ($i = 0; $i -lt $n; $i++) {
            $th = $g + $ap / 2 + $i * (360.0 - $ap) / ($n - 1)
            $bx = $cx + ($R + 3.5) * (Sen $th); $bz = $cz + ($R + 3.5) * (Cos_ $th)
            $px = Sen ($th + 90); $pz = Cos_ ($th + 90)
            if ($i % 2 -eq 0) { Obj 'StaticObj_Misc_Pallets2' ($bx + $px * 1.5) ($bz + $pz * 1.5) $th 0 }
            else { Obj 'StaticObj_Misc_WoodenCrate_5x' ($bx + $px * 1.5) ($bz + $pz * 1.5) $th 0 }
            Obj 'ExpansionIndustrialProp_Barrel1' ($bx - $px * 1.8) ($bz - $pz * 1.8) 0 0
            $fx = $cx + ($R - 4.5) * (Sen $th); $fz = $cz + ($R - 4.5) * (Cos_ $th)
            Obj 'StaticObj_Furniture_flowers_01' ($fx + $px * 3.2) ($fz + $pz * 3.2) 0 0
            Obj 'StaticObj_Furniture_flowers_02' ($fx - $px * 3.2) ($fz - $pz * 3.2) 0 0
        }
        # Plaza central: bancos mirando al centro, bidones con fuego y una mesa con sillas
        foreach ($a in 140, 220) {
            $t1 = $g + $a
            Obj 'StaticObj_Misc_Bench1' ($cx + 6.5 * (Sen $t1)) ($cz + 6.5 * (Cos_ $t1)) ($t1 + 90) 0
        }
        foreach ($a in 100, 260) {
            $t1 = $g + $a
            Obj 'bldr_fire_barrel' ($cx + 5 * (Sen $t1)) ($cz + 5 * (Cos_ $t1)) 0 0
        }
        $mx = $cx + 7 * (Sen ($g + 180)); $mz = $cz + 7 * (Cos_ ($g + 180))
        Obj 'StaticObj_Furniture_table_umakart' $mx $mz $g 0
        Obj 'ExpansionPropLawnChair' ($mx + 1.2 * (Sen ($g + 90))) ($mz + 1.2 * (Cos_ ($g + 90))) ($g - 90) 0
        Obj 'ExpansionPropLawnChair' ($mx - 1.2 * (Sen ($g + 90))) ($mz - 1.2 * (Cos_ ($g + 90))) ($g + 90) 0
        # Helipuerto: luces de pista en circulo y cartel
        $hp = $mc.EntregaHelicopteros
        if ($hp -and $hp.Posicion) {
            $hx = [double]$hp.Posicion[0]; $hz = [double]$hp.Posicion[2]
            for ($k = 0; $k -lt 8; $k++) { $t1 = $k * 45; Obj 'StaticObj_Airfield_Light_Edge' ($hx + 10 * (Sen $t1)) ($hz + 10 * (Cos_ $t1)) 0 0 }
            $t1 = [math]::Atan2($cx - $hx, $cz - $hz) / $rad
            Obj 'ExpansionSign_Trader_Aircraft' ($hx + 12 * (Sen $t1)) ($hz + 12 * (Cos_ $t1)) ($t1 + 180) 0
        }
        # Aparcamiento: farolas en los extremos y cartel
        $ec = $mc.EntregaCoches
        if ($ec -and $ec.Desde -and $ec.Hasta) {
            foreach ($pt in @($ec.Desde, $ec.Hasta)) {
                $t1 = [math]::Atan2($cx - [double]$pt[0], $cz - [double]$pt[2]) / $rad
                Obj 'Land_Power_Pole_Wood1_Lamp_Amp' ([double]$pt[0] - 6 * (Sen $t1)) ([double]$pt[2] - 6 * (Cos_ $t1)) $t1 0
            }
            $sx = ([double]$ec.Desde[0] + [double]$ec.Hasta[0]) / 2; $sz = ([double]$ec.Desde[2] + [double]$ec.Hasta[2]) / 2
            $t1 = [math]::Atan2($cx - $sx, $cz - $sz) / $rad
            Obj 'ExpansionSign_Trader_Vehicles' ($sx - 7 * (Sen $t1)) ($sz - 7 * (Cos_ $t1)) ($t1 + 180) 0
        }
        Ok "Decoracion: $($objetos.Count - $antes) objetos (farolas, palets, flores, bancos, fuego, helipuerto...)"
    }

    Guardar-Json ([pscustomobject]@{ Objetos = @($objetos) }) $objetosFile
    Ok "$($objetos.Count) objetos decorativos (los coloca el mod @DayZKit a ras de suelo)"

    # --- Puntos de entrega de vehiculos comprados
    $mkFile = Join-Path $AjustesMision 'MarketSettings.json'
    if (Test-Path $mkFile) {
        $mk = Leer-Json $mkFile
        Copia-Seguridad $mkFile
        function Puntos($cfg, [int]$cuantos, [double]$sep) {
            $lista = New-Object System.Collections.ArrayList
            if (-not $cfg) { return @() }
            if ($cfg.Desde -and $cfg.Hasta) {
                # Fila de plazas entre dos puntos; los vehiculos miran hacia el mercado salvo que se indique Orientacion
                $x1 = [double]$cfg.Desde[0]; $z1 = [double]$cfg.Desde[2]; $x2 = [double]$cfg.Hasta[0]; $z2 = [double]$cfg.Hasta[2]
                $largo = [math]::Sqrt(($x2 - $x1) * ($x2 - $x1) + ($z2 - $z1) * ($z2 - $z1))
                $num = if ($cfg.Plazas) { [int]$cfg.Plazas } else { [math]::Max(1, [int][math]::Floor($largo / 7) + 1) }
                $yBase = [double]$cfg.Desde[1]
                for ($k = 0; $k -lt $num; $k++) {
                    $t = if ($num -gt 1) { $k / ($num - 1) } else { 0.5 }
                    $x = $x1 + ($x2 - $x1) * $t; $z = $z1 + ($z2 - $z1) * $t
                    $o = if ($null -ne $cfg.Orientacion) { [double]$cfg.Orientacion } else { [math]::Atan2($cx - $x, $cz - $z) / $rad }
                    [void]$lista.Add([pscustomobject]@{ Position = @([math]::Round($x, 2), [math]::Round($yBase + 0.5, 2), [math]::Round($z, 2)); Orientation = @((Norm $o), 0.0, 0.0) })
                }
                return @($lista)
            }
            if ($cfg.Posicion) {
                # Punto fijo: las plazas se reparten en fila, perpendiculares a la Orientacion
                $a = [double]$cfg.Orientacion; $px = [double]$cfg.Posicion[0]; $pz = [double]$cfg.Posicion[2]; $cy = [double]$cfg.Posicion[1]
            } else {
                $a = [double]$cfg.Angulo; $d = [double]$cfg.Distancia
                $px = $cx + $d * (Sen $a); $pz = $cz + $d * (Cos_ $a)
            }
            for ($k = 0; $k -lt $cuantos; $k++) {
                $o = ($k - ($cuantos - 1) / 2.0) * $sep
                $x = $px + $o * (Sen ($a + 90)); $z = $pz + $o * (Cos_ ($a + 90))
                [void]$lista.Add([pscustomobject]@{ Position = @([math]::Round($x, 2), [math]::Round($cy + 0.5, 2), [math]::Round($z, 2)); Orientation = @((Norm $a), 0.0, 0.0) })
            }
            return @($lista)
        }
        $land = @(Puntos $mc.EntregaCoches ([int]$(if ($mc.EntregaCoches.Plazas) { $mc.EntregaCoches.Plazas } else { 3 })) 7)
        $air = @(Puntos $mc.EntregaHelicopteros 1 0)
        $water = @(Puntos $mc.EntregaBarcas 1 0)
        if ($land.Count) { Poner $mk 'LandSpawnPositions' $land }
        if ($air.Count) { Poner $mk 'AirSpawnPositions' $air }
        if ($water.Count) { Poner $mk 'WaterSpawnPositions' $water }
        Guardar-Json $mk $mkFile
        Ok "Entrega de vehiculos: $($land.Count) puntos de coches, $($air.Count) de helicopteros, $($water.Count) de barcas"
        if (-not $water.Count) { Aviso 'Sin punto de entrega de barcas: no se podran comprar barcas (pon EntregaBarcas en zonas.json).' }
    }

    # La zona segura y la zona sin bases del mercado se tratan como un trader mas
    $traders += [pscustomobject]@{ Nombre = 'Mercado central'; Centro = $mc.Centro; RadioZonaSegura = $mc.RadioZonaSegura; NPCs = @() }
} else {
    if (Test-Path $objetosFile) { Remove-Item $objetosFile }
    Info 'Mercado central desactivado en config\zonas.json.'
}

# ======================================================================= 2) Zonas seguras
Titulo '2/7  Zonas seguras (traders)'
$safe = Leer-Json $safeFile
Copia-Seguridad $safeFile
$circulos = New-Object System.Collections.ArrayList
foreach ($t in $traders) {
    [void]$circulos.Add([pscustomobject]@{ Center = (Vec $t.Centro); Radius = [double]$t.RadioZonaSegura })
    Ok "$($t.Nombre): radio $($t.RadioZonaSegura) m"
}
Poner $safe 'Enabled' ([int]($traders.Count -gt 0))
Poner $safe 'CircleZones' @($circulos)
Guardar-Json $safe $safeFile
if ($traders.Count -eq 0) { Aviso 'No hay traders activos todavia: zonas seguras desactivadas.' }

# ======================================================================= 3) Bases
Titulo '3/7  Bases: zonas sin construccion y candados'
$bb = Leer-Json $bbFile
Copia-Seguridad $bbFile
$lista = New-Object System.Collections.ArrayList
foreach ($z in @($bb.Zones)) { if ($z -and -not "$($z.Name)".StartsWith($prefijo)) { [void]$lista.Add($z) } }
foreach ($t in $traders) {
    $r = [double]$t.RadioZonaSegura + [double]$zonas.DistanciaMinimaBasesATraders
    [void]$lista.Add([pscustomobject]@{
        Name = "$prefijo$($t.Nombre)"; Center = (Vec $t.Centro); Radius = $r; Items = @(); IsWhitelist = 1
        CustomMessage = "No se puede construir a menos de $($zonas.DistanciaMinimaBasesATraders) m de un trader."
    })
    Ok "$($t.Nombre): sin bases en $r m"
}
foreach ($z in $pvp) {
    $r = [double]$z.Radio + [double]$zonas.DistanciaMinimaBasesAPvP
    [void]$lista.Add([pscustomobject]@{
        Name = "$prefijo$($z.Nombre)"; Center = (Vec $z.Centro); Radius = $r; Items = @(); IsWhitelist = 1
        CustomMessage = "No se puede construir a menos de $($zonas.DistanciaMinimaBasesAPvP) m de una zona PvP."
    })
    Ok "$($z.Nombre): sin bases en $r m"
}
Poner $bb 'Zones' @($lista)
Poner $bb 'ZonesAreNoBuildZones' 1
# 2 = candados en puertas de Expansion + vallas vanilla/BBP + tiendas de campana
Poner $bb 'CodelockAttachMode' 2
Guardar-Json $bb $bbFile
Ok 'Candados de Expansion permitidos en puertas BBP, vallas y tiendas'

# ======================================================================= 4) NPCs de traders
Titulo '4/7  NPCs de los traders'
$mapFile = Join-Path $Mision 'expansion\traders\zonas_auto.map'
$lineas = New-Object System.Collections.ArrayList
foreach ($l in $lineasMercado) { [void]$lineas.Add($l) }
foreach ($t in $traders) {
    foreach ($n in @($t.NPCs)) {
        if (-not (Test-Path (Join-Path $dirTraders "$($n.Trader).json"))) { Aviso "No existe Traders\$($n.Trader).json - revisa el nombre." }
        $pos = ($n.Posicion | ForEach-Object { Num $_ }) -join ' '
        $linea = "$($n.Clase).$($n.Trader)|$pos|$(Num $n.Orientacion) 0 0"
        if ($n.Ropa) { $linea += "|$($n.Ropa)" }
        [void]$lineas.Add($linea)
    }
}
if ($lineas.Count -gt 0) {
    Guardar-Texto (($lineas -join "`r`n") + "`r`n") $mapFile
    Ok "$($lineas.Count) NPCs en $mapFile"
} else {
    if (Test-Path $mapFile) { Remove-Item $mapFile }
    Aviso 'Sin traders activos (rellena sus coordenadas en config\zonas.json).'
}

# ======================================================================= 5) Bandidos IA
Titulo '5/7  Patrullas de bandidos en zonas PvP'
$aiFile = Join-Path $AjustesMision 'AIPatrolSettings.json'
if (Test-Path $aiFile) {
    $ai = Leer-Json $aiFile
    Copia-Seguridad $aiFile
    $b = $zonas.Bandidos
    $patrullas = New-Object System.Collections.ArrayList
    foreach ($p in @($ai.Patrols)) { if ($p -and -not "$($p.Name)".StartsWith($prefijo)) { [void]$patrullas.Add($p) } }
    foreach ($z in ($pvp | Where-Object { [int]$_.Bandidos -gt 0 })) {
        [void]$patrullas.Add([pscustomobject]@{
            Name = "$prefijo$($z.Nombre)"; Persist = 0; Faction = $b.Faccion; Formation = 'RANDOM'; FormationScale = -1.0
            FormationLooseness = 0.5; Loadout = $b.Equipo; Units = @()
            NumberOfAI = 2; NumberOfAIMax = [int]$z.Bandidos
            Behaviour = 'ROAMING_LOCAL'; LootingBehaviour = 'ALL'; Speed = 'WALK'; UnderThreatSpeed = 'SPRINT'
            DefaultStance = 'STANDING'; CanBeLooted = [int][bool]$b.SePuedenSaquear; UnlimitedReload = 0
            AccuracyMin = [double]$b.PrecisionMin; AccuracyMax = [double]$b.PrecisionMax
            ThreatDistanceLimit = -1; NoiseInvestigationDistanceLimit = -1; MaxFlankingDistance = -1; EnableFlankingOutsideCombat = -1
            DamageMultiplier = -1; DamageReceivedMultiplier = -1
            CanSpawnInContaminatedArea = 0; CanBeTriggeredByAI = 0
            MinDistRadius = -2; MaxDistRadius = -2; DespawnRadius = -1
            MinSpreadRadius = 0; MaxSpreadRadius = [double]$z.Radio * 0.5
            Chance = 1.0; DespawnTime = -1; RespawnTime = [double]$b.SegundosParaReaparecer
            UseRandomWaypointAsStartPoint = 1; Waypoints = @(, (Vec $z.Centro))
        })
        Ok "$($z.Nombre): patrulla de 2 a $($z.Bandidos) bandidos"
    }
    Poner $ai 'Patrols' @($patrullas)
    if ($patrullas.Count -gt 0) { Poner $ai 'Enabled' 1 }
    Guardar-Json $ai $aiFile
} else { Aviso "No existe $aiFile (Expansion AI no cargado?)." }

# ======================================================================= 6) Garaje
Titulo '6/7  Garaje de vehiculos'
$garFile = Join-Path $AjustesPerfil 'GarageSettings.json'
if (Test-Path $garFile) {
    $gar = Leer-Json $garFile
    Copia-Seguridad $garFile
    Poner $gar 'Enabled' ([int][bool]$zonas.Garaje.Activo)
    Guardar-Json $gar $garFile
    Ok "Garaje: $(if ($zonas.Garaje.Activo) { 'activado' } else { 'desactivado' })"
} else { Aviso "No existe $garFile." }

# ======================================================================= 6b) Jugabilidad
Titulo '6b    Zombis, animales, vehiculos, minimapa y stamina'
$zb = $zonas.Zombis
$an = $zonas.Animales
$jg = $zonas.Jugabilidad
$fZ = if ($zb) { [double]$zb.Multiplicador } else { 1.0 }
$fA = if ($an) { [double]$an.Multiplicador } else { 1.0 }
function Escalar([string]$v, [double]$f) { return [string][int][math]::Round([double]$v * $f) }
# Siempre se calcula desde una copia del original: repetir el script no vuelve a multiplicar.
function Original([string]$archivo) {
    $orig = [IO.Path]::ChangeExtension($archivo, '.original.xml')
    if (-not (Test-Path $orig)) { Copy-Item $archivo $orig }
    return $orig
}
function Cargar-Xml([string]$ruta) { $x = New-Object System.Xml.XmlDocument; $x.PreserveWhitespace = $true; $x.Load($ruta); return $x }

# --- Territorios de zombis (cuantos aparecen en cada zona)
$terrFile = Join-Path $Mision 'env\zombie_territories.xml'
if (Test-Path $terrFile) {
    $xmlT = Cargar-Xml (Original $terrFile)
    $nZonas = 0
    foreach ($zona in $xmlT.SelectNodes('//zone')) {
        foreach ($a in 'smin', 'smax', 'dmin', 'dmax') { if ($zona.HasAttribute($a)) { $zona.SetAttribute($a, (Escalar $zona.GetAttribute($a) $fZ)) } }
        $nZonas++
    }
    $xmlT.Save($terrFile)
    Ok "Zombis x$fZ en $nZonas zonas del mapa"
}

# --- Eventos: Infected* (zombis), Animal*/Ambient* (animales), Vehicle* vanilla (desactivar)
$vanilla = @()
if ($zonas.Vehiculos -and $zonas.Vehiculos.QuitarVanilla) { $vanilla = @($zonas.Vehiculos.EventosVanilla) }
$evFile = Join-Path $Mision 'db\events.xml'
if (Test-Path $evFile) {
    $orig = Cargar-Xml (Original $evFile)
    $actual = Cargar-Xml $evFile
    $nZ = 0; $nA = 0; $nV = 0
    foreach ($e in $orig.SelectNodes('//event')) {
        $nombre = $e.GetAttribute('name')
        $dest = $actual.SelectSingleNode("//event[@name='$nombre']")
        if (-not $dest) { continue }
        $f = 0
        if ($nombre -like 'Infected*') { $f = $fZ; $nZ++ }
        elseif ($nombre -like 'Animal*' -or $nombre -like 'Ambient*') { $f = $fA; $nA++ }
        if ($f -gt 0) {
            foreach ($campo in 'nominal', 'min', 'max') {
                $o = $e.SelectSingleNode($campo); $d = $dest.SelectSingleNode($campo)
                if ($o -and $d) { $d.InnerText = (Escalar $o.InnerText $f) }
            }
        }
        $act = $dest.SelectSingleNode('active')
        if ($act) {
            if ($vanilla -contains $nombre) { $act.InnerText = '0'; $nV++ }
            else { $o = $e.SelectSingleNode('active'); if ($o) { $act.InnerText = $o.InnerText } }
        }
    }
    Copia-Seguridad $evFile
    $actual.Save($evFile)
    Ok "Zombis x$fZ en $nZ eventos de infectados"
    Ok "Animales x$fA en $nA eventos de animales"
    if ($vanilla.Count) { Ok "Vehiculos vanilla desactivados: $nV eventos (los de Expansion siguen)" }
}

# Expansion redefine algunos coches vanilla en su propio archivo de eventos
$expEv = Join-Path $Mision 'expansion_ce\expansion_events.xml'
if ((Test-Path $expEv) -and $vanilla.Count) {
    $x = Cargar-Xml $expEv
    $n = 0
    foreach ($nombre in $vanilla) {
        $act = $x.SelectSingleNode("//event[@name='$nombre']/active")
        if ($act -and $act.InnerText -ne '0') { $act.InnerText = '0'; $n++ }
    }
    if ($n) { Copia-Seguridad $expEv; $x.Save($expEv) }
}

# --- Maximos globales
$globFile = Join-Path $Mision 'db\globals.xml'
if (Test-Path $globFile) {
    $glob = Cargar-Xml $globFile
    Copia-Seguridad $globFile
    foreach ($par in @(@('ZombieMaxCount', $zb.MaximoGlobal), @('AnimalMaxCount', $an.MaximoGlobal))) {
        $var = $glob.SelectSingleNode("//var[@name='$($par[0])']")
        if ($var -and $par[1]) { $var.SetAttribute('value', [string][int]$par[1]); Ok "$($par[0]) = $($par[1])" }
    }
    $glob.Save($globFile)
}

# --- Minimapa (GPS de Expansion sin necesitar el objeto GPS) y brujula
$mapFile = Join-Path $AjustesMision 'MapSettings.json'
if ($jg -and $jg.Minimapa -and (Test-Path $mapFile)) {
    $mp = Leer-Json $mapFile
    Copia-Seguridad $mapFile
    foreach ($par in @(@('EnableHUDGPS', 1), @('NeedGPSItemForKeyBinding', 0), @('NeedMapItemForKeyBinding', 0),
                       @('CanOpenMapWithKeyBinding', 1), @('EnableHUDCompass', 1), @('NeedCompassItemForHUDCompass', 0), @('NeedGPSItemForHUDCompass', 0))) {
        Poner $mp $par[0] $par[1]
    }
    Guardar-Json $mp $mapFile
    Ok 'Minimapa y brujula sin necesitar objetos (se activan con su tecla)'
}

# --- Marcadores en el mapa (en espanol): mercado, aparcamiento, helipuerto y zonas PvP
if (Test-Path $mapFile) {
    $mp = Leer-Json $mapFile
    $marc = New-Object System.Collections.ArrayList
    foreach ($m in @($mp.ServerMarkers)) { if ($m -and -not "$($m.m_UID)".StartsWith('DayZKit_')) { [void]$marc.Add($m) } }
    function Marcador([string]$id, [string]$texto, [string]$icono, [int]$color, $pos, [int]$vis) {
        [void]$marc.Add([pscustomobject]@{ m_UID = "DayZKit_$id"; m_Visibility = $vis; m_Is3D = 1; m_Text = $texto; m_IconName = $icono; m_Color = $color; m_Position = (Vec $pos); m_Locked = 1; m_Persist = 1 })
    }
    $verde = -13710223; $rojo = -1618884; $azul = -13331237
    if ($zonas.Mercado -and $zonas.Mercado.Activo) {
        $mc = $zonas.Mercado
        Marcador 'Mercado' 'Mercado central' 'Trader' $verde $mc.Centro 6
        if ($mc.EntregaCoches -and $mc.EntregaCoches.Desde) {
            $d1 = $mc.EntregaCoches.Desde; $d2 = $mc.EntregaCoches.Hasta
            Marcador 'Aparcamiento' 'Aparcamiento' 'Car' $azul @((([double]$d1[0] + [double]$d2[0]) / 2), [double]$d1[1], (([double]$d1[2] + [double]$d2[2]) / 2)) 4
        }
        if ($mc.EntregaHelicopteros -and $mc.EntregaHelicopteros.Posicion) { Marcador 'Helipuerto' 'Helipuerto' 'Helicopter' $azul $mc.EntregaHelicopteros.Posicion 4 }
    }
    $k = 0
    foreach ($z in $pvp) { $k++; Marcador "PvP$k" ("Zona PvP - " + ($z.Nombre -replace '^PvP\s*-\s*', '')) 'Skull' $rojo $z.Centro 4 }
    Poner $mp 'EnableServerMarkers' 1
    Poner $mp 'ShowNameOnServerMarkers' 1
    Poner $mp 'ServerMarkers' @($marc)
    Guardar-Json $mp $mapFile
    Ok "Marcadores en el mapa: $(@($marc | Where-Object { "$($_.m_UID)".StartsWith('DayZKit_') }).Count)"
}

# --- Stamina infinita (cfggameplay.json de la mision)
$gpFile = Join-Path $Mision 'cfggameplay.json'
if ($jg -and $jg.SinStamina -and (Test-Path $gpFile)) {
    $gp = Leer-Json $gpFile
    Copia-Seguridad $gpFile
    $st = $gp.PlayerData.StaminaData
    foreach ($c in 'sprintStaminaModifierErc', 'sprintStaminaModifierCro', 'sprintSwimmingStaminaModifier', 'sprintLadderStaminaModifier',
                   'meleeStaminaModifier', 'obstacleTraversalStaminaModifier', 'holdBreathStaminaModifier', 'staminaKgToStaminaPercentPenalty') {
        Poner $st $c 0.0
    }
    Guardar-Json $gp $gpFile
    Ok 'Stamina: correr, nadar, saltar y pelear ya no la gastan'
}

# ======================================================================= 7) Quests
Titulo '7/7  Quests'
$q = $zonas.Quests
$dirQ = Join-Path $Perfil 'Quests'
if (-not $q.Activo) {
    Info 'Quests propias desactivadas en zonas.json (se dejan las de Expansion como esten).'
} elseif (-not (Test-Path $dirQ)) {
    Aviso "No existe $dirQ (Expansion Quests no cargado?)."
} else {
    # Copia de seguridad de las quests por defecto la primera vez
    $marca = Join-Path $dirQ '.configurado-por-script'
    if (-not (Test-Path $marca)) {
        $copia = Join-Path $Perfil "Quests.original-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $dirQ $copia -Recurse
        Ok "Quests originales guardadas en $copia"
    }
    # Vaciar quests, NPCs y objetivos (se mantienen las carpetas para que Expansion no regenere los de por defecto)
    foreach ($d in @('Quests', 'NPCs') + @(Get-ChildItem (Join-Path $dirQ 'Objectives') -Directory | ForEach-Object { "Objectives\$($_.Name)" })) {
        Get-ChildItem (Join-Path $dirQ $d) -Filter *.json -ErrorAction SilentlyContinue | Remove-Item -Force
    }
    foreach ($d in 'Quests', 'NPCs', 'Objectives\TreasureHunt', 'Objectives\Collection') { New-Item -ItemType Directory -Force -Path (Join-Path $dirQ $d) | Out-Null }

    $npc = $q.NPC
    Guardar-Json ([pscustomobject]@{
        ConfigVersion = 6; ID = 1; ClassName = $npc.Clase; Position = $(if ($posAbe) { Vec $posAbe } else { Vec $npc.Posicion }); Orientation = @($(if ($posAbe) { [double]$zonas.Mercado.Entrada } else { [double]$npc.Orientacion }), 0.0, 0.0)
        NPCName = $npc.Nombre; DefaultNPCText = 'Busco cosas perdidas de esta isla. Si encuentras algo, pagare bien.'
        Waypoints = @(); NPCEmoteID = 46; NPCEmoteIsStatic = 0; NPCLoadoutFile = $npc.Equipo
        NPCInteractionEmoteID = 1; NPCQuestCancelEmoteID = 60; NPCQuestStartEmoteID = 58; NPCQuestCompleteEmoteID = 39
        NPCFaction = 'InvincibleObservers'; NPCType = 0; Active = 1
    }) (Join-Path $dirQ 'NPCs\QuestNPC_1.json')

    function Loot($nombre, [double]$prob, [int]$min, [int]$max) {
        return [pscustomobject]@{ Name = $nombre; Attachments = @(); Chance = $prob; QuantityPercent = -1; Max = $max; Min = $min; Variants = @() }
    }
    $botin = @(
        (Loot 'JMC_Book_DIARYFROST' 0.3 1 1), (Loot 'JMC_Book_DIARYCARGO' 0.3 1 1), (Loot 'JMC_Book_DIARYLOVE' 0.3 1 1),
        (Loot 'JMC_Radio_CassetteTape_MusicTape2' 0.4 1 1), (Loot 'JMC_Radio_CassetteTape_MusicTape3' 0.4 1 1),
        (Loot 'SRP_GladiusSword_Ornamental' 0.1 1 1), (Loot 'Jmc_Mjolnir' 0.03 1 1),
        (Loot 'Bear_Pink' 0.3 1 1), (Loot 'Deagle_Gold' 0.05 1 1)
    )
    $puntos = New-Object System.Collections.ArrayList
    foreach ($pt in $q.PuntosTesoro) { [void]$puntos.Add((Vec $pt)) }
    Guardar-Json ([pscustomobject]@{
        ConfigVersion = 28; ID = 1; ObjectiveType = 6; ObjectiveText = 'Encuentra y desentierra el alijo'
        TimeLimit = -1; Active = 1; ShowDistance = 0; ContainerName = 'ExpansionQuestSeaChest'; DigInStash = 1
        MarkerName = 'Alijo enterrado'; MarkerVisibility = 4; Positions = @($puntos); Loot = $botin
        LootItemsAmount = 4; MaxDistance = 10.0
    }) (Join-Path $dirQ 'Objectives\TreasureHunt\Objective_TH_1.json')

    function Coleccion($cls, [int]$n) { return [pscustomobject]@{ Amount = $n; ClassName = $cls; QuantityPercent = -1; MinQuantityPercent = -1 } }
    Guardar-Json ([pscustomobject]@{
        ConfigVersion = 28; ID = 1; ObjectiveType = 4; ObjectiveText = 'Consigue 3 pieles de lobo'
        TimeLimit = -1; Active = 1; Collections = @((Coleccion 'WolfPelt' 3)); ShowDistance = 1
        AddItemsToNearbyMarketZone = 0; NeedAnyCollection = 0
    }) (Join-Path $dirQ 'Objectives\Collection\Objective_C_1.json')

    $diarios = 'JMC_Book_KMUC','JMC_Book_NAMALSK','JMC_Book_DIARYFROST','JMC_Book_DIARYHCRINCI','JMC_Book_DIARYBARINGER','JMC_Book_DIARYCARGO','JMC_Book_DIARYTELEPORT','JMC_Book_DIARYLOVE'
    Guardar-Json ([pscustomobject]@{
        ConfigVersion = 28; ID = 2; ObjectiveType = 4; ObjectiveText = 'Trae un diario perdido de Deer Isle'
        TimeLimit = -1; Active = 1; Collections = @($diarios | ForEach-Object { Coleccion $_ 1 }); ShowDistance = 1
        AddItemsToNearbyMarketZone = 0; NeedAnyCollection = 1
    }) (Join-Path $dirQ 'Objectives\Collection\Objective_C_2.json')

    function Quest([int]$id, $titulo, $desc, $objTexto, $objetivo, [int]$dinero, [bool]$diaria) {
        return [pscustomobject]@{
            ConfigVersion = 22; ID = $id; Type = 1; Title = $titulo
            Descriptions = @($desc, 'Vuelve cuando lo tengas.', 'Buen trabajo. Aqui tienes lo prometido.')
            ObjectiveText = $objTexto; FollowUpQuest = -1; Repeatable = 1; IsDailyQuest = [int]$diaria; IsWeeklyQuest = 0
            CancelQuestOnPlayerDeath = 0; Autocomplete = 0; IsGroupQuest = 0; ObjectSetFileName = ''
            QuestItems = @(); Rewards = @([pscustomobject]@{ ClassName = 'ExpansionBanknoteHryvnia'; Amount = $dinero; Attachments = @(); DamagePercent = 0; QuestID = -1; Chance = 1.0 })
            NeedToSelectReward = 0; RandomReward = 0; RandomRewardAmount = -1; RewardsForGroupOwnerOnly = 1
            QuestGiverIDs = @(1); QuestTurnInIDs = @(1); IsAchievement = 0; Objectives = @($objetivo)
            QuestColor = 0; ReputationReward = 0; ReputationRequirement = -1; PreQuestIDs = @(); RequiredFaction = ''; FactionReward = ''
            PlayerNeedQuestItems = 1; DeleteQuestItems = 1; SequentialObjectives = 1; SuppressQuestLogOnCompetion = 0; Active = 1
        }
    }
    function Obj([int]$id, [int]$tipo) { return [pscustomobject]@{ ConfigVersion = 28; ID = $id; ObjectiveType = $tipo } }

    Guardar-Json (Quest 1 'Tesoro enterrado' 'Un viejo pescador enterro sus cosas en algun pueblo de la isla. Toma una pala, sigue la marca del mapa y desentierralo.' 'Desentierra el alijo' (Obj 1 6) ([int]$q.RecompensaTesoro) $true) (Join-Path $dirQ 'Quests\Quest_1.json')
    Guardar-Json (Quest 2 'Pieles de lobo' 'Los lobos estan acabando con el ganado. Traeme 3 pieles de lobo.' 'Entrega 3 pieles de lobo' (Obj 1 4) ([int]$q.RecompensaPieles) $false) (Join-Path $dirQ 'Quests\Quest_2.json')
    Guardar-Json (Quest 3 'Diarios perdidos' 'Colecciono los diarios de quienes vivieron aqui. Traeme cualquiera que encuentres.' 'Entrega un diario de Deer Isle' (Obj 2 4) ([int]$q.RecompensaDiario) $false) (Join-Path $dirQ 'Quests\Quest_3.json')

    Set-Content -Path $marca -Value (Get-Date -Format s)
    Ok "NPC '$($npc.Nombre)' en X=$($npc.Posicion[0]) Z=$($npc.Posicion[2])"
    Ok "Quests: Tesoro enterrado (diaria, $($puntos.Count) escondites), Pieles de lobo, Diarios perdidos"
}

# ======================================================================= Resumen PVEZ
Titulo 'Zonas PvP para configurar en PVEZ'
foreach ($z in $pvp) { Info ("{0}:  X={1}  Z={2}  Radio={3} m" -f $z.Nombre, $z.Centro[0], $z.Centro[2], $z.Radio) }
Info 'PVEZ guarda sus zonas por su cuenta: crea estas mismas desde su menu de admin o su configuracion.'
Write-Host ''
Ok 'Hecho. Ya puedes arrancar el servidor.'
