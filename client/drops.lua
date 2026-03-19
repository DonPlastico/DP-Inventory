-- ============================================================
--  DP-INVENTORY · client/drops.lua
--  Sistema de bolsas/drops en el suelo.
--  Gestiona la detección de proximidad, la interacción (abrir/
--  recoger/soltar bolsas) y la sincronización con el servidor.
--
--  ÍNDICE DE CONTENIDOS
--  ─────────────────────────────────────────────────────────
--  [1]  VARIABLES DE ESTADO
--  [2]  FUNCIÓN PÚBLICA  – GetDrops
--  [3]  FUNCIÓN LOCAL    – PlayPickupAnimation
--  [4]  EVENTOS DE RED   – sincronización de drops
--  [5]  NUI CALLBACK     – DropItem (tirar ítem al suelo)
--  [6]  THREAD 1         – Escáner de proximidad (lento)
--  [7]  THREAD 2         – Interacción y TextUI (rápido)
-- ============================================================
-- ============================================================
--  [1] VARIABLES DE ESTADO
-- ============================================================
HoldingDrop = false -- GLOBAL: true si el jugador lleva una bolsa en la mano.
-- Leído desde otros archivos (ej: backitems.lua) para ocultar props.
local bagObject = nil -- Handle de la entidad de la bolsa que se está llevando en la mano.
local heldDrop = nil -- ID del drop actualmente sostenido (ej: "drop-1234").
CurrentDrop = nil -- GLOBAL: ID del drop que está abierto en la UI en este momento.

-- Variables para gestionar los TextUIs y las zonas
local activeDrops = {} -- Tabla actualizada desde el servidor con todos los drops activos en el mundo.
local inDropZone = false -- true si el jugador está dentro del radio de interacción de una bolsa.
local nearestDropData = nil -- Dato del drop más cercano. Puente entre el Thread 1 y el Thread 2.

-- ============================================================
--  [2] FUNCIÓN PÚBLICA – GetDrops
-- ============================================================

--- Solicita al servidor la lista actualizada de todos los drops activos
--- y la almacena en `activeDrops` para ser usada por los threads de proximidad.
--- Se llama al iniciar, al crear un drop, y al eliminar uno.
function GetDrops()
    QBCore.Functions.TriggerCallback('DP-Inventory:server:GetCurrentDrops', function(drops)
        if not drops then
            activeDrops = {}
            return
        end
        activeDrops = drops
    end)
end

-- ============================================================
--  [3] FUNCIÓN LOCAL – PlayPickupAnimation
-- ============================================================

--- Reproduce la animación de agacharse a recoger un objeto del suelo.
--- Bloquea ~700ms (el momento en que la mano toca el suelo) antes de continuar.
--- Se usa tanto al recoger como al soltar una bolsa para mayor inmersión.
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

-- ============================================================
--  [4] EVENTOS DE RED – Sincronización de drops
-- ============================================================

--- El servidor notifica que un drop fue eliminado → refrescamos la lista local.
RegisterNetEvent('DP-Inventory:client:removeDropTarget', function(dropId)
    GetDrops()
end)

--- El servidor notifica que un drop fue creado → refrescamos la lista local.
RegisterNetEvent('DP-Inventory:client:setupDropTarget', function(dropId)
    GetDrops()
end)

-- ============================================================
--  [5] NUI CALLBACK – DropItem (tirar un ítem al suelo)
-- ============================================================

--- Llamado desde la UI cuando el jugador arrastra un ítem fuera del inventario.
--- Flujo:
---   1. Solicita al servidor crear un drop físico con el ítem.
---   2. Espera a que la entidad de red exista en el cliente.
---   3. Coloca la bolsa en el suelo y la congela.
---   4. Devuelve al NUI el ID del drop creado para actualizarlo en la UI.
---
--- @param item  table   Datos del ítem a tirar
--- @param cb    function  Callback NUI: cb(dropId) o cb(false) si falló
RegisterNUICallback('DropItem', function(item, cb)
    QBCore.Functions.TriggerCallback('DP-Inventory:server:createDrop', function(dropId)
        if dropId then
            -- Esperamos a que la entidad de red esté disponible en el cliente
            while not NetworkDoesNetworkIdExist(dropId) do
                Wait(10)
            end
            local bag = NetworkGetEntityFromNetworkId(dropId)
            SetModelAsNoLongerNeeded(bag) -- Liberamos referencia del modelo
            PlaceObjectOnGroundProperly(bag) -- Ajustamos la altura al suelo
            FreezeEntityPosition(bag, true) -- Congelamos para que no se mueva
            local newDropId = 'drop-' .. dropId
            cb(newDropId)
        else
            cb(false)
        end
    end, item)
end)

-- ============================================================
--  [6] THREAD 1 – Escáner de proximidad (bucle lento)
--  Ejecuta cada 500ms (2 veces/segundo) para mantener el consumo bajo.
--  Busca el drop más cercano al jugador dentro de 2.5 metros y
--  actualiza `nearestDropData` para que el Thread 2 lo procese.
-- ============================================================
CreateThread(function()
    while true do
        Wait(500) -- Escanea el entorno solo 2 veces por segundo

        if not HoldingDrop then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local tempNearest = nil
            local nearestDistance = 2.5 -- Radio de detección en metros

            for k, v in pairs(activeDrops) do
                -- Verificamos que la entidad de red existe antes de intentar obtenerla
                if NetworkDoesNetworkIdExist(v.entityId) then
                    local bag = NetworkGetEntityFromNetworkId(v.entityId)

                    if DoesEntityExist(bag) then
                        local bagCoords = GetEntityCoords(bag)
                        local distance = #(playerCoords - bagCoords)

                        -- Guardamos solo el más cercano
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
            -- Publicamos el resultado para que el Thread 2 lo consuma
            nearestDropData = tempNearest
        else
            -- Si llevamos la bolsa en la mano, no hay "drop más cercano"
            nearestDropData = nil
        end
    end
end)

-- ============================================================
--  [7] THREAD 2 – Interacción y TextUI (bucle rápido bajo demanda)
--  Normalmente espera 1000ms, pero cuando el jugador está cerca
--  de una bolsa o la lleva en la mano, pasa a 0ms para capturar
--  las pulsaciones de teclas en tiempo real.
--
--  TECLAS:
--    E (38) → Abrir bolsa
--    G (47) → Recoger bolsa / Soltar bolsa (si se lleva)
-- ============================================================
CreateThread(function()
    local actionCooldown = 0 -- Timestamp hasta el que no se aceptan nuevas acciones (anti-spam)
    local currentDropId = nil -- ID del drop que actualmente muestra el TextUI

    while true do
        local waitTime = 1000 -- Por defecto esperamos 1 segundo (modo idle)
        local playerPed = PlayerPedId()

        -- ────────────────────────────────────────────────
        --  CASO A: Cerca de una bolsa y sin llevar ninguna
        -- ────────────────────────────────────────────────
        if nearestDropData and not HoldingDrop then
            waitTime = 0 -- Pasamos a modo reactivo (0ms) para capturar input

            -- SISTEMA DE SEGURIDAD: Si la bolsa desapareció inesperadamente (recogida por otro
            -- jugador, destruida, etc.), ocultamos el UI y reseteamos el estado.
            if not DoesEntityExist(nearestDropData.bag) then
                if inDropZone then
                    exports['DP-TextUI']:OcultarUI('drop_abrir')
                    exports['DP-TextUI']:OcultarUI('drop_recoger')
                    inDropZone = false
                end
                nearestDropData = nil
                goto continue
            end

            -- Mostramos los TextUIs al entrar en la zona o al cambiar de bolsa
            if not inDropZone or currentDropId ~= nearestDropData.id then
                if inDropZone then
                    -- Ocultamos el UI de la bolsa anterior antes de mostrar el nuevo
                    exports['DP-TextUI']:OcultarUI('drop_abrir')
                    exports['DP-TextUI']:OcultarUI('drop_recoger')
                end

                exports['DP-TextUI']:MostrarUI('drop_abrir', 'Abrir bolsa', 'E', false)
                exports['DP-TextUI']:MostrarUI('drop_recoger', 'Recoger bolsa', 'G', false)

                inDropZone = true
                currentDropId = nearestDropData.id
            end

            -- ── Tecla E: Abrir la bolsa (ver su contenido en la UI) ──
            if IsControlJustPressed(0, 38) then
                -- Normalizamos el ID del drop al formato "drop-XXXX"
                local newDropId = type(nearestDropData.id) == "string" and string.match(nearestDropData.id, "drop-") and
                                      nearestDropData.id or 'drop-' .. nearestDropData.entityId

                -- Pedimos permiso al servidor ANTES de abrir (otro jugador podría estar usándola)
                QBCore.Functions.TriggerCallback('DP-Inventory:server:requestOpenDrop', function(canOpen)
                    if canOpen then
                        CurrentDrop = newDropId -- La UI leerá esta variable para saber qué drop mostrar
                    else
                        QBCore.Functions.Notify("Alguien ya está interactuando con esta bolsa", "error")
                    end
                end, newDropId)

                -- ── Tecla G: Recoger la bolsa (llevarla en la mano) ──
            elseif IsControlJustPressed(0, 47) and GetGameTimer() > actionCooldown then
                if IsPedArmed(playerPed, 4) then
                    -- Seguridad: no se puede llevar una bolsa y un arma a la vez
                    QBCore.Functions.Notify("¡No puedes llevar un arma y una bolsa a la vez!", "error", 5500)
                else
                    local bag = nearestDropData.bag
                    local newDropId =
                        type(nearestDropData.id) == "string" and string.match(nearestDropData.id, "drop-") and
                            nearestDropData.id or 'drop-' .. nearestDropData.entityId

                    -- Pedimos permiso al servidor (evita que dos jugadores cojan la misma bolsa)
                    QBCore.Functions.TriggerCallback('DP-Inventory:server:requestHoldDrop', function(canHold, reason)
                        if canHold then
                            -- Pedimos el control de red de la entidad (necesario para moverla/adjuntarla)
                            NetworkRequestControlOfEntity(bag)
                            local timeout = 0
                            -- Esperamos hasta 500ms a que el servidor nos ceda el control
                            while not NetworkHasControlOfEntity(bag) and timeout < 50 do
                                Wait(10)
                                NetworkRequestControlOfEntity(bag)
                                timeout = timeout + 1
                            end

                            PlayPickupAnimation() -- Animación inmersiva de recoger

                            -- Adjuntamos la bolsa al ped, a la altura del hueso configurado
                            AttachEntityToEntity(bag, playerPed, GetPedBoneIndex(playerPed, Config.ItemDropObjectBone),
                                Config.ItemDropObjectOffset[1].x, Config.ItemDropObjectOffset[1].y,
                                Config.ItemDropObjectOffset[1].z, Config.ItemDropObjectOffset[2].x,
                                Config.ItemDropObjectOffset[2].y, Config.ItemDropObjectOffset[2].z, true, true, false,
                                true, 1, true)

                            bagObject = bag
                            HoldingDrop = true
                            heldDrop = newDropId
                            actionCooldown = GetGameTimer() + 1000 -- 1 segundo de cooldown

                            -- Ocultamos los TextUIs de interacción y mostramos el de soltar
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

            -- ────────────────────────────────────────────────
            --  CASO B: Salimos de la zona de una bolsa
            -- ────────────────────────────────────────────────
        elseif inDropZone and not nearestDropData then
            exports['DP-TextUI']:OcultarUI('drop_abrir')
            exports['DP-TextUI']:OcultarUI('drop_recoger')
            inDropZone = false
            currentDropId = nil
        end

        -- ────────────────────────────────────────────────
        --  CASO C: Llevamos una bolsa en la mano
        --  Tecla G: Soltar la bolsa en el suelo frente al jugador
        -- ────────────────────────────────────────────────
        if HoldingDrop then
            waitTime = 0 -- Modo reactivo mientras llevamos la bolsa

            if IsControlJustPressed(0, 47) and GetGameTimer() > actionCooldown then -- Tecla G: Soltar
                PlayPickupAnimation() -- Animación de dejar la bolsa en el suelo

                DetachEntity(bagObject, true, true)

                -- Calculamos la posición frente al jugador para colocar la bolsa
                local coords = GetEntityCoords(playerPed)
                local forward = GetEntityForwardVector(playerPed)
                local x, y, z = table.unpack(coords + forward * 0.57)

                -- La bajamos 0.9 unidades para que quede a ras de suelo
                SetEntityCoords(bagObject, x, y, z - 0.9, false, false, false, false)
                FreezeEntityPosition(bagObject, true) -- La congelamos en su nueva posición

                exports['DP-TextUI']:OcultarUI('drop_soltar')

                -- Notificamos al servidor la nueva posición del drop
                TriggerServerEvent('DP-Inventory:server:updateDrop', heldDrop, coords)

                HoldingDrop = false
                bagObject = nil
                heldDrop = nil
                actionCooldown = GetGameTimer() + 1000

                GetDrops() -- Refrescamos la lista de drops activos
            end
        end

        ::continue::
        Wait(waitTime)
    end
end)
