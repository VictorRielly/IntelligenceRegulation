# Review handoff — public BLAKE3 lazy frontier —2026-10-21

Candidate only; no native code modified or performance claimed.

Interface: activeGPU `Gpu::commit_zk_chunked`, `commit_chunked`, `commit_chunked_upload`
and **both** `k_hash_cols_stream` / `k_hash_cols_stream_keyed`. Rootlegacy has only
unkeyed. Source pins in [manifest](../experiments/commitment-public-frontier-20261021/source-manifest.json).
Alternative patches: [active](../experiments/commitment-public-frontier-20261021/active-count-free.patch)
or [legacy](../experiments/commitment-public-frontier-20261021/legacy-count-free.patch).
Uncompiled/unapplied; use only matching tree, inspect currentpins first.

Derive length at public chunkc0=row0/128:0 ifzero, else popcount(c0−1)+1. This follows
existing lazy push; eagerpopcount(c0) is WRONG. Remove count load/store,193->192u32
percolumn and three whole-state clears. Retain24CVlevels,all compression/store order,
key flags/words,active keyed64-thread grid and every original key/mask/salt/draw.
Dynamicdepth is model-only, absent frompatch. Earlier first-launch patch remains
a narrower alternative; no native decision made here.

Hash model: **1,528 checks, 30 unkeyed + 19 keyed shapes, 109 restarts,
26 control types PASS**. Independent labelled-interval/source/cost audit: **1,835,886
checks, 262,144 prefixes, 64 large boundaries, nine source pins PASS**. Both models were
authored by this researcher; the cryptographic reference is independently implemented in
installed blake31.0.9. Diagnostic wall/RSS: 8.168926s/23,628KiB
and 2.392768s/16,592KiB. Every leaf: one-core affinity,nice19,
30s CPU/alarm,35s parent timeout,256MiB AS,64MiB estimate. No native build/GPU/proof ran.

1,528 model checks include safe starts after109synthetic failure/poison
cases,freshkeys/endian/root/counter/count controls. Safe prior retirement is assumed;
not CUDA failure/fence evidence. Corrected flag model mistake and original failed
logs retained; wrongflag64 control now fires. Models authored by same researcher;
independent implementation is installed blake3, not another agent review.

T128/T512 extra requested saving0.25/0.5MiB perA/H vs prior same-depth candidate.
Originalcount traffic13.25/14.75MiB forT128nonDD A/H;71.5/86.5MiB T512. Adds
1.70/1.90M or9.31/11.27M source-level popcount evaluations. Logical traffic can be
cached; no DRAM or elapsed guarantee. Poolretention can save zero physicalmemory.
Fullclear removal already existed in priorcandidate: no double counting.

Owner gates: poisoned nativehashes both kernels/allthree hosts,1/2/3/manychunks and
tails; current public profile keys, saltedleaves/Merkleroots/paths, complete receipt
parity+freshprocess independentverify; transcript/mask/RNG/privacy/refusal gates.
Check resident/off/fallback/nonZK paths,allocation/launch/download failures,integer
bounds and partialfailedkernels with proven safe retirement before buffer reuse.
Removingmemset removes thatAPI's failurepoint; never claim identical infrastructure
failurebehavior. No source bug or nativeUAF claimed by CPUrestart model.

Measure actualchunk incidence, pooledcapacity, exclusive clear/count criticalpath,
registers and enclosing completeGPU verifiedresident1/2/4/8 under sharedheavy/build
locks. Unknown removablefractionf gives ceiling1/(1−f) beforeaddedcosts. Reject any
hash/trace/key/refusal/receipt/privacy mismatch or slower enclosing workload; park
if nativecost immaterial. No private8B/high-endGPU acceptance inferred.

Next local: pin active tagged PCS/Merkle sources, separately count salted-leaf and
internal-node compressions, all required retained paths, transfers and recomputation for
one complete commitment. Differential-test keyed roots/all paths before any scheduling
proposal; stop counter micro-optimization until owner supplies exposed native clocks.
Owner next: native poisoned-buffer/hash/receipt/privacy gates, actual clear/counter/capacity
clocks and complete verified fixed-context resident1/2/4/8 sweep under shared heavy/build locks.
This handoff is saved locally, not an external message.
