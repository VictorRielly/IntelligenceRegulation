# MVP integration review — 2026-09-15

This disposition controls acceptance of the delegated work. A model's proposed
security argument is not an accepted theorem. P1 continues to hide input,
output and activations with independently fixed caller endpoints.

## Opus 5: component demo accepted after corrections

The new `scripts/zk60_p1_demo.py` builds the existing CPU example, registers
public weights before proving, selects fresh caller context, and independently
verifies the saved receipt against the separate endpoint policy. Six real
rejection controls pass. The receipt is **5,029,244 bytes** on the public
synthetic T32/d16/f16 fixture. Existing output is refused without changing
the saved artifacts. No protocol Rust was changed.

Codex's review reproduced two malformed-output failures: numeric zero was
accepted as a Boolean attestation, and an empty receipt caused an unrecorded
`IndexError`. Integration requires exact Boolean/integer types, a positive
receipt length, validated Cargo output and finite positive timeout limits.
CPU and build concurrency are bounded. All 37 focused orchestration tests pass.

The component's successful verification is not whole-proof privacy acceptance.
The current example uses public synthetic values and does not prove attention.

## Fable 5.1: retain bounded algebra, reject the scope reduction

The candidate tool adds a constructive zero-data preimage for each of the two
IO sumcheck channels at **fixed captured challenges**. It checks the captured
round messages, terminal difference, mask sum/evaluation and altered controls;
it also reuses the conditional endpoint sampler. This is useful bounded
evidence. It does not construct one consistent full proof view over all the
shared A/H/W/M/endpoint randomness.

The proposal to treat simulation for caller-fixed external roots as “not a P1
requirement” is **not accepted**. The public verifier takes those roots, and the
requirement is already explicit in the endpoint model and privacy contract.
Private fields and consuming Rust methods constrain the supported API. They do
not narrow the mathematical statement or adversary model. In particular, a
valid root prepared from a hidden input is not an invalid arbitrary string;
simulating fresh zero-input roots does not simulate a proof for that same
existing valid statement.

The proposed adaptive lift is also **not established by these checks**.
Sequential composition would need witness independence of each next-message
distribution **conditioned on the complete public past**, including commitment
roots, prior oracle answers, earlier messages and refusal history. Fixed-
coefficient marginal ranks and separate preimages do not supply that premise.

`tests/test_zk60_mvp_review_boundary.py` records a small counterexample to that
inference: publish `H(mask)` and `mask XOR witness`. Each marginal has the same
distribution for both candidate witnesses, with equal masked-message preimage
counts, but their joint view distinguishes them. This is a counterexample to
the inference, **not an attack on the actual FFN implementation**.

The integrated diagnostic states these limits explicitly. Codex also corrected
a source-inventory bug that counted `impl PreparedPlane` as a constructor and
made source-pin mismatches fail. Tests leave evidence generation to the
explicit CLI. The refusal snippets remain an inventory, not an
exhaustive refusal theorem or a proved exceptional-event bound.

The [original Fable delivery](ZK60_MVP_SECURITY_DECISION.md) is archived
unchanged; the integrated diagnostic and this disposition qualify its claims.

## Next acceptance gate

Keep the P1 private set and external-root obligation intact. The next security
delivery must construct the **joint conditional distribution** over actual
commitments, CFS messages, terminal masks and PCS openings, with shared
randomness and an explicit oracle history, or identify a necessary protocol
change that supports the same statement. It must cover both valid caller-fixed
statements and the specified preparation workflow; these cannot be silently
interchanged. A further standalone rank pass cannot close this gate.

Private attention's public oracle and operation inventory are available for
parallel design work. Its private lookup, norm/residual, score/softmax/PV and
seam implementation still requires a reviewed masking/composition construction.
The public block and the FFN demo do not fill those missing relations.

Run evidence is under `results/zk60_mvp_20260915_evidence/`; the
[MVP plan](ZK60_MVP_20260915.md) records current ownership and ordering.
