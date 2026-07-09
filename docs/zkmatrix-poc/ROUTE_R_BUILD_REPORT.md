# Route R Protocol Build (U1-U8): Report

Status: tranche complete. Artifacts: `zkmatrix-rs/src/ring/{mod,params,
commit,sigma,ct_engine}.rs` (shared modules, `#[path]`-included),
`zkmatrix-rs/src/bin/ring_matmul.rs` (Pi1/Pi2 lift + gadget family +
chain demo + self-tests; `ring_matmul self-test`, `ring_matmul chain-demo
n0 n1 n2 n3`), Python-suite coverage in
`tests/test_zkmatrix_native_backends.py`. Companion docs:
`ROUTE_R_DESIGN.md` (annotated in place by this tranche),
`RING_MULT_BOTTLENECK.md` Section 6, `A1_AUX_NTT_REPORT.md`.

Executive summary, stated the honest way around: **the arithmetic,
commitment, opening, ct-engine, gadget and chain layers of Route R are
built, measured, and hold their design rates at r = 1 — and the build
FALSIFIED two load-bearing constructions of the design spike** (both
flagged there as Q1, "highest risk"): option (b)'s general-A linear map
and the ring-challenge Pi2 gate do not compose soundly as written. Both
have working implemented replacements (option (a) R-linear maps at full
grade; a scalar-challenge gate behind the design's own `r_g` flag), but
the Pi2 gate's replacement costs repetitions, so **the r = 1 lever — and
with it the 50-175 KB Pi2 proof projection — does not survive the gate
at this design state.** The commit bill (the A1-kernel layer, ~119
muls/element, measured in-protocol by the previous tranche) is
unaffected. The next design round (automorphism/trace gate machinery,
ALS20-style) is now the critical-path item for the ~15 s / ~2x endpoint.

## 1. What was built (all layers self-tested, negative batteries included)

| unit | contents | status / measured |
|---|---|---|
| U1 | `ring/mod.rs`: generic-q k-way CRT (k = 8 at q8_31), Karatsuba slot kernels, GEMM kernels, A1 aux-NTT dispatch, quinary XOF, digit decomposition, sigma_{-1} transport | bit-identity battery across all kernel paths; LS18 1.30x margin reproduced (100 inversions + zero-divisor control) |
| U2 | `ring/params.rs`: C0'-C4 chains (plain + digit) pinned to `route_r_params.py` outputs; P0 A1-capacity enforcement. `ring/commit.rs`, `ring/sigma.rs`: shape-parametric BDLOP commit, plain + digit opening rounds | Q2-frontier and FFN rows match the script exactly; prototype tamper batteries transferred; same-seed School/A1 transcript identity |
| U3 | `ring/ct_engine.rs`: linear ct-claims (g-before-theta ordering, h reveals, combined mask images W_l, joint Sigma round), Ajtai-slot (ABDLOP) commitments, JL-projection ARP | 9 theta rows at q31; full negative battery incl. fake-reveal-with-matching-ct; ARP mechanism at q46 |
| U4 | ring-Pi1: option (a) R-linear A; v-combined commitments with digit openings; ring-valued claims | 256->128 x 64 demo: prove 38 ms, verify 6 ms, ~100 KB at r = 1 |
| U6 | quadratic claim layer (sigma-twisted ct + untwisted ring); binary, range/recomposition, rescale, H3 slot Hadamard | all gadgets as claims (no per-element Sigma floor); binary at q46 with ARP; negatives throughout |
| U5 | ring-Pi2 with the scalar gate behind the `r_g` flag | 128 x 256 x 64 demo at r_g = 8: prove 656 ms, verify 48 ms; ~202 KB/rep |
| U7 | manifest/chain integration; one ct-round per gadget wave | chain-demo: 12 commitments, 8 operations, one 49-claim wave; tampered-manifest negative |
| U8 | this report; design-doc annotations; parameter freeze below | — |

## 2. The frozen parameter point (and what is NOT frozen)

Frozen (carried from the Q2/Q3 + A1 tranches, now exercised in-protocol):

- d = 128, k = 8, q = q8_31 = 2^31 - 399 (= 17 mod 32), eta = 2056890868;
  LS18 quinary margin 1.30x (tight — `assert_ls18` runs at every context
  construction).
- Quinary challenge set (|C| = 2^297.2, C1' 40-bit margin) for every
  ring-challenge combination and Sigma round.
- Digit-decomposed openings for combined commitments: e = 4 default
  (ring-challenge combos: L = 3 at demo shapes; scalar gate combos:
  L = 4), concentration discipline with restart rules.
- theta output-compression rows: l = ceil(256 / log2 q) = 9 at q31.
- The A1 kernel paths and their derive-time capacity policy (P0),
  unchanged from the integration tranche; the commit path stays on the
  measured golden regime.

NOT frozen, with reasons:

- **The Pi2 gate** (finding F2): implemented as scalar repetitions;
  parameters (b = 6, r_g) are per-deployment until the automorphism gate
  lands. Full grade r_g = 64.
- **The binary-gadget side condition at q31** (finding F3): the ARP
  budget does not close at q31 under the conservative Q4 constants
  (extraction 2^22.1 vs the 2^15-class budget); it closes at q46 even
  conservatively. Options for the gadget layer: run gadget claims at a
  q46-class budget, a modulus-pair linking argument, or exact per-chunk
  strategies. *(Decision study done: GADGET_MODULUS_DECISION.md —
  recommended option (a), q46 gadget layer + modulus link (x1.02 CPU /
  x2.04 GPU commit end-to-end, ~7 MB/pass of link rows); per-chunk
  REJECTED at scale; tightened-slack is the deletion path
  (Q4_LEMMAS.md Q4.4'). CORRECTION: the bit-tensor fraction is ~83% of
  committed element-equivalents at the current quantized-spec
  assumptions, not "small"; the honestly re-derived q46 gadget layer
  costs x1.03 CPU and x2.26 GPU-int8 on that fraction.)*
- Q5 (estimator sign-off): *(DONE — ESTIMATOR_NOTE.md: the frozen point
  HOLDS with zero (kappa, N_r) movement; real lattice-estimator run
  under a doctest-validated shim + an independent core-SVP leg; MSIS
  binds at 136.7-153.0 bits classical across the frozen shapes; MLWE
  never binds. Residue: native-Sage value confirmation; quantum-target
  note (kappa+1 if ever adopted).)*
- Q4 (concentration lemma + garbage-term ZK simulation + ARP slack
  constant): the write-up debt is unchanged and now also covers the
  quadratic layer's garbage terms and the ARP's relaxed-opening slack
  (`SLACK_OP`, conservative 4D).

## 3. Findings (the tranche's main scientific output)

### F1 — option (b) does not type-check for general A (Q1, linear half)

`ROUTE_R_DESIGN.md` Section 4 option (b) asserts the compressed claim
`<A^T theta, unpack(x_b)> = <theta, unpack(x_c)>` over ring-challenge
combined commitments. For the negacyclic matrix M(v_j) of a ring
challenge and general A, `A M(v_j) != M(v_j) A`, and the identity fails
for HONEST parties (the per-column functionals would have to be
`M(conj v_j) theta`, whose A-pullbacks the verifier cannot afford).
Every elementary repair loses a leg of the triangle {r = 1 proof size,
l-matvec verifier, general A}:

| repair | cost |
|---|---|
| per-column openings + rank-1 theta claims | proof linear in cols (MB-class at n = 2048) |
| single wide commitment per matrix | responses scale with matrix area (MB-class) |
| scalar-challenge mini-repetition of the compression | r_v = ceil(256/(b-2)) digit bundles (~MB) |
| ALS20 automorphism basis | d ring products per block ("zero compression") |

Resolution shipped: **option (a) at full grade** — ring-Pi1 takes A as
R-linear (ring-coefficient blocks: shift/gadget matrices, convolutions,
block-selection), where A commutes with the v-combination by
commutativity of R_q, and the compressed equation is discharged by
ring-valued claims (no theta, no reveals). The design itself notes
option (a) covers the gadget-internal maps; the transformer critical
path (Pi2 for hidden weights) never needed general-A Pi1.

### F2 — the ring-challenge Pi2 gate does not close (Q1, gate half)

With ring challenges s, v: `F := sum_u conj(xa_u) xb_u = sum_ij
conj(s_i) v_j P_ij` where `P_ij := sum_u conj(apack_iu) bpack_ju` carries
`ct(P_ij) = C[i][j]` — but the ring weights mix P_ij's JUNK
(shift-correlation) coefficients into ct(F): `ct(w P) != w-weighted
ct(P)`. The C-side cannot be twisted to match (same non-commutation as
F1), and committed-correction escapes fail because the correction's own
consistency claim reintroduces per-pair objects. This is exactly the
"junk cross-correlation coefficients absorbed by ct-masks" step the
design listed as its highest-risk item; written out, it does not go
through with elementary machinery.

Resolution shipped: the design's own fallback, **scalar gate challenges
behind the `r_g` flag** — signed nonzero b-bit scalars commute with the
packing, so each repetition is ONE sigma-twisted quadratic ct-claim over
scalar-combined, digit-opened commitments (all repetitions share one
ct-round). Per-rep soundness (b - 2) bits (Route Z's own discipline):

- full grade at b = 6: **r_g = 64** — the r -> 1 lever does not survive
  the gate; the vector/opening layers DO stay at r = 1, so a repetition
  costs ~3 digit bundles (~202 KB, ~80 ms at the demo shape) instead of
  a full Route Z repetition.
- Projected at FFN-scale parameters: ~240 KB and O(10 ms) per rep ->
  **~13-15 MB and ~0.3-0.6 s (1T) of gate work per matmul claim** at
  full grade. At ~2,200 claims per 7B/512 pass this adds minutes-class
  prove time (22T) and ~30 GB of proof — vs the design Section 7(b)
  projection of ~117 KB / ~0.1-0.2 s per claim.

Consequence for the ladder: **the ~15-30 s / ~2-4x reconciliation of
RING_MULT_BOTTLENECK.md Section 6.5 holds for the commit bill and the
non-gate layers, but the claim-proof layer is gated on the automorphism
gate design round** (ALS20 trace/automorphism machinery adapted to the
packed-matmul statement — the natural next tranche, sized like the
original U5 estimate of 2-3 weeks). Until then Pi2 runs at reduced r_g
for development or at full r_g with the stated costs.

### F3 — the binary side condition fails at q31 (ARP budget)

New quantitative finding (asserted in the self-test): with conservative
Q4 constants (JL constant 13, relaxed-opening slack 4D) the extracted
bound is 2^22.1 for a 512-coefficient tensor at 256 rows, alpha = 3;
the q31 non-wrap budget needs a 2^15-class bound (and even the
optimistic slack ~20.8 gives 2^17.4 — still over). At q46 the budget
closes even conservatively (2^44.2 < 2^45). The Q2/Q3 tranche moved the
recommended modulus to q31 without re-checking this gadget-side budget;
the gadget layer needs one of: a q46-class budget for binary claims, a
modulus-pair linking argument, exact per-chunk ranges, or a tightened Q4
slack lemma.

### F4 — what holds at r = 1 (measured)

Openings (plain + digit), linear ct-claims, ring-valued claims, the
quadratic claim layer, the gadget family, H3 slot Hadamard, option-(a)
Pi1, wave batching and manifest chaining all run at r = 1 with the
measured figures of Section 1 — bit-identical across the schoolbook and
A1 kernel paths under same-seed proving, with the negative batteries
transferred from Route Z test-for-test. The Sigma-floor removal for
gadgets is structural: gadget cost is commitment arithmetic plus
amortized claims (the 256-value demo runs the whole range family in
~20 ms, ~78 us/element at a shape far too small to amortize; the
FFN-scale projection of ~17 us/element from commit arithmetic alone is
unaffected).

## 4. Perf notes

No new kernel work was needed: the A1 aux-NTT paths (previous tranche,
measured in-protocol) carry every commitment, mask and verify matvec in
this build; same-seed bit-identity is asserted throughout, so the
integrated rates of RING_MULT_BOTTLENECK.md Section 6.3 apply as-is.
Demo-scale protocol timings (1T, this build): Pi1 38 ms / 6 ms verify;
Pi2 (r_g = 8) 656 ms / 48 ms; the 49-claim gadget wave proves in ~0.5 s
inside the 0.79 s chain total. Multithreading and the GPU row remain the
roadmap's flagged extrapolations.

## 5. Recommended next steps (in order)

1. **The automorphism gate design round** — DONE, same session:
   `AUTOMORPHISM_GATE_DESIGN.md` + the `gate-spike` prototype. The
   trace-gate identity is machine-verified at (k = 8, q8_31) including
   the dense full-group point: junk-free, per-slot 2^-296, r = 1
   restored ALGEBRAICALLY, zero commit-bill penalty. The measured
   frontier law (executions x 1/density = 128) picks the operating
   point; the remaining build risk is the amortized-opening composition
   (Q-A1: digit-decomposed amortized responses decide ~100-200 KB vs
   ~0.7 MB per claim). Next tranche: the protocol composition
   (U-A1..U-A4 in the design doc).
2. The gadget-layer modulus decision (F3): price q46-budget binary
   claims vs the modulus-pair link on the FFN bit-tensor fraction —
   note the link machinery is shared with the gate's option 2 (Q-A4).
3. Q5 estimator run at the frozen point; Q4 lemma write-up (now also
   covering garbage-term simulation, the ARP slack, and Q-A2's
   twisted-execution ZK aggregate).
4. GPU kernels (unchanged from the roadmap) — the commit bill is
   arithmetic-layer-complete and unaffected by F1/F2.

A `freeze-check` subcommand (and suite test) now runs EVERY derive-time
budget of the frozen point in one gate — the permanent guard against
F3-class cross-tranche parameter drift.

### F5 — the fixed-coefficient binary claim was unsound (found and fixed
in this session's follow-up tranche)

Working the Q4.3c mask algebra surfaced a soundness hole in U6's binary
gadget AS FIRST IMPLEMENTED: a fixed-coefficient ct-claim cannot use the
g-mask soundly (g's argument is the commit-before-theta ordering; with
protocol-fixed coefficients a prover commits g with ct(g) = -defect and
passes a non-binary tensor). FIX: theta-randomized claim copies — each
scaled by a uniform SCALAR drawn from h0 (a full ring element would mix
junk into the ct and break completeness — the F2 phenomenon again);
l = ceil(256/log2 q) copies give 2^-279-class. The self-test now carries
the F5 regression BOTH ways: the old shape demonstrably accepts the
crafted attack; the new shape rejects it. The ARP and Pi2-gate claims
were never affected (FS-derived coefficients). Claims are now per-TENSOR
(the design's granularity).

Also shipped in the follow-up tranche: joint-scaled rejection
(Q4_LEMMAS.md Q4.2b, proven — one summed test replaces the per-bundle
product; ~3.7x fewer restarts at three active bundles, visible in the
demo timings), and the derived gate-scalar width (`derive_gate_b`,
freeze-check-pinned: demo b = 8/e = 4 -> r_g = 43, response cost -33%;
FFN honestly stays b = 6/e = 3 -> r_g = 64 — prioritizing the
recursive-gate round, AUTOMORPHISM_GATE_DESIGN.md Appendix A).
