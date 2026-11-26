"""Check the archived signed pilot labels against its public inventories and original verifier results."""
import hashlib
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
PILOT = HERE/'qualification-20261124T082610.220713Z'
sys.path.insert(0, str(HERE.parents[2]/'apps/proven-media'))
from proven_media import manifest
from proven_media.publisher import leaf_hash, merkle_check
from proven_media.w16r2_public_verifier import signed_post_coverage

TEST_KEY = '32c026629c724e2b9ccac8670e54c1c2349110733b011065cd97ff37ac451d90'
ORIGINAL_RESULT = 'a551256720477c86108cc2e69ecdddf383fba8505f741d7a889aee7b8aa15943'


def checked(path, expected):
    raw = path.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == expected
    return json.loads(raw)


def audit():
    if not __debug__:
        raise RuntimeError('Pilot audit requires enabled assertions')
    original = checked(PILOT/'RESULT.json', ORIGINAL_RESULT)
    assert original['passed'] and original['public_scratch_removed']
    signed = json.loads((PILOT/'manifest.json').read_bytes())
    assert manifest.verify_signature(signed, TEST_KEY)['accepted']
    coverage = signed_post_coverage(signed)
    pid = signed['item']['post_id']
    assert pid == original['post_id'] and coverage['planned_chunks'] == coverage['accepted_chunks'] == 3
    inventory_segments = 0
    floors = {}
    for entry in signed['entries']:
        category = entry['category']
        bundle = entry['bundle']
        publication = checked(PILOT/f'{category}.publication.json', bundle['manifest_sha256'])
        native = checked(PILOT/f'{category}.json', original['public_verification'][category]['report_sha256'])
        anchor = native['anchor_ref']
        assert native['accepted'] and all(native['checks'].values())
        assert anchor['status'] == 'anchored' and anchor['manifest_sha256'] == bundle['manifest_sha256']
        assert anchor['manifest_uri'] == bundle['manifest_uri']
        assert len(publication['segments']) == len(anchor['receipt_uris']) == bundle['receipt_uris']
        assert publication['post_id'] == pid and publication['chunk'] == entry['chunk']
        assert publication['category'] == category and publication['token_range'] == entry['token_range']
        assert publication['content_commitment'] == entry['content_commitment'] == signed['item']['content_commitment']
        assert publication['policy_id'] == entry['policy_sha256'] and publication['verdict'] == entry['verdict']
        assert all(publication[k] == entry[k] for k in ('model_id','profile_id','verifier_id','statement_sha256'))
        leaf = leaf_hash(pid, category, entry['chunk'], entry['token_range'], bundle['manifest_sha256'],
                         entry['statement_sha256'], entry['verdict'], entry['model_id'],
                         entry['policy_sha256'], entry['content_commitment'])
        assert leaf == anchor['leaf_hash'] == entry['anchor']['leaf_hash']
        assert merkle_check(leaf, anchor['merkle_proof'], anchor['merkle_root'])
        proof = native['proof_verifier']
        event = proof['verified']
        assert proof['ok'] and proof['statement_sha256'] == entry['statement_sha256']
        assert event['event'] == 'classified' and event['trained_statement_identity'] == entry['model_id']
        assert event['policy'] == entry['policy_id'] and event['chunk'] == entry['category_chunk_index']
        assert event['chunks'] == signed['chunking']['categories'][category]['chunks']
        assert event['verdict'] == ('flagged' if entry['verdict'] == 'yes' else 'not-flagged')
        floors[category] = event['whole_run_floor_bits']
        assert floors[category] >= 95
        inventory_segments += len(publication['segments'])
    return dict(post_id=pid, publisher_test_key=TEST_KEY, signed_post_coverage=coverage,
                inventory_segments=inventory_segments, original_native_floor_bits=floors,
                original_qualification_sha256=ORIGINAL_RESULT, archived_merkle_paths_checked=len(floors),
                fresh_native_replay=False, fresh_input_owner_check=False)


if __name__ == '__main__':
    print(json.dumps(audit(), indent=2))
