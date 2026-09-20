# Clarity and control iteration

Status: U1-U5 source implemented and full gate passed; human visual/feel review pending.

User accepts the illustrated direction as improved and authorizes the following
next slices. This supersedes the older blanket mechanics freeze for these named
changes only; new chemistry mutation and mixed-element attacks remain gated.

| Slice | Outcome | Acceptance |
|---|---|---|
| U1 bodies | Red Baron is the common head/body proportion reference; scale anatomy together for middle/small | Review all eight directions and poses; stable 58/68/76 envelopes, shared feet, unchanged hitbox |
| U2 elements | One clearly named element/color per spell, simple projectile core with quiet travel cue | Reject mixed-element attack metadata; color/shape separation in game and grayscale; preserve collision/costs |
| U3 spell desk | Whole current spell catalog alongside twelve binding positions; drag a spell to a slot, click/keyboard alternative | Every live spell visible; cancel/outside drop safe; online changes still host-authoritative |
| U4 guidance | Short task instructions, readable spell detail, no internal compiler/authority jargon | Newcomer can find, assign and cast without reading repository documents |
| U5 jump | Jump means vertical lift; horizontal motion follows live input, not a forced forward hop | Still jump stays still; steer/reverse/brake in eight directions; advanced wall/slide techniques preserved; deterministic network parity |

Single-element gate stays closed to hybrids until every first-eight interaction
is implemented, tested in isolation/combination, replicated/reset correctly and
passes the chemistry acceptance suite. A champion can still equip spells of
several different elements; each attack itself has exactly one element.

Evidence: full Windows gate 67 suites, 21,548 assertions, zero stderr; local
Farflow smoke passed. 720p spell panel inspected; body contact sheet is extracted
from runtime v14, not a separate concept. Windows installer exports not rebuilt.

Next user expansion: Grace Riva and Wa Bidi, exact motion-facing artwork,
clean alternating walking legs, all-action sprite and map-object refinements.
These are separate small slices; do not mistake this checkpoint for their completion.
