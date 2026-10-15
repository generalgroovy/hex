# 6459 foreground source diagnostic — October 14

The [independent source performance review](review.json) passes **29,542 checks**
for frozen **p61-64590c45c7a5**. This admits a full-observer source CPU diagnostic,
not portable-release FPS, GPU/present latency or physical-input acceptance.
The qualified playable package and its separate delivery evidence are unchanged.

The actual Start button was recorded before game instantiation. All **720**
post-arm engine focus samples and **638** recorded process samples remained
focused. The raw Windows record contains 154 available post-arm observations of
the exact owned 1280×720 window, followed by two unavailable shutdown observations;
the longest interior observation gap is 560 ms. Source identity and all 326 raw
source pins are unchanged. Stderr is empty and the wrapper restored APPDATA.
The wrapper does not expose a numeric native exit code; its clean return, exact
completion marker and complete receipt are preserved.

The root agent reported invocation through the standard `PLAY-HEX.cmd -Mode Profile`
front door (exec session 63236, exit 0). There is no separate Profile-B external
wrapper receipt or physical desktop-click proof. The archived summary independently
records the profiler arguments. The previous [unarmed attempt](../foreground-setup-a/review.json)
expired after 300,000 ms without Start or game instantiation; it remains unmeasured.

## Warm measurements

Configuration: low visual detail, 1280×720, 60 frame limit, 120 Hz simulation,
immediate-reference campus drawing, full observer and all-fixed-step counters.
Each warm row runs approximately 15 seconds. Commands are synthetic ordinary paid
commands; no measured-period resource refill occurs.

| Case | Process samples | Engine interval mean / p95 | Main process mean | Main draw mean | Paid attempts / admitted / refused |
|---|---:|---:|---:|---:|---:|
| Garden middle |243|62.105 / 73.910 ms|24.866 ms|17.345 ms|0 / 0 / 0|
| Sustained Fire Bolt |163|92.595 / 117.084 ms|28.517 ms|29.894 ms|11 / 11 / 0|
| Sustained all-six Mantle |172|87.840 / 110.507 ms|32.673 ms|27.771 ms|12 / 6 / 6|

All 638 process groups conserve **4,432 completed ticks** and the nine completed-step
elapsed/count lanes. Garden warm processing averages 7.31 completed ticks per callback:
the nine simulation stages total 16.348 ms per process, while the separately recorded
Garden step calls total 3.258 ms per process. The remaining process time is not assigned
to a new cause. Warm Garden drawing is 4.012 ms inside 17.345 ms total draw; surfaces
are 2.520 ms, including 1.539 ms preparation, while plaques are 0.570 ms and pads 0.072 ms.
Nested measurements must not be added to their parents. `render_entries` allocation
is not independently timed in this recording.

Startup and actual Garden travel are separate rows. Garden arrival recorded 34
process callbacks, 31 still-loading observations and 0.988 seconds instrumented wall
time. Warm Garden has no loading observations. These are not pure travel-latency
or full process-launch measurements.

## Limits and next measurement

This was not a dedicated-idle-machine experiment. Available host memory was
419.53 MB before and 454.67 MB after, out of 7,455.62 MB visible memory. The sampled
process peaked at 876,474,368 private bytes and 753,188,864 working-set bytes.
These snapshots establish neither a cause nor a leak. Root reported a light
startup log read; Experience and Gameplay reported no local commands during the
measurement interval. This is not an OS-wide activity trace.

Full observation adds timing, snapshot and bookkeeping cost beyond the separately
reported observer-head/tail metric. Engine intervals can include scheduling and
driver waits; GPU timing was disabled. The warm authority clock runs slower than
configured 120 Hz, and reported drop/clamp counters do not assign the entire gap.
Historical 500be rows have unmatched workloads, configuration and machine state;
they establish no causal regression or speedup here. No optimization was integrated
as part of this measurement.

The next useful Garden diagnostic separates actual funded exhibition emission/fracture/expiry
and departure from stable drawing and preparation. Exhibits do not spend player Flux. It should measure retained
allocation and observer cost before proposing another cache. Casting/Garden work
remains the current priority; portable FPS and human comfort remain open.

## Preserved evidence

[metrics.json](metrics.json) is the complete raw record; [summary.json](summary.json)
retains the wrapper's source/window admission and case summaries. Exact native
logs, runtime identity and seven wrapper inputs are included. The
[copy manifest](copy-manifest.json) hashes 13 exact payloads, including the
independent review script. Successful transient partial metrics and isolated
profile contents are excluded. The separate depth/delivery archive is immutable.

The archived review script preserves its original verification run. The final
review includes two later, independently reviewed annotations: refusal reasons
were not retained, and the recorded texture endpoints do not demonstrate a leak.
Those wording/context corrections leave all raw payload hashes and numerical
checks unchanged; rerunning the historical script alone does not reproduce these
final annotations.
