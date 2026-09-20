# S4 keyboard migration marker-loss fix

Status: **isolated candidate; NOT RUN**. Live source and tests are unchanged.

The failing path begins with a deliberate current-revision copy of the exact
historical schema-11 keyboard layout. The current writer adds `punch=0` and
`kick=0`. If an older reader strips only `keyboard_defaults_revision`, the next
load sees the historical layout plus those two normalized zero entries. The old
recognizer required identical dictionary size, classified the two harmless
entries as customization, and retained Evade V / Technique Q instead of applying
the current Evade B / Technique V defaults.

The candidate changes the keyboard migration predicate only. It recognizes
either the exact historical map or that exact map plus both newly introduced
actions explicitly unbound. Every historical action must still match its frozen
default, both added actions must be zero, and no extra key is permitted. A
custom key, explicit unbind of an historical action, nonzero Punch/Kick binding,
partial map, or unrelated extra entry remains outside default migration.

The existing marker-stripping assertion now describes this normalized shape.
Two added defenses prove that an explicit historical unbind and a deliberate
nonzero Punch assignment remain byte-for-byte custom. Mouse and controller
migration, revision validation, persistence, backups, notices, and all live files
are untouched.

Promotion is a direct replacement of only:

- `src/app/player_preferences.gd`
- `tests/unit/test_player_preferences.gd`

No Godot command, import, test, capture, profile write, or personal-file access
was performed. Root remains the test and promotion authority.
