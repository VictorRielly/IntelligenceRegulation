# W1: exact CPU witness arithmetic and bounded blocking experiment

Codex witness worker, 2026-09-04. Base `19ebd18` plus the lead's C0
patch, in `/tmp/zk60-parallel-OrrY0T/witness`. This worker is neither
Fable nor Claude. The existing C0 changes were preserved.

## Decision

Keep both production matmul loops unchanged. A four-row by 128-column
blocking experiment matches an independent scalar oracle but does not
demonstrate a consistent improvement on the eight-thread target. The
64-bit accumulation variant is slower. The retained deliverable is the
oracle/test coverage and a reproducible small profiling harness, rather
than a default performance regression.

This work concerns CPU witness matrix multiplication. It is separate from
AL's already-landed prover staging/allocation change and does not change
quantization, proof parameters, privacy, commitments, or transcript bytes.
No speedup of a complete witness, 8B proof, or generated-token workload
was established.

## Files and arithmetic contract

- `hashline/src/chain.rs`: tests only. Independent row/column/k scalar
  comparisons cover signed int8 extremes, zeros, empty row/inner dimensions,
  odd shapes, row tails, column boundaries 127/128/129/259 and the stated
  inner-dimension bound of 32768. Zero columns retain the existing panic.
  Beyond the documented bound, tests preserve checked-prefix overflow and
  release wrapping, including a sum that overflows before returning to the
  representable range.
- `hashline/src/export_v3.rs`: tests only. The independent i128 oracle covers
  full i32 input extremes as well as the int16 activation range, signed int8
  weights, zeros and tails. A specific `i32::MIN * i8::MIN == 2^38` check
  requires widening before multiplication. No enormous allocation was made
  merely to force an i64 accumulator overflow.
- `hashline/examples/zk60_witness_bench.rs`: experimental blocked kernels,
  scalar i128 oracle, deterministic synthetic inputs, alternating A/B order,
  per-trial output comparisons, raw timings and candidate tests. The
  production functions supply the baseline. `--log NEW_PATH` preserves the
  raw repetitions without overwriting an existing artifact.
- This report.

The candidate reuses each weight across four independent output rows. It
blocks 128 output columns and falls back to the streaming loop for a final
partial row tile. For each output, products and additions retain increasing
`k` order and the original i32/i64 types. There are no SIMD intrinsics,
unsafe accesses, saturating operations, partial-sum reassociation, or floating
point operations in either candidate. Test runs exercise checked and wrapping
integer behavior. Zero-valued operands may add an exact zero instead of
skipping an addition; this does not change any intermediate numeric value.

## Measured scope and result

Machine: WSL, Intel Core Ultra 9 185H; generic release build, `RUSTFLAGS`
unset; rustc 1.97.1 / LLVM 22.1.6. Measurements hold `/tmp/zk-heavy.lock`; no GPU, model export, or
proof is loaded. The sandbox process view cannot certify whole-host idleness,
so these are **local paired diagnostics on a shared host**, not publication
rows. Both functions are warmed once and then run five times in alternating
baseline/candidate order. Timings include output allocation; scalar-oracle
work and equality comparisons occur outside each timed call. "Speedup" is
median baseline time divided by median candidate time.

An initial simple nested-row blocking variant was rejected: single-thread
i8 ratios were 0.946–0.986 and i64 ratios 0.795–0.820. The retained variant
explicitly reuses each loaded weight across four rows. Its final logged sweep was:

| rows × inner × columns | i8→i32, 1T | i8→i32, 8T | i32×i8→i64, 1T | i32×i8→i64, 8T |
|---|---:|---:|---:|---:|
| 32 × 768 × 2048 | 1.061× | 1.044× | 0.648× | 0.779× |
| 64 × 1024 × 2048 | 1.151× | 1.020× | 0.808× | 0.398× |
| 17 × 769 × 2049 | 0.870× | 0.948× | 0.732× | 0.535× |
| 32 × 2048 × 768 | 1.188× | 1.100× | 0.694× | 0.887× |
| 64 × 2048 × 1024 | 1.135× | 1.117× | 0.750× | 0.649× |
| 17 × 2049 × 769 | 1.187× | 1.175× | 0.884× | 0.532× |

Every output matched the independent scalar oracle and the production
baseline. Whole sweeps including both scalar oracles took 3.154 seconds at
1T and 1.570 seconds at 8T. `/usr/bin/time -v` reported peak RSS 8,764 KiB
and 8,236 KiB respectively, exit 0. The largest weight matrix contains
2,097,152 bytes. All sweeps stay far below the 1 GiB/one-minute limits; a
30-second deadline is checked before timed repetitions.

The eight-thread i8 measurements overlap materially. For 32×768×2048,
baseline trials span 2.270–2.749 ms and candidate trials 2.103–2.592 ms;
for 64×1024×2048 they span 5.008–6.283 ms and 5.825–6.020 ms. A 2–18%
median difference on selected shapes is not sufficient to promote this
change when another shape regresses and the i64 path clearly loses. These
small matrices mostly fit in cache; the experiment cannot settle the cost
of repeatedly streaming real 8B weights.

## Validation and reproduction

Run builds under the build lock. Run each benchmark under the heavy lock;
the example itself does not acquire that lock. It is a short foreground
diagnostic, not a detached full proof job.

```sh
flock /tmp/zk-build.lock /home/victor/.cargo/bin/cargo test --offline --manifest-path /tmp/zk60-parallel-OrrY0T/witness/hashline/Cargo.toml --lib --example zk60_witness_bench witness_ -- --test-threads=1
flock /tmp/zk-build.lock /home/victor/.cargo/bin/cargo test --release --offline --manifest-path /tmp/zk60-parallel-OrrY0T/witness/hashline/Cargo.toml --lib --example zk60_witness_bench witness_ -- --test-threads=1
flock /tmp/zk-build.lock /home/victor/.cargo/bin/cargo build --release --offline --manifest-path /tmp/zk60-parallel-OrrY0T/witness/hashline/Cargo.toml --example zk60_witness_bench
flock /tmp/zk-heavy.lock /usr/bin/time -v /tmp/zk60-parallel-OrrY0T/witness/hashline/target/release/examples/zk60_witness_bench --threads 1 --reps 5
flock /tmp/zk-heavy.lock /usr/bin/time -v /tmp/zk60-parallel-OrrY0T/witness/hashline/target/release/examples/zk60_witness_bench --threads 8 --reps 5
```

Debug targeted tests: 5 production arithmetic tests and 3 experimental
candidate tests passed, exit 0. Release targeted tests: the same 8 tests
passed, exit 0. Final release example build passed, exit 0. Both final
logged A/B runs passed every scalar-oracle and baseline comparison and
exited 0. `git diff --check` passed. No dependencies were downloaded and no files outside
the four-file lane were edited. Compilation emits existing attention-module
warnings, unrelated to this lane.

Raw repetitions from the final executable are retained at
`/tmp/zk60-witness-evidence-kAs24A/one-thread.log` and
`/tmp/zk60-witness-evidence-kAs24A/eight-thread.log`. The last two commands
above were run with, respectively,
`--log /tmp/zk60-witness-evidence-kAs24A/one-thread.log` and
`--log /tmp/zk60-witness-evidence-kAs24A/eight-thread.log` appended. Reproduce
with new paths because the logger deliberately refuses to overwrite files.

## Next bounded step

First attribute the existing witness clock at one small real 125M layer:
file reads/digests, each of the three exact matrix products, nonlinear
requantization and copies. Use this scalar oracle to check every changed
matrix output. Then investigate an output layout/work partition that retains
enough independent tasks for eight workers; four-row grouping reduces the
number of available jobs and can erase the single-thread gain. Measure
cache misses and bandwidth before choosing a larger cache experiment or
an architecture-specific integer kernel. The current evidence does not
identify the hardware bottleneck conclusively.

For the GPU witness lane, these tests provide exact integer reference
behavior; int16×int8 down projection still requires wide accumulation.
Any future production optimization should request a small real-125M
witness comparison and the lead's frozen deterministic proof gates before
integration. This lane needs no new proof gate to validate a changed
production implementation because none was promoted.
