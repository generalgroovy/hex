# Repository consolidation

Status: **canonical repository and branch authority contract**.

## Product authority

`C:\Users\sende\Projects\flux` is the only authoritative FLUX working
tree. It is a Godot 4 project; `project.godot`, `src/`, `content/`, `assets/`,
`packaging/`, and `scripts/` define the shipped product.

The canonical integration branch is `main`. Every published playable checkpoint
lands there after its relevant gates pass. `codex/continuous-overhaul` is a
compatibility/handoff branch only; it may be fast-forwarded to a green `main`
checkpoint but never defines newer product truth or receives independent
long-lived work.

## Retired browser lineage

The former browser-only checkout at `C:\Users\sende\Documents\FLUX` ended at
commit `e13171473baf67b2264479467b650974a4c65290` on
`origin/integration/unify-flux`. Before retirement it was verified clean and
exactly synchronized with that remote branch. Its full source and history are
therefore recoverable from <https://github.com/generalgroovy/flux.git>.

The imported `legacy/web-prototype/` copy is also retired. It was never loaded
or packaged by Godot and keeping a second runtime in the product tree made
installation, documentation, testing, and ownership needlessly ambiguous.

No browser runtime code was promoted. The durable design lessons already have
Godot-native implementations or explicit contracts:

| Retained lesson | FLUX 2 owner |
|---|---|
| Compact virtual-pixel presentation | `src/presentation/`, visual tokens |
| Separate world pivot, feet, shadow, and airborne height | champion presenter and movement presentation |
| Anticipation, travel, impact, and expiry phases | spell presentation contracts |
| Shape and ownership remain readable without hue | projectile and effect presenters |
| Rendering never owns simulation rules | fixed-tick systems under `src/sim/` |

## Branch policy

- New work uses one short-lived `codex/<gate>-<outcome>` branch only when useful;
  accepted playable checkpoints land on `main` without rewriting history.
- `codex/continuous-overhaul` may be fast-forwarded after acceptance for old
  handoff links; divergence is resolved toward the tested `main` checkpoint.
- Compatibility IDs are migration adapters, not permission to revive legacy
  product language or a second runtime.
- Generated imports, build output, caches, local dependencies, credentials, and
  machine-specific firewall rules are not product source.
- A slice may be pushed only after its relevant deterministic tests, source
  boot, and imported-resource boot pass.

## Recovery

The retired browser state can be inspected without restoring it into the
product tree:

```powershell
git clone --branch integration/unify-flux https://github.com/generalgroovy/flux.git legacy-review
git -C legacy-review checkout e13171473baf67b2264479467b650974a4c65290
```

Do not use that checkout to launch or develop FLUX 2. The authoritative run,
test, package, and installer commands are maintained in the root `README.md`.
