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
