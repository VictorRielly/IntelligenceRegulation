#!/usr/bin/env python3
"""P-18 (R7): check the two input copies against the calibration export.
  - the prover-private seq dir = the export's seq_ho00/, file for file;
  - the verifier export = the export minus every top-level seq_* entry
    (the native rule, trained_block_tests::verifier_copy), file for file,
    and holding no seq_* entry at all.
Writes inputs.json (counts, the sha256 of each sha256 list, ok) and the two
sha256 lists next to this script; never overwrites. No file content is printed.
    python3 check_inputs.py"""
import hashlib, json, os, sys
E = os.path.dirname(os.path.abspath(__file__))
X = "/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32"
SEQ = "/home/victor/zk60-artifacts/tinyllama-cli-r7-seq-ho00"
VER = "/home/victor/zk60-artifacts/tinyllama-cli-r7-verifier-export"
outs = {k: os.path.join(E, n) for k, n in (("json", "inputs.json"), ("seq", "inputs.seq-ho00.sha256"), ("ver", "inputs.verifier-export.sha256"))}
for f in outs.values():
    if os.path.exists(f):
        raise SystemExit(f"{f} exists")


def tree(root, skip_top_seq=False):
    out = {}
    for dp, dn, fn in os.walk(root):
        if skip_top_seq and dp == root:
            dn[:] = [d for d in dn if not d.startswith("seq_")]
            fn = [f for f in fn if not f.startswith("seq_")]
        for n in fn:
            p = os.path.join(dp, n)
            assert not os.path.islink(p), p
            out[os.path.relpath(p, root)] = hashlib.sha256(open(p, "rb").read()).hexdigest()
    return out


src_seq = tree(os.path.join(X, "seq_ho00"))
src_ver = tree(X, skip_top_seq=True)
got_seq = tree(SEQ)
got_ver = tree(VER)
seq_in_ver = sorted(e for e in os.listdir(VER) if e.startswith("seq_"))
lines = lambda t: "".join(f"{d}  {p}\n" for p, d in sorted(t.items()))
open(outs["seq"], "w").write(lines(got_seq))
open(outs["ver"], "w").write(lines(got_ver))
doc = {
    "seq_dir": SEQ, "seq_files": len(got_seq), "seq_equal_to_export_seq_ho00": got_seq == src_seq,
    "verifier_export": VER, "verifier_files": len(got_ver), "verifier_equal_to_export_minus_seq": got_ver == src_ver,
    "verifier_seq_entries": seq_in_ver,
    "seq_list_sha256": hashlib.sha256(open(outs["seq"], "rb").read()).hexdigest(),
    "verifier_list_sha256": hashlib.sha256(open(outs["ver"], "rb").read()).hexdigest(),
}
doc["ok"] = doc["seq_equal_to_export_seq_ho00"] and doc["verifier_equal_to_export_minus_seq"] and not seq_in_ver
json.dump(doc, open(outs["json"], "w"), indent=1)
print(json.dumps(doc, indent=1))
sys.exit(0 if doc["ok"] else 1)
