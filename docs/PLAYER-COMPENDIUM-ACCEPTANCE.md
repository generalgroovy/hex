# Traveller's Compendium

Status: implemented source candidate; focused navigation/layout checks pass,
with integrated Full/Farflow acceptance tracked in TEAM-FOUNDATION-ACCEPTANCE.md.

The in-game read-only compendium exposes the current movement rules and the
canonical cast without confusing planned identities with playable champions.

| Action | Keyboard / mouse | Controller |
|---|---|---|
| Open / close | F4; Escape also closes | Select / Back; B also closes |
| Section | Tab, or click Movement / Characters | LB / RB |
| Skill or alphabetical race row | Up / Down, wheel, click | D-pad Up / Down |
| Previous / next row page | Home / End, or Rows buttons | D-pad continues across pages |
| Character within selected race | Left / Right, or click character heading | D-pad Left / Right |
| Detail page | Page Up / Page Down, or Details buttons | X / Y |
| Open at Movement Guide station | Current interact binding (F by default) | Current interact binding |

F4 and Select / Back are fixed interface shortcuts in this slice, not yet
rebindable actions. Existing control capture, Spell Loom and join-address
editors retain input priority. Binding labels in movement instructions follow
the configured input device when opening. Closing consumes the event and guards
two frames against accidental actions. Reading sends neutral gameplay commands;
the shared world and other players continue, so the panel grants no safety.

The 16 movement entries derive execution, hold costs, windows, cooldowns,
protection and cautions from the movement guide model. Live Stamina profile and
chain premium refresh only when the relevant values change. The Characters
section lists 21 races alphabetically and 24 canonical identities: 5 playable,
18 planned and 1 placeholder. Only playable records expose actual stats. This
panel never equips characters, invents race bonuses or promotes planned art.

At 1280 x 720 the panel uses a ten-row list and measured-font text wrapping,
with fourteen detail lines per page; no paragraph is discarded. Rendering is
reusable presentation code and does not rebuild catalogs or wrap strings each
frame. Smaller windows scale the entire page to fit.

## Verification

- Isolated `test_player_compendium.gd`: navigation, keyboard/controller/wheel,
  all movement pages and character records, width bounds, long-word wrapping,
  dynamic chain expiry and honest availability labels.
- Real game captures use `--capture-compendium=movement` or
  `--capture-compendium=characters`; the integration lead records final Full
  suite and playtest status. A successful unit run alone is not visual acceptance.

Remaining: interactive controller hardware verification, user readability
acceptance and making the fixed interface shortcut configurable in a later slice.
