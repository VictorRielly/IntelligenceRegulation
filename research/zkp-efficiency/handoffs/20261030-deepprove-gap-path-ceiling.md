# Review handoff: prioritize PCS vectors, demote path-only compression

Run `20261030T204123Z-0f14d260`, cycle0172. Main/Claude owns review and
integration. No production change, native build, proof, GPU invocation or
merge occurred. There is no Rust patch to integrate.

The source-derived frozen-R18 classifier census prices every authentication
path at **13,656,064 B / 848,412,096 B = 1.6096%**. A synthetic root-local
path dictionary projects a **0.7360%** whole-receipt saving. This is a useful
negative: path deduplication cannot explain the large proof-size gap to
DeepProve/Attestable. It is not a wall-time bound on other PCS computations.

Candidate interface in
[codec.py](../experiments/deepprove-gap-ledger-20261030/codec.py):
`encode(ordered_indices, paths, trusted_checks, trusted_depth) -> bytes`;
`decode` restores every original path in the same order. Each dictionary
belongs to one commitment opening only. Native repeated queries remain
repeated. No column value, salt, vector, query draw or mask is removed.
The seam would be `OpeningZk::write_bytes`, `MaskOpening::write_bytes`,
`private_block/wire.rs` and `private_block/token_io.rs`, as an outer
transport wrapper before the original bounded decoder and verifier.

Validation: 50 synthetic full-record round trips, 12,800 independent
synthetic root checks, ten negative controls; independently authored local
audit passes 7,291 checks and 28 stream comparisons. SHA256 is a synthetic
tree oracle; no native BLAKE3/PCS/privacy verification is claimed. Main
0.469 s / 40,844 KiB, audit0.217 s /29,368 KiB, one low-priority CPU.

Unresolved if ever promoted: native full-frame identity; exact fresh-process
verification; malformed-frame acceptance/bounds; all keyed roles and paths;
wrapper versioning/integrity; Rust allocation/copy/decoder costs and exclusive
serialization clocks. Decoder expansion adds work. The original verifier
still hashes every path. Do not prioritize this Rust port for 50-token/s.

More useful next handoff: a source-pinned A/H plane and PCS-group census of
the actual accuracy layout. Identify which deterministic intermediate
commitments could be replaced by backward claim chaining and which lookup,
range or nondeterministic witnesses still need commitments. Keep P1 hiding,
all original refusals and bindings, D8/D11 history and D12 composition
explicit. Do not remove any current commitment based on a public-IO analogy.
Then cost the removed A/H encode/open vectors against exclusive owner clocks.

[Experiment](../experiments/deepprove-gap-ledger-20261030/README.md) ·
[Gap analysis](../experiments/deepprove-gap-ledger-20261030/GAP_ANALYSIS.md) ·
[Source pins](../experiments/deepprove-gap-ledger-20261030/source-pins.json).


## Closing update: coordinator study and D53 received

The coordinator study landed during closing and was read with its handoff,
arithmetic output and GPU-lane ledger; copies and hashes are in
`late-owner/` and `late-owner-pins.json`. D52 concerns a separate synthetic
privacy challenge. D53 holds publication until GPU proving and verification
exist; the GPU-classifier lane is now owned by Claude. Neither adds research
GPU authority, changes privacy or establishes GPU performance. No owner job
was duplicated or restarted.

This supersedes the initial next-action order: **masked streaming LogUp-GKR
against committed H helpers comes before the derived-linear-plane census**.
The coordinator cites older TinyLlama T128 measured phase rows: H commit +
inverses + open =30.03s/152.2s (19.7%); selected hiding-related rows
18.39s/152.2s (12.1%). Those are historical phase attribution, not a matched
causal P1/public-IO A/B or current Shieldstral/8B-GPU measurement. Its
1.37–1.57 roofline factor for masked LogUp-GKR and 40–50% receipt reduction
are models with unmeasured added GKR/privacy cost. We do not promote them to
observed improvements. MAC/s normalization is a useful workload proxy; it
does not normalize lookup, precision, proof, privacy or witness work.
Multiplying a legacy public-FFN CPU/GPU ratio by bandwidth ratios also
remains an inference, not a measured attribution of all cross-system gaps.

Next bounded local experiment: a streamed Fp2 byte-fraction-tree and fresh
alpha-dependent pair-table oracle, with independent leaf/root/ordered-link
equations and controls for missing leaves, zero denominators anywhere in
the declared public table, changed multiplicities, root disclosure and
binding. Start at2^10..2^16 synthetic lookups and stream larger counts only
if the strict resource estimate permits. Count every layer's arithmetic,
bytes and live buffers. The65536entry pair table must be rebuilt after
each fresh alpha; only its public index plan is reusable. Keep roots and
all intermediate claims private until a reviewed masking construction and
joint-view simulator exist. Two cancelling leaves do not by themselves
prove uniformity or privacy: specify their distribution and check it,
including zero/refusal cases. This arithmetic oracle is not called a GKR
proof. Native masked proof verification remains a separate gate.

The coordinator's handoff suggests up to1GiB and2^20/2^22/2^24 lookups. The
active user limits are stricter: **one thread, at most60s and512MiB**; no
dependency install/build/GPU. Larger native throughput measurements are
proposals for the owner/shared locks, not jobs launched here. A Python
one-thread diagnostic cannot be compared directly with its54ns/lookup
sixteen-thread cost law. The proposed kill condition (CPU cost>=0.7of the
helper baseline AND bytes>=baseline) needs matched implementations and
all masking/setup/binding costs. The170B/lookup GPU traffic baseline is a
model, not current device telemetry. Derived-linear and wider-limb censuses
remain companions, and all previous fraction-tree privacy/capacity negatives
remain binding research evidence.
