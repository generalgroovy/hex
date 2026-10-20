# Turn editing and battle feedback

This pass keeps rules and network protocol 13 unchanged. Four specialist reviews covered tactical correctness, battlefield feedback, compact interfaces, and independent controller verification.

## Player-facing changes

- The selected character has direct Move, Hold, spell, and Next controls. Hold removes only movement, preserving a legal cast or explicit Guard. Changing the origin removes an impossible cast with an inline explanation and one-step Undo.
- Company cards show queued destinations and spell targets. The selected route stays visible with movement effort and destination. Known allied blockers and uncertain rival occupancy have different markers and accessible descriptions; allied swaps and movement cycles remain legal.
- The movement preview and field forecast share the same allied movement projection. Rival orders remain private. A preview reports what the player can know, not a guaranteed enemy response.
- Health feedback reports actual net health change, avoiding overheal numbers and healing flashes on respawn. Movement faces the first actual path segment before turning to cast.
- The phone workspace places core spells above the fixed command dock on the tested 390 by 844 and 320 by 705 layouts. Optional detail expands below. Shorter screens scroll; controls remain reachable. Wide phones put the spell hand beside the map.
- Finished matches replace the order tray with scores, the ending reason, Story reward status, Play again, and a return action. Phone layouts lead with this result. The compact scoreboard retains the round number instead of squeezing in a winner name.

## Verification

The automated suite passed 624 tests before the final scoreboard text simplification. Focused controller tests cover preserving casts and Guard, clearing an illegal cast, respecting locks and movement limits, and exact Undo restoration. Movement tests include blockers, duplicate destinations, dependency chains, swaps, cycles, Ice paths, and hidden rival orders. Health tests cover overheal, mixed damage and healing, defeat, and respawn.

Browser checks exercised Hold preserving a legal queued spell, a complete seven-round Story loss, the result layout, and Play again returning to round one. Responsive checks cover 390 by 844, 320 by 705, 320 by 567, 666 by 662, and 1200 by 900 CSS viewports. These are desktop browser viewport checks, not physical-device performance or human playtest evidence.

Release-specific build, HTTP, publication, and browser evidence is recorded separately in the workspace's `work/next-release-verification.json` after publication.

The first production browser pass caught an asset-order difference: legacy v9 mobile rules could override the current spell grid even though the development layout passed. The battle workspace now uses explicit current-battle specificity and defines its complete compact spell layout, so correctness does not depend on stylesheet arrival order. This correction is checked against the packaged Worker before the final publication.
