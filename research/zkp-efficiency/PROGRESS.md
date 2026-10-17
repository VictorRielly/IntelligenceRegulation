# ZKP efficiency progress

Cycle 0069 — `20261017T222105Z-d6d7aa4d`, 2026-10-17 UTC.

**No proving speedup found.** A Rust padding experiment passes 94 fixtures,
23 controls and an independent 5,185-check audit. Native MSB folding mixes
padding immediately if column bits come first. Putting row bits first avoids
34.3% of hypothetical base-round pairs at counted 8B T32 sizes. Both layouts
match their own dense polynomials; native proof compatibility and a complete
private lookup protocol remain open. Main 2.038 s including compile/oracles;
compiler peak 131.4 MiB; one CPU thread, no GPU/proof job.

Naive index/factor payload sums to 625.625 MiB across four groups before
scratch; public weights alone sum to 178.75 MiB. These are aggregate counts,
not peak memory. Masks stay over the whole cube; zero Boolean products do not
justify skipping factor support. Next: implicit equality/support factors.
[Unapplied handoff](handoffs/20261017-ragged-logup-rounds.md).

Carried verified 8B T32 CPU baseline: one cold pass, 171.578 s application /
171.641 s process, about 0.1865 diagnostic positions/s. Witness 21.376 s within
156.143 s inclusive proving; serialization unisolated. Partial startup 8.943%.
Fresh check 26.491 s plus 13.165 s load. Steady rate and trained-shape privacy
acceptance remain open. Owner R5b changes startup, so older clocks need
remeasurement; owner whole-prover GPU work remains higher priority.

New target proofs/passes/positions: **0/0/0**. No resident repeats, long prefill
or decode. >=50/s private 8B GPU target remains unachieved. Eight LIVE primary
records added, including October SP1 changes and older accumulation leads.
[Dated report with clocks, sources and rankings](progress/20261017T222105Z-d6d7aa4d.md).
Production, runtime and Git untouched. Saved reports do not establish delivery.
