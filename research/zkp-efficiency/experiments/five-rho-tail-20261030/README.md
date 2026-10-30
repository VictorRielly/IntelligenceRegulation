# Five-vector final row fold — cycle0155

Run `20261030T005649Z-506c4db2`, October30,2026 UTC.
**No native proving improvement measured; private8B >=50 proved tokens/s remains unachieved.**

The current PCS device wrapper sends `rhos.chunks(4)` and the CUDA adapter
asserts `1 <= k <= 4`. PCS adds one fresh proximity rho before batching.
For a public count `4m+1`, m>=1, the research planner replaces only the
last4+1 by5 without permuting any vector. The separate
`candidate_kernel.cu::k_fold_rows_tail5` copies the exact current kernel
body, changes its maximum to5 and renames its symbol. The original max4
symbol remains intact. Neither candidate nor planner is applied to production.

The baseline rereads all systematic matrix rows once per chunk. The candidate
can remove one matrix sweep, launch and per-call rho/output allocation and
submission pair. Total coefficient upload, output download, base-field
multiplies, pad folds, all masking/proximity/commitments and verification
remain. The fifth Fp2 accumulator increases source accumulator payload
64->80B per thread, not a measurement of compiled registers. Largest affected
per-call rho+output device scratch grows25%; it is not total device memory.
Register spills, occupancy, caches and peak overlap can erase a benefit.

| Conditional historical generic groups, f_e9 | Old/new systematic matrix source bytes | Reduction |
|---|---:|---:|
| R14 T128, noDD |8,209,432,576 ->7,748,452,352|5.61525%|
| R14 T128, DD |8,316,649,472 ->7,908,229,120|4.91088%|
| R14 T256, noDD |19,128,909,824 ->18,063,294,464|5.57071%|
| R14 T256, DD |17,947,164,672 ->17,041,719,296|5.04506%|

These source operands include a standalone generic core's two external
endpoints. They are neither current native group measurements nor a
multi-block/classifier/full-run workload. They are explicit Shieldstral
3072/9216 layouts, not8B R14 geometry. Rho accesses are warp-uniform and
may hit caches; operand bytes are not DRAM bytes. The historical builder
census's four producer-source mismatches from cycle0154 remain unresolved.
Internal endpoint grouping remains unmeasured. If a four-claim internal
endpoint has four groups, its5rhos could also benefit; no full-run multiplier
is applied here.

Correction to the preceding cycle's shorthand: at T128/f_e9, A3517 rows
times16384columns times8B is **460,980,224B**, not461,373,440B (the latter
corresponds to3520rows). H3116's408,420,352B is unchanged. Old artifacts are
retained; this correction does not change the exact prior geometry result.

Validation completed on one pinned, nice19 Intel Core Ultra9 185H CPU worker:

-612 Rust synthetic fixtures,228,780 scalar limb outputs including3
  synthetic pad columns, comparing unchanged extracted native scalar field
  and serial-adapted host fold with source-loop emulation and an independent
  schoolbook-u128 modular oracle. Public batch counts0..129 preserve ordered
  coverage.141 controls comprise130planner cases,3shape refusals and8fault
  checks. Rows0/1/3/33 and actual row counts3517/3272/3395/3116; columns1/7/17,
  rho counts0/1/2/4/5/9/12/13/57/59; dense,sparse,pure-imaginary,boundary
  and protected-tail inputs. Large-row fixtures use7columns; no large matrix.
-375 C++ fixtures,30,750 scalar limbs, compile the exact extracted max4
  and max5 CUDA loop bodies in a CPU control-flow shim with u128 arithmetic.
  Every fixture checks overlaunch and guarded output bounds. Rows include257,
  columns include33. This is not CUDA compilation, device ABI/arithmetic,
  races, registers or GPU timing evidence.
-25 of those public synthetic vectors receive an independently written
  Python bigint full-dot-product reference:1,050 limbs,1,817 assertions
  including source pins, arithmetic filters and cost accounting. These
  references were written by this researcher, not an external reviewer.

Zero rows/counts and odd columns are primitive edges, not admitted native
profiles. Real FS, claims/groups, mask assertions, generated PCS pads,
encoding, proof bytes, privacy and independent native verification are unrun.
No real prompt, activation, weight or token was read or copied.

Two audit mistakes are retained in `first-*` and `second-*` logs: only f_e9
fixtures have historical group records, and `P-1` happens to be exactly
representable in binary64. The corrected older-source filter uses `P-2`
and `(P-1)^2`; the candidate/kernel results did not change. A tool metadata
diagnostic also printed character indices of a string; it affected no test.

Reproduction, one stage at a time from the research directory:

```sh
python3 experiments/five-rho-tail-20261030/run_bounded.py prepare
python3 experiments/five-rho-tail-20261030/run_bounded.py compile
python3 experiments/five-rho-tail-20261030/run_bounded.py probe
python3 experiments/five-rho-tail-20261030/run_bounded.py compile-cpp
python3 experiments/five-rho-tail-20261030/run_bounded.py probe-cpp
python3 experiments/five-rho-tail-20261030/run_bounded.py audit
```

Seed202610300155. Each leaf:40sCPU/45salarm/50sparent timeout,384MiB address
cap, oneCPU affinity; estimates300MiB Rust compile,128MiB C++ compile,
96MiB others. Rust compiler auxiliary threads unmeasured; one codegen unit.
Measured compile1.084s/158288KiB;probe0.317s/8824KiB;
C++ compile0.633s/76496KiB;probe0.066s/7600KiB;
final audit0.036s/15240KiB. Shared-host diagnostic clocks only.
Do not rerun `record_cycle.py`: it appends the one-cycle source ledger.
Native/document hashes must remain pinned; preserve evidence on drift.

Five LIVE source records in `sources-cycle.jsonl` include the newly assessed
[2010 exact SpMV](https://arxiv.org/abs/1004.3719) and
[2026 Karatsuba–NTT](https://link.springer.com/article/10.1007/s44443-026-00722-6),
plus refreshed
[cuda-zkp-ntt](https://github.com/Artemarius/cuda-zkp-ntt/releases),
[zkDuel](https://github.com/snarang181/zk-duel) and
[StateSync-GKR](https://arxiv.org/abs/2610.14849).
The older paper's small-modulus floating/deferred-reduction implementation
does not transfer to full-width Goldilocks; sparse-format and preprocessing
methodology remain useful. The2026 NTT paper reinforces the need to measure
occupancy against saved traffic. None establishes native privacy or a
private8B rate. Dates/nulls, license scope and fetch failures are recorded;
no external commit content or author performance was reproduced.
Nine native LIVE request batches have response hashes; query/open provenance
is in `web-provenance.json`. No foreign code executed.

All80 prior hypotheses are retained exactly;81records this result and82asks
whether one-opening public-rho staging can reduce allocation/submission
cost without widening all batches. Global priorities remain owner verified
high-endGPU resident1/2/4/8 workloads, admitted context/DD/fidelity scaling,
then exclusive phase/capacity clocks. Complete bound is
`N/(T-C_removed_exclusive+A_added)`; free deletion of unknown exclusive
fraction f is bounded by`1/(1-f)`. No numerical8BGPU ceiling follows.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actual model context and accelerator:none; modeled T128/T256; CPU only.
Witness,proof,serialization,verification,startup/initial-prefill clocks,
startup fraction,proof latency/bytes,steady-state and total-workload rates:
**unmeasured**. No long-context prefill,resident series or decode ran.
Larger workloads remain allowed; longer attention can grow quadratically.

Only research outside runtime written. No production/Git/receipt/calibration/
instruction/safety/reviewer changes, GPU/native build, installs, downloaded
script execution, external messages/writes, purchases, escalation or merge.
Main/Claude reviews and integrates. Saved reports do not establish delivery
or supervisor liveness. Owner state00:28:47UTC records detached recovery,
not an independently checked running job; held sources remain untouched.
