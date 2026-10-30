# D24 review, round 11: short fix check of the native R12b tree

## Verdict

**R12b is ACCEPTED on soundness for the fix scope** (R12-F1, R12-F2, R12-F3, N-7). No fix is required before the token lane (R-C2) rebases onto it.

* **R12-F1:** the tied embedding, head and multiplier tables are now recomputed from the authenticated checkpoint and required to be equal. Every forgery I tried is refused, including forgeries whose manifest digests were updated to match.
* **R12-F2:** token-table hashing is bounded and refuses symbolic links, FIFOs and devices.
* **R12-F3:** `--rope-from-export` is refused at every profile that pins a RoPE transform.
* **N-7:** the named test no longer writes to `/tmp`.
* **Existing profiles:** byte-identical to R12/R9.
* **New issues:** nothing in the diff weakens soundness. Seven low notes follow; none is a soundness finding.

The coordinator's three conditions on the quantizer contract (21:35Z) hold at the native level:

* **(a)** Nothing native reads the yes/no ids or the margin scale from a file. Binding them to the registered policy is the R-C2 caller's job (§5).
* **(b)** `token_io_parameters` sits inside the profile digest the statement binds, and the Shieldstral loader also validates it.
* **(c)** A margin with |m| > 32767 is refused, never clamped.

**This is not a privacy review.**

## What was reviewed

* **The freeze:** `results/zk60_1b_native_20261017/r12b/frozen-tree/`, tree `51de5b83…`, 229 files.
  * My copy, `ops/zkp-mvp/trained-1b-review-r12b-scratch/`, matches the manifest file for file, and the tree hash recomputes.
  * The frozen tree itself was re-hashed after all my runs: still 229/229, no extra files.
* **The patch:** `r12b-vs-r12.patch`, 861 lines, read in full. `diff -rq` of my R12 review copy against the R12b copy gives the same file list: 4 new files and 8 changed files.
* **The two new modules:** `tied_tables.rs` and `tied_tables/derive.rs`, read line by line.
* **Sol's working tree:** `ops/zkp-mvp/trained-1b` equals the frozen manifest on all 229 paths. So Sol's test binary (`hashline-a876d33e`, built there) ran the frozen source.
* **My runs:** all guarded, detached and serial, on a shared box, n = 1. They ran from 22:43Z to 23:07Z, with the kernel memory cap active. No job declared ≥ 3 GiB, per the 22:58Z lean-memory rule. Golden and dense proofs were **not** rerun (§4 says why).
* **My binaries:**
  * CLI `6704f90e…`;
  * derivation example `c028a50b…`;
  * test binary `hashline-34a4a057`.
  * Sol's binaries are `d9106df6…` and `1d6396ba…`; the build paths differ.

## 1. Per-item table

| # | Item | Verdict | Where (frozen tree, `hashline/src/private_block/`) |
|---|---|---|---|
| 1 | R12-F1: tables derived from the pinned tensor | **FIXED** | `trained_block.rs:582–605`; `tied_tables/derive.rs:122–160, 180–194, 218–267` |
| 1a | ids and scale only from the bound policy/profile | **FIXED at the native level; R-C2 obligation** | `derive.rs:204–207, 220–223` |
| 1b | `token_io_parameters` inside the bound profile digest | **FIXED** | `trained_block.rs:1038, 1384`; `derive.rs:68–84`; `r12b_tests.rs:73–95` |
| 1c | \|margin\| > 32767 refused, never clamped | **FIXED** | `derive.rs:180–187, 260–264` |
| 1d | scope sentence no longer overclaims | **FIXED** | `trained_block.rs:2752`; `trained_statement.rs:538–546` |
| 2 | R12-F2: bounded regular-file hashing | **FIXED WITH NOTES** (N-r12b-2) | `tied_tables.rs:17–70`; `trained_block.rs:593–599` |
| 3 | R12-F3: `--rope-from-export` at pinned transforms | **FIXED** (pre-existing residual for the base, N-r12b-3) | `trained_block.rs:1170–1173` (all prove/verify/stack paths go through it) |
| 4 | N-7: no test writes to `/tmp` | **FIXED WITH NOTES** (N-r12b-4) | `r12_tests.rs:456, 493` |
| 5 | Regression | **PASS** | §4 |
| 6 | Evidence hygiene | **PASS WITH NOTES** | §3 |
| 7 | New weaknesses in the diff | **none for soundness**; notes N-r12b-1..7 | §6 |

## 2. The fixes, in detail

### R12-F1: the tie is now checked by derivation

`tied_of` (`trained_block.rs:538–607`) now does this, in order:

1. It checks each manifest's dtype and shape exactly:
   * embedding: int16, [131072, 3072];
   * head: int8, [131072, 3072];
   * multipliers: int64, [131072].
2. It hashes exactly dtype × shape bytes of each table file and compares with the manifest.
3. It calls `recompute_declared_tied_tables` and refuses any table whose digest differs from the recomputation: "integer table is not derived from the pinned tensor under the export's quantizer".

The derivation (`derive.rs`) works like this:

* **Checkpoint.** It authenticates the whole checkpoint:
  * a regular file of exactly 7,698,241,104 bytes, whose full SHA-256 is the model pin;
  * it re-reads the header from those same authenticated reads;
  * it takes the final-norm weights γ from those reads;
  * it refuses a separate `lm_head`.
* **Tensor.** It re-reads the tied tensor (BF16, [131072, 3072], checked from the authenticated header). Those consumed bytes must hash to the tensor pin `67a138c1…` before any result is returned.
* **Quantizer.** The quantizer is written out in full (`derive.rs:163–194, 242–264`):
  * signed block Hadamard, three blocks of 1024, divided by 32;
  * embedding: rotated row → binary32 → `floor(x/s_x + 0.5)`, refused outside the int16 range;
  * head: γ-folded rotated row, per-row max|x|/127, symmetric int8;
  * multipliers: `max(1, floor(4096·s_row/s_max + 0.5))`, with a 1..4096 check;
  * margin: the rotated (E[yes] − E[no])·γ divided by one public scale, refused outside ±32767.
* **Margin source.** The margin row is derived from the tensor rows. No margin file is ever read.
* **Parameters.** The embedding scale (`residual_scales_in[0]`), the rotation signs (bound by `sign_sha256`) and the calibration are all read from the profile whose digest the statement binds.

**My independent transcription** (`r12b/r12b_tied_reference.py`) [COUNTED]:

* I wrote it from Sol's contract text, not from his code. It runs the Hadamard with decreasing strides; the native code runs increasing strides.
* It reproduces every digest:

  | Table | Digest |
  |---|---|
  | embedding | `baff04d2…` |
  | head | `786f02bc…` |
  | multipliers | `f43790f3…` |
  | fixture margin | `b597f254…` |
  | policy margin (13059 / 2649 / 4.08288030735373e-6) | `1f5cb346…` |

  These equal Sol's `reference_tables.json` and `policy_margin_reference.json`, and Astra's `dg_r12b_t256` manifests and margin file.
* Rotating every value both ways gave **0 mismatches over 805,312,512 rotated values**. The rotation is exact on this tensor, so the contract does not depend on the butterfly order. Astra's and R-C2's transcriptions can rely on that.
* No table entry is refused. The multipliers span 434..4096, and no head row is all zero.

**Attacks on the native loader** (`review_r12b_tests.rs`, my scratch copy only):

* **The R12 attack D verbatim** (7-, 5- and 3-byte tables with consistent manifests) is refused: "missing key dtype".
* **D'** (12 cases, at Shieldstral T128 and T256-DD) — all refused:
  * tables declared correctly but with 7/5/3-byte files → "expected exactly 805306368";
  * wrong shapes or dtypes → "dtype/shape";
  * R12's swapped head is refused too.
* **F1, on my own honest fixture** (27 checks, 143 s, RSS 0.01 GiB). The fixture was written by my transcription, not copied.
  * **Honest tables:** accepted, with my digests.
  * **Each of these is refused as "not derived from the pinned tensor":**
    * a one-byte embedding forgery with its manifest rehashed;
    * a one-byte head forgery with its manifest rehashed;
    * one multiplier m → m+1, manifest rehashed;
    * a plausible uniform multiplier table (all 4096);
    * an all-zero embedding of the exact size, with a consistent manifest (R12's attack D at the real size);
    * the embedding scale moved by a relative 6.4e-6 in the profile.
  * **Seven `token_io_parameters` attacks** are refused by name: absent; bos 2; classifier tn 9; head tn ≠ `norm_tn`; g0 126; head ceps ≠ `norm_ceps`; cn 0.
  * **A profile swapped between the statement read and the derivation** is refused: "profile.json changed before tied-table derivation".
  * **Four `checkpoint_file` attacks** are refused:
    * a symbolic link to the real checkpoint;
    * the 7,698,234,952-byte `consolidated.safetensors`;
    * a sparse file of the exact length;
    * a missing path.
* **Sol's own ignored tied test** also passes against my fixture (47 s).

**Condition (a), ids and scale.**

* `recompute_tied_tables(export, Some((yes, no, scale)))` takes them as arguments only. It checks that they are distinct, inside the vocabulary, and that the scale is finite and positive. Six argument refusals were tested.
* Nothing native reads them from any file. The native loader passes `None`, so no native statement involves the margin.
* Astra's profile carries `classifier_margin_parameters` (13059, 2649, 4.08288030735373e-6, threshold 0) inside the bound profile digest. Its `token_io/classifier.json` duplicates those values *outside* that digest.
* Binding the ids and scale is therefore R-C2's obligation (§5). The native API gives no "prefer the file" path, so the condition is met at the native level.

**Condition (b), the profile fields.**

* The statement binds `export_profile_sha256 = sha256(profile.json bytes)` (`trained_block.rs:1038, 1384`). Every byte of `token_io_parameters` therefore moves the identity. Sol's test changes all nine fields one at a time and the identity moves each time.
* At Shieldstral the loader also validates the fields (`derive.rs:53–84`):
  * bos = 1;
  * g0 = 127;
  * cn and tn inside the declared classes;
  * classifier tn = 10 and ceps < 2^40;
  * head tn and ceps equal `profile_constants`;
  * classifier ceps = head ceps.
* An export that lacks the fields does not load. My F1 attacks confirm each of these refusals.

**Condition (c), refusal not clamp.**

* `quantize` refuses any value outside [−32767, 32767] for the margin and returns no partial row.
* At the actual policy: 0 of 3,072 coordinates are refused, with min −32767 and max 31800 [COUNTED].
* At half the scale, my transcription refuses 232 coordinates, and the native API errors with "quantization overflow (no clipping is permitted)" [MEASURED].

**Scope wording.**

* `STACK_SCOPE_SHIELDSTRAL` (`trained_block.rs:2752`) now reads "the loader checks tied-table derivation from the pinned tensor; token-stage relations require their own review". The `TiedEmbedding` doc says "a declaration alone does not establish a tie".
* Both are accurate. The loader checks the embedding, head and multipliers; it does not check the margin row or any token-stage relation.

### R12-F2: bounded regular-file hashing

`regular()` (`tied_tables.rs:17–44`) works like this:

1. `symlink_metadata` must show a regular file of exactly the expected length.
2. It opens with `O_NOFOLLOW | O_NONBLOCK` (on Linux x86_64).
3. On the open descriptor it rechecks: still a file, the same length, the same dev/ino.

`hash_regular_exact` then reads exactly that many bytes and checks for EOF and an unchanged length.

My test D2', all refused in 0.02 s with no blocking:

* a symbolic link to a file outside `token_io/` → "not a regular file";
* a link to `/dev/zero` → "not a regular file";
* a FIFO → "not a regular file";
* `"../escape.bin"` → refused by `plain_name`.

### R12-F3: the opt-in at pinned transforms

`load_layer_mode` refuses the opt-in first, before any layer read, whenever the export's transform is not `None` (`trained_block.rs:1170–1173`). At load time that transform must equal the geometry's pin (`:1028`).

* `load_layer`, `reload_block` and every CLI path (prove, verify, stack-prove, stack-verify) go through it.
* My test C': all four Shieldstral geometries pin YaRN. The opt-in is refused on both `load_layer` and `reload_block`. Without the opt-in, the comparison with the generator still applies.
* **On Astra's actual `dg_r12b_t256` with my CLI:** `verify`, `verify --dd` and `stack-verify` with `--rope-from-export` are all rejected: "--rope-from-export is refused at a profile with a pinned RoPE transform".
* The same `verify` without the flag loads the real export through the full loader, including the tied derivation, and rebuilds the layer-0 statement `be827c17…`. That identity is informative only; it was rejected against a zero pin as intended.
* No output directory was created.

### N-7

`f3_the_loader_reads_a_tied_export` now writes under `CARGO_MANIFEST_DIR/../results/r12-tied-<pid>` (`r12_tests.rs:456`), not `std::env::temp_dir()`. The new tests write under `../results/r12b-*`. See N-r12b-4 for what is left.

## 3. Evidence hygiene (item 6) [MEASURED, from Sol's logs]

Every one of the 21 final stages in `R12B_AUDIT.json` was audited (`r12b/audit_stages.py` → `r12b/audit_stages.json`). **Every test stage ran real tests, with nonzero passed counts and named `... ok` lines.**

**The 0 s / 0 GiB stages ran real tests, not zero matches:**

| Stage | Tests passed | What it covered | Time |
|---|---|---|---|
| `sol-r12b-components` | 3 | | 0.06 s |
| `components-final-r2` | 4 (+1 ignored) | | 0.008 s |
| `sol-r12b-source-pins-final` | 1 | "S24 run-gate §10: 49 source pins" | 0.008 s |
| `source-pins-final-r2` | 1 | the same | |
| `hash-census-final-r2` | 1 | "32 hash call sites in 24 scanned lane sources" | 0.03 s |

These are source scans and tiny unit tests. They finish below the guard's 0.5 s RSS sampling interval, which is why they show 0 GiB.

**The other stages:**

* **Test stages:**
  * focused: 18 passed;
  * tied: 1;
  * golden: 5;
  * dense: 2;
  * fresh: 2;
  * full suite: 739 passed, 0 failed, 43 ignored, over 29 targets (594 in the library target).
* **Non-test stages:** they print their real outputs:
  * table digests (margin, Astra tables, tn7);
  * `verified` / `statement-checked` events (the four compat stages).
* **`build-7-r2`:** a compile stage. Its log shows "Executable unittests", which is `--no-run` output.

**Notes:**

* The guard's `cmd` record is truncated after about 8 arguments. `--no-run` and the suite's `--no-fail-fast -- --test-threads=4` appear only in `*.command.json`.
* Sol's guard reported `watchdog-only` enforcement (no kernel cap) in his sandbox. Mine reported `cgroup+watchdog`.
* The first suite attempt (593 passed, 1 failed: the stale S25 census) is retained as Sol says.

## 4. Regression (item 5)

**Code.** R12b changes no proof, transcript, layout or statement-field path of an existing profile:

* `tied_of` returns `Ok(None)` for untied geometries before reading anything;
* the RoPE refusal needs a non-`None` transform;
* the new module is reached only from `tied_of`.

**Runs** [MEASURED, shared box, n = 1]:

* **Retained receipts under my R12b CLI.** All verify, and each statement is byte-checked:

  | Receipt | Statement | Peak memory |
  |---|---|---|
  | TinyLlama T128 DD | `d5721276…` | 802 MiB |
  | 8B T128 DD | `4da580bd…` | 2,140 MiB |
  | R8 TinyLlama T128 | `caf6ced2…` | |
  | R8 8B T128 | `5585f5ee…` | |
  | TinyLlama T32 | `9b71dfb0…` | |

* **My R12 attack port** (`review_r12_tests.rs`, verbatim):
  * A, B, C, E, F, G and H pass, with numbers identical to round 10;
  * **D and D2 fail, as intended:** R12's tie and link attacks are now refused.
* **The author subset on my binary:** 119 passed, 0 failed, 6 ignored. It covers r12, r12b, tied_tables, r9, the trained stack and block tests, r6, r8, s24, s25, s33, hash_domain, pad and cs_port.
* **Goldens.** Sol's golden output (`golden-final-r2.log`) gives exactly the four digests and five identities of my own R12 golden run: 9 of 9 lines identical. Two facts back this up: his binary was built from the frozen source, and the diff touches no proof path. So the 6 GiB golden and dense runs were not repeated, under the lean-memory rule.

## 5. What the token lane (R-C2) and Astra's export must rely on

### Token lane (R-C2)

1. **Take the ids, scale and threshold from the bound profile.** Read yes/no ids, `public_scale` and `threshold_c` only from the statement-bound profile's `classifier_margin_parameters`, or from a registered policy.
   * Then call `recompute_tied_tables(export, Some((yes, no, scale)))`.
   * Never take these values from `token_io/classifier.json`, which sits outside the profile digest.
   * `threshold_c` is not bound natively at all.
2. **Check the profile digest.** Require `result.calibration.profile_sha256 == statement.export_profile_sha256`. The API re-reads `profile.json`, so this closes the window between reads.
3. **Use the returned margin.** Either use the returned margin row directly or require `margin_int16.bin` to equal it byte for byte. Never prefer the file.
   * Take BOS and the final norms from `calibration`.
   * Classifier: g0 127, tn 10, ceps < 2^40.
   * Head: tn and ceps are the profile's.
4. **Keep refusals refusals.** A margin refusal is an error that must reach the caller. Do not catch it and clamp.
5. **Do not apply γ twice** (N-r12b-5). Under the contract, w = q( H·diag(sign)·((E_yes − E_no) ⊙ γ) / 32 / s ). The final-norm weight γ and the rotation are already folded into w. The classifier relation must use the rotated normalised state with only the g0 = 127 gain.
6. **Budget for the checkpoint.** The embedding, head and multiplier digests are already enforced by the native loader whenever a Shieldstral export loads. The cost: every load streams the 7.7 GB checkpoint and the 0.8 GB tensor (about 17 s measured for a whole `verify`) and needs the checkpoint locally (N-r12b-1). Run the API under the guard.

### Astra (A2)

1. **Tables.** The tables must equal the native recomputation bit for bit. `dg_r12b_t256` does: I reproduced all four digests independently.
2. **`token_io_parameters`.** `profile.json` must carry it, valid as in §2 condition (b): bos 1; classifier tn 10 with ceps = `norm_ceps`; head tn and ceps = `profile_constants`; g0 127. Otherwise the export does not load. `dg_r12b_t256` loads under my CLI.
3. **Manifests.** They must declare dtype and shape exactly. The tables must be regular files, not links.
4. **Re-exports.** Any change to `residual_scales_in[0]`, the rotation signs or γ regenerates all three tables through the contract.
5. **`checkpoint_file`.** Do not put it in a profile meant for third-party verification: it is part of the statement identity (N-r12b-1).

## 6. Notes (none is a soundness finding)

* **N-r12b-1 (liveness / portability).**
  * Every Shieldstral load (prove, verify, stack-verify) streams the checkpoint (7.7 GB plus the 0.8 GB tensor, about 15–17 s) and needs it locally.
  * The checkpoint must be at the hard-coded `DEFAULT_CHECKPOINT` (`/home/victor/models/…`, `derive.rs:10`) or at `tied_embeddings.checkpoint_file`. That field lies inside the bound profile digest, so moving the checkpoint changes the statement identity. Both cases fail closed.
  * For third-party verification, consider either of these:
    * a verifier-side location (a flag or environment variable) outside the statement;
    * R12's option (b): registered derived-table digests per calibration, computed once with this function and reviewed, so that remote verifiers need not stream the checkpoint.
* **N-r12b-2 (F2, low).**
  * `O_NOFOLLOW | O_NONBLOCK` is set only on Linux x86_64. Elsewhere (the Mac rig), the pre-open `symlink_metadata` check still refuses links, FIFOs and devices. Only a FIFO swapped in during the race window could block the open before the dev/ino recheck.
  * A symbolic link in a *parent* directory (for example `token_io/` itself) is followed. The bytes are still bounded and authenticated by derivation.
* **N-r12b-3 (F3 residual, pre-existing since R2).**
  * At unscaled profiles, the opt-in still proves export tables while the statement records the pinned base. My R12 test C still passes, with 1 entry off at rung-TC.
  * This is outside R12b's fix scope as I set it in round 10. Close it later by refusing the opt-in at every trained profile, or by recording "export tables" plus their digest.
* **N-r12b-4 (N-7 residue).**
  * Tests now write under the source tree's `../results/`. The pid-named directories are never cleaned up. Running the suite *inside* a frozen tree would write into it; the frozen R12b tree is unchanged, because all my runs used my copy.
  * Older `temp_dir()` test writers remain, and Sol's suite ran without `TMPDIR`: `stable_weight_*_tests` (3), `wcache` / `wcache_atomic_tests` (3), `run_capture_tests`, `run_tests`, `s24_tests`, `mvp_driver`'s test, and the `base_dir` fallback when `ZK60_NATIVE_TINY_EXPORT_DIR` is unset. `cs_port_tests` only names a missing path. They predate R12, and I found no leftovers of mine in `/tmp`.
  * The measured cost of N-r12b-1: each CLI load of the real export took 16.9–18.3 s, even when the opt-in refusal fires, because `TrainedExport::load` derives first.
  * Sol's ignored tied test edits his evidence fixture in place and restores it before asserting. A kill mid-test would corrupt that fixture.
* **N-r12b-5 (contract point for R-C2).** γ is folded into both the head rows and the margin row (§5, item 5).
* **N-r12b-6 (fidelity, for the calibration lane).**
  * At s_x = 0.00355, the embedding entries span only −16..16: about 5 bits, and no entry reaches −32768.
  * The policy margin's extreme coordinate sits at |x|/s = 32767.000000000004, half a unit inside the refusal edge. The scale must be used as the exact binary64 value `4.08288030735373e-06`.
* **N-r12b-7 (capture format).**
  * The two new source pins are appended to `OWN_SOURCE_FILES`, so the `SHARED_SOURCE_FILES` entries move by two positions in a bundle's `source_pins` (`run_capture.rs:1983`). R12 did the same with `rope.rs`.
  * No gate tool indexes `source_pins` by position; I grepped for it. Captures from R12b list 49 pins.

## Evidence

Everything below is under `results/zk60_d24_review_20261017/r12b/` unless a path says otherwise.

**Tree checks and Sol's evidence:**

* `tree_check.py`: scratch copy and frozen tree against the manifest;
* `audit_stages.py` / `.json`: Sol's 21 stages.

**Independent transcription:**

* `r12b_tied_reference.py` / `.json`: digests, order check, margins;
* `rv12b-tied-reference.*`: 100 s, 0.59 GiB.

**Builds:**

* `r12b_cli.sh`, `rv12b-cli-build.*`, `binaries.sha256`: my CLI and derivation example;
* `r12b_queue.sh`, `queue.out`: the serial queue;
* `rv12b-test-build.*`, `test-binary.sha256`.

**Tests:**

* `rv12b-review-new.log`: D', D2', C';
* `rv12b-review-r12port.log`: 7 passed, D and D2 refused as intended;
* `rv12b-f1.log`: 27 checks;
* `rv12b-sol-tied.log`;
* `rv12b-author-subset.log`: 119/0/6.

**CLI and retained receipts:**

* `rv12b-cli-real-load.log`, `rv12b-cli-f3-{verify,verify-dd,stack}.log`: Astra's real export;
* `rv12b-compat-{tl-dd,8b-dd,tl,8b,tl-t32}.log`: five retained receipts.

**My fixture:**

* `fixture.sha256`: hashes of my fixture. Its three large tables were deleted after the run; they are byte-identical to Sol's `tied-fixture` and are reproducible with `r12b_tied_reference.py`.

**Test modules** (in my scratch copy only):

* `ops/zkp-mvp/trained-1b-review-r12b-scratch/hashline/src/private_block/review_r12b_tests.rs`;
* `review_r12_tests.rs`: the round-10 module, verbatim.
