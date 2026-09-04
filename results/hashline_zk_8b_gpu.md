# THE 8B PROOF, ON A GPU, WITH PRIVACY — lane AI, rung 3

**The product number under Victor's P1 ruling** (private inputs and
activations, public weights): a 32-layer Mistral-7B FFN pass at T = 512,
proven in zero knowledge on a laptop GPU. Nobody had this row before
2026-09-04; the ZK prover used to decline the device path at Mistral width
(rungs 0-2 fixed that), and the 32-layer pass had never been run.

Box: WSL laptop, 8 threads + RTX 4070 Laptop (8,188 MiB part). Every row
below is `[WSL-BOX] [8T] [GPU or CPU] [NOISY-SHARED]` `[MEASURED]` unless it
says otherwise; the pass ran detached under `flock /tmp/zk-heavy.lock` with a
`.done` marker, one run, while another lane was compiling.

    HL_GPU=1 hashline pass 32 512 --zk --seed 1 --profile v3 \
      --export /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export \
      --wcache <fresh dir> --threads 8 --proof-out F

(lane AH's rung-4 configuration exactly, plus `--zk --seed 1`.)

## 1. The row

| | AH's 8B GPU pass (no privacy) | **THIS ROW — mode P1** | ratio |
|---|---:|---:|---:|
| **PROVE** | 95.48 s | **265.34 s** | **2.78x** |
| VERIFY | 1.16 s | **2.33 s** | 2.01x |
| proof bytes | 1,234,936,956 | **1,285,578,368** | **+4.10%** |
| **sha256** | `dc980e81..` | **`930ce9a043a03721..c982e`** | — |
| peak RSS | 3.80 GB | **4.30 GB** | +13% |
| VRAM peak | 5,651 MB | **8,585 MB** (of 8,188 MiB) | +52% |
| proven MAC/s | 3.02e10 | **1.088e10** | 0.36x |
| witness load + chain | 126.97 s | 131.79 s | — |
| wall | 225.35 s | **402.29 s** | — |
| tokens/s (512 / prove) | 5.36 | **1.93** | — |

Full digest:
`930ce9a043a037210f62ac1384384e3a88607f29046b56284c6308ed272c982e`
(1,285,578,368 B), taken by hand with `sha256sum` over the written file as
well as by the binary. `PASS-V3 ACCEPT [ZK]`, verifier green.
`wcache: 32 misses, 129 MB written` (a fresh dir, so the cold configuration).

**THE P1 SURCHARGE AT 8B ON A DEVICE IS NOT AD's +4.7%.** AD measured
+4.7% prover / +3.9% bytes on ONE Mistral layer **on the CPU**, where the
base is 15 s of host arithmetic and the ZK work hides inside it. The bytes
carried over exactly (+4.10% here). The time did not: on a device the base
is 3 s of kernels, and the ZK work — masked commitments with salted leaves,
the committed multiplicity tables, the extra H rows — is most of the layer.
Any P1 projection built by multiplying a GPU row by 1.047 is wrong by 2.7x.

## 2. Where the 265 s goes

Phases summed over the 32 layers [MEASURED, s]:

| phase | AH, no privacy | **P1 (this row)** |
|---|---:|---:|
| commit W | 41.94 | 54.18 |
| commit A | 15.85 | 24.57 |
| mask commit | — | 0.23 |
| **helpers + commit H** | **5.36** | **146.26** |
| matmul g/u + d | 8.13 | 10.64 |
| zero-check F | 4.65 | 8.62 |
| zero-check D | 0.79 | 1.34 |
| table zero-check | 0.32 | 1.58 |
| zsum + mask open | — | 0.12 |
| pcs openings | 18.48 | 17.80 |
| **total** | **95.48** | **265.34** |

Device-side, summed: h2d 16.86 s (61,018 MB), **ntt 119.10 s** (AH: 15.85),
hash 8.07, sumcheck 9.80, fold 5.87, helpers 19.63, d2h 1,466 MB, VRAM peak
8,585 MB.

**55% of the prove is one phase — helpers + commit H — and it is 27x AH's.**
Part of that is real: the ZK H matrix carries the LogUp helper planes, their
masks, the zero-sum rows and the table helpers, and it is committed with
`commit_zk_device` (salted leaves, mask rows, the proximity row). But most of
it is the card being too small; see §3.

## 3. The VRAM story — what the drain buys, and what it cannot

The crash-recovery commit `1c225d4` left a per-layer pool drain with its
justification written only as a comment (its logs died with the box). This
rung made the claim testable in one binary (`HL_ZK_DRAIN=0`) and ran it:
**4 real Mistral layers, same binary, same statement, drain the only
difference** (results/hashline_zk_8b_drain_ab.log).

| | drain ON (shipped) | drain OFF |
|---|---|---|
| result | 4/4 layers, **ACCEPT** | **layer 1 PANICS** |
| prove | 31.15 s (5.65 / 9.13 / 8.02 / 8.34) | layer 0 in 4.78 s, then dead |
| failure | — | `gpu zk commit H (v3): cuMemAlloc(1514 MB): CUDA_ERROR_OUT_OF_MEMORY` |
| proof | 9f2f35a3.. / 160,708,048 B | none |

So **the drain is necessary: without it the 32-layer 8B ZK pass cannot run at
all**, and the dead agent's testimony — including the 1,514 MB allocation —
is now evidence. The mechanism is in the trace: the device buffer pool
matches by EXACT length, the ZK prover's row counts differ per layer (layer 0
proves 40,186,228 B, every later layer 40,173,940 B — different remainder
windows, different table rows), so a previous layer's pooled buffers are dead
weight; without the drain the card reads `free 0 MiB` with 9 pooled buffers
before layer 1 has finished committing W.

**What the drain cannot buy: layer-0 speed at every layer.** Layer 0 proves
in 4.36 s and layers 1..31 in 8.42 s mean (median 8.63; layers 11, 21 and 31
came in near 5 s). The trace says why: at layer 0 the zero-check table
reservation FAILS, `dev_reserve_hard` drains and retries, and the layer runs
with 1,614 MiB of real VRAM free; at every later layer the same reservation
SUCCEEDS with 494 MiB free — **on WSL `cuMemAlloc` is backed by host memory
rather than failing** — so the 1,168 + 224 MB of zero-check tables are paged
and the whole helpers/H/zero-check phase runs against host memory.

A third drain, placed before that reservation to force the tables into real
VRAM, was written and A/B'd (results/hashline_zk_8b_drain_pre_ab.log). **It
kills layer 0**: `gpu zk commit H (v3): cuMemAlloc(1516 MB) OUT_OF_MEMORY`.
On an 8,188 MiB part the resident A commitment + 1,392 MB of zero-check
tables + a 1.5 GB H commit do not fit, and the paging is what makes the layer
possible at all. It is reverted, with the reason recorded at the site.

**Therefore the 2x per-layer penalty is a card-size fact, not a code fact.**
A 16 GB+ board should show layer-0 behaviour at every layer with no change:
32 x 4.36 s = 140 s, which would make this row 1.9x faster than measured and
put the P1 surcharge at ~1.5x rather than 2.78x. That is a prediction, not a
measurement, and it is the single cheapest thing lane E's hardware ruling
could settle.

## 4. Byte identity — the proof is the same on both provers

`pass 4 512 --zk --seed 1 --profile v3` on the real Mistral export
(results/hashline_zk_8b_cpu_gpu_cmp.log):

| | GPU | CPU |
|---|---|---|
| sha256 | `9f2f35a383295118..` | **the same** (`cmp` identical) |
| bytes | 160,708,048 | 160,708,048 |
| PROVE | 30.76 s | 74.48 s (**2.42x**) |
| peak RSS | 3.09 GB | 13.01 GB |

Rung 1 established this for one Mistral layer; this extends it to a
transcript that chains four. The 32-layer CPU run was NOT taken: at 13 GB of
RSS and ~596 s of prove [COUNTED from this row] it would put a 15 GB box
shared with two other lanes at risk for a digest the 4-layer gate already
pins.

## 5. `--wcache` on the ZK path (E4)

results/hashline_zk_8b_wcache_e4.log, 2 Mistral layers per run:

- ZK + `--wcache` on a cold dir: **MISS x2, entries written** (4.2 MB/layer).
  Before rung 1's one-line change the flag wrote nothing on this path.
- ZK with **no** `--wcache`: **the same digest** `5c766868..`, the same
  80,360,168 B. The cache changes no bytes of the ZK proof.
- The **non-ZK v3 prover** against the dir the ZK prover wrote:
  **hits 2 | misses 0** — the two passes share entries, which is what the
  shared `WKey::new("v3", l, d, f, ..)` key was for. commit W 2.51-2.67 s
  cold -> 1.61 s warm over two Mistral layers.
- **But the WARM path CRASHES the GPU ZK prover at Mistral width**:
  `gpu helpers (zk v3): cuMemAlloc(379 MB) OUT_OF_MEMORY`, right after the
  layer-0 HIT. Cause, from wcache.rs (lane AC's file, read-only here): on a
  HIT `reencode_store` calls `gpu::dev_encode_only` and keeps the re-encoded
  W **device-resident for the layer**, where the MISS path's `pcs::commit`
  goes through the chunked device commit and leaves nothing resident. At
  10,752 rows that store plus the resident A commitment does not leave the
  helpers their 379 MB. `--wcache` is therefore safe on the GPU ZK path only
  while it MISSES — which is what a fresh dir does, and what this row used.
  The byte-identity of the cached form is not in question; its VRAM budget
  is. Owed to whoever owns wcache.rs.

## 6. Floors

- The four byte gates on BOTH binaries, before any rung-3 code and again on
  the final tree: **all eight green** (v2 `50cf7bdf..` 66,844,928 B; v3
  `5f368db6..` 70,758,084 B; zk-v2 `021485e4..` 87,228,528 B; zk-v3
  `40eb5479..` 87,697,008 B) — results/hashline_zk_8b_gates.log and
  results/hashline_zk_8b_gates_final.log.
- `cargo test --release` **40/40**.
- The **eight v3 tamper legs at Mistral-7B width through the GPU ZK prover**,
  re-run on the final binary (results/hashline_zk_8b_legs.log): honest run
  ACCEPT (prove 4.182 s, verify 0.053 s, 40,186,228 B), then **8 of 8
  REJECT** — flipped X, flipped Wg, out-of-range remainder, wrong int16
  table entry, wrong requant (h16), wrong z, wrong rounding (floor),
  out-of-range int16 — **`layer 0 (v3) [ZK]: GREEN`**.

## 7. What this row does and does not prove

It is the FFN half of the statement — the same scope as every other 8B row in
this repository. Attention, the norms and the layer seams are lane AG's
build and are not in it, and the chained-transcript simulator argument (plan
item A6) is still owed before any published ZK claim. What is hidden here is
what mode P1 hides: the inputs and every activation. What is revealed: the
weights and their whole opening, the shapes and block structure, the four
signed shifts, the table digests.
