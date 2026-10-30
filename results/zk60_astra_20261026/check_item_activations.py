"""Compare the item writer with retained native R16 outputs, without disclosure.

Only the numerical writer is a heavy leaf. The reference tree is read-only;
generated inputs and activations stay in a new owner-only /tmp directory.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import stat
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
EXPORT = ROOT / 'results/zk60_shieldstral_export_20261026'
INPUTS = EXPORT / 'evaluation_inputs'
REFERENCES = ROOT / 'results/zk60_token_io_r1_20261017/r16/items.json'
GUARD = ROOT / 'scripts/zk60_resource_guard.py'
GUARD_SHA = '88af4c639848d39df8da559652db11529575aa745b916a06eb522c20ea89fbd3'
HOLDS = [ROOT / 'results' / name / 'HOLD' for name in
         ('zk60_shieldstral_export_20261026', 'zk60_shieldstral_prep_20261021',
          'zk60_media_app_20261021')]


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


class CheckFailure(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise CheckFailure(message)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--attempt', type=int, required=True)
    args = parser.parse_args()
    require(args.attempt > 0, 'invalid attempt')
    require(not any(p.exists() for p in HOLDS), 'coordinator HOLD active')
    require(sha(GUARD) == GUARD_SHA, 'guard changed')
    out = HERE / f'item_activations_check_{args.attempt}'
    out.mkdir(exist_ok=False)
    try:
        import numpy as np
        sys.path.insert(0, str(EXPORT))
        import write_item_activations as writer

        sources = [Path(__file__), EXPORT / 'write_item_activations.py',
                   EXPORT / 'test_item_activations.py',
                   ROOT / 'apps/proven-media/proven_media/shieldstral_text.py',
                   ROOT / 'apps/proven-media/proven_media/prompting.py',
                   EXPORT / 'evaluate_verdicts.py', EXPORT / 'amended_evaluator.py']
        pins = {str(p.relative_to(ROOT)): sha(p) for p in sources}
        ref = json.loads(REFERENCES.read_bytes())
        require(sha(INPUTS / 'input.json') == ref['source_input_json_sha256'], 'input manifest changed')
        metadata = json.loads((INPUTS / 'input.json').read_bytes())
        for name in ('ids', 'offsets'):
            require(sha(INPUTS / (name + '.npy')) == metadata[name + '_sha256'], 'input array changed')
        ids = np.load(INPUTS / 'ids.npy', allow_pickle=False, mmap_mode='r')
        offsets = np.load(INPUTS / 'offsets.npy', allow_pickle=False, mmap_mode='r')
        require(len(ref['items']) == 3, 'expected three native category references')
        templates = writer.policies()
        requests = []
        for row in ref['items']:
            index = row['row_index']
            meta = metadata['rows'][index]
            require(meta['template'] == row['template'] and meta['dataset'] == row['dataset']
                    and meta['content_tokens'] == row['content_tokens']
                    and meta['id'] == row['row_id_sha256'],
                    'reference item identity differs from A1 input')
            template = templates[row['policy']]
            raw = writer.private_read(row['content_file'], 65536)
            content = tuple(int(s) for s in raw.decode('ascii').replace(',', ' ').split())
            require(len(content) == row['content_tokens'], 'reference content length changed')
            actual = tuple(map(int, ids[int(offsets[index]):int(offsets[index + 1])]))
            require(actual == template.prefix + content + template.suffix,
                    'reference content differs from saved A1 input')
            requests.append({'name': row['template'], 'policy_id': row['policy'],
                             'content_file': row['content_file'], 'chunk_index': 0})
        prepared = writer.prepare_requests(requests)
        require({item['policy_id'] for item in prepared} == set(templates), 'category set changed')
        private = Path(f'/tmp/zk60-astra-item-activations-20261029-{args.attempt}')
        private.mkdir(mode=0o700, exist_ok=False)
        request = private / 'request.json'
        writer.private_write(request, writer.json_bytes(requests))
        generated = private / 'sequences'
        command = ['python3', str(GUARD), 'run', '--class', 'cpu',
                   '--label', 'astra-item-activations', '--need-gib', '1.5', '--cap-gib', '3',
                   '--wait-secs', '1800', '--max-secs', '600',
                   '--log', str(out / 'writer.log'), '--done', str(out / 'writer.done'),
                   '--result-json', str(out / 'writer.guard.json'), '--',
                   '/usr/bin/env', 'OPENBLAS_NUM_THREADS=2', 'OMP_NUM_THREADS=2',
                   'python3', str(EXPORT / 'write_item_activations.py'),
                   '--request', str(request), '--out', str(generated)]
        record = {'schema': 'zk60-astra-item-activation-parity/1',
                  'at': datetime.now(timezone.utc).isoformat(), 'source_sha256': pins,
                  'reference_manifest_sha256': sha(REFERENCES),
                  'source_input_manifest_sha256': ref['source_input_json_sha256'],
                  'guard_sha256': GUARD_SHA, 'command': command,
                  'need_gib': 1.5, 'cap_gib': 3,
                  'measurement_basis': '8-item CPU evaluator peak1.14GiB plus25%, rounded up',
                  'scope': 'One real35-token A1 item, three moderate categories; numerical/native activation parity only'}
        save(out / 'plan.json', record)
        require(not any(p.exists() for p in HOLDS), 'coordinator HOLD active')
        rc = subprocess.run(command).returncode
        guard = json.loads((out / 'writer.guard.json').read_bytes())
        require(rc == guard['exit'] == guard['child_rc'] == 0 and not guard['guard_killed'],
                'guarded writer did not succeed')
        done = json.loads(writer.private_read(generated / 'complete.json', 100000))
        require(done['writer_sha256'] == pins[str((EXPORT / 'write_item_activations.py').relative_to(ROOT))]
                and done['profile_sha256'] == writer.PROFILE_SHA256
                and done['evaluation_export_sha256'] == writer.EVALUATION_SHA256
                and done['request_sha256'] == sha(request)
                and done['dtype'] == 'int16-le' and done['shape'] == [128, 3072]
                and done['layers'] == 26 and done['refusals'] == 0, 'completion provenance changed')
        require([row['name'] for row in done['items']] == [r['name'] for r in requests],
                'completion item set differs')
        expected_names = {f'x_{side}_L{layer:02d}.bin' for side in ('in', 'out') for layer in range(26)}
        count = size = continuity = 0
        for generated_row, reference, expected in zip(done['items'], ref['items'], prepared):
            require(generated_row['policy_id'] == expected['policy_id']
                    and generated_row['chunk'] == expected['chunk']
                    and generated_row['content_total'] == expected['content_total']
                    and generated_row['content_sha256'] == expected['content_sha256'],
                    'generated item metadata differs')
            directory = generated / generated_row['name']
            native = Path(reference['content_file']).parent / 'seq'
            require(set(generated_row['files']) == expected_names
                    and {p.name for p in directory.iterdir()} == expected_names, 'wrong sequence file set')
            require(stat.S_IMODE(directory.stat().st_mode) == 0o700, 'sequence directory is not private')
            for layer in range(26):
                for side in ('in', 'out'):
                    name = f'x_{side}_L{layer:02d}.bin'
                    raw = writer.private_read(directory / name, 128 * 3072 * 2)
                    baseline = writer.private_read(native / name, 128 * 3072 * 2)
                    entry = generated_row['files'][name]
                    require(len(raw) == len(baseline) == entry['bytes'] == 786432
                            and hashlib.sha256(raw).hexdigest() == entry['sha256'], 'sequence shape/hash mismatch')
                    require(raw == baseline, f'native byte mismatch: {reference["template"]} {name}')
                    count += 1
                    size += len(raw)
                if layer:
                    require(generated_row['files'][f'x_in_L{layer:02d}.bin']['sha256'] ==
                            generated_row['files'][f'x_out_L{layer-1:02d}.bin']['sha256'], 'broken layer continuity')
                    continuity += 1
        require({str(p.relative_to(ROOT)): sha(p) for p in sources} == pins, 'sources changed during run')
        require(sha(REFERENCES) == record['reference_manifest_sha256'], 'native references changed')
        record.update({'finished_at': datetime.now(timezone.utc).isoformat(), 'bit_identical': True,
                       'files_compared': count, 'bytes_compared': size, 'layer_continuity_checks': continuity,
                       'categories': 3, 'layers': 26, 'shape': [128, 3072], 'refusals': 0,
                       'input_matches_saved_a1': True, 'private_permissions_checked': True,
                       'guard': {k: guard[k] for k in ('child_wall_seconds', 'peak_rss_gib',
                                                      'peak_cgroup_gib', 'enforcement', 'exit')}})
        save(out / 'complete.json', record)
        (out / 'worker.done').write_text('0\n')
        print(json.dumps({'complete': str(out / 'complete.json'), 'bit_identical': True,
                          'files_compared': count}), flush=True)
    except Exception as error:
        # No private values or arbitrary exception text enter the public evidence.
        save(out / 'failure.json', {'type': type(error).__name__,
                                   'message': str(error) if isinstance(error, CheckFailure) else 'activation check failed'})
        (out / 'worker.done').write_text('1\n')
        print(json.dumps({'failure': str(out / 'failure.json'), 'type': type(error).__name__}), flush=True)
        raise SystemExit(1) from None


if __name__ == '__main__':
    main()
