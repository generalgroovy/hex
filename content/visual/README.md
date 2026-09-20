# Visual content registry

`visual_asset_registry_v1.json` is the runtime-facing index for generated visual
assets. `visual_asset_hashes_v1.json` records committed byte sizes and SHA-256
hashes for reproducibility checks.

The registry is validated by `VisualAssetRegistry` and the headless
`test_visual_asset_registry.gd` suite. Presentation entries do not confer
simulation authority.
