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
- [x] D3 RE-RUNS UNDER MASKING: E3-N1..N5 and E4-N1/N2 attack pairs against the masked
      pipeline (h0_lkp binds strictly more data; psi follows the mask openings —
      E4-N1's scope grows, same attack shape).
- [x] D4 MEASURED NUMBERS for the U-K5e re-grade, recorded here: prover/verifier delta
      masked vs unmasked at battery shape; mask material counts (LKP-6); transcript
      bytes at the frozen FFN point (LKP-7).  --> see "## D4 measured numbers" below.
- [x] D5 DONE (5f17c70, 39e96e5; merged a724bb9) (Agent B) Q4_LEMMAS.md: adapted Libra counting lemma (component 4), boundary-
      mask rank lemma (components 5-6), top-variety lemma (component 3), each graded
      [PROVEN at spike scale; engine-scale battery = U-K5d]. SOUNDNESS_REFERENCE.md
      Section 7: merged Section 3.3 hash-edge rows with attack-pair pointers.
- [x] FINAL DONE (orchestrator): suite independently re-verified 42/42 green (138 s);
      Agent B branch merged (a724bb9); Section 3.5 re-graded with D4 numbers;
      non-ZK label LIFTED at subprotocol level across M4_LOOKUP_DESIGN (header,
      3.5 update, row 12, Section 8 U-K5 item, Section 9 item 1),
      M4_LOOKUP_ZK_DESIGN (status header, Section 4 table note), Q4.7-Q4.9 grades,
      SOUNDNESS_REF Section 7 rows, TARGET_CONTRACT (ZK status, U-K5 row, and a
      NEW proof-size TIGHTNESS FLAG: masked lookup transcript alone 150 KB vs the
      256 KB budget), LLM_SCALE_ESTIMATE M4 row. Honest scope kept everywhere:
      HVZK proof-of-protocol at the subprotocol level; U-K8 FFN integration and
      chain-wide composition remain OPEN.

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

## Decisions (spec-open, recorded here)

Points the design/spec left open that Agent A resolved during the build:

1. Commitment layout for the battery (D1): ONE frozen CRS, kappa 8 / n_r 26
   / msg_r 8, carries X/Y/m (base-field scalars), the blinders + mask
   coefficients (committed K-elements, 64/commitment) and the ct-round
   g-masks — 13 commitments. conc=true ct-round params (40+ would overflow
   q at conc=false). The spec pinned only "msg_r >= 2 statement-wave slots";
   msg_r=8 was chosen to keep the commitment count small.
2. Table-tree leaf layout (D1): the 256 SiLU rows are SPLIT across the two
   halves of the depth-9 blinded tree (rows 0..127 at 0..127, 128..255 at
   256..383) so each half has dummy space for its top blinder. Pinned by
   the new table_row_positions; the spec said "depth 9" but not the split.
3. Aggregate leaf-pin identities (D1): the exact P/Q pin equations
   (p*-H = sum eqw a_bl; q*-alphaH-D = sum eqw u_bl - (v^X+Y v^Y); table
   analogues with the fused-row MLE and multiplicity weights). Derived from
   Section 3.2's prose; recorded in the "working notes" block above and in
   ring_matmul.rs leaf_pins.
4. Freshness enforcement surface (D2/N3): release builds set panic="abort",
   so catch_unwind can't observe the one-time-use assert. Added
   MaskSet::is_used() as the testable marker (the prove-side assert still
   aborts on real reuse). Reset via harness_reset_freshness for the rank
   probes / leak modelling.
5. D3 scope (per "less code" latitude): demonstrated the edges whose scope
   the design says GROWS under masking — E3-N1 (alpha now binds masks +
   blinders) and E4-N1 (pin psi now batches the mask openings) — plus
   masked tamper-rejects (E3-N4/N5 class). E3-N2 (kappa:=Y fusion) and
   E4-N2 (ct-round restart confinement) are structurally unchanged by
   masking and are inherited by the honest masked pass + D1's real ct-round;
   recorded rather than duplicated.
6. m-recovery / freshness harnesses use the fixed-coins (honest-verifier)
   transcript so the transcript stays an affine function of m / of m_a-m_b;
   the ordering-attack ACCEPT legs use it too (the spike's adversary-
   readable tape). Shipped legs use real ratcheting transcripts / the pin
   flag / committed pins.

## D4 measured numbers (for the U-K5e / Section 3.5 re-grade)

These are the measured replacements for the design doc's [MODEL] rows. All
from the shipped engine (self_test_lookup_zk + freeze-check), q8_31, k=8.

### Prover / verifier delta, masked vs unmasked (the descent core)
At the battery shape (witness depth 8, table depth 9, ONE instance, 20
reps, single thread):
  - prove  (both descents): masked 13.9 ms vs unmasked 6.9 ms  -> x2.0
  - verify (both descents): masked 0.79 ms vs unmasked 0.59 ms -> x1.4
Plain reading: the MASKED DESCENT roughly doubles the sumcheck work (the
one degree-5 first round per layer, the extra w-round, the correction
summands and the g-mask evaluations). BUT the descent is O(N) and a small
fraction of a real pass: at the FFN point the pass cost is dominated by the
tensor weight-expansion (~2.3e7 ring-op-equivalents, M4_LOOKUP_DESIGN),
against which even a doubled descent is noise. So the PASS-LEVEL prover/
verifier delta stays sub-percent, consistent with Section 3.5's [MODEL]
"< 1% of the 43 K-mult/el budget". The committed masked pass (both descents
+ 60 aggregate pins through a real 13-commitment ct-round) proves in ~13 ms
at the battery shape.

### Mask material (LKP-6 formulas evaluated) — committed per pass
At the frozen FFN point (witness depth 23, table depth 9 with blinders,
e_bits = 5):
  - witness masks: g 1197 + R 252 K-elements
  - table   masks: g  266 + R  84 K-elements
  - blinders:      8 x 2 trees x 32 instances = 512 K-elements
  - TOTAL: 2311 K-elements/pass = 36976 dce (16 base coeffs/K-el).
(Battery-shape sanity, dw=8/dt=9, e=0: witness g117+R72, table g146+R84.)

### Transcript bytes (LKP-7) at the frozen FFN point
Masked transcript volume (round polys + layer-1 quadruples + per-layer
G/boundary/openings), 64 B per K-element (16 base coeffs x 4 B, q<2^31):
  - witness: 385 rounds, 1862 K-elements
  - table:    84 rounds,  532 K-elements
  - PASS TOTAL: 2394 K-elements = 153216 B = 150 KB/pass.
(Design Section 3.5 estimated ~140 KB; measured 150 KB.)

Both LKP-6 and LKP-7 are pinned as freeze rows in `ring_matmul freeze-check`
(green); LKP-7 is the row added this tranche.

## Log

- 2026-07-10: tranche opened at ace3f9b; ledger written; Agents A and B launched.
- 2026-07-10: Agent A recon done (design doc + spike + engine read); D1 plan
  + pin identities + LKP-7 arithmetic recorded above; starting D1 build.
- 2026-07-10: D1-D4 ALL GREEN (Agent A critical path complete). Commits on
  perf/zk-batch-optimizations (local, not pushed): D1 U-K5c committed masked
  pass + m-recovery + LKP-7; D2 U-K5d E3Z-N1..N4 F5 pairs + rank canaries;
  D3 E3/E4 edges re-run under masking; D4 timing + measured numbers (this
  file). Full suite 42/42 green; freeze-check green (LKP-7 row added);
  ring self-test 202 checks pass in ~36s. Decisions the spec left open are
  listed under "## Decisions (spec-open, recorded here)" below. Remaining:
  D5 (Agent B, docs) and the orchestrator's Section 3.5 re-grade + label lift.
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
- 2026-07-10: TRANCHE COMPLETE. Agent B docs merged (a724bb9); orchestrator
  re-grade + label lift committed; suite 42/42 green re-verified independently;
  pushed. The U-K5 masking obligation (audit C-01 / design row 12) is closed at
  the subprotocol level. Next per the audit-aligned order: true U-K8 exit
  (masked lookup inside a committed FFN-shape pass with upstream range +
  downstream gate-o-up), then U-K9 kernel-grade K-mults + the H-03 memory
  refactor, then the GPU experiment.
