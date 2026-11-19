-- ============================================================
--  DP-INVENTORY · client/sim.lua
--  Callbacks NUI que la UI usará para pedir combinar/extraer SIM.
--  El toast al jugador lo lanza el SERVIDOR con QBCore:Notify,
--  así que aquí solo devolvemos { success, error? } a la NUI.
-- ============================================================
RegisterNUICallback('DP-Inventory:combineSim', function(data, cb)
    -- Forzamos que el cliente extraiga los números puros del JSON
    local phoneSlot = tonumber(data.phoneSlot)
    local simSlot = tonumber(data.simSlot)

    QBCore.Functions.TriggerCallback('DP-Inventory:combineSim', function(res)
        cb(res or {
            success = false,
            error = 'internal'
        })
    end, phoneSlot, simSlot)
end)

RegisterNUICallback('DP-Inventory:splitSim', function(data, cb)
    local phoneSlot = tonumber(data.phoneSlot)

    QBCore.Functions.TriggerCallback('DP-Inventory:splitSim', function(res)
        cb(res or {
            success = false,
            error = 'internal'
        })
    end, phoneSlot)
end)
