local UNARMED_HASH = joaat('WEAPON_UNARMED')

local holstered = true
local canFire = true
local currWeap = UNARMED_HASH
local currHolster = nil
local currHolsterTexture = nil
local wearingHolster = nil
local isDrawLoopActive = false -- Evita que se creen bucles duplicados

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then
        return
    end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

-- Detecta cualquier arma (vanilla o custom) excepto puños, nudillera invisible y navaja retráctil
local function checkWeapon(newWeap)
    if not newWeap or newWeap == 0 or newWeap == UNARMED_HASH or newWeap == joaat('WEAPON_KNUCKLE') or newWeap == joaat('WEAPON_SWITCHBLADE') then
        return false
    end
    return true
end

local function isWeaponHolsterable(weap)
    if not Config.WeapDraw or not Config.WeapDraw.weapons then
        return false
    end
    for i = 1, #Config.WeapDraw.weapons do
        if joaat(Config.WeapDraw.weapons[i]) == weap then
            return true
        end
    end
    return false
end

RegisterNetEvent('DP-Inventory:client:ResetHolster', function()
    holstered = true
    canFire = true
    currWeap = UNARMED_HASH
    currHolster = nil
    currHolsterTexture = nil
    wearingHolster = nil
end)

RegisterNetEvent('DP-Inventory:client:DrawWeapon', function()
    if GetResourceState('DP-Inventory') == 'missing' then
        return
    end
    if isDrawLoopActive then
        return
    end -- Ya hay un bucle vigilando, no creamos otro
    isDrawLoopActive = true

    CreateThread(function()
        local weaponCheck = 0
        while true do
            local ped = PlayerPedId()
            local sleep = 250

            if DoesEntityExist(ped) and not IsEntityDead(ped) and not IsPedInParachuteFreeFall(ped) and
                not IsPedFalling(ped) and (GetPedParachuteState(ped) == -1 or GetPedParachuteState(ped) == 0) then
                sleep = 0
                local selectedWeap = GetSelectedPedWeapon(ped)

                if currWeap ~= selectedWeap then
                    local pos = GetEntityCoords(ped, true)
                    local rot = GetEntityHeading(ped)
                    local newWeap = selectedWeap

                    SetCurrentPedWeapon(ped, currWeap, true)
                    loadAnimDict('reaction@intimidation@1h')
                    loadAnimDict('reaction@intimidation@cop@unarmed')
                    loadAnimDict('rcmjosh4')
                    loadAnimDict('weapons@pistol@')

                    local holsterVariant = GetPedDrawableVariation(ped, 8)
                    wearingHolster = false
                    if Config.WeapDraw and Config.WeapDraw.variants then
                        for i = 1, #Config.WeapDraw.variants do
                            if holsterVariant == Config.WeapDraw.variants[i] then
                                wearingHolster = true
                                break
                            end
                        end
                    end

                    if checkWeapon(newWeap) then
                        if holstered then
                            -- SACAR ARMA DESDE DESARMADO
                            canFire = false
                            CeaseFire()
                            if wearingHolster then
                                currHolster = GetPedDrawableVariation(ped, 7)
                                currHolsterTexture = GetPedTextureVariation(ped, 7)
                                TaskPlayAnimAdvanced(ped, 'rcmjosh4', 'josh_leadout_cop2', pos.x, pos.y, pos.z, 0, 0,
                                    rot, 3.0, 3.0, -1, 50, 0, 0, 0)
                                Wait(300)
                                SetCurrentPedWeapon(ped, newWeap, true)
                                currWeap = newWeap
                                Wait(300)
                            else
                                TaskPlayAnimAdvanced(ped, 'reaction@intimidation@1h', 'intro', pos.x, pos.y, pos.z, 0,
                                    0, rot, 8.0, 3.0, -1, 50, 0, 0, 0)
                                Wait(1000)
                                SetCurrentPedWeapon(ped, newWeap, true)
                                currWeap = newWeap
                                Wait(1000)
                            end
                            ClearPedTasks(ped)
                            holstered = false
                            canFire = true

                        elseif newWeap ~= currWeap and checkWeapon(currWeap) then
                            -- CAMBIAR DIRECTAMENTE DE ARMA A -> ARMA B (Ej: Pistola a Escopeta)
                            canFire = false
                            CeaseFire()
                            if wearingHolster then
                                TaskPlayAnimAdvanced(ped, 'reaction@intimidation@cop@unarmed', 'intro', pos.x, pos.y,
                                    pos.z, 0, 0, rot, 3.0, 3.0, -1, 50, 0, 0, 0)
                                Wait(500)
                                if isWeaponHolsterable(currWeap) then
                                    SetPedComponentVariation(ped, 7, currHolster, currHolsterTexture, 2)
                                end
                                SetCurrentPedWeapon(ped, UNARMED_HASH, true)
                                currHolster = GetPedDrawableVariation(ped, 7)
                                currHolsterTexture = GetPedTextureVariation(ped, 7)
                                TaskPlayAnimAdvanced(ped, 'rcmjosh4', 'josh_leadout_cop2', pos.x, pos.y, pos.z, 0, 0,
                                    rot, 3.0, 3.0, -1, 50, 0, 0, 0)
                                Wait(300)
                                SetCurrentPedWeapon(ped, newWeap, true)
                                Wait(500)
                            else
                                -- 1. Guarda arma actual
                                TaskPlayAnimAdvanced(ped, 'reaction@intimidation@1h', 'outro', pos.x, pos.y, pos.z, 0,
                                    0, rot, 8.0, 3.0, -1, 50, 0, 0, 0)
                                Wait(1400)
                                SetCurrentPedWeapon(ped, UNARMED_HASH, true)
                                -- 2. Saca arma nueva
                                TaskPlayAnimAdvanced(ped, 'reaction@intimidation@1h', 'intro', pos.x, pos.y, pos.z, 0,
                                    0, rot, 8.0, 3.0, -1, 50, 0, 0, 0)
                                Wait(1000)
                                SetCurrentPedWeapon(ped, newWeap, true)
                                Wait(1000)
                            end
                            currWeap = newWeap
                            ClearPedTasks(ped)
                            holstered = false
                            canFire = true
                        else
                            -- FALLBACK: Saca arma nueva
                            canFire = false
                            CeaseFire()
                            SetCurrentPedWeapon(ped, UNARMED_HASH, true)
                            if wearingHolster then
                                currHolster = GetPedDrawableVariation(ped, 7)
                                currHolsterTexture = GetPedTextureVariation(ped, 7)
                                TaskPlayAnimAdvanced(ped, 'rcmjosh4', 'josh_leadout_cop2', pos.x, pos.y, pos.z, 0, 0,
                                    rot, 3.0, 3.0, -1, 50, 0, 0, 0)
                                Wait(300)
                                SetCurrentPedWeapon(ped, newWeap, true)
                                Wait(300)
                            else
                                TaskPlayAnimAdvanced(ped, 'reaction@intimidation@1h', 'intro', pos.x, pos.y, pos.z, 0,
                                    0, rot, 8.0, 3.0, -1, 50, 0, 0, 0)
                                Wait(1000)
                                SetCurrentPedWeapon(ped, newWeap, true)
                                Wait(1000)
                            end
                            currWeap = newWeap
                            ClearPedTasks(ped)
                            holstered = false
                            canFire = true
                        end
                    else
                        -- GUARDAR ARMA (A DESARMADO)
                        if not holstered and checkWeapon(currWeap) then
                            canFire = false
                            CeaseFire()
                            if wearingHolster then
                                TaskPlayAnimAdvanced(ped, 'reaction@intimidation@cop@unarmed', 'intro', pos.x, pos.y,
                                    pos.z, 0, 0, rot, 3.0, 3.0, -1, 50, 0, 0, 0)
                                Wait(500)
                                if isWeaponHolsterable(currWeap) then
                                    SetPedComponentVariation(ped, 7, currHolster, currHolsterTexture, 2)
                                end
                            else
                                TaskPlayAnimAdvanced(ped, 'reaction@intimidation@1h', 'outro', pos.x, pos.y, pos.z, 0,
                                    0, rot, 8.0, 3.0, -1, 50, 0, 0, 0)
                                Wait(1400)
                            end
                            SetCurrentPedWeapon(ped, UNARMED_HASH, true)
                            ClearPedTasks(ped)
                            SetCurrentPedWeapon(ped, newWeap, true)
                            holstered = true
                            canFire = true
                            currWeap = newWeap
                        else
                            SetCurrentPedWeapon(ped, newWeap, true)
                            holstered = true
                            canFire = true
                            currWeap = newWeap
                        end
                    end
                end
            end

            Wait(sleep)

            if currWeap == nil or currWeap == UNARMED_HASH then
                weaponCheck = weaponCheck + 1
                if weaponCheck >= 4 then
                    break
                end
            else
                weaponCheck = 0
            end
        end
        isDrawLoopActive = false
    end)
end)

function CeaseFire()
    CreateThread(function()
        if GetResourceState('DP-Inventory') == 'missing' then
            return
        end
        while not canFire do
            DisableControlAction(0, 25, true)
            DisablePlayerFiring(PlayerId(), true)
            Wait(0)
        end
    end)
end
