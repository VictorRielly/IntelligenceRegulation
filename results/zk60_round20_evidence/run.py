import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import time

root = Path('/home/victor/IntelligenceRegulation')
out = Path('/tmp/zk60-round20')
resource.setrlimit(resource.RLIMIT_AS, (8*1024**3, 8*1024**3))
env = {k: v for k, v in os.environ.items() if not k.startswith('HL_')}
env.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2', RUST_TEST_THREADS='2')
stages = [
    ('unit', ['python3', '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_zk60_io_opening_translation.py', '-v']),
    ('fa6_regression', ['python3', '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_zk60_fable_cfs_channel.py', '-v']),
    ('captures', ['python3', 'scripts/zk60_io_opening_translation.py', '--captures', '/tmp/zk60-round19/captures', '--out', 'results/zk60_round20_opening_translation.json']),
]
result = {'schema': 1, 'stages': [], 'rlimit_as': 8*1024**3}
for name, command in stages:
    log = out / (name+'.log')
    start = time.monotonic()
    with log.open('wb') as f:
        process = subprocess.run(command, cwd=root, env=env, stdout=f, stderr=subprocess.STDOUT)
    record = dict(name=name, command=command, exit_code=process.returncode, elapsed_s=time.monotonic()-start, log_sha256=hashlib.sha256(log.read_bytes()).hexdigest())
    result['stages'].append(record)
    (out/'validation.json').write_text(json.dumps(result, indent=2)+'\n')
    print(name, process.returncode, flush=True)
    if process.returncode:
        (out/'validation.done').write_text(str(process.returncode)+'\n')
        raise SystemExit(process.returncode)
result['status'] = 'passed'
(out/'validation.json').write_text(json.dumps(result, indent=2)+'\n')
(out/'validation.done').write_text('0\n')
