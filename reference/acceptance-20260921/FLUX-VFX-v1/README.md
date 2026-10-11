# FLUX VFX v1 — review package

Open **`preview-standalone.html`**. It contains all imagery, data and code needed for the offline viewer. `index.html` is the smaller equivalent that uses the adjacent `assets/` and `preview/` folders. The integration document links require the extracted package beside either entry point.

Start with `HANDOFF.md`, then compare the native paintovers, lifecycle sheets, hot/cool Steam and coverage boards. Two lossless animated PNGs in `boards/` show a 6.4-second reference fixture. They are offline component animations, not gameplay footage.

Material definitions are **proposals, not validated drop-in code**. Runtime integration, performance and human acceptance are **NOT_RUN**. See `evidence/verification.json` for checks actually executed.

## Rebuild / verify

A current Chromium browser alone is enough to view the prebuilt package. Rebuilding pixel assets requires Python + Pillow; the browser checks/motion export additionally require Playwright + Chromium. Node is used for pure geometry/semantic tests. Versions used here are recorded in the verification receipt; no development dependency is required to open the preview.

```text
python tools/build_assets.py
python tools/build_restoration.py
python tools/embed_data.py
python tools/build_standalone.py
python tests/test_assets.py
node --test tests/test_geometry.js
python tests/capture_previews.py --capture
python tools/render_motion.py
python tools/check_package.py
```

The tools write only owned package outputs. Rebuilding changes hashes; regenerate the manifest with `python tools/make_manifest.py` afterward. Direct `file://` navigation was blocked by sandbox browser policy here; the capture tool records that failure and uses self-contained content injection. It does not disable browser policy or claim a successful file launch.

No repository edits, installation, publishing, commits, pushes or checkpoint promotion are performed by this package.
