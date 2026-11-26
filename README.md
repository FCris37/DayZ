# Servidor DayZ: Deer Isle PvE con zonas PvP

Kit para montar en **Windows** un servidor de DayZ con:

- **Mapa:** Deer Isle
- **Modo:** PvE en todo el mapa y PvP solo dentro de zonas delimitadas (mod PVEZ Reloaded). Stonington ya viene configurada como zona PvP.
- **Bandidos con IA:** patrullas hostiles dentro de las zonas PvP (Expansion AI)
- **Traders:** mercado de DayZ Expansion, con zona segura alrededor
- **Bases:**
  - Construcción de Expansion con bandera de territorio y candados.
  - **BaseBuildingPlus**: muros, suelos y tejados por niveles.
  - **MuchStuffPack**: muebles y almacenaje.
  - No se puede construir cerca de las zonas PvP ni de los traders.
- **Garaje** para guardar los coches en tu territorio
- **El doble de zombis** que en el mapa original (ajustable en `config/zonas.json` > `Zombis`)
- **Coleccionables:** el trader "Coleccionista" compra diarios, cintas, reliquias, trofeos de caza y coleccionables retro
- **Quests:** búsqueda del tesoro diaria, encargo de pieles de lobo y encargo de diarios perdidos
- **Airdrops:** los de Expansion, que ya traen sus puntos de Deer Isle
- **Admin:** Community Online Tools

> Los scripts son para tu PC con Windows (pruebas). Cuando lo pases a un hosting, mira [Pasar a un hosting](#pasar-a-un-hosting).

---

## Estructura

```
1-INSTALAR-O-ACTUALIZAR.bat     Descarga/actualiza servidor, mods y mision
2-INICIAR-SERVIDOR.bat          Arranca el servidor (se reinicia solo si se cae)
3-APLICAR-CONFIGURACION.bat     Aplica traders, zonas, bases, bandidos, garaje, quests y mercado
config/
  ajustes.json                  Rutas, usuario de Steam, puerto...
  mods.json                     Lista de mods (activar/desactivar, orden de carga, categorias de mercado)
  serverDZ.cfg                  Configuracion del servidor (nombre, jugadores, password...)
  zonas.json                    Traders, zonas PvP, bandidos, garaje, quests y tesoros
  expansion/Market/Coleccionables.json   Categoria de coleccionables y trofeos
  expansion/Traders/Coleccionista.json   Trader que los compra
scripts/                        Los .ps1 que hacen el trabajo
IDEAS_MODS.md                   Mas mods recomendados
```

## Requisitos

- Windows 10/11 con **16 GB de RAM** o más si vas a tener el servidor y el juego abiertos a la vez.
- Unos **40 GB libres**: servidor más mods, Expansion, Deer Isle y MuchStuffPack pesan bastante.
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
5. Integra Expansion en la misión: añade `expansion_ce`, añade los puntos de aparición de vehículos y crea las carpetas de traders.
6. Busca el `types.xml` de BBP, MuchStuffPack y RetroCollectibles y lo registra en la misión. Sin esto, sus objetos no aparecerían como loot y las bases podrían desaparecer.
7. Copia `serverDZ.cfg` con la contraseña de admin.

Puedes volver a ejecutarlo para **actualizar** servidor y mods. La misión no se toca si ya existe, para no perder bases ni coches. Para rehacerla desde cero, ejecuta desde PowerShell `scripts\instalar.ps1 -ReinstalarMision`.

> Si un mod grande (Expansion, Deer Isle, MuchStuffPack) falla por tiempo de espera, vuelve a lanzar el instalador. Es habitual con SteamCMD.

### 3. Primer arranque

Doble clic en **`2-INICIAR-SERVIDOR.bat`**. El primer arranque tarda varios minutos y crea los ajustes de Expansion (`mpmissions\empty.deerisle\expansion\settings\` y `profiles\ExpansionMod\`). Cuando termine de cargar, **ciérralo**.

### 4. Aplicar la configuración

Con el servidor apagado, doble clic en **`3-APLICAR-CONFIGURACION.bat`**. Funciona sin tocar nada y activa directamente:

- **Mercado:** categoría *Coleccionables y trofeos* y trader *Coleccionista*. Además crea categorías automáticas con los kits de **BBP** y **MuchStuffPack** (las vende el trader de materiales de construcción) y con los objetos de **RetroCollectibles** (los compra el Coleccionista).
- **Zona PvP de Stonington:** no se puede construir a menos de 500 m del borde y tiene una patrulla de 2 a 4 bandidos.
- **Candados de Expansion** en puertas de BBP, vallas y tiendas de campaña.
- **Garaje** de vehículos.
- **Zombis x2** y hasta 2000 vivos a la vez en el mapa. Se calcula siempre desde una copia del original, así que repetir el script no los vuelve a multiplicar. Si el servidor va lento, baja `Multiplicador` en `config/zonas.json` > `Zombis`.
- **Quests:** el NPC *Abe el Cazatesoros* está en Oldfield y ofrece tres encargos:
  - *Tesoro enterrado* (diaria): un cofre enterrado en un pueblo al azar, con diarios, cintas y alguna reliquia. Hace falta una pala.
  - *Pieles de lobo*: entregar 3 pieles de lobo.
  - *Diarios perdidos*: entregar cualquier diario de Deer Isle.

  Las quests por defecto de Expansion se sustituyen, porque están pensadas para Chernarus y Namalsk; en Deer Isle saldrían en la posición 0,0,0. Antes de sustituirlas se guarda una copia en `profiles\ExpansionMod\Quests.original-*`.

Lo puedes repetir siempre que cambies algo en `config/`. Antes de modificar un archivo de ajustes, el script guarda una copia `.bak` con fecha.

Después arranca de nuevo el servidor. Para entrar desde el mismo PC, abre el **DayZ Launcher** y ve a *Servers* > *Direct connect* > `127.0.0.1`, puerto `2302`. El launcher te ofrecerá suscribirte a los mods que te falten.

### 5. Colocar los traders (y más zonas PvP)

Los NPC de los traders necesitan la **altura exacta del suelo**, así que sus coordenadas se sacan en el juego:

1. Hazte admin en **Community Online Tools**. Sigue las instrucciones de la página del mod en el Workshop; normalmente basta con añadir tu Steam64 ID en la carpeta de permisos que crea dentro de `profiles\`.
2. En el juego, abre COT, ve al sitio y copia tu posición `X Y Z`.
3. Rellena en `config/zonas.json`:
   - **Traders:** el centro ya está propuesto en Oldfield. Pon la `Posicion` de cada NPC (de pie en el suelo, con la Y que te da COT), su `Orientacion` (0 a 360 grados) y `"Activo": true`.
   - **ZonasPvP:** puedes activar más zonas, por ejemplo una base militar. Cada una lleva `Centro`, `Radio` y el número de `Bandidos` (0 = sin patrulla). En el campo `_pueblos` tienes las coordenadas de 13 pueblos de Deer Isle.
   - **Distancias** para bases: `DistanciaMinimaBasesAPvP` (500 m) y `DistanciaMinimaBasesATraders` (300 m).
   - **Quests:** posición del NPC, puntos donde se entierran los tesoros y recompensas.
4. Apaga el servidor, ejecuta **`3-APLICAR-CONFIGURACION.bat`** y vuelve a arrancarlo.

**PVEZ:** el script te muestra la lista de zonas PvP. Créalas también en PVEZ, desde su menú de admin o su archivo de configuración según su página del Workshop. PVEZ guarda sus zonas por su cuenta, por eso este paso es manual.

### 6. Que entre un amigo

- Abre en el router los puertos **UDP 2302-2305** y **UDP 27016**, apuntando a tu PC. Permite también `DayZServer_x64.exe` en el Firewall de Windows.
- Tu amigo se conecta con *Direct connect* a tu **IP pública** y el puerto 2302.
- Tiene que tener los mismos mods. El launcher se los ofrece al conectar.

## Mods incluidos

| Mod | Workshop ID | Para qué |
|---|---|---|
| CF (Community Framework) | 1559212036 | Base de casi todos los mods |
| Dabs Framework | 2545327648 | Requisito de Expansion |
| DayZ-Expansion-Licensed | 2116157322 | Modelos con licencia que Expansion necesita |
| DayZ-Expansion-Bundle | 2572331007 | Mercado, zonas seguras, bases y territorios, candados, garaje, IA, quests, airdrops, vehículos, armas... |
| DeerIsle | 1602372402 | El mapa |
| MuchFramework | 3171576913 | Requisito de MuchStuffPack ⚠️ |
| BaseBuildingPlus | 1710977250 | Construcción por niveles |
| MuchStuffPack | 1991570984 | Muebles y almacenaje ⚠️ |
| RetroCollectibles | 2927929000 | Coleccionables retro para vender |
| PVEZ Reloaded | 2831742849 | PvE con zonas PvP |
| Community Online Tools | 1564026768 | Admin |
| SNAFU Weapons *(desactivado)* | 2443122116 | Pack de armas. Comprueba que siga publicado antes de activarlo. |

⚠️ Avisos:

- **MuchStuffPack** ya no recibe actualizaciones de su autor. Funciona, pero podría romperse con un parche futuro de DayZ.
- El ID de **MuchFramework** sale de su historial de cambios; compruébalo en el Workshop.
- **BBP y Expansion:** BBP funciona junto a la construcción de Expansion y sus candados. Algunos usuarios reportan que las piezas encajan mal (*snapping*) al mezclar ambos sistemas.

**Si el servidor no arranca**, desactiva los mods de uno en uno (`"Activo": false` en `config/mods.json`) en este orden: MuchStuffPack + MuchFramework, BBP, RetroCollectibles y PVEZ. Así sabrás cuál falla. El error concreto está en el último `.RPT` de `profiles\`.

## Coleccionables

El **Coleccionista** solo compra (no vende). Precios y objetos están en `config/expansion/Market/Coleccionables.json`:

- **Diarios y libros** de Deer Isle (8), que cuentan la historia del mapa
- **Música:** 2 cintas de casete y el radiocasete
- **Rarezas:** Mjolnir, bastón con calavera, caja de cereales Crunchin' Paulies
- **Reliquias:** espadas y hachas de exposición (gladius, Witcher, espada de fuego, berserker, katana, hacha fantasma, dagas)
- **Trofeos de caza:** pieles de oso, lobo, ciervo y jabalí, y el ghillie de piel de oso
- **Peluches y huevo de Pascua**, que ya existen en el mercado de Expansion
- **Todo RetroCollectibles**, con su categoría generada automáticamente

## Pasar a un hosting

En hostings como Nitrado, GTX o Pingperfect:

1. Instala los mods desde el panel del hosting, con los mismos IDs y en el mismo orden que `mods.json`.
2. Sube por FTP la carpeta `mpmissions\empty.deerisle` de tu PC. Ya lleva Expansion integrado, los `types.xml` de los mods, tus traders y tus ajustes.
3. Sube `profiles\ExpansionMod\` a la carpeta de perfil del hosting (a veces se llama `config` o `profile`). Lleva mercado, quests y ajustes.
4. Copia en el panel los valores de `serverDZ.cfg`. Normalmente el hosting gestiona el puerto y `template`.
5. Configura de nuevo las zonas de PVEZ, o sube su carpeta de configuración.

## Problemas típicos

| Síntoma | Solución |
|---|---|
| "Signature check failed" al entrar | Falta una `.bikey` en `keys\`. Vuelve a ejecutar el instalador. |
| El servidor se cierra al arrancar | Mira el último `.RPT` en `profiles\`. Casi siempre es un mod que falta o un orden de carga incorrecto. |
| No aparecen los traders | Revisa que la Y de la `Posicion` sea la del suelo y que el nombre en `Trader` coincida con un archivo de `profiles\ExpansionMod\Traders\`. |
| No aparece el NPC de quests | Revisa en el `.RPT` errores de `Quest`. Si su posición cae dentro de un edificio, cámbiala en `zonas.json`. |
| Los cambios desaparecen | Ejecuta el paso 3 con el servidor apagado. |
| Los objetos de BBP o MuchStuffPack desaparecen | Comprueba que el instalador dijo "types.xml registrado" para ese mod. |
| PVEZ no funciona con Expansion | Prueba la alternativa en [IDEAS_MODS.md](IDEAS_MODS.md). |
