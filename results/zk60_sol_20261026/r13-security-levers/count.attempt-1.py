"""R13 N-r13-1: conditional costed >=95-bit options at unregistered 8B T512.

No new security ruling, implementation, native profile or throughput estimate.
Paired-byte repetition needs review of the partitioned nonzero-residue bound.
"""
from collections import Counter
from pathlib import Path
import hashlib
import json
import math

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
R13 = ROOT / "results/zk60_1b_native_20261017/r13"
ROLES = ROOT / "results/zk60_1b_native_20261017/s4-split-width/s4-native-role-census.log"
P = 2**64 - 2**32 + 1
FIELD = P * P
BLOCKS = 32


def native_roles(dd, ls):
    rows = [s.split(",") for s in ROLES.read_text().splitlines()]
    rows = [r for r in rows if r[1:3] == [str(dd).lower(), str(ls)]]
    a = Counter(r[4] for r in rows if r[0] == "ROLE")
    lk = {r[3]: int(r[4]) for r in rows if r[0] == "LOOKUPS"}
    h = {d: (n + 1) // 2 for d, n in lk.items() if n}
    h["S"] += 1 + int(dd)
    h["F"] += 1
    h["Tab"] = 4
    if dd:
        h["Dd"] += 1
    return a, h, lk


def geometry(t, n, dd):
    ls = (t.bit_length() - 1 + 9 + 7) // 8
    a, h, lk = native_roles(dd, ls)
    size = {"T": t, "Ht": 32*t, "L": n, "D": t*4096, "Q": t*4096,
            "Kv": t*1024, "F": t*16384, "S": 32*t*t, "Tab": n}
    if dd:
        size["Dd"] = 32*t*32
    rows = lambda counts: sum(k * max(1, size[d]//n) for d, k in counts.items())
    a_sites = (149 if dd else 146) + 2*(ls-2)
    h_sites = (55 if dd else 53) + ls-2
    adata, hdata = rows(a), 2*rows(h)
    N = sum(size[d]*k for d, k in lk.items()) + size["S"] + size["F"] + (size["S"] if dd else 0)
    Td = 512 + 4096*4 + (size["Dd"] if dd else 0)
    return {"T": t, "n": n, "dd": dd, "a_data_rows": adata, "h_data_rows": hdata,
            "a_sites": a_sites, "h_sites": h_sites, "a_rows": adata+2*a_sites+2,
            "h_rows": hdata+2*h_sites+2, "lookups": lk, "size": size, "N": N, "Td": Td}


def terms(g, q, rate, protected=0, pair_sites=0):
    n = g["n"]
    # Q = MQ here: both PCS and mask-opening query counts are profile levers.
    ahbe_col = (3*BLOCKS+1) * (1-(1-(n+q)/(n*rate))/3)**q
    m_col = BLOCKS * .75**q
    # Conservative field/composition ceilings: <=4096 claim/functionals per
    # opening and <=8192 SC error units per block; native census must confirm.
    e = (n*rate-(n+q))//3
    pcs = ((3*BLOCKS+1)*(e+1+4096) + BLOCKS*(1025+4096))/FIELD
    sc = BLOCKS*8192/FIELD
    numerator = g["N"] + 4*g["Td"] - 1
    # Conditional partition argument: if protected bytes are valid, their
    # poles collapse into the existing public U8 table. If they are invalid,
    # both independent challenge identities must fail. New histograms are
    # committed in A before either challenge. Do not infer a ruling from this.
    lookup = BLOCKS*((g["N"]-protected+4*g["Td"]-1)/FIELD
                     + (numerator/FIELD)*(2*(protected+256)/FIELD)) if protected else BLOCKS*numerator/FIELD
    total = ahbe_col+m_col+pcs+sc+lookup
    return {"column_error": ahbe_col+m_col, "pcs_field_error": pcs, "sumcheck_error": sc,
            "lookup_error": lookup, "whole_error": total, "whole_bits": -math.log2(total),
            "lookup_bits": -math.log2(lookup), "column_bits": -math.log2(ahbe_col+m_col)}


def choices(g):
    # Protect entire existing paired-byte helper columns. Never choose a
    # private/data-dependent position subset. One item is one H inverse-pair
    # plane; odd singleton helpers are excluded from this first cost search.
    items = [(d, k, 2*g["size"][d]) for d, count in g["lookups"].items()
             for k in range(count//2)]
    dp = {0: ()}
    for d, k, queries in items:
        for old, selected in list(dp.items()):
            new = old + queries
            pick = selected + ((d, k),)
            if new not in dp or len(pick) < len(dp[new]):
                dp[new] = pick
    return dp


def price(g, q, rate, protected, selected):
    n = g["n"]
    k = len(selected)
    # One new U8 histogram in A, one U8 table helper and one zero-sum mask
    # in H. Each new logical H table gets its own site/pair. A separate ZS
    # slot closes the new zero-sum mask, avoiding an uncosted identity batch.
    extra_a = 3*n
    extra_h = protected + (2*k+8)*n
    extra_words = extra_a+extra_h
    baseline = (g["a_rows"]+g["h_rows"])*n
    extra_m = 1024  # one new CFS slot, two 512-word base rows
    encoded_ratio = ((baseline+extra_words)*rate)/(baseline*4)
    # Incremental flat receipt upper model: added rows, one new H group,
    # Q-related existing columns/vectors, endpoint/boundary Q cost, M rows,
    # one new slot/terminal block. It is not a final native wire census.
    new_rows = extra_words//n
    ah_cols = q*8*new_rows + (q-256)*8*(g["a_rows"]+g["h_rows"])
    h_vector = (n+q)*16
    old_group_cap = g["a_sites"]+g["h_sites"]+3
    old_vectors = max(0,q-256)*16*old_group_cap
    tree_path = int(math.log2(n*rate))
    path_delta = 2*(q*(40+32*tree_path)-256*(40+32*17))
    m_extra = q*2*8 + max(0,q-256)*(8+(52 if g["dd"] else 50)*8+32+12*32)
    slot_cap = 16384  # generous slot/terminal count allowance, to be replaced by native IR
    boundaries = max(0,q-256)*((BLOCKS-1)*(70*8+40+17*32+3*16)+2*(69*8+40+17*32+2*16))/BLOCKS
    delta_bytes = ah_cols+h_vector+old_vectors+path_delta+m_extra+slot_cap+boundaries
    result = terms(g,q,rate,protected,k)
    return {"dd": g["dd"], "Q_and_MQ": q, "inv_rate": rate,
            "protected_byte_queries": protected, "paired_helper_planes_repeated": k,
            "selected_native_byte_helper_pairs": [{"domain":d,"pair_index":i} for d,i in selected],
            "extra_a_h_base_words": extra_words, "extra_m_base_words": extra_m,
            "a_h_committed_increase_percent": 100*extra_words/baseline,
            "a_h_encoded_work_increase_percent": 100*(encoded_ratio-1),
            "extra_receipt_mib_per_block_upper_model": delta_bytes/2**20,
            "extra_receipt_mib_32_block_upper_model": delta_bytes*BLOCKS/2**20,
            "whole_bits_conditional": result["whole_bits"], "lookup_bits_conditional": result["lookup_bits"],
            "column_bits": result["column_bits"],
            "scope": "COUNTED/MODEL proposed paired-byte repetition; soundness partition and native schedule require independent review"}


def main():
    census = json.loads((R13/"NATIVE_LAYOUT_CENSUS.json").read_text())["rows"]
    anchor_checks = 0
    for t,n in [(128,16384),(256,32768)]:
        for dd in [False,True]:
            g=geometry(t,n,dd)
            old=next(r for r in census if r["width"]==3072 and r["tokens"]==t and r["f_e"]==9 and r["groups"]==4 and r["dd"]==dd)
            for key in ["a_rows","h_rows","a_sites","h_sites"]: assert g[key]==old[key],(key,g[key],old[key])
            assert g["N"]+g["Td"]==old["lookup_positions"]
            anchor_checks += 1
    output=[]
    for dd in [False,True]:
        g=geometry(512,32768,dd); dp=choices(g)
        baseline=terms(g,256,4)
        best=[]
        for rate in [4,8,16]:
            for q in range(256,289):
                passing=[]
                # Select the least committed data at each Q/rate, retaining a
                # numerical margin so float printing cannot flip the policy.
                for protected,selected in dp.items():
                    if protected and terms(g,q,rate,protected,len(selected))["whole_bits"]>=95.0001:
                        passing.append((protected+(2*len(selected)+11)*g["n"],protected,selected))
                if passing:
                    _,protected,selected=min(passing,key=lambda x:(x[0],len(x[2])))
                    best.append(price(g,q,rate,protected,selected))
        cheapest=min(best,key=lambda r:(r["a_h_encoded_work_increase_percent"],r["extra_receipt_mib_32_block_upper_model"]))
        no_query_change=min((r for r in best if r["Q_and_MQ"]==256 and r["inv_rate"]==4),key=lambda r:r["extra_a_h_base_words"])
        margin=min((r for r in best if r["whole_bits_conditional"]>=95.05 and r["inv_rate"]==4),key=lambda r:(r["a_h_encoded_work_increase_percent"],r["extra_receipt_mib_32_block_upper_model"]))
        queries_only=[{"Q_and_MQ":q,"inv_rate":rate,"whole_bits":terms(g,q,rate)["whole_bits"]}
                      for q,rate in [(256,4),(272,4),(288,4),(256,8),(288,8),(288,16)]]
        assert all(r["whole_bits"]<95 for r in queries_only)
        output.append({"dd":dd,"geometry":g,"baseline":baseline,"queries_or_rate_only":queries_only,
                       "cheapest_encoded_data_candidate":cheapest,"no_query_change_candidate":no_query_change,
                       "margin_candidate":margin,"all_best_per_parameter":best})
    report={"status":"N-r13-1 count for later ruling; no profile implemented/registered",
            "workload":"Llama-3-8B T512,32blocks,LOW+h24,F_E9,4ACTgroups,N32768",
            "native_baselines_reproduced":anchor_checks,"rows":output,
            "important":"Partial byte repetition/partition bound is a proposed adaptation of the earlier G02 design, not accepted R13 security. Native census, privacy and soundness review remain mandatory.",
            "field_extension_comparison":{"Fp4_lookup_only":"At least doubles H helper data (4 base components vs2); requires new arithmetic/masks and review. More committed data than the selected partial-repetition candidates.",
                                          "Fp3_lookup_components":"Potentially +50% H data and3 component constraints at Fp2 SC points, with new global aggregation/rank obligations. It is a separate unimplemented field design; not a proven cheap drop-in and not needed for this95 target.",
                                          "full_extension":"Widening all challenges also widens SC/PCS messages and masks; broader and more expensive than the partial-repetition candidate. No timing claim."},
            "limitations":["Not a throughput benchmark; encoded word volume is a cost proxy, not tokens/s",
                           "Receipt delta is an upper model, not native wire count",
                           "Q and MQ are separate bound profile parameters; raising PCS Q alone leaves M's column term",
                           "No security tier or 8B T512 registration before the security-owner ruling and independent review"]}
    (HERE/"COUNT.json").write_text(json.dumps(report,indent=2)+"\n")
    (HERE/"SOURCE_PINS.json").write_text(json.dumps({str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROLES,R13/"NATIVE_LAYOUT_CENSUS.json",ROOT/"results/zk60_soundness_recount_20261017/g02_levers.py",ROOT/"results/zk60_d24_review_20261017/r13/reviewer_bits_r13.py"]},indent=2)+"\n")
    print(json.dumps([{ "dd":r["dd"],"baseline_whole_bits":r["baseline"]["whole_bits"],
                       "cheapest":r["cheapest_encoded_data_candidate"],"q256":r["no_query_change_candidate"],
                       "margin":r["margin_candidate"]} for r in output]))


if __name__=="__main__":main()
