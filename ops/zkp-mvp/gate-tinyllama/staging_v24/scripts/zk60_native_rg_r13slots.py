#!/usr/bin/env python3
"""[v22, gate round 19, 2026-10-29] The R13 ACCURACY-STACK block slots for the
privacy gate's terminal identity (native R13 / token frozen-r16b).

At an R13 accuracy shape (`shape.rs` ACCURACY_PROFILES, stack LOW or LOW +
h24) `argument.rs::define` first calls `argument_accuracy.rs::define_changed`,
which REDEFINES seven slots -- SC_DZC 14, SC_QZC 15, SC_KVZC 16, SC_SZC 17 (and
its DD twin), SC_FZC 18, SC_DD 23 (DD profiles only), SC_TAB 19 -- and leaves the
other sixteen on their legacy bodies (whose matmul weight folds now carry the
R13 multipliers, `accuracy_fold.rs`: a different public TABLE, the same
polynomial).  This module ports the seven bodies, the R13 plane list and its
names (`accuracy_layout.rs::AccuracyIds::new`), the R13 byte lookups with their
exact top-bit pins (`AccuracyIds::lookups`), the precision derivation
(`accuracy_precision.rs::derive`) and the public tables each R13 slot pushes.

READ [token frozen-r16b, list 04d94bc0...; = native R13 bb9eb212... for every
file below]:

    argument_accuracy.rs  a5e02391b615...  (define_changed, dzc, fzc, qzc, szc, szc_dd, dd, tab)
    accuracy_layout.rs    37a3e3456a17...  (AccuracyIds::new, lookups)
    accuracy_precision.rs 145c1e0f....     (derive)
    accuracy_act.rs       7ef5fe26....     (table, group_column, query_values)
    accuracy_public.rs    0b44bf54....     (folds().product.shift = 24 LOW / 16 h24, :488)
    shape.rs              8e00a144....     (ACCURACY_PROFILES :202-215, a_plane_doms :2204-2212,
                                            accuracy_base :672-675, f_p :679-681)
    layout.rs             8519a514....     (SH_ROPE = 7 :67; Ids at R13 :363-367; lookups dispatch;
                                            the R13 calibration line of the layout description)
    argument.rs           bc0332e3....     (define: R13 dispatch first; matmul folds via accuracy_fold)

Line references below are to argument_accuracy.rs at a5e02391.

WHAT IS NOT PORTED: SC_DD and the DD softmax twin (`szc_dd`): no R13 DD profile
is captured (the classifier profiles are non-DD); a DD bundle is refused by
name, never evaluated with a legacy body.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_terminals as T  # noqa: E402
from zk60_native_jv_field import f2_from_list  # noqa: E402

add, sub, mul, mulb, k = T.add, T.sub, T.mul, T.mulb, T.k
ONE, ZERO, P = T.ONE, T.ZERO, T.P
limbs, helper_sum, PadTerm, gate_at = T.limbs, T.helper_sum, T.PadTerm, T.gate_at

SH_ROPE = 7          # layout.rs:67
MASK_SCORE = -127    # layout.rs
TAG_ACT = 134

# shape.rs ACCURACY_PROFILES (:202-215): profile -> (name, stack, registry)
ACCURACY_PROFILES = {
    "hashline-zk-mr1/private-block-tinyllama-1.1b-t128-low-stack-v01/1": ("R13_TINY_T128_LOW", "Low", "standard"),
    "hashline-zk-mr1/private-block-tinyllama-1.1b-t128-low-ddict-v01/1": ("R13_TINY_T128_LOW_DD", "Low", "standard"),
    "hashline-zk-mr1/private-block-llama-3-8b-t128-lh24-v1/1": ("R13_8B_T128_H24", "LowH24", "standard"),
    "hashline-zk-mr1/private-block-llama-3-8b-t128-lh24-dd/1": ("R13_8B_T128_H24_DD", "LowH24", "standard"),
    "hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/1": ("R13_SHIELD_T128_H24", "LowH24", "shieldstral"),
    "hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-ddict1/1": ("R13_SHIELD_T128_H24_DD", "LowH24", "shieldstral"),
    "hashline-zk-mr1/private-block-shieldstral-3b-t256-lowh24-blocks/1": ("R13_SHIELD_T256_H24", "LowH24", "shieldstral"),
    "hashline-zk-mr1/private-block-shieldstral-3b-t256-lowh24-ddict1/1": ("R13_SHIELD_T256_H24_DD", "LowH24", "shieldstral"),
    "hashline-zk-mr1/private-block-rung-lo-t32-dev/1": ("R13_RUNG_LOW", "Low", "standard"),
    "hashline-zk-mr1/private-block-rung-lh-t32-dev/1": ("R13_RUNG_H24", "LowH24", "standard"),
    "hashline-zk-mr1/private-block-rung-ld-t32-dev/1": ("R13_RUNG_LOW_DD", "Low", "standard"),
    "hashline-zk-mr1/private-block-rung-hh-t32-dev/1": ("R13_RUNG_H24_DD", "LowH24", "standard"),
}
R13_SLOTS = (14, 15, 16, 17, 18, 19)          # the redefined slots off DD (SC_DD 23 only at DD)

# legacy plane NAME -> its R13 name (AccuracyIds names, prefix A_), for the
# sixteen legacy-body slots whose ports address the legacy names
R13_NAME_OF_LEGACY = {"A_Q8": "A_Q", "A_K8": "A_K", "A_V8": "A_V", "A_QR8": "A_QR", "A_KR8": "A_KR",
                      "A_O8": "A_O", "A_S8": "A_S", "A_G8": "A_G", "A_A16": "A_A_SCALED",
                      "A_U16": "A_U", "A_H16": "A_H", "A_Z16": "A_Z"}
LEGACY_NAME_OF_R13 = {v: kk for kk, v in R13_NAME_OF_LEGACY.items()}


def stack_of(profile: str):
    s = ACCURACY_PROFILES.get(profile)
    return s[1] if s else None


def is_r13_shape(shape_raw: dict) -> bool:
    return shape_raw.get("profile") in ACCURACY_PROFILES


# =====================================================================
#  the plane list (accuracy_layout.rs AccuracyIds::new) and its count
# =====================================================================
def accuracy_plane_list(stack: str, dd: bool, ls: int) -> list:
    """`AccuracyIds::new` (accuracy_layout.rs:40-93): [(name, domain)] in
    plane order, names prefixed `A_` (the gate's H19-3 plane_index.rs)."""
    if stack not in ("Low", "LowH24") or not (2 <= ls <= 3):
        raise ValueError("R13 planes require an explicit LOW stack and two/three softmax remainder limbs")
    h24 = stack == "LowH24"
    out = []

    def word(dom, name):
        out.append((f"A_{name}", dom))

    def group(dom, name, count):
        for kk in range(count):
            word(dom, name if count == 1 else f"{name}{kk}")
    for name in ("D", "DSQ", "DM", "DSQM"):
        word("T", name)
    word("Ht", "MX")
    word("Ht", "SUM")
    word("L", "LIMB")
    word("L", "LIMBM")
    word("D", "X"); group("D", "XL", 2)
    word("D", "Y"); group("D", "YL", 2)
    group("D", "NR", 3); group("D", "NS", 3)
    word("D", "AO"); group("D", "AL", 2)
    group("D", "RAL", 3)
    word("D", "X1"); group("D", "X1L", 2)
    word("D", "YM"); group("D", "YML", 2)
    group("D", "MR", 3); group("D", "MS", 3)
    word("D", "Z"); group("D", "ZL", 2)
    group("D", "RDL", 3 if h24 else 2)
    word("D", "X2"); group("D", "X2L", 2)
    word("Q", "Q"); group("Q", "QL", 2)
    group("Q", "RQL", 2)
    word("Q", "QR"); group("Q", "QRL", 2)
    group("Q", "RQRL", 1)
    word("Q", "O"); group("Q", "OL", 2)
    group("Q", "RO", 2)
    word("Kv", "K"); group("Kv", "KL", 2)
    group("Kv", "RKL", 2)
    word("Kv", "V"); group("Kv", "VL", 2)
    group("Kv", "RVL", 2)
    word("Kv", "KR"); group("Kv", "KRL", 2)
    group("Kv", "RKRL", 1)
    word("S", "S"); group("S", "RSL", 3)
    word("S", "ZSEL"); word("S", "E"); word("S", "P")

    def division(dom):
        group(dom, "PL", 2); group(dom, "SR", ls); group(dom, "SG", ls)
    if not dd:
        division("S")
    word("F", "G"); group("F", "RGL", 3)
    word("F", "A_SCALED"); word("F", "U"); group("F", "UL", 2)
    group("F", "RU", 2)
    word("F", "H"); group("F", "HL", 3 if h24 else 2)
    group("F", "RH", 2 if h24 else 3)
    if dd:
        word("Dd", "PDICT"); division("Dd"); word("Dd", "MDD")
    word("Tab", "MU8"); word("Tab", "MEXP"); word("Tab", "MACT")
    return out


def a_plane_doms_count(stack: str, dd: bool, ls: int) -> list:
    """`Shape::a_plane_doms` at R13 (shape.rs:2204-2212), counted
    independently of the name table"""
    h24 = stack == "LowH24"
    v = ["T"] * 4 + ["Ht"] * 2 + ["L"] * 2 + ["D"] * (39 if h24 else 38) + ["Q"] * 14 + ["Kv"] * 14
    v += ["S"] * (7 if dd else 9 + 2 * ls) + ["F"] * 16
    if dd:
        v += ["Dd"] * (4 + 2 * ls)
    return v + ["Tab"] * 3


def check_plane_index(index, shape_raw: dict) -> dict:
    """The capture's plane index (written by the gate's H19-3 plane_index.rs)
    against the independent port above: names, domains, the count."""
    stack = stack_of(shape_raw.get("profile"))
    dd = int(shape_raw.get("dd_cap", 0)) > 0
    ls = sum(1 for p in index.a_planes if re.fullmatch(r"A_SR\d+", p.name))
    f = []
    try:
        want = accuracy_plane_list(stack, dd, ls)
    except ValueError as exc:
        return {"ok": False, "findings": [str(exc)]}
    count = a_plane_doms_count(stack, dd, ls)
    if [d for _n, d in want] != count:
        f.append("the ported AccuracyIds domain list is not the independently counted a_plane_doms")
    got = [(p.name, p.domain) for p in index.a_planes]
    if got != want:
        diff = [i for i, (a, b_) in enumerate(zip(got, want)) if a != b_]
        f.append(f"the capture's A plane list differs from the port at {len(diff) or 'its length'} positions "
                 f"(first {diff[:3]}; {len(got)} vs {len(want)} planes)")
    return {"stack": stack, "dd": dd, "sigma_limbs": ls, "a_planes": len(got), "a_planes_ported": len(want),
            "names_and_domains_equal": got == want, "findings": f, "ok": not f}


# =====================================================================
#  the precision (accuracy_precision.rs derive) and the calibration line
# =====================================================================
BASE_KEYS = ("tn", "cn_a", "cn_m", "ceps", "ao", "qkv", "score", "o", "gate", "product", "down")
CAL_LINE = re.compile(r"^calibration: R13 stack=(\w+) registry=(\S+) base=(.*?) norm-window=24 fp=12 "
                      r"gate-common=(\d+) precision=Precision \{ (.*?) \}; ")


def derive_precision(stack: str, b: dict) -> dict:
    """`accuracy_precision.rs::derive` (:55-98) from the base shifts"""
    if not (1 <= b["norm_tn"] <= 16 and 1 <= b["qkv"] <= 8 and 1 <= b["score"] <= 8 and 9 <= b["pv"] <= 16
            and b["ao"] <= 8 and 1 <= b["gate"] <= 8 and b["up"] == 0 and 9 <= b["product"] <= 16
            and 1 <= b["down"] <= 8):
        raise ValueError("precision: base calibration is outside the legacy class")
    h24 = stack == "LowH24"
    p = {"norm_tn": b["norm_tn"] - 8, "q": b["qkv"] + 7, "k": b["qkv"] + 7, "v": b["qkv"] + 8,
         "score": b["score"] + 12, "pv": b["pv"] + 3, "ao": b["ao"] + 14, "gate": b["gate"] + 10,
         "up": b["up"] + 12, "product": b["product"] - (8 if h24 else 0),
         "down": b["down"] + 6 + (8 if h24 else 0), "f_p": 12, "norm_bits": 16, "attention_bits": 16,
         "gate_bits": 12, "product_bits": 16 + (8 if h24 else 0)}
    if p["norm_tn"] <= 0:
        raise ValueError("precision: tn-8 must remain positive")
    if not (all(9 <= p[x] <= 16 for x in ("q", "k", "v", "pv", "up")) and all(17 <= p[x] <= 24 for x in ("score", "ao"))
            and 1 <= p["gate"] <= 24 and ((5 <= p["product"] <= 8) if h24 else (13 <= p["product"] <= 16))
            and ((17 <= p["down"] <= 24) if h24 else (9 <= p["down"] <= 16))):
        raise ValueError("precision: derived shift is outside the declared remainder window")
    return p


def parse_calibration_line(layout_description: list) -> dict:
    """The R13 calibration line of the seed layout's description (layout.rs:
    "calibration: R13 stack={:?} registry={} base={} norm-window=24 fp=12
    gate-common={} precision={:?}; ..."), its base constants, and the printed
    precision CHECKED against `derive_precision` of that base."""
    lines = [s for s in layout_description if s.startswith("calibration: R13 ")]
    if len(lines) != 1:
        raise ValueError(f"the layout description carries {len(lines)} R13 calibration lines, not one")
    m = CAL_LINE.match(lines[0])
    if not m:
        raise ValueError(f"the R13 calibration line does not parse: {lines[0][:160]!r}")
    stack, registry, base_s, gate_common, prec_s = m.groups()
    base = {}
    for tok in base_s.split():
        kk, _, v = tok.partition("=")
        base[kk] = int(v)
    if tuple(base) != BASE_KEYS:
        raise ValueError(f"the R13 base calibration names {tuple(base)}, not {BASE_KEYS}")
    printed = {}
    for tok in prec_s.split(", "):
        kk, _, v = tok.partition(": ")
        printed[kk] = v
    shifts = {"norm_tn": base["tn"], "qkv": base["qkv"], "score": base["score"], "pv": base["o"], "ao": base["ao"],
              "gate": base["gate"], "up": 0, "product": base["product"], "down": base["down"]}
    prec = derive_precision(stack, shifts)
    diff = [kk for kk, v in prec.items() if printed.get(kk) != str(v)]
    if printed.get("stack") != stack:
        diff.append("stack")
    if diff:
        raise ValueError(f"the printed R13 precision differs from its derivation at {diff}")
    return {"stack": stack, "registry": registry, "base": base, "base_shifts": shifts,
            "gate_common": int(gate_common), "precision": prec, "line": lines[0]}


R13_GATE = re.compile(r"; R13 gate denominator (\d+) \(the layer record's accuracy-gate-layer\)$")


def stage_gate_of(line: str):
    """the stage line's R13 gate denominator (token classify.rs `stage_lines`)"""
    m = R13_GATE.search(line)
    return int(m.group(1)) if m else None


def strip_gate(line: str) -> str:
    return R13_GATE.sub("", line)


# =====================================================================
#  the R13 lookups (accuracy_layout.rs AccuracyIds::lookups :110-170)
# =====================================================================
def r13_lookups(dom: str, prec: dict, gate_shift: int, wrho_s: int, counts: dict) -> list:
    """[(terms [(plane name, coeff)], cst)] in the Rust order.  `counts` are
    the limb counts read from the plane names (sigma limbs; h24 or LOW)."""
    ls = counts["ls"]
    h24 = counts["h24"]
    if prec["f_p"] != 12 or prec["product_bits"] != (24 if h24 else 16) or not (9 <= wrho_s <= 24) \
            or (wrho_s + 7) // 8 != ls:
        raise ValueError("R13 lookups: precision or softmax context mismatch")
    v = []
    groups = {"X": ("XL", 2), "Y": ("YL", 2), "Nr": ("NR", 3), "Ns": ("NS", 3), "Ao": ("AL", 2),
              "Rao": ("RAL", 3), "X1": ("X1L", 2), "Ym": ("YML", 2), "Mr": ("MR", 3), "Ms": ("MS", 3),
              "Z": ("ZL", 2), "Rd": ("RDL", 3 if h24 else 2), "X2": ("X2L", 2), "Q": ("QL", 2), "Rq": ("RQL", 2),
              "Qr": ("QRL", 2), "Rqr": ("RQRL", 1), "O": ("OL", 2), "Ro": ("RO", 2), "K": ("KL", 2),
              "Rk": ("RKL", 2), "V": ("VL", 2), "Rv": ("RVL", 2), "Kr": ("KRL", 2), "Rkr": ("RKRL", 1),
              "Rs": ("RSL", 3), "P": ("PL", 2), "Sr": ("SR", ls), "Sg": ("SG", ls), "Rg": ("RGL", 3),
              "Up": ("UL", 2), "Ru": ("RU", 2), "H": ("HL", 3 if h24 else 2), "Rh": ("RH", 2 if h24 else 3)}

    def name(g, kk):
        base, count = groups[g]
        return f"A_{base}" if count == 1 else f"A_{base}{kk}"

    def byts(g, bits=None):
        count = groups[g][1]
        for kk in range(count):
            v.append(([(name(g, kk), 1)], 0))
        if bits is not None:
            if bits == 0 or bits > 8 * count or bits <= 8 * (count - 1):
                raise ValueError(f"R13 lookups: {g} shift does not fit its counted limb window")
            v.append(([(name(g, count - 1), 1 << (8 * count - bits))], 0))
    if dom == "L":
        v += [([("A_LIMB", 1)], 0), ([("A_LIMBM", 1)], 0)]
    elif dom == "D":
        byts("X"); byts("Y"); byts("Nr"); byts("Ns"); byts("Ao"); byts("Rao", prec["ao"]); byts("X1")
        byts("Ym"); byts("Mr"); byts("Ms"); byts("Z"); byts("Rd", prec["down"]); byts("X2")
    elif dom == "Q":
        byts("Q"); byts("Rq", prec["q"]); byts("Qr"); byts("Rqr", SH_ROPE); byts("O"); byts("Ro", prec["pv"])
    elif dom == "Kv":
        byts("K"); byts("Rk", prec["k"]); byts("V"); byts("Rv", prec["v"]); byts("Kr"); byts("Rkr", SH_ROPE)
    elif dom == "F":
        byts("Rg", gate_shift); byts("Up"); byts("Ru", prec["up"]); byts("H"); byts("Rh")
    elif dom in ("S", "Dd"):
        if counts["dd"]:
            raise ValueError("R13 lookups: DD profiles are not ported")
        if dom == "S":
            byts("Rs", prec["score"])
            byts("P", prec["f_p"] + 1); byts("Sr", wrho_s); byts("Sg", wrho_s)
            v.insert(0, ([("A_S", -1)], 127))
            v.insert(0, ([("A_S", 1)], 127))
    return v


def lk_tables_r13(cx, dom: str, prec: dict, gate_shift: int, wrho_s: int, counts: dict):
    """`lk_tables` (argument.rs) at R13, in this slot's table-index space"""
    return [([(cx.t(nm), c) for (nm, c) in terms], add(k(cst), cx.g_u8))
            for (terms, cst) in r13_lookups(dom, prec, gate_shift, wrho_s, counts)]


# =====================================================================
#  the R13 slot context: draws in the R13 order
# =====================================================================
class R13Ctx:
    """the stage's R13 facts a port reads: stack, precision, G, counts"""

    def __init__(self, stack, prec, gate_shift, wrho_s, counts, product_shift):
        self.stack, self.prec, self.gate_shift, self.wrho_s = stack, prec, gate_shift, wrho_s
        self.counts, self.product_shift = counts, product_shift


def draws_mu_first(cx, lt: int, n_mu: int, n_nu: int, *doms):
    """DZC / FZC / QZC / KVZC (argument_accuracy.rs:33-35, :71-73, :110-112):
    mu(n_mu + n_pad), nu(n_nu), zeta(1 if pad_on), THEN tau(lt)."""
    on = cx.pad_on(*doms)
    n_pad = 1 if on else 0
    want = n_mu + n_pad + n_nu + n_pad + lt
    if len(cx.dc) != want:
        raise ValueError(f"slot {cx.slot}: this R13 slot consumes {want} definition draws (mu {n_mu}+{n_pad}, "
                         f"nu {n_nu}, zeta {n_pad}, tau {lt}) and the capture declares {len(cx.dc)}")
    mu = cx.dc[:n_mu + n_pad]
    nu = cx.dc[n_mu + n_pad:n_mu + n_pad + n_nu]
    zeta = cx.dc[n_mu + n_pad + n_nu] if on else None
    return mu, nu, zeta, on


def _names_of(prefix, n):
    return [prefix if n == 1 else f"{prefix}{kk}" for kk in range(n)]


def _lb(v, cx, prefix, n):
    return limbs(v, [cx.t(nm) for nm in _names_of(prefix, n)])


def domain_names(cx, dom):
    return list(cx.g.a_plane_names_by_domain[dom])


def zero_planes(cx, dom):
    """`pad::zero_rule_a_planes` (pad.rs) at R13 names: every A plane of the
    domain except A_E, empty when the domain does not pad"""
    if not cx.g.geom.pads(dom):
        return []
    return [cx.t(nm) for nm in cx.g.a_plane_names_by_domain[dom] if nm != "A_E"]


def r13_dzc(v, cx, rc: R13Ctx):
    """argument_accuracy.rs:29-67"""
    n_help = cx.g.n_helpers("D")
    cx.expect(domain_names(cx, "D") + ["A_D", "A_DM"] + [f"H_D{j}" for j in range(n_help)])
    mu, nu, zeta, pad_on = draws_mu_first(cx, cx.g.log("D"), 13 + n_help, 2, "D")
    p = rc.prec
    ig, igm = cx.c("gamma_a"), cx.c("gamma_m")
    gi = cx.p("supp", "D")
    h24 = rc.counts["h24"]

    def at(nm):
        return v[cx.t(nm)]
    x, y, ao, x1, ym, z, x2 = at("A_X"), at("A_Y"), at("A_AO"), at("A_X1"), at("A_YM"), at("A_Z"), at("A_X2")
    d, dm = at("A_D"), at("A_DM")
    num, num_m = k(2 * rc.base["cn_a"]), k(2 * rc.base["cn_m"])
    dv, den = k(1 << p["norm_tn"]), k(1 << (p["norm_tn"] + 1))
    kd, kdm = mul(den, d), mul(den, dm)
    nr, ns, mr, ms = (_lb(v, cx, "A_NR", 3), _lb(v, cx, "A_NS", 3), _lb(v, cx, "A_MR", 3), _lb(v, cx, "A_MS", 3))
    c32 = k(32768)
    clauses = [
        sub(sub(add(mul(mul(v[ig], x), num), mul(d, dv)), mul(kd, y)), nr),
        sub(add(add(nr, ns), ONE), kd),
        sub(add(x, c32), _lb(v, cx, "A_XL", 2)),
        sub(add(y, c32), _lb(v, cx, "A_YL", 2)),
        sub(add(ao, c32), _lb(v, cx, "A_AL", 2)),
        sub(add(x1, c32), _lb(v, cx, "A_X1L", 2)),
        sub(sub(x1, x), ao),
        sub(sub(add(mul(mul(v[igm], x1), num_m), mul(dm, dv)), mul(kdm, ym)), mr),
        sub(add(add(mr, ms), ONE), kdm),
        sub(add(ym, c32), _lb(v, cx, "A_YML", 2)),
        sub(add(z, c32), _lb(v, cx, "A_ZL", 2)),
        sub(add(x2, c32), _lb(v, cx, "A_X2L", 2)),
        sub(sub(x2, x1), z),
    ]
    batch = ZERO
    for m_, c_ in zip(mu, clauses):
        batch = add(batch, mul(m_, c_))
    pz = PadTerm()
    if pad_on and gi is not None:
        pz.mu = mu[13 + n_help]
        pz.add(gi, zero_planes(cx, "D"), zeta)
    lks = lk_tables_r13(cx, "D", p, rc.gate_shift, rc.wrho_s, rc.counts)
    g = gate_at(gi, v)
    zc = add(add(helper_sum(v, lks, cx.t("H_D0"), cx.alpha, mu[13:13 + n_help]), pz.eval(v)), mul(g, batch))
    host_o = sub(add(mul(k(1 << p["ao"]), ao), _lb(v, cx, "A_RAL", 3)), k(1 << (p["ao"] - 1)))
    host_d = sub(add(mul(k(1 << p["down"]), z), _lb(v, cx, "A_RDL", 3 if h24 else 2)), k(1 << (p["down"] - 1)))
    return add(add(mul(v[cx.eq(0)], zc), mul(mul(mul(nu[0], v[cx.eq(1)]), g), host_o)),
               mul(mul(mul(nu[1], v[cx.eq(2)]), g), host_d))


def r13_fzc(v, cx, rc: R13Ctx):
    """argument_accuracy.rs:69-104"""
    n_help = cx.g.n_helpers("F")
    cx.expect(domain_names(cx, "F") + [f"H_F{j}" for j in range(n_help)] + ["H_FACT"])
    mu, nu, zeta, pad_on = draws_mu_first(cx, cx.g.log("F"), 4 + n_help, 2, "F")
    p = rc.prec
    group = cx.c("group_column")
    gi = cx.p("supp", "F")
    h24 = rc.counts["h24"]

    def at(nm):
        return v[cx.t(nm)]
    g8, a, u, h = at("A_G"), at("A_A_SCALED"), at("A_U"), at("A_H")
    r, gate = rc.product_shift, rc.gate_shift
    f0 = add(sub(sub(mul(a, u), mul(k(1 << r), h)), _lb(v, cx, "A_RH", 2 if h24 else 3)), k(1 << (r - 1)))
    f1 = sub(add(u, k(32768)), _lb(v, cx, "A_UL", 2))
    f2 = sub(add(h, k(1 << (p["product_bits"] - 1))), _lb(v, cx, "A_HL", 3 if h24 else 2))
    beta2 = mul(cx.beta, cx.beta)
    query = add(add(add(add(g8, k(2048)), mul(cx.beta, a)), mul(beta2, v[group])), cx.g_act)
    fa = sub(mul(v[cx.t("H_FACT")], sub(cx.alpha, query)), ONE)
    arith = add(add(mul(mu[0], f0), mul(mu[1], f1)), mul(mu[2], f2))
    pz = PadTerm()
    if pad_on and gi is not None:
        pz.mu = mu[4 + n_help]
        pz.add(gi, zero_planes(cx, "F"), zeta)
    lks = lk_tables_r13(cx, "F", p, rc.gate_shift, rc.wrho_s, rc.counts)
    gf = gate_at(gi, v)
    zc = add(add(add(helper_sum(v, lks, cx.t("H_F0"), cx.alpha, mu[4:4 + n_help]), mul(mu[3], fa)), pz.eval(v)),
             mul(gf, arith))
    host_g = sub(add(mul(k(1 << gate), g8), _lb(v, cx, "A_RGL", 3)), k(1 << (gate - 1)))
    host_u = sub(add(mul(k(1 << p["up"]), u), _lb(v, cx, "A_RU", 2)), k(1 << (p["up"] - 1)))
    return add(add(mul(v[cx.eq(0)], zc), mul(mul(mul(nu[0], v[cx.eq(1)]), gf), host_g)),
               mul(mul(mul(nu[1], v[cx.eq(2)]), gf), host_u))


def _r13_qzc(v, cx, rc: R13Ctx, q: bool):
    """argument_accuracy.rs:106-138"""
    dom = "Q" if q else "Kv"
    n_help = cx.g.n_helpers(dom)
    hp = "H_Q" if q else "H_KV"
    if q:
        source, rotated, rr, lword, lrword, other, lother, rsource, rother = (
            "A_Q", "A_QR", ("A_RQRL", 1), ("A_QL", 2), ("A_QRL", 2), "A_O", ("A_OL", 2), ("A_RQL", 2), ("A_RO", 2))
        s1, s2 = rc.prec["q"], rc.prec["pv"]
    else:
        source, rotated, rr, lword, lrword, other, lother, rsource, rother = (
            "A_K", "A_KR", ("A_RKRL", 1), ("A_KL", 2), ("A_KRL", 2), "A_V", ("A_VL", 2), ("A_RKL", 2), ("A_RVL", 2))
        s1, s2 = rc.prec["k"], rc.prec["v"]
    cx.expect(domain_names(cx, dom) + [source] + [f"{hp}{j}" for j in range(n_help)])
    mu, nu, zeta, pad_on = draws_mu_first(cx, cx.g.log(dom), 4 + n_help, 2, dom)
    ic, isn = cx.c("rope_cos"), cx.c("rope_sin")
    gi = cx.p("supp", dom)
    src, flip = v[cx.t(source, 0)], v[cx.t(source, 1)]
    rot, oth = v[cx.t(rotated)], v[cx.t(other)]
    rope = add(sub(sub(add(mul(v[ic], src), mul(v[isn], flip)), mul(k(1 << SH_ROPE), rot)), _lb(v, cx, *rr)),
               k(1 << (SH_ROPE - 1)))
    c32 = k(32768)
    clauses = [rope, sub(add(src, c32), _lb(v, cx, *lword)), sub(add(rot, c32), _lb(v, cx, *lrword)),
               sub(add(oth, c32), _lb(v, cx, *lother))]
    arith = ZERO
    for m_, c_ in zip(mu, clauses):
        arith = add(arith, mul(m_, c_))
    pz = PadTerm()
    if pad_on and gi is not None:
        pz.mu = mu[4 + n_help]
        pz.add(gi, zero_planes(cx, dom), zeta)
    lks = lk_tables_r13(cx, dom, rc.prec, rc.gate_shift, rc.wrho_s, rc.counts)
    g = gate_at(gi, v)
    zc = add(add(helper_sum(v, lks, cx.t(f"{hp}0"), cx.alpha, mu[4:4 + n_help]), pz.eval(v)), mul(g, arith))
    host1 = sub(add(mul(k(1 << s1), src), _lb(v, cx, *rsource)), k(1 << (s1 - 1)))
    host2 = sub(add(mul(k(1 << s2), oth), _lb(v, cx, *rother)), k(1 << (s2 - 1)))
    return add(add(mul(v[cx.eq(0)], zc), mul(mul(mul(nu[0], v[cx.eq(1)]), g), host1)),
               mul(mul(mul(nu[1], v[cx.eq(2)]), g), host2))


def r13_qzc(v, cx, rc):
    return _r13_qzc(v, cx, rc, True)


def r13_kvzc(v, cx, rc):
    return _r13_qzc(v, cx, rc, False)


def r13_szc(v, cx, rc: R13Ctx):
    """argument_accuracy.rs:204-308 (non-DD)"""
    ls = rc.counts["ls"]
    n_help = cx.g.n_helpers("S")
    cx.expect(["A_S", "A_RSL0", "A_RSL1", "A_RSL2", "A_ZSEL", "A_E", "A_P", "A_PL0", "A_PL1"]
              + [f"A_SR{j}" for j in range(ls)] + [f"A_SG{j}" for j in range(ls)]
              + ["A_MX", "A_SUM"] + [f"H_S{j}" for j in range(n_help)] + ["H_SEXP"])
    lt = cx.g.log("S")
    on = cx.pad_on("Ht", "S")
    n_pad = 1 if on else 0
    want = lt + 5 + n_help + 1 + n_pad + 2 + n_pad
    if len(cx.dc) != want:
        raise ValueError(f"slot 17: this R13 slot consumes {want} definition draws and the capture declares {len(cx.dc)}")
    mu = cx.dc[lt:lt + 5 + n_help + 1 + n_pad]
    nu = cx.dc[lt + 5 + n_help + 1 + n_pad:lt + 5 + n_help + 1 + n_pad + 2]
    zeta = cx.dc[want - 1] if on else None
    p = rc.prec
    im = cx.p("causal", None)
    ght, gs = cx.p("supp", "Ht"), cx.p("supp", "S")
    imx, isum = cx.t("A_MX"), cx.t("A_SUM")
    pz = PadTerm()
    if on and gs is not None:
        pz.mu = mu[5 + n_help + 1]
        pz.add(ght, [imx, isum], zeta)
        pz.add(gs, zero_planes(cx, "S"), zeta)
    lks = lk_tables_r13(cx, "S", p, rc.gate_shift, rc.wrho_s, rc.counts)
    mask, s8 = v[im], v[cx.t("A_S")]
    zsel, e, pp, sm = v[cx.t("A_ZSEL")], v[cx.t("A_E")], v[cx.t("A_P")], v[isum]
    sr = _lb(v, cx, "A_SR", ls)
    delta = add(sub(v[imx], mul(mask, add(s8, k(-MASK_SCORE)))), k(-MASK_SCORE))
    c0 = sub(mul(zsel, zsel), zsel)
    c1 = mul(zsel, delta)
    c2 = sub(sub(mul(mul(mask, e), k(1 << p["f_p"])), mul(pp, sm)), sr)
    c3 = sub(add(add(_lb(v, cx, "A_SG", ls), sr), ONE), sm)
    c4 = sub(pp, _lb(v, cx, "A_PL", 2))
    cxx = sub(mul(v[cx.t("H_SEXP")], sub(cx.alpha, add(add(delta, mul(cx.beta, e)), cx.g_exp))), ONE)
    g = gate_at(gs, v)
    clauses = ZERO
    for m_, c_ in zip(mu, [c0, c1, c2, c3, c4]):
        clauses = add(clauses, mul(m_, c_))
    zc = add(add(add(helper_sum(v, lks, cx.t("H_S0"), cx.alpha, mu[5:5 + n_help]), mul(mu[5 + n_help], cxx)),
                 pz.eval(v)), mul(g, clauses))
    half = 0 if p["score"] == 0 else 1 << (p["score"] - 1)
    host_rs = mul(mul(nu[0], gate_at(ght, v)), add(sm, cx.lam_z))
    host_s = mul(mul(nu[1], g), sub(add(mul(s8, k(1 << p["score"])), _lb(v, cx, "A_RSL", 3)), k(half)))
    return add(add(mul(v[cx.eq(0)], zc), mul(v[cx.eq(1)], host_rs)), mul(v[cx.eq(2)], host_s))


def r13_tab(v, cx, rc: R13Ctx):
    """argument_accuracy.rs:382-412: three LogUp table arms, the third over
    the derived ACT3 table, with its OWN support indicator in the pad term"""
    cx.expect(["A_MU8", "H_GU8", "A_MEXP", "H_GEXP", "A_MACT", "H_GACT"])
    lt = cx.g.log("Tab")
    on = cx.pad_on("Tab")
    n_pad = 1 if on else 0
    want = lt + 3 + n_pad + n_pad
    if len(cx.dc) != want:
        raise ValueError(f"slot 19: this R13 slot consumes {want} definition draws and the capture declares {len(cx.dc)}")
    mu = cx.dc[lt:lt + 3 + n_pad]
    zeta = cx.dc[want - 1] if on else None
    i_u8, i_exp, i_act = cx.p("u8", None), cx.c("exp_values"), cx.c("act3_values")
    triples = [(cx.t("A_MU8"), cx.t("H_GU8"), i_u8), (cx.t("A_MEXP"), cx.t("H_GEXP"), i_exp),
               (cx.t("A_MACT"), cx.t("H_GACT"), i_act)]
    if cx.structural and [tuple(t) for t in triples] != [(1, 2, 3), (4, 5, 6), (7, 8, 9)]:
        raise ValueError(f"slot 19: the (multiplicity, helper, values) indices are {triples}, not the R13 push order")
    rel = [sub(mul(v[ih], sub(cx.alpha, v[iv])), v[im_]) for im_, ih, iv in triples]
    pz = PadTerm()
    si, sa = cx.p("supp", "Tab"), cx.c("act_support") if on else None
    if on:
        if si is None:
            raise ValueError("slot 19: Dom::Tab pads and the slot carries no supp(Tab)")
        pz.mu = mu[3]
        pz.add(si, [1, 4], zeta)
        pz.add(si, [2, 5], zeta)
        pz.add(sa, [7], zeta)
        pz.add(sa, [8], zeta)
    inner = add(add(add(mul(mu[0], rel[0]), mul(mu[1], rel[1])), mul(mu[2], rel[2])), pz.eval(v))
    return mul(v[cx.eq(0)], inner)


R13_PORTS = {14: ("SC_DZC (R13)", r13_dzc), 15: ("SC_QZC (R13)", r13_qzc), 16: ("SC_KVZC (R13)", r13_kvzc),
             17: ("SC_SZC (R13)", r13_szc), 18: ("SC_FZC (R13)", r13_fzc), 19: ("SC_TAB (R13)", r13_tab)}

# the public tables each R13 slot pushes, in push order (the legacy
# PUBLIC_SPEC's format); DZC / QZC / KVZC / SZC push the legacy set
R13_PUBLIC_SPEC = {
    14: [("captured", "gamma_a", "gain"), ("captured", "gamma_m", "gain"), ("supp", "D")],
    15: [("captured", "rope_cos", "rope_cos@Q"), ("captured", "rope_sin", "rope_sin@Q"), ("supp", "Q")],
    16: [("captured", "rope_cos", "rope_cos@Kv"), ("captured", "rope_sin", "rope_sin@Kv"), ("supp", "Kv")],
    17: [("causal", None), ("supp", "Ht"), ("supp", "S")],
    18: [("captured", "group_column", "group_column"), ("supp", "F")],
    19: [("u8", None), ("captured", "exp_values", "lookup_values"), ("captured", "act3_values", "act3_values"),
         ("supp", "Tab"), ("captured", "act_support", "act_support")],
}
R13_PUBLIC_WHAT = {
    "group_column": "the FFN group-id column, gid(j) at (t < T, j < hidden), 0 elsewhere "
                    "(accuracy_act::group_column, accuracy_act.rs:33-41)",
    "act3_values": "the derived ACT3 table i + beta T_g[i] + beta^2 g + g_act on 4096 G rows, the zero row "
                   "2048 + g_act elsewhere (accuracy_act::table, accuracy_act.rs:13-31)",
    "act_support": "the ACT3 table's support indicator, 1 on its 4096 G rows (accuracy_act.rs:13-31)",
}


def check_r13_structure(gate, structure: str, label: str, vals) -> tuple:
    """(findings, detail) for the R13-only captured tables."""
    s = gate.shape_raw
    out, det = [], {}
    if structure == "group_column":
        n = gate.geom.size("F")
        f_pad, t_, hidden = s["f_pad"], s["tokens"], s["hidden"]
        if len(vals) != n:
            return [f"{label}: {len(vals)} entries, not |Dom::F| = {n}"], det
        if any(x[1] != 0 for x in vals):
            out.append(f"{label}: an entry with a nonzero extension coordinate")
        ids = [vals[j][0] for j in range(hidden)]
        if any(i >= 4 for i in ids):
            out.append(f"{label}: a group id outside 0..3 (at most four groups)")
        bad = 0
        for x in range(n):
            t, j = divmod(x, f_pad)
            want = (ids[j] if (t < t_ and j < hidden) else 0)
            if vals[x][0] != want:
                bad += 1
        if bad:
            out.append(f"{label}: {bad} positions are not the token-constant group column (0 at pad positions)")
        det = {"groups_used": sorted(set(ids)), "channels": hidden,
               "per_group_channels": {str(g): ids.count(g) for g in sorted(set(ids))}}
    elif structure == "act_support":
        n = gate.geom.size("Tab")
        if len(vals) != n:
            return [f"{label}: {len(vals)} entries, not |Dom::Tab| = {n}"], det
        ones = sum(1 for x in vals if x == ONE)
        if any(x not in (ONE, ZERO) for x in vals) or any(vals[i] != ONE for i in range(ones)) or ones % 4096 \
                or not (4096 <= ones <= 16384):
            out.append(f"{label}: not a prefix of 4096 G ones (G <= 4)")
        det = {"groups": ones // 4096}
    elif structure == "act3_values":
        n = gate.geom.size("Tab")
        if len(vals) != n:
            return [f"{label}: {len(vals)} entries, not |Dom::Tab| = {n}"], det
        binv = T.f2_inv(gate.beta)
        beta2 = mul(gate.beta, gate.beta)
        zero_row = add(k(2048), gate.g_act)
        entries = None
        words = []
        for g_ in range(4):
            row = []
            for i in range(4096):
                x = g_ * 4096 + i
                if x >= n:
                    break
                w = mul(sub(sub(sub(vals[x], k(i)), mul(beta2, k(g_))), gate.g_act), binv)
                row.append(w)
            if len(row) == 4096 and all(w[1] == 0 and (w[0] < (1 << 40) or w[0] > P - (1 << 40)) for w in row):
                words.append([w[0] if w[0] < P // 2 else w[0] - P for w in row])
            else:
                break
        entries = 4096 * len(words)
        if not words:
            out.append(f"{label}: no 4096-row group recovers small integer words")
        tail = [x for x in range(entries, n) if vals[x] != zero_row]
        if tail:
            out.append(f"{label}: {len(tail)} positions past the 4096 G rows are not the zero row 2048 + g_act")
        zero_ok = [ws[2048] == 0 for ws in words]
        if not all(zero_ok):
            out.append(f"{label}: a group's word at gate 0 (index 2048) is not 0")
        import hashlib
        det = {"groups": len(words), "entries": entries,
               "word_sha256_per_group": [hashlib.sha256(b"".join(int(w).to_bytes(8, "little", signed=True) for w in ws)).hexdigest()
                                         for ws in words],
               "word_min_max": [[min(ws), max(ws)] for ws in words]}
    else:
        out.append(f"{label}: no R13 structure check is declared for it")
    return out, det


def build_public_r13(gate, cx, check_digests=True) -> None:
    """`TerminalGate.build_public` with the R13 spec of this slot (same rules:
    a shape table rebuilt and digest-compared, a statement table taken after
    its length, digest and structure checks)."""
    spec = R13_PUBLIC_SPEC[cx.slot]
    built = []
    for entry in spec:
        kind, dom = entry[0], entry[1]
        label = entry[1] if kind == "captured" else None
        structure = entry[2] if kind == "captured" else None
        if kind == "supp":
            vals = gate.geom.supp(dom, cx.cube)
            what = f"supp({dom})"
        elif kind == "causal":
            vals = gate.geom.causal_mask()
            what = "causal_mask_at"
        elif kind == "u8":
            vals = [add(k(i % T.U8_LEN), gate.g_u8) for i in range(cx.cube)]
            what = "table_values_u8_at"
        else:
            vals = None
            what = R13_PUBLIC_WHAT.get(label) or T.PUBLIC_WHAT[label]
        if kind != "captured" and vals is None:
            continue
        if kind == "captured" and label == "act_support" and not gate.geom.pads("Tab"):
            continue
        built.append((kind, dom, label, structure, what, vals))
    if len(built) != len(cx.pub_idx):
        raise ValueError(f"slot {cx.slot}: the R13 port declares {len(built)} public tables, the capture has {len(cx.pub_idx)}")
    for (kind, dom, label, structure, what, vals), i in zip(built, cx.pub_idx):
        tab = cx.arg["tables"][i]
        if kind == "captured":
            got = tab.get("values")
            if got is None:
                raise ValueError(f"slot {cx.slot} public table {i} ({what}): the capture carries no values for it")
            vals = [f2_from_list(x) for x in got]
            if tab["len"] != len(vals):
                raise ValueError(f"slot {cx.slot} public table {i} ({what}): length mismatch")
            if check_digests and T.table_digest(vals) != tab["sha256"]:
                gate.public_digest_failures.append(f"slot {cx.slot} public table {i} ({what}): digest mismatch")
                raise ValueError(f"slot {cx.slot} public table {i} ({what}): the carried values are not the ones the capture's digest names")
            if structure in ("group_column", "act_support", "act3_values"):
                bad, det = check_r13_structure(gate, structure, label, vals)
                gate.structure_checks += 0 if bad else 1
                gate.structure_detail.setdefault(label, []).append(det)
            else:
                bad = gate.check_structure(structure, label, vals)
            if bad:
                gate.public_structure_failures += bad
                raise ValueError(f"slot {cx.slot} public table {i} ({what}): {bad[0]}")
            gate.captured_tables[(cx.slot, i)] = what
            cx.pub_of[("captured", label)] = i
            cx.public_values[i] = vals
            cx.public_is_base[i] = False
            continue
        if tab["len"] != len(vals):
            raise ValueError(f"slot {cx.slot} public table {i} ({what}): the capture has {tab['len']} entries, the rebuilt one {len(vals)}")
        d = T.table_digest(vals)
        if check_digests and d != tab["sha256"]:
            gate.public_digest_failures.append(f"slot {cx.slot} public table {i} ({what}): the rebuilt digest differs")
            raise ValueError(f"slot {cx.slot} public table {i} ({what}): the rebuilt table is not the captured one")
        gate.public_tables[(cx.slot, i)] = what
        cx.pub_of[(kind, dom)] = i
        cx.public_values[i] = vals
        cx.public_is_base[i] = kind != "u8"
