# macOS peak-RSS guard candidate

Source: `/tmp/zk60-sol-macmem-20260927`, an isolated copy of the frozen `/tmp/zk60-sol-gpu-20260927`. Nothing was changed in the frozen GPU candidate or its timing binary. Reviewable changes are in [mac-memory-guard.patch](mac-memory-guard.patch), with changed-file SHA-256 values in [pins.json](pins.json).

The shared memory reader keeps Linux `/proc/self/status` `VmRSS` and `VmHWM` in KiB-to-MiB units. On macOS it calls `getrusage(RUSAGE_SELF)` and converts `ru_maxrss` bytes to MiB; current RSS is `NaN` there. The 12-block ignored 125M test now rejects missing, nonfinite, zero, or negative peak telemetry before constructing the witness chain, again before proving, and after each block. Its existing 11.5 GiB ceiling is retained. Ordinary proof recording remains diagnostic and can show `NaN` if telemetry is unavailable.

Unit justification: [Apple XNU `calcru` and `getrusage`](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_resource.c#L1665-L1746) assign `mach_task_basic_info.resident_size_max` to `ru_maxrss`; [Apple's Mach task-info header](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/mach/task_info.h) defines `resident_size_max` in bytes. This is source-based reasoning, not an M3 Ultra runtime observation.

Validation on Linux:

- `flock /tmp/zk-build.lock cargo check --offline --locked -j 2 --manifest-path /tmp/zk60-sol-macmem-20260927/hashline/Cargo.toml --lib`: passed; [log](linux-check.log).
- `flock /tmp/zk-build.lock cargo test --offline --locked -j 2 --manifest-path /tmp/zk60-sol-macmem-20260927/hashline/Cargo.toml --lib private_block::memory::tests`: passed, 3 tests; post-build test-binary output [here](linux-memory-tests.log). Tests cover Linux field units/live observations, macOS byte conversion, and fail-closed invalid values.
- `cargo tree --offline --locked --target aarch64-apple-darwin --manifest-path /tmp/zk60-sol-macmem-20260927/hashline/Cargo.toml -i libc`: passed; [log](mac-dependency-tree.log) shows direct `hashline -> libc v0.2.189` for macOS.

No Mac cross-build or actual Mac execution was available. The Linux compile cannot type-check the `cfg(target_os = "macos")` body, so native Mac build and telemetry sanity check remain bringup gates. No heavy proof test was run for this telemetry-only patch.
