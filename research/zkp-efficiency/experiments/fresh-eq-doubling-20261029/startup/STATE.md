# ZKP efficiency explorer — durable state

Cycle 0144 COMPLETE: `20261029T135649Z-1526011b`.
Started 2026-10-29 13:56:49 UTC; early checkpoint 13:58:04 UTC.
Final checkpoint 2026-10-29T14:13:51.365086+00:00; deadline 14:16:49 UTC.
Next cycle no earlier than 14:56:49 UTC.

No native proving improvement found. Public coordinate-map reuse passes
210 fixtures, 3,150 synthetic 1/2/4/8-pass replays, 9,450 comparisons,
3,402,855 output-word comparisons, 3,150 fresh-mask checks and 10 negative
controls. R13 priv_table rebuilds two integer maps per call; Layout already
retains slot geometry. The candidate caches only integer geometry. Every
Fixed challenge value, Eq table, private slice and mask result stays fresh.
The research u64 identity is a stub, not native profile admission.

Final shared CPU helper timings improve in 21/36 median comparisons,
versus 27/36 initially. Larger cases sometimes regress. No reliable native
or GPU gain follows. Source-derived 8B T128 metadata: 201–209 sites,
15–16 map signatures, 277,248–279,296 tuple bytes before metadata. All
146.93–153.74 million private-word reads per block remain. Exclusive map,
Eq/table, witness and enclosing-proof times remain unknown.

Probe: 1.571899 seconds, 12,504 KiB RSS; accounting: 16,972 checks;
provenance audit: 844 checks, nine pins, three unchanged native bodies.
An initial control changed an unread word; corrected to the actual slice
offset, with the original harness and logs retained. No arithmetic mismatch.
All commands used one CPU affinity, low priority and bounded time/memory.

All 60 previous hypotheses remain unchanged; hypothesis 61 was added.
Global priorities remain:

1. Whole-prover high-end GPU work and verified resident 1/2/4/8 workloads.
2. Admitted context/DD/fidelity scaling.
3. Exclusive phase and capacity clocks.

Conditional handoff: handoffs/20261029-resident-public-map-plan.md.
Owner next: measure exclusive map/Eq/table/witness/enclosing clocks before
integration. No native patch or heavy job queued. Next local rotation:
quantization/arithmetic incidence of fresh fixed Eq construction, unless
new native phase evidence redirects it. Preserve full fresh CFS/mask work.

Nine LIVE primary records appended, 955 -> 964. New leads: Foundry 2026
and older dynamic CUDA graph node updates with inspected per-file MIT code.
Current release, regular-wiring, sumcheck and October-paper scope checks are
retained. No commit ID/date available for inspected external code; license,
history and release fetch blockers are recorded exactly. No foreign code
executed, no author performance reproduced, no crawl date treated as publication.

New independently verified full-stack proofs / model passes / proved positions:
**0 / 0 / 0**. Actual model context / accelerator: **none**. This cycle used
one pinned Intel Core Ultra 9 185H CPU worker, no GPU. Witness, proof,
serialization, verification, startup and initial-prefill clocks, startup
fraction, proof latency/bytes, steady-state and total-workload rates:
**unmeasured**. No long-context prefill, resident-model proof series or decode
ran. Larger workloads remain allowed; longer dense attention can increase
work quadratically. Complete private 8B >=50 proved tokens/s on an RTX 5090
or named high-end GPU remains **unachieved**.

Carried older-profile CPU 8B baseline: T128/L32, one 16-thread pass, GPU off.
Total 478.737s = 0.267370 positions/s; prove_run 393.785s includes witness
98.348s and block load 17.595s. Sealing 84.824s precedes prove_run; sealing
load 27.151s and witness 80.897s overlap. Receipt 922,711,264 bytes; verify
42.709s plus load 13.681s. Not rerun/reverified or newly counted. Isolated
serialization, startup fraction and steady slope remain unknown. Newer owner
classifier results do not transfer to this older paired baseline.

Experiment: experiments/resident-public-plan-20261029/README.md.
Report: progress/20261029T135649Z-1526011b.md. Prior state/findings/sources
and latest results retained under startup. Only research outside runtime
written; no production, Git, receipts, calibration, instructions, safety or
reviewer changes. No external write/message, installation, purchase, GPU,
large build, escalation or merge. Saved reports are not delivery/liveness.

Final audit 2026-10-29T14:13:51.499930+00:00: 187 checks PASS; all nine native source pins and six owner documents unchanged; prior 955 source records and all 60 previous hypotheses preserved. No new independently verified model work.
