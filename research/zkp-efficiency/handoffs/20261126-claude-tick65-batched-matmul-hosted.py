#!/usr/bin/env python3
"""Tick 65 (queue item 108): counts for merging the seven weight-matmul slots into one batched sumcheck (or four).
Standard library only, reads no file. Shapes are the 8B profile's padded axes (shape.rs:2683-2693 as read in tick 63):
d_pad 4096, q_pad 4096, kv width 1024, f_pad 16384. A round message is ASSUMED at most 3 Fp2 coefficients (degree 2) of
16 B; the true wire encoding was not read, so the byte figures are upper bounds. Receipt per block: tick 54's 818.7 MB / 32.
"""
import math
lg = lambda x: int(math.log2(x))
d, q, kv, f = 4096, 4096, 1024, 16384
inner = {"Q": lg(d), "K": lg(d), "V": lg(d), "Wo": lg(q), "G": lg(d), "U": lg(d), "Wd": lg(f)}
EXT = 1                      # one extension round per matmul slot (shape.rs:2705)
ROUND_B = 3 * 16             # ASSUMED upper bound, bytes per round message
today = sum(inner.values()) + EXT * 7
full = max(inner.values()) + EXT
groups = {"QKV": ["Q", "K", "V"], "Wo": ["Wo"], "GU": ["G", "U"], "Wd": ["Wd"]}
part = sum(max(inner[m] for m in ms) + EXT for ms in groups.values())
print("inner bits:", inner)
print(f"round messages a block: today {today} ; four groups {part} ; one batch {full}")
blk = 818_728_672 / 32
for name, r in (("today", today), ("four", part), ("one", full)):
    print(f"  {name:>5}: <= {r*ROUND_B} B a block of rounds = {100*r*ROUND_B/blk:.4f}% of one block's receipt ({blk/1e6:.2f} MB)")
print(f"  saving, one batch: <= {(today-full)*ROUND_B} B a block = {100*(today-full)*ROUND_B/blk:.4f}%")
# private terminals (one A claim per matmul slot today, claim_sites shape.rs:2607-2609)
print("A terminals a block: today 7 ; four groups 4 (QKV share A_Y at (r_q, rho), GU share A_YM at (r_tf, rho)) ; one batch 4 (Wo reads A_O8, Wd reads A_H16)")
# padding of shorter instances in one 14-round batch: factor 2^(14 - n_k) on the claimed total of an instance placed with trailing dummy rounds
for m, b in inner.items():
    print(f"  {m}: 14-round batch pads {14-b} dummy rounds, claimed total scaled by 2^{14-b} = {2**(14-b)}")
# the hosted pairs are batched by nu in the HOST slot, drawn after the matmul slots have published their scalars
print("hosts (layout.rs:1107-1114): DZC [Wo,Dmm], QZC [Qmm,PV], KVZC [Kmm,Vmm], SZC [RS,SCORE], FZC [Gmm,Umm], TZC [SS,SSM]")
print("slot order (layout.rs:982-990): QMM 5, SCORE 8, PV 9, WO 10, DMM 13: every hosted private slot runs before its host (test layout.rs:1642-1652)")
