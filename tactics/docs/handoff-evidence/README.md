# GitHub handoff checks

These checks concern the source handoff prepared on 20 October 2026. They are distinct from the [historical release-45 receipt](../release45-evidence/verification.json).

- [Fresh install](github-tactics-install.log): Node 24, locked dependencies, portable profile, new checkout without copied `node_modules`.
- [Fresh local D1 setup](github-tactics-db.log): all four committed migrations applied successfully.
- [Repeated D1 setup](github-tactics-db-repeat.log): migration ledger reports no migrations to apply.
- [Art reconstruction](art-repack.json): all 31 portable inputs matched their provenance hashes. Repacking all 30 character atlases and both environment derivatives in isolated scratch produced 32 exact SHA-256 matches. Runtime artwork remained untouched. The receipt records the tested Windows/Node/Sharp toolchain.

The [source import inventory](../source-import-r45.json) compares every baseline file with the original Sites Git blob. Only the project README and package command aliases differ among baseline files. New documentation, portable raw sources, setup configuration and CI are additions.

GitHub Actions records the full native, type, build, asset and database checks for the exact pushed commit, on Linux and Windows; Linux additionally runs the three HTTP scenarios in sequence. Read each run's actual terminal conclusion rather than treating this workflow definition as evidence that it passed.

Exact source or image bytes do not establish human usability, balance, animation quality, listening quality, or phone performance. The open acceptance work remains in [Testing and release](../handbook/TESTING-AND-RELEASE.md).
