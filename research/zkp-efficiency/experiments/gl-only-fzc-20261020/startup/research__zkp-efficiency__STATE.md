# ZKP efficiency explorer — durable state

Cycle 0098 COMPLETE `20261020T061854Z-03bda577`; checkpoint 2026-10-20T06:35:36.293240+00:00.
Deadline 06:38:54 UTC. Next cycle no earlier than 2026-10-20 07:18:54 UTC.
Evidence: experiments/base-affine-fzc-20261020/.

No proving speed improvement measured. BASE specialization of paired raw
round-zero GL/PL derivation passes 36 Python fixtures, 144 rounds, 1,669
checks, 18 negative controls and 90 partial source-cost cases. Independent
schoolbook original-slot polynomial/direct-original-MLE round bytes, high
stores and original-table finals agree. Only 18 first rounds use BASE;
later/extension rounds use the fallback. Synthetic data/challenges only;
no native masks, transcript, PCS, receipt or verifier ran. Kh=2^1/2^20 stress
is outside trained sh_h 9..16, not profile admission. Artifact validation:
67 checks, eight current native pins unchanged. One CPU thread, final leaf
1.555 s / 16,948 KiB; no build/GPU/install.

At illustrative L=2^21/support/k11, versus current literal source: remove
44,040,192 base products, 347,078,656 adds/subs and 608 MiB logical shared
operand reads. Versus prior paired: remove 37,748,736 products, 282,066,944
adds/subs and 304 MiB reads. Precompiler source counts, not instructions,
actual traffic or time. No global/capacity saving or new barrier. Add fresh
k public Fp2 preweights per sumcheck, <=176 parameter bytes/staging and template
code. Relative to prior paired, no new setup. Compiler/register/occupancy and
elapsed benefit unknown. Coefficients/results remain Fp2; BASE ends before
the first challenge fold. High reconstruction/store retained. Existing
Host/Public eligibility checks must not be broadened; no new private scan,
zero dispatch, telemetry or privacy acceptance.

Ranked queue (12 entries, full obligations in hypotheses.json):
1. Owner whole GPU plus independently verified resident 1/2/4/8 passes.
2. Owner DD larger-context scaling after the T128 null result.
3. Actual peak/raw/BASE/public-pad/exclusive-phase measurements.
4. Tested BASE paired derivation; 5 public loader; 6 capacity-gated mixed arena
   and implicit tables; 7 demoted OUT eviction; 8 rejected earlier release;
   9 NTT/constants; 10 prepared metadata; 11 NEW upstream carry negative;
   12 NEW older packed-protocol filter.
Unknown exclusive fraction f: even deleting the entire phase permits only
1/(1-f); this candidate removes part and adds setup. Reject any field/high
store/round/next-challenge/refusal/receipt mismatch, invalid eligibility,
compiler elimination of the alleged redundancy or enclosing regression.
Prior negative findings remain preserved.

Next local: compare BASE GL-only requiring no new host coefficients against
the full prepared pair; independent original math and sparse-pad counts first.
Next owner: locked tiny native A/B, ptxas registers/spills, actual raw/BASE
eligibility, exclusive and enclosing clocks, masked-round/next-challenge and
full receipt identity, fresh verification, strict GPU/refusal/CS/H-1 and current
privacy gates. Keep parameters/fallbacks, private owners, fresh masks/draws and
one-opening schedule. candidate_base_pair.cuh is an uncompiled sketch, not an
applied patch. Handoff: handoffs/20261020-base-paired-affine-fzc.md. No merge.

New register evidence at 05:59 UTC: R9 DD soundness ACCEPTED at three profiles,
with N-r9-a (row Sum/slot17/Ht) and N-r9-b (M_dd in A, commit before challenges).
DD privacy gate still owed. This supersedes prior review-pending state.
T128 478.7 ->474.9 s is n=1/shared-box, explicitly no measurable change.
R10 range counting is owner-owned. D33's frozen R7 TinyLlama T32 privacy scope
is not extended; D27/D30/D32/D34/D35 obligations remain.

Carried non-DD CPU 8B T128/L32, one 16-thread pass, GPU off: total 478.737 s
=0.267370 positions/s; prove_run 393.785 includes witness 98.348/load 17.595;
seal 84.824 overlaps; receipt 922711264 B; fresh verify 42.709+load 13.681 s;
recheck 34.395+load 10.739 s. Not rerun/reverified. Startup, steady slope and
isolated serialization unknown. New verified full proofs/passes/positions:
0/0/0; actual model context/device none. All new witness/proof/serialization/
verification clocks, steady/total proved rates and startup fraction UNMEASURED.
No long prefill, complete resident pass or decode. Complete private 8B >=50
proved tokens/s on RTX 5090/another named high-end GPU remains unachieved.
Larger workloads allowed; attention may grow quadratically. No mask/opening
reuse or privacy weakening.

LIVE sources 565 ->571: NEW older packed 2025/719 (September14 revision),
NEW July prime-ir409 measured-and-rejected carry/128-bit accumulation, SP1
recent6.9.0/full commit, Bits Under ZK-LLM, October zkLLMPoT v2 and extended
sumcheck. Dates/license/commit limits and Internal Error failures explicit.
No author performance reproduced. Next rotation: lookup/softmax, composition/
private KV, GPU commitments/NTT, batching/memory, quantization, sumcheck.
Only research excluding runtime written; no production/Git/build/GPU/install/
external write/message/purchase/escalation. Progress and dated report saved;
these do not imply external message delivery.
