"""Independent reference for the R3 run: rung R0's integer semantics on the 8B export's own last-layer output.

For each run written by the Rust test `token_io_r3_prove_to_dir` ($OUT/<tables>-<seq>/crosscheck.json), recompute the
next token from PUBLIC data only, with R0's own functions (results/zk60_token_io_design_20261017/r0/token_io_ref.py,
imported read-only) and numpy for the 128,256-row head:
  * x = the export's seq_<seq>/x_out_L31.bin row T - 1 (the native parity makes it the run's B_out row);
  * `final_norm` (uniform gain, D24 window, refuses instead of clamping);
  * the GENERIC head re-derived here word by word from its definition (murmur3 fmix64 of seed ^ (row << 20 | col),
    exactly as `token_io::tests::hashed_tables`), or the trained head files when the run used them;
  * logits l_j = m_j (y . W'_j), `first_argmax` (numpy's rule).
Compares with the id the output owner decommitted from the receipt. Writes crosscheck_result.json beside the runs.
Chunked (2,048 head rows at a time); one process, about a minute for the generic head.
"""
import json
import os
import sys

import numpy as np

R0 = "/home/victor/IntelligenceRegulation/results/zk60_token_io_design_20261017/r0"
sys.path.insert(0, R0)
import token_io_ref as ref  # noqa: E402

EXPORT = "/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_T32"
M64 = np.uint64(0xFFFFFFFFFFFFFFFF)


def fmix64(u):
    u = u ^ (u >> np.uint64(33))
    u = u * np.uint64(0xFF51AFD7ED558CCD)
    u = u ^ (u >> np.uint64(33))
    u = u * np.uint64(0xC4CEB9FE1A85EC53)
    u = u ^ (u >> np.uint64(33))
    return u


def generic_head_rows(seed, r0, r1, d):
    rows = np.arange(r0, r1, dtype=np.uint64)[:, None]
    cols = np.arange(d, dtype=np.uint64)[None, :]
    with np.errstate(over="ignore"):
        w = (fmix64(np.uint64(seed) ^ ((rows << np.uint64(20)) | cols)) % np.uint64(254)).astype(np.int64) - 127
    return np.where(w >= 0, w + 1, w)


def generic_mult(seed, v):
    with np.errstate(over="ignore"):
        return 1 + (fmix64(np.uint64(seed) ^ np.arange(v, dtype=np.uint64)) % np.uint64(4096)).astype(np.int64)


def main(out, head_dir=None):
    results = {}
    ok_all = True
    for run in sorted(os.listdir(out)):
        p = os.path.join(out, run, "crosscheck.json")
        if not os.path.exists(p):
            continue
        c = json.load(open(p))
        V, d, T, seq = c["V"], c["d"], len(c["tokens"]), c["seq"]
        xs = np.fromfile(os.path.join(EXPORT, f"seq_{seq}", "x_out_L31.bin"), dtype="<i2").reshape(T, d)
        x = [int(v) for v in xs[T - 1]]
        fn = ref.final_norm(x, c["g0"], c["cn"], c["tn"], c["ceps"])
        y = np.array(fn["y"], dtype=np.int64)
        if c["tables"] == "generic":
            _, seed_h, seed_m = c["hash_seeds"]
            m = generic_mult(seed_m, V)
            rows = lambda r0, r1: generic_head_rows(seed_h, r0, r1, d)  # noqa: E731
        else:
            W8 = np.fromfile(os.path.join(head_dir, "head_int8_perrow.bin"), dtype=np.int8).reshape(V, d)
            m = np.fromfile(os.path.join(head_dir, "head_mult12.bin"), dtype="<i8")
            rows = lambda r0, r1: W8[r0:r1].astype(np.int64)  # noqa: E731
        acc = np.concatenate([rows(r, min(V, r + 2048)) @ y for r in range(0, V, 2048)])
        r0_rows = ref.head_logits(fn["y"], [[int(v) for v in rows(j, j + 1)[0]] for j in range(16)])
        assert list(acc[:16]) == r0_rows, "the vectorised head is not R0's"
        logits = m * acc
        tok = ref.first_argmax([int(v) for v in logits])
        assert tok == int(np.argmax(logits))
        top = np.sort(logits)[-2:]
        agree = tok == c["decommitted_next_token"]
        ok_all &= agree
        results[run] = {"r0_next_token": tok, "decommitted_next_token": c["decommitted_next_token"], "agree": agree,
                        "top2_margin": int(top[1] - top[0]), "D": fn["D"], "max_abs_y": int(np.abs(y).max()),
                        "max_abs_logit": int(np.abs(logits).max()), "prompt_bos": c["tokens"][0] == 128000}
        print(run, results[run])
    with open(os.path.join(out, "crosscheck_result.json"), "w") as fh:
        json.dump({"ok": ok_all, "runs": results, "reference": "R0 token_io_ref.py (final_norm, head_logits x m_j, first_argmax) on the 8B export's x_out_L31 row T-1"}, fh, indent=1)
    print("ALL AGREE" if ok_all else "DISAGREEMENT")
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None))
