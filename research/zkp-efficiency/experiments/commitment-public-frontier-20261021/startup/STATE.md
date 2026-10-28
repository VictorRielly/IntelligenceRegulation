# ZKP efficiency explorer — durable state

Cycle0123 COMPLETE: `20261021T071854Z-0fa6988f`. Checkpoint UTC: 2026-10-21T07:34:42.480903+00:00.
Started07:18:54UTC; hard deadline07:38:54UTC; next cycle no earlier than
2026-10-21T08:18:54Z. AGENDA read at startup and checkpoint. Required prior memory,
782 sources and project notes snapshotted in
`experiments/commitment-leaf-buffer-20261021/startup/`.

No proving gain measured. StreamingBLAKE3 model passes 328,043 checks/27
synthetic shapes/11control types against installed independent blake3 1.0.9.
Independent labelled-subtree/source/cost audit passes 1,050,682 checks,
1024chunk counts/seven source pins. Diagnostic clocks/RSS and hard limits in
result.json/audit-result.json/commands.jsonl: one CPU, <5s/<30MiB RSS each.

193u32/column current state can be modelled with ceil(log2(ceil(rows/128))) CV
levels+count; capacity request saves38MiB at frozenT128 and68–72MiB at countedT512
per A/H commitment. Active CV traffic/compressions identical. First-launch local
count0 removes all state memset in model; length-only init also tested.
Full pooled backing may be larger than request; request reduction can saveZERO
backing. No native/CUDA execution, allocator/HWM/time or private receipt evidence.
Uncompiled first-launch/no-memset patch is narrower than dynamic-depth model.
No masks/salts/openings reused or original refusal/profile changed.

All35prior hypotheses retained;36 tested state candidate,37 new MARS screen.
Owner top4 unchanged: wholeGPU+verified resident1/2/4/8; DD/fidelity larger-context;
complete private phase/capacity clocks; native all-elevenFZC A/B. Prior dense bits,
NTT-cache, scratch-pool and other negatives retained. D37–D41 product direction
does not alter8B target; LOW/HIGH excluded from frozen geometry census.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Device: one Intel Core Ultra 9 185H CPU
worker. Witness, proof, serialization, verification and startup clocks, startup fraction,
steady-state and total-workload rates: **unmeasured**. No long-context prefill,
resident-model proof series or decode ran. T128/T512 are counted geometry only;
T512 is unregistered and LOW/HIGH fidelity layouts are excluded. Larger workloads
remain allowed; attention can grow quadratically. The complete private8B / >=50
proved tokens/s target on RTX5090 or a named high-end GPU remains unachieved.

Next local: derive lazy count from public first chunk index and independently
test chunk schedules, poisoned reuse/failure restart and address bounds; count
popcount/index costs. Owner next: native poisoned hash+receipt/privacy gates,
actual removed memset critical-path time/capacity and verified resident sweep.
Handoff `handoffs/20261021-streaming-blake3-state.md`; main/Claude reviews/integrates.

NineLIVEqueries/eightprimaryrecords appended. MARS2026 newly assessed, olderBLAKE3
stack sizing tested; BatchZK/ChimeraOct16/MORPH/Poseidon scope filtered. BLAKE3
fullcommit inspected; releaseAug20 yearunknown. MARSLICENSE/history cachemiss and
paper404,BLAKE3PDF unsupportedtype retained. No foreign code executed/installed.

Carried historical CPU nonDD8BT128L32: total478.737s=0.267370positions/s;
prove_run393.785s incl witness98.348s/load17.595s; seal84.824s overlaps.
Receipt922711264B; freshverify42.709s+load13.681s; recheck34.395s+load10.739s.
Not rerun/reverified; startup fraction/serialization isolation/steady slopeunknown.
No complete high-endGPU or8B privacy acceptance inferred.

Only research outside runtime written; no production/Git/receipt/calibration/
instruction/reviewer edits, build/GPU/install, external write/message or escalation.
Saved reports do not establish delivery/liveness. Final artifact audit is complete.

Final evidence audit: 302 checks PASS; 61 immutable artifacts and seven live source pins match. All782 prior sources,10562 prior findings lines and35prior hypotheses retained. Finalized UTC: 2026-10-21T07:37:06.437012+00:00.
