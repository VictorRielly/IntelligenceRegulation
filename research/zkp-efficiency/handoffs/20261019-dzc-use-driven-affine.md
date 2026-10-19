# Unapplied candidate: consume D affine terms at first use

Cycle0079, `20261019T111854Z-5ff11116`, 2026-10-19. Main/Claude reviews and
integrates; no merge, production edit, GPU or native performance result.

Interface: [run.py](../experiments/dzc-use-driven-affine-20261019/run.py),
`lazy_row(raw,p,use_driven=True)`: raw[j]=(lo,hi) of the current MSB pair;
proof-local p from prior-run.py::plan; output five row coefficients. Reduce
across rows, then convert to the original ordered0..=degree messages with
existing point1 recovery. Driver retains transcript, RNG, masks, folds,
extension rounds, refusal rules and original ordered finals/openings.

Patch seam: source-pinned
`ops/zkp-mvp/gpu-zerocheck/hashline/src/private_block/argument.rs::SC_DZC`
(line1551), behind
`zkp-core/src/sumcheck/rounds.rs::SumcheckRounds`. Six pins and snapshots in
experiment source-pins.json/native/. This requires the preceding unintegrated
coefficient evaluator, streamed helpers and lazy endpoints. It is not a
small reorder of the installed sample evaluator by itself.

At each source's first use, accumulate its combined affine source weight
exactly once; acquire bilinear operands before capturing the accumulator
because acquisition can add affine terms. After helper processing, drain
affine-only sources. The plan combines aliases by returned table index.
Do not skip zero weights or branch on field values. A static public plan
can replace Python dictionaries/sets; native code must realize last-use
release instead of retaining a dynamically indexed endpoint array.

Result: current unpadded59-table D catalogs complete logical peak77→27 Fp2
words (800 logical bytes per active worker,64.94%); source54→4,derived18,
round accumulator5 at peak.118 reads/59 differences and complete field
counts272/209/331/72 are unchanged. Original59 folds/finals remain; including
folds331/268/390/72, before common round reduction/conversion/plan.
No full table or private claim/opening removed. No physical register/VRAM/
speed evidence. Candidate source-retention control136words; no-memoization
adds118→138reads/59→69differences. Generic padding only93→87words.

Validation:30synthetic fixtures,N2/8/32,seed2026101979;1,950coefficients,
2,145Rust grid/390off-grid comparisons,90messages,1,845originalfinals,
30finalrelations,30aliases/permutations/affine-onlydrains,390charged traces,
12controls,681independent audit checks. Complete captured Rust expression/
catalog with exactu128 field and Shape/Layout substitutes, independent
Python clauses/direct cube. Main12.651142s/RSS56024KiB,compiler134256KiB;
audit0.587274s/RSS27840KiB,one nice19CPU0,each59s/512MiB. No dependency build
or foreign source execution.

End-to-end bound: newly parsed retained8B R6/b7,T128,32blocks,one16-threadCPU
pass,GPUoff,D44.833/total471.580s. Removing ALL D at zero cost gives at most
1.105058×/0.299944diagnosticpositions/s; not the candidate prediction or GPU
bound. Native affected D row time, static compiler allocation and total gain
remain unknown. Include setup/dispatch/scalar scratch/reduction/conversion/
folds/launches/transfers/drain/serialization/fresh verification in timing.
All native work belongs to owner shared build/heavy locks.

Outstanding gates: actual registered profiles and actual alpha/g_u8/mu/nu
challenges; public original source mapping including all aliases and generic
fallbacks; exact seeded bytes/RNG draw schedule/refusals/degree; extension,
fresh masks/PCS/final-opening order; fresh receipt/tamper and joint-view privacy
gates. Synthetic alpha/g_u8 constants are not reusable proof setup. No mask or
opening reuse/privacy weakening. D30 dictionary does not follow from this row.

Next local experiment: static named-local Rust emitter with proof-local
runtime scalar parameters, full differential and lowered scalar DAG/assembly
inspection under CPU-light limits. Owner then tests real D kernel and enclosing
complete-stack slopes; reject native resource/timing loss even if logical
words shrink.
