# R1d round evaluator — isolated candidate, 2026-09-22

Goal: reduce the complete private block's shared sumcheck work and provide
the owned-table interface needed for the slot evaluator/device follow-up.
This is not the completed 8B GPU model prover or a privacy acceptance.

`candidate-v1/`, `source-changes-v1.json` and `candidate-v1.patch` retain the
six changed/new files against the source-hashed shaped integration. The
working source is `/tmp/zk60-rounds-20260922`. Main's production prover has
not been changed. The initial candidate/patch and failed compile log are
retained too: a duplicate module registration was removed before v1 ran.

## Implemented

- Additive `SumcheckRounds`, `prove_rounds` and CPU `ClosureRounds`; no Sync
  bound on the trait, so an evaluator can own a non-Sync device handle.
- Optional `recover_one(initial_unmasked_claim)` skips the polynomial's
  evaluation at 1, reconstructing it from its actual unmasked running sum.
  `None` evaluates the first round in full. Debug builds independently
  evaluate the omitted value and assert the sum identity.
- Additive `zk::masked_prove_rounds`, using the existing transcript's masker.
  Existing `prove` and `masked_prove` function bodies are byte-identical to
  the baseline. Extension rounds, mask generation and the verifier are
  unchanged.
- The candidate's complete private-block caller uses the new path. Private
  slots seed it from their already-computed actual cube sum; host and
  standalone slots cannot assume their claimed identity holds on a bad
  witness, so recover only after computing the first round fully. This
  saves less work than the fully seeded R1d estimate but preserves invalid
  proof bytes/refusal behavior.
- Native test builds compare bounded actual slots against the original
  prover at identical tables and transcript, including published masked
  rounds, challenges, folded tables and the next transcript challenge.
  This oracle is absent from ordinary non-test builds.

## Evidence and limits

`validation-2/validation.json` is the completed aggregate gate and binds
the original `validation-1/validation.json` by hash. The first full native
run passed 511 tests and failed one because the isolated checkout omitted
an archived pre-lane receipt. The authentic receipt/policy were copied from
main and checked identical to the already passing shaped baseline; the one
test then passed without a source or binary change. The initial failure is
retained, not relabelled as a passing full invocation.
Core debug and release each passed 57 unit + 2 integration tests. The seven
new core tests cover degree 1–6, tagged/unkeyed transcripts, seeded/unseeded
recovery, serial/parallel folds, one/two masked extension rounds, exact
bytes and challenges, a wrong-claim control and non-Sync trait objects.
Release tests count calls to confirm evaluations really are skipped.

The native library and example compiled; all 512 native tests pass across
the full + targeted runs (17 explicitly ignored heavy tests remain ignored).
New receipts verify under old and new binaries; the old receipt verifies
under the new binary. All three verification processes reject their three
corruptions (nine controls). Sources are unchanged across these checks.
`validate.py` and `finish_validation.py` retain commands, source/log hashes
and exits. The public fixtures are pinned in `fixture-hashes.json` and
`pre-lane-fixtures.json`.

`benchmark.py` runs only after that validation passes. Its current/terminal
state is `dense-ab-1/comparison.json`. It compares the same dense synthetic 125M block on old/new binaries, two
samples per arm in A/B/B/A order under the heavy lock, with a memory check.
These are shared-CPU diagnostics, not a target workload or a publishable p95.
The candidate test binary retains the bounded-slot oracle, which adds
work absent from production; phase times must retain that qualification.
The four dense proofs passed at 40,783,352 bytes each. Softmax sumcheck:
old 9.053 / 9.258 s, new 8.590 / 8.551 s. The sum of the 23 rounded sumcheck
phase clocks is old 13.875 / 14.172 s, new 13.349 / 12.926 s. Whole proving
time is old 61.79 / 38.96 s, new 43.02 / 38.06 s; unchanged phases varied
too much to establish an end-to-end speedup. These two-thread shared-CPU
diagnostics do not replace the earlier 17.4–19.4-second measurements under
their original conditions. `measured-summary.json` retains the extraction
and the full comparison record's hash. Full-model GPU proving, trained
weights, larger-profile privacy and final integration acceptance remain open.
