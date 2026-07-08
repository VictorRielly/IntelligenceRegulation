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
- [ ] U3 ct-engine (`ring/ct_engine.rs`) + ARP
- [ ] U4 ring-Pi1 (option b A-map) + negative battery
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

- U3: ct-engine (theta batching, g/h masks with ct(g) = 0, ARP), on top of
  sigma.rs opening rounds. Then U4 (Pi1 option-b A-map).
