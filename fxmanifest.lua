fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

description 'The official weapon system for Feather framework.'
author 'Feather Framework'
name 'feather-weapons'
version '0.16.0'

shared_scripts {
    'config.lua',
    'config_cosmetics.lua',
    '/shared/constants.lua',
    '/shared/errors.lua',
    '/shared/definitions/ammunition.lua',
    '/shared/definitions/attachments.lua',
    '/shared/definitions/weapons.lua',
    '/shared/validation.lua',
    '/shared/ammunition_pools.lua',
    '/shared/cosmetics/definitions/components.lua',
    '/shared/cosmetics/definitions/shared_components.lua',
    '/shared/cosmetics/definitions/shared_groups.lua',
    '/shared/cosmetics/catalog.lua',
    '/shared/character_ammunition.lua',
    '/shared/character_ammunition_runtime.lua',
    '/shared/character_ammunition_client.lua',
    '/shared/character_ammunition_catalog.lua',
    '/shared/character_ammunition_policy.lua',
    '/shared/character_ammunition_item.lua',
    '/shared/character_ammunition_materialization.lua',
    '/shared/character_ammunition_loadout_lease.lua',
    '/shared/character_ammunition_transport.lua',
    '/shared/character_ammunition_dispatch.lua',
    '/shared/character_ammunition_activation.lua',
    '/shared/character_ammunition_readiness.lua'
}

server_scripts {
    '@feather-mysql/lib/DB.lua',
    '/server/imports.lua',
    '/server/adapters/core.lua',
    '/server/adapters/inventory.lua',
    '/server/adapters/feather_inventory.lua',
    '/server/services/character_ammunition_runtime.lua',
    '/server/adapters/character_ammunition_inventory.lua',
    '/server/services/character_ammunition_dispatch.lua',
    '/server/services/character_ammunition_routes.lua',
    '/server/services/native_equipment_transition.lua',
    '/server/services/definition_registry.lua',
    '/server/services/metadata.lua',
    '/server/services/runtime.lua',
    '/server/services/equip.lua',
    '/server/services/ammo.lua',
    '/server/services/maintenance.lua',
    '/server/services/repair.lua',
    '/server/services/attachments.lua',
    '/server/services/provenance.lua',
    '/server/services/evidence.lua',
    '/server/services/ownership.lua',
    '/server/services/issuance.lua',
    '/server/services/commands.lua',
    '/server/services/reconciliation.lua',
    '/server/services/cosmetics.lua',
    '/server/services/chat_suggestions.lua',
    '/server/services/api.lua',
    '/server/main.lua'
}

client_scripts {
    '/client/imports.lua',
    '/client/character_ammunition_native.lua',
    '/client/character_ammunition_controller.lua',
    '/client/character_ammunition_loadout.lua',
    '/client/character_ammunition_creation_native.lua',
    '/client/character_ammunition_dual_native.lua',
    '/client/character_ammunition_session.lua',
    '/client/character_ammunition_owner.lua',
    '/client/character_ammunition_receiver.lua',
    '/client/character_ammunition_release.lua',
    '/client/character_ammunition_checkpoint.lua',
    '/client/character_ammunition_context.lua',
    '/client/character_ammunition_context_native.lua',
    '/client/character_ammunition_host.lua',
    '/client/character_ammunition_lifecycle.lua',
    '/client/character_ammunition_driver.lua',
    '/client/character_ammunition_client_runtime.lua',
    '/client/character_ammunition_routes.lua',
    '/client/character_ammunition_native_owner.lua',
    '/client/character_ammunition_startup.lua',
    '/client/character_ammunition_actions.lua',
    '/client/native_equipment_actions.lua',
    '/client/guid_weapons.lua',
    '/client/native_maintenance.lua',
    '/client/native_weapon_coordinator.lua',
    '/client/firearm_pools.lua',
    '/client/main.lua',
    '/client/inspect.lua',
    '/client/cosmetics/imports.lua',
    '/translations/cosmetics_en_us.lua',
    '/translations/cosmetics_ro.lua',
    '/client/cosmetics/apply.lua',
    '/client/cosmetics/preview.lua',
    '/client/cosmetics/menu.lua',
    '/client/cosmetics/stations.lua',
    '/client/cosmetics/placement.lua',
      '/client/dev_shot_death.lua',
    '/client/native_probe.lua'
}

files {
    '/data/weapon_holsters.meta'
}

data_file 'WEAPONINFO_FILE_PATCH' '/data/weapon_holsters.meta'

dependencies {
    'feather-mysql',
    'feather-core',
    'feather-character',
    'feather-medical',
    'feather-inventory',
    'feather-menu-v2',
    'feather-toolkit'
}
