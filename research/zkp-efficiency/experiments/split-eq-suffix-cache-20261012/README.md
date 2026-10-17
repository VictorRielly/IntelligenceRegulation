# Per-proof split equality suffix cache — cycle 0041

Run `20261012T222555Z-e2cb7a5e`, seed 2026101241, accessed and tested October 12, 2026.
**Synthetic arithmetic passes; no native or complete-proof gain is measured.**
This is a small preparation candidate, demoted as a principal throughput lever.

## Question and baseline

Can a fixed split plus cached suffix levels replace the two `eq_table_msb`
constructions performed each round by the current `GroupedEqRounds`? The
baseline already factors equality and recovers one actual group sample. This
experiment preserves those existing optimizations; it does not claim their
published gains again. The point/support descriptor is immutable and local
to one proof. Fresh private masks, commitments and proof challenges remain.

Pinned native source: `ops/zkp-mvp/candidate/zkp-core/src/sumcheck/grouped.rs`
SHA-256 `7777a19c8db97694c51e66c78d1a7688573158bddaa7fcb370345ebd14ab669b`;
all 13 previous native/report pins match, plus a new snapshot/hash of `mle.rs`.
`input-manifest.json` retains exact paths, hashes and snapshots.

Historical bottleneck: synthetic one-block 125M/T512, two CPU threads, RTX
4070 Laptop, shared host b2: RS 0.600 s, SZC 7.794 s within 16.864 s proving,
external witness 5.77 s, serialization 0.028 s, in-process byte verification
0.82 s, whole test 27.523873283003923 s. Startup is unisolated. The other GPU
witness sample was 10.66 s; the enclosing phases are not stable p95 evidence.
These are historical diagnostic clocks, not an accepted private 8B baseline.
No new native proof or actual-device timing was run.

## Experiment and independent reference

```text
python3 -B experiments/split-eq-suffix-cache-20261012/experiment.py
```

Final run passes in **9.878353521 s**, **22,480 KiB**
peak RSS, Intel(R) Core(TM) Ultra 9 185H, one CPU thread pinned to CPU0, nice19,
Python 3.10.12. Internal CPU/wall caps59s, address space512MiB;
estimated experiment memory64MiB. Outer timeout60s. `command.json`,
`execution.json` and `run.log` retain the exact command and enclosing duration.
The elapsed clock includes fixtures, controls and oracle work; it is no proof
phase or performance A/B. Two earlier passes are retained with every original
code hash; later passes added offset rounds and debug bracket-call checks.
No failed experiment invocation occurred.

- 184 suffix fixtures, cube logs0..8, empty/full/leading/interior/short supports,
  full Goldilocks2 (`u²=7`), base, Boolean and zero points; 12,036 independently
  evaluated suffix weights and 736 construction/release formula checks.
- 32 source-derived complete SC_SZC fixtures, contexts1/2/3, padded extents up
  to4 tokens and8 heads, cube logs0/2/6/7,26/30 tables,2/3 sum limbs. Seeded
  inconsistent synthetic planes, not honest witnesses or model activations.
- 64 cached grouped schedules against the rebuilt reference and independent
  original-cube tuple algebra:2,520 independent subgroup samples,5,040 cached
  sample/degree checks,720 actual claim checks,318 recoveries,258 zero-factor
  explicit fallbacks,1,792 ordered table finals,5,376 extension table checks.
  Release and debug bracket counts retain192 exact checks.
- Seven offset/empty/interior grouped fixtures pass112 direct original-cube
  round samples. Sixteen controls catch stale points/starts, bound cache reuse,
  wrong schedules/extents, mutated cells, reversed MSB order and false host
  claims. Original equality planes remain dense and in final table order.

The oracle uses independent schoolbook tuple multiplication and original
Boolean-cube MLEs; it calls no cache, descriptor or folding implementation.
The rebuilt/cached grouped schedulers share locally copied scheduling logic,
so the direct original-cube check is the independent reference. Final digest:
`11fcb1135eceef1149ddd56daa7ae14ed6d159f5f01a4edc77af8f65d0d69a5b`. Local source hashes and hardware are in result.json.

## Eliminated work and added costs

Cache each half's suffix levels once, select borrowed slices each round, then
free obsolete levels after all row reductions and binding complete. For a
start-zero support, skip only its first current coordinate in preparation.
For a support that begins later, cache the entire point. The split stays fixed
instead of rebalancing each suffix; their products represent identical weights.
Prefix scales, per-group actual claims, inversions, zero-factor fallback,
all sample values/degrees, dense folds, helper/future-score constraints,
extensions, final-table positions and public zero targets stay unchanged.

Conditional m125 head map h_pad16/T512 (data cube log22, Eq lengths22/13/22):
preparation multiplications **41,598 -> 12,532**, removing29,066 (69.9% of that
construction count). The unchanged row weight cost is **12,582,909** Fp2
multiplications and **25,165,818** table reads. Removed work is only **0.2302%**
of the counted preparation-plus-weight multiplications, before brackets,
folds and all other phases. This percentage is **not a speed ceiling**: field
counts do not price allocations, cache misses or compiler effects. It is a
reason to rank the candidate below the measured dominant work.

Logical cache peak: **200,608 B**, versus **100,352 B** baseline split tables,
so **100,256 B extra** before metadata/allocator/point ownership. Obsolete
levels are released monotonically to two identity words per group. Retaining
suffix levels changes locality; the right half stays larger in later rounds
than a rebalanced table. The serial Rust sketch reads each tail in two passes;
native baseline loads each element once for two outputs. Exact construction
traffic formulas are in cost-accounting.json, including native initialization
writes and point-reversal copies; native compiler/cache/free costs are unknown.
The separate original dense equality planes are not removed.

Allocation-free T512/1024/2048/4096 projections keep head padding16. Relative
removed multiplication count falls0.2302% ->0.1150% ->0.0574% ->0.0287%, while
unchanged score-cube work grows quadratically. These are unadmitted shape
counts, not larger-context performance. A resident sequence uses a fresh cache
for each proof point; it cannot amortize challenge-dependent Eq preparation
across proofs or reuse private masks. No decode relation is tested.

End-to-end ceiling: `Nproved/(Ttotal-Ceq_preparation+Ccache_build_read_free)`;
ideal bound removes only `Ceq_preparation`. **Accepted private8B numeric
ceiling unknown.** The entire historical RS/SZC envelope8.394s is broader than
this candidate and cannot be assigned as its saving. Need native construction,
read/free, slot, enclosing readiness, peak and independent-verification clocks.

Falsify on any original-cube/sample/group-claim/final/order/degree/short-support/
zero-factor/extension/refusal/mask/RNG/transcript/receipt/privacy mismatch,
stale point reuse, or native added costs/peak/enclosing time consuming savings.
No message normalization, challenge distribution or privacy change is proposed.

## Ranked hypotheses

| Rank | Hypothesis | Prerequisites, costs and rejection condition |
|---|---|---|
|1 owner|GPU SC_SZC plus recurring witness, largest measured scope.|Exact CUDA, memory lifetime and native masked/refusal/frozen-byte gates; duplicate witness clocks. Independently verified full A/B; enclosing/peak regression rejects.|
|2 owner|Exact full-K int16 FFN down.|Packing,two exact products,i64 reconstruction/requant,transfer/workspace; native calibration/range/device and phase clocks. No complete readiness gain rejects.|
|3 tested prior|Canonical four-reduction Fp2.|Compiler/register/carry provenance,masked/receipt tests; kernel arithmetic counts do not establish enclosing improvement.|
|4 tested prior|Heterogeneous public descriptors retain grouping.|Native reader/build/total/census/extension/verifier and parallel integration; predicate/dispatch overhead. Any transcript or enclosing mismatch rejects.|
|5 owner|Fixed-context resident complete passes with fresh masks.|Startup/slope/lag/drain,context/pass/concurrency,all recurring phases/peaks and independent verification. Recurring>20ms/proved position rejects50/s for that schedule.|
|6 NEW next local|Collapse repeated trailing-j work in the lifted Ht host group.|Prove actual Tab::lift/source provenance and invariance,keep all other groups including future-score checks. Test arbitrary off-domain samples/extensions/zero factors and sabotaged lifts. Underbinding,wrong refusals or tiny priced share rejects.|
|7 NEW tested/demoted as main lever|Per-proof fixed-split Eq suffix hierarchy.|Passes synthetic parity;0.2302% multiplication-count removal before brackets,extra100,256B peak at conditionalT512. Native costs and privacy gates unmeasured; no enclosing gain rejects.|
|8 retained|Sparse GKR/composition,compiled lookup,structured PCS,GPU NTT.|Migration/setup/PCS/joint privacy costs; preserve prior smaller-phase,fusion,compiler,residency and privacy negatives.|

## Sources and seam

Five qualified LIVE primary records appended (220 ->225). Dates, exact URLs,
inspected commit scope, licenses and failures are in source-records.json;
queries and fetch metadata/response hashes in search-log.json/web*.json. Akita chapter
search text describes suffix caches; its implementation and license-text
fetches returned Cache miss. Repository root reports Apache2/MIT, but exact
license text was not inspected. Visible v0.1.0-linked validation diff is pinned
at029ceceaba879a0d9bf80a47d2e08534e630457d; its timestamp is unavailable.
Tag display omits year; official announcement explicitly dates September9,2026.
No current HEAD or suffix implementation pin is claimed.

[BDDT2026](https://eprint.iacr.org/2026/587) and
[Dao/Thaler2024](https://eprint.iacr.org/2024/1210) were refreshed; their whole
reported Eq/Jolt gains are not reproduced by this incremental cache. Newly
assessed older [Libra](https://eprint.iacr.org/2019/317), received2019-03-29,
last revision2021-11-20, prices sparse bookkeeping before rounds. Its older
[author-hosted2019PDF](https://www.cs.yale.edu/homes/cpap/published/libra-crypto19.pdf)
was inspected in Algorithms4/5 and ZK outline; not asserted to be the2021
version. Proceedings PDF403 retained. Sparse GKR wiring and separate
setup/delegation/masking obligations do not transfer directly to generic SZC.
No foreign code or author performance was executed.

Seam: `zkp-core/src/sumcheck/grouped.rs` constructor, round group tables and
post-fold release; `mle.rs:48` existing MSB table function; native private-block
`argument.rs:1783` three equality groups. Tested Python is local only.
`suffix_cache.rs` is an **uncompiled, unapplied serial Rust sketch**, with
borrowed slices and owned per-proof state. No production edit or merge.
Owner first instruments preparation/read/free and enclosing time, then ports
only if its share warrants it; requires native masked/transcript/frozen receipt,
independent verifier,refusal and privacy gates under shared build/heavy locks.
No heavy job was launched or queued.

## Proof accounting

Accepted independently verified complete private8B proofs/passes/tokens:**0**.
Proof context null;passes0;CPU only. Steady-state and total-workload rates,
startup seconds/fraction,witness/proof/serialization/independent-verification,
proof latency/lag/drain are unmeasured. No long-context prefill,resident-model
pass or decode proof. Target remains>=50 proved tokens/s;larger workloads
allowed,quadratic attention,fresh masks and full coverage/privacy preserved.
Research-only writes excluding runtime;no native builds,GPU,install,Git,
production/receipt/calibration/instruction/reviewer edits or external messages.
Checkpoint 2026-10-12T22:36:34.177104+00:00. Saved reports are not notification-delivery evidence.
