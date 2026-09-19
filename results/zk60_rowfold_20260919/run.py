#!/usr/bin/env python3
import fcntl, hashlib, json, os, signal, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def run():
    if (OUT/'validation.json').exists(): raise SystemExit('refusing overwrite')
    sources=['zkp-core/src/mle.rs','zkp-core/examples/row_fold_bench.rs','zkp-core/Cargo.toml','zkp-core/Cargo.lock']
    report={'state':'running','runs':[],'source_hashes':{p:sha(ROOT/p) for p in sources},'runner_sha256':sha(Path(__file__)),'model_scale_speed_claim':False,'proof_byte_gates_run':False}
    env={k:v for k,v in os.environ.items() if not k.startswith(('HL_','CARGO_','RUSTFLAGS'))}
    env.update(CARGO_BUILD_JOBS='2',RAYON_NUM_THREADS='2')
    def save():
        p=OUT/'validation.tmp'
        p.write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
        p.replace(OUT/'validation.json')
    def command(name, argv, extra=None):
        report['current']=name;save();print('START',name,flush=True)
        start=time.monotonic()
        with (OUT/(name+'.log')).open('x') as log:
            p=subprocess.Popen(argv,cwd=ROOT,env=env|(extra or {}),stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
            try: code=p.wait(timeout=1200)
            except subprocess.TimeoutExpired:
                os.killpg(p.pid,signal.SIGKILL);p.wait();code=124
        report['runs'].append({'name':name,'argv':argv,'environment':extra or {},'exit_code':code,'elapsed_shared_seconds':time.monotonic()-start})
        (OUT/(name+'.done')).write_text(str(code)+'\n');save()
        if code: raise RuntimeError(f'{name}: exit {code}')
        print('PASS',name,flush=True)
        return (OUT/(name+'.log')).read_text()
    save()
    try:
        with open('/tmp/zk-build.lock','w') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX)
            cargo='/home/victor/.cargo/bin/cargo'
            test=[cargo,'test','--release','--offline','--locked','-j','2','--manifest-path','zkp-core/Cargo.toml','--lib','mle::tests','--','--test-threads=2']
            for mode in ['1','0']:
                text=command('arithmetic-'+mode,test,{'HL_FSP_ROW_FOLD':mode})
                if 'test result: ok. 7 passed; 0 failed; 0 ignored' not in text: raise RuntimeError('incomplete arithmetic tests')
            command('bench-build',[cargo,'build','--release','--offline','--locked','-j','2','--manifest-path','zkp-core/Cargo.toml','--example','row_fold_bench'])
        binary=ROOT/'zkp-core/target/release/examples/row_fold_bench'
        report['binary_sha256']=sha(binary);save()
        with open('/tmp/zk-heavy.lock','w') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX)
            for i,mode in enumerate(['0','1','1','0']):
                text=command(f'bench-{i}-{mode}',[str(binary),'2','11'],{'HL_FSP_ROW_FOLD':mode})
                rows=[json.loads(s) for s in text.splitlines()]
                if len(rows)!=8 or not all(r.get('reference_equal') is True for r in rows): raise RuntimeError('incomplete bench reference gate')
                report['runs'][-1]['measurements']=rows;save()
        for p,want in report['source_hashes'].items():
            if sha(ROOT/p)!=want: raise RuntimeError('source changed: '+p)
        report['state']='passed';report['current']=None;save();(OUT/'run.done').write_text('0\n')
    except BaseException as e:
        report['state']='failed';report['error']=str(e);save();(OUT/'run.done').write_text('1\n');raise

if __name__=='__main__':
    if sys.argv[1:]==['--detach']:
        with (OUT/'launch.log').open('x') as log:
            p=subprocess.Popen([sys.executable,str(Path(__file__).resolve())],cwd=ROOT,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        (OUT/'process.json').write_text(json.dumps({'pid':p.pid,'detached':True})+'\n')
        print('Detached row-fold check PID',p.pid,flush=True);raise SystemExit(p.wait())
    run()
