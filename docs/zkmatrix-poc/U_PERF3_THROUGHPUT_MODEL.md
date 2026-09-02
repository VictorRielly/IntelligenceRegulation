# U-PERF3 lane TT — the throughput model: proven tokens per second, honestly

Status: IN PROGRESS (opened 2026-09-02; round 10 of tranche U-PERF3,
lane TT, docs only, worktree wt-uperf3-tt). Sections land one commit
each; the "Agent TT status" block in PROGRESS_UPERF3.md carries the
summary.

Who this is for: a reader who knows what a cryptographic proof is
but has never opened this repository. Every term is defined where it
first appears. Every number carries one of four labels:

- **[MEASURED]** — a run happened on a named machine, on a named date.
- **[COUNTED]** — derived by arithmetic from measured pieces or from
  the engine's own counters (the arithmetic is shown).
- **[MODEL]** — an estimate; the assumption is written next to it.
- **[EXTERNAL]** — someone else's claim; unverified by us.

Where a number is a [MODEL] built on another [MODEL], the cell says
so ("[MODEL on MODEL]"). Where two sources disagree, the memo says
which is newer and uses that one.

The question this memo answers (Victor, 2026-09-02): the goal is now
**at least 50 proven tokens per second for a 30B-parameter model on
ONE GPU** (an H100-class board is allowed). What does the system as
built give today, in those units? What would a 50 tok/s design have
to look like? And is the 2026-08-30 task-board line ("~25-35 tok/s
amortized ... compose to ~65") derivable from anything recorded?

## Sources (every number below traces to one of these)

| tag | file | what is taken from it |
|---|---|---|
| S1 | `PROGRESS_UPERF2.md`, "Orchestrator status (2026-08-18, after round 9 — P + Q)" | the reference measurement: 12 layers x 512 tokens of the 125M model, 21.0 s = commit 2.5 / prove 15.5 / verify 1.7, 8 threads + RTX 4070 Laptop, QUIET; CPU-only 81.5 s; 6.7 GB; the phase attribution; 1.4e9 proven MAC/s |
| S2 | `PROGRESS_UPERF2.md`, "Decision memo (orchestrator, 2026-08-18)" | the gap arithmetic; the 4-6x desktop-board factor [MODEL]; the three routes |
| S3 | `docs/zkmatrix-poc/U_PERF3_HEADLINE_ROUTES.md` §1.2, §1.3, §2.1, §2.4, §2.6, §3.1, §3.3 | what scales how (weights x99.6, activations x18.5, opening terms x41-43); the 8B wall phase by phase [MODEL]; the two-tier reroute; the hardware note; weight preprocessing (designed, never built); the compounding table; the honesty block |
| S4 | `docs/zkmatrix-poc/U_PERF3_OPENING_LAYER_DESIGN.md` §1, §3.2, §3.3 | the built protocol's cost anatomy; Stage A's prover model at 12x512 and at 8B |
| S5 | `docs/zkmatrix-poc/U_PERF3_S4_REDESIGN.md` §1, §3, C-R1, closing verdict; `PROGRESS_UPERF3.md` "Agent FF status" rung 3 | the two-tier opening spike: measured 1.10x; the bench anatomy rows 1.45 / commit 14.59 / v-passes 20.01 / fold 2.25 s at 2^22 rings, 1 thread; the redesign's 1.6-2.5x composed count |
| S6 | `PROGRESS_UPERF3.md` "Orchestrator note 2026-08-29 — the composition ladder" | Stage A vs the oracle at 12x64 / 12x128 on CPU: bytes 2.1-2.15x smaller, prove +15% |
| S7 | `PROGRESS_UPERF3.md` "Agent OO status" RUNG 3 | 8B memory: commit ~61 GB, pass peak ~72 GB; 30B: weight-group terms ~265-270 GB |
| S8 | `docs/zkmatrix-poc/U_PERF3_MVP8B_SCALING.md` §1.1, §1.2, §1.6, §3.3 | the 8B scaling model (ring counts per group; the T axis moves only the activation side); the Mac CPU projections |
| S9 | `docs/zkmatrix-poc/AGGREGATION_LITERATURE.md`, "Addendum 2026-08-11 — Attestable" and "Conversion note 2026-08-18" | the competitor's claim (53 / 77 tok/s, one H100) and the ledger's conversion (3.1e10 MACs per token at 30B; 1.6e12 proven MAC/s) |
| S10 | `docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md` §3 | the common yardstick and the 5-15x hardware normalization used there |
| S11 | `docs/zkmatrix-poc/TASK_BOARD.md` §0, the "AS OF 2026-08-30" block | the line under audit: "~80 proven tokens/s per H100 board at 30B — currently counted ~25-35 amortized; ... 1.2-1.5x, pipelining 1.3x, spine amortization 1.1-1.2x ... compose to ~65" |
| S12 | `docs/zkmatrix-poc/TARGET_CONTRACT.md` §3-4 | what the clock covers (starts with the committed model and the tokens in memory, stops at proof bytes; excludes weight commitment and CRS expansion); the hardware line (<= 450 W consumer board) |
| S13 | `docs/zkmatrix-poc/MAC_RUNBOOK.md` M5 | the T-scaling leg on the Mac (layer 0 of the 8B model at T = 16 / 64 / 512): the measurement that gives the weight-vs-activation split directly |
| S14 | `docs/zkmatrix-poc/U_PERF2_GPU_REPORT.md` §4.5 and header; `U_PERF2_GPU4_REPORT.md` §4.5 | the laptop GPU's recorded specs (36 SMs, 8 GB); the measured kernel ceilings (1.7 G K-mults/s; the level-h GEMM at 74 G MAC/s, ~30% of the part's integer peak; 11.7 GB/s host-to-device); the report's own desktop-board note |
| S15 | `PROGRESS_UPERF3.md` "ROUND 10" block and "### Lane QQ / RR / TT" briefs | the goal as restated; the two facts Victor asked to double-check; what each round-10 lane measures |
| S16 | `docs/zkmatrix-poc/START_HERE.md` §2-6 | the plain-language state of the project (used for definitions and cross-checks only) |

Public hardware specifications (SM counts, clocks, memory bandwidth,
board power) are quoted from the vendors' published spec sheets and
are labelled [EXTERNAL, spec sheet]; none was measured here.

## 0. The answer in one paragraph

The only proof this repository has ever timed is 12 layers x 512
tokens of a 125M model on a laptop: 18.0 s of prover time (21.0 s
with verification), which is 28 proven tokens per second OF THAT
SMALL MODEL, feed-forward blocks only [MEASURED, S1]. Scaling that
measurement by the counted growth of each phase, the built system at
8B is a **~0.6-0.8 tokens/s system for 512-token prefill on the
laptop, ~1-5 tok/s on one desktop board, ~1-7 tok/s on one H100
[MODEL]**, and a **~0.0025 tok/s system for batch-1 decode on the
laptop (~0.005-0.02 on either big board)** — decode is ~250x worse
than prefill because the built protocol re-proves the entire weight
side on every proof, and at one token per proof the weights are
99.9% of the witness. At 30B every number is 3-4x smaller again, and
the pass does not fit any single board. **50 tokens/s at 30B means
1.55e12 proven MAC/s, 20 ms per token, 10.2 s per 512-token proof —
about 1,000x the measured rate.** The recorded design path (Stage A
+ the two-tier opening + weight preprocessing) at its own modelled
constants lands at **2-15 tok/s for 30B prefill and 0.05-0.7 tok/s
for 30B decode on one H100 [MODEL on MODEL]**, and at the constants
the two-tier spike actually measured it lands 3-30x lower than that;
so under no assumption recorded in this repository does the lattice
line reach 50 tok/s, in either workload. The gap is structural, not
a tuning gap: it needs (i) a per-proof weight-side cost that does not
walk the weight digits per token, or hundreds of tokens per proof;
(ii) an activation-side proving rate ~10-30x above the best modelled
one; (iii) attention in the statement (the numbers above cover
69-78% of a real token's MACs). The 2026-08-30 task-board line
("~25-35 tok/s amortized ... ~65") is unsourced in every part and is
retracted in §5. The measurements that decide whether the lattice
line can move at all are lane QQ (the per-proof weight-side opening
on the GPU after preprocessing), lane RR (Stage A on the device) and
the Mac runbook's T-scaling leg (the weight/activation split at 8B).

## 1. Workload definitions and MACs per token

### 1.1 Terms used throughout

- **MAC**: one multiply-accumulate (`acc += a * b`). The unit of
  inference work; a model with P weights costs about P MACs per
  token in its matrix multiplications. All MACs here are 8-bit
  integer MACs, because the model is first converted to exact
  integer arithmetic (S16 §1).
- **Token**: one position in the text. **Prefill** processes a whole
  prompt of T tokens in one forward pass. **Decode** generates one
  new token per forward pass, reusing the cached attention state of
  the earlier positions.
- **Proof / pass**: one run of the prover producing one proof. A
  proof covers a **statement**: "these committed weights, applied to
  these T tokens, produced these outputs". The **witness** is every
  number the proof is about: the weights, the activations (the
  values flowing between layers), and helper values.
- **Weight side vs activation side**: the witness has two halves.
  The weights are the same for every proof of the same model. The
  activations differ per proof and grow with T. The engine commits
  them as two separate **groups** and opens each group once (S4
  §1.3).
- **Digit ring**: the unit the lattice commitment works on. The
  engine splits every witness value into small digits and packs 128
  digits per ring. The 8B weight group is 352 million digit rings
  (S8 §1.2). Costs of the commitment and opening phases scale with
  ring counts, not with MACs.
- **Proven MAC/s**: MACs in the statement divided by the prover's
  wall-clock seconds. The common yardstick of S9/S10; it lets a
  per-proof system and a per-token system be compared.
- **The prover clock**: per the contract (S12 §3) it starts with the
  committed model and the tokens in memory and stops when the proof
  bytes exist. It EXCLUDES verification, the one-time weight
  commitment and the CRS (public key) expansion. The ledger's 21.0 s
  reference wall INCLUDES 1.7 s of verification; this memo's
  tokens/s use the prover clock (commit + prove = 18.0 s at 12x512)
  and say so wherever the distinction matters.

### 1.2 The three workloads

| workload | tokens per proof | weight side paid | activation side paid | tokens/s |
|---|---:|---|---|---|
| **batch-1 decode** | 1 | once per proof = once per TOKEN | for one position | `1 / cost(T=1)` |
| **batch-T prefill** | T (512 in the contract, S12 §3) | once per proof = once per T tokens | for T positions | `T / cost(T)` |
| **pipelined batches** | T per proof, several proofs in flight | as prefill | as prefill | `T / (busiest resource's time per proof)` |

Writing the per-proof cost as `cost(T) = W + A(T) + F`, where W is
the weight-side work, A(T) the activation-side work (roughly
proportional to T above a small floor) and F the fixed per-proof
overhead (device init, the recursion's fixed levels — ~0.5 s at
12x512, S1 attribution "chain-derive ... ~0.5 s device init"):

- Decode at batch 1 costs `W + A(1) + F` per token. Under the built
  protocol W is paid in full on every proof because the weight
  group's opening is recomputed per proof (S3 §2.6: weight
  preprocessing is "designed only"). So batch-1 decode is
  weight-bound: at T = 1 the witness is 99.9% weights (§1.4).
- Prefill at T = 512 amortizes W over 512 tokens. Every measured
  number in this repository is a prefill number at T = 512 (S1, S12
  §3) or smaller T on the same axis.
- Pipelining overlaps consecutive proofs so that work on different
  resources (the GPU's kernels, the 8 CPU threads, the host-device
  link) proceeds concurrently. On ONE board it cannot exceed the
  bound `T / max(GPU-busy, CPU-busy, link-busy)` per proof; it is a
  multiplier only to the extent the pass is split across resources,
  and that split has never been recorded at the 8B shape (§5.3
  below). Multi-request batching (several independent requests
  decoded together, the competitor's "batch 4" in S9) is the same
  amortization as prefill with T = the number of requests.

### 1.3 The two model shapes

The **8B shape** is the real checkpoint in use, Mistral-7B-v0.1
(S8 §0-1.1): L = 32 layers, width d = 4096, FFN hidden f = 14336;
attention with 32 query heads of 128 and 8 key/value heads
[EXTERNAL, model card]; vocabulary 32,000.

For **30B** this repository records no architecture: the
competitor's model is "Gemma-4-31B" (S9), whose layer shape no memo
here states. This memo therefore adopts a **stand-in shape** and
labels every 30B number as depending on it: the public Gemma-3-27B
architecture [EXTERNAL, model card] — L = 62, d = 5376, f = 21504,
32 query heads of 128 (4096 wide), 16 key/value heads (2048 wide),
vocabulary 262,144, five local-attention layers (window 1024) per
global layer. Parameter count of the stand-in: 21.5e9 (FFN) +
4.1e9 (attention projections) + 1.4e9 (embeddings, tied) = 27e9.
If the real 31B model is 15% larger, every 30B cost row scales by
about 1.15x [MODEL].

### 1.4 MACs per token [COUNTED from the shapes]

| term (per token) | formula | 8B | 30B stand-in |
|---|---|---:|---:|
| FFN (gate, up, down) | `L x 3 x d x f` | 3 x 4096 x 14336 x 32 = **5.64e9** | 3 x 5376 x 21504 x 62 = **2.15e10** |
| attention projections (q, k, v, o) | `L x d x (q + k + v + o widths)` | 4096 x 10240 x 32 = 1.34e9 | 5376 x 12288 x 62 = 4.10e9 |
| output head | `vocab x d` | 32000 x 4096 = 1.3e8 | 262144 x 5376 = 1.41e9 |
| **dense total** | | **7.11e9** | **2.70e10** |
| attention scores + values at context C | `L x 2 x (heads x head_dim) x C` (per global layer; window instead of C for local layers) | C = 512: 1.3e8; C = 4096 (Mistral's sliding window): 1.07e9 | C = 16,384 with the 5:1 local/global pattern: 1.78e9; all-global at 16,384: 8.32e9 |
| **total per token** | | **7.2e9 (C = 512) to 8.2e9 (C = 4096)** | **2.9e10 (16K, local/global) to 3.5e10 (16K, all global)** |
| FFN share of the total | | 69-78% | 61-75% |

The ledger's yardstick "one decoded token at 30B costs ~3.1e10 MACs"
(S9 conversion note; S15) is the "1 MAC per parameter at 31B"
convention. It sits inside the counted band, so this memo keeps it:
**50 tok/s at 30B = 50 x 3.1e10 = 1.55e12 proven MAC/s = 20 ms per
token**, and the budget per proof at T = 512 is 10.2 s.

**Honesty about the statement.** The built and measured statement is
the FFN only (S16 §2: "any write-up must say FFN-only"; S12 §1 the
contract's surrogate). Every tokens/s number in §4 is therefore an
**FFN-proven** token: 5.64e9 MACs per token at 8B, 2.15e10 at 30B —
69-78% of the dense MACs. Adding attention adds 1.3-1.6x MACs, but
the routes memo's honesty block (S3 §3.3) prices attention at ~3.5x
per layer of statement MASS (its lookups and softmax chain are not
matmul-shaped), so the full-model proof cost is NOT 1.3-1.6x the
FFN's; it is unmeasured until spike X3 (one attention layer proven
at 125M) lands.

### 1.5 The witness at each workload [COUNTED, S8 §1.2 and its scaling law]

The engine's public counters give the 8B ring counts; the 30B
stand-in is scaled by the same laws (weight rings = `L x 3df / 16`,
activation elements = `L x T x (10f + 4d)`):

| group | 8B, T = 512 | 8B, T = 1 | 30B stand-in, T = 512 | 30B stand-in, T = 1 |
|---|---:|---:|---:|---:|
| weight group (digit rings) | 352,321,536 [COUNTED = S8] | 352,321,536 (same at every T, S8 §1.6) | 1.34e9 (x3.81) | 1.34e9 |
| activation group (digit rings, incl. ~43K fixed aux) | 145,475,764 [COUNTED = S8] | ~0.33M (145.5M / 512 + aux) | ~417M (x2.87 in activation elements) | ~0.9M |
| weight share of the witness | 71% | **99.9%** | 76% | **99.9%** |

Two facts to carry: (1) at T = 1 the proof is a proof about the
weights — any per-proof cost that is linear in the weight rings is
paid in full per token; (2) at 30B the weight group is 3.8x the 8B
one and the digit store alone is 1.34e9 x 128 bytes = **172 GB**
(45 GB at 8B, S8 §1.2 "w0 flat i8 store"), which sets the memory
question of §3 and §7. The 30B FFN hidden 21504 is not a power of
two; the engine pads f-shaped tables to the next power of two (S8
§1.1: 14336 -> 16384, 12.5%), so a 30B port would pay 52% padding
(21504 -> 32768) on the activation-side tables unless the padding
rule changes [COUNTED, shape-dependent].

## 2. The cost anatomy per proof: per-model vs per-proof

"Per-model" means work that depends only on the weights and could be
done once at model-export time and cached; "per-proof" means work
that depends on the proof's inputs or on the per-proof random
challenges and must be redone every time. The contract's clock (S12
§3) already excludes committing the weights and expanding the CRS,
so per-model work is legitimately off the clock — IF the protocol
separates it. The built protocol does not (S3 §2.6): the weight
group's opening is recomputed on every proof. That is the single
fact that makes batch-1 decode expensive today.

### 2.1 The reference measurement and how each phase scales

The one fully measured pass: 12 layers x 512 tokens of the 125M
model on the WSL laptop (Core Ultra 9 185H, 8 threads, RTX 4070
Laptop GPU at 55-70 W), QUIET, three consecutive runs 21.0 / 21.1 /
20.9 s, 20-run p95 21.1 s, 6.7 GB RSS, proof 1,509,911 bytes, every
digest identical (S1). Its phases (S1 attribution; the listed phases
sum to ~22 s against the 21.0 s wall because the timers overlap by
~1 s):

| phase (what it does) | 12x512 [MEASURED] | side | scale driver to 8B x 512 [COUNTED, S3 §1.2] |
|---|---:|---|---|
| commit (bind the witness: u_0 matvecs, the chain GEMM = the integer forward pass, digit witness) | 2.5 | both | rings x44 blended; the chain GEMM x99.6 |
| prove-group (the lattice opening's main pass: level-h, kernel rows, psi0, fold, matvec) | 7.1 | both, by rings | the level-0 cross term Theta(n_0 x r): x42 |
| descents (the range and table-lookup facts as masked GKR sub-proofs) | 6.5 | activations only | leaf elements x19.9 |
| claim layer (the matmul / Hadamard / requant sumchecks) | 1.75 | mixed | weight-side table build x99.6; activation-side rounds x16 |
| transport (carrying claims between levels) | 1.4 | both, by rings | ~x40 |
| CRS expand (the public commitment key, seed-expanded) | 1.3 | both, by A_0 size | x43 |
| verify (8 threads; NOT on the prover clock) | 1.7 | both, by value rings | x41 |

Rates at this shape: 2.9e10 MACs / 21.0 s = **1.4e9 proven MAC/s**
on the wall the ledger quotes; 2.9e10 / 18.0 s = 1.6e9 on the
prover clock [COUNTED from S1].

### 2.2 (a) The built pass at 8B x 512 — every term per proof

The 8B phase totals are the routes memo's (S3 §1.3: each measured
phase times its counted driver; "~11-16 min" on the laptop if it had
the memory — it does not, 15 GB vs a ~72 GB peak, S7). The
weight/activation split per phase is this memo's, by the ring shares
of S8 §1.2 (weight 352.3M of 497.8M rings = 71%; level-0 CRS 64.4 of
94.8 GB = 68%; value rings 44.0M of 64.5M = 68%) and, for commit, the
routes memo's own "~2/3 weight" (S3 §2.6):

| phase | 8B laptop [MODEL, S3 §1.3] | weight share used | W (weight side, s) | A(512) (activation side, s) |
|---|---:|---:|---:|---:|
| commit | 110-160 | 2/3 (S3 §2.6) | 73-107 | 37-53 |
| prove-group | ~290 | 71% (rings) | ~206 | ~84 |
| descents | 80-300 (the range depends on whether the trees fit VRAM — they do not on 8 GB) | 0% | 0 | 80-300 |
| claim layer | 30-40 | ~50% [MODEL: the weight-side table build vs the activation-side rounds] | 15-20 | 15-20 |
| transport | ~55 | 71% | ~39 | ~16 |
| CRS expand | ~55 | 68% | ~37 | ~18 |
| **prover clock** | **620-910** | | **W = 370-409** | **A(512) = 250-491** |
| verify (off the clock) | ~70 | 68% | ~48 | ~22 |

Reading: on the built protocol **W is 45-60% of every 8B prefill
proof and 99% of every 8B decode proof**. At T = 1 the activation
side collapses to A(1) ~ A(512)/512 ~ 0.5-1 s plus the fixed floor F
of a small group's recursion (~1-2 s; the whole 3-layer x 16-token
pass measures 3.4 s, S1), so:

- cost_a(T=512) = 620-910 s per proof (512 tokens) [MODEL];
- cost_a(T=1) = W + A(1) + F = **~372-411 s per token** [MODEL on
  MODEL].

At the 30B stand-in (§1.5: weight rings x3.81, activation elements
x2.87), scaling W and A(512) by those factors [MODEL on MODEL; and
the pass does not fit any machine we own — the weight-group terms
alone are ~265-270 GB, S7]: W = 1,410-1,558 s, A(512) = 718-1,409 s,
cost_a(512) = 2,130-2,970 s, cost_a(1) = ~1,412-1,561 s per token.

### 2.3 (b) Built pass + Stage A

Stage A replaces the descents (the ten masked lookup sub-proofs)
with aggregate zero-checks in the base field and one LogUp sumcheck
for the SiLU table (S4 §2). It is in the engine behind a selector
(lane GG). What is known:

- At 12x512 the design memo modelled descents 6.5 -> ~1.2 s and the
  claim layer 1.75 -> ~2.0 s, prove 15.5 -> ~10.5 s (~1.5x) [MODEL,
  S4 §3.2].
- Measured on CPU at the 125M shapes (S6, 2026-08-29, NOISY-SHARED):
  proof bytes 2.10-2.15x SMALLER; prove **+15% slower** (12x128:
  97.1 -> 112.1 s) and commit +38% (12.9 -> 17.8 s), because the
  aggregate checks run on the CPU while the descents' kernels rode
  the GPU, and because Stage A must COMMIT extra "width planes"
  (+58% activation rings at 12x512, lane GG's finding F1 in S5's
  ledger section). The 12x512 GPU A/B was deferred; lane RR's rung 4
  runs it.
- At 8B the descents are 80-300 s of a 620-910 s prover clock, so
  the lever is worth 1.1-1.5x THERE even though it measured < 1x at
  125M. Stage A touches only the activation side; W is unchanged.

The (b) row therefore takes, at 8B on the laptop [MODEL]: descents
80-300 -> 20-40 s (the S4 §3.2 ratio); the activation-side opening
terms +58% for the committed width planes (prove-group A 84 -> 133,
transport 16 -> 25, CRS 18 -> 28, commit A 37-53 -> 50-70)
[COUNTED from GG's F1 ring growth, applied linearly]:

- W_b = W_a = 370-409 s; A_b(512) = 50-70 + 133 + 20-40 + 15-20 + 25
  + 28 = **271-316 s**; cost_b(512) = **641-725 s**; cost_b(1) =
  ~372-411 s per token — **identical to (a): Stage A does nothing
  for decode.**

The routes memo's own row for the same composition is 630-700 s
including verify (S3 §3.1); it did not carry the width-plane growth.
The two agree within their bands; this memo uses its own (newer
inputs).

### 2.4 (c) The two-tier opening + weight preprocessing

The **two-tier ("square-root") opening** (spike S4, lane FF; S5)
splits a group's rings into ~sqrt(n) blocks, commits each block
(tier 1), and runs the expensive lattice recursion only on a
sqrt-sized summary (tier 2). Per proof, the prover computes a
challenge-weighted fold over ALL the group's rings (one linear pass)
and the sqrt-sized recursion. **Weight preprocessing** (S3 §2.6
(vi-a), designed only) is the observation that for the weight group
the tier structure — the inner commitments, the CRS blocks, the tier
layout — depends only on the weights and can be cached per model;
only the fold and the recursion depend on the per-proof challenge.

**Per-model (off the clock).** The weight group's commitment (today
73-107 s of every 8B proof, §2.2) and its tier commitments. The
spike measured tier-1 + tier-2 commit at **14.59 s for 2^22 rings, 1
thread** (S5 §1). The 8B weight group is 352.3M / 4.19M = 84x that,
so ~1,230 s (20 min) of one CPU thread per model at 8B, ~4,700 s at
30B [COUNTED from MEASURED, linear scaling assumed]. Acceptable
next to calibration, which already takes minutes-to-hours per model.

**Per-proof, weight side** — the term the whole 50 tok/s question
turns on. Two sources, and they disagree by an order of magnitude:

| source | what it says about the per-proof pass over the weight rings | at the 8B weight group (x84 over 2^22; the recursion stays sqrt-sized, ~1-3.5 s) |
|---|---|---|
| the routes memo (S3 §2.1, 2026-08-23) [MODEL] | "the fold pass is ~5.0e8 ring-scalar mults over both groups = ~6.4e10 base-mults; ~90 s 1T, ~12-15 s 8T, seconds-class on the GPU GEMM path" — a streaming pass at ~1 base MAC per coefficient | weight share 71%: ~9-11 s at 8 CPU threads; **"seconds" on the GPU** [MODEL] — call it 2-10 s on the laptop GPU |
| the spike as measured (S5 §1, 2026-08-28) [MEASURED, 1T, NOISY] | rows 1.45 + v-passes 20.01 + fold 2.25 + recursion 1.73 = 25.4 s core at 2^22; the v-pass computes GENERAL ring products (that is why the spike landed at 1.10x, not 5x) | 84 x 23.7 + 3.5 = **~2,000 s at 1 thread** [COUNTED from MEASURED] |
| the redesign count (S5 C-R1, 2026-08-28) [COUNTED] | the factored "swap-order" v-pass: 2-5x on the v-pass (20.01 -> 4-10 s), composed core 11-17 s at 2^22 1T | 84 x (1.45 + 4..10 + 2.25) + 3.5 = **650-1,160 s at 1 thread**; at 8 threads [MODEL: S5 §5 notes the comparable factored passes threaded 3.5-11x] **60-330 s**; **on the GPU: never counted** |

The newer source (S5) is the measured one; this memo carries BOTH
as the ends of the (c) range — (c) with the routes constants and
(c') with the S5 constants — and names lane QQ (rungs 1, 3, 4) as
the measurement that collapses them. Note what the disagreement is
about: whether the per-proof linear pass over the weight rings can
be made a scalar streaming kernel (routes) or remains a
ring-product pass (spike). Nobody has run it on a GPU.

A floor that holds under EITHER constant: the pass must READ every
weight digit once per proof — 45 GB at 8B, 172 GB at 30B (§1.5).
That is a memory-bandwidth floor per proof (§3.4), independent of
the arithmetic.

**Per-proof, activation side under (c).** The activation group is
also served two-tier (it is the group the spike actually ran on at
2^22-2^23 rings; the 12x512 activation group is 7.85M ~ 2^23). Its
opening at 8B: the built activation share of prove-group +
transport + CRS = 84 + 16 + 18 = 118 s (§2.2); the spike measured
the two-tier core at 1.10x that -> ~107 s; the redesign's 1.6-2.5x
-> 47-74 s; the routes memo's constant -> ~5-15 s [MODEL]. Plus
commit of the activations with width planes 50-70, the Stage-A
aggregate 20-40, the claim layer 15-20 (§2.3):

- A_c(512) = 50-70 + (5..15) + 20-40 + 15-20 = **90-145 s** with the
  routes constants [MODEL]; **150-240 s** with the S5 constants
  [COUNTED from MEASURED]; A(1) + F ~ 2-3 s either way.

### 2.5 Summary: the per-proof cost model at 8B, laptop, prover clock

| design | per-model (off the clock) | W per proof | A(512) | A(1) + F | cost(512) | cost(1) = per decode token |
|---|---|---:|---:|---:|---:|---:|
| (a) built | none separable (S3 §2.6) | 370-409 [MODEL] | 250-491 [MODEL] | ~2 | 620-910 | ~372-411 |
| (b) built + Stage A | none | 370-409 | 271-316 [MODEL] | ~2 | 641-725 | ~372-411 |
| (c) two-tier + preprocessing, routes constants | ~20 min 1T CPU at 8B [COUNTED] | **2-10 [MODEL]** | 90-145 [MODEL] | 2-3 | 92-155 | **~4-13** |
| (c') same design, spike-measured constants scaled | same | **60-330 (8T CPU; GPU uncounted) [COUNTED from MEASURED]** | 150-240 | 2-3 | 210-570 | **~62-333** |

At 30B, W scales x3.81 and A x2.87 (§1.5) for every row [MODEL on
MODEL]; memory is a separate gate (§3.4).

The routes memo's compounding table gives the (c) composition at
"~105-155 s laptop" including verify (S3 §3.1, "+ (vi-a)"); this
memo's (c) row (92-155 s on the prover clock) reproduces it — the
two are the same model. The (c') row is what the same design costs
at the constants the spike actually measured. **The distance between
(c) and (c') — 10-40x on the per-proof weight side — is the largest
unknown in this memo and the reason lane QQ exists.**

## 3. The hardware factor: laptop -> desktop board -> H100, as a range

No number in this section is measured on anything but the laptop.
Every 8B and 30B wall in this repository was scaled from the laptop
by a "4-6x desktop board" factor that the decision memo (S2, route
3) introduced as [MODEL] and every later memo repeated (S3 §2.4,
§3.3 "both unmeasured"). This section says where that factor comes
from, why it is a range, and why an H100 is not simply "more".

### 3.1 What kind of work the pass is

From the measured 12x512 attribution (S1) and the kernel reports
(S14), the pass is four kinds of work:

1. **Integer ALU chains on the GPU**: the descent round kernels
   multiply in the extension field GF(q^16) as ~363-instruction
   `mad.wide.u32` chains; they run at 70-88% of a measured 1.7 G
   K-mults/s register-only ceiling on this part (S14, GPU4 §4.5).
   Compute-bound; scales with (SM count x clock). No tensor cores
   are used anywhere — the arithmetic is exact modular integer.
2. **Integer GEMM on the GPU**: the level-h blocks, int32 MACs at 74
   G MAC/s (~30% of the part's integer peak), fed by a host pack and
   an 11.7 GB/s pinned host-to-device copy (S14, GPU_REPORT). Partly
   link-bound.
3. **Streaming passes over u64 planes**: the fold, the aggregate
   zero-check (Stage A), the CRS walk, the flat-store scans.
   Memory-bandwidth-bound wherever they run.
4. **Host-side work on 8 CPU threads**: host T rings 1.1 s, host PHI
   MAC 0.9, tree-pack fill 0.75, CRS walk 0.7, transport, digits
   (S1). The conversion note (S9) puts "~half the wall" on the CPU
   at 12x512; the decision memo (S2 route 3) puts the remaining
   host-device fills at ~2 s of the 21.

So at 12x512 [MEASURED shares, this memo's grouping]: GPU-bound
~35-40%, CPU-bound ~50%, link-bound ~10%. At 8B the routes memo
argues the pass is >99% parallelizable work (S3 §2.4) — a statement
about STRUCTURE (what could run on a device), not about what is
ported today.

### 3.2 The parts, from public spec sheets [EXTERNAL, spec sheet]

| part | SMs | boost clock | SM x GHz (integer ALU proxy) | VRAM | VRAM bandwidth | host link | board power |
|---|---:|---:|---:|---:|---:|---|---:|
| RTX 4070 Laptop (AD106) — the measured part | 36 (S14 header) | 2.18 GHz spec max; at 55-70 W sustained ~1.5-2.0 [MODEL] | 54-72 | 8 GB | 256 GB/s | PCIe 4 x8; 11.7 GB/s measured (S14) | 55-70 W (S1) |
| RTX 4090 (AD102) — "one desktop board" | 128 | 2.52 | 323 | 24 GB | 1,008 GB/s | PCIe 4 x16, ~25 GB/s | 450 W (= the contract's line, S12 §4) |
| RTX 5090 (GB202) | 170 | 2.41 | 410 | 32 GB | 1,792 GB/s | PCIe 5 x16, ~50 GB/s | 575 W — OVER the contract's 450 W line |
| H100 SXM5 | 132 | 1.98 | 261 | 80 GB HBM3 | 3,350 GB/s | PCIe 5 x16 / NVLink | 700 W |
| H100 PCIe | 114 | 1.76 | 200 | 80 GB HBM2e | 2,000 GB/s | PCIe 5 x16 | 350 W |

All five parts issue 64 int32 operations per SM per clock, so SM x
GHz is the right proxy for work of kind 1 and 2. Ratios against the
laptop's 54-72:

| ratio vs the laptop | RTX 4090 | RTX 5090 | H100 SXM | H100 PCIe |
|---|---:|---:|---:|---:|
| integer compute (SM x GHz) | 4.5-6.0x | 5.7-7.6x | **3.6-4.8x** | 2.8-3.7x |
| VRAM bandwidth | 3.9x | 7.0x | **13x** | 7.8x |
| host link | ~2x | ~4x | ~4x | ~4x |
| VRAM capacity | 3x | 4x | **10x** | 10x |

The point most likely to surprise: **on scalar integer work an H100
is not faster than a 4090** — it has fewer SM-GHz. Its two real
advantages for THIS mix are memory bandwidth (3.3x a 4090) and
capacity (80 GB: the only board where the 8B weight digit store,
45 GB, is device-resident). The H100's headline numbers (tensor-core
TFLOPS) do not apply to exact modular integer arithmetic.

### 3.3 The composed factor, as a range with its reasoning

Let c, g, l be the CPU-, GPU- and link-bound fractions of the pass
wall on the laptop (0.50 / 0.375 / 0.10 at 12x512, §3.1), and k_c,
k_g, k_l the per-resource speedups of the new machine. The composed
factor is `1 / (c/k_c + g/k_g + l/k_l)` (Amdahl's law by resource).

- **Nothing more ported, same host CPU** (k_c = 1): 4090 -> 1 /
  (0.50 + 0.375/5 + 0.10/2) = **1.6x**; H100 -> 1 / (0.50 + 0.375/4
  + 0.10/4) = **1.6x**. This is the floor, and it is what the GPU
  report itself warned (S14 §4.5: "a ~2.5-3x further factor on the
  ported share, NOT on the composed pass").
- **Nothing more ported, a desktop/server host** (k_c = 2-4 from
  2-4x the threads of the laptop's 8; the 8B pass is not memory-
  bound on a 128-256 GB host): 4090 -> 1 / (0.50/3 + 0.075 + 0.05)
  = **~3.4x**; H100 (server host, k_c ~ 4) -> 1 / (0.125 + 0.094 +
  0.025) = **~4.1x**.
- **Everything device-resident** (c -> 0, l -> 0; the routes memo's
  8B structure assumption): the factor is the GPU's own ratio
  weighted by how much of the work is compute-bound (kind 1-2)
  versus bandwidth-bound (kind 3). 4090: 4-6x either way. H100: 3.6-
  4.8x if compute-bound, up to ~13x if bandwidth-bound — the
  conversion note's "5-15x" (S9) is this top case.

**The ranges this memo uses** (and the §4 table shows both ends):

| machine | factor over the laptop | low end means | high end means |
|---|---:|---|---|
| one desktop board (4090 class, <= 450 W) | **2-6x** [MODEL] | today's CPU/GPU split with a 2-3x better host | everything on the device, compute-bound |
| one H100 (SXM) | **2-8x** [MODEL] | today's split, server host | device-resident, half of the work bandwidth-bound |

The memos' "4-6x" for the board is the upper half of this range and
presupposes the port. There is no measured point anywhere in it
(S3 §3.3: "the box is busy ... no quiesced measurement exists"); the
task board's choice C (S16 §7) is the purchase/rental that would
turn one of these rows into a measurement.

### 3.4 The per-proof memory floor (matters only for decode, and only under (c))

Any design in which the prover walks every weight digit once per
proof — which includes the two-tier fold of §2.4 — has a floor set
by where the digit store lives and how fast it can be read:

| weight digit store | size | laptop (8 GB VRAM, 15 GB RAM) | RTX 4090 (24 GB, link ~25 GB/s) | RTX 5090 (32 GB, link ~50 GB/s) | H100 (80 GB, HBM 3.35 TB/s) |
|---|---:|---:|---:|---:|---:|
| 8B, one byte per digit (as built: S8 §1.2 "w0 flat i8 store" 45.1 GB) | 45 GB | does not fit either memory | streamed from host: ~1.8 s | ~0.9 s | **resident: ~13 ms** |
| 30B stand-in, one byte per digit | 172 GB | — | ~6.9 s | ~3.4 s | streamed from host: ~3.4 s |
| 30B, two bits per digit (the weight digits are sign-binary, in {-1, 0, +1} — S3 §1.1; a packed store is a DESIGN NOTE, not built) | 43 GB [MODEL] | — | ~1.7 s | ~0.9 s | **resident: ~13 ms** |

Reading for §7: at 30B a per-proof walk over the weights costs
seconds per proof on every board unless the store is both packed
and resident on an H100, where it costs ~13 ms — and 13 ms is
already 65% of the 20 ms per-token budget of a 50 tok/s target at
batch 1. Whatever the arithmetic constant turns out to be, batch-1
decode at 50 tok/s on the lattice line needs a per-proof weight-side
cost that does NOT walk the weight digits per token, or a batch of
tokens per proof.

## 4. The tokens/s table

How to read it: tokens/s = tokens per proof / prover-clock seconds
per proof (§1.1). "Prefill" is T = 512 tokens per proof; "decode" is
batch 1, one token per proof. The laptop column applies §2.5's
costs; the board and H100 columns divide by §3.3's factors (board
2-6x, H100 2-8x; for (c'), whose weight side is a CPU pass as
counted, the host factor 2-4x is used on both). The 30B columns
scale W by 3.81 and A by 2.87 (§1.5). Decode cells under (c) are
clipped at the memory floor of §3.4 (unpacked store). Every token is
an **FFN-only** token (§1.4).

Labels: the only [MEASURED] cell is the 125M anchor. Every 8B cell
is [MODEL] (no 8B proof has ever run — S16 §3.1). Every 30B cell is
[MODEL on MODEL] (the 8B model scaled by an assumed shape). Every
board or H100 cell adds the unmeasured §3 factor on top of that.

### 4.1 The anchor [MEASURED]

| shape | machine | prover clock | tokens/s (of the 125M model, FFN-only) |
|---|---|---:|---:|
| 12 layers x 512 tokens, 125M | WSL laptop, 8T + RTX 4070 Laptop, QUIET (S1) | 18.0 s (21.0 s wall incl. verify) | **28 tok/s** (24 on the wall) |

### 4.2 8B (Mistral-7B shape), proven tokens per second [MODEL]

| design | laptop, prefill T=512 | laptop, decode | one desktop board, prefill | one desktop board, decode | one H100, prefill | one H100, decode |
|---|---:|---:|---:|---:|---:|---:|
| (a) built | 0.56-0.83 | 0.0024-0.0027 | 1.1-5.0 | 0.005-0.016 | 1.1-6.6 | 0.005-0.022 |
| (b) built + Stage A | 0.71-0.80 | 0.0024-0.0027 | 1.4-4.8 | 0.005-0.016 | 1.4-6.4 | 0.005-0.022 |
| (c) two-tier + weight preprocessing, routes constants | 3.3-5.6 | 0.08-0.25 | 6.6-33 | 0.15-0.55 (floor: 1.8 s streamed store) | 6.6-43 | 0.15-2.0 |
| (c') same design, spike-measured constants, CPU weight pass | 0.9-2.4 | 0.003-0.016 | 1.8-9.7 (host 2-4x) | 0.006-0.06 | 1.8-9.7 (host 2-4x) | 0.006-0.06 |

Per-proof costs behind the cells (laptop, prover clock, s): (a)
620-910 / 372-411; (b) 641-725 / 372-411; (c) 92-155 / 4-13; (c')
210-570 / 62-333 (§2.5). The 8B pass does not fit the laptop's 15
GB (S16 §3.1); the laptop column is "if it had the memory", as in
S3 §1.3.

### 4.3 30B (the §1.3 stand-in shape), proven tokens per second [MODEL on MODEL]

| design | laptop, prefill T=512 | laptop, decode | one desktop board, prefill | one desktop board, decode | one H100, prefill | one H100, decode |
|---|---:|---:|---:|---:|---:|---:|
| (a) built | 0.17-0.24 | 0.0006-0.0007 | 0.35-1.4 | 0.0013-0.004 | 0.35-1.9 | 0.0013-0.006 |
| (b) built + Stage A | 0.21-0.23 | 0.0006-0.0007 | 0.42-1.4 | 0.0013-0.004 | 0.42-1.9 | 0.0013-0.006 |
| (c) two-tier + weight preprocessing, routes constants | 1.1-1.9 | 0.024-0.09 | 2.3-12 | 0.05-0.14 (floor: 6.9 s streamed store) | **2.3-15** | **0.05-0.3** (floor: 3.4 s streamed; 0.05-0.7 with a packed, resident store [MODEL]) |
| (c') same design, spike-measured constants, CPU weight pass | 0.26-0.78 | 0.0008-0.004 | 0.5-3.1 (host 2-4x) | 0.0016-0.017 | 0.5-3.1 (host 2-4x) | 0.0016-0.017 |

Per-proof costs behind the cells (laptop, prover clock, s): (a)
2,130-2,970 / 1,413-1,561; (b) 2,190-2,470 / 1,413-1,561; (c)
266-454 / 11-41; (c') 660-1,950 / 232-1,260. Memory: (a)/(b) at 30B
need ~265-270 GB of weight-group terms (S7) — no single board holds
them; (c) removes the level-0 CRS matrices (S3 §2.1) but must still
stream the 172 GB digit store per proof (§3.4).

### 4.4 The same cells in proven MAC/s, for the yardstick of §6

| design, workload | laptop | one desktop board | one H100 |
|---|---:|---:|---:|
| 125M, 12x512 [MEASURED, S1] | 1.4e9 (wall) / 1.6e9 (prover clock) | — | — |
| (a) 8B prefill [MODEL] | 3.2-4.7e9 | 0.6-2.8e10 | 0.6-3.7e10 |
| (c) 8B prefill [MODEL] | 1.9-3.1e10 | 0.4-1.9e11 | 0.4-2.5e11 |
| (c) 30B prefill [MODEL on MODEL] | 2.4-4.1e10 | 0.5-2.5e11 | 0.5-3.3e11 |
| (c) 30B decode [MODEL on MODEL] | 0.5-2.0e9 | 1-3e9 | 1-6e9 (1-15e9 packed store) |
| **the target: 50 tok/s at 30B** | | | **1.55e12** |
| the competitor's claim (S9) [EXTERNAL] | | | 1.6e12 (batch 1), 2.4e12 (batch 4) |

The (a) 8B rates sit above the measured 1.4e9 because the routes
memo's 8B model has the pass growing 33-47x in time for 100x the
MACs (the descents and activation terms scale x19-20, S3 §1.2);
that is the model's claim, unverified until an 8B proof runs.

### 4.5 What the table says

1. **Today, on the laptop, the built system is a ~0.6-0.8 tok/s
   system at 8B prefill and a ~0.0025 tok/s system at 8B decode**
   [MODEL from the measured 125M pass] — decode is 250x worse than
   prefill because every proof re-proves the whole weight side.
2. **Stage A does not move decode at all** and moves prefill by
   1.1-1.5x at 8B. It is an activation-side lever.
3. **The recorded design path — two-tier opening + weight
   preprocessing — at its own modelled constants gives, on one H100,
   2-15 tok/s at 30B prefill and 0.05-0.7 tok/s at 30B decode.** It
   does not reach 50 tok/s in any cell, in either workload, under
   any assumption recorded in this repository. The best cell in the
   whole table (8B prefill, one H100, routes constants) is 43 tok/s
   of an 8B FFN-only model.
4. The (c)/(c') spread — 3-5x on prefill, 15-30x on decode — is the
   unmeasured per-proof weight-side constant; lane QQ's rungs 3-4
   measure it and collapse the two rows into one.
5. Batch-1 decode at 30B is bounded below by the weight-digit walk
   (§3.4) whatever the arithmetic: on one H100 it needs a packed,
   device-resident store just to make the 20 ms/token budget
   conceivable, and then 13 of the 20 ms are spent reading.

## 5. Audit of the 2026-08-30 task-board line

The line under audit (S11, TASK_BOARD.md §0, "AS OF 2026-08-30"):

> **THE STANDING TARGET (Victor 2026-08-30): ~80 proven tokens/s per
> H100 board at 30B** — currently counted ~25-35 amortized; the
> enumerated levers (Stage-A aggregate GPU port + fold fusion
> 1.2-1.5x, pipelining 1.3x, spine amortization 1.1-1.2x) compose to
> ~65; the last ~1.3x needs an act-side opening idea.

Method: for each number, search every ledger and memo for a
derivation (the orchestrator's grep of 2026-09-02, repeated here on
2026-09-02 over PROGRESS_UPERF2.md, PROGRESS_UPERF3.md,
TASK_BOARD.md, CONTINUATION.md and the U_PERF3_* memos for
"amortized", "pipelin", "spine", "fold fusion"); then try to
reconstruct the number from recorded rows; report derived or
UNSOURCED. "~80" is Victor's target of that date, since restated as
50 (S15); it is a goal, not a claim, and is not audited.

### 5.1 "currently counted ~25-35 [tok/s] amortized" — UNSOURCED

- No ledger status section, memo table or note counts a tokens/s
  figure before this memo; the word "amortized" is defined nowhere.
  START_HERE.md §2 (S16) already says "until then no tokens/s number
  in this repository is sourced".
- Reconstruction attempt. The most favorable recorded composition is
  the routes memo's "+ (vi-a) weight-group preprocessing" row (S3
  §3.1): ~20-40 s per 8B FFN x 512-token proof on ONE DESKTOP BOARD
  [MODEL], i.e. 512 / 40 .. 512 / 20 = **13-26 tok/s of an 8B
  FFN-only model on a 4090-class board**. Its four-board row (~6-13
  s) gives 39-85 tok/s — at 8B, on four boards. Scaled to 30B by
  this memo's §1.5 factors (cost x2.9-3.8) and moved to one H100
  (0.5-1.3x a 4090 on this mix, §3.2), the one-board row becomes
  **2-15 tok/s** (§4.3). No recorded row, at 30B, on one H100,
  produces 25-35.
- Verdict: **UNSOURCED. Retracted.** The nearest recorded number is
  13-26 tok/s at 8B on one desktop board [MODEL], and 2-15 tok/s at
  30B on one H100 [MODEL on MODEL], both for 512-token prefill of an
  FFN-only statement; the batch-1 decode figure is 50-100x lower.

### 5.2 "Stage-A aggregate GPU port + fold fusion 1.2-1.5x" — UNSOURCED as stated

- What exists: the design memo models Stage A's prover factor at
  12x512 as ~1.5x [MODEL, S4 §3.2: prove 15.5 -> ~10.5 s]; this
  memo's split puts it at 1.1-1.5x at 8B (§2.3). That is the factor
  of Stage A ITSELF over the built pass on any hardware, not the
  increment of porting its checks to the GPU.
- What was measured: on CPU at 125M shapes, Stage A is 0.87x
  (prove +15%, S6) — the aggregate checks run on the CPU while the
  descents they replace ran on the GPU. The GPU port's increment
  has never been measured; that is lane RR's whole brief (S15).
- "Fold fusion" names lane DD's rung 5 (PROGRESS_UPERF3.md, DD
  status, rung 4 SCOPE DECISION): an AVX2 CPU vectorization of the
  fold's `e_red_block` reduction inside the aggregate zero-check
  prover, explicitly "GATED on EE's profile: build it only if the
  aggregate still shows folds as a top-3 term" — never built, and a
  CPU item with no GPU counterpart.
- Verdict: **UNSOURCED as a GPU-port factor. Retracted as a
  number.** The lever is real and named; its value is lane RR's
  rung-5 measurement, which "REPLACES the board's 1.2-1.5x line"
  (S15, Lane RR rung 5).

### 5.3 "pipelining 1.3x" — UNSOURCED

- No design, count or measurement of proof-level pipelining exists
  anywhere in the repository. The only "pipelined" hits are
  kernel-internal transfer overlaps in lane L's and lane J's
  round-7 status lines (PROGRESS_UPERF2.md), which are already
  inside the 21.0 s measurement.
- Structural bound (§1.2): on one board, pipelining consecutive
  proofs cannot exceed `1 / max(c, g, l)` where c, g, l are the CPU-,
  GPU- and link-bound fractions of a proof. At 12x512 that is <= 2x
  (c ~ 0.5, §3.1). At 8B the fractions are unrecorded, and if the
  pass is ported to be device-resident (the assumption under every
  4-6x board factor) then c -> 0 and the pipelining gain -> ~1x:
  **the pipelining lever and the hardware lever are the same CPU
  share counted twice.**
- Verdict: **UNSOURCED. Retracted.** Recorded in its place: a <= 2x
  bound that shrinks toward 1x as the pass is ported, and the
  measurement that would price it (lane RR rung 0: which Stage-A
  phases run on the CPU today).

### 5.4 "spine amortization 1.1-1.2x" — UNSOURCED and contradicted by the recorded count

- The "spine" is the Fiat-Shamir sequence of challenge rounds
  (each round's challenge depends on the previous round's
  transcript — the only inherently serial part of the prover). The
  routes memo counted it at 8B: ~4,659 descent rounds + ~200 claim
  rounds + 10-20 eval-proof levels at 10-100 us each = **"< 1 s
  total ... Amdahl's serial fraction is < 1%"** (S3 §2.4). Amortizing
  under 1 s of a 620-910 s proof across proofs cannot buy more than
  ~1.002x.
- The only place round overheads were a real cost is 12x512, where
  1,134 tiny CPU-tail rounds mattered (S4 §1.1) — a 125M-scale
  effect that the same memo says vanishes at 8B because every round
  body becomes e8-e9-class work.
- Verdict: **UNSOURCED and inconsistent with S3 §2.4. Retracted.**

### 5.5 "compose to ~65" — the product of the above

25-35 x (1.2-1.5) x 1.3 x (1.1-1.2) = 43-82, midpoint ~62 ≈ "~65".
The figure is the arithmetic product of an unsourced base and three
unsourced factors. **Retracted.**

### 5.6 The retraction, in one sentence

> The 2026-08-30 task-board line — "~25-35 tok/s amortized; Stage-A
> aggregate GPU port + fold fusion 1.2-1.5x, pipelining 1.3x, spine
> amortization 1.1-1.2x -> ~65" — is retracted in full: none of its
> five numbers is derived from, or consistent with, any measurement,
> count or model recorded in this repository; the nearest recorded
> row (the routes memo's most optimistic 8B composition on one
> desktop board, ~20-40 s per 512-token proof [MODEL]) gives 13-26
> tok/s of an 8B FFN-only model, whose 30B, one-H100 equivalent is
> 2-15 tok/s for prefill and under 1 tok/s for batch-1 decode
> [MODEL on MODEL]; the Stage-A-on-GPU factor is lane RR's
> measurement, the per-proof weight-side cost is lane QQ's, and no
> pipelining or spine-amortization lever exists in any design.

The task board's §0 should replace the line with a pointer to this
memo (a one-line edit for the orchestrator; TASK_BOARD.md is not in
this lane's ownership).

## 6. The competitor row on the same yardstick

The claim (S9, Attestable, blog post of 2026-08-11; no paper, no
code, no third-party reproduction as of this memo): Gemma-4-31B
INT8, **53 tok/s at batch 1** (16K context) and **77 tok/s at batch
4**, on ONE H100; proofs 4.35-7.92 MiB; CPU verification 157-648
ms; hash-based, post-quantum, 100-bit security; "all non-linear
operations in floating point, all matrix multiplications quantized
to integers", ~1.5x proving overhead from approximation. Every
number **[EXTERNAL, VENDOR-CLAIMED, UNVERIFIED]**.

On this memo's yardstick (3.1e10 MACs per token, §1.4):

| row | tokens/s | proven MAC/s | ms per token | what the statement covers | label |
|---|---:|---:|---:|---|---|
| Attestable, batch 1 | 53 | **1.6e12** | 18.9 | the full model: attention, FFN, float nonlinears (approximate), 16K context | [EXTERNAL, VENDOR-CLAIMED] |
| Attestable, batch 4 | 77 | 2.4e12 | 52 per 4-token step | same | [EXTERNAL, VENDOR-CLAIMED] |
| **the goal** | 50 | 1.55e12 | 20 | | |
| ours, measured (125M, 12x512, laptop) | 28 (of a 125M model) | 1.4e9 wall / 1.6e9 prover | 36 (of a 125M token) | FFN only, exact integer, lattice, ZK for the declared set | [MEASURED, S1] |
| ours, (a) built, 8B prefill, one H100 | 1.1-6.6 | 0.6-3.7e10 | 150-900 | FFN only | [MODEL] |
| ours, (c) routes constants, 30B prefill, one H100 | 2.3-15 | 0.5-3.3e11 | 65-430 | FFN only | [MODEL on MODEL] |
| ours, (c) routes constants, 30B decode, one H100 | 0.05-0.7 | 1-15e9 | 1,400-20,000 | FFN only | [MODEL on MODEL] |

Ratios: the claim is ~1,100x our measured rate, ~40-270x the built
pass modelled on an H100, and **~5-30x above the best cell this
repository can model for 30B prefill** — and 100-1,600x above the
best modelled batch-1 decode cell, which is the workload the claim
is stated for. Hardware-normalized (§3: an H100 is 2-8x the laptop
on this mix), the built system's algorithmic gap to the claim is
~140-550x [MODEL]; the S10 note's "~80-230x" used a 5-15x hardware
factor that §3 finds too generous for integer work.

The other columns matter too, and they cut both ways. Proof size:
theirs 4-8 MiB per token(-step); ours 1.5 MB per 512-token pass at
125M and 1.9 MB at 8B [COUNTED, S8 §1.5] — 1,000x smaller per token.
Verification: theirs 0.16-0.65 s on a CPU; ours 1.7 s at 8 threads
for 12x512 [MEASURED], ~70 s at 8 threads for 8B under the built
opening [MODEL, S3 §1.3], sub-second under the two-tier opening
[MODEL, S3 §2.1]. Guarantee class: theirs hash-based, 100-bit, with
an approximation contract on the nonlinears; ours lattice-based,
exact-integer (an uncalibrated model fails to prove, by design),
zero-knowledge for the declared private set (S16 §1, S10 §3).

**What our system would have to match.** At batch 1: the ENTIRE
per-proof cost — weight side, activation side, fixed overhead — for
3.1e10 MACs including attention, in under 19 ms on one H100. Under
any design that walks the weight digits per proof, 13 ms of that is
memory reads even in the best case (§3.4), so matching the batch-1
claim on the lattice line requires a per-proof weight-side cost
that is sublinear in the weight count — the "structurally new idea"
the two-tier redesign memo said the 5-15 s question was closed
without (S5, closing verdict). At batch 4 (multi-request): 52 ms per
4-token step, of which the weight walk is 13 ms — conceivable on the
memory side; the arithmetic must still run at ~1.6e12 proven MAC/s.

## 7. What a 50 tok/s design must have

### 7.1 The budget, on one H100

| quantity | batch-1 decode | T = 512 prefill (or a 512-request batch) |
|---|---:|---:|
| proven MAC/s required | 1.55e12 | 1.55e12 |
| time per proof | **20 ms** | **10.2 s** |
| of which, a per-proof walk over the 30B weight digits (§3.4) | 13 ms IF packed and H100-resident; 3.4 s if streamed (impossible) | 13 ms (0.1% of the budget) |
| left for everything else | **~7 ms** for 3.1e10 MACs (4.4e12 MAC/s) | ~10 s for 1.6e13 MACs (1.6e12 MAC/s) |
| activation-side cost at 30B x 512 today, routes constants, H100 [MODEL on MODEL] | — | 258-416 s laptop / 2-8 = **32-208 s** |
| activation-side gap to the budget | — | **3-20x** (5-35x at the spike-measured constants) |

The budget separates the two workloads cleanly. **Batch-1 decode at
50 tok/s is not reachable by any design that touches every weight
per proof**: the memory read alone eats 65% of the budget in the
best case, and the two-tier opening's per-proof fold is exactly such
a touch. **T = 512 prefill (or multi-request batching at hundreds of
requests) makes the weight side irrelevant** and turns the question
into the activation side's proving rate: 1.6e12 proven MAC/s on one
board, against a best modelled 0.5-3.3e11.

### 7.2 The requirements, stated as "must"

- **R1 (weight side).** Either (R1a) a per-proof weight-side cost
  sublinear in the 1.34e9 weight rings — a preprocessed structure
  whose per-proof part touches O(sqrt N) or less; the two-tier
  design's challenge fold is linear, so R1a needs an idea this
  repository does not have — or (R1b) >= ~500 tokens per proof, at
  which point a 13-50 ms weight walk is under 0.5% of the budget.
  R1b is the only path recorded here; it means the product is
  "prefill / batched proving", not "batch-1 decode".
- **R2 (activation side).** A proving rate of >= 1.6e12 proven MAC/s
  on one H100 for the activation-side statement (commit of the
  activations, their opening, the Stage-A range and lookup checks,
  the claim layer). The best modelled lattice-line figure is
  0.5-3.3e11 (§4.4, (c) 30B prefill on an H100); the gap is 3-20x
  at the routes constants and 5-35x at the spike's. Nothing in the
  recorded design space is priced to close it.
- **R3 (memory).** At 30B on one board: a weight digit store that is
  device-resident (packed to 2 bits: 43 GB [MODEL]) and an
  activation-side working set under the remaining ~35 GB — the 8B
  x 512 pass peaks at ~72 GB host-side today (S7) and the 30B
  activation group is 2.9x larger, so a streaming design over the
  token axis (S3 §2.6 (vi-b), deferred) is required, not optional.
- **R4 (statement).** Attention in the proof (X3 and beyond; S16
  §4): the FFN-only tokens of this memo are 69-78% of a real token's
  MACs and an unknown fraction of its proof cost (S3 §3.3: ~3.5x
  per layer of statement mass).
- **R5 (verifier and bytes).** Sub-second verification and
  megabyte-class proofs at 30B: the two-tier opening's verifier
  [MODEL, S3 §2.1] and the Stage-A byte drop [MEASURED 2.15x, S6]
  are the recorded path; the built opening's ~70 s at 8 threads for
  8B [MODEL] is not shippable next to a 0.2-0.6 s competitor.

### 7.3 Which measurement replaces which constant

| constant in this memo | current status | who measures it | where it lands |
|---|---|---|---|
| the per-proof weight-side opening after preprocessing (§2.4: 2-10 s vs 60-330 s at 8B on the laptop) | [MODEL] vs [COUNTED from a 1T CPU spike] — 10-40x apart | **lane QQ** rung 4 (the 12x512 weight group on the 4070, per-proof wall with the per-model part warm, vs the built GPU opening; the reopen bar is >= 5x) and rung 1's count at 8B/30B | collapses (c)/(c') into one row; decides whether the 30B H100 prefill cell is 2-15 tok/s or 0.5-3 |
| the GPU wall of the factored linear pass over the weight rings (the S5 v-pass) | never run on a GPU | **lane QQ** rung 3 | the arithmetic half of R1's per-proof cost |
| the Stage-A-on-GPU factor (§2.3: descents 80-300 -> 20-40 s at 8B; +58% width-plane rings) | [MODEL] at 8B; 0.87x measured on CPU at 125M | **lane RR** rungs 3-5 (12x128, then the 12x512 A/B: oracle vs Stage A vs Stage A + GPU) | the (b) row and the activation side of (c) |
| which phases run on the CPU today (the pipelining bound of §5.3; c in §3.3) | unrecorded at 8B | **lane RR** rung 0 | the low end of the hardware factor |
| the weight/activation split W vs A(T) at 8B (§2.2: by ring shares) | [MODEL] | **the Mac runbook M5, T-scaling leg**: layer 0 of the 8B model at T = 16 / 64 / 512 on the Mac CPU; fit wall = W + A x T/512 to the three points | the W/A columns of §2.5 become [MEASURED, MAC-BOX CPU]; the decode row of §4.2 follows directly |
| the thread factor k_c of §3.3 | [MODEL 2-4x] | Mac runbook M7 (8B thread ladder, optional) | the low end of the board/H100 factor |
| the board factor itself (2-6x / 2-8x) | [MODEL], never measured | choice C (S16 §7): a 4090/5090 or a rented H100 under the 12x512 rig, 20 warm QUIET runs | every board/H100 column |
| the 30B shape and its padding | assumed (§1.3, §1.5) | Victor (the target model) | the x3.81 / x2.87 factors |
| attention's proof cost per layer | [MODEL ~3.5x statement mass] | X3 (one attention layer at 125M) | R4 |

### 7.4 The one or two unknowns that decide the answer

1. **U1 — the per-proof weight-side constant on a GPU.** If lane QQ
   measures the factored linear pass at the routes memo's
   "seconds-class" (>= 5x the built opening at the 12x512 weight
   group, claims bit-identical), the (c) row stands and the
   lattice line is a 2-15 tok/s system at 30B prefill on one H100
   [MODEL on MODEL]. If it measures at the spike's class, the (c')
   row stands (0.5-3 tok/s) and the lattice line's one-H100 ceiling
   at 30B is low single digits in prefill and below 0.02 tok/s in
   decode. Either way the answer to "50 tok/s on the lattice line
   as designed" is no; U1 decides by how much.
2. **U2 — whether ANY lattice-line activation-side opening can run
   at ~1e12 proven MAC/s on one board.** No recorded design, count
   or measurement approaches it (best modelled 0.5-3.3e11, and that
   is [MODEL on MODEL]). No round-10 lane measures U2; it is the
   question that decides between "the lattice line at 5-15 tok/s
   for batched proving, exact and post-quantum" and "the hash-based
   line" (choice D, S16 §7), and it should be put to Victor as such
   when QQ's count lands.

Round 11 should be cut from QQ's rung-4 ratio, RR's rung-5 factor
and M5's three points, applied to §2.5 — not from any tokens/s
number, including this memo's, until those three land.

## What is not known

1. **Any 8B proof wall.** None has ever run (S16 §3.1). Every 8B
   and 30B cell in §4 is a model of a 125M measurement.
2. **The hardware factor.** No proof has run on anything but the
   laptop's RTX 4070 (55-70 W) and the Mac's CPU. Board 2-6x, H100
   2-8x are [MODEL] (§3.3).
3. **The per-proof weight-side constant** of the two-tier opening
   on a GPU (U1, §7.4): a 10-40x spread between the routes memo's
   model and the spike's measurement.
4. **The Stage-A-on-GPU factor**: measured 0.87x on CPU at 125M
   (S6), modelled 1.1-1.5x at 8B (§2.3); lane RR.
5. **The weight/activation split at 8B**: by ring shares here
   (§2.2); the Mac runbook's M5 measures it.
6. **The 30B architecture.** A Gemma-3-27B-shaped stand-in is used
   (§1.3); the real target's layer count, widths and attention
   pattern change every 30B row, and its FFN hidden (21504) is not
   a power of two (§1.5).
7. **Attention's proof cost.** The statement is FFN-only; attention
   is priced at ~3.5x per layer of statement mass [MODEL, S3 §3.3]
   and has been proven only at toy scale (S16 §4).
8. **The CPU / GPU / link split at 8B** (the pipelining bound, the
   low end of the hardware factor; RR rung 0).
9. **Memory at 30B on one board**: the 172 GB digit store (packed
   43 GB is a design note, not built) and the activation-side
   working set (the 8B pass peaks ~72 GB host-side, S7).
10. **The full-mode Stage A cost** (the F1 ruling: every lookup
    through the aggregate) at 8B: the memory recount is lane SS's
    rungs V1-V4; this memo's (b)/(c) rows use the cheaper range-only
    mode that OO's 8B projection assumes (S7).
11. **The verifier at 8B and 30B**: ~70 s at 8 threads under the
    built opening [MODEL, S3 §1.3]; sub-second under the two-tier
    opening [MODEL, S3 §2.1]; the spike measured 3.9-4.7 s at 2^22
    rings, 1 thread (S5 §1), above the sub-second bar.
12. **Whether the competitor's claim holds.** No paper, no code, no
    reproduction (S9). The yardstick comparison in §6 is against a
    number nobody outside the vendor has checked.
