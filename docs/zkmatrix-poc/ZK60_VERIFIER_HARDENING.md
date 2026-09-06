# H1: explicit zero lookup-denominator refusal

Scope: Codex hardening lane, base `5657a8d`, isolated checkout
`/tmp/zk60-round5-mO246D/hardening`. This is a narrow availability/error-handling
change, not a whole-verifier audit, privacy claim, or throughput result.

**Integrated acceptance:** 129 release Rust tests and all four complete frozen
CPU proof artifacts pass. The ordinary-library public receipt verifies in a
separate process and reproves to exactly the existing full SHA-256/length.
All frozen attention runtime schedule fingerprints are unchanged; the lead
reviewed the scoped source diff before explicitly accepting its source guard.
See [round-5 validation](../../results/zk60_round5_validation.json). The later
worker-stage references to pending lead gates are retained as history.

## Cause and change

The attention LogUp histogram identity and both FFN verifier versions constructed
nonzero-multiplicity table denominators `alpha - table_value`, then passed them
to the asserting `batch_inverse2`. A zero produces a zero accumulated product;
extension inversion reaches the base-field `inverse of zero` assertion. Depending
on build panic settings, this can unwind or abort instead of returning refusal.

`field::batch_inverse2_checked` now scans all canonical Fp2 inputs for zero and
returns `Err` **before allocating, mutating the slice, or inverting**. Empty
input succeeds. Nonzero input delegates to the unchanged batch inversion routine,
preserving its arithmetic and ordering. Its field representation precondition
is unchanged: Fp limbs must be canonical. This is not a parser for arbitrary
raw Fp tuple values; bounded wire decoding enforces canonicality separately.

The three verifier call sites propagate explicit contextual errors:

- `attention LogUp: zero lookup denominator`
- `FFN v2 LogUp: zero lookup denominator`
- `FFN v3 LogUp: zero lookup denominator`

Attention's argument function is shared by prover and verifier. The checked
call is only on its verifier branch; the prover retains its original call.
Prover helper construction, RNG draws, transcript absorption, polynomial
arithmetic, proof serialization, and proof parameters are unchanged. A zero
denominator is refused, not silently skipped, replaced, or retried.

## Deterministic production-branch tests

The new `hashline/src/field/verifier_hardening_tests.rs` is registered only under
`cfg(test)` inside the field module. Its crate-private thread-local hook is
single-use and resets through an RAII guard, including unwinding. There is no
environment switch, public override, production feature, or hook in ordinary
library/binary builds. GPU-feature builds omit the CPU proof-fixture tests.

The hook changes the late histogram-side alpha to one active row's table value,
after an honest proof has already passed the preceding production verifier
checks. The actual denominator construction and checked batch call then run.
Tests require that the selected hook was consumed and assert the exact error.
This isolates a rare exceptional branch; it is **not** a found Fiat–Shamir
preimage, a naturally sampled collision, or a constructed proof exploit.

Tests cover:

- Zero at every position for lengths 1, 2 and 9, plus all-zero input; the whole
  input is unchanged on refusal.
- Empty, singleton, repeated and mixed base/extension edge values through
  length 257; checked output equals legacy output and individual inverses.
- Complete `verify_attn`, `verify_layer_v3`, and legacy `verify_layer` prefixes
  reaching the production refusal branch, followed by successful honest replay.
- Attention and v3 caller error propagation through `verify_public_block`.
- Existing deterministic B3 component-wire bytes remain fixed at BLAKE3
  `b965cc4ddd05ac2eabc949579ee6482af650b7db89890d5e7cc0ae979cd6df95`.
  Verification does not mutate either tiny B3 or synthetic v2 proof bytes.

The attention/v3 fixture is the existing public T32/d16/f16 block. Legacy v2
has fixed d768/f2048, so its smallest supported row count T1 uses an explicit
all-zero public witness, a public zero member table, and reduced test-only PCS
parameters (`log_cols=8`, `inv_rate=2`, two column checks). That fixture is only
a bounded branch regression, not an approved model or security-strength proof.

## Commands and acceptance

Builds and substantive CPU tests serialize through the shared kernel lock with
two build/Rayon threads. No exports, GPU, network, or large-model job is needed.

```sh
env -u HL_GPU -u HL_FOLD -u HL_NO_FOLD CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 \
  flock /tmp/zk-heavy.lock /home/victor/.cargo/bin/cargo test \
  --release --offline \
  --manifest-path /tmp/zk60-round5-mO246D/hardening/hashline/Cargo.toml \
  --lib hardening_ -- --test-threads=1 --nocapture
```

Result: exit **0**, **5/5 tests passed**, 55.75 s fresh offline release build,
0.29 s tests. The eight emitted warnings were existing attention warnings.
`git diff --check` also passed. A direct rerun under the same shared lock and
two Rayon threads passed 5/5 again (0.28 s test report); `/usr/bin/time -v`
reported **139,176 KiB maximum RSS**, no swaps, exit 0:

```sh
env -u HL_GPU -u HL_FOLD -u HL_NO_FOLD RAYON_NUM_THREADS=2 \
  flock /tmp/zk-heavy.lock /usr/bin/time -v \
  /tmp/zk60-round5-mO246D/hardening/hashline/target/release/deps/hashline-72d1cf268ba37d0a \
  hardening_ --test-threads=1 --nocapture
```

These [WSL-BOX, 2T, NOISY-SHARED] runtime/resource diagnostics establish only
that the synthetic regression job is bounded, not a proving throughput claim.
The lead owns the full integrated frozen gates, including the ordinary
non-`cfg(test)` library, the public receipt's distinct 135-claim bytes and source
inventory acceptance.

The attention source drift alarm deliberately changes from SHA256
`fec19c0f03a50052a92bf71579446d0885f543fc6fc45282a04f229aa9a732b2` to
`e5ab96f35018dfcfe44c9a24879a3ab2fc5cae5394809bd489ddc16eb5d9b6d8`.
The H1 lane does **not** update or approve that snapshot. The lead must inspect
the import, test-only hook and verifier-only call change before accepting the
new source hash. No attention recorder event or semantic role was edited.

## Adjacent review and remaining limits

The directly related inversion search in `attention.rs` and `layer.rs` found
the remaining unchecked batch calls in prover helper construction, intentionally
unchanged. `pow2_signed` inverts a public power of two for supported negative
shifts, not a challenge-derived lookup denominator; its existing metadata/shift
preconditions remain. Table indexing and dimensions also rely on the existing
statement/profile validation. The new check does not make arbitrary legacy
typed inputs panic-free, validate noncanonical raw field objects, bound every
legacy allocation, cover `zk.rs`, or prove verifier security generally.
