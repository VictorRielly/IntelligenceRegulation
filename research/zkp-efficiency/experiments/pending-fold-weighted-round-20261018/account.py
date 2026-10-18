"""Integer resource census and carried native timing, with no large allocations."""
from pathlib import Path
import datetime,hashlib,json,os,re,resource,signal,time
H=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
start=time.perf_counter();groups=[]
for name,n,c in [('L',8192,2),('D+Q',131072,47),('Kv+S',32768,25),('F',524288,9)]:
 w=1<<(c-1).bit_length();k=n.bit_length()-1
 old=4*c*(n-1);new=c*(3*n-2);writes=c*(n-1)
 groups.append(dict(name=name,rows=n,columns=c,padded_columns=w,row_old_reads=old,row_new_reads=new,row_writes_unchanged=writes,row_reads_saved=old-new,row_logical_bytes_saved=16*(old-new),extra_column_reads=6*(w-1),extra_column_subs=3*(w-1),suffix_nodes_unchanged=c*(n-1-k),suffix_weight_muls_unchanged=2*c*(n-1-k)))
keys=['row_old_reads','row_new_reads','row_writes_unchanged','row_reads_saved','row_logical_bytes_saved','extra_column_reads','extra_column_subs','suffix_nodes_unchanged','suffix_weight_muls_unchanged']
total={key:sum(g[key]for g in groups)for key in keys}
total['row_read_reduction_fraction']=total['row_reads_saved']/total['row_old_reads']
total['row_read_write_reduction_fraction']=total['row_reads_saved']/(total['row_old_reads']+total['row_writes_unchanged'])
total['row_logical_bytes_saved_MiB']=total['row_logical_bytes_saved']/2**20
total['ideal_core_row_byte_only_ratio']=(total['row_old_reads']+total['row_writes_unchanged'])/(total['row_new_reads']+total['row_writes_unchanged'])
def events(name):
 return[json.loads(s)for s in(H/'baseline'/name).read_text().splitlines()if s.startswith('{')]
p=next(e for e in events('prove.log')if e['event']=='proved');v=next(e for e in events('verify.log')if e['event']=='verified');s=next(e for e in events('prove.log')if e['event']=='sealed')
controls=next(e for e in events('verify.log')if e['event']=='stack-controls')
gp=json.loads((H/'baseline/prove.guard.json').read_text());gv=json.loads((H/'baseline/verify.guard.json').read_text())
assert controls['refused']==11 and controls['honest_still_verifies'] and gp['exit']==gv['exit']==0
phase={}
for line in(H/'baseline/prove.log').read_text().splitlines():
 if not line.startswith('PB-TIMING prove |'):continue
 parts=[x.strip()for x in line.split('|')]
 if len(parts)<5:continue
 try:t=float(parts[3])
 except ValueError:continue
 phase.setdefault(parts[1],[]).append(t)
names=['H: LogUp helper inverses (six lookup domains)','H: exp + activation helper inverses','H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)','open H (schedule audit + pcs::open_zk)']
assert all(len(phase[x])==32 for x in names)
cost=sum(sum(phase[x])for x in names);wall=p['total_seconds']
baseline=dict(model='Llama-3-8B, all32 transformer blocks; D13 scope, no embedding/head/selection',context=128,passes=1,workload='cold single fixed-context pass, not resident repeats or decode',device='Core Ultra9 185H CPU, 16 threads, GPU off',shared_host=True,sample_count=1,app_total_s=wall,process_s=gp['child_wall_seconds'],diagnostic_app_positions_per_s=128/wall,diagnostic_process_positions_per_s=128/gp['child_wall_seconds'],steady_state_positions_per_s=None,sealing_s=s['seconds'],sealing_fraction=s['seconds']/wall,sealing_cumulative_load_s=s['of_which_load_seconds'],sealing_cumulative_witness_s=s['of_which_witness_seconds'],inclusive_proving_s=p['prove_run_seconds'],proving_cumulative_rebuilt_witness_s=p['of_which_witness_seconds'],witness_rebuilds=p['rebuilt_witnesses'],proving_reload_s=p['of_which_block_load_seconds'],serialization_s=None,verification_initial_load_s=v['load_seconds'],verification_inclusive_check_s=v['verify_seconds'],verification_reload_within_check_s=v['of_which_block_load_seconds'],verification_check_minus_reload_s=v['verify_seconds']-v['of_which_block_load_seconds'],verification_process_with_controls_s=gv['child_wall_seconds'],receipt_bytes=p['receipt_bytes'],controls=controls,peak_rss_gib=gp['peak_rss_gib'],peak_cgroup_gib=gp['peak_cgroup_gib'],limits=['Shape privacy acceptance open; functional diagnostic positions are not target-accepted positions','Sealing is a known lifecycle boundary, not measured full startup or prefill','Cumulative sealing load and witness clocks overlap: not disjoint wall phases','Inclusive proving covers witness rebuilding, block loading, proof and serialization/sink','No fresh resident slope, proof latency/lag/drain, isolated serialization or prefill clocks','No GPU/5090/private-weight performance result'],proved_event=p)
bound=dict(phase_names=names,phase_seconds={x:sum(phase[x])for x in names},cost_s=cost,free_deletion_speedup=wall/(wall-cost),free_deletion_diagnostic_rate=128/(wall-cost),scope='Only zero-cost deletion of four direct H families, all other time fixed. Not a bound for complete new lookup architecture or this arithmetic adapter; added work lowers this phase-set bound.')
src=(H/'native/rounds.rs').read_text();local=(H/'pending.rs').read_text()
def trait(s):return re.sub(r'\s+','',s[s.index('pub trait SumcheckRounds {'):s.index('\n}',s.index('pub trait SumcheckRounds {'))+2])
assert trait(src)==trait(local)
out=dict(status='PASS',groups=groups,aggregate_core_row_census=total,baseline=baseline,direct_H_phase_deletion_bound=bound,local_payload='Same C*N Fp2 working V allocation, per-column points/prefix and O(logN) DFS stack. No expanded E/S/index, no private-value-based scheduling; input witness remains live.',limits=['Counts are logical field accesses, not measured DRAM or kernel time','Four-group census uses prior8B T32 domains; carried native clocks are T128. Do not multiply them together','Counts exclude input-copy/materialization, common tail setup, output, masks/GKR/PCS/links and original-witness reads','Prototype capsN32768,NC2^20 refuse larger groups; no model-shape arrays executed','Extra column reads and subs arise because measure and bind are separate calls; counted explicitly','Known row folding arithmetic and suffix generation remain; no native end-to-end speedup inferred'],wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'accounting.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({k:v for k,v in out.items()if k not in ['baseline','groups']},indent=2))
