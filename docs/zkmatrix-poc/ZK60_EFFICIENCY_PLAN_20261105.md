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

| A10 | **Register W16R2 for real content.** The registered profile is R13, whose blocks commit about 1.8× W16R2's rows (census: A 4,577 against 2,501; H 4,390 against 2,602). Astra measured a trained 26-block Shieldstral R13 stack at 9.9 s of proof, against 5.1 s for the synthetic 32-block W16R2 stack (`results/zk60_astra_20261026/flashprove_effplan_runtime_20261105/REPORT.md`) | about ×1.8–2.4 per block on real models [INFERRED from those two runs, which differ in width and weights] | the W16R2 privacy gate on GPU-made bundles, the D60 conditions, then a ruling by Victor |

**Phase A's expected result on the Mac:** one request about 7–8 s (16–18 tok/s), a stream about 22–25 tok/s
[ESTIMATE]. Every step is accepted only if the goldens, the six pinned digests and plane-for-plane equality hold.

### Phase B: the protocol changes, designed together, shipped as W16R3 (design 1–2 weeks, build 3–5 weeks)

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
- B1–B3 alone model at ×1.44–1.64 on the GPU work per block [MODEL, 2026-11-01]. B4–B5 could add as much again, but
  that is unmeasured.
- On the Mac, the W16R3 stream would be about 35–45 tok/s [ESTIMATE].

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

1. Approve the principle: byte-preserving work first, and every protocol change shipped together as one profile
   version (W16R3), with one re-proof and one re-gate.
2. The RTX 5090 box: Phase C cannot start without it. It is the largest single step toward 110.
3. B4 (probabilistic range checks) and B6 (recursive openings) are the FlashProve ideas with the biggest potential
   and the biggest new proof obligations. Start their design studies now?
