# Gameplay S4 control migration candidate

Status: isolated source candidate. Godot has not parsed or executed these files. The live runtime and live tests are unchanged.

## Promotion map

Promote each candidate file over the matching live path as one atomic slice:

| Candidate | Live destination |
| --- | --- |
| `src/app/player_preferences.gd` | `src/app/player_preferences.gd` |
| `src/app/input_router.gd` | `src/app/input_router.gd` |
| `src/app/control_binding_editor.gd` | `src/app/control_binding_editor.gd` |
| `tests/unit/test_player_preferences.gd` | `tests/unit/test_player_preferences.gd` |
| `tests/unit/test_input_router.gd` | `tests/unit/test_input_router.gd` |
| `tests/unit/test_control_binding_editor.gd` | `tests/unit/test_control_binding_editor.gd` |
| `src/app/character_weave_library.gd` | `src/app/character_weave_library.gd` |
| `tests/unit/test_character_weave_library.gd` | `tests/unit/test_character_weave_library.gd` |

The `.gdignore` keeps this mirror outside Godot discovery until promotion. Existing test registration paths remain valid after promotion.

The copies were forked from these live-file SHA-256 values. Recheck them before promotion and merge if another accepted slice changed a live file meanwhile:

| Live file | Forked SHA-256 |
| --- | --- |
| `src/app/player_preferences.gd` | `B23861DB929E7F0843FC89020A17323D6B0456BA4D0F43B3C06773BD4B4E58A5` |
| `src/app/input_router.gd` | `85DEAA3A9E31A4F9B4A69A67675E926A7848F29B52E71F90ED95F4A0AD46A51D` |
| `src/app/control_binding_editor.gd` | `87F9DF7F07D77F12104C2E0A7744D76B7F48FCE51C957171FE6E468FBB4CE295` |
| `tests/unit/test_player_preferences.gd` | `772873EE378CCF6D7308CE2041F8CA798FC07C54E43AC675E27DDAD4868444B3` |
| `tests/unit/test_input_router.gd` | `1B6AAEA7096B6A9AA0B94F5E462ECCC492101CC4D211E814548AC0E05BBE9DB5` |
| `tests/unit/test_control_binding_editor.gd` | `FC51F67D9E00C4A3D36036200B5DDE38620A8502708A3ED05599B6B70B5B2AA9` |

## Final S4 defaults

- Keyboard revision 2 moves Evade from Q to B. Technique remains V, Active remains E, and Primary remains unbound on keyboard.
- Punch and Kick are unbound on keyboard.
- Mouse revision 1 binds Punch to Left Button and Kick to Right Button. The previous Primary/Active spell aliases on Left/Right Button are removed. Wheel Up remains Jump and Wheel Down remains Slide/Fast-Fall.
- Punch and Kick are unbound on controller. Every existing controller action descriptor and meaning is unchanged.
- InputRouter creates Punch and Kick actions and includes them in paid-action modal/focus quarantine. S4 deliberately assigns no `SimCommand` bit; command authority belongs to S5.

The profile schema stays at 11. The additive `keyboard_defaults_revision: 2` and `mouse_defaults_revision: 1` markers let an older schema-11 document remain readable while preventing repeat migrations.

## Migration policy

Each device migrates independently.

- A complete pre-S4 keyboard default map recognized against its historical schema/revision is replaced by revision 2 defaults. Partial maps, explicit unbinds, and any customized key preserve all prior meanings; newly introduced Punch and Kick keys are seeded to zero.
- A complete pre-S4 mouse default map, the complete schema-4 mouse map, or an omitted pre-mouse map is replaced by revision 1 defaults. Partial/custom mouse maps preserve every prior button owner; Punch and Kick are seeded to zero.
- Controller meaning is never migrated by S4. Punch and Kick are added as explicit `none` descriptors. Existing controller revision behavior remains intact.
- Migration notices are transient dictionaries on `PlayerPreferences` and are not serialized. Each notice has `code`, `severity`, `device`, `action`, `requested_binding`, `conflicting_action`, and `message` fields. Exact-default migration reports the Q-to-B and mouse-melee changes. Customized maps report preservation and identify B/Left/Right conflicts.
- A successful current-revision reload emits no notice, which makes the migration idempotent.

## Reversible persistence

Before replacing any existing valid preferences file, `save_to_file()` installs its exact original bytes at `<preferences path>.pre_s4_controls.bak`. The backup is staged and byte-verified with the same replacement primitive as the primary file. An existing backup is validated and never overwritten. A damaged primary, damaged backup, failed backup install, failed primary install, or failed staged-byte verification leaves the primary unchanged and returns failure. New profiles do not create a backup.

The older `.pre_four_delivery_a.bak` constant remains available for historical tooling, but this S4 migration writes only the dedicated `.pre_s4_controls.bak` recovery copy.

## Root integration hooks

After promotion, root should pass `player_preferences.migration_notices` into `controls_editor.set_migration_notices(...)` immediately after creating the editor. The current `Bootstrap._commit_control_bindings()` already applies all three validated device maps and will remove reused InputMap mouse aliases before gameplay sampling. The station/UI can render `controls_editor.migration_notice_lines()` or its first `status_message` without persisting the notices.

Root should run the registered PlayerPreferences, InputRouter, and ControlBindingEditor suites first, then the serialized full gate. Native UI validation should confirm B/Q/V/E ownership, Left/Right Punch/Kick ownership, readable migration notices, binding conflict swaps, and modal release/repress behavior.

## Per-character weave library

`CharacterWeaveLibrary` is a separate version-1 store at `user://character_weaves_v1.json`. A missing file initializes memory for exactly the thirty canonical character IDs without writing personal storage. Every entry owns twelve unique known ability wires plus their matching stable ability IDs and a `custom` or `starter` mode. Starter entries come directly from `CharacterStarterKit`; custom entries may retain known `catalog_only` abilities, including disabled Burst identities, without replacing them with a playable spell. Queries return deep copies, and merely previewing or switching characters cannot mutate any saved weave.

Existing documents must contain exactly the canonical thirty IDs once each. Unknown or duplicate champions, unknown or duplicate abilities, wire/ID disagreement, non-whole numeric wires, invalid modes, schema drift, extra fields, malformed JSON, and files over 64 KiB fail atomically while preserving prior memory. The store intentionally does not enforce the separate three-active competitive point budget and does not claim that a retained disabled ID can currently be applied by simulation authority.

Saving uses a same-directory staged write with byte verification. Before the first rewrite of an existing valid file, its exact bytes are staged at `<path>.pre_character_weaves_v1.bak`. An existing recovery copy is validated and never overwritten. Invalid disk state or failed backup/primary replacement preserves the primary, recovery copy, and requested in-memory weave.

After promotion, root should register `test_character_weave_library.gd`, load the library once after both canonical catalogs validate, and explicitly request `saved_weave(current_champion_id)`. Character preview and switching are read-only. Root applies a weave through the existing authoritative Spell Loom path and calls `remember(...)` plus `save_to_file(...)` only after that apply succeeds. A failed authoritative apply must leave both library memory and disk unchanged.

## Exclusions

This candidate does not modify bootstrap, `SimCommand`, protocol/snapshots, combat, project input settings, or live files. It does not assign gameplay consequences to Punch or Kick and does not apply saved weaves to `PlayerState`.
