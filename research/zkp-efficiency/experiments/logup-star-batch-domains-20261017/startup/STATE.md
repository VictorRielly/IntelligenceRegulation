# ZKP efficiency explorer — durable state

Cycle 0067 COMPLETE: `20261017T202105Z-363d38a1`.
Checkpoint: 2026-10-17T20:34:48.424601+00:00. Next cycle no earlier than 2026-10-17T21:21:05Z.
Read AGENDA, target, durable/project memory, all 342 prior sources and latest
three results. Startup snapshots: experiments/logup-star-private-pushforward-20261017/startup/.
FINDINGS appended; source prefix preserved; now 350 source records.
Full report: progress/20261017T202105Z-363d38a1.md.

No proving improvement found. The std-only Rust pushforward uses captured
native Fp2. It passes 405 fixtures, 23,166 bucket values, 405 virtual claims,
405 support checks and 14 controls. Independent polynomial-convolution/count
audit: 24,014 checks, three binding controls and 17 exhaustive F17 challenges.
Main 0.356768 s / 28,256 KiB; compiler 122,168 KiB; audit 0.088526 s / 24,432
KiB. One Core Ultra 9 185H CPU core, CPU0, nice 19, seed 2026101767,
59-second / 512-MiB caps. No native crate, proof or GPU ran.

New negative: hiding the pushforward commitment alone leaves an unmasked
virtual evaluation leaking a single lookup via a known equality weight.
Twenty Fp2 controls recover the synthetic secret. Same-histogram orderings
differ at 16 of 17 F17 points; r=1/2 is degenerate. Self-consistent replacement
arithmetic still requires original ordered binding. Zero-sum masks generally
change the value; orthogonal masks preserve the leaking scalar. Fresh scalar
pad uniformity is only a marginal toy, not a private lookup protocol; reuse
leaks differences. Whole-table unused zero refusal remains as an event, not a
native draw/order replay. Prior D/C, zero-zero, padding and integer-wrap
negatives stand. No native/upstream accepted-proof attack is claimed.

Current 8B T32 per block: 83 U8 columns / 11,714,560 queries. U8 H data:
1,514 base rows / 99,221,504 B; total H: 1,758 rows / 115,212,288 B.
Looked arrays are already uncommitted, so extra query commitment saving is
zero. One 256-entry Fp2 pushforward has 4,096 logical bytes, or 131,072 B
at the current 8,192-wide row lift before masks. These are gross counts,
not net rows, peak or traffic. GKR, ordered A/affine links, support/refusals,
fresh masking, PCS, M sites and serialization remain uncosted.

Latest owner R5 cli3 CPU diagnostic: 8B, 32 linked blocks, T32, one cold pass,
16 threads. Total 171.578 s; witness 21.376 s inside inclusive proving
156.143 s, including reloads 15.993 s. Remainder 118.774 s includes proof,
serialization and sink. Partial load/seal 15.345 s = 8.943%; full startup,
steady slope, isolated serialization, latency, lag and drain unknown.
Fresh cli3 verification terminal was absent at 20:31:20 UTC; no positions
credited, no liveness inferred. H commit/open/U8/exp-act clocks total 19.5 s;
free deletion gives a 1.128224x ceiling only with other work fixed, not a
whole-architecture/GPU/5090 bound. Earlier R5 cli2 CPU 267.8 s has fresh
verify 45.777 s, but four controls had weaker refusal locations, subsequently
strengthened. Different contention/check placement prevents clean A/B.

Carried R4 functional 8B T32: one cold pass per CPU / RTX 4070 Laptop arm,
16 threads. Process 384.542564/391.287091 s; diagnostic 32/process
0.083216/0.081781 positions/s includes in-process checks. Witness
18.629/18.109 s; inclusive proof 208.019/213.831 s includes reload
79.222/77.997 s; remainder 110.168/117.725 s includes serialization/sink.
Partial startup 21.595%/20.341%. Fresh check 96.103/90.935 s plus initial
load 80.675/78.635 s. Receipt 465,815,776 B. D24 round 3 accepts 8B soundness;
shape privacy and later R5/new-profile gates remain separate. Owner F-device
t10 equality/seeded gates and a freshly verified 1.1B T128 stack are recorded;
earlier VRAM violation, 255-register spills and about 5x enclosing body
slowdown remain visible. No 8B/5090 gain follows.

Ranked hypotheses:

1. OWNER whole-prover GPU arithmetic/residency: highest potential, high cost.
   CPU 8B phases D=28.79 s and F=16.64 s identify recurring work. Charge
   launches, scratch, transfers, fresh masks and drain. Native bytes,
   refusal/privacy mismatch or no enclosing gain falsifies a candidate.
2. OWNER public-model residency after R5: initial load 15.294 s and recurring
   reloads 15.993 s replace the old 80-second forecast. Add RAM, identity
   and invalidation. Measure fresh complete-pass slopes. Stale identities,
   memory failure or over 20 ms recurring work per newly proved position
   reject the relevant correctness or 50/s claim.
3. TESTED private LogUp* architecture: credit actual H displacement only,
   with zero additional query commitment saving. High GKR/PCS/mask/binding
   cost. Reject raw private evaluations, unbound terminals, changed refusals
   or support; no enclosing saving rejects its performance claim.
4. NEW batching of 83 U8 columns with a fresh terminal/mask budget. Compare
   with the unbatched illustration; test odd/padded columns. New points and
   masks may erase gains. Reject reference mismatches, challenges before
   binding, disclosed private channels or no net row saving after masks.
5. NEW older DUPLEX/Locq: authors claim private lookup, but RSA/KZG backends,
   setup and cross-PCS linkage are low-compatibility changes. Primary
   abstracts/metadata only; no performance reproduced.

Next local: an 83-column domain/batching differential oracle, odd-column
padding and census of every added terminal point and fresh mask site. Retain
the unmasked virtual-evaluation control. Next owner: finish cli3 fresh
verification/controls and complete fixed-context workload clocks/slopes under
shared locks. No owner job queued or duplicated here.
Unapplied handoff: handoffs/20261017-logup-star-private-view.md.

New target-compliant proofs/passes/positions: 0/0/0. Target steady-state and
total-workload rates and clocks remain unmeasured. No resident repeat, long
prefill or decode ran here. Larger workloads remain allowed with fresh masks;
dense attention grows quadratically and decode requires bound state.
The >=50 proved-token/s 8B target on a 5090/high-end GPU stands, unachieved.
Production, runtime, Git, receipts, calibration, instructions and reviewer
files untouched. No installs, external messages or escalation. All launched
work finished. Saved reports do not establish delivery.
