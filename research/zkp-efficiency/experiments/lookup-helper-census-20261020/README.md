# Recurring private lookup helpers versus fractional-tree cost — cycle 0103

Run `20261020T111854Z-3f58f916`. Completed 2026-10-20T11:28:24.186578+00:00. **No proving speed improvement measured.**

The native U8 inverse table already amortizes reciprocal computation within an
attempt. Its entries depend on fresh alpha and gamma and must be recomputed
for each proof attempt. Public table/index metadata can persist; these inverse
values, masks and private openings cannot be reused across resident passes.
The larger opportunity is recurring private helper commitments, requiring a
new private protocol rather than an inverse-cache optimization.

The current source-derived fixture uses norm window32, fE9, fP9, DD cap32 and
rate4. It matches the owner's published T128 A/H/U8 counts for both models
with and without DD. T32/T64 are counted registered geometries; T512 is the
owner's **unregistered counted-only 8B anchor**, not a completed proof or an
admitted larger profile. Other norm-window and sigma-limb boundaries are
parameter sensitivities, never assertions about actual calibrated exports.
The new fidelity LOW stack is outside this frozen R9 census.

| Model / T | DD | A / H rows | U8 queries | U8 helper data MiB | Fraction of H input | Fraction of A+H input |
|---|---:|---:|---:|---:|---:|---:|
| TinyLlama / 32 | False | 1729 / 1798 | 5,971,968 | 48.31 | 85.984% | 43.833% |
| TinyLlama / 64 | False | 1817 / 1926 | 12,795,904 | 103.62 | 86.085% | 44.296% |
| TinyLlama / 128 | False | 1993 / 2182 | 28,999,680 | 235.25 | 86.251% | 45.078% |
| TinyLlama / 128 | True | 1871 / 2026 | 25,460,736 | 205.25 | 81.046% | 42.135% |
| 8B / 32 | False | 1697 / 1758 | 11,714,560 | 94.62 | 86.121% | 43.821% |
| 8B / 64 | False | 3229 / 3534 | 24,264,704 | 196.12 | 88.795% | 46.400% |
| 8B / 128 | False | 3405 / 3790 | 51,937,280 | 420.25 | 88.707% | 46.727% |
| 8B / 128 | True | 3283 / 3634 | 48,398,336 | 390.25 | 85.911% | 45.135% |
| 8B / 512 counted only | False | 9185 / 11056 | 306,249,728 | 2,480.50 | 89.743% | 49.019% |
| 8B / 512 counted only | True | 7303 / 8724 | 219,742,208 | 1,760.50 | 80.720% | 43.938% |

These are per-block logical helper DATA bytes, excluding helper blinding and
proximity rows from the numerator. Denominators include the complete counted
H or A+H input rows, including reserved rows. They exclude M, run boundary and
endpoint commitments, encoding expansion, tree overhead, scratch, transfers,
serialization and verification. They are not proof bytes, DRAM traffic,
exclusive time fractions, peak memory or net bytes removable by a valid proof.
Each block/pass recurs with fresh randomness. Repeated public setup does not
make these helper bytes a one-time startup cost.

## Tested question and useful negative

Could exact column structure avoid the memory penalty of a global fractional
tree, while retaining one global native U8 histogram? A global power-of-two
binary tree including one 256-entry table has two private Fp2 fields per
node. A literal internal node costs three Fp2 products plus one addition;
constant-leaf optimizations and proof reductions are not priced. The exact
forest has the original ordered query columns as subtrees, then one table
subtree, then combines their roots. It changes topology and needs a separate
mixed-height masked GKR design. Its node-count identity is independently
checked by explicit tiny trees, not by allocating any model-sized tree.

| 8B context | DD | Fully materialized global tree GiB | Exact forest GiB | Largest one-column tree MiB | Two adjacent levels MiB |
|---|---:|---:|---:|---:|---:|
| 128 | False | 4.000000 | 3.095718 | 127.999969 | 96.000000 |
| 128 | True | 4.000000 | 2.884781 | 127.999969 | 96.000000 |
| 512 counted only | False | 32.000000 | 18.253921 | 511.999969 | 384.000000 |
| 512 counted only | True | 16.000000 | 13.097671 | 511.999969 | 384.000000 |

Even the exact forest materialized in full is larger than the U8 helper input
it aims to displace. This rejects that storage schedule as a memory-saving
replacement; it does not reject streamed/recomputed fractional GKR. The one-
column and two-level counts omit other columns, retained proof reductions,
original A/PCS links, randomness, full GKR scratch and root lifetimes. They do
not prove a complete fit. D and F dominate T128 U8 helper bytes: 136 and160MiB,
unchanged by DD. At T512 the remaining S helpers grow with dense attention;
T128-to-T512 multiplies score entries by16 while positions multiply by4.

One native global U8 histogram must enter once. Splitting into per-domain
lookups would require new separately bound local histograms; duplicating the
existing global one is unsound. The per-domain-table illustration in each
JSON row is explicitly costed as requiring new local histograms. The forest
scenario instead retains one table/global histogram. T128 has83 ordered U8
column links; T512 has85. These are original affine column obligations, not
83 independent PCS openings mandated by any implemented construction.

Baseline: paired reciprocal H helpers with all original relations. Hypothetical
eliminated work: gross U8 helper-data commitment/processing only. Added costs:
fractional circuit evaluation and reductions, ordered original-A leaf links,
private multiplicity binding before challenges, all nonzero/whole-table
refusals, masks/CFS rows, terminal claims/PCS openings and launches. The other
exp, activation, DD and zero-sum helpers remain unless a complete reviewed
replacement proves them too. No masks or claim sites may simply be deleted.
If f is the unknown exclusive affected time fraction, hypothetical free deletion
has ceiling1/(1-f); this replacement does less and adds work. Byte fractions
cannot be substituted for f or for a high-end GPU rate. Reject any altered
binding/refusal/privacy relation, or if replacement costs exceed avoided work.

## Validation and reproduction

Final probe: 1098 checks / 46 fixtures / 13 negative controls,
including120 tiny F65537 direct-inverse versus division-free fraction cases.
Audit: 1381 checks, 34 pinned source fragments and their mutations,
624 altered-census controls, 160 explicit topology checks, five unchanged source pins.
These are integer/algebra/source checks, not native GKR, transcript, denominator
refusal, CFS mask, receipt or privacy validation. The F65537 experiment is only
an independent arithmetic oracle, not the native Goldilocks/Fp2 field.

Commands from the research root:

```text
python3 experiments/lookup-helper-census-20261020/run_bounded.py probe.py
python3 experiments/lookup-helper-census-20261020/run_bounded.py validate.py
```

Seed20261020103; one core/thread, nice19,59sCPU/alarm,60sparent,512MiBAS;
64MiB estimate. Probe 0.008066s / 16,248KiB RSS;
audit 0.019911s / 16,336KiB. Device: CPU Intel Core Ultra9 185H,
WSL2. No GPU/build/dependencies/external code. Python clocks measure checking,
not any proof stage. Source snapshots/hash manifest, commands, hardware and
source/search records are retained. An initial forest join-count assertion
failed (roots join by k internal nodes, not2k); the failure and previous data
remain under before-forest-join-correction/. Duplicate parameter fixtures were
then removed; prior results are retained. No owner code changed.

## Throughput evidence and integration

New independently verified complete-stack proofs/passes/positions: **0/0/0**.
Actual model context/device: none. New witness/proof/serialization/verification
clocks, startup duration/fraction and steady/total rates: all **unmeasured**.
No long prefill, resident-model passes or decode were executed. Greater context
can increase attention quadratically; larger accepted workloads remain allowed.

Carried CPU non-DD baseline, not rerun or reverified: 8B T128/L32, one16-thread
pass, GPUoff, total478.737s=0.267370positions/s; prove_run393.785s encloses
witness98.348s and load17.595s. Seal84.824s overlaps accounting. Receipt922,711,264B;
fresh verify42.709s+load13.681s, recheck34.395s+load10.739s. Startup and isolated
serialization are unknown, steady slope unmeasured. No target progress is
credited from this census. R9 soundness conditions N-r9-a/b remain; DD privacy
gate owed, D33 frozen-R7 CPU TinyLlama scope unextended, D32 fidelity bar intact.

[Handoff](../../handoffs/20261020-lookup-helper-census.md) identifies the actual
Rust seam. No native patch or merge is ready. Next: bounded mixed-height forest
lifetime/recomputation ledger with one original histogram and every ordered
column link, before any masked-protocol prototype. Owner priorities remain
complete high-end GPU phase/capacity clocks, verified fixed-context resident
1/2/4/8 passes, and the all-eleven FZC compiler A/B. Twenty ranked hypotheses
are retained in hypotheses.json. Six LIVE primary records appended599->605;
flookup is new in this ledger, other relevant sources are marked refreshes.
PDF/commit/license Internal Errors and release-date uncertainty are explicit.
No author benchmark was reproduced. Saved reports are not external delivery.
