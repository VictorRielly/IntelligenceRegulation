# CL20 integration review — PCS accepted, typed decoder held

Reviewed on 2026-09-08 from committed source in Fable's clean local
`zk60-cl20-core` checkout. This was local delivery review, not evidence that
Fable had pushed the branch. The recorded published core tip was `882f037`.

## Accepted boundary

`76ee27513763b7992bd57638b203b7ce76e6a8ed` moves the canonical CPU PCS into
`zkp-core` behind `Backend`/`EncodedStore`, retaining hashline's GPU dispatch,
runtime switches and timing output in the adapter. Its parent `ee775be`
extends the static dependency scanner across both crates. Codex integrates
this boundary in `b044e20`, then adapts the protected-material cleanup and its
test to the generic store in `83115b5`.

The six reviewed functions `hash_columns`, `coset_powers`, `encode_row_zk`,
`salt_leaf`, `verify` and `verify_zk` are byte-for-byte unchanged. Their hashes
are retained with the review evidence. The full diff review also covers backend
fallback, timed opening, serialization and pads-before-salts RNG order. Three
PCS tests move from hashline to the core; the core now has 22 tests. Combined
validation, including actual GPU execution, is recorded in
[round 14](ZK60_ROUND14.md).

The core has no CUDA, filesystem storage or key-provider dependency. The
two-crate graph is a static source inventory; actual Cargo dependency checks
remain the dependency gate. The current v3 floor runner still needs CL21's
core provenance upgrade. Round 14 additionally hashes both crates and their
lockfiles before and after the combined run.

## Held boundary and reproductions

Do not integrate `f8d40a74e07ee9d60f869fe323eee2a2f564f067` yet. It moves
tables and typed FFN pieces and adds the shape-directed proof decoder. The
prover/verifier extraction remains a later step. Codex reproduced the following
issues in a `git archive` snapshot, without editing Fable's checkout. All
fixtures and seeds are public, tiny test data. These results do not establish
a proof-soundness failure under the fixed production configuration.

| ID | Source at the reviewed pin | Reproduction and consequence | Required correction |
|---|---|---|---|
| C20-R1 | `zkp-core/src/ffn_v3/proof.rs:204`, `:388` | `Params::check()` accepts `num_col_checks = usize::MAX`. Decoding an ordinary tiny proof with those expected parameters panics with capacity overflow in `Vec::with_capacity`, instead of returning a decoding error. | Validate supported query counts and checked size/allocation bounds before allocating. Retain a no-panic oversized-parameter regression. Treat this as public-API configuration robustness; the query count is not read from malicious proof bytes. |
| C20-R2 | `zkp-core/src/ffn_v3/proof.rs:216`, `statement.rs:40` | `Proof::from_bytes(&[], statement_with_shift_64, normal_params)` panics in `rem_rows` during shape construction, before reading input. | Validate the supported shift domain and geometry before shifts/products; return `DecodeError::Shape`. Add invalid expected-statement tests, including overflow boundaries. The observed shift panic is from a debug build; release behavior must also be checked. |
| C20-R3 | `zkp-core/src/ffn_v3/proof.rs:241`–`:243` | With `log_cols = 0`, the legacy prover produces a proof accepted by its ordinary verifier, and `Params::check()` accepts the configuration. Actual W/A/H opening groups are 1/1/2; the decoder assumes 2/2/3 and refuses those honest bytes. | Derive group counts consistently with actual PCS grouping. If this configuration is deliberately excluded from the new codec, enforce and document that profile restriction explicitly, preserve legacy behavior, and add a regression. |

The normal `log_cols = 5`, 12-query fixture first proves, verifies and decodes
successfully. The output retained in `review/probes.log` is:

```text
CONTROL_NORMAL_ROUNDTRIP=true
Q_MAX_PARAM_CHECK_ACCEPT=true
Q_MAX_DECODE_PANIC=true
SHIFT64_EMPTY_DECODE_PANIC=true
LOG0_PARAM_CHECK_ACCEPT=true
LOG0_LEGACY_VERIFY=true
LOG0_ACTUAL_GROUPS=1,1,2
LOG0_DECODER_GROUPS=2,2,3
LOG0_CORE_DECODE=false
```

The probe catches the two panics so all cases run; its exit 0 means the review
harness completed, not that the proposed decoder passed. The original probe
source, manifest, lockfile, runner, log and source pin are retained in
[the evidence directory](../../results/zk60_round14_evidence/README.md).
The source snapshot itself and build products are not committed. Reconstruct
the snapshot from the exact Git pin and use the retained probe's relative path
dependencies to rerun it with two threads and `HL_GPU` unset.

## Fable continuation

1. Merge the published performance integration into the existing core lane,
   preserving local work. Do not duplicate PCS or the host cleanup fix.
2. Correct C20-R1–R3 in a bounded follow-up commit. Review all shape arithmetic
   and allocation limits, retain the existing malformed-byte cases and add the
   above expected-configuration cases. Report debug/release results separately.
3. Complete the selected P0 FFN prover/verifier extraction with actual old/new
   proof and cross-verification parity. Preserve table semantics, compact/cache
   consumers and all complete CPU/GPU frozen artifacts.
4. Keep the later ZKP extraction gated on the reviewed privacy invariants.
   PCS and P0 refactoring do not repair the known FFN privacy or P3 identity
   limitations, and do not finish CL20.

CL20 remains priority 3. FA6–FA9's independent correctness/privacy review and
CL21's provenance work retain their existing priority and ownership.
