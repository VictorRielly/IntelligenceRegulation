# Review supplement: native pad counts and affine FZC eligibility

Cycle0100, `20261020T081854Z-6e7df31f`, 2026-10-20.
**Source-backed public-constructor/gate result only; no native speedup.**

Use this when reviewing the uncompiled cycle0098 full BASE pair and
cycle0099 host-free GL-only sketches. This delivery does not patch production.

Accepted padded FFN descriptors in both inspected lanes use all eleven
nonzero zeta powers. `zero_rule_a_planes(Dom::F)` includes all eleven planes;
the only exemption A_E is outside F. `SC_FZC` hosts one group and refuses
zero zeta; its powers begin at one. `mu_pad` can be zero, but existing
`FZ_PADW` values remain unscaled and nonzero. No retry or special acceptance
is proposed. The earlier k=1/3/8 cases are controls, not caller incidence.

Interface and source locations in `ops/zkp-mvp/gpu-zerocheck/hashline/src/`:

- `private_block/argument.rs:1709` draws zeta and builds the descriptor;
  `PadTerm::add` at1047 orders its powers. `pad.rs:365` selects planes;
  `shape.rs:1610` supplies all eleven F planes.
- `gpu/fzc.rs:260` serializes the parameter block; FZ_PADW is word62,
  eleven Fp2 values, and mu_pad is word28. Prepare `mu_pad*w_j` freshly per
  sumcheck for the full pair; do not overwrite the original weights or cache
  them across fresh challenges.
- `gpu/cuda.rs:4300` retains BASE/raw eligibility. Source tables3..19 must
  be resident; split/fused/raw switches, n>=3 and n-1>tail_log still apply.
  BASE checks all A tables3..13 and support20; `:4628` limits it to next==0.
- `gpu/fzc_kernels.cu:855` raw&&!FOLD phase1b is the adapter seam. Keep both
  full-coordinate high/low global stores, shared writes and barriers.
  Helpers, mu and derived outputs remain extension-valued.

Candidate patch/sketch locations:
`experiments/gl-only-fzc-20261020/candidate_gl_only.cuh` and
`experiments/base-affine-fzc-20261020/candidate_base_pair.cuh` (the latter
depends on cycle0097's extension fallback). Both remain uncompiled sketches.
This supplement provides `experiments/public-pad-eligibility-20261020/`:
independent public algebra, model/reference gates, source audit, snapshots,
hashes, commands and limits. Final gates: 7,616 checks/640 descriptor cases/
3,132 dispatch cases/46 negative controls; source audit51 assertions/six
source mutations/13 unchanged pins. One CPU thread,0.442s/12,268KiB RSS.
No native masks/transcript/PCS/receipt/verifier or valid transformer witness.

Keep source lanes separate. Frozen R9's inspected F term has the same
eleven-plane rule under DD and non-DD, but **does not contain this GZC
descriptor adapter**. Active GZC registers8B T32; R9 registersT32/64/128.
The T128 FFN cube2^21 is a geometry match, not a GPU-run or port acceptance.

At that illustrative cube, carried source-only GL savings are14,680,064
base products/97,517,568 adds+subs/256MiB logical shared reads. Full pair
saves44,040,192 products/347,078,656 adds+subs/608MiB but adds eleven fresh
Fp2 preweights/up to176 parameter bytes. No global/capacity savings.
Compiler elimination/registers/occupancy and exclusive phase fraction f are
unknown; even full phase deletion has ceiling1/(1-f). No50/s forecast.

Owner acceptance: supported k=11 literal/GL-only/full-pair native A/B under
shared build/heavy locks; compiler instructions, registers/spills and actual
eligible incidence; exclusive and enclosing clocks; masked round bytes/next
challenges/full receipt parity; independent verification of fresh full
receipts; strict-GPU/refusal/CS/H-1/current soundness and privacy gates.
Reject broader eligibility, absent compiler savings, any mismatch or enclosing
regression. Public weights alone do not discharge joint privacy obligations.
Researcher neither merges nor runs native/GPU work.

No new verified complete-stack proof/pass/token. All new proof clocks/rates
and startup fraction unmeasured; no prefill/resident/decode execution.
The private8B >=50/s target remains unachieved. Next local work moves to
actual fused NTT gather sector accounting unless owner measurements arrive.
