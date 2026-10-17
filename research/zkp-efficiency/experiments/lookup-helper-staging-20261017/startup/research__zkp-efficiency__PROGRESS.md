# ZKP efficiency progress

Cycle 0065 — `20261017T182105Z-44205280`, 2026-10-17 UTC.

**A GPU traffic accounting correction; no proving speedup measured.**
The captured F-device functions pass 96 synthetic fixtures and 384 schedules.
Direct fusion removes about 20% of round/fold table accesses, or 15.38% with
counted construction. The design note overstates that saving; its Rust direct
counter is consistent. Lean fusion rereads folded tables. Eq construction
counts output bytes. Hardware traffic and GPU performance remain unmeasured.
Thirteen controls and an independent schedule/Eq audit pass. Each CPU
experiment took under one second, one thread, under 35 MiB compiler RSS.
[Review handoff](handoffs/20261017-fzc-device-traffic.md) is unapplied.

Carried-forward owner 8B T32 baseline, one cold pass per arm: CPU 384.54 s /
RTX 4070 Laptop 391.29 s; diagnostic rates 0.08322 / 0.08178 positions/s.
Witness: 18.63 / 18.11 s. Inclusive proving: 208.02 / 213.83 s, including
reloads. Serialization is not isolated. Load/seal is 21.60% / 20.34% of
internal total; full startup and steady rate are unknown. Fresh verification:
96.10 / 90.94 s plus initial load 80.68 / 78.64 s. No resident-pass, longer
prefill or decode sweep. Privacy acceptance and 8B review remain open.
New target-compliant proofs/passes/positions: **0 / 0 / 0**. The >=50/s target
is unchanged and unachieved.

Six LIVE primary records added. Next owner: review counts and collect device
and enclosing-proof timings under native gates. Next local: audit lookup
helper representations and lifetimes. Kernel/Rust pins match; an updated
owner ledger is retained separately and is not a successful device result.
[Dated report](progress/20261017T182105Z-44205280.md) holds full clocks,
hypotheses, sources and blockers. Production, runtime and Git were untouched.
Saved reports do not establish message delivery.
