QBCore = exports['qb-core']:GetCoreObject()
PlayerData = nil
local hotbarShown = false
local inVendingZone = false
local isInventoryOpen = false
local currentAimStyle = joaat("Default")
local isHolstering = false
local holsterTimer = nil

-- Handlers

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set('inv_busy', false, true)
    PlayerData = QBCore.Functions.GetPlayerData()
    GetDrops()
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
end)

-- Functions

function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then
        return
    end

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

-- Mapea el attachmentType del config de qb-weapons al tipo de slot del panel WIP
-- Los nombres EXACTOS vienen del config.lua de qb-weapons (WeaponAttachments keys)
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
    return 'flashlight' -- fallback al slot Accessory
end

local function FormatWeaponAttachments(itemdata)
    if not itemdata.info or not itemdata.info.attachments or #itemdata.info.attachments == 0 then
        return {}
    end
    local attachments = {}
    local weaponName = itemdata.name
    local WeaponAttachments = exports['qb-weapons']:getConfigWeaponAttachments()
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
                        slotType = GetAttachmentSlotType(attachmentType) -- NUEVO: tipo de slot para el panel
                    }
                end
            end
        end
    end
    return attachments
end

--- Checks if the player has a certain item or items in their inventory with a specified amount.
--- @param items string|table - The item(s) to check for. Can be a table of items or a single item as a string.
--- @param amount number [optional] - The minimum amount required for each item. If not provided, any amount greater than 0 will be considered.
--- @return boolean - Returns true if the player has the item(s) with the specified amount, false otherwise.
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
            else -- Single item as string
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

-- Events

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

    SendNUIMessage({
        action = 'update',
        inventory = items
    })
end)

RegisterNetEvent('DP-Inventory:client:ItemBox', function(itemData, type, amount)
    SendNUIMessage({
        action = 'itemBox',
        item = itemData,
        type = type,
        amount = amount
    })
end)

RegisterNetEvent('DP-Inventory:server:RobPlayer', function(TargetId)
    SendNUIMessage({
        action = 'RobMoney',
        TargetId = TargetId
    })
end)

RegisterNetEvent('DP-Inventory:client:openInventory', function(items, other)
    SetNuiFocus(true, true)
    isInventoryOpen = true

    local charName = "INVENTARIO"
    if PlayerData and PlayerData.charinfo then
        charName = PlayerData.charinfo.firstname .. ' ' .. PlayerData.charinfo.lastname
    end

    -- COMPROBACIÓN DE VEHÍCULO (Piloto)
    local ped = PlayerPedId()
    local isDriver = false
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
        isDriver = true
    end

    SendNUIMessage({
        action = 'open',
        inventory = items,
        slots = Config.MaxSlots,
        maxweight = Config.MaxWeight,
        other = other,
        playerName = charName,
        isDriver = isDriver
    })

    -- Vigila si te sacan del coche con el inventario abierto
    CreateThread(function()
        while isInventoryOpen do
            Wait(500) -- Comprueba cada medio segundo
            local currentPed = PlayerPedId()
            local inVehicle = IsPedInAnyVehicle(currentPed, false)
            local currentVeh = GetVehiclePedIsIn(currentPed, false)
            local currentlyDriver = (currentVeh ~= 0 and GetPedInVehicleSeat(currentVeh, -1) == currentPed)

            -- Si estabas en un coche y te bajas, o estabas de piloto y te cambias de asiento:
            if not inVehicle or not currentlyDriver then
                SendNUIMessage({
                    action = 'checkVehicleState',
                    inVehicle = inVehicle,
                    isDriver = currentlyDriver
                })
            end
        end
    end)
end)

RegisterNetEvent('DP-Inventory:client:giveAnim', function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        return
    end
    LoadAnimDict('mp_common')
    TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_b', 8.0, 1.0, -1, 16, 0, false, false, false)
end)

-- NUI Callbacks

RegisterNUICallback('PlayDropFail', function(_, cb)
    PlaySound(-1, 'Place_Prop_Fail', 'DLC_Dmod_Prop_Editor_Sounds', 0, 0, 1)
    cb('ok')
end)

RegisterNUICallback('AttemptPurchase', function(data, cb)
    QBCore.Functions.TriggerCallback('DP-Inventory:server:attemptPurchase', function(canPurchase)
        cb(canPurchase)
    end, data)
end)

RegisterNUICallback('CloseInventory', function(data, cb)
    SetNuiFocus(false, false)
    isInventoryOpen = false

    if data.name then
        if data.name:find('trunk-') then
            CloseTrunk()
        end
        TriggerServerEvent('DP-Inventory:server:closeInventory', data.name)
    elseif CurrentDrop then
        TriggerServerEvent('DP-Inventory:server:closeInventory', CurrentDrop)
        CurrentDrop = nil
    end
    cb('ok')
end)

RegisterNUICallback('UseItem', function(data, cb)
    -- Si es un arma, damos tiempo para que se cierre la UI
    if data.item and data.item.type == "weapon" then
        -- Pequeño delay para asegurar que la UI se cierra primero
        Citizen.SetTimeout(100, function()
            TriggerServerEvent('DP-Inventory:server:useItem', data.item)
        end)
    else
        -- Para items normales, comportamiento habitual
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
        -- Ya no buscamos al más cercano, usamos el ID que el jugador ha seleccionado en el NUI
        QBCore.Functions.TriggerCallback('DP-Inventory:server:giveItem', function(success)
            cb(success)
        end, data.target, data.item.name, data.amount, data.slot, data.info)
    else
        QBCore.Functions.Notify('No se ha seleccionado a ningún jugador.', 'error')
        cb(false)
    end
end)

-- Callback para obtener jugadores a 10 metros y pedir sus NOMBRES REALES al servidor
RegisterNUICallback('GetNearbyPlayers', function(_, cb)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local activePlayers = QBCore.Functions.GetPlayersFromCoords(playerCoords, 10.0)
    local serverIds = {}

    -- Recopilamos las IDs de servidor de todos los que están cerca (menos nosotros)
    for _, player in pairs(activePlayers) do
        if player ~= PlayerId() then
            table.insert(serverIds, GetPlayerServerId(player))
        end
    end

    -- Si hay alguien cerca, le preguntamos al Servidor cómo se llaman sus personajes
    if #serverIds > 0 then
        QBCore.Functions.TriggerCallback('DP-Inventory:server:GetPlayerNames', function(playersData)
            cb(playersData)
        end, serverIds)
    else
        cb({}) -- Si no hay nadie, devolvemos array vacío
    end
end)

-- Callback para notificaciones directas desde el NUI
RegisterNUICallback('Notify', function(data, cb)
    QBCore.Functions.Notify(data.message, data.type)
    cb('ok')
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
    local allAttachments = exports['qb-weapons']:getConfigWeaponAttachments()
    local Attachment = allAttachments[data.AttachmentData.attachment][WeaponData.name]
    local itemInfo = QBCore.Shared.Items[data.AttachmentData.attachment]
    QBCore.Functions.TriggerCallback('qb-weapons:server:RemoveAttachment', function(NewAttachments)
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
                            slotType = GetAttachmentSlotType(attachmentType) -- NUEVO
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

-- NUEVO: Equipar un accesorio arrastrándolo desde el inventario al panel WIP
RegisterNUICallback('AddAttachment', function(data, cb)
    local ped = PlayerPedId()
    local WeaponData = data.WeaponData
    local AttachmentItem = data.AttachmentItem
    local allAttachments = exports['qb-weapons']:getConfigWeaponAttachments()

    -- Validación rápida en cliente antes de ir al servidor
    local weaponComponent = allAttachments[AttachmentItem.name] and allAttachments[AttachmentItem.name][WeaponData.name]
    if not weaponComponent then
        cb({
            success = false
        })
        return
    end

    QBCore.Functions.TriggerCallback('qb-weapons:server:AddAttachment', function(result)
        if not result or result.success == false then
            cb({
                success = false
            })
            return
        end

        -- Si el jugador tiene el arma en la mano en este momento, aplicar el componente visualmente
        local currentWeapon = GetSelectedPedWeapon(ped)
        if currentWeapon == joaat(WeaponData.name) then
            GiveWeaponComponentToPed(ped, joaat(WeaponData.name), joaat(weaponComponent))
        end

        -- Reconstruir la lista de accesorios con slotType a partir de los attachments actualizados
        -- que devuelve el servidor (result.attachments = weaponSlot.info.attachments)
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

    -- SISTEMA DE ROPA (Menú de interacciones)
    if action == 'ropa_sombrero' then
        ExecuteCommand('hat')

    elseif action == 'ropa_gafas' then
        ExecuteCommand('glasses')

    elseif action == 'ropa_mascara' then
        ExecuteCommand('mask')

    elseif action == 'ropa_cabello' then
        ExecuteCommand('hair')

    elseif action == 'ropa_cambiar_cabello' then
        QBCore.Functions.Notify('¡Esto estará disponible PROXIMAMENTE!', 'error', 5000)

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

    elseif action == 'aim_default' then
        currentAimStyle = joaat("Default")
        LocalPlayer.state:set('aimStyle', currentAimStyle, true) -- Enviamos a la red
        SetWeaponAnimationOverride(PlayerPedId(), currentAimStyle)
        QBCore.Functions.Notify("Estilo de apuntado: Normal", "success")

    elseif action == 'aim_gangster' then
        currentAimStyle = joaat("Gang1H")
        LocalPlayer.state:set('aimStyle', currentAimStyle, true) -- Enviamos a la red
        SetWeaponAnimationOverride(PlayerPedId(), currentAimStyle)
        QBCore.Functions.Notify("Estilo de apuntado: Gangster", "success")

    elseif action == 'aim_cowboy' then
        currentAimStyle = joaat("Hillbilly")
        LocalPlayer.state:set('aimStyle', currentAimStyle, true) -- Enviamos a la red
        SetWeaponAnimationOverride(PlayerPedId(), currentAimStyle)
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
    end

    cb('ok')
end)

RegisterNUICallback('CloseSecondaryInventory', function(data, cb)
    -- A diferencia del CloseInventory normal, este NO tiene SetNuiFocus(false, false).
    -- Así el servidor sabe que ya no miras la guantera, pero tú conservas el ratón.
    if data.name then
        TriggerServerEvent('DP-Inventory:server:closeInventory', data.name)
    end
    cb('ok')
end)

-- Callback para enfundar el arma cuando se arrastra un arma en el inventario
RegisterNUICallback('HolsterWeapon', function(data, cb)
    local ped = PlayerPedId()

    -- Prevenir ejecuciones múltiples en un corto período de tiempo
    if isHolstering then
        cb('ok')
        return
    end

    -- Verificar si el jugador tiene un arma en la mano actualmente
    local currentWeapon = GetSelectedPedWeapon(ped)

    -- Solo proceder si tiene un arma (no es puño)
    if currentWeapon ~= 0 and currentWeapon ~= joaat('WEAPON_UNARMED') then
        -- Marcar que estamos en proceso de holstering
        isHolstering = true

        -- Detener cualquier tarea actual
        ClearPedTasks(ped)

        -- Forzar al ped a enfundar el arma
        SetPedCurrentWeaponVisible(ped, false, false, false, false)
        SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)

        -- Pequeña animación de guardado si no está en vehículo
        if not IsPedInAnyVehicle(ped, false) then
            LoadAnimDict('reaction@intimidation@1h')
            TaskPlayAnim(ped, 'reaction@intimidation@1h', 'outro', 8.0, 1.0, 1000, 48, 0, false, false, false)
        end

        -- Notificar al jugador que el arma se ha guardado (SOLO UNA VEZ)
        QBCore.Functions.Notify('Arma guardada automáticamente', 'primary')

        -- Resetear el flag después de un tiempo (para permitir futuros holsters)
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

-- Vending (Adaptado a DP-TextUI y Optimizado)

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
        local closestDistance = 2.5 -- Radio de búsqueda

        if not LocalPlayer.state.inv_busy then
            -- Iterar sobre hashes específicos es mucho más óptimo que escanear todos los objetos
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
                exports['DP-TextUI']:MostrarUI('vending_usar', Lang:t('menu.vending') or 'Usar Máquina', 'E', false)
                inVendingZone = true
            end

            if IsControlJustPressed(0, 38) then -- Tecla E
                exports['DP-TextUI']:OcultarUI('vending_usar')
                inVendingZone = false

                TriggerServerEvent('DP-Inventory:server:openVending', {
                    entity = nearestVendingObject,
                    coords = nearestVendingCoords
                })

                Wait(1000)
            end
        elseif inVendingZone and not isNearVending then
            exports['DP-TextUI']:OcultarUI('vending_usar')
            inVendingZone = false
        end

        Wait(waitTime)
    end
end)

-- Commands

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
        -- Notificar al NUI qué slot está activo para el glow
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

-- GUARDIÁN DE ESTILOS DE APUNTADO (Híbrido: Local + Red) OPTIMIZADO Y SIN CONFLICTOS
local appliedAimStyles = {}
local lastWeapons = {}
local equipTimers = {}

CreateThread(function()
    while true do
        Wait(500) -- Comprueba 2 veces por segundo
        local myPed = PlayerPedId()
        local myId = PlayerId()

        -- 1. TU PROPIO GUARDIÁN
        local currentWeapon = GetSelectedPedWeapon(myPed)

        -- Detectamos si acabas de cambiar de arma (o sacarla)
        if lastWeapons[myId] ~= currentWeapon then
            lastWeapons[myId] = currentWeapon
            equipTimers[myId] = GetGameTimer() -- Empezamos a contar
            appliedAimStyles[myId] = nil -- Reseteamos para que se aplique la nueva
        end

        -- Si tenemos un arma en la mano (que no sea el puño)
        if currentWeapon ~= 'WEAPON_UNARMED' and currentWeapon ~= 0 then
            local stateKey = tostring(currentAimStyle) .. "_" .. tostring(currentWeapon)

            if appliedAimStyles[myId] ~= stateKey then
                -- Esperamos 1.5 segundos desde que empieza a sacarla para no cortar la animación de qb-weapons
                if GetGameTimer() - (equipTimers[myId] or 0) > 1500 then
                    SetWeaponAnimationOverride(myPed, currentAimStyle)
                    appliedAimStyles[myId] = stateKey
                end
            end
        end

        -- 2. GUARDIÁN PARA LOS DEMÁS JUGADORES (Sincronización de red)
        for _, player in ipairs(GetActivePlayers()) do
            if player ~= myId then
                local targetPed = GetPlayerPed(player)

                if targetPed ~= 0 then
                    local targetWeapon = GetSelectedPedWeapon(targetPed)

                    -- Si el jugador cambia de arma
                    if lastWeapons[player] ~= targetWeapon then
                        lastWeapons[player] = targetWeapon
                        equipTimers[player] = GetGameTimer()
                        appliedAimStyles[player] = nil
                    end

                    if targetWeapon ~= 'WEAPON_UNARMED' and targetWeapon ~= 0 then
                        local serverId = GetPlayerServerId(player)
                        local targetAimStyle = Player(serverId).state.aimStyle

                        if targetAimStyle then
                            local targetStateKey = tostring(targetAimStyle) .. "_" .. tostring(targetWeapon)

                            if appliedAimStyles[player] ~= targetStateKey then
                                -- Damos 1.5s de margen a los demás jugadores también
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
