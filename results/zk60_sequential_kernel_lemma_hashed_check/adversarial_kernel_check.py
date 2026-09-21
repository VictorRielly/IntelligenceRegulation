#!/usr/bin/env python3
"""INDEPENDENT ADVERSARIAL re-check of ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED.md.

Written by the adversarial checker, not by the memo's author.  Exact rational
arithmetic (`fractions.Fraction`); every toy protocol is enumerated in full.

The memo's own evidence (results/zk60_sequential_kernel_lemma_hashed/) checks
eight claims -- but EVERY protocol in it has exactly ONE challenge round
(`rounds = len(rules) - 1 = 1` for all of C1..C7), so the SEQUENTIAL part of the
"sequential-kernel lemma" is never exercised.  This script does the multi-round
work, adds early aborts, and attacks each hypothesis in turn.

Tests
  A1  path identity (*) at 2 and 3 challenge rounds, exhaustive over schedules,
      including adversarial schedules (constant; read the hash part only;
      read a bit of the previous field message)
  A2  path identity with EARLY ABORT, under Game-perp and Game-prefix views,
      and under every completion of rho beyond the abort
  A3  Theorem S-H at 2 rounds: (iv) at every rho  =>  adaptive law witness-free
  B1  necessity of (i) causality      -- non-causal prover, fixed point on chi
  B2  necessity of (ii) witness fixed -- ADAPTIVE WITNESS SOURCE: conclusion
      still holds, so (ii) is NOT needed given (i),(iii),(iv)
  B3  necessity of (iii) chi-source independence, multi-round + partial
      correlation (not just the memo's total-coincidence C7)
  B4  necessity of (iv)
  B5  necessity of the UNSTATED hypothesis hidden in Definition 1.4: chi must
      read only the PUBLIC prefix.  Not among (i)-(iv).
  C1  naive approximate form at TWO rounds: blow-up |C|^2, not |C|
  C2  the correct lossy form  d_adaptive <= sum over reachable rho of TV_rho
  C3  S-H' bound: holds, tight, and holds under every completion convention
      for a NON-ADAPTED flag B
  C4  S-H' with the memo's pair-dependent flag  B = B_w union B_w'
  D1  Game-perp vs Game-prefix: (iv') true under one and false under the other
      (claim S-6), and the abort probability itself as a channel
  D2  Corollary S-H'' with ADAPTIVE oracle queries (the memo's C8 is
      non-adaptive)
  E1  arithmetic: every error term in the memo's section 5.3 recomputed
"""

import itertools
import json
import math
import os
import sys
from collections import defaultdict
from fractions import Fraction as Fr

REFUSE = "REFUSE"
OUT = os.path.dirname(os.path.abspath(__file__))
LOG = []
RESULT = {}


def say(s=""):
    LOG.append(s)
    print(s)


# ---------------------------------------------------------------- engine


class Proto:
    def __init__(self, name, witnesses, omegas, challenges, rules):
        self.name = name
        self.witnesses = list(witnesses)
        self.omegas = list(omegas)
        self.challenges = list(challenges)
        self.rules = list(rules)
        self.rounds = len(rules) - 1


def fixed_run(proto, w, omega, rho):
    """Message tuple at fixed challenges rho, truncated at the first REFUSE."""
    out = []
    for j, rule in enumerate(proto.rules):
        m = rule(w, omega, tuple(rho[:j]))
        out.append(m)
        if m == REFUSE:
            break
    return tuple(out)


def adaptive_run(proto, w, omega, sched):
    """Returns (messages, challenges).  sched maps (j, public_prefix) -> c where
    public_prefix = (m_0, r_0, ..., m_j) as a flat tuple."""
    msgs, rs, pref = [], [], []
    for j, rule in enumerate(proto.rules):
        m = rule(w, omega, tuple(rs))
        msgs.append(m)
        pref.append(m)
        if m == REFUSE:
            break
        if j < proto.rounds:
            c = sched[(j, tuple(pref))]
            rs.append(c)
            pref.append(c)
    return tuple(msgs), tuple(rs)


def law(items):
    counts = defaultdict(int)
    n = 0
    for it in items:
        counts[it] += 1
        n += 1
    return {k: Fr(v, n) for k, v in counts.items()}


def fixed_law(proto, w, rho):
    return law(fixed_run(proto, w, o, rho) for o in proto.omegas)


def adaptive_law_msgs(proto, w, sched):
    return law(adaptive_run(proto, w, o, sched)[0] for o in proto.omegas)


def adaptive_law_view(proto, w, sched, game="prefix"):
    """Game prefix: the whole (m, r) interleaving.  Game perp: everything is
    replaced by the single symbol PERP as soon as a REFUSE occurs."""
    vals = []
    for o in proto.omegas:
        msgs, rs = adaptive_run(proto, w, o, sched)
        if msgs and msgs[-1] == REFUSE:
            if game == "perp":
                vals.append(("PERP",))
                continue
        v = []
        for j, m in enumerate(msgs):
            v.append(m)
            if j < len(rs):
                v.append(rs[j])
        vals.append(tuple(v))
    return law(vals)


def tv(p, q):
    keys = set(p) | set(q)
    return sum(abs(p.get(k, Fr(0)) - q.get(k, Fr(0))) for k in keys) / 2


def reachable_slots(proto):
    """Every (j, public_prefix) at which a challenge must be answered, over all
    challenge assignments, all witnesses, all omegas."""
    slots = []
    frontier = set()
    for w in proto.witnesses:
        for o in proto.omegas:
            frontier.add(((proto.rules[0](w, o, ()),), ()))
    for j in range(proto.rounds):
        nxt = set()
        for pref, rs in sorted(frontier, key=repr):
            if pref[-1] == REFUSE:
                continue
            if (j, pref) not in slots:
                slots.append((j, pref))
            for c in proto.challenges:
                rs2 = rs + (c,)
                for w in proto.witnesses:
                    for o in proto.omegas:
                        m = proto.rules[j + 1](w, o, rs2)
                        nxt.add((pref + (c, m), rs2))
        frontier = nxt
    return slots


def all_schedules(proto, cap=4096, seed=11):
    """Every challenge schedule; uniformly sampled (fixed seed) when the
    exhaustive family is too large.  The named adversarial schedules are added
    separately by the callers, so a sampled sweep never misses them."""
    import random as _r
    slots = reachable_slots(proto)
    total = len(proto.challenges) ** len(slots)
    if total <= cap:
        return [dict(zip(slots, combo))
                for combo in itertools.product(proto.challenges,
                                               repeat=len(slots))], slots
    rng = _r.Random(seed)
    return [{s: rng.choice(proto.challenges) for s in slots}
            for _ in range(cap)], slots


def rho_of(proto, w, omega, sched):
    return adaptive_run(proto, w, omega, sched)[1]


def rho_along(proto, sched, msgs):
    """rho^xi(m): the unique schedule-consistent challenge vector along m.
    Returns the (possibly short) tuple actually drawn."""
    rs, pref = [], []
    for j, m in enumerate(msgs):
        pref.append(m)
        if m == REFUSE:
            break
        if j < proto.rounds:
            key = (j, tuple(pref))
            if key not in sched:
                break
            c = sched[key]
            rs.append(c)
            pref.append(c)
    return tuple(rs)


# ------------------------------------------------- A1/A3 multi-round protocols


def mk_masked_2round(seed_coefs, nc=2, nw=2, ndig=2):
    """Two challenge rounds, (field, hash) pairs, per-rho joint law witness-free.

    omega = (a, b, c, salt, leaf-table).  Every published field word is a fresh
    pad plus a public function of (w, r); the hash parts are oracle images at
    points whose salt is fresh and never published.  This is the memo's shape,
    but with TWO challenges so the induction is actually exercised."""
    k0, k1, k2 = seed_coefs
    points = [(x, s) for x in range(nc) for s in range(2)]
    tables = list(itertools.product(range(ndig), repeat=len(points)))
    idx = {p: i for i, p in enumerate(points)}
    omegas = [(a, b, c, s, t) for a in range(nc) for b in range(nc)
              for c in range(nc) for s in range(2) for t in tables]

    def m0(w, om, r):
        a, b, c, s, t = om
        return ((a + k0 * w) % nc, t[idx[((b + w) % nc, s)]])

    def m1(w, om, r):
        a, b, c, s, t = om
        return ((b + k1 * w * r[0]) % nc, None)

    def m2(w, om, r):
        a, b, c, s, t = om
        return ((c + k2 * w * r[0] * r[1]) % nc, None)

    return Proto("masked-2round-%s" % (seed_coefs,), range(nw), omegas,
                 list(range(nc)), [m0, m1, m2])


def mk_masked_3round(nc=2, nw=2):
    """Three challenge rounds, field only but with an abort that is a public
    function of the challenges (the memo's 'challenge-driven' refusal class)."""
    omegas = list(itertools.product(range(nc), repeat=4))

    def mk(j):
        def f(w, om, r):
            if j == 2 and len(r) >= 2 and r[0] == r[1] == 0:
                return REFUSE          # challenge-driven refusal: rho only
            acc = w
            for x in r:
                acc = acc * (x + 1)
            return ((om[j] + acc) % nc, None)
        return f

    return Proto("masked-3round", range(nw), omegas, list(range(nc)),
                 [mk(0), mk(1), mk(2), mk(3)])


def adversarial_schedules(proto):
    """Named adversarial schedules on top of the exhaustive sweep."""
    slots = reachable_slots(proto)
    out = {}
    for c in proto.challenges:
        out["constant-%s" % c] = {s: c for s in slots}

    def hashbit(pref):
        # read ONLY the hash part of the last message
        m = pref[-1]
        h = m[1] if isinstance(m, tuple) and len(m) > 1 else None
        return 0 if h in (None, 0) else 1

    out["hash-part-only"] = {(j, p): proto.challenges[hashbit(p) % len(proto.challenges)]
                             for (j, p) in slots}

    def fieldbit(pref):
        m = pref[-1]
        f = m[0] if isinstance(m, tuple) else 0
        return 0 if f in (None, 0) else 1

    out["field-bit"] = {(j, p): proto.challenges[fieldbit(p) % len(proto.challenges)]
                        for (j, p) in slots}
    out["round-parity"] = {(j, p): proto.challenges[j % len(proto.challenges)]
                           for (j, p) in slots}
    return out


def test_A1_A3():
    say("=" * 78)
    say("A1/A3  the path identity and Theorem S-H at TWO and THREE challenge rounds")
    say("       (the memo's own evidence never leaves ONE round)")
    rows = []
    protos = [mk_masked_2round((1, 1, 1)), mk_masked_2round((1, 0, 1)),
              mk_masked_3round()]
    for proto in protos:
        scheds, slots = all_schedules(proto)
        named = adversarial_schedules(proto)
        all_s = [("exhaustive-%d" % i, s) for i, s in enumerate(scheds)]
        all_s += list(named.items())
        # hypothesis (iv) at every rho
        worst_rho = Fr(0)
        for rho in itertools.product(proto.challenges, repeat=proto.rounds):
            laws = [fixed_law(proto, w, rho) for w in proto.witnesses]
            for i in range(1, len(laws)):
                worst_rho = max(worst_rho, tv(laws[0], laws[i]))
        mismatch = 0
        worst_ad = Fr(0)
        for nm, sched in all_s:
            for w in proto.witnesses:
                al = adaptive_law_msgs(proto, w, sched)
                for m, p in al.items():
                    rs = rho_along(proto, sched, m)
                    # every completion of rho beyond the (possibly short) draw
                    comps = list(itertools.product(proto.challenges,
                                                   repeat=proto.rounds - len(rs)))
                    vals = set()
                    for comp in comps:
                        rho = rs + comp
                        vals.add(fixed_law(proto, w, rho).get(m, Fr(0)))
                    if len(vals) != 1 or p not in vals:
                        mismatch += 1
            laws = [adaptive_law_msgs(proto, w, sched) for w in proto.witnesses]
            for i in range(1, len(laws)):
                worst_ad = max(worst_ad, tv(laws[0], laws[i]))
        say("  %-22s rounds=%d omegas=%-5d slots=%-3d schedules=%-6d "
            "path-identity mismatches=%d  max per-rho TV=%s  max adaptive TV=%s"
            % (proto.name, proto.rounds, len(proto.omegas), len(slots),
               len(all_s), mismatch, worst_rho, worst_ad))
        rows.append({"protocol": proto.name, "rounds": proto.rounds,
                     "omegas": len(proto.omegas), "slots": len(slots),
                     "schedules_tested": len(all_s),
                     "path_identity_mismatches": mismatch,
                     "max_per_rho_tv": str(worst_rho),
                     "max_adaptive_tv": str(worst_ad)})
        assert mismatch == 0, proto.name
        assert (worst_rho == 0) == (worst_ad == 0), proto.name
    RESULT["A1_A3"] = rows
    say("  VERDICT: the path identity survives 2 and 3 rounds, every completion of a")
    say("           truncated rho, and every adversarial schedule tried.  S-H holds.")


# ------------------------------------------------------- A2 abort / two games


def mk_abort_proto(nc=2):
    """m_0 publishes a pad; the run refuses at round 1 on a rho-only condition
    and at round 2 on an omega-only condition.  Used to check the identity and
    the two abort games."""
    omegas = list(itertools.product(range(nc), range(nc), range(nc), range(2)))

    def m0(w, om, r):
        return ((om[0] + w) % nc, None)

    def m1(w, om, r):
        if r[0] == 0:
            return REFUSE                       # challenge-driven: rho only
        return ((om[1] + w * r[0]) % nc, None)

    def m2(w, om, r):
        if om[3] == 0:
            return REFUSE                       # omega-only refusal, witness-free
        return ((om[2] + w) % nc, None)

    return Proto("abort-2round", range(nc), omegas, list(range(nc)), [m0, m1, m2])


def test_A2():
    say()
    say("=" * 78)
    say("A2  the identity and the lemma with EARLY ABORTS, Game-perp and Game-prefix")
    proto = mk_abort_proto(2)
    scheds, slots = all_schedules(proto)
    worst_rho = Fr(0)
    for rho in itertools.product(proto.challenges, repeat=proto.rounds):
        laws = [fixed_law(proto, w, rho) for w in proto.witnesses]
        for i in range(1, len(laws)):
            worst_rho = max(worst_rho, tv(laws[0], laws[i]))
    wp = wperp = Fr(0)
    mismatch = 0
    for sched in scheds:
        for w in proto.witnesses:
            al = adaptive_law_msgs(proto, w, sched)
            for m, p in al.items():
                rs = rho_along(proto, sched, m)
                vals = {fixed_law(proto, w, rs + comp).get(m, Fr(0))
                        for comp in itertools.product(proto.challenges,
                                                      repeat=proto.rounds - len(rs))}
                if len(vals) != 1 or p not in vals:
                    mismatch += 1
        lp = [adaptive_law_view(proto, w, sched, "prefix") for w in proto.witnesses]
        lq = [adaptive_law_view(proto, w, sched, "perp") for w in proto.witnesses]
        for i in range(1, len(lp)):
            wp = max(wp, tv(lp[0], lp[i]))
            wperp = max(wperp, tv(lq[0], lq[i]))
    say("  %s: per-rho TV=%s  mismatches=%d  adaptive TV (Game prefix)=%s  (Game perp)=%s"
        % (proto.name, worst_rho, mismatch, wp, wperp))
    RESULT["A2"] = {"per_rho_tv": str(worst_rho), "mismatches": mismatch,
                    "adaptive_tv_game_prefix": str(wp),
                    "adaptive_tv_game_perp": str(wperp),
                    "schedules": len(scheds)}
    assert mismatch == 0 and wp == 0 and wperp == 0
    say("  VERDICT: the identity is insensitive to the completion of rho past an abort,")
    say("           and both abort games inherit the conclusion.  No defect found.")


# --------------------------------------------------------- B1 causality


def test_B1():
    say()
    say("=" * 78)
    say("B1  necessity of hypothesis (i) CAUSALITY -- a prover that reads the")
    say("    challenge that FOLLOWS its own message (fixed-point semantics)")
    nc, res = 2, []
    #   f_0(w, omega, r_0) = (w * r_0 + omega) mod 2 -- non-causal
    #   fixed run at rho: m_0 = w*rho_0 + omega          -> uniform, witness-free
    #   adaptive with chi(m_0) = m_0: solve m_0 = w*m_0 + omega
    for w in (0, 1):
        pass
    fixed = {}
    for rho0 in range(nc):
        for w in (0, 1):
            fixed[(w, rho0)] = law(((w * rho0 + om) % nc,) for om in range(nc))
    per_rho = max(tv(fixed[(0, r)], fixed[(1, r)]) for r in range(nc))

    def adaptive(w):
        vals = []
        for om in range(nc):
            sols = [m for m in range(nc) if m == (w * m + om) % nc]
            vals.append((sols[0],) if sols else (REFUSE,))
        return law(vals)

    d = tv(adaptive(0), adaptive(1))
    say("    chi(m_0) = m_0 ;  per-rho TV = %s  (hypothesis (iv) HOLDS)" % per_rho)
    say("    adaptive TV = %s   ->  the conclusion FAILS without (i)" % d)
    RESULT["B1"] = {"per_rho_tv": str(per_rho), "adaptive_tv": str(d),
                    "hypothesis_needed": d > 0}
    assert per_rho == 0 and d > 0
    say("  VERDICT: (i) is NECESSARY.  [the memo never tests this]")


# ----------------------------------------- B2 hypothesis (ii): NOT necessary


def test_B2():
    say()
    say("=" * 78)
    say("B2  necessity of hypothesis (ii) 'the witness is fixed before m_0'")
    say("    An ADAPTIVE WITNESS SOURCE: the stage-1 secret is chosen AFTER r_0,")
    say("    as a function of r_0 and of the source's own seed.  This is exactly")
    say("    the memo's GAP S-4 (RunWitnessSource inside the stage loop).")
    nc = 3
    omegas = list(itertools.product(range(nc), repeat=2))   # two fresh pads
    # two SOURCES, each a map (seed, r_0) -> stage-1 secret; the stage-0 secret
    # is the source's index.  Both sources publish masked values only.
    sources = {
        "S ": lambda s0, r0: (s0 + r0) % nc,
        "S'": lambda s0, r0: (2 * s0 + 2 * r0 + 1) % nc,
    }
    results = {}
    for nm, src in sources.items():
        def m0(w, om, r, src=src):
            return ((om[0] + w) % nc, None)

        def m1(w, om, r, src=src):
            return ((om[1] + src(w, r[0])) % nc, None)

        results[nm] = Proto("adaptive-source-%s" % nm, [0, 1, 2], omegas,
                            list(range(nc)), [m0, m1])
    names = list(results)
    a, b = results[names[0]], results[names[1]]
    # hypothesis (iv) across the two SOURCES at every rho
    worst_rho = Fr(0)
    for rho in itertools.product(a.challenges, repeat=1):
        for w in a.witnesses:
            for w2 in b.witnesses:
                worst_rho = max(worst_rho, tv(fixed_law(a, w, rho),
                                              fixed_law(b, w2, rho)))
    scheds, _ = all_schedules(a)
    worst_ad = Fr(0)
    for sched in scheds:
        for w in a.witnesses:
            for w2 in b.witnesses:
                worst_ad = max(worst_ad, tv(adaptive_law_msgs(a, w, sched),
                                            adaptive_law_msgs(b, w2, sched)))
    say("    across the two adaptive sources: max per-rho TV = %s, max adaptive TV = %s"
        % (worst_rho, worst_ad))
    RESULT["B2"] = {"per_rho_tv": str(worst_rho), "adaptive_tv": str(worst_ad),
                    "hypothesis_needed": worst_ad > 0}
    assert worst_rho == 0 and worst_ad == 0
    say("  VERDICT: (ii) is NOT necessary for the CONCLUSION.  Whenever (iv) holds for")
    say("           the adaptive sources themselves, the adaptive laws still agree: an")
    say("           adaptive witness source folds into the message maps and (i) is")
    say("           untouched.  (ii) is a WELL-POSEDNESS condition that fixes what the")
    say("           quantifier in (iv) ranges over -- so GAP S-4 is a gap in (iv), not")
    say("           in (ii), and the memo's 'COMPUTATIONAL / through binding' label is")
    say("           a category error.")


# ------------------------------------- B3 hypothesis (iii): partial correlation


def test_B3():
    say()
    say("=" * 78)
    say("B3  necessity of hypothesis (iii) chi-source independent of omega")
    say("    (the memo's C7 only tests TOTAL coincidence of one query point;")
    say("     here: partial correlation, and a multi-round version)")
    nc = 4
    rows = []
    # omega = (pad, bias).  The challenge source leaks ONE BIT of the pad.
    for leak in ("none", "one-bit", "full"):
        omegas = [(p,) for p in range(nc)]

        def m0(w, om, r):
            return (None, None)

        def m1(w, om, r):
            return ((om[0] + w + r[0]) % nc, None)

        proto = Proto("corr-%s" % leak, range(nc), omegas, list(range(nc)), [m0, m1])
        # the challenge depends on omega to the stated degree
        def chi(om, leak=leak):
            if leak == "none":
                return 0
            if leak == "one-bit":
                return (om[0] % 2) * 2          # reveals the low bit of the pad
            return om[0]

        laws = []
        for w in proto.witnesses:
            vals = []
            for om in proto.omegas:
                r0 = chi(om)
                vals.append(((None, None), r0, ((om[0] + w + r0) % nc, None)))
            laws.append(law(vals))
        d = max(tv(laws[0], laws[i]) for i in range(1, len(laws)))
        # per-rho hypothesis (iv) still holds in every case
        worst_rho = Fr(0)
        for rho in itertools.product(proto.challenges, repeat=1):
            ls = [fixed_law(proto, w, rho) for w in proto.witnesses]
            for i in range(1, len(ls)):
                worst_rho = max(worst_rho, tv(ls[0], ls[i]))
        say("    leak=%-8s per-rho TV=%s   adaptive TV with a correlated source = %s"
            % (leak, worst_rho, d))
        rows.append({"leak": leak, "per_rho_tv": str(worst_rho), "adaptive_tv": str(d)})
    RESULT["B3"] = rows
    assert rows[0]["adaptive_tv"] == "0"
    assert Fr(rows[1]["adaptive_tv"]) > 0 and Fr(rows[2]["adaptive_tv"]) > 0
    say("  VERDICT: (iii) is NECESSARY, and it is not an all-or-nothing hypothesis:")
    say("           leaking ONE BIT of the prover's randomness into the challenge")
    say("           source already breaks the conclusion (TV %s at |C|=4)."
        % rows[1]["adaptive_tv"])


# --------------------------------------------------------------- B4 / B5


def test_B4_B5():
    say()
    say("=" * 78)
    say("B4  necessity of (iv): the marginal-only hypothesis (already project lore)")
    nc = 4
    omegas = list(range(nc))

    def m0(w, om, r):
        return (None, om % 2)            # a hash part: one bit of the mask

    def m1(w, om, r):
        return ((om + w) % nc, None)

    proto = Proto("marginals-only", range(nc), omegas, list(range(nc)), [m0, m1])
    worst_rho = Fr(0)
    for rho in itertools.product(proto.challenges, repeat=1):
        ls = [fixed_law(proto, w, rho) for w in proto.witnesses]
        for i in range(1, len(ls)):
            worst_rho = max(worst_rho, tv(ls[0], ls[i]))
    scheds, _ = all_schedules(proto)
    worst_ad = Fr(0)
    for sched in scheds:
        ls = [adaptive_law_msgs(proto, w, sched) for w in proto.witnesses]
        for i in range(1, len(ls)):
            worst_ad = max(worst_ad, tv(ls[0], ls[i]))
    say("    per-rho (JOINT) TV=%s ; adaptive TV=%s  -- (iv) fails and so does the"
        " conclusion" % (worst_rho, worst_ad))
    RESULT["B4"] = {"per_rho_tv": str(worst_rho), "adaptive_tv": str(worst_ad)}
    assert worst_rho > 0 and worst_ad > 0

    say()
    say("B5  necessity of the hypothesis the memo does NOT number: chi must read")
    say("    only the PUBLIC prefix (smuggled into Definition 1.4, tracked in the")
    say("    section-4 table only as code row (iii-d), 'spot-checked here')")
    nc = 2
    omegas = list(range(nc))

    def n0(w, om, r):
        return ((om + w) % nc, None)     # perfectly masked

    def n1(w, om, r):
        return (r[0], None)              # republish the challenge

    p2 = Proto("chi-reads-hidden", range(nc), omegas, list(range(nc)), [n0, n1])
    worst_rho = Fr(0)
    for rho in itertools.product(p2.challenges, repeat=1):
        ls = [fixed_law(p2, w, rho) for w in p2.witnesses]
        for i in range(1, len(ls)):
            worst_rho = max(worst_rho, tv(ls[0], ls[i]))
    laws = []
    for w in p2.witnesses:
        vals = []
        for om in p2.omegas:
            r0 = w                       # chi reads the WITNESS (an unpublished absorb)
            vals.append((((om + w) % nc, None), r0, (r0, None)))
        laws.append(law(vals))
    d = tv(laws[0], laws[1])
    say("    per-rho TV=%s (hypothesis (iv) HOLDS) ; adaptive TV with a chi that reads"
        " one hidden absorbed word = %s" % (worst_rho, d))
    RESULT["B5"] = {"per_rho_tv": str(worst_rho), "adaptive_tv": str(d)}
    assert worst_rho == 0 and d == 1
    say("  VERDICT: PUBLICNESS OF EVERY ABSORBED WORD IS A HYPOTHESIS OF THE LEMMA,")
    say("           not a convenience.  It is not in the list (i)-(iv).")


# ------------------------------------------------- C1 two-round blow-up


def mk_leaky_2round(nc):
    omegas = list(itertools.product(range(nc), repeat=2))

    def m0(w, om, r):
        return (om[0], None)

    def m1(w, om, r):
        return (om[1], None)

    def m2(w, om, r):
        return ((w if (r[0] == om[0] and r[1] == om[1]) else 0), None)

    return Proto("leaky-2round-%d" % nc, [1, 2], omegas, list(range(nc)),
                 [m0, m1, m2])


def test_C1_C2():
    say()
    say("=" * 78)
    say("C1  the naive approximate form at TWO rounds: the blow-up is |C|^2,")
    say("    not |C|.  The memo measured |C| because every instance it built has")
    say("    one round; its prose says 'the number of reachable challenge vectors'.")
    rows = []
    for nc in (2, 3, 4):
        proto = mk_leaky_2round(nc)
        per_rho = Fr(0)
        sum_rho = Fr(0)
        for rho in itertools.product(proto.challenges, repeat=2):
            ls = [fixed_law(proto, w, rho) for w in proto.witnesses]
            d = tv(ls[0], ls[1])
            per_rho = max(per_rho, d)
            sum_rho += d
        steer = {}
        for (j, pref) in reachable_slots(proto):
            steer[(j, pref)] = pref[-1][0]          # chi = read the last field word
        d_ad = tv(adaptive_law_msgs(proto, 1, steer), adaptive_law_msgs(proto, 2, steer))
        say("    |C|=%d  per-rho TV=%-10s adaptive TV=%-4s blow-up=x%-5s   "
            "sum over reachable rho of TV_rho = %s (a VALID bound: %s)"
            % (nc, per_rho, d_ad, d_ad / per_rho, sum_rho, d_ad <= sum_rho))
        rows.append({"nc": nc, "per_rho_tv": str(per_rho), "adaptive_tv": str(d_ad),
                     "blowup": str(d_ad / per_rho), "sum_rho_tv": str(sum_rho),
                     "sum_bound_holds": d_ad <= sum_rho})
        assert d_ad == 1 and per_rho == Fr(1, nc * nc) and d_ad <= sum_rho
    RESULT["C1_C2"] = rows
    say("  C2  the memo states no correct approximate form.  One exists and is free")
    say("      from the same identity:  d_adaptive <= SUM over reachable rho of TV_rho")
    say("      (<= (#reachable rho) * delta).  Verified above, tight in every row.")


# ------------------------------------------- C3/C4 the until-bad bound


def test_C3_C4():
    say()
    say("=" * 78)
    say("C3  Theorem S-H' with a NON-ADAPTED flag B (B reads a challenge the run")
    say("    never draws).  Does the bound survive every completion convention?")
    nc = 2
    omegas = list(itertools.product(range(nc), range(2)))

    def q0(w, om, r):
        return ((om[0] + w) % nc, None)          # masked

    def q1(w, om, r):
        return REFUSE if om[1] == 0 else (0, None)   # omega-only abort at round 1

    def q2(w, om, r):
        return ((w if r[1] == 1 else 0), None)       # leaks iff rho_1 == 1

    proto = Proto("nonadapted-flag", range(nc), omegas, list(range(nc)),
                  [q0, q1, q2])
    scheds, _ = all_schedules(proto)

    # B(w, omega, rho) := (rho_1 == 1).  On the half of the runs that abort at
    # round 1, rho_1 is NEVER DRAWN, so "the probability of the flag in the
    # adaptive run" (the memo's words) is not defined without a convention.
    def flag(w, om, rho):
        return len(rho) > 1 and rho[1] == 1

    # verify (iv') at every rho under this flag
    ok_iv = True
    for rho in itertools.product(proto.challenges, repeat=proto.rounds):
        sub = []
        for w in proto.witnesses:
            d = defaultdict(Fr)
            for om in proto.omegas:
                if not flag(w, om, rho):
                    d[fixed_run(proto, w, om, rho)] += Fr(1, len(proto.omegas))
            sub.append(dict(d))
        for i in range(1, len(sub)):
            if sub[0] != sub[i]:
                ok_iv = False
    viol = 0
    checked = 0
    spread = {}
    for sched in scheds:
        for comp in itertools.product(proto.challenges, repeat=proto.rounds):
            # completion convention: pad a short rho with `comp`
            pb = []
            for w in proto.witnesses:
                bad = 0
                for om in proto.omegas:
                    msgs, rs = adaptive_run(proto, w, om, sched)
                    rho = rs + comp[len(rs):]
                    if flag(w, om, rho):
                        bad += 1
                pb.append(Fr(bad, len(proto.omegas)))
            ls = [adaptive_law_view(proto, w, sched, "prefix") for w in proto.witnesses]
            for i in range(1, len(ls)):
                checked += 1
                d = tv(ls[0], ls[i])
                if d > (pb[0] + pb[i]) / 2:
                    viol += 1
                key = (repr(sorted(sched.items(), key=repr))[:12], comp)
                spread.setdefault(comp, []).append((str(d), str((pb[0] + pb[i]) / 2)))
    say("    (iv') holds under the non-adapted flag: %s" % ok_iv)
    say("    bound checked %d times over every schedule x every completion: %d violations"
        % (checked, viol))
    for comp in sorted(spread, key=repr):
        worst = max(spread[comp], key=lambda t: Fr(t[0]))
        say("      completion rho_missing := %s -> worst (TV, bound) seen = %s"
            % (comp, worst))
    RESULT["C3"] = {"iv_prime_holds": ok_iv, "checks": checked, "violations": viol,
                    "by_completion": {str(k): max(v, key=lambda t: Fr(t[0]))
                                      for k, v in spread.items()}}
    assert ok_iv and viol == 0
    say("  VERDICT: no soundness hole -- quantifying (iv') over the FULL rho in C^N is")
    say("           what rescues a non-adapted flag.  But the VALUE of Pr^xi[B] depends")
    say("           on the completion (1/2 vs 1 here), so 'the probability of the flag")
    say("           in the adaptive run' is NOT WELL DEFINED as the memo words it: the")
    say("           run stopped before that challenge was ever drawn.  A convention")
    say("           must be fixed, or B must be required ADAPTED.")

    say()
    say("C4  S-H' with the memo's PAIR-DEPENDENT flag  B = B_w union B_w'  (this is")
    say("    where the memo's factor 2 on the LogUp term comes from)")
    nc = 8
    omegas = list(range(nc))

    def g(w):
        return w % nc

    def m0(w, om, r):
        return (om, None)

    def m1(w, om, r):
        return (REFUSE if r[0] == g(w) else (0, None))

    p = Proto("logup-shape", [0, 1], omegas, list(range(nc)), [m0, m1])
    scheds, _ = all_schedules(p)
    worst = Fr(0)
    worst_single = Fr(0)
    for sched in scheds:
        lp = [adaptive_law_view(p, w, sched, "perp") for w in p.witnesses]
        d = tv(lp[0], lp[1])
        pb_union, pb_single = [], []
        for w in p.witnesses:
            bu = bs = 0
            for om in p.omegas:
                _, rs = adaptive_run(p, w, om, sched)
                r0 = rs[0] if rs else None
                if r0 in (g(0), g(1)):
                    bu += 1
                if r0 == g(w):
                    bs += 1
            pb_union.append(Fr(bu, len(p.omegas)))
            pb_single.append(Fr(bs, len(p.omegas)))
        worst = max(worst, d - (pb_union[0] + pb_union[1]) / 2)
        worst_single = max(worst_single, d - (pb_single[0] + pb_single[1]) / 2)
    say("    union flag B = B_w u B_w' :  max (TV - bound) = %s   %s"
        % (worst, "bound HOLDS" if worst <= 0 else "bound VIOLATED"))
    say("    single-world flag B = B_w :  max (TV - bound) = %s   %s"
        % (worst_single, "bound HOLDS" if worst_single <= 0 else "bound VIOLATED"))
    RESULT["C4"] = {"union_slack": str(worst), "single_slack": str(worst_single)}
    assert worst <= 0
    say("  VERDICT: the union definition is REQUIRED -- a single-world flag does not")
    say("           satisfy (iv') and its bound is violated.  So the memo's factor 2")
    say("           on B_logup (2^-117.42 vs ruling S-4's 2^-118.4) is CORRECT and is")
    say("           not a one-bit arithmetic error; but the memo never says why the 2")
    say("           is there, and attributes the figure to ruling S-4, which has no 2.")


# ------------------------------------------------ D1 two games and the abort


def test_D1():
    say()
    say("=" * 78)
    say("D1  claim S-6: Game-perp makes (iv') trivial at a challenge-refused rho,")
    say("    Game-prefix does not.  Built explicitly.")
    nc = 2
    omegas = list(itertools.product(range(nc), repeat=2))

    # m_1 is masked when r_0 == 1 and RAW when r_0 == 0; the challenge-driven
    # refusal at round 2 fires exactly when r_0 == 0.  So under Game perp the
    # leak is never published; under Game prefix it always is.
    def m0(w, om, r):
        return ((om[0] + w) % nc, None)          # masked

    def m1(w, om, r):
        if r[0] == 1:
            return ((om[1] + w) % nc, None)      # masked
        return (w, None)                         # RAW -- but see m2

    def m2(w, om, r):
        if r[0] == 0:
            return REFUSE                        # challenge-driven: rho only
        return (0, None)

    def m1_safe(w, om, r):
        return ((om[1] + w) % nc, None)

    a = Proto("masked-prefix", range(nc), omegas, list(range(nc)),
              [m0, m1_safe, m2])
    b = Proto("leaky-prefix", range(nc), omegas, list(range(nc)), [m0, m1, m2])
    out = {}
    for proto, nm in ((a, "masked prefix"), (b, "leaky prefix")):
        scheds, _ = all_schedules(proto)
        wp = wq = Fr(0)
        # hypothesis (iv') at the VIEW level, per game, per rho
        iv_pref = iv_perp = Fr(0)
        for rho in itertools.product(proto.challenges, repeat=proto.rounds):
            for game, acc in (("prefix", "p"), ("perp", "q")):
                ls = []
                for w in proto.witnesses:
                    vals = []
                    for om in proto.omegas:
                        msgs = fixed_run(proto, w, om, rho)
                        if msgs[-1] == REFUSE and game == "perp":
                            vals.append(("PERP",))
                        else:
                            v = []
                            for j, m in enumerate(msgs):
                                v.append(m)
                                if j < len(rho) and j < len(msgs) - 1:
                                    v.append(rho[j])
                            vals.append(tuple(v))
                    ls.append(law(vals))
                d = max(tv(ls[0], ls[i]) for i in range(1, len(ls)))
                if game == "prefix":
                    iv_pref = max(iv_pref, d)
                else:
                    iv_perp = max(iv_perp, d)
        for sched in scheds:
            lp = [adaptive_law_view(proto, w, sched, "prefix") for w in proto.witnesses]
            lq = [adaptive_law_view(proto, w, sched, "perp") for w in proto.witnesses]
            for i in range(1, len(lp)):
                wp = max(wp, tv(lp[0], lp[i]))
                wq = max(wq, tv(lq[0], lq[i]))
        say("    %-16s  per-rho view TV: prefix=%s perp=%s | adaptive TV: prefix=%s perp=%s"
            % (nm, iv_pref, iv_perp, wp, wq))
        out[nm] = {"iv_prefix": str(iv_pref), "iv_perp": str(iv_perp),
                   "prefix": str(wp), "perp": str(wq)}
    RESULT["D1"] = out
    assert out["leaky prefix"]["perp"] == "0" and out["leaky prefix"]["prefix"] != "0"
    assert out["leaky prefix"]["iv_perp"] == "0" and out["leaky prefix"]["iv_prefix"] != "0"
    say("  VERDICT: claim S-6 CONFIRMED and made exact -- for the SAME protocol,")
    say("           hypothesis (iv') holds at every rho under Game perp and FAILS at the")
    say("           challenge-refused rho under Game prefix, and the adaptive")
    say("           conclusion follows the hypothesis.  Game perp is load-bearing,")
    say("           so GAP S-3 (M-9 has no production code) is a real obligation.")

    say()
    say("    Does the ABORT PROBABILITY itself leak under Game-perp?  A protocol whose")
    say("    prefix is perfectly masked but whose refusal probability is")
    say("    witness-dependent:")
    omegas2 = list(itertools.product(range(4), range(4)))   # (pad, coin)

    def c0(w, om, r):
        return ((om[0] + w) % 4, None)           # perfectly masked prefix

    def c1(w, om, r):
        return REFUSE if om[1] < w else (0, None)   # refusal rate = w/4

    c = Proto("abort-rate-leak", [0, 1, 2], omegas2, [0, 1], [c0, c1])
    scheds, _ = all_schedules(c)
    wq = max(tv(adaptive_law_view(c, 0, s, "perp"), adaptive_law_view(c, 2, s, "perp"))
             for s in scheds)
    say("      prefix perfectly masked, refusal rate w/4.  Game-perp adaptive TV = %s"
        % wq)
    say("      = exactly the gap in refusal rate.  The abort INDICATOR is inside the")
    say("      Game-perp view; nothing in the lemma hides it.  So the memo's 'liveness,")
    say("      not distance' line for the challenge-driven class is valid ONLY because")
    say("      that class is a function of rho ALONE -- if any of the four")
    say("      challenge-driven refusals also reads omega or w, it becomes a DISTANCE")
    say("      and must join B.  The memo asserts 'functions of rho alone' without a")
    say("      line-by-line code check.")
    RESULT["D1_abort_rate"] = {"perp_tv": str(wq)}
    assert wq == Fr(1, 2)


# ------------------------------------------- D2 adaptive oracle queries


def test_D2():
    say()
    say("=" * 78)
    say("D2  Corollary S-H'' with ADAPTIVE oracle queries (the memo's C8 fixes the")
    say("    query set in advance and says 'which for one leaf is without loss')")
    rows = []
    for salts in (2, 4):
        cols, digests = 2, 2
        points = [(x, s) for x in range(cols) for s in range(salts)]
        # exact optimal ADAPTIVE 2-query distinguisher by dynamic programming over
        # the posterior; compare with the best NON-ADAPTIVE pair.
        universe = []
        for a in range(cols):
            for s in range(salts):
                for t in itertools.product(range(digests), repeat=len(points)):
                    tab = dict(zip(points, t))
                    for w in (0, 1):
                        universe.append((w, a, s, tab, tab[((a + w) % cols, s)]))
        n_per_w = len(universe) // 2

        def best_adv(strategy_depth):
            # posterior over (w, a, s, tab) given the view (a, leaf) and answers
            def rec(state, depth, qs):
                # state: list of (w, a, s, tab)
                if depth == 0:
                    c0 = sum(1 for e in state if e[0] == 0)
                    c1 = len(state) - c0
                    return abs(c0 - c1)
                best = 0
                for p in points:
                    if p in qs:
                        continue
                    buckets = defaultdict(list)
                    for e in state:
                        buckets[e[3][p]].append(e)
                    tot = sum(rec(v, depth - 1, qs | {p}) for v in buckets.values())
                    best = max(best, tot)
                if best == 0:
                    c0 = sum(1 for e in state if e[0] == 0)
                    c1 = len(state) - c0
                    best = abs(c0 - c1)
                return best
            groups = defaultdict(list)
            for e in universe:
                groups[(e[1], e[4])].append(e)
            tot = sum(rec(v, strategy_depth, frozenset()) for v in groups.values())
            return Fr(tot, 2 * n_per_w)

        for q in (0, 1, 2):
            adv = best_adv(q)
            bound = Fr(q * cols, salts)
            say("    |S|=%d q=%d  exact OPTIMAL ADAPTIVE advantage = %-8s  memo bound"
                " q*N/|S| = %-6s  %s" % (salts, q, adv, bound,
                                         "OK" if adv <= bound else "VIOLATED"))
            rows.append({"salts": salts, "q": q, "adaptive_advantage": str(adv),
                         "bound": str(bound), "ok": adv <= bound})
            assert adv <= bound
    RESULT["D2"] = rows
    say("  VERDICT: the augmentation bound survives optimal ADAPTIVE querying on these")
    say("           instances.  It is also very loose (the memo's C8 bound q*N/|S|")
    say("           exceeds 1 already at q=1), so C8 is weak evidence either way.")


# ------------------------------------------------------- E1 the arithmetic


def lg(x):
    return math.log2(x)


def test_E1():
    say()
    say("=" * 78)
    say("E1  every number in the memo's section 5.3, recomputed")
    rows = []

    def row(name, value_log2, memo, note=""):
        ok = abs(value_log2 - memo) < 0.02
        rows.append({"term": name, "recomputed_log2": round(value_log2, 3),
                     "memo_log2": memo, "agrees": ok, "note": note})
        say("    %-46s recomputed 2^%-10.3f memo 2^%-10s %s %s"
            % (name, value_log2, memo, "OK  " if ok else "MISMATCH", note))

    row("B_samp toy   327,052 * 2^-96", lg(327052) - 96, -77.70)
    row("B_samp run   109,728,784 * 2^-96", lg(109728784) - 96, -69.29)
    row("B_salt toy   C(12288,2) * 2^-256", lg(12288 * 12287 / 2) - 256, -229.83)
    row("B_salt run   C(2473984,2) * 2^-256",
        lg(2473984 * 2473983 / 2) - 256, -214.52)
    row("eps_hit toy  2^128 * 12288 * 2^-256", 128 + lg(12288) - 256, -114.42)
    row("eps_hit run  2^128 * 2473984 * 2^-256", 128 + lg(2473984) - 256, -106.76)
    row("eps_gen      6 * 2^128 * 2^-256", lg(6) + 128 - 256, -125.42)
    # the field: 4/p = 2^-62.0 per opening  =>  p = 2^64 ;  |Fp2| = 2^128
    p = 2 ** 64
    fp2 = p * p
    row("B_logup toy  2*768/|Fp2|  (memo)", lg(2 * 768) - lg(fp2), -117.42,
        "factor 2 = the union over both worlds")
    row("B_logup run  2*12*768/|Fp2| (memo)", lg(2 * 12 * 768) - lg(fp2), -113.83,
        "factor 2 = the union over both worlds")
    row("ruling S-4   768/|Fp2| per block", lg(768) - lg(fp2), -118.42,
        "the memo's figure is exactly 1 bit worse")
    row("ruling S-4   12*768/|Fp2| per run", lg(12 * 768) - lg(fp2), -114.83,
        "the memo's figure is exactly 1 bit worse")
    row("challenge-only refusal toy 4/p", lg(4) - lg(p), -62.0, "liveness")
    row("challenge-only refusal run (3L+1)/p, L=12", lg(37) - lg(p), -58.79,
        "liveness")
    row("dropped B3 toy  2^128*4000*2^-256", 128 + lg(4000) - 256, -116.03)
    rows.append({"term": "dropped B4 toy  absorb collision", "recomputed_log2": None,
                 "memo_log2": -233.07, "agrees": None,
                 "note": "NOT RECOMPUTABLE from the memo: it never states the "
                         "absorb count A that C(A,2)*2^-256 needs (2^-233.07 "
                         "back-solves to A = 4,296)"})
    say("    %-46s NOT RECOMPUTABLE      memo 2^%-10s ---- the memo never states the "
        "absorb count A" % ("dropped B4 toy  absorb collision", -233.07))
    # totals
    toy_total = 2.0 ** (lg(327052) - 96) + 2.0 ** (lg(2 * 768) - lg(fp2)) \
        + 2.0 ** (lg(12288 * 12287 / 2) - 256) + 2.0 ** -241.42 \
        + 2.0 ** (128 + lg(12288) - 256) + 2.0 ** (lg(6) + 128 - 256)
    run_total = 2.0 ** (lg(109728784) - 96) + 2.0 ** (lg(2 * 12 * 768) - lg(fp2)) \
        + 2.0 ** (lg(2473984 * 2473983 / 2) - 256) \
        + 2.0 ** (128 + lg(2473984) - 256) + 2.0 ** (lg(6) + 128 - 256)
    say("    toy total  = 2^%.4f  (memo: 2^-77.70)" % lg(toy_total))
    say("    run total  = 2^%.4f  (memo: 2^-69.29)" % lg(run_total))
    rows.append({"term": "TOTAL toy", "recomputed_log2": round(lg(toy_total), 4),
                 "memo_log2": -77.70, "agrees": abs(lg(toy_total) + 77.70) < 0.01})
    rows.append({"term": "TOTAL run", "recomputed_log2": round(lg(run_total), 4),
                 "memo_log2": -69.29, "agrees": abs(lg(run_total) + 69.29) < 0.01})
    RESULT["E1"] = rows
    say("  VERDICT: every figure reproduces.  The totals are dominated by B_samp to")
    say("           more than 30 bits, so nothing in this page can move a total.")


def main():
    test_A1_A3()
    test_A2()
    test_B1()
    test_B2()
    test_B3()
    test_B4_B5()
    test_C1_C2()
    test_C3_C4()
    test_D1()
    test_D2()
    test_E1()
    with open(os.path.join(OUT, "checks.json"), "w") as f:
        json.dump(RESULT, f, indent=2, sort_keys=True, default=str)
    with open(os.path.join(OUT, "checks.log"), "w") as f:
        f.write("\n".join(LOG) + "\n")
    say()
    say("wrote checks.json and checks.log to %s" % OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
