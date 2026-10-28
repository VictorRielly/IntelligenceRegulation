# D24 review, round 9: the native R9 tree (DD, the per-row division dictionary)

**Verdict: R9 is ACCEPTED on soundness at the three DD profiles**: TinyLlama-1.1B T128 DD, Llama-3-8B T128 DD, and the synthetic DD development rung. D30 requires an independent soundness review before any DD receipt is called sound, and this is that review.

**No soundness finding.** There are seven notes, N-r9-a to N-r9-g. Two of them (N-r9-a, N-r9-b) are proposed as register conditions.

**What this is not.** It is not a privacy acceptance. D30's remaining gates still come first: the rank lemma, NL-1, and the gate's constructed-blinding and joint passes on DD captures. Only Victor rules on privacy.

## What was reviewed

* The native R9 freeze of 2026-10-20T04:52:07Z: `results/zk60_1b_native_20261017/r9/frozen-tree/`.
  * Tree hash af90c703ed7b2791d1771dd6e443edf4339bf5fa84a32e0d4a57ed38c3b0a41a, 222 files.
  * My copy is `ops/zkp-mvp/trained-1b-review-r9/`. Its `.sha256` equals `r9/manifest_frozen.json`, and the tree hash recomputes.
* `r8-vs-r9.patch`: 2,911 lines over 28 files, the same as the author's patch.
* The specification:
  * D30, conditions (1)–(6);
  * `dd_check/CHECK.md`, B-1..B-8 and §4;
  * REVIEW.md §R2.4.

## In plain words

### What DD changes

Before R9, every attention score proved its own division (P = floor(e·2^F_P / Sum)) with its own byte limbs.

Under DD, each attention row gets 32 dictionary slots. Each slot proves one quotient with exactly the old division relation, and each score entry only shows that its (row Sum, e, P) is one of its row's slots.

That is cheaper. It is sound only if four things hold:

1. every slot is really constrained;
2. the slots are fixed before the random challenges;
3. a wrong P cannot find a matching slot;
4. the 32-slot cap is never silently exceeded.

### What I found

All four hold in the code as built, and in what I ran:

* I verified both DD receipts fresh, with 11 controls each.
* I built my own attacks. The main one is a dictionary that is entirely consistent with a false row Sum. It is rejected, and only by the unchanged row-sum relation.
* I re-derived the lookup soundness term. DD improves it slightly.
* I confirmed that non-DD proofs are byte-for-byte what R8 produced.

## The eight review items

### 1. Every dictionary position is constrained, with no usage gate

**Code.** The dictionary zero-check (`SC_DD`, argument.rs:2038) evaluates the following at every slot of the cube (h, t | k), all multiplied by `eq(tau)` only:

* `c2 = e·2^F_P − P_dict·Sum − ρ`;
* `c3 = σ + ρ + 1 − Sum`;
* `c4 = P_dict − limbs`;
* the byte lookups of all limbs with their top pins (layout.rs `Dom::Dd`);
* the table relation `g·(α − τ) − M_dd`.

The only gate in that arm is the `cfg(test)` D-3 lapse, and `dd_lapse` is a constant false in release builds. Both DD arms (`SC_SZC` and `SC_DD`) refuse `pad_on`.

**The restriction that makes B-3 vacuous** is `Shape::check_dd_geometry`:

* `h_pad = q_heads`;
* `t_pad = T`;
* the cap is a power of two;
* `Dom::S` and `Dom::Dd` are unlifted, with size equal to true size.

It runs in `Shape::build` for every profile that `DD_PROFILES` names.

**Where the restriction is enforced.** `dd_cap` is derived only from the profile string, and ruling CS-8 rebuilds the shape in all four cores (protocol.rs:914/1037/1342/1469). My test B wrote `dd_cap` into 12 shapes: non-DD shapes with 32, and DD shapes with 0, 16 or 64. CS-8 refused all 12, and the run-shape door refused them as well.

**Geometry.** My test C found S, Ht and Dd unpadded and unlifted at all three profiles:

| Profile | log_cols | S | Ht | Dd | Notes |
|---|---|---|---|---|---|
| TinyLlama T128 DD | 14 | 2^19 | 2^12 | 2^17 | |
| Llama-3-8B T128 DD | 14 | 2^19 | 2^12 | 2^17 | |
| DD rung | 10 | 2^13 | 2^8 | 2^13 | — |

At every profile:

* every dictionary limb lookup reads only `Dom::Dd` planes;
* the score domain keeps exactly sym(s8) and the rsl pair.

**Pads.** A slot past `n_col` holds e = 0, so c2 forces P_dict = 0 and ρ = 0, given Sum ≥ 1 from c3. The pad is therefore the tuple (Sum, 0, 0) by the clauses themselves.

### 2. Commitment order, tag, β², and the Sum key

**Order.** The A root, which binds P_dict, its limbs and M_dd, is absorbed before β, γ and α:

* by the prover, at protocol.rs:1119–1140;
* by the verifier, at protocol.rs:1363–1367.

The verifier's transcript is what decides soundness, and it fixes M_dd before α.

**Plane placement.** Test C shows that P_dict, its limbs, the ρ/σ limbs and M_dd are all A planes on `Dom::Dd`. None of them is a histogram the prover derives, so the witness supplies them and they are committed with A.

**Tag and β².** TAG_DD is 141, distinct from 128–134. P enters as β²·P. The tag g_dd = γ·141 is formed identically in both `Ctx`s.

**The key is sound because of what binds Sum.**

* c3 pins 1 ≤ Sum < 2^(wrho_s+1), where wrho_s is 16 at both T128 DD profiles.
* SC_RS (unchanged, hosted at SC_SZC) binds Sum to Σ_j mask·E over the row.
* A tuple (S, e, floor(e·2^F_P/S)) is a function of (S, e). Two rows with equal Sums therefore share only valid tuples, and keying by row id would add nothing.

**Test A shows the dependency.** At row 0 of the DD rung I moved Sum from 4096 to 4095. That move leaves every quotient of the row's 32 slots unchanged, and I rewrote the row's ρ/σ limbs to match. The resulting witness satisfies, at the integer level:

* c2, c3, c4 and all pins at every slot;
* `dd_misses = 0`;
* no byte, exp or activation miss.

The only broken fact is the row sum, at that one row. The verifier rejected it at slot 17, the softmax zero-check that hosts SC_RS ("hosts 07, 10"). So the key is exactly as strong as SC_RS (N-r9-a).

### 3. The table helper in the single sum claim; reserved sites only

* `HIds::is_table` includes `gdd`, so it enters with sign −1. The score tuple helper `stuple` enters with +1. Both are in `logup_sum_claim`. The out-of-sum lapse is `cfg(test)`.
* SC_DD opens the dictionary planes only at its own sites:
  * a = a_planes_on(Dd) + 1, the extra one being the A_SUM slice on the leading (h, t) variables;
  * h = helpers(Dd) + 1.
* There is no virtual claim.
* P-3 is unchanged: `u` is the last H plane, on `Dom::Tab` (native test).

### 4. D16 rule 5: P's range by membership

Every committed value under a non-unit coefficient in the DD relations has an independent range:

| Value | Where it appears | Range | Source of the range |
|---|---|---|---|
| P_dict | under Sum in c2 | 0 ≤ P_dict < 2^(F_P+1) | its own byte limbs, pin 2^(8·lp − F_P − 1) |
| Sum | in c2, c3 | c3 range, and value fixed | c3 and SC_RS |
| ρ, σ | c2, c3 | < 2^wrho_s | limbs with top pins |

On the score side, P under V in the PV product no longer has limbs of its own. Its range is by membership:

* The LogUp argument gives (Sum, mask·E, P) equal, as field elements, to some committed slot tuple, except with the counted lookup probability. This holds because all three components are committed before β and the compression has degree 2 in β.
* That slot's P_dict is limb-pinned.

**The range is also tighter than before.** Every exp table is monotone with E[0] = 2^f_e as its maximum. `exp_member` asserts this, and I re-checked it on every layer of the exports below. So Sum ≥ e for every column value, and P ≤ 2^F_P. The old pin was P < 2^(F_P+1), so the PV no-wrap premise is unchanged (my round-8 worst case was 2^43.32).

**c2 and c3 do not wrap.** At T128 DD:

* P·Sum + ρ < 2^10·2^17 + 2^16 < 2^28, far below p;
* e·2^F_P ≤ 2^18.

**The range holds.**

### 5. The LogUp term [COUNTED] (my test D)

How the count is made:

* N = the byte lookups over every position of each lookup domain, from the **built** list. I cross-checked it against the shape's counter.
* Plus |S| exp pairs, plus |F| activation pairs.
* On DD, plus |S| tuple queries.
* T_DD = rows × cap = 131,072.

The term per block is (N + 2303 + 4·T_DD)/p², where p is the Goldilocks prime. The term per run is the union over the run's blocks. Shapes are taken from the exports' own runs, and they equal the test calibrations' figures.

| Profile | non-DD N | non-DD per block | non-DD per run | DD N | N + 2303 + 4·T_DD | DD per block | DD per run |
|---|---|---|---|---|---|---|---|
| TinyLlama dg T128 (22 blocks) | 30,572,544 | 2^-103.13 | 2^-98.67 | 27,557,888 | 28,084,479 | 2^-103.26 | **2^-98.80** (+0.12 bit) |
| Llama-3-8B b7voc0 T128 (32 blocks) | 54,558,720 | 2^-102.30 | 2^-97.30 | 51,544,064 | 52,070,655 | 2^-102.37 | **2^-97.37** (+0.07 bit) |
| DD rung (per block) | — | — | — | 747,520 | 747,520 + 2303 + 32,768 | 2^-108.42 | — |

In the table, "N" is the per-block query count, "per block" and "per run" are the lookup term, and the "+" figure is the gain in bits from DD.

**Byte lookups.** These match the native counts:

* TinyLlama: 28,999,680 → 25,460,736;
* 8B: 51,937,280 → 48,398,336.

**The whole-run floor.** At the DD profiles, the whole-run union of the lookup term is 2^-98.80 for TinyLlama T128 (22 blocks) and 2^-97.37 for 8B T128 (32 blocks). Both are better than their non-DD twins, and both are inside D27's MVP tier.

D27's named workload is 8B T512. CHECK.md §4 gives 2^-95.12 per 32-block run there, and I did not re-count T512 because it is not built.

### 6. The cap refusal, by name and before any header

**The four places, read and exercised:**

1. **The block statement.** `BlockPublic::check_for_shape` covers both cores, the run statement's `blocks_fit_the_shape`, the run prover's and verifier's `fit_the_shape`, and CS-3's sealing pass.
2. **The witness builder.** The `dd_e_column` call refuses inside the first attention row; see N-r9-c on its placement.
3. **The trained loader.** `load_layer` refuses with the layer index and its e_s. `stack_records` loads every layer before any header.
4. **The run statement.** `new_bound` refuses via `blocks_fit_the_shape`.

**What the cap counts.** `dd_e_column_of` counts `{0} ∪ outputs` after sort and dedup, and refuses when the count exceeds 32.

**My test E.** I wrote DD-rung exports myself, with a real export format and a synthetic source:

* The over-cap layer (e_s 0, 44 slots) is refused at the loader with: "layer 1 (exp_e_s 0): private block: D30 / B-8 — ... 44 slots ({0} U its outputs), more than the profile's cap of 32; refused by name before any header".
* The over-cap layer is also refused by `stack-prove` (with and without `--dd`) and by single-block `prove`, with no output and no unverified directory left behind.
* A verifier asked for the over-cap layer refuses, both `stack-verify` and `verify`.
* The in-cap layer range `--layers 0..1` of the same export proves and verifies, so the door is per layer.

**Real exports.** I recounted `n_col` from each layer's `exp.bin` after checking its SHA (`r9/r9_ncol_check.json`):

| Export | Worst n_col |
|---|---|
| TinyLlama dg T128 | 24 |
| 8B b7voc0 T128 | 19 |
| 8B b7 T64 | 19 |
| 8B pg_rot1 T32 | exactly 32 |
| TinyLlama T32 | 24 |

None is over the cap, and every table is monotone.

**At the rung** (head_dim 32, f_e 12), e_s 1..8 fit and e_s ≤ 0 do not.

### 7. Non-DD byte identity

* **Seeded goldens on my R9 build**:
  * TinyLlama T128: 782b64c97a88cba4c6c34a2fecb73132f26d5f54adc9bd159f3d6cf9df4205c0;
  * 8B T128: 05a22d72a892aff5fb2e35da4d0ab0c894d696f2e6afa542b6ecece5aeb9f4db.
  * Each run has 23 slots and 69 absorbs, and both equal the recorded R8 digests.
* **The same record-mode file in my own copy of the R8 freeze** printed the same two digests (`r8-golden-run`; 23 slots, 69 absorbs). That copy equals `r8/frozen-tree/` plus that file and its registration. So I reproduced the R8 side independently too, not only the native lane's recorded constants.
  * The digest covers everything the seeded core produces: the roots, every slot proof, the openings, the IO claims, the absorb order and the final transcript state.
* **R8 receipts under my R9 CLI**, with no `--dd`: TinyLlama caf6ced2... and 8B 5585f5ee... verify, and their published statements check byte-for-byte.
* **No 24th slot, mask row or functional off DD.** I read every DD-touching path:
  * `n_slots` / `m_rows` / `n_functionals` are 23 / 50 / 34 off DD;
  * `slot_terms` changed `>= SC_IO_IN` to `== IO_IN || == IO_OUT`, which is identical for s < 23;
  * the `a_plane_doms` / `lookups_at` / `claim_sites` / `prove_core` branches are all gated on `dd_cap > 0`;
  * the SC_SZC DD arm is a separate guarded match arm;
  * the dictionary and slot-23 schedule lines appear only on DD (native check-(c) test).

### 8. The lane's mutation tests

**The harness is real.** `mutation()` first requires the cheat to **pass** against its lapsed construction. The test panics with "proves nothing" otherwise. Only then does it require rejection as built.

**What each cheat does:**

* **D-3**: a wrong (Sum, 0, 1) at an e = 0 padding slot, with a count moved there.
* **D-4**: another row's quotient for the same e, with a count moved across rows.
* **Helper out of the sum**: P off by one with no count moved.

Each edit recomputes the PV accumulator so that only the dictionary can object.

**What the lapse switches do.** Each removes exactly the protection its test targets, and only in `cfg(test)`:

* gate the last slot;
* drop the key on both sides;
* drop `stuple` and `gdd` from the sum.

**Results.** All 10 `r9_tests` pass on my binary. Re-run with output (`r9-author-r9tests-nocapture`), each cheat passes its lapse and is rejected by exactly the relation it targets:

| Cheat | Rejected at |
|---|---|
| D-3 | slot 23 (SC_DD, the division at that slot) |
| D-4 | the H opening of the single value-0 sum claim ("H: pcs zk: group 9: <v, c> != combined claim") |
| Helper out of the sum | the same H opening |
| D-8 hook | slot 23 (the table relation against the committed M_dd) |

In the same run, the over-cap block is refused by the run statement itself.

**The lapsed D-8 variant** (multiplicities chosen after α) is not built here. I judge that sufficient, because:

* M_dd is an A plane;
* the verifier absorbs the A root before drawing α;
* the zero-check ties the table helper to the committed M_dd at every slot, with no gate.

The native D-8 test shows that a helper whose counts move after α is rejected at slot 23. CHECK.md's toy (20/20) shows the attack is real against the lapsed construction. The lapsed construction would need M_dd moved out of A or a challenge drawn before the A root, and neither path exists in the code. See register condition N-r9-b.

## Findings

None.

## Notes

* **N-r9-a — the Sum key rests on SC_RS** (proposed register condition).
  * D30's key = row Sum is sound because SC_RS binds Sum to the row sum and c3 pins its range.
  * Test A shows that a dictionary consistent with a false Sum is caught by SC_RS and nothing else.
  * Condition: any change to SC_RS, to its hosting at SC_SZC, or to the Ht gate re-opens D30. `review_r9_a` is the regression test.
* **N-r9-b — D-8 by structure** (proposed register condition).
  * M_dd stays an A plane below the histograms.
  * No LogUp challenge is drawn before the A root, on the verifier side.
  * Moving either re-opens D30.
  * Regression tests: the native check-(c) test (`mdd < A_MU8`, not a multiplicity) and my test C.
* **N-r9-c — where the witness builder refuses.** The builder's over-cap refusal fires inside the attention row loop, after the norm and Q/K/V. Its entry check calls `AttentionPublic::check_for_shape`, which lacks the DD fit (only `BlockPublic`'s has it). The refusal is still by name and before any header, so condition 6 is met. This is about placement only.
* **N-r9-d — completeness depends on monotone tables.** The builder refuses a slot quotient above 2^F_P. That case cannot arise, because every in-class table is monotone with E[0] = 2^f_e, which `exp_member` asserts. A non-monotone table would cost completeness, never soundness, since the limb pin is 2^(F_P+1).
* **N-r9-e — choosing the relation.** A DD run and a non-DD run of the same export have distinct statement identities (the run profile is bound), so a relying party's pin selects the relation.
  * A verifier given the wrong `--dd` refuses at the pin. TinyLlama: 6b280d06... rebuilt versus d5721276... pinned; the single block likewise.
  * With the other relation's identity pinned, it refuses at the wire: the segment lengths differ by 235,008 B at both T128 profiles.
    * This held for 4/4 stack receipts.
    * It held for the single-block DD receipt too: 23,284,280 B against a counted 23,049,272 B.
    * The run header's profile binding sits behind that.
  * Worth one line in the one-pager: "a DD receipt is verified with `--dd` and has its own identity".
* **N-r9-f — profile names.** The TinyLlama DD block profile is `...-t128-trained-ddict/1`, while the 8B one is `...-t128-ddict32/1` (the cap is named in only one). Both are distinct and bound. This is cosmetic.
* **N-r9-g — the inconsistent-witness controls are not DD-specific.** The CLI's three inconsistent-witness controls at a DD profile (norm word, query word, cn_m + 7) are rejected at the D and Q zero-checks. My test A and the native mutation tests are the DD-specific forgeries.

## Evidence

Everything below is under `results/zk60_d24_review_20261017/r9/` unless a path says otherwise. All runs were guarded, detached and serial, on a shared box, n = 1.

* **Queue A** (`r9_queue_a.sh`):
  * my CLI from the pristine copy: sha256 d552e96f..., versus the author's 53c2ccac... (build paths differ);
  * `r9-dd-tl`, `r9-dd-8b`: verified, with 11 controls each, statement checked;
  * `r9-compat-tl`, `r9-compat-8b`: verified;
  * `r9-sb-dd-prove` (23,284,280 B, 3 inconsistent witnesses refused), `r9-sb-dd-verify` (19 controls refused), `r9-sb-x-noflag` (refused).
* **Queue A2**:
  * `r9-dd-probes2`: 12/12 refused by name, no directory;
  * `r9-xr-*`: 4/4 cross-relation receipts refused.
  * `r9-dd-probes`: the first pass, a harness error that is kept and corrected.
* **Queue B**:
  * `r9-test-build`;
  * `r9-review`: my 6 tests pass (A–F);
  * `r9-author-subset`: 85 passed, 0 failed, 1 ignored. These are the r9_tests, trained_stack/block, r6, r8, s24, s25, s33, pad, cs_port and review_e_ modules on my binary;
  * `r9-golden-r9`;
  * `r8-golden-build` and `r8-golden-run`.
* **Queue C**: `r9-author-r9tests-nocapture`, `r9-xr-sb-as-plain`.
* **My test module** (scratch only): `ops/zkp-mvp/trained-1b-review-r9-scratch/hashline/src/private_block/review_r9_tests.rs`.
* **n_col recount**: `r9_ncol_check.py` and `.json`.
