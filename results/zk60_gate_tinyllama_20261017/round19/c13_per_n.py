#!/usr/bin/env python3
"""[gate round 19] C-13 PER n (REVIEW_R14 §10 / REVIEW_R16 §10 item 4) on the R13 stack: for every
round-19 capture, from frozen tools v22's gate record and the capture itself:

1. the input endpoint / IN-C joint view: the public KNOWN words (the template
   P0 + S and the pad positions T - P0 - n - S) and the hidden words (n), read
   from the CAPTURED template indicator pi and ids kappa (INC-01's public
   tables) and compared with (T, P0, n, S, pad); the joint figure and the
   tok component's per-word figure, summed over the hidden and over the known
   positions; the per-commitment and CFS figures at that n;
2. the blocks: the block shape is the same at every n (T = t_pad = 32 rows in
   every block: no T < T_pad, no padded row >= T at the rung, so the pad rows
   are ordinary hidden rows of every block plane);
3. the verdict-row opening: B_out's OUTC-00 claim decoded to its row, = P0 + n
   + S - 1 at each n; the B_out claims with fixed row bits (only OUTC-00's);
   row T - 1 opened at a fixed point only when n is the plan size;
4. the receipt's length (segment bytes per stage) at each n.

A frozen-v21 gate record with disclosed dimension 0 over ALL data words
(every word unknown) implies 0 over the hidden words with the known words
fixed as constants: the view's distribution does not depend on the data
anywhere, so it does not on the subset either (the masks are independent of
the data). The table below shows the figure at each n.

Reads JSON and the captures only; uses frozen tools v21 for the capture reader.

    python3 c13_per_n.py <out.json>
"""
import glob
import json
import os
import sys

E = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
P = E + "/round19"
CAP = "/home/victor/zk60-artifacts/token-io/captures"
sys.path.insert(0, "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v22/scripts")
import zk60_native_rg_classgate as CG  # noqa: E402
import zk60_native_rg_classify as CL  # noqa: E402
import zk60_native_rg_tokenterminals as TT  # noqa: E402


def L(p):
    with open(p) as fh:
        return json.load(fh)


def one(rec_path):
    d = L(rec_path)
    name = d["bundle"]
    b = CG.load(os.path.join(CAP, name))
    g, cf = b.geom, b.run["classify"]
    T, p0, n, s = g.tokens, g.p0, g.n, g.s
    pad = b.profile_fields["pad_id"]
    q = b.stages[0].doc["arguments"][CL.SIC_QZC]["tables"]
    pubs = [t for t in q if t["kind"] == "public"]          # supp, u0, pi, kappa, ctl_q
    # [v22] a capture without public-table values (the real Shieldstral one, length + digest only):
    # pi / kappa are the gate's REBUILT tables, which its record shows equal to the capture's digests
    try:
        pi = TT.captured_values(pubs[2])
        kap = TT.captured_values(pubs[3])
        if pi is None or kap is None:
            raise ValueError("no values in the capture")
        values_from = "the capture's own public-table values"
    except Exception:  # noqa: BLE001
        if not d["one_public_bit"].get("rebuilt_public_tables_all_equal_the_capture"):
            raise
        tp = 1 << max(1, (T - 1).bit_length())
        pi = [(1, 0) if (t < p0 or p0 + n <= t < T) else (0, 0) for t in range(tp)]
        pre, suf = cf["policy"]["prefix_ids"], cf["policy"]["suffix_ids"]
        kap = [((pre[t] if t < p0 else suf[t - p0 - n] if p0 + n <= t < p0 + n + s else pad if t < T else 0) % (2 ** 64 - 2 ** 32 + 1), 0)
               if (t < p0 or p0 + n <= t < T) else (0, 0) for t in range(tp)]
        values_from = "REBUILT from (T, P0, n, S, the policy's ids, pad id); the record: every rebuilt public table equals the capture's digest"
    known_pos = [t for t in range(T) if pi[t] == (1, 0)]
    hidden_pos = [t for t in range(T) if pi[t] == (0, 0)]
    pad_pos = list(range(p0 + n + s, T))
    want_known = list(range(p0)) + list(range(p0 + n, T))
    f = []
    if known_pos != want_known:
        f.append(f"pi's ones {known_pos} are not the template + pad positions {want_known}")
    if hidden_pos != list(range(p0, p0 + n)):
        f.append("pi's zeros are not the content positions")
    if any(kap[t] != (pad, 0) for t in pad_pos):
        f.append("kappa at a pad position is not the public pad id")
    if any(x != (0, 0) for x in pi[T:]):
        f.append("pi is nonzero beyond T")
    j = d["G1_joint"]
    tok = [c for c in j["components"] if set(c["commitments"]) == {"A-in@0", "E-token-in"}]
    per_word = tok[0]["joint_disclosed_fp_per_word"] if len(tok) == 1 else None
    if len(tok) != 1 or tok[0]["word_positions"] != T:
        f.append(f"the tok component is not one signature over the T = {T} word positions")
    g2 = d["G2_claim_points"]["claims"]["B_out"]["claims"]
    fixed_row_claims = [{"claim": c["claim"], "source": c["source"], "public_bits": c["public_bits"]} for c in g2 if c["public_bits"] > 0]
    vr = d["integrity"].get("bout_claim_row", {}).get("row")
    segs = [st.doc["segment_bytes"] for st in b.stages]
    sh = dict(b.run["shape"])
    return {
        "bundle": name, "status": d["status"], "blocks": d["blocks"], "verdict": cf["verdict"], "c": cf["policy"]["c"],
        "n": n, "T": T, "P0": p0, "S": s, "pad_id": pad, "pad_positions": len(pad_pos),
        "IN_C_known_words": {"template": p0 + s, "pad": len(pad_pos), "total": len(known_pos)},
        "IN_C_hidden_words": len(hidden_pos),
        "joint": {"joint_disclosed_fp": j["joint_disclosed_fp"], "identified_word_pairs": j["identified_word_pairs"],
                  "tok_component_per_word": per_word,
                  "over_hidden_words": None if per_word is None else per_word * len(hidden_pos),
                  "over_known_words": None if per_word is None else per_word * len(known_pos)},
        "per_commitment_disclosed": sorted({(r["role"], r["disclosed_dimension"]) for r in d["G1_per_commitment"]["per_commitment"]}),
        "cfs": [[x["stage_kind"], x["entries_recomputed"], x["entries_differing"], x.get("functional_values")] for x in d["G3_mask_cfs"]["per_stage"]],
        "full_preimage": [(d.get("full_preimage") or {}).get("view_entries_compared"), (d.get("full_preimage") or {}).get("view_entries_differing")],
        "block_stage_slots": [[x.get("slot_checks_equal"), x.get("slot_checks_expected")] for x in d["terminals_block_stages"].get("per_stage", [])],
        "block_shape": {k: sh[k] for k in ("tokens", "t_pad", "width", "d_pad", "n_slots")},
        "verdict_row": {"expected": p0 + n + s - 1, "B_out_OUTC00_claim_row": vr,
                        "claims_with_fixed_row_bits": fixed_row_claims,
                        "row_T_minus_1_opened_at_a_fixed_point": vr == T - 1},
        "segment_bytes": segs, "pi_kappa_values_from": values_from, "findings": f,
        "ok": not f and d["status"] in ("PASS", "PASS-WITH-DECLARED-LIMITS"), "status_detail": d["status"],
    }


def main(out):
    rows = []
    for p in sorted(glob.glob(P + "/v22/v22-*.json")):
        if p.endswith(".guard.json"):
            continue
        rows.append(one(p))
    by_n = {}
    for r in rows:
        by_n.setdefault(r["n"], []).append(r["bundle"])
    shapes = {json.dumps(r["block_shape"], sort_keys=True) for r in rows if r["T"] == 32}
    segs = {(r["blocks"], tuple(r["segment_bytes"])) for r in rows if r["T"] == 32}
    seg_by_l = {}
    for l_, sg in segs:
        seg_by_l.setdefault(l_, set()).add(sg)
    doc = {"what": __doc__.strip().splitlines()[0], "privacy_acceptance": False, "rows": rows,
           "n_values": sorted(by_n), "captures_per_n": by_n,
           "block_shape_identical_at_every_n": len(shapes) == 1, "block_shapes": sorted(shapes),
           "receipt_segment_bytes_independent_of_n": all(len(v) == 1 for v in seg_by_l.values()),
           "segment_bytes_per_L": {str(k): sorted(list(v)) for k, v in seg_by_l.items()},
           "all_ok": bool(rows) and all(r["ok"] for r in rows),
           "joint_over_hidden_words_zero_at_every_n": all(r["joint"]["over_hidden_words"] == 0 for r in rows),
           "verdict_row_moves_with_n": all(r["verdict_row"]["B_out_OUTC00_claim_row"] == r["verdict_row"]["expected"] for r in rows)}
    with open(out, "w") as fh:
        json.dump(doc, fh, indent=1, default=str)
    for r in sorted(rows, key=lambda x: (x["blocks"], x["n"], x["bundle"])):
        print(f"L{r['blocks']} n={r['n']:2d} v{r['verdict']} known {r['IN_C_known_words']['total']:2d} (pad {r['pad_positions']:2d}) "
              f"hidden {r['IN_C_hidden_words']:2d} joint {r['joint']['joint_disclosed_fp']} hidden-joint {r['joint']['over_hidden_words']} "
              f"row {r['verdict_row']['B_out_OUTC00_claim_row']} fixed-claims {r['verdict_row']['claims_with_fixed_row_bits']} "
              f"segs {r['segment_bytes']} {r['status']} {r['findings'][:1]} {r['bundle']}")
    print({k: doc[k] for k in ("n_values", "block_shape_identical_at_every_n", "receipt_segment_bytes_independent_of_n",
                               "all_ok", "joint_over_hidden_words_zero_at_every_n", "verdict_row_moves_with_n")})


if __name__ == "__main__":
    main(sys.argv[1])
