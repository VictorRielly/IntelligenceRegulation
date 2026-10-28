# Consumer capacity correction before private lookup-GKR design

2026-10-20, cycle0105, run `20261020T131854Z-4f8a9e18`.
**Research interface only; no measured proving speedup or native patch.**

The full-layer/five-plane consumer changes the prior memory study materially:
8B T128 one-column rebuild128.006->208.005MiB once folds are counted.
Per-column top16 needs148.005MiB but3.870/3.885x fraction-tree construction
work (nonDD/DD), versus global470.018MiB at2.870/2.885x. Compare complete
costs before adopting either schedule. The72w-byte consumer floor is only
for immutable child pairs + four fold planes + dense equality; it is not a
theorem about GKR and not total proof fit.

Research patch/interface:
- `experiments/lookup-layer-consumer-20261020/consumer.py::allocation_trace(sizes,b,mode)`
  gives public symbolic allocation events/peak, tree work and leaf reads;
  `mode` is global forest or sequential column checkpoint reconstruction.
- `serve(read,n,b,p)` yields `(depth,immutable_child,private_root,counters)`;
  reader is synthetic in tests and must eventually bind original ordered A.
- `consume(child,point,challenges,lambda,p)` supplies cubic samples and final
  arithmetic for the two fraction equations; independent reference checks
  complete rows and interpolation. Unmasked and not a Fiat-Shamir protocol.

Actual pinned Rust seam (five pins in source-manifest): frozenR9 private_block
`protocol.rs` lines712/1149/1164 (fresh U8 reciprocal cache/helpers),
`argument.rs` lines934/1963 (`helper_sum`/`SC_TAB`), `shape.rs` lines1994/2054
(ordered lookups/sites), `layout.rs::lookups_at`. Current256-entry inversion
cache already exists; this study addresses recurring committed helpers,
not a missing inversion optimization. Proposed future provider would accept
ordered original columns and ONE prechallenge-bound global histogram;
all layer/root arrays remain internal private data, no new public messages.
No production file was edited and no Rust fragment is presented as compilable.

Validation:1515 probe checks/183 tiny layer consumers/12controls; independent
480 cost schedules,1440 cost mutations,80direct-basis cases/80alias controls,
five sourcepins. F65537 only. See README, commands.json, result and validation.
NativeFp2, masks, CFS, PCS, terminal delegation, full refusal equivalence,
whole-run soundness/joint-view privacy and independent receipt verification
are unresolved. Exact new mask/claim/PCS sites=null. Root-only binding fails
wrong-site permutation; test digests do not fix it privately. Preserve all
ordered links, global multiplicity and denominator checks and R9N-r9-a/b.
DD privacy and fidelity/profile gates are still owed. LOW layout not counted.

Before implementation: owner full phase/capacity clocks, then a versioned
masked protocol and measured complete-workload comparison. Native all-eleven
FZC compiler A/B remains higher priority. No merge/integration in this lane.
Next local: test destructive ownership transfer of freshly rebuilt child
buffers and symbolic equality under the same full arithmetic oracle; never
alias originalA or a retained checkpoint. Review resulting stream access
work and terminal binding before making a private memory or speed claim.
