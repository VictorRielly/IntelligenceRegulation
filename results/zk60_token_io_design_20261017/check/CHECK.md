# Token I/O design — adversarial check

Checker lane, 2026-10-17 (UTC 19:00–19:25). **Paper only**: nothing built, proved
or measured; no git writes. Object of the check: `../DESIGN.md` with
`../token_io_count.py` / `../token_io_count.json` and `../PROGRESS.md`, against
D12/D12a/D12b, D15–D18, D20–D24, `ZK60_PRIVACY_REQUIREMENTS.md`, and the native
construction read-only (`ops/zkp-mvp/trained-1b/hashline/src/private_block/`
`protocol.rs`, `argument.rs`, `layout.rs`, `run.rs`, `boundary.rs`, `endpoint_g.rs`,
and `zkp-core/src/pcs.rs`). This is not a privacy acceptance and makes no ruling.

Labels: **[COUNTED]** = exact arithmetic, reproduced by `check_arith.py` in this
directory (one thread, under a second; output `check_arith.json`,
`check_arith.out.txt`). Nothing here is [MEASURED].

---

## 1. Verdict in plain words

**The core of the design is sound and is safe to start building as R0 and R1, but only
after three binding changes. One of them is a real soundness accounting hole that
cannot wait.**

* **The input side holds.** Each hidden token pulls exactly its own row of the public
  embedding table, every column, through the boundary into block 0. The challenge order
  is right and the field terms are about 2^-102 or smaller.
* **The output side holds.** The keyed argmax forces numpy's first maximum. A two-hot or
  fractional selector cannot pass, the maximum `M` cannot be understated, and padded
  vocabulary entries are left out of the maximum rather than having to lose. The largest
  integer any clause can reach is below 2^48.1, at least 15 bits under `p`, at both models. A randomised
  check over every candidate index (1,200 cases, extreme and tied logits) found no
  other admissible token [COUNTED].
* **Hole 1: soundness accounting (F-2).** The two new token endpoints are 256-word
  rows carrying 256 zero-knowledge pad symbols. At the encoding rate the design's
  counter assumes (1/4, the run default), that commitment's code has relative distance
  1/2, not 3/4. So each opening fails to catch a bad commitment with probability
  about **2^-67**, not the 2^-106 the design's soundness accounting uses.
  With that geometry the whole proof drops from about 2^-98.7 to about **2^-66**
  [COUNTED]. Fix: encode the token endpoints at rate 1/8. That is exactly the frozen
  toy endpoint's geometry, worth 2^-106.25 per opening, and it costs a few KB of
  receipt. The two small new stages, chosen for receipt size at row widths 2^10 and
  2^11, lose another 10 and 5 bits per opening. At TinyLlama that is −4.2 bits for the
  whole proof. Give every new commitment a width floor of 2^12 (+0.04 M committed
  elements at 8B, +0.39 M at TinyLlama).
* **Hole 2: the hidden selector the design recommends is not bound to the prompt
  length (F-1).** As specified, the selector only has to pick *some* row. A cheating
  prover can return the greedy token after any prefix of the hidden sequence, even
  after BOS alone. The receipt still verifies, and the owner cannot tell. Privacy is
  fine; what the proof means is not. Fix: seal the selector (or the length) under an
  endpoint root that the owner checks. The natural carrier is the two-site input
  endpoint that mode (ii) already needs (R9). The public-row variant of mode (i) does
  not have this problem.
* **Point 3, the tiny endpoint and its low-entropy value: no hole.** A root over one
  hidden token id cannot be brute-forced. Every encoded column's leaf carries a fresh
  32-byte salt that never leaves the prover for unopened columns. The 256 pads per row
  make the 256 opened columns uniform. The value's entropy plays no part. Conditions:
  one opening only (two would recover the row), the owner's decommitment never
  published, and the D17 joint-view gate (G-6).
* **Counts reproduced exactly** from my own plane list: 8B T32 mode (i) 3,057,664
  committed elements, and 8B T512 mode (ii) 1,066,008,576 (U8) and 595,525,632 (U16)
  [COUNTED]. Two savings the design missed: the top-limb "pin" lookup is unnecessary for
  soundness. Dropping it removes one lookup per vocabulary entry and one Vo helper.
  That is −10 % of stage OUT in mode (i) and −12.6 % (−134 M elements) at T512 mode (ii)
  [COUNTED].

**R0 can start now. R1 can start once binding changes B-1 to B-3 below are written into
the design.**

### Binding changes (must be in the design before R1 code)

* **B-1 (F-2).** Token endpoints use `log_n = 8` with `inv_rate = 8` (more data rows at
  T512, never a 512-wide row at rate 1/4). Every new stage commitment (`A_in`, `H_in`,
  `A_out`, `H_out`) has row width at least 2^12 at rate 1/4. Section 4.4 recounts the
  commitment term per opening as `(1 − δ/3)^256` with `δ = 1 − (n + 256)/(n · inv_rate)`.
  The R1 dev rung's narrow stages must state their actual per-opening figure.
* **B-2 (F-1).** The hidden selector `s` (one-hot, booleanity and sum 1 kept) is sealed
  under an endpoint root:
  * preferred: as a second plane of the input token endpoint, claimed by stage OUT. That
    endpoint then needs the two-site geometry `data + 2·2 + 2`, opened once at the end of
    the run, which is R9, now needed in mode (i) as well;
  * fallback, with no geometry change: in the output endpoint's data row beside the token.

  The owner check verifies `s = e_{P−1}`. Alternatively, derive `s` in-circuit from a
  reserved pad id with monotone validity bits. That needs a third tiny prover-generated
  boundary from stage IN to stage OUT.
* **B-3 (F-3).** Write the slot cubes out:
  * `tok` (stage IN) lives on the **same lifted domain** as `h_q`, pad-zero there. A
    `T`-sized `tok` broadcast into the lifted cube and then pad-zeroed is a completeness
    failure.
  * Each IO slot runs over the token endpoint's **whole padded plane** (≥ 256 words, as
    `EndpointSpecG` requires `log_n ≤ log_len` and pads ≤ row width). The A side is
    embedded with a public indicator, so the endpoint's pad words are bound to zero
    (D17 rule 1).
  * RSEL's constant and `tok` terms each carry a public factor (the slot machinery's
    construction premise).

Recommended, not binding: drop the pin (F-4). Owner decommitment includes the per-row pad
coefficients (F-5). Add the D16 rule-5 audit of the new layouts to R1's acceptance (F-8).

---

## 2. Findings table

| ID | point | verdict | severity | one line | minimal repair |
|---|---|---|---|---|---|
| F-1 | 4 | **hole** (soundness of the intended statement) | high, blocks the hidden-selector variant | selector `s` is constrained only to be one-hot; prover picks any row `t*`, receipt verifies, owner cannot detect | seal `s` (or `P`) under an endpoint root the owner checks (B-2) |
| F-2 | 3, 5 | **hole** (soundness accounting) | high, blocks R1 as counted | token endpoints `n = 256`, `Q = 256` pads, rate 1/4: code RS(512, 1024), δ = 1/2, per opening 2^-67.3; whole proof 2^-66.3 instead of the design's 2^-98.6 | `inv_rate = 8` at `log_n = 8` (2^-106.25); stage widths ≥ 2^12 (B-1) |
| F-2b | 5 | needs change | medium | receipt-optimal widths 2^10 / 2^11 give 2^-96.1 / 2^-101.2 per opening; TinyLlama whole proof −4.2 bits, 8B −0.5 bits | width floor 2^12 (+0.04 M elements at 8B, +0.39 M at TinyLlama) |
| F-3 | 1, 2 | needs change (specification) | low | domain mismatch `tok` (T) vs `h_q` (lifted); IO slots vs 256-word endpoint plane; RSEL monomials without public factor | B-3 |
| F-4 | 2 | holds; efficiency | — | the pin in (A4) is not needed: 6 bytes give `[0, 2^48)` and `2^48 + 2^44 < p`; window check unaffected | drop it: −1 lookup per vocab entry, −1 Vo helper |
| F-5 | 3 | needs change (minor) | low | owner decommitment lists data row, 5 mask rows, salts, but not the 256 pad coefficients per row needed to re-encode | add pads (all 6 rows) to `owner_check`'s input |
| F-6 | 3 | holds, with dependency | — | hiding of the token-endpoint roots under a *tagged* profile rests on D19b's model (pending Victor), not only D19 | list D19b next to R5 |
| F-7 | 2 | holds, with note | — | final-norm int8 overflow is an input-dependent refusal (CS-3 class), same as the block norms | either constants with `g0 · Cn_f / 2^tn_f ≤ 126` (provably no refusal) or carry it in the D20 class list; F2/F6 fidelity runs stay |
| F-8 | 2 | needs change (minor) | low | D16 rule 5 (every committed value under a non-unit coefficient independently ranged or determined) not listed for the new layouts (`tok·2^-v`, `M`, `m`) | add to R1 acceptance; argued below (all three are determined, not free) |
| F-9 | 5 | [MODEL] caveat | — | mode (ii) materialised public tables at 8B T512: two 2^26-entry Fp2 tables, 1 GiB each, on the verifier; verifier also hashes 1.6 GB of public tables per pass unless digests are cached | factored supports for mode (ii); state digest-caching assumption |
| P-1 | 1 | **holds** | — | `r_emb` after `B_in`, `A_in`, `M_in`; LogUp + β-compression + Schwartz–Zippel bind every column of every embedded row | — |
| P-2 | 2 | **holds** | — | keyed argmax = numpy first maximum; `e` two-hot/fractional rejected; `M` forced to `l_j`; padded vocab excluded; every clause below 2^48.1, ≥ 15 bits under p | — |
| P-3 | 3 | **holds** (privacy of a tiny root) | — | 32-byte salt per encoded column, 256 pads per row, 5 random rows; derived boundary rows and single openings correct | keep one opening; G-6 gate; D21 for the decommitment |
| P-4 | 4 | mode (ii) **holds** conditional on R9; hidden selector see F-1 | — | SHIFT with public shifted eq is sound; two-site endpoint is a boundary-like geometry | R9 ruling |
| P-5 | 5 | **holds** (counts reproduced) | — | 3,057,664 (8B T32 mode i); 1,066,008,576 (8B T512 ii, U8); 595,525,632 (U16) | — |

---

## 3. Details

### 3.1 Point 1 — input side (indexed LogUp of the compressed row)

**Order.** Stage IN: absorb the stage tag and embedding digest, commit `B_in`, `A_in`
(`tok`, `m`), `M_in`, draw `β, γ, α, r_emb`, commit `H_in`. Nothing of the prover's
enters between the draws, so the four challenges are jointly uniform given every value
they must bind: `B_in`, `tok`, `m`, the endpoint (its root is in the header) and `E`
(digest in the header). The order among `β, γ, α, r_emb` does not matter. **Holds.**

**The three steps, each a union bound over the joint draw** [COUNTED, `|F_p^2| ≈ 2^128`]:

1. **LogUp (α).** `Σ_t 1/(α − q_t) = Σ_v m_v/(α − τ_v)`, with `m_v` arbitrary field
   elements. A query value outside `{τ_v}` leaves a pole of residue `count ∈ [1, T]`,
   which is nonzero because `p > T`. So no range proof on `m` is needed. Error about
   `(T + V_pad)/2^128 ≤ 2^-110.9`.
2. **Tuple compression (β).** For fixed `r_emb`, `q_t − τ_v = (tok_t − v°) + β(X_t − E~(v°, r_emb))`
   is linear in β. So two distinct tuples collide for at most one β. Over `T·V_pad` pairs
   that is `2^9 · 2^17 / 2^128 = 2^-102` at 8B T512. The tag `g_emb` cancels on both
   sides and is only needed if the sum is ever shared with another table; harmless.
3. **Row binding (r_emb).** `x[t,·] − E[tok_t,·]` is fixed before `r_emb`. Its MLE
   vanishing at a random `r_emb` gives `T · log2 d_pad / 2^128 ≈ 2^-115.4`.

**Every column, through `B_in`, into block 0.** Step 3 binds the whole row `x[t, 0..d_pad)`,
including the zero pad columns at the rung's d384→512, because `E` is folded with its
zero pad. Block 0's IO-in slot runs over the full `Dom::D` cube, which is the whole
`B_in` plane (D17's whole-plane rule). So `A_X(block 0) = B_in = E[tok]` word for word,
and block 0 re-proves int16. The virtual column `X(t) = B_in~(t, r_emb)` is expressible
today: a `Tab::Priv` with `Coord::Fixed` for the column bits (`argument.rs:49–53, 208`).
Its zero-check terminal becomes one claim on `B_in` at `(ρ_t, r_emb)`, masked by
site 0's own pair.

**Histogram, padding, pad ids.** On padded table entries, `m = h_tab = 0` (pad-zero)
already removes them from the sum. The "repeat entry 0" rule is belt-and-braces, and the
table ZC holds there as `0 = 0`. A query with `tok_t ≥ V` matches no `τ` except by a
step-2 collision. Zero denominators: honest queries equal table values, the whole table is
inverted first, and refusal is a function of public `τ` and challenges (D22 V-3's
argument). The hidden-selector pad id must be `< V`; any real id works. **Holds.**

**Specification gap (F-3).** The counter puts `tok` on an unlifted `T` domain and `h_q`
on `T` lifted to the row width. `priv_table` broadcasts a plane over the slot variables
it does not use (`argument.rs:264–271`). So the design as literally written, a `T`-sized
`tok` inside the lifted query cube with a pad-zero term on `tok`, would force the
broadcast copies to zero, which is a completeness failure. Repair: `tok` lives on the
lifted domain, as every plane of an H-carrying domain does in the block. Rows are
unchanged, 1 either way. `B_in`'s row variables map to the trailing `log T` slot
variables and are broadcast over the leading lift variables. That is harmless, because
`h_q = 0` there by pad-zero.

### 3.2 Point 2 — output side

**Final norm.** This is the block's `norm_a` relation (`argument.rs:1561–1562`: `c0`, `c1`)
with `γ ≡ g0`. Clause magnitudes over D24's class at the class edge (`Ceps = 2^40`,
int16 −32768, `Cn = 2^20`, `g0 = 127`) [COUNTED]:

| clause | TinyLlama (d 2048, tn 10) | 8B (d 4096, tn 9) |
|---|---:|---:|
| `2·g0·Cn·|x|` | 2^42.99 | 2^42.99 |
| `2^(tn+1)·D·|y|` | 2^38.78 | 2^38.15 |
| `S = Σx² + Ceps` (TZC) | 2^41.58 | 2^42.32 |
| `D_max`, bits | 1,816,186, 21 | 2,344,687, 22 |
| remainder window `tn + 1 + bits(D_max)` | 32 | 32 |

All are below `p/2`, and the window is at most 32 bits, so D16 rules 1–4 hold as written.
The int8 output (sym lookups) is what bounds the logits.

**Logits and argmax, no-wrap** [COUNTED]:

| quantity | TinyLlama (V 32,000, v 15) | 8B (V 128,256, v 17) |
|---|---:|---:|
| `B = d·127·127` (`|l|`) | 33,032,192 (2^24.98) | 66,064,384 (2^25.98) |
| same with −128 weights | 33,292,288 | 66,584,576 |
| max `|2^v(l_j − l_i) + (i − j)|` (127 / 128) | 2,164,797,766,911 / 2,181,843,418,367 (< 2^41) | 17,318,382,007,551 / 17,454,747,219,199 (< 2^44) |
| keyed window bits needed | 41 | 44 |
| step window bits | 26 | 27 |
| 6 limbs (2^48) + max RHS < p | yes | yes |

**First maximum, adversarially.** (A1) `e(1−e) = 0` over `F_p` has only the roots 0
and 1. (A2) `Σe = 1` with at most `V_pad·T_out < p` ones gives exactly one: a **two-hot or
fractional `e` cannot pass**. (A3) `tok = j`. (A6) `δ_j = 0`; with (A5) at `i = j`,
`2^v(M − l_j) = 0`, so `M = l_j`. **`M` cannot be chosen below or above the true value.**
Without (A6), any `M ≥ max` would let every `j` pass, so (A6) is load-bearing and present.
Then for every true `i`: `δ_i ≡ 2^v(l_j − l_i) + (i − j)`, with `δ_i ∈ [0, 2^48)` and
`|RHS| < 2^44`, so `δ_i = RHS ≥ 0` as integers, and `j` is the lowest index among the
maxima. The matmul slot makes the virtual `l*` equal `yW'^T` at a random point drawn after
`A_out`, which is the usual Schwartz–Zippel step. Randomised exhaustive check
(`check_arith.py` §B): 300 logit vectors per model (uniform extremes ±B, forced ties at the
maximum, near-ties differing by 1, all-equal), every `j` tried, with and without the pin.
Only numpy's first maximum is admissible: **0 mismatches in 1,200 cases** [COUNTED].

**Padded vocabulary entries** take no part. At `i ≥ V`, `l* = supp_V(i)·(…) = 0` matches
`yW'^T = 0` (zero head rows), and pad-zero forces `e = δ = 0` there. So no keyed relation
applies, and they do not need to lose; numpy's vector has no such entries either.

**F-4, the pin.** Six byte limbs already bound `δ` to `[0, 2^48)`. Soundness needs only
`2^48 + max|RHS| < p`, and completeness needs `max RHS < 2^48`. Both hold, so the
top-limb pin lookup buys nothing. Dropping it:

* lookups per vocab entry fall from 7 to 6;
* Vo helpers fall from 4 to 3;
* 8B mode (i) stage OUT drops from 2,621,440 to 2,351,104 elements (−10.3 %) and from
  970,752 to 839,680 lookups;
* 8B T512 mode (ii) U8 drops from 1,066.0 M to 931.7 M elements (−12.6 %) and from
  495.0 M to 427.9 M lookups;
* U16 keeps its element count but drops from 293.7 M to 226.6 M lookups [COUNTED].

The same argument removes the pin from the step and U16 variants.

**F-3 (RSEL, IO-out).** A standalone slot asserts sum 0 (`argument.rs:528`), and every
monomial needs a public factor (`argument.rs:18–22`). So write RSEL as
`Σ supp_V·e·(c1 + c2·ι + c3·δ) − u0·(c1 + c2·tok)`, with `u0` a public one-entry indicator
(per row, eq-weighted, in mode ii). IO-out in mode (i) compares a size-1 `tok` with a
256-word endpoint row through `u0·tok`. Without it, either the slot cannot be built or the
other 255 endpoint words are unbound, which D17 rule 1 forbids.

**F-7, final-norm refusals.** `|y| ≤ g0·Cn_f/2^tn_f · |x_i|/D + ½` with `|x_i| ≤ D`. So
constants with `g0·Cn_f/2^tn_f ≤ 126` make an int8 overflow (CS-3 refusal) impossible for
every input. Otherwise it is an input-dependent refusal class like the block norms', and
must sit in D20's list with F2/F6 evidence. The design picks the second without saying so.

**F-8, D16 rule 5.** The new non-unit coefficients sit on `tok` (`2^-v` in `l*`), `M` and
`m`. None is ranged, and none needs to be: `tok = j` (A3, with one-hot `e`), `M = l_j`
(A5 + A6), and `m` needs no range for LogUp (residues ≤ T < p). Byte limbs carry the
`256^k` coefficients. R1's acceptance should state this audit explicitly.

### 3.3 Point 3 — endpoint change and tiny commitments

**Derived rows, sites, openings.** `B_in` has 2 sites (stage IN's query ZC at site 0 and
block 0's IO-in at site 1) and is opened once, in block 0's stage. `B_out` has 2 sites
(block L−1's IO-out at site 0 and stage OUT's IO-in at site 1) and is opened once, in
stage OUT. Each is `data + 2·2 + 2 = endpoint_rows + 1`, exactly what
`RunStatement::boundary_spec` builds (`run.rs:428`) and M-1 derives. Block L−1's site-0
row is the old endpoint's terminal-pair row (`data`), so its pair index does not move;
block 0's moves from `data` to `data + 2` (stage line only). The token endpoints stay at
M-7's `data + 5`, one site. **Holds.**

**Public-row claim on `B_out`.** The claim on `B_out` at `(bits(T−1), ρ_i)` has public
Boolean coordinates. At 8B T32 (`endpoint_log_n = 13 > log d = 12`) one of them falls in
the reserved pair's column tail. The eq weight then zeroes half of the pair's columns, but
the remaining half are fresh uniform values with nonzero weight, so the terminal is still
uniformly masked. The tools must accept such points (G-2). **Holds.**

**Can the root over one hidden id be brute-forced?** No. The commitment is the ZK code
RS(n + Q, n·inv_rate) on a coset with Q = 256 random pads per row, so "any Q of [the
columns] are jointly uniform given the data" (`zkp-core/src/pcs.rs` ZK section). Leaves
are `blake3(blake3(column) || salt)` with a fresh 32-byte salt per encoded column
(`hashline/src/pcs.rs:132`). Recomputing the root for a guessed token needs the 768 (rate
1/4) or 1,792 (rate 1/8) unopened salts, which the prover never releases. In the random
oracle model (D19) the root and the single opening are simulatable independently of the
value, so the 17 bits of entropy do not matter, and no extra blinding is required. The
group and proximity vectors are masked by the terminal pair and the proximity rows, which
is the boundary module's `2(G + 1)` real dimensions against `2(G + 1)` free mask
coordinates. Conditions:

1. **One opening, ever.** Two openings of 256 columns each give 512 evaluations of a
   512-coefficient row and recover it. This is D11 at its smallest geometry. R9's two-site
   endpoint keeps one opening.
2. **D21**: the owner's decommitment reveals the id and is never in a published or retained
   bundle.
3. **F-6**: under a tagged profile, the model is D19b's (pending).
4. **G-6 / D17 rule 3**: joint-view gate on a captured receipt at the 6-row geometry.
5. **F-5**: the owner's root rebuild needs the per-row pad coefficients (`CommittedZk.pads`)
   as well as the rows and salts.

**F-2, the soundness side of the tiny geometry (the real problem here).** In ZK mode the
code is RS(n + Q, nn) with distance `1 − (n + Q)/nn` (`zkp-core/src/pcs.rs`), and the
column test misses a far matrix with probability `(1 − δ/3)^Q`. Per opening, with Q = 256
[COUNTED]:

| row width | rate 1/4 | rate 1/8 |
|---|---:|---:|
| 2^8 (token endpoint) | **2^-67.34** | 2^-106.25 |
| 2^9 (token endpoint, T512 one row) | 2^-86.28 | 2^-116.65 |
| 2^10 (Tiny stage IN, design) | 2^-96.13 | — |
| 2^11 (8B stage IN, Tiny stage OUT) | 2^-101.16 | — |
| 2^12 (8B stage OUT) | 2^-103.69 | — |
| 2^13 / 2^16 | 2^-104.97 / 2^-106.09 | — |
| D15 convention (pads ignored) | 2^-106.25 | — |

The counter's endpoint receipt term uses `INV_RATE = 4`, and nothing in `EndpointSpecG`
refuses rate 1/4 at `log_n = 8` (`n + Q = 512 ≤ 1024`). Whole-proof commitment term,
keeping D15's convention for the existing 192 / 132 openings [COUNTED]:

| geometry | 8B T32 | TinyLlama T32 |
|---|---:|---:|
| stack alone | 2^-98.66 | 2^-99.21 |
| design's own accounting (all 8 new at 2^-106.25) | 2^-98.61 | — |
| design geometry (endpoints rate 1/4) | **2^-66.34** | **2^-66.34** |
| endpoints rate 1/8, design stage widths | 2^-98.14 | 2^-95.00 |
| repaired: endpoints rate 1/8, stages ≥ 2^12 | 2^-98.47 | 2^-98.93 |

Width floor cost: 8B stage IN goes from 436,224 to 479,232 elements, and TinyLlama stage
IN from 119,808 to 184,320; TinyLlama stage OUT goes from 819,200 to 1,146,880 [COUNTED].
Observation outside this design, for the security owner: D15's 2^-106 per opening also
ignores the pad dilution. At the trained widths 2^12–2^13 the per-opening figure is
2^-103.7 to 2^-105.0, so the stack's own term is roughly 1.3–2.5 bits weaker than quoted.
This is a technical note, not a finding against the token I/O design.

### 3.4 Point 4 — prompt length hiding; mode (ii)

**F-1, a concrete attack.** In the hidden-selector variant the only constraints on `s`
are booleanity, `Σs = 1`, and the bilinear slot `x_sel = Σ_t s(t) B_out(t,·)`.

1. The prover sets `s = e_0`.
2. Stage OUT computes the honest greedy token after position 0. Under R8 that is BOS
   alone, which is a constant of the model.
3. The prover seals that token in the output endpoint.

Every slot holds, so the receipt verifies. The owner receives the id and the output
decommitment, and neither reveals `t*`. Any `t* ∈ [0, T)` works, including padded
positions. The receipt therefore attests "the greedy token after *some* prefix of the
sealed sequence", which is not the claim the design makes. Privacy is unaffected: `s` is
hidden, has two sites, and is opened once.

**Repair (B-2):**

* **Preferred.** Seal `s` in the input token endpoint, so the owner's input check covers it,
  and claim it from stage OUT. That needs R9's two-site geometry in mode (i), which unifies
  mode (i) with hidden length and mode (ii).
* **Fallback.** Put `s` in the output endpoint's data row (the 255 spare words at T ≤ 255).
  This needs no geometry change, the owner checks `s = e_{P−1}`, and `P` becomes output-side
  data of the owner.
* **In-circuit.** Derive `s` from a reserved pad id with monotone validity bits in stage IN,
  carried to stage OUT by a third tiny prover-generated boundary (D12a-compliant, 2 sites).

**R2's recommendation must be amended** to name one of these.

**Mode (ii).** SHIFT,
`Σ_k eq(r,k)R(k)tok_out(k) − Σ_k S(k)tok_in(k) = 0` with the public shifted table
`S(k) = eq(r, k−1)R(k−1)`, has a public factor in every monomial. The verifier evaluates
`S~` in `O(T)`. It proves `tok_in[k+1] = argmax_k` on the public window. Together with
causality this attests every generated token. The two-site input endpoint (`data + 6`,
one opening at the end of the run) is the boundary construction applied to an external
endpoint; the security owner rules on it (R9). Prefix consistency (F4) and the public
`P`, `G` are correctly stated. **Holds, conditional on R9.**

### 3.5 Point 5 — the counts

Re-derived from the design's plane / site lists in my own code (not importing the
counter) [COUNTED, `check_arith.py` §C]:

* 8B T32 mode (i):
  * stage IN at 2^11: A 73 + H 140 rows → **436,224**;
  * stage OUT public row at 2^12: A 338 (242 data + 2·47 + 2) + H 302 (274 data + 2·13 + 2)
    → **2,621,440**;
  * total **3,057,664** = 3.06 M. Matches.
* 8B T512 mode (ii) U8 keyed at 2^16: A 7,656 (7,558 data, 48 sites) + H 8,610 (8,582
  data, 13 sites) → **1,066,008,576**. Matches.
* U16 keyed: A 4,573 + H 4,514 → **595,525,632**. Matches.
* TinyLlama: stage IN 119,808 and stage OUT 819,200. Match.
* Hidden selector: 2,633,728. Matches; it omits the selector slot, as the design says.
* With the recommended changes (stage IN at 2^12, no pin), 8B T32 mode (i) totals
  **2,830,336** (−7.4 %).

Small undercounts, all negligible: the selector's own slot and its DZC host term; the
`+1` row of each boundary and the two 6-row token endpoints (no element figure); the BOS
constraint (R8). The [MODEL] seconds were spot-checked only: verifier `+1.63 s =
2 × (1.46e-9 × 536.9 M + 0.0315)`. F-9 adds two caveats: per-pass digest hashing of
1.6 GB of public tables, and 1 GiB per materialised 2^26-entry Fp2 table on the verifier
in mode (ii) at T512.

---

## 4. Rulings and decisions this check surfaces

1. **R2 must be amended (Victor, product).** "Hide the prompt length" now means "the length
   is sealed under the input root and checked by its owner". That needs the R9 two-site
   input endpoint already in mode (i), or the output-endpoint fallback. Recommend the input
   endpoint route.
2. **R9 moves earlier (security owner).** If B-2's preferred form is taken, the two-site
   external endpoint is needed for the hidden-length mode (i), not only for mode (ii).
3. **Per-opening counting convention (security owner, technical clarification under
   D15).** New commitments are counted with the ZK code's real distance
   `1 − (n + Q)/(n · inv_rate)`, and a floor is set; this check proposes "every opening
   ≥ 2^-103" for the token I/O stages. The whole-proof target itself stays Victor's pending
   D15 question.
4. **D19b dependency (Victor, pending).** The hiding of the token-endpoint roots under a
   tagged profile rests on it. List it beside R5 / D23.

No other new ruling is needed. R1, R3–R8 stand as written.

---

## 5. Reproduction

* `python3 results/zk60_token_io_design_20261017/check/check_arith.py` writes
  `check_arith.json` here and prints it (`check_arith.out.txt` is a copy). One thread,
  under a second.
* Nothing from `../` is imported. The design's counter was run once, piped into `head`,
  before this check's own script existed. It writes `../token_io_count.json` only at the end
  of its run, and that file's size and mtime are unchanged (108,229 B, 11:51 PDT), so no
  write happened.
