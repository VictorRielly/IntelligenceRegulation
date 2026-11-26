# First decoder layer arithmetic and rejection sites

A single-core integer replay reproduced all 72 first-layer arrays for each of the black, white and coordinates fixtures. Across the three synthetic inputs, the 122,202,648 signed 64-bit values matched their archived SHA-256 digests. Peak process RSS was 316.4 MiB. [Arithmetic result](RESULT.json)

The replay reads the authenticated model and initial residual for each case. It computes both normalization steps, all seven trained matrix products, rotary embeddings, attention scores, causal softmax, attention/value products, grouped SiLU lookups, both residual additions and the output. The seven matrix products per case cover 52,027,195,392 multiply-accumulates in total. The reference file contributes expected digests only. Proof generation, committed-witness comparison and verification of the saved proof bytes require the separate native suite. [Reproduction script](check.py)

## Checkpoint and calibration

Rebuilding the first layer from the pinned 7,698,241,104-byte Shieldstral BF16 checkpoint and the archived calibration scales reproduced all 116,391,936 integer weights in the seven matrices. Every weight matched both the exported array and the decoder fixture in its specified orientation. All 30,720 per-output multipliers and shifts matched. The replay folds the checkpoint normalization weights into the consumer projections and applies the registered three-block Hadamard rotation before quantization. [Parameter result](PARAMETER_REVIEW.json)

The calibrated scales also reproduced 6,144 integer normalization parameters. All 19,072 rotary coefficients, 256 exponential lookup entries and 12,288 grouped SiLU entries matched formula evaluations. The 9,216 SiLU group assignments came from the authenticated export. Re-estimating those assignments or the original scales from the calibration corpus is outside this check. [Parameter derivation](parameters.py)

## Historical verifier observations

The frozen first attempt expected the query matrix control to fail at private slot 5. Its verifier reported slot 15 and the test exited 101. A later attempt changed the expected slots to the zero-checks that host the private claims. The native host mapping was byte-identical in both revisions. The final black-case log records the following outcomes. [Source and log audit](SLOT_REVIEW.json)

| Control | Private slot | Verifier reported |
| --- | ---: | --- |
| Query matrix, attention/value product | 5, 9 | 15, query zero-check |
| Key matrix, value matrix | 6, 7 | 16, key/value zero-check |
| Attention output, feed-forward down projection | 10, 13 | 14, residual-width zero-check |
| Feed-forward gate, feed-forward up projection | 11, 12 | 18, feed-forward zero-check |
| Attention score | 8 | 17, softmax zero-check |

Each reported index identifies a host with multiple relations. The error alone cannot establish which member caused the failure. Both normalization carry controls reported helper opening group 8. The source appends the global LogUp sum claim last and declares nine helper opening groups for this profile. The observed group is consistent with that schedule. The earlier run retained logs only, so the historical evidence supports a source-and-log comparison. [Audit script](slots.py)

