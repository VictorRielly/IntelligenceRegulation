# The road to five seconds a proof

**Status: DRAFT — delegated analysis, not yet reviewed by the
orchestrator.** Written 2026-09-19 by a delegated read-only analyst
working from the ledgers, the design memos and the retained measurement
records. No build, proof or benchmark was run for this page; every
number in it is quoted from an existing record and carries that record's
own label and path. Nothing here is a ruling, and nothing here changes a
privacy decision.

---

## 0. How to read this page

**The labels.** Every number below carries one:

* **[MEASURED]** — a run actually happened, on a named machine, with a
  log that still exists. If the box was shared with other jobs the row
  also says **NOISY-SHARED**, which on this laptop means the number may
  be wrong by up to about a factor of two run to run (the ledger
  documents ~2x run-to-run variance and ~6% on short repeats).
* **[COUNTED]** — arithmetic on measured pieces. No new run; the inputs
  are real.
* **[MODEL]** — an estimate from assumptions. The assumptions are always
  stated. A [MODEL] number is never a result.
* **[PREDICTION]** — a [MODEL] number that names the experiment that
  would settle it.

**The two traps this project has already fallen into twice, and which
this page obeys.** (1) Never compare a run on the processor (CPU) with a
run on the graphics card (GPU) as if only one thing changed — that is
what produced the wrong "private proving costs +178%" reading in round
14. (2) Never compare a public-weights arm with a private-weights arm
across two different devices — that is what produced the wrong
"238 → 499 s is the cost of privacy" reading in round 15, corrected the
same day. Where this page compares two things it says explicitly which
single thing varies.

**The names you will meet.** The project runs *lanes*: a lane is one
agent working in its own copy of the repository, owning a named set of
files, appending its results to a ledger. Lanes are named by two
letters. The ones that matter here:

| lane | what it did |
|---|---|
| **AC** | the per-model weight-commitment cache (`--wcache`) and the first 8B proof on the GPU (175 s) |
| **AH** | made the GPU kernels work at the real model's block shape (175 → 95 s) |
| **AI** | the private (`--zk`) 8B pass on the GPU, 265 s |
| **AJ** | the "host wall": uploads, packing, chunk parameters (95.5 → 86.0 s) |
| **AL** | the host allocation wall inside `layer.rs` (98.5 → **58.40 s**, the current best) |
| **AM** | the two privacy tiers at 8B; "hiding the weights costs under 3%" on the CPU path |
| **AO** | lever L9, the opening's re-encode kernels (1.29x on that phase, never applied to an 8B pass) |
| **CL1, CL4, CL6, CL7, CL18** | later Codex/Claude lanes that put the *hiding* (private-weight) commitment onto the GPU at the real model width and tuned its kernels |

"**The pass**" always means: Mistral-7B, all 32 feed-forward blocks,
512 tokens, one proof. "**FFN-only**" means the attention half of each
transformer layer is not in the proof — no 8B proof on any line
includes attention today.

"**Public IO**" means the non-zero-knowledge profile: the proof reveals
nothing about the weights beyond what is already public, but it does not
hide activations. "**P1**" means inputs, outputs and activations hidden,
weights public — the decided requirement for the first PoC. "**P3**"
additionally hides the weights.

## 1. The true current numbers

### 1.1 What the target actually says

From `TARGET_CONTRACT.md` (frozen benchmark boundary) and `START_HERE.md`
§2:

* **The claim**: 5 to 15 seconds per proof, **p95** over at least 20
  warm runs on an otherwise idle machine, with the median reported
  alongside and the first (cold) run reported separately
  (`MEASUREMENT_PROTOCOL.md` §1 pins the percentile as nearest-rank).
* **The workload**: one 512-token prefill through the feed-forward
  blocks of a 7–8B model — 32 blocks, width 4096, hidden width 11008 in
  the contract's surrogate. Every measurement below uses **Mistral-7B's
  hidden width 14336**, which is the wider 8B-class shape, so the
  measured runs are *harder* than the contract's surrogate, not easier.
* **The machine**: one consumer GPU, **at most 600 W** board power. The
  bound was 450 W and was **amended to 600 W by Victor's console ruling
  of 2026-09-04**, precisely so that the RTX 5090's 575 W part is inside
  it. Capping the card with `nvidia-smi -pl 450` is therefore *not*
  required; a capped number may be recorded alongside for comparability
  with the pre-ruling series.
* **What the clock covers** (contract §3, and this matters): it starts
  with the committed model and the input tokens in memory and stops when
  the serialized proof bytes exist. It **includes witness inference —
  the quantized forward pass** — every per-proof commitment, every
  claim/lookup/link proof, hashing, and serialization. It **excludes**
  one-time setup: the common reference string, the transform caches,
  **committing the weights**, and freezing the activation table.
* Two other contract lines are relevant and are both unmet by a wide
  margin: the **verifier budget** is ≤ 2 s single-threaded, and the
  **proof-size budget** for the private tiers (P1–P3) was frozen at
  **1,114,112 bytes per 32-layer pass**. Today's 8B proof is
  1,234,936,956 bytes — about **1,100× over that frozen line**. Speed is
  not the only unmet contract clause; it is the one this page is about.

### 1.2 The best public-IO 8B feed-forward proof, phase by phase

This is the fastest 8B pass ever run in this project, on any line.

**Row: Mistral-7B, all 32 feed-forward blocks, 512 tokens, public IO
(profile v3, no zero-knowledge), laptop RTX 4070 Laptop (8,188 MiB,
55–70 W) plus 8 CPU threads, cold weight cache (32 misses, 0 hits),
shared box.** [MEASURED, NOISY-SHARED, 2026-09-04]
Log `results/hashline_convert_r3.log`; write-up
`results/hashline_convert_gpu.md` §7; ledger
`PROGRESS_UPERF3.md`, "AL rung 3" (line 12958); merged as `22b975f`.

| | before (lane AL's switches off) | **after — the current best** |
|---|---:|---:|
| **PROVE** | 98.54 s | **58.40 s** |
| commit W (the weights) | 43.901 | **19.823** |
| commit A (the activations) | 16.155 | **4.838** |
| LogUp helpers + commit H | 5.552 | 5.555 |
| matmul sumcheck, gate/up pair | 5.816 | 3.441 |
| matmul sumcheck, down | 3.070 | 2.092 |
| zero-checks F + D | 5.490 | 5.468 |
| openings (the PCS) | 18.557 | **17.176** |
| *phases sum to* | *98.54* | *58.39* |
| witness load from disk | 141.76 | 134.50 |
| verify | 1.65 | **1.08** |
| process wall | 244.45 | **196.79** |
| proof bytes | 1,234,936,956 | 1,234,936,956 |
| proof sha256 | `dc980e81..4536c` | `dc980e81..4536c` — **identical** |
| VRAM peak | 5,249 MB | 5,249 MB |
| peak host RSS | 3.93 GB | 4.69 GB |
| proven int8 multiply-accumulates/s | 2.929e10 | **4.943e10** |
| tokens/s at 8B prefill (512 ÷ prove) | 5.20 | **8.77** |

**Inside the device, where the after-arm's time goes** [MEASURED, same
run]: host→device transfer 8.597 s (9,328 MB moved), encode transform
(NTT) 13.877 s, hashing 0.481 s, sumchecks 5.465 s, folds 2.850 s,
helper kernels 1.378 s, the opening's re-encode 13.826 s. Those sum to
**46.47 s of the 58.40 s, so 11.9 s (20.4%) is host work** — down from
49.8 s (50.5%) in the before arm. Of the remaining host time, about
**7.5 s is `layer.rs` residue** (per-layer fill 0.049 + 0.035 s, commit
residual 0.017 s, folds 0.135 s) and the rest is the openings' and
helpers' host tails.

**A caveat about which clock this is, and it is not a small one.** The
58.40 s figure is the *prove* clock. The contract's clock also contains
witness inference. The 134.50 s "witness load + chain" line is **not**
inference: reading `hashline/src/bin/hashline.rs` (the `pass … --profile
v3` path), that timer wraps `load_witness_v3`, which reads
already-computed activation planes off disk. The quantized forward pass
itself is done ahead of time by a Python exporter and **has never been
measured at 8B inside a prover run**. So:

* the honest *prover-arithmetic* number is **58.40 s**;
* the honest *end-to-end process* number is **196.79 s wall**, of which
  134.50 s is disk I/O for a witness the contract says should be
  computed, not loaded;
* **no number in this repository is the contract clock as written.**
  Producing one is cheap (instrument the Rust re-execution path the
  `chain` subcommand already has) and is listed as lane 3 in §6.

### 1.3 Is 58.40 s real, and is the status page stale?

**58.40 s is real.** It is recorded three times, consistently:

1. `results/hashline_convert_r3.log` — the raw log of the detached run
   (both arms, one session, one binary, `/usr/bin/time -v`, exit-0
   marker).
2. `results/hashline_convert_gpu.md` §7 — the lane's write-up with the
   full table reproduced above.
3. `PROGRESS_UPERF3.md` line 12958, "AL rung 3", and the task board
   entry "LANE AL IS MERGED (22b975f) — THE HOST WALL IS GONE".

**What makes it trustworthy is not the seconds, it is the digest.** The
proof is `dc980e81…4536c` at 1,234,936,956 bytes — the same sha256 as
the before arm, as the 175 s and 95 s GPU runs, as the 510 s CPU
reference, and as the cached and uncached forms. The project's
byte-identity gates are its strongest instrument: an optimisation that
changes a byte is a bug, and none of these did.

**What is fragile about it**: one run per arm on a shared box with
~6% per-phase and up to ~2× whole-run variance; a cold weight cache;
and no p95 over 20 warm runs, so it is **not a contract-grade
measurement** under `MEASUREMENT_PROTOCOL.md` §3. The lane itself gives
two framings and says which to quote: the in-session A/B is **1.687×**
(98.54 → 58.40); against lane AJ's recorded 86.00 s it is **1.47×**, and
that conservative form is the one to use against the ledger.

**`MVP_STATUS.md` is stale on this point.** Its §2 table still reads
"prove 95 s … 19× slower than 5 s" and its activation-side table still
uses lane AH's 95.5 / 41.9 / 53.5 s split. The current figures are:

| | MVP_STATUS.md today | the ledger's current truth |
|---|---:|---:|
| 8B public-IO prove, laptop GPU | 95 s | **58.40 s** |
| distance from 5 s | 19× | **11.7×** |
| distance from 15 s | 6× | **3.9×** |
| commit W share | 41.9 s of 95.5 | **19.8 s of 58.40** |
| activation side (W subtracted) | 53.5 s → 9.6 tok/s | **38.58 s → 13.3 tok/s** |
| tokens/s including W | 5.4 | **8.77** |

`START_HERE.md` §3.1 carries the same stale 95 s row. Both should be
refreshed; neither is wrong about anything except being one lane behind.

### 1.4 The private profiles, and why none of them is an accepted P1 number

**First, the thing that governs all of these rows.** On 2026-09-08 the
project recorded that *the legacy hash-line `--zk` / `--p3` feed-forward
proofs have demonstrated private-value disclosure in synthetic
fixtures*, so their verification and frozen performance results **do not
establish zero knowledge** (`START_HERE.md`, privacy correction). The
rows below are therefore **cost measurements of that machinery**, not
privacy results. A repaired private feed-forward exists only at the tiny
shape (`hashline/src/zk_ffn_fresh_io.rs` and the private-block work of
2026-09-19), and its cost at width 4096 is unknown.

**(a) The 8B pass with the legacy privacy profile on the GPU.**
[MEASURED, NOISY-SHARED, 2026-09-04], lane AI, log
`results/hashline_zk_8b_pass_gpu.log`, record
`results/hashline_zk_8b_gpu.md`; cold weight cache.

| | value |
|---|---:|
| PROVE | **265.34 s** |
| commit W | 54.176 |
| commit A (hiding) | 24.568 |
| mask commit | 0.230 |
| **LogUp helpers + commit H** | **146.259 (55% of the prove)** |
| matmul sumchecks (g/u + d) | 10.642 |
| zero-checks F + D + table | 11.539 |
| openings | 17.797 |
| verify | 2.33 s |
| proof | 1,285,578,368 B, sha256 `930ce9a0…c982e` |
| VRAM peak | **8,585 MB on an 8,188 MiB card** |
| peak RSS | 4.30 GB |
| witness load / wall | 131.79 / 402.29 s |

Device side: transfer 16.862 s (61,018 MB), **encode transform 119.10 s**
against the public arm's 15.85, hashing 8.068, sumchecks 9.804, folds
5.874, helpers 19.625.

Lane AM reproduced the **same digest and byte count** on a different
worktree at 238.37 s — the ledger is explicit that this is **noise, not
a speedup**, because AM's tree predates lane AL and has no mechanism for
it.

**The 8,585 MB peak is the story of this row.** The card is 8,188 MiB.
Under WSL an over-budget allocation is served from host memory instead
of failing, so the run does not crash — it pages. Layer 0 proves in
**4.36 s** (it happens to get real video memory); layers 1–31 average
**8.42 s**. The ledger's conclusion, and it is a prediction with a named
experiment: *"a 16 GB+ board should give ~140 s instead of 265 with no
code change"* [PREDICTION]. A per-layer memory drain (`HL_ZK_DRAIN`) is
load-bearing — with it off, layer 1 dies at `cuMemAlloc(1514 MB)`.

**(b) The one-axis privacy cost: what hiding the weights actually
costs.** Same binary, same seed, same shape, same CPU path; the *only*
variable is the mode. [MEASURED, 2026-09-04], lane AM, logs
`results/am_r3_8b_p1_scan_cpu.log` and `results/am_r3_8b_p3_cpu.log`.

| | P1 (weights public) | P3 (weights private) | cost of hiding |
|---|---:|---:|---:|
| PROVE | 485.33 s | 499.04 s | **+2.82%** |
| commit W | 214.337 | 217.694 | +1.57% |
| VERIFY | 1.95 s | 1.99 s | +2.1% |
| proof bytes | 1,285,578,368 | 1,287,678,592 | **+0.163%** |
| peak RSS | 13.27 GB | 13.97 GB | — |

That is the cleanest comparison in the repository and its headline is
**hiding the weights costs under 3%**. It also settles a trap the ledger
walked into and corrected the same day: `commit W` is ~44% of the prove
in *both* modes, so it is the cost of committing weights at all, not of
hiding them.

**(c) Private weights on the device at the real model width — one
layer.** After the 2026-09-04 lane CL1 work (`ZK60_CLAUDE_GPU.md`), the
hiding commitment chunks and therefore *fits*: one Mistral layer,
T = 512, both arms on the GPU in one session, **P1 3.453 s → P3 4.142 s
= +20.0%**, proof +0.163%, VRAM peak 5,182 MB (P3) against 5,282 (P1),
flat across four layers. The same layer had read 15.82 s when the device
commit was declined, so **15.82 → 4.142 s = 3.82× purely by fitting on
the card**. Later lanes trimmed it further: CL7 fused and pruned the
hiding opening's re-encode (that phase 0.575 → 0.470 s, 1.22×, 2.6% of
the prove) and CL18's compact pad/scale output took the whole layer
**4.346 → 4.089 s (−5.9%)**, default OFF.

**(d) What has never been run.** There is **no 32-layer 8B P3 pass on a
GPU**, anywhere, in any log. There is no 8B pass of any kind that
includes attention. And lane AL's 1.687× host fix was applied to
`layer.rs` only — `zk.rs` carries its own prover body with its own
staging buffers and **was deliberately not touched**, so the private arm
has never received the single largest speedup this project has found.

### 1.5 The distance from 5 s and from 15 s

All rows are the prover clock at 8B, 32 FFN layers, 512 tokens, on the
laptop's RTX 4070 (8 GB) unless stated.

| arm | prove | ÷ 5 s | ÷ 15 s | label |
|---|---:|---:|---:|---|
| **public IO, GPU (the best row)** | **58.40 s** | **11.7×** | **3.9×** | [MEASURED, NOISY-SHARED, 2026-09-04] |
| public IO, GPU, activation side only (weights pre-committed, an optimistic boundary) | 38.58 s | 7.7× | 2.6× | [COUNTED] |
| public IO, CPU 8 threads | 510.38 s | 102× | 34× | [MEASURED] |
| legacy privacy profile, GPU (paging) | 265.34 s | 53× | 17.7× | [MEASURED, NOISY-SHARED] |
| legacy privacy profile, GPU, on a card that does not page | ~140 s | ~28× | ~9.3× | [PREDICTION, no code change] |
| legacy privacy profile, CPU 8 threads | 485.33 s | 97× | 32× | [MEASURED] |
| private weights (P3), CPU 8 threads | 499.04 s | 100× | 33× | [MEASURED] |
| private weights (P3), GPU, 32 layers | — | — | — | **never run** |
| whole process wall (load + prove + verify), public IO, GPU | 196.79 s | 39× | 13× | [MEASURED] |

**The one-sentence version.** On the machine we have, the fastest honest
8B feed-forward proof is **11.7× away from 5 s and 3.9× away from 15 s
for the public-IO arm**, and the privacy arm that the product actually
requires is **53× away and does not yet have a trustworthy privacy
construction at that width**.

## 2. What a proof costs once the weights are already committed

The target is **per proof**. Committing the weights is **per model**, and
the contract explicitly carves it out of the clock. So the fair question
is: with the weights already committed, what does the next proof pay?

**The answer today is: most of it.** The weight commitment is 19.823 s
of the 58.40 s pass (34%), and a warm cache removes only part of that.

**Why.** The commitment is a Reed–Solomon encoding of the weight matrix
plus a Merkle tree over its columns. The cache (`--wcache`, lane AC) can
store the tree. It cannot store what the *opening* needs: the 256
columns the verifier will ask for are chosen by the Fiat–Shamir
transcript **after** the root has been absorbed, so the prover must be
able to produce any of the 65,536 encoded columns at opening time. On
the device path the encoding is regenerated in chunks every proof. In
the ledger's words: *"the cache removes the hashing and the tree build;
the encoding is paid again at the opening."*

**What the warm path actually pays** [MEASURED, 2026-09-03, lane AC's
tree, `results/hashline_8b_gpu.md`], 32 layers, GPU:

| | cold (every entry a miss) | warm (every entry a hit) |
|---|---|---|
| commit itself | 21.02 s | — |
| key computation | 0.49 s | 0.52 s |
| save / load + Merkle re-verify | 0.06 s (write 134.2 MB) | **0.49 s** (read 134.2 MB, every tree re-hashed level by level) |
| **Reed–Solomon re-encode** | *(inside the commit)* | **11.53 s** |
| total | **21.57 s** | **12.54 s** |

So the cache is worth **9.0 s of the 32-layer GPU prove** and no more —
about 5% of that run. On the CPU path the same cache removes ~2.1 s per
layer, ~67 s of 510. At the small 125M shape the later CL9 lane measured
it at ~0.14 s of a 5.4 s prove, **inside the run-to-run spread**, and
wrote the warning plainly: *"a plan that assumes warm-cache proofs are
materially cheaper is assuming something the measurements do not
support."*

**On today's tree this has never been measured.** Lane AL's after-arm
shows cold `commit(miss)` at 17.028 s inside a 19.823 s commit-W phase,
both arms deliberately cold so the cache could not mask the A/B. If the
warm re-encode is unchanged (lane AL touched no kernel; lane AO's
pad-skip counts ~1.16× on that encode), a warm pass would pay roughly
**11–13 s instead of 19.8 s**, putting the prove near **49–51 s**
[COUNTED, unverified — the assumption is that the warm re-encode has not
moved]. **Measuring it is one command and nobody has run it.**

**Three things break the amortisation, and they should be stated
together:**

1. **The warm cache is unusable on the GPU privacy path.** At Mistral
   width, the first cache hit is followed immediately by
   `gpu helpers (zk v3): cuMemAlloc(379 MB): CUDA_ERROR_OUT_OF_MEMORY`
   [MEASURED, `results/hashline_zk_8b_wcache_e4.log`]. On a hit,
   `reencode_store` keeps the re-encoded weight matrix device-resident
   for the whole layer, where the miss path streams it. It is safe only
   while it *misses*. Every private 8B number in this repository was
   taken on a fresh (cold) cache for that reason. This is an owed fix in
   `wcache.rs`.
2. **Under private weights (P3) the cache is forbidden outright**, and
   not by accident. A cached hash-based weight commitment publishes 256
   encoded columns per proof; after **(n+Q)/Q = 65 proofs** every row is
   determined and the weights are recoverable by linear algebra
   [COUNTED, `U_PERF3_ROUTE_B_THROUGHPUT.md` §4.4]. So P3 must re-commit
   the weights, hidingly, on every proof: **+44% at 8B × 512** [COUNTED].
   The code enforces this — a process that has configured a weight cache
   refuses to serve a P3 proof.
3. **The obvious "just store the encoded rows" fix is worse, not
   better.** Persisting them is 5.6 GB per layer, 180 GB per model; on
   the CPU it trades the transform for a disk read of the same size, and
   on the device it would put 180 GB back on the bus. The other recorded
   idea — serving the 256 columns by direct evaluation without
   materialising the matrix — costs about **4.5e10 field products per
   layer**, against roughly **6.9e9 butterflies** for the whole
   transform. On the CPU those are comparable (lane AC counted 1–4 s
   against ~5 s for the transform); **on the device the transform is
   about 0.36 s per layer and direct evaluation would be several times
   worse.** I flag lane AC's "[MODEL] 1–4 s" as a CPU-path number that
   should not be carried to the device.

**What a truly amortised path would pay, and it is the honest floor.**
With the tree cached and the encode made as cheap as the hardware
allows, the per-proof weight side is: load and validate 134 MB of cached
trees (~0.5 s measured) plus one output-pruned transform over the weight
matrix. The transform is the right algorithm at Q = 256 — the question
is only how close to the memory roof it runs, which is exactly lever L9
(§3). The project's own spec-sheet floor for the per-proof weight side
at 8B is **10–20 ms on one H100** [COUNTED on spec sheet,
`U_PERF3_ROUTE_B_THROUGHPUT.md` §2.3], against 151 s modelled on this
laptop's CPU — a reminder of how much of the present number is hardware
and marshalling rather than algorithm.

**The bottom line for §5's plan:** budget the per-proof weight cost at
**11–13 s today with a warm cache [COUNTED]**, not at zero, and treat
"make the encode cheap" — not "cache harder" — as the lever.

## 3. Every recorded lever, one row each

Every number in this section names the shape it came from. **A factor
measured at the 125M shape or at one Mistral layer is not a factor on
the 8B pass**, and where only that exists the row says so.

### 3.A Built, merged, and already inside the 58.40 s

| lever | what it is | worth on the 8B pass | bytes | notes |
|---|---|---|---|---|
| **AH — shape-general kernels** | the device kernels were templated on the small model's block shape and declined Mistral's, leaving 44% of the work on the CPU | 175.09 → 95.48 s, **1.83×** [MEASURED 8B] | unchanged | this is the "device-shape gate" the brief asks about: for the **public** path it is **closed**. It is still open on the private path (§3.C) |
| **AJ — narrow upload, pinned interleaved staging, chunk/thread defaults** | send int8 planes as bytes and rebuild field elements on the device; overlap the copy with the encode; chunk 128 rows, 512 NTT threads | 88.90 → 86.00 s, **1.034×** [MEASURED 8B]; bus traffic 59,861 → 9,328 MB (6.4×); VRAM −402 MB | unchanged | the time win is small **on this box** because the copy was already hidden. It is kept because it is the right structure the moment the device is faster than the bus — i.e. the 5090 |
| **AL — host staging pool + int8-plane folds** | `vec![Fp::ZERO; w_len]` does not become a zeroed allocation for a user type, so every layer single-threadedly wrote 1.4 GB of zeros it then overwrote; and the weight blocks were folded twice over two copies of the same numbers | 98.54 → **58.40 s, 1.687×** in-session; **1.47×** against the ledger's 86.00 s [MEASURED 8B] | unchanged, digest `dc980e81..` | the largest single win in the project. Host time inside the prove 49.8 → 11.9 s |
| **AK — the claim fold (L5)** | fold every pending claim into the two zero-checks and open at two points instead of ~41 | 12-layer proof **404.3 → 282.2 MB (−30.2%)**, **verify −69%**, prove **+7.1%** [MEASURED at 125M, 12 layers] | **yes, by design** | a bytes-and-verifier lever that costs a little prove time. No 8B figure exists |

### 3.B Built and merged, but never measured on an 8B pass — the cheapest value available

| lever | what it is | worth | bytes | cost / risk |
|---|---|---|---|---|
| **AO — L9, the opening's re-encode kernels** | three byte-identical kernel rewrites: the first two stages of a zero-padded transform are a broadcast not arithmetic (**1.37×** on that kernel); a runtime 32-bit integer division per butterfly replaced by shift-and-mask (**1.18×**, and *parity* on the kernel already at the memory roof — the control that proves the mechanism); and output pruning, since only **244 of 4,096** column residues can produce a sampled output (**4.38×** on that kernel) | four re-encode kernels **1.484×**, `columns_chunked` end-to-end **1.292×**, the commit's encode **1.156×** [MEASURED, small shapes, ABBA over four processes, spread 2.5%]. Projected onto the 58.40 s pass: re-encode 13.83 → ~10.7 s, encode 13.88 → ~12.0 s, **≈ 4 s, about 1.07×** [COUNTED] | unchanged — **twelve byte gates green twice**, and the device-vs-CPU oracle compares the re-encoded opening columns element for element | already paid for. **The lane was forbidden from running an 8B pass** ("do not quote a headline from this box"), so the value sits unrealised. AO's own closing projection used the stale 86 s baseline and the task board corrected it: post-AL the device is ~80% of the prove, so device work is worth *more*, not less |
| **CL7 — the same fusion and pruning for the hiding opening** | the private path's re-encode had never received AJ's fusion or AO's pruning | that phase **0.575 → 0.470 s, 1.22×**; **2.6% of one Mistral P3 layer's prove** [MEASURED, one layer] | unchanged | no 8B figure |
| **CL1 — the hiding commitment chunks** | the non-hiding commit had chunked by size and fallen back on allocation failure since lane AC; the hiding commit took both full buffers unconditionally and died. Derived peak **13,491 MiB** on an 8,188 MiB card, largest single take **5,387 MiB** — exactly the observed failure | one Mistral layer **15.82 → 4.142 s = 3.82× purely by fitting**; P3 vs P1 on the device **+20.0%** (4.142 vs 3.453 s); VRAM 5,182 MB, flat over four layers, 37% headroom [MEASURED, one layer] | unchanged; digests reproduce lane AM's exactly, so it is also a CPU/GPU byte-identity gate at real width | **this is the most important unmeasured result in the repository.** Every 8B private number predates it |
| **CL18 — compact pad/scale output** | the pad/scale kernel wrote a zero tail three-quarters of each row that the next kernel read back and never used | one Mistral P3 layer **4.346 → 4.089 s (−5.9%)**, changed phase 1.090 → 0.923 s, VRAM −34 MB [MEASURED, one layer] | identical across arms | **default OFF**; promotion is an integrator's decision. Per-chunk traffic −20.6% (commit) and −34.7% (opening), and the measured gain sits inside that bound, so the kernels are only *partly* bandwidth-bound |
| **CL4 — a double-charged device NTT counter** | an accounting bug, not a speedup: the chunked path counted the transform twice (1.262 → 0.603 s at Mistral width) | none | none | it means some older device-NTT figures overstate that phase |

### 3.C Named, attributed, not built

| lever | what it is | worth | shape | bytes | who |
|---|---|---|---|---|---|
| **The rest of L9** | `k_dit_p1_pad_s` is still **56% of the four re-encode kernels** at 105 GB/s (41% of the 256 GB/s roof) and 52.7e9 butterfly/s (11% of the ALU roof) — the one kernel that is neither bandwidth- nor compute-bound. Two named, untried items: the residual shared-memory bank conflicts in stages 3–4 (a warp lands on 8 distinct banks instead of 16), and the fact that its 537 MB of writes per chunk are read exactly once by the very next kernel. `k_dif_pb` (27% of the four) is untouched, same family | if the pad kernel reached the 77–78% roof its siblings hold, the four kernels go ~0.119 → ~0.085 s = **~1.4×** on 27.7 s of device transform work ≈ **6 s of the 58.40** [COUNTED, my arithmetic on AO's table] | 8B W shape (10,752 rows), measured on this box | byte-preserving by construction, gated by twelve gates and the column oracle | mechanical kernel engineering to an existing attribution |
| **The host tail of `columns_chunked`** | an unpooled 22 MB device allocation, a 22 MB download, and a serial host loop copying 2.75 M field elements into 256 vectors | ~0.048 s per call = **40% of what the four kernels now cost**; jittery (3.6–21% of the call) [MEASURED, small shape] | — | zero byte risk; it is all in `gpu/cuda.rs` | mechanical |
| **Port lane AL's host fix into `zk.rs`** | `zk.rs` carries its **own** v3 prover body with its own staging buffers (`zk.rs:925-966`); lane AL deliberately did not touch it, so the private path never received the 1.687× | unknown on the private arm; the identical change was **1.687×** on the public one, and the private arm's host share has never been attributed | 8B, private | byte-preserving by the same tiling argument; gated by the two ZK byte gates `021485e4..` and `40eb5479..` | **unowned.** The single largest known unrealised factor on the tier the product actually needs |
| **L8 — recover the ZK surcharge on the device** | on the private 8B pass, **helpers + commit H is 146.26 s of 265.34 (55%)** against the public arm's 5.36 s, and the device transform is **119.10 s** against 15.85 | up to **2.1×** [COUNTED from lane AI's phase table] | 8B, private, GPU | unchanged (bytes already carry over at +4.10%) | partly answered already: CL1 suggests much of it was the card, not the argument. Needs the 32-layer re-run before more design work |
| **L3 — general kernel quality** | ordinary device engineering toward the counted spec-sheet floor | **1.5–5×** [COUNTED] | 8B GPU | — | nobody has done a systematic pass on this codebase for a device |
| **Merkle cap** | truncate the top levels of the Merkle paths | **−29% of the proof bytes at zero soundness cost and zero prover cost** [COUNTED] | 125M and 8B | **yes** (that is the point) | not implemented; free money on the bytes line |

### 3.D Levers that are rulings, not lanes

| lever | what it is | worth | status |
|---|---|---|---|
| **L4 — fewer hashed bytes** | halve or quarter the bytes that must be hashed per proof: encoding rate 1/2 instead of 1/4, and/or a 31–32-bit field instead of the 64-bit Goldilocks | **2–4×** [MODEL] — *the largest single lever recorded anywhere in this project* | **DEFERRED BY RULING (2026-09-04).** It changes the soundness accounting and **every frozen digest in the repository**. It starts with a costed design memo, not code |
| **Compact (BaseFold-class) PCS — lane AF** | replace the Ligero-class opening with a batched evaluation sumcheck driving a FRI fold | one Mistral layer **38.7 → 1.94 MB (19.9×)**; 8B projection **~62 MB against 1,234.9 MB**; verifier **10–15× faster** — but the **prover is 4.36× slower at 8B** [MEASURED at one layer, COUNTED at 8B] | **pending ruling D10**: soundness drops to **95–98 bits from 106**. Also *not hiding* (`--pcs compact --zk` is refused) and **no GPU implementation exists**. It moves the project *away* from 5 s and *towards* the frozen byte budget |
| **Two-tier ("square-root") opening + weight preprocessing** | the literature's answer: commit blocks, run the expensive argument on a square-root summary, preprocess the weight side once per model | measured at **parity** (2.08 s against 2.09 s) at 12×512 on this GPU; the S4 spike measured **1.08–1.10× against a 5× bar**; the paper redesign counted **1.6–2.5×** | **CLOSED by its own memo**: *"the 5–15 s question on this line is CLOSED unless a structurally new idea arrives."* Note this is a **lattice-line** lever; it is not a hashline lever, and the hash line is the only line that can approach the target |
| **L1 — a bigger board** | see §4 | see §4 | Victor's; the 5090 is available and not installed |

### 3.E The divisors — things that make the number worse, and must be in any honest plan

| item | cost | label |
|---|---|---|
| **Attention in the statement (D1)** | **×2.87** at 8B, T = 512 | [COUNTED, lane AE]. Measured at smaller contexts: ×1.17 at T = 16, ×1.61 at T = 64 (lane AG). No 8B proof on any line includes attention |
| **Zero knowledge for inputs/activations (D2)** | **×2.78 on a GPU** | [MEASURED, lane AI]. The earlier ×1.047 was a **CPU-only artefact** and is retracted for device rows — on the CPU the ZK work hides inside 15 s of host arithmetic; on the device the base is 3 s of kernels |
| **The range facts the contract still owes (D3)** | ×1.15–1.20 | [MODEL]. Input-token and weight ranges are *declared* in the statement, not range-proven — an open soundness item, not optional for a rigorous claim |
| **Hiding the weights on top of that (P1 → P3)** | **×1.028** | [MEASURED, one-axis, CPU path]. Essentially free once ZK is paid for |

### 3.F The video-memory problem, which is a lever in both directions

* The **public** 8B pass peaks at **5,249 MB** on an 8,188 MiB card — comfortable.
* The **private** 8B pass peaks at **8,585 MB on an 8,188 MiB card**. Under
  WSL an over-budget allocation is served from host memory rather than
  failing, so it pages continuously: the kernel logged
  `dxgkio_make_resident: Ioctl failed: -12` in pairs every ~2 minutes for
  the whole six-minute run. **This box froze three times on 2026-09-04**
  and the standing rule since is that the 8B private pass is itself a
  freeze risk and must never be chained behind another GPU job.
* The consequence for the numbers: layer 0 proves in **4.36 s** and
  layers 1–31 in **8.42 s**. *"A 16 GB+ board should give ~140 s instead
  of 265 with no code change"* [PREDICTION]. That is a free ~1.9× on the
  private pass, purchasable rather than programmable.
* CL1's chunking then reduced the private *per-layer* peak to **5,182 MB
  with 37% headroom**, so an 8B private pass on this card is now
  plausible [PREDICTION, never run].

### 3.G The item nobody counts because it sits outside the headline

The 8B pass spends **134.50 s loading the witness from disk** — 2.3×
the prove itself. It is outside the prove clock, inside the wall, and
**inside the contract clock** in the form the contract actually
specifies (witness inference). No lane has ever owned it. Any statement
of the form "we are at N seconds" that quotes the prove clock is
quoting a number that assumes the activations arrive for free.

## 4. What different hardware changes, phase by phase

### 4.1 The project's own cost model (not invented here)

`U_PERF3_THROUGHPUT_MODEL.md` §3.3 states it exactly:

> Let c, g, l be the CPU-, GPU- and link-bound fractions of the pass
> wall, and k_c, k_g, k_l the per-resource speedups of the new machine.
> The composed factor is **1 / (c/k_c + g/k_g + l/k_l)** (Amdahl's law by
> resource).

and §3.2 gives the resource ratios, using SM×clock as the integer-ALU
proxy and raw memory bandwidth for streaming and hashing work:

| part | SM×GHz | memory bandwidth | ALU ratio vs the laptop | bandwidth ratio |
|---|---:|---:|---:|---:|
| **RTX 4070 Laptop** (every measurement in this document) | 54–72 | **256 GB/s** | 1× | 1× |
| **RTX 5090** | 410 | **1,792 GB/s** | 5.7–7.6× | **7.0×** |
| H100 PCIe | 200 | 2,000 GB/s | 2.8–3.7× | 7.8× |
| H100 SXM | 261 | 3,350 GB/s | 3.6–4.8× | 13× |

The memo's own surprise, worth repeating: **on scalar integer work an
H100 is not faster than a 4090** — it has fewer SM-GHz. Its advantages
for this mix are bandwidth and capacity.

### 4.2 The 58.40 s pass, phase by phase, sorted by what bounds it

| phase | seconds | what bounds it | evidence | does a 5090 help? |
|---|---:|---|---|---|
| host residue in `layer.rs` (per-layer fill, commit residual, folds) | ~7.5 | **host** | lane AL's own attribution | **no** |
| host tails of the openings and helpers | ~4.4 | **host** | 11.9 s total host minus the above | **no** |
| host→device transfer | 8.597 | **link**, partly host (the counter holds waits: 9,328 MB in 8.597 s is 1.08 GB/s effective against a measured 5.4–5.6 GB/s raw copy rate) | lane AJ rungs 1 and 3 | partly — and this is where AJ's 6.4× traffic cut finally converts |
| the commit's encode transform | 13.877 | **mixed**: two of the four kernels run at 197.6 and 200.5 GB/s = **77–78% of the 256 GB/s roof and closed**; one (`k_dit_p1_pad_s`) at 105 GB/s and 11% of the ALU roof = **neither, a latency/occupancy item** | lane AO rungs 1–3, measured per kernel | the closed ones scale ~7×; the latency one is uncertain |
| the opening's re-encode | 13.826 | same mix, same kernels | lane AO | same |
| sumchecks | 5.465 | **compute / integer ALU** | the model's class 1 | ~5.7–7.6× |
| folds, helpers, hashing | 4.709 | **bandwidth** (streaming passes over 64-bit planes) | the model's class 3; CL6's chunk sweep shows the chunk loop is bandwidth-bound on the encoded scratch — time is invariant to chunk height while memory scales linearly | ~7× |

### 4.3 The projection

Applying the project's own formula to the measured split (device 46.47 s,
host 11.9 s), with the **same host CPU**, k_g between 4 and 7 (the
latency-bound kernel drags the effective device factor below the 7.0×
bandwidth ratio) and k_l between 1.5 and 3:

| assumption | arithmetic | 8B public-IO prove |
|---|---|---:|
| conservative (k_g 4, k_l 1.5) | 11.9 + 5.73 + 9.47 | **27.1 s** |
| mid (k_g 5.5, k_l 2) | 11.9 + 4.30 + 6.89 | **23.1 s** |
| optimistic (k_g 7, k_l 3) | 11.9 + 2.87 + 5.41 | **20.2 s** |

**[MODEL] — the RTX 5090 gives roughly 20–27 s on the 8B public-IO
feed-forward pass, about 2.2–2.9×.** Assumptions, stated: the same host
CPU and the same host code; no lever from §3.B or §3.C landed; a cold
weight cache; the prove clock only, so the 134.50 s of witness loading
is excluded and would not shrink.

Put the card in a **desktop host** (the model's k_c = 2–4) and the same
arithmetic gives **14–21 s, about 2.8–4.1×** — which is where the
runbook's "4×" lives.

**The number that matters more than any of these.** With the host at
11.9 s and unchanged, **an infinitely fast graphics card gives 58.40 →
11.9 s, a hard ceiling of 4.9×.** No board, at any price, takes the
present code under 5 s. Reaching 5 s *requires* host work, not only
hardware. That single line drives §5.

### 4.4 What "buys about 1.4× until the host wall lands" actually said,
and what it means now

The phrase is a paraphrase; the source is
`BLACKWELL_5090_RUNBOOK.md` §2, headed **"THE AMDAHL WARNING — the board
buys ~1.4×, not 7×, today"**, with the arithmetic done on the *then*
current pass:

```
device 33-40 s / 7  =  4.7-5.7 s
host   56-63 s      =  unchanged
total               =  61-69 s   (from 95.5 s)   -> ~1.4x
```

and the conditional sentence: *"The `layer.rs` item is what decides
whether the 5090 buys 1.4× or 4×."*

**The host wall has since landed** (lane AL, merged 22b975f): host time
inside the prove is 11.9 s, not 56–63 s, and the device is now ~80% of
the pass. Redoing the runbook's own arithmetic on the current pass gives
**2.2–2.9× with this host CPU** and **2.8–4.1× with a desktop host** —
so the condition in that sentence is satisfied and the answer moved
towards the 4× end, but it **did not move to 7×**, because Amdahl now
binds on a smaller but still real host residue. Anyone quoting "1.4×"
today is quoting a pre-AL number.

### 4.5 What the bigger card does for the private pass

Two effects, and they must not be multiplied together carelessly.

1. **Not paging.** The private 8B pass spills to 8,585 MB on an
   8,188 MiB card; layer 0 (which gets real video memory) proves in
   4.36 s and layers 1–31 in 8.42 s. *"A 16 GB+ board should give
   ~140 s instead of 265 with no code change"* [PREDICTION,
   `BLACKWELL_5090_RUNBOOK.md` §6]. That is ~1.9×, free, purchasable.
2. **Already partly collected in code.** CL1's chunking brought the
   private per-layer peak to 5,182 MB with 37% headroom *on the 8 GB
   card*, and took one Mistral layer from 15.82 s to 4.142 s. If that
   carries to 32 layers the pass would already be near **131 s**
   [PREDICTION, 32 × the one-layer rate] without any new hardware — in
   which case effect (1) has largely been collected already and must
   **not** be counted again on top.

The honest statement is therefore: **the 5090 either buys ~1.9× on the
private pass or CL1 already did; the 32-layer re-run is what
distinguishes them, and it costs one detached job.**

### 4.6 Power, and what blocks the install

* **Power.** The contract's bound was 450 W; **Victor's console ruling
  of 2026-09-04 amended it to 600 W** rather than capping the card,
  precisely so a 575 W part is inside it. `TARGET_CONTRACT.md` §4 now
  reads ≤ 600 W "so it names a class of part rather than one product's
  exact TDP", and the runbook's cap-and-record paragraph is superseded.
  A `nvidia-smi -pl 450` run alongside is optional, for comparability
  with the pre-ruling series only.
* **The box is not Blackwell-ready.** Driver **566.14** against ≥ 570;
  NVRTC **12.1** against ≥ 12.8 (`sm_120` codegen lands in CUDA 12.8);
  the `cudarc` feature is `cuda-12040` and needs `cuda-12080`; host RAM
  15 GB against the ≥ 64 GB the 8B CPU arm wants. The code half is
  **done** — lane AJ added the `compute_100` and `compute_120` arms plus
  a loud warning on any generic-PTX fallback.
* **The order is tested and it matters.** Moving NVRTC to 12.8 with the
  driver still at 566.14 produced `CUDA_ERROR_UNSUPPORTED_PTX_VERSION`
  — **and the failure is quiet**: the binary fell back to the CPU and
  still printed `PASS … ACCEPT`, with only a `gpu: off` line as
  evidence. Driver first, then toolkit, then the crate feature; and
  **always grep a run's header for `gpu: ON` before believing a GPU
  number.** The toolkit must not be moved while lanes are running —
  `/home/victor/cuda-root` is shared by every worktree.

## 5. The integrated plan to five seconds

> **CORRECTION FROM THE FIRST LANE THAT TESTED THIS PLAN (orchestrator,
> 2026-09-19 11:18). Step 3 below is worth about 1–2 s, not 7 s, and step 1
> is now in doubt for the same reason.** Lane `fsp-l9` (branch `fsp-l9`,
> pushed; ledger `ZK60_FSP_L9_PROGRESS.md`) started from an all-green floor
> (202 tests, every `gpu-probe` oracle, the twelve byte gates) and measured
> the re-encode path **on a quiet box**: `columns_chunked` at the 8B weight
> shape runs in **0.095–0.098 s**, against the 0.178 s (after lane AO's
> levers) and 0.222 s (before) that this plan's step-3 arithmetic was built
> on. Lane AO took its numbers while another lane was loading the CPU, so its
> table over-states what is left. What the lane then found, all [MEASURED] on
> small shapes with ABBA ordering: removing the shared-memory bank conflicts
> in `k_dit_p1_pad_s` is correct and provably conflict-free but **slower**
> (mean 0.93×; 11 of 12 runs below parity) — withdrawn, left off behind
> `HL_GPU_SMEM_SWZ`; the same treatment of `k_dif_pb` **0.91×** — withdrawn,
> that kernel already sits at 66–77% of the memory roof; **the fusion pays**:
> the producer writes only the 244 of 4,096 residues its pruned consumer
> reads (traffic 7,046 → 1,762 MB), the four kernels go 0.1035 → 0.0898 s,
> **1.162× at 10,752 rows** and 1.06–1.08× at the smaller row counts; the
> host tail's serial 256-vector split is now parallel (byte-identical, not
> measurable under that session's host memory pressure). No digest moved and
> no oracle failed. **Counted worth on the 58.40 s pass: 0.8–1.8 s**
> (13.826 s of re-encode × 92% in these kernels × the measured factor)
> [COUNTED, not measured at 8B]. One change is owed to the integrator:
> pooling the 22 MB output allocation turns
> `hashline/tests/zk60_gpu_commit.rs`'s `expect_alloc(…, 2, …)` red, a file
> that lane did not own.
>
> **What this does to the ladder.** Read step 3 as **−1 to −2 s**, and treat
> step 1's −4 s (lane AO's kernels, never measured at 8B) as **unverified in
> either direction** until the three-arm 8B measurement runs: if AO's A/B was
> taken under the same load, its factors may hold while its absolute seconds
> do not. The laptop's best case after steps 1–4 is therefore nearer **40 s
> than 34 s** [COUNTED], and the conclusion of this page is *strengthened*,
> not changed: **on this card the kernels are close to their memory roof;
> what remains is the host floor (step 4), the weight cache (step 2), the
> bigger card (step 5) and the ruling-sized lever (step 6).** Kernel work on
> the 4070 is no longer where the seconds are.

This is **one ordered plan**, not a menu. Each step assumes the ones
before it. The baseline is the measured **58.40 s**, public IO,
feed-forward only, 32 Mistral layers × 512 tokens, laptop RTX 4070,
cold weight cache.

The steps are ordered on a single principle: **collect what is already
paid for before building anything new, and do not buy hardware until
the host residue is small enough for hardware to matter.**

### The ladder

| # | step | expected gain | running total | acceptance check | who | can it start now? |
|---|---|---|---:|---|---|---|
| **1** | **Measure what is already built.** Lane AO's three re-encode kernel levers and CL7's port of them to the hiding path merged *after* the 58.40 s run and have never touched an 8B pass | **−4 s** [COUNTED from AO's measured 1.484× / 1.292× / 1.156×] | **54.4 s** | **byte identity**: the proof must still be `dc980e81..4536c` at 1,234,936,956 B, and the twelve byte gates must not move. The change is byte-preserving, so identity is the whole check | mechanical — no design work; AO left switches (`HL_GPU_PAD_SKIP=0` etc.) for the A/B | **design and script now; the seconds need a quiet box** |
| **2** | **Warm the weight cache and measure it.** The contract excludes committing the weights from the clock; the built system's closest approximation is `--wcache` warm, which has **never been run at 8B on the current tree** | **−6 s** (range 3–9) [COUNTED, unverified; §2] | **48 s** | byte identity again — the cache never enters the transcript, and byte identity across cold/warm/absent is already proven at 12×512 and at one Mistral layer | mechanical | **yes, one command; needs a quiet box only for the seconds** |
| **3** | **Finish lever L9 on the one kernel that is neither bandwidth- nor compute-bound**, plus its host tail. `k_dit_p1_pad_s` is 56% of the four re-encode kernels at 41% of the memory roof and 11% of the ALU roof; `k_dif_pb` is untouched; `columns_chunked`'s host tail is an unpooled 22 MB allocation and a serial copy into 256 vectors | **−7 s** [COUNTED on AO's own per-kernel table] | **41 s** | the twelve byte gates **and** the `gpu-probe` device-versus-CPU oracles, which compare the re-encoded opening columns against the CPU encoder element for element at three padding depths | mechanical kernel engineering to an existing, measured attribution | **yes — the A/B runs on small shapes, which AO already did on this shared box at 2.5% spread** |
| **4** | **Attack the host floor.** ~11.9 s survives inside the prove and **no card touches it**. The named changes: hand `pcs::commit` the int8 planes directly instead of a converted 64-bit vector (the device half, `k_widen`, is already built and on the live path), give the remaining host folds a device form, pool the opening's 22 MB allocation | **−7 s** (host 11 → ~4 s) [COUNTED from lane AJ's item (a) and AO's item 2] | **34 s** | byte identity; this is the same class of change lane AL made and byte-gated | needs a **design decision**: which crate owns the int8-plane commit entry point. Otherwise mechanical | **yes, code and gates; the number needs a quiet box** |
| **5** | **The RTX 5090.** Driver ≥ 570 first (Windows-side), then toolkit ≥ 12.8, then the `cudarc` feature | **÷2.3–3.4** on what remains [MODEL, §4.3 arithmetic re-run on the post-step-4 split] | **10–15 s** | an A/B is impossible (different machine), so the check is: the proof digest must be **unchanged from the 4070's**, `gpu: ON` in the header, and p95 over ≥ 20 warm runs per `MEASUREMENT_PROTOCOL.md` | **needs Victor** (a purchase already made, plus a Windows-side driver install and a window with no lanes running) | **no — blocked on the driver** |
| **6** | **L4 — halve or quarter the hashed bytes** (encoding rate 1/2 and/or a 31–32-bit field instead of 64-bit Goldilocks). The only recorded lever large enough to close the last gap | **÷2–4** on the hashing and encoding terms [MODEL] | **5–10 s** | **not byte-preserving**: it moves every frozen digest in the repository and changes the soundness accounting. The check is a new frozen-digest set plus a re-derived soundness table | **needs Victor's ruling** and a costed design memo first; deferred by the 2026-09-04 ruling | **no — a ruling, not a lane** |

**Running in parallel, off the critical path for seconds but on it for
the contract:** the proof is 1,234,936,956 bytes against a frozen
1,114,112-byte budget — about 1,100× over. The Merkle cap is a free
−29% [COUNTED, not implemented]; the compact PCS is a 19.9× cut that
costs 4.36× the prover time and awaits ruling **D10** (95–98 bits
against 106). Neither belongs inside the speed ladder, and both belong
in the same conversation with Victor.

### What the ladder does *not* include, and must be applied on top

The ladder above is **feed-forward only and public IO**. The product
needs complete layers and P1 privacy. The recorded divisors:

* attention in the statement: **×2.87** at 8B, T = 512 [COUNTED];
* zero knowledge for inputs and activations: **×2.78 on a device**
  [MEASURED], which lever L8 aims to recover to about **×1.3**
  [COUNTED];
* the range facts the contract still owes: **×1.15–1.20** [MODEL].

Applied to step 5's 10–15 s, with L8 landed, a **complete, private** 8B
layer proof on a 5090 projects to roughly **45–75 s** [MODEL on MODEL —
the weakest number on this page]. The project's own independent
composition puts the same object at **14.9–42.5 tokens/s on one H100**,
i.e. **12–34 s per 512-token prefill proof**
(`U_PERF3_SIXTY_TOKENS_PLAN.md`, §2, corrected divisors). The two agree
to within the bandwidth ratio between a 5090 and an H100 SXM, which is
the most reassuring thing on this page: two independent routes to the
same answer.

### The verdict, honestly

| question | answer | why |
|---|---|---|
| **5 s, public IO, FFN-only, on this 4070 laptop** | **No, and not close.** | Best case after steps 1–4 is ~34 s, and the host residue alone is a hard floor: even an infinitely fast card leaves 11.9 s today and ~4 s after step 4, while the device work is 46 s and cannot be divided by this card |
| **15 s, public IO, FFN-only, on this 4070 laptop** | **No.** ~34 s best case | |
| **5 s, public IO, FFN-only, on a 5090** | **No** without lever L4 (a ruling that moves every frozen digest). **Marginal with it**: 5–10 s [MODEL] | |
| **15 s, public IO, FFN-only, on a 5090** | **Yes, plausibly** — 10–15 s [MODEL] after steps 1–4 | this is the first genuinely reachable contract-shaped claim in the project, and it is four mechanical steps and one driver install away |
| **5 s, P1-private, FFN-only, on any single consumer GPU** | **No** under any assumption recorded in this repository | |
| **5 s, P1-private, complete layers — what the product actually needs** | **No.** The project's own honest band is 12–34 s on an H100, i.e. the **15 s edge** is the realistic target and 5 s is outside every counted assumption | |

### The single largest uncertainty

**Every private second in this document was measured on a privacy
profile that was subsequently found to disclose private values.** The
2026-09-08 correction records demonstrated private-value disclosure in
the legacy hash-line `--zk` / `--p3` feed-forward proofs. The repaired
construction exists only at width 16 (the private block proved on
2026-09-19 at T32, width 16, in 0.095 s). **Nobody knows what the
repaired private feed-forward costs at width 4096** — whether it is the
same shape as the legacy machinery, or twice it, or ten times. Every
private projection above, including the project's own 12–34 s H100 band,
inherits its cost model from machinery that will be replaced.

That is the number to go and get: **the repaired private construction,
at one Mistral-width layer, timed.** It is worth more than any kernel
work on this page, because it is the only thing that tells us whether
the private ladder is the public ladder times three or the public ladder
times thirty.

A distant second: **no contract-grade measurement exists for anything at
8B.** Every headline here is a single run on a shared box with ~2×
documented run-to-run variance. The measurement protocol
(p95 over ≥ 20 warm runs, quiesced) has never been executed at 8B, and
20 warm runs at ~197 s of wall each is only about 66 minutes — it is
affordable, and it has simply never been scheduled.

## 6. The first three pieces of work that can start today on this box

All three respect the tree as it stands on 2026-09-19: Codex is working
live and uncommitted in `hashline/src/lib.rs`,
`hashline/src/tables_attn.rs`, `hashline/Cargo.toml`, `Cargo.lock`, the
`zkvm-block/` tree, `scripts/`, `tests/` and three status documents.
**`hashline/src/gpu/*`, `zk.rs`, `layer.rs`, `pcs.rs` and `wcache.rs`
are all clean.** Each lane below should still run in a sibling worktree
(`../wt-<lane>`), because `Cargo.toml` and `Cargo.lock` are contended.

### Lane 1 — "collect what is already paid for" (measurement only, no source)

**Owns:** new `results/fsp1_*` files and its own status section in
whichever ledger the orchestrator names. **It owns no source file at
all**, which is why it can start immediately.

**What it does.** Runs the 8B public-IO pass that has never been run
since lane AO and CL7 merged, in three arms on one binary in one
session: (a) today's defaults; (b) `HL_GPU_PAD_SKIP=0 HL_GPU_NTT_FAST=0
HL_GPU_PRUNE_P2=0`, which restores the pre-AO kernels exactly; (c)
today's defaults with a **warm** weight cache, which no 8B run has ever
used on this tree. Detached under `flock /tmp/zk-heavy.lock` with a
`.done` marker, `/usr/bin/time -v`, `nvidia-smi` verified near 0 MiB
first, and the run header grepped for `gpu: ON` before any number is
believed.

**The gate that protects existing proof bytes.** Every arm must produce
`dc980e810085b2ddf4688eb4a6cf4dd931c209bf7c5a9a7692d57ec14bc4536c` at
1,234,936,956 bytes, verified by `sha256sum` by hand and not only by the
binary; and the twelve byte gates (four fixtures × CPU / GPU / GPU with
`HL_GPU_CHUNK_BYTES` forced small) must stay green. This lane changes no
code, so a moved digest would mean the tree is broken, not that the lane
is.

**Does it need a quiet box?** For the digests, no. **For the seconds,
yes** — the arms differ by a projected ~4 s on ~55, which is inside this
box's noise when it is shared. The run itself is safe on the 8 GB card
(the public pass peaks at 5,249 MB; it is the *private* pass that
spills).

**Expected answer:** arm (a) ≈ 54 s against arm (b) ≈ 58 s, and arm (c)
≈ 48 s. If arm (a) does not beat arm (b), lane AO's kernels do not
transfer to the 8B shape and step 1 of the plan is worth nothing — which
is itself the most valuable thing this lane could find.

### Lane 2 — the one kernel that is neither bandwidth- nor compute-bound

**Owns:** `hashline/src/gpu/cuda.rs`, `hashline/src/gpu/kernels.cu`,
`hashline/src/gpu/mod.rs`, `hashline/src/ntt.rs`, new `results/fsp2_*`.
**Read-only:** `layer.rs`, `zk.rs`, `pcs.rs`, `wcache.rs`, and
everything Codex has open.

**What it does.** Takes the two items lane AO named and did not take:
the residual shared-memory bank conflicts in `k_dit_p1_pad_s`'s stages
3–4 (a warp lands on 8 distinct 64-bit banks instead of 16), and the
fact that its 537 MB of writes per chunk are read exactly once by the
very next kernel — so the two can be fused. Then `k_dif_pb`, same
family, 27% of the four kernels and untouched. Then the host tail of
`columns_chunked`: an unpooled 22 MB allocation, a 22 MB download, and a
serial loop copying 2.75 million field elements into 256 vectors, all
inside this lane's own file with zero byte risk.

**The gate.** The twelve byte gates on both binaries, plus **every
`gpu-probe` device-versus-CPU oracle** — the blake3 row-count checks,
the transform checks at seven shapes, and the chunked-commit checks,
the last of which compares the re-encoded **opening columns** against
the CPU encoding element for element at inverse rates 2, 4 and 8 (the
three padding depths). That last oracle is the pruned kernel's own
check, and it is why lane AO could make a 4.38× change to a kernel and
be sure of it. Plus `cargo test --release`.

**Does it need a quiet box?** **No.** The A/B is
`HL_GPU_BENCH_REENC=1 hashline gpu-probe` with
`HL_BENCH_ROWS=1024,3584,10752`, best of 7, ABBA over four processes —
lane AO took exactly these numbers on this shared box and reported a
2.5% spread. Only the roll-up onto the 8B pass needs quiet, and that
belongs to lane 1.

**Expected answer:** if `k_dit_p1_pad_s` reaches the 77–78% of the
memory roof its siblings already hold, the four kernels go 0.119 →
~0.085 s, which is ~1.4× on 27.7 s of device transform work on the 8B
pass.

### Lane 3 — give the private prover lane AL's host fix

**Owns:** `hashline/src/zk.rs`, new `results/fsp3_*`. **Read-only:**
`gpu/*` (lane 2's), `layer.rs`, `pcs.rs`, `wcache.rs`.

**Why it is third and not first.** It is the largest known unrealised
factor on the tier the product actually needs, but its acceptance is
harder and its 8B measurement is the dangerous one, so it should start
after the two cheap lanes are moving.

**What it does.** `zk.rs` carries its own copy of the v3 prover body
with its own `w_data` / `a_data` allocations (around `zk.rs:925-966`).
Lane AL deliberately did not touch it, so the private path never
received the two-slot host staging pool or the fold-straight-off-the-
int8-planes change that took the public pass from 98.54 s to 58.40 s.
This lane ports both, behind switches in lane AL's style so the old
arms stay in the binary for the A/B and for rollback.

**The gate.** The two zero-knowledge byte gates —
`021485e4f80ec695..` at 87,228,528 B and `40eb54795e023c77..` at
87,697,008 B — on **both** binaries and in both the resident and the
forced-chunked form; the eight v3 tamper legs at Mistral width through
the GPU zero-knowledge prover (honest ACCEPT, then 8 of 8 REJECT), which
already exist as a runnable battery; and `cargo test --release`. The
change is byte-preserving by the same tiling argument lane AL wrote
down, and if a digest moves it is a bug, not a speedup.

**Does it need a quiet box?** The correctness work, the gates and the
one-layer A/B do not — one Mistral layer in the private profile on the
GPU is a ~4 s run. **The 32-layer private pass does**, and more than
that: the last one spilled to 8,585 MB on an 8,188 MiB card, paged
continuously for six minutes, and this box froze three times on the day
it was run. It must be launched alone, detached, with the card verified
idle, and never chained behind another GPU job.

**A note on ownership before starting.** Codex's CL lanes have been
editing around `zk.rs` (CL18's `HL_ZK_COMPACT_PAD` lives there).
`ZK60_CODEX_FABLE_COORDINATION.md` should be read and the ownership
confirmed before the first commit.

### A cheap fourth, if a fourth agent is free

**The contract clock.** Nobody has ever measured what the contract
actually specifies. A read-only lane owning only `results/fsp4_*` could
run the existing `chain --profile v3` subcommand at 32 × 512 to get the
Rust re-execution time of the quantized forward pass, and publish the
honest contract-clock number — inference plus prove plus serialize —
next to the 58.40 s prove clock. No source change, no byte risk, one
command. It would end the ambiguity about whether this project is at
58 s or at 195 s per proof.

## 7. What I did not read, and what I could not find

### Read in full

`START_HERE.md` (§§1–7), `TARGET_CONTRACT.md`, `MEASUREMENT_PROTOCOL.md`,
`MVP_STATUS.md`; `PROGRESS_UPERF3.md` rounds 12–16 in full (lanes AC,
AH, AI, AJ, AK, AL, AM, AN, AO) plus its ZK60 round sections;
`TASK_BOARD.md`'s handoff blocks from 2026-09-04 onwards;
`results/hashline_convert_gpu.md` §7. Through delegated readers:
`BLACKWELL_5090_RUNBOOK.md`, `ZK60_CLAUDE_5090.md`,
`ZK60_CLAUDE_GPU.md`, `ZK60_CLAUDE_RESIDENCY.md`, `ZK60_CLAUDE_CACHE.md`,
`ZK60_CLAUDE_CHUNK.md`, `ZK60_CLAUDE_PROFILE.md`, `ZK60_PROFILE_SWEEP.md`,
`ZK60_PENDING_FFN.md`, `U_PERF3_THROUGHPUT_MODEL.md`,
`U_PERF3_ROUTE_B_THROUGHPUT.md`, `U_PERF3_SIXTY_TOKENS_PLAN.md`,
`U_PERF3_HEADLINE_ROUTES.md`, `U_PERF3_OPENING_LAYER_DESIGN.md`,
`U_PERF3_S4_REDESIGN.md`, `PROVING_CHANNEL_OPTIONS.md`,
`U_PERF3_MVP8B_SCALING.md`, `ZK60_DECISIONS.md` (D10),
`results/hashline_8b_gpu.md`, `results/hashline_zk_8b_gpu.md`,
`results/hashline_hostwall_gpu.md`, `results/ao_l9_reencode.md`, and the
8B logs (`hashline_convert_r3.log`, `hashline_zk_8b_pass_gpu.log`,
`am_r3_8b*.log`, `hashline_zk_8b_wcache_e4.log`,
`hashline_mistral_32x512.log`).

### Not read

* **The prover source**, except `hashline/src/bin/hashline.rs`'s pass
  timer (to establish what "witness load + chain" actually measures) and
  a grep confirming the optimisation switches are present in
  `layer.rs` and `gpu/`. I did **not** read `pcs.rs`, `zk.rs`,
  `layer.rs`, `wcache.rs` or the CUDA sources. Every attribution in §3
  and §4 is the lanes' own, not mine.
* `PROGRESS_UPERF2.md` (rounds 1–9) and `PROGRESS_UPERF.md` (phase 0).
* `PROGRESS_UPERF3.md` rounds 1–11 in detail.
* The ZK60 round documents 5–25, the Fable and Opus review documents,
  and the private-attention / private-block construction documents,
  except as they are quoted in `MVP_STATUS.md`. The private-block work
  of 2026-09-19 is therefore represented here only by its headline
  numbers.
* `OPTIMIZATION_ROADMAP.md` and `PROVER_OPTIMIZATIONS.md` were read by a
  delegate and found to be about a different, earlier prover track
  (pairing-based zkMatrix); they contain nothing relevant to this page.

### Could not find — each of these is a real gap, not a search failure

1. **Any warm-weight-cache measurement at 8B on the current tree.** The
   only warm figures are from lane AC's tree (2026-09-03), before lanes
   AL and AO.
2. **Any 32-layer 8B pass with private weights (P3) on a GPU.** None
   exists in any log. The only P3 8B run is on the CPU.
3. **Any 8B pass, on any line, that includes attention.**
4. **Any measurement at all after the CL1 / CL7 / CL18 lanes at
   32 layers**, public or private. Every 8B number in this document
   predates them.
5. **Any p95-over-20-warm-runs measurement of anything at 8B.** No
   contract-grade row exists.
6. **Any measured witness-inference time at 8B.** The activations are
   produced offline in Python and read from disk.
7. **Any RTX 5090 measurement.** The card is not installed; the box is
   not Blackwell-ready.
8. **The phrase "buys about 1.4× until the host wall lands" verbatim.**
   It does not appear in the repository. Its source is
   `BLACKWELL_5090_RUNBOOK.md` §2, headed "THE AMDAHL WARNING — the
   board buys ~1.4×, not 7×, today", plus "the `layer.rs` item is what
   decides whether the 5090 buys 1.4× or 4×". §4.4 above works out what
   it means now that the host wall has landed.

### Discrepancies I noticed and could not resolve

* `U_PERF3_SIXTY_TOKENS_PLAN.md` §1 describes the fast tier's weight
  commitment as "the ~37 s `commit W`", while
  `U_PERF3_ROUTE_B_THROUGHPUT.md` §2.2–2.3 models the per-model commit
  at **218 s** at 8B. The documents do not reconcile these, and the
  measured figure has since moved again (19.823 s on the GPU after lane
  AL). Anyone using either number should re-derive it.
* Lane AC's `[MODEL]` "direct column evaluation is ~1–4 s per layer
  against ~5 s for the transform" is, by my own arithmetic (§2), a
  CPU-path statement: on the device the transform is ~0.36 s per layer
  and direct evaluation of 256 columns is several times more work. I
  have flagged it rather than corrected it, because `pcs.rs` is a file
  I did not read.
* `MVP_STATUS.md` §2 and `START_HERE.md` §3.1 both still carry the 95 s
  8B row and the "19× slower than 5 s" distance. §1.3 above gives the
  replacement figures. Both files were being edited by another agent
  while this page was written, so they may already have moved.

---

*(draft complete)*
