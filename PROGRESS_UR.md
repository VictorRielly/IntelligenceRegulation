# U-R tranche ledger — per-layer instances (multi-wave) + range-lookup pilot

Branch: perf/zk-batch-optimizations. Spec: RANGE_AGGREGATION_DESIGN.md
(Sections 2b and 3); audit 2026-07-12 Phase 5 items 2-3.
Build: PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release
Suite: python3 -m unittest discover -s tests (42 tests + freeze-check green at every commit).
Heavy runs: ONE at a time on this box, systemd-run MemoryMax=10G, sizes <= 2^22.

## Scoping result (2026-07-14, code-verified)

The multi-wave refactor is CALLER-SIDE plumbing plus small ct_engine
helpers — prove_ct_round/verify_ct_round themselves need NO change, and
the masked descents/pins are untouched:

- The chain assembles its q31 claims itself (ring_matmul.rs ffn-chain:
  [pins | link targets | zeta Y | zeta UP] + Hadamard QuadRingClaims)
  and makes ONE prove_ct_round call over the block's 113 commitments.
  Multi-wave = partition the commitment list into <=cap bundles, call
  prove/verify per wave with re-indexed claims.
- CtClaim { msg_coeffs: (commit_idx, slot, poly), .., scalar } splits by
  wave: public msg_coeffs partition + PROVER-REVEALED per-wave partial
  scalars; the verifier rebuilds per-wave claims from public weights and
  gates sum(partials) == total (mod q, centered) — the link_reveal_y
  trust class. QuadRingClaims do not split: their operand + output
  commitments must co-locate (a partition constraint, planner-enforced).
- Binding order is ALREADY multi-wave-safe: h0_link_b binds every block
  commitment before any challenge (D-4); per-wave h0 and per-wave
  g-masks follow the existing per-block pattern.
- Memory: per-layer 512x11008 = 2^22.4 el exceeds the 2^22 CLI cap and
  the box; pilot shapes 2^18..2^22 with linear extrapolation, honest
  about it (U-K9 B-D2's cap lift is the eventual unblocking work).

## Stages

- [ ] S0 — ct_engine wave helpers: plan_waves (greedy, co-location
      groups, cap), split prover/verifier claim functions, partial-sum
      gate. Self-test [U-R1a]: 2-wave == 1-wave differential on a small
      committed claim set (both ACCEPT; lied partial REJECTS; cross-wave
      quad REJECTED by the planner).
- [ ] S1 — chain integration: `ffn-chain layer <log2_el>` — ONE
      instance, multi-wave q31 commit, one masked descent pair, pins/
      link/zeta/quad claims through the splitter; honest ACCEPT + the
      battery's tamper edges at the new shape + NEW wave-boundary
      tampers (partial-sum lie, wave g-mask cross-use).
- [ ] S2 — measure: A/B marginal at 2^18/2^20/2^22 vs the blocked
      chain (the committed+masked amortization curve — the design
      study's key unknown); RSS per shape; [NOISY-SHARED] marks; the
      1/B fixed-cost claim checked against measurement.
- [ ] S3 — U-R2 pilot: replace X's planes+ARP with a 256-row [0,256)
      range lookup inside the layer instance (second table instance +
      m column; X read dense, no offset fold needed at w = 8); A/B
      the range marginal exactly as A-D2 did. Ceiling gate N_inst <=
      2^25 derive-time.
- [ ] S4 — docs/freeze: RANGE_AGGREGATION_DESIGN status flips, freeze
      rows (wave cap + partition rule + partial-sum gate; range-table
      spec digest), Section 7''/ladder reconciliation, this ledger.

## Design decisions (recorded before coding)

- D-1 PARTIAL SCALARS IN THE PROOF. Split linear claims reveal per-wave
  partial ct values; sum gated against the public total. Quadratic
  claims never split (co-location instead) — revealing partial quad
  values would need new masking analysis; co-location needs none.
- D-2 WAVE PLANNING IS DETERMINISTIC AND PUBLIC: greedy first-fit in
  commitment order with co-location groups pinned first; the plan is a
  pure function of (n_commits, groups, cap) so verifier and prover
  derive it independently — nothing prover-chosen enters the partition.
- D-3 CAP STAYS THE DERIVED C2 VALUE (~134 at the U-K5c shape) minus
  the wave's own g-mask commitments; derive_ct_round_params remains the
  single source of truth (its assert is the gate, as today).
- D-4 PER-WAVE g-MASKS bind wave-locally (mask only their wave's
  reveals), exactly the per-block D-4 pattern lifted one level.

## Log

- 2026-07-14: tranche opened; scoping verified in code (see above);
  restart-rate fixes and the design study landed earlier today
  (92ca018, b6bb1e2 — see PROGRESS.md 2026-07-13 entries).
