-- DP-Inventory · client/vehicles.lua
-- Maleteros y guanteras de vehículos.

local hashedBackEngine = {}
local forceOpenTrunk = false

CreateThread(function()
    if BackEngineVehicles then
        for k, _ in pairs(BackEngineVehicles) do
            if type(k) == 'string' then
                hashedBackEngine[joaat(k)] = true
            else
                hashedBackEngine[k] = true
            end
        end
    end
end)

local function IsBackEngine(vehModel)
    return hashedBackEngine[vehModel] or false
end

local function OpenTrunk(vehicle)
    LoadAnimDict('amb@prop_human_bum_bin@idle_b')
    TaskPlayAnim(PlayerPedId(), 'amb@prop_human_bum_bin@idle_b', 'idle_d', 4.0, 4.0, -1, 50, 0, false, false, false)
    if IsBackEngine(GetEntityModel(vehicle)) then
        SetVehicleDoorOpen(vehicle, 4, false, false)
    else
        SetVehicleDoorOpen(vehicle, 5, false, false)
    end
end

function CloseTrunk()
    local vehicle, distance = QBCore.Functions.GetClosestVehicle()
    if vehicle == 0 or distance > 5 then
        return
    end
    LoadAnimDict('amb@prop_human_bum_bin@idle_b')
    TaskPlayAnim(PlayerPedId(), 'amb@prop_human_bum_bin@idle_b', 'exit', 4.0, 4.0, -1, 50, 0, false, false, false)
    if IsBackEngine(GetEntityModel(vehicle)) then
        SetVehicleDoorShut(vehicle, 4, false)
    else
        SetVehicleDoorShut(vehicle, 5, false)
    end
end

QBCore.Functions.CreateClientCallback('DP-Inventory:client:vehicleCheck', function(cb)
    local ped = PlayerPedId()

    local inVehicle = GetVehiclePedIsIn(ped, false)
    if inVehicle ~= 0 then
        local plate = GetVehicleNumberPlateText(inVehicle)
        local class = GetVehicleClass(inVehicle)
        local inventory = 'glovebox-' .. plate
        cb(inventory, class)
        return
    end

    if forceOpenTrunk then
        forceOpenTrunk = false

        local vehicle, distance = QBCore.Functions.GetClosestVehicle()
        if vehicle ~= 0 and distance < 5 then
            local pos = GetEntityCoords(ped)
            local vehModel = GetEntityModel(vehicle)
            local dimensionMin, dimensionMax = GetModelDimensions(vehModel)

            local trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, dimensionMin.y, 0.0)
            if IsBackEngine(vehModel) then
                trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, dimensionMax.y, 0.0)
            end

            if #(pos - trunkpos) < 2.0 then
                if GetVehicleDoorLockStatus(vehicle) < 2.0 then
                    OpenTrunk(vehicle)
                    local class = GetVehicleClass(vehicle)
                    local plate = GetVehicleNumberPlateText(vehicle)
                    local inventory = 'trunk-' .. plate
                    cb(inventory, class)
                    return
                else
                    QBCore.Functions.Notify(Lang:t('notify.vlocked') or 'Vehículo bloqueado', 'error')
                    cb(nil)
                    return
                end
            end
        end
    end

    cb(nil)
end)

local inTrunkZone = false

CreateThread(function()
    local actionCooldown = 0

    while true do
        local waitTime = 1000
        local ped = PlayerPedId()

        if not IsPedInAnyVehicle(ped, false) and not LocalPlayer.state.inv_busy then
            local pos = GetEntityCoords(ped)
            local vehicle, distance = QBCore.Functions.GetClosestVehicle()

            if vehicle ~= 0 and distance < 5.0 then
                local vehModel = GetEntityModel(vehicle)
                local dimensionMin, dimensionMax = GetModelDimensions(vehModel)

                local trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, dimensionMin.y, 0.0)
                local doorIndex = 5

                if IsBackEngine(vehModel) then
                    trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, dimensionMax.y, 0.0)
                    doorIndex = 4
                end

                if #(pos - trunkpos) < 2.0 then
                    waitTime = 0

                    local isTrunkClosed = GetVehicleDoorAngleRatio(vehicle, doorIndex) < 0.1

                    if GetVehicleDoorLockStatus(vehicle) < 2 and isTrunkClosed then
                        if not inTrunkZone then
                            exports['DP-Hud']:MostrarUI('trunk_open', 'Abrir Maletero', 'E', false)
                            inTrunkZone = true
                        end

                        if IsControlJustPressed(0, 38) and GetGameTimer() > actionCooldown then
                            exports['DP-Hud']:OcultarUI('trunk_open')
                            inTrunkZone = false
                            forceOpenTrunk = true
                            ExecuteCommand('inventory')
                            actionCooldown = GetGameTimer() + 1500
                        end
                    else
                        if inTrunkZone then
                            exports['DP-Hud']:OcultarUI('trunk_open')
                            inTrunkZone = false
                        end
                    end
                else
                    if inTrunkZone then
                        exports['DP-Hud']:OcultarUI('trunk_open')
                        inTrunkZone = false
                    end
                end
            else
                if inTrunkZone then
                    exports['DP-Hud']:OcultarUI('trunk_open')
                    inTrunkZone = false
                end
            end
        else
            if inTrunkZone then
                exports['DP-Hud']:OcultarUI('trunk_open')
                inTrunkZone = false
            end
        end

        Wait(waitTime)
    end
end)
