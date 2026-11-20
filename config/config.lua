-- DP-Inventory · config/config.lua

Config = {

    MaxWeight = 1200000,
    MaxSlots = 35,

    StashSize = {
        maxweight = 2000000,
        slots = 100
    },

    DropSize = {
        maxweight = 1200000,
        slots = 100
    },

    Keybinds = {
        Open = 'F2',
        Hotbar = 'Z'
    },

    CleanupDropTime = 15,
    CleanupDropInterval = 1,

    ItemDropObject = 'prop_paper_bag_01',
    ItemDropObjectBone = 28422,
    ItemDropObjectOffset = {
        vector3(0.260000, 0.040000, 0.000000),
        vector3(90.000000, 0.000000, -78.989998)
    },

    VendingObjects = {
        'prop_vend_soda_01',
        'prop_vend_soda_02',
        'prop_vend_water_01',
        'prop_vend_coffe_01'
    },

    VendingItems = {
        { name = 'kurkakola', price = 4, amount = 50 },
        { name = 'water_bottle', price = 4, amount = 50 }
    },

    Sim = {
        enableLog = true,
        pendingTimeoutMs = 15000,
        actionCooldownMs = 1500,
        debug = false
    },

    -- Schema / migración
    -- Al iniciar el recurso siempre se ejecuta CREATE TABLE IF NOT EXISTS.
    -- La migración desde qb-inventory / lj-inventory SOLO corre con el comando admin.
    Database = {
        autoCreateTables = true,
        -- Comandos (permiso admin/god):
        --   /dpinv_migrate     → copia gloveboxitems + stashitems + trunkitems → inventories
        --   /dpinv_drop_legacy → borra gloveboxitems, stashitems, trunkitems (IRREVERSIBLE)
        migrateCommand = 'dpinv_migrate',
        dropLegacyCommand = 'dpinv_drop_legacy',
        dropLegacyRequiresConfirm = true
    }
}
