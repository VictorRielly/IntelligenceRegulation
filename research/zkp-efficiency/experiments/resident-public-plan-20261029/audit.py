"""Provenance, counts and independently recomputed work formulas; no native proof."""
from pathlib import Path
import json,hashlib,time,resource
HERE=Path(__file__).resolve().parent
start=time.monotonic();checks=0
def sha(b):return hashlib.sha256(b).hexdigest()
def ck(v,label):
 global checks
 checks+=1
 if not v:raise AssertionError(label)
def extract(text,prefix):
 a=text.index(prefix);b=text.index('{',a);depth=1;i=b+1
 while depth:depth+=(text[i]=='{')-(text[i]=='}');i+=1
 return text[a:i]
pins=json.loads((HERE/'native-pins.json').read_text())
for p in pins:
 ck(sha(Path(p['path']).read_bytes())==p['sha256'],'native source unchanged')
 ck(sha((HERE/p['snapshot']).read_bytes())==p['sha256'],'snapshot exact')
arg=(HERE/'native/argument.rs').read_text()
for prefix,name in [('pub(super) fn priv_table(', 'native_priv_table'),('fn claim_point(', 'native_claim_point'),('fn mask_eval(', 'native_mask_eval')]:
 old=prefix.split('fn ')[1].split('(')[0];f=extract(arg,prefix).replace('pub(super) ','').replace('fn '+old+'(','fn '+name+'(',1)+'\n'
 ck((HERE/(name+'.rs')).read_text()==f,'exact extracted body '+name)
for anchor in ['let hi_map = map(&p.coords[..hi_len], hi_len);','let lo_map = map(&p.coords[hi_len..], lo_len);','let eqf = eq_table_msb(&fixed);','if simple {','if used != (1usize << n_vars) - 1 {']:
 ck(anchor in arg,'native repeated map/fresh-value seam')
cand=(HERE/'candidate.rs').read_text();body=cand.split('pub struct Plan {',1)[1].split('}',1)[0]
for forbidden in ['Fp2','Fp,','Priv','data','slices','mask_row','ext_round']:
 ck(forbidden not in body,'plan contains no challenge/private payload '+forbidden)
ck('enum Op {Rho(usize),Flip(usize),Fixed}'in cand,'fixed marker contains no field value')
ck('let eqf=eq_table_msb(&fixed);'in cand.split('pub fn execute',1)[1],'Eq rebuilt at every execute')
for forbidden in ['unsafe','static mut','thread','random','std::fs','Transcript','MaskFunctional']:
 ck(forbidden not in cand,'candidate has no unscoped side effects '+forbidden)
r=json.loads((HERE/'result.json').read_text());a=json.loads((HERE/'account-result.json').read_text())
ck(r['status']=='PASS'and a['status']=='PASS','completed probes')
ck(r['fixtures']==10*7*3,'fixture count')
ck(r['synthetic_pass_replays']==r['fixtures']*15,'resident replay count')
ck(r['comparisons']==3*r['synthetic_pass_replays'],'table/table/extension comparison count')
ck(r['fresh_mask_checks']==r['synthetic_pass_replays'],'each pass masks fresh')
ck(r['negative_controls']==10,'explicit ten controls')
ck(r['full_stack_proofs']==r['model_passes']==r['proved_positions']==0,'no proved tokens')
ck(len(r['bench'])==3*3*4,'benchmark cases')
for b in r['bench']:
 for label in ['native_ns','planned_total_ns','plan_startup_ns']:ck(len(b[label])==3,'raw sample arrays retained')
 ck(all(s<=t for s,t in zip(b['plan_startup_ns'],b['planned_total_ns'])),'setup included')
 log=b['log'];lo=log//2;hi=log-lo
 ck(b['plan_payload_bytes']==16*((1<<lo)+(1<<hi)),'map payload')
cost=json.loads((HERE/'costs.json').read_text())
for c in cost:
 ck(c['unique_map_coordinate_visits']<=c['map_coordinate_visits_per_block'],'sharing nonnegative')
 for o in c['options']:
  p=o['synthetic_resident_passes']
  ck(o['map_visits_removed']==p*c['map_coordinate_visits_per_block']-c['unique_map_coordinate_visits'],'map removal formula')
  ck(o['fresh_private_base_reads_retained']==p*c['private_base_reads_per_block'],'all private reads remain')
  ck(o['fresh_output_words_retained']==p*c['output_words_per_block'],'all output writes remain')
  ck(o['added_signature_vector_allocations']==p*c['sites'],'added validation cost')
prior=json.loads((HERE/'startup/prior-hypotheses.json').read_text());now=json.loads((HERE/'hypotheses.json').read_text())
ck(now[:len(prior)]==prior,'all sixty prior hypotheses preserved unchanged')
ck(len(now)==len(prior)+1,'one new hypothesis')
out={'status':'PASS','checks':checks,'native_pins':len(pins),'extracted_native_bodies':3,'external_review':False,'scope':'same-researcher provenance/count/side-effect audit; independent arithmetic walk is in harness.rs','elapsed_s':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'full_stack_proofs':0}
(HERE/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
