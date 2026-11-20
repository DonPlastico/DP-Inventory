QBCore = exports['qb-core']:GetCoreObject()

Inventories = {}
Drops = {}
RegisteredShops = {}

local function EnsureDatabaseSchema()
    if Config.Database and Config.Database.autoCreateTables == false then
        return
    end

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `inventories` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `identifier` varchar(255) NOT NULL,
          `items` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`items`)),
          PRIMARY KEY (`identifier`),
          KEY `id` (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `dp_preferences` (
          `citizenid` varchar(50) NOT NULL,
          `menu_top` varchar(20) DEFAULT '14.537%',
          `menu_left` varchar(20) DEFAULT '62.5%',
          `menu_scale` INT DEFAULT 90,
          `inventory_position` varchar(20) DEFAULT 'bottom',
          `move_while_open` INT DEFAULT 0,
          `ui_sounds` INT DEFAULT 1,
          `boombox_move_open` INT DEFAULT 0,
          `boombox_top` varchar(20) DEFAULT NULL,
          `boombox_left` varchar(20) DEFAULT NULL,
          PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]])

    -- columnas por si la tabla existía de versiones viejas / boombox
    local cols = {{'ui_sounds', "INT DEFAULT 1"}, {'boombox_move_open', "INT DEFAULT 0"},
                  {'boombox_top', "varchar(20) DEFAULT NULL"}, {'boombox_left', "varchar(20) DEFAULT NULL"},
                  {'inventory_position', "varchar(20) DEFAULT 'bottom'"}, {'move_while_open', "INT DEFAULT 0"},
                  {'menu_top', "varchar(20) DEFAULT '14.537%'"}, {'menu_left', "varchar(20) DEFAULT '62.5%'"},
                  {'menu_scale', "INT DEFAULT 90"}}
    for _, col in ipairs(cols) do
        pcall(function()
            MySQL.query.await(('ALTER TABLE `dp_preferences` ADD COLUMN IF NOT EXISTS `%s` %s'):format(col[1], col[2]))
        end)
    end

    print('^2[DP-Inventory]^7 Schema verificado (inventories + dp_preferences).')
end

local function RunLegacyMigration()
    local inserted = 0

    local function tableExists(name)
        local row = MySQL.single.await(
            'SELECT COUNT(*) AS c FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?',
            {name})
        return row and tonumber(row.c) > 0
    end

    if tableExists('gloveboxitems') then
        local n = MySQL.update.await([[
            INSERT IGNORE INTO inventories (identifier, items)
            SELECT CONCAT('glovebox-', plate), items FROM gloveboxitems
        ]]) or 0
        inserted = inserted + n
    end

    if tableExists('stashitems') then
        local n = MySQL.update.await([[
            INSERT IGNORE INTO inventories (identifier, items)
            SELECT stash, items FROM stashitems
        ]]) or 0
        inserted = inserted + n
    end

    if tableExists('trunkitems') then
        local n = MySQL.update.await([[
            INSERT IGNORE INTO inventories (identifier, items)
            SELECT CONCAT('trunk-', plate), items FROM trunkitems
        ]]) or 0
        inserted = inserted + n
    end

    -- recargar cache RAM
    local result = MySQL.query.await('SELECT * FROM inventories') or {}
    for i = 1, #result do
        local inv = result[i]
        if not Inventories[inv.identifier] then
            Inventories[inv.identifier] = {
                items = json.decode(inv.items) or {},
                isOpen = false
            }
        end
    end

    return inserted
end

local function DropLegacyTables()
    MySQL.query.await('DROP TABLE IF EXISTS `gloveboxitems`')
    MySQL.query.await('DROP TABLE IF EXISTS `stashitems`')
    MySQL.query.await('DROP TABLE IF EXISTS `trunkitems`')
end

CreateThread(function()
    EnsureDatabaseSchema()

    MySQL.query('SELECT * FROM inventories', {}, function(result)
        if result and #result > 0 then
            for i = 1, #result do
                local inventory = result[i]
                local cacheKey = inventory.identifier
                Inventories[cacheKey] = {
                    items = json.decode(inventory.items) or {},
                    isOpen = false
                }
            end
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(Config.CleanupDropInterval * 60000)
        local currentTime = os.time()
        for k, v in pairs(Drops) do
            if v and (v.createdTime + (Config.CleanupDropTime * 60) < currentTime) and not Drops[k].isOpen then
                local entity = NetworkGetEntityFromNetworkId(v.entityId)
                if DoesEntityExist(entity) then
                    DeleteEntity(entity)
                end
                Drops[k] = nil
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source

    for _, inv in pairs(Inventories) do
        if inv.isOpen == src then
            inv.isOpen = false
        end
    end

    for _, drop in pairs(Drops) do
        if drop.isOpen == src then
            drop.isOpen = false
        end
        if drop.isHeld == src then
            drop.isHeld = false
        end
    end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    for inventory, data in pairs(Inventories) do
        MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?',
            {inventory, json.encode(data.items), json.encode(data.items)})
    end
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    QBCore.Functions.AddPlayerMethod(src, 'AddItem', function(item, amount, slot, info, reason)
        return AddItem(src, item, amount, slot, info, reason)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'RemoveItem', function(item, amount, slot, reason)
        return RemoveItem(src, item, amount, slot, reason)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'GetItemBySlot', function(slot)
        return GetItemBySlot(src, slot)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'GetItemByName', function(item)
        return GetItemByName(src, item)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'GetItemsByName', function(item)
        return GetItemsByName(src, item)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'ClearInventory', function(filterItems)
        ClearInventory(src, filterItems)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'SetInventory', function(items)
        SetInventory(src, items)
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    local Players = QBCore.Functions.GetQBPlayers()
    for k in pairs(Players) do
        QBCore.Functions.AddPlayerMethod(k, 'AddItem', function(item, amount, slot, info)
            return AddItem(k, item, amount, slot, info)
        end)
        QBCore.Functions.AddPlayerMethod(k, 'RemoveItem', function(item, amount, slot)
            return RemoveItem(k, item, amount, slot)
        end)
        QBCore.Functions.AddPlayerMethod(k, 'GetItemBySlot', function(slot)
            return GetItemBySlot(k, slot)
        end)
        QBCore.Functions.AddPlayerMethod(k, 'GetItemByName', function(item)
            return GetItemByName(k, item)
        end)
        QBCore.Functions.AddPlayerMethod(k, 'GetItemsByName', function(item)
            return GetItemsByName(k, item)
        end)
        QBCore.Functions.AddPlayerMethod(k, 'ClearInventory', function(filterItems)
            ClearInventory(k, filterItems)
        end)
        QBCore.Functions.AddPlayerMethod(k, 'SetInventory', function(items)
            SetInventory(k, items)
        end)
        Player(k).state.inv_busy = false
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    for k, v in pairs(Drops) do
        if v and v.entityId then
            local entity = NetworkGetEntityFromNetworkId(v.entityId)
            if DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        end
        Drops[k] = nil
    end
end)

function checkWeapon(source, item)
    local currentWeapon = type(item) == 'table' and item.name or item
    local ped = GetPlayerPed(source)
    local weapon = GetSelectedPedWeapon(ped)
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    if weaponInfo and weaponInfo.name == currentWeapon then
        RemoveWeaponFromPed(ped, weapon)
        TriggerClientEvent('DP-Inventory:client:UseWeapon', source, {
            name = currentWeapon
        }, false)
    end
end

RegisterNetEvent('DP-Inventory:server:openVending', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    if not RegisteredShops['vending'] then
        CreateShop({
            name = 'vending',
            label = 'Máquina Expendedora',
            coords = data.coords,
            slots = #Config.VendingItems,
            items = Config.VendingItems
        })
    else
        RegisteredShops['vending'].coords = data.coords
    end
    OpenShop(src, 'vending')
end)

RegisterNetEvent('DP-Inventory:server:OpenInventory', function(type, targetId)
    local src = source
    if type == "otherplayer" then
        OpenInventoryById(src, targetId)
    end
end)

RegisterNetEvent('DP-Inventory:server:closeInventory', function(inventory)
    local src = source
    local QBPlayer = QBCore.Functions.GetPlayer(src)
    if not QBPlayer then
        return
    end

    Player(src).state.inv_busy = false

    for invId, invData in pairs(Inventories) do
        if invData.isOpen == src and invId ~= inventory then
            invData.isOpen = false
            MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?',
                {invId, json.encode(invData.items), json.encode(invData.items)})
        end
    end
    for dropId, dropData in pairs(Drops) do
        if dropData.isOpen == src and dropId ~= inventory then
            dropData.isOpen = false
        end
    end

    if inventory:find('shop%-') then
        return
    end

    if inventory:find('otherplayer%-') then
        local targetId = tonumber(inventory:match('otherplayer%-(.+)'))
        if targetId then
            Player(targetId).state.inv_busy = false
        end
        return
    end

    if Drops[inventory] then
        if Drops[inventory].isOpen == src then
            Drops[inventory].isOpen = false
        end

        if not Drops[inventory].isOpen then
            local hasItems = false
            for _, _ in pairs(Drops[inventory].items) do
                hasItems = true
                break
            end

            if not hasItems then
                TriggerClientEvent('DP-Inventory:client:removeDropTarget', -1, Drops[inventory].entityId)
                Wait(500)
                local entity = NetworkGetEntityFromNetworkId(Drops[inventory].entityId)
                if DoesEntityExist(entity) then
                    DeleteEntity(entity)
                end
                Drops[inventory] = nil
            end
        end
        return
    end

    if not Inventories[inventory] then
        return
    end

    Inventories[inventory].isOpen = false
    MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?',
        {inventory, json.encode(Inventories[inventory].items), json.encode(Inventories[inventory].items)})

    if type(inventory) == "string" and string.find(inventory, "^bag_") then
        TriggerEvent('DP-Inventory:server:UpdateBagWeight', src, inventory)
    end
end)

RegisterNetEvent('DP-Inventory:server:useItem', function(item)
    local src = source
    local itemData = GetItemBySlot(src, item.slot)
    if not itemData then
        return
    end

    local itemInfo = QBCore.Shared.Items[itemData.name]

    if itemData.type == 'weapon' then
        if itemData.name == 'weapon_switchblade' then
            TriggerClientEvent('DP-Inventory:client:ToggleSwitchblade', src, itemData)
            TriggerClientEvent('DP-Inventory:client:WeaponItemBox', src, itemInfo)
        else
            TriggerClientEvent('DP-Inventory:client:UseWeapon', src, itemData,
                itemData.info.quality and itemData.info.quality > 0)
            TriggerClientEvent('DP-Inventory:client:WeaponItemBox', src, itemInfo)
        end

    elseif itemData.name == 'id_card' then
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('DP-Inventory:client:ItemBox', source, itemInfo, 'use')
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        local gender = item.info.gender == 0 and 'Hombre' or 'Mujer'
        for _, v in pairs(QBCore.Functions.GetPlayers()) do
            if #(playerCoords - GetEntityCoords(GetPlayerPed(v))) < 3.0 then
                TriggerClientEvent('chat:addMessage', v, {
                    template = '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #74807c); display: flex;"><div style="margin-right: 10px;"><i class="far fa-id-card" style="height: 100%;"></i><strong> {0}</strong><br> <strong>DNI:</strong> {1} <br><strong>Nombre:</strong> {2} <br><strong>Apellido:</strong> {3} <br><strong>Nacimiento:</strong> {4} <br><strong>Sexo:</strong> {5} <br><strong>Nacionalidad:</strong> {6}</div></div>',
                    args = {'Tarjeta ID', item.info.citizenid, item.info.firstname, item.info.lastname,
                            item.info.birthdate, gender, item.info.nationality}
                })
            end
        end

    elseif itemData.name == 'driver_license' then
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('DP-Inventory:client:ItemBox', src, itemInfo, 'use')
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        for _, v in pairs(QBCore.Functions.GetPlayers()) do
            if #(playerCoords - GetEntityCoords(GetPlayerPed(v))) < 3.0 then
                TriggerClientEvent('chat:addMessage', v, {
                    template = '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #657175); display: flex;"><div style="margin-right: 10px;"><i class="far fa-id-card" style="height: 100%;"></i><strong> {0}</strong><br> <strong>Nombre:</strong> {1} <br><strong>Apellido:</strong> {2} <br><strong>Nacimiento:</strong> {3} <br><strong>Licencias:</strong> {4}</div></div>',
                    args = {'Licencia Conducir', item.info.firstname, item.info.lastname, item.info.birthdate,
                            item.info.type}
                })
            end
        end

    else
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('DP-Inventory:client:ItemBox', src, itemInfo, 'use')
    end
end)

RegisterNetEvent('DP-Inventory:server:updateDrop', function(dropId, coords)
    local src = source
    if Drops[dropId] then
        Drops[dropId].coords = coords
        if Drops[dropId].isHeld == src then
            Drops[dropId].isHeld = false
        end
    end
end)

RegisterNetEvent('DP-Inventory:server:ForceOpenStash', function(identifier)
    local src = source
    if not (QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')) then
        return
    end
    OpenInventory(src, identifier)
end)

QBCore.Functions.CreateCallback('DP-Inventory:server:GetCurrentDrops', function(_, cb)
    cb(Drops)
end)

QBCore.Functions.CreateCallback('DP-Inventory:server:requestHoldDrop', function(source, cb, dropId)
    if Drops[dropId] then
        if not Drops[dropId].isOpen and not Drops[dropId].isHeld then
            Drops[dropId].isHeld = source
            cb(true)
        else
            cb(false, "in_use")
        end
    else
        cb(false, "not_found")
    end
end)

QBCore.Functions.CreateCallback('DP-Inventory:server:createDrop', function(source, cb, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return cb(false)
    end

    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)

    if RemoveItem(src, item.name, item.amount, item.fromSlot, 'dropped item') then

        if GetResourceState("DP-RealMoney") ~= 'missing' then
            exports['DP-RealMoney']:UpdateCash(src, item.name, item.amount, 'remove')
        end

        if item.type == 'weapon' then
            checkWeapon(src, item)
        end

        TaskPlayAnim(playerPed, 'pickup_object', 'pickup_low', 8.0, -8.0, 2000, 0, 0, false, false, false)

        local bag = CreateObjectNoOffset(Config.ItemDropObject, playerCoords.x + 0.5, playerCoords.y + 0.5,
            playerCoords.z, true, true, false)
        local dropId = NetworkGetNetworkIdFromEntity(bag)
        local newDropId = 'drop-' .. dropId

        item.slot = 1
        local initialItem = {
            [1] = item
        }

        if not Drops[newDropId] then
            Drops[newDropId] = {
                name = newDropId,
                label = 'Mochila Suelo',
                items = initialItem,
                entityId = dropId,
                createdTime = os.time(),
                coords = playerCoords,
                maxweight = Config.DropSize.maxweight,
                slots = Config.DropSize.slots,
                isOpen = false,
                isHeld = false
            }
            TriggerClientEvent('DP-Inventory:client:setupDropTarget', -1, dropId)
        else
            local foundSlot = false
            for i = 1, Config.DropSize.slots do
                if not Drops[newDropId].items[i] then
                    item.slot = i
                    Drops[newDropId].items[i] = item
                    foundSlot = true
                    break
                end
            end
            if not foundSlot then
                return cb(false)
            end
        end
        cb(dropId)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('DP-Inventory:server:attemptPurchase', function(source, cb, data)
    local src = source
    local itemInfo = data.item
    local amount = math.floor(tonumber(data.amount) or 0)
    local shop = string.gsub(data.shop, 'shop%-', '')
    local Player = QBCore.Functions.GetPlayer(src)

    if amount <= 0 or not Player or not RegisteredShops[shop] then
        return cb(false)
    end

    local shopInfo = RegisteredShops[shop]

    if shopInfo.coords and
        #(GetEntityCoords(GetPlayerPed(src)) - vector3(shopInfo.coords.x, shopInfo.coords.y, shopInfo.coords.z)) > 10 then
        return cb(false)
    end

    if shopInfo.items[itemInfo.slot].name ~= itemInfo.name then
        return cb(false)
    end

    if amount > shopInfo.items[itemInfo.slot].amount or shopInfo.items[itemInfo.slot].amount <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'No hay suficiente stock', 'error')
        return cb(false)
    end

    if not CanAddItem(src, itemInfo.name, amount) then
        TriggerClientEvent('QBCore:Notify', src, 'No tienes espacio suficiente', 'error')
        return cb(false)
    end

    local price = shopInfo.items[itemInfo.slot].price * amount
    if Player.PlayerData.money.cash >= price then
        Player.Functions.RemoveMoney('cash', price, 'shop-purchase')
        AddItem(src, itemInfo.name, amount, nil, itemInfo.info, 'shop-purchase')
        shopInfo.items[itemInfo.slot].amount = shopInfo.items[itemInfo.slot].amount - amount
        TriggerEvent('qb-shops:server:UpdateShopItems', shop, itemInfo, amount)
        cb(true)
    else
        TriggerClientEvent('QBCore:Notify', src, 'No tienes suficiente dinero', 'error')
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('DP-Inventory:server:giveItem', function(source, cb, target, item, amount, slot, info)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(target)

    if not player or player.PlayerData.metadata['isdead'] or player.PlayerData.metadata['inlaststand'] or
        player.PlayerData.metadata['ishandcuffed'] then
        return cb(false)
    end

    if not Target or Target.PlayerData.metadata['isdead'] or Target.PlayerData.metadata['inlaststand'] or
        Target.PlayerData.metadata['ishandcuffed'] then
        return cb(false)
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) > 5 then
        return cb(false)
    end

    if item == 'sim_card' then
        if not info then
            info = {}
        end
        if not info.sim_number then
            local newNumber
            local exists = true
            while exists do
                newNumber = string.format("%03d-%04d-%03d", math.random(100, 999), math.random(1000, 9999),
                    math.random(100, 999))
                local found = MySQL.scalar.await('SELECT 1 FROM dp_phone_sim WHERE sim_number = ?', {newNumber})
                if not found then
                    exists = false
                end
            end
            MySQL.insert.await('INSERT IGNORE INTO dp_phone_sim (sim_number, activated) VALUES (?, 0)', {newNumber})
            info.sim_number = newNumber
            print("^2[DP-Inventory]^7 SIM activada automáticamente: " .. newNumber)
        end
    end

    local itemInfo = QBCore.Shared.Items[item:lower()]
    if not itemInfo or not HasItem(src, item) then
        return cb(false)
    end

    local itemData = GetItemByName(src, item)
    if not itemData or itemData.amount <= 0 then
        return cb(false)
    end

    local giveAmount = math.floor(tonumber(amount) or 0)
    if giveAmount <= 0 or giveAmount > itemData.amount then
        return cb(false)
    end

    if not RemoveItem(src, item, giveAmount, slot, 'Given to ID ' .. target) then
        return cb(false)
    end
    if not AddItem(target, item, giveAmount, false, info, 'Received from ID ' .. src) then
        return cb(false)
    end

    if itemInfo.type == 'weapon' then
        checkWeapon(src, item)
    end

    if GetResourceState("DP-RealMoney") ~= 'missing' then
        exports['DP-RealMoney']:UpdateCash(src, item, giveAmount, 'remove')
        exports['DP-RealMoney']:UpdateCash(target, item, giveAmount, 'add')
    end

    TriggerClientEvent('DP-Inventory:client:giveAnim', src)
    TriggerClientEvent('DP-Inventory:client:ItemBox', src, itemInfo, 'remove', giveAmount)
    TriggerClientEvent('DP-Inventory:client:giveAnim', target)
    TriggerClientEvent('DP-Inventory:client:ItemBox', target, itemInfo, 'add', giveAmount)
    if Player(target).state.inv_busy then
        TriggerClientEvent('DP-Inventory:client:updateInventory', target)
    end

    cb(true)
end)

QBCore.Functions.CreateCallback('DP-Inventory:server:requestOpenDrop', function(source, cb, dropId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player or not Drops[dropId] or Drops[dropId].isOpen or Drops[dropId].isHeld then
        cb(false)
        return
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - Drops[dropId].coords) > 2.5 then
        cb(false)
        return
    end

    Drops[dropId].isOpen = src

    local formattedInventory = {
        name = dropId,
        label = 'Mochila Suelo',
        maxweight = Drops[dropId].maxweight,
        slots = Drops[dropId].slots,
        inventory = Drops[dropId].items
    }

    TriggerClientEvent('DP-Inventory:client:openInventory', src, Player.PlayerData.items, formattedInventory)
    cb(true)
end)

QBCore.Functions.CreateCallback('DP-Inventory:server:GetPlayerNames', function(source, cb, serverIds)
    local playersData = {}

    for _, id in ipairs(serverIds) do
        local TargetPlayer = QBCore.Functions.GetPlayer(id)

        if TargetPlayer then
            local charName = TargetPlayer.PlayerData.charinfo.firstname .. " " ..
                                 TargetPlayer.PlayerData.charinfo.lastname
            local steamName = GetPlayerName(id)

            table.insert(playersData, {
                id = id,
                name = charName,
                steam = steamName
            })
        end
    end

    cb(playersData)
end)

local function getItem(inventoryId, src, slot)
    local items = {}
    if inventoryId == 'player' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.items then
            items = Player.PlayerData.items
        end
    elseif inventoryId:find('otherplayer-') then
        local targetId = tonumber(inventoryId:match('otherplayer%-(.+)'))
        local targetPlayer = QBCore.Functions.GetPlayer(targetId)
        if targetPlayer and targetPlayer.PlayerData.items then
            items = targetPlayer.PlayerData.items
        end
    elseif inventoryId:find('drop-') == 1 then
        if Drops[inventoryId] and Drops[inventoryId]['items'] then
            items = Drops[inventoryId]['items']
        end
    else
        if Inventories[inventoryId] and Inventories[inventoryId]['items'] then
            items = Inventories[inventoryId]['items']
        end
    end

    for _, item in pairs(items) do
        if item.slot == slot then
            return item
        end
    end
    return nil
end

local function getIdentifier(inventoryId, src)
    if inventoryId == 'player' then
        return src
    elseif inventoryId:find('otherplayer-') then
        return tonumber(inventoryId:match('otherplayer%-(.+)'))
    else
        return inventoryId
    end
end

RegisterNetEvent('DP-Inventory:server:SetInventoryData',
    function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
        local src = source

        if toInventory:find('shop%-') then
            return
        end

        if not fromInventory or not toInventory or not fromSlot or not toSlot or not fromAmount or not toAmount then
            return
        end

        fromSlot = math.floor(tonumber(fromSlot) or 0)
        toSlot = math.floor(tonumber(toSlot) or 0)
        fromAmount = math.floor(tonumber(fromAmount) or 0)
        toAmount = math.floor(tonumber(toAmount) or 0)

        if fromAmount < 0 or toAmount < 0 then
            return
        end
        if fromInventory == toInventory and fromSlot == toSlot then
            return
        end

        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then
            return
        end

        local fromItem = getItem(fromInventory, src, fromSlot)
        local toItem = getItem(toInventory, src, toSlot)

        if fromItem then
            if not toItem and toAmount > fromItem.amount then
                return
            end

            if fromInventory == 'player' and toInventory ~= 'player' then
                checkWeapon(src, fromItem)
            end

            local fromId = getIdentifier(fromInventory, src)
            local toId = getIdentifier(toInventory, src)

            if toItem and fromItem.name == toItem.name then
                if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'stacked item', true) then
                    AddItem(toId, toItem.name, toAmount, toSlot, toItem.info, 'stacked item', true)
                    if GetResourceState("DP-RealMoney") ~= 'missing' then
                        exports['DP-RealMoney']:UpdateCash(fromId, fromItem.name, toAmount, 'remove')
                        exports['DP-RealMoney']:UpdateCash(toId, toItem.name, toAmount, 'add')
                    end
                end

            elseif not toItem and toAmount < fromAmount then
                if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'split item', true) then
                    AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'split item', true)
                    if GetResourceState("DP-RealMoney") ~= 'missing' then
                        exports['DP-RealMoney']:UpdateCash(fromId, fromItem.name, toAmount, 'remove')
                        exports['DP-RealMoney']:UpdateCash(toId, fromItem.name, toAmount, 'add')
                    end
                end

            else
                if toItem then
                    local fromItemAmount = fromItem.amount
                    local toItemAmount = toItem.amount

                    if RemoveItem(fromId, fromItem.name, fromItemAmount, fromSlot, 'swapped item', true) and
                        RemoveItem(toId, toItem.name, toItemAmount, toSlot, 'swapped item', true) then
                        AddItem(toId, fromItem.name, fromItemAmount, toSlot, fromItem.info, 'swapped item', true)
                        AddItem(fromId, toItem.name, toItemAmount, fromSlot, toItem.info, 'swapped item', true)
                        if GetResourceState("DP-RealMoney") ~= 'missing' then
                            exports['DP-RealMoney']:UpdateCash(fromId, fromItem.name, fromItemAmount, 'remove')
                            exports['DP-RealMoney']:UpdateCash(toId, toItem.name, toItemAmount, 'remove')
                            exports['DP-RealMoney']:UpdateCash(toId, fromItem.name, fromItemAmount, 'add')
                            exports['DP-RealMoney']:UpdateCash(fromId, toItem.name, toItemAmount, 'add')
                        end
                    end

                else
                    if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'moved item', true) then
                        AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'moved item', true)
                        if GetResourceState("DP-RealMoney") ~= 'missing' then
                            exports['DP-RealMoney']:UpdateCash(fromId, fromItem.name, toAmount, 'remove')
                            exports['DP-RealMoney']:UpdateCash(toId, fromItem.name, toAmount, 'add')
                        end
                    end
                end
            end
        end

        if (fromInventory == 'player' and fromSlot == 101) or (toInventory == 'player' and toSlot == 101) then
            Wait(100)
            CheckBackpackUnequip(src)
        end
    end)

QBCore.Functions.CreateCallback('DP-Inventory:server:IsAdmin', function(source, cb)
    cb(QBCore.Functions.HasPermission(source, 'admin') or QBCore.Functions.HasPermission(source, 'god'))
end)

QBCore.Functions.CreateCallback('DP-Inventory:server:GetAdminMasterData', function(source, cb)
    if not (QBCore.Functions.HasPermission(source, 'admin') or QBCore.Functions.HasPermission(source, 'god')) then
        return cb(false)
    end

    local players = {}
    for _, v in pairs(QBCore.Functions.GetPlayers()) do
        local target = QBCore.Functions.GetPlayer(v)
        if target then
            players[#players + 1] = {
                id = v,
                name = target.PlayerData.charinfo.firstname .. ' ' .. target.PlayerData.charinfo.lastname,
                steam = GetPlayerName(v)
            }
        end
    end

    MySQL.query('SELECT identifier FROM inventories', {}, function(result)
        local trunks, gloveboxes, stashes = {}, {}, {}
        if result then
            for i = 1, #result do
                local id = result[i].identifier
                if string.find(id, "^trunk%-") then
                    trunks[#trunks + 1] = id
                elseif string.find(id, "^glovebox%-") then
                    gloveboxes[#gloveboxes + 1] = id
                else
                    stashes[#stashes + 1] = id
                end
            end
        end
        cb({
            players = players,
            trunks = trunks,
            gloveboxes = gloveboxes,
            stashes = stashes
        })
    end)
end)

QBCore.Functions.CreateCallback('DP-Inventory:server:GetPosition', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb('bottom')
    end

    local result = MySQL.Sync.fetchAll('SELECT inventory_position FROM dp_preferences WHERE citizenid = ?',
        {Player.PlayerData.citizenid})
    if result[1] and result[1].inventory_position then
        cb(result[1].inventory_position)
    else
        cb('bottom')
    end
end)

RegisterNetEvent('DP-Inventory:server:SavePosition', function(pos)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    MySQL.Async.execute(
        'INSERT INTO dp_preferences (citizenid, inventory_position) VALUES (?, ?) ON DUPLICATE KEY UPDATE inventory_position = ?',
        {Player.PlayerData.citizenid, pos, pos})
end)

QBCore.Functions.CreateCallback('DP-Inventory:server:GetMovePref', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb(false)
    end

    local result = MySQL.Sync.fetchAll('SELECT move_while_open FROM dp_preferences WHERE citizenid = ?',
        {Player.PlayerData.citizenid})
    if result[1] and result[1].move_while_open ~= nil then
        cb(result[1].move_while_open == 1)
    else
        cb(false)
    end
end)

RegisterNetEvent('DP-Inventory:server:SaveMovePref', function(status)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local val = status and 1 or 0
    MySQL.Async.execute('UPDATE dp_preferences SET move_while_open = ? WHERE citizenid = ?',
        {val, Player.PlayerData.citizenid})
end)

QBCore.Functions.CreateCallback('DP-Inventory:server:GetSoundPref', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb(true)
    end

    MySQL.Async.fetchAll('SELECT ui_sounds FROM dp_preferences WHERE citizenid = ?', {Player.PlayerData.citizenid},
        function(result)
            if result[1] ~= nil then
                cb(result[1].ui_sounds == 1)
            else
                MySQL.Async.execute(
                    'INSERT INTO dp_preferences (citizenid, ui_sounds) VALUES (?, 1) ON DUPLICATE KEY UPDATE ui_sounds=1',
                    {Player.PlayerData.citizenid})
                cb(true)
            end
        end)
end)

RegisterNetEvent('DP-Inventory:server:SaveSoundPref', function(status)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return
    end

    local val = status and 1 or 0
    MySQL.Async.execute(
        'INSERT INTO dp_preferences (citizenid, ui_sounds) VALUES (?, ?) ON DUPLICATE KEY UPDATE ui_sounds=?',
        {Player.PlayerData.citizenid, val, val})
end)

local function isInvAdmin(src)
    return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
end

local migrateCmd = (Config.Database and Config.Database.migrateCommand) or 'dpinv_migrate'
local dropLegacyCmd = (Config.Database and Config.Database.dropLegacyCommand) or 'dpinv_drop_legacy'

QBCore.Commands.Add(migrateCmd, 'Migrar qb/lj inventory → DP-Inventory (glovebox/stash/trunk)', {}, false,
    function(source)
        if source ~= 0 and not isInvAdmin(source) then
            return
        end
        local n = RunLegacyMigration()
        local msg = ('[DP-Inventory] Migración finalizada. Filas insertadas/ignoradas: %s'):format(tostring(n))
        print('^2' .. msg .. '^7')
        if source ~= 0 then
            TriggerClientEvent('QBCore:Notify', source, msg, 'success')
        end
    end, 'admin')

QBCore.Commands.Add(dropLegacyCmd, 'Borrar tablas legacy gloveboxitems/stashitems/trunkitems', {{
    name = 'confirm',
    help = 'Escribe confirm para ejecutar'
}}, false, function(source, args)
    if source ~= 0 and not isInvAdmin(source) then
        return
    end
    local needConfirm = not (Config.Database and Config.Database.dropLegacyRequiresConfirm == false)
    if needConfirm and (not args[1] or args[1]:lower() ~= 'confirm') then
        local msg = 'Uso: /' .. dropLegacyCmd .. ' confirm'
        if source ~= 0 then
            TriggerClientEvent('QBCore:Notify', source, msg, 'error')
        else
            print(msg)
        end
        return
    end
    DropLegacyTables()
    local msg = '[DP-Inventory] Tablas legacy eliminadas.'
    print('^3' .. msg .. '^7')
    if source ~= 0 then
        TriggerClientEvent('QBCore:Notify', source, msg, 'success')
    end
end, 'admin')

local TestStashPool = { -- raros / interesantes para probar el fog
{
    name = 'weapon_katana',
    amount = 1
}, {
    name = 'weapon_battleaxe',
    amount = 1
}, {
    name = 'weapon_switchblade',
    amount = 1
}, {
    name = 'weapon_dagger',
    amount = 1
}, {
    name = 'weapon_stone_hatchet',
    amount = 1
}, {
    name = 'heavyarmor',
    amount = 1
}, {
    name = 'armor',
    amount = 2
}, {
    name = 'cryptostick',
    amount = 1
}, {
    name = 'gpu4090',
    amount = 1
}, {
    name = 'gpu5090',
    amount = 1
}, {
    name = 'gpu3060',
    amount = 1
}, {
    name = 'laptop',
    amount = 1
}, {
    name = 'radioscanner',
    amount = 1
}, {
    name = 'bodycam',
    amount = 1
}, {
    name = 'police_stormram',
    amount = 1
}, {
    name = 'security_card_02',
    amount = 2
}, {
    name = 'security_card_01',
    amount = 3
}, {
    name = 'weaponlicense',
    amount = 1
}, {
    name = 'lawyerpass',
    amount = 1
}, {
    name = 'moneybag',
    amount = 1
}, {
    name = 'black_money',
    amount = 5000
}, {
    name = 'cash',
    amount = 2500
}, {
    name = 'dendrogyra_coral',
    amount = 3
}, {
    name = 'antipatharia_coral',
    amount = 2
}, {
    name = 'diving_gear',
    amount = 1
}, {
    name = 'parachute',
    amount = 1
}, {
    name = 'binoculars',
    amount = 1
}, {
    name = 'racing_gps',
    amount = 1
}, {
    name = 'newscam',
    amount = 1
}, {
    name = 'speaker',
    amount = 1
}, {
    name = 'skateboard',
    amount = 1
}, {
    name = 'item_bench',
    amount = 1
}, {
    name = 'attachment_bench',
    amount = 1
}, {
    name = 'handcuffs',
    amount = 2
}, {
    name = 'radio',
    amount = 1
}, {
    name = 'phone',
    amount = 1
}, {
    name = 'sim_card',
    amount = 1
}, {
    name = 'custom_bag_1',
    amount = 1
}, {
    name = 'custom_bag_2',
    amount = 1
}, {
    name = 'steel',
    amount = 10
}, {
    name = 'aluminum',
    amount = 8
}, {
    name = 'copper',
    amount = 12
}, {
    name = 'iron',
    amount = 6
}, {
    name = 'plastic',
    amount = 15
}, {
    name = 'rubber',
    amount = 10
}, {
    name = 'glass',
    amount = 8
}, {
    name = 'thermalpast',
    amount = 3
}, {
    name = 'animal_medkit',
    amount = 2
}, {
    name = 'lotto',
    amount = 5
}}

local function ShuffleTable(t)
    local n = #t
    for i = n, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local function BuildRandomStashItems(maxSlots, fillCount)
    local pool = {}
    for i = 1, #TestStashPool do
        pool[i] = TestStashPool[i]
    end
    ShuffleTable(pool)

    local items = {}
    local count = math.min(fillCount or maxSlots, maxSlots, #pool)
    local usedSlots = {}

    for i = 1, count do
        local entry = pool[i]
        local itemInfo = QBCore.Shared.Items[entry.name]
        if itemInfo then
            local slot
            repeat
                slot = math.random(1, maxSlots)
            until not usedSlots[slot]
            usedSlots[slot] = true

            local info = {}
            if itemInfo.type == 'weapon' then
                info.quality = math.random(40, 100)
                info.serie = ('TEST-%s-%04d'):format(string.upper(string.sub(entry.name, 8, 12) or 'WPN'),
                    math.random(1000, 9999))
            end
            if entry.name == 'phone' then
                info.imei = tostring(math.random(100000000000000, 999999999999999))
            end
            if entry.name == 'custom_bag_1' or entry.name == 'custom_bag_2' then
                info.bagid = ('bag_test_%s_%d'):format(entry.name, math.random(10000, 99999))
            end

            items[slot] = {
                name = itemInfo.name,
                amount = entry.amount or 1,
                info = info,
                label = itemInfo.label,
                description = itemInfo.description or '',
                weight = itemInfo.weight,
                type = itemInfo.type,
                unique = itemInfo.unique,
                useable = itemInfo.useable,
                image = itemInfo.image,
                slot = slot
            }
        end
    end
    return items
end

local function EnsureTestStashSeeded(stashId, label, maxweight, slots, fillCount)
    local inv = Inventories[stashId]
    local empty = true
    if inv and inv.items then
        for _, _ in pairs(inv.items) do
            empty = false
            break
        end
    end

    if not inv then
        Inventories[stashId] = {
            items = {},
            isOpen = false,
            label = label,
            maxweight = maxweight,
            slots = slots
        }
        inv = Inventories[stashId]
        empty = true
    end

    if empty then
        inv.items = BuildRandomStashItems(slots, fillCount)
        inv.label = label
        inv.maxweight = maxweight
        inv.slots = slots
        -- persistir en DB para que sobreviva reinicios
        MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?',
            {stashId, json.encode(inv.items), json.encode(inv.items)})
        print(('[DP-Inventory] Test stash %s rellenado con items aleatorios.'):format(stashId))
    end
end

RegisterNetEvent('DP-Inventory:server:OpenTestStash', function(stashId)
    local src = source
    if stashId == 'stash_pruebas_peque' then
        EnsureTestStashSeeded('stash_pruebas_peque', 'Armario Pequeño', 100000, 12, 4)
        OpenInventory(src, 'stash_pruebas_peque', {
            label = 'Armario Pequeño',
            maxweight = 100000,
            slots = 12
        })
    else
        EnsureTestStashSeeded('stash_pruebas', 'Armario de Pruebas', 500000, 39, 28)
        OpenInventory(src, 'stash_pruebas', {
            label = 'Armario de Pruebas',
            maxweight = 500000,
            slots = 39
        })
    end
end)
