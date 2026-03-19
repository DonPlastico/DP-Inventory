-- ============================================================
--  DP-INVENTORY · server/backpack_sv.lua
--  Sistema de mochilas en el servidor: apertura como stash,
--  desbordamiento al quitarse la mochila y peso dinámico.
--
--  ÍNDICE DE CONTENIDOS
--  ─────────────────────────────────────────────────────────
--  [1]  ExpanderBags         – tabla legacy de bonus de slots
--  [2]  CheckBackpackUnequip – desbordamiento al quitarse mochila
--  [3]  GenerateBagId        – generador de IDs únicas
--  [4]  Registro dinámico    – mochilas usables con stash propio
--  [5]  UpdateBagWeight      – cálculo de peso dinámico al cerrar
-- ============================================================
local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
--  [1] ExpanderBags (sistema legacy)
--  Tabla de bonus de slots extra por tipo de mochila.
--  Usada por CheckBackpackUnequip para calcular cuántos slots
--  tiene el jugador según la mochila equipada en el slot 101.
--  Nota: el sistema nuevo usa itemData.bagSlots directamente
--  desde QBCore.Shared.Items.
-- ============================================================

-- ==========================================================================
-- CONFIGURACIÓN: MOCHILAS EXPANSORAS (SISTEMA ANTIGUO)
-- ==========================================================================
local ExpanderBags = {
    ['backpack_1'] = 5, -- +5 slots sobre maxBaseSlots
    ['backpack_2'] = 10,
    ['backpack_3'] = 15,
    ['backpack_4'] = 20 -- +20 slots
}

-- ============================================================
--  [2] CheckBackpackUnequip
--  Se ejecuta cuando el jugador mueve algo al/desde el slot 101
--  (slot de mochila equipada) en SetInventoryData de main_server.lua.
--
--  Flujo:
--    1. Calcula cuántos slots permite la mochila actual (o base si no hay).
--    2. Busca ítems en slots > allowedSlots (que ya no caben).
--    3. Por cada ítem huérfano: lo retira del inventario y lo añade a un drop.
--    4. Crea la entidad física de la bolsa y la registra en `Drops`.
--    5. Notifica al cliente y fuerza actualización de la UI.
--
--  @param source  number  Server ID del jugador
-- ============================================================
function CheckBackpackUnequip(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local maxBaseSlots = 41 -- Debe coincidir con Config.MaxSlots
    local allowedSlots = maxBaseSlots

    -- Comprobamos si tiene una mochila expansora equipada en el slot 101
    local bagItem = Player.PlayerData.items[101]
    if bagItem and ExpanderBags[bagItem.name] then
        allowedSlots = maxBaseSlots + ExpanderBags[bagItem.name]
    end

    local itemsToDrop = {}
    local dropSlotIndex = 1

    -- Buscamos ítems en slots "en el limbo" (por encima de los slots permitidos)
    -- Ignoramos slots de equipamiento (>= 100) y solo procesamos numéricos < 100
    for slot, item in pairs(Player.PlayerData.items) do
        if type(slot) == "number" and slot > allowedSlots and slot < 100 then
            -- Clonamos el ítem y le reasignamos un slot desde 1 para el drop
            local dropItem = item
            dropItem.slot = dropSlotIndex
            itemsToDrop[dropSlotIndex] = dropItem
            dropSlotIndex = dropSlotIndex + 1

            -- Eliminamos del inventario de forma segura
            Player.Functions.RemoveItem(item.name, item.amount, slot)
        end
    end

    -- Solo creamos el drop si hay ítems que colocar en él
    if #itemsToDrop > 0 then
        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)

        -- Creamos la entidad física de la bolsa junto al jugador
        local bag = CreateObjectNoOffset(Config.ItemDropObject or joaat('prop_paper_bag_small'), coords.x + 0.5,
            coords.y + 0.5, coords.z, true, true, false)
        local dropId = NetworkGetNetworkIdFromEntity(bag)
        local newDropId = 'drop-' .. dropId

        -- Registramos el drop en la tabla global (mismo formato que createDrop)
        Drops[newDropId] = {
            name = newDropId,
            label = 'Objetos Caídos',
            items = itemsToDrop,
            entityId = dropId,
            createdTime = os.time(),
            coords = coords,
            maxweight = 200000, -- Peso holgado para garantizar que caben todos
            slots = #itemsToDrop,
            isOpen = false,
            isHeld = false
        }

        -- Notificamos a todos los clientes para que el sistema de drops lo detecte
        TriggerClientEvent('DP-Inventory:client:setupDropTarget', -1, dropId)

        -- Feedback al jugador y actualización forzada de la UI
        TriggerClientEvent('QBCore:Notify', src, '¡Tus objetos se han caído al quitarte la mochila!', 'error', 6000)
        TriggerClientEvent('DP-Inventory:client:updateInventory', src)
    end
end

-- ============================================================
--  [3] GenerateBagId
--  Genera un ID único de 10 caracteres (prefijo 'bag_' + 6 aleatorios)
--  para identificar el stash propio de cada mochila.
--  Se asigna la primera vez que el jugador usa la mochila y se
--  guarda en item.info.bagid para persistir entre sesiones.
--
--  Formato: 'bag_XXXXXX' (letras mayúsculas/minúsculas y dígitos)
--  @return  string  ID único de mochila
-- ============================================================

-- ==========================================================================
-- 1. FUNCIÓN AUXILIAR: GENERADOR DE IDS ÚNICAS PARA MOCHILAS
-- ==========================================================================
local function GenerateBagId()
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local id = 'bag_'
    for i = 1, 6 do
        local rand = math.random(1, #chars)
        id = id .. string.sub(chars, rand, rand)
    end
    return id
end

-- ============================================================
--  [4] Registro dinámico de mochilas usables
--  Al arrancar el recurso, itera todos los ítems de QBCore que
--  tengan el campo `bagSlots` definido y los registra como
--  ítems usables con su propio callback de apertura de stash.
--
--  Campos requeridos en QBCore.Shared.Items para activar este sistema:
--    · bagSlots     → número de slots del stash de la mochila
--    · bagMaxWeight → peso máximo del stash de la mochila
--
--  Flujo al usar la mochila:
--    1. Si es nueva (sin bagid), genera ID y guarda en item.info.
--    2. Busca el stash en RAM (Inventories) o en BD.
--    3. Si no existe en BD, lo crea con INSERT.
--    4. Marca el stash como abierto (lock) por este jugador.
--    5. Abre la UI del inventario con el stash formateado.
-- ============================================================

-- ==========================================================================
-- 2. REGISTRO DINÁMICO DE MOCHILAS (USABLES CON STASH DIRECTO)
-- ==========================================================================
CreateThread(function()
    for itemName, itemData in pairs(QBCore.Shared.Items) do
        if itemData.bagSlots then
            QBCore.Functions.CreateUseableItem(itemName, function(source, item)
                local src = source
                local Player = QBCore.Functions.GetPlayer(src)
                if not Player or not item then
                    return
                end

                -- Asignamos un ID único a la mochila si es la primera vez que se usa
                if not item.info or not item.info.bagid then
                    item.info = item.info or {}
                    item.info.bagid = GenerateBagId()

                    -- Guardamos el nuevo ID en el inventario del jugador
                    Player.PlayerData.items[item.slot] = item
                    Player.Functions.SetInventory(Player.PlayerData.items)
                end

                local bagId = item.info.bagid

                -- Carga el stash: primero busca en RAM, luego en BD
                if not Inventories[bagId] then
                    local result = MySQL.Sync.fetchAll('SELECT items FROM inventories WHERE identifier = ?', {bagId})
                    if result[1] and result[1].items then
                        -- Existe en BD: lo cargamos en RAM con todos sus metadatos
                        Inventories[bagId] = {
                            items = json.decode(result[1].items) or {},
                            isOpen = false,
                            maxweight = itemData.bagMaxWeight,
                            slots = itemData.bagSlots,
                            label = itemData.label or 'Mochila'
                        }
                    else
                        -- No existe: lo creamos de cero en RAM y en BD
                        Inventories[bagId] = {
                            items = {},
                            isOpen = false,
                            maxweight = itemData.bagMaxWeight,
                            slots = itemData.bagSlots,
                            label = itemData.label or 'Mochila'
                        }
                        MySQL.Async.execute('INSERT INTO inventories (identifier, items) VALUES (?, ?)', {bagId, '[]'})
                    end
                else
                    -- Parche de seguridad: si ya estaba en RAM pero sin metadatos, los inyectamos
                    Inventories[bagId].maxweight = itemData.bagMaxWeight
                    Inventories[bagId].slots = itemData.bagSlots
                    Inventories[bagId].label = itemData.label or 'Mochila'
                end

                -- Lock: marcamos quién está usando esta mochila (impide apertura simultánea)
                Inventories[bagId].isOpen = src

                -- Formateamos la estructura que espera la UI de Vue.js
                local formattedInventory = {
                    name = bagId,
                    label = itemData.label or 'Mochila',
                    maxweight = itemData.bagMaxWeight,
                    slots = itemData.bagSlots,
                    inventory = Inventories[bagId].items
                }

                -- Abrimos el inventario directamente (sin pasar por backpack_cl.lua)
                TriggerClientEvent('DP-Inventory:client:openInventory', src, Player.PlayerData.items, formattedInventory)
            end)
        end
    end
end)

-- ============================================================
--  [5] UpdateBagWeight
--  Llamado desde closeInventory de main_server.lua cuando el
--  identificador empieza por 'bag_'.
--
--  Calcula el peso total del contenido de la mochila y lo guarda
--  en item.info.weight del ítem mochila en el inventario del jugador.
--  Este peso dinámico puede ser usado por la UI para mostrarlo.
--
--  Fórmula: peso_dinámico = floor(pesoTotalInterior / 3)
--  (División por 3 para penalizar el peso sin ser tan restrictivo)
--
--  @param src    number  Server ID del jugador
--  @param bagId  string  ID del stash de la mochila ('bag_XXXXXX')
-- ============================================================

-- ==========================================================================
-- 3. CÁLCULO DE PESO DINÁMICO AL CERRAR LA MOCHILA
-- ==========================================================================
AddEventHandler('DP-Inventory:server:UpdateBagWeight', function(src, bagId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    -- Validación: solo procesamos IDs que empiecen por 'bag_'
    if type(bagId) ~= "string" or not string.find(bagId, "^bag_") then
        return
    end

    -- Obtenemos los ítems del interior de la mochila (RAM primero, BD como fallback)
    local bagItems = {}
    if Inventories[bagId] and Inventories[bagId].items then
        bagItems = Inventories[bagId].items
    else
        local result = MySQL.Sync.fetchAll('SELECT items FROM inventories WHERE identifier = ?', {bagId})
        if result[1] and result[1].items then
            bagItems = json.decode(result[1].items) or {}
        end
    end

    -- Sumamos el peso total de todos los ítems dentro de la mochila
    local totalInternalWeight = 0
    for _, item in pairs(bagItems) do
        if item and item.name then
            local sharedItem = QBCore.Shared.Items[item.name:lower()]
            if sharedItem and sharedItem.weight then
                totalInternalWeight = totalInternalWeight + (sharedItem.weight * item.amount)
            end
        end
    end

    -- Aplicamos la fórmula: el jugador "carga" 1/3 del peso interior
    local dynamicWeight = math.floor(totalInternalWeight / 3)

    -- Buscamos la mochila en el inventario del jugador y actualizamos su peso
    local bagFoundAndUpdated = false
    for slot, item in pairs(Player.PlayerData.items) do
        if item.info and item.info.bagid == bagId then
            item.info.weight = dynamicWeight
            Player.PlayerData.items[slot] = item
            bagFoundAndUpdated = true
            break
        end
    end

    -- Solo guardamos si encontramos la mochila (evita escrituras innecesarias a BD)
    if bagFoundAndUpdated then
        Player.Functions.SetInventory(Player.PlayerData.items)
        TriggerClientEvent('DP-Inventory:client:updateInventory', src)
    end
end)
