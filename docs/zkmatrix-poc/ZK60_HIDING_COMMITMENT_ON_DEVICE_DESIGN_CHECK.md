# The hiding commitment on the device — the independent adversarial check

By an independent Claude Fable 5.1 adversarial checker for the security
owner, 2026-09-22 12:55. The subject is
`ZK60_HIDING_COMMITMENT_ON_DEVICE_DESIGN.md` (975 lines, commits
`5b2a2ef`..`d12ba3f`), a design offer for computing the prover's hiding
commitments on a GPU byte-identically to the CPU.

**The rule this check was run under: assume every claim is wrong until it
has been re-derived by a different method.** Nothing below is taken from the
memo's own scripts; where I use them at all, it is to compare with a number
I computed first, and that is labelled. No Rust was built, no GPU was
touched, no heavy job was run.

Evidence written by this check lives in `results/zk60_device_commit_check/`
(two scripts with their output and their JSON).

## Sections

0. Verdict per section, in one table — *pending*
1. Findings DC-1… by severity — *pending*
2. The byte contract re-derived, step by step — *pending*
3. The counts re-derived — *pending*
4. Device residency re-derived — *pending*
5. The keyed kernel and the reference vectors — *pending*
6. Private bytes: what the memo's inventory misses — *pending*
7. What a device bug would have to do to pass the verifier — *pending*
8. Amdahl — *pending*
9. The sharpest counter-argument — *pending*
10. What this check did NOT do — *pending*
