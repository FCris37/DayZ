# Ideas de mods para un servidor PvE con zonas PvP

Busca cada uno por su nombre en el Steam Workshop de DayZ y comprueba la fecha de la última actualización antes de instalarlo. Añádelo a `config/mods.json` y activa los mods **de uno en uno**.

## Ya vienen dentro de Expansion

Basta con configurarlos en `mpmissions\empty.deerisle\expansion\settings\` o en `profiles\ExpansionMod\`.

- **Quests:** misiones de recoger, entregar o matar con recompensas en dinero. Encaja muy bien en PvE. Incluye **búsquedas del tesoro** (*Treasure Hunt*), que combinan bien con los coleccionables.
- **Expansion AI:** patrullas de bandidos con IA. Dan PvE con peligro real y se pueden poner patrullas duras solo dentro de las zonas PvP.
- **Misiones dinámicas y airdrops:** eventos que llevan a los jugadores a moverse por el mapa.
- **Hardline:** sistema de reputación y rareza de objetos. Puedes hacer que algunos traders pidan reputación.
- **Personal Storage:** almacén personal en los traders. Útil en PvE para que nadie pierda todo.
- **Garaje de vehículos y llaves de coche:** evita robos de coches en PvE.
- **Grupos/Party y marcadores en el mapa.**

## Bases

- **BaseBuildingPlus (BBP):** muros, suelos y tejados de más niveles. Es compatible con los candados de Expansion; pon `CodelockAttachMode` a 1 o 3.
- **MuchStuffPack:** muebles, taquillas y almacenamiento para decorar la base.
- **RaG Base Items / MMG Base Storage:** estanterías, armeros y cajas de almacenamiento.
- **Breachingcharge:** cargas para asaltar bases. Solo tiene sentido si permites raid en las zonas PvP.

## Armas

- **SNAFU Weapons:** el pack más conocido. Ya está en `mods.json` desactivado.
- Otros packs de armas recientes: comprueba que traigan *types.xml* para el loot y que estén actualizados.
- **Mass' Many Item Overhaul:** muchas armas y objetos. Busca la versión más actualizada, porque algunos packs antiguos están abandonados.

## Coleccionables y economía

- **RetroCollectibles:** objetos retro para vender. Ya está en `mods.json` desactivado.
- **Dog Tags:** chapas de identificación que caen al morir. En las zonas PvP se pueden vender como "trofeo".
- **Mods de cartas, figuras o monedas antiguas:** busca *collectible* en el Workshop. Cualquiera sirve: solo hay que meter sus classnames en `Coleccionables.json`.
- **Animales y caza (p. ej. Wolf/Bear packs, mods de pesca):** más trofeos para el Coleccionista.

## Ambiente PvE

- **Zombie mods (p. ej. PvZmoD Customisable Zombies):** zombis más duros o variados. En PvE el reto viene de la IA y los zombis.
- **Zonas contaminadas / KOTH (King of the Hill):** eventos para la zona PvP con buen loot como recompensa.
- **Mods de clima y radiación:** dan más vida al mapa.

## Si PVEZ da problemas

Hay usuarios que reportan conflictos de **PVEZ Reloaded** con algunas versiones de Expansion. Alternativas:

- **Ninjins PvP-PvE:** zonas PvP/PvE/raid circulares, poligonales o por horario. Admite granadas y minas.
- **PVEZ Reloaded Improved:** fork mantenido por la comunidad.

## Orden de carga recomendado

1. `@CF`, `@DabsFramework`
2. `@DayZ-Expansion-Licensed`, `@DayZ-Expansion-Bundle`
3. Mapa: `@DeerIsle`
4. Mods de contenido (armas, bases, coleccionables)
5. Mods de reglas o admin: `@PVEZ-Reloaded`, `@CommunityOnlineTools`
