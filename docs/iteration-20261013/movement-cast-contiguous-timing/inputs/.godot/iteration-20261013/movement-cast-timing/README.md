# Ignored movement/cast timing companion

Status: frozen for independent source review and root-owned parsing; not parsed or executed. Canonical runtime and the original functional checkpoint are unchanged. All thirteen original partitions passed independent raw-receipt review (84,172 checks, 2,548 attempted and 2,547 completed steps, with one intentional rejected-command prefix). [PLAN-v2-contiguous.md](PLAN-v2-contiguous.md) is the current contract; PLAN-v1 is the preserved superseded proposal. The additional roster still requires its own complete functional qualification before timing.

Driver: `res://.godot/iteration-20261013/movement-cast-timing/compare-movement-cast-timing.gd`.

CLI (after Godot's `--`):

- Required `--output=res://.godot/iteration-20261013/movement-cast-timing/runs/probe-<fresh-name>`; direct fresh directory only.
- Required one `--case=garden_idle`, `--case=fire_close`, or `--case=bootstrap_roster_mantle`.
- `--functional-only` is accepted only for the additional roster's complete 480-step qualification. It requires no prior receipt and may run headless.
- Timing omits `--functional-only`, requires native display, and requires `--functional-receipt=res://.godot/iteration-20261013/.../receipt.json` plus `--functional-sha256=<exact SHA-256>`. The single selected case, full trace and all source pins must match.
- Optional `--reverse-order` reverses whole-group arm order in a separate process.

Each process emits exactly one selected case and `receipt.json` with `passed`, `errors`, `checks`, `mode`, `selected_case`, `source_hashes`, `cases`, qualification linkage and cleanup. No output overwrite is allowed. Functional mode preserves the original every-tick `_attempt`; timing is a consciously separate reduced packet cadence with strict proof at every actual group boundary. Ordered interior events and branch counts still match every prequalified row. No engine command belongs to this agent; root owns all execution and external watchdogs.
