# D helper-pair streaming: useful negative at the current catalog

Cycle 0077, `20261019T091854Z-7d13829d`, 2026-10-19 UTC.
**No native proving speedup measured. Pair streaming alone barely changes
the complete logical live-value peak at current unpadded T128 catalogs.**

The cycle-76 candidate computes the complete D row polynomial's coefficients
from original endpoint pairs, reduces them, then converts once per round to
the original ordered `0..=degree` samples. This experiment changes only the
order in which denominator/helper coefficient pairs are constructed. Both
schedules preserve all eleven clauses, helpers, hosts, support/padding,
original table folds/finals and point-1 recovery.

Run from the research directory:

```bash
python3 experiments/dzc-pair-stream-20261019/run.py
python3 experiments/dzc-pair-stream-20261019/audit.py
```

Both commands impose one nice19 CPU thread, 59-second CPU/wall limits and
512 MiB address space. Only the captured local Rust reference is compiled,
using `rustc`, one codegen unit, opt-level 0; no Cargo, install or GPU job.
Commands and status are in `execution.json` and `audit-execution.json`.

Seed `2026101977`, synthetic N=2/8/32. Actual public four-limb T128 catalog
descriptors for TinyLlama and Llama-3-8B are exercised alongside generic
partial-top/five-limb/odd-helper/padded branches. These latter branches are
algebra controls, not admitted trained profiles. Both actual T128 catalogs
have unpadded D: 35 A columns, 34 lookups, 17 helpers, 59 original tables.

PASS 30 fixtures: 1,950 coefficient comparisons against cycle76, 2,145
captured-Rust grid and 390 off-grid values, 90 complete round messages,
1,845 original cube finals, 30 final relations, 30 permutations and aliases.
All 390 operation censuses and zero/random structural traces agree. Seven
algebra controls catch wrong pairs, degree loss, stale challenges/recovery,
helper order, support omission and wrong MSB order. They are synthetic
controls, not native verifier refusal gates.

The reference is the captured complete Rust D expression/catalog with exact
u128 Fp2 and Shape/Layout substitutes. Independently expanded Python clauses
and direct-cube finals also agree. Actual native challenge plumbing, shape
admission, transcript/RNG/masks/PCS and fresh proof verification remain owed.
The synthetic alpha/g_u8 constants are not reusable proof preprocessing.

| Logical scope, current unpadded catalogs | All denominators | Pair streaming |
|---|---:|---:|
| Peak live denominator coefficient words |68|4|
| Peak derived polynomial-buffer words, endpoints excluded |79|18|
| Endpoint bank retained throughout + five-word accumulator |202|141|
| **All polynomial buffers released at last use + accumulator** |**130**|**129**|

One Fp2 word corresponds to 16 logical bytes. The final row is the fairer
complete lifetime comparison: **0.7692% fewer logical words**, not 30.2%.
The 202→141 row assumes the entire common endpoint bank remains allocated
and is explicitly a different scope. All counts exclude primitive-internal
scalar scratch, plan data, allocator metadata, register allocation, scheduling
and enclosing proof storage. They are not physical memory or GPU registers.
Do not multiply per-worker logical savings by every row and call it VRAM.

Arithmetic is identical between the two coefficient schedules: per row,
331 Fp2 mul, 72 mul_base, 272 add, 150 sub; same proof-local preparation
0/30/76/54 in mul/base/add/sub order. All 34 denominators are still computed.
All 59 original folds/finals remain. No full table is added or removed.
The earlier source-level arithmetic saving versus scalar D is unchanged,
but is not a native timing result.

The independent 246-check audit reconstructs interval peaks, compares a
second direct live-set sweep, checks closed-form scratch counts, unchanged
source contracts and all six live source pins. A retention control shows
that a later use of all denominators destroys the claimed streaming gain.
`initial-scratch-only-accounting/` preserves the earlier narrower accounting
and its refinement. The synthetic main test takes 6.348 s, RSS 33,804 KiB;
compiler peak 132,128 KiB. The final audit takes 0.118 s, RSS 19,352 KiB on
one Intel Core Ultra9 185H CPU0, WSL2. These are test clocks, not a speed A/B.

Generic padded catalogs show larger total-lifetime differences (e.g. 194→131
words), but current actual T128 catalogs are unpadded. Do not import that
gain into a trained-profile claim. The odd unpadded branch is 129→129.

Baseline/eliminated/new costs: versus cycle76 eliminate simultaneous
denominator-bank retention; add loop scheduling and potential fixed-array
dispatch/allocation/compiler costs, with no arithmetic-count saving. The
unmeasured end-to-end expression is `total - affected_old_D + new_D + all
integration costs`. Actual 8B D share is unknown. Even deleting every D in
the carried 1.1B one-pass 174.052 s diagnostic gives only 1.18113× / 0.868615
diagnostic positions/s; this is not this candidate's estimate or an 8B bound.
Reject any polynomial/final/degree/refusal/transcript/RNG/privacy mismatch
or enclosing regression. The large overall-retention hypothesis is demoted.

Next local experiment: construct each original endpoint pair on its first
publicly scheduled use, retaining it only until its last use. Charge every
endpoint read and difference, plan/alias handling, new scratch and original
fold. Compare against the current materialized input bank. Reject a value
dependent schedule, increased uncharged reads/arithmetic, no lower complete
logical peak or any sample/final mismatch. Owner native gates precede any
device port. See the [handoff](../../handoffs/20261019-dzc-pair-stream.md).

LIVE sources and exact access/date/license/commit limitations are in
`source-records.json`. Older super-sumcheck code and NVIDIA indexing guidance
were newly inspected; the Plonky3 October release and matched NTT/sumcheck
hardware study were checked. No external code or benchmark was executed.

New accepted target proofs/passes/positions: **0/0/0**, device none. Target
steady/total rates, startup fraction, witness/proof/serialization/verification
clocks unmeasured. No long-context prefill, resident series or decode ran;
attention context can grow quadratically. No mask/opening reuse or weaker
privacy. Complete private 8B ≥50 proved tokens/s remains unachieved.
