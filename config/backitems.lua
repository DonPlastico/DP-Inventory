-- ==========================================
-- DP-Inventory BACKITEMS CONFIG (VERTICAL TÁCTICO)
-- Huesos de referencia:
-- 24818: Espalda (Spine)
-- 51826: Cadera/Muslo Derecho (Pistolas)
-- 58271: Cadera/Muslo Izquierdo (Cuchillos)
-- ==========================================

BackItemsConfig = {
    
    -- ==========================================
    -- 🔫 RIFLES DE ASALTO (Espalda, lado IZQUIERDO, cañón abajo)
    -- ==========================================
    ['weapon_assaultrifle'] = { model = 'w_ar_assaultrifle', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_assaultrifle_mk2'] = { model = 'w_ar_assaultriflemk2', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_carbinerifle'] = { model = 'w_ar_carbinerifle', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_carbinerifle_mk2'] = { model = 'w_ar_carbineriflemk2', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_advancedrifle'] = { model = 'w_ar_advancedrifle', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_specialcarbine'] = { model = 'w_ar_specialcarbine', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_specialcarbine_mk2'] = { model = 'w_ar_specialcarbinemk2', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_bullpuprifle'] = { model = 'w_ar_bullpuprifle', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_bullpuprifle_mk2'] = { model = 'w_ar_bullpupriflemk2', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_compactrifle'] = { model = 'w_ar_assaultrifle_smg', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_militaryrifle'] = { model = 'w_ar_heavyrifleh', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_heavyrifle'] = { model = 'w_ar_heavyrifle', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_tacticalrifle'] = { model = 'w_ar_carbinerifle_sec', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_ak47'] = { model = 'w_ar_ak47', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_m70'] = { model = 'w_ar_m70', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_groza'] = { model = 'w_ar_groza', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_m4'] = { model = 'w_ar_m4', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_hk416'] = { model = 'w_ar_hk416', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_scarh'] = { model = 'w_ar_scarh', bone = 24818, x = -0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },

    -- ==========================================
    -- 🔭 FRANCOTIRADORES Y LMGs (Espalda, lado DERECHO, cañón abajo)
    -- ==========================================
    ['weapon_sniperrifle'] = { model = 'w_sr_sniperrifle', bone = 24818, x = 0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_heavysniper'] = { model = 'w_sr_heavysniper', bone = 24818, x = 0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_heavysniper_mk2'] = { model = 'w_sr_heavysnipermk2', bone = 24818, x = 0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_marksmanrifle'] = { model = 'w_sr_marksmanrifle', bone = 24818, x = 0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_marksmanrifle_mk2'] = { model = 'w_sr_marksmanriflemk2', bone = 24818, x = 0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_precisionrifle'] = { model = 'w_sr_heavysniper', bone = 24818, x = 0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_mg'] = { model = 'w_mg_mg', bone = 24818, x = 0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_combatmg'] = { model = 'w_mg_combatmg', bone = 24818, x = 0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_combatmg_mk2'] = { model = 'w_mg_combatmgmk2', bone = 24818, x = 0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_m110'] = { model = 'w_sr_m110', bone = 24818, x = 0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_huntingrifle'] = { model = 'w_sr_huntingrifle', bone = 24818, x = 0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_mk14'] = { model = 'w_sr_mk14', bone = 24818, x = 0.15, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },

    -- ==========================================
    -- 💥 ESCOPETAS (Espalda, ligeramente a la Izquierda para equilibrar)
    -- ==========================================
    ['weapon_pumpshotgun'] = { model = 'w_sg_pumpshotgun', bone = 24818, x = -0.07, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_pumpshotgun_mk2'] = { model = 'w_sg_pumpshotgunmk2', bone = 24818, x = -0.07, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_sawnoffshotgun'] = { model = 'w_sg_sawnoff', bone = 24818, x = -0.07, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_assaultshotgun'] = { model = 'w_sg_assaultshotgun', bone = 24818, x = -0.07, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_bullpupshotgun'] = { model = 'w_sg_bullpupshotgun', bone = 24818, x = -0.07, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_musket'] = { model = 'w_ar_musket', bone = 24818, x = -0.07, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_heavyshotgun'] = { model = 'w_sg_heavyshotgun', bone = 24818, x = -0.07, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_dbshotgun'] = { model = 'w_sg_doublebarrel', bone = 24818, x = -0.07, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_autoshotgun'] = { model = 'w_sg_sweeper', bone = 24818, x = -0.07, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_combatshotgun'] = { model = 'w_sg_pumpshotgunh0', bone = 24818, x = -0.07, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_remington'] = { model = 'w_sg_remington', bone = 24818, x = -0.07, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_mossberg'] = { model = 'w_sg_mossberg', bone = 24818, x = -0.07, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_beanbag'] = { model = 'w_sg_beanbag', bone = 24818, x = -0.07, y = -0.16, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },

    -- ==========================================
    -- 🚀 ARMAS PESADAS (Espalda, CENTRO EXACTO, cañón abajo)
    -- ==========================================
    ['weapon_rpg'] = { model = 'w_lr_rpg', bone = 24818, x = 0.0, y = -0.18, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_grenadelauncher'] = { model = 'w_lr_grenadelauncher', bone = 24818, x = 0.0, y = -0.18, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_minigun'] = { model = 'w_mg_minigun', bone = 24818, x = 0.0, y = -0.18, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_firework'] = { model = 'w_lr_firework', bone = 24818, x = 0.0, y = -0.18, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_railgun'] = { model = 'w_ar_railgun', bone = 24818, x = 0.0, y = -0.18, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_hominglauncher'] = { model = 'w_lr_homing', bone = 24818, x = 0.0, y = -0.18, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_compactlauncher'] = { model = 'w_lr_compactgl', bone = 24818, x = 0.0, y = -0.18, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_rayminigun'] = { model = 'w_mg_sminigun', bone = 24818, x = 0.0, y = -0.18, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_emplauncher'] = { model = 'w_lr_emplauncher', bone = 24818, x = 0.0, y = -0.18, z = 0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },

    -- ==========================================
    -- 🔫 SUBFUSILES - SMGs (Espalda, ligeramente derecha y MÁS ABAJO)
    -- ==========================================
    ['weapon_smg'] = { model = 'w_sb_smg', bone = 24818, x = 0.08, y = -0.16, z = -0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_microsmg'] = { model = 'w_sb_microsmg', bone = 24818, x = 0.08, y = -0.16, z = -0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_smg_mk2'] = { model = 'w_sb_smgmk2', bone = 24818, x = 0.08, y = -0.16, z = -0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_assaultsmg'] = { model = 'w_sb_assaultsmg', bone = 24818, x = 0.08, y = -0.16, z = -0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_combatpdw'] = { model = 'w_sb_pdw', bone = 24818, x = 0.08, y = -0.16, z = -0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_machinepistol'] = { model = 'w_sb_compactsmg', bone = 24818, x = 0.08, y = -0.16, z = -0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_minismg'] = { model = 'w_sb_minismg', bone = 24818, x = 0.08, y = -0.16, z = -0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_raycarbine'] = { model = 'w_ar_mxsilen', bone = 24818, x = 0.08, y = -0.16, z = -0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_gusenberg'] = { model = 'w_sb_gusenberg', bone = 24818, x = 0.08, y = -0.16, z = -0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_uzi'] = { model = 'w_sb_uzi', bone = 24818, x = 0.08, y = -0.16, z = -0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_mp9'] = { model = 'w_sb_mp9', bone = 24818, x = 0.08, y = -0.16, z = -0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },
    ['weapon_mac10'] = { model = 'w_sb_mac10', bone = 24818, x = 0.08, y = -0.16, z = -0.05, x_rot = 180.0, y_rot = -180.0, z_rot = 180.0 },

    -- ==========================================
    -- 🔫 PISTOLAS (Cadera Derecha / Cinturón)
    -- ==========================================
    ['weapon_pistol'] = { model = 'w_pi_pistol', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_combatpistol'] = { model = 'w_pi_combatpistol', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_appistol'] = { model = 'w_pi_appistol', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_stungun'] = { model = 'w_pi_stungun', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_pistol50'] = { model = 'w_pi_pistol50', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_snspistol'] = { model = 'w_pi_sns_pistol', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_heavypistol'] = { model = 'w_pi_heavypistol', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_vintagepistol'] = { model = 'w_pi_vintage_pistol', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_flaregun'] = { model = 'w_pi_flaregun', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_marksmanpistol'] = { model = 'w_pi_marksman_pistol', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_revolver'] = { model = 'w_pi_revolver', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_revolver_mk2'] = { model = 'w_pi_revolvermk2', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_doubleaction'] = { model = 'w_pi_doubleaction', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_pistol_mk2'] = { model = 'w_pi_pistolmk2', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_snspistol_mk2'] = { model = 'w_pi_sns_pistolmk2', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_ceramicpistol'] = { model = 'w_pi_ceramic_pistol', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_navyrevolver'] = { model = 'w_pi_navyrevolver', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },
    ['weapon_gadgetpistol'] = { model = 'w_pi_ap_pistol_sec', bone = 51826, x = -0.01, y = 0.10, z = 0.07, x_rot = -115.0, y_rot = 0.0, z_rot = 0.0 },

    -- ==========================================
    -- 🗡️ CUERPO A CUERPO PEQUEÑAS (Cadera Izquierda / Cinturón)
    -- ==========================================
    ['weapon_knife'] = { model = 'w_me_knife', bone = 11816, x = -0.1, y = -0.15, z = 0.12, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_dagger'] = { model = 'w_me_dagger', bone = 11816, x = -0.1, y = -0.15, z = 0.12, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_switchblade'] = { model = 'w_me_switchblade', bone = 11816, x = -0.1, y = -0.15, z = 0.12, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_hatchet'] = { model = 'w_me_hatchet', bone = 11816, x = -0.1, y = -0.15, z = 0.12, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_hammer'] = { model = 'w_me_hammer', bone = 11816, x = -0.1, y = -0.15, z = 0.12, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_bottle'] = { model = 'w_me_bottle', bone = 11816, x = -0.1, y = -0.15, z = 0.12, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_flashlight'] = { model = 'w_me_flashlight', bone = 11816, x = -0.1, y = -0.15, z = 0.12, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_nightstick'] = { model = 'w_me_nightstick', bone = 11816, x = -0.1, y = -0.15, z = 0.12, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },

    -- ==========================================
    -- 🪓 CUERPO A CUERPO GRANDES (Espalda, Diagonal Hombro Derecho -> Cadera Izquierda)
    -- ==========================================
    ['weapon_bat'] = { model = 'w_me_bat', bone = 24818, x = 0.0, y = -0.16, z = 0.05, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_golfclub'] = { model = 'w_me_golfclub', bone = 24818, x = 0.0, y = -0.16, z = 0.05, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_crowbar'] = { model = 'w_me_crowbar', bone = 24818, x = 0.0, y = -0.16, z = 0.05, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_machete'] = { model = 'w_me_machete', bone = 24818, x = 0.0, y = -0.16, z = 0.05, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_poolcue'] = { model = 'w_me_poolcue', bone = 24818, x = 0.0, y = -0.16, z = 0.05, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_battleaxe'] = { model = 'w_me_battleaxe', bone = 24818, x = 0.0, y = -0.16, z = 0.05, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_stone_hatchet'] = { model = 'w_me_stonehatchet', bone = 24818, x = 0.0, y = -0.16, z = 0.05, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_katana'] = { model = 'w_me_katana', bone = 24818, x = 0.0, y = -0.16, z = 0.05, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_sword'] = { model = 'w_me_sword', bone = 24818, x = 0.0, y = -0.16, z = 0.05, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_dildo'] = { model = 'w_me_dildo', bone = 24818, x = 0.0, y = -0.16, z = 0.05, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_sledgehammer'] = { model = 'w_me_sledgehammer', bone = 24818, x = 0.0, y = -0.16, z = 0.05, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
    ['weapon_perforator'] = { model = 'w_me_perforator', bone = 24818, x = 0.0, y = -0.16, z = 0.05, x_rot = 0.0, y_rot = 135.0, z_rot = 0.0 },
}