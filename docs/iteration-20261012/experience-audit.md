# Experience audit — October 12 iteration

Current experience state: E1 contact ownership and E2 airborne flier casting have
passed their scoped native reviews. E3 guide/result pointer handoff passed clean
verification after both fixture repairs. E4's 11-pixel status-row lift passed the
paid before/after native comparison and focused geometry checks. The 30-suite
integrated focused gate passed; final Full and delivery qualification remain open.
The current acceptance table below owns status; earlier proposals and checkpoints
are retained as historical evidence.

Scope began as a read-only audit of frozen `p60-be680e20d70e`, followed by bounded
authorized implementation. The [iteration brief](SELF-PROMPT.md) and [single queue](../../.agent/OVERHAUL-IMPLEMENTATION.md)
own authorization and ordering. No engine, import, test, profile or export was
run by this reviewer. Runtime, tests and original artwork were unchanged during
the audit. Root owns engine execution and the included-usage cutoff.

The preserved `be680` fallback passed 261 suites / 7,401,986 assertions and its
portable gates. Those results do not establish human readability, controller
feel or final-source 60 FPS. The new foreground attempt expired before Start;
it supplies no gameplay timing. Earlier `46fca` timing belongs to the intermediate
source, and the rejected paid-ground cache must not be silently reintroduced.
See [current delivery](../smoothness-20261012/README.md),
[performance](../smoothness-20261012/performance.md) and
[presentation evidence](../smoothness-20261012/experience.md).

## Priority 1 — correct wall-contact evidence and reset ownership

**Confirmed fixture defect; production lifecycle omission.** The previously
reported detached tan fragment beside Grace is an authored wall-contact effect,
not established evidence of broken character artwork.

- The historical native images
  [tick 52](../../.godot/motion-proof-20261012-60-repair/wall_east-025.png) and
  [tick 58](../../.godot/motion-proof-20261012-60-repair/wall_east-028.png) show the
  shape at a constant position while Grace rises. A read-only pixel comparison
  matched **all 104 opaque pixels** of the first shape to frame 0 of
  `magic.movement.walljump_burst.normal`, and **all 102 pixels** of the second
  shape to frame 1, both at anchor `(858, 193)`. The asset is in
  `art_batches/pixel_v1/magic/manifest.json`; its declared role is harmless
  movement at actual wall contact. Original character atlases remain untouched.
- `tests/visual/capture_action_motion.gd:13,40,59,69,92` uses one presenter for
  four independent worlds, each with player entity 1. The four drawings use
  different panel-space anchors. `pixel_movement_effects.gd:109–124` stores
  historical contact by entity ID only, so these unrelated worlds overwrite one
  another's remembered contact. The last actor is Grace. The fixture also follows
  each actor by changing its supplied anchor without projecting the remembered
  contact through the same moving view.
- `src/presentation/cartoon_champion_presenter.gd:1331–1333` obtains and draws
  that remembered burst. `tests/unit/test_cartoon_champion_presenter.gd:214–228`
  checks observed-contact anchoring and age expiry, but not separate worlds with
  reused entity IDs or an explicit world reset.
- Production has one real world with unique player IDs. Crucially,
  `src/app/bootstrap.gd:1388,1449–1473,2038–2089` installs a world transform and
  supplies world-space actor anchors. **The initial hypothesis that ordinary
  camera movement leaves the production effect fixed on screen is withdrawn.**
  Preserve that world-space path. There is nevertheless no contact-history clear
  alongside the camera/gait/trail reset in `bootstrap.gd:5545–5553`; presenter
  history can outlive its world/session. A near-time reused ID can consult old
  history unless a fresh contact or time guard replaces/rejects it.

**Established precedent and limit.** [Riot's clarity explanation](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/)
prioritizes accurate location, direction and importance of gameplay cues. Apply
that principle to making a wall-contact cue belong to its actual contact. It
does not prescribe this implementation, justify deleting an intentional cue, or
prove that the corrected motion feels good.

**Bounded implementation tree.** Experience implements; gameplay independently
reviews; root integrates its one lifecycle hook and runs verification.

1. Preserve the source artwork and existing effect duration/budget.
   - Add a contact-history-only `PixelMovementEffects.clear_contacts()` and a
     presenter wrapper; do not reset shared immutable magic art or unrelated
     budgets. Root invokes the wrapper in `_reset_motion_history()`.
   - Retain entity IDs inside one presentation scope. Do not key by mutable or
     cloned `PlayerState` object identity; prediction/reconciliation may replace
     an instance without changing its actor.
2. Correct the native fixture's presentation scope.
   - Give each independent world its own movement-effect history while sharing
     immutable admitted art. Use actual world anchors and a separate panel view
     transform, so current actors and historical contacts move together when
     that view follows the actor.
   - Reset histories between scenarios. Record the relevant presenter/effect,
     fixture and atlas hashes, sampled action, remembered-contact anchor and
     ownership scope. Label 30/60 Hz as sampling cadence, not measured FPS.
3. Add meaningful checks before declaring the visual issue resolved.
   - Separate real entity IDs cannot overwrite each other's contacts.
   - Two presentation scopes with the same entity 1 remain independent.
   - Explicit reset plus near-time entity reuse yields no stale burst without
     a newly observed contact; the existing age, no-contact and fixed-world
     location checks remain.
   - An ordinary paid wall approach/kick/cast trajectory retains payment,
     collision, authority hash, contact expiry and unchanged art bytes.
   - Root captures a bounded moving sequence with translated/zoomed views in
     normal and reduced effects. Inspect isolated body/contact layers as well as
     the actual combined draw, then independently review the clip/filmstrip.

**Rollback and limits.** If isolation changes unrelated layers or authority,
revert the fixture/runtime slice while preserving failed captures. Old native
frames remain evidence of what their fixture drew, not proof that Grace's atlas
is malformed. A corrected isolated sequence still does not establish human
animation acceptance, every roster action, physical input or frame pacing.

## Priority 2 — verify flying-character cast readability after wall release

**Known presentation limitation; lower priority than the contact correction.**
`src/presentation/fullbody_cast_presenter.gd:392–398` attaches the existing
independent hand layer to actual held flight and to non-flying airborne tucks.
Ordinary airborne wall-jump/fall states on a flight-capable character do not enter
that branch. `pixel_flipbook_presenter.gd:266–268` instead accepts the authored
action bank, whose whole-body frame at `pixel_action_bank.gd:130–143` reports
`independent_cast_pose=false`. The old Grace tick-52 record has a live paid cast
with no hand layer; however, Bootstrap still draws the separate spell-startup cue
at `bootstrap.gd:1481`. This is not an invisible or unpaid cast defect.

**Precedent.** The same [League clarity source](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/)
supports maintaining action/direction recognition while moving. The
[official Melee overview](https://www.nintendo.com/en-gb/Games/Nintendo-GameCube/Super-Smash-Bros-Melee-268951.html)
describes distinct air/ground defensive actions, but supplies no H.E.X. animation
timers or proof that every airborne action should use a new pose.

**Bounded next decision, dependent on priority 1.** First inspect the corrected
paid sequence with the already-visible startup cue. If the cast remains difficult
to distinguish, prototype the existing independent hand layer on a flight-capable
ordinary rise/fall body, preserving the authored body, active-flight gate,
preparation/recovery deadlines and zero additional text. Avoid treating every
airborne flier as actively flying. Gameplay reviews bounds, startup/recovery
continuity and expiry; root captures actual paid examples in all aim directions
and reduced effects. Require exact body pixels, separately bounded hands,
unchanged authority and visible return to the plain body. Do not call this a
complete bespoke animation cycle. Defer implementation if the isolated native
evidence does not demonstrate a meaningful readability gap.

## Coverage and deferred findings

| Area audited | Current evidence / remaining scope | Decision |
| --- | --- | --- |
| Movement trails | `character_movement_trail.gd:7–18,126–146` has fixed tracks/segments, time sampling, witnessed displacement, gap/reset rules and reduced-motion suppression. The prior paid route captured 40 frames, with 38 containing strokes and a six-segment maximum. | Preserve; another trail rewrite lacks evidence. New contact tests must not regress trail ownership. |
| Projectile clarity | Previous all-63 geometry checks plus 210 native projectile cases preserved ingredient, collision and Fuse/Mantle bounds; only two decorative arcs were removed. Native draw-submission savings are not total-frame savings. | Preserve core/direction/danger cues. Technical owns the measured paid-ground experiment; review its fill changes against exact native coverage. |
| Casting/Garden waste | Paid-ground submission remains a measured large stage; optional menus are absent from those closed-menu workloads. Existing spatial Garden memo keys exact view/observer inputs. Previous style/batch proposal was withdrawn despite pixel equality. | Prioritize the peer's bounded retained-fill experiment, not speculative thinning or another metadata cache. |
| Loom/Range/reference reading | `readable_testing_panel.gd:33,61–68` and `spell_inspector_model.gd:10–30,44–83` can reproject and wrap selected facts during each open-panel draw. `readable_reference_panel.gd:40–45,87` also wraps current reading content. | Potential optional-panel allocation work, **not a demonstrated casting bottleneck**. Measure before adding caching; invalidation must include live perk/status timing, selected/equipped wire, input device, bindings and text scale. |
| UI/input/accessibility | Previous 196-frame receipt includes 68 images at 200%; Options Back, visible ingredient cursor, pinned selection, short Aim cue and actual compact pointer/key/pad routes were repaired. This is prior-845f capture scope, not a new be680 capture. | No new blocking source defect established. Retain controls and avoid a new UI redesign without observed failure. Physical controller and first-time comprehension remain open. |
| Tutorial/Range/Garden | Paid introduction and optional three-rival learning journey have actual command tests. Garden distinguishes harmless ground demonstrations from actor statuses requiring paid damaging hits; selected mixture opens a paid Range preset. Range target/stat controls preserve ordinary finite resources. | Keep optional teaching and concise cues; no new text justified by this audit. Future human observation should test whether a player finds the actual preset and understands the distinction. |
| Map/wayfinding | `wellspring_map_panel.gd:144,156,185,201` restricts tiny-map selection to the visible marker and draws selected authored links; prior dense-marker overlap was repaired. Links are authored connections, not a shortest-path guarantee. | No new confirmed defect. A real traversal/fast-travel comprehension session is more informative than another static overview or additional labels. |
| Audio/environment depth | Prior bounded priority audio and native actor/ground shadows are preserved; listening and 3D-feel remain human judgments. Nintendo's [Oracle examples](https://www.nintendo.com/us/whatsnew/july-update-two-game-boy-games-are-now-available-for-nintendo-switch-online-members/) support concrete environmental consequences, not arbitrary new interactions. | No scope expansion. Keep useful reaction footprints and distinct terrain consequences visible while technical work reduces submission cost. |

## Review handoff

The selected first slice is contact ownership/lifecycle plus corrected native
evidence. Flying-character cast parity is contingent on that corrected evidence.
No additional player-facing text or art generation is proposed. Gameplay must
review the contact API, retained world coordinates and paid fixture before edits;
root owns the Bootstrap hook, serialized gates and final qualification. Technical
and gameplay changes receive separate source/behavior review; their receipts do
not silently qualify this workstream.

## Historical first implementation checkpoint — before root gates

After the audit, root authorized the first slice and gameplay independently
approved the exact changes. `PixelMovementEffects.clear_contacts()` and
`CartoonChampionPresenter.clear_motion_contacts()` now clear only owned contact
history; root added the guarded wrapper call to the existing Bootstrap motion
reset. Production world coordinates, character artwork and effect timing remain
unchanged. The unit additions cover separate scopes with reused entity IDs,
neighboring actors, near-time reset, shared art/budget preservation and authority
purity. Their camera arithmetic is structural evidence only.

The native fixture now supplies real world anchors under each panel's camera
transform and gives each independent world its own mutable effect history. The
bounded `--wall-contact-audit` mode uses an ordinary 72-tick paid wall approach,
kick and cast, yielding 18 full samples and two isolated body/contact views at
tick 52 per effects profile. It records source/art hashes, scope and world/screen
contact positions and rejects a contact that differs from the independently
observed touch. Root must run the focused suite and native sequence, and another
reviewer must inspect those images before closing the Grace observation. No new
pass or performance benefit is claimed at this checkpoint.

Experience also approved the gameplay Gust change and 23-case paid delivery
diagnostic source, and approved technical's three retained-fill substitutions as
an experiment subject to exact native phase/heat/transform/coverage and measured
submission checks. These approvals are source reviews, not execution results.

## Historical contact capture review and flier prototype

Root's corrected contact captures passed in both
[normal](../../.godot/motion-proof-iteration-contact-normal/receipt.json) and
[reduced](../../.godot/motion-proof-iteration-contact-reduced/receipt.json)
effects: **18 full samples plus two isolated layers per profile**, empty stderr,
and no missing trajectory coverage. Each of the four actual identities admitted
and released one paid cast and recorded 30 wall-contact ticks. These are 30 Hz
presentation samples of a 120 Hz simulation, not a measured frame-rate result.

Independent review inspected ticks 36, 48, 52, 56, 64 and 68, including the full,
body-only and contact-only tick-52 views. The four wall bursts belong to their
respective remembered wall contacts; the body-only view contains none, while the
contact-only view reconstructs them. Stored world contacts remain fixed as their
screen positions follow the camera, and the transient bursts expire. This closes
the scoped fixture/lifecycle issue without changing character artwork or claiming
complete animation or physical-input acceptance.

The same corrected sequence confirms a narrower Grace continuity gap: hands are
present during the paid wallrun startup, then absent after wall release while
startup and recovery remain active. The fixture omits Bootstrap's separate spell
startup cue, so this evidence does not establish an invisible attack in the game.
Root authorized a prototype, source-reviewed by gameplay, that applies the
existing hand layer only to a flight-capable actor's ordinary airborne authored
action key when an actual cast window is active and no independent cast layer is
already present. It preserves the original body, actual flight eligibility,
resources and timers. The existing
[layered-animation precedent](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-layered-animations-in-unreal-engine)
supports separating locomotion and action layers; it does not establish that
these particular reused hand pixels are anatomically clean.

Declared geometry tests cover six ordinary airborne actions, eight aims, both
effects profiles, all four hand phases, exact body preservation, returned-data
mutation isolation, expiry and interruption negatives. The bounded native
`--flier-cast-audit` supplies eight independent Grace worlds, one ordinary charged
jump and paid Heavy per world, no held flight, 16 full samples and an isolated
plain-body view per profile. Root execution and all-direction visual comparison
were pending at this checkpoint. Retain the prototype only if those images show clean, useful
poses without duplicate or detached anatomy; source assertions alone cannot make
that judgment.

### Flier native result and next input defect

Root subsequently produced passing
[normal](../../.godot/motion-proof-iteration-flier-normal/receipt.json) and
[reduced](../../.godot/motion-proof-iteration-flier-reduced/receipt.json) captures:
**17 PNGs per profile**, eight actual Grace actors/aims, no missing coverage and
empty stderr. Independent inspection compared the full and plain-body tick-54
images in both profiles and all eight facings at gather 42, release 66, settle 78
and expiry 84. Hands remain attached around the torso; raised/forward palms are
clearest in side and diagonal views. Back-facing changes are subtler. No detached
appendage, duplicated body or conspicuous extra limb was observed in these
samples. Reduced effects retain the hands without additional reach. The cast
ends and the plain body returns at tick 84, before landing. This supports retaining
the scoped layer; it does not establish bespoke animation coverage, physical input
feel, human comprehension or frame performance.

The fresh menu/input review identified two instances of one concrete defect:
nonmodal guide Skip/Details and the finished Chemistry result Close consume a
pointer press without the existing gameplay handoff. A supported left-button
spell remap can therefore reach the raw gameplay sampler while the UI click is
still held. The default left-button Punch binding currently has no live command
bit, so this is **not** a claim of default Punch damage. Modal menu/map/Range paths
already quarantine their input; reviewed loaner restoration and binding/device
refresh paths did not establish another actionable defect.

Root authorized the existing two-frame guard and release-to-rearm quarantine at
those three successful UI intents, with no new layout, controls or player text.
The guide reuses `_handoff()`; result dismissal adds the same guard and router
discard. Gameplay reviewed both source and regressions. Tests use actual parsed
mouse events, viewport dispatch and inherited Bootstrap handling, hold through
and beyond the guard, release, then require a fresh normal paid cast. The result
test extends the existing genuinely completed two-Bolt demonstration; it does
not fabricate a result. Source copies are preserved in
`.godot/iteration-20261012/ui-handoff-before`. Engine verification was pending
at this historical source checkpoint; later executions are recorded below.

The first focused execution passed **58,242 spell-testing assertions and 246
result-dismissal assertions**, but the guide fixture emitted a warning because
it reparsed the same mutable `InputEvent` for press and release within one engine
frame. That run is not a clean acceptance receipt. Its exact fixture is preserved
in `.godot/iteration-20261012/guide-handoff-failed-1`; the correction creates a
detached event for each subsequent physical transition, preserving every paid
input assertion. A clean rerun remains required.

The next six-suite execution passed every assertion, including the same 58,242
spell-testing and 246 result-dismissal checks, but strict warning rejection found
the equivalent reused-event warning in the result fixture. This second run also
does not qualify as a clean acceptance receipt. Its exact source is preserved in
`.godot/iteration-20261012/result-handoff-failed-1`. The independently reviewed
repair adds only three event duplicates before release, fresh press and cleanup
release; every event field, dispatch path and paid-state assertion is unchanged.
The repaired result fixture SHA-256 is
`7623f4915845d347ba067a149e55525b769171eaaca9f80cbc5678611fd725aa`.
Both fixtures were frozen for root's clean integrated rerun. That
[30-suite focused gate](focused-ci30.json) passed **1,547,015 assertions**, zero
failures and empty stderr, including **58,242 spell-testing** and **246
result-dismissal** assertions. The earlier warning-bearing receipts remain
preserved; this clean execution supplies the input-handoff regression acceptance.

### Optional viewport observer correction

The native collector lifecycle probe exposed a distinction in Godot's viewport
API: the scene node retains the requested `UPDATE_ONCE`, while the rendering
server consumes it and disables subsequent updates. This follows the
[scene-node getter](https://github.com/godotengine/godot/blob/4.6/scene/main/viewport.cpp#L5060-L5068)
and [server draw lifecycle](https://github.com/godotengine/godot/blob/4.6/servers/rendering/renderer_viewport.cpp#L731-L843).
The first native probe on the installed 4.7.1 engine failed its node-property
reset assumption; it produced no passing receipt. The optional profiler now
records the effective server policy before drawing and keeps the requested node
policy separately. A consumed one-shot request therefore cannot cause a stale
timing query on later frames. The server getter may synchronize the rendering
thread, so its cost is explicitly part of the observer's limitations. This path
remains disabled by default. Technical independently reviewed the narrow repair.
Root's pure validation passed **182 assertions** across the four supporting
suites. The corrected [native lifecycle receipt](../../.godot/iteration-20261012/viewport-native-lifecycle-b.json)
passed **17 groups across eight stages**, with empty stderr. Independent
recomputation verified all three role rows per group, callback serials, null
inactive/absent readings, and exact summary counts: root one warmup plus 16
continuous readings; main five absent, four inactive, three warmups and five
continuous; spare five absent, five inactive, three warmups and four continuous.
After the one-shot draw, the installed engine reported requested node mode 1 and
effective server mode 0; both subsequent main rows stayed inactive with null
readings. Cleanup accounts for four enabled targets as two disabled live targets
and two freed targets, with no live ownership or connected observer remaining.
Receipt SHA-256 is
`6dcca8a03f75aebcb8d9eca9745f806102239d6fc26e67d4f5cf6ca8591440a0`.
Neither policy observation nor a stored CPU/GPU reading proves a presented frame,
qualifies whole-game performance, or identifies the source frame of engine
timestamps.

### E4 accepted native composition: ailments and evade crest

The bounded follow-up audit found one reproducible geometry conflict.
`ElementStatusPresenter.draw` previously placed its opaque 12-by-14 badge at body
Y minus 77 and is called after the complete champion
draw (`bootstrap.gd:1481`, remote equivalent `:2095`). A large fixed-pixel pose
reports height 68. Its intangible crest center is the presenter anchor minus
81; Bootstrap offsets that anchor by the 18-pixel shadow radius times 0.58, so
the crest center is approximately body Y minus 70.56. The stroked crest and a
single centered ailment plate therefore overlap. The status layer can obscure
part of the protection symbol; side slashes and body opacity still communicate
protection, so this is not evidence of an entirely invisible protected window.

The [before receipt](../../.godot/iteration-20261012/status-protection-a/receipt.json)
contains eight native images of one ordinary paid Light Rapid hit followed by
one ordinary large-actor roll. Full/body/protection/status columns reproduce the
production anchors and painter order at 1× and 0.75×, in normal and reduced
profiles. Independent inspection confirmed that the ailment plate obscured part
of the crest. The existing side slashes, translucency and remaining-window pips
were still visible.

The retained change moves the existing fixed badge row from −77 to −88. It adds
no icon, text, frame sampling or state-dependent movement. Original presenter
and test files are preserved in `.godot/iteration-20261012/status-row-before`.
Independent source review covers all admitted 58/63/68-pixel body heights,
one through six badges, ink-expanded intangible crest, actual 16-by-16 spawn
stamp, pips, both profiles and both zooms. These prepared geometry checks remain
distinct from the paid native trajectory.

The [after receipt](../../.godot/iteration-20261012/status-protection-b/receipt.json)
passed with eight images and empty stderr, using the exact same helper
`3c5a6212dc9488ad1224c71604e1225754f8e96298bfe4d469cb2e98cc7c1378`.
The genuine contact is at tick 4, first protected roll at 5, last protected tick
at 20, and first vulnerable tick at 21. There is one cast and release, 2,000 Flux
and 600 Matter paid; roll Stamina changes from 700,000 to 676,000. Independent
comparison found identical commands, all four canonical snapshots, and initial
and final world hashes before and after. All eight after images were inspected:
the badge, crest and pips are now separately visible at both zooms and profiles;
the first vulnerable image removes protection while keeping the ailment.
Receipt SHA-256 is
`3912c36d3cd0ef09841e2c3b87774976679d23e7da33bc055111687085638ae0`.
This accepts the bounded placement correction. It does not establish every
possible multi-actor overlap, startup-cue combination or first-time human reading.
The same clean [integrated focused gate](focused-ci30.json) subsequently passed
**20,531 element-delivery-presentation assertions**, including the cross-component
clearance checks. It was a focused test tier, without Full, 120 Hz boot or package
execution; it must not be promoted to those separate gates.

### Current experience acceptance checklist

| Slice | Established evidence | Remaining delivery gate |
| --- | --- | --- |
| E1 contact-history ownership | Exact scoped reset and peer review; paid normal/reduced contact captures, 20 PNGs each, independently inspected ownership, camera projection and expiry. No body-art replacement. | Final integrated regression and delivery qualification owned by root. |
| E2 ordinary airborne flier casting | Scoped existing hand layer and peer review; paid normal/reduced captures, 17 PNGs each, all eight Grace aims and natural cast expiry independently inspected. | Final integrated regression and delivery qualification owned by root. |
| E3 consumed pointer handoff | Three existing intents use the established guard/quarantine; genuine parsed-input and paid-world regressions passed cleanly after independently approved event-identity fixture repairs. | Final Full regression and delivery qualification owned by root. |
| E4 status/protection separation | Existing row lifted 11 pixels after paid native evidence confirmed crest overlap; eight before and eight after images, both profiles and zooms, independently inspected with identical commands and authority. Peer-reviewed geometry checks passed in the clean focused gate. | Final Full regression and delivery qualification owned by root. |

None of these gates establishes physical mouse/controller testing, first-time
human comprehension, complete bespoke animation coverage, or sustained frame
performance. The portable fallback remains separately qualified until root
completes the current source's delivery process.

### T5 arrival preparation: independent UX and native acceptance

Technical's next bounded change stages Garden exhibits only after a successful
map travel. Ordinary walking keeps synchronous admission and gains no new wait.
The review required atomic publication, one funded entry per presentation frame,
exact current camera demand, cancellation on world/mode/directory replacement,
and existing input quarantine. It also identified two corrected edges: a ready
Garden must stay detached while terrain is still loading so resize can rekey
it, and a preparation failure must remain in a separate diagnostic after the
ordinary fallback. The existing progress bar counts both prerequisites; the
early input guard prevents a new menu or Range panel being hidden by loading.
No new player-facing text was added. Gameplay's independent fixtures cover the
real held travel click, release and fresh paid cast, ordinary walking, cancellation,
an injected preparation failure, and the ready-Garden/terrain/resize sequence.

The [native Bootstrap receipt](../../.godot/iteration-20261012/garden-arrival-native-a/receipt.json)
passed **255 checks, 28 production process observations and four PNGs**, with
empty stderr and the actual normal safe-close path. Independent inspection of
all four images found readable progress at 2.33%, 53.49% and 97.67%, followed by
the complete Garden. The [independent review receipt](garden-arrival-native-review.json)
pins the raw/helper/PNG hashes, isolation boundary and proof limits. Independent
receipt recomputation confirms all 27 pending
observations remain at world tick zero with the exact same authority hash and
no published plots; the final observation contains all 28 independently selected
visible masks. All four image hashes match the receipt. Receipt SHA-256 is
`57968891ab5376009d98e89c86fffb8c11a3d28f210f8568a1839d306309d02d`.

The helper boots the actual scene in a required fresh isolated user-data directory
inside this iteration's `.godot` folder. All five watched stores were initially
absent. Boot creates the isolated preference file; other watched stores remain
absent, and the journey verifies no changes after boot before normal close.
Startup and close may write isolated diagnostic preferences; this is not a claim
of zero disk writes. The real user's profile is outside the admitted path.

Each observed production process is paused afterward for serialized native
readback. The completing observation advances from tick 0 to 8, so these captures
cannot establish ordinary arrival duration, catch-up behavior, foreground frame
pacing or physical input acceptance. The source manifest printed during this
diagnostic was deliberately stale; exact watched source hashes in the receipt
identify its scope. The native result is not runtime-identity, Full or package
qualification. Root's separate scheduling comparison and final delivery gates
own those remaining claims.

### Current diagnostic follow-up: Garden presentation and HUD

The `foreground-a9a85-five-minute` run completed its five workload rows after
manual Start, but the user confirmed briefly switching away. Its focus admission
failed and the whole run remains unqualified. A fully focused final Mantle row
does not qualify the run selectively. All five rows report `ready=true` and an
empty `garden_arrival_error`; Garden arrival records 33 area/Garden-loading
observations and 25 resident plots, followed by a warm Garden row with no loading.
Those fields support completed staging, but do not assert modal state. The
separate native T5 receipt above remains the evidence for no hidden UI.

The raw draw attribution identifies a cold-presentation lead: the first Garden
draw is 125.988 ms, including 90.066 ms in surface preparation and 32.087 ms in
plaques; the next two draws are 1.775 and 1.783 ms. These are nested CPU diagnostic
observations from a focus-rejected run, not qualified arrival latency or FPS.
The independently reviewed T6 proposal prepares at most one current visual entry
per presentation frame behind the already authorized explicit-travel wait. It
must reuse the actual ordinary projection, surface preparation and plaque
constructor, retain exact readiness through resize/cancellation, and publish
only after terrain, funded courts and current visuals are ready. Ordinary
walking remains unchanged. Native first-frame equality and cold/warm attribution
are required before accepting a performance claim; first GPU upload can remain.

The same report does **not** support a HUD layout-cache-miss diagnosis. Warm Garden
adds zero binding, card, frame-layout, panel-geometry or text-metric builds. Fire
adds one panel and 78 changed resource-label measurements; Mantle adds 157 such
measurements with no geometry rebuild. Remaining method submission and live
argument preparation need separate attribution before another cache is justified.
Godot already retains shaped text in its
[Font draw-string implementation](https://github.com/godotengine/godot/blob/4.6/scene/resources/font.cpp#L316-L343).
The [paired native HUD diagnostic](../../.godot/iteration-20261012/hud-attribution-a/receipt.json)
passed seven cases, each with four warm-up and 32 measured pairs, and empty
stderr. Independent review recomputed all 14 PNG hashes, verified seven exact
image pairs, 16 measured pairs in each callback order per case, and all 448
unchanged-authority draw observations. All seven distinct images were visually
inspected: resources, paid startup/cooldown, hidden paid cast, hover and compact
controller prompts remain intact. Receipt SHA-256 is
`471f99a29adae1909665d93082fcdab1e53b095aed77d4906d6fd893895b7d62`.

| Frozen paid/UI state | Plain submission mean (ms) | Observed submission mean (ms) |
| --- | ---: | ---: |
| Idle single elements | 2.687 | 2.599 |
| Paid Fire startup | 3.277 | 3.664 |
| Paid Fire cooldown | 3.855 | 4.275 |
| Paid all-six Mantle startup | 2.774 | 2.993 |
| Paid Mantle on the hidden spell layer | 2.209 | 2.248 |
| Resource hover | 1.774 | 1.951 |
| Compact controller layout | 2.610 | 2.788 |

The observer-minus-plain mean varies from -3.28% to +11.79%; instrumentation
overhead and timing noise are material. Observed spell-cell submission spans
0.949–2.487 ms across these cases. Panels (0.505–1.038 ms) and glyphs
(0.247–0.710 ms) overlap the resource/spell-cell totals and must not be added to
them. Capacity and cast-gate queries take 33–76 microseconds in the plain path;
other Bootstrap argument preparation is excluded. Cache builds remain bounded
to changed state/layouts, with no builds during the warm Fire-cooldown case.
These are repeated draws of frozen authority, not an evolving gameplay,
foreground, GPU, frame-time or latency qualification. Cases run sequentially,
so their totals do not rank spell cost or establish cross-case performance.
No production HUD optimization or improvement has been claimed; a later
experiment could isolate unchanged drawing while preserving live warnings and
the exact painter order.

T6's first focused gate ran all 184,149 assertions without assertion failures,
but was correctly rejected for destruction-time script errors: the presenter's
manual PREDELETE cleanup tried to resolve a self-bound callback after its script
instance became null. The preserved failure is not a clean pass. Independent
review approved removing only that redundant five-line callback block, while
retaining explicit old-font disconnection during live font replacement.
[Godot's Object contract](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-connect)
and [destructor implementation](https://github.com/godotengine/godot/blob/4.6/core/object/object.cpp#L2306-L2314)
already disconnect signals targeting freed objects. The repaired source and
added lifetime regression then passed the five-suite gate with **184,153
assertions, zero failures and empty stderr**; the original rejected logs remain.

The new [actual Bootstrap visual-arrival receipt](../../.godot/iteration-20261012/garden-visual-arrival-native-a/receipt.json)
passed **288 checks, 28 production process observations and four PNGs**, with
normal safe close and empty stderr. The [independent review](garden-visual-arrival-native-review.json)
pins the receipt, helper, PNG and watched source hashes. All four images were
inspected: the existing loading overlay remains readable at 2.82%, 50.70% and
97.18%, then exposes the complete Garden, ordinary labels, character and HUD.
All 27 pending observations preserve world tick zero and the same authority
hash with no published plots. The final observation contains all 28 expected
masks, world tick 8 and exhibit tick 7, with current visual readiness complete.
The first actual inherited draw has matching current geometry keys; geometry
builds remain 28 and plaque builds remain 28 before and after that draw, with
unchanged authority. Receipt SHA-256 is
`b6445ecf8bd416a65ded40df4ab92bd98248c546b89ceb21d0d68636465f7fad`.

This helper boots the full scene in a required fresh isolated diagnostic profile.
Boot creates its preference file; watched stores remain unchanged during the
journey before normal close. The actual user profile is outside the admitted
path. As in T5, each real process is paused afterward for readback; completing
0-to-8 ticks is observed rather than suppressed. These are lifecycle, cache-work
and visual results, not ordinary arrival latency, foreground performance, GPU
upload, physical-device or Full/portable qualification. The printed
`p60-a9a85d210a6f` manifest was intentionally stale; actual watched hashes identify
this execution. Separate paired offscreen Garden results and root's current
qualification record own any broader attribution or delivery claims.

One separate source defect is deferred: HUD startup fill divides the paid
remaining timer by the authored base startup, while admission can apply perk or
status timing. The visible numeric cooldown countdown still uses the actual
remaining clock. Re-projecting a current perk after payment cannot reconstruct
the admitted total reliably. A later bounded fix needs a truthful duration
contract and actual paid threshold/expiry tests; it must not be folded into the
HUD cost experiment or solved with a speculative balance change.

### Next HUD experiment after qualification: retain unchanged spell-card commands

**Proposal only; production remains unchanged.** The fully admitted
[`foreground-1e084` source run](foreground-1e084/summary.json) reports zero focus
loss. Warm HUD submission means/p95 are 1.806/2.881 ms in Garden,
1.910/3.139 ms for paid Fire and 1.890/3.054 ms for paid all-six Mantle.
Garden adds no layout/binding/panel/text builds. The paid rows change resource
text and one panel; they do not establish repeated spell-card layout misses.
Together with the exact-image attribution above, this supports investigating
unchanged command submission in the four visible spell cards. It does not
prove that HUD alone explains frame intervals or that another cache will help.

The smallest proposed diagnostic boundary retains each **complete current
spell card**, with at most four active items. It uses the existing drawing
method (`compact_combat_hud.gd:358`) and existing card model (`:508`), avoiding
new artwork, labels, altered readiness or an invented second clock. Each frame
still computes the current `spell_display_status` (`:421`) from current
authority. A card redraw is requested only when one of its displayed values
changes; a paid timer's changing fill remains live. This follows Godot's
[documented retained draw-command behavior](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html#updating),
not a claim about how League's renderer is implemented. Riot's
[clarity principles](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/)
support preserving important state changes and visual hierarchy while avoiding
extra noise; they provide no numerical performance guarantee for this design.

Required current-value invalidations are:

- The selected layer and each slot's complete displayed ability descriptor:
  empty/playable state, element/mask, family, title, cost and any in-place catalog
  edit that changes the card. Compare values rather than wire ID alone.
- Exact computed readiness kind, label, progress, casting and waiting values.
  Payment, resource thresholds, control, death, cooldown, capacity and startup
  changes must become visible on the first changed draw. Retain no actor or
  paid-state object in the rendering key.
- Current binding text/device, logical rectangle, UI scale/viewport, font
  replacement or `changed` revision, and all colors/layout/copy used by the
  card, including the empty-card Loom message and mixed/single glyph choice.
  Preserve inherited transform, clip and material semantics explicitly.
  Reconfiguration, teardown, reconnect, spectated actor/world/mode replacement
  and HUD visibility transitions must clear or redraw the current four entries.

**Painter order is a hard prerequisite.** Bootstrap currently submits the HUD
at `bootstrap.gd:1547`, then practice coaching, Garden inspection, edge-clamped
controller aim and modal panels afterward on the same parent CanvasItem. A
naive retained child would draw above those later commands. The diagnostic
must first establish an explicit bounded pre-HUD/card/post-HUD ordering seam,
or reject the integration. Do not trade correct modal or aim visibility for a
small CPU saving. Resource bars, jump preparation, paid hidden-layer cue,
session text and feedback stay on their existing live paths in this first
experiment; whole-HUD retention is outside its scope.

Acceptance requires an unchanged immediate reference and exact native pixels
on the **first changed frame** for all three layers, single/mixed/empty cards,
actual paid startup/release/cooldown, resource/capacity/control boundaries,
held modifier release, remapped input/device changes, font changes, resize and
100–200% reading scales. Include overlapping coach, Garden card, controller
reticle and each modal as painter-order witnesses, plus world/spectator/actor
replacement and safe teardown. Verify authority hashes and that unchanged
cards submit zero new commands after warm-up, while changed cards redraw once.
Measure key preparation plus retained child callback work in alternating
native pairs with instrumentation overhead, followed by the same admitted
foreground workload. Keep only a repeatable saving without extra frame cost or
stale cues. The existing paid-startup denominator defect remains a separate
correctness task; this experiment must not silently change its semantics.
