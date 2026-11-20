# Research handoff: which committed activation planes need not be committed, and a ranked summary of cycle 6 (2026-11-16, claude-cycle 6c)

From Claude, the standing researcher (D50). Part C of a three-part session (6a lookups, 6b small values, 6c linear chains), with
the ranked summary across A-C at the end (§7).

**Scope.**
- **Local counting plus a little web reading.** Read the plane layout and the zero-check relations of the W16R2 block; 2 searches
  and 3 fetches on published systems. No build, prover run, GPU run, Git write. Written: this file,
  `20261116-claude-cycle6c-linear-chains.py` (standard library, reads no file; it asserts the census's per-domain plane counts and the 2,279
  data rows) and a STATE.md entry.
- **Triage material, not a work order.** Every candidate changes what is committed and what the verifier checks, so it needs the
  owner's ruling, a new profile string (D17) and re-proved Lean statements (D63). Not a privacy acceptance.

Labels: **COUNTED** (file:line), **MEASURED**, **[AUTHORS]**, **[abstract]** / **[summary]**, **DERIVED** (script or argument),
**ASSUMED**.

## 0. Headline

- **Cycle 4's near-zero for chaining linear layers is confirmed, with a more exact count.** Only **two** committed activation
  planes are linear images of other committed planes: the residual sums **X1 = X + AO and X2 = X1 + Z** (64 rows per block, 1.25%
  of 5,103) (`slot_ir_accuracy.rs:485, 488`). The rope remainders (RQRL, RKRL, 40 rows) are linear with public tables. Everything
  else is the output of a rounding, lookup, norm or division, a digit witness, or **the committed form of an uncommitted accumulator**:
  a matmul output is already virtual and is carried as `2^s * word + remainder digits` (the `host_*` terms,
  `slot_ir_accuracy.rs:494-495`, `611-612`, `693-695`). The word and its remainder are how the accumulator is committed, so neither can be
  dropped by chaining.
- **A different mechanism removes more, and I did not find it in the Lean-found list C1-C13** (`ZK60_LEAN_L1L2_FINDINGS_20261106.md`
  §6, §12, §18): **remainder planes whose value the relation already determines pointwise** need not be committed. The
  lookup then queries the expression. Per block, **424 of 2,279 A data rows (18.6%; 8.3% of the 5,103 committed rows)**:
  L1 104 rows (linear or public-table), L2 192 rows (single-limb degree-2 remainders: SR, SG, RH), L3 128 rows (top limbs of norm
  remainders). [COUNTED classes; DERIVED volume; script]
- **Volume effect** (DERIVED): per request 43.19 GB of codewords to **39.6 GB (91.8%)** alone; together with 6a's helper retirement
  **18.7 GB (43%)**; together with 6a and 6b's 31-bit base field **9.4 GB (22%)**.
- **Prover time is not what this buys.** 424 rows x 18.8 us per row (measured anchor, commits A + H 0.096 s per block on Metal)
  is **8 ms of a 470 ms warm block (1.7%)**; any extra zero-check work from the higher-degree queries eats into that. The
  receipt loses 0.95 MB per block of opened column data (8.3% of the 372 MB column data).

## 1. The plane list and the classification

W16R2 plane list: `accuracy_layout.rs:122-160` (`new_w16`), `shape.rs:2466-2489`; limb counts from `range16.rs:114-120` (`limbs_of`:
1 limb up to 16 bits, else 2). The W16R2 limb counts follow from the census plane counts and are cross-checked against the
census's lookups per position (D 19, Q 6, Kv 6, F 7, S 7; `census.log:218-237`): ao = down = 2, score = 2, ws = 1, gate = 2, h24 = rh = 1.

**Classes.** M: must commit (chain input; output of a rounding, lookup, norm, division, or digit extraction; digit witness; committed
form of an uncommitted accumulator). L1: linear (or public-table elementwise) image of other committed planes. L2: single-limb
remainder equal to a degree-2 expression of committed planes. L3: the top limb of a two-limb remainder whose total is determined by
committed planes and the low limb.

| Domain (rows per plane) | M planes | L1 | L2 | L3 | Source of the relation |
|---|---|---|---|---|---|
| D (32) | X, Y, YM, AO, Z, NR0, NS0, MR0, MS0, RAL0-1, RDL0-1 = 13 planes, 416 rows | X1, X2 = 64 rows | none | NR1, NS1, MR1, MS1 = 128 rows | `slot_ir_accuracy.rs:483-488` (norm clauses c0-c4, residuals c2, c5), `494-495` (host requant) |
| Q (32) | Q, QR, O, RQL, RO = 5, 160 rows | RQRL = 32 | none | none | `:596-605` (rope clause), `:611-612` |
| Kv (8) | K, V, KR, RKL, RVL = 5, 40 rows | RKRL = 8 | none | none | same |
| S (32) | S, RSL0-1, ZSEL, E, P = 6, 192 rows | none | SR0, SG0 = 64 | none | `:670-679` (softmax c0-c3), `:693-695` |
| F (128) | G, RGL0-1, A_SCALED, U, RU, H, HT = 8, 1,024 rows | none | RH = 128 | none | `:534-537` (product f0), `:538-550` (ACT query) |
| T, Ht, L, Tab | 4 + 2 + 2 + 15 = 23 rows | none | none | none | tokens' statistics, softmax max and sum, isqrt limbs, tables |
| **Total rows** | **1,855 (81.4%)** | **104 (4.6%)** | **192 (8.4%)** | **128 (5.6%)** | of the 2,279 A data rows |

Why each class (the relations are `slot_ir_accuracy.rs` clauses, W16 forms):
- **L1.** `x1 - x - ao = 0` and `x2 - x1 - z = 0` (`:485, 488`); `rope: cos*src + sin*flip - 2^SH*rot - rem + 2^(SH-1)` (`:596-605`)
  with public `cos`, `sin`.
- **L2.** `c2: 2^fp * mask * e - p * sum - sr` and `c3: sg + sr + 1 - sum` (`:672-679`): `sr` and `sg` are single 16-bit limbs fixed by
  the committed `e`, `p` and the per-token `sum`. `f0: a*u - 2^r*h - rh + 2^(r-1)` (`:534-537`): `rh` is a single limb fixed by `a`, `u`, `h`.
- **L3.** `nr` (`c0`) and `ns` (`c1`: `nr + ns + 1 - den*id`) are fixed by `x`, `y`, `id` and the public `gamma`; with the low
  digit committed, the top digit is `(value - low) * 2^-16`.
- **Not derivable, and why.** The requant remainders (RAL, RDL, RQL, RKL, RVL, RO, RGL, RU, RSL) depend on a matmul accumulator that
  has no pointwise form: it is non-local (a sum over the inner dimension). The pulled-back arrays **E** and **A_SCALED** are read
  pointwise by clauses (`c2`, `f0`), so a Logup*-style virtual pullback, which gives only an evaluation at a random point, does not
  apply. H's top limb HT is a digit extraction. `delta = mx - mask*(s8+127) + 127` is **already virtual** in this design
  (`:664-667`), as are all matmul outputs.

**How a derived plane would work in the zero-check** [DERIVED, not designed]: the lookup's query value becomes the expression;
the helper clause `h*(alpha - v) - 1` rises one degree; the plane's own clause (`c2`, `c3`, `f0`, rope, the limb identity)
becomes a definition and disappears; the multiplicity histograms are unchanged; the terminal check evaluates the expression from the
other planes' openings (composition of polynomials, not a product of MLE evaluations). Pads: the clauses are gated by the support
tables (`gated(gf, ar)`); how the pad-zero rule treats a derived plane is **not checked** (ASSUMED to need a review of `pad.rs`).

## 2. What published systems do (and what I could verify)

| System | Intermediates | ZK for uncommitted ones | Reading |
|---|---|---|---|
| zkLLM (arXiv 2404.16109) | commits Z, round(z-hat), digit tensors, outputs; **Z' = Z - round(z-hat)*1^T is not committed**, enforced by a sumcheck relation | "zero-knowledge variations of sumcheck" with Pedersen/Hyrax; guarantee for **model parameters only**, verifier semi-honest; no masking detail per message | read (first 100,000 of 159,000 characters) [AUTHORS] |
| FlashProve (Goldilocks, hash-based) | "for each segment the prover commits to the intermediate values, the trace"; reduces to "linear claims about what was committed" and weight-table claims | "random masks hide the values sent along the way"; masks committed at the start of the chain | fetch-tool summary of `docs/protocol.md`; the format spec §11 was not read |
| zkGPT (ePrint 2025/1184, USENIX Security 2025) | not stated in what I read | abstract: privacy of **model parameters** | [abstract]; GPT-2 in under 25 s [AUTHORS] |
| DeepProve (ePrint 2026/1112, CCS 2026) | sumcheck and lookups for all operators of GPT-2 and Gemma 3 | not stated | [abstract / search listing] |
| TensorZKP (ePrint 2026/1250) | HyperPlonk + Brakedown, 2^25 gates in 215 ms | not claimed in the abstract | [abstract]; performance only |
| Libra / Barretenberg ZK-sumcheck | n/a | a small random polynomial masks each round message (log-many coefficients); final evaluations masked separately | [summary of search results] |

**Reading.** The published systems that hide intermediates (FlashProve) commit the trace; the ones that skip commitments
(zkLLM's Z') hide only weights. I found **no published construction that both leaves an intermediate uncommitted and proves it
hidden** for activations; the project's own approach (accumulators carried through `host_*` terms, CFS masks on round messages,
`zk.rs` (b)(i), per `ZK_DESIGN_NOTE.md` §2) is already further than what I could read. For a derived plane the ZK needs: no opening
of the plane (nothing to leak by openings), round messages that involve the expression masked as today, and the mask degree raised by
one (a message with one more coefficient; the masking table has room: `ZK_DESIGN_NOTE.md` §4, specs of at most 182 + 256 pads in 512).
**Unverified: that the simulator argument survives; it is a Lean-statement and review item, not a derivation here.**

## 3. Derivation: committed volume (script, DERIVED)

| Scenario | Rows removed per block | Request codewords (43.19 GB) |
|---|---:|---:|
| C-a: L1 only | 104 (2.0%) | 42.32 GB (98.0%) |
| C-b: L1 + L2 | 296 (5.8%) | 40.70 GB (94.3%) |
| C-c: L1 + L2 + L3 | 424 (8.3%) | 39.63 GB (91.8%) |
| 6a G2 + C-c | | 18.66 GB (43.2%) |
| 6a G2 + C-c + 6b B2 (31-bit base) | | 9.41 GB (21.8%) |

The 5090 write floor at an assumed 1.792 TB/s for 9.41 GB is 5.3 ms against the plain int8 pass's 4.4-5.0 ms: **1.05-1.2x**, not 2x,
and none of it counts the GKR work and the sumchecks that replace what is removed.

## 4. Candidates, each with a falsifiable test

- **H140: derive the L1-L3 planes instead of committing them (424 rows per block).**
  - *Test 1 (count, no prover run).* Mark the eleven planes (X1, X2, RQRL, RKRL, SR0, SG0, RH, NR1, NS1, MR1, MS1) virtual in the
    layout and re-run the census test; **kill if A rows per block do not fall from 2,501 to 2,077** (it would mean the layout ties a plane
    to a slot I read as a definition).
  - *Test 2 (cost, shared Metal GPU needed).* Raise the helper clause degree in a block fork's slots D, Q, Kv, S, F and time them;
    **kill if the added zero-check time exceeds the 8 ms per block that 424 rows of commit are worth** (18.8 us per row; 1.7% of 470 ms).
  - *Expected effect.* (i) committed words **-8.3%** (rows), receipt **-0.95 MB per block** of opened column data; (ii) tokens per second
    **x1.00-1.02** [DERIVED from the measured commit anchor; the rest of the work moves in the other direction]. Rank low on speed, mid
    on bytes. Overlaps: C3 and C9a of the Lean list change the S and F planes; C9a moves SR and SG onto the causal triangle, so
    their saving here shrinks (about half of the 64 rows).
- **H141: residual sums only (L1's X1 and X2, 64 rows, 1.25%).** The cleanest case: linear, no degree change. *Test:* the same count
  (A rows 2,501 to 2,437); kill if the block-boundary design needs X2 as a separately committed plane for the chain link
  (`boundary.rs`; unread here). Expected (i) -1.25%; (ii) none.
- **Dropped:** chaining linear layers through matmul outputs (already virtual); Logup*-style virtual E and A_SCALED (read pointwise);
  derived requant remainders (accumulator not pointwise).

## 5. Corrections and cautions

- Cycle 4 §5 said "the expected cut by chaining alone is near zero": confirmed (64 rows linear). The new 424-row class is not chaining; it
  is the removal of planes that a relation determines. Cycle 4's "11.6% matmul in/out rows" ceiling is unchanged.
- The census lists 71 A planes (19+9+6+8+6+4+2+2+15); cycle 4's table prints 69 in its "Data rows" line, a summing slip. The rows (2,279) are
  right and are what every number here uses.
- Additivity of 6a, 6b, 6c in the combined rows is **assumed**: derived quadratic queries are harder in the LogUp-GKR design (the leaf
  claim over a product needs an extra sumcheck term per domain; `ZK_DESIGN_NOTE.md` §3 covers linear queries only), and the small-field
  exactness issue of 6b applies to the derived values too.
- I did not read `boundary.rs`, `pad.rs` or the Lean statements; a derived plane may change the proved relation families and their
  "one position at a time" statements (`MVP_STATUS.md`, 2026-11-06 entry).
- zkGPT, DeepProve and TensorZKP are abstract-level; FlashProve is a tool summary; zkLLM half read.

## 6. Status

- New full-stack proofs, passes and proved positions: **0 / 0 / 0.** The complete private 8B at >= 50 proved tokens/s remains
  **unachieved**. Hypotheses: **141** (H138, H139 in 6b; H140, H141 here). Cumulative this session: 19 searches, 22 fetches (the budget was about 36 and 36).
- Pointer posted to `ops/zkp-mvp/RECOVERY_COORDINATION.md`.

## 7. Ranked summary across A-C (committed-volume reduction per request, DERIVED; today 43.19 GB of codewords)

| Rank | Change | Alone | In combination | Main risk |
|---:|---|---|---|---|
| 1 | **6a: LogUp-GKR for every lookup (G2/G3)**: retire the 2,514 helper rows except `u` | **-49 to -51%** (21.5-22.2 GB) | with 3: 18.7 GB; with 2 and 3: 9.4 GB | **Zero knowledge of masked GKR is unpublished at this scale** and the local design is unreviewed (joint-view simulation over 25 layers); needs a new profile, the whole Lean statement set, and buys x1.07-1.25 speed at best |
| 2 | **6b: 31-bit prime base field for the small and mask rows** (4 B symbols; helpers unchanged in bytes) | **-25.5%** (32.2 GB) | with 1: 11.2 GB | Full-stack field rewrite (the parked H116); **soundness of small-field codes** (Fenzi-Sanso 2025/2197) and exactness above 2^31 (accumulators 36 bits, norm sums of squares) |
| 3 | **6c: derive pointwise-determined planes** (L1-L3, 424 rows) | **-8.3%** (39.6 GB) | with 1: 18.7 GB | Higher-degree lookup queries (extra product term in the GKR route), re-stated Lean families, mask degree; gives about 1.7% of block time at best |

Larger numbers exist on paper and are **not** ranked: an ideal 4x packing of small rows (-34%) has no mechanism on a prime-field code
(6b); a binary tower (-38%) breaks exact integer arithmetic and has no published ZK. The Lean-found C1-C5 (-11.7%, already
priced) and 6a overlap: C1 (pairing helpers) becomes moot if the helpers go.

Reading the three together: **only the first two are volume levers of the order that matters** (cycle 4: to reach a write floor at 1x
plain int8 the volume must fall to about 20%); both need rulings and neither is cheap. The 21.8% corner needs all three and 6a's ZK
design to hold.

## 8. Next concrete actions (no new permission needed to prepare)

1. Owner or coordinator: record that H136 (6a) is the one lever worth a ZK review before anything else; 6b and 6c depend on it only
   loosely but multiply its effect.
2. H141's count test is a layout edit plus the existing ignored census test; it needs no prover run.
3. Read `boundary.rs` and `pad.rs` before any claim that X2 or a derived plane can leave the layout.
