"""Rung R0 of the token I/O design: REFERENCE SEMANTICS, no proof.

DESIGN.md v2 sections 2.3 (stage IN), 3.1 (stage OUT), 8 (the B-2 seal of the hidden prompt length,
D25 T2) and D25 T3 / T8 (lowest-id tie rule, BOS at position 0). Pure Python integers, no third-party
imports, one thread. Three layers:

1. INTEGER SEMANTICS (what the run computes): `embed`, `final_norm`, `head_logits`, `first_argmax`,
   `select_row`, `next_token`. The final norm is the block's norm_a relation with a uniform gain
   (private-model-kernel::final_norm_row / tlcalib.i_norm semantics, D24 window), the logits are the
   RAW integer accumulators, the next token is numpy's first maximum.
2. RELATION CHECKERS (what the proof's slots enforce, written as the relations themselves, over the
   Goldilocks base field p = 2^64 - 2^32 + 1): `check_stage_in` (BOS, the compressed-row LogUp
   identity with challenges drawn after the witness is fixed), `check_final_norm` (isqrt witnesses,
   limb windows, quotient / remainder), `check_argmax` (A1..A6 of section 3.1, six byte limbs, NO
   pin), `check_selector` / `check_selection`. They return (ok, reason) and never raise on a
   dishonest witness. The native construction uses F_p^2 challenges and sum-checks at random points;
   this layer checks the same relations entry by entry (a semantic model, not the protocol).
3. OWNER-SIDE SEAL (B-2, D25 T2 / T5): `input_plane`, `output_plane`, `commit_standin`,
   `owner_check_input`, `owner_check_output`. The commitment here is a STAND-IN (salted SHA-256 over
   the plane words), modelling only what the owner check needs: the decommitment determines the root.
   The real endpoint is the Ligero-class PCS commitment of endpoint_g (rows, 256 pads per row, salted
   leaves); its owner check (`endpoint_g::owner_check`) does not exist yet.

Labels: everything printed by `token_io_vectors.py` is computed here; nothing is [MEASURED].
"""
from __future__ import annotations

import hashlib
import math

P = (1 << 64) - (1 << 32) + 1      # Goldilocks
# N-2 (CHECK2): the BOS id is a PER-PROFILE statement constant with declared class [0, V)
BOS_TINYLLAMA = 1                  # TinyLlama SentencePiece BOS (TOKEN_IO_SPEC.md)
BOS_LLAMA3_8B = 128000             # Llama-3 <|begin_of_text|> (zk60_8b_calibration_20261017)
BOS = BOS_TINYLLAMA                # the synthetic R0 profile's BOS (its V = 300 admits id 1)
DELTA_LIMBS = 6                    # the R0 synthetic profile's limb count (no top-limb pin, DESIGN v2 C-4);
                                   # the stored vectors keep it fixed; the rule itself is `limbs_for` (TF-1)
MULT_BITS_D25_T4 = 12              # D25 T4 as amended: per-row multipliers m_j in [1, 2^12]


def keyed_window_bits(d: int, V: int, mult_bits: int = MULT_BITS_D25_T4, wmax: int = 127) -> int:
    """the honest keyed difference's worst case over the declared class (d, V, head multipliers):
    bits(2^v * 2 * d * 127 * wmax * 2^mult_bits + V - 1), v = log2(V_pad)."""
    v = clog2(npow2(V))
    return ((((2 * d * 127 * wmax) << mult_bits) << v) + (V - 1)).bit_length()


def limbs_for(d: int, V: int, mult_bits: int = MULT_BITS_D25_T4, limb_bits: int = 8):
    """TF-1: the limb count is DERIVED, ceil(window / limb_bits), never a fixed six; returns
    (limbs, window, no_wrap) with no_wrap the C-4 / door condition 2^(limb_bits * L) + 2^window < p."""
    w = keyed_window_bits(d, V, mult_bits)
    n = -(-w // limb_bits)
    return n, w, (1 << (limb_bits * n)) + (1 << w) < P
D_LIMB_BOUND = 1 << 24             # D, a1, a2: three byte limbs each (D16 rule 1)


def clog2(x: int) -> int:
    return (x - 1).bit_length()


def npow2(x: int) -> int:
    return 1 << clog2(x)


def inv(a: int) -> int:
    return pow(a % P, P - 2, P)


class Refusal(Exception):
    """An honest-prover refusal (D20 class); carries a static site name only, never data."""


# ============================================================================ integer semantics
def check_bos_class(bos: int, V: int):
    """N-2: the profile's BOS constant must lie in its declared class [0, V) (D24 F-1 rule)."""
    return (True, "ok") if 0 <= bos < V else (False, "BOS constant outside its class [0, V)")


def embed(tokens, E, V, bos=BOS):
    """x_in[t] = E[tok_t] (the public int16 table, TOKEN_IO_SPEC.md). Refuses out-of-vocabulary ids
    and a missing BOS (D25 T8) BEFORE anything else, naming no position or value."""
    if any(not (0 <= t < V) for t in tokens):
        raise Refusal("token id outside the vocabulary")
    if not tokens or tokens[0] != bos:
        raise Refusal("position 0 is not BOS")
    return [list(E[t]) for t in tokens]


def norm_window(d: int, tn: int, ceps: int) -> int:
    """D24: D_max = isqrt(ceps + d * 32768^2) (int16 -32768 counted), window = tn + 1 + bits(D_max)."""
    dmax = math.isqrt(ceps + d * 32768 * 32768)
    return tn + 1 + dmax.bit_length()


def final_norm(x, g0: int, cn: int, tn: int, ceps: int):
    """The block's norm relation with a UNIFORM gain g0 on one int16 row (round mode):
    D = isqrt(sum x^2 + ceps), den = 2 D 2^tn, y = floor((2 x g0 cn + D 2^tn) / den),
    rho = remainder, sigma = den - 1 - rho; refuses (never clamps) if D, a1, a2 leave three byte
    limbs, y leaves [-127, 127], or rho / sigma leave the 2^wrho window."""
    d = len(x)
    if any(not (-32768 <= v <= 32767) for v in x):
        raise Refusal("final norm input is not int16")
    wrho = norm_window(d, tn, ceps)
    ss = ceps + sum(v * v for v in x)
    D = math.isqrt(ss)
    a1 = ss - D * D
    a2 = 2 * D - a1
    if not (1 <= D < D_LIMB_BOUND and 0 <= a1 < D_LIMB_BOUND and 0 <= a2 < D_LIMB_BOUND):
        raise Refusal("final norm denominator")
    dv = D << tn
    den = 2 * dv
    y, rho, sigma = [], [], []
    for v in x:
        num = 2 * v * g0 * cn + dv
        q, r = divmod(num, den)          # floor / Euclidean remainder (den > 0)
        s = den - 1 - r
        if not (-127 <= q <= 127) or r >= (1 << wrho) or s >= (1 << wrho):
            raise Refusal("final norm quotient/remainder")
        y.append(q)
        rho.append(r)
        sigma.append(s)
    return dict(D=D, Dsq=D * D, a1=a1, a2=a2, y=y, rho=rho, sigma=sigma, wrho=wrho)


def head_logits(y, W):
    """l_j = sum_i y_i W[j][i]: the RAW integer accumulators (no requantization)."""
    return [sum(a * b for a, b in zip(y, row)) for row in W]


def first_argmax(l) -> int:
    """numpy.argmax: the lowest index among equal maxima (D25 T3)."""
    best = 0
    for i in range(1, len(l)):
        if l[i] > l[best]:
            best = i
    return best


def select_row(s, X):
    """x_sel = sum_t s_t X[t] (the hidden-length selection, DESIGN 3.1 item 1)."""
    d = len(X[0])
    return [sum(s[t] * X[t][i] for t in range(len(X))) for i in range(d)]


def selector(P_len: int, T: int):
    """s = e_{P-1}: the one-hot position selector of a prompt of P_len tokens in a bucket of T."""
    if not (1 <= P_len <= T):
        raise Refusal("prompt length outside the bucket")
    return [1 if t == P_len - 1 else 0 for t in range(T)]


def next_token(x_out, s, g0, cn, tn, ceps, W):
    """Stage OUT, integer semantics: select the row, final norm, raw logits, first maximum."""
    xr = select_row(s, x_out)
    fn = final_norm(xr, g0, cn, tn, ceps)
    l = head_logits(fn["y"], W)
    return first_argmax(l), dict(x_row=xr, norm=fn, logits=l)


# ============================================================================ field helpers
def eq_weights(r):
    """eq(r, x) for every x in {0,1}^k, MSB-first (the module's coordinate order)."""
    k = len(r)
    out = [0] * (1 << k)
    for x in range(1 << k):
        acc = 1
        for j in range(k):
            bit = (x >> (k - 1 - j)) & 1
            acc = acc * (r[j] if bit else (1 - r[j])) % P
        out[x] = acc
    return out


def mle(vec, r):
    w = eq_weights(r)
    return sum(v * wi for v, wi in zip(vec, w)) % P


def challenges(label: str, *parts, n: int = 1):
    """Fiat-Shamir STAND-IN: field elements from SHA-256 over a label and the (already fixed) witness
    commitments. Only the order matters here: challenges are a function of what was fixed before."""
    h = hashlib.sha256(label.encode())
    for p_ in parts:
        h.update(repr(p_).encode())
    seed = h.digest()
    out = []
    ctr = 0
    while len(out) < n:
        v = int.from_bytes(hashlib.sha256(seed + ctr.to_bytes(4, "little")).digest()[:16], "little") % P
        ctr += 1
        if v not in (0, 1):
            out.append(v)
    return out


# ============================================================================ stage IN relations
def histogram(tokens, V_pad):
    m = [0] * V_pad
    for t in tokens:
        m[t] += 1
    return m


def check_stage_in(tokens, x_rows, m, E, V, bos=BOS):
    """The relations stage IN proves (DESIGN 2.3), checked as a semantic model:
    * BOS: tok_0 = 1 (D25 T8 term);
    * pad-zero of the histogram on padded table entries;
    * the compressed-row LogUp identity  sum_t 1/(alpha - q_t) = sum_v m_v/(alpha - tau_v)  with
      q_t = tok_t + beta x~(t, r_emb) + g, tau_v = v + beta E~(v, r_emb) + g, challenges drawn AFTER
      tokens, x and m are fixed (r_emb, beta, alpha, g from their hash).
    Returns (ok, reason). Token ids outside [0, V) and wrong rows fail the identity (whp)."""
    T = len(tokens)
    V_pad = npow2(V)
    d = len(E[0])
    d_pad = npow2(d)
    if len(m) != V_pad or len(x_rows) != T:
        return False, "shape"
    if (tokens[0] - bos) % P:
        return False, "BOS term: position 0 is not BOS"
    if any(m[v] % P for v in range(V, V_pad)):
        return False, "pad-zero: histogram nonzero on a padded table entry"
    k = clog2(d_pad)
    chal = challenges("stage-in", tokens, x_rows, m, n=k + 3)
    r_emb, beta, alpha, g = chal[:k], chal[k], chal[k + 1], chal[k + 2]

    def row_mle(row):
        return mle(list(row) + [0] * (d_pad - len(row)), r_emb)

    lhs = 0
    for t in range(T):
        q = (tokens[t] + beta * row_mle(x_rows[t]) + g) % P
        den = (alpha - q) % P
        if den == 0:
            return False, "zero LogUp denominator (refusal class, decided by the public table side)"
        lhs = (lhs + inv(den)) % P
    rhs = 0
    for v in range(V):
        tau = (v + beta * row_mle(E[v]) + g) % P
        den = (alpha - tau) % P
        if den == 0:
            return False, "zero LogUp denominator (table side, public)"
        rhs = (rhs + m[v] * inv(den)) % P
    if lhs != rhs:
        return False, "LogUp identity: some (token, row) tuple is not a row of the public table"
    return True, "ok"


# ============================================================================ stage OUT relations
def check_final_norm(x, wit, g0, cn, tn, ceps):
    """The final norm's relations as the TZC / DZC slots state them (integers; limb windows)."""
    d = len(x)
    wrho = norm_window(d, tn, ceps)
    D, Dsq, a1, a2 = wit["D"], wit["Dsq"], wit["a1"], wit["a2"]
    if not (0 <= D < D_LIMB_BOUND and 0 <= a1 < D_LIMB_BOUND and 0 <= a2 < D_LIMB_BOUND):
        return False, "isqrt limb windows"
    if Dsq != D * D or Dsq + a1 != sum(v * v for v in x) + ceps or 2 * D != a1 + a2:
        return False, "isqrt relations"
    den = 2 * (D << tn)
    for v, y, r, s in zip(x, wit["y"], wit["rho"], wit["sigma"]):
        if not (-127 <= y <= 127):
            return False, "norm output outside int8 (sym lookups)"
        if not (0 <= r < (1 << wrho) and 0 <= s < (1 << wrho)):
            return False, "remainder window"
        if 2 * v * g0 * cn + (D << tn) != y * den + r or r + s != den - 1:
            return False, "norm quotient relation"
    return True, "ok"


def keyed_witness(l, V):
    """The honest argmax witness for a logit vector l over the true vocabulary [0, V):
    tok = first maximum, M = l_tok, e = one-hot, delta_i = 2^v (M - l_i) + (i - tok) on true entries
    (zero on padded ones), six byte limbs of delta."""
    V_pad = npow2(V)
    v = clog2(V_pad)
    j = first_argmax(l[:V])
    M = l[j]
    e = [1 if i == j else 0 for i in range(V_pad)]
    delta = [(((M - l[i]) << v) + (i - j)) if i < V else 0 for i in range(V_pad)]
    limbs = [[(dl >> (8 * k)) & 0xFF for dl in delta] for k in range(DELTA_LIMBS)]
    if any(dl < 0 or dl >= (1 << (8 * DELTA_LIMBS)) for dl in delta):
        raise AssertionError("honest delta outside six byte limbs")
    return dict(tok=j, M=M, e=e, limbs=limbs)


def forged_witness(l, V, j, e=None):
    """What a cheating prover can do for a chosen index j: M = l_j, tok = j, delta reduced mod p and
    written into six byte limbs as far as they reach (the low 48 bits). Used for tamper vectors."""
    V_pad = npow2(V)
    v = clog2(V_pad)
    M = l[j]
    if e is None:
        e = [1 if i == j else 0 for i in range(V_pad)]
    delta = [((((M - l[i]) << v) + (i - j)) % P) if i < V else 0 for i in range(V_pad)]
    limbs = [[(dl >> (8 * k)) & 0xFF for dl in delta] for k in range(DELTA_LIMBS)]
    return dict(tok=j, M=M, e=e, limbs=limbs, delta_full=delta)


def check_argmax(l, wit, V, skip=()):
    """A1..A6 of DESIGN 3.1 for one output row. `l` is the true integer logit vector (the head
    matmul's output on the true vocabulary); padded entries are zero (zero head rows).
    A1 e(1-e) = 0 and pad-zero of e and the limbs; A4 limbs are bytes (delta in [0, 2^48));
    A2 sum e = 1; A3 tok = sum i e_i; A6 sum e_i delta_i = 0; A5 the virtual logits
    l*_i = supp_V(i) (M + 2^-v (i - tok - delta_i)) equal l_i in the field for every i.
    `skip` names relations to leave out ("A1", "pad", "A2", "A3", "A4", "A5", "A6"), only to show
    which relation is the load-bearing one for a forgery (CHECK2 N-10)."""
    V_pad = npow2(V)
    v = clog2(V_pad)
    e, limbs, tok, M = wit["e"], wit["limbs"], wit["tok"], wit["M"]
    lf = list(l[:V]) + [0] * (V_pad - V)
    if len(e) != V_pad or len(limbs) != DELTA_LIMBS:
        return False, "shape"
    if "A1" not in skip:
        for i in range(V_pad):
            if (e[i] * (1 - e[i])) % P:
                return False, "A1 booleanity of the selector"
    if "pad" not in skip:
        if any(e[i] % P for i in range(V, V_pad)) or any(limbs[k][i] for k in range(DELTA_LIMBS) for i in range(V, V_pad)):
            return False, "A1 pad-zero on padded vocabulary entries"
    if "A4" not in skip:
        if any(not (0 <= limbs[k][i] < 256) for k in range(DELTA_LIMBS) for i in range(V_pad)):
            return False, "A4 a delta limb is not a byte"
    delta = [sum(limbs[k][i] << (8 * k) for k in range(DELTA_LIMBS)) for i in range(V_pad)]
    if "A2" not in skip and sum(e) % P != 1:
        return False, "A2 row sum of the selector is not 1"
    if "A3" not in skip and (tok - sum(i * e[i] for i in range(V_pad))) % P:
        return False, "A3 tok is not the selected index"
    if "A6" not in skip and sum(e[i] * delta[i] for i in range(V_pad)) % P:
        return False, "A6 the selected entry's difference is not zero"
    if "A5" not in skip:
        i2v = inv(1 << v)
        for i in range(V_pad):
            supp = 1 if i < V else 0
            lstar = supp * (M + i2v * (i - tok - delta[i])) % P
            if lstar != lf[i] % P:
                return False, "A5 virtual logits differ from the head's logits (some delta out of range)"
    return True, "ok"


def check_selector(s):
    if any((x * (1 - x)) % P for x in s):
        return False, "selector booleanity"
    if sum(s) % P != 1:
        return False, "selector row sum"
    return True, "ok"


def check_selection(s, X, x_row):
    if select_row(s, X) != list(x_row):
        return False, "selected row differs from sum_t s_t B_out[t]"
    return True, "ok"


# ============================================================================ B-2 seal (owner side)
def input_plane(tokens, P_len: int, T: int, sealed_selector: bool = True):
    """The input token endpoint's plane (DESIGN 8.2): half 0 = tok (zero beyond T), half 1 = s = e_{P-1}
    (zero beyond T), each half max(128, T_pad) words; public-row variant: tok alone, max(256, T_pad)."""
    T_pad = npow2(T)
    if not sealed_selector:
        L = max(256, T_pad)
        return list(tokens) + [0] * (L - T)
    L = max(128, T_pad)
    return list(tokens) + [0] * (L - T) + selector(P_len, T) + [0] * (L - T)


def output_plane(tok: int):
    """The output token endpoint's plane in mode (i): one id at word 0 of a 256-word row."""
    return [tok] + [0] * 255


def commit_standin(plane, salt: bytes) -> str:
    """STAND-IN commitment (salted SHA-256 over the words), not the endpoint PCS commitment."""
    h = hashlib.sha256(b"token-io-r0/standin-commitment/v1" + salt)
    for w in plane:
        h.update(int(w).to_bytes(8, "little", signed=False))
    return h.hexdigest()


def owner_check_input(root, plane, salt, prompt, pad_id: int, T: int, sealed_selector: bool = True, bos=BOS):
    """The input owner's check (D25 T2 / T5, D26 C-d): the decommitment rebuilds the root, position 0 is
    the profile's BOS, the sealed tokens are its prompt + pad ids up to T, every pad word is zero, and
    the sealed selector is e_{P-1}."""
    if commit_standin(plane, salt) != root:
        return False, "root does not match the decommitment"
    if not plane or plane[0] != bos:
        return False, "sealed position 0 is not the profile's BOS"
    P_len = len(prompt)
    want_tok = list(prompt) + [pad_id] * (T - P_len)
    T_pad = npow2(T)
    L = max(128, T_pad) if sealed_selector else max(256, T_pad)
    if plane[:T] != want_tok or any(plane[T:L]):
        return False, "sealed tokens are not this owner's prompt (or pad words nonzero)"
    if sealed_selector:
        half1 = plane[L:2 * L]
        if half1[:T] != selector(P_len, T) or any(half1[T:]):
            return False, "sealed selector is not e_{P-1} for this owner's prompt length"
    return True, "ok"


def owner_check_output(root, plane, salt, claimed_tok: int):
    if commit_standin(plane, salt) != root:
        return False, "root does not match the decommitment"
    if plane[0] != claimed_tok or any(plane[1:]):
        return False, "sealed output is not the claimed token"
    return True, "ok"


# ============================================================================ a causal stand-in stack
def stand_in_stack(x_in):
    """A CAUSAL integer stand-in for the 22 / 32 proved blocks (they are proved elsewhere): row t
    depends on rows <= t only. out[t][i] = x[t][i] + (sum_{t' <= t} x[t'][(5 i + 3) mod d]) >> 3,
    refused if it leaves int16."""
    T, d = len(x_in), len(x_in[0])
    out = []
    pref = [0] * d
    for t in range(T):
        for i in range(d):
            pref[i] += x_in[t][i]
        row = [x_in[t][i] + (pref[(5 * i + 3) % d] >> 3) for i in range(d)]
        if any(not (-32768 <= v <= 32767) for v in row):
            raise Refusal("stand-in stack output is not int16")
        out.append(row)
    return out


# ============================================================================ v3 additions (CHECK2)
# ---- N-1 / N-11: the stage-IN slot relations with COMMITTED helpers and batched clauses
def stage_in_challenges(tokens, x_rows, m, d_pad):
    """r_emb, beta, alpha, g: drawn after B_in (x), A_in (tok, m) are committed (before H)."""
    k = clog2(d_pad)
    ch = challenges("stage-in-lookup", tokens, x_rows, m, n=k + 3)
    return ch[:k], ch[k], ch[k + 1], ch[k + 2]


def stage_in_helpers(tokens, x_rows, m, E, V, L=None):
    """The honest prover's H_in: h_q over the lifted T domain (length L, zero beyond T), h_tab over V."""
    T = len(tokens)
    L = L or npow2(T)
    d_pad = npow2(len(E[0]))
    r_emb, beta, alpha, g = stage_in_challenges(tokens, x_rows, m, d_pad)
    rm = lambda row: mle(list(row) + [0] * (d_pad - len(row)), r_emb)
    h_q = [inv((alpha - (tokens[t] + beta * rm(x_rows[t]) + g)) % P) for t in range(T)] + [0] * (L - T)
    h_tab = [(m[v] * inv((alpha - (v + beta * rm(E[v]) + g)) % P)) % P for v in range(V)] + [0] * (len(m) - V)
    return h_q, h_tab


def check_stage_in_helpers(tok_plane, x_rows, m, h_q, h_tab, E, V, T, bos=BOS, bos_weighting="fresh"):
    """The three stage-IN relations entry by entry, as the slots prove them (DESIGN v3 2.3):
    query zero-check over the lifted T domain (length L = len(tok_plane)):
        F(t) = mu_q (h_q(t) (alpha - q_t) - supp_T(t)) + mu_bos [t = 0] (tok(t) - bos)
               + mu_pad (1 - supp_T(t)) (tok(t) + zeta h_q(t)) = 0
    table zero-check over V_pad: h_tab(v) (alpha - tau_v) - m(v) = 0 (pad-zero beyond V);
    LogUp sum: sum h_q - sum h_tab = 0.
    The batching coefficients (mu_q, mu_bos, mu_pad, zeta) are drawn AFTER H_in is committed.
    bos_weighting = "unweighted" models DESIGN v2's text (the BOS clause a bare addend, mu_q = mu_bos = 1):
    CHECK2 N-1 showed the forgery tok_0 = bos + 1, h_q(0) = 0 then passes."""
    L = len(tok_plane)
    d_pad = npow2(len(E[0]))
    toks = tok_plane[:T]
    r_emb, beta, alpha, g = stage_in_challenges(toks, x_rows, m, d_pad)
    mu_q, mu_bos, mu_pad, zeta = challenges("stage-in-batch", tok_plane, x_rows, m, h_q, h_tab, n=4)
    if bos_weighting == "unweighted":
        mu_q, mu_bos = 1, 1
    rm = lambda row: mle(list(row) + [0] * (d_pad - len(row)), r_emb)
    for t in range(L):
        supp = 1 if t < T else 0
        q = (tok_plane[t] + beta * (rm(x_rows[t]) if t < T else 0) + g) % P
        F = mu_q * (h_q[t] * (alpha - q) - supp)
        F += mu_bos * (tok_plane[t] - bos) if t == 0 else 0
        F += mu_pad * (1 - supp) * (tok_plane[t] + zeta * h_q[t])
        if F % P:
            return False, "query zero-check at t = %d" % t
    V_pad = len(m)
    for v in range(V_pad):
        if v >= V:
            if m[v] % P or h_tab[v] % P:
                return False, "table zero-check: pad-zero"
            continue
        tau = (v + beta * rm(E[v]) + g) % P
        if (h_tab[v] * (alpha - tau) - m[v]) % P:
            return False, "table zero-check at v = %d" % v
    if (sum(h_q) - sum(h_tab)) % P:
        return False, "LogUp sum"
    return True, "ok"


# ---- N-12: the final norm over F_p with explicit windows, and x's int16 range (DZC's c2)
def to_field(v):
    return v % P


def canon_signed(v):
    """the canonical representative read back as a signed integer (for reports only)"""
    v %= P
    return v - P if v > P // 2 else v


def check_final_norm_field(x, wit, g0, cn, tn, ceps):
    """Every value is a FIELD element (canonical in [0, p)); windows are what the lookups enforce:
    x + 32768 in [0, 2^16) (two byte limbs), D, a1, a2 in [0, 2^24) (three limbs each), y + 127 and
    127 - y in [0, 256) (sym), rho and sigma in [0, 2^wrho) (the remainder limbs); relations mod p:
    Dsq = D^2, Dsq + a1 = sum x^2 + ceps, 2 D = a1 + a2, 2 x g0 cn + D 2^tn = y (2 D 2^tn) + rho,
    rho + sigma = 2 D 2^tn - 1."""
    d = len(x)
    wrho = norm_window(d, tn, ceps)
    xf = [to_field(v) for v in x]
    if any(((v + 32768) % P) >= (1 << 16) for v in xf):
        return False, "x int16 window (DZC c2 limbs)"
    D, Dsq, a1, a2 = (to_field(wit[k]) for k in ("D", "Dsq", "a1", "a2"))
    if not (D < D_LIMB_BOUND and a1 < D_LIMB_BOUND and a2 < D_LIMB_BOUND):
        return False, "isqrt limb windows (D, a1, a2 in three bytes)"
    if (Dsq - D * D) % P or (Dsq + a1 - sum(v * v for v in xf) - ceps) % P or (2 * D - a1 - a2) % P:
        return False, "isqrt relations"
    den = (2 * D * (1 << tn)) % P
    for v, y, r, s in zip(xf, wit["y"], wit["rho"], wit["sigma"]):
        y, r, s = to_field(y), to_field(r), to_field(s)
        if ((y + 127) % P) >= 256 or ((127 - y) % P) >= 256:
            return False, "norm output outside int8 (sym lookups)"
        if r >= (1 << wrho) or s >= (1 << wrho):
            return False, "remainder window"
        if (2 * v * g0 * cn + D * (1 << tn) - y * den - r) % P or (r + s - den + 1) % P:
            return False, "norm quotient relation"
    return True, "ok"


# ---- N-14: the verifier half of the seal -- the IO slot relations
def check_io_half(end_half, a_side, T):
    """IO-in / IO-s: end(z) = supp_T(z) A(z) over the endpoint's WHOLE half (D17 rule 1); A is the
    stage's own plane (tok on its lifted domain, or s), read at the half's coordinates."""
    for z in range(len(end_half)):
        a = a_side[z] if z < len(a_side) else 0
        if (end_half[z] - (a if z < T else 0)) % P:
            return False, "IO equality at word %d" % z
    return True, "ok"


def check_io_out(end_plane, tok):
    """IO-out (mode i): end(z) = u0(z) tok over the whole 256-word output plane."""
    for z in range(len(end_plane)):
        if (end_plane[z] - (tok if z == 0 else 0)) % P:
            return False, "IO-out equality at word %d" % z
    return True, "ok"
