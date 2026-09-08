#!/usr/bin/env python3
"""FA8 -- exact structural checks behind the transcript simulator of
docs/zkmatrix-poc/ZK60_FABLE_TRANSCRIPT_REVIEW.md, and the machine-readable
disposition table of that document.  Reviewer: Claude Fable 5.1, 2026-09-08.

The simulator of the review (section B) commits the CFS mask matrix M FIRST
(uniformly random a-rows, real pads and salts), programs only the sumcheck
ROUND challenges, and samples every slot's round messages on the fibre
{claim, fin} of FA6's consistency subspace S, with fin := want(m_t) + c g(rho)
for the g(rho) the committed M actually has.  That is a valid simulator only
because of three exact facts that FA6/FA3 do not state, checked here:

  1. (fibre)  for EVERY challenge sequence, the two mask functionals
     (G = sum g, g(rho)) are linearly independent, so (claim, fin) is uniform on
     Fp2^2 both honestly and in the simulator, and the last-round map
     Delta_{N-1} -> h_{N-1}(r_{N-1}) is onto Fp2 for every last challenge, so
     the fibre is non-empty and uniformly samplable round by round;
  2. (k slots) FA4's budgeted stable W: k proofs against ONE commitment, each
     using its own slot's pair rows while every proof's proximity vector
     touches ALL rows, disclose no W functional jointly (FA2's exact rank),
     and a reused or copied slot does (negative control);
  3. (pad budget) the opened coset positions of one row across k openings are
     hidden exactly when |J| <= q_pad (Vandermonde x Z_n on the coset), and
     |J| - q_pad functionals of the row leak beyond it (negative control).

Plus the exact statistical distance of ZkRng::fp / Transcript::challenge_fp
(a 128-bit draw reduced mod p) from uniform, derived, not inherited.

Field code, elimination and the CFS weight rows are imported by path from
FA2's and FA6's tools (nothing duplicated).  Exact integer arithmetic only.

    python3 scripts/zk60_fable_transcript_sim.py report -o results/zk60_fable_fa8_transcript_sim.json
    python3 scripts/zk60_fable_transcript_sim.py disposition -o results/zk60_fable_fa8_disposition.json
"""
import argparse
import hashlib
import importlib.util
import json
import math
import sys
from fractions import Fraction
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent


def _load(name: str):
    spec = importlib.util.spec_from_file_location(name, HERE / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


R = _load("zk60_fable_joint_rank")   # FA2: field, Model, analyze, rank
C = _load("zk60_fable_cfs_channel")  # FA6: CFS weights, Fp2 rank, coset helpers

P = R.P
ONE, ZERO, U = R.ONE, R.ZERO, R.U
f2, f2_add, f2_sub, f2_mul, f2_mul_base, f2_is_zero = R.f2, R.f2_add, R.f2_sub, R.f2_mul, R.f2_mul_base, R.f2_is_zero
Fp2 = Tuple[int, int]

REVIEWER = "Claude Fable 5.1, independent privacy reviewer, 2026-09-08 session (FA8)"
SOURCE_PIN = {"worktree_head": "ed478da", "codex_merge": "972da4e", "fa6_fa7_pin": "cfa46f6"}


# ----------------------------------------------------------------------------
# 1. the fibre facts (section B of the review)
# ----------------------------------------------------------------------------


def functional_pair_rank(n: int, d: int, rho: Sequence[Fp2]) -> int:
    """rank over Fp2 of [sum_weights ; eval_weights(rho)]: 2 iff (G, g(rho)) are
    independent functionals of the mask coefficients."""
    return C.f2_rank([list(C.cfs_sum_weights(n, d)), list(C.cfs_eval_weights(rho, d))])


def last_round_map(d: int, r: Fp2) -> List[Fp2]:
    """Coefficients of Delta(1..d) in h(r) when h(0) = (prev - Delta(1)) / 2:
    [L_1(r) - 1/2, L_2(r), ..., L_d(r)].  Nonzero <=> the map is onto Fp2."""
    lam = C.lagrange_weights(d, r)
    out = [f2_sub(lam[1], f2(C.HALF))]
    out.extend(lam[2:])
    return out


def degenerate_sequences(n: int, rng: R.Rng) -> Dict[str, List[Fp2]]:
    seqs = {
        "all_zero": [ZERO] * n,
        "all_one": [ONE] * n,
        "last_zero": [rng.fp2() for _ in range(n - 1)] + [ZERO],
        "last_one": [rng.fp2() for _ in range(n - 1)] + [ONE],
        "last_two": [rng.fp2() for _ in range(n - 1)] + [f2(2)],
        "all_half": [f2(C.HALF)] * n,
        "random": [rng.fp2() for _ in range(n)],
    }
    return seqs


def fibre_report(rng: R.Rng, shapes: Sequence[Tuple[int, int]] = ((2, 2), (3, 2), (4, 3), (5, 4), (6, 4), (10, 4))) -> Dict:
    rows = []
    ok = True
    for n, d in shapes:
        for name, rho in degenerate_sequences(n, rng).items():
            rk = functional_pair_rank(n, d, rho)
            onto = not all(f2_is_zero(x) for x in last_round_map(d, rho[-1]))
            rows.append({"n_vars": n, "degree": d, "challenges": name, "rank_G_and_g_rho": rk, "last_round_onto": onto})
            ok = ok and rk == 2 and onto
    # the batched pair as coded: (G_gu, g_gu(rho_gu), G_20, g_20(rho_20)) over the two masks' unknowns
    batched = []
    for (n1, d1, n2, d2) in ((5, 2, 10, 4), (6, 2, 6, 4), (9, 2, 17, 4)):
        for name in ("all_zero", "all_one", "random"):
            r1 = degenerate_sequences(n1, rng)[name]
            r2 = degenerate_sequences(n2, rng)[name]
            L1, L2 = C.cfs_len(n1, d1), C.cfs_len(n2, d2)
            rows4 = [
                list(C.cfs_sum_weights(n1, d1)) + [ZERO] * L2,
                list(C.cfs_eval_weights(r1, d1)) + [ZERO] * L2,
                [ZERO] * L1 + list(C.cfs_sum_weights(n2, d2)),
                [ZERO] * L1 + list(C.cfs_eval_weights(r2, d2)),
            ]
            rk = C.f2_rank(rows4)
            batched.append({"pair": [n1, d1, n2, d2], "challenges": name, "rank": rk})
            ok = ok and rk == 4
    # the last-round map for every small integer last challenge and d in 2..4
    small = []
    for d in (2, 3, 4):
        for r in range(0, d + 2):
            onto = not all(f2_is_zero(x) for x in last_round_map(d, f2(r)))
            small.append({"degree": d, "r_last": r, "onto": onto})
            ok = ok and onto
    return {
        "statement": "for every challenge sequence (G, g(rho)) has rank 2 and Delta_{N-1} -> h_{N-1}(r_{N-1}) is onto Fp2, so the honest (claim, fin) is uniform on Fp2^2 and the simulator's fibre sampling reproduces it (review section B, step 5)",
        "single_slot": rows, "batched_pairs": batched, "last_round_small_challenges": small, "all_ok": ok,
    }


# ----------------------------------------------------------------------------
# 2. FA4's k slots against one Merkle root (section F2 of the review)
# ----------------------------------------------------------------------------


def stable_w_model(n_cols: int, rw: int, k_slots: int, proofs: Sequence[int], seed: int, copy_slot_from: Optional[int] = None) -> R.Model:
    """A tiny P3 W commitment (nb_d = nb_f = 1: blocks Wg, Wu, Wd of `rw` rows
    each, n_cols columns) with `k_slots` FA3-repaired slot sets (w_mgu pairs
    for Wg, Wu; a w_mdd pair for Wd; a w_prox pair), and one proof per entry
    of `proofs` (the slot index that proof declares).  Every proof draws fresh
    coefficients (points, lambdas, e/e2, prox rhos); its group vectors and
    terminals use ITS slot's pairs; its proximity vector touches EVERY row of
    the commitment (data and all slots), as `zk_rhos` does.
    `copy_slot_from = s` makes slot s's pair rows the SAME unknowns as slot 0's
    (the AM4-style copied-pair hazard across slots)."""
    rng = R.Rng(seed)
    m = R.Model(f"stable W: {k_slots} slots, proofs on slots {list(proofs)}")
    log_n = n_cols.bit_length() - 1
    assert 1 << log_n == n_cols
    blocks = ["Wg", "Wu", "Wd"]
    all_rows: List[str] = []
    for b in blocks:
        for r in range(rw):
            pre = f"{b}/D{r}"
            all_rows.append(pre)
            for j in range(n_cols):
                m.data_unknown(f"{pre}[{j}]")
    slot_rows: List[Dict[str, Tuple[str, str]]] = []
    for s in range(k_slots):
        rows: Dict[str, Tuple[str, str]] = {}
        src = 0 if (copy_slot_from is not None and s == copy_slot_from and s != 0) else s
        for site in ("mgu_g", "mgu_u", "mdd", "prox"):
            pre_re, pre_im = f"slot{src}/{site}/re", f"slot{src}/{site}/im"
            rows[site] = (pre_re, pre_im)
            if src == s:
                for pre in (pre_re, pre_im):
                    all_rows.append(pre)
                    for j in range(n_cols):
                        m.mask_unknown(f"{pre}[{j}]")
        slot_rows.append(rows)
    for i, s in enumerate(proofs):
        rows = slot_rows[s]
        for gname, members in (("p3", [("Wg", "mgu_g"), ("Wu", "mgu_u")]), ("p6", [("Wd", "mdd")])):
            e, e2 = rng.fp2(), rng.fp2()
            k0 = f2_mul(f2_sub(ONE, e2), f2_sub(ONE, e))   # (1 - e2)(1 - e): the W-side data coefficient
            k1 = e2                                          # the W-side mask coefficient (pair: k1, k1 u)
            cw = R.eq_table_msb(rng.point(log_n))
            vec: List[Dict[str, Fp2]] = [dict() for _ in range(n_cols)]
            for blk, site in members:
                lam = rng.fp2()
                eq = R.eq_table_msb(rng.point(rw.bit_length() - 1)) if rw > 1 else [ONE]
                pre_re, pre_im = rows[site]
                terms: List[Tuple[str, Fp2]] = [(f"{blk}/D{r}", f2_mul(k0, eq[r])) for r in range(rw)]
                terms.append((pre_re, k1))
                terms.append((pre_im, f2_mul(k1, U)))
                value: Dict[str, Fp2] = {}
                for pre, coef in terms:
                    for j in range(n_cols):
                        nm = f"{pre}[{j}]"
                        vec[j][nm] = f2_add(vec[j].get(nm, ZERO), f2_mul(lam, coef))
                        value[nm] = f2_add(value.get(nm, ZERO), f2_mul(coef, cw[j]))
                m.observe(f"proof{i}/value[{gname}/{blk}]", value, role="terminal")
            for j in range(n_cols):
                m.observe(f"proof{i}/v[{gname}][{j}]", vec[j], role="group vector entry")
        for j in range(n_cols):
            m.observe(f"proof{i}/v[prox][{j}]", {f"{pre}[{j}]": rng.fp2() for pre in all_rows}, role="proximity vector entry over every row")
    return m


def k_slot_report(seed: int = 21) -> Dict:
    cases = []
    ok = True

    def run(name: str, k: int, proofs: Sequence[int], expect_zero: bool, copy_from: Optional[int] = None, n_cols: int = 4, rw: int = 2) -> None:
        nonlocal ok
        res = R.analyze(stable_w_model(n_cols, rw, k, proofs, seed, copy_from))
        dd = res["disclosed_dim"]
        rec = {
            "case": name, "k_slots": k, "proofs_declare_slots": list(proofs), "n_cols": n_cols, "rows_per_block": rw,
            "disclosed_dim": dd, "rank_mask": res["rank_mask"], "rank_joint": res["rank_joint"],
            "trivial_identities": res["observation_functionals_killing_masks_but_not_data"],
            "disclosed_W_entries": sorted(res["summary"]["disclosed"] + res["summary"]["recovered"])[:12],
            "expected": "0" if expect_zero else "> 0", "verdict": "PASS" if ((dd == 0) == expect_zero) else "FAIL",
        }
        ok = ok and rec["verdict"] == "PASS"
        cases.append(rec)

    run("one proof, one slot (FA3 whole_W_p3 shape)", 1, [0], True)
    run("two proofs, distinct slots", 2, [0, 1], True)
    run("three proofs, distinct slots, prox over all 3 slot sets", 3, [0, 1, 2], True)
    run("three slots, slot 1 burned (proofs on 0 and 2)", 3, [0, 2], True)
    run("NEGATIVE: two proofs declare the same slot", 2, [0, 0], False)
    run("NEGATIVE: three proofs, slot 1 reused twice", 3, [0, 1, 1], False)
    run("NEGATIVE: slot 1's pair rows are copies of slot 0's (AM4 across slots)", 2, [0, 1], False, copy_from=1)
    run("one proof, one slot, n = 8", 1, [0], True, n_cols=8)
    run("two proofs, distinct slots, n = 8, single-row blocks", 2, [0, 1], True, n_cols=8, rw=1)
    return {
        "statement": "k proofs against one budgeted W commitment, each on its own slot's pairs with the proximity vector over all rows, disclose no W functional jointly; a declared-twice or copied slot leaks W (review section F2, enforcement E1/E3)",
        "cases": cases, "all_ok": ok,
        "caveat": "exact rank under stand-in coefficients over the source's observation structure; the pad/column channel is section 3, the CFS channel FA6, the simulator the review",
    }


# ----------------------------------------------------------------------------
# 3. the pad budget across k openings (sections B step 10 and F2)
# ----------------------------------------------------------------------------


def pad_budget(log_n: int, inv_rate: int, q_pad: int, index_sets: Sequence[Sequence[int]]) -> Dict:
    """One committed row f + Z_n g_pad on the coset 7 G_nn; the union J of the
    opened positions of `index_sets` (with replacement, as challenge_indices);
    the map pad -> (Z_n(x_j) g_pad(x_j))_{j in J} is [Z_n(x_j) x_j^t]; its rank
    is min(|J|, q_pad) and |J| - rank functionals of f(x_J) are in the clear."""
    n, nn = 1 << log_n, (1 << log_n) * inv_rate
    w = C.subgroup_gen(nn)
    pts = [(7 * C._pow(w, j)) % P for j in range(nn)]
    J = sorted(set(j for s in index_sets for j in s))
    assert all(j < nn for j in J)
    zn = [(C._pow(x, n) - 1) % P for x in pts]
    assert all(z != 0 for z in zn), "Z_n vanishes on the coset"
    rows = [[(zn[j] * C._pow(pts[j], t)) % P for t in range(q_pad)] for j in J]
    rk = R.rank(rows) if rows else 0
    return {"n": n, "nn": nn, "q_pad": q_pad, "openings": len(index_sets), "per_opening": [len(s) for s in index_sets],
            "distinct_positions": len(J), "rank": rk, "leaked_functionals_of_the_row": len(J) - rk,
            "hidden": len(J) - rk == 0, "expected_leak": max(0, len(J) - q_pad)}


def pad_budget_report(seed: int = 5) -> Dict:
    rng = R.Rng(seed)

    def draws(q: int, nn: int) -> List[int]:
        return [rng.fp() % nn for _ in range(q)]   # with replacement, like challenge_indices

    cases = []
    ok = True
    for (log_n, rate, Q, k, extra) in ((2, 4, 2, 3, 0), (2, 4, 2, 3, 1), (3, 4, 4, 4, 0), (3, 4, 4, 4, 2), (4, 8, 8, 8, 0), (4, 8, 8, 8, 1), (3, 2, 4, 2, 0)):
        nn = (1 << log_n) * rate
        q_pad = k * Q
        sets = [draws(Q, nn) for _ in range(k + extra)]
        res = pad_budget(log_n, rate, q_pad, sets)
        res["case"] = f"k = {k} budgeted, {k + extra} openings of Q = {Q}"
        res["verdict"] = "PASS" if res["leaked_functionals_of_the_row"] == res["expected_leak"] else "FAIL"
        ok = ok and res["verdict"] == "PASS"
        cases.append(res)
    # a forced-duplicate set: duplicates only shrink J
    res = pad_budget(3, 4, 4, [[1, 1, 1, 1], [1, 5, 5, 9]])
    res["case"] = "duplicates: 8 draws, 3 distinct positions, q_pad 4"
    res["verdict"] = "PASS" if res["hidden"] and res["distinct_positions"] == 3 else "FAIL"
    ok = ok and res["verdict"] == "PASS"
    cases.append(res)
    return {"statement": "the opened positions of a row are hidden by its pads exactly when the number of DISTINCT opened coset positions across all openings is <= q_pad; k openings of Q draws each give <= kQ", "cases": cases, "all_ok": ok}


# ----------------------------------------------------------------------------
# 4. the reduction bias of fp() and challenge_fp(), exactly
# ----------------------------------------------------------------------------


def reduction_bias() -> Dict:
    m = pow(2, 128, P)
    q = (1 << 128) // P
    sd = Fraction(m * (P - m), P * (1 << 128))
    direct = Fraction(1, 2) * (m * abs(Fraction(q + 1, 1 << 128) - Fraction(1, P)) + (P - m) * abs(Fraction(q, 1 << 128) - Fraction(1, P)))
    assert sd == direct
    dep = Fraction(P * P + (P * P - 1) * P, P ** 4)
    return {
        "p": P, "two_pow_128_mod_p": m, "p_minus_m": P - m, "p_minus_m_is_2_pow_32": (P - m) == (1 << 32),
        "sd_fp_from_uniform": {"numerator": sd.numerator, "denominator": sd.denominator, "log2": math.log2(sd)},
        "sd_one_time_pad_shift_bound_log2": math.log2(2 * sd),
        "source_comment_bound_log2": -64.0,
        "prob_two_fp2_fp_dependent_log2": math.log2(dep),
        "prob_uniform_fp2_in_fp_log2": math.log2(Fraction(1, P)),
        "statement": "x mod p for x uniform on [0, 2^128) is within m(p - m) / (p 2^128) = 2^-96 (1 - 2^-32) of uniform, because 2^128 = p - 2^32 (mod p); a one-time pad drawn this way hides its addend up to 2^-95 per Fp coordinate (the source's 2^-64 is a loose bound)",
    }


# ----------------------------------------------------------------------------
# 5. per-proof counts behind the bound (from FA6's and FA3's committed records)
# ----------------------------------------------------------------------------


def counts_from_records(fa6_path: Path, fa3_path: Path) -> Dict:
    out: Dict = {"programmed_round_challenges": [], "fp_draws": []}
    if fa6_path.exists():
        fa6 = json.loads(fa6_path.read_text())
        for e in fa6["slot_table"]:
            out["programmed_round_challenges"].append({"shape": e["shape"], "mode": e["mode"], "slots": len(e["slots"]),
                                                       "sum_n_vars": sum(v["n_vars"] for v in e["slots"].values()),
                                                       "sum_len": sum(v["len"] for v in e["slots"].values())})
    if fa3_path.exists():
        fa3 = json.loads(fa3_path.read_text())
        shapes = {"tiny T2/d16/f16": (5, 12), "tiny T32/d16/f16": (8, 256), "125M d768/f2048": (14, 256), "8B d4096/f14336": (14, 256)}
        for fam, body in fa3["families"].items():
            log_n, Q = shapes.get(fam, (body["layout"]["log_n"], 256))
            n = 1 << log_n
            rows = body["rows"]
            a_rows, h_rows = rows["A"]["repaired_rows"], rows["H"]["repaired_rows"]
            w = rows.get("W_P3", {})
            w_rows_1 = w.get("data_rows", 0) + w.get("repaired_mask_rows_per_slot", 0)
            fp_a = a_rows * (n + Q)
            fp_h = h_rows * (n + Q)
            # M: per slot 2 (re, im) x (L_s coefficients + 256 pads); b, u: 2 x 1024 each -- at the block profile (8 slots) from FA6's table
            fp_m_upper = 2 * 8 * (74 + 256) + 4 * 1024
            out["fp_draws"].append({"family": fam, "n": n, "Q": Q, "A_rows_block": a_rows, "H_rows": h_rows, "W_P3_rows_one_slot": w_rows_1,
                                    "fp_draws_A": fp_a, "fp_draws_H": fp_h, "fp_draws_M_upper": fp_m_upper,
                                    "fp_draws_per_proof_P1_block": fp_a + fp_h + fp_m_upper,
                                    "bias_term_log2_P1_block": math.log2((fp_a + fp_h + fp_m_upper)) - 95})
    return out


# ----------------------------------------------------------------------------
# 6. the disposition table (section G of the review), machine-readable
# ----------------------------------------------------------------------------

PROFILES = ["legacy_v3", "repaired_P1", "repaired_P3_fresh_W", "repaired_P3_stable_W_k_slots", "block_profile"]

BLOCKERS = {
    "B5": "the repaired profile ffn-v3-mr1 does not exist in source and has no capture (FA3 §11 B5); acceptance test FA3 P3 / FA7 schema 2, case 1 -- owner Codex (implement), Fable (run the tools)",
    "S1": "the explicit-seed path ZkConfig.seed = Some(u64) -> ZkRng::new is reachable outside cfg(test) (zk.rs ZkConfig::rng); a 64-bit seed is brute-forceable from one proof's M root; must be refused in production (FA6 I4 clause 2, FA3 §3) -- owner Codex",
    "S2": "FA6's two hardenings: assert mask degree = round degree in zk.rs::extension (I1); prover aborts the attempt on c_s = 0 (I3) -- owner Codex",
    "S3": "FA3 §6's verifier obligations as specified (claims from the layout, exact counts, degeneracy refusals not resamples, seams on the two absorbed A roots, publish-nothing-on-failure) and FA3 §12.2's transcript order -- owner Codex; acceptance FA3 §7 AM1-AM24",
    "E1": "a consuming slot API: no open_zk on C*_l without a ReservedSlot from the journal, the slot index bound into the header and the W claims from that slot's rows, a failed attempt burning its slot (FA4 H3; Codex journal doc: 'no existing prover consumes slots yet') -- owner Codex",
    "E2": "protected secret-material storage and deterministic reconstruction of C*_l (data, pads, salts, k slot sets) bound to the same SlotPolicy digest (H2 second increment) -- owner Codex",
    "E3": "anti-rollback and single-canonical-journal: a restored earlier journal file or a second journal for the same root reuses slots undetected; needs an external monotonic authority or the registry's (D_M, l, i) double-use record (FA4 §4.3 (8)) -- owner application / Victor (product ruling), Codex (hook)",
    "E4": "the changed-rate proximity/soundness bound for RS[nn, n + kQ] at the chosen (k, inv_rate) (FA4 §5.1, FA5 obligation) -- owner FA5/Fable; not a privacy term",
    "A1": "the attention side's mask schedule and observation inventory (A04-A06 not designed, FA3 §14): every attention claim as an FA3 §2.2 row (site, group key, kind, coefficient pair, proof field) with a whole-commitment rank verdict of 0 -- owner the attention designer (Codex) + Fable review",
    "A2": "the attention side's CFS slot table under FA6's criterion ((n_vars, degree) per slot, extension degree = mask degree, batched forms, M slot order, mask_functionals) -- same owners",
    "A3": "the attention-side seam terminals SeamXm8[c], SeamZ16c[c] as reserved pair rows of the attention A, inventoried jointly with the attention's own openings of xm8 / z16c (aliasing under several masks) -- same owners; FA6 §4 and FA7 flag them as uncounted",
    "A4": "the residual seam between blocks (attention A_k xres2 vs attention A_{k+1} x_in), its CFS slot and pair rows, and the chain-level transcript (FA4 H7, FA3 §4.5) -- same owners",
    "X1": "outside the model, listed not closed: prover timing and memory (the device/host path choice, drains), the driver's `sites` / randomness label report (never to be published), the registry double-use log; proof size is a function of (statement, params, mode) only (zk_proof_size.rs counts fields, never values) and is not a channel",
}

# channel -> profile -> ("accepted", cite) | ("leaks", cite) | ("blocker", [ids]) | ("n/a", why)
_ACC = "accepted"
_LEAK = "leaks"
_BLK = "blocker"
_NA = "n/a"

CHANNELS: List[Dict] = [
    {"id": "cfs.rounds", "name": "CFS-masked round messages per slot (incl. extension rounds)",
     "legacy_v3": (_ACC, "FA6 §2 (surjective onto S for every challenge sequence); §B step 5"),
     "repaired_P1": (_ACC, "FA6 §2; §B step 5 (fibre sampling, programmed round challenges)"),
     "repaired_P3_fresh_W": (_ACC, "FA6 §2 incl. the P3 second extension; §B step 5"),
     "repaired_P3_stable_W_k_slots": (_ACC, "per proof as P3 fresh; CFS masks fresh per proof (FA6 I4); §F2"),
     "block_profile": (_BLK, ["A2"])},
    {"id": "cfs.claims", "name": "masked claimed sums gu_claim, d_claim and the Gammas",
     "legacy_v3": (_ACC, "FA6 §2.3 (batched pairs); §B step 5"), "repaired_P1": (_ACC, "FA6 §2.3; §B step 5"),
     "repaired_P3_fresh_W": (_ACC, "same"), "repaired_P3_stable_W_k_slots": (_ACC, "same, per proof"), "block_profile": (_BLK, ["A2"])},
    {"id": "cfs.g_rho", "name": "derived g_s(rho_s) through the terminal relation",
     "legacy_v3": (_ACC, "FA6 §2.1 (a function of the view); §B step 5: fixed by the committed M, matched by the fibre"),
     "repaired_P1": (_ACC, "same"), "repaired_P3_fresh_W": (_ACC, "same"), "repaired_P3_stable_W_k_slots": (_ACC, "same"), "block_profile": (_BLK, ["A2"])},
    {"id": "m.opening", "name": "M root, q', prox, 256 sampled columns of M",
     "legacy_v3": (_ACC, "FA6 §3 (one Fp2 value V, already public) under I5; §B step 7 (Sim's M is an honest M)"),
     "repaired_P1": (_ACC, "same"), "repaired_P3_fresh_W": (_ACC, "same"), "repaired_P3_stable_W_k_slots": (_ACC, "same, one M per proof"),
     "block_profile": (_ACC, "same per component; the seam slots are FFN-M slots 7 and 8 (FA6 §6)")},
    {"id": "a.vectors", "name": "A group vectors (message parts) at rho_f, rho_d, p2, p5, rho_tab, [rho_p]",
     "legacy_v3": (_LEAK, "FA7 §6: 2n + 4 base functionals per proof; T2 X/h16 rows recovered whole"),
     "repaired_P1": (_ACC, "FA3 §9 whole_A_n4_* (0) + §B step 8 structural cover (pair per column)"),
     "repaired_P3_fresh_W": (_ACC, "FA3 §9 *_p3 (0); §B step 8"), "repaired_P3_stable_W_k_slots": (_ACC, "A is fresh per proof; as P3 fresh"),
     "block_profile": (_ACC, "FA3 §9 whole_A_n4_*_seams (0): X under three pairs; the FFN A only")},
    {"id": "h.vectors", "name": "H group vectors incl. the LogUp sum claim",
     "legacy_v3": (_ACC, "FA7 §8: residual = the public LogUp identity (value 0); FA2 §14.5"),
     "repaired_P1": (_ACC, "FA3 §9 whole_H_n4_* (0), h_logup_sum_zero_sum_u_prox_pair (2 = public identity); §B step 8"),
     "repaired_P3_fresh_W": (_ACC, "same"), "repaired_P3_stable_W_k_slots": (_ACC, "same"), "block_profile": (_ACC, "same (FFN H); attention helpers: A1")},
    {"id": "w.vectors", "name": "W group vectors at p3, p6 (P3 only)",
     "legacy_v3": (_LEAK, "FA7 §6-§7: 2n + 2 per proof; the whole Wd plane at T32; identical across proofs"),
     "repaired_P1": (_NA, "P1 W is public (plain opening, approved root)"),
     "repaired_P3_fresh_W": (_ACC, "FA3 §9 whole_W_p3_n4_* (0); §B step 8"),
     "repaired_P3_stable_W_k_slots": (_BLK, ["E1", "E2", "E3"]),
     "block_profile": (_BLK, ["E1", "E2", "E3"])},
    {"id": "prox.vectors", "name": "proximity vectors of A, H, W",
     "legacy_v3": (_LEAK, "FA2 §14.4 / FA7: covered only by borrowed freedom; +1 functional per column at tiny W"),
     "repaired_P1": (_ACC, "prox pair: FA3 one_pairmask_claim_prox_pair (0); §B step 8 (bijection per column, private to the prox)"),
     "repaired_P3_fresh_W": (_ACC, "same, W prox pair per slot"), "repaired_P3_stable_W_k_slots": (_ACC, "each proof's prox covered by its slot's prox pair even though it touches every row: §F2, k_slot_report"),
     "block_profile": (_ACC, "FFN side same; attention side A1")},
    {"id": "terminals", "name": "terminal values per role (A.value, H.value, W3.value, pred.term)",
     "legacy_v3": (_LEAK, "FA7 §6: +4 (A), +2 (W) functionals per proof from the all-base groups' values"),
     "repaired_P1": (_ACC, "FA3 §9 group_values_all_pairmask (rank 2m + 2n - 2); §B steps 5 and 8 (uniform Fp2 via the pair, composed through want(m_t))"),
     "repaired_P3_fresh_W": (_ACC, "same"), "repaired_P3_stable_W_k_slots": (_ACC, "same; W terminals via the slot's pairs"), "block_profile": (_ACC, "FFN side same; attention side A1")},
    {"id": "columns", "name": "sampled columns, salts and Merkle paths of A, H, W",
     "legacy_v3": (_ACC, "FA2 §14.6 (single proof, q_pad = Q); FA6 §3 for M"),
     "repaired_P1": (_ACC, "§B step 10: Vandermonde x Z_n, |J| <= Q = q_pad; pad_budget_report"),
     "repaired_P3_fresh_W": (_ACC, "same, W fresh"), "repaired_P3_stable_W_k_slots": (_ACC, "§F2: |J| <= kQ <= q_pad across all k proofs (pad_budget_report); conditional on E1-E3 for the count"),
     "block_profile": (_ACC, "same per commitment")},
    {"id": "folded_pads", "name": "folded pad coordinates v_g[n..n+q_pad) of every clear vector",
     "legacy_v3": (_ACC, "FA2 §14.6"), "repaired_P1": (_ACC, "§B step 10: determined by (v_msg, columns) up to a data-independent kernel"),
     "repaired_P3_fresh_W": (_ACC, "same"), "repaired_P3_stable_W_k_slots": (_ACC, "§F2, same with q_pad = kQ and the shared pad kernel"), "block_profile": (_ACC, "same")},
    {"id": "unopened_columns", "name": "the Merkle roots over unopened salted leaves (A, H, W, M, C*_l)",
     "legacy_v3": (_ACC, "ROM: q_H n_leaves / 2^256 (§D hash assumptions H2)"), "repaired_P1": (_ACC, "same"), "repaired_P3_fresh_W": (_ACC, "same"),
     "repaired_P3_stable_W_k_slots": (_ACC, "same; C*_l's root once, at registration (§F2)"), "block_profile": (_ACC, "same")},
    {"id": "seam.ffn", "name": "internal seam terminals, FFN side (seam_x.term_ffn[c], seam_z.term_ffn[c])",
     "legacy_v3": (_NA, "no private seams in the legacy profile"), "repaired_P1": (_NA, "standalone: no seams"), "repaired_P3_fresh_W": (_NA, "standalone"),
     "repaired_P3_stable_W_k_slots": (_NA, "standalone"), "block_profile": (_ACC, "FA3 §9 whole_A_n4_*_seams (0) + FA6 §6 (slot approved); §C")},
    {"id": "seam.attn", "name": "internal seam terminals, attention side (SeamXm8[c], SeamZ16c[c])",
     "legacy_v3": (_NA, ""), "repaired_P1": (_NA, ""), "repaired_P3_fresh_W": (_NA, ""), "repaired_P3_stable_W_k_slots": (_NA, ""), "block_profile": (_BLK, ["A3"])},
    {"id": "seam.residual", "name": "the residual seam between blocks and the chain transcript",
     "legacy_v3": (_NA, ""), "repaired_P1": (_NA, ""), "repaired_P3_fresh_W": (_NA, ""), "repaired_P3_stable_W_k_slots": (_NA, ""), "block_profile": (_BLK, ["A4"])},
    {"id": "public", "name": "the public statement: header, roots, LogUp identity = 0, seam constant 0, external I/O binding, W under P1, C*_l, slot index",
     "legacy_v3": (_ACC, "by definition of the statement (FA2 §14.5, FA5 R27/R30)"), "repaired_P1": (_ACC, "same"), "repaired_P3_fresh_W": (_ACC, "same"),
     "repaired_P3_stable_W_k_slots": (_ACC, "same; the slot index is public and reveals only consumption order"), "block_profile": (_ACC, "same; request context absorbed first (A03)")},
    {"id": "conditioning", "name": "transcript conditioning: lambda, rho, e, points, indices as functions of earlier masked messages (B2)",
     "legacy_v3": (_NA, "moot: the profile leaks without it (FA7)"), "repaired_P1": (_ACC, "§B: Sim programs only the round challenges; every other challenge squeezed honestly; distance q_H n_sq / 2^256"),
     "repaired_P3_fresh_W": (_ACC, "same"), "repaired_P3_stable_W_k_slots": (_ACC, "§F2: the same per proof, k independent transcripts after the shared prefix"), "block_profile": (_BLK, ["A1", "A2", "A3"])},
    {"id": "repeats", "name": "repeated proofs of the same witness / same weights (B4)",
     "legacy_v3": (_LEAK, "FA2 §17.1, FA7 §7: identical recovered digests across ten proofs of one X and three of one W"),
     "repaired_P1": (_ACC, "§F1: k independent runs of Sim; bound k x single-proof"), "repaired_P3_fresh_W": (_ACC, "§F1"),
     "repaired_P3_stable_W_k_slots": (_BLK, ["E1", "E2", "E3"]), "block_profile": (_BLK, ["A1", "E1", "E2", "E3"])},
    {"id": "ranges", "name": "integer ranges and nonlinear side information (B3)",
     "legacy_v3": (_LEAK, "§E: at T32 both X rows (int8) and both h16 rows (int16) per column from ONE proof by bounded enumeration of the disclosed 2-row functional"),
     "repaired_P1": (_ACC, "§E: the view is simulatable without the witness, so no function of it (a range solver included) beats the public statement, up to the stated distance"),
     "repaired_P3_fresh_W": (_ACC, "§E"), "repaired_P3_stable_W_k_slots": (_ACC, "§E given §F2's enforcement"), "block_profile": (_BLK, ["A1"])},
    {"id": "retry", "name": "failure, retry and entropy (degenerate draws, discarded attempts, seeds)",
     "legacy_v3": (_BLK, ["S1"]), "repaired_P1": (_BLK, ["S1", "S2"]), "repaired_P3_fresh_W": (_BLK, ["S1", "S2"]),
     "repaired_P3_stable_W_k_slots": (_BLK, ["S1", "S2", "E1"]), "block_profile": (_BLK, ["S1", "S2"])},
    {"id": "implementation", "name": "the repaired profile as implemented (captures, verifier obligations, exact counts)",
     "legacy_v3": (_NA, "the legacy profile is what exists"), "repaired_P1": (_BLK, ["B5", "S3"]), "repaired_P3_fresh_W": (_BLK, ["B5", "S3"]),
     "repaired_P3_stable_W_k_slots": (_BLK, ["B5", "S3"]), "block_profile": (_BLK, ["B5", "S3"])},
    {"id": "side_channels", "name": "outside the model: timing, memory, driver reports, proof size",
     "legacy_v3": (_BLK, ["X1"]), "repaired_P1": (_BLK, ["X1"]), "repaired_P3_fresh_W": (_BLK, ["X1"]), "repaired_P3_stable_W_k_slots": (_BLK, ["X1"]), "block_profile": (_BLK, ["X1"])},
]

BOUNDS = {
    "single_proof": "Delta_1 <= delta_deg + q_H (n_sq + n_leaves) / 2^256 + N_fp 2^-95, with delta_deg = 2 n_pair 2^-128 + n_slots 2^-128 + (n_prox_pairs + n_block_slots) 2^-64 (+ n_pair_P3 2^-128 for e2 = 1); n_sq = sum over slots of n_vars (programmed round challenges); n_leaves = nn_A + nn_H (+ nn_W) + 4096; N_fp = base-field mask and pad draws of the proof",
    "k_proofs_fresh": "Delta_k <= k Delta_1 (hybrid over proofs; fresh ZkRng stream per attempt, no wcache, no shared pads; the only shared object is the public statement and the transcript prefix up to the first fresh root)",
    "k_proofs_stable_W": "Delta_k <= q_H nn_W / 2^256 + sum_i Delta_1(i) + 0 [kQ <= q_pad] + N_fp(C*_l) 2^-95, valid only under E1-E3 (each slot declared at most once incl. failed attempts, no opening outside the journal, no rollback/copy); the pad channel leaks |J| - q_pad functionals per row when |J| > q_pad; the soundness distance 1 - (n + q_pad)/nn is E4 (FA5)",
    "degeneracy_probabilities": {"lambda_or_k1_zero_per_pair_claim": "2^-128 each", "c_s_zero_per_slot": "2^-128", "prox_pair_Fp_dependent": "2^-64 (exact: (p^3 + p^2 - p) / p^4)", "block_slot_row_bit_in_Fp": "2^-64", "fp_reduction_bias_per_draw": "2^-96 (1 - 2^-32), pad shift bound 2^-95"},
}


def disposition() -> Dict:
    rows = []
    counts = {prof: {"accepted": 0, "leaks": 0, "blocker": 0, "n/a": 0} for prof in PROFILES}
    for ch in CHANNELS:
        row = {"id": ch["id"], "channel": ch["name"], "profiles": {}}
        for prof in PROFILES:
            status, cite = ch[prof]
            counts[prof][status] += 1
            if status == _BLK:
                row["profiles"][prof] = {"status": status, "blockers": cite, "cite": "; ".join(BLOCKERS[b].split(" -- ")[0] for b in cite)}
            else:
                row["profiles"][prof] = {"status": status, "cite": cite}
        rows.append(row)
    return {
        "schema_version": 1, "task": "FA8 -- disposition of every observation channel by profile (review section G)", "reviewer": REVIEWER,
        "source_pin": SOURCE_PIN, "profiles": PROFILES, "blockers": BLOCKERS, "bounds": BOUNDS, "channels": rows, "counts": counts,
        "rule": "finite rank tests and a declaration of model identity do not substitute for the simulator argument or for the enforcement of slot consumption; no private-block, deployment or throughput acceptance follows from this table",
    }


# ----------------------------------------------------------------------------
# report / CLI
# ----------------------------------------------------------------------------


def build_report(seed: int = 6) -> Dict:
    rng = R.Rng(seed)
    fa6 = ROOT / "results/zk60_fable_fa6_cfs_channel.json"
    fa3 = ROOT / "results/zk60_fable_fa3_mask_schedule.json"
    rep = {
        "schema_version": 1, "task": "FA8 -- exact checks behind the transcript simulator", "reviewer": REVIEWER, "source_pin": SOURCE_PIN,
        "seed": seed, "tool_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (Path(__file__).resolve(), HERE / "zk60_fable_joint_rank.py", HERE / "zk60_fable_cfs_channel.py")},
        "fibre": fibre_report(rng), "k_slots": k_slot_report(), "pad_budget": pad_budget_report(), "reduction_bias": reduction_bias(),
        "counts": counts_from_records(fa6, fa3),
    }
    rep["all_ok"] = rep["fibre"]["all_ok"] and rep["k_slots"]["all_ok"] and rep["pad_budget"]["all_ok"]
    rep["caveat"] = "exact integer arithmetic on the source's observation structure with stand-in coefficients; the checks pin three facts the review's simulator uses; they are not the simulator and not an acceptance"
    return rep


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("report")
    r.add_argument("-o", "--out", required=True)
    r.add_argument("--seed", type=int, default=6)
    d = sub.add_parser("disposition")
    d.add_argument("-o", "--out", required=True)
    args = ap.parse_args(argv)
    if args.cmd == "report":
        rep = build_report(args.seed)
        Path(args.out).write_text(json.dumps(rep, indent=1) + "\n")
        print(f"fibre all_ok={rep['fibre']['all_ok']} k_slots all_ok={rep['k_slots']['all_ok']} pad_budget all_ok={rep['pad_budget']['all_ok']}")
        print(f"fp bias log2 = {rep['reduction_bias']['sd_fp_from_uniform']['log2']:.3f}")
        for c in rep["k_slots"]["cases"]:
            print(f"  {c['verdict']}: {c['case']}: disclosed {c['disclosed_dim']} (expected {c['expected']})")
        return 0 if rep["all_ok"] else 1
    rep = disposition()
    Path(args.out).write_text(json.dumps(rep, indent=1) + "\n")
    for prof, cnt in rep["counts"].items():
        print(f"  {prof}: {cnt}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
