"""NATIVE LANE, speed plan task 3: REFIT of the speed plan's per-block phase
model on the measured Llama-3-8B phase ladder (generic dense block, T64 /
T128, laptop, 16 threads, HL_PB_TIMING=1).

The plan's model (`cost_model.py`, copied here unchanged next to this file,
sha256 of the originals in `originals.sha256`) was calibrated on the R4-4
22-block TinyLlama T128 phase run. The task-3 acceptance rule: if any phase
group misses by more than 15%, refit and re-run the projection. This refit
keeps the model's STRUCTURE (the same work drivers per phase, the same
`block_phases`) and re-derives every coefficient with the plan's own
formulas from ONE calibration rung: the 8B T128 CPU block (the quiet-box
run, 21:03-21:10 UTC, the only guarded job live). The other measured points
(8B T64 one block, the 8B T32 stack per block, the TinyLlama ladder) are
validation. The GPU arm: the keyed-commit coefficient from the 8B T128 GPU
block and the fixed per-block overhead G0 from the 8B GPU points.

usage: python3 -B refit.py   -> refit.json (+ the printed validation)
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cost_model as cm  # noqa: E402  (the unchanged copy)
from layout import llama3_8b, tinyllama  # noqa: E402

R5 = os.path.dirname(HERE)


def first_prove(path):
    """the honest prove's PB-TIMING rows and the PB-SLOTSTEP extension rows before it"""
    rows, ext, wall, on = {}, {}, None, False
    for line in open(path, errors="replace"):
        if not on and line.startswith("PB-SLOTSTEP slot") and "extension rounds" in line:
            p = [x.strip() for x in line.split("|")]
            s = int(p[0].split()[-1])
            ext[s] = ext.get(s, 0.0) + float(p[2].split()[0])
        if line.startswith("PB-TIMING prove [") and "phases, wall" in line:
            on = True
            continue
        if on and line.startswith("PB-TIMING prove |"):
            p = [x.strip() for x in line.split("|")]
            if p[1] == "phase" or p[1].startswith("SUM OF") or p[1].startswith("unaccounted"):
                continue
            if p[1].startswith("WALL CLOCK"):
                wall = float(p[3])
                break
            rows[p[1]] = rows.get(p[1], 0.0) + float(p[3])
    return rows, ext, wall


def ph_of(path):
    rows, ext, wall = first_prove(path)
    g = lambda pre: sum(v for k, v in rows.items() if k.startswith(pre))
    zc = {}
    for s, k in ((14, "D"), (18, "F"), (17, "S"), (15, "Q"), (16, "Kv")):
        zc[k] = (g(f"slot {s}"), ext.get(s, 0.0))
    run = g("run:")
    return dict(witness=0.0, a_alloc=g("A: allocate"), commit_a=g("A: commit"), commit_h=g("H: commit"),
                inv_u8=g("H: LogUp helper inverses"), inv_pair=g("H: exp + activation"), zc=zc,
                open_a=g("open A"), open_h=g("open H"), wall=wall - run)


def ph_of_stack(path):
    """every block table of a stack log summed (run rows excluded), the
    PB-SLOTSTEP extension rows summed, and the block count"""
    rows, ext, walls, run, nb = {}, {}, 0.0, 0.0, 0
    for line in open(path, errors="replace"):
        if line.startswith("PB-SLOTSTEP slot") and "extension rounds" in line:
            p = [x.strip() for x in line.split("|")]
            s = int(p[0].split()[-1])
            ext[s] = ext.get(s, 0.0) + float(p[2].split()[0])
        elif line.startswith("PB-TIMING prove |"):
            p = [x.strip() for x in line.split("|")]
            if p[1] == "phase" or p[1].startswith("SUM OF") or p[1].startswith("unaccounted"):
                continue
            if p[1].startswith("WALL CLOCK"):
                walls += float(p[3])
                nb += 1
                continue
            rows[p[1]] = rows.get(p[1], 0.0) + float(p[3])
            if p[1].startswith("run:"):
                run += float(p[3])
    g = lambda pre: sum(v for k, v in rows.items() if k.startswith(pre))
    zc = {k: (g(f"slot {s}"), ext.get(s, 0.0)) for s, k in ((14, "D"), (18, "F"), (17, "S"), (15, "Q"), (16, "Kv"))}
    return dict(witness=0.0, a_alloc=g("A: allocate"), commit_a=g("A: commit"), commit_h=g("H: commit"),
                inv_u8=g("H: LogUp helper inverses"), inv_pair=g("H: exp + activation"), zc=zc,
                open_a=g("open A"), open_h=g("open H"), wall=walls - run), nb


def coefficients_at(p, sh, blocks, f0=cm.F0_SLOT):
    """the plan's `coefficients` with the calibration rung as a parameter"""
    c = {"f0": f0}
    s = sh.summary()
    ah = s["A_elems"] + s["H_elems"]
    c["conv"] = (p["a_alloc"] - p["witness"]) / blocks / s["A_elems"]
    c["commit"] = (p["commit_a"] + p["commit_h"]) / blocks / ah
    c["inv_u8"] = p["inv_u8"] / blocks / s["u8"]
    c["inv_pair"] = p["inv_pair"] / blocks / (s["exp_pairs"] + s["act_pairs"])
    c["open"] = (p["open_a"] + p["open_h"]) / blocks / ah
    terms = s["terms"]
    ext_total = sum(v[1] for v in p["zc"].values()) / blocks
    c["ext"] = ext_total / (sum(terms.values()) * s["n"])
    c["zc"] = {k: ((v[0] - v[1]) / blocks - f0) / s["sizes"][k] / terms[k] for k, v in p["zc"].items()}
    accounted = (p["a_alloc"] + p["commit_a"] + p["commit_h"] + p["inv_u8"] + p["inv_pair"]
                 + sum(v[0] for v in p["zc"].values()) + p["open_a"] + p["open_h"]) / blocks
    rest = p["wall"] / blocks - accounted
    # the rest's split by driver: the plan's block-0 TinyLlama proportions,
    # re-scaled to this rung's measured rest and this rung's drivers
    scale = rest / sum(cm.REST0.values())
    c["rest"] = dict(Dlin=cm.REST0["Dlin"] * scale / s["sizes"]["D"], Slin=cm.REST0["Slin"] * scale / s["sizes"]["S"],
                     wfold=cm.REST0["wfold"] * scale / cm.padded_weights(sh), ncol=cm.REST0["ncol"] * scale / s["n"],
                     siterows=cm.REST0["siterows"] * scale / (cm.site_rows(sh) * s["n"]), u8=cm.REST0["u8"] * scale / s["u8"],
                     const=cm.REST0["const"] * scale)
    c["rest_total_cal"] = rest
    return c


def main():
    cal_log = os.path.join(R5, "ladder8b-T128-cpu", "prove.log")
    sh128 = llama3_8b(128, 14)
    c_new = coefficients_at(ph_of(cal_log), sh128, 1.0)
    c_old = cm.coefficients("cpu")
    out = {"calibration": "8B T128 generic block, CPU, quiet box (r5/ladder8b-T128-cpu)", "coefficients_cpu": c_new, "coefficients_cpu_plan": c_old}
    print("coefficient            plan      refit (8B T128)")
    for k in ("conv", "commit", "inv_u8", "inv_pair", "open", "ext"):
        print(f"  {k:10s} {c_old[k] * 1e9:10.2f} ns {c_new[k] * 1e9:10.2f} ns")
    for k in c_old["zc"]:
        print(f"  zc {k:6s} {c_old['zc'][k] * 1e9:10.2f} ns {c_new['zc'][k] * 1e9:10.2f} ns per element-term")
    print(f"  rest (cal rung) {c_old['rest_total_T128']:.3f} s (TinyLlama T128) -> {c_new['rest_total_cal']:.3f} s (8B T128)")
    # validation points: block wall minus the run rows, per block
    val = []
    pts = [("8B T64 one block (cpu)", llama3_8b(64, 13), os.path.join(R5, "ladder8b-T64-cpu", "prove.log"), 1.0)]
    for name, sh, path, nb in pts:
        p = ph_of(path)
        meas = p["wall"] / nb
        val.append((name, meas, cm.block_phases(sh, c_old)["total"], cm.block_phases(sh, c_new)["total"]))
    # the 8B T32 stack (cli3): every block's table, run rows excluded
    stack = os.path.join(R5, "stack-llama3_8b_pg_rot1_T32-ho00-cpu-cli3", "prove.log")
    if os.path.exists(stack):
        walls, runs, cur_run = [], [], 0.0
        for line in open(stack, errors="replace"):
            if line.startswith("PB-TIMING prove |"):
                p = [x.strip() for x in line.split("|")]
                if p[1].startswith("run:"):
                    cur_run += float(p[3])
                if p[1].startswith("WALL CLOCK"):
                    walls.append(float(p[3]) - cur_run)
                    cur_run = 0.0
        if walls:
            val.append(("8B T32 stack, per block (cli3, light contention)", sum(walls) / len(walls), cm.block_phases(llama3_8b(32, 13), c_old)["total"], cm.block_phases(llama3_8b(32, 13), c_new)["total"]))
    for (model, t), sh in cm.SHAPES.items():
        if model == "TinyLlama":
            meas = cm.MEASURED[(model, t, "cpu")]
            val.append((f"TinyLlama T{t} stack (r3 ladder, proofs per block)", meas, cm.block_phases(sh, c_old)["total"], cm.block_phases(sh, c_new)["total"]))
    print("\nvalidation (seconds per block): measured | plan model (err) | refit model (err)")
    out["validation"] = []
    for name, meas, old, new in val:
        print(f"  {name:52s} {meas:7.3f} | {old:7.3f} ({100 * (old - meas) / meas:+5.1f}%) | {new:7.3f} ({100 * (new - meas) / meas:+5.1f}%)")
        out["validation"].append(dict(point=name, measured=meas, plan=old, refit=new))
    # per-group at T64 and T128 under the refit
    for t, lc in ((64, 13), (128, 14)):
        sh = llama3_8b(t, lc)
        m = cm.block_phases(sh, c_new)
        print(f"refit 8B T{t}: " + ", ".join(f"{k} {v:.3f}" for k, v in m.items()))
    # the GPU arm, when its logs exist
    gpu = {}
    for t, lc in ((64, 13), (128, 14)):
        path = os.path.join(R5, f"ladder8b-T{t}-gpu", "prove.log")
        if os.path.exists(path):
            p = ph_of(path)
            sh = llama3_8b(t, lc)
            s = sh.summary()
            gpu[t] = dict(commit_ns=(p["commit_a"] + p["commit_h"]) / (s["A_elems"] + s["H_elems"]) * 1e9, wall=p["wall"], cpu_model_minus_commit=cm.block_phases(sh, c_new)["total"] - cm.block_phases(sh, c_new)["commit"])
    if gpu:
        commit = gpu[max(gpu)]["commit_ns"] * 1e-9
        g0 = sum(v["wall"] - (v["cpu_model_minus_commit"] + commit * (llama3_8b(t, LC[t]).summary()["A_elems"] + llama3_8b(t, LC[t]).summary()["H_elems"])) for t, v in gpu.items()) / len(gpu)
        out["gpu"] = dict(points=gpu, commit_ns=commit * 1e9, g0_s=g0)
        print(f"\nGPU arm: keyed commit {commit * 1e9:.2f} ns per committed element (plan 5.06), fixed per-block G0 {g0:.3f} s (plan 0.305); points {gpu}")
    # R5 run hygiene: the measured per-layer load of the cli3 8B T32 run
    # (digest pass 15.294 s + proving-pass reloads 15.993 s over 32 layers)
    out["load_per_layer_s"] = (15.294 + 15.993) / 2 / 32
    json.dump(out, open(os.path.join(HERE, "refit.json"), "w"), indent=1, default=float)
    # the STACK refit: the trained 8B T128 stack (task 4) as the calibration rung
    st = os.path.join(R5, "stack-llama3_8b_pg_rot1_b6_T128-ho00-cpu", "prove.log")
    if os.path.exists(st) and "event\":\"proved" in open(st, errors="replace").read():
        p, nb = ph_of_stack(st)
        c_st = coefficients_at(p, sh128, float(nb))
        res = {"calibration": f"8B T128 TRAINED stack, CPU, {nb} blocks (r5/stack-llama3_8b_pg_rot1_b6_T128-ho00-cpu)", "coefficients_cpu": c_st, "load_per_layer_s": out["load_per_layer_s"]}
        if "gpu" in out:
            res["gpu"] = out["gpu"]
        print(f"\nSTACK refit on {nb} trained 8B T128 blocks: per-block wall {p['wall'] / nb:.3f} s")
        for k in ("conv", "commit", "inv_u8", "inv_pair", "open", "ext"):
            print(f"  {k:10s} plan {c_old[k] * 1e9:8.2f} ns  one-block {c_new[k] * 1e9:8.2f} ns  stack {c_st[k] * 1e9:8.2f} ns")
        for k in c_old["zc"]:
            print(f"  zc {k:6s} plan {c_old['zc'][k] * 1e9:8.2f}  one-block {c_new['zc'][k] * 1e9:8.2f}  stack {c_st['zc'][k] * 1e9:8.2f} ns per element-term")
        res["validation"] = []
        for name, meas, old_, _ in val:
            import re
            tt = int(re.search(r" T(\d+)", name).group(1))
            sh = llama3_8b(64, 13) if name.startswith("8B T64") else (llama3_8b(32, 13) if name.startswith("8B T32") else cm.SHAPES[("TinyLlama", tt)])
            m = cm.block_phases(sh, c_st)["total"]
            print(f"  stack-refit validation {name:52s} {meas:7.3f} | {m:7.3f} ({100 * (m - meas) / meas:+5.1f}%)")
            res["validation"].append(dict(point=name, measured=meas, stack_refit=m))
        m1 = cm.block_phases(sh128, c_st)["total"]
        print(f"  stack-refit at the quiet 8B T128 one-block: {first_prove(cal_log)[2]:.3f} measured block wall (incl. run rows ~0) vs {m1:.3f}")
        json.dump(res, open(os.path.join(HERE, "refit_stack.json"), "w"), indent=1, default=float)


LC = {64: 13, 128: 14}

if __name__ == "__main__":
    main()
