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
- [x] S2 — measure: A/B marginal at 2^18/2^20/2^22 vs the blocked
      chain (the committed+masked amortization curve — the design
      study's key unknown); RSS per shape; [NOISY-SHARED] marks; the
      1/B fixed-cost claim checked against measurement.
      DONE 2026-07-14 at 2^16/2^18/2^20 (NOT 2^22: the layer rig's
      commitment stores + split pin claims peak at 8.23 GiB at 2^20 —
      the 10G scope caps the CLI at 2^20; 2^22 is ~4x that. The
      original 2^18..2^22 sketch predated the S1 memory findings).
      One shape at a time, MemoryMax=10G, 1T, ALL timings
      [NOISY-SHARED] (a live trading job burns a core):

      shape | el        | waves | commit  | prove    | verify   | RSS
      2^16  | 65,532    |  43   | 13.3    | 544.8    | 185.7    | 0.52 GiB
      2^18  | 262,140   | 168   | 14.7    | 529.4    | 186.9    | 2.06 GiB
      2^20  | 1,048,572 | 670   | 16.0    | 578.7    | 187.4    | 8.23 GiB
      (arm A absolute us/el; data cap 76/wave of C2 max 134 all rows)

      lookup marginal (A - B)      2^16    2^18    2^20   | B=1020 (A-D2)
      prove  us/el                 +41.8   -10.4   +27.3  | +205.9
      verify us/el                 +16.7   +19.4   +23.5  | +130.0
      commit us/el                 +2.2    +3.4    +4.1   | +64
      committed dce/el             1.609   1.387   1.335  | 14.1
      masked transcript B/el (A)   1.417   0.716   0.512  | 37.5
      lkp attribution p/v us/el  24.6/9.9 22.5/9.8 23.4/10.2 | 99.7/39.7

      Findings (the design study's key unknown, answered):
      * The A-B prove marginal is NOISE-WIDE past 2^16 on this box
        (-10..+42 us/el across shapes on 140-600 s totals) — the
        clean signal is the lookup-stage attribution: prove falls
        99.7 -> ~23 us/el (4.3x) and verify 39.7 -> ~10 us/el, and is
        FLAT across 2^16..2^20 — the per-instance fixed costs are
        fully amortized by 2^16 already.
      * Fixed-cost factor vs the unmasked core (10.8-10.9 us/el 1T,
        lookup-bench): ~2.1-2.3x at layer scale, down from 6-9x at
        B = 1020. The modeled ~1-1.5x is NOT quite reached: the
        residual is PER-ELEMENT masked-path work (the blinded witness
        tree is 2x payload leaves by the blinder-packing pattern +
        pins/claims), not per-instance fixed cost — i.e. the 1/B
        claim holds for the fixed material, and the model's remaining
        gap is the tree-overhead constant, not amortization.
      * dce/el marginal does NOT fall as 1/n: floor ~1.3 dce/el = the
        per-WAVE pin g surcharge (9 pin shares/wave -> ~2 extra
        g-groups/wave vs arm B = 2048 dce per ~1565-el wave). The
        per-LAYER lookup material itself (m + blinders + masks) is
        ~29 commitments = 0.028 dce/el at 2^20 and falling as 1/n —
        the design's "~1e-4 dce/el class" claim is on track for the
        m-column proper, but Section 2b's model did NOT price the
        multi-wave pin-share g term; S3/S4 must carry it (it also
        prices the range-table m column's pin shares).
      * Masked transcript: descent pair is per-layer fixed; reveals
        scale with waves (12 B x ~56 shares/wave ~ 0.43 B/el
        asymptote at this wave shape) -> 0.512 B/el at 2^20 vs 37.5
        at B = 1020 (73x).
- [x] S3 — U-R2 pilot: replace X's planes+ARP with a 256-row [0,256)
      range lookup inside the layer instance (second table instance +
      m column; X read dense, no offset fold needed at w = 8); A/B
      the range marginal exactly as A-D2 did. Ceiling gate N_inst <=
      2^25 derive-time.
      DONE 2026-07-14 (rig 0434a0e; measured below). Second 256-row
      table instance inside the layer rig: own m column, blinders and
      mask pair (same depths dw/dt), X read DENSE at w = 8 (the
      committed offset code IS the looked-up value), same masked
      machinery, ONE psi pin batch (per-wave pin g budget UNCHANGED at
      9 copies — the S2 surcharge does not double). Ceiling gate
      N_inst <= 2^25 asserted derive-time (Section 4 instancing rule).
      Arms: LookupRange (measured arm R) and RangeOnly (battery
      isolation arm — the S3 architecture where the range table is the
      SOLE X certifier). [U-R2a] battery green: honest ACCEPT both
      arms; x_u = 300 smuggled into the dense column REJECTS at the
      range root cross-check, fully ISOLATED on RangeOnly (all other
      gates pass) and doubly covered on the full arm (silu root also
      rejects, labeled); PLUS the S1-deferred g-mask cross-use forgery
      (donor wave's g's presented + opened self-consistently) REJECTS
      at exactly the target wave. Honest scope notes: (a) the pilot
      rides the LAYER rig — per D-5 it never had a plane/ARP side, so
      the A/B is "with vs without the range table", not a
      plane-removal differential inside the block chain; (b) the range
      witness covers the n_el DATA values (pads uncovered — the block
      rig's all-1024-positions coverage needs a 2x-deeper tree, S4+
      work); (c) manifest v2 has no multi-table vocabulary — the range
      table binds via its spec digest in the lookup prehash context,
      statement-format lift deferred.

      RANGE marginal (R - A), 1T [NOISY-SHARED], one shape at a time:

      shape | commit  | prove   | verify  | attr p/v   | dce/el | B/el  | RSS R
      2^16  | +1.5    | -17.8   | +1.9    | +18.0/+0.5 | 0.2656 | 0.977 | 0.54
      2^18  | +3.7    | -3.5    | +4.0    | +14.4/+1.9 | 0.0742 | 0.285 | 2.11
      2^20  | +4.5    | +8.8    | +2.3    | +15.3/+1.4 | 0.0146 | 0.082 | 8.40
      (us/el except dce/B/GiB; attr = range descent-pair share of the
      lookup-stage attribution — the clean signal; R - A totals are
      box-noise-wide, exactly as in S2)

      PUNCHLINE (the Section 3 prediction, measured): range
      certification per element falls from the block rig's q46
      plane+ARP 582 dce/el committed to 0.0146 dce/el at 2^20
      (39,731x) and from ~10,300 us/el prove (96% of 10.7 ms/el
      [NOISY-SHARED, pre-restart-fix]) to ~+15 us/el (range descent
      attribution; ~670x) — and the range fact becomes EXACT (no
      SLACK_OP, no wrap side condition, no ARP/alpha coupling).
      Falls as 1/n (m column + fixed material only), vs the S2 pin
      surcharge which does NOT (already priced in both arms here).
- [x] S4 — docs/freeze: RANGE_AGGREGATION_DESIGN status flips, freeze
      rows (wave cap + partition rule + partial-sum gate; range-table
      spec digest), Section 7''/ladder reconciliation, this ledger.
      DONE 2026-07-14: RANGE_AGGREGATION_DESIGN.md header flipped
      (Section 2b BUILT+MEASURED with the S2 table appended in place,
      Section 3 PILOT-MEASURED with the S3 table; Section 4 tranche
      items marked LANDED/PARTIAL with the honest scope shifts).
      Freeze row LKP-9 (freeze_check_ur1, gates both directions like
      LKP-8): q31 C2 wave capacity = 134 at the U-K5c shape (135
      fails); the deterministic partition rule at the 2^12/silu point
      (data cap 76, 3 waves, chunk-wave budget 57, plan re-derives
      identically, 77-commit triple wave busts C2); the partial-sum
      gate (honest reveals ACCEPT, lied partial REJECTS at a fixed toy
      instance); the ur2-range-table-v1 spec digest pinned (full hex);
      and — resolving PROGRESS.md A-D3's recorded open item — the ARP
      rejection constants: log M(1)/log M_joint(4) at the LKP-8 point
      (t = 1.5, alpha = 3.5) as exact-formula windows plus the
      behavioral gates (joint < 3 attempts/round, joint < per-unit
      product). M4 Section 7''' gains the one-line S3-result pointer;
      PROGRESS.md A-D3 note carries the dated RESOLVED line. LKP-5..8
      digests and gates unmoved (verified in the same freeze-check
      run). NOT closed here (recorded in Section 4's U-R3 item): the
      quiesced ladder re-measure and the GPU_GO_NO_GO range-gate
      re-run stay with the orchestrator.

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
- 2026-07-14 (4): S2 measured (table under S2). Headline: per-instance
  fixed costs are gone by 2^16 (attribution flat at ~23/10 us/el
  prove/verify); the residual vs the unmasked core is ~2.1-2.3x
  per-element masked-path work (blinded-tree 2x-leaf overhead), not
  amortization; the NEW cost term the design model missed is the
  per-wave pin-share g surcharge (~1.3 dce/el floor at data cap 76).
  2^20 peaks at 8.23 GiB under the 10G scope; 2^22 does not fit as
  built (CLI capped at 2^20; U-K9 B-D2's cap lift + claim-mass
  streaming would be the unblocking work).
- 2026-07-14 (5): S3 rig + battery landed (0434a0e), measured
  (43b2851 — table under S3; punchline 582 -> 0.0146 dce/el at 2^20).
  The S1-deferred g-mask cross-use forgery leg landed with it.
- 2026-07-14 (6): S4 landed — doc flips, LKP-9 freeze row (incl. the
  A-D3 rejection-constant resolution), this ledger. Tranche S0-S4
  complete; open residuals live in RANGE_AGGREGATION_DESIGN Section 4
  (U-R3 PARTIAL: quiesced ladder + GPU gate re-run) and the S3 scope
  notes (pad coverage, multi-table statement typing).
