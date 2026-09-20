# Review basic size templates before character production

**Current acceptance gate:** inspect generic Small first, then Middle and Large;
named character repairs/additions wait until the user accepts the basic templates.
All8 headings, contact alternation and stable body volume must pass together.
Construction diagrams and a green metadata test are not that acceptance.

| Gate | Reviewer must actually inspect |
|---|---|
| Neutrality first | Same generic humanoid and approved neutral wardrobe, empty hands, no race/element/named-character features; identity-specific review is deferred |
| Size | One58/68/76 body scale; preserved head, torso and limb volume through all poses |
| Construction length/overlap | Hip-knee/ankle and shoulder-elbow/wrist lengths remain anatomically stable; crouches bend rather than compress bones; near/far overlap follows heading |
| Compass | Every one of80 cells is readable without its direction label; nose/head, chest/back, shoulders, hips and toes agree |
| Adjacent directions | S vsSE/SW; E vsSE/NE; N vsNE/NW; W vsSW/NW remain clearly different at native/game zoom |
| Walk contacts | Each A/B pair exchanges anatomical planted legs and opposing arms; same heading and body volume |
| Sprint contacts | The same check for sprint; faster playback is not a replacement for different feet |
| Animation playback | Pause/step native walk and sprint for all8 directions, light/dark backgrounds; no skating, foot teleport, anatomy growth or yaw snap |
| Registration | Actual occupied last pixel y83, common48/84 pivot and empty gutters; do not measure only the resized canvas |
| Portrait | Exactly the top third of occupied south-grounded bounds, full occupied width and ceil(height/3) rows, fitted into32px; no manual portrait asset |
| In-game | Source candidate at50/75/100% zoom, contrasting map backgrounds and real movement; source coverage alone is not final acceptance |
| User gate | User finds the generic Small/Middle/Large result satisfactory before named character art resumes |

Record all80 cell decisions against the exact candidate PNG SHA. A reviewed cell
with ambiguous facing, unstable volume or incorrect support is `held`; uninspected
cells are `pending`. Both block new promotion. Accepted contacts use anatomical
`left` for walk/sprint A and `right` for B. Non-locomotion cells use
`not_applicable`, not fabricated support claims.

The first three generated neutral attempts are held, and the fourth guide-first
pair remains unapproved. Current `guides-v3` and `contact-guides-v2` are fixed-bone
construction diagrams only; `guides-v2` and `contact-guides-v1` are superseded for
bone-length/overlap defects. There are no approved complete neutral runtime PNGs yet. Retain
failed attempts as evidence, never silently relabel them as accepted templates.
An isolated pair is a partial art review: it does not satisfy80-cell admission.
Include a genuine South-grounded source to establish the immutable body scale
before using the shared assembler; never substitute a guessed reference.

Evidence files must be existing, hash-locked review artifacts. Include native
light and dark contact pages plus a recorded native gait review. The receipt must
say whether its reviewer is an agent or a human. Never label agent visual review
as final user acceptance. `validate-character-art-review.ps1` checks receipt
integrity and consistency; it cannot see or certify anatomy, charm or game feel.

Do not mark an entire page approved to hide one known directional defect. Do not
turn off existing working art while a replacement is held. Existing source-playtest
pages may lack this new retrospective receipt; all subsequent promotions need it.
