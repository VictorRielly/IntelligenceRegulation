# Lifted Ht host collapse — cycle 0042

Run `20261012T232555Z-fecd435a`, 2026-10-12. Synthetic arithmetic passes;
**no native proving improvement measured**. This is a modest operation-count
candidate. The complete private 8B / >=50 proved-token/s target is unchanged.

Question: can the SC_SZC row-sum host group sum its repeated trailing j values
once per leading Ht position, retaining the original round polynomials?
The production seam is the pinned candidate `hashline/src/private_block/argument.rs`:
`priv_table` at 208 broadcasts unused coordinates; SC_SZC at 1699 constructs
`A_SUM` with `rho(0..lht)` at 1719, builds the leading `supp_Ht` at 1745,
declares group 1 at 1785 and its bracket at 1791. It is **not** a native
`Tab::lift` method, as the previous next-step shorthand suggested.

Baseline is the existing GroupedEqRounds, including actual per-group claim
recovery and zero-factor fallbacks. It is not an unoptimized generic driver.
The host is `eq(p_ht,leading) * nu0 * supp_Ht * (sum + lam)`.
For j before L leading variables are consumed, multiply the compact half-cube
sum by `2^(n-L)`. Thereafter every bracket sample is the same constant, and
the remaining Boolean-tail sum is that constant times `2^(n-j-1)`.
Both lifted MLEs remain constant on trailing variables at arbitrary field
challenges. Do not infer invariance from equal sampled values or from a
private witness assertion. Immutable native constructors must certify it.

The [Python adapter](collapsed.py) removes only group 1 from the full row loop.
Groups 0/2, complete table scans, all private/Eq/public folds, source order,
sample/degree metadata, actual claims and terminal/extension equations remain.
`admit_plan` illustrates public mapping checks; it is not an integrated native
capability or a sufficient security boundary. Unsupported metadata falls back
to the original grouped path. Directly forged plans demonstrably fail.

Validation command: `python3 -B experiment.py`, with argv/env retained in
[command.json](command.json). One Core Ultra 9 185H thread, affinity 0,
nice 19; 59-second wall/CPU and 512-MiB address-space caps. Estimated memory
64 MiB. Final run: **10.821527 seconds / 22,528 KiB RSS**, seed 2026101242.
There are 32 source-derived deliberately inconsistent synthetic SZC fixtures:
contexts 1/2/3, padded token extents 1/2/4, varied KV-interleaved head padding,
cube logs 0/2/6/7, two/three sum limbs, full-extension/base/Boolean/zero fields.
Two chunk/debug schedules preserve 2,520 independent original-cube group
samples, 5,040 candidate sample/degree checks, 720 actual claims, 144 terminal
group checks, 3,584 ordered finals, 5,376 extension-table and 192 extension
polynomial checks; 316 recoveries and 260 explicit zero-factor fallbacks.
128 other-group call checks and 64 scan/fold checks pass. No honest witness,
private input, trained weights, native proof or GPU job is used.

Independent reference uses tuple schoolbook Goldilocks2 arithmetic, expanded
monomials and prefix basis sums of the original Boolean cube. It does not call
the candidate's fold/descriptor/host-collapse implementation. The scheduling
baseline is copied research code derived from the pinned native evaluator.
All inputs/code/logs are hashed. Thirteen controls cover unsupported mappings,
generic fallback, non-lift sum/support, S-vs-Ht support, host coefficient,
off-domain quadratic behavior, round order and premature finals.
The first run exited 1 in an invalid negative-control comparison after all
fixture loops passed. [initial-control-selection](initial-control-selection/README.md)
retains its exact code/logs: S and Ht coincide at sampled j=0 representatives.
The corrected control compares the altered **full original cube**, including
padded trailing j, and detects the unsafe collapse. No failure is discarded.

Run `python3 -B accounting.py` for the separate count study. Sixteen formulas
match actually counted small full-extension fixtures. [cost-accounting.json](cost-accounting.json)
uses conditional m125 h_pad16 / T512 / initial n22 / Ht L13 / ls3 / lp2:

| Selected work | Existing grouped | Collapsed host |
|---|---:|---:|
| Group 0 bracket calls | 18,874,364 | 18,874,364 |
| Group 1 bracket calls | 10,485,758 | 20,487 |
| Group 2 bracket calls | 10,485,758 | 10,485,758 |
| Selected bracket/weight/accumulation + all-table fold Fp2 multiplications | 1,239,416,567 | 1,203,834,633 |

That removes **35,581,934 / 2.87086%** of the selected Fp2 multiplication
API count. Counting five base multiplications per Fp2 multiplication and two
per base multiplication, with added multiplicity scalings, gives 2.53766%.
Neither fraction is a timing bound or an 8B gain. Native optimizer/instruction
behavior can differ. Added: 32,782 endpoint reads (524,512 bytes of logical
field payload), 16,382 differences, 32,764 sample-advance additions and 66
base multiplicity scalings, typed/provenance dispatch and native integration.
No compact private table is allocated; scratch O(degree), allocator excluded.
The two remaining full-cube groups still require quadratic attention work.
T1024/2048/4096 count rows are hypothetical single-context geometries, not
larger admitted profiles or repeated resident passes.

Excluded/unchanged: full-row differences and sample advances, Eq construction,
factor/inversion/recovery/interpolation/reduction, extension rounds,
construction/census/verifier, witness, masks/RNG/transcript/PCS, transfers,
serialization and independent verification. No native compile/cache/parallel,
power/VRAM or end-to-end timing was measured. Whole-proof acceptance remains
with its existing owner.

Current measured bottleneck evidence is pinned unchanged: historical shared
T512 synthetic one-block125M diagnostic, two CPU threads / RTX4070 Laptop,
SZC 7.794 s inside proving 16.864 s; external witness 5.77 s, serialization
0.028 s, in-process byte verify 0.82 s, enclosing test process
27.523873283003923 s. Slot clock includes extensions and other work; the
count study covers only initial data rounds. The entire SZC slot is a broad
7.794-second envelope, **not** time credited to this host candidate.
An accepted private 8B baseline and affected host phase clock are absent.
End-to-end ceiling is `Nproved/(Ttotal-Cht_round+Cnew)`; the ideal upper
bound drops only `Cht_round`. No accepted 8B numeric ceiling follows.
Falsification: any cube/sample/degree/support/order/claim/final/extension,
refusal/mask/RNG/transcript/frozen-byte/privacy mismatch; invalid provenance;
or added native costs/peak/enclosing regression consuming the saved work.

[ht_host.rs](ht_host.rs) is an uncompiled/unapplied serial Rust helper sketch.
Owner first measures the group-1 bracket/weight/read/reduction share, then
ports only if useful. Wire the immutable plan through argument.rs SlotDef
and grouped.rs round; preserve native parallel thresholds. Require generic
masked/native transcript, original finals/extensions, fresh independent
verification, frozen bytes, refusal and full privacy checks under shared
build/heavy locks. No heavy job queued or merge performed.

Four qualified LIVE records added (225 ->229), details in source-records.json:
[Plonky3 release](https://github.com/Plonky3/Plonky3/releases/tag/v0.8.0)
and version-addressed strategy code, newly assessed older
[Bootle/Chiesa/Sotiraki 2021](https://eprint.iacr.org/2021/333), and an author
packed-mask experiment README. The release commit diff is pinned; strategy
runtime commit/update date is unknown. Apache license text inspected;
mask repository reports MIT but license fetch failed. The older paper PDF
returned 403; assessment is limited to primary abstract/metadata, not a
reproduced protocol. PR/file fetch failures remain. No downloaded code run.

Accepted independently verified complete private8B proofs/tokens: **0**.
Proof context null; passes 0; device CPU only. Steady-state/total-workload
rates, startup seconds/fraction, witness/proof/serialization/independent
verification, latency/lag/drain are unmeasured. No long-context prefill,
resident-model pass or decode proof. Fresh masks/full coverage/privacy remain.

Next local: keep private A_MX/A_SUM leading lifts compact during the actual
mixed grouped scan/bind/finals, extending earlier static typed-reader tests.
Use actual immutable native Priv descriptors and independently check arbitrary
private extension targets; unsupported mappings fall back. Count avoided
materialization/folds and added reads. Next owner: dominant SZC/recurring
witness clocks and masked mixed-reader gates before complete verified A/B.
