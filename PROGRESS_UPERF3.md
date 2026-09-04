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

## Agent GG status (wt-uperf3-gg) — round 5

STATE: DONE (2026-08-28; rungs 0-5 all landed same day: R0 b0f9afd,
R1 02bce92, R2 ed7fdd7, R3 3aa8ad3, R4 4feb066, R5 = the close
commit). LANE SUMMARY — Stage A INTO THE REAL PASS: (1) the object
map reconciles EXACTLY with memo §1.1 at 12x512 (all rows + totals +
the 31,116 aux rings); (2) the one-family differential on real 3x16
grounds EVERY served claim on both sides bit-for-bit against the raw
committed data, tampers reject both ways; (3) the COMPOSED 3x16 pass
ACCEPTS behind the selector in all three modes (range / full /
masked) with bk_pass_run untouched (default byte-identical, floors
green at every commit) — descent transcript 600,960 B -> 26,320 B
(full) at 3x16; (4) the O-4 mask rides at pass level with the mask
coefficients REALLY committed (u_0-bound, not the EE stand-in) and 4
tamper legs reject at named gates; (5) the 12x128 A/B: bytes 2.15x
smaller, walls par on this CPU build, and the MEMORY hypothesis
fails honestly — peak 1.9x HIGHER selector-on and full mode OOMs
the 15 GiB box (the h-commit finding measured). TWO FINDINGS FOR
THE RULING: (F1) COMMIT GROWTH the memo does not carry — width
planes must be committed to close the off-table gap (+4.5M rings at
12x512, +58% act) and the naive h commit at l0_q=16 adds 25.2M
rings (act n_0 7.85M -> ~37.5M counted; measured as the 12x128 OOM)
— options: a cheaper h class/side channel, or Stage-A round 1 =
range-only (84/96 cols, the unambiguous win) with silu descents
kept; (F2) the memo §2.1/§2.4 h ORDERING IS CIRCULAR (h depends on
alpha; u_0 is nonlinear — that0 is a digit decomposition) — the
working amendment implemented here is a THIRD "act-h" group
committed mid-transcript (one opening per group preserved; the pass
gains a group). OWNS: NEW ring/stage_a.rs, one line in ring/mod.rs,
the [UPERF3-GG] bin section + the `uperf-a` dispatch line, this
status section. Everything else read-only — bk_pass_run, zc_range,
manifest.rs untouched.

FLOORS at every commit: release build; uperf-pc diff-battery green;
uperf-s battery digest 3752cba4.. unchanged; uperf-s agg-battery
digest 46234986.. unchanged; freeze-check 102 ok rows then the
expected BK panic (WSL box).

PLAN (one commit per green rung, prefix "U-PERF3 GG:"):
- [x] R0 SKELETON: this section; empty ring/stage_a.rs + its mod
  line; the `uperf-a` GG dispatch wrapper + [UPERF3-GG] bin section
  stub (`map` prints not-built).
- [x] R1 THE OBJECT MAP (no proving): `uperf-a map [layers] [t]` —
  from the REAL pass structures (bk_pair_specs + the bk_pair_claims
  shape) at 12x512 and 3x16: every descent-pair family with instance
  count, depth/dt, the claims it serves to the opening (counted), and
  its Stage-A replacement instance (zc_agg / LogUp per memo §2.3/2.4).
  Reconcile against memo §1.1's counted rows; mismatches are FINDINGS.
- [x] R2 ONE-FAMILY DIFFERENTIAL on real 3x16 (M125_EXPORT_DIR): the
  simplest rem-w pair proved BOTH ways at fixed seeds — the descent
  pair (bk_pass_run call sequence, the oracle) and the aggregate
  zero-check — with every served claim checked bit-for-bit against
  the raw committed values (the zc_range_open_check pattern on the
  zc side; the direct part-functional evaluation on the descent
  side). Exact compared values recorded here.
- [x] R3 ALL FAMILIES + the composed 3x16 pass behind the selector
  (own driver in the [UPERF3-GG] section; bk_pass_run untouched):
  full prove + verify ACCEPT with every descent family replaced;
  transcript delta recorded (rows/bytes changed — a protocol change
  by design, selector-only).
- [x] R4 O-4 masked variant at pass level + tamper legs (flipped
  mask / tampered claim / tampered round must reject).
- [x] R5 the A/B walls + /usr/bin/time -v peak RSS, selector on/off,
  at 12x128 (coordinator-scoped 2026-08-28; 12x512 DEFERRED WITH
  CAUSE — see the R5 evidence) [WSL-BOX CPU NOISY-SHARED].

OPEN QUESTIONS (conservative readings taken, flagged not guessed):
- OQ-1 `uperf-a` NAME COLLISION: the brief says "register a uperf-a
  stub arm", but `uperf-a` has been the [UPERF2-A] descent
  bench/battery arm since U-PERF2 (uperf_a_main; the design memo
  §5.3 itself cites `uperf-a descent-bench`). Resolution: the GG
  wrapper `uperf_a_gg_main` takes the dispatch line (granted to this
  lane), handles the new Stage-A subcommands, and DELEGATES the
  legacy subcommands to uperf_a_main verbatim (their stdout
  unchanged); unknown/no-arg prints both usage lines.
- OQ-2 RANGE PLANES (transcript-affecting; memo §2.3 subtlety (1)):
  the pass commits balanced base-2^e0 digits per tensor; a
  zero-check on THOSE limbs alone cannot close the committable-but-
  off-table gap (bk_range_violation's leg). The spike/EE-validated
  form is w width-specific planes under the house sign-binary
  alphabet (e0 = 1, deg_f 3) — that is what R2/R3 use (committed as
  new aux tensors under the selector, replacing bk-m/bl/wm/tm).
  KNOWN GAP carried to the O-3 write-up: sign-binary w planes prove
  membership in [-(2^w - 1), 2^w - 1], not [0, 2^w) — the {0,1}
  booleanity alphabet that closes the negative side is the design
  ruling EE's lane already flagged (bit-granularity commitment).
  Recorded, not silently widened.

R5 EVIDENCE (2026-08-28, WSL box, CPU build, ~22T default,
NOISY-SHARED; /usr/bin/time -v peaks; all runs under flock):
- THE A/B TABLE at 12x128 (same box, same binary, selector off/on):

  | leg | accept | commit | prove | verify | bytes | descent/stage-a B | peak RSS |
  |---|---|---|---|---|---|---|---|
  | oracle `table-descent prove 12 128 p0` | TRUE | 13.3s | 94.8s | 5.3s | 1,372,775 | 952,128 (descents) | 4,481 MiB |
  | `uperf-a pass 12 128 range` | TRUE | 17.5s | 109.4s | 12.0s | 637,691 | 215,888 (2 silu descents 187K + zc 29K) | 8,621 MiB |
  | `uperf-a pass 12 128 full` | KILLED (signal 9, OOM) at ~2:58 | - | - | - | - | - | 14,777 MiB (box ceiling) |

  Groups at 12x128: weight n_0 3,538,944 both legs; act n_0
  oracle-reg ~2.36M -> 3,091,604 selector-on (+planes); full mode
  adds act-h n_0 6,291,456 (2x the act group) — the OOM driver.
- VERDICT (honest, ruling-grade): (i) BYTES: 2.15x smaller
  selector-on (descent transcript 952 KB -> 216 KB, of which 187 KB
  is the two KEPT silu descents — the range replacement itself is
  ~45x on its share). (ii) WALLS: roughly par on this CPU build
  (the zc E_4 prototype kernels + the +29% act opening offset the
  descent savings — consistent with the spike's kernel-quality
  caveat; the counted win needs DD-class kernels and/or the GPU
  path). (iii) MEMORY: the rung's hypothesis ("the descent-pair
  memory vanishes from the peak") FAILS at this shape with the
  naive layouts — peak 1.9x HIGHER selector-on: at t=128 the trees
  were only ~a few hundred MB while the Stage-A side pays the
  planes witness + act growth + zc table residency; and full mode
  OOMs the 15 GiB box outright (the act-h group alone is 2x act —
  the R1 h-commit finding now MEASURED at pass level).
- 12x512 DEFERRED WITH CAUSE: range-mode projection from the
  measured 12x128 peak (act 12.4M rings = 4x, claim tables 4x,
  nrw-88 zc transient ~5 GB) lands >= the 15 GiB box under
  NOISY-SHARED; full mode is excluded by the measured 12x128 OOM.
  Prerequisites named: lane HH's diet on the shared phases + a
  ruling on the h/planes commitment layout (R1 finding). The
  descent side's 12x512 CPU baseline also untaken (same box
  courtesy). No number faked; the counted deltas are in R1.
- floors: diff-battery 15.38s green; 3752cba4.. / 46234986..
  unchanged; freeze-check passed.

R4 EVIDENCE (2026-08-28, WSL box, NOISY-SHARED):
- The O-4 masked variant AT PASS LEVEL (`uperf-a pass 3 16 masked`,
  ACCEPT TRUE): per range class a private ZcAggMask (EE's M1 g-mask
  in E_4, deg 4) drawn from ProverRng, its coefficients COMMITTED
  as an act tensor (zca-mk-*, K-coord rows at the blinder class,
  rows padded to the value-ring grid) — mask-then-fold holds via
  u_0(T_act) inside h0, so EE's commit_absorb stand-in is replaced
  by the REAL commitment binding; the prover runs
  zc_agg_prove_masked and serves G + g_m(x*); the verifier runs
  stage_a::zc_agg_verify_masked_served (REIMPLEMENTED in
  stage_a.rs: zc_range's zc_agg_verify_masked pins against a
  verifier-held mask copy — at pass level the mask is private, so
  the two pins become OPENING CLAIMS over the committed mask
  tensor: hypersum = [2^n, 2^(n-1)..] weights, final = [1,
  x*_t^(d+1)..] weights — the bk mask_claims idiom carried to the
  aggregate; zc_range untouched per the ownership rule). +16 mask
  claims at 3x16 (2 per class x 8 classes), 427 claims total,
  bytes 526,090 (vs 525,834 unmasked — the two served E-values per
  class).
- Tamper battery (`uperf-a pass-battery 3 16`): masked honest
  ACCEPT + 4 REJECTS, each at a NAMED gate: mask-served (flipped
  served g_m(x*)) -> zc-agg:nrw-88 (the masked final identity);
  mask-commit (flipped COMMITTED mask coefficient, ct rows forced
  — the BD WrongC shape) -> floor-target (the act group's floor
  chain); claim (flipped stacked claim) -> zc-agg:nrw-88
  (recombination/final identity); round (flipped round-poly node)
  -> zc-agg:nrw-88 (the round chain). All asserted.
- Regression: range + full modes re-run, both still ACCEPT
  (525,834 / 584,786 B unchanged).
- floors: diff-battery 15.43s green; 3752cba4.. / 46234986..
  unchanged; freeze-check passed.

R3 EVIDENCE (2026-08-28, WSL box, NOISY-SHARED):
- The selector: `uperf-a pass [layers] [t] [range|full]` — an OWN
  composed driver in the [UPERF3-GG] section mirroring bk_pass_run
  (claim layer / publics / nu-assembly / group proofs verbatim
  reuse); bk_pass_run itself untouched, so the DEFAULT path is
  byte-identical by construction (floors below). Own transcript
  domain "uperf3-gg-pass" + own h0 (statement digest + gg map bytes
  binding ALL group inventories + both u_0s).
- cmd: `uperf-a pass 3 16 range` — ACCEPT TRUE (full prove +
  verify): the 7 range/narrowing families at 3x16 replaced by
  zc_agg aggregates over committed width-w bit-plane tensors
  (strided member layout r*cols_pad + c — the descent tree's own
  alignment, so the rem claim lands on the MEMBER tensor as
  to_k(cc[i][w]) - offset*S_eq); silu pairs keep the frozen
  descents; NO stand-ins — every Stage-A claim grounds through the
  act opening (bg_prove_group's honest-ct row assert is the gate
  and it holds). DELTA: descent pairs 600,960 B -> 141,264 B (the
  remaining 128,000 B is the two silu descents; the range share
  473 KB -> 13.3 KB); total 985,142 -> 525,834 B; act n_0 79,477
  -> 102,276 (+29%, the committed planes).
- cmd: `uperf-a pass 3 16 full` — ACCEPT TRUE with EVERY descent
  family replaced: descent pairs 600,960 B -> Stage-A 26,320 B
  (22.8x), total 985,142 -> 584,786 B; claims served 1,140-ish
  descent-derived -> 231 (225 act/weight + 6 act-h). THE THIRD
  GROUP: h cannot ride u_0(T_act) (h depends on alpha; u_0 is
  NONLINEAR in the witness — that0 is a digit decomposition — so
  the memo §2.1/§2.4 ordering is CIRCULAR; finding). Resolution
  implemented: an "act-h" commitment group committed
  mid-transcript (u_0(T_h) absorbed after the silu alphas, before
  any rho — mask-then-fold holds), served by its own single
  opening (E-O2-BB preserved per group; the PASS gains a third
  group + 173,896 B of opening bytes; act-h n_0 196,608 rings at
  3x16 — the R1 h-cost finding in composed form: the h GROUP is
  2x the act group itself). Walls (NOISY-SHARED, small shape):
  range mode prove 12.4s == oracle 12.4s; full mode 20.8s (the
  act-h opening dominates at this scale — h-class cost, not
  sumcheck cost).
- Serving forms pinned by the driver (the new transcript rows):
  planes claims (block row kernel x eq_lo at r_col over the
  planes tensor), member rem claims (to_k(cc)-offset*S_eq), LogUp
  h_sum/h(x*) claims (act-h, ones/eq kernels x ypow), key(x*)
  claims (prim + Y-scaled image member parts), table_sum claims
  (inv(alpha-t_j) weights over the per-column m block), stacked
  zc claims + LogUp finals/served values absorbed before the nus
  (CRB-N5 kept).
- floors: diff-battery 15.33s green; 3752cba4.. / 46234986..
  unchanged; freeze-check passed (default path byte-identical).

R2 EVIDENCE (2026-08-28, WSL box, NOISY-SHARED):
- cmd: `uperf-a diff rem-w6 3 16 205` (also run: nrw-88 — the
  multi-tree + pad shape; nrw-z — the nd padded-2^14 shape). ALL
  LEGS GREEN on each.
- EXACTLY WHICH VALUES ARE COMPARED (the differential's contract):
  (a) DESCENT ORACLE (bk_pass_run's per-pair call sequence verbatim:
  alpha = first challenge, bk_build_aux blinders/masks/counts,
  bk_tree_slots -> aligned_witness_tree + blinded_table_tree,
  masked_gkr_prove both sides, the PASS-form verify — zero-mask
  shells, no pins — + root cross-checks + transcript parity, claims
  rebuilt by bk_pair_claims from the VERIFIER's re-derived
  endpoints): every served claim is grounded by the eval-proof
  STAND-IN — claim.value == sum_parts(scale x row^T M col) evaluated
  directly on the raw committed grids (member tensors via
  bf_entry_values, m/bl/wm/tm via the bk_build_aux value vectors),
  EXACT K-field equality, 88/88 claims (rem-w6; 96/96 nrw-88, 92/92
  nrw-z). (b) ZC LEG ([UPERF3-EE] zc_agg_prove/verify at E_4, e0=1,
  one aggregate per shape class, w bit planes per member column
  built by stage_a::range_planes from the SAME bf_entry_values
  arrays — shared committed-code digest printed): every served
  stacked claim col_claims[i][k] == base_mle_eval(plane_k | rem,
  r_col) BIT-FOR-BIT (7/7 rem-w6 m=1; 54/54 nrw-88 m=6 a=3; 27/27
  nrw-z m=3 a=2), verify green, prover/verifier transcript parity.
  The two legs serve DIFFERENT claim forms at different points by
  design (the EE lane's FS note); the common ground is the raw
  committed data both sides are checked against, byte-identical by
  the shared code digest.
- Tamper mini-legs (the BK RangeViolation shape, +2^w at one code):
  descent REJECTS at the root cross-check (mass mismatch); zc
  truncated-plane cheat REJECTS at zc_agg_verify (recomposition
  breaks — the top bit cannot be presented). Both asserted.
- Walls (informational, NOISY-SHARED): rem-w6 zc prove 0.02s vs
  descent trees+prove 0.09s; nrw-88 0.19s vs 0.29s; peak RSS
  267-313 MiB.
- floors: diff-battery 15.64s green; 3752cba4.. / 46234986..
  unchanged; freeze-check passed.

R1 EVIDENCE (2026-08-28, WSL box, NOISY-SHARED; structure-only, no
proving, no walls):
- cmd: `uperf-a map 12 512` (M125_EXPORT_DIR set) — the OBJECT-MAP
  VERDICT: **memo §1.1 reconciliation ALL ROWS MATCH** (per pair:
  member cols / real trees / l / pads / wit depth / tab dt / derived
  B, engine-derived from bk_pair_specs + plan_pair_trees +
  pair_expected_bytes; totals 96 cols / 45 trees / 57 l (12 pads) /
  1,083,456 B exactly). Retired aux ring count 31,116 == memo §1.3's
  "aux 31,116 = 0.40%" row. Claims served today (counted from the
  bk_pair_claims structure, per pair 2(D-1)+2(D-2) mask opens per
  side + wp/wq/tp/tq): 1,140 claims at 12x512, 856 at 3x16.
- cmd: `uperf-a map 3 16` — the 3x16 inventory: 9 pairs live (rem-w5
  ABSENT at 3 layers), 24 member cols, 14 real trees; rem-w6..w10
  and both nrw pairs present; rem-w8 is a MIXED-SHAPE pair (nf 2^15
  + nd padded 2^14 members) -> the Stage-A schedule gives one
  zc_agg per (pair, shape class): 10 range aggregates + 3 SiLU
  LogUp columns at 3x16 (14 aggregates + 12 LogUp cols at 12x512).
- Stage-A replacement schedule (printed as the table): range pairs
  -> ZC-AGG (e0=1 sign-binary planes, w = t_rows.log2, instance
  axis a = ceil(log2 m)); silu pairs -> LogUp h+m (Had prover) per
  member column. Served-claim swap 1,140 -> 761 MLE claims at
  12x512 (199 at 3x16).
- FINDING (ruling-grade input, quantifies memo §5.1's "wash" risk):
  the commit-side growth the memo's "range facts commit nothing
  new" line does NOT carry for the q31 pass. (a) Closing the
  committable-but-off-table gap (the BK RangeViolation gate)
  requires committing width-w planes — the already-committed
  balanced base-2^e0 limbs of the remainder tensors CANNOT close
  it (any value in the gap has valid house digits). Counted cost:
  +4.52M digit rings at 12x512 (+58% of act n_0 7.85M). (b) The
  SiLU helper h's K coordinates commit at the blinder class
  (e0=2, l0_q=16): +25.2M digit rings at 12x512 — the naive h
  commit alone TRIPLES the act group. Together n_0 7.85M ->
  ~37.5M [COUNTED approx]. Options for the ruling (not taken
  here): a cheaper committed class/side channel for h; or Stage-A
  round 1 replacing only the 8 range pairs (84/96 cols, the
  memo's own fulcrum) and keeping the 2 SiLU descents. Rungs 2-4
  proceed at 3x16 where the volumes are small (+0.23M rings)
  and the composed-pass evidence is unaffected.
- floors: diff-battery 16.65s green; uperf-s digest 3752cba4..
  unchanged; agg digest 46234986.. unchanged; freeze-check passed
  (BK rows stable with the WSL export).

R0 EVIDENCE (2026-08-28, WSL box, NOISY-SHARED):
- cmd: release build green; `uperf-a map` prints the stub; legacy
  `uperf-a` (no args / descent-*) delegates with its usage intact.
- floors: uperf-pc diff-battery green (O1 4/4, O2 35/35, O3 63/63,
  O5 12/12, E2E 2/2, 15.01 s); uperf-s battery 48 legs digest
  3752cba4.. unchanged; agg-battery 136 legs digest 46234986..
  unchanged; freeze-check WITH M125_EXPORT_DIR: 102 ok rows AND the
  BK rows stable ("freeze-check passed" — no panic with the WSL
  export present; the brief's expected-panic form is the no-export
  invocation).
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

## ROUND 6 — MVP-2 OPENS + DIET 2 (opened 2026-08-29; Victor
## console: spin up the tasks that can run while the Mac works)

Ground: round 5 merged (Stage A integrated; the diet landed; the S4
line closed); the composition ladder measuring; the five rulings
pending do NOT gate these lanes (X-S1 is explicitly no-freeze-move;
diet 2 is transcript-preserving by definition). Floors at every
commit: diff-battery, freeze-check 102 ok, uperf-s 3752cba4..,
agg 4623..96, uperf-w 23/23.

### Lane JJ — spike X-S1: the integer softmax chain (wt-uperf3-jj) — RUST+PY, MVP-2's opener
OWNS: NEW ring/attn_softmax.rs (+ mod line), a `uperf-x` bin
section + dispatch line, additive exp-member machinery in
lookup.rs ONLY if the frozen families stay byte-identical (else
keep members lane-local), "Agent JJ status". SPEC:
U_PERF3_ATTENTION_STATEMENT_DESIGN.md §5.3 VERBATIM (§2.3 item 1 +
§1.3 for the chain; ATTENTION_INTEGER_SPEC.md §2.4-2.5 the op
semantics; scripts/attention_spec_spike.py = the value oracle).
One committed (head, row) softmax chain end to end through the
as-built claim machinery: s8 -> m/d/zsel (pins + w8/w1 range facts
+ attainment zero-check) -> E via a REAL LookupAt fused pair with
a frozen exp member -> Sum by masked thin sumcheck -> P/rho/sigma
by the division zero-check with broadcast divisor + off-support
pin — one rolling transcript, PW-3/PW-4 wired for real.
ACCEPTANCE = the memo's four: honest ACCEPT; the AT-O8/AT-O9
tamper battery (m over/under, zsel two-hot/off-support,
off-support P != 0, shifted mask, wrong exp member — each rejects
at its PRE-REGISTERED gate); values bit-equal the python reference
at the same seed; the Stage-A leg (the row's range facts through
zc_range, claims == the descent oracle).

### Lane KK — diet 2: phi_1 windowing + the verifier A_0 site (wt-uperf3-kk) — RUST
OWNS: the phi_1 consumers + the verifier A_0 expansion site in the
bin, additive eval_proof.rs helpers, "Agent KK status". SPEC: lane
HH's findings (its ledger status): (a) phi_1 — the level-1
aggregated functional (~35+11 GB boxed at 8B, MISSING from the
scaling memo §3.1) — both consumers windowable; (b) the verifier
still expands A_0 whole (~70 GB phase at 8B) — HH's CrsColStream
helper applies, the site was outside HH's grant. ACCEPT: the HH
discipline verbatim — statement + EVAL-PROOF digests IDENTICAL at
3x16 and 12x64 at every rung (transcript-preserving only; any
digest move = revert + record); RSS before/after per fix; the 8B
projection updated.

### Orchestrator note 2026-08-29 — the composition ladder (diet x Stage A, the first combined-binary measurement) [WSL-BOX NOISY-SHARED: agent lanes building concurrently]

`uperf-a pass <shape> range` on the round-5 MERGED tree (HH's diet
active + GG's Stage A), oracle and Stage-A modes in one process,
/usr/bin/time -v, flock:

| shape | mode | commit/prove/verify (s) | bytes | process peak RSS |
|---|---|---|---|---|
| 12x64 | oracle | 10.8 / 67.8 / 5.4 | 1,308,775 (descents 890,304) | 5.2 GiB (both modes) |
| 12x64 | Stage-A | 13.6 / 77.8 / 9.6 | 622,011 (2.10x smaller) | " |
| 12x128 | oracle | 12.9 / 97.1 / 6.6 | 1,372,775 (descents 952,128) | 7.85 GiB (both modes) |
| 12x128 | Stage-A | 17.8 / 112.1 / 14.7 | 637,691 (2.15x smaller) | " |

Reading: the composition ACCEPTS at both shapes (the two round-5
lanes coexist correctly); bytes hold at 2.1-2.15x smaller; prove
+15% (CPU, the known trade at 125M scales where descents are cheap);
the combined-process peak at 12x128 (7.85 GiB, INCLUDING the oracle
phase) sits BELOW lane GG's pre-diet Stage-A-only 8.62 GiB — the
diet reaches Stage-A mode too. The 125M shapes remain the WRONG
place to see Stage-A's memory win (descent pairs here are ~1 GB;
at 8B they are 120 GB) — the F1 ruling input is: range-only Stage A
composes cleanly with the diet TODAY, and every counted 8B term
says the composition is what fits 128 GB.
## Agent KK status (wt-uperf3-kk) — round 6

STATE: OPEN (2026-08-29) — DIET 2: (a) phi_1 windowing (the level-1
aggregated functional, ~35.2 + 11.1 GB boxed mod-q at 8B — the
first-order term HH's projection surfaced, NOT in memo 3.1's
component list) and (b) the verifier-side A_0 expansion
(bg_verify_group's level-0 expand_level_matrix_arc, HH's recorded
open item — CrsColStream applies directly). ACCEPTANCE at EVERY
rung: the identity anchors BYTE-IDENTICAL (fp3x16 stmt 93a98700..
+ EP 0ae9cdae..; the 12x64 digests captured at rung 0 below) + the
floors (build; diff-battery; freeze-check 102 ok + expected export
panic; uperf-s battery 3752cba4..; uperf-s agg-battery 46234986..).
A memory diet is TRANSCRIPT-PRESERVING ONLY: any digest move =
revert the rung, record the failure, do NOT fix forward.

RUNG PLAN:
  0. skeleton + BASELINE (this section): /usr/bin/time -v at 3x16
     and 12x64 under flock; digests + peak RSS captured. [DONE below]
  1. (b) the verifier A_0 through CrsColStream — bg_verify_group's
     level-0 handle becomes BgA0 (Stream when ZK_A0_BLOCK > 0,
     !oracle, levels >= 2 — HH's precommit guard mirrored); the
     li == 1 transport consumes it via transport_level_from_psi_cols
     (landed round 5). Deeper levels / the floor keep Mat.
  2. (a) phi_1 windowed at its consumers: the transport's stage-(v)
     assembly DEFERRED into a TransportPhiSource (s/t5/p/q precursor
     rings + the `one(u)` assembly — ~s_rings-sized, 5.9 GB at 8B,
     vs 35.2 GB materialized); consumers read windows: the level-1
     h pairs (blocked GEMM, the level_h_pairs_with_block pattern),
     the level-2 transport + the tier-z floor (both consume phi only
     through Psi — computed per output block from the source).
     ZK_PHI1_CHECK=1 oracle leg (materialize vs the cols transport's
     phi_next) run once at 3x16.
  3. THE RECORD: the RSS curve (HH round-5 numbers + these rungs) +
     the corrected 8B projection (the 32x512 range-only-Stage-A
     ~116 GB with phi_1 + verifier-A_0 removed; the margin verdict
     and the largest remaining term).

OWNERSHIP: bg_prove_group's phi_1 consumer sites + bg_verify_group's
A_0 site (src/bin/ring_matmul.rs); ADDITIVE helpers in
ring/eval_proof.rs. READ-ONLY: manifest.rs, stage_a.rs, zc_range.rs,
ec_kernel.rs, attn_softmax.rs, kfield/gkr/descent internals.

BASELINE (2026-08-29, WSL box, ZK_THREADS=8, M125_EXPORT_DIR=
/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl,
each run under flock /tmp/zk-heavy.lock; NOISY-SHARED label applies
to walls; tree = da327a4, i.e. HH's round-5 diet + GG's Stage A
already merged — this baseline IS HH's rung-4 endpoint):
  * fp3x16: accept=true, wall 6.25 s, peak RSS 974,648 KB; STATEMENT
    93a987002a7c4b60c3dfbfc62b7a4f0e5957d8ae2039014ff241e323285fb790
    EVAL-PROOF
    0ae9cdae66607239a80cc1f1dea36248370edadbe85214144aee7a5250d975be
    — BOTH match the brief's pinned anchors.
  * pa12x64 (pass-agg prove 12 64 p0): wall 19.62 s, peak RSS
    2,608,000 KB; STATEMENT 45fb340517eee2344b44dd40d4e47562d80305
    eb7c5604c9c6cf61ede37443dc (matches HH's).
  * fp12x64: accept=true, wall 25.95 s, peak RSS 2,250,276 KB;
    STATEMENT 80763ea537e77cd9cb5c538397af2622044447d654b8e9a34cae
    3ccad8f3f115; EVAL-PROOF 63f4a3a4320a47260ab8ae3d52cfa3656b626f
    c367af671c6c317300454dec89 (both match HH's).
  * Floors: diff-battery 0 FAIL (16.26 s; the E2E leg "bg_prove_
    group/verify 2/2 identical oracle vs fast" runs a FORCED 2-LEVEL
    schedule — it exercises BOTH my sites); freeze-check exit 0,
    102 ok rows — NOTE: no export panic on this box anymore (results/
    m125_ffn_export now exists in the main repo, so the WSL freeze
    floor is the FULL pass, stronger than HH's expected-SIGABRT
    form); uperf-s battery 48 legs 3752cba4..; agg-battery 136 legs
    46234986...
  * Schedule depths at the test shapes (from the fp RSS trace): BOTH
    groups run 8 levels at 12x64 — the deep-schedule phi_1 consumer
    (the li=2 transport) is exercised by every profile anchor; the
    2-level boundary (h-pairs-only consumer) by the E2E leg.

RUNG 1 — diet2(b) LANDED (2026-08-29): bg_verify_group's level-0 A
is STREAMED per column block (the BgA0 enum on the verify side; the
li=1 transport through transport_level_from_psi_cols — HH's round-5
body, its fast oracle unchanged; deeper levels + the floor keep Mat;
guard = bg_precommit's: ZK_A0_BLOCK > 0, !oracle, levels >= 2).
  ACCEPT: all five identity anchors BYTE-IDENTICAL (93a98700 /
  0ae9cdae; 45fb3405; 80763ea5 / 63f4a3a4); floors green
  (diff-battery 0 FAIL incl. the 2-level E2E cross-verify leg;
  freeze-check 102 ok exit 0; uperf-s 3752cba4..; agg 46234986..).
  RSS delta [MEASURED, NOISY-SHARED, vs rung 0]:
    fp3x16     974,648 ->   869,060 KB  (-106 MB, -10.8%)
    pa12x64  2,608,000 -> 2,040,436 KB  (-568 MB, -21.8%)
    fp12x64  2,250,276 -> 2,165,536 KB  ( -85 MB,  -3.8%)
  (pa12x64 is the big mover: after HH's verify-side lays drop its
  high-water mark sat in the VERIFY phase — reloaded claim tables +
  the whole A_0 re-expansion; the ~647 MB boxed 12-layer weight A_0
  never materializes now. fp12x64's peak has left the verify phase.)
  WALL delta [MEASURED, honest]: fp3x16 6.25 -> 6.25 s; pa12x64
  19.62 -> 19.96 s (+1.7%); fp12x64 25.95 -> 26.11 s (+0.6%) —
  verify-phase walls 0.7->0.8 / 1.3->1.5 / 2.0->2.1 s (the counting
  pass + one regeneration sweep instead of one expansion).

RUNG 2 — diet2(a) LANDED (2026-08-29): phi_1 (the level-1 transported
functional) is NEVER MATERIALIZED on the streamed-A_0 path. The
transport's stage-(v) assembly is DEFERRED into an additive
`TransportPhiSource` (eval_proof.rs: the s/t5/p/q precursor rings +
a_t1 + the layout — `fill` runs the fast/cols bodies' `one(u)`
verbatim per window; `transport_level_from_psi_cols_src` = stages
(i)-(iv) of the cols body verbatim + the source + h_next). The
consumers read windows (bin, bg_prove_group):
  * the level-1 h pairs: `bg_level_h_win` -> `level_h_pairs_phiwin`
    (the level_h_pairs_with_block pattern: r x 1024 phi rings alive,
    the r x r table accumulated mod q over blocks — exact partial
    sums, the in-tree blocked-GEMM identity);
  * the level-2 transport: `compute_psi_from_phiwin` (windows
    partition the OUTPUT index only — each output ring's whole
    k-term MAC runs in one compute_psi call on the same ring values;
    the source's zero pad past n_total = the old resize's) ->
    transport_level_from_psi;
  * the 2-level tier-z floor corner: materialize from the source
    (same rings by the check; 8B schedules are deep — the corner
    never binds at scale).
  Gate: ZK_PHI1_WIN=0 disables (A/B); only consulted on the streamed
  arm, so oracle mode / ZK_A0_BLOCK=0 / < 2-level schedules disable
  both diets together. Deeper-level phis stay materialized (small).
  ORACLE CHECK: ZK_PHI1_CHECK=1 at 3x16 — src.materialize() vs the
  cols body's phi_next FULL-VECTOR EQUAL on both groups (41,568 +
  9,248 rings) + h_next equal; digests unchanged under the check.
  ACCEPT: all five identity anchors BYTE-IDENTICAL (93a98700 /
  0ae9cdae; 45fb3405; 80763ea5 / 63f4a3a4); floors green
  (diff-battery 0 FAIL — the 2-level E2E leg now runs THROUGH the
  windowed path fast-side and stays proof-identical to oracle;
  freeze 102 ok; uperf-s 3752cba4..; agg 46234986..).
  RSS delta [MEASURED, NOISY-SHARED, vs rung 1]: fp3x16 +0.02 MB;
  pa12x64 +0.3 MB; fp12x64 +5.9 MB — WITHIN NOISE, honestly
  recorded: phi_1 at these shapes is 44 MB (3x16 weight) to a few
  hundred MB (12x64) and the process high-water mark sits in the
  commit/claim/descent phases. The counted 8B win: 35.2 (w) + 11.1
  (a) GB of boxed mod-q rings never exist; the source holds the
  s_rings (~5.9 GB, already a counted round-5 term) + KB-scale
  t5/p/q rings.
  WALL delta [MEASURED, honest]: fp12x64 26.11 -> 28.54 s, of which
  the profile attributes ~1.2 s to bg.level-h (8.62 -> 9.84 s x16 —
  the windowed h pairs re-assemble phi per block) and ~0.1 s to
  psi0-factored; the REST of the delta also appears in untouched
  phases (descent-gkr 4.37 -> 4.76, a.round-g 3.51 -> 3.83) = box
  noise. fp3x16 6.25 -> 6.78 s; pa12x64 19.96 -> 20.87 s. Net
  honest cost of (a): ~1-1.5 s at 12x64 (~5%), the price of
  assembling phi windows twice (h pairs + psi) instead of one
  stage-(v) pass.

RUNG 3 — THE RECORD (2026-08-29).

THE MEASURED 125M-SHAPE RSS CURVE (peak RSS KB, /usr/bin/time -v,
ZK_THREADS=8, flock-serialized, NOISY-SHARED box; the KK baseline IS
HH's rung-4 endpoint — GG + HH merged at da327a4):
  shape    HH rd-5 base   KK base    +KK(b) verify-A0  +KK(a) phi1
  fp3x16     1,126,084     974,648      869,060           869,084
  pa12x64    2,968,604   2,608,000    2,040,436         2,040,772
  fp12x64    3,091,220   2,250,276    2,165,536         2,171,604
  Cumulative across the TWO diet lanes (HH + KK) vs the round-5
  baseline: fp3x16 -257 MB (-22.8%); pa12x64 -907 MB (-31.3%);
  fp12x64 -898 MB (-29.7%). Reading per KK fix: (b) is the measured
  mover at 125M shapes (the verify-phase A_0 re-expansion was the
  pa12x64 high-water mark: -568 MB); (a) is invisible here (phi_1 is
  44-400 MB at these shapes, peak sits elsewhere) and counted at 8B.
  Walls: fp3x16 6.25 -> 6.78 s; pa12x64 19.62 -> 20.87 s; fp12x64
  25.95 -> 28.54 s (+2.6 s, of which ~1.2 s attributed by the
  profile to the windowed h pairs, the rest box noise).

THE CORRECTED 8B PROJECTION (HH's rung-4 count, 32x512 range-only
with Stage A [lane GG, merged] + W-3 [mandatory] + ZK_W0_REGEN
[exists], with THIS lane's two terms removed; [COUNTED] sizes,
[MODEL] liveness):
  commit  ~116  (L 66 + W_w 45.1 + one act split 4.7) — UNCHANGED,
                 still the pass peak
  claim    ~71  (regen)
  lvl-0    ~72  (W + z_all transient 5.9 + flat store)
  lvl-1    ~29  (WAS ~64: phi_1_w 35.2 REMOVED; s_rings 5.9 +
                 V1flat 4.2 + act w0 18.6 remain; the act group's
                 phi_1_a 11.1 removed likewise from its phase)
  verify    ~6  (WAS ~70: A_w 64.4 + A_a 30.4 NEVER EXPAND; reg_v +
                 shipped proofs ~5.6 + one resident column block)
  VERDICT: **~116 GB peak — UNDER 128 GB with ~12 GB margin, and the
  margin is now ROBUST: the only phase above ~75 GB is the commit
  phase** (before this lane, claim/lvl-0/lvl-1/verify all sat at
  64-72 GB, each within estimate-drift range of the line). HH's
  caveats stand: without W-3 the commit is ~130, without the regen
  the claim is ~135 (both pieces load-bearing); with the descents as
  built (no Stage A) the descent phase ~250 GB still dominates.
  THE LARGEST REMAINING TERM: the commit-phase BfLayer store L =
  66 GB (i64; W-8(a) drops it only AFTER the commit — it must exist
  to be committed). The next lever is the W-8 row's other arm:
  per-class i8/i32 layer storage (~9.9 GB), which would take the
  commit phase to ~60 GB and make the lvl-0 group phase (~72 GB)
  the pass peak. 32x16 (the yardstick): peak stays ~95 (claim),
  with lvl-1 46 -> ~11 and verify 70 -> ~6.

OPEN ITEMS / NOT DONE HERE:
  * The 2-level tier-z corner materializes phi_1 from the source
    (values identical by ZK_PHI1_CHECK; no floor leg runs tier-z
    through bg_prove_group at exactly 2 levels — the corner is
    small-shape-only, 8B schedules are 8+ levels at 12x64 already).
  * The (a) wall cost (~5% at 12x64) is the double window assembly
    (h pairs + psi); if it matters at 8B the two consumers could
    share one assembly sweep — not built.
  * At 8B the verify side now pays ~2 extra CRS generations (~50 s
    [MODEL] instead of holding 64.4 GB) — the W-8 trade, verify-side.
  * HH's remaining opens stand: bg_pass_run keeps lays end-to-end;
    z_all ~5.9 GB fold transient; the commit-phase L above.

STATE: DONE (2026-08-29) — rungs 0-3 landed, one commit each, all
pushed on uperf3-kk; every rung transcript-preserving (five digest
anchors byte-identical at every commit: fp3x16 93a98700../0ae9cdae..,
pa12x64 45fb3405.., fp12x64 80763ea5../63f4a3a4..) with floors green
(diff-battery incl. the 2-level E2E cross-verify; freeze-check 102
ok exit 0; uperf-s 3752cba4..; agg-battery 46234986..).
## Agent JJ status (wt-uperf3-jj) — round 6

LANE: SPIKE X-S1 — the integer softmax chain through the real claim
machinery (U_PERF3_ATTENTION_STATEMENT_DESIGN.md §5.3 verbatim; the
semantics ATTENTION_INTEGER_SPEC.md §2.4-2.5; the value oracle
scripts/attention_spec_spike.py). MVP-2's opening rung: the ONE
construction with no FFN precedent — the softmax row-normalization
coupling (four fact groups on one rolling transcript).

OWNERSHIP: NEW zkmatrix-rs/src/ring/attn_softmax.rs; one mod line in
ring/mod.rs; the [UPERF3-JJ] bin section + one `uperf-x` dispatch
line in bin/ring_matmul.rs; this ledger section. Everything else
READ-ONLY; frozen registries (lookup.rs / manifest.rs) unmoved.

RUNG PLAN (one commit per green rung, prefix "U-PERF3 JJ:"):
  0. skeleton: this section + empty attn_softmax.rs + mod line +
     `uperf-x` stub arm.                                    [DONE]
  1. `uperf-x chain [seed] [t]` — the Rust value chain bit-equal to
     the Python oracle (acceptance c early): seeded s8 -> mask ->
     m/zsel/d -> E (exp member, spec-header digest) -> Sum -> P/rho/
     sigma; per-tensor sha256 digests printed on both sides.
     DONE 2026-08-29: BYTE-IDENTICAL at (seed 161, T 512), (7, 128),
     (20260811, 512), (42, 32) — CHAIN digest at the contract point
     949d5cee85212bc9..; exp members pinned (eS -1 15903694.., eS -2
     b4f01aca..) from the oracle's own generator; the Python driver
     (scratchpad xs1_chain_ref.py) drives softmax_int VERBATIM on the
     sha256-stream s8.                                        [DONE]
  2. `uperf-x prove [seed] [t]` — the committed chain through the
     as-built machinery (u3_layer_run pattern): 9 committed entries
     (s8, m, zsel, d, E, Sum, P, rho, sigma), the d-pin (PW-3), the
     F-one/F-hit/Sum/DIV/sigma-def/off-support sumchecks (PW-3/PW-4
     weights real), 6 lookup/range instances incl. the REAL fused
     (d, E) LookupAt pair against the lane-local frozen exp member,
     pins -> psi claims -> masked wave split -> ct waves + closing;
     honest ACCEPT (acceptance a).
     DONE 2026-08-29: ACCEPT at the contract point (seed 161,
     T 512): 2435 data cms / 2476 commits / 19 waves / 703 pins;
     commit 1.5 s + prove 34.1 s (gates 4.2, lkp 4.1) + verify
     8.5 s [WSL-BOX NOISY-SHARED]; also ACCEPT at T 32/64/128.
     Instance transcript order = the spec chain order (d-w8,
     zsel-w1, exp-pair, P-w10, rho-w, sigma-w).                [DONE]
  3. `uperf-x battery` — the AT-O8/O9 tamper legs, each at its
     pre-registered gate (acceptance b): m overstated -> F-hit;
     m understated -> F-dom (w8 root cross-check); zsel two-hot ->
     F-one; zsel off-support -> F-hit; off-support P != 0 -> the
     off-support batch zero-check; shifted mask -> the first PW-3
     public-weight MLE check (Sum gate); wrong exp member -> the
     statement-table leaf pin (waves).
     DONE 2026-08-29: 8/8 legs at seed 161, T 64, EACH at its
     pre-registered gate, with side-fire isolation checks
     (m-under: exp-pair root also fires, G1/G2 green under the
     strongest cheater who re-places zsel at a d=0 position;
     off-support P: G1-G5 green; shifted mask: G1/G2 green, G3's
     PW-3 weight-MLE check is the gate; wrong member: ALL gates +
     roots green — the reject comes from the verifier folding the
     STATEMENT member into the exp tq leaf pin, surfacing at the
     masked-claims sum gate one step before the waves — the leg's
     pre-registration updated to that exact gate, recorded).
     XS1 BATTERY DIGEST be89d5da10aa7a375f36460f3c1a2a8cac8630b1
     61cfa189aacd055a476c191a.                                 [DONE]
  4. `uperf-x stage-a [seed] [t]` — the same row's range facts
     (d w8, zsel w1, rho/sigma w18) through zc_range's zero-check
     form vs the descent oracle (acceptance d, the S1/S2 pattern at
     attention's widths).
     DONE 2026-08-29: 4/4 fact groups at the contract point (seed
     161, T 512, n 2^18): (a) the masked descent PAIR (the oracle
     form) root cross-check green per group; (b) the zc_range
     zero-check at c 8/16 verify + open-check green on the SAME
     column; (c) c = 16 BYTE-IDENTICAL to the boxed-K oracle
     (rounds, fold point, finals, transcript state — the uperf-s
     leg-A identity at attention's widths). 70.2 s total 1T
     [WSL-BOX NOISY-SHARED]. XS1 STAGE-A DIGEST 34c6c1e2897ad6bb..
     Differential reading recorded: for RANGE facts the
     claims-equality is the pair-vs-zc GREEN on one committed
     column + the K-oracle byte identity (the S2 fraction-sum
     equality is a LOOKUP-side comparison; the exp pair's Stage-A
     LogUp form is X1 work, not spiked here).                 [DONE]
  5. (stretch) the calibrated data variant.
     DONE 2026-08-29: `uperf-x prove-cal [seed] [t]` + `chain-cal`.
     The s8 draw is score-shaped at the MEASURED eS = -2 — lane
     CC's results/m8b_gemma4_attn_stats.json layer 0 (absmax
     25.887, e8 = -2; the 125M attention exponents were never
     captured — the study ran attention fp32 — so the Gemma gate
     data is the honest measured source, per the round-6 brief);
     integer-exact Irwin-Hall map (ledger-recorded formula) so
     the Python driver reproduces it bit-for-bit. Value chain
     BYTE-IDENTICAL Rust-vs-oracle at (161, 512) CHAIN
     b5f2cbf358a4d956..; the committed chain ACCEPTs at T 512
     with the statement binding the eS = -2 member (same rig
     walls); chain stats printed: exp underflow 0.0% of support,
     Sum in [512, 46637], row mass [265, 512] vs 2^9 (the
     oracle's [282, 512] class). NOTE: stats are Gemma d_h 256;
     the member decay stays keyed at the spike's d_h 64 — the
     AM-2 params gap is an X1 item, recorded.                 [DONE]

  Repro driver: scripts/attention_xs1_chain_ref.py (NEW file, one
  step outside the strict ownership grant, additive and
  collision-free — committed for Grok-resumability of acceptance
  (c); recorded here as the lane's one ownership note).

LANE-LOCAL CONVENTIONS (recorded; none transcript-affecting beyond
this additive spike's own statement):
  * The seeded s8 draw is a SHA-256 counter stream (seed || counter
    LE64, byte -> (b % 255) - 127), implemented identically on both
    sides — numpy PCG64 is not replicated in Rust; the CHAIN from s8
    onward is the oracle's softmax_int verbatim.
  * The exp member (exp-neg-table-v1, eS = -1, d_h = 64, fE = 9 —
    the spec's layer-0 example) is LANE-LOCAL: generated in
    attn_softmax.rs with the spec §2.5 header JSON byte-exact to the
    oracle's exp_table_digest, digest pinned as a const (drift-loud,
    silu-v2 discipline). OPEN FREEZE QUESTION: promoting exp members
    into the lookup.rs/manifest.rs registries is additive (no
    existing digest moves) but is a C5 registry ruling (the AM-2
    key extension) — left for Victor with the X1 freeze set.
  * At T != 512 the remainder width derives as wrho = fE + log2(T)
    (18 at the contract T = 512, matching the oracle's w18); the
    battery runs at small T with derived widths. OPEN QUESTION:
    instancing/width policy at non-contract T is X1 work.
  * zsel is the FIRST argmax position (np.argmax first-occurrence
    convention) — any attainment witness verifies; the oracle pick
    is pinned for the bit-equality leg only.

FLOORS AT EVERY COMMIT: cargo build --release; uperf-pc diff-battery
green; uperf-s battery digest 3752cba4..; uperf-s agg-battery digest
46234986..; freeze-check 102 ok rows + the expected BK panic.

THE FOUR ACCEPTANCES (X-S1, memo §5.3), verdicts:
  (a) honest ACCEPT — GREEN at the contract point (seed 161,
      T 512): every fact on ONE rolling transcript (F-one, F-hit,
      the PW-3 masked row sum, the PW-4 broadcast-divisor DIV,
      sigma-def, the off-support batch pin, the d-pin, 6 masked
      descent pairs incl. the REAL fused (d, E) exp pair, 19 ct
      waves + closing). 1.5 + 34.1 + 8.5 s [WSL-BOX NOISY-SHARED].
  (b) tamper battery — GREEN, 8/8 legs each at its PRE-REGISTERED
      gate (digest be89d5da..); the one pre-registration corrected
      mid-rung and recorded: wrong-exp-member rejects at the
      masked-claims sum gate (the statement-table leaf pin
      surfacing one step before the waves), not in the waves.
  (c) value bit-equality vs scripts/attention_spec_spike.py —
      GREEN at 4 (seed, T) synthetic pairs + the calibrated
      variant (CHAIN 949d5cee.. synthetic / b5f2cbf3.. calibrated
      at the contract point; softmax_int driven VERBATIM).
  (d) Stage-A leg — GREEN: 4/4 range-fact groups (d w8, zsel w1,
      rho/sigma w18) through zc_range's zero-check form vs the
      masked-descent-pair oracle on the same column, c = 16
      byte-identical to the boxed-K oracle (digest 34c6c1e2..).

WHAT THE SPIKE DE-RISKED (the memo's four names): the four-fact
softmax coupling under one transcript with no ordering freedom;
PW-3 (mask as public weights in the d-pin, the masked row sum, and
the verifier's weight-MLE checks — the shifted-mask leg rejects at
the FIRST mask-consuming public-weight gate) and PW-4 (the
broadcast divisor as a free row-MLE read); the exp member registry
mechanics (spec-header digest byte-compatible with the oracle,
drift-loud, statement-bound — the wrong-member leg shows the
STATEMENT table is the only witness needed); and the Stage-A
sequencing recommendation exercised at attention's widths.

OPEN QUESTIONS (for the round close / X1):
  * The exp member freeze: lane-local in attn_softmax.rs (eS -1
    and -2 at d_h 64, fE 9). Promotion into lookup.rs/manifest.rs
    is additive (no existing digest moves — verified by the floor
    gates at every commit) but is a C5 registry RULING (AM-2 key
    extension with the params field); goes to Victor with the X1
    freeze set.
  * AM-2 params gap: the calibrated leg keys the member at the
    spike's d_h 64 while the measured stats are Gemma d_h 256 —
    the (eS, d_h) member matrix is X2 (AT-O1) output.
  * wrho at non-contract T derives as fE + log2 T (lane-local);
    the X1 instancing policy should fix it statement-side.
  * The wrong-member reject gate: the masked-claims sum gate, not
    the waves — if the round wants the reject to land INSIDE a
    named wave, the pin psi would need to bind pin INDICES rather
    than values (a design note, not a defect: the gate is sound
    and deterministic either way).
  * first-failing-gate semantics after a rejecting sumcheck leave
    the verifier transcript deliberately desynced (house
    behavior, bf/u3 precedent) — later flags in a rejecting run
    are not individually meaningful; the verdict names the first.

STATE: DONE (2026-08-29) — rungs 0-5 landed, one commit per rung
(rungs 2+3 share one commit, reason recorded), all pushed on
uperf3-jj; footprint purely additive (attn_softmax.rs + mod line +
the [UPERF3-JJ] bin section + this ledger section + the recorded
repro script); floors green at every commit (diff-battery, uperf-s
3752cba4.., agg 46234986.., freeze-check 102 ok + expected BK
panic).

## Orchestrator note 2026-08-29 — MAC-BOX sync gate pass [MAC-BOX QUIET]

Pull f698548 -> 9a8fa3d: the whole U-PERF2/U-PERF3 program landed on
this box for the first time. Box state at the run: QUIET — load ~1.7
on the M3 Ultra, frugal-lm F2 training NOT running (status watchers
only). Walls below are context, not a quiesced timing ladder.

1. **aarch64 BUILD BREAK (fixed)**: the pulled tree did not compile on
   the Mac — two WSL-round x86 paths lacked arch gates:
   `psi_avx2::mac_fold_row` called from `rows_t_rings_avx2`
   (eval_proof.rs, the module is `#[cfg(x86_64)]`) and
   `is_x86_feature_detected!("sha")` in `uperf_m_sha_bench`
   (ring_matmul.rs). Fix, house style: `rows_t_rings_avx2` is now
   `#[cfg(x86_64)]` with an off-x86 `unreachable!` stub (safe:
   `psi_simd_enabled()` is hard-false off x86_64, so the arm is never
   taken) and the sha flag print computes a cfg'd bool. x86 behavior
   byte-identical (same calls, same values, same print).

2. **GATE PASS** (logs + walls + peak RSS:
   `results/uperf/mac_sync_20260829_*`, marker `...done`):
   - freeze-check: **exit 0, 102 ok rows, FULL — no panic; the BK/BF
     rows run on this box** (0.4-0.9 s)
   - uperf-pc diff-battery green 12.6 s (O1 4/4, O2 35/35, O3 63/63,
     O5 12/12)
   - uperf-s battery 48 legs ok, DIGEST 3752cba4.. (matches ledger);
     uperf-s agg-battery 136 legs ok, DIGEST 46234986.. (matches)
   - uperf-w 23 legs 0 FAIL; agg-matmul battery green 80 s;
     bh-verifier battery green 8.3 s
   - uperf-v3 battery smoke green; uperf-v3 chain-m125: all 12 layers
     derive + range-check (v3 profile, T = 16)
   - uperf-x battery 8 legs ok, XS1 DIGEST be89d5da.. (matches JJ;
     note the banner hard-codes "[WSL-BOX NOISY-SHARED]" — a label
     constant, cosmetic)
   - python suite: **Ran 81 tests, OK — all green, no skips** (434 s)
   - pass-agg seam: 12/12 — AFTER the fix in the finding below (the
     first run FAILED at "perturbed scale moves Psi [real-act]")

3. **FINDING (latent, arch-independent): the `pass-agg seam`
   non-vacuity legs were broken by the [UPERF2-Q] row-factor memo.**
   `MultiClaimKernel.row_factors` caches scale * row keyed by (q, s)
   only (its own comment: "a pure function of (q, s, scale, rows),
   keyed by (q, s)"). The seam battery mutates `kernels[0].scale` in
   place after the honest run has populated the memo; the perturbed
   re-run hits the stale memo, Psi does not move, the leg panics.
   Triangulation: ZK_UPERF_ORACLE=1 -> 12/12 green (the oracle body
   reads scale directly); ZK_PSI0NTT=0 -> still fails (lane M's NTT
   body exonerated); f698548 has no memo (the seam predates lane Q and
   was green). The gate had simply not been run since lane Q landed —
   it is in NO round-5/6 gate list; WSL at HEAD fails identically.
   **PRODUCTION UNAFFECTED**: kernels are built fresh per pass
   (`bg_multi_kernels`) and scale is never mutated post-construction.
   FIX (battery-side, minimal): the seam drops `row_factors` when it
   mutates the scale. OPEN for Victor: whether the memo should be
   drift-loud (store scale in the memo, validate on read) — the
   scale-immutability contract is now load-bearing and only
   documented.

Floors re-run green on the final tree after all three code changes:
build, diff-battery 12.6 s, freeze-check 102 ok exit 0, seam 12/12.

## ROUND 7 — THE PoC SPRINT (opened 2026-08-30; Victor: "let's go
## ahead and continue" — the 32x16 8B yardstick is the milestone)

### Lane LL — W-1: zero-check column-splitting (wt-uperf3-ll) — RUST, the last code blocker
OWNS: the zero-check instance builder path (bg_zc_prove + its
callers' window loop), additive helpers, "Agent LL status". SPEC:
U_PERF3_MVP8B_SCALING.md's W-1 row VERBATIM: split each zero-check
instance over its COLUMN space into windows <= 2^(25 - lr - lambda)
columns; each sub-instance the same instance kind over a col range
(the eq_pc factor per window; terminal claims = ClaimContribs over
the window — the same product form); the K9 cap 2^25 is AUDITED and
does NOT move. ACCEPT: (1) k=1 at 125M shapes = the NULL split —
statement + EVAL-PROOF digests BYTE-IDENTICAL (the anchors);
(2) a forced-window battery leg (windows < cols at 125M: accept +
tamper); (3) the planner leg at the 8B shapes (the 2^28-class
f-instances -> 7 windows, d -> 2, ALL under the cap; ~+3.4 KB per
extra instance, ~+30 KB total at 8B counted); (4) floors green.
This unlocks board task T16 (the 32x16 yardstick on the Mac).

### Lane MM — the composed v3 statement (wt-uperf3-mm) — RUST, the PoC statement itself
OWNS: a composed-driver arm in the [UPERF3-BB]/u3 region (additive),
NEW seam machinery, "Agent MM status". WHY: the u3 rig proves
PER-LAYER v3 statements (its SeamSwap tamper is the INTRA-layer
gate seam); a working PoC = ONE composed multi-layer statement with
the CROSS-LAYER seams bound (layer l's z16 -> layer l+1's X: the
dequant/requant seam at the committed planes) — the m125 composed
pass's psi-seam (pass-agg seam 12/12) is the house precedent.
RUNG 1 IS A MAP, NOT CODE: enumerate exactly what a composed v3
statement must bind that u3_layer_run does not (the seam relation
in v3 semantics incl. clamp-at-z at the seam, the shared transcript
spine, the statement digest form), reconciled against the m125
composed pass's seam machinery — the gap table is the deliverable
and half the risk. THEN: the m125-shape composed rung (12 layers,
one statement, differential: the composed accept + per-layer
digests vs 12 independent u3 proofs + seam tamper legs incl. a
CROSS-layer swap), then shape-general (the Mistral 32-layer form —
the Mac runs it as T17 once landed).
## Agent LL status (wt-uperf3-ll) — round 7

W-1: zero-check column-splitting — the last named code blocker before
the 32x16 8B yardstick. The K9 packed-table cap (kfield.rs:283,
2^25, AUDITED) is NEVER moved; every zero-check instance whose
stacked table would exceed it is split over its COLUMN space into
windows of <= 2^(25 - lr - lambda) columns, each window the same
instance kind (same product form, eq_pc per window, ClaimContribs
over the window's scattered column kernel).

RUNG PLAN
- R0 SKELETON: this section + BASELINE anchors (below). [commit 1]
- R1 PLANNER: `uperf-pc zc-plan <layers> <t> <dmodel> <dff>
  [window]` — per-instance lr/lcp/lambda, K-elements, cap verdict,
  window count k, per-window K-elements, counted transcript bytes
  (no proving; 8B shapes = arithmetic only). Table recorded here.
- R2 THE SPLIT with k=1 as the NULL PATH: the window loop in
  bg_pass_run + bk_pass_run (prover + verifier mirrors); the k=1
  branch executes the pre-W1 statements verbatim (same labels, same
  bg_zc_prove call). ACCEPT: all three identity anchors
  BYTE-IDENTICAL.
- R3 FORCED-WINDOW BATTERY: new arm `uperf-pc zc-battery` (own
  digest — existing battery digests untouched): 125M shapes at
  512-col windows -> real multi-window instances; honest ACCEPT +
  claim-vs-unsplit-oracle byte-identity + tamper legs (tampered
  sub-instance claim; window-boundary off-by-one witness) rejecting.
- R4 RECORD: counted 8B transcript delta from the planner, the
  1024-col GPU-window note (W-9), ledger close.

DESIGN CHOICES (the k=1 anchors are the arbiter)
- Window size parameter: opts field `zc_window` (battery/programmatic)
  + env `ZK_ZC_WINDOW_COLS` read by the uperf-pc profile arms;
  default = the cap-derived 2^(25 - lr - lambda), clamped to a power
  of two <= the cap. k = 1 (window >= cols_real) = the NULL SPLIT.
- FS ambiguity ruling: window count/size is DERIVED (shape + the K9
  cap constant + the parameter), not separately absorbed; windowed
  instances get per-window absorb labels "<name>-w<i>" while k=1
  keeps the exact pre-W1 labels — byte-identity at k=1 by
  construction. OPEN QUESTION for the statement layer: a production
  8B statement should pin the window parameter in the statement
  digest (same class as the shape rows); recorded, not implemented.
- No ring/ changes: IxfZcSpec is already parameterized by
  (cols_real, cols_pad, n_pos); windows hand it per-window column
  slices (materialized copies, transient). K9_MAX_LEAVES read, never
  written.

BASELINE (identity anchors at the round-7 open commit ab2db23,
M125_EXPORT_DIR=results/m125_ffn_export_wsl, WSL box, ZK_THREADS 1,
walls [WSL-BOX NOISY-SHARED] — identity is the anchor, not time):
- fp3x16  (uperf-pc full-profile 3 16): accept true; statement
  93a987002a7c4b60c3dfbfc62b7a4f0e5957d8ae2039014ff241e323285fb790;
  EVAL-PROOF
  0ae9cdae66607239a80cc1f1dea36248370edadbe85214144aee7a5250d975be;
  985142 B counted.
- pa12x64 (uperf-pc pass-profile 12 64): accept true; statement
  45fb340517eee2344b44dd40d4e47562d80305eb7c5604c9c6cf61ede37443dc;
  EVAL-PROOF
  23cf1cb757c6edae949f8103d8a34497cf709ff0fde81b64273174b6381c0eb5;
  418471 B counted.
- fp12x64 (uperf-pc full-profile 12 64): accept true; statement
  80763ea537e77cd9cb5c538397af2622044447d654b8e9a34cae3ccad8f3f115;
  EVAL-PROOF
  63f4a3a4320a47260ab8ae3d52cfa3656b626fc367af671c6c317300454dec89;
  1308775 B counted.
All three equal the round-6 Mac-sync values (ledger above) — the
tree is clean at the round-7 open commit.

R1 PLANNER — DONE. `uperf-pc zc-plan <layers> <t> <dmodel> <dff>
[window]` (arithmetic only, no proving). The kel formula (had:
1 + 4(n_pos+lam) + 4; rq: 1 + 3 n_pos + 4 lam + 5; 64 B/K-element)
is VERIFIED EXACTLY against the measured wire face at 3x16
(`table-descent prove 3 16` instance lines: had 73 kel, rq-g/u/h 59,
rq-d 56 = the planner's numbers to the byte). Table (default =
cap-derived window 2^(25 - lr - lambda)):

  shape    inst    K-elems  verdict  k  wcols  win-elems  zc bytes
  3x16     all 5   2^16-17  UNDER    1  —      —          19584 (+0)
  12x64    all 5   2^20-21  UNDER    1  —      —          24192 (+0)
  32x16    all 5   2^21-23  UNDER    1  —      —          26304 (+0)
  8x512    f x4    2^26     OVER     2  8192   2^25       +22016 total
           rq-d    2^24     UNDER    1  —      —
  32x128   f x4    2^26     OVER     2  8192   2^25       +22400 total
           rq-d    2^24     UNDER    1  —      —
  32x512   f x4    2^28     OVER     7  2048   2^25       31424 ->
           rq-d    2^26     OVER     2  2048   2^25       173632 B
                                                          (+142208)
  32x512 w=1024 (the W-9 GPU option): f k=14, d k=4, windows 2^24;
                                                          +303424 B

VERDICT: the 125M shapes and the 32x16 yardstick are ALL k=1 (the
null split); at 32x512 the f-instances split 7-way and rq-d 2-way,
every window AT the cap boundary 2^25 (<=, the KTab::words_for
assert form) — the W-1 row's window counts reproduced. HONEST
CORRECTION vs the row's estimate: the counted delta is +142,208 B
at 32x512 (not ~+30 KB) — the row's ~+3.4 KB/instance is the
125M-shape instance cost; an 8B WINDOW instance is 5.4-6.7 KB and
there are 25 extra instances. +139 KB rides a transcript whose
125M-3x16 count is already 985 KB — noise at the 8B scale.

R2 THE SPLIT (k=1 = the NULL PATH) — DONE. The window loop in
bg_pass_run + bk_pass_run, prover AND verifier mirrors (the verifier
re-derives the identical plan from shape + the K9 cap constant +
opts). k = 1 executes the pre-W1 statements verbatim (same labels
"bg/bk-claim-<name>", same bg_zc_prove call); k > 1 proves one
sub-instance of the SAME KIND per window through the NEW
bg_zc_prove_win (windowed per-layer operand copies into the
UNCHANGED IxfZcSpec; labels "<name>-w<i>"), terminal claims through
bg_zc_scatter_col (the window eq kernel scattered at the window
offset over the full padded column space — same ClaimContrib product
form over the FULL committed tensors). No ring/ file touched;
K9_MAX_LEAVES read, never written. Parameter surface: opts.zc_window
(both rigs) + ZK_ZC_WINDOW_COLS on the uperf-pc profile arms.
ACCEPT (all at ZK_THREADS 1, M125 WSL export):
- IDENTITY ANCHORS BYTE-IDENTICAL post-split: fp3x16
  93a98700../0ae9cdae..; pa12x64 45fb3405../23cf1cb7..; fp12x64
  80763ea5../63f4a3a4.. (statement + EVAL-PROOF, all six digests
  equal the R0 baseline).
- FLOORS: freeze-check FULL exit 0 (102 ok rows); uperf-pc
  diff-battery passed; uperf-s battery 48 legs 3752cba4..; uperf-s
  agg-battery 136 legs 46234986..; uperf-x battery 8 legs
  be89d5da.. — all unchanged.
- FORCED-WINDOW SMOKE (both rigs at 3x16, ZK_ZC_WINDOW_COLS=512 ->
  f k=4, d k=2): accept TRUE; statement digests UNCHANGED
  (bg 3x16 de93b680.. and bk 3x16 93a98700.. identical with and
  without the forced plan — the statement is window-independent);
  EVAL-PROOF digests differ at k>1 as expected (the transcript
  grows by the extra sub-instances).

R3 FORCED-WINDOW BATTERY — DONE. NEW arm `uperf-pc zc-battery`
(own digest; NO existing battery digest moved). 7/7 legs ok,
ZC BATTERY DIGEST
01ca048b9021e3573e40286de35d1af7f0bc74492414e6c18f661c852cda32f7:
- plan-125M-null: 3x16 + 12x64, f + d cols all k=1.
- plan-8B-32x512: default f k=7 w=2048 / d k=2; the 1024-col W-9
  option f k=14 / d k=4 — all windows under the K9 cap.
- bg-3x16-w512-honest+oracle and bk-3x16-w512-honest+oracle: accept
  TRUE with 54/54 zc terminal claims (3 x (4 f-windows x 4 insts +
  2 d-windows)) BYTE-IDENTICAL to the unsplit oracle (each windowed
  claim re-evaluated from the FULL tensors through the scattered
  kernels, asserted in-pass) — the recombined-claims identity.
- bg-3x16-w512-tamper-subclaim (BgTamper::ZcSubClaim, +1 on the last
  windowed sub-instance's t1 final on the wire): REJECT, first_fail
  sc-requant (the combine check at the instance gate).
- bg-3x16-w512-boundary-c511 / -c512 (+1 on layer-0 H at the last
  column of window 0 / the first column of window 1): both REJECT,
  first_fail sc-hadamard — no column escapes coverage at the seam.
FLOORS re-run green at this commit: freeze-check FULL exit 0 (102
ok), diff-battery, uperf-s 3752cba4.., agg 46234986.., uperf-x
be89d5da..; all three identity anchors byte-identical again
(93a98700/0ae9cdae, 45fb3405/23cf1cb7, 80763ea5/63f4a3a4).

R4 THE RECORD — LANE CLOSE.
- THE 8B TRANSCRIPT DELTA (counted, planner-verified end to end):
  the planner's byte accounting is CONFIRMED ON THE REAL WIRE —
  fp3x16 forced-512 counted 1,029,686 B vs the 985,142 B baseline
  = +44,544 B, EXACTLY the planner's forced-512 3x16 zc delta.
  The 8B 32x512 counted delta therefore stands at +142,208 B
  (~+139 KB) at the 2048-col cap default (f-instances 7 windows,
  rq-d 2); the W-1 row's ~+30 KB estimate is superseded (honest
  correction recorded under R1). At 8x512 / 32x128: ~+22 KB. At
  32x16 (the yardstick): +0 B — the null split.
- THE GPU-WINDOW NOTE (W-9): `ZK_ZC_WINDOW_COLS=1024` (or
  opts.zc_window = Some(1024)) keeps every zc packed table at 2^24
  K-elements = half the K9 budget, holding the device ixf path
  inside its 4 GB at 32x512 (f k=14, d k=4; +303,424 B counted).
  The default stays the cap-derived 2048.
- OPEN QUESTION (recorded, not implemented; the k=1 anchors were
  the arbiter): the window parameter is DERIVED (shape + the K9 cap
  constant + opts/env), absorbed only through the per-window labels
  "<name>-w<i>"; a production 8B statement should pin the window
  size in the statement digest like the shape rows (one line in the
  statement builder when the 8B statement lands — W-10 territory).
- MEMORY NOTE: k>1 windows materialize per-window operand copies
  (3 entries x layers x rows x window i64) — ~768 MB transient per
  f-window at 32x512, freed per window; the packed tables the
  windows exist to shrink are 2.1 GB each. No ring/ change; if the
  copy ever matters, an IxfZcSpec col-stride is the additive fix.
LANE VERDICT: W-1 CLOSED. The last named code blocker before board
task T16 (the 32x16 8B yardstick — itself k=1/null-split) is
removed, and the 32x512 ladder rung has a proven, battery-covered
split with every packed table under the AUDITED, UNTOUCHED K9 cap.
Files: src/bin/ring_matmul.rs only (bg_zc_window_plan /
bg_zc_prove_win / bg_zc_window_vals / bg_zc_scatter_col /
bg_stack_table_win, the window loops in bg_pass_run + bk_pass_run
prover+verifier, uperf-pc zc-plan + zc-battery, opts fields,
BgTamper::ZcSubClaim). READ-ONLY honored: kfield.rs, manifest.rs,
stage_a.rs, zc_range.rs, attn_softmax.rs, two_tier.rs untouched.


## Agent MM status (wt-uperf3-mm) — round 7

Lane MM: the COMPOSED v3 statement (cross-layer seam binding — the PoC
statement itself). Rung plan:

- **Rung 0 (this commit)**: skeleton status.
- **Rung 1 — THE MAP (deliverable: the gap table, below when done)**:
  enumerate what a composed v3 statement must bind that u3_layer_run
  does not — (a) the cross-layer seam relation in v3 semantics
  (z16(l) -> X(l+1) through the dequant/requant seam, clamp-at-z per
  the 2026-08-27 ruling); (b) the shared transcript spine (one rolling
  transcript + composed statement digest vs 32 independent ones);
  (c) what the m125 composed pass's psi-seam differential actually
  checks and whether the mechanism transfers. Reconciled against the
  real Mistral sidecar (wt-uperf3-aa results/m8b_mistral_v3_export,
  read-only). Open questions flagged, not guessed.
- **Rung 2 — the composed driver at m125**: `uperf-v3 composed [t]
  [layers]` — 12 layers under ONE rolling transcript, seam relations
  bound; differential vs 12 independent u3_layer_run proofs; honest
  ACCEPT.
- **Rung 3 — the seam tamper battery**: cross-layer swap, seam
  off-by-one (wrong shift), clamp-lie at the seam — each rejecting at
  a named gate; existing battery digests unmoved.
- **Rung 4 — shape-general**: the composed arm through
  bf_model()/ZK_MODEL_EXPORT_DIR; m125 smoke via the env var; the real
  Mistral 32-layer run stays a Mac task (T17) — NOT run here.

Floors at every commit: release build, uperf-pc diff-battery, freeze-check
102 ok, uperf-s 3752cba4… / agg 46234986… / uperf-x be89d5da… unchanged,
m125 fp3x16 anchors 93a98700…/0ae9cdae… unchanged.

STATUS: rung 0 committed; rung 1 (the map) below.

### RUNG 1 — THE MAP (the gap table; sources read, none guessed)

READING CORRECTIONS first (what the precedents actually are):

- **`pass-agg seam` is NOT a cross-layer seam.** bg_seam()
  ([UAGB1-BJ], ring_matmul.rs ~31993) is the R-BG1 *aggregation*
  differential: factored multi-claim Psi_0 == compute_psi over the
  reference phi materialization, on real + synthetic groups, plus a
  non-vacuity perturbation. Its mechanism (two implementations of one
  aggregation semantics, differential-tested) transfers as a TEST
  DISCIPLINE, not as a seam relation. The cross-layer seam needs its
  own relation; none exists anywhere in the house today.
- **The m125 composed pass binds consecutive layers by PUBLIC
  DECLARATION, not by relation.** [UAGB1-BG] prove (~31437): "Public
  binding claims: X_l + declared z_l at a shared point" — the prover
  ships MLE evals of every layer's X and z planes at one
  transcript-drawn point; the verifier RECOMPUTES them from the public
  planes (~31891) and rejects on mismatch ("public-claim" gate). All
  layers sit in ONE statement + ONE transcript, but no arithmetic fact
  ties z(l) to X(l+1). The house says this out loud already:
  uagb1_statement_125m prints "the RMSNorm/residual inter-layer edge
  is NOT integer-specified and NOT wired" (~19690).
- **Why there is no such relation in the data**: both walkers
  (m125_int8_calibration.py walk() ~326: `x = x + blk.attn(...)`;
  m8b_int8_calibration.py walk() ~360: attn residual + mlp_norm
  between sublayers) put attention + residual + RMSNorm — float, out
  of FFN statement scope — between z(l) and X(l+1). The exported
  X(l+1) planes do NOT satisfy any requant of z16(l). A seam-requant
  statement over the REAL export planes would (correctly) REJECT.

THE GAP TABLE — what a composed v3 statement must bind that
u3_layer_run does not:

| # | must bind | u3_layer_run today | precedent | composed v3 design |
|---|-----------|--------------------|-----------|--------------------|
| G1 | ONE accept over all layers | one proven layer per call (li); 12/32 independent accepts | [UAGB1-BG]: one bundle, one verify | one composed driver: all layers committed, all proven, one composed verdict = AND(per-layer gates) AND(seam gates) |
| G2 | one transcript spine | statement ctx ALREADY covers all layers (u3_statement_bytes = all-layer commitment digests) but each proof seeds its own h0 = ct_h0(ctx\|\|li, own tags); proofs are transcript-independent, mixable across sessions | BG: one rolling tr absorbs everything | one LkpTranscript: absorb every layer's h0_l (commitment binding) FIRST, then per-layer relation phases, then seam phases, then per-layer pin->psi->waves — every challenge downstream of all commitments |
| G3 | composed statement digest | "uperf3-v3-pass-v2" bytes (all-layer, no seam data) | BG statement + expect | NEW tag "uperf3-v3-composed-v1": the existing per-layer blocks verbatim + a seam block (per seam: sh_seam, half, zpolicy byte) + Rs commitment digests; per-layer u3_statement_bytes untouched (byte-identity floor) |
| G4 | the seam relation z16(l) -> X(l+1) | absent (SeamSwap tamper is INTRA-layer g8) | none (see corrections) | the v3 requant edge, cross-layer: X(l+1) = rq_round(z16(l), sh_seam), sh_seam = eX(l+1) - eZ16(l); proven as THREE pins at one shared eq-point r_seam — pin z16(l) MLE (layer l commit space), pin X(l+1) MLE, pin Rs (layer l+1 space) — verifier checks v_z + half*S = 2^sh*v_x + v_rs ("seam-edge" gate); same PinnedValue machinery, no new crypto |
| G5 | seam range facts | X has NO range instance (it is an input); no Rs | v2 range-instance classes | seam-fed X(l+1) becomes an interior plane: rng-x ([-128,127] via 256-row identity table at offset 128, the rng-hhi class) + rng-rs-w{sh} ([0,2^sh) identity table) — instances LOCAL to layer l+1's commit space; NO C5-class table addition (C5 freezes act16 members only; identity tables are built on the fly). ANSWER to the brief's flagged question: the seam RIDES the existing requant relation. |
| G6 | clamp-at-z at the seam | u3 requant edges are exact linear identities — a clamp event breaks them (caught at the remainder range instance, i.e. only clamp-FREE witnesses prove today) | 2026-08-27 ruling (ledger ~1631): clamp legal AT Z, events counted, both real exports measured 0; BB's guard fails nonzero `NN zclamps` loudly; clamp-selector z gadget = the recorded open item | same treatment at the seam: statement declares zpolicy; the tower builder counts would-be seam clamps and REQUIRES 0 (clamp-free witness class); a witness with real seam clamps needs the same clamp-selector gadget (recorded, not built here) |
| G7 | witness for the seam-fed layers | u3_load_m125_layer loads every layer's X from the export (correct planes; no seam relation holds between them) | — | THE TOWER (verdict below): layer 0 X = export plane; X(l+1) := rq_round(z16(l), sh_seam) at the export eX(l+1) — downstream shifts stay as calibrated; values shrink through the seam so range facts hold (clamp count measured, 0 required) |

RECONCILE vs the REAL Mistral sidecar (wt-uperf3-aa
results/m8b_mistral_v3_export, read-only):

- The export CARRIES the seam operands: X (int8) and z16 (int16)
  planes per layer, both committed independently — the seam is
  expressible as a relation between committed planes. It does NOT
  carry seam shifts (derived: sh_seam = eX(l+1) - (eZ(l)-8) from the
  exps rows) or any inter-layer plane.
- Derived Mistral seam shifts, 31 seams: [12, 3, 15, 15, 14, 15, 14,
  15, 14, 11, 14, 14, 15, 15, 11, 14, 13, 12, 12, 11, 11, 11, 13, 13,
  14, 14, 13, 13, 13, 13, 8] — ALL in the provable 1..=16 band;
  2 of 31 (sh 3, sh 8) are clamp-POSSIBLE at extreme z16.
- m125 seam shifts (M125_EXP, eZ16 = eZ - 8): [5,7,5,7,7,9,9,9,8,8,6]
  — all in band; sh <= 8 seams are clamp-possible in principle,
  tower values expected far below the thresholds (measured at rung 2,
  0 required).
- This sidecar copy PRE-DATES the zpolicy row (no `00 zpolicy clamp`
  line; manifest has range_violations 0, no z_clamps key). The
  m8b_margins.py of record writes it now; Gemma's export carries it.
  Inert to the composed rung (the statement takes the policy from the
  model profile, not this file).

THE VERDICT (the honest scope statement rung 2 builds under):

The composed v3 statement that is BUILDABLE today with existing
machinery classes is the **FFN TOWER**: X(0) committed from the
export, every later X(l+1) bound to z16(l) by the declared seam
requant, every intermediate plane committed and range-checked, ONE
statement, ONE transcript, ONE accept. This binds every cross-layer
seam cryptographically and is the PoC statement. It is NOT the walked
model: the real inter-layer edge (residual + attention + RMSNorm) is
replaced by the declared seam requant — exactly the edge the house
has always declared out of FFN scope, and the edge lane CC's
attention-site gate exists to close in MVP-2. The composed driver
prints this scope label loudly (the D3-skeleton precedent).

OPEN QUESTIONS (flagged, not guessed):

- OQ1 (for Victor / T17 disposition): should the REAL Mistral 32-layer
  composed run (Mac, T17) run the TOWER semantics (machinery
  yardstick; witness planes diverge from the export planes after
  layer 0 by construction), or wait for the attention statement and
  compose model-faithfully (X planes declared per layer, the m125
  public-binding reading)? Rungs 2-4 build the tower arm either way;
  T17's label depends on the answer.
- OQ2: if the m125 tower witness carries ANY seam clamp event, rung 2
  stops and reports (the clamp-selector gadget is the recorded
  dependency; transcript-affecting, not mine to improvise).
- OQ3: the composed statement byte layout is a NEW tag (no existing
  digest moves); the manifest-v5 typed statement encoding stays the
  recorded merged-round item (BB's own note at the v3 rig header).
- OQ4: the round-7 brief calls the precedent "the m125 composed pass's
  psi-seam (pass-agg seam 12/12)" — per the reading corrections above
  that battery is the aggregation differential, not a cross-layer
  mechanism; recorded here so the next agent doesn't chase it.

### RUNG 2 — THE COMPOSED DRIVER (built; the measured road to it)

- **THE RAW MEASUREMENT FIRST** (`uperf-v3 composed-chain 16 12 raw`,
  m125 T=16): the export calibration is UNCALIBRATABLE for the tower
  witness — 300,230 non-seam range violations, 40,813 seam clamps
  (g8 max 2651 vs 127, u16 max 572,385 vs 32,767, blowup compounding
  by depth). The z-image input exceeds every per-layer band; OQ5 (the
  tower needs its own calibration) is thereby MEASURED, not
  hypothetical.
- **THE TOWER CALIBRATION** (u3c_tower_calibrated): greedy forward
  pass in shift space with multi-pass seam+gate budget targets (the
  coupled constraint: sh_seam + sh_g = e_gate - eWg - eZ16(l-1),
  both ends frozen). FROZEN quantities untouched: the C5 member pair
  (e_gate, e_a16) per layer, the weight exponents, every
  U3Model::shifts band. The whole calibration is DECLARED through
  the statement's existing exps/shifts rows (the house
  margin-mechanism species — the m8b_margins precedent). Measured
  (m125 T=16, 12 layers): **0 non-seam violations, 1,309 seam clamp
  events** (= the clamp machinery's first live data; seams 1->2: 6,
  2->3: 113, 3->4: 1190), signal live through ~layer 7, decaying
  deeper — intrinsic to a residual-free tower, documented, harmless
  to the proof.
- **THE SEAM MACHINERY** (all existing classes, NO frozen-registry
  addition — the map's flagged question answered):
  * seam edge: z16(l) + half = 2^sh * Ys(l+1) + Rs(l+1), proven as
    two MLE pins at a shared transcript point (v_z over layer l's
    committed z16; v_lin over layer l+1's committed Ys/Rs) + the
    verifier equation v_z + half*S == v_lin — the SEAM-EDGE gate.
  * clamp-pair: (Ys, X) fused-pair lookup against the
    STATEMENT-DERIVED saturation table u3c_clamp_rows(sh) (the
    2026-08-27 clamp-at-z semantics applied at the seam); the table
    domain IS the Ys range fact and its output column IS the X range
    fact. No separate rng-x / rng-ys instances needed.
  * Rs range: [0, 2^sh) identity instance.
  Soundness chain: edge + Rs range = the unique Euclidean
  decomposition (committed z16 determines Ys); clamp-pair = X
  determined pointwise. The cross-layer seam is BOUND.
- **THE SPINE**: composed statement tag "uperf3-mm-composed-v1" =
  the per-layer u3_statement_bytes body VERBATIM (the differential's
  embedding check) + the seam block (zpolicy byte; per seam: fed
  layer, sh, Ys/Rs commitment digests). ONE transcript seeded by
  sha(ctx || h0_0 || ... || h0_L) — every layer's full commitment
  tag set bound before any challenge; phase order: relation phases
  per layer -> seam pins -> per-layer pin batches / waves / closing.
  One accept (U3cVerdict = statement AND every per-layer gate AND
  every seam-edge gate).
- Arms: `uperf-v3 composed [t] [layers] [diff]`,
  `composed-battery [t] [layers]`, `composed-chain [t] [layers]
  [raw]` — all through bf_model()/bf_export_path() (env-general;
  entries 0..19 keep the [UPERF3-BB] public commitment seeds so the
  per-layer digests are byte-identical to the per-layer rig's).

### RUNG 3 — THE SEAM TAMPER BATTERY

Legs (m125 tower, T=16, 3 layers; log
results/mm_composed_battery.log):
1. honest composed ACCEPT (2 seams, 6 live clamp events — the
   clamp-pair relation proven on real clamped positions).
2. CrossLayerSwap — layer 1 fed from the WRONG layer's z16 (z16(2),
   self-consistent) -> SEAM-EDGE(1) rejects; statement + every
   per-layer gate clean (the seam gate is the lone discriminator).
   FINDING from the first aim of this leg: feeding layer 2 from the
   HOTTER z16(0) fired the seam edge AND blew layer 2's calibrated
   range gates — scale-mismatched swaps trip both gate classes; the
   leg was re-aimed at a small-scale source to isolate the seam gate.
3. SeamShiftLie — layer 1's X/Ys/Rs derived at sh-1 while the
   statement declares sh (from the exps rows) -> SEAM-EDGE(1)
   rejects.
4. SeamClampLie — X forged to 127 at an in-band position, Ys/Rs
   honest (the seam edge HOLDS by construction) -> the seam-clamp
   pair instance's roots gate rejects: a false clamp claim cannot
   ride the clamped relation.

STATUS: rungs 0-1 committed (6d6f155), rung 2a committed (13f57da);
battery re-run + the 12-layer composed differential + the Mistral
shape-general smoke IN FLIGHT serialized on /tmp/zk-heavy.lock
(results/mm_composed_battery.log, mm_composed_12L_diff.log,
mm_composed_mistral_smoke.log; .done markers alongside).

### RUNG 3 + CLOSE (integrated by the orchestrator 2026-08-30 after
### two agent stalls; the failure history recorded, not erased)

- **THE BATTERY'S FIRST RUN FAILED HONESTLY**: the CrossLayerSwap
  leg demanded a surgical single-edge reject but did NOT re-derive
  the layers downstream of the swap — so the downstream seam (and a
  per-layer gate) legitimately fired too. The LEG was fixed
  (downstream re-derived; the tamper now isolates exactly one
  inconsistent edge); NO gate was weakened. RE-RUN
  [WSL-BOX NOISY-SHARED]: **composed battery 4/4 legs green,
  COMPOSED BATTERY DIGEST 7465fa05..** — honest ACCEPT;
  CrossLayerSwap rejects at SEAM-EDGE(target) ONLY; SeamShiftLie at
  its seam edge; SeamClampLie at the seam-clamp instance's roots
  gate with ALL seam edges holding (the precision property). The
  3-layer composed object: 16,066 data cms / 124 waves, commit
  5.4 s / prove 174.1 s / verify 50.5 s per variant.
- **THE 6-LAYER COMPOSED DIFFERENTIAL PASSED** (the 12-layer form
  OOM-KILLED on this 15 GB box — measured 10.58 GB peak at 6
  layers, ~20 GB projected at 12 -> a Mac-class run, recorded):
  composed accept + 6/6 independent u3_layer_run accepts;
  per-layer commitment content IDENTICAL (public seeds); differs
  BY DESIGN only in the transcript spine (one vs six), proof
  randomness, and the composed-only Ys/Rs seam entries.
- **THE REAL-MISTRAL SHAPE-GENERAL SMOKE IS PROVABLE**: the 3-layer
  tower probe on the real Mistral v3 export — 39 seam clamp events
  (legal, clamp-pair-provable), 0 non-seam range violations; per
  seam: sh_seam 6 and 1, clamps 38 and 1. The composed statement
  machinery is shape-general.
- **T17 (the Mac composed run), the command text**: after T15's
  Mistral export on the Mac:
  `ZK_MODEL_EXPORT_DIR=<mistral v3 export> ring_matmul uperf-v3
  composed 16 32` (add `diff` for the 32 independent-proof
  differential if time permits; /usr/bin/time -l; expect ~40+ GB
  RSS [MODEL from the 6L curve], hours-class wall at T=16 CPU).
- **THE T17-SEMANTICS RULING (Victor)**: (a) the DECLARATIONAL
  composed statement over the real export (every FFN block, one
  transcript, per-layer inputs declared — the honest MVP-1 form;
  attention/residual/norm between layers is out of FFN scope by
  construction); (b) additionally the CALIBRATED-TOWER composed
  proof (the seams arithmetically BOUND — the machinery
  demonstrator; the tower is NOT the model's function and says so).
  Orchestrator recommendation: BOTH (b is nearly free given a; the
  write-up states each object's meaning plainly). The seam
  machinery itself transfers to MVP-2's real seams either way.

## ROUND 8 — MVP-2 X1 + THE i8 LAYER STORE (opened 2026-08-31;
## Victor: continue; the Mac holds T15-T17)

### Lane NN — X1: attention entry classes + PW wirings (wt-uperf3-nn) — RUST
OWNS: ring/attn_softmax.rs extensions + a NEW ring/attn_entries.rs
if cleaner, the [UPERF3-JJ]/[UPERF3-NN] bin sections + uperf-x
arms, "Agent NN status". SPEC: the design memo §5.1 X1 VERBATIM
(~66 new per-layer entries in the BF typing — or ~60 fused, AT-O2
decides and the lane RECORDS its pick; PW-1..PW-4 public-weight
builders; the folded instance families extended with the head
index; exp + range members LANE-LOCAL pending the AT-O5/O6
freezes) at T=16, 1-2 heads, synthetic witness; §1.6b's measured
exponents are the calibrated source. GATES: F5 batteries per PW;
AT-O8/O9 tamper legs; every frozen digest + the five battery
digests + freeze-check unmoved at every commit.

### Lane OO — the i8 layer store (wt-uperf3-oo) — RUST, diet 3
OWNS: the BfLayer/U3Layer storage representation + consumers'
accessor path (additive accessors; the HH/KK wrap-don't-rewrite
rule), "Agent OO status". WHY: the commit-phase layer store (i64,
66 GB at 8B, ~245 GB at 30B) is the LAST term above ~75 GB; the
W-8 row prices the i8/i32 per-class store at ~9.9 GB (8B) -> the
counted peak moves to lvl-0 ~72 GB. DISCIPLINE: transcript-
preserving ONLY — the five digest anchors (fp3x16 93a98700../
0ae9cdae.., pa12x64 45fb3405.., fp12x64 80763ea5../63f4a3a4..)
byte-identical at every rung, /usr/bin/time -v RSS before/after,
any digest move = revert + record.

## RULINGS (Victor, console 2026-08-31)

1. **T17 = BOTH FORMS**: the declarational composed statement over
   the real Mistral export AND the calibrated-tower composed proof
   (each object's meaning stated plainly in the write-up). The
   board's T17 task text updated accordingly.
2. **F1 = FULL MODE**: the Stage-A round-1 freeze set adopts FULL
   mode (every descent family incl. the silu lookups through the
   aggregate), accepting the committed-h bill. RECORDED
   CONSEQUENCES (not relitigated): (a) the F2 act-h mid-transcript
   third-group ordering amendment is thereby REQUIRED (it is what
   makes full mode transcribable) — treated as adopted with this
   ruling; (b) the committed-h growth is the new named cost center
   (+25.2M rings at 12x512 scale; the measured 12x128 full-mode
   OOM at 14.8 GiB on the 15 GB box) — a NEW WORK ITEM is opened:
   the COMPACT COMMITTED-H ENCODING (beat the naive l0_q=16
   encoding; candidates: the limb-split form h already carries in
   v3, a coarser l0_q, or a derived-not-committed h with its own
   relation) — this is the round-9 design item; (c) the 8B memory
   projection is STALE for full mode — the ~116 GB/~72 GB figures
   are range-only; a fresh counted row is OWED before hardware
   commitments (first estimate [MODEL]: commit-phase act growth
   puts the peak back in the ~130-160 GB class until (b) lands).
## Agent NN status (wt-uperf3-nn) — round 8

LANE: X1 — the attention ENTRY CLASSES + PUBLIC-WEIGHT WIRINGS at toy
shape (design memo §5.1 X1 verbatim; semantics ATTENTION_INTEGER_
SPEC.md §2.1-2.9; measured exponent defaults §1.6b / results/
m8b_gemma4_attn_stats.json layer 0). Toy shape: T = 16 (value level;
the proven rung at T = 32, the X-S1 machinery's floor), d = 128,
H = 2, H_kv = 1 (GQA group 2), d_h = 64, synthetic witness.

AT-O2 FUSION DECISION (recorded): UNFUSED — the 66-entry table
(witness 60 + weights 6, spec §4.1 verbatim). Why: the as-built
house pattern (u3_layer_run, X-S1) commits accumulators and the
fused matmul-terminal requant pin's wave-plan interaction is
explicitly unverified (AT-O2 names its own battery, unbuilt); X1 is
the typing/wiring rung, so the -13.8% commit-volume saving is
deferred to the rung where volume binds (X3+), with the fused form
kept as a recorded statement-level packing option.

OWNERSHIP: NEW ring/attn_entries.rs + one mod line in ring/mod.rs;
extensions of the [UPERF3-JJ] bin section limited to a
behavior-preserving parameterization of xs1_run (s8 source +
statement/transcript tags become arguments; the JJ entry points keep
their exact bytes — uperf-x battery digest be89d5da.. is the guard);
the NEW [UPERF3-NN] bin section + uperf-x arms (entries, layer-chain,
pw-battery, head-prove, head-battery); NEW
scripts/attention_x1_layer_ref.py (the stated reference driver);
this ledger section. Frozen registries (lookup.rs / manifest.rs)
untouched; exp + rope members LANE-LOCAL pending AT-O5/O6.

RUNG PLAN (one commit per green rung, prefix "U-PERF3 NN:"):
  0. skeleton: this section. [DONE]
  1. THE ENTRY TABLE: `uperf-x entries [t]` — the 66 typed entries
     (name, shape, class, exponent source) reconciled against the
     memo §1 / spec §4.1 inventory; mismatches flagged, not papered.
  2. THE VALUE CHAIN: `uperf-x layer-chain [seed] [t]` — the full
     attention-layer derivation at toy shape, bit-exact vs the
     REFERENCE (stated: scripts/attention_x1_layer_ref.py, Python,
     written by this lane, driving the validated oracle
     scripts/attention_spec_spike.py primitives — rmsnorm_int /
     rope_int / softmax_int / requant — VERBATIM at patched toy
     shape constants; per-tensor sha256 + CHAIN digest both sides).
  3. PW-1..PW-4 builders + F5 batteries: `uperf-x pw-battery` —
     flip-read (PW-1), GQA/MQA map (PW-2), causal mask closed form +
     band degeneracy (PW-3), broadcast reads (PW-4), the
     head-indexed public coefficient MLE (the BG layer-MLE
     precedent extended to (l, h)), rope-cs-table-v1 generation +
     python-pinned digest; each functional == its direct evaluation
     on random points + wrong-vector sanity legs; own digest.
  4. Head-indexed instances + the per-head X-S1 chain proven for 2
     heads (`uperf-x head-prove`): the layer chain's per-head s8
     blocks through the xs1 core (head-tagged statements binding
     the layer-calibrated exp member), honest ACCEPT x2; tamper
     legs (`uperf-x head-battery`, AT-O8/O9 class) at
     pre-registered gates; own digest.
  5. The record: the X3 needs list, enumerated here.

FLOORS AT EVERY COMMIT: cargo build --release; uperf-pc
diff-battery; uperf-s battery 3752cba4..; uperf-s agg-battery
46234986..; uperf-x battery be89d5da.. (existing arms byte-frozen);
freeze-check 102 ok via M125_EXPORT_DIR; uperf-pc zc-battery
01ca048b..; composed 7465fa05.. NOT touched (u3 region untouched).

LANE-LOCAL CONVENTIONS (recorded; conservative picks for
transcript-affecting ambiguities):
  * Calibration at toy shape is per-draw integer max-calibration
    (smallest shift with the floor-requant output in [-127, 127],
    the study's rule on the integer grid); the MEASURED §1.6b
    exponents ride the entry table as the calibrated DEFAULT source
    column (Gemma-4 l0: q -3 / k -6 / v -3 / qr -3 / kr -6 /
    scores -2 / ctx -3; seam sites ao/postn/xres int16 per the
    stack_wide ruling), since a synthetic toy witness cannot honor
    real absolute scales without failing narrowing by design.
  * Exp members generated at the layer-calibrated (eS, d_h 64,
    fE 9); contract-point members pinned from the Python side
    (drift-loud); non-contract eS prints UNPINNED loudly.
  * The Gemma four-norm/QK-norm sites (AM-5) are NOT in the
    66-entry table (spec §4.1 is the 125M two-norm form) — recorded
    as the reconciliation's known delta, not a mismatch.

RUNG RESULTS (recorded as gated, in order; the four rungs' code is
ONE additive block across ring/attn_entries.rs + the bin section —
built together, gated per rung below, ledger commits follow the
gates in order):

  1. THE ENTRY TABLE — DONE. `uperf-x entries [seed] [t]`: 66 typed
     entries (name, shape, manifest QuantMeta/TypingV4 row with the
     CLS_W8S/ACT8/ACC/REM/AUX31 mapping, exponent source), census
     66/66 vs spec §4.1 (witness 60 + weights 6; per-block counts
     match exactly). RECONCILIATION VERDICT: MATCHES, with four
     recorded deltas/flags (none papered over): (a) X_l + the FFN 17
     are shared MVP-1 entries, not re-counted; resid2's FFN input is
     a seeded stand-in (the X3 seam); (b) Gemma AM-5 sites (QK-norm,
     post_attn/post_ffn norms) absent from the §4.1 125M inventory
     by design — §1.6b's postn measured row has no 125M entry;
     (c) softmax rho/sig SINGLE range facts at wrhoSm = fE + log2 T
     (13/14 toy, 18 at 125M) vs the norm remainders' (11, 8) limb
     split — both per the §2.9 split rule; (d) attention aux rides
     CLS_AUX31/CLS_REM (no new class rows; whether narrower classes
     pay is X3 pricing). X1 ENTRIES DIGEST 0358428f85efd1d8.. at
     (1611, 16); 0e895bda3a9b4f59.. at (1611, 32).             [DONE]

  2. THE VALUE CHAIN — DONE. `uperf-x layer-chain [seed] [t]`: the
     full attention layer at toy shape (T 16/32, d 128, H 2, Hkv 1,
     d_h 64): attn_norm (isqrt pair + DIV + limbs) -> QKV + requant
     -> RoPE (route (a), fRo 7, scale-preserving) -> stacked scores
     (public GQA map g(h) = h/2) + requant -> per-head X-S1 softmax
     chain (derive_chain verbatim) -> PV -> Wo -> resid1 ->
     mlp_norm -> resid2 (seeded FFN stand-in). REFERENCE (stated):
     scripts/attention_x1_layer_ref.py — Python, this lane, driving
     the VALIDATED oracle attention_spec_spike.py primitives
     VERBATIM (rmsnorm_int / requant / rope_int / softmax_int +
     both table generators) at patched toy constants, aux tensors
     recomputed per the spec formulas and tied to every oracle
     output. stdout BYTE-IDENTICAL Rust-vs-Python at 5 (seed, T)
     pairs: (1611,16) CHAIN ee72b55f07930035.., (7,16), (42,16),
     (1611,32) CHAIN b646c164d355a461.., (20260811,32).
     Calibration: per-draw integer max-calibration (smallest
     narrowing shift); contract point lands eXn -5, eQ/eK/eV -7,
     eS -6 (exp member 062917d84faa9782.. PINNED, oracle-generated;
     non-contract eS runs loudly UNPINNED), eO -7, eAo -9, eR1 -3.
     rope-cs-table-v1 members pinned from the oracle side: t16
     355be440fcc13985.., t32 e0de1cf45aa38f10.. (drift-loud, AT-O6
     pending). NOTE (open, cosmetic): synthetic toy data lands
     eS = -6 (slow-decay member, softmax near-uniform) vs the
     measured Gemma eS -2 class — wiring gates don't depend on it;
     the calibrated-shape variant stays X2's business (JJ's
     prove-cal already covered measured-eS score shape).      [DONE]

  3. PW BUILDERS + F5 BATTERIES — DONE. `uperf-x pw-battery [seed]`,
     19/19 legs at seed 1611 (each public-weight functional equals
     its DIRECT evaluation at transcript-drawn random points, two
     independent code paths — dense eq-table sum vs closed
     form/multilinear fold):
     * PW-1 (RoPE): the flip-read EXACT identity (dense flip-composed
       read == MLE(q8) at the coordinate-flipped point); the rotation
       relation as a weighted zero point on the honest witness; cW~
       and sW~ closed forms (head + top-of-head bits marginalize;
       the sign rides (2 r_top - 1)).
     * PW-2 (GQA/MQA map): the layer's own H2->Hkv1 stacked K-read
       (dense == sum_h eq * MLE) + a NONTRIVIAL identity map
       (H2->Hkv2 on seeded data; head bits pass through to the
       kv-head coordinate).
     * PW-3 (mask): the causal MLE O(log T) DP closed form == dense
       support sum; the pub_mass tie on the T x T index space; band
       degeneracy at T <= window (AM-6); shifted-triangle MLE
       DIFFERS (the wrong-mask sanity leg).
     * PW-4 (broadcast reads): row-broadcast divisor (Sum_bc == free
       row-MLE read), col-broadcast gamma, row-broadcast D*2^tn.
     * The head-indexed public coefficient MLE (memo §1.6 / AM-3,
       the BG layer-MLE precedent extended to (l, h) = 4x2): fold ==
       dense F5 + the wrong-vector (tampered s_{l,h}) value moves.
     * rope-cs-table-v1 freeze legs: double-generation determinism +
       pinned oracle digests + bounds (c[0] = 128, |c|,|s| <= 128)
       at t_max 16 and 32.
     X1 PW BATTERY DIGEST f2f3913785f958f9.. .               [DONE]

  4. HEAD-INDEXED INSTANCES + THE PER-HEAD PROVEN CHAIN — DONE.
     xs1_run parameterized into xs1_run_core (s8 source, exp
     members, statement/transcript/rng tags as arguments; the JJ
     entry points byte-preserved — uperf-x battery digest
     be89d5da.. re-verified green both before AND after the NN
     arms landed). `uperf-x head-prove 1611 32`: the LAYER-derived
     per-head s8 blocks (tie asserted: the core's chain ==
     the layer's committed softmax slices bit-for-bit) proven
     through the full X-S1 machinery per head under HEAD-TAGGED
     statements (tag uperf3-nn-x1-head-v1; extra bytes bind head
     index + H + the 66-entry layer CHAIN digest; per-head wit/
     session rng tags), statement member = the layer-calibrated
     PINNED eS -6 member: 2/2 honest ACCEPT (120 data cms / 122
     commits / 1 wave / 479 pins each; commit 0.1 s + prove
     2.2-2.6 s + verify 0.4 s per head [WSL-BOX NOISY-SHARED]).
     X1 HEAD-PROVE DIGEST 5f5625f79ff825dd.. .
     `uperf-x head-battery 1611 32`: 7/7 AT-O8/O9-class legs on the
     layer-derived per-head chains, EACH at its pre-registered gate
     (legs alternate heads; the two chain-shape-dependent legs
     probe head support and assert, never skip): m-overstate h0 ->
     G2 F-hit; m-understate h0 -> rng-d-w8 root cross-check;
     zsel-two-hot h0 -> G1 F-one; zsel-off-support h1 -> G2 F-hit;
     off-support-P h1 -> G6; shifted-mask h0 -> G3's PW-3
     weight-MLE check; wrong-exp-member h1 -> the masked-claims sum
     gate (JJ's corrected registration, reproduced on layer data).
     17.6 s total. X1 HEAD BATTERY DIGEST 35ddec83ffcdcee9.. .
     Head-INDEXED instance families: the scores/PV/softmax entries
     are committed HEAD-STACKED ((H*T) x T tensors, head bits = the
     high index bits — the F-IF1 index-extension form the §4.3
     dispositions fold over), and the per-head shift/member freedom
     rides the coefficient-MLE machinery exercised in rung 3; full
     folded (l, h) instances over the claim engine are X3's
     integration (enumerated in rung 5).                      [DONE]

  5. THE RECORD — WHAT X3 (one full layer proven at 125M, then the
     12x512 full-LLM pass) STILL NEEDS, enumerated:
     (1) STATEMENT INTEGRATION (AT-O3, manifest v5): the 66 typed
         rows into a real ClaimManifest — operation kinds (or their
         decomposition into existing kinds + PW descriptors), the
         causal-mask convention flag, per-layer (tn, Cn, Ceps, fE,
         fP, wrho) metadata; v4 digests unmoved (BF-2b). X1 built
         the typed rows + census, not the manifest wiring.
     (2) THE NON-SOFTMAX CLAIM INSTANCES at layer scope: the
         matmul-class instances (QKV x3, scores, PV, Wo, SS/E/zsel
         rowsums), ZC3 (xsq/Dsq, DIV x3, F-hit), the RoPE deg-2
         zero-checks consuming PW-1 for real, the PIN families
         (requant edges, d-def, isqrt pins, limb recomps,
         residuals). All precedented (mm-*/had/rq-*), none yet
         built at attention shapes — X1 proved the SOFTMAX block
         per head through the X-S1 rig and validated every PW
         functional at value/MLE level.
     (3) FOLDED (l, h) INSTANCE FAMILIES: the head index as
         index-extension variables inside the folded families
         (scores/pv carry (l, h); rq coefficient MLEs head-indexed
         — machinery exercised in rung 3, fold-side IxfZcSpec +
         schedule integration not built). The entries commit
         HEAD-STACKED already (head bits = high index bits).
     (4) FREEZE RULINGS (VICTOR): exp members into lookup.rs/
         manifest.rs under the AM-2 key (function, e_in, e_out,
         params {d_h}) — additive, C5 registry ruling (joint with
         JJ's open item); rope-cs-table-v1 freeze rows (AT-O6);
         parametric range widths {1, 9, 10, 11, 13/14, 18} +
         shifts (AT-O5); the Stage-A sequencing ruling (memo §3.3)
         — X3's score-volume range facts should land on zc_range
         from the start, descent form as toy oracle.
     (5) X2 FIRST (AT-O1 as a C4 run): every exponent here is
         per-draw synthetic; X3 needs the frozen 125M per-layer
         exponent table + the 12 real exp members. §1.6b's Gemma
         data de-risks the CLASSES (per-tensor int8 core, widened
         seams), it is not the 125M table. The toy eS -6 wants the
         real-score-shape check X2 provides.
     (6) SCALE ITEMS AT T = 512: statement-DECLARED wrho (X1
         derives fE + log2 T lane-locally; fix it statement-side —
         the JJ open question stands); LKP-2/N_inst instancing
         gates (per-layer exp instances fine at 125M); W-1 column
         windows if stacked zc tables grow; the 15 GiB box
         discipline for the T^2 tensors (score volume 12 x 512^2).
     (7) THE SEAMS: resid2 must bind the REAL MVP-1 FFN output
         entry (the seeded stand-in retires); X_l = the shared FFN
         "X" entry (one commitment, two consumers — the AM-7-class
         layout fact); the inter-layer residual-stream pins (spec
         §4.3) with the cross-layer-seam REJECT leg extended.
     (8) RoPE THROUGH THE REAL EVAL PROOF: the flip-read's extra
         opening point through the mu-batched per-group eval proof
         (E-O2-BB preserved) — X1 checked the exact identity at
         MLE level, not the eval-proof plumbing; rope-cs member at
         (T_max 512, d_h 64, base 10000, fRo 7) frozen (32 KiB).
     (9) EMBEDDING/UNEMBEDDING (PW-5): outside X1's layer scope;
         needed for the 12x512 full-LLM milestone — last-position
         unembed default (X-D6), the PW-5 selector weights + F5.
    (10) INSTANCE-LEVEL BATTERIES: AT-O4 F5-pair ORDERING batteries
         per PW at proof level (X1's F5 legs are value/MLE level);
         the wrong-coefficient-vector PROOF-level reject at the
         instance terminal; k_eq_v (AM-7) only when Gemma enters.

LANE-LOCAL CONVENTIONS ADDED DURING THE BUILD (all recorded, none
transcript-affecting beyond this additive lane's own arms):
  * Seeded draws: tagged SHA-256 counter streams (tag || le64 seed
    || le64 ctr); weights [-16, 16] (the study's weight-RMS class,
    so eS lands non-degenerate), gammas [49, 79] at eG -6, x8
    full-range at declared eX -4.
  * RMSNorm e_y by integer max-calibration search (smallest
    window-admissible e_y whose narrowing holds — monotone), the
    oracle's window rule as the probe.
  * Head statements: tag uperf3-nn-x1-head-v1 + (head, H, layer
    CHAIN digest) extra bytes; per-head wit/session rng tags (two
    heads never share commitment randomness).
  * resid2's FFN input is a seeded STAND-IN (x1-ffn stream) at
    e_r1 — the X3 seam, loudly recorded in the arm and the table.
  * COMMIT-GRANULARITY DEVIATION (recorded): rungs 1-4 landed as
    one additive code block (two shared files + one new module +
    one script); each rung's gate ran green with its own digest
    before any commit; the ledger commits follow rung order. The
    one-commit-per-green-rung discipline collapsed to code+record
    commits — floors run on the combined tree (identical code).

FLOORS AT THE RUNG 1-4 COMMIT (aa33bf0), all on this tree [WSL-BOX
NOISY-SHARED]:
  * cargo build --release: green (0 errors).
  * uperf-pc diff-battery: passed (18.1 s).
  * uperf-s battery: 48 legs, digest 3752cba4.. UNCHANGED.
  * uperf-s agg-battery: 136 legs, digest 46234986.. UNCHANGED.
  * uperf-x battery: 8 legs, digest be89d5da.. UNCHANGED — verified
    both immediately after the xs1_run_core extraction AND on the
    final tree with the NN arms live (the refactor guard).
  * freeze-check (M125_EXPORT_DIR=results/m125_ffn_export_wsl):
    FULL exit 0, 102 ok rows.
  * uperf-pc zc-battery: 7/7 legs, digest 01ca048b.. UNCHANGED.
  * composed 7465fa05..: NOT re-run — the u3 region untouched (the
    diff is the additive NN block + the parameterized JJ core; no
    u3/composed path in the change set).
  * Extra point: head-prove 2/2 ACCEPT also at seed 20260811 T 32
    (digest 23a6c75a.., seed-dependent as expected); layer-chain
    byte-identity additionally checked at seed 5 (6 pairs total).

NEW LANE DIGESTS (this lane's arms; existing digests never moved):
  X1 ENTRIES    0358428f85efd1d84d2ad9c0aa3737dec80c3f87cd66d34c
                e7d2284f6c774ca8 (1611, 16); 0e895bda.. (1611, 32)
  X1 CHAIN      ee72b55f0793003540cc9fde9a7c9f196d73fba7074d3994
                a2b903cc2c5382a1 (1611, 16); b646c164.. (1611, 32)
  X1 PW BATTERY f2f3913785f958f9ad8b3b0105518d75e73db616671aa0e0
                54abbb9b8b3d070f (19 legs)
  X1 HEAD-PROVE 5f5625f79ff825ddb4a5d6c02b03b21c2e75e5b3e267cae8
                cdd5a92f89878d15 (1611, 32; 2/2 ACCEPT)
  X1 HEAD BATT  35ddec83ffcdcee93440423d4ec1b081f9decfd12ef13d5e
                bb36704de2cc7a72 (7/7 pre-registered)

STATE: DONE (2026-08-31) — rungs 0-5 landed on uperf3-nn (skeleton
c022b4e; rungs 1-4 + records aa33bf0; this close commit), all
pushed. Footprint purely additive: ring/attn_entries.rs (NEW) + one
mod line + one #[derive(Clone)] on SoftmaxChain + the
behavior-preserving xs1_run_core parameterization in the JJ bin
section + the [UPERF3-NN] bin section + scripts/
attention_x1_layer_ref.py (NEW) + this ledger section. Frozen
registries untouched; every pre-existing battery digest byte-
identical. OPEN QUESTIONS live in the rung-5 needs list (freeze
rulings item 4 -> Victor, jointly with JJ's exp-member C5 ruling).
## Agent OO status (wt-uperf3-oo) — round 8

STATE: OPEN (2026-08-31) — DIET 3: the per-class compact layer
store. BfLayer's 17 chain tensors held as Vec<i64> are the
commit-phase term (66 GB at 8B 32x512, ~245 GB at 30B — the LAST
phase term above ~75 GB after rounds 5-6). Per class the values fit
narrow storage: i8 for X/weights/g8/a8/u8/h8/z (|v| <= 127 by the
range facts), i32 for Gacc/Uacc/Dacc/H and the remainders (bounded
by the acc bits). The consumers keep reading i64 VALUES through the
accessor surface — a REPRESENTATION change only.

DESIGN PICK (the brief's option (a), recorded): compact planes in
BfLayer + `bf_entry_values` returns a per-call materialization
GUARD (`BfVals`: Borrowed for wide planes, Owned Vec<i64>
materialized from compact ones; Deref to [i64]) — NOT option (b)'s
LRU. Why: (1) no interior mutability — guard lifetimes make the
live set explicit at every call site and the borrow checker
enforces it; (2) the consumers are phase-local and touch one plane
at a time except three named sites, each with a local fix (hoist
per-layer planes out of bg_mm_tables' block fill; feed
agg_digit_witness_cols per tensor instead of a whole-group
Vec<&[i64]>; move the guards into bk_tree_slot_fns' closures);
(3) an LRU "sized to the live set" needs a phase-dependent policy
plus shared mutable state under rayon (`Sync` per-leaf closures in
the tree fills) — a lock inside the threaded packed fill, i.e.
serialization risk for no extra memory win.
  Plane classes I8/I16/I32 with an I64 fallback chosen by VALUE
SCAN at store time: honest chains compact (the range facts are the
guarantee); tampered chains that exceed a class ride WIDE — values
exact, the PROOF is what rejects, no new panic path (the
RangeViolation/WrongTable arms write through the same store).
I16 is what makes the W-8 row's ~9.9 GB: H/Rh/Rg/Ru/Rd fit i16 at
the m125/8B shifts; the pure-i8+i32 split counts ~12.9 GB.
  U3Layer: OUT OF SCOPE, recorded — it is the v3 engine spike rig
(24 fields incl. i16-class a16/u16/h16 limbs + lo/hi split planes,
its own u3_entry_values surface); the same BfPlane machinery
applies verbatim when a later rung wants it; the 8B commit-phase
term W-8 prices is BfLayer.

RUNG PLAN (one commit per green rung, prefix "U-PERF3 OO:"):
  0. skeleton + BASELINE: this section; /usr/bin/time -v digests +
     peak RSS at fp3x16 / pa12x64 / fp12x64 under flock; floors.
  1. compact store for the WEIGHT planes (wg_t/wu_t/wd_t — 45 of
     the 66 GB at 8B; lowest-risk consumers). ACCEPT: five anchors
     byte-identical, RSS delta recorded.
  2. the activation/accumulator/remainder planes (x, gacc, rg, g8,
     a8, uacc, ru, u8v, hh, rh, h8, dacc, rd, z). ACCEPT: same.
  3. THE RECORD: the RSS curve on top of HH+KK, the counted 8B and
     30B projections (does the 8B peak now sit at lvl-0 ~72 GB;
     what 30B's peak becomes), open questions.

DISCIPLINE (HH/KK verbatim): transcript-preserving ONLY — at EVERY
rung the five identity anchors byte-identical (fp3x16 stmt
93a98700.. + EP 0ae9cdae..; pa12x64 stmt 45fb3405..; fp12x64 stmt
80763ea5.. + EP 63f4a3a4..; full values at rung 0 below); floors
green (build; uperf-pc diff-battery; freeze-check 102 ok exit 0;
uperf-s battery 3752cba4..; agg-battery 46234986..; uperf-x battery
be89d5da..). ANY digest move = revert the rung, record, do NOT fix
forward. Runs under flock /tmp/zk-heavy.lock, NOISY-SHARED label;
shapes 3x16 and 12x64 only.

BASELINE (2026-08-31, WSL box, ZK_THREADS=8, M125_EXPORT_DIR=
/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl,
each run one-at-a-time under flock /tmp/zk-heavy.lock; sibling lane
NN shares the box — NOISY-SHARED applies to walls; tree = 20aa4b5,
the round-8 ledger commit = KK's round-6 endpoint merged):
  * fp3x16: accept=true, wall 6.38 s, peak RSS 869,172 KB; STATEMENT
    93a987002a7c4b60c3dfbfc62b7a4f0e5957d8ae2039014ff241e323285fb790
    EVAL-PROOF
    0ae9cdae66607239a80cc1f1dea36248370edadbe85214144aee7a5250d975be
  * pa12x64 (pass-agg prove 12 64 p0): wall 19.87 s, peak RSS
    2,040,644 KB; STATEMENT 45fb340517eee2344b44dd40d4e47562d80305
    eb7c5604c9c6cf61ede37443dc
  * fp12x64: accept=true, wall 26.13 s, peak RSS 2,164,948 KB;
    STATEMENT 80763ea537e77cd9cb5c538397af2622044447d654b8e9a34cae
    3ccad8f3f115; EVAL-PROOF 63f4a3a4320a47260ab8ae3d52cfa3656b626f
    c367af671c6c317300454dec89
  (all five anchors match the brief's pinned values; the RSS figures
  reproduce KK's rung-2 endpoint within noise.)
  * Floors: diff-battery exit 0 (15.55 s, incl. the 2-level E2E
    cross-verify); freeze-check exit 0, 102 ok rows (full pass —
    this box has the export); uperf-s battery 48 legs 3752cba4..;
    agg-battery 136 legs 46234986..; uperf-x battery 8 legs
    be89d5da..

RUNG 1 — WEIGHT PLANES LANDED (2026-08-31): wg_t/wu_t/wd_t live as
compact `BfPlane`s (I8 for honest chains — the export values are
i8-source) and the WHOLE accessor surface moved to the guard form in
this rung: `bf_entry_values -> BfVals` (Deref to [i64]; Borrowed for
the still-i64 tensors, so rung 2 is a field flip with no further
consumer surgery). The named wide/hot consumers got their local
fixes NOW: bg_mm_tables hoists per-layer planes out of the per-block
fills (one materialization per layer, not per block); the zc
IxfZcSpec site holds guard owners; bg_witness / bk_witness_act /
bk_witness_weight / gg_witness_act feed agg_digit_witness_cols
PER TENSOR through new additive `agg_digit_witness_{cols,ref}_src`
(fetch closure; the old &[&[i64]] forms remain as wrappers — no
whole-group i64 materialization); bk_member_vals returns guards and
bk_tree_slot_fns moves them into its Sync closures; the tamper arms
write through BfPlane::get/set/fill_zero (set widens the class in
place if a tampered value does not fit — no new panic path); the
GG serving-check leg holds owners; derive/battery GEMMs materialize
weight inputs transiently.
  ACCEPT: all five identity anchors BYTE-IDENTICAL (93a98700 /
  0ae9cdae; 45fb3405; 80763ea5 / 63f4a3a4); floors green
  (diff-battery exit 0 in 18.0 s; freeze-check 102 ok exit 0;
  uperf-s 3752cba4..; agg 46234986..; uperf-x be89d5da..).
  RSS delta [MEASURED, NOISY-SHARED, vs rung 0]:
    fp3x16     869,172 ->   814,624 KB  ( -53 MB,  -6.3%)
    pa12x64  2,040,644 -> 1,653,768 KB  (-378 MB, -19.0%)
    fp12x64  2,164,948 -> 1,778,104 KB  (-387 MB, -17.9%)
  (the counted 12-layer weight store is 452 MB i64 -> 57 MB i8 =
  -396 MB; the measured 378-387 MB at the 12x64 shapes IS that term
  minus transients — the fix behaves exactly as priced.)
  WALL delta [MEASURED]: fp3x16 6.38 -> 6.36 s; pa12x64 19.87 ->
  20.13 s; fp12x64 26.13 -> 26.10 s — within run noise (the
  materialization cost is one i64 copy per plane consumer, paid
  against O(plane) walks that already existed).

RUNG 2 — ACTIVATION/ACCUMULATOR/REMAINDER PLANES LANDED (2026-08-31):
the remaining 14 fields (x, gacc, rg, g8, a8, uacc, ru, u8v, hh, rh,
h8, dacc, rd, z) flipped to BfPlane — ALL 17 chain tensors now live
compact per class (the rung-1 accessor surgery made this a field
flip: bf_entry_values already guards every entry; new additive
bf_entry_plane gives len/get without materialization).
bf_derive_chain computes the chain in i64 locals VERBATIM (same
operations, same values) and compacts each tensor once its last i64
use passes; bf_load_layer's range-fact assert is BfPlane::fits_i8
(the exact old predicate); the z digest check materializes; the
tamper arms (BfTamper::RangeViolation, zc_perturb_h,
bk_range_violation, the GG +2^w bump via gg_entry_values_mut ->
&mut BfPlane) write through get/set — the widening path carries any
out-of-class tampered value exactly.
  ACCEPT: all five identity anchors BYTE-IDENTICAL (93a98700 /
  0ae9cdae; 45fb3405; 80763ea5 / 63f4a3a4); floors green
  (diff-battery exit 0; freeze-check 102 ok exit 0; uperf-s
  3752cba4..; agg 46234986..; uperf-x be89d5da..). PRUDENCE legs
  beyond the floors (the edited tamper arms exercised end to end):
  m125-pass battery small ALL LEGS ok exit 0 (533 s — WrongWeight/
  WrongTable/SeamSwap/RangeViolation/WrongMap each rejects at its
  pre-registered gate); table-descent battery small 5/5 ok (74 s,
  incl. the BK RangeViolation leg).
  RSS delta [MEASURED, NOISY-SHARED, vs rung 1]:
    fp3x16     814,624 ->   814,116 KB  (  -0.5 MB — peak sits in
                                          claim/verify, not the store)
    pa12x64  1,653,768 -> 1,562,672 KB  ( -91 MB)
    fp12x64  1,778,104 -> 1,668,184 KB  (-110 MB)
  (the counted 12x64 non-weight store is ~140 MB i64 -> ~35 MB
  compact = -105 MB; the measured 91-110 MB IS that term.)
  WALL delta [MEASURED, honest]: fp3x16 6.36 -> 6.84 s; pa12x64
  20.13 -> 21.24 s; fp12x64 26.10 -> 27.78 s (+5-6% at 12x64 — the
  per-consumer guard materializations; NOISY-SHARED box, lane NN
  building concurrently).

RUNG 3 — THE RECORD (2026-08-31).

THE MEASURED 125M-SHAPE RSS CURVE (peak RSS KB, /usr/bin/time -v,
ZK_THREADS=8, flock-serialized, NOISY-SHARED box; the OO baseline IS
KK's round-6 endpoint — rounds 5-7 merged at 20aa4b5):
  shape    OO base    +weights (r1)  +all planes (r2)   lane total
  fp3x16     869,172     814,624        814,116          -55 MB  ( -6.3%)
  pa12x64  2,040,644   1,653,768      1,562,672         -478 MB  (-23.4%)
  fp12x64  2,164,948   1,778,104      1,668,184         -497 MB  (-22.9%)
  Counted check: the 12-layer 12x64 store is 598 MB i64 -> ~93 MB
  per-class = -505 MB; the measured -478/-497 MB IS that term (the
  small gap = guard transients live at the high-water mark). fp3x16
  moves less than its -104 MB counted store because its peak sits in
  the claim/verify phases where only part of the store overlaps.
  CUMULATIVE across the THREE diet lanes (HH + KK + OO) vs the
  round-5 baseline: fp3x16 1,126,084 -> 814,116 (-27.7%); pa12x64
  2,968,604 -> 1,562,672 (-47.4%); fp12x64 3,091,220 -> 1,668,184
  (-46.0%).
  Walls [MEASURED, honest]: fp3x16 6.38 -> 6.84 s; pa12x64 19.87 ->
  21.24 s; fp12x64 26.13 -> 27.78 s (+5-6% at 12x64: the guard
  materializations in the claim/commit walks; lane NN was building
  concurrently — treat as an upper bound).

THE COUNTED 8B PROJECTION (32x512; t=512 d=4096 f=14336; 257.9M
elements/layer x 32 = 8.25G, i64 66.04 GB — the W-8 row's number
reproduced exactly):
  The per-class store: i8 planes (X + 3 weights + g8/a8/u8/h8/z)
  209.7 MB/layer; H i16 (|a8*u8| <= 16129); Gacc/Uacc/Dacc i32
  (inner-dim bounds 2^26-2^28); remainders i16 or i32 by the m8b
  shifts (auto-picked by from_vals) -> 339.7-388 MB/layer =
  **10.9-12.4 GB total** (5.3-6.1x; the W-8 row's ~9.9 GB assumed
  every remainder i16 — the honest band depends on the calibrated
  shifts, sh < 15 gives the low end).
  The phase table (KK's corrected projection with L compact; range-
  only Stage A [GG] + W-3 [mandatory] + ZK_W0_REGEN [exists] +
  HH/KK diets assumed as before):
    commit  ~61  (WAS ~116: L 66 -> ~11.5; W_w 45.1 + act split 4.7)
    claim   ~20  (WAS ~71: L compact + W-1 windows + zc guard
                  owners ~5.6 transient)
    lvl-0   ~72  (unchanged — W 63.7 flat + z_all 5.9 + flat store)
    lvl-1   ~29  (KK)
    verify   ~6  (KK)
  VERDICT: **the pass peak now sits at lvl-0 ~72 GB — exactly the
  W-8 row's prediction; UNDER 128 GB with ~56 GB margin (was ~12 GB
  at the commit phase before this lane), UNDER the Mac trivially.**
  32x16 (the yardstick): L 45.8 -> ~5.7; the ~95 GB claim/descent
  peak drops to ~55-57 (descents still read lays — compact now);
  commit 91.5 -> ~51. T9's 12x512 CPU row: store 1.61 -> ~0.35 GB;
  projected ~8-9 GB with HH+KK+OO (NOT measured — shared-box rule).

THE 30B PROJECTION (the brief's ~245 GB i64 store, ratio 3.71x the
8B layer volume): L compact = **~40-46 GB** (from ~245 — the store
is no longer the blocker at ANY box under ~64 GB headroom for it).
30B's peak becomes the W-side group terms (lvl-0 ~72 GB at 8B
scales to ~265-270 GB): the known levers are per-layer-range
WEIGHT-group splits (the W-3 mechanism applied to the weight side),
ZK_W0_REGEN, and the already-landed A_0/phi streaming — a build
round of its own, NOT this lane; L is off the critical list.

OPEN ITEMS / NOT DONE HERE:
  * bg_zc_window_vals materializes the FULL entry plane per (layer,
    window) to slice one column window — O(windows x plane) copies
    on the W-1 windowed path at 8B (wall, not memory). A compact
    window extractor over bf_entry_plane would make it O(window).
  * bg_mm_tables' hoist holds BOTH operand planes across all layers
    as i64 while the full tables build (~17 GB transient at 8B for
    an (h8, WdT) instance) — only IF the unwindowed path runs
    there; the W-1 windowed claim path avoids it. A monomorphized
    per-class fill would remove the transient entirely.
  * bk_tree_slot_fns' closures own materialized member planes for
    the live tree (oracle-descent mode only; Stage A is the 8B
    path and never builds them).
  * The +5-6% 12x64 wall: the biggest per-call materializers are
    the bg_mle claim-parts loop and bf_commit_entries; both could
    read through bf_entry_plane (get/window) if 8B walls demand it.
  * U3Layer: OUT OF SCOPE as recorded at rung 0 — the v3 engine
    spike rig (24 fields incl. a16/u16 i16 classes and the h16
    lo/hi limb planes, its own u3_entry_values surface); BfPlane
    applies verbatim when a lane owns that surface.
  * bg_pass_run still keeps lays end-to-end (HH's open item) — now
    6.4x smaller; pa12x64's -478 MB is that term shrinking.

STATE: DONE (2026-08-31) — rungs 0-3 landed, one commit each, all
pushed on uperf3-oo; every rung transcript-preserving (five digest
anchors byte-identical at every commit: fp3x16 93a98700../
0ae9cdae.., pa12x64 45fb3405.., fp12x64 80763ea5../63f4a3a4..)
with floors green (diff-battery; freeze-check 102 ok exit 0;
uperf-s 3752cba4..; agg 46234986..; uperf-x be89d5da..; plus the
m125-pass and table-descent tamper batteries at rung 2).

## ROUND 9 — X2 + THE COMMITTED-H ENCODING (opened 2026-09-01)

### Lane PP — X2: the 125M attention calibration gate (wt-uperf3-pp) — PYTHON
OWNS: NEW scripts/m125_attn_gate.py (or an m8b_gemma4_attn_gate.py
generalization — additive, Gemma defaults byte-identical), NEW
results files, "Agent PP status". WHY: lane JJ's close recorded
that the 125M model's ATTENTION exponents were never captured (the
original study ran attention fp32) — X3 (one full attention layer
proven at 125M) needs MEASURED 125M exponents, and X2 is the
memo's AT-O1 C4-style gate at 125M. GOAL: the stats + attribution
phases of the Gemma gate pattern on the FRUGAL 125M checkpoint
(local since T10; the frugal arch adapter exists in
m8b_int8_calibration.py): per-site range profiles, the int8
first-order attribution, the widened-class check where poisoned,
and the exponent table (AT-O1) as X3's calibrated source. The
equiv gate (hooks-off bit-exactness vs the validated frugal
walker) is the precondition leg, as always.

### The committed-h encoding (orchestrator, lane II-style) — DESIGN
The F1 full-mode ruling's price: count the candidates (the v3
limb-split h vs GG's naive act-h vs derived-not-committed h with
the range facts read through the Hadamard relation), fold in the
owed 8B full-mode memory recount from OO's new baseline. Memo:
docs/zkmatrix-poc/U_PERF3_COMMITTED_H.md.

## Agent PP status (wt-uperf3-pp) — round 9, X2: the 125M attention gate

LANE: X2 — AT-O1 as a C4-style gate run at 125M (the round-9 Lane PP
brief above; the CC pattern scripts/m8b_gemma4_attn_gate.py — that
file UNTOUCHED — transplanted to the frugal adapter in
m8b_int8_calibration.py --arch frugal). Deliverable: the MEASURED
125M attention exponent table + site verdicts so X3 builds on
measured, not synthetic, exponents (NN rung-5 item 5; the toy eS -6
wants the real-score-shape check).

OWNERSHIP: NEW scripts/m125_attn_gate.py; NEW results/m125_attn_*
files; this ledger section. Everything else READ-ONLY (python-only
lane; no Rust files touched; frugal-lm never written).

DATA: the local-since-T10 checkpoint
/home/victor/models/125m-best-adamw-val3.0816/model.safetensors +
val shard /home/victor/shard-00000.npy; the m125 sampler verbatim
(seed 1337, 8 cal + 8 val disjoint T=512 windows —
scripts/m8b_verify_125m.py proved this sampler + the m8b frugal
walker reproduce the committed calibration 108/108 on this box).

THE 125M SITE LIST (enumerated from frugal-lm src/frugal_lm/model.py,
read-only: pre-norm two-norm sandwich, RoPE rotate-half, GQA H 12 /
H_kv 4, d 768, d_h 64, scale hd^-0.5, NO QK-norm):
  Wattn, xattn [xn8], q, k (RAW projections PRE-rope — the Gemma hook
  position with the QK-norm stage nonexistent), v (no v_norm),
  scores [s8 — SCALED at hd^-0.5 unlike Gemma's 1.0], exps [E fE=9],
  probs [P fP=9 floor], ctx [o8], ao [ao8], xres [xres1].
  ABSENT vs Gemma (by architecture, stated not papered): postn (no
  post_attention_layernorm — two-norm sandwich), q/k/v norms (AM-5),
  post_ffw_norm + layer scalar (facts F2), sliding/global family
  split (all 12 layers plain causal). qr/kr recorded as stats.

RUNG PLAN (one commit per green rung, prefix "U-PERF3 PP:"):
  0. skeleton: this section + scripts/m125_attn_gate.py (a NEW script
     importing the shared m125/m8b machinery — the safer branch of
     the brief's choice; the Gemma gate stays byte-identical). [DONE]
  1. EQUIV (the precondition): hooks-off walker BIT-EXACT vs the
     validated m8b frugal Walker on the val windows (final-hidden
     array_equal + loss equality + logits sha256)
     -> results/m125_attn_equiv.json. STOP and record if not.
     DONE: BIT-EXACT at 12 layers (hidden sha256 1922d7d3aff85b33..,
     logits w0 sha256 7ae681a974246ff9..); val loss (8 win, numpy)
     3.228673 both walkers — matches the committed mlx loss_ref
     3.2286728 at the 1e-6 level (the documented numpy-vs-mlx drift
     is negligible at 125M). 49 s, RSS 0.96 GB [WSL-BOX
     NOISY-SHARED]. 2-layer smoke also green.               [DONE]
  2. STATS: the full 12-layer per-site range profiles
     (absmax/p999/p9999, per-head where head-structured) on the 8
     cal windows -> results/m125_attn_stats.json.
     DONE [MEASURED WSL-BOX NOISY-SHARED, 28 s, RSS 0.55 GB]:
     * COMPUTE CORE TIGHT (the Gemma picture WITHOUT QK-norm):
       q/k/v/scores/ctx absmax/p999 ratios <= 5.6 (mostly <= 3).
       e8 ranges: q [-3,-2], k [-4,-3], v [-5,-3], ctx [-5,-4].
     * **scores e8 = -2 at ALL 12 LAYERS** — ONE distinct eS, so
       X3 needs ONE exp member (exp-neg, eS -2, d_h 64, fE 9), not
       the 12 the design doc counted — and it is the SAME (eS -2)
       class JJ's prove-cal already pinned from Gemma l0.
     * qr/kr post-rope: e8 == q/k's everywhere (no +1-bit layer —
       even the Gemma l5 qr quirk is absent).
     * xattn mildly stretched (absmax ~19-20, ratio <= 2.9,
       col_ratio 5.3-9.1) — far milder than Gemma l0's 1302/100.
     * xres = the residual-stream growth again but milder: absmax
       2.4 -> 357 (l8 peak), e8 -5 -> +2, ratio <= 7.95, col_ratio
       to 30.5. ao ratio <= 4.3.
     * probs: 40-86% of causal support below the fP=9 step (the
       fixed-point floor is the binding constraint, as at Gemma).
                                                              [DONE]
  3. ATTRIB: per-site int8 quantize-dequant first-order deltas (FFN
     fp), exponents frozen from the stats pass, val subset take=2
     -> results/m125_attn_attrib.json. Expectation to TEST, not
     assume: the attention core int8-clean (the Gemma 1.6b picture);
     a surprise here is a major finding.
     DONE [MEASURED WSL-BOX NOISY-SHARED, take=2, ref_subset
     3.3587, ~7 s/site]: q -0.0004, k +0.0009, v +0.0000, scores
     +0.0006, exps +0.0005, ctx -0.0003 (core CLEAN at the noise
     floor) — and unlike Gemma, the SEAM sites are clean too:
     Wattn +0.0015 (vs Gemma +0.2000), xattn +0.0020 (vs +2.0043),
     ao -0.0002 (vs +0.4081). probs +0.0167 (the fP=9 floor cost,
     visible but sub-material). **xres +4.2747 — the ONE poisoned
     site** (the residual-stream disease, concentrated). all_int8
     +2.7750 (composed anchor; below the xres single — the same
     first-order over-count interaction CC recorded).        [DONE]
  4. WIDEN (only if attrib shows sites >= +0.10 nats): int16 singles
     + per-head variants + the composed stack_wide row
     -> results/m125_attn_widen.json.
     DONE [same rig]: xres16 single +0.0000 — the poison DIES with
     one class widening (cleaner than Gemma's -0.0549). Composed
     **stack_wide** (EVERY site int8 incl. Wattn, ONLY xres int16,
     exps fE=9, probs fP=9): **+0.0314** vs all_int8 +2.7750 —
     inside the +0.1-nat class, better than Gemma's +0.0854; the
     residue is mostly the probs fixed-point floor.          [DONE]
  5. RECORD: the AT-O1 table X3 consumes (per site per layer: e8,
     class, exp members keyed (eS, d_h 64, fE 9), wrho = fE +
     log2(T) = 18) -> results/m125_attn_at_o1.json + the 1.6b-style
     verdict paragraph here and the 125M column note for the design
     doc's site->class table (§1.6b extension left to the merge if
     doc ownership is contested; the JSON is the source of truth).
     DONE: results/m125_attn_at_o1.json (per site per layer e8 +
     class + per-head e8 lists + exp-member keys + probs floor
     stats; poison threshold 0.10 nats recorded in meta). [DONE]

THE 125M AT-O1 VERDICT (the §1.6b-style paragraph — X3's measured
source; every number [MEASURED WSL-BOX NOISY-SHARED], attrib/widen
on the 2-window val subset, machine-independent):

1. **The attention COMPUTE CORE is int8-clean per-tensor at 125M —
   WITHOUT QK-norm.** Ratios <= 5.6; first-order int8 deltas q
   -0.0004, k +0.0009, v +0.0000, scores +0.0006, exps +0.0005,
   ctx -0.0003 (all at the subset noise floor). Per-head exponent
   vectors are NOT needed at first order (degenerate per-tensor C2,
   as at Gemma); qr/kr take q/k's exponents with no extra bit
   anywhere (even Gemma's one l5 quirk is absent).
2. **The Gemma four-site widened class COLLAPSES TO ONE SITE at
   125M.** Wattn +0.0015, xattn +0.0020, ao -0.0002 — the seam
   sites Gemma needed widened are CLEAN here; postn does not exist
   (two-norm sandwich). The residual-stream disease concentrates
   entirely at **xres +4.2747**, rescued by one class widening to
   **+0.0000** (xres16). Composed **stack_wide** (every attention
   site int8 incl. Wattn, ONLY xres int16, exps fE 9, probs fP 9):
   **+0.0314** vs all_int8 +2.7750 — inside the +0.1-nat class and
   better than Gemma's +0.0854.
3. **ONE exp member serves the whole model**: scores e8 = -2 at ALL
   12 layers -> the single member (exp-neg, eS -2, d_h 64, fE 9) —
   the design doc's counted "12 at 125M" becomes 1 MEASURED, and it
   is the same eS -2 class lane JJ's prove-cal already pinned from
   Gemma l0 (X3's member freeze list = ONE row). wrho = 18 at the
   contract T 512.
4. **probs carries the one visible sub-material residue**: +0.0167
   first-order (40-86% of causal support below the fP=9 step — the
   fixed-point floor binds, not range). fP is a statement
   resolution knob; the composed +0.0314 says fP 9 is acceptable
   at 125M (same decision family as CC's Gemma fP note).
5. X3 CONSUMPTION NOTES: (a) NN's X1 entry table carried the Gemma
   measured defaults (seam sites ao/postn/xres int16 per the Gemma
   stack_wide ruling) — the MEASURED 125M classes narrow that to
   xres-only int16, ao int8, no postn row: reconcile the 66-entry
   table's exponent-source column to results/m125_attn_at_o1.json.
   (b) l0 is range-atypical (xattn/v/ao e8 -5 vs -2/-3 elsewhere;
   xres e8 -5 vs +1/+2) — keep per-layer exponents, do not collapse
   layers. (c) The toy eS -6 concern (NN rung 2 note) is resolved:
   real 125M scores land eS -2. (d) Deltas are first-order on a
   2-window subset; stack_wide +0.0314 is the decision number.

STATE: LANE COMPLETE (2026-09-01). Commits: 5339707 skeleton,
b689dcf equiv, 35cd6ad stats, 05c5c08 attrib+widen, close = this
commit. Files: scripts/m125_attn_gate.py;
results/m125_attn_{equiv,stats,attrib,widen,at_o1}.json (+ .log).
The Gemma gate script and all Rust untouched.

## ROUND 10 — THE THROUGHPUT ROUND (opened 2026-09-02; Victor: "Let's
## go with your recommendation ... Our goal should be to get at least
## about 50 tokens/second throughput on a 30B parameter model with one
## gpu (although it can be a very beefy GPU if needed). This is the
## competition to beat")

Ground: round 9 merged (8e2060d); START_HERE.md (0642ca0) is the
onboarding page every lane reads FIRST. Worktrees wt-uperf3-{qq,rr,ss}
cut at 0642ca0. Lane TT is a docs-only lane run from the main
session (no worktree). The Mac runbook (MAC_RUNBOOK.md) is the
orchestrator's deliverable this round; Victor pulls and runs it.

THE NEW GOAL, stated plainly: >= 50 proven tokens per second for a
30B-class model on ONE GPU (H100-class allowed). The competitor's
claim: Gemma-4-31B at 53 tok/s (batch 1) / 77 tok/s (batch 4) on one
H100 [EXTERNAL, VENDOR-CLAIMED]. One decoded token at 30B costs ~3.1e10
MACs, so 50 tok/s = ~1.55e12 proven MAC/s. Our measured rate is 1.4e9
on the laptop's RTX 4070 (55-70 W) [MEASURED 2026-08-18]. Lane TT owns
the honest conversion; nobody else quotes a tokens/s number without it.

TWO FACTS VICTOR ASKED TO DOUBLE-CHECK (2026-09-02):
1. The board's 2026-08-30 line ("~25-35 tok/s amortized; Stage-A
   aggregate GPU port + fold fusion 1.2-1.5x; pipelining 1.3x; spine
   amortization 1.1-1.2x -> ~65") has NO derivation anywhere in the
   ledgers or memos (grep confirms: the only "fold fusion" in this
   ledger is lane DD's AVX2 rung 5). It is UNSOURCED until lane TT
   derives or retracts it. Lane RR MEASURES the Stage-A-on-GPU factor.
2. Weight preprocessing ((vi-a): the weight side computed once per
   model, not per proof) has NEVER been built or measured — it is
   "designed only" (U_PERF3_HEADLINE_ROUTES.md §2.6). Lane QQ builds
   and measures it, on the two-tier opening it depends on.

STANDING RULES FOR EVERY LANE (in addition to TASK_BOARD §1 and
CLAUDE.md): read START_HERE.md §8 before writing anything; build
with `flock /tmp/zk-build.lock cargo build --release` inside your
worktree's zkmatrix-rs/ (one build at a time on the 15 GB box); any
run expected > 5 minutes is NOT run by the lane — post the exact
command in your status section and STOP; the orchestrator runs it
detached under /tmp/zk-heavy.lock and pastes the result (agents
stall on background-run wakes — measured three times in August);
one commit per green rung, prefix `U-PERF3 <LANE>:`; every wall
carries [WSL-BOX|MAC-BOX] [1T|NT] [QUIET|NOISY-SHARED]; the built
pass stays byte-identical (floors: release build, `uperf-pc
diff-battery`, `freeze-check` with M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
102 ok rows, uperf-s battery digest 3752cba4.., agg battery
46234986.., uperf-x be89d5da..).

### Lane QQ — the two-tier opening + weight preprocessing on the GPU (wt-uperf3-qq) — RUST/CUDA + COUNT
OWNS: zkmatrix-rs/src/ring/two_tier.rs (ADDITIVE: new functions
behind flags; the S4 code paths stay byte-identical), NEW
zkmatrix-rs/src/ring/gpu/two_tier_gpu.rs (or a kernel-string file
beside the existing GPU kernels, + its one `pub mod` line), the
`uperf-t` bin section (ADDITIVE subcommands), NEW results/uperf3_qq_*,
"Agent QQ status". READ-ONLY: eval_proof.rs, stage_a.rs, the pass,
manifest.rs, every other ring module.
WHY (plain words): 71% of the 8B witness is weights, and weights are
a per-model constant. The two-tier ("square-root") opening lets the
expensive lattice recursion see only a sqrt-sized summary, and lets
the weight side's tier structure be built ONCE per model. Spike S4
(lane FF) measured the CPU form at 1.10x because its "cheap" linear
pass computed general ring products (79% of the time); the redesign
memo (U_PERF3_S4_REDESIGN.md §2 R1 + C-R1) counted the factored
"swap-order" form at 2-5x on that pass and 1.6-2.5x composed — AT
ONE CPU THREAD, on a synthetic shape. Nobody has counted or measured
(a) that linear pass as GPU scalar-MAC kernels, or (b) the per-proof
cost with the per-model part cached. This lane does both. It is the
test of whether the routes memo's "~20-40 s/board" row and Victor's
50 tok/s target are reachable on the lattice line.
RUNGS (one commit each, prefix "U-PERF3 QQ:"):
  0. SKELETON: this section; `uperf-t` usage lists `count`, `r1`,
     `gpu`, `repeat`; floors green.
  1. COUNT (a printer, no proving): `uperf-t count <log2_rings>` —
     for the C-R1 swap-order form (memo §2 R1: v[e][i] = sum_cb
     sum_d conjQ[cb][d] (x) S[i][cb][d][e], with the Y^d-basis
     shift collapsing (d,e) to (e-d) + a rank-limited twist), the
     scalar MACs and ring products per phase (rows / v-pass / fold /
     recursion) at 2^22, at the 8B weight group (352,321,536 rings,
     U_PERF3_HEADLINE_ROUTES.md §1.2) and at a 30B weight group
     (count it from U_PERF3_MVP8B_SCALING.md's model; state the
     shape you assume), split into PER-MODEL (alpha-independent:
     tier-1 commitments, CRS blocks, tier layout) vs PER-PROOF
     (alpha-dependent). Expected walls on the RTX 4070 [MODEL] from
     the measured kernel classes (U_PERF2_GPU_REPORT.md's GEMM
     kernel throughput; the K9 E_c class). Print the table; record
     it here. This rung alone is ruling-grade input.
  2. R1 ON CPU: the factored v-pass behind a flag; the S4
     differential legs at 2^20 (b_rows byte-equal, per-contrib y_m
     equal, h_cur equal — the FF rung-2 legs, reused verbatim);
     wall at 2^22 1T vs the measured 20.01 s v-pass (FF's
     bench22_1t_v2). ACCEPT: bit-identical; record the ratio
     whatever it is.
  3. THE DEVICE PORT of the linear pass: the factored v-pass as a
     cudarc/NVRTC kernel (integer MACs mod q31 with the existing
     reduction conventions — copy the pattern of the level-h GEMM
     kernel); bit-identical to rung 2 at 2^20/2^22; wall at
     2^22/2^23 with ZK_GPU=1 vs the built `bg_prove_group` GPU path
     at the same shape (the FF bench harness already times both).
  4. THE PREPROCESSING BOUNDARY: split the two-tier state into a
     per-model struct (built once, held across repeated proofs in
     one process; disk cache optional) and per-proof work;
     `uperf-t repeat <log2_rings> <n>` proves n times with the
     per-model part warm and prints per-proof wall; then on the REAL
     12x512 WEIGHT group (M125_EXPORT_DIR set): the per-proof
     weight-side opening wall on the 4070 vs the built weight-group
     opening (ZK_GPU=1 both). Claims bit-identical (rung-2 legs).
  5. RECORD: the measured constants -> the 8B and 30B projections
     [MODEL] with the per-proof/per-model split, in a table lane TT
     can consume; the VERDICT against the reopen bar: per-proof
     weight-side opening at the 12x512 weight group >= 5x faster
     than the built GPU path with claims bit-identical. If NOT:
     record the measured ratio and STOP — the ratio is the finding.

### Lane RR — Stage A's aggregate checks on the device (wt-uperf3-rr) — RUST/CUDA
OWNS: zkmatrix-rs/src/ring/zc_range.rs (ADDITIVE device-dispatch
hook lines ONLY, in the exact pattern eval_proof.rs uses:
`if gpu::enabled() { if let Some(..) = gpu::<fn>(..) { return .. } }`
with the CPU body falling through as the oracle — the cost centers
are `build_eq_full`, `compact_even`, `fold_ext`, `fold_base`,
`round_sums` (zc_range.rs ~:542-:734), all bottoming out in the
ec_kernel MAC families), NEW zkmatrix-rs/src/ring/gpu/zc_agg.rs +
NEW gpu/kernels_zc.cu (+ their `mod`/FUNCS lines in gpu/mod.rs and
the stub block for the non-GPU build), stage_a.rs (ADDITIVE, the
RANGE-mode path; SS owns the full-mode routing — see SS), the
`uperf-a` bin section (ADDITIVE subcommands/timers), NEW
results/uperf3_rr_*, "Agent RR status". READ-ONLY: ec_kernel.rs
(the CPU oracle — never edit), eval_proof.rs, fold.rs (the LogUp
packed prover is ALREADY GPU-hooked at fold.rs:704 — reuse), the
pass, two_tier.rs, manifest.rs.
GPU BUILD (from PROGRESS_UPERF3.md:58-62): `CUDA_ROOT=/home/victor/cuda-root
LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
CARGO_TARGET_DIR=<worktree>/zkmatrix-rs/target-gpu cargo build
--release --features gpu-cuda` (under flock /tmp/zk-build.lock);
binary `<worktree>/zkmatrix-rs/target-gpu/release/ring_matmul`; run
with `ZK_GPU=1`; the first GPU run of a fresh binary pays the NVRTC
compile of kernels_k9.cu (~8 min once) — plan for it. VRAM: the
12x512 pass already holds ~6.7 of the 8 GB (K9 slabs); size new
device buffers against `ZK_GPU_K9_BUDGET_MB` and measure at 12x64 /
12x128 first.
WHY: Stage A is in the pass behind a selector (lane GG): proof bytes
2.15x smaller, but prove +15% on CPU at 12x128 (the 2026-08-29
composition-ladder note) because its aggregate checks run on the
CPU while the rest of the pass rides the GPU. Its wall win is
expected on the device. The board's "1.2-1.5x" figure for this port
is UNSOURCED; this lane replaces it with a measurement.
RUNGS (prefix "U-PERF3 RR:"):
  0. SKELETON + BASELINE: `uperf-a pass 12 64 range` and `uperf-a
     pass 12 128 range` with ZK_GPU=1, oracle and Stage-A modes
     (`ZK_THREADS=8`), per-phase walls, EVAL-PROOF + statement
     digests, /usr/bin/time -v RSS. Confirm which Stage-A phases
     run on the CPU today.
  1. ATTRIBUTION: per-function timers inside the Stage-A path at
     12x128 (the zc_agg plane build / table / fold; the LogUp h+m
     prover; the per-instance claim transport) -> the ranked cost
     table, recorded here.
  2. Port the TOP cost center to the device, bit-identical: the
     EVAL-PROOF DIGEST and the statement digest unchanged at 12x64
     and 12x128; the Stage-A tamper legs (GG rung 4) still reject.
  3. The next cost centers, until Stage-A mode wall <= oracle mode
     wall at 12x128 with the GPU (both ZK_GPU=1, 8T).
  4. THE 12x512 A/B (orchestrator-run, flock, QUIET): oracle vs
     Stage-A vs Stage-A+GPU in range mode (full mode only if SS has
     landed V3), walls + bytes + RSS. Post the command; STOP.
  5. RECORD: the measured Stage-A-on-GPU factor at 12x128 and
     12x512, in the form lane TT consumes; it REPLACES the board's
     1.2-1.5x line.

### Lane SS — the committed-h encoding, rungs V1-V4 (wt-uperf3-ss) — RUST
SPEC: docs/zkmatrix-poc/U_PERF3_COMMITTED_H.md §3 VERBATIM (V1: one
h16 range fact as a 256-row lookup over the existing Hlo commitment
in the full-mode aggregate path, differential vs the E5/table form —
the load-bearing rung; V2: the helper/multiplicity commit bill
counted precisely at 12x512 and the 8B shapes; V3: all h + remainder
facts routed, `uperf-a pass 12 128 full` NO LONGER OOMs the 15 GiB
box and peaks near range mode's; V4: the 8B full-mode counted row on
OO's baseline — closes the owed recount).
OWNS: NEW zkmatrix-rs/src/ring/stage_a_full.rs (the full-mode lookup
routing lives here, + its one `pub mod` line), EXACTLY ONE dispatch
line in stage_a.rs (the full-mode switch to stage_a_full; record the
line here so RR's merge is mechanical), the `uperf-a` full-mode
subcommands (ADDITIVE), NEW results/uperf3_ss_*, "Agent SS status".
READ-ONLY: the rest of stage_a.rs (RR's), the S2 LogUp machinery
(reuse), the v3 statement (Hlo/Hhi/H/Rh are consumed, not changed),
everything else.
WHY: the F1 ruling adopted full mode; the memo says its memory price
was a layout artifact. V1-V4 verify that, and V3 is what lets the
8B pass run in full mode on the Mac (T17's freeze set).
RUNGS: V1 -> V2 -> V3 -> V4, one commit each (prefix "U-PERF3 SS:");
V3's 12x128 full-mode run is < 5 min at 8T if it no longer OOMs —
run it yourself with /usr/bin/time -v; if it OOMs, that is the
record (paste the peak).

### Lane TT — the throughput model (main session, docs only) — DESIGN
OWNS: NEW docs/zkmatrix-poc/U_PERF3_THROUGHPUT_MODEL.md; "Agent TT
status". No code, no builds, no runs.
GOAL: the proven-tokens-per-second model for a 30B-class model on
ONE GPU (H100-class allowed), written so a newcomer can follow it:
  1. the workload definitions — batch-1 decode (one token per
     proof), batch-T prefill (T tokens per proof), pipelined batches
     — and the MACs per token at 30B (weights + attention at a
     stated context), with the 8B row alongside;
  2. the cost anatomy per proof split PER-MODEL (preprocessable) vs
     PER-PROOF for (a) the built pass, (b) built + Stage A, (c)
     two-tier + weight preprocessing — every constant traced to a
     [MEASURED] row in PROGRESS_UPERF2/3.md or U_PERF3_* memos, or
     labelled [MODEL] with its assumption written next to it;
  3. the hardware factor 4070-Laptop -> H100 for THIS mix (integer
     NTT/GEMM, memory-bound passes), as a RANGE with the reasoning;
  4. the honest tokens/s table for (a)/(b)/(c) x {laptop, one
     desktop board, one H100} x {decode, T=512 prefill};
  5. an AUDIT of the board's 2026-08-30 line (~25-35 amortized;
     1.2-1.5x / 1.3x / 1.1-1.2x -> ~65): derive each factor or mark
     it UNSOURCED and retract it in the memo;
  6. the competitor row (53/77 tok/s) on the same yardstick
     [EXTERNAL];
  7. what a 50 tok/s design MUST have: the per-token budget in
     proven MAC/s and ms/token, and which lane (QQ/RR) measures
     which constant — so round 11 is cut from numbers.

## Agent QQ status (wt-uperf3-qq) — round 10

- 2026-09-02 SKELETON (rung 0): worktree wt-uperf3-qq on uperf3-qq
  at 10f73bf (round-10 open). OWNS: zkmatrix-rs/src/ring/two_tier.rs
  (ADDITIVE), NEW zkmatrix-rs/src/ring/gpu/two_tier_gpu.rs (+ its
  `pub mod` line and the stub twin), the `uperf-t` bin section
  (ADDITIVE: new [UPERF3-QQ] block after tt_build_real_act_instance;
  the dispatcher now lists `count | r1 | gpu | repeat`), NEW
  results/uperf3_qq_*, this section. READ-ONLY: everything else.
  RUNG PLAN (one commit each, prefix "U-PERF3 QQ:"):
  1. `uperf-t count [log2_rings]` — the C-R1 swap-order form
     COUNTED: scalar MACs / ring products per phase (rows / v-pass /
     fold / recursion), per-model vs per-proof, at 2^22, the 8B
     weight group (352,321,536 rings) and a 30B weight group (shape
     stated); [MODEL] walls on the RTX 4070 from the measured kernel
     classes. The table lands here.
  2. `uperf-t r1 [n_log2] [threads] [seed]` — the factored v-pass on
     the CPU behind a flag (two_tier.rs: new functions, the S4
     tt_qr_pass/tt_v_from_qr untouched); the FF rung-2 legs (DIFF
     1-3 + the reject legs) reused verbatim at 2^20; the v-pass wall
     at 2^22 1T vs the measured 20.01 s (bench22_1t_v2).
  3. `uperf-t gpu` — the device port of the factored linear pass
     (cudarc/NVRTC, integer MACs mod q31); bit-identical to rung 2;
     wall at 2^22/2^23 ZK_GPU=1 vs the built bg_prove_group GPU path.
  4. `uperf-t repeat <shape> [n]` — the per-model struct (built once,
     held warm) vs the per-proof work; per-proof wall over n proofs;
     then the REAL 12x512 WEIGHT group vs the built weight-group
     opening (ZK_GPU=1 both), claims bit-identical.
  5. RECORD + the verdict against the reopen bar (>= 5x per-proof
     weight-side opening at the 12x512 weight group, claims
     bit-identical); if not, the measured ratio is the finding.
  Every wall: [WSL-BOX] [1T|8T] [NOISY-SHARED] (lanes RR/SS active).
  Every number: [MEASURED] / [COUNTED] / [MODEL].
  Rung 0 commit: 83e163d.
- 2026-09-02 RUNG 1 — THE COUNT (`uperf-t count`, a printer, no
  proving; full output results/uperf3_qq_count.log). THE FORM
  COUNTED (memo §2 R1 / C-R1, written out over VALUE rings):
    v[e][i] = sum_{j=(r,cb)} P_e[j] (x) Fl_i[j],
    P_e[(r,cb)] = sum_d loY[r][d][e] * conjQ[cb][d]  (16 x nb x g mod-q rings per contrib),
    Fl_i[(r,cb)] = the recombined value ring (= the int8 weight for CLASS_W8S).
  i.e. the v-vectors are ONE GEMM of the built `ntt_gemm_modq_small`
  contract (a = 16 rows of nb*g mod-q rings, b = G columns of nb*g
  small rings) — the kernel that is already GPU-hooked and AVX2-
  tuned. The memo's Y^d-basis shift (loY[r][d][e] = tw(d,e)
  lo[r][(e-d) mod 16]) lives entirely in the P precompute (256 D nb g
  scalar MACs, negligible) and never touches the witness pass.
  THREE COUNTED FACTS the memo did not have:
  (1) R1 has the SAME D-domain MAC count as the S4 `tt_qr_pass`
      (16 Nv D) — the S4 cost was the TRANSFORMS: one forward AND one
      inverse 128-pt NTT per (row, cb, d) product = 8,847,360 pairs at
      2^22 (2.26 us each 1T [MEASURED-derived from the 20.01 s]); the
      GEMM pays ONE forward transform per value ring (569,344 at 2^22)
      + 16 G inverses. Counted v-pass at 2^22 1T: 1.94 s [MODEL C8]
      vs 20.01 s => ~10x on the v-pass, above the memo's 2-5x ceiling
      (the memo priced the swap-order S-pass as scalar MACs per row-nb
      unit and missed that it is the GEMM the engine already has).
  (2) The built claim layer's kernel-pass ROWS over the whole witness
      are REDUNDANT in the two-tier form: b_rows[c] = sum_m sum_i
      sum_e hiY[i][e][c] v[e][i] (256 D G scalar MACs per contrib) —
      v does not depend on alphas, so the transcript order (b_rows,
      alpha0, u, U, v, c, w) is unchanged. The differential leg
      becomes STRONGER (b_rows recovered from v vs the oracle).
  (3) The per-proof floor of the design of record is the FOLD over
      DIGIT rings (8x the value rings at l0 8): 25.4 s at 8B on the
      combine class C4 (72 ns/digit ring [MEASURED 12x512]) vs the v
      GEMM's 1.2 + 1.0 s. The recursion's input with the per-tensor
      grids as built is n_w + n2 + n_v = 10.3M rings at 8B (w digits
      5.2M — 96 per-tensor folded rows x l_z 4 at e' 4; u 2.1M; v
      3.0M), NOT the FF planner's global-split 1.65M: the per-tensor
      grid costs ~6x in n_rec.
  THE TABLE [COUNTED sizes; walls MODEL on the RTX 4070 Laptop from
  the measured classes C1 GEMM 74 G D-MAC/s, C2 transform 22.9
  ns/ring, C4 fold 72 ns/digit ring, C5 the built prove-group 0.623
  us/level-0 ring (12x512: 7.1 s / 11,393,420 rings) used both as
  the recursion class and as the built-opening class; one contrib
  per weight tensor; ratio = built / two-tier per-proof, (proxy =
  the FF bench's u-digit recursion | full = w+u+v recursed)]:
  | shape | n0 digit rings | Nv value rings | v GEMM D-MACs | n_rec (w+u+v) | per-MODEL s | per-proof v (GEMM+xf) s | fold s | recursion s | per-proof TOTAL s | built s | ratio proxy | ratio full |
  |---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
  | 2^22 FF synthetic (n0 2,972,672) | 2.97e6 | 422,912 | 1.17e9 | 495,876 | 0.12 | 0.029 | 0.21 | 0.31 | 0.55 | 1.85 | 5.3x | 3.4x |
  | 12x512 weight group (the bar's shape) | 3.54e6 | 442,368 | 0.91e9 | 583,680 | 0.15 | 0.022 | 0.25 | 0.36 | 0.64 | 2.21 | 5.5x | 3.4x |
  | 8B weight group (352,321,536) | 352.3e6 | 44.0e6 | 90.2e9 | 10.3e6 | 14.8 | 2.23 | 25.4 | 6.4 | 34.0 | 219.6 | 7.6x | 6.5x |
  | 30B FFN weight group (64 x 5120 x 25600 = 2.52e10 weights, ASSUMED shape; x1.23 for attention weights) | 1.57e9 | 196.6e6 | 402.7e9 | 42.7e6 | 65.9 | 9.9 | 113.2 | 26.6 | 149.8 | 980.2 | 7.6x | 6.5x |
  PER-MODEL (alpha-independent, once per model): tier-1 commit
  kappa*n0 ring-MACs (8B: 3.88e9 = 4.96e11 D-MACs, 6.7 s GEMM + 8.1 s
  transforms [MODEL]), tier-2 U kappa*n2, CRS kappa*(width_sum+n2)
  rings, the int8 value layout (8B: 5.64 GB; 30B: 25.2 GB — VRAM
  residency is a board question; streamed at C3 11.7 GB/s it is
  0.48 s / 2.15 s per pass).
  VARIANT B [COUNTED, a DESIGN CHANGE outside this lane's authority —
  recorded as the lever the count exposes]: tier-1 commitment over
  the int8 VALUE rings (e = 8) instead of the digit rings. Row-group
  exact-digit gate headroom +3.45 / +1.74 / +1.42 bits at 12x512 /
  8B / 30B (green); commit and fold 8x cheaper (8B fold 3.2 s); n_rec
  full 6.0M at 8B; per-proof 6.7 s (proxy) | 9.1 s (full) at 8B =>
  ratio 32.8x | 24.0x [MODEL]; 12x512: 12.2x | 5.8x.
  READING FOR THE RULING: on the GPU cost model the design of record
  is a ~5-8x per-proof win over the built opening on the weight side
  [MODEL], not the memo's 1.6-2.5x (which priced CPU ring products
  and 1T); at the 12x512 bar shape the count sits AT the 5x bar
  (5.5x proxy / 3.4x full) because the fixed-class fold + recursion
  dominate a 3.5M-ring group; the win grows with the shape (8B 7.6x)
  and Variant B is the ~25-30x lever. What clears 50 tok/s is lane
  TT's arithmetic (per-proof weight side 34 s at 8B on THIS laptop
  part [MODEL] is the row to convert). Every wall above is a model
  from four measured classes; rungs 2-4 measure.
  Floors at commit: build green; diff-battery 15.63 s; freeze-check
  102 ok + passed; uperf-s 3752cba4.., agg 46234986.., uperf-x
  be89d5da.. unchanged. Rung 1 commit: 1fa6611.
- 2026-09-02 RUNG 2 — R1 ON THE CPU: GREEN, bit-identical; v-pass
  6.1x [MEASURED]. BUILT: ring::two_tier (ADDITIVE; the S4 functions
  untouched): `R1Form {Value, Digit}` + `tt_r1_form_for` (value form
  whenever the recombined |value| fits >= 1 exact-integer window of
  the GEMM — every CLASS_W8S weight tensor and every tensor of the FF
  synthetic; the digit form is the same GEMM over the flat i8 digit
  rings with the radix in P, for act classes beyond l0 ~11),
  `tt_inner_value_functionals` (P_e over (r, cb)), `tt_fl_row_groups`
  (the recombined value rings per row-group batch), `tt_v_pass_r1`
  (batches of <= 64K value rings through `ntt_gemm_modq_small_gen`,
  a = 16 x (nb g) mod-q rings, b = G x (nb g) small rings),
  `tt_rows_from_v` (b_rows recovered from v). Bin: `TtVMode {S4, R1}`
  threaded through tt_prove (the two FF call sites pass S4 — the
  spike path is unchanged: `uperf-t diff 20 1 161` re-run, same
  legs, same verdicts); in R1 mode the v-vectors are computed FIRST
  (they never see the transcript), b_rows are recovered from them,
  and the wire/absorption order is identical. `uperf-t r1 diff|bench`.
  DIFFERENTIAL (`uperf-t r1 diff 20 1 161`, results/uperf3_qq_r1_diff20_1t.log)
  [WSL-BOX 1T NOISY-SHARED]: all six tensors take the Value form
  (windows 24,582-6.7M terms); DIFF 1 b_row images BYTE-IDENTICAL vs
  the built GroupEvalProof.b_rows — in R1 mode the images are
  RECOVERED FROM v, so this leg now pins the count's fact (2); DIFF 2
  H_m == alphas . rows_m POLY-EXACT 7/7; DIFF 3 h_cur identical; the
  6 reject legs fire at the same gates (tt-fold-binding x2,
  tt-u-binding, tt-ct-row-gate, tt-consistency, tt-claim). two-tier
  prove 8.58 s (R1) vs 16.18 s (S4, same box, concurrently) at
  2^19.6; oracle 21.6 s; peak RSS 2594 MiB.
  THE 2^22 MEASUREMENT (the FF bench harness in R1 mode;
  results/uperf3_qq_r1_bench22_{1t,8t}.log; flock, /usr/bin/time -v):
  | [WSL-BOX NOISY-SHARED] | S4 bench22_1t_v2 | R1 1T | R1 8T |
  |---|---:|---:|---:|
  | rows pass (S4: kernel pass; R1: rows-from-v) | 1.45 | **0.34** | 0.33 |
  | v-passes | **20.01** | **3.26** (6.1x) | 2.29 |
  | fold | 2.25 | 2.59 | 0.73 |
  | tier1+tier2 commit (per-model class) | 14.59 | 16.41 | 4.91 |
  | proxy recursion precommit + prove | 0.44 + 1.73 | 0.67 + 2.21 | 0.22 + 0.71 |
  | tt core (rows+v+fold+rec) | 25.44 | **8.41** | 4.06 |
  | bg_precommit / bg_prove_group | 7.10 / 27.91 | 7.23 / 28.74 | 2.90 / 8.26 |
  | PROVE-GROUP-EQUIVALENT core ratio | 1.10x | **3.42x** | 2.03x |
  | with-commit ratio | ~0.6x | 1.41x | 1.21x |
  | tt_verify (unchanged by R1) | 3.93 | 4.80 | 3.25 |
  | peak RSS | 4913 MiB | 4963 MiB | 4993 MiB |
  READING: R1 on the CPU takes the S4 core from 1.10x to 3.42x at
  1T — above the memo's 1.6-2.5x composed ceiling (the memo priced
  the swap-order S-pass as scalar row-nb MACs and missed the GEMM
  identity), below the 5x bar: the remaining core is fold 2.59 +
  recursion 2.21 = 57%, exactly the two terms the count names as
  the design-of-record floor. The R1 v-pass measured 3.26 s vs the
  count's 1.94 s [MODEL C8] — the CPU GEMM body plus the i64 Fl
  materialization and the P precompute on a noisy box; the GPU
  measurement (rung 3) is the one the count is about. Bytes and the
  verifier are untouched (criterion 3 was never R1's). ACCEPT per
  the rung's own criterion (bit-identical; ratio recorded).
  Floors at commit: build green; diff-battery green; freeze-check
  102 ok + passed; uperf-s 3752cba4.., agg 46234986.., uperf-x
  be89d5da.. unchanged. Rung 2 commit: 1a34ac6.
- 2026-09-02 RUNG 3 — THE DEVICE PORT: bit-identical; measured at
  PARITY with the built GPU opening at 2^22-2^23 and at the real
  12x512 weight group (0.85x / 0.93x / 1.05x core). NO NEW KERNEL:
  the R1 pass IS the `ntt_gemm_modq_small` contract, whose device
  port (k_gemm_split, cuda.rs :638) is the existing hook — the port
  is the dispatch. Built (two_tier.rs, ADDITIVE): `tt_v_pass_r1_dev`
  (the value-form GEMM with the Fl batch built on a pool at the
  house thread count and packed flat-i8 whenever every value fits —
  the hook's `as_i8` fast path, i.e. every real int8 weight tensor),
  `TtStridedCol` (a strided-column `SmallRings` view of the flat i8
  witness; the GEMM never calls `sub`) + `tt_fold_r1` (the fold as
  ONE GEMM per tensor: a = the G challenges as mod-q rings, b = the
  width strided columns, len = G; centered back to the exact i64 fold
  — the combine class is tuned for r <= 64 x many outputs, the
  two-tier fold is G ~ 10^3 x width outputs, the transpose),
  `tt_inner_value_functionals` / `tt_rows_from_v` pooled, the
  attribution counters `tt_r1_prof_take`. Bin: R1 mode uses both;
  `tt_wire_digest` (SHA-256 over b_rows|u|U|v|w) printed by diff and
  bench with the GPU label — the cross-run identity check.
  BYTE IDENTITY: WIRE DIGEST cae0b3123c0335b4.. at 2^20 IDENTICAL
  across CPU/S4, CPU/R1, GPU/R1 (three binaries/modes; the FF legs
  green on the device: results/uperf3_qq_r1_diff20_gpu.log); the
  real weight group: b_row images byte-identical two-tier vs the
  built opening at the real shape (the FF bench's leg).
  THE MEASUREMENT [WSL-BOX 8T NOISY-SHARED, ZK_GPU=1, RTX 4070
  Laptop; flock, /usr/bin/time -v; results/uperf3_qq_r1_bench{22,23}_8t_gpu.log,
  results/uperf3_qq_r1_bench_realw_8t_gpu.log]:
  | GPU 8T | 2^22 synth (n0 2.97M) | 2^23 synth (5.86M) | REAL 12x512 WEIGHT (3.54M, 36 tensors) |
  |---|---:|---:|---:|
  | rows-from-v | 0.09 | 0.44* | 0.11 |
  | v-pass (P + Fl + GEMM) | 1.35 (0.06 + 0.41 + 0.85) | 1.90 (0.31 + 0.67 + 0.87)* | **0.67** (0.16 + 0.29 + **0.19**) |
  | fold wall (fold-as-GEMM inside) | 0.71 (0.31) | 0.96 (0.59)* | 0.94 (0.49) |
  | proxy recursion precommit + prove (u digits, 173-207K rings) | 0.19 + 0.62 | 0.22 + 0.55 | 0.24 + 0.58 |
  | tt core (rows+v+fold+rec) | 2.77 | 3.85 | **2.30** |
  | tier1+tier2 commit (per-model class) | 2.24 | 2.31 | 2.90 |
  | built bg_precommit / bg_prove_group | 0.72 / **2.35** | 1.32 / 3.59 | 0.81 / **2.42** |
  | RATIO core (proxy recursion) | 0.85x | 0.93x | **1.05x** |
  | tt_verify (unchanged by R1) | 3.05 | 3.51 | 7.27 (consistency 5.13 — 36 tensors x 16 x width) |
  | bytes spike-clear vs built | 45.3 MB vs 179 KB | — | 65.0 MB vs 180 KB |
  | peak RSS | 5242 MiB | 6749 MiB | 6369 MiB |
  (* the 2^23 row is from the run before the P/rows pooling landed;
  the pooled 2^22 row is the final form.)
  ATTRIBUTION (what the device actually does at these shapes):
  (1) the GEMM hook at the two-tier shape (len = g*nb = 64-512 value
  rings, na = 16, nb up to 1024) runs ~8x below C1: `ZK_GPU_VERBOSE`
  shows "gemm na 16 nb 1024 len 64 (b_fmt 3 = i64): pack 5.1 ms,
  wait 15.0 ms, h2d 68 MB, d2h 10 ms" — a short K loop, an i64
  operand in the synthetic (|Fl| <= 255), transfer-bound; on the real
  int8 weights (i8 pack) the whole v GEMM is 0.19 s at 12x512. At the
  8B shape len = 1792 (the level-h class) — the count's C1 applies
  there, not here. (2) the fold-as-GEMM: 0.31-0.49 s vs the combine
  class's 0.99 s at 2^22 (measured in the first GPU run); the rest of
  the fold wall is host-side (the honest-bound check + poly_from_small
  + absorb over width rings). (3) THE FLOOR: the proxy recursion on a
  173-207K-ring group costs 0.8 s = ~4 us/ring — the built machinery's
  fixed-cost regime (7 levels, CRS, transcript), 6x the C5 class the
  count used (0.62 us/ring, measured at 11.4M rings). The count's
  12x512 row assumed C5 for the recursion; measured, the recursion
  alone is 1/3 of the built opening's whole wall.
  READING: at 2^22-2^23 and at the real 12x512 weight group the
  built opening on this GPU costs 2.3-3.6 s, and the two-tier
  per-proof core (R1, device GEMMs, proxy recursion) is AT PARITY
  (0.85-1.05x) — the S4 spike's 0.65x at 7T CPU becomes ~1x on the
  device, the v-pass having gone from 79% of the core to ~30%. The
  5x bar at this shape would need the recursion + fold + v together
  under ~0.5 s against a 2.4 s built wall; the recursion alone is
  0.8 s. This is the shape-class finding the count predicted in its
  own reading ("the fixed-class fold + recursion dominate a 3.5M-ring
  group") but at a worse constant than counted. The two-tier form's
  advantage is asymptotic — the built path's x41-43 opening terms vs
  linear passes — and lives at the 8B shape [MODEL 6.5-7.6x, count],
  not at 12x512 [MEASURED 1.05x]. Rung 4 measures the per-model /
  per-proof split at this shape; the reopen bar as written (12x512
  weight group, >= 5x) is NOT met [MEASURED].
  Floors at commit: build green (CPU + GPU); diff-battery green;
  freeze-check 102 ok + passed; uperf-s 3752cba4.., agg 46234986..,
  uperf-x be89d5da.. unchanged. Rung 3 commit: c030ea6.
- 2026-09-02 RUNG 4 — THE PREPROCESSING BOUNDARY: built and
  measured; the weight-side per-proof opening at the real 12x512
  weight group is 1.00x the built GPU opening [MEASURED]. BUILT
  (bin, ADDITIVE): `TtPerModel` = everything alpha/point-independent
  — the tier-1 inner commitments u, the tier-2 U, the flat-i8 value
  layout the v GEMM reads (the CRS matrices ride eval_proof's Arc
  cache, warm after the build); `tt_build_per_model`; `tt_prove`
  takes `Option<&TtPerModel>` (the commitments are absorbed from the
  cache — the transcript and wire are unchanged: digest identical);
  two_tier.rs `tt_fl_layout_i8` + `tt_v_pass_r1_dev(.., fl_cache)`.
  `uperf-t repeat <n_log2|real|real-w> [n] [threads] [seed]`: the
  per-model build once, n two-tier proofs with it warm (per-proof =
  tt_prove + the proxy recursion prove; the recursion's precommit is
  per-model class and reported separately), then n built openings
  on an identically rebuilt group (the E-O2-BB one-opening gate) with
  the witness cloned; b_rows two-tier == built asserted; the wire
  digest asserted identical across the n proofs.
  THE MEASUREMENT [WSL-BOX 8T NOISY-SHARED, ZK_GPU=1, RTX 4070
  Laptop; flock, /usr/bin/time -v; results/uperf3_qq_repeat_realw_8t_gpu.log,
  results/uperf3_qq_repeat22_8t_gpu.log]:
  | GPU 8T, n = 3 | REAL 12x512 WEIGHT group (3,538,944 rings, 36 tensors, i8 layout 36/36) | 2^22 synth |
  |---|---:|---:|
  | PER-MODEL build (u + U + i8 layout) | **2.34 s**, 91.2 MB held | 1.93 s, 32.9 MB |
  | per-proof tt_prove (min) | 1.74 = rows-from-v 0.09 + v 0.27 (P 0.13 + GEMM **0.12**) + fold 0.80 (GEMM 0.42) + commits-from-cache 0.03 + absorbs | 1.80 |
  | per-proof recursion prove (proxy, u digits 202,752 rings) | 0.34 (its precommit 0.10, per-model class) | 0.28 |
  | **PER-PROOF two-tier, per-model warm (min / median)** | **2.08 / 2.15 s** | 2.09 / 2.24 |
  | built bg_prove_group (min / median) | **2.09 / 2.11 s** | 1.79 / 1.80 |
  | built bg_precommit (min; per-model class, paid per proof as built) | 0.68 | 0.57 |
  | RATIO built / two-tier per-proof | **1.00x** (prove-group) / 1.33x (+ precommit) | 0.86x / 1.13x |
  | claims | b_row images BYTE-IDENTICAL (two-tier recovered from v vs built); wire digest 12a8a3f6.. identical x3 | cba4356c.. x3 |
  | peak RSS | 5872 MiB | 4763 MiB |
  WHERE THE PER-PROOF 2.08 s GOES at the weight group: the fold 0.80
  (0.42 device GEMM over strided columns at len = G = 64-96 — a short
  K again — + 0.38 host: honest-bound check, poly_from_small and the
  transcript absorb of 43,008 folded rings), the recursion prove
  0.34, the v GEMM 0.12 (+ P 0.13 on the CPU pool), rows-from-v 0.09,
  the transcript/absorbs the rest. The per-model part removed from
  the per-proof clock: 2.34 s of tier commits + layout — the same
  class as the built path's own precommit (0.68 s), which the built
  pass ALSO treats as per-model discipline for the weights.
  VERDICT AT THE BAR: per-proof weight-side opening at the 12x512
  weight group = 1.00x the built GPU path (bar: >= 5x) — NOT MET
  [MEASURED]. Claims bit-identical throughout.
  Floors at commit: build green (CPU + GPU); diff-battery green;
  freeze-check 102 ok + passed; uperf-s 3752cba4.., agg 46234986..,
  uperf-x be89d5da.. unchanged. Rung 4 commit: 1dfcf72.
- 2026-09-02 RUNG 5 — THE RECORD AND THE VERDICT. LANE COMPLETE.
  THE VERDICT against the reopen bar (per-proof weight-side opening
  at the 12x512 weight group >= 5x faster than the built GPU path,
  claims bit-identical): **NOT MET — measured 1.00x** (2.08 s vs
  2.09 s, [WSL-BOX 8T GPU NOISY-SHARED], claims byte-identical, the
  per-model part held warm). Per the brief, the ratio is the finding
  and the lane stops here. What the lane established on the way:
  (a) the memo's C-R1 count was wrong in the memo's own favor-
  against: the swap-order v-pass is ONE existing GEMM (10x on the
  v-pass at 1T CPU [MODEL], 6.1x [MEASURED]), taking the S4 core
  from 1.10x to 3.42x at 1T CPU [MEASURED] — above the memo's
  1.6-2.5x closing ceiling; (b) on the device the whole two-tier
  per-proof side reaches PARITY with the built opening at 2^22-2^23
  and at the real weight group, and no better, because at ~3.5M
  rings the built GPU opening costs ~2 s and the two-tier's floors
  (a ~200K-ring recursion, a fold over 8x the value rings, the
  per-tensor host-side fold tail) add up to the same; (c) the
  per-model / per-proof boundary EXISTS and is bit-identical (2.34 s
  per model at 12x512, 91 MB held; the transcript unchanged).
  THE MEASURED CONSTANTS (12x512 weight group, GPU 8T NOISY; every
  8B/30B row below is [MODEL] = these constants x the counted
  sizes, linear unless said):
  | constant | value | source |
  |---|---:|---|
  | K1 per-model tier-1 + U + i8 layout | 0.66 us / digit ring | 2.34 s / 3,538,944 |
  | K2 v GEMM, i8 operand, len = g*nb 128-192 (short K) | 7.5 G D-MAC/s | 0.12 s / 9.06e8; at len ~1800 (8B) the C1 class 74 G/s applies [MODEL] |
  | K3 P precompute (CPU pool) | 1.35 G scalar MAC/s | 0.13 s / 1.76e8 |
  | K4 fold-as-GEMM, len = G 64-96 | 119 ns / digit ring | 0.42 s / 3,538,944 (combine class: 72 ns; Variant B: over value rings) |
  | K5 fold host tail (bound check + poly_from_small + absorb) | 8.8 us / folded ring | 0.38 s / 43,008 (scales with width_sum = the per-tensor grid tax) |
  | K6 recursion prove, small regime | 1.68 us / ring | 0.34 s / 202,752 (C5 0.62 us/ring at 11.4M) |
  | K7 rows-from-v | ~1.1 G scalar MAC/s | 0.09 s / 1.0e8 |
  | K8 the built bg_prove_group on the device | 0.59 us / digit ring | 2.09 s / 3,538,944 (C5 0.62 at 12x512 both groups; ROUTES x41-43 for x44 rings — linear class) |
  THE PROJECTION TABLE FOR LANE TT (RTX 4070 Laptop GPU, 8T, weights
  resident; [MODEL] from K1-K8 x the rung-1 counted sizes; ranges =
  short-K rate .. C1 rate for the v GEMM, small-regime .. C5 for the
  recursion):
  | shape | per-MODEL (once) | per-proof v GEMM + P + rows | per-proof fold (GEMM + host tail) | per-proof recursion (proxy u digits) | **per-proof TOTAL** | built opening | ratio |
  |---|---:|---:|---:|---:|---:|---:|---:|
  | 12x512 W [MEASURED] | 2.34 s | 0.27 + 0.09 | 0.42 + 0.38 | 0.34 | **2.08 s** | 2.09 s | **1.00x** |
  | 8B W, design of record | 233 s | 1.2-12 + 4.4 + 0.7 | 41.9 + 12.7 | 1.3-3.5 | **62-75 s** | ~210 s | **2.8-3.4x** |
  | 8B W, Variant B (value-ring tier 1; a design change) | ~30 s | 1.2-12 + 4.4 + 0.7 | 5.2 + 1.6 | 1.3-3.5 | **14-27 s** | ~210 s | **7.8-15x** |
  | 30B W (FFN-only 64x5120x25600), design of record | 1,040 s | 5.4-54 + 20 + 3 | 187 + 57 | 6-16 | **280-340 s** | ~940 s | ~2.8-3.4x |
  | 30B W, Variant B | ~130 s | 5.4-54 + 20 + 3 | 23 + 7 | 6-16 | **65-125 s** | ~940 s | ~7.5-14x |
  (the "full" recursion — w + u + v digits recursed, 10.3M rings at
  8B — adds 6-17 s to the 8B rows; the u/v/w clear-wire form is what
  was measured. Per-proof act-side work is NOT in this table: the
  weight side only, as the brief asks.)
  READING FOR THE RULING: on this GPU the two-tier opening with
  weight preprocessing gives ~3x on the weight-side per-proof clock
  at 8B in the design of record [MODEL], ~8-15x with Variant B, and
  1.00x at 12x512 [MEASURED]. The count's 6.5-7.6x (rung 1) assumed
  the C-class rates for the fold and the recursion; the measured
  constants at the two-tier's shapes (short-K GEMMs, a small-regime
  recursion, the per-tensor fold tail) are 2-6x worse. The lever the
  measurements point at is NOT the v-pass any more (0.27 s of 2.08):
  it is the FOLD over digit rings (K4 + K5 = 58% of the per-proof
  clock at 12x512, 73% at 8B) — Variant B removes 8x of it by
  committing the int8 value rings (row-group gate +1.74 bits at 8B
  [COUNTED, rung 1]) and needs a design ruling (the committed object
  changes; the exact-digit gate holds), plus a global (not
  per-tensor) grid to kill the K5 tail (6x on n_w at 8B [COUNTED]).
  Whether ~3x (or ~10x) on the weight side of one proof reaches 50
  tok/s is lane TT's conversion; this lane's numbers are the rows
  above.
  NOT COUNTED / NOT MEASURED (honesty): the act-side opening under
  two-tier (act tensors need the digit form or i64 operands: l0 up
  to 15); the verifier (criterion 3: tt_verify 7.27 s at the weight
  group, consistency 5.13 s — 36 tensors x 16 x width; R2's
  recursed serving was never built); the R2 bytes (65 MB clear vs
  180 KB built); the composed pass (this is the group opening
  alone); a quiet box (every wall here is NOISY-SHARED, 8T); a
  desktop board or an H100 (nothing here is measured on one — the
  weights resident assumption is a board question: 5.6 GB at 8B,
  25 GB at 30B); a tensor-core int8 fold kernel (not built; would
  be the other way to remove K4). The S4 code paths, the built
  pass, and every freeze row are byte-identical (floors green at
  every commit; `uperf-t diff 20 1 161` re-run in S4 mode gives the
  FF verdicts and the same wire digest as R1).
  ORCHESTRATOR-RUN: none posted — every run of this lane fit the
  foreground limit (longest: bench 22 1T, 1:49).
  Commits: 83e163d (rung 0), 1fa6611 (rung 1), 1a34ac6 (rung 2),
  c030ea6 (rung 3), 1dfcf72 (rung 4), this entry (rung 5).

## Agent RR status (wt-uperf3-rr) — round 10

STATE: RUNGS 0-3 + 5 DONE (2026-09-02; R0a efde2bf, R1 517ae49, R2
f948888, R3 + R5 = the commits carrying this block); rung 4 (the 12x512
A/B) POSTED as orchestrator-run below. THE RESULT: the aggregate prover
5.0-5.9 -> 0.58 s at 12x128 (device, bit-identical); Stage-A prove
17.6-19.4 -> 13.4 s with GG's transport (1.31-1.44x, the board's guess
measured) -> 7.5 s == the oracle's with the BATCHED claim transport
(opt-in, a Stage-A transcript variant, ruling item); verify at parity;
total 1.14x (the planes commit); process peak 7.5 -> 3.1 GB. Lane: Stage
A's aggregate checks on the device — the RANGE-mode path (zc_agg + LogUp h+m), the
factor MEASURED at 12x64 / 12x128 (12x512 orchestrator-run). OWNS per
the brief: zc_range.rs (ADDITIVE hook lines only, eval_proof.rs
pattern, CPU body = oracle), NEW gpu/zc_agg.rs + gpu/kernels_zc.cu (+
their mod/FUNCS lines in gpu/mod.rs and the stub block), stage_a.rs
(ADDITIVE, range-mode path), the `uperf-a` bin section (ADDITIVE
timers/subcommands), NEW results/uperf3_rr_*, this section.

FLOORS at every Rust-touching commit: CPU release build (the stub
block) + GPU release build; `uperf-pc diff-battery` green;
freeze-check 102 ok rows + passed (M125_EXPORT_DIR set); uperf-s
battery 3752cba4..; agg-battery 46234986..; uperf-x be89d5da..; the
Stage-A identity (EVAL-PROOF DIGEST + statement digest of `uperf-a
pass 12 64 range` identical with/without ZK_GPU=1); GG's tamper legs
(`uperf-a pass-battery 3 16`) still reject.

PLAN (one commit per green rung, prefix "U-PERF3 RR:"):
- [x] R0a SKELETON: this section; worktree cut at 10f73bf; GPU build
  (target-gpu, --features gpu-cuda) 2m24s green; CPU build 2m18s
  green — the round-9 code, no Rust touched.
- [x] R0b BASELINE: `uperf-a pass 12 64 range` / `12 128 range`,
  ZK_GPU=1 ZK_THREADS=8, oracle + Stage-A in one process, per-phase
  walls, digests, /usr/bin/time -v RSS; which Stage-A phases run on
  the CPU today.
- [x] R1 ATTRIBUTION: per-function timers inside the Stage-A path at
  12x128 -> the ranked cost table.
- [x] R2 the TOP cost center on the device, bit-identical (digests
  unchanged at 12x64 / 12x128; tamper legs reject).
- [x] R3 the next cost centers until Stage-A wall <= oracle wall at
  12x128 (both ZK_GPU=1, 8T) — MET on prove + verify under the batched
  transport variant; total 1.14x (the planes commit).
- [ ] R4 the 12x512 A/B — ORCHESTRATOR-RUN (command posted below).
- [x] R5 RECORD the measured Stage-A-on-GPU factor (replaces the
  board's unsourced 1.2-1.5x): results/uperf3_rr_stage_a_gpu.md.

R0b BASELINE EVIDENCE (2026-09-02, [WSL-BOX] [8T] [NOISY-SHARED]; the
round-9 code's GPU binary, oracle + Stage-A in ONE process (`uperf-a
pass <l> <t> range`, M125_EXPORT_DIR set), /usr/bin/time -v, flock) [MEASURED]:

  | shape | device | leg | commit / prove / verify (s) | bytes | process peak RSS |
  |---|---|---|---|---|---|
  | 12x64 | ZK_GPU=1 | oracle | 1.7 / 6.9 / 1.8 | 1,308,775 | 4,811 MiB (both legs) |
  | 12x64 | ZK_GPU=1 | Stage-A | 3.2 / 11.6 / 2.6 | 622,011 | " |
  | 12x64 | CPU (ZK_GPU unset, same binary) | oracle | 4.7 / 21.2 / 2.2 | 1,308,775 | 4,259 MiB |
  | 12x64 | CPU | Stage-A | 6.1 / 22.6 / 3.3 | 622,011 | " |
  | 12x128 | ZK_GPU=1 | oracle | 1.8 / 9.7 / 2.0 | 1,372,775 | 7,344 MiB (both legs) |
  | 12x128 | ZK_GPU=1 | Stage-A | 3.6 / 18.3 / 4.2 | 637,691 | " |

  READING: with the device live, Stage-A prove is 1.68x (12x64) /
  1.89x (12x128) SLOWER than the oracle — the oracle's descents ride
  k9 while the aggregate runs on the CPU; CPU-only the two legs are
  near par (22.6 vs 21.2 at 12x64), consistent with the 08-29 note's
  +15% (that note's absolute walls, 67.8/77.8 s at 12x64, were taken
  at 22T on a loaded box; these are 8T). WHICH STAGE-A PHASES RUN ON
  THE CPU TODAY: the planes tensors (gg_build_groups/gg_witness_act),
  the per-class zc tables (gg_build_class_tabs), zc_agg_prove
  ENTIRELY (eq / round sums / folds — the ec_kernel MAC families), and
  the claims transport (gg_zc_claims); the kept silu descents ride
  k9; the act/weight openings ride the level-h/GEMM device paths.

R1 ATTRIBUTION EVIDENCE (2026-09-02, [WSL-BOX] [8T] [NOISY-SHARED],
ZK_GPU=1; per-function timers added to the `uperf-a pass` driver, the
`[UPERF3-RR] ATTRIBUTION` block) [MEASURED]:
- 12x128 Stage-A pass: commit 3.73 = groups+planes 1.07 | witness 0.98
  | precommit weight 0.85 | precommit act 0.77 | statement 0.07.
- prove 19.20 = claim-layer 0.95 | STAGE-A PHASE 6.74 (silu descents
  0.58 + zc tabs-build 0.28 + ZC PROVE 5.45 [eq 0.29, rounds 2.76,
  folds 1.65; 240 rounds; 20.90 G MACs -> 3.8 GMAC/s on 8T] + zc
  claims-transport 0.40) | publics+nus 0.02 | opening weight 2.70 |
  OPENING ACT 8.80.
- verify 4.75 = stage-a 0.19 | group verifies 4.54.
- the ranked zc classes: nrw-88 (m 24 x 2^18, w 8, n_tot 23) 1.89 s
  (7.65 G MACs); rem-w8 c0 (15 x 2^18) 0.94; rem-w9 c0 0.59; nrw-z
  0.48; rem-w7 c0 0.45; rem-w6 c0 0.43; the rest < 0.2 s each.
- THE RANKED COST TABLE (Stage-A-specific, prove side): (1) the act
  OPENING's excess — 8.80 s vs the weight group's 2.70 on a group
  1.14x smaller in rings (act n_0 3.09M vs weight 3.54M) — the Stage-A
  act group carries 997 claims of which ~700 are planes contribs
  (gg_zc_claims: m x w rank-1 claims per class, each a row kernel of
  length m*w*rows with ONE nonzero block); [read-only eval_proof.rs,
  already device-hooked; the prof split is printed from the next
  commit on]; (2) zc_agg_prove 5.45 s (CPU; THIS lane's port target);
  (3) claims transport 0.40 + tabs-build 0.28 (CPU scalar loops);
  (4) the planes commit (+1.8 s commit vs oracle).
- IDENTITY: the new `[UPERF3-RR] STAGE-A DIGEST` line (statement
  digest | prover transcript state | verifier transcript state) is
  IDENTICAL with and without ZK_GPU=1 at 12x64: statement
  441ca5db221d4dd2.., transcript 44528c6aeee0a771.. (prover ==
  verifier); at 12x128 (GPU): statement dc3100e73f810cf7..,
  transcript e5085602a2fbc93b...

R2 THE DEVICE PORT — EVIDENCE (2026-09-02, [WSL-BOX] [8T] [NOISY-SHARED]) [MEASURED]:
- WHAT: NEW gpu/kernels_zc.cu + gpu/zc_agg.rs — the aggregate zero-check's
  round loop on the device: E_4 arithmetic op-for-op with the CPU's
  reduction chain (products folded by 2^32, fold31 x2, one conditional
  subtraction, Z^c = s), `k_zc_round_base` / `k_zc_round_ext` (grid.y =
  node; per-thread mod-q accumulators for the w+1 constraints x c
  coordinates; warp-shuffle + shared-memory reduction in a fixed order;
  ONE u64 atomic per (node, constraint, coordinate); the host reduces
  mod q — the same field elements the CPU's split planes finalize to),
  `k_zc_fold_base` / `k_zc_fold_ext` (out of place, a rotating scratch:
  w+2 buffers for w+1 tables; the base table rides in the E buffer, n
  u32 fitting n/2 E elements), `k_zc_eq_build` (the pair eq from
  build_eq_full's two half tables, built on the host) + `k_zc_eq_compact`.
  The hook (zc_range::zc_agg_prove_masked, the ixf/fold.rs pattern):
  open before the eq build; per round the device round / fold; handover
  (tables + eq materialized as ETab) at n <= 2^a (the claim-stacking
  point) or n/2 < min_pairs; a device error -> the host rebuilds from the
  stacked instance + the challenges drawn (`zc_agg_host_rebuild`) and
  the module is disabled (reported once). Declines -> CPU: c != 4, w+1 >
  12, n < 16, VRAM (256 MB margin). Stub twins in gpu/mod.rs for the
  non-GPU build. Knobs: ZK_GPU_ZC=0 (the in-process A/B),
  ZK_GPU_ZC_MIN_PAIRS (default 4096), ZK_GPU_VERBOSE=1.
- TWO BUGS FOUND AND FIXED on the way: (1) the handover copied whole
  8-lane blocks, so a small-n handover carried STALE lanes past n where
  the CPU's ETab pads are zeros (a stale eq lane weighs a pad pair) —
  zeroed at handover; (2) uploads by pageable cuMemcpyHtoD on the
  module's (non-null) stream RACED the next launch (a pageable copy may
  return before the DMA lands): 2-4 failures in 6 runs on tiny shapes,
  data-dependent-looking; fixed by pinned staging + memcpy_htod_async
  stream-ordered on the module's stream (the ixf discipline) — 18/18
  after.
- IDENTITY: `uperf-s agg-battery 7` under ZK_GPU=1 ZK_GPU_ZC_MIN_PAIRS=1
  (the device forced on EVERY aggregate, to the last round): 136 legs
  ok, digest 46234986.. UNCHANGED; smoke shapes incl. the pass's nrw-88
  shape (m 24 x 2^17, 216 claims), a 2^23 grid-stride shape, w 10, e0 2:
  all BYTE-IDENTICAL to zc_range_prove(stacked) + claims ==
  base_mle_eval; `uperf-a pass 12 64 range` ZK_GPU=1: ACCEPT, STAGE-A
  DIGEST statement 441ca5db.. / transcript 44528c6a.. == the CPU run;
  12x128: dc3100e7.. / e5085602.. == the CPU run; GG's `pass-battery 3
  16` (masked honest ACCEPT + 4 tampers REJECT) green with the device
  forced on. FLOORS: CPU + GPU builds; diff-battery green on both
  binaries (19.8 s CPU / 18.9 s ZK_GPU=1); freeze-check 102 ok rows +
  "freeze-check passed"; uperf-s 3752cba4..; agg 46234986..; uperf-x
  be89d5da...
- WALLS at 12x128, ZK_GPU=1, 8T, ONE binary, ZK_GPU_ZC=0 vs 1, two reps
  each back-to-back (lane QQ was benching concurrently at the start):

  | leg | prove (s) | stage-a phase | zc prove (eq / rounds / folds) | opening weight / act | verify |
  |---|---|---|---|---|---|
  | Stage-A, aggregate on CPU | 17.58 / 19.38 | 6.37 / 7.53 | 5.04 (0.23 / 2.60 / 1.52) / 5.88 (0.31 / 2.96 / 1.76) | 2.46 / 7.83 | 4.29 / 4.4 |
  | Stage-A, aggregate on DEVICE | 13.36 / 13.55 | 2.40 / 2.33 | 0.95 (0.00 / 0.26 / 0.02) / 0.95 | 2.34 / 7.65 | 3.88 / 3.9 |
  | oracle (same process, descents on k9) | 9.6 - 9.9 | - | - | - | 2.0 - 2.1 |

  Device-side split (the zc label): 12 aggregates, 96 device rounds /
  folds, 0.83 GB VRAM held; open 0.23 s (300 MB of base tables up),
  rounds 0.19 s, folds 0.01 s, handover 0.01 s; the remaining ~0.5 s of
  "zc prove" is host work (zc_agg_stack's copy + the tail rounds).
  THE FACTOR: the aggregate prover 5.0-5.9 s -> 0.95 s (5.3-6.2x); the
  Stage-A PROVE wall 17.6-19.4 -> 13.4-13.5 s (1.31-1.44x); at 12x64
  12.7 -> 9.8 s (zc 3.10 -> 0.61). Stage-A prove remains 1.36-1.40x the
  oracle's at 12x128 — the port removed the aggregate from the critical
  path; what remains is NOT the aggregate.
- THE RESIDUAL (rung 3's target) from the prof table at 12x128
  (Stage-A | oracle, seconds): bg.prove-group 9.98 | 4.35;
  bg.kernel-rows 3.58 | 1.11; ep.psi0-factored 3.74 | 0.87;
  bg.kernel-phi 0.89 | 0.14; ep.crs-expand 0.84 (x36) | 0.46 (x16);
  ep.level-h-pairs 1.55 | 0.93; bg.matvec-chunks 1.44 | 1.03;
  bg.level-h 1.56 | 0.95; bg.verify-group 3.52 | 1.56. The per-CONTRIB
  phases (kernel-rows, kernel-phi, psi0-factored: +6.1 s prove-side, ~+2
  s verify-side) carry the excess: the Stage-A act group serves ~700
  planes contribs (gg_zc_claims: m x w rank-1 claims per class, each a
  row kernel of length m*w*rows with ONE nonzero block) where the oracle
  serves ~64 rows. eval_proof.rs is read-only for this lane; the lever
  inside this lane's files is the CLAIM TRANSPORT: the m x w per-column
  plane claims of a class recombine LINEARLY to w claims — T_k(x*) =
  sum_i eq(r_inst, i) claim[i][k], the recombination zc_agg_verify
  already performs — i.e. ONE opening claim per plane per class (row
  kernel = the eq(r_inst, i)-weighted block concatenation, col kernel
  eq_lo unchanged); the m rem claims stay (per-member tensors).
  [COUNTED] 672 -> 96 planes contribs at 12x128. That is a TRANSCRIPT
  CHANGE of the Stage-A path (selector-only, not frozen; the served
  plane values become w recombined values per class instead of m x w):
  implemented next as an OPT-IN variant (default byte-identical) and
  posted for the ruling with its measurement.
- commits: R1 = the driver timers + prof + digest line; R2 = the port
  (this block).

R3 THE NEXT COST CENTERS — EVIDENCE (2026-09-02, [WSL-BOX] [8T]
[NOISY-SHARED], ZK_GPU=1, two reps back-to-back each) [MEASURED]:
- R3a THE BATCHED CLAIM TRANSPORT (opt-in, `ZK_RR_ZC_CLAIMS=batched`;
  `gg_zc_claims_batched` + `gg_zc_claims_sel` at both call sites in the
  uperf-a driver; stage_a.rs untouched): the m x w per-column plane
  claims of a class recombined along the instance axis into w claims
  (value = sum_i eq(r_inst, i) claim[i][k]; row kernel = the
  eq(r_inst, i)-weighted block concatenation over the members; col
  kernel eq_lo; the m per-member rem claims verbatim). The SERVED values
  and their absorption ("gg-zc-claims") are untouched; the opening's
  claim structure and hence the nu count change -> a Stage-A transcript
  VARIANT (selector-only path; default = GG's form, byte-identical).
  Claims served at 12x128: 997 -> 439. Identity: CPU == GPU under the
  variant (12x64 statement 441ca5db.., transcript c0b8236fed52daa1..;
  12x128 dc3100e7.. / 1644b4e14dd4f298..); GG's `pass-battery 3 16`
  green under the variant with the device forced on (the "claim"
  tamper flips col_claims[0][0][0] -> the batched value moves -> the
  opening rejects).
- R3b the device stacks the columns on upload (the host `zc_agg_stack`
  copy skipped while the chain is live; pad columns memset on the
  device; the host rebuild stacks on demand) + `gg_build_class_tabs`
  parallel over members: zc prove 0.93 -> 0.57 s, tabs 0.29 -> 0.07 s.
- R3c `gg_build_class_data` (the planes tensor grid) parallel over
  members: commit groups+planes 1.0-1.7 -> 0.9 s, witness 0.8 -> 0.5 s.
- THE 12x128 TABLE (one process, one binary; peak = process peak):

  | leg | commit | prove | verify | total | claims | peak RSS |
  |---|---|---|---|---|---|---|
  | ORACLE (the built pass, descents on k9) | 1.5 | 7.5 / 7.5 | 2.0 / 2.1 | 11.0 | 64 rows | (<= the process peak) |
  | Stage-A, GG transport, aggregate on CPU (round-9 code) | 3.6 | 17.6 / 19.4 | 4.3 | 25.5-27.3 | 997 | 7.5 GB |
  | Stage-A, GG transport, aggregate on DEVICE (R2) | 3.6 | 13.4 / 13.5 | 3.9 | 20.9 | 997 | 7.5 GB |
  | Stage-A, device + BATCHED transport (R3a) | 3.7 | 8.5 / 8.5 | 2.1 / 2.0 | 14.3 | 439 | 2.87 GB |
  | Stage-A, device + batched + R3b/R3c | 3.06 | 7.58 / 7.50 | 2.01 / 1.98 | 12.6-12.7 | 439 | 3.09 GB |

  12x64 (device + batched + R3b/c): Stage-A 2.5 / 5.75 / 1.53 vs oracle
  1.3 / 5.7 / 1.8 (peak 2.6 GB).
  VERDICT ON THE RUNG-3 BAR ("Stage-A wall <= oracle wall at 12x128, both
  ZK_GPU=1, 8T"): MET on the PROVE wall (7.50-7.58 vs 7.5 s: 1.00-1.01x,
  inside run-to-run noise) and the VERIFY wall (1.98-2.01 vs 2.0-2.1)
  UNDER THE BATCHED-TRANSPORT VARIANT; NOT met on the total (12.6-12.7 vs
  11.0: 1.14x) — the planes commit (+1.6 s: groups+planes 0.9 + witness
  0.5 + precommit act 0.77) is the residual, the F1 commit-growth
  finding at this scale. With GG's transport unchanged the bar is NOT
  met (13.4 vs 7.5): the opening's per-contrib cost, not the aggregate,
  is what stands between Stage A and the oracle on this box.
- floors at this commit: CPU + GPU builds; diff-battery green on both
  binaries (15.6 s / 16.1 s); freeze-check 102 ok + passed; uperf-s
  3752cba4..; agg 46234986.. (CPU, and GPU with the device forced on
  every aggregate); uperf-x be89d5da..; 12x64 default-transport digests
  441ca5db.. / 44528c6a.. unchanged; tamper batteries green under both
  transports.
- FOR LANE SS's MERGE: this lane did NOT touch stage_a.rs; the driver
  edits are the [UPERF3-RR]-tagged timer lines, `gg_zc_claims_sel` at
  the two `gg_zc_claims` call sites (prover + verifier), the parallel
  bodies of `gg_build_class_tabs` / `gg_build_class_data`, and the
  print block before `peak RSS`; zc_range.rs: the hook block in
  `zc_agg_prove_masked` (before the eq build, the round, the fold) + the
  three `[UPERF3-RR]` helper fns before `zc_agg_prove`.

R4 THE 12x512 A/B — ORCHESTRATOR-RUN (posted 2026-09-02; NOT run by this
lane: > 5 min; the box must be QUIET; three legs, each detached under
the heavy lock; run leg C FIRST — it is the one expected to fit: the GG
transport's claim rows were the 7.5 GB peak at 12x128 and grow 4x):
ORCHESTRATOR-RUN:
  # leg C: Stage-A device aggregate + BATCHED transport (+ the oracle, same process)
  setsid nohup bash -c 'flock /tmp/zk-heavy.lock env ZK_GPU=1 ZK_THREADS=8 ZK_RR_ZC_CLAIMS=batched M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib /usr/bin/time -v /home/victor/wt-uperf3-rr/zkmatrix-rs/target-gpu/release/ring_matmul uperf-a pass 12 512 range >> /home/victor/wt-uperf3-rr/results/uperf3_rr_12x512_C_batched.log 2>&1; echo $? > /home/victor/wt-uperf3-rr/results/uperf3_rr_12x512_C_batched.done' >/dev/null 2>&1 &
  # leg A: Stage-A device aggregate, GG transport (+ the oracle) — may hit the 15 GB ceiling
  setsid nohup bash -c 'flock /tmp/zk-heavy.lock env ZK_GPU=1 ZK_THREADS=8 M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib /usr/bin/time -v /home/victor/wt-uperf3-rr/zkmatrix-rs/target-gpu/release/ring_matmul uperf-a pass 12 512 range >> /home/victor/wt-uperf3-rr/results/uperf3_rr_12x512_A_gg_devzc.log 2>&1; echo $? > /home/victor/wt-uperf3-rr/results/uperf3_rr_12x512_A_gg_devzc.done' >/dev/null 2>&1 &
  # leg B: Stage-A aggregate on the CPU, GG transport (+ the oracle) — the round-9 form
  setsid nohup bash -c 'flock /tmp/zk-heavy.lock env ZK_GPU=1 ZK_GPU_ZC=0 ZK_THREADS=8 M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib /usr/bin/time -v /home/victor/wt-uperf3-rr/zkmatrix-rs/target-gpu/release/ring_matmul uperf-a pass 12 512 range >> /home/victor/wt-uperf3-rr/results/uperf3_rr_12x512_B_gg_cpuzc.log 2>&1; echo $? > /home/victor/wt-uperf3-rr/results/uperf3_rr_12x512_B_gg_cpuzc.done' >/dev/null 2>&1 &
  READ: the "STAGE-A pass:" line, the ORACLE "accept true |" line, the
  "[UPERF3-RR] ATTRIBUTION" block (commit / prove / verify splits), the
  "zc: on" label (aggregates / declined / VRAM held — a "declined" count
  > 0 means the device chain fell back to the CPU for VRAM: the 12x512
  nrw-88 class needs ~3.2 GB beside k9's residency), the STAGE-A DIGEST
  line, and "Maximum resident set size". An exit 137 / "Killed" with the
  .done file holding 137 is the 15 GB ceiling — record the peak from the
  last "[UPERF2-F] RSS" line.

R5 RECORD (2026-09-02): results/uperf3_rr_stage_a_gpu.md — the measured
factor in lane TT's form. THE LINE THAT REPLACES THE BOARD'S "Stage-A
aggregate GPU port + fold fusion 1.2-1.5x" (UNSOURCED, 2026-08-30):
  * the aggregate prover on the device: 5.0-5.9 s -> 0.58 s at 12x128
    (8.6-10x) [MEASURED];
  * the Stage-A PROVE wall with GG's transport: 17.6-19.4 -> 13.4-13.5 s
    = 1.31-1.44x [MEASURED] — the port alone lands in the guessed range
    but leaves Stage-A prove 1.36-1.40x the ORACLE's (the built pass);
  * with the batched transport (ruling item): 7.5-7.6 s = the oracle's
    7.5 s — Stage A + GPU is 1.00x on prove, 1.00x on verify, 1.14x on
    total (the planes commit) vs the built pass at 12x128 [MEASURED];
    cumulative 2.3-2.6x on the Stage-A prove wall vs the round-9 code.
  * FOR TT: book NO speed factor > 1.0 for "Stage A + GPU" against the
    built pass at 125M; book the bytes (2.15x) and the memory (process
    peak 7.5 -> 3.1 GB at 12x128 in the batched form; at 8B the 120 GB
    descent term). The prove anatomy with Stage A + device + batched at
    12x128: claim layer 0.90 | Stage-A phase 1.29 | openings 5.3 (weight
    2.25, act 3.1) — the OPENING is 70% of the prove.
  * RULING ITEM (Victor / the orchestrator): adopt the batched transport
    as the Stage-A default (then the per-column served values can leave
    the wire too), or keep GG's form and accept 1.8x on the Stage-A prove
    wall at 125M. Soundness reading in the results page §4.
STATE: DONE for rungs 0-3 + 5; rung 4 posted (orchestrator-run).


## Agent SS status (wt-uperf3-ss) — round 10

Lane SS: the committed-h encoding, rungs V1-V4 (spec
U_PERF3_COMMITTED_H.md §3). OWNS: NEW ring/stage_a_full.rs (+ its
`pub mod` line in ring/mod.rs), ONE dispatch line in ring/stage_a.rs,
the driver's Full-mode branches + ADDITIVE `uperf-a` arms in the bin,
NEW results/uperf3_ss_*, this section. Range mode is lane RR's and
stays byte-identical (the floor below).

THE DISPATCH LINE (verbatim, ring/stage_a.rs, inserted before the
"Rung 1" banner — for RR's merge):
`pub use super::stage_a_full as full; // [UPERF3-SS] round 10: the FULL-mode routing (committed-h rungs V1-V4) lives in stage_a_full — the one dispatch line lane SS owns in this file`

### RUNG 0 — SKELETON + THE READING (2026-09-02) [WSL-BOX 8T NOISY-SHARED]

READING THE CODE BEFORE BUILDING (the finding the rungs are cut
around; recorded up front, not after): the act-h group of lane GG's
full mode (`gg_build_groups`, ring_matmul.rs ~:50926) is the S2 LogUp
HELPER h_i = 1/(alpha - key_i) of the two SiLU pair families — a
K-field element per looked-up element committed at the blinder class
(16 coords x l0_q = 16 base-4 digits = 256 digit values = **2 digit
rings per element**), committed after alpha (the F2 ordering). It is
not a range-fact commitment of the activation h, and nothing in the
v3 entry list (Hlo/Hhi/H/Rh) can stand in for it: a LogUp instance
needs a helper column of its own whatever it looks up. The memo's
candidate C2 ("route h's range facts as 256-row lookups over the
existing limbs; the act-h group vanishes") is therefore inverted on
the ring count: a 256-row lookup over an EXISTING 8-bit column costs
the S2 helper (2 rings/element) where the width planes it would
replace cost w/128 = 1/16 ring/element — **32x MORE** for an 8-bit
fact (the planes ARE the compact form for range facts). The v2 pass
the driver runs on has no Hlo (BF_ENTRIES = X, WgT, WuT, WdT, Gacc,
Rg, g8, a8, Uacc, Ru, u8, H, Rh, h8, Dacc, Rd, z); its analog of the
spec's "h16 range fact over Hlo" is the nrw-88 family (the u8/h8
narrowing against [0,256) at offset 128 over the existing h8
commitment) — that is V1's target.
- Sanity [COUNTED vs MEASURED]: `uperf-a full-plan` reproduces GG's
  measured act-h rows exactly — 3x16: 196,608 rings; 12x128:
  6,291,456 (m125 f = 2048 padded to 2048, t x f elements x 12
  layers x 2 rings). Same elements as 8 width planes: 6,144 /
  196,608 rings (32x).
- THE COMPACT FORM THIS LANE BUILDS FOR V3 (where a lookup is
  unavoidable — the SiLU tables): the kappa-level PARTIAL-FRACTION
  helper — commit h at node granularity, h_node = sum_{i in node}
  1/(alpha - key_i) over 2^kappa consecutive keys (one K element per
  2^kappa elements: 2/2^kappa rings/element), and prove h_node *
  prod_i (alpha - key_i) = sum_i prod_{i' != i} (alpha - key_i') by
  ONE degree-(2^kappa + 2) zero-check (eq * (h * Q - P)) whose final
  claims are the 2^kappa key MLEs at (b || x*) over the EXISTING
  member commitments (prim + Y-scaled image, as gg_logup_claims
  serves today) plus h(x*) and h_sum over the 2^kappa-times smaller
  act-h block; the LogUp sum identity sum_nodes h_node = sum_j m_j /
  (alpha - t_j) is unchanged (partial fractions: P/Q = sum_i
  1/(alpha - key_i) exactly when Q != 0, i.e. alpha != every key —
  the S2 redraw measure ~2^-490). kappa = 0 is the S2 form; kappa =
  3 cuts act-h 8x (12x128: 6.29M -> 786K rings) at round degree 10;
  kappa = 4 cuts 16x (393K) at degree 18. This is the ruling's third
  candidate ("a derived-not-committed h with its own relation") in
  partially-derived form; it is a Stage-A full-mode transcript change
  (full mode is selector-gated, not frozen) and needs Victor's ruling
  before the Stage-A round-1 freeze set adopts it — recorded, not
  assumed.
- Built: ring/stage_a_full.rs (ring arithmetic + plan), the mod line,
  the dispatch line, `uperf-a full-plan`, and ONE additive print in
  the driver — `[UPERF3-SS] PASS TRANSCRIPT DIGEST <hex>` (the
  prover transcript state after the last group proof; deterministic
  seeds, so it binds every shipped object) = the byte-identity floor
  for the routing rungs.
- FLOORS: release build green; uperf-pc diff-battery 15.32 s green;
  freeze-check (M125_EXPORT_DIR set) 102 ok rows + "freeze-check
  passed"; uperf-s 3752cba4.. / agg 46234986.. / uperf-x be89d5da..
  unchanged.
- RANGE-MODE BASELINE [MEASURED]: `M125_EXPORT_DIR=... ZK_THREADS=8
  /usr/bin/time -v ring_matmul uperf-a pass 12 64 range nooracle` —
  PASS TRANSCRIPT DIGEST **44528c6aeee0a771..**, 622,011 B counted,
  accept true, weight n_0 3,538,944 / act n_0 1,548,104, 989 claims,
  commit 6.0 s prove 23.7 s verify 3.2 s, peak RSS 3,892 MiB (wall
  31 s). Every later commit re-runs this and must reproduce the
  digest and the byte/ring lines.
- RUNG PLAN (one commit each, prefix "U-PERF3 SS:"): V1 = the nrw-88
  h8 fact of layer 0 as a 256-row identity LogUp over the existing h8
  commitment in full mode, differential vs the planes form (range
  mode's zc) and the descent form (the oracle), rings counted; V2 =
  the counted bill at 12x512 and 32x512 8B for S2 K-helper / E_4
  helper / kappa-level pf helper / planes / descent; V3 = the SiLU
  helper routed through the kappa-level pf form, `uperf-a pass 12
  128 full` peak vs range mode; V4 = the 8B full-mode counted row.
- Commit: 0301c66.

### RUNG V1 — ONE RANGE FACT AS A 256-ROW LOOKUP OVER ITS EXISTING COMMITMENT (2026-09-02) [WSL-BOX 8T NOISY-SHARED]

WHAT WAS BUILT (ring/stage_a_full.rs + the driver's Full-mode branches):
the mode `uperf-a pass L T full-ss [k<kappa_silu>] [r<kappa_route>|noroute]
[ss-sum]` — the SiLU pairs' LogUp helper at kappa levels (kappa 0 = the
S2 form as GG built it) and, by default, the nrw-88 member (layer 0, h8)
taken OUT of its planes class and proven as a 256-row identity lookup
over its EXISTING h8 commitment (multiplicities in act, helper in act-h;
the key claim lands on the member tensor as key_b(x*) - offset * S_eq
with the strided eq_hi x eq_lo kernels the planes form uses; pads carry
key 0 = row 0 and are counted in m[0]). The kappa-level partial-fraction
prover/verifier (eq * (h * Q - P), degree 2^kappa + 2; the verifier is
the house ixf_sumcheck_verify with the shape's combine) landed with it
and is exercised at kappa 3/4 — that is V3's core, tested here on the
small shape. `uperf-a ss-diff` = the standalone R2-style differential.
- DIFFERENTIAL LEG 1, byte identity of the plumbing: `pass 3 16 full-ss
  k0 noroute` reproduces GG's `pass 3 16 full` BIT-FOR-BIT — PASS
  TRANSCRIPT DIGEST **b0349a4536cddaf0..** both, 584,786 B, act-h n_0
  196,608, 231 claims [MEASURED].
- DIFFERENTIAL LEG 2, the lookup form over the existing commitment
  (`ss-diff 1 16`, the real layer-0 h8 column, 2^15 codes, one alpha
  across the forms): kappa 0 / 3 / 4 all ACCEPT; every served value
  grounded DIRECTLY on the raw column in exact K equality (key_b(x*)
  1/1, 8/8, 16/16; h(x*); h_sum and table_sum recomputed); the three
  forms' h_sum IDENTICAL (the same rational identity sum_i 1/(alpha -
  key_i)); TAMPER off-table (one code 300 -> 428, outside [0,256) yet
  inside the committed class — the BK RangeViolation shape; the prover
  honest about its own inverse) REJECTS at the SUM gate with the chain
  intact at kappa 0 and 3; TAMPER served key REJECTS at the CHAIN gate
  at kappa 0 and 3. ALL LEGS GREEN, peak RSS 44 MiB.
- DIFFERENTIAL LEG 3, at pass level (`pass 3 16 full-ss`, kappa 0 both):
  ACCEPT, digest 4c63259d6c4ffd97.., 589,762 B; the route's key_b(x*) /
  h(x*) direct == served, h_sum == table_sum (asserted in the driver);
  `pass 3 16 full-ss ss-sum` (the served h_sum flipped) REJECTS at the
  named gate `ss-lookup-sum:nrw-88`. The descent (table) form of the
  same fact is the frozen oracle's nrw-88 pair (bk_pass_run; its
  RangeViolation leg rejects the same off-table shape) — same rational
  identity, proven as a masked GKR tree instead of a committed helper;
  no served value to compare bit-for-bit across the two proof systems
  beyond the accept/reject pair, recorded as such.
- **THE RING VERDICT [MEASURED at 3x16]**: routing ONE 8-bit fact (2^15
  elements) through the lookup form over its existing commitment
  costs act-h **+65,536 rings** (the S2 helper, 2/element) and saves
  act **-2,030 rings** (its 8 planes 2,048 minus the 18-ring
  multiplicity tensor): **32x MORE commitment for the same fact**.
  `full` -> `full-ss`: act-h 196,608 -> 262,144, act 98,614 -> 96,584,
  bytes 584,786 -> 589,762, peak 1,024 -> 1,145 MiB. The memo's C2
  ("the act-h group and the width planes both vanish") is inverted:
  the planes are the compact form for range facts; the lookup form
  buys ONE thing the planes cannot — the exact one-sided fact [0, 256)
  (GG's OQ-2 sign gap closes by construction: the table IS the range).
  At kappa 3 the same route costs 8,192 rings (4x the planes), at
  kappa 4 4,096 (2x) — still never cheaper than the planes.
- THE V3 FORM AT 3x16 (`pass 3 16 full-ss k3 r4`): ACCEPT, digest
  1fa0ff25b6905bbe.., **act-h n_0 196,608 -> 28,672 (6.9x smaller;
  silu-m3 131,072 -> 16,384, silu-m4 65,536 -> 8,192, the route
  4,096)**, bytes 611,794 (+27 KB: degree-10/18 rounds + 2^kappa key
  claims), peak RSS **890 MiB vs 1,024 (full) / 1,145 (full-ss k0)**,
  lookup sumchecks 1.12 s vs 0.46 s (kappa 0), verify 1.2 s.
- FLOORS: build green; diff-battery 17.45 s green; freeze-check 102 ok
  + passed; 3752cba4.. / 46234986.. / be89d5da.. unchanged; range-mode
  12x64 digest 44528c6a.. UNCHANGED (622,011 B, 989 claims, peak 3,891
  MiB) — range mode byte-identical.
- What V1 does NOT settle: the kappa-level form's soundness argument is
  the partial-fraction identity P/Q = sum_i 1/(alpha - key_i) (exact
  when alpha is no key) plus the standard sumcheck bound at degree
  2^kappa + 2 over K (2^496) — written here, not yet reviewed by
  anyone but this lane; it enters no freeze row until ruled.
- Commit: a169c81.

### RUNG V2 — THE HELPER/MULTIPLICITY COMMIT BILL, COUNTED (2026-09-02) [WSL-BOX, no proving]

`uperf-a full-count [layers] [t]` (M125_EXPORT_DIR set): (a) the
REAL registries of the loaded m125 layers at the shape, built by the
driver's own gg_build_groups in every mode (engine structures — the
same objects the pass commits); (b) the same arithmetic at the 8B
shapes with the MVP8B §1.2 / OO memory law. The count REPRODUCES every
measured row of lanes GG/OO: 3x16 act-h 196,608; 12x128 act 3,091,604
/ act-h 6,291,456 (GG R5); 12x512 act 12,351,296 (planes 4,521,984 =
GG R1's +4.52M) / act-h 25,165,824 (GG's 25.2M); the e0 = 2 group cap
94,177,249 rings (the memo's 94.2M). Peak RSS of the count 320 MiB.

THE 12x512 TABLE (m125 d 768 f 2048; silu elements 12 x 512 x 2048 =
12,582,912) [COUNTED from the registries]:

| mode | act n_0 (planes / mults) | act-h n_0 | act-h / act | act-h store (128 B/ring) |
|---|---:|---:|---:|---:|
| oracle bk_pass_run (descents everywhere) | 7,854,476 | 0 | — | — |
| range (planes; silu descents) | 12,351,296 (4,521,984 / 0) | 0 | — | — |
| full, S2 K-helper as built | 12,345,608 (4,521,984 / 264) | **25,165,824** | 2.04x | 3.22 GB |
| full-ss kappa 3 | same | 3,145,728 | 0.25x | 0.40 GB |
| full-ss kappa 4 | same | **1,572,864** | 0.13x | 0.20 GB |
| full-ss kappa 5 | same | 786,432 | 0.06x | 0.10 GB |
| full-ss kappa 0 + the V1 route | 12,280,094 (4,456,448 / 286) | 27,262,976 | 2.22x | 3.49 GB |
| (E_4 helper, arithmetic only — not built) | | 6,291,456 | 0.51x | 0.81 GB |
| (8 width planes over the same silu elements, for scale) | | 786,432 | | 0.10 GB |

THE 8B TABLE (32x512, d 4096, f 14336 -> f_pad 16384; silu elements
268,435,456; range-form baseline = lane OO's counted row: weight n_0
352,321,536, act n_0 145,475,764, commit ~61 GB, pass peak lvl-0 ~72
GB). Pass peak [MODEL] = max(72 GB + the act-h flat store, the act-h
group's own lvl-0 phase = 63.7 GB of flat stores + its store + A_0 at
209 B/ring + lvl-1 at 76 B/ring — the act-group rates of MVP8B §1.2):

| act-h form | rings | groups under the 94.2M cap | flat store | pass peak [MODEL] |
|---|---:|---:|---:|---:|
| S2 K-helper (kappa 0, as built) | **536,870,912** | **6** | 68.7 GB | **~285 GB** |
| E_4 helper | 134,217,728 | 2 | 17.2 GB | ~119 GB |
| pf kappa 3 (degree 10) | 67,108,864 | 1 | 8.6 GB | ~91 GB |
| **pf kappa 4 (degree 18)** | **33,554,432** | **1** | **4.3 GB** | **~78 GB** |
| pf kappa 5 (degree 34) | 16,777,216 | 1 | 2.1 GB | ~74 GB |
| pf kappa 6 (degree 66) | 8,388,608 | 1 | 1.1 GB | ~73 GB |
| (8 width planes, same elements) | 16,777,216 | 1 | 2.1 GB | ~74 GB |
| descent (GKR tree, range mode) | 0 | — | 0 | 72 GB (+ the 27.9 GB transient silu-m3 pair, MVP8B §1.4) |
| C2-literal: EVERY range fact as a K-helper lookup | **2,952,790,016** (vs their w~8 planes 92,274,688) | 32 | 378 GB | — |

At 32x16 (the yardstick): S2 16.8M rings (2.15 GB) / pf kappa 4 1.05M
(0.13 GB) / kappa 5 0.52M.

VERDICT [COUNTED]: (1) the memo's "~+1-3M class" for C2 at 12x512 is
off by an order of magnitude in the wrong direction — the S2 helper
of the SiLU pairs ALONE is 25.2M (GG measured it), and routing the
range facts through lookups as C2 literally says would cost 2.95
BILLION rings at 8B against 92M for their planes; C2 is retired. (2)
The as-built S2 form is not an 8B object: 537M helper rings, SIX
act-h groups under the exact-digit cap, a ~285 GB peak — the ruling's
"130-160 GB class" undercounted it (flat store only). (3) The compact
committed-h encoding that keeps full mode is the kappa-level
partial-fraction helper: kappa 4 = 1.57M rings at 12x512 (0.13x the
act group) and 33.6M at 8B — ONE group under the cap, +4.3 GB of
store, pass peak ~78 GB on OO's ~72 GB baseline [MODEL]; kappa 5
halves it again at round degree 34. (4) The E_4 helper (4 coords) is
a 4x lever on top of any kappa but changes the LogUp soundness field
to E_4 (2^124, as the zc-agg already draws its challenges) — not
built; counted as the fallback if a lower degree is wanted. (5) Two
8B blockers seen in the code while counting, recorded for V4: GG's
silu phase asserts `prim.len() == n_el` (unpadded keys vs the padded
2^23 hypercube — f = 14336 pads to 16384, so full mode as built
cannot even build its keys at 8B), and the boxed key/helper vectors
(Vec<u64> K elements, ~150 B each) would hold ~40 GB of transient at
8B — the keys must be strided/packed (V3 makes the silu column
strided like the V1 route; the packed build is an 8B-rung item).
- Commit: 1d4e911 (+ results/uperf3_ss_v2_full_count_12x512.log).

### RUNG V3 — FULL MODE FITS THE BOX: `uperf-a pass 12 128 full` (2026-09-02) [WSL-BOX 8T NOISY-SHARED]

WHAT V3 ROUTES, honestly restated after V2: the spec's "all h +
remainder facts routed [through lookups]" is retired by the count
(V2: 2.95 billion rings at 8B for the range facts as lookups vs 92M
for their planes). The remainder/narrowing facts STAY on the planes
(range mode's form, the compact one); the SiLU lookups — the facts
that cannot be planes — carry the compact committed-h: the
kappa-level partial-fraction helper at kappa 4. `full` now MEANS that
(`GgMode::FullSs { kappa_silu: 4, route_nrw: None }`); the S2 form GG
built is reachable as `full-s2` and is byte-identical to the pre-V3
`full` (digest b0349a45.. at 3x16, checked again after every V3 edit).
Also landed: the SiLU keys built STRIDED over the padded grid (pads
on the table's row-0 key, subtracted by every claim builder with the
pad kernel sum — the f = 14336 -> 16384 case GG's `prim.len() ==
n_el` assert excluded; a no-op at m125's f = 2048, digests unchanged),
and the keys diet (a column's boxed keys live only while its helper
or its sumcheck is built; the helper alone is held across the commit).

THE 12x128 TABLE [MEASURED, ZK_THREADS=8, /usr/bin/time -v, walls
NOISY-SHARED — lane QQ benching, the 3x16 checks overlapped one run]:

| `uperf-a pass 12 128 ...` | accept | commit / prove / verify | bytes | act n_0 / act-h n_0 | prover high-water | **peak RSS** | wall |
|---|---|---|---:|---:|---:|---:|---:|
| `range` (planes; silu descents) — the baseline | true | 8.9 / 36.2 / 4.9 s | 637,691 | 3,091,604 / — | — | **6,802 MiB** | 50 s |
| `full-s2` = full as GG built it (S2 K-helper) | **OOM** (GG 2026-08-28, 22T, killed at 2:58) | — | — | 3,086,576 / 6,291,456 | — | **14,777 MiB** (box ceiling) | — |
| **`full` = kappa 4 (V3)** | **true** | 8.4 / 56.1 / 8.9 s (quiet-er run); 9.2 / 57.7 / 17.3 (overlapped) | 860,867 | 3,086,576 / **393,216** | **6,801 MiB** (= range's peak) | **8,072 MiB** (8,872 before the keys diet) | 74 s / 96 s |
| `full-ss k3 noroute` | true | 9.2 / 54.2 / 9.1 s | **772,467** | 3,086,576 / 786,432 | 7,491 MiB | 9,337 MiB | 73 s |
| `full-ss k5 noroute` | **REJECT** at `ss-lookup-chain:silu-m3` (see below) | 8.2 / 66.2 / — | 1,029,059 | 3,086,576 / 196,608 | 6,715 MiB | 6,715 MiB | — |

Digests (the mode-routing floor from here on): range 12x128
e5085602a2fbc93b..; full (kappa 4) 646f0dceae89d8da..; full-ss k3
c2d614550c7cec5b..; range 12x64 44528c6aeee0a771.. UNCHANGED after
every V3 edit; 3x16: full-s2 = full-ss k0 noroute b0349a45.. (the
pre-V3 full), full (kappa 4) dbc581525eb1f9c9.., full-ss (the V1
route) 4c63259d.. — all unchanged by the strided keys and the diet.

VERDICT: **`uperf-a pass 12 128 full` no longer OOMs the 15 GiB box —
peak 8,072 MiB against range mode's 6,802 (+19%) and the as-built
full mode's 14,777 (killed).** The act-h group is 393,216 rings
(16x smaller than the 6,291,456 that OOMed; 0.13x the act group). The
prover's high-water mark is 6,801 MiB — IDENTICAL to range mode's
peak; the remaining +1.3 GB sits in the VERIFIER phase and is the
served-claim kernels (two dense n_h-row kernels per column for h_sum
and h(x*), both prover's and verifier's copies live during verify —
with the as-built helper they were 16x larger, part of the OOM).
Named follow-ups, not built: (i) ONE h_sum claim per PAIR (ones over
all blocks; the union multiset against the summed multiplicities is
the same membership fact) cuts 11 of the 12 ones-kernels; (ii) freeing
the prover's claim vectors before the verifier runs (a driver-level
diet, range mode's too). Wall: prove +20 s over range (the 12
degree-18 lookup sumchecks 14.8 s + the act-h commit/opening); bytes
860,867 vs range 637,691 (+35%: the third opening 175 KB + the
degree-18 rounds x 15 x 12 columns 247 KB, minus the 187 KB of silu
descents) — kappa 3 is the bytes-optimal point (772,467, STAGE-A
173,776 < range's 215,888) at +1.3 GB more memory; kappa 4 is the
memory point. The pre-V3 bytes win vs the oracle (1,372,775) is 2.15x
in the as-built form, 1.6x at kappa 4, 1.8x at kappa 3.

KAPPA 5 IS BLOCKED BY THE HOUSE VERIFIER, not by the design:
`sumcheck::lagrange_eval` (read-only) forms the node denominator
prod_{j != i} (i - j) as an i64 before reducing — it overflows above
degree ~20 (20! = 2.4e18), so the degree-34 round chain of kappa 5
fails at the verifier's own reduction (prover and honest witness
fine: the sums hold; kappa 4 = degree 18 is the last green). Fix =
reduce the denominator mod q per factor (one line in sumcheck.rs, a
frozen-path file — RECORDED for a ruling, not touched). kappa 4
(degree 18) is the practical maximum today; the 8B row (V4) uses it.

FLOORS: build green; diff-battery 17.50 s green; freeze-check 102 ok
+ passed; 3752cba4.. / 46234986.. / be89d5da.. unchanged; range 12x64
digest 44528c6a.. unchanged (622,011 B, peak 3,891 MiB).
- Commit: 3916742 (the code + the 12x128 logs under results/
  uperf3_ss_v3_*; this status text landed one commit later — the
  ledger edit missed its anchor the first time).

### RUNG V4 — THE 8B FULL-MODE COUNTED ROW ON LANE OO's BASELINE (2026-09-02) [COUNTED / MODEL, no run]

The owed recount (RULINGS 2026-08-31 item 2(c): "the 8B memory
projection is STALE for full mode ... a fresh counted row is OWED
before hardware commitments; first estimate ~130-160 GB"). Baseline =
lane OO's counted 32x512 phase table (range-form Stage A + W-3 + the
HH/KK/OO diets): commit ~61 / claim ~20 / lvl-0 ~72 / lvl-1 ~29 /
verify ~6 GB, peak lvl-0 ~72 GB; weight n_0 352,321,536, act n_0
145,475,764 (split in >= 2 groups under the 94.2M cap). Full mode =
V3's routing: the planes for every range fact (already in the
baseline), the SiLU lookups on the kappa-4 partial-fraction helper.
Shape: 32 x 512 x f 14336 -> f_pad 16384 (the strided keys of V3),
silu elements 268,435,456.

| 8B 32x512 term | range form (OO baseline) | full mode, as built (S2 K-helper) | **full mode, V3 (kappa 4)** | label |
|---|---:|---:|---:|---|
| act-h digit rings | 0 | 536,870,912 | **33,554,432** | COUNTED (`uperf-a full-count`) |
| act-h groups under the e0 = 2 gate (94,177,249 rings) | — | 6 (six mid-transcript openings) | **1** (+0.74 bits headroom) | COUNTED |
| act-h flat i8 store (128 B/ring) | 0 | 68.7 GB | **4.3 GB** | COUNTED |
| act-h own lvl-0 phase (63.7 GB flat stores + store + A_0 209 B/ring + lvl-1 76 B/ring) | — | ~285 GB | **~78 GB** | MODEL (MVP8B §1.2 act-group rates) |
| the weight group's lvl-0 phase + the act-h store | 72 | 141 | **76.3** | MODEL |
| served-claim kernels of the lookups (2 dense n_h-row K kernels per column, prover + verifier copies) | 0 (descents serve endpoint claims) | ~137 GB (n_h = 8.4M x 32 cols x 2 x 128 B x 2) | **~8.6 GB** (n_h 524,288) — ~2.2 GB with follow-up (i), ~1.1 with (i)+(ii) | COUNTED from V3's measured attribution |
| per-column transients (one column live: boxed keys ~150 B x 8.4M, the 18 pf tables x 524K nodes) | 0 | 1.3 GB + (S2's packed tables) | **~2.7 GB** | COUNTED |
| the silu descents' transient (MVP8B §1.4: silu-m3 pair 27.9 GB, m4 6.4 GB at 32x512) | **27.9 GB** during the descent phase | 0 | **0** | COUNTED (memo) |
| **pass peak** | **~72 GB** (lvl-0) | **~285 GB** (the act-h opening; the ruling's 130-160 counted the store only) | **~78 GB at lvl-0-class; ~87 GB if the claim kernels are left as they are** | MODEL |
| full-mode bytes vs range (12x128 ratio carried: +35%) | ~1.9 MB (MVP8B §1.5 artifact class) | — | ~2.6 MB | MODEL |
| the 12 -> 32-column lookup sumchecks at 8T (12x128: 14.8 s for 3.1M elements, scalar K, degree 18) | — (descents ~x0.03 of the wall) | — | **~21 min at 8T on this box; ~6-8 min on the Mac's 24+ threads** | MODEL (linear in elements, x85) |
| 32x16 (the yardstick) act-h rings / store | 0 | 16,777,216 / 2.15 GB | **1,048,576 / 0.13 GB** | COUNTED |

THE ROW, in one line: **full mode at 8B under V3's encoding costs
+4.3 GB of committed store and lands the pass peak at ~78 GB
[MODEL] on OO's ~72 GB range-form baseline (≈ +8%; ~87 GB until the
claim-kernel follow-ups land) — ONE act-h group, no new gate problem,
under 128 GB with ~40-50 GB of margin; the as-built S2 form would
have been ~285 GB and six groups.** The F1 ruling's "committed-h
bill" is therefore ~6 GB of the 8B peak, not the 60-90 GB class the
first estimate carried — PROVIDED the transcript change is ruled in
(the kappa-level helper is a new Stage-A full-mode object; nothing
frozen moved, and the S2 form stays reachable as `full-s2`).

WHAT MUST LAND BEFORE T17's FULL-MODE FREEZE SET (recorded, none
built here): (a) Victor's ruling on the kappa-level helper as THE
full-mode encoding (soundness note: the partial-fraction identity is
exact when alpha is no key — the S2 redraw measure; the round chain
is the house sumcheck at degree 18 over K); (b) the lagrange_eval
denominator reduction if kappa 5+ is ever wanted (sumcheck.rs, a
frozen-path one-liner — degree 18 needs nothing); (c) the claim-kernel
diet (i)+(ii) above (~7 GB at 8B; a driver-level change); (d) the
MVP8B memo's W-1/W-3/W-4/W-6/W-7 items shared with range mode; (e)
the packed (KTab) key build if the 1.3 GB per-column boxed transient
matters on the Mac (it does not on 256 GB).

ORCHESTRATOR-RUN (optional, > 5 min at this box's 8T; NOT run by
this lane): the 12x512 full-mode measurement that turns the 12x128
row into the reference shape —
`M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl ZK_THREADS=8 flock /tmp/zk-heavy.lock /usr/bin/time -v /home/victor/wt-uperf3-ss/zkmatrix-rs/target/release/ring_matmul uperf-a pass 12 512 full`
(expected [MODEL]: act-h 1,572,864 rings; peak ~range's 12x512 peak
(~7.85-9 GB class, the 2026-08-29 ladder note) + ~1.5-2 GB of claim
kernels; wall ~5-6 min at 8T with the lookup sumchecks ~60 s) and its
range-mode sibling `... uperf-a pass 12 512 range nooracle` for the
A/B. Post both peaks + digests here.

LANE SS SUMMARY (rungs 0-V4 all landed 2026-09-02, commits 0301c66,
a169c81, 1d4e911, 3916742 + c6b8b1a, V4 below): the memo's C2 was a
conflation (the act-h group is the SiLU lookups' LogUp helper, not a
range-fact commitment of h) and is inverted on the count (a lookup
over an existing 8-bit column costs 32x its planes; all range facts
as lookups = 2.95 billion rings at 8B); the compact committed-h
encoding is the kappa-level partial-fraction helper (16x smaller at
kappa 4), which makes `uperf-a pass 12 128 full` fit the box (8,072
MiB vs the 14,777 OOM; prover high-water = range mode's) and puts
the 8B full-mode peak at ~78 GB [MODEL] on the 72 GB baseline. Range
mode is byte-identical throughout (12x64 digest 44528c6a.. at every
commit). Files: ring/stage_a_full.rs (NEW), ring/mod.rs (+1 line),
ring/stage_a.rs (+1 dispatch line, verbatim above), the driver's
Full-mode branches + `uperf-a full-plan | full-count | ss-diff | pass
.. full | full-s2 | full-ss ..`, results/uperf3_ss_v2_full_count_12x512.log,
results/uperf3_ss_v3_12x128_{range,full_k4,full_k3}.log.

## Agent TT status (main session) — round 10

STATE: LANE COMPLETE (2026-09-02; docs only — no code, no builds, no
runs; worktree wt-uperf3-tt, branch uperf3-tt, cut at 8e2060d).
DELIVERABLE: docs/zkmatrix-poc/U_PERF3_THROUGHPUT_MODEL.md (the
proven-tokens-per-second model, plain language, every number
labelled [MEASURED]/[COUNTED]/[MODEL]/[EXTERNAL] and traced to one
of sixteen named sources). OWNS: that file + this section. Nothing
else written.

THE ANSWER (§0 of the memo, compressed):
- The only timed proof is 12x512 of the 125M model: 18.0 s prover
  clock (21.0 s with verify) = 28 FFN-proven tokens/s OF THAT MODEL
  [MEASURED, S1 = PROGRESS_UPERF2 "after round 9"].
- Built system at 8B, scaled by the counted phase growth (routes memo
  §1.3): ~0.6-0.8 tok/s for T=512 prefill on the laptop, ~1-5 on one
  desktop board, ~1-7 on one H100 [MODEL]; batch-1 decode ~0.0025
  tok/s on the laptop (~0.005-0.02 on either board) — 250x worse
  than prefill because the built protocol re-proves the whole weight
  side per proof and at T=1 the witness is 99.9% weights. At 30B
  every cell is 3-4x smaller again and nothing fits one board.
- 50 tok/s at 30B = 1.55e12 proven MAC/s = 20 ms/token = 10.2 s per
  512-token proof, ~1,000x the measured rate.
- The recorded design path (Stage A + two-tier opening + weight
  preprocessing), at ITS OWN modelled constants, lands at 2-15
  tok/s for 30B prefill and 0.05-0.7 tok/s for 30B decode on one
  H100 [MODEL on MODEL]; at the constants spike S4 actually
  measured, 3-30x lower. Under no assumption recorded anywhere in
  this repository does the lattice line reach 50 tok/s in either
  workload. Batch-1 decode is additionally bounded by the per-proof
  read of the weight digits (172 GB at 30B; 13 ms only if packed to
  2 bits AND H100-resident = 65% of the 20 ms budget).

THE TOKENS/S TABLE (memo §4; FFN-only tokens; laptop / one desktop
board (2-6x [MODEL]) / one H100 (2-8x [MODEL])):
  8B prefill T=512:  (a) built 0.56-0.83 / 1.1-5.0 / 1.1-6.6;
                     (b) +Stage A 0.71-0.80 / 1.4-4.8 / 1.4-6.4;
                     (c) two-tier+preproc, routes constants
                         3.3-5.6 / 6.6-33 / 6.6-45;
                     (c') same, spike-measured constants
                         0.9-2.4 / 1.8-9.7 / 1.8-9.7.
  8B decode:         (a)=(b) 0.0024-0.0027 / 0.005-0.016 / 0.005-0.022;
                     (c) 0.08-0.25 / 0.15-0.55 / 0.15-2.0;
                     (c') 0.003-0.016 / 0.006-0.06 / 0.006-0.06.
  30B prefill T=512: (a) 0.17-0.24 / 0.35-1.4 / 0.35-1.9;
                     (b) 0.21-0.23 / 0.42-1.4 / 0.42-1.9;
                     (c) 1.1-1.9 / 2.3-12 / 2.3-15;
                     (c') 0.26-0.78 / 0.5-3.1 / 0.5-3.1.
  30B decode:        (a)=(b) 0.0006-0.0007 / 0.0013-0.004 / 0.0013-0.006;
                     (c) 0.024-0.09 / 0.05-0.14 / 0.05-0.3 (0.05-0.7
                         with a packed resident store [MODEL]);
                     (c') 0.0008-0.004 / 0.0016-0.017 / 0.0016-0.017.
  Every 8B cell [MODEL]; every 30B cell [MODEL on MODEL] (a
  Gemma-3-27B-shaped stand-in: L 62, d 5376, f 21504 — the real
  Gemma-4-31B architecture is not recorded here); board/H100 add the
  unmeasured hardware factor. The hardware note that matters: on
  scalar integer work an H100 has FEWER SM-GHz than a 4090; its
  edge for this mix is bandwidth (13x the laptop) and 80 GB.

THE AUDIT (memo §5) of the board's 2026-08-30 line — every part
UNSOURCED, RETRACTED:
- "~25-35 tok/s amortized": no derivation anywhere; nearest recorded
  row = the routes memo's most optimistic 8B composition on ONE
  DESKTOP board (~20-40 s/proof) = 13-26 tok/s of an 8B FFN-only
  model; its 30B/one-H100 equivalent 2-15 tok/s prefill, < 1 decode.
- "Stage-A aggregate GPU port + fold fusion 1.2-1.5x": restates the
  design memo's [MODEL] factor for Stage A ITSELF (measured 0.87x on
  CPU at 125M, the composition ladder); "fold fusion" = lane DD's
  rung 5, an unbuilt AVX2 CPU item. Lane RR rung 5 replaces it.
- "pipelining 1.3x": no design, count or measurement exists; the
  structural bound is <= 2x at 12x512's ~50% CPU share and -> 1x as
  the pass is ported (the hardware lever counted twice).
- "spine amortization 1.1-1.2x": contradicted by the routes memo's
  own count (the Fiat-Shamir spine < 1 s of a 620-910 s 8B pass).
- "~65": the product of the four (43-82, midpoint ~62).
  Quotable sentence: memo §5.6. TASK_BOARD.md §0 (orchestrator's
  file) should point its 2026-08-30 line at it.

THE 50 TOK/S BUDGET (memo §7): 1.55e12 proven MAC/s; batch 1 = 20
ms per proof, of which a per-proof walk over the 30B weight digits
is >= 13 ms even packed+resident -> batch-1 decode at 50 tok/s needs
a per-proof weight-side cost SUBLINEAR in the weights (an idea this
repo does not have) or >= ~500 tokens per proof; at T=512 the weight
walk is 0.1% of the 10.2 s budget and the whole question is the
ACTIVATION side: it must prove 1.6e13 MACs in ~10 s = 1.6e12 MAC/s
on one H100 vs a best-modelled 0.5-3.3e11 — 3-20x short at the
routes constants, 5-35x at the spike's. Requirements R1-R5 stated.
Which measurement replaces which constant: QQ rung 4 (the per-proof
weight-side opening after preprocessing at the 12x512 weight group,
the reopen bar >= 5x) + rung 1's 8B/30B count collapse the (c)/(c')
spread; QQ rung 3 = the GPU linear pass; RR rungs 3-5 = the
Stage-A-on-GPU factor ((b) and the activation side of (c)); RR rung
0 = the CPU/GPU split (the pipelining bound, the low end of the
hardware factor); Mac runbook M5 (layer 0 at T = 16/64/512) = the
W/A split at 8B (fit wall = W + A x T/512), turning §2.5's split
from ring-share [MODEL] into [MEASURED, MAC-BOX]; M7 = the thread
factor; choice C = the board factor. The two deciding unknowns: U1
= the per-proof weight-side constant on a GPU (QQ); U2 = whether
ANY lattice-line activation-side opening can run at ~1e12 MAC/s on
one board — no lane measures U2; it is the choice-D question and
should be put to Victor when QQ's count lands. Round 11 is to be cut
from QQ rung 4 + RR rung 5 + M5's three points applied to memo §2.5,
not from any tokens/s number.

COMMITS (branch uperf3-tt, never pushed by this lane): af09959
skeleton + sources; a71b98d §1 workloads; e814f91 §2 cost anatomy;
c02418a §3 hardware factor; 7a28184 §4 table + §0 answer; 3e482b7
§5 audit; 84e306a §6 competitor + §7 budget + unknowns; close = this
commit (status COMPLETE + this section).

## Orchestrator note 2026-09-02 — round 10 merges (TT, SS) [WSL-BOX NOISY-SHARED: lanes QQ/RR building]

- **TT merged (aae3478, fast-forward)**: U_PERF3_THROUGHPUT_MODEL.md.
  Verdict recorded in START_HERE.md §2 and the board §0; the
  2026-08-30 board line retracted in full per memo §5.6.
- **SS merged (827e90b)**: stage_a_full.rs + the one dispatch line +
  the `uperf-a full-plan`/`full-count`/`ss-diff`/`full-ss` surface;
  `full` now = the kappa-4 partial-fraction helper, `full-s2` = the
  GG form. Floors on the MERGED tree (this checkout, release build
  2m06s): diff-battery 16.41 s passed; freeze-check (M125 export)
  102 ok + "freeze-check passed", exit 0; uperf-s battery
  3752cba4..; agg-battery 46234986..; uperf-x be89d5da..;
  `uperf-a pass 12 64 range` transcript digest 44528c6a.., 622,011 B,
  accept — all identical to SS's lane record. RULING ITEMS (SS's
  "WHAT MUST LAND" block, not decided here): the kappa-4 helper as
  the full-mode encoding; the lagrange_eval one-liner for kappa 5+.
- **SS's ORCHESTRATOR-RUN pair (12x512 full vs range nooracle)**:
  DEFERRED — a ~9-11 GB pass while two lanes build on the 15 GB box
  is an OOM risk; enqueue on /tmp/zk-heavy.lock once QQ/RR report.
- **QQ merged (6b6ae1f)**: two_tier.rs R1 functions + `uperf-t
  count|r1 diff|r1 bench|repeat` + the [UPERF3-QQ] block. Floors on
  the MERGED tree (release build 2m09s): diff-battery 17.20 s
  passed; freeze-check 102 ok + passed, exit 0; uperf-s 3752cba4..;
  agg 46234986..; uperf-x be89d5da..; `uperf-a pass 12 64 range`
  transcript digest 44528c6a.., 622,011 B, accept — identical to the
  SS-merge floors. THE VERDICT: the reopen bar NOT MET at 1.00x
  [MEASURED, 8T GPU NOISY-SHARED]; U1 settled at the low band (the
  (c') class of U_PERF3_THROUGHPUT_MODEL.md); Variant B (8-15x
  [MODEL]) is a design-ruling candidate, not built. The GPU build of
  the merged tree is checked at RR's merge (RR adds gpu/ files).
- **SS's ORCHESTRATOR-RUN, first half (2026-09-02, detached under
  /tmp/zk-heavy.lock, the merged binary at 6b6ae1f)**: `uperf-a pass
  12 512 full` (kappa 4) **OOM-KILLED at 15.18 GB max RSS after
  2:06** [WSL-BOX 8T NOISY-SHARED]. The lane's own RSS lines: 8,317
  MiB after the act-h commit (phase B), 12,179 MiB after the Stage-A
  phase (phase C), then signal 9 inside the group openings. SS's
  expectation for this shape was ~9-11 GB [MODEL] ("range's peak +
  ~1.5-2 GB of claim kernels"); the measured growth from 12x128
  (8,072 MiB, accept) to 12x512 is > 7 GB, not ~2. CONSEQUENCES:
  (a) the 12x512 reference shape does NOT run in full mode on the
  15 GB box until the claim-kernel diet SS named lands (or the Mac
  runs it — MAC_RUNBOOK M1b added); (b) the V4 8B full-mode row
  (~78 GB; ~87 GB "until the diet lands") rests on the same
  claim-kernel model and is now a LOWER BOUND pending the Mac's
  12x512 full-mode measurement; the F1 full-mode price is not
  "approximately nothing" at the reference shape as measured here.
  The range-mode sibling (`12 512 range nooracle`) is queued next
  and gives the same-binary baseline peak.
- **SS's ORCHESTRATOR-RUN, second half**: `uperf-a pass 12 512 range
  nooracle` ALSO OOM-KILLED — 15,092,328 kB max RSS (14.4 GiB)
  after 1:42 [WSL-BOX 8T NOISY-SHARED]. So the Stage-A composed
  DRIVER at the reference shape exceeds the 15 GB box in BOTH modes
  on today's tree — this is NOT a full-mode-specific cost. Lane GG
  had projected it on 2026-08-28 ("12x512 DEFERRED WITH CAUSE:
  range-mode projection from the measured 12x128 peak — act 12.4M
  rings = 4x, claim tables 4x, the nrw-88 zc transient ~5 GB — lands
  >= the 15 GiB box"); the HH/KK/OO diets since (-46/-47% at 12x64)
  did not bring the Stage-A driver's 12x512 under the box. MEASURED
  now, not projected. CONSEQUENCES: (a) on this box the Stage-A
  reference shape is 12x128 (both modes accept there; the GPU
  factor lane RR measures is a 12x128 number); (b) RR's rung-4
  12x512 A/B is NOT runnable here — the Mac's M1b gives the CPU
  12x512 numbers for both modes (no CUDA on the Mac, so the GPU
  factor stays a 12x128 measurement until desktop hardware exists);
  (c) the named memory lever for the Stage-A driver is GG's list
  (the nrw-88 zero-check transient, the claim tables at 4x) plus
  SS's claim-kernel diet — a diet lane for round 11 if the WSL box
  is to run the reference shape in Stage-A mode at all; (d) the
  frozen pass (`uperf-pc full-profile 12 512`) is unaffected: 6.7 GB
  with the GPU / 11.1 GB CPU-only [MEASURED 2026-08-18].
- **RR merged (this commit)**: gpu/kernels_zc.cu + gpu/zc_agg.rs +
  the zc_range.rs hook + the [UPERF3-RR] driver timers/prof/batched
  transport. Four ring_matmul.rs conflicts with SS (the uperf-a
  driver) resolved by keeping both lanes' additions: SS's
  `gg_witness_act(.., &ss_m)` signature + RR's `rr_t_wit` timer; RR's
  `rr_s_desc` timer then SS's committed-h SiLU branch; SS's phase-C
  RSS print + tamper block then RR's `rr_t_stagea`; SS's transcript
  digest + RSS prints then RR's `rr_tr_state`. RR's leg C (12x512,
  batched transport, GPU) launched detached under the heavy lock
  with RR's worktree binary; legs A/B not attempted here (the range
  and full 12x512 passes with GG's transport already OOM-killed this
  box today — see above). RULING ITEM from RR: the batched claim
  transport as the Stage-A transcript form (997 -> 439 claims at
  12x128; peak RSS 7.5 -> 3.1 GB; prove parity with the built pass).
  Floors on the merged tree: recorded below once the builds run
  (held until leg C leaves the box).
- **Floors on the RR-merged tree** (this checkout; CPU build 2m14s,
  GPU build 2m23s): diff-battery 15.71 s passed; freeze-check (M125
  export) 102 ok + passed, exit 0; uperf-s 3752cba4..; agg
  46234986..; uperf-x be89d5da..; `uperf-a pass 12 64 range`: CPU
  binary AND GPU binary (ZK_GPU=1, device zc aggregate on, 0
  declined) both print statement 441ca5db.. / transcript 44528c6a..,
  622,011 B, accept — the Stage-A identity holds across CPU/GPU and
  across the SS/RR merge.
- **RR's leg C at 12x512 [MEASURED, WSL-BOX 8T GPU NOISY-SHARED,
  RR's worktree binary]**: Stage-A range mode + device aggregate +
  BATCHED transport: commit 6.1 / prove 17.9 / verify 4.5 s, 670,891
  B, accept, statement ee87f414.., prover == verifier transcript
  e0b3b985..; zc on the device: 12 aggregates, 0 declined, 3.31 GB
  VRAM held, open 0.79 + round 0.69 s. Process peak RSS 11.17 GB
  (BOTH legs in one process) — **the first Stage-A run of the
  reference shape that fits this box** (GG's transport OOMs it in
  both modes, above). CAVEAT on the in-process oracle leg: it
  printed commit 3.0 / prove 54.9 / verify 4.1 s with the k9 status
  "used 0.00 GB, 0 trees" — i.e. the descent kernels did NOT engage
  for the oracle in that process (the 12x64 GPU floor run shows k9
  "used 1.08 GB" when they do), so 54.9 s is a CPU-descent number
  and NOT the A/B reference; the reference is the frozen pass's
  2026-08-18 QUIET GPU row (commit 2.5 / prove 15.5 / verify 1.7).
  Against that: Stage-A batched prove 17.9 s ~ 1.15x (NOISY vs
  QUIET) — parity-class, consistent with RR's 12x128 finding. Bytes
  670,891 vs 1,509,911 (2.25x smaller). Follow-up for a round-11
  lane: why the oracle leg's k9 path stayed cold after the device zc
  aggregate held 3.31 GB (VRAM budget interaction) — a one-process
  A/B needs the oracle leg FIRST or a standalone run.

## RULINGS (Victor, console 2026-09-02, after round 10's close)

Victor, verbatim: "Let's do 1) and 2) go ahead and work on variant B
as well as a separate attempt". Read against the orchestrator's
round-10 close message (item 1 = start the hash-based comparison
prototype now; item 2 = the three rulings: the compact full-mode
helper as the encoding, the batched claim transport as the Stage-A
transcript form, and whether to build Variant B):
1. **CHOICE D STARTS NOW**: the hash-based (float/int-mix-line)
   comparison prototype on OUR exact int8 statement, on OUR rig —
   round 11 lane UU. PROVING_CHANNEL_OPTIONS.md's "documented, not
   started" line changes to "in build".
2. **The kappa-4 partial-fraction helper is ADOPTED as THE full-mode
   encoding** (lane SS's V3 form; `full` already means it, `full-s2`
   keeps the GG/S2 form reachable). T17's full-mode freeze set uses
   it.
3. **The BATCHED claim transport is ADOPTED as the Stage-A transcript
   form** (lane RR's R3a; today opt-in via ZK_RR_ZC_CLAIMS=batched;
   round 11 lane WW makes it the default with the GG form opt-in).
4. **Variant B of the two-tier opening is BUILT as a separate
   attempt** (lane QQ's rung-1 count: tier-1 over the int8 VALUE
   rings) — round 11 lane VV, against the original reopen bar.
If the orchestrator's reading of "2)" overreaches (i.e. Victor meant
only Variant B), items 2 and 3 revert to "pending" — both are
selector-gated Stage-A forms, nothing frozen moves either way.

## ROUND 11 — THE COMPARISON PROTOTYPE + VARIANT B + THE STAGE-A DEFAULTS (opened 2026-09-02)

Ground: round 10 merged (0dc31f7; all floors green, CPU + GPU
binaries). Every lane reads START_HERE.md first, then this block,
then its brief. Worktrees wt-uperf3-{uu,vv,ww} on branches
uperf3-{uu,vv,ww}. Standing rules = round 10's (build under
`flock /tmp/zk-build.lock`; no background runs by lanes; > ~8 min
runs posted as ORCHESTRATOR-RUN; one commit per green rung; labels
on every wall; the built pass byte-identical; floors: release build,
`uperf-pc diff-battery`, `freeze-check` with M125_EXPORT_DIR
102 ok, uperf-s 3752cba4.., agg 46234986.., uperf-x be89d5da..,
`uperf-a pass 12 64 range` statement 441ca5db.. / transcript
44528c6a..).

WHY THIS ROUND (plain words): round 10 measured every recorded lever
of the lattice line and none made a proof faster than today's pass
at 125M; the throughput model puts the line at 2-15 tok/s for 30B
prefill on one H100 at the very best, against a 50 tok/s goal.
Round 11 therefore (a) builds the competing proof system on our own
statement to get OUR number for it (UU), (b) builds the one lattice
lever that counted at 8-15x on paper (VV), and (c) makes the
round-10 memory/bytes wins the defaults and gets the reference shape
running in Stage-A mode on the laptop (WW).

### Lane UU — the hash-based comparison prototype ("Route B") (wt-uperf3-uu) — RUST, NEW CRATE
OWNS: NEW top-level crate `hashline/` (its own Cargo.toml, target
dir, README), NEW results/hashline_*, one status paragraph in
docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md §2 ("in build" + the
measured row when it lands), "Agent UU status". READ-ONLY:
everything under zkmatrix-rs/ (it is the semantic reference and the
source of the frozen SiLU table — `ring::lookup::silu_v2_member` —
and of the export reader's layout; nothing in it is modified),
scripts/m125_export_ffn.py and scripts/m8b_export_ffn.py (the exact
integer chain, the digest sidecar format), TARGET_CONTRACT.md §2 (the
semantics), results/m125_ffn_export_wsl/ (the witness: layerNN_X.bin
int8 T x d row-major, layerNN_WgT/WuT/WdT.bin int8, digests.txt with
the per-layer shifts g/u/h/z and the per-tensor sha256s).
WHAT TO BUILD (the honest comparison row, nothing more): a prover +
verifier for THE SAME statement the lattice line proves at 12x512 —
the 125M FFN pass, 12 layers x 512 tokens, EXACT int8 semantics
(per layer: g = X.Wg and u = X.Wu with exact accumulators; the
requant of g/u by the sidecar shifts with the remainders proven in
range; the SiLU as the FROZEN 256-row v2 table applied to the
requantized gate; the Hadamard with u; the requant of h; z = h.Wd
with its requant to the sidecar's z width; every range fact a
proven lookup) — but proven with a HASH-BASED, small-prime-field
stack: (1) a multilinear polynomial commitment of the Ligero /
Brakedown tensor-product class (rows Reed-Solomon-encoded, Merkle
over columns, evaluation = one clear row-combination + random
column checks; sqrt-size proofs; O(N) prover) over the Goldilocks
field p = 2^64 - 2^32 + 1 with a degree-2 extension for challenges;
(2) the three matmuls per layer via the matrix-multiplication
sumcheck (Thaler: C~(r1,r2) = sum_k A~(r1,k) B~(k,r2), log2(d) rounds,
prover cost linear in the matrix SIZES, not the MACs); (3) the SiLU
table and every range/requant fact via LogUp-as-sumcheck over the
256-row / 2^w-row tables with committed multiplicities; (4) the
Hadamard and requant identities as zero-check sumchecks; (5)
Fiat-Shamir via blake3 or sha2 (the repo has sha2). Field/NTT/Merkle
primitives: use plonky3 crates from crates.io if `cargo` can fetch
them on this box (p3-goldilocks, p3-field, p3-dft, p3-merkle-tree,
p3-symmetric/p3-keccak, p3-challenger); if not fetchable, hand-roll
(Goldilocks arithmetic is ~60 lines; a radix-2 NTT ~80; Merkle over
sha2 ~40) — rung 0 decides and records which.
RUNGS (prefix "U-PERF3 UU:"):
  0. SKELETON: the crate builds (`flock /tmp/zk-build.lock cargo
     build --release --manifest-path /home/victor/wt-uperf3-uu/hashline/Cargo.toml`);
     field + extension + NTT + Merkle + transcript with unit tests;
     the export reader reproduces the sidecar's per-tensor sha256s
     for layer 0 (the witness is the right one); this status section
     with the rung plan.
  1. THE INTEGER CHAIN, EXACTLY: a plain (unproven) Rust
     re-execution of one layer's FFN chain from the export bins that
     reproduces the export's z digest for layer 0 AND layers 1-11
     (the sidecar's `z` sha256 lines) — the proof is only worth
     measuring if it is about the same integers. STOP and record if
     any digest differs (read scripts/m125_export_ffn.py for the
     exact floor/shift/table semantics).
  2. THE MATMUL SUMCHECK at 3x16 for g = X.Wg: prover + verifier;
     a differential vs the plain chain; tamper legs (one flipped X
     entry, one flipped weight) reject.
  3. THE PCS: commit X_l, Wg/Wu/Wd, and the intermediate tensors;
     open the matmul sumcheck's terminal claims through it; tamper
     legs on the commitment (a flipped committed value with an honest
     opening attempt) reject.
  4. THE LOOKUPS + IDENTITIES: SiLU table LogUp, the range/requant
     facts, the Hadamard/requant zero-checks; the full ONE-LAYER
     statement at 12x512 shape (T 512, d 768, f 2048) accepts;
     tamper legs: an out-of-range remainder, a wrong table entry, a
     wrong requant.
  5. THE 12-LAYER PASS at 12x512 end to end (the same 2.89e10-MAC
     statement the lattice line's 21.0 s row proves), measured with
     /usr/bin/time -v at ZK_THREADS-equivalent 8 threads AND at the
     box's 22 threads; prover wall, verifier wall, proof bytes, peak
     RSS; proven MAC/s. THIS IS THE COMPARISON ROW — write it into
     PROVING_CHANNEL_OPTIONS.md §3 next to the lattice line's 1.4e9
     [MEASURED], with the label and every caveat (what is NOT
     proven: attention, seams between layers; what the assumption
     class is: hash-only, ~100-bit with the chosen parameters — state
     them).
  6. (if time) GPU: which kernels (NTT, the sumcheck round sums, the
     Merkle hashing) would go to the RTX 4070 and a [MODEL] estimate
     from the measured CPU shares — no port unless rung 5 is green
     and the measured CPU row already beats the lattice line.
ACCEPT for the round: rung 5's row is [MEASURED] on the same
statement with tamper legs rejecting. A row SLOWER than the lattice
line is as valuable as a faster one — it is the number Victor asked
for.

### Lane VV — Variant B of the two-tier opening (wt-uperf3-vv) — RUST
OWNS: zkmatrix-rs/src/ring/two_tier.rs (ADDITIVE: Variant B behind
a flag; QQ's R1 paths and the S4 paths stay byte-identical), the
`uperf-t` bin section (ADDITIVE subcommands: `count-b`, `b diff`,
`b bench`, `repeat-b`), NEW results/uperf3_vv_*, "Agent VV status".
READ-ONLY: everything else (eval_proof.rs, the pass, manifest.rs,
the GPU modules — reuse QQ's device fold/GEMM hooks, do not edit).
WHAT IT IS (lane QQ's rung-1 count, verbatim): "VARIANT B: tier-1
commitment over the int8 VALUE rings (e = 8) instead of the digit
rings. Row-group exact-digit gate headroom +3.45 / +1.74 / +1.42
bits at 12x512 / 8B / 30B (green); commit and fold 8x cheaper (8B
fold 3.2 s); n_rec full 6.0M at 8B; per-proof 6.7 s (proxy) | 9.1 s
(full) at 8B => ratio 32.8x | 24.0x [MODEL]; 12x512: 12.2x | 5.8x."
And QQ's rung-5 projection: 8B weight side 14-27 s per proof vs
~210 s built (7.8-15x); 30B 65-125 s vs ~940 s. The per-proof lever
it removes is the digit-ring FOLD (58-73% of QQ's measured per-proof
clock at 12x512).
RUNGS (prefix "U-PERF3 VV:"):
  0. SKELETON + the planner: `uperf-t count-b <log2>` prints the
     Variant-B object map and the exact-digit gate at 2^22, 12x512
     W, 8B W, 30B W (reproduce QQ's +3.45/+1.74/+1.42 bits; STOP if
     the gate is red anywhere — that is the finding).
  1. SOUNDNESS NOTE FIRST (a status-section paragraph, before code):
     what the lattice binding rides on when tier-1 commits VALUE
     rings rather than balanced digits — which lemma of
     AGGREGATION_PARAMS_DESIGN.md / the built opening's extraction
     argument covers a tier-1 witness of width e = 8, what the
     norm-bound / exact-digit gate must hold, and what the tier-2
     recursion sees. If the argument needs a NEW lemma, say so
     plainly (Victor rules before any freeze; the build continues
     as a measured spike).
  2. BUILD Variant B on CPU behind the flag: the S4/R1 differential
     legs (b_rows byte-equal, y_m equal, h_cur equal vs the built
     opening) at 2^20 and 2^22; tamper legs reject.
  3. THE DEVICE PATH: QQ's fold-as-GEMM and v-GEMM hooks over the
     value-ring tier; bit-identical to rung 2; walls at 2^22 / 2^23
     8T GPU vs the built `bg_prove_group` GPU path.
  4. THE PER-PROOF MEASUREMENT at the real 12x512 weight group
     (M125_EXPORT_DIR), per-model part warm (`repeat-b`), vs the
     built GPU opening — THE BAR: >= 5x, claims bit-identical.
  5. RECORD: the measured constants -> the 8B/30B per-proof weight
     rows in lane TT's form; the verdict at the bar; what changes in
     U_PERF3_THROUGHPUT_MODEL.md §2.4/§4 if it clears.

### Lane WW — the Stage-A defaults + the driver diet at 12x512 (wt-uperf3-ww) — RUST
OWNS: the `uperf-a` driver section of zkmatrix-rs/src/bin/ring_matmul.rs
(the [UPERF3-GG]/[UPERF3-RR]/[UPERF3-SS] driver code; RR's and SS's
lanes are closed), zc_range.rs (ADDITIVE), stage_a.rs, stage_a_full.rs,
NEW results/uperf3_ww_*, "Agent WW status". READ-ONLY: eval_proof.rs,
two_tier.rs, the frozen pass, manifest.rs, the GPU modules except
zc_agg.rs (RR's — ADDITIVE fixes allowed if a VRAM-budget interaction
is the cause of rung 3's finding).
RUNGS (prefix "U-PERF3 WW:"):
  0. THE DEFAULTS (rulings 2 and 3): `full` = kappa-4 (confirm; it
     already is), the batched claim transport = the Stage-A DEFAULT
     with the GG form opt-in (`ZK_RR_ZC_CLAIMS=gg`); the identity
     floors move accordingly — record the NEW 12x64 batched digests
     (RR: c0b8236f.. at 12x64, 1644b4e1.. at 12x128) as the Stage-A
     identity from here on, and that the GG-form digests
     (441ca5db../44528c6a..) remain reachable under the opt-in.
  1. THE ORACLE-LEG-COLD FINDING: leg C's in-process oracle ran with
     k9 "used 0.00 GB, 0 trees" (descents on the CPU, 54.9 s) after
     the device zc aggregate held 3.31 GB — find the cause (VRAM
     budget interaction? bypass state? order of legs?) and fix it or
     make the driver run the oracle leg FIRST; acceptance: a
     one-process 12x128 A/B where the oracle leg's k9 status shows
     the trees on the device and its prove wall matches the
     standalone frozen pass within noise.
  2. THE DRIVER DIET at 12x512: lane GG's named terms (the nrw-88
     zero-check transient ~5 GB, the claim tables at 4x) and lane
     SS's claim-kernel diet (one h_sum claim per pair; free the
     prover's claims before verify) — until `uperf-a pass 12 512
     range` (batched default) AND `uperf-a pass 12 512 full` accept
     on this box; record the three RSS high-water lines and the
     peaks (/usr/bin/time -v; these are ~2-6 min runs at 8T — run
     them yourself if under 8 min, else post as ORCHESTRATOR-RUN).
  3. THE 12x512 A/B, honestly: oracle (k9 warm) vs Stage-A range vs
     Stage-A full, one binary, ZK_GPU=1, 8T, walls + bytes + RSS +
     digests — the row the round-10 ladder could not take on this
     box; if the oracle leg must be a separate process for the k9
     reason, say so and run it that way.
  4. RECORD: the new Stage-A reference numbers at 12x512 on the
     laptop, in lane TT's form; the 8B full-mode memory re-estimate
     with the diet (replacing the "lower bound" caveat).

## Agent UU status (wt-uperf3-uu) — round 11

(lane appends below)

**RUNG PLAN (2026-09-02, opened).** 0 skeleton + primitives + the
export reader; 1 the exact integer chain vs the 12 z digests; 2 the
matmul sumcheck at 3x16 with tamper legs; 3 the PCS with tamper legs;
4 lookups + identities, one full layer at 12x512 shape with tamper
legs; 5 the 12-layer pass measured (prover/verifier wall, bytes, RSS
at 8T and 22T, proven MAC/s) -> PROVING_CHANNEL_OPTIONS.md §3 row; 6
(optional) the GPU [MODEL] estimate.

**DESIGN OF RECORD (what `hashline/` proves and how).** Per layer l
(T 512, d 768, f 2048), the committed columns are X (as 3 blocks of
T x 256 — d = 768 = 3 x 2^8 is the one non-power-of-two dimension and
is handled by block structure, NOT zero padding, so no padded region
needs constraining), Wg/Wu (3 blocks of 256 x f each), Wd (3 blocks
of f x 256), g8, rg, u8, ru, a8, h8, rh (T x f each), z, rd (3 blocks
T x 256). Requant identities are LINEAR and fold into evaluations:
gacc~(r) := 2^sh_g g8~(r) + rg~(r) (no separate zero-check). Matmuls:
the Thaler matrix-multiplication sumcheck, g and u batched on one
(r_i, r_j) with a random lambda (8 rounds over k' in 2^8, three block
products summed), d over k in 2^11 with the three output blocks
batched; prover cost = the matrix SIZES (fold X against eq(r_i), fold
W against eq(r_j)), not the MACs. Hadamard hh = a8 u8 = 2^sh_h h8 +
rh: a zero-check sumcheck (degree 3 per round). Lookups: LogUp with
committed helper columns h = 1/(alpha - v1) + 1/(alpha - v2) (one
extension helper = two base columns per TWO lookups), the helper
identity h (alpha - v1)(alpha - v2) = 2 alpha - v1 - v2 as a
zero-check batched with the Hadamard check, the helper sum as a plain
functional of the commitment, and the table side computed by the
verifier from multiplicities sent in the clear. Tables: the 256-row
SiLU member as pairs v + beta S[v] (g8's range fact = table-domain
membership, as the lattice line), int8 [-128, 127] for u8/h8/z (the
rig's `fits_i8`), [0, 2^sh) per distinct shift for rg/ru/rh/rd; each
table tagged by gamma * tag so a column cannot borrow another's
table. X and the weights are DECLARED int8 (not range-proven) —
exactly the lattice statement's open M3 finding; the same gap on
both lines. PCS: Ligero/Brakedown tensor form — the committed vector
as an m x n matrix, rows RS-encoded to 4n (rate 1/4), blake3 Merkle
over the 4n columns; an evaluation = one clear row-combination
(extension vector of length n) checked at Q = 256 random columns
(shared across every functional on the commitment); claims that
share column weights share one row-combination. Three commitments
per layer: W (weights), A (activations + X + z), H (helpers, after
alpha/beta/gamma). Fiat-Shamir over blake3; every challenge in Fp2.
Soundness bookkeeping (stated again with the §3 row): proximity
test (1 - delta/3)^Q with delta = 3/4 -> 2^-106; LogUp alpha in Fp2
with 2^23 lookups per layer -> 2^-105 per layer; sumcheck rounds
(deg x rounds)/2^128; Merkle/blake3 2^-128 => ~100-bit hash-only
(+ ROM) class. NOT zero-knowledge (the Ligero ZK masking rows are a
known, cheap addition; not built).

**RUNG 0 — SKELETON + PRIMITIVES + THE EXPORT READER: GREEN
(2026-09-02, WSL-BOX).** `hashline/` builds under `flock
/tmp/zk-build.lock cargo build --release --manifest-path
/home/victor/wt-uperf3-uu/hashline/Cargo.toml` (7.2 s cold). Decision
of record on primitives: crates.io IS reachable from this box
(`cargo search` finds p3-goldilocks / p3-field / p3-dft at
0.7.0-rc.1) but the primitives were HAND-ROLLED — Goldilocks
add/sub/mul (the 2^64 = 2^32 - 1 reduction, canonical), Fp2 = Fp[u]/
(u^2 - 7) (7 checked a non-residue), a radix-2 in-place NTT with a
2^32-order root (pinned to plonky2's 1753635133440165772), a blake3
column Merkle tree, a blake3 Fiat-Shamir transcript — because the p3
API is an rc, the code is ~300 lines, and the measurement stays
self-contained; blake3 1.8 / rayon 1.12 / sha2 0.10 from crates.io
(pinned in Cargo.lock). 16 unit tests green (`cargo test --release`):
mul vs a u128 reference on 200k pairs + edge values, add/sub vs
reference, inverse + batch inverse, two-adic roots, extension
axioms, NTT vs naive evaluation + roundtrip at 2^0..2^12, RS encode
= evaluation, Merkle paths accept / tampered leaf + index reject,
transcript determinism/sensitivity, eq-table sums to 1 and matches
eq at boolean points, matrix folds = tensor evaluations,
interpolation. The frozen SiLU family: zkmatrix-rs has NO lib target
(no src/lib.rs), so `hashline::silu` regenerates both members from
the frozen formula and CHECKS the v2 spec digests against the pins
(bdf8bc71.. for (-3,-3), 06399348.. for (-4,-4) — the same digests
the export manifest's "tables" carries): both reproduce. Export
reader (`hashline check-export`, reading
results/m125_ffn_export_wsl/ read-only, the same digests.txt framing
as bf_sidecar): **48/48 tensor sha256s reproduce** (X/WgT/WuT/WdT x
12 layers) and the sidecar shifts equal the calibration-derived
sh_g = eGate - eX + 9 etc. on every layer (0.05 s).

**RUNG 1 — THE INTEGER CHAIN, EXACTLY: GREEN (2026-09-02, WSL-BOX
22T).** `hashline chain 12`: the plain Rust chain (i32 exact
accumulators, arithmetic-shift floor requant with the low-bit mask
remainder = the rig's bf_floor_requant, the digest-pinned member
table, the rig's [-128,127] range facts) reproduces the sidecar's z
sha256 on **12/12 layers** (3cff4aa0.., 234a13a5.., 78fb1239..,
37e88a6c.., bc684858.., aa3f1d52.., 34e99652.., f6d9ca73..,
7589552a.., 6325892d.., 1d045f10.., 8193e4ca..) with every range
fact holding; 0.06-0.09 s per layer, 0.84 s for the pass including
the file reads [MEASURED, WSL-BOX 22T NOISY-SHARED]. The proof is
about the same integers as the lattice line's. No STOP.
Commit f56c0b3 (rungs 0 + 1).

**RUNG 2 — THE MATMUL SUMCHECK at 3x16: GREEN (2026-09-02).**
`hashline matmul 3 16`: the g/u matrix-multiplication sumcheck alone
(no PCS; the verifier evaluates X~, Wg~, Wu~ and the gacc/uacc claims
from ITS OWN plain matrices — the differential against the plain
chain). Layers 0-2 at T = 16: honest ACCEPT x3 (0.19-0.25 s each,
the folds dominate); tamper legs REJECT on every layer: a flipped X
entry and a flipped Wg entry both fail "sumcheck round 0: s(0) + s(1)
!= claim"; a wrong claimed gacc (g8[i] -= 1) fails "claimed
evaluation != the honest chain's". Sumcheck engine (`sumcheck.rs`):
generic tables in Fp2, MSB-first variable order (row-major matrices
flatten as row bits || col bits), round polynomial sent as values at
0..=deg, verifier interpolates; unit tests: product sumcheck
roundtrip + wrong-sum + tampered-round reject, zero-check with eq.

**RUNG 3 — THE PCS: GREEN (2026-09-02).** `pcs.rs`: Ligero/Brakedown
tensor form over an m x n matrix (n = 2^log_cols), systematic RS at
rate 1/inv_rate via NTT (encoded[i][4j] = data[i][j]), blake3 column
Merkle (tiled column hashing, no transposed copy), functionals as
(slice, coefficient) parts x point (or the all-ones sum), grouped by
identical column weights into ONE clear row-combination each, a
proximity combination, Q shared column checks with paths. Unit test
(2^4 cols, rate 1/4, Q 20): a 4-claim opening over three slices
including an Fp2 helper as (re, u*im) parts and its sum functional
accepts; a wrong claimed value, a flipped committed value with an
honest opening attempt (against the original commitment: root
mismatch; against its own commitment: claim mismatch), and a tampered
clear vector all reject. Opened through the layer statement at T =
16 and T = 512 (rung 4) with the flipped-X / flipped-W legs going
through the commitment path.

**RUNG 4 — LOOKUPS + IDENTITIES, ONE FULL LAYER AT 12x512 SHAPE:
GREEN (2026-09-02, WSL-BOX 8T NOISY-SHARED).** `hashline layer 0 512
--all-tampers --threads 8` (flock zk-heavy, /usr/bin/time -v): the
full one-layer statement (T 512, d 768, f 2048) **ACCEPTS: prove
2.58 s (commit W 0.22 / commit A 0.44 / helpers + commit H 0.54 /
matmul g,u 0.11 / matmul d 0.07 / zero-check 20 0.52 / zero-check 17
0.28 / openings 0.41), verify 0.40 s, proof 5,573,568 B, peak RSS
1.15 GB** [MEASURED]. Tamper legs, all REJECT: flipped X entry (g/u
sumcheck round 0), flipped Wg entry (same), out-of-range remainder
(rg[i] += 2^sh_g with g8[i] -= 1 so the gacc identity holds AND the
prover pads its multiplicities so the totals pass — rejected by the
LogUp identity itself), wrong table entry (a8[i] += 1 with the whole
downstream chain recomputed consistently — rejected by the LogUp
identity), wrong requant (h8[i] += 1, rh unchanged — zero-check 20
round 0), wrong z (d matmul sumcheck round 0). The same six legs
also reject at T = 16 (prove 0.6 s). Commit 34e7dd2 (rungs 2-4).

**RUNG 5 — THE 12-LAYER PASS AT 12x512, MEASURED: GREEN — THE
COMPARISON ROW (2026-09-02, WSL-BOX CPU-ONLY NOISY-SHARED, load avg
2-3).** `flock /tmp/zk-heavy.lock /usr/bin/time -v
hashline/target/release/hashline pass 12 512 --threads N` (one
transcript chains the 12 layers; the same 2.899e10-MAC statement as
the lattice line's 21.0 s row; witness digest-identical):
- **8T: PROVE 23.0 s p50 (22.92 / 23.07 / 23.69 / 21.48 over four
  runs; includes the three per-layer commitments), VERIFY 2.8 s
  (2.76-3.12), proof 66,844,928 B (66.8 MB; 5.57 MB per layer), peak
  RSS 1.56 GB, 1.26e9 proven MAC/s (1.22-1.35e9)** [MEASURED, 8T].
  Per layer 1.80-2.49 s. Phase shares (8T run 1, summed): commit W
  2.19 s, commit A 3.98 s, helpers + commit H 4.58 s, matmul g/u
  0.77 s, matmul d 0.60 s, zero-check 20 4.50 s, zero-check 17
  2.30 s, PCS openings 3.96 s — commitments 47%, zero-checks 30%,
  openings 17%, matmul sumchecks 6%. Witness load + plain chain
  0.9-1.5 s outside the clock.
- **22T: PROVE 37.1 / 39.4 s, VERIFY 7.9-8.1 s, same bytes, RSS 1.57
  GB, 7.4-7.8e8 MAC/s** [MEASURED, 22T]; 16T: 32.2 s / 5.7 s. Thread
  scaling is INVERTED beyond 8T on this hybrid laptop part
  (reproduced); hypotheses [MODEL]: E-cores weak on the 64x64->128
  multiplies of the Goldilocks reduction under the laptop power
  limit, rayon chunking not E-core-aware, WSL2 vCPU scheduling. Not
  chased; the 8T figure is the row (= the lattice line's ZK_THREADS=8
  convention).
- Pass-level tamper leg: `pass 12 512 --threads 8 --tamper requant`
  (a wrong requant in layer 6 of the chained transcript) -> "layer 6:
  REJECT: sumcheck round 0" [MEASURED].
- THE ROW is written into docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md
  §3 (table + caveats) with a §2 status paragraph; the full record is
  results/hashline_pass_12x512.md. Assumption class and parameters,
  stated: Goldilocks p = 2^64 - 2^32 + 1, degree-2 extension for every
  challenge (|Fp2| ~ 2^128); Ligero/Brakedown PCS at RS rate 1/4,
  n = 2^14 columns (W m = 288 rows, A m = 520, H m = 432), Q = 256
  column checks; soundness: proximity (1 - delta/3)^Q = (3/4)^256 =
  2^-106, LogUp (N + |T|)/2^128 = 2^-105 per layer -> 2^-101 over 12,
  sumchecks ~2^-120, blake3 2^-128, Fiat-Shamir in the ROM => ~100-bit
  hash-only class, post-quantum. NOT zero-knowledge. Not proven:
  attention, layer seams (X_l committed fresh — the lattice tower's
  declared seam), X/W int8 ranges (declared; the open M3 finding on
  both lines).
- READING: on the CPU alone the hash-based prover of the SAME
  statement lands at parity with the lattice line's GPU-assisted 21.0
  s (18.0 s commit + prove vs 23.0 s) and ~3.5x under its CPU-only
  81.5 s, with 4.3x less memory (1.56 vs 6.7 GB), 44x larger proofs
  (66.8 vs 1.51 MB), a slower verifier (2.8 vs 1.7 s), and no ZK. The
  proof-system difference §2 predicted is real at 125M on this box
  but is ~4x (CPU vs CPU), not the ~1,000x the vendor claim implies —
  the rest of that gap, if it exists, is GPU-native engineering and
  scale, neither measured here.

**RUNG 6 — GPU ESTIMATE [MODEL], no port (the CPU row is at parity
with the lattice GPU row, not beyond it, so per the brief no port).**
From the measured 8T shares: commitments 47% (per row an inverse NTT
of 2^14 + a forward NTT of 2^16 + blake3 over 64 KB per column: both
are the textbook GPU kernels — batched NTT over 288-520 rows of 2^16,
and a hash-per-column kernel; 10-30x per-kernel over 8 CPU threads
on a 4070 Laptop is the usual range [MODEL]); the zero-check
sumchecks 30% (each round is an embarrassingly parallel map-reduce
over 2^20 points with ~13 Fp2 tables — a GPU reduction; 10-20x
[MODEL]); the PCS openings 17% (row-combinations = a GEMV of an
m x n Fp matrix against 2-3 Fp2 row vectors, plus the strided column
reads — GEMV-class, 10x [MODEL]); the matmul sumchecks 6% (folds =
GEMV, same). Amdahl over the measured shares with those factors:
**~1.5-2.5 s per 12x512 pass on the RTX 4070 Laptop [MODEL on
MEASURED shares]** — i.e. the 5-15 s contract band would be reachable
at 125M on this box, and the 8B extrapolation (100x the MACs, but the
hash line's cost is linear in the witness SIZE, ~100x too) would be
~2.5-4 min on the laptop part and ~30-60 s on a desktop board
[MODEL on MODEL], before any of the two-tier/preprocessing tricks
the lattice line needed just to stay in the game. Nothing here is
built or measured on a device.

**WHERE THIS LANE STOPPED.** Rungs 0-5 green and recorded; rung 6 is
the [MODEL] paragraph above. Open items, none blocking the row: (a)
the inverted thread scaling beyond 8T; (b) proof size (a FRI/STIR
PCS swap or a larger n with the batched-evaluation reduction would cut
the 66.8 MB by ~10x at some prover cost); (c) ZK masking rows; (d)
per-model weight preprocessing (commit W once, 2.2 s of the 23.0 s);
(e) X/W range lookups (5.1M more lookups per layer, ~+15-20% [MODEL])
if the statement is to close the M3 gap on this line; (f) the
LogUp-GKR form to drop the H commitment (~4.6 s of 23.0 s, [MODEL]
half of it recoverable). No ORCHESTRATOR-RUN posted: every run fit
under 8 minutes and was run in the lane.

- 2026-09-02 SKELETON + THE PLANNER (rung 0): worktree wt-uperf3-vv on
  uperf3-vv at 80de176 (round-11 open). OWNS: two_tier.rs (ADDITIVE —
  the [UPERF3-VV] block at the end: `tt_b_value_base`, `TtBTensorPlan`,
  `TtBPlan`, `tt_b_plan`; the FF/QQ functions untouched), the `uperf-t`
  bin section (ADDITIVE: `count-b | b | repeat-b` in the dispatcher +
  the [UPERF3-VV] block after QQ's `uperf_t_qq_repeat`), NEW
  results/uperf3_vv_*, this section. READ-ONLY: everything else.
  RUNG PLAN (one commit each, prefix "U-PERF3 VV:"): 0 this count; 1
  the soundness note (below, before code); 2 `uperf-t b diff|bench` on
  the CPU (the S4/R1 legs at 2^20/2^22 + rejects); 3 the device path
  (QQ's hooks over the value tier, bit-identical, 2^22/2^23 8T GPU vs
  bg_prove_group); 4 `uperf-t repeat-b real-w` (per-model warm) vs the
  built GPU opening at the real 12x512 weight group — THE BAR >= 5x,
  claims bit-identical; 5 the record. Every wall [WSL-BOX] [1T|8T]
  [GPU|CPU] [NOISY-SHARED]; every number [MEASURED]/[COUNTED]/[MODEL].
  THE DESIGN AS PLANNED (two_tier.rs header of the VV block): the
  DESIGN-OF-RECORD GRID is KEPT (QQ's build_tt_grid: g_rows, G, the
  hi *K lo claim factorization, the v-vectors, the tier-2 object all
  IDENTICAL to R1); tier 1 commits row group i = its g_rows*nb
  RECOMBINED VALUE rings Fl_i (the flat-i8 value layout QQ's R1 GEMM
  already reads — `tt_fl_layout_i8` — IS the tier-1 witness) at the
  VALUE base e_v = the smallest e with 2^(e-1) >= the tensor's PUBLIC
  value bound (int8 class: 128 -> e_v 8; alphabet(8) = [-128, 127] is
  CLASS_W8S's declared range exactly, so a value ring is ONE balanced
  digit at base 8); the fold w_v = sum_i c_i Fl_i runs over width_v =
  width/l0 value rings with honest bound fold_coeff_bound(G, e_v); the
  consistency check uses the radix-free value functionals P
  (`tt_inner_value_functionals`, the operand the R1 GEMM consumes);
  gates per opened object: row group (width_v, e_v), folded w
  (n_w_B = sum width_v * l_z(G, e_v, e_u), e_u), tier-2 u (n2, e_u).
  `uperf-t count-b` [COUNTED] (results/uperf3_vv_count_b.log; QQ's
  `qq_count_shape` reused for the record's numbers, `tt_b_plan` laid
  on top) — THE GATE TABLE (the record grid; bits >= 0 green):
  | shape | n0 digit rings | Nv value rings | record row-group | B row-group (tightest tensor) | B folded w (n_w_B) | tier-2 u (n2) | B verdict |
  |---|---:|---:|---:|---:|---:|---:|---|
  | 2^22 FF synthetic | 2.97e6 | 422,912 | +7.95 | **-1.76** (td: e0 2 l0 6, bound 2730 -> e_v 13, width_v 256) | +2.82 (7,424) | +0.54 (173,316) | RED (see F0) |
  | 12x512 weight group | 3.54e6 | 442,368 | +8.95 | **+3.45** (WdT, e_v 8, width_v 192) | +2.05 (21,504) | +0.43 (202,752) | GREEN |
  | 8B weight group | 352.3e6 | 44.0e6 | +7.24 | **+1.74** (WdT, e_v 8, width_v 2048) | +1.35 (901,120) | +0.75 (2,072,576) | GREEN |
  | 30B weight group (ASSUMED 64x5120x25600) | 1.57e9 | 196.6e6 | +6.92 | **+1.42** (WgT, e_v 8, width_v 3200) | +1.28 (4,014,080) | +0.77 (8,053,760) | GREEN |
  QQ's +3.45 / +1.74 / +1.42 bits REPRODUCED exactly at 12x512 / 8B /
  30B: GREEN at every weight shape — no stop. Also counted: the
  folded-w object SHRINKS under B (n_w_B = 21.5K vs the record's
  86.0K at 12x512; 0.90M vs 5.24M at 8B; 4.0M vs 22.9M at 30B — the
  fold bound grows 2^7 but the folded rings drop 8x: l_z 4-7 vs 2-5
  limbs, net 4-6x fewer w digits), so the B folded-w gate is GREENER
  than the record's (+2.05 vs +1.05 at 12x512; +1.35 vs +0.08 at 8B;
  +1.28 vs +0.02 at 30B); n_rec full (w+u+v) 519K / 5.99M / 23.8M vs
  the record's 584K / 10.3M / 42.7M (1.1-1.8x smaller); per-model
  tier-1 commit kappa*Nv = 8.0x fewer ring-MACs; the CRS 2.29M vs
  2.70M rings at 12x512. (The "V-recursed (w+u+v) at e_u" recursion
  row is GATE RED at every shape for BOTH forms — e_u is derived for
  n2 alone (`tt_u_digit_base`), as QQ's proxy measured; a production
  V-recursed form re-derives the base for the combined object; the
  proxy recursion on the u digits is what rungs 3-4 measure, as QQ.)
  FINDING F0 (recorded, not a stop): the 2^22 FF synthetic is RED for
  a PURE Variant B because its td tensor (e0 2, l0 6) is an ACT-class
  tensor with |values| <= 2730 (e_v 13) — Variant B is an INT8-WEIGHT
  lever (QQ's count priced it only for int8_weights shapes); on the
  record grid the value form is green up to about e_v 11 at width_v
  256 (tc +0.24) and fails at e_v 13. Therefore Variant B is defined
  PER TENSOR by a public rule: the VALUE form iff gate(width_v, e_v)
  >= 0, else the record's DIGIT form (QQ's R1Form precedent) — the
  2^20/2^22 differential legs run the hybrid on the SAME instance the
  S4/R1 legs used (td digit-form, the rest value-form), the real
  12x512 weight group runs all-value (36/36 tensors at e_v 8). This
  also answers the act-side question in advance: the value tier does
  NOT extend to act-class tensors (l0 >= 6) on this grid.
  PROJECTION [MODEL from QQ's measured K2-K9 x the counted sizes;
  K9 = QQ's unattributed 0.55 s residual at 12x512 scaled with
  G_all; ranges = C1..short-K GEMM x C5..small-regime recursion]:
  per-proof B 0.83-1.15 s vs built 2.09 s at 12x512 => **1.8-2.5x
  [MODEL]** (the record 1.1-1.4x; QQ measured 1.00x); 8B: B 17-30 s
  vs 208 s => 6.9-12.1x; 30B: B 63-120 s vs 928 s => 7.8-14.8x —
  QQ's rung-5 rows within rounding. Reading BEFORE measuring: on
  the measured constants the fold is the only term B removes (0.80
  -> 0.10 s at 12x512); the v GEMM + P + rows (0.22-0.34 s), the
  recursion (0.13-0.34 s) and the residual (0.37 s) stay, so the
  12x512 bar (>= 5x) is NOT expected to clear on paper; the rungs
  measure it.
  Floors at commit (rung-0 tree, CPU + GPU binaries): build green
  both (2m08s / 2m18s); `uperf-pc diff-battery` 16.99 s CPU / 19.58 s
  GPU green; freeze-check 102 ok + "freeze-check passed" exit 0;
  uperf-s battery 48 legs 3752cba4..; agg-battery 136 legs
  46234986..; uperf-x be89d5da..; QQ's identity `uperf-t r1 diff 20 1
  161` PASS with WIRE DIGEST cae0b312.. (unchanged). Rung 0 commit:
  89dcc51.
- 2026-09-02 RUNG 1 — THE SOUNDNESS NOTE (before code; sources:
  AGGREGATION_PARAMS_DESIGN.md §2.2 / §3.2-3.5 / §4.1-4.2, digits.rs
  (the F-N2 exact-digit form), eval_proof.rs plan_schedule (row
  H-gate-ed, row EB4-emax), the FF two-check structure of two_tier.rs).
  SETTING. The group opening serves ONE thing: the alpha/K-batched
  evaluation claim h_cur = Phi_0 . W over the committed level-0
  witness W. In the built opening W = the digit rings (n0 rings,
  |d| <= 2^(e0-1) per the class alphabet) and Phi_0 carries the
  radix; the RANGE facts about W (each digit in alphabet(e0)) are NOT
  the opening's — the pass proves them by the deterministic
  exact-digit relations (digits.rs header: the range-table lookup /
  Stage A's bit-plane zero-checks + the recomposition RingClaims) and
  serves their final claims through the same opening. Variant B moves
  the OPENED object at tier 1 to the recombined VALUE rings Fl_i
  (|x| <= 2^(e_v-1), e_v public; int8: e_v 8, alphabet(8) =
  [-128, 127] = CLASS_W8S's range, so a value ring is ONE balanced
  digit at base 8, l0 = 1).
  (1) WHAT THE BINDING RIDES ON — the SAME lemma, a NEW PARAMETER
  ROW. Tier 1 is the Greyhound level-0 shape of PARAMS §2.2 (inner
  Ajtai commitments u_i = A_B Fl_i over the row groups, the outer U
  over their digits) with the fold w_v = sum_i c_i Fl_i under quinary
  transcript challenges. Its binding is PARAMS §3.2-3.4 at digit base
  e = e_v: the fold-norm law gamma_z = OP_CONC * 2^(e-1) * sqrt(n*D)
  is stated for a general base (the alphabet enters ONLY through the
  per-coefficient magnitude 2^(e-1)); the extraction slack of the
  exact-digit reading (§3.4 row 2: fork 2 x dc-clearing 29.4 = 58.8)
  is base-independent (it comes from the fork and from inverting a
  challenge difference in the slot structure, LS18 invertibility —
  not from the alphabet); so the extractor yields, per row group, an
  opening Fl_i* of u_i with ||Fl_i*||_2 <= 58.8 * gamma_z(width_v,
  e_v) <= q/8 exactly when the gate gate_headroom_bits(width_v, e_v,
  q) >= 0 holds — the C2' condition beta_top <= q/8 of §3.3, and
  MSIS binding of A_B at (kappa 11, width_v columns, beta_top). The
  instance class is §3.3's top row with FEWER columns (width_v =
  width/l0: 128-192 vs 1024-1536 at 12x512, 1792-2048 vs 14-16K at
  8B) at the same kappa and beta_top — no easier (fewer short
  vectors exist) [the core-SVP count of §3.3 is monotone in the
  column count at fixed beta_top; a one-line check for O-7's table,
  NOT re-run here — recorded as [MODEL]]. The frozen EB4-emax cap
  (e <= 7, plan_schedule's per-level assert) is a cap on the
  RECURSION's interior bases (the 1 B/coordinate wire codec and the
  alphabet-table sizes inside the level loop); the tier-1 object
  never enters plan_schedule — only the folded w's digits at e_u and
  the u digits do, exactly as in the record — so e_v = 8 at tier 1
  does not touch that row. VERDICT (1): no new lemma; the class
  table gains a row {int8-value: min -128, max 127, e0 8, l0 1,
  mod_q false} (non-wrap trivially OK) — a FREEZE-TABLE change
  (UAGB1-1a semantics) that needs Victor's ruling before any freeze.
  (2) THE GATES THAT MUST HOLD (per OPENED object, row H-gate-ed):
  the row group (width_v, e_v) — [COUNTED, rung 0] +3.45 / +1.74 /
  +1.42 bits at 12x512 / 8B / 30B (the tightest tensor); the folded
  w (n_w_B, e_u) — +2.05 / +1.35 / +1.28 (GREENER than the record's
  +1.05 / +0.08 / +0.02: 8x fewer folded rings beat the 2^7 larger
  fold bound); the tier-2 u (n2, e_u) — unchanged +0.43 / +0.75 /
  +0.77. Plus the honest-fold restart discipline: the prover asserts
  |w_v|_inf <= fold_coeff_bound(G, e_v) and the verifier range-checks
  it (V-clear) or its digits' alphabet facts (V-recursed).
  (3) THE CLAIM SEMANTICS — unchanged from FF's argument. With the
  extracted Fl_i* and random c, check (c) sum_j P_e[j] w_v[j] ==
  sum_i c_i v_e[i] per (m, e) pins, by the conditioning argument of
  PARAMS §4.1 (quinary challenges injective per slot, 2^-297 per
  slot), v_e[i] == sum_j P_e[j] Fl_i*[j]: the served v ARE the
  value-functional images of the committed value rings. Check (b)
  then gives h_cur = sum_{i,e} b_e[i] (P_e . Fl_i*) = Phi_0^V . Fl*
  with Phi_0^V the radix-free functional — and Phi_0^V . Fl == Phi_0
  . digits(Fl) identically whenever Fl = sum_l radix_l digit_l (the
  algebra DIFF 1-3 pin bit-for-bit against the built opening). FS
  order v-before-c, u/U-before-v, b_rows-before-alpha as FF; the
  knowledge-error terms are §3.5's (the tier-1 fold at base 8 adds
  NO statistical term in the exact-digit reading: no JL).
  (4) WHAT TIER 2 SEES — exactly the record's object: the u_i (kappa
  mod-q rings per row group, the same G_all groups on the same grid)
  as l_u balanced digits at e_u (the mod-q-native full-column
  class, CLASS_Q31C semantics) bound by U and recursed by the frozen
  planner (the proxy: u digits alone, n2 identical); the folded
  w_v's digits (V-recursed) are a NARROW integer class (bound
  2^17-2^18 << q/2, non-wrap OK) at l_z 4-7 limbs. The checks
  (a)/(b)/(c) are verifier-side polynomial identities on served
  objects with no norm content.
  (5) WHAT IS NEW — WHERE THE RANGE FACT OF THE VALUE TIER LIVES (a
  PROTOCOL OBLIGATION, said plainly). The statement needs |x| <= 128
  per weight (CLASS_ACC24_768's interval arithmetic assumes it). The
  fold norm alone does NOT give it: the extractor's 58.8 * gamma_z is
  a RELAXED L2 bound on the whole row group (~2^22), not a
  per-coefficient alphabet fact. So the int8 fact of the value tier
  must be discharged by one of: (i) A PER-MODEL CERTIFICATE (the
  preprocessing form Variant B's per-proof clock assumes): the digit
  planes of the weights (the record's 8 sign-binary limbs) committed
  ONCE per model alongside the value tier, their alphabet facts
  proven once (alpha-independent), and the digits TIED to the value
  tier by the F-N2 recomposition RingClaims (digits.rs
  `digit_recomposition_claims`: sum_j 2^(e0 j) d_(j,u) - x_u = 0 over
  R_q, constant public coefficients, sound over Z under
  `recomposition_nonwrap_ok(1, 8, q)` — true, 255 << q/2), served
  through ONE per-model opening; every per-proof opening then reuses
  the same value-tier commitment (u_i, U: same CRS, same witness) for
  the evaluation claim only — the standard commit-and-prove
  composition (binding => both extractions yield the same Fl*). THE
  CAVEAT: this is a SECOND opening of the same commitment, which the
  aggregate layer's build rule E-O2-BB forbids (one batched opening
  per group) — a ruling item, not a soundness gap (E-O2-BB is a
  transcript-budget rule, and the record's weight precommit is
  already treated as per-model discipline). (ii) A PER-PROOF 256-ROW
  RANGE-TABLE LOOKUP over the value tier (the U-R2 machinery, LogUp
  with committed multiplicities over Nv entries) with its final
  claims opened through tier 1 as extra contribs — keeps E-O2-BB,
  adds a linear pass over Nv per proof (44M at 8B) that Variant B
  was meant to remove: the fallback, priced not built. Recorded, not
  claimed: the record's own weight range fact via 8 sign-binary limbs
  proves |x| <= 255 (representable(1, 8)) unless the shared sign is
  separately claimed; the base-8 alphabet fact proves exactly
  [-128, 127] — a tightening.
  CONCLUSION. No new LEMMA: the tier-1 binding/extraction is PARAMS
  §3.2-3.4's exact-digit argument at base e_v = 8 with the MSIS
  instance at 8x fewer columns — a new PARAMETER ROW under the same
  lemma, plus a class-table row {e0 8, l0 1}. What IS new is a
  PROTOCOL OBLIGATION: the int8 range fact of the value tier lives in
  a per-model certificate (digit planes + F-N2 recomposition claims +
  a second opening of the value-tier commitment) or a per-proof
  256-row lookup — neither built by this spike (FF's spike did not
  build the record's range facts either; the opening alone is the
  subject) — and it needs Victor's ruling (E-O2-BB, the class row)
  before any freeze. The build continues as a MEASURED spike with the
  S4/QQ criteria: claims bit-identical, gates green, the per-proof
  wall ratio at the bar. Rung 1 commit: fdc718d.
- 2026-09-02 RUNG 2 — VARIANT B ON THE CPU: GREEN, claims bit-identical
  at 2^20 and 2^22; every reject leg fires. BUILT (two_tier.rs,
  ADDITIVE): `TtBForm {Value, Digit}` + `tt_b_form_for` (the public
  per-tensor rule: value form iff the row-group gate at (width_v, e_v)
  is green, else the record's digit form — F0), `TtBLayout {I8, I64,
  Digit}` + `tt_b_layout` (the tier-1 witness = the recombined value
  rings in row-group order: `tt_fl_layout_i8` when every value fits an
  i8 — every real int8 weight tensor — else boxed i64; the SAME object
  the R1 v GEMM reads as its B operand), `tt_b_commit` (u_i = A_B *
  Fl_i via `matvec_modq_small_multi_gen` over the layout slices, CRS
  label "TB" at width_v; the digit form keeps "T" at width — so a
  digit-form tensor's u is byte-identical to R1's), `TtStridedColI8` /
  `TtStridedColI64` (strided columns of the layout) + `tt_fold_b` (the
  value fold as ONE GEMM, a = the G challenges, b = the width_v
  strided columns, len = G — `tt_fold_r1`'s contract over the value
  tier; centered to the exact i64 fold) + `tt_fold_b_ref` (the
  combine-class `fold_chunks_ntt_gen` over the same slices — the
  identity oracle, never on a measured path). Bin (the [UPERF3-VV]
  block): `TtBInst` (plan + forms), `TtBPerModel` (layouts + u + U),
  `tt_build_per_model_b`, SEPARATE `tt_prove_b` / `tt_verify_b` /
  `tt_refold_b` (transcript domain "uperf-t-vb"; FF's tt_prove /
  tt_verify and QQ's R1 untouched): the v-vectors FIRST by R1's value
  GEMM (the i8 layout as its B operand when held), b_rows recovered
  from v, tier 1 over the form's witness, tier 2 over the u digits
  (e_u, l_u from the plan = `tt_u_digit_base`), v absorbed, the fold
  per form with the honest bound `tt_fold_bound(G, e_v | e0)`; the
  verifier's consistency check (c) uses the radix-free value
  functionals `tt_inner_value_functionals` for value-form tensors.
  `uperf-t b diff|bench`, `uperf-t repeat-b`.
  THE DIFFERENTIAL (`uperf-t b diff 20 1 161`, results/uperf3_vv_b_diff20_1t.log
  [WSL-BOX 1T NOISY-SHARED]; `b diff 22 8 161`, results/uperf3_vv_b_diff22_8t.log
  [8T]; the FF instance, forms ta/tb/tc/te/tf VALUE (e_v 7/9/11/5/7;
  layouts i8/i64/i64/i8/i8), td DIGIT (e_v 13, gate -1.26 / -1.76)):
  DIFF 1 b_row images BYTE-IDENTICAL vs the built GroupEvalProof.b_rows
  and the direct kernel pass; DIFF 2 H_m == alphas . rows_m POLY-EXACT
  7/7; DIFF 3 h_cur identical (built route == sum_m H_m); VV-1 the v
  plane (7 x 16) and b_rows BYTE-IDENTICAL to R1's, run by QQ's
  prover in the same process (R1's own wire digests reproduced:
  cae0b312.. at 2^20, cba4356c.. at 2^22), the digit-form u identical
  to R1's and the five value-form u's distinct; VV-2 the value fold
  as ONE GEMM == fold_chunks_ntt_gen over the same layout slices
  (fresh challenges) 5/5; REJECT (7): w tamper -> tt-fold-binding, v
  tamper -> tt-fold-binding, u tamper -> tt-u-binding, b_rows tamper
  -> tt-ct-row-gate, lying-v + honest refold -> tt-consistency, lying
  b_rows non-ct + refold -> tt-claim, and the NEW VV-3 LYING VALUE
  RING (one committed value +-1, u/U re-committed, honest refold
  under the tampered transcript so fold-binding AND the U rebind
  pass) -> tt-consistency. Variant-B WIRE DIGESTS e757eff7.. (2^20)
  / 1b239b2a.. (2^22) — the cross-binary identity for rung 3. Walls
  at 2^19.6 1T: oracle 18.2 s; R1 prove 8.57 s; Variant-B prove 5.01 s
  (layout 0.34 + v 1.13 + rows 0.17 + commits 1.96 + fold 1.02) +
  verify 2.12 s; peak RSS 2594 MiB (2^22 8T: 4978 MiB).
  THE CPU BENCH ROW (`b bench 22 8 161`, results/uperf3_vv_b_bench22_8t_cpu.log
  [WSL-BOX 8T CPU NOISY-SHARED]; QQ's R1 8T CPU row for contrast):
  | 8T CPU, 2^22 synth | QQ R1 (bench22_8t) | Variant B |
  |---|---:|---:|
  | rows-from-v | 0.33 | 0.08 |
  | v-passes | 2.29 | 1.14 (P 0.06 + Fl 0.29 + GEMM 0.76) |
  | fold wall | 0.73 (combine class over 2.97M digit rings) | 1.18 (fold-as-GEMM over 3,456 value columns: 0.86) |
  | proxy recursion prove | 0.71 | 0.72 |
  | tt core (rows+v+fold+rec) | 4.06 | **3.12** |
  | tier1+tier2 commit (+ layout) | 4.91 | 3.26 (+ 0.93 layout) |
  | bg_precommit / bg_prove_group | 2.90 / 8.26 | 3.00 / 7.60 |
  | core ratio | 2.03x | **2.44x** |
  | tt verify | 3.25 | 2.65 |
  | bytes spike-clear | 45.3 MB | 43.0 MB (w 1.77 MB: 3,456 folded rings vs 7,936) |
  READING: on the CPU the fold-as-GEMM over the value tier (0.86 s
  for 3,456 short-K GEMM columns, two of them i64) is NOT faster than
  the record's combine-class fold over 7x more digit rings (0.73 s) —
  the short-K GEMM is the wrong class on the CPU (the combine class
  over the value layout, `tt_fold_b_ref`, is the CPU form; the
  device hook is what rung 3 measures, as QQ). The core gain vs R1
  is the v-pass (the i8 layout cached) and rows. The 5x bar is a
  device question; recorded, not chased on the CPU.
  Floors at commit (CPU + GPU builds green, 2m59s / 2m27s):
  diff-battery 16.88 s; freeze-check 102 ok + passed; uperf-s
  3752cba4..; agg 46234986..; uperf-x be89d5da..; QQ's `r1 diff 20`
  cae0b312.. unchanged. Rung 2 commit: d64c13a.
- 2026-09-02 RUNG 3 — THE DEVICE PATH: bit-identical; at 2^22 / 2^23
  8T GPU the Variant-B core is 1.12x / 1.38x the built GPU opening
  (QQ's R1 at the same shapes: 0.85x / 0.93x). NO NEW KERNEL, as QQ:
  `tt_fold_b` and `tt_b_commit` ARE the `ntt_gemm_modq_small` contract
  whose device port (k_gemm_split) is the existing hook — the value
  layout's i8 groups take the hook's pack fast path; the port is the
  dispatch (ZK_GPU=1 on the gpu-cuda binary).
  BYTE IDENTITY: `ZK_GPU=1 uperf-t b diff 20 1 161` on the GPU binary
  (results/uperf3_vv_b_diff20_gpu.log): WIRE DIGEST e757eff7.. IDENTICAL
  to the CPU run; DIFF 1-3, VV-1, VV-2 and the 7 reject legs green on
  the device (28.5 s, peak RSS 3007 MiB). The 2^22 GPU bench's digest
  1b239b2a.. == the CPU bench's.
  THE MEASUREMENT [WSL-BOX 8T NOISY-SHARED, ZK_GPU=1, RTX 4070 Laptop;
  flock, /usr/bin/time -v; results/uperf3_vv_b_bench{22,23}_8t_gpu.log;
  QQ's R1 rows from results/uperf3_qq_r1_bench{22,23}_8t_gpu.log]:
  | GPU 8T | 2^22 synth: QQ R1 | 2^22 synth: VARIANT B | 2^23 synth: QQ R1 (pre-pooling) | 2^23 synth: VARIANT B |
  |---|---:|---:|---:|---:|
  | rows-from-v | 0.09 | 0.08 | 0.44 | 0.10 |
  | v-pass (P + Fl + GEMM) | 1.35 (0.06 + 0.41 + 0.85) | **0.68** (0.06 + 0.33 + 0.25) | 1.90 (0.31 + 0.67 + 0.87) | **1.06** (0.07 + 0.58 + 0.37) |
  | fold wall (fold-as-GEMM inside) | 0.71 (0.31) | **0.44** (0.16) | 0.96 (0.59) | **0.73** (0.37) |
  | proxy recursion precommit + prove (u digits) | 0.19 + 0.62 | 0.13 + 0.57 | 0.22 + 0.55 | 0.15 + 0.60 |
  | tt core (rows+v+fold+rec) | 2.77 | **1.78** | 3.85 | **2.51** |
  | tier1+tier2 commit (+ layout) — per-model class | 2.24 | 1.78 (+ 0.94) | 2.31 | 2.09 (+ 1.74) |
  | built bg_precommit / bg_prove_group | 0.72 / 2.35 | 0.58 / **2.00** | 1.32 / 3.59 | 1.20 / **3.46** |
  | RATIO core | 0.85x | **1.12x** | 0.93x | **1.38x** |
  | tt verify | 3.05 | 2.18 | 3.51 | 2.77 |
  | bytes spike-clear (w) | 45.3 MB (4.0 MB) | 43.0 MB (1.77 MB) | — | 54.6 MB (2.10 MB) |
  | peak RSS | 5242 MiB | 5563 MiB | 6749 MiB | 7582 MiB |
  READING: on the device the value tier takes the fold wall down
  1.3-1.6x (0.71 -> 0.44; 0.96 -> 0.73) — not the 7x of the ring
  count, because at these shapes the fold-as-GEMM is launch/transfer-
  bound (3,456-4,096 columns of len G = 2-2048, two of them boxed
  i64: 0.16-0.37 s device) and the host tail (bound check +
  poly_from_small + absorb) is the rest; the v-pass halves because
  the i8 layouts are the GEMM's operand directly (the i64 tensors
  tb/tc still rebuild Fl per batch: 0.33-0.58 s — a synthetic-only
  cost, every real weight tensor is i8). What remains of the core is
  the SAME floor QQ named: the recursion (0.57-0.60 s on a 173-207K
  ring proxy) + the v GEMM + rows — 0.9-1.1 s that Variant B does
  not touch. The bar (>= 5x) is NOT met at 2^22-2^23 [MEASURED]; the
  12x512 weight group (rung 4) is the bar's shape.
  Rung 3 commit: 06b88ed.
- 2026-09-02 RUNG 4 — THE PER-PROOF MEASUREMENT AT THE REAL 12x512
  WEIGHT GROUP: **1.77x the built GPU opening [MEASURED] — the >= 5x
  bar is NOT MET.** Claims bit-identical throughout.
  TWO ATTRIBUTION CORRECTIONS FIRST (they change how QQ's 2.08 s
  should be read, and they are in the code now): (1) the per-contrib
  reconstructions H_m (tt_claim_sum over 36 contribs x G x 16 ring
  products) are DIFFERENTIAL objects (the diff's DIFF 2 leg), not
  protocol work — QQ's tt_prove computes them unconditionally at the
  end of every proof, so ~0.3-0.5 s of QQ's per-proof clock was
  bookkeeping (measured 0.31-0.33 s at 2^20 in `b diff`; QQ's
  "unattributed 0.55 s residual" at 12x512 is mostly this); tt_prove_b
  takes `want_hms` (the diff passes true; bench/repeat-b false) and
  times it as its own phase. (2) the fold's "host tail" (QQ: 0.38 s =
  bound check + poly_from_small + absorb over 43,008 folded rings) is
  actually the CHALLENGE DRAW: `agg_draw_cs` draws G_all = 3,072
  quinary rings serially through `draw_quinary_capped` at ~120 us
  each = 0.34-0.40 s per proof, proportional to G_all and independent
  of the tier form; the real tail is 0.01 s (measured with the fold
  phase split into draw / fold-fn / tail). The draws are independent
  pure functions of (state, label, j), so `tt_draw_cs_par` (two_tier.rs)
  runs them on the lane pool — value-identical (the wire digest
  02708a51.. unchanged before/after) — used by tt_prove_b / tt_verify_b
  / tt_refold_b only; the built path's serial `agg_draw_cs` is
  untouched. Draw 0.37 -> 0.08 s at 8T.
  THE MEASUREMENT [WSL-BOX 8T NOISY-SHARED, ZK_GPU=1, RTX 4070 Laptop;
  flock, /usr/bin/time -v; `uperf-t repeat-b real-w 5 8 161`,
  results/uperf3_vv_repeat_b_realw_8t_gpu.log; QQ's `uperf-t repeat
  real-w 5 8 161` re-run in the SAME session for the A/B,
  results/uperf3_vv_qq_repeat_realw_8t_gpu_rerun.log; the phase table
  from `uperf-t b bench real-w 8 161`, results/uperf3_vv_b_bench_realw_8t_gpu.log]:
  | GPU 8T, REAL 12x512 WEIGHT group (3,538,944 digit rings = 442,368 value rings, 36 tensors, all value/i8) | QQ R1 (same session, n = 5) | VARIANT B (n = 5) |
  |---|---:|---:|
  | PER-MODEL build (held warm) | 2.43 s (u + U + i8 layout), 91.2 MB | **2.14 s** (layouts 0.23 + tier-1 u over the VALUE rings + U), 91.2 MB |
  | per-proof rows-from-v | 0.08-0.09 | 0.08-0.09 |
  | per-proof v-pass (P + GEMM; layout cached) | 0.26-0.37 (0.12 + 0.12-0.23) | 0.27-0.35 (0.11-0.14 + 0.12-0.20) |
  | per-proof fold wall | 0.79-1.30 (GEMM 0.40-0.90 over 3.54M digit rings + serial draw ~0.37 + tail) | **0.33-0.47** (draw 0.07-0.09 pooled + fold-fn 0.24-0.38 over 442K value rings + tail 0.01) |
  | tier commits from cache + absorbs | 0.03 + (in residual) | 0.03-0.04 + v-absorb 0.03 |
  | h_ms (differential bookkeeping) | in the clock (~0.3-0.5, unattributed) | NOT computed |
  | tt_prove | 1.71-2.33 | **0.78-0.96** |
  | per-proof recursion prove (proxy: u digits, 202,752 rings) | 0.30-0.51 | 0.39-0.52 |
  | **PER-PROOF (min / median)** | 2.14 / 2.30 | **1.24 / 1.29** |
  | built bg_prove_group (min / median), same run | 2.11 / 2.13 | 2.20 / 2.23 |
  | built bg_precommit (min) | 0.67 | 0.67 |
  | **RATIO built / per-proof** | 0.98x (1.30x + precommit) | **1.77x (2.31x + precommit)** |
  | claims | b_rows byte-identical; digest 12a8a3f6.. x5 | b_rows byte-identical; digest **02708a51..** x5 (== the pre-pooled-draw run) |
  | bench: tt core (rows+v+fold+rec) vs bg_prove_group | (QQ rung 3: 2.30 vs 2.42, 1.05x) | 1.34 vs 2.51, **1.88x**; verify 2.15 s (consistency 0.77) |
  | peak RSS | 5871 MiB | 5510 MiB |
  WHERE THE 1.24 s GOES: the recursion prove 0.39-0.52 (the frozen
  bg machinery on a 203K-ring proxy — 1.9-2.6 us/ring, the small
  regime QQ named; 35%), the value fold GEMM 0.24-0.38 (36 device
  GEMMs of 1 x 128-192 columns x len 64-96 — launch/pack-bound: 8x
  fewer rings than the record's fold but only ~1.5-2x less wall), the
  v-pass 0.27-0.35 (P on the CPU pool 0.11-0.14 + the i8 GEMM
  0.12-0.20), rows 0.08, the draw 0.08, absorbs 0.06. The bar (>= 5x)
  needs <= 0.44 s per proof: the recursion ALONE is at or above the
  whole budget, before any fold or v-pass. VERDICT AT THE BAR: NOT
  MET — 1.77x [MEASURED]. Per the brief the ratio is the finding and
  the lane stops here (rung 5 = the record).
  Floors at commit (final tree, CPU + GPU builds green 2m12s /
  2m29s): diff-battery 16.11 s CPU / 18.23 s GPU; freeze-check 102 ok
  + passed; uperf-s 3752cba4..; agg 46234986..; uperf-x be89d5da..;
  QQ's `r1 diff 20` cae0b312.. unchanged; `b diff 20 1 161` CPU
  e757eff7.. (== GPU). Rung 4 commit: 4244278.
- 2026-09-02 RUNG 5 — THE RECORD AND THE VERDICT. LANE COMPLETE. The
  full record in lane TT's form is results/uperf3_vv_variant_b.md
  (the verdict, what was established, the measured constants K1'-K10,
  the 8B/30B projection rows, what is not measured, the ruling
  items). THE VERDICT against the bar (per-proof weight-side opening
  at the real 12x512 weight group >= 5x faster than the built GPU
  opening, claims bit-identical): **NOT MET — measured 1.77x** (1.24
  s vs 2.20 s min, 1.29 vs 2.23 median, n = 5, [WSL-BOX 8T GPU
  NOISY-SHARED], claims byte-identical, the per-model part held
  warm); QQ's design of record in the same session 0.98x. THE
  MEASURED CONSTANTS at 12x512 (GPU 8T NOISY): K1' per-model 2.14 s
  (launch-bound: 4.8 us / value ring); K2 v GEMM 4.5-7.5 G D-MAC/s
  short-K (C1 74 G/s at 8B widths [MODEL]); K3 P 1.3-1.6 G MAC/s; K4'
  value fold GEMM 0.54-0.86 us / value ring (launch-bound; the C1-
  regime bound is the record's 119 ns / ring); K5' fold tail 1.9 us /
  folded ring; K6 recursion 1.9-2.6 us / ring (small regime; C5 0.62);
  K7 rows 1.1-1.25 G MAC/s; K8 built 0.62 us / digit ring; K9 (QQ's
  residual) RESOLVED = h_ms bookkeeping + the serial draw; K10 draw
  120 us / ring serial, 23-29 us pooled at 8T. THE PROJECTION FOR
  LANE TT (per-proof weight side, [MODEL] = the constants x the
  counted sizes; ranges = C1..launch-bound GEMM x C5..small-regime
  recursion):
  | shape | per-MODEL | v GEMM + P + rows | fold GEMM + tail | draw | recursion | absorbs | **per-proof** | built | ratio |
  |---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
  | 12x512 W [MEASURED] | 2.14 s | 0.27-0.35 + 0.08 | 0.24-0.38 + 0.01 | 0.08 | 0.39-0.52 | 0.06 | **1.24 / 1.29 s** | 2.20 / 2.23 s | **1.77x** |
  | 8B W (44.0M value rings, G_all 23,552, n2 2.07M) | ~30 s | 1.2-12 + 4.4 + 0.7 | 5.2-24 + 0.3 | 0.6-0.7 | 1.3-5.4 | ~0.5 | **14-48 s** | ~210-218 s | **4.4-15x** |
  | 30B W (ASSUMED shape; 196.6M value rings, G_all 66,560, n2 8.05M) | ~130 s | 5.4-54 + 14 + 2.0 | 23-106 + 1.1 | 1.5-1.9 | 5.0-21 | ~1.4 | **54-201 s** | ~930-975 s | **4.6-18x** |
  READING FOR THE RULING: at the bar's shape Variant B is 1.77x
  [MEASURED] — 1.8x better than the record's parity, at the low end
  of the count's own [MODEL] range for that shape (1.8-2.5x), because
  the two GEMM-class terms (the value fold, the tier-1 commit) are
  launch-bound at width_v 128-192 and the recursion is in its small
  regime; the floor is the recursion (0.39-0.52 s on a 203K-ring
  proxy of frozen machinery) + the fold GEMM + the v-pass, and the
  recursion alone exceeds the 0.44 s the bar allows. At 8B/30B the
  rows STRADDLE the bar (4.4-15x / 4.6-18x [MODEL]): Variant B does
  remove most of the fold (73% of the record's 8B clock), but whether
  the fold GEMM at 8B widths runs at the C1 class or stays launch-
  bound is a question this box cannot answer (the 8B shape does not
  fit 15 GB) — an 8B-shape measurement on the Mac or a desktop board
  is the only thing that moves it. WHAT CHANGES IN
  U_PERF3_THROUGHPUT_MODEL.md §2.4/§4: nothing at the bar — the
  12x512 row is 1.77x, not 5x; the 8B Variant-B row moves from QQ's
  "14-27 s [MODEL]" to "14-48 s [MODEL on measured constants]" and
  the lattice-line band (0.5-3 tokens/s at 30B prefill on one H100)
  stands. RULING ITEMS (none frozen; the spike is selector-gated):
  (1) the class-table row {int8-value: e0 8, l0 1}; (2) the per-model
  weight certificate = a second opening of the value-tier commitment
  (E-O2-BB) or the per-proof 256-row lookup; (3) the pooled challenge
  draw as a prover-side form (value-identical; the verifier's replay
  unchanged). NOT MEASURED (honesty): the act-side opening (F0: the
  value form does not apply to act-class tensors); the verifier (2.15
  s at the weight group; R2's recursed serving never built); the
  bytes (45.7 MB clear vs 180 KB built); the per-model weight
  certificate; a quiet box; a desktop board or an H100; a fused fold
  kernel (one launch for the 36 small GEMMs — the other way to remove
  K4' at 12x512; it does not touch the recursion floor). The S4 and
  R1 code paths, the built pass and every freeze row are
  byte-identical (floors green at every commit; QQ's `uperf-t r1
  diff 20 1 161` gives cae0b312.. on the final tree; FF's `uperf-t
  diff` is untouched).
  ORCHESTRATOR-RUN: none posted — every run of this lane fit the
  foreground limit (longest: `b diff 22 8 161`, 1:20).
  Commits: 89dcc51 (rung 0), fdc718d (rung 1), d64c13a (rung 2),
  06b88ed (rung 3), 4244278 (rung 4), this entry (rung 5).

## Agent WW status (wt-uperf3-ww) — round 11

Lane WW: the Stage-A defaults (rulings 2-3), the cold-descent-kernels
finding, the driver diet at 12x512, the honest 12x512 A/B. OWNS per the
brief: the `uperf-a` driver section of ring_matmul.rs, zc_range.rs
(ADDITIVE), stage_a.rs, stage_a_full.rs, gpu/zc_agg.rs (ADDITIVE fixes
if rung 1's cause is there), NEW results/uperf3_ww_*, this section.
Worktree cut at 80de176. Binaries: CPU `target/release` (2m17s) and
GPU `target-gpu/release --features gpu-cuda` (2m36s), both green on
the round-11 ground before any edit.

### RUNG 0 — THE DEFAULTS (2026-09-02) [WSL-BOX 8T NOISY-SHARED: lanes UU/VV building]

- RULING 2 (`full` = the kappa-4 partial-fraction helper): CONFIRMED
  in the code, no change — `uperf-a pass L T full` parses to
  `GgMode::FullSs(SsCfg { kappa_silu: 4, route_nrw: None, .. })`
  (ring_matmul.rs, the `Some("full") =>` arm of the pass parse);
  `full-s2` = GG's S2 form stays reachable.
- RULING 3 (the batched claim transport = THE Stage-A transcript
  form): `rr_zc_claims_batched()` now defaults to TRUE; the GG
  per-column form is the opt-in `ZK_RR_ZC_CLAIMS=gg` (the old
  `=batched` value is still accepted, a no-op). The `[UPERF3-RR]
  ATTRIBUTION` line names the form in force; the `uperf-a` usage
  string names the knob. One function + two prints; nothing frozen
  touched.
- THE STAGE-A IDENTITY FROM HERE ON [MEASURED, one CPU binary and one
  GPU binary, `uperf-a pass 12 <t> range nooracle`, M125_EXPORT_DIR
  set, ZK_THREADS=8] (statement digest | prover == verifier transcript
  | bytes | claims | peak RSS, /usr/bin/time -v):
  * 12x64 DEFAULT (batched), CPU: 441ca5db.. | **c0b8236fed52daa1..** |
    622,011 B | 431 | 1,667 MiB (commit 6.0 / prove 22.1 / verify 2.6 s).
  * 12x64 DEFAULT, GPU (ZK_GPU=1): 441ca5db.. | **c0b8236f..** (== CPU) |
    622,011 B | 431 | 2,136 MiB (3.0 / 7.5 / 1.6 s).
  * 12x128 DEFAULT, GPU: dc3100e7.. | **1644b4e14dd4f298..** | 637,691 B
    | 439 | 2,496 MiB (3.3 / 8.4 / 2.7 s). (RR's R3a values, reproduced.)
  * 12x64 OPT-IN `ZK_RR_ZC_CLAIMS=gg`, CPU: 441ca5db.. | **44528c6aeee0a771..**
    | 622,011 B | 989 | 4,114 MiB (7.2 / 24.4 / 3.8 s) — the pre-round-11
    identity remains reachable, byte-identical.
  READING: the statement digest does not move (the transport is an
  opening-structure choice, not a statement change); the transcript
  digest is the form's identity. At 12x64 on the CPU the batched form's
  process peak is 2.5x smaller than GG's (1,667 vs 4,114 MiB) — the
  ~700 rank-1 claim rows were the peak, as RR found at 12x128.
- FLOORS on this commit (CPU binary): `uperf-pc diff-battery` 18.44 s
  passed; `freeze-check` (M125_EXPORT_DIR) 102 ok + "freeze-check
  passed", exit 0; `uperf-s battery 8` 48 legs, 3752cba4..; `uperf-s
  agg-battery 7` 136 legs, 46234986..; `uperf-x battery` 8 legs,
  be89d5da.. — all unchanged. The GPU binary builds (2m39s) and prints
  the same 12x64/12x128 digests as the CPU binary (above).
- FOR THE ORCHESTRATOR / the board §0: the round-11 floor line "`uperf-a
  pass 12 64 range` statement 441ca5db.. / transcript 44528c6a.."
  becomes "statement 441ca5db.. / transcript **c0b8236f..** (default;
  44528c6a.. under ZK_RR_ZC_CLAIMS=gg)". Logs:
  results/uperf3_ww_r0_{freeze_check,12x64_batched_cpu,12x64_gg_cpu,12x64_batched_gpu,12x128_batched_gpu}.log.
- Commit: 26990ea.

### RUNG 1 — THE COLD-DESCENT-KERNELS FINDING: CAUSE + FIX (2026-09-02) [WSL-BOX 8T GPU NOISY-SHARED]

THE CAUSE [MEASURED, `ZK_GPU_VERBOSE=1` at 12x512, one process
(`uperf-a pass 12 512 range`, batched default);
results/uperf3_ww_r1_repro_12x512_verbose.log]: NOT a k9 budget
decline — a DEVICE ERROR that disables k9 for the rest of the process
(`[UPERF2-L] gpu k9 ixf round failed (h2d: CUDA_ERROR_INVALID_VALUE)`,
printed right after the oracle leg's `bk.commit-end`), produced by a
VRAM-residency interaction of three device modules:
1. RR's zc aggregate module keeps its table/eq buffers across the
   phase's 12 aggregates (3.31 GB at 12x512) and nothing gave them
   back before process exit ("held 3.31 GB" on leg C's status line).
2. k9's VRAM budget is fixed at its init (free 7.15 - 0.256 = 6.88 GB,
   computed in the Stage-A leg's claim layer, BEFORE zc allocated) and
   its slabs are kept for the process: after the Stage-A leg's silu
   descents it sits on 3.76 GB of IDLE residency.
3. Lane L's ixf module (the claim layer's device-built zero-check
   tables + device chain at 2^24: 4.06 GB, released per instance)
   budgets against the LIVE free VRAM with a 256 MB margin.
The sequence in the oracle leg's claim layer: free VRAM 0.34 GB (8.59
total - zc 3.31 - k9 idle 3.76 - ~1.2 base) -> the ixf module DECLINED
("need 4.06 GB more, free 0.34 GB"; it never declines in the standalone
frozen pass, where the claim layer precedes the descents and it opens at
4.06 GB) -> the CPU-built tables went through k9's own `ixf_round`
upload path (first instance: a 2.4 s first round, the 4-table upload)
-> at the second instance k9's accounting crossed its budget mid-way
through the table-grow loop -> `make_room` (fired from `grow_dev`)
freed the WHOLE idle ixf_t family — including the tables grown moments
earlier in the same call (`self.ixf` is None during the loop; "k9: gave
back 3.76 GB") -> the upload wrote to ptr 0 -> CUDA_ERROR_INVALID_VALUE
-> `k9_ixf_round` disables the module -> all 20 descents on the CPU
(bk.descent-gkr 28.8 s + trees 7.0 s): prove 54.9 s (leg C) / 59.1 s
(the repro). At 12x128 the residency is 0.83 + ~1 GB and nothing bites
(RR's warm 7.5 s oracle).
HALF-FIX EVIDENCE (the zc release alone;
results/uperf3_ww_r1_12x512_ab_gpu_verbose.log): free at the oracle's
claim layer 3.65 GB — still < 4.06 + 0.256, the ixf module still
declined, the crash recurred (prove 56.2 / 49.8 s in two runs). The k9
half is required — rung 1 proves the cause is a k9 budget interaction,
so the brief's ADDITIVE, default-preserving k9 fix is in scope.

THE FIX (three additive pieces; nothing frozen moves — every digest
below is unchanged):
(a) gpu/zc_agg.rs: `pub fn zc_agg_release() -> usize` — the module's
    private `release()` made callable: table/eq/ab buffers back to the
    device, the module stays live (not bypassed, not disabled; the next
    open re-grows), a no-op while a chain is live or before any open.
(b) gpu/k9.rs, two pieces: [B] in `K9::ixf_round` the room is made ONCE
    before the table-grow loop (`make_room` for the pre-check's own
    over-counted `more`, then decline = the CPU round if still short) —
    no `make_room` can fire mid-loop any more, so the upload can never
    target a buffer freed in the same call; [C] `pub fn k9_trim_idle()
    -> usize` — `make_room`'s own rule (the idle families + the wholly
    free slabs; never a live chain, the layer binding, the eq or the
    tree store) at a caller-chosen boundary. k9's static init-time
    budget itself is left as is (re-reading free VRAM inside the
    frozen path's device planner is a behavior change I did not want
    without a ruling; the trim makes the boundary explicit instead).
(c) the `uperf-a` driver: both called at the END of the Stage-A phase
    (before the openings), one print `[UPERF3-WW] device residency
    given back after the Stage-A phase: zc .. GB, k9 .. GB`. gpu/mod.rs:
    the two names on the `pub use` lines + two no-op stub twins for the
    non-GPU build (RR's pattern; the minimal export).

ACCEPTANCE [MEASURED, one GPU binary, one process, ZK_GPU=1, 8T]:
- 12x128 (results/uperf3_ww_r1_12x128_ab_fixed.log): given back zc 0.83
  + k9 0.81 GB; Stage-A 3.4 / 7.7 / 2.1 s; ORACLE 1.9 / 8.9 / 2.2 s with
  k9 "used 1.89 GB" (the trees on the device); the standalone frozen
  pass `uperf-pc full-profile 12 128` (GPU) 2.1 / 9.2 / 2.3 and 2.3 /
  11.4 / 2.5 in two runs — within noise. Digest 1644b4e1.. unchanged;
  process peak 3,110 MiB.
- 12x512 (results/uperf3_ww_r1_12x512_ab_fixed_verbose.log): given back
  zc 3.31 + k9 2.96 GB; the oracle leg's claim layer OPENS the ixf
  module (5 x "ixf open ... held 4.06 GB" — the standalone path); no k9
  failure; ORACLE commit 3.3 / prove 18.2 / verify 4.1 s vs the
  standalone frozen pass `uperf-pc full-profile 12 512` (GPU, same
  session) 3.4 / 16.9 / 3.8 and 3.6 / 17.7 / 4.4 — within noise (+3-8%,
  NOISY-SHARED). Stage-A 7.1 / 18.8 / 4.6 s, digest e0b3b985.. unchanged
  (the fix is transcript-neutral). Process wall 57 s (was 1:37).
  **Process peak RSS 7,157 MiB — leg C's "11.2 GB fits" was the
  CPU-descent artifact (the oracle's CPU trees, hwm 10.9 GB at
  bk.claim-layer-end), not the Stage-A driver's peak.**
- FLOORS on this commit. CPU binary: diff-battery 15.66 s passed;
  freeze-check 102 ok + passed, exit 0; uperf-s 3752cba4..; agg
  46234986..; uperf-x be89d5da..; 12x64 c0b8236f.. (default) /
  44528c6a.. (gg); `uperf-a pass-battery 3 16` green. GPU binary:
  diff-battery (ZK_GPU=1) 18.43 s passed; agg-battery with the device
  forced (ZK_GPU_ZC_MIN_PAIRS=1) 46234986..; THE FROZEN PASS AFTER THE
  k9 EDIT: `uperf-pc full-profile` EVAL-PROOF DIGEST 12x128 742d88e1..
  and 12x512 4c259008.. == the same binary lineage before the edit
  (results/uperf3_ww_r1_frozen{128,512}_after_k9fix.log vs
  uperf3_ww_r1_12x{128,512}_frozen_gpu.log); `pass-battery 3 16` with
  the device forced green.
- FOR RUNG 3: the one-process A/B is VALID on this box from here on —
  no separate oracle process needed.
- Commit: 03c0a49.

### RUNG 2 — THE DRIVER DIET AT 12x512: BOTH MODES ACCEPT ON THE BOX (2026-09-02) [WSL-BOX 8T GPU NOISY-SHARED]

THE STARTING POINT [MEASURED, the rung-1 binary, batched default,
ZK_GPU=1] — the two OOMs of 2026-09-02 were GG's transport's, not the
shape's: `uperf-a pass 12 512 range nooracle` peak **7,152 MiB** (was
killed at 14.4 GiB under GG's form), 30 s wall, accept, e0b3b985..;
`uperf-a pass 12 512 full` peak **12,472 MiB**, ACCEPT (was killed at
15.18 GB), wall 1:46, 6.5 / 82.2 / 16.2 s, 900,003 B, act-h 1,572,864
rings (SS's count), with the three RSS lines phase B 6,989 / phase C
6,989 / prover done 9,540 MiB — i.e. the VERIFIER phase set the
full-mode peak (+2.9 GB: SS's claim-kernel term, 4x: per column a
dense ones-row and an eq-row of gh_rows = 655,360 K elements, ~84 MB
each, x 24 claims, prover's and verifier's copies alive together).
Both modes therefore accepted before any diet; the margin in full
mode (2.5 GB on a box where two lanes build) was the reason to land
the named diet anyway.

THE DIET (driver only; range mode byte-identical; the full-mode
transcript moves as SS named — recorded below):
(i)  SS's ONE h_sum CLAIM PER PAIR (`ss_lookup_claims(.., pair_sum)` +
     `ss_pair_h_sum_claim`): the served per-column h_sum_j / table_sum_j
     stay on the wire and the verifier keeps its per-column sum gate;
     the OPENING claim that grounds the h sums on the committed helper
     becomes one ones-row over the pair's column blocks with value
     sum_j h_sum_j (12 -> 2 dense rows per side at 12x512). SOUNDNESS
     NOTE (written here, reviewed by nobody but this lane): the pair's
     membership fact is the UNION LogUp identity over the pair's one
     frozen table with the summed multiplicities; sum_j table_sum_j is
     grounded per column on the committed multiplicities, the union
     claim pins sum_j h_sum_j to the helper's true total, and the two
     totals agree only when every key of every column is in the table
     (the partial-fraction identity at a random alpha — the S2
     argument, unchanged); the per-column split of the h_sum grounding
     added nothing. The V1 route (one column, its own tensor) keeps the
     per-column form; `full-s2` (GG's `gg_logup_claims`) is untouched.
(ii) FREE THE PROVER'S CLAIMS BEFORE THE VERIFIER: `claims`, `claims_h`,
     the assembled group claims, the nus and the flat level-0 witness
     (w0_w / w0_a / w0_h) dropped right after the group proofs (+
     `uf_trim`), the counts kept for the report line.
(iii) GG's named host terms dropped at the end of the Stage-A phase
     (beside rung 1's device release): `class_data` (the per-class
     planes data the zc tables were built from), `bk_aux`, `m_vals`,
     `ss_m`, `ss_tables`, the routed columns/helpers (`logup_mat` stays:
     the full-s2 verifier reads it).
(iv) The RSS high-water lines are printed in EVERY mode now (phase C,
     prover done, a "dropped before the verifier: current RSS" line,
     after the verifier), not only in full mode.

THE RESULT [MEASURED, one GPU binary, ZK_GPU=1, 8T, /usr/bin/time -v]:

| `uperf-a pass 12 512 ..` | accept | commit / prove / verify | bytes | claims | phase B / C / prover done / after drops (current) / verifier hwm | **peak RSS** | wall |
|---|---|---:|---:|---:|---|---:|---:|
| `range nooracle`, before the diet | true | 6.7 / 18.9 / 4.6 | 670,891 | 455 | — / 6,985 / — / — / — | 7,152 MiB | 0:30 |
| `range nooracle`, WITH the diet | true | 6.4 / 19.1 / 4.9 | 670,891 | 455 | — / 6,985 / 6,985 / 2,778 / 6,985 | **7,152 MiB** | 0:31 |
| `full`, before the diet | true | 6.5 / 82.2 / 16.2 | 900,003 | 427 + 24 | 6,989 / 6,989 / 9,540 / — / (peak) | 12,472 MiB | 1:46 |
| `full`, WITH the diet | true | 6.7 / 77.4 / 11.4 | 900,003 | 427 + **14** | 6,988 / 6,988 / **7,547** / 2,999 / 7,547 | **7,728 MiB** | 1:36 |

READING: full mode's peak -4.7 GB (-38%): (ii)+(i) took the verifier
off the peak (it now starts from 3.0 GB and never exceeds the prover's
high-water), (iii)+(i) took the prover-done mark from 9,540 to 7,547
(-2.0 GB), and verify fell 16.2 -> 11.4 s (10 fewer dense contribs).
Range mode's peak did not move: its 7.15 GB IS the commit-phase peak
(phase B/C = 6,985-6,989 MiB in both modes) — the planes' act group
(12.35M rings vs the frozen pass's 7.85M; the frozen pass peaks at
2,833 MiB on the GPU at this shape) under lane OO's commit memory law:
the F1 commit-growth term, an engine item (MVP8B W-1/W-3), not a
driver term. Full mode now sits +0.58 GB over range mode at 12x512
(SS's 12x128 row had +1.3 GB before the diet).
At 12x128: `full` peak 4,417 -> **3,161 MiB** (SS's 8,072 MiB under
GG's form); 3.6 / 27.5 / 4.6 s, 860,867 B, 441 claims.

THE FULL-MODE IDENTITY (the batched default AND the diet both move it;
the STATEMENT digest does not move — c6f1850a.. at 12x512 and
1a3517de.. at 12x128 before and after the diet; range mode is
byte-identical throughout: 12x64 c0b8236f.., 12x512 e0b3b985..):
  * 12x512 `full`: **8d1ef1a8..** (pre-diet under the default 8ab3dd36..).
  * 12x128 `full`: **4b02815d..** (pre-diet 4669b9f4..; SS's 646f0dce.. under GG's form).
  * 3x16 `full` (kappa 4): **6863f0d6..** (pre-diet 9c3c2e7e..; SS's dbc58152.. under GG's form).
  * 3x16 `full-s2`: d47cd6d7.. UNCHANGED by the diet (SS's b0349a45.. under GG's form).
  * 3x16 `full-ss` (the V1 route, k0): 45c5cd18.. (SS's 4c63259d.. under GG's form).
  * Under `ZK_RR_ZC_CLAIMS=gg` the pre-diet full forms are NOT
    recoverable (the diet is not knob-gated — it is the full-mode form
    from here on); SS's digests were reproduced under the opt-in BEFORE
    the diet (3x16 full dbc58152.., full-s2 b0349a45..) and are recorded
    as the round-10 form. Tamper legs: SS's `pass 3 16 full-ss ss-sum`
    (the served h_sum flipped) still REJECTS at `ss-lookup-sum:nrw-88`;
    `ss-diff 1 16` ALL LEGS GREEN; GG's `pass-battery 3 16` green.
FLOORS on this commit (CPU binary): diff-battery 16.84 s passed;
freeze-check 102 ok + passed, exit 0; uperf-s 3752cba4..; agg
46234986..; uperf-x be89d5da..; 12x64 range c0b8236f.. / 44528c6a..
(gg). No GPU-module change since rung 1 (its GPU floors stand).
Logs: results/uperf3_ww_r2_12x512_{range_nooracle,full}_{predict,diet}.log,
uperf3_ww_r2_12x128_full_{predict,diet}.log, uperf3_ww_r2_3x16_full_diet.log,
uperf3_ww_r2_freeze_check.log.
- Commit: 5d3ca82.

### RUNG 2b — THE ACT-H CLAIM ROWS WERE DENSE: COMPACT ROWS + ONE CONTRIB PER TENSOR (2026-09-02) [WSL-BOX 8T GPU NOISY-SHARED]

THE FINDING (from the code while writing rung 4's 8B row): every act-h
opening claim carried a DENSE row of gh_rows K elements (`vec![zero;
gh_rows]`, one block nonzero) — gh_rows = the pair's columns x n_h,
NOT n_h. SS's V4 counted the claim kernels at block size ("n_h =
524,288 x 32 cols x 2 x 128 B x 2 = ~8.6 GB"); SS's own 12x128
verify-phase growth (+1.3 GB) is the DENSE size (24 x 163,840 x 128 B
per side), the block size gives 50 MB. At 8B the dense rows were 64 x
~1.7 GB = ~95 GB per side, both sides alive before diet (ii) — the
pre-round-11 full mode at 8B was a ~260 GB object [COUNTED from the
layout], not the "~87 GB" caveat.
THE FIX (driver only, TRANSCRIPT-NEUTRAL): `WwHClaim` = (value,
parts(tensor, scale, ROW OFFSET, COMPACT row, col)); the three act-h
claim builders (`ss_lookup_claims`, `ss_pair_h_sum_claim`, and GG's
S2 `gg_logup_claims`) push the column's block at its offset; ONE
helper `ww_combine_h_claims` (prover and verifier) builds ONE dense
row per act-h tensor from the compact rows with the nus drawn —
K = sum_j nu_j scale_j (row_j (x) ypow) = (sum_j nu_j scale_j row_j)
(x) ypow, the same kernel the engine summed over 14 (or 24) contribs;
the opening's transcript does not see the contrib decomposition.
IDENTITY [MEASURED]: 3x16 `full` 6863f0d6.., `full-s2` d47cd6d7..,
`full-ss` 45c5cd18.., 12x128 `full` 4b02815d.., 12x512 `full`
8d1ef1a8.. — ALL UNCHANGED; `ss-sum` tamper still REJECTS at
`ss-lookup-sum:nrw-88`; range 12x64 c0b8236f.. unchanged.
THE RESULT [MEASURED, GPU binary, 8T]: `uperf-a pass 12 512 full`
peak **7,156 MiB** (rung 2's 7,728; the rung-1 binary's 12,472; the
killed 15.18 GB) == range mode's 7,152 — the commit-phase high-water
(6,988) is now the process peak in BOTH modes (prover done 6,988,
after the drops 3,097, verifier hwm 6,988); prove 74.5 s (the act-h
opening `tail` 9.4 s vs 11.8-14.2; `bg.kernel-rows` 6.9 s x3 groups),
verify 10.4 s (was 11.4-16.2), wall 1:31, 900,003 B, 441 claims.
12x128 `full` peak **2,884 MiB** (rung 2: 3,161; SS: 8,072), 3.5 /
26.2 / 4.3 s. Logs: results/uperf3_ww_r2b_12x512_full_compact.log,
uperf3_ww_r2b_12x128_full_compact.log, uperf3_ww_r2b_freeze_check.log.
FLOORS on this commit (CPU binary): diff-battery 16.19 s passed;
freeze-check 102 ok + passed, exit 0; uperf-s 3752cba4..; agg
46234986..; uperf-x be89d5da..; `pass-battery 3 16` green; `ss-diff
1 16` green; 12x64 range c0b8236f... GPU binary: the 12x512/12x128
full digests above (its GPU-module floors are rung 1's, no GPU module
changed since).
- Commit: the commit carrying this entry ("U-PERF3 WW: RUNG 2b + 3 + 4").

### RUNG 3 — THE 12x512 A/B, HONESTLY (2026-09-02) [WSL-BOX 8T GPU NOISY-SHARED, one binary]

One process for the oracle + Stage-A range (`uperf-a pass 12 512
range`, valid since rung 1 — no separate oracle process needed); full
mode runs without the in-process oracle by construction (the FullSs
parse passes with_oracle = false), so its oracle reference is the
range run's leg and the standalone `uperf-pc full-profile 12 512` of
the same session. Two reps each + the rung-1/2 runs [MEASURED]:

| leg | commit | prove | verify | total | bytes | claims | peak RSS | identity |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| ORACLE standalone (`uperf-pc full-profile 12 512`) x3 | 3.3-3.6 | **16.9-17.7** | 3.8-4.4 | 24.6-25.7 | 1,509,911 | 64 rows | 2,833 MiB | EVAL-PROOF 4c259008.. |
| ORACLE in-process (the range run's leg) x3 | 3.3 | **18.2-18.8** | 4.1-4.2 | 25.6-26.3 | 1,509,911 | 64 rows | (7,158 MiB, both legs) | k9 warm, ixf module open |
| STAGE-A RANGE (batched default, device zc) x3 | 6.4-7.1 | **18.8-19.1** | 4.6-5.0 | 30.3-31.0 | **670,891** | 455 | **7,152 MiB** | ee87f414.. / e0b3b985.. |
| STAGE-A FULL (kappa 4 + the diet) x3 | 6.2-7.3 | **74.5-82.9** | 10.4-14.6 | 91-105 | **900,003** | 441 | **7,156 MiB** | c6f1850a.. / 8d1ef1a8.. |

OUTLIER, recorded not averaged: range rep 2's oracle leg — the 20
masked-GKR descents took 140.8 s (6.6 s in rep 1) with k9 live ("used
6.72 GB"), no device error, no decline line; its Stage-A leg was +20%
too; no concurrent process in the sibling lanes' result timestamps
(VV's last GPU logs 13:56, UU's 13:09, the rep at 14:05-14:08) — a
NOISY-SHARED contamination of the device (results/uperf3_ww_r3_12x512_range_ab_rep2.log).
READING: Stage-A range = prove parity with the built pass at the
reference shape (1.02-1.03x in-process, 1.08-1.11x vs standalone),
total 1.15-1.18x (the planes commit +3.1-3.5 s), bytes 2.25x smaller;
prover clock 25.2-26.2 vs 21.5-22.1 s -> 1.1e9 vs 1.3e9 proven MAC/s
[COUNTED]. Full mode 4.0-4.4x the prove wall (the 12 scalar-K
degree-18 lookup sumchecks 44-47 s + the act-h group 9-14 s) for a
1.68x smaller proof with no GKR descent left — at range mode's
memory. The prove anatomy (range, rep 1): claim-layer 2.39 | Stage-A
phase 4.54 (silu descents 2.26, zc prove 1.67 on the device: 264
rounds, 83.6 G MACs) | openings 11.78 (weight 2.46, ACT 9.32 = 50% of
the prove). Logs: results/uperf3_ww_r3_12x512_{range_ab_rep1,range_ab_rep2,full_rep1,full_rep2,frozen_rep3}.log.

### RUNG 4 — RECORD (2026-09-02)

results/uperf3_ww_12x512_stage_a.md — the 12x512 Stage-A reference
numbers on the laptop in lane TT's form (§1 the A/B table, §2 the
reading for THROUGHPUT_MODEL §2.3 (b): book NO speed factor > 1.0
for Stage A + GPU at 125M, book the bytes 2.25x and the memory; §3
the memory table with the three RSS lines per rung; §4 the 8B
full-mode row; §5 what was built; §6 open items).
THE 8B FULL-MODE MEMORY ROW, RE-ESTIMATED WITH THE DIET: **~85 GB
[MODEL]** = the act-h phase (SS's V4 ~78 GB: OO's ~72 GB baseline + the
4.3 GB kappa-4 store at the act-group rates) + ~6.4 GB of act-h claim
rows in the rung-2b layout (32 compact eq-rows 2.1 GB + 2 pair
ones-rows 2.1 GB + 2 combined rows 2.1 GB; the verifier's copies not
simultaneous) + ~2.7 GB of per-column lookup transients (SS) — vs the
weight group's ~72 GB lvl-0 phase; under 128 GB with ~40 GB of margin.
This REPLACES the "lower bound" caveat (orchestrator note 2026-09-02,
consequence (b)): the measured full-mode peak at the reference shape
now EQUALS the range-form peak (7,156 vs 7,152 MiB), so full mode's
8B excess is the counted act-h terms (~13 GB), not a measured growth
law; the pre-diet full mode would have been ~260 GB at 8B (the dense
rows, both sides), which is what the 12x512 kill was measuring.
Flagged, not measured: the host-built zc class tables at 8B (nrw-88:
~64 members x 8 planes x 2^23 x 4 B = ~17 GB of transient during its
aggregate, below the 72 GB peak) for MVP8B §1.4's transient list.

LANE WW SUMMARY (rungs 0-4 landed 2026-09-02; commits 26990ea,
03c0a49, 5d3ca82, + the rung-2b/3/4 commit): the batched transport is
the Stage-A default (identity c0b8236f.. / 1644b4e1.. / e0b3b985..;
gg opt-in); the cold-descent-kernels cause found and fixed (a
zc/k9/ixf VRAM-residency interaction + a k9 make_room-mid-loop bug;
ADDITIVE fixes in zc_agg.rs / k9.rs / the driver; every frozen digest
unchanged); the 12x512 reference shape runs on the 15 GB box in BOTH
Stage-A modes at 7.15 GB (range, byte-identical) and 7.16 GB (full;
was OOM at 15.18 GB); the honest 12x512 A/B is on record (Stage-A
range at prove parity, 1.15-1.18x total, 2.25x fewer bytes; full 4x
the prove for 1.68x fewer bytes at the same memory); the 8B full-mode
row is ~85 GB [MODEL] with the dense-row undercount corrected.
Files: ring_matmul.rs (the uperf-a driver: the transport default, the
residency release, the diet, the compact/combined act-h claims, the
RSS lines), gpu/zc_agg.rs (+ `zc_agg_release`), gpu/k9.rs (+ the
room-once guard in `ixf_round`, + `k9_trim_idle`), gpu/mod.rs (the
two exports + two stub twins), results/uperf3_ww_*. NOT touched:
stage_a.rs, stage_a_full.rs, zc_range.rs, eval_proof.rs, two_tier.rs,
the frozen pass, manifest.rs.
ORCHESTRATOR-RUN: none posted — every run fit under 8 minutes.

(lane appends below)

## Orchestrator note 2026-09-02 — round 11: UU merged (fast-forward 0f51720)

- `hashline/` builds in this checkout (13.25 s) and its 19 unit
  tests pass. No zkmatrix-rs file changed; the lattice floors are
  unaffected (not re-run for this merge). PROVING_CHANNEL_OPTIONS.md
  carries the orchestrator's "in build" paragraph AND UU's "row
  LANDED" paragraph (both kept; the second supersedes).
- THE ROW, restated for the record [MEASURED, WSL-BOX 8T CPU-ONLY
  NOISY-SHARED, same digest-identical 2.899e10-MAC statement]:
  prove 23.0 s p50 (21.48 / 22.92 / 23.07 / 23.69), verify 2.8 s,
  66,844,928 B, 1.56 GB, 1.26e9 proven MAC/s; 16T 32.2 s, 22T 37-39 s
  (inverted scaling, not chased). Per-phase at 8T: commit W 2.19 |
  commit A 3.98 | helpers + commit H 4.58 | matmul g/u 0.77 | matmul d
  0.60 | zero-check-20 4.50 | zero-check-17 2.30 | PCS openings 3.96 s.
- READING: one untuned lane-day of the hash-based line reaches parity
  with the lattice line's GPU-assisted reference on the CPU alone.
  The proof-system difference PROVING_CHANNEL_OPTIONS §2 predicted is
  real at 125M; the vendor claim's ~1,000x is NOT reproduced at this
  scale on this box (and the row is not ZK). Two follow-on lanes
  opened below: XX (the GPU port; the measured wall) and YY (the
  Route-B tokens/s model incl. the ZK surcharge and the proof-size
  lever). Lanes VV and WW continue.

### Lane XX — hashline on the GPU (wt-uperf3-xx) — RUST/CUDA (round 11 addendum)
OWNS: hashline/ (NEW src/gpu/*, a `gpu-cuda` cargo feature, the
device toggle env `HL_GPU=1`), NEW results/hashline_gpu_*, the GPU
row in PROVING_CHANNEL_OPTIONS.md §3, "Agent XX status". READ-ONLY:
zkmatrix-rs/ (copy its cudarc + NVRTC bootstrap pattern from
src/ring/gpu/cuda.rs — feature gate, `include_str!` kernel source,
FUNCS list, init, a probe; do not link to it), everything else.
WHY: UU's phase shares (commitments 47% = row Reed-Solomon NTTs +
blake3 Merkle; zero-check sumchecks 30%; PCS openings 17% = the
row-combination + column decommitments; matmul sumchecks 6%) are all
device-native, memory-bound work; UU's [MODEL] for the RTX 4070 is
1.5-2.5 s per 12x512 pass vs 23.0 s CPU. This lane measures it.
RUNGS (prefix "U-PERF3 XX:"): 0 skeleton (feature, cudarc/NVRTC
bootstrap, device init + a Goldilocks mul/reduce probe vs the CPU
field, the toggle; CPU build and proofs byte-identical with the
feature off); 1 the batched row NTT on the device (the RS encoding
of the commit phase) — the Merkle roots and hence the proof bytes
IDENTICAL to CPU at 3x16 and 12x512; 2 blake3 Merkle on the device
(or leave hashing on the CPU if rung 1 already moved the wall —
measure and decide); 3 the sumcheck round sums (zero-checks, LogUp,
matmul) on the device; 4 the PCS opening's row-combination on the
device; 5 the 12x512 pass measured: proof bytes identical CPU vs
GPU, prove/verify walls at 8T + GPU, RSS, VRAM held, proven MAC/s
-> the GPU row in §3 and a results page in lane TT's form. ACCEPT:
byte-identical proofs (the transcript is deterministic) + the
measured wall, whatever it is.

### Lane YY — the Route-B throughput model (docs only) (wt-uperf3-yy) — DESIGN (round 11 addendum)
OWNS: NEW docs/zkmatrix-poc/U_PERF3_ROUTE_B_THROUGHPUT.md, one
pointer line in PROVING_CHANNEL_OPTIONS.md §3, "Agent YY status". No
code, no builds, no runs.
GOAL: lane TT's seven items (U_PERF3_THROUGHPUT_MODEL.md's structure
and labels, same yardstick) for the hash-based line, from UU's
MEASURED shares and sizes: (1) the workloads (batch-1 decode, T=512
prefill, pipelined) and MACs/token at 8B and 30B (reuse TT's shapes);
(2) the per-proof cost anatomy split PER-MODEL (the weight
commitments: 2.19 s of the 23.0 s at 12x512 per UU; what else is
alpha-independent) vs PER-PROOF (the weight PCS opening is per-proof
and LINEAR in the weight count — count its field operations and
bytes moved at 8B/30B; the activation-side commitments, sumchecks
and openings — scale each from UU's per-phase seconds by the counted
sizes, showing the arithmetic); (3) the hardware factor for THIS
mix (NTT + hashing + reductions, memory-bound) laptop -> one desktop
board -> one H100, as a range with reasoning; (4) THE ZK SURCHARGE
[MODEL] — Victor's rule ("Zero Knowledge is nonnegotiable") means the
row must carry it: the named techniques (Ligero/Brakedown masking
rows; zero-knowledge sumcheck via masking polynomials — cite the
literature classes) and their counted cost in prover time, proof
bytes and verifier time; (5) THE PROOF-SIZE LEVER: 66.8 MB is the
sqrt-size Ligero class; the FRI / STIR / WHIR-class multilinear PCS
swap — bytes vs prover-time trade, counted; (6) the honest tokens/s
table for Route B x {laptop CPU, laptop GPU [MODEL until XX], one
desktop board, one H100} x {decode, T=512 prefill} at 8B and 30B,
next to lane TT's lattice table; (7) the competitor row and what a
50 tok/s Route-B design MUST have (the per-token budget; which
measurement — lane XX's — replaces which constant; the unknowns).
Plain language, every number labelled and sourced, "What is not
known" at the end.

## Agent XX status (wt-uperf3-xx) — round 11

(lane appends below)

**RUNG 0 — SKELETON + THE DEVICE FIELD PROBE: GREEN (2026-09-02,
WSL-BOX, RTX 4070 Laptop sm_89 36 SMs, NOISY-SHARED: another lane's
job held ~6 GB while this ran).** `hashline/` gains a `gpu-cuda` cargo
feature (cudarc 0.13.9, the same driver+NVRTC toolchain and features
zkmatrix-rs uses; default OFF), `src/gpu/{mod.rs,cuda.rs,kernels.cu}`
in zkmatrix-rs's bootstrap pattern (device singleton, `include_str!`
kernel source compiled once by NVRTC, FUNCS list, `HL_GPU=1` runtime
toggle, `HL_GPU_VERBOSE=1`), and a device Goldilocks probe. Build:
`CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
CARGO_TARGET_DIR=/home/victor/wt-uperf3-xx/hashline/target-gpu flock
/tmp/zk-build.lock cargo build --release --features gpu-cuda
--manifest-path /home/victor/wt-uperf3-xx/hashline/Cargo.toml` (19 s;
the CPU build in `target/` is untouched by the feature). Run:
`HL_GPU=1 LD_LIBRARY_PATH=<as above> hashline/target-gpu/release/hashline
gpu-probe`: **NVRTC compile 0.39 s; 2^20 canonical pairs (the 81 edge
pairs of {0, 1, p-1, p-2, 2^32-1, 2^32, 2^63, p-(2^32-1), 2^64-2^32}
first, then xorshift) — mul / add / sub mismatches 0 vs field.rs**
(the reduction is the CPU's reduce128 with the same borrow/carry
adjustments; 4.9 G mul/s on the naive 3-op probe kernel, memory-bound,
not a ceiling) [MEASURED]. Byte-identity gate added for every rung:
`LayerProof::to_bytes()` (the flat LE encoding `size_bytes` counted
— asserted equal), `--proof-out PATH`, and a `PROOF sha256` line in
`pass`. CPU path unchanged: 19/19 unit tests green (CPU build); the
3x16 pass gives sha256 596b9c79f086d6f1.. (7,365,588 B) from BOTH the
CPU-only binary and the gpu-cuda binary with HL_GPU unset (the
feature-on build without the toggle is the CPU prover). THE CPU
REFERENCE at 12x512 for this lane (CPU-only binary, `flock
/tmp/zk-heavy.lock /usr/bin/time -v hashline pass 12 512 --threads 8
--proof-out ...`): **PROOF sha256
50cf7bdfd6b5b182f9c029c3d62087ca9e0e273be218d017609323c15146a17d
(66,844,928 B); PROVE 21.60 s, VERIFY 2.85 s, RSS 1.56 GB; phases
commit W 2.13 | commit A 3.76 | helpers + commit H 4.38 | matmul g/u
0.73 | matmul d 0.57 | zero-check 20 4.13 | zero-check 17 2.15 | PCS
openings 3.71 s** [MEASURED, WSL-BOX 8T CPU NOISY-SHARED] — UU's row
reproduced within its 21.5-23.7 s spread. Commit 7352e3d.

**RUNG 1 — THE BATCHED ROW NTT ON THE DEVICE: GREEN, BYTE-IDENTICAL
(2026-09-02, WSL-BOX 8T + RTX 4070 Laptop, NOISY-SHARED).** Kernels
`k_ntt_p1` (the first 12 radix-2 DIT stages of a row on a 4096-element
shared-memory block, the bit-reversed gather done on the load with
positions >= n_src read as zero = the RS zero padding never
materialized) and `k_ntt_p2` (the remaining log_n - 12 stages on a
[2^(log_n-12)] x [J] tile, closed under those stages since the
partner of x = t*4096 + j differs only in t); the CPU's own twiddle
tables (`NttTables::twiddle_tables()`, indexed tw[k * max_n/len]
exactly as ntt.rs) uploaded once; the 1/n scale on the last store.
`pcs::commit` dispatches to `gpu::dev_commit` when `HL_GPU=1` (Err ->
the CPU body): data H2D, inverse NTT (2^14) into a coefficient
buffer, forward NTT (2^16) into the device-resident encoded matrix;
the commitment becomes `pcs::Store::Device` and the opening's 256
columns come from a gather kernel (`k_gather_cols`). Rung 1 still
hashes on the HOST (the encoded matrix copied back) so the hashing
question is measured in rung 2. Checks: `gpu-probe` now also encodes
random rows at (log_cols, inv_rate, rows) = (4,4,3) (10,4,5) (12,4,7)
(14,4,5) (14,4,64) (13,2,4) (12,8,3) — **0 mismatches** against the
CPU encoder element for element, and the gathered columns match. THE
GATE: `HL_GPU=1 hashline pass 3 16 --threads 8` -> **PROOF sha256
596b9c79f086d6f1.. = the CPU's**; `HL_GPU=1 flock /tmp/zk-heavy.lock
/usr/bin/time -v hashline pass 12 512 --threads 8` -> **PROOF sha256
50cf7bdfd6b5b182.. = the CPU's (66,844,928 B), PASS ACCEPT**.
Walls at 12x512 [MEASURED, WSL-BOX 8T GPU NOISY-SHARED]: **PROVE
19.33 s (CPU ref 21.60), VERIFY 2.73 s, RSS 1.44 GB, VRAM peak 2.16
GB**; commit W 1.65 / commit A 3.07 / helpers + commit H 3.82 s (CPU:
2.13 / 3.76 / 4.38); device-side sums: H2D 0.51 s for 1.95 GB (3.9
GB/s pageable), NTT 1.19 s (36 commitments, ~33 ms each — ~8 G
butterflies/s, well under the part's arithmetic ceiling: the
twiddle reads in p1 are strided (tw[k*stride]) and the u64 shared
butterflies bank-conflict; a stage-major twiddle table is rung 2's
first fix), host hashing 1.02 s, **D2H 3.17 s for 7.83 GB** (the
encoded matrices copied back for the host hash at 2.5 GB/s — the
commit phase is now transfer-bound, which is exactly the rung-2
question: hashing on the device removes the 7.8 GB entirely). Commit
7ed56cf.

**RUNG 2 — blake3 MERKLE LEAVES ON THE DEVICE: GREEN, BYTE-IDENTICAL;
DECISION: hash on the device (2026-09-02, WSL-BOX 8T + RTX 4070
Laptop, NOISY-SHARED).** `k_hash_cols`: one thread per column runs the
reference blake3 (7-round compression, 1024-byte chunks with
CHUNK_START/END, the lazy CV-stack merge to popcount(chunk index)
before each push, the root roll-up with ROOT on the last compression)
over the column's little-endian u64 bytes read straight from the
device-resident encoded matrix (coalesced across the warp); only the
2^16 x 32 B leaves come back and the host builds the Merkle levels as
before (`MerkleTree::build`, ~2 ms; not worth a kernel). Check:
`gpu-probe` hashes 64 random columns at 322 row counts (1..300 and
432, 520, 511-513, 640, 767-769, 1023-1025, 1500, 2047-2049, 3000,
4095-4097, 8191, 8192 — every chunk-tree shape up to 64 KB) against
`blake3::hash`: **0 failing**. Also the NTT twiddle table became
stage-major (stage s owns tw_cpu[k << (max_log - s)] contiguous;
same values, coalesced reads). Gates: 3x16 sha256 596b9c79.. and
12x512 sha256 50cf7bdf.. — IDENTICAL. The A/B that decides the rung
[MEASURED at 12x512, 8T GPU NOISY-SHARED]: host hashing (rung 1's
form, kept behind `HL_GPU_HOST_HASH=1`): D2H 3.17 s for 7.83 GB +
host hash 1.02 s; device hashing: 0.30 s device time, D2H 0.106 GB
per pass -> commit W 0.83 / A 1.57 / H 2.54 s (CPU 2.13 / 3.76 /
4.38; rung 1 1.65 / 3.07 / 3.82). **PROVE 16.22 s** (CPU ref 21.60),
verify 3.06 s, RSS 1.24 GB, VRAM 2.16 GB. Device-side sums: H2D 0.60
s / 1.95 GB, NTT 1.41 s, hash 0.30 s. The commit phase's remaining
~4.9 s is now mostly HOST work (the Fp conversions of the witness
planes, the LogUp helper columns' batch inversions ~1.3 s, the
68/57/37 MB host copies) — moved in the follow-on items below.

**RUNG 3 — THE ZERO-CHECK SUMCHECKS ON THE DEVICE: GREEN,
BYTE-IDENTICAL (2026-09-02, WSL-BOX 8T + RTX 4070 Laptop,
NOISY-SHARED).** `gpu::dev_zerocheck(kind, specs, prm, tr)`: the 13
(zc20) / 15 (zc17) tables are BUILT ON THE DEVICE — base-field slices
of the resident A commitment data (`k_tab_from_fp`), (re, im) slice
pairs of the resident H data (`k_tab_from_fp2`), and the eq tables of
the challenge points (`k_eq_table`, the per-bit factor product, MSB
convention as `mle::eq_table_msb`) — no table upload at all; the
round loop stays on the host with the transcript: `k_sc_round_zc20 /
_zc17` (templated on the table count so cur/dif live in registers;
the parameters staged in shared memory; the CPU's incremental cur =
v0 + d*dif evaluation at d = 0..4; block partials) -> `k_reduce_f2`
-> 5 Fp2 back -> absorb -> challenge -> `k_sc_fold`; finals from the
folded tables. layer.rs branches when A and H are device stores
(`Transcript::clone_state` lets a declined attempt fall back to the
CPU body untouched); the polynomials mirror the Rust closures term
for term. Gates: 3x16 596b9c79.. and 12x512 50cf7bdf.. IDENTICAL.
Bug found on the way: the first version copied the whole 218 MB table
buffer back to read the 13 finals (0.13 s per layer); fixed to 13
16-byte reads. Per layer at T = 512 [MEASURED, HL_GPU_VERBOSE]: zc20
(2^20 x 13) tables 0.021 s | rounds 0.020 s | folds 0.004 s | syncs
0.002 s = **0.047 s** (CPU 0.34 s); zc17 (2^17 x 15) **0.013 s** (CPU
0.18 s). At 12x512: **zero-check 20 0.71 s (CPU 4.13), zero-check 17
0.17 s (CPU 2.15)**; PROVE 13.52 s in a run where another lane loaded
the CPU (the untouched host phases — openings 5.54 s, matmul 1.04 /
0.81 s, verify 4.34 s — all ran 1.4-1.5x slower than in the rung-2 run;
NOISY-SHARED, rung 5's p50 is the number). The matmul sumchecks stay
on the host BY DESIGN: their tables are 2^8 (g/u, 6 tables) and 2^11
(d, 2 tables) entries — the matmul phases' cost is the FOLDS
(fold_rows/cols over X, Wg, Wu, h8, Wd: GEMV-class, 1.3 s per pass),
which rung 4's kernel class covers. The LogUp is inside the two
zero-checks (the helper identity) and its helper-sum functionals.

**RUNG 4 — THE PCS OPENING'S ROW-COMBINATION ON THE DEVICE + THE
HOST-SIDE FINDING: GREEN, BYTE-IDENTICAL (2026-09-02, WSL-BOX 8T +
RTX 4070 Laptop, NOISY-SHARED).** `k_fold_rows` (one thread per
column, up to 4 row-weight vectors at once — the 2-3 claim groups +
the proximity rho — over the device-resident systematic data;
warp-uniform rho reads) behind `gpu::dev_fold_rows`; `pcs::open`
dispatches on the store; the DevCommit's host data copy is gone
(saved a 37/68/57 MB clone per commitment). Gates: 3x16 596b9c79..
and 12x512 50cf7bdf.. IDENTICAL; the fold itself 0.16-0.23 s per
pass (36 combinations; CPU ~1.1 s). THE FINDING while profiling
`pcs::open` (`HL_TIMING=1`): `group_claims` cost 0.26 s per layer —
`mle::eq_table` opened a rayon parallel region per doubling step,
and the 37 claims x 2 eq tables x up to 14 steps per layer paid ~0.3
ms of pool wake-up each; the same code runs in the VERIFIER. Fix
(same values, one `if len < 4096 { sequential }`): group_claims 0.26
-> 0.03 s per layer. Because that is CPU-path code, the CPU
reference moves too and is re-measured here so the comparison stays
apples to apples: **CPU-only binary, this tree, 12x512 8T: PROVE
17.36 s (was 21.60), VERIFY 0.73 s (was 2.85), sha256 50cf7bdf..
unchanged**; phases commit W 1.98 | A 3.64 | H 4.18 | matmul 0.37 /
0.22 | zc20 3.76 | zc17 1.75 | openings 1.43 s [MEASURED,
NOISY-SHARED]. (UU's 23.0 s row stands as the round-11 record of the
untuned prototype; the 17.4 s is the same prover after this fix.)
GPU, after rungs 1-4 [MEASURED, 12x512, 8T + GPU, alone on the
device — a concurrent 3x16 run on the same GPU had polluted an
earlier attempt 3x, noted]: **PROVE 4.88 s, VERIFY 0.44 s, RSS 1.08
GB, VRAM peak 2.40 GB**; commit W 0.45 | commit A 0.84 | helpers +
commit H 1.75 | matmul g/u 0.34 | matmul d 0.19 | zero-check 20 0.56
| zero-check 17 0.12 | PCS openings 0.58 s; device-side sums: H2D
0.35 s / 1.95 GB, NTT 0.84 s, hash 0.11 s, sumcheck 0.64 s, fold 0.16
s. What is left is HOST work around the device: the LogUp helper
columns (batch inversions + the Fp2 tables, ~1.4 s per pass), the
witness-plane -> Fp conversions and the H2D of W/A (~0.6 s), the
eq-table builds (0.25 s) and the matmul folds (0.3 s). Next: the
helper columns on the device from the resident A data (the H
commitment then encodes a device buffer with no upload), then rung
5's measurement. Commit 15e480f.

**RUNGS 4b-4d — THE HOST REMAINDER MOVED, THE POOL, THE GATHER-FREE
ENCODE: GREEN, BYTE-IDENTICAL (2026-09-02, WSL-BOX 8T + RTX 4070
Laptop, NOISY-SHARED).** (4b) The LogUp helper columns on the device:
`k_helper` computes h = 1/(alpha - l1) + 1/(alpha - l2) from the
resident A data (l1 = v1 + beta w + c1, l2 = v2 + c2) straight into a
device H buffer — Montgomery's trick over 8-element thread chunks
with one Fermat inversion (inverses are unique, so the values equal
`batch_inverse2`'s); the H commitment encodes that buffer with no
upload (`dev_commit_from`); the helper sums come from `k_sum_fp`
block reductions. The host Fp2 tables (g8f..rhf, lg.., hg/hu/hh,
zf/rdf/hz) are never built on the device path (`HostTabs` is an
Option; a device zero-check that declines after device helpers is a
hard error, not a silent divergence). First attempt failed to launch
(CUDA_ERROR_LAUNCH_OUT_OF_RESOURCES: 16-element chunks x 1024-thread
blocks exceeded the register file) and the CPU fallback took over
with identical bytes — the Err-discipline works; fixed at 8 x 128.
(4c) `eval_many` on the device (`k_dot_slices` against a device eq
table), eq tables by the two-half join (`k_eq_join`: eq factorizes
over the variable split — one f2_mul per entry instead of 20), and
`pcs::group_claims` builds the 2^14 column-weight table once per
group instead of once per claim (37 claims/layer -> 3-5 groups; also
the verifier's; 0.26 -> 0.005 s per layer). (4d) THE FIRST-TOUCH
FINDING: a freshly cuMemAlloc'd buffer pays ~12 ms per 68 MB on its
first write on this box (measured by encoding the same rows twice:
inverse NTT 15.2 -> 2.9 ms, zc20 table build 13.4 -> 3.0 ms on the
second pass) — so a device buffer POOL reuses buffers by exact length
across commitments and layers (`Pooled`, returned on drop). Also the
encode became gather-free — the inverse as a DIF NTT (natural in,
bit-reversed out: `k_dif_pa` strided tile stages, `k_dif_pb`
contiguous) and the forward as a DIT from the bit-reversed,
zero-padded coefficients (`k_dit_p1_pad`: DIT position m R reads
coef-buffer[m], the rest are zeros — a contiguous load); it turned
out the gather was NOT the cost (the first-touch was), but the form
is cleaner and stays (`HL_GPU_GATHER_NTT=1` keeps rung 1's). Every
step: `gpu-probe` NTT/blake3 checks GREEN, 3x16 sha 596b9c79.. and
12x512 sha 50cf7bdf.. IDENTICAL. Commits 3bd5a85 (4b/4c), 0e5a2eb
(4d).

**RUNG 5 — THE 12x512 PASS MEASURED: THE GPU ROW (2026-09-02, WSL-BOX
8T + RTX 4070 Laptop, NOISY-SHARED, alone on the device, `flock
/tmp/zk-heavy.lock`, 4 runs).** `HL_GPU=1 /usr/bin/time -v
hashline/target-gpu/release/hashline pass 12 512 --threads 8
--proof-out <file>`: **PROVE 3.43 / 3.38 / 3.38 / 3.49 s -> p50 3.40
s; VERIFY 0.41-0.44 s; proof 66,844,928 B; peak RSS 775 MB; VRAM peak
2.43 GB (cuMemGetInfo, incl. the driver context); 8.5e9 proven MAC/s
(8.3-8.6e9)** [MEASURED]. **BYTE-IDENTITY: `sha256sum` of the four
written GPU proofs and of the CPU-only binary's proof all equal
50cf7bdfd6b5b182f9c029c3d62087ca9e0e273be218d017609323c15146a17d**;
the 3x16 gate 596b9c79.. both ways. Per-phase (run 2, CPU-this-tree
run 1 / UU's row in parentheses): commit W 0.43 (1.98 / 2.19) | commit
A 0.95 (3.64 / 3.98) | helpers + commit H 0.50 (4.18 / 4.58) | matmul
g/u 0.39 (0.37 / 0.77) | matmul d 0.27 (0.22 / 0.60) | zero-check 20
0.35 (3.76 / 4.50) | zero-check 17 0.10 (1.75 / 2.30) | PCS openings
0.35 (1.43 / 3.96) s. Device-side sums (run 2): H2D 0.25 s / 1.27 GB,
NTT 0.43 s, blake3 leaves 0.12 s, zero-checks 0.45 s, row-combinations
+ eval_many 0.17 s, helpers 0.10 s, D2H 0.14 GB. The CPU reference in
THIS tree (CPU-only binary, 3 runs, load 2-7): PROVE 17.36 / 20.38 /
20.90 s (p50 20.4), VERIFY 0.33-0.73 s, RSS 1.56 GB, same sha256.
Tamper legs THROUGH THE GPU PROVER: `HL_GPU=1 hashline layer 0 512
--all-tampers --threads 8` -> flipped X / flipped Wg / wrong requant /
wrong z REJECT at "sumcheck round 0: s(0) + s(1) != claim",
out-of-range remainder / wrong table entry REJECT at "LogUp identity
fails" — the same seven sites as the CPU prover's; `HL_GPU=1 pass 12
512 --tamper requant` -> "layer 6: REJECT: sumcheck round 0" (that
pass proved its 12 layers in 2.75 s with the box momentarily quieter —
the fastest prove seen; not in the p50, it bounds the noise penalty at
~20%). THE VERDICT AGAINST UU's [MODEL] 1.5-2.5 s: MISSED, at 3.4 s
(1.4-2.3x over the band's ends), and the attribution is measured, not
guessed: ~1.5 s of the 3.4 s is device time (the NTT at ~34 G
butterflies/s is far under the part's arithmetic ceiling; the
zero-checks 0.45 s; H2D 0.25 s pageable), ~1.9 s is host work the
estimate did not count — the witness planes to field elements and
their upload (~0.35 s), the matmul folds + the 2^8/2^11 sumchecks
(~0.5 s), the Merkle levels (36 x 2^16 leaves), the transcript and
claim bookkeeping, serialization, the per-round syncs. All of it has
byte-preserving fixes (upload the i8/i32 planes and convert on the
device, the folds on the device, pinned staging, a radix-4 /
conflict-free NTT); none applied. Against the lattice line on the
same device: 8.5e9 vs 1.4e9 proven MAC/s (6.1x), 3.4 s vs 18.0 s
commit+prove, 0.78 GB + 2.43 GB VRAM vs 6.7 GB, 66.8 MB vs 1.5 MB
proofs, no ZK vs ZK. THE ROW is in docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md
§3 (next to UU's, same columns, same caveats, plus the CPU-this-tree
row) with a status paragraph; the full record is
results/hashline_gpu_12x512.md; hashline/README.md carries the GPU
build/run recipe.

**WHERE THIS LANE STOPPED.** Rungs 0-5 green, recorded, committed;
the byte-identity gate held at every rung. Open items, none blocking
the row: (a) the ~1.9 s host remainder listed above (the largest:
plane -> Fp conversion + 1.27 GB pageable H2D per pass; the matmul
folds); (b) the NTT kernels (shared-memory bank conflicts on u64,
radix-2, 256 threads — 2-4x available [MODEL]); (c) the CPU verifier
is unchanged in structure (0.3-0.7 s; its RS re-encodes of the 10
clear vectors per layer and the 256 column checks could take the
device too); (d) `layer` (unlike `pass`) starts the device inside its
prove clock (the NVRTC compile ~0.5-0.8 s shows in single-layer
timings; `pass` initializes before the clock); (e) everything UU
listed (ZK masking, proof size, per-model W preprocessing — commit W
is 0.43 s of the 3.4 s here — X/W range lookups, LogUp-GKR). No
ORCHESTRATOR-RUN posted: every run fit under 8 minutes.

## Agent YY status (wt-uperf3-yy) — round 11

(lane appends below)

**LANE COMPLETE (2026-09-02, docs only; no code, no builds, no
runs).** Deliverable: NEW `docs/zkmatrix-poc/U_PERF3_ROUTE_B_THROUGHPUT.md`
— lane TT's seven items for the hash-based line on the same
yardstick (S0 = TT's memo; workloads, shapes, MACs per token copied
verbatim), every number labelled [MEASURED] / [COUNTED] / [MODEL] /
[EXTERNAL] with a source; plus one pointer line in
PROVING_CHANNEL_OPTIONS.md §3 (after the B row's caveats). Commits:
d37d5f6 skeleton; 52f3e07 §0 + §1; 329e56c §2; 7982586 §3; ecf4b65
§4; 74c37bd §5; f4a1fc3 §6; 414c84f §7 + What is not known; the
pointer line and this status block in the closing commit. Not
pushed.

**THE ANSWER (§0).** From UU's measured 12x512 row (23.0 s prove,
8T CPU, 22 proven tokens/s of the 125M model) and the loops in
`hashline/src/*.rs`: per-model 2.19 s (9.6%, commit W); per-proof
weight side 1.52 s (6.6%: 4.33 extension-by-int8 multiply-adds per
weight — 4/3 in the matmul folds, 3 in the Ligero opening — LINEAR
in the weight count); activation side 19.17 s (83.8%, 102 ns per
committed element; 13 f + 5 d elements per token-layer). Scaled by
counted sizes to the laptop CPU: 8B x 512 = 151 + 341 = **492 s
(1.0 tok/s)**, 8B decode ~152 s (0.007 tok/s); 30B x 512 = 576 + 970
= **1,546 s (0.33 tok/s)**, 30B decode ~578 s [MODEL from MEASURED].
Hardware factor for THIS mix (NTT + blake3 + sumcheck reductions +
GEMV streaming; all device-native, no host-bound share): laptop CPU
-> laptop GPU 5-15x [MODEL until XX], -> 4090 15-75x, -> H100
25-180x [MODEL on MODEL]; the 8T/16T/22T inversion is a hybrid-part
artefact (E-cores + power limit + static chunking) that does not
transfer to a GPU. **Tokens/s (§6): Route B on one H100, P0 (no
ZK), FFN-only: 30B prefill 8.3-60 tok/s, 30B decode 0.04-0.3; 8B
prefill 26-187, 8B decode 0.16-1.2** — vs the lattice line's best
modelled 30B-prefill cell 2.3-15 (S0). Counted spec-sheet floors on
the H100: 30B prefill 3.7-11 s per proof (47-138 tok/s; hashing 311
GB of encoded activations at 30-100 GB/s is the term), 30B decode
30-80 ms (12-33 tok/s; the linear weight opening alone is 25-60 ms:
6.4 ms of HBM reads + 18-36 ms of arithmetic + 7 ms of cache
columns).

**THE ZK SURCHARGE (§4, Victor's rule).** Constructions: Ligero-ZK
randomised rows (+Q pad symbols, Q 256 -> 296 with non-systematic
sampling — as built 1 in 4 opened columns is a RAW column) + mask
rows; CFS/Libra masking polynomials for the four sumchecks (<= 81
coefficients each); masked claims; committed multiplicities (the
histograms are in the clear today — the lattice line's C-01 leak);
salted leaves. Cost as fractions of UU's phases: **P1 (activations
private): +2-8% prover, +1-8% bytes, +2-15% verifier** [COUNTED
from the constructions]. **THE FINDING: a cached hash-based weight
commitment cannot be zero-knowledge across proofs — each proof
reveals 256 encoded columns, and after (n + Q)/Q = 65 proofs (40-80
for any RS parameters at 2^-106) the weights are recoverable by
linear algebra from the published proofs.** So P2/P3 (weights
private) must re-commit W with fresh randomness EVERY proof: +9.6%
at 125M, +44% at 8B x 512, +54% at 30B x 512, +143% at decode; on an
H100 the re-commit's hashing floor is 1.8-6 s (8B) / **7-23 s (30B)
per proof — 70-230% of the 10.2 s budget by itself**. On Route B the
cheap partial-knowledge mode is P1 (open weights, private inputs)
and the expensive one is P2 (proprietary weights) — the reverse of
the lattice line, where the MLWE commitment is hiding and
re-openable with a sqrt-class mask. Uncounted ways out: Orion-class
hidden columns (an inner proof of ~1e9 constraints per proof at
30B); a hiding lattice commitment for the weights with a ZK link
(the A + B hybrid).

**THE PROOF-SIZE LEVER (§5).** 66.8 MB is the sqrt class; the
as-built n = 2^14 is within 2% of the per-commitment optimum, so no
parameter lever exists. At the optimum: 613 MB per 8B x 512 proof,
1.51 GB per 30B x 512 proof, and **282 / 736 MB per DECODE token**
(the W opening's bytes do not shrink with T); verifier ~3-5 s (8B)
/ 8-12 s (30B) at 8T vs the <= 2 s line [MODEL]. Batched-evaluation
+ one merged commitment: −50-56% bytes at +5-15% time. WHIR/STIR-
class PCS swap: 3-12 MB per 8B/30B pass (−100-250x), 3-12 MB per
decode token, ms verify, at x0.94-1.4 prover [MODEL from stated
complexities: half the hashed bytes at rate 1/2, a larger NTT, an
N-sized sumcheck opening]; FRI 2-3x larger; Goldilocks has 2-adicity
32, so the lattice review's two-adicity wall does not exist here.
The swap changes neither the weight opening's linearity nor the
§4.4 leak.

**THE §7 VERDICT.** The competitor's claimed 1.6e12 proven MAC/s
(53 tok/s, batch 1, one H100 [EXTERNAL]) is INSIDE Route B's counted
FFN-only prefill floor band (1.0-3.0e12) — consistent with a
hash-based prover at the spec-sheet floor, batched — and 1.5-4x
above the counted batch-1 floor of a LINEAR weight opening on the
same board. Budget: at 30B the per-proof weight opening is **25-60
ms against a 20 ms batch-1 budget (NOT affordable; the arithmetic,
not the bytes, is the larger part)** and 0.3-0.6% of the 10.2 s
prefill budget (affordable). Batching table at the floor: B = 1
12-31 tok/s, B = 4 28-77, B = 8 36-100, B = 512 47-138: **50 tok/s at
30B needs B >= 4-16 requests per proof AND a device hash rate >= ~50
GB/s.** Requirements R1-R6 stated; R6 (ZK) is a product ruling that
changes the answer by >= 2x. **Verdict: 50 tok/s at 30B on one H100
is reachable on Route B under the counted assumptions ONLY for
prefill / batched proving, FFN-only, in modes P0/P1, and only in the
upper half of the hardware range (>= ~90x over the CPU row as built)
— it hinges on lane XX's port factor and the device hash rate.
Batch-1 decode at 50 tok/s is not reachable under any counted
assumption. Under P2/P3 no counted cell reaches 50 tok/s.**

**WHICH MEASUREMENT REPLACES WHICH CONSTANT (§7.4).** Lane XX rung 5
-> the laptop-GPU column [MEASURED]; XX rung 2 -> the device hash
rate (the dominant floor term); XX rung 4 -> the row-combination /
the decode row; a ZK spike (Ligero-ZK pads + mask rows + Libra masks
+ committed multiplicities on hashline at 12x512) -> §4.3
[MEASURED]; a PCS spike (a WHIR/STIR-class pcs.rs behind a switch)
-> §5; an 8B-shape layer of hashline on the Mac at T = 16/64/512 ->
the 8B constants (and the zero-check-17 3.5x anomaly); choice C ->
every device column. 14 unknowns listed at the end of the memo.

**Asks of the orchestrator's files (not in this lane's ownership):**
START_HERE.md §2's "Its GPU port and its own tokens-per-second model
are round 11's follow-on lanes" can now cite the memo; TASK_BOARD.md
§0 may carry the one-line verdict above.

## Orchestrator note 2026-09-02 — round 11: YY merged (fast-forward 3c4dc8a)

- U_PERF3_ROUTE_B_THROUGHPUT.md landed (1,096 lines; docs only; no
  floors affected). Verdict recorded in START_HERE.md §2 and the
  board §0: 50 tok/s at 30B on one H100 is reachable on Route B only
  for batched/prefill proving, FFN-only, in P0/P1, in the upper half
  of the hardware range, hinging on lane XX's port factor and the
  device hash rate; batch-1 decode not reachable on either line;
  P2/P3 (weights private) reaches no counted cell because a cached
  hash commitment leaks its columns across proofs (§4.4: recoverable
  after ~65 proofs) — the weights must be re-committed per proof
  (7-23 s hashing floor at 30B on an H100) unless an uncounted
  design is built (Orion-class hidden columns; the lattice-hybrid
  weight commitment = PROVING_CHANNEL_OPTIONS §3's "A + B" row made
  concrete).
- THE RULING THIS RAISES (put to Victor): the product's privacy
  mode. P1 (open weights, private inputs) is the cheap mode on Route
  B (+2-8%) and the natural one for open-weight checkpoints; P2/P3
  needs the weight-privacy design priced. Lane ZZ (docs only) opened
  below to price options 2 and 3 of §4.4 so the ruling is made with
  numbers.

### Lane ZZ — weight privacy on Route B, priced (docs only) (wt-uperf3-zz) — DESIGN (round 11 addendum 2)
OWNS: NEW docs/zkmatrix-poc/U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md; one
pointer line in U_PERF3_ROUTE_B_THROUGHPUT.md §4.4 (after option 3);
"Agent ZZ status". No code, no builds, no runs.
GOAL: count, on lane YY's yardstick and shapes, the three ways a
hash-line proof can keep the WEIGHTS private across many proofs:
(1) re-commit per proof (YY's counted baseline — restate it, and
count the batching amortization: at B requests per proof the
re-commit is paid once per B tokens x T); (2) Orion-class
hidden-column openings (ePrint 2022/1010 and its successors): the
inner statement's exact size at 8B/30B (YY counted ~1e9 constraints
at 30B — verify), which inner prover (a small-field sumcheck/GKR
over an arithmetic hash such as Poseidon2 — the hash swap's cost on
the OUTER commit phase too), the prover time as a fraction of the
P0 row [MODEL with named constants], the proof bytes, the verifier;
(3) the lattice-hybrid weight commitment: the lattice line's hiding
MLWE commitment for W (cached per model — the built weight group;
per-proof opening = lane QQ's MEASURED 2.08 s at the 12x512 weight
group on the 4070, [MODEL] 62-75 s at 8B and 280-340 s at 30B in
the design of record, 14-27 s / 65-125 s with Variant B — lane VV
is measuring), the hash channel for the activations, and the
cross-commitment link (the matmul sumcheck's terminal claim W~(r)
must be opened from the lattice commitment: what object carries it,
what its ZK costs — S5 §4.4's ~59 KB of link rows per tensor is the
only recorded number); hardware-normalized to one H100 with the
SAME ranges YY used; and (4) any fourth option the literature offers
for a hiding, cached, hash-based commitment (e.g. a fresh outer
layer per proof over a fixed inner commitment; "commit once, mask
per proof" constructions) — cite or say none. OUTPUT: a table of the
options x {8B, 30B} x {prefill B=1, B=16, decode} in seconds per
proof and tokens/s on one H100 with the P0 row alongside; the
verdict on which option, if any, keeps a WEIGHTS-PRIVATE Route B on
the 50 tok/s path; what must be measured next; "What is not known".
Plain language, every number labelled and sourced.

## Agent ZZ status (wt-uperf3-zz) — round 11

(lane appends below)

**LANE COMPLETE (2026-09-02, docs only; no code, no builds, no
runs).** Deliverable: NEW `docs/zkmatrix-poc/U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md`
(§0-7 + What is not known; every number labelled [MEASURED] /
[COUNTED] / [MODEL] / [EXTERNAL] with a source; sources S0-S8,
L1-L7, HW; the literature read in-session: ePrint 2022/1010 (Orion,
PDF text), 2024/1164 (its soundness restoration), 2024/1918 (TCHES
2025 accelerator), 2024/1731 (Arc), 2026/1367 (the hash-PCS SoK),
2023/323 (Poseidon2, PDF text), 2025/1085 (SmallWood, search
summary)) plus one pointer line in U_PERF3_ROUTE_B_THROUGHPUT.md
§4.4 (after option 3). Commits: a144465 skeleton; 46bc2f9 §1;
b84c3e8 §2; b403ade §3; a4e149b §4; fca7645 §5; cecffd7 §6; 76384fc
§7 + What is not known; 1b15319 §0; the pointer line, the status
line and this block in the closing commit. Not pushed.

**THE PROBLEM (§1).** A cached Ligero-class weight commitment
opens 256 public columns of m values per proof; with L1's pad the
first proof leaks nothing, the union of samples spans a row after
(n + Q)/Q proofs: **65 at the measured 125M parameters (S0's
number), 257 at 8B and 513 at 30B at S0 §5.2's optimum n**
[COUNTED]. Two smaller per-proof leaks ride along: a mask row
INSIDE a cached commitment is itself fixed (two proofs' masked
vectors differ by an unmasked (rho - rho')^T M), so any
cached-commitment design needs a FRESH per-proof mask commitment;
the terminal claim W~(r) is hidden by the fresh Libra polynomial.
Activations are fresh per proof and never re-proven: no
accumulation (ZK_GAP_OPTIONS §6's asymmetry).

**OPTION 1 — re-commit per proof (§2).** S0's baseline restated
(218 s / 832 s per proof on the laptop CPU at 8B / 30B [MODEL from
MEASURED]; 1.8-6 s / 7-23 s H100 floor). The NTT is 2-15% of the
re-commit, hashing the rest [COUNTED on spec sheet]; an arithmetic
hash is 10-100x slower per byte (Poseidon2 t = 12: 2.81 us per
permutation single-thread [EXTERNAL, L7 Table 2]) — not a
re-commit candidate; rate 1/2 and a 32-bit field are 2x levers
each. Batching counted (the B requests must be STACKED into one X
so W has ONE claim point — else the folds and row-combinations
scale with B [COUNTED from layer.rs / pcs.rs]): 30B prefill on one
H100 at B = 1 / 4 / 16 / 64: floor 15-48 / 31-96 / 42-127 / 46-139
tok/s, scaled 5.4-39 / 9.7-71 / 12-87 / 13-93; decode <= 8.5 tok/s
even at B = 64 (needs B >= 400-1,200 for 20 ms). At B = 16 the
per-layer working set is 258 GB: the token-streaming design (S0 R3)
is a precondition.

**OPTION 2 — never reveal the columns (§3).** Orion as read: code
switching = Virgo as the inner argument; the inner witness = the
sampled columns + the clear vectors; a two-level Merkle
commitment (a tree per column) so no hash runs in-circuit; 3.09 s
/ 1.5 MB at 2^20 R1CS single-thread [EXTERNAL]; its successor
(2024/1164) finds the published Orion unsound and gives Scorpius.
**The literal Orion form still accumulates** (the inner oracle is
the cached column codeword: 4,500-13,000 proofs at 30B [COUNTED]).
The form that meets the rule (2b): the sampled columns become the
witness of a FRESH per-proof inner commitment; the column hash and
Merkle path to the cached root are proven in-circuit over Poseidon2;
a fresh per-proof mask matrix U (3 rows per layer) is inner witness
too. Inner statement from pcs::verify: per column m/8 + 2 log2(4n)
permutations + 3m extension-by-base multiply-adds; **3.05e6 / 5.86e6
Poseidon2 permutations per proof at 8B / 30B, ~2.3e9 / ~4.4e9
native Goldilocks multiplies** [COUNTED; R_P = 22 as instantiated,
EXTERNAL]. Inner prover = a ZK GKR/sumcheck over the data-parallel
circuit (hashline's sumcheck.rs is the seed; K_ov 5-20x native
[MODEL], anchored on S0 §2.1's measured 27.5 ns/entry zero-check):
**9-37 ms floor / 0.12-3.5 s scaled per 30B proof on one H100**,
plus 42-140 ms of fresh blake3 commitments (inner witness 1.3 GB +
U 2.9 GB hashed) = +0.5-5% (floor) / +2-40% (scaled) on the 30B
prefill row; x2.7-3.2 on the decode floor. The hash swap lands
ONLY on the per-model W tree (~1.1e10 permutations at 30B: 2-18
min on a GPU [MODEL], off the clock); A/H stay blake3, so the
on-clock hash floor is untouched. Bytes: the W side 346 MB -> ~14
MB per 30B proof (the masked clear vectors 390 MB remain until the
PCS swap); verifier slightly faster than as built. Per proof,
batched across layers, amortised over B x T like the weight
opening; not amortisable across proofs (Arc: RS-proximity
accumulation, hash-only, hiding unaddressed — uncounted).

**OPTION 3 — the lattice hybrid (§4).** W on the lattice channel
(QQ: per-model 2.34 s, per-proof 2.08 s at 12x512 [MEASURED]; 62-75
/ 14-27 s at 8B, 239-290 / 55-107 s at 30B rescaled x0.85 to S0's
shape [MODEL]; normalised with TT's 2-8x lattice range: Variant B
6.9-81 s per 30B proof on an H100, design of record 30-218 s).
**THE LINK IS THE CRUX.** Form 3a (matmul on the lattice): the
recorded S7 link rows apply verbatim, but ~30% of the activation
witness (4 T f + 2 T d of 13 f + 5 d) rides the lattice rates:
+12-215 s per 30B proof [MODEL on MODEL] — the audit form. Form 3b
(matmul on the hash side): the object is an Fp2 (Goldilocks-ext.)
MLE evaluation claim W~(r); **no recorded design opens it from the
q31 commitment** (S7's link ties two COMMITMENTS of the same
integers via revealed small-coefficient integer functionals). The
cheapest honest bridge: split each coefficient's two 64-bit limbs
into 11-bit digits -> 12 integer functionals per claim (S7's w = 11
class); exactness needs |F| < q/2 with |F| < 2^44.8 per 30B tensor:
does NOT fit q31 — chunking at q31 is 40-100x on the fold (dead) —
so the weight group must sit at the q46 gadget class on the VALUE
rings (a Variant-B-class ruling); per-proof opening x1-1.5 [MODEL];
the 12 revealed integers per tensor are floor-leak class (~1e7
proofs) and must be Tier Z masked with ONE recombination relation
(unrecorded; +272,640-281,856 B per masked floor class); bytes
~15-20 KB per tensor per proof (S0's "~59 KB of link rows per
tensor" traced and quoted: GADGET_MODULUS_DECISION §3.4 "full FFN
tensor | 24 rows | 2,519 B | 59.0 KB | 7.4 MB/pass", scaled by
AGGREGATION_LITERATURE §4.4 item 4). Tokens/s: Variant B 30B
prefill B = 1 5.6-49, B = 16 32-128, decode < 0.15; design of
record 2.2-15 / 21-94. Memory: the 172 GB digit store does not fit
an H100; Variant B's 21.5 GB does.

**OPTION 4 — the literature (§5).** Searched (two web searches;
the ePrint pages above; S5-S8): **none found** for a hiding,
cached, hash-based commitment reusable across proofs; the counted
dichotomy: a hash commitment reveals what it opens, so hiding
across openings means re-randomising every position per proof
(= re-commit; mask-by-linearity, re-salting, a one-time pad all
reduce to it), never revealing (= option 2), or an algebraic hiding
commitment (= option 3; Pedersen/KZG mandate-excluded); RS
accumulation (Arc) is unpriced research.

**THE TABLE (§6), 30B on one H100, tok/s floor / scaled, prefill
B = 1 | prefill B = 16 | decode B = 1:** P0 47-138 / 8.3-60 | 47-138
/ 13-92 | 12-33 / 0.043-0.31; P1 43-135 / 7.6-58 | 44-135 / 12-90 |
12-32 / 0.04-0.30; **option 1** 15-48 / 5.4-39 | 42-127 / 12-87 |
0.043-0.14 / 0.018-0.13; **option 2** 46-137 / 7.8-58 | 47-138 / 13-92
| 3.9-12 / 0.037-0.29; **option 3 VB** 5.6-49 / 4.3-42 | 32-128 /
12-88 | 0.012-0.14; option 3 DoR 2.2-15 / 2.0-13 | 21-94 / 9.7-71 |
0.005-0.033. At 8B every option's prefill cells clear 50 at the
floor. Laptop-GPU row at 12x512 for lane XX [MODEL]: P0 1.5-4.6 s;
option 1 +0.15-0.44 s; option 2 +0.05-0.6 s; option 3 3.4-7.0 s on
QQ's measured 2.08 s. Note: the measured 23.0 s CPU row already
re-commits W every proof (S0 §1.1) — it IS option 1's row at 125M.

**THE VERDICT (§7).** If the product must hide the weights (P2/P3),
**option 2 is the design to build**: the only weights-private
option whose 30B prefill cells are P0's (46-137 floor / 7.8-58
scaled), reaching 50 tok/s under exactly P0's conditions (batched
or prefill, upper half of the range, >= ~50 GB/s hash rate) and no
others; it hinges on the inner ZK prover for a data-parallel
Poseidon2 circuit (K_ov, nothing built), the per-model
arithmetic-hash tree (off the clock) and a written simulator for
the composition. Option 1 reaches 50 only at B >= 16 stacked
prefills with a streaming commitment. Option 3 reaches 50 only with
Variant B at B >= 16 and is the audit channel (S8), not a
throughput route (its weight opening is 100-1,000x the hash
line's on the same board). Batch-1 decode at 50 is out of reach
for every option, as for P0. If P1 is acceptable, nothing here is
needed. Spikes: Z-1 (hashline ZK form, 1 lane-day, the base);
O2-1 Poseidon2 + the W tree behind a switch (2-3 d); O2-2 the
inner statement + a ZK GKR on hashline's sumcheck at 12x512, the
outer verifier accepting with the W columns absent, K_ov
[MEASURED] (3-5 d); O2-3 the simulator/extractor (1 d, docs); O2-4
the device port (an XX rung); O1-1 re-committed vs cached on the
GPU (0.5 d, XX); O1-2 the token-streaming commitment (2-3 d); O3-1
= lane VV; O3-2 the bridge design (2 d); O3-3 the bridge at 3x16
(3-5 d); choice C for every floor/scaled pair. 14 unknowns listed
(the device wall, the hash rate, K_ov, the Poseidon2 GPU rate, the
composition's proof, the inner statement's shape, streaming,
Variant B at q46, the mask relation, attention, the 30B shape, the
verifier, the competitor's privacy sense, the P3 interaction).

**Asks of the orchestrator's files (not in this lane's
ownership):** START_HERE.md §2's "unless an uncounted design
(hidden-column openings, or a lattice-hybrid weight commitment) is
built" can now cite the memo — the hidden-column design is priced
at P0's cells; TASK_BOARD.md §0 may carry the one-line verdict;
AGGREGATION_LITERATURE's family (d)/(e) rows could note ePrint
2024/1164 (Orion found unsound as published; Scorpius).

## Orchestrator note 2026-09-02 — round 11: VV merged (a630f25)

- two_tier.rs (Variant B behind its flag, `tt_b_plan`, the pooled
  challenge draw `tt_draw_cs_par`, `want_hms`), the `uperf-t
  count-b | b diff | b bench | repeat-b` surface, results/uperf3_vv_*.
  Floors on the merged tree: recorded below once the builds finish.
- THE VERDICT: NOT MET at 1.77x [MEASURED, real 12x512 weight group,
  GPU 8T, per-model warm]; the floor is the frozen recursion prove
  on the ~200K-ring proxy + the launch-bound value-fold GEMM + the
  v-pass; 8B/30B [MODEL] 4.4-15x / 4.6-18x straddle the bar — an
  8B-shape run (Mac M-item or a desktop board) is the only settle.
  Three ruling items (VV's status): the int8-value class row; the
  per-model weight certificate (E-O2-BB second opening vs a 256-row
  lookup); the pooled draw. The lattice line's 30B band in
  U_PERF3_THROUGHPUT_MODEL.md is unchanged by this lane.
- Floors on the VV-merged tree (CPU build 2m33s, GPU build 2m53s):
  diff-battery 22.45 s passed; freeze-check 102 ok + passed, exit 0;
  uperf-s 3752cba4..; agg 46234986..; uperf-x be89d5da..; Stage-A
  12x64 range identity statement 441ca5db.. / transcript 44528c6a..
  on BOTH binaries; `uperf-t r1 diff 20` (GPU) wire cae0b312.. PASS
  (3 differential + 6 reject legs, 127.9 s); `uperf-t b diff 20`
  (GPU) wire e757eff7.. PASS (3 differential + 2 identity + 7 reject
  legs, 31.2 s). [WSL-BOX NOISY-SHARED: lanes WW/XX building]

## Orchestrator note 2026-09-02 — round 11: ZZ merged (docs only)

- U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md + the §4.4 pointer in the
  Route-B memo. Verdict recorded in START_HERE §2 and the board §0:
  private weights on Route B stay on the 50 tok/s path ONLY via
  option 2 (never send the sampled weight columns: a per-model
  Poseidon2 weight tree + a per-proof ZK inner proof of the column
  check; +50 ms-3.6 s per 30B proof on an H100 [MODEL]; ~2
  lane-weeks; a written simulator required — Orion found unsound,
  ePrint 2024/1164). Option 1 needs B >= 16 prefills per proof;
  option 3 is the audit channel. The ruling stands with Victor: P1
  vs P2/P3. Z-1 (the hashline ZK form for the activations) is
  needed under ANY mode and is the first spike to open once lane XX
  releases hashline/ (both edit the same crate; serialized to avoid
  a merge fight).
- Corrections adopted from ZZ: the weight-recovery horizon is
  257/513 proofs at the 8B/30B optimum (65 = the 125M parameters);
  only the W commitment needs the inner proof.

## Orchestrator note 2026-09-02 — round 11: WW merged (3f68c8c)

- Floors on the WW-merged tree (CPU build 2m11s, GPU 2m25s):
  diff-battery 16.91 s passed; freeze-check 102 ok + passed, exit 0;
  uperf-s 3752cba4..; agg 46234986..; uperf-x be89d5da..; **the
  Stage-A identity is now the BATCHED form by default**: 12x64
  statement 441ca5db.. | transcript c0b8236f.. on the CPU AND GPU
  binaries; under `ZK_RR_ZC_CLAIMS=gg` the old transcript 44528c6a..
  is reproduced byte-identically. THE STANDING FLOOR LINE FROM HERE:
  `uperf-a pass 12 64 range` -> 441ca5db.. / c0b8236f.. (gg:
  44528c6a..). `uperf-t b diff 20` (GPU) e757eff7.. PASS. The frozen
  pass on the GPU binary after WW's additive k9 edit: `uperf-pc
  pass-profile 3 16` EVAL-PROOF 8a0a3fd4.. (statement de93b680..),
  accept — recorded as this lineage's 3x16 reference; WW verified
  the 12x128 (742d88e1..) and 12x512 (4c259008..) EVAL digests
  unchanged across the edit.
- The ledger tail conflict (WW's status block vs the orchestrator
  notes appended after its header) resolved keeping both sides,
  WW's block first, BEFORE staging — per the new merge-hygiene rule.
- STATE: round 11 lanes UU, VV, WW, YY, ZZ merged; XX (hashline on
  the GPU) still running. Next lane to open when XX lands: Z-1 (the
  hashline ZK form), needed under any privacy mode.

## Orchestrator note 2026-09-03 — round 11: XX merged (clean, 'ort')

- hashline/src/gpu/{mod,cuda}.rs + kernels.cu, the `gpu-cuda`
  feature, `HL_GPU=1`, `--proof-out` + the PROOF sha256 line, the
  device buffer pool; two byte-identical CPU fixes; results/
  hashline_gpu_12x512.md; the §3 GPU row. Floors for the crate:
  recorded below once the builds and the byte-identity re-run
  finish here.
- THE ROW [MEASURED, 8T + RTX 4070, NOISY-SHARED]: prove 3.40 s
  p50, verify 0.42 s, proof 66,844,928 B byte-identical to the CPU
  proof (sha256 50cf7bdf..), 0.78 GB RSS + 2.43 GB VRAM, 8.5e9
  proven MAC/s = 6.1x the lattice line's 1.4e9 on the same device.
  UU's [MODEL] 1.5-2.5 s missed: ~1.9 s of host work uncounted, all
  with byte-preserving fixes (not applied). READING: the hash line
  is now MEASURED faster than the lattice line on the same hardware
  (3.8 s vs 21.0 s total at 12x512), at 125M, FFN-only, without ZK.
- ROUND 11 STATE: all six lanes merged (UU, VV, WW, XX, YY, ZZ).
  Rulings pending with Victor: the privacy mode (P1 vs P2/P3); VV's
  three items; WW's h_sum grounding note. NEXT LANES (opened below):
  ZA = the hashline ZK form (Ligero-ZK pad rows + masked sumchecks
  + committed multiplicities + salts; measured surcharge vs the XX
  row; needed under ANY privacy mode; YY counted +2-8%); ZB = the
  widened-stack v3 semantics (int16-out tables, round-nearest
  requant, the int16 u/h/z classes) + the 8B export reader in
  hashline, so the Mac runs the FIRST MEASURED 8B PROOF on the hash
  line (MAC_RUNBOOK M9) — the laptop cannot hold the 8B weight
  commitments (~17 GB encoded).

### Lane ZA — the hashline zero-knowledge form (wt-uperf3-za) — RUST (round 11 addendum 3)
OWNS: hashline/src/pcs.rs (ADDITIVE: the ZK pad rows / masked
row-combination behind a `--zk` flag), hashline/src/sumcheck.rs
(ADDITIVE: masking polynomials for the zero-check / LogUp / matmul
sumchecks behind the flag), hashline/src/transcript.rs (salts),
the `--zk` flag lines in the pass driver, NEW hashline/src/zk.rs if
wanted, NEW results/hashline_zk_*, the ZK row + a paragraph in
PROVING_CHANNEL_OPTIONS.md §3, "Agent ZA status". READ-ONLY:
hashline/src/gpu/* (XX's; the ZK form must run through the same
device paths — if a kernel needs a mask input, add a NEW kernel
entry, never edit an existing one), the export reader, layer.rs /
silu.rs (lane ZB's), zkmatrix-rs/, scripts/.
WHAT: make the proof zero-knowledge for the ACTIVATIONS (mode P1 of
TARGET_CONTRACT Amendment A1: inputs/activations private, weights
public) per U_PERF3_ROUTE_B_THROUGHPUT.md §4.2-4.3 (the
constructions (a)-(e): Ligero/Brakedown ZK = Q random pad symbols
per encoded row so any Q opened positions are uniform + a masked
clear vector; zero-knowledge sumcheck via a committed random masking
polynomial (Libra / Chiesa-Forbes-Spooner) for every sumcheck whose
polynomial touches A, H or the helpers; committed multiplicities
with a random shift; salted Merkle leaves). The weight commitment
stays as built (public weights; the P2 problem is lane ZZ's option
2, NOT this lane). ACCEPT: (1) the honest proof verifies with `--zk`
at 3x16 and 12x512 on CPU and GPU (`HL_GPU=1`), byte-identical
CPU vs GPU under the same seed; (2) the 7 tamper legs still reject;
(3) a SIMULATION CHECK in code: with `--zk`, two runs with different
activation witnesses but the same public inputs produce opened
values whose distribution the test cannot distinguish (at minimum:
every opened column entry and clear-vector entry is uniform over
the field — assert the pad/mask is actually applied at every
opening; document what a full simulator would add); (4) the
measured surcharge vs the XX row (prove, verify, bytes, RSS, VRAM)
at 12x512 on the GPU — the ZK row in §3, with the recorded
soundness parameters unchanged (state them). RUNGS: 0 skeleton +
the flag + the plan; 1 the PCS pad + masked clear vector with the
opening-uniformity test; 2 the masked sumchecks; 3 multiplicities +
salts; 4 GPU parity + the measured row; 5 record.

### Lane ZB — the widened-stack semantics + the 8B export reader (wt-uperf3-zb) — RUST + a Mac item (round 11 addendum 3)
OWNS: hashline/src/layer.rs and silu.rs (ADDITIVE: a `--profile v3`
path — the int16-output activation tables (SiLU and GELU-tanh v3
families), round-nearest requant, the int16 u/h/z classes; the v2
path byte-identical), NEW hashline/src/export_v3.rs (the reader for
the m8b export layout: `00 dims T d f layers`, `NN exps ...`, the
a16/u16/h16/z16 planes), the `--profile`/`--export` flag lines in
the pass driver, NEW results/hashline_v3_*, MAC_RUNBOOK.md item M9,
"Agent ZB status". READ-ONLY: hashline/src/pcs.rs, sumcheck.rs,
transcript.rs, gpu/* (lanes ZA/XX), zkmatrix-rs/ (the reference:
the `uperf-v3` section's u3_layer_run and the table members
SILU16_V3_MEMBERS / GELU16_V3_MEMBERS / their DIGESTS in
ring_matmul.rs, `ring::lookup`), scripts/m8b_export_ffn.py
(--profile v3: the exact widened chain), the exports.
WHAT: hashline proves the m125 v2 chain today. The real 8B
checkpoints were calibrated under the WIDENED STACK (v3): int16
resolution at the table output, int16 u/h/z classes, round-nearest
requant (U_PERF3_QUANTIZATION_MEASUREMENTS.md; the export
results/m8b_mistral_v3_export/ with digests.txt lines `00 profile
v3-widened`, `00 requant round`, per-layer X/WgT/WuT/WdT/a16/u16/
h16/z16 sha256s and `NN exps` rows). Make hashline prove THAT chain
so the Mac (256 GB, CPU) can prove real Mistral-7B layers.
RUNGS: 0 skeleton + the flags + the plan; 1 the v3 reader
reproducing results/m8b_mistral_v3_export/digests.txt's per-tensor
sha256s for layer 0 from the WSL-local bins (the bins are on this
box under that directory — check; if absent, use
results/m8b_test/m125_v3_export/ which is a v3 export of the 125M
model with its own digests.txt); 2 THE EXACT v3 CHAIN, unproven:
reproduce ALL per-layer z16 digests of the v3 export you have (the
125M v3 test export first — 12 layers; then Mistral layer 0 if the
bins exist here) — STOP and record if any differs; 3 the proof:
the v3 statement at the 125M v3 export, 12x512, CPU and GPU,
tamper legs (a wrong int16 table entry; a wrong rounding); 4 ONE
Mistral-7B layer at T=16 on this box if memory allows (weights
176M int8 -> ~1.4 GB per tensor commitment x3 + encoding; measure
RSS; if it OOMs, record and stop — the Mac runs it); 5 MAC_RUNBOOK
item M9 written with exact commands: the first 8B proof on the hash
line — per-layer at T=16 for all 32 layers, then T=512 for layer 0,
then the full 32x512 pass if memory allows on the Mac (count it
first: ~17 GB of encoded weight commitments per layer, streamed per
layer) — CPU, `--threads` = the Mac's core count (the Mac's cores
are uniform; the laptop's inverted scaling is the hybrid part),
/usr/bin/time -l, the paste-back template.

## Agent ZA status (wt-uperf3-za) — round 11

(lane appends below)

### ZA rung 0 — skeleton + the plan + the identity gate (2026-09-02, second attempt; the first was cut off before any commit)

- Files: NEW `hashline/src/zk.rs` (the plan as the module doc, `ZkConfig`,
  `ZkRng` = a blake3 stream seeded by `--seed` so CPU and GPU produce the
  same `--zk` bytes), `pub mod zk;` in lib.rs, `--zk` / `--seed N` in the
  pass driver (parsed, not yet consumed).
- THE PLAN, and two places where the memo's section-4.2 sketch does not
  close as written (both stated in zk.rs and built differently):
  (1) the memo's mask row "v' = rho^T M + u with u's entry read off the
  column" leaves the verifier without <u, c> for a challenge-dependent
  column weight c; sending it is unsound. Built instead: each private
  table gets a mask row whose contribution is folded into the SUMCHECK
  by a last-round extension (T_ext = (1-y) T + y R_T; rounds 0..k-1
  identical to today's, round k O(1)), so the opened claim is the
  combined (1-rho_k) T~ + rho_k R_T~ — one two-part claim, uniform
  clear vector AND uniform value; this also masks the terminal
  evaluations the memo lists as revealed (its (c) "masked claims" does
  not cover a nonlinear terminal check). (2) the masking polynomial g
  needs a ZK opening of its own (a plain row would unmask the rounds):
  a small per-layer Ligero-form mask commitment with the product-form
  linear test (challenge-independent zero-sum blinding). Pads: f_data +
  Z_n g_pad on the coset 7 * G_4n (no systematic column is ever opened;
  NTT sizes unchanged; RS(n+Q, 4n): distance 0.7455, 2^-105.6 at Q=256,
  the memo's number). Committed multiplicities via a table-side helper
  in H + one zero-valued sum claim masked by a proven zero-sum row.
  Salts as a host re-hash of the device leaves (kernels unchanged).
- Identity gate [WSL-BOX] [8T] [NOISY-SHARED: lane ZB may build]
  [MEASURED]: `M125_EXPORT_DIR=... hashline pass 12 512 --threads 8
  --proof-out <f>` on the fresh builds of this tree (CPU 15.2 s build,
  GPU 16.9 s): CPU PROOF sha256 50cf7bdfd6b5b182.. (66,844,928 B),
  PROVE 16.95 s / VERIFY 0.28 s / RSS 1.56 GB; GPU (HL_GPU=1) PROOF
  sha256 50cf7bdfd6b5b182.. PROVE 2.76 s / VERIFY 0.25 s / RSS 0.78 GB /
  VRAM 2.43 GB. Non-zk path unchanged. `cargo test --release`: 20/20
  (19 + the rng test).

### ZA rung 1 — the ZK PCS: pad rows on the coset, salted leaves, mask rows as claim parts, the uniformity test (2026-09-02)

- `hashline/src/pcs.rs` (additive; the non-zk functions untouched except
  `fold_rows_multi`'s host body factored into `fold_rows_host` with the
  same arithmetic — the 12x512 gate re-run: CPU PROOF sha256
  50cf7bdfd6b5b182.. unchanged [MEASURED]): `ZkOpts` (Q = num_col_checks
  pads, coset generator 7), `CommittedZk` (the plain `Committed` whose
  store holds the coset-encoded rows and whose tree holds the SALTED
  leaves, plus the data, the pads, the salts, the declared mask rows),
  `encode_row_zk` (f_data + Z_n g_pad, coefficients scaled by 7^i,
  one size-nn NTT — the NTT sizes are unchanged), `commit_zk`,
  `ZClaim`/`ZPart` (a general linear claim: parts of any log_size,
  sub-row slices, plain sums; grouped by the full column-weight
  vector), `open_zk`/`verify_zk` (clear vectors of n + Q entries; the
  verifier re-encodes them on the coset with the pads; salted Merkle
  leaves blake3(blake3(col) || salt)), and `assert_mask_sites` — the
  runtime assertion that EVERY opening site carries a mask: each group
  vector touches >= 1 declared mask row with a nonzero combined weight,
  the proximity rho touches the reserved prox mask row, Q pads >= the
  opened columns, all leaves salted. The device commit hook
  (`gpu::dev_commit_zk`) is referenced behind the feature; built in
  rung 4.
- Tests (22/22): `zk_commit_open_verify_and_tampers` (honest accept;
  a wrong value, a wrong sum, a tampered message entry, a tampered PAD
  entry, a tampered salt, a tampered column entry, a different witness
  under the same claims — all reject) and THE UNIFORMITY TEST
  `zk_openings_are_uniform_and_every_site_is_masked` [MEASURED, in
  code]: two witnesses of int8 values, 40 independent openings each
  (fresh pads/masks/salts per seed), the same claim structure (a
  16-row private slice opened through the combined masked claim
  (1-e) P~(r) + e <R, eq(r_col)>, a private sub-row slice with its own
  mask, a value-0 sum claim over a zero-sum mask row, a prox mask row):
  (1) all 37,000+ opened column entries and clear-vector entries are
  DISTINCT and none lies within 2^40 of 0 or p (no witness-range
  value); (2) chi-square of the top byte against uniform at 256 bins:
  columns A 275.6 / B 259.0, clear vectors A 293.0 / B 235.7 over
  ~9K values each (critical 310.5 at p = 0.01, df 255); (3) the
  two-sample chi-square A vs B 253.3 (the two witnesses' opened
  distributions are not distinguishable by the statistic); (4) the
  enumerated sites: group vectors 0/1/2 -> mask rows 17/18/19, the
  proximity vector -> prox mask row 20, 12 opened columns with 12 pads
  per row on the coset, 64 leaves salted. The contrast: the NON-zk
  commitment of the same data opens 42 raw int8 values among its 252
  opened entries (the systematic columns).
- Soundness parameters, unchanged in kind: inv_rate 4, Q = 256 column
  checks, n = 2^14; the ZK code is RS(n + Q, 4n) on the coset
  (distance 0.7455 vs 0.75), (1 - delta/3)^256 = 2^-105.6 vs 2^-106.

### ZA rung 2 — the masked sumchecks, the mask commitment, the ZK layer prover/verifier (2026-09-02)

- `transcript.rs` (additive): a `RoundMask` hook — while installed,
  every `sc-round` absorb is replaced by the masked message and each
  challenge is reported back; the masked messages are recorded for the
  proof. This masks BOTH the CPU `sumcheck::prove` and XX's device
  `dev_zerocheck` without touching either (the device kernels are
  unchanged). `sumcheck.rs` (additive): `CfsMask` (g = a_0 + a' prod x_j
  + sum a_{j,e} x_j^e; closed-form round messages, total, terminal,
  and the weight vectors of both as linear functionals of the
  coefficients), `CfsMasker`, `extension_round` / `masked_terminal`
  (the last-round extension). Tests: the closed-form rounds equal a
  brute-force sumcheck of g at three (N, d); a masked zero-check with
  the extension round round-trips and still catches a broken identity.
- `zk.rs`: `MaskCommit` (the five masking polynomials of a layer as
  base rows with 256 pads each, a zero-sum blinding row, a proximity
  mask row; RS(1024, 4096) on the coset 7 G_4096, salted Merkle; the
  product-form linear test `mask_open` / `mask_verify`: q' = sum_s
  p_a p_W + p_b, its G_512-sum equals the theta-combined functional,
  256 sampled columns; ~170 KB per layer); `ZkLayout` (A: 7 zc20 + 9
  zc17 + 3 gu + 1 d mask rows + a prox row = 21 rows of n; H: 6 + 6 rows
  for the Fp2 masks, the zero-sum row u (re/im), its extension mask
  u', a prox row = 17 rows); `prove_layer_zk` / `verify_layer_zk`: W
  as built; A and H via `commit_zk`; the gu and d sumchecks with
  their claimed sums sent MASKED (S'' = S + c G) and their private
  terminals masked (opened directly from A at p2 / p5 as two-part
  claims — two more A group vectors than the non-zk fold; see the
  open item); zc20 with fold1 = nu0 (gacc + lambda uacc) and the
  eq5 term dropped, its claim nu0 S''_gu + Gamma20 (Gamma20 = c20 G20
  - nu0 c_gu G_gu, a functional over two mask rows, proven in the
  mask opening); zc17 likewise (fz over the lambda_d combination,
  fx dropped); the zero-sum sumcheck over u (14 vars + extension,
  degree 2 with a constant selector table); the LogUp table side and
  the helper sums as built in rung 2 (rung 3 moves them); the five
  g(rho)'s DERIVED by the verifier from the masked terminal checks
  and folded with the three Gammas into one mask opening. Every
  table-opening claim is (1 - e) T~ + e R~ with its own mask row
  (Fp2 tables: re/im pairs with Fp2 masks). `--zk` in the driver:
  `pass_zk`, `layer_zk` (the 7 tamper legs), the PROOF sha256 line,
  the enumerated mask sites printed.
- Correctness [WSL-BOX, 8T, CPU, NOISY-SHARED, MEASURED]: 3x16 ZK
  ACCEPT (PROOF 02a31a2c.. at seed 1, reproduced on a second run;
  seed 2 -> c7a70708..); non-zk 3x16 596b9c79.. and 12x512
  50cf7bdf.. UNCHANGED; `layer 0 16 --zk --all-tampers` 6/6 REJECT +
  `pass 2 64 --zk --tamper z` REJECT (the 7 legs) at the same sites
  as the non-zk (matmul/zero-check round 0; the LogUp identity);
  `cargo test` 24/24.
- THE 12x512 ZK CPU ROW [MEASURED, WSL-BOX 8T NOISY-SHARED (lane ZB
  active), 1 run each]: ZK PROVE 19.45 s / VERIFY 0.38 s / proof
  79,956,224 B (80.0 MB) / RSS 1.77 GB / 1.49e9 proven MAC/s (PROOF
  sha256 50f5df46.. at seed 1) vs the non-zk pass on the same tree
  and box the same hour: 16.89 s / 0.29 s / 66,844,928 B / 1.56 GB.
  Surcharge: prover +15%, verifier +31%, bytes +19.6%, RSS +14%.
  Phases (zk vs non-zk): commit A 4.17 vs 3.60, helpers + commit H
  4.99 vs 4.34, zc20 4.01 vs 3.72, zc17 2.14 vs 1.73, openings 0.94
  vs 0.87, + mask commit 0.08 + zsum/mask open 0.31. A first cut
  had the verifier at 1.45 s and the openings at 2.6 s: the general
  claim built its 2^14 column table per PART (rayon wake-ups); it is
  now built once per group as the non-zk path does (the digests did
  not move: transcript-preserving).
- Bytes: the +13.1 MB are two extra A clear vectors (the masked gu /
  d terminals opened at p2 / p5 rather than folded into the
  zero-checks: 2 x 266 KB per layer), one extra H vector (the zsum
  point), the mask openings (~170 KB per layer), 38 mask rows per
  layer in the opened columns, pads and salts. OPEN ITEM (not built):
  folding the masked matmul terminals into the zero-checks needs a
  "replicated mask row" table kind on the device (a new TabSpec +
  kernel); it would return ~6.4 MB (-8%).

### ZA rung 3 — committed multiplicities (nothing of the histogram or the helper sums is sent) + the small-sumcheck path (2026-09-02)

- Construction (d) as built: the multiplicity tables (silu 256, int8
  256, range(s) 2^s for each distinct shift; the export's shifts are
  5-10 bits, so every table fits one row of the commitment) are rows
  of A (committed BEFORE alpha, as LogUp needs), each with a mask row.
  Their table side h_t[i] = m[i] / (alpha - tval[i]) is a committed
  helper row of H (re/im, zero beyond the table) with an Fp2 mask,
  tied to m by a masked zero-check over log n variables
  (eq(tau3) sum_i mu3_i (h_t,i (alpha - tval_i) - m_i) = 0; the public
  tval rows are recomputed by the verifier from beta, gamma and the
  frozen table and evaluated at the point), and THE LOGUP IDENTITY is
  one value-0 sum claim on H: witness helpers - table helpers + the
  zero-sum row u. Gone from the proof and the transcript: the mults
  tables, the helper sums, the verifier's shape/total checks and its
  table-side evaluation. Soundness is unchanged in kind (the residue
  argument does not need m to be small integers). The mask commitment
  has a sixth row (the table zero-check's degree-3 mask) and a fourth
  Gamma.
- Correctness [MEASURED]: 3x16 ZK ACCEPT (PROOF ee9497e0.. at seed 1,
  reproduced), `layer 0 16 --zk --all-tampers` 6/6 REJECT — the two
  lookup legs (out-of-range remainder, wrong table entry) are now
  caught at "H: pcs zk: group 4: <v, c> != combined claim" (the
  value-0 LogUp claim) instead of the verifier's clear-text table
  evaluation — and `pass 2 64 --zk --tamper z` REJECT; tests 24/24;
  the mask-site enumeration now lists 5 A groups and 5 H groups
  (A group 4 = the five m rows' masks; H group 3 = the five table
  helpers' masks; H group 4 = the sum group's zero-sum row).
- `sumcheck.rs`: rounds with half * k <= 2^16 run on one thread (the
  field sums are order-independent; the values are identical). This
  also speeds up the NON-zk pass, byte-identically: 12x512 CPU PROVE
  16.89 -> 14.82 s at PROOF 50cf7bdf.. unchanged (zc20 3.72 -> 2.95,
  zc17 1.73 -> 0.78, the matmul sumchecks 0.58 -> 0.35) [MEASURED,
  WSL-BOX 8T NOISY-SHARED]. The table zero-check: 1.69 -> 0.59 s.
- THE 12x512 ZK CPU ROW after rung 3 [MEASURED, WSL-BOX 8T
  NOISY-SHARED, 1 run each, same binary, same hour]: ZK PROVE 18.45 s
  / VERIFY 0.52 s / proof 87,080,688 B (87.1 MB) / RSS 1.81 GB /
  1.57e9 proven MAC/s (PROOF 9b80855d.. at seed 1) vs non-zk 14.82 s
  / 0.28 s / 66,844,928 B / 1.56 GB. Surcharge: prover +24%, verifier
  +0.24 s (+86%), bytes +30%, RSS +16%. Phases zk vs non-zk: commit A
  4.46 vs 3.65 (+26 rows, pads, coset, salts), helpers + commit H
  5.26 vs 4.27 (+37 rows, the table helpers), zc20 3.29 vs 2.95, zc17
  1.17 vs 0.78, table zero-check 0.59, zsum + mask open 0.07, mask
  commit 0.11, openings 0.99 vs 0.83.

### ZA rung 4 — GPU parity + the measured surcharge (2026-09-02)

- The device path (feature gpu-cuda, `HL_GPU=1`), additive to XX's
  module: ONE new kernel `k_zk_pad_scale` (the pad + coset coefficient
  step of the ZK row encoding) appended to kernels.cu and its name in
  the FUNCS list; NEW host functions `dev_commit_zk_from` /
  `dev_commit_zk` (inverse NTT in rung 1's gather form, the pad kernel,
  the size-nn forward NTT, XX's column hashes; the host salts the
  leaves) and `dev_upload_rows` (the host-generated tail rows of H —
  masks, table helpers, u — written into the device helper buffer);
  two re-export lines in gpu/mod.rs. No existing kernel or host
  function was edited. `pcs::commit_zk_device` (H from the device
  helper buffer; pads and salts drawn in `commit_zk`'s order). In
  zk.rs the H commit, the two zero-checks (XX's `dev_zerocheck`
  through the transcript masker, nu1 := nu0 lambda / nu2 := 0 and
  nu_x := 0 / nu_z := nu_z lambda_d so the existing kernels compute
  exactly the ZK polynomials) and the claims' evaluations run on the
  device; the matmul folds, the table zero-check (16 tables of 2^14)
  and the zero-sum sumcheck stay on the host as XX's matmul sumchecks
  do. The seeded RNG (blake3 XOF) now fills 8 KB blocks (it was 64 B:
  ~10^5 hasher inits per layer); the mask evaluations share one eq
  table per opening point; the committed data is moved into the
  commitment instead of copied (2 x 60-70 MB per layer); and the
  number of multiplicity-table slots is FIXED at 6 (dummy slots m =
  h_t = 0) so every layer's A and H have the same row counts — with
  per-layer counts the device buffer pool cached three layouts and
  the held VRAM grew 3.0 -> 5.7 GB over the 12 layers.
- PARITY [MEASURED]: `pass 12 512 --zk --seed 1`: CPU PROOF sha256
  021485e4f80ec695.. (87,228,528 B) on 3 runs == GPU (HL_GPU=1) on 4
  runs; `pass 3 16 --zk --seed 1` f9509b9d.. CPU == GPU. Non-zk gates
  on the same final binaries: CPU and GPU 12x512 both
  50cf7bdfd6b5b182.., 3x16 596b9c79.. — unchanged. The 7 tamper
  legs reject through the GPU ZK prover (`layer 0 16 --zk
  --all-tampers` GREEN + the pass-level wrong-z leg). Tests 24/24.
- THE SURCHARGE [MEASURED, WSL-BOX 8T + RTX 4070 Laptop, NOISY-SHARED
  (lane ZB active), 4 runs GPU / 3 runs CPU, prove p50]:

  | 12x512 | PROVE | VERIFY | proof bytes | RSS | VRAM held |
  |---|---:|---:|---:|---:|---:|
  | GPU non-zk (XX's row, this tree) | 2.46 s (2.40-2.48) | 0.25-0.29 s | 66,844,928 | 0.78 GB | 2.43 GB |
  | **GPU --zk (P1)** | **3.93 s** (3.87-4.10) | 0.37-0.40 s | 87,228,528 | 0.90 GB | 3.03 GB |
  | surcharge | **+60%** | +0.12 s (+45%) | **+30.5%** | +16% | +25% |
  | CPU non-zk | 14.78 s (14.70-14.82) | 0.27-0.28 s | 66,844,928 | 1.56 GB | — |
  | **CPU --zk (P1)** | **16.55 s** (16.52-16.65) | 0.44-0.50 s | 87,228,528 | 1.68 GB | — |
  | surcharge | **+12%** | +0.2 s | +30.5% | +8% | — |

  3x16 GPU: zk 0.36 s (0.34-0.41) vs non-zk 0.28 s (0.23-0.31);
  9,509,916 vs 7,365,588 B; RSS 0.33 vs 0.33 GB; VRAM 1.49 vs 1.46 GB.
  Proven MAC/s at 12x512: GPU zk 7.4e9 (non-zk 1.2e10), CPU zk 1.75e9.
- Where the GPU's +1.47 s goes (phases, zk vs non-zk): commit A 1.09
  vs 0.78 (+26 rows, the pads, the gather-form NTT: device ntt 0.58
  vs 0.43 s total, the salting of 65,536 leaves), helpers + commit H
  0.84 vs 0.42 (+37 rows incl. the table helpers, the tail upload,
  the host-side table helpers), openings 0.43 vs 0.24 (six row
  weights for A = two device fold calls, the pad folds, more rows in
  the columns), the table zero-check 0.24-0.33 (host), the mask
  commit + opening 0.11, zc20/zc17 +0.05. Byte-preserving levers not
  applied: the DIF/DIT NTT pair with a bit-reversed pad kernel
  (~-0.15 s), the table zero-check on the device (~-0.2 s), folding
  the masked matmul terminals into the zero-checks (-8% bytes, needs a
  replicated-row table kind), the mask rows' RNG on the device.
- Against the memo's [COUNTED] +2-8% prover / +1-8% bytes / +2-15%
  verifier for P1: the built form is +60% / +30% / +45% on the GPU
  and +12% / +30% / +70% on the CPU. The memo's count assumed the
  masked objects ride inside work already paid; the built form pays
  for what the memo's sketch did not close: one mask row per (table,
  point) — 26 + 37 rows per layer — and the matmul terminals opened
  as their own groups (two more clear vectors of 16,640 Fp2 per
  layer), plus the mask commitment. The bytes' +20.4 MB: 3 extra A
  clear vectors and 2 extra H vectors (5 x 266 KB x 12), the mask
  openings (~170 KB x 12), the pads on every clear vector, 63 mask /
  table rows in every opened column, the salts.

### ZA rung 5 — the record (2026-09-02) — LANE COMPLETE (rungs 0-5)

- results/hashline_zk_12x512.md (XX's form: the gate, the runs table,
  the phase split zk vs non-zk on both devices, the soundness
  parameters, the uniformity test, the enumerated mask sites of the
  real pass, the tamper legs, the two departures from the memo, the
  count vs the measurement, the levers, the commands); the section-3
  rows (GPU zk, CPU zk) + the ZK paragraph in
  PROVING_CHANNEL_OPTIONS.md (what is hidden, what is still revealed,
  what a full simulator proof would add); a README block. START_HERE /
  the board are the orchestrator's.
- SUMMARY FOR THE RULING. Mode P1 on the hash line is BUILT and
  MEASURED: `--zk --seed N` hides the opened columns, the clear
  vectors, the histograms and helper sums, the sumcheck rounds, every
  private terminal evaluation and matmul claimed sum, and the leaves;
  the weights stay public; CPU and GPU produce the same bytes under
  one seed; the seven tamper legs reject; the soundness class is
  unchanged (2^-105.6 vs 2^-106 on the column test). The price on the
  laptop GPU is 3.93 s vs 2.46 s per 12x512 proof (+60%), 87.2 vs
  66.8 MB (+30%), 0.38 vs 0.27 s verify — larger than lane YY's
  counted +2-8% / +1-8% because two parts of the memo's sketch had to
  be replaced by heavier constructions (the mask rows tied to the
  sumcheck; the mask polynomial's own ZK opening) and because the
  matmul terminals are opened as their own groups. With the listed
  byte-preserving levers the GPU surcharge should land near +30-40%.
  Open: a written simulator for the 12-layer composition; folding the
  masked matmul terminals into the zero-checks (needs a replicated-row
  table kind on the device); the ZK encode on the DIF/DIT NTT pair;
  the table zero-check on the device; mode P2/P3 (private weights) is
  lane ZZ's option 2, not touched.
- Files touched (ownership as declared): hashline/src/{pcs.rs,
  sumcheck.rs, transcript.rs} (additive), NEW hashline/src/zk.rs,
  hashline/src/lib.rs (one line), hashline/src/bin/hashline.rs (the
  `--zk`/`--seed` flags + pass_zk/layer_zk), hashline/src/gpu/
  {kernels.cu, cuda.rs, mod.rs} (ONE new kernel + three new host
  functions + one name in FUNCS + two re-export lines; no existing
  kernel or function edited), hashline/README.md (a block), NEW
  results/hashline_zk_12x512.md, PROVING_CHANNEL_OPTIONS.md section 3
  (rows + paragraph), this status section. layer.rs, silu.rs, the
  export reader, zkmatrix-rs, scripts: untouched.

## Agent ZB status (wt-uperf3-zb) — round 11

(lane appends below)
- Floors for the crate on the XX-merged tree (this checkout; CPU
  build 10.6 s, 19/19 tests; GPU build 17.2 s): `hashline pass 12
  512 --threads 8 --proof-out`: CPU PROVE 16.81 s / VERIFY 0.27 s /
  RSS 1.56 GB; GPU (HL_GPU=1) PROVE **2.88 s** / VERIFY 0.27 s / RSS
  0.78 GB / VRAM 2.43 GB / 1.008e10 proven MAC/s [WSL-BOX 8T, the
  box quieter than XX's runs: no lane building]; BOTH proofs sha256
  50cf7bdfd6b5b182.. (66,844,928 B) — byte-identical, as XX
  recorded. Device-side sum 1.44 s (h2d 0.23, ntt 0.43, hash 0.11,
  sumcheck 0.43, fold 0.16, helpers 0.09); the rest is host.

**ZB RUNG PLAN (2026-09-02, opened on 0c8e636).** 0 skeleton: the
`--profile v3 --export DIR` flags, `tables_v3.rs` (the 15 frozen
int16-out members regenerated + digest-pinned), `export_v3.rs` (the
m8b v3 sidecar/bin reader + the exact widened chain), the plan; 1 the
reader reproducing every per-tensor sha256 (125M v3 export; Mistral
layer 0 — its bins exist here); 2 the exact chain reproducing the
a16/u16/h16/z16 planes of BOTH exports; 3 the v3 PROOF at the 125M v3
export 12x512, CPU + GPU, tamper legs, walls vs the v2 row; 4 one
Mistral layer at T=16 here if memory allows; 5 MAC_RUNBOOK M9 + the
record. DESIGN OF RECORD (what `--profile v3` proves, per layer, any
(T, d, f)): the same three Ligero commitments and the same sumcheck
skeleton as v2, generalized to nb_d = d / 2^log_db blocks on the d
axis and nb_f = f / 2^log_fb blocks on the f axis (768 = 3 x 256 and
2048 = 1 x 2048 at 125M; 4096 = 1 x 4096 and 14336 = 7 x 2048 at
Mistral — block structure, no zero padding); the (g8, a16) lookup
into the layer's frozen int16-out member (256 rows, int16 outputs;
tag ACT16; the member's spec digest is part of the statement); the
int16 classes as ONE 2^16-row range table [-32768, 32767] (tag INT16
— the class the engine's v3 statement proves: its rng-u16/rng-z16
tables are 2^16 rows and its h16 limb split admits -32768; the
Python export's honest-witness assert +-32767 is a subset); ROUND-
to-nearest requant as the exact identity acc = 2^sh y + r with the
BALANCED remainder r in [-2^(sh-1), 2^(sh-1)) (equivalent to the
engine's floor on the pre-shifted operand acc + 2^(sh-1); the
identities stay linear with no constant, so they fold into the
evaluation claims exactly as v2's and the XX zero-check kernels
apply unchanged); negative sh_u (the exact public up-scaling branch,
present in both exports) as the identity uacc = 2^-k u16 with the
field inverse of 2^k as the public coefficient and an all-zero
remainder column over the one-row window {0}; signed shifts and the
member digest absorbed into the statement. v2 untouched.

- **RUNG 0+1+2 GREEN (2026-09-02, WSL-BOX).** Build 7-14 s CPU; 22/22
  unit tests (19 + 3 new: every frozen member regenerates to its pin,
  requant_round == the pre-shifted floor on 140k values at 5 shifts
  incl. the sh <= 0 branch, the i64 down-matmul). `hashline tables-v3`
  prints the 15 members with min/max/saturated rows/digests LINE-
  IDENTICAL to `ring_matmul uperf-v3 tables` (third leg: a python
  parse of lookup.rs's frozen consts vs m8b_margins.py's generator —
  15/15 bytes + digests SAME). READER [MEASURED]: `check-export
  --profile v3` reproduces **96/96** tensor sha256s of the 125M v3
  export (X/WgT/WuT/WdT/a16/u16/h16/z16 x 12; 0.30 s) and **256/256**
  of the REAL Mistral-7B v3 export (x 32 layers; 7.0 GB of bins under
  /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export/, 9.2 s);
  every sidecar shifts row equals the exponent-derived signed shifts,
  every wexps row equals exps - 8, every table row names a frozen
  member whose regenerated digest equals the row's. THE EXACT CHAIN
  [MEASURED]: `chain --profile v3` re-executes each layer from X and
  the int8 weights alone and reproduces the export's planes:
  **125M 12/12 layers x 4 planes** (a16/u16/h16/z16 full-plane sha256
  at T=512, 2.0 s, 22T) and **Mistral-7B 32/32 layers x 4 planes**
  (128 plane digests at T=512, 127.6 s at 8T under the heavy lock,
  peak RSS 0.72 GB [NOISY-SHARED]); every range fact HOLDS (g8 in the
  table domain, u16/h16/z16 in the int16 class, every balanced
  remainder in its window incl. sh_u in {-2..3}). No STOP. The
  statement the proof is about is the exported one, bit for bit, on
  both checkpoints. Files: hashline/src/tables_v3.rs, export_v3.rs,
  lib.rs (+2 mod lines), bin/hashline.rs (+flags, check-export/chain
  v3, tables-v3).

- **RESUME (2026-09-02, second session).** The first session died at
  a usage cutout with rungs 0-2 committed (a40b338) and rung 3 as an
  UNCOMMITTED draft (layer.rs +971 lines: the v3 prover/verifier/
  tamper legs; hashline.rs +182: `layer`/`pass` dispatch on
  `--profile v3`). The draft was reviewed against the XX kernel
  contracts (kind 0 = 13 tables in the order eq-tau/eq-p1/eq-p5/g8/
  rg/a16/u16/ru/h16/rh/hg/hu/hh with prm alpha,beta,g_act,g_rg,g_ru,
  g_rh,g_i16,mu[4],nu[3],p_g,p_u,p_h; kind 1 = 15 tables with
  alpha,g_i16,g_rd,mu2[3],nu_x[3],nu_z[3],p_z — the v2 polynomials
  verbatim, only the semantics of the columns changed), built clean,
  and KEPT IN FULL; the one edit is a cfg-gated `let _ = dev_shape`
  for the CPU-build warning. Checkpoint 54a4558.

- **RUNG 3 GREEN (2026-09-02, WSL-BOX): THE v3 PROOF at the 125M v3
  export, 12x512, CPU and GPU, byte-identical.** What `--profile v3`
  proves per layer (the design of record above, now code): the block-
  structured layout (125M: Wg/Wu as 3x1 blocks of 256x2048, Wd as 1x3
  blocks of 2048x256; A = 7 f-planes g8/rg/a16/u16/ru/h16/rh + 3 d-
  planes X/z16/rd per block; H = the LogUp helper columns) under the
  same three Ligero commitments and the same sumcheck skeleton as v2;
  the ACT16 lookup g8 + beta a16 + gamma TAG_ACT16 into the layer's
  frozen int16-out member (256 rows, int16 outputs; the member's spec
  digest, the family name, (d, f) and the four SIGNED shifts absorbed
  into the statement); u16/h16/z16 in ONE 2^16-row INT16 class table
  [-32768, 32767]; every balanced remainder in its window table
  tag_rem_v3(sh) (2^sh rows; the one-row window {0} at sh <= 0); the
  four requant identities acc = 2^sh y + r folded into the g/u and d
  evaluation claims and the two zero-checks exactly as v2 (the public
  coefficient of u16 at sh_u = -1 is the field inverse of 2, the
  remainder column committed all-zero — layers 3 and 4 of the 125M
  export exercise it). The multiplicity tables ride in the proof
  (256 + 65536 + one per distinct shift), which is the whole size
  delta against v2. [MEASURED] layer 0 (shifts 9/1/14/10) and layer 3
  (8/-1/14/9, the up-scaling branch) at T=512: CPU ACCEPT prove
  1.60 s / verify 0.027 s / 5.90 MB; **8/8 tamper legs REJECT on CPU
  and on GPU** (flipped X, flipped Wg, out-of-range remainder, wrong
  int16 table entry (a16+1 with h16/z16 recomputed consistently),
  wrong requant, wrong z, WRONG ROUNDING = floor at a round-up element
  carried through the chain (only the remainder window breaks), out-
  of-range int16 = z16 + 65536 with rd compensated (identity kept)) —
  the matmul/requant legs die in sumcheck round 0, the table/range/
  rounding legs in the LogUp identity. **THE ROW** [MEASURED, WSL-BOX
  8T, NOISY-SHARED: lane ZA's worktree present, no concurrent build
  during the two pass walls] `hashline pass 12 512 --profile v3
  --export .../m125_v3_export --threads 8 --proof-out`: CPU PROVE
  **17.40 s** / VERIFY 0.27 s / proof 70,758,084 B (70.8 MB) / RSS
  1.58 GB / 1.67e9 proven MAC/s; GPU (HL_GPU=1) PROVE **2.74 s** /
  VERIFY 0.26 s / RSS 0.78 GB / VRAM 2.43 GB / 1.06e10 proven MAC/s,
  device-side sum 1.39 s (h2d 0.21 [1271 MB], ntt 0.42, hash 0.10,
  sumcheck 0.43, fold 0.15, helpers 0.08). BOTH proofs sha256
  **5f368db6240e0614..** — `cmp` BYTE-IDENTICAL. Against the v2 row
  on this box (CPU 16.81 / 0.27 / 66.84 MB / 1.56 GB; GPU 2.88 /
  0.27): the widened statement costs +3.5% CPU prove, -5% GPU prove
  (noise), +5.9% proof bytes, i.e. the v3 semantics are FREE at the
  hash line — the 2^16-row class is a multiplicity vector, not a
  wider commitment. Phases (CPU, summed over 12 layers): commit W
  2.13, commit A 3.86, helpers+H 4.55, matmul g/u 0.40, d 0.23, zc F
  3.61, zc D 1.72, openings 0.89 (GPU: 0.45 / 0.77 / 0.40 / 0.30 /
  0.17 / 0.33 / 0.09 / 0.22). **v2 GATE UNCHANGED**: `pass 12 512
  --threads 8 --proof-out` prints PROOF sha256 50cf7bdfd6b5b182..
  (66,844,928 B) on the CPU binary (17.13 s, box loaded by the GPU
  legs) and on the GPU binary (2.66 s). 22/22 tests.

- **RUNG 4 GREEN (2026-09-02, WSL-BOX): THE FIRST 8B-WIDTH LAYER
  PROOF ON THE HASH LINE — Mistral-7B layer 0 of the real v3 export
  (bins under /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export/),
  d 4096 f 14336, shifts 11/2/15/6, member silu-int16out-table-v3
  (-3,-12) 859344ba5ed57bd3..** Block structure: Wg/Wu 1x7 blocks of
  4096x2048, Wd 7x1 blocks of 2048x4096 (21 blocks of 2^23; W =
  176,160,768 Fp = 1.41 GB, its Ligero encoding at log_cols 14 =
  10,752 rows x 65,536 cols = 5.64 GB). COUNTED before running: peak
  ~7.5 GB at T=16 against `free -g` 14 GB available -> GO. [MEASURED,
  WSL-BOX 8T CPU NOISY-SHARED, under the heavy lock, /usr/bin/time -v]
  `hashline layer 0 T --profile v3 --export .../m8b_mistral_v3_export
  --threads 8`:
  | T | prove | of which commit W | verify | proof | peak RSS |
  |---|---:|---:|---:|---:|---:|
  | 16 | **10.53 s** | 8.58 s | 0.029 s | 25.86 MB | **7.48 GB** |
  | 128 | 11.67 s | 7.92 s | 0.034 s | 28.76 MB | 8.78 GB |
  | 256 | 14.51 s | 9.37 s | 0.031 s | 32.07 MB | 10.28 GB |
  ACCEPT at all three; the wrong-int16-table-entry leg at T=16
  (`--tamper table --tamper-idx 1000`) REJECTs in the LogUp identity
  (9.0 s). The split the throughput model wants, read off the three
  rows: the WEIGHT part (commit W + its opening, ~9 s and 7.0 GB per
  layer, the same at any T) and the ACTIVATION part (~13.5 ms and
  11.7 MB per token row), so a 7B layer at T=512 models to **~18 s /
  ~13.3 GB** on this box [MODEL] — 13.3 of the 14 GB available, which
  is why T=512 at 7B is a Mac run (M9), not a laptop run. The proof
  is 22 MB of W column openings (256 checks x 10,752 rows x 8 B):
  `--log-cols 16` (2,688 rows) halves it to 13.37 MB at the same
  wall (9.47 s) and RSS (7.46 GB) — a parameter choice for the Mac
  runs, noted in M9, not the default (the byte-identity gate is per
  parameter set). GPU [MEASURED]: `HL_GPU=1` at the 7B shape DECLINES
  the W commit (cuMemAlloc 5376 MB: CUDA_ERROR_OUT_OF_MEMORY on the
  8 GB part with the 1.4 GB data already resident) and falls back to
  the CPU path — ACCEPT, 10.62 s, the same 25,863,324 B — so the 7B
  GPU proof needs a chunked/streamed W encoding (a future lane; the
  fallback is graceful and the bytes are the CPU bytes). The zero-
  checks at this shape (nb_f 7, nb_d 1: 73 and 7 tables) run on the
  host by design. A `pass` fix in this rung: `pass_v3` now loads ONE
  witness at a time (load, prove, drop; the statement stays for the
  verifier) — 32 resident 7B witnesses would have been 11 GB before
  the first commitment; byte-neutral: the 12x512 v3 pass re-run after
  the edit prints 5f368db6240e0614.. on the CPU binary (17.18 s) and
  the GPU binary (2.78 s, RSS now 0.43 GB); the pass-level leg `pass
  12 512 --profile v3 --tamper requant` REJECTs at layer 6 (sumcheck
  round 0) as in XX's v2 table.

- **RUNG 5 (2026-09-02): MAC_RUNBOOK item M9 + the record.** M9
  (docs/zkmatrix-poc/MAC_RUNBOOK.md, before "## R. RESULTS"): THE
  FIRST 8B PROOF ON THE HASH LINE on the Mac — build the crate CPU-
  only, 22 tests, `check-export`/`chain --profile v3` against the
  Mac's own M4 export (256/256 digests, 32/32 x 4 planes), then
  `layer 0 16`, the 32-layer T=16 loop, `layer 0 512`, and the full
  `pass 32 512 --profile v3 --proof-out` (modelled from this box's
  T=16/128/256 rows: ~18-20 s and ~13.3 GB per 7B layer at T=512 at
  8T, so ~10 min and ~14 GB peak for the 32x512 pass with one witness
  resident; the Mac's 256 GB holds it many times over; the proof
  file ~1.2 GB, not committed), `--threads $(sysctl -n hw.ncpu)`,
  `/usr/bin/time -l`, the paste-back template; optional legs: the
  125M v3 12x512 pass against the WSL v3 export copied over (the
  byte gate 5f368db6240e0614.. on Apple silicon — the transcript is
  deterministic, so the Mac's bytes must equal the laptop's), the v2
  gate 50cf7bdfd6b5b182.. via M125_EXPORT_DIR, and `--log-cols 16`.
  The record: results/hashline_v3_12x512.md (XX's form: the
  statement, the gate, the 12x512 runs CPU/GPU vs v2, the phases,
  the nine tamper legs incl. the two v3-only ones, the 7B rows and
  their T-split, the side-by-side). LANE COMPLETE at this commit;
  the next rungs are the Mac's (M9) and, on this box, a chunked W
  encoding for the 7B GPU commit (declined at 5.4 GB) and the ZK form
  (lane ZA) composed with v3.
  ORCHESTRATOR-RUN (optional, ~10 min, ~13.5 GB peak of 14 GB
  available — may exit 137; that exit is the record):
  `flock /tmp/zk-heavy.lock /usr/bin/time -v
  hashline/target/release/hashline pass 32 512 --profile v3 --export
  /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export --threads 8
  --proof-out /tmp/hl_v3_32x512.bin` (with the ZB worktree's binary).

## Orchestrator note 2026-09-03 — round 11: ZB merged (fast-forward da4c395)

- The relaunch after the usage-limit cutoff found rungs 0-2 committed
  (a40b338) and rung 3's edits uncommitted; the resumed lane kept
  them in full and finished rungs 3-5. hashline now has `--profile
  v3 --export DIR`, tables_v3.rs, export_v3.rs, the v3 prover/
  verifier/tamper legs, `--log-cols`; MAC_RUNBOOK M9; results/
  hashline_v3_12x512.md. Floors for the crate: recorded below once
  the builds and the two byte gates (v2 50cf7bdf.., v3 5f368db6..)
  re-run here.
- THE MILESTONE: one real Mistral-7B FFN layer PROVEN on the WSL
  laptop's CPU (T=16: 10.53 s, 7.48 GB; T=256: 14.51 s, 10.28 GB;
  8/8 tamper legs reject) — the first 8B-width proof in this project
  (the lattice line's T15 rung has never run: OOM at 15 GB here).
  The Mistral v3 bins live under /home/victor/wt-uperf3-aa/results/
  m8b_mistral_v3_export/ (7 GB, not in git).
- QUEUED (orchestrator-run, after ZA frees the box): the full 32x512
  Mistral pass here — `hashline pass 32 512 --profile v3 --export
  /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export --threads 8
  --proof-out ...` (~10 min, ~13.5 GB [MODEL]; exit 137 = the record).
  If it fits, it is the FIRST FULL 8B FFN PROOF, on the laptop.
- Floors for the crate on the ZB-merged tree (this checkout; CPU
  build 16.6 s, 22/22 tests; GPU build 19.0 s): the v2 gate `pass 12
  512 --threads 8 --proof-out` -> sha256 50cf7bdf.. on CPU (PROVE
  17.69 s) and GPU (PROVE 2.97 s); the v3 gate `pass 12 512 --profile
  v3 --export <m125 v3 export> --threads 8 --proof-out` -> sha256
  5f368db6.. (70,758,084 B) on CPU and GPU — both byte-identical to
  ZB's record. NOTE FOR EVERY LATER LANE: the v3 export BINARIES are
  not in git and live only under /home/victor/wt-uperf3-aa/results/
  (m8b_test/m125_v3_export/, m8b_mistral_v3_export/ 7 GB,
  m8b_gemma4_v3_export/); the main checkout's and other worktrees'
  copies of those directories hold digests.txt + manifest.json only.

## Orchestrator note 2026-09-03 — round 11: ZA merged (the ZK form)

- CONFLICTS: hashline/src/lib.rs (both lanes' `pub mod` lines — kept
  both) and hashline/src/bin/hashline.rs (12 hunks: ZB's `--profile
  v3 --export` and ZA's `--zk --seed` collided in the doc comment,
  the Opts struct + initializer, the arg parser, the two dispatch
  lines, and — interleaved by git — the two lanes' whole function
  groups (tables_v3/check_export_v3/layer_v3/pass_v3 vs
  run_layer_zk/layer_zk/pass_zk). Resolved by: keeping both fields/
  arms/docs; the initializer carrying both lanes' defaults; the
  dispatch composed as `if zk && v3 { refuse with a message } else if
  zk { *_zk } else if v3 { *_v3 } else { v2 }`; and the interleaved
  region rebuilt as ZB's block followed by ZA's block, each with the
  shared tail lines. Composing `--zk` with `--profile v3` is a named
  follow-on (ZB listed it), NOT built.
- Floors on the merged crate (this checkout; CPU build 23 s, 27/27
  tests; GPU build 27 s): CPU gates v2 50cf7bdf.., v3 5f368db6..,
  zk-seed-1 021485e4.. (87,228,528 B; PROVE 16.62 s / VERIFY 0.46 s
  [8T NOISY-SHARED]); GPU gates recorded in the commit below.
- ZA's process note, recorded: one command in its session used a
  `cd /tmp &&` prefix against CLAUDE.md; no harm.
- ROUND 11 STATE: all EIGHT lanes merged (UU, VV, WW, XX, YY, ZZ,
  ZA, ZB). NEXT on this box: the queued 32x512 Mistral pass (the
  first full 8B FFN proof if it fits; ~13.5 GB). Rulings pending
  with Victor: the privacy mode; VV's three items; WW's h_sum note.
- GPU gates on the merged crate (HL_GPU=1, 8T): v2 50cf7bdf.. PROVE
  2.26 s; v3 5f368db6.. PROVE 2.56 s; zk-seed-1 021485e4.. PROVE
  3.98 s / VERIFY 0.42 s — all byte-identical to the CPU proofs and
  to the lanes' records.

## Orchestrator note 2026-09-03 — THE FIRST FULL 8B FFN PROOF [MEASURED, WSL-BOX CPU 8T NOISY-SHARED]

`flock /tmp/zk-heavy.lock /usr/bin/time -v hashline pass 32 512
--profile v3 --export /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
--threads 8 --proof-out <scratch>/mistral_32x512.bin` (the merged
crate at dc0dae3, CPU binary; detached with a .done marker):
**PASS-V3 ACCEPT: 32 x 512 (d 4096 f 14336): witness load+chain
136.37 s | PROVE 510.38 s | VERIFY 1.21 s | proof 1,234,936,956 B |
2.886e12 MACs | 5.655e9 proven MAC/s | wall 650.15 s; max RSS
13,985,580 kB; exit 0; PROOF sha256 dc980e81..**. Per layer 24.2 /
23.6 s (layers 0-1, cold) then 14.6-17.6 s. Phases summed: commit W
224.97 | commit A 81.77 | helpers + commit H 102.74 | matmul g/u
6.58 | matmul d 3.52 | zero-check F 50.82 | zero-check D 7.75 | PCS
openings 31.68 s. Log: results/hashline_mistral_32x512.log (3.3 KB,
committed); the 1.23 GB proof file stays in the scratchpad.
READINGS: the hash line proved the whole 8B FFN stack on the 15 GB
box that cannot hold one lattice-line layer; lane YY's [MODEL] for
this cell was 492 s (measured 510, +3.7%) — the Route-B model's 8B
row is validated; the per-model weight commit is 44% of the prove
(225 s), the per-proof remainder ~285 s; the proof is the sqrt
class (1.23 GB) — the PCS swap is the size lever.

## RULINGS (Victor, console 2026-09-03)

Victor, verbatim: "Let's continue with private inputs/ public weigths
for now, but add private weights as a todo. This looks like good
news, the 50 token per second target seems not too far out of reach
now. To clarify the Mistral test had a full proof? Attention and
everything included?"
1. **THE PRIVACY MODE = P1** (inputs/activations private, weights
   public) for the product path now. Lane ZA's `--zk` form is the
   P1 mechanism; the weight commitment stays public and cacheable
   per model.
2. **PRIVATE WEIGHTS (P2/P3) = A STANDING TODO**, not started: lane
   ZZ's option 2 (never send the sampled weight columns: a per-model
   Poseidon2 weight tree + a per-proof ZK inner proof of the column
   check; ~2 lane-weeks; spikes O2-1..O2-3; a written simulator
   required — Orion found unsound, ePrint 2024/1164). Board T-item
   added.
3. **THE CLARIFICATION, answered plainly (orchestrator)**: the
   2026-09-03 Mistral-7B 32x512 proof was FFN-ONLY — the three
   matmuls, the SiLU table, the requant/range facts of every
   feed-forward block, all 32 layers, in one chained transcript. NOT
   included: attention (Q/K/V/scores/softmax/context/output
   projections, RoPE), the norms, the embeddings/head, and the
   layer-to-layer seams (each layer's X was committed from the
   export, not derived from the previous layer's output — the same
   "FFN tower" limitation the lattice line's composed statement
   has). FFN-only tokens are ~69-78% of a real token's MACs
   (U_PERF3_THROUGHPUT_MODEL.md §1) and an unknown share of its
   PROOF cost (~3.5x per layer of statement mass [MODEL]). The
   attention statement on the hash line is round 12's long pole.

## ROUND 12 — THE P1 PRODUCT PATH: ATTENTION, THE 8B GPU NUMBER, THE SIZE LEVER (opened 2026-09-03)

Ground: round 11 closed (eight lanes merged, dc0dae3); the first
full 8B FFN proof measured (0bc3ad9: Mistral-7B 32x512, 510 s CPU,
1.23 GB, 14 GB). Every lane reads START_HERE.md first, then this
block, then its brief. Worktrees wt-uperf3-{ac,ad,ae,af} on branches
uperf3-{ac,ad,ae,af}. Standing rules = round 10's (no background
runs; > ~8 min posted as ORCHESTRATOR-RUN; one commit per rung;
labels; the byte gates: v2 50cf7bdf.., v3 5f368db6.. (export bins
ONLY under /home/victor/wt-uperf3-aa/results/), zk-seed-1
021485e4..; the lattice floors untouched — no lane below edits
zkmatrix-rs). ALL FOUR LANES EDIT hashline/: file ownership is
strict and the driver (src/bin/hashline.rs) is shared — each lane
adds ONLY its own flag lines and dispatch arms there, marked with
its tag, so the orchestrator's merge is mechanical.

THE GOAL RESTATED FOR THIS ROUND: >= 50 proven tokens/s at 30B on
one H100, mode P1, batched/prefill proving. What stands between the
measured 8B FFN-only CPU row and that: (1) attention + norms + seams
in the statement (the "full proof" — lane AE, the long pole); (2)
the per-model weight cache + the 8B pass on a GPU (the measured 8B
GPU number — lane AC); (3) zk composed with v3 so the 8B number is
the P1 number (lane AD); (4) the proof size (1.23 GB per 8B proof —
lane AF); (5) hardware (choice C, Victor); (6) the Mac's own 8B
number (M9, Victor).

### Lane AC — the per-model weight cache + the 8B pass on the GPU (wt-uperf3-ac) — RUST/CUDA
OWNS: NEW hashline/src/wcache.rs (the per-model weight-commitment
cache: commit each layer's W once, persist the Merkle roots + the
encoded rows or re-derive, verify-on-load by root; `--wcache DIR`),
hashline/src/gpu/* (ADDITIVE: chunked/streamed W encoding so a
4096x14336 int8 tensor's Reed-Solomon rows + Merkle tree are built
in device-sized chunks under the 8 GB part; the device buffer pool),
its flag lines in the driver (tag [UPERF3-AC]), NEW
results/hashline_8b_gpu_*, "Agent AC status". READ-ONLY: pcs.rs,
sumcheck.rs, transcript.rs, zk.rs (AD's), layer.rs/silu.rs/
export_v3.rs/tables_v3.rs (AE's/AF's interfaces), zkmatrix-rs/.
WHY: 225 of the 510 s of the 8B CPU pass are the weight commitments
— per-model work under P1 (public weights); and `HL_GPU=1` today
DECLINES the 5.4 GB W commit on the 8 GB part and falls back to CPU
bytes (lane ZB). The 8B GPU number is the anchor the 30B/H100
projection needs.
RUNGS (prefix "U-PERF3 AC:"): 0 skeleton + the plan + the gates
unchanged; 1 the weight cache on the CPU path: `pass 32 512
--profile v3 --wcache DIR` run twice — the second run skips the W
commits (root-verified), proof bytes IDENTICAL to the uncached run
(the same Merkle roots), per-proof prove wall recorded (expect ~285
s CPU); 2 the chunked W encoding on the device at 12x512 (v2 and
v3), bytes identical (50cf7bdf.. / 5f368db6..), the wall; 3 ONE
Mistral layer at T=512 on the GPU (`HL_GPU=1`), bytes identical to
the CPU layer proof, wall + VRAM; 4 THE 8B PASS ON THE GPU: `pass 32
512 --profile v3 --wcache` with `HL_GPU=1`, cold and warm cache,
proof bytes identical to the CPU pass (sha256 dc980e81.. for the
uncached form — state whether the cached form changes bytes; it
should not), walls, RSS, VRAM, proven MAC/s — ORCHESTRATOR-RUN if >
8 min; 5 RECORD: results/hashline_8b_gpu.md in XX's form + the §3
8B GPU row in PROVING_CHANNEL_OPTIONS.md + the tokens/s at 8B on
this laptop GPU (P0 and, once AD lands, P1) next to YY's model
cells.

### Lane AD — zero knowledge composed with the widened stack (wt-uperf3-ad) — RUST
OWNS: hashline/src/zk.rs (ADDITIVE: the v3 statement's ZK form —
the int16-output table lookups, the int16 range facts, the
round-nearest requant identity, all masked like the v2 ones), the
v3 hooks in layer.rs that ZA's form needs (ADDITIVE, tagged
[UPERF3-AD]; coordinate: lane AE also edits layer.rs — AD touches
only the existing v3 functions' ZK variants, AE adds NEW attention
functions), the `--zk` + `--profile v3` dispatch (replace the refusal
with the composed path), NEW results/hashline_zk_v3_*, "Agent AD
status". READ-ONLY: pcs.rs, sumcheck.rs, transcript.rs (ZA's ZK
primitives — reuse), gpu/* (AC's), export_v3.rs, tables_v3.rs.
WHY: the P1 mode is the product ruling; the 8B number (v3) and the
ZK form (v2 only) must be the same proof.
RUNGS (prefix "U-PERF3 AD:"): 0 skeleton; 1 the v3 ZK layer at 3x16
(uniformity test extended to the v3 opening sites — enumerate them);
2 the 12x512 v3 ZK pass, CPU and GPU byte-identical under a seed,
the 8 v3 tamper legs under `--zk`; 3 ONE Mistral layer under `--zk`
at T=512 (CPU; GPU if AC's chunked encoding has landed — else
record); 4 the surcharge table vs ZB's v3 rows and ZA's v2 ZK rows;
the ZK-v3 row in §3; 5 record.

### Lane AE — ATTENTION IN THE STATEMENT: the full-layer proof on the hash line (wt-uperf3-ae) — RUST + PYTHON (the long pole)
OWNS: NEW hashline/src/attention.rs (the attention statement), NEW
hashline/src/tables_attn.rs (the exp / inverse / rsqrt table
members), NEW hashline/src/norm.rs (RMSNorm), the NEW attention
functions in layer.rs (ADDITIVE, tagged [UPERF3-AE]; AD edits the
v3 FFN functions' ZK variants — do not touch those), NEW
scripts/m8b_mistral_attn_gate.py (the attention calibration gate for
the hf Mistral adapter: the CC/PP pattern), NEW
scripts/attention_hash_ref.py (the python oracle of the integer
attention chain), NEW results/m8b_mistral_attn_* and
results/hashline_attn_*, the `--attn` flag lines in the driver,
"Agent AE status". READ-ONLY: everything else in hashline/ (reuse
pcs/sumcheck/zk/gpu as libraries), zkmatrix-rs/ (the attention
DESIGN of record lives there: read docs/zkmatrix-poc/
U_PERF3_ATTENTION_STATEMENT_DESIGN.md, the ledger's Agent JJ (the
integer softmax chain X-S1: exp table members keyed (eS, d_h, fE),
the sum, the quotient/remainder normalisation), Agent NN (the
66-entry typed attention layer, RoPE rows, the value chain vs the
python oracle scripts/attention_x1_layer_ref.py — read that script),
Agent CC (the Gemma attention calibration gate:
scripts/m8b_gemma4_attn_gate.py — read it) and Agent PP (the 125M
gate: scripts/m125_attn_gate.py; results/m125_attn_at_o1.json)).
WHY (plain words): the 8B proof is FFN-only. A real token's layer is
attention + FFN with norms and a residual stream; "the full proof"
Victor asked about does not exist on either line beyond toy scale.
This lane builds it on the hash line, the same way the FFN was
built: exact integer semantics first (calibrated, measured
exponents), a python oracle, then the proof with the existing
primitives (the matmul sumcheck for Q/K/V/O projections and the
per-head QK^T and PV matmuls; LogUp tables for exp, the inverse in
the softmax normalisation, and the RMSNorm inverse-sqrt; zero-checks
for the requants, the residual adds and the layer-to-layer SEAM so
layer l+1's X is DERIVED from layer l, not committed fresh).
RUNGS (prefix "U-PERF3 AE:"): 0 skeleton + THE STATEMENT SPEC in
your status section (every tensor of one Mistral-7B layer — GQA
H 32 / H_kv 8, d 4096, d_h 128, RoPE — with its class (int8/int16),
its exponent source, and which primitive proves it; the seam; what
is deferred: KV cache/decode, the embedding/head); 1 THE CALIBRATION
GATE for Mistral attention (python; the CC pattern on the hf
adapter; the checkpoint is local — find it: /home/victor/models/
or where scripts/m8b_int8_calibration.py's --ckpt pointed for T12;
if absent, run the gate on the 125M frugal model's measured table
results/m125_attn_at_o1.json instead and say so): per-site range
profiles + the int8 first-order attribution + the widened-class
check -> results/m8b_mistral_attn_at_o1.json (the exponent table
the statement consumes) — CPU, minutes-class per site [MODEL];
STOP and record if the Mistral attention core is NOT int8-clean
(that would be a finding of the CC/PP kind); 2 THE PYTHON ORACLE of
the integer attention chain for one layer (scripts/attention_hash_ref.py)
reproducing the calibrated forward at 125M (bit-exact vs the hooked
walker, the PP pattern) and at Mistral layer 0; 3 THE RUST CHAIN
(unproven) reproducing the oracle's per-tensor digests at 125M and
Mistral layer 0; 4 THE PROOF at 125M for one FULL layer (attention +
FFN + norms + residual, seam-bound to the next layer's X), tamper
legs (a flipped score, a wrong exp entry, a wrong softmax quotient,
a wrong norm, a broken seam), CPU and GPU byte-identical; walls vs
the FFN-only layer; 5 the 12-layer 125M FULL-MODEL pass (seams
bound) and ONE Mistral full layer at T=16 (CPU; memory permitting),
measured; the row in §3 as "FULL LAYER" next to the FFN-only rows;
what remains for a true end-to-end proof (embeddings, the head, the
KV cache/decode regime).
This lane is multi-day; commit every rung; if you run out of
session, the ledger must let the next agent resume from the last
green rung.

### Lane AF — the proof-size lever: a compact polynomial commitment (wt-uperf3-af) — RUST
OWNS: NEW hashline/src/pcs_compact.rs (a second multilinear PCS
behind `--pcs compact`: a FRI/STIR/WHIR-class or batched-evaluation
construction that brings the per-proof bytes from the sqrt class
(1.23 GB at 8B; 66.8 MB at 12x512) to the MB class; the choice is
yours — read U_PERF3_ROUTE_B_THROUGHPUT.md §5 (the counted trade:
x0.94-1.4 prover for 3-12 MB per pass) and pick the construction you
can build and argue in one lane; state its soundness parameters),
the `--pcs` flag lines in the driver, NEW results/hashline_compact_*,
"Agent AF status". READ-ONLY: pcs.rs (the Ligero form stays the
default and byte-identical), sumcheck.rs, transcript.rs, zk.rs,
gpu/*, layer.rs, the v3 files.
RUNGS (prefix "U-PERF3 AF:"): 0 skeleton + the construction chosen,
its parameters and soundness stated in the status section; 1 the
PCS alone: commit/open/verify on random polynomials with tamper
legs; bytes vs the Ligero form at 2^14..2^20 rows; 2 the 12x512 v2
pass under `--pcs compact`: accept, tamper legs, bytes, prove and
verify walls vs the Ligero row (CPU; GPU if the NTT/hash primitives
already serve it — else record what a port needs); 3 the 12x512 v3
pass the same; 4 ONE Mistral layer at T=512 under `--pcs compact`
(CPU): bytes and walls; the projection for the 32x512 pass; 5 the
row in §3 + record; the ZK interaction stated (does the compact
form keep ZA's pads/masks? what changes?).

## Agent AC status (wt-uperf3-ac) — round 12

(lane appends below)

**RUNG 0 — SKELETON + THE PLAN + THE GATES: GREEN (2026-09-03, WSL-BOX,
8T, box idle at the time: load 0.1, 14 GB available, the other round-12
lanes not yet building; CPU + GPU binaries built clean in this tree).**
What landed: NEW `hashline/src/wcache.rs` (the per-model weight-commitment
cache behind `--wcache DIR`: `configure`, `commit_w`, the file format, the
verify-on-load, a stats line; module doc = the design of record), the mod
line in lib.rs, the ONE hook at each W-commit call site in layer.rs
(`pcs::commit(&w_pcs, &w_data, ntt)` -> `wcache::commit_w(.., &WKey::new(
profile, l, d, f, &wg_t, &wu_t, &wd_t))`, v2 and v3, tagged [UPERF3-AC];
`commit_w` IS `pcs::commit` when no dir is configured — no key digest, no
I/O), the `--wcache DIR` flag + the report line in the driver, and in
gpu/cuda.rs the ADDITIVE `dev_encode_only` (upload + encode, no hash: the
cached-W device store). `.wc` files and `results/hashline_8b_gpu_wcache/`
are git-ignored (root + crate .gitignore). Tests: **28/28** (27 + the new
`tree_roundtrip_and_every_corruption_rejected`: a flipped root byte, a
flipped leaf byte, a flipped inner-node byte, a flipped last byte,
truncation, a wrong key, a wrong row count and a wrong inv_rate are ALL
rejected on load; the honest file round-trips level for level).
THE GATES with the hook in place [MEASURED, WSL-BOX 8T, the heavy lock,
proofs written to the scratchpad and sha256'd by the binary]:
| gate | CPU binary | GPU binary (HL_GPU=1) |
|---|---|---|
| v2 `pass 12 512 --threads 8` | **50cf7bdfd6b5b182..** (66,844,928 B), PROVE 16.22 s, commit W 2.18 s | **50cf7bdfd6b5b182..**, PROVE 2.47 s, commit W 0.36 s |
| v3 `pass 12 512 --profile v3 --export .../m125_v3_export` | **5f368db6240e0614..** (70,758,084 B), PROVE 15.99 s, commit W 2.26 s | **5f368db6240e0614..**, PROVE 2.61 s, commit W 0.47 s |
| zk `pass 12 512 --zk --seed 1` | **021485e4f80ec695..** (87,228,528 B), PROVE 16.52 s | **021485e4f80ec695..**, PROVE 3.95 s |
All six = the round-11 references. [QUIET-ish: no other lane building.]

THE PLAN (design decisions, with the reasons):
(1) WHAT THE CACHE HOLDS: the whole Merkle tree of the W commitment (every
level, 2 x nn x 32 B = 4.2 MB per layer at nn = 2^16, the same at 125M
and at 7B), under a key = blake3(version tag, profile, l, d, f, log_cols,
inv_rate, rows, len, the three int8 planes' chained piece digests) — the
ACTUAL planes the prover holds, so a tampered W (the flipw leg) never
reuses an honest tree. Verify-on-load = every level re-hashed pairwise into
the next, the top == the stored root, the leaf count == nn; any failure is
a logged REJECT and a re-commit (never a silent reuse).
(2) WHAT IT CANNOT HOLD, and the consequence: the Q = 256 opened columns
are chosen by the transcript AFTER the W root is absorbed, so the prover
must produce ANY encoded column at opening time. pcs.rs (read-only) reads
them from `Store::Host { encoded }` (rows x nn, materialized) or, on the
device, from the `DevCommit`. So a warm cache removes the HASHING (blake3
over the 4x-expanded matrix, ~5.6 GB at 7B) and the tree build; the NTT
encoding is paid again at the opening — in full on the CPU path (the same
memory as today), CHUNKED on the device path (rung 2: never resident).
The counted alternative, persisting the encoded rows (5.6 GB per 7B layer,
180 GB per model; this box has 766 GB free), would remove the NTT on the
CPU too but the host store would still have to hold the matrix; and the
direct column evaluation (rows x n x Q int8-by-field products, 4.5e10 at
7B) is ~1-4 s per layer on this CPU [MODEL] against ~5 s for the NTT —
neither is built in this rung; the measured split is rung 1's record.
(3) THE CHUNKED DEVICE COMMIT (rung 2): `DevCommit.enc` becomes optional;
a commitment above `HL_GPU_CHUNK_BYTES` (default 1 GiB — the 12x512
commitments, 151-272 MB, stay on XX's resident path byte-for-byte and
clock-for-clock) is encoded in row chunks of `HL_GPU_CHUNK_ROWS` (default
1024, a multiple of 128 = blake3's 1024-byte chunk of a column) through a
STREAMING blake3 column kernel whose per-column CV stack lives in device
memory across launches; the opening re-encodes chunk by chunk and gathers
the Q columns (a new gather kernel with a row offset). At the 7B shape
this replaces the declined 5.4 GB allocation with ~0.65 GB of chunk
scratch and also takes A (1.85 GB) and H (1.54 GB) off the resident path,
so the layer's VRAM is ~3 GB instead of ~7.2. Probes: the chunked commit
and its re-encoded columns against the CPU encoder + `blake3::hash` at
row counts around every 128-row boundary (in `gpu-probe`).
(4) THE 7B GPU LAYER (rung 3) then the 8B PASS (rung 4), cold and warm.
Known and NOT in this lane's ownership: at the Mistral shape ZB's
`dev_shape` gate (layer.rs, nb_f == 1 && nb_d == 3) keeps the helpers and
the two zero-checks on the HOST (the XX kernels are fixed at 13/15
tables); those phases were 102.7 + 50.8 + 7.8 s of the 510 s CPU pass and
will remain host work in the GPU number — recorded, not touched.

**RUNG 1 — THE CACHE ON THE CPU PATH: GREEN, BYTE-IDENTICAL; THE 7B SPLIT
MEASURED (2026-09-03, WSL-BOX 8T, the heavy lock, box otherwise idle
[QUIET-ish]).** Cache dir `results/hashline_8b_gpu_wcache/{m125,mistral}`
(git-ignored); 4,194,372 B per layer entry (the 17-level tree of 2^16
leaves + the 100-byte header) — 50.3 MB for the 12 layers of either 125M
profile, 134 MB for the 32 Mistral layers [COUNTED].
THE 12x512 ROWS [MEASURED]: `pass 12 512 --threads 8 --wcache DIR
--proof-out F`, twice per profile (cold = every entry a MISS and written;
warm = every entry a HIT, verified level by level, the encoding rebuilt for
the opening):
| run | commit W (12 layers) | of which | PROVE | PROOF sha256 |
|---|---:|---|---:|---|
| v2 CPU cold | 2.12 s | pcs::commit 2.01 + key 0.013 + save 0.027 | 15.22 s | 50cf7bdfd6b5b182.. |
| v2 CPU warm | 1.74 s | load+verify 0.090 + re-encode (NTT only) 1.57 | 14.56 s | 50cf7bdfd6b5b182.. |
| v3 CPU cold | 2.18 s | pcs::commit 1.95 + save 0.027 | 15.20 s | 5f368db6240e0614.. |
| v3 CPU warm | 1.97 s | load+verify 0.097 + re-encode 1.67 | 15.50 s | 5f368db6240e0614.. |
| v2 GPU warm (HL_GPU=1, `dev_encode_only`) | 0.34 s | load+verify 0.087 + device upload+NTT 0.19 | 2.38 s | 50cf7bdfd6b5b182.. |
| v3 GPU warm | 0.46 s | load+verify 0.081 + device 0.19 | 2.62 s | 5f368db6240e0614.. |
`sha256sum` of the seven written proofs (cold, warm, GPU-warm, corrupted-
entry run) = the two reference digests, byte for byte. THE CORRUPTION LEG
at pass level: one leaf byte of `v2-l05-*.wc` flipped -> `wcache entry ...
REJECTED (level 0: 1 nodes do not hash to their parent); re-committing`
-> 11 hits + 1 miss, the entry rewritten, PROOF sha256 50cf7bdf.. again.
THE 7B SPLIT [MEASURED, one real Mistral-7B layer at T = 512 on the CPU,
`layer 0 512 --profile v3 --export .../m8b_mistral_v3_export --threads 8
--wcache`, /usr/bin/time -v; 13.2 GB peak RSS both runs]: cold commit W
**8.51 s** (pcs::commit 7.84 = NTT + blake3 over 5.64 GB + the tree +
the 5.64 GB allocation; save 0.014 s) -> warm commit W **6.43 s** (load+
verify 0.008 s; re-encode 5.49 s = the NTT alone; the rest the w_data
build); prove 22.7 -> 16.4 s (the other 4.4 s of that delta is the
`helpers + commit H` phase, 8.3 s cold vs 3.9 s warm — first-run noise on
a box that had just loaded 7 GB of export, not the cache); proof
38,688,700 B both; GREEN both.
READING (the honest one): on the CPU path the cache removes ~25% of the
W commit at 7B (~2.1 s of 8.5 s per layer, ~67 s of the 225 s over 32
layers [COUNTED from the one layer]); the other ~75% is the Reed-Solomon
re-encoding the OPENING needs — pcs.rs (read-only for this lane) serves
the Q sampled columns from a materialized host matrix, so the warm CPU
run still pays the NTT and the 5.6 GB. The orchestrator's "expect ~285 s"
assumed the whole 225 s vanishes; on this crate's CPU path the warm
32x512 pass models to ~510 - 67 = ~445 s [MODEL]. The two ways to remove
the remainder on the CPU are recorded, not built: (a) persist the encoded
rows (5.6 GB per layer, 180 GB per model — 766 GB free here; the host
store would still hold 5.6 GB per layer, so it trades the NTT for a disk
read of the same size, ~3-5 s at WSL disk rates [MODEL]); (b) serve the
opening's columns WITHOUT the matrix — a new `Store` variant in pcs.rs
(not this lane's) fed by a direct rows x n x Q evaluation. On the DEVICE
path the re-encode is ~0.19 s for the 12 layers (chunked at 7B in rung
2), so the cache's per-layer cost there is the load+verify (7 ms) plus
the upload — the GPU number is where the cache pays.
ORCHESTRATOR-RUN (posted; each ~9-11 min, ~14 GB peak; exit 137 is the
record): the 32x512 CPU pass cold then warm, and the warm-only form on
the pre-warmed dir the GPU runs will have written by rung 4:
  cold: `flock /tmp/zk-heavy.lock /usr/bin/time -v
  /home/victor/wt-uperf3-ac/hashline/target/release/hashline pass 32 512
  --profile v3 --export /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
  --threads 8 --wcache /home/victor/wt-uperf3-ac/results/hashline_8b_gpu_wcache/mistral_cpu
  --proof-out <scratch>/ac_32x512_cpu_cold.bin`  (expect PROOF sha256
  dc980e81.., 1,234,936,956 B; ~510 s prove + ~14 s of cache writes)
  warm: the same command again (the dir now holds 32 entries; expect the
  same sha256; commit W ~158 s instead of 225 [MODEL]).

**RUNG 2 — THE CHUNKED DEVICE COMMIT: GREEN, BYTE-IDENTICAL (2026-09-03,
WSL-BOX 8T + RTX 4070 Laptop, NOISY-SHARED from here on: the other
round-12 lanes started building, load 8-13).** What landed (gpu/*,
additive): `k_hash_cols_stream` — the streaming form of XX's blake3
column kernel: the encoded matrix arrives in ROW CHUNKS, every chunk but
the last a multiple of 128 rows (= 1024 column bytes = one blake3 chunk,
so a row-chunk boundary is a blake3 chunk boundary and no partial-chunk
state exists); the per-column CV stack (24 x 8 words + the length, 50 MB
at nn = 2^16) lives in a device state buffer across launches; the launch
holding the last row finishes the column with the same compressions and
flags as `b3_hash_column` and writes the leaf. `k_gather_cols_off` (the
opening's columns assembled chunk by chunk). `DevCommit.enc` is now
`Option`: a commitment whose encoding exceeds `HL_GPU_CHUNK_BYTES`
(default 1 GiB — the 12x512 commitments are 151-273 MB and stay on XX's
resident path clock for clock) or whose resident buffers cannot be
allocated is encoded in chunks of `HL_GPU_CHUNK_ROWS` rows (default 1024)
into reused scratch (a new "at least this long" pool take), hashed
streaming, and NEVER resident; `dev_columns` re-encodes the same chunks
at the opening and gathers the Q columns; the cached-W `dev_encode_only`
uploads only, in the chunked class. THE PROBE (`gpu-probe`, 15 new
shapes: rows 127/128/129/255/256/257/300/1024/1025 at chunk 128-256,
plus (12,4,1000,256), (14,4,64,128), (14,4,700,384), (13,2,4,128),
(12,8,3,128), (14,4,2200,1024)): **0 leaf mismatches and 0 column
mismatches at every shape** against the CPU encoder + `hash_columns`
[MEASURED]. THE GATES with EVERY 12x512 commitment forced through
128-row chunks (`HL_GPU_CHUNK_BYTES=0 HL_GPU_CHUNK_ROWS=128`: W in 3, A
in 5, H in 4 chunks per layer; 36 chunked commits per pass): v2
**50cf7bdfd6b5b182..** PROVE 2.86 s | v3 **5f368db6240e0614..** 3.25 s |
zk **021485e4f80ec695..** 4.77 s | warm-cache v2/v3 the same two digests
(3.16 / 3.17 s) — all byte-identical; the chunked form costs +0.4 s per
pass at this shape (the opening re-encodes, 0.42 s: it is the resident
path's job to be cheap here). THE DEFAULT PATH, same binary, same
session: 0 chunked commits, v2/v3/zk 2.76 / 2.91 / 4.17 s, the three
digests unchanged. Per-commit device walls at 12x512 (verbose, one
layer): W 288 rows in 3 chunks 0.018 s (ntt 0.013 + hash 0.001), A 520
rows 0.035 s, H 432 rows 0.023 s; the opening's re-encode + gather 0.008
/ 0.015 / 0.012 s. Commit 641a80a.

**RUNG 3 — ONE REAL MISTRAL-7B LAYER AT T = 512 ON THE GPU: GREEN,
BYTE-IDENTICAL TO THE CPU (2026-09-03, WSL-BOX 8T + RTX 4070 Laptop,
NOISY-SHARED, the heavy lock, /usr/bin/time -v).** `pass 1 512 --profile
v3 --export .../m8b_mistral_v3_export --threads 8 --proof-out F` (the
pass form so the device-side line and the sha256 print; d 4096, f 14336,
shifts 11/2/15/6):
| run | PROVE | commit W | A | helpers+H | matmul | zcF (host) | zcD (host) | openings | RSS | VRAM peak | PROOF sha256 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| CPU (the reference) | 16.55 s | 6.69 | 2.12 | 4.24 | 0.57 | 1.52 | 0.24 | 1.14 | 12.69 GB | — | 179ec2fb8f99d0d6.. (38,688,700 B) |
| GPU, no cache | **5.56 s** | 1.14 | 0.39 | 1.00 | 0.27 | 1.66 | 0.25 | 0.82 | 4.16 GB | **4,175 MB** | **179ec2fb8f99d0d6..** |
| GPU, cache cold (writes 4.2 MB) | 5.57 s | 1.24 | 0.38 | 1.04 | 0.27 | 1.57 | 0.25 | 0.81 | 4.18 GB | 4,175 MB | 179ec2fb8f99d0d6.. |
| GPU, cache warm | **4.94 s** | **0.80** | 0.41 | 0.98 | 0.25 | 1.41 | 0.25 | 0.82 | 4.16 GB | 4,175 MB | 179ec2fb8f99d0d6.. |
`sha256sum` of the four written proofs: one digest. So the 5.4 GB W
encoding that `HL_GPU=1` DECLINED on this part (lane ZB) is now committed
in **11 chunks of 1024 rows** (W 10,752 rows; A 3,520 rows in 4; H 2,944
rows in 3), the whole layer at **3.0x the CPU wall in a third of the
memory and half the part's VRAM**. Device-side (cold): h2d 0.49 s for
2.26 GB, ntt 0.52 s, fold 0.22 s; the opening's chunked re-encode +
gather 0.51 s (W 0.31 in 11 chunks, A 0.09, H 0.08). The cache on the
GPU saves 0.34 s per layer (the commit-time NTT + hash: commit(miss) 0.71
s -> upload only), i.e. ~11 s per 32-layer pass [COUNTED]. WHAT REMAINS
HOST WORK at this shape and why: zero-check F 1.4-1.7 s + zero-check D
0.25 s + the helper columns (~0.7 of the 1.0 s "helpers + commit H") run
on the CPU because ZB's `dev_shape` gate (layer.rs: nb_f == 1 && nb_d ==
3, outside this lane's ownership) keeps the XX kernels — fixed at 13 / 15
tables — to the 125M block shape; at Mistral the F-side zero-check has
73 tables (7 f-blocks x 10 + 3 eq). That is ~2.4 s of the 4.9-5.6 s
layer, the next lever (a block-looping zero-check kernel: same register
footprint as zc20, one f-block at a time). Also host: the w_data / a_data
Fp conversions + their pageable upload (~0.8 s), the matmul folds (0.25
s), the opening's claim bookkeeping + Merkle paths + serialization (~0.3
s). Projection for the 32-layer GPU pass: ~178 s cold / ~158 s warm
prove + ~110 s witness load [MODEL] — under the 8-minute line, so run
here (rung 4).

**RUNG 4 — THE 8B PASS ON THE GPU: GREEN, BYTE-IDENTICAL TO THE CPU PASS
(2026-09-03, WSL-BOX 8T + RTX 4070 Laptop 8.6 GB, the heavy lock,
/usr/bin/time -v, [NOISY-SHARED] — see the noise note below).**
`pass 32 512 --profile v3 --export /home/victor/wt-uperf3-aa/results/
m8b_mistral_v3_export --threads 8 --wcache DIR --proof-out F` under
`HL_GPU=1`, run twice on the same cache dir (cold = 32 misses written;
warm = 32 hits, each tree verified level by level):
| run | witness load+chain | PROVE | VERIFY | wall | proof B | RSS | VRAM peak | proven MAC/s |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| CPU reference (orchestrator, uncached) | — | **510.38 s** | 1.21 s | — | 1,234,936,956 | 13.99 GB | — | 5.655e9 |
| **GPU, cache cold** | 130.75 s | **175.09 s** | 1.09 s | 308.82 s | 1,234,936,956 | **5.33 GB** | **4,175 MB** | **1.648e10** |
| **GPU, cache warm** | 138.02 s | **193.29 s** | 1.24 s | 334.93 s | 1,234,936,956 | 5.33 GB | 4,175 MB | 1.493e10 |
THE BYTE VERDICT: `sha256sum` run by hand over the three 1.23 GB files —
the orchestrator's uncached CPU proof, the GPU cold-cache proof and the
GPU warm-cache proof — is ONE digest,
**dc980e810085b2ddf4688eb4a6cf4dd931c209bf7c5a9a7692d57ec14bc4536c**
(1,234,936,956 B), the merged CPU reference. So the 8B proof is invariant
under: device vs host, chunked vs resident commitment, and cached vs
freshly committed weights. (The fourth configuration, *cached CPU* at
32x512, is the ORCHESTRATOR-RUN posted in rung 1 — at ~445 s prove +
~130 s load it is over this lane's 600 s ceiling; the cached CPU form is
byte-identical at 12x512, both profiles, and at one Mistral layer
(179ec2fb..), so nothing about 32 layers can change it: the cache never
enters the transcript, it only skips recomputing the same Merkle tree.)
THE HEADLINE: **the 8B FFN pass proves in 175 s on a laptop GPU instead
of 510 s on 8 CPU threads — 2.92x — in 5.33 GB of host RSS instead of
13.99 (2.6x less) and 4,175 MB of the part's 8,188** [MEASURED].
PER-LAYER (cold): mean **5.472 s**, min 5.314, max 5.661 — 32 layers
within +/-3.5%, the rung-3 single-layer number (5.56 s) reproduced at
pass scale. Warm: mean 6.040, min 5.446, max **8.855** — the spread is
the box, not the cache (lane AF's `pass 12 512` gates and a lane-AE
python were on the CPU during the warm run; the cold run had the box to
itself for the GPU).
PHASES, summed over the 32 layers [MEASURED, s]:
| phase | GPU cold | GPU warm | CPU (merged reference) |
|---|---:|---:|---:|
| commit W | 38.85 | 34.66 | 224.97 |
| commit A | 13.53 | 16.51 | 81.77 |
| helpers + commit H | 35.24 | 45.16 | 102.74 |
| matmul g/u | 5.38 | 6.12 | 6.58 |
| matmul d | 2.86 | 3.40 | 3.52 |
| zero-check F (HOST) | 46.64 | 53.36 | 50.82 |
| zero-check D (HOST) | 7.48 | 8.30 | 7.75 |
| pcs openings | 24.61 | 25.25 | 31.68 |

The two zero-checks and the matmul folds are the CPU's cheap phases and
the GPU's expensive ones: zcF is 50.8 s on the CPU and 46.6 s on the GPU
(it never left the host), and the matmuls are already so cheap on the CPU
(6.6 + 3.5 s) that the device only halves them. **Every second the device
actually won came from the three commitments and the openings: 441.2 s of
CPU work -> 112.2 s** (3.9x), which is the honest statement of what the
laptop part buys on this statement.
Device-side (cold): h2d **15.72 s for 72,209 MB**, ntt 15.63 s, fold
6.75 s, d2h 1,413 MB; **96 chunked commits** (W, A and H at every layer —
none of the three fits the resident path at this width) and the opening's
chunked re-encode 15.73 s. Warm: ntt **8.23 s** (the cache's commit-time
NTT gone), 64 chunked commits (W is upload-only), re-encode 15.77 s.
THE WEIGHT CACHE AT 8B, honestly attributed [MEASURED, internal
accounting — immune to the box noise that moved the wall]: cold
`commit(miss) 21.02 s + key 0.49 + save 0.06` for 32 layers vs warm
`load+verify 0.49 + re-encode 11.53 + key 0.52`, i.e. the cache removes
**9.0 s of the 32-layer prove on the GPU path** (corroborated by the
device NTT, 15.63 -> 8.23 s) and 134.2 MB of reads replaces the hashing
and tree-building of 180 GB of expanded weight rows. On the CPU path the
same cache removes ~2.1 s per layer, ~67 s of the 510 s (rung 1). It is
NOT the lever at 8B on either path: the opening still needs every column,
so the Reed-Solomon re-encoding is paid every run (11.5 s device, ~176 s
host [COUNTED from rung 1's 5.49 s/layer]). The cache's real payoff is
the 4.2 MB/layer proof-of-work reuse across passes and the fact that a
tampered W can never reuse an honest tree (the key covers the planes).
WHAT WOULD MOVE THE REMAINING 175 s: the two zero-checks are still HOST
work at this shape (46.6 + 7.5 = **54.1 s, 31% of the pass**) because
ZB's `dev_shape` gate (layer.rs, nb_f == 1 && nb_d == 3 — outside this
lane's ownership) keeps the XX kernels, fixed at 13/15 tables, to the
125M block shape while Mistral's F-side check has 73 tables. A
block-looping zero-check kernel is the single next lever: ~54 s -> ~5 s
[MODEL] would take the pass to ~125 s (4.1x the CPU). After that the
host remainder is the helper columns and the Fp conversions inside
"helpers + commit H" and the openings' Merkle/serialization (~35 s), and
the h2d itself (15.7 s for 72 GB — the pageable-copy rate; pinned
staging would roughly halve it [MODEL]).
THE 8-MINUTE RULE: both runs were under it (5:11 and 5:38 wall), so they
were run in-lane, not posted.

**RUNG 5 — THE RECORD (2026-09-03).** Three files, in XX's form:
(1) **NEW results/hashline_8b_gpu.md** — the 8B GPU row: what was
proven and the one gate (the 1.23 GB proof is ONE sha256 across the
uncached CPU pass, the GPU cold-cache pass and the GPU warm-cache pass);
the runs table (CPU 510.38 / GPU cold 175.09 / GPU warm 193.29 s prove,
RSS 13.99 / 5.33 / 5.33 GB, VRAM 4,175 MB, 1.648e10 proven MAC/s); the
per-layer anatomy phase by phase against the CPU pass, with the
factor column that shows WHERE the device won (commitments and openings
441.16 -> 112.23 s, 3.9x; everything else 1.0-1.3x because it is still
host work); the device accounting (h2d 15.72 s for 72,209 MB, chunked
encode+hash 15.63 s, opening re-encode 15.73 s, folds 6.75 s = 53.8 s,
31% of the prove) with the two DIFFERENT reasons the `hash`, `sumcheck`
and `helpers` counters read 0.000 (the chunked path folds hash into the
encode counter unless --verbose — hashing did NOT leave the device; the
zero-check and helper kernels genuinely never ran); the weight-cache
section (9.0 s of the GPU prove, ~67 s of the CPU's — and why no more:
the Q = 256 columns are drawn after the root is absorbed, so the RS
re-encode is paid every proof, ~176 s of the CPU's 225 s W phase); the
host-remainder table with each item's lever [MODEL]; the tokens/s
verdict; and the side-by-side against the CPU 8B row and XX's 125M GPU
row.
(2) **the §3 row in docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md** —
"THE 8B ROW ON THE GPU" directly under the 8B CPU row (175.1 s cold /
193.3 warm, 1.09 s verify, 1,234.9 MB BYTE-IDENTICAL dc980e81.., 5.33
GB + 4,175 MB VRAM, 1.65e10 MAC/s, [MEASURED, NOISY-SHARED]) plus the
"Lane AC's 8B GPU row LANDED" paragraph at the end of the section, in
the form of XX's and ZA's.
(3) **the measured cells in U_PERF3_ROUTE_B_THROUGHPUT.md §6.2** — the
first measured 8B cells against YY's model.
THE TOKENS/S VERDICT (the question the rung asked): at 8B prefill
T = 512, mode P0, FFN-only, prover clock —
| cell | YY's [MODEL] §6.2 | [MEASURED] here | verdict |
|---|---|---:|---|
| laptop CPU 8T | 1.0 tok/s | **1.00** (512/510.38) | INSIDE — exact |
| laptop GPU | 5.2-16 tok/s | **2.92** (512/175.09) | **BELOW the band, 1.8x** |
| laptop GPU, proven MAC/s (§6.5) | 2.9e10-8.8e10 | **1.648e10** | BELOW, 1.76x |
The band assumed §3.3's "Route B's work is entirely device-shaped".
True at 125M (XX: 5.3x over its own CPU form), NOT true at Mistral
width: **76 s of the 175 (44%) are the two zero-checks and the LogUp
helper columns on the HOST**, declined by ZB's `dev_shape` gate because
XX's kernels are templated on the 125M block shape (13/15 tables) while
Mistral's F-side check has 73; ~42 s more is host conversion, Merkle
levels and serializing 1.23 GB. The realized factor is **2.92x**, not
5-15x. Fixing the shape gate (a block-looping zero-check kernel — ZB's
file, byte-preserving) models to 105-125 s = 4.1-4.9 tok/s, still under
the band; the band's low end needs the conversion/upload and Merkle
items too. This is the first test of that premise at a real model
width, and the H100 columns rest on the same premise — recorded as a
caution, not a claim about them.
THE GATES, re-run in this tree after the rung-4/5 work — ALL SIX GREEN
[MEASURED, NOISY-SHARED: the six runs queued behind lane AE's Mistral
attention gate on `flock /tmp/zk-heavy.lock`, as the shared-box rule
requires; load 4-20 across them, so the walls are upper bounds]:
| gate | CPU | GPU (HL_GPU=1) |
|---|---|---|
| v2 `pass 12 512 --threads 8` | **50cf7bdfd6b5b182..** (PROVE 15.15 s, verify 0.31) | **50cf7bdfd6b5b182..** (PROVE 2.79 s, verify 0.24) |
| v3 `pass 12 512 --profile v3 --export .../m125_v3_export` | **5f368db6240e0614..** (16.78 s, 0.31) | **5f368db6240e0614..** (2.94 s, 0.26) |
| zk `pass 12 512 --zk --seed 1` | **021485e4f80ec695..** (17.30 s, 0.54) | **021485e4f80ec695..** (3.98 s, 0.39) |
All six = the round-11 references; `sha256sum` over the six written
proof files gives the same three digests as the binaries' own prints.
NO CODE CHANGED in rungs 4-5 (`git status`: PROGRESS, two docs, the new
record — no .rs, no .cu), so the rung-0 test suite (28/28) and the
rung-2/3 device probes stand as recorded.
WHAT THE NEXT AGENT SHOULD PICK UP, in order: (a) the block-looping
zero-check / helper kernels behind ZB's `dev_shape` gate — worth ~1.5x
of the 8B pass and the difference between 2.9 and 4.9 tok/s; (b) the
raw-plane upload with device-side i8/i32 -> Fp conversion and pinned
staging (~10-15 s); (c) if a warm-CPU 32x512 number is wanted for the
record, the ORCHESTRATOR-RUN posted in rung 1 (the cache dir
results/hashline_8b_gpu_wcache/mistral_gpu_cold is now warm with all 32
entries, written by the GPU run — the CPU binary reads the same file
format, so that run needs no cold pass first).

**THE FOURTH CONFIGURATION CLOSED (2026-09-03, after rung 5).** The
rung-4 ACCEPT asked for byte identity in four configurations; three
were run at 32 layers and the fourth (cached CPU) is over this lane's
600 s ceiling there. Closed instead at Mistral width at PASS scale, a
2-layer triple run back to back on the same loaded box
(`pass 2 512 --profile v3 --export .../m8b_mistral_v3_export`)
[MEASURED, NOISY-SHARED, load 4-12]: **CPU no cache PROVE 44.69 s |
CPU warm cache 37.67 s (2 hits, load+verify 0.032 s, re-encode 11.40 s)
| GPU warm cache 10.74 s — all three 77,307,784 B, all three sha256
b0efed43a7bb1d35ba99d534f31dcb95766ae99ff95c6f69f9df487d83ba31b4**
(`sha256sum` over the three files). So every cache/device combination
is now byte-identical at 7B width in a chained multi-layer transcript,
not only in the single-layer form. Side result: at this width the CPU
cache saves 3.5 s per layer under load (rung 1's quieter single-layer
figure was 2.1), and the same-conditions GPU/CPU prove ratio at two
layers is 4.2x (the 32-layer figure, 2.92x, is the one to quote — its
CPU reference ran on a quieter box).

## Agent AD status (wt-uperf3-ad) — round 12

(lane appends below)

### AD rung 0 — the plan, the hooks, the gates re-run (2026-09-03)

- Read: START_HERE, the round-12 block and this brief, Agent ZA and ZB
  in full, the crate (zk.rs, layer.rs, pcs.rs, sumcheck.rs,
  transcript.rs, the driver, export_v3.rs, gpu/mod.rs + the cuda.rs
  entry points).
- THE PLAN (the [UPERF3-AD] block at the end of hashline/src/zk.rs):
  ZA's five constructions kept as built and applied to ZB's objects —
  mask rows per block-structured plane per opening point (7 nb_f at
  rho_F, 3 nb_d at rho_D, nb_d X-blocks at p2, nb_f h16-blocks at p5),
  the ACT16 table, the INT16 class (2^16 rows) and the four balanced
  remainder windows (one per signed shift, no dedup: 6 slots per layer)
  as COMMITTED multiplicity tables with masks of their own shape. THE
  ONE STRUCTURAL ADDITION: a table larger than a commitment row (the
  INT16 class is 2^16 rows against n = 2^14; a 2^15 window at sh_h = 15
  — the 125M export has sh_h in {13, 14, 15}, Mistral layer 0 has 15)
  occupies 2^log_size / n consecutive rows of A/H, and the table
  zero-check runs over log_S = max(log n, 16) variables with every slot
  zero-extended; a slot's opened claim carries the public coefficient
  prod_{j<k}(1 - rho_j) at the point rho[k..], every slot's column tail
  being the last log n coordinates of rho_tab (one group). ZA's
  single-row TabRows cannot hold these (its assert would fire). The
  requant identities fold linearly as in ZB's form (the field inverse
  of 2^-sh at sh <= 0). RNG domain "layer-v3-{l}".
- Hooks in layer.rs (ADDITIVE, tagged): `absorb_statement_v3` and
  `rem_index` made pub (two lines). Nothing else of ZB's or AE's
  regions touched.
- THE GATES on this tree before any code [WSL-BOX] [8T] [NOISY-SHARED:
  three other lanes building] [MEASURED], `flock /tmp/zk-heavy.lock
  /usr/bin/time -v`, 12x512:
  | gate | CPU sha256 / PROVE / RSS | GPU (HL_GPU=1) sha256 / PROVE / RSS / VRAM |
  |---|---|---|
  | v2 `pass 12 512` | 50cf7bdfd6b5b182.. / 14.77 s / 1.56 GB | 50cf7bdfd6b5b182.. / 2.43 s / 0.78 GB / 2.43 GB |
  | v3 `--profile v3` | 5f368db6240e0614.. / 15.31 s / 1.21 GB | 5f368db6240e0614.. / 2.97 s / 0.43 GB / 2.43 GB |
  | zk `--zk --seed 1` | 021485e4f80ec695.. / 19.00 s / 1.67 GB | 021485e4f80ec695.. / 4.81 s / 0.90 GB / 3.03 GB |
  All six byte-identical to the round-11 records (CPU build 32 s, GPU
  build 30 s). Process note: one gate command line carried a `cd /`
  prefix against CLAUDE.md; no harm, not repeated.

### AD rung 2 — the 12x512 v3 ZK pass, CPU == GPU, the eight legs (2026-09-03)

- **THE NEW GATE** (`pass 12 512 --zk --seed 1 --profile v3 --export
  results/m8b_test/m125_v3_export --threads 8 --proof-out`):

      sha256 40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17
      87,697,008 B [ZK v3 seed 1]

  from the CPU-only binary (3 runs) AND from the gpu-cuda binary with
  `HL_GPU=1` (3 runs); `cmp` of the written files agrees. ACCEPT on
  both. 3x16: `4d9f7632..` (10,272,540 B) CPU and GPU (rung 1's,
  reconfirmed); seed 2 at 3x16 `ff8cbbd3..` — a different proof of the
  same statement, the same size.
- **THE THREE OLD GATES, re-run on this tree at this rung, CPU and
  GPU: UNCHANGED.** v2 `50cf7bdfd6b5b182..` (66,844,928 B, CPU 15.16 s
  / GPU 2.53 s), v3 `5f368db6240e0614..` (70,758,084 B, CPU 15.76 s
  p50 / GPU 2.75 s p50), zk-v2 `021485e4f80ec695..` (87,228,528 B, CPU
  17.42 s / GPU 3.98 s).
- The ladder [WSL-BOX] [8T] [GPU|CPU] [NOISY-SHARED — and noisy for
  real: lanes AC/AE/AF built and ran throughout, load average 5-21,
  three of these runs queued 5-13 min on `flock /tmp/zk-heavy.lock`],
  `/usr/bin/time -v`, 3 runs each:

  | row | PROVE p50 | VERIFY | bytes | RSS | VRAM |
  |---|---:|---:|---:|---:|---:|
  | CPU zk-v3 (17.87/18.41/18.64) | **18.41 s** | 0.43 s | 87,697,008 | 1.27 GB | — |
  | CPU v3 non-zk (15.58/16.13/15.76) | 15.76 s | 0.29 s | 70,758,084 | 1.21 GB | — |
  | GPU zk-v3 (5.63/4.63/6.15) | **5.63 s** | 0.54 s | 87,697,008 | 0.53 GB | 4.44 GB |
  | GPU v3 non-zk (3.04/2.75/2.63) | 2.75 s | 0.31 s | 70,758,084 | 0.42 GB | 2.43 GB |

  ZK surcharge on v3: CPU +16.8% prove / +23.9% bytes / +5.0% RSS;
  GPU +105% / +23.9% / +25% RSS / +83% VRAM. zk-v3 over zk-v2: CPU
  +5.7%, **bytes +0.54% (+468,480 B)** — the widened statement is not
  more expensive to HIDE.
- **THE FINDING (and the one lever).** The table zero-check runs ON THE
  HOST (ZA built it there; the device port was a listed, unapplied
  lever). At v3 it is a sumcheck over **2^16** variables — the INT16
  class alone is 4 rows of m, 4 of its mask, 8 of its Fp2 helper and 8
  of that helper's mask — and costs **1.14 s on the GPU run: 20% of
  the whole GPU prover, and +0.90 s of the +1.65 s that zk-v3 costs
  over zk-v2** (on the CPU the same phase is 1.26 vs 0.40 s, +0.86 of
  +0.99 s — the same absolute work, invisible against a 15 s CPU
  baseline). Porting it to lane XX's device kernels is byte-preserving
  and would put the GPU zk-v3 prover back at ~4.7 s. NOT done here.
- **THE EIGHT LEGS, at T = 512, under `--zk`, on BOTH provers**
  (`layer L 512 --zk --seed 1 --profile v3 ... --all-tampers`), at
  **layer 0** (shifts 9/1/14/10) and at **layer 3** (8/-1/14/9, the
  exact up-scaling branch): 8/8 REJECT each time, `GREEN` four times.
  The split is ZA's: flipped X, flipped Wg, wrong requant (h16) and
  wrong z die at `sumcheck round 0: s(0) + s(1) != claim`; the four
  LOOKUP legs (out-of-range remainder, wrong int16 table entry, WRONG
  ROUNDING, out-of-range int16) die at `H: pcs zk: group 4: <v, c> !=
  combined claim` — the value-0 LogUp sum claim, where the non-zk
  verifier rejected in clear text. Identical rejection strings CPU and
  GPU. The two legs v3 adds over v2 are both lookup legs and both are
  caught at layer 3 as well: the negative-shift branch is inside the
  masked form, not beside it. Pass-level: `pass 12 512 --zk --seed 1
  --profile v3 --tamper requant` -> `layer 6: REJECT: sumcheck round 0`
  on CPU and GPU.

### AD rung 3 — ONE Mistral-7B layer in zero knowledge at T = 512 (2026-09-03)

`layer 0 T --zk --seed 1 --profile v3 --export
results/m8b_mistral_v3_export --threads 8`, d 4096, f 14336, log_cols
14; statement shifts 11/2/15/6, member `silu-int16out-table-v3`
(-3,-12) 859344ba5ed57bd3.. `free -g` showed 13 GB available at the
start (below the 14 the brief asked for), so the T = 256 pair was run
first as the safe rung; T = 512 then fitted with ~1.7 GB to spare and
**no swapping** (`Swaps: 0`). [WSL-BOX] [8T] [CPU] [NOISY-SHARED]:

| row | PROVE | VERIFY | bytes | RSS |
|---|---:|---:|---:|---:|
| **T=512 ZK CPU (18.67/15.14/15.73)** | **15.73 s p50** | 0.056 s | **40,186,228** | **13.29 GB** |
| T=512 non-zk v3 CPU (15.40/14.65/15.02) | 15.02 s p50 | 0.038 s | 38,688,700 | 13.17 GB |
| **surcharge** | **+4.7%** | +0.018 s | **+3.9%** | **+0.9%** |
| T=512 ZK `HL_GPU=1` | 17.01 s | 0.053 s | 40,186,228 | 10.13 GB |
| T=256 ZK CPU (1 run, quiet window) | 11.80 s | 0.046 s | 33,566,932 | 10.40 GB |
| T=256 non-zk v3 CPU (1 run) | 15.64 s | 0.045 s | 32,069,404 | 10.28 GB |

ACCEPT on every row. (The T = 256 ZK run is FASTER than its own
baseline — one run each, a quiet window; that is the box, not a
discovery. Read the T = 512 triples.)

**THE READING — the important result of this lane.** At 125M the P1 ZK
form costs +17% prover / +24% bytes; at 8B WIDTH it costs **+4.7% /
+3.9%**, back inside U_PERF3_ROUTE_B_THROUGHPUT.md's [COUNTED] +2-8% /
+1-8% band that the 125M measurement had blown through. Structural,
not lucky: mode P1 hides the activations and leaves the WEIGHTS
public, and as the model widens the prover and the proof are dominated
by the weight commitment (6.6-9.1 s of a 15 s prover) and its 256-
column openings (~22 MB of a 39 MB proof), neither of which the ZK
form touches; the masked objects grow with T x (d + f), not d x f.
**The P1 surcharge shrinks as the model grows.** The 32 x 512 8B pass
in mode P1 therefore models to **~534 s / ~1,283 MB** [MODEL, this
one-layer ratio x 32] against the measured 510.4 s / 1,234.9 MB in the
clear — the 8B FFN proof is affordable in zero knowledge on this
laptop today.

**The GPU at the 8B shape**, as the brief anticipated: `HL_GPU=1`
DECLINES the weight commitment —
`[UPERF3-XX] gpu commit declined (cuMemAlloc(5376 MB):
DriverError(CUDA_ERROR_OUT_OF_MEMORY, "out of memory")); CPU path` —
and falls back to the host for W (8.07 s) while the ACTIVATION side
does run on the device (commit A 0.98 s vs 2.88 s on the host); the
two zero-checks stay on the host by design at this block shape (nb_f
7, nb_d 1). Net 17.01 s, no faster than CPU-only, same proof bytes.
**Lane AC's chunked/streamed W encoding is not in this lane's base** —
composing it with this ZK path is a base change and an untaken
measurement.

### AD rungs 4-5 — the surcharge table, the §3 row, the record (2026-09-03)

- The surcharge table is rung 2's ladder plus rung 3's rows, all on
  THIS tree in THIS session (so the four channels are comparable):

  | statement / form | CPU prove | GPU prove | bytes |
  |---|---:|---:|---:|
  | v2 non-zk | 15.16 s | 2.53 s | 66,844,928 |
  | v3 non-zk | 15.76 s | 2.75 s | 70,758,084 |
  | ZK v2 (ZA's form) | 17.42 s | 3.98 s | 87,228,528 |
  | **ZK v3 (this lane)** | **18.41 s** | **5.63 s** | **87,697,008** |
  | ZB's v3 record (quieter box) | 17.40 s | 2.74 s | 70,758,084 |
  | ZA's v2 ZK record (quieter box) | 16.55 s | 3.93 s | 87,228,528 |
  | **Mistral-7B layer 0, T=512, ZK v3** | **15.73 s** | 17.01 s (W declined) | **40,186,228** |
  | Mistral-7B layer 0, T=512, non-zk v3 | 15.02 s | — | 38,688,700 |

- results/hashline_zk_v3_12x512.md written in the form of
  results/hashline_zk_12x512.md (what is proven / hidden / STILL
  REVEALED, the one structural addition, the gate block, the
  enumerated v3 opening sites as the driver prints them, the runs, the
  phases, the legs, the 8B row, the soundness parameters, the
  uniformity test, the commands).
- docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md §3: two ZK-v3 rows in
  the main table (GPU and CPU), a ZK 8B-layer row next to the 8B row,
  and the "Lane AD JOINED THE TWO" paragraph.
- **WHAT MODE P1 NOW COVERS at the 8B semantics**: one FFN layer and a
  12-layer FFN pass of the WIDENED (v3) statement — the statement the
  8B proof runs — with the inputs and every activation private, on the
  laptop CPU and (at 125M) byte-identically on the laptop GPU.
  **STILL REVEALED**: the weights and the entire W opening (mode P1 by
  definition; private weights are T18); the shapes and the block
  structure; the four SIGNED shifts, which publish the remainder
  windows' sizes; the table digests and the activation member's family
  name; the uniform masked values. **Outside the statement entirely**:
  attention, the norms, the embeddings, the head and the layer seams
  (X_l is still committed fresh per layer — lane AE's build). ZA's
  simulator caveat is inherited unchanged: per-object uniformity is
  what is established (the uniformity test + the run-time site
  assertion), not a composed simulator for the chained transcript.
- Suites at close: `cargo test --release` 28/28 green.
  `python3 -m unittest discover -s tests` 81 tests, 12 skipped, **1
  pre-existing environment error**: `ring_matmul freeze-check` aborts
  at the m125-export section because `results/m125_ffn_export/*.bin`
  is gitignored and **the WSL box has no m125 export (Mac-only rig)**
  — 102 freeze rows pass before it, the binary is zkmatrix-rs
  (READ-ONLY, untouched by this lane), and the condition is present in
  every worktree on this box. Not a regression from this work.
- NOT DONE / next: the table zero-check on the device (the one
  byte-preserving lever, ~-0.9 s GPU); the composition with lane AC's
  chunked W encoding for a GPU 8B ZK row; the 32 x 512 8B pass under
  `--zk` (measured, not modelled); ZA's other listed levers (DIF/DIT
  NTT for the ZK encode, folding the matmul terminals back into the
  zero-checks) still unapplied.


## Agent AE status (wt-uperf3-ae) — round 12

LANE: attention, norms and the layer-to-layer seams in the hash-line
statement — the FULL-LAYER proof (the round-12 Lane AE brief above).
Worktree wt-uperf3-ae, branch uperf3-ae. Multi-day; one commit per
rung; every wall [WSL-BOX] [8T] [CPU|GPU] [NOISY-SHARED] (lanes AC/AD/AF
build and run on the same box).

OWNS (recorded): NEW hashline/src/{attention,norm,tables_attn}.rs (+ the
three `pub mod` lines in lib.rs), NEW attention functions in layer.rs
tagged [UPERF3-AE] (additive; AD's v3 ZK variants and AC's W-commit call
site untouched), the `--attn` flag lines + dispatch arms in
src/bin/hashline.rs tagged [UPERF3-AE], NEW scripts/m8b_mistral_attn_gate.py,
NEW scripts/attention_hash_ref.py, NEW results/m8b_mistral_attn_*,
results/hashline_attn_*, the §3 FULL-LAYER row, this section.

RUNG PLAN (prefix "U-PERF3 AE:"): 0 skeleton + THE STATEMENT SPEC +
the gates re-run [DONE below]; 1 the Mistral attention calibration gate
(scripts/m8b_mistral_attn_gate.py, the CC/PP pattern on the hf adapter)
-> results/m8b_mistral_attn_at_o1.json; 2 the python oracle
scripts/attention_hash_ref.py (one layer, 125M + Mistral l0, per-tensor
sha256s); 3 the Rust chain reproducing the oracle's digests; 4 THE
PROOF of one full layer at 125M (+ tamper legs, CPU/GPU byte-identical,
walls vs FFN-only); 5 the 12-layer 125M full-model pass with seams +
one Mistral full layer at T=16; the §3 row; what remains.

- **RUNG 0 GREEN (2026-09-03, WSL-BOX).** Fresh CPU build of the crate
  in this worktree (28.7 s); the three byte gates re-run here [8T CPU
  NOISY-SHARED]: v2 `pass 12 512 --threads 8 --proof-out` -> PROOF
  sha256 **50cf7bdfd6b5b182..** (66,844,928 B; PROVE 15.67 s); v3
  `pass 12 512 --profile v3 --export /home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export`
  -> **5f368db6240e0614..** (70,758,084 B; 15.69 s); zk `pass 12 512
  --zk --seed 1` -> **021485e4f80ec695..** (87,228,528 B; 17.88 s) —
  all three unchanged. Skeleton: hashline/src/tables_attn.rs (the
  exp-neg-table-v1 generator + spec digest and the rope-cs-table-v1
  generator + digest, BYTE-EXACT with scripts/attention_spec_spike.py —
  unit tests reproduce JJ's pinned members eS -1 15903694.. / eS -2
  b4f01aca.. and NN's rope pins t16 355be440.. / t32 e0de1cf4..; the
  attention LogUp tags >= 128, disjoint from the FFN's), norm.rs (the
  RMSNorm integer gadget: window rule, Ceps, isqrt fact pair, the
  division relation with rho/sigma; 2 tests), attention.rs (the module
  doc = the statement in one page + the shape record), lib.rs (+3 mod
  lines), the two python skeletons. `cargo test --release`: 31/31
  (27 + 4 new).

THE STATEMENT SPEC (rung 0; one Mistral-7B-v0.1 layer: T rows, d 4096,
f 14336, H 32 / H_kv 8 (GQA group 4: kv head = h / 4 = the high 3 bits
of h), d_h 128, RoPE theta 10000 rotate-half, rms eps 1e-5, sliding
window 4096 so T <= 4096 is plain causal; the 125M instance: d 768, f
2048, H 12 / H_kv 4, d_h 64. Classes int8 = [-127,127] proven as the
INT8 table [-128,127]; int16 = the 2^16-row INT16 class; requants are
ROUND-to-nearest with the v3 balanced remainder r in [-2^(sh-1),
2^(sh-1)) (the window table of the shift), except the two DIVISIONS by
committed divisors which are floor with rho in [0, div). Exponent
sources: 125M = results/m125_attn_at_o1.json (PP, per layer per site);
Mistral = results/m8b_mistral_attn_at_o1.json (rung 1); weights and
norm gammas int8 per-tensor at absmax-derived power-of-two exponents.)

| tensor (per layer) | shape | class | exponent source | proven by |
|---|---|---|---|---|
| x_in | T x d | int16 (layer 0: int8 embedding at eX0) | previous layer's e_r2 (l=0: the input's absmax) | the SEAM (l>0): MLE equality with layer l-1's xres2 at a point drawn after both A commitments (layer l-1's A opening deferred); INT16 lookup; l=0: a committed input (public in P0) |
| gA, gM (norm gammas) | d | int8 | absmax of the gamma vector (NEW site; the CC/PP gates kept gammas fp — measured in rung 1 / rung 2's quality leg) | committed in W (aux row); read column-broadcast in the norm zero-check (PW-4) |
| SS, D, a1, a2 (attn_norm rows) | T each | SS < d 2^30 (int16 in); D < 2^21; a1, a2 <= 2D | structural | SS: one degree-2 row-sum sumcheck of x_in^2 tied to the committed vector; a1 = SS + Ceps - D^2, a2 = 2D - a1: per-row zero-checks; a1, a2 as 16-bit limb pairs in the U16 table (D >= 0 and D = isqrt follow) |
| tn, Cn, Ceps (per norm site) | scalars | public | the window rule from (e_g, e_y, d); Ceps from eps, d, e_x | statement constants (absorbed) |
| xn8 | T x d | int8 | xattn e8 (gate) | the division zero-check y D 2^tn + rho = x g Cn over (t, i) with D row-broadcast and g column-broadcast; INT8 lookup |
| rho, sigma (norm) | T x d | [0, D 2^tn) < 2^31 | structural | 16-bit limb pairs (4 U16 lookups per element); sigma = D 2^tn - 1 - rho linear |
| Wq, Wk, Wv, Wo | 4096x4096, 4096x1024, 4096x1024, 4096x4096 | int8 | per-tensor absmax | committed in W (block-structured like Wg/Wu/Wd); opened at the matmul terminals |
| Qacc, Kacc, Vacc | T x 4096 / T x 1024 / T x 1024 (inner d: |acc| <= 2^26) | accumulator (not committed) | — | matmul sumchecks (the g/u form: X folded by eq(r_t), W by eq(r_j)); the requant identity acc = 2^sh y + r folded LINEARLY into the claim |
| q8, k8, v8 (+ rQ, rK, rV) | as above | int8 (+ balanced window) | q/k/v e8 (gate); sh = e_y - e_xn - e_w | INT8 lookups; window lookups |
| QRacc, KRacc | T x 4096 / T x 1024 (|acc| <= 2 x 128 x 127) | accumulator | — | the RoPE zero-check with the PUBLIC rope-cs tables (fRo 7) read at the terminal by the verifier, q8 read at the coordinate-flipped point (PW-1: one extra opening point) |
| qr8, kr8 (+ rQR, rKR) | as q8/k8 | int8 (scale-preserving: e_qr = e_q) + the 2^7 window | qr/kr e8 == q/k e8 (gate: no extra bit) | INT8 + window lookups |
| Sacc | H x T x T (inner d_h: |acc| <= 128 x 127^2 = 2^21) | accumulator | — | the per-head matmul sumcheck over (h, i): claim Sacc~(r_h, r_t, r_j) = sum_{h,i} eq(r_h,h) Qfold(h,i) Kfold(h/4, i); the GQA map is the kv index bits (PW-2, free) |
| s8 (+ rS) | H x T x T | int8 at eS_raw = e_q + e_k + sh_s (+ window) | scores e8 (gate; RAW convention — see the note) | INT8 + window lookups; the requant folded into the score claim |
| m | H x T | int8 | structural (the exact row max of sM = s8 on support, -127 off it) | committed (aux row); dominance = (d, E) in the exp member (d in [0,255]); attainment = zsel |
| zsel | H x T x T | binary | structural | zero-checks z(1 - z) = 0 and z d = 0; the row-sum sumcheck sum_j z = 1 |
| E | H x T x T | u10, E in [0, 2^9] | the exp member (exp-neg, eS_raw, d_h, fE 9): ONE per distinct eS_raw | the fused (d, E) LogUp lookup, d = m - sM computed in the helper zero-check (not committed) |
| Sum | H x T | [2^9, T 2^9] | structural | the masked row-sum sumcheck of E (the mask public, PW-3) tied to the committed vector |
| P (+ rho, sigma) | H x T x T | P in [0, 2^9]; rho, sigma in [0, 2^wrho), wrho = 9 + log2 T | fP 9 (gate: the probs floor) | zero-check mask (P Sum + rho - 2^9 E) + (1 - mask)(P + rho) = 0 with Sum row-broadcast (PW-4); PROB and SREM lookups (sigma = Sum - 1 - rho computed in the helper) |
| Oacc | T x H x d_h (inner T: |acc| <= T 2^9 127) | accumulator | — | the per-head matmul sumcheck over (h, j): Oacc~(r_t, r_h, r_i) = sum_{h,j} eq(r_h,h) Pfold(h,j) Vfold(h/4, j) |
| o8 (+ rO) | T x 4096 | int8 at e_o (sh_o = e_o - (e_v - 9)) | ctx e8 (gate) | INT8 + window lookups |
| AOacc; ao8 (+ rAO) | T x d (inner 4096) | int8 at e_ao | ao e8 (gate) | matmul sumcheck (the Wo form); INT8 + window lookups |
| xres1 (+ rr1) | T x d | int16 at e_r1 (sh_r1 = e_r1 - min(e_r, e_ao)) | xres e8 - 8 (gate: int16 class) | the linear identity 2^sh xres1 + rr1 = 2^a x_in + 2^b ao8 folded into one claim; INT16 + window lookups |
| SS/D/a1/a2, xm8, rho/sigma (mlp_norm) | as attn_norm on xres1 | int8 xm8 | the FFN export's eX (= the v3 statement's X exponent) | as attn_norm; xm8 IS the FFN's X plane (one commitment, two consumers) |
| g8, rg, a16, u16, ru, h16, rh, z16, rd | the v3 FFN planes | as ZB's statement | the v3 export rows | layer.rs prove_layer_v3's checks, with X = xm8 |
| xres2 (+ rr2) | T x d | int16 at e_r2 | the next layer's xres e8 - 8 | the linear identity 2^sh xres2 + rr2 = 2^a xres1 + 2^b z16; INT16 + window lookups; = layer l+1's x_in (the seam) |

DEFERRED (stated, not proven): the KV cache / decode regime (the
statement is prefill-only: every position's K/V is recomputed inside
the proof; a decode step would carry the cached K/V planes as committed
inputs bound by seams across proofs); the embedding (X0 is a committed
input; its gather from token ids is not proven — the PW-5 selector of
the design memo); the final norm and the LM head (the last layer's
xres2 is the proven output); the sliding window at T > 4096.

THE exp-MEMBER KEY NOTE (a reconciliation of the records, recorded
here so nobody re-derives it): PP's results/m125_attn_at_o1.json keys
the member "(exp-neg, eS -2, d_h 64, fE 9)" with eS = the SCALED score
exponent (the 125M walker applies d_h^-0.5 before the s8 hook); the
design memo / JJ's member keys eS as the exponent of the RAW q.k score
with 1/sqrt(d_h) in the table's decay. At d_h = 64 (sqrt = 8) the two
differ by exactly 3 bits: the statement's member is (eS_raw = +1, 64, 9)
and its function exp(-d 2^1 / 8) = exp(-d / 4) IS the gate's
exp(-d 2^-2). At Mistral (d_h 128, sqrt irrational) only the RAW
convention is an integer statement; the rung-1 gate therefore records
the RAW score exponent (the Gemma/CC convention, scaling 1.0 at the
hook) and the scaled one beside it.

ON "BIT-EXACT VS THE HOOKED WALKER" (the rung-2 acceptance, read
honestly before building): the PP/CC hooked walkers are fp32
quantize-dequant forwards, and an exact integer chain cannot equal them
bit for bit: (a) np.round is half-to-even while the v3 requant is
half-up (they differ at exact halves, 2^-sh of the accumulator
elements); (b) RMSNorm is fp32 sqrt/divide vs the isqrt + floor
division gadget; (c) RoPE is fp32 cos/sin vs the fRo = 7 integer
tables (a systematic 2^-8 rotation error); (d) exp is fp32 vs the
round_half_up table. The FFN precedent (lane AA/ZB) resolved this by
making the ORACLE the definition (m8b_margins.py's v3 chain) and
measuring its quality (the val-loss delta). Rung 2 does the same:
attention_hash_ref.py IS the semantics; its legs are (i) the Rust
chain's digests (bit-exact, rung 3), (ii) per-site agreement vs the
hooked walker (fraction of equal integers, max |delta| in grid steps),
(iii) the end-to-end 12-layer INTEGER forward's val loss on the gate's
val windows vs the fp reference — the number that says whether the
full integer statement still models the text.

- **RUNG 1 GREEN — THE MISTRAL-7B ATTENTION ANSWER (2026-09-03,
  [MEASURED WSL-BOX NT CPU NOISY-SHARED]).** scripts/m8b_mistral_attn_gate.py
  (5 phases; attrib/widen rows MERGE into their JSON per site, so a
  killed run resumes — this lane died once mid-attrib and lost nothing
  but the in-flight site). Ref: the hf Walker's val-subset loss
  1.6403015947117856 (2 windows of T=512; the committed 8-window
  reference is 1.8411).
  - **EQUIV**: the hooked walker with all hooks off is BIT-EXACT vs the
    validated m8b hf Walker at 32 layers — final hidden sha256
    97deb9f4.., logits 885b401b.., identical loss. The precondition
    holds. -> results/m8b_mistral_attn_equiv.json
  - **STATS** (263.6 s, 4 cal windows): per-site per-layer absmax/p999/
    e8, per head where head-structured; scores in the RAW q.k
    convention (e8_scaled beside it). e8 spans and worst absmax/p999
    ratios: xattn [-2,1] 6.9, q [-3,-2] 2.1, k [-4,-2] 2.0, v [-7,-3]
    3.0, scores [1,2] 2.3, ctx [-7,-3] 11.5, ao [-10,1] 193, **xres
    [-10,2] ratio 2348** — and xres's e8 jumps to +2 at layer 2 and
    STAYS there for 30 layers: the Mistral massive-activation residual.
    -> results/m8b_mistral_attn_stats.json
  - **ATTRIB** (12 sites, ~120-190 s each, first order, FFN fp):
    Wattn +0.0074, Wnorm -0.0004, xattn +0.0046, q +0.0006, k +0.0017,
    v +0.0037, scores +0.0017, exps +0.0038, probs +0.0092 (the fP=9
    floor), ctx +0.0021, ao +0.0799, **xres +9.7232** (loss 11.36);
    composed all_int8 +8.7118 = xres's damage. THE CORE AND THE SEAMS
    ARE int8-CLEAN — like 125M, unlike Gemma, whose QK-norm sites were
    dirty. -> results/m8b_mistral_attn_attrib.json
  - **WIDEN** (the widened class is now per-site parameterized:
    `--wide-bits xres:16,ao:8`, `--stack-label`): xres16 +0.1205 (a
    9.6-nat rescue that still MISSES the +0.1 class, where 125M's
    xres16 was +0.0000), ao16 +0.0001, **xres24 +0.0000**. Composed
    rows: stack_wide (all int8 + xres16) +0.3615; +ao16 +0.2403;
    stack_wide_xres24 (ao left int8) +0.1150; **stack_wide_xres24_ao16
    +0.0266** — inside the +0.1-nat class, better than Gemma's +0.0854.
    -> results/m8b_mistral_attn_widen.json
  - **THE VERDICT**: Mistral-7B attention IS int8-clean per tensor at
    every core and seam site (q, k, v, scores, exps, probs, ctx, the
    weights, the norm gammas and the attention input), the residual
    stream xres is THE ONE poisoned site (the third model in a row),
    and the rescue costs ONE class MORE than at 125M: xres needs
    **int24**, and ao — clean alone at +0.0799 — must be int16 or the
    composed stack loses the class (+0.1150 vs +0.0266). First-order
    per-site deltas UNDER-count: the composed row is the number the
    statement must quote.
  - **RECORD** -> results/m8b_mistral_attn_at_o1.json: per-site
    per-layer e8 + adopted class (classes adopted FROM the composed row
    stack_wide_xres24_ao16, not from the per-site threshold), qr/kr and
    the two gamma exponents, probs floor stats, and the exp members —
    **only 2 members over 32 layers**: (exp-neg, eS_raw 1, d_h 128,
    fE 9) and (exp-neg, eS_raw 2, d_h 128, fE 9); wrho = fE + log2 T =
    18. qr/kr sit at q/k's exponent at every layer EXCEPT kr at
    layer 0 (+1 bit) and qr at layer 26 (-1) — the rope requant is
    therefore scale-CHANGING in general (sh = fRo + (e_qr - e_q)),
    not scale-preserving as the spike's toy instance assumed
    [corrected in rung 2].
  - **STATEMENT CONSEQUENCE (amends the rung-0 spec table above)**: the
    xres1/xres2 planes and therefore the SEAM are **int24**, not int16
    — proven as two 16-bit limbs against the existing U16 table (no new
    table, one extra committed plane per residual site), and ao8 becomes
    ao16 (INT16 lookup). The int8 rows of the spec table are unchanged.
    At 125M (PP's record) int16 suffices for xres, so the Rust chain
    must carry the residual class as a per-instance parameter.
  - Commits: 233069a (checkpoint: equiv + stats + 6 attrib sites),
    6dcbe20, f90a4f4, d6fd96a (attrib complete), 2131623, 0da65e8
    (widen), + this record commit.

- **RUNG 2 GREEN — THE ORACLE (2026-09-03, [MEASURED WSL-BOX NT CPU
  NOISY-SHARED]).** scripts/attention_hash_ref.py: the integer
  attention + norm + residual chain of ONE REAL layer at the REAL
  measured exponents (lane NN's attention_x1_layer_ref.py is the
  toy-shape seeded sibling; this one drives checkpoints). Semantics:
  v3 round-to-nearest requants with BALANCED remainders at every
  requant edge (hashline export_v3::requant_round), divisions with
  rho/sigma in the norm and softmax gadgets, the spike's exp and rope
  table generators imported VERBATIM (the bytes tables_attn.rs emits),
  the residual and ao planes in their rung-1 classes.
  - 125M layer 0 (2.3 s): CHAIN **aed541fcc8d16f3c..**, 66 witness
    tensors; eXn -5, tn 7, Cn 1774, Ceps 2013, wrho 18 (2 limbs); eQ -2
    eK -4 eV -5; **exp member (exp-neg, eS_raw 1, d_h 64, fE 9)** — the
    ledger's raw/scaled reconciliation CONFIRMED by the running chain
    (PP's scaled eS -2, +3 bits); ropedig 236f03f3..; eO -5, eAo -5,
    res1 int16 at eR1 -13; mnorm eXm -3 tn 9 wrho 26.
  - Mistral-7B layer 0 (22.2 s): CHAIN **4085604b8d61ce8c..**; eXn -2,
    tn 6, Cn 1024 (sqrt(4096) = 64 exact -> Cn a pure shift), Ceps
    171799, wrho 17; eQ -3 eK -4 eV -7; **exp member (exp-neg, eS_raw
    2, d_h 128, fE 9)**, expdig 423a43e7..; eO -7; **ao int16 at eAo
    -18**; **res1 int24 at eR1 -26**; mnorm SS 49 bits, wrho 32 (2
    limbs) — every width inside i64 and far inside the Goldilocks
    field. -> results/hashline_attn_ref_{125m,mistral}_l0.json
  - **NO REQUANT BUMPS at either instance**: the fp-derived exponents of
    the AT-O1 records admit the integer chain at every edge (nothing
    saturates, nothing was clamped) — the measured tables are directly
    usable as statement constants.
  - **THE LOCAL LEGS** (each gadget vs its fp counterpart on the SAME
    dequantized integer inputs — "does the gadget compute the op"):
    q8/k8/v8/s8/ao8/xres1 **1.000000 exact** at both models (matmul +
    balanced-remainder requant IS the fp op to the last bit); rope
    0.976-0.983 with max 1 grid step (the fRo = 7 table error, as
    designed); the norms 0.9998-1.000000 max 1 step; softmax P
    0.76 (125M) / 0.82 (Mistral) with max 34 / 28 steps out of 512 —
    the fE/fP = 9 floor, the cost rung 1 already priced (+0.0167 /
    +0.0092 nats). The CASCADE legs (vs the true fp layer) are far
    looser and SHOULD be: they carry the int8 embedding's own error.
  - **SPEC AMENDMENT (rung 2, adopted)**: the RMSNorm division is now
    ROUND-to-nearest, not floor. Floor cost half a grid step on ~49% of
    every norm output (local agreement 0.51, max 1 step); round lifts it
    to 0.97-1.000. It needs NO parity witness and no new commitment:
    double both sides — y = floor((2 num + div)/(2 div)) with the
    proven relation y (2 div) + rho = 2 num + div, 2 div = D << (tn+1)
    still linear in the committed D, rho one bit wider. This works at
    tn = 0 (Mistral's mnorm, sqrt(4096) exact), where adding
    floor(div/2) would have needed D's parity bit. `--norm-div floor`
    reproduces the old semantics for the comparison.

- **RUNG 3 GREEN — THE RUST CHAIN (2026-09-03, [MEASURED WSL-BOX 8T CPU
  NOISY-SHARED]).** hashline/src/attention.rs now carries the exact
  integer value chain of one attention half-layer (norm gadget with the
  round division, QKV/Wo matmuls with v3 round requants and balanced
  remainders, RoPE against tables_attn's generated tables, the per-head
  score/softmax/PV stage streamed head by head, the residual add, the
  mlp norm) and `hashline attn-chain <export-dir>` diffs every digest
  against the oracle's manifest (exit non-zero on any difference).
  scripts/attention_hash_ref.py --export DIR writes the layer's integer
  inputs as i32 LE planes + manifest.txt (a flat key/value file so the
  crate needs no JSON dependency); the planes are binary and live in
  scratch, NEVER in the repo.
  - **125M layer 0: 64/64 tensor digests + CHAIN aed541fc.. in 0.64 s**
    (the oracle takes 2.3 s).
  - **Mistral-7B layer 0: 64/64 + CHAIN 4085604b.. in 4.52 s** (oracle
    24.1 s).
  - Negative control: flipping ONE integer of x_in by +1 breaks 54 of
    the 64 tensors and the CHAIN — the gate is not vacuous.
  - The three byte gates re-run on this build: v2 **50cf7bdfd6b5b182..**,
    v3 **5f368db6240e0614..**, zk **021485e4f80ec695..**, all unchanged;
    `cargo test --release` **33/33** (31 + 2 new: the round-division
    relation and the balanced requant window).
  -> results/hashline_attn_chain_rung3.json

- **RUNG 3.5 — WHAT RUNG 4 WILL COST (`attention_hash_ref.py --cost`;
  [COUNTED] volumes, [MODEL] projection).** The statement's
  committed/derived split from the rung-0 table (accumulators, d = m - sM
  and sigma are DERIVED in helper zero-checks, never committed):
  - 125M (T 512, d 768, H 12/4): **42 committed attention planes,
    29.11 M elements** vs the v3 FFN half's 8.13 M -> attention is
    **3.58x the FFN**, a full layer **4.58x the FFN-only layer**.
    12.19 M more elements are derived and never committed.
  - Mistral (T 512, d 4096, H 32/8): **103.85 M committed** vs the FFN's
    55.57 M -> **1.87x**, a full layer **2.87x**.
  - **THE SHAPE OF THE COST**: the six committed H x T x T planes (s8,
    rS, zsel, E, P, rho) are **65% of the 125M attention witness and 48%
    of Mistral's**, and they are QUADRATIC in T while the FFN half is
    linear. At T 1024 they quadruple (75.5 M / 201.3 M) — attention, not
    the FFN, sets the context-length cost of the hash line.
  - [MODEL] at each instance's own measured v3 rate (125M 1.876 s/layer
    = 0.2307 s per M committed elements; Mistral 15.95 s/layer = 0.287
    s/M — the 8B rate is 24% slower per element): a 125M full layer
    **~8.6 s** vs 1.88 s FFN-only; a Mistral full layer **~45.8 s** vs
    15.95 s, so a 32-layer Mistral full-model prove projects to **~24
    min** against the measured 510 s FFN-only. Rung 4 replaces this
    model with a measurement. -> results/hashline_attn_cost_{125m,mistral}.json

**WHERE THE LANE STANDS (for the next session).** Rungs 0-3 + 3.5 are
done and committed; the remaining work is the PROOF itself:
- **RUNG 4** (the long pole): prove one FULL 125M layer — the attention
  planes committed alongside the v3 FFN planes, the matmul sumchecks
  (QKV/Wo per the g/u form, the per-head score and PV sumchecks with the
  GQA map as free index bits), the RoPE zero-check at the
  coordinate-flipped point, the softmax's fused (d, E) LogUp + the
  masked row-sum sumcheck + the division zero-check, the norm's isqrt
  pair + division + U16 limb lookups, the two residual linear pins, and
  the seam; then the tamper legs (a flipped score, a wrong exp entry, a
  wrong softmax quotient, a wrong norm, a broken seam) + CPU/GPU
  byte-identity + walls vs the FFN-only layer.
- **RUNG 5**: the 12-layer 125M full-model pass with seams bound, ONE
  Mistral full layer at T=16 on CPU, the §3 FULL-LAYER row, and what
  remains for end-to-end (embeddings, head, KV cache/decode).
- ORCHESTRATOR-RUN (nothing blocking; both are conveniences): the
  Mistral token stream is cached at
  /tmp/claude-1000/-home-victor-IntelligenceRegulation/<session>/scratchpad/mistral_toks.npy
  (tokenizing from scratch costs ~5.5 min of the 6-min setup), and the
  rung-3 exports live beside it (attn_export_{125m,mistral}_l0) — both
  are scratch, regenerate with `--export`.


(lane appends below — NOTE: this lane's log is the block at the END of
this file, the one beginning "LANE: attention, norms and the
layer-to-layer seams"; it was opened there in rung 0 and left in place
so that moving it cannot conflict with the other lanes' appends.)

## Agent AF status (wt-uperf3-af) — round 12

(lane appends below)

**RESUME NOTE (2026-09-03).** The first attempt at this lane was cut off
by a usage limit before it committed anything. It left an UNCOMMITTED
`hashline/src/pcs_compact.rs` (1351 lines, with 5 unit tests) and a
tagged PCS-selection seam in `layer.rs`. **VERDICT: KEPT.** The reason:
the module is a complete construction, not a sketch — commit, the
batched sumcheck+FRI opening, the verifier walk, and a test that runs
commit/open/verify plus seven tamper legs were all present; the only
things missing were the `pub mod` line in `lib.rs`, the `--pcs` flag in
the driver, and the `cpcs_open` field on `LayerProofV3` (the v2
`LayerProof` had it). Three edits, and it compiled and passed 32/32
tests first try. Discarding it to restart from a blank file would have
thrown away a working construction to prove a point. Everything below
was re-derived and re-verified in this session; nothing is taken on
trust from the lost one.

### Rung 0 — THE CONSTRUCTION, ITS PARAMETERS, ITS SOUNDNESS

**The choice: a BaseFold-class commitment** (Zeilberger-Chen-Fisch,
ePrint 2023/1705 [EXTERNAL]) — a batched-evaluation *sumcheck* whose
round challenges simultaneously drive a *FRI fold* of the Reed-Solomon
codeword of the same polynomial. Why this and not Ligero-with-more-
folding, STIR, or WHIR:

- The proof size is `O(k^2 * lambda / log(1/rate))` hashes instead of
  Ligero's `O(sqrt(N))` field elements. That is the whole point of the
  lane: 66.8 MB and 1.23 GB are square-root-class numbers.
- BaseFold needs *no new primitives*. The existing Goldilocks field,
  its two-adic roots, blake3, and the Merkle module already serve it.
  The one thing this repo did not have is a decimation-in-frequency NTT
  whose bit-reversed output puts a fold coset in one contiguous block;
  that is ~80 lines in `pcs_compact.rs` (`ntt_dif`), verified against
  Horner evaluation in `ntt_dif_is_bitreversed_evaluation`.
- Crucially, BaseFold's sumcheck *is* the evaluation proof. The Ligero
  form answers each claim with a proximity test plus a column opening;
  BaseFold answers ALL claims on ALL of a layer's commitments with ONE
  sumcheck and ONE FRI, because the claims are all linear functionals
  `<f, w_c>` and a random `lambda`-combination of linear functionals is
  another linear functional. That collapses 3 openings per layer to 1.
- STIR/WHIR would cut the query count further (they are the right
  answer at 128-bit security over a big field), but both need the
  list-decoding regime to pay off, and the Johnson-bound field term is
  ~`L^2/|F|` — over `F_{p^2}` with `p` Goldilocks that is `2^-64` at
  `L = 2^24`, i.e. it does not even reach the target. Unique decoding
  is what this field can carry, and inside unique decoding BaseFold's
  simplicity wins.

**How the pieces fit** (details in the module header):
1. A committed vector of `N` base-field values is the Lagrange table of
   a multilinear `f` in `k = ceil(log2 N)` variables, variable `j` =
   bit `j` of the index, LSB folded first. `N` is cut into at most
   `max_pieces = 3` power-of-two PIECES (the top set bits of `N`,
   rounded up); a piece may run past `N` with zeros and no claim ever
   weights the pad. Committed lengths here are not powers of two (a
   125M layer's `W` is `9 x 2^19`), so pieces are not optional.
2. Each piece is Mobius-transformed to coefficient form, read as a
   univariate, and RS-encoded at rate `1/4` by one DIF NTT. Its
   bit-reversed output makes the 16 positions that fold together over
   four rounds ONE contiguous block, so a Merkle leaf is exactly a
   fold coset. Pieces of the same size share a tree (leaf = their
   blocks concatenated); the commitment root is the blake3 of the
   per-size roots.
3. OPENING, once per layer over `W`, `A`, `H` together. Every claim in
   this prover is `<f, w_c>` with `w_c` either `eq(point)` on an
   aligned slice or the constant 1 on a slice (the LogUp helper sums).
   With random `lambda_c` the batched claim is
   `sum_p sum_b f_p(b) g_p(b)`, a degree-2 sumcheck. `g_p` is NEVER
   materialised at full size: it is stored as a sum over distinct eq
   tables `E_t` of `sel_t[b >> s_t] * E_t[b mod 2^s_t]` with small
   selector tables, and LSB-first folding collapses each `E_t` into an
   explicit table over the slice-index bits only when its arity runs
   out. A slice that is unaligned or crosses a piece boundary is split
   recursively, the point's leading variables becoming `(1-p0)`/`p0`
   coefficients — so the arbitrary offsets `build_claims` produces are
   handled exactly, not by padding.
4. A piece with `k_p < k_max` joins at round `k_max - k_p` as
   `prod_{i<join}(1 - X_i) * f_p g_p`; before the join its round
   message is the affine pair `(beta*S_p, 0, -beta*S_p)`. The same
   challenges fold its codeword into the running
   `R = sum_p mu_p Enc(f_p)` at the round where the domains coincide.
5. Every 4th round the prover commits `Enc(folded R)` as a fold tree
   (recomputed from the folded tables, not folded symbol-wise — the
   folded codeword IS the encoding of the folded polynomial). At
   `2^k_end <= 2^log_final` coefficients the final polynomial is sent
   in the clear. Then `f_p(r)` per piece. The verifier checks the
   sumcheck terminal `sum_p beta_p f_p(r) g_p(r)` (a product of `O(k)`
   eq factors, no tables), checks the final polynomial against
   `sum_p mu_p f_p(r)`, and runs `Q` query walks: a random 16-coset of
   the largest domain, four folds per stretch, adding `mu_p` times the
   joining pieces' opened values, matched against the next fold tree's
   leaf and finally against the final polynomial.

**PARAMETERS** (`--pcs-*` overrides all of them):
`inv_rate = 4`, `target_bits = 106`, `queries = 157` (derived),
`log_final = 7`, `max_pieces = 3`, `reencode` off. `COSET_LOG = 4`
(fold-by-16 per commitment) is a compile-time constant.

**SOUNDNESS ARITHMETIC** (error terms, per proof):
- Query term `(1 - delta)^Q` with `delta = (1 - 1/inv_rate)/2 = 3/8`
  the unique-decoding radius: `(5/8)^157 = 2^-106.45`. This meets the
  Ligero form's `2^-106` (`inv_rate 4`, 256 column checks). Unique
  decoding is the regime in which BaseFold's Thm 3 and FRI soundness
  are proven with a per-fold affine-line error of `L/|F|` [BCIKS20 Thm
  1.2, EXTERNAL].
- Fold/batching field terms `~(k_max + pieces) * L_0 / |F_{p^2}|`.
  `|F_{p^2}| ~ 2^128`. At 12x512 the largest committed vector is
  `H` at `2^23` -> `L_0 = 2^25`, `k_max = 23`: `28 * 2^25 / 2^128 =
  2^-98.2`. At the 8B shape `W` is `4096 x 14336 = 2^25.48` ->
  `L_0 = 2^28`, `k_max = 26`: `29 * 2^28 / 2^128 = 2^-95.1`.
- Sumcheck: `2 * k_max / |F_{p^2}| < 2^-122`.
- TOTAL: `2^-98.2` at 12x512, `2^-95.1` at 8B — dominated by the field
  term, not the queries. Honest reading: this is 3-11 bits BELOW the
  Ligero form's `2^-106` at the same shapes, because Ligero's proximity
  test never pays a per-round affine-line term. To recover the margin
  one raises `|F|` (a degree-3 extension) or lowers `L_0` (more, smaller
  pieces); it is NOT recovered by more queries. Recorded, not papered
  over.
- The list-decoding (Johnson) regime would roughly halve `Q`, but its
  field term is `~L^2/|F| = 2^-64` at `L = 2^24` over `F_{p^2}` — not
  usable at this field. Hence unique decoding.
- NOT zero-knowledge: `--pcs compact` with `--zk` is refused by the
  driver with a message. See the ZK-interaction statement at rung 5.

**THE PLAN**: rung 1 the PCS alone at `2^14..2^20` with tamper legs and
a bytes/walls table vs Ligero; rung 2 the 12x512 v2 pass under
`--pcs compact`; rung 3 the same in v3; rung 4 one Mistral layer at
T=512 and the 32x512 projection; rung 5 the §3 row, the record file,
and the ZK-interaction statement.

**THE THREE BYTE GATES, re-run on this binary** [MEASURED, WSL-BOX, 8T,
CPU, NOISY-SHARED: three sibling lanes active]:
- v2 `pass 12 512 --threads 8`: `50cf7bdfd6b5b182f9c029c3d62087ca..`
  (66,844,928 B), PROVE 15.40 s / VERIFY 0.30 s — **GREEN**.
- v3 `pass 12 512 --profile v3`: `5f368db6240e061428a90eccdb22ff45..`
  (70,758,084 B), PROVE 16.48 s / VERIFY 0.30 s — **GREEN**.
- zk `pass 12 512 --zk --seed 1`: `021485e4f80ec695ddc0b05423a941e1..`
  (87,228,528 B), PROVE 17.11 s / VERIFY 0.38 s — **GREEN**.
The default path is byte-identical: `--pcs` defaults to `ligero`, and
`pcs_compact::commit` forwards to `pcs::commit` when it is not selected.
32/32 tests (5 of them new: the DIF NTT vs Horner, the Mobius transform
vs the multilinear evaluation, the piece cut and the query count, the
single-commitment open/verify + 7 tamper legs, and a 3-commitment batch
with a late-joining piece).

### Rung 1 — THE PCS ALONE: `hashline pcs-bench <log_lo> <log_hi>`

A new `[UPERF3-AF]`-tagged subcommand in the driver. For each size it
builds a random int8-valued vector of `2^k` entries, answers the SAME
claim set with both commitments (Ligero from the untouched `pcs.rs`,
compact from `pcs_compact.rs`), and runs the three named tamper legs on
the compact opening. Bytes are the opening plus the 44-byte commitment.
`HL_BENCH_CLAIMS=N` sets the claim count.

**ONE claim** (the canonical single-evaluation PCS benchmark)
[MEASURED, WSL-BOX, 8T, CPU, NOISY-SHARED]:

| log N | Ligero B | compact B |  x   | Lig P s | cmp P s |  x   | Lig V s | cmp V s |
|------:|---------:|----------:|-----:|--------:|--------:|-----:|--------:|--------:|
| 14 |   659,500 | 162,588 | 4.06 | 0.169 | 0.035 | 0.20 | 0.0408 | 0.0003 |
| 15 |   661,548 | 173,708 | 3.81 | 0.022 | 0.025 | 1.14 | 0.0135 | 0.0039 |
| 16 |   665,644 | 252,380 | 2.64 | 0.016 | 0.042 | 2.61 | 0.0195 | 0.0004 |
| 17 |   673,836 | 267,756 | 2.52 | 0.022 | 0.066 | 3.03 | 0.0121 | 0.0005 |
| 18 |   690,220 | 283,388 | 2.44 | 0.042 | 0.073 | 1.73 | 0.0108 | 0.0025 |
| 19 |   722,988 | 299,532 | 2.41 | 0.060 | 0.117 | 1.95 | 0.0147 | 0.0005 |
| 20 |   788,524 | 383,228 | 2.06 | 0.088 | 0.239 | 2.72 | 0.0137 | 0.0007 |

**EIGHT claims** (what a real layer looks like):

| log N | Ligero B | compact B |   x   | Lig P s | cmp P s | Lig V s | cmp V s |
|------:|---------:|----------:|------:|--------:|--------:|--------:|--------:|
| 14 | 2,494,508 | 162,588 | 15.34 | 0.028 | 0.037 | 0.0212 | 0.0004 |
| 16 | 2,500,652 | 252,380 |  9.91 | 0.024 | 0.044 | 0.0178 | 0.0004 |
| 18 | 2,525,228 | 283,388 |  8.91 | 0.027 | 0.156 | 0.0164 | 0.0050 |
| 20 | 2,623,532 | 383,228 |  6.85 | 0.131 | 0.510 | 0.0480 | 0.0010 |

**READING IT.** Three facts, and the third is the lane's real lever.

1. **The compact opening's size does not depend on the claim count.**
   162,588 B at `2^14` and 383,228 B at `2^20` for ONE claim; the same
   bytes to the byte for EIGHT. Every claim is folded into the
   `lambda`-combination before the sumcheck starts, so more claims cost
   nothing but the terminal `f_p(r)` values (one per PIECE, not per
   claim). The Ligero form pays a fresh `group_vec` of `rows` field
   elements per distinct column-weight group, so its bytes grow ~linearly
   in the claim count: 659 KB -> 2.49 MB going from 1 to 8. This — not
   the single-claim ratio — is where the pass-level win comes from.
2. **The compact opening grows logarithmically, the Ligero one as
   `sqrt`.** From `2^14` to `2^20` (64x the data) the compact opening
   grows 2.36x (162 KB -> 383 KB) and would keep growing by ~2 Merkle
   levels per doubling; Ligero grows 1.20x here only because at these
   sizes it is still dominated by the fixed 256 column checks — its
   `sqrt` term takes over at the layer shapes of rung 2 onward.
   Honest note: at these SMALL sizes the compact form is only 2-4x
   smaller on a single claim. The MB-class collapse this lane is after
   does not come from one small polynomial; it comes from (a) the claim
   independence above and (b) the 3-commitments-to-1-opening batching in
   `layer.rs`.
3. **The compact prover is 1.1-3.9x SLOWER at these sizes; the compact
   verifier is 20-100x FASTER.** The prover cost is the sumcheck over
   the full `2^k` table plus one re-encode per fold stretch; the
   verifier does `Q = 157` walks of ~30 hashes and no NTT at all, which
   is why it lands at sub-millisecond where Ligero needs 10-50 ms (it
   re-encodes the row combinations). The `2^14` row's 0.169 s Ligero
   prove is first-call table warm-up, not a real cost.

**TAMPERS**: at every size, all three legs REJECT — a wrong claimed
evaluation, a corrupted opening value, and a swapped Merkle path.
(The unit test `compact_commit_open_verify_and_tampers` carries four
more: a corrupted fold leaf, a corrupted round message, a corrupted
terminal, a corrupted final polynomial, plus an honest opening of a
DIFFERENT witness checked against both its own and the original
commitment — 9 legs in all, all rejecting.)

### Rung 2 — THE 12x512 v2 PASS UNDER `--pcs compact`: 66.8 MB -> 13.5 MB

`hashline pass 12 512 --pcs compact --threads 8`, the same statement,
the same witness (`results/m125_ffn_export_wsl`), the same transcript
structure. **PASS ACCEPT.** Reproduced twice, byte-identical:
proof sha256 `f84432ea509524fea247264cc3743f25019edd858f580555606e6c743..`
(13,487,744 B). [MEASURED, WSL-BOX, 8T, CPU, NOISY-SHARED, both rows
taken under `flock /tmp/zk-heavy.lock`]

| | Ligero (default) | compact | ratio |
|---|---:|---:|---:|
| proof bytes | 66,844,928 (66.8 MB) | **13,487,744 (13.5 MB)** | **4.96x smaller** |
| PROVE | 15.40 s | 31.78 s | 2.06x slower |
| VERIFY | 0.30 s | **0.02 s** | **15x faster** |
| peak RSS | 1.56 GB | 2.23 GB | +43% |
| proven MAC/s | 1.88e9 | 9.12e8 | 0.48x |

**Prover phases, summed over the 12 layers:**

| phase | Ligero | compact | delta |
|---|---:|---:|---|
| commit W | 2.009 | 3.659 | +82% |
| commit A | 3.626 | 7.553 | +108% |
| helpers + commit H | 4.438 | 7.358 | +66% |
| matmul g/u | 0.226 | 0.241 | = |
| matmul d | 0.142 | 0.151 | = |
| zero-check 20 | 3.141 | 3.105 | = |
| zero-check 17 | 0.912 | 0.906 | = |
| PCS openings | 0.880 | 8.793 | 10.0x |
| **PROVE** | **15.40** | **31.78** | **2.06x** |

**THE HONEST VERDICT AGAINST THE COUNT.** U_PERF3_ROUTE_B_THROUGHPUT.md
§5 counted the trade at **x0.94-1.4 prover for 3-12 MB per pass**. This
construction lands at **x2.06 prover for 13.5 MB** — outside the count
on both axes, though not far. Where the two disagreements come from,
measured, not guessed:
- The commit is ~2x slower and that is STRUCTURAL, not a bug. Ligero
  encodes each 2^14-column row independently (`4N log 4n` butterflies,
  `n = 2^14`); the compact form encodes the whole vector as ONE
  polynomial (`4N log 4N`, i.e. 25/16 = 1.56x the butterflies at
  `N = 2^23`) and pays a Mobius transform on top (`k` memory passes
  over the data). Both those terms are the price of having a single
  low-degree codeword to fold.
- The opening is 10x slower because it IS a full sumcheck over the
  combined `2^23` table plus a re-encode per fold stretch, where
  Ligero's opening is a handful of row-combinations.

**WHERE THE BYTES ARE, and the one lever left [COUNTED].** Per layer the
batched opening is 1,113,888 B of the layer's 1,127,136 B — 98.8%; the
sumchecks, multiplicities and commitments are 13 KB. The opening at
`Q = 157`, `k_max = 23`, `k_end = 7`, 7 pieces / ~7 group trees + 3 fold
trees is ~7,095 B per query, of which roughly half is Merkle path
digests (~110 levels x 32 B across the ~10 trees). **A Merkle CAP** —
truncate every tree at a fixed level and send that level once per proof
— is the standard, contained fix: at a 2^8-node cap it removes 8 levels
x 10 trees x 32 B x 157 queries = 402 KB per layer and adds 10 x 256 x
32 = 82 KB, a net -29%, i.e. **13.5 MB -> ~9.6 MB [COUNTED]**, inside
the counted 3-12 MB band. It is not implemented in this lane; it is the
next lever and it costs no soundness. Raising `inv_rate` to 8 (`Q` 157
-> 128) is the other knob and is measured below.

**TAMPERS: 6/6 REJECT** through the compact prover
(`layer 0 512 --pcs compact --all-tampers`), at the same sites as the
Ligero path: flipped X -> matmul round 0; flipped Wg -> matmul round 0;
out-of-range remainder -> LogUp identity; wrong table entry -> LogUp
identity; wrong requant (h8) -> zero-check round 0; wrong z -> matmul
round 0. Plus the three PCS-internal legs of rung 1 and the four more in
the unit test. The compact opening never masks a statement tamper: the
claims it answers are the same claims.

**GPU: NOT PORTED, and here is exactly what a port needs.** The device
module's NTT kernels (`k_ntt_p1`/`k_ntt_p2`, `k_dif_pa`/`k_dif_pb`,
`k_dit_p1_pad`) are built for the Ligero LAYOUT — a batch of `rows`
independent transforms of `2^log_cols` each, twiddles stage-major, and
`k_hash_cols` hashes one blake3 leaf per COLUMN of that matrix. The
compact form needs (1) a SINGLE transform of up to `2^28` elements with
the DIF bit-reversed output order this module's `ntt_dif` produces —
the existing `k_dif_pa/pb` pair is the right shape but is sized for one
row, so it needs the strided multi-block tail stages that `k_ntt_p2`
has; (2) a blake3 kernel over 16-symbol CONTIGUOUS blocks rather than
strided columns (`k_hash_cols`'s gather is the only thing that changes);
(3) the Mobius transform (a `k`-pass in-place kernel, trivial); and (4)
the sumcheck round kernel over an `f * g` product where `g` is the
selector/eq-table structure — `k_sc_round_zc20` is the closest existing
kernel but its `g` is a fixed table set, not this module's `GTab` list.
(1)-(3) are a day; (4) is the real work and is where 8.8 of the 31.8 s
sit. Nothing in the port changes a byte of the proof.

**THE RATE KNOB** [MEASURED, same box, NOISY-SHARED — this run started
the moment the heavy lock freed with three sibling lanes active, so its
wall carries more noise than the rows above]:
`--pcs compact --pcs-inv-rate 8` (RS rate 1/8, `delta = 7/16`,
`Q = 128` for the same 106 bits: `(9/16)^128 = 2^-106.2`) gives
**11,518,208 B (11.5 MB)** — inside the counted 3-12 MB band — at
PROVE **47.93 s** (3.11x Ligero), VERIFY 0.02 s, sha256
`3c02420be01d78c0f8ec217f08aae1551687bfa617b76bfb9cf2f5b09265a54c`,
ACCEPT. Trading rate for bytes costs more prover than it saves: -15%
bytes for +51% prove. **The recommended operating point stays
`inv_rate 4`** (13.5 MB at 2.06x), with the Merkle cap above as the way
into the band without touching the prover.

### Rung 3 — THE 12x512 v3 PASS UNDER `--pcs compact`: 70.8 MB -> 17.4 MB

`hashline pass 12 512 --profile v3 --export .../m125_v3_export
--pcs compact --threads 8`. **PASS-V3 ACCEPT**, proof sha256
`621c263375a4629283773e627f7167319b5a917be950e42f1ee4e33183dc2875`
(17,400,900 B). [MEASURED, WSL-BOX, 8T, CPU, NOISY-SHARED, under
`flock /tmp/zk-heavy.lock`]

| | Ligero (default) | compact | ratio |
|---|---:|---:|---:|
| proof bytes | 70,758,084 (70.8 MB) | **17,400,900 (17.4 MB)** | **4.07x smaller** |
| PROVE | 16.48 s | 29.92 s | 1.82x slower |
| VERIFY | 0.30 s | **0.03 s** | **10x faster** |
| peak RSS | 1.58 GB | 1.80 GB | +14% |

Phases (12 layers, compact): commit W 3.755, commit A 6.816,
helpers + commit H 6.901, matmul g/u 0.282, matmul d 0.135, zero-check
F 2.882, zero-check D 0.751, PCS openings 8.359.

**THE CLEAN FACT THIS RUNG ADDS.** The v3 surcharge over v2 is
`70,758,084 - 66,844,928 = 3,913,156 B` under Ligero and
`17,400,900 - 13,487,744 = 3,913,156 B` under compact — **the same
number to the byte**. The widened statement's extra cost is entirely
the committed MULTIPLICITY vectors, which no polynomial commitment
touches; the compact form carries it through unchanged. So the compact
opening itself is the same size in v2 and v3, and the v3 ratio (4.07x)
is worse than v2's (4.96x) only because a fixed 3.9 MB of non-PCS bytes
is now a larger share of a smaller proof. A Merkle cap would take the
v3 pass to ~13.5 MB [COUNTED].

**TAMPERS: 8/8 REJECT** through the compact v3 prover
(`layer 0 512 --profile v3 --pcs compact --all-tampers`): flipped X,
flipped Wg -> matmul round 0; out-of-range remainder, wrong int16 table
entry -> LogUp identity; wrong requant (h16), wrong z -> matmul/
zero-check round 0; wrong rounding (floor), out-of-range int16 (z16) ->
LogUp identity. Same sites as the Ligero v3 path.

**MEMORY FIX before rung 4** (`pcs_compact::group_codewords`). The
query phase built its codeword table with `g.codewords.clone()` when
the codewords were resident — a full copy of every commitment's
codeword at the moment of peak use. At 12x512 that is ~270 MB; at the
Mistral shapes it is GIGABYTES, and it would have decided rung 4 by
OOM rather than by measurement. Resident groups are now BORROWED and
only the `--pcs-reencode` path allocates. [MEASURED] 12x512 v2 compact:
proof `f84432ea..` UNCHANGED to the byte, PROVE 31.78 -> **28.76 s**
(-9.5%), peak RSS 2.23 -> **1.78 GB** (-20%, now only +14% over
Ligero's 1.56 GB). Gates re-run on the fixed binary: v2
`50cf7bdfd6b5b182..`, v3 `5f368db6240e0614..`, zk `021485e4f80ec695..`
— all three GREEN. 32/32 tests.

### Rung 4 — ONE MISTRAL LAYER AT T=512: 38.7 MB -> 1.94 MB (19.9x)

`hashline layer 0 512 --profile v3 --export
.../m8b_mistral_v3_export --threads 8`, d 4096, f 14336, the FFN-only
v3 statement; the same witness for both forms; both runs under
`flock /tmp/zk-heavy.lock` with `free -g` >= 14 GB before each.
[MEASURED, WSL-BOX, 8T, CPU, NOISY-SHARED]

| | Ligero (default) | compact (`--pcs-reencode`) | ratio |
|---|---:|---:|---:|
| **proof bytes (one layer)** | **38,688,700 (38.7 MB)** | **1,940,684 (1.94 MB)** | **19.94x smaller** |
| PROVE | 15.497 s | 67.593 s | 4.36x slower |
| VERIFY | 0.041 s | **0.010 s** | 4.1x faster |
| peak RSS | 13.17 GB | 13.92 GB | +6% |
| ACCEPT | yes | yes | |

Phases: commit W 7.326 -> 15.916, commit A 2.425 -> 5.253, helpers +
commit H 2.705 -> 5.381, matmul g/u 0.182 -> 0.189, matmul d 0.106 ->
0.103, zero-check F 1.620 -> 1.653, zero-check D 0.235 -> 0.239,
**PCS openings 0.881 -> 38.818**.

**WHY 19.9x HERE AND ONLY 4-5x AT 12x512.** This is the lane's whole
point and it is the square-root law showing itself. The Ligero opening
grows as `sqrt(N)` — from a `2^23` commitment to a `2^27` one it grows
~4x — while the compact opening grows LOGARITHMICALLY: 1.11 MB of
opening at `k_max = 23` becomes ~1.9 MB at `k_max = 27`, four more
Merkle levels per tree and nothing else. The bigger the model, the
bigger the win. At 125M the compact form buys 5x; at 8B it buys 20x.

**THE 32x512 PROJECTION [COUNTED from a MEASURED layer].** Every layer
of the Mistral pass has the same shape, and the measured Ligero layer
(38,688,700 B) matches the measured 32x512 pass's per-layer average
(1,234,936,956 / 32 = 38,591,780 B) to 0.25%. So:

| 8B FFN pass, 32 x 512 | Ligero [MEASURED] | compact [COUNTED] |
|---|---:|---:|
| proof bytes | 1,234,936,956 (1.235 GB) | **62,101,888 (62.1 MB)** |
| prove | 510.38 s | ~2,163 s (~36 min), 4.24x |
| verify | 1.21 s | ~0.3 s |
| peak RSS | 13.99 GB | ~13.9 GB |

**The 1.23 GB per-proof number becomes 62 MB.** That is the
square-root class leaving and the log class arriving — and with the
Merkle cap of rung 2 (-29% [COUNTED]) it would be ~44 MB. It is NOT
the "3-12 MB per pass" of the §5 count, because that count was written
against a 125M pass; the same construction on the 125M pass IS 13.5 MB
(rung 2), and ~9.6 MB with the cap.

**THE MEMORY WALL, and why `--pcs-reencode` is not optional here.**
Ligero's Merkle tree has only `enc_cols = 2^16` leaves however large
the commitment is (it hashes COLUMNS of a rows x enc_cols matrix); the
compact tree has `L/16` leaves, which at `L = 2^29` is 33.5M — ~1.4 GB
of tree for W alone. Holding the codewords resident as well
(5.64 GB for W, ~10 GB across W/A/H) puts the layer at ~15.4 GB
[COUNTED] on a 15 GB box, i.e. OOM. `--pcs-reencode` drops each
group's codeword the moment its tree is built and re-encodes it at
query time, and this session also restructured the query phase to run
ONE GROUP AT A TIME so that only one codeword is ever materialised
(byte-identical: `f84432ea..` at 12x512 with and without the flag).
The cost is visible: of the 38.8 s opening phase, ~16 s is that
re-encode. On a box with ~20 GB the resident path would prove the
layer in ~52 s [COUNTED], i.e. ~1,654 s / 3.24x for the 32x512 pass.

**THE PROVER COST, stated plainly.** 4.36x at 8B against the §5 count
of x0.94-1.4. Three quarters of the excess is the opening (38.8 s of
the 52.1 s of extra prove), and the opening is a full degree-2
sumcheck over a `2^27` table plus a re-encode per fold stretch plus the
memory-forced re-encode. None of it is on the GPU, where the Ligero
form already runs 5x faster; the port items are listed at rung 2.

### Rung 5 — THE RECORD, THE §3 ROW, AND THE ZK INTERACTION

- **NEW `results/hashline_compact_12x512.md`**, in the form of lane
  XX's `results/hashline_gpu_12x512.md`: what changed and what did not,
  the construction, the parameters and the soundness arithmetic, the
  125M and 8B rows with the 32x512 projection, why the ratio grows with
  the model, the prover phases, the honest verdict against the §5
  count, the two levers left, the memory wall and the two fixes, the
  tamper table, the GPU port list, the ZK interaction, and every one of
  the B row's caveats unchanged.
- **The §3 row** in `docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md`:
  five compact rows (12x512 v2, 12x512 v3, the inv_rate-8 knob, the
  Mistral layer, the 32x512 projection) below the 8B row, with the
  reading, the cost stated plainly, the Merkle-cap lever and the ZK
  pointer.

### THE ZK INTERACTION — the statement

**The compact form as built is NOT hiding.** The driver refuses
`--pcs compact --zk` with a message rather than emitting a proof that
looks private and is not. Lane ZA's `--zk` path is untouched and
byte-identical (`021485e4..`) on the Ligero form.

**Does the compact form keep ZA's pad rows and mask rows? No — and the
reason is structural, not an omission.**

- **PAD ROWS do NOT survive.** ZA's pads are per-ROW (`f_data +
  Z_n g_pad`, `Q` fresh coefficients per row) with the evaluation
  domain moved to a coset `h G_{4n}` disjoint from `G_n` so that no
  opened position is systematic and any `Q` opened COLUMNS are jointly
  uniform. The compact form has no rows and no systematic positions —
  it encodes the coefficient form of ONE polynomial over the whole
  domain. The coset half of the device is not needed; the randomness
  half still is, in a different shape.
- **MASK ROWS do NOT survive**, and what they hid is exposed by four
  different surfaces here: (i) `terminals`, i.e. `f_p(r)` per piece —
  precisely the evaluation the mask rows existed to hide; (ii)
  `final_coeffs`, the `2^k_end = 128` coefficients of the fully folded
  polynomial; (iii) `rounds`, 3 `F_{p^2}` values over 23-27 rounds;
  (iv) the query cosets, `157 x 16` codeword symbols per group. ZA's
  "every opening site carries a mask" assertion is written against
  Ligero's opening sites and does not transfer; it must be re-derived
  for these four.
- **CFS-masked sumchecks and the last-round extension DO survive** and
  are the right tool: the batched opening is a sumcheck, and
  `sumcheck.rs`'s masking applies directly. The BaseFold-specific
  catch: the mask must also be carried by the FRI fold, or the codeword
  and the sumcheck decouple and the query walks stop closing.
- **SALTED LEAVES survive verbatim** — one line in `group_leaf_hash`
  and `hash_fp2_block` — and are needed: the compact trees are
  currently unsalted, so identical cosets hash identically.
- **COMMITTED MULTIPLICITIES survive unchanged** (statement-side, not
  PCS-side). Rung 3 measured it: the multiplicity bytes pass through
  the compact form identically, to the byte.

**What a ZK-compact form needs**: (1) randomness in extra multilinear
VARIABLES — equivalently one extra random PIECE of size `2^c` in the
batch, `c ~ log Q` — so the folded object stays a multilinear encoding
and the FRI still closes (a naive `P(Y) + Y^{2^k} R(Y)` pad would break
exactly that); (2) the CFS mask on the batched opening sumcheck,
committed as a piece of the same batch so the fold carries it (this
covers surfaces (i) and (iii), and (ii) too, since `final_coeffs` then
includes the mask); (3) salted leaves on the group and fold trees,
covering (iv) with (1); (4) a re-derived query count and field term
(the extra piece raises `pieces` in the `(k_max + pieces) L_0 / |F|`
bound). Counted cost: bytes up by the extra piece's share of the
queries (a few percent — it is tiny and joins late), prover up by one
piece in the sumcheck and one mask commitment. **None of it is built
here; this is the specification, not a claim.**

### THE FINAL GATES — CPU AND GPU, both binaries

[MEASURED, WSL-BOX, 8T, under `flock /tmp/zk-heavy.lock`]

| gate | CPU binary | gpu-cuda binary, `HL_GPU=1` |
|---|---|---|
| v2 `pass 12 512 --threads 8` | `50cf7bdfd6b5b182..` (66,844,928 B), 15.33 s | **same sha256**, 2.50 s |
| v3 `--profile v3` | `5f368db6240e0614..` (70,758,084 B), 15.68 s | **same sha256**, 3.06 s |
| zk `--zk --seed 1` | `021485e4f80ec695..` (87,228,528 B), 16.61 s | **same sha256**, 4.79 s |

**All six GREEN.** 32/32 tests. And one more, not required but worth
having: `--pcs compact` on the **gpu-cuda binary with `HL_GPU=1`**
produces `f84432ea..` — byte-identical to the CPU-only binary's compact
proof — at PROVE 34.96 s, i.e. SLOWER than the CPU-only 28.76 s. That
is the expected and honest outcome: a compact commitment is never
device-resident (`dev_of` returns `None` for it), so the device helper
and commit paths decline and the GPU contributes nothing while the
process still pays the CUDA context. **There is no GPU benefit for the
compact form until the four kernels listed at rung 2 exist** — which
matters, because the Ligero form on the GPU proves the same pass in
2.50 s. Today the choice is 2.50 s / 66.8 MB (GPU + Ligero) or 28.76 s
/ 13.5 MB (CPU + compact); the two wins do not yet compose.

### WHERE THIS LANE STOPPED

Rungs 0-5 complete. Not done, in priority order: (1) the **Merkle cap**
(-29% bytes [COUNTED], zero soundness and zero prover cost — the
cheapest remaining win, and it puts 125M inside the counted 3-12 MB
band at ~9.6 MB and 8B at ~44 MB); (2) the **four GPU kernels**, which
is what would let the size win and the speed win compose; (3) the
**ZK-compact form** specified above; (4) the **full 32x512 compact
pass** actually run rather than projected (~36 min under the current
prover, and it wants a quiescent box); (5) the soundness margin
(`2^-98.2` / `2^-95.1` vs Ligero's `2^-106`), which needs a degree-3
extension field or a smaller-piece cut, not more queries.

## ROUND 13 — THE FULL LAYER, AND THE KERNELS THAT ARE STILL 125M-SHAPED (opened 2026-09-03)

Ground: round 12 merged (159a511; build + 40 tests + FOUR byte gates
green: v2 50cf7bdf.., v3 5f368db6.., zk-v2 021485e4.., zk-v3
40eb5479..). What round 12 established: the 8B FFN proof runs on a
GPU in 175 s (2.9x the CPU) with byte-identical output; mode-P1
privacy costs +4.7% at 8B width; the proof shrinks 19.9x under a
compact commitment (at 95-98 bits, Victor's ruling pending); and
Mistral's attention is int8-clean except its residual stream, with
both integer chains reproducing 64/64 digests at 8B width.

THE TWO GAPS THIS ROUND ATTACKS, in the order they matter:
1. **The statement is still FFN-only.** Lane AE built everything up
   to the proof and stopped at a gated boundary. Its counted cost:
   a full layer is 2.87x the FFN-only cost at Mistral width, so a
   32-layer full-model prove models to ~24 min on this CPU. Lane AG
   builds the prover/verifier (AE's rungs 4-5).
2. **The GPU kernels are templated on the 125M block shape.** Lane
   AC measured 44% of the 8B GPU prove still on the HOST because the
   device-shape gate declines Mistral's shape (13/15 tables vs 73),
   and lane AD measured the table zero-check at 20% of the GPU ZK
   prove for the same reason. Both fixes are byte-preserving and
   worth ~1.5x on the 8B pass. Lane AH does them.

Standing rules unchanged (no background runs; > ~8 min posted as
ORCHESTRATOR-RUN; commit rung 0 within 15 minutes AND after every
rung — the 2026-09-03 cutout proved this is what saves a lane; the
four byte gates must stay green; append ONLY to your own status
section, which exists below, so merges stay mechanical).

### Lane AG — the FULL-LAYER proof (wt-uperf3-ag) — RUST (lane AE's rungs 4-5)
OWNS: hashline/src/attention.rs, norm.rs, tables_attn.rs (ADDITIVE),
the NEW full-layer prover/verifier functions in layer.rs (tagged
[UPERF3-AG]), the `--attn` flag lines in src/bin/hashline.rs, NEW
results/hashline_attn_*, the FULL-LAYER row in
docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md §3 (only when MEASURED),
"Agent AG status". READ-ONLY: pcs.rs, pcs_compact.rs, sumcheck.rs,
transcript.rs, zk.rs, wcache.rs, gpu/* (lane AH's), export_v3.rs,
tables_v3.rs, silu.rs, the v2/v3 FFN functions in layer.rs,
zkmatrix-rs/, scripts/ (import, never edit).
SPEC: the "WHERE THE LANE STANDS" block at the end of "## Agent AE
status" lists exactly what rungs 4 and 5 must build. Read AE's whole
status section first, then attention.rs and norm.rs (the value chain
is already green and digest-checked at 125M and Mistral layer 0).

### Lane AH — shape-general device kernels (wt-uperf3-ah) — RUST/CUDA
OWNS: hashline/src/gpu/* (kernels.cu, cuda.rs, mod.rs), the
`dev_shape` gate line in layer.rs (tagged [UPERF3-AH]; lane AG adds
NEW attention functions to that file — never edit its regions), NEW
results/hashline_gpu_shapegen_*, "Agent AH status". READ-ONLY:
everything else.
GOAL: make the zero-check and LogUp-helper kernels loop over blocks
instead of being compiled for one block shape, so the device-shape
gate stops declining Mistral's shape; and put the table zero-check
on the device (lane AD's 20%-of-the-GPU-ZK-prove item). ACCEPT: the
four byte gates unchanged; the 8B GPU pass's host share measured
before and after (AC's 44%); the 8B GPU prove wall re-measured
(175.09 s is the number to beat; ~105-125 s is AC's [MODEL]); the
GPU ZK prove re-measured (5.63 s at 12x512 v3 is AD's number).

## Agent AG status (wt-uperf3-ag) — round 13

(lane appends below)

LANE: THE FULL-LAYER PROOF on the hash line — attention + the two norms +
the residual stream + the seam, i.e. lane AE's rungs 4 and 5. Worktree
wt-uperf3-ag, branch uperf3-ag. Every wall [WSL-BOX] [8T] [CPU|GPU]
[NOISY-SHARED] (lane AH builds and runs on the same box).

OWNS (recorded): hashline/src/{attention,norm,tables_attn}.rs (ADDITIVE),
NEW full-layer functions in layer.rs tagged [UPERF3-AG] (never lane AH's
`dev_shape` line), the `--attn` flag lines in src/bin/hashline.rs, NEW
results/hashline_attn_*, the §3 FULL-LAYER row (only when MEASURED), this
section. READ-ONLY: pcs.rs, pcs_compact.rs, sumcheck.rs, transcript.rs,
zk.rs, wcache.rs, gpu/*, export_v3.rs, tables_v3.rs, silu.rs, the v2/v3
FFN functions in layer.rs, zkmatrix-rs/, scripts/.

### AG rung 0 — THE PLAN + THE FOUR GATES (2026-09-03) [WSL-BOX 8T CPU NOISY-SHARED]

Fresh CPU build in this worktree (35.8 s). **The four byte gates re-run
here, all unchanged**: v2 `pass 12 512 --threads 8 --proof-out F` ->
**50cf7bdfd6b5b182..** (66,844,928 B; PROVE 14.86 s); v3 `--profile v3
--export <aa v3 export>` -> **5f368db6240e0614..** (70,758,084 B; 16.01 s);
zk `--zk --seed 1` -> **021485e4f80ec695..** (87,228,528 B; 21.44 s);
zk-v3 `--zk --seed 1 --profile v3` -> **40eb54795e023c77..** (87,697,008 B;
22.95 s).

**THE SHAPE OF THE PROOF I AM BUILDING** (the object list of the full-layer
statement, each object with the primitive that proves it; AE's rung-0 spec
table is the semantics, this is its realization on the hash line's
primitives). Three NEW commitments per layer beside the FFN's three:
`Wa` (Wq/Wk/Wv/Wo + the two norm gammas), `Aa` (every committed attention
plane), `Ha` (the LogUp helper columns of the attention domains). The
attention half is proven by FOUR zero-checks (one per index domain) plus
SIX sumchecks, and is bound to the FFN half by TWO seam claims:

| # | what is proven | primitive | domain (125M) |
|---|---|---|---|
| 1 | SS_t = sum_i x_in(t,i)^2 (both norm sites) | degree-3 row-sum sumcheck, terminal = a claim on x_in | (t,i), T x d |
| 2 | D = isqrt(SS + Ceps): Dsq = D D, a1 = SSe - Dsq, a2 = 2D - a1, a1/a2 as U16 limb pairs | row zero-check + U16 LogUp | t, T |
| 3 | xn8 (and xm8) = round-divide(x g Cn, D 2^tn): y (2 div) + rho = 2 num + div, sigma = 2 div - 1 - rho, rho/sigma U16 limb pairs, y int8 | the d-domain zero-check (D row-broadcast, g column-broadcast: both free, the MLE of a broadcast table at (r_t, r_i) IS the small plane's MLE) + LogUp | (t,i), T x d |
| 4 | Qacc/Kacc/Vacc = xn8 . W^T and the requant acc = 2^sh y + r | three matmul sumchecks over the inner d; the acc claim is 2^sh y~(p) + r~(p) at a fresh point p | inner d |
| 5 | RoPE: QRacc = c q_lo - s q_hi \| s q_lo + c q_hi against the PUBLIC rope-cs tables, then the requant to qr8 | the q/kv-domain zero-checks reading q8 at the coordinate-FLIPPED point (PW-1: the flip is a public permutation of the low index bit, one extra opening point) | (t, h, i) |
| 6 | Sacc(h,t,j) = sum_i qr8(t,h,i) kr8(j,g(h),i) | ONE per-head matmul sumcheck over i; the GQA map g(h) = high bits of h is FREE (sum_h eq(r_h,h) F(g(h)) = sum_g eq(r_h-high,g) F(g)) | inner d_h |
| 7 | s8 int8 + rS in the balanced window; m dominance d = m - sM in [0,255]; zsel binary, sum_j zsel = 1, zsel d = 0 (attainment); E from the fused (d,E) LogUp; P Sum + rho = 2^fP E on the mask and P = rho = 0 off it; P in [0,2^fP]; rho, sigma = Sum - 1 - rho in [0,2^wrho) | the S-domain zero-check (degree 5: the fused exp row is degree 2 because sM = mask s8 + (1-mask)(-127)) + five LogUp tables (INT8, WIN, EXP, PROB, SREM) + the masked row-sum sumcheck (batched with sum_j zsel = 1) | (h,t,j), H x T x T |
| 8 | Oacc(t,h,i) = sum_j P(h,t,j) v8(j,g(h),i) | one matmul sumcheck over j | inner T |
| 9 | o8 requant + int8; AOacc = o8 . Wo^T; ao requant + class | the o-domain zero-check + one matmul sumcheck over the inner H d_h | (t,h,i) / inner d |
| 10 | xres1 = requant(x_in 2^a + ao 2^b) and xres2 = requant(xres1 2^a' + z16 2^b') | two LINEAR pins in the d-domain zero-check + INT16/INT24 and window lookups | (t,i) |
| 11 | THE FFN HALF on X = xm8 | the existing `prove_layer_v3` (READ-ONLY, byte-identical) on the same transcript | — |
| 12 | THE INNER SEAM: the FFN's X IS this layer's xm8, and the copy z16c used by pin 2 IS the FFN's z16 | the v3 proof opens X and z16 at rho_d (its zero-check D point, drawn AFTER both A commitments); the attention opening is DEFERRED to after that and adds xm8~(rho_d) and z16c~(rho_d) as claims on Aa, checked equal to the v3 proof's zcd_term values | rho_d |
| 13 | THE LAYER SEAM: layer l+1's x_in IS layer l's xres2 | the same mechanism one layer later: layer l's Aa opening is deferred until layer l+1's Aa is committed, then both are opened at one point drawn after both commitments | a fresh point |

Deferred and stated (unchanged from AE): the embedding gather, the final
norm and the LM head, the KV cache / decode regime, sliding windows.

WHY THIS SHAPE. The v3 FFN prover folds every pending claim into its two
zero-checks so that A and H open at exactly two points; that is a
proof-SIZE optimization. The attention half has ~30 planes over five
different index domains, and folding them all would double the build. I
take the other trade: many claims at many points (the PCS batches claims
that share a point into one group vector of 2^log_cols Fp2 each), which
costs bytes and buys a prover I can land in one session. Every claim is
still a real PCS opening of a committed plane — soundness is unchanged.

BUILD ORDER (each its own commit, each green before the next): (a) the
witness + layout: every plane of AE's chain as a committed vector, the
digests still reproducing the oracle's; (b) the matmul sumchecks (QKV, the
per-head score, PV, Wo) alone, checked against the chain's values; (c) the
norms and RoPE; (d) the softmax LogUp + row sum + division; (e) the
residual pins, the inner seam and the assembled full-layer prover/verifier
with the tamper legs; (f) the 12-layer pass with the layer seams bound.

ORCHESTRATOR-RUN (only if a step needs > ~8 min): none yet.

### AG rung 4 — THE FULL LAYER IS PROVEN (2026-09-03) [MEASURED WSL-BOX 8T CPU NOISY-SHARED]

**One full transformer layer of the 125M model — attention + both RMSNorms
+ the residual stream + the v3 FFN half + the seam between them — proves
and verifies.** This is the first proof in this project that covers a whole
layer rather than its feed-forward half.

    hashline attn-full <attn-export> --export <v3-export> --t 512 --threads 8

| shape (125M layer 0) | PROVE | VERIFY | proof | peak RSS | verdict |
|---|---:|---:|---:|---:|---|
| FULL layer, T = 512 | **10.12 s** (8.77 s on a second run) | 0.23 s | 33.2 MB (attention half 27.3) | 5.10 GB | ACCEPT |
| FFN-only layer, T = 512 (`layer 0 512 --profile v3`) | 1.65 s | 0.03 s | 5.90 MB | 1.12 GB | ACCEPT |
| **full / FFN-only** | **6.1x** | 7.4x | 5.6x | 4.5x | — |
| FULL layer, T = 256 | 4.21 s | 0.29 s | 27.0 MB | 2.11 GB | ACCEPT |
| FULL layer, T = 128 | 2.68 s | 0.28 s | 24.1 MB | 1.06 GB | ACCEPT |
| FULL layer, T = 64 | 1.15 s | 0.13 s | 23.0 MB | — | ACCEPT |

AE's rung-3.5 count predicted 4.58x on committed elements; the measured
6.1x is that plus this build's two deliberate trades (below). The wall
grows sub-quadratically in T here only because the T-independent parts
(the weight commitment, the group vectors) still dominate at T <= 256.

**THE TAMPER LEGS — 10 of 10 REJECT at T = 512** (and at T = 64; a
cheating prover's own consistency asserts are silenced by
`set_tamper_mode`, so the VERIFIER is what rejects):

| leg | rejected by |
|---|---|
| flipped score s8 | the score matmul sumcheck |
| wrong exponential-table entry (E) | the LogUp identity |
| wrong softmax quotient (P) | the softmax zero-check |
| wrong norm output (xn8) | the D-domain zero-check |
| wrong RoPE rotation (qr8) | the Q-domain zero-check |
| wrong row maximum (m) | the softmax zero-check |
| flipped layer input x_in | the SS row-sum sumcheck |
| **BROKEN SEAM** (the z16 copy changed and the residual pin *recomputed* so only the seam can catch it) | **the seam claim** |
| FFN half: wrong int16 table entry | the FFN's LogUp identity |
| FFN half: wrong requant h16 | the FFN's zero-check |

plus, in the attention-half-alone mode (`hashline attn-layer`), wrong
isqrt D (the isqrt pair) and a moved attainment selector (the softmax
zero-check): **12 distinct legs in all**.

**WHAT THE STATEMENT PROVES** (the object list of rung 0, as built):
x_in -> attn_norm (SS row-sum sumcheck; D = isqrt via the a1/a2 pair with
U16 limbs; Dsq = D D; the ROUND division y (2 div) + rho = 2 x g Cn + div
with D row-broadcast and gamma column-broadcast, both free) -> Q/K/V by ONE
batched matmul sumcheck over the inner d -> RoPE as a zero-check reading q8
at the coordinate-FLIPPED point against the public cos/sin tables -> the
per-head score matmul (ONE sumcheck over (kv head, head dim): the GQA map
is the high bits of the padded head index, so it costs nothing) -> the
softmax (int8 + window lookups on s8/rS; dominance and the exponential by
the FUSED (d, E) LogUp with d = m - mask s8 computed in the constraint;
zsel binary with row sum 1 and zsel d = 0; the division P Sum + rho = 2^fP E
on the mask and P = rho = 0 off it; P in the PROB table, rho and the DERIVED
sigma = Sum - 1 - rho in the SREM table) -> the masked row sum of E batched
with sum_j zsel = 1 -> the PV matmul (one sumcheck over (kv head, j)) ->
o8 -> the Wo matmul -> ao -> residual pin 1 -> mlp_norm -> **xm8, which IS
the FFN half's X plane** -> the v3 FFN (unchanged `prove_layer_v3`) -> z16
-> residual pin 2 -> xres2, the layer's output.

**THE SEAM, exactly.** The attention half commits its planes FIRST; the FFN
half then commits its own on the same transcript; the FFN's zero-check D
draws rho_d AFTER both commitments; the attention half's PCS opening is
DEFERRED until then and adds two claims per d-block — xm8~(rho_d) and the
z16 copy~(rho_d) — checked equal to the FFN proof's own zcd_term values.
`layer.rs::v3_zcd_point` [UPERF3-AG] recovers rho_d by replaying the v3
transcript walk on a clone (neither prove_layer_v3 nor verify_layer_v3
returns it, and both are read-only for this lane).

**TWO DELIBERATE TRADES, recorded so the next agent can undo them.**
(1) *Padding, not blocking.* Every axis is padded to a power of two (d 768
-> 1024, the 12 query heads -> 16 slots with the GQA group as the high bits)
so one plane is ONE slice; the padding is INERT because the pad columns and
pad heads carry the values the chain itself produces on zero inputs (a zero
gamma column: rho = div, sigma = div - 1; a zero query head: its own
softmax and PV). Cost at 125M: 1.33x on the two dominant domains, nothing
at Mistral (d 4096, H 32 are already powers of two).
(2) *Many opening points, not folded claims.* The v3 FFN prover folds every
pending claim into its two zero-checks so A and H open at two points; this
prover opens at ~20 points (one group vector of 2^log_cols Fp2 each). That
is why the attention half's proof is 27.3 MB where the FFN half's is 5.9:
about 8 MB of it is group vectors that folding would remove. Folding is the
named next optimization; it changes no soundness property.

**The honest note on composition.** The FFN half is proven on the attention
half's OWN xm8, not on the v3 export's X plane; the two agree on 31% of
elements at T = 512 (0.3102), which is the integer chain's drift from the
fp forward that AE's rung-2 cascade leg already measured (xm8 cascade
agreement 0.31). A full-layer proof MUST use the attention half's output —
that is the point of the seam — so the export's X plane is only a
reference here.

Commits: b18e114 (the witness refactor), 37b9a29 (the attention prover and
verifier, first green), the tamper-leg commit, 715fc48 (the full layer).

### AG rung 5 — THE 12-LAYER FULL-MODEL PASS + ONE FULL MISTRAL LAYER (2026-09-03) [MEASURED WSL-BOX 8T CPU NOISY-SHARED]

**THE 12-LAYER 125M FULL-MODEL PASS, SEAMS BOUND, ACCEPTS.** Every layer's
attention half and FFN half on ONE transcript; both seams proven; nothing
committed twice.

    hashline attn-pass <attn-export-prefix> 12 --export <v3-export> --t 512 --threads 8

| pass | witness | PROVE | VERIFY | proof | peak RSS | verdict |
|---|---:|---:|---:|---:|---:|---|
| **12 FULL layers x 512, seams bound** | 4.95 s | **94.54 s** | **2.03 s** | **404.3 MB** | **6.56 GB** | **ACCEPT** |
| 12 FFN-only layers x 512 (`pass 12 512 --profile v3`) | 1.60 s | 16.01 s | 0.43 s | 70.8 MB | ~1.2 GB | ACCEPT |
| ratio | | **5.9x** | 4.7x | 5.7x | 5.5x | |
| 12 FULL layers x 64 | 1.13 s | 17.37 s | 1.59 s | 281.5 MB | — | ACCEPT |

PROOF sha256 **c91f8713e2ed805543c1ca3a5f1c752734278606e7b13d199f1348dbf22f0ece**
(404,327,452 B; at T = 64: 05f54591e28630d8.., 281,521,404 B). Proven work
4.349e10 MACs (3 d f + 2 d^2 + 2 d d_kv + 2 T d per token per layer) =
**4.60e8 proven MAC/s** against 1.8e9 for the FFN-only pass: the full
statement proves 3.9x fewer MAC/s because attention's committed planes are
quadratic in T while its MACs are not.

**THE LAYER SEAM, exactly.** Layer l's xres2 IS layer l+1's x_in: ONE MLE
equality at a point drawn after BOTH layers' A commitments. Layer l's A
opening is deferred until layer l+1 has committed (its W and H close
early, so only one extra A commitment is resident: that is what keeps the
pass at 6.56 GB). The leg that tests it: layer 1's x_in changed by one and
its WHOLE witness rebuilt on it, so every other relation still holds —
**REJECT: "layers 0->1: layer seam: the previous layer's xres2 != this
layer's x_in"**.

**ONE FULL MISTRAL-7B LAYER (int24 residual, ao int16), layer 0:**

| shape | PROVE | VERIFY | proof | peak RSS | verdict |
|---|---:|---:|---:|---:|---|
| **FULL layer, T = 16** | **12.91 s** | 0.11 s | 48.5 MB | 10.08 GB | ACCEPT, **10/10 legs reject** |
| FFN-only layer, T = 16 | 11.03 s | 0.04 s | 25.9 MB | 7.48 GB | ACCEPT |
| **FULL layer, T = 64** | **14.27 s** | 0.13 s | 52.8 MB | 11.24 GB | ACCEPT |
| FFN-only layer, T = 64 | 8.86 s | 0.02 s | 27.1 MB | 8.04 GB | ACCEPT |

**THE HEADLINE SHAPE OF THE COST: the full-layer surcharge SHRINKS with
width and GROWS with context** — 6.1x at 125M/T512, **1.17x at 8B width
and T = 16**, 1.61x at 8B width and T = 64 — for the same reason the ZK
surcharge shrinks with width: the weight commitments dominate a wide model
and attention adds only four more weight matrices, while its six committed
H x T x T planes are quadratic in T. AE's counted 2.87x is the T = 512
number at 8B; the 32-layer 8B full-model pass is NOT measured (the
FFN-only row alone peaks at 14.0 GB on this 15 GB box; the attention half
adds ~2 GB plus the quadratic planes, so it needs the Mac).

**THE MISTRAL CHAIN GATE re-run here: 64/64 tensor digests + CHAIN
4085604b8d61ce8c.. (4.40 s)**, so the int24 path proves the exact chain AE
recorded. The 125M gate is 64/64 at layers 0 and 2-11; **layer 1 differs**
and the reason is recorded: the ORACLE fits the score requant shift PER
HEAD (`fit_requant` inside its head loop), this statement uses ONE score
shift per layer (a per-head shift would need a per-head window table and a
per-head coefficient in the score claim — the head-restricted claims are
cheap, ~hp claims in one PCS group, but it was not worth the build here).
At layer 1 one head wanted a bump, so all 12 heads take it: one bit of
score resolution on that layer, no soundness consequence.

**TWO CALIBRATION FACTS the composition forced (both public statement
constants, never silent clamps).** (1) The mlp norm's OUTPUT exponent is
pinned to the FFN export's X exponent, so the two halves meet on one grid.
(2) The FFN half's four requant shifts are FITTED to the attention half's
xm8 — its export was calibrated on its own X plane, which the composed
statement replaces — and when the gate shift rises, the FROZEN int16-out
table member for the new gate exponent is re-selected from the registry
(never a re-derived table). Over the 12 layers exactly one bump occurred
(layer 4, the Hadamard shift, +1).

**THE FOUR BYTE GATES, re-run on this tree after every Rust change:** v2
**50cf7bdfd6b5b182..**, v3 **5f368db6240e0614..**, zk **021485e4f80ec695..**,
zk-v3 **40eb54795e023c77..** — all unchanged; `cargo test --release` 40/40.

RECORD -> results/hashline_attn_fulllayer.md; the §3 FULL-LAYER rows are in
docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md.

### WHERE THIS LANE STANDS (for the next session)

Rungs 0, 4 and 5 are done and committed; the full-layer statement is real,
measured and non-vacuous at both model widths. What the next agent should
pick up, in the order the numbers argue for:

1. **FOLD THE CLAIMS** (proof size). The attention half opens A/W/H at ~20
   points; the v3 FFN prover folds every pending claim into its two
   zero-checks and opens at two. About 8 MB per 125M layer — two thirds of
   the attention half's 27.3 MB — is group vectors that folding removes.
   No soundness change, no new machinery: the same `nu`-weighted eq terms
   the v3 zero-checks already carry.
2. **BLOCK, DON'T PAD** (prover time at 125M). d 768 -> 1024 and 12 heads
   -> 16 slots cost 1.33x on the two dominant domains. Nothing at Mistral.
3. **THE 32-LAYER 8B FULL-MODEL PASS.** Needs the Mac (256 GB): the
   FFN-only row alone peaks at 14.0 GB here. The Mistral attention exports
   are ~30 s each (`scripts/attention_hash_ref.py --arch mistral --layer L
   --tokens-cache <cache> --export DIR`); the token cache is
   scratchpad/mistral_toks.npy (tokenizing from scratch is ~5.5 min).
4. **THE GPU.** The attention half is CPU-only. Its zero-checks have the
   same shape as the v3 ones (eq * a sum of helper constraints), so lane
   AH's shape-general kernels should apply directly; the S-domain
   zero-check (13 tables, degree 5, hp T^2 rows) is 40-50% of the
   attention half's wall at T = 512 and is the first kernel to port.
5. **ZERO KNOWLEDGE for the attention half.** ZA's mask/pad treatment
   applies plane for plane; the only new object is the fused (d, E) LogUp
   row (its l1 is degree 2, so the CFS mask degree rises by one).
6. **The statement's remaining holes**, unchanged and stated in the record:
   the embedding gather, the final norm and the LM head, the KV cache /
   decode regime (prefill only), sliding windows.

New CLI (all tagged [UPERF3-AG]): `attn-layer <dir>` (the attention half
alone, 12 legs), `attn-full <dir> --export <v3>` (one full layer, 10 legs),
`attn-pass <prefix> <n> --export <v3>` (the full-model pass, seams bound,
+ the layer-seam leg), all with `--t T` to truncate the token axis.

## Agent AH status (wt-uperf3-ah) — round 13

(lane appends below)

### AH rung 0 — the plan (2026-09-03, WSL-BOX, wt-uperf3-ah, branch uperf3-ah)

Read: START_HERE (whole), the round-13 block + this brief, Agent AC in
full (the 8B GPU pass, its per-phase anatomy, the 44% host share),
Agent AD (the table zero-check = 20% of the GPU ZK prove), Agent XX
(the kernel inventory, the buffer pool, the byte-identity discipline);
the code: gpu/{mod.rs,cuda.rs,kernels.cu}, layer.rs's v2 and v3 device
regions, zk.rs's v3 device regions.

**WHAT IS SHAPE-TEMPLATED TODAY (the finding, stated exactly).** Three
places, not one:
1. `kernels.cu`: `sc_round_impl<K, KIND>` holds `f2 cur[K], dif[K]` in
   REGISTERS, so K must be a compile-time constant; the only two
   instantiations are `k_sc_round_zc20 = <13, 0>` and
   `k_sc_round_zc17 = <15, 1>`. 13 = 3 eq + 10 x nb_f at nb_f = 1;
   15 = 3 eq + 4 x nb_d at nb_d = 3. `zc20_poly` / `zc17_poly` read the
   per-block coefficients out of a 32-u64 shared array (`sprm[32]`),
   which is exactly big enough for ONE f-block (4 mu + 3 nu) or THREE
   d-blocks.
2. `cuda.rs::dev_zerocheck`: `assert_eq!(k, want_k)` (13 / 15) and
   `assert!(prm.len() <= 32)`.
3. `layer.rs`, the three device regions of `prove_layer_v3`: the
   helper-spec list hard-codes f-block **[0]** (three specs) and the
   two `TabSpec` lists hard-code block [0] on the F side; only the
   d-side loops. Hence the gate at line 1411 (and its twin in zk.rs at
   2004): `let dev_shape = nb_f == 1 && nb_d == 3;`

**WHAT THE GATE DECLINES, AND WHY IT COSTS 44%.** `LayoutV3` splits d
into `nb_d` blocks of 2^log_db (log_db = min(v2(d), 12)) and f into
`nb_f` blocks of 2^log_fb. 125M: d 768 = 3 x 256, f 2048 = 1 x 2048 ->
(nb_f, nb_d) = (1, 3) = the templated shape. **Mistral-7B: d 4096 =
1 x 4096, f 14336 = 7 x 2048 -> (nb_f, nb_d) = (7, 1)**, so zero-check
F has 3 + 10 x 7 = **73** tables and zero-check D has 3 + 4 x 1 = **7**;
neither is 13 or 15, the gate is false, and THREE phases fall back to
the host: the LogUp helper columns (inside "helpers + commit H"), zc F
and zc D. AC measured that as 46.64 + 7.48 s of host zero-check plus
~0.7 s/layer of host helpers in the 175.09 s 8B GPU prove = the 44%.

**THE APPROACH (byte-preserving by construction).**
- (R1/R2) A BLOCK-LOOPING round kernel per side. The round polynomial
  is `eqt*ZC + eq1*F1 + eq5*F5` where ZC/F1/F5 are SUMS OVER BLOCKS of
  terms that read only that block's 10 (F) / 4 (D) tables. So the
  kernel keeps 15 f2 accumulators (3 partial sums x 5 evaluation
  points), loops over blocks loading 10 (or 4) `cur`/`dif` pairs into
  registers per block, and joins with the three eq tables at the end —
  register footprint ~ the templated kernel's, independent of the
  block count. Parameters move to a larger shared array with the
  length passed at launch. The 13/15 templated kernels STAY and stay
  the default at their shapes, so XX's measured 125M numbers cannot
  move; the generic kernels are used only where the gate is false
  today (and are A/B'd against the templated ones at 12x512).
- `dev_zerocheck` derives the block count from `specs.len()`
  ((k-3)/10 for kind 0, (k-3)/4 for kind 1), so the v2 and zk.rs call
  sites need NO change.
- (R2) The helper-spec list in layer.rs loops `for b in 0..nb_f` (the
  `k_helper` kernel is already length-general); the TabSpec lists loop
  the same way. These are three small edits inside the v3 FFN prover,
  each tagged `[UPERF3-AH]`; lane AG owns the NEW attention functions
  in that file and the v2/v3 FFN functions are read-only for AG, so
  the lanes do not overlap.
- SAFETY (a real hazard, handled): when the device helper path runs,
  `host_tabs` is never built, and a LATER device decline panics by
  design. At Mistral the zcF table buffer is 73 x 2^20 x 2 u64 = 1.22
  GB of VRAM on top of AC's measured 4,175 MB peak, so a decline is
  possible. The device path therefore RESERVES both zero-check table
  buffers (through the XX pool, which matches by exact length, so the
  reservation IS the later allocation) before it commits to device
  helpers; failure -> the whole layer takes today's host path, exactly
  as now.
- (R3) The table zero-check (zk.rs) runs `masked_prove`, not
  `sumcheck::prove`; it is a different kernel family (mask rows), so
  it comes after R1/R2 and only if the byte gates and the 8B pass are
  in hand.

**THE FOUR BYTE GATES on both binaries and the BASELINE follow in this
rung's second half.**

**RUNG 0 — THE FOUR BYTE GATES ON BOTH BINARIES: ALL EIGHT GREEN, AND
THE BASELINE (2026-09-03, WSL-BOX, 8T + RTX 4070 Laptop, box quiet at
the time — load < 1, 14 GB available, GPU 30 MB used; lane AG was not
running heavy work. [MEASURED], `flock /tmp/zk-heavy.lock`, one run
each, proofs written and `sha256sum`'d by hand as well as by the
binary).** Builds: CPU 36.3 s, GPU 41.0 s, both clean.

| gate (`pass 12 512 --threads 8 --proof-out F`, + the flags) | CPU PROVE | GPU PROVE | sha256 | bytes |
|---|---:|---:|---|---:|
| v2 | 17.40 s | **2.46 s** | `50cf7bdfd6b5b182..` | 66,844,928 |
| v3 `--profile v3 --export .../m125_v3_export` | 17.71 s | **2.51 s** | `5f368db6240e0614..` | 70,758,084 |
| zk-v2 `--zk --seed 1` | 20.86 s | **4.02 s** | `021485e4f80ec695..` | 87,228,528 |
| zk-v3 `--zk --seed 1 --profile v3 --export ...` | 17.94 s | **4.66 s** | `40eb54795e023c77..` | 87,697,008 |

All four digests = the round-12 references, from both binaries. (The
GPU zk-v3 4.66 s is this box's quiet reading of AD's 5.63 s p50, which
was taken with three lanes on the CPU; AD's number stays the one to
beat and both are quoted in rung 3.)

**THE BASELINE THIS LANE MUST MOVE — one real Mistral-7B layer at
T = 512 on the GPU** (`HL_GPU=1 pass 1 512 --profile v3 --export
/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export --threads 8
--proof-out F`, `/usr/bin/time`): **PROVE 5.515 s**, verify 0.04 s,
proof 38,688,700 B, sha256 **179ec2fb8f99d0d6..** (= AC's rung-3
digest, which is also the CPU's), RSS 4.17 GB, **VRAM peak 4,175 MB**;
AC measured 5.56 s for the same run [MEASURED, WSL-BOX 8T GPU, QUIET].
Phases, with the HOST share marked (d 4096, f 14336 -> nb_f 7, nb_d 1,
so `dev_shape` is FALSE and three phases run on the CPU):

| phase | s | on |
|---|---:|---|
| commit W | 1.291 | device (chunked, 3 chunks) |
| commit A | 0.450 | device |
| helpers + commit H | 1.022 | **HOST helpers** + device commit |
| matmul g/u | 0.170 | host folds |
| matmul d | 0.093 | host folds |
| **zero-check F** | **1.454** | **HOST** |
| **zero-check D** | **0.236** | **HOST** |
| pcs openings | 0.785 | device folds + host Merkle/serialize |

Device-side: h2d 0.498 s (2,257 MB), ntt 0.525 s, fold 0.228 s,
opening re-encode 0.510 s. **THE HOST SHARE THIS LANE ATTACKS: 1.454 +
0.236 + ~0.7 (the helper columns inside "helpers + commit H") = ~2.39 s
of the 5.515 s = 43.3%** — AC's 44% reproduced at one layer
[MEASURED/COUNTED].

**RUNGS 1 + 2 — THE BLOCK-LOOPING ZERO-CHECK KERNELS AND THE LOGUP
HELPER COLUMNS AT ANY BLOCK COUNT: GREEN, BYTE-IDENTICAL (2026-09-03,
WSL-BOX 8T + RTX 4070 Laptop, [MEASURED], box quiet).** The two rungs
landed in one change because they are the same gate: the helper
columns and the two zero-checks are all-or-nothing (once the helpers
go to the device there are no host tables to fall back to).

WHAT LANDED (gpu/*, additive; three tagged edits in layer.rs's v3 FFN
prover):
- `kernels.cu`: **`k_sc_round_zcf_gen` / `k_sc_round_zcd_gen`** — the
  round polynomial is `eq_t*ZC + eq_a*F_a + eq_b*F_b` with ZC/F_a/F_b
  sums over blocks of terms reading only that block's own tables, so
  the kernel loops over blocks holding ONE block's cur/dif in
  registers (10 tables on the F side, 4 on the D side) and accumulates
  the three partial sums at the five evaluation points; the eq tables
  join once per element. The register footprint no longer depends on
  the block count — which is exactly what `sc_round_impl<K, KIND>`
  could not do. `__launch_bounds__(128, 1)`; the block-indexed
  parameters live in a 384-u64 shared array (bounds nb_f <= 26,
  nb_d <= 62 — Mistral needs 115 u64 at nb_f = 7).
- `cuda.rs`: `dev_zerocheck` split into `zerocheck_impl` +
  **`dev_zerocheck_blocks(kind, nb, ..)`**; the templated 13/15 path is
  untouched and is still what the v2 prover and zk.rs call.
  **`dev_reserve(&lens)`** takes both zero-check table buffers through
  the XX pool (exact-length match, so the reservation IS the later
  allocation) and gives them back — the device path now proves it can
  finish BEFORE it takes the helpers off the host.
- `layer.rs` (3 edits, all `[UPERF3-AH]`, none in lane AG's regions):
  the gate `nb_f == 1 && nb_d == 3` -> the kernels' real bound; the
  helper-spec list loops `for b in 0..nb_f` (3 nb_f + nb_d specs, was
  3 + nb_d with block [0] hard-coded); the two TabSpec lists loop the
  same way with the block-indexed parameter layout.

**THE RESULT — ONE MISTRAL-7B LAYER AT T = 512 ON THE GPU** (the same
command as rung 0's baseline, same box, same session):

| phase | before (rung 0) | after | factor |
|---|---:|---:|---:|
| commit W | 1.291 | 1.366 | 0.95 |
| commit A | 0.450 | 0.453 | 0.99 |
| **helpers + commit H** | **1.022** | **0.261** | **3.9x** |
| matmul g/u + d | 0.263 | 0.250 | 1.05 |
| **zero-check F** | **1.454** (HOST) | **0.144** | **10.1x** |
| **zero-check D** | **0.236** (HOST) | **0.024** | **9.8x** |
| pcs openings | 0.785 | 0.584 | 1.34 |
| **PROVE** | **5.515 s** | **3.090 s** | **1.79x** |
| RSS | 4.17 GB | **2.48 GB** | 1.68x less |
| VRAM peak | 4,175 MB | 5,651 MB | +1,476 MB (the zc tables) |

**PROOF sha256 `179ec2fb8f99d0d622dc2f868167c67c0ba2822c676b826fa1b01bdb3882a79b`
(38,688,700 B) — IDENTICAL to the rung-0 baseline, to AC's rung-3 GPU
row and to the CPU prover's.** Device-side after: h2d 0.467 s (1,871
MB — 386 MB less uploaded, the H columns are no longer built on the
host and copied up), ntt 0.524, **sumcheck 0.168**, fold 0.091,
**helpers 0.113**, opening re-encode 0.449. The host share AC measured
at 44% (the two zero-checks + the helper columns) is **0** — those
three phases are 0.429 s of device work now; the residual ~1.28 s of
host time in the 3.09 s is the witness-plane -> Fp conversions and
their upload, the Merkle levels, the claim bookkeeping and
serialization (XX's and AC's listed next levers, none of them a
declined kernel).

**NO REGRESSION AT THE 125M SHAPE, measured as an A/B in one session**
(2 runs each, `pass 12 512` on the GPU): the generic kernels on the v3
statement zcF **0.327 / 0.323 s**, zcD **0.085 / 0.079 s**; XX's
templated kernels on the v2 statement zc20 0.338 / 0.340 s, zc17 0.095
/ 0.103 s. Same shape (13 / 15 tables), same work, no measurable cost
for looping — so the shape-general form could replace the templated
one everywhere; it is kept beside it because XX's and ZA's measured
rows were taken with it.

**THE FOUR BYTE GATES, BOTH BINARIES, AFTER THE CHANGE: ALL EIGHT
GREEN** [MEASURED, one run each, `flock /tmp/zk-heavy.lock`; sha256
both from the binary and by hand]:
| gate | CPU | GPU |
|---|---|---|
| v2 | `50cf7bdfd6b5b182..` 14.61 s | `50cf7bdfd6b5b182..` 2.83 s |
| v3 | `5f368db6240e0614..` 15.15 s | `5f368db6240e0614..` 2.84 s |
| zk-v2 | `021485e4f80ec695..` 16.50 s | `021485e4f80ec695..` 4.09 s |
| zk-v3 | `40eb54795e023c77..` 18.78 s | `40eb54795e023c77..` 4.74 s |
Plus `pass 3 16 --profile v3` CPU == GPU (`5d49ab312eb720f5..`) and
`cargo test --release` **40/40**.

**RUNG 4 — THE 8B GPU PASS RE-MEASURED: 175.09 s -> 95.48 s (1.83x),
THE PROOF BYTE-IDENTICAL (2026-09-03, WSL-BOX 8T + RTX 4070 Laptop 8.6
GB, `flock /tmp/zk-heavy.lock /usr/bin/time -v`, cold cache = AC's cold
configuration, load 1.0 at the start, 14 GB available, GPU otherwise
idle; [MEASURED, NOISY-SHARED by convention — in fact quiet]).**

`HL_GPU=1 hashline pass 32 512 --profile v3 --export /home/victor/
wt-uperf3-aa/results/m8b_mistral_v3_export --wcache <fresh dir>
--threads 8 --proof-out F`

| | AC (round 12, cold) | **AH (this rung, cold)** | |
|---|---:|---:|---|
| witness load + chain | 130.75 s | 126.97 s | — |
| **PROVE** | **175.09 s** | **95.48 s** | **1.83x** |
| VERIFY | 1.09 s | 1.16 s | — |
| wall | 308.82 s | **225.35 s** | 1.37x |
| proof | 1,234,936,956 B | **1,234,936,956 B** | — |
| **sha256** | `dc980e81..4536c` | **`dc980e810085b2ddf4688eb4a6cf4dd931c209bf7c5a9a7692d57ec14bc4536c`** | **IDENTICAL** |
| peak RSS | 5.33 GB | **3.80 GB** | 1.40x less |
| VRAM peak | 4,175 MB | 5,651 MB | +1.48 GB |
| proven MAC/s | 1.648e10 | **3.023e10** | 1.83x |

(`sha256sum` run by hand over the written 1.23 GB file as well as by
the binary. So the 8B proof is now also invariant under the
shape-general kernels — device vs host, chunked vs resident, cached vs
fresh, 125M-shaped vs block-looping kernels: one digest.)

PHASES, summed over the 32 layers [MEASURED, s]:
| phase | AC GPU cold | **AH GPU cold** | factor | CPU reference |
|---|---:|---:|---:|---:|
| commit W | 38.85 | 41.94 | 0.93 | 224.97 |
| commit A | 13.53 | 15.85 | 0.85 | 81.77 |
| **helpers + commit H** | 35.24 | **5.36** | **6.6x** | 102.74 |
| matmul g/u | 5.38 | 5.25 | 1.02 | 6.58 |
| matmul d | 2.86 | 2.88 | 0.99 | 3.52 |
| **zero-check F** | 46.64 | **4.65** | **10.0x** | 50.82 |
| **zero-check D** | 7.48 | **0.79** | **9.5x** | 7.75 |
| pcs openings | 24.61 | 18.48 | 1.33 | 31.68 |
| **total** | **175.09** | **95.48** | **1.83x** | 510.38 |

Device-side: h2d 13.05 s (59,861 MB — 12.3 GB less uploaded than AC's
72,209 MB, the host-built H columns are gone), ntt 15.85, **sumcheck
5.44**, fold 2.89, **helpers 1.38**, opening re-encode 14.28, 96
chunked commits, d2h 1,413 MB. wcache: 32 misses, 134.2 MB written,
commit(miss) 20.61 s.
**THE HOST SHARE: AC's 76 s of declined kernels (44% of 175 s) is
0.** The three phases that were host work are 10.80 s of device work.
What is left in the 95.48 s is the same list XX and AC recorded, none
of it a declined kernel: the witness planes -> Fp conversions and
their pageable upload (13.0 s of h2d alone, ~0.6 GB/s per layer), the
opening's chunked re-encode (14.3 s), the Merkle levels + claim
bookkeeping + serializing 1.23 GB (~13 s of the 18.5 s openings), and
the encode NTT (15.8 s).
**THE 8B FFN PASS NOW PROVES IN 95.5 s ON A LAPTOP GPU AGAINST 510.4 s
ON 8 CPU THREADS — 5.35x — in 3.80 GB of host RSS and 5,651 MB of the
part's 8,188** [MEASURED].

**RUNG 3 — THE ZK TABLE ZERO-CHECK ON THE DEVICE (lane AD's item):
GREEN, BYTE-IDENTICAL (2026-09-03, WSL-BOX 8T + RTX 4070 Laptop,
[MEASURED], 3 runs).** What landed: `k_sc_round_tab_gen` (the DEGREE-3
round — 4 evaluation points, not 5; `scg_emit` templated on the value
count) and **`dev_tab_zerocheck`** in cuda.rs with a new
`TabSpecPad` (a table whose live length is shorter than the sumcheck's
2^log_S: the buffer is zeroed once and only the live prefix written,
which is the host's `resize(big, ZERO)` exactly). The public table
values (`tvals`) are the one uploaded table; m comes from the resident
A data, h from the resident H data. ONE tagged edit in zk.rs's v3
prover (the file is otherwise untouched): the device attempt runs on a
**cloned transcript state** and a decline falls through to the
unchanged host body with nothing absorbed — proven live, since the
first build declined for a missing kernel name and the 3x16 ZK proof
came out at AD's digest `4d9f7632..` anyway.

| at 12x512 v3 `--zk --seed 1`, GPU | before | after |
|---|---:|---:|
| **table zero-check (zk) phase** | **0.700 s** | **0.322 s** (2.2x) |
| zero-check F (zk) | 0.374 | 0.362 |
| zero-check D (zk) | 0.122 | 0.120 |
| **PROVE p50 (3 runs)** | **4.56 s** | **4.16 s** |
| proof | 87,697,008 B `40eb5479..` | **identical** |

(AD's records, taken with three lanes loading the box, were 1.14 s of a
5.63 s prove = 20%; this tree's quiet before/after is 0.700 of 4.56 =
15.4% -> 0.322 of 4.16 = 7.7%. The residual 0.322 s is NOT the
sumcheck any more: it is the phase's host tail — the 12 `eval_slice`
mask evaluations, the extension round and the absorbs.)
LEGS: `HL_GPU=1 layer 0 512 --zk --seed 1 --profile v3 --all-tampers`
-> **8/8 REJECT, GREEN**, with AD's exact split (the four lookup legs
at `H: pcs zk: group 4`, the other four at `sumcheck round 0`).
GATES after this rung: all four on both binaries green again
(`50cf7bdf..` CPU 14.72 / GPU 2.52 s, `5f368db6..` 15.17 / 2.70,
`021485e4..` 16.94 / 3.91, `40eb5479..` 19.25 / 4.16); `cargo test
--release` 40/40.
OWNERSHIP NOTE, stated plainly: this rung needed one edit in zk.rs,
which the lane brief lists as READ-ONLY while the rung-3 assignment
asks for exactly this port. The edit is one `[UPERF3-AH]`-tagged block
that wraps the existing host body in a `match` (the host body is byte
for byte the old code, moved into the `None` arm); no other line of
zk.rs changed, and no round-13 lane owns that file.

**RUNG 5 — THE RECORD, AND THE 8B PASS RE-RUN ON THE FINAL BINARY
(2026-09-03).** The rung-4 run was taken before rung 3 landed, so the
whole pass was repeated on the final binary with a fresh cache dir
(cold, as before): **PROVE 104.42 s**, verify 1.01 s, witness load
130.30 s, wall 237.57 s, RSS 3.85 GB, VRAM 5,651 MB, **sha256
`dc980e810085b2ddf4688eb4a6cf4dd931c209bf7c5a9a7692d57ec14bc4536c`
(1,234,936,956 B) — the same digest, verified by hand**. The 8.9 s
against run 1's 95.48 s is entirely `commit W` (41.94 -> 50.56 s): run
2 started with 2 GB free and 11 GB of page cache left by run 1's 1.23
GB proof write and the 7 GB export re-read, so its host-side plane
conversion and pageable upload paid more. The phases THIS LANE moved
reproduced to three digits (zcF 4.645 / 4.649, zcD 0.792 / 0.789,
helpers + H 5.361 / 5.408). **Quote 95.5-104.4 s; 95.5 is the
quiet-box figure and 175.09 s the number it replaces.**

THE THREE RECORD ARTIFACTS:
(1) **NEW results/hashline_gpu_shapegen.md** — in the form of XX's
results/hashline_gpu_12x512.md: what was templated and why it declined
the real model (the block-count table: 125M (1, 3) = 13/15 tables vs
Mistral (7, 1) = 73/7), the fix and why the bytes cannot move, the 8B
row with both cold runs against AC's and the CPU's, the per-phase
table, the residual-host table with each item's lever, the one-layer
isolation, the 125M A/B, the ZK table zero-check, the four gates, and
the tokens/s verdict against YY's band.
(2) **docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md §3** — a new row
under AC's 8B GPU row ("...WITH SHAPE-GENERAL KERNELS": 95.5 / 104.4 s,
verify 1.16 s, 1,234.9 MB byte-identical dc980e81.., 3.80 GB + 5,651 MB
VRAM, 3.02e10 MAC/s, 5.35x the CPU row and 1.83x AC's) plus the "Lane
AH BUILT THAT KERNEL, and it beat its own model" paragraph after AC's.
(3) **docs/zkmatrix-poc/U_PERF3_ROUTE_B_THROUGHPUT.md §6.2 / §6.5** —
the re-measured GPU cell beside AC's, and a measured 8B row in the
MAC/s table. (That file is not in this lane's OWNS block; the addition
is one tagged block appended after AC's cells and one added table row,
so a merge is mechanical. Flagged for the orchestrator.)

**THE TOKENS/S VERDICT (the question rung 5 asked).** At 8B prefill
T = 512, mode P0, FFN-only, prover clock, laptop GPU:

| cell | YY [MODEL] §6.2 | AC [MEASURED] | **AH [MEASURED]** | verdict |
|---|---|---:|---:|---|
| tokens/s | 5.2-16 | 2.92 | **5.36** (slow run 4.90) | **the band's low end reached** |
| proven MAC/s §6.5 | 2.9e10-8.8e10 | 1.65e10 | **3.02e10** (2.76e10) | **inside at the low end** |
| laptop CPU 8T | 1.0 | 1.00 | 1.00 | inside — exact |

WHERE THE FIX LANDS: it closes the entire share AC attributed to the
declined kernels (2.92 -> 5.36 tok/s = 1.83x, against the 1.5x AC's
[MODEL] expected) and moves the measured row from 1.8x below the band
to inside it. The distance to the band's UPPER end is now four host
items, none of them a shape problem and all with known byte-preserving
fixes: the witness planes -> Fp conversion + pageable upload (~13-20 s
per 8B pass), the encode NTT (15.8 s), the opening's chunked re-encode
(14.3 s), and the Merkle levels + serialization of a 1.23 GB proof
(~13 s). The caution AC attached to the desktop-board and H100 columns
can be narrowed: the "Route B is device-shaped" premise now HOLDS for
the checks and the helpers at a real model width, and fails only for
witness marshalling and proof handling.

**WHERE THIS LANE STOPPED.** Rungs 0-5 green, committed, gates green at
every rung. Not done, in the order the next agent should take them:
(a) the raw-plane upload with device-side i8/i32 -> Fp conversion and
pinned staging (~13-20 s of the 8B pass, XX's and AC's item (b));
(b) the opening's re-encode / Merkle / serialization (~27 s);
(c) zk.rs's OWN `dev_shape` gate (line ~2004) is still `nb_f == 1 &&
nb_d == 3` — the ZK prover therefore still declines the device path at
Mistral width even though the kernels it needs now exist. Generalizing
it is the same three-edit pattern this lane applied to layer.rs (the
gate, the helper specs, the two spec lists) and would give a GPU 8B ZK
row, which nobody has yet;
(d) the templated `k_sc_round_zc20 / zc17` kernels could now be
deleted in favour of the general ones (measured equal at their own
shape) — kept only because XX's and ZA's published rows were taken
with them.

### Lane AI — the GPU 8B ZK row: generalize zk.rs's own device gate (wt-uperf3-ai) — RUST/CUDA (round 13 addendum)
OWNS: hashline/src/zk.rs (its `dev_shape` gate ~line 2004,
`nb_f == 1 && nb_d == 3`, plus whatever the same three-edit pattern
lane AH applied to layer.rs requires — AH's tagged block in zk.rs is
the model), hashline/src/gpu/* (ADDITIVE only, if a kernel needs a
ZK-specific entry), NEW results/hashline_zk_8b_gpu_*, the ZK rows in
docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md §3 and the P1 cells in
U_PERF3_ROUTE_B_THROUGHPUT.md §6, "Agent AI status". READ-ONLY:
layer.rs (lane AG is building the full-layer prover there), pcs.rs,
pcs_compact.rs, sumcheck.rs, transcript.rs, wcache.rs, attention.rs,
norm.rs, export_v3.rs, tables_v3.rs, silu.rs, zkmatrix-rs/, scripts/.
WHY: under Victor's P1 ruling (private inputs, public weights) the
product number is the 8B proof, on a GPU, with privacy. Today: the 8B
GPU pass is 95.48 s WITHOUT privacy, and the ZK prover still declines
the device path at Mistral width because zk.rs carries its own
125M-shaped gate — so no such row exists, only a ~534 s CPU [MODEL].
Lane AD measured the P1 surcharge at +4.7% prover / +3.9% bytes on
one Mistral layer, so the row should land near 100 s.
RUNGS (prefix "U-PERF3 AI:"): 0 the plan + the four byte gates
re-run on both binaries; 1 the gate generalized, `--zk` on the device
at Mistral width, bytes identical to the CPU ZK proof at one Mistral
layer (AD's T=512 layer row: 15.73 s CPU, 40,186,228 B) — record the
wall and the digest; 2 the 12x512 zk-v3 GPU wall re-measured (4.16 s
is the number to beat) with the gate green at both shapes; 3 **THE
GPU 8B ZK PASS**: `pass 32 512 --zk --seed 1 --profile v3 --export
/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export --wcache DIR
--threads 8 --proof-out F` with `HL_GPU=1` — the proof byte-identical
to the CPU ZK proof of the same statement (run the CPU one too, or
state why it is out of reach and compare at a smaller layer count);
walls, RSS, VRAM, bytes, proven MAC/s; 4 the record + the §3 ZK rows
+ the P1 tokens/s cells against lane YY's band.

## Agent AI status (wt-uperf3-ai) — round 13

(lane appends below)

### AI rung 0 — the plan, and the four byte gates on BOTH binaries (2026-09-03, WSL-BOX, wt-uperf3-ai, branch uperf3-ai)

Read: START_HERE (whole), this lane's brief, **Agent AH in full** (the
model: the block-looping kernels, `dev_zerocheck_blocks`, `dev_reserve`,
the three tagged edits in layer.rs, the 8B GPU pass 175.09 -> 95.48 s at
`dc980e81..`), **Agent AD** (the ZK-v3 statement, the Mistral layer row
15.73 s / 40,186,228 B / 13.29 GB CPU, the +4.7% / +3.9% surcharge, and
its own "NOT DONE" list, whose item 2 is exactly this lane); the code:
zk.rs (the gate at 2004 and AH's tagged `dev_tab_zerocheck` block at
2380 as the pattern), gpu/{mod.rs,cuda.rs,kernels.cu} (`zerocheck_impl`,
the `nblk` arm, `k_sc_round_zcf_gen` / `k_sc_round_zcd_gen` and their
parameter layouts), layer.rs READ-ONLY (AH's three edits at 1410, 1423,
1593, 1671 — the exact pattern to mirror; lane AG is building the
full-layer prover in that file and this lane will not write it).

**WHERE THE GATE IS AND WHAT IT DECLINES.** `hashline/src/zk.rs:2004`

    // the XX zero-check kernels are fixed at 13 / 15 tables: the 125M block shape
    let dev_shape = nb_f == 1 && nb_d == 3;

feeds THREE device regions of `prove_layer_v3_zk`, all-or-nothing by
construction (once `use_dev_h` is true the host tables are never built,
so a later decline panics):
1. `use_dev_h` (line 2006) — the LogUp helper columns on the device
   (`dev_helpers`) + `commit_zk_device` for H; its `HelperSpec` list
   hard-codes f-block **[0]** for the three F-side helpers (`lay.g8[0]`,
   `lay.u16[0]`, `lay.h16[0]`) and only the d-side loops.
2. `dev_f` (line 2250) — zero-check F through the TEMPLATED
   `dev_zerocheck(0, ..)` = `k_sc_round_zc20`, 13 tables, prm <= 32; its
   `TabSpec` list also hard-codes block [0].
3. `dev_d` (line 2315) — zero-check D through `dev_zerocheck(1, ..)` =
   `k_sc_round_zc17`, 15 tables; its spec list already loops `nb_d`, but
   the templated kernel demands exactly 15 tables and 3 mu / 3 nu.
AH's table zero-check (`dev_tab`, line 2380) is NOT gated by
`dev_shape` — it already runs at any shape and is untouched here.

125M: (nb_f, nb_d) = (1, 3) -> 13 / 15 tables = the templated shape.
**Mistral-7B: d 4096 = 1 x 4096, f 14336 = 7 x 2048 -> (nb_f, nb_d) =
(7, 1)** -> zcF 3 + 10 x 7 = **73** tables, zcD 3 + 4 x 1 = **7**;
neither is 13 or 15, the gate is false, and all three phases run on the
host. AD measured the consequence at one Mistral layer: `HL_GPU=1`
gave 17.01 s against 15.73 s CPU — the GPU bought nothing.

**THE THREE EDITS (byte-preserving by construction; the kernels already
exist, this lane adds no new CUDA).**
- **E1, the gate**: `nb_f == 1 && nb_d == 3` -> AH's real bound, the
  kernels' shared parameter array (`gpu::SCG_MAX_PRM` = 384):
  `nb_f >= 1 && nb_d >= 1 && 17 + 14 * nb_f <= 384 && 7 + 6 * nb_d <= 384`
  (Mistral needs 115 and 13). Plus AH's safety rung: `dev_reserve` of the
  two zero-check table buffers `[(3 + 10 nb_f) * tfb * 2, (3 + 4 nb_d) *
  tdb * 2]` BEFORE the helpers leave the host, so a VRAM shortfall takes
  the whole layer to the host path instead of panicking. At Mistral the
  zcF buffer alone is 73 x 2^20 x 2 u64 = **1.22 GB** on top of AH's
  measured 5,651 MB peak, on an 8,188 MB part — this is a live hazard,
  not a formality.
- **E2, the helper specs**: `for b in 0..nb_f` for the three F-side
  `HelperSpec`s (3 nb_f + nb_d specs, was 3 + nb_d); `k_helper` is
  already length-general.
- **E3, the two spec lists + the call**: the F list loops the blocks in
  the CPU's block-major table order (g8 rg a16 u16 ru h16 rh hg hu hh),
  and both calls move from `dev_zerocheck(kind, ..)` to
  `dev_zerocheck_blocks(kind, nb, ..)` with the **block-indexed**
  parameter layout the generic kernels read: F = alpha, beta, g_act,
  g_rg, g_ru, g_rh, g_i16 (7 Fp2), p_g, p_u, p_h (3 u64), then mu
  (4 nb_f) and nu (3 nb_f) — note the templated layout put p_* LAST, the
  generic one puts them at index 14; D = alpha, g_i16, g_rd (3 Fp2),
  p_z (1 u64), then mu2, **nu_x, nu_z** (nb_d each). The ZK D-side
  polynomial has no x term (X is opened at p2 instead), so `nu_x` is
  passed as nb_d ZEROs — the kernel then computes exactly `zcd_poly`.
  Both attempts run on a CLONED transcript (AH's `dev_tab` pattern), so
  a decline falls through to the unchanged host body with nothing
  absorbed.
- **E4 (recorded now, not part of the pattern): `--wcache` is a no-op
  for the ZK prover.** zk.rs commits W with plain `pcs::commit`; only
  layer.rs's v3 FFN prover calls `wcache::commit_w`. The rung-3 command
  passes `--wcache DIR`, so without this the flag does nothing on the ZK
  path. The fix is one tagged line in zk.rs (the same `WKey::new("v3",
  l, d, f, ..)` key, the same `w_data`, the same `PcsParams` — so the
  same tree, the same root, the same bytes, and the ZK and non-zk passes
  share cache entries). The chunked device W commit is NOT a problem any
  more: `pcs::commit` already routes through `gpu::dev_commit` ->
  `dev_commit_from`, which is lane AC's chunked path (AD's
  `cuMemAlloc(5376 MB)` decline predates it).

**THE FOUR BYTE GATES ON BOTH BINARIES: ALL EIGHT GREEN, BASELINE
BEFORE ANY CODE** (2026-09-03, [WSL-BOX] [8T] [CPU|GPU]
[NOISY-SHARED by convention; in fact quiet — load < 1, 13 GB available,
GPU 30 MB used], [MEASURED], `flock /tmp/zk-heavy.lock`, one run each,
`M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl`,
v3 export `/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export`;
every proof written to a file and `sha256sum`'d there). Builds from a
cold worktree: CPU 35.4 s, GPU 40.3 s, both clean.

| gate (`pass 12 512 --threads 8 --proof-out F`, + flags) | CPU PROVE | GPU PROVE | sha256 | bytes |
|---|---:|---:|---|---:|
| v2 | 16.04 s | **2.52 s** | `50cf7bdfd6b5b182..` | 66,844,928 |
| v3 `--profile v3 --export <v3dir>` | 16.54 s | **2.83 s** | `5f368db6240e0614..` | 70,758,084 |
| zk-v2 `--zk --seed 1` | 17.30 s | **4.95 s** | `021485e4f80ec695..` | 87,228,528 |
| zk-v3 `--zk --seed 1 --profile v3 --export <v3dir>` | 19.75 s | **4.84 s** | `40eb54795e023c77..` | 87,697,008 |

All eight digests = the round-12/13 references. **The number rung 2 must
beat is AH's quiet 4.16 s p50 for GPU zk-v3; this tree's single cold
reading is 4.84 s, so rung 2 will be a 3-run p50 against a 3-run p50 on
the same tree, not against a quoted figure.**

### AI rung 1 — THE GATE GENERALIZED: one Mistral-7B layer in ZERO KNOWLEDGE on the GPU, 16.34 s -> 4.94 s, THE PROOF BYTE-IDENTICAL (2026-09-03, WSL-BOX, [MEASURED])

WHAT LANDED (zk.rs, owned; gpu/* ADDITIVE; layer.rs NOT touched):
- **E1 the gate** (zk.rs:2014): `nb_f == 1 && nb_d == 3` ->
  `nb_f >= 1 && nb_d >= 1 && 17 + 14 * nb_f <= 384 && 7 + 6 * nb_d <= 384`
  (`gpu::SCG_MAX_PRM`). Mistral needs 115 / 13 parameters.
- **E2 the helper specs**: `for b in 0..nb_f` for the three F-side
  `HelperSpec`s (3 nb_f + nb_d, was 3 + nb_d with block [0] hard-coded).
- **E3 the two zero-checks**: the F `TabSpec` list loops the blocks in the
  CPU's block-major order; both calls moved from the templated
  `dev_zerocheck` to AH's `dev_zerocheck_blocks(kind, nb, ..)` with the
  block-indexed parameter layout (F: the 7 Fp2 constants, then p_g/p_u/p_h
  at index 14 — the templated layout put them LAST — then mu 4/block and
  nu 3/block; D: alpha/g_i16/g_rd, p_z at index 6, then mu2, **nu_x = nb_d
  ZEROs** because the ZK D-side polynomial has no x term, then nu_z). Both
  attempts ride a CLONED transcript, so a decline falls through to the
  unchanged host body with nothing absorbed.
- **E4 `--wcache` now serves the ZK prover**: zk.rs committed W with plain
  `pcs::commit`, so lane AC's per-model weight cache was a no-op on this
  path. One tagged line, the same `WKey::new("v3", l, d, f, ..)` key as
  layer.rs's v3 FFN prover, so the ZK and non-zk passes share entries.
- **E5 (the one that actually decided the rung) `gpu::dev_reserve_hard`,
  a NEW ADDITIVE function in gpu/cuda.rs + one export line in gpu/mod.rs.**
  The reservation has to be folded into `use_dev_h` here (unlike layer.rs,
  the ZK prover builds its host tables in the `!use_dev_h` branch BEFORE
  the zero-checks, so the decision must be made before that branch). The
  first build did exactly that with AH's `dev_reserve` — **and it declined
  at Mistral width**: `[UPERF3-AI] gpu zero-check tables unaffordable
  (cuMemAlloc(1168 MB): CUDA_ERROR_OUT_OF_MEMORY)`. The reason is not the
  live objects (~1.9 GB at that moment) but **the buffer pool**: it retains
  up to 64 freed buffers and matches by EXACT length (the reuse that makes
  the chunked commit fast across 32 layers), so after the W and A
  commitments it was sitting on the gigabyte the zero-check F tables need
  ((3 + 10 x 7) x 2^20 x 2 u64 = **1,168 MB**). `dev_reserve_hard` tries
  `dev_reserve`, and on failure DRAINS the pool and tries once more —
  value-neutral, since a pooled buffer holds nothing live (every element a
  kernel reads is written first); the only cost is the first-touch price of
  the next allocation of that size. Live proof, from the run:
  `[UPERF3-AI] reserve failed (cuMemAlloc(1168 MB): ..OUT_OF_MEMORY);
  drained 5 pooled buffers and retrying` — and the layer then ran entirely
  on the device.

**THE MEASURED ROW — one real Mistral-7B FFN layer at T = 512, mode P1
(private inputs and activations, public weights), `pass 1 512 --zk --seed 1
--profile v3 --export /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export
--threads 8 --proof-out F`** [WSL-BOX] [8T] [GPU|CPU] [NOISY-SHARED],
`flock /tmp/zk-heavy.lock /usr/bin/time -v`, one run each, back to back:

| | CPU (this tree) | **GPU (`HL_GPU=1`)** | factor |
|---|---:|---:|---:|
| **PROVE** | **16.34 s** | **4.94 s** | **3.31x** |
| VERIFY | 0.06 s | 0.06 s | — |
| proof bytes | 40,186,228 | 40,186,228 | — |
| **PROOF sha256** | `b5da6c38c77cf702..` | **`b5da6c38c77cf702..`** | **`cmp` IDENTICAL** |
| peak RSS | 12.90 GB | **2.85 GB** | 4.5x less |
| VRAM peak | — | 8,585 MB | of an 8.6 GB part |
| proven MAC/s | 5.52e9 | **1.83e10** | 3.31x |
| witness load + chain | 3.47 s | 3.37 s | — |

The full sha256 is
`b5da6c38c77cf702f9873cffc4db3c1de0ae16cb0262cfae15c7ffe54f1c609d`;
40,186,228 B is **AD's byte count for this statement to the byte**
(AD's `layer 0 512 --zk` row; `pass 1 512` differs from `layer 0 512`
only in the transcript's domain string, so the digests are not comparable
across the two commands but the sizes are). The equivalent `layer 0 512
--zk --seed 1 --profile v3` run on the GPU: **prove 4.736 s, verify 0.058
s, 40,186,228 B, ACCEPT, GREEN** against AD's 15.73 s p50 CPU.

PHASES, one Mistral layer at T = 512 [MEASURED, s]:

| phase | CPU | **GPU** | factor |
|---|---:|---:|---:|
| commit W | 7.471 | 1.571 | 4.8x |
| commit A (zk) | 2.551 | 0.773 | 3.3x |
| mask commit | 0.007 | 0.007 | — |
| **helpers + commit H (zk)** | 3.001 | **1.211** | **2.5x** |
| matmul g/u + d | 0.346 | 0.624 | 0.55x |
| **zero-check F (zk)** | 1.650 | **0.154** | **10.7x** |
| **zero-check D (zk)** | 0.234 | **0.029** | **8.1x** |
| table zero-check (zk) | 0.139 | 0.075 | 1.9x |
| pcs openings (zk) | 0.934 | 0.492 | 1.9x |
| **PROVE** | **16.34** | **4.94** | **3.31x** |

Device-side: h2d 0.598 s (1,908 MB), ntt 1.281 s, hash 0.215, sumcheck
0.180, fold 0.440, helpers 0.053, d2h 46 MB.

**THE BEFORE PICTURE, worth recording because it is the cost of the gate.**
With the gate still 125M-shaped (or with the reservation declining), the
same layer under `HL_GPU=1` ran the helpers and both zero-checks on the
host and took **47.5 s** — zero-check F alone 31.2 s — i.e. the GPU made
the ZK layer 1.6-3x SLOWER than CPU-only, which is AD's "17.01 s, no
faster than CPU-only" finding reproduced and amplified at this tree's
witness. (That host-fallback path under `HL_GPU=1` is itself anomalously
slow — 31.2 s against the CPU-only binary's 1.65 s for the same host
sumcheck, at 152% CPU against 455% — a real and unexplained effect worth a
later look; it is now unreachable at this shape and is NOT on the measured
path of any row above.)

GATES: re-run in rung 2 below (the `dev_reserve_hard` edit landed between).

### AI rung 2 — the 12x512 zk-v3 GPU wall, the gate green at BOTH shapes, the four gates, and the eight legs at Mistral width (2026-09-03, WSL-BOX, [MEASURED])

**THE 125M SHAPE IS NOT DISTURBED.** `pass 12 512 --zk --seed 1 --profile
v3 --export <v3dir> --threads 8` on the GPU, 3 runs: **4.06 / 4.03 /
4.16 s -> p50 4.06 s**, every run `40eb54795e023c77..` (87,697,008 B).
AH's quiet p50 for the same row was 4.16 s and this tree's rung-0 cold
single reading was 4.84 s, so the shape-general path costs **nothing** at
(nb_f, nb_d) = (1, 3) — AH's A/B finding for the non-zk prover reproduced
inside the ZK prover. The gate is now green at BOTH shapes in the SAME
binary: 125M (1, 3) and Mistral (7, 1), each byte-identical to its CPU
proof.

**THE FOUR BYTE GATES, BOTH BINARIES, AFTER `dev_reserve_hard`: ALL EIGHT
GREEN** [MEASURED, one run each, `flock /tmp/zk-heavy.lock`, sha256 taken
from the written file]:

| gate | CPU | GPU |
|---|---|---|
| v2 | `50cf7bdfd6b5b182..` 14.96 s | `50cf7bdfd6b5b182..` 2.40 s |
| v3 | `5f368db6240e0614..` 15.74 s | `5f368db6240e0614..` 2.50 s |
| zk-v2 | `021485e4f80ec695..` 17.38 s | `021485e4f80ec695..` 3.98 s |
| zk-v3 | `40eb54795e023c77..` 18.64 s | `40eb54795e023c77..` 4.06 s |

`cargo test --release` **40/40**.

**THE EIGHT TAMPER LEGS AT MISTRAL WIDTH, THROUGH THE GPU ZK PROVER**
(`HL_GPU=1 layer 0 512 --zk --seed 1 --profile v3 --export <mistral v3
export> --threads 8 --all-tampers`): honest run ACCEPT (prove 4.794 s),
then **8 of 8 REJECT** — flipped X, flipped Wg, out-of-range remainder,
wrong int16 table entry, wrong requant (h16), wrong z, wrong rounding
(floor), out-of-range int16 — **`layer 0 (v3) [ZK]: GREEN`**. This is the
first time the eight legs have been run at a real 8B width with the
zero-checks and the LogUp helpers on the device.

### AI rung 3 — **THE 8B PROOF, ON A GPU, WITH PRIVACY: 32 x 512 Mistral-7B in mode P1, PROVE 265.34 s, `930ce9a0..` (1,285,578,368 B), ACCEPT** (2026-09-04, WSL-BOX, [MEASURED])

Resumed after the 2026-09-03 hard reboot. The trunk (round 14: lane AG, this
lane's rungs 0-2, the 60 tok/s plan) merged in clean, both binaries rebuilt,
and **the four byte gates re-run on both binaries BEFORE any measurement:
all eight green** (results/hashline_zk_8b_gates.log). The crash-recovery
commit `1c225d4`'s claims were treated as hypotheses and re-established by
running; every log lives in results/, not /tmp.

**THE ROW** [WSL-BOX] [8T] [GPU] [NOISY-SHARED — another lane compiled
throughout] [MEASURED], detached under `flock /tmp/zk-heavy.lock` with a
`.done` marker, one run, `/usr/bin/time -v`; full log
results/hashline_zk_8b_pass_gpu.log, record results/hashline_zk_8b_gpu.md:

    HL_GPU=1 hashline pass 32 512 --zk --seed 1 --profile v3 \
      --export /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export \
      --wcache <fresh dir> --threads 8 --proof-out F

| | AH's 8B GPU pass (no privacy) | **THIS ROW (mode P1)** | ratio |
|---|---:|---:|---:|
| **PROVE** | 95.48 s | **265.34 s** | **2.78x** |
| VERIFY | 1.16 s | **2.33 s** | 2.01x |
| proof bytes | 1,234,936,956 | **1,285,578,368** | **+4.10%** |
| **sha256** | `dc980e81..` | **`930ce9a043a03721..c982e`** | — |
| peak RSS | 3.80 GB | **4.30 GB** | +13% |
| VRAM peak | 5,651 MB | **8,585 MB** of 8,188 MiB | +52% |
| proven MAC/s | 3.02e10 | **1.088e10** | 0.36x |
| witness load+chain / wall | 126.97 / 225.35 s | **131.79 / 402.29 s** | — |
| tokens/s (512 / prove) | 5.36 | **1.93** | — |

Digest by hand over the file as well as by the binary:
`930ce9a043a037210f62ac1384384e3a88607f29046b56284c6308ed272c982e`,
1,285,578,368 B, `PASS-V3 ACCEPT [ZK]`, wcache 32 misses / 129 MB (cold).

**THE FINDING THAT MATTERS FOR EVERY PROJECTION IN THE PLAN: the P1
surcharge at 8B ON A DEVICE is +178% on the prover, not AD's +4.7%.** AD's
+4.7% / +3.9% was measured on the CPU, where the base is 15 s of host
arithmetic and the ZK work hides inside it. **The bytes carried over exactly
(+4.10%); the time did not** — on a device the base is 3 s of kernels and the
ZK work (masked commitments with salted leaves, the committed multiplicity
tables, the extra H rows) is most of the layer. The round-13 addendum's
"expected near 100 s" came from 95.48 x 1.047; that multiplication is not
valid across channels, and this lane's job was to replace it with a
measurement. 265.34 s is the measurement.

PHASES, summed over 32 layers [MEASURED, s]: commit W 54.18 (AH 41.94),
commit A 24.57 (15.85), mask commit 0.23, **helpers + commit H 146.26
(5.36)**, matmul g/u+d 10.64 (8.13), zero-check F 8.62 (4.65), zero-check D
1.34 (0.79), table zero-check 1.58 (0.32), zsum+mask 0.12, pcs openings 17.80
(18.48). Device-side: h2d 16.86 s (61,018 MB), **ntt 119.10 s** (AH 15.85),
hash 8.07, sumcheck 9.80, fold 5.87, helpers 19.63, d2h 1,466 MB.
**55% of the prove is helpers + commit H.**

**THE DRAIN: NECESSARY, AND RE-ESTABLISHED BY RUNNING** (the dead agent's
testimony was a comment; this is evidence). `HL_ZK_DRAIN=0` was added so the
A/B runs in ONE binary; 4 real Mistral layers, same statement, drain the only
difference (results/hashline_zk_8b_drain_ab.log):

| | drain ON (shipped) | drain OFF |
|---|---|---|
| result | 4/4 layers **ACCEPT**, prove 31.15 s | layer 0 fine (4.78 s), **layer 1 PANICS** |
| failure | — | `gpu zk commit H (v3): cuMemAlloc(1514 MB): CUDA_ERROR_OUT_OF_MEMORY` |
| proof | `9f2f35a3..` / 160,708,048 B | none |

So **without the drain the 32-layer 8B ZK pass cannot run at all** — the
1,514 MB failure the crash-recovery commit described, reproduced to the
megabyte. Mechanism, from the HL_GPU_VERBOSE trace: the pool matches by EXACT
length and the ZK row counts differ per layer (layer 0's proof is 40,186,228
B, every later layer's 40,173,940 B — different remainder windows, different
table rows), so the previous layer's pooled buffers are dead weight; without
the drain the card reads `free 0 MiB` with 9 pooled buffers before layer 1 has
finished committing W. Cost of the drain, measured where it frees nothing at
the top: layer 0 4.78 -> 5.65 s (the first-touch price after the "after H"
drain).

**WHAT THE DRAIN CANNOT BUY, AND THE NEGATIVE RESULT THAT PROVES IT.** Layer 0
proves in 4.36 s; layers 1..31 average 8.42 s. The trace's only difference: at
layer 0 the zero-check table reservation FAILS, `dev_reserve_hard` drains and
retries, and the layer runs with 1,614 MiB of real VRAM; at later layers the
same reservation SUCCEEDS with 494 MiB free — **on WSL `cuMemAlloc` is served
from HOST memory instead of failing** — so 1,392 MB of tables are paged and the
helpers/H/zero-check phase runs against host memory. A third drain placed
before that reservation (to force real VRAM) was written and A/B'd
(results/hashline_zk_8b_drain_pre_ab.log): **it kills layer 0** with
`gpu zk commit H (v3): cuMemAlloc(1516 MB) OUT_OF_MEMORY`. On an 8,188 MiB
part the resident A commitment + 1,392 MB of tables + a 1.5 GB H commit do not
fit, and the paging is what makes the layer possible at all. Reverted, with
the reasoning and the failure left as a comment at the site.
**So the 2x per-layer penalty is a card-size fact, not a code fact: 32 x 4.36
= 140 s is what this row would be if every layer ran like layer 0, which a
16 GB+ board should give with no code change [PREDICTION, not measured].**
That is now the cheapest question lane E's hardware ruling can answer.

**BYTE IDENTITY, CPU vs GPU, ON A CHAINED MULTI-LAYER PROOF**
(results/hashline_zk_8b_cpu_gpu_cmp.log): `pass 4 512 --zk --seed 1 --profile
v3` on the Mistral export — GPU `9f2f35a383295118..` / 160,708,048 B / PROVE
30.76 s / RSS 3.09 GB; CPU **the same digest and byte count** (`cmp`
identical) / PROVE 74.48 s / RSS 13.01 GB. **The GPU is 2.42x the CPU on the
ZK path at 8B width.** Rung 1 proved this for one layer; this chains four. The
32-layer CPU run was NOT taken: ~596 s [COUNTED from this row] at 13 GB RSS
would risk a 15 GB box shared with two live lanes, for a digest the 4-layer
gate already pins.

**E4 — `--wcache` ON THE ZK PATH** (results/hashline_zk_8b_wcache_e4.log,
2 Mistral layers per run). The one-line change landed in rung 1; this rung
proved it rather than assuming it. ZK + cold `--wcache`: **MISS x2, entries
written** (4.2 MB/layer, where before the flag wrote nothing). ZK with no
`--wcache`: **the same digest `5c766868..`, the same 80,360,168 B** — the
cache changes no bytes. The **non-ZK v3 prover** against the dir the ZK prover
wrote: **hits 2 | misses 0** — the two passes share entries, which is exactly
what the shared `WKey::new("v3", l, d, f, ..)` key was for; commit W 2.51-2.67
s cold -> 1.61 s warm over two layers. **BUT the WARM path CRASHES the GPU ZK
prover at Mistral width**: `gpu helpers (zk v3): cuMemAlloc(379 MB)
OUT_OF_MEMORY` right after the layer-0 HIT. Cause, from wcache.rs (lane AC's
file, READ-ONLY here): on a HIT `reencode_store` calls `gpu::dev_encode_only`
and keeps the re-encoded W **device-resident for the layer**, where the MISS
path's `pcs::commit` uses the CHUNKED device commit and leaves nothing
resident; at 10,752 rows that store plus the resident A commitment does not
leave the helpers their 379 MB. `--wcache` is safe on the GPU ZK path only
while it MISSES — a fresh dir, which is what this row and AH's used. Owed to
whoever owns wcache.rs; the cached form's byte-identity is not in question,
its VRAM budget is.

**FLOORS ON THE FINAL TREE** [MEASURED]: the four byte gates on BOTH binaries
**all eight green** (v2 `50cf7bdf..` 66,844,928 B; v3 `5f368db6..` 70,758,084
B; zk-v2 `021485e4..` 87,228,528 B; zk-v3 `40eb5479..` 87,697,008 B —
results/hashline_zk_8b_gates_final.log), `cargo test --release` **40/40**, and
**the eight v3 tamper legs at MISTRAL width through the GPU ZK prover: honest
ACCEPT (4.182 s), then 8/8 REJECT, `layer 0 (v3) [ZK]: GREEN`**
(results/hashline_zk_8b_legs.log).

**WHERE THIS LANE STANDS.** Rung 3 done: the product number exists, with its
digest, and every claim in the crash-recovery commit is now either measured or
disproved. NOT done, for the next agent:
(a) **the §3 row and the P1 tokens/s cells** — docs/zkmatrix-poc/
PROVING_CHANNEL_OPTIONS.md §3 wants a row under AH's 8B GPU row (265.34 s,
2.33 s verify, 1,285,578,368 B `930ce9a0..`, 4.30 GB + 8,585 MB VRAM,
1.088e10 MAC/s, 1.93 tok/s, mode P1) and U_PERF3_ROUTE_B_THROUGHPUT.md §6.2/
§6.5 the matching P1 cells. Those files are NOT in this lane's round-14 OWNS
block, so they are flagged for the orchestrator rather than edited;
(b) **helpers + commit H is 55% of the prove** (146.26 s) and the device NTT
is 119.10 s against AH's 15.85 — the next real lever on this row, and the part
most likely to be paging rather than arithmetic;
(c) **the warm `--wcache` GPU crash** above;
(d) the 32-layer CPU ZK pass, if a quiet box with 16 GB+ ever exists, to turn
the ~596 s [COUNTED] into a measured CPU/GPU factor at full depth;
(e) the chained-transcript simulator argument (plan item A6) is still owed
before any of this is published as a ZK claim.

## ROUND 14 — THE 60 TOKENS/S PLAN, TRACKS B AND C (opened 2026-09-04)

Ground: lane AG merged (the first full-layer proof) and lane AI merged
at rung 2 (the ZK prover's device gate generalized); the merged-tree
floors are running (results/floors_round13_merge.log + .done).

The round is scheduled from `docs/zkmatrix-poc/U_PERF3_SIXTY_TOKENS_PLAN.md`,
which replaced the lane-by-lane menu with one factor budget. Its
finding: completing the statement costs 3.55x (attention 2.87x
[COUNTED], ZK P1 1.047x [MEASURED], the range facts 1.18x [MODEL]), so
60 tok/s at 30B is outside even the counted floor (13-39 tok/s honest)
while at 8B it is inside it (40-113 honest). The PoC is therefore
retargeted at 8B, and this round takes the two levers that are
measurable on this box today.

THREE LANES, disjoint files, the usual discipline: commit rung 0 within
15 minutes and after EVERY rung (the 2026-09-03 cutout and the
2026-09-03 hard reboot each proved this is what saves a lane); the four
byte gates stay green; append ONLY to your own status section.

NOTE ON THE REBOOT: the box stopped hard at 19:14 on 2026-09-03 and
/tmp was wiped. The attention EXPORT DIRECTORIES that lane AG's
full-layer gates consume lived there and are GONE; regenerating them is
lane AK's rung 0, and until it lands AG's digests (the 12-layer pass
c91f8713.., the full Mistral layer) are unverified on the merged tree.

### Lane AJ — the host wall (wt-uperf3-aj) — RUST/CUDA
OWNS: hashline/src/gpu/{cuda.rs,kernels.cu,mod.rs} EXCEPT the two
functions tagged [UPERF3-AI] (`dev_mem_info`, `dev_pool_drain`, which
belong to lane AI's rung 3 and must not be edited), hashline/src/pcs.rs,
NEW results/hashline_hostwall_*, "Agent AJ status". READ-ONLY:
zk.rs, layer.rs, attention.rs, norm.rs, tables_*.rs, pcs_compact.rs,
sumcheck.rs, transcript.rs, wcache.rs, export_v3.rs, zkmatrix-rs/,
scripts/.
TARGET: the four host items that are 56-63 s of the measured 95.5 s 8B
GPU pass — the plane->Fp conversion and its pageable upload (~13-20 s),
the encode NTT (15.8 s), the opening's chunked re-encode (14.3 s), and
the Merkle levels + serialization of a 1.23 GB proof (~13 s). All four
are byte-preserving by construction. This is the plan's lever L2,
2.4-2.9x, and the most certain factor in the whole budget.

### Lane AK — the attention exports, AG's gates, then the claim fold (wt-uperf3-ak) — RUST
OWNS: hashline/src/attention.rs, norm.rs, tables_attn.rs, the
[UPERF3-AG]-tagged full-layer functions in layer.rs, the `--attn` flag
lines in src/bin/hashline.rs, NEW results/hashline_attn_*, "Agent AK
status". READ-ONLY: gpu/* (lane AJ's), zk.rs (lane AI's), pcs.rs, the
v2/v3 FFN functions in layer.rs, zkmatrix-rs/, scripts/ (import, never
edit).
TARGET: rung 0 regenerates the attention exports the reboot destroyed
and re-establishes AG's digests ON THE MERGED TREE (this is the only
thing that makes AG's measured results verifiable again); then lever L5
— fold the claims. The attention half opens A/W/H at ~20 points where
the v3 FFN prover folds every pending claim into its two zero-checks and
opens at two; ~8 MB of the 27.3 MB per 125M layer is group vectors that
folding removes. No soundness change and no new machinery: the same
nu-weighted eq terms the zero-checks already carry.

### Lane AI (continuing, wt-uperf3-ai) — rung 3 — RUST/CUDA
OWNS: hashline/src/zk.rs, the two [UPERF3-AI] functions in
hashline/src/gpu/cuda.rs, NEW results/hashline_zk_8b_*, "Agent AI
status". READ-ONLY: everything else, and in particular the rest of
gpu/* (lane AJ's).
TARGET: the 32-layer 8B ZK pass on the GPU — the product number under
the P1 ruling, expected near 100 s. The rung-3 code is committed
(1c225d4) and compiles but was NEVER MEASURED; its scratch logs died
with the reboot, so its claims survive only as code comments and must be
re-established by running. Also owed: `--wcache` is a silent no-op on
the ZK path (zk.rs commits W with plain `pcs::commit`), one tagged line.

## Agent AJ status (wt-uperf3-aj) — round 14

(lane appends below)

### AJ rung 0 (first half) — THE PLAN: the four host items attributed to functions and lines (2026-09-04, WSL-BOX, wt-uperf3-aj, branch uperf3-aj)

Read: START_HERE (whole), U_PERF3_SIXTY_TOKENS_PLAN (Track B, items
B1-B4), the round-14 block + this brief, Agent AH IN FULL (its host-item
table is where the four numbers come from), Agent AC (the 8B GPU pass
anatomy); the code: gpu/{mod.rs,cuda.rs,kernels.cu}, pcs.rs, and the
call sites in layer.rs and src/bin/hashline.rs (both READ-ONLY here).

**WHERE THE 95.5 s ACTUALLY GOES [COUNTED from AH's rung-4 counters].**
The device counters of the 8B pass sum to h2d 13.05 + ntt 15.85 +
sumcheck 5.44 + fold 2.89 + helpers 1.38 + opening re-encode 14.28 =
**52.89 s**; the prove is 95.48 s, so **42.6 s is host time inside the
prove clock** and the h2d is 13.05 s of host-blocking copy on top of it
= the plan's "56-63 s". Note two accounting facts that the plan's item
list does not make explicit and that decide what this lane can move:
- `ntt` and `opening re-encode` are ALREADY device work (the chunked
  path's `secs_ntt` even absorbs the chunked hash when
  `HL_GPU_VERBOSE` is off — cuda.rs:596). B2 and B3 are therefore
  **kernel-quality and algorithm** items, not "move it to the device"
  items. This lane will not pretend otherwise.
- The 1.23 GB proof's **serialization is OUTSIDE the prove clock**
  (bin/hashline.rs:855-862: `to_bytes` + sha256 + `fs::write` run
  after the per-layer `t_prove` accumulation). B4's "~13 s" is a WALL
  item, not a prove item; the only part of B4 inside the prove is the
  Merkle level build (`MerkleTree::build`, pcs.rs:174/178) and the 256
  `tree.path(j)` per opening (pcs.rs:361).

**THE FOUR ITEMS, ATTRIBUTED.**

| item | where the time is | file:line | mine? |
|---|---|---|---|
| **B1a** plane -> Fp conversion | `w_data` / `a_data` / `h_data` built element-wise by `Fp::from_i64` over the int8 planes | layer.rs:1341-1357, 1371-1391, 1456-1486 | **NO — layer.rs is READ-ONLY for this lane** |
| **B1b** the pageable upload | `htod_sync_copy_into` of the whole (rows x n x 8 B) buffer, synchronous, on the default stream, from PAGEABLE host memory | cuda.rs:435 (`dev_commit`), 459 (`dev_encode_only`), 1446 (`dev_commit_zk`), 1462 (`dev_upload_rows`) | **YES** |
| **B2** the encode NTT (+ the chunked hash folded into the same counter) | `encode_rows_view` -> `k_dif_pa`/`k_dif_pb`/`k_dit_p1_pad`/`k_ntt_p2`, then `k_hash_cols_stream` | cuda.rs:525-560, 562-608; kernels.cu:852, 894, 930, 150, 1003 | **YES** |
| **B3** the opening's chunked re-encode | `columns_chunked` re-encodes EVERY row of the commitment a second time (inverse NTT of size n, forward NTT of size nn) only to gather Q = 256 of the nn = 262,144 columns | cuda.rs:610-645, entered from `dev_columns` cuda.rs:809 | **YES** |
| **B4a** Merkle levels (in the prove) | `MerkleTree::build` over nn leaves per commitment; `tree.path(j)` x 256 per opening | pcs.rs:174, 178, 361 | **YES (pcs.rs)**; merkle.rs itself is not in the OWNS block |
| **B4b** serializing 1.23 GB | `LayerProofV3::to_bytes` -> `Opening::write_bytes`, byte-at-a-time `extend_from_slice` into one Vec, single-threaded, then sha256 and `fs::write` | pcs.rs:101-120 (mine), layer.rs:1224+ and bin/hashline.rs:855-862 (not mine) | **PARTLY** |

**WHAT THIS LANE CAN AND CANNOT DO, STATED UP FRONT.** The single
largest host item — the `Fp::from_i64` conversion of the int8 planes
and the 1.4 GB `w_data` allocation per Mistral layer — lives in
`prove_layer_v3` in layer.rs, which this lane's OWNS block makes
READ-ONLY (round 14 gives layer.rs's v3 FFN functions to nobody: lane
AK holds only the [UPERF3-AG] full-layer functions there). The same is
true of the host matmul folds (`fold_cols_base` over `w_data`,
layer.rs:1532/1573 = the 8.13 s of "matmul g/u" + "matmul d"). Both are
recorded here as B1a/B7-class items for the orchestrator to assign; they
are NOT attempted in this lane. What is left inside gpu/* and pcs.rs is
B1b, B2, B3, B4a/B4b — and that is what the rungs below do.

**THE RUNGS, cheapest and most certain first.**
- **R1 (B1b): pinned staging + a pipelined upload.** Today every
  commitment blocks the host for the whole copy (4.59 GB/s measured:
  59,861 MB in 13.05 s) and only then starts the encode. The chunked
  path already walks the data in row chunks, so chunk k+1's copy can
  ride a second stream while chunk k encodes; with a pinned staging
  buffer the copy is a real DMA and can overlap. Byte-preserving by
  construction: the same bytes reach the same device addresses.
  Expected: 13.05 s -> 3-6 s of visible time [MODEL].
- **R2 (B4a/B4b + pcs.rs's host tail): the opening's host work.**
  `Opening::write_bytes` is a single-threaded byte-at-a-time encode of
  ~38 MB per layer; `pcs::open`'s `group_claims` allocates a
  `rows`-long Fp2 row-weight vector per claim (21 + 31 + 34 claims per
  Mistral layer) and `eq_table_msb` per claim. Both are host-only,
  additive, and cannot move a byte.
- **R3 (B3): the re-encode.** Two candidate forms, in order of
  certainty: (a) reuse — the commit already computes exactly this
  encoding once; nothing but VRAM stops the CHUNK's coefficient buffer
  being reused, so measure what a larger `HL_GPU_CHUNK_ROWS` and a
  fused encode+gather buy first; (b) output pruning — only 256 of the
  262,144 outputs are wanted, and a pruned forward transform costs
  ~1.31M butterflies per row against 2.36M [COUNTED], i.e. ~1.8x on
  the forward half.
- **R4 (B2): the encode NTT itself.** Bandwidth arithmetic first (the
  encoded matrix is ~5.6 GB per Mistral W commitment and every stage
  group is a full pass over it), then the cheapest of: fusing the DIF
  tail into the DIT head, raising `NTT_LOG_BLK`, or a radix-4 stage.

**THE FLOOR:** the four byte gates on BOTH binaries at every rung
(v2 `50cf7bdfd6b5b182..` 66,844,928 B; v3 `5f368db6240e0614..`
70,758,084 B; zk-v2 `021485e4f80ec695..` 87,228,528 B; zk-v3
`40eb54795e023c77..` 87,697,008 B), plus `cargo test --release`. The
8B row moves only when the 125M gates are green.

**RUNG 0 (second half) — THE BASELINE AND THE ANATOMY (2026-09-03/04,
WSL-BOX 8T + RTX 4070 Laptop, `flock /tmp/zk-heavy.lock`, [MEASURED],
NOISY-SHARED by convention: lanes AI and AK were on the CPU, the GPU was
exclusive under the lock).** Builds: CPU + GPU clean.

THE BASELINE THIS LANE MUST MOVE — one real Mistral-7B layer at T = 512
on the GPU, `HL_GPU=1 pass 1 512 --profile v3 --export
/home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export --threads 8
--proof-out F`: **PROVE 3.134 s**, verify 0.04 s, proof 38,688,700 B,
sha256 **179ec2fb8f99d0d6..** (AH's, AC's and the CPU prover's digest),
RSS 2.47 GB, VRAM peak 5,651 MB, wall 6.61 s. (AH measured 3.090 s for
the same command; the 1.4% is the box.)

| phase | s | what is inside it |
|---|---:|---|
| commit W | 1.402 | h2d(W) ~0.379 + chunked encode+hash 0.331 + **~0.69 HOST** |
| commit A | 0.461 | h2d(A) ~0.124 + chunked 0.105 + **~0.23 HOST** |
| helpers + commit H | 0.267 | device helpers 0.103 + chunked 0.087 |
| matmul g/u + d | 0.255 | **HOST folds over `w_data`** (layer.rs) |
| zero-check F + D | 0.169 | device (lane AH) |
| pcs openings | 0.573 | chunked re-encode 0.442 + device fold 0.084 |

Device counters: h2d 0.504 s (1,871 MB = W 1,409 + A 461; H is built on
the device), ntt 0.450, hash 0.073, sumcheck 0.169, fold 0.091, helpers
0.103, opening re-encode 0.442 = **1.832 s**. So **1.302 s (41.6%) of
the prove is host time**, and — measured phase by phase — **1.17 s of
that 1.30 is in layer.rs**: the `Fp::from_i64` conversion and the 1.4 GB
`w_data` allocation (~0.69 s), the same for `a_data` (~0.23), and the
host matmul folds (0.255). **layer.rs is READ-ONLY for this lane, so the
ceiling on what this lane can move is h2d + ntt + re-encode = 1.47 s of
the 3.13 (47%)** — recorded here because it caps the lane's factor at
~1.9x even if every device item went to zero, against the plan's 2.4-2.9x
for L2. THE ITEM THE ORCHESTRATOR MUST REASSIGN IF L2 IS TO LAND IN FULL:
one call site in `prove_layer_v3` (layer.rs:1341-1391) building `w_data`
/ `a_data` from the int8 planes, which rung 3 below makes unnecessary on
the device side but cannot delete.

**RUNG 1 — PINNED, DOUBLE-BUFFERED, INTERLEAVED UPLOADS (2026-09-04,
[MEASURED]).** What landed in gpu/cuda.rs: `PinBuf` (cuMemHostAlloc,
write-combined), `Uploader` (two staging buffers, a non-blocking copy
stream, one event per buffer), `Gpu::upload_sync` (a drop-in for
`htod_sync_copy_into` at the four block-upload sites) and
`commit_chunked_upload`, which sends chunk k+1's bytes on the copy
stream while chunk k encodes and hashes on the default stream. Switches:
`HL_GPU_PIN_MB=0`, `HL_GPU_STREAM_COMMIT=0`.

THE FINDING THAT SHAPED EVERYTHING AFTER IT — the h2d probe
(`HL_GPU_BENCH_H2D=1 gpu-probe`, 1.07 GB x3): **pageable 5.56 GB/s |
pinned host fill 29.13 | pinned staged serial 5.17 | pinned
double-buffered 5.44 GB/s**. **Page-locked staging does NOT raise the
host-to-device rate on this WSL box** (the paravirtualized WDDM path
already stages every copy); the DMA is capped near 5.5-6.3 GB/s whatever
the source. So the only levers on h2d are (a) overlapping it with
compute and (b) putting fewer bytes on the wire — which is rung 3.

**RUNG 2 — THE COLUMN GATHER FUSED INTO THE LAST NTT STAGE GROUP
(2026-09-04, [MEASURED]).** `k_ntt_p2_gather` in kernels.cu: identical
arithmetic to `k_ntt_p2` (same shared tile, same twiddles, same order),
but instead of writing the whole encoded row back it stores only the
`sel`-marked columns, so the opening's re-encode neither writes the
encoded chunk (537 MB per 1024-row chunk at the Mistral W shape) nor
re-reads it to gather — 1.07 GB of the 2.82 GB of per-chunk traffic
[COUNTED]. Duplicate column indices (which `challenge_indices` produces
about half the time at Q = 256 over nn = 65,536) get one device slot each
and are expanded on the host. Switch: `HL_GPU_FUSE_GATHER=0`.

**THE A/B, one Mistral layer, all five arms byte-identical
(`179ec2fb..`, 38,688,700 B):**

| arm | PROVE s | opening re-encode s | commit W (upload+encode+hash) s |
|---|---:|---:|---:|
| base (rungs 1-2 off) | 2.97 | 0.444 | ~0.72 |
| fused gather only | 3.00 | 0.442 | ~0.72 |
| interleaved upload only | **2.76** | 0.449 | 0.569 |
| both | 2.79 / 2.86 | 0.442 / 0.444 | 0.636 / 0.545 |

VERDICT, stated honestly: **the interleaved upload is worth ~0.2 s of the
3.0 (7%); the fused gather is PARITY** — 0.442 against 0.444 s. The
re-encode is therefore NOT bandwidth-bound at this shape, which is a
result in itself (it rules out the "fewer bytes" family of fixes for B3
and points at occupancy). The fused kernel is kept ON because it moves
1.07 GB less per chunk at no cost and needs less device memory for its
output; it is switchable and it is exercised by the probe's chunked
checks and by four forced-chunked byte gates.

**THE PARAMETER SWEEP THAT PAID MORE THAN EITHER RUNG** (same command,
same digest in every arm): the chunked commit's row chunk and the NTT
block size are free parameters nobody had swept at a real model width.
`HL_GPU_CHUNK_ROWS` 1024 -> 128 shrinks the encoded scratch from 537 MB
to 67 MB; `HL_GPU_NTT_THREADS` 256 -> 512 takes the 32 KB-shared NTT
kernels from 50% to 100% occupancy on sm_89 (3 blocks x 512 threads =
1,536 = the SM's limit).

| arm | PROVE s |
|---|---:|
| chunk 1024, 256 threads (the built defaults) | 2.79-2.86 |
| chunk 256, 256 threads | 2.87 |
| chunk 128, 256 threads | 2.81 |
| chunk 1024, 512 threads | 2.85 |
| chunk 1024, 1024 threads | 2.83 |
| **chunk 128, 512 threads** | **2.46** |

Neither parameter alone does anything; together they are **1.27x over the
rung-0 baseline** (3.134 -> 2.46 s) with the same proof bytes. The
streamed commit of W runs in 0.385 s against ~0.72 s, of which 0.303 s is
now the DMA itself — which is what rung 3 attacks.


**RUNG 3 — THE NARROW UPLOAD, AND THE TWO DEFAULTS (2026-09-04,
[MEASURED], ten arms, every one byte-identical `179ec2fb..`).**
`Fp::from_i64` maps x >= 0 to x and x < 0 to P + x, so an int8 plane's
field elements are exactly the two ends of the field and the upload does
not need 64 bits per element. `Uploader::send_packed` packs w bytes per
element straight into the page-locked staging buffer (w chosen by a
strided sample, then VERIFIED on every element while packing; a
violation leaves the destination untouched and falls back), and the new
`k_widen` restores the identical 64-bit image on the device. At the
Mistral shape the sample picks **1 byte for W (1,409 -> 176 MB) and 2
for A (461 -> 115 MB)**. Switch: `HL_GPU_NARROW=0`.

| arm (one Mistral layer, T = 512, GPU) | PROVE s | commit W h2d visible / total | B/elem |
|---|---:|---|---:|
| r0base — everything off, chunk 1024, 256 threads | 3.03 | — | 8 |
| chunk 128 + 512 threads, narrow OFF | 2.51 | 0.299 / 0.388 | 8 |
| **chunk 128 + 512 threads (the new defaults)** | **2.50** | 0.265 / 0.399 | 1 / 2 |
| the same, repeated | 2.66 | 0.300 / 0.585 | 1 |
| chunk 256 / chunk 512 (512 threads) | 2.73 / 2.60 | | 1 |
| chunk 128 + 256 / 1024 threads | 2.68 / 2.85 | | 1 |
| chunk 128 + 512, fused gather OFF | 2.67 | | 1 |
| chunk 128 + 512, 32 MB staging | 2.82 | | 1 |

TWO HONEST READINGS. (1) The two repeats of the SAME configuration (2.50
and 2.66; `commit W` 0.399 vs 0.585) put this box's noise floor at ~+/-6%
on the prove with lanes AI and AK on the CPU, so nothing below ~0.15 s is
real. (2) **The narrow upload is PARITY here** (2.50 vs 2.51): once the
chunk is small enough for the interleaving to hide the DMA behind the
encode, 8x fewer bytes on the bus only trades bus time for host packing
time. It is kept ON — switchable, byte-gated both ways, and the right
structure the moment the device is faster than the bus (the RTX 5090
case the coordinator flagged mid-round) — but it is NOT counted as a
speedup on this box.

WHAT DEFAULTS CHANGED (both byte-preserving, both in gpu/cuda.rs):
`HL_GPU_CHUNK_ROWS` **1024 -> 128** (the encoded scratch of one chunk at
the Mistral W shape drops 537 MB -> 67 MB; 128 rows is one blake3 chunk
of a column, the smallest legal step, and only CHUNKED commitments are
affected, so nothing at the 125M shape moves) and `HL_GPU_NTT_THREADS`
**256 -> 512** (the NTT kernels hold a 32 KB shared tile, so sm_89 fits 3
blocks per SM: 3 x 256 = 768 of the SM's 1,536 threads, against 3 x 512 =
1,536 exactly). **Neither is worth anything alone — 2.81 and 2.85 — and
together they are 3.03 -> 2.50 s.** The chunk size only pays once the
kernels have the occupancy to use the smaller working set, and the
occupancy only pays once the working set is near cache.

ALSO IN THIS RUNG, at the coordinator's request (the RTX 5090 becomes the
measurement machine): Blackwell arms in `arch_str` — (10, 0) =>
`compute_100`, (12, 0) => `compute_120` — and a LOUD stderr warning
whenever the NVRTC compile falls through to generic PTX, either because
the compute capability has no arm or because the toolkit rejects the
arch. Inert on this box (the 4070 Laptop is sm_89 and still takes
`compute_89`), and the byte gates are unchanged by it.


**RUNG 4 — THE FOUR BYTE GATES AND THE 8B PASS, BEFORE AND AFTER, IN ONE
SESSION ON ONE BOX (2026-09-04, WSL-BOX 8T + RTX 4070 Laptop,
`flock /tmp/zk-heavy.lock`, [MEASURED], the box quiet by the end).**

**THE FLOOR: ALL TWELVE BYTE GATES GREEN.** The four gates on the CPU
binary, the four on the GPU binary, and — new in this lane — the same
four re-run with `HL_GPU_CHUNK_BYTES` forced small so that the frozen
125M digests actually exercise the chunked commit, the interleaved
pinned upload, the narrow packing and the fused gather (nothing else at
the 125M shape does: those commitments are 151-272 MB and stay
resident). `50cf7bdfd6b5b182..` 66,844,928 B; `5f368db6240e0614..`
70,758,084 B; `021485e4f80ec695..` 87,228,528 B; `40eb54795e023c77..`
87,697,008 B — every one from both binaries and in both the resident and
the forced-chunked form. `cargo test --release` 40/40. No regression at
125M on the GPU either (v3 2.75/2.81 s, zk-v3 4.22/4.32 s against the
pre-lane 2.80 / 4.58).

**ONE MISTRAL LAYER, THREE REPEATS EACH, QUIET BOX** (proof `179ec2fb..`
every time): baseline 2.83 / 2.92 / 2.95 s; this lane 2.68 / 2.65 / 2.69;
this lane with `HL_GPU_NARROW=0` 2.70 / 2.69. So **~1.10x at one layer on
a quiet box**, against the 1.21-1.27x the same A/B showed while lanes AI
and AK were loading the CPU — the baseline suffers more from a busy box
than this lane's configuration does, which is itself a (small) result.

**THE 8B PASS — THE NUMBER THIS LANE IS ACCOUNTABLE FOR** (`pass 32 512
--profile v3 --export .../m8b_mistral_v3_export --wcache <fresh>
--threads 8 --proof-out F`, `/usr/bin/time -v`, cold cache, both arms
back to back in the same session):

| | BEFORE (this lane's switches all off, chunk 1024, 256 threads) | **AFTER (the lane's defaults)** | |
|---|---:|---:|---|
| **PROVE** | **88.90 s** | **86.00 s** | **1.034x** |
| witness load + chain | 126.29 | 123.86 | |
| VERIFY | 1.08 | 1.30 | |
| wall | 218.23 | **213.25** | |
| proof | 1,234,936,956 B | 1,234,936,956 B | — |
| **sha256** | `dc980e81..4536c` | **`dc980e810085b2ddf4688eb4a6cf4dd931c209bf7c5a9a7692d57ec14bc4536c`** | **IDENTICAL** |
| peak RSS | 3.87 GB | 3.99 GB | |
| **VRAM peak** | 5,651 MB | **5,249 MB** | **-402 MB** |
| **bytes uploaded** | **59,861 MB** | **9,328 MB** | **6.4x fewer** |
| device h2d | 12.810 s | **8.309 s** | 1.54x |
| device ntt (+ the streamed path's own accounting) | 13.958 | 14.714 | |
| device hash | 2.188 | 0.469 | |
| device opening re-encode | 14.238 | 14.020 | |
| phases: commit W / commit A / openings | 37.27 / 13.82 / 18.56 | 36.25 / 12.01 / 18.28 | |

**THE VERDICT, PLAINLY: 1.034x on the 8B prove, 6.4x fewer bytes on the
bus, 402 MB less video memory, the proof byte-identical.** That is far
below the plan's 2.4-2.9x for lever L2, and rung 0 predicted exactly why
before any of it was built: **the plan's L2 item list attributes to
"host marshalling" work that is either already on the device (the encode
NTT, the opening re-encode), outside the prove clock (the 1.23 GB
serialization, measured at 0.03 s per layer), or in layer.rs — and
layer.rs is READ-ONLY for this lane.**

WHERE THE 86.00 s NOW SITS [MEASURED counters / COUNTED split]: device
counters sum to 47.3 s (h2d 8.31 + ntt 14.71 + hash 0.47 + sumcheck 5.52
+ fold 2.89 + helpers 1.37 + re-encode 14.02), so **38.7 s (45%) is host
time inside the prove — and essentially all of it is in layer.rs**: the
`Fp::from_i64` conversion and the 1.4 GB `w_data` / 0.46 GB `a_data`
allocations (~29 s over 32 layers, counted from the one-layer phases)
plus the host matmul folds (8.1 s, measured directly as the "matmul g/u"
and "matmul d" phases). **After this lane, the host wall of the 8B GPU
pass is a layer.rs problem, not a gpu/ problem.** That is the single
sentence the orchestrator needs: the next 1.5x of L2 is one owner
change, not one more kernel.


**WHERE THIS LANE STOPPED (2026-09-04).** Rungs 0-5, every one committed,
the byte gates green at every rung. The whole lane, at a glance:

| rung | what landed | measured |
|---|---|---|
| 0 | the plan, the attribution, the baseline | one Mistral layer 3.134 s; 41.6% of the prove is host, 1.17 s of the 1.30 in layer.rs |
| 1 | `PinBuf` / `Uploader` / `upload_sync` / `commit_chunked_upload` — pinned, double-buffered, interleaved uploads | pinned staging does NOT raise the h2d rate on this box (5.56 pageable vs 5.44 GB/s pinned); the interleaving is worth ~0.2 s of 3.0 |
| 2 | `k_ntt_p2_gather` — the opening's column gather fused into the last NTT stage group | PARITY (0.442 vs 0.444 s): the re-encode is not bandwidth-bound |
| 3 | `k_widen` + `send_packed` — the int8/int16 planes cross the bus as bytes; and the two defaults (chunk 128 rows, 512 NTT threads) | 3.03 -> 2.50 s at one layer on a loaded box, 2.92 -> 2.66 on a quiet one; narrow is parity here and 6.4x fewer bytes |
| 4 | the twelve byte gates and the 8B pass, before and after, in one session | **PROVE 88.90 -> 86.00 s, proof byte-identical, VRAM -402 MB, bytes on the bus 6.4x fewer** |
| 5 | the gates and the tests re-run on the FINAL binary (results/hashline_hostwall_r5.log) | **ALL TWELVE BYTE GATES GREEN, `cargo test --release` 40/40** |

NOT DONE, and why — each with the number that says how much it is worth:
- **(a) THE ONE THAT MATTERS: the int8-plane -> Fp conversion and the
  host matmul folds in `prove_layer_v3` (layer.rs:1341-1391, 1532, 1573).
  ~29 s + 8.1 s of the remaining 86 s.** READ-ONLY for this lane and
  owned by nobody in round 14. The device half is already built and
  gated: `k_widen` reconstructs field elements from packed signed
  integers on the device, so the change is to hand `pcs::commit` the
  int8 planes instead of a converted 64-bit vector (and give the two
  folds a device form). **This is the whole remainder of lever L2 and it
  is an ownership decision, not a kernel problem.**
- (b) the proof serialization: measured at 0.03 s per layer and OUTSIDE
  the prove clock, against the plan's ~13 s. Not worth the change.
- (c) a deeper NTT redesign: the opening's re-encode is 0.44 s of a 2.50 s
  layer at 1.6e10 Goldilocks multiplies/s against a ~4.6e11 ALU ceiling
  and 66 against 256 GB/s — a latency and launch-structure problem.
  Output pruning (only 256 of 65,536 columns are wanted) counts at ~1.6x
  on the forward transform. A kernel project, not a rung.
- (d) `HL_GPU_NARROW` is ON by default at time PARITY on this box. It is
  kept because it is the right structure the moment the device is faster
  than the bus, which is the RTX 5090 case; `HL_GPU_NARROW=0` is the
  switch and both settings are byte-gated.


## Agent AK status (wt-uperf3-ak) — round 14

(lane appends below)
LANE: the attention exports the 2026-09-03 hard reboot destroyed, AG's
digests re-established ON THE MERGED TREE, then lever L5 — FOLD THE
CLAIMS. Worktree wt-uperf3-ak, branch uperf3-ak, based on 6854d2c (the
AG merge). Every wall [WSL-BOX] [8T] [CPU] [NOISY-SHARED] (lanes AI and
AJ build and run on the same box).

OWNS (recorded): hashline/src/{attention,norm,tables_attn}.rs, the
[UPERF3-AG]-tagged full-layer functions in layer.rs, the `--attn`/`attn-*`
lines in src/bin/hashline.rs, NEW results/hashline_attn_* and
results/ak_*, this section. READ-ONLY: gpu/* (lane AJ's), zk.rs (lane
AI's), pcs.rs, pcs_compact.rs, sumcheck.rs, transcript.rs, the v2/v3 FFN
functions in layer.rs, export_v3.rs, tables_v3.rs, zkmatrix-rs/,
scripts/.

NOTE ON THIS SECTION: the round-14 block and this section's header live
in the ORCHESTRATOR's working copy of PROGRESS_UPERF3.md and were never
committed, so this branch had neither. The header above is reproduced
verbatim from the orchestrator's copy so the merge is a text merge, not a
reconstruction.

### AK rung 0 — THE ATTENTION EXPORTS REGENERATED, AND AG'S 12-LAYER DIGEST REPRODUCES ON THE MERGED TREE (2026-09-03/04) [MEASURED WSL-BOX 8T CPU NOISY-SHARED]

**THE HEADLINE: AG's full-model digest is real again.** The 12-layer
125M full-model pass — every layer's attention + both norms + the
residual stream + the v3 FFN half on one transcript, both seams bound —
re-run on the MERGED tree (6854d2c: AG merged on top of AH's
shape-general kernels and AI's rung-2 ZK device gate) against exports
regenerated from scratch:

    PROOF sha256 c91f8713e2ed805543c1ca3a5f1c752734278606e7b13d199f1348dbf22f0ece
                 (404,327,452 B)  ==  AG's rung-5 digest, BYTE FOR BYTE

| run | PROVE | VERIFY | proof | peak RSS | verdict |
|---|---:|---:|---:|---:|---|
| AK, merged tree, regenerated exports | **100.47 s** | 2.66 s | 404,327,452 B | 6.62 GB | **ACCEPT** |
| AG, rung 5, pre-merge tree, /tmp exports | 94.54 s | 2.03 s | 404,327,452 B | 6.56 GB | ACCEPT |

The 6% wall difference is box noise (two other lanes building and running
on this box); every BYTE of the proof is identical, which is the gate
that matters. The AG merge did not disturb the full-layer statement.

Exact command (detached, heavy lock, `.done` marker per the no-hangup
protocol):

    M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl \
    hashline attn-pass /home/victor/wt-uperf3-ak/results/ak_attn_exports/m125_l 12 \
      --export /home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export \
      --t 512 --threads 8
    -> results/ak_r0_attnpass12.log / .done (exit 0)

**THE REGENERATED EXPORTS — where they live now, and why not /tmp.**
`/home/victor/wt-uperf3-ak/results/ak_attn_exports/m125_l{0..11}` (91 MB,
7 int32 planes + manifest.json + manifest.txt each), made with

    python3 scripts/attention_hash_ref.py --arch 125m --layer L \
      --export /home/victor/wt-uperf3-ak/results/ak_attn_exports/m125_lL

2.6 s (layer 0) to 5.9 s (layer 11) each — the 125M oracle needs NO token
cache (it reads `m125_attn_gate.TOKENS` = /home/victor/shard-00000.npy,
which survived). Total 45 s for all twelve; log results/ak_export_125m.log.
The layer-4 FFN Hadamard shift bump `[0, 0, 1, 0]` that AG recorded
reproduces exactly, and layer 0's cascade agreement xm8 = 0.310224 is
AG's 0.31. These directories are DELIBERATELY untracked (91 MB of int32
planes): they are worktree-local artifacts, never committed, and they are
in results/ rather than /tmp precisely because /tmp is what the
2026-09-03 19:14 reboot destroyed.

**THE MISTRAL TOKEN CACHE, likewise regenerated and kept:**
`/home/victor/wt-uperf3-ak/results/ak_mistral_toks.npy` (4,748,171 tokens,
19 MB), tokenized from ~/models/fineweb-edu/sample_text.txt with the
checkpoint's own tokenizer — the ~5.5 min step AG warned about, so REUSE
this file rather than re-tokenizing (log results/ak_mistral_toks.log).

### AK rung 1 — ONE FULL MISTRAL-7B LAYER RE-ESTABLISHED, 10/10 LEGS REJECT (2026-09-04) [MEASURED WSL-BOX 8T CPU NOISY-SHARED]

The Mistral attention export regenerated (`--arch mistral --layer 0
--tokens-cache results/ak_mistral_toks.npy --export
results/ak_attn_exports/mistral_l0`, 21.9 s once the token cache exists),
then AG's rung-5 Mistral rows re-run on the merged tree:

| shape (Mistral-7B layer 0, int24 residual) | PROVE | VERIFY | proof | peak RSS | verdict |
|---|---:|---:|---:|---:|---|
| **FULL layer, T = 16** (AK) | **12.712 s** | 0.097 s | 48,478,456 B (48.5 MB; attention half 22.6) | 10.10 GB | **ACCEPT, 10/10 legs REJECT** |
| FULL layer, T = 16 (AG) | 12.91 s | 0.11 s | 48.5 MB (attention half 22.6) | 10.08 GB | ACCEPT, 10/10 |
| **FULL layer, T = 64** (AK) | **15.008 s** | 0.243 s | 52,756,584 B (52.8 MB) | 11.24 GB | **ACCEPT** |
| FULL layer, T = 64 (AG) | 14.27 s | 0.13 s | 52.8 MB | 11.24 GB | ACCEPT |

Every proof-byte count and peak RSS matches AG to the byte / to 0.01 GB;
the walls differ by box noise only. The ten legs and what rejects them:
flipped score s8 (score matmul sumcheck), wrong exp-table entry (S
zero-check), wrong softmax quotient (S), wrong norm output (D), wrong
RoPE rotation (Q), wrong row maximum (S), flipped x_in (SS row-sum
sumcheck), BROKEN SEAM (the seam claim), FFN wrong int16 table entry
(FFN LogUp), FFN wrong requant h16 (FFN zero-check).

**THE MISTRAL CHAIN GATE:** `attn-chain results/ak_attn_exports/mistral_l0`
-> **64/64 tensor digests match the oracle** (4.16 s), oracle CHAIN
**4085604b8d61ce8c..** — AG's digest exactly. Log:
results/ak_r1_mistral.log / .done (exit 0).

### AK rung 2 — LEVER L5, THE CLAIM FOLD (2026-09-04) [MEASURED WSL-BOX CPU NOISY-SHARED]

**THE FINDING, first — the lever is bigger than AG's estimate and the
mechanism is exactly identified.** A Ligero opening costs ONE clear row
combination of 2^log_cols Fp2 per GROUP, and `pcs::group_claims` keys a
group by the claim's COLUMN TAIL — the last log_cols coordinates of its
point. Claims at different points are different groups whatever they say,
and at log_cols = 14 each group vector is **262,144 B**. Measured with the
new `HL_ATTN_CLAIMS=1` report (`attention::claim_groups_report`, stderr
only — it touches neither transcript nor proof), one 125M full layer at
T = 128 before any change:

| commitment | claims | groups | group vectors |
|---|---:|---:|---:|
| Wa | 6 | 6 | 1.50 MB |
| Ha | 38 | 6 | 1.50 MB |
| **Aa** | **93** | **49** | **12.25 MB** |
| total | 137 | 61 | **15.25 MB** of a 19.7 MB attention half |

So it is **15.25 MB per 125M layer, not 8**, and **24 of Aa's 49 groups
are single claims on the two PACKED SMALL slices** `sm` and `lm` — the
norm rows (D, Dsq, a1, a2) and the isqrt limbs, each a T-long sub-row of
a 2^14 / 2^15 packed slice, each costing a whole 262,144 B group vector.

**THE MECHANISM.** The v3 FFN prover folds every pending claim into its
two zero-checks (one nu-weighted eq term each), so A and H open at two
points. The attention argument runs its five zero-checks BEFORE its four
matmul sumchecks, so most of its claims are raised after the last
zero-check and cannot ride one — folding them into the zero-checks would
mean reordering the whole argument. The SAME arithmetic as its own
reduction is what this rung builds (`attention::collapse_range`): for a
committed range and the claims inside it,

    sum_c nu_c P(p_c) = sum_x [ sum_c nu_c eq(p_c^full, x) ] P(x)

is ONE degree-2 sumcheck over the range whose terminal is ONE claim at
ONE point; the verifier evaluates the bracket itself as
sum_c nu_c eq(p_c^full, rho), each term O(log). p_c^full is the claim's
point lifted to the range's arity by the existing `sub_point` (the
sub-block index in the high bits). **No soundness property changes**
(Schwartz-Zippel on nu, then the sumcheck) and **no new primitive is
introduced**; it costs `n_rounds x 3 x 16 B` of sumcheck plus one Fp2
terminal, and it MOVES THE PROOF BYTES by design.

Two collapse plans, both selected by `collapse_plan(lay)` from the layout
alone (public, so prover and verifier agree by construction):

* **default** — the two packed small slices `sm` and `lm` (sumchecks over
  2^14 and 2^15: free next to the layer).
* **`HL_FOLD_ALL=1`** — the binary decomposition of the WHOLE A range into
  aligned power-of-two blocks. Every plane is allocated aligned to its own
  size, so each plane lies wholly inside one block and every claim
  collapses; A then opens at as many points as the decomposition has
  blocks (4 at 125M).

`HL_NO_FOLD=1` restores the pre-fold proof for a before/after count.

**MEASURED, one 125M full layer at T = 128** (4 threads, the same binary,
same export):

| mode | Aa claims -> groups | attention half | full layer | PROVE | verdict |
|---|---|---:|---:|---:|---|
| no fold (AG's proof) | 93 -> 49 | 19.7 MB | 24,102,524 B | 2.37 s | ACCEPT |
| **fold sm+lm (default)** | 93 -> 68 claims, **25 groups** | **13.4 MB** | **17,812,492 B** | 2.39 s | **ACCEPT** |
| **fold all** | 93 -> **4 claims, 4 groups** | **7.9 MB** | **12,309,708 B** | 3.31 s | **ACCEPT** |

−32% of the layer's proof for no measurable prover time; −49% for +39% of
prover time at this shape. `cargo test --release` 40/40 with the fold in.
### AK rung 3 — THE FOLD IS THE DEFAULT: THE STATEMENT RE-VALIDATED AT BOTH WIDTHS (2026-09-04) [MEASURED WSL-BOX 8T CPU NOISY-SHARED]

The T = 512 measurement decided the default. `collapse_plan` now
collapses the **binary decomposition of the whole A range** (four aligned
power-of-two blocks at 125M); `HL_FOLD=small` keeps the packed-slice-only
plan, `HL_FOLD=nos` skips the six S-domain planes, and `HL_NO_FOLD=1`
turns the lever off.

**ONE 125M FULL LAYER, T = 512, 8 threads:**

| mode | Aa groups | attention half | FULL LAYER proof | PROVE | VERIFY | peak RSS |
|---|---:|---:|---:|---:|---:|---:|
| `HL_NO_FOLD=1` (AG's proof) | 41 | 27.3 MB | **33,234,332 B** | 7.661 s | 0.146 s | 5.102 GB |
| `HL_FOLD=small` | 25 | 23.1 MB | 29,041,500 B | 7.499 s | 0.148 s | 5.102 GB |
| **default (whole range)** | **4** | **17.6 MB** | **23,539,100 B** | 8.297 s | **0.077 s** | 5.102 GB |

**−29.2% of the layer's proof, −35.5% of the attention half, for +8.3% of
prover time, with peak RSS unchanged and VERIFY nearly halved** — inside
the plan's modelled L5 band (bytes x0.44-0.50 on the group vectors, time
x1.05-1.15).

**ONE FULL MISTRAL-7B LAYER, T = 16:** 48,478,456 -> **42,977,736 B**
(−11.3% on the layer, **−24% on the attention half**) for **+1.2% prove**
(12.712 -> 12.865 s), verify 0.097 -> 0.072 s, peak 10.10 -> 10.09 GB.
The surcharge shrinks with width because the weight commitment dominates
and `cols_log` drops to 13 there (a group vector is 131,072 B, not
262,144).

**THE 12-LAYER 125M FULL-MODEL PASS, FOLDED — the deliverable:**

| pass (12 FULL layers x 512, seams bound) | witness | PROVE | VERIFY | proof | peak RSS | verdict |
|---|---:|---:|---:|---:|---:|---|
| pre-fold (AG / AK rung 0) | 5.22 s | 100.47 s | 2.66 s | **404,327,452 B** | 6.62 GB | ACCEPT |
| **folded (default)** | 4.94 s | **107.63 s** | **0.83 s** | **282,217,500 B** | 6.44 GB | **ACCEPT** |
| change | | +7.1% | **-69%** | **-30.2%** | -2.7% | |

    PROOF sha256 2d5791ff8e153b4946086386b508ce65f6f9b8b6e48bf95a4a67f1b22eefdf43  (folded)
    PROOF sha256 c91f8713e2ed805543c1ca3a5f1c752734278606e7b13d199f1348dbf22f0ece  (HL_NO_FOLD=1)

The verify time is the surprise: the verifier checks four group vectors
per layer instead of forty-one.

**EVERY TAMPER LEG STILL REJECTS WITH THE FOLD ON** — the collapse
reduces the claims, not the statement:

* `attn-full` 125M T = 512 — **10/10 REJECT**, `attn-full: GREEN`.
* `attn-layer` 125M T = 512 (the attention half alone) — **10/10
  REJECT**, including *wrong isqrt D* (the isqrt pair), *attainment
  selector moved* and *broken residual/seam plane*, `attn-layer: GREEN`.
* `attn-full` Mistral T = 16 — **10/10 REJECT**, `attn-full: GREEN`.
* `attn-pass --all-tampers` — the LAYER SEAM leg still rejects
  (`layers 0->1: layer seam: the previous layer's xres2 != this layer's
  x_in`), `attn-pass: GREEN`.

RECORD -> results/hashline_attn_fold.md. Logs: results/ak_r3_validate.log
/ .done (exit 0), results/ak_r2_fold_512.log, results/ak_r0_attnpass12.log,
results/ak_r1_mistral.log, results/ak_r1_floors.log.

**NOT IN THIS LANE'S OWNERSHIP, OWED AT MERGE:**
`docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md` section 3 and
`results/hashline_attn_fulllayer.md` still carry the PRE-FOLD proof sizes
(33.2 MB per 125M layer, 404.3 MB for the pass). The folded numbers are
in results/hashline_attn_fold.md.

**THE FOLD IS THE ONLY CHANGE — PROVEN.** With `HL_NO_FOLD=1` the FOLDED
tree re-runs the 12-layer pass and gives AG's digest back byte for byte:
**c91f8713e2ed805543c1ca3a5f1c752734278606e7b13d199f1348dbf22f0ece
(404,327,452 B), ACCEPT**, witness 5.11 s, PROVE 94.09 s (AG: 94.54),
VERIFY 1.99 s. Nothing in the argument, the witness, the transcript or
the commitments moved — the only difference between the 404.3 MB proof
and the 282.2 MB one is how many points the A commitment is opened at.
It also means **AG's round-13 record stays checkable on the merged tree**:
`HL_NO_FOLD=1` is its gate. (results/ak_r3_nofold_gate.log / .done, exit 0)

**THE FLOOR, WITH THE FOLD IN:** `results/ak_floors.sh` on BOTH binaries
built from the folded tree — **ALL FLOORS GREEN, 8 byte gates** (v2
50cf7bdfd6b5b182.. / 66,844,928 B, v3 5f368db6240e0614.. / 70,758,084 B,
zk 021485e4f80ec695.. / 87,228,528 B, zk-v3 40eb54795e023c77.. /
87,697,008 B, cpu and gpu) — and `cargo test --release` **40/40**.

### WHERE THIS LANE STANDS (for the next session)

Rungs 0-3 are done and committed. Part 1 of the brief is closed: **the
attention exports exist again outside /tmp and AG's two headline digests
reproduce byte for byte on the merged tree**, so every attention number
in the ledger is verifiable once more. Part 2 (lever L5) is built,
measured at both model widths, and is the DEFAULT.

What the next agent should pick up, in the order the numbers argue for:

1. **Fold Ha (and, at 125M only, Wa).** They are 6 groups each — 1.50 MB
   apiece per 125M layer at T = 512, about 13% of the folded layer. The
   same `collapse_range` applies verbatim; the only work is keeping the H
   (and W) data alive in `AttnPending` until `attn_open_wh`, which today
   keeps only `a_data`. At Mistral width W is 42M entries a layer and the
   collapse would cost more than the 786 KB it saves — fold H, skip W.
2. **Stop copying A into Fp2 for the collapse.** `collapse_range` calls
   `tab2` to satisfy `sumcheck::prove`'s `Vec<Vec<Fp2>>`; a specialised
   first round reading the base-field plane in place removes one
   16-byte-per-element copy of the whole witness. Invisible at 125M (peak
   RSS was 5.102 GB in every fold mode) but it will matter at Mistral
   T = 512, where A is ~80M entries.
3. **Re-measure `HL_FOLD=nos` at Mistral T = 512** (needs the Mac). At
   125M it is worse than the default on both axes, but there the six
   `H x T x T` S-domain planes are a minority of A; at 8B/T=512 they are
   the majority and the trade may invert.
4. **AG's items 2-6 are untouched by this lane**: block-don't-pad (1.33x
   of prover time at 125M, nothing at Mistral), the 32-layer 8B
   full-model pass (the Mac), the GPU port of the attention zero-checks
   (plan item B6), zero knowledge for the attention half (A5), and the
   statement's remaining holes (embedding, final norm + LM head, the
   KV-cache/decode regime, sliding windows).
5. **The plan's C2** — the batched-evaluation reduction proper (every
   claim to ONE point, W/A/H merged into one commitment, `n`
   re-optimised) — subsumes this rung. This rung is the evidence that its
   first half alone is worth -30% of the full-model proof at +7% of
   prove.

New knobs, all tagged `[UPERF3-AK]`: `HL_ATTN_CLAIMS=1` (the
claims/groups/bytes report on stderr, plus a line saying how many claims
collapsed), `HL_FOLD=small|nos` (the two other collapse plans),
`HL_NO_FOLD=1` (the lever off — this is what reproduces AG's pre-fold
digests, and it is how the round-13 record stays checkable).

## ROUND 15 — THE ITEM NOBODY OWNED (opened 2026-09-04)

Ground: round 14 merged in full (AJ, AK, AI at rung 3). Its one
orchestration error is this round's whole content.

Lane AJ built and gated every host item the 60 tok/s plan named and the
8B pass moved 88.90 -> 86.00 s: **1.034x against a modelled 2.4-2.9x**.
The cause is not the lane. The plan's B1 item conflated the UPLOAD
(13.05 s of device counter, AJ's, fixed) with the plane -> Fp
CONVERSION, which lives in `layer.rs` — `prove_layer_v3` building
`w_data` (1.4 GB at Mistral width) and `a_data` element by element with
`Fp::from_i64`, measured at 0.92 s of a 3.13 s layer = **~29 s of the
8B pass, the single largest host item in it**. `layer.rs` was READ-ONLY
for AJ and assigned to no round-14 lane.

It is also the gate on the hardware step: AJ's §8 counts the parts a
faster device shrinks at ~1.0 s of a 2.50 s layer and the parts it does
not touch at ~1.2 s of `layer.rs` conversion and folds, so on a device
4x faster the host share becomes ~70% of the layer. **This item decides
whether the RTX 5090 buys 1.4x or 4x**, and no headline measurement
should be scheduled before it lands.

### Lane AL — the layer.rs conversion (wt-uperf3-al) — RUST/CUDA
OWNS: the v2/v3 FFN prover bodies in hashline/src/layer.rs (NOT the
[UPERF3-AG] full-layer functions, NOT lane AH's `dev_shape` line),
hashline/src/pcs.rs, NEW results/hashline_convert_*, "Agent AL status".
READ-ONLY: gpu/* (AJ's kernels are DONE and correct — `k_widen` is the
device half of this fix and must be used, not rewritten), zk.rs,
attention.rs, norm.rs, tables_*.rs, wcache.rs, zkmatrix-rs/, scripts/.
TARGET, in AJ's words: hand `pcs::commit` the int8 planes instead of a
converted 64-bit vector, and give the two host matmul folds
(`fold_cols_base` over `w_data`, ~0.26 s/layer) a device form. Ceiling
~1.5x on the 8B prove. BYTE-PRESERVING: the four gates and dc980e81..
must not move.
EVIDENCE TO READ FIRST: results/hashline_hostwall_gpu.md §7 and §9.1 —
AJ attributed this item to functions and measured it; do not re-derive.

## RULING (Victor, console 2026-09-05): TWO PRODUCTS — FULL ZK IS THE FOCUS, PUBLIC WEIGHTS IS THE FAST TIER

"Let's make a Proof with ZK weights and one without. There are
applications where the faster proofs with public weights might be
useful." — and then: "We should focus on the full ZK proofs but also
have this as an additional product (non ZK weights)."

THIS SUPERSEDES the 2026-09-03 P1 ruling as a statement of PRIORITY.
P1 is not withdrawn; it becomes the second product. The primary target
is now P3 (private inputs AND private weights).

WHAT THE TWO PRODUCTS ARE, exactly:

* **Fast tier — P1 (private inputs, public weights).** What is built
  and measured today: the 8B GPU row at 265.34 s, sha256 930ce9a0..
  The weight commitment is PER-MODEL CACHEABLE, so its ~37 s (of an
  86.00 s non-ZK prove, lane AJ's measured phase table) amortises to
  ~0 across proofs. This is the tier where 60 tok/s is reachable.
* **Full tier — P3 (private inputs AND weights).** The weight cache is
  FORBIDDEN here, and not as a policy choice: a cached hash-based
  weight commitment reveals 256 of its encoded columns per proof and
  after ~65 proofs the weights are recoverable by linear algebra
  (lane ZZ, U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md §1). So W must be
  re-committed with fresh randomness on EVERY proof, and committed
  hidingly.

THE STRUCTURAL COST, already priced by lane ZZ [COUNTED]: the
re-commit is +9.6% at 125M, +44% at 8B x 512, +54% at 30B x 512 on the
laptop, and a 7-23 s per-proof hashing floor at 30B on an H100 — which
is 70-230% of the whole prefill budget by itself. Under P2/P3 as
counted, NO cell reaches 50 tok/s at one request per proof; option 1
tops out at 48 at 30B and reaches 50 only at >= 16 stacked 512-token
prefills.

THE THREE DESIGNS, and which one the primary product needs:
1. **Re-commit every proof.** Cheap to BUILD — `zk.rs` already commits
   W with plain `pcs::commit` while A and H use `commit_zk_owned` /
   `commit_zk_device`, so the change is to use the ZK commit for W too
   and refuse `--wcache` in the mode. Expensive per proof. **This is
   what we build first: it makes the full-ZK product EXIST and gives
   the honest baseline every later design is measured against.**
2. **Never send the sampled weight columns** (T18, lane ZZ option 2).
   Commit the weight tree once per model under an arithmetic hash
   (Poseidon2) and prove the verifier's column check inside a fresh ZK
   inner proof, clear vectors masked per proof. Per-proof surcharge
   50-180 ms at the counted floor on an H100 — it puts the full tier
   back on P0's own cells. **~2 lane-weeks to a first measured row**,
   and it needs a WRITTEN SIMULATOR for the composition: the published
   construction it descends from was found unsound (ePrint 2024/1164).
   This is now the primary product's throughput path.
3. **The lattice hybrid.** An audit channel, not a throughput route;
   its cross-commitment link is unsolved (§4 of the memo).

OPEN FOR VICTOR (one question, stated in the report): which product
carries the 60 tok/s headline. Recommendation: the FAST TIER keeps it,
because that is where the counted floor contains it; the FULL TIER gets
its own honest number and its natural shape is batched (>= 16 prefills
per proof), which is what option 1 needs to reach 50 at all.

### Lane AM — the two privacy tiers, both first-class (wt-uperf3-am) — RUST
OWNS: hashline/src/zk.rs, the mode flag lines in src/bin/hashline.rs,
NEW results/hashline_p3_*, "Agent AM status". READ-ONLY: pcs.rs (lane
AL owns it — use the EXISTING `commit_zk_owned` / `commit_zk_device`
entry points; if you genuinely need a pcs.rs change, STOP and report
it rather than editing), layer.rs (lane AL's), gpu/* , attention.rs,
norm.rs, tables_*.rs, wcache.rs, zkmatrix-rs/, scripts/.
TARGET: design 1 above — a mode selector so ONE binary produces both
products, and the first measured 8B row for each. P1's row must stay
byte-identical to 930ce9a0..; P3 is a new statement and gets its own
digest, its own tamper legs, and an honest per-proof cost against P1.

## Agent AM status (wt-uperf3-am) — round 15

(lane appends below)

### AM rung 0 — THE OUTPUT-PRIVACY QUESTION (asked ahead of everything else), the mode design, and the baseline (2026-09-04)

**THE QUESTION (Victor, via the orchestrator): under `--zk` today, does the
statement publish the OUTPUT tensor values in the clear?
TARGET_CONTRACT.md §3 says the "declared output tensor values" are public;
U_PERF3_ROUTE_B_THROUGHPUT.md §4.5 puts activations — the output is one —
in P1's private set. Which is it, from the code and from a real proof?**

**THE ANSWER: NO. Nothing of the output tensor is in the statement — the
statement carries no tensor values at all, of any kind, input or output.
The contract's §3 line does not describe what this prover proves.**

The evidence, in code (`hashline/src/layer.rs`, read-only for this lane;
line numbers on the round-15 tree):

    pub struct StatementV3 {           // layer.rs:1125
        pub l: usize, pub t_rows: usize, pub d: usize, pub f: usize,
        pub shifts: (i32, i32, i32, i32),
        pub act: Act16Fn, pub table: [i16; 256], pub table_digest: String,
    }
    pub struct Statement {             // layer.rs:40 (the v2 statement)
        pub l: usize, pub t_rows: usize, pub shifts: (u32, u32, u32, u32),
        pub table: [i8; 256], pub table_digest: String,
    }

Eight fields, all of them shape or quantization metadata: the layer index,
the token count, (d, f), the four signed requant shifts, the frozen
activation table and its digest. There is no X, no z16, no digest of
either. `zk.rs`'s `absorb_statement_v3` absorbs exactly those fields and
then the mode tag; `bin/hashline.rs`'s `stmt_v3(w, t)` builds the statement
from the witness by copying exactly those fields and nothing else; and
`verify_layer_zk_v3(st, proof, params, ntt, tr)` reads only `st` and the
proof bytes. So the verifier is never handed an output value to compare
against, and there is no code path by which one could reach it.

WHERE THE OUTPUT ACTUALLY LIVES: the output plane z16 (and its remainder
plane rd) are rows of the **A commitment**, which under `--zk` is
`pcs::commit_zk_owned` — ZA's hiding form: Q = 256 uniform pad symbols per
row on the coset 7·G_4n (no systematic position is ever opened), salted
Merkle leaves, and a mask row at every opening site, so each opened claim
is the two-part masked claim (1 − e)·T~(p) + e·R~(tail p) with R a fresh
uniform row. Every evaluation of z16 that leaves the prover is that masked
combination; the terminals are `masked_terminal(...)`; the clear vectors
are `rho^T[M | pads]` with the mask rows inside rho. That is exactly the
treatment every other activation gets — the output is not a special case
and gets no weaker protection.

WHAT THE VERIFIER THEREFORE LEARNS, stated precisely (mode P1 today):
"there exist activations, committed under the root `a_com`, consistent
with the public weights, these shapes, these shifts and this activation
table, satisfying every layer identity, every range/lookup fact and the
requant identities." It does NOT learn the input, the output, or any
intermediate value. Consequently:

* A deployment declaring "inputs and outputs private" under `--zk` is
  making a claim its statement SUPPORTS, not one it contradicts. Victor's
  fast-tier phrasing ("ZK for inputs and outputs, weights public") is what
  the code does.
* `TARGET_CONTRACT.md` §3's "the declared output tensor values" is the
  line that is out of date. Not this lane's file to edit — reported here
  for Victor's ruling. `U_PERF3_ROUTE_B_THROUGHPUT.md` §4.5 is the one
  that matches the build.

**THE NUANCE THAT IS THE REAL FINDING, and it cuts the other way.** The
output is hidden — but it is also not BOUND to anything a verifier could
name. Two gaps, both stated as findings, neither fixed by this lane:

1. **No declared output commitment.** z16 is committed, but only as some
   rows of A, fused with the input X, the seven intermediate f-planes, the
   remainders and the multiplicity tables under one root. A deployment
   that wants "this model, on the committed input C_in, produced the
   committed output C_out" — so that C_out can be matched later against a
   served response, or fed to the next stage — has no such object to point
   at. The honest fix is a per-layer declaration in the statement naming
   the (slice, root) that carries X and z16, or a small separate
   commitment to each with a claim tying it to A's rows. That is a
   statement change: it moves proof bytes and would break the frozen
   digests, so it is a ruling, not a lane decision.
2. **No cross-layer value binding.** `pass_zk_v3` proves n independent
   layer statements that share ONE Fiat-Shamir transcript. The shared
   transcript orders them and stops a proof being reused out of place; it
   does NOT assert that layer l's z16 equals layer l+1's X. The witnesses
   are chained OUTSIDE the proof (`chain --profile v3` re-executes the
   chain and reproduces every plane digest — ZB's rung 2), which is a
   prover-side check, not something the verifier is shown. So "the model
   ran end to end" is today an argument about how the witness was built,
   not a proven statement. Same class of ruling: fixing it means the
   statement (or a claim) grows.

**What the trade in the orchestrator's question (2) would have been, had
the answer been yes** — recorded because the answer being "no" is only
half the story, and (1) above is the same trade under another name.
Binding the output as a commitment instead of a value: the verifier can
still check every internal identity, the ranges, the lookups, the requant
rounding and (given the same committed input) the determinism of the pass;
it can no longer check the output against anything it holds — it must
receive the opening later, or compare C_out with a commitment produced by
someone it trusts. The privacy is real and the loss is real: a verifier
alone can no longer answer "did the model output THIS", only "the output
is whatever is inside C_out".

**MODE (3): THE DECLARATION NAMES THE PRIVATE SET, AND IT IS IN THE
TRANSCRIPT.** The mode already rides in the statement: `zk.rs` absorbs
`tr.absorb(b"zk", b"P1-v3")` (line 1914, prover; 2766, verifier) right
after the statement fields, before any challenge. Two consequences that
are exactly what the design note asks for: the mode is part of the
Fiat-Shamir domain, so every challenge in the proof depends on it, and a
verifier that checks with the wrong mode diverges at the first challenge
and REJECTS. **A P1 proof therefore cannot be presented as a P3 one, and a
P3 proof cannot be checked as P1.** This lane's additions:

* the P3 tag is `P3-v3/priv=in+act+out+weights/pub=shape+shifts+tabdigest`
  — the wire tag itself names the private set, so a P3 proof is
  self-describing from the first byte of its transcript;
* the P1 tag stays `P1-v3` byte for byte (the round-13/14 gates
  `40eb5479..` and the 8B row `930ce9a0..` freeze it), and prover and
  verifier both PRINT the mode line naming P1's private set exactly:
  private = {X, every activation plane incl. the output z16, the
  remainders, the multiplicities}; public = {W, shapes, shifts, the
  activation-table digest};
* `verify_layer_zk_v3` takes the mode as an argument — the verifier is
  TOLD which privacy claim it is checking, and cannot infer it from
  prover-supplied bytes.

**THE PLAN FOR THE REST OF THE LANE** (design 1 of the 2026-09-05 ruling):
P3 = W committed with `pcs::commit_zk_owned` (fresh pads, salted leaves,
fresh per proof), W mask rows at both of its opening sites — one per W
BLOCK terminal, because a single shared mask row would leave block
differences in the clear — the matmul W terminals masked exactly as A's
are (the sumcheck's extension round already carries the selector: set the
W tables' `exts` to the combined mask evaluation and the verifier's `want`
absorbs the (1 − e) factor), and `--wcache` REFUSED, loudly, because a
cached hash commitment reveals 256 encoded columns per proof and is
recoverable after ~65 proofs (lane ZZ §1). v2 keeps P1 only.

**BASELINE** [WSL-BOX] [8T] [NOISY-SHARED — lane AL is building] the four
byte gates on both binaries of THIS tree, and the P1 8B row's digest
re-confirmed here: results/am_r0_floors.log (see the next rung for the
verdict; the run is detached under the heavy lock with a `.done` marker).
