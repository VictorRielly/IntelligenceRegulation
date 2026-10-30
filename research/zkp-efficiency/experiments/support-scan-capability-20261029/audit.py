"""Independent source/cost audit. Reads production; writes this experiment only."""
from pathlib import Path
import hashlib,json,resource,signal,time,os,re
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
resource.setrlimit(resource.RLIMIT_CPU,(20,20));resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,256*1024**2));signal.alarm(25)
start=time.monotonic();ex=Path.cwd();checks=0
def ck(x,s):
 global checks
 checks+=1
 assert x,s
pins=json.loads((ex/'native-pins.json').read_text())
for pin in pins:
 ck(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'],'unchanged source')
 ck(Path(pin['path']).read_bytes()==(ex/pin['snapshot']).read_bytes(),'snapshot exact')
p=(ex/'native/private_block.rs').read_text()
fn=p[p.index('fn weights_vanish_off_support('):p.index('/// The attention half of the public statement')]
for marker in ['let inner_off: Vec<usize>','if outer.supported(sh, o).is_err()',
               'inner_off.iter().any','if !violation','for o in 0..no','outer.supported(sh, o)?','inner.supported(sh, i)?']:
 ck(marker in fn,marker)
checks_calls=re.findall(r'weights_vanish_off_support\(sh, (\w+), Axis::(\w+)(?:\(([^)]*)\))?, Axis::(\w+)(?:\(([^)]*)\))?\)\?;',p)
ck(len(checks_calls)==9,'nine explicit role checks')
expected=[('wq','Q','','D',''),('wk','Full','kv','D',''),('wv','Full','kv','D',''),('wo','D','','Q',''),
          ('gamma_a','Full','1','D',''),('gamma_m','Full','1','D',''),('wg_t','D','','F',''),('wu_t','D','','F',''),('wd_t','F','','D','')]
ck(checks_calls==expected,'actual role order and domains')
result=json.loads((ex/'result.json').read_text());c=result['census']
# Independent integer count from true/padded matrix extents, no model imports.
d,f,q,kv,dp,fp,qp=4096,14336,4096,1024,4096,16384,4096
real=dict(wq=(qp,dp,q,d),wk=(kv,dp,kv,d),wv=(kv,dp,kv,d),wo=(dp,qp,d,q),
          gamma_a=(1,dp,1,d),gamma_m=(1,dp,1,d),wg_t=(dp,fp,d,f),wu_t=(dp,fp,d,f),wd_t=(fp,dp,f,d))
for row in c['roles']:
 no,ni,to,ti=real[row['role']]
 ck(row['padded_bytes']==no*ni,'matrix size')
 ck(row['off_support_reads_per_honest_check']==no*ni-to*ti,'off support count')
 ck(row['row_visits']==no,'row traversal count')
ck(c['support_reads_per_check']==3*4096*(16384-14336)==25165824,'24MiB')
ck(c['support_reads_per_32_layers']==805306368,'32 layer single extra sweep')
ck(c['all_i8_bytes']==243277824,'padded i8 payload')
ck(sum(r['row_visits'] for r in c['roles'])==34818,'metadata rows')
ck(sum(r['inner_support_metadata_tests'] for r in c['roles'])==61440,'metadata inner predicates')
for row in result['rows']:
 ck(row['candidate']['support_reads']==0,'same-owner repeated support cache')
 ck(row['candidate']['cache_hits']==9,'all nine predicates cached')
 ck(row['baseline']['fallback_reads']==0,'honest no fallback')
sites={}
for pin in pins:
 text=(ex/pin['snapshot']).read_text();hits=[]
 for i,l in enumerate(text.splitlines(),1):
  if '.check_for_shape(' in l or 'weights_vanish_off_support(sh,' in l or 'Self::check_words(sh,' in l:
   hits.append(dict(line=i,text=l.strip()))
 sites[pin['snapshot']]=hits
schedule=[]
for passes in [1,2,4,8]:
 for calls in [1,2,4,8]:
  for lifetime in ['new owner each check','one owner per pass','one resident owner']:
   total=passes*calls;owners={'new owner each check':total,'one owner per pass':passes,'one resident owner':1}[lifetime]
   saved=(total-owners)*25165824
   ck(saved>=0 and saved<total*25165824,'must retain first scan of each actual owner')
   schedule.append(dict(passes=passes,checks_per_pass=calls,owner_lifetime=lifetime,total_checks=total,
                        first_scans_retained=owners,synthetic_logical_bytes_saved=saved,proof_positions=0))
out=dict(status='PASS_SOURCE_COST_AUDIT_ONLY',checks=checks,native_pins=len(pins),
         elapsed_s=time.monotonic()-start,peak_rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
         roles=checks_calls,sites=sites,lifetime_countermodel=schedule,
         limitations=['Static sites are alternatives and nested; not actual call frequencies.',
                     'Current off-support optimization already avoids 89.66% of padded payload reads.',
                     'Streaming CacheBlocks fit_the_shape checks geometry, not full block scans.',
                     'Original first validation of each owner, metadata/table/DD/order/provenance checks retained.',
                     'One wrapper rebuilt per check saves zero; detached/caller asserted support certificate is unsafe.',
                     'No native compilation, execution, complete proof, GPU or privacy acceptance.'])
(ex/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:out[k] for k in ['status','checks','native_pins','elapsed_s','peak_rss_kib']}))
