# M4 SiLU activation gadget — tranche progress

Lane: NEW FILES ONLY — docs/zkmatrix-poc/M4_ACTIVATION_DESIGN.md,
scripts/silu_piecewise.py, results/m4_silu_error.txt, this file.
No edits to existing files; no pushes. Branch reset onto
perf/zk-batch-optimizations tip (5e17177) — this branch had no commits
of its own, so the merge stays trivially clean (adds only).

## Done
- Read TRANSFORMER_PROOF_PLAN, M2/M3 reports, GADGET_MODULUS_DECISION,
  SOUNDNESS_REFERENCE 4.3-4.7 + 6, LLM_SCALE_ESTIMATE 3b, and the U6a
  gadget code in ring_matmul.rs.
- Key design facts pinned: H3 slot Hadamard = 8 values/ring element
  (16x density penalty vs dense 128/element); binary+ARP at q46, units
  n <= 512; modulus link = public integer weight maps, per-row 2^-w;
  slot-constancy of slot-packed witnesses is NOT enforced anywhere yet
  (composition gap — must design + flag).

## Next
- [x] scripts/silu_piecewise.py (generator + exact evaluator + gadget
      trace + error harness + cost model)
- [x] results/m4_silu_error.txt (captured at recommended point)
- [x] docs/zkmatrix-poc/M4_ACTIVATION_DESIGN.md
- [x] final PROGRESS + report

## Decisions
- Domain trick: signed-direct segments on tau = x + 2^(W_in-1); NO
  abs/sign gadget (placement runs entirely at q46 over existing bit
  planes; m is folded into a link, never committed).
- Eval: per-segment degree-2 Horner in the local variable u, one-hot
  segment indicators; coefficient selection via modulus links with
  weights a_j/b_j/c_j (slot-packed targets) — K-independent slot cost.
- Two variants carried: (A) piecewise (slot-tensor bound) and
  (B) exact 256-entry one-hot table (256 dce/el, zero approximation,
  zero new machinery). Lookup argument flagged as the real M4 answer.
- Recommended operating point (harness-measured, NOT my prior guess):
  W_in=8/F_in=4 -> W_out=8/F_out=4, K=32, DEGREE 1, Pe=6 — deg-1 with
  more segments beats deg-2 with fewer because slot tensors (16 dce
  each) dominate indicator planes (1 dce each): 105 dce/el vs 124.
  Errors: approx_max 0.0068, ulp_max 1 (5/256 off by one ulp).
- Headline cost finding: +105 dce/el = +201% of the whole 7B/512 pass
  commit bill (marginal commit 193-242 s 22T, +15-18 s GPU, +108 GB
  stream). The piecewise route is buildable but blows the Class-3
  budget — quantified case for the lookup-argument primitive.
