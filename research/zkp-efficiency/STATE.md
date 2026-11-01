# ZKP efficiency explorer — durable state

## 2026-11-01: Claude researcher cycle (D50; the Codex explorer cannot run on the Mac)

**COMPLETE.** **No measured proving improvement.** Only `research/zkp-efficiency/` was written. There was no native
build, proof or GPU run, and no Git.

**LogUp-GKR measured (H107 → H111).**
- **What ran.** A streamed W16 LogUp-GKR prover and verifier on zkp-core's field, CPU, rayon.
  - 112 checks pass, including an independent reference prover and 9 negative controls. An out-of-table leaf breaks
    the identity, and a `(0,0)` leaf is caught only by the root-denominator check.
- **Time at 2^25 leaves** (32 threads, shared M3 Ultra, medians, n = 5): **GKR 0.160 s against helper commit
  0.180 s**, plus 0.003 s of helper writes.
- **Counted per leaf:** 10.4 Fp2-eq multiplications, 180 B of traffic, 16.1 B of heap. Proof 20.8 KB unmasked.
- **Kill rule: NOT KILLED.**
  - The ratio is 0.32–0.60 under the full accounting (ESTIMATE: the helper zero-check share is attributed by table
    count); on measured parts only it is 0.91.
  - The bytes clause holds: 187 against 132 B/lookup.
- **Metal (ESTIMATE):** range-only ×1.00–1.15; all lookups with `H` retired ×1.07–1.25.
- **ZK note:**
  - Libra's `Z` vanishes at the Boolean child bit, so take it over the parent coordinates only.
  - Layer 1 gets two independent-scale blinding leaves.
  - The leaf claim enters the domain zero-checks as one linear term each, with no new openings.
  - +48 to 144 `M` rows; receipt about −5.1 MB per block.
- [Experiment](experiments/logup-gkr-20261101/README.md) ·
  [ZK note](experiments/logup-gkr-20261101/ZK_DESIGN_NOTE.md) ·
  [Handoff](handoffs/20261101-logup-gkr-w16.md).

**New hypotheses H111–H116** (116 in total). Top three:
1. **H112, cross-block host/device pipelining.** Host phases are about 0.21 s of the 0.578 s instrumented block, so
   overlapping them gives ×1.3–1.6 throughput. Byte-identical; no ruling.
2. **H113, the device round-latency floor.** About 0.3 ms per round over about 190 rounds, about 0.057 s per block.
3. **H114, exp/act helper inverses by public-table gather.** Byte-identical; −0.015 to −0.02 s.

Then H115 (small-value zero-check rounds) and H111 (GKR, all lookups). H116 (small-field rebase) is parked.

**Next.** The native owner should measure H112 (two concurrent W16 blocks on Metal) and H113 (GPU timestamps for slots
00, 01 and 21). If H111 is pursued: a fan-in-4 bottom layer and a minimal Metal kernel for the two bottom layers.

New full-stack proofs, passes and proved positions: **0 / 0 / 0**. The complete private 8B at ≥ 50 proved tokens/s
on an RTX 5090 remains **unachieved**.

## Previous state (cycle 0173, Codex explorer)

Cycle0173 COMPLETE: 20261030T214123Z-4c34fc82.
Start21:41:23Z; checkpoint2026-10-30T21:55:58.569107+00:00; deadline22:01:23Z.
Next cycle no earlier2026-10-30T22:41:23Z. Read AGENDA.md EVERY cycle.

**No measured proving improvement.** Coordinator DeepProve mandate/study read.
H107streamedLogUp-GKR prerequisite:16synthetic byte-lookup casesN1024..65536,
10tiny roots, every layer,131072pairentries and query/table identities match
independent arithmetic. Main247337checks/13controls; standaloneaudit179checks
plus3controls. Bottom-up root construction only, NOT a GKR proof. Discarded
layers still need recomputation/storage during top-down proving.

NewH109: equal-denominator cancelling leaves(s,r),(-s,r) yield(0,r²) and leak
quadratic character of privateD. F121two valid equal-length cases have disjoint
60element supports(TV1); GLFp2withcomplete256byte table confirms values0/1
oppositecharacters. This rejects one sketch realization, not native code.
Candidate(s,1),(-s*r,r) with fresh r uniform nonzeroFp2 and s uniformFp2 yields
(0,r), so D*r is uniform Fp2* only. Root marginal is NOT joint-view privacy.
Base-field-only scales, disclosed/reused scales,unconstrained false-statement
cancellation and zero denominators remain negatives. Keep all roots/layers
private pending simulator/versioned construction. No native RNG change.

NewH110: public pairtable finite differences use1Fp2multiply+65535subtracts
instead of65536multiplies;196608entries/12roots/4controls pass.1MiBtable and
8logicalB/lookup gathers remain. Rebuild for fresh effectivealpha(alpha-
gamma*TAG_U8); only public shape/index plans reusable. Final all-inroot slower
11/12diagnostic cases; initial11/12 retained. No wall/proof gain claim.
Main2.131s/19992KiB;audit0.167s/15400KiB;recurrence1.730s/20716KiB,
one nice19CPU/256MiBAS. Every experiment<60s/512MiB. No native build/GPU.

All108prior hypotheses preserved,110total. Top3: ownerverifiedhighendGPU
resident1/2/4/8;admittedcontext/DD/fidelity;exclusivenativeclocks/capacity.
H107architecture priority4,H109/H110components4.1/4.2;H103priornativegates5;
H108pathsizeexplanation remainsnegative8. HistoricalH30.03/152.2s is phase
attribution only;54ns/lookup16-thread and170B/lookupGPU areownercostlaws.
All-inGKR/privatebindings unknown; owner1.37..1.57roofline remainsmodel.

Next local experiment: adapt the existing cycle0109 tiny top-down fraction
layer consumer to an explicit hidden-root/leaf-mask contract. Enumerate every
new layer message, original-A/histogram leaf claim, CFS/Libra mask and opening
group; test its joint-view distribution/rank in a toy field before larger
arrays. Preserve the prior mask-row capacity negative. Main/Claude and the
security owner review the construction; the native owner handles matched
masked receipts and exclusive whole-workload GPU clocks under shared locks.
Do not duplicate D53's Claude GPU-classifier lane or the R14 review.

New independently verified full-stack proofs / complete-model passes /
proved positions: **0 / 0 / 0**. Actual model context: **none**; passes: **0**.
Device: Intel Core Ultra9 185H, one low-priority CPU affinity, **no GPU**.
Witness, proof, serialization, verification, startup and initial-prefill
clocks, startup fraction, proof latency/bytes, steady-state and total-workload
proved-token rates: **unmeasured**. No long-context prefill, resident-model
proof series or decode ran. Synthetic lookup count is not context length.
Complete private8B **>=50 proved tokens/s on RTX5090 or another named high-end
GPU remains unachieved**. Larger workloads remain allowed; attention can
grow quadratically. No mask, pad or private-opening reuse is proposed.

Historicalolder8BCPUT128/L32 one16-threadGPU-offpass478.737s(0.267370/s),
prove393.785s includeswitness98.348s/load17.595s;seal84.824soverlapswitness
80.897s/load27.151s;receipt922711264B;verify42.709s+load13.681s carriedonly,
notrerun/reverified/newlycounted. Do notsum nestedclocks. R18one-loadbatch
2.407%saving andloadshare3.193% arecarry-only;loadshareisnotstartupfraction.

EightLIVErecords1168->1176. LogUp-GKR/Libra/Logup*refresh;DeepProve
lookupdocs/release/license;Oct26zkDuel;newolderfinite-differenceassessment
viaNISTDLMF(siteversion1.2.8Sep15,2026,notchapterrevision). PDF403/raw/commit
Cachemisses recorded; no inspected externalcommit or foreign execution.
Onlyresearchoutside runtimewritten;no production/Git/receipts/calibration/
gates/instructions/reviewer/build/GPU/install/externalwrite/message/purchase/
escalation/merge/restart/liveness action. Main/Claude reviews and integrates.

[Experiment](experiments/streamed-logup-root-blinding-20261030/README.md) ·
[Handoff](handoffs/20261030-streamed-logup-root-blinding.md) ·
[Dated report](progress/20261030T214123Z-4c34fc82.md).
