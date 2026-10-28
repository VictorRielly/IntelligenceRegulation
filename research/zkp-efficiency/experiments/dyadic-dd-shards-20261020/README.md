# Public dyadic division-dictionary unions — cycle 0114

Run `20261020T221854Z-d390b45f`, 2026-10-20 UTC. **No proving improvement measured.**

The leading locally testable question was whether unused positions in the
proposed S12 division dictionary can be removed by splitting its public support
into several power-of-two domains. Higher priorities still require the owner's
complete GPU, fidelity and phase measurements. Nothing in this experiment
changes or admits a native profile.

The baseline is the owner's R11 HIGH/S12 counting model at head dimension128,
f_e9 and F_P12. These settings and the existing b7 exponent distribution are
public sensitivity fixtures. Actual HIGH fidelity tables are absent. R9's
implemented cap32 cannot admit the156-value S12 table at base e_s2.

| Counted context | Public partition, e_s2 | A+H committed words per block | Versus single cap256 | Versus direct division | Selected dictionary A+H payload |
|---:|---|---:|---:|---:|---:|
|128|256|167,133,184|0%|+9.770795%|160MiB|
|128|128+16+8+4|160,415,744|-4.019214%|+5.358872%|97.5MiB|
|128|128+32|159,760,384|-4.411332%|+4.928441%|100MiB|
|512|256|803,176,448|0%|-3.965051%|768MiB|
|512|128+16+8+4|767,393,792|-4.455143%|-8.243545%|468MiB|
|512|128+32|766,607,360|-4.553058%|-8.337578%|480MiB|

The partition with the fewest dictionary positions is not the partition with
the fewest committed words. At T512, the additional shard in128+32 adds11A
and7H claim sites,36 times the row width in fresh A/H mask words (9MiB), one
DD slot, three PCS groups and two M encoded rows. The four-shard partition
saves another12MiB of dictionary payload but needs two more such mask sets.
At T128, a shard has9A+6H sites and3.75MiB of masks. Those masks are counted,
never shared across shards or proofs.

The public156-value support is sorted and split across the two shards; four
remaining positions carry the valid zero tuple. A single score tuple helper
looks into the union. Each shard has its own committed multiplicities and
table helper. All table helpers enter the original single value-zero sum with
negative signs. This avoids an extra private score-routing witness; it is a
proposed interface whose native binding and privacy still require review.
No individual shard sum or private histogram is published.

Every dictionary position checks exact quotient/remainder arithmetic, including
unused and zero-padding positions. Every denominator is inverted before its
multiplicity is applied. The row-Sum key and its slot17/Ht relation remain
essential: a keyless union accepts a quotient from a different row. M_dd must
remain in A before lookup challenges. New domain/claim/site allocation,
statement binding and joint-view privacy are unresolved; the arithmetic
oracle proves none of those properties.

Native R9 forbids lifting or padding a dictionary domain. With32heads, the
minimum capacity per shard is4 at T128 and2 at T512. The raw55-value partition
32+16+4+2+1 fails this rule. Rounding public capacity first permits56 slots,
but at T128 its extra masks make the original single cap64 cheaper. Likewise,
splitting248 values into five shards regresses committed words at both
contexts. These negative cases are retained.

The exact public optimizer minimizes
`dictionary_words_per_cap * sum(caps) + fresh_mask_words_per_shard * n_shards`.
It does not minimize runtime, receipt size or device peak. The independent
audit enumerates distinct-power partitions: repeated equal powers can merge,
preserving data size while saving a mask set. It agrees with the producer's
unbounded-coin dynamic program for every reported case.

Using the existing30x e_s2 /1x e_s3 /1x e_s4 schedule only as sensitivity:

|Counted context|Policy|32-layer committed words|Versus direct|Conditional body-byte delta versus direct|Selected dictionary peak|
|---:|---|---:|---:|---:|---:|
|128|single per-layer|5,322,047,488|+9.232756%|+81,977,104|160MiB|
|128|sharded per-layer|5,098,733,568|+4.649333%|+79,000,256|100MiB|
|128|public direct/DD choice|4,871,356,416|-0.017486%|+697,952|40MiB|
|512|single per-layer|25,575,817,216|-4.435215%|-23,268,592|768MiB|
|512|sharded per-layer|24,466,554,880|-8.580006%|-40,092,272|480MiB|

T512 sharding saves4.337153% over the previous per-layer single dictionaries.
T128's public direct/DD choice is unchanged: DD only at the final cap64 layer.
Conditional body bytes use the fixed R9 skeleton with fresh masks, extra
slots, terminal messages and PCS groups. New profile/schedule metadata and
degree/group assumptions remain unvalidated; these are not complete receipts.

The peak column is only dictionary A+H payload, under the source-backed
assumption that A remains alive while H is built and layers execute
sequentially. It excludes all other planes and masks, PCS encodings/trees,
witness, histograms, pools, driver capacity and transfers. It is neither
whole-prover HWM nor evidence of VRAM fit. Resident passes would repeat all
private per-proof costs; no resident pass was run.

Native work removed: none. Hypothetically removed work: unused dictionary
positions, byte-helper lookups and denominator inversions. Added costs:
extra masks/slots/PCS, Sum slices, histograms, metadata, challenge scheduling
and source binding. If f is the unknown exclusive affected full-prover time,
even free removal is bounded by1/(1-f), before added costs. No numerical
end-to-end rate follows. Falsify the candidate if actual public tables,
binding/range/refusal/privacy requirements or measured enclosing costs erase
the saving. The existing T128 regressions already limit its scope.

Reproduce with `python3 -B experiments/dyadic-dd-shards-20261020/probe.py`
then `python3 -B experiments/dyadic-dd-shards-20261020/audit.py`,
and `python3 -B experiments/dyadic-dd-shards-20261020/summarize.py`.
The recorded parent command bounds each child by60s. Each child uses one
worker, nice19, first allowed CPU,59s CPU/alarm and512MiB address-space cap;
estimated memory64MiB. Probe:53,680checks,60synthetic rows,19,200positions,
16controls,0.146128s and17,640KiB RSS. Independent audit:8,128checks,
20,480public entries by90-digit Decimal recurrence,3,360positions,13source
pins,0.035228s and18,480KiB RSS. Device: Intel Core Ultra9 185H CPU on WSL2;
no GPU. These clocks measure checking, not proving.

The initial audit failed because a mutation moved a count between identical
zero entries, which correctly leaves the multiset unchanged. The initial
source/stderr is preserved. The corrected control moves a max-value count to
zero. Final runs also verify exact public table hashes, reject insufficient
support and reject lifted shard geometry. `commands.json`, `source-pins.json`
and final artifact hashes retain reproduction evidence.

Eleven native LIVE queries and seven primary source records are retained in
the source ledger and `source-records.json`. Refreshed current OpenVM
release/GKR integration and October16 Chimera; [TaSSLE](https://eprint.iacr.org/2024/1075)
and [LogUp-GKR](https://eprint.iacr.org/2023/1284) provide decomposition and
input-binding boundaries. Newly assessed older
[Verifying Jolt zkVM Lookup Semantics](https://eprint.iacr.org/2024/1841)
supports validating subtable semantics independently. No author performance
was reproduced. TaSSLE PDF403 and an initial OpenVM LICENSE404 are recorded;
the actual LICENSE-MIT body was successfully inspected. The inspected release
commit is362c7ad8c6b042b320471a137e3eadec7ec69a44; its full date is unavailable.

Research interfaces: `count(T,caps)`, `best_caps`, `shard_column`, and the
synthetic tuple-union checker in `probe.py`; no native patch. Rust seams are
Shape/Layout's Dd family and claim sites, SC_DD/Sum slices, HIds/table signs,
the E-column loader, witness histograms and trained/run statement digests.
Main/Claude reviews and integrates any candidate. Next local rotation:
source-backed public PCS/NTT preprocessing incidence and cache capacity;
owner GPU/resident1/2/4/8 clocks, HIGH fidelity and all-eleven FZC A/B retain
priority. Twenty-eight ranked hypotheses preserve earlier negatives.

New completed independently verified full-stack proofs / passes / positions:
**0 / 0 / 0**. Actual model context and accelerator: **none**. Witness,
proof, serialization and verification clocks: **unmeasured**. Startup duration
and fraction, steady-state and total-workload proved rates: **unmeasured**.
No long-context prefill, repeated resident-model pass or decode ran. Counted
T128/T512 and synthetic row lengths32/128/512 are diagnostics. Larger workloads
remain permitted; attention work can grow quadratically with context. The
complete private8B >=50 proved positions/s target remains unachieved.
