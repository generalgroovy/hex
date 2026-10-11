# Development observations

The final receipts are `asset-tests.txt`, `geometry-tests.txt`, `browser-checks.json` and `verification.json`. They are offline checks only.

The first image-generator exploration was rejected for taxonomy, geometry and Steam-opacity errors; its raw image is quarantined, not silently promoted to a candidate.

Direct file navigation was attempted and blocked by sandbox administrator policy. Tests respect that restriction and feed the self-contained page through Playwright content injection. That is not a successful `file://` launch or a Godot run.

The first asset-test run passed its assertions but reported unclosed-image warnings. The metadata-only image reads were changed to load/close their files; the clean final receipt replaces that run for current status. The warning receipt remains as `asset-tests-first-run.txt`.

The first manifest build assumed flat input identity/HEAD keys; the supplied manifest actually uses `reported_runtime_identity` and nested `git.head`. The packer was corrected to those exact fields before generating and validating the delivered manifest.

Offline rendering was tightened to union same-cell/same-material base opacity while retaining all records, motifs and legacy owner/phase/expiry seams. This prevents repeated Steam base veils from becoming opaque. New tests exercise 32 coincident Steam records, active danger beside fading residue and explicit owner-key handling. No simulation or live repository file was changed.
