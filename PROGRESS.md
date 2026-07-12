# U-K8 + U-K9 tranche — progress ledger (masked-lookup FFN integration + kernel-grade K-mults)

Branch: perf/zk-batch-optimizations, base 7da16f2 (U-K5 label-lift push).
Specs: U-K8 = M4_LOOKUP_DESIGN.md Section 8 item U-K8 + the audit-reopened TRUE exit
(committed FFN-shape tensor + slot-packed E4 + upstream range + downstream gate-o-up);
U-K9 = M4_LOOKUP_DESIGN.md Section 7' closing paragraph (lane-packed bulk slot
arithmetic through the A1 kernel class + lazy reduction in round_poly/build_tree)
+ the audit H-03 memory refactor (KElem inline [u64;16]/SoA, streamed layers).
Build: PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release
Suite: PATH=... python3 -m unittest discover -s tests   (42 tests + freeze-check, must stay green)
Do NOT touch: codex-audit-* (read-only), scripts/logup_*_spike.py, src/manifest.rs.

## Lanes and file ownership (three parallel agents)

- Agent A (U-K8, THIS checkout): ring_matmul.rs (chain/battery/bench sections),
  ring/lookup.rs (additive), docs (M4_LOOKUP_DESIGN 7'/statuses, LLM_SCALE_ESTIMATE,
  TRANSFORMER_PROOF_PLAN Section 2), this ledger. Must NOT restructure ring/kfield.rs,
  ring/sumcheck.rs, ring/gkr.rs, ring/gkr_masked.rs (Agent B owns their internals;
  A consumes their public API as-is).
- Agent B (U-K9, worktree): ring/kfield.rs, ring/sumcheck.rs, ring/gkr.rs,
  ring/gkr_masked.rs internals; MINIMAL localized ring_matmul.rs edits only (CLI cap,
  bench flag). Public KElem/KField API stays source-compatible. Own ledger
  PROGRESS_UK9.md + report U_K9_KERNEL_REPORT.md (new files). Does NOT edit shared docs.
- Agent C (flake fix, worktree): tests/test_zk_lattice.py only.
- Orchestrator (after all): merge C then B, resolve, suite green, QUIESCED-MACHINE
  reconciliation re-measurement (lookup-bench + U-K8 chain bench), fold U-K9 numbers
  into Section 7'/ladder, push.

## Timing hygiene (shared box)

Two agents bench on one 22-thread machine simultaneously: every interim timing is
marked [NOISY-SHARED]; ladder-grade numbers come from the orchestrator's
reconciliation pass on a quiet machine after merge.

## Deliverable state

- [x] A-D1 Committed FFN-gate chain built: range-proved X in (q46 U-L link) ->
      masked+committed lookup certifies Y = SiLU(X) ([U-K5c] machinery) ->
      downstream gate-o-up Hadamard consumes Y (E1/E2 slot machinery); slot-packed
      E4 variant wired if the U-K6 slot-packed weight path supports it. Honest
      ACCEPT + tamper REJECT at every chain edge (out-of-range X, off-table Y,
      Hadamard mismatch, stale-hash orderings).
      DONE 2026-07-10: `ring_matmul ffn-chain [n_blocks | battery]` +
      `self_test_ffn_chain` in self-test. Statement v2 (Binary/Range/Lookup/
      Hadamard ops, output Z) is the chain ctx. The slot-packed E4 variant IS
      wired: there was no pre-existing U-K6 slot-packed weight path, so it was
      built additively as ring/lookup.rs::slot_pin_weights (E1-composed
      per-coefficient pin weights; Y lives ONLY slot-packed) — it composes
      with the masked pins cleanly (the Q-pin's Y term). Battery green (7/7):
      honest ACCEPT, baseline-arm ACCEPT, RangeX REJECT (link rows), OffTableY
      REJECT (root cross-check, isolated), HadamardZ REJECT (quad claim),
      zeta F5 pair (stale-zeta ACCEPT leg with WRONG output constants while
      the lookup passes / shipped-zeta REJECT leg). Freeze row LKP-8 (chain
      operating point + both capacity walls pinned both directions).
- [ ] A-D2 Measured at the largest per-instance shape that fits as-built memory
      (H-03 gap documented honestly if full 512x11008 does not fit; full-shape
      re-measure planned post-U-K9-merge). Marginal costs: lookup-integrated chain
      vs bare matmul chain, and the differential vs piecewise variant-A.
- [ ] A-D3 Docs: Section 7' U-K8 block (measured, not [MODEL]), the four-status
      header flips FFN-integration status honestly, LLM_SCALE_ESTIMATE M4 row,
      TRANSFORMER_PROOF_PLAN Section 2 reconciliation. Freeze row for any new
      frozen constant (house discipline).
- [ ] B-D1 Lane-packed bulk slot arithmetic (the U-K1 8-lane adapter) through the
      A1 kernel class + lazy reduction in round_poly/build_tree/fuse/descent hot
      loops. Differential battery: bulk path bit-identical to scalar path;
      LKP-5/6/7 freeze digests MUST NOT move.
- [ ] B-D2 H-03 memory refactor: KElem inline [u64;16]/SoA, streamed layer
      construction; RSS measured at 2^20/2^22/2^23; CLI cap lifted to what fits.
- [ ] B-D3 Measured kernel report (U_K9_KERNEL_REPORT.md): us/el before/after at
      2^18/2^20 (lookup-bench unchanged as the yardstick), reduction-discipline
      vs lane-occupancy attribution, honest [NOISY-SHARED] marks.
- [ ] C-D1 tests/test_zk_lattice.py tamper flake fixed without weakening the
      test's meaning; demonstrated stable over many repeats.
- [ ] FINAL (orchestrator): merges, suite green, quiesced re-measurement,
      Section 7'/ladder reconciliation with U-K9 numbers, push.

## Key facts (for resume)

- Lookup core as-built: 10.8-10.9 us/el 1T scalar schoolbook slot_mul_g, per-mult
  reduction; model 0.5-1 us/el = kernel-grade (Section 7'). Pass = 1.8e8 elements.
- Memory as-built: N=2^20 ~ 1.5 GiB RSS; 2^23 ~ 12 GiB does not fit 15 GB box;
  CLI caps 2^22. FFN per-layer instance = 512x11008 = 5.6e6 el ~ 2^22.4.
- [U-K5c] committed masked pass battery (self_test_lookup_zk) = the base for A-D1;
  13-commitment CRS msg_r=8, 60 aggregate pins, pin layer in ring/lookup.rs.
- Upstream range: chain-demo q46 U-L link pattern (ring_matmul.rs [U7w] sections);
  downstream Hadamard: U-E2 slot-constancy machinery (link_claims_tgt_slot).
- Piecewise variant-A differential baseline: M4_ACTIVATION_DESIGN.md numbers
  (+201% commit bill class).
- Known flake (Agent C's lane): Pi1Tests::test_rejects_tampered_responses —
  secrets.randbelow unseeded; +1 tamper on one Gaussian response coordinate
  occasionally survives the approximate check.

## A (U-K8) design decisions — recorded before coding (spec left these open)

- D-1 BLOCKED CHAIN (row-block sub-instances). The q31 ct-round has a hard
  C2 capacity: q > 8*beta caps one round at ~134 commitments of the U-K5c
  CRS shape (kappa 8, n_r 26, msg_r 8) ~ 4.4e5 committed coefficients.
  A single-descent committed lookup therefore caps at ~2^17 dense elements
  per round as-built — BEFORE the H-03 memory wall binds. The chain is
  built as independent row-block sub-instances of B = 1020 elements
  (dw = 11 witness tree: 1020 = blinder_positions(2048)[0], dt = 9 table),
  each with its own m column, masks, blinders, descents, pins and q31
  round — the design's Section 9 item 5 sub-instancing. Ceiling margin
  only improves; transcript volume grows (recorded honestly).
- D-2 SLOT-PACKED Y (the E1-composed E4 variant). Y lives ONLY slot-packed
  (H3) so the downstream gate-o-up Hadamard can consume it; the lookup's
  Q-pin reads Y through per-coefficient weights composed from the
  slot-constant CRT projection rows (new additive helper in
  ring/lookup.rs: slot_pin_weights). X stays dense (offset code x+128 for
  the U-L link; the -128 fold rides the pin value, coefficient 128*hw).
  Slot-constancy of Y and UP pinned by standalone zeta rows
  (link_claims_tgt_slot with xi = 0, y = 0); Z inherits by GF(q) closure.
- D-3 q46 RANGE SIDE: per-round grouping with a scaled ARP alpha. The
  ARP budget (arp_budget_ok at q46, SLACK_OP = 512, JL_C = 13) caps
  units at ~896 bits AND caps alpha at ~4 for 512-bit units; whole-round
  restarts couple all units of a round. Frozen chain point: sub-block =
  128 values -> two 512-bit units (planes 0-3 / 4-7, msg_r_g = 4);
  q46 rounds of U = 4 units (256 values) at alpha = 3.5 (per-unit accept
  e^-0.47, ~6.5 expected restarts/round, budget 2.66e13 < q46/2); one
  U-L link instance per q46 round (w = 11, l = 24). LKP-8 freeze row.
- D-4 STREAMING BINDING. Tensor commitments (X, planes, Y, UP, Z, m,
  blinders, masks) all precede the statement digest (ctx). Per-block
  h0_link_b = link_h0(ctx+block, both sides' block lists INCLUDING that
  block's g-masks); xi/zeta/alpha derive from it. Cross-block: every
  witness commitment is bound through ctx; g-masks are bound block-locally
  (they mask only their own round's reveals). This keeps RSS flat while
  preserving commit-before-challenge for every weight-like value.
- D-5 The A/B differential: arm A = chain with the masked lookup (m,
  blinders, masks, pins); arm B = identical chain minus the lookup
  material. Range + Hadamard costs cancel in the marginal.

## Blocker

(none so far)

## Log

- 2026-07-10: tranche opened at 7da16f2; ledger written; Agents A (U-K8),
  B (U-K9), C (flake) launched.
- 2026-07-10 A: read spec/audit/engine; recorded D-1..D-5 above. Key
  discovered constraint: the C2 wave capacity (not H-03 memory) is the
  binding wall for a committed single-descent lookup — goes in the docs.
