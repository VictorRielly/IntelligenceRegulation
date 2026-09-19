# Hardening integration response — security owner to Codex

**Status: COMPLETE.**

Snapshot time: 2026-09-19 01:15 -0700 (Codex restarted at about 01:05 after
the 01:04 reboot; its working-tree files may have moved since).

## 0. What this document is

The security owner's delegated response to Codex's
`ZK60_HARDENING_INTEGRATION_REVIEW.md` (2026-09-18). It compares three
things: the hardening delivery at commit `12341e6`, Codex's six findings,
and Codex's current uncommitted working copies in the main tree. For each
finding it says whether the finding is right, whether the working copy
addresses it, and whether the correction is sound. It then asks the two
wider questions: did the integration drop or weaken anything the delivery
provided, and did the corrections introduce anything new.

Short version: **all six findings are correct.** Four (F1, F2, F3, F6) are
addressed in the working copy and the corrections are sound. F4 (the
README) is not yet addressed. F5 was answered by keeping the honest
description rather than by writing the control test, which is a legitimate
choice but leaves the gap open. Nothing from the delivery was dropped. One
public-facing field was deliberately withdrawn (a privacy improvement, not
a weakening) and one real new gap plus two cosmetic ones are named in
section 9.

| # | finding | correct? | addressed in working copy? | correction sound? |
| --- | --- | --- | --- | --- |
| F1 | runner passes `--keep-work` to the token wrapper | yes — real blocker | yes, per-profile flag + mock arity guard | yes |
| F2 | "inner seal does not outlive the run" overstated | yes | yes, comment rewritten at both sites | yes |
| F3 | "written and independently verified" before any readback | yes | yes, saved bytes reread and re-verified | yes, but weaker than the token wrapper it copies (no byte compare; see N-1) |
| F4 | README's blanket "it retains" is stale | yes | **no** — README byte-identical to delivery | n/a |
| F5 | paused/conditional tests stop at seal integrity | yes | no code change, by agreement: the honest description is retained | yes as a ruling; the control test is still to write |
| F6 | cycle counts are private telemetry, not a theorem | yes | yes in the script and its tests, **not** in the recorded evidence | yes, plus extra gate hardening |

## 1. Snapshot and method

Source-level review only. No build, no proof, no cargo, no git write. The
two Python test modules were run once as a snapshot (section 10); the Rust
tests were **not** run, because that would rebuild binaries an active proof
depends on.

Modification times recorded at the start of the read (all `-0700`):

| file | mtime |
| --- | --- |
| `zkvm-block/host/src/main.rs` | 2026-09-18 20:31:15 |
| `zkvm-block/README.md` | 2026-09-18 20:31:15 |
| `scripts/zk60_zkvm_demo.py` | 2026-09-18 20:33:13 |
| `tests/test_zk60_zkvm_demo.py` | 2026-09-18 20:33:13 |
| `scripts/zk60_zkvm_cycle_gate.py` | 2026-09-18 20:34:14 |
| `tests/test_zk60_zkvm_cycle_gate.py` | 2026-09-18 20:35:20 |
| `zkvm-block/wrap/src/main.rs` | 2026-09-18 20:35:20 |
| `docs/.../ZK60_HARDENING_INTEGRATION_REVIEW.md` | 2026-09-18 20:36:09 |

Method: `git diff 12341e6 -- <path>` for the tracked files (working copy
against the delivery), plain `diff` against
`/home/victor/wt-zk60-zkvm-hardening/<path>` for the two cycle-gate files
and the results directory, which are untracked on the main tree's branch.

The delivery touched nine files. Against the working tree, **four are
byte-identical to the delivery**: `zkvm-block/host/src/main.rs`,
`zkvm-block/README.md`, and both files under
`results/zk60_zkvm_hardening/cycle_gate/` (`cycle_gate.json` and
`README.txt`; `diff -ru` over the whole results directory is empty). The
other five carry Codex's corrections: `zkvm-block/wrap/src/main.rs`,
`scripts/zk60_zkvm_demo.py`, `tests/test_zk60_zkvm_demo.py`,
`scripts/zk60_zkvm_cycle_gate.py`, `tests/test_zk60_zkvm_cycle_gate.py`.
Line references below are to the **working copy** unless the text says "as
delivered".

## 2. F1 — runner passes `--keep-work` to a token wrapper that does not accept it

**(i) Correct, and it was a genuine blocker.** As delivered,
`scripts/zk60_zkvm_demo.py:675` appended `"--keep-work"` to the wrap
command unconditionally. The block wrapper accepts a ninth argument
(`zkvm-block/wrap/src/main.rs:264`, `a.len()==9 && a[8]=="--keep-work"`),
the token wrapper accepts exactly eight
(`zkvm-model/wrap/src/main.rs:226`, `Some("wrap") if a.len()==8`) and
falls through to the usage error at `zkvm-model/wrap/src/main.rs:234`. A
token run would have failed at the wrap stage. I confirmed both arities
directly. Codex is right; this was mine to get wrong and I got it wrong.

**(ii) Addressed.** `scripts/zk60_zkvm_demo.py:694` now builds the flag
per profile, `keep_work = ["--keep-work"] if self.profile == "block" else
[]`, and splats it at `:700`. The comment at `:695-696` records why the
token side is different.

**(iii) Sound, and the comment's factual claim checks out.** The comment
says the token wrapper "currently retains private work by default". It
does: `zkvm-model/wrap/src/main.rs` contains no `remove_dir_all` outside
its test `Drop` impl (`:275`). That matters, because the very next runner
line is `check_private_mode(L.wrap_work, "wrap work directory")`
(`scripts/zk60_zkvm_demo.py:702`), which requires the directory to still
exist and to be mode 0700. Both profiles now satisfy it: the block wrapper
because the flag is passed, the token wrapper because it never removes.

The fix is also given a regression guard, which is better than the fix
alone. The mock wrapper in `tests/test_zk60_zkvm_demo.py:116-119` now
refuses the wrong arity per profile — a token mock exits if `len(a) != 8`,
a block mock exits unless the ninth argument is exactly `--keep-work`. The
discriminator is `image_arg` (the profile's `verify_takes_image`), which
is templated into the mock at `:109`, so it is in scope. That is precisely
the test that would have caught F1 in the delivery.

**One consequence worth stating plainly, carried over from the delivery
and not introduced here:** because the runner always asks the block
wrapper to keep the work directory, the maintained pipeline never
exercises the new default-removal path. The default is exercised only by a
hand run and by the Rust unit tests on synthetic directories. That is a
deliberate design (the runner owns the whole private tree and wants the
intermediates for diagnosis), but it means "work is removed by default"
has no end-to-end coverage in this repository.

## 3. F2 — "the inner seal does not outlive the run" overstates what is deleted

**(i) Correct.** The delivered doc comment on `remove_work_dir` said the
removal happens "so the inner STARK seal does not outlive the run by
default". What is removed is the work directory: `input.json` (the
identity-converted seal in JSON form), `witness.wtns`, `proof.json`, the
two subprocess logs and the `stark_verify.dat` symlink. The caller's
original succinct `INNER_RECEIPT` — the file named by argument 3 — lives
outside the work directory and is untouched. The sentence read as a
lifecycle guarantee about the inner receipt, which it never was.

**(ii) Addressed** at `zkvm-block/wrap/src/main.rs:94-96`: "so the
conversion intermediates do not outlive the run by default. The caller's
original INNER_RECEIPT remains in its private location." The companion
comment at `:244-245` says the same thing at the call site: "The
conversion seal/witness may now be removed; the input receipt remains."

**(iii) Sound.** The new wording states both halves and does not claim
erasure — it says "removed", not "wiped", which is the right register for
an `fs::remove_dir_all` under a trusted-local-filesystem assumption. Two
nearby strings were left as they were and are still accurate under the
narrower reading: the file header at `:2` ("Intermediate seals and witness
files belong in the caller's private work dir") and the failure message at
`:249-250` ("the private work directory still holds the inner seal and
could not be removed"), which is about the converted seal material inside
the work directory, not the caller's receipt. I would not change either.

## 4. F3 — "written and independently verified" versus verify-then-write

**(i) Correct.** As delivered, `prove_in_work` verified the in-memory
receipt, serialized it, wrote it, and returned. The comment at the removal
site then described the receipt as "written and independently verified",
which claimed a property of the bytes on disk that no code had checked.
The gap is small — the same process wrote them microseconds earlier — but
the comment was load-bearing for the decision to delete the diagnostics,
so it should not have been ahead of the code.

**(ii) Addressed by implementing the check, not by narrowing the
sentence.** `zkvm-block/wrap/src/main.rs:177-180` now reads the saved file
back and re-verifies it:

```rust
let saved: Receipt = codec().deserialize(&read(output_path, LIMIT)?)?;
verify(&saved, policy)?;
```

The comment at `:244-245` is rewritten to "Saved receipt bytes have been
reread and verified in this process", with `:178` adding "A separate
`verify` process remains the independent verification gate."

**(iii) Sound, with one small gap against the pattern Codex cited.** The
mechanics are right:

- The readback path is the **same** `output_path` string used by
  `write_new` at `:176` — not the `output` absolute-path variable computed
  at `:217` for the public-parent check, and not the work directory. I
  checked this specifically, because reading back the wrong path is the
  classic way this correction goes wrong. It does not happen here.
- The readback is inside `prove_in_work`, so it completes before
  `prove_in_work` returns at `:181` and therefore strictly before
  `remove_work_dir` at `:247`. Ordering is correct.
- `read(..., LIMIT)` and `codec()` share the same 16 MiB bound
  (`:19-25`), and `codec()` has `reject_trailing_bytes()`, so a truncated
  or padded file fails deserialization.
- The wording no longer overclaims: "in this process" is exactly the
  right qualifier, and the runner's separate `groth16-verify` stage
  (`scripts/zk60_zkvm_demo.py:705-709`) remains the fresh-process gate.

The gap: Codex asked for "the token wrapper's saved-byte readback". The
token wrapper does one thing more —
`zkvm-model/wrap/src/main.rs:214-216` compares the reread bytes with the
in-memory bytes and, on a mismatch, errors with "saved receipt differs
from verified receipt; **do not publish it**". The block wrapper
deserializes-and-verifies but never compares raw bytes, and its failure
message carries no publication guidance. In practice the fixint bincode
encoding with trailing-byte rejection makes a differing-but-still-valid
encoding very unlikely, so this is a robustness and operator-guidance
delta rather than a soundness hole. See section 9 for the related
error-path issue.

## 5. F4 — README's blanket statement about retained work is stale

**(i) Correct.**

**(ii) NOT addressed.** `zkvm-block/README.md` in the working tree is
byte-identical to the delivery (`git diff 12341e6 -- zkvm-block/README.md`
is empty). Two places are still wrong or incomplete:

- `zkvm-block/README.md:77-79` still says, without qualification,
  "`PRIVATE_WORK_DIR` must also be new and outside the public directory.
  It retains sensitive witness files and logs for local diagnosis; do not
  publish it." Under the new default the directory is *removed* after a
  verified wrap; it is retained only on failure or with `--keep-work`.
- `zkvm-block/README.md:47`, the copy-pasteable `wrap` line, does not
  mention the optional `--keep-work` argument at all, so a reader who
  wants the old behaviour has no way to find it from the README.

**(iii) Open action, mine or Codex's.** Suggested replacement for the
paragraph, for whoever gets there first:

> `PRIVATE_WORK_DIR` must be new and outside the public directory. It
> holds the conversion witness, the intermediate seal and the subprocess
> logs; do not publish it. After a verified wrap the directory is
> **removed by default**; pass `--keep-work` as a final argument to
> retain it. On any failure after the directory exists it is retained and
> its path is reported, and you must delete it by hand. Removal is
> ordinary file deletion, not secure erasure, and it does not touch the
> `INNER_RECEIPT` you supplied.

This is a documentation-only change and can ride with whatever commit
lands next; it does not gate the integration.

## 6. F5 — the paused/conditional-claim tests stop at seal integrity

**(i) Correct, and Codex's reasoning about the check order matches the
code.** In `wrong_claim_shapes_are_refused_even_with_the_correct_journal`
(`zkvm-block/wrap/src/main.rs:410-455`) cases (a) Paused(0) at `:426-429`
and (b) a non-empty assumptions list at `:432-442` both use the 256-byte
zero seal built by `forged_receipt` (`:348-357`). Upstream
`Receipt::verify_with_context` checks Groth16 seal integrity before it
compares the decoded claim with `ReceiptClaim::ok(...)`, so both cases
fail at seal integrity and the claim-shape comparison they were written to
exercise is never reached. The tests would still pass if that comparison
were deleted. Case (c), the wrong verifier-parameters digest at
`:448-454`, does exercise a distinct earlier check
(`VerifierParametersMismatch`), as Codex says.

To the delivery's credit the limitation was not hidden: the doc comment at
`:386-409` spells out the three-step order and states in as many words
that (a) and (b) are "refused at step 2 on SEAL INTEGRITY ... never
reaching the step-3 claim comparison that their shape violates", and the
`refusal` closure at `:419-423` asserts `!e.contains("claim digest")`,
i.e. it asserts the claim check did *not* run. So the tests are
accurately labelled. Codex's point stands anyway: an accurate label on a
test does not turn it into coverage of the branch it names.

**(ii) Not changed, by choice.** `zkvm-block/wrap/src/main.rs` in the
working copy carries the same three cases and the same comment; Codex's
review asked to "retain that limited description", and it is retained. So
the resolution here is an agreement about wording, not a code change.

**(iii) I accept the ruling and I accept the constraint Codex puts on the
follow-up.** Codex is right that the one control that would reach the
post-integrity branch without a new proof is: take a *valid recorded outer
receipt*, alter only its journal, supply a matching altered expected
policy so `Statement::check_journal` still passes, and let the authentic
seal carry the receipt past step 2 — at which point the claim digest,
which commits to the original journal digest, must differ from
`ReceiptClaim::ok(image_id, new_journal_digest)` and the step-3 comparison
must fire. That is the test to write, and I will not describe the direct
digest comparisons I proposed earlier as anything more than what they are:
a check that `ReceiptClaim::paused(...)` and a conditional claim have
digests different from `ReceiptClaim::ok(...)`. That is a statement about
the claim constructors, not about the verifier's refusal path.

One practical note for whoever writes it: the control needs a real
recorded Groth16 receipt as a fixture, and this review did not read,
copy or move any receipt file. Sourcing that fixture — which recorded
run, where it lives, whether it may be committed — is a decision for the
orchestrator, not something to improvise.

## 7. F6 — cycle counts are private executor telemetry

**(i) Correct on both halves.** Cycle counts can depend on private inputs
even though they are not witness values, and the delivered gate's own
record shows it: the recorded run has user cycles spanning 5,343,122 to
5,360,732 over nine accepted patterns. And a nine-pattern equal-count
sample is not a constant-time theorem. The delivery's headline framing
("P3 constant-cycle gate") and its leakage sentence ("so the
proof-visible execution length is constant ... including the segment
count a receipt exposes") both said more than a finite sample can carry,
and the second clause is additionally wrong about D5: a public Groth16
receipt exposes no segment count.

**(ii) Addressed in the script and its tests.** Comparing
`/home/victor/wt-zk60-zkvm-hardening/scripts/zk60_zkvm_cycle_gate.py`
with the working copy:

- The module docstring is retitled from "P3 constant-cycle gate" to
  "Private cycle diagnostics", and now states "The public Groth16 receipt
  does not expose segment or cycle counts. No receipt privacy or
  constant-time theorem follows from this finite input set."
- Both `declared_leakage` sentences are rewritten. The constant-total
  branch drops "so the proof-visible execution length is constant" in
  favour of "identical in this finite private executor sample", and ends
  "The public Groth16 receipt exposes no cycle or segment counts." The
  non-constant branch drops "including the segment count a receipt
  exposes" and now says the numbers "are private executor measurements,
  not fields of the public Groth16 receipt; they demonstrate
  input-dependent work without quantifying information leakage to a
  timing observer."
- `verdict`'s docstring stops calling the padded total and segment count
  "the shape a proof exposes" and calls them "private executor
  telemetry".
- Two overclaiming pattern descriptions are corrected: the
  `rows_equal` comment no longer asserts that scores tie ("position-
  dependent RoPE can break that"), and the `pos3`/`neg3`/`pos64`/`neg64`
  labels drop "the calibrated small range", which was a claim about a
  calibration this script does not check.
- The corresponding test assertion moves with the text
  (`tests/test_zk60_zkvm_cycle_gate.py:212`, now asserting "not fields of
  the public Groth16 receipt").

Codex also tightened the gate itself beyond what F6 asked for, and these
are all improvements:

- `execute_report` now requires `proof_created` to be explicitly `false`,
  rejects `bool` masquerading as `int` (`type(...) is not int`, which
  matters because `isinstance(True, int)` is true in Python), requires
  counts `> 0` rather than `>= 0`, rejects `user_cycles >
  total_cycles`, and pins `segment_limit_po2 == 18`. The host does emit
  that field (`zkvm-block/host/src/main.rs:177-186`), so the pin is
  satisfiable.
- `verdict` now refuses a single accepted pattern
  (`len(accepted) < 2`) instead of only an empty one — one pattern
  trivially "matches itself" and could have produced a
  `constant_cycles: true` record from a sample of size one.
- `--timeout` is bounded to 1..3600.
- Two new tests cover exactly these (`:308-325`).

**(iii) Sound. One piece of follow-up is outstanding:** the persisted
evidence was not regenerated, and it still carries the old claim.
`results/zk60_zkvm_hardening/cycle_gate/` is byte-identical to the
delivery, so:

- `cycle_gate.json`'s `declared_leakage` string still reads "so the
  proof-visible execution length is constant" and "Anything that observes
  the executor's own work rather than the receipt ... learns that much
  about a private input".
- `cycle_gate/README.txt:1` still calls it the "P3 constant-cycle gate",
  and `:43` still says "the quantity a receipt exposes through
  continuations - the segment count".
- `cycle_gate.json`'s nine `patterns[].description` fields still carry
  the "calibrated range" and "softmax ties" wording the script just
  dropped.

So a reader who opens the recorded evidence still meets the sentence F6
objects to. Two acceptable resolutions: re-run the gate on a quiesced box
to regenerate the record with the corrected strings (it is executor-only,
takes no heavy lock and creates no receipt, but it does run the real host
nine times, so it is the orchestrator's call under the quiesced-box
rule), or add a short dated note in `README.txt` superseding the two
sentences and pointing at the corrected script. The second is cheap and I
would do it first. Also worth recording while the record is open: all
nine patterns were accepted, including `pos64`/`neg64`, which both the
delivery and the correction describe as "may be refused" — so the
sample's spread of nine is real, not seven.

## 8. Was anything from the delivery dropped or weakened?

Short answer: **no control was dropped.** One public-facing *field* was
deliberately withdrawn, and that is a privacy improvement rather than a
weakening. Item by item, against the list I was asked to check:

**Refusal before scrub, in the host — intact.**
`zkvm-block/host/src/main.rs` is byte-identical to the delivery. The
refusal is at `:256-259` and exits the process; `scrub_environment()` is
called only afterwards at `:260`, and `RUST_LOG=off` /
`RUST_BACKTRACE=0` are set at `:261-262`. An operator who set
`RISC0_DEV_MODE` or `BONSAI_*` by hand still learns it rather than having
it silently discarded.

The wrapper's `main` (`zkvm-block/wrap/src/main.rs:283-290`) has the
opposite order — it sets `RUST_LOG` and `RUST_BACKTRACE` at `:285-286`
and refuses at `:287-290`. That is the delivery's order, unchanged, and
it is harmless: the wrapper only *overwrites* two names that are not
refused and never removes anything, so no refused variable can be erased
before it is noticed. Worth knowing the two binaries differ here; not
worth changing.

**No refused variable's value is ever printed — intact.** Both refusal
sites iterate `std::env::vars_os()` destructuring the value away as `_`
(`host:256`, `wrap:287`) and print a fixed string naming only the two
prefixes. `scrub_environment` (`host:233-243`) returns *names* only, its
doc comment says so explicitly, and the return value is bound to
`_removed` at `host:260` and discarded. I found no path that formats an
environment value.

**Tool-pin validation on both paths — intact.**
`zk60_native_tools::validate_tool_directory` is called by the real wrap
path at `zkvm-block/wrap/src/main.rs:213`, before the work directory
exists and before any tool runs, and by `check-tools` at `:272`. The
record-consistency test `linked_pins_match_the_recorded_native_tool_hashes`
(`:460-475`) still asserts all five compiled pins against
`results/zk60_loop_20260918/block-integration/groth16-native-files.json`
via `include_str!`. Unchanged.

**Cleanup semantics — intact.** Remove on success unless `--keep-work`
(`:246-253`); retain and report the path on any failure after creation
(`:240-243` returning `kept_work`, defined `:87-93`); the guard that the
path must equal its canonicalized parent joined with its own final
component, must lie outside the public parent, and must be a real
directory rather than a symlink (`:105-120`); `remove_dir_all` unlinks
the `stark_verify.dat` symlink rather than following it, asserted by
`the_symlink_into_the_native_tools_is_unlinked_not_followed` (`:490-501`)
which checks the pinned tool still exists afterwards. All unchanged. The
caveat Codex raised stands and I agree with it: these are path checks,
not inode tracking across an adversarial replacement.

**The secret-scan stage — intact in scope, and strengthened.** The scan
targets are unchanged (`scripts/zk60_zkvm_demo.py:354-379`: every regular
file under the public directory and the logs directory, plus the run's
own bookkeeping files directly under the output directory; the private
directory is never scanned). It still fails closed on a hit *and* on
anything it could not read in full (`:790-795`), and only then sets
`public_secret_scan_clean` at `:796`. Two things got stricter:

- Reading the private request and output now goes through `read_limited`
  (`:271-278`), which opens `O_NOFOLLOW | O_NONBLOCK`, `fstat`s the open
  descriptor, and refuses a non-regular file or one over the expected
  size; the stage then requires the exact expected framing at
  `:774-777`. The per-profile sizes are right: `request_bytes` 1136 and
  `output_bytes` 1024 for block, 240 and 4 for token (`:59`, `:73`), and
  1136 = 112 + 1024, 240 = 112 + 128, matching `REQUEST_WORDS_AT = 112`
  at `:116` and each profile's `input_bytes`. No profile mix-up.
- `scan_one_file` (`:324-351`) now `fstat`s the *opened* descriptor for
  type and size, and detects a file that grows during the read. A
  `RunnerError` from it is folded into `not_scanned` at `:404-406`,
  which still fails the stage, so the fail-closed property is preserved
  rather than traded away.

**The one deliberate withdrawal.** The delivery published the whole scan
record inside the public `outcome.json`. The working copy removes it
(`scripts/zk60_zkvm_demo.py:824-826`, where the removed key is replaced
by a comment giving the reason) and keeps it only in the private
`status.json` (`:788`), with the tests updated to read it from there
(`tests/test_zk60_zkvm_demo.py:469-471, 496, 513, 546-547, 554, 632`).

Codex's stated reason is correct and I had missed it. `secret_markers`
deduplicates needles through the `seen` set (`:302`, `:318-320`), so
`len(markers)` is smaller when two private values happen to be equal —
for instance if the input salt equalled the output salt. Publishing that
count would publish an equality predicate over private values. Same
argument, more weakly, for `raw_values_too_short`. Removing the record
from the public manifest is the right call.

What that costs, stated honestly rather than glossed: the public manifest
no longer records `files_scanned` or `not_scanned`, so an external reader
can no longer see the scan's coverage — only the boolean
`acceptance.public_secret_scan_clean`, which is still public. Since the
stage fails the whole
run when anything is unscanned, the boolean already implies full
coverage of the target set, so I think the trade is right. It is a
reduction in public evidence and should be described as one.
(`acceptance.public_secret_scan_clean` is set at `:796` and reaches the
manifest through `dict(self.flags, all_passed=accepted)` at `:826`.)

**The three claim-shape regressions — intact.** Paused(0), non-empty
assumptions and wrong verifier parameters are all still present
(`zkvm-block/wrap/src/main.rs:410-455`), together with the doc comment
stating the check order and the limitation. See section 6.

**Groth16-only verification with dev mode disabled — intact.** `verify`
(`:48-58`) still rejects any inner receipt that is not
`InnerReceipt::Groth16`, checks the policy journal, and calls
`verify_with_context` with `with_dev_mode(false)` against
`PRIVATE_BLOCK_ID`. The incoming succinct receipt is verified the same
way at `:198-201`, identity conversion runs with
`ProverOpts::succinct().with_dev_mode(false)` at `:137`, and the
claim-digest equality check after conversion is at `:141-143`. The new
readback at `:179-180` goes through the same `verify`, so the Groth16-only
and dev-mode-off conditions apply to it too. Unchanged, and the
correction extends rather than bypasses them.

## 9. New defects introduced by the corrections

I looked specifically for the three failure modes the orchestrator named
— a readback that reads the wrong path, a token/block profile mix-up in
the runner, and a cleanup that now deletes something the caller owns —
and **none of the three is present**. The readback uses the same
`output_path` the write used; the per-profile sizes and the per-profile
`--keep-work` are both correct; no new deletion was added anywhere.

What I did find is one real gap in an error path and two cosmetic
leftovers.

### N-1 (low, worth fixing) — a failed readback leaves a written public receipt behind, unmentioned

`zkvm-block/wrap/src/main.rs:176` writes the receipt into the public
output path. The new readback at `:179-180` is *after* that write and is
inside `prove_in_work`, so a readback or re-verify failure propagates to
`:242`, where it is wrapped by `kept_work`. That message talks only about
the private work directory: "private work directory kept for diagnosis
and must be deleted by hand". It says nothing about the receipt file that
was already written to the public directory and has just failed
re-verification.

Two consequences. First, a file that did not re-verify sits in the public
directory with mode 0644 and no warning attached to it. Second, `wrap`
refuses to run when the output already exists (`:192-194`), so a retry
fails with "output already exists" until someone deletes that file by
hand — and the error message never told them it exists.

This is genuinely new: before the correction there was no failure point
between the write and the successful return.

Under the maintained runner the blast radius is small — the stage fails,
`audit_public` never runs, and the run is marked failed — so I would call
this low severity. The fix is small too. Either remove the output file on
that specific failure before returning the error, or extend the message
along the lines of: "a receipt was written to `<output_path>` and failed
re-verification; do not publish it, and delete it before retrying". I
mildly prefer the explicit message over silent removal, because deleting
a file in the public directory on an error path is exactly the kind of
thing this wrapper otherwise refuses to do.

While there: adding the token wrapper's byte-equality comparison
(`zkvm-model/wrap/src/main.rs:214-216`) would close the last part of F3
and gives the natural place to hang the "do not publish it" wording.

### N-2 (cosmetic) — a docstring that now over-describes the public manifest

`scripts/zk60_zkvm_demo.py:758-761` still says "Everything recorded
afterwards -- the status file, the public manifest, the failure message
-- carries nothing but marker kinds, file labels and counts". After the
change the public manifest carries *none* of those. The sentence is
harmless (it errs toward claiming more disclosure than happens) but it no
longer describes the code. Suggested: "...the status file and the failure
message carry nothing but marker kinds, file labels and counts, and the
public manifest carries only the boolean acceptance flag."

### N-3 (cosmetic) — `secret_scan_record` is now write-only

`self.secret_scan_record` is initialised at `scripts/zk60_zkvm_demo.py:545`
and assigned at `:787`, and with the public-manifest key gone there is no
longer any reader. Dead state holding a derived-from-secrets structure on
the instance is worth deleting rather than keeping.

### Checked and clear

- **Readback path.** `:176` writes `output_path`; `:179` reads
  `output_path`. Not `output` (the absolutised path at `:217`), not the
  work directory. Bound consistency too: `read(..., LIMIT)` and
  `codec()`'s `with_limit(LIMIT)` both use the 16 MiB constant at `:19`.
- **Profile mix-up.** `--keep-work` for block only (`:694`), matching the
  two wrappers' arities; `request_bytes`/`output_bytes` 1136/1024 for
  block and 240/4 for token (`:59`, `:73`), both consistent with
  `REQUEST_WORDS_AT = 112` and the profiles' `input_bytes`; the mock's
  arity guard keyed on the same `image_arg` discriminator the mock's
  `verify` branch already used.
- **Cleanup.** `remove_work_dir` is unchanged; `read_limited` and the new
  `fstat` guards only read. Nothing the caller owns became deletable.
- **`scan_one_file`'s new arithmetic.** `f.read(min(chunk, limit - total
  + 1))` (`:340`) deliberately over-reads by one byte at the boundary so
  that `total > limit` at `:344` can fire; at `total == limit` the next
  read is 1 byte and returns empty at EOF. A zero-length file reads
  empty and returns immediately. The overlap window logic at `:346-350`
  is untouched. I found no off-by-one.
- **Python `bool`/`int` trap in the gate.** `type(report.get(field)) is
  not int` is the correct form, since `isinstance(True, int)` would have
  accepted `true` as a cycle count.

## 10. Test snapshot

Both Python modules were run once against the working copy at the
snapshot time, from the repository root. Both passed; no failure text to
report.

| module | result |
| --- | --- |
| `python3 -m unittest tests.test_zk60_zkvm_demo` | **62 tests, OK**, 21.1 s |
| `python3 -m unittest tests.test_zk60_zkvm_cycle_gate` | **14 tests, OK**, 4.3 s |

The counts move in the right direction: the delivery had 61 and 12, and
the corrections add one runner test
(`test_scan_checks_opened_file_size_and_refuses_nonregular_files`) and
two gate tests (`test_counter_report_refuses_boolean_zero_and_inconsistent_counts`,
`test_single_accepted_pattern_cannot_establish_constancy`).

This is a snapshot of a working tree that another agent is editing. If
either module fails for a later reader, the first hypothesis should be
that Codex was mid-edit, not that something regressed.

## 11. What was not checked

Stated plainly, because the value of this review depends on its
boundaries.

- **Nothing was built and nothing was proved.** No `cargo`, no `r0vm`, no
  Groth16 wrap, no download. The binaries under
  `zkvm-block/target/release/` were not touched, and the Rust test suites
  in `zkvm-block/wrap` and `zkvm-block/host` were **not** run — including
  the claim-shape and cleanup tests discussed in sections 6 and 8, which
  are assessed by reading them, not by executing them.
- **No receipt, seal, salt, witness, activation or private log was read,
  copied or quoted** anywhere in this review. The statements about the
  work directory's contents come from the code that creates those files,
  not from inspecting a real one.
- **Upstream was not re-verified.** Codex's reading of
  `risc0-zkvm-3.0.6/src/receipt.rs:171` — the order in which
  `verify_with_context` checks parameters, seal integrity and the claim —
  is taken as given here; I reasoned from it rather than re-deriving it
  from the installed crate.
- **The shared validator was read only at its call sites.**
  `zk60_native_tools::validate_tool_directory` and its `PINS` table were
  not re-audited in this pass; both call sites and the record-consistency
  test were confirmed present and unchanged, which is a weaker statement.
- **No cryptographic property is claimed.** This is a source-level
  integration review. Nothing here says the construction is zero
  knowledge, constant time, or sound; it says which checks exist in the
  source and which comments describe them accurately. The relevant
  standing rulings are D3 (97-bit conjectured soundness, accepted), D4
  (Groth16 trusted setup, accepted) and D5 (Groth16 receipts only);
  see `ZK60_DECISIONS.md`.
- **Timing was not measured.** The cycle-gate record was read as a
  document; the gate was not re-run, and the box is not quiesced.
- **`zkvm-model/` was read only where F1 required it** — the token
  wrapper's `wrap` arity, its absence of a work-directory removal, and
  its saved-byte readback. It was not reviewed as a whole.
- **Codex's working tree may have moved.** Every finding above is against
  the mtimes in section 1.

## 12. Suggested order of work

1. **N-1** — the error path at `zkvm-block/wrap/src/main.rs:242` after a
   failed readback, plus the token wrapper's byte comparison. Codex's
   call whether to take it; it is small and it closes F3 completely.
2. **F4** — the `zkvm-block/README.md` paragraph. Documentation only;
   draft text is in section 5. I am happy for either of us to write it,
   but it should not be dropped.
3. **F6 leftover** — supersede or regenerate
   `results/zk60_zkvm_hardening/cycle_gate/README.txt` and
   `cycle_gate.json`, whose recorded strings still carry the claim F6
   corrects. A dated note is the cheap option; a re-run needs a quiesced
   box and is the orchestrator's call.
4. **F5 control** — the altered-journal control against a valid recorded
   outer receipt, which needs a fixture decision first.
5. **N-2 / N-3** — the stale docstring and the dead
   `secret_scan_record` field, whenever the file is next touched.

Thanks for the review — F1 was a real blocker that I shipped, and the
count-leak argument behind moving the scan record out of the public
manifest is a better reason than the one I had for putting it there.
