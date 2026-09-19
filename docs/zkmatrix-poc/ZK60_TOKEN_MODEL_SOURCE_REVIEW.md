# Token-model zkVM source review — 2026-09-18

Reviewer: Codex independent reviewer. Delivery: Claude Fable 5.1's
`/tmp/wt-zk60-loop-fable-20260917/zkvm-model`, reviewed without changing its
files. Only this review document was written for this task.

**Disposition:** the token/model/journal bindings are coherent on source
inspection. The delivered standalone host had an inherited profiling-output
gap; the parent's host/wrapper fix was subsequently inspected and closes that
specific route. No guest-image change is requested by this review. No accepting token-model receipt,
guest execution, Rust build or Rust test was produced by this review. The
delivery's tests and README are proposed validation, not run evidence. Later
parent-led integration results must be recorded separately; an earlier block
receipt is not evidence for this new guest.

D3 and D4 are accepted decisions, not new approval questions. D7's concrete
statement/profile disposition remains pending as recorded in
`ZK60_DECISIONS.md`. This review neither changes those decisions nor declares
the synthetic token model to be a trained/model-scale MVP.

## 1. Concrete privacy finding: inherited profiling can write outside private logs

**Action required for the standalone host.** `host/src/main.rs:51` refuses
`RISC0_DEV_MODE`, `RISC0_PROVER` and `BONSAI_*`, but permits
`RISC0_PPROF_OUT`. Setting `RUST_LOG=off` at line 213 does not disable this
separate output mechanism. The executor environment is built at lines 164–170.

The installed, pinned `risc0-zkvm-3.0.6` source establishes the complete path:

- `src/host/client/env.rs:159`: `ExecutorEnvBuilder::build` reads
  `RISC0_PPROF_OUT` when no explicit profiler path is set.
- `src/host/api/client.rs:659` sends that path to the external server;
  `src/host/api/server.rs:873` enables its profiler.
- `src/host/server/exec/executor.rs:109` attaches the execution trace profiler;
  line 279 writes its report with `std::fs::write` to that path.
- `src/host/server/exec/profiler.rs:15` describes the report as cycle counts
  per execution location/call stack, excluding trace padding. The token
  kernel explicitly has secret-dependent control flow
  (`private-model-kernel/src/lib.rs:27`, `:261`).

Consequently an inherited `RISC0_PPROF_OUT=/some/public/profile.pb` can create
an additional execution-dependent artifact, using ordinary filesystem/umask
permissions, despite protected stdout/stderr. This is a source-confirmed
output route, not a demonstrated token-recovery attack or a claim that a
current run leaked. No private execution was run to reproduce it here.

Smallest fix: reject or remove this variable before building an execution
environment, and cover it in the CLI environment-refusal regression. Use the
same policy in the wrapper for consistency; this review has not established
that its identity-only path invokes the guest profiler.

**Existing mitigation:** the parent's block runner
`scripts/zk60_zkvm_demo.py:178` already strips every `RISC0_*` variable.
Reusing that actual sanitized environment for the token runner prevents this
path. The finding applies to the delivered standalone CLIs and the README's
direct commands, not automatically to a sanitized parent-led run.

**Parent integration addendum, independently inspected:** root
`zkvm-model/host/src/main.rs:51` and `wrap/src/main.rs:59` now refuse every
`RISC0_*` and `BONSAI_*` name before command execution. Their predicate tests
include `RISC0_PPROF_OUT` and an unknown `RISC0_*` name. The analogous block
CLI guards were also inspected. This closes the identified environment route
in those source copies; test/build execution belongs to the parent. The
updated token host/wrapper SHA-256 values are respectively
`6529f611dfdae80fef5d93a6eeed6c5c5952bd1bcbf848c174fe3c78421073c7` and
`7f9780475db8fbba81f9480d1b0ecc4867a7bc315b56bcf70fc21e67d40ef2ea`.
Guest, model and statement source still match the delivery hashes below.

## 2. Bindings checked in the delivered source

| Boundary | Source and conclusion |
|---|---|
| Complete computation | `methods/guest/src/main.rs:14` reads fixed-size model/request/policy buffers, decodes each, calls `Request::compute`, compares the complete resulting statement, and commits only its encoding. It accepts no claimed activation, logit or output token. |
| Complete model identity | `model/src/lib.rs:65` decodes embeddings, both complete ordered block payloads, final gamma and head; line 96 validates their structure and hashes the exact original payload. `statement/src/lib.rs:74` hashes a model-specific domain, profile, explicit length and every payload byte. |
| Actual model relation | `private-model-kernel/src/lib.rs:284` validates all 32 IDs, gathers embeddings, passes block 0's output directly to block 1, normalizes the last row, computes the head and returns the lowest-index greedy maximum. Calibration constants, shapes and tie semantics are bound through the independently approved image ID. Tables supplied in the model remain bound through the model digest. |
| Private endpoints | `model/src/lib.rs:142` commits the actual input IDs and recomputed output ID. `statement/src/lib.rs:91` binds profile, role, context, model digest, salt, exact token count and every little-endian token word. Input/output counts are 32/1. |
| Public journal | `statement/src/lib.rs:44` emits exactly 144 bytes: the new 16-byte profile and four 32-byte values. `check_journal` at line 62 compares every byte against caller-supplied policy; it does not adopt a candidate receipt's policy. |
| Public acceptance | `wrap/src/main.rs:73` requires Groth16, exact journal equality and upstream receipt verification with dev mode false. The CLI first checks the independently supplied image-ID argument against its compiled image at line 237. Fake, composite and succinct variants cannot enter this public acceptance path. |
| Inner-to-outer claim | `wrap/src/main.rs:151` requires and verifies the real succinct input. Line 186 checks the converted claim digest. Lines 215–225 use the original verified claim and journal, default verifier parameters, and verify both the newly constructed receipt and the saved bytes. |

The actual relation is a successful execution of this bounded, possibly
refusing integer program. Shape/table validation is not model approval or a
claim that arbitrary models/inputs always run successfully. The caller must
authenticate the model digest, complete policy and image independently.

`Model` has public fields, but the reviewed guest constructs it only through
`Model::decode`; no caller-provided Rust object bypasses that decoder in the
guest. Guest failure prevents an accepted successful receipt. Host-only
precomputation does not replace the guest's recomputation.

The new `zk60-r0-token-v1` framing, endpoint/model domains and new image
separate it from `zk60-r0-block-v1` and the PCS profile. Hash separation is
computational under SHA-256 assumptions, not a literal impossibility of hash
collisions. These endpoints do not establish a cross-profile or cross-receipt
block chain; both blocks are recomputed inside one guest.

## 3. Privacy and operational premises that remain explicit

The public privacy argument is the previously reviewed external Groth16
argument, conditional on a well-formed corresponding CRS, fresh honest
Groth16 proving randomness, faithful tools and the cryptographic assumptions
recorded in `ZK60_ZKVM_SOURCE_REVIEW.md`. It does not require an unproved claim
that publishing the inner STARK is zero knowledge. Inner proof soundness is
still required for the composed computation claim. This review supplies no
new ceremony verification or token-profile proof measurement.

`prepare` samples context and both salts from disjoint portions of one OS
random draw (`host/src/main.rs:110`), puts request/output in a new `0700`
directory with `0600` files, and publishes only policy/model files
(`:129`). The host saves succinct receipts with mode `0600` (`:185`). The
wrapper refuses a symlink/non-regular or group/other-readable inner file and
one located under the public artifact directory (`wrap/src/main.rs:93`).
New native work directories are `0700`, explicit inputs/logs `0600`, and
native helper output remains below that protected directory (`:103`, `:164`).
These checks assume trusted local directory ownership; they are not an
adversarial-filesystem race defense.

Salt quality is an honest preparation premise, not something the guest can
prove from bytes. In particular, a known output salt permits enumeration of
32 output IDs. Repeated proofs of the same fixed endpoint can keep that
endpoint's salt/value; they still require fresh outer proof randomness and
must not publish the private request or inner proof.

The host caps guest segments at `2^18` and total execution at 64 Mi cycles
(`host/src/main.rs:168`). Bounded file sizes and strict bincode decoding are
present. Those are not wall-clock or process-memory limits: r0vm/native
helper calls have no CLI deadline, and the native helper limits only stack
size plus Go concurrency (`wrap/src/main.rs:112`). Use the parent's bounded
process-group runner and private outer logs for execution/proving/wrapping.
The upstream r0vm child inherits standard streams
(`risc0-zkvm-3.0.6/src/host/api/mod.rs:224`).

The wrapper checks native filenames, not their provenance or SHA-256
(`wrap/src/main.rs:160`). An absolute r0vm path likewise is not a binary
integrity check. Run with the separately pinned official extraction and
record the actual executable/key/circuit hashes. Final proof verification
prevents a wrong-tool result from being silently accepted, but cannot undo
disclosure or reused blinding by an untrusted prover executable.

The old block runner's verify command shape cannot be copied unchanged:
token host/wrapper verification requires the extra independently approved
`IMAGE_ID_HEX` argument (`host/src/main.rs:199`, `wrap/src/main.rs:237`).
Successful `image-id` output from the same candidate build is identification,
not by itself approval of that build.

## 4. Minimal next validation and source identity

Retain the inspected profiling-variable fix; integrate the sanitized, bounded
runner with explicit approved image IDs. Build and run the delivered light tests
and compare the independent framing vectors. Then record actual guest
execution, a real succinct-to-Groth16 run, saved-artifact verification in a
fresh process, and rejection of changed policy/image/seal and wrong receipt
or statement profiles. Keep token/input/output files and all intermediate
proof material private. `reference/reference_vectors.py check` explicitly
trusts the supplied output token; its success checks framing, not model
execution or proof validity.

At initial inspection the following delivery files matched the parent's copies
byte-for-byte. The host/wrapper were subsequently fixed as recorded above.
These hashes identify the reviewed delivery source, not a built image:

| Relative path | SHA-256 |
|---|---|
| `zkvm-model/statement/src/lib.rs` | `75e84556a1e163b1d1ae8143d4c30f0eb34535eaf6976d56977c390e63765343` |
| `zkvm-model/model/src/lib.rs` | `d7beacb6aca79e7204b8fa9181764ae46560550a51fa20d48b901a46a5634076` |
| `zkvm-model/methods/guest/src/main.rs` | `28d1c5063390cd1ca28b9949c190bf88382332a314eef5520273c9f4b56c4f0b` |
| `zkvm-model/host/src/main.rs` | `3d8eeee58329e8840668fea85b1195e5f07f5bc50e8dcf234ff1d06a5c7c5ac5` |
| `zkvm-model/wrap/src/main.rs` | `f2bd104e02abb9f7adb852f4c6d3ff9973c83a30a34f8a65d3d21fae4078b850` |
| `private-model-kernel/src/lib.rs` | `a7053d2e8d5addb3433740b6ecbf109e8fe47692a1079e378644bd6638c67025` |
| `private-block-kernel/src/lib.rs` | `9e7c9bff10790c643ab26dcd6335991a016e62d9cc19ae217a92de60e27d4cf6` |
| `zkvm-model/Cargo.lock` | `e3eeee908bf65342eddee9a4b4065b52e31d9e96df7384ae332f0cad43065f82` |
| `zkvm-model/methods/guest/Cargo.lock` | `a5b2e53cb1e04c44b239c6f1c2dc823967f7c95d7ee3a51b75b05baff6a78162` |

Review activity was read-only source inspection and byte/hash comparison.
No heavy job, proof, build, Rust test or additional agent was launched.
