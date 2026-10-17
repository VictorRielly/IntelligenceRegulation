# Hardening integration source review — 2026-09-18

Codex independent review of Fable's delivery
`12341e6d0498ed3d9bb51cfbfd58300425428f99`, against base
`db021baf38f2445a56463204293bb4f9685d93f4`. References below are to that
delivery, not subsequently edited working-tree files. The production review
covers `zkvm-block/host/src/main.rs`, `zkvm-block/wrap/src/main.rs`, the
shared native-tool validator, and the immediate runner/token interface.
No builds, proofs or tests were run by this review; the running token proof
and its binaries were untouched.

**Disposition:** no new policy-binding, image-binding, fake-receipt or
identity-conversion acceptance defect was found in the two block Rust files.
The delivered runner has a concrete token-profile CLI incompatibility, which
the parent independently found and is correcting. The cleanup and test
claims need the qualifications below. These changes do not modify the guest
or justify broader cryptographic privacy claims.

## Required integration correction

The delivered `scripts/zk60_zkvm_demo.py:675` appends `--keep-work` for both
profiles. Only the block wrapper accepts that ninth argument
(`zkvm-block/wrap/src/main.rs:258`). The current token wrapper accepts exactly
eight arguments for `wrap` (`zkvm-model/wrap/src/main.rs:226`), so a token run
fails with usage at the wrapping stage. Pass the flag only for the block
profile, or deliberately implement the same interface in the token wrapper.
Do not replace binaries being used by the active proof. This is an integration
blocker, not a cryptographic finding.

The parent separately owns the runner's public-output scan and cycle-gate
review. Their reported fixes are not counted as independently verified by
this Rust review.

## Environment, provenance and receipt checks

- Host `main` refuses all `RISC0_*`/`BONSAI_*` names **before** scrubbing
  (`host/src/main.rs:256`), then removes `RUST_LOG*` and explicitly sets
  `RUST_LOG=off` and `RUST_BACKTRACE=0`. The removed names are not printed;
  values are never returned. This preserves the prior fail-closed profiler,
  remote-prover and dev-mode boundary. The wrapper retains the same prefix
  refusal and explicit logging settings (`wrap/src/main.rs:275`). No silent
  acceptance of dev mode was introduced.
- `check-tools` and actual wrapping both call
  `zk60_native_tools::validate_tool_directory` (`wrap/src/main.rs:208,266`).
  The validator uses the same compiled five-file length/SHA-256 table,
  rejects symlink/non-regular final components and changed file identities
  between metadata and open, and checks execute bits. Its record-comparison
  test references a file present in the base commit. This establishes byte
  identity at validation time; it is not ceremony verification, a test that
  the executables run, or protection from same-user modification afterward.
- The incoming receipt must verify against the exact policy and compiled
  image with dev mode disabled, and must be succinct. Identity conversion's
  claim digest must equal that verified claim (`wrap/src/main.rs:140,190`).
  The outgoing receipt uses the original claim and journal, default Groth16
  parameters, and the existing full receipt verifier (`:167–175`). The
  verifier requires Groth16 and exact policy bytes before upstream
  `Receipt::verify_with_context`, which compares the verified claim with
  `ReceiptClaim::ok(image_id, journal_digest)`. The upstream implementation
  was checked in installed `risc0-zkvm-3.0.6/src/receipt.rs:171`.

## Cleanup behavior and wording

The wrapper creates a new `0700` work directory outside the canonical public
output parent. On an ordinary error after creation it retains the directory
and reports its path. On success it removes the directory unless
`--keep-work` is set (`wrap/src/main.rs:225–251`). Logs/input files are private;
the native `.dat` symlink is unlinked rather than followed during recursive
removal. Default cleanup is reasonable under the existing trusted local
filesystem assumption. The canonical-path checks do not track the created
directory's inode across an adversarial replacement, and the unit-test name
“anything but the directory this run created” should not imply otherwise.

Two claims should be narrowed or implemented:

1. `wrap/src/main.rs:94–95` says the inner seal does not outlive the run.
   Only the conversion work is deleted; the caller's original
   `INNER_RECEIPT` remains. Describe removal of conversion witness/log files
   and leave the original private receipt's lifecycle explicit.
2. `wrap/src/main.rs:239` describes the receipt as written and independently
   verified. The delivered code verifies the in-memory receipt **before**
   writing; it does not reread the saved file before cleanup. Preserve the
   runner's fresh-process verification, and preferably copy the token
   wrapper's saved-byte readback/verification before returning success and
   deleting work. The parent has committed to this small host-side change;
   this review has not yet inspected it.

The README's existing blanket statement that work is retained also needs to
describe default cleanup, explicit `--keep-work`, and failure retention.
Removing a work directory is file cleanup, not a claim of secure erasure.

## Exact limit of the new tests

The paused and conditional-claim tests use a 256-zero-byte seal
(`wrap/src/main.rs:381–437`). As their comments accurately state, they fail
seal integrity before the final expected-claim comparison. They therefore
test malformed-seal refusal with those object shapes; they would still pass
if the final expected-claim comparison were accidentally removed. The
wrong-parameter test does exercise the earlier context-parameter mismatch.

Retain that limited description. A lightweight direct comparison showing
that paused/nonempty-assumption claims differ from the expected `ok` claim
is useful semantic coverage, but is still not end-to-end coverage of the
post-integrity branch. A control using a valid recorded outer receipt and
altering only its journal, with matching altered expected policy, can reach
that branch while retaining the authentic seal and claim. No new proof is
needed for that control. The parent plans direct digest controls; do not
describe them as successful proofs of invalid claim shapes.

The cleanup tests call the removal/error-format helpers with synthetic
directories. They cover those helpers, not a completed wrapping lifecycle
or interruption recovery.

Finally, execution cycle counts (`host/src/main.rs:160–180`) can depend on
private inputs even though they are not raw witness values. Treat them as
private executor telemetry. A finite equal-count sample is not a constant-
time theorem, and D5's public outer Groth16 receipt does not expose the
inner segment count. The parent reports correcting the gate's scope.
