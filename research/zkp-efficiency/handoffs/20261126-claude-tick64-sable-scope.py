# Tick 64 arithmetic: Sable v2 (arXiv 2611.14083) Section 10.2 figures set beside this prover's rates.
# Inputs [authors]: 2^16 compressions 0.16 s (13 ms commit, 0.13 s domain proofs, 15 ms openings), 2^18 compressions 0.33 s,
# 5,344 cells a compression, 2^22 G rows at 2^16 compressions, 4.2 M compressions -> 5.5 s, 9.2 M -> 12 s.
# Inputs from earlier ticks: 1.094 ns per committed word (MEASURED), 6.99-7.08 M compressions at B6a (tick 62), 3.18 s cadence.
import datetime
print("clock", datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
N16, N18 = 2**16, 2**18
T16, T18 = 0.16, 0.33
print("sum of parts at 2^16:", 0.013 + 0.13 + 0.015, "s vs 0.16")
print("us per compression 2^16, 2^18:", T16 / N16 * 1e6, T18 / N18 * 1e6)
print("G rows per compression at 2^16:", 2**22 / N16, " cells per row:", 5344 / 64)
print("5344 - 64*80 =", 5344 - 64 * 80)
# two-point linear fit T = a + b*N; rounding band +-0.005 s on each time
for dt16, dt18 in [(0, 0), (-0.005, 0.005), (0.005, -0.005)]:
    b = ((T18 + dt18) - (T16 + dt16)) / (N18 - N16)
    a = (T16 + dt16) - b * N16
    print("fit  a=%.3f s  b=%.3f us/compression" % (a, b * 1e6))
print("authors' projections: 5.5/4.2e6 =", 5.5 / 4.2e6 * 1e6, "us; 12/9.2e6 =", 12 / 9.2e6 * 1e6, "us; 5.5/92.5 =", 5.5 / 92.5)
lo_n, hi_n = 6.99e6, 7.08e6
cad = 3.18
def row(name, us_lo, us_hi, fixed=0.0):
    lo = lo_n * us_lo * 1e-6 + fixed; hi = hi_n * us_hi * 1e-6 + fixed
    print("%-52s %6.1f to %6.1f s   %4.1f to %4.1f cadences" % (name, lo, hi, lo / cad, hi / cad))
row("Sable 2^18 rate 1.3 us", 1.3, 1.3)
row("Sable 2^16 rate 2.4 us", 2.4, 2.4)
row("Sable marginal fit 0.80-0.91 us + 0.10 s fixed", 0.80, 0.91, 0.10)
own = 5344 * 1.094e-3  # us per compression at our word rate
print("own word rate x 5,344 cells:", own, "us per compression")
row("own word rate x 5,344 cells", own, own)
# transfer factors (ASSUMED hardware numbers; our copy roofline MEASURED about 700 GB/s, tick K0)
bw_sable, bw_ours = 1792.0, 700.0  # GB/s: spec of the Sable GPU is ASSUMED from memory, not read this tick
print("bandwidth ratio:", bw_sable / bw_ours, " cell width ratio 8 B / 4 B:", 2.0)
for us in (1.3, 2.4):
    print("scaled by bandwidth only %.1f -> %.2f us; by bandwidth and width %.1f -> %.2f us" %
          (us, us * bw_sable / bw_ours, us, us * bw_sable / bw_ours * 2))
print("ratio own/Sable:", own / 2.4, own / 1.3)
