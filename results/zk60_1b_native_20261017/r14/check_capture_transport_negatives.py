"""Negative controls for the exact native capture transport validator.

All files are the public synthetic non-DD fixture. Mutations are in temporary
copies; the original native capture and receipts are never changed.
"""
from pathlib import Path
import copy
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
BUNDLE = HERE / 'native-captures/non-dd'
VALIDATOR = HERE / 'validate_capture_v3.py'
OUTPUT = HERE / 'CAPTURE_TRANSPORT_NEGATIVES_v3.json'
assert not OUTPUT.exists()
validator_hash = hashlib.sha256(VALIDATOR.read_bytes()).hexdigest()
run = json.loads((BUNDLE / 'run.json').read_text())
stage = json.loads((BUNDLE / 'stage0.json').read_text())
results = []
for case in ['unknown-key', 'binding', 'component-tag', 'logup-word', 'source-pin', 'receipt-middle']:
    with tempfile.TemporaryDirectory(prefix='transport-negative-', dir=HERE) as tmp:
        tmp = Path(tmp)
        for source in BUNDLE.iterdir():
            (tmp / source.name).symlink_to(source)
        if case == 'logup-word':
            value = copy.deepcopy(stage)
            value['logup'][0][1] = (1 << 64) - (1 << 32) + 1
            path = tmp / 'stage0.json'
            path.unlink()
            path.write_text(json.dumps(value))
        elif case == 'receipt-middle':
            path = tmp / 'segment0.bin'
            path.unlink()
            shutil.copyfile(BUNDLE / 'segment0.bin', path)
            with path.open('r+b') as frame:
                frame.seek(90001)
                byte = frame.read(1)
                frame.seek(90001)
                frame.write(bytes([byte[0] ^ 1]))
        else:
            value = copy.deepcopy(run)
            if case == 'unknown-key':
                value['unapproved_private_plane'] = []
            elif case == 'binding':
                value['binding'][0] ^= 1
            elif case == 'component-tag':
                value['profiles'][0]['physical_planes'][0]['cm'] = 2
            elif case == 'source-pin':
                value['source_pins'][0]['sha256'] = '0' * 64
            path = tmp / 'run.json'
            path.unlink()
            path.write_text(json.dumps(value))
        result = subprocess.run([sys.executable, str(VALIDATOR), str(tmp), str(tmp / 'result.json')],
                                capture_output=True, text=True, timeout=60)
        assert result.returncode != 0 and not (tmp / 'result.json').exists(), case
        assert 'AssertionError' in result.stderr, (case, result.stderr[-1000:])
        assert hashlib.sha256(VALIDATOR.read_bytes()).hexdigest() == validator_hash
        results.append({'case': case, 'exit': result.returncode, 'result_emitted': False,
                        'stderr_sha256': hashlib.sha256(result.stderr.encode()).hexdigest()})
OUTPUT.write_text(json.dumps({'validator_sha256': validator_hash, 'cases': results,
    'scope': 'Six transport controls on a copied native public synthetic bundle. Unknown keys, '
             'wire binding, invalid component tag, noncanonical public Fp2 limb, source pin and '
             'receipt middle-byte mutation all refuse. Not native mathematical forgery or privacy acceptance.'}, indent=2) + '\n')
print(json.dumps({'transport_negatives': len(results), 'rejected': len(results)}))
