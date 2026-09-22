#!/usr/bin/env python3
"""A THIRD implementation of the zkp-core ZK row encode, and the conformance
vectors it produces.

Written from the Rust source, not from memory of "an NTT". Every constant
below carries the `file:line` it was read from, in the lane worktree
/home/victor/wt-zk60-block125m at commit a8e4939 (read-only):

  field.rs:10      P = 0xFFFF_FFFF_0000_0001 = 2^64 - 2^32 + 1
  field.rs:13      GENERATOR = 7                (multiplicative generator)
  field.rs:16      TWO_ADICITY = 32
  field.rs:81-86   two_adic_root(k) = (7^((p-1) >> 32))^(2^(32-k))
  field.rs:305     the pinned value: two_adic_root(32) == 1753635133440165772
  field.rs:163     Fp2 = Fp[u]/(u^2 - 7)        (NONRESIDUE = 7, field.rs:15)
  ntt.rs:21-44     NttTables::new(max_log): roots/inv_roots per size, and ONE
                   shared twiddle table of max_n/2 powers of omega_{max_n}
  ntt.rs:69-108    transform(a, inverse): bit-reverses its INPUT in place
                   (:76-87), then decimation-in-time butterflies; the output
                   is in NATURAL order. Twiddle index tw[k * (max_n/len)]
                   (:93, :98) over the SHARED table.
  ntt.rs:55-57     forward(a) = transform(a, false)
  ntt.rs:60-67     inverse(a) = transform(a, true) then scale every entry by
                   Fp::new(n).inv() with n = a.len() -- the size of THAT
                   transform, applied AFTER the transform.
  pcs.rs:642-651   coset_powers(h, nn) = [h^0 .. h^(nn-1)], assert h^nn != 1
  pcs.rs:655-674   encode_row_zk, steps 5a-5f
  pcs.rs:580       ZkOpts::standard: coset h = Fp::new(7), q_pad = num_col_checks
  pcs.rs:157-175   hash_columns / :182-202 hash_columns_keyed: column j of the
                   encoded row-major matrix is the NATURAL-order index j; no
                   permutation sits between the transform's output and the
                   hashed column layout.

Exact integer arithmetic only: Python ints modulo p. No floating point.

Usage:  python3 encode_ref.py            # self-checks, vectors, controls, cross-check
        python3 encode_ref.py selfcheck  # self-checks only
"""

import hashlib
import json
import os
import sys

# ---------------------------------------------------------------------------
# The field (field.rs)
# ---------------------------------------------------------------------------

P = (1 << 64) - (1 << 32) + 1          # field.rs:10
GENERATOR = 7                          # field.rs:13
TWO_ADICITY = 32                       # field.rs:16
NONRESIDUE = 7                         # field.rs:15
COSET_H = 7                            # pcs.rs:580, ZkOpts::standard


def finv(a):
    """a^(p-2) mod p (field.rs:76-79 computes exactly this exponent)."""
    assert a % P != 0, "inverse of zero"
    return pow(a % P, P - 2, P)


def two_adic_root(k):
    """field.rs:81-86: g^((p-1)/2^32) has exact order 2^32; raise to 2^(32-k)."""
    assert 0 <= k <= TWO_ADICITY
    r32 = pow(GENERATOR, (P - 1) >> TWO_ADICITY, P)
    return pow(r32, 1 << (TWO_ADICITY - k), P)


# Fp2 = Fp[u]/(u^2 - 7), field.rs:158-164. Used only by the capture cross-check.
def f2mul(a, b):
    ac = a[0] * b[0] % P
    bd = a[1] * b[1] % P
    ad = a[0] * b[1] % P
    bc = a[1] * b[0] % P
    return ((ac + bd * NONRESIDUE) % P, (ad + bc) % P)


def f2add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


# ---------------------------------------------------------------------------
# The NTT (ntt.rs)
# ---------------------------------------------------------------------------

class NttTables:
    """ntt.rs:20-123, transcribed. `max_log` sizes the SHARED twiddle table."""

    def __init__(self, max_log):
        self.max_log = max_log
        self.roots = [two_adic_root(k) for k in range(max_log + 1)]        # :24-28
        self.inv_roots = [finv(r) for r in self.roots]
        n = 1 << max_log
        half = max(n // 2, 1)                                              # :30,:33
        w = self.roots[max_log]
        wi = self.inv_roots[max_log]
        tw, itw = [], []
        cur, curi = 1, 1
        for _ in range(half):                                              # :37-42
            tw.append(cur)
            itw.append(curi)
            cur = cur * w % P
            curi = curi * wi % P
        self.twiddles = tw
        self.inv_twiddles = itw

    # -- the faithful transform -------------------------------------------
    def transform(self, a, inverse=False):
        """ntt.rs:69-108, in place. Bit-reversal on the INPUT, natural output."""
        n = len(a)
        assert n & (n - 1) == 0
        log_n = n.bit_length() - 1
        assert log_n <= self.max_log, "ntt size exceeds tables"
        if n == 1:
            return
        # :76-87 -- the exact incremental bit-reversal loop of the Rust
        j = 0
        for i in range(1, n):
            bit = n >> 1
            while j & bit:
                j ^= bit
                bit >>= 1
            j |= bit
            if i < j:
                a[i], a[j] = a[j], a[i]
        tw = self.inv_twiddles if inverse else self.twiddles               # :88
        max_n = 1 << self.max_log                                          # :89
        length = 2
        while length <= n:                                                 # :91-107
            half = length // 2
            stride = max_n // length                                       # :93
            for i in range(0, n, length):
                for k in range(half):
                    w = tw[k * stride]                                     # :98
                    u = a[i + k]
                    v = a[i + half + k] * w % P
                    a[i + k] = (u + v) % P
                    a[i + half + k] = (u - v) % P
            length <<= 1

    def forward(self, a):
        """ntt.rs:55-57."""
        self.transform(a, False)

    def inverse(self, a):
        """ntt.rs:60-67: transform, THEN scale by 1/len(a)."""
        self.transform(a, True)
        ninv = finv(len(a) % P)
        for i in range(len(a)):
            a[i] = a[i] * ninv % P

    # -- a genuinely different algorithm, for the ordering control ---------
    def transform_dif(self, a, inverse=False):
        """Gentleman-Sande: NATURAL input, DECIMATION IN FREQUENCY butterflies,
        BIT-REVERSED output. Not in the Rust: this is what a device NTT that
        skips the final reorder produces. Self-check S8 asserts
        transform_dif(x) == bitrev(transform(x))."""
        n = len(a)
        assert n & (n - 1) == 0
        if n == 1:
            return
        tw = self.inv_twiddles if inverse else self.twiddles
        max_n = 1 << self.max_log
        length = n
        while length >= 2:
            half = length // 2
            stride = max_n // length
            for i in range(0, n, length):
                for k in range(half):
                    w = tw[k * stride]
                    u = a[i + k]
                    v = a[i + half + k]
                    a[i + k] = (u + v) % P
                    a[i + half + k] = (u - v) * w % P
            length >>= 1

    # -- deliberately wrong transforms, for the negative controls ----------
    def transform_bug(self, a, inverse, bug):
        n = len(a)
        if n == 1:
            return
        j = 0
        for i in range(1, n):
            bit = n >> 1
            while j & bit:
                j ^= bit
                bit >>= 1
            j |= bit
            if i < j:
                a[i], a[j] = a[j], a[i]
        if bug == "conjugate_root":
            # the OTHER two-adic root: the two tables swapped
            tw = self.twiddles if inverse else self.inv_twiddles
        else:
            tw = self.inv_twiddles if inverse else self.twiddles
        max_n = 1 << self.max_log
        half_table = len(tw)
        length = 2
        while length <= n:
            half = length // 2
            stride = max_n // length
            for i in range(0, n, length):
                for k in range(half):
                    if bug == "stride_off_by_one":
                        w = tw[(k * stride + 1) % half_table]
                    elif bug == "stride_one":
                        w = tw[k % half_table]
                    else:
                        w = tw[k * stride]
                    u = a[i + k]
                    v = a[i + half + k] * w % P
                    a[i + k] = (u + v) % P
                    a[i + half + k] = (u - v) % P
            length <<= 1


def bitrev_perm(v):
    n = len(v)
    log_n = n.bit_length() - 1
    out = [0] * n
    for i in range(n):
        r = int(format(i, "0%db" % log_n)[::-1], 2) if log_n else 0
        out[r] = v[i]
    return out


# ---------------------------------------------------------------------------
# The encode (pcs.rs)
# ---------------------------------------------------------------------------

def coset_powers(h, nn):
    """pcs.rs:642-651."""
    out = []
    x = 1
    for _ in range(nn):
        out.append(x)
        x = x * h % P
    assert x != 1, "pcs zk: the coset generator has order dividing nn"
    return out


def encode_row_zk(ntt, msg, pad, pows, nn):
    """pcs.rs:655-674, steps 5a-5f, returning the nn-long encoded row."""
    n = len(msg)
    q = len(pad)
    assert n + q <= nn and nn % n == 0                                     # :659
    coeffs = list(msg)                                                     # 5a :660
    ntt.inverse(coeffs)                                                    # 5b :661
    out = coeffs + [0] * (nn - n)                                          # 5c :662-665
    for i in range(q):                                                     # 5d :666-669
        out[i] = (out[i] - pad[i]) % P
        out[n + i] = pad[i] % P
    for i in range(n + q):                                                 # 5e :670-672
        out[i] = out[i] * pows[i] % P
    ntt.forward(out)                                                       # 5f :673
    return out


def encode_row_zk_bug(ntt, msg, pad, pows, nn, bug):
    """The four (plus one bonus) wrong encodes of the negative controls."""
    n, q = len(msg), len(pad)
    coeffs = list(msg)
    if bug == "inverse_scaled_by_nn":
        ntt.transform(coeffs, True)
        ninv = finv(nn % P)                       # WRONG: 1/nn instead of 1/n
        coeffs = [c * ninv % P for c in coeffs]
    elif bug == "conjugate_root":
        ntt.transform_bug(coeffs, True, bug)
        ninv = finv(n % P)
        coeffs = [c * ninv % P for c in coeffs]
    elif bug in ("stride_off_by_one", "stride_one"):
        ntt.transform_bug(coeffs, True, bug)
        ninv = finv(n % P)
        coeffs = [c * ninv % P for c in coeffs]
    else:
        ntt.inverse(coeffs)
    out = coeffs + [0] * (nn - n)
    for i in range(q):
        out[i] = (out[i] - pad[i]) % P
        out[n + i] = pad[i] % P
    for i in range(n + q):
        out[i] = out[i] * pows[i] % P
    if bug == "dif_output_order":
        ntt.transform_dif(out, False)             # natural in, BIT-REVERSED out
    elif bug in ("conjugate_root", "stride_off_by_one", "stride_one"):
        ntt.transform_bug(out, False, bug)
    else:
        ntt.forward(out)
    return out


# ---------------------------------------------------------------------------
# Digests and the PRNG that generates the synthetic inputs
# ---------------------------------------------------------------------------

def row_bytes(row):
    """The canonical serialization: 8 little-endian bytes per entry -- the same
    byte order the column hashing feeds BLAKE3 (field.rs:88-90, pcs.rs:150)."""
    return b"".join(int(v).to_bytes(8, "little") for v in row)


def row_sha256(row):
    return hashlib.sha256(row_bytes(row)).hexdigest()


MASK64 = (1 << 64) - 1


class SplitMix64:
    """The vectors' PRNG. Deliberately NOT the prover's ZkRng: these are fixed
    SYNTHETIC inputs, and a device team must be able to regenerate them in any
    language from this definition alone."""

    def __init__(self, seed):
        self.s = seed & MASK64

    def next_u64(self):
        self.s = (self.s + 0x9E3779B97F4A7C15) & MASK64
        z = self.s
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK64
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK64
        return (z ^ (z >> 31)) & MASK64

    def fp(self):
        """A field element: one next_u64() reduced mod p (bias 2^-32; these are
        FIXTURES, not protocol randomness, so the bias is irrelevant)."""
        return self.next_u64() % P

    def fp_vec(self, n):
        return [self.fp() for _ in range(n)]


def seed_for(log_n, inv_rate, role):
    """role 1 = message, 2 = pad. Printed in every vector's JSON."""
    return (0x5A5A5A5A << 32) | (log_n << 16) | (inv_rate << 8) | role


# ---------------------------------------------------------------------------
# Self-checks: the reference against the DEFINITION, not against the Rust
# ---------------------------------------------------------------------------

def naive_eval(coeffs, x):
    """Horner, exactly the shape of ntt.rs:129-135's test helper."""
    acc = 0
    for c in reversed(coeffs):
        acc = (acc * x + c) % P
    return acc


def naive_dft(coeffs, w):
    n = len(coeffs)
    out = []
    x = 1
    for _ in range(n):
        out.append(naive_eval(coeffs, x))
        x = x * w % P
    return out


def naive_interpolate(values, w):
    """The inverse DFT by definition: c_i = (1/n) * sum_j v_j * w^(-i j)."""
    n = len(values)
    wi = finv(w)
    ninv = finv(n % P)
    out = []
    for i in range(n):
        acc = 0
        x = 1
        step = pow(wi, i, P)
        for j in range(n):
            acc = (acc + values[j] * x) % P
            x = x * step % P
        out.append(acc * ninv % P)
    return out


def selfcheck(log):
    ok = []

    def say(name, cond, detail=""):
        ok.append(bool(cond))
        log.append("  [%s] %s%s" % ("PASS" if cond else "FAIL", name,
                                    ("  " + detail) if detail else ""))

    log.append("S1  the field and the root, against field.rs's own pins")
    say("p = 2^64 - 2^32 + 1", P == 0xFFFFFFFF00000001, hex(P))
    say("two_adic_root(32) == 1753635133440165772 (field.rs:305)",
        two_adic_root(32) == 1753635133440165772)
    say("two_adic_root(1) == p-1 (field.rs:303)", two_adic_root(1) == P - 1)
    orders = all(pow(two_adic_root(k), 1 << k, P) == 1 and
                 (k == 0 or pow(two_adic_root(k), 1 << (k - 1), P) != 1)
                 for k in range(0, 21))
    say("two_adic_root(k) has exact order 2^k for k <= 20", orders)
    say("7 is a non-residue: 7^((p-1)/2) == -1 (field.rs:325)",
        pow(7, (P - 1) // 2, P) == P - 1)

    log.append("S2  forward transform == direct O(n^2) evaluation at omega^i")
    t = NttTables(16)
    for log_n in (0, 1, 2, 3, 4, 6):
        n = 1 << log_n
        rng = SplitMix64(0xC0FFEE + log_n)
        coeffs = rng.fp_vec(n)
        a = list(coeffs)
        t.forward(a)
        w = two_adic_root(log_n)
        say("n = 2^%d" % log_n, a == naive_dft(coeffs, w))

    log.append("S3  inverse == direct interpolation (1/n AFTER the transform)")
    for log_n in (1, 2, 3, 4, 6):
        n = 1 << log_n
        rng = SplitMix64(0xBEEF + log_n)
        values = rng.fp_vec(n)
        a = list(values)
        t.inverse(a)
        w = two_adic_root(log_n)
        say("n = 2^%d" % log_n, a == naive_interpolate(values, w))
        b = list(a)
        t.forward(b)
        say("round trip n = 2^%d" % log_n, b == values)

    log.append("S4  the shared table's max_log does not change any output")
    for log_n in (3, 4, 6):
        n = 1 << log_n
        rng = SplitMix64(0xD00D + log_n)
        base = rng.fp_vec(n)
        outs = []
        for ml in (log_n, log_n + 1, 10, 16):
            tt = NttTables(ml)
            a = list(base)
            tt.forward(a)
            outs.append(a)
        say("n = 2^%d over max_log in {n,n+1,10,16}" % log_n,
            all(o == outs[0] for o in outs))

    log.append("S5  zero-padded forward == evaluation at the nn-th roots "
               "(ntt.rs:157-170's own property)")
    n, nn = 64, 256
    rng = SplitMix64(0x5150)
    coeffs = rng.fp_vec(n)
    a = coeffs + [0] * (nn - n)
    t.forward(a)
    say("n = 64 -> nn = 256", a == naive_dft(coeffs + [0] * (nn - n),
                                             two_adic_root(8)))

    log.append("S6  encode_row_zk == f_data + Z_n * g_pad on the coset, "
               "by direct evaluation")
    for (log_n, rate, q) in ((3, 4, 4), (4, 4, 8), (6, 4, 32), (6, 8, 64)):
        n = 1 << log_n
        nn = n * rate
        rng = SplitMix64(0x1234 + log_n * 16 + rate)
        msg = rng.fp_vec(n)
        pad = rng.fp_vec(q)
        pows = coset_powers(COSET_H, nn)
        got = encode_row_zk(t, msg, pad, pows, nn)
        # the definition, with NO NTT anywhere:
        fdata = naive_interpolate(msg, two_adic_root(log_n))
        w_nn = two_adic_root(nn.bit_length() - 1)
        want = []
        x = COSET_H
        for _ in range(nn):
            zn = (pow(x, n, P) - 1) % P
            want.append((naive_eval(fdata, x) + zn * naive_eval(pad, x)) % P)
            x = x * w_nn % P
        say("n = 2^%d, rate %d, Q = %d" % (log_n, rate, q), got == want)
        # and the hiding property the coset buys: no systematic position
        subgroup = set()
        y = 1
        wn = two_adic_root(log_n)
        for _ in range(n):
            subgroup.add(y)
            y = y * wn % P
        pts = set()
        x = COSET_H
        for _ in range(nn):
            pts.add(x)
            x = x * w_nn % P
        say("  coset disjoint from G_n (no systematic column)",
            not (pts & subgroup))

    log.append("S7  the reference's OWN message interpolation is consistent: "
               "encode with Q = 0 re-evaluates the message on G_n")
    n, nn = 16, 64
    rng = SplitMix64(0x77)
    msg = rng.fp_vec(n)
    coeffs = list(msg)
    t.inverse(coeffs)
    say("interpolate then evaluate on G_n returns the message",
        naive_dft(coeffs, two_adic_root(4)) == msg)

    log.append("S8  the DIF control really is the SAME transform with the "
               "output permuted")
    for log_n in (3, 4, 6, 8):
        n = 1 << log_n
        rng = SplitMix64(0xABC + log_n)
        base = rng.fp_vec(n)
        a, b = list(base), list(base)
        t.forward(a)
        t.transform_dif(b, False)
        say("n = 2^%d: dif(x) == bitrev(dit(x))" % log_n, b == bitrev_perm(a))

    log.append("S9  the PRODUCTION widths against a closed form (no NTT): the "
               "Lagrange basis L_k(x) = w^k (x^n - 1) / (n (x - w^k))")
    for (log_n, rate) in ((8, 8), (10, 4), (14, 4)):
        n = 1 << log_n
        nn = n * rate
        tt = NttTables(nn.bit_length() - 1)
        pows = coset_powers(COSET_H, nn)
        w_n = two_adic_root(log_n)
        w_nn = two_adic_root(nn.bit_length() - 1)
        for k in (0, n - 1):
            msg = [0] * n
            msg[k] = 1
            got = encode_row_zk(tt, msg, [0] * 4, pows, nn)
            wk = pow(w_n, k, P)
            ninv = finv(n % P)
            want = []
            x = COSET_H
            for _ in range(nn):
                want.append(wk * ((pow(x, n, P) - 1) % P) % P
                            * finv((x - wk) % P) % P * ninv % P)
                x = x * w_nn % P
            say("n = 2^%d rate %d, message = e_%d" % (log_n, rate, k),
                got == want)

    log.append("S10 the PAD path by direct evaluation: f = Z_n * g_pad on the "
               "coset when the message is zero")
    for (log_n, rate, q, sample) in ((8, 8, 256, None), (14, 4, 256, 128)):
        n = 1 << log_n
        nn = n * rate
        tt = NttTables(nn.bit_length() - 1)
        pows = coset_powers(COSET_H, nn)
        pad = SplitMix64(seed_for(log_n, rate, 2)).fp_vec(q)
        got = encode_row_zk(tt, [0] * n, pad, pows, nn)
        w_nn = two_adic_root(nn.bit_length() - 1)
        step = 1 if sample is None else nn // sample
        agree = True
        for j in range(0, nn, step):
            x = COSET_H * pow(w_nn, j, P) % P
            want = ((pow(x, n, P) - 1) * naive_eval(pad, x)) % P
            if got[j] != want:
                agree = False
                break
        say("n = 2^%d rate %d, Q = %d, %s positions"
            % (log_n, rate, q, "all" if sample is None else str(sample)), agree)

    return all(ok)


# ---------------------------------------------------------------------------
# The vector set
# ---------------------------------------------------------------------------

# (log_n, inv_rate, Q, where it comes from)
PROFILES = [
    (3,  4,   4, "definitional; small enough to print and to check by hand"),
    (4,  4,   8, "definitional"),
    (6,  4,  32, "definitional"),
    (8,  4, 256, "the toy / frozen-seam row width at the rungs' rate"),
    (8,  8, 256, "THE TOY and the frozen seam: shape.rs:432 (log_cols 8, "
                 "inv_rate 8), private_seam.rs:28,30"),
    (10, 4, 256, "THE RUNGS: shape.rs:441-466 (rung), :486, :546, :609, :684, "
                 ":825 -- log_cols 10, inv_rate 4"),
    (14, 4, 256, "RUNG-W14 and 125M: shape.rs:763-781 and :861 -- log_cols 14, "
                 "inv_rate 4, 2^14 message -> 2^16 encoded"),
]

KINDS = ["zero", "zero_msg_seeded_pad", "delta0", "delta_last", "seeded"]


def make_inputs(kind, log_n, inv_rate, q):
    n = 1 << log_n
    if kind == "zero":
        return [0] * n, [0] * q, "all zero", "all zero"
    if kind == "zero_msg_seeded_pad":
        r = SplitMix64(seed_for(log_n, inv_rate, 2))
        return [0] * n, r.fp_vec(q), "all zero", "splitmix64(seed) %% p, %d draws" % q
    if kind == "delta0":
        m = [0] * n
        m[0] = 1
        return m, [0] * q, "1 at index 0, else 0", "all zero"
    if kind == "delta_last":
        m = [0] * n
        m[n - 1] = 1
        return m, [0] * q, "1 at index n-1, else 0", "all zero"
    if kind == "seeded":
        rm = SplitMix64(seed_for(log_n, inv_rate, 1))
        rp = SplitMix64(seed_for(log_n, inv_rate, 2))
        return (rm.fp_vec(n), rp.fp_vec(q),
                "splitmix64(seed) %% p, %d draws" % n,
                "splitmix64(seed) %% p, %d draws" % q)
    raise AssertionError(kind)


INLINE_INPUT_LIMIT = 1024      # full input arrays inline up to this width
FULL_ROW_LIMIT = 2048          # full encoded rows shipped up to this nn


def build_vectors(log):
    vectors = []
    full_rows = {}
    for (log_n, inv_rate, q, note) in PROFILES:
        n = 1 << log_n
        nn = n * inv_rate
        ntt = NttTables(nn.bit_length() - 1)
        pows = coset_powers(COSET_H, nn)
        for kind in KINDS:
            name = "w%dr%d-%s" % (log_n, inv_rate, kind)
            msg, pad, mrule, prule = make_inputs(kind, log_n, inv_rate, q)
            enc = encode_row_zk(ntt, msg, pad, pows, nn)
            rec = {
                "name": name,
                "profile_note": note,
                "log_n": log_n,
                "n": n,
                "inv_rate": inv_rate,
                "nn": nn,
                "q_pad": q,
                "coset_h": COSET_H,
                "msg_rule": mrule,
                "pad_rule": prule,
                "msg_seed": seed_for(log_n, inv_rate, 1) if kind == "seeded" else None,
                "pad_seed": (seed_for(log_n, inv_rate, 2)
                             if kind in ("seeded", "zero_msg_seeded_pad") else None),
                "msg_sha256": hashlib.sha256(row_bytes(msg)).hexdigest(),
                "pad_sha256": hashlib.sha256(row_bytes(pad)).hexdigest(),
                "encoded_sha256": row_sha256(enc),
                "encoded_first8": enc[:8],
                "encoded_last8": enc[-8:],
                "encoded_probes": {"1": enc[1], str(nn // 2): enc[nn // 2],
                                   str(nn - 1): enc[nn - 1]},
            }
            if n <= INLINE_INPUT_LIMIT:
                rec["msg"] = msg
                rec["pad"] = pad
            if nn <= FULL_ROW_LIMIT:
                rec["full_row_file"] = "full_rows.json"
                full_rows[name] = enc
            vectors.append(rec)
        log.append("  %-8s n = 2^%-2d rate %d nn = %-6d Q = %-3d  %d vectors"
                   % ("", log_n, inv_rate, nn, q, len(KINDS)))
    return vectors, full_rows


CONTROLS = [
    ("dif_output_order",
     "(a) decimation-in-frequency: the final transform returns its output in "
     "BIT-REVERSED order (every value right, every column at the wrong index)"),
    ("conjugate_root",
     "(b) the other two-adic root: the forward and inverse twiddle tables "
     "swapped (omega^-1 where the CPU uses omega)"),
    ("stride_off_by_one",
     "(c) an off-by-one twiddle stride: tw[k*(max_n/len) + 1] instead of "
     "tw[k*(max_n/len)]"),
    ("inverse_scaled_by_nn",
     "(d) the inverse NTT scaled by 1/nn instead of 1/n"),
    ("stride_one",
     "(bonus) the shared max-size table indexed as if it were the per-size "
     "table: tw[k] instead of tw[k*(max_n/len)]"),
]


def build_controls(log):
    out = []
    for (log_n, inv_rate, q) in ((14, 4, 256), (3, 4, 4), (6, 4, 32)):
        n = 1 << log_n
        nn = n * inv_rate
        ntt = NttTables(nn.bit_length() - 1)
        pows = coset_powers(COSET_H, nn)
        msg, pad, _, _ = make_inputs("seeded", log_n, inv_rate, q)
        good = encode_row_zk(ntt, msg, pad, pows, nn)
        entry = {
            "vector": "w%dr%d-seeded" % (log_n, inv_rate),
            "n": n, "nn": nn, "q_pad": q,
            "correct_sha256": row_sha256(good),
            "controls": [],
        }
        seen = {row_sha256(good): "CORRECT"}
        for (bug, desc) in CONTROLS:
            bad = encode_row_zk_bug(ntt, msg, pad, pows, nn, bug)
            d = row_sha256(bad)
            differs = sum(1 for x, y in zip(good, bad) if x != y)
            entry["controls"].append({
                "bug": bug,
                "description": desc,
                "sha256": d,
                "entries_differing_from_correct": differs,
                "first8": bad[:8],
                "probes": {"1": bad[1], str(nn // 2): bad[nn // 2],
                           str(nn - 1): bad[nn - 1]},
            })
            assert d not in seen, "control %s collides with %s" % (bug, seen[d])
            seen[d] = bug
        out.append(entry)
        log.append("  n = 2^%-2d nn = %-6d: %d controls, all digests distinct "
                   "from each other and from the correct row"
                   % (log_n, nn, len(CONTROLS)))
    return out


# ---------------------------------------------------------------------------
# The cross-check against Rust-produced committed bytes
# ---------------------------------------------------------------------------

CAPTURE_DIR = ("/home/victor/IntelligenceRegulation/results/"
               "zk60_native_captures_20260919/captures")


def capture_crosscheck(log):
    """The verifier's column identity (pcs.rs:1100-1145) on committed captures.

    A capture carries, per role: the CLEAR proximity vector (n message + Q pad
    entries in Fp2), the proximity row weights rho, and the 256 opened columns
    (each column's `rows` encoded Fp entries at a known index j). The verifier
    checks, for every opened j,

        sum_i rho_i * encoded[i][j]  ==  Enc(prox_vec)[j]

    where Enc is encode_row_zk applied to the vector's real and imaginary parts
    separately. Running MY encode on the clear vector and comparing at the 256
    opened indices tests the reference against bytes the Rust prover wrote."""
    results = []
    if not os.path.isdir(CAPTURE_DIR):
        log.append("  capture directory absent -- skipped")
        return results
    for fn in sorted(os.listdir(CAPTURE_DIR)):
        if not fn.endswith(".json"):
            continue
        path = os.path.join(CAPTURE_DIR, fn)
        with open(path) as fh:
            cap = json.load(fh)
        if "roles" not in cap:
            continue
        for role in cap["roles"]:
            pr = role["params"]
            n = 1 << pr["log_cols"]
            nn = n * pr["inv_rate"]
            q = role["q_pad"]
            ntt = NttTables(nn.bit_length() - 1)
            pows = coset_powers(COSET_H, nn)
            v = role["proximity_vector"]
            rho = role["proximity_rhos"]
            re = [x[0] for x in v]
            im = [x[1] for x in v]
            ere = encode_row_zk(ntt, re[:n], re[n:n + q], pows, nn)
            eim = encode_row_zk(ntt, im[:n], im[n:n + q], pows, nn)
            good = 0
            bad = []
            for col in role["columns"]:
                j = col["index"]
                acc = (0, 0)
                for i, x in enumerate(col["values"]):
                    acc = f2add(acc, f2mul((rho[i][0], rho[i][1]), (x % P, 0)))
                want = (ere[j], eim[j])
                if acc == want:
                    good += 1
                else:
                    bad.append(j)
            entry = {
                "capture": fn,
                "profile": cap.get("profile"),
                "role": role["role"],
                "n": n, "nn": nn, "q_pad": q,
                "rows": len(role["columns"][0]["values"]),
                "columns_checked": len(role["columns"]),
                "columns_agreeing": good,
                "columns_disagreeing": bad,
            }
            # SENSITIVITY, on the first role only: the same check with each
            # wrong encode, to show the cross-check is not vacuous.
            if not results:
                sens = {}
                for (bug, _desc) in CONTROLS:
                    bre = encode_row_zk_bug(ntt, re[:n], re[n:n + q], pows, nn, bug)
                    bim = encode_row_zk_bug(ntt, im[:n], im[n:n + q], pows, nn, bug)
                    agree = 0
                    for col in role["columns"]:
                        j = col["index"]
                        acc = (0, 0)
                        for i, x in enumerate(col["values"]):
                            acc = f2add(acc, f2mul((rho[i][0], rho[i][1]), (x % P, 0)))
                        if acc == (bre[j], bim[j]):
                            agree += 1
                    sens[bug] = agree
                entry["sensitivity_columns_agreeing_under_each_bug"] = sens
                log.append("    sensitivity (same role, wrong encodes): " +
                           ", ".join("%s %d/%d" % (b, a, len(role["columns"]))
                                     for b, a in sens.items()))
            results.append(entry)
            log.append("  %s %-7s n = %-5d nn = %-5d rows = %-4d  %d/%d opened "
                       "columns agree" % (fn[:12], role["role"], n, nn,
                                          len(role["columns"][0]["values"]),
                                          good, len(role["columns"])))
    return results


# ---------------------------------------------------------------------------

OUT = os.path.dirname(os.path.abspath(__file__))


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    log = []
    log.append("zk60 encode conformance vectors -- a third implementation")
    log.append("source read: /home/victor/wt-zk60-block125m @ a8e4939 "
               "(zkp-core/src/{field,ntt,pcs}.rs)")
    log.append("")
    log.append("== SELF-CHECKS (the reference against the DEFINITION) ==")
    ok = selfcheck(log)
    log.append("")
    log.append("self-checks: %s" % ("ALL PASS" if ok else "FAILURES PRESENT"))
    if not ok:
        print("\n".join(log))
        return 1
    if mode == "selfcheck":
        print("\n".join(log))
        return 0

    log.append("")
    log.append("== VECTORS ==")
    vectors, full_rows = build_vectors(log)
    log.append("  total: %d vectors over %d (width, rate) profiles"
               % (len(vectors), len(PROFILES)))

    log.append("")
    log.append("== NEGATIVE CONTROLS ==")
    controls = build_controls(log)

    log.append("")
    log.append("== CROSS-CHECK against committed capture bundles ==")
    cross = capture_crosscheck(log)

    meta = {
        "kind": "zk60-encode-conformance-vectors",
        "version": 1,
        "generated_by": "results/zk60_encode_vectors/encode_ref.py",
        "source_worktree": "/home/victor/wt-zk60-block125m",
        "source_commit": "a8e4939fa00eb12f71738d19d166c0aaf4492cd6",
        "field_modulus": P,
        "generator": GENERATOR,
        "two_adicity": TWO_ADICITY,
        "two_adic_root_32": two_adic_root(32),
        "coset_generator": COSET_H,
        "digest_rule": "sha256 over the row's entries, 8 little-endian bytes "
                       "each, in natural column order",
        "prng": {
            "name": "splitmix64",
            "gamma": "0x9E3779B97F4A7C15",
            "mix": ["z ^= z >> 30; z *= 0xBF58476D1CE4E5B9",
                    "z ^= z >> 27; z *= 0x94D049BB133111EB",
                    "z ^= z >> 31"],
            "field_element": "one next_u64() reduced mod p",
            "seed_rule": "(0x5A5A5A5A << 32) | (log_n << 16) | (inv_rate << 8) "
                         "| role, role 1 = message, 2 = pad",
        },
        "pads_are_synthetic": "FIXED synthetic pads. The prover draws its pads "
                              "from ZkRng (pcs.rs:777, rng.rs:73-77) before any "
                              "branch; the pad DRAW is not part of these "
                              "vectors, only the pad's PLACEMENT in the encode.",
    }

    with open(os.path.join(OUT, "vectors.json"), "w") as fh:
        json.dump({"meta": meta, "vectors": vectors}, fh, indent=1)
        fh.write("\n")
    with open(os.path.join(OUT, "full_rows.json"), "w") as fh:
        json.dump({"meta": {"kind": "zk60-encode-conformance-full-rows",
                            "digest_rule": meta["digest_rule"]},
                   "rows": full_rows}, fh, indent=1)
        fh.write("\n")
    with open(os.path.join(OUT, "negative_controls.json"), "w") as fh:
        json.dump({"meta": {"kind": "zk60-encode-negative-controls"},
                   "entries": controls}, fh, indent=1)
        fh.write("\n")
    with open(os.path.join(OUT, "capture_crosscheck.json"), "w") as fh:
        json.dump({"meta": {
            "kind": "zk60-encode-capture-crosscheck",
            "identity": "sum_i rho_i * encoded[i][j] == Enc(prox_vec)[j] for "
                        "every opened column j (pcs.rs:1100-1145)",
            "what_it_does_not_cover": "only the 256 opened columns of each "
                                      "commitment; the rows themselves are "
                                      "private and are not in the bundle",
        }, "checks": cross}, fh, indent=1)
        fh.write("\n")

    log.append("")
    log.append("wrote vectors.json, full_rows.json, negative_controls.json, "
               "capture_crosscheck.json")
    print("\n".join(log))
    return 0


if __name__ == "__main__":
    sys.exit(main())
