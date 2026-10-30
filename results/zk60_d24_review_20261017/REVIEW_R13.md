# D24 review, round R13: the native accuracy stack (S2)

## Verdict

**R13 is ACCEPTED on soundness** at its twelve registered profiles: TinyLlama T128 LOW (with and without DD), Llama-3-8B T128 LOW + h24 (±DD), Shieldstral T128 and T256 LOW + h24 (±DD), and four T32 development rungs. **No soundness finding.**

One **low fix is recommended** for the next native revision. It is a test defect, does not touch any relation, and does not gate the token lane:

* **R13-F1:** 11 of the CLI's 19 "fresh-verifier controls" are vacuous at R13 profiles. They are refused by a door check before any receipt byte is read (§9).

In plain words, item by item:

* **Existing profiles are byte-identical:**
  * the seeded goldens on my R13 binary reproduce all 4 digests and 5 identities of my round-10 R12 run (9 / 9 lines identical; 52 s, 5.91 GiB);
  * four retained R8/R9 full stacks verify under my CLI with byte-checked statements;
  * the R8, R9, R12 and R12b freezes are unchanged.
* **The arithmetic is the spec.** My independent integer reference was written from the S2 spec and the coordinator notes, not from Sol's code. It equals the native witness:
  * on all 19 sites of my own **generic** fixtures (random int8 over [−127, 127], signed gains, scores over [−49, 44], an input row whose norm output is exactly −32768), with 0 differences;
  * on Sol's three fixtures;
  * on the actual Shieldstral layer 0 at T128;
  * on the actual layers 0 and 25 at T256, fed real residual rows, including the (0, −8) member: all 19 sites, 0 differences.
* **Domains and no-wrap.**
  * The 8 widened words admit exactly [−32768, 32767].
  * The score admits exactly [−127, 127].
  * Every remainder window is exact.
  * The worst clause is 2^49.99, 14 bits below p.
* **Group protocol.**
  * Group ids are public, and the verifier evaluates the group column itself.
  * The derived tables are recomputed by the verifier and are never read from the export.
  * Wrong-group, swapped-id, pad-position, fifth-group and prover-supplied-table attacks are all refused.
* **Shieldstral.**
  * The (0, −8) member is admitted only by the Shieldstral registry, at its pinned geometry.
  * The layer-25 W_up change is ordinary public layer data, bound by the digests.
  * The tied tables are still derived from the checkpoint.
* **Bits.** Every registered profile clears D27's ~95: the lowest is Shieldstral T256 non-DD at **96.09**.
  * **Flag (N-r13-1):** at the named D27 workload, Llama-3-8B T512, which R13 does not register, R13 would give **94.48 without DD / 94.80 with DD**. Both are below 95.00, and the non-DD figure is 0.25 bit under the 94.73 that D27 accepted.

**This is not a privacy review.**

## What was reviewed

* **The freeze:** `results/zk60_1b_native_20261017/r13/frozen-tree/`, tree `bb9eb212…`, 269 files.
  * My copy, `ops/zkp-mvp/trained-1b-review-r13-scratch/tree/`, equals the manifest file for file, and the tree hash recomputes (`r13/tree_check.py`).
  * The frozen tree itself re-hashes 269/269 with no extras, both before my runs and after all of them.
  * The R8, R9, R12 and R12b frozen trees re-hash against their manifests (220/222/225/229, all match).
* **The patch:** `r13-vs-r12b.patch`, 77,037 lines.
  * About 5,800 code lines; the rest are fixtures.
  * I read in full: the 12 new production modules (`accuracy.rs`, `accuracy_act`, `accuracy_aligned`, `accuracy_fold`, `accuracy_groups`, `accuracy_layout`, `accuracy_precision`, `accuracy_public`, `accuracy_tables`, `argument_accuracy.rs`, `trained_accuracy.rs`, `witness_accuracy.rs`), the profile and proof test modules, and every hunk in `argument.rs`, `protocol.rs`, `layout.rs`, `shape.rs`, `run.rs`, `trained_block.rs`, `trained_statement.rs`, `witness.rs`, `private_block.rs` and `tied_tables*`.
  * I compared the R13 slot polynomials with the legacy `SC_DZC` / `SC_FZC` / `SC_QZC` / `SC_SZC` / `SC_DD` / `SC_TAB` bodies clause by clause.
* **The coordinator's construction conditions were checked against the code:**
  * 19:11Z: no-wrap at the signed-31 derived class, and derived tables verifier-recomputed, never prover-supplied;
  * 19:50Z and 20:00:40Z: the widened domain at exactly the 8 sites, every dependency checked, scores and weights kept symmetric;
  * 21:14Z: (0, −8) only at Shieldstral; ≤ 4 groups per layer; the signed-32 class; no new committed plane; the L25 up fix as a public constant inside the existing relations.

  All hold (§§3–5).
* **My runs:** all guarded, detached and serial on a shared box, n = 1, with the kernel memory cap (`cgroup+watchdog`).
  * Only the goldens job declared ≥ 3 GiB (7.5). It launched after a check that no other job declaring ≥ 3 GiB was live.
  * One checkpoint stream was used (rv13-shield).
  * My review tests live only in my copy: `review_r13_tests.rs`, registered by one line in my `private_block.rs`.
* **My binaries:**
  * test binary `hashline-c24e3b74` (built once, then rebuilt with one more test; both hashes are in `binaries.sha256`);
  * CLI `zk60_trained_block` (`r13/binaries.sha256`).
  * Sol's are `cb5e004d…` / `899d7c01…`; the build paths differ.

## 1. Per-item table

Paths are under the frozen tree's `hashline/src/private_block/`.

| # | Item | Verdict | Where |
|---|---|---|---|
| 1 | Existing profiles byte-identical; new behaviour only behind new profiles | **PASS** | branch points `argument.rs:1182–1184, 1352–1361, 1493–1502`; `protocol.rs:586–589, 1071–1077, 1179–1183, 1235–1241`; `shape.rs:2135–2147, 2204–2212, 2243–2247`; `layout.rs:363–367, 1502–1503`; `trained_block.rs:891–898, 1249–1260, 1323–1329`; `trained_statement.rs:302–314, 895`; `run.rs:405–413, 879–888`; `private_block.rs:850–857, 875–880` |
| 2 | Arithmetic = spec (c2 multipliers, windows, norm int16, F_P 12, int16 attention, grouped int12 SiLU, h24/LOW, group scale before h rounding) | **PASS** | `accuracy_precision.rs:55–98`; `argument_accuracy.rs:59–68, 97–104, 133–139, 305, 382`; `accuracy_aligned.rs:19–52`; `accuracy_groups.rs:30–75`; `accuracy_fold.rs:16–53`; reference parity §2 |
| 3 | Domains and no-wrap (8 widened sites, score and weights symmetric, signed-31/-32 derived class, (0, −8)) | **PASS** | `argument_accuracy.rs:60–62, 98, 135`; `accuracy_layout.rs:109–170`; `accuracy_tables.rs:13–16, 27–36`; `private_block.rs:829–835`; `accuracy_fold.rs:45`; §3 |
| 4 | Group protocol: ids public and bound, no wrong-group routing, padding, Dom::Tab row width | **PASS** | `accuracy_act.rs:13–79`; `argument_accuracy.rs:85, 99–100, 397–425`; `accuracy_public.rs:179–243, 253–288`; §4 |
| 5 | Shieldstral: (0, −8) only there; L25 W_up public and digest-bound; tied tables still recomputed | **PASS** | `accuracy_tables.rs:13`; `accuracy_public.rs:32–40`; `shape.rs:202–216, 667–671`; `trained_block.rs:1240–1260`; `tied_tables*` (visibility only); §5 |
| 6 | Soundness bits | **PASS at every registered profile; FLAG at the unregistered 8B T512** | §6 |
| 7 | Attacks | **PASS:** Sol's 19 re-run; plus 15 alternative-remainder and pad witnesses, 3 group-swap witnesses, 6 cross-statement refusals, 9 door refusals, window and endpoint checks, and 22 calibration controls | §7 |
| 8 | Evidence hygiene: every acceptance stage ran real tests; suite 816/0/51 | **PASS WITH NOTES** (R13-F1, N-r13-3) | §8 |

## 2. Arithmetic against the spec (item 2)

**Precision derivation** (`accuracy_precision.rs:55–98`). From the base calibration:

| Site | Spec | Native |
|---|---|---|
| norm | tn − 8 | tn − 8 |
| q, k | sh_qkv + 8 − 6 + 5 | sh_qkv + 7 |
| v | sh_qkv + 8 − 6 + 6 | sh_qkv + 8 |
| score | sh_s + 12 | sh_s + 12 |
| PV | sh_o + 3 | sh_o + 3 |
| AO | sh_ao + 6 + 8 | sh_ao + 14 |
| gate | sh_g + 8 − 4 + 6 | sh_g + 10 (before the group fold) |
| up | sh_u + 8 + 4, with sh_u = 0 | 12 |
| h | sh_h − 8 at h24; sh_h at LOW | the same |
| down | sh_z + 6 (+ 8 at h24) | the same |

* Multiplier bits are q5 k5 v6 o8 g6 u4 d6. Each multiplier m must satisfy 1 ≤ m ≤ 2^b (`accuracy_public.rs:138`).
* F_P = 12. The norm, attention, gate and product word classes are 16, 16, 12 and 16/24 bits.
* Each derived shift must sit in its counted window, or the profile is refused (`:84–90`).

**Relations** (`argument_accuracy.rs`):

* **Norm.**
  * `2·Cn·γ·x + D·2^tn′ = 2^(tn′+1)·D·y + nr`, and `nr + ns + 1 = 2^(tn′+1)·D`, with nr and ns each three full bytes (`:59–60`).
  * So nr ∈ [0, 2^(tn′+1)·D), and y is the exact round(Cn·γ·x / (D·2^tn′)).
  * The 24-bit window is complete over the D24 class, because tn′ + 1 + bits(D_max) = (tn + 1 + bits(D_max)) − 8 ≤ 24.
* **Matmul hosts** (`:67–68, 103–104, 138–139` and the `fold` of `argument.rs:1352–1361, 1493–1502`). Each is `Σ W·m_j·x = 2^s·w + r − 2^(s−1)`.
  * The multipliers are folded at Boolean output channels into the public matrix (`accuracy_fold.rs:16–53`).
  * The Q axis uses the head-slot permutation. K, V, O, up and down use plain padded axes, exactly as the witness does (`witness_accuracy.rs:205–260, 389`).
* **Gate.**
  * Each channel's input step is folded into one common denominator: `c_j = m_j·2^(G − s_j)`, s_j = sh_g + 10 + e_in,j − e_in,base, G = max(s_j, 17) ≤ 24, c_j ≤ 2^14 (`accuracy_groups.rs:48–68`).
  * I checked `round(acc·c_j / 2^G) = round(acc·m_j / 2^s_j)` algebraically. Sol's vectors (`accuracy_groups.rs:84–106`) check it too.
* **Product.**
  * `a_scaled·u + 2^(R−1) = 2^R·h + rh`, with rh exactly R bits (R = 16 at h24, two bytes; R = 24 at LOW, three bytes) (`:97`).
  * `a_scaled = raw·2^(24 − sh_h + e_out,g − e_out,base)` (`accuracy_aligned.rs:37–46`). This is the single exact rounding of `a·u·2^δ / 2^H`: the group scale comes before h rounding, as the coordinator's 19:11 note requires.
* **Softmax / DD.** The legacy bodies are carried over with `sh.f_p()` (= 12) and `precision.score` substituted (`:305, 367, 382`). No legacy clause was dropped.

**Independent reference** [COUNTED]. Files are under `r13/`:

* **`reviewer_block_reference.py`** (pure Python, exact).
  * It equals Sol's T32 traces at 18 of 18 sites for both stacks.
  * That fixture is degenerate, though: s = 0 and ao = 0 everywhere.
* **`reviewer_export_reference.py`** (numpy int64, exact, reads an export layer). It reproduces the native output with 0 differences on:
  * `r13-h24-wide`: 12,288 words;
  * `r13-low-dense`: 12,288 words;
  * the actual Shieldstral smoke L00 at T128: 393,216 words (130 s, 1.03 GiB, guarded).

  Every export's ACT tables equal my SiLU generator.
* **My generic fixtures** (`rv13_make_fixtures.py`; outputs from my reference only).
  * The native witness dumped by `rv13_generic_witness_parity_prove_verify` equals my reference at **all 19 sites, 0 differences**, for both stacks (`compare_rv-generic-{h24,low}.json`).
  * Ranges covered: y [−32768, 26831], scores [−49, 44], h24 h [−995318, 724391], a_scaled up to 12,288,000, z [−4261, 2928].
* **Actual Shieldstral L00 and L25 at T256, on real residual rows** (Astra's `fidelity_smoke8_fix1`, rows 0..255: the embedding output for L00, the layer-24 output for L25).
  * The native witnesses (`rv13-shield`, after one authenticated checkpoint load) equal my reference at **all 19 sites, 0 differences** (`compare_shield_L00.json`, `compare_shield_L25.json`).
  * Scores reach [−58, 42] at L00 and [−45, 50] at L25. h24 h reaches ±445,028.
  * The L25 (0, −8) channels (1,078 of them) see gate inputs in [−1459, 602]. 385 of those words lie below −1024 (the range the coarse member was added for), and the member's minimum output, −71, is reached.

## 3. Domains and no-wrap (item 3)

**Widened words** (y, nm, q, k, v, qr, kr, o):

* Each is `w + 32768 = lo + 256·hi` with two plain byte lookups and no scaled pin (`argument_accuracy.rs:60–62, 135`; `accuracy_layout.rs:116–126`).
* So the admitted set is exactly [−32768, 32767]. My `rv13_native_lookup_windows` asserts this on the emitted lookup lists.
* **The coordinator's 19:50Z dependency list was checked:**
  * No relation negates a widened word. The RoPE sign sits in the public table (`argument.rs:1100`), and the rotation uses the coordinate flip.
  * The mask sentinel is a public −127.
  * DD keys are (Sum, e, P).
  * `Fp::from_i64` maps the endpoint without negation.
* **End to end:** my fixture row with y = −32768 proves and verifies at both stacks, with and without DD.
* **The rotation of −32768 at c = −128** gives +32768. It is refused at the rotated range: completeness only (N-r13-8).

**Symmetric classes:**

* The score has exactly the two lookups s + 127 and 127 − s. The admitted set is exactly [−127, 127] (`accuracy_layout.rs:160–161`; checked by my test). It is checked at every T × T position, masked ones included.
* Public weights and gains equal to −128 are refused at the trained door (`private_block.rs:829–835`) and again by `fold` (`accuracy_fold.rs:45`). My doctored exports `rv-w128` and `rv-gamma128` are refused by name.
* The other int16 words (x, x1, x2, ao, z, u) were already two's-complement in the legacy code. h is two's-complement int24 at h24.

**Remainder windows.** These are the emitted pins, evaluated by my test; each window is exact:

| Remainder | Window | Limbs |
|---|---|---|
| Rg | 2^G (2^20 here) | 3 |
| Ru | 2^12 | 2 |
| Rd | 2^20 at h24 / 2^12 at LOW | 3 / 2 |
| Rs | 2^18 | 3 |
| Rao | 2^21 | 3 |
| Rq, Rk | 2^15 | 2 |
| Rv | 2^16 | 2 (no pin needed) |
| Ro | 2^12 | 2 |

The h remainder is R full bytes, and P has 13 bits.

**No-wrap** [COUNTED]. My recount is `r13/reviewer_nowrap_r13.py` / `.json`. It covers every R13 clause, over the validators' class maxima (width, q and kv ≤ 4096; hidden ≤ 16384; Cn ≤ 2^20; tn′ ≤ 8; D < 2^24; folded gate ≤ 2^14; |a_scaled| ≤ 32767·2^16 at the Shieldstral registry and 32767·2^15 elsewhere) and also at the registered geometries.

* **Worst clause:** the h24 down host, **2^49.99**. That is 14.0 bits below p.
* **Other clauses:**
  * norm quotient 2^48.04 (class);
  * gate host 2^48.0;
  * product 2^46.0, including the signed-32 Shieldstral class with the (0, −8) member;
  * softmax / DD 2^37.6;
  * RoPE 2^23.6.
* Sol's `nowrap_counted.json` gives 2^51 (more conservative). It agrees in substance.

## 4. Group protocol (item 4)

**Query and table.**

* The ACT3 query is `(g + 2048) + β·a_scaled + β²·gid + γ·TAG_ACT` (`argument_accuracy.rs:99`):
  * g and a_scaled are committed in A before β, γ and α;
  * gid is a public column that the verifier builds from the bound public data (`accuracy_act.rs:33–41`; `argument_accuracy.rs:85`).
* The table holds 4096·G verifier-derived rows `i + β·T_g[i] + β²·g + γ·TAG_ACT` (`accuracy_act.rs:13–31`).

**Routing.**

* A channel can only reach group g′ ≠ gid if a degree-2 polynomial identity in β holds. That is B1 below.
* Gate words are range-checked by membership: gate ∈ [−2048, 2047].

**Derived tables.**

* `check_for_registry` (`accuracy_public.rs:253–288`) re-derives the precision, the folds and the scaled tables from the registry, the members, the multipliers and the group ids. It runs at every R13 slot definition, on both sides (`argument_accuracy.rs:15`).
* The raw tables must equal the registry generator (`:157–163`).
* `scaled_act`, `derived_act`, `folded_m_g` and `folded_m_d` in an export are refused (`trained_accuracy.rs:62–68`).
* The block digest binds the encoding: registry, stack, geometry, base, member, multipliers, groups, ids and raw tables (`private_block.rs:875–880`).

**Padding.**

* Padded query positions hold zero in every F plane, by the pad-zero rule. Their query is the genuine row (gate 0, output 0, group 0) = `compressed[2048]` (`accuracy_act.rs:19, 52–54`).
* Table positions from 4096·G up to the row width repeat that tuple. Their multiplicity and helper are forced to zero by the ACT-specific support indicator in `SC_TAB` (`argument_accuracy.rs:411–418`).
* `Dom::Tab` is the row width (2^14 or 2^15), and table size ≤ the row width is required (`accuracy_act.rs:15`).

**Lookup term.** I derived it from first principles, extending CHECK.md §3 to degree-2 tuples.

* **B1:** the first bad query collides with a table tuple. The difference is a nonzero polynomial of degree ≤ 2 in (β, γ): it is nonzero through the tag, or through the gid, value or index coordinate.
* **B2:** α lands at an equal-pair or zero-multiplicity pole.
* **B3:** the α identity, by Schwartz–Zippel in α. Multiplicities are free field values, but a bad query's residue is its count, which is below p.

With |V| + |PP| ≤ N, the term is **(N + 4·T_d − 1)/p² per block**, with T_d = 256 + 256 + 4096·G (+ |Dd| under DD).

* All A planes, multiplicities included, are committed before β, γ and α. H comes after α, and every helper enters exactly one relation and the single value-0 sum (legacy, unchanged).
* **Sol's proposal 2·(positions − 1)/p² is a valid upper bound** and about 1 bit looser. Its written argument covers the α identity but not the B2 events. The number covers them anyway, because 2(N + T) ≥ N + 4·T_d.

**Attacks** (§7): wrong-group, two-channel id swap on the witness side and on the statement side, an ACT pad-position witness, a fifth group, and doctored or derived tables.

## 5. Shieldstral specifics (item 5)

**The (0, −8) member.**

* `Registry::permits` admits it only for `Registry::Shieldstral` (`accuracy_tables.rs:13`).
* The registry is a profile fact (`shape.rs:202–216, 667–671`), not an export field.
* The Shieldstral registry requires the pinned geometry 3072 / 4096 / 1024 / 9216 (`accuracy_public.rs:32–40`).
* Its table is generated without saturation; a word out of range is an error (`accuracy_tables.rs:27–36`). Max 32,752, min −71.
* My `rv-std-08` (a rung export declaring (0, −8)) is refused: "registry members must be unique and in canonical order".

**Layer 25.**

* The export's L25 carries groups [(−3, −11), (−2, −11), (−1, −9), (0, −8)], with counts [1669, 1685, 4784, 1078].
* sh_h = 15 is a per-layer constant. It sits inside the class (13..16) of the existing relations; nothing new was added.
* The aligned coefficients are [128, 128, 512, 1024], so the (0, −8) exponent is 10. The signed-32 class holds: 2^31 · 2^15 = 2^46.
* The requantized W_up and m_u are ordinary layer arrays, bound by:
  * the array hashes in the layer manifest;
  * the manifest hash in `profile.json` (whose sha256 the statement binds);
  * the block digest.
* My reference on L25 with real residual rows shows no refusal, and its ACT tables equal my generator. **Native parity holds: 19 of 19 sites equal** (§2). It uses the requantized W_up, m_u, sh_h = 15, G = 19 and the aligned multipliers {128, 512, 1024}.

**No new committed plane.** The plane list does not depend on the registry (`shape.rs:2204–2212`). The census shows identical plane counts at 8B and Shieldstral.

**Tied tables.** The `tied_tables*` diff only changes visibility (`pub(crate)` for R-C2). `tied_of` is unchanged. The R13 profiles map to the legacy model and tensor pins (`trained_statement.rs:171, 593`), and Sol's test asserts this. My rv13-shield load authenticated the checkpoint and derived the tied tables in 16.6 s (the one stream), with no refusal.

## 6. Soundness bits [COUNTED] (item 6)

**Method.**

* `r13/reviewer_bits_r13.py`, written from the R13 shape and layout code.
* It reproduces all **144 rows** of Sol's `NATIVE_LAYOUT_CENSUS.json`: byte, exp, act and DD queries, and lookup positions.
* The table gives the lookup term (N + 4·T_d − 1)/p², at G = 4, as a union over the blocks (D15's reading, as in R12 and CHECK.md).
* The PCS and sumcheck terms are about 15 bits smaller and are not included.

| Profile (row width) | DD | N per block | Per block | Blocks | **Whole run** | Sol's 2(pos − 1) | Same geometry before R13 |
|---|---|---:|---:|---:|---:|---:|---:|
| TinyLlama T128 LOW (2^14) | no | 36,929,536 | 2^-102.86 | 22 | **98.40** | 97.40 | 98.67 |
| TinyLlama T128 LOW (2^14) | yes | 33,914,880 | 2^-102.96 | 22 | **98.50** | 97.52 | 98.80 |
| Llama-3-8B T128 h24 (2^14) | no | 66,879,488 | 2^-102.00 | 32 | **97.00** | 96.00 | 97.30 |
| Llama-3-8B T128 h24 (2^14) | yes | 63,864,832 | 2^-102.06 | 32 | **97.06** | 96.07 | 97.37 |
| Llama-3-8B T512 h24 (2^15; counted, **not registered**) | no | 384,892,928 | 2^-99.48 | 32 | **94.48** | 93.48 | 94.73 |
| Llama-3-8B T512 h24 (2^15; counted, **not registered**) | yes | 306,774,016 | 2^-99.80 | 32 | **94.80** | 93.80 | 95.12 |
| Shieldstral T128 h24 (2^14) | no | 66,879,488 | 2^-102.00 | 26 | **97.30** | 96.30 | 97.60 |
| Shieldstral T128 h24 (2^14) | yes | 63,864,832 | 2^-102.06 | 26 | **97.36** | 96.37 | 97.67 |
| Shieldstral T256 h24 (2^15) | no | 154,730,496 | 2^-100.79 | 26 | **96.09** | 95.09 | 96.37 |
| Shieldstral T256 h24 (2^15) | yes | 136,642,560 | 2^-100.96 | 26 | **96.26** | 95.27 | 96.57 |
| Dev rungs T32 (2^14) | either | 2.0 M | 2^-107.0 | 1 | 107.0 | 106.0 | — |

* **The cost of R13.** R13 adds about 19–23% lookups per block, which costs 0.25–0.32 bit per profile.
* **Every registered profile clears ~95**, with ≥ 1.09 bits of margin (Shieldstral T256 non-DD).
* **Llama-3-8B T512, D27's named workload, is not registered in R13.** Counted, it gives 94.48 / 94.80.
  * Both are below 95.00.
  * The non-DD figure is 0.25 bit under the 94.73 at which D27 accepted "about 95".
  * A verifier at `--min-bits 95` would refuse either one, since the floor is 94.
  * See N-r13-1.

## 7. Attacks (item 7)

Everything in this section is [MEASURED] on my binary and was refused by a fresh verifier unless the table says otherwise.

| Case | Where | Result |
|---|---|---|
| **Sol's 19** receipt-emitting attacks: 13 limb flips, DdUnused, DdCounts, 3 table-tail moves, self-consistent wrong group | `rv13-sol-attacks` | 19 / 19 receipts emitted and refused. Also: 4 dense receipts and the two-stage boundary G20 → G21 verify |
| Gate alternative `g−1, rg+2^G`, at a position where h is unchanged (ACT and product consistent) | `rv13-review` | refused at the H LogUp sum (H24 ±DD, LOW) |
| Up alternative `u−1, ru+2^12`, at a = 0 | `rv13-review` | refused at the H LogUp sum |
| Down alternative `z−1, rd+2^down`, with output x2−1 and endpoints rebuilt | `rv13-review` | refused at the H LogUp sum |
| Masked-score alternative `s−1, rs+2^18`, at j > t (softmax unchanged) | `rv13-review` | refused at the H LogUp sum |
| ACT pad position (t3, j773) set to a valid group-0 tuple (gate 1) | `rv13-review` | lookups all hit; refused by the F zero-check pad term (slot 18) |
| Two-channel group-id swap, witness side (61 F words differ) | `rv13-review` | refused (slot 18) |
| Two-channel group-id swap, statement side | `rv13-review` | the digest moves; each statement verifies only its own receipt; cross-verification refused both ways |
| Word at −32768 at a widened site (y), honest | `rv13-generic` | **accepted** at H24 and LOW, ±DD, as intended |
| Score at ±128; −128 public weight or gain | lookups / door | not admissible: exactly [−127, 127]; `rv-w128` and `rv-gamma128` refused by name |
| Prover-supplied derived table (`scaled_act`) | door | refused: "derived by the verifier, not supplied in the export" |
| Doctored raw ACT word (manifest rehashed) | door | refused: "not the declared generated member" |
| Fifth group | door | refused: `silu_groups` [5, 2] is not an admitted shape. `AccuracyPublic` and `table()` also refuse more than 4 |
| (0, −8) at a Standard profile | door | refused |
| m_g = 0; m_o = 257 | door | refused: narrow range |
| Legacy schema naming an R13 stack | door | refused by name |
| 11 calibration constants moved by one, rebuilt at the R13 shape (block data re-derived for the moved base) | `rv13-controls` | **22 / 22 refused at the receipt** (11 per stack): "this segment belongs to another run" |

## 8. Evidence hygiene (item 8)

Every stage was audited by `r13/audit_stages.py` → `audit_stages.json`. [MEASURED, from Sol's logs.]

* **All 41 guard records exit 0,** except the two tamper stages. Those expect exit 1 and are paired with PASS records: the verifier rejects with "Merkle path … fails".
* **Every test stage ran real tests.** The counts:
  * components: 77 passed / 8 ignored;
  * chain, group-attack, receipts, norm-attack, limb-attacks, tail-attacks and actual-import: 1 each. Each test runs several cases: 14 limb, 3 tail and 4 dense cases, all named in the logs;
  * goldens: 5;
  * the 9 coverage gates: 1 each, with named filters;
  * compat-r12-shield: 2;
  * **suite: 816 passed, 0 failed, 51 ignored, over 29 targets** (the library target alone: 671 / 0 / 51).
* `release-2-build` is a `--no-run` compile stage. At build time, Sol's `release-2.source.json` records the frozen tree `bb9eb212…` (269 files).
* Sol's guard records `watchdog-only` enforcement. Mine record `cgroup+watchdog`.
* **My re-runs** (on my binary and CLI):
  * Sol's attack set: 6 tests;
  * components: 77 / 0 / 8;
  * the 4 synthetic CLI receipts (copies) verify under my CLI, each with 19 / 19 controls refused;
  * the 4 retained R8/R9 TinyLlama / 8B stacks (±DD) verify with byte-checked statements:

    | Stack | Statement |
    |---|---|
    | TinyLlama R9 DD | `d5721276…` |
    | 8B R9 DD | `4da580bd…` |
    | TinyLlama R8 | `caf6ced2…` |
    | 8B R8 | `5585f5ee…` |

  * goldens: 5 / 0, with digests and identities equal to my R12 run, 9 / 9.
* **The R12 Shieldstral retained receipts** were not re-verified by me, because the single checkpoint stream went to R13. Sol's `compat-r12-shield` (2 passed) and the unchanged tied path cover them.
* **Notes:** R13-F1 (the vacuous controls) and N-r13-3 (the CLI hash labels), §9.

## 9. Findings and notes

**R13-F1 (low; a test and evidence defect, not soundness).**

* `trained_verify_command`'s 11 calibration controls (`trained_block.rs:1988–2016`: norm_tn, cn_a, cn_m, ceps, sh_ao, sh_qkv, sh_s, sh_o, sh_g, sh_h, sh_z) build the moved verifier statement with `ex.geometry.shape_at`, which is a **legacy** shape.
* At every R13 profile, all 11 are refused by `check_accuracy_gate` ("trained statement: legacy layer carries an R13 gate denominator") before any receipt byte is read. This happens in my four CLI runs and in Sol's.
* Of the "19 fresh-verifier controls", only 8 do what they claim at R13:
  * 6 reach the receipt: 4 segment controls, the export digest, and a γ word;
  * 2 are refused at doors that are legitimate for them: f_e, at the rung geometry's pin, and the layer index.
* **The property itself holds.** My `rv13_calibration_controls_reach_the_receipt` rebuilds each control at the R13 shape, with the block's R13 public data re-derived for the moved base. **All 11 reach the receipt and are refused at both stacks** ("this segment belongs to another run"; `rv13-controls.log`).
* **Fix:** build the controls through `ex.shape_for` / `Shape::accuracy_trained`, and re-derive `AccuracyPublic` for the moved base.

**N-r13-1 (accounting; for the security owner).**

* At Llama-3-8B T512, R13 counts 94.48 (non-DD) / 94.80 (DD) whole-run. That is below 95.00, and the non-DD figure is under D27's accepted 94.73.
* No R13 profile is registered there, so no receipt today is affected.
* Before registering 8B T512 on R13, one of these is needed:
  * a ruling that "about 95" covers 94.5;
  * DD plus a lever, such as LogUp-GKR with a 256-bit challenge or lookup repetition (D27's next milestone);
  * the per-block sequential-composition argument flagged in CHECK.md §7.

**N-r13-2 (accounting).** Use (N + 4·T_d − 1)/p² per block, with T_d = 512 + 4096·G (+ |Dd|), for R13 (§4). Sol's 2(positions − 1)/p² is sound but about 1 bit looser. Under it, Shieldstral T256 non-DD would read 95.09.

**N-r13-3 (evidence labels).**

* The four synthetic CLI receipts were proved and verified at 05:52Z by CLI `a7eb20bf…`. That CLI was built at 02:58Z from the release-1 source `41f38442…`, which differs from the frozen tree only in the test-only `accuracy_proof_tests.rs`.
* The report's CLI `899d7c01…` is the example that the full suite's `cargo test` rebuilt at about 05:58Z, under dev-dependency feature unification. It ran the actual L00 receipts.
* Both binaries come from functionally identical non-test source, and my CLI from the frozen tree verifies all four receipts.
* Record the binary that actually ran next to each receipt.

**N-r13-4 (generic witness).**

* Sol's synthetic fixtures have weights in [−2, 2], gain 64 everywhere and scores in [−4, 3]. The actual L00 proof's input lies in [−1, 1], so every score is 0.
* None of them exercises a weight near ±127, signed gains, wide exp-table deltas or a −32768 word.
* My `rv-generic-*` fixtures do, and they pass. Add a generic fixture to the acceptance gates (the standing rule).

**N-r13-5 (binding, defence in depth).**

* The R13 schedule line (`layout.rs:1503`) prints the base calibration, the precision struct and G. It drops f_e, wrho_s, D_max and the norm window, which the legacy trained line prints.
* They are bound through the trained statement's `IntegerCalibration` (`trained_statement.rs:294–316`) and the export digest, so there is no gap.
* Restore them for symmetry.

**N-r13-6 (capture format, for the privacy gate).** `OWN_SOURCE_FILES` grows from 20 to 32 entries, 4 of them **prepended** (`run_capture.rs:219–223`). Every existing own-pin moves by four positions in a bundle's `source_pins`. The gate's re-pin must read the new list.

**N-r13-7 (portability).**

* The verifier-recomputed SiLU tables use the platform's f64 `exp`, with floor and clamp (`accuracy_tables.rs:29–49`). The standard members were generated that way already.
* A libm that differs in the last ulp at some entry would refuse honest receipts. That failure is closed (no false accept), but it costs liveness.
* Consider pinning per-member table digests, using the existing `r13_vectors/silu_*.bin`.

**N-r13-8 (completeness).** RoPE at c = −128 maps a −32768 input to +32768, which is refused. Sol already documents this; it is a fidelity-lane matter.

**N-r13-9 (privacy bookkeeping, not reviewed).** Per block, the input-independent table inversions grow to 4096·G ACT rows, and the keyed DD terms keep D30(4). The D30 / D34 refusal-distance terms need the gate's recount, which Sol lists in `NATIVE_BOUND_REVIEW_PROPOSAL.json`.

## 10. What the token lane needs to register the Shieldstral classifier profile on R13

1. **Base.** Rebase onto R13 `bb9eb212…`.
   * Keep the `pub(crate)` tied-table visibility (`tied_tables.rs:15`).
   * The tied derivation and R12b's F1 conditions are unchanged.
   * N-r12b-1 still applies: every load streams the checkpoint.
2. **Profiles.**
   * Block profiles: `R13_SHIELD_T128_H24(_DD)` and `R13_SHIELD_T256_H24(_DD)`.
   * Run profiles: `RUN_PROFILE_R13_SHIELD_*`, from `run::accuracy_run_profile`.
   * Build run shapes with `RunShape::accuracy`.
   * The new classifier run profiles need their own ids (D17).
3. **Stage shapes must carry each layer's gate denominator.**
   * Use `LayerRecord::shape_at` and `RunStatement::stage_shape` (`trained_statement.rs:513–526`; `run.rs:623–628`). They apply `accuracy_gate_shift` from the bound record.
   * The token lane's own `stage_shape` (`frozen-r15/…/token_io/classify.rs:872`, `token_io/run.rs:253`) applies `stage_cal` only, and must be ported. Otherwise every R13 stage fails closed, because the public data's G differs from G = 17.
   * The classifier statement must carry `accuracy-gate-layer` per layer, as the trained statement does.
4. **Check blocks per stage.** Check every block against its own stage shape before the header (`fit_the_stages`, `run.rs:879–888`). Do not use `blocks_fit_the_shape` with the run seed.
5. **Export.**
   * Schema `zk60-trained-profile-export/2`, `accuracy_stack` `low-h24-v1`, geometry `shieldstral-3b-t128` or `-t256`.
   * Per layer: `m_q…m_d`, `silu_groups` (1–4 canonical rows), `silu_group_ids` (every group used), and the raw `act` tables, which the verifier regenerates.
   * **Never** supply scaled, derived or folded arrays.
   * L25's requantized W_up / m_u and sh_h 15 are ordinary layer data.
6. **Whole-run floor.** `block_logup_size` (`token_io/run.rs:107–111`) must, at R13:
   * add the |S| DD tuple queries and charge the |Dd| DD table under DD;
   * charge the ACT3 table as 4096·G rows;
   * use the degree-2 factor: num += N + 4·(512 + 4096·G + |Dd|) − 1.

   `sh.lookups_per_position` already returns the R13 counts at an R13 shape. This change moves the figure by ≤ 0.03 bit. The lookup terms to expect, before the PCS and token-stage terms are added, are 97.30 / 97.36 (T128) and 96.09 / 96.26 (T256), so `--min-bits 95` passes. Keep the D27 floor at 95. An 8B T512 classifier would not pass (N-r13-1).
7. **Owed items.** The token review's own items (its N-r13-1 / N-r13-2: library-level binding, and a test that fails without the post-derivation check) are tracked separately. The register says token rounds 14 and 15 address them; their review is the token reviewer's.
8. **Privacy.** The privacy gate re-captures on R13 (N-r13-6, N-r13-9). No privacy acceptance follows from this review.

## Evidence

Everything below is under `results/zk60_d24_review_20261017/r13/` unless a path says otherwise.

**Tree checks and Sol's evidence:**

* `tree_check.py`;
* `audit_stages.py` / `.json`.

**References, written from the spec:**

* `reviewer_block_reference.py` / `reviewer_block_reference_t32.json`;
* `reviewer_export_reference.py` and `ref_*.json` (+ `.npz`);
* `compare_native_dump.py` and `compare_*.json`.

**Generic and doctored fixtures:**

* `rv13_make_fixtures.py` / `rv13_fixtures.json`;
* the fixtures themselves: `ops/zkp-mvp/trained-1b-review-r13-scratch/loader-fixtures-rv/`.

**Counts:**

* `reviewer_bits_r13.py` / `.json` (the 144-row census check);
* `reviewer_nowrap_r13.py` / `.json`.

**Queue:**

* `r13_queue.sh` and `queue.out`;
* the guarded logs `rv13-*.{log,guard.json,done}`;
* `binaries.sha256`.

**Tests:**

* `ops/zkp-mvp/trained-1b-review-r13-scratch/tree/hashline/src/private_block/review_r13_tests.rs` (my scratch copy only);
* the native dumps `*.native.tsv`.
