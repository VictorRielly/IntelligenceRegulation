# GPU port plan for the production classifier (Phase B)

Written 2026-10-30 21:30–22:05 UTC by the GPU classifier lane (D53: nothing is published until proving and
verification run on the GPU). Inputs:
- this lane's measured CPU profile (`PHASE_PROFILE.md`);
- its first GPU-assisted real prove and the re-measured slot-18 kernel (§3; ledger `PROGRESS.md`);
- the paused zero-check lane (`results/zk60_gpu_zerocheck_20261017/`);
- the speed plan (`docs/zkmatrix-poc/ZK60_SPEED_PLAN_20261017.md`);
- the DeepProve gap study.

Labels: [MEASURED] = shared laptop, n = 1; [COUNTED]; [MODEL]. Every gain below is a [MODEL] unless marked
otherwise. GPU timings since 21:50 UTC are under Victor's new laptop setting (MSI Extreme Performance, mains):
P0, SM about 2.1–2.4 GHz, memory 8,000 MHz, 80 W power cap (reason 0x4), no thermal flag.

## Plain words for Victor (≤ 200 words)

- **Measured today on the laptop.** With the GPU build of the program, the classifier proof's commitments
  already run on the graphics card. The receipt is byte for byte the CPU's (all 30 files), and the production
  CPU verifier accepts it. One category takes 347 s instead of 476 s (1.37×). Everything else, verification included,
  still runs on the processor.
- **The biggest pieces left:**
  - the forward-pass witness, which is computed twice (36% of the time);
  - the five zero-checks (24%);
  - reading the model, three or four times (16%).
- **Your new power setting doubled the laptop GPU's speed.** The GPU zero-check kernel now uses 35% of the
  card's memory bandwidth (19% before).
- **Estimate after the remaining port** (about 25–40 agent-days):
  - one category: about 50–60 s on the laptop, roughly 8× faster than today's CPU proof;
  - verification: from 67 s to about 8 s;
  - the RTX 5090 should then cut the GPU parts another 5–10×.
- **What we need from you:**
  1. install Linux on the 5090 desktop (`ZK60_5090_LINUX_BRINGUP.md`) and tell us its CPU and RAM;
  2. keep the laptop on mains in Extreme Performance for GPU timings (no thermal throttling seen yet).

## 1. The rule every item follows: byte-identical to the CPU path

- **The CPU prover stays the reference.** A GPU kernel computes the same field elements. Field arithmetic is
  exact, so the polynomial, the tables, the points and the round order must match; the order of operations
  need not. The transcript, CFS masking, every challenge and all randomness stay on the host.
- **Gates, in this order, for every item:**
  1. a unit equality of the device result with the CPU result, on dense random and honest-witness data, at
     the rung and at Shieldstral T128;
  2. the rung single prove under fixed entropy, CPU path against GPU path, every file equal (`tools/rung.sh`);
  3. **the real-scale job-0 prove under r18's fixed public entropy, all 30 files equal to the recorded
     digests** (`tools/phase_a.sh`);
  4. a fresh verify of the GPU-made receipt by the frozen production CPU binary;
  5. `HL_GPU_REQUIRED=1` with 0 declines, and peak VRAM and clocks recorded.

  Fixed-entropy receipts hide nothing: they are test only and are deleted after the record.
- **Gates 2–5 passed today for the commitments path** (§3).
- Because the receipts are byte-identical, the reviewed privacy statements carry over by evidence; only the
  named binaries change (D53, coordinator's reading).

## 2. The phases, ranked by measured share once the commitments are on the GPU (346.6 s per category)

Shares are of the GPU-arm prove (`profile_prove_gpu.json`; CPU-only shares in brackets, 476.1 s). The witness
pass inside `seal_chain` is the seal pass minus its block loads, taken equal to the run's loads [MODEL].

### Item 1: the witness, built twice

**Measured:** 125 s, 36% [143.6 s, 30%]. That is 62 s inside the blocks and about 63 s again in `seal_chain`.

**GPU design:** exact integer kernels.
- int8 × int8 → int32 GEMMs (exact on IMMA / dp4a).
- Then the requantisation, RMS-norm, RoPE, the exact integer softmax (table lookups and integer division), the
  activation tables and the limb decompositions.
- The A planes are written **on the device**, where they feed the commitment and the zero-check tables. This
  also removes the 31 GB per prove of row uploads measured in §3.
- A host copy comes back for the CS-3 and parity checks.

**Expected gain:** 14.9 G int8 MACs per block [COUNTED: 3.03 G per token ÷ 26 layers × 128 positions] plus
0.6 GB of A planes. That is tens of ms per block: **125 s → about 3–6 s** [MODEL].

**VRAM:** about 1.5 GB per block (243 MB weights, 0.6 GB planes, scratch). On the 5090 the whole 6.3 GB padded
model stays resident.

**Effort and risk:** 5–8 lane-days. Medium risk: the exactness of rounding and division. The per-layer parity
check against the export is already mandatory and is the oracle.

**Owner:** Sol owns `witness.rs`; the GPU lane writes the kernels behind a witness-builder seam.

### Item 2: the five element-wise zero-checks

**Measured:** 83.5 s, 24% [97.0 s]. On the CPU: bodies 82.8 s, table builds 6.7 s, extension rounds 6.3 s.

**GPU design:**
- Device `SumcheckRounds` evaluators under the unchanged `zk::masked_prove_rounds`, using the slot-18 template:
  split kernel, tables built on the device from resident A/H rows, fused reduction, mapped-flag result, host
  tail.
- A batched `mask_eval` kernel for the extension rounds.
- **The classifier is on the R13 accuracy stack.** Its slots 14–19 are redefined in `argument_accuracy.rs`, so
  the legacy slot-18 kernel does not apply as is.
- Write the five R13 polynomials once as data, by extending the test-only slot expression IR (`slot_ir.rs`) to
  the R13 definitions. Generate each kernel's polynomial body from it (NVRTC source), so that the IR == closure
  oracle guards every Sol round. The structure that makes this possible is described after this list of items.

**Expected gain:** the slot-18 body re-measured today runs at 14.4 ms per 2^20 cube with 21 tables
[MEASURED]. That is 0.65 ns per table entry or 0.81 ns per element-term, and 36× the 16-thread CPU body.
Scaled to this profile's 127 M table entries (or 254 M element-terms) per block: **0.08–0.21 s per block
against 3.2 s on the GPU arm, so about 84 s → 3–6 s** [MODEL].

**VRAM:** the largest slot (18) holds 60.8 M Fp2 = 0.97 GB of tables. With the resident A/H rows that is
about 2.5 GB; trivial on the 5090.

**Effort and risk:** 8–12 lane-days: 3–5 for the IR extension, then about one round per slot on the template.
Medium risk. The kernel efficiency is now 35% of 256 GB/s on slot 18; descriptor drift is handled by the IR.

**Owner:** the IR and the dispatch lines are in Sol's files; the kernels and gates are the GPU lane's.

### Item 3: the model passes

**Measured:** 55.5 s, 16% [66.9 s]. The digest pass is 25–31 s; then every block is loaded three more times
(seal_chain, sealing pass, run).

**Design:** **not a GPU item.**
- Load each block once per process.
- Keep the digest pass's `LayerRecord`s and compare on reload instead of re-hashing.
- Hash the layers in parallel. The speed plan's L1 did this for the trained-block CLI: digest pass 83 → 15 s,
  loads 79 → 16 s.
- A resident-model prover (all categories and posts in one process) removes the passes altogether.

**Expected gain:** 55 s → about 15 s [MODEL]; about 0 s with a resident model.

**Effort and risk:** 2–3 lane-days; low risk.

**Owner:** the token lane (classify CLI), with Sol (loaders).

### Item 4: LogUp inverses, A-row conversion, lookup values, histograms, mask rows

**Measured:** 27.3 s, 8% [27.9 s].

**GPU design:**
- Device kernels on the resident A data.
- Helper inverses follow the legacy `dev_helpers` pattern: batch inversion, with U8 inverses through the
  256-entry table.
- Histograms by atomics.
- The conversion disappears once item 1 writes the A rows on the device.

**Expected gain:** 27 s → about 1 s [MODEL].

**Effort and risk:** 3–5 lane-days; low to medium risk.

**Owner:** the dispatch is in Sol's `protocol.rs`; the kernels are the GPU lane's.

### Item 5: openings

**Measured:** 16.4 s, 4.7% [14.2 s]. This is **slower on the GPU arm for A** (0.50 s per block against 0.25 s
on the CPU).

**Cause:** `fold_rows_multi_zk` hands the device at most 4 weight vectors per call, and `k_fold_rows` re-reads
the whole A matrix on every call. A has about 35 opening groups. The device row folds take 9.96 s per prove
[MEASURED, GPU stats].

**GPU design:**
- One pass that folds all of an opening's weight vectors together: a row-tiled 2-D grid with shared-memory
  partial sums.
- No re-encode on the 5090.

**Expected gain:** 16 s → about 1–2 s [MODEL].

**Effort and risk:** 2 lane-days; low risk.

**Owner:** the GPU lane (`gpu/cuda.rs`); the chunking line is in `zkp-core` (Sol).

### Item 6: the commitments

**Measured:** 15.5 s, 4.5% [104.3 s, 21.9%].

**GPU design:** this **already exists** and is measured (§3): 6.9× the CPU. Next comes L5:
- fused LDE and hash;
- a device Merkle top;
- rows produced on the device by item 1, so the 5.2 s upload disappears;
- a warm GPU, since the first commitment after a CPU-only phase pays a clock ramp: A at 5.2 ns per word, H at
  2.4;
- encodings resident on the 5090.

**Expected gain:** 15.5 s → about 5 s [MODEL].

**VRAM:** chunked, the measured peak is 1,569 MiB. Resident encodings are 4.7 GB per block (146.9 M words ×
rate 4 × 8 B [COUNTED]).

**Effort and risk:** 0 lane-days for what exists, plus 5–10 for L5. Low risk: the proof-byte gates exist.

**Owner:** the GPU lane.

### Item 7: stage IN-C and the small remainders

**Measured:** stage IN-C, the vocabulary LogUp over V = 262,144 with the embedding fold, takes 3.1 s. CUDA
initialisation and NVRTC compilation take about 2.7 s per process. Small slots, frames and stages take about
17 s.

**GPU design:** the embedding fold is a GEMV over the 1.6 GB int16 table. The kernel compile can come from
the disk module cache, which already exists for slot 18. Small slots move with item 2.

**Expected gain:** 23 s → about 10–15 s [MODEL].

**VRAM:** 1.6 GB for the embedding table.

**Effort and risk:** 2 lane-days; low risk.

**Owner:** the token lane (stage IN-C) and the GPU lane.

### Why one generator covers the five R13 zero-checks

Read from `argument_accuracy.rs`, frozen-r19b. Every slot has the same skeleton:

`P = E0 · (Σ_k μ_k LogUp-helper_k + pad + S · Σ_i μ_i clause_i) + Σ_j ν_j E_j · S · host_j`

- Each LogUp helper is `H (α − a)(α − b) − (α − a) − (α − b)` over byte limbs.
- Each clause is a product of at most three linear forms. The inputs are A planes, limb sums
  (`Σ 2^(8i) limb_i`), public columns (`γ_a`, `γ_m`, the activation group column) and constants.
- Each host term is one such linear form.
- Slot 14 has 13 clauses and slot 18 four, plus their helpers.

The legacy slot-18 split kernel already implements the helpers, the pad term, the gates and stepped linear
forms (`results/zk60_gpu_zerocheck_20261017/NEXT.md` §3). The R13 generator adds general clause lists.

A descriptor emitted from the IR lists the tables in push order, the linear forms, the clauses, the helper
pairs, the gates and the hosts. It is checked against the closure at random points before the first launch.
That makes it both the kernel's source and its fail-closed guard.

### GPU verification (D53 asks for it)

**Measured:** the fresh verify takes 66.8 s on the CPU; the GPU-made receipt took 65.2 s in the frozen binary.
- **49 s of that is reading and hashing the public model three times.**
- About 10 s is cryptography.

**GPU design for the 10 s:**
- the public weight folds of the matmul slots (2.5 s): a GEMV of int8 weights against eq tables,
  bandwidth-bound, with the weights resident on the 5090;
- the public-table evaluations at the claim points (2.9 s): slot 18's R13 activation-group column and supports
  over 2^21 entries, the causal mask, RoPE;
- the PCS checks (2.9 s): column re-encodes and BLAKE3 Merkle paths.

**Identity method:** the verifier's decisions are field equalities. A shadow mode compares every device value
with the CPU's on the same receipt, and every negative control in the reviewed refusal set must refuse on both.

**Expected gain** [MODEL]:
- the cryptography: 10 s → about 1 s on the GPU;
- **without item 3 the verify stays about 55 s**;
- with item 3 (one model pass, parallel hashing or a pinned digest cache): about 15 s;
- then about 6–8 s with the GPU.

**Effort:** 3–5 lane-days for the GPU part (the GPU lane, with the verifier dispatch lines in Sol's files),
plus 2 lane-days for the verifier's run hygiene (the token lane).

## 3. Measured today on the laptop RTX 4070

### Rung and real-scale byte identity of the existing GPU path (commitments and openings)

**The rung** (`logs/rung/`):
- the development-rung single prove, CPU path against GPU path, under fixed entropy: all 5 files equal;
- 0 declines;
- 385 MiB of VRAM.

**The real scale** (`logs/pa/`): the Shieldstral T128 moderate-sexual job 0, 26 blocks, with r18's fixed public
entropy.

| | CPU path (gcl1-cpu) | GPU path (gcl1-gpu, `HL_GPU=1 HL_GPU_REQUIRED=1 HL_ZK_CHUNK=force`) |
|---|---:|---:|
| 30 files equal to round 18's recorded digests | **yes** | **yes** |
| guard child wall | 476.1 s | **346.6 s (1.37×)** |
| the run (sealing pass, IN-C, 26 blocks, OUT-C) | 351.6 s | 238.3 s |
| block walls | 337.5 s | 225.4 s |
| commitments A + H + M + B_k | 104.3 s | **15.5 s (6.7×; A + H + M 6.9×)** |
| per block: A commit / H commit | 2.00 / 1.97 s | 0.393 / 0.174 s (5.24 / 2.42 ns per word) |
| openings | 14.2 s | 16.4 s (device row folds 9.96 s) |
| peak host RSS | 8.15 GiB | 4.03 GiB |
| peak VRAM | — | **1,569 MiB** |
| declines | — | 0 (84 chunked device commitments) |
| fresh verify of the receipt | lane CPU binary: exit 0, 66.8 s | **frozen production binary 6d65d32e…: exit 0, 65.2 s** |

The other phases ran about 1.1× faster in the GPU run, because Sol's light job was gone and fewer CPU threads
were busy. This is shared-box noise and not a GPU effect.

**Device statistics:** host-to-device transfers 31.2 GB in 5.17 s; encode + hash 8.13 s; chunked re-encode for
the openings 3.21 s.

**Clocks:**
- 158 of 1,089 samples were busy; the GPU idles between commitments.
- Busy samples: P0 90, P3–P5 64.
- SM median 2,130 MHz; memory 8,000 MHz in 97 of 158.
- Throttle reasons 0x4 / 0x0 / 0x1. **No 0x20 or 0x40.** Maximum 47 °C.

No bandwidth fraction is quoted for the commitments: the memory clock was not steady at 8,000 MHz through
them.

### The slot-18 kernel and the commitment path under the new clocks

The slot-18 runs use the paused lane's round-4 test binary, run read-only (`logs/gzc/`).

| | round 4, capped (P4, SM 1,065, memory 6,000, reason 0x20) | today (P0, SM about 2,355, memory 8,000, reason 0x4) |
|---|---:|---:|
| ladder, kernels only, 2^19 / 2^20 / 2^21 | 11.3 / 20.7 / 39.2 ms | **5.3 / 9.8 / 18.7 ms** |
| real slot 18 at TinyLlama T128 (2^20, 21 tables), body including the device table build, default split | 26.5–27.9 ms | **14.4–14.6 ms** |
| the same, split-mat | 25.9–27.1 ms | 14.9–15.8 ms |
| on the plan figure (72 B × 2^20 × 17 = 1.2835 GB) | 46–50 GB/s = 18–19% of 256 | **89 GB/s = 34.8% of 256 GB/s** |
| device == CPU equalities (dense + honest, claim none / given) | held | **held** |

- The real-slot run: memory at 8,000 MHz in 29 of 33 busy samples, P0 28, reason 0x4, maximum 51 °C.
- The ladder: memory at 8,000 MHz in 91 of 95 busy samples.
- **The slot-18 kernel is now inside the speed plan's ≥ 25% band**, the rule's "proceed on the roofline track".
  The commitments' in-stack rate: H at 2.42 ns per word with a warm GPU, A at 5.24 with a cold one.

## 4. How the GPU code lives

- **One backend module, selected at run time.**
  - All device code stays in `hashline/src/gpu/` behind the `gpu-cuda` feature.
  - `HL_GPU=1` turns it on, and `HL_GPU_REQUIRED=1` makes every decline fatal (`gpu::declined`).
  - A CPU build has none of it.
  - Each phase plugs in through a narrow seam whose CPU implementation is the reference:
    - `zkp_core::pcs::Backend` / `EncodedStore`: commitments and openings (exists);
    - `zkp_core::sumcheck::SumcheckRounds`: the zero-check bodies (the trait was written for a device
      evaluator, and the slot-18 lane used it);
    - a witness-builder seam returning the same `Witness` (new);
    - a verifier seam for weight folds and public-table evaluations (new).
  - Every device entry has a shadow mode (`HL_GZC_CHECK=1`-style) that runs both and asserts equality.
- **Descriptors come from the slot definitions, not from hand copies.**
  - Sol's rounds change the polynomials: R13 changed five, and R14's split width changes the layout again.
  - With the IR as the single source, a new round changes the polynomial in one place, and the IR == closure
    test fails loudly on drift.
  - An unknown layout is a decline (fail closed), never a wrong polynomial.
  - So the GPU code carries across Sol's prover rounds.
- **Ownership.**
  - **Sol (native owner):** `private_block/{argument.rs, argument_accuracy.rs, protocol.rs, witness.rs,
    slot_ir.rs}` and `zkp-core`. The one-line dispatch hooks, the IR extension to R13, the witness seam and the
    openings' chunking line need Sol's authorship or review, as `device_fzc` did in the zero-check lane.
  - **Token lane:** `private_block/token_io/*`: the classify CLI and run, stage IN-C, the run-hygiene changes,
    building and pinning the GPU release binary, and the app's switch.
  - **GPU lane:** `hashline/src/gpu/*`, the kernels, the device descriptors, the gates and the measurements.
  - The privacy statements need no change while the bytes are identical; the security owner re-reads only the
    named binaries and the decline rule.
- **Release.**
  - The production classifier binary is built today without `gpu-cuda`.
  - The first deliverable is a reviewed GPU build of the same tree (step 0), pinned like the CPU one.
  - The app passes `HL_GPU=1 HL_GPU_REQUIRED=1` and refuses any run that declined.
  - **The classify statement has no backend field, so the GPU receipt is indistinguishable from the CPU's.** If
    D53's "GPU version" must be visible to a verifier, recording the backend is a statement-schema change for
    the token lane and the security owner. It would break byte identity of `statement.json` only.

## 5. Order and timeline [MODEL]

Counted in lane-days; one lane-day is about one agent round.

| step | what lands | owner | days | laptop, one category (GPU arm today 346.6 s; CPU 476.1 s) |
|---|---|---|---|---|
| 0 | GPU release build of today's tree (commitments + openings), reviewed and pinned | token lane + GPU lane | 1 | 476 → 347 s [MEASURED] |
| 1 | run hygiene: one model pass; the verifier loads each block once | token lane, Sol | 2–3 | −40 s |
| 2 | witness on the GPU (both passes); rows produced on the device | Sol + GPU lane | 5–8 | −120 s |
| 3 | the five R13 zero-checks and their extension rounds on the GPU (IR-generated) | Sol (IR) + GPU lane | 8–12 | −78 to −81 s |
| 4 | one-pass opening folds; inverses, conversion, histograms; stage IN-C | GPU lane (+ Sol's dispatch) | 4–6 | −40 to −43 s |
| 5 | GPU verification (folds, public tables, PCS) + verifier hygiene | GPU lane + token lane | 4–6 | verify 67 → about 8 s |
| 6 | commit kernel to roofline (L5) | GPU lane | 5–10 | −10 s |

**End state on the laptop** [MODEL]: about 50–60 s per category, against 476 s on the CPU today (8–9×). That
is model passes about 15, witness about 5, zero-checks about 5, commitments about 5, openings and inverses about
3, and host remainder about 20. A post's three categories in one resident-model process: about 2–2.5 min.

**Calendar:** about 25–40 lane-days with three lanes in parallel. Steps 1 and 2 are independent; step 3 needs
Sol's IR work.

**What this does not settle:** the 8B / 50 positions/s target needs the speed plan's larger levers. This plan
ports today's classifier.

## 6. What the 5090 changes, and what to measure first

- **Memory stops being the constraint.** 32 GB holds all of these together:
  - the whole padded model (6.3 GB);
  - a block's resident encodings (4.7 GB);
  - every zero-check table (≤ 1 GB at a time).

  That allows a GPU-resident prover with no per-block weight upload and no chunked re-encode. On Linux there is
  no WSL VRAM freeze, so the laptop's 4 GiB lane rule does not apply; still record `peak_vram_mib`.
- **Bandwidth and compute.**
  - 1,792 GB/s, 7× the laptop's 256.
  - 170 SMs, 4.7× the laptop's 36.
  - The device phases should scale 5–10×.
  - The host remainder (transcript, Merkle top, claims, the model passes until step 1 lands) depends on that
    box's CPU, which is still unknown, so measure it.
  - A continuously busy GPU also avoids the clock ramp seen here (A's commit at 2× H's cost).
- **First runs on the 5090, in order, one guarded job each:**
  1. This lane's `tools/rung.sh` and `tools/phase_a.sh`, unchanged except for the CUDA paths
     (`/usr/lib/wsl/lib` → the box's driver; `nvidia-smi` on PATH; `tools/gpu_sampler.sh` `S=`). Record the
     real-scale GPU prove's 30-file digest equality, its phase table and its clocks.
  2. The zero-check lane's `NEXT.md` §1 list: the gates, the ladder, and the real slot against 1,792 GB/s.
  3. With persistence mode and locked clocks, if Victor allows (root; `nvidia-smi -pm 1`, `-lgc`), the same two
     runs again, recording the clock state and throttle reasons with every timing.
