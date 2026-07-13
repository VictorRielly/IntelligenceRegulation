# GPU port contract

This is the contract a CUDA, HIP, Metal or other accelerator backend must
match. The CPU reference is `zkmatrix-rs/src/ring/kfield.rs`.

## Field and representation

- Base modulus: `q = 2,147,483,249 = 2^31 - 399`.
- Extension: `K = GF(q^16) = Z_q[Y] / (Y^16 - s)`.
- Frozen slot-zero root: `s = 2,056,890,868`.
- Every coefficient is canonical on entry and exit: `0 <= x < q`.
- Each coefficient is stored as little-endian `u32` in memory.
- One K element contains 16 coefficients in increasing powers of `Y`.

## Packed table ABI

- `KL = 8` independent K elements per block.
- `KBLK = 8 * 16 = 128` `u32` words per block, or 512 bytes.
- Layout is coefficient-major structure-of-arrays:

  `word(block, coefficient j, lane l) = block * 128 + j * 8 + l`

- The last block is zero-padded. Logical length is carried separately.
- Buffers passed as distinct inputs/outputs must not overlap unless a future
  kernel explicitly documents in-place behavior.

## Required primitives

The first GPU tranche should implement, in this order:

1. fixed-operand elementwise multiplication;
2. fold/deinterleave: `out[i] = T[2i] + r(T[2i+1] - T[2i])`;
3. projective tree step:
   `p' = pL*qR + pR*qL`, `q' = qL*qR`;
4. broadcast modular add;
5. elementwise table multiplication; and
6. round-polynomial accumulation (`round_g`).

Do not port transcript hashing, statement validation or verifier logic into a
GPU kernel. Accelerator output is deterministic arithmetic data consumed by
the unchanged protocol layer.

## Reduction contract

- Widen each `u32 * u32` product to `u64`.
- Accumulate low and high 32-bit halves in separate `u64` planes.
- Reduce only at the same boundaries as the CPU reference.
- Use `c31 = 2^31 mod q = 399` and `c32 = 2^32 mod q = 798`.
- Fold the high `Y^16` coefficients with `Y^16 = s`.
- Produce canonical values; lazy or redundant residues may not cross the
  CPU/GPU API boundary.

The round-polynomial persistent accumulator is permitted only while the
logical packed table is at or below `2^25` leaves. Raising this cap requires a
new worst-case integer proof, not just a larger allocation.

## Round-polynomial details

- Input tables are `eq`, `p0`, `p1`, `q0`, `q1`, `ql`.
- `ql` is already `lambda*q0`.
- The wire relation is `p0*q1 + p1*q0 + ql*q1`.
- Node `1` is not evaluated by the kernel; it is recovered from the running
  claim. Evaluated nodes are `0, 2, ..., degree`.
- Optional constants are indexed `[node][operand 0..5][coefficient 0..16]`
  for the five non-eq operands.
- Final lane summation and the final `Y^16 = s` fold are exact `u128` work on
  the CPU today. A GPU version must prove an equivalent non-overflow bound.

## Correctness gate

For every primitive and full descent:

`GPU output == forced-portable packed output == AVX-dispatched packed output == boxed scalar output`

Comparison is byte-for-byte after canonicalization. It must include:

- the static boundary vector in the U-K9 battery;
- randomized vectors;
- minimum, full-block and tail sizes;
- the maximum admitted logical size or a chunked equivalent;
- single- and multi-instance descents;
- masked and unmasked descents; and
- transcript equality, not only final-claim equality.

Any kernel error, unsupported size or allocation failure must return a typed
error before a transcript is advanced. Panics are acceptable in the current
prototype but are not the production API.

## Suggested launch strategy

- Map one logical K element to one lane/warp subgroup initially; preserve the
  eight-lane block ABI at host boundaries.
- Fuse deinterleave, extrapolation, multiply-accumulate and reduction only
  after the unfused kernels are differential-test clean.
- Stream tree layers and discard children once the protocol no longer needs
  them; do not materialize boxed K elements.
- Keep statement-sized instances chunked under the audited accumulator cap.
  Cross-chunk reductions must use the same deterministic order or an exact
  associativity argument.
