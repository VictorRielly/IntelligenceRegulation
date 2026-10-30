"""Resume once the existing build finishes, then serial guarded acceptance.

The build is never relaunched here. A failed/nonterminal stage cannot be
silently retried. Keep and poll the original tool session for this driver.
"""
from datetime import datetime,timezone
import json,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];BUILD='sol-r14-actual-build-2'
deadline=time.monotonic()+21600
while not (HERE/(BUILD+'.validated.done')).exists():
    if (HERE/(BUILD+'.done')).exists():
        value=(HERE/(BUILD+'.done')).read_text().strip()
        assert value=='0','existing build failed; diagnose original stage, do not retry'
    assert time.monotonic()<deadline,'waiting limit reached, inspect original build handle'
    print(datetime.now(timezone.utc).isoformat(),'waiting for existing',BUILD,flush=True);time.sleep(10)
for script,args in [('attack_checks.py',['3']),('generic_checks.py',[])]:
    result=subprocess.run([sys.executable,str(HERE/script),*args],cwd=ROOT)
    if result.returncode:sys.exit(result.returncode)
report={'utc':datetime.now(timezone.utc).isoformat(),'source':json.loads((HERE/(BUILD+'.source.json')).read_text())['tree_sha256'],
    'malicious':'NATIVE_MALICIOUS_RECEIPTS.json','generic_dense':'GENERIC_DENSE_ACCEPTANCE.json',
    'scope':'Mandatory split-specific emitted receipt attacks plus generic dense independent arithmetic gates complete. Other review/privacy/compatibility/CLI obligations remain.'}
(HERE/'CANDIDATE_ACCEPTANCE_BATCH.json').write_text(json.dumps(report,indent=2)+'\n')
(HERE/'CANDIDATE_ACCEPTANCE_BATCH.done').write_text('0\n')
print('Candidate malicious / generic dense acceptance batch complete',flush=True)
