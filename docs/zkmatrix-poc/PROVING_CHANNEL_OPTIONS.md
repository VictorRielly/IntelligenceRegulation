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
