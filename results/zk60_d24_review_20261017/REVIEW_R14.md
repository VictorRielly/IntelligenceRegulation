# D24 review, round R14: the split-width native backend (S4 B-gate, joint boundaries) on the S2 stack

Reviewer: Claude (Opus 5.5 subagent), independent of Sol's lane. Written 2026-10-30, finished 21:32 UTC (`date -u`).

## Verdict

**R14 is ACCEPTED on soundness** at its four experimental split profiles: Shieldstral-3B T128 and T256, each with and without DD (`…-lowh24[-ddict1]-split-r14/1`). T128 is backed by native proofs; T256 is checked by definition census and by count only, because no T256 proof exists. **No soundness finding.**

Two **low fixes** are recommended. Neither touches a relation, and neither gates the next step:

* **R14-F1 (low; evidence):** the accepted equivalent-row control was retained without the roots and binding it was verified against, so nobody can re-verify that frame in a fresh process (§2, §7).
* **R14-F2 (low; test):** the "generic fully dense" fixture has a down-projection output of exactly 0 everywhere (x2 = x1). No synthetic gate therefore exercises the down path with live values. Only the real-model runs do (§6, §7).

In plain words, item by item:

* **The accepted 50th receipt.** Sol's diagnosis is right.
  * The original mutation moved one count between two dictionary slots that hold the *same* tuple (Sum, 0, 0): a masked-future zero and a padding zero.
  * The verifier checks one total per distinct tuple value, so that move changes nothing it checks. The queried values are unchanged too, so the receipt is a valid proof of a true statement.
  * The replacement negative (a live (Sum, 512, 4096) count moved onto a padding zero) is rejected at the H opening's global LogUp sum.
  * The equivalent-row control is accepted.
  * I prove from the code that no move between *distinct* values can preserve those totals (§2). A small exact probe agrees: 25 of 25 equal-tuple moves pass, and 2,255 of 2,255 distinct-tuple moves fail.
* **Bits.** My recount is independent of Sol's script. It reproduces **97.2589 / 97.3119** (T128 non-DD / DD) to four decimals. After I add a conservative allowance for the zero-check and batching terms that Sol leaves out, the figures are **97.2588 / 97.3118**.
  * That clears D27's ~95 floor by 2.26 / 2.31 bits, and the coordinator's ~96 level by 1.26 / 1.31.
  * On the same full accounting, R13 at the same geometry gives 96.92 / 96.96, so R14 gains 0.34 bit. R13's table figures of 97.30 / 97.36 were the lookup term alone; they are not comparable with R14's whole-run figure.
  * T256, counted only: 96.29 / 96.48.
* **The R13 → R14 diff.**
  * 22 new files, 8 changed, none removed. 11 of the new files are production code; the other 11 are test-only.
  * Every production change is either a new module that only the experimental R14 path reaches, or a refactor whose legacy branch is identical.
  * The legacy goldens equal my R13 golden run, 9 of 9 lines. Eight retained R8/R9/R13 receipts and both R12 Shieldstral receipts verify under the final legacy CLI.
* **Split width, B-gate and boundaries.**
  * Every true lane of every D/F plane sits in exactly one piece, and every piece is constrained by its own zero-check.
  * Each smaller-piece monomial has exactly one public factor, and that factor is zero on the omitted half-cubes. Matmul folds use global indices.
  * Each endpoint or boundary is one joint commitment holding both pieces as ordered row blocks. It is opened exactly once, and every reserved pair is used once.
  * Every root is absorbed before the first challenge that depends on it.
* **Evidence.** Every number the prompt names checks against its logs:
  * 50 malformed relation receipts rejected, and the 1 equivalent control accepted;
  * 16 malformed arithmetic and C3 receipts rejected;
  * 4 honest group contexts verify;
  * the suite: 834 / 0 / 71 on the predecessor source, and 838 / 0 / 75 on the final source;
  * the full 26-layer stack: 443 / 436 s, with frames of 895,146,288 / 901,256,496 B;
  * the fresh verifiers: 85 / 88 s.

  I also recounted all 52 frame lengths from the codec as read.

**This is a soundness review, not a privacy review.** Nothing here accepts R14's privacy, registers a profile, assigns a security tier or covers the classifier and token composition.

## What was reviewed

* **The packet:** `results/zk60_1b_native_20261017/r14/review-author-1/`.
  * `AUTHOR_FREEZE.json` has sha256 `f086db82…`.
  * The source tree is `27b2a427…`, 291 files. It re-hashes 291/291 with no extra files, both at the start of the round and at the end (`r14/tree_check_r14.json`).
  * The three binaries match the freeze: test binary `29a8be1d…`, `zk60_split_stack` `6625a7f2…`, legacy `zk60_trained_block` `260b66eb…`. All 24 tool copies match as well.
* **The evidence manifest:** `EVIDENCE.json`, sha256 `2e8b76c2…`, which equals the freeze's pin.
  * It has 1,997 entries. I re-hashed all 1,595 small entries (≤ 1 MiB): every one matches, and none is missing.
  * The 402 large entries (16.4 GB of frames and arrays) were checked by size only. I read no bulk data.
  * `LEGACY_COMPATIBILITY_ACCEPTANCE.json` and its suite log are **not** in the manifest, because they belong to the predecessor source `86301542` (N-r14-3).
* **The reference:** the R13 frozen tree `bb9eb212…`, 269 files, re-hashed 269/269 (`r14/tree_check_r13.json`).
  * The diff of the manifests: 22 new files, 8 changed, 0 removed.
  * I read in full the 11 new production modules: `argument_split.rs`, `split_layout.rs`, `split_geometry.rs`, `split_profile.rs`, `split_endpoint.rs`, `split_witness.rs`, `split_protocol.rs`, `split_run.rs`, `split_wire.rs`, `trained_split.rs` and `examples/zk60_split_stack.rs`.
  * I also read every changed hunk in `argument.rs`, `argument_accuracy.rs`, `private_block.rs`, `wire.rs` and `trained_block.rs`. The changes to `run_capture.rs`, `s24_tests.rs` and `s25_tests.rs` are test-only.
  * And the R14 tests that build the malicious receipts: `split_attack_tests.rs`, `split_run_tests.rs`, `split_definition_tests.rs` and `split_dense_tests.rs`.
* **The rules:** D12 / D12a / D12b, D15, D17, D19 / D19a / D19b, D22, D24 with its review entries, D27, D30 and D45. Also the R12b and R13 verdicts, `S4_DESIGN_CHECK.md` (C-1..C-11) and the coordinator's construction rules (a)–(e) of 2026-10-29 07:43. Sol's R14 log runs from 2026-10-29 07:40 to 2026-10-30 20:51.
* **My runs:** four guarded **light** jobs, each declaring 0.5 GiB with a 1 GiB cap, under `cgroup+watchdog` enforcement. Each peaked at 0.01 GiB or less and took 4 s or less.
  * `rv14-bits` / `rv14-bits-2`: the bit recount and the frame-length recount;
  * `rv14-evidence`: the log audit;
  * `rv14-manifest`: the evidence re-hash;
  * `rv14-ddprobe`: the item 1(c) probe.

  **I built nothing and ran no proof** (the heavy slot is Sol's and Astra's). Every native [MEASURED] figure below is Sol's, audited from its logs. §8 lists the heavy runs that would close what this leaves.

## 1. Per-item table

Paths are under `review-author-1/source-tree/hashline/src/private_block/`.

| # | Item | Verdict | Where |
|---|---|---|---|
| 1a | Replacement negative (live E ≠ 0 against padded zero) rejected | **CONFIRMED** | `split_attack_tests.rs:563–591`; `final-relations-1/dd-dictionary-counts.log` |
| 1b | Equivalent-row control with retained frame verifies | **CONFIRMED in-process**; no fresh re-check is possible (R14-F1) | `split_attack_tests.rs:286–295`; `dd-dictionary-alias-counts.log` |
| 1c | No move between distinct values preserves the per-value counts | **PROVED** (§2) and probed | `argument_accuracy.rs:401` (table side), `:212` (query side); `argument_split.rs:167–197` (sum claim) |
| 2 | Soundness bits | **97.2588 / 97.3118 at T128** (author 97.2589 / 97.3119); clears ~95 and ~96 | §3; `r14/reviewer_bits_r14.py` / `.json` |
| 3 | R13 → R14 production diff: relations complete, Fiat–Shamir order | **PASS** | §4 |
| 4 | One opening per commitment (D12), fresh draws, both pieces in one boundary commitment | **PASS** | `split_endpoint.rs:73–93, 149–163, 195–206`; `split_run.rs:408–464, 594–615`; §5 |
| 5 | Evidence numbers against their logs | **PASS WITH NOTES** (R14-F1, R14-F2, N-r14-1, N-r14-3) | §6; `r14/audit_r14_evidence.json` |
| — | R13-F1 (carried into R14) | **FIXED** | `trained_block.rs:2002–2040`; `final-validation-1/cli-verify-r13-*.log` |

## 2. Item 1: the accepted 50th malicious receipt

### What the relation is, as implemented

**The dictionary table side** (SC_DD, `argument_accuracy.rs:345–410`, which R14 translates unchanged through `argument_split.rs:446–502`):

* At every slot of the (h, t | k) cube, with no usage gate, these must vanish:
  * the exact-division clauses (c2, c3, c4) together with their limb lookups;
  * and `ctab = g·(α − (γ·TAG_DD + Sum + β·e_k + β²·P_dict)) − M_dd` (`:401`).
* So `g = M_dd / (α − t_k)` at every slot. Every slot tuple t_k = (Sum, e_k, P_dict) is a *valid* tuple, because P_dict is the floor quotient and Sum ≥ 1 by c3.
* A padding slot has e = 0, which forces P = 0, so its tuple is (Sum, 0, 0) (D30 condition 1).

**The query side** (SC_SZC under DD, `argument_accuracy.rs:160–218`):

* At every score entry: `ct = h·(α − (γ·TAG_DD + Sum + β·(mask·e) + β²·P)) − 1` (`:212`).
* A masked-future entry has mask·e = 0 and P = 0, so its query is (Sum, 0, 0).

**The only check on the counts** is the single value-0 sum claim on H (`argument_split.rs:167–197`). It sums every H plane with sign +1, except the table helpers, which take −1; the U pair is proved to sum to 0 by SC_ZS.

* M_dd is an A plane, committed before β, γ and α (`split_protocol.rs:376–397`; verifier `:490–495`). The helpers are committed in H after α.
* M_dd enters no other relation.

### (a) The replacement negative is rejected [MEASURED, Sol's final-source binary, from the log]

The log shows `R14_DICTIONARY_COUNT_TUPLES alias=false from=1 to=31 E_from=512 E_to=0 P_from=4096 P_to=0 row_total=128` and `R14_ATTACK_REFUSAL dictionary-counts: R14 H: pcs zk: group 11: <v, c> != combined claim`.

* Group 11 is the last of the 12 DD H groups, which is the value-0 sum claim. That is exactly where a broken count identity has to fail.
* The row total is preserved (128), so a row-total check alone would not have caught this.
* The frame decoded canonically, and the refusal comes from the native argument, not from routing. Test binary `29a8be1d…`, source `27b2a427…`.

### (b) The equivalent-row control verifies [MEASURED]

The log shows `alias=true from=0 to=31 E_from=0 E_to=0 P_from=0 P_to=0`, then `expected_accept:true`, then `1 passed`.

* `emit` verifies the frame in-process and only then writes those exact bytes (`split_attack_tests.rs:286–293`).
* This case uses the same selection as the original failing test (the first positive count, which is the E = 0 slot, moved to the last slot). It is therefore the recipe the coordinator asked to keep, re-creating the original accepted frame up to the OS-seeded masks.
* **But** its `statement.txt` records only the case and `expected_accept` (`:294`). The malicious branch records model, roots and binding (`:309`); this one does not. Without the input and output roots no fresh verifier can rebuild the transcript, so "the retained frame verifies" rests on the in-process check alone. This is **R14-F1**.

### (c) No move between distinct values can preserve the counts: proof

**Setup.**

* Let Q be the multiset of compressed queries.
* Let (t_i, m_i) be the table positions with their committed multiplicities.
* For a field value v, let c_v = #{q ∈ Q : q = v} and M_v = Σ_{i : t_i = v} m_i.

**Step 1: what acceptance implies.** Suppose the helper relations hold and the sum claim holds. Suppose also that α equals no query and no table value that has a free helper (the pole events below). Then:

  F(α) = Σ_{q∈Q} 1/(α − q) − Σ_i m_i/(α − t_i) = Σ_v (c_v − M_v)/(α − v) = 0.

**Step 2: the pole events are rare.** Every input to F(X) is fixed before α is drawn:

* Q and the t_i depend on A data and on β and γ;
* A, M and the m_i are absorbed before β, γ and α.

So F(X) is a fixed rational function. Its numerator has degree at most |{v}| − 1 ≤ N + T_d − 1. If any coefficient c_v − M_v is nonzero, then F ≢ 0, because partial fractions over distinct poles are unique. In that case α is a root of the numerator with probability at most (N + T_d − 1)/p².

* α at a query pole leaves no solution for h·0 = 1. The prover would have to discard the attempt; the code says "zero LogUp denominator; discard attempt" (`split_protocol.rs:22–25`).
* α at a table pole with m_i ≠ 0 also has no solution.
* α at a table pole with m_i = 0 frees that helper. This is the B2 event, at most T_d/p², and it is counted in §3.

**Step 3: the conclusion.** Except with that probability, the verifier accepts only if **c_v = M_v (mod p) for every distinct value v**. These are the "per-value counts". The verifier never sees them; it enforces them through α.

**Moving one count** from position a to position b turns M into M′:

* M′_{t_a} = M_{t_a} − 1 and M′_{t_b} = M_{t_b} + 1, if t_a ≠ t_b;
* M′ = M, if t_a = t_b.

**Distinct values.** If t_a ≠ t_b, then M′_{t_a} = c_{t_a} − 1 ≢ c_{t_a} (mod p), and the identity fails. The same holds for moving k units, because 0 < k ≤ N < p, and for any change of multiplicities that alters some per-value total.

**Distinct tuples.** "Distinct" here means distinct compressed values. Two distinct integer tuples compress to the same value only if a nonzero polynomial of degree at most 2 in (β, γ) vanishes. β and γ are drawn after the tuples are committed, so this is at most 2/p² per table tuple: the B1 term, 2·T_d/p², counted in §3.

**Equal values.** A move between positions of equal value (the alias) preserves every M_v. It also leaves Q, and so the statement, unchanged. The accepted receipt is therefore a second valid witness of a true statement, not a forgery.

**Consistency with the other tables.** For the byte, exp and ACT tables, equal-tuple moves *into padding* are rejected for a separate reason. SC_TAB's support term forces m = h = 0 beyond the support (`argument_accuracy.rs:425–433`), and the three `table-*-support` receipts are rejected at slot 25. The dictionary has no such term, by design: D30 condition 1 makes every padding slot a valid tuple whose multiplicity is never gated.

**The probe** (`r14/probe_dd_multiplicity_moves.py` / `.json`, exact arithmetic in the Goldilocks field) [COUNTED]:

* A causal 6-token toy with cap 16 and the native relation shapes: 96 slots, 36 queries.
* I tried every single-unit move from a nonzero slot to any other slot, 2,280 in all:
  * all 25 equal-tuple moves keep the identity;
  * none of the 2,255 distinct-tuple moves does;
  * no distinct tuples collided under compression.
* The two named cases reproduce the native outcomes: (512, 0, 0) → (512, 0, 0) holds, and (512, 512, 4096) → (512, 0, 0) fails.
* This illustrates the proof; it does not replace it.

## 3. Item 2: soundness bits [COUNTED]

**Method** (`r14/reviewer_bits_r14.py`):

* The domain sizes are read from `split_layout.rs`. D and F are true pieces: T·(2048 + 1024) and T·(8192 + 1024).
* The byte-lookup counts per position are the ones the R13 review verified on 144 census rows. `accuracy_layout.rs` is byte-identical in R14.
  * D 34, F 14, Q 14, Kv 14, L 2, S 11 + 2·ls (or 6 under DD), Dd 5 + 2·ls;
  * with ls = ⌈(log₂T + f_e)/8⌉ and f_e = 9 at all 26 actual layers.
* The group counts come from the 26 public manifests: 12 layers have G = 3 and 14 have G = 4.
* The slot list and its (main, ext, degree) are transcribed from `SplitLayout::new` and `BASE_DEGREE`, with the indicator degree removed for the true pieces.
* The column term follows D15's δ/3 rule for the zero-knowledge code.
* Sol's census was used **only as a cross-check**, and it matches on every count: byte queries, ACT queries, the 31 / 32 slot tuples and the sum of (main + ext)·degree.

### Per block, T128

| | N | of which byte / exp / ACT / DD queries | T_d |
|---|---:|---|---|
| non-DD | 48,660,480 | 46,956,544 / 524,288 / 1,179,648 / 0 | 512 + 4096·G |
| DD | 45,645,824 | 43,417,600 / 524,288 / 1,179,648 / 524,288 | 512 + 4096·G + 131,072 |

The ACT queries now cover T·9216 true lanes only (R13 counted T·16384). In total, 18.2 M of R13's 66.9 M lookup positions disappear.

### Whole run (26 blocks, union bound)

| Term | What it is | T128 non-DD | T128 DD |
|---|---|---:|---:|
| Lookup | Σ (N + 4·T_d − 1)/p²: B1 collision 2T_d, B2 pole \|PP\| + T_d, B3 identity \|V\| + T_d − 1 | 2^-97.762 | 2^-97.837 |
| Column checks | 79 regular openings (A and H ×26, 25 boundaries, 2 endpoints) × (1 − δ/3)^256 with δ = 1 − (n + 256)/(4n), n = 2^14; plus 26 M openings × (3/4)^256 | 2^-99.029 | 2^-99.029 |
| PCS field ceiling | Sol's retained 79·(erasure + 1 + 4096) + 26·(1025 + 4096), carried as is | 2^-107.3 | 2^-107.3 |
| Sumcheck rounds | 26 · Σ (main + ext)·degree = 26·1,365 / 26·1,437 | 2^-112.9 | 2^-112.8 |
| Zero-check, batching and output points | my allowance, 26 · Σ (3·(main + ext) + 3); Sol omits it | 2^-112.7 | 2^-112.7 |
| **Whole run** | | **97.2588** | **97.3118** |
| Sol's terms only | | 97.2589 | 97.3119 |
| R13 at the same geometry, same accounting | | 96.9209 | 96.9627 |

**T256** (counted only, n = 2^15, no native proof, same group counts):

* lookup 2^-96.48 / 2^-96.71;
* column 2^-99.29;
* **whole run 96.2871 / 96.4811**;
* R13 under the same accounting: 95.94 / 96.09.

**Against the floor.**

* **T128 clears D27's ~95 by 2.26 / 2.31 bits**, and the coordinator's ~96 by 1.26 / 1.31.
* T256 clears ~95 by 1.29 / 1.48, but ~96 by only 0.29 / 0.48.
* The R14 gain comes entirely from the lookup term: +0.46 / +0.48 bit. The joint boundaries keep the opening count at R13's 4L + 1 = 105, so the column term is unchanged. Two-piece boundaries would have cost 0.33 bit (`S4_DESIGN_CHECK.md` §7).

**Sensitivity.** If the carried PCS ceiling were 10× too small, the T128 figure would lose 0.013 bit; at 100×, 0.13 bit.

**Assumptions** (each one carried, none proved here):

* **A1.** BLAKE3 is a random oracle, in Fiat–Shamir and in the Merkle layer (D19), keyed per profile (D19a / D19b). The new profile names give new keys (`split_profile.rs:112–114`).
* **A2.** The figures are interactive union bounds. Under Fiat–Shamir they are per-attempt rates: grinding with 2^k work removes about k bits (D15's closing remark, D27's work-per-attempt reading). No hash-collision budget is assigned; it is about q²/2^257 for q queries.
* **A3.** The δ/3 proximity regime (Ligero lemma) with independent uniform column sampling. This is D15's convention, unchanged.
* **A4.** Nonzero residue: every count is below p (N ≤ 1.2·10^8). Multiplicities are free field elements and are committed before β, γ and α.
* **A5.** The masked-sumcheck (CFS) soundness lemma and the PCS field ceiling of 4096 are carried at their R13 level. Sol lists both as "pending transfer". The R14 masks use the same machinery with a per-physical-slot schedule (`argument.rs:509–532, 753–765`).
* **A6.** The union is taken over blocks (D15's reading). No first-cheating-block composition is used.
* **A7.** Only the backend is counted. The classifier and token stages (embedding, final norm, head, margin) and their composition are excluded. At R13 they cost about 0.06 bit (token round 16: 96.86 at T128).

## 4. Item 3: what changed since R13

### Classification

Line counts are of the new file, or of the changed lines.

| File | Kind | What it does | Legacy effect |
|---|---|---|---|
| `split_layout.rs` (233) | new, production | Piece inventory: D [2048, 1024], F [8192, 1024]. Slot list (31 / 32 slots); sequential, exclusive mask pairs; joint endpoint geometry 24 + 7 / 24 + 10 rows. Audit for dropped, duplicated or overlapping roles (`:171–193`). Refuses an H-bearing piece shorter than a row (`:89–91`) and a CFS message over 256 (`:151`) | none |
| `split_geometry.rs` (181) | new, production | Global-index gathers, source coordinates (`:46–56`), the single norm equality factor (`:60–64`), global matmul folds (`:69–89`), the zero lift (`:91–97`) | none |
| `split_profile.rs` (263) | new, production | Four new profile names and hash tags. The descriptor digest binds the full calibration, layout and schedule (`:117–215`); the joint geometry digest (`:84–111`) | none |
| `split_endpoint.rs` (470) | new, production | One joint commitment per endpoint or boundary: claim roles and pairs (`:73–93`), audit (`:149–163`), a consuming opening (`:195–206`), fresh OS-seeded randomness (`:209–217`) | none |
| `split_witness.rs` (189) | new, prover only | Repacks the unchanged R13 witness into true pieces. Histograms are rebuilt globally; a derived histogram from the caller is refused | none |
| `split_protocol.rs` (630) | new, production | Per-stage core: A → M → (β, γ, α) → H → slots → M / A / H openings (`:351–466` prove, `:468–602` verify) | none |
| `split_run.rs` (657) | new, production | Run plan and binding (`:24–196`), run transcript (`:236–251`), stage binding (`:252–263`), boundary absorbs (`:318–328`), root uniqueness (`:298–310`), streaming public blocks (`:330–360`), prove (`:362–496`), verify (`:498–637`) | none |
| `split_wire.rs` (374) | new, production | R14 frame codec. Every count comes from the trusted profile; header binds the run binding, profile digest, L, k and the start tag; exact length; trailer tag | none |
| `argument_split.rs` (589) | new, production | Piece builders: norm (`:237–272`), matmul (`:274–442`), IO (`:504–555`). Legacy-slot translation (`:446–502`), H sum claim (`:167–197`), dispatcher (`:557–589`) | none |
| `trained_split.rs` (773) | new, production (experimental CLI) | Requires `--experimental-r14`. Seals and checks parity before the header; 200-byte policy; fresh public-only verifier with canonical statement and consumed-byte manifest | legacy dispatch unchanged |
| `examples/zk60_split_stack.rs` (29) | new | Entry point only | none |
| `argument.rs` (133) | changed | (i) `run_slot` → `run_slot_scheduled` with a `SlotSchedule`. For legacy shapes the schedule is `sh.slots()` / `slot_terms` / `SLOT_KINDS`, value for value (`:509–543`). New refusals: n, ext or degree zero, n ≥ 64, a host index not below its own slot (`:553–556`); all are unreachable for legacy shapes. (ii) `B` gains an optional split view; with `None` every method takes its old branch (`:803–952`). (iii) `Points: Clone`. (iv) test-module declarations | byte-identical (goldens) |
| `argument_accuracy.rs` (29) | changed | `define_piece`; DZC and FZC take an optional view. With `None`: `cube` equals the old `sh.size(dom)`, `pad_on` is unchanged, and gamma is built over `sh.size(Dom::D)`, as before | byte-identical |
| `trained_block.rs` (38) | changed | **R13-F1 fix** (`:2002–2040`): the controls are built at the R13 shape with re-derived accuracy data, and must reach the receipt-binding refusal. Also `mod split_cli` and its `pub use` | the CLI controls now reach the receipt (11 / 0) |
| `private_block.rs` (13), `wire.rs` (3) | changed | Module declarations and exports | none |
| `run_capture.rs`, `split_capture.rs`, `source_audit.rs`, `s24_tests.rs`, `s25_tests.rs`, `split_*_tests.rs` | test-only | Capture observer, source pins, attacks, census | none |

**Legacy byte identity** [MEASURED by Sol, final source]:

* `final-validation-1/goldens.log` gives the 4 seeded digests and 5 statement identities. They are identical to my own R13 golden run (`r13/rv13-goldens.log`), 9 of 9 lines.
* The retained receipts verify under the final legacy CLI `260b66eb…`:
  * R8 TinyLlama `caf6ced2…`, R9 TinyLlama DD `d5721276…`, R8 8B `5585f5ee…` and R9 8B DD `4da580bd…`, the same identities as R13 §8;
  * the four R13 synthetic receipts, each with all 19 controls refused, the 11 calibration controls among them refused at the receipt (R13-F1 fixed);
  * both R12 Shieldstral receipts.

### Is every relation complete?

**D/F planes.**

* Each logical D or F plane has exactly two physical pieces that cover [0, 3072) and [0, 9216). Every other plane has exactly one (`split_layout.rs:179–182`).
* Each D piece is constrained by its own DZC piece over the piece's whole cube (`argument_accuracy.rs:39–85` under the view):
  * all 13 clauses: norm a and m with their remainder windows, the 8 widened words, both residuals, and the AO and down hosts;
  * every D lookup helper.
* The norm denominators D and D_m are T-planes shared by both pieces, and TZC hosts one norm sum taken over both pieces (`argument_split.rs:237–272`). So the norm is the full row, which the one-piece-norm attack confirms (§6).
* Each F piece carries all FZC clauses with the global group column. `accuracy_act::group_column` is cropped by the view to `group_ids[e.start + j]`.
* No pad lanes remain, so dropping the pad-zero terms removes no constraint (`argument.rs:935`; `argument_accuracy.rs:43, 92`).

**The other planes** (T, L, Q, Kv, S, Ht, Dd, Tab) go through the R13 definitions. Only the offsets and mask pairs are remapped (`argument_split.rs:446–502`):

* any whole slot that touched a D or F source would be refused, because there is no `Whole` piece for those planes;
* every host still hosts each private slot exactly once (`View::host`, `:123–139`), and a host comes after its hosted slots (`argument.rs:553–556`).

**Lookups.**

* Every query helper of every piece, the exp, ACT and DD helpers, the three table helpers and U all enter the single sum claim (`argument_split.rs:167–197`).
* The histograms are global (`split_witness.rs:92–146`).
* The table support terms are unchanged.

**What the honest prover computes and the verifier does not constrain:** nothing on a relation path.

* The unused tail of rows holding planes shorter than a row (T and Ht planes) is never read by any relation or claim. It cannot change what the receipt states.
* The external joint endpoint's spare row (row 28 of 31) is random and never claimed. That is a privacy matter, not soundness (N-r14-8).

### Fiat–Shamir order (binds before each challenge)

**Run start** (`split_run.rs:236–251`). The transcript absorbs, in this order: the binding, then the plan digest, model identity, context, block count, input root and output root. The plan digest covers every stage's descriptor and block digest and the scales.

**Each stage**, in order:

1. `begin_stage` absorbs the stage index, the stage descriptor and the block digest (`:252–263`).
2. The **outgoing boundary** is prepared and its index, spec digest, root, rows and log-cols are absorbed (`:408–416`). This is before any challenge of the stage, and so before the stage's IO_OUT τ and the next stage's IO_IN τ.
3. A (with rows and log-cols) is absorbed, then M, then β, γ and α are drawn, then H is absorbed (`split_protocol.rs:386–406`; verifier `:490–495`, the same order).
4. Each slot absorbs its index, then draws c, then absorbs the scalar, the rounds and the terminals (`argument.rs:586–740`).
5. The openings run their own challenges after all their claims are fixed.

**Each piece draws fresh** τ, μ, ν and output rj (`argument_split.rs:391`; `argument_accuracy.rs:44–46, 93–95`).

**Shared token points.**

* r_tf is shared by GMM and UMM wide / narrow, as in R13.
* The DMM token is shared by the two DMM pieces.
* The WO r_q is shared by the two WO pieces.

Each piece is a separate identity on its own output piece at (token, rj_i), with rj_i independent. So sharing a token adds only a union-bound term and allows no cancellation between pieces.

**What the frames carry.** The wire header carries the binding, the profile digest, L, k and the start tag, and is checked against the verifier's own (`split_wire.rs:168–200`). The end tag must equal the verifier's transcript position (`split_run.rs:616–618`). Both are routing checks layered on top of the transcript binding.

## 5. Item 4: split width, B-gate and boundaries

**B-gate (C-1, C-2).** Every monomial that contains a smaller piece has exactly one public factor, and that factor vanishes off the b = 0 half-cube:

* in matmuls, the zero-lifted global fold (`argument_split.rs:422–423`; `split_geometry.rs:91–97`, which refuses a nonzero tail);
* in norms, `Tab::Eq` at (r_t, 0^k) (`argument_split.rs:256–259`; `split_geometry.rs:60–64`).

The private tables stay broadcast over the omitted leading feature variables (`split_geometry.rs:46–56`). No σ enters a private functional, so neither the mask audit nor `open_zk` changes. Fixed token coordinates are never omitted.

The degree is decremented only where the indicator gate was removed: SS, SSM, DZC and FZC (`split_layout.rs:122–123`). `check_degree` (`split_definition_tests.rs:115–141`) confirms the declared degrees on all 126 physical slot definitions. A degree declared too low would only break completeness; soundness uses the true degree, which is within the declared one.

**Single rounding (C-4).** There is one host expression per output entry, over the full sum of both pieces. No partial accumulator exists. No-wrap is bounded by R13's padded count (pad lanes contributed 0), whose worst clause is 2^49.99.

**One opening per commitment (D12, D12a).**

* **Per stage,** A, H and M are each opened once (`split_protocol.rs:425–453`).
* **Each endpoint or boundary** is a `JointOwner` consumed by `into_opening(self)` (`split_endpoint.rs:195–206`). It is opened exactly once, at the stage that consumes it:
  * the input at stage 0;
  * boundary k + 1 at stage k + 1, with stage k's two IO_OUT claims followed by stage k + 1's two IO_IN claims;
  * the output at the last stage (`split_run.rs:449–464`).
* The verifier mirrors this with `pending.take()` (`:568–571, 596–623`), and `finish` refuses any leftover pending opening.
* The audit (`protocol.rs:240–284`, unchanged) requires each claim to carry exactly its own reserved pair, every pair used exactly once, and the proximity pair untouched. The group count must be 2 (external) or 4 (boundary) (`split_endpoint.rs:106–163`).
* Wire geometry forces a boundary root at stage k < L − 1 and an output opening only at k = L − 1 (`split_wire.rs:85–89`).

**Both pieces in one commitment (rule (b), C-7).** Pieces 0 and 1 sit at offsets [0, T·2048) and [T·2048, T·3072): 16 + 8 data rows at T128.

* Each IO claim names its own piece slice and pair: outgoing or external on pairs 0 and 1, incoming on pairs 2 and 3 (`split_endpoint.rs:73–93`).
* The claims equal A_X2 piece i of block k and A_X piece i of block k + 1 at fresh τ. Together that is the full true-lane equality.
* The spec digest binds the joint geometry, the context (plan digest), the kind and index, the scale, the offsets, logs, rows, sites and proximity row, and the PCS parameters (`:119–148`). The seed domain includes that digest.
* There is one shared scale per boundary (`split_run.rs:91–96`), and every stage must have the same joint geometry (`:101–107`).
* Repeated roots are refused across every role of the run (`:298–310, 552–556`).

**Fresh randomness.**

* Every Fiat–Shamir challenge is fresh as listed in §4. No challenge is reused for two independent purposes.
* The mask material comes from one run RNG for A, H and M, plus one OS-seeded RNG per joint commitment (`split_endpoint.rs:214`; `split_run.rs:391–393`). That is the same pattern as R13's `boundary.rs:396` and `endpoint_g.rs:269`.
* Prover randomness does not enter soundness.

## 6. Item 5: the evidence numbers

Everything here is [MEASURED by Sol, shared box, n = 1, `watchdog-only`]. I audited it from logs (`r14/audit_r14_evidence.py` / `.json`).

Of the 290 logs and records I read, 282 are in the frozen manifest and re-hash. The other 8 are the `final-arithmetic-1/` logs: five adopted non-DD malformed cases and two fixture prechecks, plus the first wrapper's group-reset log. The five adopted logs are pinned by sha256 inside `final-arithmetic-2/ACCEPTANCE.json`, which is in the manifest, and my audit matched them by that hash. The legacy-compat pair (N-r14-3) is the only evidence I used that is pinned nowhere in the packet.

| Claim | Log check | Result |
|---|---|---|
| 50 malformed relation receipts rejected | 50/50 logs: one test passed; `expected_accept:false`; native refusal, never "R14 wire" or "R14 run"; binary `29a8be1d…`; guard exit 0; bytes equal the JSON | **50 / 50.** 21 limb families × ±DD, 3 table-support families × ±DD, dictionary-unused, dictionary-counts. Refusals land at slots 18–25 and 31, or at H group 11 |
| 1 equivalent control accepted | `expected_accept:true`, test passed | **yes** (R14-F1) |
| 16 malformed arithmetic / C3 receipts rejected | records matched to logs by sha256 | **16 / 16.** Per-piece Q rounding, wrong omitted bit, missing lift gate, wrong feature axis and wrong global fold offset: slot 20. Local AO c2: slot 19. One-piece norm: slot 2. Local group reset: H group 10 / 11 |
| 4 honest group contexts verify | `global-group-honest`, `local-group-honest` × ±DD | **4.** The fixture's narrow channel 8192 differs between groups: 65536 against 67584 |
| 2 dense honest receipts and 19-site parity | `DENSE_REFERENCE.json` | **2 receipts verify, 0 differences.** But **z ≡ 0 and x2 = x1** (R14-F2) |
| Joint receipts | | **4 honest accept. 16 opened-row tampers fail at the keyed Merkle path. 2 foreign boundary roots fail at native sumcheck**, because the transcript diverges at slot 0 |
| Envelopes | | **2 honest accept, 16 refused.** Only 6 refusals are native ("repeated commitment root"); 10 come from the test harness (N-r14-1) |
| Suite, legacy compat | `sol-r14-legacy-full-suite-3.log` | **834 / 0 / 71 over 29 targets**, all ok. Source `86301542`, outside the manifest (N-r14-3) |
| Suite, final source | `final-validation-1/suite.log` | **838 / 0 / 75 over 29 targets**, all ok; 816 baseline outcomes kept |
| Full 26 layers, non-DD | `full26-native-1/non-dd-prove.log` | sealed 76.3 s ("bit-exact at every layer", 0 kept witness bytes); prove 350.7 s; **total 442.9 s**; VmHWM 5,721 MiB; 26 segments summing to **895,146,288 B**, equal to the JSON |
| Full 26 layers, DD | `dd-prove.log` | sealed 75.5 s; prove 345.0 s; **total 436.1 s**; 5,820 MiB; **901,256,496 B** |
| Fresh verifiers | `*-fresh.log` and guard | **85.1 s / 87.9 s**, 1.41 / 1.38 GiB. Verified with `statement_promoted:true`, and the identity and binding equal the prover's |
| Tamper | `*-scalar-corrupt.log` | first scalar + 1: rejected at slot 0, sumcheck round 0, exit 1, in both modes |
| 52 frame lengths | my recount from `split_wire.rs:56–72` | **52 / 52 equal.** Totals 895,146,288 / 901,256,496 |

Notes on reading these numbers:

* "443 / 436 s" is the whole `stack-prove` command. It includes about 76 s of loading, witness building and parity before the header. The proof alone is 351 / 345 s.
* These are not benchmarks: the box is shared, n = 1, with 8 threads.
* The narrow-boundary *value* forgery (refused at slot 30, the IO_OUT narrow piece) ran on source `57c204b6`. I diffed that tree against the final one. The production delta is root uniqueness, the input ≠ output refusal, streaming public blocks and `from_records`. None of it touches the IO relation or the transcript, so that evidence carries (N-r14-4).

## 7. Findings and notes

**R14-F1 (low; evidence).**

* `split_attack_tests.rs:289–295` writes the accepted equivalent-row control's frame with a `statement.txt` that lacks the model identity, input and output roots and binding. The malicious branch writes all of them (`:309`).
* The frame header carries the binding but not the roots, so the retained frame cannot be re-verified in a fresh process. Item 1(b) therefore rests on the in-process verification at emission.
* **Fix:** write the same fields in the accepted branch; re-emit the control (one guarded cpu job, about 12 s, 5.5 GiB); and add a fresh-process verify of the retained frame through the existing `fresh_verify` reader.

**R14-F2 (low; test).**

* The "generic fully dense true-support" fixture (`split_dense_tests.rs:13–40, 42–68`) uses ±1 weights, ±1 input and ±1 scores for the down path.
* Its 19-site reference (`final-arithmetic-2/DENSE_REFERENCE.json`) shows z in [0, 0], x2 identical to x1, h in [0, 118] and ao in [−6, 6].
* So no synthetic native gate exercises the DMM pieces and the DZC down host with live values, or words near ±32768. Only the real-model runs do: L25 on the reviewer's residual prefix, and the full 26 layers.
* The arithmetic itself is R13's, which my R13 generic fixtures covered, so this is the standing generic-witness rule.
* **Fix:** give the fixture down weights and multipliers that produce nonzero z of both signs. Optionally, add a per-piece rounding attack at the down or gate site, since today it exists only at Q.

**N-r14-1 (evidence classification).**

* 10 of the 16 envelope refusals come from the test harness, not from the native verifier:
  * the fixture exact-size reader, `split_run_tests.rs:247–255` ("not bounded regular exact-size input"): drop-root, drop-opening, stage-swap and stage-duplicate, ±DD;
  * the harness's own routing-binding check, `:299–301`: endpoint-swap-roots, ±DD.
* Only the 6 "repeated commitment root" refusals are native.
* The native code does enforce the same things, by reading: the wire's exact geometry, the stage index in the header and the start tag. Sol's scope sentence classifies them honestly.

**N-r14-2.** R13-F1 is **FIXED**. `trained_block.rs:2002–2040` builds the 11 controls at the R13 shape and requires the receipt-binding refusal. All four R13 CLI verifies print `receipt_refusals 11, door_refusals 0` and `controls refused 19, honest_still_verifies true`.

The printed 11 is a literal, not a tally. But the loop returns an error if any control is refused anywhere other than "this segment belongs to another run", so the line is printed only when all 11 reach the receipt.

**N-r14-3.** The prompt's 834 / 0 / 71 suite ran on predecessor source `86301542` and is not in the frozen manifest. The authoritative final-source run is 838 / 0 / 75 (`final-validation-1`, in the manifest); its 4 extra passes and 4 extra ignored tests are the tests added since. Both runs keep all 816 baseline passes.

**N-r14-4 (carry of earlier-source evidence).**

* The stream gates (`57c204b6`) and the actual L00 / L25 gates (`087016a3`, `3c7b1dcf`) ran on earlier sources.
* Since `8851fc0b`, `argument_split.rs` is byte-identical.
* Since `57c204b6`, the only changes in `split_protocol.rs`, `split_endpoint.rs`, `split_witness.rs` and `argument.rs` are `cfg(test)` hooks or test-module declarations. `split_run.rs` gained only the additions listed in §6.
* Since `06c540f2`, only test code changed, and the `trained_split.rs` production prefix is byte-identical (`FINAL_SOURCE_DELTA.json`).

**N-r14-5 (conditions before any registration or use).**

* (i) Bind a security tier and its whole-run figure into the run statement, with a verifier minimum, as D27 directs. R14 binds none.
* (ii) The token and classifier composition must recount N for R14's true pieces. A `block_logup_size` written for R13's padded domains over-counts, which is safe, but it is not R14's figure. It must also add its own stage terms.
* (iii) T256 has no native proof; prove and tamper-check it on the desktop before using it.
* (iv) S4 rule (e): the privacy gate (P-1..P-6) is still owed.

**N-r14-6.** The PCS field ceiling (4096 per opening) and the CFS lemma are carried, not derived, as Sol flags. §3 gives the sensitivity: at most about 0.13 bit, even at 100×.

**N-r14-7.** The T256 count assumes the T128 export's 12 / 14 split of 3 and 4 groups. Recount it on the T256 export's manifests.

**N-r14-8 (privacy pointers only, not reviewed).**

* The external joint endpoint's spare row is random and never claimed.
* A dictionary count can be placed on any slot of equal tuple value, and the honest prover chooses the first. That choice lives in A, under masks.
* Both belong to the privacy gate's rank / NL-1 pass.

**N-r14-9.** The fresh verifiers in the evidence were given `--expect-statement` and `--expect-binding` taken from the prover's log. The verifier rebuilds the model identity itself and requires the pins to match, so the pins are consistency checks. A relying party must take the binding from the input owner (D25 T5); this is a composition item.

## 8. What I did not check, and the heavy runs that would close it

**What I did not check:**

* **Privacy, entirely.** That covers the rank lemma, the CFS lemma, NL-1, the joint view, the captures and the spare-row disclosure.
* **The derivation of the PCS field ceiling and the CFS lemma.** Both are carried (A5).
* **That the packet binaries were built from the packet source.** I did not rebuild them; I relied on Sol's build records and tree pins.
* **Any native re-execution.** No relation battery, full-26 proof or fresh verify was re-run with my own binary.
* **The frames.** I did not re-hash the frame bytes, which are bulk data.
* **T256 natively.** No proof exists.
* **The classifier, token stages and whole-application composition.**
* **The capture observer** (`split_capture.rs`, test-only), except that it is `cfg(test)`.

**Heavy runs to schedule.** Each would be one guarded job, run serially. Peaks and wall times are taken from Sol's records.

1. **A reviewer build from a copy of `source-tree/`:** `cargo build --release --offline --locked` of the test binary and `--example zk60_split_stack`, class **build**, about 2.1 GiB, about 3 min. Then compare behaviour with Sol's binaries.
2. **A fresh verify of the retained full-26 non-DD and DD artifacts with the reviewer CLI:** class **cpu**, need 2.5 / cap 5 GiB, about 90 s each. Then the scalar-corrupt control, about 40 s each.
3. **The 51-case relation battery and the 16 arithmetic cases on the reviewer test binary:** class **cpu**, need 7.5 / cap 10 GiB, about 12–40 s each, serial.
4. **After R14-F1:** re-emit the equivalent-row control with its roots, then a fresh-process verify. Class **cpu**, 7.5 / 10 GiB, under 30 s.
5. **After R14-F2:** the dense fixture with nonzero z, ±DD. Class **cpu**, about 5.6 GiB, about 30 s each, plus the reference at about 0.6 GiB.

## Evidence

Everything below is under `results/zk60_d24_review_20261017/r14/`.

**Tree checks:**

* `tree_check.py`;
* `tree_check_r14.json` and `tree_check_r13.json`.

**The evidence manifest:** `check_evidence_manifest.py` / `.json` (1,595 small files re-hashed, manifest `2e8b76c2…` = freeze).

**The log audit:** `audit_r14_evidence.py` / `.json`.

**The bit and frame-length recount:** `reviewer_bits_r14.py` / `.json`.

**The item 1(c) probe:** `probe_dd_multiplicity_moves.py` / `.json`.

**Guard records:** `rv14-{bits,bits-2,evidence,manifest,ddprobe}.{log,done,guard.json}`.

No author, frozen or register file was edited. No git writes, no network access.
