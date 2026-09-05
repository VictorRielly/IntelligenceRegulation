# A00 — immutable fixed-calibration block preflight

Implemented in the round-2 contract checkout on 2026-09-04 (local date),
against `19ebd18` plus the supplied C0/round-1 source snapshot. This is a
new additive metadata boundary. It does **not** implement a private block
proof, a witness validator, an independent wire decoder, or a security
certificate. Existing attention/FFN verifier calls and CLI guards are unchanged.

## Delivered API

`hashline/src/private_block_contract.rs` exports:

- `BlockRegistration`: owned public attention/residual/FFN statements,
  missing scale metadata, proof parameters, declared P1 mode, approved
  model/calibration artifact identities and two public weight commitments.
- `ApprovedP1BlockContract::from_trusted_registration`: explicit application
  authorization operation. Source arguments must be authenticated independently
  of any candidate proof. Copying candidate roots into this constructor does
  not authenticate a model.
- `public_digest` and `bind_public_statement`: stable domain-separated digest
  over explicitly ordered, length-framed, little-endian public metadata. The
  mode's model declaration must be the canonical hex of the model artifact ID.
  These methods do not prove that any computation occurred.
- `preflight_candidate`: validate supported public metadata and compare its
  exact digest to the approved object. Success means **metadata preflight only**.
- `preflight_next_boundary`: check consecutive layer order, identical approved
  model/calibration IDs, and matching outgoing/incoming residual scale/class.
  A private equality proof is still required for actual committed values.
- `registration`: return an owned snapshot; mutating it cannot mutate approval.
- `host_arithmetic_envelope`: selected honest-integer operation bounds,
  conditional on the declared witness ranges; never a no-wrap certificate.

All refusal messages use static field categories. No private witness is an
argument to this module; errors do not print supplied field values.

## Deliberately narrow supported profile

| Property | Supported value |
|---|---|
| Shape | T=32, d=f=16, query heads=2, KV heads=1, head dimension=8 |
| Layer index | 0 through 31, with matching FFN layer |
| Private/public policy | P1, committed output, no predicate; public approved W/gamma |
| Input/AO/residual classes | INT16 only |
| RMSNorm | Round only; fixed integer Ceps in 1..=16; exact d=16 window rule |
| Table resolutions | fE=fP=9, fRo=7; RoPE base exactly 10000 |
| PCS parameters | log_cols=8, inverse rate=8, column checks=256 |
| Input/output regime | Prefill block metadata only; no generation claim |

T=32 is intentional: the current attention KV domain has `T * 8` entries,
so its smallest message row can accommodate 256 pad symbols/checks without
lowering their count. T=4 is refused by this profile, rather than silently
using smaller proof parameters. Inverse rate 8 is a **new experimental
profile**, not a modification to any old FFN proof. It is not routed through
I1's existing single-FFN inverse-rate-4 approval verifier.

Retaining 256 checks, or making the hiding code's nominal effective rate at
most 1/4 at this tiny shape, does not establish whole-proof security bits.
Mask commitment, composition, challenge space and repeated-opening analysis
still need independent review at the actual dimensions.

Validation happens before calling assertion-bearing table/layout helpers.
The module restricts shape, exponents, shifts, norm windows and limb counts,
checks actual table bytes/digests and actual attention W/gamma layout, and
checks both residual and all represented QKV/RoPE/O/FFN scale equations.
It never calls `fit_norm`, `fit_requant`, `residual2` or CLI `derive_ffn_on`.
The fixed norm remainder width is derived from the **whole declared INT16
input range**, not from the current secret witness's maximum.

The contract explicitly includes `AttentionExponents` and `V3Exps` because
the current `AttnConsts`/`StatementV3` do not by themselves carry every
physical scale needed at composition boundaries. Integer Ceps is frozen
directly; authenticating its derivation from a floating-model epsilon is
the calibration registrar's responsibility.

## Honest fixture and tests

`hashline/tests/zk60_block_contract.rs` computes the approved public W roots
directly from tiny matrices before supplying any candidate: zero attention
projection weights, gamma=64, FFN Wg=Wu=1 and Wd=0, packed in the actual
`AttnLayout` / `LayoutV3` order. It uses the frozen SiLU (-3,-11) table,
actual exp/RoPE generators, and fixed shifts. Roots are not copied from a proof.

The exact host fixture has alternating all-1/all-minus-1 input rows. It
checks all RMSNorm planes against scalar values, derives the FFN with the
real `derive_v3`, and checks every FFN output/remainder plane against a
separate scalar integer calculation. Zero attention output projection and
zero FFN down projection make the residual values the original inputs.
This is not a complete attention witness/proof or an all-tensor block oracle;
those are still required in A01/A05–A07.

Seven tests cover:

- valid registration, actual layouts/table members and conditional bounds;
- the exact norm/FFN host fixture without fitting;
- 42 hostile metadata mutations, checked rejection without panic/value leaks;
- seven otherwise-valid changes requiring different independent approval;
- immutable snapshots and public-digest transcript separation;
- consecutive model/calibration/layer boundary preconditions;
- identical integer-word interpretation with changed residual scales rejected.

The fixture's conditional host bounds include SS+Ceps=17,179,869,185,
D<=131,072, round norm denominator<=536,870,912, doubled numerator
<=8,589,934,592, and scaled residual sum magnitude<=65,536. These are
**computed bounds on honest bounded integers**, not benchmark measurements.
They do not show that a malicious field witness obeys these bounds, that
every input fits its narrowed outputs, or that all proof relations exclude
modular aliases. Public-weight/gamma ranges also cannot be established
from a root alone; independent approved weights and their calibration must
satisfy that obligation.

## Validation record

Executed under the shared lock with two build/Rayon threads:

```sh
flock /tmp/zk-heavy.lock env RAYON_NUM_THREADS=2 CARGO_BUILD_JOBS=2 \
  cargo test --release --offline --manifest-path hashline/Cargo.toml \
  --test zk60_block_contract
```

Initial result: exit 0, seven tests passed, compile 53.51 seconds. Final
post-format result: exit 0, seven tests passed, compile 49.07 seconds. Both
test bodies were below the timer's 0.01-second display precision. These
are correctness checks, not quiesced performance measurements. Eight
pre-existing warnings in `attention.rs` were left untouched. Targeted
`rustfmt --check`, `git diff --check`, and no-index whitespace checks on
all three new files passed.

A repository-wide `cargo fmt --check` reported extensive existing formatting
differences (and made no edits). Only the two new Rust files were formatted
with `rustfmt --edition 2021`; unrelated files remain untouched.

## Next integration boundary

Use this immutable contract digest as context for S2's experimental private
seam. Bind both commitments, scales and slot identities before drawing the
equality challenge. Neither context binding nor `preflight_next_boundary`
can replace that equality proof. Later A03/A07 must reserve the actual
FFN/attention boundary masks before commitment and consume every obligation.

Remaining gates: complete hostile-witness arithmetic/field-bound audit;
full private attention/norm/residual arguments; pending private FFN openings;
both seam types; framed independent-byte verification; private-weight model
consistency; and embedding/head/token-selection/stateful generation coverage.
No unsupported CLI mode, 60/s claim or sensitive-use security approval is
introduced by A00.
