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

## 2. Deliverable 2 — the dense committed matmul statement

(to be filled: statement layout, wave plan at shape, transcript
order, battery legs + verdicts, measurement table, counted-byte
decomposition vs the Tier N 262,144 B/layer P0 gate)

## 3. Walls and findings

(to be filled)

## 4. Exports to BA / BC

(to be filled)
