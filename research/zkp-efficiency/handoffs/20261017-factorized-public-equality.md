# Unapplied: factorized per-column equality for row-first lookup arithmetic

Run `20261017T232105Z-d713e393`, cycle 0070, 2026-10-17.

Candidate: [factorized.rs](../experiments/factorized-public-equality-20261017/factorized.rs).
Interface: `factorized_rounds(N,C,&mut V_column_major,initial_points[C*logN],
column_point[logW],challenges[logN+logW])` returns four unmasked samples per
round, all three ordered E/S/V terminals and logical work counts. Full-challenge
input is an offline test interface; 1,699 mutation checks establish arithmetic
causality, but a stateful native adapter has not been built. No RNG/transcript
activity inside the arithmetic. Captured native `SumcheckRounds` at
`ops/zkp-mvp/gpu-zerocheck/zkp-core/src/sumcheck/rounds.rs:22` is the adapter
seam. A full lookup construction also touches `hashline/src/private_block/`
protocol lookup/H, argument relations, shape/layout and H/M/PCS accounting.

Probe is E*S*V, row bits before column bits, MSB first. Distinct row points
per real column, implicit public padding, division-free public equality walk,
one owned C*N V buffer, and small column tails. It matches 30 saved fixtures
and 54 new cases: 1,788 round values, 252 terminals, 447 whole-cube masked-chain
rounds, 22 controls. Independent audit 4,768 checks; causality 1,699 +1.
Main/audit/causality 3.151398 /7.180672 /0.111618 s; one CPU thread, no GPU or
native proof. Seeds, dimensions, commands, logs, pins and limits in
[experiment](../experiments/factorized-public-equality-20261017/README.md).

Counted 8B T32 four-group naive index+three-factor payload 625.625 MiB ->
178.783936 MiB including conservative summed small payload; largest group
94.017731 MiB. Not measured peak, not full model execution or native H savings.
Local cap refuses larger groups. Original query/witness data remains live.
Added 23,426,212 suffix-generation Fp2 multiplies and two separate V read
passes per round need enclosing timing. Current R5b direct H phase free-deletion
ceiling is only 1.126731x with other clocks fixed; entire architecture ceiling
unknown. There is no extra query commitment to remove in the existing path.

Do not promote raw virtual claims: they disclose singleton values. Preserve
all 83 original ordered and full-i64 wrapping links, distinct-point reduction,
GKR, complete-table zero refusals, fresh whole-cube masks, extensions, terminal
openings and soundness. E terminal is a mixture across different row points;
S terminal is non-Boolean. Base quadratic row arithmetic does not permit fewer
native masked samples: cubic CFS terms remain. Prior rank/diagonal-coordinate,
joint-mask, D/C, unused-table-zero, off-cube-product and endpoint-history
negatives remain. Only fixed public shape padding may be implicit, never
secret prompt length, selectors, mask rows or numerical witness zeros.

This is a new lookup-layout/protocol research prerequisite, not a byte-preserving
native lookup replacement. No production patch or merge; owner/Claude reviews.
Next local: stateful pending-previous-challenge fold plus next-round contraction;
never use the current unknown challenge before its message. Reject any round/
terminal/source-order/refusal/extension/mask/PCS/privacy mismatch or no enclosing
gain. Shared-lock native/device checks are proposals only, not queued here.
