#!/usr/bin/env python3
"""Independent exact-integer no-wrap check for the TRAINED norm calibration
class of the native lane (2026-10-17). No prover import; pure integers.

Declared class (enforced by NormCalibration::derive_at_width and by the
kernel-shaped Shape::check):
  width w in 1..=4096, tn in 1..=16, Cn (cn_a, cn_m) in 1..=2^20,
  Ceps in 1..=2^40, sh_ao in 0..=8,
  D_max = isqrt(Ceps + w * 32768^2), 2 * D_max < 2^24 (three isqrt limbs),
  wrho = tn + 1 + bitlen(D_max) in 25..=32 (exactly four remainder limbs).

For every relation the trained constants enter, the absolute value of every
term is bounded using only the RANGE FACTS the proof establishes for the
committed values (adversarial legal limbs, not honest values), and the sum
of those bounds must stay below p = 2^64 - 2^32 + 1, so that equality in F_p
is equality over the integers.
"""
import json
import math
import sys
from pathlib import Path

P = 2**64 - 2**32 + 1
LIMB_ISQRT = 2**24


def bitlen(v):
    return v.bit_length()


def derive(width, tn, cn_a, cn_m, ceps, sh_ao):
    """Mirror of the validator; returns (D_max, wrho) or raises ValueError."""
    if not (1 <= width <= 4096):
        raise ValueError("width")
    if not (1 <= tn <= 16):
        raise ValueError("tn")
    for cn in (cn_a, cn_m):
        if not (1 <= cn <= 2**20):
            raise ValueError("cn")
    if not (1 <= ceps <= 2**40):
        raise ValueError("ceps")
    if not (0 <= sh_ao <= 8):
        raise ValueError("sh_ao")
    dmax = math.isqrt(ceps + width * 32768**2)
    if 2 * dmax >= LIMB_ISQRT:
        raise ValueError("isqrt limbs")
    wrho = tn + 1 + bitlen(dmax)
    if wrho > 32 or wrho <= 24:
        raise ValueError("window %d" % wrho)
    return dmax, wrho


def max_tn(width, ceps):
    return 31 - bitlen(math.isqrt(ceps + width * 32768**2))


def bounds(width, tn, cn, ceps, sh_ao, wrho):
    """Adversarial absolute bounds of every clause the trained constants enter.
    Range facts used (and only these):
      x, x1, x2, ao, z16 in [-32768, 32767]  (two U8 limbs + bias, c2/c3/c4/c8/c10)
      y, nm in [-127, 127]                    (two `sym` U8 lookups)
      gamma public int8 in [-128, 127]
      D, Dm, a1, a2 in [0, 2^24)              (three U8 limbs each; R2)
      rho, sigma in [0, 2^wrho)               (four U8 limbs + top-limb pin)
      ral in [0, 2^sh_ao)                     (U8 + scaled 2^(8 - sh_ao))
      o8 in [-127, 127], Wo public int8
    """
    X, G, Y, DL, R = 32768, 128, 127, LIMB_ISQRT - 1, 2**wrho - 1
    out = {}
    # (R1) dsq - D^2: dsq is defined by it; D^2 < 2^48
    out["R1 dsq - D^2"] = DL * DL
    # (R3) 2D - a1 - a2
    out["R3 2D - a1 - a2"] = 2 * DL + DL + DL
    # (R4) dsq + a1 - Ceps - S, S = sum_i x_i^2 over the row
    S = width * X * X
    out["R4 dsq + a1 - Ceps - S"] = DL * DL + DL + ceps + S
    # (C0)/(C6) 2 Cn g x + 2^tn D - 2^(tn+1) D y - rho
    out["C0 norm quotient"] = 2 * cn * G * X + (2**tn) * DL + (2**(tn + 1)) * DL * Y + R
    # (C1)/(C7) sigma + rho + 1 - 2^(tn+1) D
    out["C1 remainder pair"] = 2 * R + 1 + (2**(tn + 1)) * DL
    # host SC_WO: 2^sh_ao ao + ral - half - acc, |acc| <= d_pad * 127 * 128
    d_pad = 1 << (width - 1).bit_length()
    acc = d_pad * 127 * 128
    half = 0 if sh_ao == 0 else 2**(sh_ao - 1)
    out["host SC_WO"] = (2**sh_ao) * X + (2**sh_ao - 1) + half + acc
    return out


def check():
    report = {"schema": "zk60-native-trained-nowrap/1", "p": P, "class": {
        "width": "1..=4096", "tn": "1..=16", "cn": "1..=2^20", "ceps": "1..=2^40", "sh_ao": "0..=8",
        "isqrt": "2 D_max < 2^24", "window": "25..=32"}}
    # 1. the worst case over the WHOLE declared class: every bound is monotone
    #    in width, tn, cn, ceps, sh_ao and wrho, so the class maximum is at the
    #    corner (w 4096, tn 16, cn 2^20, ceps 2^40, sh_ao 8, wrho 32) — taken
    #    without requiring the corner itself to be admissible (it is not: tn
    #    16 at width 4096 needs a 39-bit window), which only over-bounds.
    corner = bounds(4096, 16, 2**20, 2**40, 8, 32)
    report["class_corner_bounds"] = {k: v for k, v in corner.items()}
    report["class_corner_log2"] = {k: round(math.log2(v), 3) for k, v in corner.items()}
    worst = max(corner.values())
    assert worst < P, "a clause can wrap the field at the class corner"
    report["class_worst_log2"] = round(math.log2(worst), 3)
    report["class_margin_bits"] = round(math.log2(P) - math.log2(worst), 3)
    # 2. every admissible (width, tn) pair on a grid, at the class's cn/ceps/sh_ao maxima
    grid = []
    for width in (16, 96, 384, 768, 1024, 2048, 4096):
        for ceps in (1, 129_746_337, 2**40):
            mt = max_tn(width, ceps)
            for tn in range(1, 17):
                try:
                    dmax, wrho = derive(width, tn, 2**20, 2**20, ceps, 8)
                except ValueError:
                    assert tn > mt or tn + 1 + bitlen(math.isqrt(ceps + width * 32768**2)) <= 24
                    continue
                assert tn <= mt
                b = bounds(width, tn, 2**20, ceps, 8, wrho)
                assert max(b.values()) < P
                # completeness: every honest remainder fits the derived window
                assert (2**(tn + 1)) * dmax - 1 < 2**wrho
                grid.append({"width": width, "ceps": ceps, "tn": tn, "dmax": dmax, "wrho": wrho, "worst_log2": round(math.log2(max(b.values())), 3)})
    report["admissible_grid"] = grid
    report["max_tn"] = {str(w): max_tn(w, 1) for w in (16, 96, 384, 768, 1024, 2048, 4096)}
    assert max_tn(2048, 1) == 10 and max_tn(4096, 1) == 9
    assert max_tn(2048, 2**40) == 10 and max_tn(4096, 2**40) == 9
    # 3. the T3 constants and the trained rung's
    for name, (w, tn, a, m, ceps, ao) in {"T3 TinyLlama": (2048, 10, 2672, 4315, 129_746_337, 7), "rung-TC": (384, 10, 1336, 2158, 33_554_467, 6)}.items():
        dmax, wrho = derive(w, tn, a, m, ceps, ao)
        b = bounds(w, tn, max(a, m), ceps, ao, wrho)
        report[name] = {"dmax": dmax, "wrho": wrho, "limbs": (wrho + 7) // 8, "top_limb_full": wrho == 32,
                        "worst_log2": round(math.log2(max(b.values())), 3)}
    assert report["T3 TinyLlama"]["dmax"] == 1_482_954 and report["T3 TinyLlama"]["wrho"] == 32
    # 4. exactness of the quotient: with rho + sigma + 1 = den and both in
    #    [0, 2^wrho), rho is in [0, den) iff the window holds den - 1, so the
    #    quotient is the floor quotient; checked exhaustively on a small
    #    analogue (window w bits, den up to 2^w)
    for wbits in (3, 4, 5):
        win = 2**wbits
        for den in range(1, win + 1):
            for num in range(-3 * den, 3 * den):
                sols = [(q, num - q * den) for q in range(-8, 9) if 0 <= num - q * den < win and 0 <= den - 1 - (num - q * den) < win]
                assert sols == [(num // den, num % den)], (wbits, den, num, sols)
    # 5. why the class bound matters: an unbounded Cn aliases in the field
    cn_bad = (P - 1) // 2
    fake = 2 * cn_bad * 1 * 1 + 2048 * 1 - 0 - 2047
    assert fake % P == 0 and fake != 0
    report["unbounded_cn_alias"] = {"cn": cn_bad, "integer_residual": fake, "field_residual": fake % P}
    # 6. the witness i64 never overflows inside the class
    assert 2 * 32768 * 128 * 2**20 + (2**16) * LIMB_ISQRT < 2**63
    assert 2**40 + 4096 * 32768**2 < 2**63
    return report


if __name__ == "__main__":
    r = check()
    out = Path(__file__).with_name("nowrap_check.json")
    out.write_text(json.dumps(r, indent=1) + "\n")
    print("PASS: class worst clause 2^%.3f < p (margin %.3f bits); %d admissible grid points; max tn %s; written %s"
          % (r["class_worst_log2"], r["class_margin_bits"], len(r["admissible_grid"]), r["max_tn"], out))
    sys.exit(0)
