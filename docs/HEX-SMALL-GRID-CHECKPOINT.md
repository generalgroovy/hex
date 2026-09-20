# H.E.X. smaller-grid checkpoint

Status: **LOCAL PLAYTEST CANDIDATE; MULTIPLAYER LIFECYCLE FAILED**, September 21, 2026.
This is a source checkpoint, not a friends-ready release or performance certification.

Authoritative checkout: `C:\Users\sende\Projects\hex`.
Public source repository: [generalgroovy/hex](https://github.com/generalgroovy/hex),
branch `main`; Git records the exact publication commit.
Runtime: **p55-c7b7694f8d23**; source SHA256
`c7b7694f8d23a6ca1c7b069729760302a6c11a7ef6f6ff53e16548a832c937b5`.

## Changed and preserved

| Contract | This slice |
| --- | --- |
| Game title | H.E.X.; ASCII launcher and package filenames stay `hex` / `HEX` |
| Hex width | 48 px face-to-face, previously 64 px; 25% narrower |
| Eligible Wellspring cells | 2,766, previously 1,493; existing cap 4,096 |
| Fixed geometry | Half-width 24,000; half-height 27,712; row pitch 41,568; column pitch 48,000 |
| Unchanged | Map bounds/obstacles, character visuals/hurtboxes, 18 px common wall clearance, costs, authored damage coefficients, world-space spell radii |
| Coverage | Radius selects whole cells; paid material is shared across selected cells, never multiplied |
| Compatibility | Protocol 55; SessionSnapshot 21 / HexWorldSnapshot 3 / chemistry 3 / envelope 1 unchanged |
| Visibility | Completed relative 360/ 720 sight work included; opaque buildings and active solid hex cover occlude other actors and attached cues |
| Preferences | Existing `Godot/app_userdata/FLUX 2` preserved; Flux remains a resource |

Fire/Steam pressure currently uses per-cell material density. Finer coverage
can spread the same finite budget thinner; unchanged coefficients do not mean
identical damage. No hidden balance compensation is introduced. Measure
density-normalized balance as a separate slice before further expansion.

## Fresh verification

| Check | Result | Evidence |
| --- | --- | --- |
| Focused geometry v3 | PASS: 9 suites / 62,515 assertions, zero stderr | `receipts/hex-small-v3.json` |
| Focused chemistry/branding v5 | PASS: 7 suites / 7,741 assertions; ten first-four pairs, both orders, three paid trigger paths | `receipts/hex-small-v5.json` |
| Unfiltered Full v3 | PASS: 157 suites / 803,865 assertions, zero failures/stderr; import, asset audit, 120 Hz configured boot; 257.342 s | `receipts/hex-small-full-v3.json` |
| Native gameplay | PASS: 7 reviewed frames; actual Water/Fire Bolts at Nexus without a dummy, Steam formation/contact, normal/reduced coverage | `native/receipt.json` and PNGs |
| Windows portable | PASS: exact PCK/source identity, actual native EXE launch, safe close, zero stderr | `package/receipt.json` and logs |
| ZIP audit | PASS: all 7 entries match tested payload by SHA256; exact entry count, unique names, flat paths | `package/zip-audit.json` |
| Same-export localhost lifecycle | **FAILED**: unchanged 300 s deadline; 300.939 s including cleanup | `network/receipt.json` and all three peer logs |
| Final source/document checks | PASS: current-state invariants, pinned engine and runtime identity; no runtime change after Full | `final-current-state.json` |

All evidence paths in the table are relative to the
[curated evidence directory](verification/hex-small-grid-20260921/).
Both successful and failed attempts are retained. Earlier failures exposed
old-grid coordinates, off-court fixtures and stale title/protocol expectations;
test oracles were corrected without changing production damage/movement/resource
coefficients or removing suites. The invalid v4 suite ID ran no suites.

The native capture recorded simulation step p95 **885 microseconds** in its
small solo scenario. This is not dense-host, rendered-frame or 120 FPS evidence.

### Multiplayer limit

The packaged host and clients connected, reconciled movement, entered the first
round, reconnected the same actor and admitted a late spectator. They returned
to Hearth, but did not complete the second-round handoff and stewardship checks
before the unchanged deadline. All three stderr files are empty; timeout still
means **failed**, not passed with a warning.

Host trace samples show roughly 0.4-0.6 seconds spent capturing/sending a
snapshot. This indicates severe snapshot/topology pressure; it is not a new
aggregate profile or proof of the only bottleneck. The prior 64 px source
lifecycle passed in 256.926 seconds; different run/build conditions mean this is
not a controlled performance comparison. Historical dense 120 Hz results were
already red. Current multiplayer should be treated as experimental.

No timeout increase, authority reduction or release promotion was used to hide
this failure. Snapshot/topology optimization on the identical 48 px workload is
the first remaining engineering slice.

## Run and share locally

Open:
`C:\Users\sende\Projects\hex\exports\hex-small-grid-20260921\windows\PLAY-HEX.cmd`

Or run source:

```powershell
Set-Location C:\Users\sende\Projects\hex
.\scripts\run.cmd
```

Local portable ZIP:
`exports/hex-small-grid-20260921/HEX-p55-c7b7694f8d23-Windows-x64.zip`
— 98,253,684 bytes (98.3 MB). Extract completely; keep `hex.exe` beside `hex.pck`.
It is available for local solo playtesting, not certified friends-ready delivery.

| Artifact | SHA256 |
| --- | --- |
| PCK | `9c1b0041ca626ebfca890ae6063b606abe6a7a5bad2783db48d263406b83568e` |
| ZIP | `69d5db01b19cc7f22d6c20e748c52ddc49b59b005eeadb57393e8c9c3dfd1a60` |

Previous verified local sight portable:
`exports/hex-vision-20260920/windows/PLAY-HEX.cmd` (protocol 54).
Do not mix protocol 54 and 55 clients. Original FLUX, saved profiles, assets and
fallback packages remain untouched. `docs/current-checkpoint.json` retains the
older P48 delivery in the original FLUX checkout; it was not promoted here.
Portable binaries remain local, not in Git or a new GitHub release. No installer
or updater was produced.

## Human test focus

1. Compare finer boundaries in ordinary Wellspring and near wall edges.
2. Cast Water and Fire at the same point without a dummy. Cross active Steam in
   normal/reduced effects; selected whole cells, not the generating circle,
   determine contact. Compare useful pressure as well as visual coverage.
3. Form Earth cover, move along all faces, jump/wallrun and wait for expiry.
   Corridor clearance and ordinary character movement should feel unchanged.
4. Aim while moving, switch sizes, open Spell Loom and verify saved controls.
5. Record the build ID with issues. The [five-minute route](HEX-PLAYTEST.md)
   covers the included sight correction too.

![Actual 48 px whole-hex Steam in Wellspring](verification/hex-small-grid-20260921/native/ 03-steam-normal-1280x720.png)

Physical two-PC/Internet testing, human feel/balance/art acceptance and fresh
dense/rendered performance certification remain open. Thirty playable profiles
still use three shared size templates, not thirty finished character skins.
