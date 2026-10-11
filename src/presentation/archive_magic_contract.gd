extends RefCounted

# Frozen authoring metadata for the unchanged 36-recipe pixel pack.
# This validates archived art, never the current live chemistry or its timing.
# Runtime authority controls footprint, phase and expiry when sampling these frames.
const DEPOSIT_LIFETIMES := {"earth": 600, "fire": 480, "water": 600, "wind": 360, "ice": 600, "charge": 360, "light": 480, "dark": 480}
const REACTIONS := [
  {
    "wire_id": 301,
    "id": "fortify",
    "shape": "cover",
    "elements": [
      "earth",
      "earth"
    ],
    "formation_ms": 180,
    "active_ms": 3125,
    "decay_ms": 400,
    "pulse_ms": 0,
    "formation_ticks": 22,
    "active_ticks": 375,
    "decay_ticks": 48,
    "nominal_radius_px": 22.5,
    "nominal_length_px": 80.0,
    "speed_px_per_second": 0.0,
    "cover_health": 32
  },
  {
    "wire_id": 302,
    "id": "magma",
    "shape": "front",
    "elements": [
      "earth",
      "fire"
    ],
    "formation_ms": 350,
    "active_ms": 2750,
    "decay_ms": 500,
    "pulse_ms": 400,
    "formation_ticks": 42,
    "active_ticks": 330,
    "decay_ticks": 60,
    "nominal_radius_px": 30.0,
    "nominal_length_px": 100.0,
    "speed_px_per_second": 30.0,
    "cover_health": 0
  },
  {
    "wire_id": 303,
    "id": "mud",
    "shape": "disk",
    "elements": [
      "earth",
      "water"
    ],
    "formation_ms": 200,
    "active_ms": 3250,
    "decay_ms": 350,
    "pulse_ms": 0,
    "formation_ticks": 24,
    "active_ticks": 390,
    "decay_ticks": 42,
    "nominal_radius_px": 77.5,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 304,
    "id": "dustfront",
    "shape": "corridor",
    "elements": [
      "earth",
      "wind"
    ],
    "formation_ms": 250,
    "active_ms": 2250,
    "decay_ms": 350,
    "pulse_ms": 0,
    "formation_ticks": 30,
    "active_ticks": 270,
    "decay_ticks": 42,
    "nominal_radius_px": 35.0,
    "nominal_length_px": 150.0,
    "speed_px_per_second": 38.0,
    "cover_health": 0
  },
  {
    "wire_id": 305,
    "id": "permafrost",
    "shape": "cover",
    "elements": [
      "earth",
      "ice"
    ],
    "formation_ms": 240,
    "active_ms": 3000,
    "decay_ms": 650,
    "pulse_ms": 0,
    "formation_ticks": 29,
    "active_ticks": 360,
    "decay_ticks": 78,
    "nominal_radius_px": 17.5,
    "nominal_length_px": 100.0,
    "speed_px_per_second": 0.0,
    "cover_health": 18
  },
  {
    "wire_id": 306,
    "id": "grounding_network",
    "shape": "node",
    "elements": [
      "earth",
      "charge"
    ],
    "formation_ms": 250,
    "active_ms": 3250,
    "decay_ms": 300,
    "pulse_ms": 0,
    "formation_ticks": 30,
    "active_ticks": 390,
    "decay_ticks": 36,
    "nominal_radius_px": 47.5,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 16
  },
  {
    "wire_id": 307,
    "id": "crystal_prism",
    "shape": "plane",
    "elements": [
      "earth",
      "light"
    ],
    "formation_ms": 400,
    "active_ms": 2750,
    "decay_ms": 400,
    "pulse_ms": 0,
    "formation_ticks": 48,
    "active_ticks": 330,
    "decay_ticks": 48,
    "nominal_radius_px": 10.0,
    "nominal_length_px": 87.5,
    "speed_px_per_second": 0.0,
    "cover_health": 18
  },
  {
    "wire_id": 308,
    "id": "blightsoil",
    "shape": "disk",
    "elements": [
      "earth",
      "dark"
    ],
    "formation_ms": 300,
    "active_ms": 3000,
    "decay_ms": 400,
    "pulse_ms": 0,
    "formation_ticks": 36,
    "active_ticks": 360,
    "decay_ticks": 48,
    "nominal_radius_px": 67.5,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 309,
    "id": "conflagration",
    "shape": "ring",
    "elements": [
      "fire",
      "fire"
    ],
    "formation_ms": 400,
    "active_ms": 3000,
    "decay_ms": 400,
    "pulse_ms": 600,
    "formation_ticks": 48,
    "active_ticks": 360,
    "decay_ticks": 48,
    "nominal_radius_px": 90.0,
    "nominal_length_px": 30.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 310,
    "id": "steam",
    "shape": "expanding_veil",
    "elements": [
      "fire",
      "water"
    ],
    "formation_ms": 240,
    "active_ms": 2625,
    "decay_ms": 500,
    "pulse_ms": 0,
    "formation_ticks": 29,
    "active_ticks": 315,
    "decay_ticks": 60,
    "nominal_radius_px": 112.5,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 311,
    "id": "firestorm",
    "shape": "corridor",
    "elements": [
      "fire",
      "wind"
    ],
    "formation_ms": 350,
    "active_ms": 2250,
    "decay_ms": 350,
    "pulse_ms": 350,
    "formation_ticks": 42,
    "active_ticks": 270,
    "decay_ticks": 42,
    "nominal_radius_px": 22.5,
    "nominal_length_px": 162.5,
    "speed_px_per_second": 68.0,
    "cover_health": 0
  },
  {
    "wire_id": 312,
    "id": "thermal_shock",
    "shape": "fracture",
    "elements": [
      "fire",
      "ice"
    ],
    "formation_ms": 600,
    "active_ms": 100,
    "decay_ms": 550,
    "pulse_ms": 0,
    "formation_ticks": 72,
    "active_ticks": 12,
    "decay_ticks": 66,
    "nominal_radius_px": 112.5,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 313,
    "id": "plasma_arc",
    "shape": "branch",
    "elements": [
      "fire",
      "charge"
    ],
    "formation_ms": 450,
    "active_ms": 120,
    "decay_ms": 400,
    "pulse_ms": 0,
    "formation_ticks": 54,
    "active_ticks": 15,
    "decay_ticks": 48,
    "nominal_radius_px": 12.5,
    "nominal_length_px": 225.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 314,
    "id": "solar_flare",
    "shape": "reveal_pulse",
    "elements": [
      "fire",
      "light"
    ],
    "formation_ms": 220,
    "active_ms": 100,
    "decay_ms": 650,
    "pulse_ms": 0,
    "formation_ticks": 27,
    "active_ticks": 12,
    "decay_ticks": 78,
    "nominal_radius_px": 125.0,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 315,
    "id": "cinderveil",
    "shape": "ember_veil",
    "elements": [
      "fire",
      "dark"
    ],
    "formation_ms": 300,
    "active_ms": 3000,
    "decay_ms": 400,
    "pulse_ms": 350,
    "formation_ticks": 36,
    "active_ticks": 360,
    "decay_ticks": 48,
    "nominal_radius_px": 70.0,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 316,
    "id": "flood",
    "shape": "flow",
    "elements": [
      "water",
      "water"
    ],
    "formation_ms": 220,
    "active_ms": 3125,
    "decay_ms": 350,
    "pulse_ms": 0,
    "formation_ticks": 27,
    "active_ticks": 375,
    "decay_ticks": 42,
    "nominal_radius_px": 80.0,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 317,
    "id": "mistcurrent",
    "shape": "corridor",
    "elements": [
      "water",
      "wind"
    ],
    "formation_ms": 220,
    "active_ms": 2750,
    "decay_ms": 400,
    "pulse_ms": 0,
    "formation_ticks": 27,
    "active_ticks": 330,
    "decay_ticks": 48,
    "nominal_radius_px": 31.25,
    "nominal_length_px": 200.0,
    "speed_px_per_second": 25.0,
    "cover_health": 0
  },
  {
    "wire_id": 318,
    "id": "freeze",
    "shape": "growing_strip",
    "elements": [
      "water",
      "ice"
    ],
    "formation_ms": 300,
    "active_ms": 2500,
    "decay_ms": 350,
    "pulse_ms": 0,
    "formation_ticks": 36,
    "active_ticks": 300,
    "decay_ticks": 42,
    "nominal_radius_px": 20.0,
    "nominal_length_px": 175.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 319,
    "id": "conductive_flood",
    "shape": "water_path",
    "elements": [
      "water",
      "charge"
    ],
    "formation_ms": 500,
    "active_ms": 2625,
    "decay_ms": 350,
    "pulse_ms": 600,
    "formation_ticks": 60,
    "active_ticks": 315,
    "decay_ticks": 42,
    "nominal_radius_px": 25.0,
    "nominal_length_px": 225.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 320,
    "id": "mirrorwater",
    "shape": "observation",
    "elements": [
      "water",
      "light"
    ],
    "formation_ms": 220,
    "active_ms": 3250,
    "decay_ms": 350,
    "pulse_ms": 0,
    "formation_ticks": 27,
    "active_ticks": 390,
    "decay_ticks": 42,
    "nominal_radius_px": 68.75,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 321,
    "id": "blackwater",
    "shape": "motion_veil",
    "elements": [
      "water",
      "dark"
    ],
    "formation_ms": 260,
    "active_ms": 3000,
    "decay_ms": 400,
    "pulse_ms": 0,
    "formation_ticks": 32,
    "active_ticks": 360,
    "decay_ticks": 48,
    "nominal_radius_px": 77.5,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 322,
    "id": "vortex",
    "shape": "annulus",
    "elements": [
      "wind",
      "wind"
    ],
    "formation_ms": 400,
    "active_ms": 2750,
    "decay_ms": 400,
    "pulse_ms": 0,
    "formation_ticks": 48,
    "active_ticks": 330,
    "decay_ticks": 48,
    "nominal_radius_px": 90.0,
    "nominal_length_px": 30.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 323,
    "id": "hailstream",
    "shape": "pulse_lane",
    "elements": [
      "wind",
      "ice"
    ],
    "formation_ms": 400,
    "active_ms": 2813,
    "decay_ms": 350,
    "pulse_ms": 450,
    "formation_ticks": 48,
    "active_ticks": 338,
    "decay_ticks": 42,
    "nominal_radius_px": 17.5,
    "nominal_length_px": 225.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 324,
    "id": "ion_storm",
    "shape": "drifting_node",
    "elements": [
      "wind",
      "charge"
    ],
    "formation_ms": 450,
    "active_ms": 2625,
    "decay_ms": 400,
    "pulse_ms": 700,
    "formation_ticks": 54,
    "active_ticks": 315,
    "decay_ticks": 48,
    "nominal_radius_px": 50.0,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 22.0,
    "cover_health": 0
  },
  {
    "wire_id": 325,
    "id": "lightbend",
    "shape": "bend",
    "elements": [
      "wind",
      "light"
    ],
    "formation_ms": 250,
    "active_ms": 3000,
    "decay_ms": 300,
    "pulse_ms": 0,
    "formation_ticks": 30,
    "active_ticks": 360,
    "decay_ticks": 36,
    "nominal_radius_px": 56.25,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 326,
    "id": "shadowdraft",
    "shape": "bands",
    "elements": [
      "wind",
      "dark"
    ],
    "formation_ms": 300,
    "active_ms": 3000,
    "decay_ms": 350,
    "pulse_ms": 300,
    "formation_ticks": 36,
    "active_ticks": 360,
    "decay_ticks": 42,
    "nominal_radius_px": 37.5,
    "nominal_length_px": 187.5,
    "speed_px_per_second": 30.0,
    "cover_health": 0
  },
  {
    "wire_id": 327,
    "id": "glacier",
    "shape": "corridor",
    "elements": [
      "ice",
      "ice"
    ],
    "formation_ms": 650,
    "active_ms": 3500,
    "decay_ms": 600,
    "pulse_ms": 0,
    "formation_ticks": 78,
    "active_ticks": 420,
    "decay_ticks": 72,
    "nominal_radius_px": 30.0,
    "nominal_length_px": 200.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 328,
    "id": "superconduct",
    "shape": "frost_path",
    "elements": [
      "ice",
      "charge"
    ],
    "formation_ms": 500,
    "active_ms": 2250,
    "decay_ms": 350,
    "pulse_ms": 900,
    "formation_ticks": 60,
    "active_ticks": 270,
    "decay_ticks": 42,
    "nominal_radius_px": 10.0,
    "nominal_length_px": 325.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 329,
    "id": "crystal_lens",
    "shape": "lens",
    "elements": [
      "ice",
      "light"
    ],
    "formation_ms": 450,
    "active_ms": 2875,
    "decay_ms": 400,
    "pulse_ms": 0,
    "formation_ticks": 54,
    "active_ticks": 345,
    "decay_ticks": 48,
    "nominal_radius_px": 22.5,
    "nominal_length_px": 75.0,
    "speed_px_per_second": 0.0,
    "cover_health": 20
  },
  {
    "wire_id": 330,
    "id": "black_ice",
    "shape": "entry_mark",
    "elements": [
      "ice",
      "dark"
    ],
    "formation_ms": 300,
    "active_ms": 3125,
    "decay_ms": 400,
    "pulse_ms": 0,
    "formation_ticks": 36,
    "active_ticks": 375,
    "decay_ticks": 48,
    "nominal_radius_px": 67.5,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 331,
    "id": "overload",
    "shape": "corridor",
    "elements": [
      "charge",
      "charge"
    ],
    "formation_ms": 650,
    "active_ms": 2000,
    "decay_ms": 450,
    "pulse_ms": 0,
    "formation_ticks": 78,
    "active_ticks": 240,
    "decay_ticks": 54,
    "nominal_radius_px": 30.0,
    "nominal_length_px": 200.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 332,
    "id": "arcflash",
    "shape": "reveal_line",
    "elements": [
      "charge",
      "light"
    ],
    "formation_ms": 300,
    "active_ms": 140,
    "decay_ms": 400,
    "pulse_ms": 0,
    "formation_ticks": 36,
    "active_ticks": 17,
    "decay_ticks": 48,
    "nominal_radius_px": 15.0,
    "nominal_length_px": 225.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 333,
    "id": "static_shroud",
    "shape": "entry_veil",
    "elements": [
      "charge",
      "dark"
    ],
    "formation_ms": 320,
    "active_ms": 2750,
    "decay_ms": 400,
    "pulse_ms": 0,
    "formation_ticks": 39,
    "active_ticks": 330,
    "decay_ticks": 48,
    "nominal_radius_px": 72.5,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 334,
    "id": "radiance",
    "shape": "reveal_area",
    "elements": [
      "light",
      "light"
    ],
    "formation_ms": 300,
    "active_ms": 3125,
    "decay_ms": 400,
    "pulse_ms": 0,
    "formation_ticks": 36,
    "active_ticks": 375,
    "decay_ticks": 48,
    "nominal_radius_px": 97.5,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 335,
    "id": "penumbra",
    "shape": "border",
    "elements": [
      "light",
      "dark"
    ],
    "formation_ms": 220,
    "active_ms": 3000,
    "decay_ms": 250,
    "pulse_ms": 0,
    "formation_ticks": 27,
    "active_ticks": 360,
    "decay_ticks": 30,
    "nominal_radius_px": 82.5,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  },
  {
    "wire_id": 336,
    "id": "umbral_field",
    "shape": "attrition_veil",
    "elements": [
      "dark",
      "dark"
    ],
    "formation_ms": 350,
    "active_ms": 3500,
    "decay_ms": 450,
    "pulse_ms": 600,
    "formation_ticks": 42,
    "active_ticks": 420,
    "decay_ticks": 54,
    "nominal_radius_px": 92.5,
    "nominal_length_px": 0.0,
    "speed_px_per_second": 0.0,
    "cover_health": 0
  }
]
