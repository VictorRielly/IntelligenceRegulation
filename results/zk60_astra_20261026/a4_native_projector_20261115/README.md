# Native encoder-to-projector numerical qualification

Completed validation is recorded in RESULT.json. An absent or unsuccessful
result does not qualify this candidate.

The native program carries its own computed activations through all 24
encoder layers and then the fixed N16 projector. It compares every retained
reference plane on black, white and coordinate canvases. No native state is
replaced by a reference output between layers or before the projector.

The projector implements full signed-I16 normalization, channel-major 2x2
patch merging, the 4096-to-1024 merge matrix, the 1024-to-3072 first linear
matrix, literal GELU lookup, and the 3072-to-3072 final matrix. The signed-I16
normalization domain includes -32768. Half-up requantization uses Euclidean
division and supports zero shifts. The unchanged original parameter archive
and four previously qualified N16 scalar changes are authenticated by hash;
there is no recalibration, clamping or fallback precision.

Each projector case has 21 planes with 3,081,216 values, including 196,608
output values. The native checker validates the local field relations,
ranges and every matrix product. Each case also runs 77 alteration controls:
three positions in every plane, three input positions, all three shifts,
normalization coefficient/epsilon/gain/shift, all three weight matrices and
one used literal GELU entry. These are deterministic numerical/relation
checks, not serialized proof forgeries.

The encoder prefix and model readers in `check.rs` are byte-identical to the
qualified native chain except for the added projector module/reader and
post-encoder stage. `attention.rs`, `tail.rs` and `field.rs` are unchanged
copies. The audit checks these equalities and every reference-plane digest
against the previous all24 qualification. All tensor/model arrays pass
through pipes or remain in existing external sources; none are archived in
this package. The executable is in external scratch and authenticated by
the result manifest.

Validation runs single-threaded in the sandbox; measured combined parent and
child RSS upper bounds and shared-host functional durations are retained.
The checks overlapped the coordinator's A32 benchmark. They are not timing
benchmarks or evidence of a quiescent host.

The encoder output unit is exactly 0.5, matching the projector input. The
projector output unit is approximately 0.00009789336234713772 and is not a
power of two. Its exact metadata must remain bound when composing the later
signed-Hadamard/Q24 scale and image-token splice relation. A raw-integer
endpoint must not be mislabeled with an approximate binary scale.

Remaining work: committed projector and adapter/splice proofs, the complete
image-to-text proof, actual image-task quality, independent composed
soundness/privacy review, formal production obligations and adoption.
This package establishes numerical agreement on three synthetic canvases;
it is not a native proof, privacy result, production profile or accuracy test.
