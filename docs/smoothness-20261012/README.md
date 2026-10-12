# October 12 smoothness follow-up

Status: **p60-be680e20d70e is locally qualified and packaged.** Full, export,
archive, terrain and release lifecycle checks passed. Final foreground timing remains
unqualified after the Start deadline expired; the optional renderer stays unchanged.
The [single queue](../../.agent/OVERHAUL-IMPLEMENTATION.md) owns work status.
The [previous delivery](../implementation-20261012/README.md) remains independently qualified.

The user prioritizes smooth casting and the Element Garden, fast projectiles that
outrun player movement, concise effects without extra text, and trails that show
actual player paths. Three specialists implement and cross-review bounded slices;
root serializes engine tests, captures, profiles and exports.

## Candidate

Runtime SHA-256: `be680e20d70e1a284eb4175916a7d97da4446b20bfada79a89f98e741446aa8e`;
3,436 production records. The [gameplay ledger](gameplay.md) records faster projectiles,
finite projectile reach and paid counter tests. The [presentation ledger](experience.md)
records actual-path trails, simpler effects and native image comparisons.
The [technical ledger](technical.md) records retained Garden spatial reuse and the
measured decision to withdraw paid-ground batching.
The [performance comparison](performance.md) owns exact foreground results and limits.
The [validation ledger](validation.md) preserves the first failed Full, the reviewed
test-only repairs, the clean ten-suite repair gate and the clean final Full.

## Play and qualification

Open [PLAY-HEX.cmd](../../exports/hex-smoothness-20261012/windows/PLAY-HEX.cmd),
or extract the [Windows x64 ZIP](../../exports/hex-smoothness-20261012/HEX-p60-be680e20d70e-Windows-x64.zip)
into its own folder. These are local artifacts, not a published release.

- [Full](full-final.json): 261 suites, 7,401,986 assertions, zero failures and stderr;
  import, frozen identity and 120 Hz boot passed.
- [Export](package.json) and [delivery](delivery-files.json): native startup/safe close,
  matching source identity, exact payload/ZIP membership and preserved 845f fallback.
- [Terrain](terrain-pack.json): 132 chunks plus overview, 2,062 exact checks.
- [Release lifecycle](portable-lifecycle.json): five normal-close/reopen cases;
  twelve Fire and twelve all-six Mantle casts admitted, zero refusals, empty stderr,
  unchanged package bytes and identical isolated preferences.

ZIP: 161,150,389 bytes, SHA-256
`9a41e2f97351d012e89da3a0aecf7d9ece95ac8d3fa930fedc207eb806451c83`.
PCK SHA-256: `a166de4eb134061949c831910e3dd43ebdae4985680dfc7c4af9b144af5729ac`.

## Intermediate foreground measurements

Both intermediate `p60-46fca721f60d` profiles completed with unchanged source and no profile-validation errors.
Full-observer p95 frame intervals were 33.774 ms in Garden, 39.859 ms for paid Fire
and 48.763 ms for all-six Mantle. The lighter observer measured 24.547/32.768/33.250 ms;
it has no valid light-observer predecessor baseline. These short observations
support a measured improvement in the matched full-observer runs, not sustained
60 FPS or isolated causal attribution to any one optimization.

## Baseline

[Full-observer summary](baseline-immediate/summary.json): measured, no validation
errors; manual Start received, 105 post-arm Windows observations with 104 available
foreground samples and one excluded boundary, fixed 1280x720 viewport, low settings,
60 frame cap, immediate campus.
Twelve seconds per case. Source: p60-845f85b5253e. These are instrumented engine
frame-start intervals, not GPU/presentation/input-latency measurements.

| Warm case | Mean frame ms | p95 ms | p99 ms | Paid casts admitted/refused |
|---|---:|---:|---:|---:|
| Garden middle | 21.9572 | 39.306 | 53.651 | 0/0 |
| Fire Bolt sustained | 33.8683 | 54.934 | 74.395 | 12/0 |
| All-six Mantle sustained | 37.5554 | 73.790 | 83.079 | 6/6 |

Mantle uses ordinary resources without refills. Arrival/warm observations remain
separate in raw metrics. Paid-ground drawing averaged 5.016/5.294 ms in the two
casting cases; HUD drawing averaged 1.921/1.904/2.046 ms across the three cases.
Garden surface preparation averaged 0.447 ms, merged submission 0.343 ms and
plaques 0.232 ms. Stage values guide investigation; they are not additive claims
about GPU work or every fixed simulation step.

[Light-observer attempt](baseline-light/summary.json) expired before Start and
contains no gameplay cases. It is preserved as a harness attempt and excluded
from performance conclusions. Candidate comparisons must report observer mode.

## Decision precedents

- [Riot real-world profiling](https://www.riotgames.com/en/news/profiling-real-world-performance-league):
  profile the reported workload, bound trail generation independently of speed,
  and avoid effect work outside useful coverage. Transfer: fixed trail budgets
  and measured ground/effect preparation; no claim that H.E.X. matches LoL's renderer.
- [League clarity](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/):
  preserve gameplay importance and readable effect bounds. Transfer: simpler accents,
  ingredient identity and danger cues; no additional player-facing text.
- [Gungeon developer interview](https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-):
  pressure and evasive response work together. Transfer: faster travel tested against
  pursuit, jumps and cover, with finite paid range; numerical speeds remain H.E.X. hypotheses.
- [Oracle environment examples](https://www.nintendo.com/us/whatsnew/july-update-two-game-boy-games-are-now-available-for-nintendo-switch-online-members/),
  [Noita developer talk](https://www.gdcvault.com/play/1025695/Exploring-the-), and
  [Magicka developer postmortem](https://www.gamedeveloper.com/business/postmortem-arrowhead-game-studios-i-magicka-i-):
  legible material consequences and combinations inform existing Garden/status cues.
  This pass does not add a falling-pixel simulation or enlarge the rules grammar.
- [Melee's official description](https://www.nintendo.com/en-gb/Games/Nintendo-GameCube/Super-Smash-Bros-Melee-268951.html)
  and [Apex developer movement discussion](https://www.ea.com/able/news/evolution-collection-event):
  ground/air defensive choice and readable movement counterplay inform witnessed
  path trails. Neither source establishes a universal projectile-to-player speed ratio.

## Qualification boundaries

Projectile changes retain payment, cadence, finite reach and terrain counters.
Focused checks, native projectile/trail checks and 317 exact ground images passed.
The ground cache was nevertheless withdrawn because its paired CPU timings did not
justify retaining it. The restored rendering paths passed 176,632 focused assertions.
Full and fresh portable gates passed. The final foreground attempt expired before
manual Start and is excluded; intermediate timings do not qualify final bytes.
The preserved 845f package remains independently usable. No sustained-60, general
balance or human movement-feel acceptance is claimed.
