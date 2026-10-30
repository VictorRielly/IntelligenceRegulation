"""Bounded first R14 inventory gate; source remains fixed while queued/running."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
TREE=HERE/"working-tree"
GUARD=ROOT/"scripts/zk60_resource_guard.py"


def files():
    names=set(json.loads((HERE/"BASE.json").read_text())["files"])
    names.add("hashline/src/private_block/split_layout.rs")
    return {s:hashlib.sha256((TREE/s).read_bytes()).hexdigest() for s in sorted(names)}


def main():
    label="sol-r14-inventory-1"
    current=files()
    source={"tree_sha256":hashlib.sha256("".join(f"{k} {v}\n" for k,v in current.items()).encode()).hexdigest(),"count":len(current),"files":current}
    pin=HERE/(label+".source.json")
    assert not pin.exists(),"do not relaunch a live/recorded stage"
    pin.write_text(json.dumps(source,indent=2)+"\n")
    command=[sys.executable,str(GUARD),"run","--class","build","--label",label,"--need-gib","2.5","--cap-gib","5",
             "--wait-secs","21600","--max-secs","900","--log",str(HERE/(label+".log")),"--done",str(HERE/(label+".done")),
             "--result-json",str(HERE/(label+".guard.json")),"--","/usr/bin/env","RAYON_NUM_THREADS=2","OPENBLAS_NUM_THREADS=1",
             "/home/victor/.cargo/bin/cargo","test","--release","--offline","--locked","-j2","--manifest-path",str(TREE/"hashline/Cargo.toml"),
             "--lib","split_layout::tests","--","--test-threads=1","--nocapture"]
    (HERE/(label+".command.json")).write_text(json.dumps(command,indent=2)+"\n")
    while True:
        assert files()==current,"source changed while queued"
        check=subprocess.run([sys.executable,str(GUARD),"check","--class","build","--need-gib","2.5"],cwd=ROOT,capture_output=True,text=True)
        if check.returncode==0 and "OK to start now" in check.stdout:break
        print(datetime.now(timezone.utc).isoformat(),label,"waiting outside heavy lock",check.stdout.strip(),flush=True)
        time.sleep(10)
    print(datetime.now(timezone.utc).isoformat(),label,"admitted",flush=True)
    result=subprocess.run(command,cwd=ROOT)
    assert files()==current,"source changed while building/running"
    if result.returncode:sys.exit(result.returncode)
    output=(HERE/(label+".log")).read_text()
    assert "2 passed; 0 failed" in output and output.count("R14_SPLIT_CENSUS {")==12,output[-2500:]
    records=[json.loads(s.split("R14_SPLIT_CENSUS ",1)[1]) for s in output.splitlines() if "R14_SPLIT_CENSUS {" in s]
    (HERE/"NATIVE_INVENTORY_CENSUS.json").write_text(json.dumps({"source":source["tree_sha256"],"rows":records,
        "scope":"Native typed inventory/slot declaration only; actual polynomial/claim builders and profile not wired"},indent=2)+"\n")
    (HERE/"NATIVE_INVENTORY_CENSUS.done").write_text("0\n")
    print(json.dumps({"status":"native inventory declaration PASS","rows":len(records),"source":source["tree_sha256"]}),flush=True)


if __name__=="__main__":main()
