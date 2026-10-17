# Token I/O design v2: adversarial check, pass 2

Checker lane, 2026-10-17 (UTC 19:38–19:55). This pass is **paper only**: nothing was built,
proved or measured, and no git writes were made. This is not a privacy acceptance, and it makes
no ruling.

**What was checked**
- `../DESIGN.md` v2: the changes table in §0 (C-1 to C-12), the stage text in §2–§4, R0 in §6.4,
  the rulings in §7, and the R9 proposal in §8;
- `../token_io_count.py` v2, diffed against v1;
- rung R0 in `../r0/`: `token_io_ref.py`, `token_io_vectors.py`, `vectors.json` and
  `test_token_io_ref.py`;
- D25, D23 and D19b in `ZK60_DECISIONS.md`;
- for the mask commitment, `hashline/src/zk.rs`.

**Labels**
- **[COUNTED]**: exact arithmetic.
- **[RAN]**: one-thread Python run on this box, under a second, nothing written outside `check/`.

**What was run**
- R0's suite (`python3 -B`, from `/tmp`): 13 of 13 tests pass [RAN]. No bytecode was written, and
  `r0/` is unchanged.
- `check2_probes.py`: imports R0 read-only and writes `check2_probes.json` [RAN].

---

## 1. Verdict in plain words

* **B-1 to B-3 are closed as written.**
  * The token endpoints are at 2^8 with rate 1/8 (2^-106.25 per opening). Every stage commitment
    is at 2^12 or wider (2^-103.69). The whole-proof term is 2^-98.47 at 8B and 2^-98.93 at
    TinyLlama [COUNTED, reproduced].
  * The selector is sealed under the input root.
  * `tok` now sits on the lifted domain. The IO slots cover each endpoint's whole plane with
    public support factors. RSEL and IO-out carry a public factor in every monomial.
* **Dropping the top-limb pin is safe at both models.** Six byte limbs bound `delta` to
  `[0, 2^48)`. The honest maximum needs 41 bits (TinyLlama) and 44 bits (8B), also with −128
  weights. Soundness needs `2^48 + max|RHS| < p`, where `max|RHS| < 2^44`.
* **The fold-in of D25 T8 (BOS forcing) opened one new hole, as the formula is written.**
  * The BOS clause `eq(τ,t)[t=0](tok(t) − 1)` is added to the query zero-check with no
    coefficient of its own.
  * The attack: set `tok_0 = BOS + 1` and the helper `h_q(0) = 0`. Both clauses then vanish
    together at `t = 0`, and position 0 drops out of the lookup. Embedding row 0 becomes any vector
    the prover likes.
  * A helper-level model accepts this forgery when the clause is unweighted. It rejects it when the
    clause carries a fresh challenge [RAN, probe T4].
  * Second problem: `1` is TinyLlama's BOS id; Llama-3-8B's is **128000**.
  * Repair (two lines): give the clause a fresh challenge coefficient, and make the BOS id a
    per-profile statement constant.
* **R9 variant P is sound and private as accounted. I recommend that the security owner accept
  it**, with five conditions (section 4):
  1. the variant is bound in the run statement;
  2. the run verifier carries the stage-IN claim to the end of the run and refuses an early or
     second opening;
  3. the two-site external endpoint gets its own spec and digest domain;
  4. the owner check uses the derived row count;
  5. the joint-view gate (G-6 / G-7) is passed before any number from it is quoted.

  The public half bit is harmless. The opened vectors are full-row combinations, each masked by
  its own pair. The claim value is a function of the opened vector, so the zeroed half of a pair's
  columns hides nothing less.
* **R0 is a good reference for A1–A6 and for the ideal lookup identity, but several tamper
  classes are missing.**
  * Two load-bearing argmax forgeries are not in the vectors (probes T1 and T2):
    * T1, an overstated maximum, which only A6 catches;
    * T2, a selector placed on a padded vocabulary entry, which only the pad-zero term catches.
      Without that term the proof would output id 300, which is not a token.
  * The final norm has a checker but no forged-witness vectors (T5).
  * The verifier half of the B-2 seal is not modelled at all. R0 has no IO-in, IO-s or IO-out
    relation. "Sealed right, used wrong" (T7), a consistent re-lookup (T8) and "another id
    sealed" (T9) pass every R0 relation and the owner check. In the native code only the IO slots
    catch them. R1's list already names the IO-s and IO-out controls, but R0 should model them.
  * R0's lookup check uses exact inverses, so the BOS-absorption hole above is invisible to it.

**Gate.** R1 for the public-row variant may start once N-1 and N-2 (section 2) are written into
the design. The hidden-length variant waits for the R9 ruling. Section 4 gives recommended text.

---

## 2. Findings table (pass 2)

| ID | question | verdict | severity | what | minimal repair |
|---|---|---|---|---|---|
| N-1 | (1) new hole | **hole as written** | high, trivial fix | BOS clause added unweighted to the query zero-check. Forgery `tok_0 = BOS+1`, `h_q(0) = 0` satisfies the combined clause at `t = 0`, removes position 0 from the LogUp, and frees embedding row 0 (T4: accepted unweighted, rejected with a fresh coefficient) [RAN] | the BOS clause gets its own challenge coefficient, drawn after `A_in` like every batched clause. R1 control: this forgery must be refused |
| N-2 | (1) | needs change | medium | `BOS id 1` (DESIGN §2.3, §7.1, `token_io_ref.BOS`) is TinyLlama's; Llama-3-8B's is 128000 (`zk60_8b_calibration_20261017/PROGRESS.md`). D25 T8 says "the BOS token", not an id | BOS id is a per-profile constant in the statement, with declared class `[0, V)` (D24 F-1 rule); R0 takes it as a parameter |
| N-3 | (1) | needs change (spec) | low | the same batching rule must hold for every clause the v2 text adds: SBOOL's `s(1−s)` and `Σs = 1`, and RSEL's `c1..c3`. Written as a sum of clauses, one can absorb another | one sentence in §3.1: every batched clause carries a fresh challenge |
| N-4 | (1) | holds | — | pin dropped: six bytes give `[0, 2^48)`; honest maximum 2^40.98 (TinyLlama) / 2^43.98 (8B) (with −128: 2^40.99 / 2^43.99); `2^48 + 2^44 < p` (pass-1 test, 1,200 cases without pin; R0's property test is also pin-free) [COUNTED] | — |
| N-5 | (1) | holds | — | support factors are sound (details in 3.1) | — |
| N-6 | (1) | holds | — | the selector sealed as half 1 of the input endpoint, claimed by stage OUT's IO-s, is sound | — |
| N-7 | (1) | counting nit (internal inconsistency) | negligible | the counter's SEL slot lists three private tables (`s`, `B_out`, `x`). That makes hidden-length `A_out` sites 50, not 49: SEL claims `s` and `x` (2), SBOOL `s` (1), IO-s `s` (1); together they replace IO-in's 1. 49 holds only if `x_sel` is hosted by DZC, and then SEL has two private tables. The difference is ±1 site = 2 rows = 8,192 elements at 2^12 [COUNTED] | pick one form and make the slot list and site count agree |
| N-8 | (1) | documentation error | low | §4.4 note: "every block's `M` (1,024 columns) would be 2^-96.1 under the same rule". Wrong: `zk.rs` builds `M` as RS(1024, 4096) with distance 3/4, i.e. 2^-106.25. The a-rows carry their 256 pads inside 512 message positions, and `b` and `u` have 1,024 coefficients. Not from pass 1 | delete the `M` clause; keep the A/H/boundary dilution note |
| N-9 | (2) | **holds; recommend accept** with conditions | — | R9 variant P: one opening, derived `data + 2·2 + 2` geometry, fixed public half bit, owner decommitment with pads | conditions C-a to C-e (section 4) |
| N-10 | (3) | test gap | medium | R0 has no A6-only (T1), pad-only (T2) or A3-only (T3) argmax forgery. R0 rejects all three for the right reason [RAN], but no vector pins them, and R1's list has none of them either | add V13–V15 to R0; add T1 and T2 to R1's controls |
| N-11 | (3) | test gap | medium | R0 models the ideal lookup identity, not the slot relations with committed helpers, so it cannot show N-1. Its `check_stage_in` rejects the N-1 forgery only through a separate BOS test | give R0 a helper-level stage-IN checker (query / table / sum relations, batched clause) and the N-1 vector |
| N-12 | (3) | test gap | medium | final norm: honest and refusal vectors only, no forged witness. `check_final_norm` compares integers, which is stronger than the native field relations. Probes T5: y off by one, D off by one, the D16 field alias, and y = 411 with in-window remainders. All are rejected for the right reason (remainder window, D limb window twice, int8 range) [RAN] | add as vectors; write the checker over `F_p` with explicit windows; add an `x` int16 check (DZC `c2`) |
| N-13 | (3) | test gap | medium | position selector `s` not one-hot: `s = (2, −1)` passes the selection relation and only booleanity catches it (T6) [RAN]. R0's V05 covers `e` only, and R1 has no `s`-not-one-hot control | add to R0 and R1 |
| N-14 | (3) | **test gap (B-2 verifier half)** | medium-high | R0 has no IO-in, IO-s or IO-out relation. T7 (honest seal, stage OUT uses `e_0`), T8 (consistent re-lookup under an honest seal) and T9 (output plane seals another id and the owner is told it) pass every R0 relation and the owner check [RAN]. Only the native IO slots catch them | add `check_io_half(plane_half, a_side, T)` (support-factor equality) with T7–T9 and a pad-word vector; R1's IO-s / IO-out / pad-word controls stay |
| N-15 | (3) | note | low | R0's challenges are base-field and drawn by hashing the witness; that is right for semantics. Pads, salts and the PCS are stand-ins (documented). | — |

---

## 3. Details

### 3.1 Question 1: are B-1 to B-3 closed, and did a fold-in open a hole?

**B-1: closed.** Counter v2 changes:
- the token endpoints become `Endpoint`, at 2^8 with rate 1/8;
- `STAGE_MIN_LOG = 12`;
- `best_width` now starts at 12;
- `per_opening_log2` uses `δ = 1 − (n+256)/(n·inv_rate)`.

Reproduced [COUNTED]:
- the stage figures: 8B stage IN 479,232 elements, TinyLlama stage OUT 1,073,152;
- the whole-proof terms: 8B T32 2^-98.47, TinyLlama T32 2^-98.93 (pass 1's
  `check_arith.json`, same geometry);
- the T512 two-site input endpoint: 1,024 words, 4 data rows, 10 rows, still 2^-106.25 per
  opening.

The one wrong sentence is the `M` claim (N-8). The mask commitment's opened polynomial has degree
below 1,024 on a 4,096-point coset (`zk.rs`: "RS(1024, 4096), distance 3/4"). So D15's 2^-106.25
is right for `M`. The A/H/boundary dilution note stays.

**B-2: closed for variant P (pending R9), with F as the fallback.** IO-s
(`end(1, z) = supp_T(z) s(z)`) binds `A_out`'s `s` to half 1 over the whole half. SBOOL makes `s`
one-hot. SEL makes `x = Σ_t s(t) B_out(t, ·)` at a random column point drawn after `A_out`. The
owner checks `s = e_{P−1}`.

The F-1 attack now needs the prover to seal the wrong `s`. Probe T7 is the other half:
- the prover seals the right `s` and uses another in stage OUT;
- the native IO-s slot catches this;
- R0 does not model it (N-14).

The run statement must also name which variant it is: public row, P or F. The design lists "the
output mode" in the calibration identity; the selector variant belongs there too (condition C-a).

**B-3: closed.**
- **`tok` on the lifted domain.** Pad-zero on the lift and the counter's `("T", Tl)` remove the
  broadcast completeness trap.
- **IO-in,** `end(0, z) = supp_T(z) tok(0, z)`:
  * it binds the endpoint's pad words in `[T, L_half)` to zero (D17 rule 1);
  * `tok`'s own positions `[L_half, n)` are bound to zero by the query zero-check's pad term;
  * `tok` is claimed at a point whose leading (lift) coordinates are a public 0. As with
    `B_out`'s public row bits, the reserved pair is weighted by an eq that zeroes the excluded
    columns, and the remaining columns carry fresh, uniformly random mask values;
  * the monomial `eq·end` has a public factor, and so does `eq·supp·tok`.
- **IO-out,** `end(z) = u0(z)·tok`: the 255 other output words are bound to zero.
- **RSEL,** `Σ eq(r,t)[supp_V e (c1 + c2 ι + c3 δ) − u0 (c1 supp_T + c2 tok)] = 0`:
  * per row: `c1(Σe − supp_T) + c2(Σ i·e − tok) + c3 Σ e·δ = 0`;
  * with `c1..c3` fresh challenges this gives A2, A3 and A6 separately (N-3 asks the text to say
    "fresh");
  * every monomial carries `supp_V`, `u0` or `eq`.

**Pin drop: closed (N-4).** See the table. Pass 1's randomised test ran without the pin, and R0's
property test (over 500 index trials at the 8B logit bound) is pin-free too.

**N-1, the new hole.** DESIGN §2.3 ("the query zero-check also carries
`eq(τ, t) [t = 0] (tok(t) − 1)` … no new site or row") and §7.1 (D25 T8) write the BOS clause as a
bare addend. The zero-check then proves, for every `t`:

`F(t) = h_q(t)(α − q_t) − supp_T(t) + [t = 0](tok(t) − BOS) = 0`

The attack at `t = 0`:
1. Choose `tok_0 = BOS + 1`. Then `F(0) = h_q(0)(α − q_0)`.
2. Commit `h_q(0) = 0`. `F(0)` is now zero for **any** `q_0`, i.e. for any `x[0, ·]`.
3. Compute the histogram without position 0, so the LogUp sum still balances.

Every other relation holds. The verifier accepts a run whose position 0 is not BOS and whose
first embedded row is an arbitrary int16 vector. That vector feeds every later position through
attention.

Probe T4 builds this in a helper-level model of the three relations (query, table, sum) with
challenges drawn after `tok`, `x` and `m`:

| clause weighting | honest witness | attack |
|---|---|---|
| unweighted (as written) | accepted | **accepted** |
| fresh coefficient `μ` | accepted | rejected at `t = 0` |

The existing slots batch every clause with fresh `μ`/`ζ` challenges, so an implementer copying a
neighbouring arm would probably add the coefficient. The design text, however, specifies the
broken form, and R0 cannot catch it (N-11).

The owner would notice `tok_0 ≠ BOS` on decommitment, because R0's owner check compares the full
prompt. D25 T8, though, promises a proof-level guarantee to the verifier.

### 3.2 Question 2: R9 variant P

**Sound as accounted.**
- **Per opening.** The endpoint is at row width 2^8, rate 1/8: the code is RS(512, 2048),
  `δ = 3/4`, (3/4)^256 = 2^-106.25. That holds at every T, since T512 only adds data rows.
- **Openings.** Still one opening, so the whole-proof term is unchanged.
- **Binding of `s`.** IO-s is a zero-check over the half, at a point drawn after the header (which
  holds the root) and after `A_out`. The term is `log2(L_half)/|F_p^2|` ≈ 2^-125.
- **What the receipt means.** "The greedy token after the sealed prefix", with the length checked by
  the owner, exactly as D25 T2 wants.
- **Pad positions `≥ P`.** These are real ids, sealed and checked by the owner. Causality is proved
  by the blocks' causal mask.

**Private as accounted.**
- **Derived geometry and masking.** One commitment, two claim sites, each with its own reserved
  pair, and a proximity pair: `data + 2·2 + 2`. The M-1 count `2(G + 1) = 6` real dimensions per
  position (two group vectors and the proximity vector, Fp2 each) against 6 mask rows applies as
  for a boundary. The two claims have different tails, `(0, ρ)` and `(1, ρ′)`, so there are two
  groups.
- **The public half bit.** The question was whether fixing the half bit to a public value weakens
  the masking. It does not. In this PCS:
  * the prover publishes the **row combination** `v_g = ρ_g^T [M | pads]`, which is all message
    columns of both halves plus pads;
  * the verifier applies the column weights itself, as `⟨v_g, c_g⟩`;
  * so the eq weight that zeroes half of a pair's columns never touches `v_g`. Each `v_g` is masked
    by its pair's full rows;
  * the slot terminal is `(1 − e)·T(p) + e·R(tail) = ⟨v_g, c_g⟩` (`build_claim` with
    `cd = 1 − e`, `cm = e`), a function of the published `v_g` and nothing more.

  At T ≤ 128 the half bit is a column bit; at T512 it is a row bit and only selects data rows.
  Both reduce to the same argument.
- **External root.** Under D18 (the prover seals at proof time) and D23 (accepted 19:28 UTC) the
  standard game applies. D19b, also accepted, is the tag model the hiding of the root rests on.
- **Owner decommitment.** The owner receives rows, every row's 256 pads, and the salts. It can
  unmask both endpoint-side terminals, which are functions of `tok` and `s`, i.e. of its own data.
  The `A`-side terminals stay masked by `A_in`'s and `A_out`'s pairs. The owner is outside the
  adversary for its own endpoint (D25 T5).
- **One opening.** Two openings of 256 columns would recover a 512-coefficient row (D11). The
  deferred opening keeps it at one, provided the code enforces it (C-b).

**What §8 does not yet say (conditions):**
- **C-a: the variant is bound into the run statement.** This means the parameter line and stage
  lines: "input endpoint: sites 2, rows `data + 6`, row width 2^8, rate 1/8, opened after stage
  OUT and `B_out`", plus the selector variant P / F / public row. The verifier reads it from its own
  statement, never from a segment. Public-row, P and F are distinct run profiles (D17), so a receipt
  cannot be re-read under another variant.
- **C-b: the run verifier enforces the deferred single opening.** It carries the stage-IN claim
  across all stages, as `pending` / `finish` do for a boundary. It refuses a run that opens the
  input endpoint anywhere but its declared place, or with fewer or more than two claims. The prover
  side consumes the owner by value, as `endpoint_g` and `boundary` already do.
- **C-c: the two-site external endpoint is its own spec type.**
  * `EndpointSpecG`'s digest hard-codes `MASK_ROWS = 5` and two slot indices, so it cannot stand
    for this endpoint.
  * Use a boundary-like spec with its own digest domain string (for example
    `hashline/private-block/two-site-endpoint/v1`) and the input role byte in its seed domain.
  * Its constructor derives `data + 2·sites + 2` and refuses any other row count by name (M-1).
- **C-d: the owner check uses the derived geometry.** It re-encodes at row width 2^8, rate 1/8, with
  the derived row count (7 or 10), and checks:
  * `tok_0` is the profile's BOS;
  * the prompt, pad ids and pad words are zero beyond `T` in both halves;
  * `s = e_{P−1}`.

  It refuses a decommitment of any other shape.
- **C-e: G-6 / G-7.** A joint-view analysis on captured receipts at both geometries (T ≤ 128 with
  the column half bit; T512 with the row half bit). It is owed before any number from it is quoted
  (D17 rule 3).

### 3.3 Question 3: does R0 exercise what the native code will check?

| relation | R0 checker | vectors / tests | gap |
|---|---|---|---|
| A1 booleanity of `e` | yes | V05 (fractional, (2, −1)) | — |
| A1 pad-zero of `e` and limbs | yes | none | **T2** (only this catches a padded output id) |
| A2 row sum | yes | V05 two-hot | — |
| A3 `tok = Σ i·e` | yes | none directly | T3 |
| A4 six byte limbs | yes | V12 | — |
| A5 virtual logits | yes | V03, V04, property test | — |
| A6 `Σ e·δ = 0` | yes | none load-bearing | **T1** (an overstated `M` with a non-maximal `j`: only A6 catches it) |
| LogUp identity (ideal) | yes | V06, V07, V08, single-word property | helper level missing (N-11, so the N-1 hole is invisible) |
| BOS | yes (separate test) | V09 | N-1 (unweighted clause), N-2 (BOS id) |
| final norm | yes (integers) | V11 (honest refusal / refusal-free), tlcalib cross-check | **T5** forged witnesses; field form; `x` int16 |
| selector `s` | yes | V10 (one-hot, wrong position) | **T6** (`s` not one-hot) |
| selection `x = Σ s B_out` | yes | V02, V10 | — |
| IO-in / IO-s / IO-out (verifier side) | **no** | — | **T7, T8, T9**, pad words |
| owner checks (seal) | yes (stand-in commitment) | V01, V02, V10, property test | pads and PCS are stand-ins (documented) |

Probe results [RAN]:
- **T1:** R0 rejects with "A6 …", and the same witness is accepted with A6 removed.
- **T2:** R0 rejects with "A1 pad-zero …", and the witness, output id 300 = V, is accepted without
  that term.
- **T3:** R0 rejects with "A3 …".
- **T5:** "remainder window", "isqrt limb windows" (twice), and "norm output outside int8" with
  `y` up to 411.
- **T6:** the selection relation alone accepts; booleanity rejects.
- **T7, T8, T9:** every R0 relation accepts, and so does the owner check.

**Controls to add to R1's acceptance list** (DESIGN §6.1), with the catching slot predicted:
1. `e` at a padded vocabulary entry with `M = max + 1`: refused by VZC's pad term.
2. `e` at a non-maximal `j` with `M = max + 1`: refused by RSEL (A6).
3. `tok_0 = BOS + 1`, `h_q(0) = 0`, an arbitrary row 0: refused by the query zero-check through
   the BOS clause's own coefficient.
4. `tok_0 ≠ BOS`, honest otherwise: refused by the same clause.
5. A position selector `s = (2, −1)` summing to 1: refused by SBOOL.
6. A consistent re-lookup in `A_in` under the honest seal: refused by IO-in.

---

## 4. Recommended ruling text for R9 (for the security owner)

> **R9: the two-site input token endpoint (token-I/O run profiles only).** The external input
> token endpoint of a token-I/O run profile that hides the prompt length (D25 T2) or proves a
> greedy continuation (mode ii) is a hiding commitment with **two claim sites**. Its geometry is
> derived, never declared: `rows = data + 2·2 + 2`, row width 2^8, rate 1/8 (2^-106.25 per
> opening). It is built by its own spec type under its own digest domain, and any other row count
> is refused by name (M-1 applied to an external endpoint).
>
> The prover seals it at proof time (D18). Its root is absorbed in the run header and is never
> registered, republished or referred to by a later artifact (D23).
>
> It is claimed exactly twice:
> - by stage IN's IO-in, on the token half (half 0) at a point whose half bit is a public 0;
> - by stage OUT's IO-s, on the selector half (half 1, `s = e_{P−1}`; in mode ii, by SHIFT on the
>   token plane) at a point whose half bit is a public 1.
>
> Each claim has its own reserved pair. Each IO slot runs over its whole half with the public
> support factor, so every pad word is bound to zero.
>
> It is **opened exactly once, after stage OUT's and `B_out`'s openings**, with both claims in that
> opening. The run verifier carries the stage-IN claim to that point and refuses any other opening
> place, claim count or second opening. The variant (public row / P / F), the geometry and the
> opening place are fixed by the run statement's parameter and stage lines, never by a segment.
>
> The input owner receives the decommitment (every row, every row's 256 pads, the salts) privately
> (D21, D25 T5). It checks:
> - the root, by re-encoding at the derived geometry;
> - the profile's BOS at position 0, its prompt, the pad ids, and zero pad words;
> - `s = e_{P−1}`.
>
> The privacy statement places the owner outside the adversary for its own endpoint.
>
> **Variant P is the hidden-length construction. F** (the selector in the output endpoint, one
> site) **is the recorded fallback**. C (an in-circuit length) is not adopted.
>
> This ruling admits the geometry and the public half-bit claims for construction. It is **not a
> privacy acceptance**. The D17 rule 3 joint-view gate (G-6 / G-7) on captured receipts at both
> geometries (T ≤ 128, column half bit; T512, row half bit) is owed before any figure from a
> hidden-length or mode-(ii) receipt is quoted.

---

## 5. Reproduction

* `python3 -B results/zk60_token_io_design_20261017/check/check2_probes.py` writes
  `check/check2_probes.json`. One thread, under a second. It imports `../r0/token_io_ref.py` and
  `token_io_vectors.model()` read-only, and never calls `token_io_vectors.main()`, which writes.
* R0's suite, run from `/tmp`:
  `python3 -B -m unittest discover -s results/zk60_token_io_design_20261017/r0 -p 'test_*.py'`
  gave 13 tests OK in 0.71 s.
* Pass 1 artifacts are unchanged: `CHECK.md`, `check_arith.py`, `check_arith.json`.
