-- DP-Inventory · client/backitems.lua
-- Props visuales de armas/ítems en el cuerpo del jugador.
local QBCore = exports['qb-core']:GetCoreObject()

local attachedProps = {}
local currentPed = nil
local globalHidden = false
local currentWeaponPosition = 'normal'

-- Armas pequeñas que responden a los botones de posición de la UI
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

local function ClearBackItems()
    for weaponName, prop in pairs(attachedProps) do
        if DoesEntityExist(prop) then
            SetEntityAsMissionEntity(prop, true, true)
            DetachEntity(prop, true, true)
            DeleteObject(prop)
            DeleteEntity(prop)
        end
    end
    attachedProps = {}
end

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

    if position == 'normal' or not smallWeapons[weaponName] then
        return pos
    end

    if position == 'front' then
        pos.bone = 24818
        pos.x = 0.0
        pos.y = 0.16
        pos.z = -0.1
        pos.x_rot = 0.0
        pos.y_rot = 90.0
        pos.z_rot = 0.0
    elseif position == 'back' then
        pos.bone = 24818
        pos.x = 0.0
        pos.y = -0.16
        pos.z = -0.15
        pos.x_rot = 90.0
        pos.y_rot = 0.0
        pos.z_rot = 0.0
    elseif position == 'belt' then
        pos.bone = 11816
        pos.x = -0.1
        pos.y = 0.15
        pos.z = 0.0
        pos.x_rot = -115.0
        pos.y_rot = 0.0
        pos.z_rot = 90.0
    elseif position == 'chest' then
        pos.bone = 24818
        pos.x = -0.05
        pos.y = 0.15
        pos.z = 0.1
        pos.x_rot = 0.0
        pos.y_rot = -90.0
        pos.z_rot = 0.0
    elseif position == 'thigh' then
        pos.bone = 51826
        pos.x = 0.1
        pos.y = 0.0
        pos.z = 0.0
        pos.x_rot = 90.0
        pos.y_rot = 0.0
        pos.z_rot = 0.0
    elseif position == 'leg' then
        pos.bone = 36864
        pos.x = 0.08
        pos.y = 0.0
        pos.z = 0.05
        pos.x_rot = 90.0
        pos.y_rot = 0.0
        pos.z_rot = 0.0
    elseif position == 'leg_sep' then
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

local function UpdateBackItems(items)
    local ped = PlayerPedId()
    local currentWeaponsInInv = {}

    if items then
        for _, item in pairs(items) do
            if item and item.name and BackItemsConfig[item.name] then
                currentWeaponsInInv[item.name] = true
            end
        end
    end

    for weaponName, prop in pairs(attachedProps) do
        if not currentWeaponsInInv[weaponName] then
            if DoesEntityExist(prop) then
                DeleteEntity(prop)
            end
            attachedProps[weaponName] = nil
        end
    end

    if globalHidden then
        return
    end

    for weaponName, _ in pairs(currentWeaponsInInv) do
        local configData = BackItemsConfig[weaponName]
        local posData = GetWeaponPositionData(weaponName, configData, currentWeaponPosition)

        if not attachedProps[weaponName] or not DoesEntityExist(attachedProps[weaponName]) then
            local modelHash = joaat(configData.model)
            RequestModel(modelHash)
            while not HasModelLoaded(modelHash) do
                Wait(10)
            end

            local prop = CreateObject(modelHash, 0.0, 0.0, 0.0, true, true, false)
            local boneIndex = GetPedBoneIndex(ped, posData.bone)
            AttachEntityToEntity(prop, ped, boneIndex, posData.x, posData.y, posData.z, posData.x_rot, posData.y_rot,
                posData.z_rot, true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(modelHash)
            attachedProps[weaponName] = prop
        end
    end
end

local function RefreshBackItems()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.items then
        UpdateBackItems(PlayerData.items)
    end
end

RegisterNetEvent('DP-Inventory:client:ToggleBackItems', function()
    globalHidden = not globalHidden
    if globalHidden then
        ClearBackItems()
    else
        currentWeaponPosition = 'normal'
        RefreshBackItems()
    end
end)

RegisterNetEvent('DP-Inventory:client:SetWeaponPosition', function(position)
    currentWeaponPosition = position
    ClearBackItems()
    Wait(50)
    RefreshBackItems()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    if val and val.items then
        UpdateBackItems(val.items)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    currentPed = PlayerPedId()
    RefreshBackItems()
end)

RegisterNetEvent('qb-spawn:client:ValidSpawn', function()
    Wait(1000)
    RefreshBackItems()
end)

RegisterNetEvent('apartments:client:SpawnInApartment', function()
    Wait(1000)
    RefreshBackItems()
end)

RegisterNetEvent('qb-clothing:client:loadPlayerClothing', function()
    Wait(1000)
    RefreshBackItems()
end)

RegisterNetEvent('illenium-appearance:client:reloadSkin', function()
    Wait(1000)
    RefreshBackItems()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    ClearBackItems()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        ClearBackItems()
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local needsRefresh = false

        if currentPed ~= ped then
            currentPed = ped
            ClearBackItems()
            needsRefresh = true
        end

        -- Anti-props clonados por otros scripts
        local currentWeaponEnt = GetCurrentPedWeaponEntityIndex(ped)
        for _, obj in ipairs(GetGamePool('CObject')) do
            if GetEntityAttachedTo(obj) == ped and obj ~= currentWeaponEnt then
                local model = GetEntityModel(obj)
                for weaponName, configData in pairs(BackItemsConfig) do
                    if joaat(configData.model) == model then
                        local isOurs = false
                        for _, ourProp in pairs(attachedProps) do
                            if ourProp == obj then
                                isOurs = true
                                break
                            end
                        end
                        if not isOurs then
                            SetEntityAsMissionEntity(obj, true, true)
                            DetachEntity(obj, true, true)
                            DeleteEntity(obj)
                        end
                    end
                end
            end
        end

        for weaponName, prop in pairs(attachedProps) do
            if not DoesEntityExist(prop) then
                attachedProps[weaponName] = nil
                needsRefresh = true
            elseif GetEntityAttachedTo(prop) ~= ped then
                DeleteEntity(prop)
                attachedProps[weaponName] = nil
                needsRefresh = true
            end
        end

        if needsRefresh and not globalHidden then
            RefreshBackItems()
        end

        if next(attachedProps) ~= nil then
            local currentWeapon = GetSelectedPedWeapon(ped)
            local inVehicle = IsPedInAnyVehicle(ped, false)

            for weaponName, prop in pairs(attachedProps) do
                if DoesEntityExist(prop) then
                    local weaponHash = joaat(weaponName)
                    if weaponHash == currentWeapon or inVehicle or globalHidden then
                        if IsEntityVisible(prop) then
                            SetEntityVisible(prop, false, false)
                        end
                    else
                        if not IsEntityVisible(prop) then
                            SetEntityVisible(prop, true, false)
                        end
                    end
                end
            end
        end
    end
end)

exports('RefreshWeapons', function()
    if not globalHidden then
        ClearBackItems()
        Wait(500)
        RefreshBackItems()
    end
end)
