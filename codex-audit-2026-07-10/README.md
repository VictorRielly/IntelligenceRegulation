# Follow-up audit: pre-GPU readiness review

Audit date: 2026-07-10  
Audited commit: `444f05792e35b3de2980ddc9ebac74def6d1f2f9`  
Branch: `perf/zk-batch-optimizations`  
Prior audit baseline: `9fea0a5620679aa484dce3edaff9deae65b0def8`

This folder is an independent follow-up to `codex-audit-2026-07-09`.
It reviews the 19 commits and approximately 8,450 added lines since that
baseline, with special attention to whether GPU implementation is now the
right next milestone. No implementation file was changed by this audit.

## Decision

**Do not make full GPU integration the next product milestone.** A narrow,
clearly labeled GPU experiment for the stable A1 commitment kernel is
reasonable, but the proof stack is not ready for a latency or security claim.

The two most important findings from the prior audit have been materially
addressed:

- R1 masking is committed, applied to all three quadratic claim families, and
  covered by attack/fix regressions.
- E2 slot-constancy enforcement is implemented and rejects the exact
  junk-coordinate attack previously identified.

The main blocker has moved. The new LogUp-GKR activation engine is explicitly
**not zero knowledge in its current Rust form**. Its own design and executable
spike show that one unmasked transcript reveals the activation multiplicity
histogram. The proposed masking scheme is a promising design and toy spike,
but U-K5a through U-K5e have not been implemented.

The new lookup benchmark also does not meet its own U-K8 exit criteria. It
times an uncommitted, unmasked, single-threaded algebra pipeline and omits the
E4 commitment proof, upstream range proof, downstream `gate o up` use, and an
actual FFN tensor. Its reported 22-thread and GPU rows are projections, not
measurements. In addition, the same “GPU 20x” label is applied from two
different baselines in the commitment and lookup code.

## Recommended sequencing

1. Implement and review the masked lookup protocol, including the full
   U-K5 negative battery and mask-reuse rejection.
2. Complete the original U-K6/U-K8 exit criteria: committed tensor, E4 proof,
   upstream range, downstream Hadamard, and a real FFN-shaped run.
3. Close the q31 integer/non-wrap and model-statement gaps for that chain.
4. Replace the generic speedup factors with per-kernel measured baselines and
   resolve the two pass-element inventories that still differ by 1.4x.
5. Refactor the lookup representation for bounded memory and GPU-compatible
   contiguous buffers.
6. Then integrate GPU backends, starting with the commitment kernel and using
   the CPU path as a bit-exact oracle.

## Contents

- [FINDINGS.md](FINDINGS.md) — prioritized technical and security findings.
- [PRIOR_FINDINGS_STATUS.md](PRIOR_FINDINGS_STATUS.md) — what Fable fixed and
  what remains open from the first audit.
- [GPU_READINESS.md](GPU_READINESS.md) — go/no-go decision and gated GPU plan.
- [REMEDIATION_PLAN.md](REMEDIATION_PLAN.md) — concrete protocol, code, and
  benchmark exit criteria.
- [TEST_EVIDENCE.md](TEST_EVIDENCE.md) — commands and reproduced results.
- [SUGGESTED_FIXES.md](SUGGESTED_FIXES.md) — code-level changes recommended
  before and during GPU work.
- [SNAPSHOT.md](SNAPSHOT.md) — exact review boundary and file hashes.
- [REFERENCES.md](REFERENCES.md) — repository evidence and primary sources.

## Safe claim today

The repository is a strong research prototype containing a masked Route R
quadratic layer, a slot-constancy repair, a CPU commitment-stream measurement,
and an unmasked LogUp-GKR activation prototype with a designed-but-unbuilt ZK
variant. It is not yet a secure zero-knowledge proof of an 8B transformer
forward pass, and it does not yet demonstrate a five-second prover.
