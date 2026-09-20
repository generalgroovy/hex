# Gameplay S3 strength-capture candidate

Status: **CANDIDATE / NOT RUN**. This directory is ignored by Godot and contains no live runtime change. The source was forked from `tests/visual/capture_hex_court.gd` at SHA-256 `030bc64652867dd6b006811bf6c9495ba6acc883ba2a7e66d3ae40f7a2aeb047`.

Frozen candidate capture SHA-256: `55bfd043aacf603f2e1fe9d926eda4adc96524933a25aefb02fdca5b51ef06f8`.

## Added proof slice

The candidate retains the existing 31 capture labels and appends six captures in one fresh Hex Court scene:

- `heavy-strength-full-15.png`
- `heavy-strength-full-15-reduced.png`
- `heavy-strength-10.png`
- `heavy-strength-10-reduced.png`
- `heavy-strength-7.png`
- `heavy-strength-7-reduced.png`

Before the Heavy exists, actor 3 pays for the real slot-2 Fire Bolt (wire 145, strength 5) and lets it terminate as its 34 px ground disk at `(470, 480)`. Actor 4 then pays for the real slot-8 Fire Spray (wire 154, strength 3), producing its full authored 380 px terminal sector from `(650, 480)` east to `(1030, 480)`. The separated ground footprints are both asserted to retain their complete 600-unit deposited ledgers.

Actor 1 then pays for the real slot-3 Water Heavy (wire 181, strength 15) and fires east. Its center path enters the Bolt disk once, leaving strength 10, then enters the later Spray sector once, leaving strength 7. All three stationary fixture casters share team 1 so player-hit resolution cannot cut the lane short; persistent field interception still uses the ordinary Hex Court resolver.

The candidate asserts current authored speeds and collision radii, the Heavy 84 px terminal radius, the Spray range/cone, and compiled fixed-resource costs `18000/6000/12000` (18/6/12 display Flux). It also checks field existence before Heavy release, exact field source IDs and wire order, two distinct field contacts, the 15 -> 10 -> 7 moving ledger with no per-cell or per-tick repeat drain, and terminal matter conservation. The three 600-unit paid ledgers must end as 1,520 consumed plus 280 deposited Water. No projectile, ledger, clash, deposit, or resource value is fabricated.

At each strength change, the script first performs an awaited non-recorded draw at the clash tick so `HexCourtPresenter` discovers its new target. It then advances one simulation tick and performs one awaited draw six times. Before the recorded frame, it reads the presenter's actual per-projectile cache and asserts that its interpolated size equals the live Heavy sprite size `32 * sqrt(remaining / 15)`. The separate 84 px value remains the Heavy terminal gameplay radius. The reduced frame uses the same unchanged authority state and the presenter's immediate reduced-motion path.

`capture-receipt.json` gains compact per-frame projectile strengths and live court cast ledgers. Its `strength_scenario` section records fixture placements, both pre-existing field footprints and ledgers, every moving Heavy position/strength/quantity observation, both field clash events, contact geometry, paid cast costs, cached-size settling, and terminal conservation.

## Root integration and validation

1. After the S3 presenter/runtime integration is frozen, copy `capture_hex_court.gd` over `tests/visual/capture_hex_court.gd`. Do not copy `.gdignore` or this README into live test paths.
2. Register no new test script; this remains the existing standalone visual capture entry point.
3. Run it only through the root-owned serialized Godot wrapper with a fresh `--output=res://.godot/hex-court-<run-id>` directory. The script itself rejects an existing output directory.
4. Require exit 0, `PASS: hex court capture 37 frames`, 37 PNGs, and a passing receipt. Check the six new frame records for strengths 15, 10, and 7 in both motion modes; check `strength_scenario.clashes` has two `contact_kind: field` events matching Bolt 5 then Spray 3, and terminal conservation is true.
5. Root/Astra should visually compare each normal/reduced triplet for monotonic projectile shrink, unchanged Water Heavy silhouette, visible quiet collision envelope, and no skipped second field collision. Native captures establish renderer output only; they do not establish human acceptance or rendered-performance capacity.

Rollback is one file: restore `tests/visual/capture_hex_court.gd` to the archived pre-S3 source. Generated `.godot/hex-court-*` evidence remains separate.
