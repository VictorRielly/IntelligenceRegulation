# Canonical TN readers and bounded digest transpose

Cycle 0026, `20261004T080146Z-55b15f9d`, checkpoint 2026-10-04T08:16:05.805687+00:00. **No proving improvement was measured.** A locally authored storage/arithmetic oracle passes 324 synthetic cases, 3888 fresh Fp2 fold comparisons (40824 output words), 10206 raw witness dots, 1157652 canonical FFN bytes, 315 support refusals, 576 line-accounting checks and 26 controls. 0.460062s / 17392 KiB RSS on one pinned nice10 Intel Core Ultra 9 185H CPU thread, seed2026100426. 59s CPU/alarm and512MiB address-space caps;64MiB estimate. No native build, GPU or proof ran.

## Question and conditional baseline

Can one immutable TN weight store serve the current integer witness, public column folds and canonical statement digest, allowing a future integer adapter to avoid retaining both weight orientations? Native code currently owns only original input/output weights; it has no TN integer adapter or duplicated cache to remove. The conditional baseline from cycle0025 is original W plus a TN packing/cache with column sums. A one-layer LRU still misses across the separated all-layer sealing/proving scans; that negative is unchanged.

The native down seam is `ops/zkp-mvp/candidate/hashline/src/private_block/witness.rs:312,685`. The three FFN folds are at `private_block/argument.rs:1424-1432`, with canonical `zkp-core/src/mle.rs:48,141`: challenges use MSB equality order and signed i8 conversion. `private_block.rs:552,575,614` validates entrywise padded support and hashes gamma/Wg/Wu/Wd in canonical input/output row order, u64 little-endian lengths, followed by256 little-endian i16 activation entries. The digest is BLAKE3 under the existing domain. Source pins/snapshots retained; no native code was edited.

## Independent evidence

Reference uses explicit bit products over Goldilocks Fp2 (u²=7), original signed rows and direct logical i64 dots. Candidate uses a separately constructed native-order equality table and reads physical TN columns, accumulating two base components. Every challenge-dependent fold is recomputed. Test geometry: padded rows/columns1/2/4/8/16/32, stride extra0/1/5, zero/extrema/random signed bytes, extension/base/Boolean challenges, fold blocks1x1/3x3/8x5/64x64. Full and ragged blocks, dirty ignored stride guards, zero artificial aligned tails, canonical internal padding, inclusive int16 input extrema, three true token rows plus dirty token padding and distinct input/output strides are checked. Arbitrary helper geometries are synthetic, not admitted new profiles.

Canonical digest reader fills a bounded row block by reading contiguous slices of each TN output column, then emits row-major bytes. Reference packs original signed bytes and u64/i16 framing independently using struct.pack. Complete FFN absorb bytes match at row blocks1/3/8/64, including activation extrema. SHA256 streaming diagnostics agree, but **native BLAKE3, full attention+FFN public statement, transcript, RNG, PCS and receipts were not executed**. Identical preimage bytes are a prerequisite for unchanged native digests, not a recorded native gate.

Admission independently audits shape/orientation, entrywise P-2 support, artificial alignment tails, model/layer/tensor/profile/calibration metadata and canonical content digest. Python frozen bytes model immutable ownership only; persisted caches need validation against an authenticated expected model identity. Rust owner/clone/lifetime enforcement is unresolved. Guards after aligned K are ignored; synthetic dirty aligned GEMM tails are refused. A padded row can fold to zero at one challenge while still failing entrywise support; the explicit cancellation control rejects that shortcut. Controls also catch TN-as-row-major, physical hashing/length, unsigned field conversion, MSB reversal, discarded extension components, stale challenge folds, changed bytes/metadata, stride/length/orientation faults and act endianness. Initial fold/digest-only pass retained before witness/admission refinement.

## Counted capacity and traffic limits

Unadmitted Llama3-8B metadata:32layers,Kpad16384,N4096. No large matrix was allocated. Conditional original+packed down retains4GiB of byte payload plus0.5MiB column sums. Migrating **all** original consumers to one TN owner could remove2GiB duplicate bytes while retaining2GiB TN bytes and0.5MiB sums. This is not a reduction established in current native memory, not a whole-model peak, and not an admission of this profile. Import/clone mirrors, other tensors, packing X, algorithm workspace, proof planes and transfer/synchronization lifetimes are omitted.

Native `absorb_into` currently collects a byte-cast Vec the size of each tensor. For one64MiB down matrix, a Rust synchronous64-row reader needs256KiB scratch instead of that64MiB temporary. Python creates an immutable copy, so its counted scratch+chunk peak is512KiB. Other tensors must be streamed too; reducing one temporary is not the same as removing a retained weight copy, and those savings must not be added without a lifetime audit. The byte-cast allocation can separately be bounded while keeping the current original weight store, without any TN adapter.

|Digest row block|Rust modeled scratch|All32layer64-byte source-line episodes|
|---|---:|---:|
|1|4KiB|2,147,483,648|
|16|64KiB|134,217,728|
|64|256KiB|33,554,432|
|128|512KiB|33,554,432|
|256|1MiB|33,554,432|

Episodes model union of source lines within each row block and **cache reset between blocks**. A separate address-enumeration oracle agrees with interval-union counting in576 small ragged/odd-stride cases. These are not measured DRAM bytes:1row's4096lines require256KiB and may remain cached. Thus the apparent64x episode difference is not a64x speed/traffic claim. Bounded transpose adds scatter writes, scratch management and more hasher updates. Folding adds tiled output accumulators and strided output writes; no field products, witness MACs or proof operations are removed.

## End-to-end gate and next action

Removed conditional work: duplicate W retention, full cast-vector allocation and, only with valid residency, repacking/reuploading. Added costs: trusted import/canonical identity scan, ownership migration, digest block transpose/scatter/hasher calls, fresh fold scheduling and workspace/residency/transfer costs. Complete-proof ceiling is N/(Tbaseline-Cremoved+Cadded); native down/preparation/digest clocks and actual peak memory are missing, so no numerical trained8B ceiling or speed estimate is justified. Parent softmax/witness timings stay the highest impact owner work; this is a memory prerequisite, not a replacement for it.

Falsify any logical value, padding/support/refusal, canonical framing/model identity or native masked challenge/RNG/transcript/receipt mismatch; any privacy/domain weakening, peak memory not falling, or enclosing added time>=removed time. P1 public preprocessing never caches challenge-dependent folds or fresh masks. P3 weights/cache/sums/digests stay private under its reviewed protocol, not this public cache interface. No opening/blinding reuse.

Owner integration gate: migrate constructors/importers, all production witness and verifier readers, proof folds and digest before dropping original storage. Run native differential/frozen-byte/RNG gates and separately measured witness/down/preprocess/digest/transfer/peak clocks under shared locks; then supported device parity and independently verified complete-stack A/B. No build or GPU job was queued here. Local next: full attention+FFN canonical preimage and immutable-digest ownership/repeated-call audit at BlockPublic::digest, RunStatement::new and model_root_of, including mutation/clone/calibration/table/domain controls. Assess startup versus resident-pass scans; never memoize masked/proof-specific material.

LIVE primary sources and qualified failures are in source-records.json/search-log.md: cuda-zkp-ntt release/negative-result filter, older small-characteristic prover paper/repo, August2026 batch-polynomial compiler and packed-mask scope filter. No author performance was reproduced or foreign script executed. Rotation moves GPU NTT/commitments -> lookup/softmax -> sumcheck/GKR -> memory traffic -> batching/amortization -> quantization -> composition; do not repeat preserved incompatible/slower/small-parent negatives.

## Complete-proof accounting

This cycle: CPU only; accepted complete private8B passes0, countable tokens0, context null, passes0. Steady-state and total-workload rates, startup fraction, witness/proof/serialization/independent-verification clocks, latency/proof lag and drain are unmeasured. No long-context prefill, resident complete pass or decode proof. Larger workloads remain allowed; dense attention growsT² and decode requires authenticated state. >=50 proved tokens/s remains unachieved.

Historical n1 cold synthetic12-block125M/T512 diagnostic on RTX4070Laptop8188MiB remains408.609226s total,318.22s combined runprover,12.15s in-process verification and484,107,456B; independent verification false, no countable private8B tokens. Combined runprover includes witness/serialization; separate clocks/startup unknown. The later CLI report still has no terminal result after the recorded reboot; a stale running marker is not process-liveness or success evidence. No historical latency or rate was upgraded by this CPU oracle.
