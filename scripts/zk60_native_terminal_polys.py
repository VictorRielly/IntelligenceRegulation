#!/usr/bin/env python3
"""The 23 + 18 TERMINAL POLYNOMIALS of the two native private profiles, ported
from the Rust closures to Python, so that the joint-view diagnostic can check
the verifier's final equation in its STRONG form.

    python3 scripts/zk60_native_terminal_polys.py \
      --captures results/zk60_native_captures_20260919 \
      --evidence results/zk60_native_terminal_polys

WHAT THIS IS FOR.  A slot's last sumcheck step checks

    fin_s == c_s * mask_eval_s + poly_s(vals_s)

(`let g_val = fin.sub((def.poly)(&vals)).mul(c.inv());`
 `hashline/src/private_block/argument.rs:340`,
 `hashline/src/private_attention/argument.rs:326`).  `poly_s` is a Rust
closure (`Poly = Box<dyn Fn(&[Fp2]) -> Fp2>`) and is NOT in the capture, so
until now `scripts/zk60_native_joint_view.py` could only assert the WEAK form
`mask_eval_s == (fin_s - terminal_polynomial_s) / c_s` with the ALREADY
EVALUATED `terminal_polynomial_s` read from the capture -- an identity blind
to a perturbed terminal (report `ZK60_NATIVE_JOINT_VIEW.md` section 3.1).
This module ports every closure, so the equation above is recomputed from the
published terminals and compared with the receipt's own final claim.

HOW `vals` IS BUILT, exactly as the verifier builds it (same two sources):

    sel          = prod over the extension challenges e of (1 - e)
    eq table     sel * eq_point(point, rho_main[start .. start + |point|])
    public table sel * eval_mle_ext(values, rho_main)
    private tab  the published terminal, in table order

`point`, `start` and the public tables' full `2^main` values are in the
capture; `rho` is re-derived by the stage-1 transcript replay; the challenges
the closure itself captured are the slot's `definition_challenges`, consumed
here in the Rust draw order; `alpha`, `beta` and the three table tags come
from `logup_challenges` = (beta, gamma, alpha) and
`g_x = gamma * TAG_x` (`protocol.rs:330-335`, `tables_attn.rs`).

WHAT THIS DOES NOT ESTABLISH.  This is a consistency check of the verifier's
view at the receipts' real challenges.  It is NOT a privacy property, and the
caller-fixed endpoint-root obligation (decisions D8 / D11) is untouched.

REVIEWED OBLIGATION.  The equality of each Python function below with its Rust
closure is established by READING, not by machine.  The source pins make a
change to the Rust loud (the port refuses to run); they do not make the port
correct.
"""

from __future__ import annotations

import argparse
import collections
import hashlib
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)
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
    f2_inv,
    f2_is_zero,
    f2_mul,
    f2_mul_base,
    f2_sub,
)

# short aliases, so that a ported line stays readable next to its Rust original
add, sub, mul, mulb = f2_add, f2_sub, f2_mul, f2_mul_base
ONE, ZERO = F2_ONE, F2_ZERO


def k(v: int):
    """`Fp2::from_i64` (zkp-core/src/field.rs:148): a signed integer constant."""
    return (v % P, 0)


def double(a):
    """`Fp2::double` (field.rs:174)."""
    return add(a, a)


# 256^j as a field constant: `pow256` (private_block/layout.rs:690)
POW256 = [k(1 << (8 * j)) for j in range(4)]


# ------------------------------------------------------------- source pins
class SourcePinError(RuntimeError):
    """A pinned Rust source changed: the port may have drifted from it."""


Pin = collections.namedtuple("Pin", "path sha256 blob")

# sha256 of the file as ported, and its git blob id, at commit 5ca721f.
# `argument.rs` carries the closures themselves; `layout.rs` the plane
# indices, lookup lists, shifts and slot order the closures read; `protocol.rs`
# the (beta, gamma, alpha) derivation and the three table tags; `mle.rs`
# `eq_point` / `eval_mle_ext`; `native_capture.rs` the meaning of every
# captured field this port consumes.
SOURCE_PINS = (
    Pin(
        "hashline/src/private_block/argument.rs",
        "e62f46c29fe41848737e157b65c16d11d2c2c9501722b88660420a7a21a642ab",
        "e492afdb18bf205d246abafd89f8ae82a9eec3b2",
    ),
    Pin(
        "hashline/src/private_block/layout.rs",
        "6cc8f6fed8bc55ccb7cde23270976ed23912f768a6a60f3d392da08f2fcf0989",
        "4d72869b1bc98b4149bd2084b88c8e7e7f74a169",
    ),
    Pin(
        "hashline/src/private_block/protocol.rs",
        "d9455a1054aab7e18e1cba0194416a83847e862db26d8b4f5b9cf982ba082d65",
        "39f6edc0e00eed931f708b4f438045e8257b2343",
    ),
    Pin(
        "hashline/src/private_attention/argument.rs",
        "3343620eefa848421633971210305a356c183848ac15f566a503244ef2283a25",
        "338689f1770081f50cf7338959bc7e8990624960",
    ),
    Pin(
        "hashline/src/private_attention/layout.rs",
        "17159dcc677d47a9d81528d9e14bf7a28a2ef3854aa4db921719f9bd0ffc7bb1",
        "4318665378866d00e13303b1539242c29923fee8",
    ),
    Pin(
        "hashline/src/private_attention/protocol.rs",
        "cf29722099739cb737e0596c5e6cd07bdb893bef51cb9eaa639d2223bdc4dc81",
        "aa454897c09a0fb1564847faab0780b98772c43e",
    ),
    Pin(
        "hashline/src/native_capture.rs",
        "621f6459ccf516ebbc1434629f0061f997df8f3b8369d0c7f923201e9cb0e6e8",
        "25a60ee36ce8a5dde9ed614b16374f06516d606e",
    ),
    Pin(
        "zkp-core/src/mle.rs",
        "131cf1b49a2f280147ccb1d8f374c139cd7033a8a4ddb02c473b751937409614",
        "649a63d3bada92e3ca0c8c327f4591165fa3716f",
    ),
)


def _blob_id(raw: bytes) -> str:
    return hashlib.sha1(b"blob %d\0" % len(raw) + raw).hexdigest()


def check_source_pins(root: str = REPO_ROOT, pins=SOURCE_PINS) -> dict:
    """HARD ERROR if a pinned Rust source is missing or changed.

    The port is a transcription of code that lives elsewhere; silent drift is
    the failure mode that would matter, so every entry point calls this first.
    """
    out = {}
    for pin in pins:
        path = os.path.join(root, pin.path)
        if not os.path.exists(path):
            raise SourcePinError(
                f"source pin: {pin.path} is missing under {root}. The port of the "
                "terminal polynomials is pinned to that file; re-read the Rust "
                "closures before re-pinning."
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
                "The Python port of the terminal polynomials was written against the "
                "pinned bytes. Re-read the changed closures line by line, update the "
                "ported functions and only then re-pin. Do NOT re-pin to make this pass."
            )
        out[pin.path] = {"sha256": got, "git_blob": blob}
    return out


# ------------------------------------------------- layout constants (ported)
class _Layout:
    """A frozen namespace of one `layout.rs`: plane indices, shifts, sizes."""

    def __init__(self, **kw):
        self.__dict__.update(kw)


# hashline/src/private_block/layout.rs:40-200, 223-240
PB = _Layout(
    T=32, D=16, H=2, DH=8, HALF=4, KV=8, F=16, LOG_N=8, N=256,
    NORM_TN=11, NORM_CN=1024, NORM_CEPS=1, NORM_WRHO=29,
    SH_QKV=7, SH_ROPE=7, SH_S=6, SH_O=9, SH_AO=7,
    F_E=9, F_P=9, F_RO=7, WRHO_S=14, MASK_SCORE=-127,
    SH_G=7, SH_H_PROD=14, SH_Z=6,
    A_D=0, A_DSQ=1, A_DM=2, A_DSQM=3, A_MX=4, A_SUM=5, A_LIMB=6, A_LIMBM=7,
    A_X=8, A_XL0=9, A_XL1=10, A_Y=11, A_NR0=12, A_NS0=16, A_AO=20,
    A_AL0=21, A_AL1=22, A_RAL=23, A_X1=24, A_X1L0=25, A_X1L1=26, A_YM=27,
    A_MR0=28, A_MS0=32, A_Z16=36, A_X2=37, A_X2L0=38, A_X2L1=39,
    A_ZL0=40, A_ZL1=41, A_RDL=42,
    A_Q8=43, A_RQL=44, A_QR8=45, A_RQRL=46, A_O8=47, A_RO0=48, A_RO1=49,
    A_K8=50, A_RKL=51, A_V8=52, A_RVL=53, A_KR8=54, A_RKRL=55,
    A_S8=56, A_RSL=57, A_ZSEL=58, A_E=59, A_P=60, A_PL0=61, A_PL1=62,
    A_SR0=63, A_SR1=64, A_SG0=65, A_SG1=66,
    A_G8=67, A_RGL=68, A_A16=69, A_U16=70, A_UL0=71, A_UL1=72, A_H16=73,
    A_HL0=74, A_HL1=75, A_RH0=76, A_RH1=77,
    A_MU8=78, A_MEXP=79, A_MACT=80, N_A=81, N_LIMBS=9,
    H_L=0, H_D0=1, H_Q0=20, H_KV0=27, H_S0=33, H_SEXP=40, H_F0=41,
    H_FACT=46, H_GU8=47, H_GEXP=48, H_GACT=49, H_U=50,
)

# hashline/src/private_attention/layout.rs:29-170
PA = _Layout(
    T=32, D=16, H=2, DH=8, HALF=4, KV=8, LOG_N=8, N=256,
    NORM_TN=11, NORM_CN=1024, NORM_CEPS=1, NORM_WRHO=29,
    SH_QKV=7, SH_ROPE=7, SH_S=6, SH_O=9, SH_AO=7,
    F_E=9, F_P=9, F_RO=7, WRHO_S=14, MASK_SCORE=-127,
    A_D=0, A_DSQ=1, A_MX=2, A_SUM=3, A_LIMB=4,
    A_X=5, A_XL0=6, A_XL1=7, A_Y=8, A_NR0=9, A_NS0=13, A_AO=17,
    A_AL0=18, A_AL1=19, A_RAL=20, A_X1=21, A_X1L0=22, A_X1L1=23,
    A_Q8=24, A_RQL=25, A_QR8=26, A_RQRL=27, A_O8=28, A_RO0=29, A_RO1=30,
    A_K8=31, A_RKL=32, A_V8=33, A_RVL=34, A_KR8=35, A_RKRL=36,
    A_S8=37, A_RSL=38, A_ZSEL=39, A_E=40, A_P=41, A_PL0=42, A_PL1=43,
    A_SR0=44, A_SR1=45, A_SG0=46, A_SG1=47,
    A_MU8=48, A_MEXP=49, N_A=50, N_LIMBS=9,
    H_L=0, H_D0=1, H_Q0=11, H_KV0=18, H_S0=24, H_SEXP=31,
    H_GU8=32, H_GEXP=33, H_U=34,
)


# ------------------------------------------------------- lookups (layout.rs)
def _byte(p):
    """`byte` (layout.rs:266)."""
    return ([(p, 1)], 0)


def _scaled(p, c):
    """`scaled` (layout.rs:270)."""
    return ([(p, c)], 0)


def _sym(p):
    """`sym`, the int8 subset [-127, 127] (layout.rs:274)."""
    return [([(p, 1)], 127), ([(p, -1)], 127)]


def pb_lookups(dom: str):
    """`lookups` of the block layout (private_block/layout.rs:310-368)."""
    L, v = PB, []
    if dom == "L":
        v += [_byte(L.A_LIMB), _byte(L.A_LIMBM)]
    elif dom == "D":
        v += [_byte(L.A_XL0), _byte(L.A_XL1)]
        v += _sym(L.A_Y)
        v += [_byte(L.A_NR0 + j) for j in range(4)]
        v += [_scaled(L.A_NR0 + 3, 1 << (32 - L.NORM_WRHO))]
        v += [_byte(L.A_NS0 + j) for j in range(4)]
        v += [_scaled(L.A_NS0 + 3, 1 << (32 - L.NORM_WRHO))]
        v += [_byte(L.A_AL0), _byte(L.A_AL1), _byte(L.A_RAL), _scaled(L.A_RAL, 2),
              _byte(L.A_X1L0), _byte(L.A_X1L1)]
        v += _sym(L.A_YM)
        v += [_byte(L.A_MR0 + j) for j in range(4)]
        v += [_scaled(L.A_MR0 + 3, 1 << (32 - L.NORM_WRHO))]
        v += [_byte(L.A_MS0 + j) for j in range(4)]
        v += [_scaled(L.A_MS0 + 3, 1 << (32 - L.NORM_WRHO))]
        v += [_byte(L.A_X2L0), _byte(L.A_X2L1)]
        v += [_byte(L.A_ZL0), _byte(L.A_ZL1), _byte(L.A_RDL), _scaled(L.A_RDL, 4)]
    elif dom == "F":
        v += [_byte(L.A_RGL), _scaled(L.A_RGL, 2)]
        v += [_byte(L.A_UL0), _byte(L.A_UL1)]
        v += [_byte(L.A_HL0), _byte(L.A_HL1)]
        v += [_byte(L.A_RH0), _byte(L.A_RH1), _scaled(L.A_RH1, 4)]
    elif dom == "Q":
        v += _sym(L.A_Q8)
        v += [_byte(L.A_RQL), _scaled(L.A_RQL, 2)]
        v += _sym(L.A_QR8)
        v += [_byte(L.A_RQRL), _scaled(L.A_RQRL, 2)]
        v += _sym(L.A_O8)
        v += [_byte(L.A_RO0), _byte(L.A_RO1), _scaled(L.A_RO1, 128)]
    elif dom == "Kv":
        v += _sym(L.A_K8)
        v += [_byte(L.A_RKL), _scaled(L.A_RKL, 2)]
        v += _sym(L.A_V8)
        v += [_byte(L.A_RVL), _scaled(L.A_RVL, 2)]
        v += _sym(L.A_KR8)
        v += [_byte(L.A_RKRL), _scaled(L.A_RKRL, 2)]
    elif dom == "S":
        v += _sym(L.A_S8)
        v += [_byte(L.A_RSL), _scaled(L.A_RSL, 4)]
        v += [_byte(L.A_PL0), _byte(L.A_PL1), _scaled(L.A_PL1, 64)]
        v += [_byte(L.A_SR0), _byte(L.A_SR1), _scaled(L.A_SR1, 4)]
        v += [_byte(L.A_SG0), _byte(L.A_SG1), _scaled(L.A_SG1, 4)]
    else:
        raise KeyError(dom)
    return v


def pa_lookups(dom: str):
    """`lookups` of the attention layout (private_attention/layout.rs:228-267)."""
    L, v = PA, []
    if dom == "L":
        v += [_byte(L.A_LIMB)]
    elif dom == "D":
        v += [_byte(L.A_XL0), _byte(L.A_XL1)]
        v += _sym(L.A_Y)
        v += [_byte(L.A_NR0 + j) for j in range(4)]
        v += [_scaled(L.A_NR0 + 3, 1 << (32 - L.NORM_WRHO))]
        v += [_byte(L.A_NS0 + j) for j in range(4)]
        v += [_scaled(L.A_NS0 + 3, 1 << (32 - L.NORM_WRHO))]
        v += [_byte(L.A_AL0), _byte(L.A_AL1), _byte(L.A_RAL), _scaled(L.A_RAL, 2),
              _byte(L.A_X1L0), _byte(L.A_X1L1)]
    elif dom == "Q":
        v += _sym(L.A_Q8)
        v += [_byte(L.A_RQL), _scaled(L.A_RQL, 2)]
        v += _sym(L.A_QR8)
        v += [_byte(L.A_RQRL), _scaled(L.A_RQRL, 2)]
        v += _sym(L.A_O8)
        v += [_byte(L.A_RO0), _byte(L.A_RO1), _scaled(L.A_RO1, 128)]
    elif dom == "Kv":
        v += _sym(L.A_K8)
        v += [_byte(L.A_RKL), _scaled(L.A_RKL, 2)]
        v += _sym(L.A_V8)
        v += [_byte(L.A_RVL), _scaled(L.A_RVL, 2)]
        v += _sym(L.A_KR8)
        v += [_byte(L.A_RKRL), _scaled(L.A_RKRL, 2)]
    elif dom == "S":
        v += _sym(L.A_S8)
        v += [_byte(L.A_RSL), _scaled(L.A_RSL, 4)]
        v += [_byte(L.A_PL0), _byte(L.A_PL1), _scaled(L.A_PL1, 64)]
        v += [_byte(L.A_SR0), _byte(L.A_SR1), _scaled(L.A_SR1, 4)]
        v += [_byte(L.A_SG0), _byte(L.A_SG1), _scaled(L.A_SG1, 4)]
    else:
        raise KeyError(dom)
    return v


# (first helper plane, helper count) -- `helpers` (layout.rs:371 / :270)
PB_HELPERS = {"L": (PB.H_L, 1), "D": (PB.H_D0, 19), "F": (PB.H_F0, 5),
              "Q": (PB.H_Q0, 7), "Kv": (PB.H_KV0, 6), "S": (PB.H_S0, 7)}
PA_HELPERS = {"L": (PA.H_L, 1), "D": (PA.H_D0, 10), "Q": (PA.H_Q0, 7),
              "Kv": (PA.H_KV0, 6), "S": (PA.H_S0, 7)}


def a_range(first: int, last: int, base: int) -> dict:
    """`B::a_range` in table-index space: plane -> its table index.

    The builder pushes the planes `first ..= last` in order starting at table
    index `base` (argument.rs:433 / :419).
    """
    return {p: base + (p - first) for p in range(first, last + 1)}


def lk_tables(lks, idx, g_u8):
    """`lk_tables` (argument.rs:466 / :452): a lookup in TABLE-index space,
    value = cst + sum coef * v[table index], the U8 tag folded into cst."""
    return [([(idx[p], c % P) for (p, c) in terms], add(k(cst), g_u8))
            for terms, cst in lks]


def helper_sum(v, lks, h0, alpha, mu):
    """`helper_sum` (argument.rs:474 / :460): sum_k mu_k * (LogUp relation k),
    helper k covering lookups (2k, 2k+1); an odd count leaves the last single."""
    def den(l):
        terms, cst = l
        a = cst
        for (i, c) in terms:
            a = add(a, mulb(v[i], c))
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


# ============================================================================
# the twenty-three terminal polynomials of the PRIVATE BLOCK profile
# hashline/src/private_block/argument.rs::define, in slot order
# ============================================================================
def pb00_ss(v, cx):
    """SC_SS. argument.rs:544-549 (tables: eq(r_t), A_X).
    `|v: &[Fp2]| v[0].mul(v[1]).mul(v[1])`"""
    return mul(mul(v[0], v[1]), v[1])


def pb01_ssm(v, cx):
    """SC_SSM, norm_m's row sums. argument.rs:552-557.
    `|v: &[Fp2]| v[0].mul(v[1]).mul(v[1])`"""
    return mul(mul(v[0], v[1]), v[1])


def pb02_tzc(v, cx):
    """SC_TZC, the norm squares zero-check hosting 01 and 01m.
    argument.rs:558-595, closure 583-593.  Draws: tau(5), mu(6), nu(2)."""
    mu, nu = cx.dc[5:11], cx.dc[11:13]
    p1, p2 = POW256[1], POW256[2]
    # push order: eq(tau) eq(r_t) eq(r_t2) A_D A_DSQ 9 limbs A_DM A_DSQM 9 limbs
    i_tau, i_rt, i_rt2, i_d, i_dsq = 0, 1, 2, 3, 4
    i_limb = i_dsq + 1
    i_dm = i_limb + PB.N_LIMBS
    i_dsqm = i_dm + 1
    i_limbm = i_dsqm + 1

    def l3(o):
        return add(add(v[o], mul(v[o + 1], p1)), mul(v[o + 2], p2))

    d, dsq, dl, a1, a2 = v[i_d], v[i_dsq], l3(i_limb), l3(i_limb + 3), l3(i_limb + 6)
    dm, dsqm, dlm, a1m, a2m = (v[i_dm], v[i_dsqm], l3(i_limbm),
                               l3(i_limbm + 3), l3(i_limbm + 6))
    zc = add(add(mul(mu[0], sub(dsq, mul(d, d))), mul(mu[1], sub(d, dl))),
             mul(mu[2], sub(sub(double(d), a1), a2)))
    zc = add(add(add(zc, mul(mu[3], sub(dsqm, mul(dm, dm)))),
                 mul(mu[4], sub(dm, dlm))),
             mul(mu[5], sub(sub(double(dm), a1m), a2m)))
    ceps = k(PB.NORM_CEPS)
    return add(add(mul(v[i_tau], zc),
                   mul(mul(nu[0], v[i_rt]), sub(add(dsq, a1), ceps))),
               mul(mul(nu[1], v[i_rt2]), sub(add(dsqm, a1m), ceps)))


def pb03_lzc(v, cx):
    """SC_LZC, the limb zero-check.  argument.rs:598-605.  Draws: tau(9).
    `|v| v[0].mul(helper_sum(v, &lks, h0, alpha, &[Fp2::ONE]))`"""
    idx = a_range(PB.A_LIMB, PB.A_LIMBM, 1)
    h0 = 3
    lks = lk_tables(pb_lookups("L"), idx, cx.g_u8)
    return mul(v[0], helper_sum(v, lks, h0, cx.alpha, [ONE]))


def pb04_rs(v, cx):
    """SC_RS, masked row sums + selector.  argument.rs:606-615.
    Draws: p_ht(6), lam_z(1).
    `|v| v[0].mul(v[1].mul(v[2]).add(lam.mul(v[3])))`"""
    lam = cx.dc[6]
    return mul(v[0], add(mul(v[1], v[2]), mul(lam, v[3])))


def _mm(v, cx):
    """The four attention matmul slots and the three feed-forward ones:
    one private plane times one public folded weight table.
    argument.rs:639 and :697 -- `|v| v[0].mul(v[1])`"""
    return mul(v[0], v[1])


def pb05_qmm(v, cx):
    """SC_QMM.  argument.rs:616-640."""
    return _mm(v, cx)


def pb06_kmm(v, cx):
    """SC_KMM.  argument.rs:616-640."""
    return _mm(v, cx)


def pb07_vmm(v, cx):
    """SC_VMM.  argument.rs:616-640."""
    return _mm(v, cx)


def pb08_score(v, cx):
    """SC_SCORE, the bilinear score matmul.  argument.rs:641-654.
    `|v| v[0].mul(v[1])` over two private factors (two extension rounds)."""
    return mul(v[0], v[1])


def pb09_pv(v, cx):
    """SC_PV, the bilinear PV matmul.  argument.rs:655-667."""
    return mul(v[0], v[1])


def pb10_wo(v, cx):
    """SC_WO.  argument.rs:616-640."""
    return _mm(v, cx)


def pb11_gmm(v, cx):
    """SC_GMM, the gate matmul.  argument.rs:674-698."""
    return _mm(v, cx)


def pb12_umm(v, cx):
    """SC_UMM, the up matmul.  argument.rs:674-698."""
    return _mm(v, cx)


def pb13_dmm(v, cx):
    """SC_DMM, the down matmul.  argument.rs:674-698."""
    return _mm(v, cx)


def pb14_dzc(v, cx):
    """SC_DZC, the d-cube zero-check hosting 12 and 13D.
    argument.rs:699-748, closure 718-746.
    Draws: tau(9), mu(11 + 19 helpers), nu(2)."""
    L = PB
    n_help = PB_HELPERS["D"][1]
    mu = cx.dc[9:9 + 11 + n_help]
    nu = cx.dc[9 + 11 + n_help:9 + 13 + n_help]
    p1, p2, p3 = POW256[1], POW256[2], POW256[3]
    # push order: eq(tau) eq(p_a) eq(p_z) pub(gamma_a) pub(gamma_m)
    #             planes A_X..=A_RDL, A_D slice, A_DM slice, 19 helpers
    ig, igm = 3, 4
    idx = a_range(L.A_X, L.A_RDL, 5)
    id_ = 5 + (L.A_RDL - L.A_X + 1)
    idm = id_ + 1
    h0 = idm + 1
    lks = lk_tables(pb_lookups("D"), idx, cx.g_u8)
    k_num, k_dv, k_den = k(2 * L.NORM_CN), k(1 << L.NORM_TN), k(1 << (L.NORM_TN + 1))

    def at(p):
        return v[idx[p]]

    def l4(o):
        return add(add(add(at(o), mul(at(o + 1), p1)), mul(at(o + 2), p2)),
                   mul(at(o + 3), p3))

    def l2(o):
        return add(at(o), mul(at(o + 1), p1))

    x, y, ao, x1, d = at(L.A_X), at(L.A_Y), at(L.A_AO), at(L.A_X1), v[id_]
    nm, x2, z16, dm = at(L.A_YM), at(L.A_X2), at(L.A_Z16), v[idm]
    nr, ns = l4(L.A_NR0), l4(L.A_NS0)
    mr, ms = l4(L.A_MR0), l4(L.A_MS0)
    c0 = sub(sub(add(mul(mul(k_num, v[ig]), x), mul(k_dv, d)),
                 mul(mul(k_den, y), d)), nr)
    c1 = sub(add(add(ns, nr), ONE), mul(k_den, d))
    c2 = sub(add(x, k(32768)), l2(L.A_XL0))
    c3 = sub(add(ao, k(32768)), l2(L.A_AL0))
    c4 = sub(add(x1, k(32768)), l2(L.A_X1L0))
    c5 = sub(sub(x1, x), ao)
    c6 = sub(sub(add(mul(mul(k_num, v[igm]), x1), mul(k_dv, dm)),
                 mul(mul(k_den, nm), dm)), mr)
    c7 = sub(add(add(ms, mr), ONE), mul(k_den, dm))
    c8 = sub(add(x2, k(32768)), l2(L.A_X2L0))
    c9 = sub(sub(x2, x1), z16)
    c10 = sub(add(z16, k(32768)), l2(L.A_ZL0))
    zc = helper_sum(v, lks, h0, cx.alpha, mu[11:])
    for m, c in zip(mu, [c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10]):
        zc = add(zc, mul(m, c))
    host_wo = sub(add(mul(k(1 << L.SH_AO), ao), at(L.A_RAL)), k(1 << (L.SH_AO - 1)))
    host_dmm = sub(add(mul(k(1 << L.SH_Z), z16), at(L.A_RDL)), k(1 << (L.SH_Z - 1)))
    return add(add(mul(v[0], zc), mul(mul(nu[0], v[1]), host_wo)),
               mul(mul(nu[1], v[2]), host_dmm))


def _pb_qkv_zc(v, cx, q: bool):
    """SC_QZC / SC_KVZC, one arm in the source.
    argument.rs:789-830, closure 814-828.
    Draws: tau(dom.log), mu(1 + helpers), nu(2)."""
    L = PB
    dom = "Q" if q else "Kv"
    log = 9 if q else 8
    n_help = PB_HELPERS[dom][1]
    mu = cx.dc[log:log + 1 + n_help]
    nu = cx.dc[log + 1 + n_help:log + 3 + n_help]
    p1 = POW256[1]
    first, last, src = ((L.A_Q8, L.A_RO1, L.A_Q8) if q else
                        (L.A_K8, L.A_RKRL, L.A_K8))
    # push order: eq(tau) eq(pq|pk) eq(p_o|pv) pub(C) pub(S') planes flip helpers
    ic, is_ = 3, 4
    idx = a_range(first, last, 5)
    iflip = 5 + (last - first + 1)
    h0 = iflip + 1
    lks = lk_tables(pb_lookups(dom), idx, cx.g_u8)
    half = k(1 << (L.SH_QKV - 1))

    def at(p):
        return v[idx[p]]

    rot, rot_rem = ((at(L.A_QR8), at(L.A_RQRL)) if q else
                    (at(L.A_KR8), at(L.A_RKRL)))
    rope = add(sub(sub(add(mul(v[ic], at(src)), mul(v[is_], v[iflip])),
                       mul(k(1 << L.SH_ROPE), rot)), rot_rem),
               k(1 << (L.SH_ROPE - 1)))
    zc = add(mul(mu[0], rope), helper_sum(v, lks, h0, cx.alpha, mu[1:]))
    if q:
        host1 = sub(add(mul(k(1 << L.SH_QKV), at(L.A_Q8)), at(L.A_RQL)), half)
        host2 = sub(add(add(mul(k(1 << L.SH_O), at(L.A_O8)), at(L.A_RO0)),
                        mul(at(L.A_RO1), p1)), k(1 << (L.SH_O - 1)))
    else:
        host1 = sub(add(mul(k(1 << L.SH_QKV), at(L.A_K8)), at(L.A_RKL)), half)
        host2 = sub(add(mul(k(1 << L.SH_QKV), at(L.A_V8)), at(L.A_RVL)), half)
    return add(add(mul(v[0], zc), mul(mul(nu[0], v[1]), host1)),
               mul(mul(nu[1], v[2]), host2))


def pb15_qzc(v, cx):
    """SC_QZC, the Q zero-check hosting 09Q and 11.  argument.rs:789-830."""
    return _pb_qkv_zc(v, cx, True)


def pb16_kvzc(v, cx):
    """SC_KVZC, the KV zero-check hosting 09K and 09V.  argument.rs:789-830."""
    return _pb_qkv_zc(v, cx, False)


def pb17_szc(v, cx):
    """SC_SZC, the softmax zero-check hosting 07 and 10.
    argument.rs:831-873, closure 852-871.
    Draws: tau(11), mu(5 + 7 helpers + 1), nu(2); `lam` is SC_RS's lam_z."""
    L = PB
    n_help = PB_HELPERS["S"][1]
    mu = cx.dc[11:11 + 5 + n_help + 1]
    nu = cx.dc[11 + 5 + n_help + 1:11 + 7 + n_help + 1]
    lam = cx.lam_z
    p1 = POW256[1]
    # push order: eq(tau) eq(p_ht) eq(p_s) pub(causal) planes A_S8..=A_SG1
    #             A_MX slice, A_SUM slice, 7 helpers, H_SEXP
    im = 3
    idx = a_range(L.A_S8, L.A_SG1, 4)
    imx = 4 + (L.A_SG1 - L.A_S8 + 1)
    isum = imx + 1
    h0 = isum + 1
    ihx = h0 + n_help
    lks = lk_tables(pb_lookups("S"), idx, cx.g_u8)

    def at(p):
        return v[idx[p]]

    mask, s8, zsel, e, p, s_sum = (v[im], at(L.A_S8), at(L.A_ZSEL), at(L.A_E),
                                   at(L.A_P), v[isum])
    sr = add(at(L.A_SR0), mul(at(L.A_SR1), p1))
    delta = add(sub(v[imx], mul(mask, add(s8, k(-L.MASK_SCORE)))), k(-L.MASK_SCORE))
    c0 = sub(mul(zsel, zsel), zsel)
    c1 = mul(zsel, delta)
    c2 = sub(sub(mul(mul(k(1 << L.F_P), mask), e), mul(p, s_sum)), sr)
    c3 = sub(add(add(add(at(L.A_SG0), mul(at(L.A_SG1), p1)), sr), ONE), s_sum)
    c4 = sub(sub(p, at(L.A_PL0)), mul(at(L.A_PL1), p1))
    cx_ = sub(mul(v[ihx], sub(cx.alpha, add(add(delta, mul(cx.beta, e)), cx.g_exp))), ONE)
    zc = add(helper_sum(v, lks, h0, cx.alpha, mu[5:5 + n_help]),
             mul(mu[5 + n_help], cx_))
    for m, c in zip(mu, [c0, c1, c2, c3, c4]):
        zc = add(zc, mul(m, c))
    host_rs = add(s_sum, lam)
    host_s = sub(add(mul(k(1 << L.SH_S), s8), at(L.A_RSL)), k(1 << (L.SH_S - 1)))
    return add(add(mul(v[0], zc), mul(mul(nu[0], v[1]), host_rs)),
               mul(mul(nu[1], v[2]), host_s))


def pb18_fzc(v, cx):
    """SC_FZC, the f-cube zero-check hosting 13G and 13U.
    argument.rs:752-788, closure 770-786.
    Draws: tau(9), mu(4 + 5 helpers), nu(2)."""
    L = PB
    n_help = PB_HELPERS["F"][1]
    mu = cx.dc[9:9 + 4 + n_help]
    nu = cx.dc[9 + 4 + n_help:9 + 6 + n_help]
    p1 = POW256[1]
    # push order: eq(tau) eq(p_g) eq(p_u) planes A_G8..=A_RH1, 5 helpers, H_FACT
    idx = a_range(L.A_G8, L.A_RH1, 3)
    h0 = 3 + (L.A_RH1 - L.A_G8 + 1)
    i_fact = h0 + n_help
    lks = lk_tables(pb_lookups("F"), idx, cx.g_u8)

    def at(p):
        return v[idx[p]]

    def l2(o):
        return add(at(o), mul(at(o + 1), p1))

    g8, a16, u16, h16 = at(L.A_G8), at(L.A_A16), at(L.A_U16), at(L.A_H16)
    f0 = add(sub(sub(mul(a16, u16), mul(k(1 << L.SH_H_PROD), h16)), l2(L.A_RH0)),
             k(1 << (L.SH_H_PROD - 1)))
    f1 = sub(add(u16, k(32768)), l2(L.A_UL0))
    f2 = sub(add(h16, k(32768)), l2(L.A_HL0))
    f_act = sub(mul(v[i_fact],
                    sub(cx.alpha,
                        add(add(add(g8, k(128)), mul(cx.beta, a16)), cx.g_act))), ONE)
    zc = helper_sum(v, lks, h0, cx.alpha, mu[4:])
    for m, c in zip(mu, [f0, f1, f2, f_act]):
        zc = add(zc, mul(m, c))
    host_g = sub(add(mul(k(1 << L.SH_G), g8), at(L.A_RGL)), k(1 << (L.SH_G - 1)))
    host_u = u16  # SH_U = 0: no coefficient, no constant, no remainder (T2 A.4)
    return add(add(mul(v[0], zc), mul(mul(nu[0], v[1]), host_g)),
               mul(mul(nu[1], v[2]), host_u))


def pb19_tab(v, cx):
    """SC_TAB, the three (multiplicity, helper, public values) triples.
    argument.rs:876-896, closure 889-894.  Draws: tau(8), mu(3)."""
    mu = cx.dc[8:11]
    a = cx.alpha
    r0 = sub(mul(v[2], sub(a, v[3])), v[1])
    r1 = sub(mul(v[5], sub(a, v[6])), v[4])
    r2 = sub(mul(v[8], sub(a, v[9])), v[7])
    return mul(v[0], add(add(mul(mu[0], r0), mul(mu[1], r1)), mul(mu[2], r2)))


def pb20_zs(v, cx):
    """SC_ZS, the zero-sum row.  argument.rs:897-901.  `|v| v[0].mul(v[1])`"""
    return mul(v[0], v[1])


def pb21_io_in(v, cx):
    """SC_IO_IN, the input endpoint equality.  argument.rs:902-909.
    `|v| v[0].mul(v[1].sub(v[2]))`"""
    return mul(v[0], sub(v[1], v[2]))


def pb22_io_out(v, cx):
    """SC_IO_OUT, the output endpoint equality.  argument.rs:902-909."""
    return mul(v[0], sub(v[1], v[2]))


# ============================================================================
# the eighteen terminal polynomials of the PRIVATE ATTENTION profile
# hashline/src/private_attention/argument.rs::define, in slot order
# ============================================================================
def pa00_ss(v, cx):
    """SC_SS.  argument.rs:522-527.  `|v| v[0].mul(v[1]).mul(v[1])`"""
    return mul(mul(v[0], v[1]), v[1])


def pa01_tzc(v, cx):
    """SC_TZC, the norm squares zero-check hosting 01.
    argument.rs:528-546, closure 539-544.  Draws: tau(5), mu(3), nu(1)."""
    mu, nu = cx.dc[5:8], cx.dc[8]
    p1, p2 = POW256[1], POW256[2]

    def l3(o):
        return add(add(v[o], mul(v[o + 1], p1)), mul(v[o + 2], p2))

    # push order: eq(tau) eq(r_t) A_D A_DSQ 9 limb slices
    d, dsq, dl, a1, a2 = v[2], v[3], l3(4), l3(7), l3(10)
    zc = add(add(mul(mu[0], sub(dsq, mul(d, d))), mul(mu[1], sub(d, dl))),
             mul(mu[2], sub(sub(double(d), a1), a2)))
    return add(mul(v[0], zc),
               mul(mul(nu, v[1]), sub(add(dsq, a1), k(PA.NORM_CEPS))))


def pa02_lzc(v, cx):
    """SC_LZC, the limb zero-check.  argument.rs:547-554.  Draws: tau(9).
    One lookup, so the single-helper branch of `helper_sum` applies."""
    idx = a_range(PA.A_LIMB, PA.A_LIMB, 1)
    h0 = 2
    lks = lk_tables(pa_lookups("L"), idx, cx.g_u8)
    return mul(v[0], helper_sum(v, lks, h0, cx.alpha, [ONE]))


def pa03_rs(v, cx):
    """SC_RS, masked row sums + selector.  argument.rs:555-564.
    Draws: p_ht(6), lam_z(1)."""
    lam = cx.dc[6]
    return mul(v[0], add(mul(v[1], v[2]), mul(lam, v[3])))


def pa04_qmm(v, cx):
    """SC_QMM.  argument.rs:565-589.  `|v| v[0].mul(v[1])`"""
    return mul(v[0], v[1])


def pa05_kmm(v, cx):
    """SC_KMM.  argument.rs:565-589."""
    return mul(v[0], v[1])


def pa06_vmm(v, cx):
    """SC_VMM.  argument.rs:565-589."""
    return mul(v[0], v[1])


def pa07_score(v, cx):
    """SC_SCORE, the bilinear score matmul.  argument.rs:590-603."""
    return mul(v[0], v[1])


def pa08_pv(v, cx):
    """SC_PV, the bilinear PV matmul.  argument.rs:604-616."""
    return mul(v[0], v[1])


def pa09_wo(v, cx):
    """SC_WO.  argument.rs:565-589."""
    return mul(v[0], v[1])


def pa10_dzc(v, cx):
    """SC_DZC, the d-cube zero-check hosting 12.
    argument.rs:617-652, closure 632-650.
    Draws: tau(9), mu(6 + 10 helpers), nu(1)."""
    L = PA
    n_help = PA_HELPERS["D"][1]
    mu = cx.dc[9:9 + 6 + n_help]
    nu = cx.dc[9 + 6 + n_help]
    p1, p2, p3 = POW256[1], POW256[2], POW256[3]
    # push order: eq(tau) eq(p_a) pub(gamma_a) planes A_X..=A_X1L1,
    #             A_D slice, 10 helpers
    ig = 2
    idx = a_range(L.A_X, L.A_X1L1, 3)
    id_ = 3 + (L.A_X1L1 - L.A_X + 1)
    h0 = id_ + 1
    lks = lk_tables(pa_lookups("D"), idx, cx.g_u8)
    k_num, k_dv, k_den = k(2 * L.NORM_CN), k(1 << L.NORM_TN), k(1 << (L.NORM_TN + 1))

    def at(p):
        return v[idx[p]]

    def l4(o):
        return add(add(add(at(o), mul(at(o + 1), p1)), mul(at(o + 2), p2)),
                   mul(at(o + 3), p3))

    def l2(o):
        return add(at(o), mul(at(o + 1), p1))

    x, y, ao, x1, d = at(L.A_X), at(L.A_Y), at(L.A_AO), at(L.A_X1), v[id_]
    nr, ns = l4(L.A_NR0), l4(L.A_NS0)
    c0 = sub(sub(add(mul(mul(k_num, v[ig]), x), mul(k_dv, d)),
                 mul(mul(k_den, y), d)), nr)
    c1 = sub(add(add(ns, nr), ONE), mul(k_den, d))
    c2 = sub(add(x, k(32768)), l2(L.A_XL0))
    c3 = sub(add(ao, k(32768)), l2(L.A_AL0))
    c4 = sub(add(x1, k(32768)), l2(L.A_X1L0))
    c5 = sub(sub(x1, x), ao)
    zc = helper_sum(v, lks, h0, cx.alpha, mu[6:])
    for m, c in zip(mu, [c0, c1, c2, c3, c4, c5]):
        zc = add(zc, mul(m, c))
    host = sub(add(mul(k(1 << L.SH_AO), ao), at(L.A_RAL)), k(1 << (L.SH_AO - 1)))
    return add(mul(v[0], zc), mul(mul(nu, v[1]), host))


def _pa_qkv_zc(v, cx, q: bool):
    """SC_QZC / SC_KVZC, one arm in the source.
    argument.rs:653-694, closure 678-692.
    Draws: tau(dom.log), mu(1 + helpers), nu(2)."""
    L = PA
    dom = "Q" if q else "Kv"
    log = 9 if q else 8
    n_help = PA_HELPERS[dom][1]
    mu = cx.dc[log:log + 1 + n_help]
    nu = cx.dc[log + 1 + n_help:log + 3 + n_help]
    p1 = POW256[1]
    first, last, src = ((L.A_Q8, L.A_RO1, L.A_Q8) if q else
                        (L.A_K8, L.A_RKRL, L.A_K8))
    ic, is_ = 3, 4
    idx = a_range(first, last, 5)
    iflip = 5 + (last - first + 1)
    h0 = iflip + 1
    lks = lk_tables(pa_lookups(dom), idx, cx.g_u8)
    half = k(1 << (L.SH_QKV - 1))

    def at(p):
        return v[idx[p]]

    rot, rot_rem = ((at(L.A_QR8), at(L.A_RQRL)) if q else
                    (at(L.A_KR8), at(L.A_RKRL)))
    rope = add(sub(sub(add(mul(v[ic], at(src)), mul(v[is_], v[iflip])),
                       mul(k(1 << L.SH_ROPE), rot)), rot_rem),
               k(1 << (L.SH_ROPE - 1)))
    zc = add(mul(mu[0], rope), helper_sum(v, lks, h0, cx.alpha, mu[1:]))
    if q:
        host1 = sub(add(mul(k(1 << L.SH_QKV), at(L.A_Q8)), at(L.A_RQL)), half)
        host2 = sub(add(add(mul(k(1 << L.SH_O), at(L.A_O8)), at(L.A_RO0)),
                        mul(at(L.A_RO1), p1)), k(1 << (L.SH_O - 1)))
    else:
        host1 = sub(add(mul(k(1 << L.SH_QKV), at(L.A_K8)), at(L.A_RKL)), half)
        host2 = sub(add(mul(k(1 << L.SH_QKV), at(L.A_V8)), at(L.A_RVL)), half)
    return add(add(mul(v[0], zc), mul(mul(nu[0], v[1]), host1)),
               mul(mul(nu[1], v[2]), host2))


def pa11_qzc(v, cx):
    """SC_QZC, the Q zero-check hosting 09Q and 11.  argument.rs:653-694."""
    return _pa_qkv_zc(v, cx, True)


def pa12_kvzc(v, cx):
    """SC_KVZC, the KV zero-check hosting 09K and 09V.  argument.rs:653-694."""
    return _pa_qkv_zc(v, cx, False)


def pa13_szc(v, cx):
    """SC_SZC, the softmax zero-check hosting 07 and 10.
    argument.rs:695-737, closure 716-735.
    Draws: tau(11), mu(5 + 7 helpers + 1), nu(2); `lam` is SC_RS's lam_z."""
    L = PA
    n_help = PA_HELPERS["S"][1]
    mu = cx.dc[11:11 + 5 + n_help + 1]
    nu = cx.dc[11 + 5 + n_help + 1:11 + 7 + n_help + 1]
    lam = cx.lam_z
    p1 = POW256[1]
    im = 3
    idx = a_range(L.A_S8, L.A_SG1, 4)
    imx = 4 + (L.A_SG1 - L.A_S8 + 1)
    isum = imx + 1
    h0 = isum + 1
    ihx = h0 + n_help
    lks = lk_tables(pa_lookups("S"), idx, cx.g_u8)

    def at(p):
        return v[idx[p]]

    mask, s8, zsel, e, p, s_sum = (v[im], at(L.A_S8), at(L.A_ZSEL), at(L.A_E),
                                   at(L.A_P), v[isum])
    sr = add(at(L.A_SR0), mul(at(L.A_SR1), p1))
    delta = add(sub(v[imx], mul(mask, add(s8, k(-L.MASK_SCORE)))), k(-L.MASK_SCORE))
    c0 = sub(mul(zsel, zsel), zsel)
    c1 = mul(zsel, delta)
    c2 = sub(sub(mul(mul(k(1 << L.F_P), mask), e), mul(p, s_sum)), sr)
    c3 = sub(add(add(add(at(L.A_SG0), mul(at(L.A_SG1), p1)), sr), ONE), s_sum)
    c4 = sub(sub(p, at(L.A_PL0)), mul(at(L.A_PL1), p1))
    cx_ = sub(mul(v[ihx], sub(cx.alpha, add(add(delta, mul(cx.beta, e)), cx.g_exp))), ONE)
    zc = add(helper_sum(v, lks, h0, cx.alpha, mu[5:5 + n_help]),
             mul(mu[5 + n_help], cx_))
    for m, c in zip(mu, [c0, c1, c2, c3, c4]):
        zc = add(zc, mul(m, c))
    host_rs = add(s_sum, lam)
    host_s = sub(add(mul(k(1 << L.SH_S), s8), at(L.A_RSL)), k(1 << (L.SH_S - 1)))
    return add(add(mul(v[0], zc), mul(mul(nu[0], v[1]), host_rs)),
               mul(mul(nu[1], v[2]), host_s))


def pa14_tab(v, cx):
    """SC_TAB, the two (multiplicity, helper, public values) triples.
    argument.rs:738-754, closure 748-752.  Draws: tau(8), mu(2)."""
    mu = cx.dc[8:10]
    a = cx.alpha
    r0 = sub(mul(v[2], sub(a, v[3])), v[1])
    r1 = sub(mul(v[5], sub(a, v[6])), v[4])
    return mul(v[0], add(mul(mu[0], r0), mul(mu[1], r1)))


def pa15_zs(v, cx):
    """SC_ZS, the zero-sum row.  argument.rs:755-759."""
    return mul(v[0], v[1])


def pa16_io_in(v, cx):
    """SC_IO_IN, the input endpoint equality.  argument.rs:760-766."""
    return mul(v[0], sub(v[1], v[2]))


def pa17_io_out(v, cx):
    """SC_IO_OUT, the output endpoint equality.  argument.rs:760-766."""
    return mul(v[0], sub(v[1], v[2]))


# ---------------------------------------------------------- the slot tables
SlotPort = collections.namedtuple(
    "SlotPort", "index name source lines draws tables fn"
)

PB_SRC = "hashline/src/private_block/argument.rs"
PA_SRC = "hashline/src/private_attention/argument.rs"


def _kinds(spec: str):
    """"e e p*22" -> ['eq', 'eq', 'private' x 22]: the table push order."""
    long = {"e": "eq", "u": "public", "p": "private"}
    out = []
    for tok in spec.split():
        name, _, count = tok.partition("*")
        out += [long[name]] * (int(count) if count else 1)
    return tuple(out)


# slot index, name (the capture's own SLOT_NAMES), source file, the closure's
# line range, the number of Fp2 draws `define` makes, the table push order,
# and the ported function.  ORDER IS THE RUST SLOT ORDER and is checked
# against every capture.
BLOCK_PORTS = (
    SlotPort(0, "01 SS row sums norm_a (private)", PB_SRC, "544-549", 5, _kinds("e p"), pb00_ss),
    SlotPort(1, "01m SS row sums norm_m (private)", PB_SRC, "552-557", 5, _kinds("e p"), pb01_ssm),
    SlotPort(2, "02 norm squares zero-check (hosts 01, 01m)", PB_SRC, "583-593", 13, _kinds("e*3 p*22"), pb02_tzc),
    SlotPort(3, "08 limb zero-check", PB_SRC, "598-605", 9, _kinds("e p*3"), pb03_lzc),
    SlotPort(4, "07 masked row sums + selector (private)", PB_SRC, "606-615", 7, _kinds("e u p*2"), pb04_rs),
    SlotPort(5, "09Q matmul (private)", PB_SRC, "616-640", 9, _kinds("p u"), pb05_qmm),
    SlotPort(6, "09K matmul (private)", PB_SRC, "616-640", 3, _kinds("p u"), pb06_kmm),
    SlotPort(7, "09V matmul (private)", PB_SRC, "616-640", 3, _kinds("p u"), pb07_vmm),
    SlotPort(8, "10 score matmul (private, bilinear)", PB_SRC, "641-654", 11, _kinds("p*2"), pb08_score),
    SlotPort(9, "11 PV matmul (private, bilinear)", PB_SRC, "655-667", 9, _kinds("p*2"), pb09_pv),
    SlotPort(10, "12 Wo matmul (private)", PB_SRC, "616-640", 9, _kinds("p u"), pb10_wo),
    SlotPort(11, "13G gate matmul (private)", PB_SRC, "674-698", 9, _kinds("p u"), pb11_gmm),
    SlotPort(12, "13U up matmul (private)", PB_SRC, "674-698", 4, _kinds("p u"), pb12_umm),
    SlotPort(13, "13D down matmul (private)", PB_SRC, "674-698", 9, _kinds("p u"), pb13_dmm),
    SlotPort(14, "03 D zero-check (hosts 12, 13D)", PB_SRC, "718-746", 41, _kinds("e*3 u*2 p*56"), pb14_dzc),
    SlotPort(15, "04 Q zero-check (hosts 09Q, 11)", PB_SRC, "814-828", 19, _kinds("e*3 u*2 p*15"), pb15_qzc),
    SlotPort(16, "05 KV zero-check (hosts 09K, 09V)", PB_SRC, "814-828", 17, _kinds("e*3 u*2 p*13"), pb16_kvzc),
    SlotPort(17, "06 softmax zero-check (hosts 07, 10)", PB_SRC, "852-871", 26, _kinds("e*3 u p*21"), pb17_szc),
    SlotPort(18, "14 F zero-check (hosts 13G, 13U)", PB_SRC, "770-786", 20, _kinds("e*3 p*17"), pb18_fzc),
    SlotPort(19, "TAB table helper zero-check", PB_SRC, "889-894", 11, _kinds("e p*2 u p*2 u p*2 u"), pb19_tab),
    SlotPort(20, "ZS zero-sum row", PB_SRC, "897-901", 0, _kinds("u p"), pb20_zs),
    SlotPort(21, "IO-in endpoint equality", PB_SRC, "902-909", 9, _kinds("e p*2"), pb21_io_in),
    SlotPort(22, "IO-out endpoint equality", PB_SRC, "902-909", 9, _kinds("e p*2"), pb22_io_out),
)

ATTENTION_PORTS = (
    SlotPort(0, "01 SS row sums (private)", PA_SRC, "522-527", 5, _kinds("e p"), pa00_ss),
    SlotPort(1, "02 norm squares zero-check (hosts 01)", PA_SRC, "539-544", 9, _kinds("e*2 p*11"), pa01_tzc),
    SlotPort(2, "08 limb zero-check", PA_SRC, "547-554", 9, _kinds("e p*2"), pa02_lzc),
    SlotPort(3, "07 masked row sums + selector (private)", PA_SRC, "555-564", 7, _kinds("e u p*2"), pa03_rs),
    SlotPort(4, "09Q matmul (private)", PA_SRC, "565-589", 9, _kinds("p u"), pa04_qmm),
    SlotPort(5, "09K matmul (private)", PA_SRC, "565-589", 3, _kinds("p u"), pa05_kmm),
    SlotPort(6, "09V matmul (private)", PA_SRC, "565-589", 3, _kinds("p u"), pa06_vmm),
    SlotPort(7, "10 score matmul (private, bilinear)", PA_SRC, "590-603", 11, _kinds("p*2"), pa07_score),
    SlotPort(8, "11 PV matmul (private, bilinear)", PA_SRC, "604-616", 9, _kinds("p*2"), pa08_pv),
    SlotPort(9, "12 Wo matmul (private)", PA_SRC, "565-589", 9, _kinds("p u"), pa09_wo),
    SlotPort(10, "03 D zero-check (hosts 12)", PA_SRC, "632-650", 26, _kinds("e*2 u p*30"), pa10_dzc),
    SlotPort(11, "04 Q zero-check (hosts 09Q, 11)", PA_SRC, "678-692", 19, _kinds("e*3 u*2 p*15"), pa11_qzc),
    SlotPort(12, "05 KV zero-check (hosts 09K, 09V)", PA_SRC, "678-692", 17, _kinds("e*3 u*2 p*13"), pa12_kvzc),
    SlotPort(13, "06 softmax zero-check (hosts 07, 10)", PA_SRC, "716-735", 26, _kinds("e*3 u p*21"), pa13_szc),
    SlotPort(14, "TAB table helper zero-check", PA_SRC, "748-752", 10, _kinds("e p*2 u p*2 u"), pa14_tab),
    SlotPort(15, "ZS zero-sum row", PA_SRC, "755-759", 0, _kinds("u p"), pa15_zs),
    SlotPort(16, "IO-in endpoint equality", PA_SRC, "760-766", 9, _kinds("e p*2"), pa16_io_in),
    SlotPort(17, "IO-out endpoint equality", PA_SRC, "760-766", 9, _kinds("e p*2"), pa17_io_out),
)

PROFILE_BLOCK = "hashline-zk-mr1/private-block-t32-poc/1"
PROFILE_ATTENTION = "hashline-zk-mr1/private-attention-t32-poc/1"
PORTS = {PROFILE_BLOCK: BLOCK_PORTS, PROFILE_ATTENTION: ATTENTION_PORTS}
# the slot whose `define` draws `lam_z`, and its position among that slot's
# draws: `pts.lam_z = tr.challenge_fp2();` after `p_ht`'s six draws
LAM_Z_AT = {PROFILE_BLOCK: (4, 6), PROFILE_ATTENTION: (3, 6)}
# the slots the standing negative controls perturb: the first slot, a matmul,
# and the two biggest zero-checks of each profile (the ones with the lookup
# batteries, the host terms and the deepest table lists)
DEFAULT_CONTROL_SLOTS = {PROFILE_BLOCK: (0, 11, 14, 17), PROFILE_ATTENTION: (0, 9, 10, 13)}
# `gamma.mul_base(Fp::new(TAG))`, tables_attn.rs TAG_EXP 129 / TAG_U8 133 / TAG_ACT 134
TAG_EXP, TAG_U8, TAG_ACT = 129, 133, 134


def ports_for(profile: str):
    return PORTS[profile]


# -------------------------------------------------------- the verifier's view
class ModuleContext:
    """Everything a slot's closure captured that is not a table value.

    `alpha`, `beta` and the three tag offsets come from the capture's
    `logup_challenges`, which `protocol.rs:330-335` draws as
    (beta, gamma, alpha) and turns into `g_x = gamma * TAG_x`.  `dc` is set
    per slot to that slot's `definition_challenges`.
    """

    def __init__(self, capture):
        self.profile = capture.profile
        beta, gamma, alpha = (f2_from_list(x) for x in capture.doc["logup_challenges"])
        self.alpha, self.beta, self.gamma = alpha, beta, gamma
        self.g_u8 = mulb(gamma, TAG_U8)
        self.g_exp = mulb(gamma, TAG_EXP)
        self.g_act = mulb(gamma, TAG_ACT)
        slot, at = LAM_Z_AT[capture.profile]
        self.lam_z = f2_from_list(capture.slots[slot]["definition_challenges"][at])
        self.dc = []

    def for_slot(self, slot_doc):
        self.dc = [f2_from_list(x) for x in slot_doc["definition_challenges"]]
        return self


def eq_point(r, s):
    """`eq_point` (zkp-core/src/mle.rs:54): prod a*b + (1-a)*(1-b)."""
    if len(r) != len(s):
        raise ValueError("eq_point arity")
    acc = ONE
    for a, b in zip(r, s):
        acc = mul(acc, add(mul(a, b), mul(sub(ONE, a), sub(ONE, b))))
    return acc


def slot_vals(slot_doc, rho_full, main):
    """The verifier's `vals` vector of one slot (argument.rs:328-339 / :314-325).

    `sel` multiplies the PUBLIC entries only; a private table contributes its
    published terminal unchanged.
    """
    es = rho_full[main:]
    sel = ONE
    for e in es:
        sel = mul(sel, sub(ONE, e))
    rho_main = rho_full[:main]
    eq_msb = None
    vals, kt = [], 0
    terminals = slot_doc["terminals"]
    for t in slot_doc["tables"]:
        kind = t["kind"]
        if kind == "eq":
            point = [f2_from_list(x) for x in t["point"]]
            start = t["start"]
            vals.append(mul(sel, eq_point(point, rho_main[start:start + len(point)])))
        elif kind == "public":
            if len(t["values"]) != 1 << main:
                raise ValueError("public table length differs from 2^main")
            if eq_msb is None:
                eq_msb = eq_table_msb(rho_main)
            acc = ZERO
            for value, e in zip(t["values"], eq_msb):
                acc = add(acc, mul(e, f2_from_list(value)))
            vals.append(mul(sel, acc))
        else:
            vals.append(f2_from_list(terminals[kt]))
            kt += 1
    if kt != len(terminals):
        raise ValueError("private table count differs from the terminal count")
    return vals


def eval_functional_index(capture, slot: int) -> int:
    """Which M functional carries slot `s`'s mask evaluation.

    The declared order is, per slot, `[Gamma_s if standalone] eval_s`, with the
    hosts' batched Gammas appended last (argument.rs:361-376, 924-925).
    """
    before = sum(1 for a in capture.slots[:slot] if a["kind"] == "Standalone")
    own = 1 if capture.slots[slot]["kind"] == "Standalone" else 0
    return slot + before + own


def check_capture(capture, replay=None, ports=None) -> dict:
    """Recompute every slot's terminal polynomial and compare it with the
    receipt's own final claim, in the masked form the verifier checks:

        fin_s == c_s * mask_eval_s + poly_s(vals_s)

    `fin_s` is recomputed from the published rounds, `c_s` and `rho` come from
    the stage-1 transcript replay when one is supplied (otherwise from the
    capture, which is then recorded in `challenges_from`).
    """
    ports = ports if ports is not None else ports_for(capture.profile)
    ctx = ModuleContext(capture)
    scalars = [f2_from_list(a["scalar"]) for a in capture.slots]
    out = {
        "capture": capture.proof_sha256,
        "profile": capture.profile,
        "challenges_from": "transcript replay" if replay else "the capture",
        "slots": len(capture.slots),
        "slots_checked": 0,
        "slots_equal": 0,
        "slots_matching_the_stored_terminal_polynomial": 0,
        "mask_evaluations_published_as_the_slot_functional": 0,
        "not_checkable": [],
        "findings": [],
        "per_slot": [],
    }
    if len(ports) != len(capture.slots):
        out["findings"].append(
            f"the port has {len(ports)} slots for {len(capture.slots)} in the capture"
        )
        out["ok"] = False
        return out
    for port, arg in zip(ports, capture.slots):
        row = {"slot": port.index, "name": port.name, "equal": False, "checkable": True}
        reason = None
        if arg["slot"] != port.index or arg["name"] != port.name:
            reason = (f"the capture's slot {arg['slot']} is {arg['name']!r}, the port's "
                      f"slot {port.index} is {port.name!r}: slot order differs")
        elif len(arg["definition_challenges"]) != port.draws:
            reason = (f"{len(arg['definition_challenges'])} definition challenges for the "
                      f"port's {port.draws}: the slot's draw order changed")
        elif tuple(t["kind"] for t in arg["tables"]) != port.tables:
            reason = "the capture's table push order differs from the ported one"
        if reason is not None:
            row.update({"checkable": False, "reason": reason})
            out["not_checkable"].append({"slot": port.index, "reason": reason})
            out["findings"].append(f"slot {port.index}: {reason}")
            out["per_slot"].append(row)
            continue
        main = arg["main"]
        if replay is not None:
            rho_full = replay.rho[port.index]
            c = replay.slot_c[port.index]
        else:
            rho_full = [f2_from_list(x) for x in arg["rho"]]
            c = f2_from_list(arg["c"])
        claimed = scalars[port.index]
        for h in arg["hosted"]:
            claimed = add(claimed, mul(f2_from_list(h["coefficient"]), scalars[h["slot"]]))
        fin, _consistent = sumcheck_final(arg["rounds"], arg["degree"], rho_full, claimed)
        mask_eval = f2_from_list(arg["mask_eval"])
        try:
            vals = slot_vals(arg, rho_full, main)
            poly = port.fn(vals, ctx.for_slot(arg))
        except (ValueError, IndexError, KeyError) as exc:  # a shape the port cannot read
            reason = f"the ported polynomial could not be evaluated: {exc}"
            row.update({"checkable": False, "reason": reason})
            out["not_checkable"].append({"slot": port.index, "reason": reason})
            out["findings"].append(f"slot {port.index}: {reason}")
            out["per_slot"].append(row)
            continue
        out["slots_checked"] += 1
        equal = fin is not None and fin == add(mul(c, mask_eval), poly)
        row["equal"] = bool(equal)
        if equal:
            out["slots_equal"] += 1
        else:
            out["findings"].append(
                f"slot {port.index} [{port.name}]: fin != c*mask_eval + poly(terminals)"
            )
        if poly == f2_from_list(arg["terminal_polynomial"]):
            out["slots_matching_the_stored_terminal_polynomial"] += 1
        fi = eval_functional_index(capture, port.index)
        published = capture.mask["functionals"][fi]
        if f2_from_list(published["value"]) == mask_eval and [
            t["slot"] for t in published["terms"]
        ] == [port.index]:
            out["mask_evaluations_published_as_the_slot_functional"] += 1
        else:
            out["findings"].append(
                f"slot {port.index}: M functional {fi} is not this slot's mask evaluation"
            )
        out["per_slot"].append(row)
    out["ok"] = (
        not out["findings"]
        and out["slots_checked"] == out["slots"]
        and out["slots_equal"] == out["slots"]
        and out["slots_matching_the_stored_terminal_polynomial"] == out["slots"]
        and out["mask_evaluations_published_as_the_slot_functional"] == out["slots"]
    )
    return out


def perturbed_ports(ports, index: int, delta=F2_ONE):
    """`ports` with slot `index`'s polynomial changed by one term: + delta.

    The negative control the weak identity of report section 3.1 could not
    provide -- a changed terminal polynomial must be caught, at that slot only.
    """
    port = ports[index]
    base = port.fn
    return tuple(
        p._replace(fn=(lambda v, cx, _b=base: add(_b(v, cx), delta)))
        if i == index else p
        for i, p in enumerate(ports)
    )


def terminal_poly_controls(capture, replay=None, slots=None) -> dict:
    """Two negative controls per named slot, each undone before returning:

    (a) one term of the SLOT'S PORTED POLYNOMIAL perturbed by one;
    (b) one CLAIMED EVALUATION (a published terminal) of that slot perturbed
        by one -- the perturbation the weak per-slot identity cannot see.

    Each must make exactly that slot unequal, and no other.
    """
    ports = ports_for(capture.profile)
    if slots is None:
        slots = DEFAULT_CONTROL_SLOTS[capture.profile]
    out = {"capture": capture.proof_sha256[:16], "controls": [], "ok": True}
    honest = check_capture(capture, replay)
    for index in slots:
        bad = check_capture(capture, replay, ports=perturbed_ports(ports, index))
        changed_poly = [r["slot"] for r in bad["per_slot"] if not r["equal"]]
        arg = capture.slots[index]
        arg["terminals"][0][0] = (arg["terminals"][0][0] + 1) % P
        bad2 = check_capture(capture, replay)
        arg["terminals"][0][0] = (arg["terminals"][0][0] - 1) % P
        changed_eval = [r["slot"] for r in bad2["per_slot"] if not r["equal"]]
        row = {
            "slot": index,
            "name": ports[index].name,
            "changed_terminal_polynomial_fails_at": changed_poly,
            "changed_claimed_evaluation_fails_at": changed_eval,
            "only_that_slot": changed_poly == [index] and changed_eval == [index],
        }
        out["controls"].append(row)
        out["ok"] = out["ok"] and row["only_that_slot"]
    out["honest_again"] = check_capture(capture, replay)["ok"]
    out["ok"] = out["ok"] and honest["ok"] and out["honest_again"]
    return out


def summary(capture, replay=None) -> dict:
    """The per-capture row the gate and the evidence record carry (no witness
    value, no salt, no plane: counts, names and equal / not equal only)."""
    full = check_capture(capture, replay)
    per_slot = full.pop("per_slot")
    full["slots_unequal"] = [r["slot"] for r in per_slot if r["checkable"] and not r["equal"]]
    return full


# ------------------------------------------------------------------- main
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--captures", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--skip-controls", action="store_true")
    args = ap.parse_args(argv)

    from zk60_native_jv_capture import load_all
    from zk60_native_jv_replay import Replay

    t0 = time.time()
    pins = check_source_pins()
    caps = load_all(args.captures)
    if not caps:
        print("no captures found", file=sys.stderr)
        return 2
    record = {
        "gate": "zk60-native-terminal-polynomials",
        "version": 1,
        "privacy_property_established": False,
        "what_this_is": (
            "the verifier's final equation fin = c*mask_eval + poly(terminals), "
            "recomputed from a Python port of the Rust terminal polynomials"
        ),
        "reviewed_obligation": (
            "the equality of each ported function with its Rust closure is "
            "established by reading, not by machine"
        ),
        "source_pins": pins,
        "port_sha256": hashlib.sha256(
            open(os.path.abspath(__file__), "rb").read()
        ).hexdigest(),
        "captures_dir": os.path.abspath(args.captures),
        "per_capture": [],
    }
    for cap in caps:
        rp = Replay(cap).run()
        if not rp.summary()["ok"]:
            record["per_capture"].append(
                {"capture": cap.proof_sha256, "replay_failed": rp.failures[:4]}
            )
            continue
        row = summary(cap, rp)
        if not args.skip_controls:
            row["negative_controls"] = terminal_poly_controls(cap, rp)
        record["per_capture"].append(row)
    record["ok"] = all(
        r.get("ok") and (args.skip_controls or r["negative_controls"]["ok"])
        for r in record["per_capture"]
    )
    record["seconds"] = round(time.time() - t0, 1)

    os.makedirs(args.evidence, exist_ok=True)
    out = os.path.join(args.evidence, "terminal_polys.json")
    with open(out, "w") as fh:
        json.dump(record, fh, indent=1, sort_keys=True)
        fh.write("\n")
    with open(os.path.join(args.evidence, "terminal_polys.done"), "w") as fh:
        fh.write("0\n" if record["ok"] else "1\n")
    for r in record["per_capture"]:
        print(
            f"{r['capture'][:16]} {r.get('profile', '?')}: "
            f"checked {r.get('slots_checked')}/{r.get('slots')}, "
            f"equal {r.get('slots_equal')}, "
            f"not checkable {len(r.get('not_checkable', []))}"
        )
    print(f"record: {out} ({record['seconds']} s) {'ok' if record['ok'] else 'FAIL'}")
    return 0 if record["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
