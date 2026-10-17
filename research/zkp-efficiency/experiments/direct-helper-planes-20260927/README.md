# Direct U8 LogUp helper writes into H — cycle 0011

Run `20260927T025233Z-f22c1025`, 2026-09-27 UTC. **Exact synthetic result;
no proved-token throughput improvement measured.** The complete private 8B
attention-plus-FFN target remains >=50 independently verified proved tokens/s
on one RTX 5090 or named high-end GPU, including witness and serialization.
No such result exists. The owner CPU fixture below is one 125M synthetic block
at T512, not a complete model, long prefill, resident-model pass or decode.

## Question and seam

In the inspected grouped candidate,
`/tmp/zk60-groups-20260926/hashline/src/private_block/protocol.rs:884-907`
builds each U8 helper as a `Vec<Fp2>`, then `write_h` copies its two limbs into
H. Could the existing cached 256-entry U8 inverses write directly into H's
base-field planes, removing that temporary without changing any helper word,
refusal, RNG draw, transcript event, mask, commitment or opening? The baseline
already eliminated the domain-wide intermediate; this proposal removes only
the **one-helper** transient.

The direct writer has an exact failure condition. If a later looked value has
a zero denominator, the current materialized writer leaves H untouched for
that helper; direct streaming can leave a private partial H. The experiment
tests both. A guarded writer preflights the column only when
`alpha.c1 == g_u8.c1`. If these extension coefficients differ, an embedded
signed integer cannot make the denominator zero. The guard depends only on
public challenges and profile constants. On the equality branch, preflight
retains the old no-partial-write guarantee for any signed i64, including
invalid values. The table must be the internally constructed table for the
same `alpha,g_u8`; arbitrary corrupted table input breaks this guarantee.

## Reproduce and evidence

From the research directory:

```sh
python3 experiments/direct-helper-planes-20260927/experiment.py > experiments/direct-helper-planes-20260927/run.log 2>&1
python3 experiments/direct-helper-planes-20260927/validate.py > experiments/direct-helper-planes-20260927/validation.log 2>&1
```

The script enforces one CPU, 55 CPU seconds, 59 wall seconds, 512 MiB address
space; estimated memory is 64 MiB. It ran in **2.097 s**, peak **16,500 KiB**
RSS on an Intel Core Ultra 9 185H in WSL2, Python standard library only.
Use `result.json` for the exact retained elapsed value. Seed **2026092711**.
All **63** cases pass: 44 successful, 19 refusals, 7 lengths 0–1024,
single/paired helpers, signed extremes, used and unused zero denominators,
and a mismatched pair. **7,932** successful Fp2 output words match an
independent exponentiation-field inverse oracle and the materialized writer,
including both H limbs, disjoint offsets and untouched sentinels. Eight
controls cover omitted pairs, bad cache entries, wrong limb, malformed pair,
zero refusal, and partial-write behavior. The candidate uses the conjugate/
norm formula; the independent oracle uses Fp2 exponentiation and checks each
inverse product. The final run's output digest is in `result.json`.

The initial validation audit failed because old source records have no
`cycle` key. That audit-only error is saved in `validation-initial.log`; the
corrected audit passes. No differential-test failure occurred. `validate.py`
checks seven read-only source/log pins, the counted model arithmetic, final
run log, and four source records appended to `sources.jsonl`.

## Traffic, ceiling and limits

The independent shaped layout model counts **52,183,040 U8 helper output
words** in the 125M development block. A 16-byte Fp2 temporary written
then read costs **1,669,857,280 logical payload bytes (1.555 GiB)** over
that block; the largest one-helper temporary has **64 MiB modeled payload**. Direct writing
eliminates these counted requests and that transient payload. All input
loads, H plane writes, table setup, A/H encoding and Merkle work remain.
The guarded common path adds only a public coefficient comparison. On a
successful equality-branch proof, the extra preflight requests **788,791,296
logical input bytes**, before cache effects. None of these byte counts is a
DRAM or runtime measurement. The active GPU chunked PCS path already avoids
retaining full A/H codewords; its host H construction still uses this helper
seam. That route has a counted **9.86-GiB** host construction payload floor
at the unregistered T512 Mistral geometry. The 64-MiB helper temporary is
from the **different 125M shape**; its Mistral counterpart and effect on
that floor have not been counted.

The current owner's *old arm* of the demoted fusion A/B measured U8 helper
phase **1.189/1.248 s** and known witness+prove+serialization **41.462/41.089
s** in two non-warm shared two-thread CPU runs. Even deleting the whole phase
would save at most **2.87/3.04%** of those known sums; this candidate keeps
the lookup computation, so its saving must be smaller if any. The A/B itself
shows fusion slower: old/new non-warm mean prove **35.0665/35.6490 s**.
Verification was **0.88/0.87 s** on those old runs, separately; receipts were
40,783,352 bytes. These are 125M synthetic one-block diagnostics with test
oracles, not complete private 8B rates or a 5090 experiment. Startup fraction,
steady-state throughput, total-workload throughput and proof lag are unknown.

The candidate is therefore a low-priority memory and traffic lead, with no
claim toward >=50 tokens/s by itself. It is falsified as a speed lever if a
native exact-gate A/B shows no smaller helper phase or enclosing readiness,
or if a required preflight, lost parallelism or allocator behavior erases the
payload benefit. Native Rayon, full-table refusal, fresh randomness,
transcript/receipt bytes, owner publication rules and GPU paths remain
unverified. [Handoff](../../handoffs/20260927-direct-helper-planes.md) gives
the implementation interface and gates.

The LIVE primary search inspected the original [LogUp paper](https://eprint.iacr.org/2022/1530),
[Jolt Atlas paper](https://arxiv.org/abs/2602.17452),
[ICME's repository and restricted LICENSE](https://github.com/ICME-Lab/jolt-atlas/blob/main/LICENSE),
and [Plonky3 release notes](https://github.com/Plonky3/Plonky3/releases/tag/v0.8.0).
The former paper's speed comparisons and the repositories' timings are author
claims, not replicated here. ICME code was neither copied nor run.
