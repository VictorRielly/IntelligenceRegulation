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
