-- ============================================================
--  DP-INVENTORY · client/main_client.lua
--  Núcleo del cliente. Orquesta la apertura/cierre del inventario,
--  la comunicación NUI↔Lua, los sistemas anti-exploit, el menú
--  de acciones contextuales (PerformAction), el panel de admin
--  y las integraciones con recursos externos.
--
--  ÍNDICE DE CONTENIDOS
--  ─────────────────────────────────────────────────────────
--  [1]  VARIABLES DE ESTADO GLOBALES Y LOCALES
--  [2]  HANDLERS DE CICLO DE VIDA (carga/descarga/restart)
--  [3]  FUNCIONES LOCALES Y GLOBALES
--         · UpdateNuiFocus
--         · LoadAnimDict
--         · GetVehicleConfig
--         · GetAttachmentSlotType
--         · FormatWeaponAttachments
--         · HasItem (cliente)
--  [4]  EVENTOS DE RED – UI y Inventario
--         · requiredItems, hotbar, closeInv, updateInventory
--         · ShowItemBox / ItemBox / WeaponItemBox
--         · RobPlayer, openInventory, giveAnim
--  [5]  THREADS
--         · Hilo 1 (500ms)  – Vehículos y animaciones de armas
--         · Hilo 2 (1000ms) – Anti-exploit (distancia + arma fantasma)
--         · Hilo 3 (dinámico) – Máquinas expendedoras
--         · Hilo 4 (dinámico) – Bucle protector de input
--         · Hilo 5 (1500ms) – Integración DP-Boombox (radio de coche)
--  [6]  COMMANDS & KEYBINDS
--  [7]  PANEL DE ADMINISTRACIÓN (DP-Menu)
--  [8]  NUI CALLBACKS
--         · PlayDropFail, AttemptPurchase, CloseInventory
--         · toggleCursorMode, UseItem, SetInventoryData
--         · GiveItem, GetNearbyPlayers, Notify
--         · GetWeaponData, RemoveAttachment, AddAttachment
--         · PerformAction (acciones ropa / personaje / armas / vehículo)
--         · CloseSecondaryInventory, HolsterWeapon
--         · GetAdminMasterData, ForceOpenAdmin
--         · SaveInventoryPosition, SetTypingFocus, SaveMovePreference
--         · SaveSoundPref, abrirRadioDesdeInventario
--  [9]  EVENTOS DE INTEGRACIÓN EXTERNA (DP-Boombox)
--  [10] EXPORTS PARA OTROS RECURSOS
-- ============================================================
-- ============================================================
--  [1] VARIABLES DE ESTADO GLOBALES Y LOCALES
-- ============================================================
QBCore = exports['qb-core']:GetCoreObject() -- GLOBAL: accesible desde backpack_cl.lua y otros archivos

PlayerData = nil -- GLOBAL: espejo de los datos del jugador (QBCore.PlayerData).
-- Actualizado por QBCore:Player:SetPlayerData en cada cambio de inventario/stats.

local hotbarShown = false -- true si la hotbar está visible en la UI
local inVendingZone = false -- true si el jugador está dentro del radio de una máquina expendedora
local isInventoryOpen = false -- true si la UI del inventario está activa
local currentAimStyle = joaat("Default") -- Hash del estilo de apuntado activo (Default / Gang1H / Hillbilly)
local isHolstering = false -- true durante la animación de holster (anti-spam)
local holsterTimer = nil -- Handle del timeout que resetea isHolstering tras 1 segundo
local isPlayerAdmin = false -- true si el jugador tiene permisos de admin en DP-Inventory
local isTransitioningAdmin = false -- true durante la transición de apertura del panel admin (evita cierre prematuro)
local isCursorModeActive = false -- true si el modo cursor (tecla J) está activo (mueve cámara con el ratón)
local isOtherInventoryOpen = false -- true si hay un inventario secundario abierto (maletero, stash, drop, etc.)
local inventoryOpenCoords = nil -- Vector3 de donde estaba el jugador al abrir el inventario secundario (anti-exploit)
local moveWhileOpen = false -- Preferencia del jugador: si puede moverse con el inventario abierto
local isTypingInUI = false -- true si el jugador está escribiendo en un campo de texto de la UI
local inventoryPosition = 'bottom' -- Posición visual del inventario: 'bottom' | 'top' | etc.

-- ============================================================
--  [2] HANDLERS DE CICLO DE VIDA
-- ============================================================

--- Al cargar el jugador: inicializa el estado del inventario, carga los drops
--- y recupera las preferencias guardadas del jugador desde el servidor.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set('inv_busy', false, true) -- Marcamos al jugador como disponible
    PlayerData = QBCore.Functions.GetPlayerData()
    GetDrops() -- Función de drops.lua: carga los drops activos del mundo

    -- Comprobamos si el jugador es admin del inventario
    QBCore.Functions.TriggerCallback('DP-Inventory:server:IsAdmin', function(admin)
        isPlayerAdmin = admin
    end)

    -- Preferencia: ¿puede moverse con el inventario abierto?
    QBCore.Functions.TriggerCallback('DP-Inventory:server:GetMovePref', function(pref)
        moveWhileOpen = pref
    end)

    -- Preferencia: posición visual del inventario en pantalla
    QBCore.Functions.TriggerCallback('DP-Inventory:server:GetPosition', function(pos)
        inventoryPosition = pos
    end)

    -- Preferencia: sonidos de inventario activados/desactivados
    QBCore.Functions.TriggerCallback('DP-Inventory:server:GetSoundPref', function(pref)
        SendNUIMessage({
            action = 'setSoundPref',
            status = pref
        })
    end)
end)

--- Al desloguear: bloqueamos el inventario y limpiamos PlayerData.
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set('inv_busy', true, true)
    PlayerData = nil
end)

--- Actualización continua de PlayerData: se dispara en cada cambio de inventario,
--- stats o cualquier dato del jugador gestionado por QBCore.
RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

--- Al reiniciar el recurso en caliente: recargamos PlayerData y las preferencias
--- para que el jugador no pierda configuración sin reconectarse.
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

-- ============================================================
--  [3] FUNCIONES LOCALES Y GLOBALES
-- ============================================================

--- Actualiza el foco NUI y el modo de input según el estado del inventario.
--- - Inventario abierto + moveWhileOpen + no escribiendo → SetNuiFocusKeepInput(true)
---   (el jugador puede moverse WASD mientras la UI tiene el foco del ratón)
--- - Cualquier otro caso → foco total en NUI o sin foco.
--- Llamar esta función en lugar de SetNuiFocus directamente garantiza coherencia.
local function UpdateNuiFocus()
    if isInventoryOpen then
        SetNuiFocus(true, true)
        if moveWhileOpen and not isTypingInUI then
            SetNuiFocusKeepInput(true)
        else
            SetNuiFocusKeepInput(false)
        end
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end

--- Carga un diccionario de animaciones de forma bloqueante (espera hasta que esté listo).
--- GLOBAL: usada desde vehicles.lua (OpenTrunk/CloseTrunk) y otros archivos.
---
--- @param dict  string  Nombre del diccionario de animaciones a cargar
function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then
        return -- Ya estaba cargado, no hacemos nada
    end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

--- Escanea la configuración física de un vehículo y devuelve sus características.
--- Se llama al abrir el inventario estando en un vehículo para enviar a la UI
--- qué puertas/maletero/asientos existen y poder mostrar los controles correctos.
---
--- @param veh    number  Handle del vehículo
--- @return       table|nil  {vehClass, seats, hasDoor{fl,fr,rl,rr,hood,trunk}} o nil si veh=0
-- ESCÁNER FÍSICO DEL VEHÍCULO
local function GetVehicleConfig(veh)
    if veh == 0 then
        return nil
    end
    return {
        vehClass = GetVehicleClass(veh),
        seats = GetVehicleModelNumberOfSeats(GetEntityModel(veh)),
        hasDoor = {
            fl = DoesVehicleHaveDoor(veh, 0), -- Frontal Izquierda (conductor)
            fr = DoesVehicleHaveDoor(veh, 1), -- Frontal Derecha (copiloto)
            rl = DoesVehicleHaveDoor(veh, 2), -- Trasera Izquierda
            rr = DoesVehicleHaveDoor(veh, 3), -- Trasera Derecha
            hood = DoesVehicleHaveDoor(veh, 4), -- Capó / Motor
            trunk = DoesVehicleHaveDoor(veh, 5) -- Maletero
        }
    }
end

--- Traduce el tipo de accesorio de qb-weapons al tipo de slot del panel de armas de la UI.
--- Los tipos de qb-weapons son strings largos (ej: 'suppressor_attachment');
--- la UI de DP-Inventory usa tipos cortos (ej: 'suppressor').
---
--- @param attachmentType  string  Tipo de accesorio de qb-weapons
--- @return                string  Tipo de slot para la UI ('suppressor'|'barrel'|'grip'|'flashlight'|'scope'|'clip'|'drum'|'camo')
-- Mapea el attachmentType del config de qb-weapons al tipo de slot del panel WIP
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
    return 'flashlight' -- Fallback por defecto si el tipo no coincide con ningún caso
end

--- Formatea la lista de accesorios instalados en un arma al formato que consume la UI.
--- Cruza los accesorios del `info` del ítem con la config de qb-weapons para obtener
--- el tipo de slot y el label legible de cada accesorio.
---
--- @param itemdata  table  Datos completos del ítem arma (con itemdata.info.attachments)
--- @return          table  Array de {attachment, label, slotType} listo para la UI
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
                        slotType = GetAttachmentSlotType(attachmentType)
                    }
                end
            end
        end
    end
    return attachments
end

--- Comprueba si el jugador local tiene uno o varios ítems en su inventario.
--- Versión CLIENTE de HasItem: opera sobre `PlayerData.items` en lugar de llamar al servidor.
--- Misma lógica que la versión servidor de functions.lua.
---
--- EXPORT: exports['DP-Inventory']:HasItem(items, amount)
---
--- Modos de uso:
---   HasItem('water')               → ¿tiene al menos 1 water?
---   HasItem('water', 3)            → ¿tiene al menos 3 water?
---   HasItem({'water', 'bread'})    → ¿tiene al menos 1 de cada uno?
---   HasItem({water=2, bread=1})    → ¿tiene 2 water Y 1 bread?
---
--- @param items   string|table  Nombre del ítem o tabla de ítems
--- @param amount  number|nil    Cantidad mínima (solo para string)
--- @return        boolean
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

-- ============================================================
--  [4] EVENTOS DE RED – UI e Inventario
-- ============================================================

--- Muestra u oculta la lista de ítems requeridos para una acción en la UI.
--- `bool=true` → muestra los ítems; `bool=false` → limpia la lista.
---
--- @param items  table    Lista de ítems requeridos (name, image)
--- @param bool   boolean  true para mostrar, false para ocultar
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

--- Alterna la visibilidad de la hotbar y envía los ítems actuales a la UI.
--- El estado `hotbarShown` se invierte en cada llamada.
RegisterNetEvent('DP-Inventory:client:hotbar', function(items)
    hotbarShown = not hotbarShown
    SendNUIMessage({
        action = 'toggleHotbar',
        open = hotbarShown,
        items = items
    })
end)

--- Cierra la UI del inventario desde el servidor (sin pasar por el NUI callback).
RegisterNetEvent('DP-Inventory:client:closeInv', function()
    SendNUIMessage({
        action = 'close'
    })
end)

--- Fuerza una actualización de los ítems mostrados en la UI sin cerrar/abrir el inventario.
--- Se usa tras un ClearInventory, drop de ítems, etc.
RegisterNetEvent('DP-Inventory:client:updateInventory', function()
    -- 1. Volvemos a leer los ítems reales del jugador (PlayerData se actualiza solo por QBCore)
    local items = {}
    if PlayerData and type(PlayerData.items) == "table" then
        items = PlayerData.items
    end

    -- 2. Buscamos los IMEI de los teléfonos para pedir el estado de la SIM
    local imeisToCheck = {}
    for _, item in pairs(items) do
        if item and item.name == 'phone' and item.info and item.info.imei then
            table.insert(imeisToCheck, item.info.imei)
        end
    end

    -- 3. Pedimos al servidor el estado actualizado de las SIMs y enviamos a la UI
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
        -- Si no hay teléfonos, enviamos el inventario normal
        SendNUIMessage({
            action = 'update',
            inventory = items
        })
    end
end)

--- Muestra el aviso visual de ítem (añadido/eliminado/equipado/guardado) en la UI.
--- Función local reutilizada por varios eventos de red.
---
--- @param itemData  table   Datos del ítem (label, image, etc.)
--- @param type      string  Tipo de acción: 'add' | 'remove' | 'equip' | 'holster'
--- @param amount    number  Cantidad del ítem afectada
local function ShowItemBox(itemData, type, amount)
    SendNUIMessage({
        action = 'itemBox',
        item = itemData,
        type = type,
        amount = amount
    })
end

-- Alias de red para ShowItemBox (permite llamarlo desde el servidor o desde otros eventos cliente)
RegisterNetEvent('DP-Inventory:client:ItemBox', ShowItemBox)

--- Decide inteligentemente si mostrar el aviso como 'equipar' o 'guardar' según si
--- el arma clickeada es la que ya tenemos en la mano.
--- - Arma en mano == arma clickeada  → la estamos GUARDANDO ('holster')
--- - Desarmado o arma diferente      → la estamos EQUIPANDO ('equip')
RegisterNetEvent('DP-Inventory:client:WeaponItemBox', function(itemInfo)
    local ped = PlayerPedId()
    local currentWeapon = GetSelectedPedWeapon(ped)
    local itemHash = joaat(itemInfo.name)

    -- Buscamos el hash exacto del arma en el catálogo de QBCore (más fiable que joaat directo)
    if QBCore.Shared.Weapons then
        for _, v in pairs(QBCore.Shared.Weapons) do
            if v.name == itemInfo.name then
                itemHash = v.hash or joaat(v.name)
                break
            end
        end
    end

    if currentWeapon == itemHash then
        ShowItemBox(itemInfo, 'equip', 1) -- Arma en mano → la guardamos
    else
        ShowItemBox(itemInfo, 'holster', 1) -- Desarmado o diferente → la equipamos
    end
end)

--- Inicia el flujo de robo de dinero a otro jugador enviando su ID a la UI.
RegisterNetEvent('DP-Inventory:server:RobPlayer', function(TargetId)
    SendNUIMessage({
        action = 'RobMoney',
        TargetId = TargetId
    })
end)

--- Abre la UI del inventario con todos los datos necesarios para el render inicial.
--- Reúne: ítems, capacidad dinámica (mochila), datos de vehículo, preferencias y permisos.
---
--- @param items  table       Inventario del jugador (PlayerData.items)
--- @param other  table|nil   Inventario secundario (maletero, stash, drop...) o nil si solo bolsillos
RegisterNetEvent('DP-Inventory:client:openInventory', function(items, other)
    isInventoryOpen = true
    UpdateNuiFocus()

    -- Si hay inventario secundario, guardamos las coordenadas actuales para el anti-exploit de distancia
    if other then
        isOtherInventoryOpen = true
        inventoryOpenCoords = GetEntityCoords(PlayerPedId())
    else
        isOtherInventoryOpen = false
    end

    -- Nombre del personaje para mostrar en el panel del inventario
    local charName = "INVENTARIO"
    if PlayerData and PlayerData.charinfo then
        charName = PlayerData.charinfo.firstname .. ' ' .. PlayerData.charinfo.lastname
    end

    -- Detección del asiento del jugador en el vehículo (para controles de guantera/asientos)
    local ped = PlayerPedId()
    local isDriver = false
    local inVeh = false
    local mySeat = nil
    local vehData = nil
    local veh = GetVehiclePedIsIn(ped, false)

    if veh ~= 0 then
        inVeh = true
        isDriver = true
        vehData = GetVehicleConfig(veh) -- Escaneamos puertas/asientos del vehículo
        for i = -1, 2 do
            if GetPedInVehicleSeat(veh, i) == ped then
                mySeat = i -- -1=conductor, 0=copiloto, 1=TI, 2=TD
                break
            end
        end
    end

    -- Capacidad dinámica: peso puede aumentar si hay mochila expansora en slot 101
    local _, dynamicWeight = GetPlayerDynamicCapacity() -- De backpack_cl.lua
    local dynamicSlots = Config.MaxSlots -- Slots siempre base fijo

    -- ============================================================
    --  PRECARGA DEL ESTADO DE LA SIM (Vía servidor, sin MySQL)
    --  Pedimos al servidor los IMEI de los teléfonos que llevamos
    --  y él nos devuelve qué SIM tiene cada uno.
    -- ============================================================
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
                -- Inyectamos los datos en los ítems
                for _, item in pairs(items) do
                    if item and item.name == 'phone' and item.info and item.info.imei then
                        local simNum = simStates[item.info.imei]
                        item.hasSim = simNum ~= nil
                        item.sim_number = simNum
                    end
                end
            end

            -- Enviamos el inventario a la UI (ahora con los datos de SIM)
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
        -- Si no hay teléfonos, abrimos el inventario normal
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
end) -- Fin de openInventory

--- Reproduce la animación de dar/recibir un ítem a otro jugador.
--- No se reproduce si el jugador está en un vehículo.
RegisterNetEvent('DP-Inventory:client:giveAnim', function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        return
    end
    LoadAnimDict('mp_common')
    TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_b', 8.0, 1.0, -1, 16, 0, false, false, false)
end)

-- ============================================================
--  [5] THREADS
-- ============================================================

-- ==========================================================================
-- HILO 1: COMPROBACIONES MEDIAS (500ms) – Vehículos y Animaciones de Armas
-- Responsabilidades:
--   1. Vigilante del vehículo: actualiza la UI si el jugador cambia de asiento
--      o se baja del coche con el inventario abierto.
--   2. Guardián de animaciones (propio): aplica el estilo de apuntado correcto
--      tras 1.5s de haber equipado el arma (evita conflictos con animaciones de equip).
--   3. Guardián de animaciones (otros): sincroniza el estilo de apuntado de otros
--      jugadores usando su state bag (aimStyle).
-- ==========================================================================
local appliedAimStyles = {} -- Cache: player → stateKey de la animación ya aplicada
local lastWeapons = {} -- Cache: player → hash del arma en el frame anterior
local equipTimers = {} -- Cache: player → timestamp en que cambió de arma

CreateThread(function()
    while true do
        Wait(500)
        local myPed = PlayerPedId()
        local myId = PlayerId()

        -- 1. VIGILANTE DEL VEHÍCULO
        -- Actualiza en tiempo real el asiento y configuración del vehículo en la UI
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
                -- Se bajó del vehículo → notificamos a la UI para ocultar controles de coche
                SendNUIMessage({
                    action = 'checkVehicleState',
                    inVehicle = false,
                    isDriver = false,
                    seat = nil,
                    vehData = nil
                })
            end
        end

        -- 2. GUARDIÁN DE ANIMACIONES (JUGADOR PROPIO)
        -- Detecta cambio de arma y aplica el estilo de apuntado tras 1.5s de estabilidad
        local currentWeapon = GetSelectedPedWeapon(myPed)
        if lastWeapons[myId] ~= currentWeapon then
            lastWeapons[myId] = currentWeapon
            equipTimers[myId] = GetGameTimer()
            appliedAimStyles[myId] = nil -- Invalidamos el cache para forzar re-aplicación
        end

        if currentWeapon ~= joaat('WEAPON_UNARMED') and currentWeapon ~= 0 then
            local stateKey = tostring(currentAimStyle) .. "_" .. tostring(currentWeapon)

            if appliedAimStyles[myId] ~= stateKey then
                -- Solo aplicamos si han pasado 1.5s desde el cambio de arma (anti-conflicto)
                if GetGameTimer() - (equipTimers[myId] or 0) > 1500 then
                    SetWeaponAnimationOverride(myPed, currentAimStyle)
                    appliedAimStyles[myId] = stateKey
                end
            end
        end

        -- 3. GUARDIÁN DE ANIMACIONES (OTROS JUGADORES EN RED)
        -- Lee el state bag 'aimStyle' de cada jugador y aplica su animación en local
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

-- ==========================================================================
-- HILO 2: COMPROBACIONES LENTAS (1000ms) – Sistemas Anti-Exploit
-- Responsabilidades:
--   1. Anti-exploit de distancia: cierra el inventario secundario si el jugador
--      se aleja más de 4m del punto donde lo abrió.
--   2. Anti-arma fantasma: detecta si el jugador tiene equipada un arma que ya
--      no está en su inventario (dupes visuales/combate) y se la retira.
-- ==========================================================================
CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()

        -- 1. ANTI-EXPLOIT: Distancia del Inventario Secundario (Maleteros/Drops/Stashes)
        if isInventoryOpen and isOtherInventoryOpen and inventoryOpenCoords then
            if not IsPedInAnyVehicle(ped, false) then
                local currentCoords = GetEntityCoords(ped)
                local dist = #(currentCoords - inventoryOpenCoords)

                if dist > 4.0 then
                    -- Si hay un vehículo cerca, cerramos su maletero también
                    local vehicle = QBCore.Functions.GetClosestVehicle()
                    if vehicle ~= 0 and #(currentCoords - GetEntityCoords(vehicle)) < 10.0 then
                        SetVehicleDoorShut(vehicle, 5, false) -- Cierra el maletero (puerta 5)
                    end

                    SendNUIMessage({
                        action = 'forceCloseOther' -- Fuerza el cierre del panel secundario en la UI
                    })
                    isOtherInventoryOpen = false
                    ClearPedTasks(ped) -- Cancela animación de rebuscar al alejarse
                    QBCore.Functions.Notify("Te has alejado demasiado del objetivo.", "error")
                end
            end
        end

        -- 2. ANTI-EXPLOIT: Arma Fantasma (Dupe Visual/Combate)
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
                -- Arma desconocida (no está en QBCore.Shared.Weapons) → la dejamos pasar
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

-- ==========================================================================
-- HILO 3: DINÁMICO (1000ms → 0ms) – Máquinas Expendedoras (Vending)
-- Escanea los objetos de tipo expendedora dentro de 2.5m.
-- Al detectar una, pasa a 0ms para capturar la tecla E.
-- Al pulsar E, envía el evento al servidor para abrir la tienda.
-- ==========================================================================
CreateThread(function()
    -- Pre-hasheamos los modelos de la config para comparaciones O(1)
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

        -- Solo buscamos si el inventario NO está ocupado
        if not LocalPlayer.state.inv_busy then
            for _, hash in ipairs(vendingHashes) do
                local object = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, 2.5, hash, false,
                    false, false)

                if DoesEntityExist(object) then
                    local objCoords = GetEntityCoords(object)
                    local distance = #(playerCoords - objCoords)

                    -- Guardamos solo la más cercana
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
            waitTime = 0 -- Modo reactivo
            if not inVendingZone then
                exports['DP-TextUI']:MostrarUI('vending_usar', Lang:t('menu.vending') or 'Usar Máquina', 'E', false)
                inVendingZone = true
            end

            if IsControlJustPressed(0, 38) then -- Tecla E
                exports['DP-TextUI']:OcultarUI('vending_usar')
                inVendingZone = false

                -- Enviamos al servidor la entidad y coordenadas de la máquina para que abra la tienda
                TriggerServerEvent('DP-Inventory:server:openVending', {
                    entity = nearestVendingObject,
                    coords = nearestVendingCoords
                })

                Wait(1000) -- Cooldown de 1s para evitar doble apertura por spam de E
            end
        elseif inVendingZone and not isNearVending then
            exports['DP-TextUI']:OcultarUI('vending_usar')
            inVendingZone = false
        end

        Wait(waitTime)
    end
end)

-- ==========================================================================
-- HILO 4: BUCLE PROTECTOR DE INPUT
-- Evita disparos accidentales, puñetazos y apertura del menú de pausa
-- mientras el inventario está abierto o recién cerrado.
--
-- Controls bloqueados con inventario abierto + moveWhileOpen:
--   24  → Click izquierdo (Ataque)
--   257 → Ataque 2
--   25  → Click derecho (Apuntar)
--   263 → Cuerpo a cuerpo
--   37  → Rueda de armas (TAB)
--   1   → Mover cámara Izq/Der (solo si no hay modo cursor)
--   2   → Mover cámara Arr/Aba (solo si no hay modo cursor)
--
-- Escudo anti-pause menu (activo 400ms después de cerrar):
--   200 → ESC
--   322 → ESC alternativo
-- ==========================================================================
local blockPauseMenuTimer = 0

CreateThread(function()
    while true do
        local sleep = 500

        if isInventoryOpen then
            sleep = 0
            -- Renovamos el escudo anti-ESC 400ms hacia el futuro en cada frame
            blockPauseMenuTimer = GetGameTimer() + 400

            if moveWhileOpen and not isTypingInUI then
                DisableControlAction(0, 24, true) -- Click Izquierdo (Ataque)
                DisableControlAction(0, 257, true) -- Ataque 2
                DisableControlAction(0, 25, true) -- Click Derecho (Apuntar)
                DisableControlAction(0, 263, true) -- Cuerpo a cuerpo
                DisableControlAction(0, 37, true) -- Rueda de armas (TAB)
                DisablePlayerFiring(PlayerPedId(), true)

                -- Solo bloqueamos la cámara si el modo cursor (J) NO está activo
                if not isCursorModeActive then
                    DisableControlAction(0, 1, true) -- Mover cámara Izq/Der
                    DisableControlAction(0, 2, true) -- Mover cámara Arr/Aba
                end
            end
        end

        -- Escudo anti-pause: activo durante y 400ms después de cerrar el inventario
        if GetGameTimer() < blockPauseMenuTimer then
            sleep = 0
            DisableControlAction(0, 200, true) -- ESC
            DisableControlAction(0, 322, true) -- ESC alternativo
        end

        Wait(sleep)
    end
end)

-- ==========================================================================
-- HILO 5: INTEGRACIÓN DP-BOOMBOX (Radio de coche) – 1500ms
-- Detecta cuando el jugador sube/baja de un vehículo y comprueba
-- si ese vehículo tiene radio instalada (via callback del Boombox).
-- Notifica a la UI para mostrar/ocultar el botón de radio en el inventario.
-- ==========================================================================

-- ============================================
-- 📻 INTEGRACIÓN CON DP-BOOMBOX_V2 (RADIO DE COCHES)
-- ============================================

-- 1. Vigilante en segundo plano: detecta si el coche tiene radio al subirse
CreateThread(function()
    local inVehicle = false
    while true do
        Wait(1500) -- Revisión cada 1.5s (bajo impacto en rendimiento)
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) then
            if not inVehicle then
                inVehicle = true
                local veh = GetVehiclePedIsIn(ped, false)
                local plate = GetVehicleNumberPlateText(veh)

                if plate then
                    -- Limpiamos espacios en blanco de la matrícula por seguridad
                    plate = string.gsub(plate, "^%s*(.-)%s*$", "%1")

                    -- Consultamos al Boombox si este vehículo tiene radio instalada
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
                -- Al bajarse del vehículo: ocultamos el botón de radio en la UI
                SendNUIMessage({
                    action = "updateVehicleRadio",
                    status = false
                })
            end
        end
    end
end)

-- ============================================================
--  [6] COMMANDS & KEYBINDS
-- ============================================================

--- Abre el inventario si la NUI y el menú de pausa no están activos.
RegisterCommand('openInv', function()
    if IsNuiFocused() or IsPauseMenuActive() then
        return
    end
    ExecuteCommand('inventory')
end, false)

--- Alterna la visibilidad de la hotbar.
RegisterCommand('toggleHotbar', function()
    ExecuteCommand('hotbar')
end, false)

--- Slots de hotbar (1–5): usa directamente el ítem del slot correspondiente.
--- Bloquea el uso si el jugador lleva una bolsa de drop en la mano y el ítem es un arma.
for i = 1, 5 do
    RegisterCommand('slot_' .. i, function()
        local itemData = PlayerData.items[i]
        if not itemData then
            return
        end
        if itemData.type == "weapon" then
            if HoldingDrop then
                -- No se puede sacar un arma si llevas una bolsa en la mano
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

-- ============================================================
--  [7] PANEL DE ADMINISTRACIÓN (DP-Menu)
--  Sistema de menús para que los admins inspeccionen cualquier
--  inventario del servidor sin estar físicamente cerca.
-- ============================================================

-- ==========================================================================
-- MENÚ ADMIN: GESTIÓN MAESTRA DE INVENTARIOS (DP-MENU)
-- ==========================================================================
local cachedInventoryData = {} -- Cache local con los datos del panel admin (jugadores, stashes, etc.)

--- Recibe del servidor la lista de todos los inventarios y abre el menú principal de admin.
--- Cachea los datos para que los submenús no necesiten otra consulta al servidor.
RegisterNetEvent('DP-Inventory:client:OpenMasterMenu', function(players, trunks, gloveboxes, stashes)
    cachedInventoryData = {
        players = players,
        trunks = trunks,
        gloveboxes = gloveboxes,
        stashes = stashes
    }
    TriggerEvent('DP-Inventory:client:ReturnToMasterMenu')
end)

--- Construye y abre el menú raíz del panel de administración usando DP-Menu.
--- Muestra el conteo de cada categoría para orientar al admin de un vistazo.
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

--- Construye el submenú de una categoría (jugadores / stashes / maleteros / guanteras).
--- Cada entrada del menú dispara ForceOpenInventory o ForceOpenStash según el tipo.
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
                -- Entrada de jugador: muestra ID, nombre y Steam
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
                -- Entrada de stash/maletero/guantera: muestra el identificador
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

--- Abre un stash específico desde el panel de admin (sin necesidad de proximidad).
RegisterNetEvent('DP-Inventory:client:ForceOpenStash', function(data)
    TriggerServerEvent("DP-Inventory:server:ForceOpenStash", data.identifier)
    QBCore.Functions.Notify("Abriendo: " .. data.identifier, "primary", 2500)
end)

--- Abre el inventario de otro jugador desde el panel de admin.
RegisterNetEvent('DP-Inventory:client:ForceOpenInventory', function(data)
    TriggerServerEvent("DP-Inventory:server:OpenInventory", "otherplayer", data.targetId)
    QBCore.Functions.Notify("Inspeccionando a " .. data.targetName, "primary", 2500)
end)

-- ============================================================
--  [8] NUI CALLBACKS
-- ============================================================

--- Reproduce el sonido de error al intentar dejar caer un ítem en un slot inválido.
RegisterNUICallback('PlayDropFail', function(_, cb)
    PlaySound(-1, 'Place_Prop_Fail', 'DLC_Dmod_Prop_Editor_Sounds', 0, 0, 1)
    cb('ok')
end)

--- Intenta realizar una compra en una tienda. Delega la lógica de dinero al servidor.
---
--- @param data  table  Datos de la compra (ítem, cantidad, precio, etc.)
--- @param cb    function  Callback NUI: cb(true/false) según si la compra fue exitosa
RegisterNUICallback('AttemptPurchase', function(data, cb)
    QBCore.Functions.TriggerCallback('DP-Inventory:server:attemptPurchase', function(canPurchase)
        cb(canPurchase)
    end, data)
end)

--- Cierra el inventario desde la UI. Gestiona:
---   · Ignorar el cierre si hay una transición de admin en curso
---   · Cerrar físicamente el maletero si el inventario era un 'trunk-'
---   · Liberar el lock del inventario secundario (stash, drop) en el servidor
---   · Resetear todos los flags de estado del cliente
RegisterNUICallback('CloseInventory', function(data, cb)
    if isTransitioningAdmin then
        cb('ok')
        return
    end

    isCursorModeActive = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    isInventoryOpen = false
    isOtherInventoryOpen = false

    if data.name then
        if data.name:find('trunk-') then
            CloseTrunk() -- Cierra la puerta del maletero físicamente (de vehicles.lua)
        end
        TriggerServerEvent('DP-Inventory:server:closeInventory', data.name)
    elseif CurrentDrop then
        -- Si se cerró un drop, liberamos su lock en el servidor
        TriggerServerEvent('DP-Inventory:server:closeInventory', CurrentDrop)
        CurrentDrop = nil
    end
    cb('ok')
end)

--- Alterna el modo cursor (tecla J): permite mover el ratón libremente por la UI
--- sin controlar la cámara del juego. Útil para UI con elementos en toda la pantalla.
RegisterNUICallback('toggleCursorMode', function(data, cb)
    isCursorModeActive = not isCursorModeActive

    if isCursorModeActive then
        -- Modo cursor: foco NUI pero SIN capturar el ratón (keepInput=true → WASD libre)
        SetNuiFocus(true, false)
        SetNuiFocusKeepInput(true)
    else
        -- Modo normal: foco NUI capturando el ratón
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
    end
    cb('ok')
end)

--- Usa un ítem desde la UI. Las armas tienen un delay de 100ms para evitar
--- conflictos con la animación de equip que lanza QB al usar el ítem.
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

--- Procesa un movimiento de ítem entre slots (drag & drop, split, swap).
--- El servidor es la autoridad: valida pesos, permisos y ejecuta el cambio.
---
--- @param data  table  {fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount}
RegisterNUICallback('SetInventoryData', function(data, cb)
    TriggerServerEvent('DP-Inventory:server:SetInventoryData', data.fromInventory, data.toInventory, data.fromSlot,
        data.toSlot, data.fromAmount, data.toAmount)
    cb('ok')
end)

--- Da un ítem a otro jugador cercano. El servidor valida proximidad y posesión.
---
--- @param data  table  {target (serverId), item, amount, slot, info}
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

--- Busca los jugadores en un radio de 10m y devuelve sus server IDs y nombres a la UI.
--- Usado para el selector de jugador al dar ítems.
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

--- Muestra una notificación de QBCore desde la UI (para eventos NUI que necesitan feedback).
RegisterNUICallback('Notify', function(data, cb)
    QBCore.Functions.Notify(data.message, data.type)
    cb('ok')
end)

--- Devuelve a la UI los datos del ítem arma y sus accesorios formateados.
--- Usado al abrir el panel de modificación de armas.
---
--- @param cData  table  {weapon (nombre), ItemData (ítem completo)}
--- @return       table  {WeaponData, AttachmentData}
RegisterNUICallback('GetWeaponData', function(cData, cb)
    local data = {
        WeaponData = QBCore.Shared.Items[cData.weapon],
        AttachmentData = FormatWeaponAttachments(cData.ItemData)
    }
    cb(data)
end)

--- Elimina un accesorio de un arma. Delega a qb-weapons en el servidor y
--- actualiza visualmente el componente en el ped si el arma está en mano.
---
--- @param data  table  {WeaponData, AttachmentData}
RegisterNUICallback('RemoveAttachment', function(data, cb)
    local ped = PlayerPedId()
    local WeaponData = data.WeaponData
    local allAttachments = exports['qb-weapons']:getConfigWeaponAttachments()
    local Attachment = allAttachments[data.AttachmentData.attachment][WeaponData.name]
    local itemInfo = QBCore.Shared.Items[data.AttachmentData.attachment]
    QBCore.Functions.TriggerCallback('qb-weapons:server:RemoveAttachment', function(NewAttachments)
        if NewAttachments ~= false then
            local Attachies = {}
            -- Eliminamos el componente visual del ped
            RemoveWeaponComponentFromPed(ped, joaat(WeaponData.name), joaat(Attachment))
            -- Reconstruimos la lista de accesorios activos para devolver a la UI
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
            -- El servidor falló pero eliminamos visualmente de todos modos
            RemoveWeaponComponentFromPed(ped, joaat(WeaponData.name), joaat(Attachment))
            cb({})
        end
    end, data.AttachmentData, WeaponData)
end)

--- Añade un accesorio a un arma. Delega a qb-weapons y aplica el componente
--- visualmente al ped si el arma está actualmente en mano.
---
--- @param data  table  {WeaponData, AttachmentItem}
RegisterNUICallback('AddAttachment', function(data, cb)
    local ped = PlayerPedId()
    local WeaponData = data.WeaponData
    local AttachmentItem = data.AttachmentItem
    local allAttachments = exports['qb-weapons']:getConfigWeaponAttachments()

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

        -- Si el arma está en mano, aplicamos el componente visual inmediatamente
        local currentWeapon = GetSelectedPedWeapon(ped)
        if currentWeapon == joaat(WeaponData.name) then
            GiveWeaponComponentToPed(ped, joaat(WeaponData.name), joaat(weaponComponent))
        end

        -- Reconstruimos la lista de accesorios para devolver a la UI
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

--- Callback principal de acciones contextuales del inventario.
--- Gestiona TODAS las acciones del menú de acciones (botón derecho en la UI):
---   · ROPA: quitar/cambiar prendas individuales
---   · PERSONAJE: amenazar, cachear, cargar, piggyback, Rockstar Editor
---   · ARMAS: estilos de apuntado, toggle/posición de armas a la espalda
---   · VEHÍCULO: motor, cierre, cambio de asiento, puertas, ventanillas, ancla
---
--- @param data  table  {action (string con el nombre de la acción)}
RegisterNUICallback('PerformAction', function(data, cb)
    local action = data.action
    local ped = PlayerPedId()

    -- ────────────────────────────────────────────────
    --  [ ACCIONES DE ROPA ]
    --  Ejecutan comandos nativos de qb-clothing para
    --  quitar/cambiar prendas individuales sin abrir el vestuario completo
    -- ────────────────────────────────────────────────
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

        -- ────────────────────────────────────────────────
        --  [ ACCIONES DE PERSONAJE ]
        -- ────────────────────────────────────────────────
    elseif action == 'amenazar' then
        ExecuteCommand('th')

    elseif action == 'cachear' then
        -- Requiere que el jugador objetivo tenga manos arriba, esté esposado o muerto.
        -- Usa una barra de progreso de 2.5s con animación de cacheo.
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

        -- ────────────────────────────────────────────────
        --  [ ROCKSTAR EDITOR ]
        --  Permite grabar clips desde el inventario con
        --  segmentación automática en 25s / 1min / 5min.
        -- ────────────────────────────────────────────────
    elseif action == 'rockstar_start' then
        StartRecording(1)
        QBCore.Functions.Notify("🔴 Grabación iniciada", "success", 3000)

    elseif action == 'rockstar_start_25' then
        -- Clips de 25 segundos con auto-guardado y reinicio
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
        -- Clips de 1 minuto con auto-guardado y reinicio
        if IsRecording() then
            QBCore.Functions.Notify("Ya hay una grabación activa.", "error", 3000)
        else
            StartRecording(1)
            QBCore.Functions.Notify("🔴 Grabando — clips de 1 minuto", "success", 3000)
            CreateThread(function()
                while IsRecording() do
                    Wait(55000) -- 55s para tener margen antes del corte del motor
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
        -- Clips de 5 minutos (límite real del motor: ~4.9min por clip)
        if IsRecording() then
            QBCore.Functions.Notify("Ya hay una grabación activa.", "error", 3000)
        else
            StartRecording(1)
            QBCore.Functions.Notify("🔴 Grabando — clips de 5 minutos", "success", 3000)
            CreateThread(function()
                while IsRecording() do
                    Wait(295000) -- 4.9min para respetar el límite del motor
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
        ActivateRockstarEditor() -- Abre el Rockstar Editor nativo de FiveM

        -- ────────────────────────────────────────────────
        --  [ ACCIONES DE ARMAS ]
        --  Estilos de apuntado: cambia la animación de apuntado del ped
        --  y lo publica en el state bag para que otros jugadores lo vean.
        --  Posiciones de armas a la espalda: delega en backitems.lua.
        -- ────────────────────────────────────────────────
    elseif action == 'aim_default' then
        currentAimStyle = joaat("Default")
        LocalPlayer.state:set('aimStyle', currentAimStyle, true) -- Publicamos en red
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
        -- Toggle de visibilidad de armas a la espalda (backitems.lua)
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

        -- ────────────────────────────────────────────────
        --  [ ACCIONES DE VEHÍCULO ]
        --  Solo se ejecutan si el jugador está dentro de un vehículo.
        -- ────────────────────────────────────────────────
    elseif string.find(action, "veh_") then
        local veh = GetVehiclePedIsIn(ped, false)

        if veh == 0 then
            QBCore.Functions.Notify("Debes estar en un vehículo.", "error")
            cb('ok')
            return
        end

        if action == 'veh_engine' then
            -- Alterna el motor encendido/apagado
            local isRunning = GetIsVehicleEngineRunning(veh)
            SetVehicleEngineOn(veh, not isRunning, false, true)
            QBCore.Functions.Notify(isRunning and "Motor Apagado" or "Motor Encendido", "primary")

        elseif action == 'veh_radio' then
            QBCore.Functions.Notify("¡PROXIMAMENTE DISPONIBLE!", "primary")

        elseif action == 'veh_keys' then
            -- Alterna el seguro de las puertas del vehículo
            local lockStatus = GetVehicleDoorLockStatus(veh)
            if lockStatus == 1 or lockStatus == 0 then
                SetVehicleDoorsLocked(veh, 2)
                QBCore.Functions.Notify("Vehículo Bloqueado", "error")
            else
                SetVehicleDoorsLocked(veh, 1)
                QBCore.Functions.Notify("Vehículo Desbloqueado", "success")
            end

            -- ── SISTEMAS DE CONDUCCIÓN ──
        elseif action == 'veh_drift' then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            -- Solo activo si eres el conductor (asiento -1)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                exports['DP-Utilitylib']:ToggleDrift(veh)
            else
                QBCore.Functions.Notify("Debes estar conduciendo un vehículo.", "error", 3000)
            end

        elseif action == 'veh_limitador' then
            exports['DP-Hud']:ToggleLimiter()

        elseif action == 'veh_crucero' then
            exports['DP-Hud']:ToggleCruise()

            -- ── CAMBIO DE ASIENTO ──
            -- Formato de action: 'veh_sit_di' (conductor), 'veh_sit_dd' (copiloto),
            -- 'veh_sit_ti' (trasero izq), 'veh_sit_td' (trasero der) o número directo
        elseif string.find(action, "veh_sit_") then
            local seatStr = action:gsub("veh_sit_", "")
            local seatIdx = nil

            if seatStr == "di" then
                seatIdx = -1 -- Conductor
            elseif seatStr == "dd" then
                seatIdx = 0 -- Copiloto
            elseif seatStr == "ti" then
                seatIdx = 1 -- Trasero izquierdo
            elseif seatStr == "td" then
                seatIdx = 2 -- Trasero derecho
            else
                seatIdx = tonumber(seatStr) -- Asiento numérico genérico
            end

            if seatIdx and IsVehicleSeatFree(veh, seatIdx) then
                SetPedIntoVehicle(ped, veh, seatIdx)
            end

            -- ── PUERTAS Y MALETEROS ──
            -- Toggle: si está abierta (ángulo > 0) la cierra, si está cerrada la abre

        elseif action == 'veh_hood' then
            local door = 4 -- Capó/motor
            if GetVehicleDoorAngleRatio(veh, door) > 0.0 then
                SetVehicleDoorShut(veh, door, false)
            else
                SetVehicleDoorOpen(veh, door, false, false)
            end

        elseif action == 'veh_trunk' then
            local door = 5 -- Maletero trasero
            if GetVehicleDoorAngleRatio(veh, door) > 0.0 then
                SetVehicleDoorShut(veh, door, false)
            else
                SetVehicleDoorOpen(veh, door, false, false)
            end

        elseif action == 'veh_door_fl' then
            local door = 0 -- Puerta frontal izquierda (conductor)
            if GetVehicleDoorAngleRatio(veh, door) > 0.0 then
                SetVehicleDoorShut(veh, door, false)
            else
                SetVehicleDoorOpen(veh, door, false, false)
            end

        elseif action == 'veh_door_fr' then
            local door = 1 -- Puerta frontal derecha (copiloto)
            if GetVehicleDoorAngleRatio(veh, door) > 0.0 then
                SetVehicleDoorShut(veh, door, false)
            else
                SetVehicleDoorOpen(veh, door, false, false)
            end

        elseif action == 'veh_door_rl' then
            local door = 2 -- Puerta trasera izquierda
            if GetVehicleDoorAngleRatio(veh, door) > 0.0 then
                SetVehicleDoorShut(veh, door, false)
            else
                SetVehicleDoorOpen(veh, door, false, false)
            end

        elseif action == 'veh_door_rr' then
            local door = 3 -- Puerta trasera derecha
            if GetVehicleDoorAngleRatio(veh, door) > 0.0 then
                SetVehicleDoorShut(veh, door, false)
            else
                SetVehicleDoorOpen(veh, door, false, false)
            end

            -- ── VENTANILLAS ──
            -- Toggle: si está intacta (entera) la baja, si está rota la sube

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

            -- ── SISTEMA DE ANCLA (Solo barcos, clase 14) ──
        elseif action == 'veh_anchor' then
            if GetVehicleClass(veh) == 14 then
                local isAnchored = Entity(veh).state.isAnchored

                if isAnchored then
                    -- QUITAR ANCLA: libera el barco
                    Entity(veh).state:set('isAnchored', false, true)
                    SetBoatAnchor(veh, false)
                    QBCore.Functions.Notify("Ancla recogida. Ya puedes navegar.", "success")
                else
                    -- ECHAR ANCLA: apaga motor y bloquea movimiento horizontal
                    Entity(veh).state:set('isAnchored', true, true)
                    SetVehicleEngineOn(veh, false, false, true)
                    SetBoatAnchor(veh, true)
                    QBCore.Functions.Notify("Ancla echada. El barco está asegurado a las olas.", "primary")

                    -- Thread de ancla: anula velocidad X/Y en cada frame mientras está anclado.
                    -- Permite el movimiento vertical (oleaje) pero no el desplazamiento.
                    CreateThread(function()
                        while Entity(veh).state.isAnchored do
                            Wait(0)
                            if not DoesEntityExist(veh) then
                                break -- Failsafe: el vehículo desapareció
                            end
                            local vel = GetEntityVelocity(veh)
                            -- Anulamos X e Y pero respetamos Z (subida/bajada por oleaje)
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

--- Cierra el inventario secundario desde la UI sin cerrar el primario.
--- Si era un maletero, lo cierra físicamente también.
RegisterNUICallback('CloseSecondaryInventory', function(data, cb)
    if data.name then
        if data.name:find('trunk-') then
            CloseTrunk() -- Cierra la puerta del maletero (vehicles.lua)
        end
        TriggerServerEvent('DP-Inventory:server:closeInventory', data.name)
    end
    cb('ok')
end)

--- Guarda el arma actualmente en mano y reproduce la animación de enfundado.
--- Incluye protección anti-spam con `isHolstering` y un timer de 1s.
--- Muestra el aviso visual de 'holster' (arma guardada) al completar.
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

        -- Animación de enfundado solo si no está en vehículo
        if not IsPedInAnyVehicle(ped, false) then
            LoadAnimDict('reaction@intimidation@1h')
            TaskPlayAnim(ped, 'reaction@intimidation@1h', 'outro', 8.0, 1.0, 1000, 48, 0, false, false, false)
        end

        -- Buscamos el nombre del arma para el aviso visual
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

        -- Reseteo del flag tras 1 segundo (duración aprox. de la animación)
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

--- Solicita al servidor todos los inventarios activos para el panel de admin.
--- La respuesta llega vía el evento 'DP-Inventory:client:OpenMasterMenu'.
RegisterNUICallback('GetAdminMasterData', function(_, cb)
    QBCore.Functions.TriggerCallback('DP-Inventory:server:GetAdminMasterData', function(data)
        cb(data)
    end)
end)

--- Abre el inventario de un jugador o un stash directamente desde el panel admin de la UI.
--- Activa `isTransitioningAdmin` para evitar que el CloseInventory normal interrumpa la transición.
---
--- @param data  table  {type ('player'|'stash'), id (serverId o stashId)}
RegisterNUICallback('ForceOpenAdmin', function(data, cb)
    isTransitioningAdmin = true
    if data.type == "player" then
        TriggerServerEvent("DP-Inventory:server:OpenInventory", "otherplayer", data.id)
    else
        TriggerServerEvent("DP-Inventory:server:ForceOpenStash", data.id)
    end
    -- Desactivamos el flag tras 1 segundo (margen para que llegue el nuevo inventario)
    SetTimeout(1000, function()
        isTransitioningAdmin = false
    end)
    cb('ok')
end)

--- Guarda la posición visual del inventario en el servidor y la aplica localmente.
--- @param data  table  {position (string)}
RegisterNUICallback('SaveInventoryPosition', function(data, cb)
    inventoryPosition = data.position
    TriggerServerEvent('DP-Inventory:server:SavePosition', data.position)
    QBCore.Functions.Notify("Posición del inventario guardada", "success")
    cb('ok')
end)

--- Notifica al cliente que el jugador está escribiendo/dejando de escribir en la UI.
--- Actualiza el foco NUI en tiempo real para que el teclado no mueva al personaje.
RegisterNUICallback('SetTypingFocus', function(data, cb)
    isTypingInUI = data.isTyping
    UpdateNuiFocus()
    cb('ok')
end)

--- Guarda la preferencia de movimiento con el inventario abierto.
--- Actualiza el foco NUI inmediatamente para aplicar el cambio en vivo.
RegisterNUICallback('SaveMovePreference', function(data, cb)
    moveWhileOpen = data.status
    TriggerServerEvent('DP-Inventory:server:SaveMovePref', data.status)
    UpdateNuiFocus()
    cb('ok')
end)

--- Guarda la preferencia de sonidos del inventario en el servidor.
RegisterNUICallback('SaveSoundPref', function(data, cb)
    TriggerServerEvent('DP-Inventory:server:SaveSoundPref', data.status)
    cb('ok')
end)

-- ============================================================
--  [9] EVENTOS DE INTEGRACIÓN EXTERNA (DP-Boombox)
-- ============================================================

--- Recibe el clic del botón de radio desde la UI y abre el Boombox.
--- Cierra el inventario primero para una transición limpia.
RegisterNUICallback('abrirRadioDesdeInventario', function(data, cb)
    -- Cerramos el inventario antes de abrir la radio
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "close"
    })
    TriggerEvent('DP-Inventory:client:closeInv')

    Wait(250) -- Pequeña espera para que la transición de cierre sea suave

    exports['DP-Boombox_v2']:OpenCarRadio()

    cb('ok')
end)

--- Actualización inmediata del estado de la radio cuando se instala/desinstala
--- en el vehículo actual (enviada por el Boombox sin que el jugador se baje).
RegisterNetEvent('DP-Inventory:client:UpdateVehicleRadio', function(status)
    SendNUIMessage({
        action = "updateVehicleRadio",
        status = status
    })
end)

-- ============================================================
--  SISTEMA NAVAJA RETRÁCTIL (SWITCHBLADE - TECLA G)
-- ============================================================
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
    GiveWeaponToPed(ped, HASH_KNUCKLE, 1, false, true)
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
    -- Hueso 57005 = Mano derecha (PH_R_Hand)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.03, -0.02, 180.0, 90.0, 0.0, true, true, false,
        true, 1, true)
    SetModelAsNoLongerNeeded(CLOSED_KNIFE_MODEL)
    switchbladeState.prop = prop
end

local function HolsterSwitchblade()
    local ped = PlayerPedId()
    DeleteSwitchbladeProp()
    RemoveWeaponFromPed(ped, HASH_KNUCKLE)
    RemoveWeaponFromPed(ped, HASH_SWITCHBLADE)
    SetPedCurrentWeaponVisible(ped, true, false, false, false)
    SetCurrentPedWeapon(ped, HASH_UNARMED, true)
    switchbladeState.holding = false
    switchbladeState.deployed = false
    switchbladeState.itemData = nil
end

--- Evento disparado desde server/main_server.lua al usar weapon_switchblade
RegisterNetEvent('DP-Inventory:client:ToggleSwitchblade', function(itemData)
    local ped = PlayerPedId()

    if switchbladeState.holding then
        HolsterSwitchblade()
        QBCore.Functions.Notify('Has guardado la navaja.', 'primary', 2000)
        return
    end

    -- Sale CERRADA en el puño cerrado (pega puñetazos)
    switchbladeState.lastToggle = GetGameTimer()
    switchbladeState.holding = true
    switchbladeState.deployed = false
    switchbladeState.itemData = itemData
    EquipClosedFist(ped)
    AttachClosedSwitchblade()
    QBCore.Functions.Notify('Navaja en mano (cerrada). Pulsa [G] para sacar la hoja.', 'primary', 3000)
end)

--- Comando y tecla G para desplegar / recoger la hoja
RegisterCommand('toggleSwitchblade', function()
    if not switchbladeState.holding then
        return
    end
    if isInventoryOpen or IsPauseMenuActive() then
        return
    end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return
    end

    switchbladeState.lastToggle = GetGameTimer()

    if not switchbladeState.deployed then
        -- DESPLEGAR HOJA
        DeleteSwitchbladeProp()
        RemoveWeaponFromPed(ped, HASH_KNUCKLE)
        SetPedCurrentWeaponVisible(ped, true, false, false, false)
        switchbladeState.deployed = true
        TriggerEvent('qb-weapons:client:UseWeapon', switchbladeState.itemData, true)
        QBCore.Functions.Notify('Hoja desplegada.', 'success', 1500)
    else
        -- RECOGER HOJA (vuelve a puño cerrado con prop en mano)
        switchbladeState.deployed = false
        RemoveWeaponFromPed(ped, HASH_SWITCHBLADE)
        EquipClosedFist(ped)
        AttachClosedSwitchblade()
        QBCore.Functions.Notify('Hoja recogida.', 'primary', 1500)
    end
end, false)

RegisterKeyMapping('toggleSwitchblade', 'Desplegar/Recoger hoja de navaja', 'keyboard', 'G')

-- Comando temporal para ajustar posición y rotación de la navaja cerrada
-- Uso: /navajapos x y z rx ry rz
RegisterCommand('navajapos', function(_, args)
    if not switchbladeState.prop or not DoesEntityExist(switchbladeState.prop) then
        return QBCore.Functions.Notify('Saca la navaja cerrada primero.', 'error')
    end

    local x = tonumber(args[1]) or 0.12
    local y = tonumber(args[2]) or 0.03
    local z = tonumber(args[3]) or -0.02
    local rx = tonumber(args[4]) or 180.0
    local ry = tonumber(args[5]) or 90.0
    local rz = tonumber(args[6]) or 0.0

    local ped = PlayerPedId()
    AttachEntityToEntity(switchbladeState.prop, ped, GetPedBoneIndex(ped, 57005), x, y, z, rx, ry, rz, true, true,
        false, true, 1, true)

    -- Imprime la línea lista para copiar en F8
    print(string.format(
        "AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 57005), %.3f, %.3f, %.3f, %.1f, %.1f, %.1f, true, true, false, true, 1, true)",
        x, y, z, rx, ry, rz))
end, false)

--- Vigilante: mantiene oculta la nudillera y limpia solo si cambia a OTRA arma, muere o la pierde
CreateThread(function()
    while true do
        Wait(500)
        if switchbladeState.holding and (GetGameTimer() - switchbladeState.lastToggle > 1000) then
            local ped = PlayerPedId()
            local currentWeap = GetSelectedPedWeapon(ped)

            if not HasItem('weapon_switchblade', 1) or IsEntityDead(ped) then
                HolsterSwitchblade()
            elseif not switchbladeState.deployed then
                if currentWeap == HASH_KNUCKLE then
                    SetPedCurrentWeaponVisible(ped, false, false, false, false)
                elseif currentWeap ~= HASH_UNARMED then
                    -- Solo guardamos si saca otra arma distinta (pistola, bate, etc.)
                    HolsterSwitchblade()
                end
            elseif switchbladeState.deployed and currentWeap ~= HASH_SWITCHBLADE and currentWeap ~= HASH_UNARMED then
                HolsterSwitchblade()
            end
        end
    end
end)

--- Limpieza instantánea si el recurso se detiene desde consola (evita props huérfanos y crasheos)
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
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

--- Evento para guardar la navaja con animación antes de un reinicio seguro
RegisterNetEvent('DP-Inventory:client:SafeHolsterBeforeRestart', function()
    if switchbladeState and switchbladeState.holding then
        local ped = PlayerPedId()
        HolsterSwitchblade()
        if not IsPedInAnyVehicle(ped, false) then
            LoadAnimDict('reaction@intimidation@1h')
            TaskPlayAnim(ped, 'reaction@intimidation@1h', 'outro', 8.0, 1.0, 900, 48, 0, false, false, false)
        end
    end
end)

-- ============================================================
--  [10] EXPORTS PARA OTROS RECURSOS
-- ============================================================

--- Abre el inventario de otro jugador desde un recurso externo (ej: DP-AdminMenu).
--- Requiere que el jugador local tenga los permisos adecuados (el servidor lo valida).
---
--- Uso: exports['DP-Inventory']:OpenPlayerInventory(targetId)
--- @param targetId  number  Server ID del jugador objetivo
exports('OpenPlayerInventory', function(targetId)
    if not targetId then
        return
    end
    TriggerServerEvent("DP-Inventory:server:OpenInventory", "otherplayer", targetId)
end)

--- Abre un stash/maletero/guantera específico desde un recurso externo.
--- El servidor valida permisos antes de abrirlo.
---
--- Uso: exports['DP-Inventory']:OpenStash(stashId)
--- @param stashId  string  Identificador del inventario (ej: 'trunk-ABC123', 'stash_banco')
exports('OpenStash', function(stashId)
    if not stashId then
        return
    end
    TriggerServerEvent("DP-Inventory:server:ForceOpenStash", stashId)
end)
