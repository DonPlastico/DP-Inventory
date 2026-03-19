-- ============================================================
--  DP-INVENTORY · server/functions.lua
--  Funciones del lado servidor: CRUD de inventario, pesos,
--  slots, tiendas, stashes y utilidades de ítems.
--
--  ÍNDICE DE CONTENIDOS
--  ─────────────────────────────────────────────────────────
--  [1]  FUNCIONES LOCALES (internas, no exportadas)
--         · InitializeInventory
--         · GetFirstFreeSlot
--         · SetupShopItems
--
--  [2]  FUNCIONES EXPORTADAS – CARGA / GUARDADO
--         · LoadInventory
--         · SaveInventory
--         · SetInventory
--
--  [3]  FUNCIONES EXPORTADAS – METADATOS DE ÍTEMS
--         · SetItemData
--         · UseItem
--
--  [4]  FUNCIONES EXPORTADAS – BÚSQUEDA / CONSULTA
--         · GetSlotsByItem
--         · GetFirstSlotByItem
--         · GetItemBySlot
--         · GetTotalWeight
--         · GetItemByName
--         · GetItemsByName
--         · GetSlots
--         · GetItemCount
--         · GetFreeWeight
--
--  [5]  FUNCIONES EXPORTADAS – VALIDACIÓN
--         · CanAddItem
--         · HasItem
--
--  [6]  FUNCIONES EXPORTADAS – GESTIÓN DE INVENTARIO
--         · ClearInventory
--         · CloseInventory
--         · OpenInventoryById
--         · ClearStash
--         · OpenInventory
--         · CreateInventory
--         · GetInventory
--         · RemoveInventory
--         · AddItem
--         · RemoveItem
--
--  [7]  FUNCIONES EXPORTADAS – TIENDAS (SHOPS)
--         · CreateShop
--         · OpenShop
--
--  NOTA: Las funciones aparecen DOS veces en este archivo
--  (versión legacy ~línea 1 y versión refactorizada ~línea 900).
--  La versión activa en runtime es la SEGUNDA (la de abajo),
--  ya que en Lua la última definición sobreescribe a la anterior.
--  Ambas están documentadas para mayor claridad del equipo.
-- ============================================================
-- ============================================================
--  [BLOQUE LEGACY – primera definición]
--  Este bloque existía antes de la refactorización.
--  Las funciones de este bloque quedan SOBREESCRITAS por las
--  definiciones que aparecen a partir de la línea ~900.
--  Se conservan por historial / compatibilidad de revisión.
-- ============================================================
-- ============================================================
--  [1] FUNCIONES LOCALES
--  No están disponibles fuera de este archivo.
--  Son helpers internos usados por las funciones exportadas.
-- ============================================================
--- Inicializa una entrada nueva en la tabla global `Inventories`.
--- Si `data` se omite se usan los valores por defecto de Config.StashSize.
---
--- @param inventoryId  string  Identificador único del inventario (ej: "stash_banco")
--- @param data         table|nil  {label, maxweight, slots} – todos opcionales
--- @return             table  La tabla del inventario recién creada
local function InitializeInventory(inventoryId, data)
    Inventories[inventoryId] = {
        items = {}, -- Tabla de ítems vacía
        isOpen = false, -- Flag: ¿está siendo usado ahora mismo?
        label = data and data.label or inventoryId, -- Nombre visible en la UI
        maxweight = data and data.maxweight or Config.StashSize.maxweight, -- Peso máximo permitido
        slots = data and data.slots or Config.StashSize.slots -- Número de slots disponibles
    }
    return Inventories[inventoryId]
end

--- Devuelve el primer índice de slot libre dentro de una tabla de ítems.
--- Itera de 1 a maxSlots buscando el primer hueco `nil`.
---
--- @param items     table  Tabla de ítems indexada por número de slot
--- @param maxSlots  number  Número total de slots del inventario
--- @return          number|nil  Número del slot libre, o nil si está lleno
local function GetFirstFreeSlot(items, maxSlots)
    for i = 1, maxSlots do
        if items[i] == nil then
            return i
        end
    end
    return nil
end

--- Convierte la lista de ítems de una tienda (config) al formato
--- interno del inventario, enriqueciendo cada ítem con la info
--- del catálogo global `QBCore.Shared.Items`.
--- Los ítems que no existan en el catálogo son ignorados silenciosamente.
---
--- @param shopItems  table  Array de {name, amount, info, price} de la config
--- @return           table  Tabla de ítems con formato completo, indexada por slot
local function SetupShopItems(shopItems)
    local items = {}
    local slot = 1
    if shopItems and next(shopItems) then
        for _, item in pairs(shopItems) do
            local itemInfo = QBCore.Shared.Items[item.name:lower()]
            if itemInfo then
                items[slot] = {
                    name = itemInfo['name'],
                    amount = tonumber(item.amount), -- Cantidad en stock mostrada
                    info = item.info or {}, -- Metadatos extra (ej: calidad, serie)
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'], -- 'item' | 'weapon' | 'ammo'
                    unique = itemInfo['unique'],
                    useable = itemInfo['useable'],
                    price = item.price, -- Precio de venta en la tienda
                    image = itemInfo['image'],
                    slot = slot
                }
                slot = slot + 1
            end
        end
    end
    return items
end

-- ============================================================
--  [2] FUNCIONES EXPORTADAS – CARGA / GUARDADO  (versión legacy)
-- ============================================================

--- Carga el inventario de un jugador desde la base de datos.
--- Valida cada ítem contra el catálogo global; los ítems que ya
--- no existan en el catálogo son descartados y se imprime un aviso.
---
--- EXPORT: exports['DP-Inventory']:LoadInventory(source, citizenid)
---
--- @param source     number  Server ID del jugador (puede ser nil en carga offline)
--- @param citizenid  string  Ciudadano ID único del jugador
--- @return           table   Inventario indexado por slot, listo para asignar a PlayerData
function LoadInventory(source, citizenid)
    local inventory = MySQL.prepare.await('SELECT inventory FROM players WHERE citizenid = ?', {citizenid})
    local loadedInventory = {}
    local missingItems = {}
    inventory = json.decode(inventory)
    if not inventory or not next(inventory) then
        return loadedInventory -- Inventario vacío → devolvemos tabla vacía
    end

    for _, item in pairs(inventory) do
        if item then
            local itemInfo = QBCore.Shared.Items[item.name:lower()]

            if itemInfo then
                -- Reconstruimos el ítem con datos frescos del catálogo
                loadedInventory[item.slot] = {
                    name = itemInfo['name'],
                    amount = item.amount,
                    info = item.info or '',
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'],
                    unique = itemInfo['unique'],
                    useable = itemInfo['useable'],
                    image = itemInfo['image'],
                    shouldClose = itemInfo['shouldClose'], -- Si al usar cierra el inventario
                    slot = item.slot,
                    combinable = itemInfo['combinable'] -- Datos de combinación de ítems
                }
            else
                -- El ítem ya no existe en QBCore.Shared.Items → se elimina
                missingItems[#missingItems + 1] = item.name:lower()
            end
        end
    end

    -- Aviso en consola si se eliminaron ítems obsoletos
    if #missingItems > 0 then
        print(('The following items were removed for player %s as they no longer exist: %s'):format(source and
                                                                                                        GetPlayerName(
                source) or citizenid, table.concat(missingItems, ', ')))
    end

    return loadedInventory
end

exports('LoadInventory', LoadInventory)

--- Guarda el inventario de un jugador en la base de datos.
--- Soporta modo offline (pasando PlayerData directamente en lugar de source).
---
--- EXPORT: exports['DP-Inventory']:SaveInventory(source, offline)
---
--- @param source   number|table  Server ID del jugador, o PlayerData si offline=true
--- @param offline  boolean|nil   Si es true, `source` es la PlayerData directamente
function SaveInventory(source, offline)
    local PlayerData
    if offline then
        -- En modo offline se recibe PlayerData directamente (sin servidor activo)
        PlayerData = source
    else
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then
            return
        end
        PlayerData = Player.PlayerData
    end

    local items = PlayerData.items
    local ItemsJson = {}

    if items and next(items) then
        -- Serializamos solo los campos necesarios para la BD (no guardamos label, image, etc.)
        for slot, item in pairs(items) do
            if item then
                ItemsJson[#ItemsJson + 1] = {
                    name = item.name,
                    amount = item.amount,
                    info = item.info,
                    type = item.type,
                    slot = slot
                }
            end
        end
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?',
            {json.encode(ItemsJson), PlayerData.citizenid})
    else
        -- Sin ítems → guardamos JSON vacío para evitar NULL en BD
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', {'[]', PlayerData.citizenid})
    end
end

exports('SaveInventory', SaveInventory)

--- Reemplaza TODOS los ítems de un inventario (jugador, drop o stash).
--- Genera log en qb-log con el motivo del cambio y el recurso que lo invocó.
---
--- EXPORT: exports['DP-Inventory']:SetInventory(identifier, items, reason)
---
--- @param identifier  number|string  Server ID del jugador, o ID del inventario
--- @param items       table          Nueva tabla de ítems completa
--- @param reason      string|nil     Motivo del cambio (para logs)
-- Sets the items in a inventory.
function SetInventory(identifier, items, reason)
    local player = QBCore.Functions.GetPlayer(identifier)

    print('Setting inventory for ' .. identifier)

    if not player and not Inventories[identifier] and not Drops[identifier] then
        print('SetInventory: Inventory not found')
        return
    end

    if player then
        -- Jugador online → actualizamos a través de QB para sincronizar con el cliente
        player.Functions.SetPlayerData('items', items)
        if not player.Offline then
            local logMessage = string.format('**%s (citizenid: %s | id: %s)** items set: %s', GetPlayerName(identifier),
                player.PlayerData.citizenid, identifier, json.encode(items))
            TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'SetInventory', 'blue', logMessage)
        end
    elseif Drops[identifier] then
        -- Drop en el suelo → actualizamos su tabla en memoria
        Drops[identifier].items = items
    elseif Inventories[identifier] then
        -- Stash / inventario especial → actualizamos en memoria
        Inventories[identifier].items = items
    end

    -- Log global con contexto completo (inventario, ítems, motivo, recurso)
    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local setReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'DP-Inventory'
    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'Inventory Set', 'blue',
        '**Inventory:** ' .. invName .. '\n' .. '**Items:** ' .. json.encode(items) .. '\n' .. '**Reason:** ' ..
            setReason .. '\n' .. '**Resource:** ' .. resourceName)
end

exports('SetInventory', SetInventory)

-- ============================================================
--  [3] FUNCIONES EXPORTADAS – METADATOS DE ÍTEMS  (legacy)
-- ============================================================

--- Modifica el valor de una clave específica dentro del campo `info`
--- (o cualquier campo raíz) de un ítem en el inventario de un jugador.
--- Puede buscar el ítem por nombre o por slot exacto.
---
--- EXPORT: exports['DP-Inventory']:SetItemData(source, itemName, key, val, slot)
---
--- @param source    number      Server ID del jugador
--- @param itemName  string      Nombre del ítem a modificar
--- @param key       string      Clave a establecer (ej: 'info.quality', 'amount')
--- @param val       any         Valor nuevo
--- @param slot      number|nil  Slot exacto (opcional; si se omite busca por nombre)
--- @return          boolean     true si se modificó, false en caso de error
-- Sets the value of a specific key in the data of an item for a player.
function SetItemData(source, itemName, key, val, slot)
    if not itemName or not key then
        return false
    end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return
    end
    local item
    if slot then
        -- Búsqueda directa por slot (más rápido, O(1))
        item = Player.PlayerData.items[tonumber(slot)]
        if not item or item.name:lower() ~= itemName:lower() then
            return false -- El slot existe pero no coincide el nombre
        end
    else
        -- Búsqueda lineal por nombre
        item = GetItemByName(source, itemName)
        if not item then
            return false
        end
    end
    item[key] = val
    Player.PlayerData.items[item.slot] = item
    Player.Functions.SetPlayerData('items', Player.PlayerData.items)
    return true
end

exports('SetItemData', SetItemData)

--- Ejecuta el callback registrado para un ítem usable.
--- Internamente usa `QBCore.Functions.CanUseItem` para obtener la función.
---
--- EXPORT: exports['DP-Inventory']:UseItem(itemName, ...)
---
--- @param itemName  string  Nombre del ítem a usar
--- @param ...       any     Parámetros adicionales que recibe el callback del ítem
function UseItem(itemName, ...)
    local itemData = QBCore.Functions.CanUseItem(itemName)
    if type(itemData) == 'table' and itemData.func then
        itemData.func(...)
    end
end

exports('UseItem', UseItem)

-- ============================================================
--  [4] FUNCIONES EXPORTADAS – BÚSQUEDA / CONSULTA  (legacy)
-- ============================================================

--- Devuelve TODOS los números de slot que contengan un ítem con el nombre dado.
--- Útil cuando hay múltiples stacks del mismo ítem (ej: armas o ítems únicos duplicados).
---
--- EXPORT: exports['DP-Inventory']:GetSlotsByItem(items, itemName)
---
--- @param items     table   Tabla de ítems indexada por slot
--- @param itemName  string  Nombre del ítem a buscar (case-insensitive)
--- @return          table   Array de números de slot donde se encontró el ítem
-- Retrieves the slots in the items table that contain a specific item.
function GetSlotsByItem(items, itemName)
    local slotsFound = {}
    if not items then
        return slotsFound
    end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            slotsFound[#slotsFound + 1] = slot
        end
    end
    return slotsFound
end

exports('GetSlotsByItem', GetSlotsByItem)

--- Devuelve el PRIMER slot que contenga un ítem con el nombre dado.
--- Equivalente a `GetSlotsByItem` pero se detiene en el primero encontrado.
---
--- EXPORT: exports['DP-Inventory']:GetFirstSlotByItem(items, itemName)
---
--- @param items     table   Tabla de ítems indexada por slot
--- @param itemName  string  Nombre del ítem a buscar (case-insensitive)
--- @return          number|nil  Número del slot, o nil si no se encontró
-- Retrieves the first slot number that contains an item with the specified name.
function GetFirstSlotByItem(items, itemName)
    if not items then
        return
    end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            return tonumber(slot)
        end
    end
    return nil
end

exports('GetFirstSlotByItem', GetFirstSlotByItem)

--- Devuelve el ítem completo ubicado en un slot específico del inventario de un jugador.
---
--- EXPORT: exports['DP-Inventory']:GetItemBySlot(source, slot)
---
--- @param source  number  Server ID del jugador
--- @param slot    number  Número de slot a consultar
--- @return        table|nil  Tabla del ítem, o nil si el slot está vacío o el jugador no existe
--- Retrieves an item from a player's inventory based on the specified slot.
function GetItemBySlot(source, slot)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return
    end
    local items = Player.PlayerData.items
    return items[tonumber(slot)]
end

exports('GetItemBySlot', GetItemBySlot)

--- Calcula el peso total de todos los ítems en una tabla de inventario.
--- Si `amount` no es numérico se asume 1 para evitar errores.
---
--- EXPORT: exports['DP-Inventory']:GetTotalWeight(items)
---
--- @param items  table  Tabla de ítems indexada por slot
--- @return       number  Peso total en gramos/unidades de config
function GetTotalWeight(items)
    if not items then
        return 0
    end
    local weight = 0
    for _, item in pairs(items) do
        local amount = item.amount
        if type(amount) ~= 'number' then
            amount = 1
        end

        weight = weight + (item.weight * amount)
    end
    return tonumber(weight)
end

exports('GetTotalWeight', GetTotalWeight)

--- Devuelve el primer ítem con el nombre dado del inventario de un jugador.
--- Sólo devuelve UNA instancia (usa GetFirstSlotByItem internamente).
---
--- EXPORT: exports['DP-Inventory']:GetItemByName(source, item)
---
--- @param source  number  Server ID del jugador
--- @param item    string  Nombre del ítem (case-insensitive)
--- @return        table|nil  Tabla del ítem encontrado, o nil
-- Retrieves an item from a player's inventory by its name.
function GetItemByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return
    end
    local items = Player.PlayerData.items
    local slot = GetFirstSlotByItem(items, tostring(item):lower())
    return items[slot]
end

exports('GetItemByName', GetItemByName)

--- Devuelve TODOS los ítems con el nombre dado del inventario de un jugador.
--- A diferencia de GetItemByName, recorre todos los slots y devuelve un array.
---
--- EXPORT: exports['DP-Inventory']:GetItemsByName(source, item)
---
--- @param source  number  Server ID del jugador
--- @param item    string  Nombre del ítem (case-insensitive)
--- @return        table   Array de tablas de ítems (puede estar vacío)
-- Retrieves a list of items with a specific name from a player's inventory.
function GetItemsByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return
    end
    local PlayerItems = Player.PlayerData.items
    item = tostring(item):lower()
    local items = {}
    for _, slot in pairs(GetSlotsByItem(PlayerItems, item)) do
        if slot then
            items[#items + 1] = PlayerItems[slot]
        end
    end
    return items
end

exports('GetItemsByName', GetItemsByName)

--- Devuelve el número de slots usados y slots libres de un inventario.
--- Funciona con jugadores, stashes y drops.
---
--- EXPORT: exports['DP-Inventory']:GetSlots(identifier)
---
--- @param identifier  number|string  Server ID del jugador, o ID del inventario
--- @return            number, number  (slotsUsados, slotslibres)
--- Retrieves the total count of used and free slots for a player or an inventory.
function GetSlots(identifier)
    local inventory, maxSlots
    local player = QBCore.Functions.GetPlayer(identifier)
    if player then
        inventory = player.PlayerData.items
        maxSlots = Config.MaxSlots
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
        maxSlots = Inventories[identifier].slots
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
        maxSlots = Drops[identifier].slots
    end
    if not inventory then
        return 0, maxSlots
    end
    local slotsUsed = 0
    for _, v in pairs(inventory) do
        if v then
            slotsUsed = slotsUsed + 1
        end
    end
    local slotsFree = maxSlots - slotsUsed
    return slotsUsed, slotsFree
end

exports('GetSlots', GetSlots)

--- Cuenta el total de unidades de uno o varios ítems en el inventario de un jugador.
--- Acepta un string (un ítem) o una tabla (varios ítems, suma todos).
---
--- EXPORT: exports['DP-Inventory']:GetItemCount(source, items)
---
--- @param source  number        Server ID del jugador
--- @param items   string|table  Nombre del ítem, o array de nombres
--- @return        number        Cantidad total acumulada
--- Retrieves the total count of specified items for a player.
function GetItemCount(source, items)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return
    end
    -- Optimización: si es tabla creamos un set para lookup O(1)
    local isTable = type(items) == 'table'
    local itemsSet = isTable and {} or nil
    if isTable then
        for _, item in pairs(items) do
            itemsSet[item] = true
        end
    end
    local count = 0
    for _, item in pairs(Player.PlayerData.items) do
        if (isTable and itemsSet[item.name]) or (not isTable and items == item.name) then
            count = count + item.amount
        end
    end
    return count
end

exports('GetItemCount', GetItemCount)

--- Calcula el peso libre disponible en el inventario de un jugador.
---
--- EXPORT: exports['DP-Inventory']:GetFreeWeight(source)
---
--- @param source  number  Server ID del jugador
--- @return        number  Peso libre restante (Config.MaxWeight - pesoActual)
--- Gets the total free weight of the player's inventory.
function GetFreeWeight(source)
    if not source then
        warn('Source was not passed into GetFreeWeight')
        return 0
    end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return 0
    end

    local totalWeight = GetTotalWeight(Player.PlayerData.items)
    local freeWeight = Config.MaxWeight - totalWeight
    return freeWeight
end

exports('GetFreeWeight', GetFreeWeight)

-- ============================================================
--  [5] FUNCIONES EXPORTADAS – VALIDACIÓN  (legacy)
-- ============================================================

--- Comprueba si un ítem puede añadirse a un inventario considerando
--- peso disponible y slots libres. Si los slots están llenos pero el
--- ítem ya existe y NO es único, también devuelve true (se puede apilar).
---
--- EXPORT: exports['DP-Inventory']:CanAddItem(identifier, item, amount)
---
--- @param identifier  number|string  Server ID del jugador, o ID de inventario
--- @param item        string         Nombre del ítem
--- @param amount      number         Cantidad a añadir
--- @return            boolean, string|nil  true si se puede, o false + 'weight'/'slots'
--- Checks if an item can be added to a inventory based on the weight and slots available.
function CanAddItem(identifier, item, amount)
    local Player = QBCore.Functions.GetPlayer(identifier)

    local itemData = QBCore.Shared.Items[item:lower()]
    if not itemData then
        return false
    end

    local inventory, items
    if Player then
        inventory = {
            maxweight = Config.MaxWeight,
            slots = Config.MaxSlots
        }
        items = Player.PlayerData.items
    elseif Inventories[identifier] then
        inventory = Inventories[identifier]
        items = Inventories[identifier].items
    end

    if not inventory then
        print('CanAddItem: Inventory not found')
        return false
    end

    -- Comprobación de peso
    local weight = itemData.weight * amount
    local totalWeight = GetTotalWeight(items) + weight
    if totalWeight > inventory.maxweight then
        return false, 'weight'
    end

    local slotsUsed, _ = GetSlots(identifier)

    -- Comprobación de slots
    if slotsUsed >= inventory.slots then
        for _, v in pairs(items) do
            if v.name == itemData.name then
                if itemData.unique then
                    break -- Ítems únicos no se pueden apilar → no cabe
                end
                print(('CanAddItem: Player %s has no free slots for item %s, but has %d of it already'):format(
                    identifier, itemData.name, v.amount))
                goto continue
            end
        end
        return false, 'slots'
    end

    ::continue::

    return true
end

exports('CanAddItem', CanAddItem)

--- Comprueba si un jugador posee uno o varios ítems en las cantidades indicadas.
---
--- Modos de uso:
---   HasItem(source, 'water')               → ¿tiene al menos 1 water?
---   HasItem(source, 'water', 3)            → ¿tiene al menos 3 water?
---   HasItem(source, {'water','bread'})     → ¿tiene al menos 1 de cada uno?
---   HasItem(source, {water=2, bread=1})    → ¿tiene 2 water Y 1 bread?
---
--- EXPORT: exports['DP-Inventory']:HasItem(source, items, amount)
---
--- @param source  number        Server ID del jugador
--- @param items   string|table  Ítem o tabla de ítems (array o diccionario)
--- @param amount  number|nil    Cantidad mínima requerida (solo cuando items es string)
--- @return        boolean
--- Checks if a player has a certain item or items in their inventory.
function HasItem(source, items, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return false
    end
    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = isArray and #items or 0
    local count = 0

    -- Contamos el total de ítems a verificar si es un diccionario
    if isTable and not isArray then
        for _ in pairs(items) do
            totalItems = totalItems + 1
        end
    end

    for _, itemData in pairs(Player.PlayerData.items) do
        if isTable then
            for k, v in pairs(items) do
                -- k = nombre (dict) | v = nombre (array) o cantidad requerida (dict)
                if itemData and itemData.name == (isArray and v or k) and
                    ((amount and itemData.amount >= amount) or (not isArray and itemData.amount >= v) or
                        (not amount and isArray)) then
                    count = count + 1
                    if count == totalItems then
                        return true -- Todos los ítems requeridos encontrados
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

    return false
end

exports('HasItem', HasItem)

-- ============================================================
--  [6] FUNCIONES EXPORTADAS – GESTIÓN DE INVENTARIO  (legacy)
-- ============================================================

--- Vacía el inventario de un jugador, con posibilidad de filtrar
--- ítems que se quieran conservar.
---
--- EXPORT: exports['DP-Inventory']:ClearInventory(source, filterItems)
---
--- @param source       number        Server ID del jugador
--- @param filterItems  string|table|nil  Ítem o lista de ítems a conservar (el resto se borra)
function ClearInventory(source, filterItems)
    local player = QBCore.Functions.GetPlayer(source)
    local savedItemData = {}
    if filterItems then
        if type(filterItems) == 'string' then
            -- Un solo ítem a conservar
            local item = GetItemByName(source, filterItems)
            if item then
                savedItemData[item.slot] = item
            end
        elseif type(filterItems) == 'table' then
            -- Lista de ítems a conservar
            for _, itemName in ipairs(filterItems) do
                local item = GetItemByName(source, itemName)
                if item then
                    savedItemData[item.slot] = item
                end
            end
        end
    end
    -- Reemplazamos el inventario completo (vacío o con los ítems filtrados)
    player.Functions.SetPlayerData('items', savedItemData)
    if not player.Offline then
        local logMessage = string.format('**%s (citizenid: %s | id: %s)** inventory cleared', GetPlayerName(source),
            player.PlayerData.citizenid, source)
        TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'ClearInventory', 'red', logMessage)
        -- Si tenía un arma equipada, se la quitamos del ped
        local ped = GetPlayerPed(source)
        local weapon = GetSelectedPedWeapon(ped)
        if weapon ~= joaat('WEAPON_UNARMED') then
            RemoveWeaponFromPed(ped, weapon)
        end
        -- Si el inventario estaba abierto, lo actualizamos para reflejar el cambio
        if Player(source).state.inv_busy then
            TriggerClientEvent('DP-Inventory:client:updateInventory', source)
        end
    end
end

exports('ClearInventory', ClearInventory)

--- Cierra el inventario de un jugador y libera el lock del stash asociado.
--- Lanza el evento cliente para cerrar la UI.
---
--- EXPORT: exports['DP-Inventory']:CloseInventory(source, identifier)
---
--- @param source      number      Server ID del jugador
--- @param identifier  string|nil  ID del inventario a desbloquear (opcional)
-- CloseInventory function closes the inventory for a given source and identifier.
-- It sets the isOpen flag of the inventory identified by the given identifier to false.
-- It also sets the inv_busy flag of the player identified by the given source to false.
-- Finally, it triggers the 'DP-Inventory:client:closeInv' event for the given source.
function CloseInventory(source, identifier)
    if identifier and Inventories[identifier] then
        Inventories[identifier].isOpen = false -- Libera el lock del stash
    end
    Player(source).state.inv_busy = false -- Marca al jugador como libre
    TriggerClientEvent('DP-Inventory:client:closeInv', source)
end

exports('CloseInventory', CloseInventory)

--- Abre el inventario de OTRO jugador desde la perspectiva del source.
--- El jugador objetivo queda marcado como inv_busy para evitar acceso simultáneo.
--- Incluye integración opcional con DP-RealMoney para sincronizar dinero antes de abrir.
---
--- EXPORT: exports['DP-Inventory']:OpenInventoryById(source, targetId)
---
--- @param source    number  Server ID del jugador que abre el inventario
--- @param targetId  number  Server ID del jugador cuyo inventario se va a ver
-- Opens the inventory of a player by their ID.
function OpenInventoryById(source, targetId)
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not QBPlayer or not TargetPlayer then
        return
    end

    -- [[ INICIO INTEGRACIÓN DP-REALMONEY ]]
    -- Si el recurso de dinero real está activo, sincronizamos las cantidades
    -- de efectivo antes de abrir para evitar desincronías visuales
    if GetResourceState("DP-RealMoney") ~= 'missing' then
        exports['DP-RealMoney']:UpdateItem(source, 'cash')
        exports['DP-RealMoney']:UpdateItem(source, 'black_money')
        exports['DP-RealMoney']:UpdateItem(source, 'crypto')

        exports['DP-RealMoney']:UpdateItem(targetId, 'cash')
        exports['DP-RealMoney']:UpdateItem(targetId, 'black_money')
        exports['DP-RealMoney']:UpdateItem(targetId, 'crypto')
    end
    -- [[ FIN INTEGRACIÓN DP-REALMONEY ]]

    -- Si el objetivo tenía su propio inventario abierto, lo cerramos primero
    if Player(targetId).state.inv_busy then
        CloseInventory(targetId)
    end

    local formattedInventory = {
        name = 'otherplayer-' .. targetId,
        label = GetPlayerName(targetId), -- Nombre visible en la UI del inventario
        maxweight = Config.MaxWeight,
        slots = Config.MaxSlots,
        inventory = TargetPlayer.PlayerData.items
    }
    Wait(1500) -- Espera para asegurar que la UI del target se ha cerrado antes de abrir
    Player(targetId).state.inv_busy = true
    TriggerClientEvent('DP-Inventory:client:openInventory', source, QBPlayer.PlayerData.items, formattedInventory)
end

exports('OpenInventoryById', OpenInventoryById)

--- Vacía todos los ítems de un stash (inventario especial) y lo actualiza en BD.
---
--- EXPORT: exports['DP-Inventory']:ClearStash(identifier)
---
--- @param identifier  string  ID único del stash a vaciar
-- Clears a given stash of all items inside
function ClearStash(identifier)
    if not identifier then
        return
    end
    local inventory = Inventories[identifier]
    if not inventory then
        return
    end
    inventory.items = {}
    MySQL.prepare('UPDATE inventories SET items = ? WHERE identifier = ?', {json.encode(inventory.items), identifier})
end

exports('ClearStash', ClearStash)

--- Registra una o varias tiendas en la tabla global `RegisteredShops`.
--- Soporta dos formatos:
---   · Un objeto de tienda único (shopData.name definido)
---   · Una tabla de múltiples tiendas (iteración recursiva)
---
--- EXPORT: exports['DP-Inventory']:CreateShop(shopData)
---
--- @param shopData  table  Datos de una tienda o tabla de múltiples tiendas
function CreateShop(shopData)
    if shopData.name then
        -- Formato de tienda única
        RegisteredShops[shopData.name] = {
            name = shopData.name,
            label = shopData.label,
            coords = shopData.coords, -- Vector3 opcional; si se define se comprueba distancia al abrir
            slots = #shopData.items,
            items = SetupShopItems(shopData.items)
        }
    else
        -- Formato de múltiples tiendas → iteramos y registramos cada una
        for key, data in pairs(shopData) do
            if type(data) == 'table' then
                if data.name then
                    local shopName = type(key) == 'number' and data.name or key
                    RegisteredShops[shopName] = {
                        name = shopName,
                        label = data.label,
                        coords = data.coords,
                        slots = #data.items,
                        items = SetupShopItems(data.items)
                    }
                else
                    -- Anidado más profundo → llamada recursiva
                    CreateShop(data)
                end
            end
        end
    end
end

exports('CreateShop', CreateShop)

--- Abre la UI de una tienda registrada para un jugador.
--- Si la tienda tiene coordenadas definidas, valida que el jugador esté a menos de 5 metros.
---
--- EXPORT: exports['DP-Inventory']:OpenShop(source, name)
---
--- @param source  number  Server ID del jugador
--- @param name    string  Nombre de la tienda registrada en RegisteredShops
function OpenShop(source, name)
    if not name then
        return
    end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return
    end
    if not RegisteredShops[name] then
        return
    end
    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    -- Comprobación de proximidad (solo si la tienda tiene coordenadas configuradas)
    if RegisteredShops[name].coords then
        local shopDistance = vector3(RegisteredShops[name].coords.x, RegisteredShops[name].coords.y,
            RegisteredShops[name].coords.z)
        if shopDistance then
            local distance = #(playerCoords - shopDistance)
            if distance > 5.0 then
                return -- Jugador demasiado lejos → no abrimos
            end
        end
    end
    local formattedInventory = {
        name = 'shop-' .. RegisteredShops[name].name,
        label = RegisteredShops[name].label,
        maxweight = 5000000, -- Peso infinito (tienda no tiene límite)
        slots = #RegisteredShops[name].items,
        inventory = RegisteredShops[name].items
    }
    TriggerClientEvent('DP-Inventory:client:openInventory', source, Player.PlayerData.items, formattedInventory)
end

exports('OpenShop', OpenShop)

--- Abre un inventario (stash, baúl, etc.) para un jugador.
--- Si no se proporciona identifier, abre solo el inventario propio del jugador.
--- Aplica lock al inventario para impedir acceso simultáneo de otro jugador.
---
--- EXPORT: exports['DP-Inventory']:OpenInventory(source, identifier, data)
---
--- @param source      number      Server ID del jugador
--- @param identifier  string|nil  ID del inventario secundario a abrir (opcional)
--- @param data        table|nil   {label, maxweight, slots} para sobreescribir valores del inventario
function OpenInventory(source, identifier, data)
    if Player(source).state.inv_busy then
        return -- El jugador ya tiene un inventario abierto
    end
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then
        return
    end

    if not identifier then
        -- Sin identifier → abrimos solo el inventario personal del jugador
        Player(source).state.inv_busy = true
        TriggerClientEvent('DP-Inventory:client:openInventory', source, QBPlayer.PlayerData.items)
        return
    end

    local inventory = Inventories[identifier]
    if inventory and inventory.isOpen then
        -- El stash está siendo usado por otro jugador
        TriggerClientEvent('QBCore:Notify', source, 'Este inventario se encuentra actualmente en uso', 'error')
        return
    end

    if not inventory then
        -- Primera vez que se abre: inicializamos el inventario
        inventory = InitializeInventory(identifier, data)
    end

    -- Actualizamos los valores del inventario con los datos proporcionados
    inventory.maxweight = (data and data.maxweight) or inventory.maxweight or Config.StashSize.maxweight
    inventory.slots = (data and data.slots) or inventory.slots or Config.StashSize.slots
    inventory.label = (data and data.label) or inventory.label or identifier
    inventory.isOpen = source -- Guardamos quién lo tiene abierto (lock)

    local formattedInventory = {
        name = identifier,
        label = inventory.label,
        maxweight = inventory.maxweight,
        slots = inventory.slots,
        inventory = inventory.items
    }
    TriggerClientEvent('DP-Inventory:client:openInventory', source, QBPlayer.PlayerData.items, formattedInventory)
end

exports('OpenInventory', OpenInventory)

--- Crea un inventario vacío en la tabla global `Inventories` si no existe ya.
--- No hace nada si el identificador ya está registrado.
---
--- EXPORT: exports['DP-Inventory']:CreateInventory(identifier, data)
---
--- @param identifier  string    ID único del nuevo inventario
--- @param data        table|nil {label, maxweight, slots}
function CreateInventory(identifier, data)
    if identifier and not Inventories[identifier] then
        InitializeInventory(identifier, data)
    end
end
exports('CreateInventory', CreateInventory)

--- Devuelve la tabla de un inventario registrado, o nil si no existe.
---
--- EXPORT: exports['DP-Inventory']:GetInventory(identifier)
---
--- @param identifier  string  ID del inventario
--- @return            table|nil
function GetInventory(identifier)
    return Inventories[identifier]
end
exports('GetInventory', GetInventory)

--- Elimina un inventario de la tabla global `Inventories` (solo de memoria, no de BD).
---
--- EXPORT: exports['DP-Inventory']:RemoveInventory(identifier)
---
--- @param identifier  string  ID del inventario a eliminar
function RemoveInventory(identifier)
    if Inventories[identifier] then
        Inventories[identifier] = nil
    end
end
exports('RemoveInventory', RemoveInventory)

--- Añade un ítem a un inventario (jugador, stash o drop).
--- OPTIMIZACIÓN EXTREMA O(1): si el ítem no es único y ya existe en el slot
--- objetivo, suma directamente sin iterar toda la tabla.
--- Genera número de serie y calidad 100 automáticamente para armas nuevas.
---
--- EXPORT: exports['DP-Inventory']:AddItem(identifier, item, amount, slot, info, reason)
---
--- @param identifier  number|string  Server ID del jugador, o ID del inventario
--- @param item        string         Nombre del ítem
--- @param amount      number         Cantidad a añadir
--- @param slot        number|nil     Slot destino (opcional; si se omite busca el primero libre)
--- @param info        table|nil      Metadatos del ítem (calidad, serie, etc.)
--- @param reason      string|nil     Motivo del añadido (para logs)
--- @return            boolean        true si se añadió, false en caso de error
-- OPTIMIZACIÓN EXTREMA O(1): Añadir objetos sin bucles redundantes
function AddItem(identifier, item, amount, slot, info, reason)
    local itemInfo = QBCore.Shared.Items[item:lower()]
    if not itemInfo then
        return false
    end

    local inventory, inventoryWeight, inventorySlots
    local player = QBCore.Functions.GetPlayer(identifier)

    -- Determinamos qué tipo de contenedor es el destino
    if player then
        inventory = player.PlayerData.items
        inventoryWeight = Config.MaxWeight
        inventorySlots = Config.MaxSlots
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
        inventoryWeight = Inventories[identifier].maxweight
        inventorySlots = Inventories[identifier].slots
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
        inventoryWeight = Drops[identifier].maxweight
        inventorySlots = Drops[identifier].slots
    end

    if not inventory then
        return false
    end

    amount = tonumber(amount) or 1
    if GetTotalWeight(inventory) + (itemInfo.weight * amount) > inventoryWeight then
        return false -- Pesa demasiado
    end

    local updated = false

    -- Intentar apilar si no es único
    if not itemInfo.unique then
        local targetSlot = tonumber(slot) or GetFirstSlotByItem(inventory, item)
        -- Si existe ese slot en la tabla y es el mismo item, sumamos directo sin iterar
        if targetSlot and inventory[targetSlot] and inventory[targetSlot].name:lower() == item:lower() then
            inventory[targetSlot].amount = inventory[targetSlot].amount + amount
            updated = true
            slot = targetSlot
        end
    end

    -- Si no se pudo apilar, encontrar un hueco libre
    if not updated then
        slot = tonumber(slot) or GetFirstFreeSlot(inventory, inventorySlots)
        if not slot then
            return false
        end -- Inventario lleno

        inventory[slot] = {
            name = item,
            amount = amount,
            info = info or {},
            label = itemInfo.label,
            description = itemInfo.description or '',
            weight = itemInfo.weight,
            type = itemInfo.type,
            unique = itemInfo.unique,
            useable = itemInfo.useable,
            image = itemInfo.image,
            shouldClose = itemInfo.shouldClose,
            slot = slot,
            combinable = itemInfo.combinable
        }

        -- Las armas nuevas reciben serie aleatoria y calidad inicial al 100%
        if itemInfo.type == 'weapon' then
            inventory[slot].info.serie = inventory[slot].info.serie or
                                             tostring(
                    QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) ..
                        QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
            inventory[slot].info.quality = inventory[slot].info.quality or 100
        end
    end

    if player then
        player.Functions.SetPlayerData('items', inventory)
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'Item Added', 'green',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. slot .. ')\n**Item:** ' .. item .. '\n**Amount:** ' .. amount ..
            '\n**Reason:** ' .. (reason or 'No reason specified'))

    -- AVISO VISUAL DE ÍTEM RECIBIDO
    -- Muestra la notificación de ítem recibido en la UI del cliente
    if player and not player.Offline then
        TriggerClientEvent('DP-Inventory:client:ItemBox', identifier, itemInfo, 'add', amount)
    end

    return true
end
exports('AddItem', AddItem)

--- Elimina una cantidad de un ítem de un inventario (jugador, stash o drop).
--- OPTIMIZACIÓN EXTREMA O(1): accede directamente al slot sin iterar.
--- Si la cantidad llega a 0 elimina el slot completo.
--- Si el ítem era un arma y se eliminó, llama a checkWeapon para desarmarlo.
---
--- EXPORT: exports['DP-Inventory']:RemoveItem(identifier, item, amount, slot, reason)
---
--- @param identifier  number|string  Server ID del jugador, o ID del inventario
--- @param item        string         Nombre del ítem a eliminar
--- @param amount      number         Cantidad a restar
--- @param slot        number|nil     Slot origen (opcional; si se omite busca por nombre)
--- @param reason      string|nil     Motivo del borrado (para logs)
--- @return            boolean        true si se eliminó correctamente, false en caso de error
-- OPTIMIZACIÓN EXTREMA O(1): Remover objetos sin bucles
function RemoveItem(identifier, item, amount, slot, reason)
    if not QBCore.Shared.Items[item:lower()] then
        return false
    end

    local inventory
    local player = QBCore.Functions.GetPlayer(identifier)

    if player then
        inventory = player.PlayerData.items
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
    end

    if not inventory then
        return false
    end

    slot = tonumber(slot) or GetFirstSlotByItem(inventory, item)
    if not slot or not inventory[slot] then
        return false
    end

    local inventoryItem = inventory[slot]
    if inventoryItem.name:lower() ~= item:lower() then
        return false -- El slot existe pero el ítem no coincide
    end

    amount = tonumber(amount) or 1
    if inventoryItem.amount < amount then
        return false -- No hay suficiente cantidad para restar
    end

    inventoryItem.amount = inventoryItem.amount - amount
    if inventoryItem.amount <= 0 then
        inventory[slot] = nil -- Slot queda vacío
    else
        inventory[slot] = inventoryItem
    end

    if player then
        player.Functions.SetPlayerData('items', inventory)
        -- Si se eliminó un arma completamente, comprobar si estaba equipada
        if QBCore.Shared.Items[item:lower()].type == 'weapon' and inventoryItem.amount <= 0 then
            checkWeapon(identifier, item)
        end
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'Item Removed', 'red',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. slot .. ')\n**Item:** ' .. item .. '\n**Amount:** ' .. amount ..
            '\n**Reason:** ' .. (reason or 'No reason specified'))

    -- AVISO VISUAL DE ÍTEM ELIMINADO
    -- Muestra la notificación de ítem eliminado en la UI del cliente
    if player and not player.Offline then
        TriggerClientEvent('DP-Inventory:client:ItemBox', identifier, QBCore.Shared.Items[item:lower()], 'remove',
            amount)
    end

    return true
end
exports('RemoveItem', RemoveItem)

-- ============================================================
--  ════════════════════════════════════════════════════════
--  BLOQUE REFACTORIZADO – VERSIONES DEFINITIVAS (activas)
--  Estas funciones SOBREESCRIBEN las del bloque legacy de arriba.
--  Son las que realmente ejecuta el servidor en runtime.
--  ════════════════════════════════════════════════════════
-- ============================================================

-- ============================================================
--  [1] FUNCIONES LOCALES  (versión refactorizada)
-- ============================================================

--- Inicializa una entrada nueva en la tabla global `Inventories`.
--- Versión refactorizada: misma lógica pero con mejor manejo de errores.
---
--- @param inventoryId  string    Identificador único del inventario
--- @param data         table|nil {label, maxweight, slots} – todos opcionales
--- @return             table     La tabla del inventario recién creada
-- ==========================================
-- LOCAL FUNCTIONS
-- ==========================================
local function InitializeInventory(inventoryId, data)
    Inventories[inventoryId] = {
        items = {},
        isOpen = false,
        label = data and data.label or inventoryId,
        maxweight = data and data.maxweight or Config.StashSize.maxweight,
        slots = data and data.slots or Config.StashSize.slots
    }
    return Inventories[inventoryId]
end

--- Devuelve el primer slot libre de una tabla de ítems iterando de 1 a maxSlots.
---
--- @param items     table   Tabla de ítems indexada por número de slot
--- @param maxSlots  number  Total de slots del inventario
--- @return          number|nil  Número del slot libre, o nil si está lleno
local function GetFirstFreeSlot(items, maxSlots)
    for i = 1, maxSlots do
        if items[i] == nil then
            return i
        end
    end
    return nil
end

--- Convierte el array de ítems de config de una tienda al formato interno.
--- Versión refactorizada: usa `tonumber(item.amount) or 1` para mayor robustez.
---
--- @param shopItems  table  Array de {name, amount, info, price}
--- @return           table  Tabla de ítems con formato completo, indexada por slot
local function SetupShopItems(shopItems)
    local items = {}
    local slot = 1
    if shopItems and next(shopItems) then
        for _, item in pairs(shopItems) do
            local itemInfo = QBCore.Shared.Items[item.name:lower()]
            if itemInfo then
                items[slot] = {
                    name = itemInfo['name'],
                    amount = tonumber(item.amount) or 1,
                    info = item.info or {},
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'],
                    unique = itemInfo['unique'],
                    useable = itemInfo['useable'],
                    price = item.price,
                    image = itemInfo['image'],
                    slot = slot
                }
                slot = slot + 1
            end
        end
    end
    return items
end

-- ============================================================
--  [2] FUNCIONES EXPORTADAS – CARGA / GUARDADO  (refactorizada)
-- ============================================================

--- Carga el inventario de un jugador desde la BD.
--- Versión refactorizada: añade `type(inventory) ~= 'table'` como guarda extra,
--- y `tonumber(item.amount) or 1` para sanitizar cantidades corruptas.
---
--- EXPORT: exports['DP-Inventory']:LoadInventory(source, citizenid)
---
--- @param source     number  Server ID del jugador
--- @param citizenid  string  Ciudadano ID
--- @return           table   Inventario indexado por slot
-- ==========================================
-- EXPORTED FUNCTIONS
-- ==========================================
function LoadInventory(source, citizenid)
    local inventory = MySQL.prepare.await('SELECT inventory FROM players WHERE citizenid = ?', {citizenid})
    local loadedInventory = {}
    local missingItems = {}

    if inventory then
        inventory = json.decode(inventory)
    end

    -- Validación robusta: nil, tipo incorrecto o tabla vacía → devolvemos vacío
    if not inventory or type(inventory) ~= 'table' or not next(inventory) then
        return loadedInventory
    end

    for _, item in pairs(inventory) do
        if item then
            local itemInfo = QBCore.Shared.Items[item.name:lower()]

            if itemInfo then
                loadedInventory[item.slot] = {
                    name = itemInfo['name'],
                    amount = tonumber(item.amount) or 1, -- Sanitización de cantidad
                    info = item.info or '',
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'],
                    unique = itemInfo['unique'],
                    useable = itemInfo['useable'],
                    image = itemInfo['image'],
                    shouldClose = itemInfo['shouldClose'],
                    slot = item.slot,
                    combinable = itemInfo['combinable']
                }
            else
                missingItems[#missingItems + 1] = item.name:lower()
            end
        end
    end

    if #missingItems > 0 then
        print(('The following items were removed for player %s as they no longer exist: %s'):format(source and
                                                                                                        GetPlayerName(
                source) or citizenid, table.concat(missingItems, ', ')))
    end

    return loadedInventory
end
exports('LoadInventory', LoadInventory)

--- Guarda el inventario de un jugador en la BD.
--- Versión refactorizada: añade `type(items) == 'table'` como guarda extra.
---
--- EXPORT: exports['DP-Inventory']:SaveInventory(source, offline)
---
--- @param source   number|table  Server ID del jugador, o PlayerData si offline=true
--- @param offline  boolean|nil   Si es true, `source` contiene PlayerData directamente
function SaveInventory(source, offline)
    local PlayerData
    if offline then
        PlayerData = source
    else
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then
            return
        end
        PlayerData = Player.PlayerData
    end

    local items = PlayerData.items
    local ItemsJson = {}

    -- Validación triple: existencia, tipo y contenido
    if items and type(items) == 'table' and next(items) then
        for slot, item in pairs(items) do
            if item then
                ItemsJson[#ItemsJson + 1] = {
                    name = item.name,
                    amount = item.amount,
                    info = item.info,
                    type = item.type,
                    slot = slot
                }
            end
        end
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?',
            {json.encode(ItemsJson), PlayerData.citizenid})
    else
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', {'[]', PlayerData.citizenid})
    end
end
exports('SaveInventory', SaveInventory)

--- Reemplaza TODOS los ítems de un inventario (jugador, drop o stash).
--- Versión refactorizada: elimina el print de debug y simplifica la guarda inicial.
---
--- EXPORT: exports['DP-Inventory']:SetInventory(identifier, items, reason)
---
--- @param identifier  number|string  Server ID del jugador, o ID del inventario
--- @param items       table          Nueva tabla de ítems completa
--- @param reason      string|nil     Motivo del cambio (para logs)
function SetInventory(identifier, items, reason)
    local player = QBCore.Functions.GetPlayer(identifier)

    if not player and not Inventories[identifier] and not Drops[identifier] then
        return
    end

    if player then
        player.Functions.SetPlayerData('items', items)
        if not player.Offline then
            local logMessage = string.format('**%s (citizenid: %s | id: %s)** items set: %s', GetPlayerName(identifier),
                player.PlayerData.citizenid, identifier, json.encode(items))
            TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'SetInventory', 'blue', logMessage)
        end
    elseif Drops[identifier] then
        Drops[identifier].items = items
    elseif Inventories[identifier] then
        Inventories[identifier].items = items
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local setReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'DP-Inventory'
    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'Inventory Set', 'blue',
        '**Inventory:** ' .. invName .. '\n**Items:** ' .. json.encode(items) .. '\n**Reason:** ' .. setReason ..
            '\n**Resource:** ' .. resourceName)
end
exports('SetInventory', SetInventory)

-- ============================================================
--  [3] FUNCIONES EXPORTADAS – METADATOS DE ÍTEMS  (refactorizada)
-- ============================================================

--- Modifica el valor de una clave en la tabla de un ítem del inventario del jugador.
--- Versión refactorizada: `return false` explícito cuando Player no existe.
---
--- EXPORT: exports['DP-Inventory']:SetItemData(source, itemName, key, val, slot)
---
--- @param source    number      Server ID del jugador
--- @param itemName  string      Nombre del ítem a modificar
--- @param key       string      Clave a establecer
--- @param val       any         Valor nuevo
--- @param slot      number|nil  Slot exacto (opcional)
--- @return          boolean
function SetItemData(source, itemName, key, val, slot)
    if not itemName or not key then
        return false
    end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return false -- Ahora devuelve false explícitamente (antes devolvía nil)
    end

    local item
    if slot then
        item = Player.PlayerData.items[tonumber(slot)]
        if not item or item.name:lower() ~= itemName:lower() then
            return false
        end
    else
        item = GetItemByName(source, itemName)
        if not item then
            return false
        end
    end

    item[key] = val
    Player.PlayerData.items[item.slot] = item
    Player.Functions.SetPlayerData('items', Player.PlayerData.items)
    return true
end
exports('SetItemData', SetItemData)

--- Ejecuta el callback registrado para un ítem usable.
---
--- EXPORT: exports['DP-Inventory']:UseItem(itemName, ...)
---
--- @param itemName  string  Nombre del ítem a usar
--- @param ...       any     Parámetros adicionales para el callback
function UseItem(itemName, ...)
    local itemData = QBCore.Functions.CanUseItem(itemName)
    if type(itemData) == 'table' and itemData.func then
        itemData.func(...)
    end
end
exports('UseItem', UseItem)

-- ============================================================
--  [4] FUNCIONES EXPORTADAS – BÚSQUEDA / CONSULTA  (refactorizada)
-- ============================================================

--- Devuelve todos los slots que contengan el ítem indicado.
--- Versión refactorizada: normaliza itemName a lowercase antes del bucle (micro-optimización).
---
--- EXPORT: exports['DP-Inventory']:GetSlotsByItem(items, itemName)
---
--- @param items     table   Tabla de ítems indexada por slot
--- @param itemName  string  Nombre a buscar (case-insensitive)
--- @return          table   Array de slots encontrados (números)
function GetSlotsByItem(items, itemName)
    local slotsFound = {}
    if not items then
        return slotsFound
    end
    itemName = itemName:lower() -- Normalización previa al bucle
    for slot, item in pairs(items) do
        if item.name:lower() == itemName then
            slotsFound[#slotsFound + 1] = tonumber(slot)
        end
    end
    return slotsFound
end
exports('GetSlotsByItem', GetSlotsByItem)

--- Devuelve el primer slot que contenga el ítem indicado.
--- Versión refactorizada: normalización previa + `return nil` explícito.
---
--- EXPORT: exports['DP-Inventory']:GetFirstSlotByItem(items, itemName)
---
--- @param items     table   Tabla de ítems indexada por slot
--- @param itemName  string  Nombre a buscar (case-insensitive)
--- @return          number|nil
function GetFirstSlotByItem(items, itemName)
    if not items then
        return nil
    end
    itemName = itemName:lower()
    for slot, item in pairs(items) do
        if item.name:lower() == itemName then
            return tonumber(slot)
        end
    end
    return nil
end
exports('GetFirstSlotByItem', GetFirstSlotByItem)

--- Devuelve el ítem ubicado en un slot específico del inventario de un jugador.
--- Versión refactorizada: devuelve `nil` explícito en lugar de nada.
---
--- EXPORT: exports['DP-Inventory']:GetItemBySlot(source, slot)
---
--- @param source  number  Server ID del jugador
--- @param slot    number  Número de slot
--- @return        table|nil
function GetItemBySlot(source, slot)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return nil
    end
    return Player.PlayerData.items[tonumber(slot)]
end
exports('GetItemBySlot', GetItemBySlot)

--- Calcula el peso total de todos los ítems en una tabla de inventario.
--- Versión refactorizada: usa `tonumber(item.amount) or 1` para mayor robustez.
---
--- EXPORT: exports['DP-Inventory']:GetTotalWeight(items)
---
--- @param items  table  Tabla de ítems indexada por slot
--- @return       number  Peso total
function GetTotalWeight(items)
    if not items then
        return 0
    end
    local weight = 0
    for _, item in pairs(items) do
        local amount = tonumber(item.amount) or 1
        weight = weight + (item.weight * amount)
    end
    return tonumber(weight)
end
exports('GetTotalWeight', GetTotalWeight)

--- Devuelve el primer ítem con el nombre dado del inventario de un jugador.
--- Versión refactorizada: devuelve `nil` explícito y comprueba `if slot` antes de acceder.
---
--- EXPORT: exports['DP-Inventory']:GetItemByName(source, item)
---
--- @param source  number  Server ID del jugador
--- @param item    string  Nombre del ítem (case-insensitive)
--- @return        table|nil
function GetItemByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return nil
    end
    local items = Player.PlayerData.items
    local slot = GetFirstSlotByItem(items, tostring(item):lower())
    if slot then
        return items[slot]
    end
    return nil
end
exports('GetItemByName', GetItemByName)

--- Devuelve TODOS los ítems con el nombre dado del inventario de un jugador.
--- Versión refactorizada: guarda extra `if slot and PlayerItems[slot]`.
---
--- EXPORT: exports['DP-Inventory']:GetItemsByName(source, item)
---
--- @param source  number  Server ID del jugador
--- @param item    string  Nombre del ítem (case-insensitive)
--- @return        table   Array de ítems (puede estar vacío)
function GetItemsByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return {}
    end
    local PlayerItems = Player.PlayerData.items
    item = tostring(item):lower()
    local items = {}
    for _, slot in pairs(GetSlotsByItem(PlayerItems, item)) do
        if slot and PlayerItems[slot] then
            items[#items + 1] = PlayerItems[slot]
        end
    end
    return items
end
exports('GetItemsByName', GetItemsByName)

--- Devuelve slots usados y slots libres de un inventario.
--- Versión refactorizada: fallback `Config.MaxSlots` si maxSlots es nil.
---
--- EXPORT: exports['DP-Inventory']:GetSlots(identifier)
---
--- @param identifier  number|string  Server ID del jugador, o ID del inventario
--- @return            number, number  (slotsUsados, slotslibres)
function GetSlots(identifier)
    local inventory, maxSlots
    local player = QBCore.Functions.GetPlayer(identifier)

    if player then
        inventory = player.PlayerData.items
        maxSlots = Config.MaxSlots
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
        maxSlots = Inventories[identifier].slots
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
        maxSlots = Drops[identifier].slots
    end

    if not inventory then
        return 0, maxSlots or Config.MaxSlots -- Fallback a MaxSlots global
    end

    local slotsUsed = 0
    for _, v in pairs(inventory) do
        if v then
            slotsUsed = slotsUsed + 1
        end
    end
    return slotsUsed, (maxSlots - slotsUsed)
end
exports('GetSlots', GetSlots)

--- Cuenta el total de unidades de uno o varios ítems en el inventario del jugador.
--- Versión refactorizada: usa `ipairs` en lugar de `pairs` para arrays, y
--- normaliza los nombres a lowercase en el set para búsqueda consistente.
---
--- EXPORT: exports['DP-Inventory']:GetItemCount(source, items)
---
--- @param source  number        Server ID del jugador
--- @param items   string|table  Nombre del ítem, o array de nombres
--- @return        number        Cantidad total acumulada (0 si el jugador no existe)
function GetItemCount(source, items)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return 0 -- Ahora devuelve 0 en lugar de nil
    end

    local isTable = type(items) == 'table'
    local itemsSet = {}
    if isTable then
        -- Construimos un set con lowercase para lookup O(1)
        for _, item in ipairs(items) do
            itemsSet[item:lower()] = true
        end
    else
        items = tostring(items):lower()
    end

    local count = 0
    for _, item in pairs(Player.PlayerData.items) do
        if (isTable and itemsSet[item.name:lower()]) or (not isTable and items == item.name:lower()) then
            count = count + (tonumber(item.amount) or 1)
        end
    end
    return count
end
exports('GetItemCount', GetItemCount)

--- Calcula el peso libre disponible en el inventario de un jugador.
--- Versión refactorizada: simplificada en una sola línea de retorno.
---
--- EXPORT: exports['DP-Inventory']:GetFreeWeight(source)
---
--- @param source  number  Server ID del jugador
--- @return        number  Peso libre restante
function GetFreeWeight(source)
    if not source then
        return 0
    end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return 0
    end
    return Config.MaxWeight - GetTotalWeight(Player.PlayerData.items)
end
exports('GetFreeWeight', GetFreeWeight)

-- ============================================================
--  [5] FUNCIONES EXPORTADAS – VALIDACIÓN  (refactorizada)
-- ============================================================

--- Comprueba si un ítem puede añadirse a un inventario.
--- Versión refactorizada: elimina el `goto` y usa un bucle limpio para
--- la verificación de apilado cuando los slots están llenos.
---
--- EXPORT: exports['DP-Inventory']:CanAddItem(identifier, item, amount)
---
--- @param identifier  number|string  Server ID del jugador, o ID de inventario
--- @param item        string         Nombre del ítem
--- @param amount      number         Cantidad a añadir
--- @return            boolean, string|nil  true, o false + 'weight'/'slots'
-- Optimizado sin "goto"
function CanAddItem(identifier, item, amount)
    local Player = QBCore.Functions.GetPlayer(identifier)
    local itemData = QBCore.Shared.Items[item:lower()]
    if not itemData then
        return false
    end

    local inventory, items
    if Player then
        inventory = {
            maxweight = Config.MaxWeight,
            slots = Config.MaxSlots
        }
        items = Player.PlayerData.items
    elseif Inventories[identifier] then
        inventory = Inventories[identifier]
        items = Inventories[identifier].items
    end

    if not inventory then
        return false
    end

    -- Comprobación de peso
    local weight = itemData.weight * amount
    local totalWeight = GetTotalWeight(items) + weight
    if totalWeight > inventory.maxweight then
        return false, 'weight'
    end

    local slotsUsed, _ = GetSlots(identifier)

    if slotsUsed >= inventory.slots then
        -- Si está lleno, solo podemos añadir si no es único y ya existe para apilarlo
        if not itemData.unique then
            for _, v in pairs(items) do
                if v.name:lower() == itemData.name:lower() then
                    return true -- Hay un stack existente → podemos apilar
                end
            end
        end
        return false, 'slots'
    end

    return true
end
exports('CanAddItem', CanAddItem)

--- Comprueba si un jugador posee uno o varios ítems en las cantidades indicadas.
--- Versión refactorizada: misma lógica, sin cambios respecto al bloque legacy.
---
--- EXPORT: exports['DP-Inventory']:HasItem(source, items, amount)
---
--- Modos de uso:
---   HasItem(source, 'water')               → ¿tiene al menos 1 water?
---   HasItem(source, 'water', 3)            → ¿tiene al menos 3 water?
---   HasItem(source, {'water','bread'})     → ¿tiene al menos 1 de cada uno?
---   HasItem(source, {water=2, bread=1})    → ¿tiene 2 water Y 1 bread?
---
--- @param source  number        Server ID del jugador
--- @param items   string|table  Ítem o tabla de ítems
--- @param amount  number|nil    Cantidad mínima (solo para string)
--- @return        boolean
function HasItem(source, items, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return false
    end

    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = isArray and #items or 0
    local count = 0

    if isTable and not isArray then
        for _ in pairs(items) do
            totalItems = totalItems + 1
        end
    end

    for _, itemData in pairs(Player.PlayerData.items) do
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
    return false
end
exports('HasItem', HasItem)

-- ============================================================
--  [6] FUNCIONES EXPORTADAS – GESTIÓN DE INVENTARIO  (refactorizada)
-- ============================================================

--- Vacía el inventario de un jugador, conservando opcionalmente ciertos ítems.
--- Versión refactorizada: añade guarda `if not player then return end`.
---
--- EXPORT: exports['DP-Inventory']:ClearInventory(source, filterItems)
---
--- @param source       number        Server ID del jugador
--- @param filterItems  string|table|nil  Ítem o lista de ítems a conservar
function ClearInventory(source, filterItems)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        return -- Nueva guarda en la versión refactorizada
    end

    local savedItemData = {}
    if filterItems then
        if type(filterItems) == 'string' then
            local item = GetItemByName(source, filterItems)
            if item then
                savedItemData[item.slot] = item
            end
        elseif type(filterItems) == 'table' then
            for _, itemName in ipairs(filterItems) do
                local item = GetItemByName(source, itemName)
                if item then
                    savedItemData[item.slot] = item
                end
            end
        end
    end

    player.Functions.SetPlayerData('items', savedItemData)
    if not player.Offline then
        local logMessage = string.format('**%s (citizenid: %s | id: %s)** inventory cleared', GetPlayerName(source),
            player.PlayerData.citizenid, source)
        TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'ClearInventory', 'red', logMessage)

        local ped = GetPlayerPed(source)
        local weapon = GetSelectedPedWeapon(ped)
        if weapon ~= joaat('WEAPON_UNARMED') then
            RemoveWeaponFromPed(ped, weapon)
        end
        if Player(source).state.inv_busy then
            TriggerClientEvent('DP-Inventory:client:updateInventory', source)
        end
    end
end
exports('ClearInventory', ClearInventory)

--- Cierra el inventario de un jugador y libera el lock del stash.
--- Versión refactorizada: sin cambios funcionales respecto al bloque legacy.
---
--- EXPORT: exports['DP-Inventory']:CloseInventory(source, identifier)
---
--- @param source      number      Server ID del jugador
--- @param identifier  string|nil  ID del inventario a desbloquear
function CloseInventory(source, identifier)
    if identifier and Inventories[identifier] then
        Inventories[identifier].isOpen = false
    end
    Player(source).state.inv_busy = false
    TriggerClientEvent('DP-Inventory:client:closeInv', source)
end
exports('CloseInventory', CloseInventory)

--- Abre el inventario de otro jugador desde la perspectiva del source.
--- Versión refactorizada:
---   · Eliminada la integración DP-RealMoney (movida a otro lugar o eliminada)
---   · Eliminado el Wait(1500)
---   · Usa charinfo para mostrar el nombre real del personaje en lugar de GetPlayerName
---
--- EXPORT: exports['DP-Inventory']:OpenInventoryById(source, targetId)
---
--- @param source    number  Server ID del jugador que abre
--- @param targetId  number  Server ID del jugador objetivo
function OpenInventoryById(source, targetId)
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not QBPlayer or not TargetPlayer then
        return
    end

    if Player(targetId).state.inv_busy then
        CloseInventory(targetId)
    end

    -- Sacamos el nombre y apellido del personaje (más inmersivo que el nombre de Steam)
    local targetName = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname

    local formattedInventory = {
        name = 'otherplayer-' .. targetId,
        label = targetName,
        maxweight = Config.MaxWeight,
        slots = Config.MaxSlots,
        inventory = TargetPlayer.PlayerData.items
    }

    Player(targetId).state.inv_busy = true
    TriggerClientEvent('DP-Inventory:client:openInventory', source, QBPlayer.PlayerData.items, formattedInventory)
end
exports('OpenInventoryById', OpenInventoryById)

--- Vacía todos los ítems de un stash y lo actualiza en BD.
--- Versión refactorizada: guarda combinada `if not identifier or not Inventories[identifier]`.
---
--- EXPORT: exports['DP-Inventory']:ClearStash(identifier)
---
--- @param identifier  string  ID del stash a vaciar
function ClearStash(identifier)
    if not identifier or not Inventories[identifier] then
        return
    end
    Inventories[identifier].items = {}
    MySQL.prepare('UPDATE inventories SET items = ? WHERE identifier = ?', {'[]', identifier})
end
exports('ClearStash', ClearStash)

--- Registra una o varias tiendas en RegisteredShops.
--- Versión refactorizada: lógica del bloque `else` simplificada,
--- elimina la llamada recursiva y usa `data.name or key` directamente.
---
--- EXPORT: exports['DP-Inventory']:CreateShop(shopData)
---
--- @param shopData  table  Datos de una tienda o tabla de múltiples tiendas
function CreateShop(shopData)
    if shopData.name then
        RegisteredShops[shopData.name] = {
            name = shopData.name,
            label = shopData.label,
            coords = shopData.coords,
            slots = #shopData.items,
            items = SetupShopItems(shopData.items)
        }
    else
        for key, data in pairs(shopData) do
            if type(data) == 'table' then
                local shopName = data.name or key
                RegisteredShops[shopName] = {
                    name = shopName,
                    label = data.label,
                    coords = data.coords,
                    slots = #data.items,
                    items = SetupShopItems(data.items)
                }
            end
        end
    end
end
exports('CreateShop', CreateShop)

--- Abre la UI de una tienda registrada para un jugador.
--- Versión refactorizada: guarda combinada `if not Player or not RegisteredShops[name]`.
---
--- EXPORT: exports['DP-Inventory']:OpenShop(source, name)
---
--- @param source  number  Server ID del jugador
--- @param name    string  Nombre de la tienda en RegisteredShops
function OpenShop(source, name)
    if not name then
        return
    end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not RegisteredShops[name] then
        return
    end

    -- Comprobación de proximidad (solo si la tienda tiene coordenadas configuradas)
    if RegisteredShops[name].coords then
        local playerCoords = GetEntityCoords(GetPlayerPed(source))
        local shopCoords = vector3(RegisteredShops[name].coords.x, RegisteredShops[name].coords.y,
            RegisteredShops[name].coords.z)
        if #(playerCoords - shopCoords) > 5.0 then
            return -- Jugador demasiado lejos
        end
    end

    local formattedInventory = {
        name = 'shop-' .. RegisteredShops[name].name,
        label = RegisteredShops[name].label,
        maxweight = 5000000, -- Peso infinito (tienda no tiene límite)
        slots = #RegisteredShops[name].items,
        inventory = RegisteredShops[name].items
    }
    TriggerClientEvent('DP-Inventory:client:openInventory', source, Player.PlayerData.items, formattedInventory)
end
exports('OpenShop', OpenShop)

--- Abre un inventario (stash, baúl, etc.) para un jugador.
--- Versión refactorizada: añade validación de tipo para `identifier`
--- y mejor manejo de nulos en los campos de inventory.
---
--- EXPORT: exports['DP-Inventory']:OpenInventory(source, identifier, data)
---
--- @param source      number      Server ID del jugador
--- @param identifier  string|nil  ID del inventario secundario (opcional)
--- @param data        table|nil   {label, maxweight, slots} para sobreescribir
function OpenInventory(source, identifier, data)
    if Player(source).state.inv_busy then
        return
    end
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then
        return
    end

    if not identifier then
        Player(source).state.inv_busy = true
        TriggerClientEvent('DP-Inventory:client:openInventory', source, QBPlayer.PlayerData.items)
        return
    end

    -- Nueva guarda: identifier debe ser string
    if type(identifier) ~= 'string' then
        print('Inventory tried to open an invalid identifier')
        return
    end

    local inventory = Inventories[identifier]

    if inventory and inventory.isOpen then
        TriggerClientEvent('QBCore:Notify', source, 'Este inventario se encuentra actualmente en uso', 'error')
        return
    end

    if not inventory then
        inventory = InitializeInventory(identifier, data)
    end
    -- Prioridad: data > existente > default de config
    inventory.maxweight = (data and data.maxweight) or (inventory and inventory.maxweight) or Config.StashSize.maxweight
    inventory.slots = (data and data.slots) or (inventory and inventory.slots) or Config.StashSize.slots
    inventory.label = (data and data.label) or (inventory and inventory.label) or identifier
    inventory.isOpen = source

    local formattedInventory = {
        name = identifier,
        label = inventory.label,
        maxweight = inventory.maxweight,
        slots = inventory.slots,
        inventory = inventory.items
    }
    TriggerClientEvent('DP-Inventory:client:openInventory', source, QBPlayer.PlayerData.items, formattedInventory)
end
exports('OpenInventory', OpenInventory)

--- Crea un inventario vacío en `Inventories` si no existe ya.
--- Versión refactorizada: comprueba primero si ya existe, luego si identifier es válido.
---
--- EXPORT: exports['DP-Inventory']:CreateInventory(identifier, data)
---
--- @param identifier  string    ID único del nuevo inventario
--- @param data        table|nil {label, maxweight, slots}
--- Creates a new inventory and returns the inventory object.
function CreateInventory(identifier, data)
    if Inventories[identifier] then
        return
    end
    if not identifier then
        return
    end
    Inventories[identifier] = InitializeInventory(identifier, data)
end
exports('CreateInventory', CreateInventory)

--- Devuelve la tabla completa de un inventario registrado.
---
--- EXPORT: exports['DP-Inventory']:GetInventory(identifier)
---
--- @param identifier  string  ID del inventario
--- @return            table|nil  Tabla del inventario, o nil si no existe
--- Retrieves an inventory by its identifier.
function GetInventory(identifier)
    return Inventories[identifier]
end
exports('GetInventory', GetInventory)

--- Elimina un inventario de la tabla global `Inventories` (solo de memoria, no de BD).
---
--- EXPORT: exports['DP-Inventory']:RemoveInventory(identifier)
---
--- @param identifier  string  ID del inventario a eliminar
--- Removes an inventory by its identifier.
function RemoveInventory(identifier)
    if Inventories[identifier] then
        Inventories[identifier] = nil
    end
end
exports('RemoveInventory', RemoveInventory)

--- Añade un ítem a un inventario (jugador, stash o drop).
--- Versión refactorizada: el flag `isSilent` suprime el aviso visual en el cliente.
--- Si el ítem no es único, intenta apilar buscando por slot o por nombre.
--- Si el ítem es un arma nueva, asigna serie aleatoria y calidad 100.
---
--- EXPORT: exports['DP-Inventory']:AddItem(identifier, item, amount, slot, info, reason, isSilent)
---
--- @param identifier  number|string  Server ID del jugador, o ID del inventario
--- @param item        string         Nombre del ítem
--- @param amount      number         Cantidad a añadir
--- @param slot        number|nil     Slot destino (opcional)
--- @param info        table|nil      Metadatos del ítem
--- @param reason      string|nil     Motivo (para logs)
--- @param isSilent    boolean|nil    Si true, no muestra el aviso visual al jugador
--- @return            boolean
--- Adds an item to the player's inventory or a specific inventory.
function AddItem(identifier, item, amount, slot, info, reason, isSilent)
    local itemInfo = QBCore.Shared.Items[item:lower()]
    if not itemInfo then
        print('AddItem: Invalid item')
        return false
    end
    local inventory, inventoryWeight, inventorySlots
    local player = QBCore.Functions.GetPlayer(identifier)

    if player then
        inventory = player.PlayerData.items
        inventoryWeight = Config.MaxWeight
        inventorySlots = Config.MaxSlots
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
        inventoryWeight = Inventories[identifier].maxweight
        inventorySlots = Inventories[identifier].slots
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
        inventoryWeight = Drops[identifier].maxweight
        inventorySlots = Drops[identifier].slots
    end

    if not inventory then
        print('AddItem: Inventory not found')
        return false
    end

    local totalWeight = GetTotalWeight(inventory)
    if totalWeight + (itemInfo.weight * amount) > inventoryWeight then
        print('AddItem: Not enough weight available')
        return false
    end

    amount = tonumber(amount) or 1
    local updated = false

    -- Intento de apilado para ítems no únicos
    if not itemInfo.unique then
        slot = slot or GetFirstSlotByItem(inventory, item)
        if slot then
            for _, invItem in pairs(inventory) do
                if invItem.slot == slot then
                    invItem.amount = invItem.amount + amount
                    updated = true
                    break
                end
            end
        end
    end

    if not updated then
        slot = slot or GetFirstFreeSlot(inventory, inventorySlots)
        if not slot then
            print('AddItem: No free slot available')
            return false
        end

        inventory[slot] = {
            name = item,
            amount = amount,
            info = info or {},
            label = itemInfo.label,
            description = itemInfo.description or '',
            weight = itemInfo.weight,
            type = itemInfo.type,
            unique = itemInfo.unique,
            useable = itemInfo.useable,
            image = itemInfo.image,
            shouldClose = itemInfo.shouldClose,
            slot = slot,
            combinable = itemInfo.combinable
        }

        -- Armas nuevas: asignamos serie y calidad si no las traen ya
        if itemInfo.type == 'weapon' then
            if not inventory[slot].info.serie then
                inventory[slot].info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) ..
                                                          QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) ..
                                                          QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
            end
            if not inventory[slot].info.quality then
                inventory[slot].info.quality = 100
            end
        end
    end

    if player then
        player.Functions.SetPlayerData('items', inventory)
    end
    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local addReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'DP-Inventory'
    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'Item Added', 'green',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. slot .. ')\n' .. '**Item:** ' .. item .. '\n' .. '**Amount:** ' ..
            amount .. '\n' .. '**Reason:** ' .. addReason .. '\n' .. '**Resource:** ' .. resourceName)

    -- AVISO VISUAL DE ÍTEM RECIBIDO
    -- isSilent suprime la notificación (útil en inicializaciones masivas o migración de datos)
    if player and not player.Offline and not isSilent then
        TriggerClientEvent('DP-Inventory:client:ItemBox', identifier, itemInfo, 'add', amount)
    end

    return true
end
exports('AddItem', AddItem)

--- Elimina una cantidad de un ítem de un inventario (jugador, stash o drop).
--- Versión refactorizada: el flag `isSilent` suprime el aviso visual.
--- Busca el ítem iterando por slot en lugar de acceso directo (más seguro con
--- inventarios donde los índices de tabla pueden no coincidir con item.slot).
---
--- EXPORT: exports['DP-Inventory']:RemoveItem(identifier, item, amount, slot, reason, isSilent)
---
--- @param identifier  number|string  Server ID del jugador, o ID del inventario
--- @param item        string         Nombre del ítem a eliminar
--- @param amount      number         Cantidad a restar
--- @param slot        number|nil     Slot origen (opcional)
--- @param reason      string|nil     Motivo (para logs)
--- @param isSilent    boolean|nil    Si true, no muestra el aviso visual al jugador
--- @return            boolean
-- Removes an item from a player's inventory.
function RemoveItem(identifier, item, amount, slot, reason, isSilent)
    if not QBCore.Shared.Items[item:lower()] then
        print('RemoveItem: Invalid item')
        return false
    end

    local inventory
    local player = QBCore.Functions.GetPlayer(identifier)

    if player then
        inventory = player.PlayerData.items
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
    end

    if not inventory then
        print('RemoveItem: Inventory not found')
        return false
    end

    slot = tonumber(slot) or GetFirstSlotByItem(inventory, item)

    if not slot then
        print('RemoveItem: Slot not found')
        return false
    end

    -- Búsqueda por slot iterando (más segura que acceso directo por índice)
    local inventoryItem = nil
    local itemKey = nil

    for key, invItem in pairs(inventory) do
        if invItem.slot == slot then
            inventoryItem = invItem
            itemKey = key
            break
        end
    end

    if not inventoryItem or inventoryItem.name:lower() ~= item:lower() then
        print('RemoveItem: Item not found in slot')
        return false
    end

    amount = tonumber(amount)
    if inventoryItem.amount < amount then
        print('RemoveItem: Not enough items in slot')
        return false
    end

    inventoryItem.amount = inventoryItem.amount - amount
    if inventoryItem.amount <= 0 then
        inventory[itemKey] = nil -- Slot vacío → eliminamos la entrada
    else
        inventory[itemKey] = inventoryItem
    end

    if player then
        player.Functions.SetPlayerData('items', inventory)

        -- Si se eliminó un arma por completo, verificamos si estaba equipada
        local itemInfo = QBCore.Shared.Items[item:lower()]
        if itemInfo and itemInfo.type == 'weapon' and inventoryItem.amount <= 0 then
            checkWeapon(identifier, item)
        end
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local removeReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'DP-Inventory'

    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'Item Removed', 'red',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. slot .. ')\n' .. '**Item:** ' .. item .. '\n' .. '**Amount:** ' ..
            amount .. '\n' .. '**Reason:** ' .. removeReason .. '\n' .. '**Resource:** ' .. resourceName)

    -- AVISO VISUAL DE ÍTEM ELIMINADO
    -- isSilent suprime la notificación (útil en limpiezas masivas o migración de datos)
    if player and not player.Offline and not isSilent then
        TriggerClientEvent('DP-Inventory:client:ItemBox', identifier, QBCore.Shared.Items[item:lower()], 'remove',
            amount)
    end

    return true
end
exports('RemoveItem', RemoveItem)
