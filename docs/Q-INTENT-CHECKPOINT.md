# Q movement intent checkpoint — 2026-09-12

Status: local Windows portable verified; human feel and W4 remain open.

The current pointer selects `q-intent-p47-20260912`. Airborne Evade (default Q,
remappable) samples current movement at admission: directional input attempts
the existing paid air dodge; exact neutral starts vertical fast fall. Aim,
facing, previous input and continuing planar momentum cannot create direction.
Grounded neutral Evade retains the movement-facing roll. Screen-down remains
planar movement, not vertical descent.

Neutral Q ends Float and its protection, keeps spent air budgets, detaches an
active wallrun through its ordinary exit, and adds no Stamina cost or protection.
The existing C/Slide alias remains. Holding Q does not repeat; the existing
bounded newest-press buffer uses admission-time input. Airborne buffered Q cannot
turn into a ground roll after landing. The movement compatibility hash changes
so old and new Q semantics cannot join as matching builds. Protocol 47, snapshot
schema 18, 120 Hz, eight players, costs, caps, map and assets remain unchanged.

Playable: [flux2.exe](../exports/windows-q-intent-p47-20260912/windows/flux2.exe)
with its adjacent PCK, or extract the complete
[portable ZIP](../exports/windows-q-intent-p47-20260912/release/FLUX2-Windows-x86_64.zip).
PCK SHA-256: `1f7e4455af3b727e7e59e5f898a65831d38bca6c80529c4f2862ff067381f026`.
ZIP SHA-256: `5b802b96afb5569ca4921e54162981ecb46900bcf62e00f91a6d0cad48b8587e`.
Main HEAD remains `a1aa02807626823d0fbc1e25e75441ca3b7f4d36`; source is dirty,
uncommitted and unpublished. The consolidation, M2b and M2a builds remain intact.

| Evidence | Newly executed result for this Q source |
|---|---|
| Full | 98 suites / 691,064 assertions, zero failures/stderr |
| Source freeze | 3,099 inputs unchanged through export; 13 changed files retain exact baseline-byte backups; two new fixture files |
| Q gameplay | 96 PNGs / 12 actual airborne admissions, three sizes, four trials, normal/reduced, natural landing and draw-hash checks |
| Integrated gameplay | 221 new captures, byte-identical to the preserved consolidation equivalents |
| Static review | Independent runtime review and 20 actual Q-image samples passed with limits below |
| Packaging | New EXE/PCK/ZIP, packed runtime identity and isolated hidden standalone boot passed |
| Localhost | Exact exported game passed host/join, reconciliation, round, late join, return/rematch and host stewardship |

[Portable receipt](evidence/windows-q-intent-p47-20260912/checkpoint.json),
[localhost receipt](evidence/q-intent-20260912/same-export-receipt.json),
[Q capture receipt](evidence/q-intent-20260912/q-gameplay-capture/capture-receipt.json),
[review/rework](evidence/q-intent-20260912/review-and-rework.md),
[source delta](evidence/q-intent-20260912/source-delta.json) and the generated
[movement matrix](evidence/q-intent-20260912/movement-matrix.md) retain the evidence.
Passed and failed focused/capture logs are preserved. Old consolidation receipts
are historical comparison evidence, not proof of these changes.

Human timing/feel, physical controller use, physical two-PC/internet play,
installer/updater and sustained rendered 120 FPS remain unaccepted. The existing
reduced-height presentation ratio compresses the captured lifts to 3–5px; normal
airborne separation is clearer. Expanded coach second lines are width-tested,
but this fixture visually exercises collapsed cards only.

Short playtest: enter the South Loop, jump while moving, release movement and
press Q while still coasting; compare with jump plus held direction and Q.
Try screen-down Q, Float then neutral Q, and the three sizes. Check remapped Q
and reduced effects. The expected distinction is vertical descent with retained
coast versus paid planar dodge, with no new immunity or air-budget refill.

Next in the [single queue](../.agent/OVERHAUL-IMPLEMENTATION.md): P1 chemistry
subphase attribution on matched real-map and synthetic workloads, followed only
by a supported behavior-preserving optimization. W4's historical failing timings
remain unresolved. South Crossrun layout and Small rig work are preparation;
runtime map/effect growth waits on its performance and template dependencies.
