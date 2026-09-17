# Integration status of the Fable 5.1 security review

Fable's [original proposal](../../results/zk60_mvp_20260915_evidence/fable_delivery/docs/zkmatrix-poc/ZK60_MVP_SECURITY_DECISION.md)
is retained unchanged with its source hashes and authoring-session limitations.
Read [Codex's disposition](ZK60_MVP_REVIEW.md) for accepted conclusions.

The zero-data IO preimage solver is integrated as a bounded diagnostic and
has been run on all four retained captures. Its fourteen focused tests pass;
two additional tests demonstrate why separate-channel evidence does not
automatically establish joint privacy. See `security_probe.json` and
`final_security_tests.log` in `results/zk60_mvp_20260915_evidence/`.

The proposed removal of the caller-fixed external-root requirement is rejected.
The proposed adaptive privacy argument is unproved. Both obligations remain
open, as do private attention and the complete private block. The diagnostic
does not authorize a protocol or privacy-scope change.
