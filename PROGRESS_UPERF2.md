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

## Round 3 (2026-08-17): lanes D and E — REAL-DATA GATE

New standing rule for round 3: besides the unit legs, every lane's
acceptance includes the REAL 3x16 full-statement rig on this box:
`M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
flock -w 7200 /tmp/zk-heavy.lock <your binary> uperf-pc full-profile 3 16`
must print `accept = true`, statement digest
`93a987002a7c4b60c3dfbfc62b7a4f0e5957d8ae2039014ff241e323285fb790`,
counted bytes 985,142 B and EVAL-PROOF DIGEST
`0ae9cdae66607239a80cc1f1dea36248370edadbe85214144aee7a5250d975be` at
ZK_THREADS 1 and 8, fast AND `ZK_UPERF_ORACLE=1` (the oracle run takes
~11 min: run it ONCE at your close). Peak RSS ~3 GB — always under the
flock. Baseline at a450b1f: 1T commit 4.2 / prove 32.1 / verify 7.3 /
wall 43.7 s; 8T 2.6 / 12.0 / 1.9 / 16.6 s [WSL QUIET].
Worktrees: `/home/victor/wt-uperf2-d` (branch uperf2-d) and
`/home/victor/wt-uperf2-e` (branch uperf2-e), both at a450b1f (+ this
ledger commit). Everything in "Standing rules" above still binds
(the box facts now read: the checkpoint, shard and the local export ARE
here; the frozen export's X files are not).

### Lane D — CLAIM LAYER + COMMIT PHASE (wt-uperf2-d)

OWNS: `zkmatrix-rs/src/ring/fold.rs` (ixf sumchecks), `zkmatrix-rs/src/ring/sumcheck.rs`,
`zkmatrix-rs/src/ring/commit.rs` (the A1 commit kernels' callers),
`zkmatrix-rs/src/ring/kfield.rs` (bulk kernels; lane A's additions are
merged — extend, do not rewrite), the bin's commit-phase functions
(`bf_load_layer` and the chain derivation helpers `bf_*` it calls,
`agg_digit_witness`, `bg_witness`, `bg_build_groups`, `bk_build_groups`
INTERNALS, the entry-commitment/statement builders they call) and the
claim-layer region of `bg_pass_run`/`bk_pass_run` (the ixf instance
loops), a NEW `// [UPERF2-D]` bin section with subcommand `uperf-d`,
NEW `docs/zkmatrix-poc/U_PERF2_CLAIMCOMMIT_REPORT.md`, "Agent D status".
GOAL (in this order): (1) profile first — add observation-only
`prof::timer` phases (append ids `d.*` to ct_engine::prof) inside the
commit phase (chain derivation per layer, digit witnesses, entry
commitments, statement digests) and the claim layer (per ixf instance:
table expansion, sumcheck rounds, finals); run the 3x16 rig for the
table. (2) Deterministic ZK_THREADS in the claim layer's sumcheck
rounds (fixed reduction order; sumcheck.rs/fold.rs — the K-field bulk
kernels of kfield.rs are the substrate) and in the commit phase (chain
derivation matmuls: blocked i64 GEMM + threads; digit witnesses per
ring; entry commitments per column). Oracle: the current code under
`oracle_mode()`; the rig's digests are the gate. (3) Churn: KElem
clone/allocation churn in the sumcheck round loops if the profile says
so. Report + ledger section. Expected shares at 12x512 [MODEL]: claim
layer ~100 s serial, commit ~150-385 s serial — the two largest
remaining SERIAL terms after lanes A/C.

### Lane E — DESCENT CALLERS + DESCENT VERIFY + SMALL-COLS AUX (wt-uperf2-e)

OWNS: `zkmatrix-rs/src/ring/descent_fold.rs`, `zkmatrix-rs/src/ring/gkr.rs`,
`zkmatrix-rs/src/ring/gkr_masked.rs` (lane A's work is merged — extend),
the bin's BK descent-phase functions (`aligned_witness_tree`,
`neutral_tree` callers, `bk_tree_slots`, `bk_table_for`, `bk_pair_claims`,
the pair VERIFY loop in `bk_pass_run`'s verifier and its helpers), the
two GENERIC (misaligned) branches in eval_proof.rs ONLY
(`kernel_pass_factored`'s `if t.cols % D != 0` block and
`psi_level0_multi_impl`'s `if !aligned` block — nothing else in that
file), a NEW `// [UPERF2-E]` bin section with subcommand `uperf-e`,
NEW `docs/zkmatrix-poc/U_PERF2_DESCENT2_REPORT.md`, "Agent E status".
GOAL (in this order): (1) wire lane A's drop-ins (`gkr::build_tree_sparse`,
`gkr::build_neutral_tree`, the deferred boxed-leaf drop) into the
callers so no boxed leaf vectors are built for the descent trees
(U_PERF2_DESCENT_REPORT.md Section 7 says how; ~1.2 s of 5.4 s per pair
at 8T on the depth-20 bench). (2) Attribute the descent VERIFY: add
`prof::timer` phases (`e.*`) around the verifier's pair loop (table
rebuilds, eq tables, root cross-checks, leaf pins, masked_gkr_verify)
and run the 3x16 rig + `uperf-a descent-bench 20 8`; the rig's "36 s
descents verify" at 12x512 is NOT in masked_gkr_verify (3-5 ms/pair) —
find where it is and fix what is transcript-neutral (threads,
churn, cached tables). (3) The BK aux tensors have cols = 16 and
q-range coefficients (l0 = 16 limbs): a `small_cols` fast path in the
two generic branches — per value ring the K-weight row is 8 rows x 16
cols, so kw(vr, c1) = sum_c sr_c[8vr + c1/16] *_K col_c[c1 % 16]:
precompute per kernel the 16 (col) x 16 (d1) K-basis products once,
then per value ring 8 x 16 x n_k scalar-x-ring MACs against 16 x 8
cached rings (the aligned path's G/CQ0 trick with rows-inside-the-ring)
— OR, simpler and enough: hoist `kw` per value ring (already done) and
skip zero K-coordinates; measure first (kernel passes 10.9 s of the
32.1 s 3x16 prove are this). Oracle: `oracle_mode()` routes; the rig
digests are the gate; also `uperf-a descent-battery` 18/18 and
`uperf-pc diff-battery` (E2E) must stay green.

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

STATUS (2026-08-17, HEAD of uperf2-a; report:
docs/zkmatrix-poc/U_PERF2_DESCENT_REPORT.md):

- LANDED, all transcript-identical (descent digest 47a58a27..dafefb at
  depth 20 x 8 identical oracle vs fast and at ZK_THREADS
  1/2/4/6/8/12/16/22; battery 18/18 three-way identical at 1/2/7):
  1. `uperf-a descent-bench` (bk_pass_run's descent phase mirrored:
     aligned_witness_tree x n_real + neutral_tree pads + masks +
     masked_gkr_prove + the table side + verify with pins; a.* prof
     phases; DESCENT DIGEST; peak RSS) and `uperf-a descent-battery`.
  2. (a) five-table round kernel PL := p0 + lambda*q0 (`round_g5_body`)
     + block-copy extract: depth 20 x 8 prove 15.72 -> 12.82 s [WSL 1T
     NOISY-SHARED] (round-g -18%, fold -20%, extract -26%).
  3. (b) deterministic ZK_THREADS over block ranges in every packed
     descent kernel (round kernel: per-chunk exact-integer lazy planes
     summed in index order; out-of-place scratch folds; eq doubling;
     extract; tree steps; pack): 12.82 -> 3.37 s at 8T; saturates at
     ~4x by 6-8 threads on this hybrid WSL box (round-g 4.0x, fold
     2.7x) — the Mac's ~9x is the expectation (T1 must measure).
  4. (c) neutral pads never materialized nor computed:
     `FracTree::Neutral` (from build_tree/build_tree_sparse; every
     accessor answers as the full tree), kernels over the real
     instances' block ranges, the pads' round share in closed form
     (wire_pad(x) * F_t * eq(zeta_t, x) * sum_pads E(e)), pads
     materialized once per-instance size < 2 blocks; eq table as
     b-part x E(e) per real slice. 12.82 -> 7.59 s at 1T (2.07x vs the
     pre-change), 2.2-2.4 s at 8T (6.6-7.2x); bench peak RSS 3,589 ->
     2,419 MiB (T9: at the rig -11 GB of pad layers and ~-3 GB of
     untouched work-table pages at the peak pair).
  5. (d) sparse packed builders for blinded_witness_tree /
     blinded_table_tree; deferred boxed-leaf drop in build_tree at
     threads > 1; `gkr::build_neutral_tree` + `gkr::build_tree_sparse`
     offered as drop-ins for descent_fold.rs (not this lane's file).
  6. Gates at HEAD: self-test green, bh-verifier battery green,
     uperf-pc diff-battery green (O1/O2/O3/O5/E2E), freeze-check 98
     rows identical to the pre-change capture (then the expected BF
     panic).
- Extrapolation (linear in real leaf elements, box rates): the rig's
  witness-descent prove ~409 s pre-change -> ~249 s (1T) -> ~71 s (8T
  on this box) — the rig itself does not fit here (depth 22 x 16 =
  16 GB of trees + 12 GB of tables on the pre-change path).
- NOT landed / left: the caller-side boxed-leaf churn of
  aligned_witness_tree/neutral_tree in descent_fold.rs (now the largest
  term of the pair at 8T: trees 1.5 of 4.8 s wall at depth 20 x 8 —
  drop-ins provided, one-line change for the file's owner); the
  fold-into-next-round fusion (-40% table traffic on the memory-bound
  share; design note in the report); extract fusion into round 0
  (~12% at 1T); the "36 s descents verify" of the rig is NOT in
  masked_gkr_verify (3-5 ms per pair here) — it sits in the claim
  builders around it.
- Every number [WSL-BOX NOISY-SHARED] (lane C built/ran throughout).

## Agent D status (wt-uperf2-d)

- (lane launches here)

## Agent E status (wt-uperf2-e)

- 2026-08-17 PLAN COMMIT (lane E, branch uperf2-e at d3a4602). Files:
  descent_fold.rs / gkr.rs / gkr_masked.rs, the bin's BK descent-phase
  functions + the pair VERIFY loop, the two generic (misaligned)
  branches of eval_proof.rs, a `// [UPERF2-E]` bin section with
  `uperf-e {bench, diff-battery}`, prof ids `e.*` appended to
  ct_engine::prof, docs/zkmatrix-poc/U_PERF2_DESCENT2_REPORT.md.
  Baseline capture BEFORE any code change: freeze-check from the
  untouched build at d3a4602 — 98 `ok` rows then the expected BF panic
  (scratchpad/e_freeze_baseline.txt). Plan, in order:
  1. Wire lane A's drop-ins: `aligned_witness_tree` ->
     `gkr::build_tree_sparse` (aligned member entries + blinders as
     (index, p, q); same leaf sequence, bit-identical tree; the boxed
     2 x 2^depth leaf pair never exists), `neutral_tree` ->
     `gkr::build_neutral_tree`; the scalar oracle field and
     `oracle_mode()` keep the boxed builders. Measure with `uperf-a
     descent-bench 20 8` and the 3x16 rig.
  2. Descent VERIFY attribution: `e.*` timers around the verifier's pair
     loop (zero_masks shells, masked_gkr_verify, root cross-checks,
     bk_pair_claims split into mask claims / witness publics / table
     publics) + the misaligned kernel-pass and psi0 branches; run the
     rig; fix what is transcript-neutral.
  3. Small-cols K-basis fast path (`SmallColsFactored`, additive) for
     tensors with cols | D (the BK aux tensors, cols = 16): per kernel
     the hoisted row factors sr = scale *_K row, the conj-packed
     coordinate slices CQ0 of the (zero-padded) col kernel and the
     alpha-contracted G[d1] rings once; per value ring PHI_vr =
     sum_rr X^{-rr*cols} * sum_k sum_d1 sr_k[rows_per_vr*vr+rr][d1] *
     G_k[d1] (u128 lazy MACs, one reduction, negacyclic rotation per
     row-in-ring; zero row factors skipped) and for the rows pass
     T_k[d1] = sum_(vr,rr) sr_k[..][d1] * X^{-rr*cols} V_vr then
     b_rows[cd] += sum_d1 sigma * CQ0_k[(cd-d1) mod 16] * T_k[d1] — the
     O5 identities with rows-inside-the-ring. Same code serves the
     verifier's psi generic branch. Oracle: the current generic branch
     under `oracle_mode()`; `uperf-e diff-battery` = per-tensor
     kernel_pass_factored / psi_level0_factored_multi against the
     reference on random small-cols tensors (cols 16 and 8, l0 16,
     sparse block rows) at ZK_THREADS 1/2/7 + the rig digests.
  4. Gates: `uperf-a descent-battery` 18/18, `uperf-pc diff-battery`
     (E2E) at 1T/7T, freeze-check 98 rows == baseline, `self-test`, the
     3x16 rig at ZK_THREADS 1 and 8 fast + ONE oracle run (digest
     93a98700.., 985,142 B, EVAL-PROOF DIGEST 0ae9cdae.., accept).
  5. Report + this section.
- 2026-08-17 CLOSE (lane E; commits ebb1e25 plan, efc039f items 1-3,
  6300f2d battery/bench, a2bbc12 streamed builder, 5852892 sparse fill,
  f00dab1 report, cb4ee59 final; report:
  docs/zkmatrix-poc/U_PERF2_DESCENT2_REPORT.md). ALL FIVE DELIVERABLES
  LANDED, every change transcript-identical (the 3x16 REAL-DATA rig at
  close: accept, statement digest 93a98700.., 985,142 B, EVAL-PROOF
  DIGEST 0ae9cdae.. at ZK_THREADS 1 [35.2 s wall: 5.2 / 26.4 / 3.5] and
  8 [14.3 s: 2.5 / 10.4 / 1.3] fast, and under ZK_UPERF_ORACLE=1 at 1T
  [656.4 s]; self-test passed 241.6 s; descent-battery 18/18 at 1/2/7;
  uperf-pc diff-battery E2E at 1/7T; freeze rows identical; all
  [WSL NOISY-SHARED]). Merge note: prof ids 40-49 (`e.*`) collide with
  lane D's `d.*` append — renumber one block + its NAMES slice.
  1. Descent-tree callers: `descent_fold::aligned_witness_tree` ->
     `gkr::build_tree_sparse` first, then one step further — a NEW
     streamed, threaded packed builder `gkr::build_aligned_witness_tree`
     (member values generated on the fly by closures over the bin's
     integer layer data, positional fill per member over row chunks of
     whole KL-blocks, q table filled blockwise in parallel, p table
     calloc-zero) behind `descent_fold::aligned_witness_tree_fn`; the
     bin's `bk_tree_slot_fns` closures replace the boxed member columns
     of `bk_tree_slots`; `neutral_tree` -> `gkr::build_neutral_tree`.
     Scalar field / `oracle_mode()` keep the boxed bodies (and the
     pre-change caller). `uperf-a descent-bench 20 8 5 9` trees 1.68 ->
     0.69 -> **0.40 s at 8T** (a.tree-pack 0.44 -> 0.05; 1T 2.68 ->
     ~1.7 s), digest 47a58a27 identical [WSL NOISY-SHARED]. Finding:
     after the drop-ins the pack was the page-faulting + memset of the
     two fresh 64 MB leaf tables (35-50 ms per depth-20 tree), not the
     leaves (5-12 ms) — hence the calloc-p / parallel-q fill.
  2. Descent VERIFY attribution (`e.*` prof ids 40-49): FINDING E-F1 —
     on the 3x16 rig the verifier's whole pair loop (mask shells,
     masked_gkr_verify, root cross-checks, bk_pair_claims) is **0.06 s**;
     the "descents verify" is the misaligned aux tensors' K-weight rows
     inside bg.verify-group (`psi0` generic branch 3.51 s of the 6.9 s
     verify) and the same rows in the prover's kernel passes (7.33 s of
     31.9 s). Every pair-loop piece is O(depth) K-work — < 1 s at 12x512
     [MODEL]; nothing there needed a change.
  3. Small-cols aux tensors: hoisted K-weight rows in both generic
     branches (`kw_hoist` / `kw_row_hoisted`: scale *_K col once per
     kernel + nonzero row bounds; one K-mult per nonzero (kernel, c1);
     field associativity + exact zero skips = bit-identical; `kw_row_sync`
     kept as the pre-change body, the per-digit-ring reference under
     `oracle_mode()`): kw row 4,489 -> 106 us per value ring (42x; bench
     1040x16 x 80 kernels), rig 1T e.kpass-smallcols **7.33 -> 0.38 s**,
     e.psi0-smallcols **3.51 -> 0.19 s** — **wall 43.3 -> 36.3 s (prove
     31.9 -> 27.5, verify 6.9 -> 3.7)**; 8T 16.6 -> 15.7 s (verify 1.9 ->
     1.3) [WSL NOISY-SHARED]. The brief's K-basis form was worked out and
     NOT built: its per-kernel setup (256 ring products x ~80 kernels x
     27 tensors) exceeds the hoisted form's whole remaining 0.57 s — the
     mask kernels' rows are sparse blocks, which the hoist exploits.
  4. `uperf-e diff-battery` (24 tensors' rows three-way, 8 kernel passes
     fast == oracle == bg_kernel_pass, 8 psi0 legs; q31 x3 + q46) BATTERY
     DIGEST 59117121 identical at ZK_THREADS 1/2/7; `uperf-e bench`.
  5. Report + this section. Projection [MODEL]: the small-cols term at
     12x512 ~27 s -> ~1.5 s at 1T (prove ~1.0, verify ~0.5); the tree
     callers' churn ~1 min -> ~7 s 1T / ~1.5 s 8T (the phase is now the
     threaded tree steps in kfield.rs). Left: fold/extract fusion in the
     descent kernels (kfield.rs — lane D's file this round; the
     gkr_masked callers are ready), a leaf-table arena for the remaining
     page-fault cost, the K-basis form only for dense-row small-cols
     tensors.

## Agent C status (wt-uperf2-c)

- 2026-08-17 PLAN COMMIT (lane C, branch uperf2-c at c46483a). Method
  for every item: exact-integer NTT-domain evaluation over Goldilocks
  (aux_ntt_core), the pre-change body kept as `*_ref`, `oracle_mode()`
  honored, threads over independent outputs with a fixed reduction
  order — the PERF RULE unchanged. Item plan:
  - T7 `fold_chunks_ntt(cs, w_slices, chunk)`: c_j (|c| <= 2) and w
    (|w| <= 2^(e-1) <= 64) lifted to Z_p, c transformed once, each w
    once, r-term pointwise MAC per output, one inverse per z_u,
    `center_from_p` -> the exact i64 fold. Capacity is checked from the
    DATA bounds (r * D * cmax * wmax <= (p-1)/2; the composed pass sits
    at ~2^21 vs 2^63) and falls back to the `poly_mul_small` loop
    (`fold_chunks_ref`) otherwise. Callers `bg_fold` / `agg_fold` keep
    the `representable` assert and the digit split (now per-ring
    parallel via `decompose_polys_small`).
  - T3b `transport_level_from_psi`: three exact mod-q regroupings
    (radix scaling and the small-operand product commute with the
    alpha product; each next-witness ring is a scalar multiple of a
    per-SOURCE ring), so the general x general work collapses to two
    GEMV-shaped contractions — S[src] = a_l1 * psi[src] + sum_kap
    a_t4[kap] * A[kap][src] (chunk outputs x 12 terms) and T5[pos] =
    sum_kap2 a_t5[bi][kap2] * B_bi[kap2][pos] (t+h outputs x 11
    terms) — evaluated by a NEW `ntt_combine_general` kernel: both
    operands limb-split at `limb_bits(q)` (lo/hi/lo+hi transforms —
    the `A1LimbCommitKernel` contract), the alphas transformed once,
    3 Karatsuba sub-products accumulated in-domain (capacity asserted
    exactly for the term count; n <= 1024 at q46, 2^24 at q31), 3
    inverses per output, exact recompose mod q. The small-operand
    products (a_t4[kap] * c_j, a_l1 * cpair) ride `ntt_gemm_modq_small`;
    T1 is a scalar scale. Assembly per u is a fixed-order mod-q sum.
    Body kept as `transport_level_from_psi_ref`; threads over output
    blocks; battery leg at Q8 and Q8_46 with zero rings and every
    Z/T/H boundary of `NextLayout` (1 and 2 bindings).
  - `compute_psi`: per-u direct NTT accumulate (c_k transformed once,
    r phi rings per output, one inverse), windowed by
    `ntt_window_terms(q, 2)` with the ref as the over-capacity
    fallback; threads over u-blocks. `decompose_polys_modq/_small`
    parallel helpers for the `bg_matvec_chunks` / `bg_level_h` /
    `bg_fold` (and agg_*) digit splits.
  - Harness: `ring_matmul uperf-c diff-battery | bench [r] [chunk]`
    in a `// [UPERF2-C]` bin section; report
    docs/zkmatrix-poc/U_PERF2_EVALPROOF_REPORT.md.
  - Baseline capture BEFORE any code change: freeze-check's 98 `ok`
    rows from the untouched build (scratchpad), compared after each
    step.
- 2026-08-17 CLOSE (lane C; commits ed5b3b0 plan, b707af1 kernels,
  fa3340f transform, + the report commit; report:
  docs/zkmatrix-poc/U_PERF2_EVALPROOF_REPORT.md). ALL FIVE DELIVERABLES
  LANDED, plus one finding that changes the round's arithmetic:
  - FINDING (load-bearing for every NTT-domain kernel, Phase 0
    included): the length-128 Goldilocks transform cost 4.35 us fwd /
    5.24 us inv on this box, not the ~0.35 us the Phase-0 note costed
    it at — the carry/borrow selects of `add_p`/`reduce128` compile to
    mispredicted branches inside the butterflies (~40 cycles each). A
    kernel that transforms an operand ONCE therefore could not beat
    schoolbook (7.7 us) or Karatsuba (4.1 us): the first bench of T7 /
    psi / combine measured 1.8x / 1.0x / 0.8x. Fix (additive in
    aux_ntt_core.rs): `gl_add/gl_sub/gl_reduce128/gl_mul` on u128 sums
    with compare-based conditional subtracts (the only form LLVM keeps
    branchless here) and `ntt_fwd_fast/ntt_inv_fast` — IDENTICAL
    VALUES (battery leg on planted extremes + random, 504 rings) —
    1.50 us / 2.07 us. Every eval_proof.rs kernel, `ntt_gemm_modq_small`
    included, rides them; O2/O3/O5/E2E re-verified byte-identical.
    Shoup twiddles tried and dropped (no gain); SIMD is the next step.
  - T7 `fold_chunks_ntt` (+ `fold_chunks_ref`) in bg_fold/agg_fold:
    [WSL 1T NOISY-SHARED] 64x8192: 2.20 / 1.55 us per (c x w) product
    at e = 2 / 5 vs 9.65 / 10.07 oracle = 4.4x / 6.5x; 8T 0.56 / 0.39.
  - T3b `ntt_combine_general` (+ `_ref`; one-sided limb regime at q31,
    two-sided Karatsuba at q46, exact capacity, oracle fallback) and
    `transport_level_from_psi_fast` (+ `transport_level_from_psi_ref`;
    S / T5 / a_t4*c_j / a_l1*cpair once each, fixed-order mod-q
    assembly): transport level 18.6 us per next-witness ring vs 63.3 =
    3.4x at 1T (16.3 vs 70.7 = 4.3x at 16x2048); 8T 4.2 us. combine 12
    terms 2.45 vs 4.92 us per general product = 2.0x.
  - `compute_psi_ntt` (+ `compute_psi_ref`): 1.75 vs 5.18 us per term
    = 3.0x; 8T 0.32. `decompose_polys_modq/_small` parallel splits in
    the six bg_/agg_ call sites.
  - Phase-0 kernels on the fast transform: level-h 0.183 us/product
    (was 0.238) 1T, 0.033 at 8T; matvec 0.277 (was 0.64) 1T, 0.098 at 8T.
  - Gates at HEAD: `uperf-c diff-battery` (GL primitives; T7 34/34; T3b
    combine 14/14 + transport 40/40 phi_next AND h_next incl. both
    binding forms, every Z/T/H boundary, both moduli, `transport_level`
    flip; psi 11/11; splits 12/12) at ZK_THREADS 1/2/7 x3;
    `uperf-pc diff-battery` O1 4/4 O2 35/35 O3 63/63 O5 12/12 E2E 2/2
    at ZK_THREADS 1/2/7; `agg-matmul battery` 120.7 s green;
    `bh-verifier battery` green; freeze-check 98 `ok` rows identical to
    the pre-change capture (the trailing panic is now "layer 0 X export
    digest mismatch" because a `results/m125_ffn_export/` dir appeared
    in the main checkout during the session — orchestrator, see the
    report's Section 6).
  - Projection [MODEL]: the touched terms of the 125M 1T prove (fold
    ~40-60 s, prover psi ~35-45 s, transport ~10-25 s per side) go to
    ~25 s total at 1T and scale per output with ZK_THREADS; TASK_BOARD
    T1's one-binary A/B remains the honest test.
  - Left: SIMD Goldilocks butterfly (3-4x on every kernel here); a
    31-bit-prime NTT for the small x small fold only (~15x on T7); a
    per-level transformed-A cache shared by matvec and transport (1.3
    GB at level 0 — a T9 memory-diet trade). Details in the report.

## Orchestrator status (2026-08-17, after lanes A + C)

- Both lanes LANDED and MERGED (00b0288 A, a450b1f A+C) with the merge
  gate green at HEAD (uperf-pc diff-battery incl. E2E, uperf-a
  descent-battery 18/18, uperf-c diff-battery, all at 1T and 7T;
  freeze rows identical; agg-matmul + bh-verifier batteries;
  self-test). Lane reports: U_PERF2_DESCENT_REPORT.md,
  U_PERF2_EVALPROOF_REPORT.md.
- REAL DATA ARRIVED on this box (checkpoint tarball + val shard, Victor
  2026-08-17): the local re-export `results/m125_ffn_export_wsl/`
  (36/36 weights byte-identical to the Mac export; X differs by mlx
  CPU-vs-Metal rounding; 0 range violations) makes the 3x16
  full-statement rig runnable here (`M125_EXPORT_DIR=...`). FIRST
  REAL-DATA A/B (`uperf-pc full-profile 3 16`, WSL 1T): oracle 682.8 s
  (44.3 / 478.6 / 159.7) -> Phase 0 72.0 s -> lanes A+C **43.7 s**
  (4.2 / 32.1 / 7.3) — **15.6x at 1T; 16.6 s at ZK_THREADS=8 (41x),
  verify 1.9 s** — statement digest, bytes, verdict, EVAL-PROOF DIGEST
  identical throughout (U_PERF_WAVE_REPORT.md 4.2). Also found and
  fixed on the way (d3ec01f): the verifier's psi generic branch on the
  misaligned BK aux tensors recomputed per DIGIT ring (137 of 142 s
  verify at 3x16 -> 10.4 s), byte-identical.
- What the 3x16 table says is next (1T, after A+C): kernel passes 10.9 s
  (misaligned aux tensors' K-weight rows dominate at small T), level-h
  8.1, psi0 5.6 (verify), commit 4.2, claim layer 3.2 (SERIAL — the
  ixf sumchecks), matvec 3.0, transport 2.7, descents 3.2 (tiny at
  T = 16; ~300 s-class at 12x512 after lane A's 2x). Round 3 lanes: D
  (claim layer + commit phase threading/churn) and E (descent callers
  wired to lane A's drop-ins + the descent VERIFY attribution + the
  small-cols aux tensors) — both now gated on the REAL 3x16 rig
  (digest identity + accept) besides their unit legs.

## Log

- 2026-08-17: tranche opened at 9d76046; lanes A (descents) and C
  (eval-proof leftovers) launched in worktrees; Attestable float/int
  fallback recorded per Victor.
- 2026-08-17 (later): real data on the box; A + C merged; the 3x16
  real-data A/B recorded (15.6x at 1T, 41x at 8T); round-3 lanes D/E
  briefed below.
