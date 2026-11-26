# Native image-to-text-input numerical qualification

Completed validation is recorded in RESULT.json. Without a passing result,
this is an unqualified development candidate.

The native program carries its own output through all 24 encoder layers,
the unchanged N16 projector, the image adapter and the complete prompt
splice. No reference output replaces a native activation between stages.
The 149 real prompt tokens, 64 image positions, seven image-break tokens and
one image-end token are preserved. No prompt is truncated to T128. The
retained public token tables come from the older T128 export; using their
constants here does not qualify that installed profile for these prompts.

The adapter uses three independent signed H1024 transforms. It derives the
Q24 coefficient from the exact rational values of the two encoded binary64
units, using checked integer arithmetic. The trained coefficient is 14463.
Requantization uses Euclidean division and half-up rounding, with full I16
input/output ranges and 24-bit remainder/complement ranges. Public rows are
looked up from the authenticated embedding table; the image rows replace
only the canonical image-token positions.

The forward transform uses butterflies. The checker independently checks
every transform output with H[i,j] = (-1)^popcount(i & j), then checks the
field quotient/range relations and every public/image splice coordinate.
Each case compares five planes and 1,244,160 values, including all 457,728
spliced output values. Forty-one adapter controls per case cover every plane,
input changes, wrong signs and coefficients, coherent alternate witnesses,
compensated remainders/rotations, public-row substitution, marker layout,
coordinate order, geometry and range failures. These are deterministic
numerical/relation checks, not serialized proof forgeries.

The three cases are black, white and coordinates. Coordinates deliberately
uses the pinned black-case prompt as a numerical fixture. This is not a
labelled task-quality comparison. The audit requires every encoder and
projector reference-plane digest to equal the frozen prior qualification,
and the prior native kernels/prefix to remain byte-identical. The earlier
77 projector controls also run on each composed path.

No model or tensor arrays are newly archived here. Reference values pass
through bounded pipes; retained artifacts contain source hashes, output
digests, logs and summaries. Executables remain in external scratch.
Single-threaded timings are shared-host functional diagnostics.

Remaining work includes committed projector and adapter/splice proofs,
the complete image-to-text proof with T256 capability, native text-decoder
integration, actual image-task quality, independent composed soundness/privacy
review, formal production obligations and adoption. This package does not
prove privacy, production readiness, installed T128 acceptance, classifier
accuracy or a complete pixel-to-verdict pipeline.
