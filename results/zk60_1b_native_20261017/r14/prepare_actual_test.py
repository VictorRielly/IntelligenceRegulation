"""Generate staged actual S2 oracle pins; no frozen input/source is modified."""
import hashlib, json
from pathlib import Path
HERE = Path(__file__).resolve().parent
OLD = HERE.parent / 'r13'
oracle = OLD / 'actual-t128-smoke-export/PUBLIC_ORACLE.json'
assert hashlib.sha256(oracle.read_bytes()).hexdigest() == '9fe10a9c257bd18baf1dd00d752ddfa4e46ef0db914027fcc715d26f2d8e59b2'
data = json.loads(oracle.read_text())
roles = [('input','A_X'),('y','A_Y'),('q','A_Q8'),('k','A_K8'),('v','A_V8'),
    ('qr','A_QR8'),('kr','A_KR8'),('s','A_S8'),('p','A_P'),('o','A_O8'),
    ('ao','A_AO'),('x1','A_X1'),('nm','A_YM'),('gate','A_G8'),('a_scaled','A_A16'),
    ('up','A_U16'),('h','A_H16'),('z','A_Z16'),('x2','A_X2')]
assert set(name for name,_ in roles) == set(data['trace_sha256'])
entries = '\n'.join(f'    ("{name}", {role}, "{data["trace_sha256"][name]}"),' for name,role in roles)
template = (HERE / 'staged/split_actual_tests.template').read_text()
assert template.count('@@ORACLE_ENTRIES@@') == 1
(HERE / 'staged/split_actual_tests.rs').write_text(template.replace('@@ORACLE_ENTRIES@@', entries))
print('Staged actual S2 oracle with19 immutable trace pins')
