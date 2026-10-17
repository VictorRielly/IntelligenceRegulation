# ZKP efficiency progress

Cycle 0068 — `20261017T212105Z-f1b8cd7d`, 2026-10-17 UTC.

**No proving speedup found.** The Rust batching adapter passes 96 fixtures,
3,744 field values and 19 controls; independent audit: 4,136 checks. Reusing
one scalar across all column coordinates fails: the 83 column weights have
rank seven, allowing fixed errors to cancel. Private virtual evaluations
still require joint hiding. One CPU thread; main 0.417 s, audit 0.059 s,
compiler peak 125.8 MiB. No native or GPU proof ran.

Counted padding at 8B T32: six domain batches visit 1.70× the original queries,
four equal-length groups 1.52×, one global cube 5.73×. Four pushforwards use
16,384 logical bytes before masks. Native masking, binding and reduction costs
remain unknown. [Unapplied handoff](handoffs/20261017-logup-batch-domains.md).

The owner's cold CPU 8B T32 receipt now freshly verifies with 11 controls:
171.578 s application / 171.641 s process, about 0.1865 diagnostic positions/s.
Witness: 21.376 s within 156.143 s inclusive proving; serialization unisolated.
Partial startup: 8.943%. Fresh check: 26.491 s plus 13.165 s load; the entire
115.869 s verifier process includes controls. Steady rate and trained-shape
privacy acceptance remain open. Free deletion of four entire H phases gives
only 1.128× with other work fixed, before added costs.

New target proofs/passes/positions: **0/0/0**. No resident repeats, long prefill
or decode; target steady and total rates remain unmeasured. The >=50/s private
8B GPU target stands. Seven LIVE primary records added. Next: ragged round
oracle with independent points; owner whole-prover GPU and workload slopes.
[Dated report](progress/20261017T212105Z-f1b8cd7d.md).
Production, runtime and Git untouched. Saved reports do not establish delivery.
