# Simplification without lost depth

Status: 2026-09-30 local playtest checkpoint p56-c47fb65e2bd7. Full/native correctness and Windows package launch/safe-close passed. Dense 120 Hz remains failed; human feel remains open.
Working prompt: [SIMPLIFY-WITHOUT-LOSS](../.agent/SIMPLIFY-WITHOUT-LOSS.md).

[Start current build](../exports/hex-simplification-20260930/windows/PLAY-HEX.cmd) ·
[Five-minute trial](HEX-PLAYTEST.md) ·
[Package receipt](simplification-evidence-20260930/package/receipt.json).
Only this build and the verified boundary-reuse fallback remain. No installer,
historical checkpoint pointer, Git commit or remote release was promoted.

## Design judgment

Depth comes from combining choices, timing and opponents' responses. Complexity
that merely forces a player to memorize another label, or a developer to keep
two copies of a rule synchronized, contributes no useful depth.

| Keep the decision | Simplify how it is learned or maintained |
|---|---|
| Movement chains, exposure and resource tradeoffs | One explanation of action/profile/height; exact windows remain in the Compendium |
| Eight distinct elements and 36 reactions | One canonical identity and rules source; UI/rendering project that data, not a second rules table |
| Bolt, Heavy, Rapid and Spray | Teach Focus, Splash, Pressure and Fan roles alongside their names; keep live costs/strength/speed/reach |
| Twelve configured casts | Show actual keys first in the existing 4 x 3 layout; slot numbers remain secondary for reference |
| Thirty identities, three body sizes | Shared size/animation infrastructure, distinct art and authored stats; no roster cuts |
| Exact hex ownership and reactive phases | Reuse identical calculations only when inputs match; never merge enemy/ally, phase or danger boundaries |

The Loom's 32 spells already form an 8 x 4 matrix: exploit that familiar structure
instead of adding another menu or a new customization currency. All spell names,
filters, starter preview, assignment/swap rules and advanced metrics remain.

## Applied cycles

| Cycle | Implementation | Preserved contract |
|---|---|---|
| Identity | Remove renderer's duplicate 36-row wire/pair/shape table; read compiled policy identities | Explicit render order, all 44 descriptors, palette cadence, independent returned dictionaries |
| Work reduction | Share equal material styles only within one draw call; bounded transient memo | Exact phase/danger/intensity inputs; no cross-frame state; colors and animation remain current |
| Teaching | Actual keycaps lead loadout cards; delivery headers express roles | No slot, spell, name, mechanic, geometry or UI action removed |
| Combat tempo | 25% slower travelling shots, shorter cast cycles, preserved nominal reach | All damage, size, paid cost, strength, reaction and movement rules unchanged |
| Input ergonomics | Bolt joins Rapid's existing held-repeat path; Heavy/Spray remain deliberate presses | New-press priority, per-cast payment, release-stop, cooldown and capacity gates retained; no new persistent state |
| Delivery identity | Compile explicit family once from catalog; chemistry, optional-residue compatibility and projectile art read it | Trigger behavior never changes impact size, reaction allocation or visual delivery identity |
| Field preparation | Share a field workset while scheduling initial paths/pulses only | Revalidate live source/coverage during resolution; rebuild after mutation, never reuse across ticks |

## Alternatives rejected

- Fewer spell slots or reactions would simplify by deleting expression.
- Making every reaction the same damage field would erase cover, routing,
  visibility and timing choices rather than making them understandable.
- A universal long-lived presentation cache would add invalidation rules and
  risk stale danger cues; per-call reuse is easier to reason about.
- Deleting legacy-named wire/save helpers without a migration would break
  compatibility. Classify them before removal, regardless of their filenames.
- Replacing the 1437-line historical contract wholesale during a runtime change
  risks dropping commitments. This concise entry point and the single queue
  guide work; history stays linked until a separate audited consolidation.

## Review and acceptance

### Authorized tempo follow-up

The later user request adds slower travel, faster firing and high-load fixes.
That intentionally changes combat timing, unlike the first three cycles.
All 24 travelling spells use 75% of prior speed; lifetime increases to keep
nominal reach within one pixel (tick-quantized integration is tested within five).
Hit radii, direct/blast damage, Flux payments and reaction strengths remain fixed.
Spray remains an instant paid fan, not a travelling projectile.

| Delivery | Speed px/s | Cooldown ms | Startup ms | Approximate minimum start-to-start interval at120Hz |
|---|---:|---:|---:|---:|
| Bolt, common template |345.6|180|55|241.7ms|
| Water / Charge / Fire / Dark Bolt |432 /460.8 /403.2 /374.4|150 /160 /170 /180|45 /50 /50 /55|200 /216.7 /225 /241.7ms|
| Heavy |240|750|160|916.7ms|
| Rapid |456|80|20|108.3ms|
| Spray, common template |Instant|650|120|775ms|
| Water Spray (Tideline) |Instant|700|130|833.3ms|

Cooldown begins at release; do not describe it alone as the full firing interval.
The first new cadence fixture incorrectly omitted startup and failed 64 assertions;
it is retained and corrected to test the actual release-owned clock, not to change
that gameplay rule. Live Loom metrics automatically follow the compiled catalog:
`FIRE EVERY` includes startup plus cooldown using the same 120 Hz clock; the raw
cooldown remains in the detail row. Bolt and Rapid can be held; releasing stops
new admissions but does not cancel a startup already paid for. A fresh spell
press wins over a held repeat when ready; no queued cancellation is invented.

Load acceptance uses eight real paid casters, held Rapid bursts then Heavy/Spray/
Bolt choices, original and reversed command order. No resource refill, capacity
override, hidden projectile deletion or effect removal. Bounded admission remains
in place; it is not proof that arbitrary projectile/player counts can run smoothly.
Initial field-list reuse must preserve every tick's authority/events exactly;
after contacts mutate strength/coverage, later queries must be rebuilt.

### Fun and depth, without feature inflation

| Decision | Intended benefit | Tradeoff retained |
|---|---|---|
| Place/hold a Bolt | Visible travel allows dodge/counterplay; held fire frees attention for movement and aim | Precision and a paid strength-five ingredient still matter; releasing cannot refund an accepted cast |
| Commit a Heavy | Slower threat and wider impact encourage space control and prediction | Longer commitment and greater Flux expense; not a faster Rapid |
| Hold/release Rapid | Faster pressure rewards timing bursts and changing aim | Each shot still costs Flux; weak shots lose strength contests |
| Time a Spray | Reactive close fan intercepts and supplies an ingredient | Finite range and paid strength; not a free emergency shield |
| Combine impact fields | Existing 36 recipes offer routing, pressure, cover and denial choices | Exact whole-hex reach, phase windows and finite matter remain authoritative |

These are design intentions, not proof of fun or competitive balance. Slower
travel can help defenders but also keeps more shots alive; the same-clock load
tests and player trial must judge both sides of that tradeoff.

### Measured paid-pressure result

One sequential before/after pair, both command orders, same tuned data and
ordinary capacities. This is not an alternating benchmark or a global speedup.

| Simulation-only measure | Before initial-field reuse | After corrected reuse |
|---|---:|---:|
| Step median, original / reversed |9.594 / 9.815 ms|8.489 / 8.565 ms|
| Step p95 |18.145 / 18.286 ms|16.139 / 15.138 ms|
| Projectile contacts p95 |13.507 / 13.709 ms|7.676 / 7.657 ms|
| Missed 8.333 ms deadlines, of 720 each |501 / 509|379 / 394|
| Worst tick |89.994 / 86.978 ms|87.893 / 86.959 ms|

All 1,440 tick authority/event states match byte-for-byte, including 138 paid
admissions, 35 deposits, 52 reactions, and peak 29 simultaneous flights in each
run. The 120 Hz gate still FAILS, notably Spray spikes and actor/admission work.
2,160 refused requests include cooldown/capacity pressure; this workload is not
a claim to sustain all 128 projectiles or 32 players. Resources/caps were not raised.
The first after run FAILED on a typed-empty-array branch. Its apparently equal
trace does not make that run valid; logs are retained. Explicit typed empty
worksets and an empty-scene regression fix it in `after-v2`.

Final-source repeat (`reactive-final`) preserves that exact same trace and final
hash in both orders, with zero stderr and 1,889 checks. Timing is worse than the
intermediate after run: median9.897/9.825ms, p9518.387/17.971ms,
max98.565/99.011ms,559/555 missed deadlines. This eliminates any honest claim of
a robust overall speedup from the earlier sequential pair. The work reduction is
structural and contact-specific; sustained performance remains FAILED.

Full regression rejected the first held-Bolt candidate: three consumers inferred
Rapid from `repeat_while_held`, changing Bolt's chemistry footprint and drawing
identity. Delivery family is now explicit compiled catalog data, independent of
input behavior. The original paid overlapping-terminal matrix and optional-trail
compatibility fixtures must pass unchanged; live trails remain disabled. New
all-32-definition tests lock agreement among catalog, chemistry and renderer.
The Compendium now teaches held Bolt and uses the live Rapid cooldown.

### Final correctness and presentation

- Full:172 suites /1,786,509 assertions; no failures/stderr; import, post-import
  identity and configured120Hz boot passed. Configuration is not timing acceptance.
- Ordinary UI:49 checks /11 native captures. Equip held Bolt via the Loom,
 3 paid admissions in65 ticks, release prevents new payment, saved rebindings,
 explicit unbound cards, Gallery attunement and disabled-service behavior.
 The first added UI fixture pressed during the existing menu-close guard; its
 failure is retained. Four neutral frames establish a fresh gameplay press,
 exactly as the existing Heavy journey did; no runtime guard was weakened.
- Style reuse:1,246 native assertions;4 paid-scene exact RGBA/state pairs and
 6 all44-material phase/mode controls match the raw-style oracle.

| Alternating native draw CPU,32 samples per arm | Median before -> after | p95 before -> after |
|---|---:|---:|
| Distributed152-cell / Normal |59.056 ->53.699ms|66.432 ->59.022ms|
| Distributed152-cell / Reduced |58.183 ->54.667ms|79.845 ->61.130ms|
| Compact13-cell / Normal |22.860 ->23.441ms|26.898 ->29.485ms|
| Compact13-cell / Reduced |22.724 ->22.598ms|32.251 ->25.292ms|

The compact Normal case regressed; keep that result rather than selecting only
improvements. These are frozen CPU submissions, not live FPS/GPU acceptance.
Native review covered the actual Bolt detail, bindings/unbound states and full
material grammar; human readability, fun, balance and dense moving play remain open.

Every cycle must preserve authority and existing option reachability. First
focused identity run exposed a dependent test still reading the removed table;
the obsolete dependency was replaced with an independent frozen test oracle.
That run is failed evidence despite its selected suites printing pass lines.

Completed with full regression, native field equivalence, ordinary Loom/attunement/
paid-cast journey, reviewed screenshots and a source-bound Windows package.
Do not claim human understanding, competitive balance, multiplayer or120 Hz from
automated checks. Performance tails and larger working sets remain separate.

## Next simplification candidates, not silently enacted

1. A single query model for exposure/height eligibility, guarded by replay and
   every existing ground/low/air exception; do not replace rules with a blanket immunity flag.
2. Generate player-facing reaction facts from live policy and group explanation
   by purpose, without changing reaction names or hiding exact counterplay.
3. An audited contract index that separates live rules, acceptance evidence and
   historical rationale; no duplicate active plans or unverified mass deletion.
4. Profile large working sets before adding more caches; prefer sparse canonical
   data and fewer passes over temporal shortcuts that change outcomes.
