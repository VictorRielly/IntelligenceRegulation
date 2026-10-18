"""Integer payload / measured-phase accounting. No model-scale allocation."""
from pathlib import Path
import datetime,hashlib,json,os,re,resource,signal,time
H=Path(__file__).resolve().parent;ROOT=Path('/home/victor/IntelligenceRegulation')
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
resource.setrlimit(resource.RLIMIT_AS,(512*2**20,512*2**20));resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
start=time.perf_counter();groups=[]
for name,n,c in [('L',8192,2),('D+Q',131072,47),('Kv+S',32768,25),('F',524288,9)]:
 k=n.bit_length()-1;w=1<<(c-1).bit_length();l=w.bit_length()-1;m=k+l
 # Fixed original-stride values allocation remains resident throughout this probe.
 v=16*n*c;points=16*c*k;cp=16*l;challenges=16*m;prefix=16*c;tail=48*w;output=64*m+48
 # Input point/challenge payload plus temporary prefix/tail/message payload;
 # their exact overlap differs; deliberately sum them as a conservative payload census.
 meta=points+cp+challenges+prefix+tail+output
 groups.append(dict(name=name,rows=n,columns=c,padded_columns=w,row_bits=k,column_bits=l,old_index_three_factor_payload_B=56*n*c,new_value_payload_B=v,new_small_payload_B=meta,new_conservative_payload_B=v+meta,removed_full_E_S_index_payload_B=40*n*c,old_dense_pairs=n*w-1,row_first_pairs=c*(n-1)+w-1,eq_internal_nodes=c*(n-1-k),extra_weight_regeneration_mul=2*c*(n-1-k),value_reads_weighted_pass=2*c*(n-1),value_reads_separate_fold=2*c*(n-1),value_writes_fold=c*(n-1)))
total={key:sum(g[key]for g in groups)for key in groups[0]if isinstance(groups[0][key],int)and key not in['row_bits','column_bits']}
total['new_to_old_payload_ratio']=total['new_conservative_payload_B']/total['old_index_three_factor_payload_B']
total['old_payload_MiB']=total['old_index_three_factor_payload_B']/2**20
total['new_value_payload_MiB']=total['new_value_payload_B']/2**20
total['new_conservative_payload_MiB']=total['new_conservative_payload_B']/2**20
total['max_group_payload_MiB']=max(g['new_conservative_payload_B']for g in groups)/2**20
log=ROOT/'results/zk60_1b_native_20261017/r5b/stack-llama3_8b_pg_rot1_T32-ho00-cpu/prove.log'
phase={}
for line in log.read_text().splitlines():
 if not line.startswith('PB-TIMING prove |'):continue
 parts=[p.strip()for p in line.split('|')]
 if len(parts)<5:continue
 name=parts[1]
 try:value=float(parts[3])
 except ValueError:continue
 phase.setdefault(name,[]).append(value)
names=['H: LogUp helper inverses (six lookup domains)','H: exp + activation helper inverses','H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)','open H (schedule audit + pcs::open_zk)']
assert all(len(phase[n])==32 for n in names)
charged=sum(sum(phase[n])for n in names);b=json.loads((H/'baseline.json').read_text());t=b['app_total_s']
bound=dict(phase_names=names,per_phase_counts={n:len(phase[n])for n in names},per_phase_s={n:sum(phase[n])for n in names},charged_s=charged,total_s=t,zero_cost_deletion_speedup=t/(t-charged),zero_cost_deletion_diagnostic_positions_per_s=32/(t-charged),fraction=charged/t,interpretation='Only a free-deletion ceiling for these four measured direct H phase families with every other clock fixed. Not a ceiling on the full lookup architecture, shared zero-checks, GPU, or 5090. Added costs reduce this ceiling.')
b['phase_sums']={n:sum(v)for n,v in phase.items()};b['phase_counts']={n:len(v)for n,v in phase.items()}
b['limits'].append('load_seconds=35.798 is the cumulative sealing-load timer, overlaps witness32.584 inside seal37.214; do NOT subtract reload19.052 from it')
b['sealing_load_sum_s']=35.798
(H/'baseline.json').write_text(json.dumps(b,indent=2)+'\n')
out=dict(status='PASS',groups=groups,aggregate_payload_only=total,direct_phase_deletion_bound=bound,limits=['No 8B array allocated; aggregate four groups is not peak','max group excludes original witness/query buffers, masks, PCS, GKR, native layout/commitments, allocator and recursion-stack overhead','Rust FFI harness makes an owned V working copy; existing witness/query source remains live','memory census is not a proved lookup protocol or measured speedup','prototype cap32768rows deliberately does not run full counted groups','whole-cube fresh masks and 83 ordered links retained as obligations','remaining row bits use per-column equality; whole polynomial is not one globally factorizable row equality'],wall_seconds=time.perf_counter()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,threads=1,measured_log_sha256=hashlib.sha256(log.read_bytes()).hexdigest(),completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(H/'accounting.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
