# Fable re-audit — 2026-07-12

## Decision

**Do not make the GPU proof backend the next integration milestone.** The new
work is meaningful research progress, and the recoverable U-K9 kernel commit is
worth preserving, but the repository still does not implement a secure,
independently verifiable proof of an FFN feedforward. Two newly claimed closures
are not valid as implemented:

1. the lookup masks and blinders are reproducible from public/fixed seeds, so
   the concrete implementation does not provide the claimed lookup ZK; and
2. the U-K8 verifier trusts the prover-side `h0_lkp` instead of recomputing it
   from the statement and commitments, reopening the exact pre-challenge
   binding class that the negative battery demonstrates is exploitable.

There is also a statement-semantics defect: a proved range narrowing disables
the validator's fixed-point scale check, and signed-width capacity treats the
unrepresentable positive endpoint as representable. The generated 32-layer
inventory relies on the first behavior.

The honest engineering conclusion is:

- **No-go:** claiming secure ZK, target-scale U-K8 closure, a complete FFN
  proof, or a credible 5-second GPU path.
- **Conditional go:** preserve and review the clean U-K9 CPU kernel commit as
  an isolated arithmetic optimization. It passed its tests and delivered a
  real roughly 1.9–2.0x speedup plus roughly 2.35x lower RSS in my same-machine
  runs. It has not been merged with U-K8, and its post-commit worktree residue
  does not compile.

## What Fable genuinely improved

- A versioned statement wrapper now performs many useful structural checks.
- The q31/q46 range link rejects the tested `+256` wraparound witness.
- The masked GKR algebra, aggregate pin interface, slot-packed `Y` consumer,
  and adversarial batteries are substantial prototype advances.
- U-K8 composes range, lookup, and Hadamard checks at a 1,020-element block.
- The clean U-K9 commit is bit-identical to the scalar oracle on its battery and
  materially improves the unmasked lookup-core benchmark.
- Both clean snapshots pass the repository's complete 42-test suite.

Those are good results. They do not overcome the concrete randomness,
verifier-boundary, statement-semantics, proof-size, or target-scale problems.

## Scope

This audit covers all recoverable Fable work, not only the checked-out branch:

- checked-out U-K8 HEAD `8a206aec09f15f8eb203354eeaa02c15258abe68`;
- its two live documentation edits;
- clean U-K9 commit `e8fa7772d445e1d8a05a558a9f28f325d7e3bd5a`;
- the 32-line interrupted U-K9 worktree edit after that commit; and
- deterministic-test commit `4d9d0d2076c1033221b312d7ddf5a33cde3c1c05`.

No Fable source, branch, worktree, or documentation was modified by this audit.
Only this new audit directory was added.

## Findings at a glance

| ID | Severity | Finding | GPU gate |
|---|---|---|---|
| C-01 | Critical | Lookup masks/blinders are publicly reproducible; freshness is only an in-memory flag | Block |
| C-02 | Critical | U-K8 verifier does not recompute `h0_lkp` from commitments | Block |
| C-03 | Critical | Statement v2 accepts inconsistent fixed-point scales and signed endpoint overflow | Block |
| H-01 | High | “U-K8 closed at row-block granularity” does not satisfy its full-tensor exit | Block headline work |
| H-02 | High | U-K8 proves no gate/up/down matmul and accepts no caller/model input | Block product claim |
| H-03 | High | Statement v2 is not the repository-wide verifier boundary; model identity is a placeholder | Block security claim |
| H-04 | High | U-K9 is unmerged; clean commit is partial and live continuation fails to build | Block integration |
| H-05 | High | Current block economics miss proof-size and latency budgets by orders of magnitude | Redesign first |
| M-01 | Medium | U-K9 arithmetic coverage omits boundary/overflow and portable-kernel cases | Add before GPU port |
| M-02 | Medium | Documentation and branch state are internally inconsistent and not backed up remotely | Reconcile/preserve |

Full evidence and fixes are in [FINDINGS.md](FINDINGS.md),
[TEST_EVIDENCE.md](TEST_EVIDENCE.md), and
[REMEDIATION_PLAN.md](REMEDIATION_PLAN.md). The direct regression comparison is
in [PRIOR_FINDINGS_STATUS.md](PRIOR_FINDINGS_STATUS.md).
