# Proof Efficiency Analysis

Where the prover and verifier time goes today, and the ranked list of
changes that would move the numbers. Covers both tracks: the pairing-based
zkMatrix reproduction (`zk_matrix`, `zk_matrix_fast`, `zkmatrix-rs`) and the
lattice track (`zk_lattice`). Written July 2026, after the review-note
P0/P1 fixes landed (decoupling challenge, setup-digest binding).

## Where the time goes now

### Pairing track (BLS12-381 structured backend)

Measured shape at `n = 1024` (Apple Silicon, from
`docs/zkmatrix-poc/results/`): batched ZK prover fits
`36.65 s + 0.253 s * t` for `t` same-shape claims, i.e. ~0.29 s amortized
per claim at `t = 1024`; marginal verification ~2.7 ms per claim; setup
(SRS generation) 163 s; SRS ~150 MB.

Cost structure per batch:

- **Fixed cost (36.65 s)**: the three length-`n^2` projection sub-proofs.
  Each is a Bulletproof-style IPA whose per-round work is one MSM over the
  surviving half of the bases, plus one KZG opening (a length-`~3n^2` MSM
  for the quotient polynomial). MSM is the bottleneck, not field work.
- **Marginal cost (0.253 s / claim)**: one length-`n` ZK product sub-proof
  per claim (the paper's Algorithm 6 leaves these unbatched, lines 15-16),
  plus the per-claim commitments `C_d, C_ay, C_by` and their blinds.
- **Verifier**: each sub-proof costs `O(log n)` hashing plus one pairing
  check (2 Miller loops); a `t`-claim batch does `3 + t` sub-proof
  verifications, so pairings dominate at large `t`.
- **The P0 decoupling-challenge fix is not a cost item**: one extra hash
  and one scalar multiplication per sub-proof, plus one coefficient
  multiply while building projection specs. Not measurable against MSM.

### Lattice track (Route Z, pure Python reference)

Measured at toy sizes (`n = m = 16`, `N = 64`, `r = 4`):
Pi1 prove ~0.25 s, verify ~3 ms; Pi2 prove ~0.35 s, verify ~4 ms; proofs
2.5-5 KB (toy; the reference `n = 1024` sets give 2.4-6.6 MB).

The Python prover is **sampling-bound, not algebra-bound**: discrete
Gaussian sampling for one proof's masks costs ~0.084 s, and the expected
`M ~= 2.76` rejection restarts bring that to ~0.23 s of the 0.25 s total.
The verifier does only matvecs against `G1`/`G2` and is already at
millisecond scale. This matches the report's Section 13 analysis: in a
native implementation everything expensive is a GEMM-shaped product
against `G1`/`G2`, and commitment (one-time, amortized) costs 25-100x the
bare matmul at Route Z parameters.

## Ranked improvements — pairing track

1. **Aggregate the KZG opening checks with one multi-pairing.**
   Verification of a `t`-claim batch currently runs `3 + t` independent
   pairing checks. Standard batching: draw one Fiat-Shamir scalar, take a
   random linear combination of all `(C_i - v_i G, W_i)` pairs, and check
   a single 2-Miller-loop equation. Verifier cost per batch drops from
   `~2(3 + t)` Miller loops to 2, i.e. the ~2.7 ms marginal verify becomes
   microseconds of G1 arithmetic plus one shared pairing. Low risk; purely
   verifier-side.

2. **Fixed-base MSM precomputation for the SRS windows** (roadmap step 4,
   still open). The SRS powers are reused by every proof, so Pippenger
   with precomputed windows (or a full fixed-base table at 2-8 GB for
   `n = 1024`) typically buys 2-4x on the dominant prover MSMs — both the
   IPA round messages and the KZG quotient openings. This attacks the
   36.65 s fixed cost directly.

3. **Batch the `t` product sub-proofs as fused kernels** (roadmap step 5).
   The per-claim 0.253 s is `t` independent length-`n` IPAs, each with
   `log n` rounds of small dot products, folds, and two G1 points. Keeping
   the per-instance transcripts (required for fidelity to Algorithm 6) but
   scheduling all `t` instances' round-`j` work as one batched row-wise
   kernel converts the marginal cost from `t` latency-bound passes into
   GEMM-shaped throughput work — and the KZG witnesses for all `t`
   openings can share one MSM pass over the low-degree `AY/BY` window.

4. **GPU MSM (ICICLE or similar)** (roadmap step 6). After items 2-3 the
   prover is still MSM-bound; GPU MSM is the remaining order of magnitude.
   Only worthwhile after the fixed-base tables exist, because the two
   optimizations overlap.

5. **Streaming/seeded witness prover** (roadmap, Table 3 RAM claim).
   Regenerate witnesses from seeds and aggregate into one length-`n^2`
   buffer per projection instead of holding all `t` dense witnesses
   (~96 GB at `t = 1024`). Does not change time, but it is the gate on
   replicating the paper's 304 MB figure and on running `t = 1024` at all.

6. **Small verifier hygiene wins**: cache `G2Prepared::from(tau_g2)` and
   the generator preparation once per SRS instead of per sub-proof; reuse
   the recomputed `y`/`rho` challenge material across the four sub-proof
   verifications (already partially shared).

Not recommended: collapsing the four sub-proofs' base families to share
SRS windows more aggressively. The review notes flag footnote 7's
disjointness requirements; within-family sharing is fine, cross-sub-proof
sharing of `U', G', H'` is not.

## Ranked improvements — lattice track

1. **Route R (cyclotomic ring lift)** — the report's own headline number.
   Replacing `Z_q` with `R_q = Z_q[X]/(X^d + 1)`, `d = 128`, makes the
   challenge set exponentially large (ternary-coefficient polynomials), so
   `r` drops from 26-37 to 1, norms lose their `2^b` factors, `q` drops to
   one limb, and all kernels become NTT-batched. Proofs shrink from
   megabytes to 50-150 KB. This is one to two orders of magnitude on both
   size and prover time, and it is design work only at one point: applying
   the arbitrary `Z_q`-linear map `A` inside Pi1 needs the
   negacyclic-block or trace techniques of ALS20/LNP22.

2. **Native backend with GEMM-shaped commit kernels.** The report's
   Section 13: batch the `r` repetitions' mask commitments into one
   `(k + n) x N` by `N x 2r` product, expand `G1/G2` from seed in
   streamed panels, use the small `b`-bit width for the homomorphic
   `sum v_j T^(j)` combinations. The C/Rust backends in this repo are the
   natural place; the Python package stays as the differential-test oracle
   (same role Route Z plays for Route R).

3. **Faster Gaussian sampling.** The Python prototype's window-rejection
   sampler needs ~10 iterations per coordinate and pays a high-precision
   `exp` on each; a CDT or Karney sampler is ~1 iteration, and only the
   final Lemma 6.3 accept decision needs the 128-bit fixed-point care.
   In the current prototype this is the entire prover bottleneck.

4. **Rejection-rate tuning.** `alpha = 12` gives `M ~= 2.76` expected
   restarts. Raising `alpha` lowers `M` but grows `sigma`, hence norms,
   hence `q` (C2) — the report's knob table says the optimum sits where
   `log q` crosses a machine-word boundary. Bimodal-Gaussian masking
   (BLISS-style) would halve `sigma` at the same `M` if the added
   implementation risk is acceptable later.

5. **Folding for succinctness** (LaBRADOR / Greyhound). The `r * N`-linear
   proof sizes and linear verifier are the entry point; folding compresses
   proofs of many products to tens of kilobytes and gives a succinct
   verifier. Only worth starting after Route R, since folding operates
   over the same module-SIS commitments.

## Cross-track notes

- **Amortization is the pairing track's real asset**: 0.29 s/claim at
  `t = 1024` already beats the paper's estimated 0.50 s/claim, and items
  1-3 above plausibly bring the batch fixed cost under 10 s and marginal
  verification to sub-millisecond. The lattice track's asset is
  transparent setup plus post-quantum binding at seconds/proof with a
  clear path (Route R) to competitive sizes.
- **Report both comparison baselines.** Against modular matmul the Rust
  toy prover is already sub-crossover at `n >= 2048`; against float32
  GEMM the gap remains 500-70,000x depending on batch size. Only quoting
  the former overstates practicality (review notes, Section 1).
- **Shared engineering**: both tracks' provers reduce to batched
  fixed-operand linear algebra (MSM with fixed bases / GEMM against fixed
  `G1,G2`). A common batching/scheduling layer and a common transcript
  abstraction would let the backend swap (pairing -> lattice) stay a
  backend change, as the review's two-track strategy recommends.
