"""Pin only the strengthened c2 test fixture after its diagnosed pre-proof failure."""
from datetime import datetime,timezone
import hashlib,json,shutil
from pathlib import Path
HERE=Path(__file__).resolve().parent;TREE=HERE/'working-tree'
old=json.loads((HERE/'sol-r14-run-build-5.source.json').read_text())
assert (HERE/'sol-r14-attack-non-dd-per-piece-round-q-2.validated.done').read_text().strip()=='0'
assert (HERE/'sol-r14-attack-non-dd-local-c2-ao-2.done').read_text().strip()=='101'
files={}
for name,want in old['files'].items():
    assert hashlib.sha256((HERE/'checkpoints/run-build-5/tree'/name).read_bytes()).hexdigest()==want,name
    got=hashlib.sha256((TREE/name).read_bytes()).hexdigest()
    if name!='hashline/src/private_block/split_attack_tests.rs':assert got==want,name
    files[name]=got
digest=hashlib.sha256(''.join(f'{k} {v}\n' for k,v in sorted(files.items())).encode()).hexdigest()
path=HERE/'sol-r14-run-build-6.source.json';assert not path.exists()
path.write_text(json.dumps({'tree_sha256':digest,'count':len(files),'files':files},indent=2)+'\n')
shutil.copy2(HERE/'attack_checks.py',HERE/'checkpoints/run-build-5/attack_checks.attempt2.py')
(HERE/'C2_FIXTURE_ATTEMPT1.json').write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),
    'original_source':old['tree_sha256'],'corrected_source':digest,
    'failure':'No global-c2 rounded-output counterexample: selected sparse V/O lanes all rounded to zero; no malicious receipt emitted for this case.',
    'fix':'Test-only live KV lane (m_v64, W_v=-127) and narrow WO row127 over four corresponding query-head copies; global AO c2=1 vs incorrect local256 now differs. Native proof/verifier source unchanged.',
    'retained':'Failed log/guard/command and full source+binary checkpoint; earlier Q per-piece full malicious receipt passed separately.'},indent=2)+'\n')
state=json.loads((HERE/'CURRENT_DEV_STATE.json').read_text());state.update(utc=datetime.now(timezone.utc).isoformat(),
    phase='Q per-piece malicious receipt PASS; AO-c2 fixture degenerate, strengthened for build6',
    source_sha256=digest,source_pin=str(path),source_edits_held=True,live_tool_session=None,
    live_stage='sol-r14-run-build-6',live_tool_sessions=[{'session':24069,'task':'actualS2DD/nonDD native/fresh/corrupt gates source087016a3'}])
(HERE/'CURRENT_DEV_STATE.json').write_text(json.dumps(state,indent=2)+'\n');print(json.dumps({'source':digest,'files':len(files)}))
