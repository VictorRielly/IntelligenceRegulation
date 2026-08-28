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

## Round 1 CLOSED (orchestrator, 2026-08-23)

The 2026-08-18 session died ~25 minutes after opening the round; all
three lanes were resumed 2026-08-23, completed, and merged (lane R
9bc34ed..afc8c8e, lane S d9e9e86..28fb3e0, lane T 25e18f7..425367a).
Gates on the merged tree [WSL-BOX]: `uperf-pc diff-battery` green
(O1 4/4, O2 35/35, O3 63/63, O5 12/12, E2E 2/2), `uperf-s battery`
48 legs, digest 3752cba4… identical to the lane run, `freeze-check`
WSL form (98 rows ok through UAGB1-BL-1d, expected BF panic).

What round 1 established:
1. **Lane R:** the 8B MVP is buildable — every break is inventoried
   (W-1..W-11) with smallest fixes totalling ~8-12 lane-days; 32x512
   fits the Mac ONLY with W-8(a) (~184 GB peak); the export scripts
   are DONE and validated byte-identically at 125M; Grok's T12 is
   unblocked (needs the download go). Plan M0-M8 in the memo §5.1.
2. **Lane S:** Stage A's spike is GO/GO — the zero-check range fact
   beats the masked descent 9-25x in K-mult-equivalents with 12-16x
   fewer rounds and 45-55x less wire, and the LogUp-as-one-sumcheck
   claims are bit-equal to the descent oracle. Named caveat: the
   prototype E_c kernel runs ~8x below the K9 kernel's quality, so
   the measured wall win (1.0-3.2x) trails the counted win until a
   production kernel exists.
3. **Lane T:** the headline recommendation for a second design
   freeze — the opening re-architecture (Stage A + one-point front
   end + Greyhound/Hachi-class two-tier serving + weight-group
   preprocessing): 8B ~20-40 s on one desktop board, ~6-13 s on
   four [MODEL], verifier sub-second at 1T; spike S4 (2-4 days, no
   freeze move) de-risks it against the real 12x512 act group.

**AWAITING VICTOR (the round-2 fork):**
(a) the T12 download go-ahead (~17 GB network, ~30 GB Mac disk;
    Mistral-7B-v0.1 default — ungated; or Llama-3.1-8B, gated);
(b) whether round 2 opens with spike S4 (lane T's recommendation)
    alongside the MVP code rungs M1+M2 (W-5/W-4/W-2 — what unblocks
    the first 8B rig run), or MVP-only first;
(c) the W-6 SiLU-member freeze ruling only if the 7B calibration
    flags a new member (manifest.rs would move — Victor-only).

## T12 WSL validation pass (orchestrator, 2026-08-24) — THE CALIBRATION FINDING

Victor approved the Mistral download (console, 2026-08-24); the WSL
box ran the full T12 pipeline as a validation pass. Steps 1-4 results:

1. Download + decode gate: the memo's France-prompt gate was a FALSE
   FAIL in exact fp32 (" Paris" rank 3, 0.85 logits behind "a"; the
   " Paris" lore is bf16 arithmetic). The adapter itself is CORRECT —
   five-prompt factual next-token probe: " Au"/" oxygen"/
   " Shakespeare"/"4" at rank 0, "J"(upiter) rank 1 gap 0.03. Gate
   revised to the gold prompt (memo §5.2 step 3; pushed 4821e41);
   the revised gate PASSES ("...gold is Au. It is a soft, m").
2. **Calibration [MEASURED WSL-BOX, seed 1337, 8+8 x 512]: Mistral-
   7B-v0.1 DOES NOT CALIBRATE formally under TARGET_CONTRACT §2 as
   written.** Range-fact violations on held-out data: 14,531 (g/u/h/z
   classes; X clean everywhere); int8-chain val loss 10.02 vs bf16
   ref 1.84 (+8.18 nats — the as-written chain destroys the model);
   **weights-only int8 is nearly lossless: 1.92 (+0.08 nats)**.
   Accumulator ceilings all respected (gate/up 27-bit, down 29-bit —
   W-4's numbers confirmed). W-6 fired: 7 SiLU members outside the
   frozen family ((-3,-4),(-1,-1),(-4,-5),(-5,-5),(-2,-3),(-1,-2),
   (-1,-3)). Peak RSS 4.58 GB (memo said < 4 — close). JSON:
   results/m8b_int8_calibration_wsl.json.
3. **Diagnosis: emergent activation outliers** (the >= 6.7B
   phenomenon of the LLM.int8()/SmoothQuant literature — the 125M
   calibrated clean because it is below the emergence scale). The
   per-channel profile is textbook: x absmax/p99.99 = 2-6.5x across
   layers; h (Hadamard) = 6-6158x with layers 0/1/30 extreme (l1
   absmax 1353 vs p99.99 0.22). A FEW channels carry the range —
   per-TENSOR power-of-two scales cannot cover them.
4. CONSEQUENCE: the T12 EXPORT is GATED (its own 0-violations assert
   would fail); the real-weights 8B witness cannot exist until the
   spec question is ruled. NOT blocked: all M1/M2 engine work (W-5/
   W-4/W-2 run on synthetic or 125M-shaped witnesses), the Mac
   calibration as a digest cross-check.
5. RESCUE EXPERIMENT LAUNCHED (agent U, new files only):
   SmoothQuant-class per-channel POWER-OF-TWO rebalancing folded into
   adjacent weights — exact function equality (X-side: s_j into
   mlp_norm/gate/up columns; u/h-side: t_k through the up-row/
   down-column pair; the g->SiLU path cannot fold — margin-bit
   calibration policy instead), so the PROOF STATEMENT is unchanged
   in form: it binds the transformed weights, and the transform is a
   documented preprocessing step in the model identity. The
   experiment re-runs the verdict on the same seed/windows and
   reports violations + nats before/after.

**FOR VICTOR (the ruling this sets up, after the experiment
reports):** (a) adopt the rebalancing transform into the model-
identity/spec (TARGET_CONTRACT §2 addendum — the amendment path),
or (b) widen the activation classes (engine + statement change,
heavier), or (c) accept a bounded-violation/clipped statement
(measured +8.18 nats says the clipped model is garbage — not
viable as-is). The W-6 SiLU freeze ruling folds into the same
decision (the member list depends on the adopted scales).

**POSTSCRIPT after agent U's experiment (2026-08-24, results in
U_PERF3_M8B_SMOOTH_REPORT.md + the Agent U status below): (a) alone
is MEASURED DEAD.** The fold family is exact (transformed fp32
forward bit-identical to the reference) and rescues FORMALITY
almost completely (violations 14,531 -> 3, all layer-31 h-class),
but the chain loss stays +7.9..+9.1 nats in every tried policy —
int8 precision at outlier-covering per-tensor scales destroys the
model even when nothing overflows. The irreducibles the fold cannot
reach: the silu(g) path (unfoldable), the z spikes (l1 absmax 379.7
vs p999 0.21), l31's ~14-bit u range. The measured pointer to the
viable fix is **(b)-lite**: per-COLUMN w_down scales (absorbing the
t-fold without the migration damage that ruined per-tensor w_down)
plus wider a/h/z classes at the ~6 outlier layers only. A PRICING
experiment for (b)-lite (agent V, launched 2026-08-24) measures the
loss it achieves and counts the engine/spec surface, so the ruling
can happen once, with numbers on every option.

## Design round: the general quantization contract (orchestrator, 2026-08-25)

**Authority — Victor, console 2026-08-25 (verbatim), redirecting the
fix from model-specific to general:** "Let's look for a fix that can
work in many different contexts (such as this proof requires no more
than 8 bit quantization models) or something, instead of conjuring a
fix specific to this precise use case. The more general fix is much
more easy to maintain going into the future. Be sure to document the
engineering design choices and limitations." Same day, the model
question: an open 8B-class model with friendlier NATIVE quantization
(Gemma 4 named).

DELIVERABLE: docs/zkmatrix-poc/QUANTIZATION_CONTRACT_DESIGN.md — the
proposed TARGET_CONTRACT §2 v3 as a MODEL-AGNOSTIC contract behind a
statement-version selector: C1 chain form unchanged; C2 public
per-channel power-of-two exponent VECTORS (per-tensor = the constant
degenerate case; the 125M statement unchanged); C3 model identity =
raw checkpoint + declared function-preserving preprocessing (T1
per-channel PoT folds, T2 static d-axis orthogonal rotations) +
calibration record; C4 the mechanical qualification gate (0
violations + quality budget vs the model's own bf16 reference,
verdict JSON public); C5 the open frozen-table registry
(generalizes W-6: silu/gelu/relu^2 members by ruling); C6 declared
margins. Design choices D1-D6 and limitations L1-L7 documented per
the authority quote (the sharp ones: static scales only — dynamic
per-token schemes are out of contract; rotations exist only on the
d-axis — no rotation seam crosses silu(g)⊙u; C4 detects, it does
not rescue). Routes R/R+/T/Q/N; agent V's in-flight pricing plugs
into R+.

MODEL SURVEY (searched 2026-08-25, [EXTERNAL]): **Gemma 4** (Apr 2,
2026: E2B/E4B/26B-MoE/31B-dense; 12B Unified Jun 3) shipped **QAT
checkpoints Jun 5, 2026** incl. research-grade
google/gemma-4-12B-it-qat-q4_0-unquantized and a mobile variant
QAT-trained with per-channel int2/int4 weights + **int8
activations** — activation-int8 in the training loop = the prime
route-N candidate at 8B class. BitNet b1.58 2B4T = the only fully
native W1.58A8 line, 2B only, per-token dynamic scales (L1) — watch
item. Qwen3/Llama-3.1/Mistral: same emergence physics, bridge
customers.

GEMMA 4 12B QAT DOWNLOADED AND SCOPED (2026-08-25, this box —
**no license gate hit**; 23 GB single shard at
~/models/gemma-4-12B-qat): text_config d 3840 (30x128 OK), f 15360
(120x128 OK), 48 dense layers (no MoE), GeGLU (gelu_pytorch_tanh
-> ONE C5 registry member), rms eps 1e-6, GQA 16/8 heads at
head_dim 256, vocab 262144, tied embeddings, final logit softcap
30.0. Tensor scan: model.language_model.layers.N.* with the
FOUR-norm sandwich (input/post_attention/pre_feedforward/
post_feedforward), q_norm/k_norm [256] (QK-norm), a per-layer
`layer_scalar` [1] (semantics from the HF modeling source), hybrid
attention 40 sliding (window 1024 — plain causal is VALID at
T = 512) + 8 full_attention layers with global_head_dim 512 /
1 global KV head / attention_k_eq_v; multimodal embedder tensors
separable (text walk uses embed_tokens directly). FFN statement
shape: (48, 3840, 15360) — ~8.7e12 MACs at T = 512, ~3x the
Mistral 8B contract shape (a BIGGER headline than 8B, and ~3x its
clock). ADAPTER WORK (queued behind agent V for the box): the
gemma4 walker (four norms, QK-norm, layer_scalar, hybrid
attention + per-type rope bases from the HF modeling source,
softcap, tied head), a gelu-tanh table-member candidate, then the
C4 gate run — the decisive measurement of whether QAT-int8-
activation training actually tames the outlier profile.

## Round 2 (2026-08-25): lanes W (shape generalization M1+M2), X (attention statement design), Y (Gemma 4 adapter) — parallel to agent V (pricing) and the pending rulings

Opened under the standing route-1 ruling (MVP-first, protocol work
alongside) and Victor's 2026-08-25 console question "What can you
work on while that is brewing?". Box discipline: agent V owns the
heavy CPU (full verdict passes); W's builds/short batteries and Y's
--max-layers smokes are fine; NO 12x512-class runs this round; the
Gemma full C4 gate run and spike S4 are QUEUED behind V.

### Lane W — the rig accepts arbitrary model shapes (wt-uperf3-w) — CODE (M1+M2 of the MVP plan)
OWNS: the W-5/W-4/W-2 fix sites in zkmatrix-rs (bin/ring_matmul.rs
model-const sections, eval_proof.rs planner), a new `uperf-w`
battery section, "Agent W status" below. The memo rows
U_PERF3_MVP8B_SCALING.md §2 W-5 / W-4 / W-2 are the brief (file:
line, smallest fix, freeze constraints). Deliverable: the default
M125 path BYTE-UNCHANGED (freeze rows, diff-battery, 3x16 digest)
+ a BfModel/ZK_MODEL_EXPORT_DIR path validated end-to-end on the
m8b-format 125M re-export (the first proof through the generalized
loader), planner Option legs at the 8B group counts.

### Lane X — the attention statement design (wt-uperf3-x) — DESIGN (MVP-2 opens)
OWNS: NEW docs/zkmatrix-poc/U_PERF3_ATTENTION_STATEMENT_DESIGN.md,
"Agent X status" below. Map every op of the transformer layer
(QK^T, softmax, RoPE, RMSNorm/QK-norm, V/O matmuls, residual,
GQA/sliding structure, Gemma's four norms + layer_scalar) onto the
existing claim machinery under the C1-C6 contract
(QUANTIZATION_CONTRACT_DESIGN.md; ATTENTION_INTEGER_SPEC.md is the
integer-semantics input), with counted costs at the 125M / Mistral-
8B / Gemma-12B shapes, the C5 table members needed, witness/
statement sizes, soundness obligations, and the MVP-2 build plan.

### Lane Y — the Gemma 4 reference walker + gate prep (wt-uperf3-y) — CODE (python, new files only)
OWNS: NEW scripts/m8b_gemma4_*.py, NEW results/m8b_gemma4_* files,
"Agent Y status" below. The numpy reference forward for
gemma-4-12B-qat (four norms, QK-norm, layer_scalar, hybrid
sliding/global attention with per-type dims/rope from the HF
modeling source, softcap, tied head), the decode/factual gate, the
gelu_pytorch_tanh table-member candidate generator. SMOKES ONLY
(--max-layers 2-4) this round; the full C4 gate run is the
orchestrator's to schedule after agent V lands.

## The Gemma 4 C4 gate verdict (orchestrator ran it, 2026-08-25 ~23:30)

[MEASURED WSL-BOX NT, seed 1337, 8+8 x 512 on the same FineWeb text
as the Mistral baseline; results/m8b_gemma4_calibration.json; peak
RSS 5.34 GB; exit 0.]

**VERDICT: FAIL — but a structurally DIFFERENT and smaller failure
than Mistral's.** 116,852 held-out range-fact violations, chain loss
delta +17.60 nats (ref 7.2367 — the plain-fineweb-through-an-it-model
caveat lane Y flagged: absolute losses read high, the DELTA is the
meaningful number), weights-only +0.1356.

The structure is the story: **the QAT training DID tame the FFN
internals** — across all 48 layers the internal sites are essentially
CLEAN at per-tensor int8 (X: 1 violation total, gate: 0, up: 14,
Hadamard h: 0 — the sites that carried thousands of violations and
the 6158x outliers on Mistral). Every remaining violation but 15 is
at the **z site (the down-projection output feeding the residual
stream)** and concentrated at ~6 layers, dominated by ONE (layer 2:
98,650 of the 116,852; then l24 12,036, l9 5,885, l23/l26/l21
small). Accumulator ceilings all respected (27/29-bit). 6 GELU
members outside any frozen registry (C5 ruling rides along).

READING: Gemma-4-QAT needs the per-channel bridge at the z SITE of a
handful of layers (exactly agent V's `zcols` mechanism) — a much
SMALLER bridge surface than Mistral's (which needs u/h/z + widened
gate classes). Neither checkpoint qualifies natively at per-tensor;
the C2 per-channel contract is load-bearing for BOTH routes — the
general fix is the right fix. TODO for the pricing side: a
Gemma/GeGLU adaptation of the blite z-variant to measure whether
per-column eZ at those ~6 layers rescues the delta (the blite phase
as built is SwiGLU/m8b-module-specific).

Round-1 blite pricing (Mistral, agent V's exact command, variants
percol + percol_g16) LAUNCHED on the freed box right after this
verdict — running now.

## Blite round-1 verdict (orchestrator ran agent V's command, 2026-08-26 ~00:15)

[MEASURED WSL-BOX NT, seed 1337, same windows; wall 1,699 s, peak
RSS 3.93 GB, exit 0; results/m8b_blite_experiment_wsl.json.]

**Quality is NOT rescued on Mistral — route R+ is measured dead.**
percol (per-column u/h/z requant scales + per-column w_down +
margins): violations 14,531 -> 1,106 (h 1,082 residual) but delta
**+7.63 nats** (baseline +8.18). percol_g16 (+ the 16-bit gate table
at layers 0/1/2/30/31): 1,789 violations, delta **+7.32**. With
agent U's fold results this is now THREE independent mechanism
families that fix RANGE but not QUALITY on Mistral: the per-layer
relative FFN error sits at 40-90% even where formally in-range —
static 8-bit precision against Mistral's activation distributions is
the binding constraint, not range coverage. The literature's escape
hatches (dynamic per-token scales, QAT) are exactly the ones outside
the static contract (L1) or outside preprocessing (route Q).
Engine bill as measured (for the record; now moot for Mistral):
max sh 24-27 (the REM class cap must rise 16 -> ~28), max align
18-21, honest down-acc 34-37 bits, 18 layers multi-tier (up to 3).

**CONSEQUENCE — the ruling picture simplifies:** (i) Mistral-7B is
not an MVP vehicle under any static-8-bit preprocessing we can
build; it stays the documented hard case. (ii) Gemma-4-12B-QAT is
the live vehicle IF its one broken site (z, ~6 layers, internals
clean) rescues — the z mechanism is post-accumulator per-column
requant (NO alignment cost, the cheapest C2 mechanism). The decisive
measurement (agent Z, launched 2026-08-26): per-column eZ at the hot
layers on the Gemma walker, delta vs the +17.60 baseline.

## Z-fix record passes (orchestrator, 2026-08-26 morning)

First record pass (p999 floor): a DERIVATION BUG — V's p999 floor
tightened bulk z columns below the baseline per-tensor scale and
destabilized the chain (Z1 911k viols / +23.6; preserved as
results/m8b_gemma4_zfix_wsl_p999floor.json; equiv gate bit-exact so
the machinery itself is sound). Floor corrected to the baseline
per-tensor exponent (pure range extension; smoke: hot-layer z viols
98,650 -> 0).

Corrected record pass [MEASURED WSL-BOX NT, seed 1337]:
- **Z1 (per-column eZ, all 48 layers): violations 116,852 -> 87**
  (z 81, up 5, X 1) — formality one margin bit from clean.
  **Loss delta +17.5693 vs baseline +17.6029 — QUALITY UNCHANGED.**
- Z2 (hot 6 layers only): 116 viols, +17.9795.
- max sh_z 9 (inside the 16-bit REM cap), statement bytes 184,320
  (Z1) / 23,040 (Z2); no alignment, acc bounds unchanged.

**READING: the z RANGE was never the quality killer. The +17.6 is
RESOLUTION loss at outlier-stretched per-tensor ranges (h ratios
43-240 at the hot layers; z feeds the residual at coarse steps
everywhere; relFFNerr 0.4-9.5 even at violation-free layers). Same
disease as Mistral, different symptom. Across BOTH checkpoints,
every RANGE mechanism (folds, margins, per-column requant at every
site family) now measures: violations -> O(10-100), quality
unmoved. The ONE static mechanism family not yet measured on
quality is CLASS WIDENING — int16 activations at the stretched
sites (V's a16/g16 for Mistral; Z3 int16-z + an h16 extension for
Gemma). Being measured now: Gemma Z3, then Mistral a16=all. If
widening rescues quality, the contract's answer is W8A16-at-
declared-sites (weights stay int8). If not, the static-scale
boundary (L1) is fully established and the honest routes are QAT
fine-tuning to the contract (route Q) or a quality-labeled MVP.**

## THE CLASS-WIDENING RESULT (orchestrator, 2026-08-26 — the fix)

After the per-site noise ATTRIBUTION located the damage (h +2.77 /
z +3.64 first-order at ALL layers; W/X/gate/u 0.07-0.38), the exact
integer chain was measured with WIDENED CLASSES (int16 = the same
absmax coverage at exponent e-8, 256x finer step; negative shifts =
exact public up-scalings). Gemma-4-12B, full val windows, all
[MEASURED WSL-BOX NT]; the floor/a8 sanity leg reproduced the
baseline BIT-EXACTLY (24.8396 / 116,852):

| exact chain variant | delta (nats) | violations |
|---|---|---|
| floor, all-int8 (frozen spec) | +17.6029 | 116,852 |
| round, all-int8 | +4.9175 | 63 |
| floor, h16+z16 | +1.3722 | 4 |
| round, h16+z16 | +0.7860 | 10 |
| round, u16+h16+z16 | +0.7146 | 11 |
| round, uhz16 + g16(domain) | +0.7656 | 5 (g16 NEUTRAL) |
| round, X16+uhz16 | +0.5967 | 10 |
| **round, a16(out)+uhz16 — THE CHEAP STACK** | **+0.0353** | **14** |
| round, X16+a16+uhz16 | +0.0518 | 12 (X16 unnecessary) |

**+17.60 -> +0.0353 nats — essentially faithful (BELOW the
weights-only +0.1356 floor) — with the CHEAP stack: int16-resolution
TABLE OUTPUT (the table keeps 256 rows), int16 u/h/z classes (all
elementwise/post-accumulator), round-nearest requant (the m125-
documented same-proven-relation mode), X and the matmul inputs
except h staying int8.** Violations 14 of 4096x5x48 — one margin
bit from zero. ENGINE BILL: (1) witness digit width doubles at the
a/u/h/z activation tensors only; (2) ONE limb-split matmul input
(h16 into the down matmul — A1LimbCommitKernel-pattern precedent);
(3) new frozen table members (256-row, int16-out) in the C5
registry; (4) round-mode requant as a statement semantics choice;
(5) range-fact classes at 2^15 (u/z), 2^30 (h = a16 x u16). NO
limb-split on the gate/up matmuls (X stays int8) — the two big
matmuls are untouched.

Mistral cross-check (the same winning stack on the SwiGLU chain,
scripts/m8b_widen_attrib.py) launched — the model-agnosticism
evidence for the amendment. The ruling package follows it.

**MISTRAL CONFIRMED (2026-08-26, [MEASURED WSL-BOX NT], full val
windows):** the same cheap stack lands Mistral-7B at **+0.2157
nats** (from +8.1773 frozen / +7.32 best-prior-static; violations
14,531 -> 32: X_clip 8, gate 7, u 1, h 16, z 0). uhz16 without
a16-out: +0.2786. THE AMENDMENT IS MODEL-AGNOSTIC — both
checkpoints, both gate functions (SwiGLU + GeGLU), the same five
engine items. Under it, BOTH checkpoints QUALIFY: Mistral-7B
(the original MVP-1 contract shape) at +0.216, Gemma-4-12B at
+0.035. Consolidated report:
docs/zkmatrix-poc/U_PERF3_QUANTIZATION_MEASUREMENTS.md; the
amendment text: QUANTIZATION_CONTRACT_DESIGN.md §8 (measured
postscript). The ruling package is with Victor.

## RULING (Victor, console 2026-08-26, verbatim): "Let's continue
## adopting this v3 fix."

Adopted: TARGET_CONTRACT §2 v3 = the C1-C6 contract + the
widened-stack amendment (QUANTIZATION_CONTRACT_DESIGN.md §7';
measured record U_PERF3_QUANTIZATION_MEASUREMENTS.md). The adoption
covers the C5 registry additions the amendment requires (int16-out
silu/gelu members — the manifest.rs/lookup.rs additive freeze rides
this ruling, versioned, existing digests unmoved). Victor also
asked for the distance to a FIRST FULL proof (attention included)
of an 8B/12B model — answered in the board §0 and the reply of
record.

## Round 3 (2026-08-26): lanes AA (witness/margins/exports), BB (the v3 engine), CC (attention-site gate)

Box discipline: AA and CC run measurement walks (~4-5 GB each) —
wrap every walk in `flock -w 7200 /tmp/zk-heavy.lock`; BB builds and
runs batteries freely; nothing 12x512-class without the lock.
Subagent stall note: background-run wakes are unreliable — arm ONE
tracked background call and end the turn; never build watcher
stacks; if you find your own run finished without a wake, just
continue from its output file.

### Lane AA — margin bits to zero violations + the v3 witness exports (wt-uperf3-aa) — PYTHON
OWNS: NEW scripts/m8b_margins.py + additive flags in
scripts/m8b_export_ffn.py and scripts/m8b_gemma4_walker.py (lanes
R/Y closed; additive only — default behavior byte-identical), NEW
results files, "Agent AA status". GOAL: (1) the margin-bit round:
+1 bit on the per-tensor exponents of the residual-violation sites
(Mistral X/gate/u/h rows; Gemma X/gate/h/z rows), re-run both
verdicts under the widened stack, iterate to **0 violations** with
the smallest margin set; record the quality cost (expect ~none —
the margins touch coverage, not bulk resolution). (2) The v3
EXPORT profile: extend the export path to emit the widened witness
(int16 planes at a/u/h/z, the round-mode flag, the margin exponents,
the int16-out table ids) for BOTH checkpoints — Mistral streamed
here, Gemma local — with digests; the layout doc for lane BB's
loader in the script header. (3) The int16-out member tables +
digests for the C5 freeze (silu set + gelu 6) — generation script,
registry-ready.

### Lane BB — the v3 statement in the engine (wt-uperf3-bb) — RUST
OWNS: the v3 selector path in zkmatrix-rs (statement version /
rig arm `uperf-v3` or M1-style profile flag), E1 widened witness
classes at a/u/h/z, E2 the h16 limb-split down matmul
(A1LimbCommitKernel / ring_mul_q_limbsplit pattern), E4 round-mode
requant selector, E5 range-fact classes (u/z 2^15, h 2^30), the C5
int16-out registry rows in lookup.rs AND manifest.rs (ADDITIVE,
under this ruling, with UAGB1-BF-2a-style freeze rows; EVERY
existing digest unmoved), the migration battery (v2 default
byte-identical: diff-battery + freeze-check + the 3x16 digests are
the floor), "Agent BB status". GOAL: the v3 pass proves a widened
witness end-to-end on the 125M shape first (the synthetic/125M
rung — lane AA's export format), then the 1x16/3x16 real rungs.
NOT this round: W-1/W-3 (they gate 32x128+; the 32x16 rung does
not need them).

### Lane CC — the attention-site qualification gate (wt-uperf3-cc) — PYTHON (the MVP-2 de-risk measurement)
OWNS: NEW scripts/m8b_gemma4_attn_gate.py (+ additive collect hooks
in the walker if needed), NEW results, "Agent CC status". GOAL:
MVP-2's biggest unknown is whether ATTENTION activations carry the
same outlier disease. Extend the walker to collect the attention
intermediates per ATTENTION_INTEGER_SPEC.md's site classes (q/k
post-norm, scores/softmax in, attn-probs, attn-out, o-proj out,
residual x at the attention seam) on the calibration windows; run
the C4-style int8 (and widened-int16) simulation per site
(attribution-style: per-site quantize-dequant deltas + range
profiles per layer); deliver the site table (which attention sites
are int8-clean, which need the widened class) for the MVP-2
statement design (U_PERF3_ATTENTION_STATEMENT_DESIGN.md §1's
exponent assumptions get their first real data).

## ROUND 4 — STAGE A BUILD (opened 2026-08-27; Victor console: work
## Stage A while the Mac is busy; sanctioned by the 2026-08-18
## route-1 ruling's "protocol work alongside")

Ground: spike S1/S2 GO/GO (U_PERF3_SPIKE_REPORT.md — 9-25x
K-mult-equivalents, 12-16x rounds, 45-55x wire vs the masked descent
at 2^20; claims bit-identical); the production gaps are the spike
report §5 list. Stage A is ALSO MVP-2's memory-feasibility
requirement (the 120 GB descent pair vanishes). Everything additive
behind uperf-s/uperf-t selectors; the frozen pass stays the oracle;
freeze-check + diff-battery + the uperf-s 48-leg battery digest
3752cba4.. are the floor at every commit.

### Lane DD — the production E_c kernel (wt-uperf3-dd) — RUST/AVX2
OWNS: NEW zkmatrix-rs/src/ring/ec_kernel.rs + the e_mac* dispatch
hooks in ring/zc_range.rs (additive; the scalar bodies stay as the
oracle), a `uperf-s kernel-bench` arm in the bin's [UPERF3-S]
section, "Agent DD status". WHY: "kernel quality is the open wall
risk" (spike §5) — the E_4 kernel runs ~8x below K9's MAC
throughput, so the counted 13.5x is a measured wall win of only
1.6x (8T). GOAL: AVX2 intrinsics for the four MAC families
(e_mac / e_mac_base / e_mac_fixed / e_mac_base_fixed — u32xu32->u64
widening MACs into split lo/hi planes; the round-6 lane-J K9 AVX2
idiom, SIMPLER here: base-field, no 16-wide reduction), runtime
feature detection, scalar fallback = today's code. ACCEPT: uperf-s
battery 48 legs BATTERY DIGEST unchanged at ZK_THREADS 1/2/7;
kernel-bench before/after table; the spike's w/c matrix walls
re-run — target the E_c MAC gap <= 2x of K9-class [MODEL: the
counted 13.5x then lands ~5-8x measured].

### Lane EE — the aggregate zero-check + the mask transfer (wt-uperf3-ee) — RUST
OWNS: the aggregate section of ring/zc_range.rs (additive; DD owns
only the e_mac* hook lines), new uperf-s arms, "Agent EE status".
WHY: the spike ran ONE COLUMN per sumcheck; the design batches all
range columns of an instance into ONE aggregate (instance axis,
shared eq, claim-layer stacking — design memo §2.2), and the
zero-check ran UNMASKED (the O-4 obligation: the g-mask machinery
transfers per §2.6). GOAL: (1) the aggregate arm — claims equal the
per-column spike path bit-for-bit on the 48-leg matrix; counted
rounds/MACs vs per-column recorded; (2) the masked variant — values
equal unmasked, blinding verified by the existing mask battery
pattern. NOT this lane: the {0,1} alphabet (bit-granularity
commitment — a design ruling first).

### Lane FF — S4, the sqrt front end on the real rig (wt-uperf3-ff) — RUST, the 2-4 day de-risk
OWNS: a `uperf-t` bin section + NEW ring/two_tier.rs (nothing in
eval_proof.rs moves; read-only reuse), "Agent FF status". SCOPE:
U_PERF3_HEADLINE_ROUTES.md §4.2 VERBATIM — inner column
commitments, the challenge-fold w = sum c_i row_i, feed the
EXISTING recursion the sqrt-sized relation; on the real 12x512 act
group + a synthetic 2^23. ACCEPT (the memo's four): served claims
EQUAL the built opening's bit-for-bit at fixed seeds; >= 5x on the
prove-group-equivalent at >= 2^22; 1T verifier level-0 term
sub-second at the spike shape; the 8B two-tier planner gate green
(352,321,536 / 145,475,764 rings). Failing any -> the honest
fallback is recorded and the headline stays out of reach on this
line (a ruling-grade fact either way).

## ROUND 5 — STAGE A INTO THE REAL PASS + THE HEADLINE REDESIGN
## (opened 2026-08-28; Victor console: "try options 1 and 2 in
## parallel in two separate paths — worth trying to make it work but
## also important to keep moving forward")

Ground: rounds 3+4 merged, main fast-forwarded, all gates green.
Components validated: the E_c kernels (DD, 2.7x wall), the aggregate
zero-check + O-4 mask (EE, 13.3x rounds MAC-neutral), the S2 LogUp
(lane S), and the S4 verdict (FF: sound but slow as specified —
u-digit domination). The frozen pass remains the oracle; floors at
every commit: diff-battery, freeze-check 102 ok rows, uperf-s digest
3752cba4.., agg digest 4623..96, uperf-w 23/23.

### Lane GG — Stage A integration (wt-uperf3-gg) — RUST (the descent replacement in the real pass)
OWNS: NEW ring/stage_a.rs + a `uperf-a` bin section (+ its dispatch
line), read-only reuse of zc_range/ec_kernel/eval_proof/the pass
code; "Agent GG status". SPEC: U_PERF3_OPENING_LAYER_DESIGN.md §2
(2.2 batched sumchecks, 2.3 range facts, 2.4 the SiLU lookup, 2.5
the lattice opening, 2.6 soundness/O-obligations) — implement THE
MEMO on the real pass behind a selector, the frozen pass as oracle.
RUNGS: (0) skeleton; (1) THE OBJECT MAP (no proving): enumerate
every descent-pair family of the 12x512 pass and its Stage-A
replacement instance — a printed table; (2) ONE family differential
on real 3x16 (the zero-check serves the SAME claims to the opening
the descent served — S1's open-check is the stand-in pattern); (3)
all families, the composed 3x16 behind the selector: accept + the
recorded transcript delta; (4) O-4 masked + tamper battery; (5)
12x512 wall + peak RSS (the descent-pair memory should VANISH —
the 128 GB milestone's first half).

### Lane HH — the W-8(b)(c)(a) memory diet (wt-uperf3-hh) — RUST
OWNS: the named W-8 sites in the bin + eval_proof.rs additive
helpers; "Agent HH status". SPEC: U_PERF3_MVP8B_SCALING.md's W-8
row VERBATIM: (a) drop `lays` before the group proofs / int8-class
storage; (b) A_0 expanded per column block inside its three
consumers (the CRS is seed-expanded; ~25 s per full 8B expansion
[MODEL], paid ~3x); (c) flat i8/i16 deeper-witness store
(DigitCols exists). ACCEPT: statement + EVAL-PROOF digests
IDENTICAL at 3x16 and 12x64 (M125_EXPORT_DIR local bins);
/usr/bin/time -v RSS before/after per fix; floors green. The
target row: 12x512 under 14 GB CPU-side (T9's old goal) and the
counted 8B projection under 128 GB WITH lane GG (the milestone's
second half).

### Lane II — the sqrt front-end REDESIGN memo (orchestrator) — DESIGN
The S4 verdict's cause (u-digit recursion input 1.65M rings vs the
memo's ~19K) is specific enough to attack on paper. Memo:
docs/zkmatrix-poc/U_PERF3_S4_REDESIGN.md — the redesign space
(recursed u/v serving per FF's V-recursed planner row; u-digits
folded into lane EE's aggregate zero-check — they are range-shaped;
alternative tier geometries), each with COUNTS against the measured
S4 baseline, and the explicit bar a design must clear on paper
before any spike (>= 5x prove-group-equivalent at 2^22 in counted
form). No code. Victor rules on the winner (or none).

## Agent status sections (lanes append below; do not edit each other's)

## Agent R status (wt-uperf3-r)

STATE: OPEN (2026-08-18) — skeleton committed. Memo:
docs/zkmatrix-poc/U_PERF3_MVP8B_SCALING.md (sections 0-5 land one
commit each); scripts: scripts/m8b_int8_calibration.py +
scripts/m8b_export_ffn.py (NEW files; the m125 scripts are imported,
never edited). Nothing outside the lane's ownership is written.

DONE (2026-08-23, memo COMPLETE, all commits on uperf3-r):
- Section 1 (counted sizes 12x512 -> the 8B rungs) + the counter
  script m8b_scaling_model.py (`--check` reproduces the rig exactly)
  [previous session].
- Section 2 (what breaks: W-1..W-11 with file:line, smallest fixes,
  sizes; the checked-and-NOT-breaking record) — written last session,
  sanity-checked and committed this session.
- THE SCRIPTS (Grok's T12 gate): scripts/m8b_int8_calibration.py +
  scripts/m8b_export_ffn.py — streaming per-tensor safetensors reads
  + block-by-block numpy walk (< 4 GB RSS at the 7B shape by
  construction; 1.11 GB [MEASURED WSL-BOX] at 125M), hf (Mistral/
  Llama) + frugal arch adapters, frozen-family SiLU, per-tensor eW,
  the rig's exact export layout + the W-5 loader rows (model/dims/
  exps — verified inert to today's bf_sidecar), W-6/W-7 flags, shard
  sha256 identity, --weights-only re-check. Plus
  scripts/m8b_verify_125m.py: **12/12 checks PASS on this box** —
  streaming reader byte-equal on all 110 tensors; a synthetic SHARDED
  HF checkpoint through the full pipeline; the REAL 125M export with
  the committed m125 calibration: 36/36 weight digests BYTE-IDENTICAL
  to results/m125_ffn_export_wsl, 12/12 shifts identical, 0
  violations (X/z digests differ by the documented numpy-vs-mlx fp32
  drift; layer-0 X within 2 of 393,216 elements); the REAL 125M
  calibration: 108/108 exponents equal the committed table, val loss
  reproduced to 4 decimals (3.2287), variant A 0 violations.
  Evidence committed: results/m8b_test/m125_reexport/{digests.txt,
  manifest.json}. NOT exercised here (memo 4.3): a real 7B ckpt, the
  hf attention vs an external reference (transitively validated +
  the RUN task's decode gate), the tokenizer paths, true-7B RSS.
- Section 3 (memory/time per box: 32x512 needs W-8(a) even on the
  Mac — ~184 GB peak; the WSL box is the 1x16/3x16 dev rung only;
  honest walls [MODEL] Mac CPU ~15-30 min at 32x16, ~35-75 min at
  32x512, verify ~1-2 min; the weight group is 60-70% of every
  32-layer wall — lane T's target), Section 4 (data + scripts +
  validation record), Section 5 (plan M0-M8 + the VERBATIM T12 RUN
  task text for TASK_BOARD §3 — memo 5.2), Section 0.
DECISIONS NEEDED FROM VICTOR (memo 5.1 end): (1) T12 download
go-ahead (~17 GB network, ~30 GB Mac disk; Mistral-7B-v0.1 is
ungated, no token); (2) Mistral (default) vs Llama-3.1-8B (gated,
same dims/naming); (3) the W-6 SiLU-member freeze ruling IF the 7B
calibration flags one; (4) the Mac->WSL export-slice transport for
the 1x16 pre-rung; (5) Mac RAM/quiesced windows for the 32-layer
rungs (F2 coexistence).
NEXT (not this lane's round): orchestrator lifts memo 5.2 into
TASK_BOARD T12; M1 (W-5+W-4) is the first code rung.
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

## Agent T status (wt-uperf3-t)

STATE: LANDED (2026-08-23; skeleton 2026-08-18). Deliverable:
docs/zkmatrix-poc/U_PERF3_HEADLINE_ROUTES.md — COMPLETE, sections
0-5, one commit each on branch uperf3-t.

- [x] skeleton (headings, scope, labels)
- [x] Section 1 — the built pass in the family map + what scales x100
- [x] Section 2 — candidates (i)-(vi) with count tables
- [x] Section 3 — compositions and the honest reach
- [x] Section 4 — recommendation + the one spike
- [x] Section 5 — references
- [x] Section 0 — the paragraph

**Summary (the memo's Section 0, compressed).** The built pass is
the family-(c) architecture WITHOUT (c)'s serving move: the
LaBRADOR-form recursion opens the FULL ~500M-ring 8B witness, and
those full-witness terms scale x41-43 [COUNTED, lane R] — the 8B
floor (~2-4 min on a desktop board [MODEL]). **Ranked:** (1) the
opening re-architecture — Stage A + one-point front end + a
Greyhound/Hachi/RoKoko-class two-tier (sqrt/polylog) serving of each
group + per-model weight-group preprocessing: 8B ~20-40 s one board,
~6-13 s four boards [MODEL], verifier sub-second at 1T (T11 a'
closed without new crypto; W-2/W-3 dissolve; ~95 GB off the peak);
(2) route 3, the desktop-board port + quiesced ladder (4-6x, no
freeze); (3) folding across the 32 layers (LatticeFold+/Cyclo class)
AFTER MVP-1 as the memory/streaming tranche (peak ~4-8 GB, 8B fits
the WSL box; clock win overlaps 1); (4) Stage B's supplied-Psi_0
RETIRED by 1; (5) vSIS (Grand Danois) and the hash channel recorded,
not recommended. **THE ONE SPIKE: S4** — the sqrt front end on the
real 12x512 act group with the frozen opening as byte-oracle;
acceptance: claims equal, >= 5x prove-group-equivalent at >= 2^22,
sub-second 1T level-0, 8B two-tier exact-digit gate green; 2-4 days,
no freeze move. New [EXTERNAL] 2026 items cited with URLs: RoKoko
(ePrint 2026/575), Hachi (2026/156), Grand Danois (2026/1196), Cyclo
(2026/359, Eurocrypt 26), 2026/721, 2026/1127, 2026/551, the
Nethermind LatticeFold PoC — AGGREGATION_LITERATURE Section 9's "no
lattice PCS beats sqrt verify" and "no folding implementation" rows
are STALE.

## Agent U status (smooth experiment, orchestrator-launched 2026-08-24)

STATE: DONE (2026-08-24, same day). Deliverables all committed on
perf/zk-batch-optimizations: scripts/m8b_smooth_experiment.py (NEW; the
exact pow2 folds live in a TensorStore wrapper so weight_study/calibrate/
run_variant are the m8b module's own code verbatim; stats/plan/run
phases, split-alpha + caps + per-class margin knobs),
results/m8b_smooth_experiment_wsl_r{1,2,3,4}.json (the policy sweep),
results/m8b_smooth_experiment_wsl.json (canonical: body = r2 + rounds
index), docs/zkmatrix-poc/U_PERF3_M8B_SMOOTH_REPORT.md (the answer +
the ruling options). No frozen file touched; peak RSS 4.65 GB.

THE ANSWER [MEASURED WSL-BOX, seed 1337, 8+8 x 512]: per-channel
power-of-two rebalancing rescues FORMALITY only partially and QUALITY
not at all. (1) The folds are fp32-BIT-IDENTICAL at the full stack
(scales to 2^14); plain weights-only anchor reproduced to 0.0e+00.
(2) Violations 14,531 -> 4 (r2: alpha=0.5, margins x1/g1/u1/h2/z1) and
-> 3 (r3: capped fold, margins x2/g1/u1/h3/z1), the residue all in
l31's h class; 0 is plausibly one l31 margin bit away [PROJECTED].
(3) Chain loss: baseline +8.18, r1 (brief policy, alpha=1.0) +9.07,
r2 +8.45, r3 +8.70, r4 (margins-only control, NO fold) +7.86 nats —
every configuration is a destroyed model; r1's full migration alone
puts +8.97 into the folded per-tensor weights (eWd +2..+14 bits);
r4's uncompacted margins move the bulge h -> z (357,168 z violations,
25x baseline) — the fold IS load-bearing for formality, and the int8
budget is a waterbed. (4) Irreducible at per-tensor int8: the
unfoldable silu(g) factor (l1 eA=-1, bulk a ~1 level), the z spikes
(l1 379.7 vs p999 0.21), l31's ~14-bit u range; also the baseline
chain itself silently zeroes 4,147 massed l1 h channels below the u
step. (5) SiLU: the margined model needs 9 members, NONE frozen —
W-6 should wait for the spec ruling. FOR VICTOR'S RULING: option (a)
alone buys provable garbage; the measured option-(b) shape is
per-COLUMN w_down scales (floor_requant already takes per-column
shifts; absorbs the whole t-fold, deletes the migration damage) plus
wider a/h/z at the ~6 outlier layers; option (c) stays non-viable
(+7.9..+9.1 everywhere). Details: U_PERF3_M8B_SMOOTH_REPORT.md.

## Agent X status (wt-uperf3-x)

STATE: DONE (2026-08-25, round 2, design lane — documents only).
Deliverable: docs/zkmatrix-poc/U_PERF3_ATTENTION_STATEMENT_DESIGN.md
(859 lines, sections 0-6), the MVP-2 opening memo. Files touched:
the memo (NEW) + this status section; nothing else.

THE ANSWER, compressed:
- **No new claim family at P0/P2** (ATTENTION_INTEGER_SPEC.md's
  verdict re-confirmed against the as-built BF/BK/BG machinery):
  the full layer is more matmul instances, more zero-checks, more
  range/lookup columns, five public-weight wirings, ONE contract
  amendment (AM-1: the committed-divisor floor-division relation as
  a C1 chain form). C1-C6 discharged concretely: C2 head-axis/d-axis
  exponent vectors ride the BG layer-coefficient-MLE precedent (no
  new machinery); C5 members named with signatures (exp-neg per
  (eS, d_h); gelu-tanh; tanh-softcap only-if-private-logits;
  parametric range widths); C4 extended over attention classes
  (AM-10 subsumes AT-O1).
- **Headline multiples, full layer / FFN-only at T = 512** [COUNTED
  witness / MODEL prove]: 125M x3.56 witness, ~x5 prove as-built
  (~x2.5 Stage-A form) — 21.0 s -> ~105 s / ~55 s on the reference
  rig; Mistral-8B x1.72 witness, ~x2.0 prove — MVP-1's 35-75 min
  Mac -> ~1.2-2.5 h; Gemma-12B x1.72 over its own FFN (itself x1.53
  Mistral by rings) -> ~2-4 h Mac class. Crossover T where attention
  overtakes the FFN: ~163 / ~733 / ~1071 — 125M is attention-
  dominated at the contract T, the 8B class is not. Gemma's band
  masks linearize 40/48 layers beyond T = 1024 (a route-N argument
  beyond quantization).
- **Two new break items at 8B-class full layer** [COUNTED]:
  X-W12 — the WEIGHT group (436M rings Mistral / 666M Gemma) busts
  the 376.7M level-0 gate cap MVP-1 just cleared (split k = 2-3);
  the act group needs k ~ 5-7. And the descent leaves multiply
  x4.7-9.3 (score-volume range columns), pushing the as-built
  Mistral-full peak to ~260-300 GB — **over the Mac; Stage A is the
  memory-feasibility line for MVP-2 at 8B, not an optimization**
  (memo 4.5) — the range/lookup facts should land on lane S's
  zero-check machinery from the start (memo 3.3, needs Victor's
  sequencing ruling).
- **RoPE ruled**: route (a), proved elementwise rotations (spec
  form, spike-validated, fRo 7 holds everywhere); the fold-into-
  scores route (b) counted honestly (-4% extension, busts q31 at
  d_h >= 256, changes the declared function) and recorded, not
  chosen.
- **THE ONE SPIKE: X-S1** — one committed (head, row) softmax chain
  end to end through the REAL machinery (row max + attainment + exp
  LookupAt member + masked sum + division zero-check on one rolling
  transcript), REJECT battery AT-O8/O9, bit-equal vs the Python
  spike, plus a Stage-A equivalence leg; 2-4 days, additive, no
  freeze move.
- **Amendments proposed (never silently assumed)**: AM-1..AM-10
  (memo 6.3) — AM-1 (division relation into TARGET_CONTRACT §2 v3),
  AM-2/3 (C5 params key, C2 attention axes), AM-4 (rope table keyed
  by base; Gemma dual bases), AM-5 (QK-norm site + four-norm
  sandwich), AM-6 (band masks), AM-7 (k_eq_v), AM-8 (layer_scalar
  public constant), AM-9 (softcap = public post-processing when
  logits public), AM-10 (C4 over attention).
- Full-LLM artifact/tier: 125M ~2.8 MiB P0 as-built / ~1.0-1.3 MiB
  Stage-A; Mistral-full ~4.4-4.9 MB P0, ~5.5-6.5 MB P3 [MODEL] —
  outside every frozen FFN tier; tier-row proposal priced for the
  MVP-2 close (memo 4.4).

OPEN / FOR VICTOR (memo 5.2): the AM set with the C1-C6 ruling;
table freezes after X2; the Stage-A sequencing ruling; the full-LLM
tier row at MVP-2 close; lane Y to resolve the Gemma [ASSUMED]
facts (global-layer head map 8 x d_h 512, layer_scalar semantics,
rope bases, softcap site) before Gemma-full counts are promoted.
NOTE for the record: the ledger's Gemma "~8.7e12 MACs" is the
2-flops-per-MAC convention; in the pass's own 1x convention
(Mistral 2.89e12) the Gemma FFN is 4.35e12 = x1.51 (memo 3.1).

## Agent W status (wt-uperf3-w)

- 2026-08-25 SKELETON: worktree at 73adfb3 (branch uperf3-w). Lane =
  M1+M2 of the MVP plan (memo U_PERF3_MVP8B_SCALING.md Section 2 rows
  W-5 / W-4 / W-2, Section 5.1). Plan: (0) baseline captures BEFORE
  any edit (release build, diff-battery, freeze-check WSL form, 3x16
  full-profile digest via M125_EXPORT_DIR); (1) W-5 BfModel loader
  (dims/exps from the export digests.txt `00 model / 00 dims / NN
  exps` rows, selected by ZK_MODEL_EXPORT_DIR; env unset = the M125
  const path byte-unchanged); (2) W-4 acc classes from acc_bits(inner)
  = floor(log2(inner*127^2))+2 (125M must reproduce 25/26); (3) W-2
  plan_level -> Option, skip infeasible r candidates (freeze rows
  UAGB1-BG-1a/1b pin the 125M schedules); (4) new `uperf-w` battery
  (planner legs 44M/352M e0=1 + 36M/73M e0=2, acc_bits legs, BfModel
  parser legs incl. malformed rejection); (5) local m8b-format 125M
  re-export WITH bins (ckpt /home/victor/models/125m-best-adamw-
  val3.0816/model.safetensors, --arch frugal, out results/
  m8b_local_export gitignored bins) and the 1x16 + 3x16 rigs through
  ZK_MODEL_EXPORT_DIR = the first proof through the generalized
  loader. Box discipline: agent V full-tilt on this box; builds +
  short batteries + 3x16-class rigs only, no 12x512-class.

- 2026-08-25 DONE (all three rows landed; every wall below [WSL-BOX 1T
  NOISY-SHARED] — agent V full-tilt concurrent; no 12x512-class runs):
  * BASELINE (73adfb3 binary, before any edit): diff-battery green
    15.21s; freeze-check 98 ok rows then the EXPECTED WSL panic at the
    UAGB1-BF rows (cannot read layer00_X.bin), last ok row =
    "UAGB1-BL-1d pass schedules unmoved by the blind (+1728 rings):
    tierz L8 floor 1368 e4 (pins L8/1368/e4), bare L8 floor 939 e7
    (pins L8/939/e7)"; 3x16 full-profile via M125_EXPORT_DIR =
    ../results/m125_ffn_export_wsl: accept true, statement digest
    93a987002a7c4b60c3dfbfc62b7a4f0e5957d8ae2039014ff241e323285fb790,
    EVAL-PROOF DIGEST
    0ae9cdae66607239a80cc1f1dea36248370edadbe85214144aee7a5250d975be.
  * W-5 (a6b3c72): `BfModel { layers, t, d, f, e_w, exps, tag }`
    parsed once (OnceLock) from ZK_MODEL_EXPORT_DIR's digests.txt
    (`00 model` / `00 dims` / `NN exps` rows — the m8b export's W-5
    rows, inert to bf_sidecar; per-tensor/per-layer weight exponents
    REJECTED as unsupported), else the M125 consts. Threaded through
    bf_export_path (new env, precedence over M125_EXPORT_DIR),
    bf_load_layer (exps indexing + `- e_w` shifts + byte-size asserts
    at m.t*m.d etc. + t_rows==m.t digest gates), bf_derive_chain,
    bf_entry_shape, bf_entry_typing (t(e_w,..), e_x+e_w, e_h+e_w),
    bf_instances, the bf_layer_run matmul spec list, bk_pair_specs
    shapes, BgOpts/BkOpts defaults (layers/t from the model), the
    bg/bk/uperf-pc CLI arg defaults, wave-profile layer bound,
    bg_dummy_layer, the four bg_mle(.., d, ..) sites, and the
    synthetic-layer makers that feed bf_entry_shape machinery
    (uperf-d mm block, uperf_o_layers). NOT touched (125M-pinned by
    design): the freeze rows' literal (12, BF_T) calls +
    freeze_check_uagb1_bk's M125_EXP width derivation, m125-pass /
    statement-125m / bi wire-bench statement-m125 commands.
  * W-4 (same commit): `bf_acc_bits(inner) = floor(log2(inner*127^2))
    + 2` replaces q(25)/q(26) in bf_entry_typing — Gacc/Uacc =
    acc_bits(d), Dacc = acc_bits(f); bg_entry_class's l0 follows via
    derive_l0. 768->25, 2048->26 (identical to the constants —
    battery-asserted), 4096->27, 14336->29. bf_matmul_i64's i32 fast
    path needs no change (its inner*127^2 < 2^31 guard already
    admits 14336: 2.31e8).
  * W-2 (same commit): eval_proof.rs `plan_level -> Option<LevelPlan>`
    (None where :283-284 asserted; `adaptive_base_opt` returns None
    where adaptive_base's :235-238 assert fired — the pub
    adaptive_base keeps its panic contract as a wrapper), plan_schedule
    r-search skips None candidates (first-feasible-smallest rule
    unchanged where all candidates feasible), all-None => a clear
    panic naming n/e.
  * DEFAULT PATH BYTE-IDENTICAL (the differential floor), verified on
    the final binary (eca8e7e): freeze-check 98/98 ok rows diff-equal
    to baseline + the same expected BF panic; diff-battery green
    15.13s; 3x16 statement + EVAL-PROOF digests IDENTICAL to baseline
    (93a98700../0ae9cdae..).
  * uperf-w battery (6d713a0): 23/23 legs green — acc_bits 25/26/27/29
    + default-model typing/l0 consumer pins (13/14); planner legs
    [COUNTED]: n0 44M e0=1 r=2 DECLINES, schedule 9 levels level-0
    r=64 floor 936 e7; 352M e0=1 r=2 DECLINES, 10 levels r=64 floor
    936 e7; 36M e0=2 r=2 FEASIBLE, 9 levels r=56 floor 936 e7; 73M
    e0=2 r=2 DECLINES, 9 levels r=56 floor 948 e7 (pre-W-2 the 44M/
    352M/73M searches PANICKED); parser legs: synthetic good sidecar,
    6 malformed rejections, and the committed
    results/m8b_test/m125_reexport/digests.txt parses to exactly the
    M125 const model (tag frugal-125m, 512/768/2048/12, e_w -9,
    exps == M125_EXP).
  * NEW PATH END-TO-END (eca8e7e): local m8b-format 125M re-export
    with bins (scripts/m8b_export_ffn.py --arch frugal, ckpt
    125m-best-adamw-val3.0816, committed m125 calibration + shard
    tokens; 0 violations, peak RSS 0.41 GB [MEASURED]) into
    results/m8b_local_export (48 bins gitignored; digests.txt
    BYTE-IDENTICAL to lane R's committed m125_reexport fixture;
    weights 36/36 byte-identical to m125_ffn_export_wsl, shifts
    12/12, X 0/12 — the documented numpy-vs-wsl fp32 walk drift).
    Rigs through ZK_MODEL_EXPORT_DIR (the first proofs through the
    generalized loader): 1x16 accept TRUE (wall 9.3s, 749,000 B
    counted), 3x16 accept TRUE (wall 21.1s). STRONGEST LEG: both
    rungs are DIGEST-IDENTICAL to the M125_EXPORT_DIR path at the
    same shapes (1x16 statement 1c5421f6../EVAL-PROOF cf79b310..;
    3x16 93a98700../0ae9cdae.. both paths) — measured cause: the X
    drift starts at row 40 of layer 0 (2/375/26624 differing bytes in
    layers 0/1/2) and the first 16 X rows of layers 0-2 are
    byte-equal, so every byte the loader feeds these rungs is equal.
  * Commits: 6a47008 skeleton, a6b3c72 W-5+W-4+W-2, 6d713a0 battery,
    eca8e7e new-path evidence. OPEN: the 8B export itself (T12, Mac),
    M3 transport of a real 8B layer slice; W-6/W-7 per calibration;
    the m8b_local_export bins are local-only (re-derivable by the
    export command above).

## Agent Y status (wt-uperf3-y)

STATE: OPEN (2026-08-25) — skeleton committed. Lane: the Gemma 4
reference walker + gate prep (Round 2 Lane Y block above). Plan:
(1) modeling-source facts block (HF gemma4_unified, URL + line refs)
at the top of scripts/m8b_gemma4_walker.py; (2) the walker itself —
drop-in m8b_int8_calibration.Walker interface (four norms,
layer_scalar, QK-norm, hybrid sliding/global attention incl. k_eq_v
+ head-dim-512 global layers, GeGLU, softcap, tied head), streaming,
RSS < 4 GB; (3) --max-layers 2-4 smokes + the decode/factual gate
ONCE (>= 3/5 facts top-2); (4) scripts/m8b_gemma4_gelu_member.py —
gelu_pytorch_tanh table members in the frozen silu-v2 formula style,
digests only (C5 candidates, no manifest/lookup.rs edit); (5) the
one-command full C4 gate line, ready for the orchestrator to run
after agent V frees the box. NEW files only; smokes only this round.

DONE (2026-08-25, same session; commits on uperf3-y):
- FACTS PINNED (walker header F1-F8, transformers @ 9bb5f6a8 with
  file:line refs; raw sources read in full, not summarized): the
  norm sandwich order; layer_scalar multiplies the WHOLE stream
  after the ffn residual (checkpoint values are REAL data,
  0.0037-0.898 — a trained damping architecture, norms large to
  compensate); RMSNorm is plain `weight` (NOT Gemma-2/3's 1+w), eps
  inside the root; attn scaling = 1.0 (NO hd^-0.5 — the constant
  q/k_norm scalars carry it: 256x0.1221 = 512x0.0605 = same logit
  scale, sliding vs global); k_eq_v layers bind v to the RAW k_proj
  output (pre-k_norm, pre-rope); a scale-LESS v_norm RMSNorm on v at
  ALL layers (no weight tensor — that is why the scan missed it);
  proportional rope on full layers = 64 rotated pairs at
  full-hd-denominator exponents + 192 identity pairs (theta 1e6,
  partial 0.25), default rope theta 10000 on sliding; embed scale =
  bf16(sqrt(3840)) = 62.0 exactly (the HF downcast is intended);
  final softcap 30*tanh(logits/30); tied head.
- scripts/m8b_gemma4_walker.py: drop-in m8b Walker (same calibrate/
  weight_study run unchanged); embedding NEVER materialized (row
  seek-gather; head streamed in 8192-row chunks with running LSE +
  softcap). run_variant/make_int8_ffn/make_wonly_ffn are m8b copies
  with ONLY the activation swapped to gelu_tanh (m8b hard-codes SiLU
  in the fp reference). scripts/m8b_gemma4_diag.py: per-layer trace
  + logit lens + fact ablations.
- SMOKE [NOISY-SHARED]: 6-layer (5 sliding + 1 full) cal path green,
  peak RSS 2.41 GB; weights land eW -9/-10, sat@e = 0 everywhere.
- DECODE/FACTUAL GATE [MEASURED WSL-BOX, 48 layers]: plain-text
  probe FAILS 0/5 (ranks 2866-9814; greedy '00000000') — NOT a bug:
  stream healthy at every layer, and generation_config
  suppress_tokens [258882, 258883] proves the real model also tops
  these. The -it- checkpoint needs its turn structure: with the
  canonical hub chat_template wrapping (<|turn>/<turn|>/<|channel>,
  ids 105/106/100/101; partial sentence prefilled into the model
  turn) the gate is 5/5 AT RANK 0 (' Au'/' oxygen'/' Shakespeare'/
  ' Jupiter' sharp; '2 + 2 =' degenerates to the space token under
  digit-splitting). Peak RSS 1.63-1.65 GB per 48-layer pass.
  WALKER VALIDATED; --template is the gate mode for it-checkpoints.
- scripts/m8b_gemma4_gelu_member.py: gelu-tanh-int8-table-v2 family
  (exact silu-v2 formula/digest layout, silu pins self-checked on
  import); 13 candidate digests + 256-byte tables committed at
  results/m8b_gemma4_gelu_members/. Smoke-calibrated members so far:
  (-1,-1) 6e5d28a8…, (-3,-3) cb799cb4… — C5 candidates, registry
  EMPTY until the ruling; no manifest/lookup.rs touched.
- THE FULL C4 GATE (one command, orchestrator schedules after agent
  V frees the box; ~hours [MODEL] — the 262k-vocab head streams
  dominate the loss passes; peak ~4.5-5.5 GB [MODEL, T12 analogy —
  the B=8 collect batch dominates]):
    python3 scripts/m8b_gemma4_walker.py \
      --text /home/victor/models/fineweb-edu/sample_text.txt \
      --out-json results/m8b_gemma4_calibration.json
  NOTE for the record: the calibration/loss windows are plain
  fineweb text — for the -it- model both the bf16 reference and the
  int8 chain sit in the same (slightly off-) distribution, so the
  C4 delta stays meaningful; the smoke's early-layer activation
  ranges (X absmax 165.9 at l0, eH 5/4 at l0/l1) are the numbers to
  watch in the full verdict.

## Agent V status (b-lite pricing, orchestrator-launched 2026-08-24)

STATE: HANDED OFF 2026-08-25 (orchestrator directive: no further runs
from this session; the orchestrator executes the full passes with the
committed script). Code + smokes COMPLETE and green; the full-stack
pricing passes NOT yet run. Commits: 73adfb3 (the blite phase),
then the p999-floor commit (+ results/m8b_smooth_stats.npz, the
three SMOKE JSONs). The blite report doc
(docs/zkmatrix-poc/U_PERF3_M8B_BLITE_REPORT.md) is NOT yet written —
it needs the full-pass numbers.

**1. The verified per-column-shift claim (the brief's first task).**
Agent U's sentence "m125.floor_requant already accepts per-column
shifts" is TRUE of the Python simulator and FALSE of everything the
prover actually runs:
- scripts/m125_int8_calibration.py:139-154 — floor_requant's docstring
  says "`shift` may be a scalar or a per-column vector" and the code
  vectorizes; :481/:482/:501 use vector shifts, fed by the m125
  study's per-OUTPUT-channel weight variant (quantize_weights
  wgran="channel", :431-455). NOTE: that variant is per-output-channel
  W scales (row of W = output column) — NOT the per-INPUT-column
  w_down scales mechanism 1 needs (those force alignment, below).
- The RIG fixes ONE scalar shift per requant site: bf_floor_requant
  (acc: &[i64], shift: u32) at zkmatrix-rs/src/bin/ring_matmul.rs:24623;
  BfLayer.shifts is a 4-tuple of scalars, asserted against the export
  sidecar's four scalars per layer (:24656-24666); the export scripts
  write scalars only (scripts/m8b_export_ffn.py:251-271, :308;
  m125_export_ffn.py:202-211).
- The STATEMENT fixes one scale per committed entry: TypingV4
  .scale_exp is a single i32 (src/manifest.rs:625-635); class caps
  CLS_ACT8 bits <= 8, CLS_ACC <= 31, CLS_REM <= 16 (:666-681).
So the true (b)-lite delta = vector shifts in the engine + per-column
scale metadata in the statement (a manifest/v5 move — Victor-gated
file) + the alignment story at the down edge + REM/ACC class-cap
moves (measured needs below).

**2. What the committed script implements (--phase blite).** Per-
column pow2 requant scales at u/h/z + per-column w_down, widened SiLU
classes, exact-integer simulation, the module's own verdict counters:
- ucols/hcols/zcols: per-column eUp_k/eH_k (f-vectors), eZ_j
  (d-vector); requant shifts become public per-column vectors. u and z
  requant AFTER their accumulators per OUTPUT column and h is
  elementwise — NO alignment cost at those three sites.
- wdcols: per-column w_down scales ecol_k. THE ONE ALIGNMENT SITE:
  down products sit at per-column scales eH_k + ecol_k; the sim
  carries Wd8 * 2^a_k exactly (a_k = eH_k + ecol_k - P_base) and
  reports the honest acc bound 127^2 * sum_k 2^a_k + 8-bit tier
  counts per layer (the engine cost accounting).
- a16=/g16= layer lists: SiLU widened to int16 range (Qa 32767)
  and/or domain (Qg 32767, a 65536-row table in the engine), v2
  round_half_up formula at the wider clamp — a NEW family, inventory
  recorded per layer.
- The t-fold is RETIRED in this phase (--t-cap 0 asserted): per-column
  eUp_k/eH_k subsume it exactly (p_k = nh_k + wcol_k is
  fold-invariant); the s-fold (X-side) is KEPT (s_cap 3, preprocessing,
  exact). Per-tensor scale rows are NOT re-walked: derived exactly
  from the baseline record + the cal-stats npz + a stream over folded
  wg/wu, ASSERTED equal to a real m8b.calibrate walk
  (--validate-calibrate; green at 2 and 4 layers, incl. s != 0).
- Per-column p999 robustness floor (second commit): a column's
  exponent never sits below the tensor's p999 exponent — sleepy cal
  columns get free val headroom, and the alignment spread compresses
  from the bottom. Token `nofloor` disables.
- --equiv-check: the blite chain with everything off is BIT-EXACT vs
  m8b.run_variant (asserted green: loss 10.4954427558 equal, same
  violations, 2-layer smoke).

**3. Smoke results [SMOKE 4-layer TRUNCATED, WSL-BOX — results are
NOT the model's; JSONs in results/m8b_blite_SMOKE*.json].**
- margin-1 percol (mu/mh/mz=1, no floor): 2,451 violations —
  per-column cal absmax is a TIGHT fit, val fluctuates ~2x; margins
  are the knob.
- floored percol (mu/mh/mz=2 + p999 floor): 857 violations, ALL
  remaining at l0 (836 h + 21 u; layers 1-3 fully clean, z clean);
  truncated-stack chain delta +0.0097 vs the fp ref (margin-1 smoke:
  +0.1399). l0 likely needs mh=3 or a16=0.
- Engine accounting at the smoke: max align 18-21, honest down-acc
  34-37 bits at l0/l1 (over the 31-bit CLS_ACC/i32-fast-path line →
  2-3 tiers), max sh_z 24-27 (over the 16-bit CLS_REM cap).
- Design probes from the cal stats [MEASURED, full-stack stats]:
  gate-path bulk levels at int8: l1 = 1.3 (destroyed), l0 = 4.4,
  l2/l30/l31 = 10-11, rest 20-40 → g16 candidates {0,1,2,30,31},
  l1 mandatory. u absmax/p999: l1 = 74.6, l31 = 10.9, l0 = 9.3, rest
  3-6. z spikes are PERVASIVE (25 of 32 layers ratio > 8) → per-column
  z, not per-layer widening. Bulk-h levels at the Hadamard product
  scale with a8: 60-240 at most layers (per-column sh_h recovers them;
  a16 NOT needed everywhere), exceptions l1 (0.29), l0 (21.9),
  l30/l31 (44-57).

**4. THE ROUND-1 COMMAND (for the orchestrator; ~40 min: 2 verdict
walks, no calibrate walk needed — derivation is assert-guarded):**
  python3 scripts/m8b_smooth_experiment.py --phase blite \
    --s-cap 3 --t-cap 0 --stats-npz results/m8b_smooth_stats.npz \
    --bl-variant "name=percol,ucols,hcols,zcols,wdcols,mx=2,mg=1,mu=2,mh=2,mz=2" \
    --bl-variant "name=percol_g16,ucols,hcols,zcols,wdcols,g16=0;1;2;30;31,mx=2,mg=1,mu=2,mh=2,mz=2" \
    --bl-out results/m8b_blite_experiment_wsl.json
(run from the repo root; label [WSL-BOX NT] or NOISY-SHARED per top.)
Round 2 (read round 1 first): margin/floor repair of any residual
violation class (mh=3 or a16=0 for l0-class residue); then the TRIM
runs for the smallest surface: (a) drop wdcols (per-tensor eWd — the
align spread then comes from eH_k alone), (b) g16 list trimmed to
{1} or {0,1}, (c) mx=1 quality check. Round 3: the record pass of the
chosen config with --bl-wonly. If percol_g16 still misses <= +0.3
nats: a16=all is the next escalation, then u16/h16 at l1 only.
Expected shape [PROJECTED, not measured]: percol alone lands mid
(l1's silu path still broken — bulk gate 1.3 levels); percol_g16 is
the one with a shot at <= +0.3.

**5. The engine bill so far (counted; the full pass refines).**
(a) vector requant shifts u/h/z + per-column scale vectors as
statement metadata (~3f + d i8 exponents/layer ≈ 47 KB/layer public,
hashed into the model identity) — manifest.rs v5 (Victor-gated);
(b) the down-edge alignment: committed aligned w_down (per-column
range classes 127 * 2^a_k) with 8-bit tiers — most layers 1-2 tiers,
l1 = 3 [SMOKE-counted; full pass gives the real per-layer tier
table]; CLS_ACC cap 31 holds per tier, NOT for a single flat acc at
l0/l1-class layers (honest 34-37 bits); (c) CLS_REM cap 16 -> ~28
(more q46 bit planes at the wide-shift sites); (d) g16 layers: 65536-
row tables at ~5 layers max (K9 cap 2^25 unaffected; lookup transcript
grows — count vs LKP-7 at write-up); (e) W-4/W-1 items unchanged in
kind, W-4's acc_bits formula gains the per-tier form. Est. lane-days
at write-up after the measured pass.

**6. Open items.** (i) Full-stack passes + results/
m8b_blite_experiment_wsl.json + U_PERF3_M8B_BLITE_REPORT.md §0-§4 —
all blocked on the round-1 numbers; (ii) the l0 residue policy;
(iii) whether ucols can drop from the smallest surface (u cleaned at
margin 1 per-tensor in agent U's r4 — but per-tensor eUp costs l1/l31
bulk-u resolution; measure the trim); (iv) the SiLU member/W-6 story
under b-lite: a8 layers still need ~7-9 unfrozen (eGate,eA) members
(margin-dependent), g16 layers need the NEW wide family — both wait
on the ruling; (v) wall/RSS labels for the record pass.

## Agent Z status (Gemma z-fix measurement, launched 2026-08-26)

STATE: HANDED OFF 2026-08-26 (orchestrator directive after the smoke:
no further process launches from this session; the orchestrator runs
the full record pass `python3 scripts/m8b_gemma4_zfix.py --run
equiv,Z1,Z2` and writes the blite report with its numbers). Commits:
bf31d70 (scripts/m8b_gemma4_zfix.py), this one (smoke JSON + zcol
stats npz + this section).

**1. The platform (bf31d70).** NEW file scripts/m8b_gemma4_zfix.py;
the validated walker (m8b_gemma4_walker.py) is imported UNCHANGED —
zero risk to the decode/probe gates. Per-tensor scales/stats/ref
numbers are REUSED verbatim from results/m8b_gemma4_calibration.json
(same seed 1337 / windows / walker => deltas comparable to +17.6029);
the only new calibration data is the per-column z absmax over the cal
windows (fp collect walk, cached at results/m8b_gemma4_zcol_stats.npz
— 3-layer slice so far; the full run re-collects 48 and re-caches).
Derivation is agent V's zcols semantics exactly: eZ_j =
pow2ceil(absmax_j) + mz, floored at the TENSOR z-p999 exponent,
clamped at P_base = eH + eWd (shift >= 0, fixups counted).
Chain = g4.make_int8_ffn's inner loop line-for-line with the one
surgical delta at the z requant (vector shift via m125.floor_requant's
own vector path; exact integers in f64 throughout; z_out = yz * 2^eZ_j
exact in fp32). Variants: equiv (mechanism off — the equivalence
gate), Z1 (percol all layers), Z2 (percol at hot {2,9,21,23,24,26}
only), Z3 (int16 z, Qz 32767, per-tensor, hot layers — run only if Z1
leaves a material residual delta). Incremental JSON writes per stage;
record file results/m8b_gemma4_zfix_wsl.json.

**2. Smoke results [SMOKE 3-layer TRUNCATED, WSL-BOX — results are
NOT the model's; results/m8b_gemma4_zfix_SMOKE.json; exit 0, ~6 min
total, walk-only (no head/loss)].**
- EQUIVALENCE GATE: PASS — the per-tensor path reproduces the
  baseline per-layer counters (viol dicts, acc floats, rel_ffn_err)
  BIT-IDENTICALLY at layers 0-2, zero mismatches. The full-pass gate
  additionally asserts the loss float bit-equal.
- The mechanism at l2 (the 98,650-violation layer), per-column eZ all
  layers, p999 floor on: mz=0 -> 126,567 z-viols at l2 (WORSE than
  per-tensor: margin-less per-column ranges are tighter than the
  tensor ceiling), mz=1 -> 22,899, **mz=2 -> 9** (l0/l1 z fully
  clean; only leftovers = l1's known X_clip 1 + the 9). mz=2 is the
  right primary margin (matches agent V's round-1 Mistral config).
- Engine/statement at the smoke: max sh_z 9 (mz=2) — comfortably
  UNDER the 16-bit CLS_REM cap (unlike Mistral's 24-27; eWd is
  uniformly -10 and Gemma's z spread is small, absmax/p999 1.5-15) —
  the REM-cap-raise does NOT apply to the Gemma z fix on this
  evidence. Zero shift fixups. Statement bytes: 3840 i8/layer
  (d-vector) => Z1 = 184,320 B, Z2 = 23,040 B.
- THE HONEST EARLY WARNING: matched-input rel_ffn_err at l2 stays
  ~3.0-3.8 under per-column z (baseline 3.10; mz=2 gives 3.77 — the
  baseline's clipping was CAPPING upstream noise, the fix uncaps it).
  The l2 FFN error is NOT z-clipping-dominated; it sits upstream at
  the h-site RESOLUTION (h absmax/p999 = 43 at l2, eH=1 => bulk h at
  ~2 quant levels — the Mistral disease at Gemma's hot layers; the
  hot six all have h ratio 43-240). The z fix removes the hard
  range-fact failure; whether the DELTA rescues is exactly what the
  full pass measures — if it does not, the next mechanism is percol
  sh_h (per-column eH_k) at the hot layers, NOT more z.
- Baseline caveat for reading downstream numbers: baseline
  rel_ffn_err at layers > 2 is measured on the post-l2-blowup stream;
  Z1/Z2's per-layer rel errs on the healthy stream are the real
  diagnostic of where residual error lives.

**3. What the full pass produces (orchestrator, in flight).**
results/m8b_gemma4_zfix_wsl.json: equiv (gate incl. bit-equal loss
24.8395916385...), Z1/Z2 each with total/per-class/per-layer
violations, loss + delta_vs_ref (ref 7.236668249862625), per-layer
rel_ffn_err, eZ/sh histograms, max sh_z, statement bytes, wall/RSS.
Expected shapes [MODEL, from the smoke]: Z1/Z2 z-residue O(10-100)
elements at mz=2 (not 0 — C4(i) then needs either mz=3 at the residue
layers or the +1-margin C6 move; l1 X_clip 1 + l12 up 14 persist
regardless, they are X/up-site margin items outside this lane's
question). Z3 decision rule: run only if Z1's delta stays materially
above the +0.10-nats C4 budget region — int16-z at hot layers
disambiguates "z-site precision" from "upstream h-resolution" (if
int16 z ALSO fails to rescue, the residual delta is upstream and the
answer to THE QUESTION is no-at-z-alone).

**4. Report notes for U_PERF3_M8B_BLITE_REPORT.md (not started, per
directive — structure for whoever writes it).** §0 the answer: one
sentence per checkpoint — Mistral R+ dead on quality (percol +7.63,
percol_g16 +7.32 vs baseline +8.18, results/
m8b_blite_experiment_wsl.json); Gemma z-fix = Z1/Z2 delta vs +17.6029
(fill from the record JSON), with the C4(i) residue status. §1
mechanisms + bills: V's ledger §5 accounting (Mistral: REM 16->~28,
align 18-21, down-acc 34-37, 18 multi-tier layers, ~47 KB/layer
statement) vs the z-fix bill (post-accumulator, NO alignment, acc
bound unchanged, max sh_z 9 => REM cap UNTOUCHED, 3.75 KB/layer at 6
layers = 22.5 KB total for Z2). §2 tables: Mistral percol/percol_g16
(viols by class, delta) x Gemma equiv/Z1/Z2(/Z3) (same columns +
sh/exp histograms). §3 contract reading: C2 percol-eZ is the cheapest
real mechanism and Gemma needs ONLY it (if delta rescues) — checkpoint
strategy N+small-bridge beats R+ everywhere; margins are C6 statement
data (mz=2 load-bearing: 0->2 bits swings l2 126,567->9). §4 open:
(i) the ~10-element z residue policy (mz=3 local vs accept), (ii) l1
X_clip/l12 up margin bits, (iii) percol sh_h at hot layers if quality
does not rescue, (iv) quiesced wall-clock labels (box shared, F2
training on the Mac; WSL numbers are NT-labeled), (v) C5: 6 GELU
members await the freeze ruling.

## Orchestrator note 2026-08-26 (night): the m125 cross-layer weight structure [MEASURED WSL-BOX]

Victor's conjecture (console): the 125M architecture is simpler and
its layer weights "should be correlated". Measured on the committed
m125_ffn_export_wsl int8 planes (12 layers x WgT/WuT/WdT):

- **Elementwise cross-layer correlation: ~ZERO.** mean |r| 0.0006-
  0.004, max |r| 0.0096 over all 66 layer pairs per family; top-64
  right-singular-subspace overlap 0.093-0.097 vs 0.080 random
  baseline. The 12 blocks are statistically INDEPENDENT — no
  cross-layer commitment compression is available (each layer's
  weights need their own commitment). frugal-lm model.py confirms:
  standard pre-norm blocks, no sharing by construction.
- **But the layers are IDENTICALLY DISTRIBUTED to a striking
  degree**: absmax in [64, 67] and std in [15.3, 21.8] (int8 units)
  across ALL 36 tensors — one weight class, ONE uniform e_w = -9
  (this uniformity is where the rig's |w| <= 64 digit bound and the
  single-exponent statement rows come from). Contrast Mistral-7B:
  per-tensor weight exponents spanning 4 binades ([-11, -8]).
- **The "does not suffer these problems" half is TRUE and was
  already measured**: m125 variant-A int8 = 0 violations (lane R),
  no widening/margins/percol needed — the entire v3 qualification
  machinery exists only for the >= 7B off-the-shelf checkpoints'
  emergent outliers.
- **Caveat for the roadmap**: frugal-lm's plan (docs/PLAN.md §3) is
  the standard consensus recipe to ~1.2B — benignness at 125M is a
  SCALE property, not an architectural safeguard; the outlier
  phenomenon emerges ~6.7B+ in standard transformers, so the
  1.2B-ladder ceiling likely stays benign, but a frugal 8B would
  need that VERIFIED (or QAT-style interventions) before assuming
  the simple statement. The frugal ladder keeps the simple
  v2-class statement; v3 remains the off-the-shelf qualification
  path.

FOLLOW-UP (same night — Victor: the local main is the OLD llama
recipe; the EULER architecture is the intended one and should have
high layer-to-layer correlation): CONFIRMED on frugal-lm's
`origin/euler-growth-and-10b-roadmap` branch (local main was 3
commits behind it). The Euler program: `EulerBlock` x_{k+1} = x_k +
s*f_k(x_k), s = 1/L — a depth-time ODE discretization; growth ops
duplicate/interpolate/identity/merge (EULER_DEPTH_SCALING.md);
PATH_TO_10B.md is the scale roadmap. The correlation claim, AS
MEASURED THERE:
- The TOY Euler transformer: adjacent-block QKV kernels differ
  ~0.04-0.05% relative — depthwise weight function near CONSTANT
  (extreme layer correlation, no regularizer needed).
- **The trained 360m-euler-merged-qkv run: weight smoothness is
  NOT there** — median adjacent rel diff 1.4135 (~sqrt(2) = the
  independent-blocks value), adjacent cos at chance even after
  neuron alignment, confirmed not an init artifact; the V1 verdict
  DROPPED the interpolate growth arm. State smoothness decays with
  training (adjacent-increment cos 0.26 -> 0.18; capacity-bound
  signal). Same verdict as our m125 measurement: today's TRAINED
  checkpoints (both recipes) sit at the independent-layers value.
- The branch's own named remedies (wired, untested): shared-block
  init and trajectory_regularization > 0 — "would unlock
  interpolation later."
PROOF-SIDE STAKE (why the proof project should care that a future
pretrain induces weight smoothness): small adjacent weight deltas
=> commit layer 0 + per-layer DELTA planes with tight magnitude
bounds (narrow witness classes, cheap commitments); genuinely
interpolable theta(t) => commit K anchor layers and DERIVE the rest
by public linear interpolation (the rig's existing linear
machinery) — an L/K commitment compression. At the toy's 0.05%
level the deltas are ~1-2 int8 counts. Counted design memo = a
future lane item once a smoothness-regularized checkpoint exists;
the joint experiment (frugal side): a ladder run with
trajectory_regularization > 0 / shared init, then re-measure.
## Agent AA status (wt-uperf3-aa, round 3)

STATE: IN FLIGHT (2026-08-26). Landed so far (one commit each):
- scripts/m8b_margins.py: the v3 widened exact chain with
  REGISTRY-EXACT int16-out tables (CLAMPED +/-32767 — matches lane
  BB's freeze convention BY CONSTRUCTION; clamp-row index hits
  tracked per run), greedy +1-bit margin iteration, --tables C5
  record mode, and the shared v3 export machinery (make_v3_ffn /
  v3_witness_walk / write_v3_sidecar) both exporters call.
- **MISTRAL MARGINS TO ZERO** [MEASURED WSL-BOX NT]: round 0
  reproduces the ruling verdict (+0.2157 / 32 viols, clamp-hits 0);
  2 margin rounds -> **0 violations at 12 margin bits** (gate
  l3/4/14/15, u l7, h l16/26/27/31, z l20/22, X l31; rounds 1-2
  surfaced 5 second-order viols — gate l14, z l20/22 — killed by the
  same rule). Quality cost of margins **-0.0007 nats** (net
  IMPROVE); final delta +0.2150 vs ref. clamp-hits 3 elements at the
  final set. results/m8b_margins_mistral_wsl.json.
- The v3 EXPORT PROFILE: additive --profile v3 in m8b_export_ffn.py
  (layout DOC OF RECORD in its header; v2 default re-export
  BYTE-IDENTICAL to the committed m125_reexport digests) + additive
  --export-v3 in m8b_gemma4_walker.py (same shared code paths — the
  layout cannot fork). 125M v3 validation: 0 viols, weight +
  layer-0-X digests byte-match v2. REAL Mistral-7B v3 export DONE:
  0 violations under the margin set, negative sh_u = -1 exercises
  the exact-up-scaling path; digests + manifest committed, 6.8G bins
  gitignored.
- BB RECONCILE COMPLETE: all 15 frozen int16out members (9 silu + 6
  gelu, uperf3-bb lookup.rs 90415d0) regenerate BYTE-IDENTICAL and
  DIGEST-IDENTICAL from m8b_margins.py's generator (same function
  names, rounding strings, clamp, spec-header JSON). The
  margin-adjusted Mistral member set needs NO new members — the gate
  margins map l3/4 -> (-4,-13) and l14/15 -> (-3,-12), both already
  frozen; (-5,-13) becomes unused post-margin (harmless).
- **GEMMA MARGINS TO ZERO [MEASURED WSL-BOX NT|NOISY-SHARED] — WITH
  A FLAG**: round 0 reproduces the ruling verdict bit-for-print
  (+0.0353 / 14 viols: X_clip 4 at l1/10/12/21, z 5 at l5, gate 3
  at l34, h 2 at l39/43). ONE margin round -> 0 violations at just
  8 bits (+1 bit at exactly those 8 (layer, site) cells; clamp-hits
  2). **BUT the margin quality cost is +0.1082 nats** (final delta
  +0.1436 vs ref — ABOVE the +0.1356 weights-only floor), where
  Mistral's margin set was FREE (-0.0007). The script's own
  \>0.05-nat gate fired ("REPORT THIS").
  results/m8b_margins_gemma_wsl.json, peak RSS 3.71 GB.
- DECOMPOSITION IN FLIGHT (queued on the heavy lock behind CC's
  widen pass): scripts/m8b_margins_decomp.py — one verdict walk
  with the four X-site bits alone, one with the z/gate/h bits
  alone, same ref + windows. Hypothesis: the X margins carry the
  cost (X stays INT8 in the v3 stack — +1 exponent bit halves the
  whole X plane's resolution at those layers; z/gate/h margins land
  on int16 planes with resolution to spare). Mechanism smoke green.
  Marker: results/m8b_margins_decomp.done.
- **DECOMPOSITION LANDED [MEASURED WSL-BOX NT] — the hypothesis is
  REFUTED, and the answer is better**: the four X-site bits alone
  cost **+0.0011** nats (FREE — int8-X resolution was NOT the
  mechanism); the z/gate/h bits alone cost **+0.1317** (sum
  +0.1329 vs full +0.1082, interaction gap -0.0247 — sane). The
  cost lives on the int16 planes' margins, almost certainly
  because z/h margins coarsen EARLY/MID-stream planes that feed
  everything downstream (z l5!) and the gate margin swaps the
  activation-table member to a coarser input grid at l34.
  Residuals: with X-margins only, 7 violating ELEMENTS remain
  (gate 1, z 6); with z/gate/h-margins only, 4 remain (X_clip 2,
  z 2) — the chain interacts, neither subset reproduces round 0's
  14. results/m8b_margins_gemma_decomp.json.
- **RECOMMENDED POLICY for the ruling (the report's line): take the
  X margins (free, kills X_clip), do NOT take z/gate/h margins;
  treat the ~7 residual elements with lane Z's measured per-column
  eZ mechanism (C2 percol, ~3.75 KB/layer at the residue layers —
  the zfix pass already measured it killing z-residues cheaply) or
  an accept-N-residues statement row.** Mistral's margin set and
  export are unaffected (its margins were free).
- **RULING (Victor, console 2026-08-26 night): percol-eZ adopted as
  the z-residue mechanism.** Implemented as --z-percol in
  m8b_margins.py (per-column eZ16 floored at the per-tensor base —
  columns only WIDEN; vector sh_z through floor_requant's
  per-channel form; z viols route to the percol set with escalating
  mz; e_sha per layer pins the vector for the export reconcile).
- **PERCOL POLICY RUN [MEASURED WSL-BOX NT]: ZERO violations, and
  percol-z is FREE as designed** (l5: 19/3840 cols widened, max +2
  bits, identical e_sha both rounds; the forced-path check measured
  its loss effect at 7e-6). Converged margin set: X x4 (free) +
  gate l34 + h l30/39/43 (l30 is a NEW second-order h viol that
  surfaced in round 1). **BUT final delta +0.1049 — the gate/h
  margin bits carry +0.0696 of quality cost.** The z bit was NOT
  the whole story: gate/h bits are the remaining cost carriers.
  results/m8b_margins_gemma_percol_wsl.json.
- MECHANISM OPTIONS for gate/h (why percol does NOT port there):
  gate is the table INDEX (per-column eGate = per-column C5 members
  — blocked); h feeds the down MATMUL (per-column e_h = the R+
  input-alignment bill the v3 stack exists to avoid). So the
  choice is localized margins (+0.0696) vs an accept-N statement
  row for ~6 elements (gate 3 at l34, h 2-3 at l30/39/43).
- **POLICY DECOMPOSITION LANDED [MEASURED WSL-BOX NT] — the split
  FLIPPED**: base (X margins + percol-z) costs **+0.0868**; the
  gate bit is FREE (-0.0079) and the h bits are FREE (-0.0000)
  (additivity gap -0.0092, noise-scale). **The cost carrier is
  percol-z itself, not gate/h.** Reconciled ranking of every z
  mechanism at l5: whole-plane z margin bit +0.13 > percol mz=2
  +0.087 > (untested: percol mz=0, accept-N). The z site at l5 is
  intrinsically expensive to COARSEN: the 19 widened columns are
  the outlier channels, mz=2 over-widens them 4x past their
  calibrated need, and the coarsening propagates 43 layers.
  results/m8b_margins_gemma_policy_decomp.json.
- HONEST CORRECTION to the "free as designed" line above: the
  forced-path check (7e-6) ran on a 6-layer TRUNCATED stack where
  l5 is TERMINAL — structurally blind to downstream propagation.
  The percol mechanism note stands (columns only widen), but
  widening hot columns is not free when 43 layers consume them.
- **mz=0 PERCOL RUN LANDED [MEASURED WSL-BOX NT] — the decisive
  history (results/m8b_margins_gemma_percol_mz0_wsl.json)**:
  * Round 1 (THE MONEY ROW): free margins (X x4 + gate l34 + h
    l39/43, 7 bits) + percol l5 at mz=0 — which is a NO-OP (0
    columns widened: the cal-window column absmax already fits the
    per-tensor base!) — **delta +0.0380** (= round-0 +0.0353 +
    noise), 7 z-element viols (6 at l5, 1 at l37), clamp-hits 1.
  * Round 2: l5 escalated to mz=1 (9 cols, +1 bit) — kills l5's
    viols at **+0.037 quality cost** (7.2746 -> 7.3118) and a NEW
    single z viol pops at l25. Round 3: l25's mz=0 percol is a
    no-op -> RESIDUAL-1 at +0.0751. WHACK-A-MOLE CONFIRMED.
  * READING: the z residues are ~7 ROAMING single val-tail
    elements — NOT stable hot columns (cal stats do not predict
    them; percol mz=0 is literally the identity). Every RANGE
    mechanism that chases them coarsens live channels and pays;
    CLAMPING them is quality-free (the chain already clamps —
    +0.0380 IS the clamp policy's measured quality).
- **THE MEASURED MENU (Gemma, complete)**:
  | policy | delta | unexplained viols |
  | free margins + CLAMP at z | +0.0380 | 0 (clamp relation total) |
  | + percol l5 mz=1 | +0.0751 | 1 roaming |
  | full percol mz=2 | +0.1049 | 0 |
  | whole-plane z margin | +0.1082 | 0 |
  RECOMMENDATION: free margins + a CLAMPED-REQUANT relation at the
  z site (the C5 tables' own D1 +-32767 clamp convention extended
  to the z requant edge; statement-side: a per-element selector —
  in-range branch = the normal remainder+range relation, clamped
  branch = acc-beyond-threshold + y pinned at +-32767; count bound
  provable by selector-column sum). BB prices the selector gadget
  vs the percol statement rows (both are new rungs; clamp is 3x
  better on quality and has no convergence risk). Mistral already
  lives under D1 clamp semantics at the TABLE site (clamp-hits 3).
- **RULING (Victor, console 2026-08-27): CLAMP-AT-Z ADOPTED** — the
  z requant relation is CLAMPED (D1 extended); free margins (7
  bits) carry the other sites; NO percol in the adopted statement
  (the percol machinery + its measurements stay as evidence).
  Quality of record: +0.0380 (the mz0 run's round 1 IS the adopted
  policy's verdict walk: margins = the 7-bit set, percol l5-mz0 =
  the identity).
- EXECUTED under the ruling (this session):
  * v3_witness_walk records the z split (z_clamps +
    z_clamps_per_layer + hard_violations in the manifest; sidecar
    rows `00 zpolicy clamp` + `NN zclamps <n>` — inert to the
    bf_model parser; BB's clamp rung reads them); the export
    asserts hard_violations == 0 (non-z sites) instead of total.
  * The Gemma v3 EXPORT is IN FLIGHT on the lock (--margins = the
    mz0 final 7-bit set; marker results/m8b_gemma4_v3_export.done).
  * --tables C5 RECORD under the ADOPTED margin sets (new
    ADOPTED_MARGINS map: mistral = margins-to-zero, gemma = the
    mz0 7-bit set): **14 members used (8 silu + 6 gelu) and every
    digest matches BB's frozen registry byte-for-byte** (checked
    against `uperf-v3 tables` output) — the l34 gate-margin-shifted
    pair lands on an already-frozen member; the frozen (-5,-13)
    silu member goes unused post-margin (harmless). NO C5
    additions needed. results/m8b_int16out_members.{json,txt}.
- **THE REAL GEMMA-4-12B v3 EXPORT IS DONE [MEASURED WSL-BOX
  NT|NOISY-SHARED]**: 48 layers x T=512 (d 3840, f 15360) under
  the adopted 7-bit margin set — **0 violations AND 0 z clamps on
  the export window** (the window happens to be clamp-free, so the
  witness is a plain v3 witness; sidecar carries `00 zpolicy
  clamp` and no zclamps rows). Shifts: sh_g 8-10, sh_u 0-3 (no
  negative — Gemma has no upscale layer), sh_h 11-14, sh_z 8-9;
  peak RSS 3.43 GB; 11G bins gitignored; digests.txt + manifest
  committed. (First launch died on a missing --text flag — the
  token-stream source; rerun clean.)
  REMAINING for the lane: the final report block. BB (in flight):
  the Gemma gelu verify-export reconcile (family sniff from the
  sidecar table row + a legible zclamps!=0 guard landed in the BB
  worktree); the clamp-selector z gadget is forward-looking
  statement work (no clamped element exists in any current
  witness).
## Agent BB status (wt-uperf3-bb) — round 3, the v3 statement in the engine

- 2026-08-26 SKELETON. Lane = the v3 statement profile behind an
  explicit selector (E1 widened a/u/h/z classes, E2 h16 limb-split
  down matmul, E4 round-mode requant, E5 range-fact classes, C5
  int16-out registry rows), v2 default byte-identical (freeze-check +
  uperf-pc diff-battery + uperf-w battery + the 3x16 digests
  93a98700../0ae9cdae.. are the floor at every commit). PLAN (strict
  rungs, one commit per green rung):
  (0) baseline captures on THIS worktree binary (build, freeze-check
      WSL form, diff-battery, 3x16 full-profile digests via
      M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/
      m125_ffn_export_wsl — the main repo holds the local bins).
  (1) C5: lookup.rs int16-out member family (silu 9 members from the
      committed Mistral calibration's distinct (eGate,eA) pairs at
      e_out = eA-8, gelu 6 from Gemma's; frozen i16 bytes + v3 spec
      digests, generator + digest fn mirroring silu-v2/L191-242 and
      scripts/m8b_gemma4_gelu_member.py), manifest.rs ADDITIVE
      versioned registry rows (duplicated-constant discipline), new
      freeze rows inserted before the UAGB1-BF rows so the WSL form
      exercises them. PROVISIONAL under the ruling: digests to be
      reconciled with lane AA's generation script when it lands.
  (2) E4: round-mode requant helper (floor relation on acc +
      2^(sh-1); m125_int8_calibration.py:139-151 semantics) + oracle
      leg; negative-shift (exact up-scaling) branch.
  (3) the v3 chain in Rust (u3_derive_chain): int16 a/u/h/z at e-8,
      h16 -> (Hlo,Hhi) limbs at 2^8, two down-matmul accumulators
      DaccLo/DaccHi (CLS_ACC stays <= 31 at every shape), round mode;
      numerically against make_widen_ffn/make_exact_ffn (reference
      port = the battery oracle).
  (4) the `uperf-v3` rig arm: v3 statement digest (profile tag, exps,
      shifts incl. negative, round flag, int16-out member digests) +
      the full bf_layer_run-pattern prove/verify E2E: 4 matmul
      sumchecks, Hadamard a16 o u16, 4 requant pins (limb-recombine
      + round-const forms), lookup pair (g8,a16) vs the int16-out
      member, range instances incl. 2^16-row u16/z16 tables
      (multi-commitment m columns), tamper legs (WrongWeight,
      WrongTable, SeamSwap, RangeViolation, LimbForge, RoundModeLie).
  (5) rungs: synthetic small shape battery (ZK_THREADS 1/2/7); the
      125M rung on the REAL local bins with the v3-widened M125
      profile (eA/eUp/eH/eZ -8, round; sh_u in [-1,1] exercises the
      upscale branch on real data; sh_h 13-15 inside CLS_REM 16);
      1x16/3x16 real Mistral/Gemma rungs HELD for the merged round
      (need lane AA's exports).
  Writes: zkmatrix-rs/src/ring/lookup.rs (additive), src/manifest.rs
  (C5 rows ONLY, under the ruling), src/bin/ring_matmul.rs (the
  [UPERF3-BB] section + freeze-row insertion + dispatch), this
  section. NOT touched: kfield/sumcheck/gkr/gkr_masked internals,
  codex-audit-*, the python scripts, other lanes' files.

- 2026-08-26 RUNG 0+1 DONE (commits 496d71f skeleton, 90415d0 C5):
  * BASELINE captured on this worktree's binary (4e82219 + skeleton):
    build green; the floor gates re-verified AFTER the C5 edit (below).
  * C5 LANDED: ring/lookup.rs `silu-int16out-table-v3` (9 members) +
    `gelu-tanh-int16out-table-v3` (6 members) — 256-row int8 domain,
    int16 output at e_out = eA - 8, frozen i16 bytes + v3 spec-header
    digests + deterministic generators + `int16out_member` accessor;
    manifest.rs ADDITIVE versioned rows (UPERF3_SILU16/GELU16_MEMBERS +
    _TABLE_DIGESTS duplicated-constant copies, `uperf3_v3_table_
    registry()` = v4 registry UNMOVED + 15 members; v4_table_registry
    and every existing digest byte-identical). Member sets = the
    distinct calibrated (eGate,eA) pairs of the two measured
    checkpoints (Mistral 9 silu, Gemma 6 gelu; m125's two pairs map to
    (-3,-11)/(-4,-12), both present). PROVISIONAL under the ruling —
    digests to reconcile with lane AA's generation script.
  * CONVENTION NOTE for AA (the one deliberate divergence from the
    measurement scripts): the frozen members CLAMP at +-32767 (the
    family totality declaration, = the v2 +-127 discipline; same
    absmax coverage as the int8 member — design choice D1). The quick
    silu_tab_a16/gelu_tab_a16 tables in the attrib scripts carry NO
    clamp, so at saturating members (eA <= eGate: 6 of 9 silu, 2 of 6
    gelu) the top gate codes differ (ref values run to 65024-130048 =
    "int17-18"). Cross-checked in python: byte-identical on every
    non-saturating member; diffs ONLY at clamped rows. If AA's
    freeze prefers the unclamped reading, the output class must widen
    past int16 — flag for the reconcile.
  * FREEZE ROWS UPERF3-BB-1a..1d (regenerate byte-identical; digests
    pin frozen bytes + accessor exact; manifest == lookup pins + v3
    registry shape; v2 family digests unmoved) inserted BEFORE the
    UAGB1-BK rows so the WSL form exercises them.
  * FLOOR GATES on the C5 binary [WSL-BOX NT]: freeze-check 102 ok
    rows (98 baseline + the 4 BB rows, all green) then the expected
    BK panic at the export load (cannot read layer00_X.bin), last ok
    row = "UPERF3-BB-1d v2 family digests unmoved"; uperf-pc
    diff-battery green 29.4s; uperf-w battery 23/23; 3x16
    full-profile via M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/
    results/m125_ffn_export_wsl (the main repo holds the local bins;
    this worktree has none): accept TRUE, statement digest
    93a98700.. and EVAL-PROOF DIGEST 0ae9cdae.. BYTE-IDENTICAL to the
    lane-W baseline.
  * IN FLIGHT: the u3 rig (E1/E2/E4/E5 + the `uperf-v3` battery and
    the m125-v3 rungs) appended, building.

- 2026-08-26 RUNG 2-4 DONE (commit 6f1b2c3-class; the v3 rig): E1/E2/
  E4/E5 + the `uperf-v3` rig landed in ring_matmul.rs ([UPERF3-BB]
  section, ~2000 lines, v2 path untouched):
  * The v3 chain (u3_derive_chain + serial reference oracle): 19-entry
    statement per layer (X, WgT, WuT, WdT, Gacc, Rg, g8, a16, Uacc,
    Ru, u16, H, Rh, Hlo, Hhi, DaccLo, DaccHi, Rd, z16). E2 = h16
    NEVER committed whole: Hlo [0,255] + Hhi [-128,127] (the exact
    int16 window), TWO down-matmul accumulators (every committed acc
    stays inside CLS_ACC <= 31 at every shape; the single-acc form
    would need 35-38 bits at 125M/8B). E4 = round as floor on the
    publicly pre-shifted operand; sh <= 0 = exact up-scaling on a
    committed edge (no remainder). E5 = u16/z16 range facts against
    [0, 2^16) tables at offset 32768 (multi-commitment m columns —
    the layout generalization), limb facts via the 256-row tables,
    remainders at derived widths; minimum table depth 4 (the sh_u = 1
    two-row tables of the m125-v3 profile underflow
    blinder_positions below 16 leaves — found and fixed).
  * The wave rig (u3_layer_run, the bf_layer_run pattern): 4 matmul
    sumchecks, Hadamard a16 o u16, 4 requant pins with the round
    half-constant and the limb-recombine/two-acc linear forms,
    lookup pair (g8, a16) vs the frozen int16-out member, up to 9
    range instances/layer; v3 statement digest = profile tag + dims +
    exps + SIGNED shifts + round/family flags + member digests +
    entry digests + the registry digest list; verifier statement gate
    recomputes weights from the public model (P0).
  * BATTERY (uperf-v3 battery small) 3x GREEN at ZK_THREADS 1/2/7
    (115.1s / 114.4s / 106.4s [WSL-BOX NT]): C5 freeze rows; chain
    oracle 8/8 layer-runs byte-identical (silu/gelu x round/floor,
    all 15 derived tensors); E2 limb identity (DaccLo + 256*DaccHi ==
    h16 @ WdT byte-exact); E4 round == floor-on-pre-shifted (sh
    1..=16 signed) + upscale exactness; honest E2E ACCEPT x4
    (silu-round l0 (-3,-11), silu-round l1 (-4,-12) + NEGATIVE sh_u
    upscale edge, gelu-round, silu-FLOOR profile; 345 cms, 3 waves,
    787 pins at t=16 d=64 f=128); tamper REJECTS x6 at exactly the
    intended gates: WrongWeight (statement gate), WrongTable (waves;
    statement/matmuls/roots green), SeamSwap (waves), RangeViolation
    (rd root ONLY), LimbForge (hlo root ONLY — hlo+256/hhi-1 with
    recombination preserved), RoundModeLie (waves).
  * chain-m125 on the REAL local bins (M125_EXPORT_DIR=main repo's
    m125_ffn_export_wsl): ALL 12 layers derive + range-check under
    the v3 profile at T=16; measured widened shifts sh_g 7-9, sh_u
    {-1,0,1} (layers 3/4 = the real upscale layers), sh_h 13-15,
    sh_z 6-10; members (-3,-11)/(-4,-12) only; max |z16| 11445.

- 2026-08-26 (late) VERIFY-EXPORT RUNG — the cross-language
  reconciliation gate against lane AA's --profile v3 exports:
  * `uperf-v3 verify-export [t]` (point ZK_MODEL_EXPORT_DIR at a v3
    export): asserts per layer (1) sidecar SIGNED shifts == the
    Rust-derived ones, (2) wexps row == the widened exponents, (3)
    the table row names EXACTLY a frozen C5 member (family, e_in,
    e_out, digest), (4) Rust-derived a16/u16/h16(=256*Hhi+Hlo)/z16
    == AA's exported planes byte-for-byte, (5) at t == T the
    full-plane sha256s == the sidecar rows. Margins arrive BAKED
    into the sidecar's exps row (the margins row is metadata), so
    the gate holds for any margin set by construction.
  * 125M GATE PASSED [WSL-BOX]: AA's m8b_test/m125_v3_export at the
    FULL T=512 x 12 layers — 48 plane legs byte-identical, every
    table row = a frozen C5 member, full-plane sha256s == sidecar.
    The python export chain and the Rust u3 chain agree bit for bit.
  * FINDING (the real-7B blocker, expected class): the REAL Mistral
    v3 export FAILS TO LOAD — bf_model's sidecar parser (line
    ~24658) supports UNIFORM e_w only; Mistral has per-tensor
    per-layer weight exponents (l0: -10 -11 -10). The 125M export
    slid through because its three exponents happen to be equal
    (-9 -9 -9). NEXT RUNG (ownership extension noted: the lane-W
    loader region, lane W closed 2026-08-25): BfModel per-tensor
    e_w3 = [eWg,eWu,eWd] per layer; consumers migrate (bf_shifts,
    the witness class table W/acc/rem rows, u3 shifts); uniform
    sidecars byte-identical by construction (all three equal); W-5
    parser battery legs extended with a per-tensor leg.
  * Floor at this commit [WSL-BOX]: diff-battery green 28.0s;
    freeze-check 102 ok rows (last = UPERF3-BB-1d) then the
    expected BK panic — identical to the C5-commit baseline.

- 2026-08-26 (later) PER-TENSOR WEIGHT EXPONENTS + THE REAL-MISTRAL
  RECONCILE (the blocker rung, same session):
  * BfModel/U3Model `e_w: i32` -> `e_w3: Vec<(eWg, eWu, eWd)>` per
    layer (accessors e_wg/e_wu/e_wd + e_w_uniform()); the sidecar
    parser accepts per-tensor exps fields 7-9 (both uniform-only
    rejections removed); consumers migrated per site: bf_load_layer
    + bg_dummy_layer shifts (gate/up matmuls use eWg/eWu, down uses
    eWd), bf_entry_typing (WgT/WuT/WdT + Gacc/Uacc + Rg/Ru +
    Dacc/Rd rows split, each matmul's W/acc/rem carry ITS weight
    exponent), U3Model::shifts, widen_from_bf, u3_synth_model.
    Uniform exports produce identical values by construction.
  * v3 STATEMENT LAYOUT v2 ("uperf3-v3-pass-v2"): the global e_w
    field left the header; (eWg,eWu,eWd) joined the per-layer
    exponent block. Recorded: any v1-tagged digest in earlier
    evidence lines is superseded (v3 statement digests were never
    frozen — this is the right time for the layout change).
  * W-5 parser battery: the "per-tensor REJECTED" leg FLIPPED to
    "per-tensor ACCEPTED (e_w3 = [(-9,-8,-9)], uniform = None)";
    uniform + m125-fixture legs now assert via e_w_uniform().
  * GATES [WSL-BOX]: uperf-w battery 23/23; diff-battery 26.5s
    green; freeze-check 102 ok rows unchanged; uperf-v3 battery
    smoke green 16.9s (honest silu-round ACCEPT under the v2
    statement bytes); chain-m125 12/12 range facts HOLD; the 125M
    verify-export re-run BYTE-IDENTICAL (48 legs — the uniform path
    is untouched).
  * **THE REAL MISTRAL-7B v3 WITNESS VERIFIES: verify-export PASSED
    on AA's m8b_mistral_v3_export — 32 layers x T=512, 128 plane
    legs byte-identical, full-plane sha256s == sidecar, every table
    row = a frozen C5 member, per-tensor exponents (l0: -10 -11
    -10) and the margin-adjusted exps rows handled end to end.**
    The python export chain and the Rust v3 engine agree bit for
    bit at the real 8B-class shape — the cross-language reconcile
    the round was opened for.
  * NEXT: the 1x16/3x16 real-plane PROOF rungs on the Mistral
    export (u3_layer_run on loaded planes; the plumbing exists —
    u3_load_m125_layer generalizes via bf_model()); then Gemma once
    lane AA's export lands (gelu family, GeGLU sites).

- 2026-08-26 (night queue) THE 7B PROOF RUNG NEEDS THE MAC (measured,
  not assumed):
  * `uperf-v3 e2e-m125 0 16 1` on the REAL Mistral export (the
    per-tensor loader banner prints "e_w per-tensor" — the new path
    live on real planes) was **OOM-KILLED on the 15 GB box at 15.08
    GB anon RSS** (dmesg: total-vm 20.3 GB; exit 137). The bill is
    WEIGHTS-dominated — three 4096x14336 planes and their digit-ring
    /commit structures are t-INDEPENDENT, so a smaller T does not
    rescue it. Disposition: the rung runs on the Mac (256 GB; a
    Grok RUN task once this lane merges), or after a u3-rig memory
    diet (the W-8(a)-class streaming, the known MVP-plan item —
    lane R's memo predicted exactly this bill class).
  * POST-MIGRATION real-bins evidence [WSL-BOX NT]: `uperf-v3
    e2e-m125 0 16 2` on the m125 export under the v2 STATEMENT
    LAYOUT: **accept = true** — 5320 data cms (5405 commitments, 41
    waves, 911 pins), commit 3.3 s / prove 70.3 s / verify 17.6 s,
    wall 91.4 s, statement 2059 bytes. The v3 rig's real-data proof
    arm is green after the per-tensor migration.

- 2026-08-27 THE GEMMA (GeGLU) RECONCILE — both real checkpoints
  now verify byte-for-bit:
  * verify-export gained (a) table-family sniffing from the
    sidecar's layer-0 table row (widen_from_bf defaults to silu;
    the Gemma export carries gelu-tanh members), (b) a LEGIBLE
    guard on clamp-at-z exports: `00 zpolicy clamp` accepted, but
    any nonzero `NN zclamps` row fails with "the clamp-semantics
    rung is required" instead of a confusing plane diff (the chain
    here does not clamp; AA's Gemma export window measured 0
    clamps, so it reconciles as a plain v3 witness).
  * **GEMMA GATE PASSED [WSL-BOX]: AA's m8b_gemma4_v3_export — 48
    layers x T=512 (d 3840, f 15360), 192 plane legs
    byte-identical, full-plane sha256s == sidecar, every table row
    = a frozen C5 member.** With Mistral's 128 legs this closes
    the cross-language reconcile for BOTH real checkpoints and
    BOTH activation families under the adopted margin sets.
  * REMAINING (forward-looking): the clamp-selector z gadget (the
    statement-side clamp relation — needed only when a witness
    window actually contains a clamped element); the 7B/12B proof
    rungs are Mac tasks (the 15.08 GB OOM record above).
## Agent CC status (wt-uperf3-cc) — round 3, the attention-site qualification gate

STATE: IN FLIGHT (2026-08-26). One commit per green rung:
- SKELETON + EQUIV (593d3ba): scripts/m8b_gemma4_attn_gate.py
  (stats/attrib/widen/equiv phases; site table + spec/AM references
  in the header — the doc of record for MVP-2's site names). equiv
  gate: this walker with all hooks off is BIT-EXACT vs the validated
  m8b_gemma4_walker at 2 and 6 layers (incl. one k_eq_v full layer);
  6-layer stats smoke green.
- STATS (0804237): the full 48-layer site-stats pass [MEASURED
  WSL-BOX NT, 623 s, RSS 2.6 GB] — q/k/v/scores/ctx TIGHT
  (absmax/p999 ratio <= 5, the FFN-internals-clean picture);
  xattn/ao/postn/xres OUTLIER-STRETCHED (ratios to 49; xattn l0
  absmax 1302, col-ratio 100 — the residual-stream disease at the
  attention seam); probs: 75-92% of the causal support sits below
  the fP=9 step (the fixed-point floor is the binding constraint,
  not range); qr=q+1 bit only at l5.
- ATTRIB [MEASURED WSL-BOX NT, val subset take=2, ref_subset
  7.5319]: first-order per-site int8 deltas, FFN fp, exponents
  frozen from the stats pass —
  q -0.0005, k +0.0203, v -0.0363, scores -0.0213, exps -0.0146,
  probs -0.0871, ctx -0.0446 (the attention COMPUTE CORE IS
  INT8-CLEAN at first order; negative deltas = subset noise floor);
  Wattn +0.2000 (all four proj weights int8);
  xattn +2.0043, ao +0.4081, postn +2.1633, xres +13.2300 (the
  SEAM/RESIDUAL-STREAM sites carry the poison — the SAME
  class-widening story as the FFN verdict); all_int8 +14.8339
  (composed upper anchor). ~200 s/site, peak RSS 2.10 GB.
  results/m8b_gemma4_attn_attrib.{json,log}.
- **WIDEN [MEASURED WSL-BOX NT, val subset take=2] — THE MVP-2
  ANSWER: the FFN story REPEATS AT ATTENTION.** int16 (e-8) singles
  at the four poisoned sites vs their int8 attrib deltas:
  xattn +2.0043 -> **-0.0158** (rescued to noise), ao +0.4081 ->
  **-0.0108** (rescued), xres +13.2300 -> **-0.0549** (the residual
  -stream poison DIES with one class widening), postn +2.1633 ->
  **+0.1895** (mostly rescued; the one site with a first-order
  residue — the Gemma four-norm sandwich's post_attention_layernorm
  edge; flag for the statement design). Composed **stack_wide**
  (EVERY site int8 incl. Wattn, only the material four at int16):
  **+0.0854** vs all_int8 +14.8339 — the widened attention stack
  lands in the same +0.1-nat class as the FFN's widened stack.
  Interaction note: stack_wide beats the postn16 single (+0.085 <
  +0.190) — first-order singles over-count the postn residue.
  ~200 s/walk, peak RSS 2.16 GB.
  results/m8b_gemma4_attn_widen.{json,log}.
- REMAINING: the site table -> U_PERF3_ATTENTION_STATEMENT_DESIGN.md
  §1 real-data update (exponent assumptions -> measured; the widened
  -class site list = xattn/ao/postn/xres, postn residue flagged) +
  final report block. Decision input for Victor: whether MVP-2's
  statement carries the widened class at exactly these four sites
  (the measured answer) and what to do about postn's +0.19.

## Agent DD status (wt-uperf3-dd) — round 4, the production E_c kernel

- 2026-08-27 RUNG 0+1 (one commit): ring/ec_kernel.rs — AVX2 bodies
  for the four MAC families (u32xu32->u64 widening via
  _mm256_mul_epu32 on even/odd u32 positions, unpack/permute back to
  the scalar lane order, split lo/hi u64 plane accumulate), runtime
  feature detection, scalar zc_range bodies = the oracle
  (pub(crate) hooks); `uperf-s kernel-bench [c] [log2_pairs]
  [reps]` = identity gate (4 families byte-identical scalar vs
  avx2, running-sum path exercised) + the ns/MAC table.
  MEASURED [WSL-BOX 1T QUIET]:
  | c | e_mac scalar->avx2 | e_mac_fixed | e_mac_base |
  | 4  | 0.757 -> 0.296 (2.6x) | 0.748 -> 0.319 (2.3x) | 0.813 -> 0.507 (1.6x) |
  | 8  | 0.726 -> 0.249 (2.9x) | 0.699 -> 0.299 (2.3x) | 0.825 -> 0.466 (1.8x) |
  | 16 | 0.732 -> 0.252 (2.9x) | 0.740 -> 0.334 (2.2x) | 0.810 -> 0.498 (1.6x) |
  Reading: the spike's "~8x below K9" scalar kernel is now ~3x
  below K9-class [MODEL: K9 ~0.1 ns/MAC-equiv] at the kernel level.
  NEXT RUNGS: (2) wire the zc_range call sites through the
  dispatchers (cached avx2 flag; battery digest 3752cba4.. must not
  move) and re-run the spike s1 wall matrix — the wall ratio should
  move from 1.6x toward the counted 13.5x; (3) the shuffle
  elimination (permuted-plane accumulate, un-permute ONCE in
  e_red_block — the remaining ~2 ops/MAC of the 3 are shuffles;
  target <= 0.15 ns/MAC); (4) e_mac_base via pure vector ops
  (currently memory-bound at c*KL per call).

- 2026-08-27 RUNG 2 DONE: the 8 zc_range call sites route through
  `*_auto` dispatchers (cached avx2_active(); `ZK_EC_SCALAR=1`
  kill-switch for A/B). GATES: **uperf-s battery 48 legs ok,
  BATTERY DIGEST 3752cba4.. UNCHANGED with the AVX2 path live** —
  the dispatch is transcript-invariant, proven. SPIKE WALL RE-RUN
  [WSL-BOX QUIET], E_4 arm at 2^20 w=8 vs the masked-descent
  oracle: **1T prove wall 1.9x (was ~parity with the scalar
  kernel); 8T 2.3x (was 1.6x)** — 0.878 s vs 1.65 s at 1T, 0.232 s
  vs 0.54 s at 8T; counted ratios unchanged (13.5x equiv, 13.7x
  rounds, 49.5x wire; GO). The remaining wall/counted gap is still
  kernel-bound (rung 3, the shuffle elimination).

- 2026-08-27 RUNG 3 DONE (re-aimed by profile, one regression fixed
  honestly): the round loop's OTHER half is scalar modular LANE
  chains (extrapolation bv = a + X(b-a), the f chain prod(v-alpha),
  the recomposition +-2^(e0 k) v) — at w=8/deg_f=3/c=4 ~half the
  counted round MACs, untouched by rungs 0-2 (the measured Amdahl
  gap). Built fused AVX2 lane primitives (extrap_lanes /
  f_chain_lanes / rec_sub_scaled / rec_add) mirroring the
  fold31/canon32/min-trick formulas op-for-op (values IDENTICAL,
  not merely congruent), wired into both the base and ext round
  paths. REGRESSION CAUGHT: the first cut called _mm256 intrinsics
  from non-#[target_feature] fns — LLVM legalized every 256-bit op
  without AVX2 (rounds 0.70 -> 3.23 s!); fix = the rung-1 pattern
  (attributed loop-body fns). GATES: battery digest 3752cba4..
  UNCHANGED under avx2 AND ZK_EC_SCALAR=1 (the primitives'
  exact-value preservation verified end-to-end through 48 legs).
  WALLS [WSL-BOX QUIET], E_4 2^20 w=8: **1T rounds 0.696 -> 0.625 s,
  prove wall 2.0x; 8T rounds 0.148 -> 0.122 s, wall 2.6x** (vs the
  descent oracle; was 1.6x pre-round-4).
  NEXT: rung 4 = per-node FUSION (one attributed call per (k, tab)
  doing extrap + f-chain + mac_base + rec register-resident — the
  8-lane-per-call setup amortization is the remaining bound), and
  the shuffle elimination inside mac_block; target: the counted
  13.5x converting to >= 4-5x wall at 8T.

- 2026-08-27 RUNG 4 DONE — the fused base-round node
  (ec_kernel::base_node_fused, one #[target_feature] call per
  (block m, node x): AVX2 deinterleave (shuffle/unpack/permute =
  b_deint_pair's exact lane order), extrapolation, f chain, the
  c eq x f MAC blocks and the recomposition all register-resident;
  eq blocks loaded once per node; zc_range's body takes the fast
  path when base_round && avx2_active(), the rung-3 loop stays as
  the ZK_EC_SCALAR/portable fallback). GATES: battery digest
  3752cba4.. UNCHANGED both modes. WALLS [WSL-BOX 1T/8T QUIET, no
  build contention]: rounds 0.625 -> 0.530 s (1T), 0.122 -> 0.115 s
  (8T); **prove wall vs the masked-descent oracle: 2.3x (1T) /
  2.7x (8T)** — the round-4 arc took the spike's 1.6x to 2.7x, all
  transcript-invariant.
  SCOPE DECISION (recorded, not deferred silently): the next term
  is the FOLDS (0.150 s = 21% of 1T prove), whose per-block cost is
  dominated by the SCALAR e_red_block reduction (the cross-plane
  Z^c = s0 fold) — vectorizing it is delicate, AND lane EE's
  aggregate restructures the fold amortization entirely (shared eq,
  batched columns). Rung 5 (fold fusion + e_red_block AVX2) is
  therefore GATED on EE's profile: build it only if the aggregate
  still shows folds as a top-3 term. The honest DD position: the
  counted 13.5x will finish converting in the AGGREGATE's shape,
  not the per-column spike harness.

## Agent EE status (wt-uperf3-ee) — round 4

STATE: DONE (2026-08-27; all four rungs landed same day: R0 8566aba,
R1 2c1f5c8, R2 4bb51cd, R3 6f1933d, close = this commit). Lane
summary: (1) the AGGREGATE zero-check built and differentially
pinned — m range columns as ONE sumcheck (instance axis, ONE shared
eq, stacked per-column claims served for the opening layer), byte-
identical to the spike's per-column prover on the stacked instance
in all 32 battery cells and to the per-column path verbatim at
m = 1; counted at 2^20 x 16: rounds 320 -> 24 (13.33x), wire 6.61x,
MACs NEUTRAL (1.00x) — the batching win is structural (round
objects/wire/one eq + transcript), exactly the dimensions the
descent comparison is bound by. (2) the O-4 mask transfer built —
the house M1 g-mask carried onto the aggregate sumcheck, claims
provably untouched (bit-equal to the table MLEs) while every
shipped round poly blinds; flipped-mask/tampered-opening rejects.
Batteries: agg-battery 136 legs, digest 46234986.. identical at
ZK_THREADS 1/2/7; floor held at every commit (48-leg digest
3752cba4.. unmoved, diff-battery green). Files touched: the
[UPERF3-EE] section appended to zkmatrix-rs/src/ring/zc_range.rs
(no existing function edited; lane DD's e_mac* hook lines untouched),
the [UPERF3-EE] arms in the bin's [UPERF3-S] section (agg /
agg-battery / agg-mask + dispatch), this status section. No frozen
file, no other lane's file.

OPEN QUESTIONS / NOTES FOR THE ORCHESTRATOR:
- "Both moduli": read as e0 {1,2} x c {4,8} (see the MODULI NOTE
  below) — the E_c kernels structurally exclude Q8_46; if a q46
  aggregate is wanted it needs a kernel-gate ruling first.
- The brief's "aggregate's served claims EQUAL the per-column path's
  claims bit-for-bit": FS makes literally-per-column-transcript
  claims live at different points, so the leg set implements the
  three exact equalities that are well-defined: (i) m = 1 whole-path
  byte identity vs zc_range_prove; (ii) any-m byte identity vs
  zc_range_prove on the stacked instance (the spike prover AS the
  oracle); (iii) every served claim == base_mle_eval (the per-column
  path's claim definition, zc_range_open_check's machinery) at
  r_col, bit-for-bit. If a different reading was intended, say so
  and the leg is cheap to add.
- The aggregate is MAC-NEUTRAL vs per-column (R2): the memo's
  "advantage only improves" holds in rounds/wire/objects; anyone
  modelling walls should NOT book a MAC saving from batching alone.
- Non-power-of-two m pays the pad in MACs (m = 7 -> 8: 0.90x at the
  smoke shape); group planners should prefer power-of-two column
  batches per aggregate.
- The mask commitment is a STAND-IN (binding transcript digest, the
  S2 h-commit idiom); production needs the real mask-commitment wave
  + eval-proof pin rows (the O-4 write-up's remaining half), and the
  O-4/O-7 simulator + knowledge-error derivations remain design
  obligations (memo §2.6) — engine evidence is now in place for both.
- Mask cost: +2 E-elements wire, closed-form M_t per round (57
  coefficients at the demo shape), prove overhead in the noise.

Lane: the aggregate zero-check
(design memo §2.2: instance axis, shared eq, stacked claims) + the
O-4 mask transfer (§2.6: the g-mask machinery onto the aggregate
sumcheck). Everything additive: a `[UPERF3-EE] aggregate` section
APPENDED to ring/zc_range.rs (no existing function or round body
touched — lane DD owns the e_mac* hook lines), new `uperf-s` arms
(`agg`, `agg-battery`, `agg-mask`) in the bin's [UPERF3-S] dispatch,
this status section. Floor at every commit: release build; `uperf-s
battery` 48 legs, digest 3752cba4.. UNMOVED (the aggregate gets its
OWN battery arm + digest); `uperf-pc diff-battery` green.

PLAN (one commit per green rung, prefix "U-PERF3 EE:"):
- [x] R0 SKELETON: this section, the empty [UPERF3-EE] code section,
  stub arms printing usage.
- [x] R1 AGGREGATE: `zc_agg_prove/verify` — m same-shape range
  columns as ONE sumcheck over the stacked hypercube (instance axis =
  the high a = ceil(log2 m) variables, zero-padded pad columns — the
  house alphabets contain 0 so pads satisfy the constraint), ONE
  shared eq table over n+a vars, per-column claim STACKING: after the
  n column-axis rounds the folded tables hold each column's MLE at
  the shared column point r_col; those m x (w+1) values are the
  served claims (the opening layer's per-tensor form), the verifier
  recombines T_k(x*) = sum_i eq(r_inst, i) claim[i][k] for the final
  identity. DIFFERENTIAL (the per-column spike path is the oracle):
  (i) m = 1 => byte-identical to `zc_range_prove` (transcript,
  rounds, point, claims == finals); (ii) any m => byte-identical to
  `zc_range_prove` run on the manually stacked instance (the spike
  prover as the stacked oracle); (iii) served claims ==
  `base_mle_eval` (the per-column path's claim definition, the
  zc_range_open_check machinery) per column at r_col, bit-for-bit,
  asserted and printed. Battery arm `agg-battery`: m in {1,2,7,16} x
  w in {8,14} x both digit bases e0 in {1,2} (see the moduli note
  below) x c in {4,8}, honest + a tampered-claim reject leg, own
  AGG BATTERY DIGEST at ZK_THREADS 1/2/7.
- [x] R2 COUNTED: rounds/MACs/wire, aggregate vs m separate
  per-column zero-checks at 2^20 x 16 columns (w = 8, c = 4, e0 = 1);
  [COUNTED] table here; walls labeled [WSL-BOX NT NOISY-SHARED]
  (lane DD benches on this box — counts and byte-identity are the
  deliverables, not walls).
- [x] R3 O-4 MASK: `ZcAggMask` = the M1 g-mask shape
  (gkr_masked::GMask: a0 + per-variable univariates, degrees matching
  the round pattern) carried into E_c, drawn from ProverRng,
  commitment stand-in absorbed BEFORE rho/betas (mask-then-fold),
  hypersum G served + nu-combined into the claim (the house
  masked-sumcheck idiom), the mask's per-round closed-form summand
  added to every shipped round poly; the served claims are the SAME
  table MLE values (the mask vanishes on the claims — asserted via
  the base_mle_eval oracle at the masked run's point); transcript
  differs from unmasked; zero-mask degeneracy == unmasked
  byte-for-byte; tamper legs: a flipped mask coefficient at verify
  REJECTS, a tampered served mask evaluation REJECTS.

R1 EVIDENCE (2026-08-27, WSL box, shared with lane DD):
- cmd: `uperf-s agg-battery [1|2|7]` — 96 legs ok, AGG BATTERY DIGEST
  16c2e2fdce4e10fd686eadca42f2e243454dfa67a0f06d8278ca3a62b001b7fb
  byte-identical at ZK_THREADS 1/2/7. Matrix: m {1,2,7,16} x w {8,14}
  x e0 {1,2} x c {4,8} at 2^6/column; per cell: honest verify green +
  the stacked-oracle BYTE identity (transcript state, every round
  poly, fold point vs `zc_range_prove` on the stacked instance — at
  m = 1 the oracle IS the per-column path verbatim) + recombined
  stacked claims == oracle finals + ALL m x (w+1) served claims ==
  per-column `base_mle_eval` at r_col bit-for-bit + a flipped-claim
  reject + a flipped-round-node reject.
- cmd: `uperf-s agg 10 7 8 1 4 1 171` (smoke, m = 7 exercises pad
  columns): all three differentials assert + print (col-0 plane-0
  claim [1177458288, 890349491, 1733341912, 1774377869] identical
  both ways); per-column -> aggregate at 7 x 2^10: rounds 70 -> 13
  (5.4x), wire 6,608 -> 2,048 B (3.2x), MACs 0.90x (the 7 -> 8
  pad inflates the stacked cube; power-of-two m has no pad loss)
  [COUNTED].
- Floor: 48-leg battery digest 3752cba4.. UNMOVED; diff-battery
  green 15.9s; build green.
- commit: R0 8566aba; R1 2c1f5c8.

R2 EVIDENCE (2026-08-27, WSL box, SHARED — lane DD benches possible;
run under `flock /tmp/zk-heavy.lock`, ZK_THREADS 1):
- cmd: `uperf-s agg 20 16 8 1 4 1 171` — 16 columns x 2^20, w 8,
  c 4, e0 1 (the S1 design point). All differentials GREEN at full
  scale: stacked-oracle byte identity (transcript, 24 round polys,
  point) + all 144 stacked claims == per-column base_mle_eval
  bit-for-bit.
- [COUNTED] per-column (16 separate sumchecks) -> aggregate (ONE):

  | metric      | per-column      | aggregate       | ratio  |
  |-------------|-----------------|-----------------|--------|
  | rounds      | 320             | 24              | 13.33x |
  | wire bytes  | 27,904          | 4,224 (incl 144 claims) | 6.61x |
  | base MACs   | 15,292.8M       | 15,292.5M       | 1.00x  |
  |  - rounds   | 13,514.4M       | 13,514.1M       | 1.00x  |
  |  - folds    | 1,510.0M        | 1,510.0M        | 1.00x  |
  |  - eq       | 268.4M          | 268.4M          | 1.00x  |

  READING: the aggregate is MAC-NEUTRAL (the stacked cube's round/
  fold/eq volume equals the 16 columns' sum at power-of-two m; a
  non-power-of-two m pays the pad, e.g. 7 -> 8 cost 0.90x at the
  smoke shape) — the batching win is STRUCTURAL: 13.3x fewer round
  polynomials/challenges (320 -> 24, i.e. 1.5 effective rounds per
  column instead of 20), 6.6x less wire, ONE eq object and ONE
  transcript instead of 16, and the S1 per-column advantage vs the
  descent carries unchanged since MACs do not grow. This matches the
  memo's "the counted per-column advantage only improves" in the
  round/wire dimensions that motivated it (the descent comparison is
  rounds/wire-bound, spike report §2).
- Walls (labeled, not chased): prove 23.08s (16 columns) vs 24.53s
  (aggregate) [WSL-BOX 1T NOISY-SHARED]; peak RSS 3,095 MiB
  (the aggregate materializes ONE stacked copy of the 9 base tables
  at 2^24 + the E tables; per-column peaks at ~100 MiB/column —
  the 8B streaming plan prices this in lane R's memory architecture).
- commit: R2 4bb51cd (ledger-only; the arm landed at R1 2c1f5c8).

R3 EVIDENCE (2026-08-27, WSL box, shared):
- The O-4 construction (zc_range.rs [UPERF3-EE]): `ZcAggMask` — the
  M1 g-mask shape (gkr_masked::GMask: a0 + one univariate per
  variable, no per-variable constant, degree deg_f + 1 = the shipped
  round degree) in E_c, drawn from `ProverRng` (the draw_masks rule:
  FS state is not entropy), commitment stand-in = a binding
  transcript digest of the coefficients absorbed BEFORE rho/betas
  (mask-then-fold); the prover serves the hypersum G, draws nu, and
  ships g_t = g_F_t + nu * M_t with the closed-form
  M_t(X) = 2^free (a0 + sum_{s<t} u_s(r_s) + u_t(X)) +
  2^(free-1) sum_{s>t} u_s(1) — the TABLES never see the mask, so the
  stacked claims stay the true table MLEs; the verifier
  (`zc_agg_verify_masked`, the masked_gkr_verify idiom: the mask set
  stands for the commitment opening) pins BOTH served openings
  (G, g_m(x*)), starts the chain at nu*G and closes with + nu*g_m(x*).
  `zc_agg_prove` is now the mask=None path of `zc_agg_prove_masked` —
  the None path's byte-identity to the untouched `zc_range_prove` is
  re-proven by the 32 stacked-oracle legs in the battery (the
  refactor degeneracy).
- cmd: `uperf-s agg-battery [1|2|7]` — now 136 legs (96 R1 + 40 mask:
  m {2,7} x e0 {1,2} x c {4,8} at w 8, 2^6/column, 5 legs/cell), AGG
  BATTERY DIGEST moved (mask legs appended) to
  4623498603db778361e61f790df90485e61cec52fc8b80373f010cbbd61a419e,
  byte-identical at ZK_THREADS 1/2/7. Mask legs per cell: honest
  masked verify + ALL claims == base_mle_eval at the masked point
  (the mask VANISHES on the claim values) | the STRIP check (shipped
  minus nu*M_t is a VALID UNMASKED round chain for the same
  challenges, closing on the recombined claims — the O-4 transfer
  fact) | blinding (transcript differs from the unmasked run; every
  shipped round differs from its stripped g_F) | zero-mask degeneracy
  (shipped == stripped, G = g_m(x*) = 0, verify green) | tampers: a
  FLIPPED mask coefficient at verify REJECTS (hypersum pin), tampered
  served g_m(x*) REJECTS (final pin), tampered served G REJECTS,
  unmasked verifier rejects a masked proof and vice versa.
- cmd: `uperf-s agg-mask 12 4 8 1 4 1 181` (demo, 2^12 x 4): all
  differentials print + assert; shipped round-0 identity == nu*G;
  mask overhead in the noise (57 coefficients, closed-form M_t —
  masked 0.024s vs unmasked 0.025s [WSL-BOX 1T NOISY-SHARED]); wire
  +32 B (the two mask openings).
- Floor: 48-leg battery digest 3752cba4.. UNMOVED; diff-battery green
  16.1s; build green (the two new-code warnings fixed; no new
  warnings from this lane).
- commit: R3 = the commit carrying this block.

MODULI NOTE (recorded, not guessed): the brief's battery matrix says
"both moduli". The E_c sub-extension kernels REQUIRE the q31 point
(SubExt::new asserts 2^30 < q < 2^31, 2^31 mod q < 1024) — the house
has exactly ONE such modulus (Q8 = 2^31 - 399); the other house
modulus Q8_46 (46-bit) fails the gate by construction. Reading
adopted: "both moduli" = both digit-plane bases the house commits
(e0 = 1 sign-binary / e0 = 2 balanced base-4 — the two vanishing
moduli of the digit alphabet), crossed with both practical
sub-extension moduli c in {4, 8} (Z^c - s0). If Victor meant Q8_46,
that needs a kernel-gate ruling first — flagged as an open question.

## Agent FF status (wt-uperf3-ff) — round 4

- 2026-08-27 SKELETON (rung 0): worktree on uperf3-ff at the round-4
  open commit. OWNS: NEW zkmatrix-rs/src/ring/two_tier.rs (+ its one
  `pub mod two_tier;` line in ring/mod.rs), the NEW [UPERF3-FF] bin
  section with `uperf-t` in the main dispatch (one line by the
  `uperf-s` line), this status section. eval_proof.rs and every other
  ring module READ-ONLY. Rung plan (one commit per green rung):
  1. `uperf-t plan [log2_rings]` — the two-tier PLANNER only: tier
     split (sqrt sizing), what each tier commits, the exact-digit
     gate per tier, printed at 2^20 / 2^22 / 2^23 and the 8B group
     shapes 352,321,536 / 145,475,764 rings (memo acceptance: "8B
     two-tier gate green"). Table recorded here.
  2. The synthetic differential at 2^20: one committed group both
     ways (the built bg_prove_group/bg_verify_group opening as the
     ORACLE; the two-tier front end behind uperf-t), fixed seeds,
     served claims asserted EQUAL. THE VALUES COMPARED (stated up
     front, memo 4.2 differential leg): (a) the b_row images — the
     K_DEG = 16 conj-packed claim-row polys `GroupEvalProof.b_rows`,
     byte-for-byte, whose constant terms are the batched claim
     values v_batch; (b) the per-tensor / per-contrib MLE evaluation
     claims at the batched point — for every ClaimContrib m the
     K-element y_m = ct_K(sum_u bpolys(kw_m(u)) * w0[u]) computed by
     the oracle kernel pass restricted to m vs the same value served
     through the two-tier route; (c) the alpha-batched opening
     target h_cur = sum_c alphas0_c * b_rows_c vs the two-tier claim
     transport's reconstruction. If the claims cannot be made to
     line up: STOP, record exactly where the semantics diverge (a
     finding, not a failure).
  3. Scale to 2^22-2^23 synthetic + the real 12x512 act group
     (M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/
     m125_ffn_export_wsl); fold wall 1T/8T + prove-group-equivalent
     vs bg.prove-group at the same shape + verifier 1T + bytes; the
     box is SHARED — [WSL-BOX NT|NOISY-SHARED] on every wall,
     byte-identity and counts are the deliverables.
  Floor at every commit: release build green; uperf-pc diff-battery
  green; uperf-s battery digest 3752cba4.. unchanged; freeze-check
  WSL form (102 ok rows then the expected BK panic at the missing
  export).
- DESIGN NOTE (recorded before building, from the read of
  eval_proof.rs/pass_agg.rs): the built claim functional is, per
  contrib, rank-16 (not rank-1) over any (row x column-block) grid —
  the K-multiplication row_ker *_K col_ker mixes the 16 K-coordinates,
  so Phi_0[v] = radix_limb * sum_{d<16} beta[row][d] * conjQ[cb][d]
  (the [UAGB1-BH] row-column split, eval_proof.rs:2229). The
  Greyhound v-vector mechanism therefore needs per-(contrib, d)
  v-vectors on a grid where each term is rank-1 — given by the
  tensor-row-aligned grid. Consequences to measure/record honestly
  in rungs 1-2: (i) the tensor-aligned grid is UNBALANCED (outer =
  sum of tensor rows >> inner = nb*l0), so the planner must weigh
  both the balanced sqrt split (binding/norm side) and the aligned
  split (claim side); (ii) claim-side wire/verifier work scales with
  n_contrib x 16 v-vectors — counted, not assumed. Open question
  recorded, not guessed: whether the production shape wants the T11 b
  one-point RLC first (one contrib per tensor) — this spike measures
  the multi-claim form as built.
- RUNG 0 GATES (2026-08-27, pre-existing baseline, stub-only change
  set): build green; uperf-pc diff-battery green (O1 4/4, O2 35/35,
  O3 63/63, O5 12/12, E2E 2/2, 15.1s); uperf-s battery 48 legs,
  BATTERY DIGEST 3752cba4fa08c2ee052475e9f4459e2fc3ed0a0c59862468e0c31cbeb165aaae
  unchanged; freeze-check WSL form: 98 ok rows then the EXPECTED BK
  panic at the missing m125 export (the brief said 102; the branch
  baseline measured here and at lane S round 1 is 98 — recorded
  honestly, not chased).
- RUNG 1 (2026-08-27) — THE PLANNER (`uperf-t plan`), design-in-code,
  no proving. ring::two_tier: plan_two_tier_at (e' fixed-point
  mirroring the frozen plan_level with n_pairs = 0 — the pair
  cross-garbage is what two-tier removes), plan_two_tier (sqrt split
  + balanced-optimum S sweep), recursion_schedule (frozen
  plan_schedule REUSED, pre-gated), gate_headroom_bits.
  limbs_for_bound / fold_coeff_bound reproduced verbatim (private in
  the frozen module; provenance cited in-code). THE TABLE (full
  output = `uperf-t plan`; q31, kappa 11, quinary fold):
  | shape (e0) | single-tier | sqrt split S x G | tiers n_w / n2 | gates rg/w/u (bits) | rec (V-clear|V-rec) -> floor | verdict |
  | 2^20 (2) | +3.24 | 1024 x 1024 | 3072 / 56320 | +8.2/+2.5/+0.4 | 56K|59K -> 7 lv, 924-927 e7 | GREEN |
  | 2^22 (2) | +2.24 | 2048 x 2048 | 6144 / 135168 | +7.7/+3.0/+0.7 | 135K|141K -> 7 lv, 939 e7 | GREEN |
  | 2^23 (2) | +1.74 | 2897 x 2896 | 8691 / 191136 | +7.5/+2.7/+0.5 | 191K|200K -> 7 lv, 945-948 e7 | GREEN |
  | 8B weight 352,321,536 (1) | +0.05 | 18771 x 18770 | 75084 / 1651760 | +7.2/+3.2/+0.9 | 1.65M|1.73M -> 8 lv, 933 e7 | GREEN |
  | 8B act 145,475,764 (2) | -0.31 RED | 12062 x 12061 | 48248 / 928697 | +6.5/+2.5/+0.3 | 929K|977K -> 8 lv, 927 e7 | GREEN |
  ** 8B TWO-TIER PLANNER GATE: GREEN on both group shapes ** — and the
  single-tier act failure reproduces the memo's exact -0.31 bits
  (W-3), dissolved by the split. HONESTY ROWS (counted vs the memo's
  [MODEL]): (a) the recursion input is DOMINATED BY THE TIER-2
  u-DIGITS (G*kappa*l_t): 1.65M rings (8B weight sqrt split), NOT the
  memo's "~19K rings" (which counts only the folded row n_w = 75K);
  the balanced split (S ~ sqrt(n0*kappa*l_t/l_z)) lands 574K/369K
  total — still 200-600x below n0, floor-class schedules (8 levels,
  floor ~915-957 e7), but the "~19K" row should be read as w-only.
  (b) per-tier headroom at 8B act sqrt: +6.5 (row-group) / +2.5
  (folded w) / +0.33 (tier-2 u) bits — the memo modeled "~11-12 bits
  per tier"; counted is smaller (the u-digit object is the tight
  one); still green everywhere. (c) V-clear w wire at the spike
  shapes: 1.0-1.5 MB (2^22-2^23), 6-10 MB at 8B — the production
  form recurses w instead (V-recursed column). Gates at commit:
  diff-battery green, uperf-s digest 3752cba4.. unchanged,
  freeze-check 98 ok + expected panic.
- RUNG 2 (2026-08-27) — THE DIFFERENTIAL: GREEN, claims line up
  BIT-FOR-BIT. `uperf-t diff [n_log2] [threads] [seed]` (defaults
  20/1/161): a 6-tensor aligned synthetic group (809,984 digit rings
  ~2^19.6, e0 in {1,2} incl. a sign-binary l0=8 tensor and a
  claimless tensor), 7 contribs (two sharing a col kernel), the
  SAME (group, claims, witness) both ways.
  THE SEMANTIC KEY (recorded before building, PROVEN by the legs):
  the built claim functional factors RANK-16 over the per-tensor
  (row-group x in-group) grid via the BH row-column split PLUS the
  eq hi/lo split of the row kernel —
    Phi_0[i,j] = sum_e b_e[i] a_e[j],
    b_e[i] = alphaHi[i][e] (hi-side alpha contraction),
    a_e[j] = radix_l sum_d (lo[r] *K Y^d)[e] conjQ[cb][d]
  — so the front end consumes FACTORED contribs (hi, lo, col; scale
  folded into hi; the GroupClaims API's materialized product is what
  the oracle eats; invariant scale*K eq == hi *K lo asserted on every
  row). The per-tensor two-tier grid is CONTIGUOUS chunking (row
  group = g_rows whole matrix rows = width rings), so fold + inner
  commits ride fold_chunks_ntt_gen / matvec_modq_small_multi_gen
  UNCHANGED. Greyhound two-check structure, FS order v-before-c:
  (a) fold-binding A_t w_t == sum_i c_i u_{t,i} (+ tier-2 U rebind),
  (c) consistency a_e.w == c.v_e per (contrib,e), (b) claim
  sum_{m,e,i} b_e[i] v_e[i] == h_cur.
  DIFFERENTIAL LEGS (all PASS, fixed seeds):
  1. b_row images: two-tier claim layer == built GroupEvalProof.b_rows
     BYTE-IDENTICAL (16 rows; ct = v_batch), oracle bg_prove_group +
     bg_verify_group ACCEPT on the same instance.
  2. per-contrib MLE claims: single-contrib kernel-pass rows_m sum to
     b_rows; the two-tier reconstruction H_m = sum_e sum_i b_e[i]
     v_e[i] == sum_c alphas0_c rows_m[c] POLY-EXACT, 7/7.
  3. the batched opening target: h_cur two-tier == the built b_rows
     route == sum_m H_m at the same drawn alphas.
  REJECT LEGS (6): w/v/u/b_rows wire tampers (FS divergence or
  binding: tt-fold-binding / tt-u-binding / tt-ct-row-gate) + two
  MALICIOUS-PROVER legs (tamper + honest refold under the tampered
  transcript so binding passes): lying v -> tt-consistency, lying
  b_rows non-ct coeff -> tt-claim — both semantic checks provably
  fire.
  WALLS AT 2^19.6 [WSL-BOX NOISY-SHARED; identity is the deliverable,
  not the walls]: oracle bg prove+verify 16.6s 1T / 8.5s 7T (forced
  2-level); two-tier prove 19.8s 1T / 16.2s 7T + verify 1.9s 1T —
  the tt prove at this small shape is NOT yet ahead (the v-passes
  recompute per-contrib Q without col-kernel sharing, and 2^20 is
  below the memo's >= 2^22 acceptance shape; rung 3 measures
  properly with phase attribution). Peak RSS 2.4 GiB.
  OPEN (recorded, not guessed): (i) the front end requires ALIGNED
  tensors (cols % D == 0 — every real-rig tensor; the misaligned
  battery shapes would need the generic per-ring branch, linear for
  the verifier); (ii) rows must admit a power-of-2 g_rows for the eq
  hi/lo split (real tensors: rows = T or model dims — 512/768/2048
  all fine at some g); (iii) the real composed-pass kernels are
  materialized Vec<KElem> — whether every real contrib's row kernel
  is a genuine eq product (numerically recoverable via kf.inv +
  verified) is a rung-3 question; a non-product kernel would force
  the g_rows = 1 unbalanced grid for that contrib.
  Gates at commit: build green, diff-battery green, uperf-s digest
  3752cba4.. unchanged, freeze-check 98 ok + expected panic.

- 2026-08-27/28 RUNG 3 — THE MEASURED S4 VERDICT (the ladder ran
  detached 2^22/2^23 x 1T/7T; integrated by the orchestrator; walls
  [WSL-BOX NOISY-SHARED], counted rows box-independent):
  * Criterion 1 (claims bit-for-bit): **GO** (rung 2).
  * Criterion 4 (the 8B two-tier planner gate): **GO** (rung 1).
  * Criterion 2 (>= 5x prove-group-equivalent at >= 2^22):
    **NO-GO** — measured 1.10x core at 2^22 1T (25.44 vs 27.91 s),
    1.08x at 2^23 1T; at 7T the two-tier is SLOWER than the built
    path (0.65x / 0.66x core; 0.56-0.61x with commit-class).
  * Criterion 3 (1T verifier level-0 sub-second): **NO-GO** —
    tt_verify 3.93-4.66 s vs the built path's psi0 level-0 term
    0.99 s (2^22) / 2.05 s (2^23).
  * Bytes: the spike-clear form is 45.3-57.6 MB vs the built
    GroupEvalProof's 179-181 KB (production would recurse u/v/w —
    the clear u/v planes are the spike's measured overhead — but
    no measured recursed form exists to cite).
  * THE CAUSE (already flagged by rung 1's honesty row): the
    memo's cost model counted only the w-digit recursion input
    (~19K rings); the real tier-2 input is DOMINATED by u-digits —
    1.65M rings at the 8B weight sqrt, ~85x the modeled work. The
    sqrt serving trick as specified in U_PERF3_HEADLINE_ROUTES.md
    §4.2 does not clear its own bar at these shapes.
  * PER THE MEMO'S OWN ACCEPTANCE TEXT, this is the RULING-GRADE
    outcome it named: "the honest fallback is Stage A + (iii) +
    route 3 (~100-160 s/board class) and the headline stays out of
    reach on this line." Stage A proper (the descent replacement:
    lanes DD/EE — 13.5x counted, 2.7x wall and climbing, the
    aggregate's 13.3x rounds / 6.6x wire) is UNAFFECTED by this
    verdict; what fails is the sqrt SERVING front end's >= 5x
    claim. AWAITING VICTOR: accept the fallback route as the
    headline posture, or commission a redesigned front end that
    addresses the u-digit domination (a new design memo, not a
    patch to this spike).
  * Floor at close: diff-battery 15.78 s green; uperf-s digest
    3752cba4.. unchanged.

## Agent HH status (wt-uperf3-hh) — round 5

STATE: OPEN (2026-08-28) — the W-8 memory diet (the "fits 128 GB at
8B" milestone's diet half). SPEC: U_PERF3_MVP8B_SCALING.md W-8 row
verbatim; acceptance at EVERY rung = the two identity anchors below
BYTE-IDENTICAL (a memory diet is transcript-preserving or it is
nothing) + the floors (build, uperf-pc diff-battery, freeze-check
102-ok-rows form, uperf-s digest 3752cba4..).

RUNG PLAN (order = the W-8 row's effort ranking):
  0. skeleton + BASELINE (this section) [DONE below]
  1. W-8(a) drop `lays` (the i64 BfLayer store) before the group
     proofs; reload byte-identically for the verifier.
  2. W-8(b) A_0 (level-0 CRS) expanded per column block inside its
     consumers — never materialized (CrsColStream + blocked t0
     GEMM + blocked level-1 transport).
  3. W-8(c) flat i8 store for the deeper-level witnesses (DigitCols
     is the pattern; every level base e <= 7 so |digit| <= 64).
  4. the record: measured RSS curve + the counted 8B projection
     (which section-3 terms each fix removes at 32x512).

BASELINE (2026-08-28, WSL box, ZK_THREADS=8,
M125_EXPORT_DIR=results/m125_ffn_export_wsl (main repo), each run
one-at-a-time under flock /tmp/zk-heavy.lock; box otherwise light —
load 1.49 at start, 12.7 GB free; two sibling lanes exist but were
not running heavy jobs during the window; label NOISY-SHARED
applies to walls, less so to peak RSS):
  * uperf-pc full-profile 3 16: accept=true, wall 6.0 s, peak RSS
    1,126,084 KB (1.07 GB); STATEMENT DIGEST 93a987002a7c4b60c3df
    bfc62b7a4f0e5957d8ae2039014ff241e323285fb790; EVAL-PROOF DIGEST
    0ae9cdae66607239a80cc1f1dea36248370edadbe85214144aee7a5250d975be.
  * pass-agg prove 12 64 p0: wall 18.6 s, peak RSS 2,968,604 KB
    (2.83 GB); STATEMENT DIGEST 45fb340517eee2344b44dd40d4e47562d8
    0305eb7c5604c9c6cf61ede37443dc (this rig prints no EVAL-PROOF
    digest; statement + the floors carry its identity).
  * SUPPLEMENTARY uperf-pc full-profile 12 64 (the bk rig at the
    bigger shape, so W-8(a) — a bk_pass_run fix — is measurable
    above 3x16): accept=true, wall 24.0 s, peak RSS 3,091,220 KB
    (2.95 GB); STATEMENT 80763ea537e77cd9cb5c538397af2622044447d6
    54b8e9a34cae3ccad8f3f115; EVAL-PROOF 63f4a3a4320a47260ab8ae3d
    52cfa3656b626fc367af671c6c317300454dec89.
  * Floors at baseline: uperf-pc diff-battery exit 0; freeze-check
    102 ok rows then the EXPECTED panic (bf_read_i8: cannot read
    results/m125_ffn_export/layer00_X.bin — freeze-check ignores
    M125_EXPORT_DIR by design, the frozen Mac sidecar is
    authoritative; exit 134 = SIGABRT, the WSL form); uperf-s
    battery 48 legs ok, digest 3752cba4fa08c2ee052475e9f4459e2fc3
    ed0a0c59862468e0c31cbeb165aaae.

NOTE (readers of the W-8 row): the memo's "expand A_0 per column
block ... blocks are independent" needs one correction discovered
on contact with expand_level_matrix_raw: the CRS stream is ONE
sequential SHA-256-counter byte stream walked by a REJECTION
sampler, so entry n's value depends on how many words were rejected
before it — blocks are NOT independently re-keyable. They ARE
independently *resumable*: acceptance is a pure per-word predicate
((word >> shift) < q, ~0.2% rejection), so one cheap counting pass
(generate + count per 8K-word block, discard bytes) gives a prefix
table that locates any (row, col) range's word window exactly; a
column block is then regenerated from its SHA counter range and
walked with a skip — byte-identical values by construction. That is
what CrsColStream (rung 2) implements; cost model unchanged from
the memo (~one extra full generation per consumer sweep).

RUNG 1 — W-8(a) LANDED (2026-08-28): `lays` (the i64 BfLayer store)
dropped before the group proofs (they read w0 + the Phi0Source, not
lays — the W-8 row's parenthetical, confirmed on the code: bg_prove_
group takes group registry + claims + w0 only), REBUILT byte-
identically for the verifier via the factored bk_load_lays (loader +
tamper arms are deterministic functions of the exports + opts, so
reg_v / h0_v / the public-claim MLEs are unchanged — including under
the RangeViolation / WrongTable tamper legs).
  ACCEPT: all five identity anchors BYTE-IDENTICAL to baseline
  (fp3x16 stmt 93a98700 + EP 0ae9cdae; pa12x64 stmt 45fb3405;
  fp12x64 stmt 80763ea5 + EP 63f4a3a4); floors green (diff-battery
  0; freeze 102 ok + expected export panic; uperf-s 3752cba4).
  RSS delta [MEASURED, NOISY-SHARED]: fp3x16 1,126,084 -> 1,125,344
  KB (-0.7 MB); pa12x64 2,968,604 -> 2,968,436 KB (~0, expected —
  (a) is a bk_pass_run fix, the bg rig has no lays drop); fp12x64
  3,091,220 -> 3,091,152 KB (~0). HONEST READING: ~zero at the 125M
  shapes because peak RSS is a high-water mark set in the claim/
  descent phases, where lays are still READ (bk_tree_slots /
  bk_tree_slot_fns build the descent trees from layer values) — the
  fix removes L only from the GROUP phase, exactly as the W-8 row
  prices it ("66 -> 0 GB during the group phase" at 32x512, where
  the group phase is 229 GB as built -> 163). NOTE for the rung-4
  projection: the memo's 3.1 table optimistically shows the DESCENT
  phase too at W+D with (a); as built the descents read lays, so
  with (a) alone the descent-phase peak KEEPS L (250 GB at 32x512)
  — the 184 figure needs lane GG's Stage A (descents replaced) or a
  per-member layer stream (not this lane). Verify-side cost: one
  extra layer load + chain derivation (wall-neutral at these
  shapes: 23.4 s vs 24.1 s fp12x64, within run noise).

RUNG 2 — W-8(b) LANDED (2026-08-28): the level-0 CRS matrices A_0
are STREAMED per column block, never materialized. New additive
eval_proof.rs machinery: `CrsColStream` (the counting pass over the
SHA-256-counter stream -> a prefix table of accepted words per
8K-word block; `cols(c0, c1)` regenerates exactly the SHA counter
range covering a block and resumes the rejection walk with a skip —
the SAME accepted words in the SAME order as expand_level_matrix_raw)
and `transport_level_from_psi_cols` (the fast transport body with
the per-column-independent S combine assembled block by block; the
fast body is its oracle). Bin side: `bg_matvec_chunks_stream` (the
t = A_0 w GEMM per column block, mod-q accumulation of exact window
sums — identical canonical rings by the GEMM contract), `BgA0`
(Mat|Stream) in `BgPre`, and the level-1 transport dispatch.
Defaults: ON at 8192 cols (`ZK_A0_BLOCK`, 0 = materialized
fallback); guarded OFF in oracle mode and for < 2-level schedules
(their floor / tier-z sigma reads A_0 whole). Deeper levels' A stay
materialized (small).
  ORACLE CHECK: `ZK_A0_CHECK=1` full-matrix compare of the stream
  against expand_level_matrix_raw at construction — run at 3x16,
  PASSED on both groups' A_0 (a0check leg, exit 0, digests
  unchanged). This also validated the one spec correction recorded
  at rung 0: blocks are resumable, not independently re-keyable.
  ACCEPT: all five identity anchors BYTE-IDENTICAL (93a98700 /
  0ae9cdae; 45fb3405; 80763ea5 / 63f4a3a4); floors green
  (diff-battery 0; freeze 102 ok + expected export panic; uperf-s
  3752cba4).
  RSS delta [MEASURED, NOISY-SHARED, vs rung-1 tree]:
    fp3x16   1,125,344 -> 1,093,432 KB  (-31 MB)
    pa12x64  2,968,436 -> 2,616,568 KB  (-344 MB, -11.9%)
    fp12x64  3,091,152 -> 2,834,316 KB  (-251 MB, -8.3%)
  (the 12-layer weight A_0 is ~647 MB boxed; the process still
  re-expands A_0 WHOLE once in the VERIFY phase — bg_verify_group's
  level-0 expand_level_matrix_arc is not a named W-8 site, recorded
  as an open item below — so the prover-phase saving, not the full
  A_0, is what the process high-water mark can show at these
  shapes.)
  WALL delta [MEASURED, honest]: fp3x16 6.0 -> 6.2 s; pa12x64
  18.6 -> 19.7 s (+6%); fp12x64 24.1 -> 25.5 s (+6%) — the W-8
  row's "expansion paid ~3x" showing up as ~1-1.5 s at these
  shapes (the counting pass + one regeneration sweep per consumer).
  NOTE: the [UPERF3-HH W-8c] flat-store helpers
  (decompose_polys_*_into, DigitCols::extend_vecs) ride this commit
  INERT in eval_proof.rs (no caller until rung 3) — additive only.

RUNG 3 — W-8(c) LANDED (2026-08-28): the deeper-level witnesses
(`w_cur` in bg_prove_group — W-8(c)'s `Vec<Vec<i64>>`, 1,064 B/ring
boxed) now live in the existing flat i8 `DigitCols` store (128
B/ring, 8.3x): additive `decompose_polys_small_into` (the same
per-ring split appended in the same order, digits asserted into i8
— every level base is e <= 7, alphabet |d| <= 64) + `DigitCols::
extend_vecs`; bin-side `bg_fold_into` (bg_fold_gen's fold + the
VERBATIM l_z budget assert, split written straight into the flat
store — the boxed z intermediate digit rings never exist; the
boxed i64 fold OUTPUT z_all still exists transiently, ~5.9 GB at
the 8B weight level 0 — recorded). The t/h digit families stay
boxed (KBs at every level). The floor is boxed back at the floor
(~1K rings) for the wire form / tier-z helpers.
  ACCEPT: all five identity anchors BYTE-IDENTICAL (93a98700 /
  0ae9cdae; 45fb3405; 80763ea5 / 63f4a3a4); floors green
  (diff-battery 0; freeze 102 ok + expected panic; uperf-s
  3752cba4).
  RSS delta [MEASURED, NOISY-SHARED, vs rung-2 tree]: fp3x16
  -0.1 MB; pa12x64 +5.5 MB; fp12x64 -0.6 MB — i.e. WITHIN NOISE,
  honestly recorded: at the 125M shapes the deeper witnesses are
  0.1-0.4 GB boxed and the process high-water mark sits in the
  claim/descent phases, so the fix cannot move it here. The
  counted 8B win: level-1 witnesses 35.2 + 11.1 GB boxed -> ~5.6
  GB flat (both groups), and every deeper level shrinks 8.3x.

RUNG 4 — THE RECORD (2026-08-28). One more (a)-completion rode this
rung: the VERIFIER's last read of `lays` is the public-claim MLE
check, so the store is dropped a second time before the group
verifies (bg_verify_group takes reg_v + shipped proofs only) — at
12x64 this alone moved the process peak -583 MB, i.e. the high-water
mark at that shape sat in the VERIFY phase (reloaded lays + claim
tables + the verifier's A_0). Digests + floors green as at every
rung.

THE MEASURED 125M-SHAPE RSS CURVE (peak RSS KB, /usr/bin/time -v,
ZK_THREADS=8, flock-serialized, NOISY-SHARED box; each column = the
lane tree at that rung):
  shape    baseline    +a         +a+b       +a+b+c     +a(verify)  total
  fp3x16   1,126,084   1,125,344  1,093,432  1,093,324    974,028   -152 MB (-13.5%)
  pa12x64  2,968,604   2,968,436  2,616,568  2,622,056  2,621,856   -347 MB (-11.7%)
  fp12x64  3,091,220   3,091,152  2,834,316  2,833,716  2,251,012   -840 MB (-27.2%)
  walls: fp3x16 6.1 -> 6.5 s; pa12x64 18.6 -> 20.2 s; fp12x64
  24.1 -> 27.1 s (+8-12%: the ~3x CRS expansion sweeps + the layer
  reload; the W-8 row priced exactly this trade).
  Reading per fix: (a) moves nothing at 125M shapes (peak is in
  claim/descent/verify phases, which read lays) until the VERIFY
  drop lands, then it is the biggest single mover at 12x64; (b) is
  the prover-side mover (-344 MB at pa12x64 ~ the 12-layer A_0
  boxed minus the verifier re-expansion); (c) is invisible here
  (0.1-0.4 GB terms) and counted at 8B below.

THE COUNTED 8B PROJECTION (memo section 1.6/3.1 terms; [COUNTED]
sizes, [MODEL] liveness; phases of bk_pass_run after this lane):
  32x16 (the yardstick — carries the ENTIRE 352M-ring weight group):
    commit L 45.8 + W 45.7 = 91.5 | claim ~95 | descents
    L+W+D(3.8) = 95.3 | groups: lvl-0 W+block ~52, lvl-1 phi_1 35.2
    + s_rings 5.9 + V1flat 4.2 + act-w0 0.6 = ~46 | verify: A_w
    re-expansion 64.4 + reg_v/proofs = ~70 (lays dropped).
    PEAK ~95 GB — **UNDER 128 GB with this lane's diet ALONE,
    descents included** (as built: ~191 GB — the memo's own row).
  32x512 (MVP-1):
    WITH the descents as built: descent phase L 66 + W 63.7 + D 120
    = ~250 GB — NOT under 128 (nor 256); my diet does not touch D,
    and the descent trees READ lays, so (a) cannot clear L there.
    The memo 3.1 descent-row "184 with (a)" is optimistic on this
    point (recorded at rung 1). Lane GG's Stage A is the fix — cite,
    not built here.
    WITHOUT the descents (lane GG lands): the peak moves to
    commit/claim: commit L 66 + W 63.7 = ~130; claim ~135 — 2-7 GB
    OVER 128 as-is. With W-8(d) ZK_W0_REGEN=1 (EXISTS, run flag):
    claim ~71; commit still ~130. With the W-3 act-group split
    (MANDATORY at 32x512 anyway — the act gate fails unsplit),
    committed per split: commit ~ L 66 + W_w 45.1 + one act split
    4.7 = ~116. Groups after (b)+(c): lvl-0 ~72 (W + z_all boxed
    transient 5.9 + flat store), lvl-1 ~64 (phi_1 35.2 + s_rings
    5.9 + V1flat 4.2 + act w0 18.6). Verify ~70.
    VERDICT: **~116 GB peak — UNDER 128 — via (a)+(b)+(c) [this
    lane] + Stage A [lane GG] + ZK_W0_REGEN [exists] + W-3 [already
    mandatory]**; without the regen/W-3 pieces the commit/claim
    phases hold ~130-135 and the milestone is MARGINALLY missed.
  T9's old 12x512-under-14-GB goal: baseline CPU-only was 11.1 GB
  (already under); the diet removes the ~2 GB A_0 + ~0.5 GB V1
  boxed terms from the prover phases — projected ~9-10 GB, NOT
  measured here (12x512 runs excluded by the shared-box rule this
  round; measure on a quiet window).

NEW FIRST-ORDER TERM the projection surfaced (not in memo 3.1's
component list): phi_1 — the level-1 aggregated functional
(transport phi_next, boxed MOD-Q rings, same ring count as the
level-1 witness): ~35.2 GB (w) + ~11.1 GB (a) at 8B, alive through
the level-1 h pairs and the level-2 transport. It cannot go i8
(mod-q values); its two consumers are both windowable (the
Phi0Source / CrsColStream patterns generalize) — the natural NEXT
diet rung if the level-1 group phase must shrink below ~64 GB.

OPEN ITEMS / NOT DONE HERE:
  * bg_verify_group still expands A_0 WHOLE at level 0 (verify
    phase ~70 GB at 8B — bounded, NOT a 128 GB blocker after the
    verify-side lays drop; the same transport_level_from_psi_cols
    helper applies if a later rung wants it — the site is outside
    this lane's named-sites grant).
  * The commit-phase per-group build->precommit->free ordering
    (~111 GB without W-3) — a small bk_pass_run liveness reorder,
    ~0.5 d, only needed if W-3 lands late.
  * bg_pass_run (the pass-agg rig) kept its lays end-to-end — (a)
    is spec'd against bk_pass_run only; the bg rig gets (b)+(c)
    through the shared bg_precommit/bg_prove_group.
  * z_all (the boxed i64 fold output inside bg_fold_into) is a
    ~5.9 GB transient at the 8B weight level 0 — a fold-into-flat
    kernel would remove it (not priced by the W-8 row; minor).

STATE: DONE (2026-08-28) — rungs 0-4 landed, one commit each, all
pushed on uperf3-hh; every rung transcript-preserving (five digest
anchors byte-identical at every commit) with floors green.
