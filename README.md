Meter esto en el qb-core/shared/items.lua:
- Adelante: Copia y pega el bloque en items.lua tantas veces como necesites.
- Total Libertad: El label (nombre visual para el jugador), weight, image, bagSlots y bagMaxWeight pueden ser literalmente lo que te dé la gana.
- Obligatorio: El name (ID técnico) debe contener siempre la palabra custom_bag al principio (Ejemplos válidos: custom_bag_3, custom_bag_medica, custom_bag_mafia, custom_bag_pruebas_magnificas_script_DP-Scripts).

-- ══════════════════════════════════════════════════════
-- MOCHILAS CUSTOM (SISTEMA STASH - PESO DINÁMICO)
-- ══════════════════════════════════════════════════════
custom_bag_1 = {
    name = 'custom_bag_1',
    label = 'Bolsa de Deporte',
    weight = 500, -- Peso base (vacía). El servidor sumará el peso de los ítems internos aquí.
    type = 'item',
    image = 'custom_bag_1.png',
    unique = true, -- OBLIGATORIO para inyectarle la ID del Stash único
    useable = true, -- Se abre haciendo doble clic o clic derecho -> Usar
    shouldClose = true,
    bagSlots = 15, -- Slots que tendrá el stash al abrirse
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
    bagSlots = 30, -- slots que tendrá el stash al abrirse
    bagMaxWeight = 100000, -- Peso máximo soportado en el interior (100 KG)
    description = 'Macuto reforzado e impermeabilizado. Perfecto para ocultar material sensible. Su peso total en tu inventario dependerá de lo que guardes en su interior.'
},





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













ARREGLOS/IDEAS:
- PAGE/TAB PERSONAJE:
  - BOTÓN DE DOCUMENTOS, HAY QUE REPLICAR EL SCRIPT DE K5_DOCUMENTS DE 0 Y METER UN EXPORT A ESTE BOTÓN.

- PAGE/TAB ARMAS:
  - ARREGLAR LAS POSICIONES DE LAS PISTOLAS EN POSICIONAMIENTO (BONES).

- PAGE/TAB VEHÍCULO:
  - MENÚ DE LLAVES, QUE AL DARLE AL BOTÓN ME QUITE TODOS LOS BOTONES Y ME SALGA UNA LISTA (COMO EN EL PANEL DE ADMIN) CON BOTONES PARA DAR LLAVES A JUGADORES CERCANOS, CONTROLAR QUIEN TIENE LLAVES DEL VEHICULO ETC... (EXPORT AL NUEVO SISTEMA DE DP-VEHICLEKYES, PROXIMAMENTE)

- PAGE/TAB AJUSTES
  - MOVER EL INVENTARIO (ESTE PODRE MOVER EL INVENTARIO DENTRO DE LOS LIMITES DE LA PANTALLA, QUE SE GUARDARA EN LA BASE DE DATOS, IRA CON % TANTO EL TOP COMO EL LEFT... OBVIAMENTE EL INVENTARIO SECUNDARIO/STASH/DROP/GUANTERA/MALETERO SE IRA CON ESTE, DEPENDIENDO DEL QUE TENGA SELECCIONADO EL JUGADOR. TAMBIEN SE IRA TODO DINAMICAMENTE LOS SLOTS DEL ARMOR/MOCHILA Y TABS)