# Development snapshot for Linux CUDA and macOS CPU bring-up

This contains the exact four-crate keyed CUDA candidate tested on the RTX
4070 Laptop, plus five public synthetic fixture files needed by the native
library suite. `SOURCE_MANIFEST.json` hashes all packaged files and the
184 compile inputs. Fixtures include a historical toy receipt and its public
endpoint policy for cross-version verification. The source has not been
promoted into the main prover.
It includes the validated grouped evaluator, **not** the slower fused
follow-up. Neither the 5090 nor the M3 Ultra has run this source yet.

The retained device gate passed resident, streamed, compact-pad and small
tagged block CPU/GPU proof checks. Broader regression evidence is in the
parent repository's `results/zk60_sol_gpu_20260927/`. This archive contains
no compiled binaries, dependency cache, trained weights, private witness
data or 8B profile. It is not a complete 8B proof or a privacy acceptance.

Install the 5090 PC's OS using `HOST_SETUP.md`, then run:

```sh
python3 zk60_host_preflight.py
```

On either host, after native Rust/C/C++ tools are installed, resolve the
locked dependencies once, then run the small CPU core gate:

```sh
cargo fetch --locked --manifest-path zkp-core/Cargo.toml
cargo fetch --locked --manifest-path hashline/Cargo.toml
cargo test --offline --locked --manifest-path zkp-core/Cargo.toml -j 2
```

On the Mac, keep the `gpu-cuda` feature disabled. Portability still needs
actual arm64 validation. Large ignored tests use Linux-specific peak-memory
measurement; a Mac memory monitor/guard must be in place before those runs.
Do not launch the ignored model-scale tests as a first host check.

On Linux, CUDA/NVRTC library configuration and the driver must pass inventory
before device tests. The next bounded device check is
`hashline/tests/zk60_tagged_gpu_commit.rs` built with `gpu-cuda`, using
`HL_GPU=1`, `HL_GPU_REQUIRED=1`, `HL_GPU_CHUNK_ROWS=128` and separate
`HL_ZK_CHUNK=off` / `force` processes. Its only test is
`tagged_column_hashes_and_full_commitment_match_cpu`. A skipped device or
CPU fallback does not qualify. The parent repository retains reviewed
machine-specific runners; adapt their CUDA paths before using a new host.

The small proof interfaces include `hashline/examples/zk60_block_receipt.rs`.
They do not load trained 8B weights. Full trained calibration, whole-profile
privacy, a memory-bounded full-stack run and >=50 proved tokens/s remain open.
Source audit links inside HOST_SETUP.md refer to the parent repository.
