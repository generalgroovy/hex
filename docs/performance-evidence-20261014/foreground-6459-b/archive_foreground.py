"""Independent raw-receipt review and exact-byte archive. Does not run the game."""
from pathlib import Path
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import math
import re
import shutil

ROOT = Path('C:/Users/sende/Projects/hex')
RUN = ROOT / '.godot/iteration-20261014/foreground-6459-desktop-b'
OUT = ROOT / 'docs/performance-evidence-20261014/foreground-6459-b'
BUILD = 'p61-64590c45c7a5'
SOURCE = '64590c45c7a5aa4b1b6fc492a3a11b32a4a3429d49fa792a729cabdec838c212'
errors = []
checks = 0

def check(value, label):
    global checks
    checks += 1
    if not value:
        errors.append(label)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def close(a, b):
    return isinstance(a, (float, int)) and isinstance(b, (float, int)) and math.isclose(a, b, rel_tol=1e-10, abs_tol=1e-7)

def stats(values):
    ordered = sorted(values)
    if not ordered:
        return {'count': 0}
    return {'count': len(values), 'mean': sum(values)/len(values), 'p50': ordered[math.ceil(len(values)*.5)-1],
            'p95': ordered[math.ceil(len(values)*.95)-1], 'p99': ordered[math.ceil(len(values)*.99)-1], 'max': max(values)}

def verify_stats(values, reported, label):
    check(all(type(v) in (int, float) and math.isfinite(v) and v >= 0 for v in values), label+' finite nonnegative')
    calculated = stats(values)
    for key, value in calculated.items():
        check(close(value, reported[key]), label+' '+key)
    for key, boundary in [('over_20ms',20), ('over_33_3ms',33.3), ('over_50ms',50), ('over_100ms',100)]:
        if 'threshold_counts' in reported:
            check(sum(v > boundary for v in values) == reported['threshold_counts'][key], label+' '+key)
    return calculated

def utc_msec(value):
    return datetime.fromisoformat(value.replace('Z','+00:00')).timestamp()*1000

m = json.loads((RUN/'metrics.json').read_text())
s = json.loads((RUN/'summary.json').read_text())
identity = json.loads((RUN/'runtime-identity.input.json').read_text())
log = (RUN/'engine.log').read_text()
check(s['status']=='measured' and s['validation_errors']==[] and s['appdata_restored'] is True, 'wrapper admission')
projected=json.loads(json.dumps(m))
for name in ('observed_source_before','observed_source_after'): projected[name].pop('files')
for result in projected['results']: result.pop('raw')
check(m['complete'] is True and s['benchmark']==projected, 'complete raw metrics equal wrapper projection excluding declared raw arrays/source rows')
check(s['metrics_sha256']==sha(RUN/'metrics.json'), 'wrapper raw metrics hash')
check((RUN/'engine.log.err').stat().st_size==0, 'empty stderr')
check(not re.search(r'(?m)^(?:ERROR|SCRIPT ERROR|FAIL|Parse Error)', log), 'no native error marker')
check(log.count('HEX_GAMEPLAY_PROFILE_COMPLETE ')==1 and str(RUN/'metrics.json').replace('/','\\') in log, 'one exact completion marker')
for value in [identity, m['manifest'], s['runtime_identity_before'], s['runtime_identity_after']]:
    check(value['build_id']==BUILD and value['runtime_source_sha256']==SOURCE and value['record_count']==3446, 'runtime identity 6459')
check(s['runtime_identity_before']==s['runtime_identity_after'], 'runtime identity unchanged')
check(s['input_hashes_before']==s['input_hashes_after'], 'seven wrapper source inputs unchanged')
for path, digest in s['input_hashes_before'].items():
    check(sha(Path(path))==digest, 'current wrapper input '+path)
before=m['observed_source_before']; after=m['observed_source_after']
check(m['observed_source_unchanged'] and before['ok'] and after['ok'] and before['unreadable_paths']==after['unreadable_paths']==[], 'source read admission')
check(before['files']==after['files'] and before['sha256']==after['sha256'] and before['count']==after['count']==len(before['files'])==326, '326 raw source pins unchanged')
check(len({row['path'] for row in before['files']})==326, 'unique source paths')
for row in before['files']:
    check(sha(ROOT/row['path'].removeprefix('res://'))==row['sha256'], 'current observed input '+row['path'])
check(m['tick_rate']==120 and m['observer_mode']=='full' and m['all_fixed_steps']['requested'] and not m['viewport_render_timing']['requested'], 'explicit full CPU observer')
check(m['frame_limit']==60 and m['window_size']==m['window_size_end']==[1280,720] and m['profiles']==['low'] and m['campus_mode']=='immediate_reference', 'declared fixed configuration')
check(not m['observation_limits']['overflow'], 'no observation overflow')
arm=m['foreground_arming']
check(arm['requested'] and arm['armed'] and arm['manual_confirmation_received'] and arm['manual_confirmation_kind']=='start_button_pressed' and arm['manual_confirmation_phase']=='setup', 'actual manual start')
check(arm['manual_confirmation_utc_msec']<arm['armed_utc_msec']<=arm['game_instantiation_started_utc_msec'], 'arming precedes game instantiation')
check(arm['stable_focus_elapsed_ms']>=1000 and arm['stable_focus_samples']>=2 and arm['wait_elapsed_ms']<arm['deadline_ms'], 'stable bounded manual arm')
check(arm['post_arm_focus']['samples']==720 and arm['post_arm_focus']['unfocused_samples']==arm['post_arm_focus']['focus_exit_events']==0, 'all720 post-arm engine focus samples')
check(s['foreground_arming_assessment']['qualified_samples'] and s['foreground_arming_assessment']['errors']==[], 'wrapper foreground admission')
windows=s['window_observations']
post=[w for w in windows if utc_msec(w['observed_utc'])>=arm['armed_utc_msec']]
available=[w for w in post if w['main_window_available']]
check(len(windows)==231 and len(post)==156 and len(available)==154, 'raw Windows partition counts')
for w in available:
    check(w['foreground_process_matches'] is True and w['foreground_window_matches'] is True and w['main_window_process_matches'] is True and w['main_window_visible'] is True and w['main_window_minimized'] is False and [w['client_width'],w['client_height']]==[1280,720] and w['error'] is None, 'qualified post-arm Windows row')
check(all(w['main_window_available'] for w in post[:154]) and not any(w['main_window_available'] for w in post[154:]), 'only terminal unavailable boundary')
gap=max(available[i]['elapsed_ms']-available[i-1]['elapsed_ms'] for i in range(1,len(available)))
check(gap==560 and gap<=2000, 'maximum observed focus gap')
stages=m['all_fixed_steps']['stages']
check(len(stages)==len(set(stages))==9, 'fixed nine stage inventory')
expected=['startup_arrival','garden_middle_arrival','garden_middle','paid_fire_bolt_sustained','paid_all_six_mantle_sustained']
check([r['label'] for r in m['results']]==expected, 'exact ordered case inventory')
case_reviews=[]
for r in m['results']:
    label=r['label']; raw=r['raw']; groups=raw['all_fixed_steps']; n=len(groups)
    check(r['ready'] and r['run_id']==m['run_id']==s['run_id'] and r['garden_arrival_error']=='', label+' ready identity')
    check(r['focus_sample_count']==n and r['unfocused_frames']==r['viewport_mismatch_frames']==0 and r['window_focus_before'] and r['window_focus_end'], label+' focus')
    check(r['window_size']==r['window_size_before']==[1280,720] and not r['workload']['resource_refill'], label+' configuration')
    check(n==len(raw['process_elapsed_ms'])==len(raw['frame_start_us'])==len(raw['observer_overhead_elapsed_ms']), label+' process alignment')
    check(len(raw['frame_interval_ms'])==n-1==len(raw['frame_activity']), label+' interval alignment')
    for i, delta in enumerate(raw['frame_interval_ms']):
        check(close(delta,(raw['frame_start_us'][i+1]-raw['frame_start_us'][i])/1000),label+' raw interval')
    for key, values in raw.items():
        if key.endswith('_ms') and isinstance(values,list) and key in r:
            verify_stats(values,r[key],label+' '+key)
    for raw_key,summary_key in [('garden_stages_us','garden_stage_stats_ms'),('main_draw_stages_us','main_draw_stage_stats_ms'),('main_court_preparation_us','main_court_preparation_stats_ms')]:
        for key, reported in r[summary_key].items():
            verify_stats([row.get(key,0)/1000 for row in raw[raw_key]],reported,label+' '+summary_key+'/'+key)
    elapsed={k:0 for k in stages}; executions={k:0 for k in stages}; total=0; previous=None
    distribution=Counter(); residual=[]
    for index,g in enumerate(groups):
        a=g['after']; b=g['before']; d=g['delta']
        head_us=g['process_started_us']-raw['frame_start_us'][index]
        check(g['process_index']==index and close(g['process_elapsed_us']/1000,raw['process_elapsed_ms'][index]) and 0<=head_us<=raw['observer_overhead_elapsed_ms'][index]*1000+1e-7,label+' group alignment with separately timed observer head')
        if index>0: check(g['process_started_us']>=groups[index-1]['process_started_us']+groups[index-1]['process_elapsed_us'],label+' nonoverlapping process intervals')
        for snapshot in (a,b):
            check(snapshot['schema']=='hex.sim.completed-stages.v1' and snapshot['enabled'] and snapshot['profile_enabled'] and snapshot['hex_mode'],label+' enabled concrete snapshot')
            check(isinstance(snapshot['world_id'],str) and re.fullmatch(r'-?(0|[1-9][0-9]*)',snapshot['world_id']) is not None,label+' opaque string world identity')
            check(snapshot['attempted_steps']==snapshot['completed_steps']+snapshot['failed_steps'] and snapshot['failed_steps']==0,label+' successful-only snapshot')
            check(set(snapshot['elapsed_us'])==set(snapshot['executions'])==set(stages),label+' fixed lane keys')
            for k in stages:
                check(type(snapshot['elapsed_us'][k]) is int and snapshot['elapsed_us'][k]>=0 and snapshot['executions'][k]==snapshot['completed_steps'],label+' absolute stage count')
        check(all(a[k]==b[k] for k in ('world_id','epoch','hex_mode')),label+' stable world generation')
        if previous is not None: check(previous==b,label+' contiguous before/after snapshots')
        previous=a
        count=a['tick']-b['tick']
        check(d['valid'] and d['error']=='' and count==d['completed_steps']==a['completed_steps']-b['completed_steps'] and 0<=count<=8,label+' exact step delta')
        for k in stages:
            check(d['elapsed_us'][k]==a['elapsed_us'][k]-b['elapsed_us'][k]>=0 and d['executions'][k]==a['executions'][k]-b['executions'][k]==count,label+' raw stage delta')
            elapsed[k]+=d['elapsed_us'][k];executions[k]+=d['executions'][k]
        stage_total=sum(d['elapsed_us'].values())
        check(stage_total<=g['process_elapsed_us'],label+' stages enclosed in main process')
        if count==0: check(stage_total==0,label+' zero-step zero stage duration')
        residual.append((g['process_elapsed_us']-stage_total)/1000)
        total+=count;distribution[count]+=1
    t=r['all_fixed_step_totals']
    check(t['valid'] and not t['error'] and t['process_frames']==n and t['completed_steps']==total==r['ticks_advanced']==r['workload']['tick_end']-r['workload']['tick_begin'],label+' summary tick conservation')
    check(t['elapsed_us']==elapsed and t['executions']==executions,label+' all nine summary lanes')
    check(len(raw['main_draw_contexts'])==len(raw['main_draw_stages_us'])==len(raw['draw_submission_elapsed_ms']),label+' draw alignment')
    for context, child, whole in zip(raw['main_draw_contexts'],raw['main_draw_stages_us'],raw['draw_submission_elapsed_ms']):
        check(sum(child.values())<=whole*1000+1e-7,label+' main draw stage containment')
    row={k:r[k] for k in ['label','temperature','wall_seconds','ticks_advanced','ticks_per_wall_second','cast_attempts','admitted_casts_delta','refused_casts_delta','matter_paid_delta','area_loading_frames','garden_arrival_loading_frames','terrain_loading_frames','clamped_delta_seconds','dropped_accumulator_seconds','frame_interval_ms','process_elapsed_ms','draw_submission_elapsed_ms','garden_step_elapsed_ms','garden_stage_stats_ms','main_draw_stage_stats_ms','main_court_preparation_stats_ms']}
    row.update({'process_samples':n,'step_count_distribution':dict(sorted(distribution.items())),
                'completed_stage_mean_ms_per_process':{k:v/n/1000 for k,v in elapsed.items()},
                'completed_nine_stage_sum_mean_ms_per_process':sum(elapsed.values())/n/1000,
                'process_minus_completed_nine_stages_ms':stats(residual),
                'garden_step_total_ms_per_process':sum(raw['garden_step_elapsed_ms'])/n,
                'interpretation':'Process residual is unassigned; Garden step sits outside these SimWorld nine stages and may be within this residual. Nested drawing children are not additive to their parent.'})
    case_reviews.append(row)
check(sum(r['focus_sample_count'] for r in m['results'])==638 and sum(r['ticks_advanced'] for r in m['results'])==4432,'whole run process/tick totals')
check(m['results'][3]['cast_attempts']==m['results'][3]['admitted_casts_delta']==11 and m['results'][3]['refused_casts_delta']==0,'finite Fire11/11/0')
check(m['results'][4]['cast_attempts']==12 and m['results'][4]['admitted_casts_delta']==m['results'][4]['refused_casts_delta']==6,'finite Mantle12/6/6')
if errors:
    print(json.dumps({'checks':checks,'errors':errors[:30],'error_count':len(errors)},indent=2));raise SystemExit(1)
if OUT.exists(): raise RuntimeError('Fresh archive target required')
OUT.mkdir(parents=True)
payloads=[]
def copy(source, relative):
    target=OUT/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
    check(sha(source)==sha(target),'archive readback '+relative)
    payloads.append({'path':relative,'source':source.relative_to(ROOT).as_posix(),'bytes':target.stat().st_size,'sha256':sha(target)})
for name in ['metrics.json','summary.json','engine.log','engine.log.err','runtime-identity.input.json']:
    copy(RUN/name,name)
for path in s['input_hashes_before']:
    source=Path(path);copy(source,'inputs/'+source.name)
copy(Path(__file__),'archive_foreground.py')
manifest={'schema':'hex-evidence-copy-manifest-v1','payloads':payloads,'payload_count':len(payloads),'total_bytes':sum(p['bytes'] for p in payloads),'excluded':'Transient partial success metrics, isolated profile and unrelated files are not copied. Raw final metrics and summary are complete.'}
(OUT/'copy-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
review={'schema':'hex-foreground-source-review-v1','status':'passed','source_build_id':BUILD,'source_sha256':SOURCE,
 'scope':'Instrumented foreground source CPU diagnostic; not packaged-release FPS, GPU/present latency, physical-input proof, or a causal comparison to older builds.',
 'checks':checks,'errors':errors,'run_id':m['run_id'],'metrics_sha256':sha(RUN/'metrics.json'),'summary_sha256':sha(RUN/'summary.json'),
 'copy_manifest_sha256':sha(OUT/'copy-manifest.json'),'raw_source_inputs':326,'wrapper_source_inputs':7,'process_samples':638,'completed_steps':4432,
 'admission':{'manual_start':True,'armed_utc_msec':arm['armed_utc_msec'],'game_instantiation_started_utc_msec':arm['game_instantiation_started_utc_msec'],'post_arm_engine_samples':720,'post_arm_focus_exits':0,'recorded_process_unfocused':0,'windows_total_rows':231,'windows_post_arm_rows':156,'windows_post_arm_available':154,'windows_terminal_unavailable':2,'maximum_observed_gap_ms':gap,'source_before_after_unchanged':True,'stderr_bytes':0,'appdata_restored':True,'numeric_process_exit_code':None,'exit_scope':s['exit_code_scope']},
 'route':{'evidence':'Root-reported exact invocation in this conversation; no separate Profile-B external route receipt exists. Summary independently binds profiler arguments. No physical desktop-shortcut click claimed.','command':"& 'C:/Users/sende/Documents/ChatGPT/H.E.X/PLAY-HEX.cmd' -Mode Profile -OutputDirectory '.godot/iteration-20261014/foreground-6459-desktop-b'",'root_exec_session':63236,'root_reported_exec_exit_code':0},
 'configuration':s['requested'],'cases':case_reviews,
 'machine_load':{'dedicated_idle_machine':False,'evidence_scope':'Agent self-reports and wrapper snapshots, not an OS-wide activity trace. User clicked before root saw readiness; pause notice followed shortly after arming.','experience_agent':'No local commands during the measurement interval; this agent remained pending initialization until afterward.','root':'Reported a light startup log read, then idle; no other engine.','available_memory_before_mb':s['available_memory_before']['available_mb'],'available_memory_after_mb':s['available_memory_after']['available_mb'],'process_private_bytes_peak':s['window_assessment']['process_memory']['max_private_bytes'],'causal_comparison':'No matched reverse-order predecessor/current or observer-off control. Historical500be results use different state/configuration/load boundaries; no causal regression or speedup inference.'},
 'limits':['Full observer adds uncalibrated nested timing, snapshot and bookkeeping cost; isolated head/tail observer metric does not capture it all.','Sampled focus and Windows ownership do not prove continuous unobscured presentation.','Frame-start intervals may include scheduling and driver waits; no viewport GPU timing requested.','Arrival rows and fresh-process setup remain separate from warm rows.','Mantle has six real resource refusals; no measured-period refill.','Current portable performance, human input/comfort and sustained60FPS remain unqualified.']}
(OUT/'review.json').write_text(json.dumps(review,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'status':review['status'],'checks':checks,'payloads':len(payloads),'bytes':manifest['total_bytes'],'review_sha256':sha(OUT/'review.json'),'archive':str(OUT),'case_summary':[{k:r[k] for k in ['label','process_samples','ticks_advanced','step_count_distribution','completed_nine_stage_sum_mean_ms_per_process','garden_step_total_ms_per_process']}for r in case_reviews]},indent=2))
