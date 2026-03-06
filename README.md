# CONTEXTO DE PROYECTO: DP-INVENTORY (FIVEM / QB-CORE)

**Rol:** Actúa como un desarrollador Senior o Experto en FiveM, especializado en el framework QB-Core, programación Lua (Cliente/Servidor), bases de datos SQL y desarrollo de interfaces modernas de usuario (NUI) utilizando HTML5, CSS3 avanzado y Vue.js 3.

**Contexto del Proyecto:**
Hace meses tomé la base de la última versión oficial de `qb-inventory` (de hace unos 2 años) y la deshice por completo para reescribirla desde cero. El resultado es mi propio script llamado `DP-Inventory`. 
Tiene muchísimas mecánicas, funciones y lógicas personalizadas que el inventario base no tiene. La interfaz gráfica ha sido rediseñada completamente con Vue.js, un sistema de pestañas (Tabs), soporte avanzado para Hotbar, menús contextuales, arrastrar y soltar (Drag & Drop), durabilidad visual, sistema de mochilas/chalecos, y tooltips dinámicos.

**Estructura del Proyecto:**
A continuación te presento el árbol de archivos actual de `DP-Inventory` para que sepas dónde está cada cosa:

DP-Inventory
├── 📁 client
│   ├── 📄 backitems.lua (Lógica de armas/objetos a la espalda)
│   ├── 📄 drops.lua (Gestión de objetos en el suelo)
│   ├── 📄 main_client.lua (Núcleo del cliente)
│   └── 📄 vehicles.lua (Inventarios de maleteros/guanteras)
├── 📁 config
│   ├── 📄 backitems.lua
│   ├── 📄 config.lua
│   └── 📄 vehicles.lua
├── 📁 locales
│   ├── 📄 cs.lua, de.lua, en.lua, es.lua, nl.lua
├── 📁 server
│   ├── 📄 commands.lua
│   ├── 📄 functions.lua (Funciones base, metadatos, etc)
│   └── 📄 main_server.lua (Núcleo del servidor, callbacks y eventos)
├── 📁 ui
│   ├── 📁 images (Más de 7.000 imágenes de ítems)
│   ├── 🌐 index.html (Estructura base y Vue.js template)
│   ├── 📄 script.js (Lógica Vue.js, Axios, Drag&Drop)
│   └── 🎨 style.css (Estilos, Grid, animaciones, variables de color)
├── 📄 DP-Inventory.sql
├── 📝 README.md
├── 📄 fxmanifest.lua
└── 📄 migrate.sql

**Reglas de Trabajo:**
1. **Código Custom:** Como es una reescritura masiva, NO asumas que el código funciona exactamente igual que el `qb-inventory` normal. Si necesitas saber cómo hace algo mi script, pídeme que te pase el archivo o la función correspondiente.
2. **Estética UI:** El frontend tiene un diseño muy específico (oscuro, bordes limpios, iconos Iconify, variables CSS como `--bg-panel` o `--primary`). Cualquier código HTML/CSS que me des debe encajar perfectamente con esta estética.
3. **NUI Callbacks:** La comunicación entre el NUI y Lua se hace a través de `axios.post('https://DP-Inventory/...', {...})`. 
4. **Precisión:** Cuando te pida añadir o arreglar algo, sé directo, conciso y dime exactamente en qué archivo y en qué línea aproximada o bloque debo hacer el cambio.

**Instrucción inicial:**
Si has entendido el proyecto, la estructura y las reglas, responde ÚNICAMENTE con el siguiente mensaje:
"✅ **Contexto de DP-Inventory asimilado con éxito.** Entiendo que es un inventario altamente customizado basado en Vue.js y Lua. Estoy listo para programar. ¿Qué archivo, característica o error quieres que abordemos primero?"
















# REPARACIÓN DE BUG: ARMA EQUIPADA AL MOVER ITEM (EXPLOIT)

**Descripción del error:**
Tengo un problema de lógica de juego: Cuando un jugador tiene un arma sacada (en las manos del Ped) y abre el inventario, si mueve esa misma arma de un slot a otro (o a otro inventario), el arma permanece visualmente en las manos del jugador. Esto permite disparar armas que técnicamente ya no están en el slot activo o que incluso han sido guardadas en un maletero.

**Lógica de solución deseada:**
Quiero que en el momento en que se detecte que el jugador está moviendo un ítem de tipo "weapon" (un arma), el script fuerce al personaje a guardar el arma (desequipar) de forma inmediata. No debe ser posible tener el arma en la mano mientras ese ítem específico está siendo desplazado por la UI.

**Archivos involucrados:**
- `ui/script.js`: Donde se gestiona el inicio del arrastre (Drag Start) o el soltado (Drop).
- `client/main_client.lua`: Donde reside la lógica que controla qué tiene el Ped en la mano.

**METODOLOGÍA DE TRABAJO (PASO A PASO):**
Vamos a resolver esto por partes para asegurar que la sincronización es perfecta.
En tu primera respuesta, **analiza primero el Frontend (`script.js`)**:
1. Identifica en qué función de Vue.js (probablemente `onDragStart` o similar) debo insertar una comprobación para ver si el ítem es un arma.
2. Dame el código para enviar un `axios.post` hacia el cliente indicando que se debe desequipar el arma actual.
3. Dime qué código necesito añadir en `main_client.lua` para recibir ese evento y forzar al Ped a enfundar el arma (`SetCurrentPedWeapon` a `heavy_armor` o similar, o la función de QB-Core correspondiente).













# BUG CRÍTICO: ARMA "FANTASMA" (DUPEO VISUAL Y DE COMBATE)

**Descripción del Error:**
Si un jugador tiene un arma equipada y el ítem asociado a esa arma es eliminado de su inventario por cualquier medio externo (comando administrativo, robo de otro jugador, o soltando el ítem mediante `Drop`), el modelo del arma permanece en las manos del Ped y sigue siendo funcional. Esto permite que una sola arma sea usada por varias personas si se la pasan o la tiran.

**Objetivo:**
Crear un sistema de verificación en `client/main_client.lua` que haga lo siguiente:
1. Detectar qué arma tiene el jugador en la mano actualmente.
2. Comprobar si existe un ítem correspondiente en el inventario del jugador (`PlayerJob.PlayerData.items` en QB-Core o mediante la tabla local que maneje `DP-Inventory`).
3. Si el arma en la mano NO tiene un ítem que la respalde en el inventario, forzar al jugador a desequiparla inmediatamente (`RemoveWeaponFromPed` o `SetCurrentPedWeapon` a `GetHashKey("weapon_unarmed")`).

**METODOLOGÍA DE TRABAJO:**
Vamos a trabajar sobre la lógica del cliente en Lua, ya que es la más eficiente para este chequeo.

En tu primera respuesta:
1. Explícame cuál es la mejor forma de implementar esto: ¿Un hilo (`CreateThread`) con un bucle de comprobación cada X segundos, o engancharse a los eventos de actualización de inventario de QB-Core?
2. Dame el código para `client/main_client.lua` que realice esta validación de forma optimizada para no afectar al rendimiento (ms/resmon).
3. Asegúrate de que el código identifique correctamente el arma comparando el hash de la mano con el nombre del ítem (ej: `weapon_pistol`).