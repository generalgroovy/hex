# H.E.X. release 45

This pass makes the existing elemental rules easier to use, adds restrained character reactions, and gives Tower parties a small equipment vocabulary. The canonical cast, simultaneous movement/casting, elimination victory, and private co-op seats remain the foundation.

## Rules and decisions

The Guide compares the six elements by tactical use, drawback, and ground effect. Its mixture filters identify shelter, recovery, movement, pressure, control, and Flux opportunities. Map & aim compares natural terrain and spell shapes. Status rows distinguish effects that apply immediately from effects that affect the next exchange. Hover, keyboard focus, or tap opens the additional rule and examples.

Natural Water and Earth are mixing ingredients, not automatically active Flood or Rough fields. Ice, Wet, Ward, Clarity, cover, and field duration have separate explanations. Creature fixed techniques are inspected as creature techniques instead of being incorrectly judged against their appearance champion's learned library.

Story and Tower character configuration support direct spell dragging and Alt + arrow slot swaps. Existing click/tap selection remains available. Every placement still uses the legal character spell rules; moving an equipped spell swaps slots instead of duplicating it. Tower room legend controls explain costs and consequences on demand.

## Tower supplies

New runs have one charm slot and one scroll slot per fighter. There is no bag, stacking inventory, or permanent stat inflation. Reward selection still offers at most three choices.

- Four charms grant a limited opening condition: Ward, Haste, Clarity, or Anchored.
- Six scrolls provide a bounded elemental toolbox. Each allows one printed-strength cast for zero Flux regardless of affinity. It uses the fighter's normal casting action.
- A scroll is consumed when released, including an intercepted shot. Planning, undo, or a blocked landing that prevents release does not consume it.
- Rewards explicitly choose a recipient and show replacements. Existing supplies can be given or swapped between fighters between rooms.
- Native legality, forecasts, actual effects, save restoration, and the co-op service share the scroll contract.
- Supply choices appear on selected combat or elite floors (1, 2, 4, 7 and 8). They preserve affinity training and needed recovery; camp, recruitment and tuition rooms retain their existing purposes.

Existing runs retain their earlier reward model. Existing battle profiles retain their targeting and strength rules.

## Presentation

Thirty champion voice sets and separate creature reactions respond to recorded combat events. Only one speech bubble is eligible at a time. Placement avoids fighters and health feedback; repeated causes are throttled. Speech does not announce hidden commitments or invent a missed attack from zero damage.

Speech placement considers the actual edges of damage and status readouts. If a narrow or crowded view has no safe nearby space, it omits the bubble. Portrait phone battle headers give the five phases a separate evenly spaced row.

Planning fields use a bounded set of pixel material accents. Existing scenery stays still. Burn and Concussion have restrained condition animation. Audio distinguishes critical hits, recovery, burning, fizzles, blocking, elemental materials, and outcomes. Separate UI and combat buses let volume changes affect already scheduled playback; mute and disposal retain immediate ownership of all voices.

## Review and verification

Three implementation lanes were reviewed across ownership boundaries, with integration checking the actual browser and production Worker. The final delivery record identifies the tested source, archive, regression results, browser measurements, and publication separately.

Peer review specifically checks attribution when surface damage accompanies a knockout, speech history between battles, silent-to-audible playback, scroll consumption and ownership, current versus legacy spell descriptions, and touch-accessible inspection.

Validated before publication:

- 1,442 native regression tests passed, with no failures or skipped tests.
- Full TypeScript checking and the official Sites production build passed.
- Production Worker HTTP/D1 checks passed: six-player Arena (636 assertions), six squads in one Tower room (3,774), and six squads across three paired rooms (4,031). The completed runs issued 652 requests.
- Concurrent network suites elicited transient local 503 responses. Tower retried successfully without duplicate actions; the older Arena checker was rerun independently and passed. This is not a production capacity test.
- A production-browser save export/import retained the disposable test run. Combat replay, status inspection and reference tables worked at 1280×800, 390×844 and 790×444 CSS viewports; the tested views had no horizontal document overflow. Desktop result speech cleared actors and readouts. Crowded phone views deliberately omitted speech.
- One-seed opening diagnostics covered seven proposed starters and a custom two-champion party: eight wins, 64 exchanges, median eight exchanges, range four to twelve. These openings had no earned supplies and are not evidence of later-floor or equipment balance.

Automated rules and protocol checks do not establish human enjoyment or complete balance. CSS viewport checks do not establish physical phone performance. No physical-device listening or unfamiliar-player study is claimed.
