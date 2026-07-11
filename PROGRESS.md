# STATEMENT-INTEGRITY tranche — progress ledger

Branch: worktree-agent-abf53494b7c188c90 (worktree), based on perf/zk-batch-optimizations @ 08051af.
Audit driver: codex-audit-2026-07-10 findings C-02 (statement validation + q31 non-wrap),
H-05 (target contract), H-02 third item (pass-element inventory 9.4e9 vs 1.33e10).
Build: PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release
Suite: PATH=... python3 -m unittest discover -s tests   (42 tests, must stay green)
Do NOT touch: ring/gkr_masked.rs, ring/lookup.rs, [U-K5*] sections of ring_matmul.rs, codex-audit-*.

## Deliverable state

- [x] D1 DONE (commits a8eb1e6 U-S1, + U-S1b Lookup/narrowing amendment)
- [x] D2 DONE (U-S2: q46 link wiring, caveat removed, [U7w] wraparound battery green)
- [x] D3 DONE (U-S3: docs/zkmatrix-poc/TARGET_CONTRACT.md)
- [x] D4 DONE (U-S4: statement-inventory subcommand -> 1.351e10 used / 1.389e10 paid
      per pass; M5_LITE_REPORT.md + LLM_SCALE_ESTIMATE.md updated)
- [x] FINAL: full 42-test python suite green (42/42 OK, 132.6 s) + worktree clean.
      Note: one run showed a PRE-EXISTING flake in tests/test_zk_lattice.py
      Pi1Tests::test_rejects_tampered_responses (tamper=1) — that module uses
      secrets.randbelow (unseeded true randomness); a +1 tamper on one Gaussian
      response coordinate occasionally survives the approximate check. Pure-Python
      module untouched by this tranche; passes 3/3 in isolation and the full rerun
      is green. Worth a seed or a wider tamper in a future hygiene pass.

- [ ] D1 Statement format + validator (src/manifest.rs) + [U7] positive/malicious tests
      Design: Statement { header{version, model_digest, table_digest}, manifest, quant: Vec<QuantMeta>,
      outputs } ; validate() -> Result<(), StatementError>; digest() validates first.
      Checks: dense ids, dangling ids, Matmul rows/inner/cols + ByRows/ByColumns orientation
      discipline, equal-shape ops, Rescale->Range(remainder) fact, Range->contiguous width plane
      entries each with Binary, quant presence/consistency, consumed-or-output, duplicate output,
      unknown version. Tests go inside chain_demo ([U7] battery) — dangling id, shape mismatch,
      orientation flip, missing range fact, duplicate output + positive case.
- [ ] D2 q31 wraparound gap closed in chain_demo:
      R bit planes move q31 -> q46 gadget layer (ring/link.rs machinery);
      per-column ARP + binary quad claims at q46; link grounding claims (xi*2^i) in the q46
      round; link target claims (xi) ride the q31 wave's ct_claims slot; q31 recomposition +
      q31 binary claims deleted; h0_link binds both sides per the F5 ordering.
      Malicious wraparound test: crafted plane-0 bits, sum b(b-1) = 2*q31 over Z (pronic greedy
      decomposition), recomposition wraps as integer; ACCEPT under a minimal old-style q31-only
      round (documents the hole), REJECT at q46 (binary quad ct fails; ARP gate refuses).
      Remove the [q31 caveat] print only when green.
- [ ] D3 docs/zkmatrix-poc/TARGET_CONTRACT.md (audit H-05) — freeze the benchmark boundary.
- [ ] D4 Pass-element inventory reconciliation (audit H-02 item 3):
      both prior numbers trace to 1.5e14 Route Z MACs / {16k, 11.3k} MACs-per-element —
      divisor round-trip, not an inventory. Add `ring_matmul statement-inventory`:
      builds the validated 32-layer FFN-surrogate Statement per TARGET_CONTRACT quant spec,
      counts committed elements per family (q31 values / q46 bit planes, used + paid slots),
      prints ONE number. Update M5_LITE_REPORT.md (secs 4+5) and LLM_SCALE_ESTIMATE.md.

## Key facts discovered (for resume)

- Worktree was pinned at stale commit 7a3e7a0; fast-forwarded to 08051af (done).
- Audit folder lives UNTRACKED in main checkout: /home/victor/IntelligenceRegulation/codex-audit-2026-07-10.
- chain_demo: zkmatrix-rs/src/bin/ring_matmul.rs lines ~3617-3971; caveat print at ~3658.
- Binary gadget soundness: claim is sum_t b_t(b_t-1) = 0; needs ARP side condition
  (|coeffs| bounded so the non-negative integer sum cannot wrap mod q); ARP budget closes at
  q46 (arp_budget_ok), NOT q31 ([U3b] asserts the failure). ARP unit cap ~896 coeffs
  (arp_binary_unit_ok); chain demo shape 128x128x16x4 -> per-column units of 512 bits.
- Link demo pattern: self_test_link (~line 5370); q46 binary+ARP pattern: [U6b] (~line 1646).
- Suite entry: tests/test_zkmatrix_native_backends.py::test_ring_chain_demo runs
  `ring_matmul chain-demo 128 128 16 4`, expects "chain-demo passed" in stdout.
- manifest.rs is #[path]-shared by ring_matmul, lattice_matmul, ring_lattice, structured_matrix:
  additive changes only.
- Q8 = q8_31 (2^31-class prime), ring::Q8_46 = q46 gadget modulus; table digest fn:
  ring/lookup.rs::table_spec_digest(&silu_int8_table()).

## Log

- 2026-07-10: worktree synced to 08051af; audit + code recon complete; plan committed.
- 2026-07-10: tranche COMPLETE. Commits U-S1..U-S4b. Headlines:
  * Statement v2 validator (manifest.rs) + [U7v] battery (11 rejection cases).
  * chain-demo range family grounded at q46 via the U-L link; caveat print gone;
    [U7w] wraparound battery: broken-q31 ACCEPT shown, shipped q46 REJECT shown
    twice (binary ct + ARP gate).
  * TARGET_CONTRACT.md freezes the benchmark boundary (H-05).
  * statement-inventory: 1.351e10 used / 1.389e10 paid committed elements per
    pass (FFN surrogate, generated from the validated DAG); both docs updated.
  * ring_matmul.rs diff confined to chain/U7 sections + usage/main; lookup.rs,
    gkr_masked.rs, [U-K5*] untouched.
