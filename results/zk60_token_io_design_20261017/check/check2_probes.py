"""Pass-2 probes of the token I/O design v2 and its rung R0 (paper + one-thread Python, < 1 s).

Imports R0's reference (`../r0/token_io_ref.py`) and its model builder READ-ONLY (no bytecode is
written; nothing under ../ is written; `token_io_vectors.main()` is never called). Writes
`check2_probes.json` beside itself. Every probe is a tamper class this check found missing from
R0's vectors, run against R0's own checkers where they exist, or against a small helper-level model
of the native relation written here where R0 has no checker for it.

  T1  A6 is load-bearing: e one-hot at a NON-maximal j, M = max + 1, every delta in six bytes
  T2  e's pad-zero is load-bearing: e at a PADDED vocabulary entry, tok = that entry, M = max + 1
  T3  tok differs from the selected index (A3)
  T4  BOS clause written as an UNWEIGHTED addend of the query zero-check (helper-level model):
      tok_0 = BOS + 1, h_q(0) = 0 drops position 0 from the LogUp; a fresh coefficient rejects it
  T5  final-norm forged witnesses (R0 has the checker, no vectors): y off by one, D off by one,
      the D16 field alias, y outside int8 with in-window remainders
  T6  position selector s not one-hot (R0's V05 covers e only)
  T7  B-2 verifier half: sealed s = e_{P-1} (owner check passes) but stage OUT uses e_0
  T8  IO-in: a consistent re-lookup (tok_t := v', x_t := E[v'], m adjusted) under an honest seal
  T9  IO-out: the output plane seals a different id than the argmax
"""
import json
import os
import random
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
R0 = os.path.join(os.path.dirname(HERE), "r0")
sys.path.insert(0, R0)
import token_io_ref as R          # noqa: E402
import token_io_vectors as TV     # noqa: E402  (model() only; main() is never called)

P = R.P
OUT = {}
E, W = TV.model()
V, Vp, T = TV.V, R.npow2(TV.V), TV.T
v = R.clog2(Vp)
rng = random.Random(4242)
prompt = [R.BOS] + [rng.randrange(3, V) for _ in range(4)]
P_len = len(prompt)
tokens = prompt + [TV.PAD_ID] * (T - P_len)
x_in = R.embed(tokens, E, V)
x_out = R.stand_in_stack(x_in)
s_hon = R.selector(P_len, T)
tok, tr = R.next_token(x_out, s_hon, TV.G0, TV.CN_SAFE, TV.TN, TV.CEPS, W)
l = tr["logits"]
order = sorted(range(V), key=lambda i: (-l[i], i))


def limbs_of(delta):
    return [[(d >> (8 * k)) & 0xFF for d in delta] for k in range(R.DELTA_LIMBS)]


def a1_to_a5_only(l, wit, V):
    """R0's check_argmax with A6 removed (to show which relation is the catching one)"""
    e, lim, tk, M = wit["e"], wit["limbs"], wit["tok"], wit["M"]
    lf = list(l[:V]) + [0] * (Vp - V)
    if any((x * (1 - x)) % P for x in e) or any(not (0 <= lim[k][i] < 256) for k in range(6) for i in range(Vp)):
        return False
    if sum(e) % P != 1 or (tk - sum(i * e[i] for i in range(Vp))) % P:
        return False
    delta = [sum(lim[k][i] << (8 * k) for k in range(6)) for i in range(Vp)]
    i2v = R.inv(1 << v)
    return all(((1 if i < V else 0) * (M + i2v * (i - tk - delta[i]))) % P == lf[i] % P for i in range(Vp))


# ---- T1 A6 load-bearing
j = order[7]
M = l[order[0]] + 1
delta = [(((M - l[i]) << v) + (i - j)) if i < V else 0 for i in range(Vp)]
assert all(0 <= d < (1 << 48) for d in delta)
w1 = dict(tok=j, M=M, e=[1 if i == j else 0 for i in range(Vp)], limbs=limbs_of(delta))
OUT["T1_A6_load_bearing"] = dict(j=j, true_first_max=order[0], r0=list(R.check_argmax(l, w1, V)),
                                 accepted_without_A6=a1_to_a5_only(l, w1, V))

# ---- T2 e pad-zero load-bearing
ip = V                                   # first padded vocabulary entry
delta2 = [(((M - l[i]) << v) + (i - ip)) if i < V else 0 for i in range(Vp)]
assert all(0 <= d < (1 << 48) for d in delta2)
w2 = dict(tok=ip, M=M, e=[1 if i == ip else 0 for i in range(Vp)], limbs=limbs_of(delta2))


def without_e_padzero(l, wit, V):
    return a1_to_a5_only(l, wit, V) and sum(wit["e"][i] * sum(wit["limbs"][k][i] << (8 * k) for k in range(6)) for i in range(Vp)) % P == 0


OUT["T2_e_pad_zero_load_bearing"] = dict(output_id=ip, V=V, r0=list(R.check_argmax(l, w2, V)),
                                         accepted_without_e_pad_zero=without_e_padzero(l, w2, V))

# ---- T3 tok != selected index
w3 = R.keyed_witness(l, V)
w3 = dict(w3, tok=w3["tok"] + 1)
OUT["T3_tok_not_selected_index"] = dict(r0=list(R.check_argmax(l, w3, V)))

# ---- T4 BOS clause batching (helper-level model of the query / table zero-checks and the sum)
# commit-then-draw stand-in: in the native protocol the helpers are committed AFTER the challenges;
# model that order directly instead of hashing the helpers.
def run_t4_ordered(mode, attack):
    toks = list(tokens)
    xr = [list(r) for r in x_in]
    if attack:
        toks[0] = R.BOS + 1
        xr[0] = [vv + 7 for vv in E[123]]
    m = R.histogram(toks[1:] if attack else toks, Vp)
    d_pad = R.npow2(len(E[0]))
    k = R.clog2(d_pad)
    ch = R.challenges("probe-stage-in-ordered", toks, xr, m, n=k + 4)   # drawn after tok, x, m
    r_emb, beta, alpha, g, mu = ch[:k], ch[k], ch[k + 1], ch[k + 2], ch[k + 3]
    rm = lambda row: R.mle(list(row) + [0] * (d_pad - len(row)), r_emb)
    h_q = [R.inv((alpha - (tk + beta * rm(row) + g)) % P) for tk, row in zip(toks, xr)]
    if attack:
        h_q[0] = 0
    h_tab = [(m[vv] * R.inv((alpha - (vv + beta * rm(E[vv]) + g)) % P)) % P for vv in range(V)]
    c_bos = 1 if mode == "unweighted" else mu
    for t, (tk, row) in enumerate(zip(toks, xr)):
        q = (tk + beta * rm(row) + g) % P
        if (h_q[t] * (alpha - q) - 1 + (c_bos * (tk - R.BOS) if t == 0 else 0)) % P:
            return False, "query relation at t=%d" % t
    for vv in range(V):
        tau = (vv + beta * rm(E[vv]) + g) % P
        if (h_tab[vv] * (alpha - tau) - m[vv]) % P:
            return False, "table relation"
    if (sum(h_q) - sum(h_tab)) % P:
        return False, "LogUp sum"
    return True, "ok"


OUT["T4_bos_clause_batching"] = dict(
    honest_unweighted=list(run_t4_ordered("unweighted", False)),
    honest_fresh_coefficient=list(run_t4_ordered("fresh", False)),
    attack_unweighted=list(run_t4_ordered("unweighted", True)),
    attack_fresh_coefficient=list(run_t4_ordered("fresh", True)),
    attack="tok_0 = BOS + 1 with h_q(0) = 0: position 0 leaves the LogUp, x row 0 is arbitrary",
    r0_check_stage_in_on_attack=list(R.check_stage_in([R.BOS + 1] + tokens[1:], [[vv + 7 for vv in E[123]]] + x_in[1:],
                                                      R.histogram(tokens[1:], Vp), E, V)),
    llama3_bos_id=128000, r0_bos_constant=R.BOS)

# ---- T5 final-norm forged witnesses against R0's checker
xr = tr["x_row"]
fn = tr["norm"]
den = 2 * (fn["D"] << TV.TN)
res5 = {}
w = {kk: (list(vv) if isinstance(vv, list) else vv) for kk, vv in fn.items()}
w["y"][0] += 1
w["rho"][0] -= den
w["sigma"][0] += den
res5["y_off_by_one"] = list(R.check_final_norm(xr, w, TV.G0, TV.CN_SAFE, TV.TN, TV.CEPS))
w = dict(fn)
S = sum(vv * vv for vv in xr) + TV.CEPS
w["D"] = fn["D"] + 1
w["Dsq"] = w["D"] ** 2
w["a1"] = S - w["Dsq"]
w["a2"] = 2 * w["D"] - w["a1"]
res5["D_off_by_one"] = list(R.check_final_norm(xr, w, TV.G0, TV.CN_SAFE, TV.TN, TV.CEPS))
w = dict(fn)
w["D"] = (fn["D"] + (P - 1) // 2) % P            # the D16 alias family: a field solution, huge integer
res5["D16_field_alias"] = list(R.check_final_norm(xr, w, TV.G0, TV.CN_SAFE, TV.TN, TV.CEPS))
# y outside int8 with consistent in-window remainders: use the 8x multiplier on the honest row
num_hot = [2 * vv * TV.G0 * TV.CN_HOT + (fn["D"] << TV.TN) for vv in xr]
yq = [q // den for q in num_hot]
rr = [q % den for q in num_hot]
w = dict(fn, y=yq, rho=rr, sigma=[den - 1 - r for r in rr])
res5["y_outside_int8_in_window"] = list(R.check_final_norm(xr, w, TV.G0, TV.CN_HOT, TV.TN, TV.CEPS)) + [max(abs(q) for q in yq)]
OUT["T5_final_norm_forgeries"] = res5

# ---- T6 position selector not one-hot
s_bad = [0] * T
s_bad[P_len - 1], s_bad[0] = 2, P - 1            # sums to 1, 2*row_{P-1} - row_0
xsel = [(2 * a - b) for a, b in zip(x_out[P_len - 1], x_out[0])]
OUT["T6_position_selector_not_one_hot"] = dict(
    selector=list(R.check_selector(s_bad)),
    selection_relation_alone=list(R.check_selection([2 if t == P_len - 1 else (-1 if t == 0 else 0) for t in range(T)], x_out, xsel)),
    halves=list(R.check_selector([R.inv(2) if t in (0, P_len - 1) else 0 for t in range(T)])))

# ---- T7 B-2 verifier half: seal honest, use another row
plane = R.input_plane(tokens, P_len, T, True)
root = R.commit_standin(plane, b"probe-salt-0000000000000000000001")
s_att = R.selector(1, T)
tok_att, tr_att = R.next_token(x_out, s_att, TV.G0, TV.CN_SAFE, TV.TN, TV.CEPS, W)
w_att = R.keyed_witness(tr_att["logits"], V)
rel = {
    "stage_in": R.check_stage_in(tokens, x_in, R.histogram(tokens, Vp), E, V),
    "selector": R.check_selector(s_att),
    "selection": R.check_selection(s_att, x_out, tr_att["x_row"]),
    "final_norm": R.check_final_norm(tr_att["x_row"], tr_att["norm"], TV.G0, TV.CN_SAFE, TV.TN, TV.CEPS),
    "argmax": R.check_argmax(tr_att["logits"], w_att, V),
}
OUT["T7_sealed_right_used_wrong"] = dict(
    honest_token=tok, attack_token=tok_att,
    r0_relations={kk: list(vv) for kk, vv in rel.items()},
    owner_input_check=list(R.owner_check_input(root, plane, b"probe-salt-0000000000000000000001", prompt, TV.PAD_ID, T, True)),
    caught_only_by="the native IO-s slot (A_out's s vs input endpoint half 1); R0 has no IO-s relation")

# ---- T8 IO-in: consistent re-lookup under an honest seal
t8 = list(tokens)
t8[2] = (tokens[2] + 11) % V
x8 = [list(r) for r in x_in]
x8[2] = list(E[t8[2]])
OUT["T8_consistent_relookup_honest_seal"] = dict(
    r0_stage_in=list(R.check_stage_in(t8, x8, R.histogram(t8, Vp), E, V)),
    owner_input_check_on_honest_plane=list(R.owner_check_input(root, plane, b"probe-salt-0000000000000000000001", prompt, TV.PAD_ID, T, True)),
    caught_only_by="the native IO-in slot (A_in's tok vs input endpoint half 0); R0 has no IO-in relation")

# ---- T9 IO-out: the output plane seals another id; the owner is told that id
other = order[1]
oplane = R.output_plane(other)
oroot = R.commit_standin(oplane, b"probe-salt-0000000000000000000002")
OUT["T9_output_plane_other_id"] = dict(
    argmax_token=tok, sealed_id=other,
    r0_argmax_on_honest_witness=list(R.check_argmax(l, R.keyed_witness(l, V), V)),
    owner_output_check_told_sealed_id=list(R.owner_check_output(oroot, oplane, b"probe-salt-0000000000000000000002", other)),
    caught_only_by="the native IO-out slot (A_out's tok vs output endpoint, u0 support); R0 has no IO-out relation")

with open(os.path.join(HERE, "check2_probes.json"), "w") as fh:
    json.dump(OUT, fh, indent=1)
print(json.dumps(OUT, indent=1))
