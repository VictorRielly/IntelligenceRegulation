"""Stage 20 probe: re-run the INDEPENDENT Python layout model with the repaired
bilinear schedule, WITHOUT editing scripts/ (outside this lane's write set).
Prints every figure of the model that the S19-F1 repair moves."""
import sys, importlib, copy
sys.path.insert(0, "/home/victor/wt-zk60-block125m/scripts")
import zk60_private_block_layout_model as M

orig_slots = M.slots

def repaired_slots(sh):
    out = copy.deepcopy(orig_slots(sh))
    lkv = M.clog2(sh.kv_heads)
    for s in (M.SC_SCORE, M.SC_PV):
        r = out[s]
        r["main_rounds"] += lkv
        if lkv > 0:
            r["degree"] += 1
        r["L"] = (r["main_rounds"] + r["extension_rounds"]) * r["degree"] + 2
    return out

def report(name, sh):
    M.slots = orig_slots
    before = M.model(sh)
    M.slots = repaired_slots
    after = M.model(sh)
    b, a = before, after
    print(f"== {name}  (kv_heads={sh.kv_heads}, lkv={M.clog2(sh.kv_heads)})")
    for s in (M.SC_SCORE, M.SC_PV):
        rb, ra = b["slots"][s], a["slots"][s]
        print(f"   slot {s:02d} {rb['name']:<22} (main,ext,deg,L): "
              f"({rb['main_rounds']},{rb['extension_rounds']},{rb['degree']},{rb['L']})"
              f" -> ({ra['main_rounds']},{ra['extension_rounds']},{ra['degree']},{ra['L']})")
    def cmp(path, get):
        x, y = get(b), get(a)
        flag = "MOVES" if x != y else "same "
        print(f"   {flag} {path}: {x} -> {y}")
    cmp("slot_summary.main_round_total", lambda m: m["slot_summary"]["main_round_total"])
    cmp("slot_summary.extension_round_total", lambda m: m["slot_summary"]["extension_round_total"])
    cmp("slot_summary.largest_L", lambda m: m["slot_summary"]["largest_L"])
    cmp("rows.m_rows", lambda m: m["rows"]["m_rows"])
    cmp("rows.a_sites", lambda m: m["rows"]["a_sites"])
    cmp("rows.h_sites", lambda m: m["rows"]["h_sites"])
    cmp("opening_groups.a_groups", lambda m: m["opening_groups"]["a_groups"])
    cmp("opening_groups.h_groups", lambda m: m["opening_groups"]["h_groups"])
    cmp("receipt_bytes.slots", lambda m: m["receipt_bytes"]["slots"])
    cmp("receipt_bytes.total", lambda m: m["receipt_bytes"]["total"])
    # derived counts the inventory tools speak in
    rv = lambda m: sum((s["main_rounds"] + s["extension_rounds"]) * (s["degree"] + 1) for s in m["slots"])
    dr = lambda m: sum(s["main_rounds"] + s["extension_rounds"] for s in m["slots"])
    tm = lambda m: sum(m["claim_sites"]["a"][s] + m["claim_sites"]["h"][s] + (1 if s >= M.SC_IO_IN else 0) for s in range(M.N_SLOTS))
    cmp("published round VALUES (sum (main+ext)(deg+1))", rv)
    cmp("sumcheck challenge DRAWS per block (sum main+ext)", dr)
    cmp("private TERMINALS per block", tm)
    print()

for nm, sh in [("TOY", M.TOY), ("RUNG", M.RUNG), ("125M", M.M125)]:
    report(nm, sh)
M.slots = orig_slots
