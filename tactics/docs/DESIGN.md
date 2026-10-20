# H.E.X. Confluence — simultaneous rules v3

Confluence turns H.E.X.'s elemental combat into a contest of simultaneous team plans. Both players choose where their three champions will move and where their spells will land, then reveal the result together. The central decision is where the opponent will stand after movement, and whether to attack that place, protect a well or combine elements there.

The setting, six named identities and original portraits come from H.E.X. The numerical rules, tactical roles, spell labels, dialogue and code-drawn battlefield figures are authored for Confluence. They do not establish new canonical biographies or abilities. [SOURCE-PROVENANCE.md](SOURCE-PROVENANCE.md) records the boundary.

## Plan, lock, resolve

Each team drafts three different champions; opposing teams may repeat the same identities. Every champion has five Health. In each round, every living champion can move and cast, or move and Guard. Movement is optional. An unassigned champion holds position and Guards. There is no shared action-point budget, first-player turn or opening handicap.

The interface lets the player select a champion, plot movement, aim a spell at a hex and revise those orders before locking the whole team. Targets stay fixed to the ground; they do not follow a moving enemy. A locked plan cannot be edited. The other player sees the lock status but not the orders. Practice AI chooses from the same public board without access to the player's plan. Hotseat places a handoff screen between the two private planning phases.

A round resolves in this order:

1. **Movement:** apply all destinations together. Multiple champions requesting the same destination bounce. A champion cannot enter a hex whose occupant stays or has a blocked move. Valid swaps and cycles can succeed. Paths may cross occupied hexes; destination occupancy decides the result.
2. **Spells and chemistry:** check each aim from the actual landing position. A failed move may leave the spell out of range or sight, causing it to fizzle. All valid spells are collected before damage. Incoming elements from both teams combine with the existing surface.
3. **The exchange:** aggregate damage and healing before changing Health. A caster defeated in this exchange still completes the recorded spell. Guard and Steam reduce combined damage. Surviving unguarded targets receive simultaneous Air pushes; conflicting destinations bounce and competing winds can cancel.
4. **Terrain and points:** Magma burns its final occupants. Surviving well occupants score. Both teams' scores settle before victory is checked, and terrain lifetimes advance.
5. **The next round:** if play continues, champions due to return respawn near their home side. Both teams plan from the same resulting board.

## Movement, height and roles

Movement has a budget of two effort points. A normal adjacent step costs one. Climbing to higher ground, or entering or leaving Quagmire, costs two. Four mirrored raised hexes make route and firing position matter. Normal spell range is two; a raised caster can reach a lower hex at range three. Raised ground blocks low-to-low sight when neither shortest route around a hex-edge tie is clear.

| Champion | Element | Spell before reductions |
|---|---|---|
| Oh Tipi | Water | Hit the occupant for 2, including a friend; contribute Water |
| Wa Bidi | Fire | Hit the occupant for 2, including a friend; contribute Fire |
| Grace Riva | Air | Hit for 1, including a friend; push an adjacent surviving occupant unless guarded |
| Treevor the Mason | Earth | Hit the occupant for 2, including a friend; contribute Earth |
| Haara | Light | Heal a friendly occupant by 2, including the caster, or hit an enemy for 2 |
| S. Wayne | Dark | Hit for 2, including a friend; siphon 1 Health from an enemy on a pre-existing Dark surface when spell damage gets through |

Guard trades the champion's spell for one point of absorption from the combined spell damage and immunity to pushes for that round. Steam halves the combined damage first, rounded up; Guard then subtracts one. It does not prevent Magma damage. Light healing and Dark siphoning participate in the simultaneous Health exchange, capped at maximum Health.

Friendly fire is part of planning. A teammate may move into a targeted hex, or fail to leave it. Previews disclose the player's own planned friendly-fire risks and combinations, but cannot promise an exact final result while the rival's orders remain hidden.

## Shared elemental surfaces

| Ingredients | Reaction | Consequence |
|---|---|---|
| Fire + Water | Steam | Halve combined spell damage on that hex, rounded up |
| Fire + Earth | Magma | Deal 1 environmental damage to the final occupant after spells and pushes |
| Water + Earth | Quagmire | A movement step entering or leaving the hex costs 2 effort |
| Light + Dark | Penumbra | An occupied well scores 2 rather than 1 |

Ingredients accumulate with incoming spells, regardless of which team cast them. Several reactions can coexist on one hex: Fire, Water and Earth produce Steam, Magma and Quagmire together. A cast refreshes the surface's two-round lifetime. Without another cast, the surface participates in its creation round and the following round, then clears. These rules use H.E.X. reaction names but adapt their effects to this game; the real-time source has different numbers and interactions.

Surviving champions on the three wells score one point each after the entire exchange, or two on Penumbra. A defeat gives the opposing team one point, including a defeat caused by friendly fire or terrain. Downed champions miss the next full round, then return at full Health near home. Returning occurs after scoring and cannot grant an immediate well point.

At least eight points and a lead wins after a completed round. A tie continues. Round sixteen resolves normally, then higher score wins or equal scores draw.

## Counterplay and readable outcomes

A strong plan should have a response the opponent could reasonably anticipate. A spell aimed at a valuable well can be dodged. A Guard can preserve an occupant but gives up its spell. A coordinated push can remove an unguarded holder, while conflicting winds or blocked destinations can defeat the displacement. Steam can emerge from the opponent's Water meeting your Fire. Magma punishes a final position; Quagmire changes the next route; Penumbra creates a prize either team can claim.

The interface shows planned destinations, spell targets, terrain and Health, then animates movement, spell exchanges and scoring. Replay temporarily disables planning and preserves the board's zoom. On a phone, the board can be enlarged and the action dock keeps Move, Aim, Guard and Lock accessible. The handoff dialog traps focus while local plans are hidden. These implementation choices need physical-device and human acceptance; browser layout checks alone do not prove comfortable touch play.

The six spell labels and short character remarks are new Confluence writing. Their purpose is to make the company recognizable during repeated play. They are not quotations from H.E.X. canon, and Light's tactical healing role does not turn Haara's canonical identity into a healer biography.

## Remote integrity and older matches

The public app uses private twelve-character invitations and separate anonymous player keys. A key authenticates a seat; the invitation does not contain it. The server validates each plan against the public round state and stores pending plans privately. Snapshots return readiness flags and only the authenticated player's own locked plan.

Both players can submit from the same baseline. Atomic database updates merge the locks and publish a single resolution. Identical retries do not advance the game twice. Each plan includes the game's `matchId` and round number; the match identity changes on rematch, preventing a delayed old round-one request from entering a new game. Room revisions count persistence changes separately from game resolution versions. Rooms expire seven days after creation.

Existing v1/v2 games retain their alternating rules and Classic interface. They are not converted mid-match. Current-protocol consent from both players starts an online v3 rematch; older queued consent does not opt a player into changed rules. Local saves are validated before installing or overwriting them, including saved hotseat plans and mode/seat relationships. Unsupported or corrupt data is retained for recovery.

## What the evidence establishes

The final deterministic fixture runs 120 games across all twenty squads against complementary squads, three cyclic deployments, two related public-state policies and exchanged seats. It produced 60 wins for each seat and 598 mirrored round-state comparisons. This supports geometric and resolution symmetry for those cases. It does not establish equally strong squads, skilled human play or enjoyment.

One bounded Light comparison retained enemy damage 2 with friendly healing 2. Squads containing Haara won 46 of 120 final games, compared with 36 in the saved baseline. That is a squad association confounded by teammates, opponents, deployments and AI decisions, not a measurement of Haara in isolation. The final range still runs from 46 to 74 wins among champion-containing squads. The shallow bots also fizzle spells; their observed pace and decisions are not a human benchmark. [V3-VERIFICATION.md](V3-VERIFICATION.md) records the exact artifacts and remaining checks.

## Bounded human acceptance

1. **Learning:** observe six new players without coaching. Record whether they can explain simultaneous movement, fixed-hex aim, friendly fire and the difference between editing and locking. Ask each to predict one collision or reaction before resolving it.
2. **Phone control:** observe four people across iOS and Android devices planning, revising and locking a team. Record missed targets, accidental locks, zoom recovery and whether the action dock obscures useful board information.
3. **Seat and role checks:** play twelve paired duels, twenty-four games total, with unchanged squads and exchanged seats. Include Air counterplay, Light support, Dark setup and mixed-reaction positions. Treat the results as defect finding, not statistical proof of balance.
4. **Reaction value:** use one prepared position per reaction to test creating, exploiting and answering it. A reaction that cannot earn its planning cost needs revision before roster expansion.
5. **Remote completion:** use two pairs on separate networks. Include a reload while locked, a temporary disconnect, simultaneous locks, identical final scores and a mutual rematch. Also finish an older Classic room and move it to v3 by consent.
6. **Voluntary replay:** after a completed duel, offer a rematch without prompting approval. Record whether players choose it and what they want to try next. Establish a baseline before setting retention targets.

The breakthrough ambition is a duel people can understand, retell and choose to replay. Functional checks and symmetric bots make that proposition testable; they do not establish human mastery, adoption, retention or commercial success.
