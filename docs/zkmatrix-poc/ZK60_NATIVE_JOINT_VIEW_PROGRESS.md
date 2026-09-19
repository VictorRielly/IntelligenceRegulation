# ZK60 native joint view — lane ledger

Lane `zk60-native-jointview`, worktree `/home/victor/wt-zk60-jointview`,
based on `d399b32`. Delegated cryptographic-analysis lane working for the
security owner. Sole writer on this worktree.

**Scope guard.** P1 hides inputs, outputs and intermediate activations;
weights may be public. Nothing in this lane claims a privacy property is
established. A rank computed on a linear model at two receipts' real
challenges is evidence about that model at those challenges, nothing more.
D8/D11 (the caller-fixed endpoint-root obligation) is OUT OF SCOPE and is
not closed here.

## Owned files (nothing else is written by this lane)

- `scripts/zk60_native_joint_view.py` and helpers `scripts/zk60_native_jv_*.py`
- `tests/test_zk60_native_joint_view.py`
- `results/zk60_native_joint_view/`
- `docs/zkmatrix-poc/ZK60_NATIVE_JOINT_VIEW.md` (report)
- this ledger

Everything else — Rust, existing scripts, the capture writer, other
worktrees — is read-only.

## Inputs

- Captures: `results/zk60_native_captures_20260919/` (4 bundles: two
  `private-block-t32-poc/1`, two `private-attention-t32-poc/1`), manifest
  `validation.json`, source pin `2b5c65c3c430d6d6dd7ac24ab0c115181e36ca75`.
- Capture format: `docs/zkmatrix-poc/ZK60_NATIVE_CAPTURE.md`.
- Precedent (read-only, other worktree): `/home/victor/wt-zk60-mvp-fable`
  — `docs/zkmatrix-poc/ZK60_MVP_JOINT_VIEW.md`, `scripts/zk60_joint_view.py`,
  `scripts/zk60_joint_cfs_view.py`, `scripts/zk60_transcript_replay.py`.
- Review of the precedent whose criticisms apply here:
  `docs/zkmatrix-poc/ZK60_JOINT_VIEW_REVIEW_20260918.md`.
- Seeded predecessors whose numbers must be compared:
  `results/zk60_private_block_tools/`.

## Stages (each can FAIL)

1. **Transcript replay.** Re-derive the Fiat-Shamir transcript from captured
   public data with BLAKE3 in Python, label by label after
   `hashline/src/private_block/protocol.rs`; every captured checkpoint and
   every challenge reproduced exactly.
2. **Joint commitment-side view with the opened columns.** A and H together
   at the real challenges: claims, group combinations, 256 sampled columns
   with pads. Disclosed dimension expected A 0, H 2 (public LogUp identity).
   Pad-budget check.
3. **Joint masking-commitment (M/CFS) view** at the captured challenges;
   disclosed dimension expected 0.
4. **A and H and M stacked**; joint disclosed dimension vs sum of parts.
5. **Zero-witness gate**: same verifier view from the all-zero data planes
   with other mask/pad values; equal free dimension per channel; channels
   covered and not covered stated exactly.
6. **Negative controls** that must fire: masks removed; two planes sharing
   one mask pair; a commitment opened twice; an extra published helper sum;
   altered capture bytes (stage 1 must fail).
7. **Report** `ZK60_NATIVE_JOINT_VIEW.md`.

## Log

- 2026-09-19 — Lane opened. Read the capture memo, `validation.json`, the
  capture JSON skeleton (schema 3, `native-all-slots-v1`), the round-2
  precedent memo and Codex's 2026-09-18 review of it. Ledger created and
  committed before any analysis code. Next: read
  `hashline/src/private_block/protocol.rs` label by label and the precedent
  replay tool, then build stage 1.

- 2026-09-19 — **Stage 1 green on all four captures.** Sources read label by
  label: `zkp-core/src/transcript.rs` (state/counter, `squeeze`,
  `challenge_indices`), `zkp-core/src/ntt.rs`, `zkp-core/src/field.rs`,
  `zkp-core/src/pcs.rs` (`encode_row_zk`, `zpart_weights`, `group_zclaims`,
  `zk_rhos`, `verify_zk`), `zkp-core/src/sumcheck.rs` (`verify`, `CfsMask`,
  `CfsMasker`), `hashline/src/zk.rs` (`mask_commit/open/verify`),
  `hashline/src/native_capture.rs` (the capture writer), both
  `protocol.rs` files. Wrote `scripts/zk60_native_jv_field.py` (Goldilocks,
  Fp2, NTT, BLAKE3 transcript, exact rank/solve over Fp),
  `scripts/zk60_native_jv_capture.py` (schema-3 reader + manifest
  cross-check) and `scripts/zk60_native_jv_replay.py`.

  Result, from the capture's public data only (expected-IO policy bytes,
  public-statement digest, the pinned `parameters` literal, the block's
  `calibration` digest `blake3("B3 public fixed calibration v1")`, the
  schedule digest, the three roots, and every published field value):

  | capture | checkpoints | challenges | final counter | failures |
  |---|---|---|---|---|
  | block `40083e7a…` | 80 | 1543 | 1863 | 0 |
  | block `7d334e06…` | 80 | 1543 | 1863 | 0 |
  | attention `6c5e83fd…` | 65 | 1122 | 1442 | 0 |
  | attention `c26d1f05…` | 65 | 1122 | 1442 | 0 |

  A checkpoint is the pair (32-byte state, next Fp2 challenge) as
  `native_capture.rs::state` writes it, so the counter is checked too.
  Manifest cross-check: 4/4 JSON bundles match `validation.json` by sha256
  and byte count; all four are in `accepted` with
  `canonical_capture_reproduced` and `native_reverified` true and
  `privacy_review_complete` false. No surprise. Next: stage 2.

- 2026-09-19 — **Stage 2 green.** Model and reduction written up in the
  report §2. Numbers, all four captures: A 0, H 2, Input 0, Output 0 (Fp);
  the two H dimensions are exactly the public LogUp identity (the span of
  the disclosed row functionals equals the span of the sum claim's data-row
  weights, both of dimension 2). `k0 = 0` on every role. Pad budget: 231-247
  distinct sampled positions against 256 pads, margin 9-25; exact rank of
  the pad block 246 of 246 in 2.2 s as a cross-check. The verifier's own
  column identity and group identity were re-checked against my `E_j` model:
  0 failures. Surprise, resolved: one H claim (34 attention / 50 block)
  touches FOUR non-data rows — its own reserved pair plus the two zero-sum
  (u) rows, because the zsum slot evaluates them. The reduction is
  unaffected (only the reserved pair has to be exclusive) and the check was
  relaxed accordingly, with the count reported.

- 2026-09-19 — **Small model + controls green.** The reduction is validated
  against a brute-force dense rank on a toy instance of the same shape:
  honest 0 = 0, honest-with-zero-sum-pair 1 = 1. Controls fire: masks
  removed 24, shared pair 8, opened twice 10, extra helper sum 1, one pad
  fewer 3. Committed.

- 2026-09-19 — **Stages 3-6 green; one finding.** CFS: `rank R_s = dim C_s`
  on every slot of every capture (masks cover the whole consistency
  subspace); the mask's rounds stay inside it. FINDING: every published M
  functional lies in the round span (`rank F = 34/28`, `rank(F mod rounds) =
  0`), so the accounting of the DERIVED mask evaluations decides the answer:
  2 Fp counting only what the M opening independently reveals (the single
  Fp2 functional `q[0]+q[512]`, whose verifier identity was checked on all
  four captures), 68/56 Fp counting every derived value. In both readings
  the disclosed functionals are the slots' public terminal identities; the
  redundancy is nonlinear and linear algebra cannot show it. Reported as
  question 1 for the security owner, not explained away. Stage 4: joint =
  sum of parts = 4 Fp (disjoint randomness across the four commitments and
  M). Stage 5: zero-data preimage exists in the model on every covered
  channel (H's sum claim value is zero, checked); hash channels named as not
  covered. Stage 6: all controls fire, including the altered-bytes control
  on all four captures.

  Difference from the seeded runs (a finding): the seeded pair-schedule run
  records 8 H groups for the BLOCK profile and emits 7 H verdicts; the real
  receipts and `layout.rs` have 9. Its A side agrees (35).

  Gate `scripts/zk60_native_joint_view.py` runs all six stages in 19 s and
  writes `results/zk60_native_joint_view/joint_view.json` + `.done`. Tests:
  22 pass in 54 s. Report written. Lane complete.

- 2026-09-19 — **The two items owed by the security owner's answers (§9a) are
  in.** Both are checks in the gate, not prose.

  *Item 1 — the derived-mask-evaluation identity (report §3.1).* Per slot, on
  every capture: the claimed sum recomputed from the published scalars and
  hosted coefficients; every round's own `s(0)+s(1)=claim`; `fin_s`
  recomputed from the published rounds by a port of `sumcheck::verify` at the
  replayed challenges and equal to the capture's; `c_s ≠ 0`; and
  `mask_eval_s == (fin_s − terminal_polynomial_s)/c_s`. 23/23 block slots,
  18/18 attention slots, on both captures of each profile; plus every
  terminal republished as the PCS claim value its private table names
  (173/173 block, 112/112 attention). **Only the WEAK form is assertable**:
  `native_capture.rs:118` stores `terminal_polynomial` as the evaluated
  `fin − c·mask_eval`, and the slot's composition polynomial `def.poly` is a
  Rust closure the capture does not carry, so `poly_s(terminals_s)` cannot be
  recomputed here. Consequence, reported rather than hidden: the
  terminal-perturbation control does NOT fire the per-slot identity; it fires
  the terminal → claim cross-check and the transcript replay. Perturbing a
  round coefficient, `mask_eval` or `terminal_polynomial` fires the identity
  on all four captures. `c = 0` is refused at
  `private_block/argument.rs:275` and `private_attention/argument.rs:261`.
  The lemma with its three-line proof is report §3.1; the one captured field
  that would restore the strong form (a machine-readable `def.poly`) is
  listed there.

  *Item 2 — the pad-budget boundary (report §9b).* Predictions written before
  the runs, all three confirmed: `q_pad == distinct` discloses **0**,
  `distinct + 1` discloses **0**, `distinct − 1` discloses **3**. At the
  receipts' own geometry, 256 pads against 256 **distinct** positions:
  exact rank **256 of 256** (2.0 s). **The security owner's answer 2 is right
  and §9 question 2's sentence was wrong**; it is corrected in place (and the
  §2.3 "the margin only has to be positive" line with it). The opening-group
  vectors consume **no** pad freedom: measured directly in the model (rank
  over all rows = rank over the non-data rows = 32, consumed 0) and equal to
  `q_pad·k0`, which is 0 on every role of every capture. One correction of
  detail: the PCS pad block is a **Vandermonde** (`encode_row_zk`), not a
  Cauchy matrix; the Cauchy block is the masking commitment's — the
  conclusion is the same for both.

  Gate: 23 s, exit 0, all six stages ok, `privacy_property_established` and
  `privacy_review_complete` still false. Tests: **30 pass in 49 s**.
