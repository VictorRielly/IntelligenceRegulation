# ZKP efficiency progress

Cycle 0066 — `20261017T192105Z-c342a26b`, 2026-10-17 UTC.

**No proving speedup found.** Rebuilding lookup helpers from A using field
arithmetic changes malformed-witness values and helper refusals. A private-bit
reconstruction prototype matches 4,176 columns, 106,962 field words and 35 H
fixtures. The independent audit passes 5,375 checks. One CPU thread; main
4.337 s, audit 0.192 s, compiler peak 130.7 MiB.
[Review handoff](handoffs/20261017-resident-helper-integer-boundary.md) includes
the compiled interface and native gates. No native proof or GPU job ran here.

At the earlier T128 geometry, counted lookup storage is 221.25 MiB versus a
0.609 MiB private bitmap; U8 H still needs 235.25 MiB. Tagged device commitment
and host-reader coherence remain unresolved. Even deleting the entire earlier
1.1B U8 helper phase caps the GPU-assisted process gain at 1.058×.

Carried owner 8B diagnostic: context 32, one cold pass per CPU / RTX 4070 Laptop
arm, 384.54 / 391.29 s. Diagnostic rates: 0.08322 / 0.08178 positions/s, including
in-process checking. Witness: 18.63 / 18.11 s; inclusive proving: 208.02 / 213.83 s,
including reloads. Serialization is unisolated. Partial load/seal startup:
21.60% / 20.34%; full startup and steady-state/target workload rates are unknown.
Fresh check: 96.10 / 90.94 s plus initial load 80.68 / 78.64 s. D24 round 3
accepts 8B-profile soundness; shape privacy remains open. New target-compliant
proofs/passes/positions: **0 / 0 / 0**. No long-prefill, resident-pass or decode
sweep. The >=50 proved-token/s target remains unchanged and unachieved.

Five LIVE primary records added. Next owner: complete device/enclosing-proof
gates and clocks. Next local: Logup* pushforward privacy and binding-cost audit.
[Dated report](progress/20261017T192105Z-c342a26b.md) has full clocks, hypotheses, sources and blockers.
Production, runtime and Git were untouched. Saved reports do not establish delivery.
