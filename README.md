# Servidor DayZ: Deer Isle PvE con zonas PvP

Kit para montar en **Windows** un servidor de DayZ con:

- **Mapa:** Deer Isle
- **Modo:** PvE en todo el mapa y PvP solo dentro de zonas delimitadas (mod PVEZ Reloaded)
- **Traders:** mercado de DayZ Expansion, con zona segura alrededor
- **Bases:** construcción de Expansion con bandera de territorio y candados. No se puede construir a menos de X metros de las zonas PvP ni de los traders.
- **Armas:** armas extra de Expansion, más un pack opcional (SNAFU)
- **Coleccionables:** un trader "Coleccionista" que compra diarios, cintas de casete, objetos raros, peluches y pieles
- **Admin:** Community Online Tools

> Los scripts son para tu PC con Windows (pruebas). Cuando lo pases a un hosting, mira [Pasar a un hosting](#pasar-a-un-hosting).

---

## Estructura

```
1-INSTALAR-O-ACTUALIZAR.bat     Descarga/actualiza servidor, mods y mision
2-INICIAR-SERVIDOR.bat          Arranca el servidor (se reinicia solo si se cae)
3-APLICAR-ZONAS-Y-TRADERS.bat   Aplica zonas seguras, zonas sin bases, NPCs y coleccionables
config/
  ajustes.json                  Rutas, usuario de Steam, puerto...
  mods.json                     Lista de mods (activar/desactivar, orden de carga)
  serverDZ.cfg                  Configuracion del servidor (nombre, jugadores, password...)
  zonas.json                    Traders, zonas PvP y distancias minimas para bases
  expansion/Market/Coleccionables.json   Categoria de objetos coleccionables
  expansion/Traders/Coleccionista.json   Trader que los compra
scripts/                        Los .ps1 que hacen el trabajo
IDEAS_MODS.md                   Mods recomendados para este tipo de servidor
```

## Requisitos

- Windows 10/11 con **16 GB de RAM** o más si vas a tener el servidor y el juego abiertos a la vez.
- Unos **30 GB libres**: servidor más mods, Expansion y Deer Isle pesan bastante.
- Una cuenta de **Steam que tenga DayZ**. SteamCMD la necesita para bajar el servidor y los mods del Workshop.

## Puesta en marcha

### 1. Ajustes

Abre `config/ajustes.json` y revisa:

| Campo | Qué es |
|---|---|
| `CarpetaServidor` | Dónde se instala el servidor (por defecto `C:\DayZServer`) |
| `CarpetaSteamCMD` | Dónde se instala SteamCMD (por defecto `C:\SteamCMD`) |
| `UsuarioSteam` | Tu usuario de inicio de sesión de Steam. Si lo dejas vacío, te lo pregunta. |
| `PasswordAdmin` | Vacío = se genera una aleatoria y se guarda en `password_admin.txt` dentro del servidor |
| `Puerto` | 2302 por defecto |

Si no quieres subir tu usuario de Steam a git, crea `config/ajustes.local.json` con los campos que quieras sobrescribir. Ese archivo está en `.gitignore`.

### 2. Instalar

Doble clic en **`1-INSTALAR-O-ACTUALIZAR.bat`**. Hace esto:

1. Descarga SteamCMD.
2. Instala DayZ Server (app 223350). La primera vez SteamCMD te pide la **contraseña y el código de Steam Guard**. La contraseña no se guarda en ningún archivo del proyecto.
3. Descarga los mods activos de `mods.json`, los copia como `@NombreMod` y copia sus llaves `.bikey` a `keys\`.
4. Descarga la misión oficial de Deer Isle (`empty.deerisle`).
5. Integra Expansion en la misión: añade `expansion_ce`, registra los tipos en `cfgeconomycore.xml`, añade los puntos de aparición de vehículos y crea las carpetas `expansion\traders` y `expansion\objects`.
6. Copia `serverDZ.cfg` con la contraseña de admin.

Puedes volver a ejecutarlo para **actualizar** servidor y mods. La misión no se toca si ya existe, para no perder bases ni coches. Para rehacerla desde cero, ejecuta desde PowerShell `scripts\instalar.ps1 -ReinstalarMision`.

> Si un mod grande (Expansion, Deer Isle) falla por tiempo de espera, vuelve a lanzar el instalador. Es habitual con SteamCMD.

### 3. Primer arranque

Doble clic en **`2-INICIAR-SERVIDOR.bat`**. El primer arranque tarda varios minutos y crea los ajustes de Expansion (`mpmissions\empty.deerisle\expansion\settings\` y `profiles\ExpansionMod\`).

Para entrar desde el mismo PC, abre el **DayZ Launcher** y ve a *Servers* > *Direct connect* > `127.0.0.1`, puerto `2302`. El launcher te ofrecerá suscribirte a los mods que te falten.

Para comprobar que funciona: en `profiles\` del servidor, el `.RPT` más reciente no debe tener errores de mods, y en el juego deberías ver el mapa Deer Isle.

### 4. Colocar traders y zonas PvP

Las coordenadas de traders y zonas no vienen hechas, porque los NPCs necesitan la **altura exacta del suelo** y no hay una lista fiable para Deer Isle. Se sacan en el juego en unos minutos:

1. Hazte admin en **Community Online Tools**. Sigue las instrucciones de la página del mod en el Workshop; normalmente basta con añadir tu Steam64 ID en la carpeta de permisos que crea dentro de `profiles\`.
2. En el juego, abre COT, vuela o teletranspórtate al sitio y copia tu posición `X Y Z`.
3. Rellena `config/zonas.json`:
   - **Traders:** `Centro` (centro de la zona segura), `RadioZonaSegura` y, para cada NPC, su `Posicion` (de pie en el suelo, con la Y que te da COT) y su `Orientacion` (0 a 360 grados). Pon `"Activo": true`.
   - **ZonasPvP:** `Centro`, `Radio` y `"Activo": true`. Sugerencias: **Stonington**, que es la zona de mejor loot, y alguna **base militar**.
   - **Distancias:** `DistanciaMinimaBasesAPvP` (500 m por defecto) y `DistanciaMinimaBasesATraders` (300 m).
4. **Apaga el servidor** y ejecuta **`3-APLICAR-ZONAS-Y-TRADERS.bat`**, que hace esto:
   - Copia la categoría **Coleccionables** y el trader **Coleccionista** al mercado de Expansion.
   - Crea las **zonas seguras** de los traders.
   - Crea las **zonas sin construcción**: el radio del trader o de la zona PvP más la distancia mínima. Las que hayas añadido a mano en `BaseBuildingSettings.json` se conservan.
   - Genera los **NPCs** en `expansion\traders\zonas_auto.map`.
   - Te muestra la lista de **zonas PvP** para meterlas en PVEZ.
5. **PVEZ:** crea las mismas zonas PvP en PVEZ, desde su menú de admin o su archivo de configuración según su página del Workshop. PVEZ guarda sus zonas por su cuenta, por eso este paso es manual.
6. Arranca de nuevo el servidor.

Antes de modificar un archivo de ajustes, el script guarda una copia `.bak` con fecha.

### 5. Que entre un amigo

- Abre en el router los puertos **UDP 2302-2305** y **UDP 27016**, apuntando a tu PC. Permite también `DayZServer_x64.exe` en el Firewall de Windows.
- Tu amigo se conecta con *Direct connect* a tu **IP pública** y el puerto 2302.
- Tiene que tener los mismos mods. El launcher se los ofrece al conectar, o puede suscribirse a los de `mods.json` (los que tienen `"Tipo": "cliente"`).

## Mods incluidos

| Mod | Workshop ID | Para qué |
|---|---|---|
| CF (Community Framework) | 1559212036 | Base de casi todos los mods |
| Dabs Framework | 2545327648 | Requisito de Expansion |
| DayZ-Expansion-Licensed | 2116157322 | Modelos con licencia que Expansion necesita |
| DayZ-Expansion-Bundle | 2572331007 | Mercado/traders, zonas seguras, bases y territorios, candados, vehículos, armas, misiones, grupos... |
| DeerIsle | 1602372402 | El mapa |
| PVEZ Reloaded | 2831742849 | PvE con zonas PvP |
| Community Online Tools | 1564026768 | Admin |
| SNAFU Weapons *(desactivado)* | 2443122116 | Pack de armas. Comprueba que siga publicado antes de activarlo. |
| RetroCollectibles *(desactivado)* | 2927929000 | Más coleccionables para vender |

Para activar o desactivar un mod, cambia `"Activo"` en `config/mods.json`, vuelve a ejecutar el instalador y reinicia. **Activa los mods de uno en uno**: así, si algo falla, sabes cuál ha sido.

## Coleccionables

El trader **Coleccionista** solo compra (no vende):

- Los 8 **diarios y libros** de Deer Isle (`JMC_Book_*`), que cuentan la historia del mapa
- **Cintas de casete** (`JMC_Radio_CassetteTape_MusicTape2/3`)
- **Rarezas:** Mjolnir, gladius ornamental, bastón con calavera
- **Trofeos de caza:** pieles de oso, lobo, ciervo y jabalí
- **Peluches y huevo de Pascua**, que ya existen en el mercado de Expansion

Precios y objetos están en `config/expansion/Market/Coleccionables.json`. Si activas RetroCollectibles, añade allí sus classnames con el mismo formato y vuelve a ejecutar el paso 3.

## Pasar a un hosting

En hostings como Nitrado, GTX o Pingperfect:

1. Instala los mods desde el panel del hosting, con los mismos IDs y en el mismo orden que `mods.json`.
2. Sube por FTP la carpeta `mpmissions\empty.deerisle` de tu PC. Ya lleva Expansion integrado, tus traders y tus ajustes.
3. Sube `profiles\ExpansionMod\` a la carpeta de perfil del hosting (a veces se llama `config` o `profile`).
4. Copia en el panel los valores de `serverDZ.cfg`. Normalmente el hosting gestiona el puerto y `template`.
5. Configura de nuevo las zonas de PVEZ, o sube su carpeta de configuración.

## Problemas típicos

| Síntoma | Solución |
|---|---|
| "Signature check failed" al entrar | Falta una `.bikey` en `keys\`. Vuelve a ejecutar el instalador. |
| El servidor se cierra al arrancar | Mira el último `.RPT` en `profiles\`. Casi siempre es un mod que falta o un orden de carga incorrecto. |
| No aparecen los traders | Revisa que la Y de la `Posicion` sea la del suelo y que el nombre en `Trader` coincida con un archivo de `profiles\ExpansionMod\Traders\`. |
| Los cambios de zonas desaparecen | Ejecuta el paso 3 con el servidor apagado. |
| PVEZ no funciona con Expansion | Prueba la alternativa en [IDEAS_MODS.md](IDEAS_MODS.md). |
