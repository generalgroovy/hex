# Performance attribution and decisions

The current [foreground record](foreground-current-record.json) admits source
`p60-1e084a50a029` at Low/1280×720 with a 60 FPS cap. Warm Garden, paid Fire and
all-six Mantle p95 engine intervals are 29.420, 49.174 and 51.784 ms. These remain
above the 16.67 ms interval for 60 FPS. Full-observer overhead is included;
display presentation and GPU timing are not established by this recording.

The investigation below led to the implemented T4 selection memo, T5 funded
arrival staging and T6 visual staging. T6 improves all 72 measured first-draw and
modeled-peak pairs while preserving 288 exact pixel comparisons. Total CPU rises
in all six case means, so this is a peak-work tradeoff. See the
[paired record](garden-visual-staging-comparison.json) and
[actual arrival review](garden-visual-arrival-native-review.json).

Next is attribution of every completed fixed step in each process frame. The
current observer retains only the last step, which can hide earlier catch-up
work. Three independently reviewed T7 patches are [archived but unapplied](deferred-t7/README.md);
their isolated PowerShell checks pass 239
assertions. Godot parsing, simulation checks and observer-cost measurements are
pending. No improvement is attributed to these drafts.

The first retained-fill trial supports a narrow raw-Fire CPU submission benefit.
It does not explain or solve the observed Garden arrival stall, the dominant
reaction-field cost, GPU work or display pacing. Keep the passed native comparison
and the unqualified whole-game performance boundary separate.

## Initial investigation: exhibition admission before staging

**Observed cost.** The historical intermediate foreground Garden arrival includes
a 248.226 ms p99/max from only 35 intervals. Its warm Garden fixed-step cost is
small. First-visible plot construction is synchronous in
`ElementGardenExhibition.step`, but source inspection alone does not establish
that construction dominates the arrival frame.

**Hypothesis.** Admission might contribute enough CPU time to justify preparing
detached destination exhibits during existing travel/loading work. An alternative
is that drawing, initial material art, terrain validation/upload or another stage
dominates. Do not change the production lifecycle until measurement distinguishes
these possibilities.

**Children and checks.** Root prepares the ignored
`.godot/iteration-20261012/profile-garden-admission.gd`; technical independently
reviews it. It executes real harmless exhibit admission at the authored Garden
midpoint, three supported camera scales and three fresh objects per scale. Each
object records first visibility, a warm repeat and departure/revisit. Nested
`_new_entry` and `_emit_cycle` elapsed times are kept beside the inclusive step;
they must not be added together. Record actual resident masks, finite exhibition
stock and conservation outside the timed callbacks. Preserve exact watched-source
hashes and the fresh receipt. Root alone runs the bounded headless process.

**Limits and decision.** This probe excludes rendering, uploads, Bootstrap, live
player resources, foreground eligibility and the operating-system file cache.
Catalogs are deliberately admitted before the measured arrival. It is attribution,
not a comparison against an implemented optimization or a frame-pacing result.
Any later staging proposal needs exact visibility, cancellation, first-frame
readiness, memory and actual arrival comparisons; no visible plot may be omitted.

Godot describes the separation between requesting threaded work and retrieving
completed resources, while Factorio's terrain work demonstrates preparing newly
visible content and reusing stable draw work. These support investigation of the
boundary, not a promise that H.E.X. has the same bottleneck.
[Godot background loading](https://docs.godotengine.org/en/4.6/tutorials/io/background_loading.html),
[Factorio Friday Facts 323](https://www.factorio.com/blog/post/fff-323).

## Leads rejected before implementation

The executed admission probe now contains **27 observations** with identical
watched source hashes, successful exhibition conservation and no omitted visible
plots. Three fresh objects per zoom record the following mean inclusive step:

| Zoom / resident plots | First visible | Warm repeat | Revisit |
| --- | ---: | ---: | ---: |
| 100% / 10 | 28.124 ms | 0.041 ms | 31.598 ms |
| 75% / 25 | 88.399 ms | 0.072 ms | 82.356 ms |
| 50% / 55 | 206.927 ms | 0.172 ms | 209.067 ms |

The raw receipt is `.godot/iteration-20261012/garden-admission-a.json`; its log
has empty stderr. Technical independently recomputed the observations. About
81–86% of admission time lies inside `_emit_cycle`, so the next bounded task
attributes footprint selection within that stage. The proposed exact local
geometry reuse is conditional on that result and unchanged full court state,
ordered coverage and visible phases. These initial probe times are not measured
game-frame intervals; the subsequent implementation evidence is linked above.

- **Another general text cache:** Godot's `Font.draw_string` already retains
  shaped lines, and Garden plaques retain their own `TextLine` objects. The
  Garden labels therefore do not support the proposed shared-font cache-thrashing
  explanation. No cache budget was increased. The inspected 4.6 source explains
  the mechanism, not the exact installed 4.7.1 timing.
  [Godot Font source](https://github.com/godotengine/godot/blob/4.6-stable/scene/resources/font.cpp#L316).
- **Deep-copying every HUD ability:** `AbilityCatalog.ability_from_wire` returns
  the catalog's existing dictionary. It does not perform the hypothesized deep
  copy, so no replacement catalog cache is justified.
- **Wrong production wall-contact projection:** production already supplies world
  coordinates under the camera transform. The native fixture and lifecycle reset
  needed correction; another projection transform would introduce a defect.

The technical audit owns the separate opt-in viewport CPU/GPU observation work.
Its readings must retain the engine API's unknown source-frame age; a sampled
observation frame number cannot turn an old timestamp into a current-frame total.
