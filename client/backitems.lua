-- ============================================================
--  DP-INVENTORY · client/backitems.lua
--  Sistema de props visuales a la espalda/cuerpo del jugador.
--  Muestra modelos 3D de armas/ítems adjuntos al ped según el
--  inventario, la posición seleccionada y el estado global.
--
--  ÍNDICE DE CONTENIDOS
--  ─────────────────────────────────────────────────────────
--  [1]  VARIABLES DE ESTADO
--  [2]  LISTA DE ARMAS PEQUEÑAS
--  [3]  FUNCIONES LOCALES
--         · ClearBackItems
--         · GetWeaponPositionData
--         · UpdateBackItems
--         · RefreshBackItems
--  [4]  EVENTOS NUI (desde la UI)
--  [5]  EVENTOS QBCORE / CLIENTE
--  [6]  THREAD PRINCIPAL (vigilante de estado)
--  [7]  EXPORT
-- ============================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
--  [1] VARIABLES DE ESTADO
-- ============================================================

local attachedProps = {}         -- Tabla: weaponName → entity handle del prop adjunto
local currentPed = nil           -- Handle del ped local en el frame anterior (detección de cambio de ped)

-- VARIABLES DE ESTADO NUI
local globalHidden = false              -- Si true, todos los props están ocultos (toggle desde UI)
local currentWeaponPosition = 'normal' -- Posición activa: 'normal'|'front'|'back'|'belt'|'chest'|'thigh'|'leg'|'leg_sep'

-- ============================================================
--  [2] LISTA DE ARMAS PEQUEÑAS (Afectadas por botones de posición)
--  Solo estas armas responden a los cambios de posición desde la UI.
--  Las armas largas (rifles, escopetas, etc.) siempre usan la config base.
-- ============================================================
local smallWeapons = {
    ['weapon_pistol'] = true,
    ['weapon_combatpistol'] = true,
    ['weapon_appistol'] = true,
    ['weapon_stungun'] = true,
    ['weapon_pistol50'] = true,
    ['weapon_snspistol'] = true,
    ['weapon_heavypistol'] = true,
    ['weapon_vintagepistol'] = true,
    ['weapon_flaregun'] = true,
    ['weapon_marksmanpistol'] = true,
    ['weapon_revolver'] = true,
    ['weapon_revolver_mk2'] = true,
    ['weapon_doubleaction'] = true,
    ['weapon_pistol_mk2'] = true,
    ['weapon_snspistol_mk2'] = true,
    ['weapon_ceramicpistol'] = true,
    ['weapon_navyrevolver'] = true,
    ['weapon_gadgetpistol'] = true
}

-- ============================================================
--  [3] FUNCIONES LOCALES
-- ============================================================

--- Elimina y destruye TODOS los props adjuntos actualmente al ped.
--- Limpia la tabla `attachedProps` al finalizar.
--- Se llama al desloguear, al cambiar de ped o al activar el toggle de ocultación.
local function ClearBackItems()
    for weaponName, prop in pairs(attachedProps) do
        if DoesEntityExist(prop) then
            SetEntityAsMissionEntity(prop, true, true)  -- Permitir eliminación de entidades de misión
            DetachEntity(prop, true, true)
            DeleteObject(prop)
            DeleteEntity(prop)
        end
    end
    attachedProps = {}
end

--- Calcula y devuelve los datos de posición/rotación para adjuntar un prop al ped.
--- - Si la posición es 'normal' o el arma NO está en `smallWeapons`, devuelve la config base sin modificar.
--- - Si el arma SÍ es pequeña y hay una posición activa, devuelve las coordenadas de esa posición.
---
--- @param weaponName  string  Nombre interno del arma (ej: 'weapon_pistol')
--- @param configData  table   Entrada de BackItemsConfig para esta arma
--- @param position    string  Posición activa: 'normal'|'front'|'back'|'belt'|'chest'|'thigh'|'leg'|'leg_sep'
--- @return            table   {bone, x, y, z, x_rot, y_rot, z_rot}
--
-- FUNCIÓN INTELIGENTE: Traduce coordenadas SOLO para armas pequeñas
local function GetWeaponPositionData(weaponName, configData, position)
    local pos = {
        bone = configData.bone,
        x = configData.x,
        y = configData.y,
        z = configData.z,
        x_rot = configData.x_rot,
        y_rot = configData.y_rot,
        z_rot = configData.z_rot
    }

    -- Si la posición es NORMAL, o si NO ES un arma pequeña, devolvemos la config intacta
    if position == 'normal' or not smallWeapons[weaponName] then
        return pos
    end

    -- A partir de aquí, sabemos que SÍ ES una pistola y le aplicamos las posiciones:
    if position == 'front' then
        -- Frente (Barriga)
        pos.bone = 24818
        pos.x = 0.0
        pos.y = 0.16
        pos.z = -0.1
        pos.x_rot = 0.0
        pos.y_rot = 90.0
        pos.z_rot = 0.0
    elseif position == 'back' then
        -- Espalda Baja (Cintura atrás cruzada)
        pos.bone = 24818
        pos.x = 0.0
        pos.y = -0.16
        pos.z = -0.15
        pos.x_rot = 90.0
        pos.y_rot = 0.0
        pos.z_rot = 0.0
    elseif position == 'belt' then
        -- Cintura Centro (Pelvis por delante)
        pos.bone = 11816
        pos.x = -0.1
        pos.y = 0.15
        pos.z = 0.0
        pos.x_rot = -115.0
        pos.y_rot = 0.0
        pos.z_rot = 90.0
    elseif position == 'chest' then
        -- Pecho (Cruzada tipo Sobaquera)
        pos.bone = 24818
        pos.x = -0.05
        pos.y = 0.15
        pos.z = 0.1
        pos.x_rot = 0.0
        pos.y_rot = -90.0
        pos.z_rot = 0.0
    elseif position == 'thigh' then
        -- Muslo Derecho (Pegada lateral)
        pos.bone = 51826
        pos.x = 0.1
        pos.y = 0.0
        pos.z = 0.0
        pos.x_rot = 90.0
        pos.y_rot = 0.0
        pos.z_rot = 0.0
    elseif position == 'leg' then
        -- Pantorrilla
        pos.bone = 36864
        pos.x = 0.08
        pos.y = 0.0
        pos.z = 0.05
        pos.x_rot = 90.0
        pos.y_rot = 0.0
        pos.z_rot = 0.0
    elseif position == 'leg_sep' then
        -- Pantorrilla separada (offset lateral mayor)
        pos.bone = 36864
        pos.x = 0.15
        pos.y = 0.0
        pos.z = 0.05
        pos.x_rot = 90.0
        pos.y_rot = 0.0
        pos.z_rot = 0.0
    end

    return pos
end

--- Sincroniza los props visuales con el estado actual del inventario del jugador.
--- Flujo:
---   1. Construye un set de armas que DEBEN estar visibles (están en el inventario y en BackItemsConfig).
---   2. Elimina props de armas que ya NO están en el inventario.
---   3. Si globalHidden está activo, para aquí (no crea nuevos props).
---   4. Crea y adjunta props para armas que están en el inventario pero no tienen prop todavía.
---
--- @param items  table  Tabla de ítems del jugador (PlayerData.items)
local function UpdateBackItems(items)
    local ped = PlayerPedId()
    local currentWeaponsInInv = {}  -- Set: armas del inventario que tienen config en BackItemsConfig

    if items then
        for _, item in pairs(items) do
            if item and item.name and BackItemsConfig[item.name] then
                currentWeaponsInInv[item.name] = true
            end
        end
    end

    -- Paso 1: eliminar props de armas que ya no están en el inventario
    for weaponName, prop in pairs(attachedProps) do
        if not currentWeaponsInInv[weaponName] then
            if DoesEntityExist(prop) then
                DeleteEntity(prop)
            end
            attachedProps[weaponName] = nil
        end
    end

    -- Paso 2: si el toggle de ocultación está activo, no creamos más props
    if globalHidden then
        return
    end

    -- Paso 3: crear props para armas en inventario que aún no tienen prop
    for weaponName, _ in pairs(currentWeaponsInInv) do
        local configData = BackItemsConfig[weaponName]

        -- Obtenemos la posición correcta según si es pistola y la posición activa
        local posData = GetWeaponPositionData(weaponName, configData, currentWeaponPosition)

        if not attachedProps[weaponName] or not DoesEntityExist(attachedProps[weaponName]) then
            local modelHash = joaat(configData.model)
            RequestModel(modelHash)
            while not HasModelLoaded(modelHash) do
                Wait(10)  -- Esperamos hasta que el modelo esté en memoria
            end

            local prop = CreateObject(modelHash, 0.0, 0.0, 0.0, true, true, false)
            local boneIndex = GetPedBoneIndex(ped, posData.bone)
            AttachEntityToEntity(prop, ped, boneIndex, posData.x, posData.y, posData.z, posData.x_rot, posData.y_rot,
                posData.z_rot, true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(modelHash)  -- Liberamos la referencia del modelo de memoria
            attachedProps[weaponName] = prop
        end
    end
end

--- Shortcut que lee los ítems actuales del jugador y llama a UpdateBackItems.
--- Usada en todos los eventos de recarga de skin/ropa/spawn donde el ped cambia.
local function RefreshBackItems()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.items then
        UpdateBackItems(PlayerData.items)
    end
end


-- ============================================================
--  [4] EVENTOS NUI (Interacción desde la UI de DP-Inventory)
-- ============================================================

--- Alterna la visibilidad global de todos los props a la espalda.
--- Si se ocultan, destruye todos los props. Si se muestran, resetea
--- la posición a 'normal' y recrea todos los props.
RegisterNetEvent('DP-Inventory:client:ToggleBackItems', function()
    globalHidden = not globalHidden
    if globalHidden then
        ClearBackItems()
    else
        currentWeaponPosition = 'normal'
        RefreshBackItems()
    end
end)

--- Cambia la posición de las armas pequeñas en el cuerpo del jugador.
--- Destruye todos los props actuales, espera 50ms para evitar flickering
--- y los recrea con la nueva posición.
---
--- @param position  string  Nueva posición: 'normal'|'front'|'back'|'belt'|'chest'|'thigh'|'leg'|'leg_sep'
RegisterNetEvent('DP-Inventory:client:SetWeaponPosition', function(position)
    currentWeaponPosition = position
    ClearBackItems()
    Wait(50)
    RefreshBackItems()
end)


-- ============================================================
--  [5] EVENTOS QBCORE / CLIENTE
--  Todos los eventos que pueden cambiar el ped o el inventario
--  del jugador disparan un RefreshBackItems para re-sincronizar.
-- ============================================================

--- Actualiza los props cuando QB notifica un cambio en los datos del jugador.
--- Este evento se dispara cada vez que el inventario cambia (añadir/quitar ítems).
RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    if val and val.items then
        UpdateBackItems(val.items)
    end
end)

--- Al cargar el jugador, espera 2 segundos para que el ped se cargue
--- completamente antes de adjuntar props.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    currentPed = PlayerPedId()
    RefreshBackItems()
end)

--- Al hacer spawn (selección de spawn), espera 1 segundo para que el ped esté listo.
RegisterNetEvent('qb-spawn:client:ValidSpawn', function()
    Wait(1000)
    RefreshBackItems()
end)

--- Al entrar a un apartamento el ped puede reinicializarse.
RegisterNetEvent('apartments:client:SpawnInApartment', function()
    Wait(1000)
    RefreshBackItems()
end)

--- Al cambiar de ropa, el ped se regenera y hay que re-adjuntar los props.
RegisterNetEvent('qb-clothing:client:loadPlayerClothing', function()
    Wait(1000)
    RefreshBackItems()
end)

--- Compatibilidad con illenium-appearance: re-adjunta al recargar la skin.
RegisterNetEvent('illenium-appearance:client:reloadSkin', function()
    Wait(1000)
    RefreshBackItems()
end)

--- Al desloguear, eliminamos todos los props para no dejar entidades huérfanas.
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    ClearBackItems()
end)

--- Al detener el recurso, limpiamos todos los props para no contaminar la sesión.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        ClearBackItems()
    end
end)


-- ============================================================
--  [6] THREAD PRINCIPAL
--  Ejecuta cada 1 segundo y se encarga de:
--    A) Detectar cambio de ped (spawn, cambio de personaje)
--    B) Eliminar props clonados por scripts externos (anti-exploit)
--    C) Validar que los props siguen vivos y adjuntos al ped
--    D) Gestionar la visibilidad según arma activa / vehículo / toggle
-- ============================================================
CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local needsRefresh = false

        -- A) Detección de cambio de ped
        -- Si el ped cambió (nuevo spawn, cambio de personaje) limpiamos y marcamos refresh
        if currentPed ~= ped then
            currentPed = ped
            ClearBackItems()
            needsRefresh = true
        end

        -- =================================================================
        -- 🔥 B) CAZAFANTASMAS: ANTI-EXPLOIT DE PROPS DUPLICADOS 🔥
        -- Detecta y destruye props de armas adjuntos al ped que NO fueron
        -- creados por DP-Inventory. Evita que otros scripts dupliquen
        -- visualmente las armas a la espalda.
        -- =================================================================
        -- Obtenemos la entidad exacta del arma que tenemos EN LA MANO
        local currentWeaponEnt = GetCurrentPedWeaponEntityIndex(ped)

        for _, obj in ipairs(GetGamePool('CObject')) do
            -- Solo miramos objetos adjuntos a nuestro ped que NO sean el arma activa en mano
            if GetEntityAttachedTo(obj) == ped and obj ~= currentWeaponEnt then
                local model = GetEntityModel(obj)

                -- Comprobamos si el modelo del objeto coincide con alguna arma de nuestra config
                for weaponName, configData in pairs(BackItemsConfig) do
                    if joaat(configData.model) == model then

                        -- Verificamos si este prop fue creado por nosotros
                        local isOurs = false
                        for _, ourProp in pairs(attachedProps) do
                            if ourProp == obj then
                                isOurs = true
                                break
                            end
                        end

                        -- Si NO es nuestro → es un clon de otro script. Lo destruimos.
                        if not isOurs then
                            SetEntityAsMissionEntity(obj, true, true)
                            DetachEntity(obj, true, true)
                            DeleteEntity(obj)
                        end
                    end
                end
            end
        end
        -- =================================================================

        -- C) Validación de props: detecta props que dejaron de existir o se desanclaron
        for weaponName, prop in pairs(attachedProps) do
            if not DoesEntityExist(prop) then
                -- El prop fue destruido externamente
                attachedProps[weaponName] = nil
                needsRefresh = true
            elseif GetEntityAttachedTo(prop) ~= ped then
                -- El prop se desancló del ped (raro, pero posible)
                DeleteEntity(prop)
                attachedProps[weaponName] = nil
                needsRefresh = true
            end
        end

        -- Si se detectó algún problema, recreamos los props (solo si no están ocultos)
        if needsRefresh and not globalHidden then
            RefreshBackItems()
        end

        -- D) Control de visibilidad frame a frame
        -- Ocultamos el prop si: el jugador tiene esa arma en mano, está en vehículo,
        -- o el toggle global está activo. En caso contrario, la mostramos.
        if next(attachedProps) ~= nil then
            local currentWeapon = GetSelectedPedWeapon(ped)
            local inVehicle = IsPedInAnyVehicle(ped, false)

            for weaponName, prop in pairs(attachedProps) do
                if DoesEntityExist(prop) then
                    local weaponHash = joaat(weaponName)
                    if weaponHash == currentWeapon or inVehicle or globalHidden then
                        -- Ocultamos el prop (arma en mano / en vehículo / toggle activo)
                        if IsEntityVisible(prop) then
                            SetEntityVisible(prop, false, false)
                        end
                    else
                        -- Mostramos el prop
                        if not IsEntityVisible(prop) then
                            SetEntityVisible(prop, true, false)
                        end
                    end
                end
            end
        end
    end
end)


-- ============================================================
--  [7] EXPORT
-- ============================================================

--- Fuerza una recreación completa de todos los props a la espalda.
--- Útil para llamar desde otros recursos después de cambios de ropa/ped
--- que no disparen los eventos ya registrados arriba.
--- No hace nada si el toggle de ocultación está activo.
---
--- Uso desde otro recurso/scripts:
---   exports['DP-Inventory']:RefreshWeapons()
exports('RefreshWeapons', function()
    if not globalHidden then
        ClearBackItems()
        Wait(500)
        RefreshBackItems()
    end
end)