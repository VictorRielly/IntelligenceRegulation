from pathlib import Path
import os,subprocess
r=Path(__file__).resolve().parent
env=dict(os.environ);env["CARGO_MANIFEST_DIR"]=str(r/"compatibility-audit-v3/hashline")
subprocess.run(["/home/victor/.cargo/bin/rustc","--edition=2021","--test","/tmp/r14-hash-audit-v3.rs","-o","/tmp/r14-hash-audit-v3"],check=True,env=env)
subprocess.run(["/tmp/r14-hash-audit-v3","--nocapture"],check=True,env=env)
