# Hex court projectile atlas candidate

`export/projectile_atlas.png` is a deterministic, lossless RGBA atlas for the
isolated H0/H2 hex-court presenter. It contains four presentation silhouettes
(`rapid`, `bolt`, `heavy`, `spray`) across the eight stable element wire colors.
Every frame is 24x24 pixels, ordered by element wire 1-8 in columns and by family
in rows. Rapid is deliberately compact and has no flight trail.

The batch is presentation-only. It does not define projectile radius, damage,
strength, occupied terrain, collision, timing, or reaction state. Regenerate it
with `py source/bake_projectiles.py`; the script writes the PNG and manifest with
a SHA-256 over decoded RGBA pixels. `.gdignore` prevents automatic Godot imports.
The accepted runtime copy belongs at
`res://assets/sprites/hex_court_v1/projectile_atlas.png`; `HexCourtPresenter`
performs an explicit lossless decode there and has a code-drawn fallback for
packaging profiles that omit the candidate asset.
