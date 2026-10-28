"""Small dependency-free rustc adapter, bounded externally, one codegen unit."""
from pathlib import Path
import subprocess,json,time,resource
H=Path(__file__).resolve().parent
cmd=['/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/rustc',
     '--edition=2021','-C','opt-level=0','-C','codegen-units=1','-A','dead_code',
     str(H/'oracle.rs'),'-o',str(H/'oracle')]
t=time.monotonic();r=subprocess.run(cmd,cwd=H,timeout=50)
(H/'build-result.json').write_text(json.dumps({'command':cmd,'returncode':r.returncode,
    'elapsed_s':time.monotonic()-t,'maxrss_KiB':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
    'scope':'Dependency-free pinned native field and two pure helper extractions, not native prover build.'},indent=2)+'\n')
raise SystemExit(r.returncode)
