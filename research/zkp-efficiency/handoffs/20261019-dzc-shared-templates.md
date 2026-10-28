# Shared D helper templates: retain code-size finding, no speed promotion

Cycle0082 `20261019T141854Z-0a847d64`,2026-10-19UTC.

Research-only patch is experiments/dzc-shared-templates-20261019/grouping.py
(`shared_plan`, `emit`), selected by run.py::emit_arm. Generated kernels.rs
exports `driven(raw:*const Fp2,params:*const Fp2,bases:*const u64,out:*mut Fp2)`.
118Fp2 endpoints,129 proof-local Fp2 parameters,36 canonical u64 parameters,
five coefficients. Native seam is GPU-lane private_block/argument.rs SC_DZC
at1551 and SumcheckRounds; source-pins binds the exact files. No production
patch or merge. Public topology/maps can be planned independently of values;
all runtime scalar material must be refreshed for each actual proof.

19 unique groups→10 template bodies, still19 calls and884 field primitives.
Reachable code145,739→78,421B(46.19% decrease), plus634B static maps; requested
row bytes8,528→9,162. Stack remains504B vs scalar424B. Shared median4.658us
vs unique4.543us, scalar3.713us; noisy nine triplets, only3/9 favor shared.
No speed improvement is established; do not integrate on code size alone.

Validation passes six synthetic fixtures/two scalar catalogs/N2,8,32/seed
2026101982:780 coefficients,390 grid/78 off-grid original-Rust evaluations,
18 messages,354 original finals,six final relations,36zero bindings,eight
native-path controls. Independent1,455-check lineage/map/initialization/
assembly/source audit and six controls pass. A compiled wrong-map control
changes a valid parameter load and fails equality, with no uninitialized read.
Original59 tables/folds/finals retained. Exact commands, compiler/hardware,
hashes and limits are in README,source-pins,hardware and validation artifacts.

This remains a synthetic coefficient prototype with documented capture
field/Shape/Layout substitutes and artificial noinline baseline adapters.
Actual native profiles,challenges,alpha,g_u8,seeded bytes,RNG,refusals,masks,
extensions,PCS/finals,fresh-process verification/tamper,joint-view privacy,
native/GPU compiler resources and whole-D/full-stack clocks are unresolved.
No masks/openings are reused and no private/public statement changes.

Delete-all-D ceiling1.105058x applies only to the carried8B CPU T128 diagnostic,
not this strict-subset prototype or GPU. Target receipts/passes/positions0.
Owner whole-prover GPU and completed resident-pass slope measurements outrank
further helper tuning. If this seam remains useful, first census typed affine
address shifts to reject or justify removing the634B index-read overhead.
