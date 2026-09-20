# Four-delivery B numeric source checkpoint

Status: catalogue/compiler substep COMPLETE validated source, 2026-09-13; B gameplay kernel pending.

Latest direct user strengths apply across all eight elements:

| Delivery | Reaction strength |
| --- | ---: |
| Rapid | 1 |
| Spray | 3 |
| Bolt | 5 |
| Heavy | 15 |

These replace every earlier proposed ladder. The planned kernel compares authored
integer values. The current catalogue has no equal-strength cross-family pair;
equal setup uses separate casts of the same family across elements. The original
request's cross-family example is superseded by the latest explicit numbers.

All32 live definitions author and compile a separate reaction_strength field.
Ability schema5 and compiler contract2 require bounded whole values1..15; booleans,
strings, missing/fractional/out-of-range/nonfinite values fail validation. Custom
bounded values remain data driven. The actual current catalogue's four values
are separately asserted across all8 elements. Existing spell IDs and disabled
definitions remain intact.

This is a data-only substep. Projectile/deposit state, dominance, equal-contact
chemistry, pulse interception, snapshot layout and replay rules are not changed
by it. Damage, Flux, timings, geometry, lifetime and material quantity are unchanged.
The source-derived guides continue describing executable A gameplay until the
kernel is integrated. Protocol48 and snapshot18 are unchanged for this substep;
same-build admission includes the new production identity.

Candidate source identity: p48-2781b0c576ef,
SHA256 2781b0c576efeef48a4375db08d4499cc7cafe099b039bdce8d4aff1be57feaa,
2720 production records. No new export or package promotion.

Evidence root: docs/evidence/four-delivery-b-20260913/.
Exact before-images are in catalog-before/; strength-only-data.json verifies the
entire authored catalogue is unchanged apart from strength properties and the
explicit schema4-to5 transition. Independent source review and follow-through
found no actionable issue. Fresh numeric-focused-v1.json passed4 suites,
1886 assertions, zero failures and zero stderr. Fresh numeric-full-v1.json passed
104 suites/681530 assertions in146499ms with zero failures/stderr, strict import,
asset/cache checks and isolated120Hz boot. Referenced logs are preserved under
referenced/. Both inventories compare equal across all3128 frozen input paths,
sizes and hashes; numeric-freeze-validation.json verifies the copied referenced
log hashes. Numeric-preservation.json verifies the exact personal-profile hash,
unchanged checkpoint pointer and all three selected EXE/PCK/ZIP identities.
No native capture was run for this metadata-only change.

Selected playable fallback remains Overnight P48 p48-111d911c27fa through
docs/current-checkpoint.json. Its EXE/PCK/ZIP are unchanged; it does not implement
the new strength rules. A's completed source validation remains historical at
docs/FOUR-DELIVERY-A-CHECKPOINT.md and is not used as proof of B source.

Next B work is defined in the single queue and evidence contract.md: immutable
cast-owned strength propagation, compatible state/wire/replay layouts, first
eligible contact ordering, spent-payload dominance, deposit equality and bounded
Spray interception including simultaneous pulse/pulse equality. A geometry
candidate exists only as evidence text, not live source; off-lattice tangency
must be resolved before integration. No C lifetime or Steam/Magma change is included.

The120Hz performance gate remains unresolved. No new simulation performance,
renderedFPS, physical two-PC, native capture, package, installer or human-acceptance
claim follows from this metadata substep.
