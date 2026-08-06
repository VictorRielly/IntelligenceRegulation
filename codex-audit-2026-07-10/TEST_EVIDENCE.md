# Reproduction and test evidence

## Environment

- Date: 2026-07-10, America/Los_Angeles
- Commit: `444f05792e35b3de2980ddc9ebac74def6d1f2f9`
- Rust: 1.96.0 direct rustup toolchain
- Python: 3.10.12
- Host view: WSL2 Linux, 22 logical CPUs

The system `cargo` command invokes a blocked Snap wrapper, so every Rust
command below used:

```bash
PATH=/home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:/usr/bin:/bin
RUSTC=/home/victor/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rustc
```

## Full repository suite

```bash
python3 -m unittest discover -s tests -v
```

Result: **42/42 passed in 127.832 seconds**.

The Route R self-test embedded in this run passed in 32.41 seconds and covered:

- R1 leak/order pairs across all quadratic families;
- CE gate/tie positive and tamper cases;
- modulus link and E2 junk-coordinate rejection;
- K-field arithmetic;
- sumcheck and GKR positive/negative/order batteries;
- SiLU fusion and table lookup;
- E4 commitment landing at `N=256`;
- M5 chunking and cross-boundary claims.

Interpretation: this is strong regression evidence for the frozen demos. It is
not an FFN-shape masked lookup test or a production proof audit.

## Release build

```bash
cargo build --release --bins
```

Result: **pass**. The build reports 15 warnings for `ring_matmul`, two for
`lattice_matmul`, and one for `structured_matrix`.

## Cargo test

```bash
cargo test --all-targets
```

Result: **pass as a compile check, but every Rust target runs zero tests**.
The security behavior lives in CLI self-tests invoked by Python.

## Freeze check

```bash
./target/release/ring_matmul freeze-check
```

Result: **pass**. Notable pinned rows include R1 pad counts, E2 junk coverage,
the q31 ARP non-wrap item as known-open, the GF(q^16) constants, SiLU table
digest, the `2^23` lookup-instance ceiling, transcript shape, and E4 psi count.

## Algebra and ZK design spikes

```bash
python3 scripts/zk_lemma_check.py
python3 scripts/logup_gkr_spike.py
python3 scripts/logup_zk_mask_spike.py
```

All pass.

Important interpretation of the third command:

- it reconstructs the toy multiplicity histogram exactly from one unmasked
  transcript;
- its toy masked construction prevents that recovery and passes the stated
  attack/fix pairs;
- it is Python design evidence, not the missing Rust U-K5 implementation or a
  general-shape proof.

## Lookup benchmark reproduction

### `N = 2^18`

```bash
./target/release/ring_matmul lookup-bench 18
```

Result:

```text
fuse+histogram 0.02s
trees          0.25s
descents       2.55s
verify         0.12s
E4 weights     0.23s
prover core    2.82s 1T = 10,743 ns/element
```

The program prints 221 seconds/pass using an imported 8.74x factor and 96.7
seconds using a 20x GPU assumption. Neither is a measured lookup result.

### `N = 2^20`, with peak memory

```bash
/usr/bin/time -v ./target/release/ring_matmul lookup-bench 20
```

Result:

```text
fuse+histogram 0.07s
trees          1.15s
descents      10.42s
verify         0.38s
E4 weights     1.01s
prover core   11.64s 1T = 11,104 ns/element
CPU utilization: 99%
maximum RSS: 1,565,804 KiB
```

This confirms near-linear single-thread time from `2^18` to `2^20`, but also
shows the allocation-heavy memory footprint. The frozen FFN instance is
`2^23`; it was not run.

## Python syntax

```bash
python3 -m compileall -q .
```

Result: **pass**.

## Formatting and lint

```bash
cargo fmt -- --check
cargo clippy --all-targets
```

- Format check: **fail**, with widespread rustfmt differences.
- Clippy: completes successfully with extensive warnings; the all-target
  `ring_matmul` run reports 99 warnings including duplicates.

## Repository hygiene

```bash
git diff --check
```

Result: **pass** before this audit folder was added.

No CUDA proof test was run. GPU access was unavailable in this environment,
and the repository contains no Route R proof GPU backend to exercise.

## Missing tests that remain P0

1. Rust masked lookup implementation and engine-scale histogram non-recovery.
2. Mask-reuse rejection across independent proofs/processes.
3. Full original U-K8 range -> lookup -> E2 -> Hadamard chain.
4. Actual masked `2^23` memory/latency run.
5. Full FFN-shape CE proof rather than commitment-only volume.
6. Malicious q31 wraparound and declared-weight-range witnesses.
7. Manifest/model DAG omissions, shape substitutions, and operation replay.
8. Canonical parser fuzzing and verifier panic freedom.
9. CPU/GPU differential tests once a backend exists.

