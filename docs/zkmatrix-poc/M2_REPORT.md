# M2 Report: Elementwise Gadget Family (Lattice Track)

Status: **lattice track implemented, tested, and measured** (Hadamard,
binary, packed range, rescale-with-rounding, manifest integration, demo,
negative-test battery — commits `e957d74`, follow-up demo commit). The
pairing-track twins are **designed but deferred** (Section 5); the
Python mirror is deferred with them. The exit-criterion measurement
produced the milestone's most important result — a quantified negative
finding (Section 4) that resets the Class-3 strategy.

## 1. What was built (lattice Route Z)

- **Hadamard/binary gadget** (`prove_hadamard`/`verify_hadamard`):
  per committed column, per repetition, the claim `<s o x, y> = s^T z`
  for fresh `s` from `S_b^L` is proven with the Pi2-style garbage-term
  Sigma-protocol under mixed keys: `s o x`'s commitment is *derived*
  from `T_x` by scaling the message rows of the second slot by `s`
  (key `(G1, D_s G2)` — first slot untouched, so relaxed binding is
  Lemma 5.5 verbatim, the same argument as Pi2's scalar key), `y` under
  the standard key, and the scalar `s^T z` under `g_s = s^T G2` exactly
  like Pi2's `T_t`. Soundness: 3-special soundness per Theorem 8.3's
  argument, plus per-repetition compression error `<= 2^-b` (a defect
  `d = x o y - z != 0` survives `<s, d> = 0` w.p. `<= 1/2^b`); the new
  extraction norms fold into the shared C3 beta iteration
  (`sigma_h`/`bound_h_sq` in `Params`). Binary constraints are the
  `x = y = z = b` special case.
- **Packed range proofs**: a column's width-`W` bit decomposition packs
  into ONE committed column (slot `i*L + t` = bit `i` of element `t`),
  so the binary family runs per column, not per bit vector — the
  swappable-strategy requirement; `derive_params_gadget` raises the
  message dimension for packed columns. Recomposition
  `<s, value_j> = <w, packed_j>` with `w[i*L+t] = 2^i s_t` is linear and
  batches across all columns with fresh weights `u_j` into one two-key
  scalar-link Sigma-proof per repetition (the transpose-gadget shape,
  keys `g_s` and `g_w`); the signed convention (offset `2^{W-1}`) is a
  public adjustment of the packed-side scalar.
- **Rescale-with-rounding** `x = 2^shift y + r`: a zero-opening proof on
  the `u`-combined difference `sum_j u_j (T_xj - 2^shift T_yj - T_rj)`
  (per-repetition fresh `u`; rejection-sampling center sized from the
  public combination data), plus ranges on `r` (width = shift) and `y`
  (declared width). The two ranges are what turn the mod-q relation
  into integer floor division — without them the relation can wrap.
- **Manifest**: `Hadamard`/`Binary`/`Range`/`Rescale` operation kinds;
  every gadget challenge binds the manifest digest and the CRS hash.
- **Tests**: the self-test battery covers valid cases plus wrong
  product, non-binary bit (a 2 in one slot), out-of-range remainder
  (`r + 2^shift`, `y - 1` — linear relation intact, recomposition
  catches it), wrong shift, wrong quotient, tampered responses, `+q`
  norm overflows (caught only by the exact-integer norm check),
  swapped commitments, and manifest-context separation. Full repo
  suite: 36/36.

## 2. Demo and measurements

`lattice_matmul gadget-demo` (X 16x32, W 32x64, shift 6, quotient width
12; 1024 rescaled elements, 22-thread machine):

| item | measured |
|---|---|
| matmul claim (Pi2) prove | 0.82 s |
| gadget commits (Yq, R, 2 packed-bit groups) | 0.36 s |
| rescale+range family prove | 111.0 s |
| family / matmul-claim ratio | **13,566% (135x)** — criterion: <20% |
| per rescaled element | 108 ms/element |
| verify (all five proofs) | 31.6 s |
| commit-cost multiplier | ~4x the value matrix's own commit (2 packed groups + quotient + remainder, same column count) |

All proofs verify; the wrong-quotient negative fails as required.

## 3. Soundness notes

- Derived keys change only the second slot's public matrix; extraction
  and binding run through the unchanged `G1` first slot (Lemma 5.5).
- Every challenge is drawn after the commitments (and manifest digest)
  it binds; the reordering/context-swap tests enforce this.
- Padding: committed columns are zero-padded into the shared message
  dimension; every gadget reads only declared coordinate ranges
  (`[..l]`, `[..width*l]`), so padded slots cannot smuggle values.
- The gadget norm bounds are exact integers folded into the C2/C3
  parameter iteration; the conservative link/recomposition folding
  covers compositions up to `GADGET_MAX_SHIFT = 12` and the derived
  `max_cols`.

## 4. The exit-criterion finding (the important part)

The <20% criterion is **missed by ~3 orders of magnitude**, and the
reason is structural, not an implementation constant: Route Z proves
each bilinear gate vector with per-repetition one-time-pad masks, so a
packed column costs `~2(k+msg)N + 2kN` MACs *per repetition* times
`r = 64` repetitions times `M ~= 2.76` rejection restarts — about
`10^6` MACs per rescaled element — while the matmul claim it
post-processes is side-linear (its per-repetition cost is independent
of the matrix area). Consequences:

1. **Route Z is the wrong tool for Class-3 constraints at scale.** The
   packing implemented here (bits per column -> one packed column)
   saves the width factor, but the per-column Sigma-protocol floor
   remains. No amount of kernel engineering closes three orders of
   magnitude.
2. **Route R gets a second, stronger mandate.** `r: 64 -> 1` removes
   the dominant factor directly (~64 x 2.76 ~ 175x), and the ring's CRT
   slots make elementwise products near-native (SIMD Hadamard). With
   both, the projected family cost lands near the original criterion.
   The LLM_SCALE_ESTIMATE range-proof condition must be read with this
   finding: on Route Z it is the gadget *proofs*, not the commitments,
   that blow the 2x budget.
3. **The tracks invert for elementwise work.** The pairing track's
   element-proportional MSMs (~30 us/element measured at n = 2048)
   would be ~3,500x cheaper per element than Route Z's ~108 ms/element
   — the opposite of the matmul-claim story. Interim architectures
   could plausibly mix tracks per operation class (matmuls on lattice,
   elementwise on pairing) at the cost of cross-track link gadgets —
   recorded as an open design question, not a recommendation.

## 5. Deferred: pairing-track gadgets (design recorded)

Bulletproofs-style over the whole-matrix SRS windows: Hadamard claim
`sum_ij w_ij (X_ij Y_ij - Z_ij) = 0` with rank-1 weights
`w_ij = s_i v_j` folded into the IPA h-basis coefficients (as `y_L`
folds today), proven by the existing masked product IPA (X against
w-weighted Y) plus a c-projection-style public-IP proof for the
`<w, Z>` side sharing the same u-base scalar; closed-form verifier
evaluation of the weighted window is the product of two short public
evals (`zeta^off * (sum_i s_i zeta^i)(sum_j v_j zeta^{L j})`) — a new
`FormulaKind` pair. Binary/range/rescale compose exactly as on the
lattice side. Expected cost: element-proportional (2 IPAs of length
r*m per family member), which meets the <20% criterion only when the
matmul inner dimension is much larger than the range width — to be
measured when implemented. Deferred with the Python mirror after the
Section 4 finding reset priorities; both are bounded, mechanical work.

## 6. Recommended next steps

1. Update the M3 plan: the FFN-block milestone should run with the
   measured Route Z gadget costs (fine at demo scale) while Route R
   becomes the explicit gate for Class 3 at scale — promote the ring
   lift from Tier 2 "design" toward the critical path.
2. Implement the pairing-track gadget family (Section 5) and measure
   its criterion ratio at FFN-like shapes.
3. Route R design spike: challenge sets, CRT-slot Hadamard, and the
   Pi1 general-A-map question, now carrying two mandates (prover 2x
   target and Class-3 viability).
