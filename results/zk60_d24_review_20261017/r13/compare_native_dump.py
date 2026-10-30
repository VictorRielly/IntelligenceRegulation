"""D24 review R13: compare a native witness dump (review_r13_tests.rs `dump`, dense
order) with the reviewer's independent reference trace, site by site.

Usage: python3 compare_native_dump.py <native.tsv> <reference .npy dict | .npz> <export_dir> <layer> <stack low|h24> <out.json>
a_scaled is compared as a_raw * 2^(24 - sh_h + e_out(group) - e_out(base)), the
spec's exact byte-aligned scaling, computed here from the export's public group data.
"""
import json
import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import reviewer_export_reference as R  # noqa: E402


def main():
    tsv, ref, export, layer, stack, outp = sys.argv[1:7]
    native = {}
    for line in open(tsv):
        c = line.rstrip("\n").split("\t")
        native[c[0]] = np.array([int(v) for v in c[1:]], dtype=np.int64)
    tr = np.load(ref, allow_pickle=True)
    tr = tr.item() if ref.endswith(".npy") else dict(tr)
    m = json.load(open(f"{export}/layer_{int(layer):02d}/manifest.json"))
    arr = lambda k: np.fromfile(f"{export}/layer_{int(layer):02d}/{m['arrays'][k]['file']}", dtype=np.int64)
    groups = [tuple(g) for g in arr("silu_groups").reshape(-1, 2).tolist()]
    bout = m["constants"]["silu_member"][1]
    exps = np.array([24 - m["constants"]["sh_h"] + groups[g][1] - bout for g in arr("silu_group_ids")], dtype=np.int64)
    mine = {
        "x": tr["x"], "y": tr["y"], "q": tr["q"], "k": tr["k"], "v": tr["v"], "qr": tr["qr"], "kr": tr["kr"],
        "s": tr["s"], "p": tr["p"], "o": tr["o"], "ao": tr["ao"], "x1": tr["x1"], "nm": tr["nm"], "gate": tr["gate"],
        "a_scaled": tr["a_raw"] << exps[None, :], "u": tr["u"], "h": tr["h"], "z": tr["z"], "x2": tr["x2"],
    }
    res = {"native": tsv, "stack": stack, "sites": {}}
    for k, v in mine.items():
        a = np.asarray(v).reshape(-1)
        b = native[k]
        res["sites"][k] = {"n": int(a.size), "differ": int((a != b).sum()) if a.size == b.size else f"size {a.size} vs {b.size}",
                           "min": int(a.min()), "max": int(a.max()), "nonzero": int((a != 0).sum())}
    res["all_equal"] = all(s["differ"] == 0 for s in res["sites"].values())
    json.dump(res, open(outp, "w"), indent=1)
    print(json.dumps(res))


if __name__ == "__main__":
    main()
