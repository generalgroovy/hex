# Coverage matrix · source truth versus required sequences

**Status: STATIC_VERIFIED for the measured source counts; PROPOSAL for pending acceptance coverage.**

No row below is human-accepted or freshly runtime-verified. “Present” means available source cells, not complete animation quality. Source evidence: presenter L5–19, L97–132; resolver L71–88; active atlas manifest; proportion checkpoint L69–75. Exact excerpts are under `evidence/SOURCE_EXCERPTS.md`.

## 1. Measured active atlas coverage

| Size | Base cells | Walk cells | Sprint cells | 8 unique phases for all 64 pairs, both banks | PNG + decoded RGBA hashes | Binary alpha / clear outer cell edge |
|---|---:|---:|---:|---|---|---|
| Small | 80 | 512 | 512 | YES, measured | MATCH | PASS |
| Middle | 80 | 512 | 512 | YES, measured | MATCH | PASS |
| Large | 80 | 512 | 512 | YES, measured | MATCH | PASS |

Total: 240 base + 1,536 walk + 1,536 sprint = **3,312 cells in nine original textures**. No new roster skins or new production cells were authored in this review. The 15 source strips are exact extracted samples, not extra live assets. All 63 packet integrity records matched; integrity is not gameplay acceptance.

Visual inspection scope was narrower than the structural audit: all 80 base cells per size and seven selected eight-phase rows per gait bank per size. The specific rows inspected at original-pixel contact-sheet scale were T0/A0, T1/A1, T4/A0, T2/A0, T3/A3, T5/A4 and T6/A0. The P04 annotated board additionally inspects T4/A2. Therefore neither eight distinct hashes nor an inspected subset establishes all-direction anatomical or native-motion acceptance.

## 2. All 64 travel / aim relationships

Every entry below has eight registered cells in **each** walk/sprint bank, for **all three sizes**. This table describes the resolver's relative-gait classes, not whether every phase is well animated.

F = forward; B = backward; SL/SR = strafe left/right relative to facing, not screen left/right. Rows are **travel**, columns **aim**. Direction order is the actual manifest/resolver order.

| Travel ↓ / Aim → | S 0 | SE 1 | E 2 | NE 3 | N 4 | NW 5 | W 6 | SW 7 |
|---|---|---|---|---|---|---|---|---|
| S 0 | F | F | SR | B | B | B | SL | F |
| SE 1 | F | F | F | SR | B | B | B | SL |
| E 2 | SL | F | F | F | SR | B | B | B |
| NE 3 | B | SL | F | F | F | SR | B | B |
| N 4 | B | B | SL | F | F | F | SR | B |
| NW 5 | B | B | B | SL | F | F | F | SR |
| W 6 | SR | B | B | B | SL | F | F | F |
| SW 7 | F | SR | B | B | B | SL | F | F |

Direct source addressing: index `((travel*8+aim)*8+phase)`; cell origin `((index % 16)*96, floor(index/16)*96)`. P01 is T0/A0 (F), P03 T4/A0 (B), P04 T4/A2 (SL). P02 is T3/A0, but **slide does not use this matrix in the supplied presenter**.

## 3. Full shared-action coverage, including unsupported transitions

| Action / state | Small source | Middle / Large source | What it demonstrates | Still missing or unproved |
|---|---|---|---|---|
| Stand / grounded | 8 aim cells | Same count per size | Standing silhouette, registration, directional views | Idle turning continuity / actual zero-input selection |
| Walk, including `_b` | 64×8 gait cells + base rows | Same count per size | Independent travel/aim, eight visible phases | True displacement clock, ground plants, stop/block/turn transitions |
| Sprint, including `_b` | Separate 64×8 bank + base rows | Same count per size | Distinct sprint poses, not speed-only walk | Cadence caps in actual producer, walk↔sprint phase continuity |
| Jump | 8 base cells | Same count per size | A compact airborne silhouette at a fixed source pivot | Takeoff, descent, physical lift, support surface and landing sequence |
| Float | No named base row | No named base row | Checkpoint documents shared jump-body selection | Actual Float caller, duration/phase transitions and paid-state cues |
| Slide | 8 aim-only base cells | Same count per size | Seated asymmetric poses, including diagonal art | Travel×aim selection; entry/hold/brake/exit; true wall-contact sequence |
| Roll | 8 base cells | Same count per size | A curled silhouette | Rotation/entry/recovery, exact evasion interval and interruptions |
| Air dodge | No named base row | No named base row | Checkpoint documents shared jump-body selection | Actual action mapping, velocity commitment, visual phase / landing |
| Wallrun | No named base row | No named base row | Checkpoint documents reuse of slide body | Wall-facing contact/occlusion, detach and landing; inheriting slide changes is a risk |
| Cast, stationary | 8 base cells | Same count per size | Aim-oriented static hand action | Startup/release/recovery and actual event alignment |
| Cast, moving | Gait legs documented; no blended arm path in supplied presenter | Same documentary limit | The gait source can remain independent of aim | Missing caller, action arm binding, coexistence and priority |
| Hit | 8 base cells | Same count per size | Static hit silhouette | Hit interrupt/return, forced-control priority and body volume through sequence |
| Landing / compression | No base row | No base row | Grounded and jump endpoints exist | Dedicated planted pose, event trigger, compression and interruptible recovery |

The presenter returns an empty result for unsupported state names. A documented upstream alias is not the same as direct support for `frame("float")`, `frame("air_dodge")`, `frame("wallrun")` or `frame("landing")`.

## 4. Five pilot deliverables and acceptance state

| Pilot | Actual material delivered | Small review emphasis | Transfer to Middle / Large | Acceptance |
|---|---|---|---|---|
| P01 forward walk | Eight exact source phases, two swatches, proposed support timeline, offline GIF | Identify alternating feet without color; retain distance clock | Source strips available; reuse rules on original rigs after Small gate | Runtime + human PENDING |
| P02 true diagonal slide | Eight deliberate repeats of S slide for T3/A0; separate existing NE slide comparison | Expose aim-only lookup; travel-aware recline/contact and honest glide | Same current limitation; do not treat larger diagonal art as independent travel support | Runtime + human PENDING |
| P03 backpedal | Eight exact T4/A0 cells and proposed contacts | Face/hands stay S; travel reads N; no reversed-forward shortcut | All sizes have backward banks; preserve per-size bones and phase | Runtime + human PENDING |
| P04 strafe/cast | Eight T4/A2 gait cells, separate E cast cell; proposed hand stages | Legs retain phase while admitted cast releases independently | Upper-action solution must remain shared and bounded | Runtime + human PENDING |
| P05 airborne/landing | Two jump + six grounded source samples; clearly labeled storyboard | Expose missing compression pose; do not infer ground truth from pixels | Dedicated two-foot load on each rig, same event timing | Runtime + human PENDING |

No pilot GIF is a recorded runtime sequence. No whole-body preview generated here is advertised as a new rig-compliant sprite sheet. The existing source cells are provided unchanged in `originals/` with their original manifest.

## 5. Deterministic edge cases

These are acceptance fixtures. **SOURCE-MATH PASS** means a Python reference of the supplied selection math was executed, not that Godot or the missing game caller was tested. Runtime rows remain NOT_RUN.

| ID | Fixture | Expected result / invariant | Execution scope |
|---|---|---|---|
| D01 | Enumerate 8×8×8 gait indices | Unique 0…511; max cell origin (1440,2976); all regions fit 1536×3072 | SOURCE-MATH + image structure |
| D02 | Phase 0, 0.124999, 0.125, 0.999999, 1, −0.125 | Phases 0,0,1,7,0,7 | SOURCE-MATH |
| D03 | NaN/±Inf in moving walk/sprint | Reject frame; base slide does not consume phase | SOURCE-MATH reference only |
| D04 | Zero travel while aim turns | Base row, not gait bank; no distance-based footstep | Bank selection: SOURCE-MATH; clock/footstep: NOT_RUN |
| D05 | (414214,1000000) then (414215,1000000) | S then SE; boundary equality cardinal | SOURCE-MATH |
| D06 | (1000000,414214) then (1000000,414215) | E then SE; negative quadrants reflected correctly | SOURCE-MATH |
| D07 | Zero aim; invalid fallback; stateful zero-vector hold | Static South fallback tested. Stateful hold and actual upstream retained aim must be tested separately | Static SOURCE-MATH; actual caller NOT_RUN |
| D08 | Slide T3/A0 at phases 0…7 | Same South slide cell; travel must not be falsely reported as a source-bank selector | SOURCE-MATH + exact crops |
| D09 | Cast T4/A2 versus walk T4/A2 | Direct cast lookup uses static base; walk uses the matrix | SOURCE-MATH; live cast routing NOT_RUN |
| D10 | Instant aim change during admitted cast startup/release | Body aims immediately; committed shot direction stays recorded; gait never resets | NOT_RUN |
| D11 | Decelerate through zero; reverse; touch wall | No idle phantom steps or retroactive phase catch-up; travel follows realized motion, not held input | NOT_RUN |
| D12 | Landing then next-tick jump/cast/slide | New legal state interrupts cosmetic compression immediately; no extra cost/lock/protection | NOT_RUN |
| D13 | Air correction / teleport / respawn / round reset | No false landing contact, footstep burst or inherited old L/R phase lock | NOT_RUN |
| D14 | Same trace at 30/60/120 render FPS, normal/reduced | Authority/cast/landing events identical; readable cue timing; no extra phase from frame rate | NOT_RUN |
| D15 | Large adjacent to wall while aiming/rolling/sliding | Hurt radius stays19; wall clearance stays18; no pose-derived collision change | NOT_RUN |
| D16 | Heading across 0/7 wrap; both diagonal neighbors | Correct direction classification and depth ordering, no anatomical foot ID swap | Math indices PASS; rig/visual NOT_RUN |
| D17 | Release refused for resource/capacity/cooldown | No fake successful hand-release cue, projectile or phase reset | NOT_RUN |
| D18 | Rapid repeat, Spray action, Heavy wind-up, Bolt release while moving | Per-family real timing, bounded overlay restart policy, no invented shared duration | NOT_RUN |

## 6. Short human drills — proposals, not results

Use current configured semantic controls, not an assumed historical key binding. Capture at ordinary camera scale with debug arrows off, then on for diagnosis. Each drill is about 30–45 seconds. Repeat normal/reduced effects and light/dark real floors after the first clean run.

| Drill | Action | Observer should be able to say | Failure / rollback trigger |
|---|---|---|---|
| H01 · Plant / pass | Two forward cycles; stop; press into a wall; resume; toggle sprint | Which foot supports, which passes; when real motion stopped | Both feet drift indistinguishably; stepping while blocked; changing bank jumps phase |
| H02 · Independent diagonal slide | Travel NE while aim S; brake; repeat NE aim, then SW aim | Travel is NE even with arrows hidden; slide is gliding rather than walking; brake/exit are distinct | Aim masquerades as travel; an exit pose prolongs commitment; wallrun contact breaks |
| H03 · Backpedal chase | Aim at a stationary front target while walking backward and diagonally backward | Face/aim remain forward while the body moves away | Waist flips, feet reverse identities or low-speed reversal snaps through a false forward stride |
| H04 · Lateral hand release | Strafe N, aim E, cast each family; turn the cursor just after commitment | Hand release is visible while stepping continues; shot follows its committed direction | No release pose; feet reset; hand action retargets shot; glow is needed to read the action |
| H05 · Land and act | Jump / Float exit / air dodge / fast fall, then immediately jump or cast on landing | Air, actual touch, compression and renewed action are distinct | Walk pose substituted for impact; false early plant; forced cosmetic recovery; reduced mode hides contact |

Suggested blinded native-view acceptance target: at least **9/10 correct aim+travel identifications** and **8/10 support/action-phase identifications** per pilot, with no regression against matched baseline. These are proposed local review thresholds, not universal perceptual standards or measured scores. When a support phase is fully occluded, assess a short sequence rather than inventing a visible sole in a still. Mechanical invariants must pass regardless of observer scores.

## 7. Gate before expansion

Small five-case source review → original-rig pilot → continuous paid gameplay captures → focused tests → independent human review → Middle → Large → shared template acceptance. Only then consider individual skins. Preserve useful failed comparisons; never turn coverage cells or hashes into “animation complete.”
