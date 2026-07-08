# Route R design spike — progress log

Branch: worktree branch merged with perf/zk-batch-optimizations (HEAD contains
96dad77 via fast-forward; verified).

## Plan of units
1. [done] Required reading: lattice report Sections 7.5/10/11/17 (extracted from
   the PDF), M2_REPORT, LLM_SCALE_ESTIMATE, PROVER_OPTIMIZATIONS Tier 2,
   lattice_matmul.rs (Params/derive_params_gadget, Pi2 prover structure, wave
   scheduler, statement hashing, manifest).
2. [done] PROGRESS.md + plan commit.
3. [done] Deliverable 2: zkmatrix-rs/src/bin/ring_lattice.rs (883 lines,
   auto-discovered bin, no Cargo.toml change needed). ALL self-tests pass:
   ring arithmetic vs CRT cross-check, 200 challenge-difference inversions
   (worst linf 4), zero-divisor negative control, 2-slot Hadamard, full
   opening-proof round valid + tampered response/first-message/context/
   statement + (+q) norm-overflow (caught only by the exact-integer norm
   check), honest-case extraction recovers rho exactly via LS18 inversion.
   Derived params asserted in-code: kappa=8, N_R=26, msg_r=2, sigma=2^17.4,
   beta=2^24.6, q > 8 beta (3.4 bits headroom), C3 k_Z=912<=1024, C4 ok.
   Approx timings (shared machine, single-thread, naive kernels): ring mul
   18-31 us; commit (256 slots) 5-15 ms; prove 55-105 ms (4 attempts,
   M=2.76 geometric); verify 11 ms. Proof ~15 KB at r=1.
4. [todo] Parameter re-derivation script (scripts/route_r_params.py): ring
   analogues of C0-C4, worked table at demo shapes + n=2048, worst-case vs
   concentration norm columns. Output feeds the design doc Section 3.
5. [todo] Deliverable 1: docs/zkmatrix-poc/ROUTE_R_DESIGN.md (ring/modulus,
   challenge set + soundness accounting replacing r(b-2)>=256, parameter
   tables, Pi1 A-map decision, CRT-slot elementwise mapping, migration plan,
   open questions ranked + projected numbers).
6. [todo] Full python test suite green (36/36), final commit + final message
   (Deliverable 3: open questions ranked, implementation order, projected
   numbers for M2 gadget/element and n=2048 Pi2).

## Key design decisions (made during unit 1, carried through)
- d = 128, q ≡ 5 mod 8 (two-way split) as mandated; q single-limb.
- FINDING: plain ternary challenges at d=128 (|C| = 3^128 = 2^202.9) FAIL the
  report Section 7.5 Fiat-Shamir budget (Q+1)^2 · eps <= 2^-128, which needs
  per-challenge knowledge error <= 2^-256. Proposal: quinary coefficients
  {-2..2} (|C| = 5^128 = 2^297.2) => post-FS error 2^-168; LS18 invertibility
  needs only q > 32 for the +-4 differences. Fallback: d=256 ternary.
- LS18 (two-way split): every nonzero y with ||y||_inf < q^(1/2)/sqrt(2) is
  invertible; at q = 2^31-19 the bound is 32767.9 >> 4. Verified in prototype
  by CRT-slot nonzeroness + explicit ext-gcd inversion.
- Pi1 A-map: recommend (b) coefficient-domain with ct()/theta-batching
  (uniform Z_q combination rows l = ceil(256/log2 q), sigma_-1 packing);
  negacyclic-block embedding (a) only for structured public maps. Subtlety
  found: a single Z_q-scalar output cannot carry 2^-256 soundness; need l
  uniform-theta combinations (l ~ 6-9) or ring-valued compressed claims.
- Pi2 gate over the ring: ring products of packed vectors compute
  cross-correlations; only ct() coefficients are the true Z inner products.
  Gate becomes ct-claims via the same ct-engine as Pi1's A-map.
- Elementwise (M2 mandate): binary/range/rescale via LNP22 sign-definite
  trick (<x, x-1>_Z = 0) in dense coefficient packing — near-native.
  General Hadamard: three costed options (2-slot CRT packing, Sidon/B2
  coefficient packing ~12/128 density, k=8 partial split variant q ≡ 17 mod
  32); see doc Section 5.
- Prototype params (derived, C0-C4 ring analogues): kappa=8, N_r=26, msg_r=2,
  sigma≈2^17.4 (worst-case T1 discipline), beta≈2^24.6, q > 8*beta with ~3.4
  bits headroom.

## Environment notes
- cargo: PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH"
- tests: python3 -m unittest discover -s tests (36/36 must stay green)
- Do not modify lattice_matmul.rs or shared modules; new files only.
- PDF text extracted to /tmp/lattice_pdf_text.txt via /tmp/extract_pdf.py
  (zlib streams + Tj/TJ regex); Sections 7.5, 10, 11, 17 read.

## Status
Units 1-2 done. Starting unit 3 (prototype).
