# Gate round 19: the classifier gate on the R13 stack and the REAL Shieldstral-1.0-3B classifier

Privacy gate lane, 2026-10-29 10:58-15:2x UTC (token frozen-r16b on native R13). **This is NOT a privacy
acceptance.** Labels: [MEASURED] a run happened (laptop, shared box, n = 1); [COUNTED] exact arithmetic;
[READ] read from the code.

## 1. Result in plain words

* **The gate now works on the R13 stack, and it gated the REAL Shieldstral-1.0-3B classifier.** Tools v22 (frozen,
  80 files) read 14 captures made from the token lane's frozen-r16b tree; all 14 pass [MEASURED].
* **The real one** is a fresh proof by the named r16b binary of a 35-token real post under the moderate-sexual
  policy (a short item with 20 pad positions at id 11; verdict not-flagged; 848 MB receipt). On it the gate finds
  [MEASURED, 2,439 s, 5.17 GiB, alone]:
  * **nothing disclosed beyond what is public**: disclosed dimension 0 on every one of the 84 commitments except
    the H commitments' expected 2 (their zero-sum pair); the 28 masking commitments 0; the joint figure 0 over
    1,052,800 word pairs;
  * every classifier-stage public table REBUILT from public data (19, none taken), including the margin row and
    the embedding, which the gate derived itself from the 7.7 GB checkpoint and which match the statement bit for
    bit (B-3);
  * the verdict row opened at 107 = P0 + n + S - 1, the content length and pad layout public as ruled (D45(1));
  * all 15 controls fire, including the four C-13 short-item controls at pad id 11;
  * the input owner's check passes in a fresh process.
* **Two declared limits on the real capture** (status `PASS-WITH-DECLARED-LIMITS`): it was recorded without the
  public tables' values (with them it would be several GB), so 12 of the 23 block slots whose identity needs those
  tables are open (the other 11 equal in all 26 blocks); and the full zero-data preimage ran on a declared sample
  (15 of 84 commitments: both stages and blocks 0, 12, 25; 9.7 M entries, 0 differing) because each block costs
  about 8 minutes at 5.7 GiB. Both are checked in full on the 13 R13-rung captures.
* **The 13 R13-rung captures** (two blocks at different gate denominators 20 / 21; verdict 0 / 1 / tie; a 2-chunk
  item; short items n = 1, 11, 22): **all PASS, 0 false parts, 0 unfired controls**; all 23 block slots per stage
  at R13; 7 R13-specific controls fire as predicted; the verdict moves nothing but its public bit, and a short item
  nothing but its public length.
* **The refusal term goes up**: at R13 the SiLU tuple table has 16,384 rows instead of 256, so the D34 / D40
  input-dependent refusal term is **2^-108.25** per run at Shieldstral (D40 was 2^-112.7). And whether an honest
  item proves at all depends on its content (range refusals; measured: 102 of 300 ids at one dev calibration).
* **Capturing R13 runs needed four test-only gate patches** in the gate's own copy of the token tree (no prover or
  verifier byte): the token recorder cannot record any R13 run as frozen (its plane index is legacy-only).
* **Not a privacy acceptance.** What a statement still needs is in §8.

## 1a. The records [MEASURED, frozen v22]

| capture | L | n | verdict | status | block slots | classifier slots / tables rebuilt / taken | disclosed (A, E, B / H) | full preimage (entries / differing) | controls |
|---|---|---|---|---|---|---|---|---|---|
| classify-r13-rung-L2-{v0,v1,vtie} | 2 | 23 | 0 / 1 / 0 | PASS x3 | 23 / 23 x2 | 12 / 19 / 0 | 0 / 2 | 2.25 M / 0 | 14 + C13-1 n/a |
| classify-r13-rung-L1-v1 | 1 | 23 | 1 | PASS | 23 / 23 | 12 / 19 / 0 | 0 / 2 | 1.24 M / 0 | 14 + C13-1 n/a |
| classify-r13-rung-L2-v1-chunk{0,1}o27 | 2 | 23 | 1, 1 | PASS x2 | 23 / 23 x2 | 12 / 19 / 0 | 0 / 2 | 2.25 M / 0 | 14 + C13-1 n/a |
| classify-r13-rung-L2-{v0,v1,vtie}-short1 | 2 | 1 | 0 / 1 / 0 | PASS x3 | 23 / 23 x2 | 12 / 19 / 0 | 0 / 2 | 2.25 M / 0 | 15 |
| classify-r13-rung-L2-{v0,v1,vtie}-short11 | 2 | 11 | 0 / 1 / 0 | PASS x3 | 23 / 23 x2 | 12 / 19 / 0 | 0 / 2 | 2.25 M / 0 | 15 |
| classify-r13-rung-L2-v1-short22 | 2 | 22 | 1 | PASS | 23 / 23 x2 | 12 / 19 / 0 | 0 / 2 | 2.25 M / 0 | 15 |
| **classify-r13-shield-t128-cli-sexual-r16b** (real) | 26 | 35 | 0 | **PASS-WITH-DECLARED-LIMITS** | 11 / 11 covered x26 (12 open by option) | 12 / 19 / 0 | 0 / 2 (84 commitments) | 9.67 M / 0 (sample of 15) | 15 |

Rung records: 865-916 s each (~631 s at L 1), about 1.0 GiB, light. Per stage the R13 rung also passes the 7 R13
controls (G +1 -> exactly slot 18; score precision -> 17; norm shift -> 14; a group id -> 18; an ACT3 entry -> 19; a
gate weight fold -> 11; the legacy FZC body on R13 bytes refused); on the real capture the two table-free ones
fire (score precision -> 17; ceps -> 2) and six are not applicable. Records: `round19/v22/v22-*.json`; summary
`round19/R19_SUMMARY.json` (96e333e8…); C-13 per n `round19/C13_PER_N.json` (65bcae83…).

**Failing-first** [MEASURED]: frozen v21's pin rule refuses every round-19 capture (31 pins without a reading each);
frozen v21's whole gate on an R13 capture exits 1 (its classifier slots are not evaluated; it ends in a KeyError in
its controls instead of a written record: finding F19-G2); v22 refuses an r14, an R-C1 and an r14 short capture by
name. **D41** over the R13 item's two chunks: label 1 (the OR), no fail-closed reason; chunk 1 alone -> 1 with "chunks
[0] have no accepted proof"; a duplicated chunk -> 1 with "chunk 1 appears twice".

## 2. The captures

All under `~/zk60-artifacts/token-io/captures/`, made from the gate's capture tree
`ops/zkp-mvp/gate-tinyllama/capture-tree-r16b/` (a byte-equal copy of token frozen-r16b: 301 / 301 files, list
`04d94bc0…`) plus four TEST-ONLY gate patches (no prover or verifier byte moves; patches under `round19/cap/`):

| patch | file | what | why |
|---|---|---|---|
| H19-1 | `token_io/gate19_capture_tests.rs` (new) + one `#[path]` line in `classify_capture_tests.rs` (not a pin) | an R13-rung classifier capture hook with R-C2 DERIVED tables, L = 1 or 2 (two gate denominators), verdict 0 / 1 / tie, chunks, short items | frozen-r16b's hooks bind the legacy rung only; round 16's R13 rung test uses synthetic tables, which the replay refuses |
| H19-2 | the same file | the P-18 pattern on a REAL run directory: the CLI's own door, then the recorded verification | no hook took an existing real run |
| H19-3 | `plane_index.rs` 13a7dd6f -> ce79803c (a capture pin; `cfg(test)`) | at an R13 shape: `AccuracyIds`' plane names and the four R13 slots' whole-domain push orders | **no R13 capture can be recorded by frozen-r16b's recorder** (79 legacy names for 109 planes; the reading sub-lane's R19-PIN-1 too) |
| H19-4 | `run_capture.rs` cad25086 -> 8292b1c6 (a capture pin; `cfg(test)`) | `bundle_is_classify` = `is_classify_run_profile` | an R13-rung classifier bundle was written under the TOKEN schema without the classifier pins (F19-1) |

The recorder still cross-checks every slot's ACTUAL private-table order and the claim counts, so a wrong H19-3
list refuses the capture. The gate's pin rule reads H19-3 / H19-4 by name (`GATE19_PATCH_READINGS`).

The REAL capture's run (`round19/cap/r19_real.sh`, each step alone on the box) [MEASURED]: the named r16b binary
**dfb8025e…** proved round 16's 35-id ToxicChat post under `shieldstral-1.0-3b-moderate-sexual/1` (T128: P0 72 + n 35
+ S 1 = 108, **20 pad positions at id 11**, verdict row 107): 469.3 s, peak RSS 8.13 GiB, 848,412,096 B in 28
segments, floor 96 bits, verdict **not-flagged**; a fresh-process verify 74.6 s / 2.32 GiB (identity 29aeba6c…, input
root c8027b13…); the H19-2 capture 103.2 s / 4.05 GiB. One real prove in the round. The 13 R13-rung captures run at
Sol's `r13-h24-dense` fixture (the first attempts at `r13-h24-wide` were refused by the honest prover: §6, R19-1).

| capture | L | G per stage | verdict | n | pad positions | verdict row | bundle | made |
|---|---|---|---|---|---|---|---|---|
| classify-r13-rung-L1-v1 | 1 | [20] | 1 | 23 | 0 | 31 | 34 MB | H19-1, ~9 s, 0.53-0.56 GiB |
| classify-r13-rung-L2-v0 | 2 | [20, 21] | 0 | 23 | 0 | 31 | 54 MB | H19-1, ~9 s, 0.53-0.56 GiB |
| classify-r13-rung-L2-v0-short1 | 2 | [20, 21] | 0 | 1 | 22 | 9 | 54 MB | H19-1, ~9 s, 0.53-0.56 GiB |
| classify-r13-rung-L2-v0-short11 | 2 | [20, 21] | 0 | 11 | 12 | 19 | 54 MB | H19-1, ~9 s, 0.53-0.56 GiB |
| classify-r13-rung-L2-v1 | 2 | [20, 21] | 1 | 23 | 0 | 31 | 54 MB | H19-1, ~9 s, 0.53-0.56 GiB |
| classify-r13-rung-L2-v1-chunk0o27 (chunk 0/2 [0, 23) of 27) | 2 | [20, 21] | 1 | 23 | 0 | 31 | 54 MB | H19-1, ~9 s, 0.53-0.56 GiB |
| classify-r13-rung-L2-v1-chunk1o27 (chunk 1/2 [4, 27) of 27) | 2 | [20, 21] | 1 | 23 | 0 | 31 | 54 MB | H19-1, ~9 s, 0.53-0.56 GiB |
| classify-r13-rung-L2-v1-short1 | 2 | [20, 21] | 1 | 1 | 22 | 9 | 54 MB | H19-1, ~9 s, 0.53-0.56 GiB |
| classify-r13-rung-L2-v1-short11 | 2 | [20, 21] | 1 | 11 | 12 | 19 | 54 MB | H19-1, ~9 s, 0.53-0.56 GiB |
| classify-r13-rung-L2-v1-short22 | 2 | [20, 21] | 1 | 22 | 1 | 30 | 54 MB | H19-1, ~9 s, 0.53-0.56 GiB |
| classify-r13-rung-L2-vtie | 2 | [20, 21] | 0 | 23 | 0 | 31 | 54 MB | H19-1, ~9 s, 0.53-0.56 GiB |
| classify-r13-rung-L2-vtie-short1 | 2 | [20, 21] | 0 | 1 | 22 | 9 | 54 MB | H19-1, ~9 s, 0.53-0.56 GiB |
| classify-r13-rung-L2-vtie-short11 | 2 | [20, 21] | 0 | 11 | 12 | 19 | 54 MB | H19-1, ~9 s, 0.53-0.56 GiB |
| classify-r13-shield-t128-cli-sexual-r16b | 26 | 26 stages: 18 x1, 19 x7, 20 x18 | 0 | 35 | 20 | 107 | 951 MB | H19-2 on the named r16b binary's run; 103 s, 4.05 GiB |

## 3. Tools v22 (frozen 12:44:22 UTC)

* **Freeze.** `frozen_v22/`, manifest `gate-tinyllama.tools.frozen.v22.sha256`: 80 files,
  `ab7035965ef024ec6f7ec200deb6f17882983e7f43ea7a230ed5d887b8fc8027` (80 / 0 / 0). Patches: v21 -> v22 scripts
  `8526311f…` (181,981 B), tests `1ea79064…` (10,624 B); vs original `3d744e94…`.
* **Suite:** 98 OK in staging (56 s); **98 OK in the frozen snapshot** [MEASURED, 58.6 s, queue A] — 93 + 5 new (`ClassifierV22`); v21's three r14-capture tests now
  show v22 refusing r14 captures by name and run the rest under v21's rule.
* **What changed from v21:**
  * **Pins** (`classify_capture_pins_v22`): the five classifier files at r16b; the native R12b -> R13 and token
    r14 -> r16b readings (the reading sub-lane's `zk60_native_rg_r13_pins.py`, 119 digests self-checked); the
    gate's own H19-3 / H19-4 readings. 72 / 72 pins accepted on every round-19 capture; an r14 or R-C1 capture is
    refused by name.
  * **The R13 classifier profiles** (`zk60_native_rg_classify`): Shieldstral T128 / T256 and the test-only R13
    h24 rung; pad ids 11 / 2; overlaps 8 / 4; their R13 block profiles; **the registered Shieldstral policy list
    (D45(2))**: the three moderate category policies with the round-16 prefix digests (P0 72 / 72 / 78, suffix
    [4], yes 13059, no 2649, c 0, pad 11, ctl < 1000, V 131072, margin scale bits 0x3ed11ff597db2fb6); the card
    policy refused by name.
  * **R13 integrity** (`classgate`): the block profile; ONE "R13 gate denominator G" per block stage line, G in
    [17, 24], none at a legacy profile.
  * **B-3 at the real profile** (`classtied`): the gate derives the margin row and the embedding from the pinned
    checkpoint itself (a numpy port of native R12b `recompute_profile`: the whole-file SHA-256 = the model pin
    87753e30…, the tensor pin 67a138c1…, the block-Hadamard 3 x 1024 rotation with the export's signs, f32
    rounding, floor(x / s + 0.5), no clip), STREAMING one 1,024-row chunk at a time; tau is rebuilt by an exact
    numpy fold. It reproduces the round-16 real statement's `embedding_digest` 1cb276d1… and
    `margin_vector_digest` 6429a242… bit for bit [MEASURED].
  * **Captures recorded with public tables as length + digest** (the real one): every IN-C / OUT-C table is
    REBUILT and compared with the capture's digest (nothing taken); a missing value is still refused unless the
    capture declares the option.
  * **The R13 block stages** (`zk60_native_rg_r13blocks` / `_r13slots`, the block-port sub-lane): the seven
    R13-redefined slots (DZC, QZC, KVZC, SZC, FZC, TAB; DD refused by name) ported from `argument_accuracy.rs`,
    the 16 legacy bodies with the multiplier folds, the R13 plane list rebuilt independently, the R13 lookups,
    each stage's G and constants from the stage lines bound by recomputing the classifier schedule digest; seven
    R13 controls.
  * **Declared limits** in a record (`declared_limits`, status `PASS-WITH-DECLARED-LIMITS`): block slots that
    need a captured table, open by the capture option; a full preimage on a declared sample.

## 4. The [READ] list (reading sub-lane, `round19/readings/`, my spot check of argument.rs)

* Module `staging_v22/scripts/zk60_native_rg_r13_pins.py` (838f60e8…, `self_check()` re-hashes 119 digests),
  `round19/readings/R13_READINGS.json` (e8708b6a…), 50 diffs. Trees: native R12b (51de5b83…) -> R13 (bb9eb212…);
  token frozen-r14 -> r15 -> r16 -> r16b (04d94bc0…).
* **No step moves a receipt, block-stage or public-statement byte at a profile the gate captured before**
  (TinyLlama T32 block / token, the rung block profiles, the token rung, the legacy classifier rung). Every R13
  change is gated by the accuracy stack (`accuracy_stack() != Legacy`), by a new profile name, or is test-only.
  I re-read argument.rs's five hunks myself: confirmed.
* An r16b classifier bundle pins 72 files: the old 60 plus the 12 R13 modules. trained_accuracy.rs differs from
  native R13's only in a `#[cfg(test)]` fixture-path line.
* Unchanged: the statement schema `zk60-classify-run/3` (38 keys), stage_in_c.rs / stage_out_c.rs, the capture
  allow-list. run.json's `shape` carries NO accuracy field (the stack, G and precision are derived and bound
  through the schedule digest).

| file | digest chain (r16b -> ... -> read before) | diff | classification | moves a byte at a captured profile |
|---|---|---|---|---|
| src/private_block.rs | 2af1df7d -> 29540958 | +62 / -1 | gated-on-new-profiles | no |
| accuracy.rs | 2996ff41 -> NEW | NEW at native R13 (read in full for the gate's purpose: entry points and their callers) | new-file | no |
| accuracy_act.rs | 7ef5fe26 -> NEW | NEW at native R13 (read in full for the gate's purpose: entry points and their callers) | new-file | no |
| accuracy_aligned.rs | 396d0cf2 -> NEW | NEW at native R13 (read in full for the gate's purpose: entry points and their callers) | new-file | no |
| accuracy_fold.rs | 53e2b572 -> NEW | NEW at native R13 (read in full for the gate's purpose: entry points and their callers) | new-file | no |
| accuracy_groups.rs | 63a87749 -> NEW | NEW at native R13 (read in full for the gate's purpose: entry points and their callers) | new-file | no |
| accuracy_layout.rs | 37a3e345 -> NEW | NEW at native R13 (read in full for the gate's purpose: entry points and their callers) | new-file | no |
| accuracy_precision.rs | 145c1e0f -> NEW | NEW at native R13 (read in full for the gate's purpose: entry points and their callers) | new-file | no |
| accuracy_public.rs | 0b44bf54 -> NEW | NEW at native R13 (read in full for the gate's purpose: entry points and their callers) | new-file | no |
| accuracy_tables.rs | 0a92b7ff -> NEW | NEW at native R13 (read in full for the gate's purpose: entry points and their callers) | new-file | no |
| argument.rs | bc0332e3 -> c4f9f9f4 | +27 / -2 | gated-on-new-profiles | no |
| argument_accuracy.rs | a5e02391 -> NEW | NEW at native R13 (read in full for the gate's purpose: entry points and their callers) | new-file | no |
| layout.rs | 8519a514 -> 9332802e | +32 / -3 | gated-on-new-profiles | no |
| protocol.rs | 10114414 -> c4824023 | +38 / -15 | gated-on-new-profiles | no |
| run.rs | 3dc5393d -> 51e8aed2 | +133 / -13 | gated-on-new-profiles | no |
| run_capture.rs | cad25086 -> 527df40e -> ef9c54db | +15 / -1 | test-only | no |
| shape.rs | 8e00a144 -> 9a870818 | +123 / -5 | gated-on-new-profiles | no |
| tied_tables.rs | 45fc3f0f -> 049ddc18 | +3 / -1 | gated-on-new-profiles | no |
| tied_tables/derive.rs | c5bec3c6 -> 5cebeef0 | +10 / -1 | gated-on-new-profiles | no |
| token_io.rs | 2aabe64f -> 3808d844 -> eda64c31 | +3 / -0 | test-only | no |
| token_io/classify.rs | c180c83f -> c23074e9 -> 6c828db6 | +21 / -7 | gated-on-new-profiles | no |
| token_io/classify_run.rs | 8abbf72f -> 5d1d077f | +15 / -1 | gated-on-new-profiles | no |
| token_io/classify_tied.rs | a89acfab -> 401d38d4 | +39 / -3 | gated-on-new-profiles | no |
| token_io/load.rs | 67307f09 -> a9b72811 | +13 / -2 | identity-at-captured-profiles | no |
| token_io/run.rs | aae4b0ab -> 477cfc8c | +42 / -3 | gated-on-new-profiles | no |
| trained_accuracy.rs | f47b1084 -> NEW | NEW at native R13 (read in full for the gate's purpose: entry points and their callers) | new-file | no |
| trained_block.rs | dc6e8772 -> f892dbc7 | +167 / -43 | gated-on-new-profiles | no |
| trained_statement.rs | f6be924c -> 7908d827 | +123 / -7 | gated-on-new-profiles | no |
| witness.rs | 7620447c -> a586b777 | +37 / -7 | identity-at-captured-profiles | no |
| witness_accuracy.rs | 8b03abad -> NEW | NEW at native R13 (read in full for the gate's purpose: entry points and their callers) | new-file | no |

## 5. C-13 at pad 11, short items, cross-verdict

[MEASURED / COUNTED, `round19/C13_PER_N.json`]

* **Cross-verdict:** the randomness-free figures (replay counts, slot checks, rebuilt / taken tables, block slots, the
  per-commitment table, the joint figure, NL-1, the CFS entries) are equal for v0 / v1 / tie at L 2 full length and at
  each of n = 1, 11 and 22.
* **Short vs full** (six pairs at L 2): figures and per-commitment disclosure equal; the run facts differ only in n,
  the chunk, the profile text's length words (n, item-length, pad-positions, verdict-row), the profile digest and the
  run-random input root. Nothing beyond the public length differs (D45(1)).
* **C-13 per n** (the input endpoint's captured or rebuilt pi / kappa): known words 31 / 21 / 10 / 9 at the rung for
  n = 1 / 11 / 22 / 23, and **93 at the real item** (template 73 + pad 20; hidden 35); the joint figure 0 over the
  hidden and the known words at every n; B_out's OUTC-00 claim at rows 9 / 19 / 30 / 31 and **107**, the only B_out
  claim with fixed row bits (5 at T 32, 7 at T 128); the block shape identical at every n at the rung (T = t_pad);
  segment bytes independent of n (rung 1,224,328 / 15,420,264 / 3,228,344; real 1,415,192 / 32,450,184 x 26 /
  3,292,120).
* **C13-1..C13-4 fire at pad id 11** on the real capture (a doctored pad position, a pad inside the content range, a
  shifted verdict row, a declared length that is not the actual one), and on every rung short item at pad id 2.
* **The published `/3` statement of the real run**: 38 keys, all classified; item_length = P0 + n + S, pad_positions =
  T - item_length, verdict_row = item_length - 1, pad_id = the registered policy's 11.
* **At n = 1 the public verdict is a function of one hidden id** (at Shieldstral one of 130,072 non-control ids):
  D45(1) / (2) accept this; the statement must say it in plain words.

## 6. Refusals: the recount, and which refusals depend on hidden content

**(a) The input-dependent LogUp refusal term (D34 / D40) at R13** [COUNTED, `round19/refusal/refusal_recount.py`,
`R19_REFUSAL_RECOUNT.json`]. Formula: 2 (sum over blocks of T_d + T + 256) / p^2, with T_d the rows of the tables
a hidden query can hit in one block: U8 256 (every byte limb and every exact top-bit pin of R13's widened words and
remainders queries the same byte table) + EXP 256 + **ACT3 4096 x groups** (legacy: 256). Stage IN-C inverts at
most T distinct tau rows; stage OUT-C at most 256 byte values.

| profile | T_d per block | term |
|---|---|---|
| **Shieldstral T128, R13, L 26** (groups at the class maximum 4) | 16,896 | **2^-108.25** |
| the same, with the T128 export's actual 3-4 groups per layer | 12,800-16,896 | 2^-108.42 |
| Shieldstral T256, R13, L 26 | 16,896 | 2^-108.25 |
| D40 as accepted (legacy shape, L 26, T <= 512) | 768 | 2^-112.66 |
| R13 h24 rung, L 1 / L 2 (T 32) | 16,896 | 2^-112.93 / 2^-111.94 |

The R13 SiLU tuple table costs 4.4 bits against D40. **D40's 2^-112.7 must be replaced by 2^-108.25 in any
classifier statement at the R13 Shieldstral profiles.** The pad rows add no distinct value: in IN-C a pad
position's query is pinned to the public pad id 11; in the blocks the pad rows are ordinary hidden rows whose
queries fall in the same tables (the count is over table rows, not positions). Table-side inversions are of public
values (challenge-only).

**(b) Which refusals depend on hidden content** (plain words):

* **The LogUp zero-denominator event above**: depends on the challenges AND on which values the hidden content
  makes the prover invert. Priced as a distance, 2^-108.25 per run.
* **Prover-side range refusals before the header** (the "oracle range refusals" of the witness builders): the R13
  norm word outside int16, the widened words (y, nm, q, k, v, qr, kr, o) outside [-32768, 32767], the score
  outside [-127, 127], the gate word outside [-2048, 2047], the h24 product, the residual words, the norm and
  softmax denominators and remainder windows. These are deterministic functions
  of the hidden content (no challenge): **whether an item proves at all depends on what it says.** Measured this
  round (R19-1): at Sol's `r13-h24-wide` calibration (Cn 10000) an honest item is refused whenever it contains one
  of **102 of the 300** vocabulary ids; Cn 4000 refuses none. The **pad rows** are hidden rows of every block too
  (their activations depend on the content through causal attention), so they can trip the same refusals.
  Round 16's real 35-id post and this round's prove of it had none. Under D29's reading these refusals come
  before any header (no proof, no verifier view); under D45(4) the app shows "could not be verified". The
  statement must count the refusal FACT as a function of the hidden content (including the pad rows); no
  transcript term arises from it.
* **The CLI's door and sealing pass**: content with a control id (< 1000) at a content position, an item longer
  than the plan (split by D41 instead), activations that do not match the export (REVIEW_R16 §8: completeness,
  never soundness). The first is content-dependent (a public rule); the last is only reached by a wrong prover.
* **Not content-dependent**: the policy / profile / identity doors, the floor check (`--min-bits`), the D41
  coverage check, the fail-closed label rule.

## 7. Findings and notes

* **R19-PIN-1 / H19-3 (token lane and native, test recorder): frozen-r16b's recorder cannot record any R13 capture.**
  `plane_index.rs` (13a7dd6f, `cfg(test)`, unchanged since R12b) names A planes from the legacy table (79 names for
  109 planes at LOW + h24) and its DZC / FZC push ranges are short at R13. Found by the capture run and by the
  reading sub-lane independently. The gate's H19-3 is a candidate fix to adopt.
* **F19-1 (token lane, test recorder):** `run_capture::bundle_is_classify` tests the three production classifier
  profiles, so a bundle of the test-only R13 rung profile was written under the TOKEN schema without the five
  classifier pins. H19-4 (`is_classify_run_profile`) to adopt.
* **H19-1 / H19-2 to adopt:** an R13-rung capture hook with derived tables and two gate denominators, and a hook that
  records a REAL run directory through the CLI's own door (the P-18 pattern), so that later rounds capture from a
  frozen token tree without gate patches.
* **R19-1 (refusal channel, completeness):** at Sol's `r13-h24-wide` (Cn 10000) the honest prover refuses any item
  containing one of 102 of the 300 dev ids (§6). A content-dependent refusal set exists at every R13 profile.
* **O19-1 (generic-honest-witness note):** at the R13 rung the margin is EXACTLY -228,712 for every item (n = 1,
  11, 22, 23 and both chunks): the rung's verdict does not depend on the content at all. The gate's figures do not
  rely on it; only the real capture is content-dependent this round.
* **F19-G1 (the gate's own tools):** two v22 modules find the repository root at a fixed depth of five parent
  directories (true in `frozen_v22/` and `staging_v22/`, not in the working copy `ops/zkp-mvp/gate-tinyllama/`).
  v22 runs from `frozen_v22/` only; the working copy stays at v21 (77 / 0 / 0). Fix for v23: search upward.
* **F19-G2 (the gate's own tools, v21 and v22):** when a capture's pins are refused, the classifier-slot check returns
  without a `B3_margin_vector` member and `class_controls` then raises KeyError: the run still exits 1 (fail
  closed), but by a crash rather than a written refusal. Fix for v23: refuse by name before the controls.
* **Lean-rule incidents (mine):** my first real-capture dev run was declared light 3.3 / 5 and was killed by the
  guard at 5.20 GiB (11:59); the coordinator's rule since then: the real capture's analysis is cpu class, >= 6.5 /
  8, alone. The block-port sub-lane's light 2.5 job overlapped my cpu 6.5 job for 27 s (12:01:31, peak 1.38 GiB;
  launched from an earlier idle status read). My first capture queue ran 13 failing captures in 3 s before I
  stopped it at the first failure.
* **Not ported / not checked (declared):** the DD twins of SZC / DD (a DD bundle is refused by name; no DD classifier
  profile is registered); the ACT3 table only for structure (a capture carries no SiLU group members); on the real
  capture the 12 block slots that need captured tables, and the full preimage outside the declared sample.

## 8. What a classifier privacy statement draft still needs

Not drafted in this round (brief). What is still owed before a Shieldstral classifier privacy statement can be
proposed, in order:

1. **The statement text** (the D36 analogue for one classifier run at `…shieldstral-3b-t128-r13-public-row/1`):
   * hidden: the content ids at positions P0 .. P0 + n - 1, their embedding rows, every activation and the 26
     inter-block planes (pad rows included), the final-norm values, the margin and its limbs;
   * public: the verdict bit; n, the item length, pad id 11 and the pad positions, the verdict row (D45(1)); the
     chunk index / count / range / total (D41: per-chunk bits public); the policy id from the fixed list of
     three, its template ids, c, yes / no, the margin-vector digest; the model identity (trained statement
     identity 29aeba6c…, the export profile, the per-layer gate denominators); the tied source; the input
     endpoint root (D45(3)); the whole-run floor (96 bits);
   * the refusal channel of §6 with the **2^-108.25** term and the content-dependent range refusals (pad rows
     included), in plain words; the small-n sentence (at n = 1 the verdict is a function of one hidden id, one
     of 130,072 non-control ids at Shieldstral); the fail-closed rule.
2. **The per-run distance figure at the Shieldstral R13 shape** (the analogue of D36's 2^-70.35 at L 22): the
   blinding-law residuals (the G-R4 class) recounted over 26 R13 blocks (more A rows and claims per block, 107 A
   planes) and the IN-C / OUT-C draws. Not computed.
3. **Evidence the gate still owes on the real capture:**
   * the full zero-data preimage on the 23 real blocks not in the declared sample (~3.2 h of a 7 GiB heavy job;
     the 3 sampled blocks and both stages: 0 differing);
   * the block-slot terminal identity on the slots that need captured tables (5-7, 10-16, 18, 19) at the REAL
     shape: a capture with table values (~4 GB of tables, a ~7-8 GiB recorder) or a table-free evaluation of the
     weight folds from the export; at the R13 rung they hold 23 / 23 with tables;
   * the ACT3 table against the SiLU generator (only its structure is checked; a capture carries no group
     members).
4. **Owner checks**: the input owner's check on the gate's real run PASSED this round (the named binary's
   `input-owner`, fresh process: `content-checked`, content_total 35, range [0, 35); 77.6 s, 2.29 GiB). Still owed:
   a gate-side owner record on short items at other n, and the delivery of the opening D45(3) keeps with the app.
5. **Scope rulings and lanes**: Victor's strict / moderate wording ruling (the registered list is the moderate
   one, flagged); T256 is registered but not proved and has no published identity (N-r16-5); the token lane
   adopting H19-1..H19-4 (F19-1) so that later rounds capture from a frozen tree without gate patches; the
   independent check of round 16b.
6. **An independent privacy review round** on the draft (as REVIEW4-6 for D33 / D36).
7. **The security owner's sign-off and Victor's acceptance.** No lane can claim a privacy acceptance.
