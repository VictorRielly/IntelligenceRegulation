# Review handoff: unpadded SC_SZC round0 coefficients

Run `20261017T042624Z-0f7bf604`,2026-10-17T04:37:37.221578+00:00. Research arithmetic candidate only;no native speed claim.

The complete local validation and source census are in
[the experiment](../experiments/unpadded-cubic-factory-20261017/README.md).
All1,890 schedules,19,650 independent samples,43,920 finals,144 extension
checks,12 value-independent censuses,20 counter cross-checks and five mutation
controls pass. Final run 10.054167s,22,184KiB RSS,one CPU thread.

Actual candidate seam (read-only here):
`ops/zkp-mvp/candidate/hashline/src/private_block/argument.rs:1783/1788` and
`ops/zkp-mvp/candidate/zkp-core/src/sumcheck/grouped.rs:93/107/121/132`.
Hashes match sonnet-hardening snapshots in the experiment;root main differs.

Proposed interface: definition-local prepared lookup offsets plus a
`begin_row(round,cur,dif) -> Option<[Fp2;4]>` factory for group0. Derive
public shape/dependency metadata inside the native constructor. Select only
unpadded round0 with at least2 rows;scalar fallback everywhere else. Weight
and reduce4 coefficients,then evaluate original bracket samples0..3,retain
five outer outputs and existing hosted groups/claims/finals. No protocol,
masking,challenge sampling or cross-proof private cache changes.

Research patch: `experiments/unpadded-cubic-factory-20261017/cubic_factory.py`
and `experiment.py`;`research-source-diff.patch` is research-only. Do not
integrate the Python interpreter or dynamic polynomial allocations. Proposed
next local work is fixed straight-line Rust-style generation/liveness;no
native source was modified or native build launched.

Counted hp32/kv8/qh32/T512/three-limb scope falls3,527,474,753 to3,280,010,835
API ops (7.0153%) versus prepared scalar. Every API category drops in this
round-zero policy. The23.5578% comparison versus literal additionally includes
denominator preprocessing and is not cubic-only. Blanket all-round construction
is demoted:after claim recovery it adds22 general multiplications per row on
constant-mask axes. Round0 recurs each proof;it is not startup amortization.

Charge15 offsets/30 field setup ops/15 classifications,4 coefficient words,
unknown extra temporaries/native scratch/dispatch/code and retained public
width tests159,383,552 in the T512 interpreter. Per-part8 words are unchanged.
The census omits common Eq/interpolation/recovery/folds/PCS/masks/witness work,
plus native Rayon identity-fold additions. Compiler optimizations may erase
counted literal work. Counts and Python clocks establish no native rate.

Owner gates before promotion: native scalar/constructor parity across profiles,
zero-factor and malformed/refusal preservation;all five masked messages,
transcript/challenges/RNG continuation/finals;fresh masks and all commitments;
old/new receipts and independent verifier/tampering;new-shape privacy acceptance.
Then guarded3-arm phase and enclosing measurements,including both witnesses,
serialization,independent verification,peak memory and resident startup/slope.
Falsify on any mismatch or if dispatch/setup/scratch erases saved arithmetic.

End-to-end private8B ceiling unknown. Historical complete SC_SZC-removal ceiling
is28.317% of one synthetic block's27.523873s enclosing test,not8B. Target remains
>=50 proved tokens/s;accepted full private8B proofs/passes/tokens0/0/0. All
required target clocks and rates unmeasured. No heavy job or merge requested.
