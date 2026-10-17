# ZKP efficiency explorer — durable state

Cycle 0068 COMPLETE: `20261017T212105Z-f1b8cd7d`.
Checkpoint: 2026-10-17 21:29 UTC. Next cycle no earlier than 22:21:05 UTC.
Read AGENDA, target, durable/project memory, 350 prior sources and latest three
results. Startup originals and hashes: experiments/logup-star-batch-domains-20261017/startup/.
Seven LIVE records appended; 357 total; original source prefix preserved.
Report: progress/20261017T212105Z-f1b8cd7d.md. No proving speedup found.

Rust batch(index, lengths, active, row_point, column_point, table_size) returns
PRIVATE weighted buckets only. Source-captured native Fp2; std-only build.
96 fixtures, 3,744 values, 96 claims/support checks, 1,800 column visits,
19 controls. Independent audit: 4,136 checks. Main 0.416722 s / 20,600 KiB;
compiler 128,868 KiB; audit 0.059436 s / 16,284 KiB. One Core Ultra 9 185H
thread, CPU0, nice 19, seed 2026101768; each run capped at 59 s / 512 MiB.
No native/GPU/GKR/PCS or privacy proof ran. Public synthetic support only.

New negative: sharing one scalar across seven column tensor coordinates gives
83 weight polynomials rank seven, leaving 76 dimensions of fixed errors that
always cancel. Independent two-coordinate F17 points detect the column 1/2
control at 272/289 points; diagonal never. This rejects our shortcut, not an
upstream/native protocol. Distinct initial points need reduction; zero-lift
factors can vanish; raw batched singleton values still leak. Uniform correlated
pad marginals can leak jointly. Whole-table zero refusal is only a reference
event; native refusal order, RNG, wrapping and PCS obligations remain. Preserve
all prior negatives. No mask reuse or hidden prompt-length disclosure.

Current 8B T32 per block: 83 U8 columns / 11,714,560 queries. Dense padding:
six domains 1.702098×; four equal-length groups 1.523077×; one global 5.728671×.
Public-support traversal can skip dummies but needs a checked reduction.
Four-group pushforwards: 16,384 logical bytes / 524,288 bytes at existing row
width BEFORE masks. Illustrative interface retains 83 ordered index links and
eight initial/GKR-terminal pushforward scalar sites before further reductions.
Fresh round masks, native A/H/M/PCS rows and net displacement UNKNOWN.
U8 H: 1,514 rows / 99,221,504 bytes; all H: 1,758 rows / 115,212,288 bytes.
Extra query commitment saving: zero. No peak/traffic/time saving measured.
Unapplied handoff: handoffs/20261017-logup-batch-domains.md.

Owner R5 cli3 CPU 8B T32 now freshly VERIFIED: 11 controls, honest still verifies.
One cold pass, 32 linked blocks, 16 CPU threads, GPU off; shared box, n=1.
Application 171.578 s / process 171.641294 s; diagnostic rates 0.186504 /
0.186435 positions/s. Witness 21.376 s within inclusive prove 156.143 s;
reload 15.993 s also within; remainder 118.774 s includes proof, serialization
and sink. Initial load 15.294 + seal 0.051 = 15.345 s, partial startup 8.943%.
Full startup, steady slope, isolated serialization, latency, lag, drain unknown.
Fresh check 26.491 s (reload 13.071, crypto remainder 13.420), plus initial
load 13.165 s. Whole verifier process 115.868762 s includes 11 controls.
Receipt: 465,815,776 bytes. Trained-shape privacy still unaccepted. D24 round-3
soundness does not accept later R5/privacy changes. D27 MVP ~95 bits at its
named workload and later selectable tiers stand; no new tier claimed here.
Free deletion of all H commit/open/U8/exp-act phases: 19.5 s -> 1.128224×,
0.210418 diagnostic positions/s with all other work fixed, before added costs.
This is not a whole-architecture or GPU bound.

Ranked hypotheses:

1. OWNER whole-prover GPU arithmetic/residency: highest impact, high cost.
   CPU D=28.79 s / F=16.64 s identify recurring work. Charge launches, spills,
   scratch, transfers and drain. Parity/privacy/refusal mismatch or no enclosing
   gain rejects a candidate. Do not duplicate owned device jobs.
2. OWNER public-model residency: R5 initial load 15.294 s / reloads 15.993 s.
   Add host RAM, identity and invalidation. Measure fresh complete-pass slopes;
   reject stale identities/backlog, and recurring work >20 ms per new position
   for a 50/s claim.
3. TESTED private lookup batching: 83 to four/one pushforwards is gross only.
   Add padding/support, point reduction, GKR, ordered A/wrapping links, joint
   masks, PCS and soundness. Repeated-coordinate shortcut fails. Reject private
   disclosure, changed support/refusals or no net enclosing saving.
4. NEW ragged rounds across four equal-length groups: remove dummy arithmetic,
   retain independent initial points and all terminals. Test full-extension
   dense/ragged round polynomials; reject any mismatch or extra exposed message.
5. NEW older MLE-compatible lookup 2024/1058: abstract-only lead, tiny public
   tables and PCS/compiler/private-link costs lower its priority. No speed estimate.

Next local: dense/ragged round-polynomial oracle for four groups, independent
starting points, odd columns and all terminal obligations. Retain fixed-error
and raw-evaluation controls; stop if merely relocating exposed private values.
Next owner: whole-prover GPU diagnosis and independently verified complete
fixed-context resident workload slopes under shared locks. No heavy job queued.
Sources include October 16 Plonky3 releases, October 11 zkLLMPoT v2, Powdr /
Binius batching, zorch natural-width negative and new older MLE lookup. Exact
failed fetches, dates and licenses in the experiment's searched-sources.json.

New target-compliant proofs/passes/positions: 0/0/0. Target steady/total rates
and clocks unmeasured. No resident repeats, long prefill or decode here. Larger
workloads allowed with fresh masks; attention can grow quadratically; decode
needs bound state. The >=50/s private 8B high-end GPU target stands, unachieved.
Production, runtime, Git, receipts, calibration, instructions and reviewer files
untouched; no installs, external messages or escalation. All launched work done.
Saved reports do not establish delivery.
