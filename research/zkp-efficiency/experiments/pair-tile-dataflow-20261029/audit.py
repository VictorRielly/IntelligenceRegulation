"""Independent provenance and arithmetic-cost audit; no native proof acceptance."""
from pathlib import Path
import hashlib,json,resource,time
HERE=Path(__file__).resolve().parent
start=time.monotonic();checks=0
def ck(v,label=''):
 global checks
 checks+=1
 if not v:raise AssertionError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
pins=json.loads((HERE/'native-pins.json').read_text())
for p in pins:
 ck(sha(Path(p['path']).read_bytes())==p['sha256'],p['path'])
 ck(sha((HERE/p['snapshot']).read_bytes())==p['sha256'],p['snapshot'])
for p in json.loads((HERE/'research-pins.json').read_text()):
 ck(sha((HERE/p['snapshot']).read_bytes())==p['sha256'],p['snapshot'])
 ck(sha(Path(p['path']).read_bytes())==p['sha256'],p['path'])
extract=json.loads((HERE/'extraction.json').read_text());native=(HERE/'native/argument.rs').read_text()
ck(extract['original'] in native,'native exact baseline')
ck((HERE/'baseline_mask.rs').read_text().strip()==extract['original'].replace('fn mask_eval(', 'fn baseline_mask_eval(',1),'baseline rename only')
candidate=(HERE/'candidate.rs').read_text()
anchors=['assert_eq!(self.point,point);','assert_eq!(p.xs.len(),self.eq.len());','assert_eq!(p.ys.len(),self.eq.len());','let (x,y)=(p.xs[i],p.ys[i]);','let s=e.c0.add(e.c1);','a[j]=a[j].add(e.c0.mul(x));','b[j]=b[j].add(e.c1.mul(y));','c[j]=c[j].add(s.mul(x.add(y)));','out.push(Fp2::new(a[j].add(b[j].mul(Fp(7))),c[j].sub(a[j]).sub(b[j])))']
def structural_check(s):return all(x in s for x in anchors)
ck(structural_check(candidate))
for anchor in anchors:ck(not structural_check(candidate.replace(anchor,'/* deliberately removed */')),'structural mutation')
# These are static anchor mutations, not executed compiled arithmetic mutants.
result=json.loads((HERE/'result.json').read_text())
for k,v in dict(status='PASS',seed=202610290143,fixtures=720,terminal_comparisons=36000,direct_cube_checks=5040,extension_checks=28800,negative_controls=10,full_stack_proofs=0,model_passes=0,proved_positions=0).items():ck(result[k]==v,k)
initial=json.loads((HERE/'initial-control-label/result.json').read_text());ck(initial['digest']==result['digest'],'label-only correction preserves value digest')
ck(initial['negative_controls']==11 and result['negative_controls']==10,'positive edge relabel retained')
costs=json.loads((HERE/'costs.json').read_text())
for r in costs:
 a,b,c=r['options'];M=a['pair_coefficients'];ck(a['K']==1 and b['K']==2 and c['K']==4)
 for o in (a,b,c):
  ck(o['private_reads_words']==2*M)
  ck(o['public_read_bytes_removed']==16*o['public_additions_removed'])
  ck(o['tiled_public_read_bytes']+o['public_read_bytes_removed']==16*M)
  ck(o['accumulator_payload_bytes']==24*o['K'])
  ck(o['max_private_streams']==2*o['K'])
  ck(o['added_sum_buffer_bytes']==0)
  ck(1<=o['source_read_byte_ratio']<=2*o['K']/(o['K']+1))
  ck(o['extra_scalar_spill_read_write_break_even_per_full_tile']*16==16*(o['K']-1))
  ck(o['private_reads_words']*8+o['tiled_public_read_bytes']==int(32*M-o['public_read_bytes_removed']))
for stage in ('compile','probe','account'):
 e=json.loads((HERE/(stage+'-execution.json')).read_text());ck(e['exit_code']==0);ck(e['elapsed_s']<60);ck(e['max_rss_kib']<512*1024);ck(e['one_cpu_affinity']);ck(not e['gpu'] and not e['cargo'])
account=json.loads((HERE/'account-result.json').read_text());ck(account['status']=='PASS' and account['geometries']==36 and account['trace_cases']==96)
out=dict(status='PASS',checks=checks,native_pins=len(pins),static_anchor_mutations=len(anchors),executed_arithmetic_mutants=0,source_identity_and_cost_audit_only=True,external_review=False,native_receipts_verified=False,elapsed_s=time.monotonic()-start,max_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
(HERE/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
