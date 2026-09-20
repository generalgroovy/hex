# Offline magic study viewer

Open `index.html` in a browser. No installation, server, package download, external connection, settings file, or game launch is needed. The page uses local classic scripts and relative PNG paths, including the packer's optional `../packed/manifest.js` metadata wrapper; it never fetches a remote resource.

| Review control | Meaning |
| --- | --- |
| Eight-element grid | Fire, Water, Earth, Wind, Charge, Ice, Light, Dark; missing files stay explicitly missing. |
| Raw / Packed | Original 4 × 2 generated source cells, or packed 128 × 64 sheets with eight 32 × 32 cells; packed is selected automatically when its metadata is present. |
| 32 / 64 / 128 px | Exact CSS-pixel frame size in packed mode; raw cells retain their source aspect ratio within that size. Nearest-neighbor rendering, no per-frame fitting or alpha inference. |
| Pause / Space | Freeze the absolute 120-tick-per-second study clock. |
| Step frame / Right arrow | Pause, then advance to the nearest next frame boundary among the displayed elements. Different elements can have different durations. |
| Restart / R | Return to age zero. |
| Speed | Inspect at 0.25×, 0.5×, 1× or 2×; rendering refresh rate does not define simulation age. |
| Matte / Grayscale | Inspect silhouettes against dark or stone backgrounds, or without hue. Neither control edits source pixels. |
| Reload files | Reread local PNGs and packed metadata after a pack is rebuilt. |

Packed timing comes from each asset's validated `duration_ticks` at 120 ticks/second. Raw-mode defaults are Fire `[8,10,8,10,8,10,8,10]` and ten ticks per frame for other elements. These are **study timings, not changes to game mechanics**. Metadata layout flags are shown on each affected card; raw row drift is not silently corrected by this viewer. The packer may apply an explicitly approved fixed row translation, recorded in its metadata, without changing the raw source.

This batch ends after the **eight basic elements**. Steam and all other first-level interaction art are not started here; the disabled interaction stage and exact 36-pair queue record that stop boundary. Reduced-density review is also disabled because no such study variants were supplied. Existing game reaction code and production assets are not changed by the viewer.

Generated source studies are **not production-approved sprites**. Inspect motion, root alignment, cropped edges and palette clarity at actual 32 px; a successful test of the viewer is not artistic acceptance of the source art.

## Verification

Run `node test-study-model.js` and `node test-viewer-smoke.js` from this directory, or pass their absolute paths to Node. Tests cover absolute timing, looping boundaries, pause/speed/step continuity, cell geometry, metadata safety, and all 36 reaction names/pairs against the current read-only simulation source. The smoke test executes page code with a deterministic DOM/canvas test double and reads real local PNG headers; it is **not browser rendering or artistic acceptance**. Browser visual inspection remains separate from those deterministic checks.
