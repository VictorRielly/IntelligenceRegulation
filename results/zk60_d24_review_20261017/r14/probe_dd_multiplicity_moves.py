"""Item 1(c) probe: which multiplicity moves preserve the native LogUp identity?

A small exact model of the R14/R13 dictionary relation as implemented
(argument_accuracy.rs dd(): table helper g*(alpha - (gTAG + Sum + beta*e +
beta^2*P_dict)) = M_dd at EVERY slot, no usage gate; szc_dd(): query helper
h*(alpha - (gTAG + Sum + beta*(mask*e) + beta^2*P)) = 1 at every score entry;
one value-0 sum: sum(h) - sum(g) = 0). Arithmetic in the Goldilocks prime
field (the lemma needs only p > all counts; Fp2 behaves identically).

The probe: for a toy attention with causal mask, build the honest dictionary
(public e column = sorted({0} U outputs) padded with 0 to cap; P_dict =
floor(e*2^12/Sum)), the honest multiplicities, then try EVERY single-unit move
of one count from slot a to slot b (any rows) and report whether the sum
identity still holds at random (alpha, beta, gamma). It must hold exactly
when the two compressed tuples are equal.
"""
import json
import random
import sys

P = 2**64 - 2**32 + 1
TAG_DD = 141


def inv(x):
    return pow(x % P, P - 2, P)


def main(out):
    rnd = random.Random(20261030)
    T, cap, FP = 6, 16, 12
    exp_table = [512 >> min(d, 9) for d in range(256)]   # toy monotone exp, e(0) = 512
    e_col = sorted({0} | set(exp_table[:11]))
    e_col += [0] * (cap - len(e_col))
    assert len(e_col) == cap
    scores = [[rnd.randint(-5, 5) for _ in range(T)] for _ in range(T)]
    rows = []   # per row: (Sum, query tuples)
    for t in range(T):
        live = scores[t][: t + 1]
        mx = max(live)
        es = [exp_table[mx - s] if j <= t else 0 for j, s in enumerate(scores[t])]
        assert all(e in e_col for e in es)
        Sum = sum(es)
        qs = [(Sum, e, (e << FP) // Sum) for e in es]
        rows.append((Sum, qs))
    table = [(Sum, e, (e << FP) // Sum) for Sum, _ in rows for e in e_col]
    # honest multiplicities: each query counted at the FIRST slot of its row carrying the tuple
    m = [0] * len(table)
    for r, (Sum, qs) in enumerate(rows):
        for q in qs:
            k = next(k for k in range(cap) if table[r * cap + k] == q)
            m[r * cap + k] += 1
    queries = [q for _, qs in rows for q in qs]
    alpha, beta, gamma = (rnd.randrange(1, P) for _ in range(3))

    def comp(tp):
        s, e, p = tp
        return (gamma * TAG_DD + s + beta * e + beta * beta % P * p) % P

    def identity(mult):
        lhs = sum(inv(alpha - comp(q)) for q in queries) % P
        rhs = sum(mm * inv(alpha - comp(t)) for mm, t in zip(mult, table)) % P
        return lhs == rhs

    assert identity(m), "honest identity must hold"
    stats = {"slots": len(table), "queries": len(queries), "moves_tried": 0,
             "equal_tuple_moves": 0, "equal_tuple_moves_accepted": 0,
             "distinct_tuple_moves": 0, "distinct_tuple_moves_accepted": 0,
             "distinct_tuples_with_equal_compression": 0}
    for a in range(len(table)):
        if m[a] == 0:
            continue
        for b in range(len(table)):
            if a == b:
                continue
            mm = list(m)
            mm[a] -= 1
            mm[b] += 1
            ok = identity(mm)
            stats["moves_tried"] += 1
            if table[a] == table[b]:
                stats["equal_tuple_moves"] += 1
                stats["equal_tuple_moves_accepted"] += int(ok)
            else:
                stats["distinct_tuple_moves"] += 1
                stats["distinct_tuple_moves_accepted"] += int(ok)
                stats["distinct_tuples_with_equal_compression"] += int(comp(table[a]) == comp(table[b]))
    # the two named R14 cases, transcribed: masked-future zero -> padded zero (alias),
    # live (Sum, 512, 4096) -> padded zero (negative), both in row 0
    r0 = 0
    first_zero = next(k for k in range(cap) if e_col[k] == 0 and m[r0 * cap + k] > 0) if m[0] > 0 else None
    live = next(k for k in range(cap) if e_col[k] != 0 and m[r0 * cap + k] > 0)
    pad = cap - 1
    named = {}
    for name, src in [("alias_zero_to_pad", first_zero), ("live_to_pad", live)]:
        if src is None:
            named[name] = "row 0 has no masked-future zero in this toy"
            continue
        mm = list(m)
        mm[r0 * cap + src] -= 1
        mm[r0 * cap + pad] += 1
        named[name] = {"from_tuple": table[r0 * cap + src], "to_tuple": table[r0 * cap + pad],
                       "identity_holds": identity(mm)}
    stats["named_cases"] = named
    stats["claim_holds"] = (stats["equal_tuple_moves_accepted"] == stats["equal_tuple_moves"]
                            and stats["distinct_tuple_moves_accepted"] == 0)
    json.dump(stats, open(out, "w"), indent=1)
    print(json.dumps(stats, indent=1))


if __name__ == "__main__":
    main(sys.argv[1])
