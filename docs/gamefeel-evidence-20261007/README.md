# Game-feel foundations

Status: source checkpoint verified; human playtest pending, not a packaged release.
Build `p57-a2124abed591`, 3,113 production records, protocol 57 / snapshot 23.
Runtime SHA-256: `a2124abed591e9a03e825bb7c5efe7c6342b364d6fd8d01590ebefef008daa1e`.
The preceding verified source is [glow / flow](../glow-flow-evidence-20261007/README.md).

## Player-facing changes

| Change | Contract |
|---|---|
| Deliberate movement chains | A newer Evade, Slide or Technique consumes an older held Jump gesture, including refused actions. Consumed wall holds cannot silently purchase Flight after detachment. Release/repress or a genuinely new legal buffer can deliberately continue the chain. |
| Equivalent Slide input | A fresh held-only airborne Slide replaces older buffered Jump just like a pressed Slide. Effective Evade and Jump retain their existing chord priority; no recovery, cost or state field is added. |
| Reliable thin cover | Before creating a projectile, its caster-to-muzzle center line must be clear. The existing full-radius muzzle occupancy and swept flight checks remain. Heavy can still shoot away from a nearby wall. |
| Useful character choice | Gallery Overview shows actual paid flight or double jump, reserves and recovery. Details explain the twelve-slot starter and saved-weave restoration; affinities are not damage multipliers or discounts. |
| Cleaner Spray contact | Keep the elemental fan and individual, visibility-gated impacts; display compact confirmed damage at targets. Remove repeated spell-name banners and the visibility-blind aggregate hit count. |

These are adaptations of the [reference-game principles](../../SPECIFICATION.md#reference-game-adaptations),
not copied movement/frame data or claims about those games' internals. Existing
glow, character wakes, finite chemistry, paid actions, three size profiles and
independent movement/aim remain intact. No broad numeric buffs, new passives,
new spells, roster changes, physics rate or lobby cap changes are included.

## Validation ledger

| Gate | Result |
|---|---|
| Cross-review | Caught held-only Slide retaining an older Jump; corrected before engines. Capture review also hardened expected Gallery capabilities and actual starter-composition evidence. |
| Source identity guard | Initial Generate without Force refused replacement before any engine started. Intentional pre-validation regeneration produced the candidate above; not a gameplay failure. |
| Fast import / boot | Passed: zero stderr, candidate identity and configured 120 Hz boot |
| Focused v1 | FAILED: seven selected movement/prediction suites reported zero assertion failures, but a new paid Rampart test fixture had four untyped Vector2i inference errors. Explicit types repaired the fixture; assertions and production source unchanged. |
| Focused v2 | FAILED: nineteen suites reported zero assertion failures, but the new Spray ingestion fixture omitted the ordinary offline SessionTransport and emitted two nil-access errors. The fixture now constructs that dependency without opening a peer; no production change. |
| Focused v3 movement / combat / Gallery / feedback | [Passed](focused-v3/receipt.json): 19 suites / 291,357 assertions / zero stderr |
| Actual movement-input routes | [Passed](input/receipt.json): 12 routes / 7,547 checks across three sizes for flight, double jump, dodge/fast-fall and wall actions |
| Native Gallery v1 | FAILED: the capture fixture used an untyped empty-array ternary for a typed Array[String]; fixed explicit assignment. Owned stalled capture terminated after inspecting the error; no production change. [Failed log](native-logs/gallery-native-v1.log.err) retained. |
| Native Gallery v2 | [Passed scripted capture](gallery/receipt.json): four asserted overviews and one explicitly partial starter Details page; five unscaled 1280×720 frames, authority unchanged, zero stderr. [Independent review](gallery-review.json) accepts the overviews; Details is genuinely a fragment, not complete composition acceptance. |
| Native paid spell feedback | [Passed scripted capture](magic/receipt.json): 32 paid spell cases and active Fire; 20 images include two synthetic helper boards; zero stderr. [Independent review](magic-review.json) accepts the sampled Spray cleanup; Rapid and damage numerals remain subtle. Ten images directly inspected; ten carried forward by exact byte match to prior reviewed evidence. |
| Full / final identity / configured 120 Hz boot | [Passed](full/receipt.json): 221 suites / 4,138,521 assertions, zero failures/stderr, import/identity/boot and isolated profile restoration |
| Documentation guards | Current-scope check, dependency-guard self-test (105 assertions), generated README pointer check and summary regression (45 assertions) passed. Final edited-doc scope/README/scoped whitespace checks and source identity recheck passed. |
| Human feel / dense sustained performance / physical Internet | NOT_RUN; historical dense timing remains FAILED |

Root owns all engines, identity and integration. Three scoped workers handled
movement, projectile cover and Gallery presentation, with reciprocal read-only
reviews. Production was frozen before testing. Native inspection uses a fresh
isolated APPDATA set before engine startup and restored afterward; disabling
later preference persistence alone would not isolate Bootstrap's startup writes.

All owned engine processes are closed and the engine guard is released. Current
source identity was rechecked after documentation consolidation. Evidence PNGs
are excluded from future Godot imports by this directory's `.gdignore`.
An attempted cleanup of 25 regenerable evidence `.png.import` sidecars and the
two disposable native-test profiles was blocked by the execution policy before
the command ran; those files remain. No deletion was retried through another
mechanism. Original art, unrelated dirty work and retained builds are preserved.

## Human check

Run `scripts\run.cmd --pixel-cast` from the repository with pinned Godot 4.7.1.

| Try | Look for |
|---|---|
| Jump, hold Space and dodge; keep holding Space | No later surprise flight or wallrun purchase; release/repress Space deliberately to continue if legal. |
| Wallrun until it ends; keep Space held | No automatic fallback flight; a fresh press can request unused flight. Ordinary walljump-on-release remains its existing explicit rule. |
| Choose Slide while Jump is queued during recovery | The newer choice wins without shortening the recovery or adding a paid action. |
| Fire near a thin wall, then aim away from it | Cover cannot be bypassed by the muzzle offset; away/tangent shots remain available. |
| Inspect S. Wayne, Oh Tipi, Red Baron and Grace Riva | First-screen air action agrees with actual character capability; inspection does not equip or replace a saved weave. |
| Spray one and several visible targets; compare Reduced Effects | Elemental fan and contacts remain; damage numbers are compact and do not disclose unseen victims. |

Retained installer/portable builds do not acquire these source changes. No
export, package promotion, commit, push or publication is part of this batch.
All thirty pixel identities are retained, not newly authored animation cycles.
Spray off-axis actor-targeting cover and oblique muzzle corner cases remain
explicit follow-up coverage, not implied by mirrored horizontal regressions.
