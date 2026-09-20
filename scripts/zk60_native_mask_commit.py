"""The masking commitment M: a Python port of its row layout and opening.

WHAT THIS IS.  `hashline/src/zk.rs` commits the CFS mask coefficients of every
sumcheck slot in a small PRODUCT-FORM Ligero-class commitment of its own,
called M throughout this lane.  Its opening -- the product polynomial `q`, the
proximity vector `prox` and 256 opened columns -- is one of the verifier's
channels, and until now the P10 gate could not model it: three of its ten OPEN
channels said, in the gate's own words, "a port of encode_coeffs_coset and
mask_commit's row layout into this tool; no capture field is missing".  This
module IS that port.

WHAT IT PORTS, function by function (each ported function's docstring quotes
the Rust it transcribes, with the line range as of the pinned bytes):

  hashline/src/zk.rs
      MASK_LOG_MSG / MASK_LOG_DOM / MASK_Q        (373-375)
      MaskCommit's row layout                     (377-390, 430-467)
      encode_coeffs_coset                         (424-428)
      combined_weights                            (470-487)
      weight_polys                                (490-496)
      poly_mul_512                                (499-510)
      mask_open                                   (512-550)
      mask_verify's three identities              (552-590)
  hashline/src/private_block/argument.rs
      the DECLARED functional order               (361-376, 924-925)
  zkp-core/src/sumcheck.rs
      CfsMask::len / sum_weights / eval_weights   (197-243)
  zkp-core/src/ntt.rs, zkp-core/src/pcs.rs
      forward/inverse conventions, coset_powers   (55-108, 605-614)

WHAT IT DOES NOT DO.  It does not hash, so the Merkle root, the 256 leaf salts
and the 12-level authentication paths of M stay exactly where the gate already
puts them: ARGUED under M-2 and M-3.  It is a LINEAR model of M's opening at
four captured receipts' challenges.  **Nothing here establishes a privacy
property and nothing here is a privacy acceptance.**

THE MODEL.  With S slots, M has 2S + 4 base rows over the coset 7*G_4096:

    rows 0 .. 2S-1   the a-rows, two per slot (re, im).  Row 2s+k holds, in
                     VALUE form over G_512, the message
                         [ L_s mask coefficients | 256 pads | zeros ]
                     with L_s = CfsMask::len(n_s, d_s) = n_s*d_s + 2.
    rows 2S, 2S+1    b_re, b_im: 1024 coefficients each, with the single
                     linear constraint b[512] = -b[0], i.e. zero sum over
                     G_512.
    rows 2S+2, 2S+3  u_re, u_im: 1024 free coefficients each.

DATA vs BLINDING, and the hypothesis the argument needs.  For M the DATA is
the mask coefficients (they are hidden); the BLINDING is the 256 pads of each
a-row, the b rows and the u rows.  The composition memo's hypotheses H3/H4 ask
that M's opening depend on the coefficients ONLY through one functional V(a)
that is itself a public function of the rest of the view.  This module does
not assume that: it DERIVES it and checks every step, from

    sum over G_512 of p_{a_s} p_{W_s}  =  sum_t msg_s[t] * ws[s][t]
                                       =  sum_{t < L_s} a_s[t] * ws[s][t]

(the second equality needs ws[s][t] = 0 for t >= L_s, which `combined_weights`
gives by construction and which this module CHECKS on the capture), so that
b's zero-sum constraint reads 512 (q[0] + q[512]) = V(a) -- the verifier's own
first check -- and nothing else about a is pinned.
"""

from __future__ import annotations

import collections
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_jv_field import (  # noqa: E402
    F2_ONE,
    F2_ZERO,
    P,
    Ntt,
    coset_powers,
    f2_add,
    f2_from_list,
    f2_inv,
    f2_is_zero,
    f2_mul,
    f2_mul_base,
    f2_neg,
    f2_sub,
    inv,
    rank,
    two_adic_root,
)

# --------------------------------------------------------------- constants
# zk.rs:373-375
#   pub const MASK_LOG_MSG: u32 = 9;   // 512 message positions per a-row
#   pub const MASK_LOG_DOM: u32 = 12;  // 4096 evaluation positions
#   pub const MASK_Q: usize = 256;     // opened columns (== pads per a-row)
MASK_LOG_MSG = 9
MASK_LOG_DOM = 12
MASK_Q = 256
MSG_N = 1 << MASK_LOG_MSG  # 512
DOM_N = 1 << MASK_LOG_DOM  # 4096
COSET_GEN = 7  # `coset_powers(Fp::new(7), dom)`, zk.rs:433
NONRESIDUE = 7  # Fp2: U^2 = 7 (zk.rs:528 multiplies the im*im term by 7)


# ------------------------------------------------------------- source pins
class SourcePinError(RuntimeError):
    """A pinned Rust source changed: the port may have drifted from it."""


Pin = collections.namedtuple("Pin", "path sha256 blob why")

# sha256 and git blob id of each ported file, read at 1857c04 on branch
# zk60-native-jointview (the same bytes the four captures of 2026-09-19 were
# produced and verified by, except where the shared repin history of
# zk60_native_terminal_polys.py records otherwise).
SOURCE_PINS = (
    Pin(
        "hashline/src/zk.rs",
        "c5b54753d01d85f3469b8fbb873a36c7fcbc91faf15d16004f8cecff019c1310",
        "28f32f184751d14188a45b830c42fde8811ca155",
        "mask_commit / mask_open / mask_verify, encode_coeffs_coset, "
        "combined_weights, weight_polys, poly_mul_512, and the three constants",
    ),
    Pin(
        "hashline/src/private_block/argument.rs",
        "e62f46c29fe41848737e157b65c16d11d2c2c9501722b88660420a7a21a642ab",
        "e492afdb18bf205d246abafd89f8ae82a9eec3b2",
        "the DECLARED functional order: run_slot 361-376 and argument 924-925",
    ),
    Pin(
        "hashline/src/private_attention/argument.rs",
        "3343620eefa848421633971210305a356c183848ac15f566a503244ef2283a25",
        "338689f1770081f50cf7338959bc7e8990624960",
        "the same declared order for the attention profile's 18 slots",
    ),
    Pin(
        "zkp-core/src/sumcheck.rs",
        "56dbb8c742d970d3ffd851dd052fbfd4cc4a0a1ab0630258955ffd250e007d19",
        "5543a3a6d34d958951731adf1dd03547f458afaa",
        "CfsMask::len / sum_weights / eval_weights, the weights every "
        "functional carries",
    ),
    Pin(
        "zkp-core/src/ntt.rs",
        "97572d4f242637d21a089388abad4b5b39136c62036faa17ae94b3ba6f170890",
        "66758af0c58f7daf609d1fee3bf93dd607c867e9",
        "forward/inverse: coefficients <-> evaluations at omega^i in natural "
        "order, the convention the whole port rests on",
    ),
    Pin(
        "zkp-core/src/pcs.rs",
        "2d9149564ff7f77482bcc314ad1949eef4e183d2a6c9b6b3f8ac7ac4cc72b24d",
        "8806bbe0e9ca8d9e3f8717972e84fd81a1bf8ec3",
        "coset_powers, and its assertion that the coset misses the subgroup",
    ),
)


def _blob_id(raw: bytes) -> str:
    return hashlib.sha1(b"blob %d\0" % len(raw) + raw).hexdigest()


def check_source_pins(root: str | None = None, pins=SOURCE_PINS) -> dict:
    """HARD ERROR if a pinned Rust source is missing or changed.

    Same discipline as `zk60_native_terminal_polys.check_source_pins`: this
    module is a transcription of code that lives elsewhere and silent drift is
    the failure mode that would matter, so every entry point calls this first.
    """
    root = root or os.path.dirname(HERE)
    out = {}
    for pin in pins:
        path = os.path.join(root, pin.path)
        if not os.path.exists(path):
            raise SourcePinError(
                f"source pin: {pin.path} is missing under {root}. The port of the "
                "masking commitment is pinned to that file; re-read it before "
                "re-pinning."
            )
        with open(path, "rb") as fh:
            raw = fh.read()
        got = hashlib.sha256(raw).hexdigest()
        blob = _blob_id(raw)
        if got != pin.sha256:
            raise SourcePinError(
                f"source pin MISMATCH for {pin.path}:\n"
                f"  pinned sha256 {pin.sha256} (git blob {pin.blob})\n"
                f"  found  sha256 {got} (git blob {blob})\n"
                "The Python port of the masking commitment was written against "
                "the pinned bytes. Re-read the changed functions line by line, "
                "update the port and only then re-pin. Do NOT re-pin to make "
                "this pass."
            )
        out[pin.path] = {"sha256": got, "git_blob": blob, "ported": pin.why}
    return out


# ------------------------------------------------- CfsMask (zkp-core/sumcheck.rs)
def mask_len(n_vars: int, degree: int) -> int:
    """`CfsMask::len` (sumcheck.rs:197-199): `n_vars * degree + 2`."""
    return n_vars * degree + 2


def sum_weights(n_vars: int, degree: int):
    """`CfsMask::sum_weights` (sumcheck.rs:222-227).

        let mut w = vec![Fp2::from_u64(1 << (n_vars - 1)); Self::len(..)];
        w[0] = Fp2::from_u64(1 << n_vars);
        w[1] = Fp2::ONE;
    """
    L = mask_len(n_vars, degree)
    w = [((1 << (n_vars - 1)) % P, 0)] * L
    w[0] = ((1 << n_vars) % P, 0)
    w[1] = F2_ONE
    return w


def eval_weights(rho, degree: int):
    """`CfsMask::eval_weights` (sumcheck.rs:230-243).

        w.push(Fp2::ONE);
        w.push(rho.iter().fold(Fp2::ONE, |a, r| a.mul(*r)));
        for r in rho { let mut xp = Fp2::ONE;
                       for _ in 0..degree { xp = xp.mul(*r); w.push(xp); } }
    """
    w = [F2_ONE]
    acc = F2_ONE
    for r in rho:
        acc = f2_mul(acc, r)
    w.append(acc)
    for r in rho:
        xp = F2_ONE
        for _ in range(degree):
            xp = f2_mul(xp, r)
            w.append(xp)
    return w


# ------------------------------------------------------- zk.rs, the encoders
def encode_coeffs_coset(ntt: Ntt, coeffs, pows):
    """`encode_coeffs_coset` (zk.rs:424-428).

        for v in out { *v = Fp::ZERO; }
        for (i, c) in coeffs.iter().enumerate() { out[i] = c.mul(pows[i]); }
        ntt.forward(out);

    `out` has length 4096, so this is P(7 * omega_4096^j) for j = 0..4095.
    """
    out = [0] * DOM_N
    for i, c in enumerate(coeffs):
        out[i] = c * pows[i] % P
    return ntt.forward(out)


def weight_polys(w, ntt: Ntt):
    """`weight_polys` (zk.rs:490-496): p_W as coefficients (re, im).

        let mut re = w.iter().map(|x| x.c0); let mut im = w.iter().map(|x| x.c1);
        ntt.inverse(&mut re); ntt.inverse(&mut im);
    """
    re = ntt.inverse([x[0] for x in w])
    im = ntt.inverse([x[1] for x in w])
    return re, im


def poly_mul_512(a, b, ntt: Ntt):
    """`poly_mul_512` (zk.rs:499-510): 1024 coefficients of a*b, each deg < 512.

        let mut ea = vec![ZERO; 1024]; ea[..a.len()] = a;   (same for eb)
        ntt.forward(&mut ea); ntt.forward(&mut eb);
        for (x, y) in ea.zip(eb) { *x = x.mul(*y); }
        ntt.inverse(&mut ea);
    """
    m2 = 2 * MSG_N
    ea = list(a) + [0] * (m2 - len(a))
    eb = list(b) + [0] * (m2 - len(b))
    ea = ntt.forward(ea)
    eb = ntt.forward(eb)
    ea = [x * y % P for x, y in zip(ea, eb)]
    return ntt.inverse(ea)


def combined_weights(specs, functionals, theta):
    """`combined_weights` (zk.rs:470-487): the theta-batched weights and value.

        let mut ws = specs.map(|_| vec![Fp2::ZERO; 512]);
        let mut v = ZERO; let mut th = ONE;
        for f in functionals {
            for (row, w) in &f.terms {
                assert_eq!(w.len(), CfsMask::len(specs[*row]));
                for (j, x) in w.enumerate() { ws[*row][j] += th * x; }
            }
            v += th * f.value;
            th *= theta;
        }

    NOTE the two facts the whole disclosed-dimension argument rests on, both
    visible right here: (1) functional i is weighted by theta^i, so the ORDER
    of `functionals` is load-bearing; (2) the assert bounds every term's
    weights by L_row, so ws[row][j] = 0 for every j >= L_row -- the pads are
    never weighted.
    """
    ws = [[F2_ZERO] * MSG_N for _ in specs]
    v = F2_ZERO
    th = F2_ONE
    failures = []
    for i, f in enumerate(functionals):
        for term in f["terms"]:
            row = term["slot"]
            w = [f2_from_list(x) for x in term["weights"]]
            L = mask_len(specs[row][0], specs[row][1])
            if len(w) != L:
                failures.append(
                    f"functional {i}: {len(w)} weights for a mask of {L} coefficients"
                )
                continue
            for j, x in enumerate(w):
                if not f2_is_zero(x):
                    ws[row][j] = f2_add(ws[row][j], f2_mul(th, x))
        v = f2_add(v, f2_mul(th, f2_from_list(f["value"])))
        th = f2_mul(th, theta)
    return ws, v, failures


# --------------------------------------- argument.rs, the DECLARED order
#
# run_slot, argument.rs:361-376 (the comment on 361 is the declaration):
#
#   // M functionals, in the declared order: [Gamma_s if standalone] eval_s;
#   // host Gammas last
#   match kind {
#       SlotKind::Standalone => acc.fs.push(MaskFunctional {
#           terms: vec![(s, sum_weights(s).map(|w| w.mul(c)))], value: scalar }),
#       SlotKind::Host => { let mut terms = vec![(s, sum_weights(s).map(|w| w.mul(c)))];
#           for (hs, coef) in &def.hosted {
#               let k = coef.mul(acc.cs[*hs]).neg();
#               terms.push((*hs, sum_weights(*hs).map(|w| w.mul(k)))); }
#           acc.host_fs.push(MaskFunctional { terms, value: scalar }); }
#       SlotKind::Private => {}
#   }
#   acc.fs.push(MaskFunctional {
#       terms: vec![(s, CfsMask::eval_weights(&rho_full, degree))], value: g_val });
#
# argument, argument.rs:924-925:
#
#   let hosts = std::mem::take(&mut acc.host_fs);
#   acc.fs.extend(hosts);
#
# So the order is: for s = 0 .. N_SLOTS-1 in slot order, a Standalone slot's
# Gamma IMMEDIATELY BEFORE its own evaluation functional, then that slot's
# evaluation functional; a Host slot contributes only its evaluation there,
# its Gamma being deferred; and the host Gammas come LAST, in slot order.  A
# Private slot contributes its evaluation only.
DECLARED_ORDER = (
    "for each slot s in slot order: [Gamma_s, if slot s is Standalone] then "
    "eval_s; then every Host slot's Gamma, in slot order, last "
    "(private_block/argument.rs:361-376 and 924-925)"
)


def declared_functional_order(capture, replay):
    """Rebuild the declared order from the slot kinds and CHECK the capture.

    Every entry is checked three ways: its POSITION in the list, its VALUE
    against the slot's own captured scalar (Gamma) or mask_eval (eval), and
    its WEIGHTS against `CfsMask::sum_weights * c` / `CfsMask::eval_weights`
    recomputed here from the replayed challenges.  An earlier memo had the
    host Gammas interleaved; this function is the pin against that.
    """
    args = capture.doc["arguments"]
    fns = capture.mask["functionals"]
    expect = []  # (kind, slot)
    hosts = []
    for a in args:
        s = a["slot"]
        if a["kind"] == "Standalone":
            expect.append(("Gamma", s))
        elif a["kind"] == "Host":
            hosts.append(("Gamma", s))
        expect.append(("eval", s))
    expect.extend(hosts)

    out = {
        "declared_order": DECLARED_ORDER,
        "slots": len(args),
        "kinds": collections.Counter(a["kind"] for a in args),
        "expected_functionals": len(expect),
        "captured_functionals": len(fns),
        "order_as_declared": [f"{k}_{s:02d}" for k, s in expect],
        "position_matches": 0,
        "value_matches": 0,
        "weight_matches": 0,
        "host_gammas_last": all(k == "Gamma" for k, _ in expect[-len(hosts):])
        if hosts
        else True,
        "failures": [],
    }
    if len(expect) != len(fns):
        out["failures"].append(
            f"the declared order gives {len(expect)} functionals, the capture "
            f"carries {len(fns)}"
        )
        return out
    for i, ((kind, s), f) in enumerate(zip(expect, fns)):
        a = args[s]
        c = replay.slot_c[s]
        rows = [t["slot"] for t in f["terms"]]
        got_v = f2_from_list(f["value"])
        if kind == "Gamma":
            want_v = f2_from_list(a["scalar"])
            want_rows = [s] + [h["slot"] for h in a["hosted"]]
            want_w = [[f2_mul(w, c) for w in sum_weights(*capture.mask["specs"][s])]]
            for h in a["hosted"]:
                hs = h["slot"]
                k = f2_neg(f2_mul(f2_from_list(h["coefficient"]), replay.slot_c[hs]))
                want_w.append(
                    [f2_mul(w, k) for w in sum_weights(*capture.mask["specs"][hs])]
                )
        else:
            want_v = f2_from_list(a["mask_eval"])
            want_rows = [s]
            rho_full = list(replay.rho[s])
            want_w = [eval_weights(rho_full, a["degree"])]
        if rows == want_rows:
            out["position_matches"] += 1
        else:
            out["failures"].append(f"functional {i} ({kind} slot {s}): rows {rows}")
        if got_v == want_v:
            out["value_matches"] += 1
        else:
            out["failures"].append(f"functional {i} ({kind} slot {s}): value differs")
        got_w = [[f2_from_list(x) for x in t["weights"]] for t in f["terms"]]
        if got_w == want_w:
            out["weight_matches"] += 1
        else:
            out["failures"].append(f"functional {i} ({kind} slot {s}): weights differ")
    out["ok"] = not out["failures"]
    return out


# --------------------------------------------------- the M model and solver
class MaskModel:
    """M's layout at one capture: the nodes, the caches and the solver.

    Row r = 2s+k of M holds, in value form over G_512, the message
    `[a_s^(k) | 256 pads | zeros]`; rows 2S..2S+3 hold b_re, b_im, u_re, u_im
    as 1024 coefficients (`zk.rs::mask_commit`, 430-467).
    """

    def __init__(self, capture, replay):
        self.cap = capture
        self.rp = replay
        self.m = capture.mask
        self.specs = [tuple(s) for s in self.m["specs"]]
        self.S = len(self.specs)
        self.n_base = 2 * self.S + 4
        self.theta = replay.theta
        self.rhos = [f2_from_list(v) for v in self.m["proximity_rhos"]]
        self.ntt = Ntt(MASK_LOG_DOM)
        self.pows = coset_powers(COSET_GEN, DOM_N)
        self.failures = []

        self.ws, self.v, wf = combined_weights(self.specs, self.m["functionals"], self.theta)
        self.failures.extend(wf)
        self.L = [mask_len(n, d) for n, d in self.specs]

        # the sampled columns, in the captured order, and the distinct nodes
        self.idx = [c["index"] for c in self.m["columns"]]
        self.distinct = sorted(set(self.idx))
        self.D = len(self.distinct)
        g = two_adic_root(MASK_LOG_MSG)  # the generator of G_512
        wd = two_adic_root(MASK_LOG_DOM)
        self.g = g
        self.gp = [pow(g, t, P) for t in range(MSG_N)]  # g^t, t = 0..511
        self.x = [COSET_GEN * pow(wd, j, P) % P for j in self.distinct]
        self.minv = inv(MSG_N)
        # K_j = (x_j^512 - 1) / 512, the common factor of every Lagrange weight
        self.K = [(pow(y, MSG_N, P) - 1) % P * self.minv % P for y in self.x]
        self._cache = {}

    # ------------------------------------------------------- shape checks
    def shape(self):
        """The shape facts `mask_verify` relies on, checked against the capture."""
        cols = self.m["columns"]
        heights = {len(c["values"]) for c in cols}
        out = {
            "slots": self.S,
            "rows": self.n_base,
            "rows_expected": 2 * self.S + 4,
            "column_height_unique": len(heights) == 1 and heights == {self.n_base},
            "q_len": len(self.m["q"]),
            "prox_len": len(self.m["prox"]),
            "q_prox_len_expected": 2 * MSG_N,
            "sampled_columns": len(self.idx),
            "distinct_columns": self.D,
            "pads_per_a_row": MASK_Q,
            "pad_margin": MASK_Q - self.D,
            "proximity_rhos": len(self.rhos),
            "proximity_rhos_expected": 2 * self.S + 2,
            "nodes_distinct": len(set(self.x)) == self.D,
            "nodes_off_G512": all((pow(y, MSG_N, P) - 1) % P != 0 for y in self.x),
            "coefficients_plus_pads_fit": all(L + MASK_Q <= MSG_N for L in self.L),
            # combined_weights never weights a pad: ws[row][j] = 0 for j >= L_row
            "weights_vanish_above_L": all(
                all(f2_is_zero(w[j]) for j in range(self.L[r], MSG_N))
                for r, w in enumerate(self.ws)
            ),
            "data_coefficients_fp": 2 * sum(self.L),
            "blinding_unknowns_fp": 2 * self.S * MASK_Q + 2 * (2 * MSG_N - 1) + 2 * (2 * MSG_N),
        }
        bad = [
            k
            for k in (
                "column_height_unique",
                "nodes_distinct",
                "nodes_off_G512",
                "coefficients_plus_pads_fit",
                "weights_vanish_above_L",
            )
            if not out[k]
        ]
        if out["rows"] != out["rows_expected"]:
            bad.append("rows")
        if out["q_len"] != 2 * MSG_N or out["prox_len"] != 2 * MSG_N:
            bad.append("q/prox length")
        if out["proximity_rhos"] != out["proximity_rhos_expected"]:
            bad.append("proximity rhos")
        if out["pad_margin"] < 0:
            bad.append("pad budget")
        out["ok"] = not bad
        out["failed"] = bad
        return out

    # ------------------------------------------------------- the pad solve
    def _pad_cache(self, L, width=MASK_Q):
        """Everything the pad solve needs that depends only on (L, width).

        The a-row's encoded value at node y is, with L_t the Lagrange basis of
        G_512,  P(y) = sum_t msg[t] L_t(y)  and  L_t(y) = K_y g^t / (y - g^t).
        Over the `width` pad positions t = L .. L+width-1 that is a Cauchy
        matrix in the distinct nodes {y_j} and the distinct points {g^t}, so
        it is invertible whenever width == D; this cache holds the pieces of
        the closed-form solve (a rational interpolation) rather than an
        elimination.
        """
        key = (L, width)
        if key in self._cache:
            return self._cache[key]
        n = min(width, self.D)
        z = [self.gp[L + p] for p in range(width)]
        zs = z[:n]  # the pad positions actually solved for
        xs = self.x[: self.D]
        # Z(x_j) = prod_p (x_j - z_p) over the solved positions
        Zx = []
        for y in xs[:n]:
            acc = 1
            for zp in zs:
                acc = acc * ((y - zp) % P) % P
            Zx.append(acc)
        # barycentric weights of the node set {x_j}, j < n
        wbar = []
        for i in range(n):
            acc = 1
            for j2 in range(n):
                if j2 != i:
                    acc = acc * ((xs[i] - xs[j2]) % P) % P
            wbar.append(inv(acc))
        # Pi(z) = prod_j (z - x_j) at each solved pad point
        Pi = []
        for zp in zs:
            acc = 1
            for j2 in range(n):
                acc = acc * ((zp - xs[j2]) % P) % P
            Pi.append(acc)
        # Z'(z_p) = prod_{q != p} (z_p - z_q)
        Zp = []
        for p in range(n):
            acc = 1
            for q in range(n):
                if q != p:
                    acc = acc * ((zs[p] - zs[q]) % P) % P
            Zp.append(acc)
        # 1/(z_p - x_j) for every solved pad point and node, batch inverted
        diffs = [(zs[p] - xs[j2]) % P for p in range(n) for j2 in range(n)]
        invd = _batch_inverse(diffs)
        # 1/(x_j - g^t) for the DATA positions t < L, batch inverted
        ddiffs = [(xs[j2] - self.gp[t]) % P for j2 in range(self.D) for t in range(L)]
        dinv = _batch_inverse(ddiffs) if L else []
        pre = [
            inv(zs[p] * Zp[p] % P) if zs[p] * Zp[p] % P else 0 for p in range(n)
        ]
        Kinv = [inv(k) for k in self.K[:n]]
        got = {
            "n": n,
            "width": width,
            "L": L,
            "zs": zs,
            "Zx": Zx,
            "wbar": wbar,
            "Pi": Pi,
            "Zp": Zp,
            "invd": invd,
            "dinv": dinv,
            "pre": pre,
            "Kinv": Kinv,
            "singular": any(v == 0 for v in Zp) or any(v == 0 for v in Zx),
        }
        self._cache[key] = got
        return got

    def solve_pads(self, row, data, targets, width=MASK_Q):
        """Pads for one a-row: the blinding that meets the captured columns.

        The row's message is `[data | pads | zeros]`; `targets[j]` is the
        captured value of this row in the column at distinct node j.  Returns
        (pads, residual_failures): with `width == D` the Cauchy system is
        square and the pads are unique; with `width > D` the remaining
        `width - D` pads are free and are set to zero; with `width < D` the
        system is overdetermined and the residual at the unmet nodes is
        reported (the "a pad removed from M" control).
        """
        L = len(data)
        c = self._pad_cache(L, width)
        n = c["n"]
        if c["singular"]:
            return None, ["the Cauchy system is singular: a repeated node"]
        # t_j = (target_j - data part) / K_j, for the n solved nodes
        tj = []
        for j in range(n):
            acc = 0
            base = j * L
            for t in range(L):
                if data[t]:
                    acc = (acc + data[t] * self.gp[t] % P * c["dinv"][base + t]) % P
            dpart = self.K[j] * acc % P
            tj.append((targets[j] - dpart) % P * c["Kinv"][j] % P)
        # N is the degree < n interpolant of (t_j * Z(x_j)) at the nodes x_j
        a = [c["wbar"][j] * (tj[j] * c["Zx"][j] % P) % P for j in range(n)]
        pads = [0] * width
        for p in range(n):
            acc = 0
            base = p * n
            for j in range(n):
                if a[j]:
                    acc = (acc + a[j] * c["invd"][base + j]) % P
            pads[p] = c["Pi"][p] * acc % P * c["pre"][p] % P
        return pads, []

    # ---------------------------------------------------- the forward map
    def a_row_message(self, data, pads):
        """The a-row's 512 message values: `[coefficients | 256 pads | zeros]`.

            let mut msg = vec![Fp::ZERO; m];
            msg[..part.len()].copy_from_slice(part);
            let pads = rng.fp_vec(MASK_Q);
            msg[part.len()..part.len() + MASK_Q].copy_from_slice(&pads);
                                                            (zk.rs:443-446)
        """
        msg = [0] * MSG_N
        msg[: len(data)] = list(data)
        msg[len(data) : len(data) + len(pads)] = list(pads)
        return msg

    def a_coefs(self, msg):
        """`ntt.inverse(&mut msg)` (zk.rs:447): the G_512 interpolant's coefficients."""
        return self.ntt.inverse(list(msg))

    def encode_row(self, coeffs):
        """One base row's 4096 coset evaluations (zk.rs:448, 460)."""
        return encode_coeffs_coset(self.ntt, coeffs, self.pows)


def _batch_inverse(vals):
    """Montgomery's trick: one modular inversion for the whole list."""
    n = len(vals)
    if not n:
        return []
    pre = [0] * n
    acc = 1
    for i, v in enumerate(vals):
        pre[i] = acc
        acc = acc * v % P
    acc = inv(acc)
    out = [0] * n
    for i in range(n - 1, -1, -1):
        out[i] = acc * pre[i] % P
        acc = acc * vals[i] % P
    return out


# ------------------------------------------------------------- the preimage
class MaskPreimage:
    """A preimage for M's captured opening at a CHOSEN coefficient vector.

    Given coefficients `a` (one Fp2 list of length L_s per slot), this solves
    for every blinding value M holds -- the 256 pads of each a-row, the two b
    rows and the two u rows -- and then RECOMPUTES the whole published opening
    through the ported forward map and compares it, entry by entry, with the
    capture.  Nothing is read from the capture but the published opening: no
    witness, no mask coefficient, no salt and no pad of the real prover.
    """

    def __init__(self, model: MaskModel, coefs, functionals=None, pad_width=MASK_Q):
        self.mm = model
        self.coefs = coefs
        self.pad_width = pad_width
        self.fns = functionals if functionals is not None else model.m["functionals"]
        if functionals is None:
            self.ws, self.v = model.ws, model.v
        else:
            self.ws, self.v, _ = combined_weights(model.specs, self.fns, model.theta)
        self.failures = []
        self.pads = None
        self.b = None
        self.u = None
        self.ok = False

    # -------------------------------------------------------------- solve
    def build(self):
        mm = self.mm
        cols = mm.m["columns"]
        # column values by DISTINCT node, per row
        by_node = {}
        for c in cols:
            by_node.setdefault(c["index"], c["values"])
        order = mm.distinct

        # 1. the pads of every a-row: the only blinding the a-rows carry
        self.pads = []
        for s in range(mm.S):
            for k in range(2):
                r = 2 * s + k
                data = [self.coefs[s][t][k] for t in range(mm.L[s])]
                targets = [by_node[j][r] for j in order]
                pads, fail = mm.solve_pads(r, data, targets, width=self.pad_width)
                if fail:
                    self.failures.extend(f"a-row {r}: {x}" for x in fail)
                    return self
                self.pads.append(pads)

        # 2. the a-rows' interpolant coefficients, then q's product part
        self.acoef = []
        for s in range(mm.S):
            for k in range(2):
                r = 2 * s + k
                data = [self.coefs[s][t][k] for t in range(mm.L[s])]
                msg = mm.a_row_message(data, self.pads[r])
                self.acoef.append(mm.a_coefs(msg))
        prod_re = [0] * (2 * MSG_N)
        prod_im = [0] * (2 * MSG_N)
        for s in range(mm.S):
            w_re, w_im = weight_polys(self.ws[s], mm.ntt)
            a_re, a_im = self.acoef[2 * s], self.acoef[2 * s + 1]
            rr = poly_mul_512(a_re, w_re, mm.ntt)
            ii = poly_mul_512(a_im, w_im, mm.ntt)
            ri = poly_mul_512(a_re, w_im, mm.ntt)
            ir = poly_mul_512(a_im, w_re, mm.ntt)
            for i in range(2 * MSG_N):
                prod_re[i] = (prod_re[i] + rr[i] + ii[i] * NONRESIDUE) % P
                prod_im[i] = (prod_im[i] + ri[i] + ir[i]) % P
        self.prod = (prod_re, prod_im)

        # 3. b is forced by q (zk.rs:518-532: q = b + the product part)
        q = [f2_from_list(x) for x in mm.m["q"]]
        self.b = (
            [(q[i][0] - prod_re[i]) % P for i in range(2 * MSG_N)],
            [(q[i][1] - prod_im[i]) % P for i in range(2 * MSG_N)],
        )
        # 4. u is forced by prox (zk.rs:537-541)
        prox = [f2_from_list(x) for x in mm.m["prox"]]
        acc = [F2_ZERO] * (2 * MSG_N)
        for row, r in enumerate(mm.rhos):
            src = (
                self.acoef[row]
                if row < 2 * mm.S
                else (self.b[0] if row == 2 * mm.S else self.b[1])
            )
            for i, cc in enumerate(src):
                if cc:
                    acc[i] = f2_add(acc[i], f2_mul_base(r, cc))
        self.u = (
            [(prox[i][0] - acc[i][0]) % P for i in range(2 * MSG_N)],
            [(prox[i][1] - acc[i][1]) % P for i in range(2 * MSG_N)],
        )
        self.prox_acc = acc
        self.ok = True
        return self

    # ------------------------------------------------------------ verify
    def verify(self, columns="full"):
        """Recompute every published entry and compare with the capture.

        The three groups differ in what they actually test, and the record
        says so rather than letting one number stand for all three:

          * `b_admissible` -- b must satisfy `b[512] = -b[0]` (zk.rs:454-455).
            This is the ONE thing the q channel pins: it holds exactly when
            V(a) = 512 (q[0] + q[512]).
          * the opened columns -- genuinely independent data: the pads were
            solved by a rational interpolation and are re-encoded here through
            the NTT path `mask_commit` itself uses.
          * q and prox -- reproduced BY CONSTRUCTION (b and u were defined as
            the residues), so their entry counts record that the two paths
            agree arithmetically, not that anything new was tested.
        """
        mm = self.mm
        out = {"ok": False}
        if not self.ok:
            out["failures"] = self.failures
            return out
        m2 = 2 * MSG_N
        # (a) b's zero-sum admissibility, and the identity behind it
        b_ad = (self.b[0][MSG_N] == (-self.b[0][0]) % P) and (
            self.b[1][MSG_N] == (-self.b[1][0]) % P
        )
        q = [f2_from_list(x) for x in mm.m["q"]]
        lhs = f2_mul_base(f2_add(q[0], q[MSG_N]), MSG_N % P)
        vprime = self.functional_value()
        out["b_admissible"] = bool(b_ad)
        out["q_sum_identity_holds"] = lhs == vprime
        out["functional_value_equals_the_captured_batch"] = vprime == mm.v
        # (b) q and prox, recomputed through the forward map
        qm = sum(
            1
            for i in range(m2)
            if (self.b[0][i] + self.prod[0][i]) % P != q[i][0]
            or (self.b[1][i] + self.prod[1][i]) % P != q[i][1]
        )
        prox = [f2_from_list(x) for x in mm.m["prox"]]
        pm = sum(
            1
            for i in range(m2)
            if f2_add((self.u[0][i], self.u[1][i]), self.prox_acc[i]) != prox[i]
        )
        out["q_entries"] = m2
        out["q_mismatches"] = qm
        out["q_reproduced_by_construction"] = True
        out["prox_entries"] = m2
        out["prox_mismatches"] = pm
        out["prox_reproduced_by_construction"] = True
        # (c) the opened columns: every base row re-encoded
        enc = []
        for r in range(2 * mm.S):
            enc.append(mm.encode_row(self.acoef[r]))
        for c in (self.b[0], self.b[1], self.u[0], self.u[1]):
            enc.append(mm.encode_row(c))
        cols = mm.m["columns"]
        if columns != "full":
            cols = cols[: int(columns)]
        cm = 0
        checked = 0
        first = None
        for c in cols:
            j = c["index"]
            for r in range(mm.n_base):
                checked += 1
                if enc[r][j] != c["values"][r]:
                    cm += 1
                    if first is None:
                        first = {"column": j, "row": r}
        out["column_entries"] = checked
        out["column_mismatches"] = cm
        out["first_column_mismatch"] = first
        out["all_entries_equal"] = bool(
            b_ad and qm == 0 and pm == 0 and cm == 0 and out["q_sum_identity_holds"]
        )
        out["ok"] = out["all_entries_equal"]
        return out

    def functional_value(self):
        """V(a) = sum_s sum_{t < L_s} ws[s][t] * a_s[t], the ONE functional.

        The identity this rests on (derived, not assumed): the sum over G_512
        of p_{a_s} p_{W_s} equals sum_t msg_s[t] ws[s][t], and ws[s][t] = 0
        for t >= L_s, so the pads drop out and only the coefficients remain.
        """
        mm = self.mm
        v = F2_ZERO
        for s in range(mm.S):
            for t in range(mm.L[s]):
                w = self.ws[s][t]
                if not f2_is_zero(w):
                    v = f2_add(v, f2_mul(w, self.coefs[s][t]))
        return v

    def blinding_digest(self):
        """sha256 of the exhibited blinding: checkable, and not printed.

        The blinding is prover randomness this tool CONSTRUCTS; it is not read
        from any capture and it is not a witness. The digest keeps the
        evidence free of 60,000-odd field elements.
        """
        h = hashlib.sha256()
        for row in self.pads:
            for x in row:
                h.update(x.to_bytes(8, "little"))
        for v in (self.b[0], self.b[1], self.u[0], self.u[1]):
            for x in v:
                h.update(x.to_bytes(8, "little"))
        return h.hexdigest()


# ------------------------------------------- the coefficient vectors we use
SEED = "zk60-mask-commit/coefficients/v1"


def synthetic_coefficients(model: MaskModel, tag: str):
    """A public, deterministic coefficient vector: no witness is read.

    value = sha256('<SEED>|<tag>|<slot>|<index>|<part>') read little-endian
    modulo P.  This is prover randomness of the SAME kind M's own coefficients
    are (uniform Fp2), generated from a published seed, so nothing private
    enters the tool and nothing private can leave it.
    """
    out = []
    for s in range(model.S):
        row = []
        for t in range(model.L[s]):
            vals = []
            for part in (0, 1):
                h = hashlib.sha256(f"{SEED}|{tag}|{s}|{t}|{part}".encode()).digest()
                vals.append(int.from_bytes(h[:16], "little") % P)
            row.append((vals[0], vals[1]))
        out.append(row)
    return out


def force_functional(model: MaskModel, coefs, target, ws=None):
    """Correct one coefficient so that V(coefs) == target.

    Picks the first (slot, index) whose batched weight is nonzero and sets
    a[s][t] += (target - V(a)) / ws[s][t].  The result is still a public
    deterministic vector; it is simply the affine shift onto the plane the
    verifier's own first check cuts out.
    """
    ws = ws if ws is not None else model.ws
    got = F2_ZERO
    for s in range(model.S):
        for t in range(model.L[s]):
            if not f2_is_zero(ws[s][t]):
                got = f2_add(got, f2_mul(ws[s][t], coefs[s][t]))
    for s in range(model.S):
        for t in range(model.L[s]):
            if not f2_is_zero(ws[s][t]):
                delta = f2_mul(f2_sub(target, got), f2_inv(ws[s][t]))
                new = [list(r) for r in coefs]
                new[s][t] = f2_add(coefs[s][t], delta)
                return new, {"slot": s, "index": t}
    return None, None


# ---------------------------------------------- the disclosed dimension
def disclosed_dimension(model: MaskModel, extra_functionals=()):
    """M's disclosed dimension over its own unknown space, computed.

    The unknown space is the mask coefficients, `sum_s 2 L_s` over Fp.  The
    view pins a coefficient vector exactly when a preimage exists, and the
    solve above shows that happens exactly when V(a) equals the captured
    batch: the pads meet the a-columns for EVERY a (the Cauchy block is
    square and nonsingular), b is then forced and is admissible only on that
    plane, and u is forced with no constraint at all.  So

        disclosed = rank_Fp of the functionals the view pins
                  = rank_Fp [ V ]   (one Fp2 functional, so 2 over Fp)

    and this function COMPUTES that rank from the batched weights rather than
    asserting it.  `extra_functionals` models a view that published more than
    the batch (the "a second functional leaked" control).
    """
    width = 2 * sum(model.L)
    rows = []

    def add(ws_vec):
        # one Fp2 functional -> two Fp rows: the real and imaginary parts of
        # sum_s sum_t w[s][t] * a[s][t], with a[s][t] = (re, im) two unknowns
        r0 = [0] * width
        r1 = [0] * width
        col = 0
        for s in range(model.S):
            for t in range(model.L[s]):
                w = ws_vec[s][t]
                # (w0 + U w1)(a0 + U a1) = (w0 a0 + 7 w1 a1) + U (w0 a1 + w1 a0)
                r0[col] = w[0]
                r0[col + 1] = w[1] * NONRESIDUE % P
                r1[col] = w[1]
                r1[col + 1] = w[0]
                col += 2
        rows.append(r0)
        rows.append(r1)

    add(model.ws)
    for ws_vec in extra_functionals:
        add(ws_vec)
    got = rank(rows, width)
    return {
        "coefficient_unknowns_fp": width,
        "published_functionals_fp2": 1 + len(extra_functionals),
        "disclosed_fp_computed": got,
        "disclosed_fp_predicted": 2 * (1 + len(extra_functionals)),
        "fibre_dimension_fp": width - got,
        "matches_prediction": got == 2 * (1 + len(extra_functionals)),
    }


# ------------------------------------------------------- the controls
def mask_controls(model: MaskModel, columns=8, permute=(0, 1), leak=(0, 1)):
    """Each control must PASS on the honest capture and FAIL when perturbed.

    A control that cannot fire at an honest capture is not a control, so every
    entry records the honest verdict beside the perturbed one.
    """
    out = {}
    honest_c, _ = force_functional(model, synthetic_coefficients(model, "a1"), model.v)
    honest = MaskPreimage(model, honest_c).build().verify(columns=columns)
    out["honest"] = {
        "preimage_exhibited": honest["ok"],
        "column_entries": honest["column_entries"],
        "column_mismatches": honest["column_mismatches"],
        "b_admissible": honest["b_admissible"],
    }

    # (1) a pad removed from M: one blinding unknown fewer than the DISTINCT
    # opened columns.  256 pads against 246 distinct nodes has margin 10, so
    # the control has to go below the distinct count to bite.
    w = model.D - 1
    pre = MaskPreimage(model, honest_c, pad_width=w).build()
    ver = pre.verify(columns="full") if pre.ok else {"column_mismatches": None}
    out["one_pad_fewer_than_the_distinct_opened_columns"] = {
        "what": f"every a-row of M modelled with {w} pads against {model.D} distinct "
        f"opened columns (the real budget is {MASK_Q}, margin {MASK_Q - model.D})",
        "honest_passes": honest["ok"],
        "column_mismatches": ver.get("column_mismatches"),
        "b_admissible": ver.get("b_admissible"),
        "fires": bool(ver.get("column_mismatches")),
        "why": "with fewer pad symbols than distinct opened columns the a-row's "
        "message cannot meet the captured column values at every sampled node, so "
        "the view leaves the image of the blinding map and has no preimage. This is "
        "the control on the side that CAN fail: at the real budget the Cauchy block "
        "is square and nonsingular, and then EVERY admissible coefficient vector on "
        "the V plane has a preimage",
    }

    # (2) the functional order permuted: theta^i moves, so the verifier's batch
    # is a different functional.  Two flavours, because two different identities
    # catch it.
    fns = list(model.m["functionals"])
    i, j = permute
    fns[i], fns[j] = fns[j], fns[i]
    ws_p, v_p, _ = combined_weights(model.specs, fns, model.theta)
    p1 = MaskPreimage(model, honest_c, functionals=fns).build()
    v1 = p1.verify(columns=columns)
    # the second flavour removes b's excuse: coefficients chosen so that the
    # PERMUTED batch still hits the captured 512 (q[0] + q[512]).
    onplane, _ = force_functional(
        model, synthetic_coefficients(model, "a1"), model.v, ws=ws_p
    )
    p2 = MaskPreimage(model, onplane, functionals=fns).build()
    v2 = p2.verify(columns="full")
    out["functional_order_permuted"] = {
        "what": f"functionals {i} and {j} of the DECLARED order swapped, so each is "
        "weighted by the other's power of theta",
        "honest_passes": honest["ok"],
        "batched_value_changed": v_p != model.v,
        "same_coefficients_b_admissible": v1["b_admissible"],
        "same_coefficients_fires": not v1["ok"],
        "forced_to_the_captured_sum_b_admissible": v2["b_admissible"],
        "forced_to_the_captured_sum_column_entries": v2["column_entries"],
        "forced_to_the_captured_sum_column_mismatches": v2["column_mismatches"],
        "forced_to_the_captured_sum_first_mismatch": v2["first_column_mismatch"],
        "forced_to_the_captured_sum_fires": not v2["ok"],
        "fires": bool(not v1["ok"] and not v2["ok"] and v2["b_admissible"]),
        "why": "the first flavour fails b's zero-sum: the permuted batch is a "
        "different functional of the same coefficients. The second removes that "
        "excuse by forcing the coefficients onto the PERMUTED plane -- b is then "
        "admissible, and the view still has no preimage, because the verifier's "
        "per-column identity acc = sum_s a_s(x) W_s(x) + b(x) reads the weights "
        "themselves and the captured b columns no longer fit. The order is pinned "
        "by the columns, not only by the scalar sum",
    }

    # (3) a second functional leaked: two slots' evaluations published unbatched
    base = disclosed_dimension(model)
    extra = [single_functional_weights(model, k) for k in leak]
    leaked = disclosed_dimension(model, extra_functionals=extra)
    out["second_functional_leaked"] = {
        "what": f"functionals {list(leak)} published on their own beside the theta "
        "batch, as an unbatched opening would",
        "honest_passes": base["disclosed_fp_computed"] == 2,
        "disclosed_fp_honest": base["disclosed_fp_computed"],
        "disclosed_fp_leaked": leaked["disclosed_fp_computed"],
        "fibre_fp_honest": base["fibre_dimension_fp"],
        "fibre_fp_leaked": leaked["fibre_dimension_fp"],
        "fires": leaked["disclosed_fp_computed"] > base["disclosed_fp_computed"],
        "why": "batching is what keeps M's disclosure at one Fp2. Publishing two of "
        "the 34 functional values separately makes three independent Fp2 functionals "
        "of the coefficients visible and the disclosed dimension rises from 2 to 6 "
        "over Fp, with the fibre losing exactly those 4 dimensions",
    }

    names = [k for k in out if isinstance(out[k], dict) and "fires" in out[k]]
    out["all_fire"] = all(out[k]["fires"] for k in names)
    out["control_names"] = names
    out["ok"] = bool(out["all_fire"] and honest["ok"])
    return out


def single_functional_weights(model: MaskModel, i: int):
    """The weight table of ONE captured functional, unbatched (for the leak control)."""
    ws = [[F2_ZERO] * MSG_N for _ in model.specs]
    f = model.m["functionals"][i]
    for term in f["terms"]:
        row = term["slot"]
        for j, x in enumerate(term["weights"]):
            ws[row][j] = f2_add(ws[row][j], f2_from_list(x))
    return ws
