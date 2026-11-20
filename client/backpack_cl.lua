-- DP-Inventory · client/backpack_cl.lua
-- Mochilas expansoras del inventario.
local QBCore = exports['qb-core']:GetCoreObject()

local lastBag = nil

local ExpanderBags = {
    ['backpack_1'] = {
        extraSlots = 5,
        extraWeight = 10000
    },
    ['backpack_2'] = {
        extraSlots = 10,
        extraWeight = 20000
    },
    ['backpack_3'] = {
        extraSlots = 15,
        extraWeight = 30000
    },
    ['backpack_4'] = {
        extraSlots = 20,
        extraWeight = 40000
    }
}

RegisterNetEvent('DP-Inventory:client:OpenCustomBag', function(bagId, bagSlots, bagMaxWeight, itemName)
    TriggerServerEvent("DP-Inventory:server:OpenInventory", "stash", bagId, {
        maxweight = bagMaxWeight,
        slots = bagSlots,
        label = "Mochila Custom"
    })
end)

function GetPlayerDynamicCapacity()
    local slots = Config.MaxSlots
    local weight = Config.MaxWeight

    if PlayerData and PlayerData.items and PlayerData.items[101] then
        local bagName = PlayerData.items[101].name
        if ExpanderBags[bagName] then
            slots = slots + ExpanderBags[bagName].extraSlots
            weight = weight + ExpanderBags[bagName].extraWeight
        end
    end

    return slots, weight
end

CreateThread(function()
    while true do
        Wait(1000)
        if PlayerData and PlayerData.items then
            local currentBag = PlayerData.items[101]
            local currentBagName = currentBag and currentBag.name or nil

            if lastBag ~= nil and lastBag ~= currentBagName then
                local allowedSlots = Config.MaxSlots
                if currentBagName and ExpanderBags[currentBagName] then
                    allowedSlots = Config.MaxSlots + ExpanderBags[currentBagName].extraSlots
                end

                local itemsDropped = false

                for slot, item in pairs(PlayerData.items) do
                    if type(slot) == "number" and slot > allowedSlots and slot < 100 then
                        QBCore.Functions.TriggerCallback('DP-Inventory:server:createDrop', function(dropId)
                        end, item)
                        itemsDropped = true
                    end
                end

                if itemsDropped then
                    QBCore.Functions.Notify(
                        '¡Tu inventario se desbordó al quitarte la mochila y cayeron objetos al suelo!', 'error', 6000)
                    TriggerEvent('DP-Inventory:client:updateInventory')
                end
            end

            lastBag = currentBagName
        end
    end
end)
