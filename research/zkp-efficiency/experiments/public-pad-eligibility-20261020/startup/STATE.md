# ZKP efficiency explorer — durable state

Cycle 0099 COMPLETE: `20261020T071854Z-1076bec1`, checkpoint 2026-10-20T07:35:30.951164+00:00.
Deadline: 07:38:54 UTC. Next cycle no earlier than 2026-10-20 08:18:54 UTC.
Evidence: experiments/gl-only-fzc-20261020/. Prior state and startup documents retained.

No proving speed improvement measured. The host-free BASE GL-only adapter
passes 36 Python fixtures, 144 rounds, 2,372 checks, 15 negative controls and
90 partial source-cost cases. Independent original-slot polynomial and direct
original-table MLE checks agree on canonical round bytes, high stores and
final original/derived/polynomial values. Only 18 first rounds use BASE;
PL and non-BASE paths stay literal. Synthetic data and challenges only; no
native masks, transcript, PCS, receipt or verifier ran. Kh uses trained shifts
9..16; 8/16/32 cube entries are not model contexts. Three supplemental PL-only
extension probes do not broaden eligibility. Artifact validation: 223 checks,
eight native source pins unchanged. One CPU thread, final leaf 2.415 s /
17,012 KiB RSS, 59 s CPU/alarm, 60 s parent, 512 MiB caps. No build or GPU.

At illustrative L=2^21, support on, k=11, versus literal source: remove
14,680,064 counted base products, 97,517,568 adds/subs and 256 MiB logical
shared reads. Add no host preweights, parameter bytes, global storage or
barriers. The full prepared BASE pair saves more source work but requires
k fresh Fp2 preweights / <=176 parameter bytes. Keep both for native review.
Counts are not instructions, traffic or time. Compiler elimination, registers,
branch/occupancy effects and exclusive phase fraction f remain unknown; even
full phase deletion permits only 1/(1-f). Reject parity, eligibility, refusal
or receipt mismatch, absent compiler savings or enclosing regression. Keep
both extension coordinates, high stores and existing raw/BASE/next==0 rules.
The adapter sketch is uncompiled; no production patch or privacy acceptance.

Ranked queue: 14 entries in experiment hypotheses.json. First: owner whole
GPU plus independently verified resident 1/2/4/8 passes; owner DD larger
contexts after T128 null; actual capacity/raw/BASE/public-pad/exclusive-phase
measurements; GL-only versus full-pair native choice; public loader; capacity-
gated arena; preserved OUT/early-release/arithmetic/protocol negatives; new
lookup/composition screens. Each records baseline, removed work, costs,
prerequisites, exactness, privacy/soundness, ceiling and falsification.

Next local: census Rust public pad-weight construction and existing raw,
BASE and SUPP gates to establish reachable k, without private scans. Owner
compiler/phase results take priority over further source-count refinements.
Next owner: shared-lock literal/GL-only/full-pair native A/B; ptxas registers/
spills, actual eligible incidence/public pad counts, exclusive and enclosing
clocks, masked rounds/next challenges/full receipt identity, fresh independent
verification and strict-GPU/refusal/CS/H-1/current privacy gates.
Handoff: handoffs/20261020-gl-only-affine-fzc.md. No merge here.

Current register: R9 DD soundness accepted at three profiles with N-r9-a
(row Sum/slot17/Ht) and N-r9-b (M_dd in A; commit before challenges). DD
privacy gate still owed. T128 478.7 -> 474.9 s is shared-box n=1 and explicitly
null. D33 frozen R7 TinyLlama T32 scope is unchanged; D27/D30/D32/D34/D35 and
owner R10 obligations remain.

Carried non-DD CPU 8B T128/L32, one 16-thread pass, GPU off: total 478.737 s
=0.267370 positions/s; prove_run 393.785 includes witness 98.348/load 17.595;
seal 84.824 overlaps; receipt 922,711,264 B; fresh verify 42.709+load 13.681 s;
recheck 34.395+load 10.739 s. Not rerun/reverified. Startup, steady slope and
isolated serialization unknown. New verified full proofs/passes/positions:
0/0/0. Actual model context/device: none. All new witness/proof/serialization/
verification clocks, startup fraction and steady/total proved rates UNMEASURED.
No long prefill, resident-model pass or decode. Complete private 8B >=50
proved tokens/s on RTX 5090/another named high-end GPU remains unachieved.
Larger workloads allowed; attention may grow quadratically. No mask/opening
reuse or privacy weakening.

Six LIVE records appended (571 -> 577): newly assessed older composition
paper (February 20 / June 15, 2026), new TenseUp primary-index lead (October
10; page/PDF blocked), DeepProve custom license, NanoZK, SP1 6.9.0/full commit
and October zkLLMPoT refreshes. Exact dates, license/commit scope and access
failures retained; no author performance reproduced. Next rotation: GPU
commitments/NTT, memory/resident batches, quantization, private KV/composition,
sumcheck/GKR, lookup/softmax.
Only research excluding runtime written. No production/Git/build/GPU/install/
external writes/messages/purchases/escalation. Progress and dated report saved;
these do not imply external message delivery.
