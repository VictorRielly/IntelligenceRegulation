# Route R protocol-build tranche — progress notes

Working directly on branch `perf/zk-batch-optimizations` (no worktree; session
works in place). This file is removed before the final merge commit, per repo
convention.

Build command (snap cargo is broken on this box):

    PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release

Test suite: `python3 -m unittest discover -s tests` in ~/IntelligenceRegulation.

## Scope

Full Route R protocol build, U1-U8 of `docs/zkmatrix-poc/ROUTE_R_DESIGN.md`
§6, at the recommended operating point from the Q2/Q3 + A1 tranches:

- d = 128, k = 8 split, q = q8_31 = 2^31 - 399 (= 17 mod 32), eta = 2056890868
- quinary challenges (|C| = 5^128), LS18 margin 1.30x (tight — re-verify on any change)
- digit-decomposed openings, e in {2,3,4} (e = 4 default for proof size)
- A1 aux-NTT (Goldilocks) commit/GEMM kernels via shared `aux_ntt_core.rs`,
  automatic regime dispatch (P0 capacity line)
- Module layout per design §6: `src/ring/{mod,params,commit,sigma,ct_engine}.rs`
  + `src/bin/ring_matmul.rs`, `#[path]`-shared like `manifest.rs`
- Route Z (`lattice_matmul.rs`) is the differential oracle and is NOT modified
- Implementation order: U1 -> U2 -> U3 -> U4 -> U6 -> U5 -> U7 -> U8

## Unit status

- [x] U1 ring arithmetic module (`ring/mod.rs`) + differential tests (commit 7b58d96)
- [x] U2 params port (`ring/params.rs`) + commit/opening (`ring/commit.rs`, `ring/sigma.rs`)
      — port pinned to the script tables (kappa/N_r/L/headroom/proof-KB parity);
      opening + digit rounds with full prototype tamper batteries; same-seed
      School/A1 transcript identity; extraction test
- [x] U3 ct-engine (`ring/ct_engine.rs`) + ARP — linear ct-claims (g-before-
      theta ordering, h reveals, combined mask images W_l, joint Sigma round,
      per-slot extraction), Ajtai-slot (ABDLOP) commitments for norm-grounded
      witnesses, JL-projection ARP with parameterized Q4 constants.
      NEW FINDING (asserted in the self-test): the binary-gadget ARP
      side-condition budget does NOT close at q31 with conservative
      constants (extract 2^22.1, needs < 2^15-class); it closes at q46.
      Gadget-layer consequence handled in U6 (exact/chunked strategies or a
      q46 gadget budget); Q4 lemma write-up flagged in ct_engine.rs header.
- [x] U4 ring-Pi1 + negative battery — implemented as option (a) (R-linear
      A: ring-coefficient maps), r = 1: quinary-v column compression with
      digit-decomposed openings of the combined commitments (generalized
      ct-round now supports digit openings + ring-valued claims), rows_r
      ring-valued claims, ~100 KB proofs, prove 38 ms / verify 6 ms at the
      256->128 x 64 demo.
      Q1 FINDING (recorded in bin/ring_matmul.rs header comment): option (b)
      as designed — general A with theta compression over v-combined
      commitments — does not type-check (ring challenges don't commute with
      general A); costed alternatives documented; critical path unaffected
      (Pi2 + structured gadget maps). Full write-up due in U8 docs.
- [ ] U6 gadget family (binary/range/rescale ct-claims; k=8 slot Hadamard)
- [ ] U5 ring-Pi2 gate (ct-engine product layer; r_g fallback behind flag)
- [ ] U7 manifest/chain integration + wave batching + Z-oracle chain demos
- [ ] U8 parameter freeze + estimator note + perf pass + docs

## Decisions

- ring/ modules shared via `#[path]` (repo convention, per design §6);
  `bin/ring_matmul.rs` grows one self-test section per unit.
- ct_engine.rs declared as stub from U2 so the module tree is stable.
- Digit-round range checks: bundle-norm stand-in until U6 wires exact
  ct-range claims (same staging as the prototype, documented in sigma.rs).

## Next

- U4: ring-Pi1 (option b A-map) on top of the ct-engine: column compression
  with ring challenges, theta output-compression, ct-form via sigma_{-1};
  study lattice_matmul.rs prove_pi1/verify_pi1 for the statement shape and
  transfer the negative battery.
