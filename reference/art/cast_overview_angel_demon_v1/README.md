# FLUX complete cast overview: Angel and Demon correction

Status: generated visual candidate awaiting user acceptance, September 9, 2026.

Superseded by the [race/size-sorted overview with affinity labels](../cast_overview_race_size_v2/README.md).
That revision applies the user's gender/hair corrections for Juul, Faab, Spai Si
and Wa Bidi. This folder preserves the previous candidate and its test receipt.

Faab I Yaina is now an **Angel / Middle**, retaining **Fire 2 / Light 1**.
Juul I Yaina is now a **Demon / Small**, retaining **Ice 2 / Wind 1**.
Both changes are applied to the canonical roster, playable catalog, baseline
provenance and current cast/race documentation. The existing roster regression
test now expects these assignments. The Gallery derives its race grouping from
those updated records. All 21 races have a named playable representative.

The overview includes all 27 named characters and the separate reserved Unnamed
Angel, arranged in seven columns and four rows. No runtime body atlas or portrait
is replaced by this concept sheet. The game's current shared skeleton artwork
remains the active body presentation until character art is accepted and produced.

## Review assets

- [Complete cast overview](flux-cast-overview-v2.png)
- [Original user style reference](user-style-reference.png)
- [Exact card order, races, body sizes and affinities](ROSTER.md)
- [Machine-readable roster snapshot](cast-manifest.json)
- [Generation prompt](PROMPT.txt) and [single correction prompt](CORRECTION-PROMPT.txt)

Generated using the built-in image generation tool. The reference supplies the
pixel-art treatment, parchment grid and established character identities. New
details for Juul and Faab are visual proposals for acceptance, not pre-existing
approved character designs. The initial pass is retained as
[v1](flux-cast-overview-v1.png); v2 corrects Grimm Bow's hand effects to Earth/Water.

## Acceptance review

- [ ] Faab, bottom row column 6, reads as an Angel with feathered wings and a
  visible face, distinct from the reserved hooded Angel at column 3.
- [ ] Juul, bottom row column 5, reads as a Small Demon with horns and tail,
  distinct from Middle-sized Spai Si in row 2 column 4.
- [ ] The established characters remain recognizable in the supplied style.
- [ ] All 28 labels match the corresponding figures and roster card order.
- [ ] Clothing, proportions, expressions, racial silhouettes and illustrated
  spell accents are accepted as the next character-art direction.

This review accepts or rejects the concept direction. A single illustrated pose
does not certify runtime pixel dimensions, eight-way animation, combat readability
or individual character balance. Reserved Unnamed Angel remains non-selectable.

## Verification

The Windows **Focused** gate passed: **8 suites, 29,125 assertions, zero failures,
zero stderr bytes**, in 48.919 seconds. It covered champion catalog, canonical
roster, overview model, selection model, selection grid, Gallery integration,
complete visual catalog and Wellspring visual catalog. Current-state validation
also passed. Full/Release, a new executable build and human visual acceptance
were not part of this focused check.

See [the test receipt](focused-test-receipt.json) and [retained suite output](focused-suite.log).
The receipt records the tested working tree as dirty on local main at a1aa0280;
this request does not imply that unrelated local work was committed or published.

The prior v4 reference is preserved as a historical snapshot, with a correction
notice pointing here. Its old Werewolf labels are not current identity authority.
