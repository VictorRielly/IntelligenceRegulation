# VC readiness: what we can truthfully show at Tech Week SF

Written 2026-09-29 17:30 PDT (2026-09-30 00:30 UTC) by the Lane D agent
(Claude). Soft deadline: about 2026-10-06. It covers the facts in
`docs/zkmatrix-poc/` (START_HERE, MVP_STATUS, ZK60_THROUGHPUT_TARGET,
ZK60_HARDWARE_SETUP, ZK60_DECISIONS, ZK60_1B_CHECKPOINT) and the retained
evidence under `results/`. Nothing here is a new proof, benchmark or ruling.

Labels, as in START_HERE: **[MEASURED]** means a run happened on a named
machine. **[COUNTED]** means arithmetic on measured pieces or on
layout-constructor counts. **[MODEL]** means a projection with stated
assumptions. **[EXTERNAL]** means someone else's claim. Every timing is from
the shared WSL laptop (Core Ultra 9 185H, 15 GiB, RTX 4070 Laptop 8,188 MiB,
driver 566.14) unless another machine is named. None of it is a quiesced
benchmark: each figure comes from one or two samples.

Companion files in this directory:
- `DEMO_SCRIPT.md` is the one-page stage script.
- `extrapolate.py` produces `extrapolation.json`, the projection arithmetic
  behind section 2. It reads only retained logs and layout counts, and it
  checks their SHA-256 against the A/B report.
- `rehearse.py` produces `rehearsal-<UTC>.json`, a CPU-only demo rehearsal
  of about one second. The latest is `rehearsal-20260930T002413Z.json`: all
  five steps behaved as expected, covering both retained Groth16 receipts,
  the tamper refusal, and the toy native prove and fresh-process verify. The
  first run, `…001813Z`, had four steps and no token check.

**Stage path.** The integrator built a local browser demo in parallel today:
`scripts/zk60_techweek_server.py`, documented in
`docs/zkmatrix-poc/ZK60_TECHWEEK_DEMO.md`. It pins its verifiers and passes
32 HTTP checks. Use it as the primary stage vehicle for demos 1-3.
`DEMO_SCRIPT.md` adds the scale story (demos 4-5 and the numbers slide) and
keeps the command-line steps as a fallback. That document assumes a first
meeting on **Monday 10-05** with rehearsal on Sunday 10-04. The plan in
section 4 follows those dates.

---

## 0. The pitch position, in one paragraph

We have built a zero-knowledge prover for transformer inference. The prompt,
the answer and every intermediate activation stay hidden. Anyone can check,
against a public model, that the computation was done right. It already proves
and independently verifies a **complete private transformer block**
(attention, both norms, both residuals, the SiLU feed-forward) at the
**block geometry of a 125M-parameter model**. On a laptop RTX 4070 that takes
**about 17 s of proving per block**, and verification takes 0.8 s
(synthetic weights).
It also chains **12 such blocks under one transcript** over 512 hidden
tokens: 397.71 s on the laptop CPU, which is **1.29 proved tokens/s** for that
synthetic 125M-geometry stack. At toy scale the same kind of block has an
internally accepted privacy argument. A zkVM version produces a **785-byte
receipt that verifies in milliseconds**. **We have not yet proved a trained
model with private inputs.** The 1.1B TinyLlama checkpoint is pinned and
inventoried, and Llama-3-8B is identified; integer calibration is the next
step. Projecting from the measured per-block costs, today's code would give
**about 0.3 proved tokens/s for an 8B-geometry stack on the laptop** (if it
fit in memory) and **about 0.6-1.2 on an RTX 5090**. Moving the remaining
CPU proof work and witness generation onto the GPU projects to **about 5-13
tokens/s at 8B and 10-26 at 1B on a 5090**. Our goal is **50 proved tokens/s
for a private 8B model**. The gap is 4-10x after an engineering port we can
name and measure, so it is not solved. Every projection above is [MODEL],
and section 2 names the measurement that would confirm each one.

---

## 1. What can truthfully be demonstrated by ~2026-10-06

### 1a. Ready now (re-checked today where marked)

| # | Demo | What it shows | Numbers | Scope | Privacy status | Live on stage? |
|---|---|---|---|---|---|---|
| 1 | **zkVM Groth16 receipt of a complete tiny private block** (`results/zk60_loop_20260918/block-integration/groth16_public/`) | A whole transformer block (norms, QKV, RoPE, causal integer softmax, PV, O, residuals, SiLU FFN). The prompt and answer appear only as salted SHA-256 fingerprints. The receipt is tiny and verifies in milliseconds | 785 B receipt; verify 0.008 s recorded; **re-verified today: exit 0, 0.08 s including the wrapper, and a one-bit-flipped copy is refused** [MEASURED 2026-09-29]. Prove 3,743 s + Groth16 wrap 197 s on CPU [MEASURED 2026-09-18] | T32 tokens, width 16, synthetic fixture, CPU, RISC Zero zkVM (the privacy demonstrator, never the product prover, D2) | "Private under D3/D4/D5/D7" with its qualifiers: about 97-bit conjectured soundness, Groth16 trusted setup, locally built unreproduced image ID, salt secrecy, timing declared as leakage | **Yes (verify only)**. Proving takes over an hour |
| 2 | **zkVM two-block token model** (`results/zk60_loop_20260918/token-integration/token_public/`) | The first proof of actual token generation: embedding, two blocks, head, greedy next token | 785 B; prove 7,488 s + wrap 197 s [MEASURED 2026-09-18]; **re-verified today, exit 0, 0.08 s** with `zkvm-block/target/release/zk60-token-wrap` and image `3c0631ee…430b` [MEASURED 2026-09-29] | Synthetic T32 / 32-word vocabulary, untrained, not a chatbot | As in item 1 | **Yes (verify only).** This is the browser demo's first option |
| 3 | **Our own prover (custom "hashline" line): toy private block** (`hashline/target/release/examples/zk60_private_block`) | The same block kind, one native proof, verified in a fresh process from bytes only; three corrupted copies refused | **Today: prove 0.10-0.11 s, fresh-process verify 0.05-0.06 s, receipt 2,816,472 B, 3/3 corruptions refused, two rehearsals** [MEASURED 2026-09-29] | T32, width 16, synthetic public weights, CPU | **The one privacy acceptance on the custom line (D22):** about 2^-77.7 per proof, in the random-oracle model, CPU path only, accepted by the internal security owner (not a third-party audit). Its binary was built 2026-09-20 14:11; confirm the source pins before quoting D22 on stage (plan P0-2) | **Yes** (under 1 s) |
| 4 | **125M-geometry private block on the laptop GPU** (`results/zk60_sol_gpu_20260927/attempt-5-dense-ab/`) | A real model-sized block: T512, width 768, FFN 2048, 12 query / 4 KV heads, hidden input/output/activations. Commitments run on the GPU | Prove **17.13 s GPU arm vs 32.95 s CPU arm** (two CPU threads each); whole process 30.06 / 39.90 s; verify 0.8 s; receipt 40,783,352 B; host RSS 4.3 vs 10.3 GiB. Softmax zero-check is about 47% of GPU-arm proving [MEASURED 2026-09-27, 2 non-warm samples per arm, shared box] | **Synthetic dense public weights**, one block of twelve, laptop GPU | Hidden by construction; **not privacy-accepted at this shape** | **Possible** (about 30 s, one GPU job). Pre-record it as the fallback |
| 5 | **Twelve 125M-geometry blocks, one transcript** (MVP_STATUS; lane `zk60-private-block-125m`) | A complete stack of blocks, not isolated block proofs. Block boundaries stay hidden | Prove **397.71 s**, streaming verify 14.45 s, receipt 484,107,456 B, peak 10.15 GiB → **1.29 proved tokens/s over 512 tokens** [MEASURED 2026-09-20, one run, CPU]. It predates the latest speedups | Synthetic weights, blocks only (D13), CPU | Not accepted | No (6.6 min). Show the record. A GPU retry was attempted today (`results/zk60_mvp_20260929/baseline-stack-gpu/`) and failed at setup: the harness's receipt directory was missing. This was not a proof failure |
| 6 | **Historical 8B-scale proof: Mistral-7B feed-forward, all 32 layers × 512 tokens** (`results/hashline_convert_r3.log`) | The prover handles 8B-scale widths with trained, calibrated weights | Prove 58.40 s on the laptop GPU, verify 1.08 s, 1.23 GB, **8.77 tok/s for the FFN relations only**; 196.79 s total logged wall [MEASURED 2026-09-04] | **Public IO, FFN only** (no attention, norms or residual links). A diagnostic, never P1 (D1, D17). All 256 export tensor files are gone, so it cannot be re-run | None (public IO) | No; show the log line only |
| 7 | **Trained checkpoints pinned** (`results/zk60_1b_checkpoint_20260927/`, `results/zk60_mvp_20260929/`) | Real models are identified and ready for import | TinyLlama-1.1B-Chat rev `fe8a4ea1`: local SHA-256 matches, 201-tensor importer inventory passes. **1,100,048,384 parameters, of which 968,974,336 are in the 22 blocks.** Llama-3-8B (NousResearch mirror, rev `315b2009`): metadata only. **8,030,261,248 parameters, of which 6,979,584,000 are in the 32 blocks** [COUNTED from configs] | No calibration and no proof for either | n/a | Show file identities only |
| 8 | **GPU correctness discipline** | GPU results are byte-exact against the CPU | 189-case device oracle; 8 frozen proof-byte comparisons; keyed-commitment gates re-run today, 3/3 passing (4.0-4.3 s each) on the candidate restored from 184 pinned hashes (`results/zk60_mvp_20260929/device-gates/`) [MEASURED] | Correctness, not speed | n/a | No |

### 1b. Could be added by 10-06 if the week plan (section 4) lands (none done yet)

- **The first multi-block GPU measurement:** 12 blocks of 125M geometry on
  the 4070. It is projected at about 206 s prove-only (about 2.5 tok/s) and
  about 300 s end to end (about 1.7 tok/s) [MODEL]. A retry of
  `ops/zkp-mvp/baseline_run.py` is needed.
- **The first 1B-geometry block:** TinyLlama dimensions with synthetic dense
  weights on the 4070. Projected at about 37 s prove. The counted floors are
  3.72-3.76 GiB VRAM and 6.88 GiB host, so it should fit.
- **The first 1B-geometry full stack:** 22 blocks with synthetic weights,
  projected at 822 s prove-only (0.62 tok/s) [MODEL].
- **The first RTX 5090 number**, only if Victor installs Linux on that PC
  early in the week (ZK60_HARDWARE_SETUP.md).
- **A stretch:** a trained TinyLlama block. It is the integrator's 10-02
  go/no-go, and it needs a versioned full-block integer calibration,
  layer-streamed quantization with integer-kernel parity, a new profile and
  rejection controls (`results/zk60_techweek_20260929/trained-readiness.json`,
  gates 2-4).
- **Not realistic by the meetings:** any privacy acceptance above toy scale,
  any 8B-geometry block (it does not fit the laptop), and any 5090
  throughput claim at scale.

---

## 2. Honest extrapolation from one measured block to 1B and 8B stacks

**Method, in plain words.** The measured base is the 125M-geometry block
above. Its phase clock splits every second of proving into about 40 named
steps, and each step works over a known domain: committed rows, the T×d
planes, the T×FFN planes, the heads×T² attention domain, and so on. Real
layout constructors give those domain sizes for the 1B geometry (TinyLlama)
and for the 8B geometry. Llama-3-8B has the same block geometry as the
Mistral probe: d 4096, FFN 14336, 32 query / 8 KV heads, head width 128.
`extrapolate.py` multiplies each measured step by its own domain growth. The
result is 2.18x per block for 1B and 3.09x for 8B. Plain committed-row
scaling gives 2.25x and 3.25x, so the two agree within 5%.

A full-stack pass is (blocks) × (witness + prove). One measured check
supports that: the 12-block CPU run took 397.71 s, or 33.1 s per block. The
same-era prover's single block took 27.67 s to prove, plus the 5.2-6.1 s
witness builds seen in later samples, which gives 32.9-33.8 s. So block
chaining added no visible overhead [COUNTED, one run]. 512 token positions
are counted once for the whole stack, never once per layer. **The 50 tok/s
budget at 512 tokens is 10.24 s per stack pass: 0.47 s per 1B block or
0.32 s per 8B block.**

### 2a. Per block (T = 512)

| Geometry | Blocks | Committed rows A+H | Prove / block, GPU arm | Prove / block, CPU 2 threads | Witness / block (band) | Receipt / block | Label |
|---|---:|---:|---:|---:|---:|---:|---|
| 125M (measured base) | 12 | 12,801 | **17.13 s** | **32.95 s** | 5.8-8.2 s | 40.8 MB | [MEASURED] |
| 1B, TinyLlama geometry | 22 | 28,817 | 37.4 s | 73.0 s | 18-58 s | 73.7 MB | [MODEL] |
| 8B, Llama-3-8B geometry | 32 | 41,665 | 52.9 s | 104.2 s | 27-285 s | 100.3 MB | [MODEL] |

The low end of the witness band assumes witness work grows like committed
rows. The high end assumes it grows like the dense multiply-adds (7x at 1B,
35x at 8B). The 125M witness base is noisy: 5.77 and 10.66 s in the two GPU
samples.

### 2b. Full stack, 512 tokens, and the gap to 50 proved tokens/s

| Configuration | Stack prove | Proved tok/s, prove only | End to end, with witness (band) | Gap to 50 | Label |
|---|---:|---:|---:|---:|---|
| 125M geometry, 12 blocks, CPU, **actual run** | 397.71 s (includes witness) | **1.29** | 1.29 (verify is a separate 14.45 s) | 39x | **[MEASURED, n=1]** |
| 125M geometry, 12 blocks, 4070 GPU arm | 206 s | 2.49 | 1.66 | 20x | [MODEL]; a run would confirm it this week |
| 1B, 22 blocks, 4070 GPU arm | 822 s | 0.62 | 0.24-0.42 | 80x | [MODEL] |
| 8B, 32 blocks, 4070 GPU arm (**does not fit** this laptop) | 1,692 s | 0.30 | 0.05-0.20 | 165x | [MODEL] |
| S1: 8B on a 5090 box, **today's code** | 416-825 s | 0.62-1.23 | not modelled | 41-81x | [MODEL on MODEL] |
| S1: 1B on a 5090 box, today's code | 202-401 s | 1.28-2.53 | not modelled | 20-39x | [MODEL on MODEL] |
| S2: 8B on the 4070 with **all proof sumchecks on the GPU (not built; still does not fit)** | 244-405 s | 1.27-2.10 | needs device witness too | 24-40x | [MODEL on MODEL] |
| S3: 8B on a 5090 with all sumchecks on the GPU (not built) | 41-101 s | **5.1-12.6** | needs device witness too | **4-10x** | [MODEL on MODEL] |
| S3: 1B on a 5090 with all sumchecks on the GPU (not built) | 20-49 s | **10.5-26.1** | needs device witness too | 1.9-4.8x | [MODEL on MODEL] |
| *Not comparable:* historical Mistral-7B FFN-only, **public IO** | 58.40 s | 8.77 | 2.60 (logged wall) | 5.7x vs budget | [MEASURED, 2026-09-04] |

Scenario factors. **None has been measured.** Each is the item a measurement
must replace:
- **S1:** commitments run 4-6x faster on a 5090 than on the laptop part.
  This is START_HERE's recorded "desktop board factor", never measured. The
  other phases run 2-4x faster on a desktop host with more threads than the
  A/B's 2 threads. For reference, on this laptop the 2-thread CPU block is
  32.95 s, and the earlier lane-configured CPU runs were 17.4-19.4 s.
- **S2:** every CPU phase gets ported to the device at 5-10x the 2-thread
  CPU. The basis is one historical row: the public FFN line's activation side
  took 285 s on 8 CPU threads and 38.6 s on this GPU, which is 7.4x.
- **S3:** S2 × the 4-6x board factor.
- The scenarios cover proving only. In S2 and S3 the witness build must also
  move to the GPU (it is integer inference), or it dominates. At 8B the
  current CPU witness band is 27-285 s per block.

**What does not close the gap:**
- **Larger workloads.** Victor allows them, but they amortize only fixed
  costs. The measured fixed cost is about 0.2 s (CPU) to 3.9 s (GPU
  process/device start) per process, against about 1,700 s of per-token work
  at 8B today, so the gain is under 1% [COUNTED]. At S3 speeds the same
  start-up would be 4-10% of a pass, worth amortizing with a resident model,
  but it is not a multiplier.
- **Longer single contexts.** They increase per-token cost, because the
  attention domain grows with T².
- **Weight preprocessing.** It helped the historical FFN line (its
  weight-commit phase was 19.8 of 58.4 s). The private block does not commit
  public weights, so no such phase exists to remove.
- **Batching public-weight work across requests.** The researcher measured
  it at under 0.1% (a retained negative).

**Levers that could, none built.** The first four are in rough order of size:
1. A device sumcheck, starting with the softmax zero-check at about 47% of
   GPU-arm proving. It is research hypothesis 1, with its exact
   transcript-parity oracle still owed.
2. Device witness generation.
3. The 5090 itself.
4. A causal-packed attention domain. Counted optimistically, it saves up to
   5,610 of 41,665 committed rows at 8B T512 and about half the softmax
   domain. It is designed only, and today's layout saves zero rows.
5. D14's fewer-hashed-bytes lever: rate 1/2 and/or a 31-bit field. It exists
   as a memo only and would move every frozen digest and the soundness
   accounting.
6. CPU/GPU overlap across consecutive blocks.

**Assumptions and the measurement that confirms each:**

| # | Assumption | Confirming measurement | Feasible by 10-06? |
|---|---|---|---|
| A1 | Per-block cost grows about 2.2x (1B) and about 3.1x (8B) with the layout domains | One synthetic TinyLlama-geometry block on the 4070 (1B). One Llama-3-geometry block on the 5090 or the 512 GB Mac (8B) | 1B: yes. 8B: only on the 5090/Mac |
| A2 | A run of L blocks costs L × (witness + prove) | The 12-block 125M GPU run, then a 22-block 1B-geometry run | Yes / stretch |
| A3 | The witness band: rows-like to MAC-like growth | The witness clock of the same 1B-geometry block | Yes |
| A4 | The 5090 is 4-6x the laptop GPU on commitments | The same 125M block A/B on the 5090 | Only if Linux is installed by about 10-02 |
| A5 | More host threads give 2-4x on the CPU phases | The A/B at `RAYON_NUM_THREADS` 2 / 8 (laptop) and 2 / 16+ (5090 host) | Yes on the laptop |
| A6 | The device sumcheck reaches 5-10x the 2-thread CPU | Native SC_SZC device route with byte-exact transcript parity, then a per-slot clock | No (weeks) |
| A7 | Public-weight folding stays negligible. It grows 7x (1B) and 35x (8B) per block and is not separately visible in the 125M phase table | The phase table of the 1B-geometry block; a weight-fold work count | Yes (1B) |
| A8 | Memory fits: 1B on the 4070; 8B on the 5090 (chunked GPU A/H counted at 5.17 GiB VRAM, host at least 9.86 GiB during H construction) | Measured VRAM and host peaks for the same runs | 1B: yes |
| A9 | Trained weights prove at synthetic-weight speed. Dense and diagonal synthetic weights cost the same measured time at 125M | A trained TinyLlama block after calibration | No |

**Bottom line on speed.** No assumption recorded in this repository reaches
50 proved tok/s for a private 8B stack yet. The most favorable counted
scenario is about 5-13 tok/s on a 5090, and it needs an unbuilt device port.
For a 1B model the same scenario reaches 10-26 tok/s.

---

## 3. Claims to avoid, and what to say instead

| Don't say | Say instead | Why (source) |
|---|---|---|
| "We prove an 8B model" / "full-model proofs" | "We prove complete private transformer blocks at the block geometry of a 125M model, and a 12-block stack. Our 8B-scale proof so far is public-IO, feed-forward only" | No complete private 8B pass exists (MVP_STATUS; START_HERE §2) |
| "One block = the model" / "a 125M model" | "One block of twelve at 125M geometry, synthetic weights" | ZK60_1B_CHECKPOINT: never describe a single block as a complete-model pass |
| "Trained model" for any private proof | "Synthetic dense public weights. The TinyLlama 1.1B checkpoint is pinned, and calibration is next" | No calibration exists (ZK60_1B_CHECKPOINT) |
| "X proved tokens/s" for private 1B/8B | "Measured: 1.29 tok/s for a synthetic 125M-geometry 12-block stack on CPU. Everything at 1B/8B is a labelled projection" | Section 2 |
| "50 tok/s is within reach" / "on track" | "The best counted scenario is about 5-13 tok/s at 8B on a 5090 after an unbuilt GPU port. 50 needs more than that" | Section 2 |
| "Zero-knowledge / private" with no scope | "The privacy argument is accepted for one toy block on the CPU path (D22), by our internal security owner in the random-oracle model. Larger shapes hide the data by construction, but their privacy review is open" | D22; D19b and D23 pending; D8/D11 open |
| "128-bit security" / "secure" with no number | zkVM line: "about 97 bits conjectured (RISC Zero default), accepted as a recorded deviation". Custom line: "about 106 bits per opening; about 94 bits projected for a whole 8B proof" | D3, D15 |
| "No trusted setup" for the 785-byte receipt | "The 785-byte receipt uses Groth16 on RISC Zero's ceremony. Soundness assumes one honest participant; privacy does not depend on it. We have not yet run the ceremony verification ourselves" | D4; ZK60_CEREMONY_CHECK_REVIEW |
| "Tiny proofs, instant verification" at model scale | "Tiny (785 B) only on the zkVM toy line. Our fast line's receipts are about 41 MB per 125M block and about 3.2 GB projected for an 8B stack. Proof size is an open item" | Section 2a; TARGET_CONTRACT budgets unmet |
| "We prove token generation" (custom line) | "The first MVP proves the hidden blocks (D13). Only the zkVM toy has a token path" | D13 |
| "Weights stay private" | "Weights are public in every artifact today. Hidden weights (P3) are the full version" | D1 |
| "5090 / H100 numbers" | "No 5090 measurement yet; the machine is being installed" | ZK60_HARDWARE_SETUP |
| "GPU makes it 2x faster" | "Against a 2-thread CPU run the GPU arm halves proving time and cuts host memory 2.4x. Only the commitments are on the GPU so far" | A/B scope; earlier CPU runs at other thread settings were 17.4-19.4 s |
| "Audited" / "independently verified security" | "Internal adversarial reviews by separate agents; no third-party audit" | D22 wording |
| "A regulator can seal an input in advance" / "proofs compose" | "Today the prover seals inputs at proof time. Advance sealing is a planned milestone. Separately finished proofs cannot be chained" | D18; D8/D11; D12a |
| "Faster than [vendor]" | Make no comparison. Vendor figures (for example 53 tok/s for Gemma-4-31B on an H100) are unverified and use different guarantees | START_HERE §2 [EXTERNAL] |
| "p95", "benchmark", "stable speedup" | "One or two samples on a shared laptop, not quiesced" | CLAUDE.md measurement rules |
| "Production-ready" / "compliance-ready" | "A research MVP with a published decisions register and evidence trail" | — |

---

## 4. Prioritized week plan (Tue 09-29 → first meeting ~Mon 10-05)

The dates follow the integrator's gates in `ZK60_TECHWEEK_DEMO.md`: the
native stack CLI on 10-01, the trained-model go/no-go on 10-02, the build
freeze on 10-03, and rehearsal on 10-04. That document assumes a first
meeting on Monday 10-05; the soft deadline is about 10-06.

Rules that apply all week: heavy runs are detached behind
`/tmp/zk-heavy.lock` with a `.done` marker, one GPU job at a time, and never
two GPU passes chained in one script (the WSL VRAM-freeze rule). There are
**no new heavy runs after the Saturday freeze**, apart from the Sunday
rehearsal. Owners are suggestions; the lane map is
`ZK60_SOL_TEAM_20260927.md`.

**Priorities.** P0 = the demo works and every claim is sourced. P1 = replace
the two most important projections with measurements. P2 = strengthen the
story. P3 = only if hardware arrives.

| Day | Deliverables (priority, owner) | Gate / fallback |
|---|---|---|
| **Tue 09-29** (done) | This note, `DEMO_SCRIPT.md`, `extrapolate.py`, `rehearse.py`; CPU rehearsal of demos 1-3 passes, 5/5 steps (P0, Lane D). The integrator's browser demo passes 32 HTTP checks. MVP_STATUS append | — |
| **Wed 09-30** | **P0-1** Freeze the demo kit: the browser demo plus the `rehearse.py` fallback, binary hashes pinned, a copy of the public artifacts kept (root). **P0-2** Rebuild `zk60_private_block` from the main tree, or confirm that the 09-20 binary's source matches D22's pins; until then, quote demo 3 as "the profile whose privacy argument was accepted" with the caveat (security owner). **P1-1** Retry the 12-block 125M GPU run (`ops/zkp-mvp/baseline_run.py`: create the receipt dir; about 5 min, heavy lock) (root). **P0-3** Record the 125M one-block GPU run on screen (about 30 s) as the stage fallback | P1-1 passes → it replaces the 206 s / 1.66 tok/s projection. Fails → keep the CPU 12-block record (1.29 tok/s) |
| **Thu 10-01** | **P1-2** A synthetic TinyLlama-geometry block (T512, d2048, f5632, 32/4 heads, dh 64, log_cols 14) as an unregistered, test-only development shape, one proof on the 4070 with the phase clock; confirms A1/A3/A7/A8 (Sol model lane). Also the integrator's gate: the native stack CLI (Sonnet lane) builds and its segment controls pass. **P3-1** Victor: go/no-go on the 5090 Linux install (`ZK60_HARDWARE_SETUP.md`, then `zk60_host_preflight.py`) | Measured prove within ±30% of 37 s → A1 holds; otherwise re-derive section 2 and report the measured figure |
| **Fri 10-02** | The integrator's **trained-model go/no-go**: TinyLlama calibration, profile and one trained block. Treat it as a stretch; it needs calibration design, parity and review. **P2-1** If P1-2 passed: a 22-block 1B-geometry synthetic run, detached (projected 822 s prove-only, about 21-35 min end to end) (root). **P2-2** Laptop thread-scaling A/B at `RAYON_NUM_THREADS` 2 vs 8 for A5 (root; after P2-1) | No trained block → present the synthetic prototype with that limit (do not rename it). P2-1 fails on memory → report the peak; the single-block numbers stand |
| **Sat 10-03** | **Freeze the meeting build.** **P0-4** Swap measured rows into this note and MVP_STATUS; one-slide numbers sheet with measured and projected values in two colors; wording checked against section 3 (Lane D + security owner). **P3-2** Only if the 5090 is already up: device gates, then the 125M A/B on it, which is the first measured board factor (A4) | No 5090 → S1/S3 stay [MODEL]; say so on stage |
| **Sun 10-04** | **P0-5** Rehearsal with Victor, twice: once offline, once with the GPU idle. Finalize the fallback video. Claims review | A live failure → fallback level B |
| **Mon 10-05 → ~10-06** | Meetings. Run `rehearse.py` (or the browser demo's saved checks) each morning. Live: demos 1-3 (CPU, under 1 s). GPU demo 4 live only if that morning's run is clean, otherwise from the recording | — |

**Demo fallback ladder:**
- **A (full):** the browser demo. That is live demos 2 and 1 (the saved
  token and block receipts with proof/policy tamper refusals) and live demo 3
  (a fresh native proof verified in a separate process). All three are
  CPU-only and take under a second in total. Then demo 4 live on the GPU
  (about 30 s) and the 12-block record.
- **B (GPU unsafe or busy, or the browser demo fails):** the same CPU steps
  through `rehearse.py` / the `DEMO_SCRIPT.md` commands, with demo 4 from the
  recording.
- **C (laptop down):** the recorded session plus the public artifacts and
  their SHA-256 on any machine, plus the numbers sheet.
- **D (no screen):** the numbers sheet and this note's sections 0 and 3.

**Out of scope for the meetings, and to say so if asked:** a trained-model
proof (unless the 10-02 gate passes, in which case it is one trained block,
not a stack), privacy acceptance above toy scale, an 8B-geometry block, and
a 5090 at model scale.

---

## 5. Evidence index

- 125M A/B: `results/zk60_sol_gpu_20260927/dense125m_ab_analysis.md`,
  `attempt-5-dense-ab/report.json` (log SHA-256 values are checked by
  `extrapolate.py`).
- Layout counts: `results/zk60_sol_model_20260927/layout_account.json`
  (m125 control, Mistral/Llama-3 geometry T512),
  `results/zk60_1b_model_20260927/layout_ladder.json` (TinyLlama T512), and
  `gpu-chunked-memory-audit.md`.
- zkVM receipts: `results/zk60_loop_20260918/{block-integration/groth16_public,token-integration/token_public}/`.
  Block receipt SHA-256 `6c67e05c…32e7`, image `8d74aab3…98d9`.
- Today's rehearsal: `rehearsal-20260930T002413Z.json` (block wrap binary
  `3e7b1cd9…cb59`, toy example `81989569…b8cf`; token receipt SHA-256
  `94f3ce14…2cb0`, image `3c0631ee…430b`).
- The integrator's browser demo: `docs/zkmatrix-poc/ZK60_TECHWEEK_DEMO.md`,
  `results/zk60_techweek_20260929/` (HTTP checks and a trained-readiness
  inventory with the five-gate critical path to a trained TinyLlama proof).
- 12-block and historical FFN records: `docs/zkmatrix-poc/MVP_STATUS.md`,
  `results/hashline_convert_r3.log`.
- Checkpoints: `results/zk60_1b_checkpoint_20260927/inventory_20260929.json`,
  `results/zk60_mvp_20260929/{tinyllama-1.1b,llama3-8b}/source.json`.
- Rulings: `docs/zkmatrix-poc/ZK60_DECISIONS.md` (D1, D2, D3, D4, D5, D7,
  D13, D15, D18, D22 cited; D19b and D23 pending).
