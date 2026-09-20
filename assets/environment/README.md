# Runtime environment assets

`sanctum_g2/runtime_kit_v1/` contains the first repository-native FLUX 2 pixel
environment modules. They are generated deterministically by
`scripts/generate_sanctum_runtime_kit.gd`; their source and output hashes,
virtual-pixel scale, pivots, import policy, authority boundary and budgets are
bound by `content/assets/sanctum_runtime_kit_v1.json`.

The kit uses original geometric pixel patterns and no third-party or historical
character-sheet pixels. It targets compact Game Boy Color-era top-down
readability while copying no sprite, tile, map, palette, character, symbol,
animation or trade dress from an existing game. Historical FLUX character
boards remain concept references only.

Runtime approval means the modules may be evaluated in G2 presentation. It is
not release approval. The repository currently has no top-level distribution
license, so the manifest keeps the distribution-license gate explicit.

Regenerate from the project root with:

```bash
godot --headless --path . \
  --script res://scripts/generate_sanctum_runtime_kit.gd
```

Rendering pixels never define collision, elevation, traversal, material,
navigation, reset, replay or network authority.
