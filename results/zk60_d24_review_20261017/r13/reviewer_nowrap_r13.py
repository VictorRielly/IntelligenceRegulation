"""D24 review R13: the reviewer's own no-wrap recount of every R13 host clause.

Each clause is an integer identity enforced in Goldilocks; it holds over Z when
the sum of the absolute values of its terms is below p. Bounds are taken over
the DECLARED classes the native validators enforce (accuracy_public.rs
Geometry::check_bounds, multiplier bits, accuracy_groups.rs folded gate <= 2^14,
accuracy_tables.rs scaled_abs, accuracy_layout.rs limb windows, derive() shift
windows, D24 norm classes), and also at the registered geometries.
Widened words are counted at |w| <= 2^15 (the two's-complement endpoint).
"""
import json
import math
import sys

P = 2**64 - 2**32 + 1
W16 = 1 << 15          # |word| <= 32768
INT8 = 127             # public weights / gains (validators refuse -128)


def bits(v):
    return math.log2(v)


def clauses(width, qw, kvw, hidden, head_dim, T, registry, stack, cn=1 << 20, tn2=8, dmax=1 << 24):
    a_scaled = 32767 * (1 << (16 if registry == "shieldstral" else 15))
    h_abs = (1 << 23) if stack == "h24" else (1 << 15)
    r_prod = 16 if stack == "h24" else 24
    c = {}
    # matmul hosts: sum_i |x_i| * 127 * m_j  +  2^s |w| + r + 2^(s-1)
    c["q/k requant (m<=32, s<=16)"] = width * W16 * INT8 * 32 + (1 << 16) * W16 + (1 << 16) + (1 << 15)
    c["v requant (m<=64, s<=16)"] = width * W16 * INT8 * 64 + (1 << 16) * W16 + (1 << 16) + (1 << 15)
    c["rope (|c|,|s|<=128, sh 7)"] = 2 * 128 * W16 + (1 << 7) * W16 + (1 << 7) + (1 << 6)
    c["score host (sum over head_dim, s<=24, int8 word)"] = head_dim * W16 * W16 + (1 << 24) * 127 + (1 << 24) + (1 << 23)
    c["pv host (P<2^13, T rows, s<=16)"] = T * (1 << 13) * W16 + (1 << 16) * W16 + (1 << 16) + (1 << 15)
    c["ao host (m<=256, s<=24)"] = qw * W16 * INT8 * 256 + (1 << 24) * W16 + (1 << 24) + (1 << 23)
    c["gate host (folded c<=2^14, G<=24, |g|<=2048)"] = width * W16 * INT8 * (1 << 14) + (1 << 24) * 2048 + (1 << 24) + (1 << 23)
    c["up host (m<=16, s=12)"] = width * W16 * INT8 * 16 + (1 << 12) * W16 + (1 << 12) + (1 << 11)
    c[f"product (|a_scaled|<={a_scaled}, R={r_prod})"] = a_scaled * W16 + (1 << r_prod) * h_abs + (1 << r_prod) + (1 << (r_prod - 1))
    c["down host (m<=64, s<=24, |h| class)"] = hidden * h_abs * INT8 * 64 + (1 << 24) * W16 + (1 << 24) + (1 << 23)
    kd = (1 << (tn2 + 1)) * dmax
    c["norm quotient (Cn<=2^20, tn'<=8, D<2^24)"] = 2 * cn * INT8 * W16 + dmax * (1 << tn2) + kd * W16 + (1 << 24)
    c["norm complement"] = (1 << 24) + (1 << 24) + 1 + kd
    c["residual adds"] = 3 * W16
    c["byte reconstructions (<=3 limbs, bias 2^23)"] = (1 << 24) + (1 << 23) + (1 << 24)
    wrho = 24
    c["softmax / DD quotient (e<=2^24 at F_P 12, P<2^13, Sum<2^24)"] = (1 << 24) * (1 << 12) + (1 << 13) * (1 << wrho) + (1 << wrho)
    c["softmax / DD complement"] = 3 * (1 << wrho)
    return {k: {"abs_bound": v, "bits": round(bits(v), 2), "below_p": v < P} for k, v in c.items()}


def main():
    out = {}
    out["class (validator maxima: width/q/kv<=4096, hidden<=16384, head_dim 128, T 512)"] = {
        reg + "/" + st: clauses(4096, 4096, 4096, 16384, 128, 512, reg, st) for reg in ["standard", "shieldstral"] for st in ["low", "h24"]}
    out["llama3-8b T512 h24 (registered geometry)"] = clauses(4096, 4096, 1024, 14336, 128, 512, "standard", "h24", cn=1 << 20, tn2=1, dmax=math.isqrt((1 << 40) + 4096 * W16 * W16))
    out["shieldstral T256 h24 (registered geometry)"] = clauses(3072, 4096, 1024, 9216, 128, 256, "shieldstral", "h24", cn=1 << 20, tn2=1, dmax=math.isqrt((1 << 40) + 3072 * W16 * W16))
    out["tinyllama T128 low (registered geometry)"] = clauses(2048, 2048, 256, 5632, 64, 128, "standard", "low", cn=1 << 20, tn2=2, dmax=math.isqrt((1 << 40) + 2048 * W16 * W16))
    worst = max((v["abs_bound"], k, name) for name, block in out.items() for sub in (block.values() if "class" in name else [block]) for k, v in sub.items())
    out["worst"] = {"clause": worst[1], "where": worst[2], "bits": round(bits(worst[0]), 2), "margin_bits_below_p": round(64 - bits(worst[0]), 2)}
    json.dump(out, open(sys.argv[1], "w"), indent=1)
    print(json.dumps(out["worst"]))
    for name, block in out.items():
        if name == "worst":
            continue
        subs = block.items() if "class" in name else [("", block)]
        for sname, sub in subs:
            top = max(sub.items(), key=lambda kv: kv[1]["abs_bound"])
            print(f"{name} {sname}: max {top[0]} 2^{top[1]['bits']}; all below p: {all(v['below_p'] for v in sub.values())}")


if __name__ == "__main__":
    main()
