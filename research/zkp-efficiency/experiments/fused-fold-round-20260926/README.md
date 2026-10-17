# Fold and next-round sampling fusion — cycle 0005

Run `20260926T205233Z-79c00f5e`, 2026-09-26. Exact synthetic arithmetic and
logical traffic experiment. **No measured native or end-to-end improvement.**

## Hypothesis and boundary

`ClosureRounds::round` reads both halves of each table, while `fold` reads
them again and writes half as many words. At the next round the folded table
is read again. After receiving the current challenge, form next-round
endpoints while the source words are live and cache the resulting unmasked
samples. Preserve the existing driver and its `round / fold / finals` calls.
The baseline already halves its tables; no asymptotic improvement is claimed.

For old length `N=4q`, at index `i<q` load quarters `a,b,c,d` and calculate:

```
left  = a + r*(c-a)
right = b + r*(d-b)
table[i]   = left
table[i+q] = right
next_sample(t) += poly(left + t*(right-left))
```

Every `i` owns its four input locations and its two output locations, so
in-place writes cannot clobber another `i`'s input. Chunks must use the same
indices across all tables. The final length-two fold returns no next samples.
Length one is an already-final evaluator and never calls fold.

`fold` first interpolates the preceding **actual unmasked** round at the
driver's challenge to get sample-1 recovery's next claim. It then caches the
next round. `round(j+1)` consumes that cache and marks it pending; these two
states must remain distinct. No asserted host claim is substituted. A pure
polynomial closure is required. Earlier evaluator execution can change when
an impure closure runs; the native trait already requires polynomial purity.

## Result and commands

From the research directory:

```sh
python3 experiments/fused-fold-round-20260926/experiment.py > experiments/fused-fold-round-20260926/run.log 2>&1
python3 experiments/fused-fold-round-20260926/validate.py > experiments/fused-fold-round-20260926/validation.log 2>&1
```

Final experiment: **108 differential cases**, **180 full-cube direct-MLE
round oracles**, **432 direct final MLEs**, **54 synthetic masked-driver
comparisons**, eight detected mutations, ten schedule refusals and eight
malformed-fixture refusals pass. Seed 2026092605, four tables, lengths
1/2/4/8/16/32/64/256/1024, degrees 2/3, base/full-extension values, Boolean
equality factors that vanish, zero/one/extension challenges, recovery on/off,
chunks 1/3/7 and reversed chunk order. The direct oracle uses the original
cube and a separate schoolbook Fp2 multiplication. Every intermediate folded
table agrees with the non-mutating two-pass reference.

One CPU (Intel Core Ultra 9 185H), Python 3.10.12/WSL2; **2.7433 seconds**,
**17,700 KiB peak RSS**. Affinity one CPU, address-space cap 512 MiB, CPU cap
55 seconds, alarm 59 seconds. These are script costs, not proof costs.
The first passing version is retained under `initial/`; the final version
strengthens the masked-claim mutation by running a wrong-claim evaluator.

For four 1,024-row tables, reads fall **16,368 -> 12,280 Fp2 words**, while
both paths write **4,092**. Counted table traffic falls **327,360 -> 261,952
bytes (19.98%)**. Across all rounds with K tables and N>=2, reads are
`4K(N-1)` versus `K(3N-2)`, writes are `K(N-1)`. Polynomial call counts agree.
This counts logical endpoint loads once even if source syntax mentions an
endpoint twice. It excludes caches, write allocation, scratch, final reads,
driver and reduction traffic. It is neither a DRAM counter nor a 20% speedup.

## Integration and current bottleneck

Read-only source: `/tmp/zk60-groups-20260926/zkp-core/src/sumcheck/rounds.rs`,
`grouped.rs`, and native `private_block/argument.rs:553`/`:556`. Relevant
sources and retained timing logs are hashed in `source-pins.json`; the two
round evaluators are copied as source snapshots to survive temporary-tree
loss. `fused_fold_measure.proposed.rs` is an **uncompiled, unapplied SERIAL
helper sketch** for a new evaluator. It is not a production performance patch.
Owner must retain the existing parallel fallback until safe quarter-chunk
ownership and a useful crossover are measured. There is no CUDA implementation.

Current non-warm R2a logs: slot-17 masked sumcheck 9.858/9.686 s, proving
39.733/40.095 s, witness 8.35/7.26 s, serialization .024/.027 s; accounted
readiness sums 48.107/47.382 s. Verification is separate: internal .964/.976 s,
from bytes .98/.99 s. Eliminating that entire sumcheck phase would remove
about 20.4% of these sums; fusion removes only a portion of its work. Its
fold/read attribution is absent, so a time saving cannot yet be estimated.
Shared two-thread CPU, synthetic dense 125M block, compilation overlap;
these are not enclosing request clocks, GPU runs or 8B estimates. The grouped
A/B still records `waiting-for-heavy-lock`, no runs; no duplicate was started.

For SC_SZC, generic fusion must be adapted to `GroupedEqRounds`, retaining
per-group pending rounds/claims and prefix updates before preparing next-round
suffix weights. Keep each group's zero-factor fallback and original equality
tables/finals. Simply replacing it with the generic helper would discard its
tested equality-factoring arithmetic savings. That combined port was not tested.

Required owner validation: native debug/release parity against original driver,
masked messages/challenges/finals, RNG draw counts, extension rounds, receipts
and inconsistent witnesses; then phase attribution under shared build/heavy
locks. GPU work additionally needs register/occupancy/cache/DRAM measurement.
No new soundness/privacy acceptance, refusal policy or profile is proposed.

## Sources and limits

Native LIVE search checked Plonky3's release fusion follow-ups, the August 2026
GPU instruction-throughput paper and Thaler's older regular-circuit work reuse.
Exact URLs/dates/licenses/access failures are in `source-records.json` and
`search-log.json`. Plonky3 source/PR fetch failures prevent an implementation
audit; no downloaded code ran. Author performance claims are not reproduced.

The 50 proved-token/s target still requires a complete private 8B stack, all
preparation and serialization; at the 512-token reference it permits 10.24 s.
Larger workloads require explicit startup and total/steady accounting.
Five seconds is a stretch; prefill is not autoregressive decode. Experiment
proof, verification and complete-readiness fields are null.
