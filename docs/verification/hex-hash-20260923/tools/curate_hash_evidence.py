"""Preserve D2 receipts/logs and verify the new package and untouched fallback."""
from pathlib import Path
import hashlib, json, shutil, subprocess, zipfile

ROOT = Path(r"C:\Users\sende\Projects\hex")
OUT = ROOT / "docs/verification/hex-hash-20260923"
PRIOR = ROOT / "docs/verification/hex-responsive-20260923"
assert Path.cwd().resolve() == ROOT.resolve()

def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

records = []
def preserve(source, target):
    if source.is_dir():
        for child in sorted(source.rglob("*")):
            if child.is_file() and "isolated-roaming" not in child.parts:
                preserve(child, target / child.relative_to(source))
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    assert digest(source) == digest(target)
    records.append({"source": source.relative_to(ROOT).as_posix(),
                    "preserved": target.relative_to(OUT).as_posix(), "sha256": digest(target)})

for path in sorted(OUT.glob("*.json")):
    data = read(path)
    if data.get("tier") and data.get("isolation", {}).get("appdata_path"):
        run = ROOT / data["isolation"]["appdata_path"]
        preserve(run.parent, OUT / "gates" / run.parent.name)

for pattern in ["hex-probe-hash-*", "movement-cast-hash-*", "movement-advanced-hash-*",
                "water-hash-*", "station-labels-hash-*", "terrain-hash-*", "hex-network-hash-*",
                "hex-hash-candidate-hash-*.json", "hex-snapshot-stages-hash-*.json", "hex-snapshot-lifetime-hash-*.json",
                "hex-wire-decode-candidate-hash-*.json", "hex-draw-components-hash-*",
                "hex-render-frame-candidate-hash-*.json", "hex-render-frame-native-hash-*",
                "unified-wellspring-render-profile-hash-*.json"]:
    for source in sorted((ROOT / ".godot").glob(pattern)):
        preserve(source, OUT / "runs" / source.name)
for source in sorted((ROOT / "docs/verification/hex-acceptance-20260921").glob("hash-*")):
    preserve(source, OUT / "loom" / source.name)
for source in sorted((ROOT / "docs/evidence/hex-integration-20260920").glob("network-hash-*.json")):
    preserve(source, OUT / "network" / source.name)

package = ROOT / "exports/hex-hash-20260923"
if package.exists():
    meta = read(package / "receipt.json")
    preserve(package / "receipt.json", OUT / "package/receipt.json")
    preserve(package / "logs", OUT / "package/logs")
    for name in ["BUILD-STATE.json", "SOURCE-IDENTITY.json", "SHA256SUMS.txt", "README-FIRST.txt", "PLAY-HEX.cmd"]:
        preserve(package / "windows" / name, OUT / "package" / name)
    assert digest(package / "windows/hex.pck") == meta["pack_sha256"]
    assert digest(Path(meta["zip"])) == meta["zip_sha256"]
    zipped = []
    with zipfile.ZipFile(meta["zip"]) as archive:
        for info in archive.infolist():
            if info.is_dir(): continue
            name = Path(info.filename).name
            sha = hashlib.sha256(archive.read(info)).hexdigest()
            assert sha == digest(package / "windows" / name)
            zipped.append({"name": name, "sha256": sha})
    assert len(zipped) == len([p for p in (package / "windows").iterdir() if p.is_file()])
    (OUT / "package-audit.json").write_text(json.dumps({"status":"passed", "build_id":meta["build_id"],
        "pck_sha256":meta["pack_sha256"], "zip_sha256":meta["zip_sha256"], "entries":zipped}, indent=2)+"\n")

protected = read(PRIOR / "baseline.json")["protected"]
protected += [item for item in read(PRIOR / "freeze.json")["files"]
              if item["path"] != "content/runtime/runtime_build_identity_v1.json"]
if (OUT / "freeze.json").exists():
    protected += read(OUT / "freeze.json")["files"]
for item in protected:
    assert digest(ROOT / item["path"]) == item["sha256"], item["path"]
old_package = read(ROOT / "exports/hex-responsive-20260923/receipt.json")
assert digest(ROOT / "exports/hex-responsive-20260923/windows/hex.pck") == old_package["pack_sha256"]
assert digest(Path(old_package["zip"])) == old_package["zip_sha256"]
assert not subprocess.check_output(["git","diff","--cached","--name-only"],cwd=ROOT,text=True).strip()
(OUT / "preservation-audit.json").write_text(json.dumps({"status":"passed", "protected_files":protected,
    "responsive_fallback_pck_sha256":old_package["pack_sha256"], "responsive_fallback_zip_sha256":old_package["zip_sha256"],
    "staged_changes":False},indent=2)+"\n")
for item in records:
    assert digest(OUT / item["preserved"]) == item["sha256"]
(OUT / "evidence-map.json").write_text(json.dumps({"scope":"D2 runtime gate and D3-D6 diagnostic receipts with referenced logs/images; personal profiles never copied; isolated profiles retained at original run locations", "files":records},indent=2)+"\n")
print(f"PASS: {len(records)} evidence files, {len(protected)} source/protected hashes and unchanged responsive fallback")
