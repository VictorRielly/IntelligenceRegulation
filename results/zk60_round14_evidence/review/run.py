import fcntl,os,subprocess
from pathlib import Path
base=Path('/tmp/zk60-round14/core-review')
env={k:v for k,v in os.environ.items() if not k.startswith('HL_')}
env.update(CARGO_BUILD_JOBS='2', RAYON_NUM_THREADS='2', CARGO_NET_OFFLINE='true')
env.pop('CARGO_TARGET_DIR',None)
rc=1
try:
 with open('/tmp/zk-heavy.lock','a') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX)
  with (base/'probes.log').open('w') as log:
   rc=subprocess.run(['cargo','run','--offline','--manifest-path',str(base/'probe/Cargo.toml')],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=240).returncode
finally:
 (base/'probes.done').write_text(str(rc)+'\n')
