"""Final D8 test-only refinement; frozen v2 remains the old candidate oracle."""
from pathlib import Path
import hashlib
ROOT = Path(r'C:\Users\sende\Projects\hex')
assert Path.cwd().resolve() == ROOT.resolve()
p = ROOT / 'tests/support/hex_viewport_candidate.gd'
assert hashlib.sha256(p.read_bytes()).hexdigest() == 'd7bd92c559c3b983b3b981558f982ecf5cf942cffbc421d9faaa85300a332bd1'
s = p.read_text(encoding='utf-8')
needle = '\tvar grown_visible: Rect2 = grown_visible_world_rect(visible_world, zoom)\n'
assert s.count(needle) == 1
s = s.replace(needle, needle + '''\t# Exact base-world regions share canonical cell polygons after full preparation.
\t# Keep this visibility index local to the call; generic courts retain per-region
\t# fail-open checks, including their accepted approximate or unusual polygons.
\tvar cell_visibility: Dictionary = {}
\tvar all_cells_visible: bool = court.get_script() == HexChemistryWorldScript
\tif all_cells_visible:
\t\tfor cell: Vector2i in _cells:
\t\t\tvar visible: bool = region_visible({"polygon": _vertices.get(cell)}, grown_visible)
\t\t\tcell_visibility[cell] = visible
\t\t\tif not visible: all_cells_visible = false
''')
old_args = ', grown_visible, diagnostics, collect_diagnostics)'
assert s.count(old_args) == 7
s = s.replace(old_args, ', grown_visible, diagnostics, collect_diagnostics, cell_visibility, all_cells_visible)')
signature = 'grown_visible: Rect2, diagnostics: Dictionary, collect_diagnostics: bool) -> void:'
assert s.count(signature) == 5
s = s.replace(signature, 'grown_visible: Rect2, diagnostics: Dictionary, collect_diagnostics: bool, cell_visibility: Dictionary, all_cells_visible: bool) -> void:')
calls = {
    'mirror_product': '_draw_mirror_product(canvas, regions_by_cell, material, tick, reduced)',
    'water': '_draw_water(canvas, _views, regions_by_cell, tick, reduced)',
    'fire': '_draw_fire(canvas, _views, regions_by_cell, tick, reduced)',
    'steam': '_draw_steam(canvas, views, regions_by_cell, tick, reduced)',
    'shared_material': '_draw_shared_material(canvas, regions_by_cell, material, tick, reduced)',
}
for name, call in calls.items():
    start = s.index('func _candidate_draw_' + name + '(')
    end = s.index('\n', start)
    s = s[:end+1] + '\tif all_cells_visible and not collect_diagnostics:\n\t\t' + call + '\n\t\treturn\n' + s[end+1:]
old_cell = '\tfor cell: Vector2i in regions_by_cell:\n'
assert s.count(old_cell) == 5
s = s.replace(old_cell, old_cell + '\t\tvar cell_visible: Variant = cell_visibility.get(cell)\n')
old_test = '\t\t\tif not region_visible(region, grown_visible):\n'
assert s.count(old_test) == 5
s = s.replace(old_test, '\t\t\tvar visible: bool = bool(cell_visible) if cell_visible != null else region_visible(region, grown_visible)\n\t\t\tif not visible:\n')
p.write_text(s, encoding='utf-8', newline='\n')
print('PASS: final bounded D8 candidate refinement; exact-base call-local cell visibility and unchanged all-visible submission helpers')
