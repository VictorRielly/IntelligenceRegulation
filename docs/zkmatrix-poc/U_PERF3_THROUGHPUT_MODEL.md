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

(lands with the §4 table)

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

## 3. The hardware factor: laptop -> desktop board -> H100, as a range

## 4. The tokens/s table

## 5. Audit of the 2026-08-30 task-board line

## 6. The competitor row on the same yardstick

## 7. What a 50 tok/s design must have

## What is not known
