"""Freeze the completed author native gates for independent review.

This copies no target directories, assigns no security tier and activates
nothing. The additional reviewer-input chain is explicitly kept separate.
"""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,shutil

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
OUT=HERE/'review-author-1'

def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for data in iter(lambda:f.read(1<<20),b''):h.update(data)
 return h.hexdigest()

def save(path,value):path.write_text(json.dumps(value,indent=2)+'\n')

def main():
 assert not OUT.exists()
 pin_path=HERE/'sol-r14-final-build-1.source.json'
 pin=json.loads(pin_path.read_text());source=pin['tree_sha256']
 build=json.loads((HERE/'final-validation-1/ACCEPTANCE.json').read_text())
 assert build['source']==source and build['suite']['passed']==838
 assert hashlib.sha256(''.join(f'{k} {v}\n' for k,v in sorted(pin['files'].items())).encode()).hexdigest()==source
 required={
  'final-validation-1':'ACCEPTANCE.done','final-relations-1':'ACCEPTANCE.done',
  'final-arithmetic-2':'done','joint-receipts-2':'ACCEPTANCE.done',
  'joint-envelopes-1':'ACCEPTANCE.done','final-census-1':'ACCEPTANCE.done',
  'full26-native-1':'ACCEPTANCE.done','full26-captures-1':'ACCEPTANCE.done',
 }
 reports={}
 for directory,marker in required.items():
  assert (HERE/directory/marker).read_text().strip()=='0',(directory,marker)
  report=json.loads((HERE/directory/'ACCEPTANCE.json').read_text())
  assert report['source']==source,directory
  reports[directory]=report
 for name in ['native','capture']:
  worker=HERE/f'detached-full26-{name}-1'
  assert (worker/'WORKER.done').read_text().strip()=='0'
  result=json.loads((worker/'RESULT.json').read_text())
  assert result['exit']==0 and result['script_unchanged'] and result['supervisor_unchanged']
 assert len(reports['final-relations-1']['cases'])==50
 assert reports['final-relations-1']['positive_equivalent_dictionary_rows']['receipt']['expected_accept'] is True
 assert len(reports['joint-receipts-2']['cases'])==22
 assert len(reports['joint-envelopes-1']['cases'])==18
 assert len(reports['full26-native-1']['modes'])==len(reports['full26-captures-1']['modes'])==2
 count=json.loads((HERE/'FULL26_ACTUAL_CONDITIONAL_COUNT.json').read_text())
 assert count['source']==source and not count['security_tier_assigned'] and not count['privacy_accepted']
 original=HERE/'checkpoints/final-build-1/tree'
 for name,want in pin['files'].items():assert sha(original/name)==want,name
 OUT.mkdir();tree=OUT/'source-tree'
 for name,want in pin['files'].items():
  target=tree/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(original/name,target)
  assert sha(target)==want,name
 shutil.copy2(pin_path,OUT/'SOURCE.json')
 binaries={}
 for name,key in [('hashline.test.bin','test_binary_sha256'),('zk60_split_stack.bin','cli_sha256'),('zk60_trained_block.bin','legacy_cli_sha256')]:
  source_bin=HERE/'checkpoints/final-build-1'/name
  assert sha(source_bin)==build[key]
  target=OUT/'bin'/name;target.parent.mkdir(exist_ok=True);shutil.copy2(source_bin,target)
  assert sha(target)==build[key];binaries[name]=build[key]
 # The full Rust suite needs the same pinned public loader fixtures at its
 # established path two directories above Cargo.toml.
 fixtures=HERE/'loader-fixtures'
 fixture_pins={}
 for path in sorted(fixtures.rglob('*')):
  if path.is_file():
   rel=path.relative_to(fixtures);target=OUT/'loader-fixtures'/rel
   target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,target)
   fixture_pins[str(rel)]=sha(path);assert sha(target)==fixture_pins[str(rel)]
 assert len(fixture_pins)==129,len(fixture_pins)
 save(OUT/'LOADER_FIXTURES.json',fixture_pins)
 helpers=['capture_contract_v4.py','validate_capture_v4.py','native_mask_checks_v4.py','native_claim_checks_v4.py',
  'local_row_rank_v4.py','test_capture_streams_v4.py','check_capture_transport_negatives_v4_2.py',
  'generic_reference.py','final_census_checks.py','final_relation_checks.py','regression_checks_direct.py',
  'final_arithmetic_checks.py','final_arithmetic_checks_v2.py','joint_receipt_checks.py','joint_receipt_checks_v2.py',
  'joint_envelope_checks.py','full26_native_checks_v3.py','full26_capture_checks.py','full26_count.py',
  'prepare_astra_prefix.py','reference_stack_v3.py','reference_sequence_step_v3.py','detached_stage.py',Path(__file__).name]
 helper_pins={}
 for name in helpers:
  target=OUT/'tools'/name;target.parent.mkdir(exist_ok=True);shutil.copy2(HERE/name,target)
  helper_pins[name]=sha(target);assert sha(HERE/name)==helper_pins[name]
 # Retain exact evidence paths/hashes without copying multi-GiB receipts or
 # captures. Only already-terminal directories are included in this manifest.
 directories=[*required,'astra-smoke-prefix-1','capture-adapters-v4','detached-full26-native-1','detached-full26-capture-1','joint-receipts-1']
 evidence={}
 for directory in directories:
  for path in sorted((HERE/directory).rglob('*')):
   if path.is_file():evidence[str(path.relative_to(ROOT))]={'bytes':path.stat().st_size,'sha256':sha(path)}
 extra=['FULL26_ACTUAL_CONDITIONAL_COUNT.json','FINAL_SOURCE_DELTA.json','CAPTURE_TRANSPORT_NEGATIVES_v4_2.json',
  'CAPTURE_TRANSPORT_NEGATIVES_v4_FAILURE.json','REFERENCE_STACK_2_FAILURE.json',
  'JOINT_RECEIPT_WRAPPER_FAILURE_1.json','FINAL_ARITHMETIC_WRAPPER_FAILURE_1.json',
  'JOINT_ROW_MUTATION_PRECONDITIONS.json','FULL26_CAPTURE_RESOURCE_BASIS.json','TOKEN0_REAL_INPUT_PREFLIGHT.json']
 for name in extra:
  path=HERE/name;evidence[str(path.relative_to(ROOT))]={'bytes':path.stat().st_size,'sha256':sha(path)}
 save(OUT/'EVIDENCE.json',evidence)
 facts={
  'rust_suite':{'passed':838,'failed':0,'ignored':75,'baseline_outcomes_preserved':816},
  'relation_receipts':{'native_rejections':50,'positive_alias':1},
  'arithmetic_C3':{'native_rejections':16,'positive_group_contexts':4,'dense_native_receipts':2,'independent_trace_sites':19,
   'group_artifacts':'Complete native group frames verified in memory only; output omitted to avoid test-only accepted-control path collision. Other malicious frames retained.'},
  'joint_receipts':{'honest':4,'native_Merkle_rejections':16,'foreign_logical_root_sumcheck_rejections':2},
  'envelope_controls':{'honest':2,'binding_root_ownership_transport_rejections':16},
  'full26':{'variants':2,'stages_each':26,'strict_model_without_synthetic_waiver':True,'H1_bit_exact_every_layer_before_header':True,
   'fresh_public_only_verified':True,'canonical_scalar_tamper_rejected':True,'proof_bytes':[m['bytes'] for m in reports['full26-native-1']['modes']]},
  'captures':{'variants':2,'stages_each':26,'same_bytes_with_without_observer':True,'rejected_bundle_suppression':True,
   'regular_opening_views_each':79,'claimed_values_checked':[7878,8008],'exclusive_site_pairs_checked':[7852,7982],
   'stage_json_cache_max':2,'scope':'Transport, captured M budgets/functionals/order, private claim/public-gate provenance and local row-mask precheck only.'},
  'whole_count':{'native_lengths_matched':52,'conditional_backend_bits':[v['conditional_backend_bits'] for v in count['variants']],
   'security_tier_assigned':False},
 }
 pending=['Independent D24 native soundness/code review and lookup/PCS/CFS ceiling transfer',
  'Complete host-polynomial reconstruction, global H/column/joint rank, CFS lemma, NL1 and privacy acceptance',
  'O-2 commitment reuse across artifacts and adapted joint-row C-11 coverage confirmation by reviewer',
  'Token/classifier joint-endpoint integration and whole-application composition before use or registration']
 save(OUT/'AUTHOR_FREEZE.json',{'utc':datetime.now(timezone.utc).isoformat(),'schema':'r14-author-native-review/1',
  'source':source,'source_files':pin['count'],'source_tree':str(tree.relative_to(ROOT)),'binaries':binaries,
  'helpers':helper_pins,'evidence_manifest_sha256':sha(OUT/'EVIDENCE.json'),'loader_fixtures_manifest_sha256':sha(OUT/'LOADER_FIXTURES.json'),
  'facts':facts,'privacy_accepted':False,'independent_soundness_accepted':False,'profile_registered':False,'production_activated':False,
  'pending':pending,'additional_reviewer_reference':{'path':str((HERE/'reference-stack-3').relative_to(ROOT)),
   'status_at_freeze':'Still running on a different retained reviewer input; not included in the immutable evidence manifest.'},
  'reference_provenance':'Astra numerical evaluator with baseline/cache replay parity and authenticated native export equivalence. Both replay variants share arithmetic; their parity checks caching. The native H1 pass independently matched every layer output before proving.',
  'joint_attack_scope':'One root per logical ordered piece matrix. Opened-row forgeries, foreign logical-root substitutions and envelope refusals are separately classified; there are no standalone serialized piece roots.',
  'scope':'Immutable author source/binary/evidence packet for independent review. No inherited approval, security tier, privacy acceptance, classifier/app acceptance or deployment.'})
 (OUT/'AUTHOR_FREEZE.done').write_text('0\n')
 print('Author R14 native review packet frozen; independent/security/privacy gates pending',flush=True)

if __name__=='__main__':main()
