# Run audit geometry — independent pickup, 2026-09-20

Reviewed the U-1 instance in `private_block/run_tests.rs` on delivery
`663555f0e912a7dc7a2c37bdf5f2cba35372b4ba`, against `audit_claims`,
`boundary.rs::prepare`, `endpoint_g.rs::prepare_with_rng`, and main's
`private_seam.rs::prepare_with_rng`.

The test establishes an API limitation: `audit_claims` checks the supplied
row declaration. It does not receive a commitment's entropy provenance and
cannot infer which rows its constructor randomized. Supplying a different
`prox` is therefore not evidence that an actual endpoint or run verifier
accepts a leaking proof. The test constructs claims and metadata, not such
a proof. The two-site 37-row instance is already rejected.

There is an additional source fact relevant to the replacement one-site
example. Both external endpoint constructors fill **all five appended rows**
with fresh field draws. Rows `data+2`, `data+3`, and `data+4` are all random;
the last is spare, not a deterministic row. The actual challenge check
requires a nonzero determinant on `data+2` and `data+3`. Relabelling the audit's
proximity pair as `data+3,data+4` does not remove the independent randomness
or the existing check. A rank example that gives the endpoint only one
effective random proximity row would need to account for that constructor
and check before describing this source as leaking.

For internal boundaries, `BoundarySpec` derives the row count and site/proximity
positions, `prepare` randomizes the entire appended region and attaches the
same metadata, and the opening path uses that spec. That agreement is the
invariant to retain in integration. Keep the single-proximity-row negative
control for a deliberately weakened construction, with that scope labelled.

Disposition: do not change the shared audit solely to reject this hypothetical
metadata tuple. It is useful to document its trusted geometry precondition;
future exposed geometry APIs should derive and bind it once. This review does
not accept whole-run privacy or replace independent tests of boundary binding,
the challenge checks, or the joint-view gate.
