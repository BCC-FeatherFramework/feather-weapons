# Scoped native firearms alpha

This PR is an opt-in alpha foundation, not a production-readiness declaration.
`CharacterAmmunitionEnabled`, `CharacterAmmoTransportEnabled` and
`NativeAlphaRuntime` remain false; `NativeAlphaCharacterId` remains nil.
Activation additionally requires DevMode and an explicitly selected enrolled
character. Do not enable it for all players or run it alongside the proof resource.

## Coordinated prerequisites

- Matching Inventory shared-pool transactions, equipment snapshots, guards and UI.
- Character's CFX logout checkpoint receiver fix.
- Medical's persisted client life-state export/change event.
- The character ammunition schema and explicitly validated enrollment. Existing
  legacy item ammo is not silently migrated or credited by startup.

Server-owned session/epoch authority binds creation, restore acknowledgements,
final observations, sealing, owned-copy cleanup and release. Equipment changes
retire the old native owner before Inventory's conditional full-snapshot/revision
transaction and restore a fresh epoch afterward. UI intent is not authority.
Exceptions or uncertain commits do not trigger automatic retry or rollback of an
already committed write. Legacy repair/attachment/gameplay handlers are quarantined
while the native cutover flags are enabled; they are not completed native features.

Inventory's Equipment panel requests server-approved slots for the clicked owned
firearm. Ammunition Load/Unload transfers between loose items and character-owned
carried pools; the game's wheel chooses the active ammunition type. The UI does
not set per-weapon quantities or select native ammo types.

## Acceptance and limits

The scoped Cattleman primary path has live acceptance for load/unload, firing
consumption, login, death/doctor recovery, release/rebuild dry-run, actual console
and player UI equip/unequip, and completed-equipment logout/relogin with further
equipment changes. Latest final durable baseline: item112 revision1, ledger21,
carried0, loose2, receipts22. These are development evidence, not runtime defaults
or a general enrollment policy. Older disposable proof matrix results do not
substitute for broad testing of this normal host.

Remaining work includes broader slots/families/mixed types, in-flight and final-shot
lifecycle races, abnormal resource/disconnect ownership reconciliation, native
repair/attachments and multiplayer/operational hardening. Reused-client startup
has refused a preexisting unowned Cattleman; a clean client restored successfully,
but the prior copy's provenance remains unresolved. Do not bypass ownership checks
or remove all ped weapons to hide that failure.

Development commands, fixed Jane probes and alternative fixture manifests remain
explicit test tools, disabled/gated where applicable; do not replace the normal
manifest with a test manifest in production. New runtime scripts/manifests require
server `refresh` before resource restart. Update matching Inventory and Weapons
together; do not claim the disabled legacy/default path is replaced by this PR.

Regression tests are under `tests/*spec.lua` (Lua 5.4, resource-root working
directory). Most are isolated mocked contracts; the Character integration test
also needs the sibling Character repo. Framework docs remain the authoritative
acceptance record.
