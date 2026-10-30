"""One exact guarded development proof gate, retaining nonzero test count."""
from pathlib import Path
import importlib.util
import sys

root=Path(__file__).resolve().parents[4]
spec=importlib.util.spec_from_file_location('sol_r13_runner',root/'results/zk60_sol_20261026/r13_guard.py')
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
name,which=sys.argv[1:]
tests={
    'receipts':'private_block::accuracy_proof_tests::accuracy_dense_low_and_h24_dd_and_non_dd_prove_and_verify',
    'mutation':'private_block::accuracy_proof_tests::accuracy_new_norm_high_byte_mutation_reaches_native_proof_and_is_rejected',
    'limbs':'private_block::accuracy_proof_tests::accuracy_all_new_limb_and_unused_dictionary_mutations_reach_verification',
    'tails':'private_block::accuracy_proof_tests::accuracy_every_table_support_tail_rejects_a_moved_multiplicity',
    'actual-import':'private_block::accuracy_proof_tests::accuracy_actual_shieldstral_v2_all_public_weights_and_layer_contexts_import',
    'chain':'private_block::accuracy_proof_tests::accuracy_two_stage_private_boundary_with_different_gate_shifts_verifies',
}
binary=runner.R13/'working-tree/hashline/target/release/deps/hashline-9fb4e6d6ef34bc25'
extra=[f'HL_R13_SHIELDSTRAL_EXPORT={runner.R13 / "shieldstral-export-v2"}'] if which=='actual-import' else []
runner.run(name,'cpu',2.5,4,['/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1',*extra,str(binary),
    '--exact',tests[which],'--ignored','--test-threads=1','--nocapture'],seconds=900)
assert '1 passed; 0 failed' in (runner.R13/f'{name}.log').read_text(),'exact proof gate did not execute'
