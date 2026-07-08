# PROGRESS — gadget-modulus decision study (F3) + Q4 lemma write-ups

Tranche: two analysis deliverables + one computation script (+ optional
standalone Rust spike). File lanes: NEW files only —
`docs/zkmatrix-poc/GADGET_MODULUS_DECISION.md`, `docs/zkmatrix-poc/Q4_LEMMAS.md`,
`scripts/gadget_modulus_study.py`, optional `zkmatrix-rs/src/bin/gadget_link_spike.rs`.
No modification of ring/*, ring_matmul.rs, lattice_matmul.rs, manifest.rs,
aux_ntt_core.rs, or existing docs (annotations go in the decision doc's
"integration notes" section).

## Done

- [x] Worktree fast-forwarded 7a3e7a0 -> 32b13fb (stale base; clean ff, no
      merge commit). All read-first context reviewed: ROUTE_R_BUILD_REPORT
      (F2/F3), AUTOMORPHISM_GATE_DESIGN (sect. 4 opt 2, Q-A4), ROUTE_R_DESIGN
      sect. 5, RING_MULT_BOTTLENECK sect. 6, ct_engine.rs (ARP, SLACK_OP=4D,
      JL_C=13), sigma.rs, params.rs, route_r_params.py, ring_matmul.rs
      U3b/U6/freeze-check, LLM_SCALE_ESTIMATE.

## Next

- [x] Unit 1: scripts/gadget_modulus_study.py (all tables computed, no
      hand numbers; runs clean; F3 numbers asserted-reproduced) — DONE.
      Headline outputs: option (a) x1.02 CPU / x2.04 GPU commit
      multipliers, link = 24 rows at w = 11 per FFN tensor (~59 KB,
      ~7 MB/pass, 2^-264); option (b) verified 2^28.45 per chunk but
      154 GB/pass + 3-9x the claim layer -> rejected; option (c) needs
      SLACK_OP <= 3.79.
- [ ] Unit 2: docs/zkmatrix-poc/GADGET_MODULUS_DECISION.md — commit.
- [ ] Unit 3: docs/zkmatrix-poc/Q4_LEMMAS.md (Q4.1–Q4.6) — commit.
- [ ] Unit 4 (optional): zkmatrix-rs/src/bin/gadget_link_spike.rs
      (standalone, no test hooks) — commit.
- [ ] Unit 5: suite green check (only needed if Rust touched), final
      PROGRESS, report back.

## Decisions / findings so far (from the read + hand checks, to be
   script-verified)

- F3 numbers reproduce by hand: extract 2^22.1 (slack 4D), 2^17.5 (slack
  20.8), defect 2^44.2 at q46 (0.8 bits under q46/2), q31 needs extract
  <= ~2^15 => slack <= ~3.8 at alpha = 3.
- Option (a) link design: structured small weights xi_(l,t)*2^i on bits =
  xi_(l,t) on values — ONE revealed integer y_l per row asserted by
  ct-claims at BOTH moduli; subsumes recomposition; no duplicate
  commitments. Per-row miss <= 2^-w (signed uniform w-bit xi), rows =
  ceil(256/w).
- Option (a) commit cost: q46 gadget layer re-derived honestly is
  kappa ~6-7, N_r ~62 at msg_r 32 => ~1.03x CPU MACs/element vs q31; the
  real penalty is the GPU int8 row (~2.2x on the bit fraction) and 1.37x
  commit-stream bytes.
- Option (b) per-chunk: (2B)^2 = 2^28.45 verified (prior 2^28.4 estimate
  good), budget closes per chunk BUT requires per-ring-element quadratic
  claims => bytes/time explode at FFN scale (fails <20% Class-3), and it
  does NOT escape the Q4.4 relaxed-opening lemma debt either.
- Q4.3 real finding: the engine's quadratic garbage terms (Ga, Gb) carry
  NO additive mask; simulation needs either an x-regularity assumption
  (fails for degenerate bit tensors) or an engine change (mask slots).
- Bit tensors are ~82.8% of committed element-equivalents (5.8x bill
  factor, 40% coverage, w=12) — NOT a small fraction; the build report's
  "SMALL bit-tensor fraction" phrasing needs an integration note.

## Environment

- Rust builds (only if spike is written):
  PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release  (from zkmatrix-rs/)
- Python suite from repo root:
  PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" python3 -m unittest discover -s tests
