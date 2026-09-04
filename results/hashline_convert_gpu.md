# The layer.rs conversion — lane AL, round 15 (lever L2b)

Status: LIVE. WSL box (Core Ultra 9 185H, 8 threads used, 15 GB) + RTX
4070 Laptop GPU (8.19 GB, sm_89), `flock /tmp/zk-heavy.lock`,
NOISY-SHARED by convention. Every number below is [MEASURED] on this
tree unless labelled otherwise; numbers labelled [AJ] are lane AJ's,
quoted and not re-derived.

The unit of measurement is a real Mistral-7B feed-forward layer at
T = 512 on the GPU, and — because the whole item is per-layer
amortization — the **4-layer** run, which is the smallest one where a
layer runs with the staging pool already warm:

    HL_GPU=1 hashline pass 4 512 --profile v3 \
      --export /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export \
      --threads 8 --proof-out F

**The gate on every row: `PROOF sha256 e029e489d1bde1aa..`
(154,507,884 B) at 4 layers, `179ec2fb8f99d0d6..` (38,688,700 B) at one,
and `dc980e81..4536c` (1,234,936,956 B) at 32.** Every arm in every
table below produced them.

## 1. What the item turned out to be

Lane AJ closed round 14 with the 8B prove at 86.00 s, of which **38.7 s
is host time inside the prove clock and essentially all of it is in
`layer.rs`** [AJ]: the plane -> Fp conversion together with the `w_data`
(1.4 GB) and `a_data` (0.46 GB) allocations at ~29 s over 32 layers, and
the host matmul folds at 8.1 s. `layer.rs` was READ-ONLY for AJ and
owned by no round-14 lane. This lane owns it.

Rung 0 instrumented it (`HL_CONV_VERBOSE=1`, still in the tree: it
charges the allocation, the fill, the commit call and the device
counters inside the commit, so the commit's HOST residual is a measured
number and not the difference of two runs). One Mistral layer, x3
[MEASURED, 2026-09-04]:

| | alloc s | fill s | commit s | of which dev h2d / ntt | commit host s |
|---|---:|---:|---:|---|---:|
| W (176 Melem, 1.409 GB) | **0.573 / 0.611 / 0.631** | 0.044 / 0.054 / 0.053 | 0.68 / 0.56 / 0.62 | 0.36 / 0.29, 0.21 / 0.32, 0.21 / 0.37 | 0.028 / 0.029 / 0.034 |
| A (57 Melem, 0.461 GB) | **0.209 / 0.218 / 0.260** | 0.028 / 0.033 / 0.036 | 0.14 / 0.14 / 0.14 | 0.078 / 0.051 | 0.010 / 0.009 / 0.012 |

**THE FINDING: the conversion is not the conversion. The `Fp::from_i64`
fill of 1.4 GB costs 0.05 s; the `vec![Fp::ZERO; lay.w_len]` in front of
it costs 0.60.** `Fp` is a user type, so `vec!` does not specialize to
`alloc_zeroed`: the macro expands to an allocation plus a
SINGLE-THREADED write of 1.4 GB of zeros over ~344k first-touch page
faults — every one of which is then overwritten by the fill. Over 32
layers that is ~27 s of an 86 s prove spent zeroing memory nobody reads.
AJ's ~29 s item is real and is where AJ said it was; it is an
**allocation** item, not an arithmetic one.

The same instrumentation accounts for the rest of the layer exactly: the
`commit W` phase is alloc + fill + commit and nothing else (1.30 s
measured against 1.302 s of phase), and the two matmul phases are 95%
host fold (0.080 + 0.074 = 0.154 s against a 0.162 s `matmul g/u`
phase).

## 2. What the ownership allows, and what it does not

`gpu/*` is READ-ONLY for this lane, and `Pooled::take` — the only way to
obtain a device buffer — is private to `gpu/cuda.rs`. The only device
commit entry callable from here is `dev_commit(params, data: &[Fp],
ntt)`. **So a contiguous `&[Fp]` of the whole matrix cannot be avoided
from this lane**, and "hand `pcs::commit` the int8 planes" in its literal
form (int8 on the bus, `k_widen` on the device, no 64-bit host copy at
all) needs one new entry point in `gpu/cuda.rs` — a chunk-wise
`dev_upload_narrow` + `dev_commit_from`, or a source enum on
`dev_commit`. That is recorded in §6 as the next item, with its measured
size.

What this lane could do instead, and did: **stop paying for the buffer**,
and **stop reading it where the int8 planes say the same thing**.

## 3. Rung 1 — the host staging pool

`hostbuf` (layer.rs): a two-slot pool of host buffers, taken at the top
of `prove_layer_v3` and given back after the W opening / at the end of
the layer. The first layer pays the zeroing once; no layer after it
allocates at all (`alloc 0.0000`, measured on every layer of every
multi-layer run below).

What makes it safe is that `LayoutV3`'s blocks TILE the buffers exactly —
`w_len` is the 3 x nb_d x nb_f weight blocks and nothing else, `a_len`
the 7 x nb_f + 3 x nb_d witness columns and nothing else — so every
element is written before any element is read. **The 12-layer byte gates
are the test of that claim**: a buffer that was not fully overwritten
would carry layer k-1's weights into layer k's commitment and move the
digest on the second of twelve layers. Switch: `HL_AL_POOL=0`.

Not touched: `prove_layer` (v2) and the `h_data` CPU-path buffer. v2
runs only at the 125M shape where the same allocation is 12 MB, and
`h_data` exists only when the device helper path declines. Neither is
worth the risk to a byte gate; both are recorded here rather than
changed.

## 4. Rung 2 — the matmul folds read the int8 planes, and two passes become one

The v3 prover folded each weight block **twice, over two different
copies of the same numbers**:

* `fold_cols_i8` over the whole int8 plane (58.7 M elements) to build
  `wgk` / `wuk` / `wdk`, the sumcheck's weight tables;
* `fold_cols_base` over the `w_data` blocks — the same numbers as Fp,
  8x the bytes — to build `gu_term` / `d_term`.

1.06 GB of reads per layer for the g/u pair, 0.53 GB for d.

They are the same fold. With `cw_gu[j] = lam_f[b] * eq_rj[jp]` and
j = b * fb + jp,

    wgk[c*db + kp] = sum_j cw_gu[j] . src = sum_b lam_f[b] * blk_b[kp]

where `blk_b` is exactly the block fold `gu_term` wants. The block fold
needs only `eq_rj`, which is drawn BEFORE the sumcheck, so it can be
computed first and the plane fold read off it for the price of
d x nb_f extension multiplies. `fold_block_i8` does the block fold as a
strided fold over the int8 plane, so the 64-bit copy is never read.

Byte-identical by construction, not by luck: the field is Z_p and every
operation is exact; Fp2 multiplication is bilinear over the base field,
so `(lam * eq) . v` and `lam * (eq . v)` are the same element; summation
order is irrelevant in an abelian group; and skipping a zero adds zero,
which is what `fold_cols_i8` already did. Switch: `HL_AL_I8FOLD=0`.

## 5. The A/B, 4 x 512 Mistral, ONE binary, two rounds [MEASURED]

Every arm produced `e029e489d1bde1aa..`, 154,507,884 B.

| phase (4 layers, s) | before (both switches off) | after (lane defaults) |
|---|---:|---:|
| commit W | 4.375 / 4.792 | 3.063 / 3.545 |
| commit A | 1.562 / 1.563 | 0.792 / 0.863 |
| helpers + commit H | 0.797 / 0.805 | 0.804 / 0.802 |
| matmul g/u | 0.676 / 0.648 | **0.383 / 0.389** |
| matmul d | 0.362 / 0.364 | **0.235 / 0.242** |
| zero-check F + D | 0.681 / 0.691 | 0.688 / 0.676 |
| pcs openings | 2.299 / 2.315 | 2.154 / 2.150 |
| **PROVE** | **10.75 / 11.18** | **8.12 / 8.67** |

Mean **10.97 -> 8.40 s = 1.306x**, and the per-layer instrumentation
says exactly where it came from:

* `alloc` 0.57-0.91 s (W) + 0.21-0.27 s (A) on layer 0, **0.0000 on
  every layer after it**;
* the `w_data` block folds 0.074 -> 0.006 s (g/u) and 0.039 -> 0.003 s
  (d), while the fused plane pass that absorbed them did not grow
  (0.085 s before, 0.085 s after) — the second pass is simply gone.

The 4-layer figure UNDERSTATES the 32-layer one: the after arm still
pays layer 0's allocation over 4 layers instead of 32.

## 6. What this lane did NOT do, and why

* **The literal form of the fix — int8 on the bus, no 64-bit host copy.**
  It needs a new entry point in `gpu/cuda.rs` (READ-ONLY here) because
  `Pooled::take` is private, so nothing outside that file can stage a
  device buffer chunk by chunk. Its remaining value is now MEASURED and
  small: after rungs 1-2 the whole host cost of building `w_data` and
  `a_data` is **fill 0.049 + 0.035 s and 0.017 s of commit residual =
  ~0.10 s of a ~1.9 s layer**, about 3 s of the 8B prove. The bigger
  prize behind that door is not time but VRAM and bus: the device would
  hold the widened matrix only chunk by chunk.
* **`prove_layer` (v2) and the `h_data` CPU-path buffer** — see §3.
* **The remaining fold cost.** After rung 2 the fold phases are 0.085 s
  (g/u) + 0.050 s (d) per layer, and that is now genuine arithmetic:
  176 M Fp2 `mul_base`+`add` over the three planes plus
  `fold_rows_i32` over h16. Moving it to the device is a `gpu/*` item.
* **`pcs.rs`.** This lane owns it and did not need to change it: with
  `dev_commit`'s signature fixed, every lever was on the caller's side.

## 7. Rung 3 — the floor, and the 8B pass before and after

**THE FLOOR: ALL TWELVE BYTE GATES GREEN** — the four on the CPU binary,
the four on the GPU binary, and the same four re-run with
`HL_GPU_CHUNK_BYTES` forced small so the frozen 125M digests exercise the
chunked commit as well. `cargo test --release` **40/40**.
(`results/hashline_convert_r3.log`, `results/cargo_test_r3.log`.)

| gate | digest | bytes | cpu | gpu | gpu chunk-forced |
|---|---|---:|---|---|---|
| v2 | `50cf7bdfd6b5b182` | 66,844,928 | OK | OK | OK |
| v3 | `5f368db6240e0614` | 70,758,084 | OK | OK | OK |
| zk-v2 | `021485e4f80ec695` | 87,228,528 | OK | OK | OK |
| zk-v3 | `40eb54795e023c77` | 87,697,008 | OK | OK | OK |

**THE 8B PASS, both arms in ONE session on ONE binary** (`pass 32 512
--profile v3 --export .../m8b_mistral_v3_export --wcache <fresh dir>
--threads 8 --proof-out F`, cold cache in both arms — 32 misses, 0 hits
each — `/usr/bin/time -v`) [MEASURED, 2026-09-04, WSL-BOX, 8T, GPU,
NOISY-SHARED]:

| | BEFORE (`HL_AL_POOL=0 HL_AL_I8FOLD=0`) | **AFTER (lane defaults)** | |
|---|---:|---:|---|
| **PROVE** | **98.54 s** | **58.40 s** | **1.687x** |
| commit W | 43.901 | **19.823** | 2.21x |
| commit A | 16.155 | **4.838** | 3.34x |
| helpers + commit H | 5.552 | 5.555 | — |
| matmul g/u | 5.816 | **3.441** | 1.69x |
| matmul d | 3.070 | **2.092** | 1.47x |
| zero-check F + D | 5.490 | 5.468 | — |
| pcs openings | 18.557 | 17.176 | |
| witness load + chain | 141.76 | 134.50 | |
| verify | 1.65 | 1.08 | |
| wall | 244.45 | **196.79** | |
| **proof sha256** | `dc980e81..4536c` | `dc980e81..4536c` | **IDENTICAL**, 1,234,936,956 B |
| device h2d | 9.734 s (9,328 MB) | 8.597 s (9,328 MB) | |
| device ntt / hash | 14.860 / 0.467 | 13.877 / 0.481 | |
| device sumcheck / fold / helpers | 5.488 / 2.878 / 1.384 | 5.465 / 2.850 / 1.378 | |
| opening re-encode | 13.961 | 13.826 | |
| **VRAM peak** | 5,249 MB | 5,249 MB | unchanged |
| peak RSS | 3.93 GB | **4.69 GB** | +0.76 GB (see below) |
| **proven MAC/s** | 2.929e10 | **4.943e10** | |
| **tokens/s at 8B prefill** | 5.20 | **8.77** | |

**1.687x on the prove, the proof byte-identical, every gate green.**

**THE HOST WALL IS GONE.** Summing the device counters: before, 48.77 s
of the 98.54 s prove is device, so **49.8 s (50.5%) is host**; after,
46.47 s of 58.40 s is device, so **11.9 s (20.4%) is host**. The host
time inside the 8B prove fell **49.8 -> 11.9 s** and every second of that
came out of `layer.rs`. The device columns are unchanged to within 1-7%,
as they must be — this lane did not touch a kernel.

**Two honest framings of the factor.** The controlled in-session A/B is
**1.687x** (98.54 -> 58.40). Against lane AJ's recorded 86.00 s the
number is **1.47x** — today's box ran the switches-off arm at 98.54 s
where AJ's session ran the same configuration at 88.90 s, about 11%
slower, which is inside the ±6%-per-phase noise this box has shown twice
now once compounded over a 4-minute run. The A/B is the number to quote;
the 86.00 -> 58.40 comparison is the one to use against the round-14
ledger, and it is the more conservative of the two.

**Peak RSS is up 0.76 GB and that is the pool, by design**: the two
staging buffers (1.409 + 0.461 GB) stay resident for the life of the
process instead of being allocated and freed 32 times. On this 15 GB box
that is a good trade for 40 s of prove; `HL_AL_POOL=0` gives the memory
back on a tighter box. VRAM is untouched at 5,249 MB.

**Where the 58.40 s sits now.** The layer.rs host residue is fill 0.049 +
0.035 s and ~0.017 s of commit residual and 0.135 s of folds per layer =
**~7.5 s of the 58.40**; the rest of the 11.9 s host is the openings'
and helpers' host tails. **The next factor is device work again** — the
opening re-encode (13.83 s, AJ's §7 kernel project), the encode NTT
(13.88 s) and the sumchecks (5.47 s) — plus the ZK prover, which still
declines the device path at Mistral width (lane AI's item, untouched
here).
