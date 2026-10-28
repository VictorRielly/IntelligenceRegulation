# D24 review, round 10: the native R12 tree (Shieldstral-1.0-3B features on R9)

## Verdict

**R12 is ACCEPTED WITH FIXES on soundness.** This covers the four Shieldstral profiles (T128 and T256, each with and without DD) and the decoupled-head development rung.

What is sound:

* the relations of the 26 text blocks;
* the decoupled head_dim wiring;
* the YaRN tables;
* the padding.

The existing profiles are byte-identical to R9.

**Three findings, to fix before anything relies on what they cover:**

| Finding | Severity | In short |
|---|---|---|
| **R12-F1** | medium | The tied-embedding record checks that the export *declares* both tables come from the pinned tensor. It does not check that they *are* derived from it, and does not even check their size. |
| **R12-F2** | low, liveness / DoS | The token-table hashing follows symbolic links and reads without a bound. |
| **R12-F3** | low | `--rope-from-export` proves the export's RoPE tables while the statement records the pinned YaRN transform. |

F1 and F2 do not touch the block relations, because the embedding and head are outside the block proof (D13). They matter as soon as the token stages read the tied record. F3 needs an explicit opt-in on both sides.

**This is not a privacy review.**

## What was reviewed

* The native R12 freeze, `results/zk60_1b_native_20261017/r12/frozen-tree/`.
  * Tree 1e406781f734e9f35f066516a35bf6b9ef97dee164ece4f43bbe7b3e00735fc7, 225 files.
  * My copy is `ops/zkp-mvp/trained-1b-review-r12/`. Its `.sha256` equals the manifest, and the tree hash recomputes.
  * The copy is unchanged at the end of the round.
* `r9-vs-r12.patch`: 2,771 lines over 21 files, the same body as the author's.
* The R8 (7f64276a) and R9 (af90c703) freezes re-hash to their manifests.
* Sol's acceptance evidence, `results/zk60_sol_20261026/`, was read but not relied on. Everything below is my own reading or my own runs.

All runs were guarded, detached and serial, on a shared box, n = 1, and launched after the D42 guard swap (19:09 UTC). My R12 CLI, built from the pristine copy, has sha256 edc61ad8….

## 1. Diff R9 → R12: the existing profiles are unchanged

**Code.** Every R12 edit to a production path is one of four kinds:

* **Gated on a new profile:** `SHIELDSTRAL_PROFILES`, `TRAINED_HD_RUNG_PROFILE`, `Geometry::Shieldstral*`, `RungHdDev`, and the new run profiles.
* **The query axis given its own name**, which equals the model axis wherever `q_heads·head_dim == width`:
  * `Shape::q_pad()` / `q_width()`;
  * the `Wq` / `Wo` folds (argument.rs:1331–1347);
  * `SC_WO`'s fold length (shape.rs:2276–2279);
  * the `Dom::Q` stride (pad.rs:94, 174; witness.rs:278);
  * `Axis::Q` and `check_words` (private_block.rs:421, 574–586).
* **Optional statement fields present only on Shieldstral profiles:**
  * the rope-scaling field, present only when the transform is not none (trained_statement.rs:844);
  * the tied fields, present only for a tied model (trained_statement.rs:800).
* **The frozen generator itself** for every unscaled profile (rope.rs `rope_tables`).

R12 also removes one refusal, `d_pad != h_pad * head_dim` (shape.rs:724–729). Every shape that passed it has `q_pad == d_pad`; see N-1.

**Runs** [MEASURED]:

* **Seeded goldens on my R12 build.** All four match:
  * TinyLlama T128 782b64c9…;
  * 8B T128 05a22d72…;
  * TinyLlama T128 DD e50e71f8…;
  * 8B T128 DD 9c2572a3….
  * The five synthetic statement identities also match.
* **The same file in record mode on my own copy of the R9 freeze** (`r12-scratch/r9-golden/`, which is R9 plus that file) prints the **same four digests and five identities**. This reproduces the R9 side independently.
* **Retained receipts under my R12 CLI** all verify, with their published statements byte-checked (read only):
  * TinyLlama T128 DD d5721276…;
  * 8B T128 DD 4da580bd…;
  * R8 TinyLlama T128 caf6ced2…;
  * R8 8B T128 5585f5ee…;
  * TinyLlama T32 9b71dfb0….
* **My test A.** 15 existing shapes keep `q_pad == d_pad`, `q_width == width`, the frozen RoPE generator, no transform and no tie.
* **`--dd` at 8B T32** is still refused by name, and no output directory is created.

**Answer: no relation, transcript order, statement field or verifier check changes for the existing profiles.**

## 2. The new profiles: geometry and RoPE are the profile's, not the prover's

**Widths and head count.** The geometry is a fixed registry entry (shape.rs:482–485, 519–522): width 3072, hidden 9216, 32 heads of 128 over 8 KV heads, row width 2^14 / 2^15.

Every CLI path builds a `RunShape`. Its CS-7 check compares every field with the registry (run.rs:169–180). My test G edited `head_dim`, `q_heads`, `h_pad`, `kv_heads`, `width`, `hidden` and `d_pad` on all four profiles, and CS-7 refused all **28** edits.

Two further checks bind the widths:

* The loader expects `wq` [4096, 3072], `wo` [3072, 4096] and `wk` / `wv` [1024, 3072] before reading (trained_block.rs:1201–1229).
* `check_words` binds `wq` and `wo` lengths to q·d, the RoPE length to T·64, and the off-support entries to zero.

**The RoPE tables are public constants that the verifier recomputes.**

* The export must declare a transform equal to the profile's pin (trained_block.rs:1022–1025).
* `check_self` requires the statement's transform bytes to equal the pin (trained_statement.rs:368–373).
* The loader computes the tables itself with `rope_tables_for` and refuses export tables that differ (trained_block.rs:1255–1278).
  * The one exception is the `--rope-from-export` opt-in; see F3.
* An attention factor other than 1 is refused by name. This excludes 4.48.1's default of 1.277.

**My independent YaRN check** (`r12/r12_yarn_check.py`). I wrote my own binary64 transcription of transformers main `_compute_yarn_parameters`:

* Its inverse frequencies differ from the **installed transformers 5.13.1** output by a maximum relative 1.39e-7. Against **4.48.1's shipped default** (correction range at max_position 262,144) the difference is 11.47.
* Its integer tables (2^7) are:
  * T128 544dd35e…;
  * T256 bb5397c6…;
  * T512 261b32b8…;
  * T2048 5e370a8c….
* The Rust tables equal these at all four lengths, and at the four profiles (test B).
* These near misses each give a different table: no truncation, 4.48.1's correction range, factor 8, and unscaled. Each moves 6,501 / 19,601 / 12,034 / 22,650 of the 65,536 T512 entries.
* The door refuses declarations of truncate false, original 262144, or `default`.
* An absent declaration at a Shieldstral export is not the pin, so it is refused.

**Dense proofs at full shape.** On my build, a generic dense Shieldstral T128 block proves and verifies, both DD (29,536,904 B) and non-DD (29,301,896 B):

* the witness equals the independent kernel;
* the heads differ;
* a flipped segment is rejected.

That run took 256 s with a peak of 6.5 GiB. Sol's two saved dense receipts also verify in a fresh process, and their modified copies are rejected.

## 3. Tied embedding: the record binds declarations, not the tensor (R12-F1)

**What the code checks** (`tied_of`, trained_block.rs:536–585; `TrainedModelStatement::check_self`, trained_statement.rs:758–775):

* profile.json's `tied_embeddings` names `language_model.model.embed_tokens.weight` with sha256 67a138c1…, compared as a string against the pin;
* `token_io.json`'s `embedding_table.source_tensor` and `head_manifest.json`'s `source_tensor` carry that same (name, digest) string;
* the three files `embedding_int16.bin`, `head_int8_perrow.bin` and `head_mult12.bin` hash to their manifests.

The statement then binds the tensor pin and the three file digests.

**What it does not check.**

* **Derivation.** Nothing reads the tensor (the 805,306,368-byte BF16 range of model.safetensors), and nothing checks that either integer table is a quantisation of it.
* **Shape or dtype.** Nothing checks those of the tables either.

So the two sides of the tie can be swapped independently.

**Failure scenario** (my test D):

* The loader accepts 7-, 5- and 3-byte files as the embedding table, head table and multipliers.
* A head table swapped for different bytes, with its manifest digest updated, loads too. Only the record's head digest changes; the tensor pin stays 67a138c1….
* In practice, an export writer could ship a head whose yes/no rows always favour "safe", declare it derived from the tied tensor, and the statement would carry the authoritative-looking tensor pin beside the doctored digest.
* The Shieldstral stack scope already says that "the token stages bind the tied embedding / head by the statement's digests". Those are digests of whatever files the export carries.

**The fix**, one of these, before any token stage or statement relies on the tie:

* **(a) Verifier-side recomputation:** when the pinned checkpoint is available, recompute both integer tables from the pinned tensor bytes with the calibration's public quantisation rule, and require equal digests.
* **(b) Pinned table digests:** pin the expected integer-table digests per calibration in what a relying party approves, as is done for the tensor. Refuse anything else by name.

**Plus, either way:**

* check dtype and shape (131072 × 3072) before hashing;
* reword the scope sentence.

## 4. Lookup term [COUNTED] and refusal distances at Shieldstral (my test F)

**How the lookup term is counted.**

* N is the byte lookups over every padded domain position, taken from the **built** lookup lists and cross-checked against the shape's counter.
* Plus |S| exp pairs and |F| activation pairs.
* Plus |S| tuple queries under DD.
* Per block, the term is (N + 2303 + 4·T_DD)/p². Per 26-block run it is the union over the blocks.

**How the refusal distance is counted** (a privacy residual, not soundness). It combines D34 and D30 (4):

* D34 (token stages): 2·(768·L + T + 256)/p², with T prompt rows in and 256 byte values out as an upper bound;
* D30 (4) (DD only): + 2·L·rows·cap/p².

| T (row width) | DD | N | T_DD | per block | per 26-block run | bits | refusal distance |
|---|---|---|---|---|---|---|---|
| 128 (2^14) | no | 54,558,720 | — | 2^-102.30 | 2^-97.60 | 97.60 | 2^-112.69 |
| 128 (2^14) | yes | 51,544,064 | 131,072 | 2^-102.37 | 2^-97.67 | 97.67 | 2^-105.29 |
| 256 (2^15) | no | 127,991,808 | — | 2^-101.07 | 2^-96.37 | 96.37 | 2^-112.68 |
| 256 (2^15) | yes | 109,903,872 | 262,144 | 2^-101.27 | 2^-96.57 | 96.57 | 2^-104.30 |
| 512 (2^15, counted only, not registered) | no | 323,026,944 | — | 2^-99.73 | 2^-95.03 | 95.03 | 2^-112.66 |
| 512 (2^15, counted only, not registered) | yes | 244,908,032 | 524,288 | 2^-100.12 | 2^-95.42 | 95.42 | 2^-103.30 |

The padded Shieldstral geometry is the 8B geometry, so these N values equal 8B's at the same T: CHECK_LOGUP gives 323,026,944 and dd_check gives 244,908,032 at T512.

**Every registered Shieldstral run clears D27's ~95-bit MVP floor with margin** (96.4–97.7 bits). T512 sits at the floor: 95.03 bits without DD and 95.42 with it (N-2).

**The token stages are not counted here.** The embedding lookup and the D38 two-row threshold are not in R12. They add their own small lookup terms, and they need a recount when built.

**No wrap** (my `r12/reviewer_nowrap_r12.py`, over the whole calibration class). The worst clause is 2^43.08, against p/2 = 2^63. The R12-specific clauses are:

* Wo's host, which now folds over q_pad: 2^26.16;
* the PV host at T256 / T512: 2^25.31 / 2^26.16;
* the DD division over the f_e class: 2^35.0.

## 5. Padding (d 3072 → 4096, FFN 9216 → 16384): no unconstrained pad lane

**Every value plane of a padded domain is zero-ruled.** On D and F, every A plane carries the zero rule; on S only A_E is exempt, and S is unpadded here (pad.rs:294–308). The rule is enforced by the pad term of the domain's own zero-check, and the clauses are gated by the support indicator.

**The indicators are exactly the true lanes** (my test H, built from the widths alone):

* Shieldstral supp_D is 3072 of 4096 lanes, as the closed form 1 − b10·b11;
* supp_F is 9216 of 16384, as the explicit table;
* supp_Q has every lane true;
* at rung-HD, 192 of 256 and 384 of 512.

**The padded weight rows and columns are zero** by `pad_matrix` and `weights_vanish_off_support`. γ is zero on the padded lanes, so both norms sum squares over the true 3072 lanes only.

**My test E** (rung-HD, where the query axis 512 ≠ the model axis 256). Each attack sets ONE padded lane that nothing downstream reads, and keeps every lookup hitting. The verifier rejected all three:

| Attack | Rejected at |
|---|---|
| norm_a output Y = 5 at a padded model lane | slot 14 (D zero-check, pad term) |
| FFN product H16 = 1 at a padded hidden lane | slot 18 (F zero-check) |
| block output X2 = 3 at a padded model lane | slot 14 |

**The query and token axes do not pad at Shieldstral.** There are 32 of 32 heads, and T is a power of two. DD's unpadded geometry check passes at T128 and T256.

## Findings

* **R12-F1 (medium; the tie binding)** — section 3.
  * Where: trained_block.rs:536–585, trained_statement.rs:546–560 and 758–775, and the stack scope sentence.
  * Scenario and fix: as given in section 3.
* **R12-F2 (low; liveness / DoS)** — `sha256_file`, trained_block.rs:589–603 (called at :580).
  * It opens through symbolic links and reads until EOF with no bound.
  * A table in `token_io/` that is a FIFO, or a link to `/dev/zero`, blocks `TrainedExport::load` forever, for every Shieldstral verify, stack-verify and prove.
  * My test D2: a link to a file outside `token_io/` is followed, and a FIFO blocked the loader for 2 s until the test released it.
  * The block arrays have had bounded, pre-checked reads since R5b (r4_A), and the segments since r3_6.
  * Fix: before reading, use `symlink_metadata` to require a regular file whose length equals the manifest's declared dtype × shape. Then read with that bound.
* **R12-F3 (low; what the statement records)** — trained_block.rs:1273–1274 and trained_statement.rs:368–373.
  * With `--rope-from-export` on both sides, the export's tables are proven whenever they differ from the generator. The statement still records the pinned base and transform: at Shieldstral, "yarn(16, 16384, …)".
  * The real tables enter only through the opaque block digests.
  * My test C, at the rung-TC export: one entry off, accepted under the opt-in, and the statement still records base 10000 and transform none.
  * Scenario: a Shieldstral export carrying 4.48.1-default tables (19,601 of 65,536 T512 entries differ) is proved and verified with the flag. The record says YaRN as pinned.
  * This has existed since R2 for the base; R12's transform field makes the record look more authoritative.
  * Fix: refuse `--rope-from-export` at every profile that pins a transform. Alternatively, bind "export tables" plus their digest in the statement and make `check_self` refuse it at pinned profiles.

## Notes

* **N-1 — geometry binding rests on CS-7.** With the `d_pad == h_pad·head_dim` refusal gone, CS-8's rebuild (`Shape::check_constructed`, shape.rs:1701) uses the shape's own fields. A consistently edited geometry is therefore caught by CS-7, which compares every field with the registry, and not by CS-8. Every production entry point goes through a run, so CS-7 applies (test G: 28 of 28 refused). Any future block-level entry point must also compare with the registry.
* **N-2 — T512 is at the floor.** T512 is counted only. Its non-DD whole-run lookup term of 2^-95.03 is 0.03 bit above D27's ~95. Registering T512 without DD would sit at the floor; DD gives 95.42.
* **N-3 — float32 versus binary64.** The proven tables use the binary64 formula. transformers' float32 frequencies move 1 / 1 / 2 / 42 entries at T128 / T256 / T512 / T2048 by one unit at 2^-7. This is a fidelity matter for the calibration lane, not soundness.
* **N-4 — `llama_4_scaling_beta`.** `rope_scaling_of` ignores this key (0.1). Its query scale, 1 + β·ln(1 + ⌊pos/16384⌋), is exactly 1 below position 16384, so it has no effect at T ≤ 512. A profile beyond 16384 must model it.
* **N-5 — where q_pad ≠ d_pad is exercised.** At Shieldstral the padded query and model widths coincide (4096), and only the true widths differ. q_pad ≠ d_pad is exercised only at rung-HD: by the native proof and parity, and by my pad attacks.
* **N-6 — the refusal distances are not soundness.** These are privacy residuals (D34, D30 (4)), recounted in section 4. They are tiny against the statement's other terms (~2^-70). The token-stage design for D38 is not built yet.
* **N-7 — a test writes to /tmp.** Sol's `f3_the_loader_reads_a_tied_export` writes under `std::env::temp_dir()`, which is `/tmp`, and removes it at the end. That is minor, but against the evidence rule.

## Evidence

Everything below is under `results/zk60_d24_review_20261017/r12/` unless a path says otherwise.

**Queue:** `r12_queue.sh`. `r12_queue_a.sh` is a first launch, stopped before any guard for the D42 window.

**CLI build and retained receipts:**

* `r12-cli-build`, `binaries.sha256` (mine edc61ad8…, author fb4219ec…; the build paths differ);
* `r12-compat-{tl-dd,8b-dd,tl,8b,tl-t32}`: all verified, statements byte-checked;
* `r12-dd-probe.log`: refused by name.

**Scratch test build and tests:**

* `r12-test-build`;
* `r12-review`: my 9 tests (A–H, D2) pass;
* `r12-author-subset`: 98 passed, 0 failed, 5 ignored. These are r12, r9, the trained stack and block tests, r6, r8, s24, s25, s33, pad and cs_port, on my binary;
* `r12-saved-receipts`: 2 of 2;
* `r12-golden`: 5 of 5;
* `r12-dense`: 2 of 2, 256 s, peak 6.5 GiB.

**R9 side of the goldens:** `r9-golden-build`, `r9-golden-run` (same digests and identities).

**Python checks:**

* `r12_yarn_check.py` / `.json`: the independent YaRN check;
* `reviewer_nowrap_r12.py` / `.json`: no wrap.

**My test module** (scratch only): `ops/zkp-mvp/trained-1b-review-r12-scratch/hashline/src/private_block/review_r12_tests.rs`.
