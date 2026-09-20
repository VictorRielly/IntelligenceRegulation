#!/usr/bin/env python3
"""Independent recomputation of the hash-layer counts and the reduction-bias
arithmetic quoted in docs/zkmatrix-poc/ZK60_D8_D11_RESTATEMENT.md.

Pure arithmetic; no repository code is imported and nothing is proved or run.
"""

from fractions import Fraction
import math


def ancestors(nn: int, draws: int):
    """Expected number of distinct level-j ancestors of `draws` leaves drawn
    uniformly WITH REPLACEMENT from nn leaves.  Level 0 = the leaves."""
    depth = nn.bit_length() - 1
    out = []
    for j in range(depth + 1):
        groups = nn >> j          # number of nodes at level j
        # P(a given level-j node has no draw below it) = (1 - 2^j/nn)^draws
        p_empty = Fraction(groups - 1, groups) ** draws
        out.append(groups * (1 - p_empty))
    return out  # out[0] = distinct opened leaves ... out[depth] = 1 (root)


def report(nn: int, draws: int = 256):
    depth = nn.bit_length() - 1
    A = ancestors(nn, draws)
    opened = A[0]
    # every child of a level-(j+1) ancestor becomes public (recomputed or
    # published as a sibling): revealed at level j = 2 * A_{j+1}
    revealed = [2 * A[j + 1] for j in range(depth)]
    leaf_digests = revealed[0]
    unopened_leaves = leaf_digests - opened
    internal = sum(revealed[1:])          # levels 1 .. depth-1
    total_nodes = sum(revealed) + 1       # + the root
    # distinct PUBLISHED siblings: at level j, siblings that are not themselves
    # ancestors = 2*A_{j+1} - A_j
    siblings = sum(2 * A[j + 1] - A[j] for j in range(depth))
    print(f"--- nn = {nn}, depth = {depth}, draws = {draws} ---")
    print(f"distinct opened leaves          {float(opened):.4f}")
    print("A_1..A_depth                   ",
          ", ".join(f"{float(a):.4f}" for a in A[1:]))
    print(f"leaf digests revealed           {float(leaf_digests):.4f}"
          f"  (= {float(opened):.4f} opened + {float(unopened_leaves):.4f} unopened)")
    print(f"internal nodes revealed (1..{depth-1})  {float(internal):.4f}")
    print(f"total distinct nodes revealed   {float(total_nodes):.4f} of {2*nn-1}"
          f"  = {100.0*float(total_nodes)/(2*nn-1):.2f} %")
    print(f"distinct sibling digests        {float(siblings):.4f}"
          f"  of {draws*depth} emitted slots")
    print(f"honest queries to build tree    {nn} cols + {nn} leaves + {nn-1} nodes"
          f" = {3*nn-1}")
    # top pair: A_{depth-1} and the exact deficit
    top = A[depth - 1]
    print(f"A_(depth-1) (the top pair)      {float(top):.12f}"
          f"   deficit 2 - A = 2^{math.log2(float(2 - top)):.1f}")
    print()


def opening_bytes(rows: int, depth: int, n_plus_q: int, checks: int = 256):
    return 2 * n_plus_q * 16 + checks * (8 + rows * 8 + 32 + depth * 32)


def bias():
    p = (1 << 64) - (1 << 32) + 1
    print("--- reduction bias of a 128-bit draw reduced mod p ---")
    print(f"p = 2^64 - 2^32 + 1 = {p}")
    print(f"2^128 mod p = {(1<<128) % p}   p - 2^32 = {p - (1<<32)}  "
          f"equal: {(1<<128) % p == p - (1<<32)}")
    N = 1 << 128
    q, s = divmod(N, p)          # s residues get q+1 draws, p-s residues get q
    print(f"floor(2^128/p) = q, remainder s = {s} = p - 2^32 -> "
          f"{s} residues occur {q+1} times, {p-s} residues occur {q} times "
          f"(p - s = 2^32: {p - s == 1 << 32})")
    tvd = Fraction(0)
    tvd += s * abs(Fraction(q + 1, N) - Fraction(1, p))
    tvd += (p - s) * abs(Fraction(q, N) - Fraction(1, p))
    tvd /= 2
    print(f"total statistical distance = {float(tvd):.6e} = 2^{math.log2(float(tvd)):.6f}")
    rel = abs(Fraction(q + 1, N) - Fraction(1, p)) / Fraction(1, p)
    print(f"relative bias of one over-represented outcome = "
          f"2^{math.log2(float(rel)):.6f}")
    rel_lo = abs(Fraction(q, N) - Fraction(1, p)) / Fraction(1, p)
    print(f"relative bias of one under-represented outcome = "
          f"2^{math.log2(float(rel_lo)):.6f}")
    for label, draws in (("tiny endpoint pair (O10 F10.4's 6144)", 6144),
                         ("a tiny proof, 2^21 draws", 1 << 21),
                         ("125M, 2^23.1 draws", int(2 ** 23.1)),
                         ("8B, 2^24.3 draws", int(2 ** 24.3))):
        print(f"  {label:38s}: {draws} * 2^-96 = "
              f"2^{math.log2(draws * float(tvd)):.2f}")
    print()


def sha_gadget():
    print("--- section 4.2 arithmetic ---")
    plane = 1 << 21
    comp_model = plane * 2 // 64
    print(f"model plane 2^21 words as int16 = {plane*2} B = {comp_model} compressions/endpoint")
    H = 4379 * 16384 * 32
    words = 18649 * 16384 * 32
    print(f"pass H = {H:.3e}, committed words = {words:.3e}")
    for lk, cw, tag in ((2000, 1250, "optimistic"), (4000, 2500, "central"), (8000, 5000, "pessimistic")):
        L = 2 * comp_model * lk
        W = 2 * comp_model * cw
        print(f"  {tag:12s}: lookups {L:.3e} = {100*L/H:.1f}% of H ; "
              f"words {W:.3e} = {100*W/words:.2f}% of committed")
    L = 2 * comp_model * 4000
    W = 2 * comp_model * 2500
    dt = 5.555 * (L / H) + W / 1.67e8
    print(f"central seconds on the 58.40 s public pass: "
          f"{5.555*(L/H):.2f} (helpers) + {W/1.67e8:.2f} (commit) = {dt:.2f} s"
          f"  -> {100*dt/58.40:.1f} % of the pass")
    print(f"if the pass ever reaches 5 s by a uniform {58.40/5:.1f}x speedup, the same "
          f"relative cost is {dt*5/58.40:.2f} s = {100*dt/58.40:.1f} % of the 5 s budget")
    comp_tiny = 512 * 2 // 64
    Ht = 1326 * 256
    print(f"tiny: {comp_tiny} compressions/endpoint, extra lookups "
          f"{2*comp_tiny*4000} = {100*2*comp_tiny*4000/Ht:.1f}% of H_tiny={Ht}, "
          f"extra words {2*comp_tiny*2500}")
    for name, rows in (("A", 702), ("H", 1326), ("M", 20), ("endpoints x2", 14)):
        print(f"   tiny committed words, {name}: {rows*256}")
    tot = (702 + 1326 + 20 + 14) * 256
    print(f"   tiny committed words total (message part) {tot} -> "
          f"extra words are {100*2*comp_tiny*2500/tot:.1f}%")
    print()


def bytes_table():
    print("--- opening bytes ---")
    print("tiny endpoint  rows=7 depth=11 n+Q=512 :",
          opening_bytes(7, 11, 512))
    print("log_cols14/inv_rate4, 2^21 plane: rows =", (1 << 21) // (1 << 14),
          "(+5 mask) =", (1 << 21) // (1 << 14) + 5,
          "depth = 16, n+Q = 16384+256 =", 16384 + 256)
    print("   bytes:", opening_bytes(133, 16, 16384 + 256))
    print("log_cols8/inv_rate8, 2^21 plane: rows =", (1 << 21) // 256,
          "(+5) =", (1 << 21) // 256 + 5, "depth = 11, n+Q = 512")
    print("   bytes:", opening_bytes(8197, 11, 512))
    print()


def transcript_domain():
    print("--- transcript absorb input lengths (zkp-core/src/transcript.rs:44-52) ---")
    for label, dlen in ((b"rows", 8), (b"log-cols", 8), (b"layer", 8),
                        (b"t_rows", 8), (b"io-side", 8), (b"pb-slot", 8),
                        (b"pa-slot", 8), (b"expected-IO", 112)):
        n = 32 + 8 + len(label) + 8 + dlen
        flag = "  <-- 64 bytes: SAME DOMAIN as hash_pair / salt_leaf" if n == 64 else ""
        print(f"  absorb({label!r:15s}, {dlen:3d} B) -> {n} B{flag}")
    print(f"  squeeze_bytes -> 32 + len(b'squeeze')=7 + 8 = {32+7+8} B")
    print()


if __name__ == "__main__":
    report(2048)
    report(65536)
    bytes_table()
    bias()
    sha_gadget()
    transcript_domain()
