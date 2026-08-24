# U-PERF3 tranche ledger — the 8B MVP on the lattice line (route 1)

Branch: main (orchestrator) with lane worktrees `/home/victor/wt-uperf3-<lane>`
(branches `uperf3-<lane>`), opened at c3fb448 (2026-08-18). Previous
ledgers: PROGRESS_UPERF.md (Phase 0), PROGRESS_UPERF2.md (rounds 1-9,
155.6 -> 21.0 s at 12x512 8T+GPU on the reference box; its "Decision
memo (orchestrator, 2026-08-18)" is the fork this tranche resolves).
Standing plan: docs/zkmatrix-poc/CONTINUATION.md; executable queue:
docs/zkmatrix-poc/TASK_BOARD.md; the route-1 design memo:
docs/zkmatrix-poc/U_PERF3_OPENING_LAYER_DESIGN.md.

**Authority — Victor, console 2026-08-18 (verbatim):** "Let's continue
with (1), and see if we can be more creative and find a solution
anyway. I think it's best to fully explore this option first and to
have a complete product with this option before moving to the second
option. We can separate the options and document them. One may be
preferable to the other in certain contexts. To me it's more important
that we have a complete example of an 8B parameter proof as an MVP even
if the proof currently takes 1-3 minutes."

**Reading of the ruling (orchestrator; Victor can redirect):**
1. The lattice line (Route R: MLWE/MSIS, exact-integer range facts,
   masked lookup, HVZK for the declared private set) stays THE line.
   The float/int-mix channel is NOT started; it is documented as an
   option (docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md) with the
   contexts in which it would be preferable.
2. **MVP-1 = the TARGET_CONTRACT FFN statement at the 8B shape**: 32
   layers x 512 tokens x d 4096 x f 14336 (Llama-3-8B / Mistral-7B FFN
   dims), REAL int8-calibrated weights from an open checkpoint, the
   int8 spec of TARGET_CONTRACT §2, proved and verified END TO END with
   the artifact bytes counted — on hardware we own (the Mac's 256 GB
   for the CPU path; the WSL box's 8 GB GPU only if the pass streams).
   Minutes are acceptable; the number is recorded honestly with its
   [BOX/threads/GPU] label. **MVP-2** = the full transformer layer
   (attention, RMSNorm, residual, embedding — ATTENTION_INTEGER_SPEC.md,
   CONTINUATION Phase 4 wiring) after MVP-1.
3. In parallel, the route-1 protocol work proceeds in the design memo's
   order (spike S1/S2 -> Stage A -> Stage B) because it shrinks BOTH
   the clock (~1.35x / ~1.8-2.5x [MODEL]) and the memory (the descent
   trees are the pass's peak) and the artifact (~3x) — all three
   matter for the 8B shape.
4. "Be more creative": a design/literature lane looks for the
   lattice-line route to the 5-15 s headline (the opening
   re-architecture the design memo left unpriced, folding across the
   32 identical layers, GPU-native structure) with COUNTS, so Victor
   can rule on a second design freeze later.

## Standing rules (every lane) — unchanged from PROGRESS_UPERF2.md

Differential floor (bit-identical bytes where semantics are unchanged;
oracles kept; freeze rows; the EVAL-PROOF digest), labels on every
number ([MEASURED]/[COUNTED]/[MODEL]/[ASSUMED]; [MAC-BOX|WSL-BOX NT
QUIET|NOISY-SHARED]), command hygiene (no cd/PATH=/sed -i; plain
`cargo`; `git --no-pager`; `git -C <worktree> add/commit` only; never
push/checkout/reset/rebase/rm), skeleton commit first, commit after
every green step, strict file ownership, memory discipline (15 GB box,
`flock -w 7200 /tmp/zk-heavy.lock` around anything heavy, one 12x512
rig at a time), the GPU build recipe (CUDA_ROOT=/home/victor/cuda-root,
LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib,
CARGO_TARGET_DIR=<worktree>/zkmatrix-rs/target-gpu, --features
gpu-cuda, run with ZK_GPU=1; the first process on a changed
kernels_k9.cu pays NVRTC ~8 min once). Read the rules block at the
top of PROGRESS_UPERF2.md if anything is unclear.

Transcript-changing work (Stage A/B) is a NEW protocol version, not an
edit of the frozen one: the frozen pass and its freeze rows stay
buildable and green under the default binary; the new pass lives
behind an explicit selector (statement version / rig subcommand) with
its own digests, batteries and audit trail — the migration battery of
the design memo §4.

## Round 1 (2026-08-18): lanes R (8B scaling + MVP plan), S (spike S1/S2), T (headline routes)

### Lane R — the 8B shape: what breaks, what it costs, how the MVP runs (wt-uperf3-r) — DESIGN, then the plan

OWNS: NEW `docs/zkmatrix-poc/U_PERF3_MVP8B_SCALING.md`, `scripts/`
additions ONLY as new files (`m8b_*.py`), the "Agent R status" section
below. Read-only everywhere else this round.
GOAL: a counted memo + executable plan for MVP-1. (1) The 8B FFN
statement's size per phase from the 12x512 measured attribution
(PROGRESS_UPERF2 "after round 9": commit 2.5 / prove-group 7.1 /
descents 6.5 / claim layer 1.75 / verify 1.7 / transport 1.4 / CRS 1.3
s; RSS 6.7 GB GPU path, 11.1 GB CPU path; VRAM ~6.8 GB store + 4 GB
chain; artifact 1,509,911 B) and the COUNTED scaling of each term with
(layers 12->32, tokens 512, d 768->4096, f 2048->14336): witness digit
rings, level-0 value rings, the claim layer's zero-check table sizes
(2^24 today), the descent pairs/depths, the planner's r/level schedule
(bk_pair_specs / bg schedules), the artifact bytes, the CRS. Say per
term whether it is ~x100 (weights/MACs), ~x19 (activations), or fixed.
(2) What BREAKS at that shape in the code as built (fixed-size
assumptions: u32 indices, 2^24 table words, alignment (4096 and 14336
are multiples of 128 — check every place `cols % 128` matters), the
15 GB / 8 GB budgets, planner caps, timeouts, `M125_*`-specific paths,
`Statement v2` fields, the freeze/digest conventions for a new shape).
(3) The memory architecture for the MVP: on the Mac (256 GB, CPU-only,
16-24 threads) does the pass FIT as built (project the RSS peak per
phase); on the WSL box (15 GB + 8 GB VRAM) what would have to stream
(per-layer proving with the composed aggregation the pass already
does? layer groups? the descent trees are gone under Stage A — say
what the peak becomes then). Give the honest time projection per box
[MODEL] and name the rungs: 32x16 (yardstick, like 3x16), 32x128,
32x512. (4) The data: the open checkpoint with the exact 8B FFN dims
(Mistral-7B-v0.1: d 4096, f 14336, 32 layers, SwiGLU, Apache-2.0;
Llama-3.1-8B same dims but gated — Victor's call), the int8
calibration + export generalized from scripts/m125_int8_calibration.py
/ scripts/m125_export_ffn.py (write `scripts/m8b_export_ffn.py` +
`m8b_int8_calibration.py` as NEW files if the m125 scripts do not
generalize with args; they must produce the manifest/digests layout
the rig reads — find where the rig reads `layerXX_*.bin` and the
manifest; the WSL box cannot hold a 7B bf16 model, so the export is a
MAC task: write it so Grok can run it (TASK_BOARD RUN task with exact
commands), and test the script's structure here on the 125M ckpt via
the same code path). (5) The plan: lanes, files, gates, in order, with
the smallest rung first; what needs Victor (license, the Mac run,
disk).
Report: the memo (sections 0 one paragraph, 1 counted sizes, 2 what
breaks, 3 memory/time per box, 4 data + scripts, 5 the plan + the
Grok RUN task text), everything labelled.

### Lane S — spike S1 + S2 of the Stage-A protocol change (wt-uperf3-s) — CODE (synthetic, no engine change)

OWNS: NEW `zkmatrix-rs/src/ring/zc_range.rs` (or a name you choose,
new file) for the spike's base-field booleanity / recomposition
zero-check + the LogUp-as-one-sumcheck prototype, a `// [UPERF3-S]`
bin section + `uperf-s` (dispatch line next to the other
`Some("uperf-…")` lines), NEW `docs/zkmatrix-poc/U_PERF3_SPIKE_REPORT.md`,
"Agent S status" below, `ct_engine::prof` ids 89 (free) — if you need
more, add `S_*` ids 90-95 and bump N_PHASES to 96 (no other lane
touches prof this round). Read-only: everything else (the frozen pass
is the ORACLE, not the patient).
GOAL (U_PERF3_OPENING_LAYER_DESIGN.md §5.3 / §6.1, read it first, then
§2.3-2.4): S1 — on a synthetic 2^20-element remainder column at a
representative width (w = 8; also w = 4 and 12), build (a) the current
masked descent pair (the `uperf-a descent-bench` shape / the BK pair
builder) and (b) the base-field booleanity zero-check over the same
committed bit planes + the recomposition check, folded into a synthetic
aggregate sumcheck; COUNT K-mults vs base-field MACs, round polys and
transcript bytes; MEASURE the wall at 1T/8T on this box (default build;
GPU not required). Acceptance in the memo: >= 5x cheaper in
K-mult-equivalents, round count ~10x fewer. S2 — one SiLU column at
2^20: the descent-form claims vs the LogUp-as-sumcheck claims with a
committed helper h; the claims must be EQUAL at fixed seeds (the
descent as oracle — say precisely which values are compared);
measure the round-poly count and the h overhead. Deliver a go/no-go
per spike with the measured ratios, and the counted implication for
the 12x512 and 8B shapes (descents 6.5 s -> ?; the tree memory peak
-> ?; artifact -> ?). Batteries: `uperf-s battery` (equalities at
several shapes/widths/seeds, planted extremes, ZK_THREADS 1/2/7); the
default gate unchanged (`uperf-pc diff-battery`, freeze rows).

### Lane T — the headline within the lattice line: what would 5-15 s at 8B take (wt-uperf3-t) — DESIGN/LITERATURE

OWNS: NEW `docs/zkmatrix-poc/U_PERF3_HEADLINE_ROUTES.md`, "Agent T
status" below. Read-only everywhere else.
GOAL: the "be more creative" memo. Start from the design memo's
finding (Stage A/B <= ~2.5x; the eval proof / lattice opening is the
floor: level-h + kernel passes + psi0 + transport + commit + CRS ~12 s
of the 21 s and it scales ~x100 to 8B) and from AGGREGATION_LITERATURE.md
(the Greyhound-adaptation verdict, families (a)/(b)/(c), obligations
O-1..O-9, and what of it was actually built — read UAGB1_PASS_AGG_REPORT
/ UAGB1_TABLE_DESCENT_REPORT to say precisely which family the built
pass is). Then, with COUNTS at 8B x 512 (2.9e12 MACs; the witness
sizes lane R counts — coordinate through the ledger, do not wait):
candidates that could move the exponent while keeping MLWE/MSIS +
exact-integer soundness: (i) the full family-(c) O(sqrt N) reroute of
the eval proof (Greyhound-class PCS serving), (ii) folding across the
32 identical layers (LatticeFold / LatticeFold+ (2024-25) / Neo-style
lattice folding: one accumulated instance, the opening paid once —
what the folding verifier costs, what the norm growth does to q31/q46),
(iii) batching the level-0 claims across layers/tokens (the R-row and
one-point batching pushed further), (iv) GPU-native restructuring
(the K-field arithmetic per round is at its ceiling on this part —
which parts are inherently serial vs. embarrassingly parallel across
32 layers / many pairs, and what a multi-GPU or a desktop board buys
[MODEL]), (v) anything from the 2025-26 lattice-PCS / lattice-folding
literature that fits (WebSearch allowed; cite; label [EXTERNAL]).
For each: what changes in the protocol, the counted prover/verifier
cost model at 8B on a desktop board, the soundness obligations, the
build size (tranche-weeks), and an honest expected factor. End with a
ranked recommendation for a second design freeze and the ONE spike
that would de-risk the top candidate. Plain narrative, labelled
numbers, ~300-600 lines.

## Agent status sections (lanes append below; do not edit each other's)

## Agent S status (wt-uperf3-s)

- 2026-08-18 SKELETON: worktree fast-forwarded to d1d1963 (the ledger
  commit lives on perf/zk-batch-optimizations, not on `main`); report
  skeleton docs/zkmatrix-poc/U_PERF3_SPIKE_REPORT.md; plan: (1)
  zkmatrix-rs/src/ring/zc_range.rs (NEW) — sub-extension E_c = GF(q^c)
  arithmetic inside K (c in {4, 8, 16}, coordinates at stride 16/c), the
  lane-packed booleanity + recomposition zero-check prover/verifier (S1
  b), the LogUp-as-one-sumcheck with committed h on the frozen packed
  Had kernel (S2 b), structural K-mult counters for the masked descent
  (S1/S2 a); (2) bin `// [UPERF3-S]` section + `uperf-s` dispatch
  (`uperf-s s1|s2|battery|count`); (3) freeze-check capture BEFORE any
  edit; (4) measurements 1T/8T; (5) report + this status. Status: IN
  PROGRESS.
- 2026-08-23 RESUME (session cut 08-18 mid-file): zc_range.rs recovered
  (1370 lines, coherent, committed as WIP first), counter honesty fix
  (per-pair-node MACs now include node extrapolation + digit scalings),
  wired: `mod zc_range` + bin `[UPERF3-S]` section (`uperf-s
  s1|s2|battery|count`, descent-pair oracle helper mirroring
  bk_pass_run's call sequence: alpha-first transcript, blinded witness/
  table trees, solve_mass, masked descents, pinned verify). Build green
  first try. BATTERY GREEN at ZK_THREADS 1/2/7, 48 legs, digest
  3752cba4fa08c2ee052475e9f4459e2fc3ed0a0c59862468e0c31cbeb165aaae
  identical across all three: (A) c=16 zero-check == boxed-K oracle
  (fold.rs ixf_sumcheck_prove) byte-for-byte — transcript state, round
  polys, fold point, finals — at 5 shapes incl. e0=2; (B) c in {4,8}
  honest+open accept, digit-outside-alphabet (recomposition-consistent)
  REJECTS, recomposition tamper REJECTS, all-hi/all-lo extremes accept,
  w in {3,4,8,12}; (C) S2 equality set at 2^10: P_w/Q_w - mass_w ==
  h_sum, P_t/Q_t - mass_t == table_sum, mass_w == mass_t, cross-check
  == sum equality; off-table key keeps chain and fails sum;
  multiplicity tamper fails sum. NOTE: e0=1 planes use the HOUSE
  sign-binary alphabet {-1,0,1} (digits::alphabet), deg_f 3 — an upper
  bound on the memo's {0,1} booleanity (deg_f 2). Next: gates
  (uperf-pc diff-battery, freeze-check), then s1/s2 measurement passes.
- 2026-08-23 GATES + MEASUREMENTS (box QUIET: 99.4% idle, 12.3 GB free,
  load 0.59 before timing): uperf-pc diff-battery GREEN (O1 4/4, O2
  35/35, O3 63/63, O5 12/12, E2E 2/2, 15.5s); freeze-check WSL form
  GREEN (98 rows ok, last "ok UAGB1-BL-1d pass schedules unmoved by the
  blind (+1728 rings): tierz L8 floor 1368 e4 (pins L8/1368/e4), bare
  L8 floor 939 e7 (pins L8/939/e7)", then the EXPECTED panic at the
  UAGB1-BF m125-export rows — no export on this box). S1 at 2^20
  [MEASURED WSL-BOX QUIET], c=4 (the design point), zero-check vs the
  descent pair (depth 21 + dt w+1, l=1): w=4 25.2x K-mult-equiv / 12.2x
  rounds / 45.4x wire, wall 2.1x (1T) 3.2x (8T); w=8 13.5x / 13.7x /
  49.5x, wall 1.0x (1T) 1.6x (8T); w=12 9.2x / 16.0x / 55.5x, wall 0.8x
  (1T) 1.2x (8T) — GO at every width on the memo's acceptance (>=5x
  equiv, ~10x rounds); c=8 3.9-7.3x (marginal), c=16 ~1x (it IS K).
  Wall lag vs count: the prototype E_4 round kernel runs ~2.9 GMAC/s
  (8T) vs the frozen K9 kernel's ~23 GMAC-equiv/s — kernel-quality gap
  ~8x, so the counted 13.5x nets 1.6x measured; a production E_c kernel
  is the (b)-side upside. S2 at 2^20: ALL FOUR claim equalities hold at
  fixed seeds (P_w/Q_w - mass_w == h_sum; P_t/Q_t - mass_t ==
  table_sum; mass_w == mass_t; cross-check == sum equality); rounds
  13.7x fewer (274 -> 20), wire 15.7x (86,272 -> 5,504 B), prove wall
  1.9x (1T) / 1.2x (8T) INCLUDING h build; h overhead: 64 MiB raw per
  2^20 column (rides ACT eval proof), h build 0.13-0.15s. Peak RSS
  627-729 MiB (all runs). Both spikes GO. Next: the report.
- 2026-08-23 CLOSE: U_PERF3_SPIKE_REPORT.md COMPLETE (go/no-go, what
  was built, S1/S2 tables with every number labelled, the 12x512 and
  8B implications, caveats — the kernel-quality gap named as the open
  wall risk, batching/alphabet/masking/one-point-opening listed as
  Stage-A obligations the spike did not test). Lane S deliverables
  done: zc_range.rs + [UPERF3-S] bin section (additive), batteries
  green 1/2/7, both default gates green, report filled. Files touched:
  zkmatrix-rs/src/ring/zc_range.rs (NEW), ring/mod.rs (one mod line),
  bin/ring_matmul.rs ([UPERF3-S] section + dispatch arm),
  docs/zkmatrix-poc/U_PERF3_SPIKE_REPORT.md, this status section.
  No frozen file, no other lane's file, no prof id used. STATUS: DONE.
