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
