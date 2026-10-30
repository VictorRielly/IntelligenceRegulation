# Periodic public SC_TAB factors — owner review candidate

Run `20261028T215649Z-43c1f18d`, cycle 0128. No proving gain measured.

The [experiment](../experiments/periodic-sc-tab-20261028/README.md) passes
50,042 synthetic checks and a 64-check source/count audit. It replaces only
the representation of three publicly known, freshly challenge-encoded,
periodic U8/exp/act factors. Pinned canonical source is
`ops/zkp-mvp/trained-1b/hashline/src/private_block/argument.rs`, SC_TAB around
line 1967; exact nine-file hashes are in the experiment's native-pins.json.

Interface: `(full cube n, declared length 2^n, 256 fresh Fp2 rows)` ->
immutable indexed reads, MSB `bind(r)`, final scalar. First n-8 binds update
state only; remaining binds fold the suffix. All private/equality/support
tables stay dense and the full SC_TAB polynomial/cube/table order remains.
Verifier evaluates the short table at `rho[n-8..]` then retains **every**
`(1-e)` extension factor. Public targets are zero. Lifting public indices or
zero-extending the main cube gives a different relation and fails controls.

At R12 T128 the three public factors' initial logical payload falls
786,432 -> 12,288 B; public fold lerps 49,149 -> 765. The round cube,
98,298 public endpoint calls and generic round polynomial work remain.
Fresh exp/act arithmetic reduction overlaps the earlier tiling candidate;
do not add both savings. No native capacity, compiler, verifier or GPU clock
was measured. Conditional 32-block removed payload is cumulative, not peak.
Selected R13 LOW+h24/per-group tables and unregistered T512 are excluded.

The [Rust sketch](../experiments/periodic-sc-tab-20261028/candidate-periodic.rs)
is uncompiled and unapplied. Owner integration is moderate: new public Tab
variant and constructors; exact full-cube checks on both sides; builder/move,
heterogeneous ClosureRounds, census/capture, public verifier dispatch. Preserve
all six private terms, the exact six-plane pad list/powers and whole-table
inverse/zero checks. Do not broaden public eligibility to any private table.

The independent oracle uses original-cube sums, integer encoding and expanded
monomials over schoolbook Fp2; both implementations were authored locally.
Six synthetic slot fixtures n8/9/10 cover all rounds/terminals, arbitrary Fp2,
zero/one challenges and inconsistent synthetic private values. Descriptor-only
n13/14 checks do not constitute full T128 proofs. No native masks, transcript,
PCS, complete receipts or privacy evidence was produced. Native terminal
challenge 0/1 refusals were read in source, not executed by the model.

First owner action: exclusive fresh constructors, public folds, whole SC_TAB
and enclosing proof/workload clocks. Only if material, compile/integrate under
the current shared build/heavy locks, run every native masked-round/next-draw/
terminal/refusal/golden/receipt and current privacy gate, then independently
verified fixed-context resident 1/2/4/8 workloads with startup/drain charged.
Reject on mismatch, negligible affected share or enclosing regression.
Unknown phase fraction f prevents a numeric end-to-end forecast; even free
deletion cannot exceed 1/(1-f). No private 8B >=50-token/s claim follows.

Sources searched include [current Efficient Sumcheck](https://github.com/compsec-epfl/efficient-sumcheck),
[2026 sumcheck work](https://eprint.iacr.org/2026/587),
[SP1 release](https://github.com/succinctlabs/sp1/releases/tag/v6.10.0) and
[original CMT paper](https://arxiv.org/html/1105.2003v5).
Exact access/date/license/commit/blocker qualifications are retained.
No foreign code executed, heavy job queued or production file changed.
