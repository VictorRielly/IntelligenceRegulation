"""Integrate the terminal extra reference without changing the author freeze."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
OUT=HERE/'AUTHOR_REFERENCE_SUPPLEMENT.json'

def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for data in iter(lambda:f.read(1<<20),b''):h.update(data)
 return h.hexdigest()

def main():
 assert not OUT.exists()
 ref=HERE/'reference-stack-3'
 assert (ref/'ACCEPTANCE.done').read_text().strip()=='0'
 acceptance=json.loads((ref/'ACCEPTANCE.json').read_text())
 assert len(acceptance['layers'])==26 and acceptance['native_full_stack_proved'] is False
 manifest=json.loads((ref/'manifest.json').read_text())
 assert sha(ref/'manifest.json')==acceptance['manifest_sha256'] and len(manifest['arrays'])==52
 evidence={}
 for path in sorted(ref.iterdir()):
  if path.is_file():evidence[str(path.relative_to(ROOT))]={'bytes':path.stat().st_size,'sha256':sha(path)}
 previous=None;traces=[]
 for k,row in enumerate(acceptance['layers']):
  assert row['layer']==k and row['guard']['exit']==row['guard']['child_rc']==0 and not row['guard']['guard_killed']
  report=ref/f'layer_{k:02}.json';value=json.loads(report.read_text())
  assert sha(report)==row['report_sha256'] and value['profile_sha256']=='2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0'
  assert len(value['traces'])==len({site['site'] for site in value['traces']})==19
  assert value['reference_sha256']=='d7c175e154cef761e7e574e417c6979634e05243e6abf0357fb3cb2c7cdfe4ac'
  if previous:assert previous['output_sha256']==value['input_sha256']
  for kind in ['in','out']:
   info=manifest['arrays'][f'x_{kind}_L{k:02}'];path=ref/info['file']
   assert info['dtype']=='int16' and info['shape']==[128,3072] and path.stat().st_size==128*3072*2
   assert sha(path)==info['sha256']
  traces.append({'layer':k,'report_sha256':sha(report),'sites':19,'input_sha256':value['input_sha256'],'output_sha256':value['output_sha256']})
  previous=value
 frozen=HERE/'review-author-1/AUTHOR_FREEZE.json';freeze=json.loads(frozen.read_text())
 pin=json.loads((HERE/'review-author-1/SOURCE.json').read_text())
 assert pin['tree_sha256']==freeze['source']
 for name,want in pin['files'].items():assert sha(HERE/'review-author-1/source-tree'/name)==want,name
 assert sha(HERE/'review-author-1/EVIDENCE.json')==freeze['evidence_manifest_sha256']
 for name,want in freeze['binaries'].items():assert sha(HERE/'review-author-1/bin'/name)==want
 for mode in ['native','capture']:
  assert (HERE/f'detached-full26-{mode}-1/WORKER.done').read_text().strip()=='0'
 supplement={'utc':datetime.now(timezone.utc).isoformat(),'schema':'r14-extra-reference-supplement/1',
  'author_freeze_sha256':sha(frozen),'source':freeze['source'],'reference_profile_sha256':'2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0',
  'layers':traces,'trace_sites_each':19,'trace_hashes_total':494,'source_math':'Unchanged independent reviewer exact-int64 block arithmetic; authenticated read-only int8 weight mappings with int64 promotion and trace dtype assertions.',
  'input_relation_to_native_proof':'Different retained numerical input from the Astra evaluation fixture used for native proving. This additional chain is not itself a new native proof.',
  'evidence':evidence,'script_sha256':sha(Path(__file__)),'privacy_accepted':False,'independent_soundness_accepted':False,
  'scope':'All26 extra exact-integer reference layers pass every original range check;52 arrays link exactly and494 trace hashes retained. The immutable author packet is unchanged. Independent D24/privacy/full-app gates remain open.'}
 OUT.write_text(json.dumps(supplement,indent=2)+'\n')
 (HERE/'AUTHOR_REFERENCE_SUPPLEMENT.done').write_text('0\n')
 print('Additional exact reference PASS26/494trace hashes; immutable author source/binaries intact',flush=True)

if __name__=='__main__':main()
