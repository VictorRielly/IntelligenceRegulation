# Remediation and integration plan

This sequence is ordered by dependency, not by ease. GPU work may proceed as a
separate exploratory branch, but it should not become the integration critical
path before phases 1–5 close.

## Phase 0 — Preserve the interrupted work

1. Record/bundle all four reachable tips: U-K8, U-K9, U-K9 baseline parent, and
   test hygiene.
2. Save the two live documentation diffs and the 32-line U-K9 residue
   separately.
3. Keep clean `e8fa777` immutable as the benchmark/review baseline.
4. Do not merge the live U-K9 residue; it currently fails to compile.

Exit: another clone/worktree can reproduce every reviewed snapshot by hash.

## Phase 1 — Restore a valid ZK implementation boundary

1. Replace SplitMix/public transcript-derived prover secrets with an injected
   `CryptoRng` seeded from OS entropy.
2. Make proof-session nonce generation explicit and bind the nonce before every
   commitment/challenge edge that depends on it.
3. Consume mask/blinder objects; remove the `Cell<bool>` security claim.
4. Recompute `h0_lkp` in the verifier and remove it from prover-controlled proof
   data.
5. Repeat the histogram-recovery battery against:
   - fresh secret masks (must fail),
   - reconstructed/reused masks (attack must succeed in the broken harness),
   - the production API's attempted duplicate session (must be refused or
     cryptographically impossible), and
   - two separate processes.
6. Have an independent cryptographer review the Q4.7–Q4.9 adaptation and its
   Fiat–Shamir composition claim.

Exit: a verifier process accepts an honest proof and the exact public-mask,
same-seed, free-h0, stale-h0, and reuse attacks all reject at the API boundary.

## Phase 2 — Replace Statement v2 with enforceable integer semantics

1. Freeze raw integer encoding and scale-exponent conventions in a typed spec.
2. Enforce rescale scale propagation even when a range proof narrows magnitude.
3. Represent signed bounds asymmetrically or check positive and negative bounds
   separately.
4. Bind an exact typed table spec, not merely a nonzero digest.
5. Validate DAG topology, nonempty operations, orientation, source/weight roles,
   output visibility, modulus capacity, and canonical padding.
6. Disable bare `ClaimManifest::digest()` outside migration tests.
7. Port structured, lattice, ring, inventory, and chain paths to the same
   statement type.

Exit: negative tests cover inconsistent fraction bits, `+2^(w-1)`, cycles,
empty add, wrong table digest/scale, dangling roles, and noncanonical padding.

## Phase 3 — Build an actual proof artifact

1. Define canonical `PublicStatement`, `ProverInput`, `Proof`, and
   `VerificationError` types.
2. Serialize with lengths, versioning, canonical field encodings, and resource
   limits.
3. Run verifier in a fresh process from only statement bytes, proof bytes, and
   verified setup.
4. Fuzz/truncate/reorder every proof component; verifier must return errors and
   never panic.
5. Derive the model digest from architecture, quantization/table spec, and all
   weight commitments.

Exit: canonical byte size and independent verifier p50/p95 are measured, and no
prover-local value is available to verification.

## Phase 4 — Prove one complete caller-supplied FFN layer

Implement and bind:

```text
gate_acc = Wg * X
gate     = requantize(gate_acc)
up_acc   = Wu * X
up       = requantize(up_acc)
act      = SiLU(gate)
hidden   = act o up
out_acc  = Wd * hidden
out      = requantize(out_acc)
```

Use real frozen weights and caller-provided activations. Include every range,
link, padding, and output-visibility edge in the statement. Run boundary
vectors (`-128`, `127`, accumulator extrema, rounding remainders), not only
random vectors.

Exit: one layer verifies end-to-end and every edge has a targeted tamper test.

## Phase 5 — Redesign target-scale range and aggregation

1. Treat q46's 96% time share and restart coupling as the primary performance
   problem.
2. Evaluate range-lookup/alternative range arguments with full commitment,
   masking, transcript, and verifier costs—not a core-only model.
3. Lift the q31 C2 cap or aggregate block proofs so fixed per-block masks,
   tables, openings, and transcripts do not scale 176,832 times.
4. Serialize and measure a full `512x11008` layer, then 32 layers.
5. Enforce the 256 KiB proof and 2 s verifier budgets as hard gates.

Exit: an actual full pass, not a linear extrapolation, fits memory; proof bytes
and verifier time meet the contract or the contract is explicitly revised.

## Phase 6 — Integrate U-K9 safely

1. Merge clean U-K9 into a dedicated branch based on U-K8/remediated HEAD.
2. Resolve the dispatcher conflict by retaining both batteries.
3. Review the overlapping `lookup.rs` change manually.
4. Add reduction boundary, maximum-accumulation, forced-portable, and
   sanitizer tests.
5. Add a runtime capacity gate; do not rely on `debug_assert!` for arithmetic
   safety.
6. Measure `2^23` only after the committed masked path can use that scale.
7. Produce the missing kernel report with raw logs.

Exit: combined full suite, new security tests, and committed-chain A/B benchmark
are green; the live interrupted patch is either completed separately or
dropped with its diff preserved.

## Phase 7 — GPU implementation

Port only the frozen CPU reference. Require exact CPU/GPU transcript identity,
named hardware/software, transfer-inclusive timing, host/device peak memory,
secure randomness, p50/p95 warm runs, cold start, proof bytes, and independent
verification.

Exit: the measured end-to-end proof—not multiplied assumptions—meets the target.

