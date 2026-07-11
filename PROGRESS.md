# U-K5d/e tranche — progress ledger (masked lookup: battery + label lift)

Branch: perf/zk-batch-optimizations, base ace3f9b (statement-integrity merge).
Spec: docs/zkmatrix-poc/M4_LOOKUP_ZK_DESIGN.md Section 6 (build plan U-K5a..e);
reference semantics: scripts/logup_zk_mask_spike.py (11/11 OK, do not modify).
Build: PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release
Suite: PATH=... python3 -m unittest discover -s tests   (42 tests, must stay green; freeze-check too)
Do NOT touch: codex-audit-*, src/manifest.rs, ring/link.rs, statement/[U7] sections of
ring_matmul.rs, scripts/logup_zk_mask_spike.py. Docs are Agent B's + orchestrator's lane.
Known flake: tests/test_zk_lattice.py Pi1Tests::test_rejects_tampered_responses
(unseeded true randomness, pre-existing) — rerun in isolation, do not chase.

## Lanes

- Agent A (this checkout, critical path): D1-D3 below. Incremental commits, no push.
- Agent B (worktree, parallel): U-K5e paper part — three lemmas into Q4_LEMMAS.md
  + Section 3.3 hash-edge rows into SOUNDNESS_REFERENCE.md Section 7. NO label lift.
- Orchestrator (after both): review, merge B, re-grade parent Section 3.5 with measured
  numbers, lift the non-ZK label (M4_LOOKUP_DESIGN.md header + TARGET_CONTRACT.md +
  LLM_SCALE_ESTIMATE.md row), push.

## Deliverable state

- [x] D1 U-K5c COMPLETION (exit criteria from Section 6 that 784bb78's plumbing did not meet):
      masked descent wired over COMMITTED tensors — mask-coefficient commitments in
      statement-wave slots, blinded witness/table trees (builders exist), G_j pins +
      Rp/Rq opening pins + aggregate-only P/Q leaf pins as E4 CtClaims via the U-K5c
      pin-weight builders + U-K6 e4 machinery; v^X/v^Y/v^M retired from the transcript;
      end-to-end masked pass on a committed FFN-shape tensor ACCEPTS; Z1-class
      m-recovery harness at engine scale (recovers m from the zero-mask transcript,
      FAILS against the masked one); freeze row LKP-7 (masked transcript shape: round
      counts, evaluation pattern, byte count at the frozen FFN point).
- [x] D2 U-K5d NEGATIVE BATTERY:
      E3Z-N1 (F5 pair, spike Z4): G unpinned/crafted after nu ACCEPTS a false lookup;
        shipped order REJECTS the same crafting.
      E3Z-N2 (F5 pair, spike Z6): blinder mass solved at KNOWN alpha ACCEPTS;
        fresh alpha REJECTS the same committed blinders.
      E3Z-N3 (mask freshness): two passes sharing one g-mask — transcript difference
        reproduces the unmasked leak (demonstrated); engine REFUSES reuse (enforced).
      E3Z-N4 (rank canaries): Z3b/Z3c exposure-rank certificates as derive-time checks
        at engine shapes (leaf pads 4/4, R-mask 6/6, round-poly rank n_g with l+1
        forced relations) + guard-restart regression (Section 3.4 guard fires, restarted
        pass verifies).
- [ ] D3 RE-RUNS UNDER MASKING: E3-N1..N5 and E4-N1/N2 attack pairs against the masked
      pipeline (h0_lkp binds strictly more data; psi follows the mask openings —
      E4-N1's scope grows, same attack shape).
- [ ] D4 MEASURED NUMBERS for the U-K5e re-grade, recorded here: prover/verifier delta
      masked vs unmasked at battery shape; mask material counts (LKP-6); transcript
      bytes at the frozen FFN point (LKP-7).
- [ ] D5 (Agent B) Q4_LEMMAS.md: adapted Libra counting lemma (component 4), boundary-
      mask rank lemma (components 5-6), top-variety lemma (component 3), each graded
      [PROVEN at spike scale; engine-scale battery = U-K5d]. SOUNDNESS_REFERENCE.md
      Section 7: merged Section 3.3 hash-edge rows with attack-pair pointers.
- [ ] FINAL (orchestrator): battery green + suite green -> Section 3.5 re-grade with
      D4 numbers, non-ZK label lifted, docs consistent, push.

## Key facts (for resume)

- U-K5a/b landed 08051af (masked GKR core, [U-K5ab] battery, LKP-6); U-K5c plumbing
  landed 784bb78 (DescentEnd opening points, fixed-coins HV transcript mode for leak
  harnesses ONLY, blinded tree builders, mask flatten/offset helpers, pin-weight
  builders g_hypersum_weights/g_open_weights/r_open_weights, mul-by-kappa matrix).
- Anchors in zkmatrix-rs/src/bin/ring_matmul.rs: [U-K5ab] battery ~7634-7760; LKP-6
  freeze row ~8012; lookup-bench honesty label ~7878; U-K6 e4 machinery: e4_claims/
  derive_e4_psi/mle_weights_block/mul_y.
- Engine API: zkmatrix-rs/src/ring/gkr_masked.rs (masked_gkr_prove/verify, MaskSet,
  BlinderSet, blinded_witness_tree/blinded_table_tree, masked_transcript_shape,
  mask_coeff_counts).
- Mask commitments need msg_r >= 2 statement-wave slots (U-K5a).

## Agent A working notes (D1 recon, 2026-07-10)

- D1 plan: new battery section [U-K5c] in ring_matmul.rs self-test (fn
  self_test_lookup_zk, called from main after self_test_lookup). Committed
  masked pipeline at battery shape: 1 instance, witness depth 8 (96 honest
  leaves; honest block must stay below blinder position n/2-4), table depth 9
  (256 SiLU rows SPLIT across halves — rows 0..127 at 0..127, 128..255 at
  256..383 — because a front-packed 256-row table fills the whole left half
  and the tL blinder needs left-half dummy space; blinded_table_tree gets the
  split layout + collision asserts; nothing used it yet).
- Commitment layout (shape kappa 8 / n_r 26 / msg_r 2, U-K6 CRS class):
  idx 0 X, 1 Y, 2 m (scalars packed D=128/slot), 3 blinders (16 K-el = 256
  coeffs: w.tl.a,u, w.tr.a,u, w.f0.., w.f1.., then table same), 4..30 mask
  coefficients (witness MaskSet.flatten 189 K-el then table 230 K-el, 16
  K-el per msg_r=2 commitment), + 9 ct-round masks = 40 commitments.
  h0_lkp = ct_h0 over ALL of them (alpha follows masks/blinders: E3Z-N2 edge).
- Pin machinery (ring/lookup.rs, additive): PinTerm::{Scalar,Kelems},
  PinnedValue, pin_claims (psi-batched CtClaims via k_weight_coords +
  pack_functional), derive_pin_psi(state, copies, rows, q). Pin list order:
  witness layers (G_j, open_g, [j>=2] open_rp, open_rq), table same, then
  W P-pin, W Q-pin, T P-pin, T Q-pin. Leaf pin identities:
    W P: p* - H(z*) = sum eqw_bl a_bl
    W Q: alpha H + D - q* = sum L_i x_i + sum (Y L_i) y_i - sum eqw_bl u_bl
    T P: p* = sum L_pos(j) m_j + sum eqw_bl a'_bl
    T Q: q* - alpha H_t - D_t + MLE(table)(z*) = sum eqw_bl u'_bl
  v^X/v^Y/v^M never sent (retired; U-K6's e4-v absorb is the unmasked
  baseline battery and stays).
- m-recovery harness: fixed-coins mode, table descent only, probe basis =
  zero masks + benign (0,1) blinders at the depth-9 split layout, 257 proves,
  base-field Gaussian elimination (rank 256). Same probe matrix reused by
  E3Z-N3 (transcript difference of two mask-sharing passes = affine in
  mA - mB; needs shared alpha => fixed-coins modelling, documented).
- LKP-7 numbers (computed, to pin): masked_transcript_totals at FFN point
  (incl. layer1 quadruples, G_j, boundaries, openings): witness (23,5,32) =
  385 rounds / 1862 K-el, table (9,5,32) = 84 / 532; pass total 2394 K-el =
  153216 B at 64 B/K-el (16 coeffs x 4 B wire convention).
- Mask freshness (E3Z-N3 enforcement): MaskSet gains used: Cell<bool>;
  masked_gkr_prove refuses reuse (panic), harness_reset_freshness() for
  leak harnesses/attack modelling only.
- D2/D3 modelling: ordering attacks via fixed-coins transcripts (the spike's
  adversary-readable tape) for ACCEPT legs; shipped legs = pin flag /
  committed pin claims / real ratcheting transcript. E4-N1 masked: forge
  (orp + lambda t, orq - t) — end-check invariant direction — solve 9 psi
  constraints over t's 16 coords (U-K7 Gaussian-elimination shape).

## Log

- 2026-07-10: tranche opened at ace3f9b; ledger written; Agents A and B launched.
- 2026-07-10: Agent A recon done (design doc + spike + engine read); D1 plan
  + pin identities + LKP-7 arithmetic recorded above; starting D1 build.
- 2026-07-10: D1 GREEN. [U-K5c] battery in self_test_lookup_zk: committed
  masked pass (13 commits: X/Y/m/blinders/wmask x3/tmask x4 + 2 ct-g-mask,
  msg_r=8) ACCEPTS with 60 aggregate pins (G_j/open_g/open_Rp/Rq + 4 leaf
  P/Q pins) through pin_claims + a real ct-round; v^X/v^Y/v^M retired.
  m-recovery: rank 256/256 exact from zero-mask transcript (407 ms), wrong m
  from masked. LKP-7 freeze row wired: FFN point witness 385 rounds/1862 K-el,
  table 84/532, pass 153216 B (150 KB at 64 B/K-el). ring/gkr_masked.rs:
  freshness Cell, split table_row_positions, masked_transcript_totals/
  masked_pass_bytes. ring/lookup.rs: PinTerm/PinnedValue/pin_claims/
  derive_pin_psi. Freeze-check passes.
