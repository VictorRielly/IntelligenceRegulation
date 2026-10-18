# Factorized public equality for the row-first lookup probe

Cycle 0070, run `20261017T232105Z-d713e393`, 2026-10-17 UTC.
Research only; no native lookup protocol or proving speedup is established.

Question: can the previous rectangular probe keep distinct per-column points
without allocating full public E, public S or public position arrays?
**Yes for its tested arithmetic.** `factorized.rs` matches the previous
`ragged.rs`, a Python dense evaluator, and an independent retained-artifact
audit. It is a storage/evaluation prerequisite for a potential architecture.
The cubic E*S*V probe itself is not a complete or minimal lookup argument.

For public N rows, C real columns and W=next_power_of_two(C), Boolean index
`row*W+col` means row bits first, MSB first. For real columns:

```
E(row,col) = eq(col, column_point) * eq(row, initial_point[col])
S(row,col) = 1
V(row,col) = original synthetic value[col][row]
```

Dummy columns are zero in every factor. Private zero values do not change
the schedule. The evaluator owns one column-major C*N V scratch allocation;
the polynomial still has row-first variable order. It retains a scalar prefix
weight for each column, regenerates remaining Boolean equality weights with
a division-free depth-first walk, and contracts two V halves before forming
four row samples. V then folds at the supplied challenge. After row bits,
the three C column values enter ordinary padded cubic column rounds.
Public E at the terminal is a **mixture of distinct row equalities**; public
S is generally non-Boolean there. All three ordered terminals are retained.

Validation: 84 synthetic fixtures (30 prior fixtures unchanged), 1,788 round
values, 252 terminal values, 447 masked-chain rounds, 197 quadratic-base row
checks and 22 controls. Rows 1/2/4/8/16/32, columns through 83, odd padding,
Fp2 points and 0/1/half/signed-boundary/base-extension cases. Main run 3.151398 s
including compilation and references; main RSS 28,696 KiB, compiler 135,348 KiB.
Independent original-table prefix sums / power-basis convolution / direct MLE
and whole-cube mask integration: 4,768 checks, 7.180672 s, 21,272 KiB.
Separate future-challenge mutation test: 1,699 unchanged-prior-round checks
and one past-challenge sensitivity control, 0.111618 s, 16,732 KiB.
No future challenge is needed to form an earlier sample. An interactive
native adapter is still unimplemented.

One Core Ultra 9 185H CPU0 thread, nice 19, seed 2026101770. Each command has
59-second CPU/wall and 512-MiB address-space limits; estimated main/compiler
memory under 128/192 MiB. No GPU, dependencies, real private data or heavy job.
`commands.json`, `environment.json`, results, actual compile/audit/account/
causality logs and hashes retain the evidence. The first passing result was
retained before the extra mask-degree control. The first independent audit
passed arithmetic then failed an extraction assertion: it had forgotten the
eight `//!` to `//` comment conversions in captured field source. That failed
script/result note is retained; the corrected exact extraction check passes.

At the prior counted 8B T32 groups (not executed at these sizes), naive
index+E+S+V payload is 625.625 MiB. V plus summed small input/state/output
payload is 178.783936 MiB, with largest individual group 94.017731 MiB.
These are **aggregate payload comparisons, not measured peak memory**.
Original witness/query source, recursion/allocator overhead, whole-cube masks,
M/A/H/PCS, GKR, links, transfers and serialization are additional. The local
adapter deliberately caps N at 32768 and N*C at 2^20; it did not execute the
large D+Q/F groups. No native H rows or query commitment are removed here.

Costs: regenerating suffix weights adds 23,426,212 counted Fp2 multiplies
across the four groups; V is read in weighted and fold passes separately
(23,428,954 field reads each) and written 11,714,477 times. These are logical
source-level counts, not physical traffic. Ordered original-A and i64 wrapping
links for all 83 columns, distinct-point reductions, GKR, fresh masks,
extensions, final openings and workload soundness are unresolved. Masks
remain on the **whole cube**. Quadratic unmasked row arithmetic does not
authorize quadratic masked messages: the native cubic CFS mask still applies.
Unmasked singleton values still disclose; arithmetic parity is not privacy.
Only fixed public shape support may be implicit, never hidden prompt length,
secret selectors, witness sparsity or private mask rows.

Current owner baseline is R5b, not R5 cli3: a functionally verified linked
32-block 8B T32 CPU pass, n=1 shared host. Application 191.755 s / process
191.975140 s; diagnostic total rates 0.166880 / 0.166688 positions/s. Sealing
37.214 s =19.407056% of application time. Inside sealing, cumulative load
35.798 s and witness 32.584 s overlap; neither is an exclusive wall slice.
Proving 154.427 s includes reload 19.052 s, no witness rebuilds; remainder
135.375 s includes proof, serialization and sink. Fresh verification 32.248 s
plus initial load 14.507 s; verify reload 17.015 s within check, crypto
remainder 15.233 s; entire verifier process with controls 141.571000 s.
Receipt 465,815,776 B. All 11 controls refuse; honest recheck verifies.
Shape privacy acceptance remains open. Startup beyond sealing, steady slope,
isolated serialization, latency, lag, pipeline drain and prefill are unknown.
Free deletion of four measured direct H phase families (21.568 s) bounds
only that phase set to 1.126731x / 0.188028 diagnostic positions/s with other
work fixed, before any new cost. It is not an architecture/GPU ceiling.

Integration seam: captured `zkp-core/src/sumcheck/rounds.rs:22` and
`prove_rounds` can host a stateful arithmetic adapter; a new lookup construction
also needs private_block protocol/argument/shape/layout H/M/PCS changes.
Nothing here preserves the frozen native lookup transcript or proves that
construction. No production patch applied or merged; owner/Claude reviews it.
Reject mismatch of a round, terminal, ordering, support/refusal, wrapping,
joint privacy, mask/extension/PCS binding or lack of enclosing time/peak gain.
End-to-end ceiling of the full new architecture is unknown.

Next: implement a pending-previous-challenge adapter and test folding V while
forming the **next** weighted round, charging equality generation and data
reads. Folding with the current unknown challenge in the same round is
unavailable under the native transcript schedule. Owner priority stays kernel
design / complete GPU proof and resident fixed-context workload slopes.
No new complete proof/pass/target position: 0/0/0. Target steady/total rates
unmeasured; >=50 proved tokens/s on a named high-end GPU remains unachieved.
No resident repeats, longer prefill or decode were performed; context growth
can increase attention quadratically and decode needs authenticated state.

Sources and exact date/license/commit limitations are in `source-records.json`:
SP1 NTT ordering, EPFL split-equality source, March 2026 sumcheck, Jolt
implementation dates, older time-space tradeoffs, and newly assessed Orion.
Orion's corrected 2023 paper versus its inspected 2022 repository is a useful
filter: code switching requires commit-and-prove and adequate joint masks;
the old snapshot does not establish a corrected implementation.
