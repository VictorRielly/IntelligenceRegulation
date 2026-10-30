from pathlib import Path
import json,difflib
H=Path(__file__).resolve().parent
old=(H/'consumers/zkp-core__src__mle.rs').read_text()
new=old.replace('        let one_minus = Fp2::ONE.sub(ri);\n','',1)
needle='                *b = e.mul(ri);\n                *a = e.mul(one_minus);'
assert new.count(needle)==2
new=new.replace(needle,'                let product = e.mul(ri);\n                *b = product;\n                *a = e.sub(product);')
(H/'native-eq-doubling.patch').write_text(''.join(difflib.unified_diff(old.splitlines(keepends=True),new.splitlines(keepends=True),fromfile='a/zkp-core/src/mle.rs',tofile='b/zkp-core/src/mle.rs')))
(H/'candidate-native-mle.rs').write_text(new)
prior=json.loads((H/'startup/prior-hypotheses.json').read_text())
assert len(prior)==61
lead=dict(rank=62,title='NEW TESTED same-basis fresh Eq complement doubling; fixed Eq tiny, mask Eq more material but unclocked',
 baseline='Canonical frozen R13 core Eq builder uses two Fp2 products/node and one 1-r subtraction/dimension. 8B T128 fixed Eq has2165nodes/block; mask_eval Eq2878263..2997039nodes/block. No exclusive native Eq clock.',
 eliminated_work='One Fp2 multiplication per doubling node, replacing e*(1-r) with e-(e*r). Native source Fp2::mul has five base mul and two adds; compiler may specialize constants. No allocations, private reads, mask draws, commitments, openings or attention work removed.',
 added_costs='One Fp2 subtraction/node, replacing per-dimension complement subtractions; net nodes-log subtractions per table. Same one-read/two-store dataflow, initialization and reverse-copy allocations. Native scheduling/compiler effects unmeasured.',
 prerequisites='Native Rayon branch/source integration review, unchanged-byte receipts/refusals/transcript and current privacy gates; exclusive Eq/dot/mask extension and enclosing clocks before performance promotion; owner shared locks for native work.',
 expected_end_to_end_impact='Unknown. Serial helper diagnostic1.257..1.744x for nonempty tested sizes is not a native/GPU ratio. For exclusive affected fraction f and actual native phase ratio k, whole speedup1/((1-f)+f/k); no f/k measured. Fixed Eq-only lane demoted.',
 integration_cost='Small two-loop arithmetic patch in zkp-core/src/mle.rs. Research patch preserves threshold,Rayon,MSB wrapper and empty behavior; actual Cargo/native build not run.',
 exactness='234Eq fixtures/2691054entries/14094direct weights/198independent MLE folds;600priv_table and600fresh mask cases vs native extract and independent schoolbook-u128 literal/fold references;8controls. Same researcher,not external review.',
 privacy_soundness='Pure exact all-field algebra with unchanged challenge law,representation,draw/order and no cache. Keep every fresh CFS/reserved pair; no privacy acceptance inherited or newly claimed.',
 compatibility='Frozen R13 hashline mle adapter reexports ../zkp-core by pinned Cargo path; actual frozen field/mle match prior adapters byte-for-byte. PCS row/column and other Eq consumers exist; complete incidence uncounted.',
 falsification='Any all-field/order/empty/mask/MLE/native refusal/transcript/receipt mismatch; changed accepted domain/randomness; no exclusive phase share; native compiler already removes work or added subtraction/scheduling cost erases enclosing improvement.',
 status='Bounded correctness and serial helper improvement; conditional native review/profiling handoff, no integration or native speed result')
(H/'hypotheses.json').write_text(json.dumps(prior+[lead],indent=2)+'\n');(H/'leading-hypothesis.json').write_text(json.dumps(lead,indent=2)+'\n')
ranking=json.loads((H/'startup/prior-cycle-ranking.json').read_text())
ranking['cycle']='0145';ranking['local_tested_hypothesis_rank']=62;ranking['local_result']='Eq exact; fixed incidence tiny; mask incidence larger, native clocks unknown; whole-prover priorities unchanged'
(H/'cycle-ranking.json').write_text(json.dumps(ranking,indent=2)+'\n')
(H/'rotation.json').write_text(json.dumps(dict(cycle='0145',tested='quantization/arithmetic: all-field fresh Eq complement doubling and incidence',next='proof composition: audit actual R13 group_zclaims/n_groups_zk/open_zk call graph for repeated same-call public Eq preparation; distinguish fresh masks and prior tail-cache work; prefer new exclusive native clocks if available',queue=['GPU NTT/commitments','sumcheck/GKR','lookup arguments and softmax','memory traffic','batching/amortization','quantization/arithmetic','proof composition']),indent=2)+'\n')
print('61 prior hypotheses preserved;62 added; conditional patch saved, not applied')
