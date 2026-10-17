# ZKP efficiency progress

Cycle 0064 — `20261017T142624Z-6b84b6ef`, 2026-10-17 UTC.

**Exact synthetic F-slot candidate; no native proof speedup established.**
The current FFN zero-check can use three grouped equality brackets. Seventy-two
fixtures, 960 independent original-cube round checks, 12 mutation controls
and a separate 290-check audit pass. Small tables regress; larger synthetic
tests show 1.03–1.42x, with shared-host variability. Main-bracket calls fall
about 22% in the large-domain count; equality setup, inversions and dispatch
add costs. One CPU thread, 7.06 s, under 147 MiB compiler RSS. No GPU/native
proof job. [Unapplied handoff](handoffs/20261017-fzc-grouped-equality.md).

Owner baseline remains one complete functional 8B T32 cold pass per arm:
CPU 384.54 s / RTX 4070 Laptop 391.29 s, diagnostic 0.08322 / 0.08178
positions/s. Witness 18.63 / 18.11 s; inclusive proving 208.02 / 213.83 s
includes reload 79.22 / 78.00 s. Proof remainder 110.17 / 117.73 s includes
serialization/sink. Initial load+seal is 21.60% / 20.34% of internal total,
only a partial startup boundary. In-process verify 93.36 / 92.74 s; fresh
check 96.10 / 90.94 s plus initial load 80.68 / 78.64 s. Full startup/prefill,
isolated serialization and steady slope are unknown. No resident-pass sweep,
longer-context sweep or decode ran here. Shape privacy and 8B review stay open.

Six LIVE primary source records added. Even deleting the whole F masked
sumcheck caps direct gain at 1.113x on the earlier trained 1.1B GPU diagnostic;
this candidate affects only part. No 8B/5090 extrapolation. Next local: audit
actual F-device traffic against the proposed logical bandwidth metric. Owner
next: native byte/refusal/privacy/fresh-verifier gates and enclosing timing,
coordinated with the active F-device lane and shared resource locks.

Accepted target-compliant new 8B proofs/passes/positions: **0 / 0 / 0**.
The >=50/s target is unchanged and unachieved. Larger workloads may amortize
setup with fresh masks; dense attention can grow quadratically. Production,
runtime, Git, calibration, receipts and gates were untouched; no external
messages were sent. [Dated report](progress/20261017T142624Z-6b84b6ef.md)
retains all clocks, sources and limits. Saved reports do not establish message
delivery or supervisor liveness.
