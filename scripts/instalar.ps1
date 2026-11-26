# Instala o actualiza: SteamCMD, DayZ Server, mods del Workshop, mision de Deer Isle + Expansion.
# Se puede ejecutar tantas veces como quieras: sirve tambien para actualizar.
param(
    [switch]$ReinstalarMision   # Borra y vuelve a crear la mision (perderas la persistencia: bases, coches...)
)

. (Join-Path $PSScriptRoot 'comun.ps1')
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$aj = Leer-Ajustes
$mods = Leer-Mods
$Servidor = $aj.CarpetaServidor
$SteamCMDDir = $aj.CarpetaSteamCMD
$SteamCMD = Join-Path $SteamCMDDir 'steamcmd.exe'
$Mision = Join-Path $Servidor "mpmissions\$($aj.Mision)"
$Temp = Join-Path $env:TEMP 'dayz-instalador'

# ---------------------------------------------------------------- SteamCMD
Titulo '1/6  SteamCMD'
if (-not (Test-Path $SteamCMD)) {
    New-Item -ItemType Directory -Force -Path $SteamCMDDir | Out-Null
    $zip = Join-Path $SteamCMDDir 'steamcmd.zip'
    Info 'Descargando SteamCMD...'
    Invoke-WebRequest 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip' -OutFile $zip -UseBasicParsing
    Expand-Archive $zip -DestinationPath $SteamCMDDir -Force
    Remove-Item $zip
}
Ok "SteamCMD en $SteamCMDDir"

$usuario = $aj.UsuarioSteam
if ([string]::IsNullOrWhiteSpace($usuario)) {
    Aviso 'DayZ Server y los mods del Workshop necesitan una cuenta de Steam que tenga DayZ.'
    $usuario = Read-Host '  Tu usuario de Steam (no el nombre visible, el de iniciar sesion)'
}
Info 'SteamCMD te pedira la contrasena y el codigo de Steam Guard la primera vez.'
Info 'La contrasena NO se guarda en ningun archivo de este proyecto.'

# ---------------------------------------------------------------- Servidor
Titulo '2/6  DayZ Server (app 223350)'
New-Item -ItemType Directory -Force -Path $Servidor | Out-Null
& $SteamCMD +force_install_dir "$Servidor" +login $usuario +app_update 223350 validate +quit
if (-not (Test-Path (Join-Path $Servidor 'DayZServer_x64.exe'))) {
    throw 'No se ha instalado DayZServer_x64.exe. Revisa el usuario/contrasena de Steam y vuelve a ejecutar.'
}
Ok "Servidor instalado en $Servidor"

# ---------------------------------------------------------------- Mods
Titulo "3/6  Mods del Workshop ($($mods.Count) activos)"
$parametros = @('+login', $usuario)
foreach ($m in $mods) { $parametros += @('+workshop_download_item', '221100', $m.Id, 'validate') }
$parametros += '+quit'
& $SteamCMD @parametros

$workshop = Join-Path $SteamCMDDir 'steamapps\workshop\content\221100'
$keysDir = Join-Path $Servidor 'keys'
New-Item -ItemType Directory -Force -Path $keysDir | Out-Null
$faltan = @()
foreach ($m in $mods) {
    $origen = Join-Path $workshop $m.Id
    if (-not (Test-Path $origen)) { $faltan += $m; continue }
    $destino = Join-Path $Servidor $m.Carpeta
    robocopy $origen $destino /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    # Las llaves (.bikey) pueden estar en keys\ o Keys\ (Windows no distingue mayusculas)
    Get-ChildItem -Path $origen -Recurse -Filter *.bikey -ErrorAction SilentlyContinue |
        ForEach-Object { Copy-Item $_.FullName $keysDir -Force }
    Ok "$($m.Carpeta)"
}
if ($faltan.Count -gt 0) {
    foreach ($m in $faltan) { Aviso "No se descargo $($m.Carpeta) (id $($m.Id))." }
    Aviso 'Los mods grandes a veces fallan por tiempo de espera: vuelve a ejecutar el instalador.'
}

# ---------------------------------------------------------------- Mision Deer Isle
Titulo '4/6  Mision de Deer Isle'
if ($ReinstalarMision -and (Test-Path $Mision)) {
    $copia = "$Mision.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Move-Item $Mision $copia
    Aviso "Mision anterior movida a $copia"
}
New-Item -ItemType Directory -Force -Path $Temp | Out-Null
if (-not (Test-Path $Mision)) {
    $zip = Join-Path $Temp 'deerisle.zip'
    Info 'Descargando archivos de mision oficiales de Deer Isle (GitHub johnmclane666/Deerisle-Stable)...'
    Invoke-WebRequest 'https://github.com/johnmclane666/Deerisle-Stable/archive/refs/heads/master.zip' -OutFile $zip -UseBasicParsing
    $ext = Join-Path $Temp 'deerisle'
    if (Test-Path $ext) { Remove-Item $ext -Recurse -Force }
    Expand-Archive $zip -DestinationPath $ext -Force
    $origen = Get-ChildItem $ext -Recurse -Directory -Filter 'empty.deerisle' | Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $origen) { throw 'No se encontro empty.deerisle dentro del zip de Deer Isle.' }
    New-Item -ItemType Directory -Force -Path (Split-Path $Mision) | Out-Null
    Copy-Item $origen.FullName $Mision -Recurse
    Ok "Mision copiada desde $($origen.Parent.Name)"
} else {
    Ok 'La mision ya existe (no se toca para no perder la persistencia). Usa -ReinstalarMision para rehacerla.'
}

# ---------------------------------------------------------------- Expansion en la mision
Titulo '5/6  Integrar Expansion en la mision'
$zip = Join-Path $Temp 'expansion-missions.zip'
Invoke-WebRequest 'https://github.com/ExpansionModTeam/DayZ-Expansion-Missions/archive/refs/heads/master.zip' -OutFile $zip -UseBasicParsing
$ext = Join-Path $Temp 'expansion-missions'
if (Test-Path $ext) { Remove-Item $ext -Recurse -Force }
Expand-Archive $zip -DestinationPath $ext -Force
$plantilla = Get-ChildItem $ext -Recurse -Directory -Filter 'DeerIsle' | Select-Object -First 1
if (-not $plantilla) { throw 'No se encontro la plantilla DeerIsle de Expansion.' }

# a) Tipos de objetos de Expansion (loot, coches...)
robocopy (Join-Path $plantilla.FullName 'expansion_ce') (Join-Path $Mision 'expansion_ce') /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
Ok 'expansion_ce copiado'

# b) Registrar expansion_ce en cfgeconomycore.xml
$core = Join-Path $Mision 'cfgeconomycore.xml'
$texto = Get-Content -Raw -Encoding UTF8 $core
if ($texto -notmatch 'folder="expansion_ce"') {
    Copia-Seguridad $core
    $bloque = @"
	<ce folder="expansion_ce">
		<file name="expansion_types.xml" type="types" />
		<file name="expansion_spawnabletypes.xml" type="spawnabletypes" />
		<file name="expansion_events.xml" type="events" />
	</ce>
</economycore>
"@
    $texto = $texto -replace '</economycore>', $bloque
    Guardar-Texto $texto $core
    Ok 'cfgeconomycore.xml actualizado'
} else { Ok 'cfgeconomycore.xml ya tenia expansion_ce' }

# c) Puntos de aparicion de los vehiculos de Expansion en cfgeventspawns.xml
$spawnsMision = Join-Path $Mision 'cfgeventspawns.xml'
[xml]$xmlMision = Get-Content -Raw -Encoding UTF8 $spawnsMision
[xml]$xmlPlantilla = Get-Content -Raw -Encoding UTF8 (Join-Path $plantilla.FullName 'cfgeventspawns.xml')
$existentes = @{}
foreach ($e in $xmlMision.eventposdef.event) { $existentes[$e.name] = $true }
$anadidos = 0
foreach ($e in $xmlPlantilla.eventposdef.event) {
    if (-not $existentes.ContainsKey($e.name)) {
        [void]$xmlMision.eventposdef.AppendChild($xmlMision.ImportNode($e, $true))
        $anadidos++
    }
}
if ($anadidos -gt 0) { Copia-Seguridad $spawnsMision; $xmlMision.Save($spawnsMision) }
Ok "cfgeventspawns.xml: $anadidos eventos de Expansion anadidos"

# d) Carpetas que usa Expansion Market
foreach ($d in 'expansion\traders', 'expansion\objects') {
    New-Item -ItemType Directory -Force -Path (Join-Path $Mision $d) | Out-Null
}
Ok 'Carpetas expansion\traders y expansion\objects listas'

# e) types.xml de los mods (BBP, MuchStuffPack, coleccionables...) para loot y persistencia
$texto = Get-Content -Raw -Encoding UTF8 $core
$cambios = $false
foreach ($m in ($mods | Where-Object { $_.TiposCE })) {
    $carpetaMod = Join-Path $Servidor $m.Carpeta
    if (-not (Test-Path $carpetaMod)) { continue }
    # El types.xml suele venir en una carpeta tipo "Extras" o "ServerFiles". Elegimos el de ruta mas corta.
    $tipos = Get-ChildItem $carpetaMod -Recurse -File -Filter '*.xml' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '(?i)^(.*[_\-\s])?types\.xml$' -and $_.Name -notmatch '(?i)spawnable' } |
        Where-Object { (Get-Content $_.FullName -TotalCount 20 -ErrorAction SilentlyContinue) -match '<types' } |
        Sort-Object { $_.FullName.Length } | Select-Object -First 1
    if (-not $tipos) {
        Aviso "$($m.Carpeta): no trae types.xml. Sus objetos funcionaran, pero no apareceran como loot."
        continue
    }
    $nombre = $m.Carpeta.TrimStart('@')
    $destino = Join-Path $Mision "mods_ce\$nombre"
    New-Item -ItemType Directory -Force -Path $destino | Out-Null
    Copy-Item $tipos.FullName (Join-Path $destino 'types.xml') -Force
    if ($texto -notmatch [regex]::Escape("folder=""mods_ce/$nombre""")) {
        $bloque = "`t<ce folder=""mods_ce/$nombre"">`r`n`t`t<file name=""types.xml"" type=""types"" />`r`n`t</ce>`r`n</economycore>"
        $texto = $texto -replace '</economycore>', $bloque
        $cambios = $true
    }
    Ok "$($m.Carpeta): types.xml registrado ($($tipos.FullName.Substring($carpetaMod.Length + 1)))"
}
if ($cambios) { Copia-Seguridad $core; Guardar-Texto $texto $core }

# ---------------------------------------------------------------- serverDZ.cfg
Titulo '6/6  serverDZ.cfg'
$pwdArchivo = Join-Path $Servidor 'password_admin.txt'
$pwdAdmin = $aj.PasswordAdmin
if ([string]::IsNullOrWhiteSpace($pwdAdmin)) {
    if (Test-Path $pwdArchivo) { $pwdAdmin = (Get-Content $pwdArchivo -Raw).Trim() }
    else {
        $chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'.ToCharArray()
        $pwdAdmin = -join (1..16 | ForEach-Object { $chars | Get-Random })
        Set-Content -Path $pwdArchivo -Value $pwdAdmin -Encoding ASCII
    }
}
$cfg = Get-Content -Raw -Encoding UTF8 (Join-Path $CarpetaConfig 'serverDZ.cfg')
$cfg = $cfg.Replace('__PASSWORD_ADMIN__', $pwdAdmin)
$cfg = $cfg -replace 'template\s*=\s*"[^"]*"', ('template = "' + $aj.Mision + '"')
Guardar-Texto $cfg (Join-Path $Servidor 'serverDZ.cfg')
Ok 'serverDZ.cfg copiado'
Info "Password de admin (RCon / #login): guardada en $pwdArchivo"

Titulo 'LISTO'
Info 'Siguiente paso: 2-INICIAR-SERVIDOR.bat'
Info 'El primer arranque genera los ajustes de Expansion. Despues usa 3-APLICAR-CONFIGURACION.bat'
