# M3 Ultra arm64 macOS CPU bring-up audit (2026-09-27)

Scope: read-only audit of the **frozen** `/tmp/zk60-sol-gpu-20260927`
candidate pinned by the GPU lane's
[attempt-2 report](../zk60_sol_gpu_20260927/attempt-2/device_report.json).
I ran `cargo tree --offline --locked --target aarch64-apple-darwin` on the
Linux development host; the [default](mac-default-deps.txt) and
[storage-feature](mac-storage-deps.txt) dependency trees resolve. **No Mac
compile, proof, receipt verification, or performance measurement was run.**
The available M3 Ultra has 512 GB RAM, but this audit does not establish
speed or complete private 8B stack coverage.

## Code and feature boundary

Copy the four sibling crates with their relative layout and lockfiles:
`zkp-core`, `hashline`, `private-block-kernel`, and
`private-block-kernel-shaped`. Hashline's two kernel crates are path-based
test dependencies; its tests also use relative `include_str!` paths into
`zkp-core`. A copy of `hashline` alone is insufficient.

The default `hashline` build has no CUDA dependency. `gpu-cuda` is opt-in;
without it, `gpu/mod.rs` compiles a CPU backend and a GPU stub that always
reports disabled. **Do not enable `gpu-cuda` on this Mac bring-up.** That
feature uses CUDA/NVRTC and has no Metal implementation here. The M3 Ultra
GPU therefore cannot run this prover as a GPU target from the current source.
The optional `stable-weight-storage` feature adds ChaCha20-Poly1305 and
Zeroize; its code uses Unix file modes and `/dev/urandom`, both relevant to
macOS, but needs an actual Mac test before storage claims.

A source search of all four crates found no explicit x86 intrinsics,
`std::arch`, inline assembly, or architecture `cfg` in the CPU Rust source.
The CPU path uses fixed-width field/receipt serialization, Rayon, BLAKE3 and
SHA-2. This is a static portability signal, not proof that the Apple linker,
dependency C build, and tests pass. There is no pinned `rust-toolchain` file;
record `rustc -Vv`, `cargo -V`, the exact source/lock hashes, and `uname -m`
on the Mac.

## Concrete fixture and OS issues

1. The full native suite **requires three retained runtime fixtures** under
   the sibling `results/zk60_block125m_lane/` directory. They are absent
   from the GPU source copy and the main workspace's `results` tree, but are
   present in `/tmp/zk60-groups-20260926/results/zk60_block125m_lane/`:
   `x34-slot-ir/drafter_inventory.tsv`,
   `m125-run-l12-tagged-run-statement.json`, and
   `m125-run-l12-dense-run-statement.json` (about 32 KiB total). The slot IR
   test reads the TSV unconditionally; the retained-statement test reads both
   JSON files unconditionally. A source/docs-only package will make those
   tests fail for missing files. Their exact sizes and hashes are retained in
   [mac-fixture-pins.json](mac-fixture-pins.json); stage those bytes without
   regenerating them. The slot IR
   export test also writes JSON into `results/zk60_block125m_lane/x34-slot-ir/`,
   so that directory must be writable during tests.
2. `/proc/self/status` is Linux-only. `private_block/timing.rs`, `run.rs`,
   and several tests return `NaN` RSS on the Mac. Ordinary proof paths still
   run and merely lose memory telemetry. The ignored 12-block 125M test in
   `private_block/run_tests.rs` is different: its `if hwm > 11.5 GiB` guard
   evaluates false for `NaN`, silently removing its memory stop. **Proposed
   patch, not applied:** fail closed when `!hwm.is_finite()` before comparing
   the ceiling, then add a macOS high-water-mark reader or an external
   enforced memory monitor before that heavy test runs on the Mac. The
   hard-coded 11.5 GiB threshold was a Linux box limit and must be set
   deliberately for the 512 GB host. `MALLOC_MMAP_THRESHOLD_` references in
   the run tests describe glibc behavior and are not a macOS allocator knob.
3. The production/export default in `hashline/src/export.rs` points at
   `/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl`.
   Widened-stack cache tests also default to another `/home/victor/...` tree
   and loudly skip if it is absent. Set `M125_EXPORT_DIR` and `HL_EXPORT_DIR`
   to staged, identity-pinned exports on the Mac when those profiles are
   intentionally tested. A green suite with the cache fixture absent does
   not mean that cache proof test ran. The small synthetic private-block
   example needs neither export.

## Suggested Mac gates on the staged copy

Use an arm64 Rust toolchain on the Mac and keep CUDA disabled. These are
commands **to run on that host**, not commands claimed to have passed here:

```sh
uname -m
rustc -Vv
cargo -V
cargo test --manifest-path zkp-core/Cargo.toml --locked -j 2
cargo test --manifest-path hashline/Cargo.toml --locked -j 2 --no-default-features --lib
cargo test --manifest-path hashline/Cargo.toml --locked -j 2 --no-default-features
cargo test --manifest-path hashline/Cargo.toml --locked -j 2 --no-default-features --features stable-weight-storage
cargo build --manifest-path hashline/Cargo.toml --locked -j 2 --release --example zk60_private_block
hashline/target/release/examples/zk60_private_block prove /tmp/zk60-mac-block
hashline/target/release/examples/zk60_private_block verify /tmp/zk60-mac-block
```

Stage the three pinned fixtures before the full `hashline` test commands.
The last two commands must run in **separate processes**; verification checks
three corrupted copies. `--locked` protects dependency resolution but may
still download uncached crates on a new Mac; use `--offline --locked` only
when its registry cache is populated. The ignored 125M/12-block tests need
their own explicit resource and receipt gates after memory telemetry is
fixed. Compare proof bytes/digests and independent verification across the
Mac and retained Linux fixtures before calling the port equivalent.

This CPU bring-up is a useful correctness and memory diagnostic. The current
source has no complete private 8B transformer-stack result and no Apple GPU
backend; the >=50 proved-token/s RTX 5090-or-named-GPU target remains open.
