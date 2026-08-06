# Intelligence Regulation re-audit — 2026-07-14

## Decision

**No-go for GPU integration as the next project milestone.** The July 14 work
contains useful engineering progress: multi-wave execution removes the old
q31 instance cap, a lookup-based range pilot is dramatically cheaper than the
legacy q46 range path, verifier-side lookup prehash recomputation is present in
the main rigs, and the current tree builds. Those results are worth preserving.

They do not yet define a secure or compact proof system to accelerate. Four
issues are release-blocking:

1. the newly frozen ARP rejection parameter `t = 1.5` gives a non-negligible
   clipping region, contradicting the repository's own rejection-sampling ZK
   lemma, which proves its approximately `2^-100` guarantee at `t = 12`;
2. multi-wave pin claims reveal deterministic per-wave linear functionals of
   private activations, with no privacy proof or masking layer for those new
   public values;
3. the layer benchmark omits every `CtRoundProof` from its reported transcript
   bytes; under their current fixed-width representation, the two dominant
   proof arrays alone occupy about **2.86 GiB** at the measured `2^20` shape,
   before commitments and the rest of the proof;
4. the uncommitted U-S1 fresh-process verifier is only toy plumbing. It accepts
   its statement and commitment digest from the proof, disables the mask-pin
   checks that the repository's own attack battery shows are load-bearing,
   and carries no commitment-opening proof.

The current measured layer rig is also only a lookup/range/Hadamard fragment.
It does not prove the three FFN matrix multiplications, requantization,
residual connection, attention, normalization, or a caller-supplied model.

The practical decision is therefore:

- **No-go:** porting the current proof pipeline to a GPU, claiming negligible
  ZK for the legacy ARP chain, using the printed transcript size as proof size,
  or describing the rig as a transformer/FFN proof.
- **Conditional go:** continue isolated CPU/GPU arithmetic-kernel research
  behind a stable differential ABI, but do not let that work freeze the
  protocol or wire format. The protocol gates in
  [GPU_GO_NO_GO.md](GPU_GO_NO_GO.md) must close first.

## What improved since the previous audit

- The main U-K8 and U-R verifier paths recompute `h0_lkp` from the validated
  statement context and complete commitment list.
- The `c377d0d` Statement v2 repairs remain intact: rescale scale propagation,
  asymmetric signed capacity, canonical SiLU metadata, topology, coverage, and
  orientation validation are enforced.
- Production benchmark modes now obtain prover coins from `/dev/urandom`.
- `MaskSet` is consumed by value by `masked_gkr_prove`.
- Multi-wave commitment planning and claim localization pass adversarial
  consistency tests at the prototype shape.
- The one-instance masked lookup cost is substantially better amortized than
  the prior 1,020-element block rig.
- The exact `[0,256)` range-lookup pilot removes the legacy range plane/ARP
  cost at the local rig level and is the right architectural direction.
- The current checked-out and dirty source compiles across all Rust targets;
  focused Python protocol tests and the two principal committed batteries pass.

These improvements are real. The findings are about the security boundary and
what is actually counted or proved, not about the value of the prototype work.

## Findings at a glance

| ID | Severity | Finding | GPU gate |
|---|---|---|---|
| C-01 | Critical | `ARP_REJ_T = 1.5` does not establish negligible statistical ZK | Block legacy chain |
| C-02 | Critical | Per-wave partial claim scalars disclose new witness-dependent linear measurements | Block multi-wave protocol |
| C-03 | Critical | Reported proof bytes omit all ct-round proofs; dominant arrays are GiB-class | Redesign/aggregate first |
| C-04 | Critical | Dirty U-S1 proof/verifier is not a sound independent verification boundary | Do not merge as closure |
| H-01 | High | Move semantics/session nonce do not enforce mask freshness or prevent reconstruction | Harden prover API |
| H-02 | High | The exact-range pilot is not represented by the public Statement semantics | Statement v3 first |
| H-03 | High | “FFN-integrated/closed” overstates the implemented computation | Complete one FFN layer |
| H-04 | High | Canonical proof/statement parsing and repository-wide validated verification remain absent | Build before GPU API |
| H-05 | High | Measured latency is hundreds of seconds per million elements for only a subchain | Protocol redesign first |
| M-01 | Medium | Wave helpers panic on malformed inputs and mishandle generic Ajtai-bearing splits | Harden interfaces |
| M-02 | Medium | Freeze/docs lock in performance constants without locking the missing security invariants | Reframe freeze gates |

Full evidence is in [FINDINGS.md](FINDINGS.md), command results in
[TEST_EVIDENCE.md](TEST_EVIDENCE.md), and the ordered path forward in
[REMEDIATION_PLAN.md](REMEDIATION_PLAN.md).

## Scope and preservation

The audit compares baseline
`c377d0d6d9a72316681eb186b545d6d7d2868d23` with committed HEAD
`80ec1a16f7c4f16655d76390b2bba133357efae6` and also reviews the three
uncommitted U-S1 source edits present in the shared worktree.

No implementation, prior audit, patch residue, branch, or Git metadata was
modified. This directory is the only audit output.
