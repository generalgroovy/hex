# Element color and impact C1

Status: verified local portable, 2026-09-09; Full, rendered review, frozen export,
standalone boot and same-export localhost Farflow passed. Current pointer promoted.
Weekly stop floor is 5% remaining; earlier limits are historical.

[Run FLUX2](../exports/windows-element-impact-c1-p47-20260909/windows/flux2.exe)
with its adjacent PCK, or extract the complete [97.7MB portable ZIP](../exports/windows-element-impact-c1-p47-20260909/release/FLUX2-Windows-x86_64.zip).
Both players need this exact build. It includes the current 29 playable profiles
using three shared body templates. No new installer or publication was performed.

## Player-visible changes

| Element | Main color | Readable native motif |
|---|---|---|
| Earth | Ochre / dark brown | Masonry, fractured blocks |
| Fire | Orange-red | Forked flame, ember edges |
| Water | Saturated blue | Curling water, flowing droplets |
| Wind | Green | Open spirals and directional wisps |
| Ice | Cyan | Angular crystal points |
| Charge | Yellow | Broken bolts and snapping contacts |
| Light | Ivory | Radiant diamonds and measured pulses |
| Dark | Violet | Inward wisps and crescents |
| Steam result | Neutral lilac-grey | Rounded vapor, distinct from blue Water/cyan Ice |

All 36 reaction results preserve their categorical input color ramps and own
pixel motifs, not an averaged muddy hue. 440 existing editable native sequences
were recolored with unchanged pixel rows, frame times, pivots and silhouettes.
The deterministic palette-only command is idempotent. UI and native art use the
same canonical palette; both color and shape communicate element identity.

| Coverage | Before | C1 |
|---|---|---|
| Optional flight trails | 16px radius | 20px radius |
| Terminal ingredients | 24-32px radius | 30-40px radius |
| All reaction radii/lengths | 1.0x | 1.25x; disk area approximately 1.56x |
| Rampart wall | 64 x 36px | 80 x 45px |
| Steam full growth | 90px radius | 112.5px radius |
| Hail moving pulse | 25px radius | 31.25px radius, still clipped to its lane |

These are actual authoritative material/reaction extents, not decorative scaling.
Movement, shots, visibility and presentation consume the same state. Ring-safe
centers scale proportionally. Wider fields are a deliberate balance change, even
though direct damage, phase times, lifetimes, costs, cover health and all entity
caps remain unchanged. Direct projectile hit radii and spell Field/Spray/Beam
reach are unchanged. Rapid remains trail-free; one paid cast has one chemistry
payload. Plain ingredients still cause no automatic damage or status.

Harmless terminal/trail tile opacity is .64/.36 normal and .50/.30 reduced;
active solid material is .82/.64, with translucent veils .54/.40. Formation,
harmless decay, thinning/gaps and zero-opacity expiry remain source-derived.
No screen flash, separate range rings or extra particle banks were introduced.

## Verification and limits

- Focused: 9 suites / 138,129 assertions; no failures or stderr.
- Pack reconstruction: 20,484 assertions; 474 sequences / 1,960 frames / 3 pages;
  decoded RGBA budget unchanged. The eight allowlisted PNGs total 136,713 bytes,
  only 129 more compressed bytes than M1.
- Actual-campus review: 146 frames through production drawing, all eight Bolt
  elements, Rapid exception, paid protection/casting, three sizes, Rampart
  lifecycle and all 36 paid Rapid pairs (formation/active/reduced). No injected
  deposits; drawing leaves authoritative world hashes unchanged.
- Linked recipes without extra supporting deposits truthfully show their
  unconnected state; pair creation is not a claim that every linked tactical
  configuration received a human playtest.
- Full: 95 suites / 549,869 assertions; zero failures/warnings/stderr. All 3,083
  frozen runtime/test/package files remained unchanged through strict Windows
  export, PCK verification and isolated standalone boot. Exact same exported
  Farflow host/join, HELLO, reconciliation, round, late-join, rematch and stewardship
  passed at 120Hz on localhost UDP24973; all three stderr logs are empty.
- Physical two-PC Internet play, human feel/charm/accessibility acceptance and
  sustained rendered 120FPS remain open. The earlier W4 performance miss is
  not erased by these correctness checks.

## Try it after delivery

Equip any element's Bolt to compare its narrow trail and broader landing matter.
Use two Rapid casts at the same point to isolate a reaction without trail mixing;
try Fire+Fire, Fire+Water, Earth+Earth, Water+Ice and Wind+Ice. Compare normal and
reduced effects. F4 reports the actual result, active effects, timing and counters.

Next: human color/coverage playtest, then the existing M2 Ice/Charge mirror pilot
queue; race skins/map expansion remain separate, not silently bundled into C1.

Owned test processes are closed and preferences isolated/restored. Environment
policy blocked removal of the redundant ignored review/final capture folders;
47.2MB remains there, recoverable in principle from the retained evidence after
identity verification. No original art, previous builds or failed evidence was
deleted, and no cleanup bypass was attempted.

[Immutable build receipt](evidence/windows-element-impact-c1-p47-20260909/checkpoint.json)
pins the frozen source and all payload hashes. PCK SHA256:
`71e8f209c6d1ee05ffbb4fc7b3d0633d884375a5b12b6b2f89cc81cfaa561e28`.

![Actual paid Fire terminal and trail](evidence/windows-element-impact-c1-p47-20260909/inputs/capture/fire-bolt-terminal.png)
![Actual paid Steam with larger material coverage](evidence/windows-element-impact-c1-p47-20260909/inputs/capture/pair-310-steam-active.png)
