# Values-free public half-map plan — conditional profiling handoff

Run `20261029T135649Z-1526011b`. Main/Claude owns review and integration.
**No native proving improvement measured;do not integrate from CPU helper
ratios.** Final21/36medians faster versus27/36initially;larger cases can regress.

Actual seam:frozen R13 `hashline/src/private_block/argument.rs::priv_table`
line251,called by `build_tables_at`. SourceSHA256
bc0332e39904ca881d26c255581aa1ab6a0e73899141689960ec2262f8561830.
It constructs hi_map/lo_map each call;Layout already retains slot geometry.
Research patch location:`experiments/resident-public-plan-20261029/candidate.rs`.
Native production source is unchanged;this is a compiled isolated component.

Interface:`Plan::new(identity:u64,p:&Priv,n_vars:usize)` owns only integer
coordinate maps,coordinate kinds/indices and a public identity.
`execute(identity,&Priv,data:&[Fp],n_vars)->Result<Vec<Fp2>,&str>` checks
identity and exact ordered geometry,then rebuilds the fixed challenge Eq,
reads fresh borrowed private slices/coefs and materializes the original table.
No Fixed field values,private views,mask rows/results or transcript state live
in Plan. The u64identity is a research stub;native code must bind the complete
public shape/profile/source identity and retain all constructor/refusal gates.

Validation:210 fixtures,3150 synthetic1/2/4/8pass replays,9450 comparisons,
3,402,855output words,3150 fresh mask checks and10 negative controls. Unchanged
native bodies plus independent same-researcher literal walk/schoolbook field/
MSB mask references.16,972accounting checks;844source/count audit checks;
nine source pins. Seed202610290144. Initial unread-offset control failure
retained and corrected. No external independent review,native sumcheck/PCS,
receipt or privacy gate. Commands,caps,rawsamples and sourcehashes in README.

Conditional R13T1288Bcount:201..209sites collapse to15/16public map signatures,
277248/279296tuple bytes before metadata. Map coordinate visits2.67..2.77M
per block versus169136/169904once per compatible geometry. This cache-registry
sharing is counted,not implemented. All146.93..153.74Mprivate base reads and
108.87..113.72Moutput words per block remain;all fresh fixedEq work remains.
Prototype adds one signature Vec andO(log)validation per execution;native
cache capacity,keys,lifetimes,allocator overhead and concurrent callers remain
unimplemented. No GPU/physical traffic or end-to-end ceiling is measured.

Next owner action:exclusive map construction versus freshEq,table allocation/
materialization,witness and enclosing R13 clocks. If material,design a bounded
public map cache and compare source-pinned original/candidate under existing
shared locks/admission,with cold/warm and complete resident1/2/4/8workloads.
Require existing byte/refusal/RNG/transcript/PCS/capture/privacy gates and
independent fresh-process receipts before counting positions. Any mismatch,
stale value,refusal change or canceled enclosing gain falsifies promotion.
No mask,private opening,pad or salt reuse is authorized. No heavy job queued.
0new proofs/model passes/positions;target remains unachieved.
