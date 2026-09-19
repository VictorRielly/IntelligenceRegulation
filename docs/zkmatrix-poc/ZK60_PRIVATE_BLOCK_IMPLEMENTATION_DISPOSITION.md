# Disposition of the private block implementation — security owner, 2026-09-19

Written by the interactive Claude Fable 5.1 session (the security owner) at
06:19 on 2026-09-19, on lane `zk60-private-block` at `5f3b2f7`. It rules on
the implementation of the design accepted the same night in
`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md`.

| Verdict | **Accepted as the custom line's experimental complete private block at the tiny geometry** (T32 tokens, width 16, two heads, one KV head, feed-forward width 16; profile `hashline-zk-mr1/private-block-t32-poc/1`). All six conditions of the construction disposition are met (§2). **It is not a privacy acceptance, establishes no privacy property, is not a trained model, and carries no speed claim for any larger shape** (§4). |
|---|---|

## 1. What was built, and by whom

A new module, `hashline/src/private_block.rs` and `hashline/src/private_block/`,
grown from a copy of the accepted private attention component into the whole
block — attention, the second RMS norm, the SiLU feed-forward, the second
residual — in one proof under one transcript with no seam, each commitment
opened once, inputs, outputs and activations hidden, weights public.

Built overnight by delegated Opus agents, one sole writer at a time, from the
accepted design, with a ledger (`ZK60_PRIVATE_BLOCK_IMPL_PROGRESS.md`):
scaffold and tests first; witness and layout; the argument; the block profile
with the tripwire; the checking tools on the real source; then an independent
adversarial code review by a different agent, and a last agent closing what
that review found. The only existing files the lane edits are one module
export in `hashline/src/lib.rs`, a dev-dependency in `hashline/Cargo.toml`, and
one constant (`TAG_ACT = 134`) in `hashline/src/tables_attn.rs`.

## 2. The six conditions, and the evidence for each

| # | Condition | Met by |
|---|---|---|
| 1 | The block profile lands only with the feed-forward relations; the tripwire first | The profile string, `BlockPublic` and the endpoint's move to `xres2` landed in one commit (`95756c8`) after the argument was green. `block_output_cannot_be_chosen` tampers `z16` by one, recomputes `xres2` and both limb pairs, has the endpoint owner commit the **chosen** output, builds a real receipt, and the **verifier** rejects at the down-requantization slot; the honest proof is asserted beside it. I read its source. |
| 2 | The activation table's value range enforced by the proof's own statement | `BlockPublic` holds it as `[i16; 256]` and its 256 words enter the statement digest with `gamma_m` and the three weight matrices (code review §5: digest order listed, every public word the argument reads is covered). |
| 3 | The 22 errata applied before building | Done on the design lane (`58f6150`); the implementers read corrected text. |
| 4 | The tools on the real Rust, all controls firing, plus two owed ones | `scripts/zk60_private_block_inventory.py`: the accepted attention verdict reproduced with the committed tool unmodified; on the real block source 46 of 46 counts equal the design, every opening group and both endpoints disclose 0, whole H's residual is exactly the public identity, six host groups with kernel 3 and leaked 0, every slot within `L + 256 ≤ 512`, **22 of 22 negative controls fire** including `A_H16` sharing `A_U16`'s pair and `A_YM` sharing `A_Y`'s; 74 of 74 items agree with the paper run. I ran its 29-test module myself. |
| 5 | Endpoint scales pinned to the calibration, calibration digest absorbed | `IoSpec::new` refuses any pair but `(0, 0)`; the digest is absorbed under `"calibration"` between `"parameters"` and `"schedule"`. It is a literal pinned to `causal_oracle`'s registration by a test: accepted for the proof of concept, to become a statement field when a second calibration exists. |
| 6 | Kernel parity including the refusal site and string | 1,200 fixed-seed public cases, every plane equal to `private-block-kernel` element for element, 905 accept and 295 refuse at the identical site with the identical message; every reachable refusal site also forced by a hand-built case, every unreachable one documented with its bound. |

## 3. What I verified myself, and what was delegated

- **My own runs**, recorded in `results/zk60_private_block_evidence/README.md`
  and repeated after the last fixes: the accepted attention files, `zk.rs`,
  `layer.rs`, `zk_ffn_fresh_io.rs` and `private_seam.rs` byte-identical to
  `zk60-attention-compile` at every stage; `cargo test --release --lib private_`
  **46 passed, 0 failed** (11 accepted attention tests, 35 block tests); 4
  integration tests pass; the example proves the whole block (0.095 s) and a
  fresh process verifies the **2,816,472-byte** receipt (0.041–0.043 s) —
  exactly the size the design derived before any code existed — and refuses
  three corruptions [diagnostic timings, shared box]; the tools' test module
  29 OK. **A receipt I produced before the last round of fixes verifies under
  the binary rebuilt after them**, so those fixes changed no protocol
  behaviour.
- **Source I read myself:** the tripwire and its harness; the `u16 = 0` test
  (below); the `requant` defect at `witness.rs:54`.
- **Delegated and independently checked, not re-done by me:** the argument's
  arms line by line (the adversarial review tabulates, for every new plane,
  the arm, the term and the class lookup that pin it, compares all seven
  relations with the kernel sign by sign, lists what the digest absorbs,
  compares the Fiat–Shamir order with the design, and reports seven failed
  attempts to construct a false witness the verifier accepts).

**The test I asked for above all others.** Wherever the up matmul is zero the
product relation says nothing about `a16`; only the pair lookup
`(g8 + 128, a16)` can see it (erratum E-22). The public fixture has no such
index, so one is built by zeroing a column of the public `Wu`; `a16` is moved
to another legal int16 off its table row, `h16` and both remainder limbs are
asserted unchanged, nothing else is recomputed, and **the verifier rejects at
the LogUp sum claim**, as predicted before it was measured. Every other new
tamper (the second norm's output, denominator, limbs and remainder windows; a
moved activation multiplicity) was likewise caught exactly where it was
predicted.

## 4. What this does not establish

- **No privacy property.** The tools check a linear-algebra model of the
  schedule that leaves out the sampled columns, the salted Merkle paths, the
  CFS channel, transcript conditioning, integer-range side information and
  correlation between the two commitments. The construction's own gate — on
  captured real receipts, a zero-witness preimage with the same free dimension
  as the real witness on every channel — is unmet, and needs a schema-3
  capture writer for this profile first.
- **D8 and D11 stay open** for the block's two external endpoints. D9 pending.
- **Not a model and not trained weights**: one block, a public synthetic
  fixture.
- **No speed claim beyond this shape.** A tenth of a second at width 16 says
  nothing about width 4096, and this form deliberately gives up the
  block-decomposed GPU feed-forward prover; the equality-seam form that keeps
  it is deferred with the two measurements that would force it named
  (construction memo §B.3).
- **Completeness** (that an honest witness always exists within the proved
  ranges) was tested on 1,200 cases, not proved; the no-wraparound bounds
  were derived at design level and re-checked in review, not mechanised.

## 5. Owed, none of it blocking this acceptance

1. A runtime test that edits the activation **multiplicity plane directly**:
   it is derived inside the prover, so reaching it needs a test-only hook in
   `protocol.rs`. LogUp's soundness covers an adversarial multiplicity on
   paper; the moved-unit test covers the histogram the prover derives.
2. The claim audit's shared-pair refusal is tested on the verifier's real
   claim list; a degenerate list cannot be forced through
   `prove_inner`/`verify_inner` because pairs come from the layout. Stated in
   the test.
3. The schema-3 capture writer for this profile, then the round-2 joint-view
   tools on real block receipts. **That is where a privacy statement starts.**
4. The calibration digest as a statement field, once a second calibration
   exists.
5. For whoever integrates: the committed inventory parser does not understand
   four constructs of this Rust, and for one of them
   (`protocol.rs:54–55`) it silently yields nothing instead of failing. The
   new driver carries named adapters and a test asserting the unadapted
   parser fails here. Two pre-existing red Python tests on this base are
   unrelated to the block (a missing `scripts/zk60_joint_cfs_view.py`; a
   committed record embedding another worktree's absolute path).
