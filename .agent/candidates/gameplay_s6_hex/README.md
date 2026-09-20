# S6 canonical-hex infusion candidate

Status: **STATIC CANDIDATE — NOT RUN**. Root owns promotion, Godot import, test registration, and runtime evidence. The frozen S3 candidate and live source files are unchanged.

## Schema and API diff

- `HexFootprint.hex(cell, grid_origin)` stores one canonical axial cell and its world-fixed grid origin. Its six integer planes drive `validate`, `contains`, segment intervals, primitive/composite intersection witnesses, cell clipping, and rendering. No circumscribed disk authorizes gameplay.
- The fork includes the finalized S3 stored-witness contract: deterministic floor/ceil lattice witnesses remain inside the analytic footprint and stored-cell union when representable; a true non-lattice tangency keeps its nearest one-unit-bounded witness with `quantization_outside=true` and continuous-coordinate provenance. It also carries the later closest-per-primitive candidate that retains the real one-fixed-unit lens between a compiled 5px-radius wall-clamped Spray and a stored field.
- `HexCourt.held_infusions` maps one owner to one immutable source id outside the ordinary `pending` cast map.
- `reserve_infusion(owner, wire, source_id, strength=3, budget=180)` accepts only Water/Fire and the fixed S6 3/180 payload. It reserves cast/product capacity before the caller spends Flux and mutates nothing on refusal.
- `commit_infusion_payment(owner)` marks that reservation paid exactly once. `ledger_for_source` exposes only paid ledgers.
- `release_infusion(owner, target_point, tick)` consumes the held marker and uses `HexGrid.world_to_cell(target_point-origin)` exactly once. It deposits all 180 units into that cell, or expires all live stock on an outside/empty terminal. Existing ground reaction and one-shot Steam modifier paths remain authoritative.
- `cancel_infusion(owner)` expires paid live stock once, gives no refund, and frees the held reservation. `sync_flights` retains a legitimate held payload even though no projectile represents it.
- Fire pressure normalizes each cell against that cast record's budget. Normal 600-unit behavior is unchanged; a full 180-unit infusion hex has the same normalized density and the ordinary 24-tick warning/lifetime.
- `state_hash` and `conservation_valid` include held ownership. The caller still owns ordering release before knockback and actual Stamina/Flux/input/physics changes.

The two candidate tests cover exact face/vertex/tangency and one-unit misses, bounded hex composites and witnesses, finite release/cancel/miss/duplicate accounting, pre-knockback canonical targeting, outer-edge ownership, atomic unsupported/owner/source/capacity refusal, reaction, and Steam modification. They have not been imported or executed.
