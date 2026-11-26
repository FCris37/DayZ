# Arranca el servidor con los mods activos de config\mods.json.
# Si el servidor se cierra (crash o reinicio programado) vuelve a arrancarlo. Ctrl+C para parar.
. (Join-Path $PSScriptRoot 'comun.ps1')

$aj = Leer-Ajustes
$mods = Leer-Mods
$Servidor = $aj.CarpetaServidor
$exe = Join-Path $Servidor 'DayZServer_x64.exe'
if (-not (Test-Path $exe)) { throw "No existe $exe. Ejecuta primero 1-INSTALAR-O-ACTUALIZAR.bat" }

foreach ($m in $mods) {
    if (-not (Test-Path (Join-Path $Servidor $m.Carpeta))) {
        throw "Falta la carpeta $($m.Carpeta) en el servidor. Ejecuta de nuevo el instalador."
    }
}

$modsCliente  = ($mods | Where-Object { $_.Tipo -eq 'cliente' }  | ForEach-Object { $_.Carpeta }) -join ';'
$modsServidor = ($mods | Where-Object { $_.Tipo -eq 'servidor' } | ForEach-Object { $_.Carpeta }) -join ';'

$parametros = @(
    '-config=serverDZ.cfg',
    "-port=$($aj.Puerto)",
    '-profiles=profiles',
    '-dologs', '-adminlog', '-netlog', '-freezecheck'
)
if ($modsCliente)  { $parametros += "`"-mod=$modsCliente`"" }
if ($modsServidor) { $parametros += "`"-serverMod=$modsServidor`"" }

Titulo 'Servidor DayZ - Deer Isle'
Info "Carpeta : $Servidor"
Info "Puerto  : $($aj.Puerto) (UDP)"
Info "Mods    : $modsCliente"
if ($modsServidor) { Info "Server  : $modsServidor" }
Info 'Logs    : profiles\ dentro de la carpeta del servidor'
Info 'Para conectarte desde este PC: DayZ Launcher > Servers > Direct connect > 127.0.0.1 puerto 2302'

do {
    Write-Host ''
    Ok "Arrancando ($(Get-Date -Format 'HH:mm:ss'))..."
    $p = Start-Process -FilePath $exe -ArgumentList $parametros -WorkingDirectory $Servidor -PassThru -Wait
    Aviso "El servidor se ha cerrado (codigo $($p.ExitCode))."
    if (-not $aj.ReinicioAutomatico) { break }
    Info 'Reiniciando en 10 segundos... (Ctrl+C para cancelar)'
    Start-Sleep -Seconds 10
} while ($true)
