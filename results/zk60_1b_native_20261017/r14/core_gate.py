"""Run one immutable T128 core component through the common CPU guard."""
from datetime import datetime,timezone
import hashlib,json,subprocess,sys,time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];GUARD=ROOT/'scripts/zk60_resource_guard.py';TREE=HERE/'working-tree'
def main():
    mode=sys.argv[1];assert mode in {'non-dd','dd'}
    attempt=sys.argv[2] if len(sys.argv)>2 else '1';assert attempt in {'1','2'}
    label='sol-r14-native-core-'+mode+'-'+attempt;build='sol-r14-core-build-'+attempt
    assert (HERE/(build+'.validated.done')).read_text().strip()=='0'
    pin=json.loads((HERE/(build+'.source.json')).read_text())
    def check():
        for name,want in pin['files'].items():assert hashlib.sha256((TREE/name).read_bytes()).hexdigest()==want,name
    check()
    bins=[p for p in (TREE/'hashline/target/release/deps').glob('hashline-*') if p.is_file() and p.stat().st_mode&0o111];assert len(bins)==1
    binary=bins[0];binary_sha=hashlib.sha256(binary.read_bytes()).hexdigest()
    test='private_block::argument::split_definition_tests::split_native_core_t128_'+('non_dd' if mode=='non-dd' else 'dd')+'_proves_verifies_and_tamper_refuses'
    cmd=[sys.executable,str(GUARD),'run','--class','cpu','--label',label,'--need-gib','9.5','--cap-gib','11.5','--wait-secs','21600','--max-secs','1800',
        '--log',str(HERE/(label+'.log')),'--done',str(HERE/(label+'.done')),'--result-json',str(HERE/(label+'.guard.json')),'--',
        '/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1',str(binary),test,'--exact','--ignored','--nocapture','--test-threads=1']
    record=HERE/(label+'.command.json');assert not record.exists(),'do not duplicate a recorded gate'
    record.write_text(json.dumps({'command':cmd,'source':pin['tree_sha256'],'binary':str(binary),'binary_sha256':binary_sha},indent=2)+'\n')
    while True:
        check();assert hashlib.sha256(binary.read_bytes()).hexdigest()==binary_sha
        r=subprocess.run([sys.executable,str(GUARD),'check','--class','cpu','--need-gib','9.5'],cwd=ROOT,capture_output=True,text=True)
        if r.returncode==0 and 'OK to start now' in r.stdout:break
        print(datetime.now(timezone.utc).isoformat(),label,'waiting outside heavy lock',flush=True);time.sleep(10)
    r=subprocess.run(cmd,cwd=ROOT);check();assert hashlib.sha256(binary.read_bytes()).hexdigest()==binary_sha
    if r.returncode:sys.exit(r.returncode)
    log=(HERE/(label+'.log')).read_text();assert '1 passed; 0 failed' in log and 'R14_NATIVE_CORE {' in log
    (HERE/(label+'.validated.done')).write_text('0\n');print(label,'PASS native in-process public synthetic core only',flush=True)
if __name__=='__main__':main()
