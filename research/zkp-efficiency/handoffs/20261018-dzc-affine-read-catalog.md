# Unapplied D affine follow-up: arithmetic candidate, no memory saving

Cycle0075 / `20261018T042105Z-c9fe8fca`. Complements cycle74's handoff;
main/Claude owns review and integration. No native proving speedup.

Seam: owner `ops/zkp-mvp/gpu-zerocheck/hashline/src/private_block/argument.rs`
`SC_DZC` / `B::a_range` / `lk_tables`, and `zkp-core/src/sumcheck/rounds.rs`
`SumcheckRounds`. Five source pins and read-only snapshots are under
`experiments/dzc-affine-read-catalog-20261018/`.

Candidate patch location: `run.py::{prep,lin,fast}`. Interface:

```text
prep(returned_table_id_map, fresh_mu, public_constants, norm_limb_count)
  -> accumulated [(table_id, coefficient)], affine_constant, four bilinears
lin(original_point_values, prepared) -> proof-local L value
fast(original_point_values, folded_L_value, prepared) -> same clause value
```

Use the actual returned bindings and shaped limb maps; repeated table IDs
require coefficient addition. No literals from the toy layout transfer.
The tiny reference executes captured native catalog/indexing routines with
Shape/Layout substitutes; full native admission/mask-site identities remain
owner gates. `public-profile-scalars.json` pins the two T128 metadata sources.
Both trained norm windows are32bits under the actual signed-int16 derivation.
The initial wrong32767 formula/provisional31bit8B result is preserved and
superseded; a negative control catches it.

Measured synthetic validation:24fixtures,2,028 native-reference full values,
468 round sums,1,488 original-cube terminals,24 full-expression permutations,
24 alias cases,24 harness binding refusals and10 controls. Independent83-check
catalog/source/count audit passes. Main1.182 s, one CPU thread, no GPU. Field
is an exact u128 substitute; this is not native field/PTX, transcript, RNG,
proof-byte, malformed-input parity or fresh-verifier/privacy validation.

Negative result to retain: current unpadded D has59 original tables;
helper/host/bilinear dependencies retain58, plus L is59. Only `A_X2` can be
omitted from the candidate's arithmetic input subset; it remains an original
private final claim. Padding brings that read back. Generic ClosureRounds
still loads/folds every original table and adds L, yielding60 tables, all54
private final claims retained. At8BT128 add8MiB plus285,212,672 generic-build
logical bytes (146,800,640 base),25,165,776 fold bytes and16,777,184 unique
pair-endpoint bytes. Counts are not measured bus traffic or peak memory.

Do not sell this as a memory optimization. Port only if measured D clause
arithmetic share repays construction/folds/extra scratch/register costs.
All-D deletion bound on carried1.1B run1.18113x; 8B clause ceiling unknown.
Keep extension rounds on the ORIGINAL polynomial and ORIGINAL final vector:
L is internal driver scratch, never a new private terminal/opening or a
replacement for the verifier's oracle. Recompute affine values from current
original values if an extension-stage evaluation uses them; do not give L
an independent mask. Preserve all definition draws and per-proof fresh masks.

Before promotion: owner native layout/degree/round/final/refusal parity,
seeded proof bytes, transcript and next-RNG equality, fresh verification and
current joint-view privacy gates, then enclosing warm/total workload clocks.
No cache/private mask/opening reuse or security/profile change is authorized.

Next experiment: derive D's exact row polynomial coefficients from original
endpoints, including34 lookup denominators/17 helper products and hosts.
Count all coefficient construction/recovery work versus additive point
stepping before adding any working table or requesting a GPU port.
