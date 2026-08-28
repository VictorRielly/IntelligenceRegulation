# U-PERF3 lane X — the attention statement: MVP-2's design under the C1-C6 contract

Status: DESIGN MEMO (U-PERF3 round 2, lane X, 2026-08-25, worktree
wt-uperf3-x; documents only, no code). This memo OPENS the MVP-2
trench: the full transformer layer (attention, norms, residuals) as
a proof statement, mapped onto the claim machinery the FFN pass
already runs, instantiating the C1-C6 model-agnostic quantization
contract (QUANTIZATION_CONTRACT_DESIGN.md) and discharging its L6
("attention inherits C1-C6 by construction") concretely. Semantic
input: ATTENTION_INTEGER_SPEC.md (2026-08-11, spike 18/18) — taken
as the frozen integer semantics; where this design needs it amended,
the amendment is PROPOSED explicitly (the AM-1..AM-10 list, Section
6.3), never silently assumed. Counting method and measured anchors:
U_PERF3_MVP8B_SCALING.md Section 1 (the 12x512 attribution: 21.0 s =
commit 2.5 / prove-group 7.1 / descents 6.5 / claim 1.75 / transport
1.4 / CRS 1.3 / verify 1.7 [MEASURED WSL-BOX 8T+GPU QUIET], reused
not recounted). Every number is labelled [COUNTED] / [MODEL] /
[ASSUMED]; [EXTERNAL] marks literature.

Shapes used throughout (T = 512 contract workload):

- **125M frugal**: 12 layers, d 768, f 2048, H 12 / H_kv 4 (GQA 3),
  d_h 64, SwiGLU, 2 norms/layer, vocab 49,152 tied.
- **Mistral-7B (the 8B FFN contract shape)**: 32 layers, d 4096,
  f 14336, H 32 / H_kv 8 (GQA 4), d_h 128, SwiGLU, 2 norms/layer.
- **Gemma-4-12B** (ledger "GEMMA 4 12B QAT DOWNLOADED AND SCOPED",
  2026-08-25): 48 layers, d 3840, f 15360, GeGLU, FOUR norms/layer
  (input / post_attention / pre_feedforward / post_feedforward),
  QK-norm [256], per-layer layer_scalar [1], hybrid attention — 40
  sliding layers (window 1024; GQA 16/8 at d_h 256) + 8 global
  layers (global_head_dim 512, 1 global KV head, attention_k_eq_v),
  final logit softcap 30.0, vocab 262,144 tied. [ASSUMED, flagged
  for lane Y's HF-modeling-source read: global layers run 8 query
  heads x d_h 512 (projection width 4096 preserved); layer_scalar
  is a residual-branch scalar multiplier.]

## PROGRESS

- [x] Section 0: one paragraph — what MVP-2 adds, the headline multiples
- [x] Section 1: the op inventory and its integer form (incl. RoPE ruling, C5 members)
- [x] Section 2: the mapping onto the existing claim machinery
- [x] Section 3: counts at the three shapes; the T story
- [x] Section 4: statement/witness size and memory
- [x] Section 5: the MVP-2 build plan (rungs, lanes, the ONE spike)
- [x] Section 6: design choices and limitations (numbered, the house style)
- [x] Section 1.6b: the MEASURED Gemma gate data (lane CC, 2026-08-26) — core int8-clean, seam sites widened-class, stack_wide +0.0854

## 0. One paragraph

MVP-2 extends the proved statement from "32 disconnected FFN blocks"
to the full transformer layer chained end to end: RMSNorm (two to
four sites per layer), QKV projections with GQA/MQA, QK-norm where
the model has it, RoPE, causal/sliding scores, the exact integer
softmax (proven row max + a frozen exp table + a committed-divisor
floor-division relation), PV, the output projection, both residual
adds, and embedding/unembedding — all under the C1-C6 contract with
per-channel power-of-two exponent vectors where calibration demands
them. No new claim family is required for modes P0/P2
(ATTENTION_INTEGER_SPEC.md's verdict, re-confirmed here against the
as-built BF/BK/BG machinery): the extension is more matmul-family
instances, more zero-checks, more range/lookup descent columns, five
public-weight wirings, and ONE contract amendment (the
committed-divisor division relation, AM-1). The honest headline
multiples of the full layer over the FFN-only statement at T = 512
[COUNTED witness / MODEL prove]: **125M x3.6 witness, ~x5 prove
as-built (~x2.5 if the range facts ride lane S's Stage-A zero-check
instead of masked descents) — 21.0 s -> ~105 s / ~55 s on the
reference rig; Mistral-8B x1.7 witness, ~x2.0 prove — the Mac MVP-1
projection 35-75 min becomes ~1.2-2.5 h; Gemma-12B x1.7 witness over
its own FFN (which is itself x1.5 Mistral's) — ~2-4 h Mac-CPU
class.** The asymmetry has one cause: attention's committed volume is
O(T^2 H) per layer against the FFN's O(T f + d f), so at T = 512 the
125M statement is already attention-dominated (crossover T ~ 163)
while the 8B-class statements are still FFN/weight-dominated
(crossover T ~ 733 Mistral / ~1071 Gemma-sliding). Two structural
consequences land as new break items: at the 8B-class full layer the
WEIGHT commitment group (x1.24) busts the level-0 exact-digit gate
cap that MVP-1's group just cleared (split k = 2, X-W12), and the
score-volume descent columns multiply exactly the object lane S's
GO/GO spike replaces 9-25x — Stage A is not an optimization for
MVP-2 at 8B, it is the memory-feasibility line (Section 4).

## 1. The op inventory of one transformer layer, and its integer form

The per-op integer semantics are ATTENTION_INTEGER_SPEC.md Sections
2.1-2.9, adopted wholesale; this section restates each op only to
the depth needed to (a) check it against the C1-C6 chain form, (b)
name the C5 table members it needs, (c) rule the two design
questions the round brief names (RoPE; softcap), and (d) extend the
inventory to the Gemma sites the spec predates.

### 1.1 The chain, in order (one layer)

    x --attn_norm--> xn --Wq/Wk/Wv--> q,k,v --[QK-norm]--> qn,kn
      --RoPE--> qr,kr --scores QK^T (GQA map)--> Sacc --requant--> s8
      --row max m + d = m - sM--> exp table--> E --masked row sum--> Sum
      --division relation--> P --PV--> Oacc --requant--> o8
      --Wo--> AOacc --requant--> ao8 --[post_attn_norm]--> --residual-->
      x' --mlp_norm/pre_ffn_norm--> (the FFN block, MVP-1's statement)
      --[post_ffn_norm]--> --residual--> x''

Bracketed sites exist only on models that have them (Gemma's
four-norm sandwich and QK-norm); on 125M/Mistral the chain is the
spec's two-norm form. Every arrow is one of exactly four move
classes, all already in the contract vocabulary:

1. **matmul-class**: QKV, scores, PV, Wo, the row sums (SS, E-sum,
   zsel-sum), embedding/unembedding — exact integer accumulation
   (C1), accumulator widths from the inner dimension (27-bit at
   inner 4096; 22-bit at d_h 128 scores; 24-bit at Gemma's global
   d_h 512 [COUNTED: 512 x 127^2 = 8.26M]).
2. **requant edges**: floor division by 2^shift with proven
   remainder + narrowing fact (C1 verbatim). Under C2 the shift
   becomes a per-channel VECTOR where calibration demands (Section
   1.6).
3. **table gates**: exactly ONE new table family (exp-neg; Section
   1.3) plus the parametric range widths — everything else that
   looks reciprocal-shaped is deliberately NOT a table (Section 1.4).
4. **division relations**: floor division by a COMMITTED divisor
   (RMSNorm's D * 2^tn; softmax's Sum) — quotient*divisor +
   remainder identity as one degree-<=3 zero-check with two-sided
   remainder ranges (spec Section 2.9, [PROVEN arithmetic]). This is
   the one move C1 as frozen does not name: **AM-1** proposes the
   TARGET_CONTRACT Section 2 v3 wording admit it as a chain form
   alongside the 2^shift requant. It adds no claim family — it IS a
   zero-check plus range facts.

### 1.2 RMSNorm, QK-norm, and Gemma's four-norm sandwich

The spec's RMSNorm gadget (Section 2.1): squares by self-Hadamard,
row sum by ones-matmul, integer square root by the isqrt fact pair
(two w14 range facts + one self-Hadamard — D is THE exact isqrt),
then the division relation with the public window constant Cn. The
rsqrt TABLE is the spec's recorded loser (mantissa normalization
costs more than the fact pair; the same argument kills a reciprocal
table for the softmax denominator) — re-affirmed here, nothing to
re-litigate.

**QK-norm (Gemma) is the SAME gadget at row width d_h**: q_norm/
k_norm are RMSNorm over each head's 256 coordinates, weights [256]
shared across heads. The gadget instantiates with d -> d_h = 256 and
rows T*H (q side) / T*H_kv (k side). Bonus: sqrt(256) = 16 is a
power of two, so Cn is EXACT at this site (the spec's "8B bonus"
mechanism, item 2 of its Section 2.1). **AM-5** adds the site to the
spec's site list.

**The four-norm sandwich**: post_attention/post_feedforward norms
normalize the SUBLAYER OUTPUT before the residual add (x' = x +
post_norm(attn_out)), so the residual spec (Section 2.7) gains the
normed-output ordering — same gadgets, one more requant edge per
site, no new facts. **AM-5** covers this too. Cost: Gemma pays 4
norm sites + 2 QK-norm sites per layer vs the spec's 2 (counted in
Section 3).

**layer_scalar**: a per-layer scalar [1]. Handling [ASSUMED until
lane Y reads the HF modeling source]: quantize the declared scalar
to a public fixed-point constant; if it lands on a power of two it
folds into the adjacent requant shift (zero cost); otherwise it
rides as a Cn-style declared public multiplier inside the adjacent
requant pin (zero witness either way). **AM-8**. If the HF source
reveals it multiplies something nonlinear-adjacent, the fallback is
one extra linear pin — still no witness.

### 1.3 The integer softmax, checked against C1, and the C5 members

The spec's softmax (Sections 2.4-2.5) is: (stage 1, resolution) a
standard requant of the 21/22-bit score accumulator to int8 at the
calibrated eS; (stage 2, offset) a committed row max m with
dominance proven by ONE [0, 2^8) range fact on d = m - sM and
attainment by a binary selector zsel (w1 + row-sum-1 + z o d = 0);
then E = ExpT[d] through a 256-row frozen table; a masked thin
sumcheck for Sum; and the division relation P o Sum + rho = 2^fP * E
with two-sided w18 remainder ranges and the off-support zero pin.
Checked against the C1 chain form: every step is int8 operands /
exact accumulation / floor requant / frozen table / range facts,
EXCEPT the division by committed Sum — which is AM-1's clause. No
shift-normalized reciprocal table, no floating point, no clamp
anywhere. The "row-normalization coupling" that looks research-shaped
is, in the claim vocabulary, four facts on one transcript (Section
2.2 of this memo); the spec proves the arithmetic pins m and every
output uniquely ([PROVEN]; ties leave only zsel non-unique).

**The C5 table registry members this design needs, with (function,
e_in, e_out) signatures** (C5 keys members by function and scales;
AM-2 extends the key with a params field and admits non-int8 output
widths):

| member | signature | rows | shapes needing it |
|---|---|---|---|
| exp-neg | (exp-neg, e_in = eS, e_out = -fE, params {d_h}) u8 -> u(fE+1), fE = 9 | 256 | all; one member per distinct (eS, d_h): 12 at 125M, 32 at Mistral, <= 48 at Gemma (d_h 256 sliding + d_h 512 global) [per-head eS multiplies members: Section 1.6] |
| silu | (silu, eGate, eA) i8 -> i8 (frozen v2 family) | 256 | 125M/Mistral FFN (existing; W-6 ruling pending) |
| gelu-tanh | (gelu_pytorch_tanh, eGate, eA) i8 -> i8 | 256 | Gemma FFN (route-N adapter work, already queued) |
| tanh-softcap | (softcap-tanh, eL, eL', params {cap = 30}) | 256 | Gemma final logits ONLY IF logits are private (Section 1.5) |
| range-w | ([0, 2^w)), parametric w in {1, 8, 9, 10, 11, 14, 18} + the shift widths | 2^w | all (spec AT-O5; trivial generation rule, frozen digests) |

Explicitly NOT members (the spec's recorded losers, kept): rsqrt,
reciprocal-of-Sum, any variable-shift mantissa-normalized table. The
division relation covers both at two w-class range facts + one
zero-check each.

### 1.4 Scores, the causal/sliding mask, GQA/MQA, k_eq_v

Scores are ONE stacked matmul-class sumcheck per layer over (h, t,
j, t') with the public GQA map g(h) composed into the K-side weights
(PW-2) — the head index is index-extension variables, the same
mechanism the pass fold already uses for the layer index. The
1/sqrt(d_h) fold lives in the exp table's decay constant (exact at
d_h 64; declared-generation at 128/256/512), never in a shift.

**Masks are public structure, zero witness.** The causal mask enters
as public lower-triangular weights inside every consuming pin/
zero-check (PW-3), with off-support positions reading the domain
minimum -127 so every softmax fact holds on the full T x T rectangle
(the spec's construction). **Sliding windows generalize PW-3 to a
public BAND matrix** — same weight class, same off-support
convention; at T <= window the band IS the triangle, so **at the
contract T = 512 Gemma's 40 sliding layers (window 1024) are plain
causal and cost nothing new** [COUNTED: 512 <= 1024]. **AM-6**
records the band form for T > window (where it also CAPS the score
volume at T x window per head — the long-T consequence in Section
3.4).

**MQA and k_eq_v (Gemma's global layers)**: 1 KV head is the GQA map
with g(h) = 0 — public weights, nothing new. attention_k_eq_v means
K and V are the SAME projection: commit the tensor once, let both
the score instance and the PV instance read the same committed
segment — a layout fact (one commitment, two consumers, bound by the
same u_0 group identity), saving the V triple and its facts at those
layers [COUNTED in Section 3]. **AM-7**. A battery leg (wrong-tensor
read) covers the wiring, not the soundness.

### 1.5 RoPE — the key design question, both routes counted

RoPE is a per-position PUBLIC block-diagonal rotation: within each
head, position t rotates coordinate pairs by angles t * theta_i. Two
honest ways to put it in the statement:

**Route (a) — proved elementwise rotations (the spec's Section 2.3,
the as-specified form).** Public c/s tables at fRo = 7
(rope-cs-table-v1, frozen bytes + drift-loud generator), ONE
degree-2 zero-check per rotated tensor using the flip-read (one
extra MLE opening point on q8 — mu-batching serves it), then a
requant edge back to the int8 grid. Witness cost per layer: 6
committed tensors (QRacc, qr8, rQR; KRacc, kr8, rKR) + 2 remainder
and 2 narrowing descent columns. [COUNTED] 1.57M coeffs/layer at
125M (3.7% of the attention extension), 7.86M at Mistral (4.2%),
similar share at Gemma. Public data: 2 x T x d_h/2 int8-class
entries per (T_max, d_h, base) member — 32 KiB at 125M.

**Route (b) — RoPE folded into the score matmul as public linear
structure (no rotation witness at all).** Because rotations compose,
R_t^T R_t' = R_(t'-t), the rotated score q_r(t) . k_r(t') equals a
RELATIVE-rotation form: the score sumcheck's public weights gain a
Toeplitz factor c/s[t'-t, i] generated directly at fRo bits (NOT
fRo^2 — the composed table is rounded once). Drops all 6 tensors and
their 4 descent columns per layer: [COUNTED] -3.7% extension coeffs
at 125M, -4.2% at Mistral — a small win, because RoPE is small.
Costs, honestly: (i) the declared function CHANGES — rotate-then-
requant-then-multiply becomes one fused product with a single
rounding; the reference walk, calibration, and the C4 gate all move
with it; (ii) the score accumulator bound becomes 2 * d_h * 127^2 *
2^fRo: 2^28 at d_h 64, **2^29 at d_h 128 (fits q31's 2^30-200
non-wrap), 2^30.0 at Gemma's d_h 256 — BUSTS at fRo 7, needs fRo 6
(and fRo 5 at global d_h 512), a rotation-resolution cut the C4
quality gate would have to price** [COUNTED]; (iii) the score
instance's public weight function is no longer an eq-product — the
verifier evaluates a public Toeplitz MLE, O(T * d_h) per instance
(sub-second, fine), and the prover's weight build is new PW work of
the same class it replaces.

**The ruling this memo proposes: route (a) for MVP-2.** The spike
already validates it end to end (18/18), the requant semantics are
the contract's own, fRo = 7 holds at every shape, and the saving
route (b) buys is ~4% of the extension. Route (b) is recorded as a
counted option that becomes worth revisiting only if (T^2-lever work
having landed) the linear-volume tensors become the binding cost, or
if a future shape needs rotation resolution the requant grid cannot
carry. No spec amendment needed for (a) beyond **AM-4**: the
rope-cs-table-v1 header gains the rope base as a keyed field (Gemma
uses DIFFERENT bases for sliding vs global layer types [per the
ledger's scoping; exact values are lane Y's HF read]) and members
per (T_max, d_h, base, fRo); the non-interleaved convention flag
binds per model in the manifest.

### 1.6 C2 instantiation: which sites carry exponent VECTORS

C2 gives every quantization site a public per-channel power-of-two
exponent vector over ONE declared axis (constant vector = the
degenerate per-tensor case; the 125M statement unchanged). The
attention sites and their proposed axes (**AM-3**):

| site | declared C2 axis | consequence in the machinery |
|---|---|---|
| xn (norm outputs) | d-axis | Cn becomes a public per-column constant vector in the division zero-check — a PW-4-class public broadcast read, degree unchanged |
| q, k, v, qr, kr | HEAD axis | per-head eQ/eK/eV; requant shift vectors indexed by head |
| s8 (scores) | HEAD axis | per-head eS -> per-head exp members (C5 instancing per distinct value); the requant zero-check's public coefficient MLE 2^s gains a head index — the SAME class as the layer-coefficient MLE c~(l) = 2^{s_l} the BG pass already built for the folded requant family |
| o8, ao8, xres | d-axis | as the FFN's R+ sites (agent V's pricing covers the engine surface) |
| E, P, d, zsel, Sum, m | none (structural) | widths are structural (E <= 2^fE etc.), no calibration freedom |

The load-bearing observation: **per-head and per-channel shift
vectors need NO new claim machinery** — the folded requant family
already reads its shift as a public coefficient MLE over the layer
index; extending the index set to (layer, head) or (layer, channel
group) is the same public-weight construction (the BG precedent,
PW-class work with an F5 battery). The engine bill for per-column
alignment is the SAME surface agent V is pricing for the FFN's R+
route; attention adds sites, not a new mechanism. Why this matters
at 8B-class: the Mistral calibration finding (emergent outliers,
+8.18 nats as-written) provably has an attention analogue — the
spec's own risk 1 says attention logits are famously heavy-tailed —
and Gemma's QK-norm is an architectural mitigation on exactly the
q/k rows (one reason the route-N candidate is attractive for MVP-2,
not just MVP-1). Every attention exponent remains [SYNTHETIC] until
the AT-O1/C4 run (Section 5).

### 1.6b MEASURED (2026-08-26, lane CC — the qualification-gate data)

The C4-style gate ran on Gemma-4-12B (48 layers, 40 sliding/8 full;
scripts/m8b_gemma4_attn_gate.py, equiv phase bit-exact vs the
validated walker; results/m8b_gemma4_attn_{stats,attrib,widen}.json,
[MEASURED WSL-BOX NT], attrib/widen on the 2-window val subset).
Three findings, in the order they kill assumptions:

1. **The attention COMPUTE CORE is int8-clean per-tensor.** Range
   ratios (absmax/p999) <= 5 at q/k/v/scores/ctx, and first-order
   int8 deltas: q -0.0005, k +0.0203, v -0.0363, scores -0.0213,
   exps -0.0146, probs -0.0871, ctx -0.0446 (negatives = subset
   noise floor). QK-norm is doing exactly the mitigation 1.6
   hoped: the per-HEAD exponent vectors proposed for q/k/s8 are
   NOT needed at first order — the degenerate per-tensor C2 case
   suffices there. qr wants q's exponent +1 bit only at l5.
2. **The seam/residual sites are the FFN disease again**: ratios to
   49 (xattn l0 absmax 1302, col-ratio 100); int8 deltas xattn
   +2.0043, ao +0.4081, postn +2.1633, xres +13.2300; all-site
   int8 composes to +14.8339. Wattn (all four proj weights int8)
   costs +0.2000.
3. **Class WIDENING rescues, exactly as in the FFN v3 ruling**:
   int16 (e-8) singles land xattn -0.0158, ao -0.0108, xres
   -0.0549 (rescued to noise); postn +0.1895 is the ONE site with
   a first-order residue (the four-norm sandwich's requant edge —
   open item below). The composed **stack_wide** row (every site
   int8 incl. Wattn, only xattn/ao/postn/xres at int16):
   **+0.0854** — the widened attention stack sits in the same
   +0.1-nat class as the FFN's widened stack. (stack_wide beats
   the postn16 single: first-order singles over-count the postn
   residue; the composed number is the decision-relevant one.)

Consequences for the AM-3 axis table: the d-axis R+ per-column
machinery priced for o8/ao8/xres is likely UNNECESSARY on this
checkpoint — the v3-style widened CLASS at the four seam sites is
the measured fix (sites, not axes); the softmax fixed-point floor
matters more than range (75-92% of causal support sits below the
fP=9 step — fP is a resolution knob, revisit with the exp-table
member choice); postn's +0.19 residue is the open question (finer
e, a per-column vector at THIS one site, or accept — same decision
family as lane AA's Gemma margin-cost finding). Exponents at the
core sites graduate from [SYNTHETIC] to [MEASURED] for Section 5's
AT-O1 rung.

### 1.7 Softcap, embedding, unembedding

**Softcap (Gemma)**: final-logit site only (the scoped Gemma-4
config has NO attention-score softcap — QK-norm replaced it; lane Y
verifies against the HF source). softcap(x) = 30 * tanh(x/30) on
the logits. Ruling proposed (**AM-9**): in P0/P2 with public
declared outputs, declare the RAW logits public and apply softcap as
PUBLIC post-processing — zero proof cost, exactly the spec's
"declare the raw logits public" statement-level choice. Only a
deployment that must keep logits private-but-softcapped pays the C5
tanh-softcap member (one 256-row table on the requantized logit
grid). The clamp alternative (public clamp at +-cap) is NOT
function-preserving (tanh is not a clamp) and is rejected — it would
change the declared model.

**Embedding/unembedding**: the spec's forms stand — public-input
embedding is a selector matmul (PW-5, verifier weight functional
O(T log V)); tied unembedding is one T x d x V matmul instance with
last-position (3 x V coeffs) vs full-T (T x V) as the statement
choice. At Gemma's V = 262,144 the full-T logits triple is 402M
coefficients [COUNTED: 3 x 512 x 262,144] — the last-position form
is the MVP-2 default at every shape (Section 4). Private-INPUT
embedding (P1/P3) remains the spec's one OPEN gadget; MVP-2 targets
P0/P2 and does not wait on it (unchanged).

## 2. The mapping onto the existing claim machinery

Vocabulary: the machinery as BUILT and measured (UAGB1_PASS_AGG_
REPORT.md, UAGB1_TABLE_DESCENT_REPORT.md, the 21.0 s rig): BF entry
tables (per-layer committed tensors with typed classes), the eight
folded IXF claim instances (mm-gate/up/down, had, rq-g/u/h/d) with
stacked zero-check tables, the BK layer (10 per-table folded masked
descent pairs serving LookupAt + RangeLookup), pins/public claims,
and the two per-group lattice eval proofs (E-O2-BB: one opening per
group).

### 2.1 What is just MORE of the same (and should dominate)

| new op | lands as | precedent |
|---|---|---|
| QKV, Wo, unembed matmuls | 3-4 more folded mm-* instances (stacked over layers exactly like mm-gate) | mm-gate/up/down |
| scores, PV | 2 more folded mm-* instances with head index variables + the public GQA/MQA map in the weights | the stacked-index forms + M125's zero-extended eq weights |
| SS / E-sum / zsel-sum row sums | thin matmul instances (ones or mask weights) | the thin/ones forms |
| all requant edges | more columns in the folded rq-* zero-check families; per-head/channel shifts = the public coefficient MLE indexed beyond l | BG's rq family with c~(l) = 2^{s_l} |
| xsq, Dsq self-Hadamards, F-hit, the two DIV zero-checks, RoPE rotation checks | more folded ZC3/deg-2 instances | had (CR-7 class) |
| residual adds, d-pin, isqrt pins, limb recompositions | PIN entries (count-invariant per family) | the existing pin layer |
| exp lookup | 1-2 more BK descent pairs (member columns per layer, the fused (d,E) pair) — the silu-m3/m4 pattern with more members | silu-m3/m4 pairs |
| new range widths w1/w10/w11/w14/w18 (+w8/w9 joins) | more BK pairs / more columns in existing pairs | nrw-88, rem-w5..w10 |
| weights Wq/Wk/Wv/Wo, gammas | join T_W (the stacked weight group; W-C two-proof layout unchanged) | the weight group |

That table is ~95% of the extension by committed volume [COUNTED
from Section 3's census: matmul+requant+lookup/range columns
dominate; the genuinely new wiring below carries < 5% of the
volume]. The pass fold dispositions are the spec's Section 4.3 table
— every family folds, with the one caveat that per-layer exp members
make the table side l-indexed (priced there, unchanged).

### 2.2 The C5 lookup layer, reused

The exp pair is a LookupAt fused pair exactly as SiLU: witness side
= the (d, E) columns at score volume, table side = the 256-row
member with per-layer (or per-head, under C2 vectors) member keying.
The BK structure already handles multiple members per family
(silu-m3 x10 + silu-m4 x2 at 125M); exp at 125M is 12 members — the
same shape, more of it. The new range widths ride the parametric
registry (AT-O5) and the BK pair-per-width structure (BG-F1's
finding made this per-width split the BUILT design already — the
attention widths just add pairs). Instancing gates carry over: the
LKP-2 characteristic ceiling and the K9 2^25 cap force per-layer
instancing at T = 512 and per-layer-per-head-group at T >= 2048
(spec AT-O11); at the 8B-class full layer the stacked zero-check
tables hit 2^28-2^29 — the SAME W-1 column-window fix lane W is
building for MVP-1, applied to more instances [no new mechanism].

### 2.3 What is genuinely NEW, and the soundness obligation each carries

None of these is a new claim FAMILY; each is new public-weight
wiring or a new coupling of existing facts, and each carries a named
obligation with a REJECT battery:

1. **The softmax row-normalization coupling** (the one construction
   with no FFN precedent): four fact groups on one transcript —
   dominance (range), attainment (w1 + row-sum + z o d = 0), the exp
   lookup, the division relation with committed divisor + off-support
   pin. Obligation: the COUPLING is what makes m and P unique
   ([PROVEN] in the spec, arithmetic only) — the engine obligation is
   that all four land on the same committed tensors under one
   rolling transcript with no ordering freedom (F5 pair), and the
   AT-O8/AT-O9 tamper legs (m +-1, zsel two-hot, off-support P != 0,
   shifted mask) reject at their pre-registered gates. This is THE
   spike (Section 5.3).
2. **PW-1 flip-read** (RoPE route a): reading MLE(q8) at a
   flipped-coordinate point — exact identity, one extra opening
   point. Obligation: the mu-batched multi-point opening serves it
   without a second eval proof (E-O2-BB preserved); F5 ordering
   battery.
3. **PW-2 GQA/MQA map, PW-3 causal/band mask, PW-4 broadcast
   divisor + public constant vectors, PW-5 embedding selector**: all
   public-weight computations in families that exist. Obligation per
   the spec: an F5-pair ordering battery each (AT-O4); for PW-3
   additionally the wrong-mask/shifted-triangle REJECT (AT-O8).
4. **Head/channel-indexed public coefficient MLEs** (C2 shift
   vectors, AM-3): extends BG's layer-coefficient precedent.
   Obligation: the coefficient MLE is read from the STATEMENT (never
   prover-supplied), and a wrong-vector proof rejects at the
   instance's terminal — one battery leg per indexed family.
5. **k_eq_v shared segment** (Gemma global layers): one committed
   tensor, two instance consumers. Obligation: both consumers bind
   to the same segment id in the group map (h0_agg already binds the
   map); a swapped-segment leg rejects.
6. **Per-position public RoPE structure**: route (a) makes it table
   data (freeze rows, drift-loud generator — obligation AT-O6, the
   silu-v2 discipline); route (b) would make it verifier-evaluated
   Toeplitz weights (a new PW obligation, recorded not chosen).
7. **Data-dependent structure — explicitly none committed**: the
   causal/band masks are public; the GQA map is public; zsel is
   witness (attainment freedom under ties only — outputs unique);
   the ONE open data-dependent gadget remains private-input
   embedding (P1/P3, spec AT-O10), out of MVP-2 scope.

### 2.4 The statement-version discipline

MVP-2 is TRANSCRIPT-CHANGING by definition: it is a NEW statement
version behind the selector (the standing tranche rule) — the
FFN-only v4/v5 statements, their freeze rows, and the MVP-1 line
stay buildable and green; the full-layer statement gets its own
digests, batteries, and freeze rows. Nothing in this memo edits the
frozen pass.

## 3. Counts at the three shapes (T = 512)

Method: the coefficient censuses are [COUNTED] by the same
block-by-block construction as ATTENTION_INTEGER_SPEC.md Section 6.1
(the counting script reproduces its 42,879,488/layer at 125M
exactly, all eight blocks); digit rings use an l0 table matching the
recorded engine classes (i8 -> 5, accumulators -> 13-15, weights
sign-binary -> 8, remainders -> 6) and are [MODEL] until the
engine's derive_l0 runs the real inventory; MACs are [COUNTED];
descent leaves use the FFN-anchored leaves/(cols x footprint) ratio
3.42 from the measured 12x512 structure and are [MODEL]. Gemma rows
carry the Section-0 [ASSUMED] global-layer reading. FFN-only
baselines: the 12x512 measured pass and lane R's counted 8B rows;
the Gemma FFN baseline is counted here by the same formulas.

### 3.1 The census

Per PASS (all layers, T = 512); "ext" = the attention extension
(everything Section 1 adds), "FFN" = the FFN-only statement
including its weights:

| quantity | 125M | Mistral-8B | Gemma-12B |
|---|---:|---:|---:|
| ext committed coeffs [COUNTED] | 514.6M | 5.92G | 9.10G |
| FFN committed coeffs [COUNTED] | 201.3M | 8.25G | 12.65G |
| **full / FFN, coeffs** | **x3.56** | **x1.72** | **x1.72** |
| ext witness digit rings [MODEL] | 27.5M | 329.6M | 501.5M |
| FFN witness digit rings | 11.4M [COUNTED, rig] | 494.4M [COUNTED, lane R] | 756.3M [MODEL] |
| **full / FFN, rings** | **x3.42** | **x1.67** | **x1.66** |
| ext matmul MACs [COUNTED] | 14.5G | 756G | 1.21T |
| FFN matmul MACs [COUNTED] | 29.0G | 2.89T | 4.35T |
| **full / FFN, MACs** | **x1.50** | **x1.26** | **x1.28** |
| exp table lookups (score volume) [COUNTED] | 37.7M | 268.4M | 184.5M |
| ext lookup/range fact elements (cols x footprint) [COUNTED] | 415M | 3.72G | 5.52G |
| ext descent leaf elements [MODEL] | 1.42G | 12.7G | 18.9G |
| FFN descent leaf elements | 172M [COUNTED] | 3.42G [COUNTED] | ~5.3G [MODEL] |
| **full / FFN, descent leaves** | **x9.3** | **x4.7** | **x4.6** |

Notes. (i) The Gemma FFN MAC row uses the pass's own 1-MAC
convention (Mistral = 2.89e12 matches lane R); the ledger's "~8.7e12"
for Gemma is the 2-flops-per-MAC convention — flagged so nobody
double-counts. (ii) Gemma's exp lookups are FEWER than Mistral's
despite more layers: 16 heads x T^2 x 40 + 8 x T^2 x 8 vs 32 x T^2
x 32 — head count drives score volume. (iii) Gemma's ext is +54%
over Mistral's driven by the four-norm + QK-norm sites and 48
layers, partially offset by fewer heads and k_eq_v at the global
layers [COUNTED]. (iv) The descent-leaf multiple (x9.3 / x4.7) far
exceeds the witness multiple (x3.4 / x1.7): score-volume range/
lookup columns (8 per layer at H x T^2 footprint) are the whole
story — this is the Stage-A interaction, Section 3.3.

### 3.2 Projected prove/verify against the measured anchors

125M full-LLM 12x512 on the reference rig (8T + RTX 4070 Laptop),
per-phase multiples applied to the 21.0 s attribution [MODEL; driver
in parentheses]:

| phase | FFN-only [MEASURED] | full layer [MODEL] |
|---|---:|---:|
| commit (n0 rings x3.42) | 2.5 s | ~8.6 s |
| prove-group (h cross-garbage ~ n0 x r; r stays at the 64 cap) | 7.1 s | ~24 s |
| descents (leaf elements x9.3) | 6.5 s | ~60 s |
| claim layer (zc volume + mm-table build) | 1.75 s | ~4.5 s |
| transport + CRS (~x2) | 2.7 s | ~5.5 s |
| verify (value rings x3.4) | 1.7 s | ~5.8 s |
| **total** | **21.0 s** | **~105-110 s (x5)** |

The census multiple (x3.56) UNDERSTATES the prove multiple because
the descent phase scales with score-volume lookup columns, not with
committed coefficients. The same table with the range/lookup facts
on lane S's Stage-A machinery (booleanity zero-checks + LogUp-as-
one-sumcheck, measured GO at 9-25x K-mult-equivalents on this box)
[MODEL]: descents ~60 s -> ~5-9 s, total **~50-55 s (x2.5)** — the
Stage-A form flips the full-layer statement from descent-dominated
back to opening-dominated.

Mistral-8B full layer, Mac CPU, applied to lane R's MVP-1 projection
(32x512 ~35-75 min, weight group 60-70% of the wall) [MODEL]:
weight-driven phases x1.24 (attention weight rings), act-driven
commit/opening x2.7, descents x4.7 -> blended **~x2.0 -> ~1.2-2.5 h
prove, verify ~2-4 min**; with Stage A **~x1.5 -> ~50-110 min**.
Gemma-12B full layer: its FFN-only pass is x1.53 Mistral's by rings
[COUNTED], and the full-layer multiple is x1.66 on top -> **~2.6x
the Mistral MVP-1 wall, ~2-4 h Mac CPU class [MODEL]**; same
Stage-A relief factor. (8B-class rows inherit lane R's stated
unknowns: the Mac-throughput [ASSUMED 1.5-2.5x] and the CPU
prove-share bracket. No 8B attention layer has ever been proven;
these are census-scaled projections, labelled as such.)

### 3.3 The Stage-A interaction, stated as a design consequence

Lane S's spike (U_PERF3_SPIKE_REPORT.md, GO/GO) replaces masked
descents for range facts with base-field zero-checks at 9-25x fewer
K-mult-equivalents and 45-55x less wire, and SiLU-class lookups with
LogUp-as-one-sumcheck. The attention extension multiplies EXACTLY
the object Stage A retires: 84 of 96 descent columns at 125M-FFN
were range facts; the attention extension's score-volume columns are
~85% range-class too (only exp is an arbitrary-table lookup). The
consequence for the build plan: **MVP-2's range/lookup facts should
land on the Stage-A zero-check machinery FROM THE START in the new
statement version** (the descent form exists as the oracle at toy
shape only), rather than building the 8B-scale score-volume descents
and then replacing them. This is a sequencing recommendation, not a
freeze move — Section 5 wires it in; Victor's Stage-A protocol-
version ruling (already contemplated by the standing rules) is the
gate.

### 3.4 What T does

Attention's committed volume per layer is 9 x H x T^2 (the score
block) + linear terms; the FFN's is (10f + 4d) x T + 3df. Crossover
T where the attention layer overtakes the FFN layer, by committed
coefficients [COUNTED]: **~163 at 125M, ~733 at Mistral, ~1071 at
Gemma (sliding shape)**. By MACs: ~2,000 / ~16,400 / ~15,800. So at
the contract T = 512 the 125M statement is attention-dominated
(x3.56) while the 8B-class statements are weight/FFN-dominated
(x1.72); at T = 2048 the Mistral full layer is ~x3.4 its FFN
[COUNTED: score block x16, linear x4] and the long-context ceiling
fE + fP <= 29 - log2(T) binds exactly at T = 2048 (spec Section
5.2). **Gemma's sliding windows change the asymptotics**: for 40 of
48 layers the band mask caps score volume at T x min(T, 1024) per
head — beyond T = 1024 those layers grow LINEARLY in T, and only
the 8 global layers keep T^2 [COUNTED structure; AM-6]. At T = 4096
Gemma-full is ~x2.2 its FFN vs Mistral-full ~x8.7 [MODEL] — the
hybrid architecture is materially cheaper to prove at long context,
worth naming as a route-N argument beyond quantization.

## 4. Statement/witness size and memory

### 4.1 Witness store and the KV-shaped intermediates

The extension's w0 flat int8 store (digit rings x 128 B) [MODEL from
the Section 3 rings]: **125M +3.5 GB (FFN 1.46 GB -> ~5 GB);
Mistral +42.2 GB (63.7 -> ~106 GB); Gemma +64.2 GB (96.8 [MODEL] ->
~161 GB)**. The KV-shaped tensors themselves (k8/v8 at T x H_kv d_h)
are small — 0.5-1 MB per layer i8; the memory story is (i) the six-
to-nine score-volume tensors per layer (75.5M coeffs = 75 MB i8 per
Mistral layer, streamable per (layer, head-group) exactly as the
claim windows already slice), and (ii) the descent trees over them
(below). Per-layer/per-phase liveness discipline (lane R's W-8(a)
pattern) extends to the attention intermediates unchanged.

### 4.2 The commitment groups — TWO new gate busts [COUNTED]

The level-0 exact-digit gate (gamma_z <= gamma_max = 2^22.12) caps a
sign-binary (e0 = 1) group at ~376.7M digit rings and an e0 = 2
group at ~94.2M (lane R's W-3 arithmetic, reused):

| group | Mistral-full | Gemma-full | gate cap | verdict |
|---|---:|---:|---:|---|
| weight group (FFN + Wq/Wk/Wv/Wo + gammas) | 436M rings | 666M rings | 376.7M | **BUSTS at both — split k = 2 (Mistral) / k = 2-3 (Gemma). NEW break item X-W12** (MVP-1's 352M passed with 3.5% spare; the attention weights spend it 7x over) |
| act group (FFN + ext activations) | 391M rings | 592M rings | 94.2M | busts — split k ~ 5-6 / 7 (the W-3 mechanism, more of it) |

Consequences: the W-3 layer-range split machinery must generalize to
the WEIGHT group (same code shape, E-O2-BB per group); each extra
group costs ~185 KB artifact and one more eval proof [COUNTED from
the per-group blocks]. Total groups at Mistral-full ~7-8, Gemma-full
~9-10.

### 4.3 What the C2 exponent vectors add

Statement data only [COUNTED]: per Mistral layer, d-axis vectors at
xn/o/ao/xres (~4 x 4096 x 1 B) + head-axis vectors (~80 B) ~ 17 KB/
layer -> ~0.5 MB/pass worst case (every site per-channel), bytes not
witness; the degenerate constant-vector sites cost their present one
exponent each. The exp member registry grows with distinct (eS, d_h)
values: 32 members (per-layer) to ~256+ (per-head) at Mistral — each
member is a frozen 256-row table (512 B-class) + a registry row;
per-head membership multiplies BK member columns (or Stage-A LogUp
table columns) accordingly [priced as C5 instancing, small].

### 4.4 Artifact projections [MODEL]

125M full-LLM P0: the spec's Section 6.3 arithmetic (~2.6 MiB-class,
~0.83x the 12-layer Tier-N envelope) adjusted +9% for BK-F1's
honest buildable-form overprice -> **~2.8 MiB-class**; Stage-A form
~1.0-1.3 MiB (descent lines -> zero-check/LogUp wire at the lane-S
measured 45-55x wire reduction on the range share). Mistral-full P0:
MVP-1's 1.94 MB + new descent pairs (~1.2-1.5 MB) + instances/pins
(~0.3 MB) + ~5-6 extra group blocks (~1.0-1.1 MB) -> **~4.4-4.9
MB**; P3 adds per-masked-floor surcharges (~0.55 MB each, now per
weight-group split) -> **~5.5-6.5 MB class**. Gemma-full P0 ~5.5-6
MB [MODEL]. All of these stand OUTSIDE the frozen FFN-scoped tiers —
the spec's Section 6.4 contract finding extends: **the full-LLM
statement needs its own contract tier row, and the number to
propose at the MVP-2 close is <= 8 MiB P3 per pass as-built /
<= 3 MiB with Stage A [MODEL, both levers unpriced in]** — priced
here so the eventual FINAL freezes against counted lines, not
elastic ones (the H-05 discipline).

### 4.5 Memory feasibility per box [MODEL]

125M full-LLM: WSL-box runnable with care — the score-volume descent
pairs peak at 1.75U ~ 8-11 GB (w18/exp pairs at 2^24-leaf trees),
one pair at a time as today, pressing but inside 15 GB; the Mac is
unconstrained. Mistral-full as-built: MVP-1's ~184 GB peak (with
W-8(a)) + ext w0 42 GB + score-volume pairs (~120 GB-class peak
pair, same class as nrw-88) -> **~260-300 GB — DOES NOT FIT the
Mac's 256 GB**. With Stage A (descent trees gone) the peak returns
to the ~145-190 GB class — **at the 8B-class full layer, Stage A
(or a per-layer streamed descent build, a tranche of its own) is
REQUIRED for memory, independent of the clock argument** — the
sharpest single planning fact in this memo. Gemma-full lands
~1.5x Mistral-full on every memory line.

## 5. The MVP-2 build plan

Standing constraints: MVP-2 is a new statement version behind a
selector (Section 2.4); the default path stays byte-identical
(freeze rows, diff-battery); attention lands at 125M FIRST (the
CONTINUATION Phase 4 ordering — never a first-contact at 8B); the
box discipline of the ledger applies (heavy runs queued, quiesced
walls only when the box allows).

### 5.1 Rungs, in order

- **X0 — the spike X-S1** (Section 5.3; WSL, 2-4 d, no freeze move).
  GATE: all REJECT legs land; claims bit-equal the Python reference.
- **X1 — entry classes + PW wirings at toy shape** (WSL CODE, ~1-2
  weeks lane-time): the ~66 new per-layer entries (or ~60 fused,
  AT-O2 decides) in the BF typing, PW-1..PW-4 public-weight
  builders, the folded instance families extended (scores/pv head
  index; rq coefficient MLEs head-indexed), exp + range members in
  the registry (AT-O5/O6 freezes — Victor), at T = 16, 1-2 heads,
  synthetic witness. GATE: F5 batteries per PW; AT-O8/O9 tamper
  legs; freeze rows unmoved on the default path.
- **X2 — AT-O1 as a C4 gate run at 125M** (frugal venv RUN, days):
  extend the m125/m8b calibration walk with attention capture; the
  C4 verdict JSON over attention classes (violations = 0 required;
  quality delta vs the model's own reference); freeze the per-layer
  (or per-head) exponent table + the 12 exp members. Kills
  [SYNTHETIC] everywhere. GATE: the C4 gate itself (AM-10).
- **X3 — one full layer at 125M, then the 12-layer full-LLM pass**
  (WSL RUN): layer-0 at 1x512 proved + verified against the numpy
  reference walk (the m8b_verify pattern: digests bind the exact
  tensors the chain used), then 12x512 = **the MVP-2 125M
  milestone**; walls recorded with labels ([MODEL] expectation
  ~105 s as-built / ~55 s Stage-A form, Section 3.2). GATE: accept
  = true end to end; artifact counted vs Section 4.4; battery green.
- **X4 — the 8B-class stack** (Mac RUN, after MVP-1 lands): needs
  X-W12 (weight-group split), the act-group split extension, W-1
  windows on the score-volume zc tables, and the Section 4.5 memory
  ruling (Stage A vs streamed descents). Gemma-full additionally
  needs lane Y's adapter facts (global-layer head map, layer_scalar
  semantics, rope bases) resolved from [ASSUMED] to [COUNTED].

Lanes (round-shaped, one owner per file set): engine lane (X1's
entries/instances), tables lane (registry members + freeze rows),
calibration lane (X2), batteries lane (AT-O4/O8/O9 + the new
X-W12/window legs). The AT-O2 fused-accumulator decision (-13.8%
commit volume, unverified wave interaction) is a named early fork —
take it at X1 where it is cheap, or ship unfused.

### 5.2 What needs Victor

1. The **AM-1..AM-10 amendment set** (Section 6.3) — AM-1 touches
   TARGET_CONTRACT §2 v3 wording (with the C1-C6 ruling, same
   sitting); AM-2/AM-3 are C5/C2 clarifications inside the contract
   draft; AM-4..AM-9 are spec-side.
2. **Table freezes**: exp-neg members (after X2 names them),
   rope-cs tables, the parametric range widths, gelu-tanh (Gemma),
   silu W-6 (pending, unchanged) — each a registry ruling, never a
   protocol change (C5's promise).
3. **The Stage-A sequencing ruling** (Section 3.3): MVP-2's
   range/lookup facts on the zero-check machinery from the start
   (recommended), with the descent form as toy-shape oracle only.
4. **The contract tier row** for the full-LLM statement (Section
   4.4 proposal) at the MVP-2 close — the spec's 6.4 finding, now
   with 8B-class counted lines attached.
5. Gemma verification items to lane Y (global-head map,
   layer_scalar, rope bases, softcap site) before any Gemma-full
   counting is promoted from [ASSUMED].

### 5.3 THE ONE SPIKE — X-S1, the integer softmax chain through the real machinery

The single construction with no FFN precedent is the softmax
coupling (Section 2.3 item 1). X-S1 proves ONE committed (head, row)
softmax chain end to end through the AS-BUILT claim machinery at
small scale (T = 512 row, synthetic then 125M-calibrated data):
committed s8 row -> m, d, zsel (pins + w8/w1 range facts + the
attainment zero-check) -> E via a REAL LookupAt fused pair with a
frozen exp member -> Sum by masked thin sumcheck -> P/rho/sigma by
the division zero-check with broadcast divisor + off-support pin —
one rolling transcript, PW-3/PW-4 wired for real. Acceptance: (a)
honest ACCEPT with every fact green; (b) the AT-O8/AT-O9 battery —
m overstated/understated, zsel two-hot/off-support, off-support
P != 0, shifted mask, wrong exp member — each REJECTS at its
pre-registered gate; (c) the committed chain's values bit-equal
scripts/attention_spec_spike.py's reference on the same seed; (d) a
Stage-A leg: the same row's range facts through lane S's zc_range
form, claims equal the descent oracle (the S2 pattern applied to
attention's widths). ~2-4 days, additive code only, no freeze move.
De-risks in one stroke: the fact coupling, the two hardest PW
wirings, the exp member registry mechanics, and the Stage-A
sequencing recommendation.

## 6. Design choices and limitations (the numbered record)

### 6.1 Design choices, each with its why

- **X-D1 — the spec is adopted, not re-derived.** ATTENTION_INTEGER_
  SPEC.md's semantics carry a green 18/18 machine-checked spike and
  a [PROVEN]-graded gadget set; this memo maps, counts, and amends —
  it does not reopen the integerization. Cost: the spec's 125M-
  centric conventions need the AM list for Gemma-class models.
- **X-D2 — softmax by exact row-max + exp table + division relation**
  (the spec's form), NOT shift-normalized sums or reciprocal tables.
  Why: exactness with two range facts and one zero-check per
  normalization; no variable shifts; the C1 chain form holds with
  one amendment (AM-1). Evidence: the spike's 734 range facts + the
  uniqueness argument.
- **X-D3 — RoPE as proved elementwise rotations (route a)**, the
  fold-into-scores form recorded as a counted option. Why: spike-
  validated, fRo = 7 at every shape, and route (b) saves only ~4%
  while changing the declared function and busting q31 headroom at
  d_h >= 256 (Section 1.5's arithmetic).
- **X-D4 — masks, GQA/MQA, k_eq_v as PUBLIC structure** — zero
  committed mask/selector tensors anywhere in attention. Why: every
  data-independent structure a verifier can recompute should live in
  public weights (the house PW pattern); the witness carries only
  data.
- **X-D5 — C2 axes: head-axis for q/k/s, d-axis for stream-shaped
  sites** (AM-3). Why: matches the physical outlier structure
  (per-head score scales; per-channel stream outliers) and reuses
  the layer-coefficient-MLE precedent — vectors without new
  machinery. Cost: per-head exp members multiply C5 rows (priced,
  small).
- **X-D6 — last-position unembedding as the MVP-2 default.** Why:
  the full-T logits triple is the single largest object at every
  shape (402M coeffs at Gemma) and the generation-relevant form is
  last-position; full-T stays a declared statement choice.
- **X-D7 — Stage-A-first for the new range/lookup volume** (Section
  3.3). Why: the extension's descent leaves (x4.7-9.3) multiply the
  machinery lane S measured 9-25x replaceable; at 8B-class the
  as-built form does not fit the Mac at all (Section 4.5). The
  descent form remains the toy-shape oracle — differential
  discipline preserved.
- **X-D8 — MVP-2 lands at 125M first** (X3 before X4). Why: every
  layer of new wiring gets its REJECT batteries and its reference-
  walk oracle at a shape where a full pass costs seconds-to-minutes,
  exactly the m8b lesson (validate the pipeline at 125M before any
  Mac hour is spent).
- **X-D9 — the full-layer statement is a new version behind the
  selector**; the FFN-only line never moves. Why: the tranche's
  standing freeze discipline; MVP-1's headline must remain
  reproducible forever.

### 6.2 Limitations, stated plainly

- **X-L1 — every attention exponent is [SYNTHETIC] today.** The
  entire width/member story rides study-shaped synthetic data until
  X2 (AT-O1/C4) runs on real checkpoints. The Mistral outlier
  finding says attention-side calibration at 8B-class may force
  per-head vectors, wider classes, or route-N — the C4 gate decides,
  mechanically.
- **X-L2 — the 8B-class rows are census-scaled projections.** No
  attention op has ever run in this engine; the Section 3.2 numbers
  inherit lane R's Mac-throughput [ASSUMED] band and add the
  descent-leaf [MODEL] ratio. First measured rung: X3.
- **X-L3 — Gemma's global-layer reading is [ASSUMED]** (8 q-heads x
  512, layer_scalar semantics, rope bases, softcap site) until lane
  Y reads the HF modeling source; the Gemma columns move if the
  reading is wrong (the sliding-layer columns and both other shapes
  do not).
- **X-L4 — l0/digit-ring and descent-leaf lines are [MODEL]** (the
  l0 table and the 3.42 leaves ratio approximate the engine's own
  planners); the engine's derive_l0/plan_pair_trees on the real
  inventory is the authority, wired as an X1 gate (the m8b
  `--check` pattern).
- **X-L5 — T >= 2048 has known walls**: the fE + fP <= 29 - log2 T
  resolution ceiling, per-head-group instancing (AT-O11), and score
  volume x16 — all recorded in the spec, none binding at the
  contract T = 512; Gemma's band masks soften the third beyond
  T = 1024 (Section 3.4).
- **X-L6 — P1/P3 attention inherits the open embedding gadget** and
  additionally needs the T_blind instance-masking story extended
  over the new instance families before any full-ZK full-layer
  claim; MVP-2 is scoped P0/P2 (the same honest gap the FFN pass
  carries).
- **X-L7 — the artifact/tier lines are pre-freeze [MODEL]** (BK-F1
  taught that buildable forms price ~9% over kel fits; group-split
  counts depend on the real ring inventories); the tier proposal in
  Section 4.4 is a pricing target, not a budget, until the MVP-2
  close counts it against a running pass.

### 6.3 The proposed amendment set (consolidated; none silently assumed)

| id | target | amendment |
|---|---|---|
| AM-1 | TARGET_CONTRACT §2 v3 (C1) | admit the committed-divisor floor-division relation (quotient x divisor + two-sided-ranged remainder, degree-<=3 zero-check) as a chain form alongside 2^shift requant — the spec §2.9 construction, [PROVEN] |
| AM-2 | C5 | registry key gains params (d_h, cap, ...); non-int8 output widths admitted (exp-neg u8 -> u(fE+1)); member = (function, e_in, e_out, params) |
| AM-3 | C2 + spec §0 | declared channel axes for attention sites (head axis q/k/qr/kr/s; d-axis xn/o/ao/xres); requant shift VECTORS as head/channel-indexed public coefficient MLEs (the BG layer-MLE precedent) |
| AM-4 | spec §2.3 | rope-cs-table-v1 keyed by (T_max, d_h, base, fRo); per-layer-type members (Gemma dual bases); model-bound convention flag |
| AM-5 | spec §2.1/§2.7 | QK-norm site (RMSNorm at row width d_h; Cn exact at d_h 256); the four-norm sandwich's normed-output residual ordering |
| AM-6 | spec §2.4 | PW-3 generalized to public band masks (sliding windows); T <= window degenerates to causal; off-support convention unchanged |
| AM-7 | spec §2.2 | attention_k_eq_v: one committed tensor read by both score and PV instances; MQA = GQA with g(h) = 0 |
| AM-8 | spec (new) | layer_scalar as a declared public fixed-point constant folded into the adjacent requant shift (PoT) or pin constant (else); no witness [pending lane Y semantics] |
| AM-9 | spec §2.8 | softcap at final logits: public post-processing when logits public; C5 tanh-softcap member only for private-logit deployments; clamp REJECTED (not function-preserving) |
| AM-10 | C4 | the qualification gate's classes extend over the attention sites (AT-O1 subsumed as a C4 run; violations = 0 includes score/softmax classes; quality budget measured on the full-layer chain) |

---

*Changelog: 2026-08-25 — first edition (U-PERF3 round 2, lane X):
the MVP-2 attention statement design — op inventory checked against
C1-C6 with the AM-1..AM-10 amendment set; RoPE ruled route (a) with
route (b) counted; C5 members named with signatures; the mapping
onto the built claim machinery (no new claim family at P0/P2; seven
new-wiring items with obligations); counted censuses at 125M /
Mistral-8B / Gemma-12B (full/FFN x3.56 / x1.72 / x1.72 witness,
x1.50 / x1.26 / x1.28 MACs, descent leaves x9.3 / x4.7 / x4.6) with
prove projections against the 21.0 s and Mac anchors; the T story
(crossovers 163 / 733 / 1071; Gemma's band masks linearize 40/48
layers beyond T = 1024); the X-W12 weight-group gate bust and the
Stage-A memory-feasibility finding at 8B-class; the X0-X4 build plan
with spike X-S1 (the softmax chain through the real machinery); the
numbered X-D1..D9 / X-L1..L7 record.*
