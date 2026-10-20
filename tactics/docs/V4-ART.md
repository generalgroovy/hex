# V4 pixel battlefield and original H.E.X. sprites

The v4 battlefield uses all 30 original H.E.X. character atlases from
`assets/sprites/pixel_cast_v1`. The original repository is read-only. No original
asset was painted over, cropped, recoloured, or resampled. The browser selects
frames from byte-identical copies under `public/pixel/champions`.

## Source and identity contract

`scripts/import-pixel-assets.mjs` reads the original pixel-cast manifest and the
current generated `lib/roster.ts`. It checks thirty unique canonical IDs, the
128 × 128 cell size, foot pivot (64, 104), eight facings, four rows, and every
1024 × 512 PNG. After copying, it checks each destination against the original
bytes. `public/pixel/manifest.json` records the original relative source paths,
PNG SHA-256 values, original RGBA hashes, byte sizes, and manifest hash.

Run the importer with an explicit original checkout when needed:

```sh
node scripts/import-pixel-assets.mjs /path/to/original/hex
```

The set contains eight directions in source order: S, SE, E, NE, N, NW, W, SW.
Its rows are idle, walk contact A, walk contact B, and cast. Existing full-body
atlases and the older small champion atlases were visually inspected before
choosing this set. The pixel-cast set provides the original detailed, expressive
figures plus actual directional walking and casting frames.

## Rendering

`PixelChampion.tsx` uses nearest-neighbour atlas rendering and the original foot
pivot. Its `size` is the full cell size, not the visible body height: size 128
shows a roughly 58–68 pixel figure. The battlefield uses a 192 pixel cell before
the responsive camera scale. Character proportions remain those of the original
art. Idle breathing, hit flashes, healing light, and defeat motion are CSS
presentation effects; they are not additional hand-drawn source animation rows.

`PixelBattlefield.tsx` draws the environment as stepped, code-native SVG shapes:
stone terrace faces, grassy surfaces, flowers, a ruined arch, a lantern, and
pixel wells. Decoration outside the playable cells does not change collision or
line of sight. Raised ground, barriers, wells, terrain, reaction lifetime, health,
Flux, status duration, and legal targets all come from the authoritative state.

The six elemental spell effects use distinct silhouettes as well as colour.
All fifteen elemental pairs have individual pixel terrain motifs and restrained
surface palettes; the rules catalogue remains authoritative for their labels.
Burn, Wet, Blind, Concussion, Rooted, Chilled, Ward, and Haste have small persistent
visual cues, supplemented by labelled status data in the unit inspector. Plan
paths show only the current player's allowed orders. Area previews are supplied
by the rules engine; the renderer does not invent a second targeting model.

## Interaction and readability

- Each hex has one accessible button with coordinates, elevation, terrain,
  occupant, health, Flux, statuses, and legal-target information.
- Arrow keys, Q/E, Home, Enter, and Space support keyboard board operation.
- Narrow screens start in Focus, centred on the company. Overview remains one
  tap away. Focus supports dragging and explicit pan/centre buttons.
- Health and Flux bars render above foreground tiles, so terrace faces cannot
  hide them. Team identity uses labels/numbers and ring colour together.
- Resolution shows movement, spells, reactions, and aftermath. Replay preserves
  the view and disables order editing through `onReplayChange`. Old terrain,
  statuses, and vitals remain visible through movement/casting; resolved effects
  appear at impact. Health/Flux bars travel with their character.
- Reduced motion removes continuous and movement animations while retaining
  readable static impact marks and labels.

## Evidence boundaries

The importer verified coverage and byte identity for all 30 canonical sprites:
6,137,442 bytes total. This establishes correct asset transfer and IDs. It does
not establish subjective charm, competitive visual readability, a physical-phone
pass, or a human preference result. Those require direct play and observation.
The v3 `IsometricBoard.tsx` and `battlefield.css` remain unchanged for old games.

Independent browser verification used a temporary Opera viewport override. The
requested 390 × 844 viewport reported an actual 355 × 767 CSS-pixel page because
of the browser's existing scaling, so this is evidence for that actual width.
The page had no horizontal overflow. Focused hex hit areas measured approximately
72.7 × 49.6 CSS pixels, and all five pan controls measured 44 × 44. Pointer
movement and spell targeting, keyboard Enter activation, and a complete Fire +
Water simultaneous plan were exercised: Round 2 showed Steam at (-1, 0), with the
reaction in the exchange report. No browser console errors were captured. The
temporary viewport was reset and the isolated QA tab was closed. This test did
not use a physical phone.
