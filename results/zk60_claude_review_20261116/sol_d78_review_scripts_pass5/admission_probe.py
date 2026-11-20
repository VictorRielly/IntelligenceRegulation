"""Pass-5 probe: 344 ordinary-layout descriptor check on saved sanitized native cases (read-only, stdout only, no native run)."""
import sys, json, copy, time, resource
sys.dont_write_bytecode = True
B = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3'
sys.path.insert(0, B)
import d78_native_admission_io344 as m

def fire(fn):
    try: fn(); return "ACCEPTED"
    except BaseException as e: return (type(e).__name__, str(e)[:100])

t0 = time.time()
for mode, scaled in (("outer", False), ("scaled", True)):
    cases = json.load(open(f"{B}/d78-native-admission346/{mode}.sanitized.json"))
    print(mode, "cases:", len(cases), [c.get("profile", "")[-30:] for c in cases][:6], "valid:", [c.get("valid") for c in cases][:6])
    case = next(c for c in cases if c.get("valid"))
    print(" positive (boundary_io=False, ordinary) ->", fire(lambda: m.check_case(case, scaled)))
    # reproduce the 303 outer failure: same native data against the token-stage expectation (boundary_io=True)
    orig = m.derive_case
    m.derive_case = lambda c, s, *, boundary_io=False: orig(c, s, boundary_io=True)
    print(" same data vs token-stage IO row (boundary_io=True) ->", fire(lambda: m.check_case(case, scaled)))
    m.derive_case = orig
    refused = m.controls(case, scaled)
    print(" 14 field/site controls refused:", len(refused), "| messages:", sorted(set(r['message'] for r in refused)))
    # an extra control of mine: alter a native definition-only challenge word
    alt = copy.deepcopy(case); alt["all_case"]["draws"][3][0][0] ^= 1
    print(" altered native draw word ->", fire(lambda: m.check_case(alt, scaled)))
    # coherent: change expected profile base shift (gate) in case metadata
    alt = copy.deepcopy(case); alt["gate"] = case["gate"] + 1
    print(" metadata gate +1 ->", fire(lambda: m.check_case(alt, scaled)))
    break
print("wall %.1fs peak %.0f MB" % (time.time()-t0, resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/1e6))
