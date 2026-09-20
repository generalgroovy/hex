# Unified sight evidence

Status: verified local human-playtest candidate p54-6dc4e976f925, September 20, 2026.

Final runtime identity: source-identity.json. Current checkpoint:
../../HEX-VISION-CHECKPOINT.md. Integration handoff: ../../../.agent/HEX-RESUME.md.

Final gates: receipts/focused-v4.json (7/4780), receipts/focused-v5.json
(2/3301), receipts/full-v2.json (157/775578), package/receipt.json,
receipts/package-audit.json. All final engine gates passed with zero stderr.
Earlier failed attempts are preserved and explained in the checkpoint.

Before: captures/before-v1 is a fresh native run of the preserved old Full-mode
PCK. Final after: captures/after-v2. Each has twelve native frames and its own
capture-receipt.json. receipts/comparison.json verifies matching authority,
helper, map, fixture, normal/reduced visibility and the exact final image hashes.
captures/after-v1 is the earlier reviewed capture, byte-identical to after-v2.
receipts/review.md records bounded independent review and native visual findings.

evidence-map.json maps original receipt-referenced paths to preserved copies and
verifies SHA256 for every copied file. Logs and their stderr siblings are retained
under their original relative .godot or exports paths inside this bundle. User
profiles and engine caches are excluded. user-launch.json records launch only;
the ongoing interactive user's log is not represented as a frozen validation run.

No fresh performance/network benchmark, physical two-PC, installer/updater or
human acceptance claim. Presentation concealment does not redact snapshots.
