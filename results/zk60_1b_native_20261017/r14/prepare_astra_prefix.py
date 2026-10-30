"""Authenticate and reuse Astra's completed26layer numerical smoke chain.

Read-only owner artifacts. Extract only an admitted T128 causal prefix of
the retained367token item, never raw text. Native H1 parity remains required.
"""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json
import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
ASTRA=ROOT/'results/zk60_shieldstral_export_20261026'
EXPORT=ASTRA/'native_low_h24_t128'
OLD=ROOT/'results/zk60_1b_native_20261017/r13/shieldstral-export-v2'
OUT=HERE/'astra-smoke-prefix-1'

def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for chunk in iter(lambda:f.read(1<<20),b''):h.update(chunk)
 return h.hexdigest()

def save(path,value):path.write_text(json.dumps(value,indent=2)+'\n')

def main():
 assert not OUT.exists()
 pins={}
 def read(path):
  pins[str(path.relative_to(ROOT))]=sha(path)
  return json.loads(path.read_text())
 profile=read(EXPORT/'profile.json')
 assert sha(EXPORT/'profile.json')=='2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0'
 equivalence=read(ASTRA/'native_export_equivalence.json')
 assert equivalence['all_payload_bytes_verified'] is True
 assert sha(OLD/'profile.json')==equivalence['profile_sha256']=='1d50078243f13d58afa814a55c47c2df797e494d7f045941ea82fa142740498a'
 old_profile=read(OLD/'profile.json')
 parity=read(ASTRA/'cache_parity.json')
 assert parity['bit_identical'] is True and parity['layers']==26 and parity['items']==8
 plans=[]
 roots=[ASTRA/'fidelity_smoke8_fix1',ASTRA/'fidelity_smoke8_cached']
 for root,key in zip(roots,['baseline_run_sha256','cached_run_sha256']):
  done=read(root/'complete.json');plan=read(root/'run.json')
  assert sha(root/'run.json')==done['run_sha256']==parity[key]
  assert done['stack_refused']==0 and done['items']==8
  assert plan['evaluation_export_sha256']==equivalence['evaluation_export_sha256']
  assert plan['layer25_calibration_candidate']==equivalence['layer25_candidate']
  plans.append(plan)
 assert plans[0]['indexes']==plans[1]['indexes']==list(range(8))
 data_path=ASTRA/'evaluation_inputs/input.json';data=read(data_path)
 assert sha(data_path)==plans[0]['input_sha256']==plans[1]['input_sha256']
 lengths=[data['rows'][i]['T'] for i in plans[0]['indexes']]
 assert lengths==[119,93,79,90,367,88,109,83]
 item=4;start=sum(lengths[:item])*3072*2;size=128*3072*2
 prefixes=[];stages=[]
 for name in ['input']+[f'layer_{i:02}' for i in range(26)]:
  ready0=None
  for root in roots:
   ready=read(root/name/'ready.json')
   assert ready==parity['stages'][name]
   for file,key in [('residual.bin','residual_sha256'),('journal.jsonl','journal_sha256')]:
    path=root/name/file;assert sha(path)==ready[key];pins[str(path.relative_to(ROOT))]=ready[key]
   for line in (root/name/'journal.jsonl').read_text().splitlines():
    entry=json.loads(line)
    assert all(not d['refused'] and not d['violations'] for d in entry['diagnostics'])
   if ready0 is None:ready0=ready
   else:assert ready==ready0
  with (roots[0]/name/'residual.bin').open('rb') as f:
   f.seek(start);prefix=f.read(size)
  assert len(prefix)==size
  prefixes.append(prefix);stages.append({'name':name,'ready':ready0,'prefix_sha256':hashlib.sha256(prefix).hexdigest()})
 # Reauthenticate every native public array and the exact model conversion.
 for k,row in enumerate(profile['layers']):
  path=EXPORT/row['dir']/'manifest.json';assert sha(path)==row['manifest_sha256']
  current=read(path);prior_row=old_profile['layers'][k]
  old_path=OLD/prior_row['dir']/'manifest.json';assert sha(old_path)==prior_row['manifest_sha256']
  previous=read(old_path);eq=equivalence['layers'][k]
  assert eq['layer']==k and eq['manifest_sha256']==sha(old_path) and eq['constants_match'] is True
  assert current['constants']==previous['constants']
  for name,array in current['arrays'].items():
   payload=path.parent/array['file'];assert sha(payload)==array['sha256'];pins[str(payload.relative_to(ROOT))]=array['sha256']
   assert previous['arrays'][name]['sha256']==eq['arrays'][name]
   if name in ['rope_cos','rope_sin']:
    original=old_path.parent/previous['arrays'][name]['file'];assert sha(original)==eq['arrays'][name]
    assert payload.read_bytes()==original.read_bytes()[:payload.stat().st_size]
   else:assert array['sha256']==eq['arrays'][name]
 OUT.mkdir();arrays={};layers=[]
 for k in range(26):
  for kind,raw in [('in',prefixes[k]),('out',prefixes[k+1])]:
   name=f'x_{kind}_L{k:02}';path=OUT/(name+'.bin');path.write_bytes(raw)
   arrays[name]={'file':path.name,'dtype':'int16','shape':[128,3072],'sha256':sha(path)}
  layers.append({'layer':k,'input_sha256':arrays[f'x_in_L{k:02}']['sha256'],'output_sha256':arrays[f'x_out_L{k:02}']['sha256']})
 save(OUT/'manifest.json',{'arrays':arrays})
 save(OUT/'ACCEPTANCE.json',{'utc':datetime.now(timezone.utc).isoformat(),'layers':layers,'manifest_sha256':sha(OUT/'manifest.json'),
  'native_full_stack_proved':False,'privacy_accepted':False,'source_sha256':pins,'script_sha256':sha(Path(__file__)),
  'provenance':{'owner':'Astra','items_checked':8,'selected_item_position':item,'original_tokens':367,'prefix_tokens':128,'stages':stages},
  'scope':'Authenticated complete26layer numerical evaluator residuals, independently reproduced byte-for-byte by Astra baseline/cache implementations. Exact S2 native weight/calibration conversion and T128 RoPE prefix checked. Causal attention plus token-local norm/FFN/residual imply the same first128 activations. Native H1 parity/proof/fresh verification still required; separate reviewer exact-int64 chain remains additional validation, no classifier/privacy acceptance.'})
 (OUT/'ACCEPTANCE.done').write_text('0\n')
 print('Astra full26 numerical reference prefix authenticated; native parity still required',flush=True)

if __name__=='__main__':main()
