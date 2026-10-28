# Owner review note: avoid direct dense one-hot U8 transplant

Cycle0121 `20261021T051854Z-3d9d2756` — 2026-10-21T05:31:54.087303+00:00. **Negative cost result; no native patch.**

`experiments/u8-address-increment-20261021/candidate.py` exposes synthetic
`check_factors(source,witness,d)`, `check_bits(source,witness)`,
`check_events(source,events,histogram)` and three equivalent MLE evaluators.
`source` is an ordered list of((domain,column,row),canonicalFieldValue), not a
published witness. Supported domains includeDd. All data here are synthetic.
This interface is reviewable contract evidence, not a private proof adapter.

Validation:3337checks,512factor/128complement fixtures,48dense MLE
cases,51controls; source/order audit51checks/6pins. Independent reference by
same researcher; no external review. Seed202610210121;oneCPU,under2seconds
final diagnostic,estimated64MiB. Logs and hashes retained. No build/GPU.

FrozenR9 seams and exact anchors are in source-manifest/anchors.json:
- protocol.rs:u8_denominator_inverses, paired helper loop/write_h; A/M beforealpha.
- layout.rs:lookups_at owns byte/symmetric/scaled affine source obligations.
- argument.rs:helper_sum andSC_TAB own reciprocal/global histogram relations.
- zkp-core pcs.rs:encode_row_zk andcommit_zk_owned_with_tag draw freshpads/salts,
  encode every dense row and hash all encoded columns in the selected host path.

Native U8H already uses two base coordinates per paired query-column group.
Direct d4/d8 factor data costs6.19140625GiB at8B T128nonDD versus420.25MiB
original U8H; virtual complement bitplanes3.095703125GiB. These15.086x/7.543x
DATA ratios reject only these layouts as logical-byte improvements. Do not
substitute sparse nonzero counts for actual dense encoded capacity/work.
Other owners, padding,masks/PCS/scratch and actual device capacity are omitted.
T512 is counted-only/unregistered. New LOW/HIGH fidelity shapes are excluded.

Obligations: bind every ordered affine original-A source and padding support;
Booleanity/range/symmetric endpoints/scaled top bits; private virtualization
sumcheck and its claims; fresh masking/PCS/CFS/current whole-run soundness;
retain native nonU8/table/denominator refusal policy unless a new relation is
explicitly reviewed. New private commitment/mask/group counts are unknown,
not zero. All current privacy gates are owed for any new protocol.

Controls: same histogram permits wrong order; one-hot without source link also
permits it; sum/address without Booleanity permitsq256; characteristic251 admits
252hot rows (not native field); product of factor MLEs at a nonBoolean time is
wrong. A single fixed-point evaluator is no source-binding proof. Counter
increments are a diagnostic contract; read-only Shout does not require them.
Current Jolt docs sayAkita lacksZK, so lattice benchmark claims do not validate
this private target. No unmasked traces/roots should enter public receipts.

Next local: count shared original affine sources, independently enumerate exact
byte/symmetric/scaled ranges and support, and price distinct bitplanes/private
claims. Reject any binding/refusal/privacy drift or enclosing workload regression.
Owner next: complete GPU exclusive/enclosing clocks, actualcapacity, verified
resident1/2/4/8. Amdahl free-deletion ceiling<=1/(1-f),unknownf,before addedcosts.
Main/Claude reviews/integrates; no merge or permission to launch heavy jobs.

New completed, independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context and accelerator: **none**. Research device: one Intel(R) Core(TM) Ultra 9 185H
CPU worker. Witness, proof, serialization and verification clocks: **unmeasured**.
Startup duration/fraction, steady-state rate and total-workload rate: **unmeasured**.
No long-context prefill, repeated resident-model proof passes or decode ran.
T128/T512 are symbolic geometries; T512 is unregistered counted-only, not an
admitted workload. Longer workloads remain allowed; increasing context can
increase attention work quadratically. The complete private8B >=50 proved
tokens/s target on RTX5090 or another named high-end GPU remains unachieved.


Checkpoint amendment, 2026-10-21 05:32 UTC: live decisions changed during this
cycle. D30 now records the completed DD gate:13/13 staged records PASS,zero
unexplained leaves,on the DD dev rung and TinyLlama T128 L1/2. This is gate
evidence only; no privacy statement yet covers a DD profile. It is not8B/GPU
privacy acceptance. Rank2 prerequisite/status updated; top-four order unchanged.
The exact live decision copy/diff is retained; no owner evidence reproduced.
