# Reviewed snapshot

## Git state

```text
branch: perf/zk-batch-optimizations
HEAD:   80ec1a16f7c4f16655d76390b2bba133357efae6
base:   c377d0d6d9a72316681eb186b545d6d7d2868d23
remote: origin/perf/zk-batch-optimizations at the same HEAD
```

Committed commits reviewed after the prior GPU-readiness baseline:

```text
e6727e4 ARP rejection: log M parameterized by alpha
92ca018 ARP joint rejection (Q4.2b) across 4 coupled units
7b2a57c multi-wave claim splitting
fa634ae one per-layer multi-wave chain rig
0434a0e second range-table instance
43b2851 range measurements
4713fa1 U-R documentation/freeze close
80ec1a1 U-S security-boundary ledger
```

The range also includes the related measurement and documentation commits
listed by `git log c377d0d..HEAD`.

## Pre-existing worktree state

At audit start, these implementation files were already modified:

```text
M zkmatrix-rs/src/bin/ring_matmul.rs
M zkmatrix-rs/src/ring/gkr_masked.rs
M zkmatrix-rs/src/ring/mod.rs
```

They comprise an interrupted U-S1 tranche: OS-session nonce plumbing,
move-by-value masks, a minimal masked-descent byte dump/parser, a child-process
verifier mode, and attack/freshness batteries. The live diff was approximately
726 insertions and 125 deletions when captured. It changed slightly while the
audit was running; all final observations use the hashes below and the source
that rebuilt successfully immediately before documentation.

Pre-existing untracked material was preserved:

```text
codex-audit-2026-07-09/
codex-audit-2026-07-10/
codex-audit-2026-07-12/
uk9-residue-2026-07-12.patch
```

## Final reviewed source hashes

```text
e711477a12d8dd2445a0a7b59f35b4bb28a3029ecfc94b112c788b4ca4c44fdb  zkmatrix-rs/src/bin/ring_matmul.rs
1ac08dc80f5da68d6f4220bbf3c7ac8c76491a096f49465ce285f763e323ec76  zkmatrix-rs/src/ring/gkr_masked.rs
be9574f473471f9c9deddf762f4e6a538e08e8ce48d537b60a3381724c94558e  zkmatrix-rs/src/ring/mod.rs
85da0e2b3965bbde3f7019dbeb8e8e55710af421c36009251b999f6199c9e0dd  zkmatrix-rs/src/ring/ct_engine.rs
6644d7395ebafbd554e7a9e8127cdbb86d2fb460d0845e62c6ac1feefa99bffc  zkmatrix-rs/src/manifest.rs
449b553a8c0c26342dc3c3abf9beada9fdb7d4777bf59615c29ead6f6400f38f  docs/zkmatrix-poc/TARGET_CONTRACT.md
```

## Scope boundaries

This was a source-and-executable security/readiness review, not a formal proof
or independent cryptographic certification. It covered:

- rejection sampling and ARP parameterization;
- multi-wave linear/quadratic claim composition;
- lookup masking, freshness, and verifier pinning;
- exact range-table integration and Statement semantics;
- proof artifact/serialization readiness;
- measured performance, memory, and proof-size accounting;
- the implemented relationship to an FFN/transformer forward pass; and
- regression/adversarial batteries available in the repository.

No GPU exists in the repository, so GPU readiness was assessed from the CPU
reference semantics, data movement, artifact size, and protocol stability—not
from hypothetical speedup multipliers.
