-- DP-Inventory · server/weapons.lua

local QBCore = exports['qb-core']:GetCoreObject()

local function IsWeaponBlocked(WeaponName)
    local retval = false
    for _, name in pairs(Config.DurabilityBlockedWeapons) do
        if name == WeaponName then
            retval = true
            break
        end
    end
    return retval
end

QBCore.Functions.CreateCallback('DP-Inventory:server:GetConfig', function(_, cb)
    cb(Config.WeaponRepairPoints)
end)

QBCore.Functions.CreateCallback('weapon:server:GetWeaponAmmo', function(source, cb, WeaponData)
    local Player = QBCore.Functions.GetPlayer(source)
    local retval = 0
    if WeaponData then
        if Player then
            local ItemData = Player.Functions.GetItemBySlot(WeaponData.slot)
            if ItemData then
                retval = ItemData.info.ammo and ItemData.info.ammo or 0
            end
        end
    end
    cb(retval, WeaponData.name)
end)

QBCore.Functions.CreateCallback('DP-Inventory:server:RepairWeapon', function(source, cb, RepairPoint, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local minute = 60 * 1000
    local Timeout = math.random(5 * minute, 10 * minute)
    local WeaponData = QBCore.Shared.Weapons[GetHashKey(data.name)]
    local WeaponClass = (QBCore.Shared.SplitStr(WeaponData.ammotype, '_')[2]):lower()

    if not Player then
        cb(false)
        return
    end

    if not Player.PlayerData.items[data.slot] then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_weapon_in_hand'), 'error')
        TriggerClientEvent('DP-Inventory:client:SetCurrentWeapon', src, {}, false)
        cb(false)
        return
    end

    if not Player.PlayerData.items[data.slot].info.quality or Player.PlayerData.items[data.slot].info.quality == 100 then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_damage_on_weapon'), 'error')
        cb(false)
        return
    end

    if not Player.Functions.RemoveMoney('cash', Config.WeaponRepairCosts[WeaponClass]) then
        cb(false)
        return
    end

    Config.WeaponRepairPoints[RepairPoint].IsRepairing = true
    Config.WeaponRepairPoints[RepairPoint].RepairingData = {
        CitizenId = Player.PlayerData.citizenid,
        WeaponData = Player.PlayerData.items[data.slot],
        Ready = false
    }

    if not exports['DP-Inventory']:RemoveItem(src, data.name, 1, data.slot, 'DP-Inventory:server:RepairWeapon') then
        Player.Functions.AddMoney('cash', Config.WeaponRepairCosts[WeaponClass], 'DP-Inventory:server:RepairWeapon')
        return
    end

    TriggerClientEvent('DP-Inventory:client:ItemBox', src, QBCore.Shared.Items[data.name], 'remove')
    TriggerClientEvent('DP-Inventory:client:CheckWeapon', src, data.name)
    TriggerClientEvent('DP-Inventory:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)

    SetTimeout(Timeout, function()
        Config.WeaponRepairPoints[RepairPoint].IsRepairing = false
        Config.WeaponRepairPoints[RepairPoint].RepairingData.Ready = true
        TriggerClientEvent('DP-Inventory:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)
        exports['DP-Phone']:sendNewMailToOffline(Player.PlayerData.citizenid, {
            sender = Lang:t('mail.sender'),
            subject = Lang:t('mail.subject'),
            message = Lang:t('mail.message', {
                value = WeaponData.label
            })
        })

        SetTimeout(7 * 60000, function()
            if Config.WeaponRepairPoints[RepairPoint].RepairingData.Ready then
                Config.WeaponRepairPoints[RepairPoint].IsRepairing = false
                Config.WeaponRepairPoints[RepairPoint].RepairingData = {}
                TriggerClientEvent('DP-Inventory:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint],
                    RepairPoint)
            end
        end)
    end)

    cb(true)
end)

QBCore.Functions.CreateCallback('prison:server:checkThrowable', function(source, cb, weapon)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return cb(false)
    end
    local throwable = false
    for _, v in pairs(Config.Throwables) do
        if QBCore.Shared.Weapons[weapon].name == 'weapon_' .. v then
            if not exports['DP-Inventory']:RemoveItem(source, 'weapon_' .. v, 1, false, 'prison:server:checkThrowable') then
                return cb(false)
            end
            throwable = true
            break
        end
    end
    cb(throwable)
end)

RegisterNetEvent('DP-Inventory:server:UpdateWeaponAmmo', function(CurrentWeaponData, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end
    amount = tonumber(amount)
    if CurrentWeaponData then
        if Player.PlayerData.items[CurrentWeaponData.slot] then
            Player.PlayerData.items[CurrentWeaponData.slot].info.ammo = amount
        end
        Player.Functions.SetInventory(Player.PlayerData.items, true)
    end
end)

RegisterNetEvent('DP-Inventory:server:TakeBackWeapon', function(k)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end
    local itemdata = Config.WeaponRepairPoints[k].RepairingData.WeaponData
    itemdata.info.quality = 100
    exports['DP-Inventory']:AddItem(src, itemdata.name, 1, false, itemdata.info, 'DP-Inventory:server:TakeBackWeapon')
    TriggerClientEvent('DP-Inventory:client:ItemBox', src, QBCore.Shared.Items[itemdata.name], 'add')
    Config.WeaponRepairPoints[k].IsRepairing = false
    Config.WeaponRepairPoints[k].RepairingData = {}
    TriggerClientEvent('DP-Inventory:client:SyncRepairShops', -1, Config.WeaponRepairPoints[k], k)
end)

RegisterNetEvent('DP-Inventory:server:SetWeaponQuality', function(data, hp)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end
    local WeaponSlot = Player.PlayerData.items[data.slot]
    WeaponSlot.info.quality = hp
    Player.Functions.SetInventory(Player.PlayerData.items, true)
end)

RegisterNetEvent('DP-Inventory:server:UpdateWeaponQuality', function(data, RepeatAmount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local WeaponData = QBCore.Shared.Weapons[GetHashKey(data.name)]
    local WeaponSlot = Player.PlayerData.items[data.slot]
    local DecreaseAmount = Config.DurabilityMultiplier[data.name]
    if WeaponSlot then
        if not IsWeaponBlocked(WeaponData.name) then
            if WeaponSlot.info.quality then
                for _ = 1, RepeatAmount, 1 do
                    if WeaponSlot.info.quality - DecreaseAmount > 0 then
                        WeaponSlot.info.quality = QBCore.Shared.Round(WeaponSlot.info.quality - DecreaseAmount, 2)
                    else
                        WeaponSlot.info.quality = 0
                        TriggerClientEvent('DP-Inventory:client:UseWeapon', src, data, false)
                        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.weapon_broken_need_repair'), 'error')
                        break
                    end
                end
            else
                WeaponSlot.info.quality = 100
                for _ = 1, RepeatAmount, 1 do
                    if WeaponSlot.info.quality - DecreaseAmount > 0 then
                        WeaponSlot.info.quality = QBCore.Shared.Round(WeaponSlot.info.quality - DecreaseAmount, 2)
                    else
                        WeaponSlot.info.quality = 0
                        TriggerClientEvent('DP-Inventory:client:UseWeapon', src, data, false)
                        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.weapon_broken_need_repair'), 'error')
                        break
                    end
                end
            end
        end
    end
    Player.Functions.SetInventory(Player.PlayerData.items, true)
end)

RegisterNetEvent('DP-Inventory:server:removeWeaponAmmoItem', function(item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or type(item) ~= 'table' or not item.name or not item.slot then
        return
    end
    exports['DP-Inventory']:RemoveItem(source, item.name, 1, item.slot, 'DP-Inventory:server:removeWeaponAmmoItem')
end)

QBCore.Commands.Add('repairweapon', 'Repair Weapon (God Only)', {{
    name = 'hp',
    help = Lang:t('info.hp_of_weapon')
}}, true, function(source, args)
    TriggerClientEvent('DP-Inventory:client:SetWeaponQuality', source, tonumber(args[1]))
end, 'god')

for ammoItem, properties in pairs(Config.AmmoTypes) do
    QBCore.Functions.CreateUseableItem(ammoItem, function(source, item)
        TriggerClientEvent('DP-Inventory:client:AddAmmo', source, properties.ammoType, properties.amount, item)
    end)
end

local function GetWeaponSlotByName(items, weaponName)
    for index, item in pairs(items) do
        if item.name == weaponName then
            return item, index
        end
    end
    return nil, nil
end

local function IsMK2Weapon(weaponHash)
    local weaponName = QBCore.Shared.Weapons[weaponHash]['name']
    return string.find(weaponName, 'mk2') ~= nil
end

local noTintWeapons = {
    ['weapon_unarmed'] = true,
    ['weapon_flaregun'] = true,
    ['weapon_raypistol'] = true,
    ['weapon_stungun'] = true,
    ['weapon_petrolcan'] = true,
    ['weapon_fireextinguisher'] = true,
    ['weapon_hazardcan'] = true,
    ['weapon_ball'] = true,
    ['weapon_snowball'] = true,
    ['weapon_smokegrenade'] = true,
    ['weapon_stickybomb'] = true,
    ['weapon_proxmine'] = true,
    ['weapon_pipebomb'] = true,
    ['weapon_grenade'] = true,
    ['weapon_molotov'] = true,
    ['weapon_bzgas'] = true,
    ['weapon_flare'] = true,
    ['weapon_digiscanner'] = true,
    ['weapon_parachute'] = true,
    ['weapon_minigun'] = true,
    ['weapon_hominglauncher'] = true,
    ['weapon_rpg'] = true,
    ['weapon_grenadelauncher'] = true,
    ['weapon_grenadelauncher_smoke'] = true,
    ['weapon_compactlauncher'] = true,
    ['weapon_firework'] = true,
    ['weapon_railgun'] = true,
    ['weapon_rayminigun'] = true,
    ['weapon_raycarbine'] = true,
    ['weapon_musket'] = true
}

local function EquipWeaponTint(source, tintIndex, item, isMK2)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return
    end

    local weaponName = nil
    local weaponSlot = nil
    local weaponSlotIndex = nil
    local weaponCount = 0

    local ped = GetPlayerPed(source)
    local selectedHash = GetSelectedPedWeapon(ped)

    for index, invItem in pairs(Player.PlayerData.items) do
        if invItem and invItem.type == 'weapon' then
            weaponCount = weaponCount + 1
            if selectedHash ~= joaat('WEAPON_UNARMED') and joaat(invItem.name) == selectedHash then
                weaponName = invItem.name
                weaponSlot = invItem
                weaponSlotIndex = index
                break
            end
            weaponName = invItem.name
            weaponSlot = invItem
            weaponSlotIndex = index
        end
    end

    if weaponCount > 1 and (selectedHash == joaat('WEAPON_UNARMED') or joaat(weaponName) ~= selectedHash) then
        TriggerClientEvent('QBCore:Notify', source, 'Debes tener el arma en la mano para aplicar el tinte.', 'error')
        return
    end

    if weaponCount == 0 or not weaponName then
        TriggerClientEvent('QBCore:Notify', source, 'No tienes ningún arma en el inventario.', 'error')
        return
    end

    if noTintWeapons[weaponName] then
        TriggerClientEvent('QBCore:Notify', source, 'Este arma no puede llevar tintes.', 'error')
        return
    end

    local weaponHash = joaat(weaponName)
    local isMK2Weap = string.find(weaponName, 'mk2') ~= nil

    if isMK2 and not isMK2Weap then
        TriggerClientEvent('QBCore:Notify', source, 'Este tinte es exclusivo para armas MK2.', 'error')
        return
    end

    if not isMK2 and isMK2Weap then
        TriggerClientEvent('QBCore:Notify', source, 'Las armas MK2 usan tintes exclusivos MK2.', 'error')
        return
    end

    weaponSlot.info = weaponSlot.info or {}

    if weaponSlot.info.tint == tintIndex then
        TriggerClientEvent('QBCore:Notify', source, 'Este tinte ya está aplicado en tu arma.', 'error')
        return
    end

    weaponSlot.info.tint = tintIndex
    Player.PlayerData.items[weaponSlotIndex] = weaponSlot
    Player.Functions.SetInventory(Player.PlayerData.items, true)
    exports['DP-Inventory']:RemoveItem(source, item, 1, false, 'DP-Inventory:EquipWeaponTint')
    TriggerClientEvent('DP-Inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'remove')
    TriggerClientEvent('DP-Inventory:client:EquipTint', source, weaponHash, tintIndex)
    TriggerClientEvent('QBCore:Notify', source, 'Tinte aplicado correctamente.', 'success')
end

local standardTints = {{
    name = 'weapontint_black',
    index = 0
}, {
    name = 'weapontint_green',
    index = 1
}, {
    name = 'weapontint_gold',
    index = 2
}, {
    name = 'weapontint_pink',
    index = 3
}, {
    name = 'weapontint_army',
    index = 4
}, {
    name = 'weapontint_lspd',
    index = 5
}, {
    name = 'weapontint_orange',
    index = 6
}, {
    name = 'weapontint_plat',
    index = 7
}}

for _, tint in ipairs(standardTints) do
    local tintIndex = tint.index
    local tintName = tint.name
    QBCore.Functions.CreateUseableItem(tintName, function(source, item)
        EquipWeaponTint(source, tintIndex, tintName, false)
    end)
end

for i = 0, 32 do
    QBCore.Functions.CreateUseableItem('weapontint_mk2_' .. i, function(source, item)
        EquipWeaponTint(source, i, item.name, true)
    end)
end

local function HasAttachment(component, attachments)
    for k, v in pairs(attachments) do
        if v.component == component then
            return true, k
        end
    end
    return false, nil
end

local function DoesWeaponTakeWeaponComponent(item, weaponName)
    if WeaponAttachments[item] and WeaponAttachments[item][weaponName] then
        return WeaponAttachments[item][weaponName]
    end
    return false
end

local function EquipWeaponAttachment(src, item)
    local shouldRemove = false
    local ped = GetPlayerPed(src)
    local selectedWeaponHash = GetSelectedPedWeapon(ped)

    if selectedWeaponHash == joaat('WEAPON_UNARMED') then
        TriggerClientEvent('QBCore:Notify', src, 'Debes tener un arma en las manos.', 'error')
        return
    end

    local weaponName = nil
    for k, v in pairs(QBCore.Shared.Weapons) do
        if GetHashKey(k) == selectedWeaponHash then
            weaponName = v.name
            break
        end
    end

    if not weaponName then
        return
    end

    local attachmentComponent = DoesWeaponTakeWeaponComponent(item, weaponName)
    if not attachmentComponent then
        TriggerClientEvent('QBCore:Notify', src, 'Este accesorio no es compatible con tu arma.', 'error')
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return
    end

    local weaponSlot, weaponSlotIndex = GetWeaponSlotByName(Player.PlayerData.items, weaponName)
    if not weaponSlot then
        return
    end

    weaponSlot.info.attachments = weaponSlot.info.attachments or {}
    local hasAttach, attachIndex = HasAttachment(attachmentComponent, weaponSlot.info.attachments)

    if hasAttach then
        RemoveWeaponComponentFromPed(ped, selectedWeaponHash, attachmentComponent)
        table.remove(weaponSlot.info.attachments, attachIndex)
    else
        weaponSlot.info.attachments[#weaponSlot.info.attachments + 1] = {
            component = attachmentComponent
        }
        GiveWeaponComponentToPed(ped, selectedWeaponHash, attachmentComponent)
        shouldRemove = true
    end

    Player.PlayerData.items[weaponSlotIndex] = weaponSlot
    Player.Functions.SetInventory(Player.PlayerData.items, true)

    if shouldRemove then
        exports['DP-Inventory']:RemoveItem(src, item, 1, false, 'DP-Inventory:EquipWeaponAttachment')
        TriggerClientEvent('DP-Inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'remove')
    end
end

for attachmentItem in pairs(WeaponAttachments) do
    QBCore.Functions.CreateUseableItem(attachmentItem, function(source, item)
        EquipWeaponAttachment(source, item.name)
    end)
end

QBCore.Functions.CreateCallback('DP-Inventory:server:RemoveAttachment', function(source, cb, AttachmentData, WeaponData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Inventory = Player.PlayerData.items
    local allAttachments = WeaponAttachments
    local AttachmentComponent = allAttachments[AttachmentData.attachment][WeaponData.name]
    if Inventory[WeaponData.slot] then
        if Inventory[WeaponData.slot].info.attachments and next(Inventory[WeaponData.slot].info.attachments) then
            local HasAttach, key = HasAttachment(AttachmentComponent, Inventory[WeaponData.slot].info.attachments)
            if HasAttach then
                table.remove(Inventory[WeaponData.slot].info.attachments, key)
                Player.Functions.SetInventory(Player.PlayerData.items, true)
                exports['DP-Inventory']:AddItem(src, AttachmentData.attachment, 1, false, false,
                    'DP-Inventory:server:RemoveAttachment')
                TriggerClientEvent('DP-Inventory:client:ItemBox', src, QBCore.Shared.Items[AttachmentData.attachment],
                    'add')
                TriggerClientEvent('QBCore:Notify', src, Lang:t('info.removed_attachment', {
                    value = QBCore.Shared.Items[AttachmentData.attachment].label
                }), 'error')
                cb(Inventory[WeaponData.slot].info.attachments)
            else
                cb(false)
            end
        else
            cb(false)
        end
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('DP-Inventory:server:AddAttachment', function(source, cb, AttachmentItem, WeaponData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb({
            success = false
        })
        return
    end

    local attachmentComponent = DoesWeaponTakeWeaponComponent(AttachmentItem.name, WeaponData.name)
    if not attachmentComponent then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_support_attachment'), 'error')
        cb({
            success = false
        })
        return
    end

    local weaponSlot, weaponSlotIndex = GetWeaponSlotByName(Player.PlayerData.items, WeaponData.name)
    if not weaponSlot then
        cb({
            success = false
        })
        return
    end

    weaponSlot.info.attachments = weaponSlot.info.attachments or {}

    local hasAttach = HasAttachment(attachmentComponent, weaponSlot.info.attachments)
    if hasAttach then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.attachment_already_on_weapon', {
            value = QBCore.Shared.Items[AttachmentItem.name] and QBCore.Shared.Items[AttachmentItem.name].label or
                AttachmentItem.name
        }), 'error')
        cb({
            success = false
        })
        return
    end

    weaponSlot.info.attachments[#weaponSlot.info.attachments + 1] = {
        component = attachmentComponent
    }
    Player.PlayerData.items[weaponSlotIndex] = weaponSlot
    Player.Functions.SetInventory(Player.PlayerData.items, true)

    exports['DP-Inventory']:RemoveItem(src, AttachmentItem.name, 1, AttachmentItem.slot,
        'DP-Inventory:server:AddAttachment')
    TriggerClientEvent('DP-Inventory:client:ItemBox', src, QBCore.Shared.Items[AttachmentItem.name], 'remove')

    cb({
        success = true,
        attachments = weaponSlot.info.attachments
    })
end)
