-- ============================================================
--  DP-INVENTORY · server/main_server.lua
--  Núcleo del servidor. Gestiona el ciclo de vida de inventarios,
--  drops, tiendas, movimientos de ítems (anti-dupe), callbacks
--  de interacción y preferencias de usuario en base de datos.
--
--  ÍNDICE DE CONTENIDOS
--  ─────────────────────────────────────────────────────────
--  [1]  VARIABLES GLOBALES
--  [2]  THREADS DE INICIO
--         · Carga de inventarios desde BD
--         · Limpieza periódica de drops
--  [3]  HANDLERS DE CICLO DE VIDA
--         · playerDropped      – libera locks al desconectarse
--         · serverShuttingDown – guarda inventarios en shutdown
--         · QBCore:Server:PlayerLoaded – inyecta métodos al jugador
--         · onResourceStart    – re-inyecta métodos en hot-restart
--  [4]  FUNCIÓN – checkWeapon
--  [5]  EVENTOS DE RED
--         · openVending        – tiendas expendedoras
--         · OpenInventory      – abrir inventario de otro jugador
--         · closeInventory     – cerrar inventario y guardar BD
--         · useItem            – usar ítem (armas, documentos, usables)
--         · updateDrop         – actualizar posición de un drop
--         · ForceOpenStash     – admin: abrir stash sin proximidad
--  [6]  CALLBACKS
--         · GetCurrentDrops    – lista de drops activos
--         · requestHoldDrop    – coger bolsa del suelo
--         · createDrop         – crear drop al tirar un ítem
--         · attemptPurchase    – comprar en tienda
--         · giveItem           – dar ítem a otro jugador
--         · requestOpenDrop    – abrir bolsa del suelo
--         · GetPlayerNames     – nombres de personajes cercanos
--  [7]  LÓGICA DE MOVIMIENTO DE ÍTEMS (ANTI-DUPE)
--         · getItem            – helper: obtiene ítem por slot
--         · getIdentifier      – helper: traduce inventoryId a ID real
--         · SetInventoryData   – drag&drop, split, swap, move
--  [8]  SISTEMA ADMIN
--         · IsAdmin            – comprueba permisos
--         · GetAdminMasterData – todos los inventarios del servidor
--  [9]  PREFERENCIAS DE USUARIO (BD: dp_preferences)
--         · GetPosition / SavePosition
--         · GetMovePref / SaveMovePref
--         · GetSoundPref / SaveSoundPref
-- ============================================================
-- ============================================================
--  [1] VARIABLES GLOBALES
--  Accesibles desde functions.lua, backpack_sv.lua, commands.lua
-- ============================================================
QBCore = exports['qb-core']:GetCoreObject()

Inventories = {} -- Cache en RAM de todos los stashes/inventarios especiales
Drops = {} -- Cache en RAM de todos los drops (bolsas en el suelo)
RegisteredShops = {} -- Cache en RAM de todas las tiendas registradas

-- ============================================================
--  [2] THREADS DE INICIO
-- ============================================================

--- Carga todos los inventarios de la BD en la cache RAM al arrancar el recurso.
--- Esto permite acceso O(1) sin consultas SQL en cada operación de inventario.
-- ==========================================
-- THREADS
-- ==========================================
CreateThread(function()
    MySQL.query('SELECT * FROM inventories', {}, function(result)
        if result and #result > 0 then
            for i = 1, #result do
                local inventory = result[i]
                local cacheKey = inventory.identifier
                Inventories[cacheKey] = {
                    items = json.decode(inventory.items) or {},
                    isOpen = false -- Al cargar, ningún inventario está abierto
                }
            end
        end
    end)
end)

--- Limpieza periódica de drops abandonados.
--- Cada `Config.CleanupDropInterval` minutos elimina los drops cuyo
--- tiempo de vida supere `Config.CleanupDropTime` minutos y no estén abiertos.
CreateThread(function()
    while true do
        Wait(Config.CleanupDropInterval * 60000)
        local currentTime = os.time()
        for k, v in pairs(Drops) do
            -- Elimina solo si: existe, ha expirado Y nadie lo está usando
            if v and (v.createdTime + (Config.CleanupDropTime * 60) < currentTime) and not Drops[k].isOpen then
                local entity = NetworkGetEntityFromNetworkId(v.entityId)
                if DoesEntityExist(entity) then
                    DeleteEntity(entity)
                end
                Drops[k] = nil
            end
        end
    end
end)

-- ============================================================
--  [3] HANDLERS DE CICLO DE VIDA
-- ============================================================

--- Al desconectarse un jugador, libera todos los locks de inventarios y drops
--- que tuviera abiertos o cogidos para que otros jugadores puedan acceder.
-- ==========================================
-- HANDLERS
-- ==========================================
AddEventHandler('playerDropped', function()
    local src = source

    -- Libera el lock de cualquier stash que tuviera abierto
    for _, inv in pairs(Inventories) do
        if inv.isOpen == src then
            inv.isOpen = false
        end
    end

    -- Libera el lock de bolsas abiertas o que llevara en la mano
    for _, drop in pairs(Drops) do
        if drop.isOpen == src then
            drop.isOpen = false
        end
        if drop.isHeld == src then
            drop.isHeld = false
        end
    end
end)

--- Al apagar el servidor (via txAdmin), guarda todos los inventarios en BD.
--- Usa INSERT ... ON DUPLICATE KEY UPDATE para no perder datos de stashes nuevos.
AddEventHandler('txAdmin:events:serverShuttingDown', function()
    for inventory, data in pairs(Inventories) do
        MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?',
            {inventory, json.encode(data.items), json.encode(data.items)})
    end
end)

--- Al cargar un jugador, inyecta en su objeto QBPlayer los métodos del inventario.
--- Esto permite que otros recursos usen `Player.Functions.AddItem(...)` directamente,
--- igual que en qb-inventory base, manteniendo compatibilidad total.
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    QBCore.Functions.AddPlayerMethod(src, 'AddItem', function(item, amount, slot, info, reason)
        return AddItem(src, item, amount, slot, info, reason)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'RemoveItem', function(item, amount, slot, reason)
        return RemoveItem(src, item, amount, slot, reason)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'GetItemBySlot', function(slot)
        return GetItemBySlot(src, slot)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'GetItemByName', function(item)
        return GetItemByName(src, item)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'GetItemsByName', function(item)
        return GetItemsByName(src, item)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'ClearInventory', function(filterItems)
        ClearInventory(src, filterItems)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'SetInventory', function(items)
        SetInventory(src, items)
    end)
end)

--- En hot-restart del recurso, re-inyecta los métodos a TODOS los jugadores online
--- para que no pierdan acceso al inventario sin reconectarse.
--- También resetea inv_busy por si quedó bloqueado de un ciclo anterior.
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    local Players = QBCore.Functions.GetQBPlayers()
    for k in pairs(Players) do
        QBCore.Functions.AddPlayerMethod(k, 'AddItem', function(item, amount, slot, info)
            return AddItem(k, item, amount, slot, info)
        end)
        QBCore.Functions.AddPlayerMethod(k, 'RemoveItem', function(item, amount, slot)
            return RemoveItem(k, item, amount, slot)
        end)
        QBCore.Functions.AddPlayerMethod(k, 'GetItemBySlot', function(slot)
            return GetItemBySlot(k, slot)
        end)
        QBCore.Functions.AddPlayerMethod(k, 'GetItemByName', function(item)
            return GetItemByName(k, item)
        end)
        QBCore.Functions.AddPlayerMethod(k, 'GetItemsByName', function(item)
            return GetItemsByName(k, item)
        end)
        QBCore.Functions.AddPlayerMethod(k, 'ClearInventory', function(filterItems)
            ClearInventory(k, filterItems)
        end)
        QBCore.Functions.AddPlayerMethod(k, 'SetInventory', function(items)
            SetInventory(k, items)
        end)
        Player(k).state.inv_busy = false -- Reseteo de seguridad en hot-restart
    end
end)

-- ============================================================
--  [4] FUNCIÓN – checkWeapon
--  Comprueba si el jugador tiene el arma especificada en mano
--  y si es así, se la retira del ped y notifica a DP-Inventory.
--  Se llama al eliminar un arma del inventario (RemoveItem,
--  createDrop, giveItem) para evitar el "arma fantasma".
--
--  @param source  number  Server ID del jugador
--  @param item    string|table  Nombre del arma o tabla del ítem
-- ============================================================

-- ==========================================
-- FUNCTIONS
-- ==========================================
function checkWeapon(source, item)
    local currentWeapon = type(item) == 'table' and item.name or item
    local ped = GetPlayerPed(source)
    local weapon = GetSelectedPedWeapon(ped)
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    if weaponInfo and weaponInfo.name == currentWeapon then
        RemoveWeaponFromPed(ped, weapon)
        -- Notificamos a DP-Inventory para que limpie su estado interno
        TriggerClientEvent('DP-Inventory:client:UseWeapon', source, {
            name = currentWeapon
        }, false)
    end
end

-- ============================================================
--  [5] EVENTOS DE RED
-- ============================================================

--- Abre la tienda de una máquina expendedora.
--- Optimización: solo crea la tienda 'vending' la primera vez;
--- en llamadas sucesivas actualiza solo las coordenadas.
-- ==========================================
-- EVENTS
-- ==========================================
RegisterNetEvent('DP-Inventory:server:openVending', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    -- Solo crea la tienda si no existe para evitar fugas de memoria
    if not RegisteredShops['vending'] then
        CreateShop({
            name = 'vending',
            label = 'Máquina Expendedora',
            coords = data.coords,
            slots = #Config.VendingItems,
            items = Config.VendingItems
        })
    else
        -- Si ya existe, actualizamos las coordenadas a la máquina actual
        RegisteredShops['vending'].coords = data.coords
    end
    OpenShop(src, 'vending')
end)

--- Abre el inventario de otro jugador (usado por el admin y el cacheo).
--- Actualmente solo soporta el tipo 'otherplayer'.
---
--- @param type      string  Tipo de apertura ('otherplayer')
--- @param targetId  number  Server ID del jugador objetivo
RegisterNetEvent('DP-Inventory:server:OpenInventory', function(type, targetId)
    local src = source
    if type == "otherplayer" then
        OpenInventoryById(src, targetId) -- De functions.lua
    end
end)

--- Cierra un inventario y gestiona toda la lógica de post-cierre:
---   · Tiendas    → solo libera inv_busy, no guarda BD
---   · Otros jugadores → libera inv_busy del objetivo
---   · Drops      → libera lock; si queda vacío, destruye la entidad
---   · Stashes    → guarda en BD + calcula peso dinámico si es mochila (bag_)
RegisterNetEvent('DP-Inventory:server:closeInventory', function(inventory)
    local src = source
    local QBPlayer = QBCore.Functions.GetPlayer(src)
    if not QBPlayer then
        return
    end

    Player(src).state.inv_busy = false

    -- Las tiendas no tienen estado que guardar
    if inventory:find('shop%-') then
        return
    end

    -- Inventario de otro jugador → libera su estado
    if inventory:find('otherplayer%-') then
        local targetId = tonumber(inventory:match('otherplayer%-(.+)'))
        if targetId then
            Player(targetId).state.inv_busy = false
        end
        return
    end

    -- Drop (bolsa en el suelo)
    if Drops[inventory] then
        if Drops[inventory].isOpen == src then
            Drops[inventory].isOpen = false
        end

        -- Si nadie más lo tiene abierto y está vacío → destruir entidad y limpiar
        if not Drops[inventory].isOpen then
            local hasItems = false
            for _, _ in pairs(Drops[inventory].items) do
                hasItems = true
                break
            end

            if not hasItems then
                TriggerClientEvent('DP-Inventory:client:removeDropTarget', -1, Drops[inventory].entityId)
                Wait(500)
                local entity = NetworkGetEntityFromNetworkId(Drops[inventory].entityId)
                if DoesEntityExist(entity) then
                    DeleteEntity(entity)
                end
                Drops[inventory] = nil
            end
        end
        return
    end

    if not Inventories[inventory] then
        return
    end

    -- 1. PRIMERO guardamos en BD (anti-pérdidas: si algo falla después, los ítems ya están guardados)
    Inventories[inventory].isOpen = false
    MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?',
        {inventory, json.encode(Inventories[inventory].items), json.encode(Inventories[inventory].items)})

    -- 2. DESPUÉS calculamos el peso dinámico de la mochila (si algo crashea aquí, los ítems ya están salvados)
    if type(inventory) == "string" and string.find(inventory, "^bag_") then
        TriggerEvent('DP-Inventory:server:UpdateBagWeight', src, inventory)
    end
end)

--- Procesa el uso de un ítem desde la hotbar o el inventario.
--- Lógica especial para:
---   · Armas       → delega animación a DP-Inventory + aviso visual
---   · id_card     → muestra los datos del DNI en el chat cercano (radio 3m)
---   · driver_license → muestra licencia en el chat cercano (radio 3m)
---   · Resto       → ejecuta el callback usable registrado en QBCore
RegisterNetEvent('DP-Inventory:server:useItem', function(item)
    local src = source
    local itemData = GetItemBySlot(src, item.slot)
    if not itemData then
        return
    end

    local itemInfo = QBCore.Shared.Items[itemData.name]

    if itemData.type == 'weapon' then
        if itemData.name == 'weapon_switchblade' then
            TriggerClientEvent('DP-Inventory:client:ToggleSwitchblade', src, itemData)
            TriggerClientEvent('DP-Inventory:client:WeaponItemBox', src, itemInfo)
        else
            -- Las armas se equipan/desequipan via DP-Inventory; la comprobación visual es instantánea en cliente
            TriggerClientEvent('DP-Inventory:client:UseWeapon', src, itemData,
                itemData.info.quality and itemData.info.quality > 0)
            TriggerClientEvent('DP-Inventory:client:WeaponItemBox', src, itemInfo)
        end

    elseif itemData.name == 'id_card' then
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('DP-Inventory:client:ItemBox', source, itemInfo, 'use')
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        local gender = item.info.gender == 0 and 'Hombre' or 'Mujer'
        -- Mostramos el DNI en el chat solo a jugadores dentro de 3 metros
        for _, v in pairs(QBCore.Functions.GetPlayers()) do
            if #(playerCoords - GetEntityCoords(GetPlayerPed(v))) < 3.0 then
                TriggerClientEvent('chat:addMessage', v, {
                    template = '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #74807c); display: flex;"><div style="margin-right: 10px;"><i class="far fa-id-card" style="height: 100%;"></i><strong> {0}</strong><br> <strong>DNI:</strong> {1} <br><strong>Nombre:</strong> {2} <br><strong>Apellido:</strong> {3} <br><strong>Nacimiento:</strong> {4} <br><strong>Sexo:</strong> {5} <br><strong>Nacionalidad:</strong> {6}</div></div>',
                    args = {'Tarjeta ID', item.info.citizenid, item.info.firstname, item.info.lastname,
                            item.info.birthdate, gender, item.info.nationality}
                })
            end
        end

    elseif itemData.name == 'driver_license' then
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('DP-Inventory:client:ItemBox', src, itemInfo, 'use')
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        -- Mostramos la licencia en el chat solo a jugadores dentro de 3 metros
        for _, v in pairs(QBCore.Functions.GetPlayers()) do
            if #(playerCoords - GetEntityCoords(GetPlayerPed(v))) < 3.0 then
                TriggerClientEvent('chat:addMessage', v, {
                    template = '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #657175); display: flex;"><div style="margin-right: 10px;"><i class="far fa-id-card" style="height: 100%;"></i><strong> {0}</strong><br> <strong>Nombre:</strong> {1} <br><strong>Apellido:</strong> {2} <br><strong>Nacimiento:</strong> {3} <br><strong>Licencias:</strong> {4}</div></div>',
                    args = {'Licencia Conducir', item.info.firstname, item.info.lastname, item.info.birthdate,
                            item.info.type}
                })
            end
        end

    else
        -- Ítem usable genérico: ejecuta el callback registrado con QBCore.Functions.CreateUseableItem
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('DP-Inventory:client:ItemBox', src, itemInfo, 'use')
    end
end)

--- Actualiza las coordenadas de un drop cuando el jugador lo suelta.
--- Solo el jugador que lo tenía cogido (isHeld) puede liberarlo.
---
--- @param dropId  string   ID del drop ('drop-XXXX')
--- @param coords  vector3  Nueva posición del drop en el mundo
RegisterNetEvent('DP-Inventory:server:updateDrop', function(dropId, coords)
    local src = source
    if Drops[dropId] then
        Drops[dropId].coords = coords
        if Drops[dropId].isHeld == src then
            Drops[dropId].isHeld = false -- Solo quien la cogió puede liberarla
        end
    end
end)

--- Abre un stash específico sin comprobación de proximidad (solo admins).
--- Verificación de permisos integrada.
RegisterNetEvent('DP-Inventory:server:ForceOpenStash', function(identifier)
    local src = source
    if not (QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')) then
        return
    end
    OpenInventory(src, identifier)
end)

-- ============================================================
--  [6] CALLBACKS
-- ============================================================

--- Devuelve la tabla completa de drops activos al cliente que la pide.
--- Usado por drops.lua (cliente) para actualizar la lista de bolsas en el mundo.
QBCore.Functions.CreateCallback('DP-Inventory:server:GetCurrentDrops', function(_, cb)
    cb(Drops)
end)

--- Solicita el lock de una bolsa para llevarla en la mano.
--- Devuelve true solo si la bolsa existe, no está abierta y nadie la lleva.
---
--- @return  boolean, string|nil  true, o false + razón ('in_use' | 'not_found')
QBCore.Functions.CreateCallback('DP-Inventory:server:requestHoldDrop', function(source, cb, dropId)
    if Drops[dropId] then
        if not Drops[dropId].isOpen and not Drops[dropId].isHeld then
            Drops[dropId].isHeld = source -- Registramos quién la lleva
            cb(true)
        else
            cb(false, "in_use")
        end
    else
        cb(false, "not_found")
    end
end)

--- Crea un drop al tirar un ítem del inventario al suelo.
--- Flujo:
---   1. Elimina el ítem del inventario del jugador.
---   2. Crea la entidad física (prop) en el mundo.
---   3. Registra el drop en la tabla global `Drops`.
---   4. Notifica a todos los clientes para que lo detecten.
---   5. Devuelve el networkId al cliente para que lo congele.
---
--- @param item  table  Datos del ítem a tirar (name, amount, fromSlot, type...)
--- @return      number|false  networkId del drop, o false si falló
QBCore.Functions.CreateCallback('DP-Inventory:server:createDrop', function(source, cb, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return cb(false)
    end

    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)

    if RemoveItem(src, item.name, item.amount, item.fromSlot, 'dropped item') then

        -- Integración DP-RealMoney: sincroniza el efectivo si el ítem es dinero
        if GetResourceState("DP-RealMoney") ~= 'missing' then
            exports['DP-RealMoney']:UpdateCash(src, item.name, item.amount, 'remove')
        end

        -- Si era un arma, comprobamos si la tenía en mano
        if item.type == 'weapon' then
            checkWeapon(src, item)
        end

        -- Animación de tirar al suelo
        TaskPlayAnim(playerPed, 'pickup_object', 'pickup_low', 8.0, -8.0, 2000, 0, 0, false, false, false)

        -- Creamos la entidad física de la bolsa ligeramente desplazada del jugador
        local bag = CreateObjectNoOffset(Config.ItemDropObject, playerCoords.x + 0.5, playerCoords.y + 0.5,
            playerCoords.z, true, true, false)
        local dropId = NetworkGetNetworkIdFromEntity(bag)
        local newDropId = 'drop-' .. dropId

        item.slot = 1
        local initialItem = {
            [1] = item
        } -- Tabla limpia sin metatables

        if not Drops[newDropId] then
            -- Drop nuevo: creamos la entrada completa
            Drops[newDropId] = {
                name = newDropId,
                label = 'Mochila Suelo',
                items = initialItem,
                entityId = dropId,
                createdTime = os.time(),
                coords = playerCoords,
                maxweight = Config.DropSize.maxweight,
                slots = Config.DropSize.slots,
                isOpen = false,
                isHeld = false
            }
            TriggerClientEvent('DP-Inventory:client:setupDropTarget', -1, dropId)
        else
            -- Drop ya existente: buscamos el primer slot libre
            local foundSlot = false
            for i = 1, Config.DropSize.slots do
                if not Drops[newDropId].items[i] then
                    item.slot = i
                    Drops[newDropId].items[i] = item
                    foundSlot = true
                    break
                end
            end
            if not foundSlot then
                return cb(false)
            end -- Drop lleno
        end
        cb(dropId)
    else
        cb(false)
    end
end)

--- Procesa una compra en una tienda registrada.
--- Validaciones en orden:
---   1. Cantidad válida y jugador/tienda existen
---   2. Jugador dentro del radio de la tienda (10m)
---   3. El ítem del slot coincide con el pedido (anti-tamper)
---   4. Hay suficiente stock
---   5. El inventario del jugador tiene capacidad
---   6. El jugador tiene suficiente dinero en efectivo
---
--- @param data  table  {item, amount, shop}
--- @return      boolean
QBCore.Functions.CreateCallback('DP-Inventory:server:attemptPurchase', function(source, cb, data)
    local src = source
    local itemInfo = data.item
    local amount = math.floor(tonumber(data.amount) or 0)
    local shop = string.gsub(data.shop, 'shop%-', '')
    local Player = QBCore.Functions.GetPlayer(src)

    if amount <= 0 or not Player or not RegisteredShops[shop] then
        return cb(false)
    end

    local shopInfo = RegisteredShops[shop]

    -- Comprobación de proximidad (solo si la tienda tiene coordenadas)
    if shopInfo.coords and
        #(GetEntityCoords(GetPlayerPed(src)) - vector3(shopInfo.coords.x, shopInfo.coords.y, shopInfo.coords.z)) > 10 then
        return cb(false)
    end

    -- Anti-tamper: verificamos que el slot pedido contiene el ítem esperado
    if shopInfo.items[itemInfo.slot].name ~= itemInfo.name then
        return cb(false)
    end

    -- Comprobación de stock
    if amount > shopInfo.items[itemInfo.slot].amount or shopInfo.items[itemInfo.slot].amount <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'No hay suficiente stock', 'error')
        return cb(false)
    end

    -- Comprobación de espacio en inventario
    if not CanAddItem(src, itemInfo.name, amount) then
        TriggerClientEvent('QBCore:Notify', src, 'No tienes espacio suficiente', 'error')
        return cb(false)
    end

    local price = shopInfo.items[itemInfo.slot].price * amount
    if Player.PlayerData.money.cash >= price then
        Player.Functions.RemoveMoney('cash', price, 'shop-purchase')
        AddItem(src, itemInfo.name, amount, nil, itemInfo.info, 'shop-purchase')
        shopInfo.items[itemInfo.slot].amount = shopInfo.items[itemInfo.slot].amount - amount
        TriggerEvent('qb-shops:server:UpdateShopItems', shop, itemInfo, amount)
        cb(true)
    else
        TriggerClientEvent('QBCore:Notify', src, 'No tienes suficiente dinero', 'error')
        cb(false)
    end
end)

--- Transfiere un ítem de un jugador a otro.
--- Validaciones: ambos vivos/no esposados, distancia máx 5m, ítem existe
--- y cantidad suficiente. Llama a checkWeapon si era un arma.
--- Reproduce la animación de dar/recibir en ambos jugadores.
---
--- @param target  number  Server ID del receptor
--- @param item    string  Nombre del ítem
--- @param amount  number  Cantidad a dar
--- @param slot    number  Slot origen
--- @param info    table   Metadatos del ítem
QBCore.Functions.CreateCallback('DP-Inventory:server:giveItem', function(source, cb, target, item, amount, slot, info)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(target)

    -- Validación de estado del dador
    if not player or player.PlayerData.metadata['isdead'] or player.PlayerData.metadata['inlaststand'] or
        player.PlayerData.metadata['ishandcuffed'] then
        return cb(false)
    end

    -- Validación de estado del receptor
    if not Target or Target.PlayerData.metadata['isdead'] or Target.PlayerData.metadata['inlaststand'] or
        Target.PlayerData.metadata['ishandcuffed'] then
        return cb(false)
    end

    -- Comprobación de proximidad (máx 5m)
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) > 5 then
        return cb(false)
    end

    -- ============================================================
    --  AUTO-ACTIVAR SIMS VÍRGENES AL DARLAS
    --  Si un admin da una sim_card sin número, le generamos uno.
    -- ============================================================
    if item == 'sim_card' then
        if not info then
            info = {}
        end
        if not info.sim_number then
            local newNumber
            local exists = true
            while exists do
                newNumber = string.format("%03d-%04d-%03d", math.random(100, 999), math.random(1000, 9999),
                    math.random(100, 999))
                local found = MySQL.scalar.await('SELECT 1 FROM dp_phone_sim WHERE sim_number = ?', {newNumber})
                if not found then
                    exists = false
                end
            end
            MySQL.insert.await('INSERT IGNORE INTO dp_phone_sim (sim_number, activated) VALUES (?, 0)', {newNumber})
            info.sim_number = newNumber
            print("^2[DP-Inventory]^7 SIM activada automáticamente: " .. newNumber)
        end
    end

    local itemInfo = QBCore.Shared.Items[item:lower()]
    if not itemInfo or not HasItem(src, item) then
        return cb(false)
    end

    local itemData = GetItemByName(src, item)
    if not itemData or itemData.amount <= 0 then
        return cb(false)
    end

    local giveAmount = math.floor(tonumber(amount) or 0)
    if giveAmount <= 0 or giveAmount > itemData.amount then
        return cb(false)
    end

    if not RemoveItem(src, item, giveAmount, slot, 'Given to ID ' .. target) then
        return cb(false)
    end
    if not AddItem(target, item, giveAmount, false, info, 'Received from ID ' .. src) then
        return cb(false)
    end

    if itemInfo.type == 'weapon' then
        checkWeapon(src, item)
    end

    -- Integración DP-RealMoney
    if GetResourceState("DP-RealMoney") ~= 'missing' then
        exports['DP-RealMoney']:UpdateCash(src, item, giveAmount, 'remove')
        exports['DP-RealMoney']:UpdateCash(target, item, giveAmount, 'add')
    end

    -- Animaciones y avisos visuales en ambos extremos
    TriggerClientEvent('DP-Inventory:client:giveAnim', src)
    TriggerClientEvent('DP-Inventory:client:ItemBox', src, itemInfo, 'remove', giveAmount)
    TriggerClientEvent('DP-Inventory:client:giveAnim', target)
    TriggerClientEvent('DP-Inventory:client:ItemBox', target, itemInfo, 'add', giveAmount)
    if Player(target).state.inv_busy then
        TriggerClientEvent('DP-Inventory:client:updateInventory', target)
    end

    cb(true)
end)

--- Solicita abrir una bolsa del suelo (como inventario secundario).
--- Validaciones: jugador existe, drop existe, no está ya abierto ni cogido,
--- jugador dentro de 2.5m.
---
--- @param dropId  string  ID del drop ('drop-XXXX')
--- @return        boolean
QBCore.Functions.CreateCallback('DP-Inventory:server:requestOpenDrop', function(source, cb, dropId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player or not Drops[dropId] or Drops[dropId].isOpen or Drops[dropId].isHeld then
        cb(false)
        return
    end

    -- Comprobación de proximidad
    if #(GetEntityCoords(GetPlayerPed(src)) - Drops[dropId].coords) > 2.5 then
        cb(false)
        return
    end

    Drops[dropId].isOpen = src -- Registramos QUIÉN abrió la bolsa (lock)

    local formattedInventory = {
        name = dropId,
        label = 'Mochila Suelo',
        maxweight = Drops[dropId].maxweight,
        slots = Drops[dropId].slots,
        inventory = Drops[dropId].items
    }

    TriggerClientEvent('DP-Inventory:client:openInventory', src, Player.PlayerData.items, formattedInventory)
    cb(true)
end)

--- Devuelve los nombres de personaje y Steam de una lista de server IDs.
--- Usado por la UI para mostrar jugadores cercanos al dar ítems.
---
--- @param serverIds  table  Array de server IDs a consultar
--- @return           table  Array de {id, name (RP), steam}
QBCore.Functions.CreateCallback('DP-Inventory:server:GetPlayerNames', function(source, cb, serverIds)
    local playersData = {}

    for _, id in ipairs(serverIds) do
        local TargetPlayer = QBCore.Functions.GetPlayer(id)

        if TargetPlayer then
            local charName = TargetPlayer.PlayerData.charinfo.firstname .. " " ..
                                 TargetPlayer.PlayerData.charinfo.lastname
            local steamName = GetPlayerName(id)

            table.insert(playersData, {
                id = id,
                name = charName, -- Nombre del personaje (Roleplay)
                steam = steamName -- Nombre de Steam (identificación real)
            })
        end
    end

    cb(playersData)
end)

-- ============================================================
--  [7] LÓGICA DE MOVIMIENTO DE ÍTEMS (ANTI-DUPE)
--  Gestiona todo movimiento de ítems entre inventarios:
--  · drag & drop completo    → mover
--  · mismo ítem en destino   → apilar
--  · cantidad < total origen → dividir (split)
--  · ambos slots con ítems distintos → intercambiar (swap)
--  Todas las operaciones pasan por RemoveItem + AddItem del
--  servidor para que sean la autoridad única (anti-dupe).
-- ============================================================

-- ==========================================
-- ITEM MOVE LOGIC (ANTI-DUPE)
-- ==========================================

--- Helper: obtiene el ítem en un slot concreto de cualquier inventario.
--- Soporta: 'player', 'otherplayer-ID', 'drop-ID', cualquier stash.
---
--- @param inventoryId  string  Identificador del inventario
--- @param src          number  Server ID del jugador (para resolver 'player')
--- @param slot         number  Número de slot a buscar
--- @return             table|nil  Tabla del ítem, o nil si no existe
local function getItem(inventoryId, src, slot)
    local items = {}
    if inventoryId == 'player' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.items then
            items = Player.PlayerData.items
        end
    elseif inventoryId:find('otherplayer-') then
        local targetId = tonumber(inventoryId:match('otherplayer%-(.+)'))
        local targetPlayer = QBCore.Functions.GetPlayer(targetId)
        if targetPlayer and targetPlayer.PlayerData.items then
            items = targetPlayer.PlayerData.items
        end
    elseif inventoryId:find('drop-') == 1 then
        if Drops[inventoryId] and Drops[inventoryId]['items'] then
            items = Drops[inventoryId]['items']
        end
    else
        if Inventories[inventoryId] and Inventories[inventoryId]['items'] then
            items = Inventories[inventoryId]['items']
        end
    end

    for _, item in pairs(items) do
        if item.slot == slot then
            return item
        end
    end
    return nil
end

--- Helper: traduce un inventoryId al identificador real que usan AddItem/RemoveItem.
--- 'player' → server ID numérico | 'otherplayer-ID' → ID numérico | stash → string
---
--- @param inventoryId  string  Identificador del inventario
--- @param src          number  Server ID del jugador local
--- @return             number|string
local function getIdentifier(inventoryId, src)
    if inventoryId == 'player' then
        return src
    elseif inventoryId:find('otherplayer-') then
        return tonumber(inventoryId:match('otherplayer%-(.+)'))
    else
        return inventoryId
    end
end

--- Procesa TODO movimiento de ítems entre slots/inventarios desde la UI.
--- Es el evento más crítico del servidor: cualquier drag&drop pasa por aquí.
---
--- OPERACIONES POSIBLES:
---   · Apilar    → fromItem.name == toItem.name (mismo ítem en destino)
---   · Dividir   → toAmount < fromAmount y destino vacío
---   · Intercambiar → ambos slots ocupados con ítems distintos
---   · Mover     → destino vacío, mover cantidad completa
---
--- FILTROS ANTI-DUPE:
---   · Cantidades negativas bloqueadas
---   · Mismo inventario + mismo slot bloqueado
---   · toAmount > fromItem.amount bloqueado (no puedes mover más de lo que hay)
---   · Movimientos a tiendas bloqueados
---
--- Tras el movimiento, comprueba si se afectó el slot 101 (mochila expansora)
--- y dispara CheckBackpackUnequip si es necesario.
RegisterNetEvent('DP-Inventory:server:SetInventoryData',
    function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
        local src = source

        -- Bloquea movimientos hacia tiendas (las tiendas son de solo lectura)
        if toInventory:find('shop%-') then
            return
        end

        -- Validación de parámetros completos
        if not fromInventory or not toInventory or not fromSlot or not toSlot or not fromAmount or not toAmount then
            return
        end

        -- Sanitizamos todos los valores numéricos (anti-injection)
        fromSlot = math.floor(tonumber(fromSlot) or 0)
        toSlot = math.floor(tonumber(toSlot) or 0)
        fromAmount = math.floor(tonumber(fromAmount) or 0)
        toAmount = math.floor(tonumber(toAmount) or 0)

        -- FILTRO ANTI-DUPE: cantidades negativas o movimiento al mismo slot exacto
        if fromAmount < 0 or toAmount < 0 then
            return
        end
        if fromInventory == toInventory and fromSlot == toSlot then
            return
        end

        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then
            return
        end

        local fromItem = getItem(fromInventory, src, fromSlot)
        local toItem = getItem(toInventory, src, toSlot)

        if fromItem then
            -- FILTRO ANTI-DUPE: no se puede mover más cantidad de la que hay
            if not toItem and toAmount > fromItem.amount then
                return
            end

            -- Si el jugador saca algo de su propio inventario hacia otro,
            -- comprobamos si era un arma para quitársela de la mano
            if fromInventory == 'player' and toInventory ~= 'player' then
                checkWeapon(src, fromItem)
            end

            local fromId = getIdentifier(fromInventory, src)
            local toId = getIdentifier(toInventory, src)

            -- ── APILAR: mismo ítem en destino ──
            if toItem and fromItem.name == toItem.name then
                if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'stacked item', true) then
                    AddItem(toId, toItem.name, toAmount, toSlot, toItem.info, 'stacked item', true)
                    if GetResourceState("DP-RealMoney") ~= 'missing' then
                        exports['DP-RealMoney']:UpdateCash(fromId, fromItem.name, toAmount, 'remove')
                        exports['DP-RealMoney']:UpdateCash(toId, toItem.name, toAmount, 'add')
                    end
                end

                -- ── DIVIDIR: cantidad parcial a slot vacío ──
            elseif not toItem and toAmount < fromAmount then
                if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'split item', true) then
                    AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'split item', true)
                    if GetResourceState("DP-RealMoney") ~= 'missing' then
                        exports['DP-RealMoney']:UpdateCash(fromId, fromItem.name, toAmount, 'remove')
                        exports['DP-RealMoney']:UpdateCash(toId, fromItem.name, toAmount, 'add')
                    end
                end

            else
                -- ── INTERCAMBIAR: dos slots ocupados con ítems distintos ──
                if toItem then
                    local fromItemAmount = fromItem.amount
                    local toItemAmount = toItem.amount

                    if RemoveItem(fromId, fromItem.name, fromItemAmount, fromSlot, 'swapped item', true) and
                        RemoveItem(toId, toItem.name, toItemAmount, toSlot, 'swapped item', true) then
                        AddItem(toId, fromItem.name, fromItemAmount, toSlot, fromItem.info, 'swapped item', true)
                        AddItem(fromId, toItem.name, toItemAmount, fromSlot, toItem.info, 'swapped item', true)
                        if GetResourceState("DP-RealMoney") ~= 'missing' then
                            exports['DP-RealMoney']:UpdateCash(fromId, fromItem.name, fromItemAmount, 'remove')
                            exports['DP-RealMoney']:UpdateCash(toId, toItem.name, toItemAmount, 'remove')
                            exports['DP-RealMoney']:UpdateCash(toId, fromItem.name, fromItemAmount, 'add')
                            exports['DP-RealMoney']:UpdateCash(fromId, toItem.name, toItemAmount, 'add')
                        end
                    end

                    -- ── MOVER: slot destino vacío, cantidad completa ──
                else
                    if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'moved item', true) then
                        AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'moved item', true)
                        if GetResourceState("DP-RealMoney") ~= 'missing' then
                            exports['DP-RealMoney']:UpdateCash(fromId, fromItem.name, toAmount, 'remove')
                            exports['DP-RealMoney']:UpdateCash(toId, fromItem.name, toAmount, 'add')
                        end
                    end
                end
            end
        end

        -- Si el movimiento afectó el slot 101 (mochila expansora), ejecutamos
        -- la comprobación de desbordamiento de inventario
        if (fromInventory == 'player' and fromSlot == 101) or (toInventory == 'player' and toSlot == 101) then
            Wait(100) -- Pequeño wait para asegurar que SetInventoryData terminó de guardar
            CheckBackpackUnequip(src) -- De backpack_sv.lua
        end
    end)

-- ============================================================
--  [8] SISTEMA ADMIN
-- ============================================================

--- Comprueba si el jugador tiene permisos de admin o god en QBCore.
--- Devuelve true si tiene cualquiera de los dos niveles.
QBCore.Functions.CreateCallback('DP-Inventory:server:IsAdmin', function(source, cb)
    cb(QBCore.Functions.HasPermission(source, 'admin') or QBCore.Functions.HasPermission(source, 'god'))
end)

--- Recopila todos los inventarios del servidor categorizados para el panel admin:
---   · players    → jugadores online con nombre RP y Steam
---   · trunks     → identificadores que empiezan por 'trunk-'
---   · gloveboxes → identificadores que empiezan por 'glovebox-'
---   · stashes    → resto de identificadores
--- Solo accesible para admin/god.
QBCore.Functions.CreateCallback('DP-Inventory:server:GetAdminMasterData', function(source, cb)
    if not (QBCore.Functions.HasPermission(source, 'admin') or QBCore.Functions.HasPermission(source, 'god')) then
        return cb(false)
    end

    local players = {}
    for _, v in pairs(QBCore.Functions.GetPlayers()) do
        local target = QBCore.Functions.GetPlayer(v)
        if target then
            players[#players + 1] = {
                id = v,
                name = target.PlayerData.charinfo.firstname .. ' ' .. target.PlayerData.charinfo.lastname,
                steam = GetPlayerName(v)
            }
        end
    end

    -- Consultamos la BD para categorizar todos los inventarios guardados
    MySQL.query('SELECT identifier FROM inventories', {}, function(result)
        local trunks, gloveboxes, stashes = {}, {}, {}
        if result then
            for i = 1, #result do
                local id = result[i].identifier
                if string.find(id, "^trunk%-") then
                    trunks[#trunks + 1] = id
                elseif string.find(id, "^glovebox%-") then
                    gloveboxes[#gloveboxes + 1] = id
                else
                    stashes[#stashes + 1] = id
                end
            end
        end
        cb({
            players = players,
            trunks = trunks,
            gloveboxes = gloveboxes,
            stashes = stashes
        })
    end)
end)

-- ============================================================
--  [9] PREFERENCIAS DE USUARIO (BD: dp_preferences)
--  Tabla: dp_preferences (citizenid, inventory_position,
--                         move_while_open, ui_sounds)
--  Todas las preferencias se guardan por citizenid y persisten
--  entre sesiones. Usan INSERT ... ON DUPLICATE KEY UPDATE
--  para crear la fila si no existe.
-- ============================================================

-- ==========================================================================
-- PREFERENCIAS DE POSICIÓN DEL INVENTARIO
-- ==========================================================================

--- Obtiene la posición visual del inventario del jugador.
--- @return  string  'bottom' (por defecto) u otra posición guardada
QBCore.Functions.CreateCallback('DP-Inventory:server:GetPosition', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb('bottom')
    end

    local result = MySQL.Sync.fetchAll('SELECT inventory_position FROM dp_preferences WHERE citizenid = ?',
        {Player.PlayerData.citizenid})
    if result[1] and result[1].inventory_position then
        cb(result[1].inventory_position)
    else
        cb('bottom') -- Valor por defecto
    end
end)

--- Guarda la posición visual del inventario.
--- Usa ON DUPLICATE KEY UPDATE para crear la fila si aún no existe.
RegisterNetEvent('DP-Inventory:server:SavePosition', function(pos)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    MySQL.Async.execute(
        'INSERT INTO dp_preferences (citizenid, inventory_position) VALUES (?, ?) ON DUPLICATE KEY UPDATE inventory_position = ?',
        {Player.PlayerData.citizenid, pos, pos})
end)

--- Obtiene la preferencia de moverse con el inventario abierto.
--- @return  boolean  false por defecto
-- Obtener la preferencia de movimiento
QBCore.Functions.CreateCallback('DP-Inventory:server:GetMovePref', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb(false)
    end

    local result = MySQL.Sync.fetchAll('SELECT move_while_open FROM dp_preferences WHERE citizenid = ?',
        {Player.PlayerData.citizenid})
    if result[1] and result[1].move_while_open ~= nil then
        cb(result[1].move_while_open == 1) -- BD guarda 0/1; devolvemos boolean
    else
        cb(false)
    end
end)

--- Guarda la preferencia de movimiento. Convierte boolean → 0/1 para la BD.
-- Guardar la preferencia de movimiento
RegisterNetEvent('DP-Inventory:server:SaveMovePref', function(status)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local val = status and 1 or 0
    MySQL.Async.execute('UPDATE dp_preferences SET move_while_open = ? WHERE citizenid = ?',
        {val, Player.PlayerData.citizenid})
end)

--- Obtiene la preferencia de sonidos de la UI.
--- Si no existe entrada en BD, la crea con valor 1 (sonidos activados).
--- @return  boolean  true por defecto
-- Obtener preferencia de sonidos al cargar el personaje
QBCore.Functions.CreateCallback('DP-Inventory:server:GetSoundPref', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb(true)
    end

    MySQL.Async.fetchAll('SELECT ui_sounds FROM dp_preferences WHERE citizenid = ?', {Player.PlayerData.citizenid},
        function(result)
            if result[1] ~= nil then
                cb(result[1].ui_sounds == 1) -- 1 = true, 0 = false
            else
                -- Primera vez del jugador: insertamos con sonidos activados por defecto
                MySQL.Async.execute(
                    'INSERT INTO dp_preferences (citizenid, ui_sounds) VALUES (?, 1) ON DUPLICATE KEY UPDATE ui_sounds=1',
                    {Player.PlayerData.citizenid})
                cb(true)
            end
        end)
end)

--- Guarda la preferencia de sonidos. Usa UPSERT para crear la fila si no existe.
-- Guardar la preferencia cuando el jugador hace clic en el interruptor
RegisterNetEvent('DP-Inventory:server:SaveSoundPref', function(status)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return
    end

    local val = status and 1 or 0
    MySQL.Async.execute(
        'INSERT INTO dp_preferences (citizenid, ui_sounds) VALUES (?, ?) ON DUPLICATE KEY UPDATE ui_sounds=?',
        {Player.PlayerData.citizenid, val, val})
end)
