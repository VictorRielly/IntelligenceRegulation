#!/usr/bin/env python3
"""R-2 part 1: exactness of every byte-limb range decomposition used by
hashline/src/private_attention/layout.rs::lookups.

For each pattern we compute the EXACT set of integers representable by the
declared limbs under the declared U8 lookups and compare it with the window
the note claims. "Exact" means the two sets are equal: no value inside the
window is unrepresentable, and no value outside it is representable.

The multi-limb sets are contiguous (lower limbs sweep a full byte, only the
top limb is capped), so the set is characterised by (min, max, contiguity);
contiguity is proved by construction below and spot-checked by brute force on
the small patterns.

Read-only: computes from the declared constants, touches nothing.
"""

U8 = range(256)


def limb_set(nlimbs, top_scale, offset=0):
    """The set {sum_k 256^k l_k - offset} with l_k in U8 for k < top and
    l_top in U8 with top_scale*l_top in U8.  Returned as (lo, hi, count);
    the set is the full contiguous integer interval [lo, hi] because the
    lower limbs sweep every residue mod 256^(nlimbs-1) and the top limb
    sweeps 0..=m with no gaps."""
    m = max(l for l in U8 if top_scale * l <= 255)
    lo = -offset
    hi = (m << (8 * (nlimbs - 1))) + (1 << (8 * (nlimbs - 1))) - 1 - offset
    return lo, hi, hi - lo + 1


def brute_limb_set(nlimbs, top_scale, offset=0):
    """Brute force (only used where the space is small enough)."""
    out = set()

    def rec(k, acc):
        if k == nlimbs:
            out.add(acc - offset)
            return
        for l in U8:
            if k == nlimbs - 1 and top_scale * l > 255:
                continue
            rec(k + 1, acc + (l << (8 * k)))

    rec(0, 0)
    return out


CASES = [
    # (name, nlimbs, top_scale, offset, claimed lo, claimed hi, brute?)
    ("int16 = l0+256*l1-32768   (A_XL*, A_AL*, A_X1L*; c2/c3/c4 of SC_DZC)",
     2, 1, 32768, -32768, 32767, True),
    ("norm rho,sigma: 4 limbs, 8*l3 in U8              -> [0, 2^29)",
     4, 8, 0, 0, (1 << 29) - 1, False),
    ("D,a1,a2: 3 plain byte limbs                      -> [0, 2^24)",
     3, 1, 0, 0, (1 << 24) - 1, False),
    ("requant sh=7 biased limb: l, 2l in U8, r=l-64    -> [-64, 64)",
     1, 2, 64, -64, 63, True),
    ("requant sh=6 biased limb: l, 4l in U8, r=l-32    -> [-32, 32)",
     1, 4, 32, -32, 31, True),
    ("requant sh=9 biased limb: l0, l1, 128*l1, r-256  -> [-256, 256)",
     2, 128, 256, -256, 255, True),
    ("softmax rho_s,sigma_s: l0, l1, 4*l1 in U8        -> [0, 2^14)",
     2, 4, 0, 0, (1 << 14) - 1, True),
    ("softmax p: l0, l1, 64*l1 in U8                   -> [0, 2^10)",
     2, 64, 0, 0, (1 << 10) - 1, True),
    ("plain byte (A_LIMB)                              -> [0, 256)",
     1, 1, 0, 0, 255, True),
]

ok = True
for name, n, scale, off, want_lo, want_hi, brute in CASES:
    lo, hi, count = limb_set(n, scale, off)
    same = (lo, hi) == (want_lo, want_hi)
    note = ""
    if brute:
        s = brute_limb_set(n, scale, off)
        contiguous = (min(s), max(s), len(s)) == (lo, hi, count)
        same &= contiguous and s == set(range(want_lo, want_hi + 1))
        note = " [brute-forced]"
    ok &= same
    print(f"{'EXACT    ' if same else 'NOT EXACT'} {name}{note}")
    print(f"          representable [{lo}, {hi}] ({count} values) vs claimed "
          f"[{want_lo}, {want_hi}] ({want_hi - want_lo + 1} values)")

# the sym() pattern is not a limb decomposition: v+127 in U8 AND 127-v in U8
sym = {v for v in range(-4096, 4097) if (v + 127) in U8 and (127 - v) in U8}
same = sym == set(range(-127, 128))
ok &= same
print(f"{'EXACT    ' if same else 'NOT EXACT'} sym(): v+127 in U8 and 127-v in U8  "
      f"(y,q8,k8,v8,qr8,kr8,s8,o8) [brute-forced]")
print(f"          representable [{min(sym)}, {max(sym)}] ({len(sym)} values) vs claimed "
      f"[-127, 127] (255 values)")

print()
print("ALL DECOMPOSITIONS EXACT" if ok else "AT LEAST ONE DECOMPOSITION IS NOT EXACT")
