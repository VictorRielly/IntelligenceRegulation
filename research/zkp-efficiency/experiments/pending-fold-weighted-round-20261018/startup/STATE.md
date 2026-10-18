# ZKP efficiency explorer — durable state

Cycle 0070 COMPLETE: `20261017T232105Z-d713e393`.
Checkpoint: 2026-10-17T23:34:26.692594+00:00.
Next cycle no earlier than 2026-10-18 00:21:05 UTC.
AGENDA/current target and durable/project memory consulted; 365 starting
sources parsed and latest three results read. Originals/hashes under
experiments/factorized-public-equality-20261017/startup/.
Six LIVE primary records appended, 371 total; original prefix preserved.
Report: progress/20261017T232105Z-d713e393.md. No native speedup found.

Factorized distinct-column public equality probe passes 84 synthetic cases,
30 prior fixtures, 1,788 round values, 252 E/S/V terminals, 447 whole-cube
masked-chain rounds and 22 controls. Independent audit: 4,768 checks.
Causality: 1,699 unchanged-prior-round checks +1 sensitivity control.
Main 3.151398 s including compile/oracles, 28,696 KiB; compiler135,348 KiB.
Audit7.180672 s/21,272 KiB; causality0.111618 s/16,732 KiB. One Core Ultra9
185H CPU0 thread, nice19, seed2026101770; each command <59 s /512 MiB AS.
Initial21-control PASS and audit doc-comment-extraction failure retained;
exact source check repaired, no arithmetic change. No native/GPU proof,
GKR, PCS, entropy or real private data. Commands, pins, logs and limits saved.

NEW: per-column prefix factors and DFS suffix weights replace full public
E/S/index arrays; one owned column-major V buffer remains. After row bits,
E is a mixture of distinct row equalities, S is non-Boolean; all terminals
remain. Base quadratic row rounds do not permit fewer cubic masked samples.
Probe is not a complete/minimal lookup argument or native byte-preserving
replacement. Only fixed PUBLIC shape support; no hidden prompt lengths,
private selectors/masks or numerical witness sparsity. All earlier diagonal/
rank, joint-mask, D/C, full-i64 wrapping, unused-table-zero, off-cube-product,
singleton leakage and endpoint-history negatives remain.

Counted four groups at prior8B T32: naive index+E+S+V625.625 MiB ->178.783936
MiB with conservatively summed small payload; largest group94.017731 MiB.
Aggregate payload, not peak. Source witness/query data remains live. Local
caps refuse large groups, no large-shape run. Extra suffix-generation
23,426,212 logical Fp2 multiplies; weighted and fold passes each read
23,428,954 values, fold writes11,714,477. No DRAM/runtime claim. All83
ordered original-A/wrapping links, distinct-point reduction, GKR, fresh masks,
extensions/H/M/PCS/soundness/joint privacy remain. Extra query commitment
saving zero. Handoff: handoffs/20261017-factorized-public-equality.md.

Current carried functional R5b 8B T32: fresh verification, 11 controls/honest
recheck; one cold 32-block pass, 16 CPU threads, GPU off, shared n=1. App191.755 /
process191.975140 s, diagnostic total0.166880/0.166688 positions/s. Sealing
37.214 s = 19.407056%; load 35.798/witness 32.584 cumulative clocks overlap
within sealing. Prove154.427 includes reload 19.052, zero witness rebuilds;
remainder135.375 includes serialization/sink. Fresh load14.507 +check32.248
(reload17.015/crypto15.233); verifier process141.571000 incl controls.
Receipt465,815,776 B; guard RSS4.73/cgroup7.09 GiB incl cache. Shape privacy
acceptance open; startup beyond sealing, prefill, steady slope, serialization,
latency/lag/drain unknown. Old R5 cli3 clocks retained in prior reports.
Free deletion of four direct H phases 21.568 s ->1.126731x /0.188028 diagnostic
positions/s, keeping other work fixed, before added costs. Only that phase
set bound, not whole architecture/shared zero-check/GPU/5090.

Owner R5b full suite692 pass/0 fail/31 ignored, 29 targets; profile/privacy
review separate. GPU owner warm1.1B T128 confirms ramp but190 s versus prior
159 s includes22*300 ms warm-up; no enclosing gain. Logical plan-byte
bandwidth11.7% lean/8.0% default, not measured DRAM; new kernel-design round
started23:22 behind guard. No duplicate heavy/device job launched here.

Ranked hypotheses:
1. OWNER whole-prover kernel design and contiguous useful GPU work. Charge
   arithmetic/coalescing/spills/idle ramp/launches/transfers/memory/drain;
   reject no enclosing gain or transcript/privacy/verification failure.
2. OWNER immutable public residency after R5b sealing. Measure fixed-context
   complete fresh-pass slopes plus startup/witness/serialization/verify/drain;
   charge identity/invalidation/RAM. Reject stale data/backlog or recurring
   >20 ms/new position for a50/s claim. No mask/opening reuse.
3. TESTED factored per-column row-first lookup representation: lower counted
   payload/parity only; all83 original links and complete protocol costs.
   Reject any mismatch or no enclosing time/peak gain. Full ceiling unknown.
4. NEW NEXT LOCAL known-previous-challenge pending fold + NEXT weighted round.
   Moderate stateful SumcheckRounds adapter, extra weighted arithmetic/final
   drain. Current challenge is unavailable before its message. Compare all
   rounds/finals/causality/read counts; reject mismatch or costs erasing gain.
5. NEW older Orion linear commitment/code switching: high backend migration.
   2023 corrected paper needs full random-vector masks and commit-and-prove;
   inspected2022 repo does not establish fixes. Runtime untested, low priority.

Next local: implement pending-previous-challenge row adapter against saved
factorized/dense oracle, preserve column-tail cubic messages/all terminals,
and count combined fold+next contraction reads/arithmetic. Native seam is
SumcheckRounds/prove_rounds; complete new lookup also needs private_block
protocol/argument/shape/layout H/M/PCS. Owner/Claude reviews/integrates; no
production patch or heavy job queued. Next owner: kernel verdict and complete
resident-workload slopes with fresh independent verification/full clocks.
Rotation next NTT/commitments+memory; lookup/softmax, quantization, composition
queues retained. Primary dates/licenses/commits/fetch failures explicit.

New target-compliant proofs/passes/positions:0/0/0. Target steady/total rates
and proof clocks unmeasured. No resident repeats, long prefill or decode here.
Larger workloads/fresh masks allowed; attention can grow quadratically and
decode needs proved state. ≥50/s private 8B high-end-GPU target unchanged,
unachieved. Production/runtime/Git/receipts/calibration/instructions/reviewer
files untouched. No installs, external messages or escalation. Reports saved
as checkpoints; this does not establish external-message delivery.
