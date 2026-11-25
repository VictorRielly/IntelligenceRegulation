#!/usr/bin/env python3
"""Tick 59 (queue item 93): weight classes beyond the block matrices that a P3 profile must commit.
Standard library only, reads no file. Shapes are quoted from the source (cited in the handoff):
  8B   : Llama-3-8B, width 4096 (d_pad 4096), hidden 14336 (f_pad 16384), q_width 4096, kv width 1024, T 128, 32 layers
         V 128,256 (V_pad 2^17), checkpoint_parameters 8,030,261,248                 trained_statement.rs:143
  Shield: Shieldstral-1.0-3B text tower, width 3072 (d_pad 4096), hidden 9216 (f_pad 16384), q_width 4096, kv 1024, 26 layers
         V 131,072, tied embedding, checkpoint_parameters 3,849,090,048 (image tower included) trained_statement.rs:163
  wire   = (G+1)(n+qpad)*16 + Q*(8 + 8*rows + 32 + 32*path)  (wire.rs:106-108, as in tick 54's script)
Tick 54's best row: n = 2^16, rate 1/4, budget k = 16, Q' = 172, qpad = k*Q' = 2752, one group.
"""
import math

TODAY_8B = 818_728_672
TODAY_CL = 669_600_000          # classifier receipt, 669.6 MB MEASURED (B6a plan sec. 1)
n, rho, k, Q = 1 << 16, 4, 16, 172
qpad = k * Q
path = int(math.log2(rho * n))


def rows(words):
    return math.ceil(words / n)


def wire(words, G=1, extra_rows=0):
    r = rows(words) + extra_rows
    vec = (G + 1) * (n + qpad) * 16
    col = Q * 8 * r
    rest = Q * (8 + 32 + 32 * path)
    return r, vec, col, rest, vec + col + rest


def block_words(width, hidden, qw, kvw, pad):
    dp = 1 << (width - 1).bit_length()
    fp = 1 << (hidden - 1).bit_length()
    if pad:
        d, f = dp, fp
    else:
        d, f = width, hidden
    return qw * d + 2 * kvw * d + d * qw + 3 * d * f   # Wq, Wk, Wv, Wo, Wg, Wu, Wd


print("== 0. check of the 8B counts against the checkpoint's own parameter count (trained_statement.rs:143)")
N8 = block_words(4096, 14336, 4096, 1024, False)
G8 = 2 * 4096                       # gamma_a + gamma_m per block, int8
V8, D8 = 128_256, 4096
EMB8 = V8 * D8
HEAD8 = V8 * D8
print(f"  block matrices (true)      {N8:>15,}  x32 = {32*N8:>15,}")
print(f"  norm gains (2 x 4096)      {G8:>15,}  x32 = {32*G8:>15,}")
print(f"  embedding int16 V x d      {EMB8:>15,}")
print(f"  head int8 V x d            {HEAD8:>15,}")
FINAL_NORM = 4096
tot = 32 * N8 + 32 * G8 + EMB8 + HEAD8 + FINAL_NORM
print(f"  + final norm gains 4,096 (checkpoint has them; the proof uses one uniform g0) -> total {tot:,}")
print(f"  checkpoint_parameters      {8_030_261_248:,}   difference {tot-8_030_261_248:,}")

print("\n== 0b. same for Shieldstral (text tower only; the image tower is in the checkpoint's count)")
NS = block_words(3072, 9216, 4096, 1024, False)
GS = 2 * 3072
VS, DS = 131_072, 3072
EMBS = VS * DS
text = 26 * NS + 26 * GS + EMBS + 3072
print(f"  block matrices (true) {NS:,} x26 = {26*NS:,}; gains {26*GS:,}; embedding {EMBS:,}; final norm 3,072")
print(f"  text tower {text:,}; checkpoint {3_849_090_048:,}; remainder (not text) {3_849_090_048-text:,}")

print("\n== 1. words and rows at n = 2^16, per class (8B)")
classes8 = [
    ("block matrices, 1 block (true)", N8, 32),
    ("block matrices, 1 block (padded to d_pad x f_pad)", block_words(4096, 14336, 4096, 1024, True), 32),
    ("norm gains gamma_a + gamma_m, 1 block", G8, 32),
    ("embedding int16 (V = 128,256)", EMB8, 1),
    ("embedding at V_pad = 2^17", (1 << 17) * D8, 1),
    ("head int8 W'", HEAD8, 1),
    ("head multipliers m_j (one word each)", V8, 1),
]
for name, w, mult in classes8:
    print(f"  {name:<52} {w:>13,} words {w/n:>10.2f} rows (ceil {rows(w):>6,})  x{mult}")

print("\n== 2. added receipt bytes at tick 54's best row (n=2^16, rate 1/4, k=16, Q'=172, one group), 8B")
r, vec, col, rest, tot_blk = wire(N8)
blocks_added = 32 * tot_blk
print(f"  blocks, one opening each, 32 blocks: {blocks_added/1e6:7.1f} MB  (rows {r}, vectors {vec}, columns {col}, path/rest {rest} B a block)")
# gains as one extra row per block
_, _, _, _, tot_g = wire(N8, extra_rows=1)
print(f"  + gains as 1 extra row a block: +{32*(tot_g-tot_blk)/1e3:.1f} KB for 32 blocks (rows 3,329 a block)")
r, vec, col, rest, tot_e = wire(EMB8)
print(f"  embedding, one opening a request: {tot_e/1e6:6.2f} MB (rows {r}, vectors {vec/1e6:.2f}, columns {col/1e6:.2f}, rest {rest/1e3:.0f} KB)")
r, vec, col, rest, tot_h = wire(HEAD8)
print(f"  head W', one opening a request:   {tot_h/1e6:6.2f} MB (rows {r})")
r, vec, col, rest, tot_m = wire(V8)
print(f"  head multipliers, own opening:    {tot_m/1e6:6.2f} MB (rows {r}; vectors dominate; or fold m into W' rows instead)")
add8 = blocks_added + 32 * (tot_g - tot_blk) + tot_e + tot_h
print(f"  blocks + gains + embedding + head: {add8/1e6:7.1f} MB = x{1+add8/TODAY_8B:.2f} of today's {TODAY_8B/1e6:.1f} MB (blocks alone x{1+blocks_added/TODAY_8B:.2f})")
print(f"  embedding + head alone add {(tot_e+tot_h)/1e6:.1f} MB = {(tot_e+tot_h)/blocks_added*100:.1f}% of the block part, {(tot_e+tot_h)/TODAY_8B*100:.1f}% of today's receipt")
add_m = add8 + tot_m
print(f"  with the multipliers as their own opening: {add_m/1e6:.1f} MB")
# after B6a: vectors go, columns only (tick 54: 146 MB for the block part)
col_blocks = 32 * Q * 8 * rows(N8)
rest0 = Q * (8 + 32 + 32 * path)
col_eh = Q * 8 * (rows(EMB8) + rows(HEAD8))
print(f"  after B6a (columns + rest only): blocks columns {col_blocks/1e6:.1f} MB (+ rest {32*rest0/1e6:.1f} MB; tick 54: 146), embedding + head {(col_eh+2*rest0)/1e6:.2f} MB (columns {col_eh/1e6:.2f})")

print("\n== 3. the same for Shieldstral (26 blocks, classifier receipt 669.6 MB)")
for pad, lab in ((False, "true"), (True, "padded")):
    w = block_words(3072, 9216, 4096, 1024, pad)
    r, vec, col, rest, t = wire(w)
    print(f"  block {lab}: {w:,} words, rows {r:,}, one opening {t/1e6:.2f} MB, x26 = {26*t/1e6:.1f} MB (x{1+26*t/TODAY_CL:.2f})")
r, vec, col, rest, t_es = wire(EMBS)
print(f"  embedding {EMBS:,} words: rows {r:,}, one opening {t_es/1e6:.2f} MB")
r, vec, col, rest, t_ws = wire(3072)
print(f"  margin vector w_delta 3,072 words: rows {r}, own opening {t_ws/1e6:.2f} MB (vectors dominate; put it as 1 extra row of the embedding's commitment: +{Q*8/1e3:.2f} KB)")
w_true = block_words(3072, 9216, 4096, 1024, False)
_, _, _, _, tb = wire(w_true)
tot_cl = 26 * tb + t_es
print(f"  blocks (true) + embedding: {tot_cl/1e6:.1f} MB = x{1+tot_cl/TODAY_CL:.2f}; embedding is {t_es/tot_cl*100:.1f}% of it")

print("\n== 4. per-model stored encoded size at rate 1/4 (8 B a word, 4 x words)")
for name, w in (("8B blocks (32)", 32 * N8), ("8B embedding", EMB8), ("8B head", HEAD8), ("Shieldstral blocks (26)", 26 * NS), ("Shieldstral embedding", EMBS)):
    print(f"  {name:<26} {w*rho*8/1e9:8.1f} GB")

print("\n== 5. prover row combination for embedding + head, one request (G=1: 2 x 2 x N base mults a opening)")
words = EMB8 + HEAD8
for g in (45e9, 150e9, 300e9):
    t = 4 * words / g
    print(f"  {words/1e9:.2f} G words at {g/1e9:.0f} G/s: {t*1e3:6.0f} ms = {t/3.7455*100:4.1f}% of the 3.7455 s cadence")

print("\n== 6. range proofs once per model, scaling tick 53's tree bound by words (ASSUMED linear)")
leaves = 1 << 25
for ms in (15.7, 21.9):
    allw = 32 * N8 + EMB8 + HEAD8
    print(f"  {ms} ms per 2^25 leaves: blocks {ms*32*N8/leaves/1e3:.1f} s, + embedding/head {ms*words/leaves/1e3:.1f} s, total {ms*allw/leaves/1e3:.1f} s")

print("\n== 7. small classes, counts")
IC_scalars = 5 + 9 + 6 + 5 + 2   # norm_{tn,cn_a,cn_m,ceps,wrho}, sh_{qkv,rope,s,o,ao,g,u,h,z}, residual_shifts, f_e f_p f_ro wrho_s mask_score, block_scales
print(f"  IntegerCalibration numeric scalars: {IC_scalars} (+ residual unit and RoPE base as f64 bits = {IC_scalars+2}); own overrides at most 11 a layer: {11*32} (8B), {11*26} (Shieldstral)")
print(f"  final norm: 4 scalars (g0, cn, tn, ceps), one uniform gain, not per channel")
half = 64
print(f"  RoPE cos+sin: 2 x T x head_dim/2 = {2*128*half:,} words a profile (T=128), one set for every layer")
print(f"  exp table 256 words, SiLU table 4,096 words a layer (per-layer member): {32*(256+4096):,} words in 8B (all generator output)")
