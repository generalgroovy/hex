# Campaign rules 19

This campaign is isolated from the existing online rules 18. The home page and
`/story` open the campaign; `/v16` preserves the preceding story and local saves.
Existing root invitation and seeded-map links route to `/v16`. The original
`/classic` game is also preserved.

## Design constraints

- The player commands one custom hero and two recruited elemental creatures.
- Encounters follow a fixed order. Completed encounters can be replayed; rewards
  are collected only once. Enemy strength never changes in response to a build.
- Early enemies contain one champion and two creatures. Additional enemy
  champions enter later, with the full lineup visible before the fight.
- Creature perks must have explicit triggers, distance limits and stacking caps.
  They must stop when the source is defeated and never revive a defeated unit.
- Movement resolves before simultaneous casting. Win by eliminating the enemy
  company. The spatial endgame prevents indefinite stalling; elapsed rounds alone
  cannot declare a draw while units survive.
- Compact symbols supplement accessible names and selectable descriptions.
  Information needed to plan must also be available without hover.

## Validation required before publication

1. Validate every authored encounter and creature kit, ordered unlocks, repeated
   rewards, progression migration, malformed saves, and locked signatures.
2. Exercise creature perks in both positive and negative cases, including range,
   stacking, source defeat, simultaneous outcomes, and enemy independence.
3. Run deterministic campaign simulations across the progression and with
   contrasting parties. Retain results as bot evidence, not human playtesting.
4. Inspect the creator, companion selection, first battle, replay/review and
   saved-session continuation in the browser, including narrow phone layouts.
5. Run existing regressions, TypeScript validation and a production build; publish
   that exact source state and verify the public entry points.

Balance simulations can reveal impossible encounters, pacing problems and
dominant automated strategies. They do not establish human difficulty, long-term
metagame balance or commercial success.

## Implemented progression

Thirty encounters form three chapters of ten. Opposition rises from one champion
and two creatures to two champions and one creature, then three champions. The
player always commands one created hero and two chosen creatures. Teams have
fixed authored builds, exposed before battle, rather than scaling against the
player's current choices.

Heroes start with five points across at most three elements. First victories add
one point, up to eighteen, and teach the defeated champion's signature. The
per-element cap rises from three to four, five and six across the first three
victories. Replays cannot award additional progression. Changes between battles
are free and invalid drafts cannot replace a valid saved party.

The catalogue contains 93 creatures: 36 pure species (two per strength class in
each of six elements) and 57 mixed lineages covering every combination of two to
six elements. Twelve lesser pure companions are initially available. Standard
creatures unlock after three victories, greater creatures after ten; mixed
lineages gain one ingredient tier every four victories. The final six-element
lineage unlocks after twenty victories.

Bonds have five mechanical benefits: healing, Flux, Ward, Haste and Clarity.
Different elemental partners enable them; the recipient must be within two
hexes of the living allied sources. Identical benefits cap at one. Ordinary
combat deaths resolve before bonds, and Wither taxes combined healing once.

## Validation recorded on 2026-10-19

- Full regression suite: 952 passing tests before the final early-rank and
  movement-name adjustments. The final campaign-focused suite passed all 35
  tests after those changes; full TypeScript validation and production build
  also passed.
- All thirty encounter compositions construct and restore. Ordered travel,
  malformed saves, signature restrictions, idempotent rewards and migration are
  covered, including older overrank profiles and noncontiguous victories.
- All 93 creature renderings are distinct; all 321 equipped spells have legal
  affordable casts. Pairing checks exercise 8,649 ordered creature pairings,
  order independence, benefit caps, range and defeated sources.
- A 60-match initial automated corpus exposed the opening's excess healing and
  prompted an authored correction. A separate final, unchanged-source corpus
  ran twelve contrasting matches at encounters 1, 2, 10, 11, 21 and 30:
  seven wins, five losses, no draws, 133 rounds (mean 11.08), 266 validated plans
  and 145 restored states. Neither corpus establishes human balance.
- The default starting party wins the opening in the final regression. An
  ordinary next-step build wins encounter two: the same hero and companions,
  Water 4 / Fire 2, replacing Undertow with Tidal Surge. This is a verified legal
  path, not a claim about beginner win rates.
- Browser checks exercised naming, affinity reassignment, four-slot loadouts,
  exact enemy inspection, movement, aiming, resolution, replay and save/resume.
  Desktop 1366x768 and phone 360x740/360x640 layouts were inspected. The phone
  battle had no document overflow and kept the map and End Turn visible.
- Existing root invitation redirect and `/v16` and `/skirmish` routes returned
  the expected redirect/HTTP responses. Online rules and persistence were not
  changed by this campaign.

Raw local logs, source hashes, simulations and screenshots are retained in the
workspace's `work/campaign-*` evidence files. Viewport checks are not physical
phone testing; no external human playtest or audio listening study was performed.
