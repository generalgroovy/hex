"""Original FLUX pixel key poses. Integer cells only; no vector rasterization.

Run once to author source/frames. Edit those JSON pixel rows directly afterwards.
export_pack.py exports those editable frames without regenerating their drawings.
All paths written by this module stay inside the magic candidate folder.
"""
from pathlib import Path
import json
import math
import re
import hashlib

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[2]
LANGUAGE_PATH = REPO / "content/visual/visual_language_v1.json"
LANGUAGE = json.loads(LANGUAGE_PATH.read_text(encoding="utf-8"))
COLOR_ROLES = ("dark", "base", "bright")
ORDER = ["earth", "fire", "water", "wind", "ice", "charge", "light", "dark"]
# One editable ramp feeds both the native sprite atlas and runtime UI/glyphs.
# Never multiply already-colored sprites by a second tint or average input hues.
PALETTES = {
    **{element: [LANGUAGE["elements"][element][role].removeprefix("#") for role in COLOR_ROLES] for element in ORDER},
    "steam": [LANGUAGE["reaction_materials"]["steam"][role].removeprefix("#") for role in COLOR_ROLES],
    "dust": ["403424", "98805a", "e2d4a7"],
    "protection": ["07171d", "258298", "58d8dd"],
}
INK = "16212a"
def read_deposit_lifetimes():
    source = (REPO / "src/sim/chemistry/element_chemistry_system.gd").read_text(encoding="utf-8")
    values = json.loads(re.search(r"const ELEMENT_LIFE_MS: Array\[int\] = (\[[^\n]+\])", source).group(1))
    assert len(values) == 9 and all(0 < value <= 5000 for value in values[1:])
    return dict(zip(ORDER, [(value * 120 + 999) // 1000 for value in values[1:]]))

LIFE = read_deposit_lifetimes()

# A line in these drawings is one row of logical pixels. '.' = transparent.
# d / b / h = dark / base / bright. Silhouettes are edited per pose, not filtered.
POSES = {
 "fire": [
 """.........bb...
.........bhb..
....b....bhb..
...bhb..bhb...
...bhb..bhb...
..bbhbbbhb....
..bhhbbhhb....
.bbhhhhhb.....
.bhhhhhhhb....
bbhhhbhhhb....
bbhhbdbhhhbb..
.bbhbdbhhbbb..
..bbbbbbbbd...
...dddddd.....""",
 """....bb.......
...bhb.......
...bhbb......
....bhhb.....
....bhhb..b..
....bhb..bhb.
...bhhb..bhb.
..bhhhbbbhb..
.bbhhhhhhhb..
.bhhhbbhhhb..
bbhhbddbhhbb.
.bbhbdbhhhbb.
..bbbbbbbbd..
...dddddd....""",
 """.......b.....
......bhb....
.....bhb.....
....bhhb.....
...bhhhbb....
...bhhhhbb...
.bbbhhhhhb...
.bhhbbhhhb...
bbhhbdbhhbb..
bbhhhbbhhhb..
.bbhhhhhhbb..
..bbhhhhbb...
..bbbbbbbbd..
...dddddd....""",
 """..........b..
.........bhb.
.........bhb.
....bb..bhb..
...bhb..bhb..
...bhhbbhb...
..bbhhhhhbb..
.bbhhhhhhhb..
.bhhhbbhhhb..
bbhhbddbhhbb.
bbhhbdbhhhbb.
.bbhhhhhhbb..
..bbbbbbbbd..
...dddddd...."""],
 "water": [
 """.......hhhh...
.....hhbbbbh..
....hbbbddbh..
...hbbd..dbh..
..hbbd...dbb..
..hbbd........
.hbbbd........
.hbbbbdd......
hhbbbbbbdddd..
hbbbbbbbbbbbh.
.hbbbbbbbhhh..
..dddddddd....""",
 """........hhh...
......hhbbbh..
....hhbbddbh..
...hbbbd.dbh..
..hbbbd.dbh...
..hbbd..db....
.hbbbd........
.hbbbbdd......
hhbbbbbbdd....
hbbbbbbbbbbbh.
.hbbbbbbbhhh..
..dddddddd....""",
 """.........hh...
.......hhbbh..
.....hhbbdbh..
....hbbbd.hb..
...hbbbd..h...
..hbbbd.......
..hbbbdd......
.hbbbbbbdd....
hhbbbbbbbbdd..
hbbbbbbbbbbbh.
.hbbbbbbbhhh..
..dddddddd....""",
 """......hhhh....
.....hbbbbh...
....hbbddbh...
...hbbd..dbh..
..hbbd...dbh..
..hbbd..dbb...
.hbbbd........
.hbbbbdd......
hhbbbbbbdddd..
hbbbbbbbbbbbh.
.hbbbbbbbhhh..
..dddddddd...."""],
 "earth": [
 """....hhhhh.....
..hhbbbbbh....
.hbbbbbbbdh...
.hbbbd bbbdh..
hbbbbddbbbdh..
hbbbbddbbbdh..
hbdddbbbbd dh.
dbbbbdbbbddbd.
.dbbbdbbddbbd.
..dddddddddd..""",
 """....hhhhh.....
..hhbbbbbh....
.hbbbbbbbdh...
.hbbbd bbbdh..
hbbbbddbbbdh..
hbbbddddbbdh..
hbdddbbbbd dh.
dbbbbdbbbddbd.
.dbbbdbbddbbd.
..dddddddddd.."""],
 "wind": [
 """......hhhhh.....
....hhbbbbbhh...
...hbbd...dbbh..
..hbd.......bh..
..hbd..hhh..bh..
...bb..hbb..h...
.......hbd......
.hhh...hbd......
hbbbhhhbd.......
.dbbbbbd........
...dddd.........""",
 """.......hhhh.....
.....hhbbbbh....
....hbbd..dbh...
...hbd.....bh...
...hbd.hhh.bh...
...dbb.hbb.h....
.......hbd......
..hhh..hbd......
.hbbbhhbd.......
..dbbbbd........
....ddd.........""",
 """.....hhhhhh.....
...hhbbbbbbh....
..hbbd....dbh...
..hbd......bh...
..hbd.hhh..bh...
...bb.hbb..h....
......hbd.......
hhh...hbd.......
bbbhhhbd........
.dbbbbd.........
...ddd.........."""],
 "ice": [
 """.......h.......
......hbh......
......hbh......
..h...hbh...h..
..hb..hbh..bh..
...hbhhbhhbh...
....hbhhhbh....
hhhhhbhhhbhhhhh
.bbbbhhhhhbbbb.
..ddddhbdddd...
.....hbdbh.....
....hbd.dbh....
...hbd...dbh...
..hbd.....dbh..
..hd.......dh..""",
 """.......h.......
.......h.......
......hbh......
..h...hbh......
..hb..hbh..h...
...hbhhbhhbh...
....hbhhhbh....
.hhhhbhhhbhhhh.
..bbbhhhhhbbb..
...dddhbddd....
.....hbdbh.....
....hbd.dbh....
...hbd...dbh...
...hd.....dh...
..............."""],
 "charge": [
 """.........hh...
........hbh...
.......hbh....
......hbh.....
...hhhbh......
...hbbh.......
....hbhhh.....
.....hbbbh....
....hbhhh.....
...hbh........
..hbh.........
.hbh..........
.hh...........""",
 """.......hh.....
......hbh.....
.....hbh......
....hbh.......
...hbhhhh.....
....hbbbh.....
.....hbh......
..hhbh........
..hbbh........
...hbh........
..hbh.........
...hb.........
...hh.........""",
 """........hh....
.......hbh....
......hbh.....
.....hbh......
....hbhhhh....
.....hbbbh....
....hbhhh.....
...hbh........
..hbh.........
...hbh........
....hbh.......
...hbh........
...hh........."""],
 "light": [
 """.......h.......
.......h.......
......hbh......
......hbh......
.....hbbbh.....
....hbbhbbh....
..hhbbhhhbbhh..
hhbbbhhhhhbbbhh
..hhbbhhhbbhh..
....hbbhbbh....
.....hbbbh.....
......hbh......
......hbh......
.......h.......
.......h.......""",
 """...............
.......h.......
.......h.......
......hbh......
......hbh......
.....hbbbh.....
...hhbhhhbhh...
.hhbbhhhhbbbhh.
...hhbhhhbhh...
.....hbbbh.....
......hbh......
......hbh......
.......h.......
.......h.......
..............."""],
 "dark": [
 """.....bbbb......
...bbhbb.......
..bbhb.........
.bbhbd.........
.bhbd..........
bbhbd.....bb...
bbhbd......bb..
bbhbd......bb..
.bhbbd....bbh..
.bbhbbddddbhb..
..bbhhbbbbhb...
...bbhhhhbb....
.....bbbb......""",
 """......bbb......
....bbhbb......
...bbhb........
..bbhbd........
..bhbd.........
.bbhbd.....b...
.bbhbd.....bb..
.bbhbd.....bb..
..bhbbd...bbh..
..bbhbbddbbhb..
...bbhhbbbhb...
....bbhhhbb....
......bbb......""",
 """....bbbbb......
..bbhhbb.......
.bbhhb.........
bbhhbd.........
bhhbd..........
bhhbd.....bb...
bhhbd......bb..
bhhbd......bb..
bbhhbd....bbh..
.bbhhbbddbbhb..
..bbhhbbbbhb...
...bbhhhhbb....
.....bbbb......"""],
 "steam": [
 """......hhhh...........
....hhbbbbhh.........
...hbbbbbbbbh........
...hbbbbbbbdbh.......
..hhbbbhhhbbdbh......
.hbbbbhbbbhbbdbh.....
hbbbbhbbbbbhbbdbh....
hbbbbhbbbbbhbbbdbh...
hbbbbbddddbbbbbbbhh..
.hbbbbbbbbbbbbbbbbbh.
..dbbbbbbbbbbbbbbbbd.
....ddddbbbbbbdddd...
........dddddd.......""",
 """.......hhhh..........
.....hhbbbbh.........
....hbbbbbbbh........
...hbbbbbbbdbh.......
..hhbbbbhhbbdbh......
.hbbbbb hbhbbdbh.....
hbbbbhhhbbbhbbdbh....
hbbbhbbbbbbbhbbdbh...
hbbbhbbbbbbbhbbbbhh..
.hbbbddddddbbbbbbbbh.
..dbbbbbbbbbbbbbbbbd.
....ddddbbbbbbdddd...
........dddddd.......""",
 """........hhhh.........
......hhbbbbh........
.....hbbbbbbbh.......
....hbbbbbbbdbh......
...hbbbbbbbbbbh......
..hbbb hhhbbbbbhh....
.hbbbhhbbbhbbbbbbh...
hbbbhbbbbbbhbbbbbbh..
hbbbhbbbbbbhbbbbbbh..
.hbbbddddddbbbbbbbbh.
..dbbbbbbbbbbbbbbbbd.
....ddddbbbbbbdddd...
........dddddd.......""",
 """......hhhhh..........
....hhbbbbbh.........
...hbbbbbbbbh........
...hbbbbbbbdbh.......
..hhbbbbbbbbdbh......
.hbbbbhhhhbbbdbh.....
hbbbbhbbbbhbbbdbh....
hbbbhbbbbbbhbbbdbh...
hbbbhbbbbbbhbbbbbhh..
.hbbbddddddbbbbbbbbh.
..dbbbbbbbbbbbbbbbbd.
....ddddbbbbbbdddd...
........dddddd......."""],
 "dust": [
 """......hh.......
....hhbbh......
...hbbbbbhh....
..hbbbbbbbbh...
hhbbbhhhbbbdh..
hbbbhbbbhbbbdh.
hbbbbddddbbbbh.
.dbbbbbbbbbbd..
...dddddddd....""",
 """.....hhh.......
...hhbbbh......
..hbbbbbbhh....
.hbbbbbbbbb h..
hbbbhhhhbbbdh..
hbbhbbbbhbbbdh.
.hbbddddbbbdh..
..dbbbbbbbbd...
....dddddd....."""],
 "protection": [
 """hhhhhhhhhhh
hbbbbbbbbbh
hbhhhhhhhbh
hbhbbbbb hbh
hbhbbbbb hbh
.hbhbbbhbh.
.hbhbbbhbh.
..hbhbhbh..
...hbhbh...
....hhh...."""],
}

GRAINS = {
 "fire": ["..b..", ".bhb.", "bhhhb", ".bhd.", "..d.."],
 "water": ["..h..", ".hbh.", "hbbbh", ".dbd.", "..d.."],
 "earth": [".hhh.", "hbbdh", "hbdbd", ".ddd."],
 "wind": [".hhh.", "hb...", ".bh..", "..hh."],
 "ice": ["..h..", ".hbh.", "hbbdh", ".hbd.", "..d..", "..d.."],
 "charge": ["..hh.", ".hb..", "..hh.", ".hb..", ".h..."],
 "light": ["..h..", "..h..", "hhbhh", "..h..", "..h.."],
 "dark": [".bb..", "bh...", "bh.b.", ".bhb.", "..b.."],
 "steam": [".hhh.", "hbbbh", "hbbbh", ".ddd."],
 "dust": [".hh.", "hbbh", ".ddd"],
}
BEAM_ROWS = {
 "earth": [".hhhhhh..hhhhh..", "hbbbbbdhhbbbbbdh", "hbdbbbdhbbdbbbdh", "hbddbbdhbbddbbdh", ".dddddd..ddddd.."],
 "fire": ["...bb.....bb....", ".bbhhb..bbhhbbb.", "bbhhhhbbhhhhhhbb", "hhhhhhhhhhhhhhhh", "bbhhbbbbhhhbbbbb", ".ddd....ddd....."],
 "water": ["...hhhhh........", ".hhbbbbb hh.....", "hbbbbbbbbbbhhhbh", "bbbbbbbbbbbbbbbb", "dddddddddddddddd"],
 "wind": ["..hhhh......hhhh", "hhbbbbhh..hhbbbb", "bb....bbhhbb....", "........bb......"],
 "ice": ["...h......h.....", ".hhbhhhh hhbhhh.", "hbbbbbbbhbbbbb bh", "bbbbdhhbbbddhbbb", ".ddd....ddd....."],
 "charge": ["...hhh..........", "..hbbbh...hhh...", "hhb...bhhhbbbhhh", "bb.....bbb...bbb", "................"],
 "light": ["................", "...h.......h....", "hhhhhhhhhhhhhhhh", "bbbbbbbbbbbbbbbb", "...d.......d...."],
 "dark": ["....bb.....bb...", "..bbhb...bbhb...", "bbhhbbbbb hhbbbb", "bbddddbbddddbbbb", "...ddd...ddd...."],
}

def blank(w=32, h=32):
    return [["." for _ in range(w)] for _ in range(h)]

def rows(text):
    return [list(row.replace(" ", ".")) for row in (text.splitlines() if isinstance(text, str) else text)]

def stamp(dst, pattern, cx, cy, remap=None, flip=False):
    pattern = rows(pattern) if isinstance(pattern, str) else pattern
    w = max(map(len, pattern)); h = len(pattern)
    for y, line in enumerate(pattern):
        for x, c in enumerate(line):
            if c == ".": continue
            px = cx - w // 2 + (w-1-x if flip else x); py = cy - h // 2 + y
            if 0 <= py < len(dst) and 0 <= px < len(dst[0]):
                dst[py][px] = remap.get(c,c) if remap else c

def line(dst, a, b, c):
    # Integer run editing; never draw smooth paths or antialiased primitives.
    x,y=a; x1,y1=b; dx=abs(x1-x); sx=1 if x<x1 else -1
    dy=-abs(y1-y); sy=1 if y<y1 else -1; err=dx+dy
    while True:
        if 0<=y<len(dst) and 0<=x<len(dst[0]): dst[y][x]=c
        if x==x1 and y==y1: break
        e=2*err
        if e>=dy: err+=dy; x+=sx
        if e<=dx: err+=dx; y+=sy

def motif(element, frame):
    return rows(POSES[element][frame % len(POSES[element])])

def frame_strings(frame): return ["".join(row) for row in frame]

ASSETS = []
def add(key, frames, durations, *, palette="fire", element=None, reaction=None,
        phase="active", loop=False, pivot=(16,16), role="material_detail",
        attachment="world_position", geometry="clip_to_authoritative_coverage",
        variant="normal", direction="billboard", budget=8, **extra):
    ident = "magic." + key + "." + variant
    colors = {".": "00000000", "i": INK+"ff", "d": PALETTES[palette][0]+"ff", "b": PALETTES[palette][1]+"ff", "h": PALETTES[palette][2]+"ff"}
    if reaction:
        second = extra.pop("secondary_palette", palette)
        colors.update(dict(zip(["D","B","H"],[v+"ff" for v in PALETTES[second]])))
    assert len(frames)==len(durations)
    asset = dict(id=ident, element_id=element, reaction_id=reaction,
        lifecycle_phase=phase, loop=loop, direction=direction, pivot_px=list(pivot),
        attachment={"anchor":attachment, "pivot_stable_all_frames":True},
        layer_role=role, completion_status="authored_candidate",
        runtime_integrated=False, variant=variant,
        end_behavior="hide" if phase in ["release","impact","takeoff","landing"] or (key.startswith("movement.") and role=="harmless_movement" and not loop) else "hold_until_authority_phase_end",
        intended_simultaneous_instance_budget=budget,
        geometry_scaling_rules=geometry, palette=colors,
        frames=[dict(pixels=frame_strings(f),duration_ticks=d,pivot_px=list(pivot)) for f,d in zip(frames,durations)],
        **extra)
    ASSETS.append(asset)

def small_grain(element): return rows(GRAINS[element])

def element_kit(element, reduced):
    variant="reduced" if reduced else "normal"
    base=dict(palette=element,element=element,variant=variant)
    # Hand gather: three key placements close toward the hand with no timer ownership.
    prepare=[]
    for f in range(4):
        p=blank(); spread=[9,7,5,3][f]
        stamp(p,small_grain(element),16-spread,16)
        if not reduced: stamp(p,small_grain(element),16+spread,14-(f%2))
        prepare.append(p)
    add(f"{element}.hand_prepare",prepare,[10,8,6,8],phase="formation",attachment="bare_hand",
        role="harmless_cast_detail",budget=8,**base)
    release=[]
    for f in range(5):
        p=blank()
        if f<3: stamp(p,motif(element,f),16+f,16)
        for sx,sy in ([(-1,0),(0,-1),(0,1)] if not reduced else [(1,0)]):
            stamp(p,small_grain(element),16+sx*[3,6,9,11,12][f],16+sy*[3,5,8,10,12][f])
        release.append(p)
    add(f"{element}.hand_release",release,[3,4,6,8,9],phase="release",attachment="bare_hand",
        role="harmless_cast_detail",budget=8,**base)
    # Flight has no fake ring or rune. It is a material-shaped core with separate tail.
    flight=[]
    for f in range(4):
        p=blank(); stamp(p,motif(element,f),16,16); flight.append(p)
    cadence={"earth":[18,6,18,6],"charge":[4,4,12,12],"light":[16,12,16,12],"water":[10]*4}.get(element,[8,10,8,10])
    add(f"{element}.flight",flight,cadence,loop=True,role="projectile_core",budget=128,
        geometry="center_on_interpolated_projectile; nominal_envelope_16px; core_mask_scaled_to_actual_radius; aim_stays_continuous; do_not_rotate_billboard",**base)
    trail=[]
    for f in range(4):
        p=blank()
        stamp(p,small_grain(element),21,16)
        if not reduced:
            stamp(p,small_grain(element),[11,10,9,10][f],15+f%2)
            p[17][[4,5,6,5][f]]="b"
        trail.append(p)
    add(f"{element}.flight_tail",trail,cadence,loop=True,role="harmless_trail",direction="east",
        attachment="continuous_velocity_frame_behind_core",budget=64,
        geometry="rotate_cosmetic_tail_only_to_continuous_velocity; never_snap_aim; opacity_cap_0.38; omit_before_core_when_budget_exceeded",**base)
    impact=[]
    spokes=[(-1,-1),(1,-1),(-1,1),(1,1),(0,-1),(1,0)]
    for f,dist in enumerate([2,5,8,10,12,13]):
        p=blank()
        if f<2: stamp(p,motif(element,f),16,16)
        for i,(sx,sy) in enumerate(spokes[:3 if reduced else 6]):
            if f==5 and i%2: continue
            yy=16+sy*dist+(max(0,f-2) if element in ["water","earth","ice"] else -max(0,f-2))
            stamp(p,small_grain(element),max(3,min(28,16+sx*dist)),max(4,min(28,yy)))
        impact.append(p)
    add(f"{element}.impact",impact,[3,4,6,8,10,12],phase="impact",role="terminal_contact",budget=24,
        geometry="point_contact_only; fragments_harmless; hide_on_owner_effect_end; do_not_imply_AOE",**base)
    for phase in ["formation","active","decay"]:
        frames=[]
        for f in range(4):
            p=blank()
            if phase=="formation":
                stamp(p,small_grain(element) if f<2 else motif(element,f),16,23 if f<2 else 18)
            elif phase=="active":
                stamp(p,motif(element,f),16,18)
                if not reduced and element not in ["earth","light"]: stamp(p,small_grain(element),[5,6,7,6][f],25)
            else:
                if f==0: stamp(p,motif(element,2),16,18)
                elif f<3:
                    stamp(p,small_grain(element),12-f,23)
                    if not reduced: stamp(p,small_grain(element),20+f,22-f)
                else: p[24][13]="d"; p[23][20]="b"
            frames.append(p)
        add(f"{element}.deposit_{phase}",frames,[10]*4,phase=phase,loop=phase=="active",pivot=(16,26),
            attachment="ground_position",role="finite_deposit_material",budget=32,
            simulation_lifetime_ticks=LIFE[element],**base)
    # Seam-compatible 16px repeat strip. First and last columns are explicitly shared.
    beam=[]
    pattern=rows(BEAM_ROWS[element])
    for f in range(8):
        p=blank(16,12)
        for y,row in enumerate(pattern):
            for x,c in enumerate(row[:16]):
                if c!=".": p[y+2][(x+f*2)%16]=c
        for y in range(12): p[y][0]=p[y][15]="h" if y==5 else "b" if y==6 else "."
        beam.append(p)
    add(f"{element}.beam_body",beam,[8]*8,loop=True,pivot=(0,6),direction="east",role="attack_material",
        attachment="authoritative_segment_start",budget=32,
        geometry="repeat_x_not_stretch; clip_at_exact_endpoints_and_actual_half_width; continuous_basis; boundary_is_separate",
        connectors_px={"entry":[0,6],"exit":[16,6]},**base)
    for part in ["start","end"]:
        cap=[]
        for f in range(4):
            p=blank(); stamp(p,motif(element,f),16,16); cap.append(p)
        add(f"{element}.beam_{part}",cap,[8]*4,loop=True,role="attack_cap",
            attachment="actual_segment_"+part,budget=16,geometry="clip_to_beam_coverage; never_extend_beyond_authoritative_contact",**base)
    spray=[]
    for f in range(4):
        p=blank(12,12); stamp(p,small_grain(element),6,6);
        if f%2==0 and not reduced: p[3][9]="h"
        spray.append(p)
    add(f"{element}.spray_grain",spray,[8]*4,loop=True,pivot=(6,6),role="attack_material",budget=48,
        geometry="sparse_stamp_only_inside_actual_spray_cone; no_individual_grain_is_a_hitbox; preserve_essential_cone_edge",**base)
    burst=[]
    for f in range(4):
        p=blank()
        for y in ([9,16,23] if not reduced else [16]): stamp(p,small_grain(element),[10,15,20,24][f],y)
        burst.append(p)
    add(f"{element}.burst_release",burst,[3,4,6,10],phase="release",role="harmless_cast_detail",attachment="bare_hand",budget=8,
        geometry="hand_accent_only; use_flight_per_actual_projectile; never_create_extra_fan_lanes",**base)
    field=[]
    for f in range(4):
        p=blank()
        stamp(p,small_grain(element),8,10)
        if not reduced: stamp(p,small_grain(element),23,22)
        if not reduced and f in [1,2]: p[9][24]="b"; p[24][9]="h"
        field.append(p)
    add(f"{element}.field_tile",field,[12]*4,loop=True,role="ground_material",attachment="world_locked_32px_grid",budget=32,
        geometry="repeat_xy_at_1x; clip_to_actual_coverage; multiply_alpha_0.12_normal_0.06_reduced; draw_below_bodies",**base)

# Each pair receives an authored composite stamp, not a complete fixed footprint.
# Shape is read from RECIPE_ROWS. These stamps are arranged/clipped by that shape.
PAIR_LAYOUTS = {
 "fortify":"brick", "magma":"crust", "mud":"silt", "dustfront":"billow",
 "permafrost":"brick_frost", "grounding_network":"root_node", "crystal_prism":"facet", "blightsoil":"root",
 "conflagration":"flame_fork", "steam":"vapour", "firestorm":"flame_shear", "thermal_shock":"crack",
 "plasma_arc":"branch", "solar_flare":"flare", "cinderveil":"ember_cloud", "flood":"wave",
 "mistcurrent":"mist", "freeze":"frost_tip", "conductive_flood":"charged_wave", "mirrorwater":"mirror",
 "blackwater":"undertow", "vortex":"ribbon", "hailstream":"hail", "ion_storm":"ion",
 "lightbend":"bend_facet", "shadowdraft":"band", "glacier":"frostway_floor", "superconduct":"frost_wire",
 "crystal_lens":"lens_facet", "black_ice":"black_shard", "overload":"node", "arcflash":"spark_line",
 "static_shroud":"static_cloud", "radiance":"rays", "penumbra":"split", "umbral_field":"inward",
}
BRICK = """..hhhhhhhhhhhhhh..
.hbbbbbbbbbbbbbbh.
hbbbbbbddbbbbbbbdh
hbbbbbbddbbbbbbbdh
hbbbbbbddbbbbbbbdh
.dddddddddddddddd.
...hbbbbbbbbbbh...
...dddddddddddd..."""
PLATE = """....hhhhhhhhh....
..hhbbbbbbbbbhh..
.hbbbbbbbbbbbbbh.
hbbbbbddddbbbbbbh
.dbbbbbbbbbbbbbd.
..ddddddddddddd.."""
CRYSTAL = """.......h.......
......hbh......
.....hbbdh.....
....hbbbdhh....
...hbbbbdhbh...
..hbbbbbdbbdh..
.hbbbbbbdbbbdh.
hbbbbbbbdbbbbdh
.dbbbbbddbbbd..
..dbbbbddbbd...
...dbbbddbd....
....dbbdd d....
.....dbdd......
......dd......."""

def vapor_lobe(canvas, cx, cy, rx, ry):
    """Edit logical pixel cells directly: hard stepped edges, no AA/filtering."""
    for dy in range(-ry, ry + 1):
        for dx in range(-rx, rx + 1):
            if dx * dx * ry * ry + dy * dy * rx * rx > rx * rx * ry * ry:
                continue
            x, y = cx + dx, cy + dy
            if not (1 <= x <= 30 and 1 <= y <= 30):
                continue
            # Pale upper rolls, shaded lower-right pockets, no rock-like outline
            # or continuous ground baseline. Opacity remains runtime-owned.
            color = "h" if dy < -max(1, ry // 3) and dx < rx // 2 else "b"
            if dy > ry // 2 and dx > 0:
                color = "d"
            canvas[y][x] = color


def steam_vapor_pose(frame, phase, reduced):
    canvas = blank()
    # Each pose exchanges rounded lobes while wisps rise. The fixed (16,26)
    # registration never follows the visible bounding box or changes coverage.
    active = [
        [(10, 21, 5, 3), (18, 19, 7, 4), (14, 13, 5, 5), (22, 9, 3, 2)],
        [(10, 20, 5, 3), (19, 18, 6, 4), (14, 11, 5, 4), (22, 7, 3, 2)],
        [(11, 21, 6, 3), (20, 16, 6, 4), (15, 8, 4, 3), (24, 6, 2, 1)],
        [(10, 22, 5, 3), (19, 19, 7, 4), (16, 13, 5, 5), (8, 9, 3, 2)],
    ]
    formation = [
        [(12, 24, 4, 1), (21, 22, 3, 1)],
        [(11, 23, 5, 2), (19, 20, 5, 3), (15, 15, 3, 2)],
        [(10, 22, 5, 3), (18, 19, 6, 4), (14, 13, 4, 4)],
        active[0],
    ]
    decay = [
        [(11, 20, 5, 2), (20, 15, 5, 3), (14, 9, 4, 3), (25, 5, 2, 1)],
        [(9, 17, 4, 2), (19, 11, 5, 3), (13, 5, 3, 2)],
        [(10, 11, 3, 2), (22, 7, 3, 2)],
        [(11, 5, 2, 1), (23, 3, 2, 1)],
    ]
    lobes = {"formation": formation, "active": active, "decay": decay}[phase][frame % 4]
    for index, (cx, cy, rx, ry) in enumerate(lobes):
        if reduced and index == 3:
            continue
        vapor_lobe(canvas, cx, cy, rx, ry)
    if phase == "active":
        # Open lower wisps and small inner pockets prevent a filled boulder.
        for x, y in [(13, 23), (14, 23), (18, 14), (19, 14)]:
            if canvas[y][x] != ".":
                canvas[y][x] = "."
        if not reduced:
            line(canvas, (8 + frame % 2, 26), (12 + frame % 2, 26), "d")
    return canvas


def write_steam_only():
    """Revise six copied source sequences; never regenerate other materials."""
    for reduced in [False, True]:
        for phase in ["formation", "active", "decay"]:
            path = ROOT / "source/frames" / ("magic.reaction.steam.%s.%s.json" % (phase, "reduced" if reduced else "normal"))
            asset = json.loads(path.read_text(encoding="utf-8"))
            assert len(asset["frames"]) == 4 and asset["pivot_px"] == [16, 26]
            for index, frame in enumerate(asset["frames"]):
                frame["pixels"] = frame_strings(steam_vapor_pose(index, phase, reduced))
            path.write_text(json.dumps(asset, indent=2) + "\n", encoding="utf-8", newline="\n")
    # Refresh current source audit hashes only; actual36 recipe parameters and
    # every non-Steam source remain exactly those of the accepted parent pack.
    snapshot_path = ROOT / "source/authority_snapshot.json"
    snapshot = json.loads(snapshot_path.read_text(encoding="utf-8"))
    for source in snapshot["source_files"]:
        source["sha256"] = hashlib.sha256((REPO / source["path"]).read_bytes()).hexdigest()
    snapshot["candidate_revision"] = "steam-rounded-vapor-v2; only six Steam pixel-row sequences changed"
    snapshot_path.write_text(json.dumps(snapshot, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("AUTHORED six Steam-only native-pixel sequences; non-Steam sources untouched")


def rampart_pose(f, phase, reduced):
    """Tileable stone faces, not a sparse pebble standing in for a solid wall."""
    c = blank()
    rise = [22, 14, 6, 0][f % 4] if phase == "formation" else 0
    for y in range(rise, 32):
        for x in range(32):
            # Offset masonry courses meet cleanly across repeated 32px cells.
            joint_x = (x + (8 if (y // 16) % 2 else 0)) % 16
            joint_y = y % 16
            ink = "b"
            if joint_x == 0 or joint_y in [14, 15]:
                ink = "i"
            elif joint_y == 0:
                ink = "h"
            elif joint_y > 10 or joint_x > 12:
                ink = "d"
            elif (x * 7 + y * 3) % 47 == 0:
                ink = "h" if not reduced else "b"
            if phase == "decay" and ((x // 4 + y // 4 * 3) % 4 < f % 4):
                ink = "."
            c[y][x] = ink
    return c


def write_rampart_only():
    """Bounded six-sequence revision; preserve every other authored asset."""
    for reduced in [False, True]:
        for phase in ["formation", "active", "decay"]:
            path = ROOT / "source/frames" / ("magic.reaction.fortify.%s.%s.json" % (phase, "reduced" if reduced else "normal"))
            asset = json.loads(path.read_text(encoding="utf-8"))
            assert len(asset["frames"]) == 4 and asset["pivot_px"] == [16, 26]
            asset["palette"].update(dict(zip(("d", "b", "h"), [color + "ff" for color in PALETTES["earth"]])))
            for index, frame in enumerate(asset["frames"]):
                frame["pixels"] = frame_strings(rampart_pose(index, phase, reduced))
            path.write_text(json.dumps(asset, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("AUTHORED six Rampart-only tileable masonry sequences; other sources untouched")


def frostway_pose(f, phase, reduced):
    """Seamless frozen floor: shallow cracks and skate glints, never a wall.

    Every coordinate rule repeats on a 32px tile. The renderer alone clips this
    material to the actual lane; no painted outline implies extra collision.
    """
    c = blank()
    pose = f % 4
    for y in range(32):
        for x in range(32):
            # Shallow offset facets have no extrusion, ground shadow or black
            # masonry joints. Cyan remains the majority surface at every pose.
            diagonal = (x - 2 * y) % 32
            cross_crack = (x + 2 * y + 11) % 32
            ink = "b"
            if diagonal in (0, 1) or (cross_crack == 0 and diagonal < 13):
                ink = "d"
            elif diagonal == 2 or (cross_crack == 1 and diagonal < 13):
                ink = "h"
            # Parallel short skate streaks move along the surface instead of
            # growing upright crystals or pulsing the entire active field.
            glint = (x + 2 * y - (0 if reduced else 8 * pose)) % 32
            if glint in (8, 9) and (y % 16) in range(4, 10):
                ink = "h"
            if not reduced and glint == 10 and y % 16 == 7:
                ink = "h"
            # Broad native-pixel facets freeze and thaw, without radius rings.
            # The checker order has a 32px period in both axes and does not
            # make the field's authoritative edge advance ahead of admission.
            facet = ((x // 4) * 3 + (y // 4) * 5) % 8
            if phase == "formation" and facet >= (1, 3, 6, 8)[pose]:
                ink = "."
            elif phase == "decay" and facet < (0, 2, 4, 6)[pose]:
                ink = "."
            c[y][x] = ink
    return c


def write_frostway_only():
    """Revise only six stable glacier assets; do not regenerate other art."""
    for reduced in [False, True]:
        for phase in ["formation", "active", "decay"]:
            path = ROOT / "source/frames" / ("magic.reaction.glacier.%s.%s.json" % (phase, "reduced" if reduced else "normal"))
            asset = json.loads(path.read_text(encoding="utf-8"))
            assert len(asset["frames"]) == 4 and asset["pivot_px"] == [16, 26]
            # Preserve the C1 canonical Ice ramp for both input-token cases.
            for tokens in (("d", "b", "h"), ("D", "B", "H")):
                asset["palette"].update(dict(zip(tokens, [color + "ff" for color in PALETTES["ice"]])))
            asset["geometry_scaling_rules"] = "tile_flat_ice_inside_authoritative_corridor_mask; non_solid_floor_no_cover_or_range_outline; fixed_native_pivot; phase_interruptible"
            for index, frame in enumerate(asset["frames"]):
                frame["pixels"] = frame_strings(frostway_pose(index, phase, reduced))
            path.write_text(json.dumps(asset, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("AUTHORED six Frostway-only flat frozen-floor sequences; other sources untouched")


def write_palette_only():
    """Recolor existing native pixels, never regenerate poses or gameplay metadata.

    Both token cases remain separate input-element ramps for every mixed recipe;
    Steam alone has a neutral result-material identity. UI and all flight,
    impact, ingredient and reaction phases now use the same canonical colors.
    Movement dust, protection, boundary helpers and source evidence are untouched.
    """
    catalog = json.loads((REPO / "content/reactions/first_eight_element_reactions_v1.json").read_text(encoding="utf-8"))
    recipes = {recipe["id"]: recipe["input_elements"] for recipe in catalog["reactions"]}
    assert len(recipes) == 36
    changed = 0
    inspected = 0
    for path in sorted((ROOT / "source/frames").glob("*.json")):
        asset = json.loads(path.read_text(encoding="utf-8"))
        element, reaction = asset.get("element_id"), asset.get("reaction_id")
        if element not in ORDER and reaction not in recipes:
            continue
        before = json.dumps({key: value for key, value in asset.items() if key != "palette"}, sort_keys=True)
        colors = dict(asset["palette"])
        pair = [element, element] if element in ORDER else recipes[reaction]
        if reaction == "steam":
            pair = ["steam", "steam"]
        elif reaction in ("cinderveil", "static_shroud"):
            pair = list(reversed(pair))
        for tokens, palette in zip((("d", "b", "h"), ("D", "B", "H")), pair):
            for token, color in zip(tokens, PALETTES[palette]):
                if token in colors:
                    colors[token] = color + "ff"
        inspected += 1
        if colors != asset["palette"]:
            asset["palette"] = colors
            assert before == json.dumps({key: value for key, value in asset.items() if key != "palette"}, sort_keys=True)
            path.write_text(json.dumps(asset, indent=2) + "\n", encoding="utf-8", newline="\n")
            changed += 1
    roles_path = ROOT / "source/palette_roles.json"
    roles = json.loads(roles_path.read_text(encoding="utf-8"))
    roles["element_ramps"] = PALETTES
    roles["canonical_source"] = "content/visual/visual_language_v1.json"
    roles["steam"] = "neutral lilac-grey material ramp only; not blue Ice/Water or orange Fire"
    roles["mixed_reactions"] = "two separate input ramps, never an averaged tint; shape and cadence remain authored per result"
    roles_path.write_text(json.dumps(roles, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"PALETTE ONLY: inspected {inspected}, recolored {changed}; all pixel rows, timing, pivots, silhouettes and gameplay metadata preserved")


def reaction_pose(r, f, phase, reduced):
    if r["id"] == "fortify":
        return rampart_pose(f, phase, reduced)
    if r["id"] == "glacier":
        return frostway_pose(f, phase, reduced)
    if r["id"] == "steam":
        return steam_vapor_pose(f, phase, reduced)
    rid=r["id"]; layout=PAIR_LAYOUTS[rid]; a,b=r["elements"]
    c=blank(); remap={"d":"D","b":"B","h":"H"}
    main="steam" if rid=="steam" else a
    if layout in ["brick","brick_frost"]:
        stamp(c,rows(BRICK),16,18)
        if layout!="brick": stamp(c,small_grain(b),11+f%2,12,remap)
    elif layout in ["facet","lens_facet","bend_facet","black_shard"]:
        stamp(c,rows(CRYSTAL),16,16)
        # Facets never contain rays; branch geometry must be supplied by gameplay.
        if layout=="lens_facet": stamp(c,small_grain(b),23,21,remap)
        elif layout=="black_shard": line(c,(9,22),(22,11),"B")
        else: line(c,(12,18),(18,10),"H")
    elif layout in ["crack","root","root_node","crust"]:
        if layout in ["crust","root_node"]: stamp(c,rows(BRICK),16,18)
        for x,y,ex,ey in [(15,17,6,8),(15,17,26,11),(15,17,10,27)]:
            line(c,(x,y),(x-2,y-4),"B"); line(c,(x-2,y-4),(ex,ey),"B")
            if not reduced: line(c,(x+1,y),(ex+1,ey),"d")
        if layout=="crust": stamp(c,small_grain("fire"),18,17,remap)
        if layout=="root_node": stamp(c,small_grain("charge"),16,16,remap)
    elif layout in ["silt","mirror","undertow","charged_wave","wave"]:
        stamp(c,rows(PLATE),16,22)
        stamp(c,motif("water",f),15,16,remap if b=="water" else None)
        if layout=="mirror": line(c,(10,23),(23,23),"H"); line(c,(14,21),(21,21),"H")
        if layout=="undertow": stamp(c,small_grain("dark"),22,18,remap)
        if layout=="charged_wave": stamp(c,small_grain("charge"),24,22,remap)
        if layout=="silt": line(c,(8,23),(19,23),"d"); line(c,(13,25),(24,25),"d")
    elif layout in ["billow","vapour","ember_cloud","static_cloud","mist"]:
        # Pale billows; thin lower rim and asymmetric lobe exchange, never a ring.
        stamp(c,motif("steam",f),16,17)
        if layout in ["ember_cloud","static_cloud"]:
            stamp(c,small_grain(a),10,23,remap)
            if not reduced: stamp(c,small_grain(a),24,16,remap)
        if layout=="mist": line(c,(4,24),(16,24),"h")
    elif layout in ["branch","frost_wire","spark_line"]:
        for start,end in [((3,17),(10,13)),((10,13),(16,19)),((16,19),(23,14)),((23,14),(29,16))]:
            line(c,start,end,"H"); line(c,(start[0],start[1]+1),(end[0],end[1]+1),"b")
        if layout=="frost_wire": stamp(c,small_grain("ice"),16,17)
        elif layout=="spark_line": stamp(c,small_grain("light"),16,17,remap)
        elif not reduced: stamp(c,small_grain("fire"),12+f,13)
    elif layout in ["flame_fork","flame_shear"]:
        stamp(c,motif("fire",f),12,18)
        if not reduced: stamp(c,motif("fire",f+1),23,17 if layout=="flame_shear" else 22)
    elif layout in ["frost_tip","hail"]:
        stamp(c,rows(CRYSTAL) if layout=="frost_tip" else motif("ice",f),16,16,remap)
        if not reduced: stamp(c,small_grain("water" if layout=="frost_tip" else "wind"),6,22)
    elif layout in ["ribbon","band","inward"]:
        stamp(c,motif("dark" if layout in ["band","inward"] else "wind",f),16,16)
        if layout=="band": line(c,(4,10),(14,10),"B"); line(c,(19,23),(29,23),"B")
        if layout=="inward" and not reduced:
            # Steps move inward; never an expanding damage wave.
            for x,y in [(4+f,8+f),(27-f,24-f)]: stamp(c,small_grain("dark"),x,y)
    elif layout=="split":
        pat=rows(POSES["dark"][0]); stamp(c,pat,21,16,remap)
        stamp(c,rows(POSES["dark"][0]),10,16,flip=True)
    else: # Ion node, overload storage, measured radiance, solar flash.
        stamp(c,motif(a,f),16,16)
        if layout=="node": stamp(c,rows(PLATE),16,24)
        if not reduced:
            stamp(c,small_grain(b),6,8+f%2,remap)
            stamp(c,small_grain(b),25,24-f%2,remap)
    if phase=="formation":
        # Unfilled material grows in three restrained rows; essential warning is separate.
        for y in range(32):
            for x in range(32):
                if y < [22,17,11,0][f] or (x+y)%5==0:
                    c[y][x]="."
                elif c[y][x] in ["h","H"]: c[y][x]="b" if c[y][x]=="h" else "B"
        if not any(ch!="." for row in c for ch in row):
            stamp(c,small_grain(main),16,23)
    elif phase=="decay":
        # Deliberate clusters break away. Do not smear alpha or change the ground anchor.
        for y in range(32):
            for x in range(32):
                if (x//3+y//3)%4 < f: c[y][x]="."
    return c

def read_authority():
    path=REPO/"src/sim/chemistry/element_chemistry_system.gd"
    text=path.read_text(encoding="utf-8")
    block=text.split("const RECIPE_ROWS: Array = [",1)[1].split("\n]",1)[0]
    raw=[json.loads(line.strip().rstrip(",")) for line in block.splitlines() if line.strip().startswith("[")]
    extent_match = re.search(r"const EXTENT_RATIO: int = (\d+)", text)
    assert extent_match, "Native metadata requires an explicit authoritative extent ratio"
    extent_ratio = int(extent_match.group(1))
    assert 1000 <= extent_ratio <= 2000
    assert 'return base * EXTENT_RATIO / 1000' in text, "Review new authority extent formula before exporting"
    assert '"radius": extent(int(row[7])), "length": extent(int(row[8]))' in text, "Review recipe extent admission before exporting"
    catalog=json.loads((REPO/"content/reactions/first_eight_element_reactions_v1.json").read_text())
    assert len(raw)==36
    recipes=[]
    for i,row in enumerate(raw):
        rid,a,b,shape,formation,active,decay,radius,length,speed,pulse,health=row
        metadata=next(x for x in catalog["reactions"] if x["id"]==rid)
        assert metadata["wire_id"]==301+i and metadata["input_elements"]==[ORDER[a-1],ORDER[b-1]]
        recipes.append(dict(id=rid,wire_id=301+i,elements=[ORDER[a-1],ORDER[b-1]],shape=shape,
            formation_ms=formation,active_ms=active,decay_ms=decay,
            formation_ticks=(formation*120+999)//1000,active_ticks=(active*120+999)//1000,decay_ticks=(decay*120+999)//1000,
            nominal_radius_px=(radius*extent_ratio//1000)/1000,nominal_length_px=(length*extent_ratio//1000)/1000,
            speed_px_per_second=speed/1000,pulse_ms=pulse,cover_health=health,
            source_scope="RECIPE_ROWS plus verified integer EXTENT_RATIO policy and live contains/update/apply functions; catalog descriptive map_effects are not implemented promises"))
    sources=[]
    for p in [path,REPO/"content/reactions/first_eight_element_reactions_v1.json",REPO/"content/visual/visual_language_v1.json",REPO/"content/visual/foundation_spell_visuals_v1.json",REPO/"content/visual/spell_animation_skeletons_v1.json"]:
        sources.append(dict(path=p.relative_to(REPO).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    return recipes,sources

def movement_kit(reduced):
    variant="reduced" if reduced else "normal"
    base=dict(variant=variant,palette="dust",budget=8)
    # Original stepped contact loop, flattened onto cardinal ground. These are
    # foot-contact marks only, never collision/area/immunity boundaries.
    ring=[
        """......hhhhhh......
....hh......hh....
...h..........h...
..h............h..
...h..........h...
....hh......hh....
......hhhhhh......""",
        """....hhhh....hhhh....
..hh............hh..
.h................h.
h..................h
.h................h.
..hh............hh..
....hhhh....hhhh....""",
        """...hhh..........hhh...
.hh................hh.
h....................h
......................
h....................h
.hh................hh.
...hhh..........hhh...""",
        """..hh..............hh..
.h..................h.
......................
......................
......................
.h..................h.
..hh..............hh..""",
    ]
    for key in ["jump_takeoff","landing_contact"]:
        frames=[]
        for f in range(4):
            p=blank(); stamp(p,rows(ring[f]),16,24)
            if not reduced and f>0:
                stamp(p,small_grain("dust"),5,20-f); stamp(p,small_grain("dust"),26,20-f)
            frames.append(p)
        add("movement."+key,frames,[3,4,5,6] if key=="jump_takeoff" else [4,6,8,10],
            phase="takeoff" if key=="jump_takeoff" else "landing",pivot=(16,24),attachment="ground_feet",
            role="harmless_movement",geometry="1x; ground_plane; hide_on_authoritative_event_end; never_a_protection_cue",**base)
    for key in ["landing_dust","slide_dust","walljump_burst"]:
        frames=[]
        for f in range(5):
            p=blank()
            if f<3: stamp(p,motif("dust",f),16+(f if key!="landing_dust" else 0),20-f)
            if not reduced or f>=3:
                for x,y in [(7-f,22-f),(24+f,19-f)]:
                    stamp(p,small_grain("dust"),x,y)
            frames.append(p)
        add("movement."+key,frames,[4,6,8,10,12],phase="active",pivot=(16,24),attachment="wall_contact" if key=="walljump_burst" else "ground_feet",
            role="harmless_movement",direction="billboard",geometry="1x; material_dust; emit_from_actual_contact; no_stretch",**base)
    sparks=[]
    for f in range(4):
        p=blank()
        for k in range(1 if reduced else 3):
            stamp(p,small_grain("charge"),16+f*2,12+k*6-f)
        sparks.append(p)
    add("movement.wallrun_sparks",sparks,[4,6,4,10],loop=True,phase="active",pivot=(16,16),palette="charge",variant=variant,
        attachment="actual_wall_contact",role="harmless_movement",budget=8,
        geometry="hide_on_wall_detach; direction_away_from_contact_normal; short_angular_sparks")
    tail=[]
    for f in range(4):
        p=blank()
        for y in [11,21]:
            step=[0,1,2,1][f]
            line(p,(5+step*2,y),(25,y),"h");line(p,(8+step*2,y+1),(25,y+1),"b")
        tail.append(p)
    add("movement.slide_trail",tail,[8]*4,loop=True,direction="east",phase="active",attachment="velocity_frame_at_feet",role="harmless_movement",
        geometry="rotate_cosmetic_strip_to_continuous_travel; no_simulation_quantization; omit_when_stationary",**base)
    # Afterimage has no body baked in: alpha stencil multiplies the caller's
    # body-only atlas sample, without hand magic or invulnerability marks.
    masks=[]
    for f in range(4):
        p=blank(32,48)
        for y in range(4,44):
            for x in range(4,28):
                if (x//3+y//3)%4>=f: p[y][x]="h"
        masks.append(p)
    add("movement.air_dash_afterimage_mask",masks,[4,5,6,8],phase="active",pivot=(16,44),palette="light",variant=variant,
        role="caller_body_alpha_mask",attachment="caller_body_anchor_history",budget=8,
        geometry="multiply_caller_body_only_alpha; fit_stencil_to_58_68_76_envelope; 2_copies_normal_1_reduced; alpha_0.16_0.08; no_protection_or_hand_layers; clear_on_dash_end")
    for key in ["protection_corner","protection_badge","float_wing","float_budget_tick"]:
        p=blank(16,16)
        if key=="protection_corner":
            for y in range(3,13):
                for x in range(3,6): p[y][x]="d" if x==3 else "h" if x==4 else "b"
            for x in range(3,13):
                for y in range(3,6): p[y][x]="d" if y==3 else "h" if y==4 else "b"
        elif key=="protection_badge": stamp(p,motif("protection",0),8,8)
        elif key=="float_wing":
            for a,b in [((2,10),(8,10)),((8,10),(12,6)),((12,6),(14,6))]:
                line(p,a,b,"h");line(p,(a[0],a[1]+1),(b[0],b[1]+1),"b")
        else:
            for y in range(5,11):
                for x in range(6,10): p[y][x]="h" if x==6 else "b"
        add("movement."+key,[p],[1],phase="active",loop=False,pivot=(8,8),palette="protection",variant=variant,
            role="essential_protection",attachment="body_envelope" if key=="protection_corner" else "above_body",
            budget=8,geometry="show_only_on_current_authoritative_protection; zero_fade_on_exit; same_pixels_normal_reduced; corner_flip_only; no_wait_for_animation")

def boundary_kit(reduced):
    v="reduced" if reduced else "normal"
    for phase in ["formation","active","decay"]:
        p=blank(8,8)
        for x in range(8):
            if phase=="formation" and x in [3,4]: continue
            for y in [2,3,4]: p[y][x]="i" if y==2 else "h" if y==3 else "b"
        add("geometry.boundary_"+phase,[p],[1],phase=phase,palette="light",variant=v,loop=False,pivot=(0,3),
            direction="east",attachment="coverage_edge",role="essential_boundary",budget=32,
            geometry="example_edge_strip; use_exact_runtime_coverage_mask_outer_and_inner_edges; continuous_capsule_endpoints; do_not_replace_mask_with_sprite_ring; no_fade_while_gameplay_active")
    for kind in ["connected_node","unconnected_node"]:
        p=blank(12,12)
        # Filled node vs open socket: no discharge is embedded in either icon.
        for x in range(3,9): p[3][x]="h"; p[8][x]="b"
        for y in range(4,8): p[y][3]="h";p[y][8]="b"
        if kind=="connected_node":
            for y in range(5,7):
                for x in range(5,7): p[y][x]="h"
        add("geometry."+kind,[p],[1],phase="active",palette="charge",variant=v,pivot=(6,6),
            attachment="actual_link_node",role="essential_link_state",budget=32,
            geometry="open_socket_when_no_live_link; never_draw_connector_without_path_points")

def main():
    recipes,sources=read_authority()
    # Representative batch first, then common vocabulary. No shared file writes.
    for reduced in [False,True]:
        for element in ["fire","water"]: element_kit(element,reduced)
        steam=next(r for r in recipes if r["id"]=="steam")
        for phase in ["formation","active","decay"]:
            add("reaction.steam."+phase,[reaction_pose(steam,f,phase,reduced) for f in range(4)], [12]*4,
                palette="steam",secondary_palette="steam",reaction="steam",phase=phase,loop=phase=="active",
                pivot=(16,26),attachment="ground_veil_cell",variant="reduced" if reduced else "normal",budget=24,
                role="concealment_material",geometry="clip_billows_inside_actual_growing_disk; no_orange_pixels; 30_to_90px_authority_radius; concealment_ends_350ms_before_decay")
    for reduced in [False,True]:
        for element in ORDER:
            if element not in ["fire","water"]: element_kit(element,reduced)
        for r in recipes:
            if r["id"]=="steam": continue
            for phase in ["formation","active","decay"]:
                pair_palette = [r["elements"][1], r["elements"][0]] if r["id"] in ["cinderveil","static_shroud"] else r["elements"]
                add("reaction."+r["id"]+"."+phase,[reaction_pose(r,f,phase,reduced) for f in range(4)],
                    [10]*4,palette=pair_palette[0],secondary_palette=pair_palette[1],reaction=r["id"],phase=phase,
                    loop=phase=="active",pivot=(16,26) if r["shape"] not in ["branch","reveal_line","frost_path"] else (16,16),
                    variant="reduced" if reduced else "normal",attachment="authoritative_geometry_cell",budget=16,
                    role="reaction_material",geometry="repeat_or_stamp_inside_actual_"+r["shape"]+"_mask; no_fixed_whole_effect_footprint; phase_interruptible")
        movement_kit(reduced); boundary_kit(reduced)
    out=ROOT/"source/frames"; out.mkdir(parents=True,exist_ok=True)
    for asset in ASSETS:
        (out/(asset["id"]+".json")).write_text(json.dumps(asset,indent=2)+"\n",encoding="utf-8",newline="\n")
    (ROOT/"source/authority_snapshot.json").write_text(json.dumps(dict(
        source_checkpoint="286bd8f",source_files=sources,recipes=recipes,deposit_lifetime_ticks=LIFE,
        source_not_modified=True,metadata_precedence="live GDScript > catalog legacy prose"),indent=2)+"\n",encoding="utf-8",newline="\n")
    (ROOT/"source/palette_roles.json").write_text(json.dumps(dict(element_ramps=PALETTES,ink=INK,
        steam="neutral material ramp only; does not redefine Fire or Water",dust="neutral movement dust",
        protection="separate non-element authority information",logical_pixel_world_px=1,terrain_reference_px=32,
        body_reference_heights_px=[58,68,76]),indent=2)+"\n",encoding="utf-8",newline="\n")
    print(f"AUTHORED {len(ASSETS)} editable pixel sequences, {sum(len(a['frames']) for a in ASSETS)} frames")

if __name__=="__main__":
    import sys
    if sys.argv[1:] == ["--steam-only"]:
        write_steam_only()
    elif sys.argv[1:] == ["--rampart-only"]:
        write_rampart_only()
    elif sys.argv[1:] == ["--frostway-only"]:
        write_frostway_only()
    elif sys.argv[1:] == ["--palette-only"]:
        write_palette_only()
    elif sys.argv[1:]:
        raise SystemExit("Use --steam-only, --rampart-only, --frostway-only or --palette-only for a bounded revision")
    else:
        main()
