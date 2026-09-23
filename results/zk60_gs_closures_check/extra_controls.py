"""Extra controls for clauses the memo's 26 controls do not exercise (scratch, read-only inputs)."""
import copy
import sys

sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_gs_closures")
sys.dont_write_bytecode = True
import gs4_audit_replay as g  # noqa: E402

d = f"{g.ART}/block-captures-20260923/m125-dense"
shape, roles, bnds = g.roles_of(d, "block")
by = {(r["commitment_kind"], r["role"]): (s, r) for s, r in roles}
stA, A = by[("block", "A")]
stH, H = by[("block", "H")]
stE, E = by[("external-endpoint", "Input")]
n = 1 << A["params"]["log_cols"]


def refusal(stage, role, mut):
    r2 = copy.deepcopy(role)
    mut(r2)
    return g.check_role(shape, stage, r2, bnds)["refusal"]


def masks(r, ci):
    return [p for p in r["claims"][ci]["parts"] if p["offset"] // n >= r["data_rows"]]


out = {}
# eval claim with NO mask part (touched 0)
out["eval_unmasked"] = refusal(stA, A, lambda r: r["claims"][0].__setitem__("parts", [p for p in r["claims"][0]["parts"] if p["offset"] // n < r["data_rows"]]))
# eval claim with ONE mask part (touched 1)
def one(r):
    m = masks(r, 0)
    r["claims"][0]["parts"].remove(m[1])
out["eval_one_site_row"] = refusal(stA, A, one)
# eval claim with THREE site rows (claim 1's first mask part appended to claim 0)
def three(r):
    m1 = masks(r, 1)
    r["claims"][0]["parts"].append(copy.deepcopy(m1[0]))
out["eval_three_site_rows"] = refusal(stA, A, three)
# data part reaching the proximity pair
def dprox(r):
    dp = [p for p in r["claims"][0]["parts"] if p["offset"] // n < r["data_rows"]][0]
    dp["offset"] = r["prox_row"] * n
out["data_part_on_prox"] = refusal(stA, A, dprox)
# a part leaving the commitment
def leave(r):
    masks(r, 0)[1]["offset"] = (r["commitment"]["rows"] + 3) * n
out["part_leaves_commitment"] = refusal(stA, A, leave)
# unused reserved pair without sharing (drop the last claim of A)
out["unused_pair_no_sharing"] = refusal(stA, A, lambda r: r["claims"].pop())
# sum claim touching a reserved row
def sum_touch(r):
    s = r["claims"][-1]
    p = copy.deepcopy(s["parts"][0])
    p["offset"] = r["site_rows"][0] * n
    s["parts"].append(p)
out["sum_claim_touches_site_row"] = refusal(stH, H, sum_touch)
# sum claim not covering u[1]
def sum_nocover(r):
    s = r["claims"][-1]
    u1 = r["sum_rows"][1]
    s["parts"] = [p for p in s["parts"] if u1 not in g.part_rows(p, n)]
out["sum_claim_misses_u1"] = refusal(stH, H, sum_nocover)
# a sum claim on A (sum_rows None)
def sum_on_a(r):
    r["claims"].append(copy.deepcopy(H["claims"][-1]))
out["sum_claim_on_A"] = refusal(stA, A, sum_on_a)
# claim parts with different column weights
def diffkey(r):
    r["claims"][0]["parts"][-1]["point"] = r["claims"][0]["parts"][-1]["point"][:-1] + [[1, 2]]
out["parts_different_column_weights"] = refusal(stA, A, diffkey)
# endpoint: zero coefficient; two claims
out["endpoint_zero_coef"] = refusal(stE, E, lambda r: r["claims"][0]["parts"][1].__setitem__("coefficient", [0, 0]))
out["endpoint_two_claims"] = refusal(stE, E, lambda r: r["claims"].append(copy.deepcopy(r["claims"][0])))
# pair at non-adjacent rows (claim 0's second mask part moved to claim 1's second row)
def nonadj(r):
    m0, m1 = masks(r, 0), masks(r, 1)
    m0[1]["offset"] = m1[1]["offset"]
out["eval_nonadjacent_pair"] = refusal(stA, A, nonadj)
for k, v in out.items():
    print(f"{k:34s} {v}")
