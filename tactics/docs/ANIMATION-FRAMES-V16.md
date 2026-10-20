# Character frames and elemental cels

This presentation revision retains rules and room protocol 16. Combat outcomes, movement paths, simultaneous casting, interception times, and progression are unchanged.

## Character artwork

Each of the 30 canonical characters has a separate transparent atlas: six columns by eight rows, 128 pixels per cell. The 48 drawings comprise front/profile/rear movement, front/profile/rear casting, impact, and defeat, with six poses per sequence. Left-facing views mirror the three painted views. Impact and defeat use the front view. The final defeat frame remains grounded.

Artwork was generated with the built-in image generation tool from the repository's existing character references. Exact prompts, source paths, identity constraints, performance directions, and inspection notes are retained in `character-animation-prompts-a.json` and `character-animation-prompts-b.json`. Original champion atlases remain available for portraits, loading fallbacks, and historical clients.

`scripts/pack-character-animation.mjs` imports complete connected alpha islands before assigning them to the declared grid, preserving limbs that cross nominal cell boundaries. It removes translucent matte noise, uses one uniform nearest-neighbour scale per character, and places the feet at y=104. Per-frame bounds, source hash, pixel hash, and any orientation correction are recorded in `animation-assets/`. The optional third CLI argument identifies one `row,column` cell to mirror; Juul I Yaina uses `2,4`.

`ChampionFrames` advances actual atlas frames using stepped background positions. It does not stretch or rotate the character. Movement follows the existing route and changes painted view at each waypoint. Every cast's fourth frame releases at 400 ms; a late-loading atlas catches up to the current action rather than restarting its anticipation. Reduced motion retains readable static action poses.

## Element artwork

The six base and six advanced materials use 48 projectile cels and 72 impact cels. Steam has six formation cels; persistent Fire and Steam have eight small field cels. Advanced materials retain the exact palette of their parent element. Earth breaks into rocks, Metal rises in rigid blades, Air opens into curls, Storm forms a funnel, and Steam blooms and breaks apart.

Each cel uses at most six batched SVG paths on a fixed pixel grid. The main impact appears at its centre; secondary affected cells retain quieter footprint marks. Launch remains 2200 ms into the exchange, ordinary arrival 4800 ms, and meeting-point effects use the resolver's actual flight fraction.

## Review and reproduction

`/animation-review` displays all characters in groups of six, with live playback, facing selection, and permanent frame strips. Its Elements view shows the production cels and palettes. It is a review route and adds no controls to the battle screen.

Relevant automated coverage: `character-animation.test.ts`, `character-craft-v16.test.ts`, and `element-effect-frames.test.ts`. Asset coverage checks all 30 characters, 48 unique frames per atlas, complete source margins, the packed cell bounds, exact cast release, looping and held poses. Effect coverage checks distinct shapes, bounded path counts, frame windows, reduced field scale, and unchanged interception timing. These checks establish asset and timing correctness; visual inspection and actual combat playback are separate checks.
