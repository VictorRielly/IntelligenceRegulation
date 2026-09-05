# E1 — fixed-calibration CPU causal block witness oracle

Added to the round-2 contract checkout on 2026-09-04 (local date), after
A00. Owned changes are new `hashline/src/causal_oracle.rs`,
`hashline/tests/zk60_sequence_equivalence.rs`, this report, and a local
`lib.rs` module registration. No attention, ZK, GPU or PCS implementation
was modified. **This is a witness oracle, not a block proof.**

## Implemented surface

`PublicBlockWeights` supplies public INT8 matrices and gamma vectors.
Attention matrices use checkpoint `(output,input)` order; FFN `*_t`
matrices use `(input,output)` order. Shapes are checked before indexing.

`cpu_weight_commitments` packs both weight sets using actual `AttnLayout`
and `LayoutV3`, then explicitly uses CPU inverse/forward NTT, column hashing
and Merkle construction. It never calls a GPU-dispatching PCS commitment.
Computing a root is not approving its model: the application independently
authorizes the weights before registering those roots with A00.

`FixedCausalOracle::new` checks the actual supplied public matrices against
both independently approved A00 roots and owns the matrices/registration.
`build(&[i16])` requires exactly 32 rows of width 16 and returns the existing
`AttnWitness`, `V3Witness`, and `Resid2` types plus the public contract digest.
The returned tensors, including FFN witness digests, are secret local
debug/proving material, not material to publish as a private receipt.

The builder executes both round RMSNorm sites, QKV projections, rotate-half
RoPE, GQA scores, exact table softmax, PV, output projection, both residuals,
and the fixed v3 FFN. Constants come from the immutable contract. There is
no export access, floating softmax, clipping of accepted witnesses, automatic
shift fitting, `residual2` fitting call, or `build_attn_witness_full` call.

Before invoking `norm::rmsnorm_chain`, the builder computes each bounded
integer norm row/division and rejects out-of-range output/remainders.
Before invoking `export_v3::derive_v3`, a separate scalar calculation checks
all FFN narrowing and remainders. Every returned FFN plane is then compared
against that scalar result. `checked_ffn` and `derive_v3` share
`requant_round`: their GEMM/preflight paths are independent, but their
rounding implementation is not. The additional asymmetric fixture test
uses its own scalar signed-rounding formula to check that boundary.
These checks precede assertion/clamping paths;
`catch_unwind` is not relied on in a release build that can abort. Refusals
carry static site names, never supplied witness values.

## Exact semantics and intentional restrictions

This inherits A00's T32/d16/f16/H2/Hkv1/dh8 profile, fixed INT16 residual
classes, round norm, fixed table resolutions and inverse-rate-8 PCS roots.
The oracle further limits attention INT8 narrowing to **[-127,127]**, the
existing honest builder's subset. The proof's INT8 lookup table allows
-128; this oracle deliberately does not cover that boundary.

The row maximum is over the *masked* score array: real `s8` on `j<=t`,
sentinel -127 off support. The first attaining position is selected with
a strict-greater scan, exactly as the current builder. With scores in
[-127,127], an on-support position always attains this maximum. Exp values
are generated for all positions, but only on-support values contribute to
the denominator; P and rho are zero off support. The source witness stores
sigma=0 off support while `attention::pack` reconstructs `Sum-1-rho` for
its range fact there. The oracle follows that representation and separately
checks the reconstructed bound on every position.

No claim is made that every INT16 input fits a particular approved
calibration. A witness that does not fit is refused; a different shift,
table or norm remainder width is never selected automatically. Even a
future-only mutation can cause a whole-build refusal if its suffix does
not fit. Causality comparisons below concern two successful builds.

## What the sequence-equivalence tests establish

Tests compare two accepted inputs of **the same T32 shape**, same positions,
same public weights and same fixed calibration, changing only rows after
cut points 1, 7, 16 and 31. Prefix attention/FFN/residual outputs and tested
per-position witness planes remain equal. The masked softmax planes remain
equal for all columns in each prefix query row. Raw future score columns
are intentionally excluded: they depend on the changed future keys and
can differ even when the prefix outputs are unchanged.

This is bounded experimental evidence, not a general equivalence theorem.
It does not compare separate T1/T2/T4/... proofs to T32: A00 refuses those
shapes, smaller T changes table identifiers/remainder widths/layout and
proof transcripts, and variable-length suffix existence interacts with
the -127 sentinel at the -128 score corner excluded here. It does not
cover adaptive calibration, nonzero absolute RoPE offsets, KV-cache reads/
updates, sliding windows, batching, or generated-token release timing.

For the eventual delayed sequence receipt, this is useful evidence that
fixed-calibration block computation can preserve already-computed prefix
values after a future suffix is supplied. Embedding gathers, final norm,
vocabulary head, token selection, request/state binding, full private
proofs and independently decoded verification remain separate required work.

## Fixtures and validation

The nontrivial fixture uses diagonal attention Q/K/V/O weights of 64,
gamma=64, FFN Wg=Wu=1 and diagonal Wd=64. Input rows vary over small signed
integers. Tests require nonzero scores, nonzero attention output projection,
nonzero FFN output and a residual output distinct from the input. Integer
projection/score/softmax/PV/residual equations and existing `pack` range/
layout checks run on the returned witness. Additional cases cover maximum
ties, wrong public roots, malformed shapes, residual overflow, norm output
overflow before its source assertion, and FFN overflow before derive/clamp.

Following review, a seventh test adds signed asymmetric off-diagonal
Q/K/V/O and FFN weights. It checks scalar sums and independent signed
rounding/remainders, confirms the fixture distinguishes square transposes,
and compares roots from existing attention packing and the explicit FFN
layout against approved roots. This follow-up test was added without
compiling/running in the worker checkout; the lead then passed all seven
in the final integrated release suite (94 total Rust tests).

CPU validation command (two build/Rayon threads, shared lock):

```sh
flock /tmp/zk-heavy.lock env RAYON_NUM_THREADS=2 CARGO_BUILD_JOBS=2 \
  cargo test --release --offline --manifest-path hashline/Cargo.toml \
  --test zk60_sequence_equivalence
```

Initial result: exit 0, all six original tests passed; 49.19 seconds compile and 0.01 seconds
reported test time. These are correctness-run timings, not performance
evidence. Eight existing `attention.rs` warnings remain unchanged. Targeted
`rustfmt --check`, `git diff --check` and no-index whitespace checks passed.
No GPU, export download, full-model run, proof benchmark or token/s estimate
belongs to this lane. Existing deterministic proof fixtures remain the
integrator's gate; this additive oracle does not change their code paths.
