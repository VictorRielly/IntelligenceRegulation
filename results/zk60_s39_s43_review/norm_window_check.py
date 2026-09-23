"""Review of lane stages 39-43, question 2: is Shape::check_constructed exact
for every shape Shape::new builds WITHOUT a norm window override?

check_constructed re-runs Shape::new with Some(self.norm_wrho). With no
override Shape::new derives norm_wrho = 12 + bits(isqrt(1 + w*32767^2))
(shape.rs, `NORM_TN + 1 + bit_length(d_max)`); an override is refused by
ruling CS-2 below bit_length(isqrt(1 + w*32768^2) * 2^12 - 1). If the
derivation were ever below that minimum at an admitted width, a shape
Shape::new builds would be refused by its own re-check. Exact integer
arithmetic, every width 1 .. 2^20.
"""
from math import isqrt


def derived(w: int) -> int:
    return 12 + isqrt(1 + w * 32767 ** 2).bit_length()


def cs2_minimum(w: int) -> int:
    return ((isqrt(1 + w * 32768 ** 2) << 12) - 1).bit_length()


below = [w for w in range(1, 2 ** 20 + 1) if derived(w) < cs2_minimum(w)]
above = [w for w in range(1, 2 ** 20 + 1) if derived(w) > cs2_minimum(w)]
print("widths 1..2^20 where the derivation is BELOW the CS-2 minimum:", len(below), "first:", below[:5])
print("  of them at or below 16,384 (CS-5's cap):", len([w for w in below if w <= 16384]))
print("widths where the derivation is ABOVE the CS-2 minimum:", len(above))
print("VERDICT:", "exact at every admitted width" if not [w for w in below if w <= 16384] and not above else "NOT exact")
