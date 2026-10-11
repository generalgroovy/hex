# Six-element combat and dynamic movement

Status: **preceding p59 design, locally qualified October 9, 2026**. This record describes
the preserved 24-spell build. The current expansion is defined in [SPECIFICATION.md](../SPECIFICATION.md).
The [single execution queue](../.agent/OVERHAUL-IMPLEMENTATION.md) tracks the work.

## Player contract

- Six selectable ingredients in this order: Water, Fire, Air, Earth, Light, Dark.
  Ice is part of Water's effects; Charge is part of Fire's effects. There are
  four delivery families per element, 24 selectable spells and twelve weave slots.
- All 57 distinct combinations of two through six ingredients are defined, plus
  six same-element reactions. Every result deals bounded damage and has an
  additional situational, movement, visibility or terrain role. Definitions must
  explain the warning, payoff, escape and counter, and have a real runtime test.
- Frequent readable fire and deliberate volleys support bullet-hell tempo.
  Repeat fire retains real payment, capacity, source ownership and cooldowns.
- Movement chains connect slides, gathered jumps, air redirects and wall exits
  through existing controls and finite paid budgets. Non-fliers tuck into a ball
  for jumps and double jumps; fliers use a deliberate airborne second jump to
  enter finite flight. Visual cadence can be slower without delaying controls.
- Invulnerability and intangibility have different visible cues tied to the
  actual simulation windows. Normal and reduced-effects presentation must agree.
- The 21 ancestry and 30 personal situational passives remain. No new ability
  buttons, copied proprietary assets or blanket stat increases are required.

## Reference basis and limits

The earlier [reference audit](REFERENCE-IDENTITY-REFINEMENT.md) and its movement,
combat and menu evidence remain the source trail. Magicka's shared vocabulary and
[Magicka 2's base/hybrid distinction](https://www.paradoxinteractive.com/games/magicka-2/about)
support a compact ingredient selection with deeper results. [Noita](https://www.noitagame.com/)
supports readable material and environmental consequences. The [Gungeon developer
interview](https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-)
supports responsive defensive play, environmental combat and optional execution
depth. [Respawn's controls interview](https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right)
and [Firing Range redesign](https://www.ea.com/ea-play/news/arsenal-season-game-updates)
support deliberate momentum control and practice routes organized around real
actions. Melee and STRAFTAT remain movement references from the specification.
Specific H.E.X. numbers and the six-element requirement are authored decisions;
these sources do not prove this implementation balanced or enjoyable.

## Authority and compatibility

Preserve canonical element wires Earth1, Fire2, Water3, Air/internal `wind`4,
Light7 and Dark8. Wires5/6 remain historical and are refused as live ingredients.
Protocol 59 rejects incompatible sessions; packet decoders never migrate IDs.
Old local saved weaves have a deterministic, per-slot migration preview. Preserve
canonical positions and original bytes; apply only after the player's existing
Apply action, with an exact old-file backup before persistence.

The interaction mask uses Earth1, Fire2, Water4, Air8, Light16 and Dark32. Existing
pair/self recipe wires remain stable; larger combinations use `400 + mask`.
Sources are sorted, unique and bounded to twelve. Fusion consumes its parents
atomically and must add an ingredient. It transfers only remaining material and
damage funding, retains the earliest expiry and carries prior contact latches.
It cannot restart a spent damage pool, reuse a consumed source or create an
unbounded cascade. The initial funding hypothesis is four Health per consumed
strength unit; actual Health loss across all victims debits that shared pool.
Individual hit doses, control effects, reach and duration remain independently
bounded. Chemistry snapshot 4 includes masks, original formation ancestry,
funding, remaining damage and once-per-actor contact use.

## Qualification

Required: all-combination definition/role checks; real pair-to-six execution;
ordering, continuation and malformed-state tests; exact matter and damage-pool
conservation; team/protection/counter controls; saved-weave preview and cancel;
real movement/cast input journeys; inspected native animation/protection samples;
complete suite and exact-source Windows export/startup/safe-close.
Keep failures and pre-edit evidence. Human balance, sustained dense 120 Hz,
continuous-motion acceptance and different-home multiplayer remain separate.
