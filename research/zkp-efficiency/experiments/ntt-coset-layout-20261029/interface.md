# Future native adapter contract — design only, no patch applied

Target functions: `CudaNtt::encode_rows_view_zk` and
`encode_rows_view_zk_gather` in pinned trained-1b cuda.rs. Preserve the
incumbent implementation as fallback, including every current native guard.

Inputs: exact canonical Goldilocks n/r/q/h/roots; contiguous chunk views
data[rc*n], pads[rc*q] from the existing fresh draw; row0 and rows_total;
public scales alpha[s][t]=(h*omega_(r*n)^s)^t and
A[s]=(h*omega_(r*n)^s)^n, independently keyed to field/roots/n/r/h. Private
coefficients or evaluated split inputs never enter the public cache.

Keep the normalized n-point inverse. For a proposed first q<=n path, each
logical (row,s,t) supplies `(coef[row*n+t]+(A[s]-1)*pad[row*q+t])*alpha[s][t]`,
where t>=q skips the pad load and multiplication. No length-N transform of these n coefficients
is required: r independent n-point forwards suffice. q>n falls back until the
full modular-fold route has native validation; never truncate high pad blocks.
The Python general route is an oracle, not permission to broaden admission.

Dispatch batch dimension rc*r, preserve the parent proof's original order
and randomness stream. Write final local j to
`enc[row*(r*n) + s + r*j]`. A mapped intermediate is permitted only behind an
exact logical store adapter. Every salted/keyed BLAKE3 column consumes exactly
the original little-endian bytes in the original row order; no change to hash
tags, salts, commitments, claims or openings. The same proof's one masked
polynomial is evaluated across cosets. Every later proof draws fresh pads,
masks and salts; no private result or opening is cached across proofs.

Gather: logical requested k gives `(s=k%r,j=k/r)`. Preserve caller ordering
and duplicates, source row0, rows_total, compact output strides and ragged
chunks. Existing P2-gather cannot silently be used for n<=4096 (new last-stage
path needed). Preserve reencoding from the exact original private pad owner.

Costs to measure before review/promotion: actual eligibility and exclusive
inverse/prepare/forward/gather/hash/enclosing clocks; public table preparation
and retention; coefficient/pad/power loads; store coalescing; shared/register
use and occupancy; pooled/raw peak capacity and all fallbacks/error cleanup.
The naive materialized split needs r*n input words versus existing n+q;
a fused first load risks the earlier scattered-load negative. No speed claim.

Validation still owed: compiled Goldilocks edge/root/inverse/full/compact/
coset/q>n fallback/stride/chunk/gather parity; seeded masked messages, next RNG
draw/challenge, full PCS/root/receipt bytes and refusal parity; strictGPU
behavior; independent fresh-process complete verification; current whole-run
soundness/fidelity/privacy gates. CPU algebra equivalence does not extend a
privacy acceptance. Apply current shared locks/guard, no job queued here.

Falsifier: any lost/different encoded column or refusal, mask/pad/salt lifetime
or transcript drift, absent native incidence, resource regression or no gain
in the complete verified workload. Main/Claude alone reviews and integrates.
