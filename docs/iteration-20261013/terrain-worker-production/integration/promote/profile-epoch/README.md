# Revision two — capture-epoch correction, still unapplied

Use this directory's `manifest.json`, `proposed/` and `terrain-worker-promotion.patch` for the current candidate. The entire prior seven-file stage remains unchanged one directory above, including patch SHA `97e637979ecf1ccbbc0ff4be5fe570ca0ba19007c7a680da90c3ac5cd0c8bc77`.

Only the proposed async stream differs from that earlier stage. Root found that a measured task dispatched before `reset_profile` could contribute its old whole worker interval after reset. A main-thread `_profile_epoch` now advances on reset and is pinned into each job only for a measured dispatch. Join still validates the same hash and preserves the same ownership/readiness; worker elapsed/count/max enter the current capture only when the epoch matches and measurement is still enabled. `profile_status.capture_epoch` exposes the boundary. Main collection performed after reset remains current-window main work even when the prior worker interval is excluded.

No clock, worker-thread mutation, task cancellation or resource lifetime change is introduced. This is nevertheless a new diagnostic behavior correction and is not claimed to have been exercised by the earlier native prototype receipts. Root's added genuine blocked-task regression must witness old-epoch exclusion and later same-epoch inclusion, with unchanged readiness and joins. Six other proposed files remain byte-identical to revision one.

The parent README's integration, registration, native/Full/package gates and single-tile latency limitation still apply. Base stream `83c1ee7a…` remains untouched. All canonical files remain unchanged by this staging operation.
