# Proving-channel options — the lattice line vs the float/int-mix line, side by side

Status: LIVE (opened 2026-08-18 on Victor's ruling: "We can separate the
options and document them. One may be preferable to the other in
certain contexts."). Companion to CONTINUATION.md §3 (the channel
decision), PROGRESS_UPERF2.md "Decision memo (orchestrator,
2026-08-18)", AGGREGATION_LITERATURE.md (the 2026-08-11 Attestable watch
item and the 2026-08-18 conversion note), PROGRESS_UPERF3.md (the MVP
tranche on option A). Every number carries [MEASURED] / [MODEL] /
[EXTERNAL, VENDOR-CLAIMED]. This page is descriptive: it records what
each channel is, what it guarantees, what it costs, and where each is
the better fit — it does not re-open the ruling (option A first, to a
complete 8B MVP; option B evaluated after, as a parallel prototype with
an honest comparison row).

## 1. Option A — the house lattice line (Route R, zkmatrix-rs) — CHOSEN, IN BUILD

**What it is.** Commitments under MLWE/MSIS over the q31 (2^31-399) /
q46 rings (D = 128, k = 8 CRT split, K-field GF(q^16) for the descents);
the statement is the int8 forward pass of TARGET_CONTRACT §2 with
EXACT integer semantics: int8 weights/activations with power-of-two
scales, exact 27/29-bit accumulators, requantization remainders PROVEN
in range, narrowing back to int8 by PROVEN range facts, SiLU as a
frozen 256-row table with a masked lookup argument; the model identity
digest binds architecture, quantization spec, every weight commitment
and the table digest. Zero-knowledge for the declared private set
(weights, activations; modes P1/P2/P3 of ZK_GAP_OPTIONS.md); knowledge
error 2^-220 class, 128-bit-class assumptions; post-quantum (lattice).
An UNCALIBRATED model cannot be proven — the range facts fail by
design; that is a feature of the guarantee, not a limitation.

**Where it stands (2026-08-18).** The composed full-statement pass on
the 12-layer x 512-token slice of the real 125M FFN (int8 export from
frugal-lm's checkpoint): **21.0 s p50 20.9 / p95 21.1** on the reference
box (Core Ultra 9 185H, 8 threads + RTX 4070 Laptop 55-70 W), 81.5 s
CPU-only, verify 1.7 s at 8 threads (0.5 s at 3x16), artifact 1,509,911
B, peak RSS 6.7 GB [MEASURED, WSL-BOX 8T QUIET, byte-identical to the
frozen digests]; 4,811 s prove at 1 thread on the Mac before the
performance tranches (M125_PASS_REPORT / U_PERF_WAVE_REPORT 4.2). In
proven int8 matmul MAC/s: 1.4e9 on this part [MEASURED]. Every
optimization to date is differential (bit-identical proof bytes) and
the frozen freeze rows / codex-audit trail are intact.

**Projected 8B (32 x 512 x 4096 x 14336, the contract's FFN shape).**
With the current protocol ~2-8 min on a <= 450 W desktop board [MODEL:
x30-100 work, x4-6 hardware]; after the route-1 protocol change
(U_PERF3_OPENING_LAYER_DESIGN.md: Stage A ~1.35x, Stage B ~1.8-2.5x
combined) **~1-3 min [MODEL]**; verify <= 2 s at 8 threads today, at 1
thread only with Stage B's supplied-Psi_0 sumcheck (new crypto) or a
contract wording amendment ("single machine, N threads stated"). The
5-15 s headline is NOT on this line without re-architecting the lattice
opening (U_PERF3_HEADLINE_ROUTES.md, in flight); PROGRESS_UPERF3.md
builds the 8B MVP at "minutes" first.

**What it guarantees that B does not.** Exact-integer semantics (the
proof is about the integer computation, bit for bit — reproducible on
any hardware, no approximation semantics to define or audit); the
range facts as first-class proven facts; lattice (structured-lattice)
assumptions rather than hash-only; an audit trail already reviewed
(codex-audit-*). **What it costs.** Prover throughput ~2-3 orders of
magnitude below the vendor-claimed hash-based line today (Section 3);
the artifact is MB-class; the verifier is seconds-class at 1 thread on
big statements until Stage B.

## 2. Option B — the float/int-mix, hash-based line (Attestable-class) — IN BUILD (2026-09-02, round 11 lane UU)

**Status update 2026-09-02.** Victor ruled (console) to start the
comparison prototype now: round 11 lane UU builds `hashline/` — a
hash-based, small-prime-field prover/verifier (Goldilocks with a
degree-2 extension; a Ligero/Brakedown-class multilinear commitment;
the matrix-multiplication sumcheck for the three matmuls; LogUp
lookups for the SiLU table and every range/requant fact) for THE SAME
12x512 exact-int8 statement the lattice line proves in 21.0 s. The
deliverable is the [MEASURED] row in §3 below with tamper legs
rejecting, plus the honest caveats (FFN-only, no seams, hash-only
assumption class at the stated parameters). Context for the ruling:
round 10 measured every recorded lattice-line lever and none made the
proof faster than the built pass at 125M; U_PERF3_THROUGHPUT_MODEL.md
puts the lattice line at 2-15 tok/s for 30B prefill on one H100 at
best against a 50 tok/s goal. Until lane UU's row lands, everything
below in this section remains [EXTERNAL] or [MODEL].

**Lane UU's row LANDED (2026-09-02, same day).** `hashline/` proves
the SAME 12x512 exact-int8 statement (digest-identical witness, 48/48
tensor and 12/12 z sha256s reproduced) on the WSL laptop's CPU alone
in **23.0 s p50 prove (21.5 s min, 8 threads; includes all three
commitments) + 2.8 s verify, 66.8 MB proof, 1.56 GB peak RSS,
1.26e9 proven MAC/s** [MEASURED, WSL-BOX 8T CPU-ONLY NOISY-SHARED],
with seven tamper legs rejecting (flipped X, flipped W, out-of-range
remainder, wrong table entry, wrong requant, wrong z, and a tampered
layer inside the chained 12-layer transcript). Stack and parameters:
Goldilocks + degree-2 extension challenges; Ligero/Brakedown PCS at
Reed-Solomon rate 1/4 with 256 column checks and blake3 Merkle; the
matrix-multiplication sumcheck for the matmuls; LogUp with committed
helpers for the SiLU table and every range/requant fact; blake3
Fiat-Shamir. Soundness ~100-bit (proximity 2^-106, LogUp 2^-101 over
12 layers, sumchecks 2^-120, blake3 2^-128), hash-only + ROM. NOT
zero-knowledge; attention and the layer seams not proven (as the
lattice tower); X/W ranges declared (the same open M3 gap). Full
record: results/hashline_pass_12x512.md; ledger: PROGRESS_UPERF3.md
"Agent UU status". Reading: on the CPU the hash-based line is at
PARITY with the lattice line's GPU-assisted 21.0 s and ~3.5x under its
CPU-only 81.5 s, with 4.3x less memory and 44x larger proofs, after
one untuned lane-day — the proof-system difference the section above
predicted is real at 125M, though smaller than the vendor claim's
~1,000x implies at this scale and on this box. Thread scaling on the
hybrid laptop part is inverted beyond 8 threads (16T 32 s, 22T 37-39
s; not chased).

**What is publicly known [EXTERNAL, VENDOR-CLAIMED, UNVERIFIED as of
2026-08-18].** Attestable ("Proving LLMs at Scale", 2026-08-11): full
LLM inference proofs, Gemma-4-31B int8, 53 tok/s (batch 1, 16K ctx) /
77 tok/s (batch 4) on ONE H100; proof 4.35-7.92 MiB; CPU verify
157-648 ms; weights private behind a commitment; hash-based,
post-quantum, 100-bit; verbatim "we prove all non-linear operations in
floating points, we quantize all matrix multiplications to integers";
~1.5x proving overhead via approximation (per heronsec.ai). No paper,
no ePrint, no code, no third-party reproduction. Adjacent published
systems (with code): zkLLM (13B-class in ~15 min on a datacenter GPU),
Lagrange DeepProve-1 (GPT-2-class), Polyhedra zkPyTorch (Llama-3-8B
~150 s/token), zkGPT, zkAgent — 10-1,000x below the Attestable claim.
The floating-point part is what "GPUs are better at floats" refers to:
the nonlinears (softmax, norms, activations) are proven over float
arithmetic with an approximation semantics; the matmuls — the bulk of
the MACs and the whole of OUR statement today — are integer in that
line too. So the throughput difference on the matmul core is a
PROOF-SYSTEM difference (hash-based sumcheck/GKR/STARK-class prover:
O(N) small-field ops per MAC, Merkle/hash commitments), not a float
difference.

**What choosing it would mean for us.** (1) Assumption class: hash-only
(also post-quantum) at ~100-bit; the lattice commitment and the
MLWE/MSIS story go away unless kept as a second commitment. (2)
Semantics: the nonlinears become float with an approximation contract
that must be specified, proven correct as an approximation, and
audited — our exact-integer soundness story ("uncalibrated models
cannot be proven") changes in kind; the int8 matmul core could keep an
exact statement. (3) Verifier: ms-class hash verification, small
proofs — the contract's verify line is trivially met. (4) Hardware: the
prover is GPU-native by construction. (5) Cost to us: a parallel
prototype on OUR statement (the 125M FFN 12x512 with the same int8
semantics) in an existing open sumcheck/GKR framework, measured on our
GPU, is the honest comparison row (~1-2 lane-weeks [ASSUMED]); a
production line is a new engine.

## 3. The common yardstick and where each is preferable

Proven int8 matmul MAC/s (AGGREGATION_LITERATURE.md, conversion note
2026-08-18): **A = 1.4e9 [MEASURED, laptop GPU + 8T]**; the contract's
5-15 s at 8B = 1.9-5.8e11; **B (claimed) = 1.6e12 on an H100
[EXTERNAL]**. Hardware-normalized (H100 vs the 4070 Laptop, 5-15x on
this mix [MODEL]) A is ~80-230x behind B's claim algorithmically; the
route-1 protocol change closes <= ~2.5x of it; the rest is the opening
architecture (U_PERF3_HEADLINE_ROUTES.md).

**The measured B row on OUR statement (lane UU, 2026-09-02).** The same
12x512 exact-int8 FFN statement, the same witness, the same box:

| channel | device | prove (incl. commit) | verify | proof | peak RSS | proven MAC/s | assumptions / ZK | label |
|---|---|---:|---:|---:|---:|---:|---|---|
| A lattice (zkmatrix-rs, 2026-08-18 reference) | WSL laptop, 8T + RTX 4070 Laptop | 18.0 s (2.5 + 15.5); 21.0 s total wall | 1.7 s | 1.51 MB | 6.7 GB | 1.4e9 | MLWE/MSIS, 2^-220, ZK yes | [MEASURED, QUIET] |
| A lattice, CPU only | WSL laptop, 8T | ~80 s (81.5 s total) | ~1.7 s | 1.51 MB | 6.7 GB | ~3.6e8 | same | [MEASURED] |
| **B hash-based (`hashline/`, this lane)** | **WSL laptop, 8T CPU only** | **23.0 s p50 (21.5-23.7 s over 4 runs)** | **2.8 s** | **66.8 MB** | **1.56 GB** | **1.26e9 (1.22-1.35e9)** | **hash-only + ROM, ~100-bit (2^-101..106; Goldilocks, deg-2 ext., RS rate 1/4, Q = 256), ZK NO** | **[MEASURED, NOISY-SHARED]** |
| B hash-based, 22T | WSL laptop, 22T CPU only | 37-39 s | 8 s | 66.8 MB | 1.57 GB | 7.4-7.8e8 | same | [MEASURED, NOISY-SHARED] |
| **B hash-based ON THE GPU (`hashline/` `--features gpu-cuda`, `HL_GPU=1`; lane XX, 2026-09-02)** | **WSL laptop, 8T + RTX 4070 Laptop (55-70 W)** | **3.40 s p50 (3.38-3.49 s over 4 runs)** | **0.42 s** | **66.8 MB (BYTE-IDENTICAL to the CPU proof: sha256 50cf7bdf..)** | **0.78 GB (+ 2.43 GB VRAM)** | **8.5e9 (8.3-8.6e9)** | **same as the CPU row (same protocol, same parameters, ZK NO)** | **[MEASURED, NOISY-SHARED]** |
| B hash-based, CPU after XX's byte-identical fixes (eq_table / group_claims) | WSL laptop, 8T CPU only | 20.4 s p50 (17.4-20.9 s) | 0.3-0.7 s | 66.8 MB | 1.56 GB | 1.4e9 | same | [MEASURED, NOISY-SHARED] |
| **B hash-based `--zk` ON THE GPU (mode P1: activations private, weights public; lane ZA, 2026-09-02)** | **WSL laptop, 8T + RTX 4070 Laptop** | **3.93 s p50 (3.87-4.10 s over 4 runs; the non-zk prover on the same tree 2.46 s)** | **0.38 s** | **87.2 MB (+30.5%; sha256 021485e4.. at seed 1, CPU == GPU)** | **0.90 GB (+ 3.03 GB VRAM)** | **7.4e9** | **same soundness class (RS(n+Q, 4n) on a coset: 2^-105.6 at Q = 256); ZK for the activations: pads + mask rows on A/H, masked sumchecks (CFS) with the last-round extension, committed multiplicities, salted leaves; weights public** | **[MEASURED, NOISY-SHARED]** |
| B hash-based `--zk`, CPU only (lane ZA) | WSL laptop, 8T CPU only | 16.55 s p50 (16.5-16.7 s; non-zk 14.78 s on the same tree) | 0.45 s | 87.2 MB | 1.68 GB | 1.75e9 | same | [MEASURED, NOISY-SHARED] |
| **B hash-based `--zk --profile v3` — ZERO KNOWLEDGE ON THE WIDENED (8B-semantics) STATEMENT, GPU (mode P1; lane AD, 2026-09-03)** | **WSL laptop, 8T + RTX 4070 Laptop** | **5.63 s p50 of 3 (4.63-6.15 s; the non-zk v3 prover on the same tree in the same session 2.75 s, the ZK-v2 prover 3.98 s)** | **0.54 s** | **87.7 MB (+23.9% over non-zk v3; only +0.54% over ZK-v2; sha256 40eb5479.. at seed 1, CPU == GPU)** | **0.53 GB (+ 4.44 GB VRAM)** | **5.15e9** | **ZA's mode-P1 ZK form applied to ZB's v3 objects: multi-row committed multiplicity tables (the 2^16 INT16 class, the four balanced-remainder windows), the table zero-check over max(log n, 16) variables with the public prod(1-rho_j) coefficient; same soundness class (RS(n+Q, 4n) on a coset, 2^-105.6 at Q = 256); weights public** | **[MEASURED, NOISY-SHARED: three other lanes on the box, load average 5-21]** |
| B hash-based `--zk --profile v3`, CPU only (lane AD) | WSL laptop, 8T CPU only | 18.41 s p50 of 3 (17.87-18.64 s; non-zk v3 15.76 s and ZK-v2 17.42 s on the same tree, same session) | 0.43 s | 87.7 MB | 1.27 GB | 1.58e9 | same | [MEASURED, NOISY-SHARED] |

| **B hash-based, THE 8B ROW: Mistral-7B 32 x 512 x 4096 x 14336, `--profile v3` (2026-09-03)** | **WSL laptop, 8T CPU only** | **510.4 s (incl. the 225 s weight commitments)** | **1.21 s** | **1,234.9 MB** | **13.99 GB** | **5.66e9** | hash-only + ROM ~100-bit; ZK NO (the `--zk` form exists for v2 only today) | **[MEASURED, NOISY-SHARED] — the first full 8B FFN proof in this repository; the lattice line's 8B row is still [MODEL] (never run)** |
| **B hash-based, ONE 8B-WIDTH LAYER IN ZERO KNOWLEDGE: Mistral-7B layer 0, 512 x 4096 x 14336, `--zk --profile v3` (lane AD, 2026-09-03)** | **WSL laptop, 8T CPU only** | **15.73 s p50 of 3 (15.14-18.67 s; the same layer non-zk 15.02 s p50 = a +4.7% ZK surcharge)** | **0.056 s** | **40.19 MB (non-zk 38.69 MB: +3.9%)** | **13.29 GB (non-zk 13.17 GB: +0.9%)** | **1.53e9** | mode P1 (inputs and activations private, weights public), the v3 statement; hash-only + ROM ~100-bit | **[MEASURED, NOISY-SHARED] — the ZK form now runs the 8B statement; the 32 x 512 pass in mode P1 models to ~534 s / ~1,283 MB [MODEL, this ratio x 32]** |
| **B hash-based, THE 8B ROW ON THE GPU: the same Mistral-7B 32 x 512 statement, `--features gpu-cuda` + `HL_GPU=1`, chunked weight commitments + the per-model weight cache (lane AC, 2026-09-03)** | **WSL laptop, 8T + RTX 4070 Laptop (55-70 W)** | **175.1 s cold cache / 193.3 s warm (the warm run shared the box; per-layer 5.472 s mean, +/-3.5% over the 32 layers)** | **1.09 s** | **1,234.9 MB (BYTE-IDENTICAL to the CPU proof AND to the cached form: sha256 dc980e81..)** | **5.33 GB (+ 4,175 MB VRAM of the part's 8,188)** | **1.65e10** | same as the CPU row (same protocol, same parameters, ZK NO) | **[MEASURED, NOISY-SHARED] — 2.92x the CPU row; the first 8B proof on a GPU on either line. The 8 GB part no longer bounds the model width: every commitment is chunked, nothing is resident** |
| **B hash-based, THE 8B ROW ON THE GPU WITH SHAPE-GENERAL KERNELS: the same Mistral-7B 32 x 512 statement, `HL_GPU=1`, the zero-check and LogUp-helper kernels looping over blocks (lane AH, 2026-09-03)** | **WSL laptop, 8T + RTX 4070 Laptop (55-70 W)** | **95.5 s / 104.4 s (two cold-cache runs; the 8.9 s spread is `commit W` on a page-cache-loaded box — the phases this lane moved reproduced to three digits)** | **1.16 s** | **1,234.9 MB (STILL BYTE-IDENTICAL: sha256 dc980e81.., the same digest as the CPU pass and AC's GPU pass)** | **3.80 GB (+ 5,651 MB VRAM: +1.48 GB of zero-check tables that the HOST used to build)** | **3.02e10** | same as the CPU row (same protocol, same parameters, ZK NO) | **[MEASURED] — 5.35x the CPU row and 1.83x AC's GPU row; the 44% host share is gone (zcF 46.6 -> 4.6 s, zcD 7.5 -> 0.8, helpers+H 35.2 -> 5.4). 5.36 tok/s at 8B prefill: INSIDE lane YY's modelled 5.2-16 band at its low end** |

**THE FULL-LAYER ROWS (lane AG, 2026-09-03): the statement stops being
FFN-only.** Every row above proves the feed-forward half of each layer,
with each layer's input committed afresh. These rows prove WHOLE layers —
attention, both RMSNorms, the residual stream and the FFN — and, in the
pass row, a whole model with the layer seams proven (layer l's output IS
layer l+1's input). Same box, same protocol, same parameters, CPU only,
NOT zero-knowledge. Full record: results/hashline_attn_fulllayer.md.

| channel | device | prove (incl. commit) | verify | proof | peak RSS | proven MAC/s | assumptions / ZK | label |
|---|---|---:|---:|---:|---:|---:|---|---|
| **B hash-based, ONE FULL 125M LAYER (attention + norms + residual + FFN + the seam), T = 512** | WSL laptop, 8T CPU only | **10.12 s** (the FFN-only layer on the same tree 1.65 s: **6.1x**) | 0.23 s | 33.2 MB (FFN-only 5.90) | 5.10 GB (FFN-only 1.12) | 8.6e8 | hash-only + ROM ~100-bit; ZK NO | [MEASURED, NOISY-SHARED] — 12 tamper legs reject, including the seam-only ones |
| **B hash-based, THE 12-LAYER 125M FULL-MODEL PASS, seams bound, 12 x 512** | **WSL laptop, 8T CPU only** | **94.54 s** (the FFN-only pass on the same tree 16.01 s: **5.9x**) | **2.03 s** | **404.3 MB** (FFN-only 70.8) | **6.56 GB** | **4.60e8** | same | **[MEASURED, NOISY-SHARED] — the first proof in this repository that covers whole layers of a whole model; PROOF sha256 c91f8713..** |
| **the same pass WITH THE CLAIM FOLD (lane AK, round 14) — now the default** | WSL laptop, 8T CPU only | 107.63 s (**+7.1%**) | **0.83 s** (**-69%**) | **282.2 MB** (**-30.2%**) | 6.44 GB | 4.04e8 | same | [MEASURED, NOISY-SHARED] — PROOF sha256 2d5791ff..; `HL_NO_FOLD=1` still reproduces c91f8713.. byte for byte, so the row above stays checkable. One 125M layer at T=512: 33,234,332 -> 23,539,100 B (**-29.2%**, attention half **-35.5%**); one Mistral layer at T=16: 48,478,456 -> 42,977,736 B (-11.3%, attention half -24%) |
| **B hash-based, ONE FULL MISTRAL-7B LAYER (int24 residual class), T = 16** | WSL laptop, 8T CPU only | **12.91 s** (the FFN-only layer on the same tree 11.03 s: **1.17x**) | 0.11 s | 48.5 MB (FFN-only 25.9) | 10.08 GB (FFN-only 7.48) | 2.7e8 | same | [MEASURED, NOISY-SHARED] — 10/10 tamper legs reject |
| B hash-based, ONE FULL MISTRAL-7B LAYER, T = 64 | WSL laptop, 8T CPU only | 14.27 s (FFN-only 8.86 s: 1.61x) | 0.13 s | 52.8 MB | 11.24 GB | 9.8e8 | same | [MEASURED, NOISY-SHARED] |

The full-layer surcharge SHRINKS with model width (6.1x at 125M, 1.17x at
8B width and T = 16) and GROWS with context (1.61x at 8B width and
T = 64), because attention's six committed T x T planes per head are
quadratic in T while the weight commitments that dominate a wide model
are constant in it. The 32-layer 8B full-model pass is NOT measured (its
FFN-only row alone peaks at 14.0 GB on this 15 GB box). What is still
outside the statement, on every row: the embedding gather, the final norm
and the LM head, and the KV cache / decode regime (the statement is
prefill-only).

**The compact-PCS rows (lane AF, 2026-09-03): the proof-size lever.**
The same statements, the same witnesses, the same box; only the
polynomial commitment changes, behind `--pcs compact`. The default
`--pcs ligero` path stays byte-identical (all three gates green). The
construction is BaseFold-class [EXTERNAL, ePrint 2023/1705]: a batched
evaluation sumcheck over all of a layer's claims on W, A and H at once,
whose challenges drive a FRI fold of the RS codeword; `inv_rate 4`,
`Q = 157` at the unique-decoding radius. Full record:
results/hashline_compact_12x512.md.

| channel | device | prove (incl. commit) | verify | proof | peak RSS | proven MAC/s | assumptions / ZK | label |
|---|---|---:|---:|---:|---:|---:|---|---|
| **B hash-based, `--pcs compact`, 12x512 v2** | WSL laptop, 8T CPU only | **28.76 s** (Ligero 15.40 s on the same tree) | **0.01 s** (Ligero 0.30 s) | **13.5 MB (13,487,744 B; 4.96x smaller; sha256 f84432ea..)** | 1.78 GB | 1.01e9 | hash-only + ROM; total error **2^-98.2** (query `(5/8)^157 = 2^-106.45`, fold/batching `(k+p) L_0/|F_p2|`); **ZK NO** (`--zk` refused) | [MEASURED, NOISY-SHARED] |
| B hash-based, `--pcs compact`, 12x512 v3 | WSL laptop, 8T CPU only | 29.92 s (Ligero 16.48 s) | 0.03 s | 17.4 MB (17,400,900 B; 4.07x smaller; sha256 621c2633..) | 1.80 GB | 9.7e8 | same | [MEASURED, NOISY-SHARED] |
| B hash-based, `--pcs compact --pcs-inv-rate 8`, 12x512 v2 | WSL laptop, 8T CPU only | 47.93 s | 0.02 s | 11.5 MB (Q = 128, `(9/16)^128 = 2^-106.2`) | — | 6.0e8 | same | [MEASURED, NOISY-SHARED] — measured and NOT recommended: -15% bytes for +51% prove |
| **B hash-based, `--pcs compact`, ONE Mistral-7B layer at T=512** | WSL laptop, 8T CPU only | **67.59 s** (Ligero 15.50 s) | **0.010 s** (Ligero 0.041 s) | **1.94 MB (1,940,684 B) vs 38.7 MB — 19.94x smaller** | 13.92 GB (Ligero 13.17) | — | same | [MEASURED, NOISY-SHARED] |
| **B hash-based, `--pcs compact`, THE 8B PROJECTION: 32 x 512** | WSL laptop, 8T CPU only | ~2,163 s (4.24x the 510.4 s Ligero row) | ~0.3 s | **~62.1 MB vs 1,234.9 MB — 19.9x smaller** | ~13.9 GB | — | same | **[COUNTED] from the MEASURED layer above (which matches the measured pass's per-layer average to 0.25%)** |

Reading these rows. **The per-proof bytes leave the square-root class.**
At 125M the compact form buys 4-5x; at 8B it buys **19.9x — 1.23 GB
becomes ~62 MB** — because the Ligero opening grows as `sqrt(N)` while
the compact opening grows logarithmically (four more Merkle levels per
tree from `2^23` to `2^27`, and nothing else). A second effect drives
the 125M row: the compact opening's size does not depend on the claim
count at all (measured alone: identical bytes for 1 claim and for 8,
where Ligero goes 659 KB -> 2.49 MB), and a layer here has 37 claims
across three commitments. The verifier gets 10-15x FASTER (`Q = 157`
walks of ~30 hashes, no NTT).

What it costs, stated plainly. **The prover is 1.8-2.1x at 125M and
4.36x at 8B, against the x0.94-1.4 that
`U_PERF3_ROUTE_B_THROUGHPUT.md` §5 counted for this trade** — outside
the count. The commit is ~2x slower structurally (one `4N log 4N`
codeword plus a Mobius pass, against Ligero's independent `2^14` rows);
the opening is 10x slower because it IS a full sumcheck over the
combined table. The soundness total is `2^-98.2` at 125M and `2^-95.1`
at 8B — 3 to 11 bits BELOW the Ligero form's `2^-106`, recoverable by a
bigger field or smaller pieces, not by more queries. And there is no
GPU code for this PCS (the record lists the four kernels a port needs).

The one lever left, counted not measured: a **Merkle cap** would remove
a net 29% of the bytes at zero soundness and zero prover cost —
**13.5 MB -> ~9.6 MB at 125M and 62 MB -> ~44 MB at 8B [COUNTED]** —
because ~half the opening is path digests (110 levels x 32 B across ~10
trees, times 157 queries). Not implemented.

ZK: the compact form is NOT hiding and `--pcs compact --zk` is refused
rather than answered. Lane ZA's pads and mask rows are Ligero-LAYOUT
devices and do not transfer (there are no rows, and no systematic
positions); ZA's CFS-masked sumchecks, the last-round extension, salted
leaves and committed multiplicities all do. A ZK-compact form needs
randomness in extra multilinear VARIABLES (equivalently one extra
random piece in the batch) rather than pad rows, so that the folded
object stays a multilinear encoding and the FRI still closes — the
specification is in results/hashline_compact_12x512.md, "THE ZK
INTERACTION".

Caveats on the B row (all stated in results/hashline_pass_12x512.md):
FFN-only, no attention, no layer seams (X_l committed fresh, as the
lattice tower); X and weight ranges declared, not range-proven (the
same open M3 gap on both lines); the prover clock includes the three
per-layer commitments (weights recommitted every proof — a
per-model preprocessing would remove the 2.2 s "commit W" share);
the witness derivation (0.9-1.5 s) is outside the clock; sqrt-size
proofs by construction (a FRI/STIR-class PCS would trade prover time
for ~100s of KB); untuned single-lane-day Rust with thread scaling
inverted beyond 8T on the hybrid laptop part; no GPU code. The proven
MAC/s row is a CPU number: the lattice line's 1.4e9 needed the GPU
for its 21.0 s, and its CPU-only figure is ~3.6e8.
**The B row's tokens/s model** (lane YY, 2026-09-02): the 8B / 30B
per-proof anatomy, the hardware range, the ZK surcharge (P1 +2-8%;
P2/P3 need a per-proof weight re-commit) and the proof-size lever are
in `U_PERF3_ROUTE_B_THROUGHPUT.md`, on lane TT's yardstick.

**Lane XX's GPU row LANDED (2026-09-02, same day).** The same
`hashline/` prover behind a `gpu-cuda` feature and an `HL_GPU=1`
toggle: the RS encoding (batched row NTTs), the blake3 Merkle leaves,
the two zero-check sumchecks (tables built on the device from the
resident commitment data), the LogUp helper columns, the evaluation
claims and the openings' row-combinations run on the RTX 4070 Laptop;
the transcript, the matmul folds and their 2^8 / 2^11 sumchecks, the
Merkle levels and the claim bookkeeping stay on the host. The proof
bytes are byte-identical to the CPU prover's (the transcript is
deterministic and every kernel computes the canonical value of the
same field quantity; asserted by sha256 of the written proof, CPU vs
GPU, at 3x16 and 12x512 on every rung). Measured: **3.40 s p50 prove
+ 0.42 s verify at 12x512, 8.5e9 proven MAC/s — 6.1x the lattice
line's 1.4e9 on the same device, inside the contract's 5-15 s band at
125M**, 0.78 GB RSS + 2.43 GB VRAM. It misses UU's [MODEL] 1.5-2.5 s:
~1.5 s of the 3.4 s is device time, ~1.9 s is host work around the
device (witness planes to field elements + upload, the matmul folds,
Merkle levels, transcript/claim bookkeeping, per-round syncs) and the
NTT runs well under the part's ceiling — engineering items with
known, byte-preserving fixes, none applied. Two byte-identical CPU
fixes found on the way (rayon regions in `eq_table`, per-group column
weights in `group_claims`) moved the CPU prover to 17.4-20.9 s and
the CPU verifier to 0.3-0.7 s; UU's 23.0 s row stands as the untuned
record. Full record: results/hashline_gpu_12x512.md; ledger:
PROGRESS_UPERF3.md "Agent XX status". The 30B / H100 tokens/s
question is lane YY's model; this row replaces its "laptop GPU
[MODEL until XX]" constant with a measurement.

**Lane ZA's ZERO-KNOWLEDGE row LANDED (2026-09-02, same day).** The
same `hashline/` prover behind `--zk --seed N`, mode P1 (inputs and
activations private, weights public), byte-identical CPU vs GPU
under the same seed (sha256 021485e4.. at 12x512, f9509b9d.. at
3x16; the non-zk path untouched at 50cf7bdf..). What is now HIDDEN:
the opened columns of A and H (256 random pad symbols per row, the
rows evaluated on a coset so no systematic position is ever opened),
every clear row-combination vector (one fresh mask row per private
table and opening point, plus a proximity mask; asserted at every
site at run time), the multiplicity tables (committed in A; their
LogUp table side a committed helper of H; the identity one value-0
sum claim masked by a proven zero-sum row — no histogram, no helper
sum sent), every sumcheck's round messages (a committed
Chiesa-Forbes-Spooner masking polynomial per sumcheck, opened from a
small per-layer Ligero-form mask commitment by the product-form
linear test), every private terminal evaluation and matmul claimed
sum (sent masked through a last-round extension of the sumcheck —
the verifier never sees an evaluation of the activations), and the
Merkle leaves (salted). STILL REVEALED: the weights and the W
opening (public by the mode), shapes, shifts, the table digest, the
uniform masked values. A full simulator proof would add: the
composition of the 12 chained layers under one Fiat-Shamir
transcript (the per-object uniformity is what is established, in
code, by the uniformity test — chi-square of the opened symbols and
clear vectors against uniform, two witnesses indistinguishable — and
by the site assertion), the random-oracle programming for the salted
leaves and the derived challenges, and the statistical distance
bookkeeping of the 2^-64-biased field draws. Two places where the
throughput memo's section-4.2 sketch does not close were replaced
(the mask row's <u, c>; the mask polynomial's own ZK opening); the
memo's [COUNTED] +2-8% prover / +1-8% bytes for P1 became, as built,
**+60% prover / +30% bytes / +0.12 s verifier on the GPU (3.93 s vs
2.46 s) and +12% / +30% / +0.2 s on the CPU** — the count assumed
the masked objects ride inside work already paid; the built form
pays one mask row per (table, point), the matmul terminals as their
own groups, the mask commitment and the host-side randomness;
byte-preserving levers (the DIF/DIT NTT for the ZK encode, the table
zero-check on the device, folding the matmul terminals back into the
zero-checks) are listed, not applied. The 7 tamper legs reject under
`--zk` on both provers. Full record: results/hashline_zk_12x512.md;
ledger: PROGRESS_UPERF3.md "Agent ZA status". Mode P2/P3 (private
weights) is NOT this row: the W commitment stays as built
(U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md).

**Lane AC's 8B GPU row LANDED (2026-09-03).** Two additions to the
`hashline/` prover, both byte-preserving: a CHUNKED device commitment
(the encoded matrix is built and blake3-hashed in 1024-row chunks with
the per-column CV stack carried across launches, so a 5.4 GB encoding
that `HL_GPU=1` used to DECLINE on this 8 GB part is never resident;
the 12x512 shapes stay on lane XX's resident path clock for clock), and
a per-model WEIGHT CACHE behind `--wcache DIR` (each layer's W Merkle
tree persisted under a blake3 key over the actual int8 planes and
re-verified level by level on load; a tampered W cannot reuse an honest
tree). Measured on the same 32 x 512 Mistral statement: **PROVE 175.1 s
against the CPU row's 510.4 (2.92x), 5.33 GB RSS against 13.99, 4,175
MB of VRAM (51% of the part), 1.65e10 proven MAC/s, verify 1.09 s** —
and the 1.23 GB proof is ONE sha256 (dc980e81..) across the uncached
CPU pass, the GPU cold-cache pass and the GPU warm-cache pass. The
cache removes 9.0 s of the GPU prove and ~67 s of the CPU prove and no
more: the Q = 256 opened columns are drawn after the root is absorbed,
so the Reed-Solomon re-encoding is paid on every proof (~176 s of the
CPU's 225 s weight phase). **The speedup is 2.92x, not the 5-15x lane
YY's model assumes for this part** (U_PERF3_ROUTE_B_THROUGHPUT.md
section 6.2 predicted 5.2-16 tok/s at 8B prefill; measured 2.92 tok/s,
1.8x below the band — its laptop-CPU cell, 1.0 tok/s, was exact). The
missing factor is located, not hypothesised: 76 s of the 175 (44%) are
the two zero-checks and the LogUp helper columns running on the HOST,
because lane ZB's `dev_shape` gate keeps lane XX's kernels — templated
on 13/15 tables — to the 125M block shape while Mistral's F-side check
has 73 tables. A block-looping kernel takes the pass to ~105-125 s
(4.1-4.9x) [MODEL] without changing a byte. Full record:
results/hashline_8b_gpu.md; ledger: PROGRESS_UPERF3.md "Agent AC
status".

**Lane AH BUILT THAT KERNEL, and it beat its own model (2026-09-03).**
The zero-check and LogUp-helper kernels now LOOP OVER BLOCKS instead of
being compiled for one block shape: both zero-check polynomials are
`eq_t*ZC + eq_a*F_a + eq_b*F_b` with `ZC / F_a / F_b` summed over
blocks, each term reading only its own block's tables, so one block's
`cur`/`dif` live in registers and the register footprint stops
depending on the block count. With the spec lists in `layer.rs` looping
too, and the two zero-check table buffers RESERVED through the device
pool before the helper columns leave the host (a decline after that
point has no host tables to fall back to), the `dev_shape` gate accepts
Mistral's (nb_f, nb_d) = (7, 1). **Measured on the same 32 x 512
statement: PROVE 95.5 s (a second cold run on a page-cache-loaded box:
104.4 s) against AC's 175.1 and the CPU's 510.4 — 1.83x and 5.35x — at
3.80 GB of RSS, 5,651 MB of VRAM, 3.02e10 proven MAC/s, verify 1.16 s,
and the proof is still the one sha256 dc980e81..** The 44% host share
is zero: zero-check F 46.6 -> 4.6 s, zero-check D 7.5 -> 0.8 s, helpers
+ commit H 35.2 -> 5.4 s over the 32 layers, and 12.3 GB less is
uploaded per pass because the H columns are no longer built on the host.
At the 125M shape the general kernels cost nothing measurable against
the templated ones (0.327 / 0.085 s vs 0.338 / 0.095 s), and all four
byte gates are green on both binaries. The same lane put the ZK TABLE
zero-check on the device (lane AD's 20% item): that phase 0.700 ->
0.322 s and the 12x512 GPU ZK prove 4.56 -> 4.16 s, proof `40eb5479..`
unchanged, 8/8 tamper legs still rejecting. **Against lane YY's model
(U_PERF3_ROUTE_B_THROUGHPUT.md section 6.2, 5.2-16 tok/s at 8B
prefill): measured 5.36 tok/s (AC: 2.92) — the band's low end reached,
and the remaining distance to its upper end is now entirely the witness
marshalling (plane -> Fp conversion + pageable upload), the encode NTT,
the opening's re-encode and the Merkle/serialization of a 1.23 GB
proof, none of them a shape problem.** Full record:
results/hashline_gpu_shapegen.md; ledger: PROGRESS_UPERF3.md "Agent AH
status".

**Lane AD JOINED THE TWO (2026-09-03): zero knowledge on the 8B
semantics.** Until this rung the two round-11 results were about
DIFFERENT statements — the 8B proof ran lane ZB's widened `v3`
statement, and lane ZA's zero-knowledge form existed for the older
`v2` statement only. `--zk --profile v3` is one statement: ZA's five
mode-P1 constructions (Ligero-ZK commitments with per-row pads on a
coset and salted leaves, one mask row per private table per opening
point, CFS-masked sumchecks with the last-round extension, a per-layer
mask commitment opened by the product-form linear test, committed
multiplicities) applied to every v3 object (the block-structured
planes, the int16-out activation member, the 2^16-row INT16 class, the
four balanced-remainder windows, the round-nearest requant identities,
negative shifts). One construction had to be added: a multiplicity
table can now be LARGER than a commitment row — the INT16 class is
2^16 rows against n = 2^14, and a remainder window reaches 2^15 — so a
slot occupies 2^log_size / n consecutive rows and the table zero-check
runs over max(log n, 16) variables with every slot zero-extended and
its opened claim carrying the public coefficient prod_{j<k}(1 - rho_j).
Measured at 12 x 512: **18.41 s CPU / 5.63 s GPU, 87.7 MB, sha256
40eb5479.. byte-identical CPU vs GPU at seed 1**, ACCEPT, and ZB's
**eight** v3 tamper legs all REJECT under `--zk` on both provers at
T = 512 — at layer 0 and at layer 3, the negative-shift branch — plus
the pass-level leg in the 12-layer chained transcript. Against the
same tree in the same session, hiding the activations costs **+16.8%
CPU prover, +23.9% bytes** on the v3 statement (v2's were +14.9% /
+30.5%), and the widened semantics cost the ZK form almost nothing
over ZK-v2: **+5.7% CPU and +0.54% bytes**. The GPU is the one
outlier (+105% over non-zk v3) and one phase explains it: the table
zero-check still runs ON THE HOST, and at 2^16 variables it is 1.14 s,
20% of the GPU prover and +0.90 s of the +1.65 s that zk-v3 costs over
zk-v2 — porting it to lane XX's device kernels is a known,
byte-preserving fix that was listed by ZA and is still not applied.
**And the row that matters for the product: ONE Mistral-7B layer at
T = 512 under `--zk --profile v3` ACCEPTS on this laptop in 15.73 s
against 15.02 s for the same layer in the clear — a +4.7% prover,
+3.9% byte and +0.9% memory surcharge at 8B width**, back INSIDE
U_PERF3_ROUTE_B_THROUGHPUT.md's [COUNTED] +2-8% band that the 125M
measurement had blown through. The reason is structural: mode P1
leaves the WEIGHTS public, and as a model widens the prover and the
proof are dominated by the weight commitment and its column openings,
which the ZK form does not touch — so **the P1 surcharge shrinks as
the model grows**. The 32 x 512 8B pass in mode P1 therefore models to
~534 s / ~1,283 MB [MODEL, the one-layer ratio x 32] against the
measured 510.4 s / 1,234.9 MB in the clear. `HL_GPU=1` at the 8B shape
still declines the 5.4 GB weight commitment (cuMemAlloc OOM on the 8 GB
part) and falls back to the host for W while the activation side runs
on the device: composing lane AC's chunked weight encoding with this
ZK path is the untaken measurement. What is STILL REVEALED, plainly:
the weights and the whole W opening (the mode), the shapes and block
structure, the four signed shifts — which publish the remainder
windows' sizes — the table digests, and the uniform masked values;
attention, the norms, the embeddings, the head and the layer seams are
outside the statement entirely (lane AE). ZA's simulator caveat is
inherited unchanged. Full record: results/hashline_zk_v3_12x512.md;
ledger: PROGRESS_UPERF3.md "Agent AD status".

| Context | Better fit | Why |
|---|---|---|
| Regulatory / audit-grade attestation of a frozen model (what was computed, exactly, on any hardware) | **A** | exact-integer semantics, proven range facts, reproducible bit for bit; minutes per proof are acceptable in audit workflows |
| Provenance / compliance proofs produced offline or in batch (training-step audits, model-identity proofs, per-deployment declarations) | **A** | latency is not the constraint; the guarantee class is |
| Small/medium models, edge, or CPU-only verifiers with a lattice-assumption preference | **A** | 125M-class in seconds today; the verifier is a plain CPU program |
| Interactive inference attestation at frontier scale (per-token, per-request, seconds) | **B** | prover throughput ~3 orders of magnitude higher (claimed); ms verify; GPU-native |
| Full-transformer statements with float nonlinears where an approximation contract is acceptable | **B** | the nonlinears are native there; ours are exact tables (int8 SiLU) and attention is a Phase-4 wiring item |
| Both guarantees wanted | **A + B** | B as the fast channel, A as the audit channel over the SAME committed int8 weights and the same declared statement — the weight commitment and the model-identity digest can be shared [ASSUMED]; a mismatch between the two proofs is itself an audit signal |

Ruling of record (Victor, 2026-08-18): A first — a complete 8B FFN MVP
even at 1-3 minutes, the route-1 protocol work, and the creative search
for the headline within A; B evaluated after A is complete, kept
separate, documented here as it becomes measurable. Update this page
when either column moves (a measured 8B row for A; a paper/code drop
or our own comparison prototype for B).
