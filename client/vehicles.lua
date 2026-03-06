-- ==========================================
-- VARIABLES GLOBALES DEL ARCHIVO
-- ==========================================
local hashedBackEngine = {}
local forceOpenTrunk = false -- NUESTRO INTERRUPTOR MÁGICO

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

-- ==========================================
-- FUNCIONES
-- ==========================================
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

-- ==========================================
-- CALLBACKS (Lógica de Apertura Separada)
-- ==========================================
QBCore.Functions.CreateClientCallback('DP-Inventory:client:vehicleCheck', function(cb)
    local ped = PlayerPedId()

    -- 1. GUANTERA: Si estás dentro del coche, F2 abre la guantera siempre.
    local inVehicle = GetVehiclePedIsIn(ped, false)
    if inVehicle ~= 0 then
        local plate = GetVehicleNumberPlateText(inVehicle)
        local class = GetVehicleClass(inVehicle)
        local inventory = 'glovebox-' .. plate
        cb(inventory, class)
        return
    end

    -- 2. MALETERO: Solo se activa si hemos pulsado la 'E' en el TextUI
    if forceOpenTrunk then
        forceOpenTrunk = false -- Apagamos el interruptor inmediatamente

        local vehicle, distance = QBCore.Functions.GetClosestVehicle()
        if vehicle ~= 0 and distance < 5 then
            local pos = GetEntityCoords(ped)
            local vehModel = GetEntityModel(vehicle)
            local dimensionMin, dimensionMax = GetModelDimensions(vehModel)

            local trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, dimensionMin.y, 0.0)
            if IsBackEngine(vehModel) then
                trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, dimensionMax.y, 0.0)
            end

            -- Igualamos a 2.0 para que tenga la misma distancia que el TextUI
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

    -- 3. INVENTARIO PERSONAL: Si pulsas F2 en la calle (y forceOpenTrunk es false), devuelve nil.
    -- Esto hace que el servidor abra tus bolsillos normales.
    cb(nil)
end)

-- ==========================================
-- DP-TEXTUI (Proximidad del Maletero)
-- ==========================================
local inTrunkZone = false

CreateThread(function()
    local actionCooldown = 0

    while true do
        local waitTime = 1000
        local ped = PlayerPedId()

        -- Si no está en el coche y el inventario NO está ocupado
        if not IsPedInAnyVehicle(ped, false) and not LocalPlayer.state.inv_busy then
            local pos = GetEntityCoords(ped)
            local vehicle, distance = QBCore.Functions.GetClosestVehicle()

            if vehicle ~= 0 and distance < 5.0 then
                local vehModel = GetEntityModel(vehicle)
                local dimensionMin, dimensionMax = GetModelDimensions(vehModel)

                -- Por defecto asumimos motor delantero (puerta 5)
                local trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, dimensionMin.y, 0.0)
                local doorIndex = 5

                -- Si tiene el motor trasero, cambiamos a la puerta delantera (puerta 4)
                if IsBackEngine(vehModel) then
                    trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, dimensionMax.y, 0.0)
                    doorIndex = 4
                end

                if #(pos - trunkpos) < 2.0 then
                    waitTime = 0

                    -- Comprobamos si el coche está abierto Y si el maletero está físicamente CERRADO (< 0.1 de ángulo por si hay desajustes milimétricos en la animación)
                    local isTrunkClosed = GetVehicleDoorAngleRatio(vehicle, doorIndex) < 0.1

                    if GetVehicleDoorLockStatus(vehicle) < 2 and isTrunkClosed then
                        if not inTrunkZone then
                            exports['DP-TextUI']:MostrarUI('trunk_open', 'Abrir Maletero', 'E', false)
                            inTrunkZone = true
                        end

                        if IsControlJustPressed(0, 38) and GetGameTimer() > actionCooldown then
                            exports['DP-TextUI']:OcultarUI('trunk_open')
                            inTrunkZone = false

                            forceOpenTrunk = true
                            ExecuteCommand('inventory')

                            actionCooldown = GetGameTimer() + 1500
                        end
                    else
                        -- Si está cerrado con llave O el maletero ya está abierto
                        if inTrunkZone then
                            exports['DP-TextUI']:OcultarUI('trunk_open')
                            inTrunkZone = false
                        end
                    end
                else
                    if inTrunkZone then
                        exports['DP-TextUI']:OcultarUI('trunk_open')
                        inTrunkZone = false
                    end
                end
            else
                if inTrunkZone then
                    exports['DP-TextUI']:OcultarUI('trunk_open')
                    inTrunkZone = false
                end
            end
        else
            if inTrunkZone then
                exports['DP-TextUI']:OcultarUI('trunk_open')
                inTrunkZone = false
            end
        end

        Wait(waitTime)
    end
end)
