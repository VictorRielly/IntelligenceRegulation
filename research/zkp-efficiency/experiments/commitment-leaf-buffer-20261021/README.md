## Cycle 0123 — streaming BLAKE3 state: exact CPU model, native benefit unknown

Run `20261021T071854Z-0fa6988f`, checkpoint 2026-10-21T07:34:42.480903+00:00. **No proving speedup measured.**
AGENDA, prior state/findings, all782 prior source records, required project notes and
latest results read/snapshotted. Current D37–D41 media/classifier work does not amend
this research target. Old MVP_STATUS section2 five-second language is historical;
the current throughput-target document governs. All35 prior hypotheses remain;
rank36 adds the tested state candidate and rank37 the MARS scheduling screen.
Owner ranks1–4 remain whole-GPU plus verified resident1/2/4/8; DD larger-context
fidelity; complete phase/capacity clocks; native all-eleven FZC A/B.

Baseline: `commit_zk_chunked`, `commit_chunked` and `commit_chunked_upload` reserve
193 u32 words per encoded column (24 CV levels plus length) and zero their entire
pooled state backing. `Pooled::get_mut` returns full capacity; a best-fit allocation
can be larger than requested. The stream already avoids downloading full encodings;
there is no such transfer to eliminate in this path.

Tested changes: D=ceil(log2(ceil(rows/128))) CV levels suffice for the existing lazy
merge schedule; initialize only the count, or set local count=0 on public row0==0
and remove all explicit state clearing. Every CV read must follow a write in the
same proof. Poisoned bytes, fresh proof contents, 128/256/384-row launches, row/block/
chunk boundaries, global counters, root flags and little-endian words were tested.
All compared compression inputs and calls match. No compression or active CV
traffic is eliminated. Depth0 is needed for single-chunk columns. Zero/overflow
rows are excluded from the model, not newly admitted or refused by production.

Hash/state model: **328,043 checks, 27 synthetic matrix shapes and 11 control types PASS**.
Independent labelled-subtree/source/cost audit: **1,050,682 checks, 1,024 chunk counts,
seven native source pins PASS**. This researcher authored both models; the cryptographic
reference is independently implemented in the already-installed `blake3` 1.0.9 package,
one thread. Final checker clocks/RSS: 4.605481s/29,724KiB and
1.341245s/15,532KiB. These are diagnostic clocks, not proof clocks.
Every leaf has one-core affinity, nice19, 30s CPU/alarm, 35s parent timeout,
256MiB address-space limit and 64MiB estimated experiment memory.

| Frozen8B per-commit geometry | Rows A/H | CV depth A/H | Old state request MiB | New state request MiB A/H | Request saved MiB A/H |
|---|---|---|---:|---|---|
|T128 nonDD|3405/3790|5/5|48.25|10.25/10.25|38/38|
|T128 DD|3283/3634|5/5|48.25|10.25/10.25|38/38|
|T512 nonDD|9185/11056|7/7|96.50|28.50/28.50|68/68|
|T512 DD|7303/8724|6/7|96.50|24.50/28.50|72/68|

These are **one temporary state request per commitment**, not total model memory or
simultaneous A+H peak. With exact-sized backing, first-launch initialization removes
48.25/96.50MiB of explicit clearing per such call; actual pooled clearing can be
larger. Length-only clearing needs0.25/0.50MiB instead. Retained best-fit backing can
erase capacity savings completely. No actual allocator/HWM/device timing was measured.
No masks, salts, opening schedule, encoded values or lookup relation change.

Added costs: a public first-launch conditional; optional host/device depth agreement,
offset checks and original fallback. Native branch/register/driver/error behavior
and current privacy/refusal gates remain untested. Removed clear-API errors are
infrastructure behavior to review, not evidence of original failure equivalence.
If f is the unknown removable critical-path fraction, even free deletion gives
at most1/(1-f), before added costs. Byte fractions do not give f or a GPU speed.
Falsify on stale reads, wrong ordered hash/root/salt/path, RNG/transcript/receipt or
privacy drift, absent native incidence, no actual fit benefit, or slower enclosing
verified workload. A narrower uncompiled first-launch/no-memset patch is retained;
dynamic-depth compaction is model only. Native owner/Claude reviews and integrates.

Two source-audit anchor failures were corrected and retained (a comment-style
rate anchor and upload's enumerated loop), without changing production. All hash
experiments passed. Source records distinguish inspected full BLAKE3 commit
f3149ec5bb5449af877ba20377a11008ff499fa2, unknown release year and MARS history/license
cache misses. Nine native LIVE queries, eight primary records. New MARS2026
FORS scheduling and older BLAKE3 stack sizing were assessed; BatchZK, Chimera
October16, MORPH and Poseidon were filtered by actual backend/statement scope.
No author rate, external implementation or security claim was reproduced.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Device: one Intel Core Ultra 9 185H CPU
worker. Witness, proof, serialization, verification and startup clocks, startup fraction,
steady-state and total-workload rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. T128/T512 are counted geometry only;
T512 is unregistered and LOW/HIGH fidelity layouts are excluded. Larger workloads
remain allowed; attention can grow quadratically. The complete private8B / >=50
proved tokens/s target on RTX5090 or a named high-end GPU remains unachieved.

Carried historical baseline (not rerun/reverified): nonDD8B T128/L32, one16-thread
CPU pass, GPU off, total478.737s =0.267370 positions/s. prove_run393.785s includes
witness98.348s/load17.595s; seal84.824s overlaps. Receipt922,711,264B; fresh
verify42.709s+load13.681s; recheck34.395s+load10.739s. Isolated serialization,
startup fraction and steady slope unknown; not high-endGPU or8B privacy acceptance.

Next local: derive the lazy stack length from public launch row0 instead of a
stored per-column count; independently test all chunk schedules, reuse/failure
restarts and memory addresses, charging popcount/index costs. Owner next: native
poisoned hash/complete-receipt gates, then exposed memset/state incidence, capacity
and enclosing verified fixed-context1/2/4/8 clocks under shared locks. No native,
GPU, install, Git, production/runtime write, external message or escalation here.
Saved reports do not establish delivery or supervisor liveness.

Reproduce (each command enforces leaf limits):

```
python3 experiments/commitment-leaf-buffer-20261021/run_bounded.py probe.py
python3 experiments/commitment-leaf-buffer-20261021/run_bounded.py audit.py
```

The patch is `state-memset-elision.patch`; source/hash pins and commands are adjacent.
It is uncompiled and unapplied. `candidate.py::hash_columns` models both state choices;
`audit.py` imports neither candidate nor probe. Initial artifacts/failures are retained.
