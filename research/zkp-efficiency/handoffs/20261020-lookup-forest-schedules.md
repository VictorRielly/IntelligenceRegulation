# Fraction-forest service schedules — review handoff, unapplied

Cycle0104, `20261020T121854Z-ee6ad7b9`. No native patch, measured proving
speedup or privacy acceptance. [Experiment](../experiments/lookup-forest-schedules-20261020/README.md).

The frozen R9 w32/fE9 T128 count retains all83 original ordered U8 columns
and one global histogram. Full fractional forest arithmetic storage is
3170.016/2954.016MiB non-DD/DD, versus420.25/390.25MiB U8 helper data.
One-column rebuild lowers its modeled storage to128.006MiB, with nearly2x
fraction-tree internal work and2x leaf generation. Top12-depth caching gives
84.766MiB at6.676/6.677x internal work and8.663x leaf generation. Roots-only
gives64.005MiB but18.663x internal work. These ratios are versus constructing
one fraction forest, never versus the native helper writer or total proving.
COUNTED ONLY T512: one-column512.006MiB; top12 gives277.266MiB at9.275/8.884x
internal work. No T512 profile/proof or actual memory fit established.

Storage excludes A/model, other H/M, GKR folds/sumcheck scratch, masks,
CFS/PCS sites, commitment encoding/trees, transfers and launches. Net saved
bytes and full runtime unknown. Caches/root joins stay live conservatively.
84 private root pairs are semantic values, not authorized public messages.
Exact mask/claim/PCS site counts are explicitly unknown until the protocol is
designed. No plan licenses new private openings, unmasked roots or mask reuse.

Research interface / patch location:

- `experiments/lookup-forest-schedules-20261020/schedule.py::plan(sizes,b)`
  emits construction/recomputation/leaf counts and partial storage bound.
- `serve(read,n,b,p)` supplies tiny full layers top-down; tests retain copies,
  so the harness's RSS is not the modeled streaming memory.
- `reference.py::{layers,direct,enumerate_cost}` provides independent
  bottom-up/direct-inverse and width-count oracles. Native-source/input
  hashes are in source-manifest.json and input-pin.json.

Rust seam is frozen R9 `private_block/shape.rs` lookup/helper/site counts,
`layout.rs::lookups_at` ordered original A links, `argument.rs::helper_sum`
and SC_TAB, `protocol.rs::u8_denominator_inverses/write_h` and H commit.
This is a pre-prototype ledger, not a change to those files. Main/Claude
must review any new versioned construction; no merge in this lane.

Validation:959 probe checks/116 tiny cases/9 controls;5641 audit checks,
1500 cost mutations,1000 tiny column services,30 mixed-height root checks,
five source pins unchanged. F65537 synthetic arithmetic only. Wrong-site
permutation preserves the root: the ordered A link is indispensable.
Zero-multiplicity denominators still need nonzero checks; `(0,0)` roots cannot
justify dropping refusals. One global histogram enters once. Initial
singleton work-ratio division-by-zero and correction are retained. Probe
0.066202s/16284KiB, audit0.165969s/14980KiB; one thread,59s/512MiB caps.

Before promotion: actual top-down GKR consumer contract, original leaf/site
binding, one committed histogram before challenges, all table/unused
denominator refusals, fresh masking/CFS/PCS schedule and joint nonlinear/
terminal privacy argument. R9 N-r9-a/b, DD privacy gate, D32 fidelity and
D33 frozen-R7 scope remain. Free-deletion ceiling<=1/(1-f), affected
exclusive elapsed fraction f unknown. Reject any altered relation/refusal/
privacy or if added whole-proof work erases savings.

Next local: derive and test a per-column checkpoint/rebuild Pareto frontier
under an explicit layer-consumer contract; do not equate layer service with
complete GKR. Owner priority: actual GPU phase/capacity coverage, verified
resident1/2/4/8 and all-eleven FZC compiler A/B. Sources/dates/license fetch
failures retained; no author performance reproduced. Full-stack new
proofs/passes/positions0/0/0; all new proof clocks/rates unmeasured.
