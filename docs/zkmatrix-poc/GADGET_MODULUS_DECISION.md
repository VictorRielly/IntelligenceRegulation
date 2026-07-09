# The Gadget-Layer Modulus Decision (Finding F3)

STATUS (U-L1..U-L3 IMPLEMENTED, 2026-07-09): option (a) is built —
`ring/link.rs` (gadget-layer chain, w_max/rows/gate, xi/y, both claim
families), `ring_matmul link-demo` + `self_test_link` (in self-test),
`freeze_check_link` rows in freeze-check, suite test. Measured at the
frozen point (n = 128 values in [0, 2^4), W = 4 planes; w = 11, l = 24,
2^-264): prove 13 ms, verify 9 ms, link overhead ~155 KB; honest
max|y| = 2^16.7 (model 2^16.3) vs the 2^45 grounding gate; CRS points
q31 (kappa 9, N_r 56, headroom 2.0 bits), q46 (kappa 6, N_r 62, 16.8
bits); w_max(128, 4, q46) = 35. Granularity finding pinned BOTH ways:
the ARP binary unit closes at q46 for 512 coefficients, NOT for 1536 —
binary claims + ARPs stay partitioned at F3-shape units (Section 3.5
note; Q4.4' dependency). Negative battery: tampered bit / tampered
value / oversized y / stale-xi (F5 mode) all fail as required.

Status: decision study COMPLETE — recommendation: **option (a), the
q46-class gadget budget with a modulus link** (Section 6). Every number
in this document is computed by `scripts/gadget_modulus_study.py`
(runnable, assertion-checked against the F3 self-test values); nothing
is hand-computed. Companions: ROUTE_R_BUILD_REPORT.md finding F3 (the
problem), AUTOMORPHISM_GATE_DESIGN.md Section 4 option 2 / Q-A4 (the
shared link machinery), Q4_LEMMAS.md Q4.4 (the extraction-constant
lemma this study prices around), `zkmatrix-rs/src/bin/gadget_link_spike.rs`
(standalone mechanics prototype for the link, Section 4.4 — NO
test-suite hooks, by design).

## 1. The problem (F3, restated with its numbers)

The binary gadget proves "all coefficients of b are in {0,1}" as ONE
quadratic ct-claim per tensor, `ct(sum_u conj(b_u) b_u - conj(1~) b_u)
= 0`, i.e. `sum_t b_t (b_t - 1) = 0` — sound over Z only under the
non-wrap side condition `|sum_t b_t (b_t - 1)| < q/2`. The side
condition is grounded by the ARP (JL projection, 256 rows), whose
extracted bound composes the JL lower bound (constant 13) with the
relaxed-opening challenge slack (`SLACK_OP`, conservative worst-case
`||c-bar||_1 = 4D = 512`). At the study's shape (n = 512, rows = 256,
alpha = 3):

| slack | meaning | extract bound | defect bound | q31 (2^30)? | q46 (2^45)? |
|---|---|---|---|---|---|
| 512.0 | 4D worst-case l1 (as coded) | 2^22.1 | 2^44.2 | FAILS | closes |
| 20.8 | concentration op norm 1.3 sqrt(2D) | 2^17.5 | 2^34.9 | FAILS | closes |
| 2.0 | unit-slack class (LNP22-style, UNPROVEN) | 2^14.1 | 2^28.2 | closes | closes |

The Q2/Q3 tranche moved the recommended modulus to q31 without
re-checking this budget; the freeze-check now pins the failure. Honesty
note carried from Q4_LEMMAS.md Q4.4: **the q46 closure margin under the
conservative constants is only 0.84 bits, and the composition behind
the constants is itself lemma-debt** (the constants are worst-case in
what they carry, but two steps of the derivation — the JL bound against
challenge-mixed vectors and the integer lift — are stated, not proven).
The q46 budget is the best-grounded point available today; it is not a
proven theorem yet either.

Four options were priced: (a) q46-class budget for the gadget claims
plus a modulus link, (b) exact per-chunk ranges at q31, (c) a tightened
slack lemma, and the do-nothing reference (unsound). Sections 3-5;
recommendation with the end-to-end numbers in Section 6.

## 2. What the decision actually prices: the bit-tensor fraction

Per LLM_SCALE_ESTIMATE.md, the 7B/512 pass commits ~9.4e9 element-
equivalents with bill factor 5.8 (w = 12 bit decomposition on 40% of
tensors): **bit tensors are 82.8% of the committed element-equivalents.**
The build report's F3 paragraph calls this "the SMALL bit-tensor
fraction" — that phrasing is wrong at the current quantized-spec
assumptions and an integration note below corrects it. Any per-element
penalty on the gadget layer multiplies the DOMINANT share of the commit
bill; that is why this decision is costed end-to-end rather than
per-gadget. (The later "bit-packing / lookup ranges" lever would shrink
the fraction 2-4x; the decision below does not depend on it.)

## 3. Option (a): gadget claims at a q46-class budget + the modulus link

### 3.1 The q46 gadget commitment layer, derived honestly

Bit tensors are committed at q8_46 = 2^46 - 1103 (eta =
49533544627797 — the constants already in `ring/mod.rs` as
`Q8_46`/`ETA8_46`, exercised by the U3b/U6b self-tests). The commitment
shape is NOT the design table's Pi2-at-q46 point (kappa 15, N_r 72 —
sized for matmul combination magnitudes): a gadget-wave ct-round layer
re-derived through the same C2/C3/C4 chain (concentration discipline,
msg_r = 32, wave bundles of n_commits commitments) gives:

| q | n_commits | kappa | N_r | C2 headroom | ring-MACs/el | commit KB/col |
|---|---|---|---|---|---|---|
| q31 | 16 | 9 | 56 | 2.0 bits | 0.561 | 19.9 |
| q31 | 64 | — | — | C2 FAILS (< 1 bit) | — | — |
| q31 | 256 | — | — | C2 FAILS (< 1 bit) | — | — |
| q46 | 16 | 6 | 62 | 16.8 bits | 0.575 | 27.3 |
| q46 | 64 | 7 | 62 | 14.8 bits | 0.590 | 28.0 |
| q46 | 256 | 8 | 63 | 12.8 bits | 0.615 | 28.7 |

Readings:

- **Per-bit-element CPU cost at q46 is x1.03** vs the q31 layer — NOT
  the 1.45x the Pi2-shaped q46 point suggests. C3 gives kappa back
  (6 vs 9: bigger q needs fewer binding rows for the same beta) almost
  exactly as fast as C4's d_lwe term (768 log2 q / 11.7) takes N_r.
  P0 confirms the commit regime (key x ternary/binary) stays
  single-prime on the A1 kernels at q46 (n_acc = 62); the Gaussian-MASK
  regime dispatches limb-split x3 at q46 — a per-round cost on wave
  mask matvecs, not a per-committed-element cost.
- **The commit-stream bytes cost x1.38** (46-bit words, 27.3 vs 19.9
  KB/column) — a memory/bandwidth cost on the bit fraction.
- **The GPU int8-GEMM count costs x2.26** on the bit fraction
  ((46/30)^2 vs (31/30)^2 per LLM_SCALE Section 3's mapping) — this is
  the real price of option (a), and it lands on 82.8% of the bill.
- Side benefit, new quantitative observation: at q31 the wave ct-round's
  own C2 caps bundles near ~16 commitments (64-commit bundles fail);
  at q46 even 256-commit bundles hold 12.8 bits of headroom — the
  gadget wave-partitioning pressure disappears at q46.

### 3.2 The modulus link, designed precisely

The q46 bit commitments must ground the q31 VALUE commitments (the
value tensors stay at q31 — the whole point is not to move the value
chain). One argument subsumes the recomposition claim and the link:

**Statement shape.** Value tensor v committed at q31 (dense packing,
coordinates t = 1..n). Its W bit-planes b_(i,t) committed at q46 and
proven binary there (quadratic ct-claim + ARP, the q46 budget above).

**Protocol.**

1. Both commitment groups enter one statement hash `h0_link` (binding
   BOTH CRS hashes, both commitment groups, and the g-mask commitments
   of both sides — the engine's g-before-theta rule, applied across
   moduli).
2. Derive l rows of signed uniform w-bit weights xi_(l,t) from
   `h0_link` (one XOF; the same rows serve both sides).
3. The prover reveals the INTEGER scalars
   `y_l := sum_t xi_(l,t) * sum_i 2^i b_(i,t)  = <xi_l, v>` — one
   integer per row, range-checked (Section 3.3).
4. Two linear ct-claims per row assert the SAME y_l:
   - at q46, over the bit commitments, with structured weights
     xi_(l,t) * 2^i on bit (i, t) — public functional, packed by
     `pack_functional` as usual;
   - at q31, over the value commitments, with weights xi_(l,t).
   Both claims ride their side's ordinary ct-round (g-masks, reveals,
   combined mask images; nothing new in the engine).

**Soundness accounting** (per the brief: per-row catch probability for
a nonzero integer difference, rows for 2^-256).

- Extraction on the q46 side yields B46 in {0,1}^(Wn) as INTEGERS (the
  binary claims + ARP budget — that is exactly what the q46 budget
  buys). Define V46 := sum_i 2^i B46_i, an integer vector in
  [0, 2^W)^n.
- The q46 ct-claim extracts `<xi_l, V46> + ct(g46*_l) = y_l (mod q46)`
  with g46* committed BEFORE xi. Honest ct(g) = 0; an adversarial g
  shifts by a pre-committed constant. Since
  `|<xi_l, V46>| <= n 2^(w-1) (2^W - 1) < q46/2` (the w_max rule below)
  and `|y_l| < q46/2` (range check), a zero g-shift forces the exact
  integer equality `y_l = <xi_l, V46>`; a nonzero pre-committed shift
  must PREDICT `<xi_l, .>`-values — the same point-mass event as below.
- The q31 ct-claim extracts `<xi_l, V31> + ct(g31*_l) = y_l (mod q31)`.
  Combining: `<xi_l, V31 - V46> = -ct(g31*_l) (mod q31)` with the
  right side fixed before xi. For a nonzero difference vector
  delta := V31 - V46 (mod q31): xi_(l,t) is uniform over 2^w signed
  values and q31 is prime, so `xi_(l,t) delta_t` for any nonzero
  coordinate takes 2^w distinct values mod q31, each with mass 2^-w;
  adding independent coordinates cannot increase the maximum point
  mass. **Per-row catch probability >= 1 - 2^-w.**
- Rows are independent XOF draws: **l = ceil(256 / w) rows gives
  2^-(w*l) <= 2^-256** — one FS challenge event, inside the C1'
  grinding budget (the (Q+1)^2 accounting of the design's Section 2).
- Conclusion: V31 = V46 (mod q31) with V46 an integer vector in
  [0, 2^W)^n < q31/2 — the q31 values are integer-range-grounded, and
  no recomposition claim runs at q31 at all (the structured 2^i weights
  ARE the recomposition).

### 3.3 Granularity, the w_max rule, and the range gate

The q46-side integer-exactness cap `n 2^(w-1) (2^W - 1) < q46/2` sets
the weight width per linked unit of n value coordinates:

| granularity | n values | w_max | rows l | worst \|y\| | honest \|y\| (1.3-tail) | < q31/2? |
|---|---|---|---|---|---|---|
| column (msg_r = 32) | 4096 | 22 | 12 | 2^45.0 | 2^37.8 | NO (gate at q46/2 only) |
| token-block 512x4096 slice | 2097152 | 13 | 20 | 2^45.0 | 2^33.3 | NO (gate at q46/2 only) |
| full FFN tensor 512x11008 | 5636096 | 11 | 24 | 2^44.4 | 2^32.0 | NO (gate at q46/2 only) |

(Honest-|y| model spike-corrected: xi is centered but the values are
NOT, so Var(xi*v) = E[xi^2] E[v^2] with E[v^2] = 2^(2W)/3 — the /12
variant underestimates by ~1 bit; `gadget_link_spike` section [2]
observes 2^38.1 at column granularity, consistent.)

Range-gate note, stated exactly: only `|y_l| < q46/2` is load-bearing
(it pins the integer y from its residue on the side that carries the
integer grounding). The brief's symmetric `|y| < q31/2` check is sound
but NOT satisfiable by the honest prover at w_max at ANY of these
granularities (honest |y| ~ 2^32-2^38 > 2^30) — it would be a
completeness break, not a hardening; drop it, or, if a symmetric-gate
implementation is preferred for uniformity, shrink w until the honest
tail fits under q31/2 (w = 9, l = 29 rows at full-tensor granularity —
a 5-row cost for no soundness gain). The reusable link
interface (Section 3.5) states the rule generically: **range-gate y
against the GROUNDING side's q/2.** Recommended operating point: full-
tensor granularity, w = 11, l = 24 rows (fewest rows, coarsest unit).

### 3.4 Link costs

| granularity | rows | bytes/row | KB/link | MB/pass (128 linked tensors) |
|---|---|---|---|---|
| column | 12 | 2519 B | 29.5 | (x tensor count) |
| token-block slice | 20 | 2519 B | 49.2 | (x tensor count) |
| full FFN tensor | 24 | 2519 B | 59.0 | **7.4** |

Bytes/row = revealed y (8 B) + q46 reveal h_l and mask image W_l (736 B
each) + q31 h_l and W_l (496 B each) + amortized g-slot share on both
sides. Extra commitments: l g-mask slots per side per linked unit
(amortized in the table). Prover arithmetic for the link functionals:
2.25e11 MACs/pass = ~49 s 1T ~ 3.3 s at 22T — noise-class. Verifier: l
ct-checks per tensor, deterministic, microseconds-class.

### 3.5 The shared interface with the trace gate's Q-A4

AUTOMORPHISM_GATE_DESIGN.md Section 4 option 2 (gate layer at q46 with
dual-modulus links for the combos) needs exactly this machinery. The
shared interface, so one design item serves both consumers:

    LINK(gnd = (q_G, commitments, integer-bound proof),
         tgt = (q_T, commitments),
         map = public integer weight map tying tgt-coordinates to
               gnd-coordinates (here: 2^i recomposition; for Q-A4:
               identity on combo coordinates),
         w, l = ceil(256/w))
      -> transcript: l revealed integers y_l, gated |y_l| < q_G/2;
         l ct-claims on each side sharing one cross-modulus h0;
      -> guarantee: tgt-values = map(gnd-values) (mod q_T), with
         gnd-values integer-bounded by gnd's own proof.

Differences for Q-A4, flagged now: there the GROUNDING side's integer
bound comes from norm checks on q31 openings (not from binary claims),
so the w_max rule uses that norm bound in place of 2^W - 1; and the
gate-layer objects at q46 are challenge combinations, so the linked
unit is a combo (n = N_Z-class), not a tensor. Same soundness shape,
same per-row 2^-w accounting. If the trace gate instead lands on its
option 1 (digit-decomposed amortized responses — the ranked leading
candidate), the gate never consumes the link and F3 remains its only
user; the link is still the F3-cheapest sound option (Section 6).

### 3.6 Mechanics prototype

`zkmatrix-rs/src/bin/gadget_link_spike.rs` (standalone bin, NO
test-suite hooks — run manually via `cargo run --release --bin
gadget_link_spike`) machine-checks the integer-link mechanics at
(q8_31, q8_46): the w_max non-overflow rule at all three granularities,
honest-path residue agreement of the double ct-assertions, the
per-row catch rate against single-coordinate and random nonzero
difference vectors (empirical miss ~ 2^-w), the pre-committed-g-shift
adversary, and the range-gate necessity negative (a +-q46 shifted y is
caught by the gate, and only by the gate). It prototypes soundness
mechanics only — no commitments/openings; those layers are the
engine's, unchanged.

## 4. Option (b): exact per-chunk ranges at q31

Ajtai-slot grounding at per-ring-element granularity: each 128-coeff
chunk of the bit tensor committed as a short Ajtai witness, per-chunk
response norm checks, per-chunk binary claims.

**The norm chain, re-derived honestly** (verifying the prior session's
estimate): per chunk at alpha = 3, T_s = 20.8 sqrt(128) = 235.3,
sigma_s = 706, B = 1.2 sigma_s sqrt(128) = 9585, and the per-chunk
defect bound

    (2B)^2 + 2B sqrt(128) = 2^28.45  <  q31/2 = 2^30    (1.55 bits).

The prior estimate (2B)^2 = 2^28.4 is **verified** (2^28.45). Two
findings kill the option anyway:

1. **It does not escape Q4.4.** The Ajtai norm check grounds the
   relaxed opening `||c-bar s*||`, not `||s*||` — the identical
   composition debt as the ARP's slack constant. The 1.55-bit closure
   above is an honest-parameter chain, not a proven extraction bound;
   as a lemma-status matter, (b) buys nothing over (a).
2. **A per-chunk budget forces per-chunk CLAIMS.** The whole-tensor
   defect is the SUM of chunk defects (n_chunks x 2^28.45 >> q31/2),
   so the binary claim cannot stay one-per-tensor. At FFN scale:
   7.78e9 bit coefficients/pass = 6.08e7 chunks; each chunk's
   quadratic ct-claim carries h_quad + (Ga, Gb, G0) + W_quad + its
   Ajtai response = 2720 B, and ~4 ring muls (~17 us):

   | metric | per pass | vs criterion |
   |---|---|---|
   | proof bytes | **154 GB** | vs ~MB-class budgets |
   | prover time | 1021 s 1T (~68 s 22T) | **3x-9x the whole matmul-claim layer (110-330 s 1T) = 309-928% >> the <20% Class-3 criterion** |

**Verdict: REJECTED at FFN scale.** Kept in the toolbox for narrow
interim tensors (demo class), where the same numbers are trivial.

## 5. Option (c): the tightened Q4 slack lemma

How far must `SLACK_OP` drop from 4D = 512 for the q31 budget to close?
Solving `b^2 + b sqrt(512) = q31/2` gives extract <= 2^15.00, and:

| alpha | y_bound | unit extract (slack 1) | slack_max for q31 | ARP restart M |
|---|---|---|---|---|
| 3 | 19181 | 2^13.08 | **3.79** | 1.74 |
| 2 | 12787 | 2^12.49 | 5.68 | 2.40 |
| 1 | 6394 | 2^11.49 | 11.37 | 7.39 |

At the coded alpha = 3, `SLACK_OP` must fall 135x, to <= 3.79 — below
even the concentration operator norm 20.8 (5.5x past it). No operator-
norm-style tightening can get there; the only argument class that can
is the **LNP22-style direct-witness composition** (Lyubashevsky-
Nguyen-Plancon, eprint 2022/284; their projection-lemma machinery
around the constants 13/26): the ct-round's message-side extraction is
exact over R_q, the committed (b*, m*) are fixed by BINDING before the
JL rows R are derived, and the mod-q anti-concentration form of the
projection lemma bounds ||b*|| directly from the y range gate — the
`||c-bar||_1` factor never touches the witness; what remains is a
~2-class constant from the mask relaxation. The precise statement is
Q4_LEMMAS.md Q4.4' — **stated, not proven, and not claimed proven**;
it must be verified against LNP22's actual lemma statements before any
budget is moved onto it.

Even if proven at slack = 2, the q31 margin at alpha = 3 is **0.9
bits** — thinner than the repo has ever frozen a layer on. Trading
alpha down (alpha = 1: slack_max 11.4, M = 7.4 on the ARP reveal loop
only) buys real room and is worth carrying INTO the lemma work, but a
budget that only closes under an unwritten lemma is exactly the F3
failure mode this study exists to end. **Verdict: the deletion path,
not the decision** — if Q4.4' lands, the q46 gadget layer and the link
are deleted with no redesign of the claims themselves.

## 6. Sensitivity and the recommendation

End-to-end, 7B/512 pass, anchored on the integrated A1 measurements
(commit 1.6-2.0 min 22T / 5-6 s GPU; claims 10-25 s wall 22T; bit
fraction 82.8%):

| option | commit 22T CPU | commit GPU | extra proof bytes | extra prover | verdict |
|---|---|---|---|---|---|
| (reference) all-q31, F3 open | 1.6-2.0 min | 5-6 s | — | — | UNSOUND |
| **(a) q46 bits + link** | **1.6-2.0 min (x1.02)** | **10-12 s (x2.04)** | **~7 MB link (+1.38x bit commit stream)** | **~3.3 s 22T** | **SOUND TODAY** |
| (b) per-chunk q31 | 1.6-2.0 min | 5-6 s | ~154 GB | ~17 min 1T | REJECTED (Class-3 blowout; inherits Q4.4) |
| (c) tightened slack | 1.6-2.0 min | 5-6 s | — | — | UNPROVEN (needs <= 3.79) |

**Recommendation: option (a).** Concretely:

- Bit tensors and their binary/ARP claims move to a dedicated q8_46
  gadget layer (kappa 6, N_r 62, msg_r 32; wave bundles up to
  256 commitments); value tensors and every other layer stay at q31.
- Each range-proved tensor gets one modulus link at full-tensor
  granularity: w = 11, l = 24 rows, 59 KB, per-row miss 2^-11,
  aggregate 2^-264.
- Cost, honestly stated: CPU pass essentially unchanged (x1.02 commit);
  the GPU commit row doubles (x2.04: 5-6 s -> 10-12 s), stretching the
  projected pass from ~15-30 s to **~20-37 s (~2.9-5.3x CPU-int8)** —
  the 15 s rung moves outside the band until either the bit-packing
  lever (2-4x on the bit fraction) or the Q4.4' deletion path lands.
  That is the true price of F3 at today's proof state, and it is the
  cheapest sound one on offer: (b) is two orders of magnitude worse in
  bytes, (c) is not a proof yet.
- The link machinery is shared with Q-A4 (Section 3.5) — one build
  item, two consumers.

## 7. What lands in the freeze-check when (a) is built

New derive-time gates (text for the build tranche; the freeze-check
file is out of this study's lane):

    gate("gadget layer q8_46 C2/C3/C4 at (kappa 6, N_r 62, msg_r 32, waves <= 256)", ...)
    gate("link w_max rule: n 2^(w-1) (2^W - 1) < q46/2 at the frozen granularity", ...)
    gate("link rows l * w >= 256", ...)
    gate("link range gate = grounding-side q/2 (q46/2 here)", ...)
    gate("P0: q46 gadget commit regime single-prime; mask regime limb-split (priced)", ...)

## 8. Integration notes (annotations for the merger — this tranche does
not modify existing files)

1. **ROUTE_R_BUILD_REPORT.md, Section 2, F3 bullet**: append —
   *"Decision study: GADGET_MODULUS_DECISION.md — recommended option
   (a), q46 gadget layer + modulus link (x1.02 CPU / x2.04 GPU commit,
   ~7 MB/pass of link rows); per-chunk rejected at scale; tightened-
   slack lemma is the deletion path (Q4_LEMMAS.md Q4.4')."*
2. **ROUTE_R_BUILD_REPORT.md, F3 text "2.4x int8-GEMM cost on the
   SMALL bit-tensor fraction"**: correct to — *"the bit-tensor fraction
   is ~83% of committed element-equivalents at the current
   quantized-spec assumptions (LLM_SCALE 5.8x bill factor); the
   honestly re-derived q46 gadget layer costs x1.03 CPU and x2.26
   GPU-int8 on that fraction (x1.02 / x2.04 end-to-end)."*
3. **ct_engine.rs module header, ARP HONESTY NOTE**: append pointer —
   *"Lemma status and the modulus decision: Q4_LEMMAS.md Q4.4 (the
   SLACK_OP composition is a derive-time budget gate, not a proven
   extraction bound — two steps are lemma-debt even at q46);
   GADGET_MODULUS_DECISION.md (q31 needs SLACK_OP <= 3.79 at alpha 3)."*
4. **AUTOMORPHISM_GATE_DESIGN.md, Q-A4**: append —
   *"Link interface designed and priced in GADGET_MODULUS_DECISION.md
   Section 3.5 (per-row miss 2^-w, l = ceil(256/w) rows, range gate on
   the grounding side's q/2); mechanics prototyped in
   gadget_link_spike.rs."*
5. **RING_MULT_BOTTLENECK.md Section 6.6 / LLM_SCALE_ESTIMATE.md
   Section 3 table**: add the option-(a) row — *"gadget layer at q46 +
   link (F3 resolution): commit GPU x2.04 (5-6 s -> 10-12 s), pass
   ~20-37 s (~2.9-5.3x) until bit-packing or Q4.4' lands."*
