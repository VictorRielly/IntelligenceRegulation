# U-PERF tranche ledger — the performance round (prove/verify walls)

Branch: perf/zk-batch-optimizations, opened at ed1b637 (2026-08-11).
Authority: Victor, console 2026-08-11 ("Let's move on to the next
stages ... it also provides pressure for us to get there faster") —
the speed round the roadmap's Section 4/5 levers and the Attestable
watch item (AGGREGATION_LITERATURE addendum 2026-08-11) both point
at. U-AG-B1 stays OPEN pending its FINAL (quiesced p50/p95 + A1
reconciliation — runs at THIS round's close when the box is quiet;
BL-F2 hiding-tails ruling and the [MODEL]-line reconcile ride that
FINAL).

Standing constraints inherited from U-AG-B1 verbatim (I-6 hard, Z1,
one-proof rule, exact-digit, freeze digests NEVER move, suite +
freeze-check green at every claim, [MODEL]/[MEASURED]/[MAC-BOX]
flags, codex-audit-* read-only, honest fallbacks). PERF-SPECIFIC
RULE: every optimization lane is DIFFERENTIAL — bit-identical
verdicts and unmoved freeze digests are the acceptance floor; a
speedup that moves a digest is a bug, full stop.

Baseline profile (wave-4 close, [MAC-BOX ~1T, NOISY-SHARED]):
composed P0 pass prove ~4,117-4,811 s (waves 68.8%, descents
25.5%, level-0 h cross-garbage Theta(n_0*r) at r=64 cap), verify
199.6 s post-split, m125 layer prove 250.4 s post-BF-F3; lookup
core 10.8 us/el scalar vs 0.5-1 us/el kernel-grade [MODEL]; U-K9
items B-D1..B-D3 (PROGRESS.md) still open — the oldest unclaimed
10-20x.

## Lanes (worktrees wt-uperf-pa/pb/pc/pd, branches uperf-pa..pd)

- PA (KERNEL, wt-uperf-pa): U-K9 at last — B-D1 lane-packed bulk
  slot arithmetic through the A1 kernel class + lazy reduction in
  round_poly/build_tree/fuse/descent hot loops; B-D2 KElem inline
  [u64;16]/SoA + streamed layers; B-D3 measured kernel report.
  Owns src/ring/kfield.rs + sumcheck.rs + gkr.rs + gkr_masked.rs
  INTERNALS (public API source-compatible — every other module
  consumes as-is). Differential battery: bulk path bit-identical
  to scalar; ALL freeze digests unmoved. Target class: the
  recorded 10-20x on the slot-mult-bound shares.
- PB (GPU RUNG, wt-uperf-pb): the first GPU kernel prototype per
  codex-gpu-readiness-2026-07-12 (verdict GO on prototyping) +
  GPU_PORT_CONTRACT.md. HONEST SCOPE: this box is Apple silicon —
  the prototype is Metal (or wgpu targeting Metal), proving the
  kernel STRUCTURE (NTT/ring-mult/commit hot loop off-loaded,
  bit-identical results vs CPU, measured speedup on THIS box);
  the CONTRACT's consumer-GPU rung (CUDA-class) remains
  conditional on hardware and is NOT claimed. Feature-gated build
  (default build unchanged); new zkmatrix-rs/src/gpu/ module +
  build plumbing only.
- PC (WAVE/OPENING OVERHEAD, wt-uperf-pc): the 68.8% — wave-round
  batching/lifting in ct_engine.rs + the level-0 h cross-garbage
  Theta(n_0*r) hot spot + the 1.03 s seed-XOF CRS expansion (BH's
  residual profile) in eval_proof.rs. Owns ct_engine.rs +
  eval_proof.rs internals (public API stable; PA does NOT touch
  these two files). Differential + digest discipline identical to
  PA. Target: measured pass-prove reduction with the profile
  attribution table.
- PD (ATTENTION INTEGER SPEC, wt-uperf-pd): the contract's
  declared 8B gap and the full-LLM comparability long pole —
  DESIGN round (M4 pattern: paper + Python spike, NO engine
  files): integer specifications for softmax, RMSNorm, RoPE,
  residual/embedding at the frugal-lm 125M shapes first (real
  activation ranges from the calibration study), gadget
  assignments from the existing family (matmul/Hadamard/lookup/
  range — softmax exp via the lookup class, normalization via
  range+requant), the claim-DAG extension, byte/prove cost
  derivations [MODEL], and the build-round obligation list. NEW
  docs/zkmatrix-poc/ATTENTION_INTEGER_SPEC.md + scripts/
  attention_spec_spike.py.
- Orchestrator: merges (PA/PC seam = none by file zones; PB
  feature-gated; PD doc-only), differential gates at every merge,
  U-AG-B1 FINAL quiesced pass + A1 reconciliation at this round's
  close, push, brief.

## Agent PA status (wt-uperf-pa)

- (lane launches here)

## Agent PB status (wt-uperf-pb)

- (lane launches here)

## Agent PC status (wt-uperf-pc)

- (lane launches here)

## Agent PD status (wt-uperf-pd)

- PLAN (2026-08-11, committed before work). Deliverables:
  docs/zkmatrix-poc/ATTENTION_INTEGER_SPEC.md (NEW),
  scripts/attention_spec_spike.py (NEW, stdlib+numpy), one dated
  additive note in TRANSFORMER_PROOF_PLAN.md Section 2, this ledger
  section. Design decisions the spike must machine-check: (1)
  softmax exp via the HOUSE LOOKUP CLASS at a 256-row per-(eS, d_h)
  table family (silu-int8-table-v2 family precedent); range
  reduction stated exactly as: proven power-of-two requant of raw
  scores to the calibrated int8 grid, then EXACT row-max
  subtraction — dominance = the [0, 2^8) range fact on d = m - s,
  attainment = a binary argmax selector (RangeLookup w1 +
  row-sum-1 thin sumcheck + z o d = 0 zero-check); (2) causal mask
  by public-weight derivation of the masked score read sM (no
  masked-leaf machinery; d in [0,254] structural, full-rectangle
  lookup); (3) BOTH normalizations (softmax row-normalize, RMSNorm)
  as floor-division relation facts — deg-3 zero-check with
  broadcast divisor + two-sided remainder range facts — the
  reciprocal-class fact in the range/lookup vocabulary, no
  floating-point escape; (4) RMSNorm sqrt as the isqrt fact pair
  D^2 <= SS + Ceps < (D+1)^2 (two range facts + one self-Hadamard);
  the rsqrt TABLE alternative REJECTED with the
  mantissa-normalization variable-shift arithmetic recorded; (5)
  RoPE via frozen PUBLIC cos/sin integer tables + the bit-flip MLE
  read (degree-2, non-interleaved mlx convention); (6) GQA via
  public head-map weights on the K/V side; (7) embedding: public-
  input form = public-selector matmul claim; private-input form =
  the one OPEN gadget, priced honestly (AZ-T1 style); unembedding =
  standard matmul (tied Emb reused), last-position variant priced.
  No new claim family for P0/P2 modes. Costs [MODEL] derived per
  layer + per pass at 125M and 7B/8B, anchored on M125_PASS_REPORT
  measured lines and the F-IF1/kel byte model. Gates: spike seeded
  + green < 10 min; python suite green from worktree root; no Rust
  files touched; no push.

## Blocker

(none so far)

## Log

- 2026-08-11: tranche opened at ed1b637 on Victor's console go;
  four lanes launching in worktrees. Competitive context recorded
  (Attestable watch item) — pressure, not panic: differential
  discipline unchanged, honesty rules unchanged.
