# Security review

## Security claim that is supportable today

The safe description is:

> A collection of research prototypes and executable checks for committed
> matrix-multiplication and small quantized-computation proofs, including a
> custom ring/lattice route under explicitly modeled assumptions. Not audited,
> not production-safe, and not currently a complete zero-knowledge transformer
> proof.

Anything stronger needs the gates below.

## Track-by-track assessment

### Python zkMatrix

The Python code is valuable for understanding reductions and transcript flow.
Its `ToyAdditiveGroup` explicitly is not a cryptographically binding group. The
safe-prime group backends are slow reference models, not hardened libraries.
This track should never be selected from a user-controlled backend string in a
security product without eliminating the toy option at compile/deployment time.

### Structured BLS12-381 track

Using `blstrs` gives real curve arithmetic, but the security boundary is much
larger than curve selection:

- the structured SRS has `O(n^2)` material;
- demos know the trapdoor;
- no ceremony/import/validation lifecycle exists;
- proofs are not serialized or parsed;
- the implementation is a monolithic benchmark binary;
- the exact deviations from the zkMatrix paper require independent review.

This is a benchmark/research track until setup and verification are productized.

### Route Z

The Python reference uses OS entropy and higher-precision rejection arithmetic,
which is materially better than Route R's current sampler. The native Route Z
implementation demonstrates the fullest computation chain. Its performance is
far outside the goal, and its bespoke protocol/reduction still needs external
review. It remains a useful correctness oracle and conservative comparison.

### Route R

Route R contains creative and potentially valuable engineering, but also the
highest research risk:

- it is a new custom protocol rather than an implementation of a widely
  reviewed complete proof system;
- its quadratic layer had a concrete witness leak;
- R1 changes transcript contents, capacity, proof cost, and simulation;
- slot packing introduces a concrete composition attack unless extra links are
  built;
- exact-integer range/non-wrap conditions are incomplete;
- concentration and estimator constants are models;
- custom SHA-256 counter expansion and transcript code have no external
  conformance target;
- the performance implementation's secrets are deterministically generated.

Route R should have a written cryptographic specification independent of code,
followed by external review, before its speed is treated as a product path.

## R1 review notes

The high-level pad idea addresses the documented leak in the expected way:
fresh pre-challenge uniform pads mask the garbage images, and verifier equations
subtract commitment openings. The algebra harness confirms completeness for
the checked identities.

That does not by itself establish ZK. The following must be reviewed together:

1. Joint distribution of pads, commitments, responses, and all masked images.
2. Simulator for every quadratic family and batches sharing commitment groups.
3. Rejection distribution after adding pad commitments to the joint response
   bundle.
4. Fiat-Shamir programming and all commit-before-challenge dependencies.
5. Extraction with pads present and challenges in the quotient ring.
6. Abort/salt behavior and maliciously chosen statements.
7. Reuse rules: pads, randomness, and CRS rows must never repeat across proofs.
8. Capacity derivation at production batch shapes.

The live worktree now contains the load-bearing order-regression pair and a
zero-pad versus random-pad leak pair. Keep them, extend them to every quadratic
family, and do not treat a one-sample inequality check as a statistical ZK
test or a replacement for the simulator proof.

## Parameter review

Positive evidence:

- q and CRT/irreducibility identities are checked by scripts and differential
  tests.
- The LS18 short-invertible-element condition is consistent with the cited
  corollary at the frozen q31/k=8 point, albeit with only about 1.30x norm
  margin.
- Independent core-SVP and shimmed lattice-estimator runs broadly agree on the
  chosen generic instances.

Limitations:

- the stated target is 128-bit classical, not 128-bit quantum;
- several quantum estimates fall below 128 bits;
- native Sage reproduction remains outstanding;
- generic estimates do not replace analysis of module/ring structure,
  multi-target use, Fiat-Shamir loss, and the complete protocol reduction;
- C4 uses a pre-rounded dimension while deployment uses integral `kappa`; the
  repository documents this bookkeeping mismatch;
- a 1.3 empirical concentration factor is security-critical and needs a proof
  with explicit failure probability, not just sampled evidence.

## Implementation-security blockers

Before any real witness is processed:

- replace SplitMix64 with a reviewed CSPRNG seeded by the OS;
- replace floating-point secret sampling and rejection decisions;
- remove secret-dependent branches/table access where relevant;
- zeroize secrets and prevent accidental debug/log output;
- define domain separation and transcript encoding as a stable specification;
- version proofs and reject cross-version transcripts;
- use bounded allocation and checked arithmetic for untrusted proofs;
- eliminate verifier panics/aborts;
- fuzz parsers and verification with malformed/adversarial inputs;
- add dependency and supply-chain policy;
- document side-channel and fault assumptions;
- define safe key/SRS/CRS generation and storage.

## Security release gates

| Gate | Minimum evidence |
|---|---|
| ZK-R1 | Full R1 spec, both-direction order regression, leak non-recovery tests, simulator/extractor review, all tests green |
| Composition | E1/E2 implemented; adversarial junk-coordinate proof rejected; Hadamard tied into a real chain |
| Integer semantics | Every model input/weight/intermediate range proven; no-wrap theorem and malicious wrap tests |
| Statement binding | Canonical model/quantization/operation schema; generic verifier validates shape and complete DAG |
| Parameters | Native estimator reproduction, explicit classical/quantum target, algebraic attack review, conservative margin |
| Implementation | CSPRNG/constant-time sampler, serialization, fuzzing, no verifier panics, side-channel review |
| External | Independent cryptographic audit and remediation before real secrets or public reliance |
