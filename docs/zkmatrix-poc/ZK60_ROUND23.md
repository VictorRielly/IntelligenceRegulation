# Round 23 — endpoint simulation boundary and repeated-proof observations

This round continues from `4afa3fb`. Required privacy is unchanged: P1 hides
input, output and intermediate activations; P3 additionally hides weights.
No production prover, verifier, hash format, receipt format or privacy mode
changes. The new Rust file contains integration tests only.

## Endpoint preparation and the inherited simulator

[The endpoint simulation model](ZK60_ENDPOINT_SIMULATION_MODEL.md) specifies
the public statement, private owner state, root-only simulation obligation and
the distinct joint-preparation experiment. It gives no simulator the real
endpoint values, masks, pads or owner state.

Two maintained-Rust checks make the boundary concrete. A dummy commitment's
paths fail against a different caller root at the actual seven-row geometry.
Also, `salt_leaf(a,b)` and `hash_pair(a,b)` are identical hash calls. FA8's
assertion of disjoint hash domains does not cover that overlap. This corrects
an assumption in the inherited argument; it is not private-value recovery.

The research-only programmable-oracle prototype creates two endpoint roots
before it sees column values and keeps them unchanged through 512 openings.
It uses one oracle table, refuses programming at already answered points,
handles duplicate queries consistently and consumes owners on success/failure.
Eight tests check these properties, including foreign roots and prior node
queries. This verifies simulator bookkeeping only: its column values do not
come from a complete PCS sampler, and it is not a real BLAKE3 receipt.

## Two proofs of one witness, modeled together

`scripts/zk60_io_repeated_view.py` extends O8's **unchanged** `JointModel` to the
two fresh receipts per mode retained in round 22. It first verifies the
manifest, source/dependency hashes and accepted prior analysis. Missing,
duplicate, mixed-mode or reused-private-root evidence is refused.

Each commitment has its own group and proximity coordinates and independent
random rows. Within each proof, the usual X/z16 endpoint aliases remain. Across
the two proofs, corresponding A, endpoint and P3 W **data** rows are identified.
Those values come from the one synthetic witness constructed before the source
test's attempt loop. Different roots alone would not prove independence or
equality of the underlying data; the source-pinned fixture is the basis.

H data is deliberately **not** identified across proofs: its inverse/table
helpers depend on that proof's beta, gamma and alpha. Both H zero-sum constraints
are explicitly carried into the renamed commitments. The combined result is
checked by adding both public LogUp identities and by removing the zero-sum
constraints. A per-column matrix without site compression independently checks
the compressed ranks.

The controls include a model without cross-proof data sharing and one where
the first input commitment loses its second terminal-mask row. The latter
must detect the leaking first proof even when the second proof is correctly
masked. The first exploratory implementation rejected this intentional
control because it compared all random-row classifications; the corrected
guard compares the shared data-row geometry. The regression executes that
control and the initial error is retained.

Both P1 and P3 pairs give the same bounded conclusion: the jointly shared
A/Input/Output system has **zero disclosed base dimensions** over 88,064
shared data unknowns. Adding every private commitment leaves **four dimensions**,
exactly the two public H LogUp identities. Removing the H zero-sum constraints
reduces that to zero, and adding the two identities as explicit observations
adds no rank. The unshared control also gives four; the single-mask ablation
discloses **256 dimensions** despite the second correctly masked proof.
The full P1 and P3 systems use 3,732 and 3,751 merged rows respectively.

This is a **two-proof, fixed-coefficient message/terminal/proximity result**.
It excludes the CFS/pad/encoded-column/Merkle channels and adaptive transcript
composition. The already checked per-owner pad construction remains a separate
conditional component. Reusing the same commitment or proving an arbitrary
number of times is not covered. The known source fixture uses fresh owners.

## Validation and continuation

Exact commands, exits, logs, source/tool/result hashes and a completion marker
are retained in [the validation record](../../results/zk60_round23_validation.json)
and `results/zk60_round23_evidence/`. Runs use two CPU threads and an 8 GiB
address-space limit; Cargo tests take the shared heavy lock. No GPU or timing
benchmark runs are part of this result.

All seven stages pass: **39 Python tests with no skips**, **eight Rust tests**
(two new hash-boundary tests and six existing bound-IO tests), both repeated-view
analyses, the endpoint bookkeeping experiment, and native freeze-check. The
experiment has 241 distinct positions per endpoint, programs 482 fresh
salted-leaf inputs, and accepts all 512 paths under the two roots issued first.
No existing oracle point is reprogrammed. `validation.done` contains `0`.
The full repository suites were not rerun. Logs are retained verbatim, including
their trailing newlines; source/documentation whitespace checks pass.

The next work is the complete joint field-view sampler and its oracle
composition under the specified endpoint models. The root-only external
statement requirement remains open. Private attention and the tiny P1 block
follow privacy acceptance; P3's weight privacy and authenticated model identity
remain required. Full privacy acceptance and U-2 remain open.
