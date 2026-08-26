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
