# P2: opt-in FFN CPU phase diagnostics

Owner: Codex P2 worker, round 2. Status: implementation and bounded real-125M
diagnostics complete, pending lead integration/frozen gates. These are private
timing-side-channel diagnostics, not evidence of security or the 60 tokens/s goal.
Neither Claude's work nor Fable's work was modified.

## What changed

`pass ... --profile v3 --phase-profile` enables per-layer `HASHLINE_PROFILE`
records on the existing CPU FFN path. The flag is off by default, rejects other
commands/profiles and repeated flags, and rejects `HL_GPU` before GPU initialization.
`HASHLINE_TIMING`, proof arithmetic, accumulation order and transcript inputs are
unchanged. The existing W1 matmul oracle/tests remain in place; no blocked matmul
candidate was promoted. The disabled instrumentation does a thread-local enabled
check but does not read a clock.

`phase_profile.rs` records nested calling-thread wall intervals and subtracts
child intervals. Allocation of each matmul result is a child of that matmul;
digest encoding and SHA-256 are likewise exclusive. Blocking Rayon work belongs
to the calling phase, not a sum of worker CPU time. Records contain fixed labels,
public shape/mode, call counts and durations, never witness values/digests. Timing
itself can expose private-data properties: do not publish raw profiling artifacts.

Witness coverage includes export reads, SHA-256, decoding and digest encoding,
explicit allocations/copies, exact gate/up/down integer matmuls, requantization,
public activation-table construction, activation lookup/Hadamard, range and
export-plane checks, temporary deallocation, and explicit unclassified residuals.
Existing sequential prover host laps are attached per layer; nested device/event
counters are not added. The analyzer ranks exclusive costs and reconciles them to
the existing proof-ready clock (1 microsecond tolerance for printed rounding).

The Python collector keeps each sample and its privacy/shape cohort separate;
there is no pooled average or `goal_met: true` path. Missing/ambiguous records,
mixed shapes/privacy, unsupported labels, failed/unverified runs, impossible or
malformed clocks, duplicate logs and overlapping accounting fail cleanly. The
runner is restricted to one 125M FFN layer, 16/32/64 rows and two CPU threads. It
owns `/tmp/zk-heavy.lock`, unsets `HL_GPU`, uses no weight cache, verifies and
writes every proof, and gives each prover subprocess a 120-second timeout.

## Reproduce

From the chosen source-tree root, build offline under the shared lock:

```bash
env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 flock /tmp/zk-heavy.lock \
  cargo build --release --offline --manifest-path hashline/Cargo.toml --bin hashline
python3 scripts/hashline_profile.py run \
  --source-tree "$PWD" --binary "$PWD/hashline/target/release/hashline" \
  --export /home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export \
  --privacy P1 --rows 16 32 64 --out /tmp/zk60-p1-profile-new
```

Use a new output path each time. Run P0/P1/P3 separately. **Do not put an outer
flock around the Python runner**, including in a detached wrapper: it acquires
the same lock internally. If detached, supervise the Python process/log, not a
second lock holder. This task did not execute GPU commands or 8B workloads.

The output directory is owner-only (0700). `manifest.json` records the supplied
source tree, revision/dirty state, source-file hashes, binary SHA-256, CPU/system,
and thread settings. Source/binary correspondence is supplied, not attested;
this limitation also applies to analyze-only mode. `workload.json` records the
export path/shape, requested rows/mode, no-cache policy and timing limits.
`rows-N-command.json` records exact command argv, enforced environment, default
proof-parameter policy and written-proof SHA-256/size. These are public proof
digests in private metadata, not witness digests or profile fields. Raw logs,
serialized proofs, incremental `partial.json` and final `summary.json` are retained.

To analyze already collected runner logs without executing a proof:

```bash
python3 scripts/hashline_profile.py analyze \
  --source-tree "$PWD" --binary "$PWD/hashline/target/release/hashline" \
  --logs /tmp/zk60-p1-profile-new/rows-16.log \
         /tmp/zk60-p1-profile-new/rows-32.log \
         /tmp/zk60-p1-profile-new/rows-64.log \
  --out /tmp/zk60-p1-profile-analysis-new
```

Logs must contain the runner's exit-status/process-wall trailer; a bare CLI log
is deliberately insufficient. Input logs are copied into the private artifact
directory. Analyze-only mode does not prove that a supplied binary generated them.

For a bounded proof-byte regression use `--rows 16 --compare-unprofiled`. P1/P3
also require `--seed 1`: this is explicitly insecure deterministic fixture
randomness, not a privacy measurement. The collector checks verification, shape,
proof length, identical serialized bytes, and absence of profiling records with
the flag removed. Ordinary P1/P3 diagnostics use fresh OS randomness by default.

## Actual measurements: 2026-09-04 local / 2026-09-05 UTC

Source: `/tmp/zk60-round2-oNXEVd/profile`, HEAD
`19ebd18bea8fa7558874c73dc3b5132ac378666b` plus the supplied C0/W1/I1 snapshot and
P2 changes. CPU: Intel Core Ultra 9 185H, 22 logical CPUs; WSL2 Linux
6.18.33.2, two prover threads. Rust 1.97.1; release/offline build, no GPU feature,
no `RUSTFLAGS` in the invoking environment. Binary SHA-256:
`d75a074b34a5ed4a27ff986fbb6c5728788d525962f15a8e4f3c650248bd52d9`.

Export: `/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export`, shape
512 rows / d=768 / f=2048 / 12 layers; only layer 0 is proved. Defaults in this
source are Ligero PCS, log_cols=14, inv_rate=4, col_checks=256. Exact pass headers
are retained in raw logs. No parameter overrides or weight cache are supplied.
There is no guaranteed mapping to other parameter/cache profiles.

Final recorded cohorts are under
`/tmp/zk60-profile-evidence-XVTqjl/{p0-final,p1-final,p3-final}`. Each consists of
one fresh process per row shape, successful in-memory verification, a serialized
proof, raw phase measurements and metadata. P1/P3 use OS randomness. The table
below is individual samples in milliseconds, not a mean, p50 or p95:

| Mode | Rows | Witness | Prover | Proof ready | Verify | Unknown inside ready |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| P0 | 16 | 23.244 | 484.926 | 511.032 | 13.063 | 0.384 |
| P0 | 32 | 33.819 | 541.273 | 578.813 | 19.276 | 0.450 |
| P0 | 64 | 53.848 | 767.969 | 825.855 | 25.919 | 0.398 |
| P1 | 16 | 23.947 | 596.444 | 623.874 | 18.010 | 0.383 |
| P1 | 32 | 29.853 | 786.449 | 820.457 | 23.537 | 0.361 |
| P1 | 64 | 47.829 | 920.420 | 973.364 | 36.066 | 0.358 |
| P3 | 16 | 23.649 | 677.554 | 704.708 | 19.278 | 0.366 |
| P3 | 32 | 30.886 | 730.185 | 765.029 | 25.277 | 0.309 |
| P3 | 64 | 50.051 | 1009.220 | 1064.206 | 37.682 | 0.450 |

Weight commitment was the largest phase in every final sample (348–452 ms).
This points to uncached CPU commitment work for this specific diagnostic, not
to a general GPU bottleneck. Pilot and earlier cohorts are retained separately
in `p0-pilot`, `p0`, `p1`, `p3`: they are not pooled or selected for speed. For
example, earlier P1/64 prover time was 1104 ms versus 920 ms here. That variation
rules out small-effect optimization claims from these samples.

Byte gates: P0 at 16 rows (`p0-pilot`), seeded P1 at 16 rows (`p1-bytegate`),
seeded P3 at 16 rows (`p3-bytegate`) all compare profiling on/off. These are
deterministic correctness gates only; their timings are not OS-randomness samples.

## Clock and interpretation limits

- These are exported prefill rows through **one FFN**, not newly generated tokens
  or a full LLM. Attention, embeddings, head and inter-operation seams are absent.
- The loader reads/checks full exported reference planes even for 16 proved rows.
  Read costs therefore do not represent a minimal live-inference witness path.
- OS page-cache state is uncontrolled. No cold/warm statistical protocol was run.
  The runner never enables the model weight-commitment cache.
- Reads include buffer allocation; requantization/activation include their own
  internal allocation work. Lazy page faults may occur after explicit allocation.
  Profiling bookkeeping and remaining setup/destruction appear in measured
  enclosing phases or explicit residuals, not fictitious tensor-compute costs.
- The existing proof-ready clock includes witness/prove/serialization, proof
  hashing and optional proof-file writes; it excludes earlier CLI/sidecar/thread/
  NTT setup and later in-memory verification/teardown. The separate process clock
  exposes time outside proof-ready plus verification. No standalone proof decoder
  is timed; no token-generation clock exists here.
- CPU host laps are sequential. No GPU/device event counters are summed, and no
  inference about GPU phase residency is made. A GPU-init success line alone
  would not establish that all phases stayed on GPU.
- Accepted proofs/timings do not establish privacy or cryptographic soundness.
  This source predates the lead's S2 mask experiment; these results do not resolve
  the inherited single-base-mask singleton-claim privacy hazard or imply a
  whole-FFN exploit. Never compare modes as equally secure from these timings.

## Validation and next step

```bash
python3 -m unittest discover -s tests -p test_hashline_profile.py -v
env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 flock /tmp/zk-heavy.lock \
  cargo test --release --offline --manifest-path hashline/Cargo.toml \
  --lib --test zk60_phase_profile phase_profile -- --test-threads=1
env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 flock /tmp/zk-heavy.lock \
  cargo test --release --offline --manifest-path hashline/Cargo.toml \
  --lib --example zk60_witness_bench witness_ -- --test-threads=1
```

Python: 11 tests passed, including malformed clocks, missing/duplicate data,
mode separation, exact accounting, timeout behavior, private artifact permissions
and mocked on/off identity. Rust profiling: 3 unit and 3 integration tests passed.
W1 oracle/example gates: 5 library and 3 example tests passed. Existing unrelated
attention warnings remain; no warning cleanup was attempted.

The lead integrated only the P2-owned source/CLI/module/test/script/report
changes and passed all four frozen CPU correctness gates; 94 release Rust
and 48 targeted Python tests passed in the combined tree. Use ranked costs
to choose the next narrowly controlled experiment. Do not infer 8B speed, 60 generated tokens/s,
or a safe/private optimized prover from this one-layer CPU diagnostic.
