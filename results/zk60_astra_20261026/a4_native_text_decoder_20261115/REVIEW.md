# First-layer numerical qualification review

All three actual trained-width cases passed in original session 30254, exit
zero. The audit authenticates source, binaries, external fixtures, complete
plane comparisons, final outputs and exact control coverage. Native numerical
source and field arithmetic remain byte-identical to the earlier preflight.

The relation checker is separate code by the implementing agent. It validates
shape before indexing and integer domains before equations, uses field
identities for roots/gaps, quotients/complements, literal tables and residuals,
and directly recomputes every matrix, QK and PV definition. The largest
possible bounded equation difference stays below the Goldilocks modulus;
signed I24 times a 40-bit denominator is evaluated in the field to avoid i64
overflow. A dedicated test rejects that extreme false quotient.

Every one of 72 planes has first/middle/last point and truncation controls.
Nine compensated accumulator/remainder/complement changes demonstrate that
passing local rounding is insufficient: all fail their intended definition.
Used model weight/gamma/RoPE/exp/SiLU changes are checked separately from
invalid metadata classes. Final full reference comparison follows restoration
of all mutations. These controls concern the numerical oracle, not serialized
proof receipts or a malicious cryptographic prover.

The original reference exporter preserves the original Mat arithmetic and
column blocking while skipping optional retained FFN caches. Its first attempt
finished reference computation but failed while pinning unused base-directory
weights; the failure and source are preserved. The corrected attempt pins the
actual native weights and relevant base tables and completed successfully.

This is a first-layer development result on three synthetic canvas prompts,
with shared-host timings. It does not establish task quality, all-26-layer
decoding, committed decoder soundness, privacy, Lean production acceptance or
profile adoption. An independent review is still required for those claims.
