"""Rung R0 test vectors for the token I/O stages (reference semantics, no proof).

Builds a deterministic synthetic model (V = 300 -> V_pad 512, d = 16, T = 8, dense random int16
embedding with distinct rows, dense random int8 head: the generic-honest-witness rule) and evaluates
every vector with `token_io_ref`. Writes `vectors.json` beside itself (inputs, model words, expected
outcome and the checker's reason), which R1 can consume without Python. One thread, < 1 s.

Vectors (DESIGN.md v2 6.1 / 6.4):
  V01 honest, public last row          V07 histogram off by one
  V02 honest, hidden length (sealed)   V08 token id outside the vocabulary
  V03 ties -> lowest id                V09 BOS missing
  V04 a non-maximal token              V10 the F-1 attack (selector not e_{P-1})
  V05 two-hot / fractional selector    V11 final-norm overflow: refusal vs refusal-free constants
  V06 wrong embedding row / one word   V12 a delta limb that is not a byte; window arithmetic
v3 additions (CHECK2 N-10..N-14, N-1, N-2; R1 controls):
  V13 overstated maximum, non-maximal index (A6 only)     V19 position selector s = (2, -1)
  V14 selector on a padded vocabulary entry (pad only)    V20 sealed right, used wrong (IO-s)
  V15 tok differs from the selected index (A3)            V21 consistent re-lookup, honest seal (IO-in)
  V16 the N-1 BOS-absorption forgery, helper level        V22 output plane seals another id (IO-out)
  V17 tok_0 != BOS, otherwise honest (helper level)       V23 a nonzero endpoint pad word (IO-in)
  V18 final-norm forged witnesses over F_p                V24 the per-profile BOS constant's class
"""
from __future__ import annotations

import hashlib
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import token_io_ref as R  # noqa: E402

V, D_MODEL, T = 300, 16, 8
PAD_ID = 2
G0, TN, CEPS = 127, 10, 16
CN_SAFE = 1 << TN            # g0 Cn = 127 * 2^tn: no int8 overflow for any int16 row (|x_i| <= D)
CN_HOT = 8 << TN             # a "calibrated"-style multiplier 8x larger: overflow possible (D20 class)
SALT_IN, SALT_OUT = b"r0-salt-input-endpoint-000000001", b"r0-salt-output-endpoint-00000001"


def model(seed=20261017):
    rng = random.Random(seed)
    E, seen = [], set()
    while len(E) < V:
        row = tuple(rng.randint(-1000, 1000) for _ in range(D_MODEL))
        if row not in seen:
            seen.add(row)
            E.append(list(row))
    W = [[rng.randint(-127, 127) for _ in range(D_MODEL)] for _ in range(V)]
    return E, W


def sha_words(rows, width):
    h = hashlib.sha256()
    for r in rows:
        for w in r:
            h.update(int(w).to_bytes(width, "little", signed=True))
    return h.hexdigest()


def run_honest(E, W, tokens, P_len, sealed_selector):
    x_in = R.embed(tokens, E, V)
    x_out = R.stand_in_stack(x_in)
    s = R.selector(P_len, T)
    tok, tr = R.next_token(x_out, s, G0, CN_SAFE, TN, CEPS, W)
    return x_in, x_out, s, tok, tr


def verify_all(E, W, tokens, x_in, x_out, s, x_row, norm, logits, wit):
    """every relation the proof's slots enforce, as the reference checks them"""
    m = R.histogram(tokens, R.npow2(V))
    res = {}
    res["stage_in"] = R.check_stage_in(tokens, x_in, m, E, V)
    res["selector"] = R.check_selector(s)
    res["selection"] = R.check_selection(s, x_out, x_row)
    res["final_norm"] = R.check_final_norm(x_row, norm, G0, CN_SAFE, TN, CEPS)
    res["argmax"] = R.check_argmax(logits, wit, V)
    return {k: dict(ok=v[0], reason=v[1]) for k, v in res.items()}


def build():
    E, W = model()
    rng = random.Random(7)
    prompt_full = [R.BOS] + [rng.randrange(3, V) for _ in range(T - 1)]
    prompt_short = [R.BOS] + [rng.randrange(3, V) for _ in range(4)]          # P = 5
    out = {"scope": "rung R0: reference semantics of the token I/O stages; no proof, no privacy claim",
           "model": {"V": V, "V_pad": R.npow2(V), "d": D_MODEL, "T": T, "pad_id": PAD_ID, "bos": R.BOS,
                     "final_norm": {"g0": G0, "tn": TN, "ceps": CEPS, "cn_safe": CN_SAFE, "cn_hot": CN_HOT,
                                    "window_bits": R.norm_window(D_MODEL, TN, CEPS)},
                     "embedding_sha256_i16": sha_words(E, 2), "head_sha256_i8": sha_words(W, 1),
                     "embedding": E, "head": W, "stack": "token_io_ref.stand_in_stack (causal stand-in)"},
           "vectors": {}}
    vec = out["vectors"]

    # ---- V01 honest, public last row (prompt fills the bucket)
    x_in, x_out, s, tok, tr = run_honest(E, W, prompt_full, T, sealed_selector=False)
    wit = R.keyed_witness(tr["logits"], V)
    plane_in = R.input_plane(prompt_full, T, T, sealed_selector=False)
    root_in = R.commit_standin(plane_in, SALT_IN)
    plane_out = R.output_plane(tok)
    root_out = R.commit_standin(plane_out, SALT_OUT)
    vec["V01_honest_public_row"] = dict(
        io=dict(io_in=dict(zip(("ok", "reason"), R.check_io_half(plane_in, prompt_full, T))),
                io_out=dict(zip(("ok", "reason"), R.check_io_out(plane_out, tok)))),
        tokens=prompt_full, prompt_len=T, next_token=tok, logits_top2=sorted(tr["logits"], reverse=True)[:2],
        norm_y=tr["norm"]["y"], D=tr["norm"]["D"],
        checks=verify_all(E, W, prompt_full, x_in, x_out, s, tr["x_row"], tr["norm"], tr["logits"], wit),
        owner_input=dict(zip(("ok", "reason"), R.owner_check_input(root_in, plane_in, SALT_IN, prompt_full, PAD_ID, T, False))),
        owner_output=dict(zip(("ok", "reason"), R.owner_check_output(root_out, plane_out, SALT_OUT, tok))),
        roots=dict(input=root_in, output=root_out), expect="accept")

    # ---- V02 honest, hidden length: BOS + 4 prompt tokens, right-padded, selector sealed (B-2 / D25 T2)
    tokens = prompt_short + [PAD_ID] * (T - len(prompt_short))
    P_len = len(prompt_short)
    x_in, x_out, s, tok2, tr2 = run_honest(E, W, tokens, P_len, sealed_selector=True)
    wit2 = R.keyed_witness(tr2["logits"], V)
    plane_in2 = R.input_plane(tokens, P_len, T, sealed_selector=True)
    root_in2 = R.commit_standin(plane_in2, SALT_IN)
    root_out2 = R.commit_standin(R.output_plane(tok2), SALT_OUT)
    # causality: the same prompt in a bucket of exactly P_len gives the same next token
    x_in_c = R.embed(prompt_short, E, V)
    tok_c, _ = R.next_token(R.stand_in_stack(x_in_c), R.selector(P_len, P_len), G0, CN_SAFE, TN, CEPS, W)
    tok_last, _ = R.next_token(x_out, R.selector(T, T), G0, CN_SAFE, TN, CEPS, W)
    Lh = max(128, R.npow2(T))
    vec["V02_honest_hidden_length"] = dict(
        io=dict(io_in=dict(zip(("ok", "reason"), R.check_io_half(plane_in2[:Lh], tokens, T))),
                io_s=dict(zip(("ok", "reason"), R.check_io_half(plane_in2[Lh:], s, T))),
                io_out=dict(zip(("ok", "reason"), R.check_io_out(R.output_plane(tok2), tok2)))),
        tokens=tokens, prompt=prompt_short, prompt_len=P_len, selector=s, next_token=tok2,
        next_token_unpadded_run=tok_c, token_at_last_row_instead=tok_last,
        checks=verify_all(E, W, tokens, x_in, x_out, s, tr2["x_row"], tr2["norm"], tr2["logits"], wit2),
        owner_input=dict(zip(("ok", "reason"), R.owner_check_input(root_in2, plane_in2, SALT_IN, prompt_short, PAD_ID, T, True))),
        owner_output=dict(zip(("ok", "reason"), R.owner_check_output(root_out2, R.output_plane(tok2), SALT_OUT, tok2))),
        input_plane_words=len(plane_in2), roots=dict(input=root_in2, output=root_out2), expect="accept")

    # ---- V03 ties: two head rows made identical and maximal for this y
    y = tr2["norm"]["y"]
    j1, j2 = 17, 203
    Wt = [list(r) for r in W]
    best_row = [127 if v >= 0 else -127 for v in y]
    Wt[j1], Wt[j2] = list(best_row), list(best_row)
    lt = R.head_logits(y, Wt)
    honest_t = R.keyed_witness(lt, V)
    forged_t = R.forged_witness(lt, V, j2)
    vec["V03_tie_lowest_id"] = dict(
        tied_rows=[j1, j2], tie_value=lt[j1], max_logit=max(lt), first_argmax=R.first_argmax(lt),
        honest=dict(zip(("ok", "reason"), R.check_argmax(lt, honest_t, V))) | {"tok": honest_t["tok"]},
        forged_higher_id=dict(zip(("ok", "reason"), R.check_argmax(lt, forged_t, V))) | {"tok": j2},
        expect="honest accepts tok = 17; the higher tied id is rejected")

    # ---- V04 a non-maximal token
    l2 = tr2["logits"]
    order = sorted(range(V), key=lambda i: (-l2[i], i))
    second = order[1]
    rnd = order[150]
    vec["V04_non_maximal_token"] = dict(
        first=order[0], second=second, random_index=rnd,
        forged_second=dict(zip(("ok", "reason"), R.check_argmax(l2, R.forged_witness(l2, V, second), V))),
        forged_random=dict(zip(("ok", "reason"), R.check_argmax(l2, R.forged_witness(l2, V, rnd), V))),
        expect="both rejected")

    # ---- V05 two-hot / fractional / signed selector e
    Vp = R.npow2(V)
    j = wit2["tok"]
    k = order[1]
    e_two = [1 if i in (j, k) else 0 for i in range(Vp)]
    half = R.inv(2)
    e_frac = [half if i in (j, k) else 0 for i in range(Vp)]
    e_sign = [2 if i == j else (R.P - 1 if i == k else 0) for i in range(Vp)]
    res5 = {}
    for name, e in (("two_hot", e_two), ("fractional_halves", e_frac), ("two_minus_one", e_sign)):
        w5 = dict(wit2)
        w5["e"] = e
        res5[name] = dict(zip(("ok", "reason"), R.check_argmax(l2, w5, V)))
    vec["V05_selector_not_one_hot"] = dict(indices=[j, k], results=res5, expect="all rejected")

    # ---- V06 wrong embedding row, one changed word
    m2 = R.histogram(tokens, Vp)
    x_bad = [list(r) for r in x_in]
    x_bad[3] = list(E[(tokens[3] + 1) % V])
    x_word = [list(r) for r in x_in]
    x_word[3][5] += 1
    vec["V06_wrong_embedding_row"] = dict(
        position=3, wrong_row=dict(zip(("ok", "reason"), R.check_stage_in(tokens, x_bad, m2, E, V))),
        one_word=dict(zip(("ok", "reason"), R.check_stage_in(tokens, x_word, m2, E, V))), expect="both rejected")

    # ---- V07 histogram off by one
    m_bad = list(m2)
    m_bad[tokens[1]] += 1
    m_bad2 = list(m2)
    m_bad2[tokens[1]] -= 1
    m_bad2[tokens[2]] += 1
    vec["V07_histogram_off_by_one"] = dict(
        plus_one=dict(zip(("ok", "reason"), R.check_stage_in(tokens, x_in, m_bad, E, V))),
        moved_count=dict(zip(("ok", "reason"), R.check_stage_in(tokens, x_in, m_bad2, E, V))), expect="both rejected")

    # ---- V08 token id outside the vocabulary (a padded table index, row of zeros)
    tok_oov = list(tokens)
    tok_oov[2] = V + 1
    x_oov = [list(r) for r in x_in]
    x_oov[2] = [0] * D_MODEL
    m_oov = list(m2)
    m_oov[tokens[2]] -= 1
    try:
        R.embed(tok_oov, E, V)
        prover = "no refusal"
    except R.Refusal as exc:
        prover = "refused: " + str(exc)
    m_oov_pad = list(m_oov)
    m_oov_pad[V + 1] += 1
    vec["V08_token_outside_vocabulary"] = dict(
        honest_prover=prover,
        forged_hist_unchanged=dict(zip(("ok", "reason"), R.check_stage_in(tok_oov, x_oov, m_oov, E, V))),
        forged_hist_on_pad=dict(zip(("ok", "reason"), R.check_stage_in(tok_oov, x_oov, m_oov_pad, E, V))),
        expect="prover refuses; both forged witnesses rejected")

    # ---- V09 BOS missing
    tok_nb = list(tokens)
    tok_nb[0] = 5
    x_nb = [list(r) for r in x_in]
    x_nb[0] = list(E[5])
    try:
        R.embed(tok_nb, E, V)
        prover9 = "no refusal"
    except R.Refusal as exc:
        prover9 = "refused: " + str(exc)
    vec["V09_bos_missing"] = dict(
        honest_prover=prover9,
        forged=dict(zip(("ok", "reason"), R.check_stage_in(tok_nb, x_nb, R.histogram(tok_nb, Vp), E, V))),
        expect="prover refuses; forged witness rejected by the BOS term")

    # ---- V10 the F-1 attack: select row 0 (BOS alone) instead of P-1
    s_att = R.selector(1, T)
    tok_att, tr_att = R.next_token(x_out, s_att, G0, CN_SAFE, TN, CEPS, W)
    w_att = R.keyed_witness(tr_att["logits"], V)
    verifier_side = verify_all(E, W, tokens, x_in, x_out, s_att, tr_att["x_row"], tr_att["norm"], tr_att["logits"], w_att)
    plane_att = list(tokens) + [0] * (max(128, R.npow2(T)) - T) + s_att + [0] * (max(128, R.npow2(T)) - T)
    root_att = R.commit_standin(plane_att, SALT_IN)
    vec["V10_F1_attack_wrong_prefix"] = dict(
        attack_selector=s_att, attack_token=tok_att, honest_token=tok2,
        verifier_side_relations=verifier_side,
        unsealed_design_v1="no check rejects: the receipt would verify (check finding F-1)",
        sealed_owner_input_check=dict(zip(("ok", "reason"), R.owner_check_input(root_att, plane_att, SALT_IN, prompt_short, PAD_ID, T, True))),
        expect="every verifier-side relation passes; the sealed input owner check rejects")

    # ---- V11 final-norm overflow: a peaked row
    x_peak = [0] * D_MODEL
    x_peak[3] = 20000
    x_peak[7] = 300
    try:
        R.final_norm(x_peak, G0, CN_HOT, TN, CEPS)
        hot = "no refusal"
    except R.Refusal as exc:
        hot = "refused: " + str(exc)
    safe = R.final_norm(x_peak, G0, CN_SAFE, TN, CEPS)
    worst = R.final_norm([32767] + [0] * (D_MODEL - 1), G0, CN_SAFE, TN, CEPS)
    worst_neg = R.final_norm([-32768] + [0] * (D_MODEL - 1), G0, CN_SAFE, TN, CEPS)
    vec["V11_final_norm_overflow"] = dict(
        row=x_peak, calibrated_style_cn=hot, refusal_free_cn_y_max=max(abs(v) for v in safe["y"]),
        refusal_free_extremes=[worst["y"][0], worst_neg["y"][0]],
        expect="the 8x multiplier refuses (D20 class); g0 Cn = 127 2^tn never overflows (|x_i| <= D)")

    # ---- V12 a limb that is not a byte; the window arithmetic of both models
    w12 = {kk: (vv if kk != "limbs" else [list(r) for r in vv]) for kk, vv in wit2.items()}
    i_off = order[5]
    w12["limbs"][0][i_off] += 256
    w12["limbs"][1][i_off] -= 1
    win = {}
    for name, d, Vm in (("TinyLlama", 2048, 32000), ("Llama-3-8B", 4096, 128256)):
        vbits = R.clog2(R.npow2(Vm))
        top = ((2 * d * 127 * 127) << vbits) + (Vm - 1)
        top128 = ((2 * d * 127 * 128) << vbits) + (Vm - 1)
        win[name] = dict(max_honest_delta_bits=top.bit_length(), with_minus128=top128.bit_length(),
                         six_limbs_cover=top < (1 << 48), sound_margin=(1 << 48) + top128 < R.P)
    vec["V12_limb_not_a_byte_and_windows"] = dict(
        index=i_off, same_delta_value=True,
        result=dict(zip(("ok", "reason"), R.check_argmax(l2, w12, V))), windows=win,
        expect="rejected (A4); six byte limbs cover both models with the soundness margin")

    # ======================= v3 additions =======================
    v = R.clog2(Vp)

    def limbs_of(delta):
        return [[(dl >> (8 * kk)) & 0xFF for dl in delta] for kk in range(R.DELTA_LIMBS)]

    # ---- V13 overstated maximum with a non-maximal index: only A6 catches it (N-10 T1)
    j13 = order[7]
    M13 = l2[order[0]] + 1
    d13 = [(((M13 - l2[i]) << v) + (i - j13)) if i < V else 0 for i in range(Vp)]
    w13 = dict(tok=j13, M=M13, e=[1 if i == j13 else 0 for i in range(Vp)], limbs=limbs_of(d13))
    vec["V13_overstated_max_A6_only"] = dict(
        index=j13, first_max=order[0], M=M13, all_deltas_in_six_bytes=all(0 <= dl < (1 << 48) for dl in d13),
        result=dict(zip(("ok", "reason"), R.check_argmax(l2, w13, V))),
        accepted_without_A6=R.check_argmax(l2, w13, V, skip=("A6",))[0],
        expect="rejected by A6, and accepted if A6 were removed (A6 is load-bearing)")

    # ---- V14 selector on a padded vocabulary entry: only pad-zero catches it (N-10 T2)
    ip = V
    d14 = [(((M13 - l2[i]) << v) + (i - ip)) if i < V else 0 for i in range(Vp)]
    w14 = dict(tok=ip, M=M13, e=[1 if i == ip else 0 for i in range(Vp)], limbs=limbs_of(d14))
    vec["V14_selector_on_padded_entry"] = dict(
        output_id=ip, V=V, result=dict(zip(("ok", "reason"), R.check_argmax(l2, w14, V))),
        accepted_without_pad_zero=R.check_argmax(l2, w14, V, skip=("pad",))[0],
        expect="rejected by the pad-zero term; without it the proof would output id 300 = V, not a token")

    # ---- V15 tok differs from the selected index (N-10 T3). The sharp form: e and delta honest for
    # j, the output tok' = j + 1, and M' = l_j + 2^-v (tok' - j) in the field, so A5 and A6 still hold
    # (delta_i = 2^v (l_j - l_i) + (i - j) does not depend on tok); only A3 binds the OUTPUT to j.
    jj = wit2["tok"]
    tok15 = jj + 1
    M15 = (l2[jj] + R.inv(1 << v) * (tok15 - jj)) % R.P
    w15 = dict(wit2, tok=tok15, M=M15)
    w15n = dict(wit2, tok=tok15)
    vec["V15_tok_not_selected_index"] = dict(
        selected=jj, output_tok=tok15,
        result=dict(zip(("ok", "reason"), R.check_argmax(l2, w15, V))),
        accepted_without_A3=R.check_argmax(l2, w15, V, skip=("A3",))[0],
        naive_tok_plus_one_M_unchanged=dict(zip(("ok", "reason"), R.check_argmax(l2, w15n, V, skip=("A3",)))),
        expect="rejected by A3; with M shifted by 2^-v (tok' - j) every other relation holds, so A3 is load-bearing")

    # ---- V16 the N-1 forgery at helper level: tok_0 = BOS + 1, h_q(0) = 0, row 0 arbitrary
    L16 = 16                                                 # T lifted (models the P-3 lift)
    tokp = list(tokens) + [0] * (L16 - T)
    hq, ht = R.stage_in_helpers(tokens, x_in, m2, E, V, L=L16)
    att_tok = [R.BOS + 1] + list(tokens[1:])
    att_x = [[vv + 7 for vv in E[123]]] + [list(r) for r in x_in[1:]]
    att_m = R.histogram(tokens[1:], Vp)
    hq_a, ht_a = R.stage_in_helpers(att_tok, att_x, att_m, E, V, L=L16)
    hq_a[0] = 0
    att_plane = att_tok + [0] * (L16 - T)
    res16 = {}
    for wt in ("unweighted", "fresh"):
        res16["honest_" + wt] = dict(zip(("ok", "reason"), R.check_stage_in_helpers(tokp, x_in, m2, hq, ht, E, V, T, R.BOS, wt)))
        res16["attack_" + wt] = dict(zip(("ok", "reason"), R.check_stage_in_helpers(att_plane, att_x, att_m, hq_a, ht_a, E, V, T, R.BOS, wt)))
    vec["V16_bos_absorption_N1"] = dict(
        attack="tok_0 = BOS + 1 with h_q(0) = 0 and the histogram without position 0: position 0 leaves the LogUp",
        results=res16,
        ideal_identity_check=dict(zip(("ok", "reason"), R.check_stage_in(att_tok, att_x, att_m, E, V))),
        expect="unweighted BOS clause (DESIGN v2 text) accepts the attack; a fresh coefficient rejects it")

    # ---- V17 tok_0 != BOS, otherwise honest (helpers computed honestly for that sequence)
    nb_tok = [5] + list(tokens[1:])
    nb_x = [list(E[5])] + [list(r) for r in x_in[1:]]
    nb_m = R.histogram(nb_tok, Vp)
    hq_n, ht_n = R.stage_in_helpers(nb_tok, nb_x, nb_m, E, V, L=L16)
    res17 = {wt: dict(zip(("ok", "reason"), R.check_stage_in_helpers(nb_tok + [0] * (L16 - T), nb_x, nb_m, hq_n, ht_n, E, V, T, R.BOS, wt)))
             for wt in ("unweighted", "fresh")}
    vec["V17_tok0_not_bos"] = dict(results=res17, expect="rejected by the BOS clause in both weightings")

    # ---- V18 final-norm forged witnesses over F_p with explicit windows (N-12)
    xr, fn2 = tr2["x_row"], tr2["norm"]
    den = 2 * (fn2["D"] << TN)
    res18 = {"honest": dict(zip(("ok", "reason"), R.check_final_norm_field(xr, fn2, G0, CN_SAFE, TN, CEPS)))}
    w = {kk: (list(vv) if isinstance(vv, list) else vv) for kk, vv in fn2.items()}
    w["y"][0] += 1
    w["rho"][0] -= den
    w["sigma"][0] += den
    res18["y_off_by_one"] = dict(zip(("ok", "reason"), R.check_final_norm_field(xr, w, G0, CN_SAFE, TN, CEPS)))
    S2 = sum(vv * vv for vv in xr) + CEPS
    w = dict(fn2, D=fn2["D"] + 1)
    w["Dsq"] = w["D"] ** 2
    w["a1"] = S2 - w["Dsq"]
    w["a2"] = 2 * w["D"] - w["a1"]
    res18["D_off_by_one"] = dict(zip(("ok", "reason"), R.check_final_norm_field(xr, w, G0, CN_SAFE, TN, CEPS)))
    w = dict(fn2, D=(fn2["D"] + (R.P - 1) // 2) % R.P)
    res18["D16_field_alias"] = dict(zip(("ok", "reason"), R.check_final_norm_field(xr, w, G0, CN_SAFE, TN, CEPS)))
    num_hot = [2 * vv * G0 * CN_HOT + (fn2["D"] << TN) for vv in xr]
    yq, rr = [q // den for q in num_hot], [q % den for q in num_hot]
    w = dict(fn2, y=yq, rho=rr, sigma=[den - 1 - r for r in rr])
    res18["y_outside_int8_in_window"] = dict(zip(("ok", "reason"), R.check_final_norm_field(xr, w, G0, CN_HOT, TN, CEPS)))
    res18["y_outside_int8_in_window"]["max_abs_y"] = max(abs(q) for q in yq)
    xb = list(xr)
    xb[0] = 40000                                           # not int16; every other relation consistent
    Sb = sum(vv * vv for vv in xb) + CEPS
    Db = __import__("math").isqrt(Sb)
    denb = 2 * (Db << TN)
    numb = [2 * vv * G0 * CN_SAFE + (Db << TN) for vv in xb]
    yb, rb_ = [q // denb for q in numb], [q % denb for q in numb]
    wb = dict(D=Db, Dsq=Db * Db, a1=Sb - Db * Db, a2=2 * Db - (Sb - Db * Db), y=yb, rho=rb_, sigma=[denb - 1 - r for r in rb_])
    res18["x_not_int16"] = dict(zip(("ok", "reason"), R.check_final_norm_field(xb, wb, G0, CN_SAFE, TN, CEPS)))
    res18["x_not_int16"]["int_relations_hold_otherwise"] = R.check_final_norm(xb, wb, G0, CN_SAFE, TN, CEPS)[0]
    vec["V18_final_norm_field_forgeries"] = dict(results=res18, expect="honest accepted; every forgery rejected by its window")

    # ---- V19 position selector s = (2, -1) summing to 1 (N-13)
    s19 = [0] * T
    s19[P_len - 1], s19[0] = 2, -1
    x19 = [2 * a - b for a, b in zip(x_out[P_len - 1], x_out[0])]
    vec["V19_selector_two_minus_one"] = dict(
        selector=s19, selector_check=dict(zip(("ok", "reason"), R.check_selector([vv % R.P for vv in s19]))),
        selection_relation_alone=dict(zip(("ok", "reason"), R.check_selection(s19, x_out, x19))),
        expect="the selection relation alone accepts; booleanity (SBOOL) rejects")

    # ---- V20 sealed right, used wrong: stage OUT selects row 0 under the honest seal (N-14 T7)
    s_used = R.selector(1, T)
    vec["V20_sealed_right_used_wrong"] = dict(
        owner_input_check=dict(zip(("ok", "reason"), R.owner_check_input(root_in2, plane_in2, SALT_IN, prompt_short, PAD_ID, T, True))),
        io_s=dict(zip(("ok", "reason"), R.check_io_half(plane_in2[Lh:], s_used, T))),
        expect="the owner check passes (the seal is honest); IO-s rejects A_out's s against the sealed half")

    # ---- V21 consistent re-lookup in A_in under the honest seal (N-14 T8)
    t21 = list(tokens)
    t21[2] = (tokens[2] + 11) % V
    x21 = [list(r) for r in x_in]
    x21[2] = list(E[t21[2]])
    vec["V21_consistent_relookup_honest_seal"] = dict(
        stage_in_on_relookup=dict(zip(("ok", "reason"), R.check_stage_in(t21, x21, R.histogram(t21, Vp), E, V))),
        io_in=dict(zip(("ok", "reason"), R.check_io_half(plane_in2[:Lh], t21, T))),
        expect="stage IN's lookup accepts the re-looked-up sequence; IO-in rejects it against the sealed half")

    # ---- V22 the output plane seals another id (N-14 T9)
    other = order[1]
    oplane = R.output_plane(other)
    oroot = R.commit_standin(oplane, SALT_OUT)
    vec["V22_output_plane_other_id"] = dict(
        argmax_token=tok2, sealed_id=other,
        owner_output_check_told_sealed_id=dict(zip(("ok", "reason"), R.owner_check_output(oroot, oplane, SALT_OUT, other))),
        io_out=dict(zip(("ok", "reason"), R.check_io_out(oplane, tok2))),
        expect="the owner told the sealed id passes its check; IO-out rejects (A_out's tok is the argmax)")

    # ---- V23 a nonzero pad word in the endpoint's token half
    pw = list(plane_in2)
    pw[T] = 7
    vec["V23_endpoint_pad_word"] = dict(
        io_in=dict(zip(("ok", "reason"), R.check_io_half(pw[:Lh], tokens, T))),
        owner_input_check=dict(zip(("ok", "reason"), R.owner_check_input(R.commit_standin(pw, SALT_IN), pw, SALT_IN, prompt_short, PAD_ID, T, True))),
        expect="IO-in (support factor) rejects; the owner check rejects too")

    # ---- V24 the per-profile BOS constant and its class (N-2)
    vec["V24_bos_profile_constant"] = dict(
        tinyllama=dict(bos=R.BOS_TINYLLAMA, V=32000, check=list(R.check_bos_class(R.BOS_TINYLLAMA, 32000))),
        llama3_8b=dict(bos=R.BOS_LLAMA3_8B, V=128256, check=list(R.check_bos_class(R.BOS_LLAMA3_8B, 128256))),
        llama3_bos_under_tinyllama_vocab=list(R.check_bos_class(R.BOS_LLAMA3_8B, 32000)),
        synthetic_profile_bos=R.BOS,
        expect="1 and 128000 in class; 128000 outside a 32,000-entry vocabulary")
    return out


def main():
    out = build()
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vectors.json")
    with open(path, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
    for name, v in out["vectors"].items():
        summary = {kk: vv for kk, vv in v.items() if kk in ("expect", "next_token")}
        print(name, json.dumps(summary))
    print("wrote", path)


if __name__ == "__main__":
    main()
