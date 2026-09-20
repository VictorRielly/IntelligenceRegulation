# `private-block-kernel-shaped`

The ZK60 private block's reference integer computation **as a function of a
shape**. It is computation only: not a proof, not a privacy claim, and it
authenticates nothing.

## Why it is a separate crate (job K, security owner's ruling 2026-09-20)

`private-block-kernel/` is compiled into the project's **zkVM guest**
(`zkvm-block/model`, and `private-model-kernel` beside it), and that guest's
image identity is an approved, recorded artifact of the other proving line.
Step S6 of the 125M change list first generalised that crate *in place*; the
ruling is that it must stay **byte-identical** to its content at commit
`11c01b2`, so the shape-driven kernel lives here instead.

Consequences of the split, all deliberate:

* This crate **does not depend on** `private-block-kernel`, so the frozen
  crate stays a leaf the guest compiles alone.
* The toy calibration (`calib`) and the scalar primitives (`add`, `sub`,
  `mul`, `shl`, `requant`, `isqrt`) are therefore **copied**, not shared.
  A copy can drift, so the split is guarded by a cross-parity test in
  `hashline` (`private_block::parity`) that asserts, at `Shape::toy()`:
  every `calib` constant equal, `isqrt` and `requant` equal on a sweep, and
  every trace plane of `run_shaped` equal to the frozen crate's
  `run_block` trace, element for element, on every existing fixture case —
  accepts and refusals alike, with the same refusal string.
* The frozen crate keeps its own fixed-shape implementation and its own
  tests exactly as they were.

## Discipline

`no_std`, `forbid(unsafe_code)`, no dependencies, no allocation, no floats,
no I/O, nothing printed. The general path cannot size its own intermediates,
so the **caller** supplies one flat scratch buffer of `Shape::scratch_len`
`i64` words and (for parity tests only) one trace buffer of
`Shape::trace_len`.

The trace holds SECRET intermediate activations and exists for native parity
tests only; nothing here prints, hashes or serializes it.
