-- ============================================================
--  DP-INVENTORY · server/functions.lua
--  Funciones del lado servidor: CRUD de inventario, pesos,
--  slots, tiendas, stashes y utilidades de ítems.
-- ============================================================
-- ============================================================
--  FUNCIONES INTERNAS COMPARTIDAS
-- ============================================================
local ExpanderBags = {
    ['backpack_1'] = {
        extraSlots = 5,
        extraWeight = 10000
    },
    ['backpack_2'] = {
        extraSlots = 10,
        extraWeight = 20000
    },
    ['backpack_3'] = {
        extraSlots = 15,
        extraWeight = 30000
    },
    ['backpack_4'] = {
        extraSlots = 20,
        extraWeight = 40000
    }
}

local function GetPlayerMaxCapacity(Player)
    local maxWeight = Config.MaxWeight
    local maxSlots = Config.MaxSlots

    if Player and Player.PlayerData and Player.PlayerData.items then
        local bagItem = Player.PlayerData.items[101]
        if bagItem and ExpanderBags[bagItem.name] then
            maxWeight = maxWeight + ExpanderBags[bagItem.name].extraWeight
            maxSlots = maxSlots + ExpanderBags[bagItem.name].extraSlots
        end
    end

    return maxWeight, maxSlots
end

-- ============================================================
--  FUNCIONES LOCALES
-- ============================================================
local function InitializeInventory(inventoryId, data)
    Inventories[inventoryId] = {
        items = {},
        isOpen = false,
        label = data and data.label or inventoryId,
        maxweight = data and data.maxweight or Config.StashSize.maxweight,
        slots = data and data.slots or Config.StashSize.slots
    }
    return Inventories[inventoryId]
end

local function GetFirstFreeSlot(items, maxSlots)
    for i = 1, maxSlots do
        if items[i] == nil then
            return i
        end
    end
    return nil
end

local function SetupShopItems(shopItems)
    local items = {}
    local slot = 1
    if shopItems and next(shopItems) then
        for _, item in pairs(shopItems) do
            local itemInfo = QBCore.Shared.Items[item.name:lower()]
            if itemInfo then
                items[slot] = {
                    name = itemInfo['name'],
                    amount = tonumber(item.amount) or 1,
                    info = item.info or {},
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'],
                    unique = itemInfo['unique'],
                    useable = itemInfo['useable'],
                    price = item.price,
                    image = itemInfo['image'],
                    slot = slot
                }
                slot = slot + 1
            end
        end
    end
    return items
end

-- ============================================================
--  CARGA / GUARDADO
-- ============================================================
function LoadInventory(source, citizenid)
    local inventory = MySQL.prepare.await('SELECT inventory FROM players WHERE citizenid = ?', {citizenid})
    local loadedInventory = {}
    local missingItems = {}

    if inventory then
        inventory = json.decode(inventory)
    end

    if not inventory or type(inventory) ~= 'table' or not next(inventory) then
        return loadedInventory
    end

    for _, item in pairs(inventory) do
        if item then
            local itemInfo = QBCore.Shared.Items[item.name:lower()]

            if itemInfo then
                loadedInventory[item.slot] = {
                    name = itemInfo['name'],
                    amount = tonumber(item.amount) or 1,
                    info = item.info or '',
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'],
                    unique = itemInfo['unique'],
                    useable = itemInfo['useable'],
                    image = itemInfo['image'],
                    shouldClose = itemInfo['shouldClose'],
                    slot = item.slot,
                    combinable = itemInfo['combinable']
                }
            else
                missingItems[#missingItems + 1] = item.name:lower()
            end
        end
    end

    if #missingItems > 0 then
        print(('The following items were removed for player %s as they no longer exist: %s'):format(source and
                                                                                                        GetPlayerName(
                source) or citizenid, table.concat(missingItems, ', ')))
    end

    return loadedInventory
end
exports('LoadInventory', LoadInventory)

function SaveInventory(source, offline)
    local PlayerData
    if offline then
        PlayerData = source
    else
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then
            return
        end
        PlayerData = Player.PlayerData
    end

    local items = PlayerData.items
    local ItemsJson = {}

    if items and type(items) == 'table' and next(items) then
        for slot, item in pairs(items) do
            if item then
                ItemsJson[#ItemsJson + 1] = {
                    name = item.name,
                    amount = item.amount,
                    info = item.info,
                    type = item.type,
                    slot = slot
                }
            end
        end
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?',
            {json.encode(ItemsJson), PlayerData.citizenid})
    else
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', {'[]', PlayerData.citizenid})
    end
end
exports('SaveInventory', SaveInventory)

function SetInventory(identifier, items, reason)
    local player = QBCore.Functions.GetPlayer(identifier)

    if not player and not Inventories[identifier] and not Drops[identifier] then
        return
    end

    if player then
        player.Functions.SetPlayerData('items', items)
        if not player.Offline then
            local logMessage = string.format('**%s (citizenid: %s | id: %s)** items set: %s', GetPlayerName(identifier),
                player.PlayerData.citizenid, identifier, json.encode(items))
            TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'SetInventory', 'blue', logMessage)
        end
    elseif Drops[identifier] then
        Drops[identifier].items = items
    elseif Inventories[identifier] then
        Inventories[identifier].items = items
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local setReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'DP-Inventory'
    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'Inventory Set', 'blue',
        '**Inventory:** ' .. invName .. '\n**Items:** ' .. json.encode(items) .. '\n**Reason:** ' .. setReason ..
            '\n**Resource:** ' .. resourceName)
end
exports('SetInventory', SetInventory)

-- ============================================================
--  METADATOS DE ÍTEMS
-- ============================================================
function SetItemData(source, itemName, key, val, slot)
    if not itemName or not key then
        return false
    end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return false
    end

    local item
    if slot then
        item = Player.PlayerData.items[tonumber(slot)]
        if not item or item.name:lower() ~= itemName:lower() then
            return false
        end
    else
        item = GetItemByName(source, itemName)
        if not item then
            return false
        end
    end

    item[key] = val
    Player.PlayerData.items[item.slot] = item
    Player.Functions.SetPlayerData('items', Player.PlayerData.items)
    return true
end
exports('SetItemData', SetItemData)

function UseItem(itemName, ...)
    local itemData = QBCore.Functions.CanUseItem(itemName)
    if type(itemData) == 'table' and itemData.func then
        itemData.func(...)
    end
end
exports('UseItem', UseItem)

-- ============================================================
--  BÚSQUEDA / CONSULTA
-- ============================================================
function GetSlotsByItem(items, itemName)
    local slotsFound = {}
    if not items then
        return slotsFound
    end
    itemName = itemName:lower()
    for slot, item in pairs(items) do
        if item.name:lower() == itemName then
            slotsFound[#slotsFound + 1] = tonumber(slot)
        end
    end
    return slotsFound
end
exports('GetSlotsByItem', GetSlotsByItem)

function GetFirstSlotByItem(items, itemName)
    if not items then
        return nil
    end
    itemName = itemName:lower()
    for slot, item in pairs(items) do
        if item.name:lower() == itemName then
            return tonumber(slot)
        end
    end
    return nil
end
exports('GetFirstSlotByItem', GetFirstSlotByItem)

function GetItemBySlot(source, slot)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return nil
    end
    return Player.PlayerData.items[tonumber(slot)]
end
exports('GetItemBySlot', GetItemBySlot)

function GetTotalWeight(items)
    if not items then
        return 0
    end
    local weight = 0
    for _, item in pairs(items) do
        local amount = tonumber(item.amount) or 1
        weight = weight + (item.weight * amount)
    end
    return tonumber(weight)
end
exports('GetTotalWeight', GetTotalWeight)

function GetItemByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return nil
    end
    local items = Player.PlayerData.items
    local slot = GetFirstSlotByItem(items, tostring(item):lower())
    if slot then
        return items[slot]
    end
    return nil
end
exports('GetItemByName', GetItemByName)

function GetItemsByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return {}
    end
    local PlayerItems = Player.PlayerData.items
    item = tostring(item):lower()
    local items = {}
    for _, slot in pairs(GetSlotsByItem(PlayerItems, item)) do
        if slot and PlayerItems[slot] then
            items[#items + 1] = PlayerItems[slot]
        end
    end
    return items
end
exports('GetItemsByName', GetItemsByName)

function GetSlots(identifier)
    local inventory, maxSlots
    local player = QBCore.Functions.GetPlayer(identifier)

    if player then
        inventory = player.PlayerData.items
        maxSlots = Config.MaxSlots
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
        maxSlots = Inventories[identifier].slots
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
        maxSlots = Drops[identifier].slots
    end

    if not inventory then
        return 0, maxSlots or Config.MaxSlots
    end

    local slotsUsed = 0
    for _, v in pairs(inventory) do
        if v then
            slotsUsed = slotsUsed + 1
        end
    end
    return slotsUsed, (maxSlots - slotsUsed)
end
exports('GetSlots', GetSlots)

function GetItemCount(source, items)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return 0
    end

    local isTable = type(items) == 'table'
    local itemsSet = {}
    if isTable then
        for _, item in ipairs(items) do
            itemsSet[item:lower()] = true
        end
    else
        items = tostring(items):lower()
    end

    local count = 0
    for _, item in pairs(Player.PlayerData.items) do
        if (isTable and itemsSet[item.name:lower()]) or (not isTable and items == item.name:lower()) then
            count = count + (tonumber(item.amount) or 1)
        end
    end
    return count
end
exports('GetItemCount', GetItemCount)

function GetFreeWeight(source)
    if not source then
        return 0
    end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return 0
    end
    local maxWeight = GetPlayerMaxCapacity(Player)
    return maxWeight - GetTotalWeight(Player.PlayerData.items)
end
exports('GetFreeWeight', GetFreeWeight)

-- ============================================================
--  VALIDACIÓN
-- ============================================================
function CanAddItem(identifier, item, amount)
    local Player = QBCore.Functions.GetPlayer(identifier)
    local itemData = QBCore.Shared.Items[item:lower()]
    if not itemData then
        return false
    end

    local inventory, items
    if Player then
        local maxWeight, maxSlots = GetPlayerMaxCapacity(Player)
        inventory = {
            maxweight = maxWeight,
            slots = maxSlots
        }
        items = Player.PlayerData.items
    elseif Inventories[identifier] then
        inventory = Inventories[identifier]
        items = Inventories[identifier].items
    end

    if not inventory then
        return false
    end

    local weight = itemData.weight * amount
    local totalWeight = GetTotalWeight(items) + weight
    if totalWeight > inventory.maxweight then
        return false, 'weight'
    end

    local slotsUsed, _ = GetSlots(identifier)

    if slotsUsed >= inventory.slots then
        if not itemData.unique then
            for _, v in pairs(items) do
                if v.name:lower() == itemData.name:lower() then
                    return true
                end
            end
        end
        return false, 'slots'
    end

    return true
end
exports('CanAddItem', CanAddItem)

function HasItem(source, items, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return false
    end

    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = isArray and #items or 0
    local count = 0

    if isTable and not isArray then
        for _ in pairs(items) do
            totalItems = totalItems + 1
        end
    end

    for _, itemData in pairs(Player.PlayerData.items) do
        if isTable then
            for k, v in pairs(items) do
                if itemData and itemData.name == (isArray and v or k) and
                    ((amount and itemData.amount >= amount) or (not isArray and itemData.amount >= v) or
                        (not amount and isArray)) then
                    count = count + 1
                    if count == totalItems then
                        return true
                    end
                end
            end
        else
            if itemData and itemData.name == items and
                (not amount or (itemData and amount and itemData.amount >= amount)) then
                return true
            end
        end
    end
    return false
end
exports('HasItem', HasItem)

-- ============================================================
--  GESTIÓN DE INVENTARIO
-- ============================================================
function ClearInventory(source, filterItems)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        return
    end

    local savedItemData = {}
    if filterItems then
        if type(filterItems) == 'string' then
            local item = GetItemByName(source, filterItems)
            if item then
                savedItemData[item.slot] = item
            end
        elseif type(filterItems) == 'table' then
            for _, itemName in ipairs(filterItems) do
                local item = GetItemByName(source, itemName)
                if item then
                    savedItemData[item.slot] = item
                end
            end
        end
    end

    player.Functions.SetPlayerData('items', savedItemData)
    if not player.Offline then
        local logMessage = string.format('**%s (citizenid: %s | id: %s)** inventory cleared', GetPlayerName(source),
            player.PlayerData.citizenid, source)
        TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'ClearInventory', 'red', logMessage)

        local ped = GetPlayerPed(source)
        local weapon = GetSelectedPedWeapon(ped)
        if weapon ~= joaat('WEAPON_UNARMED') then
            RemoveWeaponFromPed(ped, weapon)
        end
        if Player(source).state.inv_busy then
            TriggerClientEvent('DP-Inventory:client:updateInventory', source)
        end
    end
end
exports('ClearInventory', ClearInventory)

function CloseInventory(source, identifier)
    if identifier and Inventories[identifier] then
        Inventories[identifier].isOpen = false
    end
    Player(source).state.inv_busy = false
    TriggerClientEvent('DP-Inventory:client:closeInv', source)
end
exports('CloseInventory', CloseInventory)

function OpenInventoryById(source, targetId)
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not QBPlayer or not TargetPlayer then
        return
    end

    if GetResourceState("DP-RealMoney") ~= 'missing' then
        exports['DP-RealMoney']:UpdateItem(source, 'cash')
        exports['DP-RealMoney']:UpdateItem(source, 'black_money')
        exports['DP-RealMoney']:UpdateItem(source, 'crypto')

        exports['DP-RealMoney']:UpdateItem(targetId, 'cash')
        exports['DP-RealMoney']:UpdateItem(targetId, 'black_money')
        exports['DP-RealMoney']:UpdateItem(targetId, 'crypto')
    end

    if Player(targetId).state.inv_busy then
        CloseInventory(targetId)
    end

    local targetName = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname
    local targetMaxWeight, targetMaxSlots = GetPlayerMaxCapacity(TargetPlayer)

    local formattedInventory = {
        name = 'otherplayer-' .. targetId,
        label = targetName,
        maxweight = targetMaxWeight,
        slots = targetMaxSlots,
        inventory = TargetPlayer.PlayerData.items
    }

    Player(targetId).state.inv_busy = true
    TriggerClientEvent('DP-Inventory:client:openInventory', source, QBPlayer.PlayerData.items, formattedInventory)
end
exports('OpenInventoryById', OpenInventoryById)

function ClearStash(identifier)
    if not identifier or not Inventories[identifier] then
        return
    end
    Inventories[identifier].items = {}
    MySQL.prepare('UPDATE inventories SET items = ? WHERE identifier = ?', {'[]', identifier})
end
exports('ClearStash', ClearStash)

function CreateShop(shopData)
    if shopData.name then
        RegisteredShops[shopData.name] = {
            name = shopData.name,
            label = shopData.label,
            coords = shopData.coords,
            slots = #shopData.items,
            items = SetupShopItems(shopData.items)
        }
    else
        for key, data in pairs(shopData) do
            if type(data) == 'table' then
                local shopName = data.name or key
                RegisteredShops[shopName] = {
                    name = shopName,
                    label = data.label,
                    coords = data.coords,
                    slots = #data.items,
                    items = SetupShopItems(data.items)
                }
            end
        end
    end
end
exports('CreateShop', CreateShop)

function OpenShop(source, name)
    if not name then
        return
    end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not RegisteredShops[name] then
        return
    end

    if RegisteredShops[name].coords then
        local playerCoords = GetEntityCoords(GetPlayerPed(source))
        local shopCoords = vector3(RegisteredShops[name].coords.x, RegisteredShops[name].coords.y,
            RegisteredShops[name].coords.z)
        if #(playerCoords - shopCoords) > 5.0 then
            return
        end
    end

    local formattedInventory = {
        name = 'shop-' .. RegisteredShops[name].name,
        label = RegisteredShops[name].label,
        maxweight = 5000000,
        slots = #RegisteredShops[name].items,
        inventory = RegisteredShops[name].items
    }
    TriggerClientEvent('DP-Inventory:client:openInventory', source, Player.PlayerData.items, formattedInventory)
end
exports('OpenShop', OpenShop)

function OpenInventory(source, identifier, data)
    if Player(source).state.inv_busy then
        return
    end
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then
        return
    end

    if not identifier then
        Player(source).state.inv_busy = true
        TriggerClientEvent('DP-Inventory:client:openInventory', source, QBPlayer.PlayerData.items)
        return
    end

    if type(identifier) ~= 'string' then
        print('Inventory tried to open an invalid identifier')
        return
    end

    local inventory = Inventories[identifier]

    if inventory and inventory.isOpen then
        TriggerClientEvent('QBCore:Notify', source, 'Este inventario se encuentra actualmente en uso', 'error')
        return
    end

    if not inventory then
        inventory = InitializeInventory(identifier, data)
    end

    inventory.maxweight = (data and data.maxweight) or (inventory and inventory.maxweight) or Config.StashSize.maxweight
    inventory.slots = (data and data.slots) or (inventory and inventory.slots) or Config.StashSize.slots
    inventory.label = (data and data.label) or (inventory and inventory.label) or identifier
    inventory.isOpen = source

    local formattedInventory = {
        name = identifier,
        label = inventory.label,
        maxweight = inventory.maxweight,
        slots = inventory.slots,
        inventory = inventory.items
    }
    TriggerClientEvent('DP-Inventory:client:openInventory', source, QBPlayer.PlayerData.items, formattedInventory)
end
exports('OpenInventory', OpenInventory)

function CreateInventory(identifier, data)
    if Inventories[identifier] then
        return
    end
    if not identifier then
        return
    end
    Inventories[identifier] = InitializeInventory(identifier, data)
end
exports('CreateInventory', CreateInventory)

function GetInventory(identifier)
    return Inventories[identifier]
end
exports('GetInventory', GetInventory)

function RemoveInventory(identifier)
    if Inventories[identifier] then
        Inventories[identifier] = nil
    end
end
exports('RemoveInventory', RemoveInventory)

function AddItem(identifier, item, amount, slot, info, reason, isSilent)
    local itemInfo = QBCore.Shared.Items[item:lower()]
    if not itemInfo then
        print('AddItem: Invalid item')
        return false
    end
    local inventory, inventoryWeight, inventorySlots
    local player = QBCore.Functions.GetPlayer(identifier)

    if player then
        inventory = player.PlayerData.items
        inventoryWeight, inventorySlots = GetPlayerMaxCapacity(player)
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
        inventoryWeight = Inventories[identifier].maxweight
        inventorySlots = Inventories[identifier].slots
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
        inventoryWeight = Drops[identifier].maxweight
        inventorySlots = Drops[identifier].slots
    end

    if not inventory then
        print('AddItem: Inventory not found')
        return false
    end

    local totalWeight = GetTotalWeight(inventory)
    if totalWeight + (itemInfo.weight * amount) > inventoryWeight then
        print('AddItem: Not enough weight available')
        return false
    end

    amount = tonumber(amount) or 1
    local updated = false

    if not itemInfo.unique then
        slot = slot or GetFirstSlotByItem(inventory, item)
        if slot then
            for _, invItem in pairs(inventory) do
                if invItem.slot == slot then
                    invItem.amount = invItem.amount + amount
                    updated = true
                    break
                end
            end
        end
    end

    if not updated then
        slot = slot or GetFirstFreeSlot(inventory, inventorySlots)
        if not slot then
            print('AddItem: No free slot available')
            return false
        end

        inventory[slot] = {
            name = item,
            amount = amount,
            info = info or {},
            label = itemInfo.label,
            description = itemInfo.description or '',
            weight = itemInfo.weight,
            type = itemInfo.type,
            unique = itemInfo.unique,
            useable = itemInfo.useable,
            image = itemInfo.image,
            shouldClose = itemInfo.shouldClose,
            slot = slot,
            combinable = itemInfo.combinable
        }

        if itemInfo.type == 'weapon' then
            if not inventory[slot].info.serie then
                inventory[slot].info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) ..
                                                          QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) ..
                                                          QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
            end
            if not inventory[slot].info.quality then
                inventory[slot].info.quality = 100
            end
        end
    end

    if player then
        player.Functions.SetPlayerData('items', inventory)
    end
    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local addReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'DP-Inventory'
    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'Item Added', 'green',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. slot .. ')\n' .. '**Item:** ' .. item .. '\n' .. '**Amount:** ' ..
            amount .. '\n' .. '**Reason:** ' .. addReason .. '\n' .. '**Resource:** ' .. resourceName)

    if player and not player.Offline and not isSilent then
        TriggerClientEvent('DP-Inventory:client:ItemBox', identifier, itemInfo, 'add', amount)
    end

    return true
end
exports('AddItem', AddItem)

function RemoveItem(identifier, item, amount, slot, reason, isSilent)
    if not QBCore.Shared.Items[item:lower()] then
        print('RemoveItem: Invalid item')
        return false
    end

    local inventory
    local player = QBCore.Functions.GetPlayer(identifier)

    if player then
        inventory = player.PlayerData.items
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
    end

    if not inventory then
        print('RemoveItem: Inventory not found')
        return false
    end

    slot = tonumber(slot) or GetFirstSlotByItem(inventory, item)

    if not slot then
        print('RemoveItem: Slot not found')
        return false
    end

    local inventoryItem = nil
    local itemKey = nil

    for key, invItem in pairs(inventory) do
        if invItem.slot == slot then
            inventoryItem = invItem
            itemKey = key
            break
        end
    end

    if not inventoryItem or inventoryItem.name:lower() ~= item:lower() then
        print('RemoveItem: Item not found in slot')
        return false
    end

    amount = tonumber(amount)
    if inventoryItem.amount < amount then
        print('RemoveItem: Not enough items in slot')
        return false
    end

    inventoryItem.amount = inventoryItem.amount - amount
    if inventoryItem.amount <= 0 then
        inventory[itemKey] = nil
    else
        inventory[itemKey] = inventoryItem
    end

    if player then
        player.Functions.SetPlayerData('items', inventory)

        local itemInfo = QBCore.Shared.Items[item:lower()]
        if itemInfo and itemInfo.type == 'weapon' and inventoryItem.amount <= 0 then
            checkWeapon(identifier, item)
        end
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local removeReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'DP-Inventory'

    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'Item Removed', 'red',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. slot .. ')\n' .. '**Item:** ' .. item .. '\n' .. '**Amount:** ' ..
            amount .. '\n' .. '**Reason:** ' .. removeReason .. '\n' .. '**Resource:** ' .. resourceName)

    if player and not player.Offline and not isSilent then
        TriggerClientEvent('DP-Inventory:client:ItemBox', identifier, QBCore.Shared.Items[item:lower()], 'remove',
            amount)
    end

    return true
end
exports('RemoveItem', RemoveItem)
