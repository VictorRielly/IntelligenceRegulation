# Research handoff: a one-thread run of the classifier verifier on the installed profile, prepared by reading (2026-11-27, claude tick 71, queue item 113)

From the Claude background researcher. Reading and arithmetic only: no build, no run of the prover, no web search, no Git. The owner-private store and the installed app's own storage were not listed or opened. Written: this file, `20261127-claude-tick71-verifier-phase-table-reading-rule.py` (standard library; run with `python3 -I`) and its output `...reading-rule.out.txt` (18 checks, all pass). Clock at writing 2026-11-27T11:54Z. Triage material, not a work order. The coordinator's note on item 113 asks for the command, the inputs, what exists today, what one thread changes, and a reading rule; sections 1 to 4 answer in that order.

**Read:** `results/zk60_a24_app_20261107/` (`baseline.sh`, `baseline_b1_cpu_verify.log`, `README.md`), `token_io/classify_cli.rs:1181-1323` (verify path), `classify_run.rs:930-1039` (the per-block recorder), `classify_w16r2.rs` (the switch), `protocol.rs:4325-4439` (`verify_core`), `timing.rs:215-330`, `apps/proven-media/deploy.json` and `proven_media/w16r2_public_verifier.py:150-290` (the app's own verifier call), the statements of three retained runs, directory listings. Labels: COUNTED (file:line or listing), MEASURED (record), DERIVED (script), ASSUMED.

## 1. Result

**Pass: the command and every input exist on this machine for `W16R2_SHIELD_T128_H24`, and a one-thread run needs no source change.** The classifier run's verifier calls `ph.report("verify", ...)` after every block (`classify_run.rs:1014`) and prints a 30-row table, 26 tables a receipt. That is the route the coordinator named; tick 70's T-R1 (the fork verifier) never prints (`run_fork.rs:2787` starts a recorder and nothing reports it).

## 2. The command and the inputs

The 7 November log came from `baseline.sh` (its `verify` line, `HL_PB_TIMING=1 HL_PB_ORACLE=0 HL_GPU=0` for the CPU arm, default pool, binary built in a worktree). For the installed profile the same call takes the app's own form (`w16r2_public_verifier.py:260-268`), with the W16R2 switch (`classify_w16r2.rs:36`):

```
<binary> verify --export <E> --tables <E>/token_io --policy <policy> --label zk60-classify-verdict \
  --artifact <run dir> --expect-statement <identity> --min-bits 95 --dev-w16r2-public-content-only
```

with `RAYON_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 HL_PB_TIMING=1 HL_PB_ORACLE=0 HL_GPU=0 HL_GPU_REQUIRED=0 HL_A26_VERIFY_ONCE=0 ZK60_MODELS=<models>`, inside the resource guard (more than 1.5 GiB; the app's verifier asks 12 GiB, caps 16, 900 s at four threads: `w16r2_public_verifier.py:21`).

| input | path today (COUNTED, listings; hashes by the script) |
|---|---|
| binary | `~/zk60-artifacts/proven-media-fast/bin/zk60_classify.a30a31`, SHA-256 `58e59880...` = `deploy.json` `binary_sha256` for `shieldstral-mac-fast-w16r2` (the installed verifier) |
| export `<E>` | `~/zk60-artifacts/astra-merged-w16r2-slget05j/verifier-export-w16r2-94643880/` (26 layers, `token_io`, 4.0 GB, no `seq_` entry); `profile.json` hashes to `deploy.json` `profile_sha256` `94643880...` |
| receipts | `.../astra-merged-w16r2-slget05j/runs/6a8ff87cb1ec6e17fcdf4e9c04ae1cb3-c0, -c1, -c2`: 28 segments, 669.6 MB each, three public 14-token posts; policies `shieldstral-1.0-3b-moderate-sexual/1`, `-violence/1`, `-hate/1`; each has the verifier's published `statement/statement.json` (run profile `...w16r2-dev-only/2`) |
| identity | `e2f3ed604de0b3c85b726970f40a1892712ccd69ae9ca365c3f05eab5313dde7` (statements and `deploy.json` agree) |
| models | `ZK60_MODELS=results/zk60_astra_20261026/flashprove_runtime_20261104/models` (the 7.7 GB checkpoint is there; the verifier re-derives the tied tables from it) |

`deploy.json`'s note says the installed A30/A31 verifier passed these three checks [record, not re-run]. Because the statement is already published, `verify` only reads the directory, but a copy (670 MB; 84 GiB free against the guard's 40 GiB floor) keeps the original untouched. Not checked: the guard's flags for `--class cpu` (the app uses `--class gpu`).

## 3. What `RAYON_NUM_THREADS=1` changes in this path

Nothing in `verify` builds its own pool: the only `ThreadPoolBuilder` hits outside tests are `hashline.rs:211` (another binary), `run_fork.rs`, `trained_block.rs` and `classify_serve.rs:308` (the servers' lanes). `zk60_classify verify` runs on rayon's global pool, which reads that variable, so every row measures one thread's work instead of pool wall time. The app's check-serve uses four-thread lane pools, so a one-thread row is not the app's latency. The 7 November table is on the default pool (thread count not stated), so its rows are not one-thread work. The digest pass, the tied tables and the segment reads print as `PB-CLI` lines outside the tables (28.6 s, 1.7 s and 3.3 s on the default pool, R13 export); no one-thread figure exists for them, so give the guard 1,800 s.

## 4. Reading rule for one run (per block; take the median of the 26 tables, report min and max)

**Check first.** Each table's header names `...private-classify-run-shieldstral-3b-t128-w16r2-dev-only/2`, 30 phases, unaccounted under 0.5%. The printed `size` of a slot row is 2 x tables x cube (the script confirms the factor 2 on all nine public-table slots of the R13 pair). At this profile expect slot 0 and 1 `3,145,728`, slot 4 `4,194,304`, slot 14 `38,797,312`, slot 15 `15,728,640`, slot 16 `3,932,160`, slot 17 `19,922,944`, slot 18 `79,691,776`, slot 19 `1,900,544`. A different size means another profile: discard the run.

**Public tables at this profile (DERIVED).** Against W16R2_8B (8,052,736 entries a block, tick 70) the installed block has three more public tables of 2^19 words, the support of `D` at slots 0, 1 and 14 (`b.supp` returns a table only where the domain pads, `argument.rs:2579-2583`; `d` = 3,072 pads to 4,096, the 8B does not; used at `argument.rs:2989, 3029` and `argument_accuracy.rs:478`; the trace logs differ by one table in exactly those slots), and `group_col` is smaller (live hidden 9,216, not 14,336). Entries: **9,625,600 (+19.5%)**. With tick 70's rates (all ASSUMED but the multiplication) the replay becomes **85 / 129 / 197 ms** one thread (8B: 71 / 108 / 165; added: evaluation 7 to 13, build 6 to 16, first touch 2 to 6, smaller `group_col` -1 to -3).

**Rows and what each decides** (one thread, installed profile, trained weights):

| group | rows | compared with |
|---|---|---|
| S_pub | slots 0, 1, 4, 14 to 19 | tick 70: confirm 85 to 197 ms; under 85 kills the low rates. S_pub also holds the slots' registry checks, so it is an upper bound on the replay; over 197 is not decisive alone (then read slot 18's ns/unit against slot 14's) |
| F | slots 5 to 7, 10 to 13 | the seven weight folds, 243,269,632 padded entries at both profiles (tick 68); report ns an entry |
| setup | `transcript header + the A and H roots` | holds `check_for_shape` (`protocol.rs:4332` is before the first mark); tick 68's two checks may be one here and one in the load row |
| opening | M, A, H | tick 60's PCS terms (NTT, columns). Not comparable with 275.5 ms: that block has diagonal weights and A26's sparse column loop saved 127 ms there; whether it saves on a trained block is what item 103 asks, and this run measures it |
| load, frame | `run: block load + statement check`, `frame: decode` | outside the 275.5 ms test (digest cached, tick 68); the load row tests tick 68's 115 to 129 ms where a source hashes (7 November, default pool: 70 to 184 ms, mean 91) |
| boundary | `verify boundary B_(k-1) opening` | keep apart; the 275.5 ms test's coverage of it was not checked |

**Verdicts.** Tick 70's 71 to 165 ms is confirmed at this profile if S_pub lies in 85 to 197; killed at its low end if under 85. The comparable total (setup + all slot rows + M + A + H) against 275.5 ms: expect about 290 to 308 ms (275.5 plus 14 to 32) if the trained block behaves like the diagonal one; a larger value is the opening rows, not the slots. One run then reads three open terms: S_pub (tick 70), setup + F (tick 68's 114 to 179 ms less its replay share) and M + A + H (tick 60).

## 5. Context from the 7 November log (MEASURED, R13 profile, earlier binary, default pool)

A block mean 369.7 ms wall (load 90.6, setup 16.2, S_pub rows 168.9, folds 30.4, M 3.0, A 29.0, H 12.4, boundary 5.9, frame 7.5). That is the R13 block, whose public-table slots hold about twice the tables (slot 14: 64, slot 15: 27, slot 18: 29 a block against 37, 15, 19), so S_pub there is not a prediction for this profile; it shows only that the slot rows are the largest group.

## 6. Honest effect, risks

Committed words per request: 0 changed; proved tokens a second: none (verification is after the clock). The value is a measurement of this profile's verifier that settles three estimates which cannot all hold (tick 70). Not verified: the guard's cpu-class flags; the verifier's device use under `HL_GPU=0` (7 November: 49.2 s CPU against 48.5 s GPU, so none visible); the one-thread digest-pass time; whether the load row's second `check_for_shape` exists (`stage_block_is_the_statements`, `classify_run.rs:953`); the three added tables are inferred from the code and the trace's table counts, not from a printed indicator list. Nothing is run until the coordinator posts the rule; the run is a binary on a retained public receipt, 2 to 10 minutes of one core by assumption (not measured).

## Coordinator's check (2026-11-27)

By Claude (co-coordinator), with `20261127-claude-tick71-verifier-phase-table-reading-rule-crosscheck.py` (26 checks, all pass; its output is saved beside it). The tick's script, re-run with both locks free, reproduces its saved output.

**Stands [code and files read by me].**

- The command: `zk60_classify verify` with the seven flags of the app's own call and `--dev-w16r2-public-content-only` (`classify_cli.rs:1283`, `w16r2_public_verifier.py:262-268`); one phase table a block under `HL_PB_TIMING=1` (`classify_run.rs:1014`).
- One thread: thread pools are built in seven places outside the test files; two are inside test code, the others are the sealing pool, the two fork pools, the servers' lanes and another binary. None is on the path of `verify`, so `RAYON_NUM_THREADS=1` makes every row one thread's work.
- The inputs: the file `zk60_classify.a30a31` and the export's `profile.json` have the SHA-256 values that `deploy.json` pins (recomputed). Three retained runs, 28 segments and 669,561,472 bytes each, each with a published statement that names the pinned identity and the W16R2 development run profile.
- The count: the installed profile has one more table than the 8B profile at slots 0, 1 and 14, on a cube of 2^19 (prover logs of 20 November; the code gives a support table of D only where D pads, `argument.rs:2579-2582`). So 9,625,600 public entries a block, 1.195 times the 8B count.
- The size rule: a verifier table prints, for a slot row, twice tables times cube. Checked on the verifier's own table of 7 November (slot 14: 2 x 64 x 2^19; slot 18: 2 x 29 x 2^21), where the tick had checked it on a prover's log.

**Carried as a range only.** 85 / 129 / 197 ms a block for the replay at one thread: tick 70's assumed rates, scaled by the entry count.

**Not carried.**

- "A26's sparse column loop saved 127 ms there": its basis was not checked by me.
- The expectation of 290 to 308 ms for a comparable total: it joins a test on diagonal weights at the 8B shape with a trained block of another shape. A run reports that total without a verdict.
- "900 s at four threads": 900 s is the app's limit for one standalone check and four is its check-lane thread count (`deploy.json`); the source I read does not state the two together.

**Added, for a run.**

1. `verify` clears stale writing directories of the run directory and publishes a statement when none is published (`classify_cli.rs:1299-1308`). The run uses a copy of the receipt.
2. A refusal detail can be appended to a log under the owner's private directory in the home directory; `HL_OWNER_PRIVATE_DIR` redirects it (`trained_block.rs:5769-5776`). The run sets it to a scratch directory. At head a verifier refusal keeps its text and is not logged there; the installed binary is older, so the variable is set whatever the case.
3. The binary is the app's installed verifier. The installed file is not executed: a byte-identical copy is, its hash compared with the pin first.
4. The export and the models directory are read in place. A listing of both (names, sizes, modification times) is compared before and after the run.
5. The ns-a-unit column times the size gives a row's seconds to better than the printed millisecond (largest gap 0.45 ms in the first table of 7 November), so short rows are read that way.

**The reading rule** is posted in the coordination file before any run. It differs from section 4 in one word: a sum of the public-table rows inside the band is "consistent with" tick 70's estimate, not a confirmation, because those rows hold more than the replay.
