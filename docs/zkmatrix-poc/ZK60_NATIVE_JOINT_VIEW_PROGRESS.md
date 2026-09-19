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
