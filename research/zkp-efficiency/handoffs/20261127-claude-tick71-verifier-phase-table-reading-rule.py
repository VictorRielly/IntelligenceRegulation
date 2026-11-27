#!/usr/bin/env python3
"""Tick 71 (queue item 113, rewritten by the coordinator): the reading rule for a one-thread run of the classifier run's
verifier on a retained receipt of the installed profile W16R2_SHIELD_T128_H24.

Standard library only; reads logs and directory listings, runs nothing of the prover. Run as `python3 -I <this file>`.
Labels: COUNTED (code line or listing), MEASURED (record), DERIVED (this arithmetic), ASSUMED (rate with no retained record).
"""
import re, os, sys, hashlib, statistics

ROOT = "/Users/victorrielly/IntelligenceRegulation/"
ART = "/Users/victorrielly/zk60-artifacts/astra-merged-w16r2-slget05j/"
LOG7 = ROOT + "results/zk60_a24_app_20261107/baseline_b1_cpu_verify.log"
SHIELD = ROOT + "results/zk60_w16r2_shield_block_20261120/raw/w16r2_shield_a1.log"
B8 = ROOT + "results/zk60_w16r2_shield_block_20261120/raw/w16r2_8b_ctl.log"

checks = []
def check(name, ok):
    checks.append((name, bool(ok)))
    print(("PASS  " if ok else "FAIL  ") + name)

# ---- 1. what exists on this machine for the installed profile (COUNTED: listings; one hash)
deploy = open(ROOT + "apps/proven-media/deploy.json").read()
m = re.search(r'"shieldstral-mac-fast-w16r2".*?"binary_sha256": "([0-9a-f]{64})".*?"statement_identity": "([0-9a-f]{64})".*?"profile_sha256": "([0-9a-f]{64})"', deploy, re.S)
bin_sha, ident, prof_sha = m.groups()
bindir = "/Users/victorrielly/zk60-artifacts/proven-media-fast/bin/"
have_bin = [f for f in sorted(os.listdir(bindir)) if hashlib.sha256(open(bindir + f, "rb").read()).hexdigest() == bin_sha]
print("installed verifier binary (deploy.json pin) is the file(s):", have_bin)
check("the pinned binary exists on this machine as zk60_classify.a30a31", have_bin == ["zk60_classify.a30a31"])
exp = ART + "verifier-export-w16r2-94643880/"
check("the verifier export's profile.json hashes to the pinned profile", hashlib.sha256(open(exp + "profile.json", "rb").read()).hexdigest() == prof_sha)
check("the export carries no seq_ entry (the verifier refuses prover-private entries)", not any(n.startswith("seq_") for n in os.listdir(exp)))
runs = sorted(os.listdir(ART + "runs"))
print("retained runs:", runs)
pol = {}
for r in runs:
    s = open(ART + "runs/" + r + "/statement/statement.json").read()
    pol[r] = (re.search(r'"policy": "([^"]+)"', s).group(1), re.search(r'"trained_statement_identity": "([0-9a-f]+)"', s).group(1),
              re.search(r'"run_profile": "([^"]+)"', s).group(1))
    segs = sorted(f for f in os.listdir(ART + "runs/" + r) if f.startswith("segment-"))
    sz = sum(os.path.getsize(ART + "runs/" + r + "/" + f) for f in segs)
    print(f"  {r}: {len(segs)} segments, {sz/1e6:.1f} MB, policy {pol[r][0]}")
    check(f"{r}: 28 segments", len(segs) == 28)
check("every retained run states the pinned identity", all(v[1] == ident for v in pol.values()))
check("every retained run states the W16R2 development run profile", all("w16r2-dev-only" in v[2] for v in pol.values()))

# ---- 2. the 7 November log: 26 phase tables of the R13 classifier verifier on the default pool (MEASURED)
tables, cur = [], None
for line in open(LOG7):
    if line.startswith("PB-TIMING verify [") and "phases, wall" in line:
        cur = {"wall": float(re.search(r"wall ([\d.]+) s", line).group(1)), "rows": {}}
        tables.append(cur)
        continue
    mm = re.match(r"PB-TIMING verify \| (.+?)\s+\|\s+[^|]+\|\s+([\d.]+) \|", line)
    if mm and cur is not None and not mm.group(1).startswith(("phase", "SUM", "WALL", "unaccounted")):
        key = mm.group(1).strip()
        if key not in cur["rows"]:
            cur["rows"][key] = float(mm.group(2))
check("26 verifier phase tables in the 7 November log (one a block)", len(tables) == 26)
check("every table has 30 phases", all(len(t["rows"]) == 30 for t in tables))

def slot(t, ids):
    tot = 0.0
    for k, v in t["rows"].items():
        mm = re.match(r"slot (\d+) ", k)
        if mm and int(mm.group(1)) in ids:
            tot += v
    return tot
def row(t, prefix):
    return sum(v for k, v in t["rows"].items() if k.startswith(prefix))

PUB = (0, 1, 4, 14, 15, 16, 17, 18, 19)
groups = {
    "wall of a table": [t["wall"] for t in tables],
    "load row (block load + statement check)": [row(t, "run:") for t in tables],
    "frame row": [row(t, "frame:") for t in tables],
    "setup row (header + roots; holds check_for_shape)": [row(t, "transcript header") for t in tables],
    "slots 0,1,4,14-19 (public-table slots at the installed profile)": [slot(t, PUB) for t in tables],
    "slots 5-7,10-13 (the seven weight folds)": [slot(t, (5, 6, 7, 10, 11, 12, 13)) for t in tables],
    "slots 2,3,8,9,20,21,22 (the rest)": [slot(t, (2, 3, 8, 9, 20, 21, 22)) for t in tables],
    "verify M": [row(t, "verify M") for t in tables],
    "verify A": [row(t, "verify A") for t in tables],
    "verify H": [row(t, "verify H") for t in tables],
    "boundary opening": [row(t, "verify boundary") for t in tables],
}
print("\nR13 classifier verifier, 7 Nov log, default pool (thread count not stated), 26 blocks, ms (mean / min / max):")
mean = {}
for k, v in groups.items():
    mean[k] = statistics.mean(v) * 1e3
    print(f"  {k:<66} {mean[k]:7.1f} / {min(v)*1e3:6.1f} / {max(v)*1e3:6.1f}")
rows_sum = sum(v for k, v in mean.items() if k not in ("wall of a table",))
check("the groups cover the wall of a table within 2%", abs(rows_sum - mean["wall of a table"]) / mean["wall of a table"] < 0.02)

# ---- 3. public tables at the installed profile versus W16R2_8B (MEASURED table counts, COUNTED supp rule)
def tabs(path):
    build, cube = {}, {}
    for line in open(path):
        a = re.match(r"PB-SLOTSTEP slot (\d+) \| tables: build.*\|\s+(\d+) \|", line)
        if a and int(a.group(1)) not in build:
            build[int(a.group(1))] = int(a.group(2))
        b = re.match(r"PB-SLOTSTEP slot (\d+) \| claimed sum.*\|\s+(\d+) \|", line)
        if b and int(b.group(1)) not in cube:
            cube[int(b.group(1))] = int(b.group(2))
    return {s: (build[s] // cube[s], cube[s]) for s in sorted(build) if s in cube}
t8, ts = tabs(B8), tabs(SHIELD)
diff = {s: (t8[s][0], ts[s][0]) for s in t8 if t8[s][0] != ts[s][0] or t8[s][1] != ts[s][1]}
print("\nslots whose table count differs, W16R2_8B vs installed W16R2 Shieldstral (tables):", diff)
check("only slots 0, 1 and 14 differ, each by one table of 2^19", set(diff) == {0, 1, 14} and all(ts[s][0] == t8[s][0] + 1 and ts[s][1] == 1 << 19 for s in diff))
# COUNTED: B::supp returns None unless sh.pads(dom) (argument.rs:2579-2583); SC_SS takes supp(Dom::D) (argument.rs:2989, 3029),
# the D zero-check takes supp(Dom::D) (argument_accuracy.rs:478); d = 3072 < d_pad = 4096 pads D at the installed profile only.
# The table is public (`self.public(...)`, argument.rs:2609-2611).
extra = 3 * (1 << 19)
base_total = 8_052_736            # tick 70, W16R2_8B
total = base_total + extra
print(f"public entries a block: W16R2_8B {base_total:,}; installed profile {total:,} (+{extra:,}, x{total/base_total:.3f}), {total*16/1e6:.1f} MB at 16 B")
check("installed-profile public entries 9,625,600", total == 9_625_600)

# ---- 4. tick 70's rates applied to the three added supp(D) tables and the smaller group_col (DERIVED, ASSUMED rates)
FP = (0.8, 1.12, 1.6)
eval_ns = tuple(5 * f + 0.5 for f in FP)
ev_add = [extra * e / 1e6 for e in eval_ns]
build_ns = [(4, 6, 10)[i] for i in range(3)]                 # i64 indicator then Fp2 map, as tick 70's supp(F)
b_add = [extra * x / 1e6 for x in build_ns]
mb = (extra * 16 + 3 * (1 << 19) * 8) / 1e6                  # Fp2 vectors plus the three i64 indicators
touch = [mb * f for f in (0.06, 0.10, 0.15)]
gc_8b, gc_sh = 128 * 14336, 128 * 9216                         # group_col writes tokens x hidden (accuracy_act.rs:37-39)
gc = [(gc_sh - gc_8b) * x / 1e6 for x in (2, 3, 4)]
delta = [ev_add[i] + b_add[i] + touch[i] + gc[i] for i in range(3)]
base_replay = (71.0, 108.0, 165.0)                            # tick 70 at W16R2_8B
inst = [base_replay[i] + delta[i] for i in range(3)]
print(f"\nadded to tick 70's replay: evaluation {ev_add[0]:.1f}/{ev_add[1]:.1f}/{ev_add[2]:.1f}, build {b_add[0]:.1f}/{b_add[1]:.1f}/{b_add[2]:.1f}, "
      f"first touch {touch[0]:.1f}/{touch[1]:.1f}/{touch[2]:.1f}, smaller group_col {gc[0]:.1f}/{gc[1]:.1f}/{gc[2]:.1f} ms")
print(f"replay at the installed profile, one thread: {inst[0]:.0f} / {inst[1]:.0f} / {inst[2]:.0f} ms (8B: 71 / 108 / 165)")
check("installed replay is above the 8B replay at every rate", all(inst[i] > base_replay[i] for i in range(3)))
check("the three added tables are 19.5% more entries", abs(extra / base_total - 0.1953) < 0.001)

# ---- 5. the reading rule's bands (DERIVED from tick 68, tick 70 and the 275.5 ms record)
BLOCK = 275.5   # one-thread W16R2_8B test, sparse column loop on, DIAGONAL weights, block digest cached (results/zk60_verify_threads_20261125)
print("\nreading rule bands (one thread, per block, ms):")
print(f"  S_pub  (rows of slots 0,1,4,14-19)       confirm {inst[0]:.0f} to {inst[2]:.0f}; under {inst[0]:.0f} kills the low rates (S_pub also holds registry checks, so it bounds the replay from above)")
print(f"  tick 70 lower end 71 ms x1.195 entries alone = {71*total/base_total:.0f} ms (entries-proportional floor)")
check("entries-proportional floor equals the installed band's low end within 1 ms", abs(inst[0] - 71 * total / base_total) < 1.0)

# ---- 6. the printed `size` column as a profile check (COUNTED: slot_work(s, element_terms), argument.rs:4209; MEASURED sizes)
R13 = ROOT + "results/zk60_slot18_14_breakdown_20261117/raw/r13_shield_armA_prod_batched.log"
tr13 = tabs(R13)
first = {}
for line in open(LOG7):
    mm = re.match(r"PB-TIMING verify \| slot (\d+) .*?\|\s+(\d+) elem-terms", line)
    if mm and int(mm.group(1)) not in first:
        first[int(mm.group(1))] = int(mm.group(2))
ratio = {s: first[s] / (tr13[s][0] * tr13[s][1]) for s in (0, 1, 4, 14, 15, 16, 17, 18, 19) if s in first and s in tr13}
print("\nprinted elem-terms / (tables x cube) of the prover's R13 Shieldstral slot log, per slot:", {s: round(r, 3) for s, r in ratio.items()})
check("the printed size is 2 x tables x cube in every public-table slot (R13 pair)", all(abs(r - 2.0) < 1e-9 for r in ratio.values()))
want = {s: 2 * ts[s][0] * ts[s][1] for s in (0, 1, 4, 14, 15, 16, 17, 18, 19)}
print("expected printed sizes at the installed profile (2 x tables x cube):", want)
check("expected size of slot 14 at the installed profile is 38,797,312", want[14] == 38_797_312)

fails = [n for n, ok in checks if not ok]
print(f"\n{len(checks)} checks, {len(fails)} failed")
sys.exit(1 if fails else 0)
