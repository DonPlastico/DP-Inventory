-- ============================================================
--  DP-INVENTORY · client/backpack_cl.lua
--  Sistema de mochilas expansoras del inventario.
--  Gestiona la apertura de mochilas como stash custom,
--  el cálculo dinámico de capacidad según la mochila equipada
--  y la protección anti-exploit al quitarse la mochila.
--
--  ÍNDICE DE CONTENIDOS
--  ─────────────────────────────────────────────────────────
--  [1]  VARIABLES DE ESTADO
--  [2]  CONFIG INTERNA DE MOCHILAS EXPANSORAS
--  [3]  EVENTO – APERTURA DE MOCHILA COMO STASH
--  [4]  FUNCIÓN GLOBAL – CAPACIDAD DINÁMICA
--  [5]  THREAD – VIGILANTE ANTI-EXPLOIT
-- ============================================================
local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
--  [1] VARIABLES DE ESTADO
-- ============================================================

local lastBag = nil -- Nombre de la última mochila detectada en el slot 101.
-- Usado para detectar cambios (quitarse / cambiar mochila).

-- ============================================================
--  [2] CONFIG INTERNA DE MOCHILAS EXPANSORAS
--  Define cuántos slots y cuánto peso extra otorga cada mochila.
--  El slot de equipamiento de mochilas es el 101 (fijo).
--  Ajusta extraSlots y extraWeight según el diseño del servidor.
-- ============================================================
local ExpanderBags = {
    ['backpack_1'] = {
        extraSlots = 5, -- +5 slots sobre Config.MaxSlots
        extraWeight = 10000 -- +10 kg sobre Config.MaxWeight
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
        extraSlots = 20, -- Mochila más grande: +20 slots y +40 kg
        extraWeight = 40000
    }
}

-- ============================================================
--  [3] EVENTO – APERTURA DE MOCHILA COMO STASH CUSTOM
-- ============================================================

--- Abre una mochila como inventario secundario (stash) con capacidad personalizada.
--- Es disparado desde main_client.lua cuando el jugador interactúa con su mochila.
---
--- @param bagId        string  Identificador único del stash de esta mochila (ej: "backpack_citizenid")
--- @param bagSlots     number  Número de slots del stash
--- @param bagMaxWeight number  Peso máximo del stash en gramos
--- @param itemName     string  Nombre del ítem mochila (no usado aquí directamente, disponible para extensiones)
-- ==========================================================================
-- 1. APERTURA DE MOCHILAS CUSTOM (STASH)
-- ==========================================================================
RegisterNetEvent('DP-Inventory:client:OpenCustomBag', function(bagId, bagSlots, bagMaxWeight, itemName)
    -- Abrimos el stash usando el evento nativo de DP-Inventory/QBCore,
    -- pasando la configuración custom (peso y slots propios de esta mochila)
    TriggerServerEvent("DP-Inventory:server:OpenInventory", "stash", bagId, {
        maxweight = bagMaxWeight,
        slots = bagSlots,
        label = "Mochila Custom"
    })
end)

-- ============================================================
--  [4] FUNCIÓN GLOBAL – CAPACIDAD DINÁMICA
-- ============================================================

--- Calcula los slots y el peso máximo reales del inventario del jugador,
--- sumando los bonus de la mochila expansora equipada en el slot 101.
--- Esta función es GLOBAL para que pueda ser leída desde main_client.lua
--- cuando se envíen los datos del inventario a la UI.
---
--- Lógica:
---   · Base: Config.MaxSlots y Config.MaxWeight
---   · Si en el slot 101 hay una mochila registrada en ExpanderBags,
---     se suman sus bonus al total.
---
--- @return  number, number  (slotsTotal, weightTotal)
-- ==========================================================================
-- 2. CALCULAR CAPACIDAD DINÁMICA (Llamado desde main_client.lua)
-- ==========================================================================
function GetPlayerDynamicCapacity()
    local slots = Config.MaxSlots
    local weight = Config.MaxWeight

    -- PlayerData es global en main_client.lua; accedemos directamente al slot 101
    if PlayerData and PlayerData.items and PlayerData.items[101] then
        local bagName = PlayerData.items[101].name
        if ExpanderBags[bagName] then
            slots = slots + ExpanderBags[bagName].extraSlots
            weight = weight + ExpanderBags[bagName].extraWeight
        end
    end

    return slots, weight
end

-- ============================================================
--  [5] THREAD – VIGILANTE ANTI-EXPLOIT / DROP AUTOMÁTICO
--  Ejecuta cada 1 segundo y detecta si el jugador se quitó
--  o cambió la mochila por una de menor nivel.
--  Si tras el cambio hay ítems en slots que ya no existen,
--  los tira al suelo físicamente y notifica al jugador.
-- ============================================================
-- ==========================================================================
-- 3. VIGILANTE DE MOCHILAS EXPANSORAS (ANTI-EXPLOIT / DROP AUTOMÁTICO)
-- ==========================================================================
CreateThread(function()
    while true do
        Wait(1000)
        if PlayerData and PlayerData.items then
            local currentBag = PlayerData.items[101] -- Mochila actualmente equipada
            local currentBagName = currentBag and currentBag.name or nil

            -- Detectamos cambio de mochila (o eliminación de la misma)
            if lastBag ~= nil and lastBag ~= currentBagName then
                -- Calculamos cuántos slots permite la nueva mochila (o la base si no hay)
                local allowedSlots = Config.MaxSlots
                if currentBagName and ExpanderBags[currentBagName] then
                    allowedSlots = Config.MaxSlots + ExpanderBags[currentBagName].extraSlots
                end

                local itemsDropped = false

                -- Escaneamos el inventario buscando ítems en slots que ya no están permitidos
                for slot, item in pairs(PlayerData.items) do
                    -- Ignoramos los slots de equipamiento especial (101, 102)
                    -- y solo procesamos slots numéricos que excedan el límite permitido
                    if type(slot) == "number" and slot > allowedSlots and slot < 100 then

                        -- Creamos un drop físico en el suelo con el ítem desbordado
                        QBCore.Functions.TriggerCallback('DP-Inventory:server:createDrop', function(dropId)
                            -- Drop creado correctamente en el servidor
                        end, item)

                        itemsDropped = true
                    end
                end

                -- Si cayeron ítems, notificamos al jugador y forzamos actualización de la UI
                if itemsDropped then
                    QBCore.Functions.Notify(
                        '¡Tu inventario se desbordó al quitarte la mochila y cayeron objetos al suelo!', 'error', 6000)
                    -- Forzamos a que la UI actualice los ítems visibles para reflejar el estado real
                    TriggerEvent('DP-Inventory:client:updateInventory')
                end
            end

            -- Actualizamos la referencia de la última mochila detectada
            lastBag = currentBagName
        end
    end
end)
