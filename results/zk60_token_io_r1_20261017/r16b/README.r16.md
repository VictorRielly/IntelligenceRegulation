# Token-I/O CLI: binaries and demo runs

This folder holds the token-I/O lane's `zk60_token_io` release binaries (one copy per round),
the verifier copies of the exports (public files only, hard links, no `seq_*`), and the demo
run directories. It holds no owner decommitments. Those live outside the repository:
binaries up to round 8 used `~/zk60-artifacts/token-io/`, and round 9 uses
`~/zk60-owner-private/token-io/` (PR4-16). Nothing here is a privacy acceptance.

## Binaries

Each copy's SHA-256 is in the `binaries*.sha256` file beside it.

| file | sha256 (first 12) | round |
|---|---|---|
| `zk60_token_io.release.bin` | 8c759e24f82d | r4 |
| `zk60_token_io.r5.release.bin` | da48f6d47c43 | r5 |
| `zk60_token_io.r6.release.bin` | 3225e5770f16 | r6 (statement schema `/1`) |
| `zk60_token_io.r7.release.bin` | db3d982533ef | r7 (native R8 base, schema `/2`) |
| `zk60_token_io.r7c.release.bin` | b18ad304e7f0 | r7 with the capture hooks (cfg(test) only; same `.text`) |
| `zk60_token_io.r8.release.bin` | 6b601c148da9 | r8 (T128 profiles) |
| `zk60_classify.r12.release.bin` | 04036e269a5c | r12: the CLASSIFIER CLI (R-C1, D41 chunks; see the section below) |
| `zk60_classify.r13.release.bin` | e320c2379bf7 | r13: the classifier CLI at rung R-C2 (tables re-derived from the pinned tied tensor; native R12b base; statement schema `zk60-classify-run/2`) |
| `zk60_classify.r14.release.bin` | 48dac98818f7 | r14: the classifier CLI at rung R-C3 (short items as one chunk of their length, pad positions pinned; the table binding in the library; statement schema `zk60-classify-run/3`; native R12b base; reviewed: ACCEPTED on soundness, REVIEW_R14; build note `zk60_classify.r14.BUILD.txt`) |
| `zk60_classify.r15.release.bin` | 5edb7241f3c6 | r15: as r14, plus `label --expect-total N` REQUIRED (the post's own token count; a chunk set not covering exactly `[0, N)` is refused, REVIEW_R14 N-r14-1); receipts and statement schema `/3` unchanged (r14 and r15 receipts verify with either binary); native R12b base; UNREVIEWED; build note `zk60_classify.r15.BUILD.txt` |
| `zk60_classify.r16.release.bin` | e94cecf99f82 | r16: **native R13 base**; the REAL Shieldstral-1.0-3B classifier registered (R13 LOW + h24 exports, schema v2, T128 and T256 non-DD run profiles `hashline-zk-mr1/private-classify-run-shieldstral-3b-t{128,256}-r13-public-row/1`; each block stage at its layer's bound gate denominator); the D37 category policies `shieldstral-1.0-3b-moderate-{sexual,violence,hate}/1` (moderate wording, PENDING Victor's strict / moderate ruling); one checkpoint stream per command; the rung's receipts, statements and schema `/3` unchanged; UNREVIEWED; build note `zk60_classify.r16.BUILD.txt` |
| `zk60_classify.r16-frozen.release.bin` | dae5abd78954 | r16, built from `frozen-r16` exactly after the full suite (the receipts' binary above predates N-r14-2's two comment lines in `classify.rs`, which move panic line numbers); verifies the real receipts of `e94cecf99f82` and cross-verifies rung receipts with it; UNREVIEWED |

Round 9 adds `zk60_token_io.r9.release.bin`, with `binaries_r9.sha256` and its build note
`zk60_token_io.r9.BUILD.txt`, once the round-9 chain builds it.

## Which binary re-checks which run (review REVIEW5, TR6-7)

A run is re-checked by running `zk60_token_io verify` again on its directory. That works only
with a binary that reads the run's statement schema.

* **Schema `zk60-token-io-run/1`** (the r4, r5 and r6 demo runs: `run-b7_T32-ho00`,
  `run-b7_T32-ho00-r5`, `run-b7_T32-r6-ho00`): re-check ONLY with
  `zk60_token_io.r6.release.bin`. The r7 and later binaries refuse these runs by name. That
  is the expected effect of the schema bump to `/2` (native R8 per-layer calibration). Keep
  the r6 binary for that purpose.
* **Schema `zk60-token-io-run/2`** (the r7 and r8 runs: `run-llama3_8b_pg_rot1_b7voc0_T32-r7-ho00`,
  `run-tinyllama_dg_rot1_T128-r8tl-ho00`, `run-llama3_8b_pg_rot1_b7voc0_T128-r8x-ho00`,
  `run-llama3_8b_dg_rot1_voc0_T128-r8dgx-ho00`): use the r7 or a later binary. Give it the
  verifier copy of the export and both pins from the approval record in `../approvals/`.

## Round-9 changes to the binary's interface

These change what the r9 binary accepts compared with r8.

* The prompt is never put on the command line (PR4-17). Give `--prompt-file FILE` (mode 0600)
  or `--prompt-file -` (standard input). `--prompt` is refused with exit code 2.
* `owner` writes the next token to a 0600 file (`--token-out`). It prints the token only when
  given `--print`.
* `prove` runs one sealing pass before any header (PR4-4). A refused prove reports every
  directory it removed (PR4-15).
* A killed prove leaves `<out>.incomplete/`. The next prove to the same `--out` refuses by
  name until that directory is removed by hand.
* The owner directory is refused inside a git working tree, whether it is the default or
  given explicitly (TR5-3 (a), TR6-3). The test is git's own rule: a `.git` directory holding
  `HEAD`, or a `.git` file starting with `gitdir:`. A work tree driven by `GIT_DIR` /
  `--git-dir` is not detected.

## The classifier CLI: `zk60_classify` (round 12, rung R-C1; round 13, rung R-C2; round 14, rung R-C3; round 15; round 16)

**Round 16 in brief: the real Shieldstral classifier on native R13** (design `../classifier/DESIGN_CLASSIFIER.md`
§17; REVIEW_R13 §10). UNREVIEWED; not a privacy acceptance; not a classifier-quality claim.
- **Exports:** Astra's R13 Shieldstral exports (schema `zk60-trained-profile-export/2`, `accuracy_stack`
  `low-h24-v1`, geometry `shieldstral-3b-t128` / `-t256`; T128:
  `results/zk60_shieldstral_export_20261026/native_low_h24_t128`, profile `2ba468f9…`; T256:
  `results/zk60_1b_native_20261017/r13/shieldstral-export-v2`, profile `1d500782…`) load under the classifier run
  profiles `hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/1` and `…-t256-r13-public-row/1`
  (non-DD; T256 is registered for larger hosts and is NOT proved on the 8 GB laptop). `--tables` is the export's own
  `token_io/`. The r15 binary refuses these exports (it reads schema `/1` only).
- **Policies (one fixed list, D45(2)):** `shieldstral-1.0-3b-moderate-sexual/1`, `…-moderate-violence/1`,
  `…-moderate-hate/1` — D37's three categories in Astra's MODERATE template wording (her
  `category_policy_candidates.json`, ids byte for byte). **The strict-versus-moderate choice is still Victor's**
  (open item 1 of `ZK60_RULINGS_FOR_VICTOR_20261017.md`; the coordinator recommends moderate); if he picks strict,
  these three entries are replaced (new policy ids; an item proved under one wording is never re-proved under the
  other). Chunk size at T128: 55 / 55 / 49 content ids (the hate template is 6 ids longer); overlap 8 (a tunable
  D41 deployment constant). Pad id 11, yes 13059 / no 2649, c = 0; the export profile's
  `classifier_margin_parameters` must name the same values.
- **Whole-run floor [COUNTED]:** T128 2^-96.86 -> 96 bits; T256 2^-95.91 -> 95 bits (REVIEW_R13's degree-2 lookup
  term plus the column test and the stage terms). Both pass `--min-bits 95` (the D27 floor; `--min-bits` below 95 is
  refused); T256's margin is 0.91 bit.
- **Activations (`--seq-dir`):** the prover's sealing pass still checks bit-exact parity of every block against the
  item's per-layer activations `x_in_LXX.bin` / `x_out_LXX.bin` (int16 `[T, d]` LE) in a prover-private directory. For
  round 16's real runs they were written by the native builder itself (the ignored test
  `classify_r16_tests::r16_write_item_activations`), so that parity is self-consistency, not an independent reference.
  An app needs a source of these files per item (see "How an app drives it").
- **One checkpoint stream per command:** the export loader's single authenticated pass over the 7.7 GB checkpoint now
  also derives the margin row, and the classifier's tied loader reuses it (token review N-r13-5; every check kept).
- Measured on the laptop [MEASURED, shared box, n = 1; one 35-id ToxicChat post from Astra's A1 inputs, a short item;
  binary `e94cecf99f82…`; table in `../r16/real_runs.json`]:

  | category (moderate) | prove total / proving | receipt | prove peak RSS | verify / input-owner / label (fresh processes) | their peak RSS | verdict |
  |---|---|---|---|---|---|---|
  | sexual | 439 s / 328 s | 848,412,096 B, 28 segments | 8.15 GiB | 68 s / 67 s / 66 s | 2.29 GiB | not-flagged |
  | violence | 453 s / 346 s | 848,412,096 B, 28 segments | 8.08 GiB | 68 s / 68 s / 66 s | 2.27 GiB | not-flagged |
  | hate | 456 s / 349 s | 848,412,096 B, 28 segments | 8.27 GiB | 71 s / 68 s / 67 s | 2.32 GiB | not-flagged |

  Each verify-class command re-verifies all 28 segments (about 36 s) after one checkpoint stream and the export load.
  The verdicts are those of a benign post; no classifier-quality claim.

**Round 15 in brief** (design `../classifier/DESIGN_CLASSIFIER.md` §16; review note REVIEW_R14 N-r14-1).
- **`label` now requires `--expect-total N`**, N being the POST's own token count from the policy's
  pinned tokenizer (the app counts it; never take it from the proofs). The label is refused, with the
  fail-closed line, unless every chunk run's `content_total` is N and the runs' ranges are exactly the
  D41 split of `[0, N)`. Before, a proof set of only the post's first ids labelled cleanly (since r14 a
  short item of any length is one chunk). Without `--expect-total` the r15 `label` refuses; the r14
  binary has no such argument (exit 2).
- The `label` event gains `expect_total`. prove, verify and input-owner, the statement (schema
  `zk60-classify-run/3`) and the receipts are unchanged: an r14 receipt verifies with the r15 binary
  and the reverse (both `/3`; the profile text did not change).
- Capture files (test builds only) list exactly `n_slots` slot triples (gate F18-1).

**Round 14 (R-C3) in brief** (design `../classifier/DESIGN_CLASSIFIER.md` §15). The four classifier
rulings are accepted (D45, Victor 2026-10-29): the content length is public, one fixed policy list with
one threshold each, the proof linked to the post, fail closed. Changes against r13:
- **Short items.** A content of N ids with `1 <= N < T − P0 − S` (the rung: N < 23) is ONE chunk
  `[0, N)` of its true length. The item is the prefix, the N ids, the suffix, then the policy's public
  pad id up to T (the rung's dev policy: 2; Shieldstral's card policy: 11, tekken's `<pad>`); the proof
  pins every pad position and reads the verdict at the public row `P0 + N + S − 1`. The prover's
  activations (`--seq` / `--seq-dir`) must be those of that padded item. An empty content is refused.
- **Statement schema `zk60-classify-run/3`**, adding `item_length`, `pad_id`, `pad_positions` and
  `verdict_row`; the profile text names them and the ruling switches name D45. **Re-check R-C2 runs
  (schema `/2`) only with the r13 binary; the r14 binary refuses them** (another profile digest).
- The library's classifier entry points take tables bound to the model (REVIEW_R13 N-r13-1); the CLI's
  arguments and loader rules are unchanged.
- **R-C1 receipts (schema `/1`, the r12 binary) support no classifier claim** (REVIEW_R13 N-r13-8): the
  r12 binary accepts a verdict proved from a doctored, rehashed margin row, and R-C1 and later receipts
  share the trained statement identity, so only the schema tells them apart.

**Round 13 (R-C2) in brief.** The r13 binary binds the tables to the model. The section below is
R-C1's contract, with these changes:
- prove and verify **re-derive** the margin row `w` and the embedding's SHA-256 from the pinned tied
  tensor. `margin_int16.bin` and `embedding_int16.bin` must equal the derivation; a file that differs
  is refused even when its manifest digest was updated to match. The run uses the recomputed row;
- the yes / no ids, the public margin scale and the threshold c are read only from the export
  profile's `classifier_margin_parameters`, which the trained statement binds through
  `export_profile_sha256`. The registered `--policy` must name the same values, and any copy in
  `classifier.json` (`yes_id`, `no_id`, `threshold_c`, `margin_vector.scale`) must equal them;
- BOS and the final norm come from the export profile's `token_io_parameters`;
  `classifier.json`'s `bos` / `final_norm` must equal them;
- a margin word outside [-32767, 32767] is refused, never clamped;
- `--min-bits` below the run profile's floor is refused: 93 only at the development rung, 95
  everywhere else (D27);
- at the development rung, `--tables` also holds the pinned synthetic tensor
  `dev_tied_tensor_bf16.bin` (sha256 `bba6d094…`). At Shieldstral the tensor is the pinned checkpoint,
  streamed by native R12b's `recompute_tied_tables` (17.3 s measured warm, twice per prove or
  verify, REVIEW_R13 N-r13-5; run it under the guard);
- the statement schema is `zk60-classify-run/2` (round 14: `/3`, above). It adds `margin_scale` and
  `tied_source`, and the scope sentence names R-C2. **Re-check R-C1 runs (schema `/1`) only with the
  r12 binary, and only as a record: they support no classifier claim (N-r13-8).**

Design: `../classifier/DESIGN_CLASSIFIER.md` §14. Tests: `token_io/classify_tied_tests.rs`. The
registered run profile is still only the development rung; Shieldstral's tied path is wired and
tested on Astra's export, but no Shieldstral classifier run profile is registered yet. Not a privacy
acceptance.

**What it proves.** The approved integer model's verdict on hidden content, under one
pre-registered policy (one category). The verdict is public: `flagged` means the model's
yes-minus-no margin is above the policy's threshold c. The content stays hidden. Design:
`../classifier/DESIGN_CLASSIFIER.md` (v2.2; §13 covers chunks, D41). It is not a privacy
acceptance.

**Scope today.**
- Only the development rung is registered: the trained-calibration rung T32, with the
  synthetic policy `rung-tc-synthetic-policy-dev/1`.
- Shieldstral's classifier run profile and its category policies are NOT registered yet. R-C2 wired
  and tested Shieldstral's tied path through native R12b; the run profile waits for native R13 and
  Astra's fixed export. The arguments and outputs below stay the same.
- The R-C2 binary is `zk60_classify.r13.release.bin` (sha256 in `binaries_r13.sha256`, build note
  `zk60_classify.r13.BUILD.txt`). The R-C1 binary is `zk60_classify.r12.release.bin` (sha256 in `binaries_r12.sha256`). It is
  built from `examples/zk60_classify.rs`.
- The next-token binary `zk60_token_io` is separate and unchanged.
- **Not head-binding in R-C1 (fixed by R-C2, r13 binary, above).** In R-C1 the margin vector (`margin_int16.bin`) is a given public table,
  checked only against the digest its own `classifier.json` declares; it is not derived from the
  model's tied embedding / head (nor are the embedding, bos and final norm recomputed). No classifier
  proof from this binary may be described as binding the head until R-C2 lands (the verifier
  re-derives the margin vector from the pinned tied tensor and the policy's yes / no ids, native R12b).

### Commands

```
zk60_classify prove        --export DIR --tables DIR --policy ID --content-file FILE|-
                           [--chunk J] (--seq ID | --seq-dir DIR) --out DIR
                           [--owner-dir DIR] [--label L]
zk60_classify verify       --export DIR --tables DIR --policy ID --artifact DIR
                           --expect-statement HEX [--label L] [--min-bits N]
zk60_classify input-owner  (verify's arguments) --decommitment FILE --content-file FILE|-
zk60_classify label        --export DIR --tables DIR --policy ID --runs DIR,DIR,...
                           --expect-statement HEX --expect-total N [--label L] [--min-bits N]
```

**Exit codes.**

| exit | meaning |
|---|---|
| 0 | done |
| 1 | refused |
| 2 | bad arguments |

**Arguments.**

| argument | meaning |
|---|---|
| `--export DIR` | One calibration-export variant directory. The prover needs its `seq_*`, or a prover-private `--seq-dir` holding `x_in_L00.bin` / `x_out_L00.bin`, for bit-exact parity. A verifier must be given a copy without `seq_*`; it refuses an export that holds them. |
| `--tables DIR` | `token_io.json` + `embedding_int16.bin` (the token run's embedding format), plus `classifier.json` + `margin_int16.bin`. `classifier.json` is `{"schema": "zk60-classifier-tables/1", "margin_vector": {"sha256": …, "d": …}, "bos": …, "final_norm": {"g0", "cn", "tn", "ceps"}}`. `margin_int16.bin` is the int16 margin vector, `d` words, little-endian. Every binary file is length- and SHA-256-checked before use. |
| `--policy ID` | A policy from the fixed, pre-registered list (B-6). An unknown id is refused. |
| `--content-file FILE` or `-` | The WHOLE content's token ids, separated by commas or whitespace. The file must be a regular file of mode 0600, or `-` for stdin. The ids are tekken's plain-text encoding of `' ' + content` (B-1 / B-2). The caller tokenizes; the policy's template is added by the CLI. `--content` on the command line is refused (exit 2). |
| `--chunk J` | D41: prove chunk J (default 0) of the profile's public split. The size is `T − P0 − S`, the overlap is registered per profile (rung: size 23, overlap 4), and the last chunk is end-aligned. **Round 14:** a content shorter than one chunk is one chunk (J = 0) of its true length, padded with the policy's public pad id; an empty content is refused. |
| `--expect-statement HEX` | The pinned trained-statement identity of the export under the classifier run profile. |
| `--min-bits N` | The verifier's minimum whole-run figure. The default is 95; **the rung's floor is 93, so pass `--min-bits 93` at the rung.** |
| `--label` | The context label. It is a deployment constant; only `zk60-classify-verdict` is admitted. |
| `--runs` | For `label`: every chunk run of ONE item for ONE category, comma-separated, in any order. |
| `--expect-total N` | For `label`, **required (r15)**: the post's own token count, from the policy's pinned tokenizer, counted by the caller. The label is refused unless the runs cover exactly `[0, N)` (N-r14-1). |

**What `prove` writes.**
- `<out>/`: the receipt, `L + 2` segment files. It is built as `<out>.incomplete/` and renamed
  only after the run proves.
- `<out>.unverified-statement/statement.json`: the prover's statement, unverified.
- The owner directory `input.dec`: the input owner's decommitment. The directory is 0700 and
  the file 0600. The default location is `$HOME/zk60-owner-private/token-io/<run>-<key>.owner-private`;
  `--owner-dir` must be outside the run's parent and outside any git work tree.
- A refused prove removes every directory it created and says so (`removed` events).

**What `verify` does.**
1. It re-renders the canonical statement from its own inputs (B-3): the model from `--export`
   pinned by `--expect-statement`; the margin row and the embedding's digest RE-DERIVED from the
   pinned tied tensor (R-C2; `--tables` is only compared with them); the ids, the scale and c from
   the export profile's `classifier_margin_parameters`, which `--policy` must name; BOS and the
   final norm from its `token_io_parameters`; the template, the pad id and the chunk plan from
   `--policy` and the profile.
2. It refuses unless the found statement is that text byte for byte, before reading any
   segment.
3. It verifies every segment.
4. It publishes `<artifact>/statement/statement.json` and removes the unverified one.

A second `verify` re-checks the published statement byte for byte.

**`input-owner`** runs verify's full check, then checks the decommitment against the input
root with the owner's WHOLE content (it takes the chunk's slice itself).

**`label`** verifies every chunk run in full, then prints the category's label: the OR of the
chunk verdicts. It **fails closed**: a run that does not verify, a missing or repeated chunk
index, or chunks naming different policies, models, totals or plans give exit 1 and the
fail-closed line. **Round 15:** so does a set whose `content_total` is not `--expect-total` (a
proof set of only the post's first ids, or another post's), a range that is not its index's range
in the split of `[0, N)`, and a missing or invalid `--expect-total`.

### Output contract (JSON lines on stdout)

| event | printed by | fields |
|---|---|---|
| `loaded` | prove | export_variant, run_profile, blocks, trained_statement_identity, policy, chunk, chunks, content_length_n |
| `segment` | prove | index, bytes, elapsed_seconds |
| `proved` | prove | run, owner_dir, verdict (`flagged` / `not-flagged`), policy, chunk, chunks, segments, receipt_bytes, prove_seconds, whole_run_floor_bits, total_seconds, statement (`UNVERIFIED …`) |
| `classified` | verify | verdict, chunk, chunks, policy, trained_statement_identity, input_token_endpoint_root, verify_seconds, whole_run_floor_bits, published_by |
| `content-checked` | input-owner | content_total, chunk, range `[a, b]`, verdict, checked_against |
| `chunk-verified` | label | run, chunk, range, verdict |
| `label` | label | policy, label (`flagged` / `not-flagged`), chunks, content_total, (r15) expect_total, chunk_size, overlap, flagged_ranges, note |
| `refused` | every command | command, error |
| `app-outcome` | every refusal (right after `refused`) | outcome `"flagged"`, why: **fail-closed (D45(4); B-4)**. An item without an accepted proof is handled as flagged. |
| `removed` / `REMOVAL-FAILED` | prove | path (and error): the directories a refused prove created |

**The statement** (`statement.json`, schema `zk60-classify-run/3` from r14; `/2` r13, `/1` r12) holds:
- the scope;
- who wrote it: the prover (unverified) or the verifier;
- the run and block profiles, `blocks`, the export variant and the trained statement identity;
- `policy`, `verdict` (`flagged` / `not-flagged`) and `verdict_bit`;
- `threshold_c`, `yes_id` and `no_id`;
- the template prefix and suffix ids;
- `content_length_n` and `chunk` (index, count, range, content_total, chunk_size, overlap,
  split);
- `T`, (r14) `item_length` = P0 + n + S, `pad_id`, `pad_positions` = T − item_length and
  `verdict_row` = item_length − 1, `control_ids_below` and the tokenizer;
- the margin-vector and embedding digests, (r13) `margin_scale` and `tied_source`, `bos` and
  `final_norm`;
- `classifier_profile_digest`, `rulings` (the four ruling switches, accepted as D45) and the
  context label and context;
- `input_token_endpoint_root`, `whole_run_floor_bits` and the parameter line.

### How an app drives it (one item)

One item per post. Count the post's tokens once, with the policy's pinned tokenizer (B-1 / B-2):
that count N is the content file's length and the split's total. Then, for each category of the
fixed list, and for each chunk `J` of the split:
1. `prove --policy <category> --chunk J …`
2. `verify` the run directory, or let the app's verifier do it.
3. Run `label --runs <every chunk run of that category> --expect-total N`, **passing the post's own
   token count N** (r15; N-r14-1). The exit-0 `label` line is the category's proved label, and its
   `content_total` equals N. The app compares it again itself and fails closed on any mismatch: a
   proof set for only the first k < N tokens of an N-token post must never label the post.

**Round 16, Shieldstral at T128:** the fixed list is the three moderate category policies; `--export` and `--tables`
are the R13 export and its `token_io/`; `--expect-statement` pins the trained statement identity the model's
approver publishes for that export under the classifier run profile. Each `prove` also needs the item's per-layer
activations in a prover-private `--seq-dir` (the sealing pass checks every block against them): the app must produce
them per item and category, with an integer evaluator of the same S2 arithmetic (Astra's), or the native builder
(round 16's `r16_write_item_activations` shows the format). Budget per category on the laptop: about 7.5 minutes and
8.2 GiB to prove, about a minute and 2.3 GiB to verify; one prove at a time box-wide.

Any refusal, at any step, means `flagged` for that category (D45(4)). A short content is one chunk
(J = 0). The per-chunk verdicts are
public, so a flagged label also shows which token ranges triggered it (D41, design §13.4).
