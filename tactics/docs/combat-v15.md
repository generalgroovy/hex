# Elimination combat and readable exchanges

Rules 15 changes victory from well scoring to eliminating the opposing three-character team. Defeat is permanent for that battle. All submitted spells and resulting fields, displacement and damage resolve before checking victory. Both teams defeated in that exchange is a draw; neither team eliminated after round 20 is also a draw. Remaining health never breaks a tie.

Existing wells are Flux springs: an occupied spring restores 1 extra Flux at recovery, or 2 with a spring-enhancing field, capped by maximum Flux. The compatibility scores tuple remains zero. Practice AI now seeks useful attack positions and vulnerable enemies rather than pursuing scoring income.

## Presentation contract

- Planning: editable private move and spell/Guard for each standing character.
- Movement: 0-1800 ms, all routes shown together before spells begin.
- Casting: anticipation begins together at 1800 ms; all projectiles release at 2200 ms and travel 2600 ms, arriving together at 4800 ms.
- Effects: 4800-6400 ms, fields, reactions and forced movement.
- Review: health and status outcomes at 6400 ms; animation ends at 7800 ms. Review remains until explicit Continue. Show result skips animation; Replay reuses public resolved events without changing the draft or resolving again.

All six characters have a persistent phase-specific action readout. Planning controls and floating text stacks are hidden during playback. Reduced motion changes position at phase boundaries and does not expose future effects. The review camera includes stationary characters and keeps its framing until planning resumes. Phone review uses three paired rows beneath the map and visible 44-pixel-or-larger controls.

Only public adjacent snapshots and lastResolution feed playback. A reconnect that skips versions installs the authoritative state without inventing a missing exchange. Hotseat handoff waits until review ends. Match completion waits for review before showing the final result.

## Compatibility and validation

New matches use rules/protocol 15. Rules 14 authoritative combat remains unchanged, including resurrection and points. Historical routes use current transport for reads and rematch consent, while retaining their historical resolver, action format and save keys. Story victories and affinity allocations retain their existing persistent key. New kits and local matches use version 15 keys and read older kits without rewriting older match bytes.

Meaningful automated checks cover simultaneous final wipes, no healing revival, spring recovery/caps, canonical saves, concurrent room locks, sealed-plan privacy, idempotent retries, old pending-plan bytes, replay/draft preservation, reconnects, rematches, hotseat handoff and every phase boundary. A bounded four-seed default-versus-practice audit finished by elimination in rounds 9, 9, 15 and 10, split two wins each. This sample verifies playable completion, not competitive balance or human enjoyment.

Browser checks, packaged Worker HTTP checks and release provenance are recorded separately from automated model tests.
