"""Allocation-free counted domains and explicit UNIMPLEMENTED claim inventory."""
from pathlib import Path
import json,collections,resource,signal,os,time,datetime,re,platform
H=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
start=time.perf_counter();prior=json.loads((H/'prior-accounting.json').read_text())
sizes=dict(L=8192,D=131072,Q=131072,Kv=32768,S=32768,F=524288)
cols=dict(L=2,D=34,Q=13,Kv=12,S=13,F=9)
shape=(H/'native/shape.rs').read_text();owner=(H/'native/owner-8b-counts.txt').read_text()
assert 'Dom::F => 9,' in shape and 'Dom::Q => 13,' in shape and 'Dom::Kv => 12,' in shape
assert 'self.lookups_per_position(dom).div_ceil(2)' in shape
q=sum(sizes[d]*cols[d] for d in cols);c=sum(cols.values());assert c==83 and q==11714560
assert 'u8 lookups 11,714,560' in owner
for r in prior['rows']:assert r['positions']==sizes[r['domain']] and r['lookup_columns']==cols[r['domain']]
up=lambda n:1<<(n-1).bit_length()
groups=collections.defaultdict(list)
for d,n in sizes.items():groups[n].append(d)
plans=[]
for name,gs in [('per_column',[[d] for d in sizes for _ in range(cols[d])]),('six_domains',[[d] for d in sizes]),('four_equal_length_groups',list(groups.values())),('one_global_cube',[list(sizes)])]:
 # Per-column repeats represent one column rather than all domain columns.
 visits=sum(max(sizes[d] for d in g)*up(1 if name=='per_column' else sum(cols[d] for d in g)) for g in gs)
 pushes=len(gs)
 plans.append(dict(plan=name,pushforwards=pushes,logical_pushforward_bytes=pushes*256*16,row_lifted_pushforward_bytes_before_masks=pushes*8192*16,dense_cube_positions=visits,dense_cube_over_original_queries=visits/q,query_entries_if_public_support_skipped=q,
  illustrative_claim_inventory=dict(pushforward_initial_evaluation_sites=pushes,pushforward_GKR_terminal_sites=pushes,original_ordered_index_evaluations_before_additional_reductions=c,public_table_evaluation_sites=pushes,private_scalar_sites_before_round_messages=2*pushes+c),
  mask_inventory=dict(pushforward_commitment_hiding_families=pushes,pushforward_initial_and_terminal_joint_view_obligations=2*pushes,original_index_link_obligations=c,GKR_round_masks='unknown; no GKR implemented',original_A_claim_site_reserved_rows='unknown; native schedule must be redesigned',fresh_mask_bytes='unknown',net_removable_H_or_M_rows='unknown'),
  caveat='Illustrative Powdr opening interface inventory, not a mandatory/minimal native schedule, exact mask count, net saving, GKR time or peak memory. Each original index needs a checked affine/wrapping A link. Distinct prior points require an additional reduction.'))
v=json.loads((H/'native/verify.log').read_text().splitlines()[0]);g=json.loads((H/'native/verify.guard.json').read_text());pg=json.loads((H/'native/prove.guard.json').read_text())
assert v['event']=='verified' and v['blocks']==32 and v['receipt_bytes']==465815776
controls=[json.loads(x) for x in (H/'native/verify.log').read_text().splitlines() if x.startswith('{')]
assert next(x for x in controls if x['event']=='stack-controls')['refused']==11
# Report app and process clocks separately; guard verify includes the controls.
wall=171.578;startup=15.345;removed=19.5
clocks=dict(owner_scope='Carried n=1 shared-box cold 8B T32, 32 linked blocks, one pass; CPU sixteen threads, GPU off. Functional fresh verification observed; privacy acceptance still open.',app_total_s=wall,guard_process_total_s=pg['child_wall_seconds'],diagnostic_positions_per_app_s=32/wall,diagnostic_positions_per_process_s=32/pg['child_wall_seconds'],witness_s=21.376,inclusive_prove_run_s=156.143,recurring_block_reload_inside_prove_s=15.993,remaining_proof_serialization_sink_s=156.143-21.376-15.993,partial_initial_load_and_seal_s=startup,partial_startup_fraction=startup/wall,full_startup_s=None,steady_state_positions_per_s=None,isolated_serialization_s=None,fresh_verify_load_s=v['load_seconds'],fresh_verify_inclusive_s=v['verify_seconds'],fresh_verify_reload_inside_s=v['of_which_block_load_seconds'],fresh_verify_crypto_remainder_s=v['verify_seconds']-v['of_which_block_load_seconds'],fresh_verify_process_including_controls_s=g['child_wall_seconds'],receipt_bytes=v['receipt_bytes'],refused_controls=11,proof_latency_s=None,proof_lag_s=None,pipeline_drain_s=None,conditional_H_phase_deletion_s=removed,conditional_fixed_other_work_ceiling_ratio=wall/(wall-removed),conditional_diagnostic_ceiling_positions_per_s=32/(wall-removed),no_new_proofs_or_positions=True)
out=dict(status='PASS',scope='COUNTED geometry, not execution at 8B shape; no private data read or copied.',context=32,passes_this_experiment=0,device='one Core Ultra 9 185H CPU thread; no GPU',columns=c,U8_queries=q,plans=plans,baseline_H=prior['H'],additional_query_commitment_saved_bytes=0,owner_clocks=clocks,new_target_compliant_proofs=0,new_target_compliant_positions=0,wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'accounting.json').write_text(json.dumps(out,indent=2)+'\n')
(H/'environment.json').write_text(json.dumps(dict(cpu=next(x.split(':',1)[1].strip() for x in Path('/proc/cpuinfo').read_text().splitlines() if x.startswith('model name')),platform=platform.platform(),python=platform.python_version(),device='CPU only; no GPU calls',threads=1,cpu_affinity=list(os.sched_getaffinity(0)),seed=2026101768,nice=19,estimated_main_mib=96,estimated_compiler_mib=192),indent=2)+'\n')
print(json.dumps(dict(plans=[{k:p[k] for k in ['plan','pushforwards','dense_cube_positions','dense_cube_over_original_queries','logical_pushforward_bytes','row_lifted_pushforward_bytes_before_masks']} for p in plans],owner_clocks=clocks),indent=2))
