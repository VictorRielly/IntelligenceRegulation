# Round 21 — privacy requirement/history audit and IO CFS checks

## The privacy scope was already decided

Victor reaffirmed the existing scope on 2026-09-09: the first PoC hides inputs,
outputs and intermediate activations, with public weights allowed (P1). The
full version also hides weights (P3). Codex incorrectly reopened this decision
when asking whether the PoC could expose IO. That was a failure to consult and
retain the existing requirement; it was not a change requested by the user.

The repository already contained explicit evidence before this conversation:

| Existing source | Introduction | What it already said |
|---|---|---|
| `START_HERE.md`, privacy ruling in section 7 | `34a1c45`, 2026-09-03 | P1 private inputs/public weights is the first product path; private weights remains work to do |
| `hashline/src/zk.rs::ZkPrivacy` | `b026b04`, 2026-09-04 | P1 is `in+act+out`; P3 is `in+act+out+weights`; the output plane is explicitly included |
| `ZK60_EXECUTION.md`, acceptance target | `24ae746`, 2026-09-04 | P1 means private inputs, activations and output with public weights; P3 also hides weights |
| `ZK60_BLOCK_CONTRACT.md` and `private_block_contract.rs` | `24ae746`, 2026-09-04 | The first block contract requires P1, committed output, no predicate and approved public weights |
| `ZK60_PRIVATE_BLOCK.md`, decision | `24ae746`, 2026-09-04 | Build a tiny P1 private block first, then connected blocks; P3 adds private-model consistency |

The [requirements page](ZK60_PRIVACY_REQUIREMENTS.md) now states the full table
at one stable location. `CLAUDE.md`, `START_HERE.md`, the target contract,
status page, task board and Opus handoff point to it. Stale main-guide wording
that said the mode still needed a ruling has been corrected. Historical
performance reports and archived cryptographic reviews retain their original
scope; their labels are not evidence that privacy has been established.

## Did previous pushes change the private set or expose raw IO?

The audit found **no switch from private IO to public IO** in the inspected
requirement declarations, private endpoint implementation or recent pushes.
The [history record](../../results/zk60_privacy_history_audit.json) binds the
review to HEAD `9d06dd3` and records exact source-section comparisons:

- `ZkPrivacy`'s full private/public declarations are byte-identical to
  `b026b04`, including outputs in both modes.
- `ExpectedIo::to_bytes` and `prepare_endpoints` are byte-identical to the
  initial IO implementation `e8d4261`. The policy is 112 bytes: version,
  context, scales and two roots. It contains no raw endpoint tensor or secret
  commitment state. Preparation still creates two independent hiding owners.
- `e8d4261 -> 137b109` changes the commitment schedule to one precommitted
  eight-slot M and delays all openings. It preserves hiding endpoint openings
  and masked equality terminals; it does not make IO public.
- Reviewing the complete `137b109..9d06dd3` Rust diff finds only test
  diagnostics, tests and the equivalent `cfg(test)`/`cfg(not(test))` handling
  of existing canonical serialization. Round 19's hooks publish already
  verifier-visible observations only after full acceptance. Round 20 contains
  analysis, tests, documentation and evidence; it changes no Rust files.
- The saved-receipt verifier still chooses P1/P3 from caller policy, checks
  the expected roots, uses hiding A/H/endpoint openings, and reads no witness
  or endpoint secret material. The demo's fixture is explicitly public and
  synthetic; it is not a claim about protecting those already-known constants.

The audit also reviewed the private block contract diff from `24ae746`:
later changes add public-weight registration and a norm range guard; its P1 /
committed-output restriction remains intact.

These findings address requirement drift and the inspected serialization/
mode paths. They **do not certify the whole repository as zero knowledge**.
The legacy FFN scalar-mask disclosure is a real, previously recorded issue
([round 16](ZK60_ROUND16.md), [capture review](ZK60_FABLE_CAPTURE_REVIEW.md)).
The repaired profile has new masks and evidence but still lacks final joint
IO/transcript privacy acceptance. A public-set declaration or a passing proof
verifier cannot by itself establish secrecy. No new private-value recovery or
recent public-IO regression was found in this audit.

Useful history commands (before the documentation restatement):

```
git blame 9d06dd3 -L 70,72 -- docs/zkmatrix-poc/ZK60_EXECUTION.md
git blame 9d06dd3 -L 135,168 -- hashline/src/zk.rs
git diff e8d4261..137b109 -- hashline/src/zk_ffn_fresh_io.rs
git diff 137b109..9d06dd3 -- hashline zkp-core
git diff 24ae746..9d06dd3 -- hashline/src/private_block_contract.rs
```

## Independent progress: the two IO CFS round-message channels

The new [CFS check](../../scripts/zk60_io_cfs_composition.py) consumes the
four actual round-19 captures, bound to the accepted round-20 result and all
its source/dependency hashes. It does not modify or replace archived tools.

For each IO side the tool replays the ten degree-2 rounds and the exact
terminal identity:

```
fin = (1-e) eq(tau, rho[0..9]) (terminal_A - terminal_endpoint)
      + c * mask_eval
```

It checks that the two M functionals are exactly `c * sum_weights(10,2)`
with value `gamma`, and `eval_weights(rho,2)` with value `mask_eval`, on
the intended slot 6 or 7. This checks weights and values, not just slot counts.

At fixed challenges and fixed mask total/evaluation, the coefficient space
has Fp2 dimension 20 (22 coefficients, two independent conditions). Its image
on the 30 round values has dimension 19 and lies in the homogeneous sumcheck
chain with fixed claim and final value. That round space also has dimension
19: ten chain equations plus the final-evaluation equation. Thus the mask
image covers the complete conditional round space. The redundant coefficient
direction has dimension one.

This is checked on all eight real IO arguments and on degenerate challenge
sequences in tests. The tool translates each real round vector by a nonzero
element of this image and rechecks the chain and final value. Gamma, mask
evaluation, terminals and all fixed challenges remain unchanged. These
translated rounds are an algebraic diagnostic; they are **not a valid new
Fiat–Shamir receipt**, since changing a round changes its hash challenge.

The first ten M functionals have no IO-slot support and the two IO pairs use
disjoint slots. Their conditional round map is therefore block diagonal,
dimension 38. Round 20 supplies the separate fixed-challenge M-opening lemma.
This combination still requires an adaptive transcript argument and the joint
PCS message result; it does not establish full zero knowledge.

## The remaining work follows P1's actual privacy target

The inherited FA8 simulator builds its own dummy A/H/W commitments. The new
IO profile instead receives expected endpoint roots fixed by the caller.
Replacing these roots changes the statement. Keeping a dummy tree and merely
substituting the real root does not supply valid authentication paths. FA8
also explicitly avoids programming the Merkle hash. The existing written
simulator therefore cannot simply be transplanted to this interface.

This is a concrete missing argument, not evidence that the endpoint values
can be recovered. Definitions in the literature likewise distinguish joint
commitment/proof simulation and simulation for an existing statement; see
the simulatability definition in
[Shorter Lattice-Based Zero-Knowledge Proofs, Definition 2.8](https://iacr.org/archive/pkc2021/127110213/127110213.pdf)
and the stateful simulator/auxiliary-input definitions in
[From Polynomial IOP and Commitments to Non-malleable zkSNARKs, Definition 9](https://eprint.iacr.org/2023/569.pdf).
These are background definitions, not a security proof for this implementation.

The next work is:

1. Integrate O8's joint message/terminal/proximity result, with shared X/z16
   planes. O8 was still absent at this round's remote check.
2. Specify and justify the private endpoint preparation and simulator model
   for P1. Preserve hidden IO and intermediate activations; do not use public
   IO or supply hidden endpoint state to a purported public-input simulator
   without changing and clearly stating the security model.
3. Complete the P1 transcript composition, then implement private attention
   and a tiny P1 block. Existing P3 regression coverage stays in place.
4. Complete private weights and authenticated private-model consistency for
   the full P3 version. The minimal maintained core remains priority 3.

## Validation

The [validation record](../../results/zk60_round21_validation.json) retains
commands, exits, tool/source digests and logs in
`results/zk60_round21_evidence/`:

- Six existing Rust bound-IO tests pass, including fresh P1/P3 owners,
  recommitted wrong input/output, policy/owner mismatches, receipt mutations
  and relabelled policies. The full Rust suite was not rerun.
- All four retained receipts verify in separate processes. Twelve further
  processes reject changed input roots, changed output roots and wrong
  privacy modes. The release verifier binary matches the round-19 SHA-256.
- Seven new Python tests pass. All eight real IO CFS channel checks pass,
  with 72 real-capture corruption controls (rounds, gamma, challenges,
  terminals, mask evaluations and M functional weights/values/slots).

The first audit runner used the wrong JSON key for P1's public W root after
the Rust tests and eight P3 process cases had passed. It stopped with
`KeyError: commitment`; the actual schema stores `public_w.root`. The
corrected finisher completed the P1 cases and CFS checks without rerunning
the completed Rust/P3 stages. Both scripts, initial failure and final result
are retained. This was a runner error, not a rejected honest proof.

The Rust run uses the shared heavy-job lock, two build/Rayon/test threads and
an 8 GiB address-space limit. All `HL_*` variables are cleared. No production
proof code, format, privacy mode, GPU path or benchmark parameters changed.
