# Adversarial check: DD, the per-row division dictionary for the attention softmax

Checker lane, 2026-10-19, 09:35–09:55 UTC. **Paper and one-thread Python only.** Nothing was
built, proved or measured, and nothing in git was written. I did not write the proposal.

**What was checked:** REVIEW.md, section "ROUND 2", §R2.4 (DD) and the counts in
`variants_r2.py` / `variants_r2.out.txt` (sha256 `0d005919…` / REVIEW.md `0eba417c…`). I read
it against the R6 native tree, read-only:
`results/zk60_1b_native_20261017/r6/frozen-tree/hashline/src/private_block/` (`layout.rs`,
`argument.rs`, `protocol.rs`) and `tables_attn.rs`. I also read the LogUp check
(`results/zk60_soundness_recount_20261017/check_logup/CHECK.md`), the register (D12, D12a, the
D15 notes, D16, D22, D24, D27, D28, D29), the trained privacy draft and its rank/CFS method,
NL-1..NL-8, and B6_REPORT.

**Labels:**
* [COUNTED]: exact arithmetic, reproduced by `dd_check.py`.
* [TOY]: an illustration over a 61-bit prime, also in `dd_check.py`. It is not a proof.
* [PAPER]: my own argument, checked by nobody else.

---

## 1. Verdict in plain words

* **DD is sound as proposed, provided the dictionary has no unconstrained position.** The proposal
  says "all slots are proved". That sentence carries the whole of DD's soundness, and three more
  conditions travel with it. Each is made binding below (B-1 to B-3).
  * If any slot escapes the division check, the cheat goes through deterministically, whatever
    the challenges. My toy passes it 20 times out of 20 (§3.1, D-3). Examples of such a slot:
    a padding slot gated off, a padded row, or a lifted cube position.
  * The same holds if the dictionary multiplicities are committed after α instead of in `A`
    (D-8, 20/20).
  * The same holds if the row key is dropped from the tuple (D-4, 20/20).
* **The outputs stay bit-exact, and no numerical ruling is needed.** I confirmed this: 196,608
  score entries at the 8B calibration all match the per-entry floor, bit for bit [COUNTED].
* **The LogUp bound changes form, but not in a way that matters.** With a committed table side
  it becomes (N + 2303 + 4·T_DD)/|F|. Here T_DD = 2^19 is the number of dictionary slots.
  * The proposal claimed +0.40 bits; the corrected gain is **+0.39 bits** per block at 8B T512.
  * Per block: 2^-100.12 against 2^-99.73 today.
  * Per 32-block run: 2^-95.12 against 2^-94.73 today [COUNTED].
* **Privacy holds in the linear and algebraic sense, but there is one real new residual.** The
  verifier learns nothing about which values a row uses, how many, in what order, which slots
  are empty, or the row's Sum. That holds as long as every new claim site has its own reserved
  pair and the dictionary's table helper joins the single value-0 sum claim. P-3 is untouched.
  * **The new residual:** whether the prover hits a zero LogUp denominator now depends on hidden
    data, because the table values contain the hidden quotients.
  * Today that event is a function of the challenges and the public tables alone (D22 §9
    item 10; trained draft term S-4).
  * Under DD the two-world distance is 2·L·(768 + T_DD)/p², about **2^-103 per 32-block run** at
    8B T512, against 2^-112.4 today.
  * It is far below the statement's total of about 2^-70. But it falsifies a sentence the
    statement relies on, so the security owner must rule on it (§6 draft note).
* **Completeness needs one condition stated in full.** The dictionary has `cap` = 32 slots per
  row. That must count the set {0} ∪ the table's outputs, not just the distinct outputs.
  `cap` is one constant per run profile, so it must cover every layer of the run. The trained
  door must refuse anything larger by name, before the header, where D29 already puts
  refusals.
  * **Today's exports fit:** 19 / 11 / 6 values at 8B; the older 8B T32 export has e_s = 1,
    which is **exactly 32**; TinyLlama has 24 / 14 / 8.
  * **The trained door's declared class does not fit:** only 116 of its 272 members fit 32.
  * **B6's untested layer-1 candidate (a), e_s 0, needs 55 slots.** That forces cap 64 for all
    32 layers, and DD's saving falls to −18.9%.
* **The count is slightly optimistic: −20.8% committed, not −21.0%** [COUNTED].
  * `variants_r2` scores the new dictionary zero-check at 18 terms, but never adds its 11 `A` and
    7 `H` claim sites (36 mask rows, 1.18 M elements) to the layout.
  * Byte lookups −28.2% and element-terms −20.1% reproduce exactly.
* **Is DD ready to be specified into the 8B T512 profile? Yes, as a specification**, with binding
  changes B-1 to B-8 written into it. Before any receipt of that profile is called sound or
  private, these are owed:
  * the security owner's ruling on the hidden-table note (§6);
  * an independent soundness review of the written relations, including D16 rule 5's audit,
    since P's range is now transitive;
  * the gate re-run (rank/CFS, NL-1 machine check, terminal identity) on captures of that
    profile;
  * the calibration lane's T512 export with n_col ≤ cap at every layer.

  It changes no existing profile and needs no ruling from Victor.

---

## 2. What DD changes in the native relation (read from the R6 tree)

**Today, at each score entry** (`argument.rs:1828-1837`, slot 17 `SC_SZC`):

* c2: `mask·E·2^F_P − P·Sum − σ = 0`
* c3: `ρ + σ + 1 − Sum = 0`
* c4: `P = limbs(P)`
* the limbs of σ, ρ and P are byte lookups with top pins (`layout.rs:771-779`).

So P is the floor quotient, and Sum ≥ 1 is enforced at every entry.

**DD moves c2–c4 onto the dictionary.**

* A new domain (h, t, k) holds `cap` slots per row. Slot k carries:
  * a public value e_k;
  * a committed quotient P_dict, with its limbs;
  * σ and ρ, with their limbs;
  * a committed multiplicity m;
  * an `H` table helper g with the relation g·(α − τ) = m, where
    τ = g_DD + key + β·e + β²·P_dict.
* The dictionary's U8 lookups have their own pair helpers on the new domain.
* **Each score entry keeps** S8, RSL, ZSEL, E and P. It carries one single-lookup helper for
  the tuple (key, mask·E, P).

**What does not move:**

* The exp pair (δ, E) is unchanged (`argument.rs:1837`).
* The argmax clauses c0 and c1 are unchanged.
* The row-sum host SC_RS is unchanged (`argument.rs:1268-1281`).
* PV still reads P.

**Transcript order** (`protocol.rs:959-1143`): `A` (all planes and the histograms) → `M` →
β, γ, α → `H` → the slots. **DD keeps P_dict, its limbs and m in `A`**, which is what makes the
LogUp argument below go through.

---

## 3. Findings, point by point

### 3.1 SOUNDNESS

| # | Attack | Verdict | Counterexample or reason | Minimal repair (binding) |
|---|---|---|---|---|
| S-1 | A slot holds a wrong quotient | **holds** | Each slot satisfies today's clauses c2/c3/c4 verbatim, with σ, ρ < 2^wrho_s and P < 2^(F_P+1) pinned by limbs. So 0 ≤ σ ≤ Sum − 1, and the quotient is the floor. No wrap: P·Sum + σ < 2^10·2^19 + 2^18 at 8B T512, and < 2^35 over the trained class (clog2 T + f_e ≤ 24) | — |
| S-2 | An unused or padding slot (k ≥ n_E, or unused k < n_E) absorbs a cheat | **holds as proposed; a hole if any slot is gated.** Multiplicities are free field elements, so one unconstrained table position admits any tuple | [TOY D-3] Padding slots carry no division clause. The prover writes (row, E, P_bad) into one with m = 1 and moves one count off the honest slot. The rational identity then holds exactly: **20/20 pass**. With every slot constrained: 0/20 | **B-1:** the division clauses and limb lookups apply at **every k < cap**, with no "used slot" or "k < n_E" indicator. The only gate allowed is the row support of B-3 |
| S-3 | Padded rows (h or t padded) and lifted positions (dictionary natural log below the row width; the P-3 lift applies, since the domain carries `H` planes) | **needs change (unspecified).** On a padded row Sum = 0 (zero rule), so c3 cannot hold and must be gated. That leaves positions whose content nothing constrains | As for S-2, a padded position with free content and nonzero m could hold any tuple. It is unreachable from a true row only if its key differs from every true row's key. For a padded row that holds (row id, or Sum = 0 by the zero rule). On lifted positions it depends on how the lift lays out the extra cube and what the key column holds there (repeated row ids would make them reachable) | **B-3:** on every padded or lifted dictionary position the public e column is 0 (e(y) = supp(y)·e_k), and P_dict, σ, ρ and their limbs are in the pad-zero group; m and g are exempt (the LogUp arm keeps speaking, as P-1 rules). Every position is then a valid tuple (key, 0, 0) for any key. Not exercised at 8B T512, where nothing pads |
| S-4 | A score entry reuses another row's slot | **holds with the row key; a hole without a key** | [TOY D-4] Tuple (e, P) only: an entry of row A presents row B's quotient for the same e and moves one count. **20/20 pass**; with the row key, 0/20. Concrete case: Sums 600 and 1200 with e = 512 give quotients 436 and 218 | The key is mandatory (as proposed). **Option (sound, cheaper): key by Sum instead of the row id.** Read A_SUM, which slot 17 already reads; this drops the new 2^23-entry public row table from slot 17. Validity is then intrinsic, since (Sum, e, ⌊e·2^F_P/Sum⌋) is right whichever row it came from. [TOY] honest 20/20, bad P 0/20 |
| S-5 | Multiplicities on a hidden table | **holds iff m sits in `A`** (as proposed: m is one of the 10 `A` planes) | [TOY D-8] If m is committed after α (say on `H`), the identity is one linear equation in many unknown m, and **20/20** cheats pass. In `A`, p > N (N ≈ 2.45·10^8 ≪ p) and the logarithmic-derivative criterion apply unchanged: a bad query's pole has no table pole to cancel it | **B-2:** P_dict, its limbs and m are committed in `A`, before β, γ and α, with the histograms. This is stated, not left implicit |
| S-6 | Duplicate slots (padding repeats e = 0) | **holds** | Every slot with the same (row, e) proves the same unique quotient, so duplicates only split a count | — |
| S-7 | Is each slot bound to its own row's Sum? | **holds structurally; needs one line in the spec** | Sum is A_SUM read on the leading (h, t) variables, as slot 17 reads `isum` (`argument.rs:1738`) | **B-4:** the dictionary cube orders its variables (h, t \| k), with (h, t) in A_SUM's own variable order; Sum is a new `A` claim site of the dictionary slot |
| S-8 | Tuple compression | **holds** | g_DD + key + β·e + β²·P has degree 2 in β, and γ·TAG_DD differs from 129 / 133 / 134. All three components are fixed before β and γ | **B-5:** TAG_DD is a new constant, distinct mod p, bound in the schedule line |
| S-9 | Score-side P is no longer range-proved by its own limbs | **needs change (documentation and audit)** | P's range now comes by membership: P = P_dict, which is limb-pinned. PV's no-wrap and IOR depend on it. This is sound, but D16 rule 5's audit and `layout.rs:655-663`'s premise are written for direct pins | **B-6:** rewrite the softmax clause of the construction premise ("p < 2^(F_P+1) by membership in the dictionary") and re-run the rule-5 audit, accepting range-by-membership in a committed, pinned table |
| S-10 | LogUp bound with a committed table side | **holds, with the constant corrected** | §4 | Quote (N + 2303 + 4·T_DD)/\|F\| |
| S-11 | The new dictionary zero-check | **holds** | 20 rounds at degree ≤ 5, about 2^-121 per block: inside the recount's sumcheck term | — |
| S-12 | Masked positions | **holds** | The tuple carries mask·E, so a masked entry is (key, 0, P). That matches only an e = 0 slot, whose quotient is forced to 0 because Sum ≥ 2^fE > 0 | (B-7 keeps e = 0 in every row) |

### 3.2 COMPLETENESS

* **C-1 — cap against n_E: needs change.**
  * **Count {0} ∪ the outputs.** Masked positions look up e = 0, and 111 of the 272 class
    members have no zero output [COUNTED].
    * **B-7:** the e column is sorted({0} ∪ exp outputs), padded with 0 to `cap`.
  * **One cap per profile.** The layout is per profile, so `cap` must cover the largest column
    over every layer of the run.
  * **Refuse by name, from public data only.** The refusal names the layer's table key,
    reads no data, and happens at statement construction, before the header (D29).
    `exp_e_s` is checked at `trained_block.rs:491-495` and `:982`, so the check goes there.
  * **Coverage** [COUNTED]:

    | Tables | n_col | Fits cap 32? |
    |---|---|---|
    | 8B b6/b7 exports, e_s 2 / 3 / 4 | 19 / 11 / 6 | yes |
    | Older 8B T32 export, e_s 1 | 32 | yes, with no slack: random T512 rows use all 32 |
    | TinyLlama, e_s 1 / 2 / 3 | 24 / 14 / 8 | yes |
    | Declared class (e_s −8..8, f_e 9..16) | up to 257 | 116 of 272 members fit 32; 137 fit 64 |
    | B6 candidate (a), layer 1 at e_s 0 | 55 | no: cap 64 needed for all 32 layers (−18.9%) |
    | Per-head e_s ("perhead", not recommended) | per head | the e column becomes per head; cap ≥ the worst head |

  * **No T512 export exists yet.** The calibration lane must confirm n_col ≤ cap there.
  * **B-8:** `cap` is a profile constant, bound in the schedule line next to the e-column rule.
    The door refuses n_col > cap per layer. The CS-3 sealing pass adds a defensive dictionary
    miss check, which reports the class only (K-2) and runs before `A` and before the header.
* **C-2 — T32 against T512: holds, as a profile choice.**
  * At T ≤ cap the dictionary is as large as the score domain. Each slot costs 24 committed
    elements and saves 18, so DD is a net loss there.
  * The proposal already limits DD to T ≫ cap: T64 and up, −20.8% at T512. Its −4.3% at T128
    predates the site correction of §5, which makes it slightly smaller.
  * n_E does not depend on T. Sum ≤ T·2^fE ≤ 2^wrho_s stays the window rule.
* **C-3 — refusal before the header: holds with B-8.** The cap check reads public tables only.
  The dictionary miss is unreachable for an admitted witness once B-7 and B-8 hold, so the
  sealing pass refuses nothing new [PAPER].
* **C-4 — zero-denominator liveness: holds.** The chance is at most T_DD/p², about 2^-109 per
  block. It is the privacy item P-4, not a completeness concern.

### 3.3 PRIVACY

* **P-1 — the linear view (rank lemma G-R1): holds; the gate re-run is owed.**
  * The lemma is about geometry only (`PRIVACY_STATEMENT_TRAINED_T32_DRAFT.md` step 2).
  * New `A` and `H` planes and claim sites each get their own reserved pair. New groups appear
    on `A` (the dictionary point, and Sum at its (h, t) coordinates) and on `H` (the
    dictionary point).
  * The verifier's linear view then determines none of the following: the count of distinct
    values per row, their order, which slots are empty, P_dict, m, or Sum.
  * The public items are cap, the e column, the key rule and cap − n_E per layer. All of them
    follow from the public table.
  * **Mask-row delta:**

    | Commitment | Change |
    |---|---|
    | `A` | +22 rows (11 new sites) − 16 (8 dropped slot-17 sites) = **+6** |
    | `H` | +14 (7 sites) − 10 (5 dropped) = **+4** |
    | `M` | +2 rows (24 slots) and +2 functionals (a Standalone slot); the dictionary slot's mask length is (19 + 1)·4 + 2 = 82, or 102 with the pad term, both ≤ 256 |

* **P-2 — the hidden table side in the value-0 identity: holds on one condition.**
  * The dictionary table helper must enter the single sum claim with sign −1. That means
    `HIds::is_table` must include it (`protocol.rs:171-182`).
  * `H` then still discloses exactly 2, which is the public identity.
  * A separate identity per family would add another public zero. That is harmless, but it
    moves the gate's predicted figure. Don't do it unless it is re-predicted.
  * Every dictionary plane is committed and opened only at masked sites. There is no virtual
    claim, so the LogUp* counterexample does not apply.
* **P-3 — the non-linear channel: holds; the machine check re-run is owed.**
  * Every monomial of the new slot carries eq(τ), which is a public table (NL-3).
  * In slot 17, the tuple relation's monomials also carry eq.
  * Degree is ≤ 4, or 5 with the pad term.
  * Run NL-1's `nl_check.py` and the terminal-surjection computation on the new slot-IR export.
* **P-4 — the refusal channel: needs change (a real new residual).**
  * The honest prover refuses when α equals a table value. Today the table values are public,
    and every admitted query is a table value. So whether a refusal happens is a function of
    the challenges and the public tables alone (D22 §9 item 10; S-4 in the trained draft).
  * Under DD, the table values τ = g_DD + key + β·e + β²·⌊e·2^F_P/Sum⌋ depend on the hidden row
    Sums. So the refusal fact depends on hidden data:
    * one world: at most L·(768 + T_DD)/p²;
    * two worlds: 2·L·(768 + T_DD)/p² = **2^-103.0 per 32-block run** at 8B T512, against
      2^-112.4 today [COUNTED].
  * **Repair:**
    1. The prover inverts **every dictionary slot** on every attempt, unused and padding slots
       included, before any multiplicity enters. Then the fact depends on the data only
       through the set of table values, not through m.
    2. The statement replaces S-4's sentence with this genuine input-dependent residual.
    3. The owner rules on it (§6).
* **P-5 — padding the 32 slots: holds.**
  * The number of padding slots is public (it comes from the table).
  * Their content is hidden: P = σ = 0, ρ = Sum − 1, m = 0 when honest.
  * The fill is a fixed public shape.
  * Timing of the dictionary build is out of scope (D20), and it is a fixed loop anyway.
* **P-6 — P-3 stays untouched: holds.**
  * The zero-sum pair `u` stays the last `H` plane on `Dom::Tab`, and log(`Dom::Tab`) =
    log_cols is unchanged.
  * The new domain carries `H` planes. Every sum-claim part keyed (∅, 0, n) lies on data rows,
    not on the `u` rows.
  * At 8B T512 it sits at 2^19, above the row width 2^15. At a small profile it goes through
    `domain_log_at`, with B-3 governing the lifted positions.
* **P-7 — GS-12 analogue (liveness): holds with B-3 and B-7.**
  * Zero-forced padded score positions look up (key, 0, 0).
  * Every dictionary row has an e = 0 slot with P_dict = 0: true rows by B-7, padded rows
    by B-3.

### 3.4 Engineering traps (not soundness by themselves; each would surface as a completeness failure or a mis-signed identity)

* **E-1.** `Ids::is_multiplicity` is `plane >= map[A_MU8]` (`layout.rs:433-435`). Appending the
  dictionary planes after `Dom::Tab` would classify P_dict and its limbs as histograms, and
  `prove_core` would skip writing them. Either place the dictionary block before `A_MU8`, or
  rewrite the rule.
* **E-2.** `HIds::is_table` is a range of 3 (`layout.rs:583-585`), and `logup_sum_claim` signs
  by it. It must include the dictionary table helper (P-2).
* **E-3.** `LOOKUP_DOMS`, `lookup_values` and `byte_histogram_at` must cover the dictionary's 11
  U8 lookups, or `m_u8` is wrong.
* **E-4.** The pad-zero lists (`pad.rs`) change: slot 17 loses P's limbs, and the dictionary
  gets its own group under B-3. The score-side tuple helper is never in a group (P-1's ruling).

---

## 4. The LogUp bound with a committed table side (re-derived)

This follows the structure of `check_logup/CHECK.md` §3. Fix a block. Before β, γ and α, the
prover has fixed `A`, which holds every query plane, every public-table histogram, and now the
dictionary tuples and their m (B-2). Assume the dictionary zero-check is exact; its own error is
S-11.

Then every dictionary tuple is a valid quotient tuple, and every bad query i0 (a tuple that is
not valid in its family) is a polynomial in (β, γ) distinct from every table tuple.

* **B1, compression collision.**
  * Against the public tables: the affine terms, as before, at most 768/|F|.
  * Against the dictionary: a nonzero polynomial of degree ≤ 2 (the β² term), at most
    2·T_DD/|F|.
* **B2, a pole that frees a helper.** α ∈ PP ∪ W, with |W| ≤ 768 + T_DD now. The hidden values
  are fixed before α. This is at most (|PP| + 768 + T_DD)/|F|.
* **B3, the α identity.** Unchanged, with |V ∪ W| − 1 ≤ |V| + 768 + T_DD − 1. The counting step
  |V| + |PP| ≤ N still holds: the tuple helper is single, and the dictionary's byte pairs are
  counted in N.

**Total:** (N + 2303 + 4·T_DD)/|F| per block.

**At 8B T512:**

* N drops from 323,026,944 to 244,908,032 [COUNTED].
* 4·T_DD = 2,097,152.
* Per block: 2^-100.12, against 2^-99.73 today. With T_DD bounded by rows × 19 distinct values,
  it is 2^-100.13.
* Per 32-block union: 2^-95.12, against 2^-94.73.

So DD helps D27's 95-bit MVP target by 0.39 bits, not 0.40. Two of CHECK_LOGUP §5's holes look
different with a hidden table:

* "A multiplicity column that absorbs a cheat" is no longer closed by the table being public.
  It is closed by S-2 / B-1 and S-5 / B-2.
* "The padded table admitting extra values" is closed by B-3, not by entries repeating i mod 256.

---

## 5. Counts at Llama-3-8B T512, row 2^15, per block (independent recount) [COUNTED]

`dd_check.py` part B is written from `layout.rs` / `argument.rs` by hand, not from the speed
plan's replica. It reproduces today's anchors exactly: 663,257,088 committed elements, and
N = 323,026,944 (CHECK_LOGUP).

| Layout | `A` + `H` rows | Committed | Δ | U8 Δ | Element-terms Δ |
|---|---:|---:|---:|---:|---:|
| today | 9,185 + 11,056 | 663.3 M | — | — | — |
| DD cap 32, as `variants_r2` counts it (dictionary slot sites missing) | 7,281 + 8,710 | 524.0 M | −21.00% | −28.2% | −20.1% |
| **DD cap 32, with the dictionary slot's 11 `A` + 7 `H` sites** | 7,303 + 8,724 | **525.2 M** | **−20.82%** | −28.2% | −20.1% |
| DD cap 64 (any layer at e_s 0, hd 128) | 7,463 + 8,948 | 537.8 M | −18.92% | −26.4% | −18.2% |

Per entry, both match the proposal:

* **score entry:** `A` 5, U8 4, Fp2 helpers 4, so 13 committed (was 31);
* **dictionary slot:** `A` 10, U8 11, helpers 7, so 24 committed.

The element-terms convention counts committed reads only. With the row key, slot 17 gains a
2^23-entry public row table, which the convention does not count. The Sum key (S-4) avoids it.

**Roofline and bandwidth figures** in R2.7 move by about 0.2 points with the −20.8%. I did not
recompute them.

---

## 6. Draft security-owner privacy note for the hidden-table element

*(Draft text for the owner to rule on. It is not a ruling and not a privacy acceptance.)*

> **Hidden lookup table in the value-0 LogUp identity (DD, the per-row division dictionary;
> proposed for the Llama-3-8B T512 profile only).**
>
> **What it is.** Every lookup table of the private block has been public until now. DD adds a
> committed table: per attention row, `cap` slots (a profile constant ≥ the column size of
> every layer's exp table, sorted({0} ∪ outputs)). Each slot is the tuple (key, e, P_dict). The
> key is the row id or the row's Sum, e is public, and P_dict = ⌊e·2^F_P/Sum⌋ is proved by the
> existing exact-division relation with byte-limb windows. Each slot has a committed
> multiplicity and a table helper g with g·(α − τ) = m. Each score entry replaces its own
> division limbs with one tuple lookup into its row's slots.
>
> **Ruling sought (construction rule; not a privacy acceptance):**
>
> 1. **Every dictionary position is a valid tuple.** At every slot of a true row, the division
>    clauses and limb lookups hold, with no slot-usage gate. At every padded or lifted position,
>    the public e is 0 and P_dict, σ, ρ and their limbs are pad-zero. Multiplicities and table
>    helpers are never gated.
> 2. **The dictionary tuples and multiplicities are committed in `A`**, before β, γ and α.
>    The tuple is compressed with a distinct tag and β² for P.
> 3. **The table helper enters the single value-0 sum claim** with sign −1. Every dictionary
>    plane is opened only at its own reserved claim site. There is no virtual or unmasked
>    claim, and P-3 (`log Dom::Tab == log_cols`, `u` on `Dom::Tab`) is unchanged.
> 4. **The prover inverts every dictionary slot on every attempt.** The refusal sentence of
>    D22 §9 item 10 / S-4 does not hold for this profile. Whether a zero-denominator refusal
>    happens now depends on the hidden row Sums. Its two-world distance,
>    2·L·(768 + rows·cap)/p² (about 2^-103 per 32-block run at 8B T512), is a counted residual
>    of the statement, not a challenge-only event.
> 5. **The soundness accounting uses (N + 2303 + 4·rows·cap)/|F| per block** for the lookup
>    term, and P's range is accepted as range-by-membership in D16 rule 5's audit.
> 6. **A profile whose exp tables need more than `cap` slots is refused** at the trained door,
>    by name, before any header.
>
> **What it rests on** (to be confirmed before any statement): the generic rank lemma, which is
> geometry-only, re-run on the new layout (`A` disclosed 0; `H` disclosed 2, the public
> identity); NL-1's dependencies, re-run for the new slot (eq in every monomial); the gate's
> constructed-blinding and joint-assignment passes on captures of the new profile; and an
> independent soundness review of the written relations.
>
> **What it does not cover:** any other profile; hidden weights (P3; NL-7 already excludes the
> matmul slots); any table whose entries are not each proved by an exact relation.
>
> **Lapses if:** any dictionary position is left unconstrained; the multiplicities move after α;
> the table helper leaves the single sum claim; or `cap` is ever exceeded without the door
> refusing.

---

## 7. Binding changes, collected (for the profile specification)

* **B-1.** The division clauses and limb lookups hold at every slot k < cap of every true row.
  There is no usage or k < n_E gate.
* **B-2.** P_dict, its limbs and m are in `A`, committed before β, γ and α.
* **B-3.** The pad rule for the dictionary: on padded or lifted positions, e = 0 publicly, and
  P_dict, σ, ρ and their limbs are pad-zero. m and g are exempt; the division clauses are gated
  by support.
* **B-4.** The dictionary cube is ordered (h, t | k). Sum is read from A_SUM on the (h, t)
  variables, as a claim site.
* **B-5.** TAG_DD is distinct and bound. The compression is key + β·e + β²·P.
* **B-6.** The construction premise and D16 rule-5 audit are rewritten for P's range by
  membership.
* **B-7.** The e column is sorted({0} ∪ outputs), padded with 0.
* **B-8.** cap is a profile constant, bound in the schedule line. The trained door refuses
  n_col > cap per layer, before the header. A defensive dictionary-miss check goes in the CS-3
  sealing pass.
* **Plus:** the refusal residual of P-4 (whole-dictionary inversion, restated S-4), and E-1 to
  E-4.
* **Option:** key by Sum instead of row id (S-4). It is sound and drops the 2^23 public row
  table.

---

## 8. Reproduction

* `python3 -I -B results/zk60_gpt_nonlinear_review_20261018/dd_check/dd_check.py`
  * One thread, under a second.
  * Output: `dd_check.out.txt`; data: `dd_check.json`.
  * It imports nothing from the proposal or the speed plan.
* Ledger: `PROGRESS.md` in this directory.
