# Compact private leading planes in grouped softmax

Cycle 0043, run `20261013T002555Z-f0cb53eb`, seed **2026101343**.
**Synthetic conformance passes; no native proving speed improvement measured.**
The native source/receipt/profile files were read only. No GPU, dependency
installation, native build, Git operation, heavy queue or external message.

## Question and baseline

Can SC_SZC A_MX and A_SUM keep their original leading-axis private plane
representation through the current heterogeneous/grouped driver, instead of
broadcasting each across the trailing token axis and repeatedly folding copies?
This extends the static typed-reader work and cycles39/40 public readers to
private leading planes. It does not infer a compact representation from secret
values, omit private padding, reuse masks or alter the attention relation.

All14 prior native/report pins still match (`input-manifest.json`).
`argument.rs` Priv/Cm/Coord:36-72, priv_table:208-273, SC_SZC:1719-1720 supply
the native source: one A slice, unit coefficient, log(Dom::Ht), and
Rho(0..logHt). The existing builder maps these to the leading coordinates,
then broadcasts unused trailing j. Shape/plane selection and the original
Priv mask_row/ext_round/claim-point identity remain owned by the native slot.
Unsupported Fixed/Flip/nonleading/multislice mappings use the old builder.

Current measured bottleneck remains the historical shared-box, synthetic
one-block125M/T512, two-thread RTX4070 Laptop b2 diagnostic: RS0.600s,
SZC7.794s inside16.864s proving; external witness5.77s, serialization0.028s,
in-process byte verification0.82s, enclosing27.523873283003923s. Startup was
not separated. These are not accepted private8B clocks. The synthetic12-block
GPU diagnostic is408.60922643699996s total,318.22s combined run prover,
12.15s in-process verify,484107456B; no fresh independent verifier flag.
The interrupted CLI has no terminal result. Stale reports do not prove liveness.
The individual A_MX/A_SUM construction/fold/read phase has no native clock.

## Reproduction and scope

From the research directory, exact commands are in `commands.txt`:

```text
python3 -B experiments/compact-private-grouped-20261013/experiment.py
python3 -B experiments/compact-private-grouped-20261013/constructor_check.py
python3 -B experiments/compact-private-grouped-20261013/accounting.py
```

Main check: **14.269063s**, **22220KiB** process RSS,
one nice19 CPU0 Intel Core Ultra9 185H thread, Python3.10.12; wall/CPU59s,
address-space512MiB, estimated64MiB. Time measures synthetic validation.
`command.json`, `execution.json`, `run.log`, `done` and hashes are retained.
No invocation failed. Code/reference/native/report pins are saved; the Rust
helper is uncompiled/unapplied. `constructor-result.json` records its own
seed2026101344 and 0.296248s/17512KiB small check.

Main fixtures use contexts1/2/3, padded tokens1/2/4 and padded heads1/4/8,
cube logs0/2/6/7, 26/30 original tables, two/three sum limbs; seeded full Fp2,
base, Boolean and zero planes are deliberately inconsistent. Arbitrary padded
private words are retained, including cases which are not honest witnesses.
The independent tuple Goldilocks2 original-cube definition and expanded
monomials call no compact reader, candidate fold or interpolation shortcut.
The materialized mixed baseline uses the same grouped schedule; native
GroupedEqRounds already factors equality. No new grouped gain is claimed.

Passed checks:

- 32fixtures,32 baseline schedules and96 compact schedules (chunks1/3/7,
 release-style subgroup recovery and debug explicit evaluation).
- 96 original-cube total checks;2520 independent subgroup samples,
 7560 sample/degree checks,1080 actual subgroup claims,216 terminal identities.
- 18528 original-cube private-reader checks;2688 original-order finals;
 483 recoveries and381 explicit zero-factor fallbacks without resampling.
- 16128 arbitrary private/public-zero extension table checks and576 expanded
 extension polynomials across two successive target sets. These additional
 synthetic extensions exercise representation identity, not a new native slot.
- 21 leading-length edge fixtures (0..n),621 reader checks with0/1/Fp2 bindings.
- 192 unchanged bracket-count checks,64 unchanged scan-count checks;
 384 compact fold/noop formula checks. Cost study adds192 formula checks.
- 24 controls: wrong slot/plane/cm/coefficient/Fixed/Flip/trailing coordinates/
 extension metadata use dense fallback; bounds/length/index/schedule refuse;
 stride/private source/padded-word sabotage and dropped private extension
 target alter outputs. Forged external lift attestation demonstrably underbinds.

Constructor check separately evaluates native plane~(claim_point) directly,
using tuple MLE arithmetic over synthetic committed source with an offset:
4590 binding/cube checks and270 finals;93 compact cases and177 exact fallback
cases. Base/full/zero words, unit/nonunit coefficients, A/H selection,
leading/Flip/Fixed/trailing mappings and0/1/Fp2 challenges are covered.
This is not an execution of native priv_table or a proof of its whole API.

## Removed work, added costs and end-to-end ceiling

Let N=2^n full score-cube words and H=2^L leading Ht words. Each of the two
private planes holds H rather than N field values. Across main rounds it
performs H-1 rather than N-1 fold lerps; every trailing bind still advances
its schedule once. All original finals remain in their original slots. No
private masks or targets are compressed; unchanged native extension code
reads original Priv metadata and source mask rows after data rounds.

At conditional m125 h_pad16/T512/n22/L13:

| Item | Dense two planes | Compact two planes |
|---|---:|---:|
| Initial logical Fp2 payload |128MiB|0.25MiB|
| Data-round fold lerps |8388606|16382|
| Constructor Fp2 writes, literal source model |16777216|16384|

**127.75MiB logical payload and8372224 fold multiplications/subtractions/adds
are removed.** This is6.65365% of all30 dense table folds, or7.39294% of the
27dense-table folds in the previous public-descriptor baseline. It is NOT
that fraction of proving time. Native Vec capacity persists after truncate;
compact peak starts at H, metadata/allocator excluded. Python allocation
behavior is different. Construction removes255.75MiB logical write payload,
127.75MiB broadcast read payload and8388608 cube-index loop visits; source
reads remain16384 Fp words. These are logical source operations, not DRAM
measurements, peak RSS or a hardware bandwidth lower bound.

Added:16775168 reader shifts across grouped scans, one public-state dispatch/
active-axis branch per reader call,18 inactive bind calls, O(H) private state/metadata,
source provenance/enum/parallel/census integration and compiler/locality costs.
There are16777212 unchanged private endpoint reads. A generic total scan would add8388608 index shifts for these planes;
SC_SZC is Host and does not call generic total in the normal native path.
The total tests validate reader API compatibility. Debug census may need full
logical iteration, preserving original counts/order without allocating N.

All grouped brackets, row differences/sample advances, other private/Eq/public
folds, table positions, helper/future-score/pad constraints, witness work,
fresh commitments/masks/PCS, transfer/serialization/verification remain.
No large geometry allocated; conditional T512/1024/2048/4096 at h_pad16/32
are in `cost-accounting.json`, not admitted profiles. Score work and saved
broadcast storage still grow quadratically with context. Fixed-context
resident passes and decode are separate workloads, neither measured here.

Complete ceiling is `Nproved/(Ttotal-Cmxsum_build_fold+Creader_and_integration)`.
Ideal bound removes only the affected construction/fold cost.
**Numeric accepted private8B ceiling is unknown.** Historical7.794s whole SZC
is a broad envelope, not the amount attributable to these two tables; no phase
clock licenses a speed estimate. Falsify on any cube/sample/degree/claim/
order/final/extension/source/refusal/mask/RNG/transcript/frozen-byte/independent
verifier/privacy mismatch, private-value-dependent admission, invalid provenance,
or added read/dispatch/native peak/enclosing cost consuming the saving.

## Ranked hypotheses

|Rank|Hypothesis and expected scope|Prerequisites, integration cost, exactness/privacy and falsification|
|---|---|---|
|1 owner|GPU SZC plus recurring witness; largest measured remaining phase.|High CUDA/lifetime integration; isolate duplicate witness. Exact native masked/frozen/refusal and complete independently verified A/B; regression rejects.|
|2 owner|Exact full-K split-int16 FFN down.|Packing/two products/i64/requant/workspace/transfers, ranges/calibration/device clocks. Low share or no enclosing gain rejects.|
|3 tested prior|Canonical four-reduction Fp2.|Native compiler/carry/register/provenance and masked receipt gates; count savings alone cannot establish speed.|
|4 NEW refined/tested|Mixed public driver plus compact private Ht planes.|Moderate source/reader/total/census/extension/verifier/parallel port;127.75MiB conditional payload saving, unpriced shifts. Immutable constructor source and original sites mandatory; no enclosing/peak gain rejects.|
|5 owner|Fresh fixed-context complete resident-pass slope.|Context/passes/concurrency/startup/all recurring clocks/proof lag/drain/peak and independent verification with fresh masks. Recurring>20ms/new proved position rejects50/s for that schedule.|
|6 NEW next local|Remove unused Eq0/1/2 dense round rows in the actual mixed grouped adapter.|Cycle29/30 symbolic Eq identity already tested; new gate is current grouped bracket dependency/provenance, final ordering and original public-zero extension. Eq finals computed from original points; generic total/census retains exact values. Avoid lost grouped savings, hidden extra per-row Eq products, or unsupported closure substitutions. Any parity/refusal/masked/peak/enclosing mismatch rejects.|
|7 retained modest|Ht host multiplicity and Eq suffix hierarchy.|Prior2.87% selected mul-count and0.2302% Eq prep+weight-count scope; owner affected-phase clocks missing. Prior slower native fusion preserved.|
|8 architecture queue|Regular-wiring GKR/product streaming/PCS/lookup/NTT.|Topology/field/PCS/setup/joint privacy migration and memory/time costs; no changed profile authorized. Author/kernel figures are not model throughput.|

## Integration seam and handoff

`leading_private.rs` supplies `try_from_priv/at/bind/terminal`; owner adds a
Leading variant beside Dense/Causal/Support in the existing research mixed
adapter. Generic unsupported mappings call native priv_table. Constructor
must derive plane id/offset/coefficient/coords from immutable native
SC_SZC/Layout/Priv definitions and committed pd.data, never an external
"this is a lift" flag. Prefix bindings use only L private source variables;
trailing variables advance schedule without data folds. Native parallel
thresholds/reduction must be owner-reviewed; this sketch is serial.

Keep `Tab::Priv` and the exact original source/site definitions for mask_eval,
claim_point/build_claim, ext_round, terminal counting and commitment claims.
Native shape/error behavior, tiny masked/frozen/refusal/fresh-verifier gates,
then affected construction/read/fold/census/extension/enclosing/peak A/B
under shared build/heavy locks are owed. No native job queued. Details in
`handoffs/20261013-compact-private-grouped.md`.

## Primary sources searched

Four LIVE records append233 total source records. Queries/raw responses,
exact URLs/access dates/date/license/commit qualifications and failures are
saved in `search-log.json` and `source-records.json`.

[Plonky3 PR2197](https://github.com/Plonky3/Plonky3/pull/2197), merged2026-09-18,
refines the older release-level assessment: regular packing needs the correct
height/gcd(height,width) cycle. Author quotient benchmark barely moves total
prove. We use native leading-coordinate mapping, not that cyclic formula.
The visible [v0.8 release diff](https://github.com/Plonky3/Plonky3/commit/a21e3ed42905040ad49c519e402f018381c12d0c)
was inspected and pinned; CHANGELOG2026-09-23. Runtime fix/merge hashes are
surfaced but their fetches fail, so not claimed inspected; Apache text read.

[ICICLEv4](https://github.com/ingonyama-zk/icicle/releases/tag/v4.0.0) refreshed,
visible Cargo version diff pinned6c77775961b0e4dc2be359feec1ac11536c18043;
MIT text inspected. Release display11Jul lacks year, commit date unknown;
no claim of2026release, currentHEAD or compatible Goldilocks2 grouped CUDA.
[Product time-space2025/1473](https://eprint.iacr.org/2025/1473), revised2026-02-25,
refreshed as generic reconstruction alternative; PDF403, abstract only.
New older [Thaler2013 regular-circuit work](https://eprint.iacr.org/2013/351),
received2013-06-10/revised2017-02-08, suggests exploiting wiring regularity;
independent-copy batching does not make attention token pairs independent.
PDF403/attempted author PDF inaccessible; abstract-only/high-cost architecture
filter. No downloaded source executed or author performance reproduced.

## Proof workload accounting

Accepted independently verified complete private8B proofs/passes/tokens:**0**.
DeviceCPU only; proof contextnull;passes0. Steady-state/total-workload rates,
startup duration/fraction,witness/proof/serialization/independent-verification,
latency/lag/drain clocks unmeasured. No prefill/resident pass/decode proof.
>=50proved tokens/s target unchanged; larger workloads allowed, quadratic
attention and fresh masks/full privacy/coverage required. Research files only,
excluding runtime. Saved reports are not notification-delivery evidence.
