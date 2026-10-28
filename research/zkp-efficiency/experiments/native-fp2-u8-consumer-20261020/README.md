# Native Fp2 ordered U8 consumer prerequisite — cycle0108

Run `20261020T161854Z-f0b8edce`, 2026-10-20 UTC. **No proving speed improvement measured.**
The prior challenge-causal tiled consumer now runs over the actual project
field Fp[u]/(u²−7), p=2^64−2^32+1. This is an unmasked arithmetic prerequisite
for a prospective protocol replacement; it is not a production proof patch.

The baseline already builds a fresh256-entry reciprocal cache once per
attempt. The native U8 table later inverts every table denominator before
multiplicity multiplication. This means a zero denominator at an absent
value still refuses, even if its multiplicity is zero. No new inversion
optimization was discovered. Cross-attempt caching fails a differential control.

`Attempt` retains a challenge-local256-entry denominator table (4096B of Fp2
payload) beside the reciprocal cache. Byte rescans read these denominators;
out-of-range i64 values retain the old individual-inverse arithmetic for
dishonest-witness tests. `OrderedLookup` reads immutable synthetic A planes
with the native wrapping-i64 Lk expression rule. This does not admit invalid
ranges or modify any refusal/timing/draw/absorb policy.

## Result and evidence

- Main: 10386 checks, 3168 native helper entries,
  100 tiled consumers, 40 native resident-layer cases,
  16 controls. Original leaf sizes2..64, depths1..5,
  prefix rounds0..4; exact0/1 and non-base-field challenges.
- Independent audit: 1766 checks, 96 inverses via exponent p²−2,
  40 saved original-MLE fixtures, 164 native affine/wrapping values,
  every one of256 possible zero table-denominator sites, and
  28 more consumers (including256-entry sparse global table, depth8).
  Six unchanged source pins; three source-fragment mutation controls;
  four overflow cases show why unbounded arithmetic is not a drop-in reader.
- Every sampled cubic row, interpolated claim chain, terminal and four
  original MLEs matches independent Boolean-basis evaluation. Compiled native
  field/helper extraction also matches40 materialized resident-layer cases.
  The source is revisited in order0..n−1 exactlyq+1 times and stays immutable.
  The two original helper bodies match their frozen source exactly.

Controls cover absent/present zero denominators, zero numerator, signed fallback,
stale cache, wrong extension polynomial, wrong-site swap that preserves the
root but changes ordered MLEs, bit order, altered sample/terminal, missing
challenge, source drift and degenerate0/0. These are arithmetic/refusal controls,
not a native privacy, soundness, Fiat-Shamir or saved-receipt verifier.

The resident Rust reference is independently written using an unmodified copy
of frozen R9 `zkp-core/src/field.rs` and two inspected pure helper extractions.
It does not compile or run the native prover. No downloaded code executed.
The Python tuple reference uses polynomial convolution and explicit Boolean
basis sums, independently of the candidate field and fold implementation.
The consumer's explicit LSB order is NOT yet a native MSB/profile adapter.

## Costs, ceiling and falsification

Potentially eliminated work is materialized looked-U8 columns and repeated
byte-denominator construction within the prospective consumer. Native H,
commitments and proof work are unchanged. Added costs: the4KiB payload,
every source-expression evaluation/rescan, regeneration, fold, equality table,
ordered-A terminal link, full table checks, private masks/CFS/PCS and review.
The previous68.030->36.022MiB selected-array model is carried evidence only;
this cycle measures no native allocation or fit, and does not reprice it.

If f is the unknown exclusive affected proving-time fraction, even free
deletion has end-to-end speed ceiling<=1/(1−f), before added costs. No numeric
5090 proof rate follows. Falsify on any original helper/MLE/refusal/RNG-order
mismatch, changed source, stale cache, hidden retention/PCS cost erasing savings,
failed privacy/soundness binding, no relevant device capacity cliff, or slower
complete workloads. Unmasked roots and messages cannot be exposed as private
proofs. Paired helper/layout grouping, all source sites, native MSB mapping,
mask sites and terminal openings are still integration obligations.

## Reproduction and limits

```
python3 experiments/native-fp2-u8-consumer-20261020/run_bounded.py build_oracle.py
python3 experiments/native-fp2-u8-consumer-20261020/run_bounded.py probe.py
python3 experiments/native-fp2-u8-consumer-20261020/run_bounded.py validate.py
```

Seed20261020108; independent audit20261020109. Resource runner pins the first
allowed core, nice19; one CPU worker, one Rust codegen unit,59s CPU/alarm,
60s parent and512MiB address space per command. Estimate64MiB for probe/audit,
256MiB for the dependency-free adapter build. Intel Core Ultra9 185H / WSL2;
no accelerator invoked. Final build 0.423489s / 136596KiB;
probe 0.313142s / 19016KiB;
audit 2.924653s / 17392KiB. These are diagnostic
correctness clocks, not comparable proving benchmarks. All passes succeeded;
the pre-reader stage and earlier audit are preserved under `before-affine-reader/`.

## Sources and ranking

Thirteen native LIVE search queries;11 records appended639->650. Material leads:
[LogUp-GKR](https://eprint.iacr.org/2023/1284),
[Chimera's October16 revision](https://eprint.iacr.org/2026/1388),
[Plonky3 equality/mask/release sources](https://github.com/Plonky3/Plonky3/releases/tag/p3-sumcheck-v0.9.0-rc.2),
and newly screened older [OpenSSLNTRU section2.2](https://www.usenix.org/system/files/sec22-bernstein.pdf).
The older batch method already exists in native code. No author speedup was
reproduced. Verified dates, licenses, version/commit scope, fetch failures and
prior assessments are in `source-records.json`. No new external commit diff
was successfully inspected; release listings disagree on cached/latest views.

Twenty ranked hypotheses retained in `hypotheses.json`; rank7 materially refined.
Top three remain complete GPU/resident workload evidence, DD context scaling
after T128's measured null, and actual capacity/exclusive phase tracing.
The all-eleven FZC native compiler A/B remains ahead of this protocol redesign.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context/device: **none**. Witness, proof, serialization, verification,
startup duration/fraction, steady-state and total-workload proved rates:
**unmeasured**. CPU clocks here measure research checking only. No long-context
prefill, resident-model pass or decode was performed. Larger workloads remain
allowed; longer context can increase attention work quadratically. The complete
private 8B target of >=50 proved positions/s on RTX 5090 or another named
high-end GPU remains unachieved.

Carried historical diagnostic, not rerun or independently reverified here:
non-DD 8B T128, L32, one 16-thread CPU pass, GPU off; total478.737s =
0.267370positions/s. prove_run393.785s includes witness98.348s/load17.595s;
seal84.824s includes overlapping subwork. Receipt922711264B; fresh verify42.709s
+public load13.681s; recheck34.395s+load10.739s. Isolated serialization,
startup fraction and steady slope unknown. This is not a high-end GPU result.

## Handoff and next action

Actual seams: frozen R9 `protocol::lookup_values_at`,
`u8_denominator_inverses`, `helper_one`, `write_h`; `layout::Lk/lookups_at`;
`argument::helper_sum/SC_TAB`; native `zkp-core::field`. Interfaces are
`OrderedLookup.read(index)->(numerator,denominator)` and
`consumer(...)` yielding a complete cubic row before accepting its challenge.
Research paths: `fp2.py`, `tiled_fp2.py`, `oracle.rs`, `reference.py`.
No production patch is ready. Main/Claude reviews any integration; no merge.

Build a source-pinned claim/mask/PCS site ledger for a prospective private
fraction-tree replacement: both child branches per layer, all83/85 ordered
original U8 links and one global table. Make the LSB consumer to native MSB
point mapping explicit. Reject count-preserving wrong-site merges; keep
unknown private costs unknown before making a net-memory or time claim.

Owner next: complete GPU phase/capacity clocks, independently verified
fixed-context resident1/2/4/8 workloads, DD context scaling and the all-eleven
FZC compiler A/B under shared build/heavy locks. Retain fresh masking and count
only completed, independently verified full-stack receipts.

R9 N-r9-a/b, DD privacy gate, D32 fidelity and narrow D33/D34/D35 scopes remain.
LOW fidelity layout excluded. Only research excluding runtime written; no
production/Git/GPU/install/external writes/messages/purchases/escalation.
Saved reports do not establish external delivery.
