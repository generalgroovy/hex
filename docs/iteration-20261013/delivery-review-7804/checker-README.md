# Prepared 7804 delivery review

This is closing evidence preparation only. No new gate has been executed by this directory. `review_delivery.py` is byte-identical to the independently reviewed `aa83565d5628860c627b8adeba28b3acaa76b8f1242de11a7b11391ad60ccabe` checker. The original 500be checker and pins remain untouched.

`pins.json` fixes the actual `p61-7804a23eb300` identity and the same 291 selected source/dependency paths, freshly hashed. The current `tests/run_all.gd` preload array independently yields the same ordered 265 suite IDs. All suite bodies are among those pins. `provenance.json` records the five changed pins and the original/current hashes. These selected pins do not replace root's complete 3,444-record runtime-identity gate.

The complete Full run must finish successfully before packaging. From `C:/Users/sende/Projects/hex`, the reviewed commands are:

```powershell
& .\scripts\package-hex.ps1 -RunId 'hex-checkpoint-20261013-7804' -PixelCast

& .\scripts\verify-hex-portable.ps1 `
  -BuildDir 'exports/hex-checkpoint-20261013-7804' `
  -ExpectedBuildId 'p61-7804a23eb300' `
  -FallbackBuildDir 'exports/hex-iteration-20261013-500be' `
  -Standalone

& .\scripts\verify-terrain-pack.ps1 `
  -PackPath 'exports/hex-checkpoint-20261013-7804/windows/hex.pck' `
  -OutputDirectory '.godot/iteration-20261013/terrain-pack-7804-a'

& .\docs\iteration-20261013\portable-lifecycle-harness\verify-final-portable-lifecycle.ps1 `
  -BuildDir 'exports/hex-checkpoint-20261013-7804' `
  -OutputDirectory '.godot/iteration-20261013/portable-lifecycle-7804-a' `
  -ExpectedBuildId 'p61-7804a23eb300'
```

Run them serially, and proceed only after each previous gate passes. Each output must be fresh. `-PixelCast` implies CharacterArt and is required by the portable verifier's launcher and instruction checks. `-Standalone` selects the current 18-check archive contract. The fallback is the qualified 500be package, preserved byte-for-byte.

The lifecycle helper remains exact SHA `f1527a16db7b90c6f771a8a942ceaf30c78d5922609aff765d72c2f6f5c3cd0e`. It runs Hearth/Garden/Fire/Mantle/reopen in one fresh isolated profile, with normal owned-window close after 20/25/45/45/20 seconds. Its visible windows still accept ordinary input. Extra input contaminated previous attempts; preserve any failed receipt and do not waive the twelve-outcome gate. The helper alone omits foreign or malformed capture records from its matching-wire count; the unchanged independent checker below rejects these and repeated/backward capture ticks. Report actual accepted and refused counts explicitly. This is lifecycle and persistence evidence, not focus, FPS, physical-input, audio-quality or earned-save recovery acceptance.

Only after all five lifecycle cases finish successfully, run the new checker against the new receipts:

```powershell
& 'C:/Users/sende/AppData/Local/Python/pythoncore-3.14-64/python.exe' `
  '.godot/iteration-20261013/delivery-review-7804/review_delivery.py' `
  --repo 'C:/Users/sende/Projects/hex' `
  --full '.godot/iteration-20261013/ui-integration/full-7804-a.json' `
  --build 'exports/hex-checkpoint-20261013-7804' `
  --fallback 'exports/hex-iteration-20261013-500be' `
  --terrain-directory '.godot/iteration-20261013/terrain-pack-7804-a' `
  --lifecycle '.godot/iteration-20261013/portable-lifecycle-7804-a/receipt.json' `
  --lifecycle-helper 'docs/iteration-20261013/portable-lifecycle-harness/verify-final-portable-lifecycle.ps1' `
  --output '.godot/iteration-20261013/delivery-review/runs/checkpoint-7804-a'
```

The output stays under the checker's existing admitted `delivery-review/runs` directory so no logic change is needed. A failed or existing output is retained; a later retry requires a fresh name. Full inventory/raw sums, all exact delivery check names, payload/ZIP/PCK linkage, isolated terrain mount/pixels, actual finite outcomes, shared preference/backup observations and final bytes are independently reviewed. Missing fields fail closed. No success from the older 500be receipts is inherited.

`archive-force-add-inventory.json` is a separate read-only closing inventory of 43 manifest-declared source files in reviewed archive `.godot` subdirectories. Only untracked files need force-add; root reports ten remap files already tracked and owns final index checks. This inventory does not stage or modify an archive.
