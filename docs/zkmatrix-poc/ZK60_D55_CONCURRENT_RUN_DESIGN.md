# D55 design draft: proving one run's blocks at the same time

**Status:** a DRAFT for Victor and the security owner to rule on (open question D55 in `ZK60_DECISIONS.md`). Nothing
here is built. It changes rule D12a ("a run is one transcript end to end"), so it would ship only as a new, opt-in
run profile: today's runs keep their bytes.

**Why.** On the Mac, one W16 8B block proof leaves the CPU almost idle. A profile found the rayon workers idle in 99%
of samples, and about 32% of the prover thread's time waiting on the GPU. Independent proofs run at once reach
[MEASURED, `results/zk60_metal_20261031/README.md` M10, M14, headline]:

| T | one block at a time | six at once |
|---|---:|---:|
| T128 | 11.1 tokens/s | 22.3 tokens/s |
| T256 | 13.2 tokens/s | 20.8 tokens/s |

Today one request cannot use that: its 32 blocks share one Fiat-Shamir transcript, so block k cannot start before
block k-1 has finished. This design would let one request reach the "six at once" figure, about 2x on this machine.

## Today's construction (D12a, `hashline/src/private_block/run.rs::prove_run_with`)

For k = 0 .. L-1, in order, on ONE transcript `tr`:
1. absorb `pb-run-stage` k and the block's digest;
2. commit the boundary plane B_k (block k's output, block k+1's input) and absorb its root, before any challenge of
   either adjacent equality slot;
3. `prove_core` for block k on `tr`. Its slot 21 raises claims on B_{k-1} (input) and its slot 22 on B_k (output),
   at points drawn from `tr`;
4. open B_{k-1} ONCE, with block k-1's slot-22 claims plus block k's slot-21 claims;
5. emit segment k.

Each block's challenges therefore depend on every earlier block's messages, which is what serialises the run.

## Proposed construction ("commit, fork, join")

**Phase 1 — commit every boundary first, on the run transcript `tr`.**
- Run the witness through all L blocks: the source already computes the boundary planes.
- Commit B_0 .. B_{L-2} and absorb all their roots, in order, plus a phase label.
- Call the resulting state S0. Every boundary is now fixed before any block challenge exists.

**Phase 2 — prove the blocks concurrently, each on its own fork.**
- Block k's transcript is `fork(S0, k)`: a clone of S0 that absorbs `pb-run-fork`, k and the block's digest before
  anything else (domain separation by index).
- `prove_core` runs on it exactly as today and raises its boundary claims at points from its own fork.
- Each fork's prover randomness comes from the run's OS stream split per block. A domain-separated child stream per
  k keeps the blocks' masks independent; privacy is unaffected in principle, since every mask stays fresh.

**Phase 3 — join and open.**
- Absorb into `tr` (from S0), in block order: every block's final fork state, and every boundary claim value it
  raised. Call the result S1.
- Open each B_k once, with its claims from both sides, using challenges drawn after S1.
- Open the run's two endpoints the same way.

**The verifier mirrors it.** It absorbs the boundary roots, forks per block and verifies each block (which can also
run in parallel: a faster verifier), then joins and checks the openings.

## Soundness sketch (for the security owner to check, not a proof)

1. **Every boundary root is fixed before any challenge that a claim on it depends on.** This is the property D12a's
   step 2 secures, and it is kept: all roots are in S0.
2. **Each block's sub-proof is a Fiat-Shamir transform over a transcript prefixed by S0 and its own index.** Its
   soundness error is the same per-block error as today (the D24-class accounting per block).
   - A cheating prover can grind one fork independently. It could grind block k in today's chain too, so the
     per-block grinding bound does not change.
   - The run's error is still bounded by the sum of the per-block errors plus the openings', as D12a's accounting
     already sums them.
3. **Mix-and-match.** A prover could produce several candidate proofs of block k and choose one after seeing the
   others.
   - Every candidate must verify on its own against the fixed roots.
   - The openings are drawn after S1, which binds the chosen candidates' final states and claim values.
   - So choosing among valid candidates gains nothing that grinding one block would not.
   - **This is the point the review must check carefully**, including the hosted-claim batching and the "one
     reserved pair per claim site, opened exactly once" rule, which carries over unchanged.
4. **Zero knowledge.** Each block keeps its own CFS masks and hiding commitments. The boundary openings are the same
   openings as today, joined at S1 instead of interleaved. No new value is revealed, but the plane list and the
   opening order change, so the privacy statements need a re-check.

## What would have to be ruled and reviewed

- **Victor:** amend D12a for an opt-in run profile, with its own profile string and receipts.
- **Security owner:**
  - the soundness accounting above, especially point 3;
  - an independent review in the D24 class;
  - malicious-receipt controls: a fork-index swap, a stale fork state, a boundary root absorbed after a fork, a
    claim raised on a fork but not joined.
- **Privacy re-check:** the opening order and the per-block randomness split.

## Implementation plan (once ruled)

1. **A run profile flag and a receipt format.** The joined openings move to a run-level tail; segments carry their
   fork's start and end tags.
2. **`prove_run_with_forks`:**
   - phase 1 over all boundaries;
   - phase 2 on a thread pool of N block provers, one shared Metal context (the M10 harness already proves N blocks
     at once in one process, all byte-identical to solo proofs);
   - phase 3 joins.
3. **Memory.** All L boundary planes and up to N block witnesses are resident at once: about N x 5 GB at W16 8B T128,
   fine on 256 GB.
4. **The verifier mirror,** forks verified in parallel.
5. **Gates:**
   - today's runs byte-identical, since the new path is opt-in;
   - the new profile's own goldens, malicious controls and soundness tests;
   - an A/B of one request at N = 1, 2, 4 and 6.

**Expected [MODEL]:** one request at about the concurrent figure on this Mac (about 20–22 proved tokens/s), and on a
5090 whatever its concurrent ceiling turns out to be.
