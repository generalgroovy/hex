# Cooperative game audit and optimization

Date: 2026-10-16. Baseline source: `98d70bba4f5bc674f44753b846d5369b4c73bf2d` (public Sites version 8). This pass improves the trustworthiness of planning, the legibility of simultaneous exchanges and recovery when playing remotely. It preserves the original pixel atlases, parchment visual language, seeded 127-hex maps, 30-character roster and four-spell system.

## How the review was conducted

Three specialists independently examined mechanics/tactical decisions, interface/visuals/audio, and input/storage/network reliability. One integration owner assembled their work. Each specialist challenged another's findings and reviewed the integrated code. The raw materials were the current resolver and spell definitions, actual event arrays, seeded positions, DOM and screenshots, real SQLite room behavior, HTTP exchanges, and rendered Web Audio samples. Earlier prose and bot reports were treated as context, not fresh proof.

The cross-review corrected several initial assumptions: movement already landed at approximately 420 ms within its longer CSS timeline; zero-point score events are routine and must not create victory sounds; the host's waiting-to-active transition already installs the correct game because the server changes the match identity from null to a UUID. Those findings were corrected before release rather than being presented as fixes.

## Agreed optimization plan and implementation

| Observed evidence | Player consequence | Implemented change | Acceptance evidence |
| --- | --- | --- | --- |
| Hover could supersede a pinned draft in the rendered footprint while Confirm used the draft | The displayed aim could differ from the committed spell | Draft target has precedence until re-aim/cancel; explicit confirmation remains | Browser: pin Water Jet at -2,0, move keyboard focus to -1,0, confirm; order remains -2,0 |
| No reversible order history; movement can invalidate a committed cast | Accidental edits require reconstructing a plan | Twenty-step in-round Undo, U shortcut, cancel-preview behavior and explicit invalidation notice | Browser Undo restores prior Guard/order; lifecycle reviewed for locks, new rounds and hotseat privacy |
| Same-team destination conflicts were legal but unexplained | Avoidable bounces and out-of-range fizzles obscure the simultaneous rules | Pure public-state plan analysis; known conflicts versus conditional rival risks; company-wide order review; friendly harmful-footprint warnings | Seven insight tests; browser two allies at -4,1 plus Tidal Surge at -4,4 produces collision and certain-fizzle warnings; relocating one ally removes the guaranteed warning |
| Most current status invariants were tested only against older engines; enemy Cauterize could reintroduce a friendly-cleansed Burn | One rare ownership violation and weak current-engine regression evidence | Friendly-only Cauterize ownership condition; 26 direct v6 combat regression tests | Tests cover cleanse, Wet, Guard, Resolve, recovery, displacement and simultaneity, including the original failing interaction |
| Global shortcuts could consume modified keys or typing contexts | Text entry/browser actions could alter orders | Shared input filter ignores modifiers, IME, repeats and editable contexts; M/G/U/Esc/1–4 documented | Input tests; browser keyboard aiming and Undo; modal checks by independent review |
| Successfully claimed guest seat could become inaccessible after the success response was lost | Friend sees a full room despite owning its second seat | Client-generated retained join identity; idempotent join recovery including concurrent claims | SQLite regressions and 28-check HTTP full-match test; wrong identities still rejected |
| Unsealed online orders vanished on reload; storage warnings could disappear on selection | Lost planning work and misleading recovery confidence | Validated draft persistence scoped by room, match, round and seat; authoritative sealed plans win; persistent storage fallback notice | Six client-session tests; real browser reload restores an unsealed seeded online order |
| Exchange report privileged event order over meaningful outcomes; reaction labels flooded cells | Points, defeats and tactical consequences were easy to miss | Visible score/consequence strip; prioritized detailed report; positive-score field labels; three labels per cell plus explicit overflow | Feedback and renderer checks; real exchange shows damage/status summary on 320 px layout |
| Cast/movement timing differed and late labels could outlive playback | Visual feedback looked disconnected or cut short | Shared 2800 ms timeline: landing/casts 450 ms, reaction/push 900 ms, scoring 1700 ms; stable replay callback | Timing tests, renderer inspection and browser replay returns control |
| Generic chime for all resolution outcomes; incomplete audio lifecycle | Weak information and unreliable mute/unlock behavior | Opt-in element-pitched cast, reaction, impact, block and score cues; bounded voices; cancellation, disposal and unlock failure handling | Ten feedback/audio tests; real browser module renders non-silent PCM with zero clipping and accepts playback gesture |
| Phone inspection hid useful terrain information; statuses were nested | Extra taps to understand current tactical constraints | Full terrain/effect lifetime/occupant readout; selected statuses beside primary controls; compact review | 390×844 and 320×844 browser viewports; no horizontal page overflow, readable Chilled/Resolve/Wet and reduced movement effort |
| Plan simulation and risk analysis reran on unrelated hover updates | Unnecessary input-path work | Memoized both computations by game, seat, plan and planning availability; summary memoized separately | Source dependency review; isolated Node probe established the avoidable work (not an FPS measurement) |

Detailed specialist findings: [mechanics](AUDIT-MECHANICS.md), [experience](AUDIT-EXPERIENCE.md), [reliability](AUDIT-RELIABILITY.md).

## Compatibility and scope

This remains protocol/rules 6, with no schema migration, seed-generator change, spell legality change or save-format change. Frozen older engines remain intact. The Cauterize condition is a deliberate correctness hotfix: a pending v6 exchange containing that rare enemy-Cauterize/friendly-cleanse combination resolves with the corrected behavior after deployment. Exact resolver parity with the previous v6 build is therefore not claimed.

The original character art and source-backed affinities remain the visual and mechanical foundation. No new passive tree, campaign, monetization, matchmaking system or arbitrary balance patch was introduced. The improvements expose and support the existing tactical depth.

## Fresh verification and limits

- All 208 automated tests pass, with no failures, skips or cancellations. TypeScript checking passes.
- Development and isolated local production HTTP tests each pass all 28 check groups and complete a 12-resolution match at 8–5. They check seat recovery, authentication, protocol, loadouts, sealed orders, duplicate locks, peer equality, stale requests and rematch geography. The production build passes.
- Browser checks cover pinned aim under keyboard focus changes, Undo, certain versus conditional fizzle warnings, allied exposure, seeded host activation, guest joining, online draft reload and sealing, authoritative sealed-order reload, narrow layouts, visible statuses, exchange summary and replay.
- Actual audio-module offline rendering: 3 seconds, mono 44.1 kHz, 132300 frames, peak 0.02910464, RMS 0.00318417, 37877 nonzero samples, zero clipped samples. Real-context playback was successfully requested from a user gesture. The temporary audio harness was removed before packaging.
- Production build, exact pushed source, deployment result and public checks are recorded separately in the delivery's release receipt. That receipt avoids circularly embedding its own commit identity in source.

The first live verification passed the full 28-group remote match test. Its desktop screenshot exposed excess reserved space around the review/Undo row and an inherited absolute position on the shortcut badge. A small CSS follow-up removes the duplicated spacing and keeps the badge in the button flow; this was included in the final visual verification.

The earlier 168 bot-match diagnostic is historical evidence from its recorded source; it was not rerun for this audit build. The new tests are correctness and interaction evidence, not proof of a solved metagame or commercial appeal. Browser phone viewports do not establish physical touch-device usability. Audio signal bounds do not establish subjective quality on phone speakers. No gameplay-FPS claim is made.

An initial production smoke used the same local D1 persistence directory as the running development server and hit a Miniflare internal database error (HTTP 503); an immediate rerun hit the durable create-rate limit (429). Neither run is counted as passing. Development was stopped and production was started against a newly migrated, isolated scratch database; the unchanged application then passed the full test. This is consistent with local shared-state contention, not proof of a hosted database defect. The smoke now reports unexpected service errors directly without dumping credentials or silently retrying them.

## Subsequent interface cleanup

The next pass removes promotional labels, invented character quotations, repeated instructions and provenance claims from the current player interface. Play and Resume precede setup; character replacement, map configuration, older saves and reference information open on demand. Selected spell effects are visible while aiming. Opponent inspection no longer requires two nested disclosures. All 48 spell and 12 status descriptions state mechanical consequences and preserve timing qualifications. Wells show +1 or Penumbra +2; phone camera controls retain text labels.

Practice scoring now includes damage bonuses from existing Burn, Wet and Wither. The practice rival S. Wayne carries Reap; player defaults and combat rules remain unchanged. Independent specialists checked mechanics, wording and renderer changes. The 214-test suite, TypeScript and production build passed. A fresh isolated production database passed all 28 HTTP groups and a 12-resolution match. Browser checks covered quick start, loadout editing, character replacement, map setup, aiming, confirmation, Undo, resolution, opponent kits, local handoffs, host/join and locked-order reload. Viewports of 390 and 320 CSS pixels had no horizontal page overflow; the four-button replay/overview/effect/pan toolbar fit at 320px.

The development database had exhausted its room-creation quota from accumulated testing; its 429 response was correctly displayed and is not counted as a successful host test. Production checks used a separately migrated scratch database. Publication and live checks are recorded in the delivery receipt. These checks do not replace observed human matches or physical phone testing.

## Remaining research questions

1. **Character identity:** 17 of 30 characters belong to eight repeated affinity profiles. Identical profiles with identical loadouts are mechanically equivalent. Stronger identity needs a separately evaluated design, not invented passives during a reliability pass.
2. **Practice opponent coverage:** conditional-bonus scoring is now covered by prepared positions and appears in ordinary practice diagnostics. Barrier valuation and broader area decisions still need human-readable scenario tests; do not infer spell weakness solely from bot usage.
3. **Strategic map variety:** determinism, connectedness and mirrored fairness are tested; those do not prove that seeds offer distinct winning approaches. Compare routes, timing and well-control choices in observed human matches.
4. **Learnability and mastery:** observe new players completing their first meaningful simultaneous combo, then experienced pairs adapting to the same seeded position. Measure mistaken targeting, unnecessary undo, unexpected fizzles and ability to explain score changes. Human playtests, repeat play and competitive adaptation must establish the indie-hit hypothesis.
5. **Recovery boundary:** private seats belong to browser-held keys. Cross-device transfer and recovery after all storage is lost remain outside this pass. A lost host-create response can leave an unused waiting room; it does not strand an active opponent.

The next optimization should be chosen from those observations rather than expanding the catalogue by default.
