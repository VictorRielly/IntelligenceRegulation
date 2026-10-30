"""Bounded source/provenance audit; never imports or executes native code."""
import os,resource,signal,sys,time
resource.setrlimit(resource.RLIMIT_CPU,(20,20));resource.setrlimit(resource.RLIMIT_AS,(256<<20,256<<20));signal.alarm(25)
os.nice(19);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
from pathlib import Path
import hashlib,json,datetime
D=Path(__file__).resolve().parent;R=D.parent.parent;t=time.perf_counter();count=0
def read(p):return json.loads((D/p).read_text())
def sha(b):return hashlib.sha256(b).hexdigest()
def ck(cond,why):
 global count
 assert cond,why
 count+=1
r=read('result.json');ck(r['status']=='PASS_SYNTHETIC_CONTRACT_ONLY','scope')
ck(r['checks']==sum(r['checks_by_kind'].values())==1717,'check census')
ck(r['checks_by_kind']['negative_control']==len(r['negative_controls'])==1067,'negative controls')
ck(len(r['fixtures'])==32,'fixtures')
ck({x['vocab'] for x in r['fixtures']}=={2,3,8,17},'vocab')
ck({x['width'] for x in r['fixtures']}=={4,8,16,32},'width')
ck(sum(not x['rational_matches'] for x in r['fixtures'])==2,'rational negative')
ck(sum(len(x['head_byte_differences_vs_rational']) for x in r['fixtures'])==3,'three byte differences')
edge=read('rounding-edge.json');ck(edge['binary64_quantized']==-64 and edge['rational_quantized']==-63,'edge')
ck(r['elapsed_s']<60 and r['peak_rss_kib']<512*1024 and r['hardware']['threads']==1,'caps')
for n,h in r['code_hashes'].items():ck(sha((D/n).read_bytes())==h,'code '+n)
for n,h in read('before-extra-controls/result.json')['code_hashes'].items():ck(sha((D/'before-extra-controls'/n).read_bytes())==h,'prior pass '+n)
for key in ['independently_verified_full_stack_proofs','passes','countable_positions']:ck(r['proof_accounting'][key]==0,key)
for key in ['context_length','startup_s','prefill_s','startup_fraction','witness_s','proof_s','serialization_s','verification_s','steady_state_positions_s','total_workload_positions_s','latency_s','proof_bytes']:ck(r['proof_accounting'][key] is None,key)
ck(read('execution.json')['exit_code']==0,'successful final execution')
native={};live=[]
for p in read('native-pins.json'):
 q=R/p['retained'];b=q.read_bytes();ck(sha(b)==p['sha256'],'native snapshot '+p['path']);native[p['path']]=b.decode()
 h=sha(Path(p['path']).read_bytes());live.append({'path':p['path'],'sha256':h,'unchanged':h==p['sha256']})
 ck(h==p['sha256'],'live native unchanged '+p['path'])
def src(suffix):return next(v for k,v in native.items() if k.endswith(suffix))
derive=src('/tied_tables/derive.rs');trained=src('/trained_block.rs');statement=src('/trained_statement.rs');classify=src('/classify_tied.rs');cli=src('/classify_cli.rs');load=src('/token_io/load.rs')
for s in ['const CHECKPOINT_BYTES: u64 = 7698241104;','const WIDTH: usize = 3072;','const VOCAB: usize = 131072;','hasher.update(&buffer[..count]);','let raw = bf16(&raw_bytes)?;','consumed tied tensor SHA-256 differs from pin','(value/scale+0.5).floor()','*x=(*x as f32) as f64','scales.push(head_scale)']:
 ck(s in derive,'derive '+s)
for s in ['recompute_declared_tied_tables(dir, p)?','(None, None) => return Ok(None)','hash_regular_exact(&td.join(file), length)?','let tied = tied_of(dir, &p, geometry, &source)']:ck(s in trained,'trained '+s)
for s in ['if super::shape::SHIELDSTRAL_PROFILES.contains(&profile)','pub(crate) fn tied_tensor_for_profile']:ck(s in statement,'untied incidence '+s)
for s in ['recompute_tied_tables(export, Some((id(mp.yes)?, id(mp.no)?, mp.scale())))','tied.profile_sha256 != *statement_profile_sha256','check_files_against(&tied, &files.w_delta']:ck(s in classify,'classifier '+s)
ck(cli.count('let p = load_export(&export)?;')>=2,'prove/verify load sites')
ck(cli.count('super::classify_tied::load_tied_classifier_tables(&p')>=2,'prove/verify classifier sites')
ck('let ex = TrainedExport::load(export)?;' in load,'export load chain')
for s in ['pub embedding_sha256','pub margin: Option<Vec<i16>>','#[derive(Clone, Debug)]']:ck(s in derive,'result is data not authority '+s)
facts={'source_site_incidence':'two source sites, not measured runtime calls','checkpoint_bytes':7698241104,'tensor_bytes':131072*3072*2,'logical_read_lower_bound_per_derivation':7698241104+131072*3072*2,'retained_margin_bytes':3072*2,'retained_digests_bytes':3*32,'existing_integer_table_bytes':131072*3072*3+131072*8,'direct_current_llama8b_removed_work':0,'native_proof_or_device_executed':False}
ck(facts['logical_read_lower_bound_per_derivation']==8503547472,'read lower bound')
ck(facts['existing_integer_table_bytes']==1209008128,'still read integer tables')
(D/'source-facts.json').write_text(json.dumps(facts,indent=2)+'\n')
for p in read('startup/manifest.json'):
 ck(sha((R/p['retained']).read_bytes())==p['sha256'],'startup '+p['retained'])
prior=read('startup/prior__hypotheses.json');new=read('hypotheses.json');ck(len(prior)==46 and len(new)==48,'ranked queue')
for i,x in enumerate(prior):
 ck(x['rank']==new[i]['rank'],'retained rank '+str(i+1))
 if i not in [0,45]:ck(x==new[i],'unchanged hypothesis '+str(i+1))
for x in new:
 for k in ['baseline','eliminated_work','added_costs','prerequisites','integration_cost','exactness','privacy_soundness','compatibility','end_to_end_ceiling','falsification']:ck(bool(x[k]),str(x['rank'])+k)
rs=read('sources-cycle.json');ck(len(rs)==8,'sources')
for x in rs:
 for k in ['url','access_date','publication_date','verified_update_date','implementation_license','inspected_commit_id','assessment']:ck(k in x,'source '+k)
 ck(x['external_execution'] is False and x['reproduced_performance'] is False,'unreproduced author claims')
prior_sources=(D/'startup/sources.jsonl').read_bytes();cur=(R/'sources.jsonl').read_bytes();ck(cur.startswith(prior_sources),'prior sources preserved')
ck(len(cur.splitlines())==857 and len(prior_sources.splitlines())==849,'source count')
ck([json.loads(x) for x in cur[len(prior_sources):].splitlines()]==rs,'source append equality')
ck((R/'FINDINGS.md').read_bytes().startswith((D/'startup/FINDINGS.md').read_bytes()),'prior findings preserved')
out={'status':'PASS_SOURCE_SCOPE_AND_PROVENANCE_ONLY','checks':count,'elapsed_s':time.perf_counter()-t,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'native_pins':live,'checked_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'native_build_or_proof':False,'scope':'strings, hashes, arithmetic counts, preserved sources/hypotheses; no Rust/device/PCS/receipt/privacy validation'}
(D/'audit-result.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({k:v for k,v in out.items() if k!='native_pins'}))
