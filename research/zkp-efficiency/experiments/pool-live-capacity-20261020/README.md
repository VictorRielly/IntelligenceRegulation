# Pool live-capacity study — cycle0092

Run `20261020T001854Z-f39e44f4`. **No proving speed improvement measured.** This is a source-pinned,
one-thread Python capacity model and an independent offline policy/interval
audit. Rust/CUDA and tensor contents are never executed or allocated.

The existing implementation already has exact matching, smallest fitting
reuse, a64-buffer count limit, full drain+synchronize and reserve-hard retry.
Seven pool/gate/drain function hashes match root, frozen R8 and active GPU
sources. The R8 keyed chunked body differs from root and was inspected
separately; its32-byte key upload has no RAW_ALLOC note. Historical layer-fail
comments in zk.rs are explicitly marked hypotheses, not reproduced evidence.

Public requests derived from frozen R8 `commit_zk_chunked`: r=min(rows,128),
data rows*n*8, pads rows*q*8, powers nn*8, coefficient r*n*8, padded
coefficient r*pw*8, encoded r*nn*8, hash state ceil(193*nn/2)*8, leaves32*nn,
optional key32 bytes; pw=nn or n+q. Every modeled schedule drops its commit
before the next. It excludes openings,previous live commitments,twiddle
caches,other proof phases,allocator granularity/fragmentation,and concurrency.
The rows/n/q values are synthetic public fixtures,not an admitted profile or
a reconstruction of historical device logs. No token context is assigned.

The source policy maps to effects in `capacity_model.py`; `audit.py` imports
no model code. It independently checks request choices, multiplicity, gates,
owner sets and allocation lifetime intervals, then rejects corrupted records.
Final: 59 scenarios, 4602 events,
45703 checks, 590 corruption controls,
seed 2026102092. Returned resident-buffer capacity, exact/min ties,
count versus byte cap,raw bypass,one-shot failure,size-cap-before-counter,
reuse-disable,and deferred-free/synchronization controls are included.

Synthetic four-commit row-churn example (rows3033/3028/3031/3029,n16384,q64,
nn65536,chunk128,noncompact,keyed):

| Policy | Peak modeled allocation capacity (B) | Fresh pooled allocations |
|---|---:|---:|
| Existing reuse, no intervening drain | 1794484768 | 8 |
| Existing full drain before each iteration | 603304480 | 20 |
| Proposed next-request multiset retention | 603304480 | 8 |

Selective retention assigns each idle buffer at most once to the next public
exact request(s),then to minimum-capacity scratch requests,and frees only
unselected idle buffers. It never inspects private contents or frees live
buffers. Actual native usefulness is unknown. All14 fixed-geometry pairs
have identical peak with/without full drains,but fresh allocations rise5->20.
This is evidence against adding indiscriminate drains,not authority to remove
existing production drains. This partial capacity result says nothing
about complete8B device fit. No time estimate is derived from allocation counts.

`physical_bytes` in the event schema is a symbolic sum of owned allocation
capacities including modeled deferred releases. It is NOT GPU physical page
usage,RSS,VRAM,or allocation volume. The64-entry count case retains
17179885312 modeled bytes; only small Python records exist in RAM. Another
control accumulates40960 fresh bytes at just1024 peak; requested24 bytes can
occupy2048 reused capacity. Dropping idle storage without completion can leave
an OOM in the deferred-release bracket. These controls reject misleading
peak estimates; they are not measurements of CUDA allocator behavior.

Commands (working directory research root):

```
python3 experiments/pool-live-capacity-20261020/run_bounded.py capacity_model.py
python3 experiments/pool-live-capacity-20261020/run_bounded.py audit.py
python3 experiments/pool-live-capacity-20261020/run_bounded.py validate.py
```

Every experiment leaf is one observed thread,CPU0,nice19,59s wall/CPU cap,
512MiB AS cap. Host Intel(R) Core(TM) Ultra 9 185H,WSL2,Python3.10.12.
Final model 0.191720s/30832KiB;
audit 1.489127s/22856KiB. Initial existing-policy
results and sources are preserved under before-selective-retention/;run logs
retain subsequent refinement. No compiler/dependency/native build was run.

Baseline/eliminated work/added costs/prerequisites/ceiling/falsifiers are in
hypotheses.json. Native seam: cuda.rs pool_take/take_min/put, dev_pool_drain,
dev_reserve_hard and keyed commit_zk_chunked. Tested prototype patch location:
capacity_model.py's retain branch; no production Rust patch,application or merge.
Owner must obtain actual public request/lifetime traces and test all current
CPU/GPU codeword,first-refusal,receipt,CS/H-1,one-shot-failure and privacy gates
under the shared locks before any native change or device run.

New completed independently verified full-stack proofs/passes/positions0/0/0;
device/context none. New witness/proof/serialization/verification clocks,
steady-state/total-workload proved rates and startup fraction unmeasured.
No long-context prefill,resident proof series or decode ran;attention can grow
quadratically. Larger workloads remain allowed. The complete private8B
>=50 proved-token/s target on RTX5090/high-endGPU remains unachieved.
Carried owner CPU8B T128,one16-thread pass,GPUoff,total478.737s is0.267370
positions/s,not reverified here. prove_run393.785s contains witness98.348s;
sealing84.824s overlaps witness/load;fresh verify42.709s+13.681s initial load.
Receipt922711264B. Startup/steady/isolated serialization remain unknown.

LIVE search covered NVIDIA allocation semantics/cuCascade,October SP1
NTT/zerocheck releases/diffs,and lookup/softmax zkLLMPoT v2. Dates,licenses,
inspected full/short commit scopes and cache errors are in source-records.json
and search-log.json. Author performance is not reproduced or imported.

Only research written;runtime/,production,Git,receipts,calibration,safety,
instructions/reviewer files untouched. No GPU/install/external write/message/
purchase/escalation. Fresh masks and complete proof coverage remain mandatory.
Checkpoint 2026-10-20T00:29:53.860450+00:00.
