import fcntl, json, os, pathlib, resource, subprocess, traceback
root = pathlib.Path('/home/victor/IntelligenceRegulation')
out = pathlib.Path('/tmp/zk60-round19')
env = {k:v for k,v in os.environ.items() if not k.startswith('HL_')}
env.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2')
def cap(): resource.setrlimit(resource.RLIMIT_AS, (8<<30, 8<<30))
rc=1
try:
    with open('/tmp/zk-heavy.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        with (out/'targeted.log').open('w') as log:
            p=subprocess.run(['/home/victor/.cargo/bin/cargo','test','--release','--locked','--offline','--manifest-path','hashline/Cargo.toml','--lib','bound_ffn','--','--test-threads=2','--nocapture'],cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT,preexec_fn=cap,timeout=1800)
            rc=p.returncode
except BaseException:
    traceback.print_exc()
finally:
    (out/'targeted.done').write_text(str(rc)+'\n')
