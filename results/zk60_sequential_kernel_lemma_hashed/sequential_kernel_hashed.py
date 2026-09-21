#!/usr/bin/env python3
"""Exact machine checks for the sequential-kernel lemma over (field, hash) message pairs.

Companion to `docs/zkmatrix-poc/ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED.md`.

Everything here is exact rational arithmetic (`fractions.Fraction`) on finite
toy protocols.  Nothing here touches the ZK60 prover, and nothing here
establishes a privacy property of any artifact: these are checks of an
INFERENCE.

The model.  A protocol emits messages `m_0 .. m_N`, each a PAIR
`m_j = (f_j, h_j)` of a "field part" and a "hash part"; between messages a
challenge `r_j = chi_j(prefix)` is drawn by an arbitrary deterministic
function of the published prefix.  The prover's private randomness `omega`
carries, besides field blinding, the ORACLE TABLES the prover's hash parts are
images of (a salted-leaf table `L`, a generator table `G`).  That is the whole
point: in the real protocol the hash parts are oracle images, and the question
is whether the challenge functions -- which are ALSO oracle evaluations -- can
be quantified over arbitrarily.

Checks (all exact; every challenge function enumerated unless noted):

  C1 path identity      P_chi[m] == P_{rho(m)}[m]                 (the engine of the proof)
  C2 exact lemma        (iv) at every rho  =>  adaptive law witness-free, every chi
  C3 joint vs marginal  a hash part that keeps every marginal witness-free and the
                        joint law witness-dependent; some chi distinguishes
  C4 naive approx FALSE per-rho TV <= 1/|C| for every rho, adaptive TV = 1
  C5 until-bad TRUE     d <= (Pr_w[BAD] + Pr_*[BAD])/2 with BAD measured in the
                        ADAPTIVE experiment; the per-rho probability is NOT a bound
  C6 refusal steering   one witness-dependent refusal class, probability 1/|C| at a
                        uniform challenge, is made certain by a constant chi
  C7 separation         a challenge query point that coincides with a generator
                        refill point hands the distinguisher the whole witness
  C8 oracle access      a q-query distinguisher's advantage against the hidden-salt
                        leaf is at most q * (#hidden leaves) / |salt space|

Usage:  python3 sequential_kernel_hashed.py [--out DIR]
"""

import argparse
import itertools
import json
import os
import random
import sys
from collections import defaultdict
from fractions import Fraction

REFUSE = "REFUSE"

# --------------------------------------------------------------------------
# engine
# --------------------------------------------------------------------------


class Protocol:
    """`rules[j](w, omega, r_prefix) -> message or REFUSE`; `rounds` challenges."""

    def __init__(self, name, witnesses, omegas, challenges, rules, rounds=None):
        self.name = name
        self.witnesses = list(witnesses)
        self.omegas = list(omegas)
        self.challenges = list(challenges)
        self.rules = list(rules)
        self.rounds = len(rules) - 1 if rounds is None else rounds


def run_view(proto, w, omega, next_challenge):
    """The public view `(m_0, r_0, m_1, ...)`, truncated at the first REFUSE."""
    view, r = [], []
    for j, rule in enumerate(proto.rules):
        m = rule(w, omega, tuple(r))
        view.append(m)
        if m == REFUSE:
            return tuple(view)
        if j < proto.rounds:
            rj = next_challenge(j, tuple(view))
            view.append(rj)
            r.append(rj)
    return tuple(view)


def run_messages(proto, w, omega, rho):
    """The message tuple at FIXED challenges `rho` (truncated at REFUSE)."""
    out = []
    for j, rule in enumerate(proto.rules):
        m = rule(w, omega, tuple(rho[:j]))
        out.append(m)
        if m == REFUSE:
            break
    return tuple(out)


def law_view(proto, w, next_challenge):
    counts = defaultdict(int)
    for omega in proto.omegas:
        counts[run_view(proto, w, omega, next_challenge)] += 1
    n = len(proto.omegas)
    return {v: Fraction(c, n) for v, c in counts.items()}


def law_messages(proto, w, rho):
    counts = defaultdict(int)
    for omega in proto.omegas:
        counts[run_messages(proto, w, omega, rho)] += 1
    n = len(proto.omegas)
    return {v: Fraction(c, n) for v, c in counts.items()}


def tv(p, q):
    keys = set(p) | set(q)
    return sum(abs(p.get(k, Fraction(0)) - q.get(k, Fraction(0))) for k in keys) / 2


def messages_of_view(proto, view):
    """Strip the challenges out of a view."""
    head = view[: 2 * proto.rounds + 1]
    return head[0::2] + view[2 * proto.rounds + 1:]


def challenges_along(proto, view):
    return view[: 2 * proto.rounds + 1][1::2]


def reachable_prefixes(proto):
    """Every prefix `(m_0, r_0, ..., m_j)` reachable under SOME challenge assignment."""
    levels = []
    cur = set()
    for w in proto.witnesses:
        for omega in proto.omegas:
            cur.add((proto.rules[0](w, omega, ()),))
    levels.append(sorted(cur, key=repr))
    for j in range(proto.rounds):
        nxt = set()
        for pref in levels[j]:
            if pref[-1] == REFUSE:
                continue
            for c in proto.challenges:
                rs = tuple(list(challenges_along_prefix(pref)) + [c])
                for w in proto.witnesses:
                    for omega in proto.omegas:
                        m = proto.rules[j + 1](w, omega, rs)
                        nxt.add(pref + (c, m))
        levels.append(sorted(nxt, key=repr))
    return levels


def challenges_along_prefix(pref):
    return pref[1::2]


def all_challenge_functions(proto, cap=20000, seed=0):
    """Every challenge function, as a dict `(j, prefix) -> c`; sampled if too many."""
    levels = reachable_prefixes(proto)
    slots = []
    for j in range(proto.rounds):
        for pref in levels[j]:
            if pref[-1] != REFUSE:
                slots.append((j, pref))
    total = len(proto.challenges) ** len(slots)
    if total <= cap:
        out = []
        for combo in itertools.product(proto.challenges, repeat=len(slots)):
            out.append(dict(zip(slots, combo)))
        return out, total, True
    rng = random.Random(seed)
    out = []
    for _ in range(cap):
        out.append({s: rng.choice(proto.challenges) for s in slots})
    return out, total, False


def as_fn(table):
    def f(j, prefix):
        return table[(j, prefix)]
    return f


def rho_of_view(proto, view):
    return tuple(challenges_along(proto, view))


# --------------------------------------------------------------------------
# C1 / C2  -- the path identity and the exact lemma
# --------------------------------------------------------------------------


def all_tables(npoints, digests):
    """EVERY function from `npoints` points to `digests` values -- so that a table
    drawn uniformly from this list is a uniform random function, which is what a
    random oracle restricted to those points is."""
    return list(itertools.product(range(digests), repeat=npoints))


def salted_leaf_protocol(seed, salts=2, cols=3, digests=2, witnesses=3):
    """A one-challenge (field, hash) protocol of the shape the real prover has.

    omega = (pad a, salt s, leaf table L).  m_0 = (nothing, L[(a+w) mod cols, s])
    -- a "root" over a HIDDEN column with a fresh salt.  m_1 publishes the pad
    itself, which is what makes the joint law interesting: the adversary learns
    `a`, and the hidden column `a + w` is then determined by `w`, exactly as in
    the real protocol (section 3.4 of ZK60_HASH_LAYER_AND_FS_LIFT.md: an
    unopened column IS a function of the view and the hidden data; only the salt
    hides it).

    The table is part of the PROVER's randomness and is not in the view: this is
    the q = 0 case of the lemma, and the cost of a q-query distinguisher who can
    read the table is measured separately in C8.
    """
    points = [(c, s) for c in range(cols) for s in range(salts)]
    tables = all_tables(len(points), digests)
    omegas = [(a, s, t) for a in range(cols) for s in range(salts) for t in tables]
    idx = {p: i for i, p in enumerate(points)}

    def m0(w, omega, r):
        a, s, t = omega
        return (None, t[idx[((a + w) % cols, s)]])

    def m1(w, omega, r):
        a, s, t = omega
        return ((a + r[0]) % cols, None)

    return Protocol("salted-leaf", range(witnesses), omegas, [0, 1], [m0, m1])


def random_masked_protocol(seed, cols=3, digests=2, salts=2, witnesses=3):
    """A random one-challenge paired protocol whose per-rho joint law is witness-free
    by construction: every published field value is a fresh pad plus a public
    function of (w, r), and every hash part is an oracle image at a point whose
    salt is fresh and never published."""
    rng = random.Random(seed)
    coef = [rng.randrange(cols) for _ in range(2)]        # public per-round weights
    points = [(c, s) for c in range(cols) for s in range(salts)]
    tables = all_tables(len(points), digests)
    omegas = [(a, b, s, t) for a in range(cols) for b in range(cols)
              for s in range(salts) for t in tables]
    idx = {p: i for i, p in enumerate(points)}

    def m0(w, omega, r):
        a, b, s, t = omega
        return ((a + coef[0] * w) % cols, t[idx[((b + w) % cols, s)]])

    def m1(w, omega, r):
        a, b, s, t = omega
        return ((b + coef[1] * w * r[0]) % cols, None)

    return Protocol("random-masked-%d" % seed, range(witnesses), omegas, [0, 1], [m0, m1])


def check_path_identity(proto, chis):
    """P_chi[m] == P_{rho(m)}[m] for every chi, every w, every message tuple."""
    bad = 0
    for w in proto.witnesses:
        fixed_laws = {rho: law_messages(proto, w, rho)
                      for rho in itertools.product(proto.challenges, repeat=proto.rounds)}
        for table in chis:
            lv = law_view(proto, w, as_fn(table))
            agg = defaultdict(Fraction)
            for view, p in lv.items():
                agg[(messages_of_view(proto, view), rho_of_view(proto, view))] += p
            for (msgs, rho), p in agg.items():
                # rho may be shorter than `rounds` when the run refused early
                full = rho + tuple(proto.challenges[0] for _ in range(proto.rounds - len(rho)))
                ref = fixed_laws[full].get(msgs, Fraction(0))
                if p != ref:
                    bad += 1
    return bad


def hypothesis_iv_holds(proto):
    """(iv): for every fixed rho the joint law of all messages is witness-free."""
    worst = Fraction(0)
    for rho in itertools.product(proto.challenges, repeat=proto.rounds):
        laws = [law_messages(proto, w, rho) for w in proto.witnesses]
        for i in range(1, len(laws)):
            worst = max(worst, tv(laws[0], laws[i]))
    return worst


def adaptive_worst(proto, chis):
    worst = Fraction(0)
    arg = None
    for table in chis:
        laws = [law_view(proto, w, as_fn(table)) for w in proto.witnesses]
        for i in range(1, len(laws)):
            d = tv(laws[0], laws[i])
            if d > worst:
                worst, arg = d, table
    return worst, arg


# --------------------------------------------------------------------------
# C3 -- the joint-versus-marginal trap, with a hash part
# --------------------------------------------------------------------------


def hash_mask_counterexample(table, cols=4):
    """m_0 = (nothing, H(mask)), m_1 = (mask + w, nothing), for a PUBLIC H.

    Both marginals are witness-free; the joint law is not.  This is the
    project's standing counterexample with the first message's hash part a real
    hash part.  H is public -- the distinguisher knows it -- which is the right
    model for the hash of a value the protocol goes on to publish; contrast the
    salted leaf of C1, whose input the distinguisher cannot reach."""
    omegas = list(range(cols))

    def m0(w, omega, r):
        return (None, table[omega])

    def m1(w, omega, r):
        return ((omega + w) % cols, None)

    return Protocol("H(mask), mask+w", range(cols), omegas, [0, 1], [m0, m1])


def marginal_laws(proto, w, rho, k):
    out = defaultdict(Fraction)
    for msgs, p in law_messages(proto, w, rho).items():
        out[msgs[k] if k < len(msgs) else REFUSE] += p
    return dict(out)


# --------------------------------------------------------------------------
# C4 / C5 / C6 -- the approximate forms
# --------------------------------------------------------------------------


def leaky_on_hit_protocol(nc, witnesses=2):
    """The instance that kills the naive approximate lemma.

    omega = u, uniform on the challenge alphabet.  m_0 = (u, nothing) -- a
    published value carrying NO information about w.  The prover leaks the
    witness exactly when the challenge equals u:

        m_1 = (w, nothing)          if r_0 == u
        m_1 = (0, nothing)          otherwise

    At any FIXED rho_0 the leak happens with probability 1/nc, so the per-rho
    total variation distance between two witnesses is 1/nc.  The challenge
    function chi(m_0) = u (read the first message!) makes the leak certain.

    This is the shape of every "the challenge hit a witness-dependent value"
    event in the real protocol -- among them the zero LogUp denominator."""
    omegas = list(range(nc))

    def m0(w, omega, r):
        return (omega, None)

    def m1(w, omega, r):
        return ((w if r[0] == omega else 0), None)

    return Protocol("leaky-on-hit-%d" % nc, range(1, witnesses + 1), omegas,
                    list(range(nc)), [m0, m1])


def bad_flag_leaky(proto, w, table):
    """Pr[BAD] in the ADAPTIVE experiment, BAD = {the challenge hit u}."""
    hit = 0
    for omega in proto.omegas:
        view = run_view(proto, w, omega, as_fn(table))
        if view[1] == omega:
            hit += 1
    return Fraction(hit, len(proto.omegas))


def refusal_steering_protocol(nc, witnesses=3):
    """One witness-dependent refusal class, of the LogUp shape.

    m_0 = (pad, nothing) with the pad uniform and witness-free.  The prover
    REFUSES at round 1 iff the challenge equals g(w) -- a value determined by
    the hidden data and invisible in the prefix.  At a uniform challenge the
    refusal is a 1/nc event; a CONSTANT challenge function makes it certain for
    one witness and impossible for another."""
    omegas = list(range(nc))

    def g(w):
        return w % nc

    def m0(w, omega, r):
        return (omega, None)

    def m1(w, omega, r):
        if r[0] == g(w):
            return REFUSE
        return (0, None)

    return Protocol("refusal-steering-%d" % nc, range(witnesses), omegas,
                    list(range(nc)), [m0, m1])


# --------------------------------------------------------------------------
# C7 -- separation of the challenge class from the prover's class
# --------------------------------------------------------------------------


# --------------------------------------------------------------------------
# C8 -- the distinguisher's oracle queries
# --------------------------------------------------------------------------


def oracle_query_advantage(salts, cols, digests, q):
    """Exact advantage of a q-query distinguisher against a hidden salted leaf.

    The prover publishes the pad `a` and the leaf `L[(a + w) mod cols, s]` with a
    fresh hidden salt `s`.  The distinguisher may read `L` at q points of its
    choice (chosen non-adaptively, which for one leaf is without loss).  Returns
    the exact maximal total-variation distance between the augmented views at
    w = 0 and w = 1, and the memo's bound q * cols / salts."""
    points = [(c, s) for c in range(cols) for s in range(salts)]
    best = Fraction(0)
    for qs in itertools.combinations(points, q) if q else [()]:
        laws = []
        for w in (0, 1):
            counts = defaultdict(int)
            n = 0
            for a in range(cols):
                for s in range(salts):
                    for t in itertools.product(range(digests), repeat=len(points)):
                        tab = dict(zip(points, t))
                        leaf = tab[((a + w) % cols, s)]
                        counts[(a, leaf, tuple(tab[p] for p in qs))] += 1
                        n += 1
            laws.append({k: Fraction(v, n) for k, v in counts.items()})
        best = max(best, tv(laws[0], laws[1]))
    return best, Fraction(q * cols, salts)


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.dirname(os.path.abspath(__file__)))
    args = ap.parse_args()
    report = {}
    log = []

    def say(s):
        log.append(s)
        print(s)

    # ---- C1 + C2 -------------------------------------------------------
    say("C1/C2  the path identity and the exact lemma, on (field, hash) protocols")
    c1 = []
    for proto in [salted_leaf_protocol(1)] + [random_masked_protocol(s) for s in (2, 3, 4, 5, 6)]:
        chis, total, exhaustive = all_challenge_functions(proto)
        mismatches = check_path_identity(proto, chis)
        iv = hypothesis_iv_holds(proto)
        worst, _ = adaptive_worst(proto, chis)
        say("  %-20s omegas=%-6d chi=%d%s  path-identity mismatches=%d  max per-rho TV=%s  max adaptive TV=%s"
            % (proto.name, len(proto.omegas), total, "" if exhaustive else " (sampled)",
               mismatches, iv, worst))
        c1.append({"protocol": proto.name, "omegas": len(proto.omegas),
                   "challenge_functions": total, "exhaustive": exhaustive,
                   "path_identity_mismatches": mismatches,
                   "max_per_rho_tv": str(iv), "max_adaptive_tv": str(worst),
                   "lemma_conclusion_holds": worst == 0})
    report["C1_C2"] = c1
    assert all(r["path_identity_mismatches"] == 0 for r in c1)
    assert all((r["max_per_rho_tv"] == "0") == r["lemma_conclusion_holds"] for r in c1)

    # ---- C3 ------------------------------------------------------------
    say("")
    say("C3  a hash part keeps every marginal witness-free while the joint law is not")
    cols = 4
    n_all, n_joint_bad, n_marg_bad, n_adaptive_bad = 0, 0, 0, 0
    worst_overall = Fraction(0)
    for table in itertools.product(range(cols), repeat=cols):
        proto = hash_mask_counterexample(table, cols=cols)
        n_all += 1
        marg = Fraction(0)
        for rho in itertools.product(proto.challenges, repeat=proto.rounds):
            for k in (0, 1):
                laws = [marginal_laws(proto, w, rho, k) for w in proto.witnesses]
                for i in range(1, len(laws)):
                    marg = max(marg, tv(laws[0], laws[i]))
        joint = hypothesis_iv_holds(proto)
        chis, total, exhaustive = all_challenge_functions(proto, cap=4096, seed=3)
        worst, _ = adaptive_worst(proto, chis)
        worst_overall = max(worst_overall, worst)
        n_marg_bad += 1 if marg > 0 else 0
        n_joint_bad += 1 if joint > 0 else 0
        n_adaptive_bad += 1 if worst > 0 else 0
    say("  over all %d public functions H on a %d-element domain:" % (n_all, cols))
    say("    witness-dependent MARGINAL  : %d" % n_marg_bad)
    say("    witness-dependent JOINT law : %d  (hypothesis (iv) fails on exactly these)" % n_joint_bad)
    say("    some chi distinguishes      : %d  (max adaptive TV = %s)" % (n_adaptive_bad, worst_overall))
    report["C3"] = {"functions": n_all, "marginal_witness_dependent": n_marg_bad,
                    "joint_witness_dependent": n_joint_bad,
                    "adaptively_distinguishable": n_adaptive_bad,
                    "max_adaptive_tv": str(worst_overall)}
    assert n_marg_bad == 0 and n_joint_bad > 0 and n_adaptive_bad == n_joint_bad

    # ---- C4 + C5 -------------------------------------------------------
    say("")
    say("C4/C5  the naive approximate form is FALSE; the identical-until-bad form holds")
    rows = []
    for nc in (2, 4, 8, 16, 32):
        proto = leaky_on_hit_protocol(nc)
        per_rho = hypothesis_iv_holds(proto)
        steer = {(0, ((u, None),)): u for u in range(nc)}   # chi(m_0) = u : always hit
        d_steer = tv(law_view(proto, 1, as_fn(steer)), law_view(proto, 2, as_fn(steer)))
        bad_adaptive = bad_flag_leaky(proto, 1, steer)
        const = {(0, ((u, None),)): 0 for u in range(nc)}   # chi == 0 : hits with prob 1/nc
        d_const = tv(law_view(proto, 1, as_fn(const)), law_view(proto, 2, as_fn(const)))
        bad_const = bad_flag_leaky(proto, 1, const)
        rows.append({"nc": nc, "per_rho_tv": str(per_rho),
                     "adaptive_tv_steering_chi": str(d_steer),
                     "bad_prob_adaptive_steering": str(bad_adaptive),
                     "adaptive_tv_constant_chi": str(d_const),
                     "bad_prob_adaptive_constant": str(bad_const),
                     "blowup_factor": str(d_steer / per_rho) if per_rho else None})
        say("  |C|=%-3d per-rho TV=%-8s steering chi: TV=%-4s Pr[BAD]=%-4s | constant chi: TV=%-8s Pr[BAD]=%-8s | blow-up x%s"
            % (nc, per_rho, d_steer, bad_adaptive, d_const, bad_const, d_steer / per_rho))
        assert d_steer <= (bad_adaptive + bad_adaptive) / 2 + Fraction(0)   # until-bad bound
        assert d_const <= (bad_const + bad_const) / 2
        assert d_steer == 1 and per_rho == Fraction(1, nc)
    report["C4_C5"] = rows
    say("  => per-rho TV is NOT a bound on the adaptive TV: the blow-up is exactly |C|.")
    say("  => Pr[BAD] measured in the ADAPTIVE experiment IS a bound, in every row.")

    # ---- C6 ------------------------------------------------------------
    say("")
    say("C6  one witness-dependent refusal class, steered by a constant challenge function")
    rows = []
    for nc in (4, 8, 16):
        proto = refusal_steering_protocol(nc)
        chis, total, exhaustive = all_challenge_functions(proto, cap=1024, seed=nc)
        # make sure the CONSTANT challenge functions are among the candidates:
        # those are the ones that steer the refusal
        slots = list(chis[0].keys())
        chis = [{s: c for s in slots} for c in proto.challenges] + chis
        worst, arg = adaptive_worst(proto, chis)
        # the average over a UNIFORMLY RANDOM challenge function (the ROM's chi)
        acc, n = Fraction(0), 0
        rnd = random.Random(nc)
        for _ in range(200):
            t = {k: rnd.choice(proto.challenges) for k in chis[0]}
            laws = [law_view(proto, w, as_fn(t)) for w in proto.witnesses]
            acc += max(tv(laws[0], laws[i]) for i in range(1, len(laws)))
            n += 1
        rows.append({"nc": nc, "max_adaptive_tv_arbitrary_chi": str(worst),
                     "mean_adaptive_tv_random_chi": str(acc / n),
                     "mean_float": float(acc / n), "two_over_nc": float(Fraction(2, nc))})
        say("  |C|=%-3d worst chi: TV=%-4s   random chi (200 draws): mean TV=%.4f  (2/|C| = %.4f)"
            % (nc, worst, float(acc / n), 2.0 / nc))
        assert worst == 1
    report["C6"] = rows
    say("  => for ARBITRARY chi the conclusion is FALSE whenever one refusal is")
    say("     witness-dependent; for an oracle chi the distance is ~1/|C|.")

    # ---- C7 ------------------------------------------------------------
    say("")
    say("C7  separation of the challenge class from the prover's own oracle class")
    nvals = 4
    omegas = [(key, g_tab) for key in range(nvals)
              for g_tab in itertools.product(range(nvals), repeat=nvals)]

    def m0(w, omega, r):
        return (None, omega[0])

    def m1(w, omega, r):
        key, g_tab = omega
        return ((g_tab[key] + w) % nvals, None)

    proto = Protocol("separation", range(nvals), omegas, list(range(nvals)), [m0, m1])

    # shared: the challenge is the generator's own output at the published key
    def chi_shared(j, prefix):
        raise RuntimeError

    shared_laws = []
    for w in proto.witnesses:
        counts = defaultdict(int)
        for omega in proto.omegas:
            key, g_tab = omega
            r0 = g_tab[key]                       # the challenge query point == the refill point
            counts[((None, key), r0, ((g_tab[key] + w) % nvals, None))] += 1
        shared_laws.append({k: Fraction(v, len(proto.omegas)) for k, v in counts.items()})
    d_shared = max(tv(shared_laws[0], shared_laws[i]) for i in range(1, nvals))

    chis, total, exhaustive = all_challenge_functions(proto, cap=4096, seed=7)
    d_sep, _ = adaptive_worst(proto, chis)
    say("  shared query point (challenge oracle = generator oracle): max TV = %s" % d_shared)
    say("  separated classes, every one of %d challenge functions:   max TV = %s" % (len(chis), d_sep))
    report["C7"] = {"shared_tv": str(d_shared), "separated_tv": str(d_sep),
                    "challenge_functions": len(chis)}
    assert d_shared == 1 and d_sep == 0

    # ---- C8 ------------------------------------------------------------
    say("")
    say("C8  a q-query distinguisher against one hidden salted leaf")
    rows = []
    for salts in (2, 4):
        for q in (0, 1, 2):
            adv, bound = oracle_query_advantage(salts=salts, cols=2, digests=2, q=q)
            rows.append({"salts": salts, "q": q, "advantage": str(adv), "bound": str(bound),
                         "advantage_float": float(adv), "bound_float": float(bound)})
            say("  |S|=%d q=%d  exact advantage=%-8s  memo bound q*N/|S|=%-6s  %s"
                % (salts, q, adv, bound, "OK" if adv <= bound else "VIOLATED"))
            assert adv <= bound
    report["C8"] = rows

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "checks.json"), "w") as f:
        json.dump(report, f, indent=2, sort_keys=True)
    with open(os.path.join(args.out, "checks.log"), "w") as f:
        f.write("\n".join(log) + "\n")
    say("")
    say("all checks passed; wrote checks.json and checks.log to %s" % args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
