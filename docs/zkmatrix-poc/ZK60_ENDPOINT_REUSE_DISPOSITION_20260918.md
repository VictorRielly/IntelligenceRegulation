# Endpoint reuse: native reproduction and review disposition

The existing endpoint's terminal masks must not be reused across ordinary
openings. **Two native PCS openings at the actual seven-row, 256-column
endpoint geometry recover all 512 data words**, using only the two public
group vectors and their public challenge coefficients. The fresh-owner
control does not recover the plane. Both openings separately pass the native
PCS verifier, and corrupted vectors fail. The tests do not weaken or bypass
verification; they deliberately bypass the higher-level consuming owner.

This is a test-only reproduction of Claude Fable 5.1's algebraic finding.
Original memo, model and 25 Python tests are archived unchanged under
`results/zk60_loop_20260918/reviews/fable_reuse/`, with delivery hashes.
They are not normative protocol definitions or accepted privacy theorems.

For each coordinate pair, an opening publishes
`v = a*x + b*y + c*m` over the quadratic extension field, where `x,y` are
base-field data and `m` is the fixed complex terminal mask. Two openings
cancel `m`; the remaining complex equation is two base-field equations in
`x,y`. The tested public coefficient matrix is invertible. The recovery
function does not read masks, pads, salts, paths or the fixture RNG seed.

Run the native regression:

```
cargo test --release --offline --manifest-path zkp-core/Cargo.toml --test endpoint_reuse
```

Two tests passed in the integration run. The core implementation is the
same one reexported by hashline's PCS adapter. Claim geometry matches
`zk_ffn_fresh_io::claim(0, 2, ...)`, but this is **not** a reproduction of
two complete FFN receipts through the consuming endpoint API. That API
already refuses reuse by consuming its owner; no production code changed.

The one-use lifecycle does **not** close the outstanding caller-fixed-root
privacy argument. Fable's statement that prior history is either empty or
a spent owner is too strong. An ordinary authentication path or an existing
public root-child hash query can precede the sole accepted `finish`.
The new stateful simulator represents histories as complete accepted
openings, and sets the use count from that list. It cannot represent all
allowed auxiliary history. The earlier
[prior-path distinguisher](ZK60_JOINT_VIEW_REVIEW_20260918.md) therefore remains
applicable to the claimed general construction.

Neither finitely many rank calculations nor counting additional equations
establishes the universal independent-rank and composition premises of a
new budgeted scheme. The review also found an exceptional forced-challenge
counterexample to proposed A4: both uses pass their individual proximity-pair
checks while sharing identical mask coefficients. Their data coefficients
differ by `(1,U)`, so subtracting the proximity vectors reveals both data
coordinates. A4's assertion for every non-refused challenge is false as
written. This is not an efficient attack on random Fiat–Shamir challenges;
a repaired argument needs a joint-rank refusal or a justified bound on the
bad-challenge event. See `tests/test_zk60_budgeted_endpoint_boundary.py`.
The archived two-use redesign and stateful simulator
remain research proposals. Do not adopt a new history restriction or mark
whole-proof privacy complete from this delivery.

The separately versioned zkVM experiment instead keeps endpoint openings
inside the proof witness and publishes only salted SHA-256 handles and the
outer Groth16 proof. Its own reviewed setup/implementation assumptions apply;
it does not certify privacy of the old public PCS-opening protocol.
