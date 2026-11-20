"""Pass-4 probe: per-layer gate change vs the identity derivation (read-only on Sol's dir; stdout only)."""
import sys, copy, time, resource
sys.dont_write_bytecode = True
B = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3'
sys.path.insert(0, B)
from d78_blake3_primitive184 import Blake3Primitive
from d78_token_bindings198 import load_token_capture
from d78_fixture_identity292 import fixture_model, check_fixture_identity, identity
from d78_schedule259 import check_schedule
from probe_actual_programs204 import HERE, PROFILE, BLOCK, SOURCE_SHA

def fire(fn):
    try: fn(); return "ACCEPTED"
    except BaseException as e: return (type(e).__name__, str(e)[:100])

t0 = time.time()
with Blake3Primitive() as prim:
    env, rule, tr, _ = load_token_capture(HERE/"D78_SAVED_TOKEN_11090/capture", prim, source_manifest=HERE/"SOURCE-d78-188.json",
                                          source_sha256=SOURCE_SHA, profile=PROFILE, blocks=2, trusted_block_profile=BLOCK)
    fx = fixture_model(prim)
    print("derived identity :", fx["model_identity"].hex())
    print("receipt identity :", env.public_statement["model_identity"])
    print("derived block dig:", fx["block"]["block_digest"].hex(), "| receipt:", env.public_statement["block_digests"])
    print("positive ->", fire(lambda: check_fixture_identity(env.run, env.public_statement, prim, fx)), "gate", fx["gate"])
    # per-layer gate +1 on layer 1, identity recomputed from the altered record
    for layer, delta in ((1, 1), (0, 3)):
        c = copy.deepcopy(fx); c["record"]["layers"][layer]["accuracy_gate_shift"] += delta
        c["model_identity"] = identity(prim, c["record"])
        print(f"per-layer gate layer{layer} +{delta}: identity changed:", c["model_identity"] != fx["model_identity"],
              "| block digest field unchanged:", c["record"]["layers"][layer]["block_digest"] == fx["record"]["layers"][layer]["block_digest"],
              "->", fire(lambda: check_fixture_identity(env.run, env.public_statement, prim, c)))
    # schedule level (pass-3 blind spot): per-layer gate list alone
    cal = fx["cal"]; g = fx["gate"]
    P = dict(cal=cal, stage_cals=[cal, cal], gate=g, stage_gates=[g, g], trusted_profile=PROFILE, trusted_block_profile=BLOCK)
    print("schedule positive ->", fire(lambda: check_schedule(env, prim, **P)))
    print("schedule stage_gates [g, g+1] ->", fire(lambda: check_schedule(env, prim, **{**P, "stage_gates": [g, g + 1]})))
    # is the receipt's own identity compared to a saved record? edit the *receipt-side* statement coherently
    pub = copy.deepcopy(env.public_statement); pub["model_identity"] = "00"*32
    print("receipt-side identity altered ->", fire(lambda: check_fixture_identity(env.run, pub, prim, fx)))
print("wall %.1fs peak %.0f MB" % (time.time()-t0, (resource.getrusage(resource.RUSAGE_SELF).ru_maxrss+resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)/1e6))
