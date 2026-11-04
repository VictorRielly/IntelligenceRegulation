#!/usr/bin/env python3
"""W16R2 at Q = q_pad = 280 (Victor's ruling on review F2, 2026-11-02): the soundness recount.

It re-runs the two EXISTING counting scripts of results/zk60_w16r2_20261101/ unchanged in their formulas:
  * count.py              (the builder's recount, exact rationals; ACCOUNTING.md)
  * accounting_recheck.py (the independent re-check, its own shape replica and log2 method)
with ONE input changed, Q = 280 for the three W16R2 profiles (both scripts carry Q as a per-profile constant),
and both check the code-printed `W16R2-ACCOUNTING` lines of
`private_block::w16r2_tests::w16r2_accounting_inputs_are_printed_from_the_code` against their own values when a
log is given (so a code that is not at Q = 280 fails here).

It then adds what F2 asked for, in count.py's own exact arithmetic (its `regular`, `per_block`, `MASK_*`):
  * the per-opening and whole-run figures at Q = 280 against W16 under the PROVEN-bound reading;
  * the same under the BEST-KNOWN-ATTACK reading (REVIEW_W16R2_20261102 F2): W16's rate-1/4 column term replaced
    by the close-case attack at its own unique-decoding radius, (1 - (e + 1)/N)^Q with e = floor((N - K)/2), every
    other term as counted (the M column term, the field terms, LogUp, sumcheck, zero-check);
  * a Q sweep, so the choice of 280 can be read against its neighbours.

Usage: python3 recount_q280.py [<log with W16R2-ACCOUNTING lines at Q = 280>]
"""
import importlib.util
import io
import math
import os
import sys
from contextlib import redirect_stdout
from fractions import Fraction as F

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(os.path.dirname(HERE), "zk60_w16r2_20261101")
Q_RULED = 280
W16R2 = ("W16R2_8B_T128_H24", "W16R2_SHIELD_T128_H24", "W16R2_RUNG_H24")


def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(SRC, name + ".py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def at_q(m, q, tuple_index):
    """the module's PROFILES with the W16R2 entries' Q set to q (no other value touched)"""
    for name in W16R2:
        v = list(m.PROFILES[name])
        v[tuple_index] = q
        m.PROFILES[name] = tuple(v)


def main():
    log = sys.argv[1] if len(sys.argv) > 1 else None
    argv = [sys.argv[0]] + ([log] if log else [])

    # ---- 1. the builder's count.py at Q = 280 (its PROFILES tuple: regime, n, inv_rate, Q, ...)
    c = load("count")
    at_q(c, Q_RULED, 3)
    print("=" * 100)
    print(f"count.py (results/zk60_w16r2_20261101/count.py), W16R2 Q = {Q_RULED}" + (f", inputs checked against {log}" if log else ", no log"))
    print("=" * 100)
    sys.argv = argv
    c.main()

    # ---- 2. the independent accounting_recheck.py at Q = 280 (its PROFILES tuple: regime, shape, inv_rate, Q, ...)
    r = load("accounting_recheck")
    at_q(r, Q_RULED, 3)
    print()
    print("=" * 100)
    print(f"accounting_recheck.py (independent; does not import count.py), W16R2 Q = {Q_RULED}")
    print("=" * 100)
    buf = io.StringIO()
    with redirect_stdout(buf):
        r.main()
    out = buf.getvalue()
    print(out)
    if log:
        assert "mismatches against the re-check's derivation: 0" in out, "the code-printed inputs do not match the re-check at Q = 280"

    # ---- 3. F2: both readings, exact arithmetic (count.py's own functions)
    lg = c.lg
    print("=" * 100)
    print("F2: the two readings, count.py's arithmetic")
    print("=" * 100)

    def opening(name, q=None, attack=False):
        v = c.PROFILES[name]
        regime, n, ir, q0 = v[0], v[1], v[2], v[3]
        q = q0 if q is None else q
        col, field = c.regular(regime, n, ir, q)
        if attack and regime == "delta/3":
            nn, k = n * ir, n + q
            e = (nn - k) // 2
            col = F(nn - e - 1, nn) ** q  # the close-case attack at W16's own unique-decoding radius
        return col, field

    def whole(name, l, q=None, attack=False):
        v = list(c.PROFILES[name])
        col, field = opening(name, q, attack)
        b = c.per_block(v)
        reg = 3 * l + 1
        t = {"column": reg * col + l * c.MASK_COL, "pcs_field": reg * field + l * c.MASK_FIELD, "logup": l * b["logup"], "sumcheck": l * b["sumcheck"], "zerocheck": l * b["zerocheck"]}
        return t, sum(t.values())

    pairs = [("W16R2_8B_T128_H24", "W16_8B_T128_H24", 32), ("W16R2_SHIELD_T128_H24", "W16_SHIELD_T128_H24", 26), ("W16R2_RUNG_H24", "W16_RUNG_H24", 1), ("W16R2_RUNG_H24", "W16_RUNG_H24", 3)]
    print("\n-- per regular opening (column; column + field), log2")
    col280, f280 = opening("W16R2_8B_T128_H24")
    col260, f260 = opening("W16R2_8B_T128_H24", q=260)
    colw, fw = opening("W16_8B_T128_H24")
    colwa, _ = opening("W16_8B_T128_H24", attack=True)
    print(f"   W16R2 Q 280 (delta/2, attained): column {lg(col280):.3f}; with field {lg(col280 + f280):.3f}")
    print(f"   W16R2 Q 260 (delta/2, attained): column {lg(col260):.3f}; with field {lg(col260 + f260):.3f}")
    print(f"   W16 Q 256, proven (delta/3):     column {lg(colw):.3f}; with field {lg(colw + fw):.3f}")
    print(f"   W16 Q 256, best known attack:    column {lg(colwa):.3f}; with field {lg(colwa + fw):.3f}")
    print("\n-- whole run (3L + 1 regular openings, L M openings, L blocks), log2; positive delta = W16R2 stronger")
    print(f"   {'profile':<24} {'L':>3} {'W16R2@280':>10} {'W16R2@260':>10} {'W16 proven':>11} {'W16 attack':>11} {'d proven':>9} {'d attack':>9}")
    res = {}
    for r2, w, l in pairs:
        a = lg(whole(r2, l)[1])
        a260 = lg(whole(r2, l, q=260)[1])
        wp = lg(whole(w, l)[1])
        wa = lg(whole(w, l, attack=True)[1])
        res[(r2, l)] = (a, a260, wp, wa)
        print(f"   {r2:<24} {l:>3} {a:>10.3f} {a260:>10.3f} {wp:>11.3f} {wa:>11.3f} {wp - a:>+9.3f} {wa - a:>+9.3f}")
    t, tot = whole("W16R2_8B_T128_H24", 32)
    print("   8B T128 L32 at Q 280, the terms: " + ", ".join(f"{k} {lg(x):.3f}" for k, x in t.items()) + f"; WHOLE {lg(tot):.3f}")
    t, tot = whole("W16_8B_T128_H24", 32, attack=True)
    print("   W16 8B T128 L32, attack reading, the terms: " + ", ".join(f"{k} {lg(x):.3f}" for k, x in t.items()) + f"; WHOLE {lg(tot):.3f}")

    print("\n-- Q sweep, 8B T128 L32 and Shieldstral T128 L26 (W16R2 whole run, log2), against W16's two readings")
    w8p, w8a = res[("W16R2_8B_T128_H24", 32)][2], res[("W16R2_8B_T128_H24", 32)][3]
    wsp, wsa = res[("W16R2_SHIELD_T128_H24", 26)][2], res[("W16R2_SHIELD_T128_H24", 26)][3]
    print(f"   W16 8B: proven {w8p:.3f}, attack {w8a:.3f}; W16 Shieldstral: proven {wsp:.3f}, attack {wsa:.3f}")
    for q in (256, 258, 259, 260, 265, 270, 275, 278, 279, 280, 281, 285, 290, 300, 400):
        e8 = lg(whole("W16R2_8B_T128_H24", 32, q=q)[1])
        es = lg(whole("W16R2_SHIELD_T128_H24", 26, q=q)[1])
        co, fi = opening("W16R2_8B_T128_H24", q=q)
        print(f"   Q {q:>3}: per opening column {lg(co):>9.3f} (+field {lg(co + fi):>9.3f}); 8B {e8:.3f} (vs attack {w8a - e8:+.3f}); Shieldstral {es:.3f} (vs attack {wsa - es:+.3f})")
    # the limit no Q passes: the column term of the regular openings -> 0
    lim = []
    for r2, w, l in pairs[:2]:
        v = list(c.PROFILES[r2])
        _, field = c.regular(v[0], v[1], v[2], v[3])
        b = c.per_block(v)
        reg = 3 * l + 1
        lim.append(lg(l * c.MASK_COL + reg * field + l * c.MASK_FIELD + l * b["logup"] + l * b["sumcheck"] + l * b["zerocheck"]))
    print(f"   Q -> infinity (regular column term 0, the rate-1/2 field term N/|Fp2| kept): 8B {lim[0]:.3f}, Shieldstral {lim[1]:.3f}")

    # ---- the assertions the hand-back states
    a8, a8_260, w8p, w8a = res[("W16R2_8B_T128_H24", 32)]
    assert abs(lg(col280) + 113.932) < 0.0005, lg(col280)
    assert abs(a8 + 97.779) < 0.0005 and abs(a8_260 + 97.361) < 0.0005, (a8, a8_260)
    assert abs(w8p + 97.269) < 0.0005 and abs(w8a + 97.783) < 0.0005, (w8p, w8a)
    assert a8 < w8p, "proven reading: W16R2 at 280 is not at least W16"
    assert 0 < a8 - w8a < 0.005, "attack reading: the gap at 280 is not the small field-term residual"
    assert lim[0] > w8a, "some Q would reach W16's attack-reading figure exactly"
    print("\nASSERTED: per opening 2^-113.932 at Q 280; 8B T128 whole run 2^-97.779 (2^-97.361 at Q 260); W16 2^-97.269 proven, 2^-97.783 attack;")
    print(f"          proven reading W16R2 stronger by {w8p - a8:+.3f} bit; attack reading W16R2 short by {a8 - w8a:.4f} bit, which no Q closes (limit {lim[0]:.3f})")


if __name__ == "__main__":
    main()
