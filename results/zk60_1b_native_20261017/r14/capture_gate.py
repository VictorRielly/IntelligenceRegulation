"""Compile the independent native observer after the current arithmetic gates."""
from datetime import datetime,timezone
import hashlib,json,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];TREE=HERE/'capture-working-tree';GUARD=ROOT/'scripts/zk60_resource_guard.py'
LABEL='sol-r14-capture-build-1'
assert (HERE/'CANDIDATE_ACCEPTANCE_BATCH.done').read_text().strip()=='0','finish arithmetic candidate first'
pin=json.loads((HERE/(LABEL+'.source.json')).read_text())
def check():
    for name,want in pin['files'].items():assert hashlib.sha256((TREE/name).read_bytes()).hexdigest()==want,name
check();command=[sys.executable,str(GUARD),'run','--class','build','--label',LABEL,'--need-gib','2.6','--cap-gib','5',
    '--wait-secs','21600','--max-secs','1800','--log',str(HERE/(LABEL+'.log')),'--done',str(HERE/(LABEL+'.done')),
    '--result-json',str(HERE/(LABEL+'.guard.json')),'--','/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1',
    '/home/victor/.cargo/bin/cargo','test','--release','--offline','--locked','-j2','--manifest-path',str(TREE/'hashline/Cargo.toml'),
    '--lib','split_','--','--test-threads=1','--nocapture']
record=HERE/(LABEL+'.command.json');assert not record.exists();record.write_text(json.dumps(command,indent=2)+'\n')
while True:
    check();r=subprocess.run([sys.executable,str(GUARD),'check','--class','build','--need-gib','2.6'],cwd=ROOT,capture_output=True,text=True)
    if r.returncode==0 and 'OK to start now' in r.stdout:break
    print(datetime.now(timezone.utc).isoformat(),LABEL,'waiting outside heavy lock',flush=True);time.sleep(10)
r=subprocess.run(command,cwd=ROOT);check()
if r.returncode:sys.exit(r.returncode)
log=(HERE/(LABEL+'.log')).read_text();assert '18 passed; 0 failed; 20 ignored' in log
assert log.count('R14_ACTUAL_SLOT {')==126 and log.count('R14_SPLIT_CENSUS {')==12
(HERE/(LABEL+'.validated.done')).write_text('0\n');print('Native R14 observer compiles/components PASS18/0; full capture/rank not yet tested',flush=True)
