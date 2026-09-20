"""Export editable pixel JSON into padded RGBA atlases and a candidate manifest.

Requires Pillow (already available on the authoring machine). No other package.
The frame JSON is authoritative; this command never reruns author.py.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
PAGE=1024
PADDING=2

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def rgba(code): return tuple(bytes.fromhex(code))

def decode(source,frame):
    grid=frame["pixels"]; w=len(grid[0]);h=len(grid)
    assert all(len(row)==w for row in grid), source["id"]+": ragged rows"
    image=Image.new("RGBA",(w,h),(0,0,0,0))
    image.putdata([rgba(source["palette"][c]) for row in grid for c in row])
    assert image.getbbox(),source["id"]+": empty key pose"
    assert set(image.getchannel("A").getdata()) <= {0,255}
    return image

def main():
    output=ROOT/"export";output.mkdir(exist_ok=True)
    source_dir=ROOT/"source/frames"
    sources=[(p,json.loads(p.read_text())) for p in sorted(source_dir.glob("*.json"))]
    assert sources,"Author or supply editable frame JSON first"
    pages=[Image.new("RGBA",(PAGE,PAGE),(0,0,0,0))]
    page_idx=0;x=0;y=0;shelf_h=0;assets=[]
    for path,src in sources:
        ims=[decode(src,f) for f in src["frames"]]
        w,h=ims[0].size
        assert all(im.size==(w,h) for im in ims)
        pitch=w+PADDING*2;strip_w=pitch*len(ims);strip_h=h+PADDING*2
        if x+strip_w>PAGE: x=0;y+=shelf_h;shelf_h=0
        if y+strip_h>PAGE:
            pages.append(Image.new("RGBA",(PAGE,PAGE),(0,0,0,0)));page_idx+=1;x=0;y=0;shelf_h=0
        asset={k:v for k,v in src.items() if k not in ["palette","frames"]}
        asset.update(path=f"export/magic_{page_idx:02}.png",source_path=path.relative_to(ROOT).as_posix(),
            source_sha256=sha(path),palette_rgba=list(src["palette"].values()),frame_size_px=[w,h],
            texture_filter="nearest",mipmaps=False,atlas_padding_px=PADDING,
            phase_interrupt_policy="authority_first; cancel_sequence_immediately_on_state_change",
            duration_tick_rate=120,frames=[])
        for i,(im,f) in enumerate(zip(ims,src["frames"])):
            px=x+i*pitch+PADDING;py=y+PADDING
            pages[-1].paste(im,(px,py))
            asset["frames"].append(dict(rect=[px,py,w,h],duration_ticks=f["duration_ticks"],pivot_px=f["pivot_px"]))
        assets.append(asset);x+=strip_w;shelf_h=max(shelf_h,strip_h)
    atlases=[]
    for i,page in enumerate(pages):
        path=output/f"magic_{i:02}.png";page.save(path,optimize=False)
        atlases.append(dict(path=path.relative_to(ROOT).as_posix(),width=PAGE,height=PAGE,
            mode="RGBA",sha256=sha(path),png_bytes=path.stat().st_size,decoded_bytes=PAGE*PAGE*4))
    snapshot=json.loads((ROOT/"source/authority_snapshot.json").read_text())
    # Every reaction uses a distinct material sequence plus a shape-specific
    # composition binding. An optical material is not a beam/ray instruction.
    recipes=[]
    for r in snapshot["recipes"]:
        optical=r["id"] in ["crystal_prism","crystal_lens","lightbend"]
        linked=r["shape"] in ["branch","water_path","frost_path"]
        recipes.append(dict(**r,completion_status="authored_composable_candidate",runtime_integrated=False,
            phases={phase:{v:f"magic.reaction.{r['id']}.{phase}.{v}" for v in ["normal","reduced"]} for phase in ["formation","active","decay"]},
            essential_boundary={phase:{v:f"magic.geometry.boundary_{phase}.{v}" for v in ["normal","reduced"]} for phase in ["formation","active","decay"]},
            composition=dict(mask_predicate="source/geometry.py:coverage",material_cell_px=32,
                layout="continuous_path" if r["shape"] in ["front","corridor","growing_strip","pulse_lane","bands","reveal_line"] or linked else "perpendicular_cover" if r["shape"] in ["cover","plane","lens"] else "area",
                safe_inner_radius_field="state.length" if r["shape"] in ["ring","annulus"] else None,
                links="actual_path_points_only; no_path_means_no_connector; water_path_keeps_local_disk" if linked else None,
                optical_rays="draw_only_actual_ray_interaction_returned_origins_and_endpoints; never_bake_branches_in_facets" if optical else None,
                reveal_conceal="sample_authoritative_flags_separately_from_vapour_animation; steam_conceal_ends_350ms_before_decay; shadowdraft_300ms_bands",
                hail="moving_25px_disk_intersected_with_radius_capsule; period_54_ticks; never_a_string_of_hail_projectiles" if r["id"]=="hailstream" else None,
                world_occlusion="caller_must_clip_effective_warning_to_collision_clear_line_visibility; this_pack_has_no_map",
                opacity_cap_normal=0.54 if r["id"] in ["steam","cinderveil","static_shroud"] else 0.82,
                opacity_cap_reduced=0.40 if r["id"] in ["steam","cinderveil","static_shroud"] else 0.64,
                reduced_instance_ratio=0.5,
                immediate_phase_cut=True)))
    manifest=dict(schema_version=1,contract_id="flux-pixel-assets-v1",namespace="magic",
        status="candidate_pack_not_runtime_integrated",source_checkpoint=snapshot["source_checkpoint"],
        provenance=dict(method="original_integer_pixel_keyposes_and_modular_pixel_composition",
            third_party_pixels=False,reference_principles_url="https://penusbmic.itch.io/",
            reference_use="expressive_key_poses_silhouette_spacing_and_material_motion_only",
            editable_source="source/frames/*.json",authoring_source="source/author.py",
            element_refinement_source="source/restyle_elements_v3.py",
            element_refinement_evidence="art_batches/magic_style_v3/source-proof.json",
            element_refinement_method="original_palette_index_drawings; outlined_material_motifs; no_reference_pixels_copied",
            license="original_project_candidate; project_distribution_license_not_changed"),
        import_rules=dict(format="PNG RGBA8",alpha="binary_authored_alpha; runtime_opacity_modulation_separate",
            logical_pixel_world_px=1,terrain_cell_reference_px=32,body_heights_reference_px=[58,68,76],
            filter="nearest",mipmaps=False,padding_px=PADDING,extrusion="transparent_rgba_zero_gutter",
            rotation="billboard_material_stays_upright; cosmetic_directional_strips_may_rotate_continuously; never_quantize_simulation_aim",
            position="smooth_interpolated_world_anchor; sampled_camera_transform; never_quantize_120Hz_authority",
            animation="120Hz_duration_ticks; absolute_phase_age; no_crossfade; no_delay_on_phase_change"),
        source_files=snapshot["source_files"],deposit_lifetime_ticks=snapshot["deposit_lifetime_ticks"],
        assets=assets,atlases=atlases,reactions=recipes,
        budgets=dict(atlas_pages=len(atlases),decoded_rgba_bytes=sum(a["decoded_bytes"] for a in atlases),
            maximum_decoded_rgba_bytes=32*1024*1024,normal_total_material_stamps=192,reduced_total_material_stamps=96,
            essential_boundaries_are_never_dropped=True,phase_sampler_allocations_per_tick=0,
            authority_capacity_reference={"deposits":128,"reactions":32},
            authority_capacities_are_not_modified=True,performance_acceptance="unprofiled_in_FLUX; no_FPS_claim"))
    (ROOT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8",newline="\n")
    print(f"EXPORTED {len(assets)} sequences / {sum(len(a['frames']) for a in assets)} frames / {len(atlases)} atlases / {manifest['budgets']['decoded_rgba_bytes']} RGBA bytes")

if __name__=="__main__": main()
