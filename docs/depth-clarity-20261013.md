# October 13 depth, clarity and maintenance pass

Status: **active again as of October 14; stop at 20,000 credits remaining**. The completed batch qualifies **p61-64590c45c7a5**, based on preserved **p61-7804a23eb300 / Git 38f1bc3**.
The [single queue](../.agent/OVERHAUL-IMPLEMENTATION.md) owns remaining work;
this note records concrete decisions, review and checks for the current batch.
No historical qualification is transferred to these edits.
Qualified source identity: **p61-64590c45c7a5**, protocol 61 / snapshot 24.
Full, package/archive, all 133 exported terrain images, five desktop-wrapper
lifecycle cases and the **4,076-check independent delivery review** passed.
The previous 7804 delivery remains the immediate fallback. The [source performance review](performance-evidence-20261014/foreground-6459-b/review.json)
now admits 6459 Profile B; portable-release performance remains unmeasured. The user resumed work with 57,349 credits recorded
and a 20,000-credit remaining cutoff, superseding the former 1% / no-paid-credit
limits.

## Current performance evidence

Profile B completed through the standard launcher on October 14 with actual Start,
unchanged 6459 source, 638 focused process samples and no stderr. The independent
review verifies 29,542 checks and 4,432 completed ticks. Warm Garden, sustained Fire
and sustained all-six Mantle engine interval mean / p95 are 62.105 / 73.910,
92.595 / 117.084 and 87.840 / 110.507 ms. Mantle includes six admitted and six refused
ordinary attempts; no resources were refilled. Full observer cost, low observed
host memory and unmatched historical conditions prevent a causal speed comparison.
This is source CPU evidence, not GPU/present latency, portable FPS or physical input.
The [earlier setup attempt](performance-evidence-20261014/foreground-setup-a/review.json)
expired after 300,000 ms without Start or game instantiation. Its failed raw evidence
remains preserved separately; the depth/delivery archive is unchanged.

## Qualified changes and review

| Change | Implementation | Independent review |
|---|---|---|
| District wall relief | Experience: relief variants for the existing six masonry families, broader facades, east side planes, contact courses, inset slate parapets/foundry buttresses/observatory plinths | Gameplay + Technical source review; two independent native world reviews passed |
| Taller architectural facades | Experience: two existing solid structures use taller stone faces, vertical supports and a crown/parapet, retaining existing footprints and source materials | Root + Gameplay + Experience accepted six refined native comparisons; canonical integration, cache/lifecycle source review, native parity and Full passed |
| Independent camera look-ahead | Gameplay; Root Bootstrap wiring: optional saved Boolean, legacy framing migration and compact sixth Display & Input row | Technical source review; native fit and player comfort separate |
| Range status observation | Gameplay: existing six status counters displayed as seconds for the current observation window, with explicit overlap semantics | Experience source review; no extra combat HUD or authority changes |
| Earned signature guidance | Gameplay: selected learned lessons retain their own reuse advice; the next locked lesson says Learn instead of Equip | Experience + Technical source review; existing paid wins and reload tests extended |
| CI selection | Technical: 38 selected regressions, three bounded shards, exact requested/executed inventory plus hashed log checks | Experience source review; 46 pure selection assertions passed |
| Current delivery consistency | Technical: descriptor/header/link checks distinguish working candidate from qualified portable | Experience source review; 22 pure assertions and actual documentation check passed |
| Standard launcher | Root: repaired desktop shortcut to stable wrapper; explicit Source/Profile modes share that front door, default remains qualified portable | Technical source review; default/source inspection and three unsafe-argument controls passed; no lifecycle claim from command dispatch |
| Documentation and cleanup | Root: corrected Player Guide, consolidated active queue/resume/index, removed five exact redundant Python bytecode caches | Technical inventory + Experience independent review; 43,602 cache bytes removed; original .py files preserved |

Source, native presentation, Full and delivery gates passed for this exact build.
They do not establish a performance gain or human comfort; those remain separate.

## Design basis and scope

- Environment relief uses stable lighting planes and material contrast, following
  the static-map shading described in Riot's [League graphics pipeline](https://www.riotgames.com/en/news/trip-down-lol-graphics-pipeline)
  and
  Riot's [VALORANT rendering/clarity discussion](https://www.riotgames.com/en/news/valorant-shaders-and-gameplay-clarity).
  H.E.X. compiles relief into its existing setup-only textures. The existing 41 wall
  footprints, one texture submission per wall and 2,248,960 decoded wall bytes
  are intended to remain unchanged. Relief is visual, not new walkable elevation.
  The two architectural facade replacements add 82,176 decoded bytes to the
  existing eight-building cache (779,264 to 861,440 bytes), without retaining the
  replaced roof textures. This changes apparent proportions within existing
  footprints; it does not add walkable rooftops or vertical collision rules.
- Camera controls preserve direct input and optional stable framing, informed by
  the [Titanfall controls developer interview](https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right).
  H.E.X. retains its own bounds, smoothing, aim inverse and focus policy.
- Optional Range results expose already measured status consequences using
  progressive disclosure. [Riot clarity](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/)
  supports outcome comprehension and limited noise; these results describe one
  practice window, not balance rankings or damage attribution beyond authority.
- Profiling follows Riot's [measurement-first performance work](https://www.riotgames.com/en/news/profiling-case-missing-milliseconds).
  A current-source foreground diagnostic must distinguish source instrumentation
  from packaged-release performance, CPU submission from GPU/present latency,
  and steady gameplay from arrival work.

## Preserved state and cleanup boundary

The original desktop shortcut bytes are retained at
`C:/Users/sende/Documents/ChatGPT/H.E.X/output/desktop-shortcut-before-20261013-depth.lnk`.
It previously targeted the separate FLUX checkout. The corrected target is
`C:/Users/sende/Documents/ChatGPT/H.E.X/PLAY-HEX.cmd`, which delegates to
`scripts/launch-hex.ps1`. No-argument play reads `docs/current-delivery.json`.

Removed caches were exactly the CPython 3.14 bytecode for
`build_cardinal_champion_atlas`, `build_foundation_champion_sprites`,
`build_red_baron_foundation_atlas`, `create-release-tar` and `fetch-export-templates`.
Both reviewers confirmed original sources, ignored generated status and no exact
references. Historical redirects/receipts, original art, saves and working
portables were not classified as disposable. Repeated active narrative is
recoverable in Git 38f1bc3; no second historical task queue was created.

## Validation

- Source-only PR selection: **46 assertions passed**.
- Source-only current-delivery contract: **22 assertions passed**; actual README
  and Player Guide match the qualified descriptor.
- Launcher inspect and three invalid-argument controls pass without launching.
- Supervised launcher route: **32 pure admission/parser assertions passed**;
  all five retained 7804 logs satisfy the stricter exact workload parser. The
  actual desktop wrapper's `-Lifecycle -Inspect` validates the qualified package
  without launching or changing its selection. The later fresh lifecycle and independent review are recorded below.
- First identity-generation command intentionally refused replacement without
  its explicit `-Force` switch; no engine/test began and no manifest was changed.
- Two subsequent Fast preflights found missing documentation contract statements:
  the active playable count in the queue and an explicit Status in `docs/README.md`.
  Both statements were restored; neither run reached the engine. Failed receipts
  remain in `.godot/receipts/depth-clarity-fast-b.json` and `depth-clarity-fast-c.json`.
- Fast gate passed for **p61-3d987cf79dbd**: source/documentation invariants,
  pinned-engine import, post-import identity, class-cache check and 120 Hz boot;
  zero stderr. Receipt: `.godot/receipts/depth-clarity-fast-d.json`. Fast executes
  no unit suites; the changed suites remain a separate gate.
- First Focused run completed seven selected suites with zero assertion failures,
  but could not instantiate the Range suite: a new test alias shadowed Godot's
  built-in `Panel`. The exact three-reference rename to `RangeScenarioPanel` was
  independently reviewed; production bytes and assertions were unchanged.
  The failed run and original test are retained for diagnosis.
- The combined Focused retry hit its unchanged 180-second engine limit after
  three successful suites, with empty stderr. Its new Range test redundantly
  serialized the whole world twice per tick. Reviewed sampling now checks the
  meaningful purity boundaries while retaining all 600 paid steps and six
  independently counted status channels. The run was split into bounded groups.
- Settings/Range/wall group passed **5 suites / 22,598 assertions**, zero failures
  and stderr: `.godot/receipts/depth-clarity-focused-settings-c.json`. Range took
  1,802 ms; this is test execution time, not a gameplay performance measurement.
- Navigation/learning/tools group passed **3 suites / 68,673 assertions**, zero
  failures and stderr: `.godot/receipts/depth-clarity-focused-learning-d.json`.
  Together these bounded runs cover all eight changed suites with 91,271 assertions.
- Native texture sheets passed **112 checks / 2 captures**, with independent
  visual review at 75% and 100%. Settings-panel captures passed **96 checks /
  4 captures** and independent visual review at 960×540/200% and 1280×720/100%.
  Receipts are under `.godot/iteration-20261013/environment-depth/runs/sheet-c`
  and `panel-a`. Native helper alias failures and an invalid grounded wallrun
  setup were retained and corrected. Native world-b then passed 248 checks / 4 captures with both independent visual reviews: actual paid jump-to-wallrun, unchanged world/layout and readable current character at both contacts.
- The first architectural prototype passed 219 native checks but was rejected
  by visual review: smooth facades conflicted with the existing pixel masonry.
  The refined version reuses the approved facade tile at its original pixel
  scale. Native-c passed **219 checks / 6 comparison captures**, zero stderr,
  with independent acceptance of all six views. Its adapter alias repair and
  the rejected flat version remain preserved under the ignored prototype folder.
- Canonical architecture is integrated. Import passed without errors; provenance
  changed only the existing 64-byte kit hash, preserving all 133 resource files.
  Native parity passed **260 checks / 6 captures**, with zero stderr: every RGBA
  pixel matched both the accepted prototype renderer and its saved native-c
  capture, while world/layout/tick/paid-flight/body state matched as well.
  Receipt: `.godot/iteration-20261013/architecture-prototype/parity-runs/canonical-a/receipt.json`.
- Final terrain focus passed 5 suites / 3,894 assertions. Full passed 265 suites / 7,574,438 assertions with zero failures/error output and 120 Hz boot; see [Full receipt](depth-clarity-evidence-20261014/full.json). Portable export, all 18 archive checks and isolated exact decoding of all 133 terrain images passed. See [package](depth-clarity-evidence-20261014/package.json), [archive](depth-clarity-evidence-20261014/delivery-files.json) and [terrain](depth-clarity-evidence-20261014/terrain-pack.json). The five desktop-wrapper lifecycle cases also passed: both paid cases admitted and released exactly 12 casts, with zero refusals. The [independent delivery review](depth-clarity-evidence-20261014/delivery-review/review.json) passed **4,076 checks** and links the exact source/package evidence. Qualified delivery is now 6459, with 7804 preserved as fallback; current-build foreground performance remains unmeasured.
  Player comfort, physical controls, listening quality and
  physical two-PC acceptance remain distinct.
