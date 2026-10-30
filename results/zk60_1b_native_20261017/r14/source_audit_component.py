from pathlib import Path
import os,subprocess
r=Path(__file__).resolve().parent
env=dict(os.environ);env["CARGO_MANIFEST_DIR"]=str(r/"compatibility-working-tree/hashline")
subprocess.run(["/home/victor/.cargo/bin/rustc","--edition=2021","--test","/tmp/r14-source-audit-harness.rs","-o","/tmp/r14-source-audit-harness"],check=True,env=env)
subprocess.run(["/tmp/r14-source-audit-harness","--nocapture"],check=True,env=env)
