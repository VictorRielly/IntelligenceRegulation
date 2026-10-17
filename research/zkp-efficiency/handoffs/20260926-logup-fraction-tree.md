# Fractional LogUp architecture — feasibility and negative-result handoff

Run `20260926T235233Z-5f465072`, cycle 0008. **Review only; no merge or native
patch is ready. No proving speed or privacy improvement is established.**

[Experiment and cost ledger](../experiments/logup-fraction-tree-20260926/README.md)
and [result](../experiments/logup-fraction-tree-20260926/result.json) retain the
independent oracles, source/log hashes and all controls. Exact fraction arithmetic
passes 150 cases, 100 lookup identities and 300 MLE checks; 15 controls pass.
The script is a local prototype, not a GKR proof or an upstream port.

Interface/patch location for a future owner design: shaped
`hashline/src/private_block/protocol.rs::{write_h,logup_sum_claim,prove_core}`,
the `HIds`/`Layout::for_shape` schedule and helper zero-checks in `argument.rs`.
The reference is `/tmp/zk60-groups-20260926`, pinned and copied under
`experiments/logup-fraction-tree-20260926/native-reference/grouped/`.
The prototype's `tree([(n,d)])` returns PRIVATE nodes; `link(leaves,q,theta)`
tests an ordered MLE value, without cryptographic binding. No Rust replacement
or new profile has been implemented.

The native H commitment costs 9.377/9.593 s in the latest dense 125M CPU logs,
23.3%/24.5% of known preparation+prove+serialization time. This is a large phase,
but saving it is hypothetical and adds GKR, binding and masking work. Gross
helper rows are 7,016 out of 7,120; new masking/PCS rows and net saving are
unknown. The globally padded tree would store almost 8 GiB before scratch,
versus 0.87 GiB of existing H input and 3.48 GiB of encoded H values. That
naïve memory schedule is unsuitable as an unexamined optimization.

Two decisive gates before promotion:

1. Do not serialize unmasked roots or subgroup sums. A one-value synthetic
   lookup is recovered exactly from `D/C` where C is the public table product.
   A new private construction must handle the whole joint verifier view,
   including internal messages and final leaf links. This is a counterexample
   to the naïve adaptation, not a reported vulnerability in native or upstream
   proof systems.
2. Preserve whole-public-table zero-denominator refusals even for multiplicity
   zero; pin all original leaves, multiplicities and padding to A. `(0,0)`
   satisfies a weak cross-product check; deleting matched witness/table leaves
   preserves root-zero. Ordered binding and nonzero constraints are essential.

Suggested architecture work, after an explicit design review: a private
fractional layer reduction with streamed node lifetimes, fixed public schema,
fresh masks and one joint opening per existing commitment. Derive all new
claim sites, degrees, blinding rows and refusal terms before pricing net rows.
Propose native builds, receipt tests and complete-readiness A/B under the
owner's shared locks; this research cycle launched none. Existing D12/D22 and
pending D19b/D23 rulings are untouched. Full 8B and decode results remain absent.
