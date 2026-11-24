#!/usr/bin/env python3
"""Tick 54 (queue item 91): hidden weights (P3) priced on the W16R2 8B prover. Standard library only, reads no file.

Inputs quoted from records (each labelled in the handoff):
  N      = 218,103,808 int8 weights per block (cycle 4 census, H124 note)            COUNTED
  BLOCKS = 32 forks at the 8B D55 profile                                           COUNTED (B6a plan)
  wire   = (groups+1)(n+Q)*16 + Q*(8 + 8*rows + 32 + 32*path)   (wire.rs:106-108)    COUNTED (B6a plan sec. 2.1)
  today  = 818,728,672 B receipt, 8B, MEASURED
  A+H commit 28.95 ms for 2,501+2,602 rows at nn = 2^15 (W16R2 Shieldstral block, measured 2026-11-20)  MEASURED
"""
import math

N = 218_103_808
BLOCKS = 32
TODAY = 818_728_672
n0 = 1 << 14
LOG_TARGET = 114          # each list at 2^-113.93 (delta/2), as in the B6a plan; 100 is looser

print("== 1. rows of one block's weights as a committed matrix")
for ln in (14, 16, 18, 20):
    n = 1 << ln
    print(f"  n=2^{ln}: rows = {N / n:,.1f}")
print(f"  A+H rows today at n=2^14: 2,501 + 2,602 = {2501+2602}; weights/ (A+H) = {N/n0/5103:.2f}x")

print("\n== 2. budget k of one stable commitment: pad q_pad = k*Q, distance, columns Q needed (n=2^14)")
def need_Q(k, rho, n=n0, bits=LOG_TARGET):
    nn = rho * n
    Q = 1
    while True:
        qpad = k * Q
        if n + qpad >= nn:
            return None
        delta = 1 - (n + qpad) / nn
        err_bits = -Q * math.log2(1 - delta / 2)
        if err_bits >= bits:
            return Q, qpad, delta
        Q += 1
        if Q > 20000:
            return None
print("  rate 1/rho, k  -> Q, q_pad, distance   (None = no Q reaches target)")
for rho in (2, 4, 8):
    for k in (1, 4, 16, 64, 256):
        r = need_Q(k, rho)
        print(f"  rho={rho} k={k:>3}: " + ("None" if r is None else f"Q={r[0]}, q_pad={r[1]}, delta={r[2]:.3f}"))
print("  (k=1 at rho=2 gives Q=%d; the shipped profile uses Q=280, i.e. its own error list is a different count)" % need_Q(1, 2)[0])

print("\n== 3. bytes per receipt added by one opening of the weight commitment, 32 blocks")
def wire(groups, n, Q, rows, path):
    return (groups + 1) * (n + Q) * 16 + Q * (8 + 8 * rows + 32 + 32 * path)
rows_out = []
for ln in (14, 16, 18):
    n = 1 << ln
    rows = N // n
    for rho, k in ((2, 1), (2, 16), (4, 16), (4, 64)):
        r = need_Q(k, rho, n)
        if r is None:
            continue
        Q, qpad, _ = r
        nn = rho * n
        path = int(math.log2(nn))
        for G in (1, 7):
            w = wire(G, n, Q, rows, path)
            # clear vectors have length n+q_pad, not n+Q: correct the first term
            w = (G + 1) * (n + qpad) * 16 + Q * (8 + 8 * rows + 32 + 32 * path)
            tot = w * BLOCKS
            cols = Q * 8 * rows * BLOCKS
            vecs = (G + 1) * (n + qpad) * 16 * BLOCKS
            rows_out.append((ln, rho, k, G, Q, tot, cols, vecs))
            print(f"  n=2^{ln} rows={rows:>6,} rho={rho} k={k:>2} Q={Q:>3} G={G}: total {tot/1e6:8.1f} MB "
                  f"(columns {cols/1e6:7.1f}, vectors {vecs/1e6:7.1f}); x today {1+tot/TODAY:.2f}")

print("\n== 4. per-model encoded size and per-proof fresh-commit cost (the option that needs no budget)")
for rho in (2, 4, 8):
    enc = N * rho * 8 * BLOCKS
    print(f"  rate 1/{rho}: stored encoded matrix = {enc/1e9:.1f} GB (all {BLOCKS} blocks)")
# measured commit rate
rate = (2501 + 2602) * (1 << 15) * 8 / 28.95e-3   # B/s of encoded matrix, NTT + hash, MEASURED block
print(f"  measured commit rate (A+H, 28.95 ms): {rate/1e9:.1f} GB/s of encoded matrix")
for ln in (14, 16):
    n = 1 << ln
    enc_block = N * 2 * 8
    t = enc_block / rate
    print(f"  fresh weight commit per proof at rate 1/2: {enc_block/1e9:.2f} GB per block, {t*1e3:.0f} ms per block, {t*BLOCKS:.2f} s per request")
    break
print(f"  against the 3.7455 s 8B cadence: +{N*2*8/rate*BLOCKS/3.7455*100:.0f}%")

print("\n== 5. the opening's row combination (prover, per block, per request), base multiplications")
for G in (1, 7):
    mults = (G + 1) * 2 * N
    print(f"  G={G}: {mults/1e9:.2f} G base mults per block; x32 = {mults*BLOCKS/1e9:.0f} G per request")
for rate_g in (45e9, 150e9, 300e9):
    for G in (1, 7):
        mults = (G + 1) * 2 * N
        t = mults / rate_g
        print(f"  at {rate_g/1e9:.0f} G/s: G={G}: {t*1e3:6.1f} ms per block, {t*BLOCKS:5.2f} s per request "
              f"= {t*BLOCKS/3.7455*100:5.1f}% of the 8B cadence")
print("  memory floor: int8 weights 218.1 MB per block at 700 GB/s = %.2f ms (Fp-expanded 1.74 GB: %.2f ms)" % (N/700e9*1e3, N*8/700e9*1e3))

print("\n== 6. one-off per model: range proof of the committed int8 words (scaling tick 53's tree cost, ASSUMED linear)")
leaves25 = 1 << 25
ratio = N / leaves25
for ms in (15.7, 21.9):
    print(f"  tick 53 low bound {ms} ms at 2^25 leaves -> x{ratio:.2f} = {ms*ratio:.0f} ms per block, {ms*ratio*BLOCKS/1e3:.1f} s per model")

print("\n== 7. FlashProve per request, for the same units (AUTHORS, local record)")
print("  proof 18.78 MB mean per 1,024-token request; fixed 34.5 to 47 s per batch of 24; 7.5 to 7.8 s per request")
print(f"  ours today {TODAY/1e6:.1f} MB per 128-token request = {TODAY/1e6/18.78:.0f}x their proof (different token counts)")

print("\n== 8. slot rows in the stable commitment (ASSUMED 8 to 16 mask rows per slot, FA4 had 22 for the FFN-only layer)")
for k in (16, 64):
    for r in (8, 16, 22):
        print(f"  k={k} slots x {r} rows = {k*r} rows = {k*r/(N/n0)*100:.1f}% of the {N//n0:,} data rows")
