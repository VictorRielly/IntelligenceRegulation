# Salted Merkle fusion — review candidate, parked for native clocks

Run `20261026T172925Z-dd337876`, 2026-10-26T17:41:18.145236+00:00. No native proving speedup measured.

Interface and location: add `MerkleTree::build_salted_keyed(&[Digest], &[Digest],
Option<&Digest>, Option<&Digest>) -> MerkleTree` in active GPU lane core merkle.rs;
replace the salting/build pair in core pcs.rs::commit_zk_owned_with_tag. Patch:
`../experiments/commitment-salted-merkle-20261026/salt-first-parent.patch`.
It is unapplied/uncompiled. Python model is not a Rust/CUDA implementation.

Validation: 19,952 checks,120 synthetic cases/all3825paths/17 controls against
installed independent blake3; separate interval/source/cost audit16,733
checks/12 pins/5 controls. One core;Model 1.197346s / 16,240KiB RSS; audit 0.025621s / 16,164KiB RSS.
Model uses64-byte message flags, never internal PARENT. Correct role keys and all
stored leaves/levels/path bytes are mandatory. Native RNG schedule is untouched
in the patch, but no native byte/refusal/privacy equivalence has been established.

Counted benefit:2 MiB(T128) or4 MiB(T512) logical reloads per frozenR9 A/Hcommit;
no hashes or retained bytes removed. No LOW/HIGH profile count or peak/rate claim.
Added paired-task/dependency/compiler/cache costs can exceed saving. Initialized
output buffers lose; candidate uses indexed-unzip and zero-copy array flattening
as established in pinned local library source (Rust>=1.80); actual codegen untested.
GPU full-tree offload is a transfer negative with current host paths; root-only
hash timing omits opening obligations. No privacy/mask reuse is authorized.

Before promotion: native leaf/node/all-path byte parity for keyed+legacy tags,
one-leaf/boundary cases, wrong-role/flag/path controls, same RNG/tamper/refusal,
full receipts+fresh independent verification and current profile privacy gates.
Review panic/allocation/failure behavior, inspect no extra clears/copies/reloads,
and measure instrumentation-off/on plus exclusive hash/D2H/salt/firstlevel/upper/
paths and enclosing complete verified workload under shared build/heavy locks.
If f is unknown removable time fraction, no numeric speed forecast is justified;
even free deletion <=1/(1-f). Falsify on parity/privacy drift or enclosing regression.

Priority: park until native clocks show useful incidence. Preserve higher-priority
whole-prover GPU,DDcontext and FZC accounting work. Main/Claude reviews/integrates;
this research lane does not merge. See the experiment README and dated report.
