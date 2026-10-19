# D24 review, round 7: verdict on the native R7 tree

Written 2026-10-19 (10:24 UTC) by the independent review lane. This is not a
privacy review: only Victor rules on privacy.

**What I reviewed**

- **Source.** My frozen copy `ops/zkp-mvp/trained-1b-review-r7/` of the
  R7 freeze (2026-10-19T09:58:29Z, tree hash 36a8aed1...).
- **Integrity of the copy.** `ops/zkp-mvp/trained-1b-review-r7.sha256`
  (219 entries) matches `r7/manifest_frozen.json` file for file. The tree
  hash recomputes, and the copy was unchanged after every run.
- **Diff.** I read every hunk of `r6-vs-r7.patch` (331 lines, the same as
  the author's). It touches two files: `trained_block.rs` and
  `trained_stack_tests.rs`.
- **Binary.** I built my own CLI from the untouched frozen copy:
  `r7/zk60_trained_block.review-r7.release.bin`, sha256 539450e6....
- **Log.** `PROGRESS.md`, section ROUND 7.

All measurements below come from a shared box, one run each [MEASURED].

## Verdict

**R7 is ACCEPTED on soundness.**

- **What the diff touches.** Only statement writing and publication, plus
  a cleanup step that runs before `stack-verify` lists the run directory.
  No proof, transcript, loader or relation code changes, so nothing in it
  can make a verifier accept something false.
- **N-r6-b (stale `statement.writing-<pid>`) is CLOSED.** Every attack I
  tried was either refused by name with the entry left in place, or was a
  dead verifier's directory that got removed without publishing anything.
- **Q-2 (backend allow-list) holds.**
  - `prover_reported.backend` must be exactly one of three build constants.
  - `gpu_declines` must be 0 on the CPU path and at most 4096 with the
    device.
  - Both prover sides check before writing, and the verifier checks before
    publishing.
  - No refusal echoes the backend text. One small exception concerns a
    number, not text (note N-r7-b).
- **R6 CPU statements stay valid under R7.** Two R6-published statements,
  both written by `stack-verify`, byte-check under R7:
  - my rung run (identity 72098637...);
  - the native lane's 32-block Llama-3-8B T128 b7 stack (identity
    97c4acda...; verified again, then "statement-checked").

  R5b's schema-`/1` statements were already refused by R6, so R7 changes
  nothing for them. Every schema-`/2` statement in the repo carries the CPU
  constant.

## 1. N-r6-b: `clear_stale_writing_dirs`

**What the code does.** The function is called after the identity pin and
the context, before the run directory is listed. It handles each entry
named `statement.writing-<rest>` as follows:

- `<rest>` must be non-empty ASCII digits parsing as a u32;
- the entry must be a real directory, never a link;
- `/proc/<pid>` must be absent;
- the directory may hold only `expected.bin`, `statement.json` and
  `segments.json`, each a regular file.

If all four hold, the directory is removed with `remove_dir_all`. Otherwise
the verifier refuses by name, says what to do, and leaves the entry alone.
The directory's contents are never read or published.

**Attacks** (`review_r7_inner::r7_1`, `r7/r7-fast.log`):

| attack | result |
|---|---|
| live pid (the test process), and pid 1 (pid reuse or a foreign live process) | refused ("process N is alive ... or the pid was reused"); kept |
| a symlink to an outside directory; a regular file | refused ("not a real directory ... never followed"); kept; outside untouched |
| an extra file; a renamed file (`statement.jso`); a subdirectory named `statement.json`; `expected.bin` as a symlink to an outside file; `expected.bin` as a FIFO | each refused ("holds `X`, which this verifier never writes"); kept; outside untouched |
| names `abc`, `+123`, empty, `12a`, ` 12`, `0x10`, `99999999999` (u32 overflow), `-5`, `1.0`, Arabic-Indic digits | each refused ("not a statement directory this verifier writes"); kept |
| dead pid (above pid_max) with FORGED contents under the three names; dead pid with an empty directory; dead pid with leading zeros | removed; nothing read or published |
| race: 200 runs with a racer planting a link to an outside file inside the stale directory, and 200 runs with a racer swapping the stale directory for a link to an outside directory, both during the cleanup | removed 63, refused 337; the outside file and directory survived all 400 runs |

The same behaviour holds at the CLI, with my binary:

- **Dead pid with forged files.** A copy of my R6-published rung run, plus
  a stale `statement.writing-4999999` holding forged files: the directory
  was removed ("stale-statement-writing-removed"), the run verified, and
  its existing `statement/` passed the byte check.
- **Live pid.** The same run with `statement.writing-1`: refused by name.
  The entry was kept, and nothing else was read.

**How removal interacts with other writers.** A removal publishes nothing.
A writer whose temporary directory disappears fails its own rename, so it
also publishes nothing. A race with a live writer in the same pid namespace
is refused, because its pid is alive.

## 2. Q-2: the backend allow-list

**What the code does.**

- `BACKENDS` contains three constants:
  - `BACKEND_CPU_BUILD`, byte for byte what R5b and R6 CPU builds wrote;
  - the cuda build with its device path not live;
  - the cuda build with its device path live.
- `backend_of_this_process()` picks one from the build features and
  `gpu::enabled()` only. The device's own description stays on prover
  stdout.
- `check_prover_reported` runs in three places:
  - in the block prover before it writes `statement.json`;
  - in the stack prover before it writes either statement (a failure
    removes the run directory);
  - in `ProverClaims::of_statement`, before any publication and before the
    byte check that follows.

**Attacks** (`review_r7_inner::r7_2`):

- **The check by itself, 13 cases.**
  - Admitted: the three names exactly, with 0 declines; the device name
    with 4096 declines.
  - Refused: 4097 declines; 1 decline on the CPU build; 5 declines on the
    cuda build's CPU path; upper case; a leading or trailing space; a
    trailing NUL; a Cyrillic lookalike `о`; the R6 device label
    ("gpu: ON — NVIDIA GeForce RTX 4070 ..."); an empty string.
  - No refusal contains the prover's text.
- **End to end**, on an R7 prover's unverified statement edited before
  `stack-verify`. Each of these was refused, nothing was published, and
  the backend text was not echoed:
  - upper case;
  - a trailing space inside the value;
  - a JSON escape of an allowed value (`off`, refused by the byte
    check);
  - the R6 device label;
  - free text ("request-42 user=alice");
  - 1 decline on the CPU build;
  - declines written as `0.0`, as `-0`, or as a 61-digit numeral. The last
    one's refusal echoes the numeral (N-r7-b).
- **A lie within the rules.** A CPU prover that names the device-live
  constant is accepted, and that name is published under `prover_reported`.
  This is a self-report a verifier cannot check, now limited to three fixed
  names (N-r7-c).

The author's tests `privacy_q2_the_published_backend_is_one_of_the_builds_names`
and `review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`
pass in my run. Full result of their targeted subset: 48 passed, 0 failed,
1 ignored, including `review_r5_3` and the per-layer `sh_s` stack test.

## 3. R5b and R6 statements; the rest of the diff

- **R6 CPU statements are valid under R7.**
  - The native lane's b7 T128 stack, read only: verified (load 9.5 s,
    verify 29.0 s, 2.15 GB), and its published statement checked byte for
    byte.
  - My rung run's R6-published statement: removed the stale directory,
    verified, then checked byte for byte.
- **R5b statements (schema `/1`).** These have been refused since R6
  (N-r6-c), and R7 does not change that. A census of the repo found 3
  schema-`/2` statements, all with the CPU constant, and 31 schema-`/1`
  statements.
- **Nothing else in the diff touches soundness.** The block and stack
  renderings now take `backend_of_this_process()` instead of
  `gpu::label()`. That is a published-text change only.

## Notes

| id | what | severity |
|---|---|---|
| N-r7-a | the live-pid test depends on `/proc` being mounted in the verifier's own pid namespace | low (liveness, fail-safe) |
| N-r7-b | refusals echo a prover-chosen NUMBER for `gpu_declines` | very low |
| N-r7-c | a CPU prover may claim the device-live name | by design (self-report, labelled) |
| N-r7-d | a run can be refused at the very end | operability |

- **N-r7-a.** In a sandbox without `/proc`, or in another pid namespace,
  every stale directory looks dead. A live writer's temporary directory
  could then be removed, and that writer's rename would fail. Nothing
  false is published.
- **N-r7-b.** The parse error (`J::i64`: "expected an integer, got `…`")
  quotes the prover's numeral; a 61-digit one was echoed. The CPU-path
  refusal prints the parsed integer. Both appear only in local verifier
  output. A fixed message would close this.
- **N-r7-c.** It is one of three constants, so no free text can be
  published.
- **N-r7-d.** If a cuda run ever ended with `gpu_declines` above 0 on the
  CPU-path name, or above 4096 on the device name, the stack prover would
  refuse after the proof and remove the run. I did not find a path that
  produces this; noting it so a long GPU run is not lost to it.
- **Queue label.** My job `r7-r6-rung-statement` ran the live-pid case
  (`run-r6-live`). The R6-statement check is `r7-stale-dead-forged`.

## Evidence (this directory)

- `PROGRESS.md` (ROUND 7), `r6-vs-r7.patch`.
- `r7/`: `r7_queue.sh`, `binaries.sha256`, and every `r7-*` log, guard
  record and done marker.
- Scratch, `ops/zkp-mvp/trained-1b-review-r7-scratch/`:
  - `review_r7_inner` in `hashline/src/private_block/trained_block.rs`;
  - the CLI fixtures in `review_out/` (`run-r6` and `run-r6-live`).
