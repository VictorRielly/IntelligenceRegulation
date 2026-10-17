from pathlib import Path
from decimal import Decimal as D
import hashlib,json,os,resource,signal,time
e=Path(__file__).resolve().parent
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
resource.setrlimit(resource.RLIMIT_CPU,(59,59));signal.alarm(59)
start=time.perf_counter();checks=0;live_drift=[]
def check(x):
 global checks
 assert x
 checks+=1
j=json.loads((e/'result.json').read_text())
for pin in json.loads((e/'native-pins.json').read_text()):
 check(hashlib.sha256(Path(pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'])
 live_hash=hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()
 if live_hash!=pin['sha256']:
  live_drift.append({'path':pin['path'],'snapshot_sha256':pin['sha256'],'current_sha256':live_hash})
 else:check(True)
meta=json.loads((e/'candidate-metadata.json').read_text())
base=Path(meta['source_pin']['snapshot']).read_text();candidate=(e/'candidate/witness.rs').read_text()
check(hashlib.sha256(candidate.encode()).hexdigest()==meta['candidate_sha256'])
check(candidate.count('fn matmul_i8_projection(')==1)
for old,new in meta['call_replacements']:
 check(old in base);check(new in candidate)
check('quantize(&matmul_in_out(&g, &h16,' in candidate)
# Original call lines recovered byte-for-byte, including quantize/refusal order.
snippet=(e/'i8_projection.rs').read_text();recovered=candidate.replace(snippet+'\n','')
for old,new in meta['call_replacements']:recovered=recovered.replace(new,old)
check(recovered==base)
check('!(-127..=127).contains(&q)' in base)
check('shape.sh_o, -127, 127, "O"' in base)
check(len(j['controls'])==12)
for r in j['retained_linked_stack_accounting']:
 p=r['proved_log_event'];v=r['fresh_verifier_log_event']
 for name in ['blocks','receipt_bytes','statement_identity']:check(p[name]==v[name])
 total=D(str(p['total_seconds']));seal=D(str(p['sealing_pass_seconds']));rebuild=D(str(p['of_which_witness_rebuild_seconds']))
 check(abs(float(seal+rebuild)-r['two_witness_seconds'])<1e-9)
 check(abs(float((seal+rebuild)/total)-r['witness_fraction_of_reported_total'])<1e-14)
 check(D(str(p['prove_run_seconds']))>=rebuild)
 check(total>seal+D(str(p['prove_run_seconds']))+D(str(p['load_seconds'])))
for p in j['source_loop_census']:
 # Independent closed expression, grouped by projection class.
 t,dp,fp,kv=p['T'],p['Dpad'],p['Fpad'],p['kv_width']
 direct=t*(2*dp*dp+2*dp*kv+2*dp*fp)
 down=t*dp*fp
 check(p['direct_i32_projection_macs']==direct)
 check(p['projection_macs_one_build']==direct+down)
 check(p['double_build_projection_macs_whole_stack']==2*p['layers']*(direct+down))
 for site in p['sites']:
  check(site['acc_abs_bound']==site['K']*site['activation_abs_bound']*128)
  check(site['direct_i32_exact']==(site['name']!='down'))
  # Conservative absolute bound also controls cancellation and saturation.
  if site['direct_i32_exact']:check(site['acc_abs_bound']<2**31)
check(j['float_cancellation_control']['exact_sum']==1)
check(j['float_cancellation_control']['f32_sum']==0)
for b in j['cpu_microbenchmarks']:
 for arm,samples in b['seconds_samples'].items():
  check(len(samples)==7);check(all(z>0 for z in samples))
awe=json.loads((e/'awe-filter-result.json').read_text())
check(awe['independent_pair_checks']==65536)
# Independent bilinear coefficient identity via basis vectors, not encoding search.
weights=[1,29,37];coeff=awe['coefficients']
for i in range(3):
 for k in range(3):
  a=[int(i==z) for z in range(3)];b=[int(k==z) for z in range(3)]
  terms=[a[0]*b[0],a[1]*b[1],a[2]*b[2],(a[0]+a[1])*(b[0]+b[1]),(a[0]+a[2])*(b[0]+b[2]),(a[1]+a[2])*(b[1]+b[2])]
  check(sum(x*y for x,y in zip(coeff,terms))==weights[i]*weights[k])
check(j['proof_accounting']['accepted_complete_private_8b_proofs']==0)
check(j['proof_accounting']['total_workload_tokens_per_second'] is None)
out={'status':'pass_snapshot_checks_with_integration_blocker' if live_drift else 'pass','snapshot_validation':'pass','live_source_drift':live_drift,'native_candidate_current':not live_drift,'checks':checks,'wall_seconds':time.perf_counter()-start,'max_rss_KiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'threads':1,'affinity':sorted(os.sched_getaffinity(0)),'scope':'independent snapshot integrity, inverse patch, Decimal accounting, census formula and bilinear coefficient checks; live hash drift is an explicit integration blocker; no native proof or privacy gate'}
(e/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
