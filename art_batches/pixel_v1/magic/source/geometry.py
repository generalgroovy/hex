"""Read-only reference port of live chemistry footprint predicates.

Coordinates are fixed point (1000 units / world pixel), matching current source.
This is for candidate masks and QA, not a replacement simulation implementation.
The integrator should call its actual authority geometry/visibility functions.
"""
import math

PATHS={"water_path","frost_path","branch"}
LANES={"corridor","front","growing_strip","pulse_lane","bands","reveal_line"}

def div(a,b):
    return (abs(a)//abs(b)) * (-1 if (a<0)!=(b<0) else 1)

def scaled(v,amount): return (div(v[0]*amount,1000),div(v[1]*amount,1000))
def add(a,b):return a[0]+b[0],a[1]+b[1]
def sub(a,b):return a[0]-b[0],a[1]-b[1]
def squared(v):return v[0]*v[0]+v[1]*v[1]

def segment_near(point,start,end,radius):
    delta=sub(end,start);offset=sub(point,start);length=squared(delta)
    if length==0:return squared(offset)<=radius*radius
    dot=max(0,min(length,offset[0]*delta[0]+offset[1]*delta[1]))
    closest=add(start,scaled(delta,div(dot*1000,length)))
    return squared(sub(point,closest))<=radius*radius

def phase_at(state,tick):
    if tick<state["created_tick"] or tick>=state["expiry_tick"]:return "expired"
    if tick<state["active_tick"]:return "formation"
    if tick<state["decay_tick"]:return "active"
    return "decay"

def coverage(state,point,tick):
    """Geometry only, like contains(); lifecycle and collision clearance separate."""
    origin=state["position"];shape=state["shape"];radius=state["radius"];length=state["length"]
    distance=squared(sub(point,origin))
    if shape in {"ring","annulus"}:return length*length<=distance<=radius*radius
    if shape in PATHS:
        path=state.get("path_points",[])
        if len(path)<2:return shape=="water_path" and distance<=radius*radius
        return any(segment_near(point,a,b,radius) for a,b in zip(path,path[1:]))
    if shape in LANES:
        if not segment_near(point,origin,state["endpoint"],radius):return False
        if shape=="pulse_lane":
            age=max(0,tick-state["active_tick"])%54
            moving=add(origin,scaled(state["direction"],div(length*age,54)))
            return squared(sub(point,moving))<=25000*25000
        return True
    if shape in {"cover","plane","lens"}:
        d=state["direction"];side=(-d[1],d[0]);offset=scaled(side,div(length,2))
        return segment_near(point,sub(origin,offset),add(origin,offset),radius)
    return distance<=radius*radius

def fixture(recipe,tick,direction=(1000,0),linked=True):
    """Empty-world illustrative state using current dimensions, not gameplay proof."""
    active=recipe["formation_ticks"];decay=active+recipe["active_ticks"]
    age=max(0,min(tick,decay)-active)
    radius=round(recipe["nominal_radius_px"]*1000);length=round(recipe["nominal_length_px"]*1000)
    travel=div(round(recipe["speed_px_per_second"]*1000)*age,120)
    pos=scaled(direction,travel)
    if recipe["id"]=="steam":radius=min(90000,30000+div(age*60000,108))
    if recipe["id"]=="freeze":length=min(140000,20000+div(age*120000,144))
    path=[pos,add(pos,scaled(direction,length))] if linked and recipe["shape"] in PATHS else []
    return dict(position=pos,endpoint=add(pos,scaled(direction,length)),direction=direction,
        path_points=path,radius=radius,length=length,shape=recipe["shape"],created_tick=0,
        active_tick=active,decay_tick=decay,expiry_tick=decay+recipe["decay_ticks"])

def sampled_mask(state,tick,width,height,origin_px=(0,0),pixel_world_size=1):
    """Pixel-centre occupancy sampling with ≤ half-pixel display error per axis."""
    from PIL import Image
    output=Image.new("L",(width,height),0)
    output.putdata([255 if coverage(state,(round((origin_px[0]+(x+0.5)*pixel_world_size)*1000),
        round((origin_px[1]+(y+0.5)*pixel_world_size)*1000)),tick) else 0 for y in range(height) for x in range(width)])
    return output

def optical_segments(returned_rays):
    """No synthesized lens branches. Preserve exact actual continuation origins."""
    return [(tuple(r["origin"]),tuple(r["end"])) for r in returned_rays]

def frame_index(asset,elapsed_ticks,authority_phase_active=True):
    if not authority_phase_active or elapsed_ticks<0:return None
    durations=[f["duration_ticks"] for f in asset["frames"]];total=sum(durations)
    if asset["loop"]:elapsed_ticks%=total
    elif elapsed_ticks>=total:return None if asset.get("end_behavior")=="hide" else len(durations)-1
    for i,d in enumerate(durations):
        if elapsed_ticks<d:return i
        elapsed_ticks-=d
    raise AssertionError("unreachable")
