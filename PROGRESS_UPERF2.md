# U-PERF2 tranche ledger — the second performance round (after Phase 0 kernels)

Branch: main (orchestrator) with lane worktrees `/home/victor/wt-uperf2-a`
(branch `uperf2-a`) and `/home/victor/wt-uperf2-c` (branch `uperf2-c`),
opened at 9d76046 (2026-08-17). Authority: Victor, console 2026-08-17
("Let's proceed on toward the goal ... spin up some agents to do the
heavy lifting so GROK can pick up the left over tasks ... proceed in
order of biggest performance improvements with the smallest work
first"). Standing plan: docs/zkmatrix-poc/CONTINUATION.md; executable
queue: docs/zkmatrix-poc/TASK_BOARD.md; the previous round's ledger:
PROGRESS_UPERF.md (read its two 2026-08-17 sections first — the path
correction and the Phase-0 kernels).

**Channel note (Victor, 2026-08-17):** Attestable has made ZK proofs of
LLMs fast with a MIX of floating-point and integer ZKPs (GPUs are much
better at floats). If the lattice line cannot meet the TARGET_CONTRACT
clocks after this round + the GPU rung, that mixed float/int approach
is the alternative to explore (CONTINUATION Section 3's fallback rule;
AGGREGATION_LITERATURE.md 2026-08-11 Attestable watch item). Not a
parallel rewrite now.

## Standing rules (every lane)

- The PERF RULE is unchanged: every optimization is DIFFERENTIAL —
  bit-identical transcript bytes / proof objects, unmoved freeze
  digests, identical verdicts at fixed seeds. Every changed entry point
  keeps its pre-change body as a `*_ref` oracle AND honors
  `ring::eval_proof::oracle_mode()` (`ZK_UPERF_ORACLE=1` routes to the
  oracle at runtime — the one-binary A/B). Threads: use
  `ring::eval_proof::threads()` / `pooled(...)`-style splits over
  independent exact work with a FIXED reduction order (bit-identical
  for any `ZK_THREADS`); the battery must pass at ZK_THREADS 1/2/7.
- BOX FACTS (this is the WSL box: Intel Core Ultra 9 185H, 22 threads,
  15 GB RAM, NO m125 export, NO checkpoint): the 125M rig, freeze-check's
  UAGB1-BF rows, and any `pass-agg`/`table-descent`/`m125-pass` run
  CANNOT run here. Everything must be proven on SYNTHETIC shapes with an
  oracle. `freeze-check` runs 98 rows green then panics at the BF rows —
  expected; assert the 98 `ok` rows are identical to your baseline
  capture. The python suite here: 77 pass / 2 skip / exactly 4
  export-caused failures (TASK_BOARD 2.1) — anything else is real.
- MEMORY DISCIPLINE (hard): the box has 15 GB total, TWO lanes run at
  once, and each build takes ~3 GB. Never exceed ~4 GB RSS in one run;
  size benches accordingly (e.g. descent depth 20 x 8 trees, not 22 x
  16); wrap anything heavier than ~2 GB or ~5 minutes in
  `flock -w 7200 /tmp/zk-heavy.lock <command>` so the two lanes never
  overlap heavy runs; check `free -g` first. Wall-clock numbers taken
  while the other lane runs are `[WSL-BOX NOISY-SHARED]`; quiet ones
  `[WSL-BOX QUIET]` — label every number.
- COMMAND HYGIENE (Victor gets a phone prompt for every non-allowlisted
  command): no `cd`, no `PATH=`, no `sed -i` (use the Edit tool), no
  interactive git, NEVER `git push`/`checkout`/`reset`/`rebase`/`rm`.
  Build with `cargo build --release --manifest-path
  /home/victor/wt-uperf2-<lane>/zkmatrix-rs/Cargo.toml`. Read git with
  `git --no-pager ...`; commit with `git -C /home/victor/wt-uperf2-<lane>
  add ...` / `git -C ... commit -q -m '...'` (message prefix `U-PERF2
  <LANE>:`). SKELETON COMMIT FIRST (plan + report skeleton + ledger
  section), then commit after every green step — the orchestrator
  merges from the branch, so uncommitted work is lost work.
- FILE OWNERSHIP is strict (below). Anything outside your lane's files
  is read-only. Battery legs go in your OWN `uperf-<lane>` subcommand
  and your own bin section marked `// [UPERF2-<LANE>]`; do not edit
  `uperf_pc_*` functions (append a `Some("<your-arm>")` line to
  `uperf_pc_main`'s match ONLY if you must; prefer a NEW top-level
  subcommand registered next to `Some("uperf-pc")` in `main`).
- REPORT: your report file + your ledger section here + the final
  message: numbers with labels, what landed, what did not, honest
  fallbacks. Timing lines: [WSL-BOX 1T|NT, QUIET|NOISY-SHARED].

## Priority order (improvement / work), post-Phase-0 model of the Mac 1T full-statement prove (~1,300-1,600 s from 4,811 s; not yet measured on the rig — TASK_BOARD T1)

| rank | term | est. share now | lever | work | lane |
|---|---|---:|---|---|---|
| 1 | descents (10 folded pairs: 61 real + 11 pad witness trees at depth 21-22, ~208M leaf elements; `masked_gkr_prove` + tree builds) | ~630 s (~45%) | deterministic threads over instances/lane blocks + tree-build streaming + inner-loop churn; MUST be profiled first (synthetic bench at real depth) | medium-large | **A** |
| 2 | commit phase (chain derivation, digit witnesses, statement) | ~100-200 s (?) | threads + blocking; needs the export or the T1 profile | unknown | (T1 first) |
| 3 | fold `bg_fold`/`agg_fold` (small x small schoolbook, n_0 x 16K MACs) | ~40 s | exact NTT (Goldilocks) + threads | small | **C** |
| 4 | transport levels (`transport_level_from_psi`, prover AND verifier, ~12 general x general kara ring-mults per next-witness ring) | ~25 s each side | limb-split NTT-domain kernel + threads | medium | **C** |
| 5 | `compute_psi` (prover levels >= 1), `decompose_poly_*` loops, `bg_matvec_chunks` digit splits | ~10-20 s | NTT / threads | small | **C** |
| 6 | eval-proof leftovers already threaded (level-h, matvecs, kernel passes) | ~150 s at 1T | `ZK_THREADS` on the Mac (free) | none | — |
| 7 | verifier: descents verify (~36 s), transport (~25 s, lane C covers), psi (~10 s) | ~70 s | A + C | — | A/C |
| 8 | verify <= 2 s at 1T | — | DESIGN (TASK_BOARD T11 a'); R-row | design | orchestrator |

## Lane A — DESCENTS (worktree /home/victor/wt-uperf2-a, branch uperf2-a)

OWNS: `zkmatrix-rs/src/ring/gkr_masked.rs`, `zkmatrix-rs/src/ring/gkr.rs`,
`zkmatrix-rs/src/ring/kfield.rs`, `zkmatrix-rs/src/ring/sumcheck.rs`
(INTERNALS; public API source-compatible — every caller in the bin and
descent_fold/lookup consume as-is), a NEW `// [UPERF2-A]` section at
the end of `zkmatrix-rs/src/bin/ring_matmul.rs` with the subcommand
`uperf-a` (registered in `main` next to `Some("uperf-pc")`), NEW
`docs/zkmatrix-poc/U_PERF2_DESCENT_REPORT.md`, and the "Agent A status"
section below. May add observation-only `prof::timer` calls inside its
files (phase ids appended to `ct_engine::prof` NAMES/N_PHASES — that
one edit in ct_engine.rs is allowed; nothing else there).

DELIVERABLES, in order (commit after each):
1. PLAN COMMIT (skeleton report + ledger section + the arm stubs).
2. `uperf-a descent-bench <depth> <l> [n_real]`: build `l` PACKED trees
   (n_real blinded aligned witness trees with random small leaves +
   `l - n_real` neutral pads — mirror `bk_pass_run`'s descent phase:
   `aligned_witness_tree`/`blinded_witness_tree`, `neutral_tree`,
   `draw_masks`, `masked_gkr_prove`, `masked_gkr_verify`; fixed test
   seeds), print wall + attribution: tree build vs `masked_gkr_prove`
   (inside: layer-1/fold, per-layer bulk rounds, boundary/openings,
   mask evals, transcript) vs `masked_gkr_verify`; a `[UPERF2-A]
   DESCENT DIGEST` = SHA-256 over the MaskedDescentProof + DescentEnd
   bytes at the fixed seeds. Sizes: iterate at depth 18-19 x 4; ONE
   attribution run at depth 20 x 8 (~2 GB packed) under the flock;
   depth 21-22 x 16 (the rig) is NOT runnable here — extrapolate
   linearly and say so.
3. Optimize the measured shares, transcript-identically, keeping the
   pre-change path reachable under `oracle_mode()`: (a) deterministic
   `ZK_THREADS` parallelism — over instances (trees) and/or lane blocks
   in `masked_rounds_bulk`, tree builds, eq/mask tables — with fixed
   reduction order; (b) allocation/clone churn in the round loops
   (KElem = Vec<u64> clones, per-round Vec allocations); (c) any
   kernel-grade win in the bulk paths (kfield.rs KKern/KTab) you can
   prove byte-identical. Report each as its own before/after line.
4. `uperf-a descent-battery`: fixed-seed proofs at 3-4 small shapes
   (depths 4, 8, 12; l 1, 2, 8; with pads; masked AND zero masks)
   compared byte-for-byte oracle vs fast (flip
   `ring::eval_proof::set_oracle_mode` in-process) and at ZK_THREADS
   1/2/7; every proof verifies. Also run `ring_matmul self-test`
   (contains the [U-K9] battery), `bh-verifier battery`, `uperf-pc
   diff-battery`, and freeze-check (98 identical rows) at your HEAD.
5. Report: attribution table at depth 20 x 8, per-item before/after,
   thread scaling, extrapolation to the rig's 208M leaf elements, what
   is left. Memory note: peak RSS of the bench (this is TASK_BOARD T9's
   descent-tree question).

DO NOT: change what is absorbed into any transcript, mask sampling
order, tree/leaf layouts on the wire, or any freeze row; touch
eval_proof.rs / ct_engine.rs (beyond the NAMES edit) / descent_fold.rs
/ lookup.rs / the bg_*/bk_*/uperf_pc_* sections; run anything needing
the m125 export.

## Lane C — EVAL-PROOF LEFTOVERS (worktree /home/victor/wt-uperf2-c, branch uperf2-c)

OWNS: `zkmatrix-rs/src/ring/eval_proof.rs` (additive functions; the
Phase-0 kernels there are LANDED — read them first, reuse
`ntt_gemm_modq_small`, `NTT`, `pooled`/`threads()`, `oracle_mode()`),
the `bg_fold`, `agg_fold`, `bg_matvec_chunks`, `agg_level_t`,
`bg_level_h`, `agg_level_h` functions in the bin (call-site switches
only), a NEW `// [UPERF2-C]` section at the end of the bin with the
subcommand `uperf-c` (registered next to `Some("uperf-pc")`), NEW
`docs/zkmatrix-poc/U_PERF2_EVALPROOF_REPORT.md`, and the "Agent C
status" section below. `aux_ntt_core.rs`: additive only.

DELIVERABLES, in order (commit after each):
1. PLAN COMMIT.
2. T7 — `fold_chunks_ntt(cs, w_slices, chunk) -> Vec<Vec<i64>>` (the
   exact i64 fold z_u = sum_j c_j * w_{j,u} in the Goldilocks NTT
   domain: c_j quinary, |w| <= 64, so 128 * 2 * 64 << p/2 — the
   integer result is recovered exactly with `center_from_p`); callers
   `bg_fold` / `agg_fold` (they keep the `representable` assert and the
   digit split); oracle = the current `poly_mul_small` loop; threads
   over u-blocks (fixed order); `oracle_mode()` honored.
3. T3b — `transport_level_from_psi` general x general products in the
   NTT domain: the alphas (12-24 fixed rings) transformed once, the
   per-ring operands (psi[src] / a_mat[.][src] scaled by radix, cpair,
   b_mat rows) are mod q GENERAL — use the limb-split contract (split
   one operand into two ~16-bit limbs at q31 so each sub-product fits
   the single-prime capacity; the aux `A1LimbCommitKernel` /
   `ring_mul_q_limbsplit` are the precedents) or an exact 3-product
   Karatsuba-in-limbs; keep the body as `transport_level_from_psi_ref`;
   threads over next-witness rings (independent outputs); battery leg
   at both moduli on random inputs incl. zero rings and the T/H/Z
   family boundaries of `NextLayout`.
4. `compute_psi` NTT (small operand c_k, general phi: reuse
   `ntt_gemm_modq_small` shape or a direct per-u accumulate) +
   threads; `decompose_poly_modq` / `decompose_poly_small` loops in
   `bg_matvec_chunks` / `bg_level_h` / `bg_fold` parallel over rings.
5. `uperf-c diff-battery` (your legs) + re-run `uperf-pc diff-battery`
   (its E2E leg covers bg_prove_group/verify end to end — it MUST stay
   green and identical under ZK_THREADS 1/2/7 and oracle vs fast),
   `agg-matmul battery` (exercises agg_fold/transport), `bh-verifier
   battery`, freeze-check (98 identical rows). Kernel benches for each
   item at level-0/level-1-like shapes with the oracle (`uperf-c
   bench`).
6. Report: per-item before/after us-per-unit and the projected Mac
   deltas; what is left.

DO NOT: touch gkr*/kfield/sumcheck (lane A), ct_engine.rs beyond
appending prof NAMES if you need a phase, descent_fold/pass_agg/
t_blind/lookup/wire/manifest; change transcript absorption or RNG
order; run anything needing the export.

## Orchestrator (main)

- Merges lane branches at their gates; the merge gate at HEAD: build,
  `uperf-pc diff-battery` (incl. E2E), `agg-matmul battery`,
  `bh-verifier battery`, `self-test`, freeze-check rows, python suite
  (77/2/4-known); then push main + perf/zk-batch-optimizations.
- TASK_BOARD upkeep so Grok's queue stays true (T1 remains the Mac's
  first job; the lanes' left-overs become new RUN/CODE rows).
- Design item: TASK_BOARD T11(a') (the sublinear verifier / chunk
  alignment R-row) — a written memo with the byte cost, for Victor's
  ruling.
- Ask (Victor): copy `results/m125_ffn_export/*.bin` (+ the calibration
  sidecar) from the Mac to the same path on this box — it unblocks the
  3x16 rigs, freeze-check's BF rows, and the commit-phase profile here.

## Agent A status (wt-uperf2-a)

PLAN (skeleton commit, 2026-08-17). Files: gkr_masked.rs / gkr.rs /
kfield.rs / sumcheck.rs (internals), a `// [UPERF2-A]` bin section
with `uperf-a {descent-bench, descent-battery}`, prof ids appended to
ct_engine::prof (`a.*`), docs/zkmatrix-poc/U_PERF2_DESCENT_REPORT.md.
Baseline capture taken BEFORE any code change: freeze-check from the
main worktree's binary built at 213dfa2 (code-identical to c46483a) —
98 `ok` rows then the expected BF panic
(scratchpad/a_freeze_baseline.txt).

1. Bench arm `uperf-a descent-bench <depth> <l> [n_real] [dt]`: mirrors
   bk_pass_run's descent phase (aligned_witness_tree with two synthetic
   members per real tree at bases 0 and n/2, neutral pads to l,
   draw_masks at fixed test seeds, masked_gkr_prove witness side, then
   the table side at dt with blinded_table_tree, masked_gkr_verify both
   with pins) and prints wall + prof attribution (a.tree-pack,
   a.tree-step, a.eq-table, a.extract, a.round-g, a.fold, a.scalar-tail,
   a.layer-glue) + `[UPERF2-A] DESCENT DIGEST` (SHA-256 over both proofs
   + both DescentEnds) + peak RSS (VmHWM).
2. Optimizations (each behind `oracle_mode()` with the pre-change body
   kept as `*_ref`): (a) drop the P0 work table — carry PL := p0 +
   lambda*q0 (wire = PL*Q1 + P1*Q0: 3 MACs -> 2 per node before the eq
   MAC; boundary p0 = PL - lambda*Q0 at the end; 5 folds per round
   instead of 6); (b) deterministic ZK_THREADS over block ranges in the
   round kernel (per-chunk lazy accumulators summed in index order — an
   exact-integer sum, so identical for any T), the folds (out-of-place
   into a per-layer scratch that is swapped in — the in-place fold's
   aliasing forbids a naive split), eq-table doubling, extract, tree
   steps; (c) block-copy extract; streamed pack in blinded_* builders.
3. `uperf-a descent-battery`: depths 4/8/12, l 1/2/8 with pads, masked
   AND zero masks; boxed-scalar oracle (KField::harness_scalar) ==
   bulk-ref (set_oracle_mode(true)) == bulk-fast, every proof verifies;
   prints a battery digest to compare across ZK_THREADS 1/2/7 runs.
4. Gates at HEAD: self-test, bh-verifier battery, uperf-pc diff-battery,
   freeze-check 98 rows == baseline.
5. Report + this section.

STATUS: (updated as steps land)

## Agent C status (wt-uperf2-c)

- (lane launches here)

## Log

- 2026-08-17: tranche opened at 9d76046; lanes A (descents) and C
  (eval-proof leftovers) launched in worktrees; Attestable float/int
  fallback recorded per Victor.
