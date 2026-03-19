-- ============================================================
--  DP-INVENTORY · server/commands.lua
--  Comandos de administración e interacción del inventario,
--  y keybindings del servidor (inventory, hotbar, closeInv).
--
--  ÍNDICE DE CONTENIDOS
--  ─────────────────────────────────────────────────────────
--  [1]  COMANDOS ADMIN
--         · giveitem    – dar ítems a jugadores (admin)
--         · randomitems – recibir 10 ítems aleatorios (god)
--         · clearinv    – vaciar inventario de un jugador (admin)
--  [2]  KEYBINDINGS / COMANDOS DE SISTEMA
--         · closeInv    – cerrar inventario
--         · hotbar      – toggle hotbar
--         · inventory   – abrir inventario / maletero / guantera
-- ============================================================
-- ============================================================
--  [1] COMANDOS ADMIN
-- ============================================================
--- Da uno o varios ítems a un jugador desde la consola o el chat.
--- Genera metadatos especiales para ítems con info estructurada
--- (DNI, licencia, armas con serie+calidad, arnés, billetes marcados...).
--- Requiere permiso: admin
---
--- Uso: /giveitem [id] [item] [amount]
QBCore.Commands.Add('giveitem', 'Give An Item (Admin Only)', {{
    name = 'id',
    help = 'Player ID'
}, {
    name = 'item',
    help = 'Name of the item (not a label)'
}, {
    name = 'amount',
    help = 'Amount of items'
}}, false, function(source, args)
    local id = tonumber(args[1])
    local player = QBCore.Functions.GetPlayer(id)
    local amount = tonumber(args[3]) or 1
    local itemData = QBCore.Shared.Items[tostring(args[2]):lower()]

    if not player then
        return QBCore.Functions.Notify(source, Lang:t('notify.pdne'), 'error')
    end
    if not itemData then
        return QBCore.Functions.Notify(source, Lang:t('notify.idne'), 'error')
    end

    local info = {}
    local itemName = itemData['name']

    -- Metadatos especiales por tipo de ítem
    if itemName == 'id_card' then
        -- DNI: rellena con los datos del personaje del receptor
        info.citizenid = player.PlayerData.citizenid
        info.firstname = player.PlayerData.charinfo.firstname
        info.lastname = player.PlayerData.charinfo.lastname
        info.birthdate = player.PlayerData.charinfo.birthdate
        info.gender = player.PlayerData.charinfo.gender
        info.nationality = player.PlayerData.charinfo.nationality

    elseif itemName == 'driver_license' then
        -- Licencia de conducir
        info.firstname = player.PlayerData.charinfo.firstname
        info.lastname = player.PlayerData.charinfo.lastname
        info.birthdate = player.PlayerData.charinfo.birthdate
        info.type = 'Class C Driver License'

    elseif itemData['type'] == 'weapon' then
        -- Las armas siempre se dan de 1 en 1 con serie aleatoria y calidad al 100%
        amount = 1
        info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) ..
                                  QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
        info.quality = 100

    elseif itemName == 'harness' then
        info.uses = 20 -- Arnés con 20 usos

    elseif itemName == 'markedbills' then
        info.worth = math.random(5000, 10000) -- Valor aleatorio entre 5k y 10k

    elseif itemName == 'printerdocument' then
        info.url =
            'https://cdn.discordapp.com/attachments/870094209783308299/870104331142189126/Logo_-_Display_Picture_-_Stylized_-_Red.png'
    end

    if AddItem(id, itemName, amount, false, info, 'give item command') then
        QBCore.Functions.Notify(source,
            Lang:t('notify.yhg') .. GetPlayerName(id) .. ' ' .. amount .. ' ' .. itemName .. '', 'success')
        TriggerClientEvent('DP-Inventory:client:ItemBox', id, itemData, 'add', amount)
        -- Si el receptor tiene el inventario abierto, lo actualizamos en vivo
        if Player(id).state.inv_busy then
            TriggerClientEvent('DP-Inventory:client:updateInventory', id)
        end
    else
        QBCore.Functions.Notify(source, Lang:t('notify.cgitem'), 'error')
    end
end, 'admin')

--- Da 10 ítems aleatorios al jugador que ejecuta el comando.
--- Excluye armas para evitar abuso. La lista filtrada se cachea
--- la primera vez para no recalcularla en cada ejecución.
--- Requiere permiso: god
---
--- Uso: /randomitems
local filteredRandomItems = nil -- Cache: se construye solo la primera vez

QBCore.Commands.Add('randomitems', 'Receive random items', {}, false, function(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        return
    end

    -- Construimos la lista filtrada (sin armas) solo la primera vez
    if not filteredRandomItems then
        filteredRandomItems = {}
        for _, v in pairs(QBCore.Shared.Items) do
            if v['type'] ~= 'weapon' then
                filteredRandomItems[#filteredRandomItems + 1] = v
            end
        end
    end

    local playerInventory = player.PlayerData.items

    for _ = 1, 10, 1 do
        local randitem = filteredRandomItems[math.random(1, #filteredRandomItems)]
        -- Ítems únicos siempre 1 unidad; resto entre 1 y 10
        local amount = randitem['unique'] and 1 or math.random(1, 10)
        local emptySlot = nil

        -- Buscamos el primer slot libre del jugador
        for i = 1, Config.MaxSlots do
            if not playerInventory[i] then
                emptySlot = i
                break
            end
        end

        if emptySlot then
            if AddItem(source, randitem.name, amount, emptySlot, false, 'random items command') then
                TriggerClientEvent('DP-Inventory:client:ItemBox', source, QBCore.Shared.Items[randitem.name], 'add')
                if Player(source).state.inv_busy then
                    TriggerClientEvent('DP-Inventory:client:updateInventory', source)
                end
            end
        end
    end
end, 'god')

--- Vacía el inventario de un jugador.
--- Si no se especifica ID, vacía el inventario del ejecutor.
--- Requiere permiso: admin
---
--- Uso: /clearinv [id]
QBCore.Commands.Add('clearinv', 'Clear Inventory (Admin Only)', {{
    name = 'id',
    help = 'Player ID'
}}, false, function(source, args)
    local id = tonumber(args[1]) or source
    ClearInventory(id) -- De functions.lua
end, 'admin')

--- [COMANDO DE PRUEBA - BORRAR O COMENTAR EN PRODUCCIÓN]
--- Simula que un sistema externo (ej: un script de robo) solicita 
--- tener ciertos ítems en el inventario para poder continuar.
--- Visible durante 10 segundos para pruebas de diseño CSS.
--- Requiere permiso: admin
---
--- Uso: /testreq
QBCore.Commands.Add('testreq', 'Probar UI de Items Requeridos (Test)', {}, false, function(source, args)
    local items = {
        [1] = {
            name = 'phone',
            image = 'phone.png'
        },
        [2] = {
            name = 'radio',
            image = 'Jobs/radio.png'
        },
        [3] = {
            name = 'id_card',
            image = 'id_card.png'
        },
        [4] = {
            name = 'lockpick',
            image = 'Robos/lockpick.png'
        },
        [5] = {
            name = 'thermite',
            image = 'Robos/thermite.png'
        },
        [6] = {
            name = 'laptop',
            image = 'laptop.png'
        },
        [7] = {
            name = 'armor',
            image = 'Armas/armor.png'
        },
        [8] = {
            name = 'weapon_pistol',
            image = 'Armas/weapon_pistol.png'
        }
    }

    -- Dispara el evento al cliente que ejecutó el comando
    TriggerClientEvent('DP-Inventory:client:requiredItems', source, items, true)

    -- Lo oculta automáticamente a los 10 segundos (10000 ms) para darte tiempo a ver el CSS
    SetTimeout(10000, function()
        TriggerClientEvent('DP-Inventory:client:requiredItems', source, {}, false)
    end)
end, 'admin')

-- ============================================================
--  [2] KEYBINDINGS / COMANDOS DE SISTEMA
-- ============================================================

--- Cierra el inventario del jugador desde el servidor.
--- Usado internamente como keybind de cierre (Escape / tecla configurada).
RegisterCommand('closeInv', function(source)
    CloseInventory(source) -- De functions.lua
end, false)

--- Alterna la visibilidad de la hotbar.
--- Protecciones: inv_busy, muerto, inconsciente o esposado.
--- Devuelve los primeros 5 slots del inventario a la UI.
RegisterCommand('hotbar', function(source)
    if Player(source).state.inv_busy then
        return
    end

    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer or QBPlayer.PlayerData.metadata['isdead'] or QBPlayer.PlayerData.metadata['inlaststand'] or
        QBPlayer.PlayerData.metadata['ishandcuffed'] then
        return
    end

    local items = QBPlayer.PlayerData.items
    -- Solo enviamos los 5 slots de la hotbar (slots 1-5)
    local hotbarItems = {items[1], items[2], items[3], items[4], items[5]}
    TriggerClientEvent('DP-Inventory:client:hotbar', source, hotbarItems)
end, false)

--- Comando principal de apertura del inventario (F2 por defecto).
--- Protecciones: inv_busy, muerto, inconsciente o esposado.
---
--- Flujo de decisión (via callback vehicleCheck del cliente):
---   · callback devuelve nil          → inventario personal (bolsillos)
---   · callback devuelve 'glovebox-X' → guantera del vehículo actual
---   · callback devuelve 'trunk-X'    → maletero del vehículo más cercano
---
--- La capacidad de guantera/maletero se lee de config/vehicles.lua
--- (VehicleStorage) con fallback a los valores por defecto.
RegisterCommand('inventory', function(source)
    if Player(source).state.inv_busy then
        return
    end

    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer or QBPlayer.PlayerData.metadata['isdead'] or QBPlayer.PlayerData.metadata['inlaststand'] or
        QBPlayer.PlayerData.metadata['ishandcuffed'] then
        return
    end

    QBCore.Functions.TriggerClientCallback('DP-Inventory:client:vehicleCheck', source, function(inventory, class)
        if not inventory then
            -- Sin vehículo ni maletero → inventario personal
            return OpenInventory(source)
        end

        -- Valores por defecto seguros por si VehicleStorage no está configurado
        local defaultSlots = 35
        local defaultWeight = 60000

        if VehicleStorage and VehicleStorage.default then
            defaultSlots = VehicleStorage.default.slots or 35
            defaultWeight = VehicleStorage.default.maxWeight or 60000
        end

        -- Capacidad del maletero según clase del vehículo
        local slots = VehicleStorage and VehicleStorage[class] and VehicleStorage[class].trunkSlots or defaultSlots
        local maxweight = VehicleStorage and VehicleStorage[class] and VehicleStorage[class].trunkWeight or
                              defaultWeight

        -- Si es guantera, usamos los valores de glovebox en lugar de trunk
        if inventory:find('glovebox-') then
            if VehicleStorage and VehicleStorage.default then
                defaultSlots = VehicleStorage.default.gloveboxSlots or 5
                defaultWeight = VehicleStorage.default.gloveboxWeight or 10000
            end
            slots = VehicleStorage and VehicleStorage[class] and VehicleStorage[class].gloveboxSlots or defaultSlots
            maxweight = VehicleStorage and VehicleStorage[class] and VehicleStorage[class].gloveboxWeight or
                            defaultWeight
        end

        OpenInventory(source, inventory, {
            slots = slots,
            maxweight = maxweight
        })
    end)
end, false)
