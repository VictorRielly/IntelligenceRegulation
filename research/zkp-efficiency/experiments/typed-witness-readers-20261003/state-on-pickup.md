# ZKP efficiency explorer — durable state

Last completed: **cycle 0016**, run `20261003T220146Z-cf20886e`.
Start 2026-10-03 22:01:46 UTC; checkpoint 2026-10-03T22:21:05.576293+00:00. Normal deadline22:21:46 UTC.
No next cycle before23:01:46 UTC; supervisor owns schedule. Saved reports
are local artifacts, not delivered messages. Previous state retained in
`experiments/witness-suffix-replay-20261003/state-on-pickup.md`.

## Result and target

No complete private trained8B proof or >=50-token/s result. Target unchanged;
larger workloads may amortize startup. Only independent full-stack verified
new positions count. Report steady/total rates, startup fraction, witness/
proof/serialization/verification, context, passes, device and drain/lag.
Prefill attention quadratic; resident independent passes are not decode.
Fresh masks/randomness/openings; no weaker privacy or disk witness cache.

[Experiment](experiments/witness-suffix-replay-20261003/README.md),
[result](experiments/witness-suffix-replay-20261003/result.json),
[handoff](handoffs/20261003-witness-suffix-replay.md),
[progress](PROGRESS.md), [dated](progress/20261003T220146Z-cf20886e.md).

Lossless in-memory suffix replay passes 110 byte comparisons, 670 reduced
forward-plane comparisons, 13 schedules, 20 control categories. Final
0.097s / 18,556KiB RSS, one Core Ultra9 185H thread,
seed2026100316; no accelerator/build/native receipt/trained payload. Test
forward omits native norm/RoPE/nonlinear tables: no full-block equivalence.
Source count matches independent toy/m125 i64 layout. Counted typed m125
122.36MiB/layer; unregistered Llama3 T512/1024/2048 385.18/1106.34/3556.67MiB.
Whole typed stack12.04/34.57/111.15GiB, excluding proof/weights/pack overlap.
1GiB payload retains2/0/0 layers of32. Full replay is not small-memory work.
Width4096 full signed range needs5 norm limbs; inspected builder accepts4.

Initial toy score refusal retained; reduced fixture divisor4->32 only.
Intermediate budget-refusal design REJECTED and retained. Final cache budget
evicts/skips and recomputes, adding no input-dependent refusal. Cache dtype,
digest, occupancy/hits and data-dependent build counts stay private; current
driver public build totals require integration review. No RNG/proof state cache.
Net saving Wc-P-U; Wc native/full8B unmeasured, no numerical rate ceiling.

## Latest owner evidence and missing clocks

Synthetic12-block T512 RTX4070 Laptop n=1 cold/shared host:408.609s wall,
318.22s run prover INCLUDING witness/segment serialization,12.15s in-process
verify,484107456B,2113MiB sampled VRAM. Independent verification false; its
1.253 positions/s is diagnostic and not counted private8B. CLI running flag
stale/interrupted per coordination; no liveness inference/relaunch.
Researcher completed0 model passes/countable tokens; model context, steady/
total verified rate/startup fraction/separate witness/proof/serialization/
verification/drain/lag clocks unmeasured. Older one-block GPU mean30.055s
process,8.215s witness,17.130s prove,.815s same-process verify;3.895s residual
is combined serialization/startup/other, not initialization measurement.

## Ranked queue and next action

1. Owner actual GPU SC_SZC then witness: highest measured recurring costs;
   exact transcript/native parity/transfer/peak/full-proof gates. Do not duplicate.
2. Tested bounded suffix replay: cached second builds only; native value/refusal/
   RNG/byte/peak gates and positive Wc-P-U needed. Demote full caching at longT.
3. **New next research:** typed active witness readers at `protocol.rs` -> Fp
   A rows and later lookup/helper consumers, avoiding full i64 expansion.
   Falsify signed/pad/empty/field/lookup mismatch or no actual peak saving.
4. Resident fixed-context fresh-proof independent passes; measure setup/drain/
   perpass clocks. >20ms/new completed position falsifies50/s schedule.
5. Inverse-store NTT pad/coset fusion; no native time/peak evidence; q>n separate.

Next CPU-light experiment: independent Goldilocks conversion plus typed indexed
lookup/exp/activation reads using small synthetic exact planes, source-pinned
last-read lifetime ledger. `protocol.rs`798–802 reads witness into A Fp rows;
witness persists through exp/act helper denominators908–910. No early drop.
Need owner native proof-byte/RNG/refusal checks and existing separated clocks
under common resource guard before promotion; no benchmark launched here.

Five LIVE primary records: Checkmate/paper/Apache2 repo, Adacc, HybridServe,
Sept22 FASTAR. Commit/history/API inaccessible, no commit/date inferred.
Lossy INT4 rejected for exactness; inference checkpoints not complete proof.
Rotation: typed memory/quantization -> composition -> GPU NTT/commitments ->
lookup/softmax -> sumcheck/GKR -> batching/amortization.

Preserve all prior negative findings and incomplete cycle0014. Write only
research outside runtime; production/Git/receipts/calibration/safety/review
files read-only. One CPU thread <=60s/experiment <=512MiB; no GPU/heavy build,
install/downloaded script/external writes/messages/purchases/Git/escalation.
Reread AGENDA, STATE, FINDINGS, sources/latest results/project memory next cycle.

Final artifact audit passed 2026-10-03T22:21:36.660840+00:00: script/source/snapshot pins, source records and local report links match.
