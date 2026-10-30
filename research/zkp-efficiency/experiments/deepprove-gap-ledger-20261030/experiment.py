import copy
import hashlib
import json
from pathlib import Path
import random
import time

import codec
import reference as ref

E = Path(__file__).resolve().parent
SEED = 20261030172


def rejected(f):
    try:
        f()
    except ValueError:
        return True
    return False


def run():
    start = time.monotonic()
    rng = random.Random(SEED)
    rows = []
    controls = {}
    hash_checks = 0
    timings = {'encode_s': 0.0, 'decode_s': 0.0}
    for depth in [0, 1, 2, 5, 8, 11, 12, 14, 16, 17]:
        role = f'synthetic-root-{depth}'.encode()
        tree = ref.make_tree(depth, role)
        bound, q = 1 << depth, 256
        patterns = {
            'replacement-random': [rng.randrange(bound) for _ in range(q)],
            'all-repeated': [bound // 2] * q,
            'extrema': [0, bound - 1] * (q // 2),
            'adjacent-unsorted': [(q - i - 1) % bound for i in range(q)],
            'sorted-random': sorted(rng.randrange(bound) for _ in range(q)),
        }
        for name, indices in patterns.items():
            paths = ref.paths_for(tree, indices)
            original = ref.record_bytes(indices, paths, role)
            t = time.monotonic()
            compressed = codec.encode(indices, paths, q, depth)
            timings['encode_s'] += time.monotonic() - t
            t = time.monotonic()
            rebuilt = codec.decode(indices, compressed, q, depth)
            timings['decode_s'] += time.monotonic() - t
            assert rebuilt == paths
            assert ref.record_bytes(indices, rebuilt, role) == original
            assert len(compressed) == 32 * ref.unique_coordinates_reference(indices, depth)
            for j, path in zip(indices, rebuilt):
                assert ref.verify(tree, j, path, role)
                hash_checks += 1
            rows.append({'depth': depth, 'queries': q, 'pattern': name,
                         'distinct_columns': len(set(indices)),
                         'original_path_bytes': q * depth * 32,
                         'interned_path_bytes': len(compressed),
                         'original_tuple_digest': hashlib.sha256(original).hexdigest(),
                         'full_tuple_roundtrip': True})
            if depth == 12 and name == 'replacement-random':
                controls['truncated'] = rejected(lambda: codec.decode(indices, compressed[:-1], q, depth))
                controls['trailing'] = rejected(lambda: codec.decode(indices, compressed + b'x', q, depth))
                controls['lost_repeat_or_query'] = rejected(lambda: codec.decode(indices[:-1], compressed, q, depth))
                bad = list(indices); bad[0] = bound
                controls['out_of_bounds'] = rejected(lambda: codec.decode(bad, compressed, q, depth))
                controls['wrong_depth'] = rejected(lambda: codec.encode(indices, paths, q, depth - 1))
                badp = copy.deepcopy(paths); badp[-1][-1] = b'Z' * 32
                # Top siblings have repeated coordinates; inconsistent source rejected.
                controls['inconsistent_coordinate'] = rejected(lambda: codec.encode(indices, badp, q, depth))
                altered = bytes([compressed[0] ^ 1]) + compressed[1:]
                malformed = codec.decode(indices, altered, q, depth)
                controls['digest_flip_native_stage_required'] = any(not ref.verify(tree, j, p, role) for j,p in zip(indices, malformed))
                swapped = indices[1:] + indices[:1]
                try:
                    wrong = codec.decode(swapped, compressed, q, depth)
                    controls['query_reorder'] = any(not ref.verify(tree,j,p,role) for j,p in zip(swapped,wrong))
                except ValueError:
                    controls['query_reorder'] = True
                controls['wrong_root_role'] = any(not ref.verify(tree,j,p,b'other-root') for j,p in zip(indices,paths))
                # Reusing a dictionary across roots yields the wrong bytes/root.
                other = ref.make_tree(depth, b'other-root')
                controls['cross_root_dictionary_reuse'] = any(not ref.verify(other,j,p,b'other-root') for j,p in zip(indices,rebuilt))
        del tree
    assert all(controls.values()), controls
    # Source-derived geometry: classifier IN, 26 blocks, OUT; no extra output endpoint.
    q = 256
    classifier_depths = [12,14,14,11] + [12,16,16,16] * 26 + [12,14,14,16]
    owner = json.loads((E/'owner-aggregate.json').read_text())
    total = owner['batch_jobs'][0]['receipt_bytes']
    paths = sum(classifier_depths) * q * 32
    assert len(classifier_depths) == 28 * 4
    random_rows = {r['depth']: r for r in rows if r['pattern'] == 'replacement-random'}
    modeled_intern = sum(random_rows[d]['interned_path_bytes'] for d in classifier_depths)
    census = {
        'scope': 'Frozen R18 Shieldstral T128 classifier,26 blocks plus IN/OUT, one category. Source-derived byte accounting; no actual receipt inspected.',
        'checks_per_opening': q, 'openings': len(classifier_depths),
        'path_depth_sum': sum(classifier_depths), 'receipt_bytes_owner': total,
        'all_path_bytes': paths, 'non_path_bytes': total-paths,
        'all_path_fraction': paths/total,
        'impossible_free_all_paths_size_factor': total/(total-paths),
        'synthetic_random_interned_path_bytes': modeled_intern,
        'synthetic_random_saved_bytes': paths-modeled_intern,
        'synthetic_random_saved_receipt_fraction': (paths-modeled_intern)/total,
        'timing_inference': 'No end-to-end time factor from byte share. Original native verification is unchanged after decompression; decoder adds work.',
        'full_path_depths': classifier_depths,
        '8b_block_only_historical_geometry': {
            'layers': 32, 'T': 128, 'receipt_bytes_carried': 922711264,
            'paths': (32*(12+16+16+16)+16)*q*32,
            'scope': 'Older block-only 8B source geometry,not current R14 admission or new verification'},
    }
    result = {'status':'PASS','seed':SEED,'fixtures':len(rows),'full_tuple_roundtrips':len(rows),
              'independent_synthetic_path_verifications':hash_checks,'controls':controls,
              'diagnostic_codec_clocks':timings,'wall_s':time.monotonic()-start,
              'native_execution':False,'proofs':0,'proved_positions':0,
              'scope':'Opaque path-byte codec and source byte census only. SHA256 is a synthetic tree oracle; native BLAKE3,PCS,soundness and P1 privacy not verified.'}
    for name,data in [('fixtures.json',rows),('census.json',census),('result.json',result)]:
        (E/name).write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps(result))
    print(json.dumps({k:v for k,v in census.items() if k!='full_path_depths'}))


if __name__ == '__main__':
    run()
