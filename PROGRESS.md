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

## Next
- [ ] U1a: route_r_params.py: q8 search (q = 17 mod 32 <=> LS18 k=8 class),
      irreducibility verification (Lidl-Niederreiter for X^16 - s), LS18
      (k, q) frontier table. Pick q8 ~ 2^31 and 46-bit variant.
- [ ] U1b: ring_lattice.rs: generic-modulus ring ctx, 8-way butterfly
      split/merge + slot mul, cross-check vs schoolbook at q8, LS18 margin
      print, generic Sigma opening round at q8/k=8 + tamper battery.
- [ ] U2: digit-decomposed opening round (witness digits, per-digit sigma
      w/ shared challenge, recombination check; tamper: wrong digit, digit
      out of range, recombination mismatch) + params script (k, e) frontier.
- [ ] U3: DROPPED (see scope change above; A1 handled by parallel agent).
- [ ] U4: Karatsuba on deg-64 halves (recursive, cutoff 16) folded into
      ring-mult + commit-kernel benchmarks (methods: naive / k2 / k2+Kara
      / k8 / k8+Kara; amortized-split GEMM commit kernels for k2/k8).
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
