# Efficiency plan, 2026-11-05: toward D64 (≥ 110 proved tok/s), using what FlashProve shows

**Victor, 2026-11-05:** "Make sure to prioritize working on the efficiencies. A lot of them will change the proofs in
the first place. We now have a new source of extremely efficient proofs after Anthropics release so there may be some
techniques they use which might be useful for our proofs. Please provide a plan to continue building out the
efficiencies of the proofs."

Labels: [MEASURED], [INFERRED], [MODEL], [ESTIMATE], as in the research lane. No figure here is a promise.

## 1. Where we stand

**The target (D64, confirmed):** ≥ 110 proved tok/s on the target doc's clock, for a complete private P1 8B forward pass
on one GPU. The clock includes witness work and every receipt verified; request batching is allowed.

| | proved tok/s | Source |
|---|---:|---|
| Mac M3 Ultra, one request from its input, all witness work on the clock | **11.1** [MEASURED] | H124c step 4, `results/zk60_h124_witness_20261104/` |
| Mac, a stream of 4 requests (next sealed while this one proves) | **15.9** steady, 13.8 amortized [MEASURED] | H124d |
| Mac, proof only (witnesses prebuilt) | 22–24 [MEASURED] | same harness |
| RTX 5090, proof only, central case with the serial head fixed | ~108, p10–p90 69–117 [MODEL] | `research/zkp-efficiency/handoffs/20261103-rtx5090-projection.md` |
| FlashProve, Maverick (about 17B active), one H100, batch 24 | 111 (their measurement) | Astra's comparison, `results/zk60_astra_20261026/flashprove_comparison_20261104/` |

**Where one request's time goes on the Mac (8B T128, 32 blocks):**
- **The sealing pass:** the serial forward chain, about 5.4–5.9 s. 0.164 s per block, of which 0.086 s is the weight
  products [MEASURED].
- **The fork run:** about 5.5 s, GPU-bound on one command queue. That is about 0.165 s of GPU work per block:
  - commitments 55 ms (NTT 45, leaf hashes 6.5);
  - zero-check rounds 76 ms (slots 18 and 14 are 55% of that);
  - store folds 17 ms, on the CPU [MEASURED, 2026-11-01 table].
- **Preflight:** 0.35–0.98 s per request: a scan of about 7 GB of weights each time [MEASURED in the D55 logs].
- **In a stream, the sealing pass and the forks share the CPU,** so a request costs about 8 s, not the larger stage's
  5.9 [MEASURED].
- **The receipt is about 819 MB per request** (A + H openings 23.3 MB per block). FlashProve's is about 19 MB.

**The gap.** The Mac is about 7× short of 110. The 5090 is projected near 110 proof-only, and witness work still has to
come off its CPU. The plan therefore has to:
1. take the witness off the critical path and off the CPU;
2. cut the GPU work per block by about 1.5×;
3. bring the RTX 5090 up, which is the single biggest step.

## 2. What FlashProve brings that we can use

Astra read FlashProve's code and report in full (`results/zk60_astra_20261026/flashprove_comparison_20261104/REPORT.md`,
`architecture.md`). It found that we already use rate-1/2 codes, masked sumchecks, batched GPU rounds, wide range
lookups and concurrent block proofs, so there is no forgotten single trick. These are the transferable ideas:

| FlashProve technique | What it would do for us | Changes proof bytes? |
|---|---|---|
| **Exact INT8 tensor-core products** (`products.cuh`): split values into signed bytes, run integer GEMMs in bounded slabs, recombine mod p | The witness weight products, which are half the sealing pass, on the GPU. On CUDA this uses INT8 tensor cores. On Metal the same slab idea works with float matrix units, because int8·int8 sums stay exact below 2^24 | no |
| **Gram-matrix folding** (`fold.cuh`): fold a small Gram matrix across several rounds, then read the big rows once | Fewer full passes over large tables in multi-round folds: our store folds (17 ms on the CPU) and possibly the zero-check rounds | no (same round polynomials) |
| **Probabilistic matrix range checks**: after commitment, sample `{-1,0,1}` combinations and range-check the combined values | Fewer per-element range lookups, so fewer committed limb and helper rows. Today A is 2,504 rows and H 2,606 per block, and both commitments and zero-check tables scale with them. Possibly the largest structural cut | **yes**, plus new soundness, completeness and refusal-leak analysis |
| **Recursive openings** (fold-and-hop, code switching, out-of-domain samples) | Receipts from about 819 MB toward tens of MB, and a much faster verifier. Needed for any real deployment | **yes** (a new PCS opening) |
| **Cross-request batching** (requests share one weight-check pass) | With public weights, it amortizes the per-proof fixed work over requests: preflight, weight folds, per-slot fixed costs, the fixed Q = 280 column openings. Most useful on the 5090, where the per-fork host path limits | yes, if done inside one proof; no, if it is scheduling only |

Not worth taking (Astra's analysis, agreed): a 31-bit field (D56 counts 15 relations without headroom), BLAKE2b instead
of BLAKE3, the MoE techniques (our 8B is dense), and the cubic extension.

## 3. The plan

**The principle.** Do the byte-preserving work first: it needs no ruling, no re-proof and no re-gating. Design every
protocol-changing lever together and ship them as ONE new profile version, W16R3, so the Lean proofs and the privacy gate
are redone once, not per change.

### Phase A: byte-preserving, on the Mac now (about 2–3 weeks)

| # | Item | Expected [label] | Effort |
|---|---|---|---|
| A1 | Full-clock phase breakdown in the D55 harness: per-fork core phases, host vs GPU, CPU-seconds per phase, for one request and the stream | the ranking for everything below | 0.5–1 d |
| A2 | **Preflight once per resident model** instead of per request (H122) | −0.35 to −0.9 s per request: ×1.05–1.08 for one request [MEASURED inputs] | 0.5–1 d |
| A3 | A **production D55 witness source** that keeps the sealing pass's witnesses (today only test harnesses do) | the 11.1 tok/s path becomes the product path | 1 d |
| A4 | **Witness weight products on the Metal GPU**: FlashProve's byte decomposition on float `simdgroup_matrix` with exact slabs, checked against the CPU path on every plane. The GPU is idle during the sealing pass | sealing 5.4 → about 2.5–3 s; the stream's CPU contention mostly gone [ESTIMATE] | 3–6 d |
| A5 | The rest of the builder's serial work (78 ms per block outside the products), from a fresh profile | −20 to −40 ms per block on the chain [ESTIMATE] | 2–3 d |
| A6 | **Zero-check kernels:** shared per-point loads, point at infinity, affine extraction (#2) | −5 to −13 ms of GPU per block [ESTIMATE] | 5–10 d |
| A7 | Per-fork command queues and GPU timestamps (H121), so the true GPU-busy time is measured, not inferred | ×1.0–1.25 [MODEL] | 1–3 d |
| A8 | **Gram-matrix folding** (FlashProve `fold.cuh`) for the store folds, then the zero-check rounds if it pays. Same round values | store folds 17 ms → a few ms; zero-check rounds unknown [ESTIMATE] | 2–4 d |
| A9 | Boundary commits in parallel (H123) | ×1.03 [MODEL] | 1–2 d |
| A11 | **The forks' host path** (added 2026-11-05 after A7). A7's timestamps showed the fork run is not GPU-bound: the GPU is busy 53–59% of the forks phase, and a fork's host work per block grows from 0.22 s alone to 0.47–0.62 s with six forks, with only about 20 of 32 cores busy. First a host profile of the forks phase (N = 1 against N = 6), then the largest cause: a shared rayon pool, allocation, locks, memory bandwidth, or the spinning waits | up to the GPU-busy bound: the forks phase from about 5 s toward 2.8 s [MEASURED bound, gain ESTIMATE] | 2–5 d |
| A12 | **The device slots' tables on the GPU** (added 2026-11-05 after A11). Slots 14–19, 21 and 22 build 168 tables per block (1.32 GB, 95% of all table words) on the host, about 47 ms per block per fork at N = 6. Device kernels for the eq tables and the committed-plane gathers, reading the commitments' resident rows | about −7% on the proof-only fork run [MEASURED: −6.5% to −6.9%] | 1–2 d |
| A10 | **Register W16R2 for real content.** The registered profile is R13, whose blocks commit about 1.8× W16R2's rows (census: A 4,577 against 2,501; H 4,390 against 2,602). Astra measured a trained 26-block Shieldstral R13 stack at 9.9 s of proof, against 5.1 s for the synthetic 32-block W16R2 stack (`results/zk60_astra_20261026/flashprove_effplan_runtime_20261105/REPORT.md`) | about ×1.8–2.4 per block on real models [INFERRED from those two runs, which differ in width and weights] | the W16R2 privacy gate on GPU-made bundles, the D60 conditions, then a ruling by Victor |

**Status, 2026-11-05 evening:**
- A1–A5 done (A5 stopped after its first step).
- A7 done: the shared queue stays; per-thread queues are opt-in (`results/zk60_effplan_20261105/a7/README.md`).
- A6 deferred: kernels are not the limit. Its census found a cheap exact cut (slot 18's top point), for later.
- A11 done: one rayon pool per fork worker. Independent A/B on the merged tree, both orders: stream steady +19%,
  proof only −9.5%. The Mac is now at 14.5 tok/s for one request, 24.0 for the stream steady and 29.5 proof only
  [MEASURED].
- A12 done: the device slots' tables are built on the GPU, every word checked equal to the host's. Independent A/B on
  the merged tree, both orders: proof only −6.5%, one request −4.0%, stream steady +5.0%. The Mac is now at 15.3
  tok/s for one request, 23.6–24.4 for the stream steady and 30.1 proof only [MEASURED].
- A8 done: no Gram folding was possible (each opening already reads its rows once; the vectors are distinct maps). A
  faster store fold instead (row-sparse, prefetched, 16-bit NEON lanes, pads in the same pass): 2–2.5× on the fold.
  Independent A/B on the merged tree: proof only −2.9%, stream steady +2.2%. The Mac is now at 15.5 tok/s for one
  request, 24.2 for the stream steady and 32.6 proof only [MEASURED].
- **A13, a negative result, not merged.** The forks phase fell 9.4% and the sealing pass rose 9.2%; one request moved
  +1.1% and the stream −7.3%. Its probe found the sealing pass in the global pool keeps about 10 of 32 cores busy, with
  62% system time. An 8-thread pool gave one request −11.5% and the stream +19.6% (harness, 2 passes) [MEASURED].
- **A14 done:** lazy sums (the default; proof only −2.8%, the stream −1.8%, re-checked in A15). The lane XOF and the
  parallel absorb are opt-in.
- **A15 done: the sealing pass's witness builds run in their own pool** of `(cores/4).clamp(1, 8)` threads, 8 here
  (`HL_SEAL_POOL`; 0 restores the global pool).
  - On the 32-thread global pool, 25 of the pass's 40 CPU-seconds were rayon's sleep-lock waits and `yield_now` spins.
  - Independent A/B on the merged tree against production's previous form (4 passes, both orders, every pair): one
    request −10.5%, stream steady +16.1%, amortized +14.9%, the sealing pass −20.6%; proof only unchanged.
  - The Mac is now at 17.5 tok/s for one request, 29.1 for the stream steady (24.4 amortized) and 30.1–32.6 proof
    only [MEASURED]. **Phase A's expected result below is met.**
  - The lazy sums were re-checked on top of it: the stream is unchanged, so they stay on.
  - The stream is now balanced (about 4.4 s of proof per request against about 4.6 s of sealing beside the forks), so
    both sides must get faster.
- **A16 done: the sealing builder's serial work** (`witness_accuracy.rs`, `witness.rs`; byte-preserving;
  `results/zk60_effplan_20261105/a16/`).
  - Seven forms (`HL_A16`, all on by default):
    - supports and chunk plans cached per public geometry;
    - chunked requantization;
    - normalization rows in parallel, in i64 where exact;
    - `build`'s loops on the pool;
    - int16 score and PV kernels;
    - Q/K/V and gate/up side by side;
    - production's public check of each block run once.
  - The pass's serial main line fell from 1.15 s to 0.04 s. The pool rule stays at 8 threads.
  - Independent A/B on the merged tree through production's builder (4 passes, both orders, every pair): one request
    −23.8%, the sealing pass −50.8%, the stream +12.8% steady and +17.1% amortized.
  - The Mac is now at 23.9 tok/s for one request (best 5.35 s), 33.0 for the stream steady (29.1 amortized) and
    33.7–34.2 proof only [MEASURED].
  - **The stream is now fork-bound:** about 2.6 s of sealing beside the forks against about 3.9 s of fork work per
    request.
- **A22 (running; D70, Victor 2026-11-06): production's resident-model stream form, target ≈33 proved tok/s**
  (`results/zk60_effplan_20261105/a22/`).
  - It is a long-lived prover over any `StackModel`. The export is loaded and checked once, the layer records are made
    once, and the blocks, GPU context and pools stay resident.
  - Requests come one per line and results go out one per line. Request r + 1's sealing pass runs beside request r's
    fork run, the harness's pipeline, with at most one sealed request waiting.
  - Byte-preserving per request: the same statement identity as `stack-prove`, and receipts `stack-verify` accepts
    unchanged.
  - Fresh randomness per request, and no witness or private value outlives its request.
  - H-1 per request; a refused request leaves the stream running.
  - A13's window stays behind its switch (D68's re-reading first).
- **A21 (running): host hashing** (byte-preserving; `results/zk60_effplan_20261105/a21/`).
  - Hardware SHA-256 in-tree on the stable aarch64 intrinsics, with runtime detection and `sha2` as the fallback; no
    new crate. `sha2`'s `asm` feature would regress x86's SHA-NI path.
  - A parallel BLAKE3 `BlockPublic::digest`.
  - Optionally, each fork's frame written as it finishes.
- **A20 done: production's per-request host work** (byte-preserving; `results/zk60_effplan_20261105/a20/`).
  - One request through production's function −50.1% in every pair on the merged tree (16.07 → 8.01 s); the agent's
    6-pass A/B −50.6% (15.49 → 7.65 s).
  - The sealing pass's loads run 4 layers ahead on their own threads (`HL_A20_LOADS`), the record's digest runs
    beside its SHA-256s (`HL_A20_RECPAR`), and the receipt is written by 16 threads (`HL_A20_WRITE`).
  - The profile: SHA-256 runs in software here. A19's "5× slower builds" was a clock artifact; the pass waited on its
    loads.
  - H-1 holds (D71).
- **A19 done: production's D55 path** (byte-preserving; `results/zk60_effplan_20261105/a19/`).
  - `stack-prove --d55-workers` runs `d55_seal_and_prove`. It proves with the sealing pass's own checked blocks
    (`HL_A19_SHARE`, on) instead of loading all 32 again. Independent A/B on the merged tree through production's
    function: one request −20.9% (19.3 → 15.3 s, 4 of 4 pairs). Byte-identical.
  - A13's window is now usable from production (`ForkPlan`, `SealedBlocks`, `Planned::check` before the run directory)
    but stays off: one request −0.4% at 16 and −1.0% at 32, for +10 to +30 GiB.
  - **Found:** production's one request is 15.3 s = 8.4 tok/s, against the harness's 5.4 s.
    - The sealing pass is 9.1 s, because each layer's load and record hashing slows the builds about 5×.
    - The receipt write is about 1.9 s and the preflight's re-hash 0.3 s.
  - H-1 reading: D68.
- **A18 done: the forks phase, round 2** (byte-preserving; `results/zk60_effplan_20261105/a18/`).
  - Two small forms, on by default:
    - the range and periodic table helpers read inverse tables already made (`HL_A18_TABINV`, 4.65 → 0.78 ms per
      block);
    - the preflight's record replaces `define`'s per-slot registry re-check (`HL_A18_REGISTRY`, fail-closed).
  - Independent A/B on the merged tree (4 passes, both orders, production's builder): one request −1.9% (4 of 4
    pairs), proof only +0.7%, stream +0.3%. Neutral within noise.
  - A13's split was ported onto A14–A17. On the fork-bound stream its window now pays in the harness: window 16 gives
    stream +5.0% steady (6 of 6) and one request −2.3%, for +12 GiB. It stays off by default until A19.
  - Two forms that added short parallel regions to every fork lost (+1.2% to +3.2%) and were removed. A11's pool
    width stays 6.
- **A17 done: the forks' host work in `protocol.rs`** (byte-preserving; `results/zk60_effplan_20261105/a17/`).
  - At a W16 profile, one-term lookups are read straight from their witness planes (`HL_A17_LOOKED`). The preflight's
    record of each block's public checks stands in for the fork's re-check of that very block object
    (`HL_A17_CHECKED`, fail-closed). Both are on by default; `0` restores the old code.
  - Independent A/B on the merged tree (4 passes, both orders, a quiet GPU): proof only −3.6% (4 of 4 pairs), the
    stream steady +2.6%, amortized +2.0%, one request −0.9%, system CPU −38%, page faults −42%.
  - Keeping each fork's A and H between blocks lost (+3.6%). That is the third zero-fill form to lose.
  - The Mac is now at 17.9 tok/s for one request (best 7.15 s), 30.6 for the stream steady (25.7 amortized) and 34.2
    proof only (best 3.75 s) [MEASURED].
  - **The stream is now sealing-bound:** about 3.9 s of proof per request against about 4.4 s of sealing beside the
    forks. A16 is next in line.
  - Left, largest first:
    - the A/H zero-fill, 14% of a fork's host time;
    - the store fold, 14%;
    - the helper inverses, 11%. The 2^16-entry range inverse tables are built twice;
    - the public weight folds in `define`, 11%;
    - randomness, 10%;
    - `define`'s per-slot registry re-check, which the same record could cover;
    - the bulk salt draw, which waits for Sol's `pcs.rs` work.
- Earlier plan text, kept for the record:
  - **A13, before-challenge work during the sealing pass.** A fork's work before its first transcript use (A's rows,
    A's commitment, the mask commitment) needs only its own block's witness. That is about 22% of a block [MEASURED,
    A1]. Done during the sealing pass, it could take up to about 0.8 s off one request [ESTIMATE]. Memory is the limit.
    A9 (boundary commits in parallel) goes with it.
  - **A14, the forks' remaining host work:** the private slots' tables, the transcript absorb of A's clear vectors, and
    the randomness fill.
- A10 is open.

**Phase A's expected result on the Mac:** one request about 7–8 s (16–18 tok/s), a stream about 22–25 tok/s
[ESTIMATE]. Every step is accepted only if the goldens, the six pinned digests and plane-for-plane equality hold.

### Phase B: the protocol changes, designed together, shipped as W16R3 (design 1–2 weeks, build 3–5 weeks)

**Ruled 2026-11-05 (D67):**
- W16R3 = **B1 + B2 + B3**, shipped together.
- **B4 is out.** The exact W16 word checks stay, and statement 1 stays as approved.
- **B5** joins only if its two gates pass by the freeze.
- **B6:** the study starts now; it joins W16R3 only if ready at the freeze.
- **Handoff:** `W16R3_HANDOFF_20261105.md` (Sol: the B1–B3 design note, then the build; Astra: the B6 study).
- **Sol's B1–B3 note is reviewed and accepted** (`W16R3_DESIGN_B1_B3_20261105.md`; the review is in the handoff).
  - **The modeled gain is smaller than the 2026-11-01 figure:**
    - the forks phase ×1.08–1.19 [MODEL], 8.6–18 ms of GPU service per block [ESTIMATE];
    - about 2–8% off one request;
    - the receipt 819 → about 767 MB;
    - the soundness rate 2^-103.02.
    The old ×1.44–1.64 counted rate 1/2, which W16R2 already has.
  - **Build order:** B1 (most of the saving, and B6's prerequisite), then B2, then B3, each behind its falsifier and an
    N = 6 A/B. If B2 or B3 measures no gain, Victor decides whether it stays in W16R3.
  - **The base for Sol's build** is posted in the handoff.
- **The B6 study is done** (`W16R3_DESIGN_B6_20261105.md`, by a Claude agent while Astra is out of compute).
  **Recommendation: not in W16R3; the next profile, in two steps.**
  - **Where today's 819 MB goes:** clear vectors 52%, opened column data 45%, Merkle paths 2% [MODEL, reproduced from
    the encoder].
  - **B6a** commits the clear vectors and proves their checks with a fold / code-switch tower: 387 MB [MODEL], with no
    new zero-knowledge argument.
  - **B6b** adds wide rows (2^18–2^20) and compact masks: 40–52 MB [MODEL], but costs +13 to +42 ms of GPU per block
    [ESTIMATE] and needs the tower's own zero-knowledge proof.
  - **Soundness:** both keep D59's δ/2 reading; the composed rate is unchanged at 2^-102.93.
  - **The Lean work:** 3–6 weeks for B6a, plus 3–6 for B6b [ESTIMATE].
  - **B1 stays in W16R3:** B6 needs it.
  - **Cheapest next experiment** (half a day, guarded), with kill rules: commit timings at log_cols 14, 18 and 20,
    and a stand-alone wide-row fold.

Each item first gets a design note and a census. Measurements come before code.

| # | Item | Expected | Notes |
|---|---|---|---|
| B1 | **Coefficient-form rows** (no inverse NTT) | −32 ms GPU per block, ×1.09–1.24 [MODEL] | Already studied; was deferred by Victor 2026-11-03 to a later profile |
| B2 | **Equal-size zero-check batching** (fewer claim points) | −8.5 to −14.5 ms per block, −6.7 MB of proof [MODEL] | |
| B3 | **Non-power-of-two F domain** (14,336) | −7.5 ms per block [MODEL] | |
| B4 | **Probabilistic matrix range checks** (FlashProve) | unknown, possibly the largest: a census of the limb and helper rows comes first | Needs soundness, completeness and refusal-leak analysis. The exact W16 checks stay as the baseline until it is proved |
| B5 | **LogUp-GKR** in place of the committed helper columns (H107–H116) | ×1.1–1.2 [MODEL, before later optimizations] | Designed with B4: both shrink H |
| B6 | **Recursive openings** (FlashProve fold-and-hop) | receipt 819 MB → under 50 MB target [ESTIMATE]; faster verifier | Its own PCS proof. The largest Lean change |
| B7 | **Cross-request batching inside one proof** | amortizes the per-proof fixed costs; size it from A1's census | Decide after A1 shows what is fixed per proof |

**Bundle expectation:**
- ~~B1–B3 alone model at ×1.44–1.64 on the GPU work per block [MODEL, 2026-11-01]. B4–B5 could add as much again, but
  that is unmeasured.~~ **Superseded 2026-11-05** by Sol's note: ×1.12–1.27 on the GPU service, ×1.08–1.19 on the
  forks phase [MODEL]. The old figure included rate 1/2, which W16R2 already has.
- ~~On the Mac, the W16R3 stream would be about 35–45 tok/s [ESTIMATE].~~ Superseded: the stream is now balanced
  between sealing and proving, so W16R3's forks saving alone moves it little.

### Phase C: the RTX 5090 (when the box is up; Victor's step)

- **C1:** the CUDA port of the Metal kernels, with per-fork streams and the tables built on the device.
- **C2:** **INT8 tensor-core witness products** (FlashProve's `products.cuh` directly).
- **C3:** the host path on the device (H125). It is the projected limiter there.
- **C4:** the Phase B profile on CUDA.
- **Expectation:** the target clock moves from 48–76 [MODEL] to ≥ 110 with Phase B and request streaming [ESTIMATE]. The
  first falsifiers to run on the box are the five in the 5090 handoff, §1.

## 4. The Lean proofs, meanwhile

- **New Lean proofs pause on every part Phase B changes:** the PCS and openings, the lookup and range checks, the
  zero-check batching. The M-opening proof under Fiat–Shamir was stopped on 2026-11-05 for this reason.
- **What carries over unchanged and stays merged:**
  - the approved statements (`Statements.lean`);
  - the generic Fiat–Shamir machinery: chains, wide digests, the composition, trees, paths;
  - the hiding and soundness lemmas for parts W16R3 keeps.
- **After W16R3's design freezes:** one round re-instantiates the composition at W16R3's rounds, proves the new parts
  (B4, B6), and then the remaining L2 premises. D63 still holds: nothing goes to production before its proofs.
- **Every Phase B design note must state:**
  - its per-round soundness errors against the 2^-100 target (the composed rate is the maximum; the floor is the
    zone sum, Part 9);
  - its refusal behaviour (refusals must stay challenge-only, D66);
  - how it hides, before code.

## 5. Who does what (proposed)

| Lane | Work |
|---|---|
| Claude (coordinator) | A1–A3, then A4 and A5; merges, checks and the status docs |
| Astra (it already holds the FlashProve context) | B4 and B6 design studies, and the census for B7 |
| Sol | A6–A8 (kernels, queues, Gram folding), then B1–B3 |
| Agents, as needed | parallel lanes in their own worktrees, under the guard |

## 6. Decisions for Victor

**Answered 2026-11-05 (D67):** (1) yes; (3) B4 no, B6 study yes; (2) the RTX 5090 date is still pending.

1. Approve the principle: byte-preserving work first, and every protocol change shipped together as one profile
   version (W16R3), with one re-proof and one re-gate.
2. The RTX 5090 box: Phase C cannot start without it. It is the largest single step toward 110.
3. B4 (probabilistic range checks) and B6 (recursive openings) are the FlashProve ideas with the biggest potential
   and the biggest new proof obligations. Start their design studies now?
