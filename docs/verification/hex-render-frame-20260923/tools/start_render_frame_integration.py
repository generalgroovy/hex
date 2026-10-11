from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, shutil, subprocess

root = Path(r"C:\Users\sende\Projects\hex")
out = root / "docs/verification/hex-render-frame-20260923"
assert Path.cwd().resolve() == root.resolve()
def git(*args):
    return subprocess.check_output(["git", *args], cwd=root, text=True).strip()
def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()
def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))
assert git("remote", "get-url", "origin") == "https://github.com/generalgroovy/hex.git"
assert not git("diff", "--cached", "--name-only")
assert not out.exists(), "Fresh integration evidence directory required"
old_audit = read(root / "docs/verification/hex-hash-20260923/preservation-audit.json")
for item in old_audit["protected_files"]:
    assert sha(root / item["path"]) == item["sha256"], item["path"]
out.mkdir()
(out / ".gdignore").write_text("")
changed_paths = ["src/presentation/hex_court_presenter.gd", "content/runtime/runtime_build_identity_v1.json", "tests/run_all.gd"]
originals = []
for name in changed_paths:
    source = root / name
    target = out / "baseline-source" / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    originals.append({"path": name, "sha256": sha(source), "preserved": target.relative_to(out).as_posix()})
protected = [i for i in old_audit["protected_files"] if i["path"] not in changed_paths]
package = read(root / "exports/hex-hash-20260923/receipt.json")
for path in [root / "exports/hex-hash-20260923/windows/hex.pck", Path(package["zip"])]:
    protected.append({"path": path.relative_to(root).as_posix(), "sha256": sha(path)})
baseline = {"utc": datetime.now(timezone.utc).isoformat(), "root": str(root), "origin": git("remote", "get-url", "origin"), "head": git("rev-parse", "HEAD"), "branch": git("branch", "--show-current"), "status": git("status", "--short").splitlines(), "staged": [], "runtime_identity": read(root / changed_paths[1]), "planned_modified_sources": originals, "protected": protected, "scope": "Pre-integration baseline only; D6 test-only headless/native candidate passes, production integration not yet applied or verified. No checkpoint promotion."}
(out / "baseline.json").write_text(json.dumps(baseline, indent=2) + "\n")
print("PASS: pre-integration baseline,", len(protected), "protected hashes and", len(originals), "source originals preserved")
