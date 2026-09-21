#!/usr/bin/env python3
"""The probability space, segment by segment: are the positions disjoint and
witness-independent, and what a rejection sampler would have cost.

Evidence for ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md, Part A claims A-1..A-9.

Everything here transcribes the code at lane commit 8c5922b:

  zkp-core/src/rng.rs:63-99   next_u64 = 8 B; fp = 16 B; fp2 = 32 B;
                              bytes32 = 32 B.  RNG_BLOCK = 8192 is a multiple
                              of 8, so a byte offset is exactly 8 x (#u64).
  zkp-core/src/field.rs:36-38 Fp::from_u128(v) = v % P  -- MODULAR REDUCTION.
  zkp-core/src/pcs.rs:777-778 per commitment: pads (fp_vec(rows*Q)) THEN
                              salts (nn x bytes32).  Same order on the legacy
                              twin, pcs.rs:724-725.
  hashline/src/zk.rs:485-513  M: 23 CFS masks, then 46 per-row pad blocks,
                              then b_re,b_im,u_re,u_im, then 4096 salts.
  protocol.rs:655-658         A mask+proximity rows
  protocol.rs:757-769         H mask+proximity rows, then the two zero-sum
                              rows: n-1 draws each, last entry COMPUTED.
  protocol.rs:486 / run.rs:475 / endpoint_g.rs:224 / private_seam.rs:196
                              every ZkRng::from_os on the path.
  run.rs:475 + :487 loop      ONE generator for a whole run, threaded by
                              &mut across all L stages and L-1 boundaries.

What it prints:
  1. the ordered segment table with exact byte offsets, per shape;
  2. a machine check that the segments are pairwise disjoint and that the
     total matches the project's counted figures;
  3. the same for a run, with the per-stage offsets;
  4. an exact small-model computation of what a REJECTION sampler would have
     done to the argument -- the conclusion survives by a stopping-time
     argument, but not by "disjoint fixed positions".

Run:  python3 stream_positions.py
"""

from fractions import Fraction as Fr
import itertools
import random

# ---------------------------------------------------------------------------
# shape constants, transcribed from hashline/src/private_block/shape.rs and
# layout.rs at 8c5922b (see the README for every file:line).
# ---------------------------------------------------------------------------

Q_OPEN = 256          # shape.rs:51 COL_CHECKS; ZkOpts::standard q_pad = it
MASK_Q = 256          # zk.rs:375
MASK_M = 512          # 1 << MASK_LOG_MSG, zk.rs:373
MASK_DOM = 4096       # 1 << MASK_LOG_DOM, zk.rs:374
N_SLOTS = 23          # layout.rs:797

SHAPES = {
    # name: log_cols, inv_rate, a_rows, a_data, h_rows, h_data, sum_Ls,
    #       endpoint_log_n, endpoint_inv_rate, endpoint_rows, endpoint_kind
    "toy":      dict(log_cols=8,  inv_rate=8, a_rows=455,   a_data=213,
                     h_rows=384,  h_data=280, sum_Ls=583,
                     e_log=8,  e_rate=8, e_rows=7,  e_kind="frozen seam"),
    "rung":     dict(log_cols=10, inv_rate=4, a_rows=623,   a_data=377,
                     h_rows=576,  h_data=470, sum_Ls=859,
                     e_log=8,  e_rate=8, e_rows=21, e_kind="frozen seam"),
    "rung-G":   dict(log_cols=10, inv_rate=4, a_rows=623,   a_data=377,
                     h_rows=576,  h_data=470, sum_Ls=859,
                     e_log=10, e_rate=4, e_rows=9,  e_kind="generalised"),
    "rung-K4":  dict(log_cols=10, inv_rate=4, a_rows=727,   a_data=481,
                     h_rows=720,  h_data=614, sum_Ls=871,
                     e_log=10, e_rate=4, e_rows=9,  e_kind="generalised"),
    "125M":     dict(log_cols=14, inv_rate=4, a_rows=5681,  a_data=5435,
                     h_rows=7120, h_data=7018, sum_Ls=1239,
                     e_log=14, e_rate=4, e_rows=37, e_kind="generalised"),
}

# the project's counted fp() totals of record, for the cross-check
FP_OF_RECORD = {          # per BLOCK BODY (no endpoints)
    "toy": 320_908,       # 327,052 minus the two endpoints' 6,144
    "rung": 687_028,      # ruling H-6
    "rung-G": 687_028,
    "rung-K4": 750_540,
    "125M": 9_029_804,
}


def seg(name, kind, count, published):
    """one segment: kind in {'fp','bytes32'}; count = number of draws."""
    width = 16 if kind == "fp" else 32
    return dict(name=name, kind=kind, count=count, bytes=width * count,
                published=published)


def block_segments(s):
    """The ordered segment list of ONE block body, from the code."""
    n = 1 << s["log_cols"]
    nn = n * s["inv_rate"]
    out = [
        # protocol.rs:655-658
        seg("A mask + proximity rows", "fp", (s["a_rows"] - s["a_data"]) * n, False),
        # pcs.rs:777
        seg("A pads", "fp", s["a_rows"] * Q_OPEN, False),
        # pcs.rs:778  -- PUBLISHED (the 256 sampled slots of them)
        seg("A salts", "bytes32", nn, True),
        # zk.rs:485  (CfsMask::random = fp2_vec, 2 Fp per coefficient)
        seg("M CFS mask coefficients", "fp", 2 * s["sum_Ls"], False),
        # zk.rs:496, 46 a-rows
        seg("M per-row pads", "fp", 2 * N_SLOTS * MASK_Q, False),
        # zk.rs:503-508
        seg("M b_re,b_im,u_re,u_im", "fp", 4 * 2 * MASK_M, False),
        # zk.rs:513
        seg("M salts", "bytes32", MASK_DOM, True),
        # protocol.rs:757-759
        seg("H mask + proximity rows", "fp", (s["h_rows"] - s["h_data"]) * n, False),
        # protocol.rs:760-768 -- n-1 draws per row, last entry COMPUTED
        seg("H zero-sum rows", "fp", 2 * (n - 1), False),
        # pcs.rs:777
        seg("H pads", "fp", s["h_rows"] * Q_OPEN, False),
        # pcs.rs:778
        seg("H salts", "bytes32", nn, True),
    ]
    return out


def endpoint_segments(s):
    """ONE external endpoint, on its OWN generator (endpoint_g.rs:224 /
    private_seam.rs:196).  MASK_ROWS = 5 (endpoint_g.rs:52)."""
    ne = 1 << s["e_log"]
    nne = ne * s["e_rate"]
    return [
        seg("endpoint mask rows (5)", "fp", 5 * ne, False),
        seg("endpoint pads", "fp", s["e_rows"] * Q_OPEN, False),
        seg("endpoint salts", "bytes32", nne, True),
    ]


def boundary_segments(s):
    """ONE internal boundary, on the RUN's generator (boundary.rs:315-328)."""
    ne = 1 << s["e_log"]
    nne = ne * s["e_rate"]
    return [
        seg("boundary mask rows (6)", "fp", 6 * ne, False),
        seg("boundary pads", "fp", (s["e_rows"] + 1) * Q_OPEN, False),
        seg("boundary salts", "bytes32", nne, True),
    ]


def lay_out(segments, start=0):
    """Assign byte ranges in order; return (rows, end)."""
    rows = []
    off = start
    for sg in segments:
        rows.append((sg["name"], sg["kind"], sg["count"], off,
                     off + sg["bytes"], sg["published"]))
        off += sg["bytes"]
    return rows, off


def check_disjoint(rows):
    """Every pair of ranges is disjoint (they are consecutive by
    construction; this asserts the construction)."""
    for (n1, _, _, a1, b1, _), (n2, _, _, a2, b2, _) in itertools.combinations(rows, 2):
        assert b1 <= a2 or b2 <= a1, f"overlap: {n1} and {n2}"
    return True


def line(s=""):
    print(s)


def part1_block_tables():
    line("=" * 100)
    line("1. THE ORDERED SEGMENT TABLE OF ONE BLOCK BODY (one generator, "
         "protocol.rs:486)")
    line("=" * 100)
    for name, s in SHAPES.items():
        segs = block_segments(s)
        rows, end = lay_out(segs)
        check_disjoint(rows)
        fp = sum(sg["count"] for sg in segs if sg["kind"] == "fp")
        salts = sum(sg["count"] for sg in segs if sg["kind"] == "bytes32")
        line()
        line(f"--- {name}  (n = {1 << s['log_cols']}, nn = "
             f"{(1 << s['log_cols']) * s['inv_rate']}) ---")
        line(f"{'#':>3} {'segment':<28} {'kind':>8} {'draws':>12} "
             f"{'byte start':>14} {'byte end':>14}  pub")
        for i, (nm, kd, ct, a, b, pub) in enumerate(rows, 1):
            line(f"{i:>3} {nm:<28} {kd:>8} {ct:>12,} {a:>14,} {b:>14,}  "
                 f"{'YES' if pub else '-'}")
        line(f"    total fp() draws = {fp:,}   salts = {salts:,}   "
             f"stream bytes = {end:,}")
        exp = FP_OF_RECORD[name]
        mark = "MATCHES the counted figure" if fp == exp else \
               f"DIFFERS from the counted figure {exp:,}"
        line(f"    cross-check against the project's count: {exp:,} -- {mark}")
        assert fp == exp, f"{name}: {fp} != {exp}"
    line()
    line("  Every count above is built from shape constants only: row counts,")
    line("  n, nn, Q = 256, MASK_Q, MASK_M, MASK_DOM, sum_Ls, N_SLOTS.")
    line("  No expression on the right of any '=' is a witness value.")
    line("  [COUNTED from the code; the totals reproduce the figures of")
    line("   record, D9's 327,052 at the toy and ruling H-6's at the rest.]")


def part2_toy_whole_proof():
    line()
    line("=" * 100)
    line("2. THE TOY PROOF AS A WHOLE: THREE GENERATORS")
    line("=" * 100)
    s = SHAPES["toy"]
    body = block_segments(s)
    _, body_end = lay_out(body)
    ep = endpoint_segments(s)
    _, ep_end = lay_out(ep)
    body_fp = sum(x["count"] for x in body if x["kind"] == "fp")
    ep_fp = sum(x["count"] for x in ep if x["kind"] == "fp")
    line(f"  generator 1 -- the block, protocol.rs:486, domain = the profile")
    line(f"      {body_fp:,} fp() draws, {body_end:,} stream bytes")
    line(f"  generator 2 -- the input endpoint, private_seam.rs:196")
    line(f"  generator 3 -- the output endpoint, private_seam.rs:196")
    line(f"      {ep_fp:,} fp() draws each, {ep_end:,} stream bytes each")
    total = body_fp + 2 * ep_fp
    line(f"  TOTAL fp() draws = {body_fp:,} + 2 x {ep_fp:,} = {total:,}")
    line(f"  decision D9 / the accepted statement carry 327,052.  "
         f"{'MATCHES' if total == 327052 else 'DIFFERS'}")
    assert total == 327_052
    line()
    line("  Independence between the three: INFORMATION-THEORETIC, not M-3 --")
    line("  three separate /dev/urandom reads (rng.rs:45-46), each keying its")
    line("  own stream.  (Correction C-11 of the toy joint-law memo.)")
    line("  Independence WITHIN generator 1 -- between the salt segments and")
    line("  the blinding segments -- is M-3 and nothing else.")


def part3_run():
    line()
    line("=" * 100)
    line("3. A RUN: ONE GENERATOR FOR THE WHOLE RUN (run.rs:475), PLUS TWO")
    line("=" * 100)
    for name, L in (("rung-G", 3), ("rung-K4", 3), ("125M", 12)):
        s = SHAPES[name]
        body = block_segments(s)
        bnd = boundary_segments(s)
        ep = endpoint_segments(s)
        body_bytes = lay_out(body)[1]
        bnd_bytes = lay_out(bnd)[1]
        body_fp = sum(x["count"] for x in body if x["kind"] == "fp")
        bnd_fp = sum(x["count"] for x in bnd if x["kind"] == "fp")
        ep_fp = sum(x["count"] for x in ep if x["kind"] == "fp")
        # stage order (run.rs:487-572): boundary B_k committed for k+1 < L,
        # then prove_core for stage k.
        rows = []
        off = 0
        for k in range(L):
            if k + 1 < L:
                rows.append((f"stage {k}: boundary B_{k}", off, off + bnd_bytes))
                off += bnd_bytes
            rows.append((f"stage {k}: block body", off, off + body_bytes))
            off += body_bytes
        run_fp = L * body_fp + (L - 1) * bnd_fp
        line()
        line(f"--- {name}, L = {L} ---")
        line(f"  per block body : {body_fp:,} fp, {body_bytes:,} B")
        line(f"  per boundary   : {bnd_fp:,} fp, {bnd_bytes:,} B")
        line(f"  RUN STREAM     : {run_fp:,} fp over {off:,} bytes, "
             f"{L} blocks + {L-1} boundaries = {4*L+1-2} commitments")
        line(f"  + two external endpoints on their OWN generators, "
             f"{ep_fp:,} fp each")
        line(f"  TOTAL fp() of the run = {run_fp + 2*ep_fp:,}")
        line(f"  first / last stage offsets:")
        line(f"    {rows[0][0]:<28} [{rows[0][1]:,} .. {rows[0][2]:,})")
        line(f"    {rows[-1][0]:<28} [{rows[-1][1]:,} .. {rows[-1][2]:,})")
        line(f"  the offset of stage k is k*(block) + min(k, L-1)*(boundary):")
        line(f"  a function of k and the shape, and of nothing else.")
        if name == "125M" and L == 12:
            line(f"  ruling H-6 carries 109,728,784 for this run "
                 f"(blocks + boundaries + the two endpoints).")
            line(f"  this script's total: {run_fp + 2*ep_fp:,}  -- "
                 f"{'MATCHES' if run_fp + 2*ep_fp == 109_728_784 else 'DIFFERS'}")


def part4_rejection_sampler():
    line()
    line("=" * 100)
    line("4. WHAT A REJECTION SAMPLER WOULD HAVE COST THE ARGUMENT")
    line("=" * 100)
    line("The code does NOT reject: Fp::from_u128 is `v % P` (field.rs:37),")
    line("so fp() consumes exactly 16 bytes whatever it draws.  The question")
    line("is what the argument would have needed if it did, because the")
    line("independence clause is currently justified by DISJOINT FIXED")
    line("POSITIONS, and rejection makes the positions random.")
    line()
    line("Exact model.  Stream of i.i.d. uniform symbols on {0,1,2,3}.  A")
    line("'draw' rejects the symbol 3 and retries; the value is the accepted")
    line("symbol.  Two draws, then one 'salt' symbol.  Everything exact.")
    line()
    # exact law over stream prefixes: enumerate prefixes up to a depth,
    # tracking (value1, value2, salt) and the probability.
    S = 4
    ACCEPT = 3          # symbols 0,1,2 accepted; 3 rejected
    DEPTH = 14
    joint = {}
    def walk(prefix_prob, pos, got, vals, depth_left):
        # got: how many draws accepted so far
        if got == 2:
            # the next symbol is the salt
            for s in range(S):
                key = (tuple(vals), s)
                joint[key] = joint.get(key, Fr(0)) + prefix_prob * Fr(1, S)
            return
        if depth_left == 0:
            return          # truncated mass, accounted below
        for sym in range(S):
            p = prefix_prob * Fr(1, S)
            if sym < ACCEPT:
                walk(p, pos + 1, got + 1, vals + [sym], depth_left - 1)
            else:
                walk(p, pos + 1, got, vals, depth_left - 1)
    walk(Fr(1), 0, 0, [], DEPTH)
    mass = sum(joint.values())
    line(f"  enumerated mass (truncated at depth {DEPTH}) = {mass} "
         f"= 1 - {1 - mass}")
    # marginal of the salt, and conditional independence
    salt_marg = {}
    for (v, s), p in joint.items():
        salt_marg[s] = salt_marg.get(s, Fr(0)) + p
    line(f"  salt marginal (should be mass/4 each): "
         f"{sorted(set(salt_marg.values()))}")
    assert len(set(salt_marg.values())) == 1, "salt marginal is not uniform"
    # independence: joint(v,s) == joint_v(v) * (1/4)
    val_marg = {}
    for (v, s), p in joint.items():
        val_marg[v] = val_marg.get(v, Fr(0)) + p
    worst = max(abs(p - val_marg[v] * Fr(1, S)) for (v, s), p in joint.items())
    line(f"  max |joint(v,s) - P(v)*1/4| over all (v,s) = {worst}")
    assert worst == 0, "rejection sampling broke independence"
    line()
    line("  -> with rejection the salt is STILL exactly uniform and STILL")
    line("     exactly independent of the accepted values -- but NOT because")
    line("     its position is fixed: its position is the random stopping")
    line("     time T = (number of symbols consumed).  The reason is the")
    line("     STRONG MARKOV property of an i.i.d. stream: for a stopping")
    line("     time T of the stream filtration, the post-T stream is i.i.d.")
    line("     uniform and independent of F_T.")
    line()
    line("  Two consequences for the memo, and they point opposite ways:")
    line("   (a) the CONCLUSION would survive rejection sampling;")
    line("   (b) the ARGUMENT would not -- 'disjoint fixed positions' would")
    line("       have to be replaced by a stopping-time argument, and the")
    line("       stopping time would have to be shown WITNESS-FREE, which is")
    line("       a strictly stronger reading of the draw-accounting test.")
    line("  Since fp() reduces rather than rejects, the project needs only")
    line("  the weaker reading -- and that is a fact of `field.rs:37`, which")
    line("  no test pins as a privacy-relevant property.")


def main():
    part1_block_tables()
    part2_toy_whole_proof()
    part3_run()
    part4_rejection_sampler()
    print()
    print("ALL ASSERTIONS PASSED.")


if __name__ == "__main__":
    main()
