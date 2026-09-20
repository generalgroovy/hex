# Unified sight review

Status: bounded independent code review complete for p54-6dc4e976f925; human acceptance pending.

The independent reviewer owned only POV tests. The integration owner exclusively
scheduled every engine run. Initial review found two authority/rendered-position
mismatches: lane-source visibility and character-anchored cue/audio coordinates.
Both were corrected before frozen validation; focused v4 passed 7 suites and
4,780 assertions with zero failures/stderr.

Final read-only review found no new blocking issue in the bounded diff. Beam and
spray cues bind source identity and check displayed-source visibility; explicit
beam origins remain exact and additionally point-gated. Anchored contact/refusal
feedback and audio viewport checks use the same displayed actor feet. Exact
contact_position remains exact world evidence. Missing/hidden sources and
missing/dead viewpoints fail closed. Remote death/corpse event policy is unchanged.
The owner-only post-mask repaint contains exact body texture pixels and no
surrounding world, labels or third-party actor. Retained cues re-evaluate LOS.

Native visual inspection by the integration owner covered before/after pavilion
scenes, all three size arrangements and normal/reduced rendering. The previously
visible wall target and label disappear, the rear clear target remains visible,
and the legal 64-step walking trace reveals the target around the actual corner.
The dark region retains subdued environmental landmarks; it contains no hidden
target body/name/health. The size/pose resources themselves are unchanged.
At the visible endpoint two fixture labels are close together; that is the
controlled initial placement, not a new layout/label-spacing change.

These captures are controlled native gameplay scenes, not human play acceptance,
animation continuity, packet redaction or a performance benchmark. Motion history
is rebased for each captured state. Interpolation correctness has separate headless
wall-crossing regression cases. Exact final frame/hash comparison is recorded in
comparison.json alongside the receipts.
