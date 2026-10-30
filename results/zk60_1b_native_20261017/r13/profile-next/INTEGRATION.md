# Profile and layout integration contract

These are staged choices, not active proof profiles. PLAN.json records eight
model contexts matching the received T128 exports and Shieldstral T128/T256,
plus four development contexts. New profile strings retain an existing
65/55/47-byte length class; the full hash-kind census still must run.

The development geometry is T32/d384/f768/Q1024/KV512, 16 heads of64 over8 KV
heads, at 2^14 columns. It exercises D/F padding and the decoupled Q axis.
All matmul D/F and bilinear Q/Kv/S domains meet the row width and the DD head/token axes are full.
Endpoint rows must be max(1, ceil(Tpad*Dpad/N)) + MASK_ROWS, including when the
whole endpoint is shorter than one row.

Four ACT tables need16384 columns, with Dom::Tab exactly one row. Old tiny
development shapes cannot just receive new labels: their bilinear S/Kv cubes
would be lifted by the row width, a construction the current argument refuses.

## Gate denominator is per public block

The exact group fold chooses common_gate = max(17, max(effective_gate_shift)).
Its value depends on the public group members/base member, not only sh_g.
layout::lookups_at currently receives Shape and Ids, without BlockPublic.
Therefore Shape needs a separate accuracy_gate_shift scalar for R13, validated
in17..=24 and bound in the R13 calibration description. Do not silently use
the base sh_g or assume every group uses the same denominator.

Keep the existing NormCalibration type and every legacy shape/description
byte unchanged. A dedicated R13 setter must validate the scalar, and CS-8
reconstruction must replay it. BlockPublic::check_for_shape must require
accuracy_gate_shift == accuracy.folds().gate.shift after recomputing the
public data in the exact model registry/stack/base calibration. A default
geometry-only R13 shape can use17 for counting, but it cannot authorize a
block with a different public denominator.

The R13 Ids branch allocates AccuracyIds, retains its extra limb roles and
checks its domains against Shape's independently counted formula. Removed
NR3/NS3/MR3/MS3 stay usize::MAX. Lookups use the validated gate scalar and
derived Precision; helpers/sites/masks are counted from these lists.

norm_wrho remains the original base calibration window for constructor/CS-8
checks. R13 uses effective tn=base_tn-8 and exactly three norm limbs, with no
top pin. The trained base window <=32 already guarantees the effective
window <=24. norm_top_is_full_byte must return true on the R13 branch;
limbs_p/softmax/DD and diagnostics must use F_P12 via a profile getter.

Do not activate release prove/verify/loader profiles until the full argument,
LogUp histogram/helper generation, separate ACT pad support, scoped mutations,
dense proofs, fresh verify, legacy goldens and full gates pass. The installed
BlockPublic gate still refuses all accuracy attachments.

Correction discovered during argument integration: the earlier d192/f384 test proposal lifted DomD from8192 to16384 entries. Its matmul coordinate lists have only the natural13 variables, so use d384/f768 and add a new-profile D/F lift refusal. Do not silently append a free coordinate. Existing profiles stay on their established construction checks.
