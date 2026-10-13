"""Independent read-only raw verification; archives an unapplied rejected prototype."""
from pathlib import Path
import hashlib, json, math, shutil, statistics

repo=Path('C:/Users/sende/Projects/hex')
base=repo/'.godot/iteration-20261013/prefix-key-shape'
dest=repo/'docs/iteration-20261013/prefix-key-shape'
assert not dest.exists(), 'Preserve any previous archive'
dest.mkdir()
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def source(p): return repo/p.removeprefix('res://')
def save(p,x):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(x,indent=2)+'\n',encoding='utf-8')
def copy(p,q):
    q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
    assert sha(p)==sha(q)
def stats(xs):
    xs=sorted(xs)
    return {'count':len(xs),'mean':statistics.mean(xs),'median':statistics.median(xs),'p95':xs[math.ceil(.95*len(xs))-1],'minimum':xs[0],'maximum':xs[-1]} if xs else {'count':0}
def compare(rows):
    return {'plain_us':stats([r['plain']['ground_us'] for r in rows]),'candidate_us':stats([r['candidate']['ground_us'] for r in rows]),'paired_delta_us':stats([r['candidate']['ground_us']-r['plain']['ground_us'] for r in rows]),'candidate_slower_pairs':sum(r['candidate']['ground_us']>r['plain']['ground_us'] for r in rows)}

docs={}; groups={}; warm={}; native=[]; image_count=0; measured=0; warm_count=0; controls=0
expected_receipts={'forward':'a2c5fa2417c02a024e01de8614b1fb5bbe6c91ecf5136dda867d13f1fc68f1d3','reverse':'44db42f62b24f75872deabfd2ec08086a6c59f42817f17e9adafc7d2162d1966'}
for mode in ['forward','reverse']:
    p=base/f'runs/probe-{mode}-a/receipt.json'
    assert sha(p)==expected_receipts[mode]
    d=json.loads(p.read_text(encoding='utf-8')); docs[mode]=d
    assert d['passed'] and not d['errors'] and d['checks']==9077 and d['prefix_contract_checks']==2334 and len(d['cases'])==22
    assert d['reverse_order']==(mode=='reverse')
    assert (base/f'runs/probe-{mode}-a.log.err').stat().st_size==0
    native.append({'mode':mode,'receipt_sha256':sha(p),'checks':d['checks'],'direct_prefix_checks':d['prefix_contract_checks'],'cases':len(d['cases']),'stderr_bytes':0})
    copy(p,dest/f'raw/{mode}.json')
    for ext in ['log','log.err']:copy(base/f'runs/probe-{mode}-a.{ext}',dest/f'raw/{mode}.{ext}')
    for c in d['cases']:
        assert c['exact_rgba_first_and_final'] and len(c['rows'])==(32 if c['timed'] else 1) and len(c['warmups'])==(4 if c['timed'] else 0)
        assert c['images']['plain']['sha256']==c['images']['candidate']['sha256']
        for role,image in c['images'].items():
            p=source(image['path']); assert sha(p)==image['sha256']
            copy(p,dest/f'images/{mode}/{p.name}');image_count+=1
        measured+=len(c['rows']) if c['timed'] else 0
        controls+=len(c['rows']) if not c['timed'] else 0
        warm_count+=len(c['warmups'])
        for row in c['warmups']+c['rows']:
            assert row['actual_order']==(['candidate','plain'] if ((row['index']%2==0)!=(mode=='reverse')) else ['plain','candidate'])
            assert all(row[side]['okay'] and row[side]['authority_unchanged'] and row[side]['ground_us']>=0 for side in ['plain','candidate'])
            assert row['cache_before']['plain']==row['cache_before']['candidate'] and row['cache_after']['plain']==row['cache_after']['candidate']
            assert row['new_meshes']==row['cache_after']['plain']['uploads']-row['cache_before']['plain']['uploads']>=0
            assert row['new_topologies']==row['cache_after']['plain']['topology_builds']-row['cache_before']['plain']['topology_builds']>=0
        if c['timed']:
            groups.setdefault(c['label'],[]).extend(dict(r,run=mode) for r in c['rows'])
            warm.setdefault(c['label'],[]).extend(dict(r,run=mode) for r in c['warmups'])
assert docs['forward']['source_hashes']==docs['reverse']['source_hashes']
assert docs['forward']['paid_sequences']==docs['reverse']['paid_sequences']
assert image_count==88 and measured==768 and warm_count==96 and controls==20
for left,right in zip(docs['forward']['cases'],docs['reverse']['cases']):
    assert all(left[k]==right[k] for k in ['label','timed','coverage','world_tick','render_tick','authority_hash','matter_paid','zoom','jitter','focus'])
for path,expected in docs['forward']['source_hashes'].items():
    p=source(path);assert sha(p)==expected,f'Source drift: {p}'
    copy(p,dest/'sources'/path.removeprefix('res://'))
for name in ['manifest.json','README.md']:copy(base/name,dest/'prepared'/name)
for name in ['parse-a.log','parse-a.log.err']:copy(base/name,dest/'raw'/name)
copy(base/'independent-cost-review.json',dest/'independent-technical-review.json')
copy(repo/'.godot/iteration-20261013/run-prefix-key-shape.ps1',dest/'helpers/run-prefix-key-shape.ps1')
copy(Path(__file__),dest/'helpers/analyze-and-archive.py')

cases={}
for name,rows in groups.items():
    c=next(c for c in docs['forward']['cases'] if c['label']==name)
    entry=compare(rows)
    entry['mean_change_percent']=(entry['candidate_us']['mean']/entry['plain_us']['mean']-1)*100
    entry['by_order']={first+'_first':compare([r for r in rows if r['actual_order'][0]==first]) for first in ['plain','candidate']}
    entry['by_process']={mode:compare([r for r in rows if r['run']==mode]) for mode in docs}
    entry['warmups']={'all':compare(warm[name]),'by_process':{mode:dict(compare([r for r in warm[name] if r['run']==mode]),new_meshes=sum(r['new_meshes'] for r in warm[name] if r['run']==mode),new_topologies=sum(r['new_topologies'] for r in warm[name] if r['run']==mode)) for mode in docs}}
    entry['coverage']=c['coverage'];entry['world_tick']=c['world_tick'];entry['matter_paid']=c['matter_paid']
    entry['measured_new_meshes']=sum(r['new_meshes'] for r in rows)
    entry['measured_new_topologies']=sum(r['new_topologies'] for r in rows)
    entry['measured_fallbacks']=sum(r['cache_after']['plain']['fallbacks']-r['cache_before']['plain']['fallbacks'] for r in rows)
    entry['edge_mask_hits']=sum(r['cache_after']['plain']['edge_mask_hits']-r['cache_before']['plain']['edge_mask_hits'] for r in rows)
    entry['mesh_hits']=sum(r['cache_after']['plain']['hits']-r['cache_before']['plain']['hits'] for r in rows)
    assert entry['measured_new_meshes']==entry['measured_new_topologies']==entry['measured_fallbacks']==0
    cases[name]=entry
review={'schema':'hex.ground.prefix-key-shape-review.v1','decision':'WITHDRAW_UNAPPLIED_CANDIDATE','canonical_changed':False,'native':native,'source_pins_equal_and_rechecked':True,'source_pin_count':len(docs['forward']['source_hashes']),'verified_pngs':image_count,'measured_pairs':measured,'warmup_pairs':warm_count,'pixel_control_pairs':controls,'actual_order_checks':True,'exact_authority_and_coverage_across_processes':True,'retained_counters_equal':True,'all_measured_mesh_and_topology_builds_zero':True,'cases':cases,'reason':'Exact output and authority passed, but Mantle mean benefit reverses in the second process. Reduced Mantle paired median is positive; legacy dense normal also regresses in both pooled order strata. No repeatable benefit justifies promotion. Preserve current production key and both full raw runs, including outliers.','scope':['Whole draw_ground_in_view CPU submission only, same outer timers, no nested attribution instrumentation.','Real finite paid snapshots and separate declared direct prefix contracts; no injected paid phase or resource grant.','Warmups retained with actual build deltas. First/final caches persist across cases and are not uniformly cold.','No application boot, rendering GPU/present, foreground FPS, physical input or human readability qualification.','Source guards preserve exact one-block prototype; no production patch is proposed.']}
save(dest/'review.json',review)
print('REVIEW',sha(dest/'review.json'),'PINS',len(docs['forward']['source_hashes']),'PNGS',image_count)
for name in ['mantle_active_normal','mantle_active_reduced','fire_dense_normal']:
    c=cases[name];print(name,c['paired_delta_us'],{k:v['paired_delta_us']['mean'] for k,v in c['by_process'].items()})
