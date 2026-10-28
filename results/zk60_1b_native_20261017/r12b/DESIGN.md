# R12b implementation and verification

Resume priority: S1b / R12-F1, F2, F3, N-7 from the independent R12 review.
R12 remains frozen; R13 remains isolated until rebased onto R12b.

The native tied-table reader will authenticate the Shieldstral safetensors
file against the model pin, check BF16 tensor shapes, and stream the tied
tensor while recomputing integer-table digests. Memory stays bounded to one
row plus the bounded header, rotation signs, final norm, and row scales.
The classifier API also derives the difference row from the same tensor.

Exact arithmetic matches Astra's existing candidate writer:

- Widen BF16 exactly, use binary64 for the signed block Hadamard transform
  (three blocks of 1024, each divided by 32).
- Embedding: cast the rotated row to binary32, widen to binary64, divide by
  the profile's first residual scale, floor(x + 0.5), reject outside int16.
- Head: multiply the BF16 row by the checkpoint's BF16 final-norm weights
  before rotation, use max(abs(row))/127 per row, floor(x/scale + 0.5).
  All-zero head rows stay zero. Multipliers are max(1,
  floor(4096*row_scale/max_scale + 0.5)), as signed int64.
- Classifier: subtract the BF16 yes/no rows in binary64, multiply by final
  norm, rotate, divide by the public scale, floor(x/scale + 0.5), reject
  outside [-32767,32767]. No difference of separately rounded head rows.
  No saturation, second SiLU rounding, or change to block relations.

Public token calibration authority will be `profile.json.token_io_parameters`:
`bos` (the pinned model's 1), `classifier_final_norm` and `head_final_norm`,
each with g0/cn/tn/ceps. The public API returns these values rather than
accepting the classifier manifest's copies as authority. Embedding scale
and rotation come from the profile's existing metadata. The explicit
checkpoint override is `tied_embeddings.checkpoint_file`; absence uses the
existing pinned local snapshot. Every path is still authenticated.

Required gates: bounded/special-file controls; independent scalar and rotated
quantization vectors; honest full pinned tensor versus independent Python;
doctored tables with updated manifests; shape/dtype/source refusals; pinned
RoPE override refusal; R12 geometry and dense proofs; R9 proof/statement byte
goldens; retained R8/R9 verifies; full native suite and frozen tree + patch +
source/evidence manifests. R12b is then delivered for independent fix review,
without claiming that the review or classifier privacy acceptance happened.
