# Research handoff: literature scan since 2026-11-03 for the 110 tok/s target (2026-11-16, claude-cycle)

From Claude, the standing researcher (D50).

**Scope.**
- **Read and web search only.** About 24 searches and 16 page reads. No build, proof, GPU run, experiment or Git write.
  Only this file and a dated STATE.md entry were written.
- **Window.** Work published or updated after the last researcher handoff (`20261103-rtx5090-projection.md`) and the
  coordinator's `20261115-gpu-friendly-protocols.md` (its numbers are treated as unreviewed). Where a source is older
  but was first checked this cycle, its date is given.
- **Builds on:** `20261103-rtx5090-projection.md` (H121-H126), `20261101-logup-gkr-w16.md` (H111-H116) and `DEFERRED.md`
  (coefficient-form rows, 31-bit field).
- **Searches carried no project name, owner name, path or detail.** Web pages were treated as data.

Labels: [MEASURED] (here: a run in this repository), [AUTHORS] (the source's own unreplicated number), [MODEL],
[ESTIMATE]. Nothing below is a measurement of this project.

## 0. Headline

- **Nothing found changes the 5090 bottleneck picture.** The 20261103 projection puts the 5090's limit on the per-fork
  host path and the serial witness chain, not on GPU kernels. Almost all of this cycle's literature (PCS codes, GPU
  sumcheck, lookups) attacks GPU-side work. Honest expected gain from those items on the target: 0-3%.
- **The one external fact that moves a planning number is FlashProve's own batch curve** (§1.1): its 110 tok/s needs a
  24-request batch of 1,024-token windows; one request runs at 17.4 tok/s. The target (D64) is at batch 24 there. Our
  single-request projections (76-108 tok/s at T128) therefore compare against a batched number. State the batch size
  and window length whenever we claim parity.
- **Three candidates are ranked in §3.** Two are re-framings of existing hypotheses with new supporting evidence; one
  (H127) is new.

## 1. External systems, what they actually claim

### 1.1 FlashProve (Anthropic; research page and repository read this cycle; Apache-2.0) [AUTHORS]

Sources: anthropic.com/research/provable-inference; github.com/anthropics/FlashProve (`README`, `guide/performance.md`,
`docs/protocol.md`). The repository's `paper/paper.pdf` was not read; check it before quoting construction details.

- **Setup.** Llama 4 Maverick, 4-bit weights, about 17B active parameters. One H100, 24 CPU cores, about 270 GB host
  memory (weights streamed in layer segments). Prefill-style proving: each proof covers one 1,024-token window, after
  the reply exists. The next token is public.
- **What is hidden.** Weights, intermediate values and expert routing. The prompt and reply are public. That is the
  opposite of P1 (we hide IO, weights public), so its numbers are a comparison point, not a like-for-like bound.
- **Throughput is a batch curve** (`guide/performance.md`, steady state, start-up and the 39-minute one-time
  commitment excluded):

  | Requests per batch | tok/s | s per request |
  |---|---:|---:|
  | 1 | 17.4 | 58.8 |
  | 8 | 76.3 | 13.4 |
  | 24 | 111.2 | 9.2 |
  | 64 | 123.3 | n/a (about 80.6 of 81.6 GiB VRAM used; "not to be relied on") |

  The five-batch session rate including 68-79 s start-up is 103.6. Proving is about 71-93 times slower per GPU than
  vLLM prefill of the same tokens (calculated by them). Proofs are about 18.8 MB each; verification about 21 s on one
  CPU thread.
- **Construction (from `docs/protocol.md`; same family as ours):**
  - about 64-bit prime field with an extension-field challenge space;
  - zero-knowledge Reed-Solomon rows (message plus random elements, query bound t) and salted Merkle trees, one leaf per
    column;
  - sumchecks and lookups reduce each segment to linear claims about committed vectors;
  - digit lookups for range checks;
  - a shared Fiat-Shamir chain across the whole batch, with request "seals" as leaves of a small salted Merkle tree;
  - **proof-of-work bits** (up to 28 per request, 20 in most closeness rounds) counted in the soundness total: 126.2
    bits with PoW and **96.2 without**, against a 128-bit target.
- **What it means for us.**
  - Their batch gain (17 to 111 tok/s) is mostly amortizing one weight-table opening over the batch. With public
    weights (P1) we have no weight commitment to open, so this specific saving does not transfer (§4, R1).
  - The shared batch transcript and the grinding bits are the two ideas that do (H127, H129).
  - Whether their prover time includes building the integer forward pass is **not stated** on the pages read.

### 1.2 Others (claims only)

- **Attestable** (blog numbers read via a third-party summary, 2026-08-12, "alpha") [AUTHORS]: 53 tok/s on one 16K
  sequence and 77 tok/s on a batch of four 4K sequences, Gemma 4 31B, one H100, proofs 4.35-7.92 MiB, verify 0.16-0.65 s.
  Proof system, field, soundness, and what is hidden are **not stated**; no artefact to rerun. Not a usable bound.
- **DeepProve** (ePrint 2026/1112, CCS 2026) [AUTHORS]: GPT-2 and Gemma 3 at about 174 and 86 tokens per minute on its
  reference setup; 1,855 tokens/min with distributed proving. Public-IO; an order of magnitude or more below our
  per-GPU rate. Already in the 2026-10-30 gap study.
- **Jolt Atlas** (arXiv 2602.17452, Feb 2026, ICME Labs) [AUTHORS]: lookup-centric zkML on Jolt's sumcheck stack, zero
  knowledge by "BlindFold" (the sumcheck verifier as a small R1CS, folded and proved with Spartan). Abstract gives no
  numbers, hardware or hidden-set. Idea worth noting only: ZK for sumcheck by proving the verifier, rather than masking
  each round (our approach). No quantified overhead found.

## 2. Candidates

Each: source, claim, what it changes, bytes/verifier, falsifier in project terms, honest gain against 110, risks.

### H127 (new). One batch transcript so public lookup tables and shared per-block work are built once per batch

- **Source.** FlashProve `docs/protocol.md` §6.3 (a single Fiat-Shamir chain for all requests in a batch, request seals
  in a salted Merkle tree) [AUTHORS]. The adaptation to our LogUp tables is mine.
- **Claim.** If B requests share the LogUp challenges (alpha, gamma) and the per-domain table weights, the challenge-
  dependent public tables (pair-inverse tables for the five domain zero-checks, helper table) are built once per batch,
  not once per proof.
- **What it replaces.** The per-proof table builds. In the instrumented W16 block (quoted in
  `20261101-logup-gkr-w16.md` §2, from `results/zk60_limb16_20261031/logs/g_phases2.log`) table builds were about 0.085 s
  of 0.578 s (15%) and sat in the device phase. They were instrumented at W16, not W16R2: **re-measure before using it.**
- **Bytes / verifier.** Changes the transcript: a new profile string (D17). Requests in a batch are no longer
  independently verifiable without the batch's seal root plus an inclusion path. Verifier does one batch check.
- **Falsifier (Mac, one guarded run, after the heavy lock frees).**
  1. Instrument the table-build share of one W16R2 8B block, warm, n >= 3. **Kill if the share is under 5%** of block
     proof time.
  2. Research-only (unsound) prototype: fix alpha across 2 and 4 requests, skip the rebuild, run D55 forks. **Kill if
     per-request time falls under 4%** at 4 requests.
- **Honest expected gain.** Mac (GPU-bound): x1.00-1.13 at B >= 8 [ESTIMATE from the 15% share]. 5090 (host-bound
  central case): **x1.00-1.03**, because tables are on the device and the GPU is not the limit (26.5 ms per block in the
  projection). Does not move the target by itself.
- **Risks.**
  - Soundness: per-request error is unchanged by a shared challenge if it is drawn after all B requests' commitments,
    but a batch-level "any request false" bound costs log2(B) bits. The register's open item "mix-and-match grinding
    counted in proof work" (`ZK60_DECISIONS.md` line 87) applies directly.
  - Privacy: shared challenges across requests of different users couple their transcripts; the joint-view and NL-1
    gates would need rerunning with cross-request views.
  - Product: batch-bound verification; a single request cannot wait for a batch. Fits a service that batches anyway.

### H128 (re-framed H124b). Exact int8 tensor-core forward for the witness chain, with literature support

- **Sources.**
  - EmuGEMM, arXiv 2606.25453 (Lu, Maeder, Luisier, Ziogas; v2 2026-10-05; SC26): fused integer tensor-core kernels,
    up to 1,639 Top/s on Hopper (83% of INT8 peak) and 3,654 Top/s on Blackwell (81%) [AUTHORS]. Floating-point
    emulation workload, not modular arithmetic; Hopper and datacenter Blackwell, **not a 5090**.
  - AWE, arXiv 2609.24519: exact integer products with fewer GEMMs on FP4 tensor cores [AUTHORS, abstract only].
- **Claim.** Integer GEMMs can run at 80%+ of INT8 peak once intermediates stay out of global memory.
- **What it replaces.** `witness.rs::matmul` (the 0.257 s per block serial chain, `STATE.md` 2026-11-04). This is the
  20261103 H124 seam; no new seam.
- **Bytes / verifier.** Preserved, provided the result is bit-exact. The existing bound holds: |x_lo . w| summed over
  K <= 14,336 is under 2^31 on two int8 limbs.
- **Falsifier (needs the 5090 or any CUDA GPU; none on the Mac).** The budget for 110 tok/s at T128 is about 1.16 s per
  request. If the whole 32-block forward may take at most about 0.3 s, a block's exact forward must take **<= 9 ms**.
  **Kill if a fused int8-limb forward for one 8B block (K up to 14,336, M = 128) takes over 9 ms on the 5090**, or fails
  bit-exact digests against `build_accuracy` at W16, W16R2 and R13 shapes. Also kill if the builder remainder
  (about 0.16 s per block at 32 threads, not matmul) is not removed by the same change, since that remainder alone
  breaks the budget.
- **Honest expected gain.** Same as the projection's row 1: target clock 6-11 to 48-76 tok/s [MODEL]. The literature
  adds confidence that the kernel can run at high efficiency, not a new number. **Check the coordinator's "1,500 TOPS"
  INT8 figure for the 5090**: NVIDIA's published "AI TOPS" are quoted with structured sparsity, and a dense INT8 rate
  may be half. I did not confirm the 5090's dense INT8 rate this cycle.
- **Risks.** The remaining witness work (the serial chain's non-matmul steps, expansion, host to device hops) is outside
  this lever. No soundness or privacy effect; a witness bug does not break soundness but fails honest proofs.

### H129 (new, small). Proof-of-work grinding bits for the PCS opening term

- **Source.** FlashProve `docs/protocol.md` §6.4 (up to 28 PoW bits per request, 126.2 bits with PoW against 96.2
  without) [AUTHORS]. Standard in FRI/STARK provers.
- **Claim.** Each grinding bit adds a bit to the opening-attack cost at 2^b hashes for the honest prover, a negligible
  GPU job at b <= 24.
- **What it changes.** The opening/query count Q (`W16R2_OPENED_COLS`, now 280) and the "retries are cheap" attack in
  D59's Q = 280 arithmetic (`ZK60_DECISIONS.md`, per-opening 2^-113.9, 8B run 2^-97.78, LogUp-bound 2^-97.92).
- **Bytes / verifier.** Changes bytes (a nonce per opening round; fewer columns), and the verifier checks leading zero
  bits. New profile string.
- **Falsifier.** On paper: **kill if Q cannot fall below about 250 at the same overall bound.** The run is LogUp-bound
  at 2^-97.92, so shrinking the PCS term further buys nothing without a better LogUp bound or a policy that counts PoW
  bits. Receipt bytes were +3.5% for Q 260 to 280, so even a 10% cut in Q is about 1-2% of receipt bytes.
- **Honest expected gain.** Under 1% on tok/s [ESTIMATE]; receipts about -1 to -3%. Not a throughput lever.
- **Risks.** Needs a ruling: counting grinding as security work is a policy choice (FlashProve itself reports both
  numbers). The D27 floor of about 95 bits leaves only about 3 bits of margin at the LogUp bound.

### H130 (W16R3 candidate). Ligero list-decoding analysis and out-of-domain sampling: rates above 1/2

- **Sources.**
  - ePrint 2026/2681 (Cascudo, Hazay, Venkitasubramaniam; received 2026-10-29, revised 2026-11-02): "mutual correlated
    agreement" analysis of unmodified Ligero gives lower query complexity; a variant with out-of-domain sampling allows
    RS rates above 1/2 with perfect honest-verifier zero knowledge [AUTHORS; no numbers on the page, PDF not read].
  - ePrint 2026/2481 "Polygero" (Frigo, shelat; 2026-10-14): polynomial-challenge proximity test, soundness beyond unique
    decoding, parameters machine-checked in Lean, no roots of unity or OOD samples required [AUTHORS; abstract only].
  - ePrint 2026/391 (Chiesa, Fenzi, Weissenberg): ZK IOPP with "negligible" ZK overhead [AUTHORS; no numbers].
- **Claim.** Stronger soundness per opening for Ligero-shaped RS commitments, so fewer columns or a higher rate at the
  same bit level.
- **What it replaces.** The proximity analysis behind rate 1/2 and Q = 280, and potentially the rate itself (D59 moved
  1/4 to 1/2 for x1.11 core, measured).
- **Bytes / verifier.** Changes roots and bytes (rate), the opened-column count, and the verifier's checks.
- **Falsifier (paper first).** Read the three PDFs and recompute our 8B-run bound with the improved analysis.
  **Kill if it does not allow Q < 200 at rate 1/2 or rate >= 2/3 at Q <= 280** with the run still at or above about 97 bits.
  Then, only if it passes: the Metal commit at rate 2/3 against 1/2 (**kill if under x1.04** on the A commit).
- **Honest expected gain.** Encode and Merkle volume fall by about a quarter from rate 1/2 to 2/3 [COUNTED from the code
  length ratio]. The Mac: roughly x1.03-1.06 on a GPU-bound block [ESTIMATE]. The 5090 central case: x1.00-1.03 (same
  reason as coefficient-form rows). **VRAM** is the one place it could matter on the 5090, because codeword memory caps
  forks near 8 (`20261103` §1, assumption 4): a quarter less codeword memory could allow one or two more forks.
- **Risks.** Rework of the delta/2 lemma and the PG-R2 rank checks; every byte changes. Joins the deferred
  coefficient-form change as one new profile (`DEFERRED.md`), not before.

## 3. Ranking for triage

1. **H128: exact int8 tensor-core witness forward.** It stays first because it is the only lever the 20261103 model says
   moves the 5090 by a large factor (6-11 to 48-76 on the target clock). Needs CUDA hardware; the first decision is the 9 ms
   per block kill test.
2. **H127: one batch transcript for shared tables.** New this cycle and cheap to test on the Mac (a table-build share
   measurement, 0.5 day), but small on the 5090. Needs a soundness and privacy ruling before any code beyond the
   measurement. Do the measurement; defer the protocol work.
3. **H130: the improved Ligero analysis (with coefficient-form rows) for a W16R3 profile.** Paper work only, folded into
   the profile that is being cut anyway. Do not start a separate gate cycle for it.

H129 sits just below these: a paper calculation that costs nothing but is capped by the LogUp-bound.

**Implication for 110 tok/s.** None of these closes the gap alone. The 5090 path in the 20261103 model still needs, in
order: a fast exact witness (H128), the host path off the critical path (H122, H123, H125), per-fork queues (H121),
then requests batched to the FlashProve-like size. The new batch curve (§1.1) says to plan for B near 8-24 in that
comparison.

## 4. Looked at and rejected (one line each)

- **R1. FlashProve's weight-opening amortization.** Saves a weight-table opening per batch; our weights are public in P1,
  so there is no weight opening to amortize. Our batched-weight-fold study (20260926) already found the fold under 0.1%
  of readiness; `g.M` is still computed per request.
- **R2. Bolt** (ePrint 2026/310; Gurkan, Novakovic, Rothblum): about 3-4x faster commit than RS schemes at N = 2^30,
  but over GF(2^32), hardware not stated, no ZK. Binary-field code on a Goldilocks, exact-integer stack. No.
- **R3. Blaze** (ePrint 2024/1609, EUROCRYPT 2025) and its prime-field generalization (ePrint 2026/487, NUS, blind PCS
  aimed at homomorphic encryption): RAA codes need XOR/linear time but the blind variant targets encrypted
  coefficients, with no timings on the page. Not our setting.
- **R4. Quasar** (ePrint 2026/1839; Xidian/SJTU): 13.6-20.6x faster commit than BaseFold on 32 CPU threads and a GPU
  encoder 33-148x over that CPU; but a 127-bit Mersenne field, O(N log N), no ZK or hashing discussed [AUTHORS]. Field
  mismatch.
- **R5. ReedWeave** (ePrint 2026/2147; Goldilocks, rho = 1/4, d = 2^24, 32 threads; commit 475 ms, 6.9x over FRI):
  speeds FRI's first folds. Our PCS is a one-shot interleaved RS commitment with no FRI fold rounds. No transfer.
- **R6. GPU WHIR on Apple Silicon** (ethresear.ch, BabyBear, M1/M3, 1.25-2.4x over an optimized CPU, Poseidon2 Merkle
  58% of GPU time, sumcheck left on CPU) [AUTHORS]. Two lessons that agree with our measurements: fusing to avoid
  round-trips beats kernel tuning, and **overlapping CPU reads with GPU work was slower on unified memory because both
  compete for bandwidth.** That is a warning for H112/H121-style overlap on the Mac, not a lever. Our hash is BLAKE3,
  not Poseidon2.
- **R7. Qingming-g64-ntt-cuda** (ethresear.ch 2026-07-06; RTX 4090; no stated license): native Goldilocks LDE NTT,
  domain 2^24 in 1.23 ms ("fast", 581 GB/s) and 2^27 in 9.2 ms ("fast", 704 GB/s) against 38 ms ("standard") [AUTHORS,
  self-replicated, no baseline]. Evidence that a Goldilocks NTT on a 4090 is bandwidth-bound, consistent with our
  DRAM-scaling assumption for the 5090. It does not change a ranking.
- **R8. SP1 CUDA BaseFold crate** (`sp1-gpu-basefold`): no numbers on the docs page; not our code.
- **R9. GPU sumcheck.** Chimera (ePrint 2026/1388; BN254; 7.99x in the Sumcheck region at N = 2^17 and 2.94x over ICICLE)
  and SumCATS (DATE 2026; binary tower, 1.6-1.8x) are other fields. The ICICLE team's own view is that sumcheck is
  memory-bound, which matches our launch-and-bandwidth floor (H113).
- **R10. CUDA 13.3 carry-less multiply** (NVIDIA blog, 3-4x on a 5090 for binary-field sumcheck): needs a binary-field
  rebase. We are integer-modular (D56 deferred).
- **R11. Speeding Up Sum-Check Proving** (ePrint 2026/587; Dao, DeStefano, Bagad, Domb, Thaler; 2026-03-24): over an order
  of magnitude on Jolt's Spartan sub-protocol and 1.7-2.2x on a Shout sub-protocol [AUTHORS], with a many-multilinear
  product algorithm and near-free equality-polynomial factors. We already use split-eq accumulation, and our rounds are
  memory- or launch-bound on the GPU, so saved multiplications do not buy time (H115's estimate of -0.01 to -0.035 s
  stands). Worth reading only if a CPU-side rounds path becomes the limit.
- **R12. Twist and Shout** (ePrint 2025/105, secondary summaries only): one-hot lookup commitments; our tables are
  at most 2^16, so no gain (same as the 20261101 SoK row).
- **R13. LogUp-GKR GPU.** No 2026 GPU result found. Remains H111 (x1.00-1.25 on Metal, ZK review pending).
- **R14. Tensor-core finite-field GEMM for Goldilocks.** Nothing published for a 64-bit prime found. The coordinator's G1
  (9x-36x more MACs on tensor cores) rests on its own model; EmuGEMM and AWE show the limb approach works for
  floating-point emulation, not that a modular reduction can be fused. A prototype is the only test.
- **R15. KV-cache or incremental proofs.** No incremental/recursive scheme for decoding found. VeriLLM (arXiv 2509.24257)
  avoids ZK, and ZK-DeepSeek (arXiv 2511.19902) says little. FlashProve proves per 1,024-token window after the reply,
  as prefill, which is the same batching of positions our 2026-09-26 amortization handoff describes. The KV handoff of
  2026-09-26 stands.
- **R16. BLAKE3 on GPU.** No RTX 5090 Merkle figure found; only community forks and NVIDIA cuPQC (Poseidon2, a different
  card). Our A30 parallel BLAKE3 tree digest stands.

## 5. Corrections and cautions about inputs

- **FlashProve is a batched, weights-hidden, prompt-public result.** Say "about 110 tok/s at 24 requests per batch of
  1,024-token windows, one H100" when quoting the target. A single request is 17.4 there.
- **Coordinator's G1-G5 note.** Its "1,500 TOPS" INT8 figure for the 5090 may be a sparsity-doubled marketing number;
  unverified here. G3's receipt claim (819 MB to about 45 MB) is the coordinator's own model. The 819 MB agrees with
  32 blocks at about 26 MB (`ZK60_DECISIONS.md`); the 45 MB is not supported by any source read here (FlashProve's
  proofs are 18.8 MB per request, but with public IO and a different structure).
- **The 0.085 s table-build share (H127) is W16, not W16R2.**

## 6. Status

- New full-stack proofs, passes and proved positions: **0 / 0 / 0**.
- The complete private 8B at >= 50 proved tokens/s on an RTX 5090 (target now about 110) remains **unachieved**; this
  scan found no literature result that changes the order of levers.
- Hypotheses: H127-H130 added (130 in total). No `progress/` entry or `PROGRESS.md` refresh was written, by the
  instruction for this cycle.

## 7. Next concrete actions (each needs no new permission to prepare)

1. Read `paper/paper.pdf` in the FlashProve repository (construction, how its prover builds the integer forward pass, the
   batch seal tree) and ePrint 2026/2681 and 2026/2481 in full.
2. On the Mac after the heavy lock frees: instrument table builds on one W16R2 8B block (H127 step 1).
3. Recompute the run-level bound at Q < 280 under the improved analysis (H129, H130 paper step).
4. When CUDA hardware exists: the 9 ms-per-block forward test (H128).
