# Private endpoint simulation: the public statement and preparation state

Status: a specified security boundary and executable candidate hash-layer
construction, **not** a completed privacy proof. P1 still hides inputs, outputs
and intermediate activations; P3 additionally hides weights. Neither public IO
nor disclosure of real endpoint secrets to a simulator is an accepted shortcut.

**Round-24 progress:** the [conditional endpoint sampler](ZK60_ROUND24.md) now
constructs masks/pads for chosen dummy data while preserving a supplied field
view, and connects its encoded columns to the ideal-oracle candidate below.
It does not generate the public field view or sample A/H/W/CFS jointly. The
remaining full-sampler and external-root obligations in this memo stay open.

## The interface that must be preserved

`ExpectedIo` contains public context, two scales and two endpoint roots. Its
112-byte serialization enters `transcript()` before the FFN begins.
`prepare_endpoints()` privately constructs two independent seven-row hiding
commitments: two data rows, two terminal-mask rows and three proximity rows.
Each has 256 pads per row and 2048 independently salted encoded columns.
`Endpoints` and `PendingProof` are consumed when the proof is finished.

The public verifier receives the caller's expected roots. It does not receive
the endpoint values, masks, pads, salts for unopened columns, or private owners.
Its accepted proof opens 256 sampled positions per endpoint, including salts
and authentication paths. Binding to roots supplied by the caller is a
correctness requirement; it must hold even when a simulator is being discussed.

## Two different simulation experiments

**External statement, root-only proof simulation.** The simulator receives the
actual public policy and public model/parameters. Both endpoint roots are
already fixed. It must produce the proof view without endpoint values or real
commitment randomness. Any simulation setup/oracle state and auxiliary inputs
must be explicitly defined; the real endpoint owner is not a public input.
This is the outstanding obligation for the general `from_roots` interface.

FA8's existing simulator cannot simply satisfy this experiment: it builds its
own zero-data commitments and never programs Merkle/leaf hashes. Using such a
tree's paths with the real expected root does not authenticate. The new native
hash-boundary test exercises this directly at the actual seven-row endpoint
geometry. A valid authentication path also reveals a pair of top-level child
digests hashing to the fixed root; a root-only simulator with an unprogrammable
Merkle hash is not supplied such a preimage. This rules out that transplant,
not every conceivable simulator or commitment construction.

**Joint preparation and proof simulation.** Here the experiment includes the
honest endpoint-generation phase. A simulator may issue fresh roots during
that phase and keep *its own* simulation state. Those roots are then fixed
throughout the rest of that experiment. The ideal and real roots need not be
byte-identical across experiments; the joint public views must be
indistinguishable. This could cover the owner-generated workflow, but is a
different claim from simulating a proof for an arbitrary existing root.

The distinction is established terminology: Definition 2.8 of
[Lyubashevsky, Nguyen and Seiler](https://eprint.iacr.org/2020/1448.pdf)
defines joint commitment/proof simulatability and distinguishes it from
zero knowledge for adversarially chosen commitment randomness. This reference
supplies a definition, not a theorem about this implementation.

For the proposed joint experiment, use these explicit interfaces:

1. `SimPrepare(public_context, scales, dimensions)` returns public endpoint
   roots and private **simulator-generated** state. It receives no real IO,
   real masks, real pads, secret salt list or real prepared owner.
2. The caller fixes those roots as the statement before FFN challenges.
   Public context/model authorization remains a separate caller obligation.
3. `SimProve(sim_state, public_statement)` must maintain the issued roots,
   mirror refusal/consumption behavior and simulate all field messages,
   openings and oracle answers jointly. This algorithm is not yet complete.
4. The distinguisher sees the public preparation outputs, published proof(s),
   refusal behavior and its oracle answers. It may retain prior public views
   and side information. The security experiment must account for these;
   testing final proof bytes alone is insufficient.

The environment can select valid private inputs/witnesses for the real world;
the ideal simulator must not receive them through a hidden argument. Real
owner corruption, exporting commitment secrets, importing external roots and
reusing owners are not covered by this proposed fresh-owner game. The general
external-root obligation remains open rather than being relabelled as solved.

The need to expose simulation inputs precisely is also reflected by
[Faonio et al., Definitions 8–10](https://www.eurecom.edu/publication/7419/download/sec-publi-7419.pdf):
their stateful simulator handles proof requests and oracle queries together,
and supplying witness-dependent auxiliary leakage defines a weaker notion.
We do not supply real endpoint secret state under the name of auxiliary input.

## A concrete candidate for the preparation hash layer

`scripts/zk60_endpoint_simulation.py` implements the following **ideal-oracle
bookkeeping**, separately from every production prover/verifier:

1. Sample 2048 independent digest handles for an endpoint's leaves. Build the
   binary tree using ordinary queries to one oracle table. Emit its root now.
   There are no endpoint values or real commitment secrets in this state.
2. Later, obtain the selected encoded columns from a hypothetical joint PCS
   view sampler. That sampler is still owed. For each distinct selected index,
   query the hash of its seven canonical words, sample a fresh 32-byte salt,
   and program the previously unanswered salted-leaf input to that leaf's
   prepared digest handle. Supply the pre-existing authentication path.
3. Repeated indices return the identical column, salt and path. Conflicting
   duplicates refuse. A second use of the owner or a different expected root
   refuses, and a failed attempt consumes its state.

Every supplied path then verifies under the root issued before the columns
were chosen. The executable experiment checks two endpoints and 512 positions,
including duplicates. Its columns are arbitrary diagnostic values, **not**
claimed samples from the real proof distribution. Tests also choose columns
after seeing the root; that checks consistent late assignment, not adaptive
Fiat–Shamir security.

This candidate uses programming of salted-leaf queries. FA8 explicitly allowed
only round-challenge programming, so this is an extension of the proposed
proof model, not an application of FA8 unchanged. Real BLAKE3 cannot be
programmed; the tool does not generate a receipt accepted by the real verifier.

If the chosen inner-column digest is fixed before the fresh salt, and at most
`q` 64-byte oracle inputs have already been answered, the chance that the new
salted-leaf input is among them is at most `q / 2^256`. The tool refuses on
that event; it never changes an earlier answer. This is only the local
fresh-query bound. It omits the coupling to actual committed polynomials,
sumcheck distributions, preparation side information and all other bad events;
it is not a whole-proof distance bound.

## The oracle-domain correction

FA8 section A.2 claims its hash uses occupy disjoint domains. In the actual
source, these two uses are exactly the same function on their arguments:

```
salt_leaf(column_digest, salt) = BLAKE3(column_digest || salt)
hash_pair(left, right)        = BLAKE3(left || right)
```

Both inputs are 64 bytes with no tag. Prefixes in transcript initialization
and RNG derivation do not separate these two operations. The native test
checks equality directly using the maintained functions; no collision search
is involved. This is an invalid premise in the inherited argument, not a new
demonstration of private-value recovery or a claim of hash collision.

The candidate uses **one table** for nodes, inner column hashes and salted
leaves. A prior node query prevents programming the identical salted-leaf
input. Any completed reduction must likewise account for all actual overlapping
hash inputs. Source formats are unchanged; we have not inserted a new hash tag
into a protocol with frozen proofs.

## What remains before acceptance

- Construct the full joint distribution of field messages, CFS rounds, PCS
  pads/columns and programmed oracle outputs while roots remain fixed within
  each experiment. Rounds 20–23 provide conditional components, not this sampler.
- Justify both the preparation experiment and any claim for arbitrary external
  roots, including prior oracle history and allowed side information.
- Compose sequential/adaptively requested proofs with fresh owners, all
  refusal events and the actual transcript's reduction-to-field behavior.
  A fixed-coefficient two-proof rank calculation is not that argument.
- Retain the complete P1 private set and the P3 weight/model-identity work.
  A tiny private block follows privacy acceptance; none is enabled by this memo.

The next concrete simulator task is the joint field-view sampler feeding step
2 while respecting the shared endpoint planes and each owner’s pad budget.
It must be evaluated together with the external-root requirement, not used to
silently restrict that interface or claim full zero knowledge.
