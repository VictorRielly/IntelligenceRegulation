"""Bounded pinned R14 component gate with admission outside the heavy lock."""
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
GUARD=ROOT/"scripts/zk60_resource_guard.py"


def main():
    label=sys.argv[1]
    assert label in {"sol-r14-geometry-1", "sol-r14-scheduled-cfs-1", "sol-r14-builders-1", "sol-r14-builders-2", "sol-r14-core-build-1", "sol-r14-core-build-2", "sol-r14-run-build-1", "sol-r14-run-build-2", "sol-r14-run-build-3", "sol-r14-run-build-4", "sol-r14-run-build-5", "sol-r14-run-build-6"}
    pin=json.loads((HERE/(label+".source.json")).read_text())
    def check():
        for rel,want in pin["files"].items():
            assert hashlib.sha256((HERE/"working-tree"/rel).read_bytes()).hexdigest()==want,rel
    check()
    command=[sys.executable,str(GUARD),"run","--class","build","--label",label,"--need-gib","2.5","--cap-gib","5",
        "--wait-secs","21600","--max-secs","900","--log",str(HERE/(label+".log")),"--done",str(HERE/(label+".done")),
        "--result-json",str(HERE/(label+".guard.json")),"--","/usr/bin/env","RAYON_NUM_THREADS=2","OPENBLAS_NUM_THREADS=1",
        "/home/victor/.cargo/bin/cargo","test","--release","--offline","--locked","-j2","--manifest-path",
        str(HERE/"working-tree/hashline/Cargo.toml"),"--lib","split_","--","--test-threads=1","--nocapture"]
    record=HERE/(label+".command.json");assert not record.exists(),"do not duplicate a recorded stage";record.write_text(json.dumps(command,indent=2)+"\n")
    while True:
        check()
        r=subprocess.run([sys.executable,str(GUARD),"check","--class","build","--need-gib","2.5"],cwd=ROOT,capture_output=True,text=True)
        if r.returncode==0 and "OK to start now" in r.stdout:break
        print(datetime.now(timezone.utc).isoformat(),label,"waiting outside heavy lock",flush=True);time.sleep(10)
    r=subprocess.run(command,cwd=ROOT);check()
    if r.returncode:sys.exit(r.returncode)
    out=(HERE/(label+".log")).read_text()
    assert "0 failed" in out and out.count("R14_SPLIT_CENSUS {")==12
    if label=="sol-r14-scheduled-cfs-1":
        for name in ["split_scheduled_native_cfs_pcs_m_accepts_public_factor_lift_at_slot30",
                     "split_scheduled_native_cfs_emitted_gate_forgeries_reach_m_and_refuse"]:
            assert name+" ... ok" in out,name
    if label.startswith("sol-r14-builders-") or label.startswith("sol-r14-core-build-") or label.startswith("sol-r14-run-build-"):
        assert out.count("R14_ACTUAL_SLOT {")==126
        for name in ["split_actual_definitions_match_all_physical_sites_sources_hosts_and_degrees",
                     "split_joint_one_opening_accepts_two_and_four_piece_claims_and_rejects_mutations",
                     "split_witness_global_histograms_remove_only_the_old_padding_queries"]:
            assert name in out,name
        if label!="sol-r14-builders-1":assert out.count("R14_NATIVE_GROUPS {")==4
    (HERE/(label+".validated.done")).write_text("0\n")
    print(json.dumps({"status":"R14 component gate PASS","source":pin["tree_sha256"]}),flush=True)


if __name__=="__main__":main()
