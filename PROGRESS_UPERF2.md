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

## Round 4 (2026-08-17): lanes F and G

State at 4dcaea6 (A/C/D/E merged): REAL 3x16 rig 1T 30.6 s / 8T 9.9 s
(vs oracle 682.8 s); REAL 12x64 rig at 8T: 46.0 s wall (commit 8.3 /
prove 33.6 / verify 3.6), **peak RSS 12.2 GB** — the 12x512 rig
(~40 GB) still cannot run on this 15 GB box. Phase rows at 12x64 8T:
descents 12.1 s (a.round-g 4.2, a.fold 3.8, a.tree-step 1.4,
a.extract 1.3, a.eq-table 0.9, e.tree-witness 1.8), level-h 8.3,
precommit-u0 5.5 (level-0 A matvecs), matvec 4.3, kernel passes 4.1,
digit witness 2.7, fold 2.3, psi0 2.4, crs 2.0, claim layer 3.2.
Gate for round 4: the REAL 3x16 rig at ZK_THREADS 1 and 8 (accept,
statement digest 93a98700…, 985,142 B, EVAL-PROOF DIGEST 0ae9cdae…)
AND the REAL 12x64 rig at 8T (accept, statement digest 80763ea5…,
EVAL-PROOF DIGEST 63f4a3a4…, `/usr/bin/time -f "maxrss %M KB"` for the
RSS row) — the 12x64 run needs ~12 GB: ALWAYS under the flock, and
NEVER concurrently with anything else heavy (check `free -g`; if less
than 13 GB is available, wait). Worktrees `/home/victor/wt-uperf2-f`
(uperf2-f) and `/home/victor/wt-uperf2-g` (uperf2-g) at 4dcaea6 (+ this
ledger commit).

### Lane F — MEMORY DIET (wt-uperf2-f) — the 12x512 rig on the 15 GB reference box

OWNS: `zkmatrix-rs/src/ring/eval_proof.rs` (whole file — no other lane
touches it this round), the bin's `bg_*` / `bk_*` composed-pass
plumbing (bg_witness, agg_digit_witness's OUTPUT type/consumers,
bg_precommit, bg_prove_group, bg_verify_group, bg_matvec_chunks,
bg_level_h, bg_fold, bk_pass_run's witness plumbing; the agg_* synthetic
rig may keep Vec<Vec<i64>> through an adapter), a `// [UPERF2-F]` bin
section + `uperf-f`, NEW `docs/zkmatrix-poc/U_PERF2_MEMORY_REPORT.md`,
"Agent F status".
GOAL, in order: (0) MEASURE FIRST: instrument peak RSS per phase on the
12x64 rig (a `[UPERF2-F] RSS` print of /proc/self/status VmHWM at the
phase boundaries — commit end, claim layer end, each descent pair,
before/after each group eval proof, verify) so the report has a
memory attribution table; the round-3 model says: w0 for BOTH groups
as Vec<Vec<i64>> (~1 KiB + heap header per digit ring: ~12 GB at
12x512, both groups alive through the descent phase), phi_cur (n_0
rings, ~8 GB act at 12x512), the descent pair's packed trees (~12 GB
for nrw-88 at depth 22), the claim-layer packed tables (~5.5 GB after
lane D). (1) w0 COMPACT: the level-0 digit witness as a flat
`Vec<i8>` (every digit alphabet is |w| <= 64) behind a small view type
(`DigitCols { data: Vec<i8>, n }` with `ring(i) -> &[i8]` and a
`to_i64_ring` scratch helper); consumers convert per ring inside their
kernels (the NTT kernels lift per ring anyway; `poly_from_small`,
`bg_fold`/`fold_chunks_ntt`, `bg_matvec_chunks`, `bg_level_h`,
`kernel_pass_factored`'s rows pass, `bg_precommit`, the floor/response
paths). Keep the deeper levels' witnesses (`w_cur`, zhat/that/hhat,
small) as they are if simpler. (2) phi NEVER MATERIALIZED at level 0:
`level_h_pairs_with(ctx, phi_block: impl Fn(j, u0, &mut [Poly]) + Sync,
w_slices, chunk)` fed per u-block from `PhiFactored::value_ring` (per
digit ring v = j*chunk + u locate (tensor, vr, limb) — consecutive u
are consecutive v — one PHI_vr per value ring cached across its l0
limbs, radix per limb; the same arithmetic as the phi pass, so no
extra cost) and the level-1 transport from
`psi_level0_factored_multi(...)` via `transport_level_from_psi` —
EXACTLY what `bg_verify_group` already does (byte-identical by the
seam differential); `phi_cur` for level 0 is never allocated. (3)
Drop what is dead: free the act group's w0 view of anything not needed
across the descent phase if the attribution says it matters; the
CRS matrices' memo clones (return Arc, no clone). (4) Report the
before/after RSS table (3x16, 12x64, and — if it now fits under ~13
GB — 12x128 / 12x256; do NOT attempt 12x512 unless the model says it
fits with margin) + the timing rows (must not regress; digests
identical) + what is left for 12x512 on 15 GB. Oracle: `oracle_mode()`
keeps the old materialized paths where the change is a routing; the
w0 type change is structural (no oracle) — its gate is the rig digests
+ `uperf-pc diff-battery` (E2E) + `agg-matmul battery` + `pass-agg
battery` (real data, ~14 legs; run ONCE at close under the flock) +
`table-descent battery small`.

### Lane G — DESCENTS, ROUND 2 (wt-uperf2-g)

OWNS: `zkmatrix-rs/src/ring/gkr_masked.rs`, `gkr.rs`, `kfield.rs`
(lanes A/D/E merged — extend), `descent_fold.rs`, a `// [UPERF2-G]` bin
section + `uperf-g`, NEW `docs/zkmatrix-poc/U_PERF2_DESCENT3_REPORT.md`,
"Agent G status". Do NOT touch eval_proof.rs, fold.rs, sumcheck.rs,
commit.rs, the bg_*/bk_* plumbing (lane F), other bin sections.
GOAL (U_PERF2_DESCENT_REPORT.md Section 7 + U_PERF2_DESCENT2_REPORT.md
"left"): (1) fold-into-next-round fusion in the packed descent kernel
(-40% table traffic on the memory-bound share) and extract fusion into
round 0; (2) a per-pair table arena (reuse the leaf/layer allocations
across pairs — the page-fault + memset cost lane E measured);
(3) thread scaling of a.round-g / a.fold / a.tree-step past the ~4x
saturation on this box if there is a deterministic split that helps
(chunk sizes, per-thread affinity to blocks); (4) the descent VERIFY
side is fine (E-F1) — leave it. Gate: `uperf-a descent-battery` 18/18
identical at 1/2/7T + `uperf-a descent-bench 20 8 5 9` before/after
(digest 47a58a27 identical) + `uperf-pc diff-battery` + freeze rows +
the REAL 3x16 rig at 1T/8T + the REAL 12x64 rig at 8T (digests above;
flock; not concurrently with lane F's 12x64 runs — coordinate through
the flock only) + `self-test` at close. Report: per-item before/after
[WSL 1T|8T labels], depth-20 bench + rig rows, projection to depth 22
x 16.

## Round 5 (2026-08-17): lanes H and I

State after lanes F + G (merged): REAL 3x16 1T ~28 s @ 0.96 GB, 8T ~9.3
s @ 1.0 GB; REAL 12x64 8T ~43 s @ 4.65 GB; 12x128 8T 66 s @ 7.4 GB
(lane F's run). What still keeps 12x512 (~the PoC shape) off this 15 GB
box: the largest descent pair (nrw-88: 12 real trees at depth 22) —
its packed trees (leaves + all layers = 2 x leaves x 64 B x 2 tables:
~12 GB) plus the fused kernel's work tables (~3.8 GB, lane G) on a
~1.5-2 GB floor. Round 5: H attacks exactly that; I attacks the
transform cost every NTT kernel pays. Both gated on the REAL rigs (3x16
at 1T/8T; 12x64 and 12x128 at 8T — digests: 3x16 statement 93a98700…
/ EVAL 0ae9cdae…; 12x64 80763ea5… / 63f4a3a4…; 12x128 4a3af8c3… /
742d88e1…, 1,372,775 B) plus the batteries. Worktrees
`/home/victor/wt-uperf2-h` (uperf2-h) and `/home/victor/wt-uperf2-i`
(uperf2-i). The 12x128 run needs ~7.5 GB: flock + `free -g` >= 9 GB.

### Lane H — DESCENT TREE MEMORY: layer checkpointing + tree pool (wt-uperf2-h)

OWNS: `zkmatrix-rs/src/ring/gkr.rs`, `gkr_masked.rs`, `kfield.rs`
(descent-side kernels; lanes A/D/E/G merged — extend), `descent_fold.rs`,
the bin's `bk_pass_run` DESCENT PHASE region only (the per-pair loop:
tree build calls, masked_gkr_prove calls, drops) plus a `// [UPERF2-H]`
section + `uperf-h`, NEW `docs/zkmatrix-poc/U_PERF2_DESCENT4_REPORT.md`,
"Agent H status".
GOAL: make the depth-22 x 12-real-tree pair fit in ~6-8 GB total
without changing a byte. (1) LAYER CHECKPOINTING in the packed
FracTree: keep the leaves and every c-th layer (c = 3 or 4 —
memory ~ leaves x (1 + 2^-c + ...) instead of 2 x leaves) and
recompute the intermediate layers from the checkpoint below when a
round needs them (the descent walks layers top-down; a layer is
needed for its round and the round below it; each intermediate layer
gets rebuilt at most once per pair from the next checkpoint down —
about one extra tree-build's worth of K-work per pair, on the
threaded tree-step kernels). Bit-identical by construction (same
fractional sums in the same order — assert it: `uperf-a
descent-battery` 18/18 + `uperf-g descent-battery` 22/22 + the
DESCENT DIGEST 47a58a27… of `uperf-a descent-bench 20 8 5 9`). Make c
a knob (`ZK_K9_CHECKPOINT`, default = the value that fits 12x512 with
margin; 0 = keep every layer = today). (2) A same-size TREE POOL across
a pair's trees and across pairs + a release hook (lane G measured a
generic arena NEGATIVE — do the narrow thing: reuse the leaf/layer
tables of equal size, no size classes) — only if it lowers peak RSS
on the 12x64/12x128 rigs (measure with `/usr/bin/time -f "maxrss %M
KB"`; lane F's `[UPERF2-F] RSS` rows show the per-phase peak). (3)
Then, if the model says the 12x512 pass fits under ~13 GB: run it ONCE
here (`ZK_THREADS=8`, flock, `free -g` first, nothing else running) —
that is the PoC number on the reference box; record everything
(accept, statement digest, bytes, EVAL-PROOF DIGEST, walls, RSS) in
your report and the ledger. If it does not fit, say by how much and
what is left. Gate: the batteries above at ZK_THREADS 1/2/7,
`uperf-pc diff-battery` (E2E), freeze rows, `self-test`, REAL 3x16
1T/8T + 12x64 8T + 12x128 8T digests identical.

### Lane I — SIMD Goldilocks NTT (wt-uperf2-i)

OWNS: `zkmatrix-rs/src/aux_ntt_core.rs` (additive: new `ntt_fwd_simd` /
`ntt_inv_simd` + the pointwise helpers, dispatch by
`is_x86_feature_detected!("avx2")` / `cfg(target_arch = "aarch64")`
NEON, scalar `ntt_fwd_fast` stays the reference), the ONE-line call
sites in `eval_proof.rs` where `ntt_fwd_fast`/`ntt_inv_fast` are called
(a `ntt_fwd_best`/`ntt_inv_best` indirection — no other edits there),
a `// [UPERF2-I]` bin section + `uperf-i`, NEW
`docs/zkmatrix-poc/U_PERF2_SIMD_REPORT.md`, "Agent I status".
GOAL: lane C measured the length-128 Goldilocks transform at 1.50 us
fwd / 2.07 us inv (branchless scalar); the transforms are ~30-40% of
level-h / matvec / fold / psi / transport at 8T. Vectorize the
butterfly stages (4-lane u64 with AVX2 on this box: mul via 32x32
partial products or the u128 emulation, add/sub with the branchless
reduce; NEON on the Mac — write it, cannot be run here, mark
[UNTESTED-NEON] and gate it behind cfg so the Mac build still
compiles), keeping the values IDENTICAL (battery: random + planted
extremes + 4096 rings fwd/inv vs the scalar transform, and every
existing battery). Then measure `uperf-pc kernel-bench 64 8192` and
`kpass-bench`, `uperf-c bench` before/after and the REAL 3x16 / 12x64
rigs. If AVX2 buys < 1.3x on the transform, say so and stop early with
the finding. Gate: `uperf-i battery` (transform identity), `uperf-pc
diff-battery` (E2E), `uperf-c diff-battery`, `uperf-f diff-battery`,
freeze rows, `self-test`, the REAL rig digests at 1T/8T.

## Orchestrator status (2026-08-17, after rounds 4 + 5) — THE PoC SHAPE RUNS ON THE REFERENCE BOX

- Lanes F, G, I, H all LANDED and MERGED (33dd896, d38e9ce, a087a7d,
  96559ee), each with the merge gate green (every lane battery at 1T
  and 7T, freeze rows identical, agg-matmul + bh-verifier + self-test,
  the REAL rigs' digests). Reports: U_PERF2_MEMORY_REPORT.md,
  U_PERF2_DESCENT3_REPORT.md, U_PERF2_SIMD_REPORT.md,
  U_PERF2_DESCENT4_REPORT.md.
- **THE NUMBER (2026-08-17, commit 96559ee, this box = the TARGET_CONTRACT
  CPU reference machine, Intel Core Ultra 9 185H / 15 GB, ZK_THREADS=8,
  QUIET, wsl-export):** `uperf-pc full-profile 12 512` — the
  FULL-STATEMENT 12-layer x 512-token 125M FFN pass (BK's table-descent
  rig, P0): **accept = true, wall 155.6 s = commit 11.7 s + prove 134.9 s
  + verify 7.3 s, 1,509,911 B counted (= the frozen full-statement byte
  count to the byte), peak RSS 10.98 GB**; statement digest
  2f8a92f853c1813b4d87e30dc9a43a9cb65b0e009c994fffa67e14a6132b81ab (the
  wsl-export witness; the Mac's frozen 76dbf204… differs only by the X
  files' Metal-vs-CPU rounding), EVAL-PROOF DIGEST 4c259008c8e0cac2…
  (identical to lane H's two runs at 166.4 / 178.3 s). Cross-box
  reference: the ledger's frozen [MAC-BOX 1T] full-statement line was
  commit 384.9 / prove 4,811.0 / verify ~236 s at 41-47 GiB. The
  same-box, same-witness A/B (3x16, `ZK_UPERF_ORACLE=1`) is 682.8 s ->
  25.0 s at 1T (27x) -> 8.5 s at 8T (80x). Also on this box: 12x256 8T
  95.9 s @ 6.6 GB (lane H), 12x128 8T 55.1 s @ 4.15 GB.
- 12x512 8T attribution (rows >= 1 s): descents 72 s (bk.descent-gkr
  61.4: a.round-g 52.5, a.tree-step 15.7; bk.descent-trees 10.6 /
  e.tree-witness 10.6), bg.prove-group 38.7 (level-h 22.2, matvec-
  chunks 7.8, fold 3.7, kernel-rows 3.4), claim layer 23.9 (cl-folds
  10.5, cl-rounds 6.9, cl-tables 6.6), commit 11.7 (precommit-u0 10.1),
  verify 7.3 (psi0-factored ~6), crs 3.4, transport 2.2.
- What this means for the phase plan (CONTINUATION.md): Phase 0 and
  Phase 1's "125M composed prove in minutes" are MET on the reference
  box (2.6 min at 8T); the artifact size was already in gate; the
  verify line (<= 2 s, 1T) is NOT met (7.3 s at 8T; ~25 s-class at 1T
  by the 3x16 ratio) — TASK_BOARD T11(a'): a wording amendment (N
  threads stated) or a protocol change. Phase 2 (PoC close: p50/p95
  over >= 20 warm runs, AZB canary, A1 reconciliation) is now
  runnable HERE; a 20-run p50/p95 series at 12x512 8T is in flight
  (U_PERF_WAVE_REPORT.md 4.3 when done). Phase 3 (GPU): the fused
  descent kernel (a.round-g 52 s) and the NTT-domain GEMM (level-h 22
  s) are the first two kernels to port.
- Orchestrator note (lane I): our `--manifest-path` builds ignore
  `zkmatrix-rs/.cargo/config.toml` (`target-cpu=native`) — every number
  above is a BASELINE x86-64 build with runtime AVX2 dispatch only in
  the NTT; a native-build A/B is queued (repo-root .cargo config if it
  buys anything).

## Round 6 (2026-08-17): lanes J (CPU: AVX2 K-field kernels) and K (GPU rung, CUDA on this box)

State at 96559ee: 12x512 8T 155.6 s (descents 72 s = a.round-g 52.5 +
a.tree-step 15.7 + trees 10.6; prove-group 38.7 = level-h 22.2 +
matvec 7.8 + fold 3.7 + rows 3.4; claim layer 23.9; commit 11.7;
verify 7.3). GPU FEASIBILITY (orchestrator probe, 2026-08-17): this
box has an NVIDIA GeForce RTX 4070 Laptop GPU (8 GB, 50 W cap, sm_89)
reachable from WSL2 (driver 566.14 / CUDA 12.7). No CUDA toolkit is
installed and none is needed: `cudarc 0.13.9` (features driver, nvrtc,
cuda-12040, dynamic-linking, std) + NVRTC/cudart from the user-level
pip wheels (`python3 -m pip install --user nvidia-cuda-nvrtc-cu12
nvidia-cuda-runtime-cu12`), assembled at `/home/victor/cuda-root`
(include/ from the wheels, lib64/ symlinks: libcuda.so ->
/usr/lib/wsl/lib/libcuda.so.1, libnvrtc.so + libnvrtc-builtins.so.12.1,
libcudart.so). Build/run with `CUDA_ROOT=/home/victor/cuda-root
LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib`.
A Goldilocks mulmod kernel (`__umul64hi`, the same branchless reduce)
compiled at runtime via NVRTC ran 2^20 x 100 launches: 0 mismatches vs
the CPU, 14.75 G mulmod/s (bandwidth-bound: 3 x 8 B per element).
NVRTC needs `__umul64hi` (no `__int128` without a flag). The probe
project: scratchpad `cudaprobe/` (Cargo.toml + src/main.rs) — copy its
shape. Rules: the GPU path is FEATURE-GATED (`--features gpu-cuda`,
default OFF; the default build and the Mac build must not depend on
cudarc), runtime-enabled by `ZK_GPU=1`, and DIFFERENTIAL (bit-identical
outputs vs the CPU kernels — the CPU kernels are the oracle; the rig
digests are the gate). Worktrees `/home/victor/wt-uperf2-j` (uperf2-j)
and `/home/victor/wt-uperf2-k` (uperf2-k).

### Lane J — AVX2 in the packed K-field lane kernels (wt-uperf2-j)

OWNS: `zkmatrix-rs/src/ring/kfield.rs` (KKern/KTab lane kernels: the
descent round/fold kernels of lanes A/G, the ixf sumcheck kernels of
lane D, tree steps, eq tables), `gkr_masked.rs`/`gkr.rs`/`fold.rs`/
`sumcheck.rs` ONLY where a call-site switch to a `_simd` variant is
needed, a `// [UPERF2-J]` bin section + `uperf-j`, NEW
`docs/zkmatrix-poc/U_PERF2_KSIMD_REPORT.md`, "Agent J status".
GOAL: the K-field lane arithmetic (Z_q[Y]/(Y^16 - s) elements packed
as u32 lanes with lazy reduction) is the hot loop of the descents
(a.round-g 52 s at 12x512 8T) and the claim layer (cl-rounds/folds 17
s); vectorize the per-block inner loops with AVX2 (`vpmuludq` u32 x
u32 -> u64 lane products, lazy u64 planes, the existing reduction
discipline) exactly as lane I did for the NTT (asm `vpmuludq` if LLVM
mis-lowers; runtime `is_x86_feature_detected!("avx2")`; scalar path =
today's, `ZK_KSIMD=0` knob; NEON mirror behind cfg [UNTESTED-NEON]).
Values IDENTICAL (the exact-integer planes are order-independent;
assert with `uperf-a` 18/18, `uperf-g` 22/22, `uperf-h` battery,
`uperf-d` 30/30 at 1/2/7T + the descent-bench digest 47a58a27… + a
`uperf-j battery` on the lane kernels directly). Measure `uperf-a
descent-bench 20 8 5 9`, `uperf-d bench`, the REAL 3x16 1T/8T and
12x128 8T rigs, and ONE 12x512 8T (flock, `free -g` >= 12 GB, nothing
else heavy). Gate: those + `uperf-pc diff-battery`, freeze rows,
self-test.

### Lane K — THE GPU RUNG, step 1 (wt-uperf2-k)

OWNS: NEW `zkmatrix-rs/src/ring/gpu/` (mod.rs + kernels as CUDA C
strings compiled via NVRTC at first use), the `gpu-cuda` feature +
optional `cudarc` dependency in `zkmatrix-rs/Cargo.toml`, the
`pub mod gpu` line in `ring/mod.rs`, a `// [UPERF2-K]` bin section +
`uperf-k`, ONE dispatch hook per ported kernel inside eval_proof.rs
(`ntt_gemm_modq_small`: `if gpu::enabled() { return gpu::ntt_gemm(...) }`
at the top of the function — nothing else in that file) and later the
same one-hook pattern in gkr_masked.rs for the descent round kernel,
NEW `docs/zkmatrix-poc/U_PERF2_GPU_REPORT.md` (this is the
CONTINUATION Phase-3 GPU rung report — write it as such: hardware
named, watts stated, [MEASURED] vs [ASSUMED] flags), "Agent K status".
GOAL, in order: (1) the plumbing — feature-gated cudarc, device init,
NVRTC compile of the Goldilocks primitives, a `uperf-k probe` that
reproduces the orchestrator's mulmod result; the default build (no
feature) unchanged and green. (2) Port `ntt_gemm_modq_small` (the
level-h and matvec kernel; U_PERF_WAVE_REPORT.md Section 3 describes it
exactly: D = 128 batched (na x len) x (len x nb) integer GEMMs in the
Goldilocks NTT domain with the split-halves accumulator and
exact-integer windows): forward NTTs of the a and b rings on the GPU
(length-128 negacyclic, psi-twisted, the same twiddle tables), the
GEMM per coefficient position, the window flush (reduce128, inverse
NTT, center, mod q) — output BIT-IDENTICAL to the CPU kernel (it is
exact integer arithmetic; the same window boundaries; assert with the
O2/O3 battery legs run under ZK_GPU=1 and a `uperf-k battery` cell-by-
cell vs CPU on random shapes at both moduli). Stream the operands in
blocks that fit 8 GB VRAM. (3) Measure: `uperf-pc kernel-bench 64 8192
noref` with ZK_GPU=1 vs the 8T CPU, then the REAL 3x16 and 12x128
rigs with `ZK_GPU=1` (digests identical), then ONE 12x512 8T+GPU run
(flock, `free -g`, nothing else heavy). (4) If time remains: the
descent round kernel (`k9_fused_round_par` — the fused five-table
round; K-field u32 lanes; the biggest term) with the same discipline.
Report honestly: the 4070 Laptop is a 50 W mobile part; state the
measured GPU factor over the 8T CPU on THIS box and do NOT extrapolate
to the contract's <= 450 W desktop board beyond a clearly-labeled
[MODEL] line. Gate: default build unchanged (all existing batteries
green without the feature), the feature build's batteries under
ZK_GPU=1, rig digests identical, freeze rows, self-test.

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

## Agent J status (wt-uperf2-j)

- (lane launches here)

## Agent K status (wt-uperf2-k)

- 2026-08-17 PLAN COMMIT (lane K, branch uperf2-k at bd5e0dd; report:
  docs/zkmatrix-poc/U_PERF2_GPU_REPORT.md — written as the CONTINUATION
  Phase-3 GPU rung report). Files: `zkmatrix-rs/Cargo.toml` (feature
  `gpu-cuda`, optional cudarc), NEW `zkmatrix-rs/src/ring/gpu/{mod.rs,
  cuda.rs, kernels.cu}`, `pub mod gpu` in ring/mod.rs, ONE hook at the top
  of `eval_proof::ntt_gemm_modq_small_gen`, a `// [UPERF2-K]` bin section
  with `uperf-k {probe, battery, bench}`, the report, this section.
  Baseline: the untouched bd5e0dd default build kept as
  scratchpad/ring_matmul_base_bd5e0dd. Box facts re-measured: RTX 4070
  Laptop, 8,188 MiB, sm_89, 36 SMs, driver 566.14 / CUDA 12.7; power
  limits default 55 W / current 68.82 W / max 105 W (nvidia-smi).
  PLAN, in order: (1) plumbing — device + NVRTC compile-once singleton,
  `enabled()` = feature AND `ZK_GPU=1` AND device, `uperf-k probe`
  reproducing the mulmod result; the default build unchanged (stub
  `enabled() -> false`). (2) the port of `ntt_gemm_modq_small`: forward
  length-128 NTTs of the a rings (u32-packed mod-q when q < 2^32, lifted
  on the device: balanced mod q -> Z_p) and b rings (i8 when s_max <= 127,
  else i64; lifted on the device) in shared memory with the transposed
  [t][ub][idx] store; the D = 128 batched (na x n) x (n x nb) GEMMs as
  64 x 64 output tiles x split-K with per-cell split-halves accumulation
  as TWO 128-bit integers (u64 lane + carry count each — the same
  integers `dot_split_halves` sums); the flush = the same
  `gl_reduce128(acc_lo + EPS*acc_hi)` on the same u128, inverse NTT,
  center, mod q, add; window boundaries = the CPU's
  `ntt_window_terms(q, s_max)`; u-blocks sized to a device budget
  (default 512 MB) so 8 GB VRAM streams any len; results copied back
  once. Battery `uperf-k battery` (transforms on planted extremes +
  random; the GEMM cell-by-cell GPU vs CPU at q31/q46, s_max
  1/2/64/2^20/2^40, shapes crossing tiles/u-blocks/windows, zero rings,
  the i8 store, the over-capacity decline) + `uperf-pc diff-battery`
  under ZK_GPU=1. (3) measure kernel-bench 64x8192 CPU 8T vs GPU, the
  REAL 3x16 / 12x128 rigs (digests identical), ONE 12x512 8T+GPU run
  under the flock. (4) if time: the descent round kernel, same one-hook
  discipline.

## Agent H status (wt-uperf2-h)

- 2026-08-17 PLAN COMMIT (lane H, branch uperf2-h at d38e9ce; report:
  docs/zkmatrix-poc/U_PERF2_DESCENT4_REPORT.md). Files: gkr.rs /
  gkr_masked.rs / kfield.rs / descent_fold.rs (extend), the bin's
  bk_pass_run DESCENT PHASE loop only, a `// [UPERF2-H]` bin section
  with `uperf-h {battery, bench}`, the report, this section. Baselines
  captured BEFORE any code change from the untouched d38e9ce build
  (scratchpad ring_matmul_base_d38e9ce): freeze-check 98 `ok` rows
  (h_freeze_baseline.txt = lane I's capture); `uperf-a descent-bench 20
  8 5 9` 8T: prove 1.67 s, trees 0.41 s, peak RSS 1,558 MiB, digest
  47a58a27.. [WSL 8T QUIET]. THE MODEL (report Section 0): the descent
  reads each layer once, top-down, so the pair's peak is at the bottom
  rounds — layer depth-1 + the last rounds' work tables + THE LEAVES;
  the brief's checkpoint model (leaves x (1 + 2^-c + ..)) forgets the
  transient recompute of layer depth-1 and the work tables: checkpointing
  alone lands ~3.6-3.9U (U = the pair's leaf table, 3.2 GB at 12x512) =
  ~12 GB — not enough. Plan, in order: (1) RELEASE consumed layers as the
  descent passes them (per-layer RwLock store; `FracTree::layer(k)` /
  `release_layer(k)`) + CHECKPOINTS (`ZK_K9_CHECKPOINT`, default 2 = every
  gap is one layer, recomputed by one threaded tree step from the
  checkpoint below; 0 = keep all) -> 3.625U; (2) COMPACT LEAVES for the
  aligned witness trees (the leaves are (0,1) / (1, alpha - v) with v on
  K-coords 0..1 / 4 blinders: 8 B per leaf instead of 128 B, expanded
  chunkwise into cache-resident scratch for the tree step and the fused
  extract rounds; `ZK_K9_COMPACT_LEAVES`) -> 1.75U = 5.6 GB at the 12x512
  pair [MODEL] -> the whole pass ~8-10 GB on this box; (3) `uperf-h
  battery` (2-coord shapes, knob variants == today's path, at 1/2/7T) +
  `uperf-h bench`; (4) rigs 3x16 / 12x64 / 12x128 + the 12x512 run if
  the calibrated model says < ~13 GB; (5) the same-size tree pool only if
  it lowers a rig peak; (6) report + this section.
- 2026-08-17 INTERIM (commit fd646f1 — items 1-3 landed; the 12x512 pass
  RAN on this box, twice, digests identical): (1)+(2) the packed tree's
  per-layer `RwLock` store + `FracTree::layer/release_layer`, the
  checkpointed build (`ZK_K9_CHECKPOINT` default 2, `k9_tree_climb_par`
  recompute), the COMPACT LEAVES of the aligned witness trees
  (`kfield::CompactLeaves`, `ZK_K9_COMPACT_LEAVES`), the release from
  `masked_rounds_bulk` (`ZK_K9_TREE_RELEASE`); (3) `uperf-h battery` 24
  legs x 8 ways (scalar oracle == pre-change layout == c2/c3/c4 x compact
  x release, fused + fusion off) identical + verified at ZK_THREADS 1/2/7
  (BATTERY DIGEST b1e78285..); `uperf-a` 18/18 (f936ff79..) + `uperf-g`
  22/22 (6d6a3f6b..) at 1/2/7T; a-bench 47a58a27.. identical at c 0/2/3/4
  (peak 1,558 -> 1,162 / 1,100 / 1,098 / 1,055 MiB); `uperf-h bench 20 8 5
  9` (2-coord values, digest 0bf9d7a3.. on every variant): peak **1,557 ->
  665 MiB** at 8T (release alone 1,162; + compact 733; + c=2 665; c=4 635),
  prove 1.75 -> 1.97 s (the c=2 recompute; c=0 1.74 s). REAL rigs [WSL 8T
  NOISY-SHARED, lane I active], digests identical to the ledger: 3x16 8T
  9.8 s @ 1,033 MB; 12x64 8T 43.8 s @ **2,948 MB** (was 4,034; the nrw-88
  pair transient 1.9 -> 0.8 GB); 12x128 8T 59.7 s @ **4,153 MB** (was
  6.4-7.4 GB; pair 4.9 -> 1.5 GB); **12x256 8T (FIRST on this box):
  accept, statement 889c0f12.., 1,439,719 B, EVAL 97a59ac3.., 95.9 s
  (8.4 / 80.8 / 5.7) @ 6,608 MB** (claim-layer transient 2.8 GB, pair 3.0
  GB); **12x512 8T (THE PoC SHAPE, FIRST on this box): accept, statement
  digest 2f8a92f853c1813b4d87e30dc9a43a9cb65b0e009c994fffa67e14a6132b81ab,
  1,509,911 B counted, EVAL-PROOF DIGEST
  4c259008c8e0cac2cf654471d37f937c4d1fd3dea51730520aa4256782ddf9dd, wall
  166.4 s (commit 13.4 / prove 142.6 / verify 8.7) @ maxrss 10,945 MB
  (default knobs; the peak is now lane D's CLAIM LAYER, 5.65 GB transient
  on a 5.0 GB floor; the nrw-88 pair 5.6 GB = the model's 1.75U exactly);
  with `ZK_W0_REGEN=1`: same digests, 178.3 s @ 9,535 MB**. Phase rows at
  12x512 8T: bk.descent-gkr 61.4 (a.round-g 52.3, a.tree-step 15.9 incl.
  the recompute), bk.descent-trees 10.8, bg.level-h 25.6, bg.claim-layer
  25.4 (d.cl-folds 11.3, d.cl-rounds 7.3, d.cl-tables 6.9), d.precommit-u0
  11.6, bg.matvec-chunks 9.4, ep.psi0-factored 12.8, bg.fold 5.0. Freeze
  98 rows identical; uperf-pc diff-battery E2E 1T green. Left in this
  session: 3x16 1T, self-test, the tree-pool decision, report.
- 2026-08-17 CLOSE (lane H; commits 50d87ca plan, fd646f1 items 1-3,
  9466dfb interim ledger, 08b0262 leaves-never-released + report, + this
  commit; report: docs/zkmatrix-poc/U_PERF2_DESCENT4_REPORT.md). Every
  number [WSL NOISY-SHARED — lane I active throughout, load 1-7] except
  the QUIET baseline benches; the RSS rows are load-independent.
  - LANDED (bit-identical on every path, asserted 8 ways): (1) the packed
    tree's per-layer `RwLock` store — the fast masked descent obtains
    layer j+1 once and RELEASES it as soon as its state-1 tables exist
    (`FracTree::layer` / `release_layer`; `ZK_K9_TREE_RELEASE`); (2) the
    CHECKPOINTED build (`ZK_K9_CHECKPOINT`, default 2: leaves + every 2nd
    layer + the small top layers stored, gaps recomputed by the chunked,
    positional `k9_tree_climb_par` — one threaded tree step per gap; 0 =
    every layer, the pre-change layout; always 0 under `oracle_mode()`);
    (3) COMPACT LEAVES for the aligned witness trees (`kfield::CompactLeaves`:
    2 x u32 per leaf — q's K-coordinates 0..1 + the member flag, alpha's
    tail, blinders as exceptions; the rig's fuse_pair / embed values —
    expanded chunkwise into cache-resident scratch as the exact packed
    blocks for the tree step, the fused extract rounds (per-job
    sub-chunks) and the eager extract; `ZK_K9_COMPACT_LEAVES`; general
    values fall back to the packed leaves); (4) `uperf-h {battery,
    bench}`. NOT built, decided negative with a measurement: the
    same-size tree pool (lane G's arena on the new bench: +70 / +600 MiB
    peak at 256 MB / 1 GB pools, prove within noise; a pool cannot lower a
    peak and the descent is no longer the pass's peak).
  - THE MODEL that decided it (report Section 1): the pair's peak is at
    the bottom rounds — layer depth-1 + the last rounds' work tables + the
    leaves — so checkpointing alone lands ~3.6-3.9U (U = one packed leaf
    table of the pair's real trees; 3.2 GB at 12x512), release 3.625U, and
    the compact leaves are what take it to **1.75U** (measured exactly:
    the nrw-88 pair 1.5 GB at 12x128 (model 1.4), 3.0 at 12x256 (2.8),
    5.6 at 12x512 (5.6)).
  - RESULTS: `uperf-h bench 20 8 5 9` 8T peak **1,557 -> 665 MiB** (release
    alone 1,162; + compact 733; + c=2 665; c=4 635), prove 1.75 -> 1.97 s
    (the recompute; c=0 1.74); a-bench 47a58a27.. identical, peak 1,558 ->
    1,100 (c=2). REAL rigs (digests identical to the ledger on every run):
    3x16 8T 9.8 s @ 1.03 GB (1T same-state A/B base 34.9 vs HEAD 34.5 s —
    neutral); 12x64 8T 43.8 s @ **2.95 GB** (was 4.03; pair transient 1.9
    -> 0.8 GB; bk.descent-gkr 7.87 -> 8.89 = the recompute, bk.descent-
    trees 2.57 -> 1.73 = the compact fill); 12x128 8T 59.7 s @ **4.15 GB**
    (was 6.4-7.4; pair 4.9 -> 1.5 GB); **12x256 8T FIRST on this box:
    accept, statement 889c0f12.., 1,439,719 B, EVAL 97a59ac3.., 95.9 s
    (8.4 / 80.8 / 5.7) @ 6.6 GB**; **12x512 8T — THE PoC SHAPE ON THE
    REFERENCE BOX, FIRST TIME: accept, statement digest
    2f8a92f853c1813b4d87e30dc9a43a9cb65b0e009c994fffa67e14a6132b81ab,
    1,509,911 B counted, EVAL-PROOF DIGEST
    4c259008c8e0cac2cf654471d37f937c4d1fd3dea51730520aa4256782ddf9dd, wall
    166.4 s (commit 13.4 / prove 142.6 / verify 8.7) @ maxrss 10,945 MB
    default knobs; with `ZK_W0_REGEN=1` 178.3 s @ 9,535 MB, same digests**
    — the pass's peak is now lane D's CLAIM LAYER (5.65 GB transient on a
    5.0 GB floor; bk.claim-layer-end hwm 10,689 MiB), the nrw-88 pair (5.6
    GB) fits under it. 12x512 phase rows (8T): bk.descent-gkr 61.4
    (a.round-g 52.3, a.tree-step 15.9 incl. the recompute ~6-7 [MODEL]),
    bk.descent-trees 10.8, bg.prove-group 44.7 (bg.level-h 25.6, bg.matvec-
    chunks 9.4, bg.fold 5.0), bg.claim-layer 25.4 (d.cl-folds 11.3,
    d.cl-rounds 7.3, d.cl-tables 6.9), bg.commit-phase 13.4 (d.precommit-u0
    11.6), ep.psi0-factored 12.8, verify 8.7 (bg.verify-group 8.5).
  - Gates at HEAD: `uperf-h battery` 24 legs x 8 ways (scalar oracle ==
    pre-change layout == c2 == c3 == c4 == c0+compact+release == c2 alone
    == c2 fusion-OFF) identical + verified, BATTERY DIGEST b1e78285.. at
    ZK_THREADS 1/2/7; `uperf-a descent-battery` 18/18 f936ff79.. and
    `uperf-g descent-battery` 22/22 6d6a3f6b.. at 1/2/7T; a-bench
    47a58a27.. at c 0/2/3/4; `uperf-pc diff-battery` E2E 1T + 7T;
    freeze-check 98 rows identical to the pre-change capture; `self-test`
    passed 259.0 s (328 ok rows); `table-descent battery small` 5/5,
    `pass-agg battery` 14/14 (real data); REAL 3x16 1T + 8T, 12x64 8T,
    12x128 8T digests identical; 12x256 and 12x512 twice each, identical.
  - Merge notes: files touched = gkr.rs / gkr_masked.rs / kfield.rs (lane
    files), the `uperf-h` arm in `main` + the appended `// [UPERF2-H]`
    section (bk_pass_run's loop needed NO change — the release happens
    inside masked_gkr_prove); no transcript / mask / wire / RNG change;
    `FracTree::p_layer/q_layer` are gone (replaced by `layer(k) ->
    LayerSrc`; `extract_children_par` takes the caller's handles); the
    Mac / a time-first box can set `ZK_K9_CHECKPOINT=0` (+0.37U of pair
    peak, no recompute).
  - Left (report Section 7): the pass's peak is now the CLAIM LAYER (lane
    D's packed tables, 5.65 GB transient at 12x512 -> 10.7 GB); then the
    floor (lays i64 1.5 GB, w0 i8 1.4 GB, CRS memo 1.9 GB — lane F's list);
    the recompute could be halved (checkpoints at depth-1, depth-3, ..)
    for +0.18U — not needed while the pair is not the peak; the Mac (T1)
    remains unmeasured; the 3x16 1T wall is NOISY here (34-35 s under
    load 3.5-6 vs the 28.6 s quiet merge row; the same-state A/B is
    neutral).

## Agent I status (wt-uperf2-i)

- 2026-08-17 PLAN COMMIT (lane I, branch uperf2-i from d38e9ce; report:
  docs/zkmatrix-poc/U_PERF2_SIMD_REPORT.md). Box facts checked: AVX2 +
  BMI2 + ADX, NO AVX-512/IFMA (`/proc/cpuinfo`) — the SIMD path is 4 x
  u64 AVX2 (u64 x u64 via four `_mm256_mul_epu32` partial products,
  Goldilocks reduce with compare-based conditional subtracts, every op
  canonical so the values are identical by construction); NEON mirror
  behind `cfg(target_arch = "aarch64")` [UNTESTED-NEON]. Baseline
  captured BEFORE any code change from the d38e9ce build:
  freeze-check 98 `ok` rows == the orchestrator's merge-G capture
  (scratchpad/i_freeze_baseline.txt), binary saved as
  scratchpad/ring_matmul_base for the before/after benches. Files:
  aux_ntt_core.rs (additive: `ntt_fwd_avx2/inv`, `ntt_fwd_best/inv`
  dispatch with `ZK_NTT_SIMD=0` forcing scalar, SIMD-layout twiddle
  tables inside `NttTables`), the 7 `_fast` call lines in
  eval_proof.rs -> `_best`, a `// [UPERF2-I]` bin section with `uperf-i
  {battery, bench}`, the report, this section.
  Steps: (1) AVX2 fwd/inv + dispatch + battery; (2) call-line switch +
  batteries/freeze; (3) benches + REAL rigs 3x16 1T/8T + 12x64 8T;
  (4) NEON mirror; (5) report. Stop rule: < 1.3x on the transform ->
  record the finding and stop.

STATUS (2026-08-17, HEAD of uperf2-i; report:
docs/zkmatrix-poc/U_PERF2_SIMD_REPORT.md; every number [WSL-BOX
NOISY-SHARED] — lane H ran throughout):

- LANDED, values identical (uperf-i battery: 5,192 rings incl. 1,096
  planted extremes, fwd/inv/round trips/`_best`; freeze 98 rows
  identical; every battery green; rig digests exact):
  1. `gl_avx2` in aux_ntt_core.rs: the same DIT/GS length-128 transform
     on 4 x u64 AVX2 lanes, every op canonical (u64 x u64 from four
     `vpmuludq` partial products, `lo + EPS*hi_lo - hi_hi` with
     compare-based conditional subtracts) — 1.64x / 1.61x as a naive
     port; + an opaque `asm!("vpmuludq")` (LLVM re-lowered the intrinsic
     as a 64-bit multiply idiom for loop-invariant twiddles: 6-8 wasted
     ops per butterfly) -> 1.91x / 2.04x; + signed power-of-two twiddles
     for the five outer stages and 1/n (2 has order 192 in Z_p*, so
     every 64th-root-and-below twiddle is +-2^k: shifts + the same
     reduction, sign as a store/load offset swap; only the two innermost
     stages pay the general product) -> fwd 1.00-1.04 -> 0.41-0.46 us
     (2.2-2.5x), inv 1.20-1.26 -> 0.42-0.44 us (2.7-3.0x) [1T, best of 3
     x 3 repeats].
  2. `ntt_fwd_best` / `ntt_inv_best` dispatch (`is_x86_feature_detected!
     ("avx2")` AND `ZK_NTT_SIMD` != 0, else the scalar `_fast`) at the 7
     call lines of eval_proof.rs (nothing else there); `uperf-i battery
     | bench`.
  3. NEON mirror behind `cfg(target_arch = "aarch64")` [UNTESTED-NEON —
     no aarch64 std installed here; every intrinsic signature checked
     against the toolchain stdarch source; on the Mac run `uperf-i
     battery` FIRST; `ZK_NTT_SIMD=0` is the one-env-var fallback].
  4. Kernel benches, one binary (`ZK_NTT_SIMD=0` vs default), 1T: matvec
     1.44x, transport 1.51x, combine 1.61x, fold e=5 1.57x, psi 1.27x,
     level-h 1.15x (MAC-bound at r = 64), kernel passes ~1.0x (they
     hardly transform); at 8T 1.2-2.0x on the same rows.
  5. REAL 3x16 [1T], one binary, both orders: scalar (`ZK_NTT_SIMD=0`)
     32.9-34.5 s -> SIMD 25.6-27.1 s (~1.25x; prove 25.2-26.3 -> 19.4-
     20.9 s: level-h 9.96-10.31 -> 7.45-7.95, matvec 3.51-3.87 ->
     2.15-2.38, transport 2.86-3.74 -> 1.79-1.82, fold 1.69-1.96 ->
     0.87-0.94 s); [8T] 9.8 -> 9.2 s (prove 7.1 -> 6.6); REAL 12x64 [8T]
     43.1 -> 41.0 s @ 4.06 GB (~1.05x: at 8T the composed pass is
     dominated by the phases that do not transform); statement 93a98700…
     / EVAL 0ae9cdae… and 80763ea5… / 63f4a3a4… identical on every row,
     accept true.
  6. Gates at HEAD (final binary, after the last code commit 54ebead):
     uperf-i battery 1T/7T, uperf-pc diff-battery 1T/2T/7T (E2E),
     uperf-c 1T/7T, uperf-f 1T/2T, freeze-check 98 rows == the
     pre-change capture (twice: after the call-line switch and at
     HEAD), self-test 290 s / 254.8 s (the same 61 intentional
     fail/panic lines as the merge-G baseline), rig digests above.
     Commits: a245db5 skeleton, 768ee63 AVX2 body + battery + bench,
     8b0f7e3 asm vpmuludq + pow2 twiddles, 07d91cb const stages,
     36321d2 call-line switch, 54ebead NEON pow2 mirror, then report/
     ledger commits.
- FINDING for the orchestrator: cargo does not read
  `zkmatrix-rs/.cargo/config.toml` (`target-cpu=native`) when invoked
  from the repo root with `--manifest-path` — every lane's build is a
  baseline x86-64 build; runtime detection is what gates SIMD here.
- Not done: the sign-flipped-representation trick (~8%), the mid-class
  2^k multiply shortcut (~3%), any AVX-512 path (no IFMA on this box).

## Agent F status (wt-uperf2-f)

- 2026-08-17 PLAN COMMIT (lane F, branch uperf2-f at f512ba1; report:
  docs/zkmatrix-poc/U_PERF2_MEMORY_REPORT.md). Files: eval_proof.rs
  (whole file), the bin's bg_*/bk_* composed-pass plumbing
  (bg_witness / bk_witness_*, bg_precommit, bg_prove_group,
  bg_verify_group, bg_matvec_chunks, bg_level_h, bg_fold, bk_pass_run's
  witness plumbing), a `// [UPERF2-F]` bin section with `uperf-f
  {diff-battery, rss}` (registered in `main` next to uperf-e), the
  report, this section. Baseline binary at f512ba1 preserved
  (scratchpad/ring_matmul_base_f512ba1) for the freeze/rig baselines.
  Plan, in order:
  0. MEASURE: `[UPERF2-F] RSS <tag> hwm/rss` rows (VmHWM + VmRSS from
     /proc/self/status, printed only when the prof timers are on) at the
     pass's phase boundaries — bk_pass_run: layers loaded, aux built,
     witness built, precommit, commit end, claim-layer end, each descent
     pair, before/after each group eval proof, verify per group;
     bg_prove_group: rows pass, phi pass, level-0 h, level-0 fold (w0
     freed), each deeper level. Baseline attribution at 3x16 (1T) and
     12x64 (8T, flock, >= 13 GB free) BEFORE any structural change.
  1. w0 COMPACT: `ring::eval_proof::DigitCols` (flat `Vec<i8>`, n x D
     digits; every level-0 alphabet is |w| <= 64 — asserted at the
     writer) + the `SmallRings` trait over `[Vec<i64>]` AND `[i8]` (per
     ring `ring(u, buf) -> &[i64]`, `max_abs`, `is_zero`, `sub`) so the
     kernels lift per ring from either store with identical arithmetic:
     `ntt_gemm_modq_small` / `matvec_modq_small_multi` / `level_h_pairs`
     / `fold_chunks_ntt` / `kernel_pass_factored` (rows pass) get `_gen`
     bodies (the old names stay as `[Vec<i64>]` wrappers for the
     batteries + the synthetic agg_* rig). `agg_digit_witness_cols`
     (threaded, same `digits_into`) feeds bg_witness / bk_witness_*;
     bg_precommit / bg_prove_group take `&mut DigitCols`; deeper levels'
     witnesses (`w_cur`, that/hhat, floor) stay `Vec<Vec<i64>>`.
  2. PHI NEVER MATERIALIZED at level 0: `Phi0Source` (per tensor:
     aligned -> `PhiFactored` value rings x radix per limb; small-cols ->
     the hoisted-kw phi rings materialized per tensor (they are tiny);
     no kernel -> zero) with `fill(v0, n, out)`, consumed per u-block by
     `level_h_pairs_with` (block GEMMs accumulated mod q — bit-identical
     to the single-window kernel because every flush is an exact
     integer partial reduced mod q); the level-1 transport from
     `psi_level0_factored_multi` via `transport_level_from_psi` (what
     bg_verify_group does). `phi_cur` for level 0 never allocated on the
     fast path; `oracle_mode()` keeps the materialized path (phi pass ->
     bg_level_h -> transport_level).
  3. Dead data: `expand_level_matrix_arc` (the memo hands out `Arc`
     handles; the bg_*/bk_* callers hold Arcs — no clones), a
     `ZK_CRS_MEMO=0` knob (no memo insert; each expansion freed with its
     last handle), and — if the attribution says it matters — the act
     group's w0 regenerated after the descents instead of held.
  4. `uperf-f diff-battery`: DigitCols kernels == boxed kernels
     (gemm / matvec-multi / level-h / fold / kernel-pass rows) at both
     moduli; Phi0Source::materialize == the phi pass; fill windows ==
     slices; level_h_pairs_with == level_h_pairs at ragged blocks;
     the E2E three-way (boxed-fast == cols-fast == cols-oracle, all
     verify); ZK_THREADS 1/2/7. Gates at HEAD: uperf-pc diff-battery
     (E2E), agg-matmul, bh-verifier, uperf-a/c/d/e batteries,
     freeze-check 98 rows == baseline, self-test, pass-agg battery
     (real data, once at close, flock), table-descent battery small,
     the REAL 3x16 rig at 1T/8T and the REAL 12x64 rig at 8T (digests
     identical, `/usr/bin/time` maxrss rows).
  5. Report: RSS attribution before/after per phase (3x16, 12x64, and
     12x128 / 12x256 if they fit under ~13 GB), timing rows, what is
     left for 12x512 on 15 GB.
- 2026-08-17 CLOSE (lane F; commits 5bbcf9f skeleton + RSS rows,
  7067dca w0 compact, ddadc48 phi never materialized + CRS Arcs, 369e423
  dead-data levers, + the report/ledger commit; report:
  docs/zkmatrix-poc/U_PERF2_MEMORY_REPORT.md). ALL ITEMS LANDED, every
  digest identical on every run [all walls WSL NOISY-SHARED — lane G ran
  throughout; RSS rows are load-independent]:
  - THE ATTRIBUTION (item 0, `[UPERF2-F] RSS` rows): the 12x64 8T rig
    peaked at 11.9 GB inside the weight group's level 1 = layers 0.6 GB
    + BOXED w0 of both groups 4.6 GB (weight 3.54M digit rings x ~1,064
    B) + the CRS memo AND its clones 1.8 GB + the descents' leftovers ~1
    GB + the weight group's MATERIALIZED Phi_0 3.5 GB — and `w0.clear()`
    did not lower the resident set (glibc keeps the freed 1 KiB chunks).
  - (1) `eval_proof::DigitCols` (flat i8, one allocation, 128 B/ring)
    behind the `SmallRings` trait over `[Vec<i64>]` AND `[i8]`; the
    kernels (`ntt_gemm_modq_small`, `matvec_modq_small_multi[_ref]`,
    `level_h_pairs[_ref]`, `fold_chunks_ntt[_ref]`, `kernel_pass_factored`)
    got `*_gen` bodies with the old names as boxed wrappers (no
    battery / oracle / agg-rig path changed); `agg_digit_witness_cols`
    feeds bg_witness / bk_witness_*; bg_precommit / bg_prove_group take
    `&mut DigitCols`. (2) `Phi0Source` (the O5 factored form per tensor)
    + `level_h_pairs_with` (per-u-block GEMM, exact block partials
    summed mod q — bit-identical to the single-window kernel) + the
    level-1 transport from `psi_level0_factored_multi` (bg_verify_group's
    form) — `phi_cur` for level 0 never allocated; `oracle_mode()` keeps
    the materialized path. (3) `expand_level_matrix_arc` (Arc handles,
    no clones; `ZK_CRS_MEMO=0`). (4) `malloc_trim(0)` at the phase
    boundaries (Linux-only; `ZK_MALLOC_TRIM=0`), `ZK_W0_REGEN=1` (free
    the i8 witnesses through the claim layer + descents, rebuild before
    the groups; opt-in, +0.35 s at 12x64 8T).
  - RESULTS (digests identical on every run): 3x16 peak **2.86 -> 0.94
    GB** at 1T (8T 1.03 GB), wall neutral by same-state A/B (base 28.5 /
    28.7 s vs 28.7 / 30.2 s); 12x64 8T peak **12.2 -> 4.55 GB** (default)
    / **3.99 GB** (`ZK_W0_REGEN=1`), wall 45.5 -> 42.4 s (the flat digit
    witness: commit 7.6 -> 5.4 s); **12x128 8T (first time on this box):
    7.44 GB peak, accept, 66.2 s** (statement 4a3af8c3.., 1,372,775 B,
    EVAL-PROOF 742d88e1.. — the reference for the shape). The 12x64 peak
    is now the nrw-88 descent pair's own transient (2.2-2.5 GB at depth
    19, 4.9 GB at depth 20 measured; ~20-24 GB at the 12x512 depth 22)
    on a ~1.5-2 GB floor — 12x256 (~14 GB [MODEL]) not attempted; for
    12x512 on 15 GB the pair's footprint must come down ~2x (lane G's
    file); everything else of the pass fits under ~7-9 GB [MODEL].
  - Gates at HEAD (final binary): `uperf-f diff-battery` 40/40 at 1/2/7T
    (digest 77583bed..); `uperf-pc diff-battery` E2E 1T + 7T; `uperf-a
    descent-battery` 18/18 1T + 7T (f936ff79..); `uperf-c` 1T + 7T;
    `uperf-d` 30/30 1T + 7T (46471467.. unchanged); `uperf-e` (59117121..
    unchanged); bh-verifier; agg-matmul; self-test (rows identical to
    the merge-DE capture); freeze-check 98 rows identical to the
    pre-change capture; `pass-agg battery` 14/14, `table-descent battery
    small` 5/5, `t-blind battery` 11/11 (real data); the REAL 3x16 rig at
    1T and 8T (93a98700.., 985,142 B, 0ae9cdae..) after every step, ONCE
    under `ZK_UPERF_ORACLE=1` at 1T (597.3 s, same digests, accept), and
    the REAL 12x64 rig at 8T (80763ea5.., 63f4a3a4..) on five knob
    variants.
  - Merge notes for the orchestrator: (a) the ONE edit outside the
    lane's files is a one-line witness-store change in
    `uperf_pc_diff_e2e` (`DigitCols::from_vecs(&w0)` — the E2E leg now
    runs bg_prove_group on the flat store); (b) `bg_fold` keeps its
    boxed signature (uperf-c's leg calls it) with `bg_fold_gen` as the
    body; (c) `malloc_trim` is a `cfg(target_os = "linux")` extern (a
    no-op on the Mac).
  - Left (report Section 6): the descent pair's footprint (lane G — the
    ONLY 12x512 blocker), flat CRS matrices (boxed rings never leave the
    arena without the trim; ~1.9 GB memo at 12x512), `BfLayer` as i64
    (1.5 GB at 12x512), a per-group PHI_vr cache as a knob (time-vs-1 GB),
    `ZK_W0_REGEN` as the default after T1.

## Agent G status (wt-uperf2-g)

- 2026-08-17 PLAN COMMIT (lane G, branch uperf2-g at f512ba1). Files:
  gkr_masked.rs / gkr.rs / kfield.rs / descent_fold.rs (extend), a
  `// [UPERF2-G]` bin section with `uperf-g {descent-battery, bench}`,
  docs/zkmatrix-poc/U_PERF2_DESCENT3_REPORT.md. Baselines captured
  BEFORE any code change from the untouched build (scratchpad
  g_freeze_baseline.txt: 98 `ok` rows identical to lane F's capture;
  `uperf-a descent-bench 20 8 5 9`: 1T prove 8.12 s (round-g 3.66, fold
  2.54, extract 1.22, eq 0.67), trees 1.63 s; 8T prove 2.24 s (round-g
  0.93, fold 0.89, extract 0.21, eq 0.19), trees 0.39 s, DESCENT DIGEST
  47a58a27..; descent-battery 18/18, BATTERY DIGEST f936ff79..). Plan,
  in order:
  1. Fold-into-next-round fusion in the packed descent kernel: round
     t+1's kernel folds the five state-t tables on the fly (state t+1
     written IN PLACE with a rung-ordered schedule — output pair-block
     range [A, 2A) reads [4A, 8A) and writes [2A, 4A), so rungs run
     smallest-first, each fully parallel; a 64-pair-block prefix goes
     through a tiny scratch) — 1.5 x table bytes per round instead of
     2.5 x, no S/2 fold scratch. Extract fusion: rounds 0 and 1 read the
     tree layer j+1 directly (deinterleave + PL = p0 + lambda q0 on the
     fly), the first materialized work tables are state 1 (memory 5.5 S
     -> 3 S per layer). Same canonical arithmetic per element, exact
     integer node planes -> transcript-identical; `masked_rounds_bulk_ref`
     stays the oracle; `ZK_UPERF_G_NOFUSE=1` (and an in-process flag)
     runs the same loop with eager folds (lane A's HEAD path) for A/B.
  2. Table arena: KTab buffers of the work tables / tree layers recycled
     through a per-thread-safe free list (no fresh calloc + page faults
     + memset per tree/layer), measured on the bench + rigs.
  3. Thread scaling of round-g/fold/tree-step: chunk sizes, job
     granularity, false sharing of the per-chunk planes.
  4. `uperf-g descent-battery` (scalar == ref == fast-nofuse == fast-fused,
     verified, at 1/2/7T) + report + gates (uperf-a descent-battery,
     descent-bench digest, uperf-pc diff-battery, freeze rows, self-test,
     the REAL 3x16 rig 1T/8T + 12x64 8T).
- 2026-08-17 CLOSE (lane G; commits cb2b97f plan, 501d76e fold + extract
  fusion, 977f19e arena (opt-in), 9bc7cc0 thread items, 756ae7f eq
  fusion, + the report/ledger commit; report:
  docs/zkmatrix-poc/U_PERF2_DESCENT3_REPORT.md). Every number
  [WSL NOISY-SHARED] — lane F built and ran its rigs throughout (load
  0.7-3.8); the fusion OFF/ON pairs are same-process (`uperf-g bench`).
  - ITEM 1 LANDED (transcript-identical, `masked_rounds_bulk_ref` the
    oracle under `oracle_mode()`; `ZK_UPERF_G_NOFUSE=1` = lane A's HEAD
    loop, `ZK_UPERF_G_NOXFUSE=1` = fold fusion only): the packed descent
    kernel folds round t's five tables INSIDE round t+1's pass, in place
    (kfield.rs `fused_round_body` FUSE_FOLD / FUSE_EXTRACT /
    FUSE_EXTRACT_FOLD sharing `round_g5_body`'s node loop, now
    `round_g5_pair`; driver `k9_fused_round_par` with the RUNG schedule —
    pair-block range [A, 2A) reads [4A, 8A) and writes [2A, 4A), so a
    64-pair-block prefix goes through a tiny scratch and the rungs run
    smallest-first, each fully parallel over per-job exact-integer planes
    in 128 B-padded slots); rounds 0 and 1 read the tree layer j+1 and the
    b-part eq table directly (extract deinterleave, PL = p0 + lambda q0
    and eq = eq_b(b) x E(e) on the fly), so a layer's first materialized
    tables are state 1; gkr_masked.rs `masked_rounds_bulk` is a
    pending-fold / flush loop (`flush_state` = lane A's eager eq build /
    extract / folds / add-constants, verbatim, for the tail, the w-round
    and the pad materialization). Traffic ~37 S -> ~18 S per layer,
    work-table footprint 5.5 S -> 2.5 S. Depth 20 x 8 bench
    (`uperf-g bench 20 8 5 9`, digest 47a58a27 on every line):
    `masked_gkr_prove` 8T **2.15-2.33 -> 1.66-1.78 s (ratio 0.72-0.80)**,
    1T ratio 0.85-0.92 (one run 1.06 under load), peak RSS **2,087 ->
    1,557 MiB**; REAL 3x16 rig 8T bk.descent-gkr 1.19 -> 0.88 s (wall
    9.5 -> 9.3), 1T 2.36 -> 2.26 (29.0 -> 28.7); REAL 12x64 rig 8T
    bk.descent-gkr **10.3 -> 7.36 s (-29%)**, wall 46.0 -> 42.3-44.1 s,
    maxrss 12.19 GB (the process peak is not in the descent phase).
  - ITEM 2 BUILT, MEASURED NEGATIVE, OPT-IN: the packed-table arena
    (`impl Drop for KTab` -> `k9_arena_give`, `KTab::zeroed` /
    `KTab::recycled` via `k9_arena_take`, LIFO pool capped by
    `ZK_K9_ARENA_MB`, default 0 = off; `k9_arena_clear/stats` public). On
    the depth-20 bench a 1 GB pool cut minor faults only 14-20% and cost
    +0.5-0.7 GB peak / +10% prove (size classes double per layer, glibc
    realloc copies heap chunks, the held set is RSS); a THP MADV_HUGEPAGE
    probe cut faults 9x (1.32M -> 142K) with no wall change and was
    removed. After lane E's calloc trick the faults are ~5% of the descent
    CPU here (probe: 512 MB first touch 135 ms 1T / 30-46 ms 8T). What
    would pay: a same-size tree-buffer pool across pairs + a release call
    from the pass driver after the descent phase (bk_pass_run, lane F's
    file) — recorded, not built.
  - ITEM 3: the fused kernel scales further than lane A's — prove 1T
    7.07 / 2T 4.29 / 4T 2.51 / 6T 1.89 / 8T 1.68 / 12T 1.58 / 16T 1.47 s
    (round-g 6.37 -> 1.28 = 5.0x at 16T; lane A saturated at 3.2x); the
    residual vs the ideal (~4.5x at 6T / ~5.4x at 8T / ~7x at 16T on this
    turbo-1T / all-core / E-core topology) is the box, not the split;
    plane-slot padding (hygiene) and `ZK_K9_JOBS_PER_THREAD` (2/4/8/16
    within 4-9%; default 8) landed; affinity not attempted (FFI).
  - Gates at HEAD: `uperf-g descent-battery` 22/22 four-way (scalar ==
    ref == fast-nofuse == fast-fused, verified) BATTERY DIGEST 6d6a3f6b..
    at ZK_THREADS 1/2/7 (+ arena on); `uperf-a descent-battery` 18/18
    f936ff79.. at 1/2/7; descent-bench digest 47a58a27 at 1T/8T;
    `uperf-pc diff-battery` E2E at 1T/7T; freeze-check 98 `ok` rows
    identical to the pre-change capture; REAL 3x16 at 1T and 8T (accept,
    93a98700.., 985,142 B, 0ae9cdae..) and 12x64 at 8T (accept,
    80763ea5.., 63f4a3a4..); `self-test` passed (234.0 s); the 3x16 `ZK_UPERF_ORACLE=1` 1T
    run at close: accept, same digests, wall 602.2 s (44.7 / 417.9 / 139.3).
  - Projection [MODEL]: the rig's witness-descent prove ~249 -> ~215-230 s
    at 1T, ~71 -> ~52-57 s at 8T on this box (~46 s at 16T); the peak
    pair's work tables ~8.3 -> ~3.8 GB touched (descent-phase peak ~21 ->
    ~16 GB with the trees). Left: the Mac's scaling (T1), the same-size
    tree pool + release hook, the b-part eq doubling (0.06 s at 8T), the
    GPU rung (the fused kernel is the natural first descent GPU kernel).

## Agent D status (wt-uperf2-d)

- 2026-08-17 PLAN + FIRST LANDING (lane D, branch uperf2-d from d3a4602;
  report: docs/zkmatrix-poc/U_PERF2_CLAIMCOMMIT_REPORT.md). Baselines
  captured BEFORE any code change: freeze-check 98 `ok` rows
  (scratchpad/d_freeze_baseline.txt) and the 3x16 rig at 1T (accept
  true, statement 93a98700.., 985,142 B, EVAL-PROOF DIGEST 0ae9cdae..;
  commit 4.0 / prove 32.2 / verify 6.9 / wall 43.3 s [WSL 1T]).
  Method: the PERF RULE — every changed entry point keeps its body as
  `*_ref`, honors `oracle_mode()`, threads over independent exact work.
  Items: (1) `d.*` prof phases (ct_engine::prof ids 40-50: chain,
  digits, precommit, statement, aux, groups; cl-tables/rounds/folds/
  finals/pack). (2) The claim layer's ixf sumcheck on the K9 packed
  substrate: `fold.rs::IxfCombine {Prod3, Had, Rq}` names the three
  pass combine shapes; `ixf_sumcheck_prove_kind` packs the boxed tables
  once and runs every round on a NEW lane-blocked round kernel
  (`kfield.rs::ixf_round_body` — one MAC + one deferred reduction for
  the inner factor, modular differences, eq MAC into per-node lazy
  planes; all deg+1 nodes; per-chunk planes summed in index order =
  deterministic ZK_THREADS) with `kt_fold_par` in-place threaded folds,
  finishing the last rounds (< 2 pair-blocks) on the boxed scalar
  path; the scalar `ixf_sumcheck_prove` is the oracle (`_kind_ref`).
  (3) Commit phase: `bf_matmul_i64` (row-blocked GEMM, i32 accumulation
  when the int8 x int8 bound fits, threads over row blocks; oracle the
  inline i-k-j loop), `agg_digit_witness` threaded per value ring,
  `bg_mm_tables` (matmul-instance ta/tb) threaded per (layer, k) block.
  (4) `uperf-d diff-battery` 25/25 (three shapes x 3 sizes x dense/
  sparse: oracle == ref == fast == in-process flip, every proof
  verifies; bg_mm_tables / chain GEMM / digit witness ref == fast),
  BATTERY DIGEST 1d08e03f.. identical at ZK_THREADS 1/2/7 and under
  ZK_UPERF_ORACLE=1. Rig gate + report: next.
- 2026-08-17 CLOSE (lane D; commits 2da5dd4 packed prover, 7df526b
  packed builders + lazy tables, e2f349c digits/gemm-bench, 07b5817
  report + this section; report:
  docs/zkmatrix-poc/U_PERF2_CLAIMCOMMIT_REPORT.md). ALL FIVE
  DELIVERABLES LANDED:
  - THE REAL-DATA GATE holds on every run: `uperf-pc full-profile 3 16`
    accept = true, statement 93a98700.., 985,142 B, EVAL-PROOF DIGEST
    0ae9cdae.. at 1T and 8T fast AND the 610 s all-oracle run
    (`ZK_UPERF_ORACLE=1`; Section 5 of the report lists every run).
    Claim layer 3x16: **3.17 s -> 0.91 s at 1T (3.5x) -> 0.29 s at 8T
    (11x)**; final binary 1T commit 4.4 / prove 31.5 / verify 7.9 /
    wall 44.0 s, 8T 2.4 / 8.9 / 1.9 / **13.4 s** (ledger 8T row 16.6)
    [WSL NOISY-SHARED throughout — the d.* sub-timers reproduce to
    +-0.03 s across runs].
  - Items (each with a `*_ref` oracle + `oracle_mode()`): (1) the
    packed ixf sumcheck prover — `IxfCombine {Prod3, Had, Rq}`,
    `ixf_sumcheck_prove_kind/_tables/_packed`, kernel `ixf_round_body`
    + `k9_ixf_round_par` (deterministic chunk planes), `kt_fold_par`
    folds with scratch shrink; (2) `IxfTable` — the zero-check tables
    built DIRECTLY packed (eq / scalar_table per block / layer_expand;
    64 B per element, one allocation) via `bg_zc_prove` (boxed builders
    + scalar prover as its oracle); (3) `bg_mm_tables` / `bg_mle` with
    lazy exact u128 accumulation (`kacc_*`) + threads; (4)
    `bf_matmul_i64` row-blocked i32 GEMM (10.0x at 1T, 26 GMAC/s,
    byte-identical) + `agg_digit_witness` threaded and allocation-free
    (`digits_into`); (5) `d.*` prof phases 40-50; `uperf-d
    diff-battery | bench | gemm-bench`.
  - Gates at HEAD (final binary): `uperf-d diff-battery` 30/30 at 1/2/7
    + oracle env (BATTERY DIGEST 46471467.. identical); `uperf-pc
    diff-battery` (E2E) 1T + 7T; `uperf-a descent-battery` 18/18 1T +
    7T (digest f936ff79.. unchanged); `uperf-c diff-battery` 1T + 7T;
    `self-test`; `bh-verifier battery`; `agg-matmul battery`;
    `pass-agg battery` 14/14 (REAL 3x16 data, all tamper arms);
    `table-descent battery small` and `t-blind battery` (real data);
    freeze-check 98 `ok` rows identical to the pre-change capture (only
    the panic's source-line number differs — code was added above it).
  - Projection [MODEL]: the 12x512 claim layer ~320 s serial on the
    boxed path (the brief's "~100 s" undercounted the round loop) ->
    ~75 s at 1T / ~20 s at 8T here (~8-10 s at the Mac's expected
    scaling), peak memory ~14-19 GB of boxed tables -> ~5.5 GB packed;
    chain GEMMs ~11 s -> ~1 s; digit witness ~10 s -> ~4 s (1T).
  - Left (report Section 8): `expand_level_matrix`'s serial CRS XOF
    (2.6 s = 18% of the 8T rig wall; eval_proof.rs, one counter-mode
    stream — not splittable transcript-neutrally; cache across processes
    or accept); the eq-fold identity + per-slot shift broadcast (~10-15%
    of the packed sumcheck, 1 GB at 12x512); the g(1) identity (~17% of
    round work; left out to keep tamper-arm transcripts oracle-
    identical); T_blind's masked matmul prover (t_blind.rs, small
    tables). Box note: pool threads land on E-cores under WSL2 (the
    inline 1T GEMM on a boosted P-core equals the 8T pool run; the
    standalone probe of the same loop scales 4x) — a box property, the
    Mac's cores are the expectation (T1).

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
