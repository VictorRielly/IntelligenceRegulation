# Privacy requirements — PoC and full version

Authority: Victor's existing project direction, explicitly reaffirmed on
2026-09-09. This is a prominent restatement, not a newly chosen privacy scope.
The same P1/P3 private sets already appeared in
[ZK60_EXECUTION.md](ZK60_EXECUTION.md#acceptance-target-and-current-limits)
at commit `24ae746` (2026-09-04) and `ZkPrivacy` at `b026b04` (2026-09-04).

| Value class | First proof of concept (P1) | Full version (P3) |
|---|---|---|
| Inputs | Hidden | Hidden |
| Outputs | Hidden | Hidden |
| Intermediate activations/values | Hidden | Hidden |
| Model weights | May be public; hiding is not required for this milestone | Hidden |

"Hidden" means protected from the proof verifier and public proof/receipt
artifacts. The authorized input/output owner can know its own values. Public
commitment roots are handles for hidden values; publishing a root does not
authorize publishing the corresponding raw input, output or activation.

The immediate path is P1 with private input/output binding and private
intermediate computation. P3 adds weight privacy for the full version. Existing
P3 experiments and reviews can be retained, but weight-specific work must not
unnecessarily delay the P1 PoC. Shared privacy and soundness defects still need
to be fixed in P1.

Public-input/output proofs, public-only block demos and public synthetic
fixtures can serve as diagnostics. They do not satisfy the PoC privacy target.
An unresolved simulator, commitment or composition argument is work to resolve;
it is not permission to shrink the private set or reopen this decision.
A change to these requirements needs an explicit new user instruction.

Acceptance requires privacy across the complete verifier view, including
sumcheck messages, openings, endpoint binding and repeated-proof behavior.
Passing verification, finite rank tests or conditional channel checks alone
does not establish whole-proof zero knowledge. The full version also needs
authenticated private-model identity; a fresh private weight root alone does
not prove use of a previously approved model.

Implementation status and evidence belong in [ZK60_STATUS.md](ZK60_STATUS.md).
These requirements are not a claim that the current prototype has met them.
