-- DP-Inventory · client/main_client.lua
-- Núcleo del cliente.
QBCore = exports['qb-core']:GetCoreObject()

PlayerData = nil

local hotbarShown = false
local inVendingZone = false
local isInventoryOpen = false
local currentAimStyle = joaat("Default")
local isHolstering = false
local holsterTimer = nil
local isPlayerAdmin = false
local isTransitioningAdmin = false
local isCursorModeActive = false
local isOtherInventoryOpen = false
local inventoryOpenCoords = nil
local moveWhileOpen = false
local isTypingInUI = false
local inventoryPosition = 'bottom'

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set('inv_busy', false, true)
    PlayerData = QBCore.Functions.GetPlayerData()
    GetDrops()

    QBCore.Functions.TriggerCallback('DP-Inventory:server:IsAdmin', function(admin)
        isPlayerAdmin = admin
    end)

    QBCore.Functions.TriggerCallback('DP-Inventory:server:GetMovePref', function(pref)
        moveWhileOpen = pref
    end)

    QBCore.Functions.TriggerCallback('DP-Inventory:server:GetPosition', function(pos)
        inventoryPosition = pos
    end)

    QBCore.Functions.TriggerCallback('DP-Inventory:server:GetSoundPref', function(pref)
        SendNUIMessage({
            action = 'setSoundPref',
            status = pref
        })
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set('inv_busy', true, true)
    PlayerData = nil
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        PlayerData = QBCore.Functions.GetPlayerData()
    end

    QBCore.Functions.TriggerCallback('DP-Inventory:server:IsAdmin', function(admin)
        isPlayerAdmin = admin
    end)

    QBCore.Functions.TriggerCallback('DP-Inventory:server:GetMovePref', function(pref)
        moveWhileOpen = pref
    end)

    QBCore.Functions.TriggerCallback('DP-Inventory:server:GetPosition', function(pos)
        inventoryPosition = pos
    end)

    QBCore.Functions.TriggerCallback('DP-Inventory:server:GetSoundPref', function(pref)
        SendNUIMessage({
            action = 'setSoundPref',
            status = pref
        })
    end)
end)

local function UpdateNuiFocus()
    if isInventoryOpen then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(not isTypingInUI)
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end

function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then
        return
    end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function GetVehicleConfig(veh)
    if veh == 0 then
        return nil
    end
    return {
        vehClass = GetVehicleClass(veh),
        seats = GetVehicleModelNumberOfSeats(GetEntityModel(veh)),
        hasDoor = {
            fl = DoesVehicleHaveDoor(veh, 0),
            fr = DoesVehicleHaveDoor(veh, 1),
            rl = DoesVehicleHaveDoor(veh, 2),
            rr = DoesVehicleHaveDoor(veh, 3),
            hood = DoesVehicleHaveDoor(veh, 4),
            trunk = DoesVehicleHaveDoor(veh, 5)
        }
    }
end

local function GetAttachmentSlotType(attachmentType)
    local t = attachmentType:lower()
    if t == 'suppressor_attachment' then
        return 'suppressor'
    elseif t == 'barrel_attachment' or t == 'comp_attachment' then
        return 'barrel'
    elseif t == 'grip_attachment' then
        return 'grip'
    elseif t == 'flashlight_attachment' then
        return 'flashlight'
    elseif t:find('scope_attachment') or t == 'smallscope_attachment' or t == 'medscope_attachment' or t ==
        'largescope_attachment' or t == 'holoscope_attachment' or t == 'advscope_attachment' or t ==
        'nvscope_attachment' or t == 'thermalscope_attachment' then
        return 'scope'
    elseif t == 'clip_attachment' then
        return 'clip'
    elseif t == 'drum_attachment' then
        return 'drum'
    elseif t:find('camo_attachment') or t == 'luxuryfinish_attachment' then
        return 'camo'
    end
    return 'flashlight'
end

local function FormatWeaponAttachments(itemdata)
    if not itemdata.info or not itemdata.info.attachments or #itemdata.info.attachments == 0 then
        return {}
    end
    local attachments = {}
    local weaponName = itemdata.name
    local WeaponAttachments = exports['DP-Inventory']:getConfigWeaponAttachments()
    if not WeaponAttachments then
        return {}
    end
    for attachmentType, weapons in pairs(WeaponAttachments) do
        local componentHash = weapons[weaponName]
        if componentHash then
            for _, attachmentData in pairs(itemdata.info.attachments) do
                if attachmentData.component == componentHash then
                    local label = QBCore.Shared.Items[attachmentType] and QBCore.Shared.Items[attachmentType].label or
                                      'Unknown'
                    attachments[#attachments + 1] = {
                        attachment = attachmentType,
                        label = label,
                        slotType = GetAttachmentSlotType(attachmentType)
                    }
                end
            end
        end
    end
    return attachments
end

function HasItem(items, amount)
    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = isArray and #items or 0
    local count = 0

    if isTable and not isArray then
        for _ in pairs(items) do
            totalItems = totalItems + 1
        end
    end

    if PlayerData and type(PlayerData.items) == "table" then
        for _, itemData in pairs(PlayerData.items) do
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
    end

    return false
end

exports('HasItem', HasItem)

RegisterNetEvent('DP-Inventory:client:requiredItems', function(items, bool)
    local itemTable = {}
    if bool then
        for k in pairs(items) do
            itemTable[#itemTable + 1] = {
                item = items[k].name,
                label = QBCore.Shared.Items[items[k].name]['label'],
                image = items[k].image
            }
        end
    end

    SendNUIMessage({
        action = 'requiredItem',
        items = itemTable,
        toggle = bool
    })
end)

RegisterNetEvent('DP-Inventory:client:hotbar', function(items)
    hotbarShown = not hotbarShown
    SendNUIMessage({
        action = 'toggleHotbar',
        open = hotbarShown,
        items = items
    })
end)

RegisterNetEvent('DP-Inventory:client:closeInv', function()
    SendNUIMessage({
        action = 'close'
    })
end)

RegisterNetEvent('DP-Inventory:client:updateInventory', function()
    local items = {}
    if PlayerData and type(PlayerData.items) == "table" then
        items = PlayerData.items
    end

    local imeisToCheck = {}
    for _, item in pairs(items) do
        if item and item.name == 'phone' and item.info and item.info.imei then
            table.insert(imeisToCheck, item.info.imei)
        end
    end

    if #imeisToCheck > 0 then
        QBCore.Functions.TriggerCallback('DP-Inventory:getSimStates', function(simStates)
            if simStates then
                for _, item in pairs(items) do
                    if item and item.name == 'phone' and item.info and item.info.imei then
                        local simNum = simStates[item.info.imei]
                        item.hasSim = simNum ~= nil
                        item.sim_number = simNum
                    end
                end
            end

            SendNUIMessage({
                action = 'update',
                inventory = items
            })
        end, imeisToCheck)
    else
        SendNUIMessage({
            action = 'update',
            inventory = items
        })
    end
end)

local function ShowItemBox(itemData, type, amount)
    SendNUIMessage({
        action = 'itemBox',
        item = itemData,
        type = type,
        amount = amount
    })
end

RegisterNetEvent('DP-Inventory:client:ItemBox', ShowItemBox)

RegisterNetEvent('DP-Inventory:client:WeaponItemBox', function(itemInfo)
    if itemInfo and itemInfo.name == 'weapon_switchblade' then
        return
    end
    local ped = PlayerPedId()
    local currentWeapon = GetSelectedPedWeapon(ped)
    local itemHash = joaat(itemInfo.name)

    if QBCore.Shared.Weapons then
        for _, v in pairs(QBCore.Shared.Weapons) do
            if v.name == itemInfo.name then
                itemHash = v.hash or joaat(v.name)
                break
            end
        end
    end

    if currentWeapon == itemHash then
        ShowItemBox(itemInfo, 'equip', 1)
    else
        ShowItemBox(itemInfo, 'holster', 1)
    end
end)

RegisterNetEvent('DP-Inventory:server:RobPlayer', function(TargetId)
    SendNUIMessage({
        action = 'RobMoney',
        TargetId = TargetId
    })
end)

RegisterNetEvent('DP-Inventory:client:openInventory', function(items, other)
    isInventoryOpen = true
    UpdateNuiFocus()
    blockPauseMenuTimer = GetGameTimer() + 800

    if other then
        isOtherInventoryOpen = true
        inventoryOpenCoords = GetEntityCoords(PlayerPedId())
    else
        isOtherInventoryOpen = false
    end

    local charName = "INVENTARIO"
    if PlayerData and PlayerData.charinfo then
        charName = PlayerData.charinfo.firstname .. ' ' .. PlayerData.charinfo.lastname
    end

    local ped = PlayerPedId()
    local isDriver = false
    local inVeh = false
    local mySeat = nil
    local vehData = nil
    local veh = GetVehiclePedIsIn(ped, false)

    if veh ~= 0 then
        inVeh = true
        isDriver = true
        vehData = GetVehicleConfig(veh)
        for i = -1, 2 do
            if GetPedInVehicleSeat(veh, i) == ped then
                mySeat = i
                break
            end
        end
    end

    local _, dynamicWeight = GetPlayerDynamicCapacity()
    local dynamicSlots = Config.MaxSlots

    local imeisToCheck = {}
    if items then
        for _, item in pairs(items) do
            if item and item.name == 'phone' and item.info and item.info.imei then
                table.insert(imeisToCheck, item.info.imei)
            end
        end
    end

    if #imeisToCheck > 0 then
        QBCore.Functions.TriggerCallback('DP-Inventory:getSimStates', function(simStates)
            if simStates then
                for _, item in pairs(items) do
                    if item and item.name == 'phone' and item.info and item.info.imei then
                        local simNum = simStates[item.info.imei]
                        item.hasSim = simNum ~= nil
                        item.sim_number = simNum
                    end
                end
            end

            SendNUIMessage({
                action = 'open',
                inventory = items,
                slots = dynamicSlots,
                maxweight = dynamicWeight,
                other = other,
                playerName = charName,
                isDriver = isDriver,
                inVehicle = inVeh,
                vehicleSeat = mySeat,
                vehData = vehData,
                isAdmin = isPlayerAdmin,
                invPosition = inventoryPosition,
                moveWhileOpen = moveWhileOpen
            })
        end, imeisToCheck)
    else
        SendNUIMessage({
            action = 'open',
            inventory = items,
            slots = dynamicSlots,
            maxweight = dynamicWeight,
            other = other,
            playerName = charName,
            isDriver = isDriver,
            inVehicle = inVeh,
            vehicleSeat = mySeat,
            vehData = vehData,
            isAdmin = isPlayerAdmin,
            invPosition = inventoryPosition,
            moveWhileOpen = moveWhileOpen
        })
    end
end)

RegisterNetEvent('DP-Inventory:client:openBagInventory', function(items, bagData)
    isInventoryOpen = true
    UpdateNuiFocus()
    blockPauseMenuTimer = GetGameTimer() + 800

    local charName = "INVENTARIO"
    if PlayerData and PlayerData.charinfo then
        charName = PlayerData.charinfo.firstname .. ' ' .. PlayerData.charinfo.lastname
    end

    local _, dynamicWeight = GetPlayerDynamicCapacity()
    local dynamicSlots = Config.MaxSlots

    SendNUIMessage({
        action = 'openBag',
        inventory = items,
        slots = dynamicSlots,
        maxweight = dynamicWeight,
        bag = bagData,
        playerName = charName,
        isAdmin = isPlayerAdmin,
        invPosition = inventoryPosition,
        moveWhileOpen = moveWhileOpen
    })
end)

RegisterNetEvent('DP-Inventory:client:giveAnim', function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        return
    end
    LoadAnimDict('mp_common')
    TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_b', 8.0, 1.0, -1, 16, 0, false, false, false)
end)

local appliedAimStyles = {}
local lastWeapons = {}
local equipTimers = {}

CreateThread(function()
    while true do
        Wait(500)
        local myPed = PlayerPedId()
        local myId = PlayerId()

        if isInventoryOpen then
            local inVehicle = IsPedInAnyVehicle(myPed, false)
            local currentVeh = GetVehiclePedIsIn(myPed, false)
            local currentSeat = nil
            local vData = nil

            if inVehicle and currentVeh ~= 0 then
                vData = GetVehicleConfig(currentVeh)
                for i = -1, (vData.seats - 2) do
                    if GetPedInVehicleSeat(currentVeh, i) == myPed then
                        currentSeat = i
                        break
                    end
                end
                SendNUIMessage({
                    action = 'checkVehicleState',
                    inVehicle = true,
                    isDriver = true,
                    seat = currentSeat,
                    vehData = vData
                })
            else
                SendNUIMessage({
                    action = 'checkVehicleState',
                    inVehicle = false,
                    isDriver = false,
                    seat = nil,
                    vehData = nil
                })
            end
        end

        local currentWeapon = GetSelectedPedWeapon(myPed)
        if lastWeapons[myId] ~= currentWeapon then
            lastWeapons[myId] = currentWeapon
            equipTimers[myId] = GetGameTimer()
            appliedAimStyles[myId] = nil
        end

        if currentWeapon ~= joaat('WEAPON_UNARMED') and currentWeapon ~= 0 then
            local stateKey = tostring(currentAimStyle) .. "_" .. tostring(currentWeapon)

            if appliedAimStyles[myId] ~= stateKey then
                if GetGameTimer() - (equipTimers[myId] or 0) > 1500 then
                    SetWeaponAnimationOverride(myPed, currentAimStyle)
                    appliedAimStyles[myId] = stateKey
                end
            end
        end

        for _, player in ipairs(GetActivePlayers()) do
            if player ~= myId then
                local targetPed = GetPlayerPed(player)

                if targetPed ~= 0 then
                    local targetWeapon = GetSelectedPedWeapon(targetPed)

                    if lastWeapons[player] ~= targetWeapon then
                        lastWeapons[player] = targetWeapon
                        equipTimers[player] = GetGameTimer()
                        appliedAimStyles[player] = nil
                    end

                    if targetWeapon ~= joaat('WEAPON_UNARMED') and targetWeapon ~= 0 then
                        local serverId = GetPlayerServerId(player)
                        local targetAimStyle = Player(serverId).state.aimStyle

                        if targetAimStyle then
                            local targetStateKey = tostring(targetAimStyle) .. "_" .. tostring(targetWeapon)

                            if appliedAimStyles[player] ~= targetStateKey then
                                if GetGameTimer() - (equipTimers[player] or 0) > 1500 then
                                    SetWeaponAnimationOverride(targetPed, targetAimStyle)
                                    appliedAimStyles[player] = targetStateKey
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()

        if isInventoryOpen and isOtherInventoryOpen and inventoryOpenCoords then
            if not IsPedInAnyVehicle(ped, false) then
                local currentCoords = GetEntityCoords(ped)
                local dist = #(currentCoords - inventoryOpenCoords)

                if dist > 4.0 then
                    local vehicle = QBCore.Functions.GetClosestVehicle()
                    if vehicle ~= 0 and #(currentCoords - GetEntityCoords(vehicle)) < 10.0 then
                        SetVehicleDoorShut(vehicle, 5, false)
                    end

                    SendNUIMessage({
                        action = 'forceCloseOther'
                    })
                    isOtherInventoryOpen = false
                    ClearPedTasks(ped)
                    QBCore.Functions.Notify("Te has alejado demasiado del objetivo.", "error")
                end
            end
        end

        local currentWeaponHash = GetSelectedPedWeapon(ped)
        local isClosedSwitchblade = switchbladeState and switchbladeState.holding and not switchbladeState.deployed and
                                        currentWeaponHash == joaat('WEAPON_KNUCKLE')

        if currentWeaponHash ~= joaat('WEAPON_UNARMED') and currentWeaponHash ~= 0 and not isClosedSwitchblade then
            local hasWeaponItem = false
            local weaponName = nil

            if QBCore.Shared.Weapons then
                for k, v in pairs(QBCore.Shared.Weapons) do
                    if v.hash == currentWeaponHash or joaat(v.name) == currentWeaponHash then
                        weaponName = v.name
                        break
                    end
                end
            end

            if weaponName then
                if HasItem(weaponName, 1) then
                    hasWeaponItem = true
                end
            else
                hasWeaponItem = true
            end

            if not hasWeaponItem then
                RemoveWeaponFromPed(ped, currentWeaponHash)
                SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
                QBCore.Functions.Notify('El arma que tenías en la mano ya no está en tu inventario.', 'error')
            end
        end
    end
end)

CreateThread(function()
    local vendingHashes = {}
    for _, modelStr in ipairs(Config.VendingObjects) do
        table.insert(vendingHashes, joaat(modelStr))
    end

    while true do
        local waitTime = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        local isNearVending = false
        local nearestVendingCoords = nil
        local nearestVendingObject = nil
        local closestDistance = 2.5

        if not LocalPlayer.state.inv_busy then
            for _, hash in ipairs(vendingHashes) do
                local object = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, 2.5, hash, false,
                    false, false)

                if DoesEntityExist(object) then
                    local objCoords = GetEntityCoords(object)
                    local distance = #(playerCoords - objCoords)

                    if distance < closestDistance then
                        closestDistance = distance
                        nearestVendingObject = object
                        nearestVendingCoords = objCoords
                        isNearVending = true
                    end
                end
            end
        end

        if isNearVending then
            waitTime = 0
            if not inVendingZone then
                exports['DP-Hud']:MostrarUI('vending_usar', Lang:t('menu.vending') or 'Usar Máquina', 'E', false)
                inVendingZone = true
            end

            if IsControlJustPressed(0, 38) then
                exports['DP-Hud']:OcultarUI('vending_usar')
                inVendingZone = false

                TriggerServerEvent('DP-Inventory:server:openVending', {
                    entity = nearestVendingObject,
                    coords = nearestVendingCoords
                })

                Wait(1000)
            end
        elseif inVendingZone and not isNearVending then
            exports['DP-Hud']:OcultarUI('vending_usar')
            inVendingZone = false
        end

        Wait(waitTime)
    end
end)

local blockPauseMenuTimer = 0

CreateThread(function()
    while true do
        local sleep = 500

        if isInventoryOpen then
            sleep = 0
            blockPauseMenuTimer = GetGameTimer() + 800

            if not isTypingInUI then
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 257, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 263, true)
                DisableControlAction(0, 37, true)
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
                DisablePlayerFiring(PlayerPedId(), true)
            end
        end

        if GetGameTimer() < blockPauseMenuTimer then
            sleep = 0
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 322, true)
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    local inVehicle = false
    while true do
        Wait(1500)
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) then
            if not inVehicle then
                inVehicle = true
                local veh = GetVehiclePedIsIn(ped, false)
                local plate = GetVehicleNumberPlateText(veh)

                if plate then
                    plate = string.gsub(plate, "^%s*(.-)%s*$", "%1")

                    QBCore.Functions.TriggerCallback('DP-Boombox_v2:checkCarRadio', function(hasRadio)
                        SendNUIMessage({
                            action = "updateVehicleRadio",
                            status = hasRadio
                        })
                    end, plate)
                end
            end
        else
            if inVehicle then
                inVehicle = false
                SendNUIMessage({
                    action = "updateVehicleRadio",
                    status = false
                })
            end
        end
    end
end)

RegisterCommand('openInv', function()
    if IsNuiFocused() or IsPauseMenuActive() then
        return
    end
    ExecuteCommand('inventory')
end, false)

RegisterCommand('toggleHotbar', function()
    ExecuteCommand('hotbar')
end, false)

for i = 1, 5 do
    RegisterCommand('slot_' .. i, function()
        local itemData = PlayerData.items[i]
        if not itemData then
            return
        end
        if itemData.type == "weapon" then
            if HoldingDrop then
                return QBCore.Functions.Notify("Ya tienes una bolsa en la mano, ¡ve y déjala!", "error", 5500)
            end
        end
        SendNUIMessage({
            action = 'setActiveSlot',
            slot = i
        })
        TriggerServerEvent('DP-Inventory:server:useItem', itemData)
    end, false)
    RegisterKeyMapping('slot_' .. i, Lang:t('inf_mapping.use_item') .. i, 'keyboard', i)
end

RegisterKeyMapping('openInv', Lang:t('inf_mapping.opn_inv'), 'keyboard', Config.Keybinds.Open)
RegisterKeyMapping('toggleHotbar', Lang:t('inf_mapping.tog_slots'), 'keyboard', Config.Keybinds.Hotbar)

local cachedInventoryData = {}

RegisterNetEvent('DP-Inventory:client:OpenMasterMenu', function(players, trunks, gloveboxes, stashes)
    cachedInventoryData = {
        players = players,
        trunks = trunks,
        gloveboxes = gloveboxes,
        stashes = stashes
    }
    TriggerEvent('DP-Inventory:client:ReturnToMasterMenu')
end)

RegisterNetEvent('DP-Inventory:client:ReturnToMasterMenu', function()
    local menuElements = {{
        header = "PANEL DE ADMINISTRACIÓN",
        txt = "Gestión global de Inventarios",
        isMenuHeader = true,
        icon = "fa-solid fa-server"
    }, {
        header = "Jugadores Conectados",
        txt = "Ver bolsillos de jugadores (" .. #cachedInventoryData.players .. ")",
        icon = "fa-solid fa-users",
        params = {
            event = "DP-Inventory:client:OpenSubMenu",
            args = {
                type = "players"
            }
        }
    }, {
        header = "Almacenes / Stashes",
        txt = "Ver cajas y alijos (" .. #cachedInventoryData.stashes .. ")",
        icon = "fa-solid fa-box-open",
        params = {
            event = "DP-Inventory:client:OpenSubMenu",
            args = {
                type = "stashes"
            }
        }
    }, {
        header = "Maleteros",
        txt = "Ver maleteros guardados (" .. #cachedInventoryData.trunks .. ")",
        icon = "fa-solid fa-car-rear",
        params = {
            event = "DP-Inventory:client:OpenSubMenu",
            args = {
                type = "trunks"
            }
        }
    }, {
        header = "Guanteras",
        txt = "Ver guanteras guardadas (" .. #cachedInventoryData.gloveboxes .. ")",
        icon = "fa-solid fa-toolbox",
        params = {
            event = "DP-Inventory:client:OpenSubMenu",
            args = {
                type = "gloveboxes"
            }
        }
    }, {
        header = "Cerrar Panel",
        icon = "fa-solid fa-xmark",
        params = {
            event = "DP-Menu:client:closeMenu"
        }
    }}
    exports["DP-Menu"]:openMenu(menuElements)
end)

RegisterNetEvent('DP-Inventory:client:OpenSubMenu', function(data)
    local menuElements = {}
    local itemsToLoad = cachedInventoryData[data.type] or {}

    local categoryHeaders = {
        players = {
            title = "JUGADORES",
            icon = "fa-solid fa-users"
        },
        stashes = {
            title = "ALMACENES",
            icon = "fa-solid fa-box-open"
        },
        trunks = {
            title = "MALETEROS",
            icon = "fa-solid fa-car-rear"
        },
        gloveboxes = {
            title = "GUANTERAS",
            icon = "fa-solid fa-toolbox"
        }
    }

    local headerInfo = categoryHeaders[data.type]
    menuElements[1] = {
        header = headerInfo.title,
        isMenuHeader = true,
        icon = headerInfo.icon
    }

    if #itemsToLoad == 0 then
        menuElements[#menuElements + 1] = {
            header = "Lista vacía",
            txt = "No hay datos registrados en esta categoría.",
            icon = "fa-solid fa-triangle-exclamation",
            isMenuHeader = true
        }
    else
        for _, item in ipairs(itemsToLoad) do
            if data.type == "players" then
                menuElements[#menuElements + 1] = {
                    header = "[" .. item.id .. "] " .. item.name,
                    txt = "Steam: " .. item.steam,
                    icon = "fa-solid fa-user",
                    params = {
                        event = "DP-Inventory:client:ForceOpenInventory",
                        args = {
                            targetId = item.id,
                            targetName = item.name
                        }
                    }
                }
            else
                menuElements[#menuElements + 1] = {
                    header = item,
                    icon = headerInfo.icon,
                    params = {
                        event = "DP-Inventory:client:ForceOpenStash",
                        args = {
                            identifier = item
                        }
                    }
                }
            end
        end
    end

    menuElements[#menuElements + 1] = {
        header = "Volver al Panel",
        icon = "fa-solid fa-arrow-left",
        params = {
            event = "DP-Inventory:client:ReturnToMasterMenu"
        }
    }

    exports["DP-Menu"]:openMenu(menuElements)
end)

RegisterNetEvent('DP-Inventory:client:ForceOpenStash', function(data)
    TriggerServerEvent("DP-Inventory:server:ForceOpenStash", data.identifier)
    QBCore.Functions.Notify("Abriendo: " .. data.identifier, "primary", 2500)
end)

RegisterNetEvent('DP-Inventory:client:ForceOpenInventory', function(data)
    TriggerServerEvent("DP-Inventory:server:OpenInventory", "otherplayer", data.targetId)
    QBCore.Functions.Notify("Inspeccionando a " .. data.targetName, "primary", 2500)
end)

RegisterNUICallback('PlayDropFail', function(_, cb)
    PlaySound(-1, 'Place_Prop_Fail', 'DLC_Dmod_Prop_Editor_Sounds', 0, 0, 1)
    cb('ok')
end)

local UISounds = {
    click = {
        name = 'SELECT',
        set = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    },
    tab = {
        name = 'NAV_LEFT_RIGHT',
        set = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    },
    drop = {
        name = 'NAV_UP_DOWN',
        set = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    },
    open_inv = {
        name = 'TOGGLE_ON',
        set = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    },
    close_inv = {
        name = 'BACK',
        set = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    },
    open_trunk = {
        name = 'ATM_WINDOW',
        set = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    },
    close_trunk = {
        name = 'BACK',
        set = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    },
    open_stash = {
        name = 'TOGGLE_ON',
        set = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    },
    close_stash = {
        name = 'CANCEL',
        set = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
    }
}

RegisterNUICallback('PlayUISound', function(data, cb)
    local s = data and data.sound and UISounds[data.sound]
    if s then
        PlaySoundFrontend(-1, s.name, s.set, true)
    end
    cb('ok')
end)

RegisterNUICallback('AttemptPurchase', function(data, cb)
    QBCore.Functions.TriggerCallback('DP-Inventory:server:attemptPurchase', function(canPurchase)
        cb(canPurchase)
    end, data)
end)

RegisterNUICallback('CloseInventory', function(data, cb)
    if isTransitioningAdmin then
        cb('ok')
        return
    end

    isTypingInUI = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    isInventoryOpen = false
    isOtherInventoryOpen = false
    blockPauseMenuTimer = GetGameTimer() + 800

    if GetResourceState('DP-PauseMenu') == 'started' then
        pcall(function()
            exports['DP-PauseMenu']:NotifyNuiClosed()
        end)
    end

    if data.name then
        if data.name:find('trunk-') then
            CloseTrunk()
        end
        TriggerServerEvent('DP-Inventory:server:closeInventory', data.name)
    elseif CurrentDrop then
        TriggerServerEvent('DP-Inventory:server:closeInventory', CurrentDrop)
        CurrentDrop = nil
    end

    if data.bagName then
        TriggerServerEvent('DP-Inventory:server:closeInventory', data.bagName)
    end
    cb('ok')
end)

RegisterNUICallback('toggleCursorMode', function(data, cb)
    isCursorModeActive = not isCursorModeActive

    if isCursorModeActive then
        SetNuiFocus(true, false)
        SetNuiFocusKeepInput(true)
    else
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
    end
    cb('ok')
end)

RegisterNUICallback('UseItem', function(data, cb)
    if data.item and data.item.type == "weapon" then
        Citizen.SetTimeout(100, function()
            TriggerServerEvent('DP-Inventory:server:useItem', data.item)
        end)
    else
        TriggerServerEvent('DP-Inventory:server:useItem', data.item)
    end
    cb('ok')
end)

RegisterNUICallback('SetInventoryData', function(data, cb)
    TriggerServerEvent('DP-Inventory:server:SetInventoryData', data.fromInventory, data.toInventory, data.fromSlot,
        data.toSlot, data.fromAmount, data.toAmount)
    cb('ok')
end)

RegisterNUICallback('GiveItem', function(data, cb)
    if data.target then
        QBCore.Functions.TriggerCallback('DP-Inventory:server:giveItem', function(success)
            cb(success)
        end, data.target, data.item.name, data.amount, data.slot, data.info)
    else
        QBCore.Functions.Notify('No se ha seleccionado a ningún jugador.', 'error')
        cb(false)
    end
end)

RegisterNUICallback('GetNearbyPlayers', function(_, cb)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local activePlayers = QBCore.Functions.GetPlayersFromCoords(playerCoords, 10.0)
    local serverIds = {}

    for _, player in pairs(activePlayers) do
        if player ~= PlayerId() then
            table.insert(serverIds, GetPlayerServerId(player))
        end
    end

    if #serverIds > 0 then
        QBCore.Functions.TriggerCallback('DP-Inventory:server:GetPlayerNames', function(playersData)
            cb(playersData)
        end, serverIds)
    else
        cb({})
    end
end)

RegisterNUICallback('Notify', function(data, cb)
    QBCore.Functions.Notify(data.message, data.type)
    cb('ok')
end)

RegisterNUICallback('GetRevealMap', function(data, cb)
    local invId = data and data.invId
    if type(invId) ~= 'string' or invId == '' then
        return cb({})
    end
    local raw = GetResourceKvpString('dp_inv_reveal_' .. invId)
    if not raw or raw == '' then
        return cb({})
    end
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then
        cb(decoded)
    else
        cb({})
    end
end)

RegisterNUICallback('SaveRevealMap', function(data, cb)
    local invId = data and data.invId
    local map = data and data.map
    if type(invId) ~= 'string' or invId == '' or type(map) ~= 'table' then
        return cb('ok')
    end
    SetResourceKvp('dp_inv_reveal_' .. invId, json.encode(map))
    cb('ok')
end)

RegisterNUICallback('GetBagPreviewKvp', function(data, cb)
    local bagId = data and data.bagId
    if type(bagId) ~= 'string' or bagId == '' then
        return cb(false)
    end
    local raw = GetResourceKvpString('dp_bag_preview_' .. bagId)
    if not raw or raw == '' then
        return cb(false)
    end
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then
        cb(decoded)
    else
        cb(false)
    end
end)

RegisterNUICallback('SaveBagPreviewKvp', function(data, cb)
    local bagId = data and data.bagId
    local preview = data and data.data
    if type(bagId) ~= 'string' or bagId == '' or type(preview) ~= 'table' then
        return cb('ok')
    end
    SetResourceKvp('dp_bag_preview_' .. bagId, json.encode(preview))
    cb('ok')
end)

RegisterNUICallback('GetBagPreview', function(data, cb)
    local bagId = data and data.bagId
    if type(data) == 'string' then
        local ok, decoded = pcall(json.decode, data)
        if ok and decoded then
            bagId = decoded.bagId
        end
    end
    QBCore.Functions.TriggerCallback('DP-Inventory:server:GetBagPreview', function(result)
        cb(result or false)
    end, bagId)
end)

RegisterNUICallback('GetWeaponData', function(cData, cb)
    local data = {
        WeaponData = QBCore.Shared.Items[cData.weapon],
        AttachmentData = FormatWeaponAttachments(cData.ItemData)
    }
    cb(data)
end)

RegisterNUICallback('RemoveAttachment', function(data, cb)
    local ped = PlayerPedId()
    local WeaponData = data.WeaponData
    local allAttachments = exports['DP-Inventory']:getConfigWeaponAttachments()
    local Attachment = allAttachments[data.AttachmentData.attachment][WeaponData.name]
    local itemInfo = QBCore.Shared.Items[data.AttachmentData.attachment]
    QBCore.Functions.TriggerCallback('DP-Inventory:server:RemoveAttachment', function(NewAttachments)
        if NewAttachments ~= false then
            local Attachies = {}
            RemoveWeaponComponentFromPed(ped, joaat(WeaponData.name), joaat(Attachment))
            for _, v in pairs(NewAttachments) do
                for attachmentType, weapons in pairs(allAttachments) do
                    local componentHash = weapons[WeaponData.name]
                    if componentHash and v.component == componentHash then
                        local label = itemInfo and itemInfo.label or 'Unknown'
                        Attachies[#Attachies + 1] = {
                            attachment = attachmentType,
                            label = label,
                            slotType = GetAttachmentSlotType(attachmentType)
                        }
                    end
                end
            end
            local DJATA = {
                Attachments = Attachies,
                WeaponData = WeaponData,
                itemInfo = itemInfo
            }
            cb(DJATA)
        else
            RemoveWeaponComponentFromPed(ped, joaat(WeaponData.name), joaat(Attachment))
            cb({})
        end
    end, data.AttachmentData, WeaponData)
end)

RegisterNUICallback('AddAttachment', function(data, cb)
    local ped = PlayerPedId()
    local WeaponData = data.WeaponData
    local AttachmentItem = data.AttachmentItem
    local allAttachments = exports['DP-Inventory']:getConfigWeaponAttachments()

    local weaponComponent = allAttachments[AttachmentItem.name] and allAttachments[AttachmentItem.name][WeaponData.name]

    if not weaponComponent then
        cb({
            success = false
        })
        return
    end

    QBCore.Functions.TriggerCallback('DP-Inventory:server:AddAttachment', function(result)
        if not result or result.success == false then
            cb({
                success = false
            })
            return
        end

        local currentWeapon = GetSelectedPedWeapon(ped)
        if currentWeapon == joaat(WeaponData.name) then
            GiveWeaponComponentToPed(ped, joaat(WeaponData.name), joaat(weaponComponent))
        end

        local Attachies = {}
        for _, v in pairs(result.attachments) do
            for attachmentType, weapons in pairs(allAttachments) do
                local componentHash = weapons[WeaponData.name]
                if componentHash and v.component == componentHash then
                    local itemInfo = QBCore.Shared.Items[attachmentType]
                    local label = itemInfo and itemInfo.label or 'Unknown'
                    Attachies[#Attachies + 1] = {
                        attachment = attachmentType,
                        label = label,
                        slotType = GetAttachmentSlotType(attachmentType)
                    }
                end
            end
        end

        cb({
            success = true,
            Attachments = Attachies,
            WeaponData = WeaponData
        })
    end, AttachmentItem, WeaponData)
end)

RegisterNUICallback('PerformAction', function(data, cb)
    local action = data.action
    local ped = PlayerPedId()

    if action == 'ropa_sombrero' then
        ExecuteCommand('hat')
    elseif action == 'ropa_gafas' then
        ExecuteCommand('glasses')
    elseif action == 'ropa_mascara' then
        ExecuteCommand('mask')
    elseif action == 'ropa_cabello' then
        ExecuteCommand('hair')
    elseif action == 'ropa_cambiar_cabello' then
        QBCore.Functions.Notify('¡Esto estará disponible PRÓXIMAMENTE!', 'error', 5000)
    elseif action == 'ropa_cadena' then
        ExecuteCommand('neck')
    elseif action == 'ropa_chaqueta' then
        ExecuteCommand('shirt')
    elseif action == 'ropa_chaleco' then
        ExecuteCommand('vest')
    elseif action == 'ropa_camiseta' then
        ExecuteCommand('top')
    elseif action == 'ropa_mochila' then
        ExecuteCommand('bag')
    elseif action == 'ropa_reloj' then
        ExecuteCommand('watch')
    elseif action == 'ropa_pulsera' then
        ExecuteCommand('bracelet')
    elseif action == 'ropa_guantes' then
        ExecuteCommand('gloves')
    elseif action == 'ropa_pantalones' then
        ExecuteCommand('pants')
    elseif action == 'ropa_zapatos' then
        ExecuteCommand('shoes')

    elseif action == 'amenazar' then
        ExecuteCommand('th')

    elseif action == 'cachear' then
        local player, distance = QBCore.Functions.GetClosestPlayer()
        if player ~= -1 and distance <= 2.5 then
            local targetPed = GetPlayerPed(player)
            local targetId = GetPlayerServerId(player)
            local isHandsUp = IsEntityPlayingAnim(targetPed, "missminuteman_1ig_2", "handsup_base", 3)
            local isCuffed = IsEntityPlayingAnim(targetPed, "mp_arresting", "idle", 3)
            local isDead = IsPedDeadOrDying(targetPed, true) or IsEntityPlayingAnim(targetPed, "dead", "dead_a", 3)

            if isHandsUp or isCuffed or isDead then
                QBCore.Functions.Progressbar("robbing_player", "Cacheando al sujeto...", 2500, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true
                }, {
                    animDict = "random@shop_robbery",
                    anim = "robbery_action_b",
                    flags = 16
                }, {}, {}, function()
                    StopAnimTask(ped, "random@shop_robbery", "robbery_action_b", 1.0)
                    TriggerServerEvent("DP-Inventory:server:OpenInventory", "otherplayer", targetId)
                end, function()
                    StopAnimTask(ped, "random@shop_robbery", "robbery_action_b", 1.0)
                    QBCore.Functions.Notify("Cacheo cancelado", "error")
                end)
            else
                QBCore.Functions.Notify("El sujeto no tiene las manos arriba ni está esposado.", "error", 4500)
            end
        else
            QBCore.Functions.Notify("No hay nadie lo suficientemente cerca.", "error", 4500)
        end

    elseif action == 'cargar' then
        ExecuteCommand('carry')
    elseif action == 'caballito' then
        ExecuteCommand('piggyback')
    elseif action == 'documentos' then
        QBCore.Functions.Notify('¡PRÓXIMAMENTE DISPONIBLE!', 'primary', 5000)

    elseif action == 'rockstar_start' then
        StartRecording(1)
        QBCore.Functions.Notify("🔴 Grabación iniciada", "success", 3000)

    elseif action == 'rockstar_start_25' then
        if IsRecording() then
            QBCore.Functions.Notify("Ya hay una grabación activa.", "error", 3000)
        else
            StartRecording(1)
            QBCore.Functions.Notify("🔴 Grabando — clips de 25 segundos", "success", 3000)
            CreateThread(function()
                while IsRecording() do
                    Wait(25000)
                    if IsRecording() then
                        StopRecordingAndSaveClip()
                        Wait(200)
                        StartRecording(1)
                        QBCore.Functions.Notify("📎 Clip guardado, siguiente segmento...", "primary", 2500)
                    end
                end
            end)
        end

    elseif action == 'rockstar_start_60' then
        if IsRecording() then
            QBCore.Functions.Notify("Ya hay una grabación activa.", "error", 3000)
        else
            StartRecording(1)
            QBCore.Functions.Notify("🔴 Grabando — clips de 1 minuto", "success", 3000)
            CreateThread(function()
                while IsRecording() do
                    Wait(55000)
                    if IsRecording() then
                        StopRecordingAndSaveClip()
                        Wait(200)
                        StartRecording(1)
                        QBCore.Functions.Notify("📎 Clip guardado, siguiente segmento...", "primary", 2500)
                    end
                end
            end)
        end

    elseif action == 'rockstar_start_300' then
        if IsRecording() then
            QBCore.Functions.Notify("Ya hay una grabación activa.", "error", 3000)
        else
            StartRecording(1)
            QBCore.Functions.Notify("🔴 Grabando — clips de 5 minutos", "success", 3000)
            CreateThread(function()
                while IsRecording() do
                    Wait(295000)
                    if IsRecording() then
                        StopRecordingAndSaveClip()
                        Wait(200)
                        StartRecording(1)
                        QBCore.Functions.Notify("📎 Clip guardado, siguiente segmento...", "primary", 2500)
                    end
                end
            end)
        end

    elseif action == 'rockstar_save' then
        if IsRecording() then
            StopRecordingAndSaveClip()
            QBCore.Functions.Notify("💾 Grabación guardada en el Rockstar Editor", "success", 4000)
        else
            QBCore.Functions.Notify("No hay ninguna grabación activa.", "error", 3000)
        end

    elseif action == 'rockstar_discard' then
        if IsRecording() then
            StopRecording()
            QBCore.Functions.Notify("🗑️ Grabación descartada", "primary", 3000)
        else
            QBCore.Functions.Notify("No hay ninguna grabación activa.", "error", 3000)
        end

    elseif action == 'rockstar_editor' then
        ActivateRockstarEditor()

    elseif action == 'aim_default' then
        currentAimStyle = joaat("Default")
        LocalPlayer.state:set('aimStyle', currentAimStyle, true)
        SetWeaponAnimationOverride(ped, currentAimStyle)
        QBCore.Functions.Notify("Estilo de apuntado: Normal", "success")

    elseif action == 'aim_gangster' then
        currentAimStyle = joaat("Gang1H")
        LocalPlayer.state:set('aimStyle', currentAimStyle, true)
        SetWeaponAnimationOverride(ped, currentAimStyle)
        QBCore.Functions.Notify("Estilo de apuntado: Gangster", "success")

    elseif action == 'aim_cowboy' then
        currentAimStyle = joaat("Hillbilly")
        LocalPlayer.state:set('aimStyle', currentAimStyle, true)
        SetWeaponAnimationOverride(ped, currentAimStyle)
        QBCore.Functions.Notify("Estilo de apuntado: Cowboy", "success")

    elseif action == 'weap_toggle' then
        TriggerEvent('DP-Inventory:client:ToggleBackItems')
        QBCore.Functions.Notify("Mostrando/Ocultando armas", "primary")

    elseif action == 'weap_front' then
        TriggerEvent('DP-Inventory:client:SetWeaponPosition', 'front')
        QBCore.Functions.Notify("Posición: Delante", "primary")
    elseif action == 'weap_back' then
        TriggerEvent('DP-Inventory:client:SetWeaponPosition', 'back')
        QBCore.Functions.Notify("Posición: Atrás", "primary")
    elseif action == 'weap_belt' then
        TriggerEvent('DP-Inventory:client:SetWeaponPosition', 'belt')
        QBCore.Functions.Notify("Posición: Cintura", "primary")
    elseif action == 'weap_normal' then
        TriggerEvent('DP-Inventory:client:SetWeaponPosition', 'normal')
        QBCore.Functions.Notify("Posición: Normal", "primary")
    elseif action == 'weap_chest' then
        TriggerEvent('DP-Inventory:client:SetWeaponPosition', 'chest')
        QBCore.Functions.Notify("Posición: Pecho", "primary")
    elseif action == 'weap_thigh' then
        TriggerEvent('DP-Inventory:client:SetWeaponPosition', 'thigh')
        QBCore.Functions.Notify("Posición: Muslo", "primary")
    elseif action == 'weap_leg' then
        TriggerEvent('DP-Inventory:client:SetWeaponPosition', 'leg')
        QBCore.Functions.Notify("Posición: Pierna", "primary")

    elseif string.find(action, "veh_") then
        local veh = GetVehiclePedIsIn(ped, false)

        if veh == 0 then
            QBCore.Functions.Notify("Debes estar en un vehículo.", "error")
            cb('ok')
            return
        end

        if action == 'veh_engine' then
            local isRunning = GetIsVehicleEngineRunning(veh)
            SetVehicleEngineOn(veh, not isRunning, false, true)
            QBCore.Functions.Notify(isRunning and "Motor Apagado" or "Motor Encendido", "primary")

        elseif action == 'veh_radio' then
            QBCore.Functions.Notify("¡PROXIMAMENTE DISPONIBLE!", "primary")

        elseif action == 'veh_keys' then
            local lockStatus = GetVehicleDoorLockStatus(veh)
            if lockStatus == 1 or lockStatus == 0 then
                SetVehicleDoorsLocked(veh, 2)
                QBCore.Functions.Notify("Vehículo Bloqueado", "error")
            else
                SetVehicleDoorsLocked(veh, 1)
                QBCore.Functions.Notify("Vehículo Desbloqueado", "success")
            end

        elseif action == 'veh_drift' then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                exports['DP-Utilitylib']:ToggleDrift(veh)
            else
                QBCore.Functions.Notify("Debes estar conduciendo un vehículo.", "error", 3000)
            end

        elseif action == 'veh_limitador' then
            exports['DP-Hud']:ToggleLimiter()

        elseif action == 'veh_crucero' then
            exports['DP-Hud']:ToggleCruise()

        elseif string.find(action, "veh_sit_") then
            local seatStr = action:gsub("veh_sit_", "")
            local seatIdx = nil

            if seatStr == "di" then
                seatIdx = -1
            elseif seatStr == "dd" then
                seatIdx = 0
            elseif seatStr == "ti" then
                seatIdx = 1
            elseif seatStr == "td" then
                seatIdx = 2
            else
                seatIdx = tonumber(seatStr)
            end

            if seatIdx and IsVehicleSeatFree(veh, seatIdx) then
                SetPedIntoVehicle(ped, veh, seatIdx)
            end

        elseif action == 'veh_hood' then
            local door = 4
            if GetVehicleDoorAngleRatio(veh, door) > 0.0 then
                SetVehicleDoorShut(veh, door, false)
            else
                SetVehicleDoorOpen(veh, door, false, false)
            end

        elseif action == 'veh_trunk' then
            local door = 5
            if GetVehicleDoorAngleRatio(veh, door) > 0.0 then
                SetVehicleDoorShut(veh, door, false)
            else
                SetVehicleDoorOpen(veh, door, false, false)
            end

        elseif action == 'veh_door_fl' then
            local door = 0
            if GetVehicleDoorAngleRatio(veh, door) > 0.0 then
                SetVehicleDoorShut(veh, door, false)
            else
                SetVehicleDoorOpen(veh, door, false, false)
            end

        elseif action == 'veh_door_fr' then
            local door = 1
            if GetVehicleDoorAngleRatio(veh, door) > 0.0 then
                SetVehicleDoorShut(veh, door, false)
            else
                SetVehicleDoorOpen(veh, door, false, false)
            end

        elseif action == 'veh_door_rl' then
            local door = 2
            if GetVehicleDoorAngleRatio(veh, door) > 0.0 then
                SetVehicleDoorShut(veh, door, false)
            else
                SetVehicleDoorOpen(veh, door, false, false)
            end

        elseif action == 'veh_door_rr' then
            local door = 3
            if GetVehicleDoorAngleRatio(veh, door) > 0.0 then
                SetVehicleDoorShut(veh, door, false)
            else
                SetVehicleDoorOpen(veh, door, false, false)
            end

        elseif action == 'veh_win_fl' then
            if IsVehicleWindowIntact(veh, 0) then
                RollDownWindow(veh, 0)
            else
                RollUpWindow(veh, 0)
            end
        elseif action == 'veh_win_fr' then
            if IsVehicleWindowIntact(veh, 1) then
                RollDownWindow(veh, 1)
            else
                RollUpWindow(veh, 1)
            end
        elseif action == 'veh_win_rl' then
            if IsVehicleWindowIntact(veh, 2) then
                RollDownWindow(veh, 2)
            else
                RollUpWindow(veh, 2)
            end
        elseif action == 'veh_win_rr' then
            if IsVehicleWindowIntact(veh, 3) then
                RollDownWindow(veh, 3)
            else
                RollUpWindow(veh, 3)
            end

        elseif action == 'veh_anchor' then
            if GetVehicleClass(veh) == 14 then
                local isAnchored = Entity(veh).state.isAnchored

                if isAnchored then
                    Entity(veh).state:set('isAnchored', false, true)
                    SetBoatAnchor(veh, false)
                    QBCore.Functions.Notify("Ancla recogida. Ya puedes navegar.", "success")
                else
                    Entity(veh).state:set('isAnchored', true, true)
                    SetVehicleEngineOn(veh, false, false, true)
                    SetBoatAnchor(veh, true)
                    QBCore.Functions.Notify("Ancla echada. El barco está asegurado a las olas.", "primary")

                    CreateThread(function()
                        while Entity(veh).state.isAnchored do
                            Wait(0)
                            if not DoesEntityExist(veh) then
                                break
                            end
                            local vel = GetEntityVelocity(veh)
                            SetEntityVelocity(veh, 0.0, 0.0, vel.z)
                        end
                    end)
                end
            else
                QBCore.Functions.Notify("¡Esto no es un barco!", "error")
            end
        end
    end

    cb('ok')
end)

RegisterNUICallback('CloseSecondaryInventory', function(data, cb)
    if data.name then
        if data.name:find('trunk-') then
            CloseTrunk()
        end
        TriggerServerEvent('DP-Inventory:server:closeInventory', data.name)
    end
    cb('ok')
end)

RegisterNUICallback('HolsterWeapon', function(data, cb)
    local ped = PlayerPedId()
    if isHolstering then
        cb('ok')
        return
    end

    local currentWeapon = GetSelectedPedWeapon(ped)
    if currentWeapon ~= 0 and currentWeapon ~= joaat('WEAPON_UNARMED') then
        isHolstering = true
        ClearPedTasks(ped)
        SetPedCurrentWeaponVisible(ped, false, false, false, false)
        SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)

        if not IsPedInAnyVehicle(ped, false) then
            LoadAnimDict('reaction@intimidation@1h')
            TaskPlayAnim(ped, 'reaction@intimidation@1h', 'outro', 8.0, 1.0, 1000, 48, 0, false, false, false)
        end

        local weaponName = nil
        for _, v in pairs(QBCore.Shared.Weapons) do
            if v.hash == currentWeapon or joaat(v.name) == currentWeapon then
                weaponName = v.name
                break
            end
        end

        if weaponName and QBCore.Shared.Items[weaponName] then
            TriggerEvent('DP-Inventory:client:ItemBox', QBCore.Shared.Items[weaponName], 'holster', 1)
        end

        if holsterTimer then
            Citizen.RemoveTimeout(holsterTimer)
        end
        holsterTimer = Citizen.SetTimeout(1000, function()
            isHolstering = false
            holsterTimer = nil
        end)
    end

    cb('ok')
end)

RegisterNUICallback('GetAdminMasterData', function(_, cb)
    QBCore.Functions.TriggerCallback('DP-Inventory:server:GetAdminMasterData', function(data)
        cb(data)
    end)
end)

RegisterNUICallback('ForceOpenAdmin', function(data, cb)
    isTransitioningAdmin = true
    if data.type == "player" then
        TriggerServerEvent("DP-Inventory:server:OpenInventory", "otherplayer", data.id)
    else
        TriggerServerEvent("DP-Inventory:server:ForceOpenStash", data.id)
    end
    SetTimeout(1000, function()
        isTransitioningAdmin = false
    end)
    cb('ok')
end)

RegisterNUICallback('SaveInventoryPosition', function(data, cb)
    inventoryPosition = data.position
    TriggerServerEvent('DP-Inventory:server:SavePosition', data.position)
    QBCore.Functions.Notify("Posición del inventario guardada", "success")
    cb('ok')
end)

RegisterNUICallback('SetTypingFocus', function(data, cb)
    isTypingInUI = data.isTyping
    UpdateNuiFocus()
    cb('ok')
end)

RegisterNUICallback('SaveMovePreference', function(data, cb)
    moveWhileOpen = data.status
    TriggerServerEvent('DP-Inventory:server:SaveMovePref', data.status)
    UpdateNuiFocus()
    cb('ok')
end)

RegisterNUICallback('SaveSoundPref', function(data, cb)
    TriggerServerEvent('DP-Inventory:server:SaveSoundPref', data.status)
    cb('ok')
end)

RegisterNUICallback('abrirRadioDesdeInventario', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "close"
    })
    TriggerEvent('DP-Inventory:client:closeInv')

    Wait(250)

    exports['DP-Boombox_v2']:OpenCarRadio()

    cb('ok')
end)

RegisterNetEvent('DP-Inventory:client:UpdateVehicleRadio', function(status)
    SendNUIMessage({
        action = "updateVehicleRadio",
        status = status
    })
end)

switchbladeState = {
    holding = false,
    deployed = false,
    prop = nil,
    itemData = nil,
    lastToggle = 0
}

local CLOSED_KNIFE_MODEL = joaat('prop_switchblade_closed')
local HASH_UNARMED = joaat('WEAPON_UNARMED')
local HASH_KNUCKLE = joaat('WEAPON_KNUCKLE')
local HASH_SWITCHBLADE = joaat('WEAPON_SWITCHBLADE')

local function DeleteSwitchbladeProp()
    if switchbladeState.prop and DoesEntityExist(switchbladeState.prop) then
        DeleteEntity(switchbladeState.prop)
    end
    switchbladeState.prop = nil
end

local function EquipClosedFist(ped)
    if not HasPedGotWeapon(ped, HASH_KNUCKLE, false) then
        GiveWeaponToPed(ped, HASH_KNUCKLE, 1, false, true)
    end
    SetCurrentPedWeapon(ped, HASH_KNUCKLE, true)
    SetPedCurrentWeaponVisible(ped, false, false, false, false)
end

local function AttachClosedSwitchblade()
    DeleteSwitchbladeProp()
    local ped = PlayerPedId()
    RequestModel(CLOSED_KNIFE_MODEL)
    while not HasModelLoaded(CLOSED_KNIFE_MODEL) do
        Wait(10)
    end

    local coords = GetEntityCoords(ped)
    local prop = CreateObject(CLOSED_KNIFE_MODEL, coords.x, coords.y, coords.z, true, true, false)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 57005), 0.090, -0.010, -0.020, 290.0, 20.0, 0.0, true, true,
        false, true, 1, true)
    SetModelAsNoLongerNeeded(CLOSED_KNIFE_MODEL)
    switchbladeState.prop = prop
end

local function HolsterSwitchblade(keepCurrentWeapon)
    local ped = PlayerPedId()
    DeleteSwitchbladeProp()
    RemoveWeaponFromPed(ped, HASH_KNUCKLE)
    RemoveWeaponFromPed(ped, HASH_SWITCHBLADE)
    SetPedCurrentWeaponVisible(ped, true, false, false, false)
    if not keepCurrentWeapon then
        SetCurrentPedWeapon(ped, HASH_UNARMED, true)
    end
    switchbladeState.holding = false
    switchbladeState.deployed = false
    switchbladeState.itemData = nil
end

local isTogglingSwitchblade = false

RegisterNetEvent('DP-Inventory:client:ToggleSwitchblade', function(itemData)
    if isTogglingSwitchblade then
        return
    end
    isTogglingSwitchblade = true

    local ped = PlayerPedId()
    local inVeh = IsPedInAnyVehicle(ped, false)
    local itemInfo = QBCore.Shared.Items['weapon_switchblade']

    if switchbladeState.holding then
        if not inVeh then
            LoadAnimDict('reaction@intimidation@1h')
            TaskPlayAnim(ped, 'reaction@intimidation@1h', 'outro', 8.0, 3.0, 1000, 48, 0, false, false, false)
            Wait(450)
        end
        HolsterSwitchblade(false)
        if itemInfo then
            ShowItemBox(itemInfo, 'holster', 1)
        end
        isTogglingSwitchblade = false
        return
    end

    local currentWeap = GetSelectedPedWeapon(ped)
    if currentWeap ~= HASH_UNARMED and currentWeap ~= 0 and currentWeap ~= HASH_KNUCKLE then
        local prevWeaponName = nil
        if QBCore.Shared.Weapons then
            for _, v in pairs(QBCore.Shared.Weapons) do
                if v.hash == currentWeap or joaat(v.name) == currentWeap then
                    prevWeaponName = v.name
                    break
                end
            end
        end

        if not inVeh then
            LoadAnimDict('reaction@intimidation@1h')
            TaskPlayAnim(ped, 'reaction@intimidation@1h', 'outro', 8.0, 3.0, 1000, 48, 0, false, false, false)
            Wait(500)
        end

        TriggerEvent('DP-Inventory:client:ResetHolster')
        if prevWeaponName then
            TriggerEvent('DP-Inventory:client:CheckWeapon', prevWeaponName)
        else
            SetCurrentPedWeapon(ped, HASH_UNARMED, true)
            RemoveAllPedWeapons(ped, true)
        end
        Wait(200)
    end

    switchbladeState.lastToggle = GetGameTimer()
    switchbladeState.holding = true
    switchbladeState.deployed = false
    switchbladeState.itemData = itemData

    if not inVeh then
        LoadAnimDict('reaction@intimidation@1h')
        TaskPlayAnim(ped, 'reaction@intimidation@1h', 'intro', 8.0, 3.0, 1200, 48, 0, false, false, false)
        Wait(450)
    end

    if switchbladeState.holding and not IsEntityDead(ped) then
        switchbladeState.lastToggle = GetGameTimer()
        ClearPedTasks(ped)
        SetCurrentPedWeapon(ped, HASH_UNARMED, true)
        Wait(50)

        EquipClosedFist(ped)
        AttachClosedSwitchblade()
        Wait(50)
        EquipClosedFist(ped)

        if itemInfo then
            ShowItemBox(itemInfo, 'equip', 1)
        end
    end

    isTogglingSwitchblade = false
end)

RegisterCommand('toggleSwitchblade', function()
    if not switchbladeState.holding or isTogglingSwitchblade then
        return
    end
    if isInventoryOpen or IsPauseMenuActive() then
        return
    end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return
    end

    isTogglingSwitchblade = true
    switchbladeState.lastToggle = GetGameTimer()

    if not switchbladeState.deployed then
        DeleteSwitchbladeProp()
        RemoveWeaponFromPed(ped, HASH_KNUCKLE)
        SetPedCurrentWeaponVisible(ped, true, false, false, false)

        switchbladeState.deployed = true
        GiveWeaponToPed(ped, HASH_SWITCHBLADE, 1, false, false)
        SetCurrentPedWeapon(ped, HASH_SWITCHBLADE, false)
        TriggerEvent('DP-Inventory:client:SetCurrentWeapon', switchbladeState.itemData, true)

        Wait(50)
        SetCurrentPedWeapon(ped, HASH_SWITCHBLADE, true)
    else
        switchbladeState.deployed = false
        LoadAnimDict('anim@melee@switchblade@holster')
        TaskPlayAnim(ped, 'anim@melee@switchblade@holster', 'holster', 8.0, 3.0, 500, 48, 0, false, false, false)
        Wait(250)

        RemoveWeaponFromPed(ped, HASH_SWITCHBLADE)
        TriggerEvent('DP-Inventory:client:SetCurrentWeapon', nil, true)

        SetCurrentPedWeapon(ped, HASH_UNARMED, true)
        Wait(50)
        EquipClosedFist(ped)
        AttachClosedSwitchblade()
        Wait(50)
        EquipClosedFist(ped)
    end

    switchbladeState.lastToggle = GetGameTimer()
    isTogglingSwitchblade = false
end, false)

RegisterKeyMapping('toggleSwitchblade', 'Desplegar/Recoger hoja de navaja', 'keyboard', 'G')

CreateThread(function()
    local textUiShown = false
    local lastDeployedState = nil
    local idKey = 'switchblade_action'

    while true do
        local sleep = 500
        if switchbladeState and switchbladeState.holding then
            sleep = 200
            local msg = switchbladeState.deployed and 'Recoger hoja' or 'Desplegar hoja'

            if not textUiShown or lastDeployedState ~= switchbladeState.deployed then
                exports['DP-Hud']:MostrarUI(idKey, msg, 'G', false)
                textUiShown = true
                lastDeployedState = switchbladeState.deployed
            end
        else
            if textUiShown then
                exports['DP-Hud']:OcultarUI(idKey)
                textUiShown = false
                lastDeployedState = nil
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(500)
        if switchbladeState.holding and (GetGameTimer() - switchbladeState.lastToggle > 1000) then
            local ped = PlayerPedId()
            local currentWeap = GetSelectedPedWeapon(ped)

            if not HasItem('weapon_switchblade', 1) or IsEntityDead(ped) then
                HolsterSwitchblade(false)
            elseif not switchbladeState.deployed then
                if currentWeap == HASH_KNUCKLE then
                    SetPedCurrentWeaponVisible(ped, false, false, false, false)
                elseif currentWeap == HASH_UNARMED then
                    if not IsPedInAnyVehicle(ped, false) then
                        EquipClosedFist(ped)
                    end
                else
                    HolsterSwitchblade(true)
                end
            elseif switchbladeState.deployed and currentWeap ~= HASH_SWITCHBLADE and currentWeap ~= HASH_UNARMED then
                HolsterSwitchblade(true)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if GetResourceState('DP-Hud') == 'started' then
        local textUIs = {'drop_abrir', 'drop_recoger', 'drop_soltar', 'vending_usar', 'switchblade_action',
                         'stash_pruebas_ui'}
        for _, id in ipairs(textUIs) do
            exports['DP-Hud']:OcultarUI(id)
        end
    end

    if switchbladeState and switchbladeState.holding then
        local ped = PlayerPedId()
        if switchbladeState.prop and DoesEntityExist(switchbladeState.prop) then
            DetachEntity(switchbladeState.prop, true, true)
            SetEntityAsMissionEntity(switchbladeState.prop, true, true)
            DeleteEntity(switchbladeState.prop)
        end
        RemoveWeaponFromPed(ped, HASH_KNUCKLE)
        RemoveWeaponFromPed(ped, HASH_SWITCHBLADE)
        SetPedCurrentWeaponVisible(ped, true, false, false, false)
        SetCurrentPedWeapon(ped, HASH_UNARMED, true)
    end
end)

exports('OpenPlayerInventory', function(targetId)
    if not targetId then
        return
    end
    TriggerServerEvent("DP-Inventory:server:OpenInventory", "otherplayer", targetId)
end)

exports('OpenStash', function(targetId)
    if not targetId then
        return
    end
    TriggerServerEvent("DP-Inventory:server:ForceOpenStash", targetId)
end)

CreateThread(function()
    local testStashes = {{
        id = 'stash_pruebas',
        uiText = 'Abrir Armario (50 slots)',
        coords = vector4(130.7, -625.91, 262.85, 359.2)
    }, {
        id = 'stash_pruebas_peque',
        uiText = 'Abrir Armario (2 filas)',
        coords = vector4(132.0, -625.91, 262.85, 359.2)
    }}

    local model = joaat('p_cs_locker_01_s')
    local spawnedProps = {}

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    for _, stash in ipairs(testStashes) do
        local prop = CreateObject(model, stash.coords.x, stash.coords.y, stash.coords.z - 1.0, false, false, false)
        SetEntityHeading(prop, stash.coords.w)
        PlaceObjectOnGroundProperly(prop)
        FreezeEntityPosition(prop, true)
        spawnedProps[#spawnedProps + 1] = prop
    end
    SetModelAsNoLongerNeeded(model)

    AddEventHandler('onResourceStop', function(res)
        if res == GetCurrentResourceName() then
            for _, prop in ipairs(spawnedProps) do
                if DoesEntityExist(prop) then
                    DeleteEntity(prop)
                end
            end
        end
    end)

    local currentShownId = nil
    while true do
        local sleep = 1000
        local pedCoords = GetEntityCoords(PlayerPedId())
        local closestStash = nil
        local closestDist = 2.0

        if not LocalPlayer.state.inv_busy then
            for _, stash in ipairs(testStashes) do
                local dist = #(pedCoords - vector3(stash.coords.x, stash.coords.y, stash.coords.z))
                if dist < closestDist then
                    closestDist = dist
                    closestStash = stash
                end
            end
        end

        if closestStash then
            sleep = 0
            if currentShownId ~= closestStash.id then
                exports['DP-Hud']:MostrarUI('stash_pruebas_ui', closestStash.uiText, 'E', false)
                currentShownId = closestStash.id
            end

            if IsControlJustPressed(0, 38) then
                exports['DP-Hud']:OcultarUI('stash_pruebas_ui')
                currentShownId = nil
                TriggerServerEvent('DP-Inventory:server:OpenTestStash', closestStash.id)
                Wait(500)
            end
        elseif currentShownId then
            exports['DP-Hud']:OcultarUI('stash_pruebas_ui')
            currentShownId = nil
        end

        Wait(sleep)
    end
end)
