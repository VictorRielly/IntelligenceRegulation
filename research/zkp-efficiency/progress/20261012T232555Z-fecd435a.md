# ZKP efficiency progress

Cycle 0042 — `20261012T232555Z-fecd435a`, checkpoint 2026-10-12T23:42:56.893288+00:00.

**Lifted Ht host collapse passes synthetic arithmetic; no native proving speed
improvement measured.** The final check took10.822s/22528KiB RSS on one
Core Ultra9 thread.32 SC_SZC fixtures, original-cube/degree/claim/final/
extension checks and13 controls pass. An initial invalid negative-control
comparison is preserved; its corrected full-cube test detects S/Ht substitution.
False lift attestations are invalid, so native constructor provenance is required.

At conditional T512/h_pad16, host bracket calls fall10,485,758 ->20,487.
All other groups/scans/folds remain. Including unchanged table folds, the
selected multiplication API count falls2.87086%; added host reads carry524512B.
These are counts, not native seconds or full-model throughput. The candidate
is modest and needs affected-phase timing before a port.

[Experiment](experiments/ht-host-axis-collapse-20261012/README.md) and
[owner handoff](handoffs/20261012-ht-host-axis-collapse.md) retain commands,
seed, logs, source pins, independent oracle, cost study and an uncompiled
Rust helper at argument.rs SC_SZC/priv_table and grouped.rs round.
Four LIVE records added: Plonky3 release/strategy, newly assessed older
Bootle-Chiesa-Sotiraki2021 and an author packed-mask README. Dates/license/
commit limits and fetch failures saved; no downloaded code run.

Accepted independently verified complete private8B proofs/tokens:**0**.
Device CPU only;proof context null;passes0. Steady-state and total-workload
rates,startup seconds/fraction,witness/proof/serialization/independent
verification,latency/lag/drain remain unmeasured. No prefill,resident-model
pass or decode proof.>=50proved tokens/s target and full privacy unchanged.
No production changes,build,GPU,install,Git,heavy queue or external messages.

Next local:compact private A_MX/A_SUM leading readers through mixed grouped
round/bind/finals, with immutable source mapping and arbitrary private
extension checks. Next owner:dominant SZC/recurring witness clocks and native
masked gates;measure host share before considering this port. Saved reports
are not evidence of notification delivery.
