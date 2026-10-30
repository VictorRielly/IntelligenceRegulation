"""Prepare exact A1 category policies for native-registry review, without registration."""
from collections import Counter
import json
from pathlib import Path
import struct
import sys

import numpy as np

from collect_stats import atomic_json, sha

HERE = Path(__file__).resolve().parent
PREP = HERE.parent / 'zk60_shieldstral_prep_20261021'
sys.path.insert(0, str(PREP / 'tools'))
import shieldstral_common as C
C.setup_paths()


def main():
    inputs = HERE / 'evaluation_inputs'
    data = json.loads((inputs / 'input.json').read_text())
    smoke = json.loads((HERE / 'fidelity_smoke8_fix1/run.json').read_text())
    if sha(inputs / 'input.json') != smoke['input_sha256']:
        raise ValueError('policy input differs from the retained numerical replay')
    for name, key in [('ids.npy', 'ids_sha256'), ('offsets.npy', 'offsets_sha256')]:
        if sha(inputs / name) != data[key]:
            raise ValueError('evaluation tokens changed')
    tokenizer = Path(C.MODEL_DIR) / 'tokenizer.json'
    if sha(tokenizer) != data['tokenizer_sha256']:
        raise ValueError('tokenizer changed')
    token_dir = HERE / 'dg_r12b_t256/token_io'
    tables = json.loads((token_dir / 'complete.json').read_text())
    profile_path = token_dir.parent / 'profile.json'
    if sha(profile_path) != tables['profile_sha256']:
        raise ValueError('margin profile changed')
    profile = json.loads(profile_path.read_text())
    margin = profile['classifier_margin_parameters']
    if (margin['yes_id'], margin['no_id'], margin['threshold_c']) != (13059, 2649, 0):
        raise ValueError('unexpected verdict pair or threshold')
    ids = np.load(inputs / 'ids.npy', allow_pickle=False)
    offsets = np.load(inputs / 'offsets.npy', allow_pickle=False)
    candidates = {}
    for name, policy in sorted(data['policies'].items()):
        kind, category = name.split('_')
        strictness = {'cat': 'strict', 'mod': 'moderate'}[kind]
        if policy['template'] != C.TEMPLATES[name]:
            raise ValueError('policy wording changed')
        prefix_text, suffix_text = C.prefix_suffix_text(name)
        tok = C.hf_tokenizer()
        if (tok.encode(prefix_text, add_special_tokens=False).ids != policy['prefix'] or
                tok.encode(suffix_text, add_special_tokens=False).ids != policy['suffix']):
            raise ValueError('policy tokenization differs from all-item replay')
        if policy['prefix'][0] != 1 or policy['suffix'] != [4] or tok.get_vocab_size() != 131072:
            raise ValueError('unexpected tokenizer geometry')
        p, s = len(policy['prefix']), len(policy['suffix'])
        candidates[name] = {'proposed_policy_id': f'shieldstral-1.0-3b-{strictness}-{category}/1',
            'category': category, 'strictness': strictness, 'system_prompt': C.SYSTEM_PROMPT,
            'template': policy['template'], 'prefix_text': prefix_text, 'suffix_text': suffix_text,
            'prefix_ids': policy['prefix'], 'suffix_ids': policy['suffix'], 'bos': 1,
            'num_special_tokens': 1000, 'vocabulary': 131072,
            'yes_id': margin['yes_id'], 'no_id': margin['no_id'], 'threshold_c': 0,
            'margin_scale': margin['public_scale'],
            'margin_scale_bits_hex': hex(struct.unpack('<Q', struct.pack('<d', margin['public_scale']))[0]),
            'content_tokens_by_T': {str(t): t-p-s for t in (128, 256)},
            'content_encoding': 'Leading space belongs to content; plain-text tokens must all be >=1000. No truncation or padding rule is introduced here.'}
    counts = Counter()
    controls = []
    for i, row in enumerate(data['rows']):
        policy = candidates[row['template']]
        p, s = len(policy['prefix_ids']), len(policy['suffix_ids'])
        seq = ids[offsets[i]:offsets[i+1]]
        if not np.array_equal(seq[:p], policy['prefix_ids']) or not np.array_equal(seq[-s:], policy['suffix_ids']):
            raise ValueError('benchmark item uses a different public template')
        content = seq[p:-s]
        if len(content) != row['content_tokens']:
            raise ValueError('content length differs')
        bad = content[(content < 1000) | (content >= 131072)]
        if len(bad):
            controls.append({'row': i, 'dataset': row['dataset'], 'id': row['id'], 'template': row['template'],
                             'forbidden_ids': sorted(set(int(x) for x in bad))})
        counts[row['template']] += 1
    if len(data['rows']) != 4872 or counts != Counter({k: 812 for k in candidates}):
        raise ValueError('policy audit lacks the complete A1 scope')
    result = {'schema': 'zk60-shieldstral-category-policy-candidates/1',
              'scope': 'Candidate native registry entries matching A1; no registration, product-policy selection or proof acceptance',
              'policies': candidates, 'rows_checked': len(data['rows']), 'rows_by_template': dict(counts),
              'content_control_violations': controls, 'all_content_tokens_in_native_class': not controls,
              'evaluation_input_sha256': sha(inputs / 'input.json'), 'tokenizer_json_sha256': sha(tokenizer),
              'token_io_complete_sha256': sha(token_dir / 'complete.json'), 'profile_sha256': sha(profile_path),
              'template_source_sha256': sha(PREP / 'tools/shieldstral_common.py'), 'tool_sha256': sha(__file__),
              'integration_notes': ['Each policy has its own fixed content length T-prefix-suffix.',
                  'Existing native card-unsafe policy is a different template and cannot stand in for these categories.',
                  'Native registration, production tokenizer controls, short-content handling and real proofs remain required.']}
    atomic_json(HERE / 'category_policy_candidates.json', result)
    print(json.dumps({'policies': len(candidates), 'rows_checked': len(data['rows']),
                      'content_control_violations': len(controls),
                      'content_tokens_by_T': {k: p['content_tokens_by_T'] for k, p in candidates.items()}}))


if __name__ == '__main__':
    main()
