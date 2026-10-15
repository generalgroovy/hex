# Casting stage attribution: no runtime change

Four native source runs through the desktop launcher passed exact paid-event, actor, state-boundary and cleanup checks. Each uses a real Fire or all-six Mantle cast with five authored actors. Both arms retain the existing profiler; one adds seven disjoint child intervals.

| Case | Steps / checks | First ground tick | Whole plain mean, after first four | Observed movement mean, after first four |
|---|---:|---:|---:|---:|
| fire-forward-a | 48 / 2348 | 24 | 1066.2 us | 413.8 us |
| fire-reverse-a | 48 / 2348 | 24 | 1059.4 us | 407.4 us |
| mantle-forward-a | 48 / 2348 | 17 | 1141.9 us | 419.5 us |
| mantle-reverse-a | 48 / 2348 | 17 | 1179.6 us | 418.1 us |

Movement is the largest measured child in the repeated ordinary steps. This motivates testing a narrow stationary-velocity fast path while preserving all surrounding movement, recovery and status processing. The observation alone does not qualify that candidate.

Actual callback order changes apparent observer overhead; negative paired overhead is an order/cache effect, not an optimization. Release and first-impact rows are retained separately. The short probe does not recreate the accumulated field or full application load of the earlier foreground recording. No portable FPS, smooth-gameplay, GPU/present or physical-input claim follows.

[analysis/analysis-all-a.json](analysis/analysis-all-a.json) preserves numerical strata; the original receipts retain all rows. The first strict parse failed because a local variable needed an explicit type; both failed and corrected parser logs are preserved. The qualified runtime and launcher selection remain p61-64590c45c7a5.

The manifest records exact source origins and every payload hash. Source scripts are archived as text; engine data, executable builds and isolated user profiles are excluded.
