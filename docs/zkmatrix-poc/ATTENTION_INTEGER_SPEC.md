# Attention Integer Spec: Softmax, RMSNorm, RoPE, Residuals and Embedding as Frozen Fixed-Point Gadget Chains

Status: DESIGN-ROUND DELIVERABLE (U-PERF tranche, lane PD,
2026-08-11; M4 house pattern — paper + Python spike, no engine
files). Every numbered semantic claim, width row, table-generation
rule and derivation identity in this document is machine-checked by
`scripts/attention_spec_spike.py` (stdlib + numpy, seeded 20260811,
18/18 OK, 734 range facts + 522 derivation identities across three
input draws, ~70 s single run; output recorded in Section 9). Cost
lines are [MODEL] with the arithmetic shown, anchored on
M125_PASS_REPORT.md's measured 12-layer rig and the
AGGREGATION_FOLDING_DESIGN.md F-IF1/kel byte machinery.

This closes the contract's declared specification gap
(TARGET_CONTRACT.md Section 1: "softmax/normalization do not even
have a frozen integer specification yet") at the level a build round
can consume: exact per-op fixed-point semantics, gadget assignments
from the EXISTING claim families, the claim-DAG extension of the
12-layer pass statement, derived widths at the 125M and 7B/8B
shapes, and the U-AT-B1 obligation queue. Companions:
TARGET_CONTRACT.md Sections 1-2 (the integer discipline extended
here), TRANSFORMER_PROOF_PLAN.md Section 2 (the operation taxonomy
this fills in), M4_LOOKUP_DESIGN.md (the lookup class the exp table
rides), M4_ACTIVATION_DESIGN.md (why lookup won),
M125_CALIBRATION_STUDY.md + results/m125_int8_calibration.json (the
real ranges), M125_PASS_REPORT.md (the as-built pass statement and
its measured cost anchors), AGGREGATION_FOLDING_DESIGN.md F-IF1
(the fold interface Section 4.3 extends), Q4_LEMMAS.md (grading
conventions).

Grading: **[PROVEN]** / **[MODEL]** / **[OBLIGATION]** /
**[SKETCH]** per SOUNDNESS_REFERENCE.md; **[SPIKE]** marks a claim
the spike asserts mechanically; **[SYNTHETIC]** marks numbers
derived from calibration-shaped synthetic data (real-checkpoint
attention calibration is obligation AT-O1).

**The verdict in one paragraph.** Every operation of the full
transformer layer — RMSNorm, QKV with GQA, RoPE, causal scores,
softmax, PV, output projection, both residual adds, embedding and
unembedding — compiles to the EXISTING gadget families (matmul-class
sumchecks, degree-<=3 zero-checks, linear MLE pins, LookupAt,
RangeLookup) with **no new claim family for modes P0/P2**. The two
research-shaped constraints land as: (1) softmax's exp is
range-reduced EXACTLY — a proven int8 requant of the raw scores
(resolution) followed by exact row-max subtraction (offset), with
dominance = one [0,2^8) range fact and attainment = a binary argmax
selector — and consumed by a 256-row frozen table family
(`exp-neg-table-v1`) in the M4 lookup class with the 1/sqrt(d_h)
attention scaling folded into the table generation rule; (2) both
normalizations (softmax row-normalize, RMSNorm) are floor-DIVISION
RELATION facts — quotient*divisor + remainder identities proven by
one degree-3 zero-check with a broadcast divisor plus two-sided
remainder range facts — the reciprocal-class fact expressed entirely
in the range/lookup vocabulary; RMSNorm's square root is the isqrt
fact pair D^2 <= SS + Ceps < (D+1)^2 (two range facts + one
self-Hadamard). The honest costs [MODEL]: the attention extension
adds ~42.9M committed coefficients per 125M layer (~3.5x the
FFN-only layer; two-thirds of it the six T^2 score-volume tensors),
~3.5x the as-built per-layer prove time, and ~+1.2 MB to the folded
12-layer P0 pass artifact (~2.6 MiB total, inside the 12 x 256 KiB
Tier-N envelope at ~0.83x); at 8B the full-LLM pass does NOT fit
under the Amendment A1 Tier Z line — that line is scoped "per
32-layer FFN pass," and a full-LLM tier must be frozen at a future
close (Section 6.4). The one genuinely OPEN gadget is
private-INPUT embedding (modes P1/P3), stated sharply in Section
2.8 with both candidate constructions priced.

## PROGRESS

- [x] Section 0: conventions, shapes, calibration inputs
- [x] Section 1: the extended statement
- [x] Section 2: per-op integer specifications (2.1-2.9)
- [x] Section 3: gadget assignment table + new-wiring inventory
- [x] Section 4: claim-DAG extension + F-IF1 fold dispositions
- [x] Section 5: width tables (125M + 8B), spike-checked
- [x] Section 6: cost derivations [MODEL]
- [x] Section 7: ranked risks
- [x] Section 8: build-round obligations (the U-AT-B1 queue)
- [x] Section 9: spike output (recorded)

## 0. Conventions, shapes, calibration inputs

Inherited verbatim from TARGET_CONTRACT.md Section 2 and the M125
study's convention pins, none renegotiated:

- int8 symmetric **[-127, 127]** (forced by the contract's own
  27-bit row; spike re-checks the 27 @ 4096 / 29 @ 11008
  reproduction);
- power-of-two scales, `value_real = value_int * 2^e`, exponents
  per tensor per layer, max-calibrated (smallest e with
  absmax <= 127 * 2^e);
- floor requantization `x = 2^shift * y + r` with `r` PROVEN in
  `[0, 2^shift)` (the as-written form; the study's public pre-add
  round-to-nearest note applies unchanged to every requant edge
  below and is a statement-level choice, not respecified here);
- narrowing to a declared width only by a proven range fact; an
  uncalibrated tensor FAILS its facts — intended behavior;
- all committed values are q31 centered residues; every zero-check
  term must satisfy the non-wrap bound |v| < q/2 ~ 2^30 - 200
  (checked per row in Section 5).

**Shapes.** Primary: frugal-lm 125M (n_layers 12, d = 768, H = 12
query heads, H_kv = 4 (GQA group 3), d_h = 64, mlp 2048, vocab
49,152, tied embeddings, rope_base 10000.0, RMSNorm eps 1e-5,
non-interleaved RoPE — mlx `traditional=False`, no biases anywhere),
T = 512 contract workload. Reference derived alongside [MODEL]: the
8B class (d = 4096, H = 32, H_kv = 8 (group 4), d_h = 128, f =
14336, vocab ~128k), T = 512 primary / T = 2048 flagged rows.

**Calibration inputs.** FFN-side ranges are REAL
(M125_CALIBRATION_STUDY.md; the spike loads
results/m125_int8_calibration.json and shapes its synthetic
residual stream to the measured outlier structure — bulk sigma ~1.1
plus a planted heavy tail, absmax 12-20, p999 ~4-9). Attention-side
ranges (residual stream, q/k/v, raw scores, attention output) were
NOT captured by the study — attention ran fp32 there. Every
attention exponent in this document is therefore [SYNTHETIC]
(derived by the spike's max-calibration on study-shaped data;
layer-0 example: eXn = -3, eQ = eK = -4, eS = -1, eAo = -5,
eR1 = -2) and the real-checkpoint capture is obligation **AT-O1**.
The semantics, widths and facts below do not depend on the exact
exponents; the exponent TABLE is statement metadata exactly as the
study's Section 3 table is.

## 1. The extended statement

The M125 v4 pass statement proves 12 disconnected FFN instances:
"each layer takes a fresh committed X … the inter-layer edge
(RMSNorm + residual) is not integer-specified and is NOT wired"
(M125_PASS_REPORT.md Section 0). This spec wires the layers. The
full-LLM statement is:

> The committed residual stream X_0 is the embedding of the
> declared input tokens under the committed embedding table; for
> each layer l: X_{l+1} = X_l + FFN_l(mlp_norm_l(X_l +
> ATTN_l(attn_norm_l(X_l)))) under the exact fixed-point semantics
> of Section 2, where ATTN_l is causal GQA attention with RoPE and
> the declared per-layer quantization; the declared output is the
> requantized unembedding of final_norm(X_12) (full-T or
> last-position form).

Every intermediate is committed (or explicitly DERIVED — readable
by public weights from committed tensors, Section 3); every
nonlinear step is a table or division fact; every narrowing is a
range fact. The statement's model-identity digest additionally
binds: the per-layer exponent/shift table, the `exp-neg-table-v1`
member registry, the `rope-cs-table-v1` public tables, the causal
mask convention, and the (fE, fP, tn, Cn, Ceps) constants of
Section 2 — proofs are not transplantable across any of them (the
M3 gap-5 rule, unchanged).

## 2. Per-op integer specifications

Notation: committed tensors in code face; DERIVED means "no
commitment — a public-weight linear read of committed tensors
inside a pin or zero-check" (Section 3's PW inventory). All facts
named here appear in the Section 4 DAG table.

### 2.1 RMSNorm (attn_norm, mlp_norm, final_norm)

Real function: y = x / sqrt(mean(x^2) + eps) * gamma. Integer spec,
per site (input `x8` int8 at 2^eX, gamma `G` int8 at 2^eG, output
`y8` int8 at 2^eY; d = row width):

    xsq[t,i] = x8[t,i]^2                    (Hadamard self-product)
    SS[t]    = sum_i xsq[t,i]               (ones-matmul row sum)
    SSe[t]   = SS[t] + Ceps,  Ceps = max(1, round_half_up(eps*d*2^-2eX))
    D[t]     = isqrt(SSe[t]), proven by the ISQRT FACT PAIR:
                 a1[t] = SSe[t] - D[t]^2      in [0, 2^14)   (range fact)
                 a2[t] = 2*D[t] - a1[t]       in [0, 2^14)   (range fact)
               with Dsq = D o D (self-Hadamard) and a1, a2 tied by
               linear pins. a1 >= 0 and a2 >= 0 together say
               D^2 <= SSe <= D^2 + 2D = (D+1)^2 - 1, i.e. D is THE
               integer square root — exact and unique. [PROVEN
               arithmetic; SPIKE]
    (tn, Cn) per site, PUBLIC, by the WINDOW RULE: tn = smallest
               integer with Cn = round_half_up(2^(tn+eG-eY) *
               sqrt(d)) >= 2^10  (lands Cn in [2^10, 2^11];
               relative rounding error of the declared constant
               <= 2^-11, below int8 noise).
    y8[t,i]  = floor( x8[t,i] * G[i] * Cn / (D[t] * 2^tn) )
               proven by the DIVISION RELATION (Section 2.9):
                 x8*G*Cn = y8*(D*2^tn) + rho,  rho in [0, D*2^tn)
               — one degree-3 zero-check
               eq_r * ( y8 o D_bc * 2^tn + rho - Cn * (x8 o G_bc) )
               summed to zero (D broadcast over columns, G broadcast
               over rows — both FREE MLE reads), plus the two-sided
               remainder ranges rho, sigma = D*2^tn - 1 - rho, each
               split into (11, wrho-11)-bit limbs per the Section
               2.9 splitting rule (wrho = 21-22 at 125M).
    y8 narrows to int8 by a [-127,127] range fact (w8 offset code)
               — an uncalibrated norm output FAILS here by design.

Two derivation facts the spike caught and pinned [SPIKE]:

1. **eX cancels.** x8 carries 2^-eX and D carries 2^-eX (D ~
   sqrt(d) * rms / 2^eX), so the Cn rule contains eG and eY ONLY.
   The spike's first run used 2^(tn+eG+eX-eY) and the fp32
   error gate caught the 4x scale error (block error 0.75 -> 0.094
   after the fix) — recorded as the canonical example of why the
   spike must compare against fp32, not merely check facts (all
   range facts PASSED under the wrong constant).
2. **8B bonus: Cn is exact.** sqrt(4096) = 64, so at d = 4096 the
   window rule yields Cn = 2^(tn+eG-eY+6) — a pure-shift EXACT
   constant; the declared function loses zero precision in Cn.
   sqrt(768) is irrational, so the 125M Cn carries the <= 2^-11
   declared rounding (a property of the declared function, not an
   unproven approximation).

**Rejected alternative — the rsqrt TABLE (recorded with
arithmetic).** A direct reciprocal-square-root table needs mantissa
normalization: rsqrt with D in a 12-13-bit domain forces either a
2^12-row per-shape table on a range-REDUCED radicand SSe = 4^k * u,
u in [2^(2b-2), 2^2b) — and the exactness facts for the
variable-power reduction (committed k, pow2(k) certification, a
variable shift in every downstream identity) cost more pins and
range facts than the isqrt pair — or an unnormalized reciprocal
table round(2^fr / D), whose relative error blows up to ~33% at
small quotients (round(2^13/5461) = 2 vs 1.5). The division-relation
form needs NO table, no variable shifts, two 14-bit-class range
facts and one self-Hadamard on T-length row vectors. The same
argument disposes of a reciprocal table for the softmax denominator
(Sum has an 18-19-bit domain). The exp table (Section 2.5) is the
only table this spec adds; the "rsqrt-class table" is specified
here only as the recorded loser.

### 2.2 QKV projections and GQA layout

    Qacc = Xn8 @ Wq   (T x d x H*d_h;    inner d)
    Kacc = Xn8 @ Wk   (T x d x Hkv*d_h)
    Vacc = Xn8 @ Wv   (T x d x Hkv*d_h)

Standard committed-x-committed matmul claims (the M125 Thaler
degree-2 sumcheck family), inner-768 accumulators 25-bit signed
(27-bit at 8B inner 4096), followed by standard requant edges to
int8 `q8/k8/v8` at calibrated eQ/eK/eV with remainder + narrowing
facts. No biases (frugal-lm recipe). The fused single-matmul QKV
variant (one T x d x (H+2Hkv)*d_h instance) is a statement-level
packing choice with identical semantics; not taken here (three
instances match the checkpoint's module layout).

GQA is a LAYOUT fact, not an operation: `k8`/`v8` have Hkv * d_h
columns; query head h reads kv head g(h) = floor(h / (H/Hkv)) —
g(h) = h//3 at 125M, h//4 at 8B. The map enters as public weight
computation in Sections 2.4/2.6 (PW-2), never as a committed
gather.

### 2.3 RoPE

Non-interleaved convention (mlx `traditional=False`): within each
head, position t rotates the pair (x[i], x[i + d_h/2]) by angle
t * theta_i, theta_i = base^(-2i/d_h), i in [0, d_h/2).

**Public tables** (`rope-cs-table-v1`; statement constants, NOT
committed witness):

    c[t,i] = round_half_up( cos(t * theta_i) * 2^fRo )
    s[t,i] = round_half_up( sin(t * theta_i) * 2^fRo ),   fRo = 7

Values lie in [-2^7, 2^7] (128 attained at angle 0 — public
constants are not bound by the committed [-127,127] convention).
Generation rule + digest per the silu-v2 discipline: IEEE-754 f64
generation exists to make platform drift LOUD; the FROZEN BYTES
define the table (freeze rows, obligation AT-O6). T_max, d_h, base
and fRo sit in the digested header; 125M table mass 2 x 512 x 32
int8-class values (32 KiB of statement constants).

**Relation** (per rotated tensor; Q shown, K identical at Hkv):

    QRacc[t,h,i]        = c[t,i]*q8[t,h,i]        - s[t,i]*q8[t,h,i+dh/2]
    QRacc[t,h,i+dh/2]   = s[t,i]*q8[t,h,i]        + c[t,i]*q8[t,h,i+dh/2]

|QRacc| <= 2 * 2^fRo * 127 = 32,512 — 16-bit signed [SPIKE, bound
attained by the all-extreme witness]. Proven as ONE degree-2
zero-check per tensor: sum_b eq(r,b) * ( QRacc(b) - cW(b)*q8(b) -
sW(b)*q8(flip b) ) = 0, where cW/sW are the sign-folded public
weight tables and `flip` toggles the TOP bit of the within-head
column index — for multilinear extensions, reading `q8` at the
flipped index is evaluating MLE(q8) at the point with that
coordinate replaced by 1 - r_c, an EXACT identity costing one extra
MLE opening point on q8 (mu-batching already serves multi-point
openings). New public-weight computation, existing claim family
(PW-1). Requant by shift fRo returns the rotated tensor to the int8
grid at the SAME exponent as its input (rotation is
norm-preserving; the narrowing fact catches the +-1-code overshoot
case if calibration set eQr = eQ, and the statement may declare
eQr = eQ + 1 where calibration demands — [SYNTHETIC] data never
tripped it across three draws).

### 2.4 Scores, the sqrt(d_h) fold, and the causal mask

    Sacc[h,t,t'] = sum_j qr8[t,h,j] * kr8[t',g(h),j]

ONE stacked matmul-class sumcheck over (h, t, j, t') — the head
index is lambda_h = log2(H) extra index variables (F-IF1's index-
extension vocabulary applied INSIDE a layer); the K-side weights
compose the public GQA map g(h) (PW-2; same class as the down-
matmul's zero-extended eq weights in the M125 rig). Accumulator:
inner d_h = 64 -> 21-bit signed (attained; 22-bit at 8B d_h = 128)
— the SMALLEST accumulator in the statement.

**Requant = range-reduction stage 1 (resolution).** s8 =
floor(Sacc / 2^shS) + fact pair, shS = eS - eQr - eKr >= 0, eS
per layer max-calibrated [SYNTHETIC at present]. s8 carries the RAW
(un-divided) score at scale 2^eS: the 1/sqrt(d_h) softmax scaling
is NOT applied here — it folds EXACTLY into the exp table's decay
constant (Section 2.5), because at d_h = 64, 1/sqrt(d_h) = 2^-3
(exact) and at d_h = 128 it is irrational and belongs in the
table's declared generation formula, never in a shift.

**The causal mask is a DERIVED read, not a committed tensor.**
Define (PW-3):

    sM[h,t,t'] = s8[h,t,t']  if t' <= t   (support)
               = -127        if t' > t    (off-support)

sM is never committed: every fact that consumes it reads
mask o s8 - 127 * maskC through public mask weights inside the
respective pin/zero-check (mask = lower-triangular ones, maskC its
complement — both public). Off-support positions therefore carry
the DOMAIN MINIMUM, which makes every softmax fact below hold on
the full T x T rectangle with no ragged instancing and no masked
leaf maps in the lookup.

### 2.5 Softmax: exact row-max, the exp table family, masked sum, division

**Row max (range-reduction stage 2, offset).** Committed per-row
`m[h,t]` (int8 class) and the ATTAINMENT SELECTOR `zsel[h,t,t']`
(binary). Facts:

    d[h,t,t'] = m[h,t] - sM[h,t,t']          (linear pin, PW-3 read)
    F-dom:   d in [0, 2^8)                    (RangeLookup w8)
    F-bin:   zsel in {0,1}                    (RangeLookup w1)
    F-one:   sum_{t'} zsel[h,t,t'] = 1        (thin deg-1 sumcheck,
                                               claimed value 1)
    F-hit:   sum eq * zsel * d = 0            (deg-3 zero-check)

[PROVEN arithmetic; SPIKE]: F-dom's lower edge IS dominance (m >=
every sM entry; overstating m by even 1 leaves every d >= 1 and
F-hit + F-one then force a zsel position with d = 0 — contradiction;
understating m makes some d negative — F-dom fails). Hence m is THE
exact row max of sM. d <= 254 < 2^8 is STRUCTURAL (two int8 values),
so F-dom can never fail at its top: the 256-row table needs no
clamp and no out-of-domain case. Off-support d = m + 127 in
[0, 254] — also structural. zsel is any witness of attainment (ties
make it non-unique); m and every OUTPUT below are uniquely
determined regardless — the one deliberately non-deterministic aux
tensor, recorded here.

**The exp table family** (`exp-neg-table-v1`; the M4 lookup class,
per-scale members exactly like `silu-int8-table-v2`):

    E[h,t,t'] = ExpT_(eS,d_h)[ d[h,t,t'] ]        (LookupAt, fused
                                                   pair (d, E))
    ExpT[dd]  = round_half_up( 2^fE * exp( -dd * lam ) ),
                lam = 2^eS / sqrt(d_h),   dd in [0, 255],
                fE = 9  (recommended at T = 512; Section 5's
                         resolution rule)

Header (canonical JSON, digested; spike-verified deterministic and
member-separating):

    {"function":"exp-neg-table-v1",
     "input":{"width":8,"signed":false},
     "output":{"width":fE+1,"signed":false,"frac_bits":fE},
     "decay":{"score_scale_exp":ES,"head_dim":DH},
     "rounding":"E = round_half_up(2^frac_bits * exp(-d *
                  2^score_scale_exp / sqrt(head_dim)))",
     "table":[[0,E_0],...,[255,E_255]]}

Structural table properties [SPIKE]: E[0] = 2^fE exactly; outputs
in [0, 2^fE]; monotone nonincreasing. One member per calibrated
(eS, d_h) pair — 12 members at 125M (per layer), 32 at 8B; members
are frozen registry rows with the silu-v2 drift-loud discipline
(AT-O6). The characteristic-ceiling gate (M4 LKP-2, N_inst <=
2^25): per-layer instances hold 12 x 512^2 = 3.15M pairs at 125M
(margin 667x) and 32-head 8.39M at 8B/T512 (256x); at 8B/T2048 the
per-layer instance (134M) BUSTS the gate and instancing drops to
per-layer-per-head-group (16.8M, margin 128x) — the rule M4
Section 4 already anticipated, now bound to a shape (AT-O11).

**The range reduction, stated exactly (the lane's standing
constraint).** The table's argument is d = m - sM where (i) sM is
the proven int8 requantization of the raw score accumulator at the
calibrated per-layer eS (resolution reduction: 21-bit accumulator
-> 8-bit grid, remainder + narrowing facts), and (ii) m is the
proven exact row maximum (offset reduction: argument shifted into
[0, 254] structurally). exp is evaluated ONLY on this reduced
domain; no other reduction, clamp, or escape exists. Underflow is
exact table semantics (entries round to 0 where 2^fE * e^(-d*lam)
< 1/2).

**Masked row sum** (the softmax denominator; PW-3 weights):

    Sum[h,t] = sum_{t' <= t} E[h,t,t']       (thin deg-1 sumcheck
                                              with public mask
                                              weights; NO broadcast
                                              commitment)

Sum >= 2^fE STRUCTURALLY: attainment puts d = 0 somewhere on the
support, and E[0] = 2^fE with all entries >= 0 — the divisor is
never zero, with no extra fact [SPIKE].

**Row normalization = the division relation** (Section 2.9 gadget;
fP = 9):

    P[h,t,t'] = floor( E[h,t,t'] * 2^fP / Sum[h,t] )   on support
              = 0                                       off support

Facts: one degree-3 zero-check with mask weights
eq * mask * (P o Sum_bc + rho - 2^fP * E) = 0 (Sum broadcast over
t' — free row-MLE read, PW-4); remainder pair rho in [0, 2^18) and
sigma = Sum - 1 - rho in [0, 2^18) (single w18 RangeLookups at 125M
— no split needed, 2^18 rows <= N_inst/8); P's width fact [0, 2^10)
(w10); and the OFF-SUPPORT PIN eq * maskC * (P, rho, sigma) = 0
(one public-weight zero-check batching the three tensors) so no
committed aux carries free garbage. P <= 2^fP follows from the
facts (E <= 2^fE <= Sum); row-stochasticity is deliberately NOT
claimed: sum_j P = 2^fP - (sum_j rho_j)/Sum in (2^fP - T, 2^fP]
under floor semantics ([SPIKE]: row masses landed in [282, 512]
against 2^9 = 512 on synthetic layer 0) — the declared function
stands on its division facts, exactly as TRANSFORMER_PROOF_PLAN
Section 1 requires.

### 2.6 PV, head concat, output projection

    Oacc[t,h,j] = sum_{t'} P[h,t,t'] * v8[t',g(h),j]

Stacked matmul-class sumcheck over (h, t, t', j) with the SAME
public GQA map on the V side (PW-2); P is unsigned u(fP+1), V int8:
inner T = 512 accumulator 26-bit signed at fP = 9 (28-bit at
T = 2048) [SPIKE]. Requant to `o8` int8 at eO (shift eO - (eV -
fP) >= 0) + facts. Head concat is Class-0 re-indexing (o8 is laid
out [T, H*d_h] head-major; no operation, no fact). Then

    AOacc = o8 @ Wo    (T x H*d_h x d; inner 768/4096 — 25/27-bit)

with requant to `ao8` at eAo + facts. All existing families.

### 2.7 Residual adds

Scale-aligned EXACT adds — never a float, never a clamp:

    e_c   = min(e_a, e_b)                       (public)
    XWide = xa * 2^(e_a - e_c) + xb * 2^(e_b - e_c)

One linear MLE pin (public power-of-two weights on two committed
int8 tensors; XWide <= 2 * 127 * 2^max_shift — 10-11-bit class at
the [SYNTHETIC] shift spread), then a standard requant edge XWide
-> `xres` int8 at the calibrated eR' (shift eR' - e_c >= 0) +
remainder + narrowing facts. Two sites per layer (post-attention,
post-FFN). The narrowing fact is where residual-stream growth
(the study's layer-11 absmax 180-class outliers) will bind the
calibration — flagged into AT-O1.

### 2.8 Embedding and unembedding

**Embedding, inputs PUBLIC (P0/P2 — the PoC modes).** X0 =
Emb[ids]: one matmul-class sumcheck with the PUBLIC selector MLE
folded into the weights: MLE(X0)(r_t, r_d) = sum_v Sel~(r_t, v) *
Emb~(v, r_d), Sel~(r_t, v) = sum_t eq(r_t, t) * eq(v, id_t) —
verifier computes the weight functional in O(T log V) (PW-5). The
selected rows ARE int8 (Emb is int8): no requant edge, no
narrowing fact, X0 inherits eEmb [SPIKE]. Emb (49,152 x 768 at
125M) commits ONCE with the model, off the clock.

**Embedding, inputs PRIVATE (P1/P3) — THE OPEN GADGET.** With
committed ids the selector becomes witness. The sharp question
(AZ-T1 style): *can the multiset-lookup vocabulary certify a
GATHER — committed id -> committed d-wide row — at cost o(T * V),
when the table's "rows" are d-wide tuples rather than pairs?* The
two priced candidates, both honest but heavy:

  (a) committed one-hot selector: T x V binary tensor (25.2M
      coefficients at 125M) + w1 facts + row-sum-1 + the selection
      matmul — ~25.2M committed coefficients per pass (+3.5% of
      the full-LLM pass census, Section 6.1);
  (b) per-column pair lookups: for each of d columns, the pairs
      (id_t, X0[t,c]) looked up in the frozen per-column table
      {(v, Emb[v,c])} — d instances of V-row tables; the m-columns
      alone are d x V = 37.7M coefficients per pass (heavier than
      (a); only wins if m-columns amortize across passes as
      table-side material).

Neither is specified as the design; the gadget is [OBLIGATION]
AT-O10 with (a) as the fallback that provably works today. The
125M PoC statement targets P0 and does not wait on this.

**Unembedding (tied).** logits = final_norm(X_12) @ Emb^T — one
matmul-class instance at T x d x V, inner-d accumulator (25/27-bit)
and a requant edge to the DECLARED public output at eL. Two
statement forms, both specified: full-T (the honest prefill
default; the T x V acc/output/remainder tensors are 75.5M
coefficients — the single largest object in the pass, Section 6.1)
and last-position (T_out = 1: 3 x 49,152 coefficients — the
generation-relevant cheap form) [SPIKE checks the last-position
facts]. The declared-output requant may also be omitted entirely
(declare the raw 25-bit logits public); recorded as a
statement-level choice.

### 2.9 The division-relation gadget and the range-splitting rule

Both normalizations (2.1, 2.5) instantiate ONE auxiliary gadget
shape, named here once (it is a wiring pattern of existing
families, not a new claim family):

    DIV(num-parts, divisor row-vector V, quotient Q, remainder RHO):
      relation   num = Q o V_bc + RHO         (elementwise, divisor
                                               broadcast)
      zero-check sum_b eq(r,b) * [ Q(b)*V_bc(b) + RHO(b) - num(b) ] = 0
                 — degree <= 3 when num is a product of at most two
                 committed tensors (x8 o G_bc; P case: public 2^fP
                 times committed E);
      ranges     RHO in [0, V*base) proven TWO-SIDED:
                 RHO in [0, 2^w) AND SIGMA = V*base - 1 - RHO in
                 [0, 2^w)  (both RangeLookup; SIGMA committed with
                 its defining linear pin).

[PROVEN arithmetic]: the two range facts pin 0 <= RHO < V*base
exactly (SIGMA >= 0 gives the strict upper edge), and the relation
then forces Q = floor(num / (V*base)) uniquely — floor division for
SIGNED numerators included (RHO stays nonnegative; the contract's
own requant convention at a committed divisor). This IS the
"reciprocal-class fact" in the range/lookup vocabulary: no
committed reciprocal, no table, no floating-point anywhere.

**Range-splitting rule** (uniform, used by every fact above): a
range fact at width W uses a single [0, 2^W) RangeLookup iff
W <= 14 AND 2^W <= N_inst / 8 (the table side stays a <= 12.5%
minority of the instance); otherwise the value splits into limbs
of width <= 14 with one linear recomposition pin (RMSNorm's rho at
21-22 bits splits (11, 10-11); softmax's rho at 18 bits stays
SINGLE at score volume because 2^18 = 262,144 <= 3.15M/8 holds
with 50% headroom). The registry therefore gains parametric
[0, 2^w) members for w in {1, 9, 10, 11, 14, 18} beyond the
already-frozen shift/narrowing widths — trivial generation rule,
frozen with digests like every table (AT-O5).

## 3. Gadget assignment table

Existing families as named by the M125 rig: MATMUL (Thaler deg-2
sumcheck, incl. thin/ones and stacked-index forms), ZC3
(degree-<=3 zero-check: the Hadamard/CR-7 class), PIN (linear MLE
pins at transcript points), LKP (LookupAt: masked fused-pair
LogUp descent, table families with digests), RNG (RangeLookup
instances). "PW-n" = new PUBLIC-WEIGHT COMPUTATION feeding an
existing family (build item, no new claim machinery; the E1
slot-projection and M125 zero-extended eq-weights precedents).

| op | facts | family | new wiring |
|---|---|---|---|
| RMSNorm xsq, Dsq | self-Hadamard | ZC3 | — |
| RMSNorm SS row sum | ones-matmul | MATMUL (thin) | — |
| RMSNorm isqrt pair | a1, a2 ranges + pins | RNG w14 + PIN | — |
| RMSNorm divide | DIV gadget | ZC3 + RNG w11 x2 + PIN | PW-4 broadcast reads |
| QKV / Wo / gate / up / down / unembed | matmul + requant + narrow | MATMUL + PIN + RNG | — |
| RoPE | rotation zero-check + requant | ZC3 (deg 2) + PIN + RNG | PW-1 flip-read; public c/s tables |
| scores (GQA) | stacked matmul | MATMUL | PW-2 head map |
| score requant | requant edge | PIN + RNG | — |
| causal mask | sM derived read | (inside PIN/ZC3 weights) | PW-3 mask weights |
| row max | d pin + F-dom + F-bin + F-one + F-hit | PIN + RNG w8/w1 + MATMUL (thin) + ZC3 | — |
| exp | fused-pair lookup, per-(eS,d_h) member | LKP | new table FAMILY (registry), no new machinery |
| masked row sum | thin sumcheck | MATMUL (thin) | PW-3 |
| softmax divide | DIV gadget + off-support pin | ZC3 + RNG w18 x2 + w10 + PIN | PW-3/PW-4 |
| PV (GQA) | stacked matmul + requant | MATMUL + PIN + RNG | PW-2 |
| head concat | re-indexing | Class-0 | — |
| residual adds | wide pin + requant + narrow | PIN + RNG | — |
| embedding (public inputs) | selector matmul | MATMUL | PW-5 selector weights |
| embedding (private inputs) | — | **OPEN GADGET** | AT-O10; candidates priced in 2.8 |
| unembedding | matmul + requant | MATMUL + PIN + RNG | — |

**No new claim family is required for P0/P2.** The five PW items
are public-weight computations with the same transcript shape as
their precedents; each lands with an F5-pair ordering battery
(AT-O4). The single OPEN gadget is private-input embedding.

## 4. The claim-DAG extension

### 4.1 Per-layer entries and operations (extends M125 v4's 17/16)

NEW committed entries per layer (66; witness 60 + weights 6), in
chain order — dims at 125M/T512, class in Section 5's registry:

    attn_norm: xsq[512x768] SS[512] D[512] Dsq[512] a1[512] a2[512]
               xn8[512x768] rho_lo/rho_hi/sig_lo/sig_hi[512x768]   (11)
    qkv:       Qacc,q8,rQ[512x768]  Kacc,k8,rK[512x256]
               Vacc,v8,rV[512x256]                                  (9)
    rope:      QRacc,qr8,rQR[512x768]  KRacc,kr8,rKR[512x256]       (6)
    scores:    Sacc,s8,rS[12x512x512]                               (3)
    softmax:   m[12x512] d,zsel,E[12x512x512] Sum[12x512]
               P,rho,sig[12x512x512]                                (8)
    pv:        Oacc,o8,rO[512x768]                                  (3)
    wo:        AOacc,ao8,rAO[512x768]                               (3)
    resid1:    xw1,xres1,rr1[512x768]                               (3)
    mlp_norm:  (as attn_norm)                                       (11)
    resid2:    xw2,xres2,rr2[512x768]                               (3)
    weights:   Wq[768x768] Wk,Wv[768x256] Wo[768x768] gA,gM[768]    (6)

plus the FFN 17 (M125 unchanged) = 83 entries/layer; pass adds
final_norm (11), embedding X0 (1) and the unembedding triple
(full-T or last-position). Operation census per layer (new):
10 MATMUL-class (3 qkv + scores + pv + wo + 2 SS-rowsums +
E-rowsum + zsel-rowsum), 8 ZC3 (2 xsq + 2 Dsq + 3 DIV + F-hit),
3 deg-2 public ZC (2 RoPE + off-support/zsel-support pins,
batchable), ~21 PIN (10 requant edges, d-def, 4 isqrt pins, 4 limb
recomps, 2 residual), 1 LKP (exp member), ~26 RNG (10 remainders,
12 narrowings, d, zsel, P, rho, sig, 4 isqrt/limb classes — some
share family instances). The wave planner consumes these exactly
as it consumes the FFN's (BF-F2: the all-pins composition is
generic).

### 4.2 Row-max and normalization handling in the pass statement —
### stated exactly (the mission's two named questions)

**Row max**: `m` is a committed per-(head, row) tensor; the
statement pins d = m - sM (PW-3 public mask weights), proves
d in [0, 2^8) (dominance + structural top), and proves attainment
by zsel's three facts (binary, row-sum-1, z o d = 0). m is thereby
the EXACT maximum of the masked score row — not an unproven hint,
not a prover-chosen bound. Ties leave zsel (only) non-unique.

**Sum normalization**: the statement never divides. Sum is the
masked thin-sumcheck row sum of E; P is pinned by the division
relation P o Sum_bc + rho = 2^fP * E on the support with the
two-sided remainder ranges and the off-support zero pin. Sum >=
2^fE is structural (attainment + E[0] = 2^fE), so the relation is
total. Determinism: every output tensor (m, d, E, Sum, P, and
onward) is a unique function of the committed inputs given the
facts [SPIKE: layer re-run digest-identical].

### 4.3 F-IF1 fold dispositions (the extension the fold interface
### requires of new ops)

The pass fold (AGGREGATION_FOLDING_DESIGN F-IF1) covers instance
FAMILIES; each new family must state its disposition. At 125M the
layer index contributes lambda = 4 index variables (12 layers pad
to 16; the 32-layer 8B pass keeps lambda = 5 as written).

| new family | folds? | pass form |
|---|---|---|
| stacked matmuls (qkv x3, scores, pv, wo, rowsums) | FOLDS | one joint (l, ...) sumcheck each; rounds + lambda; the scores/pv instances ALREADY carry the head index — the layer index extends the same mechanism (PW-2 weights gain l-bits) |
| ZC3 families (xsq, Dsq, DIV x3, F-hit) | FOLDS | CR-7/CR-L6 class verbatim, rounds + lambda |
| deg-2 public ZCs (RoPE, mask pins) | FOLDS | public weight tables extend over l (c/s tables are layer-independent; mask is layer-independent; per-layer constants Cn/tn/2^fP enter as l-indexed public weights — same PW class) |
| exp LKP | FOLDS with a caveat | witness side folds like the SiLU pair (dw + lambda); the TABLE side does NOT collapse to one tree when layers use DIFFERENT members (12 distinct (eS,d_h) tables at 125M): the fused-table leaves become l-indexed public values — one batched table descent over the l-extended index space (dt + lambda equivalent), or per-member table descents (<= #distinct members, each dt 8). Priced both ways in 6.3; the m-column-per-instance ceiling bookkeeping is UNCHANGED (per-layer m columns, LKP-2 gate) |
| RNG families (per width w) | FOLDS per w-family | one folded pair per DISTINCT width; new widths {1, 9, 10, 11, 14, 18} add pairs, shared widths (w8, shift widths already present) join existing pairs at dw + ~1; the D-R1 rho-sharing assumption [MODEL] extends verbatim and is the main byte lever (6.3) |
| PIN entries | count-invariant | per-pass entry list grows by the per-family constants (~+120), never per layer |
| weights (Wq/Wk/Wv/Wo/gammas/Emb) | per-group | join T_W (stacked weight tensor gains the attention matrices; W-C two-proof layout unchanged; 8B weight-group headroom re-check is AT-O7's F-N4-class item) |

**Residual-stream wiring under the fold:** X_l is a SEGMENT of the
activation group exactly like every other tensor; the inter-layer
edge (resid2 of layer l feeding attn_norm of layer l+1) is a
per-layer PIN family (count-invariant), not a cross-instance
seam — the M125 battery's cross-layer-seam REJECT leg extends to
it unchanged.

## 5. Width tables (all rows [SPIKE]-asserted; q31 non-wrap
## |v| < 2^30 - 200 checked per row)

### 5.1 125M (T = 512, fE = fP = 9)

Committed classes (s = signed two's-complement width, u = unsigned):

| class | worst-case bound | width |
|---|---:|---|
| qkv/wo/gate/up/unembed acc (inner 768) | 12,387,072 | s25 (tight) |
| down acc (inner 2048) | 33,032,192 | s26 (tight) |
| score acc (inner 64) | 1,032,256 | s21 (tight) |
| PV acc (inner T=512, P <= 2^9) | 33,292,288 | s26 |
| RoPE acc | 32,512 | s16 |
| xsq | 16,129 | s15 |
| SS + Ceps | 12,387,115 | u24 |
| D = isqrt(SSe) | 3,520 | u12 |
| E | 512 | u10 |
| Sum | 262,144 | u19 |
| P | 512 | u10 |
| softmax rho/sigma | 262,143 | u18 |
| d | 254 | u8 (structural) |
| residual wide | shift-dependent, 10-11 bit class | s11 |
| int8 tensors (x, weights, q8...) | 127 | i8 |

Zero-check non-wrap terms (never committed): RMSNorm num
x*G*Cn <= 127^2 * 2048 = 33.0M (2^24.98); y*D*2^tn <= 127 * 3520 *
512 = 228.9M (2^27.77) at the tn = 9 class — both inside q/2 with
>= 2.2 bits of margin; softmax P*Sum <= 2^27. The derive-time gate
asserts the per-site tn bound (fail loudly, the arp_budget_ok
pattern).

### 5.2 7B/8B reference [MODEL, arithmetic spike-asserted]

| class | bound | width |
|---|---:|---|
| qkv/wo acc (inner 4096) | 66,064,384 | s27 (= the contract row) |
| FFN down acc (inner 14336) | 231,225,344 | s29 (= the contract row) |
| score acc (inner d_h 128) | 2,064,512 | s22 |
| PV acc (T=512 / T=2048) | 33.3M / 133.2M | s26 / s28 |
| SS + Ceps (d 4096) | 66,064,390 | u27 |
| D | 8,128 | u13 |
| Sum (T=512 / T=2048) | 2^18 / 2^20 | u19 / u21 |
| P*Sum (T=2048, fE=fP=9) | 2^29 | non-wrap, fits |

**The long-context resolution ceiling** [SPIKE]: the division
zero-check requires fE + fP + log2(T) <= 29. At (9,9): T = 2048
fits exactly (2^29); T = 4096 BUSTS. Escapes, priced but not
specified: drop (fE, fP) (quality cost: P's step exceeds 1/T — the
uniform-row underflow the M125 study's outlier finding parallels),
or split Sum into two limbs inside the zero-check (one extra
committed row-vector + one extra ZC3 term). Recorded as the
T >= 4096 design boundary; irrelevant at the contract's T = 512.

**Softmax quality note [SYNTHETIC]**: at the spike's max-calibrated
eS = -1, layer-0 softmax error vs fp32 was max 0.155 / mean 0.00055
per entry, attention-out relative error 0.39 — score-scale
stretching by outlier maxima is the SAME mechanism the study
measured for FFN activations (its Section 4), now with an attention
number attached. Per-head eS (finer members) is the model-side
lever; the spec supports it (members are cheap); AT-O1 decides.

## 6. Cost derivations [MODEL — arithmetic shown, anchors cited]

### 6.1 Committed-coefficient census

Per 125M layer (T = 512), the attention extension (Section 4.1
entries), in coefficients:

| block | coeffs |
|---|---:|
| attn_norm + mlp_norm (2 x 2,361,856) | 4,723,712 |
| qkv (acc + y + r) | 1,966,080 |
| rope | 1,572,864 |
| scores (Sacc + s8 + rS) | 9,437,184 |
| softmax (m, d, zsel, E, Sum, P, rho, sig) | 18,886,656 |
| pv + wo | 2,359,296 |
| residuals x2 | 2,359,296 |
| attention weights + gammas | 1,574,400 |
| **extension total** | **42,879,488** |

FFN-only layer (M125 measured census): ~16.96M -> full layer
~59.84M = **3.53x**; the six T^2 score-volume tensors are 66% of
the extension. Pass (12 layers + final_norm + X0 + last-position
unembed): extension ~517.4M; full-LLM pass ~721M vs 203.5M
FFN-only = **3.54x**. Full-T unembedding adds +75.4M (the largest
single object; last-position form +0.15M). One-time weight
commitments: +18.9M (attention) + 37.75M (Emb). T-scaling: the
score-volume block grows as T^2 (16x at T = 2048); everything else
linear.

**Fused-accumulator option [MODEL, recommended for the build
round]:** the matmul terminal can pin 2^sh * MLE(y) + MLE(r)
directly (the requant identity read at the matmul's terminal
point), dropping the committed acc tensors: -5.90M/layer
(Sacc 3.15M + qkv 0.66M + rope 0.52M + O/AO 0.79M + resid wide
0.79M) -> extension 36.98M (-13.8%), full layer 3.18x. Same
[PROVEN] pin algebra, new bookkeeping only; wave-plan interaction
unverified -> AT-O2 with its battery.

### 6.2 Prove/verify time (as-built rig anchors, [MAC-BOX ~1T],
### M125_PASS_REPORT Sections 5 + 9)

Anchors: FFN-only layer prove 250.4 s post-BJ (waves 199.5 s = the
68.8%-class share at 127 waves/~131 cms each; descents 35.1 s;
matmul+Hadamard+requant 7.6 s; pins 7.4 s), verify 31.9 s, commit
36-40 s. Scaling the wave share by committed volume (59.84M/16.96M
= 3.53x -> ~446 waves) and descents by leaf volume:

| line | FFN-only (measured) | full-LLM layer [MODEL] |
|---|---:|---:|
| waves | 199.5 s | ~700 s |
| descents | 35.1 s | ~220 s |
| claim layer (sumchecks + pins) | ~15 s | ~55 s |
| **prove/layer** | **250.4 s** | **~975 s (3.9x)** |
| verify/layer | 31.9 s | ~112 s |
| 12-layer pass prove | 3,275 s (54.6 min) | **~11,700 s (~3.3 h)** |

The fused option scales these by ~0.88x. These are AS-BUILT
numbers on the noisy Mac box: the attention extension multiplies
exactly the walls the U-PERF sibling lanes attack (PC: the wave/
opening 68.8%; PA: the kernel 10-20x), so the full-LLM latency
story is deliberately quoted at today's engine, not a projected
one. 8B rows are not quoted at all: no 8B layer has ever been
proven in this repo; the honest 8B lines remain the census ratios
(inner-dim and head-count scaling) until a measured rung exists.

### 6.3 Folded pass bytes (Tier-N-class arithmetic; kel model
### F-IF1.8, 64 B/K-element; all [MODEL])

Baseline: measured FFN-only 12-layer P0 full statement 1,509,911 B
= 1.440 MiB (U-AG-B1 wave-4 close; BJ re-derived split-fill line
1,325,118 B). The extension adds, at pass scope (lambda = 4):

| object | arithmetic | bytes |
|---|---|---:|
| exp pair (dw 26, dt 8; 12 members -> l-indexed table leaves) | kel(26,9) = 1,873 | 119,872 |
| w1 zsel pair (dw 26) | kel(26,9) | 119,872 |
| w18 rho+sigma pair (dw 27, dt-extension +504 kel) | kel(27,9) = 1,990 (+504) | 159,616 |
| w11 norm-limb pair (dw 26, dt +84) | 1,873 + 84 | 125,248 |
| w14 isqrt pair (dw 15, dt +240) | kel(15,9) = 850 (+240) | 69,760 |
| w10 P pair (dw 26) | kel(26,9) | 119,872 |
| joins to existing w8/shift families (dw +1 growth) + new shift values | ~4 x 7.5 KB + slop | ~270,000 |
| folded sumcheck instances (~22 new x (rounds+4) x deg x 64) | ~5 KB each | ~110,000 |
| pins + manifest growth (~+120 entries; ~+720 typed statement rows) | | ~100,000 |
| **extension total** | | **~1,194,000** |

Full-LLM 125M P0 folded pass ~ **2.6 MiB-class** against the
12-layer Tier-N envelope 3.0 MiB (12 x 262,144 B) — **~0.83x,
inside, with the per-layer average ~218 KiB pressing the 256 KiB
line**. The main lever is the D-R1-class rho-sharing of range
descents [MODEL]: if the new RNG families share the folded witness
descents as the FFN range arm is assumed to, ~0.5 MB of the pair
lines collapses -> ~2.1-2.2 MiB (~0.70x). The dt-extension terms
(+504/+240/+84 kel) extrapolate the kel fit BEYOND its recorded
dt = 9 points — flagged as the byte-model risk (AT-O7 measures
one dt-14/18 descent before these lines are frozen).

### 6.4 The 8B pass and the contract tier (the lane's contract
### finding)

Amendment A1's Tier Z freeze reads "**per 32-layer FFN pass**" —
it does not cover the full-LLM statement. Extension arithmetic at
8B/T512 (32 layers, lambda = 5; score volume 8.39M/layer; folded
pairs at dw 29-31, kel 2,236-2,498): new descent pairs ~1.16 MB +
instances/pins ~0.26 MB -> **full-LLM 8B P0 folded ~2.6-2.9
MiB-class; P3 adds the two masked eval-proof floors (+272,640 +
281,856 B, R-EB4-corrected) -> ~3.2-3.5 MiB** vs the frozen
FFN-scoped Tier Z 1.0625 MiB. Consequence, stated for the
orchestrator: **the full-LLM statement requires a NEW contract
tier row at a future FINAL** (proposal to price at U-AT-B1 close:
full-LLM P3 <= 4 MiB per 32-layer pass [MODEL], rho-sharing and
fused-acc levers unpriced in); nothing in Amendment A1 moves, and
no full-LLM byte number may be quoted against the FFN tiers.
Weight-group note: the stacked weight tensor gains Wq/Wk/Wv/Wo
(+8.4M rings at 8B) — the F-N4 0.05-bit headroom margin must be
re-derived with the bigger group (AT-O7, F-N4-class check).

## 7. Ranked risks

1. **Attention calibration does not exist yet on the real
   checkpoint** (every attention exponent is [SYNTHETIC]). The
   study's outlier mechanism provably transfers (per-tensor eS
   stretched by score maxima -> softmax temperature distortion;
   spike measured P max err 0.155, attn-out 0.39 at synthetic
   scales) and could be materially WORSE on trained attention
   (attention logits are famously heavy-tailed). Mitigation:
   AT-O1 first in the build queue; per-head members are cheap if
   needed. This is the risk that can move the spec (exponent
   table), not the semantics.
2. **The wave/opening wall multiplies 3.5x.** The extension's
   committed volume rides the same C2 cap that already makes waves
   68.8% of prove time; ~446 waves/layer as-built. Not a spec risk
   — a scheduling one — but the full-LLM latency story is hostage
   to the PC lane (wave batching) and PA lane (kernels) exactly as
   the FFN pass is. The score-volume tensors (66% of the
   extension) are the T^2 objects: T = 2048 grows them 16x.
3. **Byte-model extrapolation** (dt-extension kel terms; the
   ~270 KB family-join slop; the rho-sharing assumption). The
   folded-pass lines in 6.3/6.4 carry the F-IF1.8-class [MODEL]
   flag; AT-O7 pins them against one measured wide-dt descent
   before any tier proposal is frozen.
4. **The Tier-Z scope finding** (6.4): if unnoticed, a full-LLM
   artifact would be quoted against an FFN-scoped line — a
   contract-integrity bug, pre-empted here by stating the missing
   tier explicitly.
5. **PW wiring correctness** (flip-read, GQA map, mask weights,
   broadcast reads, selector weights): five new public-weight
   computations, each an F5-pair battery obligation (AT-O4). The
   classes have precedents (E1 slot projections, zero-extended eq
   weights), so the risk is implementation, not design.
6. **Long-context ceiling** fE + fP <= 29 - log2(T) (Section 5.2):
   T = 4096 needs the Sum-limb split or coarser P. Boundary
   recorded; out of contract scope (T = 512).
7. **Private-input embedding is OPEN** (P1/P3 only; both
   candidates priced ~25-38M coeffs/pass). P0/P2 unblocked.
8. **Fused-acc bookkeeping** (AT-O2): a 13.8% commit saving with
   an unverified wave-plan interaction; ship unfused if the
   battery slips.
9. **zsel non-uniqueness under ties**: aux-witness freedom only
   (m and all outputs unique); stated in 2.5 so no auditor
   rediscovers it as a surprise.
10. **RoPE/exp table platform drift**: handled by the frozen-bytes
    + drift-loud-generator discipline (silu-v2 precedent); risk
    retired at AT-O6's freeze rows.

## 8. Build-round obligations (the U-AT-B1 queue candidate)

- **AT-O1 — attention calibration pass** (frugal venv, extends
  m125_int8_calibration.py): capture residual stream, xn, q/k/v,
  rotated q/k, raw scores (per head), o_pre, attn-out per layer on
  calibration + held-out windows; freeze the per-layer exponent
  table and the 12 exp members; re-run the spike's error section
  on real ranges; decide per-layer vs per-head eS.
- **AT-O2 — fused-accumulator decision**: wire the matmul-terminal
  requant pin; battery: wrong-shift, wrong-remainder, wrong-point
  REJECTs; measure the wave-plan delta; adopt or drop.
- **AT-O3 — manifest v5**: attention operation kinds (or their
  decomposition into existing kinds + PW descriptors), the
  exp/rope registries, per-layer (tn, Cn, Ceps, fE, fP) metadata,
  the causal-mask convention flag, v4 digests unmoved (the BF-2b
  discipline).
- **AT-O4 — PW-1..PW-5 wiring + F5 batteries**: flip-read (PW-1),
  GQA map (PW-2), mask weights (PW-3), broadcast reads (PW-4),
  embedding selector (PW-5); each with the ordering-attack pair.
- **AT-O5 — range-table registry members** w in {1, 9, 10, 11,
  14, 18} + the splitting rule as a derive-time gate.
- **AT-O6 — table freeze rows**: exp-neg-table-v1 members (12) +
  rope-cs-table-v1, frozen bytes + digests + drift-loud
  generators (spike Section 1 is the reference implementation).
- **AT-O7 — byte reconciliation**: extend `pass-agg expect` with
  the Section 6.3 families; measure one dt-14/18 descent to pin
  the dt-extension term; re-derive the 8B weight-group headroom
  (F-N4 class) with Wq/Wk/Wv/Wo stacked in.
- **AT-O8 — causal-mask battery**: off-support tamper (nonzero P
  off support), wrong-mask (shifted triangle) — both REJECT with
  every other gate green (the M125 sharp-leg style).
- **AT-O9 — row-max battery**: m overstated by 1 (all facts
  self-consistent except F-hit/F-one), m understated (F-dom
  fails), zsel off-support, zsel two-hot — four REJECTs.
- **AT-O10 — private-input embedding gadget decision** (the OPEN
  item; candidates priced in 2.8).
- **AT-O11 — instancing gate for long T**: derive-time enforcement
  N_inst <= 2^25 for exp instances (per-layer at T <= 1024,
  per-layer-per-head-group at T = 2048+), the LKP-2 pattern.

## 9. Spike output (recorded verbatim)

`python3 scripts/attention_spec_spike.py`, 2026-08-11, exit 0,
69.9 s, seed 20260811:

    OK 1: calibration study loaded (m125_int8_calibration.json): layer-0 eX=-3, eW=-9, absmax X 12.57 — the synthetic input generator below is shaped to these ranges
    OK 2: silu-int8-table-v2 replica: generated bytes reproduce BOTH frozen engine digests (m3 bdf8bc71.., m4 06399348..) — the house table/digest pattern the new families extend is implemented exactly
    OK 3: exp-neg-table-v1 family: double generation byte-identical, digests deterministic, 5 eS members + d_h 64/128 members all distinct; E[0]=2^9 exact, outputs in [0,512], monotone nonincreasing
    OK 4: rope-cs-table-v1: double generation byte-identical, digest deterministic, |c|,|s| <= 2^7 with cos(0) = 128 attained (public statement constants, not committed witness)
    OK 5: 125M width table: all 16 declared class bounds hold at the stated widths (signed acc rows, unsigned aux rows), every bound inside q31 headroom (< 2^30); the three matmul rows are width-tight
    OK 6: 8B width table: all 10 declared bounds hold (27-bit @ inner 4096 reproduces the contract row; 22-bit scores; T=2048 P*Sum = 2^29 fits, T=4096 at fE=fP=9 hits the q31 wall — the long-context resolution ceiling fE+fP <= 29 - log2(T) is real and recorded)
    OK 7: contract accumulator rows reproduce under [-127,127]: 27-bit @ 4096, 29-bit @ 11008 (the study's Section 1 pin, re-checked here)
    OK 8: exact-fold findings: sqrt(d_h)=8 exact at 125M (2^-3 fold), sqrt(d)=64 exact for the 8B RMSNorm Cn (pure-shift constant); sqrt(768) and sqrt(128) are irrational -> folded into declared public constants (Cn) / table generation (lambda), never proven
    OK 9: worst-case attainability: all-extreme witnesses hit the exact analytic bounds for inner-768, score, PV and RoPE accumulators (the declared widths are tight, not padded)
    OK 10: embedding/unembedding: public-selector identity X0 = Sel@Emb exact on committed int8 rows (no requant edge — rows inherit int8); tied unembed last-position logits ride the 25-bit inner-768 accumulator with a standard requant edge
    OK 11: synthetic residual stream built: absmax 16.14, p999 3.78 (study-shaped outlier tail)
    OK 12: per-layer scale tables max-calibrated from the fp reference (layer 0: eXn=-3, eQ=-4, eS=-1, eAo=-5, eR1=-2)
    OK 13: two full layers ran under the exact integer semantics: 296 range facts + 210 derivation identities all hold (requant remainders, narrowings, d-dominance, selector attainment, isqrt pairs, division relations, off-support pins)
    OK 14: accumulator audit: measured peak |acc| within the declared class bound for every class touched: acc2048=24,437<=33,032,192, acc768=693,989<=12,387,072, acc_pv_T512=28,419<=33,292,288, acc_score64=13,705<=1,032,256, e_shift=262,144<=262,144, had15=3,445<=16,129, p_sum=262,144<=134,217,728, rope_acc=11,550<=32,512, ss=69,859<=12,387,115, sum_exp=44,409<=262,144, xsq=5,041<=16,129
        error vs fp reference (layer 0): xn 0.0939, q 0.0998, rope(q) 0.1082, softmax P max 0.1554 / mean 0.000550, attn-out 0.3937, block-out 0.2889
    OK 15: error vs fp32 within sanity gates (wiring-bug detectors, not quality claims: quality is calibration work per the study's Section 4 finding, restated for attention in the spec)
    OK 16: row-mass audit: sum_j P in [282, 512] against 2^9 = 512 — floor semantics lose < T units of mass; the spec declares the division facts, NOT exact row-stochasticity
    OK 17: determinism: layer-0 re-run reproduces the block output digest (2cfa781d67797c4e..) — the declared function is a function
    OK 18: swept-input audit: two fresh seeded input draws (max-calibrated per draw) ran the full layer-0 integer path — every range fact, derivation identity and accumulator class bound held across the sweep (fail-by-design semantics exercised on 3 input draws total)

    all attention_spec_spike assertions passed (18/18 OK, 734 range facts, 522 identities, 69.9 s, seed 20260811)

Development note, recorded for honesty (the M4 tradition): the
spike's one real bug during construction was the RMSNorm constant
carrying the input exponent (Section 2.1 item 1) — caught by the
fp32 error gate, NOT by the fact battery (all 700+ facts passed
under the wrong constant, because an underscaled-but-in-range
witness satisfies every range fact). The build round inherits the
lesson: differential-vs-reference tests are load-bearing for
SEMANTIC correctness; fact batteries only guard the declared
relations.

---

*Changelog: 2026-08-11 — first edition (U-PERF lane PD): per-op
integer specifications for RMSNorm/QKV+GQA/RoPE/scores+mask/
softmax/PV+Wo/residuals/embedding+unembedding; exp-neg-table-v1 +
rope-cs-table-v1 generation rules and digests; the division-
relation and isqrt gadget shapes in range/lookup vocabulary
(rsqrt table rejected with arithmetic); gadget assignment — no new
claim family at P0/P2, five PW public-weight wirings, one OPEN
gadget (private-input embedding); claim-DAG extension (66 new
entries/layer) + F-IF1 fold dispositions; spike-checked width
tables at 125M and 8B (incl. the fE+fP <= 29 - log2 T long-context
ceiling); cost census 42.9M coeffs/layer extension = 3.53x
FFN-only, folded-pass bytes ~2.6 MiB-class 125M P0 (~0.83x the
12-layer Tier-N envelope), the Tier-Z FFN-scope contract finding;
risks ranked; U-AT-B1 obligation queue AT-O1..O11; spike 18/18
recorded.*
