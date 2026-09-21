"""Clause C6 and clause C2 against a REAL bundle.

C6 says slot `s` contributes exactly `1 + (main+ext)(degree+1) + terms` Fp2
words to the receipt (`shape.rs:938`, `wire.rs:106/150-155/225-231`).  The
memo checks that against its own model of the shape; this checks it against
the words a real prover actually wrote, in the committed capture
`run-i-dense-k4` (rung-K4, fully dense generic witness), stage 0.

It also re-runs the sumcheck chain of all 23 slots from the capture's own
published fields alone -- scalar, rounds, terminals -- which is clause C2
exercised rather than argued, independently of the run gate's tools.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fp2 import F2, ONE, ZERO, P  # noqa: E402
from flip_miniature import interpolate_eval  # noqa: E402

CAP = "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920"
LANE = "/home/victor/wt-zk60-block125m/results/zk60_block125m_lane"


def f2(v):
    return F2(v[0], v[1])


def check(bundle, stage, model):
    d = json.load(open(f"{CAP}/{bundle}/stage-{stage:02d}.json"))
    sl = [(s["main_rounds"], s["extension_rounds"], s["degree"]) for s in model["slots"]]
    rows, total_words = [], 0
    chain_ok = 0
    sched_ok = 0
    for a in d["arguments"]:
        s = a["slot"]
        m, e, deg = a["main"], a["extension"], a["degree"]
        sched_ok += int((m, e, deg) == sl[s])
        words = 1 + sum(len(r) for r in a["rounds"]) + len(a["terminals"])
        formula = 1 + (m + e) * (deg + 1) + len(a["terminals"])
        # the chain, from the published view alone (sumcheck.rs:135-160)
        claim = f2(a["claimed_sum"])
        ok = True
        for j, r in enumerate(a["rounds"]):
            if len(r) != deg + 1:
                ok = False
                break
            v = [f2(x) for x in r]
            if not (v[0] + v[1] == claim):
                ok = False
                break
            claim = interpolate_eval(v, f2(a["rho"][j]))
        ok = ok and (claim == f2(a["sumcheck_final"]))
        # the verifier's own terminal identity: fin = c*mask_eval + poly(vals)
        ident = (f2(a["sumcheck_final"]) ==
                 f2(a["c"]) * f2(a["mask_eval"]) + f2(a["terminal_polynomial"]))
        chain_ok += int(ok and ident)
        rows.append({"slot": s, "name": a["name"], "main": m, "ext": e, "degree": deg,
                     "rounds_published": len(a["rounds"]),
                     "round_widths": sorted({len(r) for r in a["rounds"]}),
                     "terminals": len(a["terminals"]),
                     "words_counted": words, "words_formula": formula,
                     "match": words == formula,
                     "chain_and_terminal_identity": ok and ident,
                     "hosted": len(a["hosted"]), "tables": len(a["tables"])})
        total_words += words
    return rows, total_words, chain_ok, sched_ok, d


def main():
    model = json.load(open(f"{LANE}/model_rung_k4.json"))
    rows, total, chain_ok, sched_ok, d = check("run-i-dense-k4", 0, model)
    mismatch = [r for r in rows if not r["match"]]
    print(f"[MEASURED] run-i-dense-k4 stage 0 (rung-K4), {len(rows)} slots")
    print(f"  slot schedule (main,ext,degree) equals the shape model: {sched_ok}/{len(rows)}")
    print(f"  words counted == 1 + N(d+1) + terms:                    "
          f"{len(rows) - len(mismatch)}/{len(rows)}")
    print(f"  chain + terminal identity from published fields alone:  {chain_ok}/{len(rows)}")
    print(f"  total slot words = {total}  ({total * 16} B); model predicts "
          f"{sum(1 + (a+b)*(c+1) + t for (a,b,c),t in zip([(s['main_rounds'],s['extension_rounds'],s['degree']) for s in model['slots']], [r['terminals'] for r in rows]))}")
    for s in (8, 9, 14, 17):
        r = rows[s]
        print(f"  slot {s:02d} {r['name'][:34]:34s} N={r['main']+r['ext']:2d} d={r['degree']} "
              f"terms={r['terminals']:2d} words={r['words_counted']:3d} "
              f"(formula {r['words_formula']:3d}) tables={r['tables']:2d}")
    # what else the receipt carries per slot: the wire writes scalar, rounds,
    # terms and nothing else (wire.rs:394-398), so compare the segment bytes.
    out = {"bundle": "run-i-dense-k4", "stage": 0, "rows": rows,
           "total_slot_words": total, "total_slot_bytes": total * 16,
           "segment_bytes": d["segment_bytes"],
           "schedule_matches": sched_ok, "chain_ok": chain_ok}
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bundle_words.json")
    json.dump(out, open(p, "w"), indent=1)
    print(f"  segment_bytes = {d['segment_bytes']}, of which slot words "
          f"{total*16} B = {100.0*total*16/d['segment_bytes']:.2f}%")


if __name__ == "__main__":
    main()
