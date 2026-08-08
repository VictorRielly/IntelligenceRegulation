# U-AG-B1 Engine Report — Lane BB (critical path: exact-digit + the dense committed matmul statement)

Status: SKELETON at plan commit (2026-08-08); filled as deliverables
land. Ledger: PROGRESS_UAGB1.md "Agent BB status". Machine: Victor's
Mac (Apple M3 Ultra, 32 threads, 256 GB, Homebrew rust 1.96) — NOT
the contract reference box; every timing here is [MAC-BOX,
non-reference], plus [NOISY-SHARED] where sibling lanes were running.
Byte counts and battery verdicts are machine-independent.

## 0. Scope and honest labels

- Deliverable 1: the exact-digit plumbing (F-N2, triple-mandated),
  config-gated ALONGSIDE the balanced-digit path (no deletion).
- Deliverable 2: the dense committed matmul statement C = A*B at the
  125M layer shape 512x768x2048 (committed A weight-class, B
  activation-class, C accumulator-class; dense D-1 encoding;
  multi-wave C2 per RANGE_AGGREGATION_DESIGN Phase 5; Z1 masked
  share discipline). This closes the "largest full matmul claim
  proof = 128x256x64" gap.
- NOT in this statement (honest): the aggregate/eval-proof layer
  (BB items 4-6: IXF fold, masked eval path, wire format). The wire
  objects here are per-wave ct-round proofs + the matmul sumcheck +
  pins; the counted-byte totals therefore carry the pre-aggregation
  opening volume, reported against the Tier N gate as the round's
  designed-vs-built gap number.

## 1. Deliverable 1 — exact-digit plumbing (LANDED, battery green)

### 1.1 What was built

- `src/ring/digits.rs` (new module): the exact-digit configuration —
  `DigitMode { Balanced, Exact }` (Balanced = the existing sigma.rs Q2
  chain, UNTOUCHED); the class table; canonical decomposition
  (e0 >= 2 = the house balanced digits, shared arithmetic asserted;
  e0 = 1 = canonical sign-binary d_j = sign(x)*bit_j(|x|)); alphabet /
  shift / representable-range / l0-derivation helpers; the gamma-gate
  arithmetic (gamma_max(exact) = (q/8)/58.8, fold-norm law
  OP_CONC*2^(e0-1)*sqrt(n_limb*D)); the recomposition non-wrap gate;
  base-2^e0 recomposition RingClaim builder; the canonical
  decomposition digest.
- `[UAGB1-D1]` rig in ring_matmul.rs (`uagb1-digit-battery`, also in
  self-test): per class, ONE committed instance — value column +
  committed digit columns + EXACT recomposition RingClaims + EXACT
  digit-alphabet membership by a range-table lookup into the shifted
  alphabet ([0,3) at e0 = 1, [0,2^e0) at e0 >= 2; blinded trees,
  masked descent pair, root cross-check, aggregate pins — the U-R2
  exact range machinery), all grounded by one masked ct-round.
  Deterministic, Gaussian-free, JL-free on the exact path; consistent
  with I-6.

### 1.2 The class table (freeze row UAGB1-1a, both directions)

| class | range | e0 | l0 | alphabet | recomposition semantic |
|---|---|---|---|---|---|
| w8s-weight-int8 | [-128, 127] | 1 | 8 | {-1,0,1} (3-row table) | integer-exact (non-wrap gated) |
| a8s-act-int8 | [-128, 127] | 2 | 5 | [-2,1] (4-row) | integer-exact |
| a8u-act-offset8 | [0, 255] | 2 | 5 | [-2,1] | integer-exact |
| acc24-inner768 | [-12,484,608, 12,582,912] | 2 | 13 | [-2,1] | integer-exact |
| q31c-full-column | +-(q-1)/2 | 2 | 16 = ceil(31/2) | [-2,1] | MOD-Q NATIVE (PARAMS 2.2; non-wrap gate violated BY DESIGN, pinned) |

### 1.3 Battery verdicts (all green, 4.2 s; `uagb1-digit-battery`)

- Round-trip + alphabet membership: exhaustive over the 8-bit
  classes, endpoint + 4096-probe sweep over the wide ones; e0 >= 2
  decomposition bit-identical to the balanced `digit_decompose`.
- l0 derivation both directions (pinned l0 rederives; l0-1 fails
  coverage) for every class.
- Committed rig honest ACCEPT at all 5 classes (n_el 120-404).
- Differential (identical inputs): balanced Q2 leg green on
  a8s/a8u (attempts 2, restarts 0); see finding F-BB2 for acc24.
- OOA digit (recomposition-preserving, value 2^e0 re-expressed as
  digit vector (base, 0)): REJECT at the range root cross-check ONLY
  — descents and ct-round green, the lookup is the gate that sees it.
- Recomposition defect (in-alphabet digit tamper): REJECT at the
  ct-round ONLY (RingClaims) — the lookup passes, the recomposition
  claims are the gate.
- Post-commit message tamper on a digit column: REJECT (opening
  equations).
- Stale-alpha F5 pair, both directions: the forgery (OOA digit +
  LogUp defect absorbed into the table blinder mass at a pre-known
  alpha) ACCEPTS under the weakened (commitment-free h0) ordering and
  is REJECTED by the shipped verifier — the alpha hash edge is
  load-bearing.

### 1.4 Lane findings (exported)

- **F-BB1 (sign-binary base).** The balanced digit arithmetic at
  e = 1 has digit set {-1, 0} — representable max 0; it cannot carry
  ANY positive value. The exact path's canonical sign-binary
  {-1, 0, 1} is the engine's ONLY e0 = 1 base — the F-N2 weight-group
  base exists exclusively on the exact-digit branch, making the
  trench's "load-bearing for the weight group" concrete in code.
- **F-BB2 (wide-class wall).** The balanced Q2 chain REJECTS the
  accumulator class at derive time (its own C2 gate: beta_rec =
  op * w_inf * sqrt(n_z) = 2^33.8-class at w_inf ~ 2^23.6 vs q/8 =
  2^28) while the exact path ACCEPTS the same values — the Gaussian
  digit transport cannot host wide value classes at q31; committed
  digits + alphabet lookup can. F-N2 reproduced at engine scale.
- **F-BB3 (mod-q semantics of the full column).** representable(2,16)
  = +-2.86e9 exceeds the q31 centered window: the full-column class's
  recomposition is mod-q native (exactly Greyhound's decomposition
  semantic); the integer-exact reading belongs to narrow value
  classes only. Pinned in UAGB1-1a rather than papered over.

### 1.5 Freeze rows (UAGB1-1a..1d, in `freeze-check`)

1a class table (rederive + l0-1 fails + semantics); trench
alignment (weight e0 = 1; q31c l0 = ceil(31/2)). 1b gamma_max(exact)
= 4,565,228 ~ 2^22.12 with the F-IF1.5 gate comparisons (act e0=2
fits / e0=5 does not; weight e0=1 fits / e0=2 does not) and the D2
statement classes' gammas (2^15.17 / 2^16.83 / 2^17.23) under the
gate. 1c canonical decomposition digest
1602129d5922fbafca357ee36e5bdf3e4d3d25bc020790e4e8ee3e4df4462197.
1d non-wrap gate rejects (e0=2, l0=17). All existing freeze rows
unmoved (56 ok rows total).

## 2. Deliverable 2 — the dense committed matmul statement (LANDED at the FULL 512x768x2048 shape, battery green)

This closes the "largest full matmul claim proof = 128x256x64" gap:
the engine's largest committed matmul statement is now the 125M layer
shape 512x768x2048 (3,014,656 committed values), proven under ONE
statement.

### 2.1 The construction

- Statement: manifest v3 (`mm_build_statement`) — A 512x768 int8
  (weight class), B 768x2048 int8 (activation class), C 512x2048
  25-bit accumulator (derived from the declared-type interval, the
  validator's own arithmetic — never copied from the 7B rows),
  RowMajor, `Operation::Matmul`, PadSpec exact; the model digest
  binds shape + quant + the DELIVERABLE-1 EXACT-DIGIT CLASS
  DECLARATIONS (A w8s e0=1, B a8s e0=2, C acc e0=2 l0-derived) +
  every data commitment digest. Witness values follow the [-127,127]
  convention (BC export; the declared v3 type stays int8 — at inner
  768 both readings give 25 accumulator bits; the inner-2048
  divergence 27-declared vs 26-honest is a recorded statement-typing
  item: QuantMeta has no symmetric-range field).
- Dense D-1 encoding: 1 coefficient per element, row-major,
  msg_r*D = 1024 coefficients per commitment; NO-TAIL discipline
  asserted at derive time (every tensor packs exactly; a shape with
  tails needs a transcript-weighted zero-tail pin first).
- Multi-wave C2 (RANGE_AGGREGATION Phase 5, the as-built U-R1/U-Z1
  machinery): first-fit plan at data cap 131 = C2 max 134 - 1 pad -
  2 g-groups; every commitment (data + pads + g) committed and bound
  into the statement/h0 BEFORE any challenge (D-4).
- The claim: one degree-2 sumcheck over K = GF(q^16), rx in K^9 and
  ry in K^11 drawn post-commit; inner 768 zero-extends to 2^10 in
  the prover's tables only; terminal MLE evaluations v = C~(rx,ry),
  a* = A~(rx,k*), b* = B~(k*,ry) land as three PinnedValues -> 9
  psi-batched ct-claims (psi after pinned values, E4-N1) -> the
  MASKED share splitter (U-Z1 coset pads, the Z1 shipped path; no
  cleartext partial functionals) -> per-wave masked ct-rounds +
  the zero-sum closing round.
- One-opening discipline: every data commitment is opened in exactly
  one wave round (plan bijection); pads per pad-wave + closing (the
  U-Z1 pattern). The per-GROUP batched-opening rule (E-O2') binds
  the eval-proof layer when it lands.

### 2.2 Battery (`matmul-statement battery`, 128x768x256, 3 waves, all green, 49 s)

| leg | verdict |
|---|---|
| honest ACCEPT (320 data cms, 3 waves) | green |
| wrong-C-entry: prover claims the true A*B value against a tampered committed C | REJECT — sumcheck green, the C pin's masked shares fail their gates (the sharp leg: only the commitment grounding catches it) |
| tampered commitment (post-commit message tamper on a C group) | REJECT at its wave's opening equations |
| stale-hash-ordering F5, DEFENSE | the forged C (16 solved entries, NOT A*B, built after stale rx/ry) REJECTED by the shipped verifier |
| stale-hash-ordering F5, ATTACK | the same forged C ACCEPTS under the weakened ordering (challenges before C is bound) — commit-before-challenge is load-bearing, demonstrated both directions |
| wave-boundary (content): two B commitments swapped ACROSS waves, statement self-consistent | REJECT — position-determined pin weights catch the move |
| wave-boundary (binding): wave rounds bound to permuted wave indices | REJECT — the verifier's independently-derived h0_w differs |
| masked-reveal lie (+1 one wave) | REJECT at the sum gate |
| compensated lie (+1/-1 two waves) | sum gate passes, REJECT at the wave rounds |
| wrong-digit-base declaration (weight class e0=2 instead of 1) | REJECT at the statement gate (model-digest class binding; the E-O1-BB negative vector, digest-binding form) |

### 2.3 Measurement [MAC-BOX, non-reference; BA/BC lanes closed at run time, orchestrator activity possible — magnitudes only]

| shape | data cms | waves | commit | prove | verify | peak RSS |
|---|---:|---:|---:|---:|---:|---:|
| 64x96x128 (sanity) | 26 | 1 | 0.01 s | 0.72 s | 0.04 s | ~22 MiB (ps) |
| 512x768x2048 (FULL, run 1) | 2,944 | 23 | 0.31 s | 45.2 s | 4.2 s | 1.13 GiB (/usr/bin/time -l) |
| 512x768x2048 (FULL, run 2) | 2,944 | 23 | 0.31 s | 45.2 s | 4.2 s | 1.25 GiB |

Run 2: 49.7 s user on 50.6 s real — the run is effectively
SINGLE-THREADED (1T); two runs agree to within noise. Not p50/p95
grade (two runs, non-reference box — the machine note governs).

Verify at 4.2 s exceeds the contract's 2 s line — that line binds the
AGGREGATE artifact's verifier (the eval-proof layer, unbuilt); this
pre-aggregation verifier re-runs every wave's ct-round. Recorded as
context, not claimed compliant.

### 2.4 Counted bytes vs the Tier N gate (counted-NOT-serialized; 64 B/K-el, 4 B/q31 coeff, 8 B/i64 response, 12 B/reveal)

Full shape 512x768x2048, one honest instance:

| component | bytes | share |
|---|---:|---:|
| statement (serialized, real) | 503 | ~0% |
| commitment tags t1+t2 | 24,518,656 | 20.9% |
| sumcheck (v + rounds + finals) | 2,112 | ~0% |
| masked share reveals (9 x 23 x 12) | 2,484 | ~0% |
| ct-round z responses | 80,297,984 | 68.4% |
| ct-round w1 images | 12,353,536 | 10.5% |
| ct-round h + w_claim | 221,184 | 0.2% |
| **TOTAL** | **117,396,459** | |

**vs Tier N 262,144 B/layer (P0): 447.8x OVER.** The claim layer
itself (statement + sumcheck + reveals + h/w_claim) is ~226 KB; the
OPENING layer (z + w1 + tags) is 99.8% of the artifact. This is the
round's load-bearing designed-vs-built gap number: the designed
eval-proof/aggregation layer (BB items 4-6, unbuilt) replaces exactly
the opening volume; the C-03 accounting predicted this class of
number and the trench's whole architecture exists to remove it. The
Tier N gate is NOT met by this statement and is not claimed.

### 2.5 Freeze rows (UAGB1-2a..2d)

Battery-shape layout (320 data cms, cap 131 = 134-1-2, 3 waves, 1
pad cm, acc 25); full-shape layout (2,944 data cms, 23 waves, 2,993
commitments, acc 25); the wave budget tight both directions (cap
fits, cap+1 busts); the accumulator interval at inner 768 pinned
equal to the D1 class. All derived, none extrapolated
(aggregation_freeze_rows.py citation: the gamma gate matches row
H-gate-ed = 28 - log2(2*29.4) = 2^22.12).

## 3. Walls and findings

1. **The C2 recipe holds at the full shape** — the load-bearing
   engineering answer for the round: 2,944 data commitments across
   23 first-fit waves at cap 131, one sumcheck + 9 masked pin claims
   + closing round; no capacity wall, no memory wall (1.13 GiB peak
   on a 256 GiB box), prove 45 s / verify 4.2 s [MAC-BOX] at the
   125M layer shape. The multi-wave machinery (U-R1/U-Z1) consumed
   as-is; no parallel wave layer was built.
2. **The opening layer is 99.8% of the counted artifact** (Section
   2.4) — the designed aggregation layer replaces exactly this; no
   other component is within two orders of magnitude of the gate.
3. **F-BB1/F-BB2/F-BB3** (Section 1.4): the exact-digit branch is
   the engine's only sign-binary base; the balanced Gaussian chain
   rejects wide value classes at q31 that the exact path accepts;
   full-column recomposition is mod-q native.
4. **Statement-typing gaps recorded, not resolved silently:** (a)
   QuantMeta lacks a symmetric-range field ([-127,127] vs declared
   [-128,127] — diverges at inner 2048: 27 vs 26 accumulator bits);
   (b) the typed v3 class/base manifest fields + 32-row maps
   (E-O1-BB full form) belong to the pass-statement stage in one
   versioned codec change — the class declarations are bound through
   the model digest here, with the wrong-base negative vector green.

## 4. Exports to BA / BC / orchestrator

- To BC (battery lane): the matmul statement rig
  (`uagb1_matmul_run`) is the hook for AZB legs when items 4-5 land;
  none of E-1..E-11 are unlocked by items 1-2 (all bind the
  aggregate/T_blind/eval-proof/IXF layers). The rig's own hash-edge
  F5 pairs (stale-alpha, stale-order) are lane batteries, not AZB
  legs, and are not claimed as such.
- To the orchestrator: E-O1-BB PARTIAL (digest binding + negative
  vector landed; typed fields deferred to the pass statement with
  reason); E-O2-BB structural predecessor asserted (one wave round
  per commitment), builder-refusal semantics land with the
  eval-proof openings; E-O3-BB N/A at items 1-2 (no descent in the
  matmul statement; D1's descents per-instance by design). F-Z1
  schedule: no floor exists yet at items 1-2.
- Verify-time context for the O-5 plan: the 4.2 s pre-aggregation
  verify at the full shape is dominated by per-wave ct-round
  re-verification — the aggregate verifier model (0.14-0.52 s
  PARAMS 5.3 [MODEL]) replaces it wholesale.
