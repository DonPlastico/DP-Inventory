HoldingDrop = false
local bagObject = nil
local heldDrop = nil
CurrentDrop = nil

-- Variables para gestionar los TextUIs y las zonas
local activeDrops = {}
local inDropZone = false
local nearestDropData = nil -- Variable global para conectar los dos hilos

-- Functions
function GetDrops()
    QBCore.Functions.TriggerCallback('DP-Inventory:server:GetCurrentDrops', function(drops)
        if not drops then
            activeDrops = {}
            return
        end
        activeDrops = drops
    end)
end

-- Función auxiliar para la animación inmersiva
local function PlayPickupAnimation()
    local ped = PlayerPedId()
    local dict = "pickup_object"
    local anim = "pickup_low"

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end

    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 48, 0, false, false, false)
    Wait(700) -- Esperamos al momento exacto en el que la mano toca el suelo
    ClearPedTasks(ped)
end

-- Events
RegisterNetEvent('DP-Inventory:client:removeDropTarget', function(dropId)
    GetDrops()
end)

RegisterNetEvent('DP-Inventory:client:setupDropTarget', function(dropId)
    GetDrops()
end)

-- NUI Callbacks
RegisterNUICallback('DropItem', function(item, cb)
    QBCore.Functions.TriggerCallback('DP-Inventory:server:createDrop', function(dropId)
        if dropId then
            while not NetworkDoesNetworkIdExist(dropId) do
                Wait(10)
            end
            local bag = NetworkGetEntityFromNetworkId(dropId)
            SetModelAsNoLongerNeeded(bag)
            PlaceObjectOnGroundProperly(bag)
            FreezeEntityPosition(bag, true)
            local newDropId = 'drop-' .. dropId
            cb(newDropId)
        else
            cb(false)
        end
    end, item)
end)

-- THREAD 1: Escáner de Proximidad (Bucle lento, bajo consumo)
CreateThread(function()
    while true do
        Wait(500) -- Escanea el entorno solo 2 veces por segundo

        if not HoldingDrop then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local tempNearest = nil
            local nearestDistance = 2.5

            for k, v in pairs(activeDrops) do
                -- Comprobamos si el ID existe en el cliente antes de llamarlo
                if NetworkDoesNetworkIdExist(v.entityId) then
                    local bag = NetworkGetEntityFromNetworkId(v.entityId)

                    if DoesEntityExist(bag) then
                        local bagCoords = GetEntityCoords(bag)
                        local distance = #(playerCoords - bagCoords)

                        if distance <= nearestDistance then
                            nearestDistance = distance
                            tempNearest = {
                                id = k,
                                entityId = v.entityId,
                                bag = bag
                            }
                        end
                    end
                end
            end
            -- Actualizamos la variable para el hilo principal
            nearestDropData = tempNearest
        else
            nearestDropData = nil
        end
    end
end)

-- THREAD 2: Interacción y TextUI (Bucle rápido bajo demanda)
CreateThread(function()
    local actionCooldown = 0
    local currentDropId = nil -- Para saber qué bolsa estamos mirando

    while true do
        local waitTime = 1000
        local playerPed = PlayerPedId()

        -- Lógica si estamos cerca de una bolsa y NO la tenemos en la mano
        if nearestDropData and not HoldingDrop then
            waitTime = 0

            -- SISTEMA DE SEGURIDAD: Evita que el UI se quede pillado si la bolsa desaparece mágicamente
            if not DoesEntityExist(nearestDropData.bag) then
                if inDropZone then
                    exports['DP-TextUI']:OcultarUI('drop_abrir')
                    exports['DP-TextUI']:OcultarUI('drop_recoger')
                    inDropZone = false
                end
                nearestDropData = nil
                goto continue
            end

            -- Mostrar UIs si entramos en la zona o cambiamos de bolsa
            if not inDropZone or currentDropId ~= nearestDropData.id then
                if inDropZone then
                    exports['DP-TextUI']:OcultarUI('drop_abrir')
                    exports['DP-TextUI']:OcultarUI('drop_recoger')
                end

                exports['DP-TextUI']:MostrarUI('drop_abrir', 'Abrir bolsa', 'E', false)
                exports['DP-TextUI']:MostrarUI('drop_recoger', 'Recoger bolsa', 'G', false)

                inDropZone = true
                currentDropId = nearestDropData.id
            end

            -- Interacciones
            if IsControlJustPressed(0, 38) then -- Tecla E: Abrir
                local newDropId = type(nearestDropData.id) == "string" and string.match(nearestDropData.id, "drop-") and
                                      nearestDropData.id or 'drop-' .. nearestDropData.entityId

                -- Pedimos permiso al servidor ANTES de dar por hecho que la hemos abierto
                QBCore.Functions.TriggerCallback('DP-Inventory:server:requestOpenDrop', function(canOpen)
                    if canOpen then
                        CurrentDrop = newDropId
                    else
                        QBCore.Functions.Notify("Alguien ya está interactuando con esta bolsa", "error")
                    end
                end, newDropId)

            elseif IsControlJustPressed(0, 47) and GetGameTimer() > actionCooldown then -- Tecla G: Recoger
                if IsPedArmed(playerPed, 4) then
                    QBCore.Functions.Notify("¡No puedes llevar un arma y una bolsa a la vez!", "error", 5500)
                else
                    local bag = nearestDropData.bag
                    local newDropId =
                        type(nearestDropData.id) == "string" and string.match(nearestDropData.id, "drop-") and
                            nearestDropData.id or 'drop-' .. nearestDropData.entityId

                    -- Preguntamos al servidor si podemos cogerla
                    QBCore.Functions.TriggerCallback('DP-Inventory:server:requestHoldDrop', function(canHold, reason)
                        if canHold then

                            -- Pedimos el control absoluto de la entidad a FiveM
                            NetworkRequestControlOfEntity(bag)
                            local timeout = 0
                            -- Esperamos hasta medio segundo para que el dueño original nos ceda el control a través de internet
                            while not NetworkHasControlOfEntity(bag) and timeout < 50 do
                                Wait(10)
                                NetworkRequestControlOfEntity(bag)
                                timeout = timeout + 1
                            end

                            PlayPickupAnimation() -- Reproducimos animación inmersiva

                            AttachEntityToEntity(bag, playerPed, GetPedBoneIndex(playerPed, Config.ItemDropObjectBone),
                                Config.ItemDropObjectOffset[1].x, Config.ItemDropObjectOffset[1].y,
                                Config.ItemDropObjectOffset[1].z, Config.ItemDropObjectOffset[2].x,
                                Config.ItemDropObjectOffset[2].y, Config.ItemDropObjectOffset[2].z, true, true, false,
                                true, 1, true)

                            bagObject = bag
                            HoldingDrop = true
                            heldDrop = newDropId
                            actionCooldown = GetGameTimer() + 1000

                            exports['DP-TextUI']:OcultarUI('drop_abrir')
                            exports['DP-TextUI']:OcultarUI('drop_recoger')
                            inDropZone = false
                            currentDropId = nil

                            exports['DP-TextUI']:MostrarUI('drop_soltar', 'Soltar bolsa', 'G', false)
                        else
                            QBCore.Functions.Notify("Alguien ya está interactuando con esta bolsa", "error")
                        end
                    end, newDropId)
                end
            end

            -- Si salimos de la zona de la bolsa
        elseif inDropZone and not nearestDropData then
            exports['DP-TextUI']:OcultarUI('drop_abrir')
            exports['DP-TextUI']:OcultarUI('drop_recoger')
            inDropZone = false
            currentDropId = nil
        end

        -- Lógica independiente para cuando llevamos la bolsa encima
        if HoldingDrop then
            waitTime = 0
            if IsControlJustPressed(0, 47) and GetGameTimer() > actionCooldown then -- Tecla G: Soltar
                PlayPickupAnimation() -- Reproducimos animación para dejarla en el suelo

                DetachEntity(bagObject, true, true)
                local coords = GetEntityCoords(playerPed)
                local forward = GetEntityForwardVector(playerPed)
                local x, y, z = table.unpack(coords + forward * 0.57)

                SetEntityCoords(bagObject, x, y, z - 0.9, false, false, false, false)
                FreezeEntityPosition(bagObject, true)

                exports['DP-TextUI']:OcultarUI('drop_soltar')

                TriggerServerEvent('DP-Inventory:server:updateDrop', heldDrop, coords)

                HoldingDrop = false
                bagObject = nil
                heldDrop = nil
                actionCooldown = GetGameTimer() + 1000

                GetDrops()
            end
        end

        ::continue::
        Wait(waitTime)
    end
end)
