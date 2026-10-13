"""Prepare a production-seam route gate from the exact approved worker fixture."""
from pathlib import Path
import hashlib
import json
import difflib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
IGNORED = ROOT / ".godot/iteration-20261013"
BEFORE = HERE / "production-route-before"


def sha(data): return hashlib.sha256(data).hexdigest()


def save_new(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if path.read_bytes() != data: raise ValueError(f"Refusing different existing bytes: {path}")
    else: path.write_bytes(data)


def once(value, old, new):
    if value.count(old) != 1: raise ValueError(f"Expected one occurrence: {old!r}")
    return value.replace(old, new)


def text(data): return data.decode("utf-8").replace("\r\n", "\n")


def encode(value, original):
    return (value.replace("\n", "\r\n") if b"\r\n" in original else value).encode("utf-8")


old_gd = IGNORED / "compare-bootstrap-terrain-worker-walk.gd"
old_ps = IGNORED / "run-bootstrap-terrain-worker-walk.ps1"
gd_before, ps_before = old_gd.read_bytes(), old_ps.read_bytes()
if sha(gd_before) != "82a0f15cdf60adb730835062e91e47b78a312d6c1d00456865db26beda849023": raise ValueError("Original route helper changed")
if sha(ps_before) != "1575c3796fa912175d9af3173f57ddcab0120919c29dbe61ecf0297229df8767": raise ValueError("Original route wrapper changed")
save_new(BEFORE / old_gd.name, gd_before)
save_new(BEFORE / old_ps.name, ps_before)

gd = text(gd_before).replace("bootstrap-terrain-worker-walk", "bootstrap-terrain-production-walk")
gd = gd.replace('res://.godot/iteration-20261013/terrain-worker/worker_terrain_stream.gd', 'res://src/presentation/wellspring_async_terrain_stream.gd')
gd = gd.replace('res://.godot/iteration-20261013/terrain-worker/hash_job.gd', 'res://src/presentation/terrain_hash_job.gd')
gd = gd.replace('0369b3cef8655c16a075396faa617e3fb06818543d92eaf520fd7edb0a4b7548', '2bf2835dc76eaeb0aa4d2cb5964ec15169c430391f4cd58c16c4ed007caa526b')
gd = gd.replace('6bcc7df8106bbfefca56bc674a257415dd9d0254c917e7f9db0e1b716eb8179e', 'fd3c440709d9ba61575830b25daf0d9013d708005553f6da5d06ea2a7e76d5b2')
gd = once(gd, 'const STEP_DELTA :=', 'const KIT_SHA := "d70a5d54fc0e14f566f51e8104e261409c5b19ca903a04745f5c24669b4d85be"\nconst STEP_DELTA :=')
gd = once(gd, '\t"res://.godot/iteration-20261013/T8-before/wellspring_terrain_stream.gd",', '\t"res://.godot/iteration-20261013/run-bootstrap-terrain-production-walk.ps1",')
gd = once(gd, '\tvar injection_ok := false', '\tvar injection_ok := false\n\tvar selected_owner: WeakRef')
start = gd.index('\t\tvar chosen: RefCounted = Before.new() if variant == "before" else After.new()')
end = gd.index('\n\tfunc _process(real_delta:', start)
gd = gd[:start] + '''		if original.get_script() != After or String(original.status().get("validation_backend", "")) != "worker_sha256_v1":
			harness._fail("Inherited production kit did not select the exact canonical async backend.")
			return
		var chosen: RefCounted = original
		if variant == "before":
			# Only the control arm replaces the known idle production owner.
			chosen = Before.new()
			var manifest: Resource = load(After.MANIFEST)
			if manifest == null or not chosen.configure(manifest.get("descriptor"), kit.bake_signature, campus_layout.canvas_size):
				harness._fail("Concrete original control configuration failed before injection.")
				return
			original.finish_shutdown()
			if not bool(original.closed) or not original.pending.is_empty():
				harness._fail("Unused production owner did not close cleanly before control injection.")
				return
			kit.terrain_stream = chosen
			kit.ground_chunks = chosen.textures
			kit.ground_chunk_order = chosen.order
			kit._sync_terrain_stats()
		# After keeps the actual inherited kit owner and its configuration/aliases.
		# No replacement, configure, shutdown or cache synchronization runs there.
		selected_owner = weakref(chosen)
		injection = {"when": "after inherited _ready, before first inherited _process/request", "world_tick": world.tick,
			"selection": "inherited production kit owner" if variant == "after" else "idle original-stream control",
			"production_owner_retained": is_same(original, chosen), "original_closed": original.closed,
			"original_pending": original.pending.size(), "chosen_status": chosen.status(),
			"bake_signature": kit.bake_signature, "texture_alias": is_same(kit.ground_chunks, chosen.textures),
			"order_alias": is_same(kit.ground_chunk_order, chosen.order), "cache_bytes": kit.ground_cache_bytes,
			"builds": kit.ground_chunk_builds, "hits": kit.ground_chunk_hits}
		injection_ok = bool(injection.texture_alias) and bool(injection.order_alias) and kit.ground_cache_bytes == 0 and kit.ground_chunk_builds == 0
		if variant == "after": injection_ok = injection_ok and bool(injection.production_owner_retained) and not bool(original.closed)
		if not injection_ok: harness._fail("Kit selection or aliases do not match the declared idle owner.")
''' + gd[end:]
gd = once(gd, '\t\tif not injection_ok: return\n\t\tif first_parent_process:',
    '\t\tif not injection_ok: return\n\t\tif selected_owner == null or not is_same(campus_renderer.illustrated_kit.terrain_stream, selected_owner.get_ref()):\n\t\t\tharness._fail("Actual route replaced its declared terrain owner.")\n\t\t\treturn\n\t\tif first_parent_process:')
gd = once(gd, 'not bool(terrain.get("worker_prototype", false))', 'String(terrain.get("validation_backend", "")) != "worker_sha256_v1"')
gd = once(gd, 'not bool(terrain.get("worker_prototype",false))', 'String(terrain.get("validation_backend","")) != "worker_sha256_v1"')
gd = once(gd,
    'if not _check(FileAccess.get_sha256("res://.godot/iteration-20261013/T8-before/wellspring_terrain_stream.gd")==BEFORE_SHA,"Worker extends the exact same original stream bytes."): return',
    'if not _check(FileAccess.get_sha256("res://src/presentation/wellspring_terrain_stream.gd")==BEFORE_SHA,"Production async extends the exact unchanged original stream bytes."): return\n\tif not _check(FileAccess.get_sha256("res://src/presentation/wellspring_illustrated_kit.gd")==KIT_SHA,"Actual kit constructor matches the reviewed production selection."): return')
gd = once(gd, 'Worker implementation and byte owner match the reviewed checkpoint.', 'Promoted worker implementation and byte owner match the reviewed capture-epoch checkpoint.')
gd = once(gd,
    'Same current Bootstrap/protocol/kit; only concrete preserved original versus ignored worker-validation stream differs. The worker prototype is not the production stream; actual task ownership and joins are recorded in terrain rows.',
    'Same current Bootstrap/protocol/kit. After retains the exact async stream created and configured by inherited production setup, without fixture replacement or reconfiguration. Before alone replaces the unused idle owner with the preserved original synchronous stream. Every observed callback retains the selected owner. Actual task ownership and joins are recorded in terrain rows.')

ps = text(ps_before).replace("bootstrap-terrain-worker-walk", "bootstrap-terrain-production-walk")
ps = once(ps, "param([string]$RunSuffix='a')", "param([ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$')][string]$RunSuffix='a')")
ps = once(ps, "$hexResults=@()\ntry {", "$hexResults=@()\n$hexSummaryPath=Join-Path $PWD \".godot/iteration-20261013/bootstrap-terrain-production-walk-summary-$RunSuffix.json\"\nif (Test-Path -LiteralPath $hexSummaryPath) { throw \"Fresh summary required: $hexSummaryPath\" }\ntry {")
ps = once(ps,
    '            if (Test-Path -LiteralPath $hexRelative) { throw "Fresh run required: $hexRelative" }\n            $env:APPDATA=Join-Path $PWD ".godot/iteration-20261013/bootstrap-terrain-production-walk-roaming-$hexRun"',
    '            $hexRoaming=Join-Path $PWD ".godot/iteration-20261013/bootstrap-terrain-production-walk-roaming-$hexRun"\n            foreach ($hexFresh in @($hexRelative, "$hexRelative.log", "$hexRelative.log.err", $hexRoaming)) {\n                if (Test-Path -LiteralPath $hexFresh) { throw "Fresh run required: $hexFresh" }\n            }\n            $env:APPDATA=$hexRoaming')
ps = once(ps,
    '            foreach ($hexProperty in $hexReceipt.source_hashes.PSObject.Properties) {',
    '            if ($hexArm -eq \'after\' -and (-not $hexReceipt.injection.production_owner_retained -or $hexReceipt.injection.original_closed -or $hexReceipt.injection.selection -cne \'inherited production kit owner\')) { throw "After arm did not retain the actual production owner: $hexRun" }\n            foreach ($hexProperty in $hexReceipt.source_hashes.PSObject.Properties) {')
old_summary = next(line for line in ps.splitlines() if "hex.bootstrap-terrain-production-walk-root.v1" in line)
new_summary = '''    $hexSummaryText=([ordered]@{schema='hex.bootstrap-terrain-production-walk-root.v1';passed=$true;cases=$hexResults;scope='Actual production kit owner retained in after; before uses the exact idle original-stream control. Explicit synthetic application focus and tick-scheduled real InputRouter actions. Not human, foreground, FPS or physical-input latency acceptance.'} | ConvertTo-Json -Depth 8) + [Environment]::NewLine
    $hexSummaryBytes=[Text.UTF8Encoding]::new($false).GetBytes($hexSummaryText)
    $hexSummaryFile=[IO.File]::Open($hexSummaryPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
    try { $hexSummaryFile.Write($hexSummaryBytes,0,$hexSummaryBytes.Length); $hexSummaryFile.Flush($true) } finally { $hexSummaryFile.Dispose() }
    if ([IO.File]::ReadAllText($hexSummaryPath) -cne $hexSummaryText) { throw 'Production route summary read-back differs.' }'''
ps = once(ps, old_summary, new_summary)

outputs = [(old_gd, gd_before, IGNORED / "compare-bootstrap-terrain-production-walk.gd", encode(gd, gd_before)),
           (old_ps, ps_before, IGNORED / "run-bootstrap-terrain-production-walk.ps1", encode(ps, ps_before))]
records = []
for old, before, new, after in outputs:
    save_new(new, after)
    delta = ''.join(difflib.unified_diff(text(before).splitlines(keepends=True),text(after).splitlines(keepends=True),fromfile=old.name,tofile=new.name))
    save_new(HERE / (new.name + '.diff'), delta.encode('utf-8'))
    records.append({'predecessor':str(old.relative_to(ROOT)).replace('\\','/'),'predecessor_sha256':sha(before),
        'path':str(new.relative_to(ROOT)).replace('\\','/'),'sha256':sha(after),'bytes':len(after)})
manifest={'schema':'hex.terrain-production-route-stage.v1','status':'UNEXECUTED','files':records,
    'scope':'Only the before control replaces the idle production stream. The after arm retains and observes the exact inherited kit stream and aliases. Route, commands, focus override, authority, snapshot, close and profile guards remain inherited from the approved fixture. Output names are separate and all outputs/roaming/summary must be fresh.',
    'canonical_writes':False,'engines_run':False}
save_new(HERE / 'production-route-manifest.json',(json.dumps(manifest,indent=2)+'\n').encode('utf-8'))
print(json.dumps(manifest))
