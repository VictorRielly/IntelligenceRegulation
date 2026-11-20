#!/usr/bin/env python3
"""Tick 16 (queue item 33): size of the sumcheck tail rounds (rounds j >= 5) over every device slot of a block.
Reads only results/zk60_slot18_14_breakdown_20261117/summary.json (Arm A batched, Arm B unbatched) and prints tables.
Standard library; runs nothing on a GPU."""
import json, re
P = '/Users/victorrielly/IntelligenceRegulation/results/zk60_slot18_14_breakdown_20261117/summary.json'
d = json.load(open(P))
BLOCK = {'w16r2_8b': 117.285, 'r13_shield': 248.899}
NBLK = {'w16r2_8b': 32, 'r13_shield': 26}
EXTRA_MS = 7.119  # MEASURED solo W16R2_8B: all_slots_gpu_ms 63.302 -> 56.183 at HL_METAL_BATCH_TAIL_US=250 (knob_probe.json)
for prof in BLOCK:
    A = d['arms'][prof + '_armA_prod_batched']['batched']['slots_sorted_ms']
    B = {re.match(r'slot (\d+)', k).group(1): v for k, v in d['arms'][prof + '_armB_unbatched_sync_lin1']['unbatched'].items()}
    print('==', prof, 'block GPU', BLOCK[prof], 'ms')
    print('slot  A_ms  ndA  B_ms  ndB  Btail(j>=5)_ms  nBtail  mean_ms  A-B_ms  extra_rounds')
    tb5 = tb6 = n5 = nA5 = sa = sb = 0
    for r in A:
        s = re.match(r'slot (\d+)', r['slot_label']).group(1)
        ndA = int(re.search(r'nd=(\d+)', r['meta']).group(1))
        b = B.get(s)
        if not b:
            print(f'{s:>4} {r["median_ms"]:6.3f} {ndA:3d}   (no Arm B row)')
            nA5 += max(0, ndA - 5); sa += r['median_ms']
            continue
        pr = b['per_round_median_ms']
        t5 = sum(x for k, x in pr.items() if int(k[2:]) >= 5)
        c5 = sum(1 for k in pr if int(k[2:]) >= 5)
        t6 = sum(x for k, x in pr.items() if int(k[2:]) >= 6)
        tot = b['phases_median_ms']['total_unbatched_with_tables_gpu_ms']
        ndB = len(pr)
        tb5 += t5; tb6 += t6; n5 += c5; nA5 += max(0, ndA - 5); sa += r['median_ms']; sb += tot
        print(f'{s:>4} {r["median_ms"]:6.3f} {ndA:3d} {tot:6.3f} {ndB:3d} {t5:8.3f} {c5:6d} {(t5/c5 if c5 else 0):8.3f} {r["median_ms"]-tot:7.3f} {ndA-ndB:3d}')
    print(f'sum Arm B tail j>=5 {tb5:.3f} ms = {tb5/BLOCK[prof]*100:.2f}% of block; j>=6 {tb6:.3f} = {tb6/BLOCK[prof]*100:.2f}%')
    print(f'rounds past the fifth in Arm A (nd-5, summed) {nA5}; in Arm B {n5}; extra batched rounds {nA5-n5}')
    head = sb - tb5
    print(f'Arm B head (tables + rounds 0..4) {head:.3f} ms; Arm A slots {sa:.3f}; A - head = {sa-head:.3f} ms = {(sa-head)/BLOCK[prof]*100:.1f}% of block (upper bound: whole batch gap counted as tail)')
    if prof == 'w16r2_8b':
        cen = tb5 + EXTRA_MS
        print(f'central (B tail + measured 3 extra rounds/slot) {cen:.3f} ms = {cen/BLOCK[prof]*100:.1f}% of block; per request x{NBLK[prof]} = {cen*NBLK[prof]/1000:.3f} s')
        print(f'range {tb5:.2f} to {sa-head:.2f} ms = {tb5/BLOCK[prof]*100:.1f}% to {(sa-head)/BLOCK[prof]*100:.1f}%')
        hid = [1 - 52/228, 1 - 82/228]
        print(f'stream hiding of the removed 3 rounds: solo 7.119 x 32 = {EXTRA_MS*32:.0f} ms/req; 2-lane forks fell 52..82 ms -> hidden {hid[1]*100:.0f}..{hid[0]*100:.0f}%')
        for t in (cen, sa - head):
            lo, hi = t * 32 * (52/228), t * 32 * (82/228)
            print(f'  whole tail {t:.1f} ms solo -> if free, stream saving {lo:.0f}..{hi:.0f} ms/req = {lo/3745.5*100:.1f}..{hi/3745.5*100:.1f}% of the 3.7455 s cadence')
