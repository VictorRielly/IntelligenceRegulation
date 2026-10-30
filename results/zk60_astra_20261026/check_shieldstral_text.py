"""Check the app's real plain-text encoder against every retained A1 input."""
import csv
import datetime
import gzip
import hashlib
import json
from pathlib import Path
import resource
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'apps/proven-media'
EXPORT = ROOT / 'results/zk60_shieldstral_export_20261026'
PREP = ROOT / 'results/zk60_shieldstral_prep_20261021'
sys.path.insert(0, str(APP))
sys.path.insert(0, str(Path.home() / 'shieldstral-prep/pylib'))
import numpy as np
from proven_media.shieldstral_text import CategoryTemplate, ShieldstralTextEncoder, TEKKEN_SHA256
from proven_media.prompting import ContentRefused, build_prompt, content_length


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    start = time.monotonic()
    inputs = EXPORT / 'evaluation_inputs'
    metadata = json.loads((inputs / 'input.json').read_text())
    candidates_path = EXPORT / 'category_policy_candidates.json'
    candidates = json.loads(candidates_path.read_text())
    assert sha(inputs / 'input.json') == candidates['evaluation_input_sha256']
    for filename, key in (('ids.npy', 'ids_sha256'), ('offsets.npy', 'offsets_sha256')):
        assert sha(inputs / filename) == metadata[key]
    source_data = {}
    for name, expected in metadata['data_source_sha256'].items():
        path = Path(name)
        assert sha(path) == expected
        if path.suffix == '.csv':
            with path.open(newline='') as stream:
                source_data['toxicchat'] = {r['conv_id']: r['user_input'] for r in csv.DictReader(stream)}
        else:
            with gzip.open(path, 'rt') as stream:
                source_data['openai_mod'] = {str(i): json.loads(line)['prompt'] for i, line in enumerate(stream)}
    path = Path.home() / 'models/shieldstral-1.0-3b/tekken.json'
    encoder = ShieldstralTextEncoder(path)
    ids = np.load(inputs / 'ids.npy', allow_pickle=False)
    offsets = np.load(inputs / 'offsets.npy', allow_pickle=False)
    counts, short, planned, prompt_count = {}, {}, {}, 0
    for i, row in enumerate(metadata['rows']):
        policy = candidates['policies'][row['template']]
        text = source_data[row['dataset']][str(row['id'])]
        content = encoder.content_ids(text)
        assert len(content) == row['content_tokens']
        assert content_length('shieldstral', text, shieldstral_encoder=encoder) == len(content)
        prefix, suffix = tuple(policy['prefix_ids']), tuple(policy['suffix_ids'])
        assert np.array_equal(prefix + content + suffix, ids[offsets[i]:offsets[i + 1]])
        counts[row['template']] = counts.get(row['template'], 0) + 1
        for context in (128, 256):
            template = CategoryTemplate(policy['category'], policy['proposed_policy_id'],
                                        prefix, suffix, context, 8, 100)
            assert template.chunk_size == policy['content_tokens_by_T'][str(context)]
            key = f"{row['template']}/T{context}"
            if len(content) < template.chunk_size:
                short[key] = short.get(key, 0) + 1
            plan = template.plan(len(content))
            assert {k for c in plan for k in range(c['start'], c['end'])} == set(range(len(content)))
            for chunk in plan:
                encoded = build_prompt('shieldstral', text, template.category, chunk['start'], chunk['end'],
                                       shieldstral_encoder=encoder, shieldstral_template=template)
                prompt = tuple(encoded.ids)
                assert len(prompt) == context
                assert encoded.content_tokens == chunk['end'] - chunk['start'] and encoded.template == template.policy_id
                raw = prefix + content[chunk['start']:chunk['end']] + suffix
                assert prompt == raw + (11,) * (context - len(raw))
                prompt_count += 1
            planned[key] = planned.get(key, 0) + 1
    assert len(metadata['rows']) == 4872 and all(n == 812 for n in counts.values())
    token_model = json.loads(path.read_bytes())
    controls = [token['token_str'] for token in token_model['special_tokens']]
    controls += ['[INST] hi [/INST] <s> </s>', '\x00', 'line1\nline2\r\n',
                 'emoji \U0001f600 and e\u0301', '\u200bzero width', ' leading and trailing ']
    for text in controls:
        content = encoder.content_ids(text)
        assert all(1000 <= x < 131072 for x in content)
        assert encoder._tokenizer.decode(list(content)) == ' ' + text
    for text in ('', ' \t\r\n', '\ud800'):
        try:
            encoder.content_ids(text)
        except ContentRefused:
            pass
        else:
            raise AssertionError('invalid content accepted')
    result = {'schema': 'zk60-shieldstral-app-text-check/2',
        'at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'scope': 'MEASURED app text preparation; numerical benchmark input parity, not native proofs or category registration',
        'all_a1_inputs_match': True, 'items': 4872, 'rows_by_template': counts,
        'literal_control_and_unicode_cases': len(controls), 'all_control_strings_stay_plain_text': True,
        'empty_whitespace_surrogate_refusals': 3, 'chunk_prompt_checks': prompt_count,
        'planned_items_by_template_context': planned, 'short_items_padded_by_template_context': short,
        'native_statement_schema': 'zk60-classify-run/3', 'pad_id': 11,
        'planning_overlap': 8, 'planning_max_chunks': 100,
        'planning_settings_note': 'Validation parameters only; production geometry remains a native-registry choice.',
        'tekken_sha256': TEKKEN_SHA256, 'evaluation_input_sha256': sha(inputs / 'input.json'),
        'candidate_policies_sha256': sha(candidates_path),
        'encoder_source_sha256': sha(APP / 'proven_media/shieldstral_text.py'),
        'prompting_source_sha256': sha(APP / 'proven_media/prompting.py'),
        'check_source_sha256': sha(__file__),
        'elapsed_seconds': time.monotonic() - start,
        'peak_rss_gib': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024**2,
        'measurement_note': 'n=1 shared box; single-process text check, no performance comparison'}
    (Path(__file__).parent / 'shieldstral_text_check_r3.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ('items', 'all_a1_inputs_match', 'literal_control_and_unicode_cases',
                                           'chunk_prompt_checks', 'elapsed_seconds', 'peak_rss_gib')}))


if __name__ == '__main__':
    main()
