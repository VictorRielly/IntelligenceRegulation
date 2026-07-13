# Test and measurement evidence

Environment date: 2026-07-12. Timings are from a shared host and are
`[NOISY-SHARED]` unless stated otherwise.

The host's `/snap/bin/cargo` shim is broken. Rust commands were run with:

```bash
PATH=/home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:/usr/bin:/bin
RUSTC=/home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rustc
```

The selected compiler was Rust 1.96.0.

## Passing checks

### Release type check

```bash
cargo check --release --offline --bin ring_matmul
```

Result: pass.

### All Rust targets

```bash
cargo test --release --offline --all-targets
```

Result: pass. All binaries compiled; this repository defines its substantive
Rust tests as CLI batteries, so Cargo itself reports zero unit tests.

### Full Route-R cryptographic battery

```bash
./target/release/ring_matmul self-test
```

Result: pass in **216.62 seconds**. This includes:

- arithmetic and commitment differentials;
- Sigma, ct-round, ARP, Pi1, Pi2 and committed-execution batteries;
- cross-modulus range linking;
- masked lookup attacks and regressions;
- the U-K8 honest/tamper chain, including the new free-h0 rejection; and
- the U-K9 scalar/portable/AVX boundary and full-descent differentials.

The honest U-K8 block reported 21.70 seconds proving and 1.08 seconds verifying
for 1,020 elements in that run. q46 grounding dominated.

### Focused Python protocols

```bash
python3 -m unittest \
  tests/test_zkmatrix_protocol.py \
  tests/test_zkmatrix_link.py \
  tests/test_zk_lattice.py
```

Result: **30/30 passed**.

### Native backend integration (excluding the already-run ring full battery)

Eleven native integration tests were run explicitly: Rust/Python parity,
Section-3 KZG, curve IPA, structured and lattice self-tests, structured/lattice
chain demos, lattice FFN, ring freeze/gate checks and the large ring chain demo.

Result: **11/11 passed in 130.513 seconds**. The ring full self-test was omitted
from this invocation only because it had already passed independently above.

### Statement validator and small chain

```bash
./target/release/ring_matmul chain-demo 2 2 2 1
```

Result: pass. All 17 malformed-statement classes rejected, including the new
scale, lookup digest/fraction, signed endpoint, cycle, empty Add and orientation
cases.

### Corrected transformer inventory

```bash
./target/release/ring_matmul statement-inventory
```

Result: pass.

- 737 entries;
- 736 operations;
- 8.2020e9 used pass elements;
- 8.5249e9 paid pass elements; and
- modeled 115 seconds at 22 CPU threads using the existing measured-rate
  convention.

### OS-entropy U-K8 path

```bash
/usr/bin/time -f 'wall=%e maxrss_kb=%M' \
  ./target/release/ring_matmul ffn-chain 1
```

Result: both lookup and no-lookup arms verified using fresh OS prover entropy.

- wall: 30.24 seconds for both arms;
- lookup arm: 15.19 seconds prove, 1.05 seconds verify;
- no-lookup arm: 12.49 seconds prove, 1.01 seconds verify;
- peak RSS: 238,496 KiB; and
- q46 proof work dominated both arms.

### U-K9 lookup-core measurement

```bash
/usr/bin/time -f 'wall=%e maxrss_kb=%M' \
  ./target/release/ring_matmul lookup-bench 18
```

Result: pass.

- 262,144 elements;
- 1.38 seconds lookup prover work;
- **5,247 ns/element** prover rate;
- 5,457 ns/element including verification;
- wall: 1.60 seconds; and
- peak RSS: 166,896 KiB.

The printed 5.4-second GPU row is still an assumption. It covers an unmasked,
uncommitted lookup-core extrapolation—not an 8B end-to-end proof.

## Formatting note

`git diff --check` passes. Repository-wide `cargo fmt --check` does not: it
reports extensive pre-existing formatting drift across untouched binaries and
shared files. Running whole-repository formatting would create a very large,
unrelated rewrite, so it was intentionally not applied in this tranche.
