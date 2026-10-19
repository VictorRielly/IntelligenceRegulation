# ZKP efficiency explorer — durable state

Cycle 0077 COMPLETE: `20261019T091854Z-7d13829d`.
Checkpoint: 2026-10-19T09:32:22.029108+00:00. Next cycle no earlier than **2026-10-19 10:18:54 UTC**.
Dated report: progress/20261019T091854Z-7d13829d.md.
Prior complete state/findings/sources: experiments/dzc-pair-stream-20261019/startup/.

**No native proving speedup measured. Useful negative:** D pair streaming
preserves the cycle76 full polynomial and operation counts, but current
actual unpadded T128 catalogs gain only one word in complete logical lifetime:
130→129 Fp2 words (0.7692%), including endpoint pairs and round accumulator.
Scratch alone is79→18, denominators68→4. Retaining the entire common endpoint
bank gives202→141, a different scope. None is a physical-memory/register claim.
Generic padded194→131 does not apply to actual unpadded T128; odd unpadded
129→129 is another negative. Initial narrower audit preserved.

PASS30 synthetic fixtures, N2/8/32, seed2026101977:2,145 captured-Rust grid
and390 off-grid values,90 messages,1,845 original cube finals,30 final
relations,30 permutations/aliases,1,950 coefficients,390 equal operation
censuses/value-independent traces,7 controls. Independent246-check audit PASS,
using source/formula/interval/direct-live-set checks; six live pins unchanged.
Both actual T128 catalogs:35 A columns,34 lookups,17 helpers,59 tables,
4 limbs/32 bits, unpadded D. Every original fold/final remains; no full table
added or removed. Row331mul/72base/272add/150sub and prep0/30/76/54 unchanged
versus cycle76. Scheduling alone has no arithmetic-count saving.

Reference: captured complete Rust D/catalog with Shape/Layout and exactu128
field substitutes, independent Python clauses/direct cube; synthetic alpha/
g_u8. No native admission/actual-challenge/RNG/transcript/masks/PCS/proof/
serialization/fresh-verifier/privacy gate passed. Main6.348416s/RSS33,804KiB;
compiler132,128KiB; audit0.118293s/RSS19,352KiB. One nice19 CoreUltra9 185H
CPU0 thread, WSL2; each59s CPU/wall,512MiB address space. No GPU/heavy job.

Unapplied handoff: handoffs/20261019-dzc-pair-stream.md.
Interface: run.py::row(v,p,streamed=True), prior plan/convert; owner seam
SC_DZC / SumcheckRounds. Graph nodes are instrumentation. Pair port alone
is demoted. Native real shape/actual challenges, frozen bytes/RNG/refusals,
extension/mask/final openings, fresh verification and joint-view privacy
remain owed. No extra private claim or mask/opening reuse.

Ranked hypotheses:
1. OWNER whole-prover GPU D/A and real fixed-context resident-pass slopes:
   broadest measured recurring work, high integration cost. Charge complete
   construction/transfers/serialization/verification/drain and fresh masks.
   Reject enclosing loss, incorrectness or privacy failure. Owner F round4
   is19.4% isolated under a clock cap; not D/full-stack evidence.
2. NEW LOCAL next: construct endpoint pairs on first public scheduled use
   instead of materializing59 pairs up front. Medium adapter cost. Measure
   complete logical peak and every read/difference/alias/temporary/fold.
   Falsify no lower complete peak, uncharged recomputation, value-dependent
   dispatch, any sample/final mismatch or later native enclosing regression.
3. OWNER immutable public setup residency: possible setup amortization,
   no measured steady slope. Record context/pass count/concurrency; fresh
   witnesses/masks/openings per pass. Reject stale identity, backlog or no
   completed-proof slope improvement.
4. Pair streaming alone demoted; retain cycle76 arithmetic identity.
   Alternate lookup/GKR/PCS composition requires field/state/helper/joint-view
   and whole-run soundness review. Prior negatives remain preserved.

NEXT: lazy endpoint dependency/lifetime differential, actual catalogs,
permutations/aliases, full samples and original finals; census reads,
differences and original folds. Native fixed-array/byte/privacy/timing gates
follow only if useful. No native/GPU/heavy duplicates or thermal changes.
Rotation next: GPU NTT/commitments and batching/amortization; retain lookup/
softmax, arithmetic/quantization, sumcheck/GKR and composition queue.

8B affected D time/ceiling unknown. Deleting ALL D in the carried1.1B
174.052s diagnostic caps at1.18113×/0.868615 diagnostic positions/s;
not this schedule's prediction or an8B bound.

Carried8B R5b: T128,32 blocks,one cold CPU pass,16threads,GPUoff,shared n1.
App606.598/process606.728291s; diagnostic0.211013/0.210968positions/s.
Seal105.287s is17.357% phase, NOT startup; overlaps load36.570/witness103.349.
Prove501.126s includes witness rebuild122.694/reload21.176. Serialization
unisolated;922,711,264B receipt. Fresh verify14.126load+43.902check;
process186.088255 includes11controls. Startup/steady slope unknown.
No trained privacy/5090 acceptance. Latest1.1B next-token result is separate.
Owner round4 F CLI still owes its22-block stack gate.

Seven LIVE records appended,414total; prior407/findings remain prefixes.
NEW older Super-sumcheck source/NVIDIA2015 indexing guidance; current13.4
memory guide, Plonky3 October release, ICICLE version diff/MIT license,
hardware comparison and SumCATS refreshed. Only abbreviated6c77775 version
bump diff newly inspected; unavailable commits/yearless releases not pins.
Exact URLs/dates/licenses/access blockers in source-records.json. No external
performance/security claim reproduced or external source code executed.

New accepted target proofs/passes/positions0/0/0; device none. Target steady/
total rates, startup fraction, witness/proof/serialization/verification clocks
unmeasured. No long-context prefill/resident series/decode. Larger workloads
allowed; attention can grow quadratically with context. No mask/opening reuse
or weaker privacy. Complete private8B ≥50 proved tokens/s on5090/named high-end
GPU unchanged and unachieved. All work is research-only; runtime/production/
Git/receipts/calibration/safety/instructions/reviewer files untouched.
Final integrity check PASS: prior407 source records/findings remain prefixes,
414 total records parse, all six live native pins match, reports/links and
resource/deadline checks pass. Artifact manifest saved in the experiment. Saved reports do not establish delivery.
