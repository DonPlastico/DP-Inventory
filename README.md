<p align="center">
<h1 align="center">🎒 [FiveM] ¡EL INVENTARIO DEFINITIVO! | DP-Inventory 🎒</h1>

<img width="960" height="auto" align="center" alt="DP-Inventory Banner" src="Images/Banner.png" />

</p>

<div align="center">

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![FiveM](https://img.shields.io/badge/FiveM-Script-important)](https://fivem.net/)
[![QBCore](https://img.shields.io/badge/QBCore-Framework-success)](https://github.com/qbcore-framework)
[![Vue.js](https://img.shields.io/badge/Vue.js-3.0-4FC08D?logo=vue.js)](https://vuejs.org/)

</div>

<h2 align="center"> 📝 Descripción General</h2>
¡Olvida todo lo que sabías sobre inventarios en FiveM! <b>DP-Inventory</b> es una reescritura masiva desde cero del clásico `qb-inventory`. Se ha transformado en un ecosistema moderno, optimizado y visualmente espectacular gracias a su frontend rediseñado con <b>Vue.js 3</b>, CSS3 avanzado y comunicación mediante Axios.

<details>
<summary><h2 align="center">¿Qué es y qué hace?</h2></summary>
Es el núcleo central de gestión de ítems e interacciones para el jugador. Entre sus múltiples sistemas integrados destacan:
<br><br>
- <b>🎨 Interfaz Rediseñada en Vue.js 3:</b> Diseño oscuro, moderno, minimalista, bordes limpios e Iconos Iconify. Reactividad perfecta.<br>
- <b>📁 Sistema de Pestañas (Tabs):</b> Navega fluidamente entre Inventario, Personaje, Ropa, Armas, Vehículo, Ajustes y Panel Admin.<br>
- <b>🎒 Mochilas Inteligentes (Sistema Stash):</b> Las mochilas (`custom_bag_X`) son stashes portátiles con identificadores únicos (`bag_XXXXXX`).<br>
- <b>🛡️ Chalecos y Slots Dedicados:</b> Slots de equipamiento visuales (101 y 102) independientes para tu mochila y chaleco antibalas.<br>
- <b>📊 Durabilidad Visual Inteligente:</b> Barras de progreso precisas bajo cada ítem que indican la calidad de armas y desgaste de chalecos.<br>
- <b>🖱️ Drag & Drop Avanzado:</b> Arrastra y suelta fluidamente entre inventarios, maleteros, guanteras o tira directamente al suelo.<br>
- <b>📱 Menús Contextuales Modernos:</b> Haz clic derecho en cualquier ítem para desplegar opciones dinámicas (Usar, Dar a cercanos, Tirar, Dividir, Copiar Nº Serie, Accesorios).<br>
- <b>🔫 Sistema de Accesorios de Armas:</b> Panel modal dedicado para inspeccionar el arma en 3D, ver su número de serie y acoplar/desacoplar silenciadores, miras y cargadores arrastrando accesorios.<br>
</details>

<details>
<summary><h2 align="center">¿Cómo funciona? (Mecánicas Backend / Frontend)</h2></summary>
Todo el backend ha sido reescrito para eliminar los temidos <i>dupes</i> (duplicación de ítems) y mejorar el rendimiento. Cuenta con sistemas altamente inmersivos y seguros:
<br><br>
- <b>Optimización O(1) y Caché RAM:</b> El servidor no satura la base de datos. Los inventarios, tiendas y <i>drops</i> se cargan en la memoria RAM del servidor al arrancar. Los bucles innecesarios se han eliminado en favor de accesos directos por slot.<br>
- <b>Mecánica de Mochilas Realista (Reducción de Peso):</b> La mochila no solo te da slots extra, sino que el servidor calcula el peso total de los ítems en su interior y <b>lo divide entre 3</b>. Si llevas 30kg dentro de la mochila, tu personaje solo sentirá 10kg de carga real.<br>
- <b>Anti-Desbordamiento Automático:</b> Si te quitas una mochila llena, el servidor detecta los ítems que ya no caben en tus bolsillos normales y los tira automáticamente al suelo en una bolsa física (evitando borrados accidentales o <i>exploits</i> de espacio).<br>
- <b>Sincronización Visual Inteligente (Ropa y Props):</b> Al equipar un chaleco o mochila, detecta el género (Hombre/Mujer) y aplica el ID de ropa exacto. Las armas largas que no llevas en la mano se renderizan físicamente en tu espalda mediante props 3D.<br>
- <b>Seguridad Anti-Loss y Locks:</b> Si dos personas intentan abrir el mismo maletero o bolsa del suelo, el servidor lo bloquea (lock). Además, los inventarios se guardan instantáneamente en BD al cerrarse y cuentan con un escudo de guardado automático al apagar el servidor (integración con eventos de txAdmin).<br>
- <b>Documentos Inmersivos (Chat 3D):</b> Usar el DNI o la Licencia de Conducir calcula las coordenadas exactas y genera una tarjeta HTML en el chat <b>únicamente</b> para los jugadores que se encuentren a menos de 3 metros de distancia.<br>
</details>

<details>
<summary><h2 align="center">¿Qué te permite?</h2></summary>
✅ Reorganizar tu equipo de forma visual y rápida (Soporte avanzado para Hotbar 1-5) 🎒.<br>
✅ Acciones rápidas de personaje (Cachear, Amenazar, Cargar, Caballito) 🧍‍♂️.<br>
✅ Integración con Rockstar Editor para grabar clips de forma segmentada 🎬.<br>
✅ Gestión completa de Ropa (quitar y poner prendas específicas al instante) 👕.<br>
✅ Modificar el estilo de apuntado (Normal, Gangster, Cowboy) y posición de armas a la espalda 🔫.<br>
✅ Control total del vehículo desde el inventario (Motor, ancla de barcos, asientos, puertas y ventanillas) 🚗.<br>
✅ Panel de Administración Integrado para inspeccionar jugadores, maleteros y stashes remotamente 👑.<br>
✅ Comandos Admin Inteligentes (`/giveitem` genera autometadatos: DNIs con tu nombre, armas con número de serie único y calidad al 100%, etc.) 🛠️.<br>
✅ <b>Cursor Libre (Tecla J):</b> Permite ocultar el ratón para rotar la cámara y mirar a tu alrededor mientras mantienes el inventario abierto en pantalla 🖱️.<br>
</details>
<br><br>
<h2 align="center"> 🚀 Instalación</h2>

<details>
<summary><h2 align="center">Requisitos previos</h2></summary>
- Servidor FiveM con <b>QBCore Framework</b> instalado y actualizado.<br>
- Base de datos MySQL configurada (<b>oxmysql</b>).<br>
</details>

<details>
<summary><h2 align="center"> 🚀 Guía de Instalación y SQL</h2></summary>
1. **Descargar el script** y colocar la carpeta en tu servidor. Eliminar tu antiguo `qb-inventory`, `lj-inventory` o el que tengas.<br>
   - ⚠️ <i>Asegúrate de que el nombre de la carpeta sea exactamente `DP-Inventory`.</i><br>
2. **Base de Datos (IMPORTANTE)**.<br>
   - Ejecuta los archivos `DP-Inventory.sql` y `migrate.sql` en tu base de datos. Esto creará la tabla `dp_preferences` para guardar los ajustes de los usuarios y adaptará las tablas necesarias.<br>
3. **Instalación de Ítems Especiales (Mochilas)**.<br>
   - Abre tu archivo `qb-core/shared/items.lua` y añade las mochilas custom.
   - **REGLAS DE ORO PARA MOCHILAS:**
     - El `name` (ID técnico) debe contener **siempre** la palabra `custom_bag` al principio.
     - Debe tener `unique = true`, `useable = true` y `shouldClose = true`.
     - Puedes definir los huecos con `bagSlots` y el peso interno con `bagMaxWeight`.
   - **Ejemplo para copiar y pegar:**
     ```lua
     -- ══════════════════════════════════════════════════════
     -- MOCHILAS CUSTOM (SISTEMA STASH - PESO DINÁMICO)
     -- ══════════════════════════════════════════════════════
     custom_bag_1 = {
         name = 'custom_bag_1',
         label = 'Bolsa de Deporte',
         weight = 500, -- Peso base (vacía). El server suma el peso del interior aquí.
         type = 'item',
         image = 'custom_bag_1.png',
         unique = true, -- OBLIGATORIO para inyectarle la ID del Stash
         useable = true,
         shouldClose = true,
         bagSlots = 15, -- Slots que tendrá al abrirse
         bagMaxWeight = 50000, -- Peso máximo soportado en el interior (50 KG)
         description = 'Una bolsa de deporte amplia. Su peso total en tu inventario dependerá de lo que guardes en su interior.'
     },
     custom_bag_2 = {
         name = 'custom_bag_2',
         label = 'Macuto de Asalto Oculto',
         weight = 1000,
         type = 'item',
         image = 'custom_bag_2.png',
         unique = true,
         useable = true,
         shouldClose = true,
         bagSlots = 30,
         bagMaxWeight = 100000, -- 100 KG
         description = 'Macuto reforzado e impermeabilizado. Perfecto para ocultar material sensible.'
     },
     ```
4. **Dependencias visuales**.<br>
   - Asegúrate de copiar la carpeta de imágenes (Más de 7.000 imágenes) dentro de `ui/images`.<br>
5. **Asegurar el recurso**.<br>
   - Añade `ensure DP-Inventory` a tu `server.cfg`.<br>
</details>
<br><br>

<h2 align="center"> 📂 Estructura del Script</h2>
<pre>
DP-Inventory
├── 📁 client
│   ├── 📄 backitems.lua (Lógica de armas/objetos a la espalda visuales)
│   ├── 📄 backpack_cl.lua (Sincronización visual de chalecos y mochilas en ped)
│   ├── 📄 drops.lua (Gestión de props físicos y objetos en el suelo)
│   ├── 📄 main_client.lua (Núcleo del cliente, callbacks, acciones y NUI)
│   └── 📄 vehicles.lua (Cálculos de clase para maleteros/guanteras y animaciones)
├── 📁 config
│   ├── 📄 backitems.lua
│   ├── 📄 config.lua
│   └── 📄 vehicles.lua
├── 📁 locales
│   └── 📄 cs.lua, de.lua, en.lua, es.lua, nl.lua
├── 📁 server
│   ├── 📄 backpack_sv.lua (Cálculo de penalización de peso y desbordamiento de ítems)
│   ├── 📄 commands.lua (Comandos admin /testreq, /giveitem con metadatos)
│   ├── 📄 functions.lua (Funciones base CRUD O(1), metadatos, validaciones)
│   └── 📄 main_server.lua (Núcleo del servidor, callbacks, persistencia SQL, preferencias)
├── 📁 ui
│   ├── 📁 images (Más de 7.000 imágenes de ítems)
│   ├── 🌐 index.html (Estructura base y Vue.js template)
│   ├── 📄 script.js (Lógica Vue.js, Axios, Drag&Drop)
│   └── 🎨 style.css (Estilos, Grid, animaciones, variables de color)
├── 📄 DP-Inventory.sql
├── 📝 README.md
├── 📄 fxmanifest.lua
└── 📄 migrate.sql
</pre>
<br>

<h2 align="center"> 🎮 Controles por Defecto y Comandos</h2>
<div align="center">
  <b>[F2]</b> - Abrir/Cerrar el inventario (configurable). <br>
  <b>[J]</b> - Activar/Desactivar el Modo Cursor Libre (navega con WASD/Ratón mientras está abierto). <br>
  <b>[Z]</b> - Mostrar/Ocultar Cinturón visual (Hotbar). <br>
  <b>[1] al [5]</b> - Usar rápidamente los ítems de la Hotbar. <br>
  <b>/giveitem</b> - (Solo Admin) Dar un ítem a un jugador. <br>
  <b>/randomitems</b> - (Solo Admin) Dá ítems aleatorios a un jugador. <br>
  <b>/clearinv</b> - (Solo Admin) Vacia el inventario de un jugador. <br>
  <b>/testreq</b> - (Solo Admin) Muestra el UI de ítems requeridos para desarrollo/tests. <br>
</div>
<br><br>

<h2 align="center"> ⚙️ Dependencias</h2>

<details>
<summary><h2 align="center">📦 Requisitos del Sistema</h2></summary>

| Recurso                                                                             | Descripción / Estado                                                 |
| ----------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| <img src="https://placehold.co/20x20/555555/FFFFFF?text=FW" alt="FW"> **QB-Core**   | 🔴 OBLIGATORIO                                                       |
| <img src="https://placehold.co/20x20/555555/FFFFFF?text=SQL" alt="SQL"> **oxmysql** | 🔴 OBLIGATORIO                                                       |
| <img src="https://placehold.co/20x20/555555/FFFFFF?text=W" alt="W"> **qb-weapons**  | 🔴 OBLIGATORIO (Para sistema de accesorios)                          |
| <img src="https://placehold.co/20x20/555555/FFFFFF?text=DP" alt="DP"> **DP-TextUI** | 🔴 OBLIGATORIO (Para los botones de interación con las bolsas/items) |

</details>
<br><br>

<h2 align="center"> 🖼️ Vistas Previas</h2>

<summary><h2>Interfaz Principal y Tooltips Dinámicos</h2></summary>
<img width="350" height="auto" src="Images/UI_Main.png" />
<br><br>

<summary><h2>Menú Contextual e Inspección de Armas (WIP)</h2></summary>
<img width="350" height="auto" src="Images/UI_Context.png" />
<br><br>

<summary><h2>Pestaña de Acciones de Vehículo y Ropa</h2></summary>
<img width="350" height="auto" src="Images/UI_Tabs.png" />
<br><br>

<summary><h2>Sistema de Notificaciones Monocromáticas (ItemBox)</h2></summary>
<img width="350" height="auto" src="Images/UI_Notifs.png" />
<br><br>

<summary><h2>Panel Maestro de Administración</h2></summary>
<img width="350" height="auto" src="Images/UI_Admin.png" />
<br><br>

<h2 align="center"> 🎥 Video Demostrativo</h2>
<p align="center">
<summary><h2 align="center">Ver Funcionamiento</h2></summary>
<a href="URL_DEL_VIDEO_AQUI">
<img width="959" height="auto" alt="Video Demostrativo DP-Inventory" src="Images/Miniaturas_YT.png" />
</a>
</p>
<br><br>

<h2 align="center"> 🔮 Posibles Mejoras Futuras (Roadmap)</h2>
Desarrollos planeados y correcciones en curso para próximas versiones.

<details>
<summary><h2 align="center">🚧 Roadmap y Sugerencias</h2></summary>

| TAREA / IDEA                                     | EXPLICACIÓN                                                                                                                                                                                                                                                                    | ESTADO         |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------- |
| **Menú de Documentos (Tab Personaje)**           | Replicar el script de `k5_documents` desde cero y meter un export para que se acceda directamente desde este botón del inventario.                                                                                                                                             | ⏳ Pendiente   |
| **Posicionamiento de Armas (Tab Armas)**         | Arreglar las posiciones exactas de las pistolas y armas grandes (posiciones de bones) del ped cuando se usa el menú de posicionamiento.                                                                                                                                        | 🛠️ En proceso  |
| **Integración DP-VehicleKeys (Tab Vehículo)**    | Cambiar el botón simple de llaves. Al hacer clic, ocultará los controles y mostrará una lista (estilo panel admin) para dar llaves a cercanos, ver quién tiene copia, etc. Requerirá export al futuro sistema `DP-Vehiclekeys`.                                                | 💡 Planificado |
| **Posicionamiento Libre de la UI (Tab Ajustes)** | Permitir al jugador mover la UI libremente por la pantalla, guardando el Top y Left en la Base de Datos mediante porcentajes (%). Al mover el inventario primario, el secundario/stash/drop se moverá en conjunto dinámicamente con él. (Cono el DP-AdminMenu o DP-Boombox_v2) | 🚀 Próximo     |

</details>

---

<div align="center">
<b>Autor:</b> DP-Scripts<br>
<b>Versión:</b> 1.2.5
</div>
