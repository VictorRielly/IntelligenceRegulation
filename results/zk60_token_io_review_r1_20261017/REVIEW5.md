# Token I/O — independent adversarial code review, ROUND 6 (the lane's rounds 6 and 7)

Reviewer: the independent adversarial code reviewer (a Claude Opus 5.5
subagent; I did not write this code), 2026-10-19 19:10 UTC to
2026-10-20 01:28 UTC. The rules are the same as in rounds 1–5. **No privacy
acceptance and no ruling is made here.**

## 1. Verdict

**Verdict: yes, the token CLI is demo-fit on frozen-r7.** No finding
affects soundness. On the soundness side:
* **The R8 rebase** is exactly R8 plus the lane's hunks.
* **Each block stage of a token run** is proved and verified at its own
  layer's R8 calibration, in all eleven fields, and the statement binds it:
  * a witness under the other layer's value of any one field is refused at
    the block;
  * a receipt read under any other set of layer records is refused.
* **The capture hooks:**
  * they are compiled out of release builds;
  * they are inert when no recorder is attached;
  * hostile receipts do not make them panic or allocate without bound;
  * there is no path from an owner decommitment to a bundle.
* **TR5-1 .. TR5-3 are closed.**
* **The round-7 demo checks out independently.** My own binary re-verifies
  the round-7 8B demo run on b7voc0_T32. Its independent publication is
  byte-identical to the lane's, the owner reads token 11, input-owner
  passes, and every control is refused.
* **The approval record** matches the fidelity lane's files.

**The coordinator's t34 question.** Does the verifier reject every receipt
the frozen-r7 prover can produce for (i) a stage-IN lookup miss and (ii) an
input endpoint sealed over another prompt? **Yes.**
* **(i)** fails the stage-IN LogUp identity (the H opening's zero-sum
  claim) or the IN-01/IN-02 zero-checks.
* **(ii)** fails the IN-00 IO-in zero-check, or the input endpoint's
  opening.
* I found no accepting path. The full argument is in §2.5.
* What remains is prover-side hygiene, finding TR6-2.

**Findings.**
* **Two LOW, both operational. Neither is a soundness problem.**
  * TR6-1: a private prompt travels on the command line.
  * TR6-2: the run prover's sink contract has the t34 gaps.
* **Five INFO.**

**Object.**
* `results/zk60_token_io_r1_20261017/manifest_final_r7.sha256`: 233 files,
  list sha256 `eb912dd5…`.
* It is reviewed as the coordinator's frozen copy `frozen-r7/`.
* My copy is `ops/zkp-mvp/token-io-review-r7/`, taken at 19:11 UTC before
  round 8 moved the lane's tree. Its manifest is
  `ops/zkp-mvp/token-io-review-r7.sha256`: 234 entries (the 233 plus
  `BASELINE.sha256`), list sha256 `5baa8e79…`.
* All 233 manifest entries match in both copies, and every file of my copy
  equals frozen-r7's.

**My binary.** `zk60_token_io` (sha256 `9a22336d…`) is built from my scratch
copy: the frozen tree plus two `#[cfg(test)] mod review_r6;` lines. The
example binary contains no test code.

**How the claims were checked.**
* Static review of every changed file.
* A 3-way merge check of the rebase.
* 7 new tests of mine on the frozen tree (6, plus RV6-8 for the t34 question), plus the lane's token_io tests.
* The layer-0 pre-check run by hand.
* The approval record re-hashed against the fidelity lane's files.
* 15 8B CLI probes on the round-7 demo run through my own binary.

## 2. What was checked, item by item

### 2.1 TR5-1 .. TR5-3: closed

**TR5-1 (LOW, round 5): closed.**

What changed:
* `prove` now claims all three of its directories atomically at its
  start, through `Claimed::dir` (`create_dir`, or the 0700 `DirBuilder`).
  The three are:
  * `<out>.incomplete/`;
  * `<out>.unverified-statement/`;
  * the owner directory.
* A directory that already exists is refused by name ("exists; … must be
  new").
* On any refusal, the `Claimed` drop guard removes only the directories
  this process created. The guard is disarmed only after the final rename.
* The old late `create_private_dir` and the unconditional
  `remove_dir_all` cleanup are gone.
* The default owner directory is now keyed by the run's canonical path:
  `<name>-<12 hex of SHA-256(canonical parent/name)>.owner-private`.

What I ran (RV6-1/2, two real threads, twice each):
* **Two proves naming the same owner directory (my round-5 reproduction).**
  One exits 0. The other is refused at its claim. The winner's
  `input.dec`/`output.dec` are present, and the loser leaves nothing.
* **Two proves naming the same `--out`.** One exits 0. The other is
  refused at the `.incomplete` claim. The winner's run, statement and
  decommitments are intact.
* **A prove refused mid-run** (parity at block 0, after stage IN's segment
  was written) leaves none of its three directories.
* **A stale `<out>.incomplete/`** from a crashed prove is refused, and its
  contents are kept.

The lane's own seam test (a rival claiming in the window, then an existing
owner directory) passes too.

**TR5-2 (INFO): closed.**

What changed:
* `tools/layer0_precheck.py` (`ddb3fcb3…`): the "clear" line now prints the
  scan's `scope` and `not_covered`. `not_covered` names the layer-0 scores
  and all later layers, and says a clear prompt can still be refused, which
  is safe.
* The docstring is restated.
* `check` now requires the export's RoPE tables to be a byte prefix of the
  scanned ones (the list holds a SHA-256 for every row prefix). Otherwise
  it reports "not-covered".
* The demo's logs for a non-calibration prompt go to a 0700 directory
  outside the repository.

Re-run (light Python, `logs6/precheck/`):
* The lane's 6 tests pass.
* voc0 with ho00 gives `clear`, with the scope and not-covered lines.
* voc0 with 662 / 16309 gives `clear`: that export has no refusing token.
* b7_T32 with 662 / 16309 gives exit 2, each token named.
* b7_T64 gives exit 2.
* The fidelity lane's T128 voc0 variant has the same layer-0 fingerprint
  but a 128-row RoPE, against the 32 rows scanned. It is now "not-covered"
  under the new prefix rule.

**TR5-3 (INFO): closed.**
* **Pins.** The demo reads both pins from the approval record and checks
  that the record's export path is the demo's. It no longer runs `profile`.
* **(a)** An explicit `--owner-dir` inside a git working tree is refused by
  name. This holds for a `.git` directory, for a worktree's `.git` file,
  and (RV6-3a) when the tree is reached through a symlink.
* **(b)** The default owner directory is accepted for a run directly under
  `$HOME`, also when `$HOME` is named through a symlink (RV6-3b).
* A run in `$HOME/zk60-artifacts`, an ancestor of the base, is still
  refused (RV6-3c).

### 2.2 The R8 rebase: exactly R8 plus the lane's hunks

**Method: a 3-way merge.**
* mine = my r5 frozen copy (R7 + lane files);
* base = `r7/frozen-tree`;
* theirs = `r8/frozen-tree`.

**Result.**
* **`private_block.rs` and `trained_block.rs` equal the merge exactly.**
  Their hunks against R8 are the same hunks they had against R7:
  * `private_block.rs`, 9 lines: the token_io module and the CLI
    re-exports;
  * `trained_block.rs`, 40 lines: `pub(crate)` on ten helpers.
* `s24_tests`, `s33_tests` and `hash_domain_tests` also equal the merge.
* **`run.rs` = the merge + 2 lines**, `token: None`, in the block run's
  capture header. That code is `cfg(test)`: release builds compile it out.
* `s25_tests.rs` = the merge + the census row change, 6 → 8 (§2.3).
* `run_capture.rs` is identical in R7 and R8. All of its changes are the
  lane's.
* Every other file equals R8 byte for byte, and 0 files exist only in R8.

**Per-layer calibration.**
* `TokenRunStatement::new` builds `stage_cal[k]` from block k's own layer
  record. The record is checked against the block digest. The calibration
  is `apply_own(base, own)`, validated by `Shape::with_layer_calibration`.
* `stage_shape(k)` is that calibration. It is used by the block prover, by
  the verifier (`ssh` at both sites) and by each block's layout.
* The stage line names every own constant, so the schedule digest that the
  header absorbs carries them. The model identity carries them too.
* This mirrors native `run.rs` line for line.
* The final norm and head keep the token profile's constants.
* The statement schema is `zk60-token-io-run/2`, with
  `layers_with_own_calibration`. A `/1` statement is refused by name ("not
  schema zk60-token-io-run/2").

**Hunting for a way to prove under one layer's constants and verify under
another's.** The rung, with block 1 at R8's all-eleven calibration:
* **RV6-4, the relation.** A cheating prover witnesses block 1 with one own
  field put back to the run's value, under the honest per-layer statement.
  It is **refused at block 1 for all 11 of 11 fields**: sh_s, norm_tn,
  norm_cn_a, norm_cn_m, norm_ceps, sh_ao, sh_qkv, sh_o, sh_g, sh_h, sh_z.
  Each one moves block 1's output, so none of the forgeries was trivial.
* **RV6-5, the binding.** The honest receipt was read under 13 other
  record sets:
  * the own constants on layer 0 instead of layer 1;
  * the own constants on both layers;
  * each of the 11 fields dropped in turn.

  All 13 are refused ("this segment belongs to another run").
* **RV6-6.** Two layers with different own calibrations:
  * witnessed swapped (each block at the other layer's calibration):
    refused at block 0;
  * the honest receipt under swapped records: refused.

At 8B: the demo's statement has one own constant, layer 1's `sh_s` 7.
* The re-check, the independent publication, the owner and input-owner
  checks all pass.
* Each of these is refused:
  * `layers_with_own_calibration` emptied;
  * layer 1's own sh_s set to 6;
  * one byte of block 1's segment flipped (refused at block 1).

### 2.3 The capture hooks: inert when off, no decommitment path

**Compiled out of release builds.**
* `run_capture` is a `#[cfg(test)]` module, and every hook call site is
  `#[cfg(test)]`.
* A release build that compiled is itself proof of that: any reference left
  ungated would not resolve. My release build and the lane's both
  compiled.
* I compared the lane's release binaries from the demo tree (r7) and the
  capture tree (r7c). `.text`, `.rodata` and `.eh_frame` are byte-identical.
  136 bytes differ in total, all in the build-id and in `.data.rel.ro`
  (panic line numbers).

**No effect on accept/reject when off (test builds).**
* No hook returns a `Result`, so none can change a verdict.
* With no recorder attached:
  * `checkpoint` returns `None`;
  * `with` returns `None`;
  * every hook returns at once.
* The arguments evaluated anyway are derived from the layout, not from
  receipt sizes.
* Indexing is safe:
  * `&segments[k]` comes after the segment-count check;
  * `&slots[s]` comes after `slots.get(s)?`.
* RV6-7 tried 62 hostile receipts, each verified once without a recorder
  and once with one: byte flips across every segment, truncations,
  extensions, emptied segments, two segments swapped, the last segment
  dropped. Result: **0 panics, 0 accepted, 0 bundles**, and the recorder
  detached every time.

**No owner decommitment can reach a bundle.**
* The recorder sees only what `verify_token_run` hands it. The
  `OwnerHandoff` never reaches the verifier.
* The salts of a token endpoint's Q opened columns do appear, but they are
  already in the receipt.
* The writer's not-in-a-capture list names the owners' decommitments.
* The lane's bundle check scans for the salts and pad words of both owners'
  decommitments, and its scan is now linear. It passes.

**The s25 census (6 → 8 `sha256_hex(` sites in `run_capture.rs`).** This is a
real classification, not a weakening.
* The two new sites are:
  * `stage_begin_stage`'s `segment_sha256` (line 1048), the twin of the
    block writer's line 884;
  * `write_run_token`'s SHA-256 of `expected_bytes` (line 2234), the twin
    of line 1941.
* Both are SHA-256 content digests that a capture file pins. That is call
  kind C1, the row's kind.
* The census still pins the exact count, so a ninth site would fail it.
* The row's reason names the two additions.

### 2.4 The round-7 8B demo (b7voc0_T32)

**The approval record matches the fidelity lane's files.** For
`approvals/token_profile_approval_llama3_8b_pg_rot1_b7voc0_T32.json`:
* I re-hashed all 7 `token_io` files from the fidelity export, and they
  match the record. They also match its `SHA256SUMS` (`216d13e4…`).
* `profile.json` is `82c7c752…c4f6`, the same value as the fidelity
  ledger's 15:48 UTC entry.
* The tables, BOS and final norm are the calibration lane's b7_T32 files,
  so the token-profile pin `e8238cf1…` is unchanged.
* The verifier copy consists of hard links of the export minus `seq_*`.
* **The pins are reproduced by a second build.** My own build's
`profile` gives identity `c3fb8c5b…` and token profile `e8238cf1…`, read
both from the fidelity lane's export directly and from the verifier copy.
These equal the record's pins. On the b7_T32 copy it gives `47f01943…`, so
the b7 record's pin still holds under the R8 code (R8 keeps R6's sh_s
encoding).

**The cross-check holds.** `runs/r7_crosscheck_voc0_ho00.json` agrees with
the fidelity lane's `runs/llama3-8b/nexttoken_ho00_b7voc0_T32.json`, which
it did not produce:
* integer token 11, margin C 313,660,358 in both;
* float model token 11 (margin 6.96 logits);
* the lane's float head on the integer row: 11 (margin 9.55).

**Fresh verify of the r7 demo run, with controls.** My binary (`9a22336d…`) was run on hard-linked copies, with
both pins read from the approval record:
* **c1** re-check: statement-checked.
* **c2** independent publication, from the unverified statement rebuilt
  from the published one: `statement.json` and `segments.json` are
  **byte-identical** to the lane's.
* **c3** owner: next token **11**.
* **c4** input-owner: 32 tokens checked.

Controls, each refused:
* **c5** the b7 identity pin: "the export's trained statement identity is
  c3fb8c5b…, not the pinned one".
* **c6** the b7 verifier export with the b7 pins: "the statement's context
  is not this export's and label's".
* **c7** a schema `/1` statement: "not schema zk60-token-io-run/2".
* **c8** `layers_with_own_calibration` emptied: not canonical.
* **c9** layer 1's own sh_s 7 → 6: not canonical.
* **c10** one byte of segment 002 flipped: block 1, pcs.
* **c11** owner over that tampered copy: refused the same way.
* **c12** the lane's round-6 run (schema /1) under the r7 binary: refused
  by name.

Peak RSS was at most 2.83 GiB, and each verification took about 100 s
[MEASURED].

### 2.5 The coordinator's t34 question: does the verifier reject what the prover does not refuse?

The question, as a soundness question: on frozen-r7, can any receipt a
prover produces for (i) a stage-IN lookup miss, or (ii) an input endpoint
sealed over a different prompt from the one embedded, be accepted?

**Stage IN as the verifier checks it** (`stage_in.rs`, `verify` and
`define`). The transcript order is:
1. The run header absorbs the input endpoint's root. It comes from the
   statement, before stage IN.
2. Stage IN absorbs `B_in`, then `A_in` (`tok` on the position domain,
   `m` on the vocabulary domain), then `M_in`.
3. Only then are β, γ, α and `r_emb` drawn.
4. Then `H_in` (`h_q`, `h_tab`, the zero-sum pair `u`) is absorbed.
5. Each slot draws its own τ, μ and ζ after `H_in`.

So everything the prover controls on the input side is fixed before the
lookup challenges: `tok`, `m`, `B_in` and the endpoint.

All four slots are *standalone*. The verifier ties each slot's scalar to
c·Σmask through the M opening (`MaskFunctional { value: scalar }`). Each
zero-check's sum is therefore bound to 0; the prover cannot choose it.

The relations the verifier checks:
* **IN-00 (IO-in).** For every word w of the endpoint's whole padded plane:
  end(w) − supp_T(w)·tok(w) = 0.
  * `end` is a claim on the input endpoint commitment, opened against the
    statement's root.
  * `tok` is a claim on `A_in`.
* **IN-01 (query zero-check).** Three clauses, each with its own fresh μ:
  * h_q(t)·(α − tok(t) − β·B~(t, r_emb) − g) = supp_T(t);
  * tok(0) = BOS;
  * on the pad: tok = h_q = 0, enforced through a fresh ζ.

  The `B_in` claim it raises is carried into block 0's `B_in` opening. In
  `verify_token_run_with`, `pending` is prepended to block 0's incoming
  claims and opened against stage IN's `B_in` root.
* **IN-02 (table zero-check).** h_tab(v)·(α − τ(v)) = m(v) for v < V, and
  m = h_tab = 0 above V. Here τ(v) = v + β·E~(v, r_emb) + g, from the
  verifier's own embedding table.
* **IN-03.** Σu = 0.
* **The LogUp identity.** Σh_q − Σh_tab + Σu = 0. It is one all-ones sum
  claim inside the H opening. Its value 0 is fixed by the verifier
  (`logup_sum_claim`, `value: Fp2::ZERO`).

**(i) A lookup miss.** Some position t < T has B_in row t ≠ E[tok_t], or
tok_t ∉ [0, V).
* If IN-01 and IN-02 hold, then h_q(t) = 1/(α − q_t) and
  h_tab(v) = m_v/(α − τ_v).
* The identity then reads Σ_t 1/(α − q_t) = Σ_v m_v/(α − τ_v) at the
  random α. As rational functions of α, the two sides are equal only if
  every q_t is some τ_v.
* q_t = τ_v means tok_t − v + β·(B~(t, r) − E~(v, r)) = 0. Since `tok`
  and `B_in` were fixed before β and `r_emb`, that forces both
  tok_t = v and B row t = E row v, except with probability about
  (2^12 + 2^17)/|F_p²| plus log d_pad/|F_p²|.
* A prover that instead forges `h_q`, `h_tab` or `m` breaks IN-01 or IN-02
  (sumcheck soundness), or breaks the opening that binds the terminals.
* `B_in` cannot be one value for the lookup and another for block 0. Both
  claims are opened in one `B_in` opening.

Refusal site: "stage IN H (the LogUp sum claim is part of this opening)",
or IN-01 / IN-02.

**(ii) A foreign input endpoint.** The endpoint commits P′, while
`tok` / `B_in` carry P.
* IN-00 is a zero-check of end − supp·tok over the whole padded plane.
  Any difference at a position below T, or any nonzero pad word, makes its
  sum nonzero at the random τ, except with probability at most
  (lw + degree·rounds)/|F_p²|.
* The terminals `end~(ρ)` and `tok~(ρ)` are bound by the endpoint opening
  (against the statement's root, absorbed in the header) and by the `A_in`
  opening.
* `check_token_endpoint_opening` fixes the claim's shape: one claim, the
  data rows plus its own terminal pair. `closes.len() != 1` is refused.

Refusal site: "stage IN slot 00 [IN-00 IO-in …]" or "input token
endpoint: …".
* Making `tok` follow P′ too just turns (ii) into (i).
* Making `B_in` and everything downstream follow P′ as well is a true run
  of P′. It is accepted, correctly: the receipt then proves a statement
  about the prompt that is actually sealed.

**No accepting path found.** I checked each of these:
* the variable order: IN-00's `tok` claim fixes the lift bits to 0, so it
  reads the same first-T entries IN-01 uses, or honest runs would fail;
* the padded vocabulary rows: forced to zero;
* positions in the lift: forced to zero;
* `u`: forced to sum to zero;
* the β / `r_emb` order;
* the endpoint's root binding.

Every soundness term involved is inside the run's derived whole-run figure.
That figure has a 97-bit floor (logup-derived, column, PCS-field and
sumcheck bound).

**Empirical evidence.**
* **The lane's DESIGN 6.1 controls**, run by me on the frozen tree (t2),
  with receipts from the test-only cheating prover. For these witnesses it
  differs from the honest prover only in skipping refusals the honest
  stage-IN prover does not have. All refused where predicted:
  * #7, a consistent re-lookup under the honest seal, i.e. an endpoint
    over another prompt: IN-00;
  * #10a, a nonzero pad word in the endpoint: IN-00;
  * #16a, a wrong embedding row: the LogUp H opening;
  * #16b, one changed word: the LogUp H opening;
  * #16c2, the padded id V: the LogUp H opening;
  * #16d, the histogram off by one: the LogUp H opening;
  * #16c, the padded id counted on the pad: IN-02;
  * #4 and #5, BOS: IN-01.
* **My RV6-8, on the HONEST prover path** (no cheating flag): every case produced a receipt, so the honest prover refused none of
them, and the verifier refused all six:
* **(i-a)** position 5's id changed, with the endpoint and histogram
  following it and B_in row 5 = E[old]: the LogUp H opening.
* **(i-b)** one word of B_in row 5 changed, with the downstream
  re-derived: the LogUp H opening.
* **(i-c)** an id ≥ V, with B_in row = the padded row E[0]: the LogUp H
  opening.
* **(ii-a)** the endpoint sealed over a prompt differing at position 7:
  IN-00.
* **(ii-b)** the endpoint with a nonzero pad word: IN-00.
* **(ii-c)** the endpoint over a prompt with position 0 changed: IN-00.
* **Control:** the other prompt with every part consistent is
  **accepted**, as it should be.

**(iii) The block CS-3 miss.**
* The block relation's lookups refuse such a receipt. That is the native
  block argument (`protocol::verify_core` at the stage shape).
* The prover's CS-3 check does fire, but only inside block k's proving. By
  then stage IN's segment has already reached the sink. The CLI's sink is
  `<out>.incomplete/`, which the `Claimed` guard removes, so nothing is
  published.
* The library's sink contract, however, says the refusals a caller can
  provoke leave the sink empty. See TR6-2.

## 3. Findings

### TR6-1 — LOW — a prover-private prompt travels on the command line

**Location.**
* `token_io/cli.rs`:
  * `input_owner_inner` takes the prompt only as `--prompt id,id,…`;
  * `prove` takes `--prompt` too, although `--seq-dir` reads it from a
    file.
* `tools/r4_cli_demo.sh`:
  * `PROMPT_IDS` goes to prove as `--prompt`;
  * input-owner always gets `--prompt $PROMPT`, also for a `SEQ_DIR`
    prompt;
  * both run through the guard, whose own argv carries the prompt as well.

**Why it matters.** On Linux, any local user can read a process's command
line through `/proc/<pid>/cmdline` (with the default `hidepid=0`), and a
shell keeps it in its history. The demo otherwise treats a non-calibration
prompt as prover-private: it keeps the logs in a 0700 directory and refuses
`LOGS` inside the repository. Hiding the prompt is P1's first requirement.
On today's single-user box this is not an active leak.

**What happens to be safe.** The guard's history file in the repository
keeps `cmd[:8]`, and the prompt sits beyond the eighth argument. That is
luck of argument order, not a guarantee.

**Minimal fix.**
* Add `--prompt-file`, read with the existing `read_regular_file_bounded`,
  for `prove` and `input-owner`.
* Have the demo write a private prompt to a 0600 file in its 0700 log
  directory and pass the path instead.

### TR6-2 — LOW — the run prover's sink contract has the t34 gaps (prover hygiene; the verifier is sound)

**Location.** `token_io/run.rs`, `prove_token_run_with`.

**The gaps.**
* It does not refuse:
  * (i) a stage-IN lookup miss (B_in row ≠ E[tok], an id ≥ V, a histogram
    that is not tok's);
  * (ii) an input endpoint sealed over another prompt, or with a nonzero
    pad word.
* It refuses (iii) a block CS-3 miss only inside block k's proving, after
  stage IN's segment has been handed to the sink.
* The function's own contract says: "the refusals a caller can provoke with
  its inputs leave the sink empty".

**Why it is not a soundness problem.** Every such receipt is refused by the
verifier (§2.5), and the honest CLI cannot produce (i) or (ii):
* B_in comes from the table rows of the prompt;
* the endpoint comes from the same prompt;
* parity is checked against the export's `x_in`.

The CLI's `Claimed` guard removes the incomplete run after a CS-3 refusal.

**What remains.** A library caller that misuses the API gets a full proof
(minutes at 8B) that every verifier rejects. Its sink also receives stage
IN's segment for a refused run. That segment includes the input endpoint's
opened columns, which is no more than an accepted receipt reveals.

**Minimal fix.** Before the first segment, check:
* B_in rows = E[tok];
* tok < V;
* tok(0) = BOS;
* m = histogram(tok);
* the endpoint plane = tok on T with zero pads;
* every block witness's CS-3 lookups.

The lane's round-9 test-first run (t34) is on it.

### TR6-3 — INFO — the default owner directory is never checked for a git working tree

`owner_dir_at` checks `git_working_tree_of` only for an explicit
`--owner-dir`. RV6-3 NOTE: when `$HOME` is itself a git working tree (a
dotfiles repository), the default
`$HOME/zk60-artifacts/token-io/…` is accepted, and an explicit directory in
the same place is refused.

The detection also looks only for a `.git` entry among the ancestors. A
work tree driven by `--git-dir` / `GIT_DIR` (the common "bare dotfiles
repo" layout) has none.

Minimal fix: apply the same check to the default, and say in the demo that
`.git`-less work trees are not detected.

### TR6-4 — INFO — the voc0 approval record's wording is copied from the b7 record

`approvals/token_profile_approval_llama3_8b_pg_rot1_b7voc0_T32.json` says:
* `"record": "… pins for the … b7 T32 token I/O tables"`;
* `"written_by": "… from the calibration lane's own files"`;
* key `calibration_lane_SHA256SUMS_sha256`.

But the export and its `SHA256SUMS` are the fidelity lane's. The tables are
the calibration lane's files (same SHA-256s).

The values are right; I re-hashed every file. One more thing for the
record: the identity pin `c3fb8c5b…` comes from `profile` over the export's
public files. For b7, the R3 harness was a second derivation; no such
second derivation exists here. My independent build reproduces the value
from both the fidelity export and the verifier copy.

### TR6-5 — INFO — the eleven-field path has not met an 8B export yet

The round-7 8B demo's statement has a single own constant, layer 1's
`sh_s` 7, which was already R6's feature. R8's other ten own fields are
exercised only at the rung:
* the lane's `r7_a`;
* my RV6-4 (11 of 11 fields enforced);
* my RV6-5 and RV6-6.

No 8B export with multi-field own constants has gone through the token CLI.
Before a demo claims "R8 per-layer calibration at 8B", run one.

### TR6-6 — INFO — the pre-check's fix text is stale

The b7 entry's `fix` still says "a layer-0 recalibrated export is coming".
It has landed: b7voc0_T32 has no refusing token. Point the fix at that
export, or at its approval record.

### TR6-7 — INFO — runs with a schema /1 statement no longer re-check under the r7 binary

The earlier demo runs (r4, r5, r6) are refused by name under the r7
binary (c12). That is the expected effect of the schema bump. Keep
`cli/zk60_token_io.r6.release.bin` for re-checking them, and say so beside
those runs.

## 4. Not findings, for the record

* **R8 rebase method and result** (§2.2): the 3-way merge reproduces
  `private_block.rs` and `trained_block.rs` exactly. `run.rs` differs from
  the merge only by the `cfg(test)` capture-header line, and `s25_tests.rs`
  only by the census row. 0 files exist only in R8.
* **`.data.rel.ro` byte count.** My byte comparison of r7 against r7c
  counts 116 differing bytes in `.data.rel.ro` (the lane wrote 110) plus 20
  in the build-id: 136 in total, the same total as the lane's. `.text`,
  `.rodata` and `.eh_frame` are identical.
* **Crash recovery.** A crash or kill leaves `<out>.incomplete/`,
  `<out>.unverified-statement/` and the owner directory. A re-run of the
  same `--out` is refused by name until they are moved: the stale claim is
  kept (RV6-2b). This is by design; the demo's header says to move the
  previous run first.
* **TR5-3 (b) tradeoff.** For a run directly under `$HOME`, the default
  owner directory sits inside the run's parent (`$HOME`), so whoever
  snapshots `$HOME` carries it. This was the coordinator's choice in TR5-3
  (b). Naming that same default path explicitly is refused under the parent
  rule. The inconsistency is harmless.
* **Who the demo's pins come from.** The verifier-side pins come from the
  approval record. The approval itself is the coordinator's round-7
  instruction, not a ruling of Victor's. The record says so ("not a privacy
  acceptance and not a ruling").
* **The token-profile pin alone does not distinguish b7 from b7voc0.** Both
  have `e8238cf1…`: same tables, BOS and final norm. The identity pin does
  distinguish them, and both pins are required.
* **What a "clear" pre-check covers.** Only layer-0 norm_a / Q / K / V /
  RoPE. The voc0 entry was scanned at T32 (32 RoPE rows), so a T > 32
  export with the same layer 0 is "not-covered", as k4 shows. That is
  correct and conservative.
* **No privacy acceptance** is made or implied by any of the above.

## 5. Tests run (round 6)

| id | what | result |
|---|---|---|
| t1 (+ t3) | my review tests (6 in t1; RV6-8 in t3, 21 s) (`review_r6`, cpu-guarded, 55 s, peak 1.47 GiB) | 6 passed / 0 failed; every CONTROL as predicted |
| RV6-1a/b ×2 | two real concurrent proves: same owner dir; same `--out` | one exit 0, the other refused at its claim; the winner intact, nothing left by the loser |
| RV6-2a/b | mid-run parity refusal; a stale `.incomplete/` | nothing left; refused, the stale claim kept |
| RV6-3a–c | git tree through a symlink; default under `$HOME` (via a symlink); run in `$HOME/zk60-artifacts` | refused; accepted; refused (NOTE: the default is accepted when `$HOME` is a git tree) |
| RV6-4 ×11 | block 1 witnessed with one own field at the run's value | refused at block 1, 11 of 11 |
| RV6-5 ×13 | the honest receipt under other layer records | refused ("belongs to another run") |
| RV6-6 / 6b | swapped layer calibrations; receipt under swapped records | refused at block 0; refused |
| RV6-7 | 62 hostile receipts, without and with a recorder | 0 panics, 0 accepted, 0 bundles |
| RV6-8 | t34 cases on the honest prover path | 6 forgeries proved by the honest prover, all refused by the verifier: (i-a/b/c) at the LogUp H opening, (ii-a/b/c) at IN-00; the consistent other-prompt control accepted |
| t2 | the lane's token_io tests on the frozen tree (189 s, peak 2.43 GiB) | 44 passed / 0 failed / 8 ignored; 67 AS PREDICTED, 0 NOT (incl. the stage-IN controls and the three capture tests) |
| k0–k5 | layer-0 pre-check (light) | 6 python tests OK; voc0 clear with scope (also with 662/16309); b7 exit 2 by name; T128 voc0 variant not-covered (RoPE prefix) |
| p1–p3 | `profile`: fidelity export, verifier copy, b7 copy | `c3fb8c5b…` / `e8238cf1…` twice = the record's; `47f01943…` |
| c1–c4 | re-check; independent publication; owner; input-owner | statement-checked; byte-identical; token 11; 32 tokens |
| c5–c12 | b7 identity pin; b7 export; schema /1; own-calibration edits ×2; tamper; owner on tamper; the r6 /1 run | all refused, each by the predicted check |

## 6. Files

* My frozen copy: `ops/zkp-mvp/token-io-review-r7/`, with manifest
  `ops/zkp-mvp/token-io-review-r7.sha256`.
* `ops/zkp-mvp/token-io-review-r7-scratch/`:
  * `tree/.../token_io/cli/review_r6.rs`;
  * `tree/.../token_io/r3_tests/review_r6.rs`;
  * `prep_b8_r6.py`;
  * `launch_r6.sh`;
  * `launch_r6b.sh` (RV6-8);
  * `b8/` (hard-linked artefact copies).
* Logs: `results/zk60_token_io_review_r1_20261017/logs6/`, with the
  pre-check runs in `logs6/precheck/`.
* Ledger: `PROGRESS.md` (ROUND 6).
