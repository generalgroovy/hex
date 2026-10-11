# Eight-element palette / silhouette / motion table

**PROPOSAL.** Base colors exactly retain `content/visual/visual_language_v1.json` from this packet. The phases below are a visual vocabulary, not authorization to change gameplay. Respect the live `danger` flag. Steam is a reaction, not an extra element.

| Element (internal ID) | Dark / body / highlight | Silhouette | Motion | Formation → active → harmless expiry |
|---|---|---|---|---|
| Water (`water`) | `#15366e` / `#1f70f2` / `#57baff` | Hooked wave crest; broad rounded underside | Local rolling curls, not directional force arrows | Gathering ripple → Coherent flowing reagent; no damage warning → Flattened, desaturated wet trace |
| Earth (`earth`) | `#4a2d1a` / `#b47c36` / `#edc179` | Three squat chipped blocks; no pillar for loose ingredient | Settle, hold, one short crumble | Gathering grains → Stable mineral cluster → Small falling chips |
| Fire (`fire`) | `#701d20` / `#fa4b26` / `#ff943e` | Uneven twin forks with a wide ember bed | Asymmetric upward snaps; tips anticipate, base holds | Low split ignition bud → Tall fork + continuous hot edge when danger=true → Flat dark ash; no hot tip or upward lick |
| Air (`wind`) | `#16513d` / `#28d882` / `#88f3ad` | Interrupted open spiral with visible negative space | Short sweeps separated by quiet holds | Converging open strokes → Open passing arcs → Separating short strokes |
| Ice (`ice`) | `#246078` / `#41d8ed` / `#b0f7ff` | Six-point branched facet, crisp center | Sharp extension, held crystalline poses | Branching growth → Stable bright facets → Short faceted fragments |
| Charge (`charge`) | `#786011` / `#eed42e` / `#ffef78` | Broken angular bolt, unequal zig-zag teeth | Brief snap, quiet interval; no full-screen strobe | Disconnected segments approach → Connected jolt → Segments disconnect and extinguish |
| Light (`light`) | `#8e8262` / `#f9ebc0` / `#fff9e8` | Radiant diamond; only short cardinal rays | Measured local expansion and return | Small gathering facet → Restrained diamond pulse → Contracting pale slivers |
| Dark (`dark`) | `#301345` / `#a246df` / `#d98aff` | Inward-facing crescent; hollow center | Slow folding inward; never global dimming | Gathering crescents → Contained inward fold → Sparse receding fragments |

## Steam pilot

Steam310 uses the source reaction palette rather than a parent-color average. Normal active: `#354f63 / #83a6b8 / #d7edf2`, scald `#ff8f4f`. Hot: `#584b4a / #a77d69 / #f2c2a6`, scald `#ff7740`. Cool: `#456575 / #8eb8c7 / #d5edf2`, scald `#e8a065`. Hot and cool are region-intensity variants, not stages inferred from age; cool is not synonymous with harmless.

Formation is a subdued, inward gathering of two open curls. Active danger uses paired pale ribbons, a continuous condensation edge and sparse warm notches. Harmless decay breaks into flat, disconnected condensate with no warm accents. The whole selected hex remains the field boundary. There is no opaque smoke, global dimming, screen distortion, concealment or particle budget expansion.

Normal and reduced modes use the same floor alpha and danger semantics. Reduced holds a representative active pose and removes optional moving details; the foreground silhouette remains open. Optional actor exposure ticks are a separate read-only binding proposal, not damage logic.

## Environment and hierarchy

Quiet weathered stone: `#4b3c2f / #806944 / #c2ac7b / #f6e4b8`. Timber: `#432516 / #77502a / #b68548 / #e8c17f`. Aged brass: `#5a330e / #956017 / #d19a3f / #ffe0a0`. These ramps come from the source. Use broad low-contrast planes under saturated magic; save high contrast for material silhouettes, actors and actionable information. The pilot does not change the map.

The two value-floor benches and grayscale boards are diagnostic proposals, not accessibility certification. Body/aim/projectile visibility requires actual camera captures and human review after integration.

## Optional audio briefs — no sound assets produced

**Water:** Small ceramic splash; soft lap. **Earth:** Dry stone clack. **Fire:** Tight crackle; single ignition pop. **Air:** Brief hollow breath. **Ice:** Glass-like tick, not shattering screen-wide. **Charge:** Short dry snap. **Light:** One soft clear chime. **Dark:** Low soft pluck, not a sustained drone. 

**Steam:** one short kettle-like exhale at formation, restrained dry scald ticks only on delivered pressure events, then a falling condensate tail that ends on actual expiry. No sustained hiss loud enough to hide aim/combat audio. Audio intensity must not invent extra damage events.
