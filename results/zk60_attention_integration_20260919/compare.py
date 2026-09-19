import pathlib, subprocess, os, json, time, re, hashlib, statistics
root=pathlib.Path(__file__).parent
bins={'baseline':root/'baseline-binary', 'candidate':pathlib.Path('/home/victor/IntelligenceRegulation/hashline/target/release/examples/zk60_private_attention')}
env={**os.environ,'RAYON_NUM_THREADS':'2','HL_GPU':'0'}
rows=[]
for i in range(11):
 for name in (['baseline','candidate'] if i%2==0 else ['candidate','baseline']):
  out=root/(name+'-comparison')
  t=time.perf_counter()
  r=subprocess.run([str(bins[name]),'prove',str(out)],env=env,capture_output=True,text=True)
  wall=time.perf_counter()-t
  if r.returncode: raise RuntimeError(r.stdout+r.stderr)
  core=float(re.search(r'^prove ([0-9.]+) s',r.stdout,re.M)[1])
  phases={n:float(s) for n,s in re.findall(r'^  (.+): ([0-9.]+) s$',r.stdout,re.M)}
  # Every saved receipt is checked in a fresh process by the OTHER binary.
  other='candidate' if name=='baseline' else 'baseline'
  v=subprocess.run([str(bins[other]),'verify',str(out)],env=env,capture_output=True,text=True)
  if v.returncode or 'ACCEPT:' not in v.stdout or v.stdout.count('refused:')!=3: raise RuntimeError(v.stdout+v.stderr)
  row={'sample':i,'warm':i>0,'implementation':name,'process_wall_seconds':wall,'prove_core_seconds':core,'phase_seconds':phases,'prove_exit':r.returncode,'verify_exit':v.returncode,'verifier_implementation':other,'rejection_controls':3,'receipt_bytes':(out/'attention_receipt.bin').stat().st_size,'receipt_sha256':hashlib.sha256((out/'attention_receipt.bin').read_bytes()).hexdigest()}
  rows.append(row)
  (root/(name+'-comparison-prove.log')).write_text(r.stdout+r.stderr)
  (root/(name+'-comparison-verify.log')).write_text(v.stdout+v.stderr)
summary={name:{'median_prove_core_seconds':statistics.median(r['prove_core_seconds'] for r in rows if r['implementation']==name and r['warm']),'median_process_wall_seconds':statistics.median(r['process_wall_seconds'] for r in rows if r['implementation']==name and r['warm'])} for name in bins}
record={'scope':'tiny attention component only; P1 experimental; CPU diagnostic; no privacy or model-scale acceptance','hardware':'Intel Core Ultra 9 185H','rayon_threads':2,'gpu_enabled':False,'quiesced':False,'warm_samples_per_implementation':10,'headline_eligible':False,'source':json.loads((root/'source.json').read_text()),'binary_sha256':{n:hashlib.sha256(b.read_bytes()).hexdigest() for n,b in bins.items()},'summary':summary,'runs':rows}
(root/'comparison.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(summary,indent=2))
