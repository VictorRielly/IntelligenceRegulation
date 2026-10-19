# ZKP efficiency explorer — durable state

Cycle 0078 COMPLETE: `20261019T101854Z-3562a78f`.
Checkpoint: 2026-10-19T10:30:14.536829+00:00. Next cycle no earlier than **2026-10-19 11:18:54 UTC**.
[Dated report](progress/20261019T101854Z-3562a78f.md).
Prior state/findings/sources preserved in experiments/dzc-lazy-endpoints-20261019/startup/.

**No native speedup measured.** Lazy first-use D endpoints lower complete
logical peak129→77 Fp2 words (40.31%,832 logical bytes per active worker),
including endpoint construction temporary and five-word round accumulator.
All input/derived buffers expire at last use in the model. No physical
memory/register claim: Python retains graph/cache values; a native adapter
must realize static local lifetimes. No full table removed; all59 original
folds/finals remain. Keeping endpoints until end gives136 words; omitting
memoization increases reads118→198 and differences59→99. Prior cycle77's
130→129 pair-streaming negative remains valid.

PASS30 synthetic fixtures,N2/8/32,seed2026101978:1,950 lazy coefficients,
2,145 captured-Rust grid/390 off-grid values,90 messages,1,845 original
finals,30 final relations,30 permutations/aliases,390 charged endpoint
censuses/value-independent traces,eight controls. Independent221-check audit
passes using DAG hashes, intervals/direct live sets, original contracts and
six unchanged live source pins. Captured full Rust expression/catalog with
exact u128 field and Shape/Layout substitutes; independent Python clauses/
direct cube agree. Actual profile admission/challenges/transcript/RNG/masks/
PCS/proof/privacy gates owed. Both current T128 catalogs:35 A columns,
34 lookups,17 helpers,59 tables,four limbs/32bits,unpadded D.

Coefficient add/sub/mul/base272/150/331/72 unchanged;118 endpoint reads /
59 differences. Original folds separately118 reads/59writes,59 each add/sub/mul.
Combined331/268/390/72 excludes common round reduction/conversion/plan.
Main8.612566s/RSS47,748KiB; compiler138,144KiB; audit0.260665s/RSS24,352KiB.
One nice19 Core Ultra9 185H CPU0 thread,WSL2,each59s CPU/wall/512MiBAS.
Initial audit caught saved-metadata shadowing; fixed/rerun, failure retained.

Unapplied handoff: handoffs/20261019-dzc-lazy-endpoints.md.
Interface run.py::lazy_row(raw,p), prior plan/reduce/convert; owner seam
SC_DZC / SumcheckRounds. No extra private claim/opening,mask reuse,degree/
refusal/privacy change. Owner owes real challenges/profile,seeded bytes/RNG/
refusals,extension/mask/PCS/final-opening order,fresh verify/tamper/joint-view
privacy and enclosing timing. Actual8B D time/ceiling unknown. Deleting ALL D
in carried1.1B diagnostic caps1.18113×/0.868615 diagnostic positions/s;
not a candidate prediction or8B bound.

Ranked hypotheses:
1. OWNER whole-prover GPU D/A and completed resident-pass slopes: broadest
   recurring scope/high cost. Charge construction/transfers/serialization/
   fresh verify/drain and fresh masks; reject enclosing loss or privacy failure.
2. NEW LOCAL next: interleave affine contributions with each endpoint's first
   helper/bilinear/host use; combine aliased weights exactly once. Baseline77
   words,54 endpoint words at peak. Moderate cost; charge all accumulators/
   reads/differences. Falsify duplicate/missing terms,extra uncharged work,
   secret dispatch,any sample/final mismatch,no lower complete peak or native loss.
3. OWNER immutable public setup residency: possible amortization,steady slope
   unknown. Track context/passes/concurrency/drain with fresh witnesses/masks/
   openings per pass. Reject stale identity/backlog/no completed-proof slope gain.
4. OWNER D30 dictionary/lookup-GKR composition: counted geometry opportunity,
   separate unbuilt profile/soundness/privacy gates,high cost; not current59-table D.

NEXT: public use-driven affine/helper accumulation differential,all aliases/
host/padding/odd-helper/original folds/finals. No duplicate heavy/GPU job.
Rotation next: lookup/softmax and arithmetic/quantization; retain GPU NTT/
commitments,sumcheck/GKR,memory traffic,batching/amortization,composition queue.

Latest carried8B diagnostic: T32,32 blocks,one CPU next-token pass,GPUoff,
shared n1; testtotal230.5s/guardchild230.645478s; prove191.7 includes witness17.3/
load14.3; digest18.4/tables1.8. Fresh verify43.4 includes load14.0; digest17.7/
tables1.6; verifier guardchild81.314998 includes other checks. Receipt471,285,072B.
Serialization/startup fraction/steady slope unisolated; Rayon threads unknown.
Diagnostic prompt positions0.138829/s differs from one next output/230.5;
neither is target acceptance/decode. Review/privacy pending. Earlier R5b T128
606.598s clocks retained separately in target-accounting.json. Current speed
plan now records GPU F round4 full22-block stack gate DONE; supersedes prior
pending statement. Its isolated19.4% capped bandwidth is not D/full-stack timing.

Eight LIVE records appended414→422. New Oct16 Chimera/Sluice revisions
(abstracts;PDF403),older1999/2020 allocation papers,recmo Goldilocks wrapper/
actual MIT file; Plonky3 October release,yrrid cache,zorch shape refreshed.
Exact dates/license/commit scope/access failures in source-records.json.
No new inspected commit; yearless releases/exposed fe5e46d are not pins.
No external code executed or benchmark reproduced.

New target full-stack proofs/passes/positions0/0/0,device none. Target steady/
total rates,startup fraction,witness/proof/serialization/verification clocks
unmeasured. No prefill,resident series or decode. Larger workloads allowed;
context may increase attention quadratically. No mask/opening reuse or weaker
privacy. Complete private8B >=50 proved tokens/s on5090/named high-end GPU
unchanged/unachieved. Only research files changed; runtime/production/Git/
receipts/calibration/safety/instructions/reviewer files untouched.
Saved reports do not establish delivery.

Final integrity check PASS at 2026-10-19T10:30:57.200386+00:00: 31 checks; prior source/findings
prefixes preserved, 422 records parse, six live native pins unchanged, test
limits and deadline met. Artifact manifest saved in the experiment.
