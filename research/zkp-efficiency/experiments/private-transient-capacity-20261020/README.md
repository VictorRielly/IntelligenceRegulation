# Private commitment transients and a mixed slot-18 table arena — cycle0095

Run `20261020T031854Z-e03e28dc`. **No proving speed improvement measured.**
A new storage-layout candidate passes a bounded toy oracle. Native Rust/CUDA,
Goldilocks extension arithmetic, masked rounds and complete receipts are untested.

The allocation model now overlays the private-stage live owner set with A/H
commit transients and slot 18. It distinguishes live requested bytes, live
backing capacity, idle pooled backing, raw lifetimes and cumulative allocation
traffic. An independent interval algorithm agrees on 72 traces (23094 events),
80 randomized allocator traces, oversize reuse and the 64-idle-buffer limit;
646591 checks and 441 corruption controls pass. These are authored single-agent
checks, not external review or proof verification. Two initial source-arm
extraction failures and the initial hi/lo ordering correction are retained in
commands/logs; final runs pass.

The model starts a middle-stage slice with previous B, current B and OUT
persistently resident. It then commits A/H and runs slot18, releasing A/H only
after their required openings. Opening scratch is omitted. Allocation repetitions
1/2/4/8 repeat this partial schedule: they are **not complete model passes**.
Public R8 f_e9 8B geometry T32/64/128 is applied to the separately pinned active
GPU allocation implementation. This is a hypothetical combination, not proof
that the active GPU tree admits these newer trained profiles. No real prompt,
activation, weight, token sequence or credential is an experiment input.

All-resident and all-chunked modes bracket selected allocation behavior; real
stores can be mixed and allocations can fail. No preceding seed-owner commit
history, H helper construction, retries, opening scratch, other slots, twiddles,
multiple public-cache entries/evictions, modules/driver, granularity, pending
physical frees or host/pinned/mapped memory is included. Actual peak phase,
VRAM, fit, transfer costs and complete elapsed time remain unknown. Raw frees
are modeled as immediate; CUDA completion must be measured. A returned pooled
buffer remains owned backing until reused or actually freed.

## New bounded experiment

Existing raw mode borrows original A/H sources for rounds0/1 yet still reserves
`kd*l` Fp2 entries with uniform stride `l`. Constructor Eq0..2 and optional public
support20 require full length. Round0 also writes derived tables at full length.
The first fused fold writes **half length**, not quarter, for the 17 raw-source
tables3..19. Later rounds use only smaller prefixes. A hypothetical mixed arena
therefore reserves `l/2` for those17 and `l` for every other table. Total is
`(kd - 8.5)*l` Fp2 entries. This removes storage, no arithmetic or proof work.

30 fixtures, n3/4/5/6/8, support on/off and three seeded value sets compare
in-place randomly ordered pair folds against direct Boolean-weight multilinear
evaluation of immutable originals. Values are **two independent residues mod101
and base-scalar challenges**. This isolates addressing/lifetimes, not native
Fp2 multiplication or the real fzc polynomial. 535848 checks pass;121 controls
reject naive global half allocation, quarter-sized raw tables, omitted
full-length derived initialization, overlapping offsets and mixed-without-raw eligibility. All modeled reads are initialized. Seed
2026102095. No native patch or arithmetic/proof claim follows.

For illustrative T128, F=2^21, support, kd23: request736->464MiB, saving272MiB
(36.9565% of table request). With the selected partial source schedule:

| Allocation mode, one partial repetition | Baseline backing peak MiB | Mixed-arena backing peak MiB | Difference MiB |
|---|---:|---:|---:|
| Resident commitments |9097.779842|9097.779842|0|
| Chunked, full pad scratch |1890.932186|1618.932186|272|
| Chunked, existing compact pad scratch |1843.182186|1571.182186|272|

The projection omits the candidate's new offset metadata and any layout-specific
scratch. These are integer capacity projections, **not measured VRAM, complete-run peaks
or speed gains**. In resident mode the pool already owns suitable larger slabs:
changing the request alone releases zero backing. In chunked mode the modeled
fresh table allocation shrinks. Other actual phases, idle slabs, failures or a
mixed store can erase the saving. Across partial repetitions4->8 HWM plateaus
while raw allocation traffic grows; cumulative allocated bytes are not a peak.
A smaller request alone cannot imply >=50 proved tokens/s.

## Integration and falsification

Prototype locations: `layout_probe.py::widths/run_fixture` and
`model.py::fzc`'s `packed` request. Owner integration would change
`hashline/src/gpu/cuda.rs::DevFzcRounds::new` and
`hashline/src/gpu/fzc_kernels.cu::fzs_ld/fzs_impl`, plus every later stride
consumer (fold, finals and host-tail pack). Proposed interface: an arena layout
with `kd` offsets and per-table capacities selected ONLY under unchanged raw
eligibility. Preserve dense mode for unsupported/unfused paths. Constructor
views must stop requesting full raw-table slices. Do not substitute one global
half stride: Eq/public/derived need full input.

Added costs: offset metadata/upload, kernel indirection/register cost, layout
bookkeeping and native fallback/refusal handling. Actual whole-workload ceiling
is unknown: current profile has no exclusive complete-GPU phase/capacity data.
Falsify on any out-of-bounds/uninitialized read, broken alias/late-fold/final,
native shadow/next-challenge/receipt mismatch, changed refusal/privacy, missing
raw eligibility, no backing reduction at the real peak, or enclosing slowdown.
Fresh per-proof masks, original commitments and single-opening lifetimes remain.

Next local: extend this toy layout oracle to the pinned native Goldilocks Fp2
and actual fzc polynomial, including raw round0 derived writes, first fused
fold, host tail and finals; independently enumerate every source consumer.
The owner first needs actual public-role capacity/phase telemetry to decide
whether a native implementation is useful. Native builds/device work remain
under the existing owner and shared build/heavy locks, not this research lane.

## Measurement scope and clocks

New independently verified full-stack proofs/passes/positions0/0/0. No actual
model context/device; new witness/proof/serialization/verification clocks,
startup fraction and steady/total proved rates **unmeasured**. No long-context
prefill, complete resident-pass series or decode. Larger workloads remain
allowed; attention may grow quadratically; no privacy/masking change.

Carried owner CPU8B T128,L32,one16-thread pass,GPUoff: total478.737s,
128/478.737=0.267370 prompt positions/s; prove_run393.785s includes
witness98.348s/load17.595s. Sealing84.824s contains overlapping witness/load.
Receipt922711264B; freshverify42.709s plus load13.681s, recheck34.395s plus
load10.739s. Not reverified here. Startup, steady slope and isolated serialization
unknown. The newer owner next-token501.6/529.2s totals are separate workloads;
none of these CPU figures is a decode stream or accepted8B GPU privacy result.

Final leaf clocks in commands/model/audit/layout result files are validation
process clocks only. One CPU0 thread,nice19,Intel CoreUltra9 185H,WSL2,
Python3.10.12; every leaf59s CPU/wall and512MiB AS. Largest observed leaf
RSS~97MiB. No builds/GPU/dependencies/downloaded-code execution.

## Sources

Native LIVE primary searches cover new StateSync-GKR Oct10 engineering and
Oct4 formal papers, its Oct10 release, SP1 open GKR PR3005/Oct10 release,
SP1-zorch's older composed-chain OOM report, INT4 toy FFN, old Sumcheck201,
Bits Under ZK-LLM and efficient-sumcheck. Ten source records append538->548.
Exact URLs, dates/unknown dates, inspected license scope and unresolved commit
fetches are in source-records.json/search-log.json. No author's measurements
reproduced. INT4 toy FFN is not a full attention stack; StateSync does not
establish multi-round Fiat-Shamir or native privacy. Library/kernel claims do
not count tokens. Current licensing and historical artifact licenses differ.

Run from research root:

```
python3 -B experiments/private-transient-capacity-20261020/run_bounded.py model.py
python3 -B experiments/private-transient-capacity-20261020/run_bounded.py audit.py
python3 -B experiments/private-transient-capacity-20261020/run_bounded.py layout_probe.py
```

No production/Git/runtime/receipts/calibration/safety/instruction/reviewer file
changed. The >=50/s complete private8B target is unchanged and unachieved.
D33 remains narrow R7 TinyLlamaT32 scope; D34 is accounting,not privacy acceptance.
Saved reports are not evidence a message was delivered to Victor.
