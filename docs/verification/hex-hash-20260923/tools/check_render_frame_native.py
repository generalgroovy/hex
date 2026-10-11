from pathlib import Path
import hashlib, json

root = Path(r"C:\Users\sende\Projects\hex")
assert Path.cwd().resolve() == root.resolve()
production = root / "src/presentation/hex_court_presenter.gd"
candidate = root / "tests/support/hex_render_frame_native_presenter.gd"
old = production.read_text(encoding="utf-8-sig")
new = candidate.read_text(encoding="utf-8-sig")
marker = '\tif regions.is_empty() and _has_active_material(views):'
old_body = old[old.index("func draw_ground("):old.index("# Repaint only the visible physical cover")].rstrip()
new_body = new[new.index("func _candidate_ground("):].rstrip()
old_tail = old_body[old_body.index(marker):]
new_tail = new_body[new_body.index(marker):]
assert old_tail == new_tail, "Candidate changed post-preparation production drawing"
report = {
    "status": "passed", "scope": "Static source comparison only; no engine or pixel claim",
    "preserved_tail_lines": len(old_tail.splitlines()),
    "tail_sha256_lf": hashlib.sha256(old_tail.encode()).hexdigest(),
    "source_sha256": {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in [production, candidate]},
    "baseline": "Actual super.draw_ground called by disabled candidate arm",
    "candidate": "Exact post-preparation draw/cover body; replaces only view/region preparation, retaining exact-base guard and generic fallback",
}
output = root / "docs/verification/hex-hash-20260923/render-frame-native-static.json"
output.write_text(json.dumps(report, indent=2) + "\n")
print("PASS: exact unchanged post-preparation draw body", report["preserved_tail_lines"], "lines")
