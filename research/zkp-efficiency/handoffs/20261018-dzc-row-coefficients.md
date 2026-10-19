# Unapplied candidate: complete D row coefficients

Cycle 0076, `20261018T052105Z-217b5106`, 2026-10-18 UTC.
Research only. No production patch, native proof or device timing.

Review candidate [run.py](../experiments/dzc-row-coefficients-20261018/run.py)
and its [evidence](../experiments/dzc-row-coefficients-20261018/README.md).

Native patch locations for owner review:

- `ops/zkp-mvp/gpu-zerocheck/hashline/src/private_block/argument.rs:1551`,
  `SC_DZC`: capture actual B/Ids/lookup/helper/host bindings and this proof's
  challenges after their normal draws. The same file's `run_slot` at 634–665
  chooses unknown-first-claim recovery for the host slot.
- `ops/zkp-mvp/gpu-zerocheck/zkp-core/src/sumcheck/rounds.rs:20`,
  `SumcheckRounds`: optional D evaluator, returning unchanged unmasked
  evaluations `0..=degree`, with original fold/finals order. The original
  polynomial must remain available to extension rounds, masking and final
  checks. Slot18's F GPU descriptor is not an existing D adapter.

Prototype interface:

```text
plan(actual table ids, lookup descriptors, helper ids, mu, nu,
     public constants, limb count, support, zeta, pad ids, alpha, g_u8)
    -> proof-local affine/bilinear coefficients and denominator offsets
row(original [low, high-low] endpoint pairs, plan)
    -> [c0,c1,c2,c3,c4]
reduce rows' coefficients; convert(sum, registered degree, recovered claim)
    -> original [s(0), ..., s(degree)]
fold(original tables, actual transcript challenge); finals(original order)
```

Bindings accumulate aliases instead of overwriting. Structural width dispatch
depends only on public syntax. Never trim by hidden zeros or coefficients.
Current real D has 59 original tables/34 lookups/17 helpers/54 private finals.
Neither a new private claim nor a full aggregate table is added. This does
not remove original tables or authentication work. Generic padded, odd-helper
and five-limb fixtures are not admission evidence for new profiles.

The captured Rust full expression/catalog with substitutes agrees on 30
synthetic fixtures: 2,145 grid +390 off-grid values, 90 round messages,
1,845 direct cube finals, 30 final polynomial relations, permutations/aliases,
schoolbook arithmetic and eleven controls. Independent closed-form counts
and source contracts pass. Exact public source pins are in `source-pins.json`;
all must be compared again before porting.

Baseline uses four scalar points after the full first round, not five on
every round. Including preparation, conversion, original differences and all
59 folds, counted N=524288 source-level products fall 16.6899% under native
Rust's 5/2 model. Known-initial-claim case saves only 7.6312%. Later-row
extension products rise 300->331; base products fall 236->72. No native time,
GPU bandwidth, peak scratch or end-to-end speedup follows. Native compiler
optimization may erase source-level opportunities. Karatsuba also adds
addition/subtraction costs. Common claim interpolation is unchanged; native
reduction/dispatch/allocation costs are unmeasured.

First local follow-up: stream two denominator polynomials and one helper
at a time, preserving the same calls/results while reducing logical temporary
retention. Do not carry a whole denominator array into a GPU port without
checking register/spill costs. 80 bytes of coefficient outputs is not peak
scratch. A fixed-array factory and native field tests are not yet supplied.

Required owner validation before promotion: real descriptor/layout admission;
actual alpha/g_u8 and fresh challenge plumbing; varying-challenge and malformed
witness/refusal controls; original finals and scalar claim recovery; fixed
degree/sample lengths, extension/CFS/mask-site/RNG draw identity; seeded native
proof bytes and next challenge; fresh-process verify and enclosing workload
clocks. Privacy joint-view and all existing security gates remain in force.
Use existing shared locks for native/device/heavy work; this handoff launches
none. Reject on any mismatch or total regression, including construction,
transfers, serialization, verification and pipeline drain.

All-D deletion ceiling in the carried 1.1B diagnostic is 1.18113x; actual D
clause share and 8B ceiling unknown. No accepted target proofs/passes/positions
were produced. The complete private 8B >=50/s high-end GPU target is unchanged.
