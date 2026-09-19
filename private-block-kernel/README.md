# private-block-kernel

Portable exact-integer kernel for the fixed ZK60 T32 block (T32 d16 f16 H2
Hkv1 dh8, approved public fixture calibration). `no_std`, no dependencies,
no allocation, no floats, no I/O. Computation only — NOT a proof or privacy
claim. Must equal `hashline::causal_oracle::FixedCausalOracle::build`
bit-for-bit, including the refusal site.

The caller MUST authenticate the public weights (against the approved
commitments) and the public tables (against the registered rope/exp/SiLU
digests, or constants baked into the trusted image). The kernel checks shape
and structure only.

## API

- `PublicWeights::from_slices(wq, wk, wv, wo, gamma_a, gamma_m, wg_t, wu_t, wd_t)`
  (i8; 256,128,128,256,16,16,256,256,256; attention (out,in), FFN (in,out))
- `PublicTables::from_slices(rope_cos, rope_sin, exp, act)` (i64 128, i64 128,
  i64 256, i16 256)
- `run_block(&[i16; 512], &PublicWeights, &PublicTables, Option<&mut Trace>)
  -> Result<[i16; 512], KernelError>` (`run_block_slice` for `&[i16]`)
- `KernelError::{Shape, Table, Range, Relation, Overflow}(&'static str)`;
  `Range`/`Relation` sites are the oracle's `OracleError` strings.
- `Trace` (tests only; secret intermediates, no Debug).
- Helpers exposed for tests: `requant`, `isqrt`, `softmax_row`,
  `matmul_out_in`, `matmul_in_out`, `calib::*`.

## Commands

```
cargo test --manifest-path private-block-kernel/Cargo.toml
# oracle parity (PUBLIC fixtures from hashline):
cargo run --release --manifest-path hashline/Cargo.toml --example zk60_kernel_fixture -- --out /tmp/k0.fx
cargo run --release --manifest-path hashline/Cargo.toml --example zk60_kernel_fixture -- --variant 7 --amp 9000 --weight-seed 3 --out /tmp/k1.fx
cargo run --release --manifest-path hashline/Cargo.toml --example zk60_kernel_fixture -- --fill 32767 --out /tmp/k2.fx
ZK60_KERNEL_FIXTURE=/tmp/k0.fx:/tmp/k1.fx:/tmp/k2.fx \
  cargo test --manifest-path private-block-kernel/Cargo.toml --test fixture_parity -- --ignored --nocapture
```

The fixture format is documented in `tests/fixture_parity.rs` and
`hashline/examples/zk60_kernel_fixture.rs`.
