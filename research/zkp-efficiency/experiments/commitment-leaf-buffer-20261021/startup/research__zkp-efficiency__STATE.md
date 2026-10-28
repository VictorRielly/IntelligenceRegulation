# ZKP efficiency explorer — durable state

Cycle 0122 COMPLETE: `20261021T061854Z-553803c5`. Checkpoint UTC: 2026-10-21T06:33:06.819634+00:00.
Started 06:18:54 UTC; deadline 06:38:54 UTC. Next cycle no earlier than
2026-10-21T07:18:54Z. AGENDA read at startup and checkpoint. Required project
notes, prior state, findings, 773 source records and latest results retained
under `experiments/affine-u8-source-sharing-20261021/startup/`.

No proving gain measured. Source-sharing semantics: 872,684 checks,
838 native descriptor instances, 608 families, 132,564 exhaustive bit
assignments and 26 control types PASS. Independent audit: 219 checks,
244 families, six native source pins, two source-mutation controls PASS.
Exact checker clocks and RSS are in result.json/audit-result.json; each <7 s,
<18 MiB RSS. One CPU, nice 19, seed 202610210122, 30 s CPU/alarm,
35 s parent, 256 MiB address-space cap, 64 MiB estimate. No native/GPU job.

Dense source-shared bit data still costs 4.82–5.46x native U8H; reject that
representation. Signed endpoints, scaled top bits, Booleanity, ordered original
A links and padded-source zero rules remain. Signed source zero encodes 127;
zero-filled bitplanes are wrong. No private bit protocol or mask/group budget.

Small conditional lead: at frozen w_s=16/T128, top-byte sr:1 and sg:1 checks
are exact aliases. Non-DD S13→11 queries; DD Dd9→7. One fewer H plane gives
H rows 3790→3724 or 3634→3616, saving 8.25 / 2.25 MiB data+mask per block.
A+H payload fractions: 0.9173% / 0.2602%. T512 has zero benefit. These are
per-block 8B geometry inventories, not whole-model timings or physical peaks.
Both histogram and helper sides must change consistently; all table denominator
refusals remain. New transcript/profile, M/receipt/group costs and native
privacy review are unresolved. No accepted production profile was changed.

Rankings: all 34 prior hypotheses retained; rank 25 refined, rank 35 added.
Owner top four remain: complete GPU plus verified fixed-context resident
1/2/4/8; larger-context DD with cheapest passing fidelity; complete private
phase/capacity clocks; native all-eleven FZC A/B. Scratch pool remains parked.
DD's 13/13 gate evidence is not DD privacy or 8B/GPU acceptance. Newer LOW/HIGH
layouts are excluded here; D41/media-app work does not amend this target.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: none. Research device: one Intel Core
Ultra 9 185H CPU worker. Witness/proof/serialization/verification/startup clocks,
startup fraction, steady-state and total-workload rates: unmeasured. No
long-context prefill, repeated resident proofs or decode. Larger workloads
remain allowed; attention may grow quadratically. The complete private 8B
≥50 proved tokens/s target on RTX 5090 or a named high-end GPU is unachieved.

Next local: inspect aliases in the owner's actual cheapest passing fidelity
layout; independently count full M/receipt/functional/group deltas and prepare
native failing-first tests before any patch. Owner next: enclosing/exclusive
GPU clocks, actual capacity and verified resident 1/2/4/8 under shared locks.
Rotate to memory traffic/commitments and composition; do not repeat dense bits.
Handoff: `handoffs/20261021-affine-u8-sharing.md`; main/Claude reviews/integrates.

Nine LIVE queries/nine source records appended. Newly assessed older field-range
tutorial and signature-encoding tradeoff; current Plonky3 components/releases,
Twist Oct17 and Chimera Oct16. Plonky3 root MIT inspected; tutorial license
unknown. Linked full merge ID retained, commit body inaccessible; no inspected
commit pin. Release year unknown. PDF403/cache misses/inaccessible primary
failures retained; no bypass, foreign-code execution or author rate reproduced.

Carried historical non-DD 8B T128/L32, one 16-thread CPU pass, GPU off:
478.737 s total = 0.267370 positions/s. prove_run 393.785 s includes witness
98.348 s/load 17.595 s; seal 84.824 s overlaps. Receipt 922,711,264 B;
fresh verify 42.709 s + load 13.681 s; recheck 34.395 s + load 10.739 s.
Startup fraction, isolated serialization and steady slope unknown. Not rerun
or reverified here; no high-end GPU or 8B privacy acceptance inferred.

Only research outside runtime written. No production/Git/receipt/calibration/
instruction/reviewer edits, build, GPU, install, external write/message,
purchase or escalation. Saved reports do not establish delivery/liveness.
Final evidence audit is complete.

Final evidence audit: 1453 checks PASS; 54 immutable artifacts and six native source pins match. All 773 prior sources, 10,447 prior findings lines and 34 prior hypotheses retained. Finalized UTC: 2026-10-21T06:34:54.132760+00:00.
