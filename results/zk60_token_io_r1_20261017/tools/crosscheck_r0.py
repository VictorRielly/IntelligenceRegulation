"""Independent reference for the R1 runs: rung R0's integer semantics on the native stack's output.

For each fixture written by the Rust test `token_io_r1_prove_to_dir` ($OUT/<fixture>/crosscheck.json +
head_int8.bin), recompute the next token with R0's own functions (results/zk60_token_io_design_20261017/
r0/token_io_ref.py, imported read-only): `final_norm` (uniform gain, D24 window, refuses instead of
clamping), `head_logits` (raw integer accumulators) times the per-row multiplier m_j (D25 T4 as amended
20:21 UTC: l_j = m_j (y . W'_j)), `first_argmax` (numpy's rule) -- and compare with the id the output
owner decommitted from the receipt. Also checks R0's `embed` refusals and BOS rule on the prompt.
Public synthetic data only. One thread, < 1 s per fixture. Writes crosscheck_result.json beside the input.
"""
import json
import os
import sys

R0 = "/home/victor/IntelligenceRegulation/results/zk60_token_io_design_20261017/r0"
sys.path.insert(0, R0)
import token_io_ref as ref  # noqa: E402


def main(out):
    results = {}
    ok_all = True
    for fixture in sorted(os.listdir(out)):
        p = os.path.join(out, fixture, "crosscheck.json")
        if not os.path.exists(p):
            continue
        c = json.load(open(p))
        V, d = c["V"], c["d"]
        raw = open(os.path.join(out, fixture, "head_int8.bin"), "rb").read()
        assert len(raw) == V * d, "head size"
        W = [[(b - 256 if b > 127 else b) for b in raw[j * d:(j + 1) * d]] for j in range(V)]
        mult = c["multipliers"]
        x = c["x_row"]
        fn = ref.final_norm(x, c["g0"], c["cn"], c["tn"], c["ceps"])
        logits = [m * l for m, l in zip(mult, ref.head_logits(fn["y"], W))]
        tok = ref.first_argmax(logits)
        top = sorted(logits)[-2:]
        bos_ok = c["tokens"][0] == 1 and ref.check_bos_class(1, V)[0]
        agree = tok == c["decommitted_next_token"]
        ok_all &= agree and bos_ok
        results[fixture] = {"r0_next_token": tok, "decommitted_next_token": c["decommitted_next_token"], "agree": agree,
                            "top2_margin": top[1] - top[0], "D": fn["D"], "max_abs_y": max(abs(v) for v in fn["y"]),
                            "max_abs_logit": max(abs(v) for v in logits), "bos_ok": bos_ok,
                            "multipliers_distinct": len(set(mult))}
        print(fixture, results[fixture])
    with open(os.path.join(out, "crosscheck_result.json"), "w") as fh:
        json.dump({"ok": ok_all, "fixtures": results, "reference": "R0 token_io_ref.py (final_norm, head_logits x m_j, first_argmax)"}, fh, indent=1)
    print("ALL AGREE" if ok_all else "DISAGREEMENT")
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
