# Q2/Q3 tranche progress (worktree notes; remove before merge to main)

## SCOPE CHANGE (from coordinator, binding)
U3 (A1 aux-modulus NTT) is DROPPED from this agent's scope: a dedicated
parallel agent implements it in zkmatrix-rs/src/bin/aux_ntt.rs. Do NOT
implement aux-NTT kernels and do NOT touch aux_ntt.rs. At the U5 gate,
mark A1 rows in results tables as "pending -- see A1 agent"; parent
session reconciles at merge.
Remaining scope: U1 (Q3 k=8 split), U2 (Q2 digit decomposition + k/q
coupling frontier), U4 (Karatsuba on halves), U5 (measurement gate).

Mission: RING_MULT_BOTTLENECK.md Q2 (digit decomposition), Q3 (k=8 split),
A2 (Karatsuba), measurement gate (U5).
Build: PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release
Suite: PATH=... python3 -m unittest discover -s tests  (must stay 37/37; ring_lattice NOT in suite, run its self-test manually)

## Done
- [x] Merged perf/zk-batch-optimizations (fast-forward to c731832).
- [x] Read RING_MULT_BOTTLENECK.md, ROUTE_R_DESIGN.md, ring_lattice.rs,
      route_r_params.py, LLM_SCALE_ESTIMATE.md. Baseline self-test green.
- [x] U1a (commit 41ecc6a): route_r_params.py k_split_study(): residue
      classes (k=8 <=> q = 17 mod 32), q8_31 = 2^31 - 399 = 2147483249
      (eta = 2056890868), q8_46 = 2^46 - 1103 = 70368744176561
      (eta = 49533544627797), irreducibility verified, LS18 frontier:
      k=8 margin 1.30x @2^31, 4.76x @2^46; min q for k=8 is 2^28.0;
      k=16 needs q > 2^64 (out). Slot-root leaf order eta^[1,9,5,13,3,11,7,15].
- [x] U1b: ring_lattice.rs: Zq + RingCtx generic layer (butterfly k-way
      split/merge from primitive 2k-th root), ring_mul_split, poly_mul_g,
      slot_inv_g/poly_inv_g, generic Sigma round (prove/verify_opening_g,
      verifier ring-mult via split kernel). Self-test sections 10-11:
      k=2-generic == legacy kernel, 25x split-mul vs schoolbook @q8, 100
      challenge-diff inversions @k=8, zero-divisor control, 8-slot
      Hadamard, full tamper battery at k=8. ALL GREEN.

- [x] U2a: route_r_params.py derive_q2/q2_frontier: digit-decomposition
      model (design rationale in module comment), Pi2-2048 frontier:
      e=2: minq 2^29.5 L=6; e=3: 2^30.0 L=4; e=4: 2^30.5 L=3 (proof
      169.8 KB, +52.8 vs q46 baseline 117.0); e=6/8 exceed q31. Coupling
      table: C2 floor 2^29.5 > k=8 LS18 min 2^28.07 => (k=8, q8_31,
      e in {2,3,4}) jointly feasible; k=16 infeasible. kappa 15->8-9,
      N_r 54->40 at q31 (feeds commit-bill revision).
- [x] U2b: ring_lattice.rs section 12: DigitParams (conc discipline +
      restart rule), balanced digit decompose, per-digit statements +
      shared-challenge Sigma bundle + joint rejection; verifier checks
      recombination, bundle norm (stand-in for ct-range claims, flagged),
      per-digit equations on split kernel. Battery: wrong digit / out-of-
      range-but-recombining digits / recombination mismatch (honest rounds
      on wrong witness) / wrong ctx / +q overflow. Demonstrated: same
      witness UNdecomposed needs q > 2^33.9 (violates C2 at q8), digit
      chain fits with 2.5 bits headroom. ALL GREEN. 37/37 suite green.

## Next
- [ ] U3: DROPPED (see scope change above; A1 handled by parallel agent).
- [x] U4/A2: generic recursive Karatsuba (correctness ref) + fixed-buffer
      Karatsuba (kara64 depth-2 / kara16 depth-1, i128 lazy, single final
      reduction) + amortized-split GEMM commit kernels (rows pre-split per
      CRS, columns split per commit, one merge per output row). Section 13
      benchmarks (min-of-batches timing, 3 consistent runs):
      ring mult us: naive 12.2-12.8 / k2 5.7-6.2 (2.1x) / k2+Kara 4.3-4.6
      (2.8x) / k8 3.9-4.1 (3.1x) / k8+Kara 4.2-4.4 (2.9-3.0x).
      commit kernel us/ring-MAC (8x26): naive-ternary 9.0-9.4 / k2 6.2-6.5
      (1.45x) / k2+Kara 2.5-2.6 (3.6x) / k8 1.9-2.0 (4.7x) / k8+Kara
      1.10-1.17 (8.1x, ~9e5 ring-MACs/s). Karatsuba pays in GEMM (lazy
      i128 across columns), not in single mults; A1 rows marked pending.
      ALL GREEN.
- [ ] U5: results into RING_MULT_BOTTLENECK.md; reconcile
      LLM_SCALE_ESTIMATE.md + ROUTE_R_DESIGN.md (mark superseded); state
      15s-gate verdict; A1 rows marked "pending -- see A1 agent".

## Key decisions
- k=8 residue class: q = 2k+1 mod 4k = 17 mod 32 (v2(q-1) = 4, primitive
  16th roots exist; slots X^16 - eta^odd, eta = primitive 16th root).
- LS18 bound (as used in ROUTE_R_DESIGN): q^(1/k)/sqrt(k), must be > 4
  (quinary diffs). Min q for k=8: (4*sqrt(8))^8 = 2^28.0. k=16 needs
  q > 16^16 = 2^64: out of single-limb range => k=8 is the max useful k.
  NOTE: RING_MULT_BOTTLENECK's "~10-13 at q31" is wrong; actual 5.19
  (margin 1.30x). Report exactly.
- Q2 mechanism (documented in U2): decompose the *norm-carrying witness*
  (stand-in for Pi2 combined responses) into base-2^e digits with separate
  digit statements t1_i = A1 rho_i and per-digit sigma rounds sharing one
  challenge; beta then scales with 2^e instead of the combination norm;
  q > 8*beta drops to ~2^28-2^31. Digit count L enters proof size.
- A1 (descoped to parallel agent; kept for context): protocol q untouched;
  products computed exactly over aux NTT primes, reduced mod q at the end.
