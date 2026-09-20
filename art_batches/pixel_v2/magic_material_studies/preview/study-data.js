(function (root) {
  "use strict";
  const elements = ["fire", "water", "earth", "wind", "charge", "ice", "light", "dark"];
  const wireElements = ["earth", "fire", "water", "wind", "ice", "charge", "light", "dark"];
  // Audited from ElementChemistrySystem.RECIPE_ROWS, not a new design table.
  const rows = [
    ["fortify",1,1],["magma",1,2],["mud",1,3],["dustfront",1,4],
    ["permafrost",1,5],["grounding_network",1,6],["crystal_prism",1,7],["blightsoil",1,8],
    ["conflagration",2,2],["steam",2,3],["firestorm",2,4],["thermal_shock",2,5],
    ["plasma_arc",2,6],["solar_flare",2,7],["cinderveil",2,8],["flood",3,3],
    ["mistcurrent",3,4],["freeze",3,5],["conductive_flood",3,6],["mirrorwater",3,7],
    ["blackwater",3,8],["vortex",4,4],["hailstream",4,5],["ion_storm",4,6],
    ["lightbend",4,7],["shadowdraft",4,8],["glacier",5,5],["superconduct",5,6],
    ["crystal_lens",5,7],["black_ice",5,8],["overload",6,6],["arcflash",6,7],
    ["static_shroud",6,8],["radiance",7,7],["penumbra",7,8],["umbral_field",8,8]
  ];
  const title = value => value.replace(/_/g, " ").replace(/\b\w/g, letter => letter.toUpperCase());
  const reactions = rows.map((row, index) => Object.freeze({
    id: row[0], wire: 301 + index, name: title(row[0]),
    elements: Object.freeze([wireElements[row[1] - 1], wireElements[row[2] - 1]])
  }));
  const data = Object.freeze({
    tickRate: 120, columns: 4, rows: 2, frameCount: 8,
    elements: Object.freeze(elements),
    steam: Object.freeze(["steam_formation", "steam_active", "steam_decay"]),
    fireTicks: Object.freeze([8,10,8,10,8,10,8,10]),
    defaultTicks: Object.freeze([10,10,10,10,10,10,10,10]),
    reactions: Object.freeze(reactions), title
  });
  if (typeof module !== "undefined" && module.exports) module.exports = data;
  else root.MagicStudyData = data;
})(typeof globalThis !== "undefined" ? globalThis : this);
