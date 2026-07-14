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

- [x] S0 — ct_engine wave helpers: plan_waves (greedy, co-location
      groups, cap), split prover/verifier claim functions, partial-sum
      gate. Self-test [U-R1a]: 2-wave == 1-wave differential on a small
      committed claim set (both ACCEPT; lied partial REJECTS; cross-wave
      quad REJECTED by the planner).
      DONE 2026-07-14: ct_engine gains WavePlan/plan_waves (deterministic
      first-fit, co-location units), split_claim_shares +
      split_claims_prover/verifier (per-wave partial ct reveals, sum
      gate, centered-representative check; Ajtai-bearing claims must be
      single-wave — S0 scope), quad_ring_wave/localized, ct_mul_centered.
      [U-R1a] green: planner determinism/cap/co-location; verifier
      rebuild == prover shares; per-wave ct-rounds (with per-wave
      g-groups, g_base = data count) ACCEPT; lied partial REJECTS at the
      sum gate; a COMPENSATED lie passes the gate but its wave's
      ct-round REJECTS (the load-bearing soundness leg); straddling quad
      detected. Full self-test 220s green; suite 42/42 green.
- [x] S1 — chain integration: `ffn-chain layer <log2_el>` — ONE
      instance, multi-wave q31 commit, one masked descent pair, pins/
      link/zeta/quad claims through the splitter; honest ACCEPT + the
      battery's tamper edges at the new shape + NEW wave-boundary
      tampers (partial-sum lie, wave g-mask cross-use).
      DONE 2026-07-14: `ffn-chain layer <log2_el> [battery]` additive
      CLI mode + [U-R1b] battery + one-shape self-test smoke leg.
      n_el = 2^log2_el - 4 (blinder-packed witness tree, depth
      log2_el + 1 — the UK8_B = 1020 pattern at layer scale); ONE
      masked descent pair serves the layer; plan_waves co-locates each
      Hadamard (Y,UP,Z) commitment triple; data cap derived from the
      C2 scan (134 at the U-K5c shape -> 76 data/wave arm A at 2^12;
      derive_ct_round_params' assert stays the per-wave gate, D-3);
      per-wave g-groups sized by plan-deterministic claim-share
      budgets and ALL committed before h0_link; per-wave h0 binds the
      lookup transcript state (which binds h0_link) + wave index +
      the wave's commitment list. PIN claims flow through the audited
      split_claims_prover/verifier (sum gate). ZETA claims: the
      materialized path is ~13 GB at 2^20 (2 x 24 rows x 2^17 chunk
      polys, both sides) and busts the 10G scope, so the rig builds
      zeta shares per wave with a streaming XOF cursor (ZetaStream),
      DIFFERENTIAL-PINNED bit-for-bit to link_claims_tgt_slot +
      split_claims_prover at the battery shape, with the same three
      verifier gates (share structure by construction, centered-
      representative bound, per-row sum == public total). Battery
      green (2^12, 3 waves): honest ACCEPT both arms; lied pin
      partial REJECTS at the sum gate; COMPENSATED pin lie passes the
      gate but its wave's ct-round REJECTS (load-bearing); lied zeta
      partial REJECTS at the per-row sum gate; compensated zeta lie
      REJECTS at its waves; off-table Y REJECTS at the root
      cross-check (isolated); tampered Z REJECTS at exactly its
      wave's quad claim; lookup-h0 bit flip REJECTS; straddling quad
      DETECTED by the planner without co-location groups. rho columns
      stored ternary-packed (i8), proofs dropped per wave (H-03).
      Suite 42/42 + freeze-check green (additive — no digest moved).
      NOT DONE from the original sketch: a wave g-mask cross-use
      tamper (per-wave g's are sampled/committed per wave and bound
      by the wave's own h0; a cross-use forgery needs a hand-built
      proof transcript — deferred to S3's battery alongside the range
      table's new edges).
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
  reveals), exactly the per-block D-4 pattern lifted one level. g-group
  SIZES per wave derive from the wave's claim-share counts, which are
  public and deterministic given the shape/plan — so every wave's g's
  can be committed BEFORE h0_link, preserving commit-before-challenge.
- D-5 THE LAYER RIG OMITS THE q46 PLANE/ARP SIDE (recorded 2026-07-14).
  The q46 granularity is an ARP soundness cap, not C2 — a 2^20-el layer
  would need 4096 q46 rounds (hours) under the CURRENT range
  architecture, which S3 replaces anyway. `ffn-chain layer` therefore
  measures the multi-wave committed masked lookup + Hadamard + zeta at
  per-layer scale — the post-range-lookup architecture — and S3 adds
  the range table INTO this rig. The full range→lookup→Hadamard
  integrity story stays covered at the block rig (unchanged); the layer
  rig's honest label: lookup-side lift only until S3 lands.

## Log

- 2026-07-14: tranche opened; scoping verified in code (see above);
  restart-rate fixes and the design study landed earlier today
  (92ca018, b6bb1e2 — see PROGRESS.md 2026-07-13 entries).
- 2026-07-14 (2): S0 landed — wave planner + claim splitters in
  ct_engine, [U-R1a] battery in self-test. One engine fact learned for
  S1: every linear ct-claim consumes a g-slot in ITS wave, so per-wave
  g-groups are sized by that wave's claim-share count (the S0 test's
  sample_g_masks pattern) — the chain's g-group sizing in Pass 2 must
  become per-wave in S1.
- 2026-07-14 (3): S1 landed — `ffn-chain layer` rig (see S1 note). Two
  facts learned: (a) the zeta slot-constancy family is the layer-scale
  memory wall, not the trees (U-K9 packed trees are ~0.5 GiB at 2^21
  leaves; materialized zeta claims would be ~13 GiB at 2^20) — hence
  the streaming per-wave builder, differential-pinned to the S0 path;
  (b) first-fit placement is chunk-monotone (singles precede triples
  in index order), which is what makes a sequential zeta XOF cursor
  per row possible at all — recorded here because any future planner
  change that breaks monotonicity breaks the streaming builder (it
  asserts).
