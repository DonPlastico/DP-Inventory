-- ============================================================
--  DP-INVENTORY · client/vehicles.lua
--  Sistema de maleteros y guanteras de vehículos.
--  Gestiona la detección de proximidad al maletero, la animación
--  de apertura/cierre, y el callback que decide qué inventario
--  abrir (guantera, maletero o inventario personal).
--
--  ÍNDICE DE CONTENIDOS
--  ─────────────────────────────────────────────────────────
--  [1]  VARIABLES GLOBALES
--  [2]  INICIALIZACIÓN – Hash de vehículos con motor trasero
--  [3]  FUNCIONES LOCALES
--         · IsBackEngine
--         · OpenTrunk
--  [4]  FUNCIÓN GLOBAL – CloseTrunk
--  [5]  CLIENT CALLBACK – vehicleCheck
--  [6]  THREAD – TextUI de proximidad al maletero
-- ============================================================
-- ============================================================
--  [1] VARIABLES GLOBALES
-- ============================================================
-- ==========================================
-- VARIABLES GLOBALES DEL ARCHIVO
-- ==========================================
local hashedBackEngine = {} -- Set de hashes de modelos de vehículos con motor trasero.
-- Poblado en el CreateThread de inicialización para lookup O(1).
local forceOpenTrunk = false -- "Interruptor mágico": se activa al pulsar E en el TextUI del maletero
-- y lo lee el callback vehicleCheck para saber si debe abrir el maletero.
-- Se desactiva inmediatamente tras ser consumido por el callback.

-- ============================================================
--  [2] INICIALIZACIÓN – Hash de vehículos con motor trasero
--  Se ejecuta al iniciar el recurso. Convierte los nombres de
--  la config (strings) a hashes numéricos para comparaciones
--  O(1) sin llamar a joaat() en cada frame.
-- ============================================================
CreateThread(function()
    if BackEngineVehicles then
        for k, _ in pairs(BackEngineVehicles) do
            if type(k) == 'string' then
                hashedBackEngine[joaat(k)] = true -- Convertimos el nombre a hash
            else
                hashedBackEngine[k] = true -- Ya era un hash numérico
            end
        end
    end
end)

-- ============================================================
--  [3] FUNCIONES LOCALES
-- ============================================================

--- Devuelve true si el modelo de vehículo dado tiene el motor en la parte trasera.
--- En GTA, los vehículos con motor trasero usan la puerta 4 (frontal) como maletero.
---
--- @param vehModel  number  Hash del modelo del vehículo
--- @return          boolean
-- ==========================================
-- FUNCIONES
-- ==========================================
local function IsBackEngine(vehModel)
    return hashedBackEngine[vehModel] or false
end

--- Reproduce la animación de abrir el maletero y abre físicamente la puerta correspondiente.
--- - Vehículos con motor trasero: abre la puerta 4 (frontal = motor trasero = cofre).
--- - Vehículos normales: abre la puerta 5 (maletero trasero).
---
--- @param vehicle  number  Handle de la entidad del vehículo
local function OpenTrunk(vehicle)
    LoadAnimDict('amb@prop_human_bum_bin@idle_b')
    TaskPlayAnim(PlayerPedId(), 'amb@prop_human_bum_bin@idle_b', 'idle_d', 4.0, 4.0, -1, 50, 0, false, false, false)
    if IsBackEngine(GetEntityModel(vehicle)) then
        SetVehicleDoorOpen(vehicle, 4, false, false) -- Motor trasero → abre puerta 4
    else
        SetVehicleDoorOpen(vehicle, 5, false, false) -- Motor delantero → abre puerta 5
    end
end

-- ============================================================
--  [4] FUNCIÓN GLOBAL – CloseTrunk
-- ============================================================

--- Cierra físicamente el maletero del vehículo más cercano (máx. 5 metros).
--- Reproduce la animación de cerrar y usa la puerta correcta según el tipo de motor.
--- Es GLOBAL para poder ser llamada desde otros archivos (ej: main_client.lua al cerrar el inventario).
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

-- ============================================================
--  [5] CLIENT CALLBACK – vehicleCheck
--  Decide qué inventario abrir cuando el jugador pulsa F2.
--  El servidor llama a este callback para saber qué inventario
--  debe abrir. Devuelve el identificador del inventario vía cb().
--
--  Prioridad de decisión:
--    1. Si está DENTRO de un vehículo  → Guantera ('glovebox-PLATE')
--    2. Si forceOpenTrunk es true      → Maletero  ('trunk-PLATE')
--    3. En cualquier otro caso         → nil (el servidor abre el inventario personal)
-- ============================================================

-- ==========================================
-- CALLBACKS (Lógica de Apertura Separada)
-- ==========================================
QBCore.Functions.CreateClientCallback('DP-Inventory:client:vehicleCheck', function(cb)
    local ped = PlayerPedId()

    -- ── CASO 1: GUANTERA ──
    -- Si el jugador está dentro de un vehículo, F2 siempre abre la guantera.
    local inVehicle = GetVehiclePedIsIn(ped, false)
    if inVehicle ~= 0 then
        local plate = GetVehicleNumberPlateText(inVehicle)
        local class = GetVehicleClass(inVehicle)
        local inventory = 'glovebox-' .. plate
        cb(inventory, class)
        return
    end

    -- ── CASO 2: MALETERO ──
    -- Solo se activa si el jugador pulsó E en el TextUI del maletero (forceOpenTrunk = true).
    if forceOpenTrunk then
        forceOpenTrunk = false -- Consumimos el interruptor inmediatamente para evitar doble apertura

        local vehicle, distance = QBCore.Functions.GetClosestVehicle()
        if vehicle ~= 0 and distance < 5 then
            local pos = GetEntityCoords(ped)
            local vehModel = GetEntityModel(vehicle)
            local dimensionMin, dimensionMax = GetModelDimensions(vehModel)

            -- Calculamos la posición del maletero según el tipo de motor
            local trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, dimensionMin.y, 0.0)
            if IsBackEngine(vehModel) then
                trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, dimensionMax.y, 0.0)
            end

            -- Distancia máxima de 2.0m: misma que el TextUI para consistencia
            if #(pos - trunkpos) < 2.0 then
                if GetVehicleDoorLockStatus(vehicle) < 2.0 then
                    OpenTrunk(vehicle)
                    local class = GetVehicleClass(vehicle)
                    local plate = GetVehicleNumberPlateText(vehicle)
                    local inventory = 'trunk-' .. plate
                    cb(inventory, class)
                    return
                else
                    -- Vehículo bloqueado → notificamos y devolvemos nil
                    QBCore.Functions.Notify(Lang:t('notify.vlocked') or 'Vehículo bloqueado', 'error')
                    cb(nil)
                    return
                end
            end
        end
    end

    -- ── CASO 3: INVENTARIO PERSONAL ──
    -- Ninguna condición especial → el servidor abrirá el inventario normal del jugador.
    cb(nil)
end)

-- ============================================================
--  [6] THREAD – TextUI de proximidad al maletero
--  Escanea continuamente si el jugador está detrás de un vehículo
--  con el maletero cerrado y desbloqueado. Si es así, muestra
--  el TextUI "Abrir Maletero [E]" y gestiona la pulsación.
--
--  waitTime:
--    · 1000ms por defecto (modo idle)
--    · 0ms cuando el jugador está dentro del radio de 2.0m
--
--  Condiciones para mostrar el TextUI:
--    · El jugador NO está en un vehículo
--    · El inventario NO está ocupado (inv_busy = false)
--    · Hay un vehículo a menos de 5m
--    · El jugador está a menos de 2m del punto del maletero
--    · El vehículo está desbloqueado (lockStatus < 2)
--    · El maletero está físicamente cerrado (ángulo de puerta < 0.1)
-- ============================================================

-- ==========================================
-- DP-TEXTUI (Proximidad del Maletero)
-- ==========================================
local inTrunkZone = false -- true si el TextUI del maletero está actualmente visible

CreateThread(function()
    local actionCooldown = 0 -- Timestamp hasta el que se ignoran pulsaciones de E (anti-spam)

    while true do
        local waitTime = 1000
        local ped = PlayerPedId()

        -- Solo ejecutamos la lógica si el jugador está a pie y no tiene el inventario abierto
        if not IsPedInAnyVehicle(ped, false) and not LocalPlayer.state.inv_busy then
            local pos = GetEntityCoords(ped)
            local vehicle, distance = QBCore.Functions.GetClosestVehicle()

            if vehicle ~= 0 and distance < 5.0 then
                local vehModel = GetEntityModel(vehicle)
                local dimensionMin, dimensionMax = GetModelDimensions(vehModel)

                -- Calculamos el punto exacto del maletero según el tipo de motor
                -- Por defecto asumimos motor delantero (puerta 5 = maletero trasero)
                local trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, dimensionMin.y, 0.0)
                local doorIndex = 5

                -- Motor trasero: el "maletero" está en la parte delantera (puerta 4)
                if IsBackEngine(vehModel) then
                    trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, dimensionMax.y, 0.0)
                    doorIndex = 4
                end

                if #(pos - trunkpos) < 2.0 then
                    waitTime = 0 -- Dentro del radio → modo reactivo

                    -- Comprobamos que el vehículo está desbloqueado Y el maletero está cerrado.
                    -- Usamos < 0.1 en lugar de == 0 para tolerar pequeños desajustes de animación.
                    local isTrunkClosed = GetVehicleDoorAngleRatio(vehicle, doorIndex) < 0.1

                    if GetVehicleDoorLockStatus(vehicle) < 2 and isTrunkClosed then
                        -- ── Mostramos el TextUI si acabamos de entrar en la zona ──
                        if not inTrunkZone then
                            exports['DP-TextUI']:MostrarUI('trunk_open', 'Abrir Maletero', 'E', false)
                            inTrunkZone = true
                        end

                        -- ── Tecla E: activamos el interruptor y lanzamos el comando de inventario ──
                        if IsControlJustPressed(0, 38) and GetGameTimer() > actionCooldown then
                            exports['DP-TextUI']:OcultarUI('trunk_open')
                            inTrunkZone = false

                            -- Encendemos el interruptor ANTES de ejecutar el comando;
                            -- el callback vehicleCheck lo leerá en la misma llamada.
                            forceOpenTrunk = true
                            ExecuteCommand('inventory')

                            actionCooldown = GetGameTimer() + 1500 -- 1.5s de cooldown
                        end
                    else
                        -- Vehículo bloqueado o maletero ya abierto → ocultamos el TextUI
                        if inTrunkZone then
                            exports['DP-TextUI']:OcultarUI('trunk_open')
                            inTrunkZone = false
                        end
                    end
                else
                    -- Fuera del radio de 2.0m → ocultamos el TextUI
                    if inTrunkZone then
                        exports['DP-TextUI']:OcultarUI('trunk_open')
                        inTrunkZone = false
                    end
                end
            else
                -- No hay vehículo cerca → ocultamos el TextUI
                if inTrunkZone then
                    exports['DP-TextUI']:OcultarUI('trunk_open')
                    inTrunkZone = false
                end
            end
        else
            -- Jugador en vehículo o inventario abierto → ocultamos el TextUI
            if inTrunkZone then
                exports['DP-TextUI']:OcultarUI('trunk_open')
                inTrunkZone = false
            end
        end

        Wait(waitTime)
    end
end)
