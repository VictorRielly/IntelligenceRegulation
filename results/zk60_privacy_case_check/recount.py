#!/usr/bin/env python3
"""Independent recount of the numbers in ZK60_PRIVACY_CASE_FIRST_MVP.md.

Every input is read from the Rust source by hand (file:line in the check
document); nothing here runs the prover.  No witness value is used.
"""
from fractions import Fraction
import math

out = []
def say(s=""):
    out.append(s)
    print(s)

def lg(x):
    return math.log2(x)

# ---------------------------------------------------------------- layout facts
# hashline/src/private_block/layout.rs
T, D, H, DH, KV, F = 32, 16, 2, 8, 8, 16
LOG_N, N = 8, 256
SLOTS = [(9,1,3),(9,1,3),(5,1,3),(9,1,4),(11,1,3),(4,1,2),(4,1,2),(4,1,2),
         (3,2,2),(5,2,2),(4,1,2),(4,1,2),(4,1,2),(4,1,2),(9,1,4),(9,1,4),
         (8,1,4),(11,1,4),(9,1,4),(8,1,3),(8,1,2),(9,1,2),(9,1,2)]
A_SITES = [1,1,22,2,2,1,1,1,2,2,1,1,1,1,37,8,7,13,11,3,0,1,1]
H_SITES = [0,0,0,1,0,0,0,0,0,0,0,0,0,0,19,7,6,8,6,3,1,0,0]
N_SLOTS = len(SLOTS)
A_ROWS, H_ROWS, A_DATA, H_DATA = 455, 384, 213, 280
M_ROWS = 2*N_SLOTS + 4
A_GROUPS, H_GROUPS = 35, 9
ENDPOINT_ROWS = 7
SC_IO_IN = 21
def slot_terms(s):
    return A_SITES[s] + H_SITES[s] + (1 if s >= SC_IO_IN else 0)
L = [(n+e)*d + 2 for (n,e,d) in SLOTS]

say("== layout ==")
say(f"sum L_s = {sum(L)}   max L_s = {max(L)}   (draft: 583 / 50)")
say(f"M_ROWS = {M_ROWS} (draft 50); slot terminals = {sum(slot_terms(s) for s in range(N_SLOTS))} (draft 173)")

# ---------------------------------------------------------------- receipt bytes
# hashline/src/private_block/wire.rs:28-36
HEADER = 8 + 32
CHECKS, VEC, ENC_COLS, PATH = 256, 512, 2048, 11
MASK_VEC, MASK_DOM, MASK_PATH = 1024, 4096, 12

def opening_len(groups, rows):
    return (groups+1)*VEC*16 + CHECKS*(8 + rows*8 + 32 + PATH*32)

slots_bytes = sum((1 + (n+e)*(d+1) + slot_terms(s))*16
                  for s,(n,e,d) in enumerate(SLOTS))
mask_bytes = 2*MASK_VEC*16 + CHECKS*(8 + M_ROWS*8 + 32 + MASK_PATH*32)
encoded_len = (HEADER + 3*32 + slots_bytes + mask_bytes
               + opening_len(A_GROUPS, A_ROWS) + opening_len(H_GROUPS, H_ROWS)
               + 2*opening_len(1, ENDPOINT_ROWS))
say()
say("== receipt bytes (wire.rs::encoded_len recomputed) ==")
say(f"header+roots        {HEADER + 3*32}")
say(f"slots               {slots_bytes}")
say(f"mask opening        {mask_bytes}")
say(f"A opening           {opening_len(A_GROUPS, A_ROWS)}")
say(f"H opening           {opening_len(H_GROUPS, H_ROWS)}")
say(f"endpoint opening x2 {2*opening_len(1, ENDPOINT_ROWS)}")
say(f"TOTAL               {encoded_len}   (measured / draft: 2816472)")

# the draft's byte-class table, recomputed
rows_total = A_ROWS + H_ROWS + 2*ENDPOINT_ROWS + M_ROWS
cls = {
 "roots (3x32)": 3*32,
 "group vectors (46 x 512 Fp2)": 46*VEC*16,
 "PCS proximity vectors (4 x 512 Fp2)": 4*VEC*16,
 "opened column values (5 x 256 x rows x 8B)": CHECKS*rows_total*8,
 "column indices (5 x 256 x 8B)": 5*CHECKS*8,
 "leaf salts (5 x 256 x 32B)": 5*CHECKS*32,
 "auth paths (4 x 256 x 11 + 256 x 12) x 32B": CHECKS*(4*PATH + MASK_PATH)*32,
 "M opening q (1024 Fp2)": MASK_VEC*16,
 "M proximity (1024 Fp2)": MASK_VEC*16,
}
say()
say("== byte classes ==")
for k,v in cls.items():
    say(f"{k:48s} {v:9d}")
subtotal = sum(cls.values())
say(f"{'subtotal (openings + roots)':48s} {subtotal:9d}   (draft 2801760)")
say(f"{'residue = slots + wire framing':48s} {encoded_len - subtotal:9d}   (draft 14712)")
say(f"{'  of which the 40-byte wire envelope':48s} {HEADER:9d}")
say(f"{'  of which slot payload':48s} {slots_bytes:9d}")
say(f"hash material (salts + paths)  {cls['leaf salts (5 x 256 x 32B)'] + cls['auth paths (4 x 256 x 11 + 256 x 12) x 32B']}"
    f"  = {100*(cls['leaf salts (5 x 256 x 32B)'] + cls['auth paths (4 x 256 x 11 + 256 x 12) x 32B'])/encoded_len:.1f} % of the receipt (draft 499712 / 17.7 %)")
say(f"one endpoint opening {opening_len(1, ENDPOINT_ROWS)} B, of which hash "
    f"{CHECKS*(32+PATH*32)} B = {100*CHECKS*(32+PATH*32)/opening_len(1,ENDPOINT_ROWS):.0f} %")

# ---------------------------------------------------------------- fp() draws
# every site read from the source:
#   protocol.rs:313-315  A mask rows           (A_ROWS - A_DATA) * N
#   pcs.rs:673           A pads                A_ROWS * q_pad,  q_pad = 256
#   pcs.rs:674           A salts               2048 * bytes32   (NOT fp)
#   zk.rs:433            23 CFS masks          2 * sum L_s      (fp2_vec)
#   zk.rs:446            M pads                46 * 256
#   zk.rs:451-455        b_re,b_im,u_re,u_im   4 * 1024
#   zk.rs:458            M salts               4096 * bytes32   (NOT fp)
#   protocol.rs:361-363  H mask rows           (H_ROWS - H_DATA) * N
#   protocol.rs:364-372  the two zero-sum rows 2 * (N-1)
#   pcs.rs:673           H pads                H_ROWS * 256
#   seam prepare         2 x (5 mask rows + 7 pad rows) * 256
Q = 256
draws = {
 "A mask rows  (455-213)*256": (A_ROWS-A_DATA)*N,
 "A pads       455*256":        A_ROWS*Q,
 "H mask rows  (384-280)*256": (H_ROWS-H_DATA)*N,
 "H zero-sum rows 2*255":       2*(N-1),
 "H pads       384*256":        H_ROWS*Q,
 "23 CFS masks 2*sum L_s":      2*sum(L),
 "M pads       46*256":         2*N_SLOTS*256,
 "b,u          4*1024":         4*1024,
 "endpoints  2*(5+7)*256":      2*(5+7)*256,
}
say()
say("== fp() draws in one toy block proof ==")
for k,v in draws.items():
    say(f"{k:30s} {v:8d}")
total_draws = sum(draws.values())
say(f"{'TOTAL':30s} {total_draws:8d}  = 2^{lg(total_draws):.3f}   (draft 327052, 2^18.3)")
salt_draws = (2048*3 + 4096 + 2048)  # A,H,In,Out trees 2048 leaves each + M 4096
say(f"bytes32 salt draws (not fp): {2048*4 + 4096} = {2048*4+4096}")

# ---------------------------------------------------------------- fp() bias
P = (1<<64) - (1<<32) + 1
M128 = 1 << 128
k, r = divmod(M128, P)          # r residues appear k+1 times, P-r appear k times
tv = Fraction(r*(P-r), P*M128)  # total variation distance, exact
say()
say("== fp() reduction bias (rng.rs:72-77, Fp::from_u128) ==")
say(f"2^128 mod p = {r}   = p - 2^32 ? {r == P - (1<<32)}")
say(f"residues appearing {k+1} times: {r};  appearing {k} times: {P-r}")
say(f"exact TV distance per draw = {float(tv):.6e} = 2^{lg(float(tv)):.4f}  (D9: 2^-96)")
for label, n in [("toy block", total_draws), ("draft's 125M count", 9_257_800)]:
    tot = float(tv)*n
    say(f"{label:20s}: {n} draws -> total <= 2^{lg(tot):.2f}")

# ---------------------------------------------------------------- LogUp zero denominator
# protocol.rs:289-357.  One denominator per lookup value, per exp position, per
# activation position, and one per table row of each of the three tables.
per_dom = {"L": 2*512, "D": 38*512, "F": 9*512, "Q": 13*512, "Kv": 12*256, "S": 13*2048}
u8_lookups = sum(per_dom.values())
exp_den = H*T*T
act_den = T*F
table_rows = 3*256
den_total = u8_lookups + exp_den + act_den + table_rows
F2 = P*P
say()
say("== the zero-LogUp-denominator event ==")
say(f"U8 lookup values {u8_lookups} (layout test asserts 61440: {u8_lookups==61440})")
say(f"exp {exp_den}, act {act_den}, table helpers {table_rows}")
say(f"denominators drawn = {den_total} = 2^{lg(den_total):.3f}")
say(f"|Fp2| = p^2 = 2^{lg(float(F2)):.4f}")
say(f"union bound = {den_total}/|Fp2| = 2^{lg(den_total/float(F2)):.3f}   (draft: about 2^-113)")

# ---------------------------------------------------------------- Merkle exposure
def exposure(nn, checks, levels):
    distinct = nn*(1 - (1 - 1/nn)**checks)
    # revealed leaf digests: opened leaves + their siblings (bounded above by 2*distinct)
    # count nodes revealed by `checks` independent paths, exactly, in expectation
    # level 0 = leaves; a node is revealed if it is a sibling of a node on some path
    tot_nodes = 0.0
    revealed_leaf_digests = 0.0
    size = nn
    p_not = (1 - 1/nn)**checks     # per-leaf probability of never being opened
    # expected number of level-l nodes that contain at least one opened leaf
    for l in range(levels):
        span = nn // size          # leaves under one node at this level
        occupied = size*(1 - p_not**span)
        # each occupied node's sibling digest is published unless the sibling is
        # itself occupied (then it is recomputed)
        sib_published = occupied*( (p_not**span) )  # sibling empty
        tot_nodes += occupied + sib_published
        if l == 0:
            revealed_leaf_digests = occupied + sib_published
            unopened_published = sib_published
        size //= 2
    return distinct, revealed_leaf_digests, unopened_published, tot_nodes

d, rl, unop, nodes = exposure(2048, 256, 11)
say()
say("== Merkle exposure per 2048-leaf tree (my own model) ==")
say(f"distinct opened leaves {d:.1f} (draft 240.7)")
say(f"leaf digests revealed  {rl:.1f} (draft 453.2); of unopened columns {unop:.1f} (draft 212.5)")
say(f"nodes revealed (all levels, incl. leaves) {nodes:.1f}; draft 1654.8 of 4095 = {100*1654.8/4095:.1f} %")

with open("/home/victor/IntelligenceRegulation/results/zk60_privacy_case_check/recount.txt", "w") as f:
    f.write("\n".join(out) + "\n")
