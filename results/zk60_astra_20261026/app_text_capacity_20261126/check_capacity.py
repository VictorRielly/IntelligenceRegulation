"""Compare the retained public W16R2 statements with the installed text planner."""
import hashlib
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
APP = ROOT / 'apps/proven-media'
PILOT = HERE.parent / 'app_composed_native_20261122'
RUN = PILOT / 'qualification-20261125T070919.014403Z'
GUEST = PILOT / 'guest-20261125T073308.630547Z'
sys.path.insert(0, str(APP))
from proven_media import manifest, proof_plans, w16r2_runtime as w16
from proven_media.app import MAX_POST_CHARACTERS, post_text
from proven_media.prompting import ContentRefused
from proven_media.shieldstral_text import ShieldstralTextEncoder, check_category_coverage


def checked(path, digest):
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != digest:
        raise ValueError(f'Digest mismatch for {path.name}')
    return json.loads(raw)


def audit():
    if not __debug__:
        raise RuntimeError('Run with assertions enabled')
    pilot = json.loads((RUN / 'RESULT.json').read_bytes())
    public = Path(pilot['public_scratch'])
    signed = checked(RUN / 'manifest.json', 'd5db0953ec8a803f3edccc770d2fa53afbd4c76bad0e3eecf3f985a7b2c4d748')
    key = '0ce1e6dd14895a04c711b665723dc1de31118479e365dd9116bdf54b8303bebb'
    assert manifest.verify_signature(signed, key)['accepted']
    guest = checked(GUEST / 'RESULT.json', 'd859dd16897b7e0e9fa453bbc1bd89cf5560287aaff2de1f41c4cce111cdf547')
    assert guest['passed'] and guest['source_pilot'] == RUN.name
    profile = checked(public / 'verifier-export-w16r2-94643880/profile.json', w16.PROFILE_SHA)
    assert guest['kit']['profile_sha256'] == w16.PROFILE_SHA and profile['T'] == 128
    authority = w16.authority()
    assert hashlib.sha256(w16.BINARY.read_bytes()).hexdigest() == guest['kit']['binary_sha256'] == authority['binary_sha256']
    assert hashlib.sha256(w16.PROVER_BINARY.read_bytes()).hexdigest() == w16.PROVER_BINARY_SHA
    assert Path(pilot['prover'][0]) == w16.PROVER_BINARY
    fixture = checked(ROOT / 'results/zk60_a24_app_20261107/posts/one.json', pilot['fixture_sha256'])[0]
    encoder = ShieldstralTextEncoder(HERE.parent / 'app_decision_refresh_20261104/tokenizers/tekken.json')
    templates = w16.Runtime.templates()
    statements, rows = {}, {}
    for entry in signed['entries']:
        category, digest = entry['category'], entry['statement_sha256']
        assert category not in statements
        statement = checked(public / 'bundle-store/objects' / digest[:2] / digest, digest)
        report = checked(GUEST / f'{category}.json', guest['public_verification'][category]['report_sha256'])
        native = report['proof_verifier']
        assert report['accepted'] and native['ok'] and native['exit'] == 0 and native['statement_sha256'] == digest
        assert native['verified']['trained_statement_identity'] == statement['trained_statement_identity'] == authority['statement_identity']
        assert native['verified']['policy'] == statement['policy'] == entry['policy_id']
        assert entry['profile_id'] == w16.PROFILE_SHA and statement['T'] == profile['T']
        assert statement['run_profile'] == authority['run_profile']
        statements[category] = [statement]
        rows[category] = {'statement_sha256': digest, 'prefix_tokens': len(statement['template_prefix_ids']),
                          'suffix_ids': statement['template_suffix_ids'], 'chunk_tokens': statement['chunk']['chunk_size'],
                          'item_tokens': statement['item_length'], 'pad_positions': statement['pad_positions']}
    content_tokens = check_category_coverage(fixture, encoder, templates, statements)
    assert content_tokens == signed['item']['content_length_tokens'] == 14
    examples = {}
    for size in (49, 50, 55, 56, 336, 337):
        cleaned, problem = post_text(' x' * size)
        assert problem is None and len(encoder.content_ids(cleaned)) == size
        try:
            plan = proof_plans.category_work_plan(size, templates)
        except ContentRefused:
            assert size == 337
            examples[str(size)] = 'over token limit'
        else:
            examples[str(size)] = {t.category: sum(ch['category'] == t.category for ch in plan) for t in templates}
    chars = {}
    boundary_text = ('The garden is quiet today. ' * 40)[:MAX_POST_CHARACTERS - 1] + 'x'
    for size in (MAX_POST_CHARACTERS, MAX_POST_CHARACTERS + 1):
        text, problem = post_text((boundary_text + 'x')[:size])
        tokens = len(encoder.content_ids(text))
        assert len(text) == size and proof_plans.category_work_plan(tokens, templates)
        chars[str(size)] = {'content_tokens': tokens, 'within_character_limit': problem is None}
    same_length = {}
    for name, text in [('repeated English word', ('information ' * 20)[:195] + 'x'),
                       ('repeated ASCII letter', 'a' * 196)]:
        assert len(text) == 196
        tokens = len(encoder.content_ids(text))
        plan = proof_plans.category_work_plan(tokens, templates)
        same_length[name] = {'characters': len(text), 'content_tokens': tokens, 'proofs': len(plan)}
    return {'public_fixture': {'characters': len(fixture), 'whitespace_words': len(fixture.split()), 'content_tokens': content_tokens},
            'native_statements': rows, 'token_boundaries': examples, 'character_boundaries': chars,
            'same_length_examples': same_length,
            'export_profile_sha256': w16.PROFILE_SHA, 'new_native_runs': 0}


if __name__ == '__main__':
    print(json.dumps(audit(), indent=2))
