"""Validate authored sources against exports and current source authority.

No integrity expectations are rewritten here. Source reconstruction is compared
pixel for pixel against every atlas frame. All reports stay in the pack folder.
"""
from pathlib import Path
import json,hashlib,math,sys
from PIL import Image,ImageChops
from geometry import coverage,fixture,frame_index,phase_at,optical_segments
from export_pack import decode

ROOT=Path(__file__).resolve().parents[1];REPO=ROOT.parents[2]
count=0;errors=[];notes=[]
def check(ok,message):
    global count
    count+=1
    if not ok:errors.append(message)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    m=json.loads((ROOT/"manifest.json").read_text());s=json.loads((ROOT/"source/authority_snapshot.json").read_text())
    check(m["schema_version"]==1 and m["contract_id"]=="flux-pixel-assets-v1" and m["namespace"]=="magic","manifest identity")
    check(len(m["reactions"])==36,"36 exact reactions")
    byid={a["id"]:a for a in m["assets"]};check(len(byid)==len(m["assets"]),"unique namespaced IDs")
    for src in m["source_files"]:
        p=REPO/src["path"]
        check(p.exists() and sha(p)==src["sha256"],"authority drift: "+src["path"])
    pages={}
    for page in m["atlases"]:
        path=ROOT/page["path"];im=Image.open(path);im.load();pages[page["path"]]=im
        check(im.mode=="RGBA" and im.size==(page["width"],page["height"]),"RGBA8 dimensions "+page["path"])
        check(sha(path)==page["sha256"],"atlas SHA256 "+page["path"])
        check(all(px==(0,0,0,0) for px in im.getdata() if px[3]==0),"zero hidden RGB / no white fringes "+page["path"])
    animated=0;seams=[];bbox_extrema={}
    for a in m["assets"]:
        sid=a["id"];path=(ROOT/a["source_path"]).resolve()
        check(path.is_relative_to(ROOT),"safe source path "+sid)
        check(sha(path)==a["source_sha256"],"source SHA256 "+sid)
        src=json.loads(path.read_text());images=[];page=pages[a["path"]]
        check(a["completion_status"]=="authored_candidate" and not a["runtime_integrated"],"truthful candidate status "+sid)
        check(a["variant"] in ["normal","reduced"],"variant "+sid)
        check(a["intended_simultaneous_instance_budget"]>0,"bounded instances "+sid)
        check(bool(a["geometry_scaling_rules"]) and bool(a["layer_role"]),"composition metadata "+sid)
        for i,f in enumerate(a["frames"]):
            x,y,w,h=f["rect"];im=page.crop((x,y,x+w,y+h));images.append(im)
            expected=decode(src,src["frames"][i])
            check(im.tobytes()==expected.tobytes(),f"source reconstruction {sid}:{i}")
            check(f["duration_ticks"]>0 and isinstance(f["duration_ticks"],int),f"120Hz duration {sid}:{i}")
            check(f["pivot_px"]==a["pivot_px"]==src["frames"][i]["pivot_px"],f"registered pivot {sid}:{i}")
            check(set(im.getchannel("A").getdata())<={0,255},f"binary authored alpha {sid}:{i}")
            check(set(im.getdata())<={tuple(bytes.fromhex(v)) for v in src["palette"].values()},f"palette membership {sid}:{i}")
            check(2<=x and 2<=y and x+w+2<=page.width and y+h+2<=page.height,f"atlas rectangle bounds {sid}:{i}")
            gutter=page.crop((x-2,y-2,x+w+2,y+h+2));gutter.paste((0,0,0,0),(2,2,w+2,h+2))
            check(not gutter.getbbox(),f"two transparent pixels of atlas padding {sid}:{i}")
            px,py=a["pivot_px"];check(0<=px<=w and 0<=py<=h,f"pivot within logical cell {sid}:{i}")
        unique=len({im.tobytes() for im in images})
        if unique>1:animated+=1
        if a["loop"] and len(images)>1:
            # Absolute changed-pixel count including alpha, for every cyclic seam.
            def delta(aa,bb):return sum(x!=y for x,y in zip(aa.getdata(),bb.getdata()))
            adjacent=[delta(aa,bb) for aa,bb in zip(images,images[1:])]
            seam=delta(images[-1],images[0]);maximum=max(adjacent)
            seams.append(dict(id=sid,last_to_first_changed_pixels=seam,max_internal_changed_pixels=maximum,ratio=round(seam/max(1,maximum),3)))
            # >1.5 is flagged for visual review, not silently declared seamless.
            if seam>max(4,maximum*1.5):notes.append("Loop seam needs review: "+sid)
        total=sum(f["duration_ticks"] for f in a["frames"])
        check(frame_index(a,0)==0,"first pose immediate "+sid)
        check(frame_index(a,5,False) is None,"authority kills immediately "+sid)
        if a["loop"]:check(frame_index(a,total)==0,"absolute loop wrap "+sid)
        elif a["end_behavior"]=="hide":check(frame_index(a,total) is None,"one shot expires "+sid)
        if a["layer_role"].startswith("essential_") and a["variant"]=="normal":
            other=byid[sid.replace(".normal",".reduced")]
            other_src=json.loads((ROOT/other["source_path"]).read_text())
            check(src["frames"]==other_src["frames"],"essential information identical in reduced "+sid)
        if sid.startswith("magic.steam") or a["reaction_id"]=="steam":
            forbidden={"5b1d12ff","dd5930ff","ffd169ff"}
            check(not forbidden.intersection(a["palette_rgba"]),"Steam is pale, never Fire orange "+sid)
    effects=["hand_prepare","hand_release","flight","flight_tail","impact","deposit_formation","deposit_active","deposit_decay","beam_body","beam_start","beam_end","spray_grain","burst_release","field_tile"]
    for e in s["deposit_lifetime_ticks"]:
        for effect in effects:
            for v in ["normal","reduced"]:
                check(f"magic.{e}.{effect}.{v}" in byid,f"coverage {e}/{effect}/{v}")
        for v in ["normal","reduced"]:
            a=byid[f"magic.{e}.beam_body.{v}"]
            for f in a["frames"]:
                x,y,w,h=f["rect"];im=pages[a["path"]].crop((x,y,x+w,y+h))
                check(im.crop((0,0,1,h)).tobytes()==im.crop((w-1,0,w,h)).tobytes(),"beam connector seam "+a["id"])
    for r in m["reactions"]:
        for phase in ["formation","active","decay"]:
            for v in ["normal","reduced"]:check(r["phases"][phase][v] in byid,"reaction module exists "+r["id"])
        st=fixture(r,r["formation_ticks"])
        check(phase_at(st,-1)=="expired" and phase_at(st,0)=="formation","unborn/formation "+r["id"])
        check(phase_at(st,st["active_tick"])=="active","active boundary "+r["id"])
        check(phase_at(st,st["decay_tick"])=="decay" and phase_at(st,st["expiry_tick"])=="expired","decay/expiry boundary "+r["id"])
        # Shape-specific empty-world geometric regression checks at fixed points.
        if r["shape"] in ["ring","annulus"]:
            check(not coverage(st,st["position"],st["active_tick"]),"safe centre "+r["id"])
            check(coverage(st,(st["length"],0),st["active_tick"]),"exact inner rim "+r["id"])
            check(not coverage(st,(st["radius"]+1,0),st["active_tick"]),"outer cutoff "+r["id"])
        if r["shape"] in ["cover","plane","lens"]:
            check(coverage(st,(0,st["length"]//2),st["active_tick"]),"perpendicular cover "+r["id"])
            check(not coverage(st,(st["radius"]+1000,0),st["active_tick"]),"cover thickness "+r["id"])
        if r["shape"] in ["branch","water_path","frost_path"]:
            unlinked=fixture(r,r["formation_ticks"],linked=False)
            check(coverage(unlinked,unlinked["position"],unlinked["active_tick"])==(r["shape"]=="water_path"),"unconnected semantics "+r["id"])
            check(not coverage(unlinked,(300000,0),unlinked["active_tick"]),"no invented link "+r["id"])
    steam=next(r for r in m["reactions"] if r["id"]=="steam")
    check(fixture(steam,steam["formation_ticks"])["radius"]==30000,"Steam starts 30px")
    check(fixture(steam,steam["formation_ticks"]+108)["radius"]==90000,"Steam 90px after 900ms")
    freeze=next(r for r in m["reactions"] if r["id"]=="freeze")
    check(fixture(freeze,freeze["formation_ticks"])["length"]==20000,"Freeze starts 20px")
    check(fixture(freeze,freeze["formation_ticks"]+144)["length"]==140000,"Freeze reaches 140px after 1200ms")
    hail=next(r for r in m["reactions"] if r["id"]=="hailstream");ht=hail["formation_ticks"]
    hs=fixture(hail,ht)
    check(coverage(hs,(0,0),ht) and not coverage(hs,(90000,0),ht),"Hail one initial pulse")
    check(coverage(hs,(90000,0),ht+27) and not coverage(hs,(0,0),ht+27),"Hail pulse halfway at225ms")
    check(coverage(hs,(0,0),ht+54),"Hail pulse repeats at450ms")
    rays=[dict(origin=[6000,7000],end=[22000,5000]),dict(origin=[6000,7000],end=[21000,10000])]
    check(optical_segments(rays)==[((6000,7000),(22000,5000)),((6000,7000),(21000,10000))],"optical continuation origins")
    check(optical_segments([])==[],"no rays invented")
    # Independent clock samplings must resolve the same pose at equal age.
    for rate in [30,60,120,144,240]:
        for a in [byid["magic.fire.flight.normal"],byid["magic.water.flight.normal"]]:
            check(frame_index(a,rate*(120/rate))==frame_index(a,120),"frame-rate independent sample "+str(rate))
    check(m["budgets"]["decoded_rgba_bytes"]<=m["budgets"]["maximum_decoded_rgba_bytes"],"decoded memory budget")
    report=dict(status="pass" if not errors else "fail",assertions=count,failures=len(errors),errors=errors,
        review_notes=notes,assets=len(m["assets"]),frames=sum(len(a["frames"]) for a in m["assets"]),
        animated_sequences=animated,constant_sequences=len(m["assets"])-animated,
        atlas_pages=len(m["atlases"]),decoded_rgba_bytes=m["budgets"]["decoded_rgba_bytes"],
        loop_seam_metrics=seams,source_scope="asset sources + atlas bytes + reference geometry port; not the production Godot renderer",
        runtime_visual_acceptance=False,user_accepted=False,performance_120fps_accepted=False)
    (ROOT/"QA-results.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8",newline="\n")
    print(f"{'PASS' if not errors else 'FAIL'}: {count} assertions, {len(errors)} failures; {len(notes)} loop-review notes; {animated} animated sequences")
    for e in errors[:30]:print(e)
    for n in notes[:20]:print(n)
    return 1 if errors else 0

if __name__=="__main__":sys.exit(main())
