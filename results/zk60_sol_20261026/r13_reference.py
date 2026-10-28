#!/usr/bin/env python3
"""Exact scalar R13 reference and portable vectors from S2_BUILD_SPEC.json.

Public synthetic arithmetic only; no native proof or fidelity measurement.
Use rational arithmetic as an independent oracle for Rust scalar tests.
"""
from fractions import Fraction
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent


def rounded(value):
    """Nearest integer, half ties toward positive infinity (fp_lib._rnd)."""
    value = Fraction(value) + Fraction(1, 2)
    return value.numerator // value.denominator


def requant(accumulator, multiplier, shift):
    assert multiplier >= 1 and shift >= 0
    return rounded(Fraction(accumulator * multiplier, 1 << shift))


def product(a, up, shift_h, output_exponent_delta):
    """Keep h in common layer units; scale a BEFORE rounding its product.

    `a` is the integer table output in the group's units. Delta is
    e_out_group - e_out_layer. h shift is the final sh_h (base minus 8).
    Moving this factor into Wd after rounding is not equivalent in general.
    """
    return rounded(Fraction(a * up) * Fraction(2) ** (output_exponent_delta - shift_h))


def main():
    vectors = []
    for bits in (4, 5, 6, 8):
        for shift in (bits + 5, bits + 8, bits + 16):
            for multiplier in (1, (1 << bits) - 1, 1 << bits):
                for acc in (-((1 << 39) - 1), -257, -128, -1, 0, 1, 127, 256, (1 << 39) - 1):
                    expected = requant(acc, multiplier, shift)
                    # Independent integer formulation of the rational result.
                    assert expected == (acc * multiplier + (1 << (shift - 1))) // (1 << shift)
                    vectors.append((acc, multiplier, shift, expected))
    (OUT / 'r13_requant_vectors.tsv').write_text(''.join('\t'.join(map(str, row)) + '\n' for row in vectors))
    products = []
    for delta in range(-4, 5):
        for shift in range(5, 9):
            for a, up in [(-32767, -32768), (-17, 31), (-1, 16), (0, 32767), (1, 16), (32767, 32767)]:
                products.append((a, up, shift, delta, product(a, up, shift, delta)))
    (OUT / 'r13_product_vectors.tsv').write_text(''.join('\t'.join(map(str, row)) + '\n' for row in products))
    # A concrete reason the group output scale cannot be moved past h rounding.
    common = product(1, 16, 5, -1)
    after_rounding = Fraction(requant(16, 1, 5), 2)
    assert common == 0 and after_rounding == Fraction(1, 2)
    report = {'scope': 'COUNTED exact public scalar vectors; not a proof or fidelity claim',
              'requant_vectors': len(vectors), 'product_vectors': len(products),
              'group_scale_rounding_counterexample': {'a': 1, 'up': 16, 'shift_h': 5,
                  'output_exponent_delta': -1, 'common_units_rounded_product': common,
                  'scale_applied_after_product_rounding': str(after_rounding)},
              'sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in [OUT / 'r13_requant_vectors.tsv', OUT / 'r13_product_vectors.tsv']}}
    (OUT / 'r13_reference.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
