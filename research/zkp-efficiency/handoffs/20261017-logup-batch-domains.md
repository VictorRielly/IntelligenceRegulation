# Lookup batching domains — research handoff, unapplied

Run `20261017T212105Z-f1b8cd7d`, cycle0068. **No native proof or speedup.**
Prototype: `experiments/logup-star-batch-domains-20261017/batch.rs`.
Its `batch(index,lengths,active,row_point,column_point,table_size)` returns
PRIVATE Fp2 weighted buckets. Public synthetic support only, no GKR/PCS,
transcript, masking, original-witness binding or hidden-length protocol.

96fixtures/3,744bucket values/96claims pass;19controls. Independent polynomial
convolution/symbolic-rank/F17 audit4,136checks. OneCPU thread, each<1s,
59s/512MiB caps. Source hashes, commands, seed2026101768 and hardware in bundle.

New decisive rejection: using the same scalar for all7column coordinates
gives83column equality polynomials rank7, hence76dimensions of fixed errors
that always cancel. Independent coordinates distinguish the simple column1/2
control at272/289 F17 points. This is our rejected shortcut, not an upstream
or native attack. Binding claims before aggregation is separately required.
Raw batched virtual evaluations still leak singleton secrets; correlated
fresh-looking pads can hide marginals and leak jointly. No mask reuse allowed.

At8BT32,83U8columns/11,714,560queries per block. Six-domain padding1.702x;
four equal-length groups1.523x;global128-column cube5.729x. A supported ragged
traversal can skip dummy entries, but needs a checked reduction. Four-group
pushforward payload16,384B logically /524,288B at old row width, BEFORE masks.
These are future-architecture illustrations, not measured memory/traffic or
net H saving. Extra query commitment saving zero: query arrays already absent
from commitments. Retain83ordered index links before additional reductions,
eight initial/terminal pushforward scalar sites in the four-group illustration,
fresh round masks, reserved A/PCS sites, whole-table refusals and wrapping.
Exact native mask rows and net displacement UNKNOWN until construction review.

Owner seam: `ops/zkp-mvp/gpu-zerocheck/hashline/src/private_block/protocol.rs`
lookup/H construction; `argument.rs` relations; `shape.rs`/`layout.rs` claims
and H/M schedule. The researcher changes no owner file. A versioned design
must preserve privacy, appropriate soundness tier, draw/absorb order, original
ordered A links and refusal domain before any device port or promotion.

Current coldCPU8BT32 owner171.578s now freshly verified,11controls,shape
privacy still open. Free deletion of all four H phases19.5s bounds direct
effect1.128224x with other work fixed, before added costs; not a whole-
architecture/GPU ceiling. No new target proofs or positions credited.

Next bounded gate: dense/ragged round-polynomial equivalence for four domain
groups with independent starting points, explicit support and every terminal
obligation. Owner should finish whole-proverGPU and fixed-context workload
slopes under existing locks; no heavy work queued by this handoff.
