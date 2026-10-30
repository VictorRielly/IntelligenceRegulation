"""Local source snapshots and exact function extraction; no external execution."""
from pathlib import Path
import hashlib, json, platform, os
HERE = Path(__file__).resolve().parent
PRIOR = HERE.parent / 'pair-tile-dataflow-20261029'
pins = json.loads((PRIOR / 'native-pins.json').read_text())
for r in pins:
    b = Path(r['path']).read_bytes()
    assert hashlib.sha256(b).hexdigest() == r['sha256']
    p = HERE / r['snapshot']; p.parent.mkdir(exist_ok=True); p.write_bytes(b)
(HERE/'native-pins.json').write_text(json.dumps(pins, indent=2)+'\n')
def extract(text, prefix):
    start = text.index(prefix); brace = text.index('{', start); depth = 1; end = brace+1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}'); end += 1
    return text[start:end]
arg = (HERE/'native/argument.rs').read_text()
funcs = []
for prefix,name in [('pub(super) fn priv_table(', 'native_priv_table'), ('fn claim_point(', 'native_claim_point'), ('fn mask_eval(', 'native_mask_eval')]:
    body = extract(arg,prefix)
    old = prefix.split('fn ')[1].split('(')[0]
    patched = body.replace('pub(super) ', '').replace('fn '+old+'(', 'fn '+name+'(', 1)
    (HERE/(name+'.rs')).write_text(patched+'\n')
    funcs.append({'name':name,'native_body_sha256':hashlib.sha256(body.encode()).hexdigest(),'adapter_only':'visibility/name; body unchanged'})
(HERE/'extraction.json').write_text(json.dumps(funcs,indent=2)+'\n')
for name in ['serial_eq.rs','model.py','legacy_catalog.py']:
    (HERE/name).write_bytes((PRIOR/name).read_bytes())
cpu = next((s.split(':',1)[1].strip() for s in Path('/proc/cpuinfo').read_text().splitlines() if s.startswith('model name')), 'unknown')
(HERE/'hardware.json').write_text(json.dumps({'cpu':cpu,'platform':platform.platform(),'affinity_available':sorted(os.sched_getaffinity(0)),'device':'CPU only','gpu':False,'numeric_workers':1},indent=2)+'\n')
print(json.dumps({'native_pins':len(pins),'extracted_functions':len(funcs),'cpu':cpu}))
