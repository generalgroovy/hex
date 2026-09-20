"""Compare the single garment-volume refinement to its preserved first bake."""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[2] / "assets/sprites/wireframe_motion_v2"
PRIOR = HERE / "previous-export-adventurer-v1"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    old = json.loads((PRIOR / "manifest.json").read_text(encoding="utf-8"))
    new = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
    for field in ("schema_version", "cell", "pivot", "presentation_scale", "style_id", "directions", "base_rows", "locomotion"):
        assert old[field] == new[field], field
    previous_evidence = json.loads((PRIOR / "evidence.json").read_text(encoding="utf-8"))
    evidence = json.loads((HERE / "evidence.json").read_text(encoding="utf-8"))
    for field in ("exporter_sha256", "rig_data_sha256", "source_rig_sha256", "source_standing_heights", "standing_heights", "fixed_bone_checks", "plant_and_non_crossing_checks", "ankle_included_angle_degrees", "knee_included_angle_degrees"):
        assert previous_evidence[field] == evidence[field], field
    assert evidence["rig_data_sha256"] == sha(HERE / "rig-data.json")
    assert evidence["rasterizer_sha256"] == sha(HERE / "build.py")
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 14)
    board = Image.new("RGB", (3*192, 264), "#ddd1b7")
    draw = ImageDraw.Draw(board)
    draw.text((8, 8), "V1 -> FULLER GARMENT VOLUME / SAME POSE AND HEIGHT", font=font, fill="#382b20")
    metrics = {}
    for index, body in enumerate(("small", "middle", "large")):
        for field in ("reference_height", "display_height"):
            assert old["sizes"][body][field] == new["sizes"][body][field]
        for bank in ("base", "locomotion", "sprint"):
            for field in (bank, bank+"_dimensions"):
                assert old["sizes"][body][field] == new["sizes"][body][field]
            for folder, manifest in ((PRIOR, old), (OUT, new)):
                path = folder / f"{body}-{bank}.png"
                assert sha(path) == manifest["sizes"][body][bank+"_sha256"]
                with Image.open(path) as page:
                    assert hashlib.sha256(page.convert("RGBA").tobytes()).hexdigest() == manifest["sizes"][body][bank+"_rgba_sha256"]
        before = Image.open(PRIOR / f"{body}-base.png").convert("RGBA")
        after = Image.open(OUT / f"{body}-base.png").convert("RGBA")
        areas = []
        for aim in range(8):
            region = (aim*96, 0, (aim+1)*96, 96)
            a,b = before.crop(region),after.crop(region)
            assert a.getbbox()[1] == b.getbbox()[1], (body,aim,"crown row")
            assert a.getbbox()[3] == b.getbbox()[3] == 84, (body,aim,"foot row")
            opaque_a = a.getchannel("A").histogram()[255]
            opaque_b = b.getchannel("A").histogram()[255]
            assert opaque_b > opaque_a, (body,aim,"no fuller silhouette")
            areas.append({"aim":aim,"prior_opaque_pixels":opaque_a,"current_opaque_pixels":opaque_b})
            if aim in (0,2):
                row = 0 if aim == 0 else 1
                board.paste(a, (index*192, 52+row*100), a)
                board.paste(b, (index*192+96, 52+row*100), b)
        draw.text((index*192+8,32),body.upper()+"  V1 / VOLUME",font=font,fill="#382b20")
        metrics[body] = areas
    board.save(HERE / "adventurer-volume-comparison-1x.png")
    board.resize((board.width*4,board.height*4),Image.Resampling.NEAREST).save(HERE / "adventurer-volume-comparison-4x.png")
    receipt = {
        "status":"offline_volume_refinement_passed_pending_runtime_import_and_full",
        "prior_checkpoint":"previous-export-adventurer-v1",
        "manifest_sha256":sha(OUT / "manifest.json"),
        "evidence_sha256":sha(HERE / "evidence.json"),
        "rasterizer_sha256":sha(HERE / "build.py"),
        "rig_data_sha256":sha(HERE / "rig-data.json"),
        "unchanged_contracts":["All 3312 source poses and source bone geometry", "All 384 eight-phase travel/aim pairs", "Nine page paths, dimensions, phase indices and schema", "Uniform 0.92 scale and pivot 48,84", "South visible heights 53/63/70", "All 24 grounded crown and foot rows"],
        "all_24_grounded_silhouettes_have_more_opaque_garment_pixels":True,
        "grounded_pixel_areas":metrics,
        "engine_run_for_this_revision":False,
        "limits":["One shared three-size adventurer foundation, not unique race skins", "Offline visual review is not human in-game acceptance"]
    }
    (HERE / "adventurer-volume-verification.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print("PASS: nine prior and nine current PNG/RGBA digests; unchanged rig, mapping and all24 grounded crown/foot rows; all24 silhouettes fuller")


if __name__ == "__main__":
    main()
