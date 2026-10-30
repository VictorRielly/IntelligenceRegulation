"""Coverage gates for the installed metadata step, with exact-test counts."""
from pathlib import Path
import importlib.util
import sys

root=Path(__file__).resolve().parents[4]
spec=importlib.util.spec_from_file_location('sol_r13_runner',root/'results/zk60_sol_20261026/r13_guard.py')
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
binary=runner.R13/'working-tree/hashline/target/release/deps/hashline-9fb4e6d6ef34bc25'
names=[
    ('light','private_block::s24_tests::the_capture_writer_pins_every_run_layer_source_it_depends_on'),
    ('light','private_block::s25_tests::every_hash_call_site_in_the_lanes_own_sources_is_classified'),
    ('light','private_block::hash_domain::tests::every_absorb_label_on_the_path_is_in_the_table'),
    ('cpu','private_block::s24_tests::every_registered_profile_is_covered_and_every_tagged_ones_keys_are_pairwise_distinct'),
    ('cpu','private_block::s24_tests::no_registered_profiles_constructor_input_has_the_squeeze_length'),
    ('cpu','private_block::s25_tests::every_hash_input_kind_of_every_registered_profile_is_printed_with_its_length'),
]
for i,(kind,name) in enumerate(names):
    if len(sys.argv)>1 and i!=int(sys.argv[1]):continue
    label=f'metadata-gate-{i}'
    runner.run(label,kind,.35 if kind=='light' else 1.42,1 if kind=='light' else 3,
        [str(binary),'--exact',name,'--test-threads=1','--nocapture'],seconds=300)
    assert '1 passed; 0 failed' in (runner.R13/f'{label}.log').read_text(),'exact gate did not execute'
