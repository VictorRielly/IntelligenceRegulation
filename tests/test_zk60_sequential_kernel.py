"""The sequential-kernel lemma ("adaptive lift"), machine-checked exhaustively on finite toy protocols.

This module is about the INFERENCE, not about the ZK60 prover.  It makes the
hypothesis under which fixed-challenge witness independence lifts to adaptive
(Fiat-Shamir) witness independence explicit, executes the proof as an exact
identity on toy models, and places both known counterexamples (Codex's H(mask),
mask XOR w and the shared-mask protocol) as failures of that hypothesis.
Establishing the hypothesis for the actual protocol -- the joint conditional
distribution over commitments, CFS messages, terminal masks, PCS openings and
oracle history -- is the open acceptance gate; nothing here supplies it.

LEMMA (sequential kernel).  Fix a finite witness set W, a finite private
randomness space Omega with the uniform law, a challenge alphabet C, and message
rules f_j : W x Omega x C^j -> M_j u {REFUSE}, j = 0..n.  A challenge function
H = (H_0, .., H_{n-1}) maps each public prefix (m_0, r_0, .., m_j) to r_j in C --
ANY function, in particular a hash of the prefix; the prover never sees H, only
the challenges r_<j.  View_H(w) is the law of the public transcript
(m_0, r_0, m_1, .., m_n), truncated at the first REFUSE, with omega uniform,
m_j = f_j(w, omega, r_<j) and r_j = H_j(prefix).  Msg_rho(w) is the law of
(m_0, .., m_n) with the challenges forced to a fixed vector rho in C^n.
  Hypothesis: for every rho and all w, w' in W,   Msg_rho(w) = Msg_rho(w').
  Conclusion: for every H and all w, w' in W,     View_H(w) = View_H(w').

PROOF SKETCH (induction on j).  For a public prefix pi_j = (m_<j, r_<j) define the
kernel K_j(m_j | pi_j) = P_rho[m_<=j] / P_rho[m_<j] for any rho extending r_<j.
 (i) Both marginals depend on rho only through r_<j, because m_0..m_j are
     functions of (w, omega, r_<j); so K_j is well defined.
 (ii) Both are marginals of Msg_rho(w), which is witness-independent by
     hypothesis; so K_j is witness-independent.
 (iii) Under any H, the event {prefix_j = pi_j} is, as a subset of Omega, the
     same event {m_<j(w, omega, r_<j) = m_<j} as under the fixed challenges r_<j,
     for H-consistent prefixes (r_i = H_i(m_<=i, r_<i)); H-inconsistent prefixes
     have probability zero.  Hence P_H[m_j | pi_j] = K_j(m_j | pi_j), r_j is then
     the deterministic value H_j(prefix), and
        P_H[(m_0, r_0, .., m_n)] = prod_j K_j(m_j | m_<j, r_<j) * prod_j 1[r_j = H_j(..)].
     Every factor is witness-independent, so View_H(w) = View_H(w').  REFUSE is
     just a message value with no continuation.  A refusal that is a function of
     the public prefix is a fixed map applied to Msg_rho, so equal laws stay
     equal; a witness-dependent refusal changes f_j and can break the hypothesis.

CHECKS BELOW (all exact, Fractions; every challenge function enumerated).
Two challenge functions that agree on every prefix reachable for SOME witness
induce identical views for EVERY witness, so enumerating values on reachable
prefixes enumerates all functions up to that view-preserving equivalence.
 (A) masked toy protocols whose per-rho joint law is witness-independent:
     kernels tail-independent (i), witness-independent (ii), and the product
     identity (iii) reproduces every adaptive view law; conclusion holds for all H.
 (B) Codex's counterexample (H(mask), mask XOR w) over all 256 functions H on a
     4-element domain: marginals always witness-independent; the per-rho JOINT
     law (rho empty) is witness-dependent for 240 of 256 H (all injective H, with
     disjoint supports).  The hypothesis fails, so the lemma does not apply.  The
     16 H constant on XOR-cosets satisfy hypothesis and conclusion alike.
     Averaged over an UNKNOWN H the joint laws coincide -- the distinguisher's
     oracle access is exactly what makes the per-H law the relevant one.
 (C) shared mask m_0 = mask, m_1 = mask + w*r_0: per-round marginals
     witness-independent, joint-given-rho not; 7 of the 8 challenge functions
     distinguish and a concrete distinguisher recovers w exactly.
 (D) refusal variants of a base protocol: a refusal that is a function of the
     public prefix preserves the lemma; a witness-independent private-coin
     refusal preserves it; a witness-dependent refusal breaks the hypothesis and
     every challenge function distinguishes.
"""
from collections import defaultdict
from fractions import Fraction
from itertools import product
import unittest

REFUSE = "REFUSE"


class Protocol:
    """(n+1) message rules, n challenges, uniform private randomness over `omegas`."""

    def __init__(self, name, witnesses, omegas, challenges, messages, rounds=None):
        self.name = name
        self.witnesses = list(witnesses)
        self.omegas = list(omegas)
        self.challenges = list(challenges)
        self.messages = list(messages)   # messages[j](w, omega, r_prefix) -> value or REFUSE
        self.rounds = len(messages) - 1 if rounds is None else rounds   # number of challenges drawn


def transcript(protocol, w, omega, next_challenge, stop_after=None):
    """Public view (m_0, r_0, .., m_n) truncated at REFUSE; `next_challenge(j, prefix)` supplies r_j.

    With `stop_after=j` return the prefix ending at m_j (None if refused earlier).
    """
    view, r = [], []
    for j, rule in enumerate(protocol.messages):
        m = rule(w, omega, tuple(r))
        view.append(m)
        if m == REFUSE:
            return None if stop_after is not None else tuple(view)
        if stop_after == j:
            return tuple(view)
        if j < protocol.rounds:
            rj = next_challenge(j, tuple(view))
            view.append(rj)
            r.append(rj)
    return tuple(view)


def law(protocol, w, next_challenge):
    counts = defaultdict(int)
    for omega in protocol.omegas:
        counts[transcript(protocol, w, omega, next_challenge)] += 1
    total = len(protocol.omegas)
    return {v: Fraction(c, total) for v, c in counts.items()}


def fixed(rho):
    return lambda j, prefix: rho[j]


def adaptive(tables):
    return lambda j, prefix: tables[j][prefix]


def messages_of(protocol, view):
    """The view alternates m, r for `rounds` challenges; any later messages are contiguous."""
    head = view[:2 * protocol.rounds + 1]
    return head[0::2] + view[2 * protocol.rounds + 1:]


def challenges_of(protocol, view):
    return view[:2 * protocol.rounds + 1][1::2]


def message_law(protocol, w, rho):
    out = defaultdict(Fraction)
    for view, p in law(protocol, w, fixed(rho)).items():
        out[messages_of(protocol, view)] += p
    return dict(out)


def marginal(msg_law, k):
    out = defaultdict(Fraction)
    for msgs, p in msg_law.items():
        out[msgs[:k]] += p
    return dict(out)


def statistical_distance(law_a, law_b):
    keys = set(law_a) | set(law_b)
    return sum(abs(law_a.get(k, Fraction(0)) - law_b.get(k, Fraction(0))) for k in keys) / 2


def hypothesis_failures(protocol):
    """Challenge vectors rho at which Msg_rho differs between some pair of witnesses."""
    failures = []
    for rho in product(protocol.challenges, repeat=protocol.rounds):
        laws = [message_law(protocol, w, rho) for w in protocol.witnesses]
        if any(l != laws[0] for l in laws[1:]):
            failures.append(rho)
    return failures


def challenge_functions(protocol):
    """Every challenge function as one table per round over prefixes reachable for some witness."""
    def rec(j, tables):
        if j == protocol.rounds:
            yield tables
            return
        prefixes = set()
        for w in protocol.witnesses:
            for omega in protocol.omegas:
                prefix = transcript(protocol, w, omega, adaptive(tables), stop_after=j)
                if prefix is not None:
                    prefixes.add(prefix)
        prefixes = sorted(prefixes, key=repr)
        for values in product(protocol.challenges, repeat=len(prefixes)):
            yield from rec(j + 1, tables + [dict(zip(prefixes, values))])
    yield from rec(0, [])


def conclusion_failures(protocol):
    """(count of challenge functions, list of (tables, max statistical distance) that distinguish)."""
    total, failures = 0, []
    for tables in challenge_functions(protocol):
        total += 1
        laws = [law(protocol, w, adaptive(tables)) for w in protocol.witnesses]
        distance = max(statistical_distance(laws[0], l) for l in laws[1:])
        if distance:
            failures.append((tables, distance))
    return total, failures


def kernel_table(protocol, w):
    """K_j(m_j | m_<j, r_<j) from the fixed-challenge laws; raises if the tail r_>=j matters (step i)."""
    table = {}
    for rho in product(protocol.challenges, repeat=protocol.rounds):
        msg_law = message_law(protocol, w, rho)
        for j in range(protocol.rounds + 1):
            numerator, denominator = marginal(msg_law, j + 1), marginal(msg_law, j)
            for msgs, p in numerator.items():
                if len(msgs) < j + 1:
                    continue  # refused earlier: the prefix already ended
                key = (j, msgs[:j], rho[:j])
                value = p / denominator[msgs[:j]]
                entry = table.setdefault(key, {})
                if msgs[j] in entry and entry[msgs[j]] != value:
                    raise AssertionError(f"kernel depends on the future challenges at {key}")
                entry[msgs[j]] = value
    return table


def product_probability(protocol, table, view):
    """Step (iii): prod_j K_j(m_j | m_<j, r_<j) for an H-consistent view."""
    msgs, rs_ = messages_of(protocol, view), challenges_of(protocol, view)
    p = Fraction(1)
    for j, m in enumerate(msgs):
        p *= table[(j, msgs[:j], rs_[:j])].get(m, Fraction(0))
    return p


# ---------------------------------------------------------------- toy protocols

def masked_two_message(p=5):
    """m_0 = u + a^2 (a hiding commitment to the mask), m_1 = (a + w r_0)^2: per-rho law uniform x squares."""
    return Protocol("masked-2msg-GF(%d)" % p, range(p), product(range(p), repeat=2), range(p), [
        lambda w, om, r: (om[0] + om[1] * om[1]) % p,
        lambda w, om, r: ((om[1] + w * r[0]) ** 2) % p,
    ])


def masked_three_message(p=3):
    """m_0 = u + a b, m_1 = a + w r_0, m_2 = (b + w r_1)^2 + r_0 m_1: fresh mask per response."""
    def m1(w, om, r):
        return (om[1] + w * r[0]) % p

    return Protocol("masked-3msg-GF(%d)" % p, range(p), product(range(p), repeat=3), (0, 1), [
        lambda w, om, r: (om[0] + om[1] * om[2]) % p,
        m1,
        lambda w, om, r: ((om[2] + w * r[1]) ** 2 + r[0] * m1(w, om, r)) % p,
    ])


def codex_counterexample(H):
    """view = (H(mask), mask XOR w); no challenge, so rho is empty."""
    return Protocol("codex-H(mask),mask^w", (0, 1), range(4), (), [
        lambda w, om, r: H[om],
        lambda w, om, r: om ^ w,
    ], rounds=0)


def shared_mask(p=3):
    """m_0 = mask, m_1 = mask + w r_0 with r_0 in {0,1}: marginals fine, joint-given-rho not."""
    return Protocol("shared-mask-GF(%d)" % p, range(p), range(p), (0, 1), [
        lambda w, om, r: om,
        lambda w, om, r: (om + w * r[0]) % p,
    ])


def with_refusal(base, refuse_before_m1, coin=False):
    """Copy `base` (two messages) with omega extended by a coin and m_1 replaced by REFUSE when the predicate holds.

    refuse_before_m1(w, omega, r_0, m_0, coin) -> bool.
    """
    omegas = [om + (c,) for om in base.omegas for c in ((0, 1) if coin else (0,))]
    m0, m1 = base.messages

    def m1_refusing(w, om, r):
        core, c = om[:-1], om[-1]
        if refuse_before_m1(w, core, r[0], m0(w, core, r), c):
            return REFUSE
        return m1(w, core, r)

    return Protocol(base.name + "+refusal", base.witnesses, omegas, base.challenges, [
        lambda w, om, r: m0(w, om[:-1], r),
        m1_refusing,
    ])


# ---------------------------------------------------------------------- tests

class LemmaHoldsOnMaskedProtocols(unittest.TestCase):
    """(A) hypothesis holds; steps (i)-(iii) executed as identities; conclusion for every H."""

    def check(self, protocol, expected_function_count):
        self.assertEqual(hypothesis_failures(protocol), [])
        tables = [kernel_table(protocol, w) for w in protocol.witnesses]  # (i) raises if tail matters
        for other in tables[1:]:
            self.assertEqual(other, tables[0])                              # (ii)
        total, failures = conclusion_failures(protocol)
        self.assertEqual(total, expected_function_count)
        self.assertEqual(failures, [])
        seen = 0
        for H in challenge_functions(protocol):                            # (iii)
            for w in protocol.witnesses:
                view_law = law(protocol, w, adaptive(H))
                for view, p in view_law.items():
                    self.assertEqual(p, product_probability(protocol, tables[0], view))
                self.assertEqual(sum(view_law.values()), 1)
            seen += 1
        self.assertEqual(seen, expected_function_count)

    def test_two_messages_gf5_all_3125_challenge_functions(self):
        protocol = masked_two_message(5)
        rho_law = message_law(protocol, 0, (1,))
        self.assertEqual(len(rho_law), 15)   # m_0 uniform (5) x squares {0,1,4}: not a uniform law
        self.check(protocol, 5 ** 5)

    def test_three_messages_gf3_all_4096_challenge_functions(self):
        protocol = masked_three_message(3)
        self.check(protocol, 2 ** 3 * 2 ** 9)


class CodexCounterexample(unittest.TestCase):
    """(B) marginals witness-independent, per-rho joint not: the hypothesis fails, the lemma does not apply."""

    def test_all_256_public_functions(self):
        joint_equal, joint_differ, injective_disjoint = 0, 0, 0
        for H in product(range(4), repeat=4):
            protocol = codex_counterexample(H)
            laws = [message_law(protocol, w, ()) for w in (0, 1)]
            for k in (0, 1):   # each marginal has the same law for both witnesses
                m = [defaultdict(Fraction) for _ in laws]
                for i, l in enumerate(laws):
                    for msgs, p in l.items():
                        m[i][msgs[k]] += p
                self.assertEqual(m[0], m[1])
            failures = hypothesis_failures(protocol)
            total, adaptive_failures = conclusion_failures(protocol)
            self.assertEqual(total, 1)   # no challenge: exactly one (empty) challenge function
            if failures:
                joint_differ += 1
                self.assertEqual(failures, [()])
                self.assertEqual(len(adaptive_failures), 1)
                if len(set(H)) == 4:
                    injective_disjoint += 1
                    self.assertFalse(set(laws[0]) & set(laws[1]))
                    self.assertEqual(adaptive_failures[0][1], 1)
            else:
                joint_equal += 1
                self.assertEqual(adaptive_failures, [])
                self.assertTrue(H[0] == H[1] and H[2] == H[3])
        self.assertEqual((joint_equal, joint_differ, injective_disjoint), (16, 240, 24))

    def test_distinguisher_with_oracle_access_recovers_the_witness_for_injective_H(self):
        for H in product(range(4), repeat=4):
            if len(set(H)) < 4:
                continue
            protocol = codex_counterexample(H)
            for w in (0, 1):
                for view in law(protocol, w, fixed(())):
                    root, masked = view
                    guess = 0 if H[masked] == root else 1   # one oracle query, as in Codex's test
                    self.assertEqual(guess, w)

    def test_without_oracle_access_the_mixture_over_H_hides_the_witness(self):
        mixtures = []
        for w in (0, 1):
            mixture = defaultdict(Fraction)
            for H in product(range(4), repeat=4):
                for msgs, p in message_law(codex_counterexample(H), w, ()).items():
                    mixture[msgs] += p / 256
            mixtures.append(dict(mixture))
        self.assertEqual(mixtures[0], mixtures[1])
        self.assertEqual(set(mixtures[0].values()), {Fraction(1, 16)})


class SharedMaskNeedsTheJointHypothesis(unittest.TestCase):
    """(C) per-round marginals witness-independent, joint-given-rho not; adaptive distinguishers exist."""

    def test_marginals_agree_joint_differs_and_seven_of_eight_functions_distinguish(self):
        protocol = shared_mask(3)
        for rho in ((0,), (1,)):
            laws = [message_law(protocol, w, rho) for w in protocol.witnesses]
            for k in (0, 1):
                marg = [defaultdict(Fraction) for _ in laws]
                for i, l in enumerate(laws):
                    for msgs, p in l.items():
                        marg[i][msgs[k]] += p
                self.assertTrue(all(m == marg[0] for m in marg))   # per-round marginals
        self.assertEqual(hypothesis_failures(protocol), [(1,)])     # joint differs only when r_0 = 1
        total, failures = conclusion_failures(protocol)
        self.assertEqual(total, 8)
        self.assertEqual(len(failures), 7)
        for tables, distance in failures:
            self.assertTrue(any(v == 1 for v in tables[0].values()))
            self.assertEqual(distance, Fraction(sum(tables[0].values()), 3))  # P[r_0 = 1] under uniform m_0
        self.assertEqual([t for t, _ in failures if not any(t[0].values())], [])

    def test_concrete_adaptive_distinguisher_recovers_the_witness(self):
        protocol = shared_mask(3)
        always_one = [{(m,): 1 for m in range(3)}]
        for w in protocol.witnesses:
            for view in law(protocol, w, adaptive(always_one)):
                m0, r0, m1 = view
                self.assertEqual(r0, 1)
                self.assertEqual((m1 - m0) % 3, w)


class RefusalEvents(unittest.TestCase):
    """(D) public-prefix refusal preserves the lemma; witness-dependent refusal breaks it."""

    FUNCTIONS = 3 ** 3   # challenges in GF(3), three reachable m_0 values

    def setUp(self):
        self.base = masked_two_message(3)
        self.assertEqual(hypothesis_failures(self.base), [])

    def test_public_prefix_refusal_preserves_the_lemma(self):
        protocol = with_refusal(self.base, lambda w, om, r0, m0, c: r0 == 1 and m0 == 0)
        self.assertEqual(hypothesis_failures(protocol), [])
        refused = sum(p for v, p in law(protocol, 0, fixed((1,))).items() if v[-1] == REFUSE)
        self.assertEqual(refused, Fraction(1, 3))
        for w in protocol.witnesses:
            kernel_table(protocol, w)
        total, failures = conclusion_failures(protocol)
        self.assertEqual(total, self.FUNCTIONS)
        self.assertEqual(failures, [])

    def test_witness_independent_private_coin_refusal_preserves_the_lemma(self):
        protocol = with_refusal(self.base, lambda w, om, r0, m0, c: c == 1, coin=True)
        self.assertEqual(hypothesis_failures(protocol), [])
        total, failures = conclusion_failures(protocol)
        self.assertEqual(total, self.FUNCTIONS)
        self.assertEqual(failures, [])

    def test_witness_dependent_refusal_breaks_the_hypothesis_and_every_function_distinguishes(self):
        protocol = with_refusal(self.base, lambda w, om, r0, m0, c: w == 1 and c == 1, coin=True)
        self.assertEqual(hypothesis_failures(protocol), [(0,), (1,), (2,)])
        for rho in ((0,), (1,), (2,)):
            refused = [sum(p for v, p in law(protocol, w, fixed(rho)).items() if v[-1] == REFUSE)
                       for w in protocol.witnesses]
            self.assertEqual(refused, [0, Fraction(1, 2), 0])
        total, failures = conclusion_failures(protocol)
        self.assertEqual(total, self.FUNCTIONS)
        self.assertEqual(len(failures), self.FUNCTIONS)
        self.assertTrue(all(distance >= Fraction(1, 2) for _, distance in failures))


if __name__ == "__main__":
    unittest.main()
