# ZKP efficiency explorer — durable state

Cycle 0103 COMPLETE: `20261020T111854Z-3f58f916`.
Checkpoint: 2026-10-20T11:31:22.171649+00:00. Deadline: 2026-10-20 11:38:54 UTC.
Next cycle no earlier than 2026-10-20 12:18:54 UTC.
Evidence: experiments/lookup-helper-census-20261020/.
Prior state, findings and source ledger are preserved in startup/.
AGENDA, current target, required durable documents and latest results read.
Larger workloads are allowed; 512 tokens is not an acceptance ceiling.

No proving speed improvement measured. Frozen R9 public norm-window 32,
fE 9 / cap 32 fixture: U8 helper data is 420.25 MiB per 8B T128 block,
390.25 MiB with DD, or 46.727% / 45.135% of A+H input including reserved
rows. D/F contribute 136/160 MiB in both. This is gross logical data, not
net removable bytes, physical traffic, time or proof size. Private H data
recurs every block/pass. The 256-entry reciprocal cache depends on fresh
alpha/gamma and is per attempt; it cannot persist across proof attempts.
Keep one original global histogram. A per-domain table split would need
new bound local histograms. Original ordered U8 columns: 83 at T128, 85 at
COUNTED ONLY T512. No T512 R9 profile/proof admission is established here.

Storage negative: a materialized global private fraction tree needs about
4 GiB at T128. An exact full column forest reduces this to 3.096/2.885 GiB
non-DD/DD, still larger than the helper data it would replace. At counted
T512: global 32/16 GiB, exact forest 18.254/13.098 GiB. Reject this full-tree
storage schedule as a memory-saving replacement. A smaller one-column or
adjacent-level count does not establish full GKR fit: retained/recomputed
intermediates, original A links, private reductions, masks, CFS/PCS sites,
refusals, scratch and launches remain unpriced. Time fraction and numeric
GPU ceiling are unknown. An initial root-join count assertion failed and
was corrected; its source/logs and previous results are retained.

Validation: 1098 checks / 46 fixtures / 13 negative controls,
including 120 tiny F65537 fractions. Independent audit: 1381 checks,
34 source fragments and 34 mutation controls, 624 altered-census controls,
160 explicit topology checks, five unchanged pins. One CPU thread/core 0,
nice 19; probe 0.008066 s / 16,248 KiB RSS;
audit 0.019911 s / 16,336 KiB. Caps: 59 s CPU/alarm,
60 s parent, 512 MiB AS; estimate 64 MiB. No native Rust/GKR, transcript,
refusal, CFS, receipt or privacy validation.

Twenty ranked hypotheses are retained in hypotheses.json. Top three:
1. Owner complete high-end GPU phase coverage and independently verified
   fixed-context resident 1/2/4/8 passes.
2. DD larger-context scaling after the measured T128 null result.
3. Actual capacity and exclusive/enclosing phase clocks before allocation changes.
The all-eleven FZC compiler A/B remains ahead of a large GKR redesign. Prior
unmasked-root disclosure, weak leaf binding, large-NTT and other negatives
remain intact. No mask, opening or inverse-cache reuse across attempts.

Six LIVE primary records appended, 599 -> 605; twelve queries retained.
New older screen: flookup 2022/1447. LogUp-GKR, OpenVM-zorch, Stwo and
zkLLMPoT refreshed. Dates, licenses, short-commit scope and fetch failures
are explicit; no author performance or external code reproduced. The
rendered Stwo v1 release listing is not claimed to be the latest release.

Next LOCAL: bounded mixed-height column-forest lifetime/recomputation ledger.
Retain one original global histogram and every ordered A column link. Compare
keep-all, one-column, and cut-level/recompute plans against independent tiny
fraction roots and wrong-site/dropped-multiplicity/zero-denominator controls.
Derive additional private GKR/CFS/PCS sites before pricing net bytes; never
publish unmasked roots. Next OWNER: complete GPU phase/capacity clocks and
verified resident 1/2/4/8 passes; all-eleven FZC compiler A/B first. Shared
locks and exact parity/refusal/privacy/fidelity/soundness gates apply.
Handoff: handoffs/20261020-lookup-helper-census.md. No merge here.

Carried baseline, not rerun/reverified: CPU non-DD 8B T128/L32, one 16-thread
pass, GPU off; total 478.737 s = 0.267370 positions/s. prove_run 393.785 s
includes witness 98.348 s and load 17.595 s; seal 84.824 s overlaps accounting.
Receipt 922,711,264 B; fresh verify 42.709 + load 13.681 s; recheck 34.395 +
load 10.739 s. Startup fraction, steady slope and isolated serialization unknown.
New independently verified full-stack proofs/passes/positions: 0/0/0. Actual
model context/device: none. All new witness/proof/serialization/verification
clocks, startup duration/fraction and steady/total rates are UNMEASURED.
No long prefill, resident pass or decode. Private 8B >=50/s on RTX 5090 or
another named high-end GPU remains unachieved. Longer context can increase
attention quadratically. R9 N-r9-a/b, DD privacy gate owed, D32 fidelity bar
and D33's frozen-R7 artifact scope remain. Only research excluding runtime
written; no production/Git/build/GPU/install/external writes or messages/
purchases/escalation. Saved reports do not establish external delivery.
