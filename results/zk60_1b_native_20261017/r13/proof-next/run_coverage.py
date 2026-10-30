"""Latest-source coverage checks; each invocation retains its own evidence."""
from pathlib import Path
import importlib.util
import json
import sys

root = Path(__file__).resolve().parents[4]
spec = importlib.util.spec_from_file_location('sol_r13_runner', root / 'results/zk60_sol_20261026/r13_guard.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
binary = runner.R13 / 'working-tree/hashline/target/release/deps/hashline-9fb4e6d6ef34bc25'
checks = [
    ('s24_tests', 'the_capture_writer_pins_every_run_layer_source_it_depends_on', 'light'),
    ('s25_tests', 'every_hash_call_site_in_the_lanes_own_sources_is_classified', 'light'),
    ('hash_domain::tests', 'every_absorb_label_on_the_path_is_in_the_table', 'light'),
    ('s24_tests', 'every_registered_profile_is_covered_and_every_tagged_ones_keys_are_pairwise_distinct', 'cpu'),
    ('s24_tests', 'no_registered_profiles_constructor_input_has_the_squeeze_length', 'cpu'),
    ('s25_tests', 'every_hash_input_kind_of_every_registered_profile_is_printed_with_its_length', 'cpu'),
    ('s33_tests', 'every_registered_profile_context_and_label_is_printable_ascii_with_no_nul', 'light'),
    ('s33_tests', 'no_transcript_constructor_input_can_equal_an_absorb_input_of_the_same_length', 'light'),
    ('s25_tests', 'stage_24s_twelve_key_test_still_covers_every_tagged_profile', 'cpu'),
]
prefix = sys.argv[1]
if len(sys.argv)>2:
    binary=Path(json.loads((runner.R13/(sys.argv[2]+'.test-binary.json')).read_text())['path'])
light='--bounded-light' in sys.argv
for i, (module, test, kind) in enumerate(checks):
    label = f'{prefix}-{i}'
    # The whole prior batch took <25s, max RSS0.62GiB; with two threads each
    # leaf fits the resource protocol's light class. This is correctness work.
    if light: kind='light'
    runner.run(label, kind, .8 if light else (.35 if kind == 'light' else 1.42), 1.5 if light else (1 if kind == 'light' else 3),
               ['/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1',str(binary), '--exact', f'private_block::{module}::{test}', '--test-threads=1', '--nocapture'], seconds=300)
    assert '1 passed; 0 failed' in (runner.R13 / f'{label}.log').read_text(), 'exact gate did not execute'
