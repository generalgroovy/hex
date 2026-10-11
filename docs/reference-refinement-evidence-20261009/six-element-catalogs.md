# Six-element catalogs and saved-weave migration

Status: SOURCE_CANDIDATE; static checks passed, Godot/import/focused/full validation NOT_RUN by this worker. Root integration and engine qualification are pending. 2026-10-09.

This implements the user's explicit six-element instruction. Live display order is Water, Fire, Air, Earth, Light, Dark; internal `wind` and stable wire order `[3,2,4,1,7,8]` remain. Wires5/6 are retired as selectable Ice/Charge. These are direct requested semantics, not balance outcomes inferred from a reference game.

`AbilityCatalog` exposes24 live spells (six elements by Bolt/Heavy/Rapid/Spray) and retains all16 authored Ice/Charge ability records as strict catalog-only identities. Retired records cannot become a catch-all exception: exact historical ID, wire, element and disabled status must agree. All eight historical Burst entries are retained as disabled reference data. Retired-wire casting and injected pending-cast refusal remain tested.

All30 current champion affinity maps fold Ice points into Water and Charge points into Fire by addition. Every profile retains its three-point total. Four former three-element profiles naturally become two-element profiles. Wire identity, display identity, ancestry, body profile, stats, art and the earlier race/character perks remain unchanged. The old full-cast candidate JSON remains historical; its parity test explicitly migrates an in-memory copy before comparing every profile field to the current catalog.

The12-slot starter contains one Bolt for each live element, the dominant Heavy, then Rapid/Spray/Rapid/Spray/Heavy over five distinct element priorities. Existing affinity order leads, then canonical order fills missing elements. Distinct element/family cells guarantee12 unique spells. This preserves the user's existing12-slot control surface while making all six elements and four delivery families reachable.

Only eight former live spells have migration aliases:

| Archived wire / spell | Canonical replacement |
|---|---|
|170 Rimeshard|140 Rillshot|
|189 Frost Shell|181 Tide Shell|
|190 Sleet Stream|182 Rill Stream|
|171 Sleet|141 Tideline|
|101 Arc Primary|145 Cinderbolt|
|187 Thunder Shell|179 Cinder Shell|
|188 Spark Stream|180 Ember Stream|
|167 Spark Shower|154 Ember Sweep|

`CharacterWeaveLibrary.migration_preview(champion_id)` returns a detached proposal with `required`, `valid`, `migration_id`, champion ID, original and proposed12-slot arrays, per-position changes/reasons and notice. Preview is read-only. All original canonical slots are reserved before any alias is folded, so an earlier archived alias can never displace a later canonical spell. Duplicate replacements fill only the archived alias's slot, using that character's deterministic starter priorities and then the remaining live catalog. An unrelated archived spell remains untouched and makes the proposal invalid; it is never silently enabled or replaced.

Loading and previewing preserve original save bytes, including whitespace, and create no backup or write. Explicit accepted Apply uses the existing remember/save path, which first preserves exact valid bytes at `.pre_six_elements_v1.bak`. The schema remains1 because the saved format is unchanged. Root owns the coordinator/bootstrap step that must show this proposal and validate both current actor slots and saved provenance before Apply; worker library completion does not establish that integration is finished.

Direct tests assert the exact collision proposal for a mixed old weave, canonical positions, all change receipts, deterministic repeat previews, copy isolation, invalid unrelated archives, byte-preserved load/preview, backup bytes and explicit saved roundtrip. Other catalog tests assert24 unique6-by4 definitions,16 retired records, all30 unchanged-profile parity and exact representative12-slot starters. The two combat admission fixtures now use live Cinderbolt145 for mutable-primary/hash tests instead of archived101.

Static evidence: JSON checks found24 distinct live wires in canonical order; every champion preserved non-affinity/kit/playstyle fields, point totals and valid mapped kit IDs. Independent migration of the historical full-cast candidate matched all30 current profiles with no differences beyond the declared folding, explicit8-wire mapping and prior documented passive wording repair. `git diff --check` passed for worker-owned source/tests. These checks do not prove engine parsing, networking, UI rendering or gameplay feel.

Exact pre-edit copies are under `.godot/six-element-baseline/movement/`. The one-time `.godot/migrate_six_catalogs.py` and fixture script are historical scratch receipts and must not be rerun over later combat cadence edits.

Unresolved boundary: legacy `FrostwayFieldPolicy` still uses wire327 and its old nine-int capsule packets; live canonical Frostway is316 and composites use explicit motion policy fields. A partial rename is unsafe while the legacy actor path still treats316 as Flood with a directional push. Root must either retain the old adapter as explicitly archived or complete the legacy-to-unified dispatch before declaring that boundary qualified.
