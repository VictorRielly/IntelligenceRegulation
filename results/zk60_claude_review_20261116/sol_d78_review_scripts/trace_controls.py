"""Re-run Sol's falsifier controls (214, 216, 218, 221) read-only, recording the
exception type and message that fired for each. Writes only to stdout."""
import sys, copy, json, struct, collections
sys.dont_write_bytecode = True
B = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3'
sys.path.insert(0, B)
from d78_blake3_primitive184 import Blake3Primitive
from d78_token_bindings198 import load_token_capture
from d78_capture_envelope197 import read_regular
from d78_wire_binding215 import compare_stage_wire, MAX_SEGMENT
from probe_wire_binding216 import plans_for
from probe_actual_programs204 import HERE, PROFILE, BLOCK, SOURCE_SHA
from d78_token_polynomials217 import check_stage_polynomials
from d78_token_model_tables220 import check_public_model_tables
from probe_public_model221 import public_fixture_words
from d78_endpoint_bindings213 import check_endpoint_bindings
from d78_endpoint_bindings210 import check_endpoint_bindings as old_check
from pathlib import Path
assert str(HERE) == B

def fire(fn):
    try:
        fn()
    except BaseException as e:
        return type(e).__name__, str(e)[:100], isinstance(e, ValueError)
    return None

root = HERE / "D78_SAVED_TOKEN_11090"
out = {}
with Blake3Primitive() as prim:
    env, rule, tr, _ = load_token_capture(root/"capture", prim, source_manifest=HERE/"SOURCE-d78-188.json",
                                          source_sha256=SOURCE_SHA, profile=PROFILE, blocks=2, trusted_block_profile=BLOCK)
    plans = plans_for(env)
    binding = bytes(env.run["run_binding"])
    # ---- 216
    rows = []
    for k, (stage, plan) in enumerate(zip(env.stages, plans)):
        raw = read_regular(root, f"segment_{k:03}.bin", MAX_SEGMENT)
        base = compare_stage_wire(raw, stage, binding=binding, plan=plan, arrays=env.arrays)
        for cat, span in base["first_spans"].items():
            alt = bytearray(raw); alt[span["offset"]] ^= 1
            rows.append((k, cat, fire(lambda: compare_stage_wire(alt, stage, binding=binding, plan=plan, arrays=env.arrays))))
        for nm, ch in (("trunc-1", raw[:-1]), ("pad+1", raw + b"\x00")):
            rows.append((k, nm, fire(lambda: compare_stage_wire(ch, stage, binding=binding, plan=plan, arrays=env.arrays))))
        alt = bytearray(raw); cs = copy.deepcopy(stage); off = base["first_spans"]["slot.scalar"]["offset"]
        struct.pack_into("<Q", alt, off, 0xffffffff00000001); cs["arguments"][0]["scalar"][0] = 0xffffffff00000001
        rows.append((k, "noncanon-scalar", fire(lambda: compare_stage_wire(alt, cs, binding=binding, plan=plan, arrays=env.arrays))))
    print("216 controls:", len(rows), "not refused:", [r[:2] for r in rows if r[2] is None],
          "non-ValueError:", [r for r in rows if r[2] and not r[2][2]])
    c = collections.Counter(r[2][1] for r in rows if r[2])
    for msg, n in c.most_common(): print("  216", n, msg)
    print("  216 per-category sample:", [(r[0], r[1], r[2][1]) for r in rows[:14]])
    # ---- 218
    rows = []
    for stage in (env.stages[0], env.stages[3]):
        for s in range(len(stage["arguments"])):
            alt = copy.deepcopy(stage); alt["arguments"][s]["terminal_polynomial"][0] ^= 1
            rows.append((stage["stage_kind"], "terminal_poly slot %d" % s, fire(lambda: check_stage_polynomials(alt, env.run["token_io"], env.arrays))))
    for choice in ("mu", "host", "order", "public", "logup"):
        alt = copy.deepcopy(env.stages[3])
        if choice == "mu": alt["arguments"][2]["definition_challenges"][1][0] ^= 1
        elif choice == "host": alt["arguments"][2]["hosted"][0]["coefficient"][0] ^= 1
        elif choice == "order": alt["arguments"][5]["tables"][2]["kind"] = "public"
        elif choice == "public": alt["arguments"][1]["tables"][0]["sha256"] = "00"*32
        else: alt["logup_challenges"][0][0] ^= 1
        rows.append(("OUT", choice, fire(lambda: check_stage_polynomials(alt, env.run["token_io"], env.arrays))))
    print("218 controls:", len(rows), "not refused:", [r[:2] for r in rows if r[2] is None], "non-ValueError:", [r for r in rows if r[2] and not r[2][2]])
    for r in rows: print("  218", r[0], r[1], "->", r[2][0] if r[2] else None, "|", r[2][1] if r[2] else None)
    # ---- 221
    emb0, head0, mult0 = public_fixture_words()
    rows = []
    for choice in ("embedding", "head", "multiplier", "embedding_point", "head_point", "embedding_class", "head_class", "multiplier_class"):
        emb = emb0.copy(); hd = head0.copy(); mult = mult0.copy(); orig = env.stages
        if choice == "embedding": emb[384] += 1
        elif choice == "head": hd[0] = -hd[0]
        elif choice == "multiplier": mult[0] = 2
        elif choice == "embedding_class": emb[0] = 32768
        elif choice == "head_class": hd[0] = -128
        elif choice == "multiplier_class": mult[0] = 0
        else:
            env.stages = copy.deepcopy(orig)
            if choice == "embedding_point": env.stages[0]["r_emb"][0][0] ^= 1
            else: env.stages[3]["arguments"][4]["definition_challenges"][0][0] ^= 1
        try: rows.append((choice, fire(lambda: check_public_model_tables(env, prim, embedding=emb, head=hd, multipliers=mult))))
        finally: env.stages = orig
    print("221 controls:", len(rows))
    for r in rows: print("  221", r[0], "->", r[1])
    # ---- 214
    run = json.loads((root/"capture/run.json").read_text())
    paths = [("token_io","input_endpoint","data_rows"),("token_io","input_endpoint","scale"),("token_io","output_endpoint","sites"),
             ("token_io","output_endpoint","site_rows",0),("token_io","b_in","index"),("token_io","b_in","data_rows"),
             ("token_boundaries",0,"facts","scale"),("token_boundaries",0,"committed_at_stage"),("token_boundaries",0,"boundary"),
             ("token_boundaries",0,"facts","site_rows",0),("token_io","input_endpoint_opened_at_stage"),("blocks",),("boundaries",)]
    rows = []
    for path in paths:
        for as_bool in (False, True):
            alt = copy.deepcopy(run); at = alt
            for p in path[:-1]: at = at[p]
            o = at[path[-1]]
            if as_bool and o not in (0, 1): continue
            at[path[-1]] = bool(o) if as_bool else float(o)
            rows.append((path, as_bool, fire(lambda: check_endpoint_bindings(alt, prim, trusted_profile=PROFILE, trusted_block_profile=BLOCK)),
                         fire(lambda: old_check(alt, prim, trusted_profile=PROFILE, trusted_block_profile=BLOCK))))
    print("214 controls:", len(rows), "not refused by 213:", [r[:2] for r in rows if r[2] is None])
    c = collections.Counter(r[2][1] for r in rows if r[2])
    for m, n in c.most_common(): print("  214", n, m)
    print("  214 old(210) accepted:", sum(1 for r in rows if r[3] is None))
