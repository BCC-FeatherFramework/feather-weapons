-- Feather Weapons: complete installation and existing-database migrations.
-- Import after the Feather Inventory schema and migrations, with Inventory and Weapons stopped.
-- Use a MySQL/MariaDB client that supports DELIMITER and stops on errors (do not use --force).
-- Utility/throwable renames skip existing targets; both item IDs and ownership are preserved.
-- Conflicting revolver names still require manual resolution before retrying.
-- Restart the server after a successful import.

-- ============================================================================
-- Source: rename_weapon_ids.sql
-- ============================================================================
-- One-time alpha data cutover to the <family>_<model> weapon ID convention.
-- Run before install_items.sql. A conflicting new-name row intentionally makes
-- this transaction fail instead of guessing which definition should survive.

START TRANSACTION;

UPDATE `items`
SET `name` = 'revolver_cattleman'
WHERE `name` = 'cattleman_revolver';

UPDATE `items`
SET `name` = 'revolver_schofield'
WHERE `name` = 'schofield_revolver';

UPDATE `inventory_items`
SET `metadata` = JSON_SET(`metadata`, '$.weaponDefinitionId', 'revolver_cattleman'),
    `metadata_revision` = `metadata_revision` + 1,
    `row_revision` = `row_revision` + 1
WHERE JSON_VALID(`metadata`)
  AND JSON_UNQUOTE(JSON_EXTRACT(`metadata`, '$.weaponDefinitionId')) = 'cattleman_revolver';

UPDATE `inventory_items`
SET `metadata` = JSON_SET(`metadata`, '$.weaponDefinitionId', 'revolver_schofield'),
    `metadata_revision` = `metadata_revision` + 1,
    `row_revision` = `row_revision` + 1
WHERE JSON_VALID(`metadata`)
  AND JSON_UNQUOTE(JSON_EXTRACT(`metadata`, '$.weaponDefinitionId')) = 'schofield_revolver';

COMMIT;

-- ============================================================================
-- Source: rename_weapon_item_names.sql
-- ============================================================================
-- Run with Inventory and Weapons stopped, BEFORE install_items.sql.
-- Abort on conflicting names; do not merge distinct inventory definitions.
-- Renaming the existing rows preserves numeric item IDs and owned instances.
-- Weapon metadata weaponDefinitionId remains revolver_cattleman/revolver_schofield.
DELIMITER //
CREATE PROCEDURE feather_rename_weapon_item_names()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF EXISTS (
        SELECT 1 FROM items
        WHERE name IN ('revolver_cattleman', 'weapon_revolver_cattleman',
                       'revolver_schofield', 'weapon_revolver_schofield')
        GROUP BY CASE
            WHEN name IN ('revolver_cattleman', 'weapon_revolver_cattleman') THEN 'cattleman'
            ELSE 'schofield'
        END
        HAVING COUNT(*) > 1
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Conflicting weapon item rows: resolve duplicates before renaming.';
    END IF;
    UPDATE items SET name = 'weapon_revolver_cattleman' WHERE name = 'revolver_cattleman';
    UPDATE items SET name = 'weapon_revolver_schofield' WHERE name = 'revolver_schofield';
    COMMIT;
END//
DELIMITER ;
CALL feather_rename_weapon_item_names();
DROP PROCEDURE feather_rename_weapon_item_names;

-- ============================================================================
-- Source: rename_utility_item_names.sql
-- ============================================================================
-- Run with Inventory and Weapons stopped; restart afterward to reload item caches.
-- Rename only when the canonical target is absent. Existing duplicates remain unchanged.
-- Preserve numeric item IDs, owned instances, equipment, and metadata.
UPDATE `items` AS legacy
JOIN (
    SELECT 'weapon_utility_lasso_reinforced' AS old_name, 'weapon_lasso_reinforced' AS new_name
    UNION ALL SELECT 'weapon_utility_lasso', 'weapon_lasso'
    UNION ALL SELECT 'weapon_utility_davy_lantern', 'weapon_melee_davy_lantern'
    UNION ALL SELECT 'weapon_utility_binoculars_improved', 'weapon_kit_binoculars_improved'
    UNION ALL SELECT 'weapon_utility_binoculars', 'weapon_kit_binoculars'
    UNION ALL SELECT 'weapon_utility_metal_detector', 'weapon_kit_metal_detector'
    UNION ALL SELECT 'weapon_utility_fishing_rod', 'weapon_fishingrod'
    UNION ALL SELECT 'weapon_utility_camera_advanced', 'weapon_kit_camera_advanced'
    UNION ALL SELECT 'weapon_utility_camera', 'weapon_kit_camera'
) AS renames ON legacy.`name` = renames.old_name
LEFT JOIN `items` AS canonical ON canonical.`name` = renames.new_name
SET legacy.`name` = renames.new_name
WHERE canonical.`name` IS NULL;

-- ============================================================================
-- Source: rename_throwable_item_names.sql
-- ============================================================================
-- Run with Inventory and Weapons stopped; restart afterward to reload item caches.
-- Rename only when the canonical target is absent. Existing duplicates remain unchanged.
-- Preserve numeric item IDs, owned instances, equipment, and metadata.
UPDATE `items` AS legacy
JOIN (
    SELECT 'weapon_throwable_throwing_knives' AS old_name, 'weapon_thrown_throwing_knives' AS new_name
    UNION ALL SELECT 'weapon_throwable_tomahawk_ancient', 'weapon_thrown_ancient_tomahawk'
    UNION ALL SELECT 'weapon_throwable_tomahawk', 'weapon_thrown_tomahawk'
    UNION ALL SELECT 'weapon_throwable_bolas_hawkmoth', 'weapon_thrown_bolas_hawkmoth'
    UNION ALL SELECT 'weapon_throwable_bolas_ironspiked', 'weapon_thrown_bolas_ironspiked'
    UNION ALL SELECT 'weapon_throwable_bolas_intertwined', 'weapon_thrown_bolas_intertwined'
    UNION ALL SELECT 'weapon_throwable_bolas', 'weapon_thrown_bolas'
    UNION ALL SELECT 'weapon_throwable_dynamite', 'weapon_thrown_dynamite'
    UNION ALL SELECT 'weapon_throwable_molotov', 'weapon_thrown_molotov'
    UNION ALL SELECT 'weapon_throwable_poisonbottle', 'weapon_thrown_poisonbottle'
) AS renames ON legacy.`name` = renames.old_name
LEFT JOIN `items` AS canonical ON canonical.`name` = renames.new_name
SET legacy.`name` = renames.new_name
WHERE canonical.`name` IS NULL;

-- ============================================================================
-- Source: install_items.sql
-- ============================================================================
-- Fishing Rod: equipment only; fishing gameplay belongs to an add-on.
INSERT INTO `items`
(`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_fishingrod', 'Fishing Rod', 'Reusable fishing equipment.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_fishingrod');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_fishingrod';

-- Metal Detector: equipment only; detecting gameplay belongs to an add-on.
INSERT INTO `items`
(`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_kit_metal_detector', 'Metal Detector', 'Reusable metal detecting equipment.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_kit_metal_detector');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_kit_metal_detector';

-- Improved Binoculars: unique ammunition-free utility equipment.
INSERT INTO `items`
(`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_kit_binoculars_improved', 'Improved Binoculars', 'Reusable improved binoculars.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_kit_binoculars_improved');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_kit_binoculars_improved';

-- Hammer: unique ammunition-free melee equipment.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_melee_hammer', 'Hammer', 'A sturdy melee hammer.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_melee_hammer');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_melee_hammer';

-- Advanced Camera: equipment-only; photography belongs to an optional add-on.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_kit_camera_advanced', 'Advanced Camera', 'A reusable advanced camera.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_kit_camera_advanced');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_kit_camera_advanced';

-- Standard Camera: unique utility equipment; no ammunition.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_kit_camera', 'Camera', 'A reusable standard camera.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_kit_camera');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_kit_camera';

-- Standard Binoculars: unique utility equipment, no ammunition.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_kit_binoculars', 'Binoculars', 'Reusable standard binoculars.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_kit_binoculars');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_kit_binoculars';

-- Davy Lantern candidate; preserves Standard Lantern ownership.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_melee_davy_lantern', 'Davy Lantern', 'A reusable handheld Davy lantern.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_melee_davy_lantern');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_melee_davy_lantern';

-- Reinforced Lasso: unique equipment; no ammunition.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_lasso_reinforced', 'Reinforced Lasso', 'A reusable reinforced lasso.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_lasso_reinforced');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_lasso_reinforced';

-- Standard Lasso: unique equipment, no ammunition item.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_lasso', 'Lasso', 'A standard reusable lasso.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_lasso');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_lasso';

-- Existing installations: run rename_weapon_item_names.sql before this seed.

-- Toxic Moonshine candidate; preserves existing item IDs and quantities.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_poisonbottle', 'Toxic Moonshine', 'Unique Toxic Moonshine carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_poisonbottle');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_poisonbottle';
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_poisonbottle', 'Toxic Moonshine - Regular', 'Toxic Moonshine ammunition.', 100, 100, 0.1, 1, 2, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_poisonbottle');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_poisonbottle';

-- Fire Bottle candidate; preserves existing item IDs and quantities.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_molotov', 'Fire Bottle', 'Unique Fire Bottle carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_molotov');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_molotov';
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_molotov', 'Fire Bottle - Regular', 'Fire Bottle ammunition.', 100, 100, 0.1, 1, 2, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_molotov');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_molotov';

-- Dynamite candidate; preserves existing item IDs and quantities.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_dynamite', 'Dynamite', 'Unique Dynamite carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_dynamite');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_dynamite';
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_dynamite', 'Dynamite - Regular', 'Dynamite ammunition.', 100, 100, 0.1, 1, 2, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_dynamite');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_dynamite';

-- Brookstone Bolas candidate; preserves existing item IDs and quantities.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_bolas_intertwined', 'Brookstone Bolas', 'Unique Bolas carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_bolas_intertwined');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_bolas_intertwined';
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_bolas_intertwined', 'Bolas - Brookstone', 'Brookstone Bolas ammunition.', 100, 100, 0.1, 1, 2, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_bolas_intertwined');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_bolas_intertwined';

-- Gravesend Bolas candidate; preserves existing item IDs and quantities.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_bolas_ironspiked', 'Gravesend Bolas', 'Unique Bolas carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_bolas_ironspiked');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_bolas_ironspiked';
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_bolas_ironspiked', 'Bolas - Gravesend', 'Gravesend Bolas ammunition.', 100, 100, 0.1, 1, 2, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_bolas_ironspiked');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_bolas_ironspiked';

-- Hawkmoth Bolas candidate. Preserves existing item IDs and quantities.
INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_bolas_hawkmoth', 'Hawkmoth Bolas', 'Unique Bolas carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_bolas_hawkmoth');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_bolas_hawkmoth';
INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_bolas_hawkmoth', 'Bolas - Hawkmoth', 'Hawkmoth Bolas ammunition.', 100, 100, 0.1, 1, 3, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_bolas_hawkmoth');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_bolas_hawkmoth';

-- Standard Bolas candidate. Preserves existing item IDs and quantities.
INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_bolas', 'Bolas', 'Unique Bolas carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_bolas');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_bolas';
INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_bolas_regular', 'Bolas - Regular', 'Regular Bolas ammunition.', 100, 100, 0.1, 1, 3, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_bolas_regular');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_bolas_regular';

-- Standard firearm catalog. Match weapon definitions; preserve existing numeric IDs.
INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_pistol_volcanic', 'Volcanic Pistol', 'Volcanic Pistol.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_pistol_volcanic');

UPDATE `items` SET `display_name` = 'Volcanic Pistol', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_pistol_volcanic';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_pistol_m1899', 'M1899 Pistol', 'M1899 Pistol.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_pistol_m1899');

UPDATE `items` SET `display_name` = 'M1899 Pistol', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_pistol_m1899';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_pistol_semiauto', 'Semi-Automatic Pistol', 'Semi-Automatic Pistol.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_pistol_semiauto');

UPDATE `items` SET `display_name` = 'Semi-Automatic Pistol', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_pistol_semiauto';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_pistol_mauser', 'Mauser Pistol', 'Mauser Pistol.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_pistol_mauser');

UPDATE `items` SET `display_name` = 'Mauser Pistol', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_pistol_mauser';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_revolver_doubleaction', 'Double-Action Revolver', 'Double-Action Revolver.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_revolver_doubleaction');

UPDATE `items` SET `display_name` = 'Double-Action Revolver', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_revolver_doubleaction';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_revolver_lemat', 'LeMat Revolver', 'LeMat Revolver.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_revolver_lemat');

UPDATE `items` SET `display_name` = 'LeMat Revolver', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_revolver_lemat';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_revolver_navy', 'Navy Revolver', 'Navy Revolver.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_revolver_navy');

UPDATE `items` SET `display_name` = 'Navy Revolver', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_revolver_navy';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_repeater_carbine', 'Carbine Repeater', 'Carbine Repeater.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_repeater_carbine');

UPDATE `items` SET `display_name` = 'Carbine Repeater', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_repeater_carbine';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_repeater_lancaster', 'Lancaster Repeater', 'Lancaster Repeater.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_repeater_lancaster');

UPDATE `items` SET `display_name` = 'Lancaster Repeater', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_repeater_lancaster';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_repeater_henry', 'Litchfield Repeater', 'Litchfield Repeater.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_repeater_henry');

UPDATE `items` SET `display_name` = 'Litchfield Repeater', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_repeater_henry';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_repeater_evans', 'Evans Repeater', 'Evans Repeater.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_repeater_evans');

UPDATE `items` SET `display_name` = 'Evans Repeater', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_repeater_evans';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_rifle_springfield', 'Springfield Rifle', 'Springfield Rifle.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_rifle_springfield');

UPDATE `items` SET `display_name` = 'Springfield Rifle', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_rifle_springfield';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_rifle_boltaction', 'Bolt Action Rifle', 'Bolt Action Rifle.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_rifle_boltaction');

UPDATE `items` SET `display_name` = 'Bolt Action Rifle', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_rifle_boltaction';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_rifle_varmint', 'Varmint Rifle', 'Varmint Rifle.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_rifle_varmint');

UPDATE `items` SET `display_name` = 'Varmint Rifle', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_rifle_varmint';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_sniperrifle_rollingblock', 'Rolling Block Rifle', 'Rolling Block Rifle.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_sniperrifle_rollingblock');

UPDATE `items` SET `display_name` = 'Rolling Block Rifle', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_sniperrifle_rollingblock';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_sniperrifle_carcano', 'Carcano Rifle', 'Carcano Rifle.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_sniperrifle_carcano');

UPDATE `items` SET `display_name` = 'Carcano Rifle', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_sniperrifle_carcano';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_rifle_elephant', 'Elephant Rifle', 'Elephant Rifle.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_rifle_elephant');

UPDATE `items` SET `display_name` = 'Elephant Rifle', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_rifle_elephant';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_shotgun_doublebarrel', 'Double-Barreled Shotgun', 'Double-Barreled Shotgun.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_shotgun_doublebarrel');

UPDATE `items` SET `display_name` = 'Double-Barreled Shotgun', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_shotgun_doublebarrel';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_shotgun_sawedoff', 'Sawed-Off Shotgun', 'Sawed-Off Shotgun.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_shotgun_sawedoff');

UPDATE `items` SET `display_name` = 'Sawed-Off Shotgun', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_shotgun_sawedoff';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_shotgun_pump', 'Pump-Action Shotgun', 'Pump-Action Shotgun.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_shotgun_pump');

UPDATE `items` SET `display_name` = 'Pump-Action Shotgun', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_shotgun_pump';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_shotgun_semiauto', 'Semi-Auto Shotgun', 'Semi-Auto Shotgun.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_shotgun_semiauto');

UPDATE `items` SET `display_name` = 'Semi-Auto Shotgun', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_shotgun_semiauto';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_shotgun_repeating', 'Repeating Shotgun', 'Repeating Shotgun.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_shotgun_repeating');

UPDATE `items` SET `display_name` = 'Repeating Shotgun', `usable` = 1, `type` = 'item_weapon',
    `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_shotgun_repeating';

-- Installation seed for the current Cattleman vertical slice.
-- Run after feather-inventory has applied its instance_mode migration.
-- Uses WHERE NOT EXISTS because older Feather schemas may not have a unique
-- index on items.name; ON DUPLICATE KEY UPDATE would create duplicate names.

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_revolver_cattleman', 'Cattleman Revolver', 'A standard single-action revolver.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_revolver_cattleman');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_revolver_schofield', 'Schofield Revolver', 'A sturdy top-break revolver.', 20, 1, 2, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_revolver_schofield');

-- Alpha cutover to the shared ammo_<family>_<variant> naming convention.
UPDATE `items` AS legacy
LEFT JOIN `items` AS current ON current.`name` = 'ammo_revolver_regular'
SET legacy.`name` = 'ammo_revolver_regular'
WHERE legacy.`name` = 'revolver_standard'
  AND current.`id` IS NULL;

DROP TEMPORARY TABLE IF EXISTS `feather_weapon_ammunition_seed`;
CREATE TEMPORARY TABLE `feather_weapon_ammunition_seed` (
    `name` VARCHAR(64) NOT NULL PRIMARY KEY,
    `display_name` VARCHAR(128) NOT NULL,
    `description` VARCHAR(255) NOT NULL
);

INSERT INTO `feather_weapon_ammunition_seed` (`name`, `display_name`, `description`) VALUES
    ('ammo_rifle_elephant', 'Rifle Cartridges - Nitro Express', 'Nitro Express cartridges for the Elephant Rifle.'),
    ('ammo_pistol_regular', 'Pistol Cartridges - Regular', 'Regular cartridges for pistols.'),
    ('ammo_pistol_express', 'Pistol Cartridges - Express', 'Express cartridges for pistols.'),
    ('ammo_pistol_high_velocity', 'Pistol Cartridges - High Velocity', 'High velocity cartridges for pistols.'),
    ('ammo_pistol_split_point', 'Pistol Cartridges - Split Point', 'Split point cartridges for pistols.'),
    ('ammo_pistol_explosive', 'Pistol Cartridges - Explosive', 'Explosive cartridges for pistols.'),
    ('ammo_revolver_regular', 'Revolver Cartridges - Regular', 'Regular cartridges for revolvers.'),
    ('ammo_revolver_express', 'Revolver Cartridges - Express', 'Express cartridges for revolvers.'),
    ('ammo_revolver_high_velocity', 'Revolver Cartridges - High Velocity', 'High velocity cartridges for revolvers.'),
    ('ammo_revolver_split_point', 'Revolver Cartridges - Split Point', 'Split point cartridges for revolvers.'),
    ('ammo_revolver_explosive', 'Revolver Cartridges - Explosive', 'Explosive cartridges for revolvers.'),
    ('ammo_repeater_regular', 'Repeater Cartridges - Regular', 'Regular cartridges for repeaters.'),
    ('ammo_repeater_express', 'Repeater Cartridges - Express', 'Express cartridges for repeaters.'),
    ('ammo_repeater_high_velocity', 'Repeater Cartridges - High Velocity', 'High velocity cartridges for repeaters.'),
    ('ammo_repeater_split_point', 'Repeater Cartridges - Split Point', 'Split point cartridges for repeaters.'),
    ('ammo_repeater_explosive', 'Repeater Cartridges - Explosive', 'Explosive cartridges for repeaters.'),
    ('ammo_rifle_regular', 'Rifle Cartridges - Regular', 'Regular cartridges for rifles.'),
    ('ammo_rifle_express', 'Rifle Cartridges - Express', 'Express cartridges for rifles.'),
    ('ammo_rifle_high_velocity', 'Rifle Cartridges - High Velocity', 'High velocity cartridges for rifles.'),
    ('ammo_rifle_split_point', 'Rifle Cartridges - Split Point', 'Split point cartridges for rifles.'),
    ('ammo_rifle_explosive', 'Rifle Cartridges - Explosive', 'Explosive cartridges for rifles.'),
    ('ammo_shotgun_regular', 'Shotgun - Regular', 'Regular shells for shotguns.'),
    ('ammo_shotgun_slug', 'Shotgun - Slug', 'Slug shells for shotguns.'),
    ('ammo_shotgun_buckshot_incendiary', 'Shotgun - Incendiary', 'Incendiary buckshot shells for shotguns.'),
    ('ammo_shotgun_slug_explosive', 'Shotgun - Explosive', 'Explosive slug shells for shotguns.'),
    ('ammo_varmint', 'Rifle Cartridges - Varmint', 'Regular .22 caliber cartridges for varmint rifles.'),
    ('ammo_varmint_tranquilizer', 'Rifle Cartridges - Tranquilizer', 'Tranquilizer cartridges for varmint rifles.');

UPDATE `items` AS item
INNER JOIN `feather_weapon_ammunition_seed` AS seed ON seed.`name` = item.`name`
SET item.`display_name` = seed.`display_name`,
    item.`description` = seed.`description`,
    item.`max_quantity` = 200,
    item.`max_stack_size` = 50,
    item.`weight` = 0,
    item.`usable` = 1,
    item.`category_id` = 2,
    item.`type` = 'item_ammo',
    item.`instance_mode` = 'stack';

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT seed.`name`, seed.`display_name`, seed.`description`, 200, 50, 0, 1, 2, 'item_ammo', 'stack'
FROM `feather_weapon_ammunition_seed` AS seed
WHERE NOT EXISTS (SELECT 1 FROM `items` AS item WHERE item.`name` = seed.`name`);

DROP TEMPORARY TABLE `feather_weapon_ammunition_seed`;

-- Preserve existing repair consumable stacks during the alpha item-ID cutover.
UPDATE `items` AS legacy
LEFT JOIN `items` AS current ON current.`name` = 'gun_oil'
SET legacy.`name` = 'gun_oil'
WHERE legacy.`name` = 'weapon_repair_kit'
  AND current.`id` IS NULL;

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'gun_oil', 'Gun Oil', 'Gun oil used to clean and restore weapon condition.', 20, 10, 1, 1, 8, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'gun_oil');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'cattleman_long_barrel', 'Cattleman Long Barrel', 'A long barrel made for the Cattleman Revolver.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'cattleman_long_barrel');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'cattleman_wide_sight', 'Cattleman Wide Sight', 'A wide sight made for the Cattleman Revolver.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'cattleman_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'schofield_short_barrel', 'Schofield Short Barrel', 'A short barrel made for the Schofield Revolver.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'schofield_short_barrel');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'schofield_wide_sight', 'Schofield Wide Sight', 'A wide sight made for the Schofield Revolver.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'schofield_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'lemat_long_barrel', 'LeMat Long Barrel', 'A long barrel made for the LeMat Revolver.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'lemat_long_barrel');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'lemat_wide_sight', 'LeMat Wide Sight', 'A wide sight made for the LeMat Revolver.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'lemat_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'navy_long_barrel', 'Navy Long Barrel', 'A long barrel made for the Navy Revolver.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'navy_long_barrel');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'navy_wide_sight', 'Navy Wide Sight', 'A wide sight made for the Navy Revolver.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'navy_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'doubleaction_long_barrel', 'Double-Action Long Barrel', 'A long barrel made for the Double-Action Revolver.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'doubleaction_long_barrel');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'doubleaction_wide_sight', 'Double-Action Wide Sight', 'A wide sight made for the Double-Action Revolver.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'doubleaction_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'm1899_long_barrel', 'M1899 Long Barrel', 'A long barrel made for the M1899 Pistol.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'm1899_long_barrel');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'm1899_wide_sight', 'M1899 Wide Sight', 'A wide sight made for the M1899 Pistol.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'm1899_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'volcanic_long_barrel', 'Volcanic Long Barrel', 'A long barrel made for the Volcanic Pistol.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'volcanic_long_barrel');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'volcanic_wide_sight', 'Volcanic Wide Sight', 'A wide sight made for the Volcanic Pistol.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'volcanic_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'semiauto_long_barrel', 'Semi-Automatic Long Barrel', 'A long barrel made for the Semi-Automatic Pistol.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'semiauto_long_barrel');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'semiauto_wide_sight', 'Semi-Automatic Wide Sight', 'A wide sight made for the Semi-Automatic Pistol.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'semiauto_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'mauser_long_barrel', 'Mauser Long Barrel', 'A long barrel made for the Mauser Pistol.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'mauser_long_barrel');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'mauser_wide_sight', 'Mauser Wide Sight', 'A wide sight made for the Mauser Pistol.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'mauser_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'carbine_wide_sight', 'Carbine Wide Sight', 'A wide sight made for the Carbine Repeater.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'carbine_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'lancaster_wide_sight', 'Lancaster Wide Sight', 'A wide sight made for the Lancaster Repeater.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'lancaster_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'litchfield_wide_sight', 'Litchfield Wide Sight', 'A wide sight made for the Litchfield Repeater.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'litchfield_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'evans_wide_sight', 'Evans Wide Sight', 'A wide sight made for the Evans Repeater.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'evans_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'springfield_wide_sight', 'Springfield Wide Sight', 'A wide sight made for the Springfield Rifle.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'springfield_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'boltaction_wide_sight', 'Bolt Action Wide Sight', 'A wide sight made for the Bolt Action Rifle.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'boltaction_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'varmint_wide_sight', 'Varmint Wide Sight', 'A wide sight made for the Varmint Rifle.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'varmint_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'elephant_long_barrel', 'Elephant Long Barrel', 'A long barrel made for the Elephant Rifle.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'elephant_long_barrel');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'elephant_wide_sight', 'Elephant Wide Sight', 'A wide sight made for the Elephant Rifle.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'elephant_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'rollingblock_wide_sight', 'Rolling Block Wide Sight', 'A wide sight made for the Rolling Block Rifle.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'rollingblock_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'rollingblock_scope_03', 'Rolling Block Scope (Type 3)', 'A replacement scope made for the Rolling Block Rifle.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'rollingblock_scope_03');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'rollingblock_scope_04', 'Rolling Block Scope (Type 4)', 'A replacement scope made for the Rolling Block Rifle.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'rollingblock_scope_04');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'carcano_wide_sight', 'Carcano Wide Sight', 'A wide sight made for the Carcano Rifle.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'carcano_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'repeating_shotgun_long_barrel', 'Repeating Shotgun Long Barrel', 'A long barrel made for the Repeating Shotgun.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'repeating_shotgun_long_barrel');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'repeating_shotgun_wide_sight', 'Repeating Shotgun Wide Sight', 'A wide sight made for the Repeating Shotgun.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'repeating_shotgun_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'pump_shotgun_long_barrel', 'Pump-Action Long Barrel', 'A long barrel made for the Pump-Action Shotgun.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'pump_shotgun_long_barrel');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'pump_shotgun_wide_sight', 'Pump-Action Wide Sight', 'A wide sight made for the Pump-Action Shotgun.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'pump_shotgun_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'semiauto_shotgun_long_barrel', 'Semi-Auto Shotgun Long Barrel', 'A long barrel made for the Semi-Auto Shotgun.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'semiauto_shotgun_long_barrel');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'semiauto_shotgun_wide_sight', 'Semi-Auto Shotgun Wide Sight', 'A wide sight made for the Semi-Auto Shotgun.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'semiauto_shotgun_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'doublebarrel_long_barrel', 'Double-Barreled Long Barrel', 'A long barrel made for the Double-Barreled Shotgun.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'doublebarrel_long_barrel');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'doublebarrel_wide_sight', 'Double-Barreled Wide Sight', 'A wide sight made for the Double-Barreled Shotgun.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'doublebarrel_wide_sight');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'sawedoff_wide_sight', 'Sawed-Off Wide Sight', 'A wide sight made for the Sawed-Off Shotgun.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'sawedoff_wide_sight');

UPDATE `items`
SET `display_name` = 'Cattleman Revolver',
    `description` = 'A standard single-action revolver.',
    `max_quantity` = 20, `max_stack_size` = 1, `weight` = 2,
    `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique'
WHERE `name` = 'weapon_revolver_cattleman';

UPDATE `items`
SET `display_name` = 'Schofield Revolver',
    `description` = 'A sturdy top-break revolver.',
    `max_quantity` = 20, `max_stack_size` = 1, `weight` = 2,
    `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique'
WHERE `name` = 'weapon_revolver_schofield';

UPDATE `items`
SET `display_name` = 'Gun Oil',
    `description` = 'Gun oil used to clean and restore weapon condition.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 1, `category_id` = 8, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'gun_oil';

UPDATE `items`
SET `display_name` = 'Cattleman Long Barrel',
    `description` = 'A long barrel made for the Cattleman Revolver.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'cattleman_long_barrel';

UPDATE `items`
SET `display_name` = 'Cattleman Wide Sight',
    `description` = 'A wide sight made for the Cattleman Revolver.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'cattleman_wide_sight';

UPDATE `items`
SET `display_name` = 'Schofield Short Barrel',
    `description` = 'A short barrel made for the Schofield Revolver.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'schofield_short_barrel';

UPDATE `items`
SET `display_name` = 'Schofield Wide Sight',
    `description` = 'A wide sight made for the Schofield Revolver.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'schofield_wide_sight';

UPDATE `items`
SET `display_name` = 'LeMat Long Barrel',
    `description` = 'A long barrel made for the LeMat Revolver.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'lemat_long_barrel';

UPDATE `items`
SET `display_name` = 'LeMat Wide Sight',
    `description` = 'A wide sight made for the LeMat Revolver.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'lemat_wide_sight';

UPDATE `items`
SET `display_name` = 'Navy Long Barrel',
    `description` = 'A long barrel made for the Navy Revolver.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'navy_long_barrel';

UPDATE `items`
SET `display_name` = 'Navy Wide Sight',
    `description` = 'A wide sight made for the Navy Revolver.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'navy_wide_sight';

UPDATE `items`
SET `display_name` = 'Double-Action Long Barrel',
    `description` = 'A long barrel made for the Double-Action Revolver.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'doubleaction_long_barrel';

UPDATE `items`
SET `display_name` = 'Double-Action Wide Sight',
    `description` = 'A wide sight made for the Double-Action Revolver.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'doubleaction_wide_sight';

UPDATE `items`
SET `display_name` = 'M1899 Long Barrel',
    `description` = 'A long barrel made for the M1899 Pistol.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'm1899_long_barrel';

UPDATE `items`
SET `display_name` = 'M1899 Wide Sight',
    `description` = 'A wide sight made for the M1899 Pistol.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'm1899_wide_sight';

UPDATE `items`
SET `display_name` = 'Volcanic Long Barrel',
    `description` = 'A long barrel made for the Volcanic Pistol.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'volcanic_long_barrel';

UPDATE `items`
SET `display_name` = 'Volcanic Wide Sight',
    `description` = 'A wide sight made for the Volcanic Pistol.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'volcanic_wide_sight';

UPDATE `items`
SET `display_name` = 'Semi-Automatic Long Barrel',
    `description` = 'A long barrel made for the Semi-Automatic Pistol.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'semiauto_long_barrel';

UPDATE `items`
SET `display_name` = 'Semi-Automatic Wide Sight',
    `description` = 'A wide sight made for the Semi-Automatic Pistol.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'semiauto_wide_sight';

UPDATE `items`
SET `display_name` = 'Mauser Long Barrel',
    `description` = 'A long barrel made for the Mauser Pistol.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'mauser_long_barrel';

UPDATE `items`
SET `display_name` = 'Mauser Wide Sight',
    `description` = 'A wide sight made for the Mauser Pistol.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'mauser_wide_sight';

UPDATE `items`
SET `display_name` = 'Carbine Wide Sight',
    `description` = 'A wide sight made for the Carbine Repeater.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'carbine_wide_sight';

UPDATE `items`
SET `display_name` = 'Lancaster Wide Sight',
    `description` = 'A wide sight made for the Lancaster Repeater.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'lancaster_wide_sight';

UPDATE `items`
SET `display_name` = 'Litchfield Wide Sight',
    `description` = 'A wide sight made for the Litchfield Repeater.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'litchfield_wide_sight';

UPDATE `items`
SET `display_name` = 'Evans Wide Sight',
    `description` = 'A wide sight made for the Evans Repeater.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'evans_wide_sight';

UPDATE `items`
SET `display_name` = 'Springfield Wide Sight',
    `description` = 'A wide sight made for the Springfield Rifle.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'springfield_wide_sight';

UPDATE `items`
SET `display_name` = 'Bolt Action Wide Sight',
    `description` = 'A wide sight made for the Bolt Action Rifle.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'boltaction_wide_sight';

UPDATE `items`
SET `display_name` = 'Varmint Wide Sight',
    `description` = 'A wide sight made for the Varmint Rifle.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'varmint_wide_sight';

UPDATE `items`
SET `display_name` = 'Elephant Long Barrel',
    `description` = 'A long barrel made for the Elephant Rifle.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'elephant_long_barrel';

UPDATE `items`
SET `display_name` = 'Elephant Wide Sight',
    `description` = 'A wide sight made for the Elephant Rifle.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'elephant_wide_sight';

UPDATE `items`
SET `display_name` = 'Rolling Block Wide Sight',
    `description` = 'A wide sight made for the Rolling Block Rifle.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'rollingblock_wide_sight';

UPDATE `items`
SET `display_name` = 'Rolling Block Scope (Type 3)',
    `description` = 'A replacement scope made for the Rolling Block Rifle.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'rollingblock_scope_03';

UPDATE `items`
SET `display_name` = 'Rolling Block Scope (Type 4)',
    `description` = 'A replacement scope made for the Rolling Block Rifle.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'rollingblock_scope_04';

UPDATE `items`
SET `display_name` = 'Carcano Wide Sight',
    `description` = 'A wide sight made for the Carcano Rifle.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'carcano_wide_sight';

UPDATE `items`
SET `display_name` = 'Repeating Shotgun Long Barrel',
    `description` = 'A long barrel made for the Repeating Shotgun.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'repeating_shotgun_long_barrel';

UPDATE `items`
SET `display_name` = 'Repeating Shotgun Wide Sight',
    `description` = 'A wide sight made for the Repeating Shotgun.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'repeating_shotgun_wide_sight';

UPDATE `items`
SET `display_name` = 'Pump-Action Long Barrel',
    `description` = 'A long barrel made for the Pump-Action Shotgun.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'pump_shotgun_long_barrel';

UPDATE `items`
SET `display_name` = 'Pump-Action Wide Sight',
    `description` = 'A wide sight made for the Pump-Action Shotgun.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'pump_shotgun_wide_sight';

UPDATE `items`
SET `display_name` = 'Semi-Auto Shotgun Long Barrel',
    `description` = 'A long barrel made for the Semi-Auto Shotgun.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'semiauto_shotgun_long_barrel';

UPDATE `items`
SET `display_name` = 'Semi-Auto Shotgun Wide Sight',
    `description` = 'A wide sight made for the Semi-Auto Shotgun.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'semiauto_shotgun_wide_sight';

UPDATE `items`
SET `display_name` = 'Double-Barreled Long Barrel',
    `description` = 'A long barrel made for the Double-Barreled Shotgun.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'doublebarrel_long_barrel';

UPDATE `items`
SET `display_name` = 'Double-Barreled Wide Sight',
    `description` = 'A wide sight made for the Double-Barreled Shotgun.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'doublebarrel_wide_sight';

UPDATE `items`
SET `display_name` = 'Sawed-Off Wide Sight',
    `description` = 'A wide sight made for the Sawed-Off Shotgun.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'sawedoff_wide_sight';

-- ============================================================================
-- Source: add_advanced_camera.sql
-- ============================================================================
-- Advanced Camera: equipment-only; photography belongs to an optional add-on.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_kit_camera_advanced', 'Advanced Camera', 'A reusable advanced camera.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_kit_camera_advanced');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_kit_camera_advanced';

-- ============================================================================
-- Source: add_binoculars.sql
-- ============================================================================
-- Standard Binoculars: unique utility equipment, no ammunition.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_kit_binoculars', 'Binoculars', 'Reusable standard binoculars.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_kit_binoculars');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_kit_binoculars';

-- ============================================================================
-- Source: add_bolas.sql
-- ============================================================================
-- Standard Bolas candidate. Preserves existing item IDs and quantities.
INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_bolas', 'Bolas', 'Unique Bolas carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_bolas');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_bolas';
INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_bolas_regular', 'Bolas - Regular', 'Regular Bolas ammunition.', 100, 100, 0.1, 1, 3, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_bolas_regular');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_bolas_regular';

-- ============================================================================
-- Source: add_brookstone_bolas.sql
-- ============================================================================
-- Brookstone Bolas candidate; preserves existing item IDs and quantities.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_bolas_intertwined', 'Brookstone Bolas', 'Unique Bolas carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_bolas_intertwined');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_bolas_intertwined';
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_bolas_intertwined', 'Bolas - Brookstone', 'Brookstone Bolas ammunition.', 100, 100, 0.1, 1, 2, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_bolas_intertwined');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_bolas_intertwined';

-- ============================================================================
-- Source: add_camera.sql
-- ============================================================================
-- Standard Camera: unique utility equipment; no ammunition.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_kit_camera', 'Camera', 'A reusable standard camera.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_kit_camera');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_kit_camera';

-- ============================================================================
-- Source: add_davy_lantern.sql
-- ============================================================================
-- Davy Lantern candidate; preserves Standard Lantern ownership.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_melee_davy_lantern', 'Davy Lantern', 'A reusable handheld Davy lantern.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_melee_davy_lantern');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_melee_davy_lantern';

-- ============================================================================
-- Source: add_dynamite.sql
-- ============================================================================
-- Dynamite candidate; preserves existing item IDs and quantities.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_dynamite', 'Dynamite', 'Unique Dynamite carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_dynamite');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_dynamite';
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_dynamite', 'Dynamite - Regular', 'Dynamite ammunition.', 100, 100, 0.1, 1, 2, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_dynamite');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_dynamite';

-- ============================================================================
-- Source: add_electric_lantern.sql
-- ============================================================================
-- Retired failed Electric Lantern candidate; historical migration is now a no-op.
-- Existing item definitions and owned instances are preserved.
-- Use retire_electric_lantern.sql to disable the retired usable item.

-- ============================================================================
-- Source: add_fire_bottle.sql
-- ============================================================================
-- Fire Bottle candidate; preserves existing item IDs and quantities.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_molotov', 'Fire Bottle', 'Unique Fire Bottle carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_molotov');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_molotov';
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_molotov', 'Fire Bottle - Regular', 'Fire Bottle ammunition.', 100, 100, 0.1, 1, 2, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_molotov');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_molotov';

-- ============================================================================
-- Source: add_fishing_rod.sql
-- ============================================================================
-- Fishing Rod: equipment only; fishing gameplay belongs to an add-on.
INSERT INTO `items`
(`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_fishingrod', 'Fishing Rod', 'Reusable fishing equipment.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_fishingrod');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_fishingrod';

-- ============================================================================
-- Source: add_hammer.sql
-- ============================================================================
-- Hammer: unique ammunition-free melee equipment.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_melee_hammer', 'Hammer', 'A sturdy melee hammer.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_melee_hammer');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_melee_hammer';

-- ============================================================================
-- Source: add_hawkmoth_bolas.sql
-- ============================================================================
-- Hawkmoth Bolas candidate. Preserves existing item IDs and quantities.
INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_bolas_hawkmoth', 'Hawkmoth Bolas', 'Unique Bolas carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_bolas_hawkmoth');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_bolas_hawkmoth';
INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_bolas_hawkmoth', 'Bolas - Hawkmoth', 'Hawkmoth Bolas ammunition.', 100, 100, 0.1, 1, 3, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_bolas_hawkmoth');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_bolas_hawkmoth';

-- ============================================================================
-- Source: add_improved_binoculars.sql
-- ============================================================================
-- Improved Binoculars: unique ammunition-free utility equipment.
INSERT INTO `items`
(`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_kit_binoculars_improved', 'Improved Binoculars', 'Reusable improved binoculars.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_kit_binoculars_improved');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_kit_binoculars_improved';

-- ============================================================================
-- Source: add_ironspiked_bolas.sql
-- ============================================================================
-- Gravesend Bolas candidate; preserves existing item IDs and quantities.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_bolas_ironspiked', 'Gravesend Bolas', 'Unique Bolas carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_bolas_ironspiked');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_bolas_ironspiked';
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_bolas_ironspiked', 'Bolas - Gravesend', 'Gravesend Bolas ammunition.', 100, 100, 0.1, 1, 2, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_bolas_ironspiked');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_bolas_ironspiked';

-- ============================================================================
-- Source: add_lantern.sql
-- ============================================================================
-- Retired failed candidate. This historical migration no longer creates or enables items.
-- Existing carrier rows and quantities are deliberately preserved.
-- For the supported Lantern, use add_davy_lantern.sql.

-- ============================================================================
-- Source: add_lasso.sql
-- ============================================================================
-- Standard Lasso: unique equipment, no ammunition item.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_lasso', 'Lasso', 'A standard reusable lasso.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_lasso');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_lasso';

-- ============================================================================
-- Source: add_metal_detector.sql
-- ============================================================================
-- Metal Detector: equipment only; detecting gameplay belongs to an add-on.
INSERT INTO `items`
(`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_kit_metal_detector', 'Metal Detector', 'Reusable metal detecting equipment.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_kit_metal_detector');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_kit_metal_detector';

-- ============================================================================
-- Source: add_poison_bottle.sql
-- ============================================================================
-- Toxic Moonshine candidate; preserves existing item IDs and quantities.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_poisonbottle', 'Toxic Moonshine', 'Unique Toxic Moonshine carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_poisonbottle');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_poisonbottle';
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_poisonbottle', 'Toxic Moonshine - Regular', 'Toxic Moonshine ammunition.', 100, 100, 0.1, 1, 2, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_poisonbottle');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_poisonbottle';

-- ============================================================================
-- Source: add_reinforced_lasso.sql
-- ============================================================================
-- Reinforced Lasso: unique equipment; no ammunition.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_lasso_reinforced', 'Reinforced Lasso', 'A reusable reinforced lasso.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_lasso_reinforced');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_lasso_reinforced';

-- ============================================================================
-- Source: add_rollingblock_scopes.sql
-- ============================================================================
-- Rolling Block scope attachments (functional, slot `scope`). For existing
-- installs; new installs get them from install_items.sql.
INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'rollingblock_scope_03', 'Rolling Block Scope (Type 3)', 'A replacement scope made for the Rolling Block Rifle.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'rollingblock_scope_03');

INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'rollingblock_scope_04', 'Rolling Block Scope (Type 4)', 'A replacement scope made for the Rolling Block Rifle.', 20, 10, 1, 0, 3, 'item_item', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'rollingblock_scope_04');

UPDATE `items`
SET `display_name` = 'Rolling Block Scope (Type 3)',
    `description` = 'A replacement scope made for the Rolling Block Rifle.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'rollingblock_scope_03';

UPDATE `items`
SET `display_name` = 'Rolling Block Scope (Type 4)',
    `description` = 'A replacement scope made for the Rolling Block Rifle.',
    `max_quantity` = 20, `max_stack_size` = 10, `weight` = 1,
    `usable` = 0, `type` = 'item_item', `instance_mode` = 'stack'
WHERE `name` = 'rollingblock_scope_04';

-- ============================================================================
-- Source: add_torch.sql
-- ============================================================================
-- Retired Torch candidate. Historical migration is now a no-op.
-- Owned carriers are preserved; use retire_torch.sql to disable their usable definition.

-- ============================================================================
-- Source: retire_electric_lantern.sql
-- ============================================================================
-- Disable retired equipment without deleting or converting Inventory instances.
UPDATE `items` SET `usable` = 0 WHERE `name` = 'weapon_utility_lantern_electric';

-- ============================================================================
-- Source: retire_standard_lantern.sql
-- ============================================================================
-- Disable the retired item definition without deleting or converting owned instances.
UPDATE `items` SET `usable` = 0 WHERE `name` = 'weapon_utility_lantern';
-- Verify supported Lantern remains present; no ownership writes.
SELECT `name`, `display_name`, `usable` FROM `items`
WHERE `name` IN ('weapon_utility_lantern', 'weapon_melee_davy_lantern');

-- ============================================================================
-- Source: retire_torch.sql
-- ============================================================================
-- Disable retired equipment without deleting or converting owned instances.
UPDATE `items` SET `usable` = 0 WHERE `name` = 'weapon_utility_torch';
