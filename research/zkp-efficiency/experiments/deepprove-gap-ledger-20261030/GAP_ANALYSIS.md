# Gap decomposition under the decided privacy requirement

2026-10-30; cycle 0172. The coordinator's intended
`results/zk60_deepprove_gap_20261030/GAP_ANALYSIS.md` was absent on inspection.
This local prerequisite study neither replaces that owner's work nor changes
the target. There is no reproduced 100-times gap on matched hardware,
workload, exact relation and privacy scope.

## What can be compared

The current project status cites approximately 452–456 s per T128
Shieldstral-3B category on eight CPU threads and an 848 MB receipt. The newer
R18 owner aggregate gives a three-category, one-load batch of 1,418.447 s
versus 1,453.434 s for three singles: 35.0 s, **2.407%**, observed saving.
Its common model/table load is 45.296 s (3.193% of batch time), not a complete
startup measurement. Each category still reloads blocks during sealing and
proving. The three reported proving clocks are 372.581, 373.025 and 365.671 s;
per-job totals are 460.905, 461.616 and 450.493 s. These nested clocks are
not independent additive phases. Source and aggregate hashes are retained;
none of the receipts was reverified here and none contributes new tokens.

[DeepProve's primary paper page](https://eprint.iacr.org/2026/1112) claims
174/86 tokens **per minute** for GPT-2/Gemma and 1,855 per minute distributed.
Those convert to 2.90/1.43/30.92 tokens/s, respectively. Its
[current README](https://github.com/Lagrange-Labs/deep-prove/blob/master/zkml/README.md)
instead lists CPU GPT-2 T512 at 1.12 tokens/s and Gemma T512 at 0.45, on a
24-core EPYC 9254 / 504 GB host. Different paper/README configurations are
not one baseline. The README derives its rate from `prove_full`; inference,
quantization and context generation appear separately. These author results
are not our total-workload or verified high-end-GPU measurements. The full
paper PDF returned HTTP 403, so its detailed privacy theorem was not inspected.

[Attestable's primary benchmark post](https://attestable.com/blog/proving-llms-scale)
claims 53 tokens/s at batch-one 16K or 77 across four 4K sequences on one
H100, with 4.35–7.92 MiB proofs and 157–648 ms verification across successful
configurations. It calls the results alpha and uses integer matrix products
with other nonlinear work in floating point. This is a competitor claim,
not reproduced evidence or an available algorithm. Publication/update date
is not exposed by the inspected page; copyright 2026 is not a publication
date. D51's closed-implementation distinction is retained.

## Ranked transferable techniques and attribution limits

| Priority | Technique | Current use and possible transfer under P1 | Added obligations / end-to-end limit |
|---|---|---|---|
| 1 architectural lead | Backward GKR chaining without committing ordinary intermediate activations | Native already uses specialized sumchecks, but A/H and boundary commitments remain. Eliminating deterministic intermediate commitments could remove recurring encodings, folds and PCS response vectors. | New relation/composition and hiding proof; keep nondeterministic lookup witnesses bound, private endpoints, original arithmetic/refusals, fresh masks and full accepted history. A/H critical phase share is unknown; no 100-times claim. |
| 2 immediate prerequisite, tested | Decompose PCS receipt bytes before selecting a replacement | Ligero-style openings send row-combination vectors, queried columns, salts and paths. This cycle falsifies paths as the large size source: only 1.61% of a current classifier receipt. | Vector-versus-column counts still needed from the actual accuracy layout; neither is removable from the current protocol. Byte counts are not phase times. |
| 3 owner priority | Whole-prover GPU residency and fused arithmetic/traffic | Native has CUDA NTT/commitments; whole private 8B high-end-GPU evidence is absent. | Hardware, host work, transfers, VRAM fit, all fresh randomness, serialization and drain must be measured together. No CPU-to-H100 ratio can be assigned. |
| 4 bounded, already implemented in part | Public preprocessing and one-load batches | Native R18 already shares one public load for three categories. | Owner observed 2.407% aggregate saving; it does not cache all recurrent layer work or private masks. Larger fixed-context independent passes are allowed and still need verified slopes. |
| 5 conditional | Decomposed lookups and fusion with requantization | Native already uses LogUp, U8 tables, domain batching and DD in selected profiles. | New decompositions must reproduce every exact integer result and refusal; challenge-dependent helpers and masks recur. DD admission and selected fidelity matter. Critical share unknown. |
| 6 partially present | Head batching and integer shifts / mixed precision | Native score/PV domains include the head axis, and existing quantized relations and R13/R14 precision work already address this family. | Count actual remaining launches/scans. Do not import approximate normalization or changed rounding under an old profile. No independent additional speed factor established. |
| 7 tested negative as primary explanation | Share Merkle path bytes within an opening | Synthetic codec restores original bytes with no cross-root dictionary. | Saves 0.736% of modeled full receipt; decoder adds work and native verification stays unchanged. No Rust port justified by the 50-token/s goal alone. |

The [author engineering explanation](https://lagrange.dev/engineering-updates/inside-deepprove-proving-an-llm-end-to-end)
supports the architectural lead: backward chaining avoids activation
commitments, while model and lookup witness commitments remain. Its
normalization and quantization choices cannot be presumed identical to our
integer relation. Our frozen stack already proves a complete causal window;
the article's avoided repeated generation passes cannot be credited again
as a saving against this baseline. Dense attention within the resulting
window can still scale quadratically.

Gap factors remain **unattributed** for hardware, IO hiding, commitment
creation, PCS/hash choice and nonlinearities until matched exclusive clocks
exist. Only the R18 batching observation and this source byte census have
numbers here. Do not multiply independently quoted speedups. D10's retained
PCS and D14's memo requirement are not changed by this study.

DeepProve's inspected root license grants limited evaluation/platform use
and restricts derivatives and redistribution; it is not presumed permissive.
Inspected licensing commit: `9d1a53e2ef49ffa2c902b8689cd3c58057a4e662`,
displayed May 26, 2026 in primary history. The current releases page lists
none. No foreign implementation was copied, installed or executed.

## Concrete next experiment

Pin the current native accuracy-layout constructors and build a public-role
inventory of every A/H plane and PCS group. Separate deterministic activation
planes from range witnesses, table multiplicities and challenge-dependent
helpers; count each terminal's downstream consumers and exact emitted vector
and column bytes. Differentially check the census against current typed
native inventory, with missing-host, reordered-group and lost-range controls.
This is the prerequisite for a narrowly versioned hidden-GKR prototype, not
permission to drop commitments from current receipts. Request owner exclusive
A/H encode/hash/open/slot/witness/serialization clocks under shared locks.

Recent [StateSync-GKR v2](https://arxiv.org/abs/2610.14849) (October 26)
reinforces separating reusable arithmetic from complete-result serving;
[zkDuel](https://arxiv.org/abs/2610.37710) (October 26) is a GPU kernel study,
not whole-proof throughput. Newly assessed older
[compact multiproofs](https://arxiv.org/abs/2002.07648) (February 2020) and
the [April 2026 draft arkworks PR](https://github.com/arkworks-rs/crypto-primitives/pull/173)
motivated the bounded size test; neither was executed or adopted.


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
