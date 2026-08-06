# Errors found during review and fixes verified

Fable was actively editing the Route R R1 tranche during this audit. I did not
modify those files. The following issues were found, communicated through the
shared worktree context, and then fixed by Fable before the review ended.

## 1. F5 C2 abort after R1 bundle expansion

Initial error: the new F5 randomized-claim case grew from a small g bundle to
the reveal slots plus three R1 pads per claim, but still called
`derive_ct_round_params(..., conc=false)`. At q31 the worst-case chain rejected
the enlarged standard bundle before the test could exercise the attack.

Live fix: use the engine's concentration/restart discipline for this enlarged
case and document why. The deliberate old attack continues to accept; the
theta-randomized construction rejects.

Verification: the final direct self-test passed this pair.

## 2. Chain demo C2 abort after R1 pads

Initial error: the toy shape derived `msg_r=1`. Each quadratic pad therefore
cost a full g commitment. The R1 wave expanded beyond q31's C2 standard-bundle
capacity.

Live fix: derive at least `msg_r=2` for this demo and increase `N_r` with the
message-width bump. This packs two pad slots per commitment. Fable also added a
freeze-check row pinning the R1 pad-count formula.

Verification on the final direct-test snapshot:

```text
commit 0.01s | prove 0.46s (wave of 54 claims) | verify 0.07s
chain-demo passed
```

This is a valid toy-demo repair. A production implementation still needs a
general claim-wave/packing derivation rather than a local minimum width.

## 3. Missing R1 leak and ordering regression

Initial error: `ct_round_challenge` was exposed but unused, while Q4 specified
a both-direction hash-order regression.

Live fix: add `self_test_r1` with two attack/fix pairs:

- zero pads expose the checked linear witness image; random pads mask it;
- a pad commitment omitted from h0 can be shifted after the challenge to make a
  false claim accept; binding it in h0 makes the same transcript reject.

Verification: all seven new R1 assertions passed in the final 31.86s direct
self-test.

Limitation: the “masked value != unmasked value” assertion is a useful
regression, not a statistical proof of uniformity or a substitute for reviewing
the simulator across all claim families.

## 4. Freeze-check coverage

Initial error: freeze-check passed while both integration tests aborted because
it did not cover R1 pad-slot expansion.

Live fix: add a row pinning `3/quad-ct`, `2/quad-ring`, and
`3/twisted-quad` pad counts. This prevents silently dropping R1 pads.

Still recommended: pin representative **total commitment counts and C2/C3/C4
headroom** for complete production waves. A pad-count formula alone does not
guarantee that a caller selected a feasible packing.

## 5. Corrected committed-executions cost in code

The worktree correctly notes that the CE round had no existing g commitment for
R1 pads. It therefore adds a tenth wide object and its response/opening. At the
toy CE shape, the code's cost breakdown implies about 116KB incremental for
that object, rather than the stale documentation's approximately 1.5KB.

Remaining action: update `Q4_LEMMAS.md`, `SOUNDNESS_REFERENCE.md`,
`AUTOMORPHISM_GATE_DESIGN.md`, and every LLM cost model; then benchmark R1 at
production shapes.

## Final test state observed

- Intermediate repaired worktree: all 42 repository tests passed in 134.382s.
- Final R1-battery snapshot: Route R self-test passed in 31.86s.
- Final R1-battery snapshot: chain demo passed.
- Algebra, activation, parameter, release build, and cargo compilation checks
  passed as recorded in [TEST_EVIDENCE.md](TEST_EVIDENCE.md).

