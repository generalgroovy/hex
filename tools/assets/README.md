# Retained historical visual asset tooling

These coupled tools retain provenance and validation for older committed assets
that still have runtime, fallback, or archive consumers. They are not the current
character or magic production contract. Current direction and fixed-scale,
shared-pivot rules live in `docs/VISUAL-DIRECTION.md` and `docs/SPRITE-PIPELINE.md`.

The legacy validation entry point remains available:

```bash
python tools/assets/validate_visual_assets_v1.py
```

The validator checks the historical dimensions, counts, archive integrity and
recorded hashes. Existing generators can overwrite retained PNGs, registries,
maps and documentation; do not run them as part of routine builds or current
art production. Preserve authored sources and review exact outputs first.

Obsolete automatic generation and README-rewriting workflows were retired during
the current-contract cleanup. Current Windows CI only validates the game; it does
not regenerate art or push generated changes. The active pixel magic pack remains
under `art_batches/pixel_v1/magic`, with its own manifest and validation contract.
