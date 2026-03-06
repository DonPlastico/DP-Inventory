-- Commands
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

    if itemName == 'id_card' then
        info.citizenid = player.PlayerData.citizenid
        info.firstname = player.PlayerData.charinfo.firstname
        info.lastname = player.PlayerData.charinfo.lastname
        info.birthdate = player.PlayerData.charinfo.birthdate
        info.gender = player.PlayerData.charinfo.gender
        info.nationality = player.PlayerData.charinfo.nationality
    elseif itemName == 'driver_license' then
        info.firstname = player.PlayerData.charinfo.firstname
        info.lastname = player.PlayerData.charinfo.lastname
        info.birthdate = player.PlayerData.charinfo.birthdate
        info.type = 'Class C Driver License'
    elseif itemData['type'] == 'weapon' then
        amount = 1
        info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) ..
                                  QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
        info.quality = 100
    elseif itemName == 'harness' then
        info.uses = 20
    elseif itemName == 'markedbills' then
        info.worth = math.random(5000, 10000)
    elseif itemName == 'printerdocument' then
        info.url =
            'https://cdn.discordapp.com/attachments/870094209783308299/870104331142189126/Logo_-_Display_Picture_-_Stylized_-_Red.png'
    end

    if AddItem(id, itemName, amount, false, info, 'give item command') then
        QBCore.Functions.Notify(source,
            Lang:t('notify.yhg') .. GetPlayerName(id) .. ' ' .. amount .. ' ' .. itemName .. '', 'success')
        TriggerClientEvent('DP-Inventory:client:ItemBox', id, itemData, 'add', amount)
        if Player(id).state.inv_busy then
            TriggerClientEvent('DP-Inventory:client:updateInventory', id)
        end
    else
        QBCore.Functions.Notify(source, Lang:t('notify.cgitem'), 'error')
    end
end, 'admin')

-- Variables cacheadas para optimizar comandos
local filteredRandomItems = nil

QBCore.Commands.Add('randomitems', 'Receive random items', {}, false, function(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        return
    end

    -- Creamos la lista solo la primera vez que se ejecuta el comando para no sobrecargar la CPU
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
        local amount = randitem['unique'] and 1 or math.random(1, 10)
        local emptySlot = nil

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

QBCore.Commands.Add('clearinv', 'Clear Inventory (Admin Only)', {{
    name = 'id',
    help = 'Player ID'
}}, false, function(source, args)
    local id = tonumber(args[1]) or source
    ClearInventory(id)
end, 'admin')

-- Keybindings

RegisterCommand('closeInv', function(source)
    CloseInventory(source)
end, false)

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
    local hotbarItems = {items[1], items[2], items[3], items[4], items[5]}
    TriggerClientEvent('DP-Inventory:client:hotbar', source, hotbarItems)
end, false)

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
            return OpenInventory(source)
        end

        -- SISTEMA ANTI-CRASH: Por si VehicleStorage falla o no se configuró bien
        local defaultSlots = 35
        local defaultWeight = 60000

        if VehicleStorage and VehicleStorage.default then
            defaultSlots = VehicleStorage.default.slots or 35
            defaultWeight = VehicleStorage.default.maxWeight or 60000
        end

        local slots = VehicleStorage and VehicleStorage[class] and VehicleStorage[class].trunkSlots or defaultSlots
        local maxweight = VehicleStorage and VehicleStorage[class] and VehicleStorage[class].trunkWeight or
                              defaultWeight

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
