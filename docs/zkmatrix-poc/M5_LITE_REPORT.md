# M5-lite Report: Wide-Object Chunking and the First Real FFN-Shape Commit-Bill Measurement

Status: MEASURED (CPU, this repo's 22-thread workstation). Artifacts: the
chunking layer in `zkmatrix-rs/src/ring/commit.rs` (`wide_chunk_count`,
`wide_slot`, `wide_chunks`, `commit_wide`, `wide_digest`,
`monolithic_wide_crs_bytes`), the `[M5]` battery inside
`ring_matmul self-test`, the `m5-bench` subcommand of
`zkmatrix-rs/src/bin/ring_matmul.rs`, and the raw session logs
`docs/zkmatrix-poc/results/m5_bench_ffn_s{1,2,3}.txt`.

This tranche does two things the roadmap asked for after the A1
integration: (1) it removes the memory blocker that made a full-scale
measurement impossible on this machine (a monolithic "wide" CRS at FFN
inner dimensions costs 17-124 GB; the box has 15 GB), and (2) it turns
the 7B-feedforward commit-bill projection of `LLM_SCALE_ESTIMATE.md`
("~1.6-2.0 min at 22T", which carried a ~15x multithread EXTRAPOLATION)
into a real end-to-end CPU measurement at the FFN matmul shape
512 x 4096 x 11008, plus the post-R1/E2 recost that the outside audit's
H-02 finding demanded (`codex-audit-2026-07-09/FINDINGS.md`).

Plain-language labels used throughout:

- **commit bill** — the prover time spent committing tensors (the
  dominant LLM-scale cost; everything else is "claim layer").
- **ring-MAC** — one multiply-accumulate of two degree-128 ring
  elements inside the commit GEMM; one committed column costs
  (kappa + msg_r) x N_r of them.
- **used vs paid elements** — a committed column carries msg_r x 128 =
  4096 message slots ("paid"); the tensor value actually stored in a
  slot is "used". Padding (e.g. a 512-tall C column in a 4096-slot
  message) pays for slots it does not use.
- **1T / 22T** — single-thread / all 22 hardware threads.
- **[MEASURED] / [MODEL] / [ASSUMED]** — measured on this machine in
  this tranche / computed from a documented cost model / an external
  factor nobody here has measured (the GPU row).

## 1. The chunking design (one page)

**The blocker.** Commitments in this protocol have a fixed message
width: msg_r ring elements (msg_r = 32 at the frozen FFN parameter
point — the C2-C4 row `FFN 512x4096x11008 e=4: kappa=9 N_r=57`,
pinned by freeze-check). Several protocol objects are much wider than
one message. The sharpest case is the pi2-CE gate's execution/mask
vectors: h x inner_r ring-element slots each, which at the FFN shape
(h = 128 automorphisms, inner_r = 32) means 4096 slots per object —
and 11008 for the wider orientation. Committing such an object
MONOLITHICALLY needs a CRS at msg_r = 4096..11008, whose A1/A2 blocks
alone hold (kappa + msg_r) x N_r ring elements:

| monolithic wide shape | CRS size | on a 15 GB box |
|---|---|---|
| msg_r = 4096 (FFN gate/up orientation) | 17.3 GB | does not fit |
| msg_r = 11008 (down-proj orientation) | 124.5 GB | absurd |
| **chunked: the frozen msg_r = 32 CRS** | **2.39 MB (+16.75 MB A1 caches)** | **fits in L3-class cache** |

(The A1 NTT-domain kernel caches roughly quadruple whatever the CRS
costs, so the monolithic route is even worse than the table row.)

**The layout.** A wide object of `len` ring elements is committed as
`ceil(len / msg_r)` ordinary column chunks under the ONE bounded CRS,
with the tail chunk zero-padded. Logical slot u lives at chunk
`u / msg_r`, slot `u % msg_r` — exactly the flat-index convention the
ct-engine has always used for its g-mask groups (`g_slot_of`). Every
chunk is an ordinary commitment with its own independent ternary
randomness, opened by the ordinary opening machinery.

**What did NOT change.** No verification equation, challenge
derivation, norm budget, or claim form moved. Claims already address
`(commitment index, slot)` pairs, so a claim that spans a wide object
simply names slots in several chunks. The `[M5]` self-test battery
pins this: chunked commitments are bit-identical across kernel paths,
and a ct-round whose RingClaims span chunk boundaries proves and
verifies unchanged (with tamper negatives on both a claim constant
and a chunk commitment).

**One logical tensor.** The manifest carries ONE `CommitmentEntry`
for the wide object, whose commitment bytes are `wide_digest()` — a
SHA-256 over the tagged, length-prefixed, ORDERED chunk commitment
list. Chunk reordering, truncation, extension, or any single-element
tamper changes the digest, and the digest (not the chunks) enters the
manifest digest and every statement hash. Chunk count and shape ride
`key_info`. The m5-bench asserts the digest is identical across all
thread counts and sessions (parallel commit must be order-identical).

**R1 interaction (the audit's H-02 case).** Per Q4_LEMMAS.md R1.4',
gate-only rounds (one TwistedQuadRingClaim, no existing g-commitment)
pay ONE fresh pad commitment. Under the monolithic layout that fresh
commitment was WIDE-shaped (the ~116 KB delta the audit measured at
the toy shape); under chunking the 3 pad slots fit one msg_r = 32
chunk — a 2337-ring-MAC commitment (~0.44 ms 1T measured) plus its
opening. The pads-ride-existing-g-slots rule for quad-ct rounds is
unchanged.

## 2. What m5-bench measures

`ring_matmul m5-bench [rows inner cols [reps]]` (defaults
512 x 4096 x 11008, 3 repetitions per thread count):

1. Derives the frozen point (kappa = 9, N_r = 57, msg_r = 32, C2
   headroom 1.4 bits), prints the P0 kernel-regime dispatch, expands
   the chunked CRS and A1 caches.
2. Streams a full FFN matmul triple — A (512 x 4096) by rows,
   B (4096 x 11008) by columns, C (512 x 11008) by columns, the
   chain-demo orientation discipline — as 22,528 column commitments.
   Nothing dense is materialized: each column is generated (seeded
   splitmix64, mod-q), packed, committed and digested, then dropped;
   only 32-byte digests are retained. End-to-end cost (datagen +
   packing + rho sampling + commit kernel + commitment hashing) is
   what the clock sees.
3. Repeats the full triple at 1/2/4/8/16/22 rayon threads, reps x
   each, reporting min/median, and separately times a no-kernel
   baseline (everything except commit + commitment hashing).
4. Commits the pi2-CE claim-layer wide objects for ONE matmul claim at
   this shape — 9 wide objects (26,112 slots) plus the R1 pad chunk —
   under the same CRS, chunked.
5. Prints the machine-readable `M5CSV` rows and the recost block.

Scale of the measured object: 52.8M used tensor elements (92.3M paid
slots — the 1.75x padding waste is dominated by C columns paying
msg_r = 32 for 4 used slots; see Section 5 item 5), 5.265e7 ring-MACs,
i.e. one full FFN gate/up-projection triple of a 7B model at 512
tokens. **This shape fits with room to spare: peak RSS 94-95 MB**
against the 12 GB budget — streaming removes the memory question
entirely, so "largest shape that fits" is no longer commit-bill
limited (dense witness storage, not commitment, is what used to blow
memory).

## 3. Measured results (three sessions, shared box)

Machine: the repo's Core Ultra 9 185H workstation (6P + 8E + 2LP
cores, 22 threads, 15 GB RAM), WSL2. **Caveat, stated up front: the
box was shared with sibling agents' workloads during all three
sessions** (a full-core python3 was live during s1 and s3-adjacent
windows; s1's 2T row even measured BELOW 1T). Per the repo's
established discipline the quotable statistic is the min over
sessions per row; within-session ratios are stable, cross-session
levels move with load.

Full triple (22,528 commitments), seconds per repetition, min of 3
per session:

| threads | s1 | s2 | s3 | **min** | ns/paid el | ns/used el | eff GMAC/s | speedup |
|---|---|---|---|---|---|---|---|---|
| 1 | 11.03 | 11.90 | 10.84 | **10.84** | 117.4 | 205.2 | 80 | 1.00 |
| 2 | 12.20 | 6.41 | 6.02 | **6.02** | 65.2 | 113.9 | 143 | 1.80 |
| 4 | 5.06 | 3.26 | 3.18 | **3.18** | 34.5 | 60.2 | 271 | 3.41 |
| 8 | 4.17 | 1.97 | 1.88 | **1.88** | 20.4 | 35.7 | 458 | 5.75 |
| 16 | 2.05 | 1.38 | 1.33 | **1.33** | 14.4 | 25.1 | 650 | 8.17 |
| 22 | 1.60 | 1.30 | 1.24 | **1.24** | 13.4 | 23.5 | 696 | **8.74** |

(The min column happens to be session 3 in every row; ns/element and
GMAC/s are recomputed from it; speedup = min-1T / min-tT. Per-session
speedup ceilings: 6.9x (s1, loaded), 9.1x (s2), 8.7x (s3) — so the
measured 22T factor is 8.7-9.1x depending on which honest statistic
is taken.)

Cross-checks:

- The 1T end-to-end rate is 0.206-0.226 us/ring-MAC across sessions
  (best 0.206); subtracting the measured no-kernel baseline
  (0.35-0.70 s: datagen + packing + rho sampling) leaves
  ~0.199 us/ring-MAC for commit + commitment hashing, and an
  estimated ~0.187 after the ~0.9 GB of SHA-256 — the A1 integration
  anchor (0.161-0.195 us/ring-MAC, idle box, kernel only) reproduced
  from inside a full streaming pipeline within ~10%. Equivalently
  117 ns per paid element end-to-end (114 minus baseline) vs the
  ladder's 99-111 ns kernel-only anchor.
- The order-folded digest of all 22,528 commitments is identical
  across every thread count and session (deterministic parallel
  layout), and the claim-layer wide digest likewise.

**Thread scaling and its ceiling.** The measured 22T factor is
**8.7x min-over-sessions (9.1x best within-session; 6.9x on the
loaded session)**, against the ~15x the ladder row assumed. The curve
(1.80 / 3.41 / 5.75 / 8.17 / 8.74 at 2/4/8/16/22T) bends well before
22 threads, and 16T -> 22T adds only ~7%. A hard memory-bandwidth
wall is unlikely to be the cause — the shared read-only working set
(2.4 MB CRS NTT cache + 57 KB per-column transforms) fits in L3 and
the kernel is compute-dense — and the no-kernel baseline
(allocation-heavy but arithmetic-light) saturates at the same ~7x,
which points at the platform: a heterogeneous core mix (6 P + 8 E +
2 LP-E; the last 6 "threads" are SMT siblings adding little), WSL2
scheduling, and sibling load. Whatever the decomposition, ~15x is
not available on this part; **8.7-9.1x is what this box gives**, and
that single correction is what moves the ladder row below.

**Claim layer at the measured shape** (per pi2-CE matmul claim,
chunked): 26,112 wide slots + 3 R1 pad slots -> **817 chunk
commitments, 0.346 s 1T** (0.42 ms/chunk), i.e. ~3.2% of the triple's
own commit time — the "claim layer subdominant" expectation holds
at the FFN shape with R1 pads included. Reveals add 4.32 MB (F) +
33.7 KB (K2) of transcript per claim. The R1 pad object under
chunking is ONE msg_r = 32 chunk (~0.42 ms + one opening) instead of
a fresh wide-shape commitment — the audit's +116 KB-class toy-shape
delta becomes structurally sub-percent at scale.

## 4. The corrected ladder row (audit H-02 recost)

Accounting basis: committed element-equivalents per 7B/512-token
pass, INCLUDING w = 12 bit tensors, as carried by the two docs —
9.4e9 (`RING_MULT_BOTTLENECK.md` 6.4a) to 1.33e10
(`A1_AUX_NTT_REPORT.md` Section 6) [MODEL]; at the frozen point each
element costs 0.571 ring-MACs. Both ends of that band are quoted —
the band itself is a documented inconsistency the next pass-level
tranche should collapse.

| ladder row | value | status |
|---|---|---|
| commit rate, 1T, end-to-end at FFN shape | 4.86e6 ring-MACs/s (117 ns/paid el) | **[MEASURED]** (was: kernel-only anchor) |
| commit bill, 1T | 1104-1563 s (18.4-26.1 min) | [MEASURED-AT-RATE: measured rate x modeled element count] |
| 22-thread factor | **8.7x** (min-over-sessions; 9.1x best in-session, 6.9x under load) | **[MEASURED]** (was: ~15x ASSUMED) |
| commit bill, 22T | **126-179 s (2.1-3.0 min)** | [MEASURED-AT-RATE, at the measured 22T rate 4.25e7 ring-MACs/s] |
| commit bill, GPU | 6.3-8.9 s | **[ASSUMED 20x]** — no GPU kernel exists in this repo (audit H-03); this row is an assumption, not a measurement |
| claim layer per pass | ~288 matmul-class claims [MODEL: 9 matmuls/layer x 32 layers] x 0.346 s 1T chunked commit volume = ~100 s 1T -> ~11 s at 8.7x, + round proofs ~10-25 s wall 22T [MODEL, RING_MULT_BOTTLENECK 6.4b — gated on the CE-gate rounds at scale, not measured here] | [MODEL anchored to measured chunk rate] |
| R1 pads | +3 slots per quad claim in existing g-groups; +1 chunk commitment + opening per gate-only round (0.42 ms each) | [MEASURED at shape; sub-percent] |
| E2 zeta rows | weight computation inside existing rows, no commitment volume | [by construction] |
| E4 / lookup landing (activations) | 9 CtClaims + ~120 KB/pass + ~2.3e7 ring-mult-equivalents (~5 s 1T, <1 s 22T at the measured rate) | [MODEL, M4_LOOKUP_DESIGN] |
| **pass total, CPU 22T** | **commit 2.1-3.0 min + claim layer ~0.4-0.6 min => ~2.5-3.6 min** | [MEASURED-AT-RATE + MODEL claim layer] |
| pass total, with GPU 20x | ~15-30 s class only if the 20x row materializes | [ASSUMED] |

**Verdict on the "1.6-2.0 min at 22T" claim: it did NOT hold on this
box.** The single-thread arithmetic HELD — the ladder's own 1T bill
(1470-1790 s from 84-102 eff GMAC/s) overlaps the measured-at-rate
1104-1563 s band (the spread between the two is mostly the two
documented element accountings, not the kernel) — but the assumed
~15x multithread factor is not available on this 22-thread part:
8.7-9.1x measured. The honest CPU commit-bill row is **~2.1-3.0 min
at 22T**, roughly 1.3-1.5x the claimed band. The 15 s pass-total
rung now depends even more squarely on the [ASSUMED] GPU row,
exactly as audit H-03 warned. If ~15x thread scaling were available
(e.g. a homogeneous many-P-core part), the 1.6-2.0 min row would
return — but on the machine the ladder was written for, it
overstated parallel throughput by the ratio 15/8.7 ~ 1.7x.

## 5. What remains extrapolated / modeled (honest list)

1. **The GPU 20x factor** [ASSUMED] — no GPU kernel exists in this
   repo; every "~5-10 s" or "~15-30 s" pass row inherits it.
2. **Pass-level element count** [MODEL] — 9.4e9..1.33e10 committed
   element-equivalents per pass (two documented accountings that
   disagree by 1.4x; this tranche measured one FFN triple's worth,
   52.8M used / 92.3M paid, at rate).
3. **Claim-proof rounds at scale** [MODEL] — the pi2-CE ROUNDS (exec
   combination, round W/O proofs) are measured only at 128x256x64
   (2.0 s prove); this tranche measured the claim layer's COMMIT
   volume at FFN shape (817 chunks, 0.36 s 1T) but not the full
   round. The ~10-25 s wall/pass figure remains the docs' model.
4. **Activations** [MODEL] — the M4 LogUp-GKR design's ~120 KB +
   9 CtClaims + ~2.3e7 ring-mults per pass is a design-round costing,
   not an implementation measurement (E3/E4 build tranches pending);
   its ZK variant (E3-Z) is a design-blocking obligation.
5. **Padding waste** — C-columns pay 8x their used slots under the
   shared-CRS discipline (1.75x aggregate on this triple). A
   per-tensor msg_r class (or slot-packing C) is a straightforward
   follow-up that the recost above does NOT credit.
6. **Shared-box noise** — all numbers are min-over-3-sessions on a
   machine running sibling workloads; the 1T rows moved ~8% across
   sessions, the 22T rows ~20%.

## 6. Reproduction

```
cd zkmatrix-rs
PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release
./target/release/ring_matmul m5-bench                  # frozen FFN shape, 3 reps
./target/release/ring_matmul m5-bench 128 256 64 2     # smoke shape
./target/release/ring_matmul self-test                 # includes the [M5] battery
```

Raw logs: `docs/zkmatrix-poc/results/m5_bench_ffn_s{1,2,3}.txt`.

*Written at the M5-lite tranche, 2026-07-10. Companion docs:
LLM_SCALE_ESTIMATE.md (the ladder this corrects), RING_MULT_BOTTLENECK.md
Section 6, A1_AUX_NTT_REPORT.md, Q4_LEMMAS.md R1.4', SOUNDNESS_REFERENCE.md
Section 8, codex-audit-2026-07-09/FINDINGS.md H-02/H-03.*
