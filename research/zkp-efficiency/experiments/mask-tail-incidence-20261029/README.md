# Mask-tail incidence and current-slot cache — cycle 0138

Run `20261029T075649Z-ff4ec0d7`, 2026-10-29 UTC.
**No native proving improvement measured.** This is a source-derived metadata
census plus a synthetic differential experiment at
`trained-1b/hashline/src/private_block/argument.rs::{define,mask_eval,run_slot}`.
Native `define` itself was not executed. The research patch is uncompiled and
unapplied; no production or runtime files changed.

The preceding SC_TAB-only cache covered six pairs. The new question is whether
all private sites offer enough identical public tail points to justify a broader
one-entry cache. Prior cycles 0039/0040, 0041, 0136 and 0137 were read first:
this does not rediscover symbolic main-table folds or combine their savings.

`catalog.py` independently constructs the ordered Priv metadata from inspected
builder calls, domains, coordinate maps and extension families. A separate
restricted arithmetic reader in `source_reference.py` extracts native
`Shape::claim_sites` expressions and checks A/H multiplicities. Source anchors
cover fixed, flipped and reordered bilinear coordinates; short denominator,
packed-limb and Ht slices; commitment widths; fresh reservations; and P-3 lift.
The census covers all 23 baseline slots and the optional 24th DD slot.

Six pinned registry geometries are counted: TinyLlama and Llama-3-8B at
T32/64/128, with two additional T128/DD32 variants. These are metadata counts
under explicit four-limb/full-byte norm, three-limb sigma, two-limb P assumptions.
They are not R13 LOW/h24 calibration measurements or profile/privacy acceptance.
Different classes must rerun the census. TinyLlama f5632 pads to8192;
8B f14336 pads to16384. Endpoint widths match A/H in these geometry rows;
separate synthetic fixtures deliberately give endpoints different widths.

At T128, both counted non-DD families have the following per-block totals:

| Quantity | Baseline | One-entry cache | Two-entry LRU |
|---|---:|---:|---:|
| Distinct private mask pairs evaluated | 174 | 174 | 174 |
| Eq-table builds | 174 | 33 | 29 |
| Eq-constructor Fp2 products | 4,871,844 | 991,678 | 860,614 |
| Fresh private base-word reads | 4,872,192 | 4,872,192 | 4,872,192 |
| Maximum public-weight payload | 262,144 B temporary | 262,144 B retained | 524,288 B retained |

The one-entry cache removes141 Eq/reversed-point vector constructions and
3,880,166 constructor products, keeping all private products and data reads.
These are API/metadata counts, not instructions, measured DRAM traffic or time.
It retains one Eq vector and a point copy through extension work, where the
original temporary had died. Whole-prover peak delta is unknown. Exact point
comparisons, key copies, dispatch and allocator/dependency costs are added.
The two-entry alternative removes only four further builds/131,064 products at
up to another262,144B public-weight payload; it is a cost tradeoff, not a winner.

The short TZC sites all share one tail despite different c0 addresses. DZC and
SZC switch from full-domain to short leading-coordinate tails and then back;
QZC/KVZC insert a flipped partner before their normal helper tails. Those four
evictions explain33 versus29 builds. Bilinear SCORE/PV tails are different;
their two extension families cannot be replaced by one private evaluation.
Per-slot/extent tables and both replayed capacities are in `counts-audited.json`.
T128/DD32 has179 pairs and36/31 builds; it is kept separate from the23-slot row.

Only ordered public points define Eq weights. c0, cm, row/pair identity and
private words remain site-specific address inputs. The cache compares the
entire actual ordered Fp2 tail (including its length), holds no private result,
and is destroyed after the current slot. Equal-tail reuse across differently
addressed private rows is not mask reuse. No challenge, mask, commitment,
opening or result is reused across proofs. Model Boolean points may make
symbolically distinct tails equal; exact value comparison remains correct.

Result: **22,307 checks /423 fixtures /35 negative controls PASS**;
6,270 independent site comparisons and6,270 extension terminals. Scaled
synthetic geometries exercise every slot with extension/Boolean/zero-first
points, ln2/4/5, sigma2/3, P1/2, full/partial norm-top bytes, DD off/on,
nonzero packed c0 and unequal endpoint widths. Separate large synthetic pair
checks use256/8192/16384 words per row and an independent MSB-fold reference.
The small reference uses original Boolean-cube evaluation and schoolbook Fp2;
the candidate follows the original four-product mask-dot arithmetic, so this
patch does not stack the previous paired3 candidate.

Controls catch stale/length-only weights, changed private values, wrong real/imag
order, c0/width/tail/order/flip, fresh pair substitution, all24 source site-count
families, and a dropped later zero extension. The independent audit passes
**4,856 checks**,57 source-anchor mutation checks and eight current source pins;
it applies the patch only in memory and restores cached mask evaluation to the
original function byte for byte except its Eq provider. Anchor presence checks
are not native forgery/refusal tests. One audit assertion initially used the
wrong local name in a literal source anchor (`profile` versus `p`); the retained
failure was corrected against the captured source and the final audit passed.

Probe2.818003s/26,300KiB RSS; audit0.041339s/20,596KiB. One nice19 pinned
Core Ultra9 185H CPU worker, Python3.10.12/WSL2, seed202610290138. Each child:
40s CPU limit,45s alarm,50s parent timeout,256MiB address-space cap,
96MiB estimate. No GPU, native build, install, downloaded code execution or model
data. These clocks measure research checks, not witness or proof phases.

Reproduce sequentially from the research root:

```text
python3 experiments/mask-tail-incidence-20261029/prepare_adapter.py
python3 experiments/mask-tail-incidence-20261029/run_bounded.py probe.py
python3 experiments/mask-tail-incidence-20261029/run_bounded.py audit.py
```

The Rust proposal selects `n_priv >1` and otherwise calls the original function.
The public cache exists inside the extension closure and spans its extension
rounds. Accepted-layout algebra is the model's scope; native malformed-slice,
allocation failure/panic schedule and source/refusal equivalence remain owed.
No RNG/transcript/masking/PCS/capture/independent-receipt/privacy gate ran here.
Main/Claude reviews and integrates; this lane does not merge or queue heavy jobs.

The prior historical R4 T128/L22 logs were reread by hash only, not rerun or
reverified: all506 extension-phase rows total15.938s of153.072s CPU prove_run,
13.303s of135.809s RTX4070Laptop-assisted prove_run, one16-thread pass each.
Even free deletion of that entire enclosing phase gives only approximately
1.116222x/1.108591x proving-only counterfactuals, from rounded displayed timers.
The cache removes only constructor work within that phase. No transfer of these
bounds to current R13,8B or a high-end GPU is justified. Target ceiling remains
`Npositions/(T-Cexclusive_removed+Aadded)`, with unknown exclusive phase costs.

A separate count-only follow-up prices public `(a+b)` preparation for the prior
paired3 arithmetic:2,436,096 per-site additions versus495,872 across the one-entry
builds at this T128 geometry. That would add up to131,072B payload for cached
base sums plus their writes/reads; it is not implemented or tested here. Do not
add it to measured gains or assume a free cache hit. The old one-product Eq-fill
lead was already recorded and is not presented as a new discovery.

LIVE primary search refreshed equality/sumcheck and batch-evaluation techniques,
recent Plonky3 releases/PR2305, an inspected historical arkworks dependency
commit, and newly assessed September2026 rational preprocessing and older2024
Sailor ring arithmetic. Dates, exact URLs, licenses, commit inspection scopes
and fetch failures are retained. The rational-preprocessing landing and PDF have
different visible document details; no theorem/performance result is reproduced.
Univariate preprocessing does not directly replace a fresh multivariate mask
dot, and ring arithmetic is a protocol migration, not an exact field swap.

Next owner: obtain exclusive Eq/dot/extension/enclosing clocks, then compare
baseline, one-entry and two-entry with golden/RNG/refusal/transcript/PCS/privacy
and independent full receipts under current shared locks. Whole-prover GPU and
verified resident1/2/4/8 workloads stay above this small enclosing-phase lead.
Next local: lookup/softmax rotation; inspect current registered LOW/h24/DD
catalog/commitment shapes before testing shared U8-source preparation. Earlier
cycle0121/0122 alias and private-PCS negatives must be read first.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actual model context/device: none; only one CPU thread used. Witness, proof,
serialization, verification, startup/initial-prefill duration/fraction, proof
latency/bytes and steady-state/total-workload rates: **unmeasured**. No long
prefill, resident-model series or decode ran. Larger workloads remain allowed;
longer contexts can increase attention quadratically. The private8B >=50/s goal
on RTX5090 or another named high-end GPU remains unachieved.
