-- ============================================================
--  DP-INVENTORY · config/config.lua
--  Configuración global del inventario.
--  Este archivo es el punto de ajuste principal para los
--  administradores del servidor. Modifica aquí para cambiar
--  límites de peso, slots, keybinds, drops y máquinas.
-- ============================================================
Config = {

    -- ──────────────────────────────────────────────────────
    --  CAPACIDAD DEL INVENTARIO DEL JUGADOR
    --  Unidades de peso: las mismas que uses en tus ítems.
    --  Ejemplo: si un ítem pesa 100, con MaxWeight=1200000
    --  el jugador puede llevar 12.000 unidades de ese ítem.
    -- ──────────────────────────────────────────────────────
    MaxWeight = 1200000, -- Peso máximo del inventario del jugador
    MaxSlots = 35, -- Número de slots del inventario del jugador

    -- ──────────────────────────────────────────────────────
    --  CAPACIDAD DE STASHES (Almacenes / Cajas / Baúles)
    --  Usado como valor por defecto al crear un stash sin
    --  parámetros específicos (CreateInventory sin data).
    -- ──────────────────────────────────────────────────────
    StashSize = {
        maxweight = 2000000, -- Peso máximo de un stash genérico
        slots = 100 -- Slots de un stash genérico
    },

    -- ──────────────────────────────────────────────────────
    --  CAPACIDAD DE DROPS (Bolsas en el suelo)
    --  Aplica a todos los drops creados al tirar un ítem.
    -- ──────────────────────────────────────────────────────
    DropSize = {
        maxweight = 1200000, -- Peso máximo de una bolsa en el suelo
        slots = 100 -- Slots de una bolsa en el suelo
    },

    -- ──────────────────────────────────────────────────────
    --  KEYBINDS
    --  Teclas por defecto para abrir el inventario y la hotbar.
    --  El jugador puede reasignarlas desde los ajustes de GTA.
    -- ──────────────────────────────────────────────────────
    Keybinds = {
        Open = 'F2', -- Tecla para abrir el inventario
        Hotbar = 'Z' -- Tecla para mostrar/ocultar la hotbar
    },

    -- ──────────────────────────────────────────────────────
    --  LIMPIEZA AUTOMÁTICA DE DROPS
    --  El servidor elimina periódicamente drops abandonados
    --  para evitar acumulación de entidades en el mundo.
    -- ──────────────────────────────────────────────────────
    CleanupDropTime = 15, -- Tiempo de vida de un drop en minutos (se elimina al llegar aquí)
    CleanupDropInterval = 1, -- Cada cuántos minutos el servidor escanea drops a limpiar

    -- ──────────────────────────────────────────────────────
    --  OBJETO 3D DE LOS DROPS (Bolsa en el suelo)
    --  Define el prop de GTA que representa visualmente la bolsa
    --  y cómo se adjunta al ped cuando el jugador la recoge.
    -- ──────────────────────────────────────────────────────
    ItemDropObject = 'prop_paper_bag_01', -- Nombre del modelo 3D de la bolsa

    ItemDropObjectBone = 28422, -- Hueso del ped al que se adjunta al llevarla en la mano
    -- 28422 = mano derecha (IK_R_Hand)

    -- Offset de posición (vector3) y rotación (vector3) de la bolsa respecto al hueso.
    -- [1] = posición relativa al hueso  [2] = rotación relativa al hueso
    ItemDropObjectOffset = {vector3(0.260000, 0.040000, 0.000000), -- Posición (x, y, z)
    vector3(90.000000, 0.000000, -78.989998) -- Rotación (x_rot, y_rot, z_rot)
    },

    -- ──────────────────────────────────────────────────────
    --  MÁQUINAS EXPENDEDORAS (Vending Machines)
    --  Lista de modelos de objetos del mundo que actúan como
    --  tiendas de snacks. El jugador puede interactuar con
    --  ellas pulsando E al acercarse (radio de 2.5m).
    --  Añade aquí cualquier prop de expendedora personalizada.
    -- ──────────────────────────────────────────────────────
    VendingObjects = {'prop_vend_soda_01', -- Máquina de refrescos (variante 1)
    'prop_vend_soda_02', -- Máquina de refrescos (variante 2)
    'prop_vend_water_01', -- Máquina de agua
    'prop_vend_coffe_01' -- Máquina de café
    },

    -- ──────────────────────────────────────────────────────
    --  ÍTEMS DE LAS MÁQUINAS EXPENDEDORAS
    --  Lista de ítems disponibles en TODAS las expendedoras.
    --  · name   → nombre interno del ítem (QBCore.Shared.Items)
    --  · price  → precio en dinero del servidor ($ por unidad)
    --  · amount → cantidad de stock mostrada en la tienda
    -- ──────────────────────────────────────────────────────
    VendingItems = {{
        name = 'kurkakola',
        price = 4,
        amount = 50
    }, {
        name = 'water_bottle',
        price = 4,
        amount = 50
    }}
}
