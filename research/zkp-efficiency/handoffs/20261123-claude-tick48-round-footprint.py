#!/usr/bin/env python3
"""Tick 48 (queue item 80): live fp2 values per thread in the zero-check round kernels, and a stepped
occupancy model fitted to the tick 46 ladders. Standard library only. Run: python3 -I -B <this file>.
Reads the generated Metal sources the tick 46 ladder compiled (verbatim k_sc_round_base) and its README numbers.
Nothing is built or run on the GPU."""
import re, sys
from pathlib import Path

B = Path("/Users/victorrielly/IntelligenceRegulation/results/zk60_tick46_occ_ladders_20261123/build")
FP2 = 16  # bytes: two ulong (4 x 32-bit registers)


def loop_body(src):
    i = src.index("kernel void k_sc_round_base")
    j = src.index("kernel void k_sc_round_pad")
    k = src[i:j]
    a = k.index("for (ulong i = ulong(gid)")
    a = k.index("\n", a) + 1
    b = k.rindex("acc = f2_add(acc, out);")
    return k[a:b].splitlines()


def parse(lines):
    stmts = []  # (name, set(of names used))
    for ln in lines:
        m = re.match(r"\s*fp2 (\w+) = (.*);\s*$", ln)
        if not m:
            continue
        name, expr = m.groups()
        used = set(re.findall(r"\b([vn]\d+)\b", expr))
        used.discard(name)
        stmts.append((name, used, expr))
    return stmts


def live_profile(stmts, sink_loads):
    """Return (max live fp2 values, statement index of the max). Values: v (table loads), n (nodes), out.
    Written order. If sink_loads, a v-load is placed just before its first use (compiler may do this);
    else loads stay where written (all 39 / 22 at the top). A value dies after its last use.
    'out' is the last statement; out accumulates into acc (acc is counted separately)."""
    last = {}
    first = {}
    for idx, (name, used, _) in enumerate(stmts):
        for u in used:
            last[u] = idx
            first.setdefault(u, idx)
    live = set()
    best = (0, -1)
    for idx, (name, used, expr) in enumerate(stmts):
        if name.startswith("v") and sink_loads:
            # not alive until first use
            continue_defer = True
        # make sure any sunk loads this statement uses are live now
        if sink_loads:
            for u in used:
                if u.startswith("v"):
                    live.add(u)
        if not (name.startswith("v") and sink_loads):
            live.add(name)
        # at this point inputs and output are all live (a mul needs both inputs and the result)
        cur = len(live)
        if cur > best[0]:
            best = (cur, idx)
        for u in list(live):
            if last.get(u, -1) <= idx and u != name:
                live.discard(u)
        if name not in last:
            live.discard(name)
    return best


def tabs_loaded(stmts):
    return sum(1 for n, _, _ in stmts if n.startswith("v"))


def main():
    out = {}
    for label, f in (("slot14", "z_occ_s14.metal"), ("slot18", "z_occ_s18.metal")):
        src = (B / f).read_text()
        st = parse(loop_body(src))
        nv = tabs_loaded(st)
        nn = sum(1 for n, _, _ in st if n.startswith("n"))
        up, upi = live_profile(st, sink_loads=False)
        lo, loi = live_profile(st, sink_loads=True)
        print(f"{label}: statements {len(st)} (loads {nv}, nodes {nn})")
        print(f"  written order, loads where written: max live fp2 = {up} at statement {upi} ({st[upi][0]}) = {up*FP2} B")
        print(f"  written order, loads sunk to first use: max live fp2 = {lo} at statement {loi} ({st[loi][0]}) = {lo*FP2} B")
        out[label] = (up, lo)
    # fixed part (ASSUMED, not read from an ISA dump): acc 4 regs, i 2, gid 1, d 1, dd 2, np/grp/di 3, bounds a.nhalf a.cap
    # a.nthreads 4-6, transients of one ln_ext (l, h, dd product, ~12 regs), one f2_mul reduction (~10 regs)
    fixed_lo, fixed_hi = 24, 40  # 32-bit registers, ASSUMED
    print(f"fixed registers (ASSUMED): {fixed_lo} to {fixed_hi} x 4 B = {fixed_lo*4} to {fixed_hi*4} B")
    print()
    tot = {}
    for s, (up, lo) in out.items():
        tot[s] = (lo * FP2 + fixed_lo * 4, up * FP2 + fixed_hi * 4)
        print(f"{s}: footprint per thread, lower {tot[s][0]} B ({tot[s][0]//4} regs), upper {tot[s][1]} B ({tot[s][1]//4} regs)")

    # ladder data (tick 46 README): (L bytes per 64-thread group, t(L)/t(0))
    data = {
        "slot14": [(0, 1.0), (2048, .9994), (4096, .9898), (8192, .9798), (16384, 1.3413), (32768, 2.0651)],
        "slot18": [(0, 1.0), (2048, .9993), (4096, .9916), (8192, .9951), (16384, 1.5181), (32768, 3.1974)],
    }
    print("\nModel A (proportional): t/t0 = max(1, (r + l)/F*), l = L/64 bytes per thread, r = the kernel's own bytes per thread")
    for s, d in data.items():
        (l1, t1), (l2, t2) = [(L / 64, t) for L, t in d[-2:]]
        slope = (t2 - t1) / (l2 - l1)
        Fs = 1 / slope
        r = t1 * Fs - l1
        print(f"  {s}: slope {slope:.5f}/B -> F* {Fs:.0f} B, r {r:.0f} B; predicted t(128 B/thread) = {max(1,(r+128)/Fs):.3f} (measured {d[3][1]:.3f})")

    print("\nModel B (integer groups): G = floor(P / (64 r + L)), t/t0 = (a + (1-a) * Gs/G) / 1 for G < Gs else 1 at G >= Gs")
    best = {}
    for s, d in data.items():
        cands = []
        for P in range(32768, 262145, 4096):
            for r_regs in range(20, 130, 2):
                r = r_regs * 4
                for Gs in range(2, 17):
                    for a in (0.0, 0.2, 0.4, 0.5, 0.6, 0.8):
                        e = 0.0
                        for L, t in d:
                            G = max(1, P // (64 * r + L))
                            pred = 1.0 if G >= Gs else a + (1 - a) * Gs / G
                            # normalise to L = 0
                            G0 = max(1, P // (64 * r))
                            p0 = 1.0 if G0 >= Gs else a + (1 - a) * Gs / G0
                            e += (pred / p0 - t) ** 2
                        cands.append((e, P, r_regs, Gs, a))
        cands.sort()
        best[s] = cands[:6]
        print(f"  {s}: six best fits (sse, P bytes per core, r regs, Gs, a):")
        for c in cands[:6]:
            print(f"    sse {c[0]:.4f}  P {c[1]}  r {c[2]} regs ({c[2]*4} B)  Gs {c[3]}  a {c[4]}")
    print("\nModel C (thread-group memory only, registers not in the pool): G = floor(P / L) groups of 64 threads per core, G = infinity at L = 0;")
    print("  t/t0 = 1 if G >= Gs else a + (1-a) * Gs / G.  P = 32 KiB is the figure of a developer-forum answer (unverified); others for sensitivity.")
    for s, d in data.items():
        for P in (32768, 49152, 61440, 65536):
            cands = []
            for Gs10 in range(10, 81, 5):
                Gs = Gs10 / 10
                for a100 in range(0, 91, 5):
                    a = a100 / 100
                    e = 0.0
                    for L, t in d:
                        G = float("inf") if L == 0 else P // L
                        pred = 1.0 if G >= Gs else a + (1 - a) * Gs / G
                        e += (pred - t) ** 2
                    cands.append((e, Gs, a))
            cands.sort()
            c = cands[0]
            gs = {L: ("inf" if L == 0 else P // L) for L, _ in d}
            print(f"  {s} P={P}: best sse {c[0]:.4f} at Gs {c[1]}, a {c[2]}; G at L = {gs}")
    # the downward-ladder reading under model C: what a flat curve says
    print("\nPredictions of the P = 32 KiB model C fit for the points NOT used to fit it are the flat ones; it cannot explain slot 14's 0.98 (round 1: 0.91).")
    return best


if __name__ == "__main__":
    main()
