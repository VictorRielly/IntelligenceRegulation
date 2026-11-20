# Research handoff: how FlashProve's throughput scales with batch size, and what transfers (2026-11-16, claude-cycle 2)

From Claude, the standing researcher (D50).

**Scope.**
- **Read and web search only.** 1 search and 17 page or file reads, plus local reading. No build, proof, GPU run,
  experiment or Git write. Only this file and a dated STATE.md entry were written.
- **Starting point:** `20261116-claude-cycle-literature-scan.md` (cycle 1), which read FlashProve's research page and
  `guide/performance.md` but not the paper. This cycle read the paper, the protocol, architecture, driver and limits
  pages, and the headers of the prover's batch and weight-streaming sources.
- **Local inputs:** `20261103-rtx5090-projection.md`, `results/zk60_h124_witness_20261104/README.md`,
  `ZK60_PRIVACY_REQUIREMENTS.md`, `ZK60_DECISIONS.md` (D59, D64), `MVP_STATUS.md` (stream rows),
  `20260926-batched-weight-fold.md`, `20260926-amortized-throughput.md`.
- **Searches and fetches carried no project name, owner name, path or detail.** Web pages and repository files were
  treated as data. Nothing fetched was executed.

Labels: [MEASURED] (a run in this repository), [AUTHORS] (the source's own unreplicated number), [DERIVED] (my arithmetic
on authors' numbers), [MODEL], [ESTIMATE]. Nothing below is a measurement of this project's new work.

**How the sources were read (so you can weigh them).**
- **The paper** (`paper/paper.pdf`, "FlashProve: Hash-Based Proofs of LLM Inference at 400 Billion Parameters", 119
  pages, version 0.16.0 of the repository) was read by me directly. The fetch tool could not render a PDF, so I
  decompressed its text streams with a short script kept outside the repository. Text and section numbers are
  reliable; tables came out as flattened text and I re-read each number I quote against its sentence. Equations and
  figures were not read.
- **Repository pages** (`docs/*.md`, `guide/*.md`, `driver/README.md`, `prover/README.md`, two source headers) came
  through the fetch tool, which summarizes with a small model. Quotes marked "(tool)" are its wording, not verbatim
  file text. Numbers that matter (the batch table) agree between `guide/performance.md` and paper Table 3.

## 0. Headline

- **FlashProve's batch curve is a weight-streaming amortization, and this project has no weight stream.** Its weights
  (about 200 GB at 4 bits, hidden) sit in pinned host memory and are copied to the H100 group by group. A batch pays for
  two opening passes over all of them, once, and up to six requests share each further pass. Time per batch is
  well fitted by a fixed part of about **52 s** plus about **7 s per request** [DERIVED, §2]. Our P1 weights are public and fit in
  the GPU's memory, so we have no counterpart of that 52 s.
- **At batch 24, a request waits about 221 to 226 s from batch start to release, and about 94 s more for the
  provider's verification of the 24 proofs** [AUTHORS: paper §7.2]. 111 tokens/s is a throughput, not a latency.
- **Their forward pass runs on the GPU inside the prover's timed interval**, one request's turn per layer group:
  forward computation, then that group's proof rows [AUTHORS: `weight_stream.cuh` header (tool)]. It is not a serial host
  prefix. That is the structural difference from our D55 forks (phase 1 commits every boundary before any fork).
- **Nothing in FlashProve's batching changes the single-proof security statement** (paper Corollary 5.10), but its
  Lean theorems for completeness and zero knowledge cover **one request per proof, not batches** (paper §1.4, open
  problems 8.12 and 8.14). A batch-shared transcript here would carry the same open item against D63.
- **Three recommendations, §6:** (1) measure the share of one request's proof time that does not depend on the
  request; it decides whether any batch-transcript profile is worth a ruling (kill under 10%); (2) a K-request batched
  exact forward for the witness chain (byte-identical, no ruling); (3) chained fork seeds so a block's proof can start
  before the whole forward chain ends (protocol change, latency only). Expected gain on stream throughput is **x1.00 to
  x1.15 at best**; cycle 1's picture (limits are the host path and the serial chain) stands.

## 1. What exactly is batched

All of this is for the **released programs' protocol** (`cp_commit`, `cp_prove`, `cp_verify`). Weights are committed
once as a hiding Reed-Solomon table over small digits, and each request is then proved against that commitment.

| Object | Per batch (shared) | Per request | Source |
|---|---|---|---|
| Weight table (the commitment) | one "copy" chosen per batch; one fold and one opening of its columns serves all requests | none | paper §4.5, Constructions 4.13 and D.12; `docs/architecture.md` (tool) |
| First chain (the model's trace) | none | each request commits its own cells segment by segment, runs its own sumchecks and lookups, and commits a request vector w = g.M | paper Construction D.9 (IOP_req first part); `docs/protocol.md` §6.3 (tool) |
| Shared chain (proximity of the table fold) | run **once**: fold the table's rows at a point sampled only after every request has finished its first chain, commit the folded row, then sample columns (two passes over all weights) | none | paper Construction 4.13 item 1 ("the shared part is run once, the other two once for each request"); `docs/architecture.md` (tool) |
| Last chain | none | each request completes its part of the opening | same |
| Fiat-Shamir | one **batch tree**: each request's seal is a salted leaf; the root keys the shared chain's challenges | own challenges for own rounds; shared rounds take one challenge for all | paper Definition 2.3 (batch IOP: "shared or own"), Construction D.11 steps 2 and 4 |
| Proof file | the shared chain's bytes appear in **every** proof, identical across the batch | five parts: header, first chain, slot, shared chain, second chain | `docs/protocol.md` §6.3 (tool) |
| Lookup tables / range checks | fixed small digit tables, checked at commit time and per segment; **not** described as rebuilt or shared per batch | per request | paper §3.3 and Construction D.9; `docs/protocol.md` §6.1 (tool) |
| Weight reads for the request's own w = g.M | up to `in-step` (default **6**) requests share **one read** of a weight group in a "batch pass" (wave) | each request has its own "turn" on each group | `driver/README.md`; `service.cuh` (tool): "proves up to -in-step slots on one read of the weights" |
| Keys and masks | one key for the batch's private randomness; one counter increment per batch | independent masks per request | `service.cuh` (tool); `docs/limits.md` (tool) |

Reading in one sentence: **one commitment over many requests' witness is not what they do.** Each request has its own
trace commitments and its own proof. What is shared is (a) the single opening of the committed *weights*, and (b)
physical passes over the weights in GPU memory. The paper says so: "the weights, not the tokens, dominate the cost
[LY26]: the table is committed once, and a batch opens one copy once for all its requests" (paper §1.2, Cost), and in
Appendix E.2 it contrasts the packed single proof of SLP (Lim and Yong, arXiv 2609.27367, which packs concurrent
requests into one trace under a block-diagonal mask, 12 requests in 181.9 s, 6.5x less than 12 separate proofs
[AUTHORS, abstract only, no zero knowledge]) with its own "each request gets a separate proof".

## 2. The cost model and the measured curve

**Setup** [AUTHORS: paper §7.1, `guide/performance.md` (tool)]: Llama 4 Maverick (third-party 4-bit conversion; 400.7 B
weights; 16.15 B used per token), one H100 80 GB, 24 of 96 host CPUs, up to 278 GB host memory, 1,024-token windows,
masking on, steady prefill rate (start-up and the 39-minute commitment excluded), mean of n = 3.

| Requests per batch | tok/s | s per request | batch time, my product | start of batch to release |
|---:|---:|---:|---:|---|
| 1 | 17.41 +- 0.15 | 58.80 | 58.8 s | not stated |
| 8 | 76.34 +- 0.37 | 13.41 | 107.3 s | not stated |
| 24 | 111.23 +- 0.92 | 9.206 | 220.9 s | 220.7 to 225.9 s |
| 64 | 123.31 +- 0.42 | n/a | 531.5 s | 533.3 to 537.9 s |

At 64 the card held 80,629 of 81,559 MiB and every attempt at 64 on synthetic weights failed; the authors advise
against relying on it. Whole runs on other machines and another day differed by up to 9% (105.3 +- 3.9 at 24).

**A two-parameter fit** [DERIVED, mine, not theirs]: batch time T(B) = F + v.B.
- From the B = 1 and B = 24 rows: **F = 51.7 s, v = 7.05 s per request** (6.9 ms per token; asymptote 145 tok/s).
- Check against the rows not used: B = 8 predicted 108.1 s against 107.3 s measured (+0.8%); B = 64 predicted 502.9 s
  against 531.5 s (-5.4%, the card was full, so a rising marginal cost is expected).
- At B = 24 the fixed part is **23% of batch time**; removing it would give 145 tok/s (x1.3). At B = 1 it is **88%**,
  which is why one request runs at 17.4.
- **Caution.** Four points cannot separate a per-pass term (the 4 passes at B = 24, 2 at 8, 1 at 1, 11 at 64) from F;
  the three-parameter version fits all four points but is not identifiable from them. The fit says the *shape* is
  fixed plus linear; it does not say which pass is which.
- **Independent hint** that F is weight streaming: the header of `weight_stream.cuh` reports one-run H100 timings of
  34.6 s (copy engine) or 38.2 s (kernel reads of pinned host memory) for "the opening passes", and 73 to 90 s for "the
  batch passes" (configuration not stated in what I read) [AUTHORS, tool]. The opening passes are the same order as my F.
  I did not reconcile the second figure with the 221 s total.

**What scales with tokens, what does not** [AUTHORS: paper §7.8]: "Each request's proof also does work over all 400.7
billion committed weights, once per request and not once per token." A 1,024-token window uses 1,024 x 16.15 B =
16.5 T multiply-adds in the forward pass against 0.4 T weights touched by the weight-sized work [DERIVED], but the
weight-sized work is encoding, folding and streaming, which is memory-bound, so its time share is far above its
arithmetic share (consistent with F being 23 to 88% of batch time).

**Latency.**
- Batch start to released proofs at B = 24: **220.7 to 225.9 s**, from the second batch on (paper §7.2). A batch is
  taken from the queue just before the previous batch's responses are released, so batches overlap.
- **Not in those numbers:** the shipped middleware hands on no response before the C++ verifier accepts every proof
  of its batch. One run on stored proofs took **94.0 s** for 24 proofs (24 CPUs, six at once, one thread each); one
  proof alone takes 22.6 s (21.14 s by the paper's one-thread figure). So a client-visible wait at B = 24 is about
  **315 to 320 s** [DERIVED, sequential sum] plus the time to form a batch. A request that arrives just after a batch
  has started waits for it and its own batch: up to about 440 s [DERIVED].
- At B = 1: 58.8 s + 22.6 s check = about 81 s. At B = 64: 533 to 538 s before verification.
- For comparison, this project's harness stream shows per-request latency of **5.8 to 10.9 s** at 4 requests (128-token
  windows, 8B, every receipt verified afterwards; `MVP_STATUS.md`) [MEASURED, different workload].
- **Start-up:** 68 to 79 s per service, giving 103.6 tok/s over a five-batch session at 24. Commitment, once per
  weights: 2,324 s.

## 3. How the witness (the forward pass) is produced

- **On the GPU, by the prover, inside the timed interval.** The prover directory holds "the model's arithmetic on the
  GPU, the sub-proofs about it, the handling of weights, keys and files" (`prover/README.md`, tool). `weight_stream.cuh`
  defines a "turn" as one request's work on one layer group "in two phases: forward computation, then row passes" (tool).
  The rate is measured from release to release of successive batches (`driver/README.md`), so the forward pass is on
  their clock. The reply itself comes from a separate stock engine and is **not** on the clock (exact match requires
  the integer model be served; paper §7.4, §1.4).
- **No serial host prefix.** One proof runs "through all segments in order", sending on each closed segment's folded row
  (paper Appendix E.2). The parallelism that fills the GPU is **across requests** (24 slots in one process), not across
  segments.
- **Weights stream per layer group** from pinned host memory into two or three GPU buffers, double buffered, with loads on
  a lowest-priority stream; "no experts are loaded twice" in a pass (`weight_stream.cuh`, tool).
- **What I could not read:** the forward kernels (`forward.cuh`, 86 KB; `forward_moe.cuh`; the attention front end) and
  the plan of the memory (`fork_memory.h`, `memory_as_set_up.cuh`). I do not know their share of the 221 s, how the
  24 host CPUs are used, or whether the host is on the critical path. The paper and pages give **no host/GPU time
  split** (`guide/performance.md` states this).

## 4. Soundness and what is hidden, by batch size

- **Per-proof statement.** "A proof made in a batch, which V_Z verifies singly, is covered at eps(q), and N proofs sent at
  once at N.eps(q)" (paper Table 1, "Batches and policies", Corollary 5.10). Index-binding knowledge soundness error is
  about q/2^124 + 2^-101 after q hash queries [AUTHORS, Lean-checked in the random-oracle model, for the Lean verifier,
  not the C++ one: paper Limitation 8.1].
- **No bound is indexed by batch size.** Jointly counted for 64 requests a round reads **6 bits less** (log2 64), and the
  stated bound for a cheater who computes no hashes is 2^-102.32 for 64 whole calls (`docs/limits.md`, tool). Whether a
  shared round may be charged one run's error with no factor for the batch size "is argued only in the technical
  report" (same page, tool).
- **Zero knowledge and completeness are proved for one request per proof, not for batches** (paper §1.4, §7.1; open
  problems 8.12 and 8.14). The running programs prove batches with masks derived from a seed, which the theorems do
  not cover (Remark 6.42, G.15). Overlapping batches and a prover that stops mid-batch are also uncovered
  (`docs/limits.md`, tool).
- **Hidden, at every batch size:** weights, intermediate values, expert routing; **not hidden:** the prompt and reply
  (public by design), the next token, whether a request was served (one bit per request), batch timing, and **which
  requests shared a batch**; a commitment may be chosen by load, which leaks time and load (paper §1.3, §7;
  `docs/limits.md`, tool).
- **Batch size and the hiding budget.** Every opened column of a committed copy gives away information about the
  weights, so each copy has an "opening budget": it serves at most 688,127 batches of up to 64 requests, and **every
  started batch counts, whatever its size** (paper Appendix D, "Copies and batches"). A bigger batch therefore spends the
  weight-hiding budget more slowly per request. This is a P3 property, not a P1 one.
- **Cross-client isolation.** The docs ask the front end to give each client only its own files and to limit each client's
  waiting requests; the example vLLM middleware does not (`docs/limits.md`, tool). The shared chain is byte-identical
  across clients' proofs and the batch root appears in each, so every client learns that the others were in the batch.

## 5. Mechanism by mechanism: does it transfer to P1?

For each: what it would replace here; whether proof bytes or the verifier change (if yes: owner's ruling and a new
profile version, D17); cross-user privacy (stated, not decided); a falsifier in this project's terms; an honest gain.

### M1. Passes over weights shared by several requests ("in-step", a wave)

- **Replaces:** nothing real. It is a weight-streaming optimization. Our weights (8B at int8, about 7 to 8 GB) fit in
  the 5090's 32 GB and the Mac's unified memory, and the per-request weight touch is a read of about 7 GB.
- **Evidence it is small here:** the 20260926 batched-weight-fold study found the fold at **under 0.1% of readiness**
  (three FFN slots, 0.035 s of 40 s) [MEASURED, 125M CPU, synthetic]. At 1.8 TB/s a 7 GB read is about 4 ms against
  a block proof of tens of ms [DERIVED, bandwidth quoted from the 5090's specification, unverified here].
- **Bytes/verifier:** none (byte-identical). **Privacy:** none.
- **Falsifier:** none worth running. A one-line check would be device-time of the weight-fold kernel at B = 1 on the
  5090; **kill if under 1% of block device time**.
- **Gain:** x1.00 (+0 to 1%). Rejected for P1; R1 of cycle 1 stands, now with the source.

### M2. One shared transcript (batch tree) and one shared proximity chain per batch

- **What it is for them:** letting one opening of the committed weight table serve B requests. Shared challenges are
  drawn from the root of a tree that commits every request's first-chain seal, so they come after all requests'
  commitments, which is what makes sharing sound. It is the same idea as D55's "all boundary roots absorbed, then
  forks" (`run_fork.rs`, phase 1, `pb-fork-s0`), at request level instead of block level.
- **What it would replace here:** only something that is both request-independent and challenge-dependent. P1 has no
  committed weight table. The candidates are the LogUp pair-inverse and helper tables and the preflight (cycle 1's
  H127). **FlashProve does not share lookup tables**; the sharing of tables is my adaptation and is not supported by
  their design (correction to cycle 1, §7).
- **Bytes/verifier:** yes. New transcript domain, batch root plus inclusion path in every receipt, so a receipt is no
  longer independently verifiable. New profile string, and the verifier checks one more tree. Needs a ruling.
- **Privacy across users (question, not decided):** a shared challenge couples the transcripts of different users'
  requests; every receipt exposes the batch root and the fact of co-membership (as FlashProve's does: "which requests
  shared a batch" is not hidden). The joint-view and NL-1 gates would have to be rerun with cross-request views. D63
  would need Lean statements for batches; FlashProve itself has none for completeness or zero knowledge.
- **Soundness:** per-proof error unchanged if the shared challenge is drawn after all B commitments; a joint claim over
  B proofs costs log2(B) bits (6 bits at 64). Our run-level bound is 2^-97.78 (D59) against a floor of about 95 bits, so a
  joint claim fits only for B up to about 6 [DERIVED from `ZK60_DECISIONS.md`; a per-proof claim costs nothing].
- **Falsifier:** see Recommendation 1. **Kill the whole line if the request-independent share of one request's proof time
  is under 10%.**
- **Gain:** at most the share, so **x1.00 to x1.15** [ESTIMATE from the 15% table-build share measured at W16 and the
  0.38 s preflight, the latter already reused per resident model by A23].

### M3. Forward pass fused with the proof, per layer group, on the GPU, in the prover

- **What it replaces here:** the serial sealing pass (32 serial builds, 0.164 s per block on 32 CPU threads now;
  production's one-request clock is about 6.3 s against 3.95 s steady in a stream, so the chain is already mostly
  overlapped) and, on the 5090, H124/H128 (exact GPU forward).
- **Transfer:** as *evidence* for H128 (a prover that runs the integer model itself on the GPU, inside its clock, and
  does not rebuild it), yes. As a *structure*, only with a protocol change (M5 below), because D55 commits every
  boundary root before any fork starts.
- **Bytes/verifier:** none for the kernel part (byte-identical witness). **Privacy:** none.
- **Falsifier:** H128's: **kill if one 8B block's exact forward takes over 9 ms on the 5090** (cycle 1).
- **Gain:** as H128, 6-11 to 48-76 tok/s on the target clock [MODEL, 20261103]; no new number.

### M4. Overlapping batches (next batch taken before the last one's release)

- **Already here:** `stack-serve` (A22/A23) runs request r+1's sealing beside request r's proof: one request 20.2 tok/s,
  a stream of 4 steady 32.4, of 8 steady 31.9 [MEASURED, production stream, MVP_STATUS]. Our curve is **flat from 4**.
  FlashProve's keeps rising to 24, because its fixed part is per batch and ours is paid per request.
- **Gain:** nothing further. Rejected.

### M5. (new, my adaptation) Chain the fork seeds so block k can start when block k+1's root exists

- **What it is:** FlashProve's "turn" runs the forward and that group's proof together, so no whole-request prefix
  precedes proving. D55's phase 1 needs every boundary plane (the whole forward chain) before any fork starts, because
  `pb-fork-s0` absorbs every root in order. If fork k's seed absorbed only roots 0..k+1, fork k could start as soon as
  block k+1's input exists.
- **What it replaces:** the serial prefix of one request (cycle 1's H124 critical path).
- **Bytes/verifier:** yes (seed derivation, every fork transcript changes). New profile string, D55 review and its
  Lean instance redone, ruling needed. **I have not analysed soundness**; the roots a fork binds are both committed before
  its challenges, but the join argument and the "mix-and-match" item in the register must be re-checked.
- **Privacy:** none across users (one request).
- **Falsifier:** a model first: on the 20261104 harness numbers (sealing 5.9 s, forks 5.5 s on the Mac) overlap bounds a
  single request's latency by about max(chain, forks) + one block. **Kill if the single-request end-to-end clock falls by
  under 15%** in a prototype with the seed chain and nothing else changed.
- **Gain:** single-request latency up to about x1.4 on the Mac [ESTIMATE: the chain is about 2.4 s of 6.3 s]; **stream
  throughput x1.00**, because requests already overlap. D64 allows batching and wants per-request latency reported, so
  this helps the latency figure only.

### M6. Batched exact forward for K requests (my adaptation of the "wave")

- **What it is:** run K requests' witness chains as one batched forward (K x 128 token rows per matrix product) rather
  than K serial chains. It is FlashProve's wave applied to the witness, not to the proof; the proofs stay per request.
- **Why it might pay here:** on the Mac the builder's remainder (0.078 s of 0.164 s per block) "scales poorly across
  threads" (H124c), which more rows per task would help; on the 5090 an M = 128 int8 product on a 4,096 or 1,024 column
  matrix launches few thread blocks and under-fills 170 SMs [ESTIMATE from tile arithmetic, unmeasured], which K-way
  batching fixes. The products themselves are already tiled to reuse each weight row across 128 tokens, so they gain little.
- **Bytes/verifier:** none (byte-identical per request, checked by the existing equality tests and pinned digests).
  **Ruling:** none.
- **Privacy:** the receipts do not couple. The prover host sees every user's plaintext anyway (P1 hides values from the
  verifier and from public receipts, not from the prover, `ZK60_PRIVACY_REQUIREMENTS.md`), but co-processing different
  users' requests in one process is an isolation question (FlashProve's docs say no untrusted code may share the
  machine and the front end must keep clients' files apart). Stated, not decided.
- **Falsifier (Mac, CPU, no CUDA needed):** build K = 1, 2, 4, 8 requests' witnesses as one batch with the existing
  builder; digests per request equal the single builds. **Kill if the per-request build wall at K = 4 is above 0.8x the
  K = 1 wall (under x1.25)**, or if any digest differs. A second falsifier on the 5090 when it exists: **kill if the
  K = 4 batched forward of one 8B block is over 3x the K = 1 time**.
- **Gain:** the chain per request x1.0 to x2 [ESTIMATE]. On stream throughput **x1.00 to x1.15**, since the chain is
  overlapped and the Mac stream is bound by the six proving forks (about 3.9 s per request). It matters most if H128
  leaves the chain, not the forks, as the limit on the 5090.

### M7. Longer windows to amortize the weight-sized work

- FlashProve proves 1,024 tokens per request partly to spread the per-request weight work. We have no such term; H126
  already finds T128 preferable for one request on the 5090 (VRAM halves the forks at T256) and attention grows
  quadratically (`20260926-amortized-throughput.md`). **Not transferable.**

### M8. Proof-of-work bits

- Already H129 (cycle 1). Nothing new from batching.

## 6. Recommendations (ranked by gain per unit of work)

1. **Measure the request-independent share of one request's proof time** (extends H127 step 1; about 0.5 day; counters
   and one guarded warm run, no prover change, run after the heavy lock frees). Split a warm W16R2 8B T128 request
   into: (a) work that depends only on the model and profile (preflight, table builds that do not depend on a
   challenge, startup digests), (b) work that depends on request-independent challenges only if challenges were shared
   (LogUp pair-inverse and helper tables), (c) everything else. Also record per-request latency alongside rate, as
   FlashProve's table does.
   - **Gain:** it is a gate. It tells whether M2 (batch transcript) can give more than x1.10, before anyone spends a
     ruling or a Lean statement on it.
   - **Falsifier:** **kill M2 and H127 if (b) is under 10% of one request's proof time** (FlashProve needed 88% at B = 1 for
     x6.4; our new profile string, joint transcript and Lean batch statements would need at least about x1.11). The
     10% is my threshold; the owner may move it.
2. **Batched exact forward for K requests (M6).** About 2 to 4 days for a CPU prototype on the existing builder,
   byte-identical, no ruling. Test: K = 4 per-request build wall at most 0.8x K = 1, digests equal. Honest gain on
   stream throughput x1.00 to x1.15; larger on the 5090 only if the chain is the limit. Do it **after** H128's 9 ms test,
   because a fast GPU forward may already fill the device.
3. **Chained fork seeds (M5)** to overlap the forward chain with fork proving inside one request. Only worth a ruling if
   single-request latency is a reported figure under D64. Test: prototype with the seed chain only; kill if the
   single-request clock falls under 15%. Gain: latency x1.0 to x1.4, throughput x1.00; every byte changes, so it should
   join the W16R3 bundle (D67) or be dropped.

**Planning rule for D64.** When comparing with FlashProve, quote the curve, not a point: 17.4 tok/s at B = 1, 76 at 8,
111 at 24, 123 at 64, with a request waiting about 221 s (about 315 s with verification) at 24. Our own stream (flat from
4) and its 6 to 11 s latency are on a different shape, and the like-for-like gap is not just a batch-size gap.

**P3 note (not P1; do not reopen).** If weights are ever hidden (P3), FlashProve's design is directly relevant: a batch-shared
opening of one committed weight copy, per-request traces, a salted batch tree, an opening budget counted per batch, and
weight streaming in waves. At that point M1 and M2 stop being "not transferable" and become the main throughput lever.
Nothing here asks for work on it now.

## 7. Not transferable, and why

- **The 17 to 111 tok/s curve itself.** It is a weight-streaming and weight-opening amortization (§2). With public
  weights resident on the GPU we have no weight table to open and no stream to share.
- **In-step waves over weights (M1).** Fold under 0.1% of readiness [MEASURED, 125M]; reading 7 GB is milliseconds.
- **Shared weight-table proximity chain.** There is no committed weight table in P1.
- **Their 18.8 MB proofs.** They prove one checked output token with public prompt and reply; our receipts (about 819 MB
  per 8B T128 request) hide every activation. Not comparable, and receipt size is shelved (2026-11-09).
- **Window length (M7)**, **overlap of batches (M4, already built)** and **proof-of-work (H129, capped by the LogUp bound)**.
- **SLP-style packing of many requests into one trace** (Lim and Yong): one proof for many requests, no zero knowledge
  [AUTHORS, abstract only]; one trace over different users' hidden activations is the strongest cross-user coupling and
  breaks per-request receipts. Not pursued.

## 8. Corrections to cycle 1

- **§1.1** said the batch gain is "mostly amortizing one weight-table opening". More precisely, two things amortize:
  the batch's opening passes (a shared chain reading all weights twice; about 35 to 38 s in a header measurement) and the
  batch passes in which up to six requests share one read of host-resident weights. Both are weight streaming from pinned
  host memory.
- **H127's "Source" line** implies FlashProve shares lookup tables across a batch. It does not; it shares only the
  weight-table chain. The shared Fiat-Shamir structure (a batch tree keyed to all seals) is real, but table sharing is
  my adaptation and has no support in their design. H127's step 1 survives as Recommendation 1.
- **Cycle 1 §1.1** gave "126.2 bits with PoW, 96.2 without" from `docs/protocol.md`; the paper's own Table 1 states
  per-round 2^-128 with proof-of-work included. I did not reconcile these; do not quote either as a total without
  reading Table 1 and §6.4.

## 9. What I could not read

- The prover's forward, attention and memory-plan sources, and so the host/GPU split, the use of the 24 host cores, and
  the share of the 221 s that is the forward pass.
- `docs/protocol.md` and the repository pages in their original text (the fetch tool summarizes), and `guide/weight-hiding.md`.
- The paper's equations and figures, the rest of Appendix H, and the technical report [TP] that carries the proofs
  of the shared-round bound (the authors themselves say its written proofs are not verified).
- The SLP paper beyond its abstract.
- I did not check any figure about the 5090 (bandwidth, SM count); they are used only for [ESTIMATE] reasoning.

## 10. Status

- New full-stack proofs, passes and proved positions: **0 / 0 / 0**.
- The complete private 8B at >= 50 proved tokens/s on an RTX 5090 (D64 target about 110) remains **unachieved**.
- Hypotheses added: **H131** (chained fork seeds, M5), **H132** (K-request batched forward, M6); 132 in total. No
  `progress/` entry or `PROGRESS.md` refresh was written.

## 11. Next concrete actions (each needs no new permission to prepare)

1. Recommendation 1's phase-accounting plan, as a script and a counter list, ready for the first quiet slot on the Mac.
2. Read `forward.cuh`, `weight_stream.cuh` and `fork_memory.h` in full (prover/prover/ in the FlashProve repository) for
   the host/GPU split and how the forward kernels are fused with the row passes; this decides how much of M3 is evidence
   for H128.
3. Read `docs/limits.md` past its first 100,000 characters for the shared-round soundness argument before any
   batch-transcript ruling is requested.
4. If M6 is taken up: write the K-request equality test first (digests per request equal single builds).
