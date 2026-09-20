# Gameplay S4 native UI capture candidate

Status: **CANDIDATE / NOT RUN**. This ignored directory contains no live runtime or test change. It is a bounded capture extension prepared against the S4 control candidate, the starter-preview editor/presenter candidate, and the current S4 root integration. Godot has not parsed or executed it.

The fork assumptions were inspected at these SHA-256 values: staged Bootstrap `5a2a9e5894c4861c7e4eb75fcf9874ce74d329a5624352f3d557e6abfade1277`, starter-preview editor `13f17f64d8f9d0b0c8cc62e3e2416d6795e2bd7f8b0030bb98e43ff4ddec9717`, staged Loom presenter `fd46ac6ded611a8c47164f4b20ce1446ed2d3c16f7c3fcccb7f62c61eccd5b9a`, S4 preferences `d79b0032d455faea0df72144dcf6aba1106947d3852752f98db70686235d2f20`, selected-notice binding editor `1a381e21de31755bc43d6c8068fe94b0d39d0dad4d42eade1e07047c46e62009`, S4 input router `4c8a2d57612778de9d3455131d67904ef3286f8dfcc71cc9d49828b3f316d8ad`, and live inherited draw harness `1b2ca32c16731eec3307e1fc44f35a40e5a1d20c0cba0c11ec80986199b5d6f1`. Root should recheck or merge if any accepted source changes before promotion.

## Captured proof

`capture_gameplay_s4.gd` inherits the production Bootstrap draw through `tests/support/chemistry_coach_harness.gd` and records six 1280 by 720 frames:

- `loom-before-1280x720.png` shows the ordinary Loom over an explicit valid custom twelve-slot weave.
- `loom-preview-1280x720.png` shows the production two-stage preview, including every before/after slot, player-facing slot labels, element colors, and honest Water/Fire versus pending Hex-effect tags.
- `loom-preview-quarantined-1280x720.png` retains that preview after an ordinary Loom navigation input is routed through the production handler and rejected by the preview modal.
- `loom-applied-1280x720.png` shows the ordinary Loom after Enter travels through the production input handler, offline request policy, authoritative twelve-slot apply, matching acknowledgement, and preview completion.
- `controls-defaults-1280x720.png` shows the production Controls Lectern focused on the fresh Punch mouse binding. Assertions cover Evade B, Punch/Kick unbound on keyboard, Punch Left Button, Kick Right Button, and removal of the old Primary/Active mouse aliases.
- `controls-migration-notice-1280x720.png` shows the production Controls Lectern after loading a customized pre-S4 profile with B, Left Button, and Right Button already owned. The selected Punch/Mouse row surfaces its action-specific preservation notice, while the receipt retains the complete transient notice set.

The preview and Apply frames use an actor explicitly placed at the authored Spell Loom station. Preview preparation must leave the world hash and all twelve authoritative slots unchanged. The Apply capture requires a completed offline authority acknowledgement and the exact proposed weave in `PlayerState`; persistence is disabled. Every draw separately proves an unchanged world hash and weave.

The quarantine check also holds both real S4 melee actions across `InputRouter.discard_transient_movement_input()`, proves Punch and Kick enter the paid-action quarantine, proves S4 emits no unowned `SimCommand` bit, then requires a release before each quarantine clears. It does not claim S5 attack behavior.

## Root integration

1. Promote and pass the focused S4 control, Loom, and root-integration gates first. This capture expects `PlayerPreferences` revisions 2/1, `ControlBindingEditor.set_migration_notices`, the starter-preview `SpellLoomEditor` API, `CharacterWeavePolicy`, and the staged Bootstrap whole-weave authority path.
2. Copy only `capture_gameplay_s4.gd` to `tests/visual/capture_gameplay_s4.gd`. Keep this `.gdignore` and README out of live test paths.
3. Run through the root-owned serialized native wrapper with a fresh `--output=res://.godot/gameplay-s4-ui-<run-id>` directory. The script rejects an existing or differently named directory.
4. Require exit 0, `PASS: 6 actual-game S4 UI frames`, six PNGs, and `capture-receipt.json`. Review the preview at native size for all twelve readable comparisons and Apply/Cancel clarity; review both controls frames for Punch/Kick bindings and readable migration feedback.
5. Archive the source-hashed receipt with the native images. Native renderer output establishes this UI boundary only; human acceptance, persistent-profile recovery, multiplayer acknowledgement, and performance remain separate.

Rollback is one test file: remove `tests/visual/capture_gameplay_s4.gd`. Generated `.godot/gameplay-s4-ui-*` evidence remains separate.
