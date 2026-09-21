"""Three small counted checks the memo's findings turn on.

(1) The `zeta` / `mu_pad` draw count per proof -- the memo's correction of
    ruling R-7's "<= 7".
(2) The degree-rise cost the memo prices at 105 / 107 / 126 extra Fp2, split
    into the part the closure's degree actually needs and the part it does
    not (see degree_maxplus.py).
(3) Two shape cliffs the memo does not name, decided rather than argued:
    (a) slots 15/16's flipped RoPE partner raises a SECOND claim on the SAME
        plane; its PCS column key separates from the first only if the
        flipped coordinate falls inside the claim point's tail, i.e. only if
        log2(head_dim) <= log_cols;
    (b) `argument.rs:1449-1451` refuses slot 17 whenever
        `zero_rule_a_planes(Dom::Ht) != [A_MX, A_SUM]`, which is what a shape
        where Dom::S pads and Dom::Ht does not would produce -- is such a
        shape constructible?
"""
import json
import os

LANE = "/home/victor/wt-zk60-block125m/results/zk60_block125m_lane"
PAD_HOST = {"T": 2, "Ht": 17, "L": 3, "D": 14, "Q": 15, "Kv": 16, "S": 17, "F": 18, "Tab": 19}
IND = {0: "D", 1: "D", 4: "S", 14: "D", 15: "Q", 16: "Kv", 17: "S", 18: "F"}
# the four slots whose declared degree rises but whose closure's does not
OVER = {14, 15, 16, 18}


def main():
    out = {}
    for name in ("toy", "rung_g", "rung_k4", "m125"):
        m = json.load(open(f"{LANE}/model_{name}.json"))
        padded = set(m["padded_domains"]) if name != "toy" else set()
        hosts = sorted({PAD_HOST[d] for d in padded})
        N = {s["slot"]: s["main_rounds"] + s["extension_rounds"] for s in m["slots"]}
        rise = [s for s, d in IND.items() if d in padded]
        need = [s for s in rise if s not in OVER]
        waste = [s for s in rise if s in OVER]
        out[name] = {
            "padded_domains": sorted(padded),
            "pad_zero_hosting_slots": hosts,
            "zeta_draws_per_proof": len(hosts),
            "mu_pad_entries_per_proof": len(hosts),
            "indicator_degree_rise_slots": sorted(rise),
            "degree_rise_cost_fp2": sum(N[s] for s in rise),
            "of_which_the_closure_needs": sum(N[s] for s in need),
            "of_which_buys_nothing": sum(N[s] for s in waste),
            "wasted_bytes_per_block": 16 * sum(N[s] for s in waste),
        }

    # (3a) the flipped partner's key separation
    cliffs = []
    for name in ("rung_g", "rung_k4", "m125"):
        m = json.load(open(f"{LANE}/model_{name}.json"))
        sh = m["shape"]
        ldh = (sh["head_dim"] - 1).bit_length()
        lc = sh["log_cols"]
        cliffs.append({"shape": name, "log2_head_dim": ldh, "log_cols": lc,
                       "flip_inside_the_claim_tail": ldh <= lc,
                       "margin_to_the_cliff": lc - ldh,
                       "ruling_S3_refuses_at": f"head_dim >= 2^{lc}",
                       "this_cliff_would_bite_at": f"head_dim > 2^{lc}",
                       "covered_by_S3": True})
    out["flip_partner_key_separation"] = cliffs

    # (3b) can Dom::S pad while Dom::Ht does not?
    #   Ht pads  <=>  h_pad*t_pad != q_heads*tokens
    #   S  pads  <=>  size(S) != q_heads*tokens^2, where size(S) is the P-3
    #                 lifted 2^max(clog2(h_pad*t_pad^2), log_cols)
    #   ruling F-2 (shape.rs:252-260) refuses ANY shape whose Dom::S is
    #   lifted, so under F-2 size(S) = h_pad*t_pad^2 and, since t_pad >= tokens
    #   and h_pad >= q_heads, h_pad*t_pad == q_heads*tokens forces
    #   (h_pad, t_pad) == (q_heads, tokens) and hence S unpadded too.
    scan = []
    for q in (1, 2, 4, 6, 12):
        for hp in (1, 2, 4, 8, 16):
            for tok in (8, 24, 32, 512):
                for tp in (8, 16, 32, 64, 512, 1024):
                    if hp < q or tp < tok:
                        continue
                    for lc in (8, 10, 14):
                        s_nat = (hp * tp * tp - 1).bit_length()
                        lifted = s_nat < lc
                        if lifted:
                            continue          # refused by ruling F-2
                        ht_pads = hp * tp != q * tok
                        s_pads = (1 << s_nat) != q * tok * tok
                        if s_pads and not ht_pads:
                            scan.append({"q_heads": q, "h_pad": hp, "tokens": tok,
                                         "t_pad": tp, "log_cols": lc})
    out["shapes_where_S_pads_but_Ht_does_not"] = {
        "searched": "q_heads x h_pad x tokens x t_pad x log_cols, F-2-legal only",
        "found": scan,
        "conclusion": ("none: under ruling F-2 (no P-3 lift of Dom::S) "
                       "Dom::Ht pads if and only if Dom::S does, so the "
                       "refusal at argument.rs:1449-1451 is unreachable"),
    }

    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "counts_and_cliffs.json")
    json.dump(out, open(p, "w"), indent=1)
    for k in ("toy", "rung_g", "rung_k4", "m125"):
        v = out[k]
        print(f"[COUNTED] {k:8s} pad-zero hosts {v['pad_zero_hosting_slots']} "
              f"-> {v['zeta_draws_per_proof']} zeta + {v['mu_pad_entries_per_proof']} mu_pad; "
              f"degree rise {v['degree_rise_cost_fp2']} Fp2 "
              f"(needed {v['of_which_the_closure_needs']}, "
              f"wasted {v['of_which_buys_nothing']} = {v['wasted_bytes_per_block']} B)")
    for c in out["flip_partner_key_separation"]:
        print(f"[COMPUTED] flip key separation {c['shape']:7s} log2(head_dim)={c['log2_head_dim']} "
              f"<= log_cols={c['log_cols']}: {c['flip_inside_the_claim_tail']} "
              f"(margin {c['margin_to_the_cliff']})")
    print(f"[COMPUTED] shapes where Dom::S pads and Dom::Ht does not, among "
          f"F-2-legal geometries: {len(scan)}")


if __name__ == "__main__":
    main()
