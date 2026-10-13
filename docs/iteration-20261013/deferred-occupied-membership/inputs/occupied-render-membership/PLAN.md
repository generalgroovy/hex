# Read-only lead: duplicate occupied-cell preparation

Status: source hypothesis only. No candidate, runtime edit or timing claim.

Root observed that `HexCourtPresenter.draw_ground(..., draw_district_base=false)`
calls `_prepare_court(court, false)`, which obtains current `occupied_cells()`,
applies the view margin, validates membership and produces sorted `_cells`.
The immediately following `_prepare_draw_bundle` obtains occupied cells again,
intersects that result with `_cell_set` and sorts it again for the exact supported
HexChemistryWorld/HexCourt types with aggregate cast coverage. The source has no
authority step between these calls. `occupied_cells()` still builds a selected
source array, deep-compares coverage and returns a detached dictionary on hits.

Potential intervention: reuse this one call's already-selected membership only
within the actual non-base draw, preserving the standalone Range filtering,
legacy missing-aggregate fallback, generic/subclass path and directly called
helper behavior. Prefer an explicitly scoped flag restored around the existing
two-argument virtual helper over changing that helper signature: reference and
profiling subclasses override it. Do not retain authority or coverage across
calls/ticks. This is distinct from the rejected broad Court/style cache and
prefix-key experiment.

Counterevidence: the containing measured bundle is about 1.74 ms in the existing
Mantle foreground case, but no receipt attributes that time to this duplicated
membership work. Other sorting and render-region conversion can dominate. The
new flag/branch and compatibility complexity may outweigh a small benefit.

Precedent: Riot's profiling practice calls for measuring the changed section,
matching the workload and retaining slow-frame evidence:
https://www.riotgames.com/en/news/profiling-case-missing-milliseconds
It motivates measurement, not a H.E.X. performance prediction.

Before implementation, independent reviewers must challenge whether current
selected membership is identical for paid products, legacy coverage, direct
mutations, camera movement and origin changes, plus generic/override behavior.
If the lead survives, use the existing 22-case ground comparison for exact
pixels and state, and both native invocation orders for whole-ground elapsed.
Include quiet, cold, ordinary, dense, reduced, standalone/base and fallback
cases, preserve all outliers, and reject a non-repeatable or regressive result.
No new cache, content reduction, game-rule edit or FPS claim belongs to this lead.
