# Prioritized remediation plan

The ordering is intentional. It resolves transcript semantics and asymptotic
artifact size before investing in an integrated GPU backend.

## Phase 0 — Preserve and relabel the current state

1. Commit or archive the current U-R work separately from the dirty U-S1
   experiment.
2. Do not merge U-S1 under a “security boundary closed” message. Label it
   `toy masked-descent serialization harness` until the full pins/openings are
   present.
3. Rename the U-R milestone from “FFN-integrated/closed” to “committed
   activation-chain rig.”
4. Mark the printed masked-transcript number as a component subtotal, never
   proof size.

Exit: a reproducible clean branch whose documentation distinguishes tested
prototype components from security/product exits.

## Phase 1 — Decide the range architecture and repair ZK claims

Preferred route:

1. Remove legacy ARP from the target FFN path.
2. Lift the exact `[0,256)` range lookup into the typed public statement.
3. Cover all committed coordinates/padding under an explicit encoding rule.
4. Bind its table/encoding/quantization spec into model identity and every
   relevant transcript prehash.

If ARP is retained for any supported path:

1. Set a stated statistical target (for example, 128 bits).
2. Derive `t` and `log M` from that target; do not freeze `t = 1.5` as secure.
3. Enforce the actual center-norm precondition used by the rejection lemma.
4. Replace floating-point probability decisions and modulo-biased sampling
   with an audited discrete-Gaussian/rejection implementation.
5. Add known-answer/statistical tests and an independent proof review.

Exit: every supported range path has an exact relation or a negligible,
parameter-derived statistical distance with executable preconditions.

## Phase 2 — Redesign multi-wave privacy

1. Enumerate every value newly visible in the multi-wave transcript: pin
   partials, zeta partials, per-wave seeds, commitments, and openings.
2. Write a simulator for the entire composed transcript, not one ct-round in
   isolation.
3. Replace deterministic partition sums with one of:

   - committed random additive shares with a proof that pads cancel;
   - a tree/accumulator proof of a global linear claim; or
   - an aggregation scheme that verifies wave-local openings without exposing
     their right-hand sides.

4. Add a rank/recovery test that attempts to infer activation chunks from all
   honest wave transcripts and compares leakage with the original total claim.
5. Have an independent cryptographer review Fiat–Shamir composition and abort
   behavior across waves.

Exit: a documented simulator and adversarial privacy suite cover every public
multi-wave value.

## Phase 3 — Solve proof-size asymptotics

Before implementing a production serializer, prototype alternatives that do
not emit one `n_r x D` response and one `kappa x D` mask image per commitment
per wave. Candidate work should be selected by proof-size and verifier-cost
models, not prover time alone.

1. Define a byte ledger for every current proof component.
2. Evaluate batched/aggregated commitment openings across all commitments and
   waves.
3. Require an analytic <=256 KiB path at the complete FFN-layer/pass scale
   before optimizing it.
4. Implement canonical encoding and measure the actual artifact file.
5. Keep a hard test that fails when the complete artifact exceeds its budget.

Exit: the complete intended proof—not a masked-descent subtotal—meets the byte
and verifier budgets with a reviewed soundness reduction.

## Phase 4 — Extend the corrected Statement v2 into the only protocol boundary

Preserve the validator repairs already landed in `c377d0d` (scale
propagation, asymmetric signed capacity, canonical SiLU metadata, topology,
coverage, and orientation checks), then extend them rather than replacing
them:

1. Introduce typed raw encoding, scale exponent, signed asymmetric bounds,
   padding policy, and table instances.
2. Represent affine range coding explicitly (`signed x` to `x + 128`).
3. Support multiple typed lookup tables with exact digest and quantization
   equality.
4. Validate topology, roles, orientations, modulus capacity, outputs, and all
   producer/consumer edges.
5. Disable bare `ClaimManifest::digest()` outside explicit migration tests.
6. Port ring, lattice, structured, inventory, and chain paths to the same
   validated Statement type.

Exit: no prover or verifier can obtain a transcript context from an invalid or
untyped manifest.

## Phase 5 — Implement the actual independent proof boundary

Define separate types:

```text
PublicStatement
ProverInput
Proof
VerificationError
VerifiedSetup
```

Then:

1. Encode version, total length, component lengths, and canonical field/signed
   representations.
2. Supply the expected `PublicStatement` separately from `Proof`; never parse
   the proposition solely from prover-controlled proof bytes.
3. Recompute all commitment digests and transcript seeds.
4. Check every data, mask, blinder, and abort-related commitment opening.
5. Reject trailing bytes, duplicate/reordered sections, noncanonical fields,
   oversized allocation requests, and unknown versions.
6. Replace panics/asserts on verifier-reachable data with typed errors.
7. Run verification in a new process with only setup, statement bytes, and
   proof bytes.
8. Fuzz, truncate, and mutate every section; port E3Z-N1 and all existing
   tamper legs to this API.

Exit: an arbitrary byte-producing adversary cannot access monolithic
prover-local state, and the complete adversarial suite rejects cleanly.

## Phase 6 — Harden entropy and session handling

1. Gate deterministic RNG and mask deep-copy helpers behind `cfg(test)` or a
   separate harness feature/crate.
2. Use a production RNG/session type that cannot be cloned, serialized, or
   carried silently across fork.
3. Remove the large userspace buffer around `/dev/urandom`, or detect PID
   changes and reseed before every post-fork draw.
4. Bind a public nonce before commitments if the protocol relies on verifier-
   observable uniqueness. Otherwise describe it only as internal diagnostic
   metadata.
5. Zeroize secret mask/blinder material after proof construction and document
   failure behavior if the OS RNG fails.

Exit: deterministic/reused secret coins are unavailable in production builds,
and the claimed freshness property matches what the verifier/API can enforce.

## Phase 7 — Prove one complete FFN layer

Accept caller-supplied model/input data and prove, under one statement:

```text
gate = requantize(W_gate * input)
up   = requantize(W_up   * input)
act  = SiLU(gate)
mix  = act .* up
down = requantize(W_down * mix)
out  = input + down       (when the architecture specifies the residual)
```

Bind all weights, quantization/table specs, input commitment, and public output.
Use the canonical proof boundary and measure real proof bytes, p50/p95 prove,
verify, RSS, and work relative to the native feedforward.

Exit: a fresh verifier proves one complete FFN layer—not an inventory and not
an activation-only rig.

## Phase 8 — GPU integration

Only after Phases 1–7:

1. Freeze the CPU arithmetic/transcript ABI with exact bounds and known-answer
   vectors.
2. Port one kernel at a time (field/NTT, commitments, aggregated openings).
3. Differential-test scalar CPU, optimized CPU, and GPU outputs at boundaries
   and random shapes.
4. Include host/device transfers, allocation, transcript hashing, proof
   encoding, and witness inference in p50/p95.
5. Report a named GPU, driver/toolkit, clock/power settings, warm/cold runs,
   peak host/device memory, and proof bytes.
6. Re-run the complete serialized adversarial suite against GPU-produced
   proofs.

Exit: measured acceleration of the same secure complete proof, not a projected
multiplier on a different benchmark.
