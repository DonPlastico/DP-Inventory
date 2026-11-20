-- DP-Inventory · server/backpack_sv.lua

local QBCore = exports['qb-core']:GetCoreObject()

local ExpanderBags = {
    ['backpack_1'] = 5,
    ['backpack_2'] = 10,
    ['backpack_3'] = 15,
    ['backpack_4'] = 20
}

function CheckBackpackUnequip(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local maxBaseSlots = 35
    local allowedSlots = maxBaseSlots

    local bagItem = Player.PlayerData.items[101]
    if bagItem and ExpanderBags[bagItem.name] then
        allowedSlots = maxBaseSlots + ExpanderBags[bagItem.name]
    end

    local itemsToDrop = {}
    local dropSlotIndex = 1

    for slot, item in pairs(Player.PlayerData.items) do
        if type(slot) == "number" and slot > allowedSlots and slot < 100 then
            local dropItem = item
            dropItem.slot = dropSlotIndex
            itemsToDrop[dropSlotIndex] = dropItem
            dropSlotIndex = dropSlotIndex + 1

            Player.Functions.RemoveItem(item.name, item.amount, slot)
        end
    end

    if #itemsToDrop > 0 then
        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)

        local bag = CreateObjectNoOffset(Config.ItemDropObject or joaat('prop_paper_bag_small'), coords.x + 0.5,
            coords.y + 0.5, coords.z, true, true, false)
        local dropId = NetworkGetNetworkIdFromEntity(bag)
        local newDropId = 'drop-' .. dropId

        Drops[newDropId] = {
            name = newDropId,
            label = 'Objetos Caídos',
            items = itemsToDrop,
            entityId = dropId,
            createdTime = os.time(),
            coords = coords,
            maxweight = 200000,
            slots = #itemsToDrop,
            isOpen = false,
            isHeld = false
        }

        TriggerClientEvent('DP-Inventory:client:setupDropTarget', -1, dropId)

        TriggerClientEvent('QBCore:Notify', src, '¡Tus objetos se han caído al quitarte la mochila!', 'error', 6000)
        TriggerClientEvent('DP-Inventory:client:updateInventory', src)
    end
end

local function GenerateBagId()
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local id = 'bag_'
    for i = 1, 6 do
        local rand = math.random(1, #chars)
        id = id .. string.sub(chars, rand, rand)
    end
    return id
end

CreateThread(function()
    for itemName, itemData in pairs(QBCore.Shared.Items) do
        if itemData.bagSlots then
            QBCore.Functions.CreateUseableItem(itemName, function(source, item)
                local src = source
                local Player = QBCore.Functions.GetPlayer(src)
                if not Player or not item then
                    return
                end

                if not item.info or not item.info.bagid then
                    item.info = item.info or {}
                    item.info.bagid = GenerateBagId()

                    Player.PlayerData.items[item.slot] = item
                    Player.Functions.SetInventory(Player.PlayerData.items)
                end

                local bagId = item.info.bagid

                if not Inventories[bagId] then
                    local result = MySQL.Sync.fetchAll('SELECT items FROM inventories WHERE identifier = ?', {bagId})
                    if result[1] and result[1].items then
                        Inventories[bagId] = {
                            items = json.decode(result[1].items) or {},
                            isOpen = false,
                            maxweight = itemData.bagMaxWeight,
                            slots = itemData.bagSlots,
                            label = itemData.label or 'Mochila'
                        }
                    else
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
                    Inventories[bagId].maxweight = itemData.bagMaxWeight
                    Inventories[bagId].slots = itemData.bagSlots
                    Inventories[bagId].label = itemData.label or 'Mochila'
                end

                Inventories[bagId].isOpen = src

                local formattedInventory = {
                    name = bagId,
                    label = itemData.label or 'Mochila',
                    maxweight = itemData.bagMaxWeight,
                    slots = itemData.bagSlots,
                    inventory = Inventories[bagId].items
                }

                TriggerClientEvent('DP-Inventory:client:openBagInventory', src, Player.PlayerData.items, formattedInventory)
            end)
        end
    end
end)

AddEventHandler('DP-Inventory:server:UpdateBagWeight', function(src, bagId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    if type(bagId) ~= "string" or not string.find(bagId, "^bag_") then
        return
    end

    local bagItems = {}
    if Inventories[bagId] and Inventories[bagId].items then
        bagItems = Inventories[bagId].items
    else
        local result = MySQL.Sync.fetchAll('SELECT items FROM inventories WHERE identifier = ?', {bagId})
        if result[1] and result[1].items then
            bagItems = json.decode(result[1].items) or {}
        end
    end

    local totalInternalWeight = 0
    for _, item in pairs(bagItems) do
        if item and item.name then
            local sharedItem = QBCore.Shared.Items[item.name:lower()]
            if sharedItem and sharedItem.weight then
                totalInternalWeight = totalInternalWeight + (sharedItem.weight * item.amount)
            end
        end
    end

    local dynamicWeight = math.floor(totalInternalWeight / 3)

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


QBCore.Functions.CreateCallback('DP-Inventory:server:GetBagPreview', function(source, cb, bagId)
    if type(bagId) ~= 'string' or not string.find(bagId, '^bag_') then
        return cb(nil)
    end

    local items = {}
    local maxweight = 0
    local slots = 0

    if Inventories[bagId] then
        items = Inventories[bagId].items or {}
        maxweight = Inventories[bagId].maxweight or 0
        slots = Inventories[bagId].slots or 0
    else
        local result = MySQL.Sync.fetchAll('SELECT items FROM inventories WHERE identifier = ?', { bagId })
        if result[1] and result[1].items then
            items = json.decode(result[1].items) or {}
        end
    end

    -- si no hay slots/weight en RAM, intentar deducir del item del jugador
    if slots == 0 or maxweight == 0 then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            for _, it in pairs(Player.PlayerData.items) do
                if it and it.info and it.info.bagid == bagId then
                    local shared = QBCore.Shared.Items[it.name:lower()]
                    if shared then
                        slots = shared.bagSlots or slots
                        maxweight = shared.bagMaxWeight or maxweight
                    end
                    break
                end
            end
        end
    end

    local preview = {}
    local used = 0
    local totalWeight = 0
    local sorted = {}
    for slot, item in pairs(items) do
        if item and item.name then
            local s = tonumber(item.slot) or tonumber(slot) or 0
            sorted[#sorted + 1] = { slot = s, item = item }
        end
    end
    table.sort(sorted, function(a, b) return a.slot < b.slot end)

    for _, entry in ipairs(sorted) do
        local item = entry.item
        used = used + 1
        local shared = QBCore.Shared.Items[item.name:lower()]
        local w = (shared and shared.weight or item.weight or 0) * (item.amount or 1)
        totalWeight = totalWeight + w
        preview[#preview + 1] = {
            name = item.name,
            label = (shared and shared.label) or item.label or item.name,
            image = (shared and shared.image) or item.image or (item.name .. '.png'),
            amount = item.amount or 1,
            slot = entry.slot > 0 and entry.slot or used
        }
    end

    if slots <= 0 then
        slots = math.max(used, 4)
    end

    cb({
        items = preview,
        used = used,
        slots = slots,
        weight = totalWeight,
        maxweight = maxweight
    })
end)
