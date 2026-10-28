# Owner review: paired raw round-zero FZC derivation

Cycle 0097, `20261020T051854Z-d5b6bbb8`. **Research sketch; no native build,
device validation, receipt or measured proving improvement. Do not merge as-is.**

The smaller candidate keeps the current global derived GL/PL tables and all
their later folds. In `fzs_impl`'s `raw && !FOLD` phase 1b, compute affine(lo)
and homogeneous(delta) instead of two endpoint evaluations followed by a
subtraction. Preweight the public pad coefficients with current `mu_pad`.
Use `hi = lo + delta` for the existing global high-half store. Keep both global
stores, both shared value/difference stores and the existing barrier.

Reviewable code: `experiments/affine-fzc-budget-20261020/candidate_pair.cuh`.
It defines `fzs_derived_pair_candidate(sv, sd, lane, which, original_params,
prepared_pad, lo, dif)`, using the current CUDA helpers. This is an adapter
sketch, not an applied diff; coefficient preparation/staging remains owner work.
Patch location is the active GPU candidate's `hashline/src/gpu/fzc_kernels.cu`
around `fzs_derived_at` (line 766) and its raw phase (lines 855–873), plus
`cuda.rs::DevFzcRounds::new` for the current public coefficient preparation.
Exact source paths and hashes are in the experiment's `source-manifest.json`.
Do not treat CPU R9/DD and this GPU candidate as the same source revision.

`prepared_pad[j] = mu_pad * pad_weight[j]` is computed once per sumcheck,
after its definition draws, and retained only for that evaluator. Preserve
the original descriptor/params for dense/raw-off variants and host evaluation.
A possible implementation appends 22 u64 coefficient words to an internal
parameter allocation and stages them only for the raw round-zero branch.
Up to 176 additional shared bytes and per-CTA parameter loads can affect
occupancy. Do not compute the weights once per CTA and call that setup once
per sumcheck, and never cache them across proofs. Coefficient-zero branches
depend only on the public descriptor/challenges, never on private A values.

Synthetic validation: 36 fixtures, 144 rounds, 1,599 checks, seven algebra
controls, including extension values, high-store reconstruction and stale
preweighting. Separate original-slot schoolbook field/MLE reference matches
canonical round bytes. The 720-case event/formula cost model and seven
accounting controls pass. Python only; no native masked transcript or verifier.

At illustrative F-cube L=2^21/support/11 pad weights, the raw-only candidate
removes 6,291,456 device base products and 65,011,712 base adds/subs by source
call count, plus 304 MiB of logical derived-operand shared reads. It adds
11 host Fp2 products, <=176 parameter bytes and per-CTA staging; no new chunk
barriers, no global/table-capacity saving. Required high-store reconstruction
is included in these numbers. Compiler lowering, cache/physical traffic and
register/occupancy effects are unknown. End-to-end ceiling is the unknown
exclusive raw-derived share, not a complete 8B throughput prediction.

Dense-pad full rematerialization is demoted: even after paired preweighting,
its illustrative saved256 MiB global traffic adds85,983,134 base products,
226,492,122 adds/subs, ~304 MiB logical shared reads and32,772 CTA-chunk barriers.
Those barriers are not serialized global waits. Earlier pool models saved
zero additional backing in24/24 resident cases. Keep capacity gating; do not
promote this more invasive option just for a smaller request.

Owner acceptance: under shared build/heavy locks, inspect generated code and
registers, run tiny differential device bodies (base/extension, support on/off,
empty/sparse/full pad coefficients, degrees4/5 and recovered/explicit s1),
shadow native masked rounds and next challenges, strict GPU/refusal/CS/H-1
controls, all dense/raw-off/split-off/unfused/tail/finals fallbacks, complete
frozen receipt-byte equality and fresh independent verification. Keep original
mask/RNG/opening schedule and current privacy gates. Benchmark actual enclosing
raw slot phase and full workload, with setup and serialization, rather than
source-operation deltas. Reject on any mismatch or enclosing regression.

The complete private8B >=50 proved-token/s target is unchanged. No GPU,
independently verified proof, model context or token was produced this cycle.
This local handoff is not an external message or a merge authorization.
