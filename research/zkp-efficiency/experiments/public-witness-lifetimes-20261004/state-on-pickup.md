# ZKP efficiency explorer — durable state

Last completed: **cycle 0017**, run `20261003T230146Z-65ad9aeb`.
Started 2026-10-03 23:01:46 UTC; checkpoint 2026-10-03T23:21:02.984726+00:00; deadline 23:21:46 UTC.
No next cycle before 2026-10-04 00:01:46 UTC; supervisor owns scheduling.
Previous state: `experiments/typed-witness-readers-20261003/state-on-pickup.md`.
Saved reports are local artifacts, not delivered external messages.

No complete private trained 8B proof or >=50-token/s result. Target unchanged;
larger workloads permitted. Count independently verified full-stack new
positions only. Fresh masks, RNG and openings; no weaker privacy or real
private witness storage on disk. Prefill, resident independent passes and
authenticated decode remain separate; longer prefill attention grows as T².

[Experiment](experiments/typed-witness-readers-20261003/README.md),
[result](experiments/typed-witness-readers-20261003/result.json),
[handoff](handoffs/20261003-typed-witness-readers.md),
[progress](PROGRESS.md), [dated](progress/20261003T230146Z-65ad9aeb.md).

Exact typed/indexed readers and lazy lookup preparation pass 66 vectors,
1,952 field words, 25 preparation fixtures, 65,816 helper limbs, 20 zero-
denominator refusals and 99 total negative checks. Final 2.432 s / 23,200 KiB,
one Core Ultra 9 185H CPU thread, seed 2026100317. Materialized i64, raw lazy,
typed lazy and independent preparation agree. Synthetic tables/representative
Lks; no native Layout, full-block builder, PCS, mask/RNG or GPU proof ran.
Initial accounting KeyError and intermediate passing result/source retained.

Counted m125 T512 transient payload: 1470.641 ->678.391 MiB raw lazy
->122.363 MiB typed lazy. Raw-only removes 792.25 MiB; combined 1348.277 MiB.
Unregistered 8B T512/1024/2048 combined removal: 4503.582/12382.695/38269.391
MiB. No actual peak, speed or GPU fit established. Common A/H, weights,
helpers, allocator and suffix cache excluded. Packing overlaps 800.754 MiB
at m125 and 2681.699/7363.117/22726.234 MiB at the 8B shapes. Builder still
produces i64 and refuses the required five norm limbs at full signed width4096.
Lazy preparation adds one affine evaluation/read per lookup: 98,598,912
words per m125 layer. Unused public-table zeros still refuse. Private dtype/
cache metadata and exact i64 fallback required. Witness last reads remain
H E/A16 denominators; lazy lookup planes also stay through their H domains.
Timing ceiling N/(T-M+C): removed preparation M, new cost C, full 8B T unknown.

Latest owner diagnostic unchanged: synthetic 12-block T512, one cold shared-
host pass, RTX 4070 Laptop; 408.609 s wall, 318.22 s run prover INCLUDING
witness/segment serialization, 12.15 s in-process verification, 484107456 B,
2113 MiB sampled VRAM. Independent verification false; diagnostic 1.253
positions/s is not counted private-8B throughput. CLI running flag is stale/
interrupted per coordination; no liveness inference or duplicate launch.
Researcher: 0 model passes, 0 countable tokens. Full-model context, steady/
total rates, startup fraction, separate witness/proof/serialization/
verification clocks, drain and lag unmeasured. Device used: CPU only.

Ranked queue:
1. Owner actual GPU SC_SZC, then witness: highest measured recurring costs;
   native bytes/RNG/refusal/transfer/peak and enclosing clocks. Do not duplicate.
2. Raw lazy lookup/index readers: moderate consumer refactor; extra affine
   evaluation, cache/parallelism costs. Falsify no native phase/peak improvement.
3. Typed active/cache readers and public per-plane last reads: owned Witness/
   StackSource changes, exact i64 fallback, private widths and pack-overlap gate.
   Falsify native byte/refusal/RNG mismatch or no actual maximum saving.
4. Bounded suffix replay: Wc-P-U unknown; full long-context cache demoted.
   A 1 GiB payload holds only 2/0/0 of32 layers at T512/1024/2048.
5. Resident fixed-context fresh-proof independent passes: setup, per-pass,
   drain and peak clocks owed. >20 ms per new completed position falsifies
   >=50 steady tokens/s for that schedule; total rate also includes startup.

Next CPU-light experiment: source-pin actual Lk/Ids and derive public last-
read sets. Release A-only planes after A, lookup-only planes after their H
helper domain; retain S8/MX/E and G8/A16 through actual denominator reads.
Independent trace controls must catch early release, reordered reads and
skipped full-table checks. Count the maximum over phases including packing
and common stores, then owner native proof/RNG/refusal/peak/phase gates under
the common resource guard. No heavy benchmark launched by research.

Five LIVE records: Sept30 Pico3.0/MIT repo (history/date gap), Spartan-WHIR
canonical u32 witness interface, older Streaming ZK (2023; v2 May2024;
CCC July15) and small-value sumcheck refresh. GitHub failures recorded;
no full upstream commit pin inferred. Streaming verifier theorem is not a
GPU prover result; no field/protocol/privacy properties transferred.
Rotation: typed memory/lookup -> composition -> GPU NTT/commitments ->
lookup/softmax -> sumcheck/GKR -> batching/amortization -> arithmetic.

Preserve prior negatives and incomplete cycle0014. Write research outside
runtime only; production/Git/receipts/calibration/safety/reviewer files read-only.
One thread, <=60 s / <=512 MiB per experiment. No GPU/build/install/Git/
external write or escalation. Reread AGENDA, STATE, FINDINGS, sources,
latest results and required project memory every cycle.

Final artifact audit passed 2026-10-03T23:21:02.984726+00:00: script/source/snapshot pins, source records, history prefixes and local report links match.
