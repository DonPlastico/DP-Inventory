-- ==============================================================================
-- DP-INVENTORY: ESTRUCTURA PRINCIPAL DE BASE DE DATOS
-- Ejecutar en servidores nuevos o tras un wipe total.
-- ==============================================================================

-- 1. TABLA MAESTRA DE INVENTARIOS SECUNDARIOS
-- Guarda Stashes, Maleteros, Guanteras y el interior de las Mochilas.
-- El 'identifier' usa prefijos (ej: 'trunk-123XYZ', 'glovebox-...', 'bag_...')
CREATE TABLE IF NOT EXISTS `inventories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(255) NOT NULL,
  `items` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`items`)),
  PRIMARY KEY (`identifier`),
  KEY `id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 2. TABLA DE PREFERENCIAS UNIFICADA (DP-SCRIPTS)
-- Guarda los ajustes que el jugador configura en la pestaña "Ajustes" del inventario
-- y también integra las coordenadas guardadas del script DP-Boombox_v2.
CREATE TABLE IF NOT EXISTS `dp_preferences` (
  `citizenid` varchar(50) NOT NULL,
  `menu_top` varchar(20) DEFAULT '14.537%',
  `menu_left` varchar(20) DEFAULT '62.5%',
  `menu_scale` INT DEFAULT 90,
  `inventory_position` varchar(20) DEFAULT 'bottom',
  `move_while_open` INT DEFAULT 0,
  `ui_sounds` INT DEFAULT 1,
  `boombox_move_open` INT DEFAULT 0,
  `boombox_top` varchar(20) DEFAULT NULL,
  `boombox_left` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;