# Handoff: F12 fixed, every M-carrying profile is now `/2` (2026-11-04)

For Sol, Astra and any lane that names a profile string or reads a capture. From the coordinator (Claude), after Victor's
ruling D65(1) in `docs/zkmatrix-poc/ZK60_DECISIONS.md`.

## What changed in `hashline`

- **The fix.** Finding F12: the mask commitment M's check combined its claims with powers of θ starting at θ⁰ = 1, so it
  certified the first claim only up to an offset the prover chose. It now starts at θ¹ (`zk.rs`, `combined_weights`).
- **Every profile whose receipts carry an M opening has a new version.**
  - 130 strings go from `/1` to `/2`. The D55 run strings follow their bases.
  - The `--zk` headers are `P1/2`, `P1-v3/2` and `HL-ZK/2`.
  - Fresh IO goes to `/3`.
  - The seam magic is `HLSEAM02`.
  - The full list: `results/zk60_f12_fix_20261104/profile_versions.tsv`.
- **Old strings are refused by name in every build** (`shape::pre_f12_refusal`). An old receipt no longer verifies.
- **Moved pins** are in `results/zk60_f12_fix_20261104/REPIN.md`. Among them are the six trained digests:
  - R13_SHIELD `5a6193d3`;
  - R13_8B `f590b01f`;
  - W16_SHIELD `79f987ef`;
  - W16_8B `a8258241`;
  - W16R2_SHIELD `0e88d84f`;
  - W16R2_8B `90003b76`.

## Also changed the same night (D65(2), D66(3))

- **Prove commands refuse with one constant line:**
  `{"event":"refused","command":<cmd>,"error":"refused","detail":"owner-private"}`. The detail goes to the owner's private
  log, `$HOME/zk60-owner-private/refusals.log`, or `$HL_OWNER_PRIVATE_DIR`. The commands: token `prove`,
  `classify-prove`, `classify-prove-batch`, `trained-prove`, `stack-prove`. Verifier refusals keep their text.
- **The DD dictionary's LogUp refusal is challenge-only.** No receipt byte moved.

## What each lane needs to update (not done by the coordinator: these files are yours)

- **`apps/proven-media`:** `proven_media/shieldstral_runtime.py:20` names the Shieldstral profile `…/1`. It needs `…/2`.
  The app's refusal display (`provers.py`, `_refusal_text`) will now show the constant "refused".
- **Python capture tools** pin the old strings:
  - `scripts/zk60_native_capture.py`;
  - `zk60_private_block_inventory.py`;
  - `zk60_attention_native_inventory.py`;
  - `zk60_opus_repaired_capture.py`;
  - `zk60_opus_io_layout.py`.
  They still read the archived `/1` captures correctly. For new captures they need the `/2` strings.
- **`scripts/zk60_io_opening_translation.py:162`** recomputes M's combination from `theta = ONE`. For any capture made by
  this build it must start at `mask["theta"]`.
- **The D55 privacy-gate records** (12 merged records and the earlier rounds) and every `/1` capture are invalidated.
  - Re-capture under `/2` and re-gate before any real-content switch.
  - The switch was closed anyway: `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is false, and D60 waits on GPU-made bundles
    and D63.
