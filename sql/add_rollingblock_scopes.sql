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
