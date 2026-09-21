#!/usr/bin/env python3
"""The sampler's good event: what a CONDITIONALLY UNIFORM good event costs.

Evidence for ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md, Part A (claims A-12,
A-13, finding F-1).

The project quotes 2^-96 per fp() draw (the total-variation distance between
the real draw and a uniform one; decision D9; D22's 2^-77.7 headline).

Ruling K-R4 of ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED_DISPOSITION.md accepted the
independent check's repair B-4: the coupling must be the REJECTION-REGION
coupling, because a maximal coupling's conditional law is not uniform and the
fixed-challenge theorem's hypothesis (H5) would not survive the conditioning.
The check wrote: "The number is unchanged: the memo's 2^-96 per draw is the
same r/2^128".

Ruling **K-R4a** (security owner, 2026-09-21 02:42) withdrew that first
sentence: the two numbers are not the same, and `B_samp` leaves the lemma's
flag -- the sampler idealisation stays a DISTANCE hop, taken before the lemma.

This script is an INDEPENDENT confirmation of K-R4a, written before it was
read, and it adds three things the ruling states in one line each:

    TV(real, uniform)    = r(p-r)/(p*2^128)  = 2^-96.000...
    Pr[rejection region] = r/2^128           = 2^-64.000...

  (1) the lower-bound proof: r/2^128 is a LOWER BOUND on the bad probability
      of ANY coupling whose good event carries an exactly uniform value, so
      2^-96 is simply not attainable in event form -- exhaustively confirmed
      on small analogues (section 3);
  (2) the closed-form criterion for when the hop beats the flag:
      2*TV < Pr[rej]  <=>  2(p - r) < p, which Goldilocks satisfies by 31
      bits and a small field need not (section 6);
  (3) an exact end-to-end adaptive model showing WHY the hop is legitimate
      under an arbitrary challenge schedule -- data processing on the
      randomness, which needs the draw positions to be schedule-determined
      (confirmed in stream_positions.py) (section 6).

Everything is exact (Fraction / int); floats appear only in printed log2.

Run:  python3 sampler_coupling.py
"""

from fractions import Fraction as Fr
import math

P = (1 << 64) - (1 << 32) + 1          # Goldilocks; zkp-core/src/field.rs:10
N = 1 << 128                           # fp() reduces a uniform 128-bit draw
K = N // P
R = N - K * P

# fp() draw counts of record (NOT salt draws: bytes32 is raw stream output).
COUNTS = {
    "toy block (D9, 327,052)": 327_052,
    "rung-G run, L=3 (H-6)": 2_093_340,
    "rung-K4 run, L=3 (H-6)": 2_283_876,
    "125M block (H-6)": 9_029_804,
    "125M run, L=12 (H-6)": 109_728_784,
}


def lg(x):
    """log2 of a positive Fraction without overflowing a float."""
    x = Fr(x)
    return math.log2(x.numerator) - math.log2(x.denominator)


def real_law(p, n):
    """Law of (U mod p) for U uniform on [0, n).  Exact.  Small p only."""
    k = n // p
    r = n - k * p
    return {v: Fr(k + 1, n) if v < r else Fr(k, n) for v in range(p)}


def tv_sum(p, n):
    """TV by the two-mass-class sum; never enumerates p points."""
    k = n // p
    r = n - k * p
    hi = abs(Fr(k + 1, n) - Fr(1, p)) * r
    lo = abs(Fr(k, n) - Fr(1, p)) * (p - r)
    return (hi + lo) / 2


def tv_closed_form(p, n):
    k = n // p
    r = n - k * p
    return Fr(r * (p - r), p * n)


def rejection_prob(p, n):
    k = n // p
    return Fr(n - k * p, n)


def min_uniform_component_bad(p, n):
    """Smallest possible bad probability over couplings whose good event
    carries an EXACTLY uniform value.

    Such a coupling is exactly a constant c >= 0 with Pr[X=v, good] = c for
    every v (conditional uniformity) and c <= real(v) (marginal feasibility).
    So Pr[bad] = 1 - p*c is minimised at c = min_v real(v) = k/n.
    """
    k = n // p
    return 1 - p * Fr(k, n)


def maximal_coupling_conditional(p, n):
    """Conditional law of the common value GIVEN AGREEMENT, maximal coupling,
    as the two mass classes (value, how many field points carry it).

    The point: this law is NOT uniform, which is the check's B-4 objection.
    """
    k = n // p
    r = n - k * p
    # min(real, uniform): on the r "heavy" points real > 1/p, so min = 1/p;
    # on the p-r "light" points real = k/n < 1/p, so min = k/n.
    mass = Fr(r, p) + Fr((p - r) * k, n)
    classes = [(Fr(1, p) / mass, r), (Fr(k, n) / mass, p - r)]
    return classes, mass


def brute_force_bad_bound(p, n, steps=None):
    """Exhaustive scan confirming min_uniform_component_bad on a tiny case."""
    law = real_law(p, n)
    steps = steps or (8 * n)
    best = Fr(1)
    for i in range(steps + 1):
        c = Fr(i, steps * p)
        if all(c <= law[v] for v in range(p)):
            best = min(best, 1 - p * c)
    return best


def line(s=""):
    print(s)


def main():
    line("=" * 78)
    line("1. The Goldilocks sampler, exactly")
    line("=" * 78)
    line(f"p        = {P}  = 2^64 - 2^32 + 1")
    line(f"N = 2^128")
    line(f"k = N//p = {K}")
    line(f"r = N-kp = {R}")
    line(f"p - r    = {P - R}  = 2^{int(math.log2(P - R))}   <- why TV is small")
    line()

    tv = tv_sum(P, N)
    tvc = tv_closed_form(P, N)
    assert tv == tvc, "closed form disagrees with the explicit sum"
    rej = rejection_prob(P, N)
    lower = min_uniform_component_bad(P, N)

    line(f"TV(real, uniform)            = {tv}")
    line(f"                             = 2^{lg(tv):.10f}     [COMPUTED]")
    line(f"Pr[rejection region U >= kp] = {rej}")
    line(f"                             = 2^{lg(rej):.10f}     [COMPUTED]")
    line(f"ratio  Pr[rej] / TV          = 2^{lg(rej) - lg(tv):.6f}")
    line()
    line(f"Smallest bad probability over ALL couplings with an exactly")
    line(f"uniform good event           = {lower}")
    line(f"                             = 2^{lg(lower):.10f}     [PROVED below]")
    assert lower == rej, "the rejection-region coupling is not optimal?!"
    line("  -> the rejection-region coupling is OPTIMAL under that constraint,")
    line("     and 2^-96 is NOT attainable with a conditionally uniform good event.")
    line()

    line("=" * 78)
    line("2. Why the maximal coupling fails (the check's B-4, reproduced)")
    line("=" * 78)
    classes, agree = maximal_coupling_conditional(P, N)
    line(f"Pr[agreement] = 1 - TV; 1 - Pr[agreement] = 2^{lg(1 - agree):.6f}")
    line(f"conditional law given agreement takes {len(set(c[0] for c in classes))}"
         " distinct values:")
    for v, cnt in classes:
        line(f"    value {v}   on {cnt:,} field points")
    line(f"uniform would be 1/p = {Fr(1, P)}")
    line("  -> NOT uniform. Hypothesis (H5) of the fixed-challenge theorem")
    line("     ('alpha uniform') does not survive conditioning on this good event.")
    line()

    line("=" * 78)
    line("3. The lower bound, checked exhaustively on small analogues")
    line("=" * 78)
    line(f"{'p':>5} {'N':>7} {'TV':>18} {'Pr[rej]':>18} {'brute-force min bad':>22}")
    for p, n in [(5, 16), (7, 32), (11, 64), (13, 128), (5, 1024), (17, 256)]:
        t = tv_closed_form(p, n)
        assert t == tv_sum(p, n)
        rr = rejection_prob(p, n)
        bf = brute_force_bad_bound(p, n)
        assert bf == rr, f"brute force {bf} != rejection {rr} at p={p}, N={n}"
        line(f"{p:>5} {n:>7} {str(t):>18} {str(rr):>18} {str(bf):>22}")
    line("  -> every instance: the exhaustive minimum equals Pr[rejection region],")
    line("     and is strictly larger than TV whenever p does not divide N.")
    line()

    line("=" * 78)
    line("4. What that does to the project's figures")
    line("=" * 78)
    line(f"{'artifact':<28} {'fp() draws':>14} {'union x TV':>14} "
         f"{'union x Pr[rej]':>16} {'gap':>8}")
    for name, d in COUNTS.items():
        a = tv * d
        b = rej * d
        line(f"{name:<28} {d:>14,} {'2^%.2f' % lg(a):>14} "
             f"{'2^%.2f' % lg(b):>16} {'%.1f bits' % (lg(b) - lg(a)):>8}")
    line()
    line("Reading:")
    line("  'union x TV'      is the accepted Route-A hop G_3->G_4 (a plain")
    line("                    distance hop; D22's 2^-77.7 and the run's 2^-69.3).")
    line("  'union x Pr[rej]' is what the sampler would cost IN EVENT FORM --")
    line("                    a flag off which the blinding is EXACTLY uniform")
    line("                    (K-R3's owed sentence as first drafted).")
    line()
    line("  The two differ by 32.0 bits.  The independent check's B-4 asserted")
    line("  they are the same number.  Ruling K-R4a (2026-09-21 02:42)")
    line("  withdraws that and keeps the sampler as a DISTANCE hop, which is")
    line("  the 'union x TV' column: D22's 2^-77.7 and the run's 2^-69.3 are")
    line("  unmoved, and B_samp leaves the flag.  This script agrees, and")
    line("  section 6 is the part the ruling states in one line.")
    line()

    line("=" * 78)
    line("5. Where the code's own comment sits")
    line("=" * 78)
    line("zkp-core/src/rng.rs:72 (at 8c5922b) reads:")
    line('    "A uniform base-field element (a 128-bit draw reduced mod p:'
         ' bias 2^-64)."')
    line(f"  2^-64 is Pr[rejection region] = 2^{lg(rej):.4f}, not the TV distance")
    line(f"  2^{lg(tv):.4f} the memos quote.  The comment is wrong for the number")
    line("  the project publishes and right for the number Route B needs.")
    line()

    line("=" * 78)
    line("6. The repair: take the sampler OUT of the flag and pay it as a hop")
    line("=" * 78)
    line("Exact end-to-end model.  p=5, N=16 (so TV=1/20, Pr[rej]=1/16), a")
    line("2-round protocol, two biased draws, challenges from a schedule, a")
    line("witness-dependent refusal in round 2.  Three bounds compared against")
    line("the TRUE adaptive distance, by exhaustive enumeration in exact")
    line("rationals over every challenge schedule.")
    line()
    run_hop_order_model(5, 16)
    line()
    line("  The same model at p=5, N=1024, where the ratio resembles"
         " Goldilocks:")
    run_hop_order_model(5, 1024)
    line()
    line("  THE CRITERION, in closed form:")
    line("    prior hop beats flag   <=>   2*TV < Pr[rej]")
    line("                           <=>   2*r(p-r)/(pN) < r/N")
    line("                           <=>   2(p-r) < p.")
    line(f"    Goldilocks: p - r = 2^32, p = 2^64 - 2^32 + 1, so 2(p-r) is")
    line(f"    2^31 times smaller than p: the prior hop wins by")
    line(f"    log2(Pr[rej]/(2 TV)) = {lg(rej) - lg(2 * tv):.3f} bits per draw.")
    line("    At p=5, N=16 the field is so small that 2(p-r) > p and the flag")
    line("    route is the better of the two -- printed so nobody reads the")
    line("    criterion as universal.")
    line()
    line("ALL ASSERTIONS PASSED.")


# ---------------------------------------------------------------------------
# Section 6: a complete small adaptive experiment.
# ---------------------------------------------------------------------------

SMALL_P = 5
SMALL_N = 16


def _draw_law(p, n):
    """Law on F_p of one biased draw, and of one uniform draw."""
    return real_law(p, n), {v: Fr(1, p) for v in range(p)}


def _protocol_view(w, omega, rho, p):
    """A 2-round (field, hash)-flavoured protocol, deterministic in (w, omega).

    omega = (b0, b1), the two blinding draws.
    Round 0 message:  m0 = w[0] + b0      (a one-time pad -- witness-free)
    challenge r0 = rho[0]
    Round 1 message:  m1 = w[1] + b1 + r0*w[0]
    Refusal (the witness-dependent class): refuse iff  b1 == w[1]  -- i.e. the
    refusal rule reads a hidden value, which is the LogUp-shaped class.
    Returns None on refusal (an accepted-receipts-only game, per D21 / M-9).
    """
    b0, b1 = omega
    if b1 == w[1]:
        return None
    m0 = (w[0] + b0) % p
    m1 = (w[1] + b1 + rho[0] * w[0]) % p
    return (m0, m1)


def _adaptive_law(w, draw_law, schedule, p):
    """Exact law of the view under a challenge SCHEDULE.

    schedule: a map from the round-0 message m0 to a challenge in F_p (this is
    the adaptive part: the challenge is a function of the prefix).
    """
    out = {}
    for b0 in range(p):
        for b1 in range(p):
            pr = draw_law[b0] * draw_law[b1]
            if pr == 0:
                continue
            m0 = (w[0] + b0) % p
            rho = (schedule[m0],)
            v = _protocol_view(w, (b0, b1), rho, p)
            out[v] = out.get(v, Fr(0)) + pr
    return out


def _tv(law_a, law_b):
    keys = set(law_a) | set(law_b)
    return sum(abs(law_a.get(k, Fr(0)) - law_b.get(k, Fr(0))) for k in keys) / 2


def run_hop_order_model(p=SMALL_P, n=SMALL_N):
    biased, unif = _draw_law(p, n)
    tv1 = tv_closed_form(p, n)
    rej1 = rejection_prob(p, n)
    n_draws = 2

    # every deterministic schedule m0 -> challenge, i.e. p^p of them
    schedules = []
    def build(prefix):
        if len(prefix) == p:
            schedules.append(tuple(prefix))
            return
        for c in range(p):
            build(prefix + [c])
    build([])

    # a fixed witness set: every pair of these is tested at every schedule
    witnesses = [(0, 0), (1, 2), (2, 4), (3, 1), (4, 3)]

    worst_true = Fr(0)
    worst_ideal = Fr(0)
    for sch in schedules:
        real = {w: _adaptive_law(w, biased, sch, p) for w in witnesses}
        ideal = {w: _adaptive_law(w, unif, sch, p) for w in witnesses}
        for i, w in enumerate(witnesses):
            for w2 in witnesses[i + 1:]:
                worst_true = max(worst_true, _tv(real[w], real[w2]))
                worst_ideal = max(worst_ideal, _tv(ideal[w], ideal[w2]))

    # the two bounds.  B_samp is a function of the STREAM only, so it is the
    # same event in both worlds and is NOT doubled; the hop route replaces the
    # randomness once per world, so its TV IS doubled.
    bound_flag = n_draws * rej1 + worst_ideal        # sampler inside the flag
    bound_hop = 2 * n_draws * tv1 + worst_ideal      # sampler as a prior hop
    line(f"  instance p={p}, N={n}: TV={tv1}, Pr[rej]={rej1}")
    line(f"  schedules enumerated               : {len(schedules)}")
    line(f"  witness pairs per schedule         : {len(witnesses)*(len(witnesses)-1)//2}")
    line(f"  TRUE worst adaptive distance (real): {worst_true}  "
         f"= {float(worst_true):.6f}")
    line(f"  worst adaptive distance (ideal)    : {worst_ideal}  "
         f"= {float(worst_ideal):.6f}")
    line(f"    (nonzero: the witness-dependent refusal, priced separately)")
    line(f"  bound A, sampler INSIDE the flag   : n*Pr[rej] + ideal "
         f"= {bound_flag} = {float(bound_flag):.6f}")
    line(f"  bound B, sampler as a PRIOR hop    : 2n*TV   + ideal "
         f"= {bound_hop} = {float(bound_hop):.6f}")
    assert worst_true <= bound_hop, "data-processing bound violated!"
    assert worst_true <= bound_flag, "flag bound violated!"
    winner = "PRIOR HOP" if bound_hop < bound_flag else "FLAG"
    line(f"  both bounds hold.  Smaller here: {winner}.")
    return bound_flag, bound_hop


if __name__ == "__main__":
    main()
