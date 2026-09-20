# S3 finite field interception candidate

Status: isolated candidate, static review only, `NOT RUN`.

This directory contains candidate copies of `HexProjectileCombat` and
`HexFootprint`. It adds source-owned fundamental ground fields to the existing
ordered projectile queue and phase-zero Spray resolver. It does not alter live
runtime files, product chemistry, schemas, presentation, or network state.

## Authority contract

- A projectile field contact occurs when the projectile **center segment**
  enters both the field's analytic footprint and the closed union of hex
  polygons in that cast's positive `cells` allocation. Projectile radius still
  applies to actor/projectile and wall contact; it never enlarges a field.
- `HexFootprint.stored_segment_interval` proves closed disk/hex contact with
  integer predicates, retains a bounded scalar Float64 interval and chooses the
  earliest entry. Fixed-grid conversion examines the deterministic floor/ceil
  neighbors within one world unit and selects the nearest point that remains in
  both the analytic footprint and the closed stored-cell union; distance then
  lexicographic `(x,y)` breaks ties.
- Some real analytic tangencies have no common `Vector2i` witness. For example,
  disks `(center=(0,0), radius=1)` and `(center=(3,4), radius=4)` touch only at
  `(0.6,0.8)`. Such a collision is retained, quantized to the ordinary nearest
  fixed-grid point within one world unit, and explicitly marks
  `contact_quantization_outside=true`. It is never dropped or moved an arbitrary
  distance inward. Continuous TOI remains authoritative in either case.
- Wall cutoff is exclusive and wins an exact tie. Range and lifetime endpoints
  remain inclusive. Phase-zero Spray compares the retained continuous witness
  to its physical wall cutoff, so it does not trim another whole fixed unit;
  one unit of genuine pre-wall overlap remains eligible. Field contacts share
  clash priority before actor hits.
- Candidate enumeration scans at most `HexCourt.MAX_CASTS` source records and
  emits at most one candidate per source, regardless of occupied cell count.
- Eligibility requires a paid, unexpired fundamental cast with a valid shared
  `StrengthBudget`, positive deposited quantity, positive ground allocation and
  positive remaining strength. Products and zero-strength records are absent.
- Resolution calls `HexCourt.resolve_contact` once. The same source ledger backs
  every field cell, later projectile clashes and later contacts. Its existing
  proportional retile updates surviving deposited stock; exhaustion clears the
  field. Pending field contacts recompute their stored-union entry after an
  earlier retile and re-enter the remaining queue if that entry moved later. A
  field never owns a second resistance counter.
- All projectiles handled here occupy the existing ground-flight layer; the
  projectile schema has no independent flight height. Actor height remains the
  established actor-contact eligibility rule.
- Phase-zero Spray uses one analytic common witness per eligible source,
  constrained to that field's stored-cell union, then applies the existing
  clear-ray cover check. Contacts use stable source-id order and every emitted
  clash carries the exact `other_wire_id` needed by the two-element cue.
- Same-source contacts and product recursion are excluded. Every accepted
  contact exhausts at least one participant, so a source cannot drain once per
  cell or once per later tick.

## Candidate files

- `hex_projectile_combat.gd`: ordered field and Spray integration.
- `hex_footprint.gd`: public analytic and stored-union interval/witness helpers.
- `test_hex_projectile_combat.gd`: unchanged S2 resolver regression copy.
- `test_hex_field_interception.gd`: S3 accounting, geometry, cover and ordering
  cases, including diagonal constrained quantization, non-lattice tangency,
  actual same-tick requeue after a leading cell disappears, phase-zero
  exhaustion, and exact-versus-one-unit Spray wall-cutoff contacts.

The integration owner must promote the two source diffs and register the new
test before serialized Godot import and focused/full gates.
