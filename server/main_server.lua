QBCore = exports['qb-core']:GetCoreObject()
Inventories = {}
Drops = {}
RegisteredShops = {}

-- ==========================================
-- THREADS
-- ==========================================
CreateThread(function()
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
            print(#result .. ' inventories successfully loaded')
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

-- ==========================================
-- HANDLERS
-- ==========================================
AddEventHandler('playerDropped', function()
    local src = source
    for _, inv in pairs(Inventories) do
        if inv.isOpen == src then
            inv.isOpen = false
        end
    end

    -- Liberamos las bolsas si el jugador se desconecta
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

-- ==========================================
-- FUNCTIONS
-- ==========================================
function checkWeapon(source, item)
    local currentWeapon = type(item) == 'table' and item.name or item
    local ped = GetPlayerPed(source)
    local weapon = GetSelectedPedWeapon(ped)
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    if weaponInfo and weaponInfo.name == currentWeapon then
        RemoveWeaponFromPed(ped, weapon)
        TriggerClientEvent('qb-weapons:client:UseWeapon', source, {
            name = currentWeapon
        }, false)
    end
end

-- ==========================================
-- EVENTS
-- ==========================================
RegisterNetEvent('DP-Inventory:server:openVending', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    -- OPTIMIZACIÓN: Solo crea la tienda si no existe para evitar fugas de memoria
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

RegisterNetEvent('DP-Inventory:server:closeInventory', function(inventory)
    local src = source
    local QBPlayer = QBCore.Functions.GetPlayer(src)
    if not QBPlayer then
        return
    end

    Player(src).state.inv_busy = false

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
        -- Solo el que la abrió legítimamente puede quitar el bloqueo
        if Drops[inventory].isOpen == src then
            Drops[inventory].isOpen = false
        end

        -- Eliminamos la bolsa solo si nadie más la está usando y está vacía
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
end)

RegisterNetEvent('DP-Inventory:server:useItem', function(item)
    local src = source
    local itemData = GetItemBySlot(src, item.slot)
    if not itemData then
        return
    end

    local itemInfo = QBCore.Shared.Items[itemData.name]

    if itemData.type == 'weapon' then
        TriggerClientEvent('qb-weapons:client:UseWeapon', src, itemData,
            itemData.info.quality and itemData.info.quality > 0)
        TriggerClientEvent('DP-Inventory:client:ItemBox', src, itemInfo, 'use')
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
            Drops[dropId].isHeld = false -- Solo el que la tenía cogida puede liberarla
        end
    end
end)

-- ==========================================
-- CALLBACKS
-- ==========================================
QBCore.Functions.CreateCallback('DP-Inventory:server:GetCurrentDrops', function(_, cb)
    cb(Drops)
end)

QBCore.Functions.CreateCallback('DP-Inventory:server:requestHoldDrop', function(source, cb, dropId)
    -- Comprobamos si la bolsa existe
    if Drops[dropId] then
        -- Si no está abierta y nadie más la tiene en la mano...
        if not Drops[dropId].isOpen and not Drops[dropId].isHeld then
            Drops[dropId].isHeld = source -- Nos adjudicamos la bolsa
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

        -- ADIÓS METATABLE: Creación directa de la tabla limpia
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
                isOpen = false, -- Empezamos cerrado
                isHeld = false -- Empezamos sin estar cogida
            }
            TriggerClientEvent('DP-Inventory:client:setupDropTarget', -1, dropId)
        else
            -- Si ya existe la mochila, encontramos un hueco libre
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
            end -- Mochila llena
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

    -- Comprobamos si alguien la tiene en la mano o ya está abierta
    if not Player or not Drops[dropId] or Drops[dropId].isOpen or Drops[dropId].isHeld then
        cb(false)
        return
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - Drops[dropId].coords) > 2.5 then
        cb(false)
        return
    end

    Drops[dropId].isOpen = src -- Registramos QUIÉN la abre

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

-- Callback para devolver los nombres reales de los personajes al inventario
QBCore.Functions.CreateCallback('DP-Inventory:server:GetPlayerNames', function(source, cb, serverIds)
    local playersData = {}

    for _, id in ipairs(serverIds) do
        local TargetPlayer = QBCore.Functions.GetPlayer(id)

        if TargetPlayer then
            -- Cogemos el nombre del personaje (Roleplay)
            local charName = TargetPlayer.PlayerData.charinfo.firstname .. " " ..
                                 TargetPlayer.PlayerData.charinfo.lastname
            -- Cogemos el nombre de Steam original
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

-- ==========================================
-- ITEM MOVE LOGIC (ANTI-DUPE)
-- ==========================================
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

        -- FILTRO ANTI-DUPE: Cantidades negativas o movimiento al mismo slot exacto
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
                if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'stacked item') then
                    AddItem(toId, toItem.name, toAmount, toSlot, toItem.info, 'stacked item')

                    -- [[ INICIO INTEGRACIÓN DP-REALMONEY ]] --
                    if GetResourceState("DP-RealMoney") ~= 'missing' then
                        exports['DP-RealMoney']:UpdateCash(fromId, fromItem.name, toAmount, 'remove')
                        exports['DP-RealMoney']:UpdateCash(toId, toItem.name, toAmount, 'add')
                    end
                    -- [[ FIN INTEGRACIÓN ]] --
                end
            elseif not toItem and toAmount < fromAmount then
                if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'split item') then
                    AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'split item')

                    -- [[ INICIO INTEGRACIÓN DP-REALMONEY ]] --
                    if GetResourceState("DP-RealMoney") ~= 'missing' then
                        exports['DP-RealMoney']:UpdateCash(fromId, fromItem.name, toAmount, 'remove')
                        exports['DP-RealMoney']:UpdateCash(toId, fromItem.name, toAmount, 'add')
                    end
                    -- [[ FIN INTEGRACIÓN ]] --
                end
            else
                if toItem then
                    local fromItemAmount = fromItem.amount
                    local toItemAmount = toItem.amount

                    if RemoveItem(fromId, fromItem.name, fromItemAmount, fromSlot, 'swapped item') and
                        RemoveItem(toId, toItem.name, toItemAmount, toSlot, 'swapped item') then
                        AddItem(toId, fromItem.name, fromItemAmount, toSlot, fromItem.info, 'swapped item')
                        AddItem(fromId, toItem.name, toItemAmount, fromSlot, toItem.info, 'swapped item')

                        -- [[ INICIO INTEGRACIÓN DP-REALMONEY ]] --
                        if GetResourceState("DP-RealMoney") ~= 'missing' then
                            exports['DP-RealMoney']:UpdateCash(fromId, fromItem.name, fromItemAmount, 'remove')
                            exports['DP-RealMoney']:UpdateCash(toId, toItem.name, toItemAmount, 'remove')
                            exports['DP-RealMoney']:UpdateCash(toId, fromItem.name, fromItemAmount, 'add')
                            exports['DP-RealMoney']:UpdateCash(fromId, toItem.name, toItemAmount, 'add')
                        end
                        -- [[ FIN INTEGRACIÓN ]] --
                    end
                else
                    if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'moved item') then
                        AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'moved item')

                        -- [[ INICIO INTEGRACIÓN DP-REALMONEY ]] --
                        if GetResourceState("DP-RealMoney") ~= 'missing' then
                            exports['DP-RealMoney']:UpdateCash(fromId, fromItem.name, toAmount, 'remove')
                            exports['DP-RealMoney']:UpdateCash(toId, fromItem.name, toAmount, 'add')
                        end
                        -- [[ FIN INTEGRACIÓN ]] --
                    end
                end
            end
        end
    end)
