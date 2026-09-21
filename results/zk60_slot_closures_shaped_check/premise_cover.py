"""Clause C4 in the strong form, for all 23 arms, COMPUTED rather than read.

The construction premise is `poly(exts) = 0`, where `exts` is zero in every
table position except the private tables of that extension round
(`argument.rs:353-360`).  The theorem needs it for EVERY value pi of those
positions, honest or not -- so the right statement is that `poly(exts)` is
the ZERO POLYNOMIAL in the pi, not that it vanishes on the honest ones.

This evaluates each arm's closure with

    every public table (Tab::Eq, Tab::Pub, every support indicator)  -> 0
    every private table NOT in the round under test                  -> 0
    every private table IN the round under test                      -> a
                                                                        fresh
                                                                        random
                                                                        Fp2

over several seeds and both extension rounds of the bilinear slots.  A
non-zero result at a random pi is a counterexample; zero at k independent
random pi bounds the chance that a non-zero polynomial survives by
(deg / |Fp2|)^k, which at deg <= 5 and |Fp2| = 2^128 is beyond any doubt.

The arms are re-ported from `argument.rs` at lane commit 8c5922b with the
public / private split written out per arm, and the NEGATIVE CONTROLS below
show the test is not vacuous.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fp2 import F2, ONE, ZERO, Rng  # noqa: E402


class Val:
    """a table value: `pub` marks it a public table (0 in `exts`)."""
    def __init__(self, x):
        self.x = x


def arm(slot, gate, pz, geq, n_lk, rng, ext_round, ext_total, break_bracket=False):
    """Return poly(exts) for slot `slot` at extension round `ext_round`.

    Every table is given its `exts` value directly: PUB -> 0, PRIV in this
    round -> random, PRIV in another round -> 0."""
    Z = ZERO

    def pub():
        return Z                                    # a public table in `exts`

    def priv(r=0):
        return rng.f2() if r == ext_round else Z    # a private table in `exts`

    def K():
        return rng.f2()                             # a challenge / constant

    def g():
        return pub() if gate else ONE               # Gate::at

    def pad(planes):
        """PadTerm::eval -- mu * (1 - supp) * sum_j zeta^j plane_j"""
        if not pz:
            return Z
        inner, p, zeta = Z, ONE, K()
        for t in planes:
            inner = inner + p * t
            p = p * zeta
        return K() * ((ONE - pub()) * inner)

    def helpers(n):
        acc = Z
        for k in range(-(-n // 2)):
            h = priv()
            d1 = K() - (K() + priv())
            if 2 * k + 1 < n:
                d2 = K() - (K() + priv())
                rel = h * d1 * d2 - (d1 + d2)
            else:
                rel = h * d1 - ONE
            acc = acc + K() * rel
        return acc

    if slot in (0, 1):
        return g() * pub() * priv() * priv()
    if slot == 2:
        d_, dsq = priv(), priv()
        zc = K() * (dsq - d_ * d_) + K() * (d_ - priv()) + K() * (d_ + d_ - priv() - priv())
        zc = zc + K() * (priv() - priv() * priv()) + K() * (priv() - priv())
        pzv = pad([priv(), priv(), priv(), priv()])
        body = pub() * (zc + pzv)
        if break_bracket:                 # control: pz OUTSIDE the eq bracket
            body = pub() * zc + pzv
        return body + K() * pub() * g() * (dsq + priv() - K()) + K() * pub() * g() * (priv() + priv() - K())
    if slot == 3:
        pzv = pad([priv(), priv()])
        body = pub() * (helpers(2) + pzv)
        if break_bracket:
            body = pub() * helpers(2) + pzv
        return body
    if slot == 4:
        return g() * pub() * (pub() * priv() + K() * priv())
    if slot in (5, 6, 7, 10, 11, 12, 13):
        return priv() * pub()
    if slot in (8, 9):
        x = priv(0)
        y = priv(1)
        ig = pub() if geq else ONE
        return ig * x * y
    if slot == 14:
        x, y, ao, x1, d_ = priv(), priv(), priv(), priv(), priv()
        nm, x2, z16, dm = priv(), priv(), priv(), priv()
        cs = [K() * pub() * x + K() * d_ - K() * y * d_ - priv(),
              priv() + priv() + ONE - K() * d_,
              x + K() - priv(), ao + K() - priv(), x1 + K() - priv(),
              x1 - x - ao,
              K() * pub() * x1 + K() * dm - K() * nm * dm - priv(),
              priv() + priv() + ONE - K() * dm,
              x2 + K() - priv(), x2 - x1 - z16, z16 + K() - priv()]
        pzv = pad([priv() for _ in range(6)])
        zc = helpers(n_lk) + pzv
        for c in cs:
            zc = zc + K() * g() * c
        body = pub() * zc
        if break_bracket:
            body = pub() * (zc - pzv) + pzv
        return body + K() * pub() * g() * (K() * ao + priv() - K()) \
                    + K() * pub() * g() * (K() * z16 + priv() - K())
    if slot == 18:
        g8, a16, u16, h16 = priv(), priv(), priv(), priv()
        f0 = a16 * u16 - K() * h16 - priv() + K()
        f1 = u16 + K() - priv()
        f2 = h16 + K() - priv()
        f_act = priv() * (K() - (g8 + K() + K() * a16 + K())) - ONE
        pzv = pad([priv() for _ in range(6)])
        zc = helpers(n_lk) + K() * f_act + pzv
        for c in (f0, f1, f2):
            zc = zc + K() * g() * c
        body = pub() * zc
        if break_bracket:
            body = pub() * (zc - pzv) + pzv
        return body + K() * pub() * g() * (K() * g8 + priv() - K()) + K() * pub() * g() * u16
    if slot in (15, 16):
        rope = pub() * priv() + pub() * priv() - K() * priv() - priv() + K()
        pzv = pad([priv() for _ in range(5)])
        zc = K() * g() * rope + helpers(n_lk) + pzv
        body = pub() * zc
        if break_bracket:
            body = pub() * (zc - pzv) + pzv
        return body + K() * pub() * g() * (K() * priv() + priv() - K()) \
                    + K() * pub() * g() * (K() * priv() + priv() - K())
    if slot == 17:
        mask, s8, zsel, e, p, sm = pub(), priv(), priv(), priv(), priv(), priv()
        imx, sr = priv(), priv()
        delta = imx - mask * (s8 + K()) + K()
        cs = [zsel * zsel - zsel, zsel * delta,
              K() * mask * e - p * sm - sr, priv() + sr + ONE - sm, p - priv()]
        cx = priv() * (K() - (delta + K() * e + K())) - ONE
        pzv = pad([imx, sm] + [priv() for _ in range(4)])
        zc = helpers(n_lk) + K() * cx + pzv
        for c in cs:
            zc = zc + K() * g() * c
        body = pub() * zc
        if break_bracket:
            body = pub() * (zc - pzv) + pzv
        return body + K() * pub() * g() * (sm + K()) + K() * pub() * g() * (K() * s8 + priv() - K())
    if slot == 19:
        rs = [priv() * (K() - pub()) - priv() for _ in range(3)]
        pzv = pad([priv() for _ in range(6)])
        body = pub() * (K() * rs[0] + K() * rs[1] + K() * rs[2] + pzv)
        if break_bracket:
            body = pub() * (K() * rs[0] + K() * rs[1] + K() * rs[2]) + pzv
        return body
    if slot == 20:
        return pub() * priv()
    if slot in (21, 22):
        return pub() * (priv() - priv())
    raise AssertionError(slot)


IND = {0: "D", 1: "D", 4: "S", 14: "D", 15: "Q", 16: "Kv", 17: "S", 18: "F"}
PZ = {2: ["T"], 3: ["L"], 14: ["D"], 15: ["Q"], 16: ["Kv"], 17: ["Ht", "S"], 18: ["F"], 19: ["Tab"]}
HELPDOM = {3: "L", 14: "D", 15: "Q", 16: "Kv", 17: "S", 18: "F"}
LANE = "/home/victor/wt-zk60-block125m/results/zk60_block125m_lane"


def main():
    res, fails, ctl_caught = {}, [], 0
    total = 0
    for name in ("toy", "rung_g", "rung_k4", "m125"):
        m = json.load(open(f"{LANE}/model_{name}.json"))
        padded = set(m["padded_domains"]) if name != "toy" else set()
        rows = []
        for s, sl in enumerate(m["slots"]):
            gate = IND.get(s) in padded
            pz = any(d in padded for d in PZ.get(s, []))
            geq = sl["group_sumcheck_bits"] > 0
            nlk = m["lookups"]["per_position"][HELPDOM[s]] if s in HELPDOM else 0
            ext = sl["extension_rounds"]
            ok = True
            for r in range(ext):
                for seed in range(6):
                    rng = Rng(0x0C4_00000 + 1000 * s + 17 * seed + r)
                    v = arm(s, gate, pz, geq, nlk, rng, r, ext)
                    total += 1
                    if not v.is_zero():
                        ok = False
                        fails.append((name, s, r, seed))
            # the negative control: the same arm with the pad-zero term moved
            # one bracket OUTWARDS (the memo's control C4)
            ctl = None
            if pz:
                rng = Rng(0xBAD_00000 + s)
                ctl = arm(s, gate, pz, geq, nlk, rng, 0, ext, break_bracket=True)
                ctl = not ctl.is_zero()
                ctl_caught += int(ctl)
            rows.append({"slot": s, "gated": gate, "pad_zero": pz,
                         "group_eq": geq, "ext_rounds": ext,
                         "premise_zero": ok,
                         "control_pz_outside_eq_breaks_it": ctl})
        res[name] = rows
    out = {"per_shape": res, "evaluations": total, "failures": fails,
           "controls_that_caught_the_break": ctl_caught}
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "premise_cover.json")
    json.dump(out, open(p, "w"), indent=1)
    n_arms = sum(len(v) for v in res.values())
    print(f"[COMPUTED] clause C4, poly(exts) = 0 at random pi: "
          f"{n_arms - len({(f[0], f[1]) for f in fails})}/{n_arms} "
          f"(slot, shape) arms over {total} evaluations")
    print(f"  failures: {fails}")
    print(f"  negative control (pad-zero term moved OUTSIDE the eq bracket) "
          f"makes the premise FALSE in {ctl_caught} of "
          f"{sum(1 for v in res.values() for r in v if r['pad_zero'])} pad-zero arms")


if __name__ == "__main__":
    main()
