# ZKP efficiency progress

Cycle 0072 — `20261018T012105Z-ac328993`, 2026-10-18 UTC.

**No native proving speedup found.** A host-compiled helper splits native
late-stage NTT roots into a small table factor and a canonical power-of-two
shift. Main: 280,366 checks and 18 controls pass; independent tiled DIT/DIF,
swizzle, padding and polynomial audit: 1,452 checks pass. Main 3.353 s including
compilation; audit 6.312 s, one Core Ultra 9 185H CPU thread, no GPU/native proof.

Proposed both-direction root tables at N=2^20: 16 MiB -> 0.5 MiB, with
6.6 million added shifts per transform versus the prior shift candidate.
These are logical counts. Host tables remain; existing uploads are cached;
no DRAM, memory-peak or throughput improvement measured. Generic consecutive
products nearly double general multiplications in a large stage.
[Unapplied handoff](handoffs/20261018-native-root-compression.md).

Latest owner round 3: warm F-slot body 28.25–29.83 ms, seeded bytes equal at
all four shapes. Enclosing default/warm stacks plus fresh verification queued;
no enclosing round-3 result captured. Do not duplicate its jobs.

Carried 8B T128 CPU baseline: 32 blocks, one cold pass, fresh independent
verification; 606.598 s app / 606.728 s process, diagnostic 0.211 positions/s.
Seal 105.287 s (17.357%) is a phase fraction, not isolated startup; witness
103.349 s overlaps seal, another 122.694 s is inside 501.126 s proving.
Serialization unisolated; fresh verifier load 14.126 s + check 43.902 s.
Steady rate/full startup/prefill/lag/drain unknown. Review accepts R5b soundness
and T64/T128 arithmetic; trained-shape privacy acceptance remains open.

Six LIVE primary records added: NTT OT/fusion, current GPU repositories and
releases, recent CGLA exactness/scope. Next local: audit the owner's derived
F-slot arithmetic counts, charging build/fold and base-round eligibility.
[Dated report: clocks, rankings, sources and limits](progress/20261018T012105Z-ac328993.md).

New target proofs/passes/positions **0/0/0**. No resident repeats, long prefill
or decode; target steady/total rates and phase clocks unmeasured this cycle.
>=50/s complete private 8B on a named high-end GPU remains unachieved.
Production/runtime/Git untouched. Saved reports do not establish delivery.
