RegisterNUICallback('DP-Inventory:combineSim', function(data, cb)
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
