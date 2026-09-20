# Exact integer row folds — integration, 2026-09-19

The shared int8/int32 row folds now accumulate bounded signed integer sums
and reduce once per output field component. The same-binary rollback is
`HL_FSP_ROW_FOLD=0`; the default is enabled. Source:
`zkp-core/src/mle.rs`. Protocol, field, transcript and output ordering stay fixed.

The accumulator bound uses the full unsigned 64-bit coefficient range and
the largest absolute input value (128 or 2^31). It bounds every partial sum
in any sign order by `i128::MAX`. A row count beyond that bound selects the
inherited field-arithmetic path. Zero inputs retain the old skip, and a zero
accumulator avoids a wide remainder.

## Measured scope

The isolated final candidate's ABBA run used the same binary, two threads,
512 rows, 768/2048 columns, int8/int32 inputs, and dense/99%-zero matrices.
Each arm has 3 warmups and 11 samples. Dense median ratios are **2.32–2.42x**;
sparse ratios are **0.89–1.20x** [MEASURED, NOISY-SHARED, fold microbenchmark].
The largest sparse int8 case is about 12% slower. This is an arithmetic
optimization, not a measured full-model speedup. The earlier unsigned-bias
candidate regressed sparse folds by 2.55–2.92x and was rejected; its evidence
is retained alongside the signed candidates.

## Acceptance evidence

Under [the retained results](../../results/zk60_rowfold_20260919/README.md):

- `attempt-4/validation.json`: all seven arithmetic tests in both switch
  modes; all eight benchmark cases also compare against base-field folding.
  Tests include signed extremes, full-field coefficients, ragged chunks,
  zero rows and refusal before reading an over-bound matrix.
- `integration/validation.json`: 37 core tests (35 library + 2 integration),
  261 default hashline tests, and all twelve frozen 12×512 proof-byte gates
  on CPU, GPU and forced-chunked GPU. All four historical digests and exact
  sizes match. Device-enabled and actual chunk-route assertions pass.
- Four fresh native receipts: attention and complete tiny block, generated
  in each fold mode. Every receipt verifies in fresh processes through both
  modes; each verification also rejects all three corruption controls.
  Sizes remain 2,245,800 and 2,816,472 bytes respectively.
- `integration/private-ffn-fold.json`: six repaired private-IO FFN P1/P3
  checks in each mode, including adversarial endpoint/receipt controls.
- `storage-gate/validation.json`: **288 passed, 0 failed, 2 ignored** with
  `stable-weight-storage`, including all 12 doctests. The two ignored tests
  are explicit native capture writers, separately exercised by the retained
  capture procedure; they are not silently counted as passed. This build
  uses a separate target directory and leaves the proof binaries unchanged.

Source, runner, binary and log hashes were independently rechecked after
completion. The standard floors definition advances to **suite v10** with
37 core tests and 288 storage tests / 2 ignored capture writers. Versions
1–9 retain their historical meanings; the device oracle still requires 189
executed cases. A focused helper test covers the new exact inventory and
refuses missing tests or extra ignored tests.

This acceptance covers field-equivalent row folding. It does not establish
whole-proof privacy, model-scale private blocks, the proof-size target or
five-second proving. The repaired-private host port, direct-plane upload and
shape-general cost probe remain separate integrations.
