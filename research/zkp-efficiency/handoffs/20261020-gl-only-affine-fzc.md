# Review candidate: host-free BASE GL-only raw-round-zero derivation

Cycle0099 / `20261020T071854Z-1076bec1`, 2026-10-20 UTC.
**Python equivalence/source counts only; no native speedup or proof. No merge.**

Question/result: GL-only avoids added host preweights while retaining a
smaller subset of the prior full-pair source savings. At L=2^21,k11,support:
14,680,064 fewer counted base products,97,517,568 fewer adds/subs,256MiB
fewer logical shared operand reads vs literal. No host setup/parameter/global/
capacity/barrier change. Full prepared pair still saves more source work;
choose by measured enclosing clocks and compiler/register evidence.

Patch location: active `ops/zkp-mvp/gpu-zerocheck/hashline/src/gpu/fzc_kernels.cu`
`fzs_impl<...,BASE>` raw&&!FOLD phase1b (~855). Research patch sketch:
`../experiments/gl-only-fzc-20261020/candidate_gl_only.cuh`.
Insert helper after fzs_derived_at; replace two endpoint calls/subtraction
with fzs_gl_only_pair_candidate<BASE>(...,lo,dif,hi). Keep every global/shared
store and barrier. Interface uses current parameters only; no Rust/ABI patch.
PL and non-BASE branches remain literal. Existing BASE flag/next==0 gating
unchanged. Coefficients/derived outputs remain Fp2; never scalarize them.
No scan on private data or expanded BASE eligibility is authorized.

Validation: 36 synthetic Python fixtures,144 rounds,2372 checks,15 negative
controls,90 source-cost cases. Independent original-slot quotient-field
polynomial and direct-original-MLE oracle; canonical bytes/high/final values
agree. Seed2026102099; entries8/16/32; Kh trained9..16; sparse public pad
weights,base/extension inputs. Three PL-only extension stress probes do not
admit new profiles. Artifact validation223 checks/eight current native pins.
Full commands/hardware/source hashes/results in experiment README/manifests.
The sketch remains uncompiled; synthetic hash challenges are not native FS.

Owner next: shared-lock tiny three-arm literal/GL-only/full-pair native A/B;
ptxas registers/spills, actual raw/BASE eligibility/public pad support,
exclusive and enclosing clocks. Compare masked rounds,next challenges,full
receipt bytes; freshly independently verify. Run all strict-GPU/refusal/CS/H-1
and current privacy gates; retain fresh masks/draws and one-opening schedule.
Reject mismatch,expanded eligibility,compiler elimination of alleged savings,
or enclosing regression. Unknown exclusive fraction f bounds even total
phase deletion by1/(1-f); this candidate removes only part. No GPU/model rate
inferred. New verified full proofs/passes/positions0/0/0; all model clocks,
startup and steady/total throughput unmeasured;8B>=50/s unachieved.

TenseUp and PCS-specific non-malleability sources are future research leads,
not security/privacy clearance for caches,private state or opening reuse.
