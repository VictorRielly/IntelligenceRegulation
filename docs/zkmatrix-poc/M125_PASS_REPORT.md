# M125 Pass Report — U-AG-B1 lane BF: the 12-layer 125M P0 pass on real weights

Status: LANE DELIVERABLE (2026-08-09/10, U-AG-B1 wave 2, Agent BF).
Ledger: PROGRESS_UAGB1.md "Agent BF status". Machine: Victor's Mac
(Apple silicon, 256 GB) — NOT the contract reference box; every
timing is [MAC-BOX, non-reference], with [NOISY-SHARED] where sibling
lanes were running. Byte counts, battery verdicts and digests are
machine-independent.

## 0. Scope and honest labels

- **What is proven:** each of the 12 FFN layers of the frugal-lm
  125M checkpoint ckpt-00009536 (the completed 2.5e9-token run), at
  the contract workload T = 512, against ONE validated 12-layer v4
  pass statement — per layer: the three full-shape dense committed
  matmuls (gate/up at 512x768x2048, down at 512x2048x768), the SiLU
  lookup at the layer's calibrated per-scale table, the gate-o-up
  Hadamard, all four requantization edges, and every range fact the
  statement declares (remainders + int8 narrowings).
- **Mode: P0** (verification-only; TARGET_CONTRACT Amendment A1). No
  privacy claim is made. Weight commitment randomness rides PUBLIC
  per-entry seeds (the "weights committed once, model identity
  public" reading — this is what makes the wrong-weight battery leg
  a statement-gate reject). Byte totals are OPENING-DOMINATED until
  lane BD's aggregation stack lands; the monster number is reported
  in Section 5, not hidden.
- **FFN-only scope** (the honest label carried since BB's D3
  skeleton): each layer takes a fresh committed X — the mlp_norm
  output of the QUANTIZED end-to-end walk — and declares its z
  output. The inter-layer edge (RMSNorm + residual) is not
  integer-specified (TARGET_CONTRACT Section 1) and is NOT wired.
- **Witness = the real int8 model's pass** on one held-out
  fineweb-edu-val sequence (seeded window construction identical to
  the calibration study's; the sequence is inside BC's measured
  0-violation set).

## 1. Deliverable 1 — the per-scale SiLU table family (D3-F1 closed)

The frozen `silu-int8-table-v1` pins frac 4 on both sides; the
calibrated 125M gate scale is eGate = -3 on 10 of 12 layers (D3-F1,
integration-blocking). The family `silu-int8-table-v2`
(`ring/lookup.rs`, [UAGB1-BF] section) generalizes the construction
to a signed exponent pair.

**Generation spec (byte-identical regeneration):** for a member
(eGate, eA), over the full int8 domain g = -128..=127:

    S[g] = clamp( floor( silu(g * 2^eGate) / 2^eA + 1/2 ), -127, 127 )

with silu(x) = x / (1 + e^-x) evaluated in IEEE-754 f64,
floor(x + 1/2) = round_half_up (the v1 rounding rule), and the clamp
declaring totality (it never fires on either frozen member —
freeze-checked). Protocol semantics do not depend on a platform's
libm: the FROZEN BYTES in `ring/lookup.rs` define each member; the
generator exists so the freeze rows make platform drift loud
(the v1/LKP-1 discipline). The Python replica in
`scripts/m125_export_ffn.py` implements the same formula and asserts
the same digests before exporting.

**Frozen members** (every exponent the 12 calibrated layers need;
eGate == eA on all layers):

| member | layers | bytes | v2 spec digest |
|---|---|---|---|
| (-3, -3) | 0, 2, 3, 5-11 | `SILU_V2_M3_OUTPUTS` (min -2, max 127) | bdf8bc7129dc6ec8..c9bb6c50 |
| (-4, -4) | 1, 4 | `SILU_INT8_OUTPUTS` — BYTE-IDENTICAL to v1 | 063993481a8fc008..acd17ada |

**The family identity, load-bearing:** under round_half_up the
(-4,-4) member IS the v1 table byte-for-byte, so the v1 table, its
spec header and its digest DO NOT MOVE — the v2 digest of that
member differs only because the v2 header carries signed
`scale_exp` fields instead of `frac_bits`. The v2 spec-header JSON
(`table_spec_digest_v2`):

    {"function":"silu-int8-table-v2",
     "input":{"width":8,"scale_exp":E_GATE,"signed":true},
     "output":{"width":8,"scale_exp":E_ACT,"signed":true},
     "rounding":"y = clamp(round_half_up(silu(x*2^in_exp)/2^out_exp), -127, 127)",
     "table":[[-128,S_0],...,[127,S_255]]}

Non-frozen exponent pairs are refused (`silu_v2_member` returns
None) — statements cannot reference tables that were never frozen.

**Freeze rows (both directions, in `freeze-check`):** UAGB1-BF-1a
regeneration reproduces frozen bytes + pinned digests for both
members; 1b the family identity (generate(-4,-4) ==
SILU_INT8_OUTPUTS; v1 digest unmoved, lookup.rs == manifest.rs); 1c
member separation (m3 != m4 != v1 digests; non-frozen pair refused);
1d the clamp never fires + the m3 output range [-2, 127].

## 2. Deliverable 2 — manifest v4: the one versioned codec change (D3-F2 + E-O1-BB + the symmetric-range export)

Landed in `src/manifest.rs` as Statement v4 ALONGSIDE v3 — the v3
rules, digest bytes and cv1 wire bytes are untouched (enforced, not
asserted: freeze row UAGB1-BF-2b pins the v3 reference digest and
wire; the v3 `statement-125m` digest 7b913619fbffa5da was verified
unmoved through the full self-test).

Per-entry `TypingV4 { scale_exp: i32, symmetric: bool, class: u32,
base_e0: u32 }` plus a statement-level table family
`tables: Vec<TableSpec>`:

1. **Signed scale exponents** (D3-F2 closed): value = raw *
   2^scale_exp; the calibrated eZ = +1 (layers 0/2/11) and eH = +2
   (layer 2) are expressible directly — the D3 skeleton's frac-0
   clamps and widened 9/10-bit storage disappear (the pass statement
   has ZERO surrogate deviations, vs the skeleton's 14).
2. **The symmetric range declaration** ([-127,127], the convention
   BC's study proved FORCED by the contract's own 27-bit row): a
   signed symmetric entry covers +-(2^(b-1)-1), and the validator's
   own interval arithmetic then DERIVES the honest 125M accumulator
   rows — 25-bit at inner 768, 26-bit at inner 2048. The
   asymmetric-declared-type divergence (27 bits at inner 2048) is
   now a machine-checked REJECT, not a recorded footnote.
3. **E-O1-BB class/base fields:** every entry declares its
   value-width class and digit base against a frozen 5-class
   registry (CLS_W8S e0=1 sign-binary per F-N2; CLS_ACT8 / CLS_ACC /
   CLS_REM / CLS_AUX31 e0=2 — AGGREGATION_ENCODING_DESIGN 8.1's
   frozen widths and adopted bases). Wrong-class and wrong-base
   statements reject pre-crypto (the E-O1-BB negative vectors, now
   TYPED rather than digest-bound).
4. **The table family + LookupAt** (D3-F1 at the statement level):
   `tables[]` must equal frozen registry members exactly (the C-03c
   discipline extended); `Operation::LookupAt { x, y, table }` picks
   the member per operation, and operand typing must match the
   member's signed scale — declaring the wrong member for a layer's
   exponent rejects at validation.
5. **RangeLookup** (the U-R2 exact range mechanism as a statement
   form): a range fact discharged by a [0, 2^width) range-table
   lookup instance — no bit-plane entry, no Binary fact. Accepted as
   a rescale remainder fact and as a calibrated-narrowing fact.
6. **Version gates:** v3 statements must carry no typing/tables and
   no v4 operations; v4 requires full typing, rejects plain Lookup
   and header tables; digest tags differ
   (zkmatrix-statement-v3 / -v4); codec containers pair (cv1 <-> v3,
   cv2 <-> v4) with structured rejects on mismatch.

**Battery** (`m125-pass v4-battery`, 19 legs green): v4 base
validates with the positive exponents un-clamped; v3 sample bytes +
digest preserved; v4 cv2 round-trip byte-identical; the
symmetric-vs-asymmetric accumulator pair at the REAL 125M inner dims
(26-bit @ 2048 ACCEPTS symmetric / REJECTS asymmetric); wrong-class,
wrong-base; both version-gate directions; bad table index,
off-registry table, wrong-member scale mismatch; nonzero v4
frac_bits; symmetric-on-unsigned; remainder RangeLookup deletion ->
MissingRangeFact; both codec-pairing directions.

Freeze rows: UAGB1-BF-2a (manifest family digests == lookup.rs
generation; registry = [v1, m3, m4]; class-table e0 pins), 2b (v3
reference digest f2a5acba.. + cv1 wire pinned), 2c (v4 reference
digest 9f83d3e9.. pinned).

## 3. Deliverable 3 — the pass: exports, witness, statement

### 3.1 Exports (scripts/m125_export_ffn.py; READ-ONLY against frugal-lm)

36 weight tensors read via the calibration script's pure-numpy
safetensors reader, quantized int8 at 2^-9 (0 saturations),
transposed to the matmul layouts (WgT/WuT 768x2048, WdT 2048x768);
per-layer X [512, 768] int8. Binary exports land in
results/m125_ffn_export/ (git-ignored; regeneration = one script run
under the frugal venv); manifest.json + digests.txt (committed)
carry SHA-256 digests of every tensor, the calibrated scale table,
the derived shifts, and per-layer z digests from a full Python
witness-chain replica.

**Finding BF-F1 (the X construction matters).** The first export
captured X from the fp32 REFERENCE walk and the z range facts FAILED
on layers 2 and 6 (3 violations) — the loud-fail path working as
designed on a witness construction that is a hybrid neither
calibrated nor claimed. The correct construction is BC's variant A:
X = the QUANTIZED end-to-end walk's own mlp_norm outputs (int8 FFNs
feeding forward through fp32 attention/norms), i.e. the actual int8
model's pass. Under it: **0 range-fact violations across 12 layers x
5 fact classes** on the held-out sequence. Consequence worth
recording: a deployment must pin WHICH forward produces the
committed X — proximity of the two constructions does not transfer
the range guarantees.

### 3.2 The witness chain (Rust-derived, cross-checked)

The Rust side (`bf_load_layer`/`bf_derive_chain`) derives the full
chain from X + weights in exact integer arithmetic — floor
requantization x = 2^shift * y + r per TARGET_CONTRACT S2 as written
(the pre-add rounding option is recorded, NOT taken — BB's
disposition), the v2 family table per layer, exact Hadamard — with
derived shifts asserted against the export sidecar, every range fact
asserted at derive time, and the final z byte-identical to the
Python replica's digest on all 12 layers (two independent
implementations of the semantics agreeing end-to-end).

Per-layer shifts (g/u/h/z), from the TRUE signed exponents:
9/9/6/10, 7/8/7/8, 8/9/7/8, 8/7/6/9, 7/7/6/10, 8/8/5/7, 8/8/6/6,
8/8/5/7, 8/8/6/7, 8/8/6/7, 8/9/5/9, 8/9/5/10 (layers 0-11).

### 3.3 The pass statement (v4, all 12 layers)

`m125-pass statement`: **204 entries, 192 operations, 12 declared z
outputs, 2 family tables — VALIDATES and digests
(76dbf2040409333e), 26,116 B serialized (cv2), built in 33.6 s**
(12 chains derived + range-asserted, 196,608 entry commitments
digested). Zero surrogate deviations (the D3 skeleton needed 14).

Per layer: 17 entries (X, WgT, WuT, WdT, Gacc, Rg, g8, a8, Uacc,
Ru, u8, H, Rh, h8, Dacc, Rd, z) and 16 operations (3 Matmul, 4
Rescale, 1 LookupAt at the layer's member, 1 Hadamard, 7
RangeLookup: 4 remainders at [0, 2^shift) + u8/h8/z narrowings at
w8). Typing: X and weights symmetric [-127,127]; accumulators 25/26
honest bits; H 15-bit; z honest 8-bit at eZ = +1 where calibrated.
The model digest binds the layer exponent/shift table, the EXPORT
tensor digests (X + weights — the frozen quantized model), and both
family digests; entry records bind every commitment group digest.

## 4. The per-layer proof (the [UAGB1-BF] runner)

One commitment set, ONE transcript, ONE first-fit wave plan per
layer at the derived C2 cap — every commitment opened in exactly one
wave round (plan bijection; pads + closing per the U-Z1 pattern).
ctx = the PASS statement digest + the layer index; h0 binds every
commitment before any challenge (D-4).

| claim family | mechanism | pins |
|---|---|---|
| 3 matmuls | Thaler degree-2 sumcheck over K per matmul (rx/ry post-commit; inner zero-extended in prover tables; the down matmul's 768-column space zero-extends to 2^10 in the eq WEIGHTS — the honest wave plan at 512x2048x768 derives like any other) | 9 MLE pins |
| Hadamard a8 o u8 = H | ONE degree-3 sumcheck (eq_r * a8 * u8 vs H~(r)); the eq final is verifier-recomputed | 3 pins |
| 4 requant edges | zero-valued MLE pins at transcript points: MLE(ACC) - 2^s MLE(y) - MLE(r) = 0 at random r in K^lv (exactness from the range facts + non-wrap, the D1 recomposition reading) | 4 pins |
| SiLU lookup | fused-pair (g8 + Y a8) masked LogUp descent pair at the layer's FAMILY member (U-K5c machinery; both columns dense — no slot machinery) | descent + 4 leaf pins |
| 7 range facts | per-instance masked descent pairs against [0, 2^w) tables (w = shift for remainders; w = 8 offset-code form for u8/h8/z — the offset folds into the leaf-pin value) | descent + 4 leaf pins each |

All pins (936 at full shape) psi-batch into 9 CtClaims -> the U-Z1
masked share splitter -> per-wave masked ct-rounds + the zero-sum
closing round (the D2 pattern consumed as-is; no new claim family,
no co-location constraints — the all-pins design is what lets the
D2 wave machinery carry a full FFN layer unchanged).

### 4.1 The pass-level battery (real data, T = 16 slice; 6/6 green, 439 s)

| leg | verdict |
|---|---|
| honest layer 0 ((-3,-3) member) | ACCEPT — 5,194 cms, 40 waves, 776 pins |
| honest layer 1 ((-4,-4) member — the family in action) | ACCEPT |
| WRONG WEIGHT TENSOR (layer 1's Wg, chain rederived self-consistently) | REJECT at the STATEMENT gate: the verifier recomputes the weight commitments from the public model (P0 identity discipline) |
| WRONG TABLE for the layer's exponent ((-4,-4) on an eGate=-3 layer; chain, m column and trees all self-consistent) | REJECT: statement, matmuls, descents and roots ALL GREEN — the verifier's STATEMENT-table leaf pins fail in the wave rounds (the sharp new leg) |
| CROSS-LAYER SEAM (layer 1's g8 under layer 0's entry, statement self-consistent) | REJECT: the requant + lookup pins tie g8 to Gacc/a8 across proof instances |
| RANGE VIOLATION (rd pushed past 2^shift, requant identity preserved) | REJECT isolated to the rd instance's root cross-check — every other gate green |

Plus the statement-level wrong-member leg in the v4 battery
(declaring the wrong family member rejects at validation), and the
suite-riding smoke leg (tests/test_uagb1_pass.py).

## 5. Full-shape results (T = 512): ALL 12 LAYERS PROVEN

The committed exit asked for layers 1-2 proven + an extrapolation;
the measured layer-0 wall (6.1 min) cleared the decision rule, so the
FULL 12-layer run went (the brief's "measure layer 1's complete
chain first, decide, and report the decision either way"). Every
layer proven end to end and verified: **12/12 accept = true** — per
layer: the statement gate, 3 matmul sumchecks, the Hadamard
sumcheck, 4 requant pins, 8 lookup root cross-checks, the sum gate,
127 masked wave rounds, and the closing round.

**Per-layer cost table [MAC-BOX, non-reference, ~1T; runs 1-10
NOISY-SHARED with a concurrent suite run]:**

| layer | cms (data/all) | waves | pins | commit | prove | mm | had | req | lkp | pinclaims | waves | verify |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 16,565/16,823 | 127 | 936 | 39.6 s | 285.3 s | 2.5 | 4.1 | 1.1 | 69.2 | 7.4 | 200.2 | 34.2 s |
| 1 | 16,560/16,818 | 127 | 920 | 36.4 s | 268.2 s | 2.5 | 4.1 | 1.0 | 68.9 | 7.2 | 183.9 | 34.1 s |
| 2 | 16,562/16,820 | 127 | 928 | 38.7 s | 254.7 s | 2.5 | 4.1 | 1.1 | 68.8 | 7.2 | 170.1 | 34.0 s |
| 3 | 16,561/16,819 | 127 | 920 | 36.0 s | 275.8 s | 2.5 | 4.0 | 1.0 | 69.0 | 7.3 | 191.1 | 34.2 s |
| 4 | 16,561/16,819 | 127 | 920 | 36.1 s | 264.5 s | 2.5 | 4.0 | 1.0 | 69.1 | 7.2 | 179.8 | 34.3 s |
| 5 | 16,559/16,817 | 127 | 912 | 36.0 s | 289.2 s | 2.5 | 4.0 | 1.0 | 69.2 | 7.4 | 204.2 | 34.1 s |
| 6 | 16,560/16,818 | 127 | 912 | 36.1 s | 266.2 s | 2.5 | 4.1 | 1.0 | 69.1 | 7.1 | 181.5 | 35.4 s |
| 7 | 16,559/16,817 | 127 | 912 | 36.2 s | 266.0 s | 2.5 | 4.1 | 1.0 | 75.1 | 7.4 | 174.9 | 34.5 s |
| 8 | 16,560/16,818 | 127 | 916 | 36.3 s | 282.6 s | 2.5 | 4.1 | 1.0 | 69.4 | 7.2 | 197.5 | 34.3 s |
| 9 | 16,560/16,818 | 127 | 916 | 36.2 s | 263.3 s | 2.5 | 4.0 | 1.0 | 69.0 | 7.2 | 178.7 | 34.2 s |
| 10 | 16,562/16,820 | 127 | 924 | 37.7 s | 284.1 s | 2.5 | 4.0 | 1.0 | 69.1 | 7.2 | 199.5 | 34.2 s |
| 11 | 16,563/16,821 | 127 | 928 | 38.7 s | 275.2 s | 2.5 | 4.1 | 1.0 | 69.1 | 7.3 | 190.4 | 34.0 s |
| **SUM** | | | | **444.0 s** | **3,275.1 s** | 30.0 | 48.7 | 12.2 | 835.0 | 87.1 | 2,251.8 | **411.5 s** |

- Prove: 54.6 min total, ~273 s/layer; wall per layer ~6.1 min
  (367.5 s real measured at layer 0, /usr/bin/time). The per-run
  commit column INCLUDES rebuilding all 12 layers' entry commitments
  for the statement digests (~33 s of each 36-40 s) — a
  single-process 12-layer driver would pay it once.
- **The wave rounds are 68.8% of prove time** (127 ct-rounds/layer
  at ~131 commitments each), descents 25.5%, the three matmul
  sumchecks just 0.9% — the claim layer is cheap; OPENING work
  dominates time exactly as it dominates bytes.
- Verify: 34.3 s/layer, 6.9 min the pass [MAC-BOX 1T] — the
  contract's <= 2 s line binds the AGGREGATE verifier (BD's stack,
  unbuilt); recorded as context, not claimed compliant.
- Peak RSS 12.0-13.5 GiB per layer run (/usr/bin/time -l).
- Determinism: commitments ride fixed per-(layer, entry) seeds, so
  the statement digest 76dbf2040409333e reproduces across runs; a
  P1+ deployment must switch the session stream to OS entropy (the
  rig's ChainEntropy::Os pattern).

**Counted bytes (counted-NOT-serialized, D2 conventions), the
honest P0 monster number:**

| component | pass total | share |
|---|---:|---:|
| statements (serialized, real; 26,116 B x 12) | 313,392 | ~0% |
| commitment tags t1+t2 | 1,653,374,976 | 20.9% |
| sumchecks (3 matmul + Hadamard x 12) | 142,848 | ~0% |
| masked descent transcripts (16/layer... 8 pairs) | 8,528,960 | 0.1% |
| masked share reveals | 164,592 | ~0% |
| ct-round z responses | 5,414,043,648 | 68.3% |
| ct-round w1 images | 832,929,792 | 10.5% |
| ct-round h + w_claim | 14,155,776 | 0.2% |
| **PASS TOTAL (12 layers)** | **7,923,653,984 B = 7.38 GiB** | |

Per layer: 660.3 MB avg = **2,518.9x the Tier N 262,144 B/layer P0
gate**. The OPENING layer (z + w1 + tags) is 99.7% of the artifact;
the claim layer proper (statements + sumchecks + descents + reveals
+ h/w_claim) is ~1.9 MB/layer. This is the wave-1 D2 finding at
pass scale: BB's single-matmul statement measured 447.8x with 3
tensors; a full layer carries 17 entries + 16 descents' aux, hence
~5.6x more opening volume. The designed eval-proof/aggregation
layer (lane BD) replaces exactly the 99.7%; per the U-AG4 tables
the folded W-C pass target is the 0.3-0.5 MiB class [MODEL until
BD lands]. Tier N is NOT met and NOT claimed.

## 6. Housekeeping

- **4a** tests/test_zk_lattice.py test_opening_proof_roundtrip:
  entropy pinned per the file's own Pi1/Pi2 precedent (seed
  0x5EED_0165); asserts unchanged; 25/25 consecutive runs green
  (was ~2-3%-class flake under OS entropy).
- **4b** scripts/aggregation_folding_spike.py: ru_maxrss print-only
  Darwin fix (bytes vs KiB; was "39168 MiB", now "38 MiB"); checks
  untouched; spike 33/33.

## 7. Findings and walls

- **BF-F1** (Section 3.1): the committed-X construction must be
  pinned to the quantized walk; the fp32-reference hybrid fails z
  facts on 2 of 12 layers.
- **BF-F2**: the all-pins composition holds at full FFN-layer scale
  — three matmul sumchecks, a degree-3 Hadamard sumcheck, four
  requant identities and eight masked lookup instances ride ONE
  first-fit wave plan and the EXISTING psi/splitter/ct-round
  machinery with zero new claim families. The D2 multi-wave recipe
  is genuinely generic.
- **BF-F3**: tree-capacity fit — the gkr_masked witness block holds
  2^(d-1)-4 elements, so the 2^20-element tensors ride dw = 22 with
  (0,1)-dummy padding (~2x tree work). A capacity-exact variant
  (2^20-4 + 4-element split) would halve descent time; not taken
  (measure first — descents are not the dominant cost; waves are).
- **Wave rounds dominate prove time** (~70% at full shape): 127
  ct-rounds at ~131 commitments each. This is exactly the opening
  volume BD's aggregation stack exists to replace.

## 8. Freeze rows added by this lane (all in `freeze-check`)

UAGB1-BF-1a..1d (the family), UAGB1-BF-2a..2c (v4/v3 digest
stability) — every pre-existing row green and unmoved.

## 9. Wave-4 addendum (2026-08-11, lane BJ): BF-F3 closed at the rig — the split-fill capacity wired in

Finding BF-F3 (Section 7: witness blocks capped at 2^(d-1) - 4, so
2^20-element tensors rode dummy-padded dw = 22 at ~2x tree work)
was lifted by lane BH in wave 3 (`gkr_masked::witness_leaf_positions`,
capacity n - 8, measured 2.03x at the standalone `bh-verifier gkr`
rig) and exported to this rig as wiring
(UAGB1_VERIFIER_REPORT.md Section 2.4). Landed here:

- **`bf_dw_for`** derives depth against the split-fill capacity
  n - 8 (was: the blinder-free front 2^(d-1) - 4). At T = 512 the
  six nf-class instances (silu, rng-rg/ru/u8/rh/h8; 2^20 elements)
  drop dw 22 -> 21 and the two nd-class instances (rng-rd/z;
  393,216 elements) drop 20 -> 19. At the battery scale (T = 16):
  17 -> 16 and 15 -> 14.
- **`leaf_pins`** (the four aggregate leaf pins wp/wq/tp/tq, shared
  by prover and verifier): the witness-side weights move from the
  contiguous assumption to the PUBLIC map — `hw` and the
  primary/pair committed-column weights index `lw` at
  `witness_leaf_positions(n_el, 2^dw)`; the dummy-mass complement
  `ddw` and the blinder terms are unchanged in form. The trees
  already rode the map inside `blinded_witness_tree` (BH's change);
  the root cross-checks are position-invariant (fraction-tree sums),
  which is why ONLY the pin layer could see the map.
- **Acceptance (the exported test): the WRONG-MAP battery leg** —
  `BfTamper::WrongMap`: honest proof on split trees, the VERIFIER's
  leaf pins recomputed under the pre-lift contiguous assumption ->
  **REJECT in the wave rounds** with statement/matmuls/roots all
  green (the position map is load-bearing at the rig), plus a
  precondition leg asserting the map is NON-IDENTITY at the battery
  shape (4 right-half leaves at n_el = 32,768, dw = 16).
  **`m125-pass battery small`: 8/8 green, 558.2 s** [MAC-BOX,
  NOISY-SHARED — the AZB-11 canary overlapped] — all six
  pre-existing legs keep their exact reject surfaces on split trees.

**Measured effect** [MAC-BOX, non-reference, QUIET, single-shot;
BEFORE = the pre-wiring binary (this HEAD minus the D3 commit),
AFTER = this HEAD, same box, back to back]:

| measurement (layer 0, T = 512 unless noted) | BEFORE | AFTER | effect |
|---|---:|---:|---:|
| prove | 288.5 s | 250.4 s | **-13.2%** |
| ... lkp (descents) phase | 69.9 s | 35.1 s | **1.99x — BF-F3's ~2x, at the rig** |
| ... waves phase | 202.9 s | 199.5 s | ~ (127 waves both) |
| verify (its lkp phase) | 34.6 s (5.9) | 31.9 s (3.1) | -7.8% |
| wall (/usr/bin/time, incl. 12-layer chain load) | 372.3 s | 330.7 s | -11.2% |
| peak RSS | 12.08 GB | 13.29 GB | +10% (single-shot; not a gate) |
| masked descent transcripts (counted, this layer) | 722,816 B | 674,176 B | **-48,640 B/layer** |
| data cms / pins | 16,565 / 936 | 16,551 / 904 | -14 / -32 |
| statement (serialized) | 26,116 B | 26,116 B | unchanged (digest stable) |
| `battery smoke` total (T = 16) | 74.8 s | 81.7 s | +6.9 s — see BJ-F1 |

- The **~10-12% pass-prove class** BH's export predicted lands at
  **13.2% on the measured layer** (descents were 24.2% of prove;
  the witness side halved on six dw 22 -> 21 instances and two
  20 -> 19). Extrapolated to the 12-layer pass prove (Section 5's
  3,275 s class): ~-460 s [MODEL from the one measured layer].
- The **byte delta is exact kel arithmetic**: -48,640 B/layer =
  6 x 6,208 (the (22 -> 21, dt 9) per-pair bonus BH measured) +
  2 x 5,696 ((20 -> 19, dt 9) pairs). Kel-row freeze values pin
  the FUNCTION at given dw and are unmoved.
- **BJ-F1 (small-shape packing artifact, recorded):** at T = 16
  the smoke TOTAL rose 74.8 -> 81.7 s even though descents
  strictly shrink (dw 17 -> 16, 15 -> 14) — the depth drop
  repacks the first-fit wave plan (40 -> 39 fuller waves at
  T = 16; commitment count -10), and the wave rounds are the only
  phase that grows. At T = 512 the wave count is unchanged (127)
  and every phase moved down. Verdicts are unaffected (8/8);
  battery wall-clock at the small shape pays ~10%, the real
  target shape gains 13%. [MAC-BOX, single-shot both.]

**Derived-line movement (recorded, not hidden):** `pass-agg
expect`'s 125M-STRUCTURAL [MODEL] descent lines ride `bf_dw_for`;
every structural dw drops by 1: total 959,232 -> 898,496 B (0.915
-> 0.857 MiB); full-statement expectations Tier N 1,385,854 ->
1,325,118 B, P2 1,978,466 -> 1,917,730 B (UAGB1_PASS_AGG_REPORT.md
Section 9.5 carries the same note; wave-4 stage 2 targets the
updated lines). No freeze row pins these; every pre-existing
freeze digest is unmoved at this HEAD.

---

*Changelog: 2026-08-11 — wave-4 addendum (lane BJ): BF-F3 wired
into the rig (split-fill depths + mapped leaf pins; wrong-map leg
8/8; measured effect + derived-line movement in Section 9).*

*Changelog: 2026-08-10 — first edition (U-AG-B1 wave 2, lane BF):
the per-scale SiLU table family frozen (two members, (-4,-4) == v1
byte-identity); manifest v4 typed codec (signed exponents,
[-127,127] symmetric, class/base fields, table family, RangeLookup)
with v3 bytes/digests unmoved; the 12-layer 125M P0 pass statement
(204 entries, v4, 0 surrogates) VALIDATED and ALL 12 LAYERS PROVEN
end to end on ckpt-00009536 at T = 512 (12/12 accept; prove 54.6
min, verify 6.9 min, 7.38 GiB counted = 2,518.9x Tier N/layer,
99.7% opening volume) [MAC-BOX]; pass tamper battery 6/6; finding
BF-F1 (the committed-X construction must be the quantized walk);
housekeeping 4a (flake pinned, 25/25) + 4b (Darwin RSS print).*
