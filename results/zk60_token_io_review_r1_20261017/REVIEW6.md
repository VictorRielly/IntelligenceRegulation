# Token I/O — independent adversarial code review, ROUND 7 (frozen-r9: the lane's rounds 8, 9 and 10)

Reviewer: the independent adversarial code reviewer (a Claude Opus 5.5
subagent; I did not write this code), 2026-10-20, 04:33 UTC to 05:20
UTC. The rules are the same as in rounds 1–6. **No privacy acceptance and
no ruling is made here.**

## 1. Verdict

**Verdict: yes, frozen-r9 is demo-fit.** Nothing found affects soundness
or leaks the prompt or the answer.
* **The sealing pass does what it claims, in both the generic prover and
  the CLI:**
  * every input-provokable refusal comes before the run header;
  * it changes no transcript byte and no draw;
  * it cannot be switched off in a release build;
  * it refuses no honest input.
* **The T128 profiles hold up:**
  * their counted floors are 97 bits (TinyLlama) and 96 bits (8B), both
    ≥ D27's 95;
  * the input endpoint is one 256-word row;
  * T32 and T128 refuse each other in both directions.
* **PR4-15/16/17 and TR6-3 are built as described,** and hold at the edges
  I tried.
* **The r9v tests are sound evidence.** Re-run on my build: the plain
  prover now stops in the sealing pass, and the old path's receipts are
  rejected at the predicted sites.
* **The named r9 binary works end to end at 8B T32.** I ran it (the
  presenter demo's binary):
  * sealing 36.9 s, prove 208.6 s, total 288.7 s, peak 3.39 GiB;
  * my own binary verifies the receipt in 48.0 s;
  * owner: next token 11, written to a 0600 file and not printed;
  * input-owner passes;
  * the statement equals the round-7 run's apart from the two endpoint
    roots.
* **The demo kit writes no prompt or answer into the repository.**

**Findings.**
* **One LOW: TR7-1.** `DEMO_PRESENTER.md` quotes "about 100x ordinary
  inference". That figure belongs to the 32 bare blocks on a quiet box. For
  the next-word proof the demo actually runs, the ratio is about 135x
  (prove) to 186x (with loading) at 8B T32, measured on the r9 binary
  today. Fix the wording before the showing.
* **Six INFO.**

**Not yet run on the r9 binary.** The 8b-t128 option has had no run on the
r9 binary at all. The default 8b-t32 option has been run only by me, through
the CLI directly, not through `demo_present.sh`. Do one dry run of each on
a quiet box before showing them.

**Object.**
* `results/zk60_token_io_r1_20261017/frozen-r9/`: 236 files, equal to
  `manifest_final_r9.sha256` (list sha256 `b666a991…`).
* I re-hashed all 236 entries in the copy: none missing, none extra.
* Against frozen-r7, 12 files changed and 3 were added.
* **One block/run file changed:** `private_block/run.rs`, additively. It
  gains two T128 token-run profile constants, `TOKEN_IO_RUN_PROFILES` goes
  from 3 to 5, and two run-shape arms are added (`Shape::tinyllama_trained(128, …)`,
  `Shape::llama3_8b_trained(128, …)`). No existing line changed.
* Everything else is token-only:
  * `token_io.rs`: three test modules, plus the census helpers' T128 rows;
  * `token_io/load.rs`: the two T128 block profiles mapped;
  * `token_io/{cli, run, stage_in}.rs`;
  * the tests;
  * `examples/zk60_token_io.rs`.

**My binary.** `zk60_token_io` (`eb1c2b74…`) is built from my scratch copy:
frozen-r9 plus one `#[cfg(test)] mod review_r7;` line. The lane's named r9
binary `cli/zk60_token_io.r9.release.bin` is `b56f1b71…`, matching the
freeze note.

## 2. What was checked, item by item

### 2.1 The sealing pass (PR4-4 / TR6-2)

**The generic prover (`prove_token_run_with`).**

Before `ZkRng::from_os` and before `st.transcript()` builds the header, the
prover now runs:
1. `src.stage_in()`;
2. `stage_in::lookup_misses`, which checks:
   * every prompt position's id is below V;
   * BOS is at position 0;
   * B_in row t = E[tok_t], with zero row pads;
   * the pad positions and pad rows are zero;
   * `m` = the prompt's histogram, over the whole vocabulary cube;
3. the input endpoint's committed words `data[..len]` = the prompt plane
   with zero pads;
4. for every block:
   * CS-1/4/6 (`stage_block_is_the_statements`);
   * then `src.seal_check(k, blk, stage_shape(k), check)`, where `check` is
     `protocol::check_lookup_misses` (CS-3) at the stage's own shape and
     layout;
5. stage OUT's byte misses;
6. the output endpoint's words = the decided id's plane.

All of this is challenge-free:
* No transcript exists yet.
* No randomness has been drawn.
* Nothing reaches the sink.

**Transcript and draws unchanged.** Every line from `let mut rng = …` and
`let mut tr = st.transcript()?` onward is frozen-r7's, line for line. There
are only two differences:
* `let (win, b_in_plane) = src.stage_in()?` moved up, before the header. It
  is a source call that touches neither the transcript nor the generator.
* A `#[cfg(test)]` header counter.

So the transcript's bytes and the number and order of its draws are
exactly r7's. That matches the gate's identical draw counts at L = 1
and 2.

**Can it be bypassed?**
* In a release build `cheating` is the constant `false`; the switch exists
  only under `cfg(test)`.
* The stage-IN, endpoint and stage-OUT checks run in the prover itself.
* The CS-3 check depends on the source calling `check`. All five in-tree
  sources do:
  * `PipelineSource`, R3, R2 and the capture source build the witness and
    call it;
  * `CliSource` returns Ok only when `sealed`, which is set after
    `seal_chain` ran the same check.

  A source that skips it gains nothing, because `prove_core` keeps its own
  CS-3 refusal after the header. That moves only the timing (TR7-5).

**Can it refuse honest inputs?**
* The checks are exactly the conditions the honest pipeline builds:
  `Fp::new(id).0` is the canonical id, the histogram is over `v < voc_n`,
  and the endpoint planes come from the same prompt and token.
* Every honest run passed:
  * the lane's suite;
  * my t2 run: 61 passed;
  * the T128 dense run;
  * the CLI capture;
  * the TinyLlama dry runs;
  * my 8B T32 end-to-end with the named r9 binary (sealing 36.9 s, parity at 32 layers, token 11).

**Evidence that it refuses before the header.**
* `r9_tests`, on my build: each of these is refused with no header built
  and no segment sunk, while the honest run builds exactly one header:
  * a stage-IN miss;
  * a stage-OUT miss;
  * a block-1 exp miss (CS-3);
  * an input or output endpoint over another prompt or token.
* The r9v tests are in §2.4.

**The CLI (`seal_chain`).** This is a second, earlier sealing pass in
`prove_inner`. It runs before `prove_token_run_with`, and so before the
header.
* For every block in order, at its stage shape (derived exactly as
  `TokenRunStatement::stage_shape` derives it), it:
  * reloads the block (CS-6 in the loader);
  * builds the witness with the builder from the builder's own chain,
    starting at x_in_L00, which is checked equal to B_in;
  * checks that every output fits in int16;
  * checks bit-exact parity against the export's `x_out` of that layer;
  * runs CS-3.
* It holds one block and one witness at a time.
* The next token is computed from the builder's last plane (`x_last`), not
  from the export's reference.

Every CLI refusal an input can provoke now precedes the header. The order
in `prove_inner` is:
1. the claimed directories;
2. `--prompt` refused, the prompt file read;
3. ids and BOS (`honest_inputs`);
4. B_in = x_in_L00;
5. `seal_chain`;
6. D20 (`out_values`);
7. the endpoints;
8. the statement;
9. the backend claim;
10. the generic sealing pass;
11. the header.

What can still fail after the header:
* a block or `seq` file that changes between the two passes (the proving
  pass rebuilds each witness and re-checks parity);
* a zero LogUp denominator, at about 2^-128;
* I/O errors.

None of these is provokable through the inputs, and the `Claimed` guard
publishes nothing on any of them; it reports what it removes.

### 2.2 The T128 profiles

**Counted floors.** `t128_tests` prints the figures and asserts each is
≥ 95. My t2 run printed the same:
* TinyLlama T128, L 22: 2^-97.82, floor **97 bits** (column 2^-98.98,
  LogUp 2^-98.67).
* Llama-3-8B T128, L 32: 2^-96.78, floor **96 bits** (column 2^-98.53,
  LogUp 2^-97.30; at T128 the stack's lookup term sets the figure).
* The T32 figures stay at 97 / 97.

The real CLI runs printed floor 96 (8B T128) and 97 (TinyLlama T128).

**Geometry.** `in_ep_words()` = 256 at T128, so the input endpoint is one
256-word row, as the test asserts. The T128 token profiles' strings and
digests differ from the T32 ones; the token-profile digest is taken under
the run profile.

**Cross-T refusal, both ways** (`t128_a_dense…`, on my build):
* `RunShape::new` refuses:
  * a T32 block shape under the T128 profile;
  * a T128 block shape under the T32 profile.
* A dense TinyLlama T128 run (L 1) proves, verifies and both owners check.
  So does a T32 run.
* Each receipt is refused under the other's statement ("this segment
  belongs to another run").

### 2.3 PR4-15 / 16 / 17 and TR6-3, as built

The lane's `pr4_*` / `tr6_3` tests pass in my t2 run, and my RV7-1..4 cover
the edges.

* **PR4-17, the prompt.**
  * `--prompt` is refused with exit 2 by `prove` and `input-owner`. The
    `=` form is refused as an unknown argument.
  * `--prompt-file` takes a regular file of mode 0600 or 0400; `-` reads
    stdin, bounded.
  * These are refused, and no entry is echoed: a 0640 file, a symlink, a
    FIFO (no block, refused by lstat), an empty file, a malformed file.
* **PR4-17, the answer.**
  * `owner` writes the token to a new 0600 file: `--token-out`, by default
    `next_token` beside the decommitment.
  * It prints the token only with `--print`.
  * An existing token file is never overwritten.
* **PR4-16, the owner base.** The default owner directory is
  `~/zk60-owner-private/token-io/<run>-<key>.owner-private`. A fresh base
  is created 0700 at both levels.
* **PR4-15, leftovers and removals.**
  * A leftover `.incomplete/`, `.unverified-statement/` or owner directory
    is refused by name, with the `rm -r` to run.
  * Each removal a refused prove makes is printed, and a failed removal is
    printed loudly (`REMOVAL-FAILED`).
* **TR6-3, git's rule, for explicit and default directories alike.** A
  working tree is marked by:
  * a `.git` directory holding `HEAD`;
  * a `.git` file starting `gitdir:`;
  * any other `.git` entry, such as a symlink; this is conservative.

  This box's stub `$HOME/.git`, which has no HEAD, is not counted, and git
  agrees. My tests: a repo `$HOME` refuses the default, a stub `$HOME`
  accepts it, and explicit directories are refused under a repo, a gitfile
  or a `.git` symlink. `GIT_DIR` / `--git-dir` work trees are not detected,
  and the code says so.

### 2.4 The r9v tests (V1–V4) as evidence

These were re-run on my build of frozen-r9, in t2.
* In each case, the PLAIN prover now stops in the sealing pass, before any
  header:
  * V1 and V2: "stage IN: the witness's embedding lookup misses";
  * V3 and V4: "the input / output token endpoint's sealed plane is not
    the stage witnesses'".
* The CHEATING prover, which is the old round-8 path with no sealing
  check, finishes, and `verify` rejects at the predicted site:
  * V1, t34's exact stage-IN miss with the downstream left as honest: the
    stage IN H opening (LogUp);
  * V2, the consistent forger with the downstream re-derived: the same
    site;
  * V3, the input endpoint over another prompt: IN-00;
  * V4, the output endpoint over another token: OUT-10.
* Nothing verified.

This agrees with REVIEW5 §2.5 and RV6-8, and with the lane's old-code run
t35v. As evidence it is sound:
* each case must reach the verifier at least once;
* a verify that returned Ok would panic;
* the refusal site is asserted.

### 2.5 The presenter demo kit

Checked: `tools/demo_present.sh` and `tools/demo_decode.py` (read in
full), `DEMO_PRESENTER.md` against its sources, and the round-10 dry-run
transcript.

**No leak into logs or the repository.**
* **Private side.** Under `~/zk60-owner-private/token-io/demo-present/<TAG>/`
  (0700, umask 077):
  * the transcript (it shows the prompt text and the answer, as the owner's
    view);
  * the prompt file (0600, `O_EXCL`);
  * every step's log and guard JSON.
* **Proof side.** The receipt goes to
  `~/zk60-artifacts/token-io/demo-present/run-<TAG>` (0700 as made under
  that umask). Only public files are written there: segments,
  `statement/`, and a verifier copy without `seq_*`.
* **Command lines.** The prompt reaches the CLI and the pre-check only
  through `--prompt-file`. The owner runs without `--print`, so the token
  is not in `owner.log`.
* **The only write inside the repository** is the resource guard's history
  line. It keeps `cmd[:8]`, which reaches the `--head` value and never the
  prompt file, the decommitment or the token.
* **One small exposure.** The answer id is passed on `demo_decode.py`'s
  command line (`--id $ANS`) for the decode call: TR7-3.

**Claims on the page.** Checked against the logs, `PROGRESS.md`, the CPU
baseline README, D27 and D33.
* **These match their sources:**
  * every time and size: TinyLlama 68–71 / 81–86 s, 255 MB; 8B T32
    219 / 264 s, 471 MB; 8B T128 489 / 529 s, 928 MB;
  * verifying ~48 s at 8B T32: I measured 48.0 s;
  * the 8-bit baselines, 1.55 s and 5.6 s;
  * tokens per second, 0.37 / 0.12 / 0.24;
  * "about 200x short of 50 tokens/s";
  * the D27 95-bit reading;
  * D33's scope and the "What NOT to claim" list;
  * the 8b-t32 estimate of ~9–10 min. My run measured 289 s for prove plus
    3 × 80 s for the checks, about 8.8 min of work.
* **Wrong for what is shown: the "~100x" ratio (TR7-1).**
* **Wording that claims a little more than the record (TR7-4):** "learned
  nothing", Q4's "yes", and "the model's next word".

## 3. Findings

### TR7-1 — LOW — the presenter page's "about 100x" is not the ratio of what the demo runs

**Location.** `DEMO_PRESENTER.md`:
* the row "proof ÷ ordinary inference":
  * "~100x (32 layers, quiet box, 156 s)";
  * "~80x" at 128 tokens, with no label;
* "What NOT to claim": "about 100x slower than ordinary inference";
* Q3: "about 100x ordinary inference".

**The mismatch.** Both 100x and 80x come from the CPU baseline README's
*32-block* proof on a quiet box: 156.2 s / 1.55 s, and 432.5 s / 5.6 s.
The demo proves the whole next-word run instead (stage IN, 32 blocks, stage
OUT) on the r9 binary, which adds the sealing pass. The ratios for that
are:

| run | prove | with loading | source |
|---|---|---|---|
| 8B T32, r9 binary | 208.6 s → ~135x | 288.7 s → ~186x | my run today [MEASURED] |
| 8B T32, r7 binary | 219 s → ~141x | 264 s → ~171x | lane's demo |
| 8B T128, dg, r8 binary | 489 s → ~87x | 529 s → ~94x | lane's demo |

The 8B T128 ratio on the r9 binary has not been measured.

**Why it matters.** A presenter quoting "100x" while the screen shows
roughly 290 s against 1.5 s is quoting a different artifact, and
understating the gap by about 1.4 to 1.9x.

**Minimal fix.** Quote the demo's own ratio, "about 135–190x for the full
next-word proof shown (about 100x for the 32 layers alone on a quiet box)",
and say the same in Q3 and "What NOT to claim".

### TR7-2 — INFO — the 8B options have not been dry-run through the demo script on the r9 binary

* The two round-10 dry runs used the TinyLlama option.
* My 8B T32 run used the same named r9 binary and export through the CLI,
  not through `demo_present.sh`. It passed every step: sealing, parity at
  32 layers, token 11, peak 3.39 GiB, within the script's 4.5 / 6.5 GiB
  guard.
* 8b-t128 has had no run on the r9 binary. Its sealing pass at 8 GiB-class
  memory, and the script's 8 / 10 GiB guard, are untried.

Before the showing, dry-run `demo_present.sh` and
`demo_present.sh 8b-t128` once each on a quiet box.

### TR7-3 — INFO — the demo passes the answer id on a command line

`demo_present.sh` runs `demo_decode.py $TOK --id $ANS`. For that moment the
answer id is in `/proc/<pid>/cmdline`, readable by local users. This goes
against PR4-17's rule, which the CLI itself now follows.

Fix: give `demo_decode.py` an `--id-file` option and pass it the owner's
0600 `next_token` file.

### TR7-4 — INFO — three phrases claim slightly more than the record

* **"the verifier … learned nothing about the prompt or the answer (\*)".**
  The page's own D33 footnote says this model, calibration and stages are
  still under review. Say "was never given the prompt or the answer", and
  keep "designed to learn nothing" for the footnote.
* **Q4, "For the smaller model's core, yes".** D33 covers the TinyLlama
  stack at pg_rot1, built from tree R7. It is suspended for R8 and later
  trees until the re-pin review. The demo's TinyLlama option is b4 on the
  R8-based r9 binary. Name that scope in the answer.
* **"the model's next word".** What is proved is the approved integer
  model's next word. Say so once ("the integer version of the model");
  the fidelity caveat is already on the page.

### TR7-5 — INFO — the CS-3 seal depends on each source, and the CLI's on a copied derivation

The generic prover's CS-3 check runs only if the source calls the `check`
it is handed. All five in-tree sources do. Skipping it would move a CS-3
refusal back behind the header; `prove_core`'s own check stays. It would
never be a soundness problem.

`CliSource::seal_check` does not run `check`. It trusts `seal_chain`, which
re-derives the stage shape with copied code ("exactly as
`TokenRunStatement::stage_shape`"). The two derivations are identical in
r9. A test asserting `seal_chain`'s shape = `st.stage_shape(k)` for every k
(or calling `check` on a kept seal witness) would stop a future divergence
from quietly un-sealing CS-3 on the CLI path.

### TR7-6 — INFO — a second `owner` call with the default token path fails only after re-verifying

`next_token` is created with `create_new`. A second `owner` on the same
decommitment without `--token-out` exits 1 (RV7-2). It does so after the
full re-verification, about 80 s at 8B. The demo passes its own
`--token-out`, so it is unaffected.

Fix: refuse at argument time if the token file already exists, or say so in
the usage text.

### TR7-7 — INFO — a pre-existing owner base keeps a loose mode

The owner base is created 0700 at both levels when new (RV7-4). A
pre-existing `~/zk60-owner-private` at 0755 stays 0755, because
`DirBuilder` does not tighten an existing directory. On this box the base
is 0700. Inside it, `token-io-cli-capture-r9/` is 0755, but the base
protects it, and the owner directories themselves are always 0700 with
0600 files.

Fix: refuse a group- or other-accessible base, or `chmod 700` it on use.

## 4. Not findings, for the record

* **The run.rs change is additive.** Two constants, the registry entry and
  two match arms. No existing line changed, and the census suites pass
  with the two new profile strings (lane's s12 / s13).
* **The 8B statement format is unchanged.** My r9 run's `statement.json`
  differs from the round-7 run's only in the two endpoint-root lines. The
  `diff` with those removed is empty, so the schema is still `/2` and the
  context is the same.
* **`--label --prompt` exits 2.** The word "--prompt" as another flag's
  value trips the PR4-17 check. This false positive is harmless.
* **Two `.git` entries are not counted as repositories:** a `.git` file
  that is not a gitfile, and a `.git` directory whose HEAD is a dangling
  symlink. Git does not take either for a repository. Work trees driven
  by `GIT_DIR` / `--git-dir` are not detected; this is documented.
* **What can still fail after the header in the CLI:**
  * a file that changes between the sealing and proving passes (the
    parity re-check in `CliSource::witness`);
  * a zero denominator, at about 2^-128;
  * I/O.

  None is reachable through the inputs, and a refusal publishes nothing.
* **D27's figure.** The demo's "security level 97 bits (the verifier
  requires 95)" is the statement's derived whole-run figure, and the CLI's
  default `--min-bits` of 95. That matches D27's MVP reading.
* **No privacy acceptance** is made or implied.

## 5. Tests run (round 7)

| id | what | result |
|---|---|---|
| t1 | my 4 review tests (`cli_tests::review_r7`, 4 s) | 4 passed; every CONTROL as predicted (RV7-1a–h prompt file, RV7-2a–c token file, RV7-3a–g git rule, RV7-4 base) |
| t2 | the lane's token_io tests on my build (211 s, peak 5.89 GiB) | 61 passed / 0 failed / 9 ignored; 71 AS PREDICTED, 0 NOT (r9_* ×5, r9v V1–V4, t128 ×2, pr4_* ×7, tr6_3, the earlier rounds') |
| e1 | 8B T32 prove, the lane's named r9 binary (guard 4.5 / 6.5) | sealed 36.9 s (parity 32), prove 208.6 s, total 288.7 s, 34 segments, 471,285,072 B, floor 97, peak 3.39 GiB |
| e2 | verify with my binary (publishes) | verified, 48.0 s / 79.9 s |
| e3 | owner with my binary, `--token-out` | next token 11 in a 0600 file; not in the log |
| e4 | input-owner with my binary, `--prompt-file` | 32 tokens checked |
| e5 | re-check with the named r9 binary | statement-checked, 47.9 s |
| compare | the r9 statement vs the round-7 run's | equal except the two endpoint roots |

## 6. Files

* `ops/zkp-mvp/token-io-review-r9-scratch/`:
  * `tree/` (frozen-r9 + `cli_tests/review_r7.rs`);
  * `launch_r7.sh`;
  * `b8/run-8b-t32-r9/` (the 8B T32 run's public receipt).
* The run's prompt file and owner directory are in a 0700 scratchpad
  directory, outside every git tree.
* Logs: `results/zk60_token_io_review_r1_20261017/logs7/`.
* Ledger: `PROGRESS.md` (ROUND 7).
