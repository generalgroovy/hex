# H.E.X.: product assessment and implementation direction

Status: **clean Windows Full passed; source candidate is not packaged or promoted. Product and release acceptance remain open.**
Status updated **October 16, 2026**.

October 15, 2026. Baseline: Git `aec900a`, qualified Windows runtime
`p61-d6d1bfb9c529`. This pass resumes development on
`codex/hex-breakthrough-20261015`; the published Linux handoff branch remains a
stable starting point. The user authorized implementation and creative scope.
The 20,000-credit floor, launcher route and preservation of qualified builds remain.

## Diagnosis

H.E.X. has considerable systems coverage and unusually extensive correctness
evidence. Its principal product weakness is that the systems do not yet form an
equally clear, memorable and independently validated player experience. Thirty
characters, twenty-one ancestries and 504 spell definitions describe breadth.
They do not establish why a new player should finish a fight, start another, or
tell someone about it.

The strongest existing hook is **defeat an elemental rival, learn their signature,
and use it to change the next fight while chaining movement and reshaping space**.
This joins three real strengths: readable adversarial patterns, earned tools and
movement/chemistry expression. It is more specific than presenting every available
system at once. The recommendation is to demonstrate that hook in one coherent
short route before producing a larger campaign or complete art library.

This is a product hypothesis. No internal test suite, reference game's success or
new feature establishes commercial demand. The decisive missing evidence is what
unfamiliar players do without a developer explaining the game.

The new Circuit integration proves that an earned spell can be selected, paid
for and released in the next encounter. **It does not prove that this choice
creates a useful tactical advantage or makes the route worth replaying.** Its
ordinary counterplay can still win the route; an extra release is not a test of
player preference or combat usefulness. Preserve ordinary Next alongside learned
use, then observe one understandable counter opportunity rather than force the
reward into a mandatory loadout puzzle.

## What is already real

- Six active elements, eight deliveries and 63 compositions are implemented.
  Their 504 definitions have bounded paid rules; combination count is not proof
  that all options have distinct tactical value.
- Thirty rivals and an optional Rapid/Fuse/Rebound lesson order already exist.
  Real owned paid victories award signatures through protected progression and
  save-recovery paths. The other 474 spells are already available; this is not an
  economy where every new spell is a major unlock.
- Advanced movement, interpolated presentation, finite resource/protection
  windows, trail readability, practice tools and an optional introduction exist.
  Adding another smoothing layer would not supply missing authored poses.
- Wellspring contains seven districts, thirteen travel destinations and a
  complete Element Garden. The architecture and interior ambitions in the
  illustrated 2.5D proposal remain substantially future work.
- The current qualified Windows build has passed extensive correctness and
  packaging checks. Current-build packaged frame pacing is still unmeasured.
  Historical source observer timings and isolated optimization results cannot
  substitute for that measurement.

A retained [native Quayside view](depth-clarity-evidence-20261014/native/world-b/deep-north-reduced-candidate.png)
also makes the visual production problem concrete: repeated paving occupies
much of the frame, the character is small, and sparse rectangular structures
provide little immediate sense of an inhabited place. This is a historical
presentation sample, not a capture of every district or a motion/performance
test. It supports a focused building/landmark pilot with a quieter ground plane
and stronger activity cues; it does not justify adding detail everywhere. Static
images cannot establish animation or sound quality, which need moving/listening
acceptance separately.

## Product choices

| Direction | Strength | Cost or unresolved assumption | Decision |
|---|---|---|---|
| Pure competitive sandbox | Movement, interception and chemistry already support expressive duels | Requires human balance, matchmaking/community density and two-device acceptance | Preserve as a capability; do not make an empty online population the first-session dependency |
| Broad open-world elemental RPG | Fits the large map and environmental wishes | Requires authored quests, interiors, pacing, rewards and substantial content production | Use one purposeful building and route as a pilot before expansion |
| Full procedural roguelite | Could provide repeated build choices and runs | New encounter director, rewards, difficulty curve and save semantics; competes with mature exemplars | Do not introduce a second game framework before testing the existing hook |
| Short authored rival route | Uses current real encounters, signatures and districts; quick to test | Three existing encounters are not a campaign, and replay value remains unproven | Implement an optional Rival Circuit as the first coherent product experiment |

The Circuit must preserve free exploration, every individual rival, the Range,
existing controls and the original save. A player may continue with their chosen
setup or explicitly use the newly learned spell in the next fresh encounter.
There is no forced loadout puzzle or fabricated reward. The three existing trial
limits bound combat duration; no unmeasured 5–15 minute completion claim is made.

## Assessment by aspect

| Aspect | What is lacking | Concrete improvement or expansion | Acceptance that matters |
|---|---|---|---|
| Identity and audience | A recognizable promise connecting the systems | Present the rival→signature→next-fight loop; show movement and terrain in the same encounter | A new player can explain the game after one route without listing the menu |
| First minute | Numerous peer menu actions compete with a goal; discovery does not establish understanding | Put the optional Circuit first; retain Introduction and exploration as clear alternatives | Find/start unaided, then explain the objective and one rival tell/response without coaching |
| Session arc | Isolated encounters and a suggested list lack a clear conclusion | Three-rival Circuit with stage results, retry, explicit next and a final replay/practice choice | Real terminal outcomes; no double grant, accidental progression or unclear exit |
| Combat depth | Definition coverage exceeds evidence of useful decisions | Build adversarial encounter scenarios that reward timing, countercasting and a changed tool; compare simpler mixtures | Players can describe why they changed spell or route; fewer dominant universal answers |
| Spell identity and AoE | Glow/name differences can conceal shared mechanics or misleading footprints | Preserve true contact/ground boundaries; use the existing eight delivery grammar; separately version any damage-allocation change | Players correctly predict hit/miss and danger timing in ordinary moving fights |
| Movement | Elaborate legal chains still need an attractive learning gradient | Teach one useful combat route per encounter, then permit shortcuts and expression | Beginners finish with basic actions; practiced movement improves routes without permanent immunity |
| Enemy design | Signature demonstrations are not yet a full encounter ecology | Give each later encounter a readable spatial problem and one compositional surprise | Actual escape routes, commitment and recovery remain visible; challenge is not merely more projectiles |
| Progression | Most spells are already available; a numerical unlock list alone is weak motivation | Immediate optional reuse, visible mastery and meaningful next encounters before adding currencies | A learned tool changes a subsequent decision; saves remain truthful and recoverable |
| Characters and races | Many passive definitions do not guarantee memorable identities | Prove one hero/rival authored action pilot and its asset budget before three representative anatomy sets | Recognizable silhouettes/actions and natural passive benefits, not only prepared trigger fixtures |
| Art and animation | Incomplete action/direction coverage and inconsistent production scale | Follow the approved illustrated 2.5D pilot, with consistent pivots, motion timing and material language | Moving capture across turns/casts/jumps/wall contact; resident memory stays within an explicit budget |
| World and buildings | More space and taller facades alone do not create places worth visiting | One useful enterable Academy building with truthful cover/cutaways, followed by differentiated district routes | A building changes traversal or a fight; self remains visible without hidden enemy information |
| Sound and impact | Existing bounded cues need a coherent authored identity and listening acceptance | Prioritize threat/release/hit/defeat information; add ambience/music only with separate buses and measured residency | Understand critical events without looking at a label; no sustained clipping or cue masking |
| UI and accessibility | A confirmed compact-map overlap makes controls ambiguous | Reserve pagination space before laying out map rows; keep shared draw/hit geometry | At 960×540/200% text, each visible control has a distinct usable target; remaps and controller actions survive |
| Performance | Smooth current packaged play has not been established | Enable matched Full/Light observations through the launcher; then measure package-presented frames and resident memory | Sustained paid casting/Garden/travel at declared display settings, exact build and machine context |
| Installation and platforms | Windows-local qualification does not prove a fresh machine or Linux | Clean-profile first launch/save/reopen; separately repair and qualify native Linux helpers/launcher | A new machine reaches play without undocumented developer setup |
| Multiplayer | Protocol coverage does not establish a good online player experience | Actual two-device join/cast/disconnect/rejoin route, then small human sessions | Authority, input ownership and readable remote movement survive real conditions |
| Discovery and distribution | No validated audience response, demo funnel or truthful gameplay pitch | Prepare a focused playable demo, actual gameplay capture and feedback route after product gates | People understand the store promise, try the demo and voluntarily continue; no fabricated conversion claims |
| Architecture and production | Bootstrap coupling and large asset ambitions raise iteration cost | Extract only changed lifecycle seams; one queue, bounded agent ownership and independent review | Smaller changes remain testable; no parallel engines or speculative renderer rewrite |
| Documentation and QA | Huge assertion totals can obscure unresolved product questions | Label correctness, presentation, performance, human play and release evidence separately | Every claim has a matching receipt or explicit open acceptance item |

## Implementation selected for this pass

1. **Rival Circuit:** local coordinator over the three existing lesson rivals;
   real challenge authority continues to own combat and rewards. Explicit result
   actions cover next, retry, replay, leave and learned-spell reuse. Temporary
   loadout changes do not replace the player's saved weave.
2. **Discovery and compact map:** a first-menu Circuit action, task-based ordering
   of existing activities and a geometry repair for small logical viewports.
3. **Performance measurement access:** an explicit `-LightObserver` option on the
   existing launcher Profile mode, preserving the default full observer and
   matched workload settings. Light omits full completed-step attribution and
   detailed draw diagnostics; compare only metrics present in both modes.
   This is measurement tooling, not an FPS gain.
4. **Integration and evidence:** actual admission/transition/save boundaries,
   controller/mouse/keyboard paths, visual checks and appropriate regression
   validation. Keep the qualified portable selected until a replacement clears
   its own delivery gates.

### Current source validation and remaining delivery gates

The candidate is `p61-6618873387e2`; normal desktop Play still selects qualified
`p61-d6d1bfb9c529`. The [evidence index](breakthrough-evidence-20261015/README.md)
keeps the following scopes separate:

- Circuit focused validation passed **548 assertions**: 488 prepared coordinator/UI
  assertions and 60 actual controller-integration assertions, with zero failures
  or stderr. The integration covers three real paid wins and subsequent earned
  casts; persistence is intentionally memory-only.
- Map validation passed **1,403 assertions** inside an earlier **failed overall**
  focused run. Its Circuit completion fixture retained an impossible next-leg
  flag; the narrow test repair and the passing rerun remain separate evidence.
- **Eight native UI captures** at 960×540, with 100% and 200% text scale, were
  independently accepted for prepared layout fit. An earlier helper parse failure
  and incorrect 720×405 content-scale capture remain negative fixture evidence.
- [Full-a](breakthrough-evidence-20261015/full-a/tests.json) **failed** after
  **112 of 267 suites**, **5,280,932 assertions** and **nine failures**, then
  reached the **2,700-second timeout**. The other **155 suites did not
  complete**, and **boot did not run**. One network-capture failure remains
  unresolved; eight remap failures followed a stale test menu-row assumption.
- Three reviewed test-only changes are applied: stable-ID keyboard selection,
  exact InputMap restoration, and bounded network-capture trace/diagnostic
  evidence. Seven-suite `focused-review-a` passed **65,133 assertions, zero
  failures/stderr**, in **264,217 ms** on unchanged runtime identity. Tools
  **58,514 / 0** and Circuit integration **314 / 0** include repaired menu
  routing and InputMap cleanup; the failing eight-player network scenario
  is outside these seven suites. This does not establish a production
  network fix, the historical capture cause, or a complete Full pass.
- The separate local outage diagnostics [A](breakthrough-evidence-20261015/network-outage-a/independent-review.json)
  and [B](breakthrough-evidence-20261015/network-outage-b/independent-review.json)
  passed **6,478** and **6,465 assertions**, respectively, with zero failures
  and **241 trace rows each**. Neither reproduced the rejected capture. Dynamic
  receive checks explain why totals need not match; identical trajectories and
  the historical failure cause are not established.
- Pushed source checkpoint **932f5974fe17a8d2432d8f82873eb86faf564543** passed
  [clean Windows CI Full 38817305452](https://github.com/generalgroovy/hex/actions/runs/38817305452):
  **267 suites / 7,576,123 assertions / zero failures**, all three stderr files
  empty, and correct **661887 / 120 Hz / protocol 61** boot. The
  [independent review](breakthrough-evidence-20261015/ci-full-38817305452/independent-review.json)
  reconciles all ordered suite rows and timings. Signature recovery/progression,
  Circuit/unit integration and network impairment all pass. This completes the
  clean Windows source Full gate; the earlier local failure and its unexplained
  capture rejection remain historical evidence. The candidate has not been
  packaged or promoted, and normal desktop Play remains qualified d6d1.
- The [archived Light source attempt](breakthrough-evidence-20261015/profile-light-concurrent-a/independent-review.json) expired before manual Start: **armed=false, empty
  results, no gameplay measurement**. Other Codex tasks were running, but this
  is not evidence of why Start was missed. Matched Full/Light and packaged
  frame-pacing acceptance remain open; no automatic restart is planned.

These results do not establish a replacement package, durable Circuit save/reopen,
physical-input behavior, current packaged frame pacing, or unfamiliar-player
appeal. The illustrated sprites, tall-wall/self-visibility/interior work and wider
campaign remain proposed; the Circuit does not implement that expansion.

The [single queue](../.agent/OVERHAUL-IMPLEMENTATION.md) owns implementation status
and the ranked next five investments: useful earned-tool choice, first-fight
comprehension, measured smoothness, one hero/rival action pilot, then one
purposeful tall room/courtyard expansion. The first four improve existing play;
the fifth adds new playable space. Qualification and a measurement baseline
precede enlargement of the art/content workload.
The [earlier complete overhaul design](OVERHAUL-DESIGN-20261015.md) retains detailed
contracts for art, AoE, buildings and memory. This document sets product priorities;
it does not create a second active queue or claim the whole overhaul is complete.

The retained [specialist audits and verification archive](breakthrough-evidence-20261015/README.md)
contain the gameplay, experience and technical analyses, their source references
and the executed evidence. Each specialist reviewed the other disciplines; root
owns integration and serialized validation.

## How to decide the next production investment

Use a small formative group of unfamiliar players. Eight to twelve is a practical
pilot size, not a statistical proof of demand or an industry conversion benchmark.
Give the launcher and no verbal tutorial. With their agreement, observe:

- whether they reach an activity and understand its immediate goal;
- where they ask for help, misread damage, or cannot find a control;
- whether they can describe a rival's pattern and a useful movement response;
- whether they choose and successfully use an earned spell;
- whether they choose another attempt after a loss or route completion;
- the exact build, input device, display settings and visible stalls.

Record task completion, help needed, quitting point and the player's own explanation.
Do not score confusion as lack of player skill. Record whether they *choose* to
replay before asking if they enjoyed it. First fix repeated obstacles and unclear
consequences. Starting this Circuit enters the existing ready countdown; the
first-menu position alone does not prove that its first fight is understandable.
Reuse a relevant existing lesson/counter only if observation identifies that gap.

After the remaining delivery checks and a measured baseline, the next art investment is
**one hero/rival authored action pilot** at actual gameplay scale: readable
locomotion and turns, windup/release/recovery, jump/landing and hit response.
Establish its pivots, animation clocks, residency and setup budget before three
anatomy sets. Then connect one useful courtyard/interior to that same loop; do
not mistake a taller facade for completed enterable world design.

Include the current Circuit/map/measurement tools in a replacement candidate only
after their gates pass. Defer roster-wide art generation, additional currencies,
procedural runs, broad campaign growth, multiplayer Circuit and speculative render
caches. Widen content when the small slice gives players a reason to continue;
creative freedom is permission to make strong choices, not evidence that every
possible expansion should ship together.

For performance, run the same paid workloads in opposite observer orders and keep
focus, resolution, cap, detail and memory context matched. Then use an appropriately
qualified packaged/presented-frame route. A lighter diagnostic can identify
observer overhead; it cannot alone establish GPU frame pacing or input latency.

## Reference mechanisms and transfer limits

- [Supergiant's Hades FAQ](https://www.supergiantgames.com/blog/hades-faq/): development
  was structured around community feedback. Transfer the ability to change a
  modular, playable slice from observed player behavior; do not infer that an
  Early Access label or a run structure guarantees success.
- [Supergiant's Hades II development update](https://www.supergiantgames.com/blog/hades-ii-development-update/):
  seek feedback when enough of the game exists to be meaningfully played while
  changes remain possible. H.E.X. needs that product-learning window before mass
  art/content production.
- [Steamworks Next Fest tips](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/tips):
  accurate categorization, a functioning demo and an accessible feedback route
  are concrete distribution requirements. They complement a strong game and do
  not manufacture demand. No store or festival registration is performed here.
- [Steam Playtest](https://partner.steamgames.com/doc/features/playtest): a possible
  later controlled testing channel. A private local pilot remains sufficient for
  the immediate usability questions; account/distribution setup is separate work.
- The earlier proposal's primary Riot, Nintendo, Capcom, Noita, Magicka and
  Gungeon references remain relevant to clarity, world coherence, earned tools
  and systemic experimentation. The specialist review inputs distinguish each
  source's claim from the proposed H.E.X. adaptation. No claim is made that the
  references validate H.E.X.'s exact timing, balance, art budget or sales potential.
