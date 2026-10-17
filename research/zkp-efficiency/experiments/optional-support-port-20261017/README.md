# Optional Ht/S supports: correct the research baseline before optimizing

Cycle 0053 — `20261017T032624Z-1d6d29cb`, 2026-10-17 UTC.
**No native speedup established.** This is a source-derived scalar/coefficient
port correction, independent algebra validation and allocation-free census.
No native Rust, GPU, receipt, mask generator or verifier ran or changed.

The old six-case factory census always supplied both padding supports.
Native `B::supp` instead returns `None` for full domains, `Gate::at` supplies
ONE, and `PadTerm::add` omits absent groups. `pad_on` comes from hosted
zero-rule planes; it controls extra challenges and source-declared bracket
degrees. For full-head/full-token qh32/T512 with no P3 S lift, both supports
and `pad_on` are absent. Bracket degrees are **3/1/1**, rather than 4/2/2;
the outer degree is 4 (five output samples), rather than 5 (six samples).
The port retains these original coordinates, widths, per-group claims,
zero-factor fallback, ordered finals and existing construction refusal.

Public support presence and `pad_on` remain separate fields. Four abstract
presence combinations are tested algebraically. They are not all admitted
native geometries. `construction_check` ports the source refusal when S
alone pads: the builder expects Ht's two zero-rule planes whenever `pad_on`
is true. Under the inspected size rules Ht-only has no geometry; P3 can make
S-only, but such a size-policy case keeps the builder refusal. Full
`Shape::new`, calibration and construction eligibility were **not executed**.
The new public policy uses `layout.rs`: **P3 lifts S, never Ht**, since Ht
carries A planes only. Tables for lifted S layouts are not ported here.

Run from the research directory:

```
python3 -B experiments/optional-support-port-20261017/run.py
```

Seed **2026101753**. Final exit0; 16.309020s experiment process,
25,428KiB RSS, one nice19 Intel Core Ultra9 185H thread pinned to CPU0.
Limits:59s wall/CPU,512MiB address space,64MiB estimated footprint;
wrapper timeout60s. No dependency install or heavy job.

100 fixtures / 600 schedules pass
5,520 direct original-cube round samples,
14,532 ordered direct-MLE final values,
384 arbitrary-extension clause values,
144 zero/random graph-schema checks,
208 independent tuple-ring padding weights,
and 924 public size-policy cases.
There are876 recoveries and636 explicit zero-factor fallbacks. Source-derived
construction checks admit24 abstract configurations and refuse8 S-only
configurations;19 additional size-policy cases retain that refusal. These
are Python tests of the port, **not native construction test passes**.

Coverage: cube logs0–3,2/3 remainder limbs,lookup counts1/2/7/8,
full-extension/zero/Boolean fixtures,all four support combinations,
chunks1/3/7,debug/release recovery, and four independently enumerated small
natural h/t/j shapes. The tuple-ring expansion calls neither scalar nor
coefficient bracket; original-cube MLE evaluation calls no candidate fold.
Controls catch Ht/S substitution,restarted zeta powers,gating LogUp helpers,
and deletion of present supports. Invalid metadata and support-without-pad_on
are refused. No private-value-based schedule selection or new privacy claim.

| No-lift shape, three-limb scalar seam | Legacy always-padded formula | Correct optional port |
|---|---:|---:|
| hp32/kv8/qh32/T512 bracket-only API operations | 6,698,302,780 | 4,181,720,663 |
| Support-table payload formula | 256MiB | 0 |
| Source-port carriers (not native slot length) | 30 | 28 |
| Group0 coefficient width if selected | 5 | 4 |
| Existing conditional factory selected groups | group0 | none |
| hp16/kv4/qh12/T512 bracket-only API operations | 3,349,151,036 | 3,349,151,036 |

The full-head correction is37.5704% below the previous three-limb scalar
formula (37.5441% with two limbs). This is **no new native work elimination**:
the code already takes the corrected branch. Padded qh12 and qh24 formulas
are unchanged. These bracket-only totals exclude interpolation,Eq generation,
recovery arithmetic,folds,PCS,masking,witnesses,transfers and serialization;
they are not the older all-phase API denominator or exact complete native
slot layouts. The census assumes release nonzero-factor sample1 recovery:
group0 evaluates4 original bracket samples on round0 and3 thereafter for
unpad;5 and4 for pad. No model-sized vector is allocated.

Added research costs:two public presence flags and separate pad_on metadata,
correct graph construction,independent references and retained source pins.
Native setup is already paid: two active pad groups retain14 weights for
three limbs but source `PadTerm::add` executes16 setup multiplications,
because the second call rebuilds the two preceding powers. The old14 figure
was sequential cached weight generation, not the literal native setup count.
There is no proposal to optimize these two tiny products. Peak native
registers,dispatch and complete elapsed time remain unmeasured.

A completed second inspection corrected a local modeling mistake: the first
passing attempt lifted Ht as well as S. It is retained under
`initial-before-P3-domain-ownership-correction/` and its P3 findings are
superseded. `before-native-outer-degree-accounting/` retains the later attempt
using a common six-sample outer validation envelope; the final run uses five
samples for unpad. No failed or superseded evidence was erased.

**Next local hypothesis:** test a separate four-coefficient group0 factory
on the actual unpadded branch. The current `padded_zero` factory policy
selects no group there; its padded improvement projections cannot establish
an 8B effect. Compare literal source sample evaluation with prepared
four-word construction,weighted reduction,Horner evaluation,setup/dispatch
and scratch,retaining five output samples,all claims/finals/refusals.
Falsify on any oracle/schema/refusal mismatch or added cost erasing saved
repeated scalar work. Do not infer benefit from lower degree alone.

Complete-proof ceiling is unmeasured:
`N/(T_complete - saved_recurring_scalar_time + added_prepare_reduce_dispatch_time)`.
This correction itself saves zero native time. Historical one-synthetic-125M
block,T512,one pass,RTX4070Laptop:SC_SZC7.794s,proof16.864s,witness5.77s,
encode0.028s,decode0.013s,in-process verification0.806s,
whole-test27.523873s,40,783,352B. The entire SC_SZC-removal upper bound is
28.317% of that enclosing time, not an 8B estimate. Startup and both recurring
witness paths lack the required split. Previous slower native fusion remains
a useful negative. Main/Claude owns guarded native integration and timings.

Seam:read-only sonnet-hardening `hashline/src/private_block/argument.rs`
B::supp810,PadTerm934,Gate978,pad_on1155,SC_SZC1699/groups1783/bracket1788;
`shape.rs` natural/true sizes976/991 and slots1139;
`layout.rs` domain_log_at170/carries_h_planes191;
`zkp-core/src/sumcheck/grouped.rs` row/part93,sample107,reduction121,recovery132.
Ten earlier native/measurement pins match cycle52;layout.rs is an added pin.
`copy-provenance.json`,`command.json`,`execution.json`,`source-diff.patch`
and `native-pins.json` retain sources,commands,actual exit and checksums.

LIVE primary search:older SpaGKR public/secret sparsity boundary,new GoQuant
changed-quantization filter,Plonky3 jagged terminal authentication and
October16rc.2,with GoldilocksNTT cache residency and NanoZKv2 scope refreshes.
`sources-cycle53.json` retains dates,exact URLs,license scope and failed
commit/PDF/package fetches. No author runtime,test or security claim was
reproduced; no foreign code copied/executed or new exactness/privacy ruling.

Accepted independently verified complete private8B proofs/passes/tokens0/0/0.
Proof context null;current device CPU only. Steady-state/total-workload rates,
startup duration/fraction,witness/proof/serialization/independent-verification
clocks,latency/lag/drain remain unmeasured. No long-context prefill,resident
model pass or decode proof. Larger workloads remain permitted with quadratic
attention,fresh masks and complete coverage/privacy;>=50/s unchanged and
unachieved. No production/runtime/Git/build/GPU/install/external action.

Final checkpoint integrity/accounting audit:144 checks passed. It verifies retained evidence and counts,not native proving or performance.
