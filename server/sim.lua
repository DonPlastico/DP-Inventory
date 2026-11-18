-- ============================================================
--  DP-INVENTORY · server/sim.lua
--  Sistema de combinación/separación de SIM entre 'phone' y 'sim_card'.
--
--  Reglas:
--   · La BD es la única fuente de verdad de si una SIM está
--     insertada (dp_phone_sim.imei).
--   · No se mueven filas de contactos/mensajes (ya indexados por sim_number).
--   · El servidor NO confía en el cliente: recibe solo slots y
--     vuelve a leer los items reales del inventario.
--   · Q2 confirmado: 'activated' = "insertada y operativa" (igual que DP-Phone).
--     Se pone a 1 al insertar y a 0 al extraer.
-- ============================================================
local PHONE_ITEM = 'phone'
local SIM_ITEM = 'sim_card'

local busy = {} -- [source] = true mientras se procesa una operación
local lastAction = {} -- [source] = GetGameTimer() de la última acción

-- ============================================================
--  Utilidades
-- ============================================================
local function debugPrint(...)
    if Config.Sim and Config.Sim.debug then
        print('^5[DP-Inventory:SIM]^7', ...)
    end
end

local function fail(code)
    return {
        success = false,
        error = code
    }
end

local function notifyError(src, code)
    TriggerClientEvent('QBCore:Notify', src, Lang:t('sim.error_' .. code), 'error')
end

local function notifySuccess(src, key)
    TriggerClientEvent('QBCore:Notify', src, Lang:t('sim.' .. key), 'success')
end

local function logAction(action, Player, imei, simNumber)
    if not (Config.Sim and Config.Sim.enableLog) then
        return
    end
    MySQL.insert('INSERT INTO dp_phone_sim_log (action, citizenid, imei, sim_number) VALUES (?, ?, ?, ?)',
        {action, Player.PlayerData.citizenid, imei, simNumber})
end

local function notifyPhone(src, imei, simNumber)
    TriggerClientEvent('dp-phone:client:simChanged', src, {
        imei = imei,
        sim_number = simNumber,
        sim_data = simNumber and {
            number = simNumber,
            activated = true
        } or {}
    })
end

-- ============================================================
--  Bloqueo + cooldown
-- ============================================================
local function acquire(src)
    local now = GetGameTimer()
    if busy[src] then
        return false
    end
    if lastAction[src] and (now - lastAction[src]) < (Config.Sim and Config.Sim.actionCooldownMs or 1500) then
        return false
    end
    busy[src] = true
    lastAction[src] = now
    return true
end

local function release(src)
    busy[src] = nil
end

AddEventHandler('playerDropped', function()
    local src = source
    busy[src] = nil
    lastAction[src] = nil
end)

-- ============================================================
--  Combinar (insertar SIM)
-- ============================================================
local function combineSim(src, phoneSlot, simSlot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return fail('internal')
    end

    -- Sanitización extrema (por si acaso llega string)
    phoneSlot = tonumber(phoneSlot)
    simSlot = tonumber(simSlot)

    if not phoneSlot or not simSlot or phoneSlot == simSlot then
        return fail('invalid')
    end

    -- Usamos la función GLOBAL del servidor. 
    -- Esta función busca el ítem comprobando la propiedad "slot" de cada ítem en el inventario real.
    local phone = GetItemBySlot(src, phoneSlot)
    local sim = GetItemBySlot(src, simSlot)

    if not phone or not sim then
        print("^1[DEBUG SIM]^7 No se encontró el ítem en el slot.")
        return fail('invalid')
    end

    if phone.name ~= PHONE_ITEM or sim.name ~= SIM_ITEM then
        return fail('not_combinable')
    end

    local imei = phone.info and phone.info.imei
    local simNumber = sim.info and sim.info.sim_number
    if not imei then
        return fail('phone_no_imei')
    end

    if not simNumber then
        -- LA SIM NO TIENE NÚMERO, SE LO GENERAMOS Y LA ACTIVAMOS EN LA BD AHORA MISMO
        local exists = true
        while exists do
            simNumber = string.format("%03d-%04d-%03d", math.random(100, 999), math.random(1000, 9999),
                math.random(100, 999))
            local found = MySQL.scalar.await('SELECT 1 FROM dp_phone_sim WHERE sim_number = ?', {simNumber})
            if not found then
                exists = false
            end
        end

        -- Insertamos en la BD (si no existe)
        MySQL.insert.await('INSERT IGNORE INTO dp_phone_sim (sim_number, activated) VALUES (?, 0)', {simNumber})

        -- Actualizamos el ítem en el inventario del jugador
        if not sim.info then
            sim.info = {}
        end
        sim.info.sim_number = simNumber
        Player.Functions.SetInventory(Player.PlayerData.items)

        print("^2[DP-Inventory]^7 SIM virgen activada en el momento de combinar: " .. simNumber)
    end

    local simRow = MySQL.single.await('SELECT imei FROM dp_phone_sim WHERE sim_number = ?', {simNumber})
    if not simRow then
        return fail('sim_not_activated')
    end
    if simRow.imei then
        return fail('sim_in_other_phone')
    end

    local alreadyHasSim = MySQL.scalar.await('SELECT 1 FROM dp_phone_sim WHERE imei = ? LIMIT 1', {imei})
    if alreadyHasSim then
        return fail('phone_has_sim')
    end

    if not RemoveItem(src, SIM_ITEM, 1, simSlot, 'sim-insert', true) then
        return fail('internal')
    end

    local ok, affected = pcall(MySQL.update.await,
        'UPDATE dp_phone_sim SET imei = ?, activated = 1 WHERE sim_number = ? AND imei IS NULL', {imei, simNumber})

    if not ok or affected ~= 1 then
        AddItem(src, SIM_ITEM, 1, simSlot, sim.info, 'sim-insert-revert', true)
        return fail(ok and 'sim_in_other_phone' or 'phone_has_sim')
    end

    logAction('insert', Player, imei, simNumber)
    notifyPhone(src, imei, simNumber)
    debugPrint(('SIM %s insertada en %s (src %s)'):format(simNumber, imei, src))

    -- AVISAR A LA UI DE QUE EL INVENTARIO HA CAMBIADO
    TriggerClientEvent('DP-Inventory:client:updateInventory', src)

    return {
        success = true
    }
end

-- ============================================================
--  Extraer (separar SIM)
-- ============================================================
local function splitSim(src, phoneSlot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return fail('internal')
    end

    phoneSlot = tonumber(phoneSlot)
    if not phoneSlot then
        return fail('invalid')
    end

    local phone = GetItemBySlot(src, phoneSlot)
    if not phone then
        return fail('invalid')
    end
    if phone.name ~= PHONE_ITEM then
        return fail('not_combinable')
    end

    local imei = phone.info and phone.info.imei
    if not imei then
        return fail('phone_no_imei')
    end

    -- GANCHO(Q4): si algún día se exige PIN para extraer, aquí se consultaría
    -- dp_phone_hardware.pin antes de continuar.

    local row = MySQL.single.await('SELECT sim_number FROM dp_phone_sim WHERE imei = ? LIMIT 1', {imei})
    if not row then
        return fail('phone_no_sim')
    end

    if not CanAddItem(src, SIM_ITEM, 1) then
        return fail('no_space')
    end

    -- 1) BD primero. Q2: activated=0 igual que DP-Phone.
    local affected = MySQL.update.await(
        'UPDATE dp_phone_sim SET imei = NULL, activated = 0 WHERE sim_number = ? AND imei = ?', {row.sim_number, imei})
    if affected ~= 1 then
        return fail('phone_no_sim')
    end

    -- 2) Entregar la SIM con su MISMO sim_number (isSilent=true)
    local addOk = AddItem(src, SIM_ITEM, 1, false, {
        sim_number = row.sim_number
    }, 'sim-extract', true)
    if not addOk then
        MySQL.update.await('UPDATE dp_phone_sim SET imei = ?, activated = 1 WHERE sim_number = ? AND imei IS NULL',
            {imei, row.sim_number})
        return fail('no_space')
    end

    logAction('extract', Player, imei, row.sim_number)
    notifyPhone(src, imei, nil)
    debugPrint(('SIM %s extraída de %s (src %s)'):format(row.sim_number, imei, src))

    -- AVISAR A LA UI DE QUE EL INVENTARIO HA CAMBIADO
    TriggerClientEvent('DP-Inventory:client:updateInventory', src)

    return {
        success = true
    }
end

QBCore.Functions.CreateCallback('DP-Inventory:combineSim', function(source, cb, phoneSlot, simSlot)
    -- Ejecutamos la lógica envuelta pero SIN el sistema de notificaciones automático
    local result = combineSim(source, phoneSlot, simSlot)
    
    -- Si la lógica devuelve un éxito, devolvemos el objeto tal cual para que la UI se actualice
    cb(result)
end)

QBCore.Functions.CreateCallback('DP-Inventory:splitSim', function(source, cb, phoneSlot)
    local result = splitSim(source, phoneSlot)
    cb(result)
end)

-- ============================================================
--  Consultas de estado (para precargar hasSim en cliente)
-- ============================================================
QBCore.Functions.CreateCallback('DP-Inventory:hasSim', function(_, cb, imei)
    print("^3[DP-Inventory]^7 Callback hasSim llamado con IMEI: " .. tostring(imei))
    if type(imei) ~= 'string' or imei == '' then
        return cb(false)
    end
    local has = MySQL.scalar.await('SELECT 1 FROM dp_phone_sim WHERE imei = ? LIMIT 1', {imei})
    print("^3[DP-Inventory]^7 Resultado: " .. tostring(has ~= nil))
    cb(has ~= nil)
end)

QBCore.Functions.CreateCallback('DP-Inventory:getSimStates', function(_, cb, imeis)
    local states = {}
    if type(imeis) ~= 'table' or #imeis == 0 or #imeis > 50 then
        return cb(states)
    end

    local rows = MySQL.query.await('SELECT imei, sim_number FROM dp_phone_sim WHERE imei IN (?)', {imeis})

    for i = 1, #(rows or {}) do
        states[rows[i].imei] = rows[i].sim_number
    end
    cb(states)
end)
