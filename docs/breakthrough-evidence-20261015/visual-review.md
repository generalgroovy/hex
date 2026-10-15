# Independent native UI review — 15 October 2026

**Decision: accept the captured Circuit and map layouts at the declared fixture scope.** Experience independently viewed all eight `capture-c` PNGs using the image viewer. No clipping, overlapping controls, or hidden required action was found in these states. This is a prepared native UI review, not a full game capture, physical-input trial, unfamiliar-player study or performance measurement. No engine was launched by this reviewer.

## Inputs and admission

Root produced `.godot/iteration-20261015/breakthrough/runs/capture-c/`. Its log ends with `PASS: 8 native UI fixture captures; not gameplay, human input or performance evidence`; the adjacent stderr file is zero bytes. Every PNG header independently reports 960 × 540. The helper explicitly sets `root.content_scale_size = Vector2i(960, 540)` and draws at logical 960 × 540 / scale 1 or logical 480 × 270 / scale 2.

The helper loads the real ability/champion catalogs, uses the actual Circuit model and panel, and opens the actual map panel/layout. Its victories, health, cast counts and save states are prepared presentation values. The flat background is intentional fixture isolation, not evidence of an absent game world. Exit status and the actual launcher execution remain root-owned evidence; this review independently read the terminal log, files, source and pixels.

The earlier `capture-b` remains negative fixture evidence. Its stage-2/scale-2 image was also inspected: the content occupied only 720 × 405 of the 960 × 540 image, leaving unused gray space. It cannot establish the requested 960 × 540 content-scale acceptance. No previous images or logs were overwritten or discarded here.

## Visual findings

| Captured state | Independent finding |
|---|---|
| Stage 2, scale 2, learned but unsaved | Full Oh Tipi / Steam Fuse reward line is visible. Temporary slot 1 and unchanged saved weave are explicit. Next with learned spell, ordinary Next, Leave and Retry progress save have distinct rectangles. The save action and footer remain inside the panel. No save success is implied. |
| Stage 3, scale 2, completed route | Full completion heading, 133.53-second prepared encounter total, normalized health and Penumbra Rebound name fit. Try, Replay and Leave remain distinct. The wording states that Try opens the Range and replay starts a fresh Circuit. |
| Stage 1, scale 2 | Arcstorm Rapid and the temporary-slot explanation fit. Primary learned-next selection is visually prominent while ordinary Next remains visible. |
| Map, scale 2 | One selected destination, `1 / 13` pager, Details text, Travel and Close are legible and separate. Both pager arrows sit above Details/Travel with a visible gap; the earlier bottom-stripe collision is not present visually. |
| Three Circuit states, scale 1 | All titles, real signature names, body lines and actions fit. Default body text is compact, with a large unoccupied background around the centered panel; no clipping was observed. Scale 2 supplies the intended larger reading option. |
| Map, scale 1 | Eight named rows, `1 / 2` pager, overview pins, destination detail and Travel fit. The lower pager and detail/travel bands are separate. |

These captures show the current first map page only. They do not show a pointer click, keyboard/pad movement or actual page changes. Those behaviors belong to the input/geometry suites and later physical-device acceptance. The screenshots also do not cover timeout/defeat/backup-recovery copy, all possible resource values, screen-reader support, moving combat background, or every display size. No broader accessibility or human-readability certification is inferred.

## Test-only fixture correction and separate paid integration evidence

Current `tests/unit/test_signature_circuit.gd` SHA-256 is `7432899ad3b30c029c953eb698fd9548f85b020c46ffcfa5bce34b683e01a538`. Removing the single `complete.can_next = false` line and replacing the new exact completion-text assertion with its previous substring assertion reproduces predecessor `58d06e200064b78387ee84f7178f2195a2c42727b29eb818b4ff4126e1963ab1` byte-for-byte. The model's real complete state has no next rival; the old prepared clone incorrectly retained `can_next = true`. This is a fixture-state repair and stronger expected-text assertion, with no production model/panel change or removed assertion.

The independently read `integration-a/tests.json` is passed: `signature-circuit` **488 assertions / 0 failures**, `signature-circuit-integration` **60 / 0**, total **548 / 0**, stderr **0**. Its raw suite log hash matches the receipt and reports both selected suites passed. The integration source exercises three actual controller-created rival encounters, real paid counterplay/rewards, previous learned-spell payment and release in following encounters, Range entry and normal weave restoration. This is distinct from the prepared capture values. Progression is deliberately memory-only, so these results do not prove durable save/reopen. Full, packaging, current presented-frame performance and human play retain their own gates.

The earlier `circuit-b/tests.json` remains a failed overall run with the single prepared completion assertion failure, despite its passing map assertions. It is not silently replaced by the later passing receipt.

## Frozen readback identifiers

- `.godot/iteration-20261015/breakthrough/capture.gd`: `bd4f8fd36d72aa0da46a84546c4a3312931e1bfa6f764bb052e2e4330c6dbd52`
- `src/presentation/signature_circuit_panel.gd`: `d06f71ecd467d8f1e7e893fc0ca816791e849c5501982fc963f0fd596c29a0c2`
- `src/app/signature_circuit.gd`: `acac15eb5206b3877a760092ccc7c08d36591453d88db5839018abfb339b6bdd`
- `src/presentation/wellspring_map_panel.gd`: `ac977a81756cf0a1c319e3683faa70108a01d1e215aa135a853d6deea4a2fb89`
- `.godot/iteration-20261015/breakthrough/runs/capture-c/capture.log`: `64493910c41007aaad31d406f23e6cd34732d24f21cb7099078c62de8dedc685`
- `.godot/iteration-20261015/breakthrough/runs/capture-c/capture.log.err`: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- `.godot/iteration-20261015/breakthrough/runs/integration-a/tests.json`: `32235ec37743bc036eebed53f5d08be0c92677d71d3c341793e3c02c1a877470`

| PNG | Dimensions | Bytes | SHA-256 |
|---|---|---:|---|
| `circuit-1-scale-1.png` | 960 × 540 | 31,344 | `c1d2ce9430a34d83cd9b1d595a988ef8129e051ca4592d7e0ad2d0234c16f2c2` |
| `circuit-1-scale-2.png` | 960 × 540 | 33,970 | `668ae0ef615650e4dc0afc32e5dba9aba9e56c7a7a7a64f81d70d4964d8dd317` |
| `circuit-2-scale-1.png` | 960 × 540 | 33,513 | `ec9d685f378d8e3f44b1174d3da6ba99ff49db7fc8ce4325df5ff017e5733a30` |
| `circuit-2-scale-2.png` | 960 × 540 | 36,772 | `bc06493c82d7e73eba456dcc74b5231d3d85bab3ef3bec934b0730b1ff186c94` |
| `circuit-3-scale-1.png` | 960 × 540 | 33,490 | `f33de5685085cd1952c43633be6b0e13e4e53519c6a592542361237afeebf816` |
| `circuit-3-scale-2.png` | 960 × 540 | 36,221 | `92b4741eaef8757546c9ac1be0d8666a6b9be5b60d08dbb6cae52a86604ed741` |
| `map-scale-1.png` | 960 × 540 | 51,458 | `9de313a1d5cd513d7acb404c53756f52f1ab713cfbaa4814f489d38d0cca6fdf` |
| `map-scale-2.png` | 960 × 540 | 30,735 | `c54974f31f703eb44a58cafc4a16e90bd8e5d11289c34fb6452af7437e447da1` |
