"""Refresh source timing metadata without reauthoring any pixel frames.

Run after an explicitly authorized simulation timing edit, then export_pack.py
and validate_pack.py. Never bypass the runtime exact-timing checks.
"""
import json
from author import ROOT, read_authority, read_deposit_lifetimes


def main():
    path = ROOT / "source/authority_snapshot.json"
    snapshot = json.loads(path.read_text(encoding="utf-8"))
    recipes, sources = read_authority()
    snapshot.update(
        source_checkpoint="local-frostway-m2a-20260909-uncommitted",
        source_files=sources,
        recipes=recipes,
        deposit_lifetime_ticks=read_deposit_lifetimes(),
        source_not_modified=False,
        candidate_revision="M2a Frostway replaces Ice mirror cover with a finite movement/projectile lane and flat tileable cyan ice; other C1 pixels and timings retained",
    )
    path.write_text(json.dumps(snapshot, indent=2) + "\n", encoding="utf-8")
    print("Refreshed 8 deposit and 36 reaction timing records; no pixel frame writes.")


if __name__ == "__main__":
    main()
