from pathlib import Path
root = Path(r'C:\Users\sende\Projects\hex')
assert Path.cwd().resolve() == root.resolve()
def replace(path, old, new):
    file = root / path
    raw = file.read_bytes()
    assert raw.count(old.encode()) == 1, path
    file.write_bytes(raw.replace(old.encode(), new.encode()))
replace('scripts/package-hex.ps1',
        'Current changes reduce sparse snapshot validation and canonical hash work, with Water material and station-label fog corrections preserved. See docs/verification/hex-hash-20260923/HANDOFF.md in the checkout.',
        'Current changes also prepare whole-hex material views and regions once per draw, preserving exact pixels. Sparse snapshot validation and canonical hash improvements, Water material and station-label fog corrections are retained. Performance remains unaccepted. See docs/verification/hex-render-frame-20260923/HANDOFF.md in the checkout.')
replace('.agent/OVERHAUL-IMPLEMENTATION.md',
        '| D6 ACTIVE / test-only candidate | Prepare material views and regions once per draw | Prototype exact base-world frame preparation against the current view-plus-region path. Require exact values/order, whole-hex geometry, phases/ownership, direct-mutation visibility and independent outputs; measure alternating costs before runtime edits. Generic courts retain their existing path. |',
        '| D6 ACTIVE / integrating reviewed candidate | Prepare material views and regions once per draw | Prototype headless PASS976/21 cases and native PASS1968/448 pixel-identical frames, independently reviewed. Matched total-draw medians save8.314-9.989ms, but remain above budget and dense maxima regress. Production presenter integration now in progress; fresh Full, integrated captures and Windows journeys pending in docs/verification/hex-render-frame-20260923. Generic courts retain their existing path. |')
print('PASS: packaging handoff target and active D6 status updated')
