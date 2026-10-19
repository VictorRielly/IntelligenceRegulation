"""CPU-only prefill timing of an 8B Llama-architecture model (Ollama, Q4_K_M) for
comparison with the proof's runtime. Starts a private server (child of this
process, GPU hidden), runs raw prompts with num_predict=1, records Ollama's own
prompt_eval_count / prompt_eval_duration / load_duration. Run under the guard."""
import json, os, subprocess, sys, time, urllib.request
PORT = 11555
MODEL = sys.argv[1] if len(sys.argv) > 1 else 'deepseek-r1:8b'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), sys.argv[2] if len(sys.argv) > 2 else 'result.json')
env = dict(os.environ, OLLAMA_HOST=f'127.0.0.1:{PORT}', CUDA_VISIBLE_DEVICES='-1',
           OLLAMA_MODELS='/usr/share/ollama/.ollama/models')  # the system service's store (read-only use)
srv = subprocess.Popen(['ollama', 'serve'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
def call(path, body):
    req = urllib.request.Request(f'http://127.0.0.1:{PORT}{path}', data=json.dumps(body).encode(),
                                 headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=900) as r:
        return json.loads(r.read())
for _ in range(60):
    try:
        urllib.request.urlopen(f'http://127.0.0.1:{PORT}/api/version', timeout=2); break
    except Exception:
        time.sleep(1)
words = ('The committee reviewed the annual report on regional water infrastructure and asked the engineers '
         'to explain why maintenance costs had risen so sharply in the northern districts during the last '
         'three years while the southern districts reported stable budgets and fewer emergency repairs across '
         'their pipe networks and treatment plants, despite similar population growth and comparable rainfall '
         'patterns throughout every season of the period under examination by the independent auditors who '
         'were appointed by the regional council last spring to verify the accounts')
toks = words.split()
import random
def mk(seed, n):
    r = random.Random(seed); t = toks[:]; out = []
    while len(out) < n:
        r.shuffle(t); out += t
    return ' '.join(out[:n])
# attempt 2 found Ollama reuses the KV cache for a repeated or shared-prefix prompt,
# so every timed prompt is distinct (different shuffles), after one untimed warm-up
call('/api/generate', {'model': MODEL, 'prompt': 'warm up the model weights please', 'raw': True,
                       'stream': False, 'options': {'num_gpu': 0, 'num_predict': 1, 'temperature': 0}})
plan = [('p32', s, 26) for s in (11, 12, 13, 14)] + [('p128', s, 100) for s in (21, 22, 23, 24)]
res = {'model': MODEL,
       'device': 'CPU only (CUDA_VISIBLE_DEVICES=-1, num_gpu=0)', 'runs': []}
try:
    for name, seed, n in plan:
        t0 = time.time()
        r = call('/api/generate', {'model': MODEL, 'prompt': mk(seed, n), 'raw': True, 'stream': False,
                                    'options': {'num_gpu': 0, 'num_predict': 1, 'temperature': 0}})
        res['runs'].append({'prompt': name, 'seed': seed, 'wall_s': round(time.time() - t0, 3),
                            'prompt_eval_count': r.get('prompt_eval_count'),
                            'prompt_eval_s': (r.get('prompt_eval_duration') or 0) / 1e9,
                            'load_s': (r.get('load_duration') or 0) / 1e9,
                            'total_s': (r.get('total_duration') or 0) / 1e9})
        print(json.dumps(res['runs'][-1]), flush=True)
finally:
    json.dump(res, open(OUT, 'w'), indent=1)
    srv.terminate()
    try:
        srv.wait(timeout=20)
    except Exception:
        srv.kill()
