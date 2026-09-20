# FLUX cast overview: race, size and affinities

Status: candidate awaiting user visual acceptance, September 9, 2026.

This revision applies the user's four identity corrections:

| Character | Requested identity | Location in the sorted sheet |
|---|---|---|
| Faab I Yaina | Male Angel; glorious shiny bald head; Middle; Fire 2 / Light 1 | Row 1, column 1 |
| Juul I Yaina | Male Demon; curly dark hair; Small; Ice 2 / Wind 1 | Row 1, column 3 |
| Spai Si | Male Demon; Middle; Wind 1 / Earth 1 / Light 1 | Row 1, column 4 |
| Wa Bidi | Female Goblin; Small; Charge 1 / Wind 1 / Fire 1 | Row 2, column 3 |

The four gender assignments and the two hair/head requirements are saved in the
canonical champion roster. Existing races, sizes, statistics, playable wires and
affinity allocations are retained. No gender is newly assigned to other identities.

## Complete overview

[Open the full image](flux-cast-race-size-v2.png).

The sheet contains all 28 identities: 27 named playable characters and the separate
reserved Unnamed Angel. Every card includes its name, race, size and exact element
affinity levels. There are 72 element/level entries, totaling three points per
character. Unnamed Angel's values remain planned, and its card is marked RESERVED.

Reading order is race A-Z, then Small / Middle / Large within a race, then name
within the same size. The game's Gallery uses the same rule. Stable gameplay
IDs and wire numbers are not reordered.

- [Complete sorted roster and affinity table](ROSTER.md)
- [Source-derived manifest](cast-manifest.json)
- [Exact generation prompt](PROMPT.txt)
- [Final local polish prompt](POLISH-PROMPT.txt)
- [Image inspection and acceptance record](acceptance-review.json)
- [Previous candidate](../cast_overview_angel_demon_v1/flux-cast-overview-v2.png)
- [Original user art direction](../cast_overview_angel_demon_v1/user-style-reference.png)

Created with the built-in image generation tool using the earlier labeled cast
for identities and the original attachment for its pixel-art/parchment treatment.
The new artwork is a review candidate, not a runtime atlas or animation approval.
The initial pass is preserved as [v1](flux-cast-race-size-v1.png); the selected v2
strengthens Faab's scalp shine and Spai Si's male face, and corrects Luuh's Water icon.

## Acceptance review

- [ ] Faab is visibly male, completely bald and has the requested shiny scalp.
- [ ] Juul is visibly male with curly dark hair and remains a Small Demon.
- [ ] Spai Si is male and remains distinct from Juul.
- [ ] Wa Bidi is female and remains distinct from Steezo.
- [ ] Every character and affinity label matches the manifest and roster table.
- [ ] Race/size order, faces, clothing, proportions and style are accepted.

## Verification

The focused gate passed: **8 suites, 29,133 assertions, zero failures and zero
stderr bytes**, in 38.598 seconds. All 28 review records and 72 affinity entries
also match the current source data. See [the focused test receipt](focused-test-receipt.json) for the exact local
catalog, overview, selection, Gallery and visual-catalog test results. The
overview regression includes a case where alphabetical name order disagrees with
size, proving that Small precedes Middle within a race. Roster tests retain the
four requested gender assignments and Juul/Faab hair identities.

The [retained suite output](focused-suite.log) matches the receipt's SHA-256.

This concept sheet does not replace the active shared skeleton presentation.
Human visual acceptance, runtime character animation and a release build are
separate from these source checks. This revision is saved in the local project.
