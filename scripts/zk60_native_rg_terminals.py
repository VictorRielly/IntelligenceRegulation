#!/usr/bin/env python3
"""The PER-SLOT TERMINAL IDENTITY at the run's shape, as far as the bundle
honestly allows.

    fin_s == c_s * mask_eval_s + poly_s(vals_s)

(`let g_val = fin.sub((def.poly)(&vals)).mul(c.inv());`,
 `hashline/src/private_block/argument.rs:381`).  The capture writes
`terminal_polynomial = fin - c*mask_eval`, so recomputing `poly_s(vals_s)`
from the PUBLISHED TERMINALS and comparing it against that field is exactly
the verifier's own final check, with nothing taken on trust.

WHAT MAKES THIS POSSIBLE NOW, AND WHAT STILL DOES NOT.  Stage 15 of the Rust
lane added `run.json["plane_index"]` — which plane each slot's `terminals[j]`
is an evaluation of, in the prover's push order.  That was the missing field
(`ZK60_NATIVE_RUN_GATE.md` §3 item 4).  It is NOT the only thing a slot's
closure reads: a slot may also have PUBLIC tables, and a run bundle carries
their LENGTH and SHA-256 but not their VALUES
(`run.json["public_tables_included"] == false`).  A public table that is a
function of the SHAPE alone is rebuilt here and checked against the
capture's own SHA-256 before it is used; a public table that folds the
public WEIGHTS, the norm gains, the RoPE tables or the exp / activation
tables cannot be rebuilt, because a bundle carries none of those.  Every
slot in the second class stays OPEN, per slot, with that reason.

COVERED AT THIS SHAPE — 12 of the 23 slots:

    00 SC_SS     01 SC_SSM    02 SC_TZC    03 SC_LZC    04 SC_RS
    08 SC_SCORE  09 SC_PV     17 SC_SZC    18 SC_FZC    20 SC_ZS
    21 SC_IO_IN  22 SC_IO_OUT

They include everything the rung adds that the toy does not have, except the
weight-folding slots: the PAD-ZERO term `mu_pad * (1 - supp) * sum zeta^j *
plane_j` (slots 02, 03, 17, 18, and the `supp` gate in 00, 01, 04, 17, 18),
the GROUPED-HEAD (GQA) padded head slots (slots 08 and 09 read `A_QR8` /
`A_KR8` / `A_P` / `A_V8` at the key-value group's own coordinates, and slot
17's `Dom::Ht` indicator is the head one), the run's TWO BOUNDARY CLAIM
SITES (slots 21 and 22, whose IO table is an internal boundary in every
stage but the first / last), and the third `sigma_s` limb (`A_SR2` /
`A_SG2`, slot 17).

NOT COVERED, all for one reason, stated per slot below: the slot's public
table is not a function of the shape.

    05 SC_QMM  06 SC_KMM  07 SC_VMM  10 SC_WO   11 SC_GMM  12 SC_UMM
    13 SC_DMM      -- fold_rows_i8 / fold_cols_i8 of the public weights
    14 SC_DZC      -- the two norm gains gamma_a, gamma_m
    15 SC_QZC  16 SC_KVZC -- the RoPE (cos, sin) tables
    19 SC_TAB      -- the exp and activation table values

REVIEWED OBLIGATION.  Each ported polynomial equals its Rust closure by
READING.  The reading is pinned: the bundle's own
`manifest.json["source_pins"]` names `argument.rs`, `layout.rs`,
`protocol.rs` and `plane_index.rs` by SHA-256, and [`check_source_pins`]
compares them with the digests this port was written against.  A pin that
moved makes every slot NOT CHECKED rather than silently wrong.  What the
machine does check is stronger than the pin: every rebuilt public table is
compared with the capture's SHA-256 of the real one, and the identity itself
must hold at the run's real challenges for every covered slot of every stage.

NOTHING HERE IS A PRIVACY STATEMENT.  This is a consistency check of the
verifier's view at two captured runs' real challenges.
"""

from __future__ import annotations

import hashlib
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_jv_cfs import sumcheck_final  # noqa: E402
from zk60_native_jv_field import (  # noqa: E402
    F2_ONE,
    F2_ZERO,
    P,
    eq_table_msb,
    f2_add,
    f2_from_list,
    f2_mul,
    f2_mul_base,
    f2_sub,
)

add, sub, mul, mulb = f2_add, f2_sub, f2_mul, f2_mul_base
ONE, ZERO = F2_ONE, F2_ZERO

# ------------------------------------------------------------- source pins
# The digests of the Rust this port was READ from, which are exactly the
# digests `run-c-tame` / `run-d-zero` pin in their own manifests.  Four of the
# seven files a bundle pins decide what a slot's polynomial is; the other
# three (`run_capture.rs`, `run.rs`, `boundary.rs`) decide the bundle's shape
# and are checked by `zk60_native_rg_bundle`.
PORTED_FROM = {
    "src/private_block/argument.rs":
        "909670c96562e7ff99b7ad37f6c3aae027574f3c0e9ab74f01a27e45058bf675",
    "src/private_block/layout.rs":
        "fec2e6476f165e1e3be7871a3dfbdef56a4619f5b2e7560eb98ff2c97587a99f",
    "src/private_block/protocol.rs":
        "4e916c693ad8e6c62e8774ddb3d829f5e1c116932e74bb1c6088d62ab4aee449",
    "src/private_block/plane_index.rs":
        "9de8320a84770560d2b998c514b0e9745a8f6c9f0c1d0cdefda8164137107611",
}
# Not pinned by a bundle, and read for the pad rule and the domain geometry.
# Their digests are recorded so that a later reader can see what was read.
ALSO_READ = {
    "src/private_block/pad.rs":
        "7b6a990be900ad56e890660e9e3587c19fefc69f434a9bb3d4eab817f603d1ff",
    "src/private_block/shape.rs":
        "144012d5d960446784a64a451b01ada2d4d6bdd9493ede51e4142e90d28942e0",
    "src/private_block/witness.rs":
        "b9b66c024e7ca68d2a0ae4ba46241eb2abbccc8c8d94fe828041abbc710850ad",
}


def check_source_pins(bundle) -> dict:
    """The bundle's own `source_pins` against the digests this port was
    written from.  A moved pin is a refusal, never a silent re-read."""
    pins = {p["file"]: p["sha256"] for p in bundle.manifest.get("source_pins", [])}
    moved, missing = [], []
    for f, want in PORTED_FROM.items():
        got = pins.get(f)
        if got is None:
            missing.append(f)
        elif got != want:
            moved.append(f"{f}: the bundle pins {got[:12]}, the port was read at {want[:12]}")
    return {
        "ported_from": PORTED_FROM,
        "also_read_not_pinned_by_a_bundle": ALSO_READ,
        "pins_missing_from_the_bundle": missing,
        "pins_that_moved": moved,
        "ok": not moved and not missing,
    }


# ------------------------------------------------- calibration constants
# `layout.rs` consts.  These are the PUBLIC calibration of the private-block
# kernel and do not move with a shape; the three that DO move at the rung
# (`norm_wrho` 31, `wrho_s` 17, `f_e` 12) are read from `run.json["shape"]`.
NORM_CEPS = 1        # layout.rs:64
F_P = 9              # shape.rs:38, the softmax quotient's scale
MASK_SCORE = -127    # layout.rs, the masked-out score
SH_S = 6             # layout.rs:68
SH_G = 7             # layout.rs (the gate's requantisation shift)
SH_H_PROD = 14       # layout.rs (the hidden product's shift)
LIMBS_ISQRT = 3      # shape.rs:28; `N_LIMBS = 3 * LIMBS_ISQRT = 9`
U8_LEN = 256         # layout.rs:59
# `gamma.mul_base(Fp::new(TAG))`, tables_attn.rs
TAG_EXP, TAG_U8, TAG_ACT = 129, 133, 134

POW256 = [(pow(256, j, P), 0) for j in range(4)]


def k(v: int):
    """`Fp2::from_i64` (zkp-core/src/field.rs:148)."""
    return (v % P, 0)


def double(a):
    return add(a, a)


def eq_point(r, s):
    """`eq_point` (zkp-core/src/mle.rs:54)."""
    if len(r) != len(s):
        raise ValueError("eq_point arity")
    acc = ONE
    for a, b in zip(r, s):
        acc = mul(acc, add(mul(a, b), mul(sub(ONE, a), sub(ONE, b))))
    return acc


# =====================================================================
#  the pad rule, ported and then CHECKED against the capture's own digests
# =====================================================================
class PadGeometry:
    """`pad.rs` and the parts of `shape.rs` the indicators need, at the
    bundle's own shape.  Every domain log is READ from the plane index table,
    never derived: `domain_log_at`'s P-3 lift is the table's business."""

    def __init__(self, shape_raw: dict, domain_log: dict):
        self.s = shape_raw
        self.domain_log = dict(domain_log)

    def log(self, dom: str) -> int:
        return self.domain_log[dom]

    def size(self, dom: str) -> int:
        return 1 << self.domain_log[dom]

    def true_size(self, dom: str) -> int:
        """`Shape::true_size` (shape.rs:405)."""
        s = self.s
        return {
            "T": s["tokens"],
            "Ht": s["q_heads"] * s["tokens"],
            "L": 3 * LIMBS_ISQRT * s["tokens"],
            "D": s["tokens"] * s["width"],
            "Q": s["tokens"] * s["q_heads"] * s["head_dim"],
            "Kv": s["tokens"] * s["kv_heads"] * s["head_dim"],
            "S": s["q_heads"] * s["tokens"] * s["tokens"],
            "F": s["tokens"] * s["hidden"],
            "Tab": U8_LEN,
        }[dom]

    def pads(self, dom: str) -> bool:
        """`Shape::pads` (shape.rs:430)."""
        return self.size(dom) != self.true_size(dom)

    def head_slot(self, h: int) -> int:
        """`Shape::head_slot` (shape.rs:338), correction C-1."""
        s = self.s
        group = s["q_heads"] // s["kv_heads"]
        per = s["h_pad"] // s["kv_heads"]
        return (h // group) * per + (h % group)

    # --------------------------------------------------- BitForm (pad.rs:124)
    @staticmethod
    def _bitform(lim: int, pad: int):
        if not (pad & (pad - 1) == 0 and 0 < lim <= pad):
            raise ValueError(f"BitForm::of({lim}, {pad})")
        m = pad.bit_length() - 1
        if lim == pad:
            return ("always", ())
        if lim & (lim - 1) == 0:
            return ("allzero", tuple(range(lim.bit_length() - 1, m)))
        q = pad - lim
        if q & (q - 1) == 0:
            return ("notallone", tuple(range(q.bit_length() - 1, m)))
        return None

    @staticmethod
    def _at(form, x: int) -> int:
        kind, bits = form
        if kind == "always":
            return 1
        if kind == "allzero":
            return 1 if all((x >> b) & 1 == 0 for b in bits) else 0
        return 0 if all((x >> b) & 1 == 1 for b in bits) else 1

    def closed_form_indicator(self, dom: str):
        """`pad::closed_form_indicator` (pad.rs:160)."""
        s = self.s
        t_pad, d_pad, f_pad, dh = s["t_pad"], s["d_pad"], s["f_pad"], s["head_dim"]
        per = s["h_pad"] // s["kv_heads"]
        bf = self._bitform

        def head():
            return bf(s["q_heads"] // s["kv_heads"], per)

        if dom == "T":
            axes = [(1, bf(s["tokens"], t_pad))]
        elif dom == "D":
            axes = [(1, bf(s["width"], d_pad)), (d_pad, bf(s["tokens"], t_pad))]
        elif dom == "F":
            axes = [(1, bf(s["hidden"], f_pad)), (f_pad, bf(s["tokens"], t_pad))]
        elif dom == "Kv":
            axes = [(s["kv_heads"] * dh, bf(s["tokens"], t_pad))]
        elif dom == "Q":
            axes = [(dh, head()), (d_pad, bf(s["tokens"], t_pad))]
        elif dom == "Ht":
            axes = [(1, bf(s["tokens"], t_pad)), (t_pad, head())]
        elif dom == "S":
            axes = [(1, bf(s["tokens"], t_pad)), (t_pad, bf(s["tokens"], t_pad)),
                    (t_pad * t_pad, head())]
        elif dom == "L":
            axes = [(1, bf(s["tokens"], t_pad)),
                    (t_pad, bf(3 * LIMBS_ISQRT, self.size("L") // t_pad))]
        else:
            axes = [(1, bf(U8_LEN, self.size("Tab")))]
        factors = []
        for stride, form in axes:
            if form is None:
                return None
            if form[0] != "always":
                factors.append(((stride & -stride).bit_length() - 1, form))
        v = [1] * self.size(dom)
        for x in range(len(v)):
            for shift, form in factors:
                if v[x]:
                    v[x] = self._at(form, x >> shift)
        return v

    def support_indicator(self, dom: str):
        """`pad::support_indicator` (pad.rs:48) through `Geom::support`
        (witness.rs:211)."""
        s = self.s
        t, d, f = s["tokens"], s["width"], s["hidden"]
        hq, hkv, dh = s["q_heads"], s["kv_heads"], s["head_dim"]
        t_pad, d_pad, f_pad = s["t_pad"], s["d_pad"], s["f_pad"]
        kvw = hkv * dh
        if dom == "D":
            idx = [tt * d_pad + i for tt in range(t) for i in range(d)]
        elif dom == "Q":
            idx = [tt * d_pad + self.head_slot(h) * dh + i
                   for tt in range(t) for h in range(hq) for i in range(dh)]
        elif dom == "Kv":
            idx = [tt * kvw + kv * dh + i
                   for tt in range(t) for kv in range(hkv) for i in range(dh)]
        elif dom == "S":
            idx = [(self.head_slot(h) * t_pad + tt) * t_pad + j
                   for h in range(hq) for tt in range(t) for j in range(t)]
        elif dom == "F":
            idx = [tt * f_pad + j for tt in range(t) for j in range(f)]
        elif dom == "T":
            idx = list(range(t))
        elif dom == "Ht":
            idx = [self.head_slot(h) * t_pad + tt for h in range(hq) for tt in range(t)]
        elif dom == "L":
            idx = [kk * t_pad + tt for kk in range(3 * LIMBS_ISQRT) for tt in range(t)]
        else:
            idx = list(range(U8_LEN))
        v = [0] * self.size(dom)
        for i in idx:
            v[i] = 1
        return v

    def indicator_table(self, dom: str):
        """`pad::indicator_table` (pad.rs:335)."""
        c = self.closed_form_indicator(dom)
        return c if c is not None else self.support_indicator(dom)

    def supp(self, dom: str, cube: int):
        """`B::supp` (argument.rs:556): the indicator tiled over the slot's
        own cube, or None where the domain does not pad."""
        if not self.pads(dom):
            return None
        t = self.indicator_table(dom)
        if len(t) == 0 or cube == 0 or cube % len(t) != 0:
            raise ValueError(
                f"an indicator that does not tile its slot's cube ({len(t)} in {cube})"
            )
        rep = cube // len(t)
        return [t[x // rep] for x in range(cube)]

    def causal_mask(self):
        """`causal_mask_at` (argument.rs:761)."""
        t = self.s["t_pad"]
        return [1 if x % t <= (x // t) % t else 0 for x in range(self.size("S"))]

    def ones_tab(self):
        """`SC_ZS`'s all-ones vector over `Dom::Tab` (argument.rs:1435)."""
        return [1] * self.size("Tab")


def table_digest(values) -> str:
    """The SHA-256 the capture records for a public table: each `Fp2` as
    `c0` then `c1`, little-endian u64 (`run_capture.rs:788`,
    `field.rs:193`).  `values` here are BASE-field integers (`c1 = 0`),
    which is what every rebuildable table is."""
    b = bytearray()
    for x in values:
        b += (x % P).to_bytes(8, "little") + b"\x00" * 8
    return hashlib.sha256(bytes(b)).hexdigest()


# =====================================================================
#  the lookup lists, by plane NAME (layout.rs::lookups_at)
# =====================================================================
def _byte(name):
    return ([(name, 1)], 0)


def _scaled(name, c):
    return ([(name, c)], 0)


def _sym(name):
    """`sym`, the int8 subset [-127, 127] (layout.rs:274)."""
    return [([(name, 1)], 127), ([(name, -1)], 127)]


def lookups_at(dom: str, counts: dict, shape_raw: dict):
    """`layout.rs::lookups_at` (layout.rs:667), written in plane NAMES.

    Only the three things the doc-comment there names move with a shape: the
    plane ids (handled by names), the byte-limb counts `ln` / `ls` / `lp`,
    and the `scaled` coefficient that pins the top limb's slack bits.
    """
    ln, ls, lp = counts["ln"], counts["ls"], counts["lp"]
    norm_wrho, wrho_s = shape_raw["norm_wrho"], shape_raw["wrho_s"]
    norm_top = norm_wrho != 8 * ln           # `Shape::norm_top_is_full_byte`
    norm_scale = 1 << (8 * ln - norm_wrho)
    sigma_scale = 1 << (8 * ls - wrho_s)
    p_scale = 1 << (8 * lp - (F_P + 1))
    v = []
    if dom == "L":
        v += [_byte("A_LIMB"), _byte("A_LIMBM")]
    elif dom == "D":
        v += [_byte("A_XL0"), _byte("A_XL1")]
        v += _sym("A_Y")
        v += [_byte(f"A_NR{j}") for j in range(ln)]
        if norm_top:
            v += [_scaled(f"A_NR{ln - 1}", norm_scale)]
        v += [_byte(f"A_NS{j}") for j in range(ln)]
        if norm_top:
            v += [_scaled(f"A_NS{ln - 1}", norm_scale)]
        v += [_byte("A_AL0"), _byte("A_AL1"), _byte("A_RAL"),
              _scaled("A_RAL", 2), _byte("A_X1L0"), _byte("A_X1L1")]
        v += _sym("A_YM")
        v += [_byte(f"A_MR{j}") for j in range(ln)]
        if norm_top:
            v += [_scaled(f"A_MR{ln - 1}", norm_scale)]
        v += [_byte(f"A_MS{j}") for j in range(ln)]
        if norm_top:
            v += [_scaled(f"A_MS{ln - 1}", norm_scale)]
        v += [_byte("A_X2L0"), _byte("A_X2L1")]
        v += [_byte("A_ZL0"), _byte("A_ZL1"), _byte("A_RDL"), _scaled("A_RDL", 4)]
    elif dom == "F":
        v += [_byte("A_RGL"), _scaled("A_RGL", 2)]
        v += [_byte("A_UL0"), _byte("A_UL1")]
        v += [_byte("A_HL0"), _byte("A_HL1")]
        v += [_byte("A_RH0"), _byte("A_RH1"), _scaled("A_RH1", 4)]
    elif dom == "Q":
        v += _sym("A_Q8")
        v += [_byte("A_RQL"), _scaled("A_RQL", 2)]
        v += _sym("A_QR8")
        v += [_byte("A_RQRL"), _scaled("A_RQRL", 2)]
        v += _sym("A_O8")
        v += [_byte("A_RO0"), _byte("A_RO1"), _scaled("A_RO1", 128)]
    elif dom == "Kv":
        v += _sym("A_K8")
        v += [_byte("A_RKL"), _scaled("A_RKL", 2)]
        v += _sym("A_V8")
        v += [_byte("A_RVL"), _scaled("A_RVL", 2)]
        v += _sym("A_KR8")
        v += [_byte("A_RKRL"), _scaled("A_RKRL", 2)]
    elif dom == "S":
        v += _sym("A_S8")
        v += [_byte("A_RSL"), _scaled("A_RSL", 4)]
        v += [_byte(f"A_PL{j}") for j in range(lp)]
        v += [_scaled(f"A_PL{lp - 1}", p_scale)]
        v += [_byte(f"A_SR{j}") for j in range(ls)]
        v += [_scaled(f"A_SR{ls - 1}", sigma_scale)]
        v += [_byte(f"A_SG{j}") for j in range(ls)]
        v += [_scaled(f"A_SG{ls - 1}", sigma_scale)]
    return v


def helper_sum(v, lks, h0, alpha, mu):
    """`helper_sum` (argument.rs:642)."""
    def den(l):
        terms, cst = l
        a = cst
        for (i, c) in terms:
            a = add(a, mulb(v[i], c % P))
        return sub(alpha, a)

    acc = ZERO
    for j in range((len(lks) + 1) // 2):
        h = v[h0 + j]
        d1 = den(lks[2 * j])
        if 2 * j + 1 < len(lks):
            d2 = den(lks[2 * j + 1])
            rel = sub(mul(mul(h, d1), d2), add(d1, d2))
        else:
            rel = sub(mul(h, d1), ONE)
        acc = add(acc, mul(mu[j], rel))
    return acc


def limbs(v, ix):
    """`limbs` (argument.rs:613): sum_k v[ix[k]] * 256^k."""
    acc = ZERO
    for j, i in enumerate(ix):
        acc = add(acc, mul(v[i], POW256[j]))
    return acc


class PadTerm:
    """`PadTerm` (argument.rs:677): the batched pad-zero term.  The `zeta`
    powers continue ACROSS the groups of one slot, so a plane is batched at
    one power and one only."""

    def __init__(self):
        self.groups = []
        self.mu = ZERO

    def add(self, supp, tables, zeta):
        if supp is None or not tables:
            return
        p = ONE
        for _ in range(sum(len(g) for _, g in self.groups)):
            p = mul(p, zeta)
        g = []
        for t in tables:
            g.append((t, p))
            p = mul(p, zeta)
        self.groups.append((supp, g))

    def eval(self, v):
        acc = ZERO
        for supp, tables in self.groups:
            anti = sub(ONE, v[supp])
            inner = ZERO
            for t, w in tables:
                inner = add(inner, mul(w, v[t]))
            acc = add(acc, mul(anti, inner))
        return mul(self.mu, acc)


def gate_at(i, v):
    """`Gate::at` (argument.rs:727)."""
    return ONE if i is None else v[i]


# =====================================================================
#  one slot's context: the resolution of a plane NAME to a table index
# =====================================================================
class SlotCtx:
    """Everything a covered slot's closure captured, resolved through the
    PLANE INDEX TABLE rather than through a ported id map.

    `t(name, k)` is the table index of the `k`-th time this slot pushes the
    plane called `name` -- the analogue of `B::tab` (argument.rs:508), which
    the Rust resolves through its own shaped map.  Addressing by name is what
    makes a re-ordered or re-pointed plane list change the ARITHMETIC and not
    just a label: the polynomial then reads a different terminal.
    """

    def __init__(self, gate, arg, plane_names, dc, lam_z, structural=True):
        self.g = gate
        self.arg = arg
        self.slot = arg["slot"]
        self.dc = dc
        self.lam_z = lam_z
        self.structural = structural
        self.alpha, self.beta = gate.alpha, gate.beta
        self.g_u8, self.g_exp, self.g_act = gate.g_u8, gate.g_exp, gate.g_act
        self.main = arg["main"]
        self.cube = 1 << arg["main"]
        self.names = list(plane_names)
        self.eq_idx, self.pub_idx, self.priv_idx = [], [], []
        for i, tab in enumerate(arg["tables"]):
            if tab["kind"] == "eq":
                self.eq_idx.append(i)
            elif tab["kind"] == "public":
                self.pub_idx.append(i)
            else:
                self.priv_idx.append(i)
        if len(self.names) != len(self.priv_idx):
            raise ValueError(
                f"slot {self.slot}: the plane index table lists {len(self.names)} "
                f"planes for {len(self.priv_idx)} private tables"
            )
        self.by_name: dict[str, list[int]] = {}
        for j, nm in enumerate(self.names):
            self.by_name.setdefault(nm, []).append(self.priv_idx[j])
        self.pub_of: dict[tuple, int] = {}
        self.public_values: dict[int, list] = {}
        self.rho_full: list = []

    # -------------------------------------------------------------- lookups
    def expect(self, want: list) -> None:
        """The port's DECLARED push order.  A run with `structural=False`
        drops this check, so that a control can show the identity itself
        failing rather than the label."""
        if self.structural and self.names != want:
            raise ValueError(
                f"slot {self.slot}: the plane index table's push order "
                f"{self.names} is not the ported {want}"
            )

    def t(self, name: str, k: int = 0) -> int:
        try:
            return self.by_name[name][k]
        except (KeyError, IndexError):
            raise ValueError(
                f"slot {self.slot} does not push plane {name!r} {k + 1} time(s): "
                f"the plane index table's push order is {self.names}"
            ) from None

    def p(self, kind: str, dom):
        """The table index of the public table `(kind, dom)`, or None when
        this shape pushes none (a domain that does not pad has no `supp`)."""
        return self.pub_of.get((kind, dom))

    def eq(self, i: int) -> int:
        return self.eq_idx[i]

    def zero_planes(self, dom: str) -> list[int]:
        """`pad::zero_rule_a_planes(sh, ids, dom)` (pad.rs:365) mapped through
        `B::tab`: every `A` plane of the domain, in plane order, except
        `A_E` (the one EXEMPT plane, pad.rs:299)."""
        return [self.t(nm) for nm in self.g.a_plane_names_by_domain[dom]
                if nm != "A_E"]


# =====================================================================
#  the twelve ported polynomials
# =====================================================================
def _ss(v, cx, plane):
    """`SC_SS` / `SC_SSM` (argument.rs:908-926).  Tables: eq(r_t), the `A`
    plane, supp(Dom::D).
    `|v| g.at(v).mul(v[0]).mul(v[1]).mul(v[1])`"""
    cx.expect([plane])
    g = gate_at(cx.p("supp", "D"), v)
    return mul(mul(mul(g, v[cx.eq(0)]), v[cx.t(plane)]), v[cx.t(plane)])


def sc_ss(v, cx):
    return _ss(v, cx, "A_X")


def sc_ssm(v, cx):
    return _ss(v, cx, "A_X1")


def sc_tzc(v, cx):
    """`SC_TZC` (argument.rs:927-1000).  Draws tau(log T), mu(6 + n_pad),
    nu(2), zeta(1).  Push order: eq(tau) eq(r_t) eq(r_t2) A_D A_DSQ, nine
    `A_LIMB` sub-slices, A_DM A_DSQM, nine `A_LIMBM` sub-slices, then
    supp(Dom::T)."""
    n_limbs = 3 * LIMBS_ISQRT
    cx.expect(["A_D", "A_DSQ"] + ["A_LIMB"] * n_limbs
              + ["A_DM", "A_DSQM"] + ["A_LIMBM"] * n_limbs)
    lt = cx.g.log("T")
    mu, nu, zeta = cx.dc[lt:lt + 7], cx.dc[lt + 7:lt + 9], cx.dc[lt + 9]
    gi = cx.p("supp", "T")
    i_tau, i_rt, i_rt2 = cx.eq(0), cx.eq(1), cx.eq(2)
    lim = [cx.t("A_LIMB", j) for j in range(n_limbs)]
    limm = [cx.t("A_LIMBM", j) for j in range(n_limbs)]

    def l3(ix, o):
        return add(add(v[ix[o]], mul(v[ix[o + 1]], POW256[1])),
                   mul(v[ix[o + 2]], POW256[2]))

    d, dsq = v[cx.t("A_D")], v[cx.t("A_DSQ")]
    dl, a1, a2 = l3(lim, 0), l3(lim, 3), l3(lim, 6)
    dm, dsqm = v[cx.t("A_DM")], v[cx.t("A_DSQM")]
    dlm, a1m, a2m = l3(limm, 0), l3(limm, 3), l3(limm, 6)
    zc = add(add(mul(mu[0], sub(dsq, mul(d, d))), mul(mu[1], sub(d, dl))),
             mul(mu[2], sub(sub(double(d), a1), a2)))
    zc = add(add(add(zc, mul(mu[3], sub(dsqm, mul(dm, dm)))),
                 mul(mu[4], sub(dm, dlm))),
             mul(mu[5], sub(sub(double(dm), a1m), a2m)))
    pz = PadTerm()
    if gi is not None:
        pz.mu = mu[6]
        pz.add(gi, cx.zero_planes("T"), zeta)
    g = gate_at(gi, v)
    ceps = k(NORM_CEPS)
    return add(add(mul(v[i_tau], add(zc, pz.eval(v))),
                   mul(mul(mul(nu[0], v[i_rt]), g), sub(add(dsq, a1), ceps))),
               mul(mul(mul(nu[1], v[i_rt2]), g), sub(add(dsqm, a1m), ceps)))


def sc_lzc(v, cx):
    """`SC_LZC` (argument.rs:1002-1030).  Draws tau(log L), mu_pad(1),
    zeta(1).  Push order: eq(tau) A_LIMB A_LIMBM H_L0, then supp(Dom::L).
    `|v| v[0].mul(helper_sum(v, &lks, h0, alpha, &mu).add(pz.eval(v)))`"""
    cx.expect(["A_LIMB", "A_LIMBM", "H_L0"])
    lt = cx.g.log("L")
    mu_pad, zeta = cx.dc[lt], cx.dc[lt + 1]
    gi = cx.p("supp", "L")
    pz = PadTerm()
    if gi is not None:
        pz.mu = mu_pad
        pz.add(gi, cx.zero_planes("L"), zeta)
    lks = cx.g.lk_tables(cx, "L")
    mu = [ONE] * cx.g.n_helpers("L")
    return mul(v[cx.eq(0)],
               add(helper_sum(v, lks, cx.t("H_L0"), cx.alpha, mu), pz.eval(v)))


def sc_rs(v, cx):
    """`SC_RS` (argument.rs:1031-1047).  Draws p_ht(log Ht), lam_z(1).
    Push order: eq(p_ht) public(causal mask) A_E A_ZSEL, then supp(Dom::S).
    `|v| g.at(v).mul(v[0]).mul(v[1].mul(v[2]).add(lam.mul(v[3])))`"""
    cx.expect(["A_E", "A_ZSEL"])
    lam = cx.dc[cx.g.log("Ht")]
    g = gate_at(cx.p("supp", "S"), v)
    mask = v[cx.p("causal", None)]
    return mul(mul(g, v[cx.eq(0)]),
               add(mul(mask, v[cx.t("A_E")]), mul(lam, v[cx.t("A_ZSEL")])))


def _bilinear(v, cx, want):
    """`SC_SCORE` / `SC_PV` (argument.rs:1056-1088): two private factors, the
    first masked in extension round 0 and the second in round 1, and no
    public table at all.  `|v| v[0].mul(v[1])`

    These are the two GROUPED-HEAD (GQA) slots: the key-value factor is read
    at the key-value head of the QUERY head the challenge selects -- the top
    `log2(kv_heads)` bits of `r_h` (correction C-1, trap T-3) -- which is a
    fact about the claim POINT and is in the capture's `coordinates`, not in
    the polynomial.  The polynomial is the plain product either way."""
    cx.expect(want)
    return mul(v[cx.t(want[0])], v[cx.t(want[1])])


def sc_score(v, cx):
    return _bilinear(v, cx, ["A_QR8", "A_KR8"])


def sc_pv(v, cx):
    return _bilinear(v, cx, ["A_P", "A_V8"])


def sc_szc(v, cx):
    """`SC_SZC` (argument.rs:1304-1378).  Draws tau(log S),
    mu(5 + n_help + 1 + n_pad), nu(2), zeta(1).  Push order: eq(tau)
    eq(p_ht) eq(p_s) public(causal), `A_S8 .. A_SG{ls-1}`, the `A_MX` and
    `A_SUM` `Dom::Ht` slices, `H_S0 .. H_S{n-1}`, `H_SEXP`, then supp(Ht)
    and supp(S).

    This is the slot that hosts TWO domains: `Dom::Ht` has no zero-check of
    its own, its two planes are read on the leading coordinates, and its
    indicator is lifted over the trailing `j` axis and carries its own
    pad-zero group (finding S9-F7)."""
    ls, lp = cx.g.counts["ls"], cx.g.counts["lp"]
    n_help = cx.g.n_helpers("S")
    cx.expect(["A_S8", "A_RSL", "A_ZSEL", "A_E", "A_P"]
              + [f"A_PL{j}" for j in range(lp)]
              + [f"A_SR{j}" for j in range(ls)]
              + [f"A_SG{j}" for j in range(ls)]
              + ["A_MX", "A_SUM"]
              + [f"H_S{j}" for j in range(n_help)] + ["H_SEXP"])
    lt = cx.g.log("S")
    n_mu = 5 + n_help + 1 + 1
    mu = cx.dc[lt:lt + n_mu]
    nu = cx.dc[lt + n_mu:lt + n_mu + 2]
    zeta = cx.dc[lt + n_mu + 2]
    im = cx.p("causal", None)
    ght, gs = cx.p("supp", "Ht"), cx.p("supp", "S")
    imx, isum = cx.t("A_MX"), cx.t("A_SUM")
    i_pl = [cx.t(f"A_PL{j}") for j in range(lp)]
    i_sr = [cx.t(f"A_SR{j}") for j in range(ls)]
    i_sg = [cx.t(f"A_SG{j}") for j in range(ls)]
    pz = PadTerm()
    if gs is not None:
        pz.mu = mu[5 + n_help + 1]
        pz.add(ght, [imx, isum], zeta)
        pz.add(gs, cx.zero_planes("S"), zeta)
    lks = cx.g.lk_tables(cx, "S")
    mask, s8 = v[im], v[cx.t("A_S8")]
    zsel, e, pp = v[cx.t("A_ZSEL")], v[cx.t("A_E")], v[cx.t("A_P")]
    sm, sr = v[isum], limbs(v, i_sr)
    # delta = max - the masked score, the masked score being
    # mask * (s8 + 127) - 127
    delta = add(sub(v[imx], mul(mask, add(s8, k(-MASK_SCORE)))), k(-MASK_SCORE))
    c0 = sub(mul(zsel, zsel), zsel)
    c1 = mul(zsel, delta)
    c2 = sub(sub(mul(mul(k(1 << F_P), mask), e), mul(pp, sm)), sr)
    c3 = sub(add(add(limbs(v, i_sg), sr), ONE), sm)
    c4 = sub(pp, limbs(v, i_pl))
    cxx = sub(mul(v[cx.t("H_SEXP")],
                  sub(cx.alpha, add(add(delta, mul(cx.beta, e)), cx.g_exp))), ONE)
    g = gate_at(gs, v)
    zc = add(add(helper_sum(v, lks, cx.t("H_S0"), cx.alpha, mu[5:5 + n_help]),
                 mul(mu[5 + n_help], cxx)), pz.eval(v))
    for m, c in zip(mu, [c0, c1, c2, c3, c4]):
        zc = add(zc, mul(mul(m, g), c))
    host_rs = add(sm, cx.lam_z)
    host_s = sub(add(mul(k(1 << SH_S), s8), v[cx.t("A_RSL")]), k(1 << (SH_S - 1)))
    return add(add(mul(v[cx.eq(0)], zc),
                   mul(mul(mul(nu[0], v[cx.eq(1)]), gate_at(ght, v)), host_rs)),
               mul(mul(mul(nu[1], v[cx.eq(2)]), g), host_s))


def sc_fzc(v, cx):
    """`SC_FZC` (argument.rs:1189-1245).  Draws tau(log F),
    mu(4 + n_help + n_pad), nu(2), zeta(1).  Push order: eq(tau) eq(p_g)
    eq(p_u), `A_G8 .. A_RH1`, `H_F0 .. H_F{n-1}`, `H_FACT`, then
    supp(Dom::F)."""
    n_help = cx.g.n_helpers("F")
    cx.expect(["A_G8", "A_RGL", "A_A16", "A_U16", "A_UL0", "A_UL1",
               "A_H16", "A_HL0", "A_HL1", "A_RH0", "A_RH1"]
              + [f"H_F{j}" for j in range(n_help)] + ["H_FACT"])
    lt = cx.g.log("F")
    n_mu = 4 + n_help + 1
    mu = cx.dc[lt:lt + n_mu]
    nu = cx.dc[lt + n_mu:lt + n_mu + 2]
    zeta = cx.dc[lt + n_mu + 2]
    gi = cx.p("supp", "F")
    pz = PadTerm()
    if gi is not None:
        pz.mu = mu[4 + n_help]
        pz.add(gi, cx.zero_planes("F"), zeta)
    lks = cx.g.lk_tables(cx, "F")

    def l2(a, b):
        return add(v[cx.t(a)], mul(v[cx.t(b)], POW256[1]))

    g8, a16 = v[cx.t("A_G8")], v[cx.t("A_A16")]
    u16, h16 = v[cx.t("A_U16")], v[cx.t("A_H16")]
    f0 = add(sub(sub(mul(a16, u16), mul(k(1 << SH_H_PROD), h16)),
                 l2("A_RH0", "A_RH1")), k(1 << (SH_H_PROD - 1)))
    f1 = sub(add(u16, k(32768)), l2("A_UL0", "A_UL1"))
    f2 = sub(add(h16, k(32768)), l2("A_HL0", "A_HL1"))
    # the activation PAIR lookup's helper relation: the LogUp arm, never gated
    f_act = sub(mul(v[cx.t("H_FACT")],
                    sub(cx.alpha,
                        add(add(add(g8, k(128)), mul(cx.beta, a16)), cx.g_act))), ONE)
    g = gate_at(gi, v)
    zc = add(add(helper_sum(v, lks, cx.t("H_F0"), cx.alpha, mu[4:]),
                 mul(mu[3], f_act)), pz.eval(v))
    for m, c in zip(mu, [f0, f1, f2]):
        zc = add(zc, mul(mul(m, g), c))
    host_g = sub(add(mul(k(1 << SH_G), g8), v[cx.t("A_RGL")]), k(1 << (SH_G - 1)))
    host_u = u16                       # SH_U = 0: no coefficient (T2 A.4)
    return add(add(mul(v[cx.eq(0)], zc),
                   mul(mul(mul(nu[0], v[cx.eq(1)]), g), host_g)),
               mul(mul(mul(nu[1], v[cx.eq(2)]), g), host_u))


def sc_zs(v, cx):
    """`SC_ZS` (argument.rs:1427-1438).  Push order: public(all ones over
    `Dom::Tab`), `H_U`.  `|v| v[0].mul(v[1])`"""
    cx.expect(["H_U"])
    return mul(v[cx.p("ones", "Tab")], v[cx.t("H_U")])


def _io(v, cx, plane, io):
    """`SC_IO_IN` / `SC_IO_OUT` (argument.rs:1440-1447).  Push order:
    eq(tau over `Dom::D`), the block's `A` plane, the endpoint.
    `|v| v[0].mul(v[1].sub(v[2]))`

    **The run's two boundary claim sites.**  At a RUN the endpoint table is
    the EXTERNAL endpoint only in stage 0 (slot 21) and the last stage (slot
    22); in every other stage it is the internal BOUNDARY commitment, at the
    reserved pair the stage's position implies (`Layout::io_mask_row`,
    argument.rs:520-540).  The polynomial is the SAME one either way -- which
    is what the boundary construction is for -- and it is checked in every
    stage, so both claim sites of every boundary are covered: block `k`'s
    slot 22 and block `k+1`'s slot 21."""
    cx.expect([plane, io])
    return mul(v[cx.eq(0)], sub(v[cx.t(plane)], v[cx.t(io)]))


def sc_io_in(v, cx):
    return _io(v, cx, "A_X", "IO_IN")


def sc_io_out(v, cx):
    return _io(v, cx, "A_X2", "IO_OUT")


# --------------------------------------------------------- the slot table
_WEIGHTS = (
    "the slot's public table is `fold_rows_i8` / `fold_cols_i8` of a public "
    "WEIGHT matrix at the round's point (argument.rs:1035, :1104).  A run "
    "bundle carries a public table's length and SHA-256 but not its values "
    "(`public_tables_included: false`), and it carries no weight matrix, so "
    "the table cannot be rebuilt from the bundle.  Nothing HIDDEN is missing: "
    "the weights are public.  Re-capturing with "
    "`HL_RUN_CAPTURE_PUBLIC_TABLES=1`, or carrying the folded table's "
    "preimage, closes this slot"
)

# slot -> the PUBLIC tables the ported closure needs, in push order.  A
# `("supp", dom)` entry is absent from the capture when the domain does not
# pad; the loader below skips it and the closure's `cx.p(...)` is then None,
# which is `Gate(None)` -- exactly `B::supp`'s `Ok(None)` (argument.rs:556).
PUBLIC_SPEC = {
    0: [("supp", "D")],
    1: [("supp", "D")],
    2: [("supp", "T")],
    3: [("supp", "L")],
    4: [("causal", None), ("supp", "S")],
    8: [],
    9: [],
    17: [("causal", None), ("supp", "Ht"), ("supp", "S")],
    18: [("supp", "F")],
    20: [("ones", "Tab")],
    21: [],
    22: [],
}

PORTS = (
    (0, "SC_SS", sc_ss, None),
    (1, "SC_SSM", sc_ssm, None),
    (2, "SC_TZC", sc_tzc, None),
    (3, "SC_LZC", sc_lzc, None),
    (4, "SC_RS", sc_rs, None),
    (5, "SC_QMM", None, _WEIGHTS),
    (6, "SC_KMM", None, _WEIGHTS),
    (7, "SC_VMM", None, _WEIGHTS),
    (8, "SC_SCORE", sc_score, None),
    (9, "SC_PV", sc_pv, None),
    (10, "SC_WO", None, _WEIGHTS),
    (11, "SC_GMM", None, _WEIGHTS),
    (12, "SC_UMM", None, _WEIGHTS),
    (13, "SC_DMM", None, _WEIGHTS),
    (14, "SC_DZC", None,
     "two of the slot's three public tables are the padded norm GAIN vectors "
     "`ctx.public.gamma_a` and `ctx.ff.gamma_m` (argument.rs:1128-1129).  They "
     "are public constants of the statement, but a run bundle carries neither "
     "them nor the tables they build, so the polynomial cannot be evaluated.  "
     "The third table, `supp(Dom::D)`, IS rebuildable and its digest matches "
     "where slots 0 and 1 use it"),
    (15, "SC_QZC", None,
     "two of the slot's three public tables are the RoPE `(cos, sin)` pair "
     "`rope_tables_at(sh, ctx.public, dom)` (argument.rs:1258), a function of "
     "the public statement's RoPE constants, which a bundle does not carry"),
    (16, "SC_KVZC", None,
     "as slot 15, on `Dom::Kv`: the RoPE `(cos, sin)` pair is not in the "
     "bundle"),
    (17, "SC_SZC", sc_szc, None),
    (18, "SC_FZC", sc_fzc, None),
    (19, "SC_TAB", None,
     "two of the slot's four public tables are `table_values_exp_at(..., "
     "ctx.public, beta, g_exp)` and `table_values_act_at(..., ctx.ff, beta, "
     "g_act)` (argument.rs:1391, :1394) -- the exp and activation LOOKUP "
     "table values, functions of the public statement's quantised tables, "
     "which a bundle does not carry.  The other two, `table_values_u8_at` "
     "and `supp(Dom::Tab)`, are rebuildable; two of four are not, so the "
     "slot is not evaluated"),
    (20, "SC_ZS", sc_zs, None),
    (21, "SC_IO_IN", sc_io_in, None),
    (22, "SC_IO_OUT", sc_io_out, None),
)

COVERED = tuple(s for s, _n, fn, _r in PORTS if fn is not None)


# =====================================================================
#  the gate over a whole run
# =====================================================================
class TerminalGate:
    """The port, instantiated at one bundle's shape and plane index."""

    def __init__(self, bundle, index):
        self.bundle = bundle
        self.index = index
        self.shape_raw = bundle.run["shape"]
        self.geom = PadGeometry(self.shape_raw, index.domain_log)
        self.alpha = self.beta = None
        self.g_u8 = self.g_exp = self.g_act = None
        self.public_tables: dict[tuple, str] = {}
        self.public_digest_failures: list[str] = []
        # the plane names of each domain, in PLANE ORDER: the name-space form
        # of `pad::zero_rule_a_planes`' iteration
        self.a_plane_names_by_domain: dict[str, list[str]] = {}
        for p in index.a_planes:
            self.a_plane_names_by_domain.setdefault(p.domain, []).append(p.name)
        self.h_plane_names_by_domain: dict[str, list[str]] = {}
        for p in index.h_planes:
            self.h_plane_names_by_domain.setdefault(p.domain, []).append(p.name)
        # the three byte-limb counts, READ from the table's own plane names
        self.counts = {"ln": self._group("A_NR"), "ls": self._group("A_SR"),
                       "lp": self._group("A_PL")}
        self._lk_cache: dict[str, list] = {}

    def _group(self, prefix: str) -> int:
        pat = re.compile("^" + prefix + r"\d+$")
        return sum(1 for p in self.index.a_planes if pat.match(p.name))

    def set_logup(self, logup_challenges) -> None:
        """`protocol.rs:660-662`: the stage draws (beta, gamma, alpha) and
        makes `g_x = gamma * TAG_x`."""
        beta, gamma, alpha = (f2_from_list(x) for x in logup_challenges)
        self.alpha, self.beta = alpha, beta
        self.g_u8 = mulb(gamma, TAG_U8)
        self.g_exp = mulb(gamma, TAG_EXP)
        self.g_act = mulb(gamma, TAG_ACT)

    def log(self, dom: str) -> int:
        return self.geom.log(dom)

    def n_helpers(self, dom: str) -> int:
        """`Shape::helpers(dom)`, READ from the plane index: the `H` planes of
        the domain, minus the ONE extra pair helper `Dom::S` and `Dom::F`
        carry (`H_SEXP`, `H_FACT` -- shape.rs:486-489)."""
        extra = {"S": "H_SEXP", "F": "H_FACT"}.get(dom)
        return sum(1 for n in self.h_plane_names_by_domain.get(dom, [])
                   if n != extra)

    def lk_tables(self, cx, dom: str):
        """`lk_tables` (argument.rs:634), in this slot's table-index space."""
        lks = self._lk_cache.get(dom)
        if lks is None:
            lks = lookups_at(dom, self.counts, self.shape_raw)
            self._lk_cache[dom] = lks
        return [([(cx.t(nm), c) for (nm, c) in terms], add(k(cst), self.g_u8))
                for (terms, cst) in lks]

    # ---------------------------------- the rebuildable public tables
    def build_public(self, cx) -> None:
        """Rebuild every public table the slot's port declares, compare each
        with the CAPTURE'S OWN SHA-256 of the real one, and place it at its
        table index.  A digest that differs is a refusal: the port would
        otherwise evaluate a polynomial the verifier never evaluated."""
        spec = PUBLIC_SPEC[cx.slot]
        built = []
        for kind, dom in spec:
            if kind == "supp":
                vals = self.geom.supp(dom, cx.cube)
                what = f"supp({dom})"
            elif kind == "causal":
                vals = self.geom.causal_mask()
                what = "causal_mask_at"
            else:
                vals = self.geom.ones_tab()
                what = "the all-ones Dom::Tab vector"
            if vals is None:          # the domain does not pad: no table
                continue
            built.append((kind, dom, what, vals))
        if len(built) != len(cx.pub_idx):
            raise ValueError(
                f"slot {cx.slot}: the port declares {len(built)} public tables, "
                f"the capture has {len(cx.pub_idx)}"
            )
        for (kind, dom, what, vals), i in zip(built, cx.pub_idx):
            tab = cx.arg["tables"][i]
            if tab["len"] != len(vals):
                raise ValueError(
                    f"slot {cx.slot} public table {i} ({what}): the capture has "
                    f"{tab['len']} entries, the rebuilt one {len(vals)}"
                )
            got = table_digest(vals)
            if got != tab["sha256"]:
                self.public_digest_failures.append(
                    f"slot {cx.slot} public table {i} ({what}): the rebuilt digest "
                    f"{got[:12]} is not the capture's {tab['sha256'][:12]}"
                )
                raise ValueError(
                    f"slot {cx.slot} public table {i} ({what}): the rebuilt table "
                    "is not the captured one"
                )
            self.public_tables[(cx.slot, i)] = what
            cx.pub_of[(kind, dom)] = i
            cx.public_values[i] = vals

    # --------------------------------------------------------- the vals list
    def vals(self, cx):
        """The verifier's `vals` (argument.rs:365-378).  `sel` multiplies the
        PUBLIC entries only; a private table contributes its published
        terminal unchanged."""
        arg = cx.arg
        main = arg["main"]
        sel = ONE
        for e in cx.rho_full[main:]:
            sel = mul(sel, sub(ONE, e))
        rho_main = cx.rho_full[:main]
        eq_msb = None
        out, kt = [], 0
        terminals = arg["terminals"]
        for i, tab in enumerate(arg["tables"]):
            if tab["kind"] == "eq":
                point = [f2_from_list(x) for x in tab["point"]]
                start = tab["start"]
                out.append(mul(sel, eq_point(point, rho_main[start:start + len(point)])))
            elif tab["kind"] == "public":
                values = cx.public_values[i]
                if len(values) != 1 << main:
                    raise ValueError("public table length differs from 2^main")
                if eq_msb is None:
                    eq_msb = eq_table_msb(rho_main)
                acc = ZERO
                for x, e in zip(values, eq_msb):
                    if x:
                        acc = add(acc, mulb(e, x % P))
                out.append(mul(sel, acc))
            else:
                out.append(f2_from_list(terminals[kt]))
                kt += 1
        if kt != len(terminals):
            raise ValueError("private table count differs from the terminal count")
        return out


def lam_z_of(stage_doc):
    """`pts.lam_z`, drawn by `SC_RS` (argument.rs:1036) as the challenge
    after `p_ht`, and read by `SC_SZC`."""
    return f2_from_list(stage_doc["arguments"][4]["definition_challenges"][-1])


def check_terminals(bundle, index, replay=None, structural=True,
                    stage_docs=None, slot_planes=None) -> dict:
    """The per-slot terminal identity over every stage of the run.

    `stage_docs` / `slot_planes` override the bundle's own, which is how a
    control perturbs a terminal or a plane list without writing any file.
    `structural=False` drops the port's declared push-order check, so that a
    control can show the ARITHMETIC failing and not merely the label.
    """
    gate = TerminalGate(bundle, index)
    out = {
        "what": "fin_s == c_s * mask_eval_s + poly_s(vals_s), the verifier's own "
        "final check (argument.rs:381), recomputed from the published terminals "
        "and compared with the capture's `terminal_polynomial` (= fin - c*mask_eval)",
        "bundle": bundle.name,
        "source_pins": check_source_pins(bundle),
        "structural_push_order_check": structural,
        "challenges_from": "transcript replay" if replay is not None else "the capture",
        "slots_per_stage": bundle.shape.n_slots,
        "stages": bundle.blocks,
        "covered_slots": list(COVERED),
        "slot_checks_attempted": 0,
        "slot_checks_equal": 0,
        "slot_checks_matching_the_stored_terminal_polynomial": 0,
        "public_tables_rebuilt_and_digest_matched": 0,
        "public_table_digest_failures": [],
        "open_slots": [{"slot": s, "name": n, "reason": r}
                       for s, n, fn, r in PORTS if fn is None],
        "per_stage": [],
        "findings": [],
    }
    if not out["source_pins"]["ok"]:
        out["findings"].append(
            "the bundle's source pins are not the ones this port was read at: "
            + "; ".join(out["source_pins"]["pins_that_moved"]
                        + out["source_pins"]["pins_missing_from_the_bundle"])
        )
        out["ok"] = False
        return out

    docs = stage_docs if stage_docs is not None else [st.doc for st in bundle.stages]
    planes = slot_planes if slot_planes is not None else [
        [p.name for p in row] for row in index.slot_planes
    ]
    for st in bundle.stages:
        doc = docs[st.index]
        gate.set_logup(doc["logup_challenges"])
        lam_z = lam_z_of(doc)
        row = {"stage": st.index, "checked": [], "equal": [], "not_checked": []}
        for s, nm, fn, _reason in PORTS:
            arg = doc["arguments"][s]
            if fn is None:
                row["not_checked"].append({"slot": s, "name": nm, "why": "OPEN"})
                continue
            try:
                dc = [f2_from_list(x) for x in arg["definition_challenges"]]
                cx = SlotCtx(gate, arg, planes[s], dc, lam_z, structural=structural)
                if replay is not None:
                    cx.rho_full = replay.stages[st.index]["rho"][s]
                    c = replay.stages[st.index]["slot_c"][s]
                else:
                    cx.rho_full = [f2_from_list(x) for x in arg["rho"]]
                    c = f2_from_list(arg["c"])
                gate.build_public(cx)
                poly = fn(gate.vals(cx), cx)
            except (ValueError, IndexError, KeyError) as exc:
                row["not_checked"].append({"slot": s, "name": nm, "why": str(exc)})
                out["findings"].append(f"stage {st.index} slot {s} [{nm}]: {exc}")
                continue
            out["slot_checks_attempted"] += 1
            row["checked"].append(s)
            claimed = f2_from_list(arg["scalar"])
            for h in arg["hosted"]:
                claimed = add(claimed,
                              mul(f2_from_list(h["coefficient"]),
                                  f2_from_list(doc["arguments"][h["slot"]]["scalar"])))
            fin, _consistent = sumcheck_final(arg["rounds"], arg["degree"],
                                              cx.rho_full, claimed)
            mask_eval = f2_from_list(arg["mask_eval"])
            if fin is not None and fin == add(mul(c, mask_eval), poly):
                out["slot_checks_equal"] += 1
                row["equal"].append(s)
            else:
                out["findings"].append(
                    f"stage {st.index} slot {s} [{nm}]: "
                    "fin != c*mask_eval + poly(terminals)"
                )
            if poly == f2_from_list(arg["terminal_polynomial"]):
                out["slot_checks_matching_the_stored_terminal_polynomial"] += 1
            else:
                out["findings"].append(
                    f"stage {st.index} slot {s} [{nm}]: the recomputed polynomial is "
                    "not the capture's terminal_polynomial"
                )
        out["per_stage"].append(row)
    out["public_tables_rebuilt_and_digest_matched"] = len(gate.public_tables)
    out["public_table_digest_failures"] = gate.public_digest_failures
    out["rebuilt_public_tables"] = sorted(set(gate.public_tables.values()))
    want = len(COVERED) * bundle.blocks
    out["slot_checks_expected"] = want
    out["slots_open_per_stage"] = bundle.shape.n_slots - len(COVERED)
    out["ok"] = (
        not out["findings"]
        and not gate.public_digest_failures
        and out["slot_checks_attempted"] == want
        and out["slot_checks_equal"] == want
        and out["slot_checks_matching_the_stored_terminal_polynomial"] == want
    )
    return out
