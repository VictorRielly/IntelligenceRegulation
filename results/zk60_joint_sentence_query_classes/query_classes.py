#!/usr/bin/env python3
"""The complete query-class table: every BLAKE3 call kind, its length per
shape, and what separates it from every other one.

Evidence for ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md, Part B.

The layouts are transcribed from the code at lane commit 8c5922b; every
file:line is in the README and in the memo's table.  This script does the
arithmetic the memo's table reports, and looks for collisions the eye misses:

  * every input length, per shape, per BLAKE3 function instance;
  * every pair of DIFFERENT call kinds that land on the SAME length inside
    the SAME function instance (these are the pairs "separated by nothing
    structural");
  * every commitment row count that would put a column digest on some other
    input's length -- including the lengths the lane's own guard
    (hashline/src/private_block/hash_domain.rs) does NOT carry;
  * the same under the LEGACY rule (one unkeyed function for everything) and
    under the TAGGED rule (five functions).

Run:  python3 query_classes.py
"""

import itertools
from collections import defaultdict

# ---------------------------------------------------------------------------
# constants, transcribed at 8c5922b
# ---------------------------------------------------------------------------

ABSORB_FIXED = 32 + 8 + 8       # hash_domain.rs:58  (transcript.rs:61-67)
NEW_FIXED = 12                  # hash_domain.rs:64  (transcript.rs:31)
SQUEEZE_LEN = 32 + 7 + 8        # hash_domain.rs:68  (transcript.rs:104-106)
REFILL_LEN = 32 + 8             # hash_domain.rs:72  (rng.rs:55-56)
NODE_LEN = 64                   # hash_domain.rs:79  (merkle.rs:15, pcs.rs:678)
EXPECTED_IO = 8 + 32 + 4 + 4 + 2 * 32     # private_block.rs:213 == 112
RUN_SHAPE_BYTES = 7 * 8         # hash_domain.rs:88  (run.rs:311-314)
DIGEST = 32
FP2 = 16
SEED_OS_PREFIX = 22             # rng.rs:48  b"hashline-zk-os-rng/v1/"
SEED_FIXTURE = 16 + 8           # rng.rs:22,24  b"hashline-zk-rng/" + le64(seed)
MASK_DOM_ROWS = 50              # 2*23+4, zk.rs base rows of M
MASK_MSG_WORDS = 2 << 9         # zk.rs:499-509, 1024 extension words

# labels and their data lengths, from hash_domain.rs fixed_labels() :74-108
FIXED_LABELS = [
    ("run-shape", [RUN_SHAPE_BYTES]),
    ("expected-IO", [EXPECTED_IO]),
    ("public-statement", [DIGEST]),
    ("calibration", [DIGEST]),
    ("schedule", [DIGEST]),
    ("A", [DIGEST]), ("H", [DIGEST]), ("B", [DIGEST]), ("M", [DIGEST]),
    ("rows", [8]),
    ("log-cols", [8]),
    ("pb-run-stage", [8]),
    ("pb-run-block", [DIGEST]),
    ("pb-slot", [8]),
    ("pb-scalar", [FP2]),
    ("sc-round", [FP2 * (d + 1) for d in range(2, 6)]),   # degree_range (2,5)
    ("mask-q", [FP2 * MASK_MSG_WORDS]),
    ("mask-prox", [FP2 * MASK_MSG_WORDS]),
]

# per-shape data, transcribed from shape.rs / layout.rs / run.rs at 8c5922b.
# parameter_line lengths are the absorb length minus (48 + 10); "None" where
# this drafter has not read the literal at that shape.
SHAPES = {
    "toy": dict(
        profile="hashline-zk-mr1/private-block-t32-poc/1",
        log_cols=8, inv_rate=8, opened=256,
        a_rows=455, h_rows=384, m_rows=MASK_DOM_ROWS,
        e_log=8, e_rate=8, e_rows=7, b_rows=None,
        param_line=113, rule="legacy", endpoint="frozen seam",
        seed_domains={"block prover": 39, "frozen-seam endpoint": 28},
    ),
    "rung": dict(
        profile="hashline-zk-mr1/private-block-rung-t24-dev/1",
        log_cols=10, inv_rate=4, opened=256,
        a_rows=623, h_rows=576, m_rows=MASK_DOM_ROWS,
        e_log=8, e_rate=8, e_rows=21, b_rows=None,
        param_line=152, rule="legacy", endpoint="frozen seam",
        seed_domains={"block prover": 44, "frozen-seam endpoint": 28},
    ),
    "rung-G": dict(
        profile="hashline-zk-mr1/private-block-rung-g-t24-dev/1",
        log_cols=10, inv_rate=4, opened=256,
        a_rows=623, h_rows=576, m_rows=MASK_DOM_ROWS,
        e_log=10, e_rate=4, e_rows=9, b_rows=10,
        param_line=152, rule="tagged", endpoint="generalised",
        seed_domains={"block prover": 46, "generalised endpoint": 42},
    ),
    "rung-K4": dict(
        profile="hashline-zk-mr1/private-block-rung-k4-t24-dev/1",
        log_cols=10, inv_rate=4, opened=256,
        a_rows=727, h_rows=720, m_rows=MASK_DOM_ROWS,
        e_log=10, e_rate=4, e_rows=9, b_rows=10,
        param_line=None, rule="tagged", endpoint="generalised",
        seed_domains={"block prover": 47, "generalised endpoint": 42},
    ),
    "125M": dict(
        profile="hashline-zk-mr1/private-block-m125/1",
        log_cols=14, inv_rate=4, opened=256,
        a_rows=5681, h_rows=7120, m_rows=MASK_DOM_ROWS,
        e_log=14, e_rate=4, e_rows=37, b_rows=38,
        param_line=157, rule="tagged", endpoint="generalised",
        seed_domains={"block prover": 36, "generalised endpoint": 42},
    ),
}

RUNS = {
    "run rung-G L=3":  dict(shape="rung-G",  profile_len=44, L=3),
    "run rung-K4 L=3": dict(shape="rung-K4", profile_len=45, L=3),
    "run 125M L=12":   dict(shape="125M",    profile_len=34, L=12),
}

# unkeyed statement digests, crate-wide on this path (all F_U at EVERY rule)
def statement_digests(s, L=None):
    out = [
        ("calibration identity (private_block.rs:222)", 30),
        ("generalised endpoint spec digest (endpoint_g.rs:158)", 142),
        ("internal boundary spec digest (boundary.rs:211)", 151),
        ("frozen-seam spec digest (private_seam.rs:116)", 128),
    ]
    if L is not None:
        out.append((f"run public statement (run.rs:221), L={L}", 29 + 32 * L))
    return out


# ---------------------------------------------------------------------------

def absorb_len(label, data):
    return ABSORB_FIXED + len(label) + data


def transcript_inputs(s, run_profile_len=None, L=None):
    """Every F_T input length of one profile's path, with what it is."""
    out = []
    if run_profile_len is None:
        out.append((f"constructor, profile `{s['profile']}`",
                    NEW_FIXED + len(s["profile"])))
    else:
        out.append((f"constructor, RUN profile ({run_profile_len} B)",
                    NEW_FIXED + run_profile_len))
    out.append(("squeeze (live, position tag, refusal replay)", SQUEEZE_LEN))
    for label, datas in FIXED_LABELS:
        for d in datas:
            out.append((f"absorb `{label}` ({d} B data)", absorb_len(label, d)))
    if s["param_line"] is not None:
        out.append((f"absorb `parameters` (block line)",
                    absorb_len("parameters", s["param_line"])))
    n = 1 << s["log_cols"]
    ne = 1 << s["e_log"]
    for tag, width in (("block", n), ("endpoint/boundary", ne)):
        d = FP2 * (width + s["opened"])
        out.append((f"absorb `pcs-vec` ({tag})", absorb_len("pcs-vec", d)))
        out.append((f"absorb `pcs-prox` ({tag})", absorb_len("pcs-prox", d)))
    # pb-term: one absorb per slot of that slot's private terminals.
    # hash_domain.rs:172-182 builds the exact per-slot set from the shape; the
    # toy memo records slot_terms(s) in 1..56 (absorb 71..951).  This drafter
    # has not read the per-slot counts at every shape, so the WHOLE range
    # 1..56 is taken -- an over-approximation, exactly as hash_domain.rs
    # over-approximates `sc-round` by the whole degree range.
    for k in range(1, 57):
        out.append((f"absorb `pb-term` ({k} terminals)",
                    absorb_len("pb-term", FP2 * k)))
    return out


def column_inputs(s):
    out = [("A column digest", 8 * s["a_rows"]),
           ("H column digest", 8 * s["h_rows"]),
           ("M column digest", 8 * s["m_rows"]),
           ("endpoint column digest", 8 * s["e_rows"])]
    if s["b_rows"]:
        out.append(("boundary column digest", 8 * s["b_rows"]))
    return out


def seed_inputs(s):
    return [(f"generator SEED derivation, domain `{k}` ({v} B)",
             SEED_OS_PREFIX + v) for k, v in s["seed_domains"].items()]


def line(x=""):
    print(x)


# ---------------------------------------------------------------------------

def report_shape(name, s, run=None):
    L = run["L"] if run else None
    rp = run["profile_len"] if run else None
    title = name if not run else f"{name}"
    line()
    line("=" * 92)
    line(f"{title}   (rule: {s['rule']}, endpoint: {s['endpoint']})")
    line("=" * 92)

    T = transcript_inputs(s, rp, L)
    C = column_inputs(s)
    LEAF = [("salted leaf", NODE_LEN)]
    NODE = [("Merkle inner node", NODE_LEN)]
    U = [("generator refill (XOF)", REFILL_LEN)] + statement_digests(s, L) \
        + seed_inputs(s)

    if s["rule"] == "legacy":
        # ONE unkeyed function carries everything except the keyed seed
        families = {"F_U (the single unkeyed function)":
                    T + C + LEAF + NODE +
                    [x for x in U if "SEED" not in x[0]],
                    "keyed under the secret OS entropy (V-2)":
                    [x for x in U if "SEED" in x[0]]}
    else:
        families = {
            "F_T (transcript key)": T,
            "F_C (column key)": C,
            "F_L (leaf key)": LEAF,
            "F_N (node key)": NODE,
            "F_U (still unkeyed)": [x for x in U if "SEED" not in x[0]],
            "keyed under the secret OS entropy (V-2)":
                [x for x in U if "SEED" in x[0]],
        }

    findings = []
    for fam, items in families.items():
        by_len = defaultdict(list)
        for what, ln in items:
            by_len[ln].append(what)
        clashes = {ln: sorted(set(v)) for ln, v in by_len.items()
                   if len(set(v)) > 1}
        # drop "same call kind at two geometries" -- not a separation question
        real = {ln: v for ln, v in clashes.items() if not same_kind(v)}
        line(f"  {fam}: {len(items)} input kinds, "
             f"{len(by_len)} distinct lengths, {len(clashes)} length clashes "
             f"({len(clashes) - len(real)} of them one kind at two geometries)")
        for ln, v in sorted(real.items()):
            kind = classify(v)
            line(f"      !! {ln:>7} B  [{kind}]")
            for w in v:
                line(f"            {w}")
            findings.append((fam, ln, v, kind))
    # cross-family length coincidences: separated by MODE or KEY, not length
    line(f"  cross-family coincidences (separated by mode/key, never by "
         f"length):")
    fams = list(families.items())
    seen = set()
    for (f1, i1), (f2, i2) in itertools.combinations(fams, 2):
        l1 = {ln: w for w, ln in i1}
        l2 = {ln: w for w, ln in i2}
        for ln in sorted(set(l1) & set(l2)):
            if (ln, f1, f2) in seen:
                continue
            seen.add((ln, f1, f2))
            line(f"      ~~ {ln:>7} B: {l1[ln]}  [{f1}]")
            line(f"                    {l2[ln]}  [{f2}]")
    return findings


def same_kind(names):
    """True if every name is the same absorb label / call kind."""
    def key(x):
        if x.startswith("absorb `"):
            return x.split("`")[1]
        return x
    return len({key(x) for x in names}) == 1


def classify(names):
    """How are these separated, if not by length?

    'NOTHING STRUCTURAL'  -- neither input carries a fixed distinguishing
                             string at a fixed offset (node vs leaf).
    'A FIXED STRING, probabilistically' -- at least one side carries a
                             literal at a fixed offset, so a coincidence
                             needs a hash output to spell it: 2^-8|literal|
                             at worst, and in practice a 32-byte state
                             collision, 2^-256.
    """
    tagged = []
    for n in names:
        if n.startswith("absorb `"):
            tagged.append(True)          # label bytes at a fixed offset
        elif "spec digest" in n or "identity" in n or "statement" in n:
            tagged.append(True)          # an ASCII DOMAIN literal first
        elif "constructor" in n:
            tagged.append(True)          # b"hashline-v1/" first
        else:
            tagged.append(False)         # node, leaf, column, refill: no tag
    if not any(tagged):
        return "NOTHING STRUCTURAL"
    if all(tagged):
        return "fixed literals at fixed offsets, in BOTH -- deterministic"
    return "a fixed literal on ONE side only -- probabilistic"


def dangerous_rows(s, run=None):
    """Row counts whose column digest (8*rows) equals SOME OTHER input length
    on this path -- the completed C-H4 set, plus the lengths the lane's guard
    does not carry (the statement digests and the seed derivation)."""
    L = run["L"] if run else None
    rp = run["profile_len"] if run else None
    guarded = {}          # length -> description, as hash_domain.rs builds it
    for what, ln in transcript_inputs(s, rp, L):
        guarded[ln] = what
    guarded[SQUEEZE_LEN] = "a transcript squeeze"
    guarded[REFILL_LEN] = "the generator's refill block"
    guarded[NODE_LEN] = "a Merkle inner node or a salted leaf"
    unguarded = {}        # NOT in hash_domain.rs at 8c5922b
    for what, ln in statement_digests(s, L) + seed_inputs(s):
        unguarded[ln] = what
    g = sorted({ln // 8: w for ln, w in guarded.items() if ln % 8 == 0}.items())
    u = sorted({ln // 8: w for ln, w in unguarded.items()
                if ln % 8 == 0}.items())
    return g, u


def main():
    line("#" * 92)
    line("# PART B -- the complete query-class table, computed")
    line("#" * 92)

    all_findings = []
    for name, s in SHAPES.items():
        all_findings += [(name,) + f for f in report_shape(name, s)]
    for rname, r in RUNS.items():
        s = SHAPES[r["shape"]]
        all_findings += [(rname,) + f for f in report_shape(rname, s, r)]

    line()
    line("#" * 92)
    line("# EVERY PAIR SEPARATED BY NOTHING STRUCTURAL (same function, same")
    line("# length), collected")
    line("#" * 92)
    if not all_findings:
        line("  none")
    seen = set()
    for row in all_findings:
        key = (row[1], row[2], tuple(row[3]))
        if key in seen:
            continue
        seen.add(key)
        line(f"  [{row[0]:<16}] {row[1]}  at {row[2]} B:")
        for w in row[3]:
            line(f"        - {w}")

    line()
    line("#" * 92)
    line("# DANGEROUS ROW COUNTS: a commitment with this many rows has a")
    line("# column digest of the same length as the named input")
    line("#" * 92)
    for name, s in SHAPES.items():
        g, u = dangerous_rows(s)
        real = [s["a_rows"], s["h_rows"], s["m_rows"], s["e_rows"]] + \
               ([s["b_rows"]] if s["b_rows"] else [])
        line()
        line(f"--- {name} (rule {s['rule']}); real row counts: {real}")
        gd = dict(g)
        u_only = [(k, w) for k, w in u if k not in gd]
        line(f"    GUARDED by hash_domain.rs (imposed only under the legacy "
             f"rule): {[k for k, _ in g]}")
        line(f"    DANGEROUS AND IN NO GUARD: {[k for k, _ in u_only]}")
        for k, w in u_only:
            line(f"        rows={k:<4} -> {8*k} B = {w}")
        hit = [r for r in real if r in gd or r in dict(u)]
        line(f"    any real commitment on a dangerous count? "
             f"{hit if hit else 'no'}")
        assert not hit, f"{name}: a real commitment is on a dangerous count"

    line()
    line("#" * 92)
    line("# THE 47-BYTE MARGIN (ruling H-8) AND THE 40-BYTE CLASS (claim N5)")
    line("#" * 92)
    line(f"  squeeze length = {SQUEEZE_LEN}; a constructor is "
         f"{NEW_FIXED} + |domain|, so |domain| = {SQUEEZE_LEN - NEW_FIXED} "
         f"is the dangerous one.")
    for name, s in SHAPES.items():
        line(f"    block {name:<8} |domain| = {len(s['profile']):>2}  "
             f"constructor = {NEW_FIXED + len(s['profile']):>3}")
    for rname, r in RUNS.items():
        line(f"    {rname:<16} |domain| = {r['profile_len']:>2}  "
             f"constructor = {NEW_FIXED + r['profile_len']:>3}")
    nearest = min(abs(SQUEEZE_LEN - NEW_FIXED - len(s["profile"]))
                  for s in SHAPES.values())
    nearest_run = min(abs(SQUEEZE_LEN - NEW_FIXED - r["profile_len"])
                      for r in RUNS.values())
    line(f"  nearest block profile to the dangerous 35: {nearest} byte(s) away")
    line(f"  nearest run   profile to the dangerous 35: {nearest_run} "
         f"byte(s) away  <- the 125M run profile, ruling H-8's margin")
    line()
    line(f"  refill length = {REFILL_LEN}.  Which other inputs are {REFILL_LEN}"
         " bytes?")
    line(f"    a 5-row commitment's column digest (8 x 5 = 40)")
    line(f"    a transcript constructor on a 28-byte domain "
         f"({NEW_FIXED} + 28 = 40): private_seam.rs:26 "
         f"(b\"experimental-private-seam/v1\") and public_block_receipt.rs:20 "
         f"(b\"zk60-public-block-receipt-v1\"), both UNKEYED, both off the "
         f"block path")
    for L in (1, 3, 12, 100):
        assert 29 + 32 * L != 40
    line(f"    the run public statement 29 + 32L: never 40 "
         f"(29 + 32L == 40 has no integer solution)  [COMPUTED]")
    line()
    line("#" * 92)
    line("# THE `pb-term` / BOUNDARY-SPEC COINCIDENCE AT 151 BYTES")
    line("#" * 92)
    line("  absorb `pb-term` with k terminals is 48 + 7 + 16k = 55 + 16k B.")
    line("  55 + 16k = 151  <=>  k = 6.  The internal boundary spec digest")
    line("  (boundary.rs:211) is 151 B, UNKEYED at every rule.")
    line("  At a TAGGED profile the absorb is in F_T and the digest in F_U:")
    line("  mode/key separated.  At a LEGACY profile both would be F_U -- and")
    line("  a legacy profile has no boundary, so the pair is CROSS-PROFILE: a")
    line("  legacy toy proof's pb-term(6) and a tagged run's boundary digest")
    line("  are the same unkeyed function's queries on one machine.")
    line("  [UNVERIFIED whether any slot's pb-term really carries 6 terminals:")
    line("   the range 1..56 used here is an over-approximation of what")
    line("   hash_domain.rs:172-182 builds.  Work-list item W-6.]")
    line()
    line("  Which absorb lengths can a COLUMN digest (8*rows) ever hit?")
    line("    pb-term  = 55 + 16k == 7 mod 16, a column digest is 0 or 8 mod")
    line("    16, so NEVER.  [PROVED]")
    for k in range(1, 57):
        assert (55 + 16 * k) % 8 != 0
    line("    (checked for k = 1..56: none is a multiple of 8)  [COMPUTED]")
    line()
    line("ALL ASSERTIONS PASSED.")


if __name__ == "__main__":
    main()
