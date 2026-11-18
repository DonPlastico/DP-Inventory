-- ============================================================
--  DP-INVENTORY · locales/en.lua  –  English (default)
--
--  Este es el idioma BASE / FALLBACK del sistema.
--  Si el servidor no tiene configurado un idioma (qb_locale),
--  o si una clave no existe en el idioma activo, se usa este.
--
--  Para activar otro idioma en el servidor:
--    setr qb_locale "es"   → en server.cfg
--
--  SECCIONES:
--    progress    → Textos de barras de progreso
--    notify      → Notificaciones del sistema de inventario
--    inf_mapping → Descripciones de keybinds (menú de controles de GTA)
--    menu        → Etiquetas de menús contextuales (TextUI / DP-Menu)
--    interaction → Textos de interacción en pantalla (estilo GTA ~color~)
-- ============================================================
local Translations = {

    -- ──────────────────────────────────────────────
    --  BARRAS DE PROGRESO
    --  Texto mostrado durante una acción con barra de progreso.
    -- ──────────────────────────────────────────────
    progress = {
        ['snowballs'] = 'Collecting snowballs..'
    },

    -- ──────────────────────────────────────────────
    --  NOTIFICACIONES
    --  Mensajes de error, éxito e información del inventario.
    --  Usados con Lang:t('notify.clave') en Lua.
    -- ──────────────────────────────────────────────
    notify = {
        ['failed'] = 'Failed',
        ['canceled'] = 'Canceled',
        ['vlocked'] = 'Vehicle Locked', -- Al intentar abrir un maletero con el coche cerrado
        ['notowned'] = 'You do not own this item!',
        ['missitem'] = 'You don\'t have this item!',
        ['nonb'] = 'No one nearby!', -- Al intentar dar un ítem sin jugadores cerca
        ['noaccess'] = 'Not Accessible',
        ['nosell'] = 'You can\'t sell this item..',
        ['itemexist'] = 'Item doesn\'t exist',
        ['notencash'] = 'You don\'t have enough cash..',
        ['noitem'] = 'You don\'t have the right items..',
        ['gsitem'] = 'You can\'t give yourself an item?', -- Auto-regalo bloqueado
        ['tftgitem'] = 'You are too far away to give items!', -- Distancia máxima superada
        ['infound'] = 'Item you tried giving not found!', -- El ítem no está en el inventario
        ['iifound'] = 'Incorrect item found try again!', -- Slot incorrecto al dar
        ['gitemrec'] = 'You Received ', -- Prefijo: "You Received 2x water_bottle"
        ['gitemfrom'] = ' From ', -- Sufijo:  "You Received X From NombreJugador"
        ['gitemyg'] = 'You gave ', -- Prefijo: "You gave 1x pistol"
        ['gitinvfull'] = 'The other players inventory is full!',
        ['giymif'] = 'Your inventory is full!',
        ['gitydhei'] = 'You do not have enough of the item',
        ['gitydhitt'] = 'You do not have enough items to transfer',
        ['navt'] = 'Not a valid type..',
        ['anfoc'] = 'Arguments not filled out correctly..',
        ['yhg'] = 'You Have Given ', -- Confirmación tras dar un ítem
        ['cgitem'] = 'Can\'t give item!',
        ['idne'] = 'Item Does Not Exist',
        ['pdne'] = 'Player Is Not Online'
    },

    -- ──────────────────────────────────────────────
    --  KEYBIND DESCRIPTIONS
    --  Aparecen en el menú de controles de GTA V (Settings → Key Bindings).
    --  El texto describe la acción del keybind al jugador.
    -- ──────────────────────────────────────────────
    inf_mapping = {
        ['opn_inv'] = 'Open Inventory', -- Keybind: abrir inventario (F2 por defecto)
        ['tog_slots'] = 'Toggles keybind slots', -- Keybind: mostrar/ocultar hotbar (Z por defecto)
        ['use_item'] = 'Uses the item in slot ' -- Keybind: usar ítem del slot 1-5 (teclas 1-5)
    },

    -- ──────────────────────────────────────────────
    --  ETIQUETAS DE MENÚ
    --  Textos mostrados en TextUI y menús contextuales.
    -- ──────────────────────────────────────────────
    menu = {
        ['vending'] = 'Vending Machine', -- TextUI al acercarse a una máquina expendedora
        ['bin'] = 'Open Dumpster', -- TextUI al acercarse a un contenedor
        ['craft'] = 'Craft', -- Opción de crafteo en menú contextual
        ['o_bag'] = 'Open Bag' -- TextUI al acercarse a una mochila/bolsa
    },

    -- ──────────────────────────────────────────────
    --  INTERACCIONES EN PANTALLA
    --  Formato de texto nativo de GTA: ~color~texto~w~
    --  ~g~ = verde  |  ~w~ = blanco  |  ~r~ = rojo
    -- ──────────────────────────────────────────────
    interaction = {
        ['craft'] = '~g~E~w~ - Craft' -- Texto en pantalla para iniciar crafteo
    },

    -- ──────────────────────────────────────────────
    --  SIM SYSTEM
    --  Combine/extract errors and success messages.
    -- ──────────────────────────────────────────────
    sim = {
        ['error_busy'] = 'Another operation is in progress. Please wait.',
        ['error_invalid'] = 'Invalid action.',
        ['error_not_combinable'] = 'These items cannot be combined.',
        ['error_phone_no_imei'] = 'This phone has no IMEI.',
        ['error_sim_not_activated'] = 'This SIM is not activated.',
        ['error_phone_has_sim'] = 'This phone already has a SIM.',
        ['error_sim_in_other_phone'] = 'This SIM is already inserted in another phone.',
        ['error_phone_no_sim'] = 'This phone has no SIM.',
        ['error_no_space'] = 'You have no space for the SIM.',
        ['error_internal'] = 'An unexpected error occurred.'
    }
}

-- En.lua es el idioma base: se carga SIEMPRE como fallback.
-- Los demás locales lo referencian con `fallbackLang = Lang`.
Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true -- Avisa en consola si se usa una clave que no existe
})
