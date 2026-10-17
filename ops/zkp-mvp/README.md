# Native MVP workspace

Read [the recovery coordination record](RECOVERY_COORDINATION.md) before
starting a build, proof, GPU check or calibration run. Claude owns the common
resource guard; Codex owns the benchmark and CLI validation. The guard must
be reviewed and released there before native execution resumes after an edit.

`candidate/` is the retained measured synthetic native source, including the
keyed GPU route. `sonnet-hardening/` is its separate CLI hardening copy.
Neither directory is a trained-model MVP or a privacy acceptance. The
recovery audit verifies all 186 baseline pins and exactly three intentional
hardening changes: the CLI example, `mvp_driver.rs`, and bounded segment
reading in `run.rs`.

Run the prepared hardening validation with a new output directory:

```sh
python3 ops/zkp-mvp/validate_hardening.py --output results/zk60_sonnet_hardening_20260930/recovered-validation-1
```

It guards each native command separately, builds offline with two jobs,
retains the actual executables, runs the CLI and bounded-reader tests,
generates a two-block p2 proof, replays its generated verifier arguments in
a separate process, and runs the independent adversarial checks. Source,
binary and log hashes accompany each terminal result. Do not wrap this
script in another guard or an outer flock: it already guards its steps.

`scripts/zk60_private_stack_benchmark.py` likewise guards each native command.
Its rates require a complete synthetic stack, saved-proof verification, and
actual keyed GPU dispatch when GPU mode is selected. Reported workload time
comes from the guard's child interval; admission and drain have separate
clocks. Raw outer GPU samples include admission/drain and are not workload
peak evidence. Each run uses a new output directory and keeps its report,
logs and terminal marker. It refuses a guard version change between steps.

After reviewed CLI validation, the agreed sequence is a small p2 GPU canary,
then the larger m125/12-block GPU diagnostic if the canary's memory and
dispatch checks pass. The old interrupted `cli-stack-gpu` attempt is preserved
as crash evidence and has no throughput result. A synthetic diagnostic must
never be described as the trained 8B / 50 proved-token/s target.

The compatibility `build_native.py`, `sonnet-hardening/build_check.py`, and
`baseline_run.py` now guard their actual child commands too. The baseline
retains the native test oracles and in-process verification; use the benchmark
entry point for a CLI artifact and fresh-process verification. Refer to
[the resource protocol](../../docs/zkmatrix-poc/ZK60_RESOURCE_PROTOCOL.md)
for current caps and safe termination, and
[MVP status](../../docs/zkmatrix-poc/MVP_STATUS.md) for remaining trained-model
work.

Both build compatibility launchers print a new per-attempt evidence
directory and preserve older reports. Do not wrap them in an outer guard or
flock: each guards its own Cargo steps.

To restore the tested localhost demo after a reboot, run
`python3 ops/zkp-mvp/start_demo_server.py` from the host. It starts a detached
server at <http://127.0.0.1:8765> and records its boot, PID namespace and start
identity plus a health check under
`results/zk60_crash_recovery_20260930/demo/server-runtime/`. Repeating the
command reuses a verified live server; an unknown listener is refused.
It starts no proof or GPU job by itself.
