# Rolling Block scope live gate

Candidates: `rollingblock_scope_03` (`COMPONENT_RIFLE_SCOPE03`) and
`rollingblock_scope_04` (`COMPONENT_RIFLE_SCOPE04`) in the new functional
`scope` slot of `rifle_rollingblock`. The rifle ships with a native scope
(shown in the modification menu as "Standard Scope"); an installed candidate
replaces it. Scopes change aiming, so they are functional attachments with
items, never cosmetic choices.
Expected catalog: 45 weapons, 43 ammunition, 40 attachments.

1. Apply sql/add_rollingblock_scopes.sql, reload Inventory item definitions and restart Weapons.
2. Give one of each scope item and equip a Rolling Block at a gunsmith bench (`Config.Attachments.stations`).
3. Open `/weaponmods`, choose the Rolling Block. Confirm the Scope slot shows "Standard Scope" and both candidates.
4. Install Type 3. Confirm the item is consumed, the new scope is visible in hand and holstered, and aiming uses it.
   Note which in-game scope it is (short/medium/long) so the label can be corrected.
5. Install fails while Type 3 is installed (slot occupied). Remove Type 3: exact item return and the native scope is back.
6. Repeat 4-5 for Type 4.
7. With a scope installed: install/remove the Wide Sight; both coexist. Unequip/re-equip, restart Weapons twice and reconnect: the scope persists.
8. Run WeaponMetadataInspect 1, WeaponRuntimeLeaseSmokeTest 1 and WeaponReleaseContractSmokeTest 1 (expects attachment=40).

Not covered: removing the native scope entirely (no "no scope" option). The
component adapter only gives approved components; removal restores the native
look by recreating the weapon. A no-scope variant needs its own design.

Status: candidate, not yet accepted.
