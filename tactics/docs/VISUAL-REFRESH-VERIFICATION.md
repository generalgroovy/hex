# Parchment visual refresh — 2026-10-16

The user's champion-poster reference sets the visual direction: warm parchment, dark ink, moss and brass, substantial original character sprites, squared pixel lettering and vivid elemental emblems. This release carries that language through the company register, spell library, battlefield, field guide and phone command controls.

## Scope

- One shared palette and a locally hosted, licensed pixel heading font.
- A new low-contrast parchment material, six original pixel element emblems, foliage ornament and matching favicon.
- Larger original character renders in recruitment and loadout preparation.
- A meadow-and-ochre battlefield with ink contours, moss, flowers, masonry, jewel magic, teal/rust team identity and distinct legal-target outlines.
- Darker status inks on light paper for readable labels.
- Corrected a presentation bug: terrain-granted statuses now show their status name, rather than a false one-point damage label. Numeric terrain damage still shows its real amount.
- Corrected pointer targeting: character hit areas no longer intercept taps on visible ground hexes behind them. Ground controls render in a final interaction layer, preserving one accessible control per hex.

The combat engine, spell catalogue, canonical roster, save keys, protocol version, room API and database configuration remain unchanged. All thirty sprite atlas files match their existing manifest byte lengths and SHA-256 hashes. The reference's printed affinities and character labels are not treated as replacement game data. Asset provenance, font license and the built-in image-generation prompt are recorded in `VISUAL-ASSETS.md`.

## Verification

The complete existing automated suite passed: **110 tests, zero failures, zero skipped tests**. It covers simultaneous tactics, reactions, statuses, prepared tactical comparisons, private rooms, persistence and compatibility with earlier rules.

Independent review checked engine/data identity, all thirty atlas hashes, font provenance, inline status/reaction colours, and misleading surface-effect feedback. It also identified and fixed low contrast on clickable unavailable spell cards: these now keep full text opacity and use an aged background, desaturation and a dashed edge. All current JSX class names have stylesheet coverage, and PostCSS parsed 403 rules.

- Full TypeScript check and production Vinext/Cloudflare build passed. The installed official npm CLI ran the project's build script directly, retaining the previously documented Windows shim workaround.
- Built Worker HTTP smoke passed all 19 checks. The complete simultaneous match resolved eight rounds, finished 6–9, and successfully rematched with preserved loadouts.
- Final production camp and battlefield were inspected in a fixed-width 1280px iframe (1271px document width after scrollbar); both reported equal document and scroll widths. The wide fixture was scaled for viewing, while its actual layout width remained 1271px. This exercised the two-column desktop layout.
- 320px and 390px phone fixtures yielded 310px and 381px document widths. The narrow spell library displayed all 48 spells without horizontal overflow. Equipping Frostbite in slot one persisted into practice.
- At 381px, movement and Cleansing Tide targeting completed via keyboard, then the commit resolved to round two with Wet status displayed. Four spell buttons measured 156 × 85px internally, and the fixed command dock measured about 381 × 79px. The guide displayed all twelve status cards without horizontal overflow.
- Desktop board QA also exercised Bulwark: Treevor retained 8/8 HP, gained Ward and Anchored, and had 5 Flux in round two.

During development, hot reload and Opera automation became unreliable. Final integrated layout checks used the built Worker instead. Subsequent direct public-browser checks at a 390 × 844 viewport (375px document width) exposed a real input defect: Treevor's tall hit area intercepted a click intended for hex −2,0 and selected −3,2. This prompted the final interaction-layer correction. Physical touch interaction is not certified by browser viewport checks. The external release receipt records the exact published source revision, deployment and public-origin HTTP smoke result.

The corrected production build passed the same direct pointer sequence: clicking −2,0 planned movement to −2,0; clicking Cleansing Tide and then −2,0 aimed at −2,0; clicking Lock team resolved round two. Independent server-render checks confirmed 37 unique hex buttons, one roving tab stop, 37/37 elevation-adjusted hit polygons, all controls disabled during resolution, and identical hidden-order markup for two different private plans. TypeScript, whitespace validation and the production build passed again after this correction.

## Limits

Responsive browser checks are layout and interaction evidence, not physical iPhone/Android device certification. Visual and regression checks do not establish broad player preference, commercial success or a new balance result. The earlier v4 balance diagnostic remains separately documented; no new balance claim is made for this presentation release.
