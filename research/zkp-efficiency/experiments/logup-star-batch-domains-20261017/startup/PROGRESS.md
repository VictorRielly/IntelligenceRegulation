# ZKP efficiency progress

Cycle 0067 — `20261017T202105Z-363d38a1`, 2026-10-17 UTC.

**No proving speedup found.** The Rust pushforward passes 405 fixtures and
23,166 Fp2 values; independent audit passes 24,014 checks. A naive private
LogUp* port fails: an unmasked virtual evaluation can reveal a hidden lookup
even if its commitment hides the contents. Ordered binding and whole-table
refusals remain necessary. One CPU core; main 0.357 s, audit 0.089 s,
compiler peak 119.3 MiB. No native/GPU proof ran.
[Research handoff](handoffs/20261017-logup-star-private-view.md).

Current 8B T32 U8 H: 1,514 rows / 94.625 MiB; all H: 1,758 rows / 109.875 MiB.
These are gross payloads. New GKR, masking and PCS costs are unknown. The
owner's newer R5 CPU T32 diagnostic takes 171.578 s: witness 21.376 s inside
inclusive proving 156.143 s, serialization unisolated. Partial load/seal
startup is 8.943%; full startup and steady slope unknown. Fresh cli3
verification was not observed at 20:31:20 UTC, so no positions credited here.
Free deletion of its four entire H phases caps their direct effect at 1.128x
with other work fixed, before added costs.

Carried R4 independently verified cold T32 CPU / RTX 4070 Laptop diagnostics
remain 0.08322/0.08178 positions/s, with different check placement/contention.
The dated report retains full clocks and limitations. Shape privacy is open.
New target proofs/passes/positions: **0/0/0**. Target steady/total rates and
clocks unmeasured; no resident sweep, long prefill or decode ran. The >=50/s
private 8B GPU target stands.

Eight LIVE primary records added. Next: batch 83 U8 columns and charge every
new terminal/mask site; owner completes fresh gates and workload slopes.
[Dated report](progress/20261017T202105Z-363d38a1.md).
Production, runtime and Git untouched. Saved reports do not establish delivery.
