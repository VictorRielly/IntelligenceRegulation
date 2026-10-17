# New-host setup artifacts

The [hardware guide](../../docs/zkmatrix-poc/ZK60_HARDWARE_SETUP.md) now starts
with creating Ubuntu installation media: Victor's 5090 PC has no Linux OS
yet. The 512 GB M3 Ultra can prepare the USB and later host CPU validation.

The [portable development source archive](zk60-keyed-cuda-development-20260927.tar.gz)
contains all 198 source/documentation files from the frozen keyed GPU
candidate's four crates, five public runtime fixture files, setup instructions,
the read-only host inventory script and a complete hash manifest. The
[checksum](zk60-keyed-cuda-development-20260927.tar.gz.sha256) and
[builder](build_snapshot.py) retain reproducibility. The builder checks the
184 source pins against the passing device report and reads every archived
member back before publishing the checksum.

This is an unpromoted development snapshot, with no trained weights or
private witness data. See its [README](SNAPSHOT_README.md) for initial CPU
gates and the limits of device validation. It has not run on the 5090 or Mac.
The first optimized GPU library run passed 491 tests and failed one because
the old toy receipt was missing (17 ignored); the archive now includes that
exact historical synthetic receipt and its public policy, alongside the
three metadata fixtures. The filtered compatibility rerun now passes on the
same pinned binary. Coverage is 491 plus one passing tests across two runs,
with 17 ignored; the original failed run remains preserved. The v3 frozen
proof also has its exact historical hash and verifies, but attempt 6's runner
used the v2 success marker for v3 and recorded a false negative. That failed
report and its proof are retained. The corrected continuation passed all six
remaining comparisons; all eight frozen proofs now have exact historical
hashes/sizes and verified device execution. This remains synthetic legacy
coverage, not an 8B or larger-profile privacy result.

The inventory script was exercised on this Linux host both with GPU queries
disabled and with actual host NVIDIA access: RTX 4070 Laptop, 8188 MiB,
compute 8.9, driver 566.14. Its separate NVRTC API query with the existing
CUDA_ROOT found version 12.1 and architectures through compute_90, including
89; that installation is not suitable for native compute_120 compilation.
Without configured library search paths it correctly reports NVRTC missing.
The macOS branch still requires validation on the actual Mac. Rustup's
automatic installation is disabled for the script's version commands via
`RUSTUP_AUTO_INSTALL=0`, as documented in the
[Rustup environment reference](https://rust-lang.github.io/rustup/environment-variables.html).

The separate [Mac memory-guard candidate](../zk60_sol_macmem_20260927/README.md)
passes Linux compilation and three targeted tests. Its patch applies cleanly
to this source, but is not included in the frozen CUDA archive. A native Mac
build and telemetry check remain required before large Mac proof tests.
