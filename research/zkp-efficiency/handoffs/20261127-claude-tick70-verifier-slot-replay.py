#!/usr/bin/env python3
"""Tick 70 (queue item 111): the slot replay of a W16R2_8B verifier block, counted.

Standard library only; reads one tracked log (the per-slot table counts of the W16R2_8B production arm) and one
retained verifier phase log (a 125M-profile CPU verifier run), prints counts, bytes and priced ranges.
Labels: COUNTED (code line), MEASURED (record), DERIVED (this arithmetic), ASSUMED (a rate with no retained record).
"""
import re, sys

ROOT = "/Users/victorrielly/IntelligenceRegulation/"
LOG8B = ROOT + "results/zk60_slot18_14_breakdown_20261117/raw/w16r2_8b_armA_prod_batched.log"
LOG125 = ROOT + "results/zk60_sol_gpu_20260927/attempt-5-dense-ab/a1-cpu.log"

checks = []
def check(name, ok):
    checks.append((name, bool(ok)))
    print(("PASS  " if ok else "FAIL  ") + name)

# ---- 1. per-slot cube and table count (MEASURED log: tables-build words = tabs * 2^n; claimed-sum words = 2^n)
build, cube = {}, {}
for line in open(LOG8B):
    m = re.match(r"PB-SLOTSTEP slot (\d+) \| tables: build.*\|\s+(\d+) \|", line)
    if m and int(m.group(1)) not in build:
        build[int(m.group(1))] = int(m.group(2))
    m = re.match(r"PB-SLOTSTEP slot (\d+) \| claimed sum.*\|\s+(\d+) \|", line)
    if m and int(m.group(1)) not in cube:
        cube[int(m.group(1))] = int(m.group(2))
slots = sorted(build)
check("23 slots read from the log", slots == list(range(23)))
tabs = {s: build[s] // cube[s] for s in slots}
check("tables x cube divides exactly in every slot", all(build[s] % cube[s] == 0 for s in slots))
print("slot: tabs x 2^n  ", {s: (tabs[s], cube[s].bit_length() - 1) for s in slots})

# ---- 2. public (Tab::Pub) tables per slot, COUNTED from the slot definitions at this profile
# At W16R2_8B: tokens = t_pad = 128, width = d_pad = 4096, q = h_pad*dh, kv unpadded; hidden 14,336 < f_pad 16,384, so only
# Dom::F (and Dom::Tab, 256 rows in 2^14) pad. Verifier: pub_gen_prove is false (argument.rs:4117), so every Pub is a full Vec<Fp2>.
pub = {s: 0 for s in slots}
pub[4] = 1                   # SC_RS: causal_mask (argument.rs:3162, 2382-2387)
for s in (5, 6, 7, 10, 11, 12, 13):
    pub[s] = 1               # matmul slots: the folded public weight (argument.rs:3251, 3392)
pub[14] = 2                  # DZC: ig, igm via repeat_vals (argument_accuracy.rs:468-469); supp(D) None at 8B
pub[15] = 2                  # QZC: rope cos, sin (argument_accuracy.rs:544)
pub[16] = 2                  # KVZC: rope cos, sin
pub[17] = 1                  # SZC: causal_mask (argument_accuracy.rs:584)
pub[18] = 2                  # FZC: group_col + supp(F) (argument_accuracy.rs:514-515)
# TAB (slot 19): tabs = 58 = 1 eq + 2(3+r) private + (3+r) range/table pubs + supp(Tab) + act.support + narrow supports
for r in (12, 13):
    narrow = tabs[19] - 1 - 2 * (3 + r) - (3 + r) - 2
    print(f"slot 19: r={r} range sub-planes -> narrow supports {narrow}, pub tables {3 + r + 2 + narrow}")
r = 13                       # the trace's 16 table planes = 3 + 13 (tick 69 / queue item 112)
pub[19] = (3 + r) + 2 + (tabs[19] - 1 - 2 * (3 + r) - (3 + r) - 2)
check("slot 19 has 25 pub tables at r = 13", pub[19] == 25)
check("slots 0-3, 20-22 carry no pub table (tabs = eq + private)", all(pub[s] == 0 for s in (0, 1, 2, 3, 8, 9, 20, 21, 22)))

entries = {s: pub[s] * cube[s] for s in slots}
total = sum(entries.values())
print("pub entries per slot", {s: entries[s] for s in slots if entries[s]})
print(f"pub entries a block: {total:,}   bytes at 16 B: {total*16/1e6:.1f} MB")
check("total pub entries 8,052,736", total == 8_052_736)

# ---- 3. other replay work, counted
rounds = sum(cube[s].bit_length() - 1 + (2 if s in (8, 9) else 1) for s in slots)
print(f"sumcheck rounds a block: {rounds}")
check("rounds 370", rounds == 370)
# split eq tables: 2^(n/2) entries per half, one pair per slot with a pub table
split_entries = sum((1 << (n - n // 2)) + (1 << (n // 2)) for n in [cube[s].bit_length() - 1 for s in slots if pub[s]])
print(f"SplitEq half-table entries a block: {split_entries:,}")

# ---- 4. rates (ASSUMED ranges; BAT's 1.12 ns an Fp multiplication, tick 58, is the one repo-derived rate)
FP = (0.8, 1.12, 1.6)                         # ns a base multiplication (low, repo, high)
eval_ns = tuple(5 * f + 0.5 for f in FP)      # Fp2::mul is five base multiplications (field.rs:163-169) plus an add
EV = [total * e / 1e6 for e in eval_ns]       # ms
print(f"SplitEq evaluation, {total:,} Fp2 products: {EV[0]:.1f} / {EV[1]:.1f} / {EV[2]:.1f} ms")

live_group = 128 * 14336                      # group_column writes tokens x hidden entries (accuracy_act.rs:37-39)
classes = [  # name, entries, ns per entry (low, mid, high), basis
    ("causal mask (slots 4, 17)",          2 * (1 << 19), (4, 8, 15),  "three runtime div/mod per entry, argument.rs:2828-2832"),
    ("rope tables (slots 15, 16)",         (1 << 19) + (1 << 17), (8, 14, 25), "four div/mod, two tables a position, argument.rs:2857-2875"),
    ("repeat_vals (slot 14, two)",         2 * (1 << 19), (2, 4, 8),   "one mod a entry, argument.rs:2459"),
    ("group_col (slot 18)",                live_group, (2, 3, 4),      "tokens x hidden writes, accuracy_act.rs:36-39"),
    ("supp(F) indicator (slot 18)",        1 << 21, (4, 6, 10),        "i64 table then Fp2 map, argument.rs:2609-2611, pad.rs:354"),
]
B = [0.0, 0.0, 0.0]
for name, n, (lo, mid, hi), basis in classes:
    v = [n * x / 1e6 for x in (lo, mid, hi)]
    for i in range(3):
        B[i] += v[i]
    print(f"build {name:<30} {n:>10,} entries  {v[0]:5.1f} / {v[1]:5.1f} / {v[2]:5.1f} ms   [{basis}]")
small = (2.0, 2.5, 3.0)                       # slot 19's 25 tables of 2^14 and the seven folded tables
for i in range(3):
    B[i] += small[i]
print(f"build slot 19 tables and folded weights (flat, ASSUMED)   {small[0]:.1f} / {small[1]:.1f} / {small[2]:.1f} ms")
mb = (total * 16 + (1 << 21) * 8) / 1e6       # Fp2 vectors plus the i64 indicator
FAULT = (0.06, 0.10, 0.15)                    # ms a MB of freshly mapped memory, ASSUMED (no repo record found)
F = [mb * f for f in FAULT]
print(f"memory first touch, {mb:.1f} MB at 0.06 / 0.10 / 0.15 ms a MB: {F[0]:.1f} / {F[1]:.1f} / {F[2]:.1f} ms")
BUILD = [B[i] + F[i] for i in range(3)]
print(f"BUILD total: {BUILD[0]:.1f} / {BUILD[1]:.1f} / {BUILD[2]:.1f} ms")

small_replay = (0.5, 1.5, 3.0)                # 370 rounds (hash + interpolation), claims, functionals, check_opening
print(f"rounds, claims, functionals, audit (ASSUMED, counts small): {small_replay[0]} / {small_replay[1]} / {small_replay[2]} ms")
REPLAY = [EV[i] + BUILD[i] + small_replay[i] for i in range(3)]
print(f"REPLAY total (one thread): {REPLAY[0]:.0f} / {REPLAY[1]:.0f} / {REPLAY[2]:.0f} ms   width {REPLAY[2]-REPLAY[0]:.0f} ms")
check("width of the replay range exceeds the 20 ms pass line", REPLAY[2] - REPLAY[0] > 20)

# ---- 5. against tick 68's cut (its numbers, restated)
BLOCK, NTT, OTH = 275.5, (75.0, 94.0), 6.1 + 6.1 + 3.7 + 5.7
resid = (BLOCK - NTT[1] - OTH, BLOCK - NTT[0] - OTH)
print(f"tick 68 residual: {resid[0]:.0f} to {resid[1]:.0f} ms; its bottom-up non-PCS 114 to 179 ms")
lo_sum = 114 + REPLAY[0]
print(f"non-PCS (114 at its low rates) + replay (low rates) = {lo_sum:.0f} ms against a residual of at most {resid[1]:.0f} ms")
room = resid[1] - 114
print(f"room left for the replay if non-PCS is at its own lower end and the NTT term at its lower end: {room:.0f} ms")
check("replay low end exceeds the room left (the assumed rates cannot all hold)", REPLAY[0] > room)
ntt_needed = BLOCK - OTH - 114 - REPLAY[0]
print(f"NTT term the residual can hold if both lower ends are right: at most {ntt_needed:.0f} ms (tick 60 derived 75 to 94)")

# ---- 6. the retained 125M-profile verifier phases (MEASURED, 2026-09-27, default pool, laptop era, before A26)
ph, wall = {}, None
for line in open(LOG125):
    if line.startswith("PB-TIMING verify [125M") and wall is None:
        wall = float(re.search(r"wall ([\d.]+) s", line).group(1))
        continue
    if wall is None:
        continue
    m = re.match(r"PB-TIMING verify \| slot (\d+) .*\|\s+([\d.]+) \|[^|]*\|[^|]*\|", line)
    if m and int(m.group(1)) not in ph:
        ph[int(m.group(1))] = float(m.group(2))
    if "SUM OF PHASES" in line:
        break
slot_sum = sum(ph.values())
print(f"125M verifier: wall {wall:.3f} s, the 23 slot phases {slot_sum:.3f} s = {100*slot_sum/wall:.0f}%")
check("125M slot phases are 0.56 to 0.57 s of 0.838 s", 0.55 < slot_sum < 0.58)
big = ph[4] + ph[14] + ph[15] + ph[16] + ph[17]
ent125 = (1 << 23) + 2 * (1 << 20) + 2 * (1 << 20) + 2 * (1 << 18) + (1 << 23)
print(f"slots 4, 14-17: {big*1e3:.0f} ms over about {ent125:,} public entries = {big/ent125*1e9:.0f} ns an entry (full eq table then, default pool)")
print(f"  slot 14 {ph[14]*1e3:.0f} ms / {2*(1<<20):,} = {ph[14]/(2*(1<<20))*1e9:.1f} ns;  slot 15 {ph[15]*1e3:.0f} ms = {ph[15]/(2*(1<<20))*1e9:.1f} ns;  slot 16 {ph[16]*1e3:.0f} ms = {ph[16]/(2*(1<<18))*1e9:.1f} ns")

fails = [n for n, ok in checks if not ok]
print(f"\n{len(checks)} checks, {len(fails)} failed")
sys.exit(1 if fails else 0)
