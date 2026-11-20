"""Tick 20 (item 36): which device sumcheck slots are plain two-table sums, and their share of block GPU.
Reads only results/zk60_slot18_14_breakdown_20261117/summary.json (standard library). Run: python3 -I <this file>."""
import json, re
R = '/Users/victorrielly/IntelligenceRegulation/results/zk60_slot18_14_breakdown_20261117/summary.json'
d = json.load(open(R))
def slot_no(s): return int(re.match(r'slot (\d+)', s).group(1))
# class by the IR census (summary.json census, slot shape: tables, degree)
# P2: two-table degree-2 (f*g, or eq*(a-b) with one linear node); P3: at most 4 tables, degree 3 (with eq factor)
CLASS = {20: 'P2', 21: 'P2', 22: 'P2', 0: 'P3', 1: 'P3', 4: 'P3', 3: 'Z4'}
for p in ['w16r2_8b', 'r13_shield']:
    A = d['arms'][p + '_armA_prod_batched']['batched']
    B = d['arms'][p + '_armB_unbatched_sync_lin1']['unbatched']
    tot = A['categories_ms']['total_prove_gpu_ms']
    allsl = A['categories_ms']['all_slots_gpu_ms']
    bms = {}
    for k, v in B.items():
        bms[slot_no(k)] = v['phases_median_ms']['total_unbatched_with_tables_gpu_ms']
    print('==', p, 'block GPU', tot, 'all slots (batched)', allsl, 'arm B sum', round(sum(bms.values()), 3))
    sums = {}
    for s in A['slots_sorted_ms']:
        n = slot_no(s['slot_label']); a = s['median_ms']; b = bms.get(n)
        c = CLASS.get(n, 'big')
        sums.setdefault(c, [0, 0, []]); sums[c][0] += a; sums[c][1] += (b or 0); sums[c][2].append(n)
        print(f"  slot {n:2d} {c:3s} {s['meta'].split(' recover')[0]:50s} A={a:7.3f} B={b if b is None else round(b,3)}")
    for c, (a, b, ns) in sorted(sums.items()):
        print(f"  class {c:3s} slots {sorted(ns)}: A {a:.3f} ms = {100*a/tot:.2f}% of block GPU ({100*a/allsl:.1f}% of slots); B {b:.3f} ms = {100*b/tot:.2f}%")
    p2 = sums.get('P2', [0, 0, []]); p3 = sums.get('P3', [0, 0, []])
    print(f"  P2 only: A {100*p2[0]/tot:.2f}%, B {100*p2[1]/tot:.2f}%;  P2+P3: A {100*(p2[0]+p3[0])/tot:.2f}%, B {100*(p2[1]+p3[1])/tot:.2f}%")
# CPU matmul slots 5..13 (host path) per block, last warm pass, from the raw log
import collections
for f, nm in [('w16r2_8b_armA_prod_batched.log', '8B'), ('r13_shield_armA_prod_batched.log', 'Shield')]:
    rows = []
    for l in open('/Users/victorrielly/IntelligenceRegulation/results/zk60_slot18_14_breakdown_20261117/raw/' + f):
        m = re.match(r'PB-SLOTSTEP slot (\d+) \| (.*?)\s+\|\s+([\d.]+) s \|', l)
        if m: rows.append((int(m[1]), float(m[3])))
    passes = []; cur = []
    for r in rows:
        if r[0] == 0 and cur and len(cur) >= 90: passes.append(cur); cur = []
        cur.append(r)
    passes.append(cur)
    per = [sum(t for s, t in p if 5 <= s <= 13) for p in passes if len(p) > 80]
    print(nm, 'matmul slots 5-13 host seconds per block, per pass (sum of three-decimal rounded phases):', [round(x, 3) for x in per])
