# Rules 7: characters, orders and terrain

Date: 2026-10-17. Baseline: public version 11, source `fad27796bb4bc43225a37026c0cb62ab1c4663fd`. This expansion follows the requested four affinity points, one signature per character, simpler turn input, moveset inspection and a larger terrain map. Three bounded specialists covered combat, experience and server reliability; one integration owner implemented the current client and performed browser/release checks. Specialists cross-reviewed one another's work.

## Decisions and acceptance

| Evidence or existing strength | Player consequence | Change | Acceptance |
| --- | --- | --- | --- |
| Private simultaneous orders, four configurable spells and exact footprints already create prediction and combination decisions | Extra actions would weaken commitment and increase turn overhead | Preserve one cast-or-Guard action; add the signature as a fifth alternative | All 30 signatures resolve legally; ownership, Flux, cooldown and four-slot restrictions tested |
| Identical affinities made some characters functionally interchangeable | Character selection lacked a tactical reason beyond appearance | Four points with original element membership; a fixed distinct signature for every original character | All 30 allocations total four; mechanical signature uniqueness; prepared situations establish specific useful differences |
| Recruitment immediately replaced a character without showing their kit | Players could not compare before committing | Candidate modal shows actual configured spells, cost, footprint, range, recovery and signature before explicit replacement | Desktop and 390px browser inspection/recruitment; native modal and shortcut suppression reviewed |
| Every spell required a target preview followed by another confirmation | Repeated input slowed a three-character turn | Tap a valid target to queue; edit freely, Undo, then lock the whole team with End turn | Browser queues Ember, replaces it with Water Jet and restores Ember with Undo; repeated same-target taps add no invisible history |
| Selecting or restoring a character could show a different action from the queued spell | The player could edit the wrong spell after Undo or reload | Selection receives the matching plan; new rounds receive an empty plan | Browser reload/Resume retains both Ember order and Ember selection; cross-review caught and corrected the original mismatch |
| Focused hex size already accommodates original sprites; camera lacked direct recovery after panning | Enlarging the world must not shrink the playable characters | Keep focused scale; add direct Center and reselect-to-center | Browser drag changes view without issuing an order; reselect returns to the identical viewBox and keeps the cast |
| Three wells and two terrain substrates offered limited route choices | More area alone would add walking without decisions | 271 hexes, five wells, six biomes; movement 4 and ordinary centre ranges+1 | 256 seeded maps: mirrored geometry/costs, connected walkable cells, safe objective approaches and deterministic regeneration |
| Temporary fields previously described the tile by its latest element | Players could lose track of permanent movement/cover rules | Immutable biome plus separately rendered temporary field | Browser Forest remains Forest under Magma, with cover rule and remaining field duration; combat tests preserve biomes through dispel/expiry |
| Hosted matches and seeds are persistent | Updating in-flight combat would change already-chosen commitments | New rules 7 engine, frozen rules6 modules, version dispatch and explicit new-rules rematch consent | Real SQLite retains v6 pending bytes, fingerprints, resolver and receipts; both players must consent before a new Frontier match |

## Character and action system

Original two-affinity characters now have 2+2 points. Original three-affinity characters have 2+1+1, with their original primary promoted. No element membership was invented or removed. These allocations are fixed character traits, not another configuration screen. Affinity2 costs one less Flux, affinity 1 pays base, unfamiliar elements cost one extra.

The 48 ordinary spells remain the configurable catalogue. Signatures are a separate set of 30 public, owner-bound actions. Each costs its owner 3 Flux before Concussion and has 3 complete planning rounds of recovery. Names refer to original H.E.X. perks; the tactical effects are Confluence adaptations. The client shows four ordinary actions and the signature, including cost and recovery. Opponent inspection exposes the same public information.

Prepared regression positions establish tactical value without claiming universal balance:

- Current Anchor combines immediate Burn prevention through Wet with next-round resistance to displacement. Oh Tipi's off-affinity Stoneheart costs 4 and lacks Wet; Cleansing Tide lacks Anchored.
- Mason's Stance creates a three-hex wall with occupied gaps while protecting allies in those gaps for the next exchange. Ordinary Raise Cairn supplies only the wall.
- Open-Lane Charge trades damage for a second displacement step. A fixture places another well behind the target: Fault Line pushes the enemy onto it, while the signature pushes them beyond it.

## Map rules

Radius 9 produces 271 hexes. Five wells have mirrored approaches. Each seed places 20 high-ground cells, 20 shallows, 24 forest, 16 marsh and 16 ruins, with the remaining cells open meadow. Permanent terrain is rotationally symmetric; all walkable cells connect. Nearest-well travel costs 4–9 effort from each spawn in the 256-seed audit. A first-round flank capture is therefore possible with movement 4.

Forest absorbs one aggregate non-piercing spell damage after Steam and before Ward/Guard. It does not reduce Burn, recoil or environmental damage. Marsh entry costs 2, without stacking another penalty for climbing or Quagmire. Ruins block movement, line of sight, line footprints and displacement, even beneath temporary effects. Earth and Water substrates participate in chemistry. High ground retains its downhill reach bonus.

The generator namespace is `frontier:SEED`; old `reach:SEED` links retain the seed text when starting a new rules 7 map, but do not promise the old geometry. Active older games still use their original generator. Victory is 16 with a lead, limited to 20 rounds. Areas remain bounded while ordinary centre ranges increase by 1; self-target actions stay at range 0.

## Fresh validation

- **244 automated tests passed**, no failures, skips or cancellations. This includes 15 focused v7 combat tests; all 30 signature resolution/restoration; all 30 characters in five complete legal bot matches; 18 committed isolated route cases; immutable terrain; client drafts/shortcut 5; server migration and historical-client transport. Frozen v6 combat remains covered.
- **TypeScript and production build passed.** No dependency or database-schema change was required.
- **Initial 12-point development and isolated production HTTP smoke each passed 31 check groups**, ending the seeded full match after 5 exchanges at 10–13. The final 16-point production and public results are recorded in the release receipt. These check private orders, authentication, loadouts, signature ownership, retry idempotency, equal peer states and mutual rematch.
- **Browser checks at 1280×900, 390×844 and 320×844:** candidate inspection before recruitment, literal readable four-point pips, direct spell queuing, changed-spell Undo, repeated-target Undo, reload/Resume selection, signature queuing/recovery, simultaneous resolution, terrain under effects, recenter and drag safety. No horizontal page overflow at the tested phone widths. A production-build browser check confirms 271 cells and the five-action bar.
- Renderer SSR also verifies 271 interactive cells, 16 ruins, five preview wells, persistent biome information beneath Magma, Center, and all cells disabled during resolution. Frozen v6 still renders 127 cells.
- An additional specialist navigation probe covered 144 isolated cases over 48 seeds; each reached a well without repeating an approach. Six additional full matches finished in 6–7 rounds, with 1–5 signature casts and no entirely idle rounds. Node policy timing for both teams averaged 242–333ms per round, worst 557ms in that probe. These numbers are not gameplay FPS or phone timings.

The browser checks corrected invisible affinity glyphs, modal centering and action-selection restoration. All original sprite assets remain intact. The new terrain uses the existing pixel palette and drawing system.

## Limits and release record

A matched pacing experiment compared targets 12, 16 and 18 across eight identical matchup/seed cases. Mean rounds were 7.00, 8.38 and 9.13; damaging hits on occupied wells were 5.88, 9.00 and 10.00 per match. Repeat-signature users increased from 1 to 5 at 16, with no further increase at 18. The chosen 16-point target gives recovery and contested exchanges more time while keeping matches shorter than at 18. Ownership flips remained scarce in the bot policy, so a higher target does not solve all strategic weaknesses. These are bot diagnostics, not proof of the desired human match length. See v7-pacing-comparison.json for the paired results. Fixed signatures have concrete use cases but have not undergone a human competitive metagame study. Browser phone viewports do not establish physical touch comfort. Audio behavior is inherited from the prior audited implementation; no new subjective listening claim is made.

The exact published SHA, saved version, terminal deployment status and public HTTP result are recorded in the external release receipt, avoiding a circular commit reference in this file. Earlier verification documents describe earlier source revisions and remain historical evidence.
