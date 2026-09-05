# I1 — approved-model verifier boundary

Codex identity worker, 2026-09-04. Base `19ebd18` plus the C0 source patch
and CLI tests. Work lives in `/tmp/zk60-parallel-OrrY0T/identity` until the
lead integrates it. This worker is not Fable; Fable's independent review
remains queued. No commits, GPU jobs, or changes to another lane's files.

## Result and scope

The tiny diagnostic reproduces the known P3 identity gap: identical input,
layer shape, signed shifts, activation table and declared model name allow
two different hidden Wg tensors to prove and verify. The new opt-in P1
boundary rejects a valid substitute-weight proof using an independently
approved public-weight commitment. It also rejects relabelled roots,
changed model statements/parameters/modes, and incompatible NTT tables.

This does **not** repair P3 identity. P3 needs a proof of consistency between
its fresh hiding W commitment and a separately approved stable commitment.
The existing verifier/prover, transcript, proof format, CLI dispatch and
historical fixtures are unchanged by I1. Calling the old verifier alone
still leaves approval checking to its caller.

Changed files:

- `hashline/src/model_identity.rs`: `ApprovedP1Layer`, registration checks,
  typed refusal errors, exact candidate comparisons, NTT validation, then
  delegation to `verify_layer_zk_v3`.
- `hashline/src/lib.rs`: additive module registration only.
- `hashline/tests/zk60_identity_gap.rs`: five tiny integration tests,
  including the explicitly named `known_p3_gap_*` diagnostic.
- This report.

## Trust API

The application calls `ApprovedP1Layer::from_trusted_registration` with:

| Independently approved value | Boundary check |
|---|---|
| `StatementV3` | Layer index, token rows, d/f, all signed shifts, activation family, table digest AND all 256 table values |
| `LayerParams` | Exact column width, inverse rate and column-check count |
| Public-weight `Commitment` | Exact W root, row count and column width; registration also validates layout dimensions |
| `ZkStatementMode` | Exact mode, including any declared model ID; only P1 and committed output without a predicate are supported |
| Transcript domain | Fixed nonempty application-selected domain; verifier creates a fresh local transcript after all checks |

Registration arguments must come from authenticated application
configuration or an independently approved public model. A `model_id`
string is a declaration, not the trust source. **Never construct the
expected commitment by reading the candidate proof or an unauthenticated
manifest supplied alongside it.** The API deliberately has no `from_proof`
constructor and keeps its registration fields private, but no Rust API can
determine whether a caller actually authenticated its inputs.

The tests register first, computing the W commitment directly from the
known public int8 weight planes using the existing block layout and PCS.
Only afterward do they produce candidate proofs. Thus the positive case
does not pin a root copied from the proof being tested.

`ApprovedP1Layer::verify` accepts the candidate metadata and structured
proof plus verifier-owned `NttTables`. It rejects every metadata mismatch
before constructing a transcript. It rejects undersized transforms,
inconsistent root/twiddle lengths and noncanonical roots. The underlying
verifier receives the immutable REGISTERED statement, parameters and mode.
Matching the expected root alone is insufficient: a substitute proof whose
W root is replaced by the approved root reaches the existing verifier and
is rejected there.

Supported registration is the current v3 P1 FFN relation, Ligero inverse
rate 4, `log_cols` 1 through 16, valid v3 export shift bands, and a frozen
activation table. Query count must be positive and fit an activation
message row; that structural check is **not** a deployment security floor.
The trusted application must approve query counts using whole-proof
soundness analysis. Unsupported privacy/output modes and parameters are
refused instead of silently relaxing the approval.

This version intentionally starts a single-layer transcript. It does not
accept a prover-selected initial state and cannot independently verify an
interior proof from a shared-transcript pass. A pass API needs its own
review of approved layer order, exact membership and seam binding.

## Tests and evidence

All proofs use T=2, d=f=16, `log_cols=5`, inverse rate 4 and 12 column
checks. These are diagnostic parameters, not production security. All
proof randomness is explicitly seeded for repeatability; these fixtures
provide no privacy. Synthetic exponent fields are internally consistent
with the selected signed shifts and frozen activation-table member.

The five tests cover:

1. Known P3 gap: fixed input and statement, Wg[0] changes from -1 to 0,
   declared model is `example-approved-model`, separate test seeds 201
   and 202, both verify against the SAME statement and model declaration.
2. Approved P1 accepts; internally valid substituted weights reject at the
   root check; copied approved root and a modified sumcheck claim reject
   in the existing proof verifier.
3. Every statement field, each proof parameter, mode/model declaration,
   missing commitment, and each W commitment field is tested adversely.
   P3 and predicate requests are explicitly refused.
4. Undersized and malformed NTT tables reject; replay under another
   independently registered transcript domain rejects.
5. Registration refuses unsupported policy, invalid dimensions, invalid
   shifts, zero/oversized query counts, non-registry table identity,
   changed table bytes, inconsistent W dimensions and an empty domain.

First offline release build/test command (exit **0**):

```sh
/home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/cargo test --release --offline --manifest-path hashline/Cargo.toml --test zk60_identity_gap -- --test-threads=1 --nocapture
```

Result: **5 passed**, test execution 2.84 s; first build 54.42 s. This
preceded a fixture-only correction aligning synthetic exponent metadata
with the already-used shifts, plus formatting.

Final confirmation after that correction (exit **0**):

```sh
env RAYON_NUM_THREADS=2 /home/victor/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/cargo test --release --offline --manifest-path hashline/Cargo.toml --test zk60_identity_gap -- --test-threads=1 --nocapture
```

Result: **5 passed**, test execution 0.54 s; rebuild 52.44 s. Both diagnostic
digests below reproduced exactly. Different test execution times are not a
controlled performance comparison.

The diagnostic proof digests, identical on both runs, are:

| Private weights | SHA-256 of the deterministic diagnostic proof |
|---|---|
| Wg[0] = -1, seed 201 | `cbccb86231fef7714eb07232ea6b00d429e3f86df0d5a1d4f8f25655ead28606` |
| Wg[0] = 0, seed 202 | `acddc82808299451d07c7997e3921bae0ffb9f0af3fdd561460697d6a48fdba5` |

Formatting: the 1.97.0 toolchain has no installed `rustfmt` (attempt exited
127, changed nothing). The installed stable `rustfmt --edition 2021` then
formatted only the two owned Rust files, exit **0**. `git diff --check`
passed, exit **0**. Existing warnings in `attention.rs` were not changed.
No performance benchmark or hardware extrapolation was made. The lead
owns cross-lane regression gates and final integration.

## Remaining obligations for Fable and C1

- Approve/authenticate a real model registry and reproduce its public P1
  roots independently. This API supplies no manifest signature system.
- Design and audit P3 stable-commitment consistency, including repeated
  openings; the passing diagnostic remains a **missing-constraint** result.
- Pin the full calibration specification outside `StatementV3`. The built
  statement exposes shifts, family and table; it omits some exponent and
  provenance fields. This boundary cannot make absent metadata a proven
  relation merely by accepting another declared digest.
- Bind the intended input and output commitments, complete layer order,
  seams, attention, head/embedding and generated-token state. A single
  approved FFN layer is not an approved complete LLM execution.
- Add independent artifact decoding and audit malformed structured proofs.
  The boundary inherits the existing verifier's proof parsing assumptions;
  it is not a general denial-of-service or panic isolation mechanism.
- Complete whole-proof soundness/ZK analysis. An approved W root does not
  certify correct private randomness, and the verifier cannot distinguish
  a public deterministic fixture from a privately generated transcript.
