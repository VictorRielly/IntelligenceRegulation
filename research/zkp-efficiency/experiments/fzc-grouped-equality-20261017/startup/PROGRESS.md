# ZKP efficiency progress

Cycle 0063 — `20261017T132624Z-393ef603`, 2026-10-17 UTC.

**Small synthetic gain; no native proof speedup established.** The captured
F zero-check matches an independent Python reference in 2,480 comparisons
across 480 fixtures; nine mutation controls and a separate 45-check audit pass.
The combined constant/support rewrite removes seven general Fp2 products
per evaluation, adds five base products, and gives about 1.10x in a short
padded CPU microbenchmark. Support-only is slightly slower without padding;
that negative is retained. One CPU thread, under 2.1 s per experiment, under
139 MiB measured child RSS. [Unapplied handoff](handoffs/20261017-fzc-public-constants.md).

New owner logs now contain freshly verified complete functional **8B T32**
stack diagnostics: 32 linked blocks, one cold pass per arm. CPU 384.54 s / RTX
4070 Laptop 391.29 s, diagnostic 0.08322 / 0.08178 positions/s. Witness
18.63 / 18.11 s; proof minus witness/reload 110.17 / 117.73 s still includes
serialization/sink. Initial load 83.01 / 79.49 s and proving reload
79.22 / 78.00 s make public residency worth testing. In-process verification
93.36 / 92.74 s; fresh check 96.10 / 90.94 s plus initial load 80.68 / 78.64 s.
Load+seal is 21.60% / 20.34% of internal total, only a partial startup boundary.
Receipt 465,815,776 B per arm. No measured steady slope,
full startup/prefill fraction, isolated serialization or lag/drain. Shape
privacy acceptance and independent 8B review remain open; these logs were
inspected, not reproduced by this researcher.

Five LIVE primary source records appended. Next local: three-bracket F grouped
equality oracle. Owner next:real-lane correctness/byte/privacy/fresh-verifier
checks, 8B phase clocks and safe public-weight reuse with memory accounting.
The earlier 1.1B GPU F phase's entire deletion ceiling is only 1.137x; no 8B or
5090 speed estimate follows from this patch.

Accepted target-compliant private 8B proofs/passes/positions remain **0 / 0 / 0**.
No resident-pass sweep, long-context sweep or decode ran here. Larger workloads
remain permitted with fresh masks and complete independently verified proofs;
longer attention can grow quadratically. The >=50-token/s target is unchanged
and unachieved. [Dated report](progress/20261017T132624Z-393ef603.md) records
all clocks, limits, hypothesis rankings and sources.

Research only; no production/runtime/Git/native proof/GPU/external messages.
Saved reports do not establish delivery or supervisor liveness.

Final audit found live owner changes to layout/shape validation guards. The
tested F closure remains pinned; the handoff requires review against the new
source. The failed live-pin check and drift are preserved.
