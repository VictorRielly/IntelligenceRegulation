#!/usr/bin/env python3
"""Tick 72 (item 112): why the census shows 2,501 / 2,602 rows and the harness traces 2,504 / 2,606.

Reimplements, from the code that runs (ops/zkp-mvp/gpu-metal/hashline/src/private_block/), only the part that
fixes the number of Dom::Tab range sub-planes, then the rows they add. Every constant is cited. Nothing is run
from the prover.

  accuracy_precision.rs:55-98   derive(LowH24, base)            -> Precision
  range16.rs:164-196            widths(stack, p, gate_shift, wrho_s)
  range16.rs:198-212            families(): sub = max(1, 2^width >> log_cols)
  layout.rs:67                  SH_ROPE = 7
  shape.rs:2482                 A Tab planes = 3 + sub_planes ; shape.rs:2587  H Tab planes = 4 + sub_planes
  accuracy_groups.rs:48,50      gate_shift = max over groups of (base_sh_g + 10 + e_in - base_e_in), at least 17
  range16_tests.rs:19-20, 36-37 census: Shape::accuracy_trained(profile, cal, fe, gate_shift = 20)
                                harness : case(original, 3) then with_accuracy_gate_shift(data.folds().gate.shift)
"""
LOG_COLS = 14
SH_ROPE = 7


def derive_lowh24(norm_tn, qkv, score, pv, ao, gate, up, product, down):
    """accuracy_precision.rs:71-96 for Stack::LowH24 (h_extra = 8)."""
    h_extra = 8
    return dict(
        q=qkv + 7, k=qkv + 7, v=qkv + 8, score=score + 12, pv=pv + 3, ao=ao + 14,
        gate=gate + 10, up=up + 12, product=product - h_extra, down=down + 6 + h_extra, f_p=12,
    )


def widths(p, gate_shift, wrho_s):
    """range16.rs:164-196, Stack::LowH24."""
    w = [16]

    def rem(bits):
        if bits <= 16:
            w.append(bits)
        else:
            w.append(16)
            w.append(bits - 16)

    rem(24)
    rem(p["ao"])
    rem(p["down"])
    for bits in [p["q"], SH_ROPE, p["pv"], p["k"], p["v"], SH_ROPE]:
        rem(bits)
    rem(gate_shift)
    rem(p["up"])
    rem(16)  # h24
    rem(p["score"])
    rem(p["f_p"] + 1)
    rem(wrho_s)
    return sorted(set(x for x in w if x != 8))


def subs(ws):
    return sum(max(1, (1 << x) >> LOG_COLS) for x in ws)


# The calibration both tests use (range16_tests.rs:13-15; slot_ir_accuracy.rs:1813): tn 9 at width >= 3072, sh_qkv 8,
# sh_s 6, sh_o 9, sh_g 8, sh_h 14, sh_z 6, sh_ao 7. BaseShifts mapping as in accuracy_precision.rs tests (BASE):
# norm_tn, qkv, score, pv(=sh_o), ao, gate(=sh_g), up 0, product(=sh_h), down(=sh_z).
p = derive_lowh24(norm_tn=9, qkv=8, score=6, pv=9, ao=7, gate=8, up=0, product=14, down=6)
print("precision (LowH24):", p)
# wrho_s = clog2(T) + f_e for T = 128, f_e = 9 (range16_tests.rs:19 fe = 9 for tokens 128): 7 + 9 = 16
WRHO_S = 7 + 9

print("\nrange widths and Tab planes by common gate shift (A planes = 3 + subs, H planes = 4 + subs):")
print(" gate_shift  widths                              subs  A_tab  H_tab")
rows = {}
for g in range(17, 25):
    ws = widths(p, g, WRHO_S)
    rows[g] = subs(ws)
    print(f"   {g:>2}        {str(ws):<36}{rows[g]:>4}   {3 + rows[g]:>4}   {4 + rows[g]:>4}")

# The harness's gate shift: group_folds_for, base_sh_g = 8, base member (e_in, e_out) = (-3, -11) (range16_tests.rs:39),
# groups e_in -4, -3, -2, -1 (range16_tests.rs:37), the first ng of them.
print("\nharness gate shift = max(17, 8 + 10 + e_in - (-3)) over the first ng groups:")
E_IN = [-4, -3, -2, -1]
for ng in (1, 2, 3, 4):
    g = max(17, max(8 + 10 + e + 3 for e in E_IN[:ng]))
    print(f"  ng = {ng}: gate shift {g}, Tab sub-planes {rows[g]}")
gh = max(17, max(8 + 10 + e + 3 for e in E_IN[:3]))
gc = 20  # range16_tests.rs:20, `accuracy_trained(..., 20)`

# Rows: layout.rs:1340-1353 (cited by the coordinator): rows = data rows + 2 per site + 2.
# A census: 2,279 data rows, 110 sites at 15 Tab planes; H census: 2,514 data rows, 43 helper sites at 16 Tab planes.
# One more width = one more Tab plane in A (1 data row) and its site pair (2 rows): +3; in H the plane and its helper (+1 data
# row, +1 site, 2 rows for the site) -> coordinator's check: +4 rows (one helper and one site pair).
a_census = 2279 + 2 * 110 + 2
h_census = 2514 + 2 * 43 + 2
print(f"\ncensus rows (gate shift {gc}, {3 + rows[gc]} A Tab planes): A {a_census}, H {h_census}")
d = rows[gh] - rows[gc]
print(f"harness (gate shift {gh}): {d} more Tab sub-plane -> A {a_census + 3 * d}, H {h_census + 4 * d}")
assert (a_census, h_census) == (2501, 2602)
assert (a_census + 3 * d, h_census + 4 * d) == (2504, 2606)
assert (3 + rows[gc], 4 + rows[gc]) == (15, 16)       # census.log:218-236
assert (3 + rows[gh], 4 + rows[gh]) == (16, 17)       # coordinator's read of the traced profile
print("\nAll asserts hold: census = gate shift 20 (width 20-16 = 4 equals the down projection's 20-16 = 4, one width"
      "\nless after dedup), harness = gate shift 19 from three groups (width 3, a new family).")
