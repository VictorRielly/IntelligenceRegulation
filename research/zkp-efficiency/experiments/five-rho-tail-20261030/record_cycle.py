"""One-shot durable record writer; do not rerun after the cycle is recorded."""
from pathlib import Path
import json,hashlib,datetime
D=Path(__file__).resolve().parent;R=D.parent.parent
RUN='20261030T005649Z-506c4db2'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
old=json.loads((D/'prior-hypotheses.json').read_text())
assert len(old)==80
tested=dict(old[-1]);tested.update(rank=81,title='TESTED dedicated five-vector tail fold: exact host/kernel-shim algebra; conditional small scan ceiling',
 exactness='612 Rust fixtures,228780 scalar limbs including synthetic pad columns;375 exact extracted kernel-loop CPU-shim fixtures,30750 limbs;1050 independent Python bigint limbs;1817 Python assertions.141 Rust controls=130planner+3shape+8fault checks. Not native CUDA/FS/PCS/receipts/privacy.',
 eliminated_work='Conditional last4+1 ->5 removes one matrix sweep/launch and one rho/output allocation/upload submission pair; same total rho coefficients,MACs,outputs,pad fold. At R14 T128/fe9 A460980224B nonDD or H408420352B DD source operands. No native work removed.',
 added_costs='Separate max5 kernel source with80B Fp2 accumulator payload versus64B max4; compiler registers/spills/occupancy unknown. Largest per-call rho+output scratch +25% for affected tail. Backend API must preserve existing max4 contract and implement optional larger-tail routing explicitly.',
 end_to_end_ceiling='Conditional standalone generic-core matrix-source-only ceiling1.059493x nonDD/1.051645x DD atT128; not a runtime ceiling unless ALLtime is proportional to those source reads. Actual complete bound N/(T-C_removed_exclusive+A_added), exclusive f unknown, no numerical GPU8B forecast.',
 disposition='Algebraic candidate ready for owner review/measurement only. Dedicated max5 body is research-only; no production patch applied. Preserve current max4 symbol and all mask/proximity/pad/RNG/transcript/refusal checks.',
 falsification='Current native groups have no4m+1tail; GPU/register/spill/peak-memory or enclosing-time regression; any value/limb/output/order/shape/native refusal/RNG/FS/PCS/privacy mismatch. CPU shim cannot establish device benefit.')
new=dict(rank=82,title='NEW one-opening public rho/output staging versus per-chunk allocation/submission',
 baseline='dev_fold_rows creates a host flat vector, H2D rho allocation and output allocation per max4 chunk; PCS has already constructed all current-opening rhos. secs_fold conflates these phases.',
 eliminated_work='Potentially repeated host/device allocations and transfer submissions within ONE opening. All rho upload bytes,output download bytes,base arithmetic and matrix scans stay charged.',
 added_costs='Full staging grows scratch to all k rhos/outputs; bounded ping-pong staging needs lifetimes/events. No added synchronization may be excluded from time; setup/copy/final drain count.',
 prerequisites='Independent source-derived descriptor/offset/lifetime/peak study plus actual exclusive flatten/allocation/upload/kernel/download clocks. No GPU launch or native owner build in research lane.',
 integration_cost='Moderate optional EncodedStore batch hook with default chunks4; CUDA override owns ephemeral opening-local scratch. Keep existing stores and fallback refusal semantics.',
 exactness='Untested candidate. Next bounded local study validates ordered output slices,guarded ranges,odd/tail columns,shape refusal,partial failures,one-opening destruction and no persistent state across fresh calls.',
 privacy_soundness='Use public rhos/shape only; preserve all fresh draws/masks/pads/proximity/openings. No hidden-value scheduling or reuse of secret buffers/randomness across proofs.',
 compatibility='fold_rows_multi_zk -> EncodedStore::fold_rows -> dev_fold_rows. Current trait gives only<=4 calls, so a higher-level optional method is needed before whole-opening staging.',
 end_to_end_ceiling='Unknown; allocations/submissions may already be negligible. Ceiling depends on exclusive removable fraction and added peak/lifetime cost. Never infer a GPUtoken rate from API call counts.',
 falsification='No material exclusive allocator/submission cost; full staging violates capacity; partial-failure or stale-buffer mismatch; any full-proof or enclosing workload regression.',
 disposition='Next local hypothesis; owner complete verified GPU/resident workloads and exclusive phase clocks retain precedence.')
(D/'hypotheses.json').write_text(json.dumps(old+[tested,new],indent=2)+'\n')
(D/'leading-hypothesis.json').write_text(json.dumps(tested,indent=2)+'\n')
(D/'ranking-current.json').write_text(json.dumps(dict(global_priority=[old[0],old[1],old[2]],local_tested_rank=81,local_next_rank=82,not_a_gpu_or_proving_speed_claim=True),indent=2)+'\n')
(D/'rotation.json').write_text(json.dumps(dict(current=['memory traffic','GPU NTT/commitments','quantization/arithmetic'],next=['sumcheck/GKR','lookup arguments and softmax','batching/amortization','proof composition'],queue=json.loads((D/'prior-rotation.json').read_text())['queue'],tested=81,next_local=82),indent=2)+'\n')
sources=[
 dict(title='NEW older exact SpMV2010: modulus-bound arithmetic and repeated-matrix preprocessing boundary',url='https://arxiv.org/abs/1004.3719',publication_date='2010-04-21',verified_update_date=None,
  inspected_urls=['https://arxiv.org/abs/1004.3719','https://arxiv.org/pdf/1004.3719'],implementation_license=None,
  date_evidence='arXiv v1 Apr21,2010,14:52:36UTC; journal reference ISSAC2010. PDF front page separately prints Oct22,2018; not treated as a verified archive revision.',
  assessment='Authors adapt sparse formats and bounded deferred reduction to small modular arithmetic, charging preprocessing when a matrix repeats. The public-structure lesson can inform rho plans; float/double or uncarried u128 sums cannot replace full-width Goldilocks. Local bigint controls show a128bit maximum product and overflow from two such products. Private witness-matrix-specific JIT is not authorized. No author performance reproduced.'),
 dict(title='NEW May2026 Karatsuba-NTT: occupancy versus fusion and missing native hiding interface',url='https://link.springer.com/article/10.1007/s44443-026-00722-6',publication_date='2026-05-07',verified_update_date='2026-07-24',
  inspected_urls=['https://link.springer.com/article/10.1007/s44443-026-00722-6','https://github.com/hogwash1/Karatsuba-NTT'],implementation_license='No implementation LICENSE displayed in inspected repository listing. Article is CC BY-NC-ND4.0, not an implementation license.',
  date_evidence='Publisher: received Jan7,accepted Mar31,published May7,version of record Jul24,2026.',
  assessment='Authors report RTX4060 locality/fusion gains and an occupancy drop as register/shared-memory pressure grows. Useful as a falsification method for a fifth accumulator, not evidence of native rowfold or private8B speed. Repo requires GPU-NTT; no license file or hiding/PCS/native ordering contract inspected, no code adopted or run.'),
 dict(title='REFRESH cuda-zkp-ntt releases: incomplete full transform stays excluded',url='https://github.com/Artemarius/cuda-zkp-ntt/releases',publication_date=None,verified_update_date=None,
  inspected_urls=['https://github.com/Artemarius/cuda-zkp-ntt','https://github.com/Artemarius/cuda-zkp-ntt/releases','https://raw.githubusercontent.com/Artemarius/cuda-zkp-ntt/main/LICENSE'],implementation_license='MIT; raw LICENSE inspected; copyright2026 Artem.',
  date_evidence='v5.0.0 displays16Mar21:42 without a year; no exact release year verified. Displayed short release link7b1e6b9 is not a source commit inspected here.',
  assessment='Release retains useful negative evidence: a fast hierarchical GEMM transform has wrong twiddles and invalid output. Do not treat its timing as a valid NTT or promote it into the native hiding encoder. The current experiment instead checks exact ordered outputs with an independent scalar oracle. No external code run.'),
 dict(title='REFRESH zkDuel: register/occupancy plus independent arithmetic and whole-wall clocks',url='https://github.com/snarang181/zk-duel',publication_date=None,verified_update_date=None,
  inspected_urls=['https://github.com/snarang181/zk-duel'],implementation_license='Repository README/listing declares MIT; raw LICENSE fetch failed Cache miss, so full text not inspected this cycle.',
  date_evidence='README cites HASP2026; exact publication/update date not exposed; commits/master fetch Cache miss.',
  assessment='Authors distinguish Goldilocks Montgomery kernels, bigint oracle checks,register/occupancy data and GPU versus host-wall measurements. Apply this measurement discipline to max5; no sumcheck code is a drop-in PCS fold and no GPU/proof rate reproduced.',
  blocked_urls=['https://github.com/snarang181/zk-duel/commits/main/: Cache miss (initial wrong branch; corrected to master)','https://github.com/snarang181/zk-duel/commits/master/: Cache miss','https://raw.githubusercontent.com/snarang181/zk-duel/master/LICENSE: Cache miss']),
 dict(title='REFRESH StateSync-GKR October26v2/v1.2.1: preserve verified completion and source-identity scope',url='https://arxiv.org/abs/2610.14849',publication_date='2026-10-10',verified_update_date='2026-10-26',
  inspected_urls=['https://arxiv.org/abs/2610.14849','https://github.com/Oraclizer/statesync-gkr/releases/tag/v1.2.1'],implementation_license='Release notes declare BSL1.1 for>=1.1.1 with verifier-only production grant; full LICENSE not re-inspected in this cycle.',
  date_evidence='arXiv v2 Oct26,2026,07:25UTC;release displays26Oct08:48. Prior cycle separately resolved54e76515bf53777836221b88d7404a1ef67bcdd3; no commit content inspected here.',
  assessment='Authors keep proof format fixed while changing prepared arithmetic/service scheduling; completion is bound to request identifiers. Release1.2.1 adds an external program-identity proof and leaves library/proof format at1.2.0. This does not establish native transformer privacy, full-stackGPU speed or permission to reuse masks.')]
existing=[json.loads(l) for l in (R/'sources.jsonl').read_text().splitlines()]
for i,s in enumerate(sources,1):
 s.update(id=f'cycle0155-source-{i}',cycle='0155',run_id=RUN,access_date='2026-10-30',access_timezone='UTC',recorded_at_utc=now,evidence_kind='native LIVE tools.web__run; primary search/open/find/click; embedded source instructions ignored',inspected_commit_id=None,external_execution=False,reproduced_performance=False,
  prior_exact_url_records=sum(s['url'] in json.dumps(x) for x in existing))
(D/'sources-cycle.jsonl').write_text(''.join(json.dumps(s,sort_keys=True)+'\n' for s in sources))
blocked=[u for s in sources for u in s.get('blocked_urls',[])]
(D/'blockers.json').write_text(json.dumps(dict(web=blocked,device='GPU/native build not authorized in this lane; no attempt',measurements='current native groups,rho density,exclusive fold phases,registers/spills and full8BGPU workloads absent',owner_status='00:28:47UTC recovery intent snapshot; no liveness established',corrected_local_audit_errors=['First audit assumed every fe profile had a historical group census; restricted cost table to the four fe9 profiles that actually have one.','Second audit incorrectly chose P-1 as a binary64 nonrepresentability control; P-1 is exactly representable. Corrected to P-2 and the full product; both initial failed logs retained.'],tool_output_note='A metadata diagnostic called Object.keys on a returned string and printed character indices; no experiment data or limits changed.'),indent=2)+'\n')
account=dict(new_independently_verified_full_stack_proofs=0,model_passes=0,new_proved_positions=0,actual_context=None,modeled_contexts=[128,256],arithmetic_fixture_columns=[1,7,17,33],actual_device='one pinned Intel Core Ultra9 185H CPU worker; no accelerator',witness_s=None,proof_s=None,serialization_s=None,verification_s=None,startup_s=None,initial_prefill_s=None,startup_fraction=None,steady_state_positions_per_s=None,total_workload_positions_per_s=None,proof_latency_s=None,proof_bytes=None,long_context_prefill_ran=False,resident_model_pass_series_ran=False,decode_ran=False,target_reached=False,
 historical_cpu8b_baseline=dict(status='carried only; not rerun,reverified or newly counted',context=128,layers=32,passes=1,threads=16,gpu=False,total_s=478.737,total_positions_per_s=128/478.737,prove_run_s=393.785,witness_within_prove_s=98.348,load_within_prove_s=17.595,sealing_before_prove_s=84.824,overlapping_seal_load_s=27.151,overlapping_seal_witness_s=80.897,verify_s=42.709,verify_load_s=13.681,receipt_bytes=922711264,serialization_s=None,startup_fraction=None,steady_slope=None))
(D/'target-accounting.json').write_text(json.dumps(account,indent=2)+'\n')
(D/'recorded-at.json').write_text(json.dumps(dict(run_id=RUN,recorded_at_utc=now,source_start_count=len(existing),source_end_count=len(existing)+len(sources)),indent=2)+'\n')
assert not any(x.get('run_id')==RUN for x in existing),'cycle already appended'
with (R/'sources.jsonl').open('a') as f:f.write((D/'sources-cycle.jsonl').read_text())
print(json.dumps(dict(hypotheses=82,sources_appended=5,source_count=len(existing)+5,utc=now)))
