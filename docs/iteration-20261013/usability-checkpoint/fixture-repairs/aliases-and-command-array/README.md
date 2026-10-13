# Focused UI fixture repair

Unapplied, test-only source proposal after the first integrated affected-suite run failed. The canonical runtime remains p61-7804a23eb300. No assertion, runtime policy, paid command, input event or handoff guard rule changes.

The audio test referenced a script without a registered class name and used nonexistent `Mode.HOST`; the proposal adds the explicit canonical script alias and uses existing `HOSTING`. The remap neutral helper accepts a Node, so its dynamic world call does not infer a typed literal array; the proposal supplies an explicit `Array[SimCommand]`. The prior helper returned at that runtime error before decrementing the guard, accounting for the mapped-cast assertion cascade without proving a production input defect.

Exact before/proposed files retain CRLF. The review patch is LF-normalized; root should apply the exact proposed bytes and verify both hashes. Gameplay must independently review before root applies and reruns the two failed suites. Local navigation (3,817) and signature progression (6,311, including the new paid gesture fixture) passed in the rejected overall run.

The original failed directory and focused receipt remain untouched. `failed-a` copies their top-level diagnostics only, including all stderr. It does not copy the isolated profile. This source proposal has not been parsed or executed.
