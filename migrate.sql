-- ==============================================================================
-- DP-INVENTORY: SCRIPT DE MIGRACIÓN
-- IMPORTANTE: Ejecutar SOLAMENTE si vienes de qb-inventory o lj-inventory.
-- Transfiere los datos de las 3 tablas antiguas a la nueva tabla maestra y 
-- actualiza la tabla de preferencias si ya existía.
-- ==============================================================================

-- 1. Transferir todo a la nueva tabla 'inventories' añadiendo los prefijos correctos
INSERT IGNORE INTO inventories (identifier, items)
SELECT CONCAT('glovebox-', plate), items FROM gloveboxitems
UNION ALL
SELECT stash, items FROM stashitems
UNION ALL
SELECT CONCAT('trunk-', plate), items FROM trunkitems;

-- 2. Limpieza (Opcional pero recomendada)
-- Descomenta (quita los --) las siguientes 3 líneas si quieres borrar las tablas viejas
-- tras comprobar que la migración ha funcionado y los jugadores tienen sus cosas.
-- DROP TABLE IF EXISTS `gloveboxitems`;
-- DROP TABLE IF EXISTS `stashitems`;
-- DROP TABLE IF EXISTS `trunkitems`;

-- 3. Actualizar la tabla 'dp_preferences' existente
-- Agrega las columnas de configuración nuevas si la tabla ya había sido
-- creada por versiones anteriores o por el DP-Boombox_v2.
-- IGNORAR ERRORES "Duplicate column name" si las columnas ya existen.
ALTER TABLE `dp_preferences` ADD COLUMN IF NOT EXISTS `ui_sounds` INT DEFAULT 1;
ALTER TABLE `dp_preferences` ADD COLUMN IF NOT EXISTS `boombox_move_open` INT DEFAULT 0;
ALTER TABLE `dp_preferences` ADD COLUMN IF NOT EXISTS `boombox_top` varchar(20) DEFAULT NULL;
ALTER TABLE `dp_preferences` ADD COLUMN IF NOT EXISTS `boombox_left` varchar(20) DEFAULT NULL;
ALTER TABLE `dp_preferences` ADD COLUMN IF NOT EXISTS `inventory_position` varchar(20) DEFAULT 'bottom';
ALTER TABLE `dp_preferences` ADD COLUMN IF NOT EXISTS `move_while_open` INT DEFAULT 0;