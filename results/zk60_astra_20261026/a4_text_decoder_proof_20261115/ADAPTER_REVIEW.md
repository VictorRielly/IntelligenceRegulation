# Decoder witness conversion: bounded preflight passes

The fixed six-step batch compiled the conversion helpers, passed eight unit
tests, compiled the fixture checker and checked black, white and coordinates.
Original tool session 37364 exited zero. Sources, binaries and fixtures were
authenticated before and after execution (31 pins); all 1,011 files in frozen
P/Q/R/S packages were rehashed unchanged. The combined parent/child RSS upper
bound was 520,355,840 bytes. No additional host approval was requested.

Evidence: [batch result](adapter_attempts/20261115T181136.336469Z/RESULT.json),
[audit](ADAPTER_AUDIT.json), [conversion code](adapter.rs),
[fixture checker](check_adapter.rs), [fixed runner](validate_adapter.py).
The implementing agent performed this review; it is not independent review.

Across the three cases the checker validates:

| Conversion/check | Coordinates |
|---|---:|
| Both normalization remainder conversions | 2,746,368 |
| Symmetric I16 encodings across eight roles | 9,612,288 |
| Grouped gate common denominator | 4,119,552 |
| Aligned activation/product denominator | 4,119,552 |
| Real causal exp/probability representation | 2,131,296 |
| Exp lookup over the padded score squares | 6,291,456 |
| Data carry and zero padding across 17 planes | 84,148,224 |

These counts overlap; they are not additional independent decoder executions.
The checker reads the 72 authenticated reference planes and validates the
representation changes. Q already qualified the original native arithmetic
against those references; this batch does not recompute all seven matrix
products or run the existing R13 witness builder.

For normalization, the full allowed residual class implies
`ss <= 3072*32768^2+2439`, hence `4*floor(sqrt(ss)) < 2^23`. Reduced
remainders therefore fit 23 bits, even though the legacy encoding allows 24;
the exact `rho_ref=256*rho` and `sigma_ref=256*sigma+255` translations fit the
original 31-bit window. This bound is over the allowed class, not observed
fixture extrema. Root-gap equations and both remainder relations are checked.

The proposed strict signed encoding keeps the existing unsigned-16 lookup
of `q+32768` and adds one for `q+32767`, with both reconstruction identities.
Together these exclude -32768 and permit exactly [-32767,32767]. The helper
tests exhaust the adjacent signed range and reject a scalar-consistent norm
witness at the excluded endpoint. In the byte-based proof, each added U16
encoding needs two byte limbs, their lookups and the reconstruction equation.
These constraints must still be integrated into the actual verifier.

The first layer uses common gate shift 19 and maps its native product shift
8 to the legacy aligned shift 16. Power-of-two conversion preserves the
quotient, scales rho, and applies the corresponding affine sigma adjustment;
denominator reduction refuses inexact conversions. Literal activation values
and the resulting product accumulator agree at every real coordinate.

Legacy exp witnesses remain defined outside real causal support. In
particular padded rows have E=table[0] below/on their diagonal and
E=table[127] above it. They must not be indiscriminately zero padded. The
masked reference exp remains zero on future real coordinates; full-square
scores, causal maxima, sums, probability quotients and complements are checked.
Data planes separately retain 149 real rows, T256 padding and channel padding.

Next: integrate these relations into a distinct 149-real/T256 development
profile in an isolated source copy, compare its actual witness builder, and
prepare a complete first-layer serialized proof and forged-receipt batch.
No committed decoder proof has run. All-26-layer proof, classifier proof,
composition with P, task quality, independent soundness/privacy and Lean
production obligations remain open. The existing source profiles are unchanged.
