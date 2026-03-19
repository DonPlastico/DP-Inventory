local QBCore = exports['qb-core']:GetCoreObject()

-- ==========================================================================
-- CONFIGURACIÓN: MOCHILAS EXPANSORAS (SISTEMA ANTIGUO)
-- ==========================================================================
local ExpanderBags = {
    ['backpack_1'] = 5,
    ['backpack_2'] = 10,
    ['backpack_3'] = 15,
    ['backpack_4'] = 20
}

-- Función para vigilar cuando alguien se quita una mochila expansora
function CheckBackpackUnequip(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local maxBaseSlots = 41 -- Ajusta según tu Config.MaxSlots
    local allowedSlots = maxBaseSlots

    local bagItem = Player.PlayerData.items[101]
    if bagItem and ExpanderBags[bagItem.name] then
        allowedSlots = maxBaseSlots + ExpanderBags[bagItem.name]
    end

    local itemsToDrop = {}
    local dropSlotIndex = 1

    -- 2 y 3. Bucle para buscar y eliminar ítems en el "limbo" (> allowedSlots)
    for slot, item in pairs(Player.PlayerData.items) do
        -- Ignoramos los slots de ropa/armas (>= 100) y comprobamos si excede la capacidad actual
        if type(slot) == "number" and slot > allowedSlots and slot < 100 then

            -- Clonamos el ítem y le reasignamos un slot desde el 1 para la bolsa del suelo
            local dropItem = item
            dropItem.slot = dropSlotIndex
            itemsToDrop[dropSlotIndex] = dropItem
            dropSlotIndex = dropSlotIndex + 1

            -- Eliminamos el ítem del inventario del jugador de forma segura
            Player.Functions.RemoveItem(item.name, item.amount, slot)
        end
    end

    -- 4. Si encontramos ítems huérfanos, creamos el Drop físicamente
    if #itemsToDrop > 0 then
        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)

        -- Usamos el objeto de caja/bolsa definido en tu Config
        -- CreateObjectNoOffset es nativo del servidor en las nuevas versiones de FiveM
        local bag = CreateObjectNoOffset(Config.ItemDropObject or joaat('prop_paper_bag_small'), coords.x + 0.5,
            coords.y + 0.5, coords.z, true, true, false)
        local dropId = NetworkGetNetworkIdFromEntity(bag)
        local newDropId = 'drop-' .. dropId

        -- Registramos el Drop en la tabla global de tu script (Drops)
        Drops[newDropId] = {
            name = newDropId,
            label = 'Objetos Caídos',
            items = itemsToDrop,
            entityId = dropId,
            createdTime = os.time(),
            coords = coords,
            maxweight = 200000, -- Peso holgado para que nunca de error al crear el drop
            slots = #itemsToDrop,
            isOpen = false,
            isHeld = false
        }

        -- Avisamos a todos los clientes cercanos para que el target o el marcador reconozca la bolsa
        TriggerClientEvent('DP-Inventory:client:setupDropTarget', -1, dropId)

        -- 5. Notificación y actualización visual obligatoria
        TriggerClientEvent('QBCore:Notify', src, '¡Tus objetos se han caído al quitarte la mochila!', 'error', 6000)
        TriggerClientEvent('DP-Inventory:client:updateInventory', src)
    end
end

-- ==========================================================================
-- 1. FUNCIÓN AUXILIAR: GENERADOR DE IDS ÚNICAS PARA MOCHILAS
-- ==========================================================================
local function GenerateBagId()
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local id = 'bag_'
    for i = 1, 6 do
        local rand = math.random(1, #chars)
        id = id .. string.sub(chars, rand, rand)
    end
    return id
end

-- ==========================================================================
-- 2. REGISTRO DINÁMICO DE MOCHILAS (USABLES CON STASH DIRECTO)
-- ==========================================================================
CreateThread(function()
    for itemName, itemData in pairs(QBCore.Shared.Items) do
        if itemData.bagSlots then
            QBCore.Functions.CreateUseableItem(itemName, function(source, item)
                local src = source
                local Player = QBCore.Functions.GetPlayer(src)
                if not Player or not item then
                    return
                end

                -- Si la mochila es nueva, le generamos su ID único y guardamos
                if not item.info or not item.info.bagid then
                    item.info = item.info or {}
                    item.info.bagid = GenerateBagId()

                    Player.PlayerData.items[item.slot] = item
                    Player.Functions.SetInventory(Player.PlayerData.items)
                end

                local bagId = item.info.bagid

                -- 1. Buscamos el Stash en la Caché / Base de Datos nativa de DP-Inventory
                if not Inventories[bagId] then
                    local result = MySQL.Sync.fetchAll('SELECT items FROM inventories WHERE identifier = ?', {bagId})
                    if result[1] and result[1].items then
                        -- Si existe en DB, lo cargamos en RAM con todos sus datos
                        Inventories[bagId] = {
                            items = json.decode(result[1].items) or {},
                            isOpen = false,
                            maxweight = itemData.bagMaxWeight,
                            slots = itemData.bagSlots,
                            label = itemData.label or 'Mochila'
                        }
                    else
                        -- Si no existe en DB, lo creamos de cero con todos sus datos
                        Inventories[bagId] = {
                            items = {},
                            isOpen = false,
                            maxweight = itemData.bagMaxWeight,
                            slots = itemData.bagSlots,
                            label = itemData.label or 'Mochila'
                        }
                        MySQL.Async.execute('INSERT INTO inventories (identifier, items) VALUES (?, ?)', {bagId, '[]'})
                    end
                else
                    -- Parche de seguridad: Si ya estaba en RAM pero le faltaban datos, se los inyectamos
                    Inventories[bagId].maxweight = itemData.bagMaxWeight
                    Inventories[bagId].slots = itemData.bagSlots
                    Inventories[bagId].label = itemData.label or 'Mochila'
                end

                -- 2. Marcamos que TÚ estás usando esta mochila (para evitar que la usen 2 a la vez)
                Inventories[bagId].isOpen = src

                -- 3. Formateamos la estructura exacta que espera tu Vue.js
                local formattedInventory = {
                    name = bagId,
                    label = itemData.label or 'Mochila',
                    maxweight = itemData.bagMaxWeight,
                    slots = itemData.bagSlots,
                    inventory = Inventories[bagId].items
                }

                -- 4. Disparamos la apertura directamente al cliente (Ignorando el backpack_cl.lua)
                TriggerClientEvent('DP-Inventory:client:openInventory', src, Player.PlayerData.items, formattedInventory)
            end)
        end
    end
end)

-- ==========================================================================
-- 3. CÁLCULO DE PESO DINÁMICO AL CERRAR LA MOCHILA
-- ==========================================================================
AddEventHandler('DP-Inventory:server:UpdateBagWeight', function(src, bagId)
    -- Quitamos el 'local src = source' porque ya recibimos src como argumento
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    -- Filtro de seguridad
    if type(bagId) ~= "string" or not string.find(bagId, "^bag_") then
        return
    end

    -- Obtenemos los ítems que hay dentro de la mochila (leyendo de tu tabla global Inventories)
    local bagItems = {}
    if Inventories[bagId] and Inventories[bagId].items then
        bagItems = Inventories[bagId].items
    else
        -- Fallback de seguridad
        local result = MySQL.Sync.fetchAll('SELECT items FROM inventories WHERE identifier = ?', {bagId})
        if result[1] and result[1].items then
            bagItems = json.decode(result[1].items) or {}
        end
    end

    -- 3.1. Sumamos el peso total de los ítems en el interior
    local totalInternalWeight = 0
    for _, item in pairs(bagItems) do
        if item and item.name then
            local sharedItem = QBCore.Shared.Items[item.name:lower()]
            if sharedItem and sharedItem.weight then
                totalInternalWeight = totalInternalWeight + (sharedItem.weight * item.amount)
            end
        end
    end

    -- 3.2. División matemática del peso (Peso Total / 3)
    local dynamicWeight = math.floor(totalInternalWeight / 3)

    -- 3.3. Buscamos la mochila y actualizamos su peso en la metadata
    local bagFoundAndUpdated = false
    for slot, item in pairs(Player.PlayerData.items) do
        if item.info and item.info.bagid == bagId then
            item.info.weight = dynamicWeight
            Player.PlayerData.items[slot] = item
            bagFoundAndUpdated = true
            break
        end
    end

    if bagFoundAndUpdated then
        Player.Functions.SetInventory(Player.PlayerData.items)
        TriggerClientEvent('DP-Inventory:client:updateInventory', src)
    end
end)

