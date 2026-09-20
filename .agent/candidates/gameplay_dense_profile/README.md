# Dense paid workload profiling candidate

Status: isolated candidate, static review only, **NOT RUN**. It makes no change to live simulation, tests, scripts, imports, snapshots, or build identity.

## Promotion map

| Candidate file | Intended live destination |
| --- | --- |
| `dense_profile_workload.gd` | `tests/performance/dense_profile_workload.gd` |
| `profile_dense_headless.gd` | `tests/performance/profile_dense_headless.gd` |
| `dense_profile_render_harness.gd` | `tests/performance/dense_profile_render_harness.gd` |
| `profile_dense_rendered.gd` | `tests/performance/profile_dense_rendered.gd` |
| `profile-dense-headless.ps1` | `scripts/profile-dense-headless.ps1` |
| `profile-dense-rendered.ps1` | `scripts/profile-dense-rendered.ps1` |

The wrappers resolve `flux2-common.ps1` from either this candidate directory or the promoted `scripts` directory. After promotion, the integration owner runs them with a fresh immutable identifier:

```powershell
pwsh -NoProfile -File scripts/profile-dense-headless.ps1 -RunId <fresh-id>
pwsh -NoProfile -File scripts/profile-dense-rendered.ps1 -RunId <fresh-id>
```

## Measured boundary

`DenseProfileWorkload` creates the same empty 1,280,000 by 960,000 fixed-unit court, deterministic seed, four local opposing fixture emitters, production `oh_tipi` champion state, and real Water/Fire Bolt, Heavy, Rapid, and Spray kit for both variants. It submits one ordinary production command per actor per tick, including genuine alternating movement and deterministic center/neighbor target patches. It never refills Flux, raises a capacity, clears cooldowns, inserts projectiles or fields directly, evicts retained state, or ends a sample early. The four emitters are an explicitly unnetworked instrumentation fixture and establish no lobby or player-capacity support.

The headless driver alternates ordinary/hex order for three repetitions per variant, excludes 240 warmup ticks, and samples 2,400 ticks at 120 Hz. `SimWorld.step` is timed by itself. For ordinary mode, production `AuthoritativeSession` event retention, snapshot construction, and snapshot wire encoding have separate timings and byte/queue counters. The current snapshot schema does not carry HexCourt, so hex mode reports exact court canonical state bytes as a local diagnostic and checks their digest against `HexCourt.state_hash`; those bytes are never labeled network traffic.

The native driver measures four bounded cases: ordinary normal, hex normal, hex reduced, and ordinary reduced. Each excludes 120 warmup frames and samples 600 frames with two separately timed simulation ticks per frame in a 1280 by 720 main window. It records `Bootstrap._draw` CPU submission time and queue-to-`frame_post_draw` elapsed time separately. The wrapper injects no `--fixed-fps` override; the receipt records the repository's configured max-FPS value, and elapsed frame time is not a capacity claim. Both variants share an empty renderer backing; ordinary keeps production legacy chemistry/projectile/actor/cue presentation, while hex adds canonical court presentation.

Both receipts include production source hashes and runtime identity, actual command/admission/refusal/cast family/element counts, products and queue maxima, actor outcomes, conservation where applicable, final state hashes, Godot memory/render monitors, and repeat/mode invariants. The wrappers use the common serialized engine lease, 180-second owned-child watchdog, runtime identity and class-cache checks, isolated `APPDATA`, personal-profile hash guard, hardware inventory, and fresh `.godot` JSON/log paths.

Physical multiplayer, sockets, remote clients, snapshot support for HexCourt, infusion input, lobby scaling, OS working-set/VRAM residency, installer behavior, publication, and player-facing acceptance remain outside this candidate. Physical/infusion extensions can add new workload commands later without changing the baseline timeline.
