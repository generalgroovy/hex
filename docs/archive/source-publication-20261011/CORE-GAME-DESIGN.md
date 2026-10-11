# H.E.X. game design overview

Status: Current concise overview; SPECIFICATION.md owns the detailed contract.

H.E.X. combines movement execution, aimed spell combat and finite elemental
terrain. Players learn a small set of actions, then express skill through timing,
route choice, countercasting and combinations.

The [current design contract](../SPECIFICATION.md) is the single authority for
scope and rules. The [README](../README.md) is the player guide; the
[balance contract](HEX-BALANCE-CONTRACT.md) separates implemented capabilities
from intended viability and uniqueness.

| Pillar | Current foundation |
|---|---|
| Movement | Independent travel/aim; paid slide chains, evasions, wall routes and finite second-jump options |
| Spells | Bolt, Heavy, Rapid and Spray for six elements; twelve configured positions |
| Chemistry | Sixty-three bounded reactions cover every ingredient subset, with shared damage funding and situational effects |
| Characters | Thirty identities, twenty-one ancestries, three sizes; each race and champion has a situational passive |
| Wellspring | Spawn, configure, practice and meet friends through the shared world |

All execution work is in the [single queue](../.agent/OVERHAUL-IMPLEMENTATION.md).
The [earlier summary](archive/core-docs-20261007/CORE-GAME-DESIGN.md) is archived:
its FLUX title, seven families, fifty-seven spells and older roster are not current.
