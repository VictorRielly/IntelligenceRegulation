"""Build/run immutable accepted-R13 matched fixtures through the shared guard."""
from datetime import datetime,timezone
import hashlib,json,subprocess,sys,time
from pathlib import Path
R14=Path(__file__).resolve().parent;HERE=R14/'matched-r13';ROOT=R14.parents[2];TREE=HERE/'working-tree';GUARD=ROOT/'scripts/zk60_resource_guard.py'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    pin=json.loads((HERE/'source.json').read_text())
    def check():
        for path,want in pin['files'].items():assert sha(TREE/path)==want,path
    mode=sys.argv[1];assert mode in {'build','non-dd','dd'};check()
    attempt=sys.argv[2] if len(sys.argv)>2 else '1';assert attempt.isdigit()
    label='sol-r13-matched-'+mode+'-'+attempt;need=2.5 if mode=='build' else 9.5;cap=5 if mode=='build' else 11.5
    if mode=='build':
        leaf=['/home/victor/.cargo/bin/cargo','test','--release','--offline','--locked','-j2','--manifest-path',str(TREE/'hashline/Cargo.toml'),'--lib','matched_r14_benchmark','--no-run']
        binary_sha=None
    else:
        assert (HERE/('sol-r13-matched-build-'+attempt+'.validated.done')).read_text().strip()=='0'
        bins=[p for p in (TREE/'hashline/target/release/deps').glob('hashline-*') if p.is_file() and p.stat().st_mode&0o111];assert len(bins)==1
        binary_sha=sha(bins[0]);test='private_block::matched_r14_benchmark::r14_matched_r13_t128_'+mode.replace('-','_')+'_two_blocks'
        leaf=[str(bins[0]),test,'--exact','--ignored','--nocapture','--test-threads=1']
    command=[sys.executable,str(GUARD),'run','--class','build' if mode=='build' else 'cpu','--label',label,'--need-gib',str(need),'--cap-gib',str(cap),'--wait-secs','21600','--max-secs','1800',
        '--log',str(HERE/(label+'.log')),'--done',str(HERE/(label+'.done')),'--result-json',str(HERE/(label+'.guard.json')),'--','/usr/bin/env','RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=1',*leaf]
    record=HERE/(label+'.command.json');assert not record.exists(),'do not duplicate a recorded stage'
    record.write_text(json.dumps({'command':command,'source':pin['tree_sha256'],'binary_sha256':binary_sha},indent=2)+'\n')
    while True:
        check()
        result=subprocess.run([sys.executable,str(GUARD),'check','--class','build' if mode=='build' else 'cpu','--need-gib',str(need)],cwd=ROOT,capture_output=True,text=True)
        if result.returncode==0 and 'OK to start now' in result.stdout:break
        print(datetime.now(timezone.utc).isoformat(),label,'waiting outside heavy lock',flush=True);time.sleep(10)
    result=subprocess.run(command,cwd=ROOT);check()
    if result.returncode:sys.exit(result.returncode)
    if mode!='build':
        assert sha(bins[0])==binary_sha
        log=(HERE/(label+'.log')).read_text();assert '1 passed; 0 failed' in log and 'R13_MATCHED_STREAM ' in log
        row=[json.loads(line.split('R13_MATCHED_STREAM ',1)[1]) for line in log.splitlines() if 'R13_MATCHED_STREAM ' in line];assert len(row)==1
        (HERE/(label+'.result.json')).write_text(json.dumps(row[0],indent=2)+'\n')
    (HERE/(label+'.validated.done')).write_text('0\n');print(label,'PASS',flush=True)
if __name__=='__main__':main()
