# ZK60 decisions register — the rulings that govern the proof project

**Read this before claiming any security or privacy property, and record every
new ruling here the day it is made.** One entry per decision: what was
decided, by whom, why, what it means day to day, and what would reopen it.
Entries are never deleted; a reversed decision gets a new entry that points
back. Keep this file short enough to read in five minutes.

## At a glance

| ID | Decision | Status | Date | Decided by |
|---|---|---|---|---|
| D1 | Privacy scope: P1 hides inputs, outputs, activations (weights may be public); P3 also hides weights | **standing** | 2026-09-09 | Victor |
| D2 | Two lines: a zkVM intermediate delivers the first complete private tiny block; the custom-PCS line remains the route to the throughput target | **standing** | 2026-09-17 | Victor |
| D3 | Security level for the zkVM intermediate: about 97 bits conjectured soundness accepted, as a recorded deviation from the 128-bit target | **accepted** | 2026-09-18 | Victor |
| D4 | Groth16 trusted setup accepted for soundness of the zkVM intermediate's public artifact | **accepted** | 2026-09-18 | Victor |
| D5 | Public receipt kind: Groth16 only; composite never public; succinct is experimental evidence only | **decided (security review)** | 2026-09-18 | Fable disposition + Codex source review |
| D6 | Groth16 proving path on this box: native tools extracted from the official prover image, digests pinned (Docker absent) | **in progress** | 2026-09-18 | Codex (implementation) |
| D7 | New endpoint and weight identity profile for the zkVM route (salted SHA-256 commitments in a fixed journal; old PCS roots not compatible) | **accepted as the P1 statement of the zkVM line, with three recorded qualifiers**; the model approval record is still to be written | 2026-09-19 | Victor (Telegram 11:50); Codex implemented |
| D8 | Custom line, caller-fixed endpoint roots: obligation stands; the "two programmed points" closure is retracted for roots with any prior public opening | **corrected** | 2026-09-18 | Codex review; accepted by the security owner |
| D9 | Reduction-bias term of the prover's mask and pad draws on the custom line (about 2^-75 at the tiny shape, 2^-72 at 8B): accept as stated, or re-freeze fixtures with rejection sampling | **accepted as stated** | 2026-09-19 | Victor (Telegram 11:50) |
| D10 | Compact-PCS proof-size lever on the custom line (95–98 bits instead of 106) | **declined: keep the Ligero-class commitment** (the "free Merkle cap" first recorded beside this ruling is worth about 1% here, not 29% — corrected the same day) | 2026-09-19 | Victor (Telegram 11:50, phrased as a question and confirmed back to him) |
| D11 | D8's proposed reduction to empty history is not established by a consuming owner; prior authentication/hash history remains in scope | **technical correction** | 2026-09-18 | Codex native reproduction and independent review |
| D12 | Composed private block on the custom line: one proof, one transcript, two external endpoints; no commitment opened twice; hidden intermediates never get a shared caller-fixed endpoint; the second norm's int8 range proof is mandatory | **construction rule (restrictive; not a privacy acceptance)** | 2026-09-19 | Security owner (Fable), from the composition gap inventory |
| D13 | What the first MVP must prove: the hidden transformer blocks are enough; generating a token (embedding, final norm, head, token selection) is the next milestone | **decided** | 2026-09-19 | Victor (Telegram 11:50) |
| D14 | Commission a costed design memo for the fewer-hashed-bytes speed lever (encoding rate 1/2 and/or a 31–32-bit field). Paper only: building it would move every frozen digest and the soundness accounting, and stays a separate ruling | **memo commissioned** | 2026-09-19 | Victor (Telegram 11:50) |
| D15 | The custom line's "106 bits" is a per-opening figure; the projected whole 8B proof is about 94 bits. Every model-scale security statement quotes the whole-proof figure | **technical clarification**; the whole-proof target itself is a ruling still to be put to Victor | 2026-09-19 | Security owner (Fable), from `ZK60_FABLE_SECURITY_OBLIGATIONS.md` §5 and the D14 memo |
| D16 | Before the private block's norm is widened toward real-model widths, its denominator and the two isqrt witnesses keep a direct byte-limb range pin sized to the new maximum, at most four limbs each, with an exact remainder window | **construction rule (precondition for widening; soundness)** | 2026-09-19 | Security owner (Fable), from the norm range lane |
| — | RTX 5090 install (an action, not a ruling; the 600 W bound was ruled on 2026-09-04) | **go**; date, machine and host RAM still to be named | 2026-09-19 | Victor (Telegram 11:50) |

Operational rules (detached heavy runs, the shared-box lock, command hygiene)
live in `CLAUDE.md`; they are not repeated here.

---

## D1 — Privacy scope (standing since 2026-09-09)

**Decided.** The first proof of concept, P1, hides inputs, outputs and every
intermediate activation from the verifier and from every public artifact;
model weights may be public. The full version, P3, also hides weights.

**Why.** This is the product: a regulator or auditor can check that an
approved model produced an answer without learning the prompt or the answer.

**In practice.** Public-IO demos are diagnostics, never deliverables. A
component that opens or publishes an endpoint value is not P1. An unresolved
privacy argument is work to do, not a reason to shrink the private set.

**Reopens only** on an explicit new instruction from Victor.
Source: `ZK60_PRIVACY_REQUIREMENTS.md`.

## D2 — Two lines (standing since 2026-09-17)

**Decided.** Run an implementation, review and test loop until a workable
private MVP exists, using a RISC Zero zkVM re-execution of the exact integer
block as the intermediate. Keep the custom-PCS prover (hashline) as the
route to the model-scale throughput target.

**Why.** The custom line's privacy argument still has open obligations (D8)
and its private attention is unbuilt; the zkVM route sidesteps both because
its proof never opens the endpoint commitments. The zkVM route cannot reach
the throughput target: re-executing an 8B model is on the order of 10^13
cycles, so it is a functional intermediate and a differential oracle, not
the product's prover.

**In practice.** "Tiny block" claims come from `zkvm-block/`; speed claims
come from hashline. Neither line's results are quoted as the other's.
The exact-integer kernel (`private-block-kernel/`) is shared by both.

**Reopens** if the zkVM route's assumptions (D3–D5) become unacceptable, or
if the custom line's privacy acceptance lands first.
Sources: `ZK60_MVP_LOOP_20260918.md`, `ZK60_ZKVM_REVIEW_DISPOSITION.md`
(branch `zk60-mvp-fable`), `ZK60_FABLE_LANE_HANDOFF.md`.

## D3 — About 97 bits of conjectured soundness accepted for the zkVM intermediate (2026-09-18)

**Decided.** The zkVM intermediate's proofs are accepted at RISC Zero's
shipped security level, about 97 bits conjectured for 2^20-cycle segments
(95 at 2^24) and roughly 100 bits for the BN254 Groth16 layer, instead of
the project's 128-bit target. This is a **recorded deviation**, not a change
of the target: the target stays 128 bits for the product.

**What the number means.** "Bits" measure the work a forger needs: about
2^97 operations to produce a proof of a false block result. "Conjectured"
means the figure rests on a widely used but unproven conjecture about the
FRI protocol (the "toy problem" conjecture from ethSTARK); the bound that is
actually proven is lower and must be read off the build (see below). For
comparison, hashline's own default profile is 106 bits and its compact
lever 95–98 (D10), so the whole project is currently below 128.

**Why accepted.** The parameters (50 FRI queries, rate 1/4, the digest
width) are compile-time constants baked into RISC Zero's recursion circuits,
control roots and Groth16 circuit; no setting raises them. Reaching 128 bits
would mean a different proof system. For an intermediate whose purpose is a
complete private block, not a deployed product, the shortfall is accepted.

**In practice.**
- Every document that mentions the intermediate's security says
  "about 97 bits conjectured (RISC Zero default), accepted per D3", never
  "128 bits" and never "secure" without the number.
- The first real proving run records the build's own two figures,
  `conjectured_security` and `proven_soundness_error`, from
  `risc0-zkp/src/prove/soundness.rs` (`RUST_LOG=risc0_zkp=info`), and this
  entry is updated with them.
- Segment size stays at 2^20 or below (larger segments lower the figure).

**Reopens** when a proof system at or above 128 bits is adopted (the custom
line, or a future RISC Zero circuit version with different parameters), or
if the proven bound recorded from the build is unexpectedly low.
Sources: `risc0-zkp-3.0.5/src/lib.rs:40–46`, `src/prove/soundness.rs:15–35`;
`ZK60_ZKVM_REVIEW_DISPOSITION.md` §1–§2; vendor page
`dev.risczero.com/api/security-model`.

**D3 measurement addendum, same day.** The installed upstream calculator
has now been called directly with each actual circuit's tap set. At the
integration's trace limit `2^18`, rv32im reports **98.6424 conjectured bits**
and **45.3014 proven list-decoding bits**; recursion at its fixed `2^18`
reports **99.7587** and **46.0184**, respectively. These are per-circuit
calculator outputs, not a composition/whole-proof bound and not captured
prover telemetry. At `2^20`, the rv32im outputs are 97.1420 and 41.5670.
The accepted conjecture-based interpretation stays explicit. Source hashes
and all rows are in `results/zk60_loop_20260918/risc0-security.json`;
`zkvm-block/security/` invokes the installed Rust functions without private
data. The first proof ran with debug logs disabled; contrary to the earlier
command hint, this crate emits the per-proof figures at **debug**, not info.

## D4 — Groth16 trusted setup accepted for soundness (2026-09-18)

**Decided.** The public artifact of the zkVM intermediate is a Groth16
receipt, whose soundness depends on RISC Zero's trusted-setup ceremony.
This dependency is accepted.

**What a trusted setup is, in plain words.** Groth16 proofs are tiny and
fast to check because the verifier holds a fixed "reference string": a set
of elliptic-curve points computed once from secret random numbers. Whoever
knows those secret numbers can forge a proof of any false statement; nobody
can forge if they were destroyed. A ceremony makes many participants
contribute their own secret one after another and destroy it; the final
string is safe as long as **at least one** participant was honest. RISC
Zero ran such a ceremony for its STARK-verifier circuit and ships the
resulting verifying key as constants.

**What it does and does not affect.**
- *Soundness*: a colluding ceremony (every participant dishonest) or
  subverted ceremony software would allow forged receipts, i.e. a fake
  proof of a block result that never happened. That is the risk accepted.
- *Privacy*: **not affected.** Groth16's zero knowledge holds for any
  well-formed reference string, even one whose secrets are known. Inputs,
  outputs and activations stay hidden regardless of ceremony honesty.
- *The inner STARK*: unaffected either way; it has no setup.

**Why accepted.** The alternative, a succinct STARK receipt, has no setup
but its hiding rests on the vendor's STARK blinding, for which the vendor
itself states no finished mathematical argument (and the segment-level
prover adds no blinding at all). Groth16 trades a soundness assumption the
project can name and pin for a privacy argument it can cite (Groth 2016,
Theorem 3). For a private-block intermediate, privacy is the property that
matters most.

**In practice.**
- Pin and record: ceremony key `2024-05-17.1`, SHA-256
  `69c6056451ea814b37e30ccbc44639dbaafef73540cbfbff6ec7e68e2d325735`;
  verifying-key constants in `risc0-groth16-3.0.5/src/verifier.rs`;
  default verifier-parameter digest
  `73c457ba541936f0d907daf0c7253a39a9c5c427c225ba7709e44702d3c6eedc`;
  prover image manifest
  `sha256:7f173963196570b7a71816ed70565a4579264c5d2e3e0ecb028102538ad0e331`.
- Run RISC Zero's published ceremony verification once
  (`snarkjs zkey verify` against the published R1CS hash) and record the
  outcome here; until then the well-formedness of the string is an
  assumption, not a checked fact.
- The verifier binary embeds its verifying key and control roots; it never
  takes them from a receipt.

**Reopens** if RISC Zero publishes a new ceremony or circuit (new key), if
the ceremony verification fails, or when the product's prover no longer
needs a setup (the custom line is transparent).
Sources: `ZK60_ZKVM_SOURCE_REVIEW.md` (CRS and prover-randomness chain),
`ZK60_ZKVM_REVIEW_DISPOSITION.md` §1, §3; vendor page
`dev.risczero.com/api/trusted-setup-ceremony`.

## D5 — Receipt kind: Groth16 only (2026-09-18)

**Decided.** Only a Groth16 receipt leaves the prover. A composite receipt
is never public: its per-segment claims carry memory-image roots at every
split and its segment count reveals cycle counts, and the rv32im segment
prover adds no blinding rows in circuit 4.0.5. A succinct receipt is used
only as explicitly experimental evidence while the Groth16 wrap is being
brought up; it is never presented as a private artifact.

**In practice.** The verifier matches the receipt kind explicitly before
anything else, refuses dev mode by construction, and is built with
`default-features = false` (the crate's default features include the
Bonsai upload path). Fake receipts are refused always.

**Reopens** only with a reviewed zero-knowledge argument for the succinct
receipt at the shipped parameters.
Sources: `ZK60_ZKVM_REVIEW_DISPOSITION.md` §1–§2, §4;
`ZK60_ZKVM_SOURCE_REVIEW.md`.

## D6 — Groth16 proving path on this box (in progress)

Docker is not installed; the crate's Docker path cannot run. Codex is
extracting the native prover tools (`stark_verify`, `prover`, the proving
key) from the official image at the pinned manifest digest and running
them directly, with each tool's SHA-256 recorded (`scripts/zk60_zkvm_demo.py
--native-tools`). The CUDA Groth16 component is the alternative, not
installed; the 8 GB laptop GPU and the box's VRAM-freeze history make it
the second choice. This entry closes when the first Groth16 receipt
verifies and its tool hashes are recorded.

**Closed 2026-09-18 19:18.** The first Groth16 receipt (785 bytes, SHA-256
`6c67e05c…32e7`, image `8d74aab3…98d9`) was produced by the native tools
in 197 s and verified independently, by Codex's stage and again by the
security owner in a fresh process; the inner succinct receipt and seven
corrupted variants are refused. Tool provenance: `groth16-native-files.json`
under `results/zk60_loop_20260918/block-integration/`; public artifacts
retained in `…/groth16_public/`. Hardening items from the source review
(`ZK60_ZKVM_BLOCK_SOURCE_REVIEW_FABLE.md`) are open but not blocking.

## D7 — New endpoint and weight identity profile (implemented, ruling pending)

The zkVM route commits endpoints as salted SHA-256 hashes inside a fixed
public journal (Codex's implementation: 144 bytes; Fable's proposal: 260
bytes, superseded by the implementation), and identifies weights and
calibration by digests over the bytes the guest uses. Old PCS endpoint and
weight roots have no meaning here; a chain of blocks is checked by journal
equality, not by a seam argument. **Pending:** Victor's acceptance of this
profile as the P1 statement for the intermediate, and a new approval record
for the model digests. Until then the artifact is "complete-block
experiment", not "private block".

**Ruling (Victor, Telegram, 2026-09-19 11:50): accepted, with three
qualifiers written into the acceptance.** In plain words: for the zkVM
line, "private" now officially means that the prompt and the answer appear in
the public record only as SHA-256 fingerprints, each mixed with a 32-byte
secret salt, inside a fixed 144-byte record, and the model is named by
digests of the exact bytes the program used. The two verified Groth16
receipts (one block; the two-block token model) stop being "experiments"
and may be called **zkVM line, private under D3, D4, D5 and D7**. The
qualifiers, which travel with every such claim: (1) the hiding of an endpoint
is the secrecy of its salt under SHA-256 — in the toy token model the answer
is one of only 32 values, so whoever learns the salt learns the answer, and
the model library still accepts an all-zero or repeated salt (hardening item
H5 of the token source review; honest runs draw fresh salts); (2) the
program's identity (its image ID) depends on the directory it was built in,
so any approval record says "locally built, unreproduced" until a container
build exists; (3) timing is declared leakage — the secret scan and the
constant-cycle check were run for the block program on nine inputs (a
sample, not a proof of constant time) and not yet for the token program.
What this does **not** do: it is the definition of the claim, not a finding
that a cryptographic analysis was performed beyond the reviewed Groth16
premises; and the second half of D7, the approval record for the model
digests, is still to be written and cannot be credible before qualifier (2)
is fixed. Pages: `ZK60_RULINGS_FOR_VICTOR.md` §2.

## D8 — Caller-fixed endpoint roots on the custom line (corrected 2026-09-18)

**Standing obligation.** A proof on the custom line must be simulatable for
endpoint roots the caller fixed, with the distinguisher allowed to keep
prior public history (`ZK60_ENDPOINT_SIMULATION_MODEL.md`).

**Correction.** The round-2 memo on `zk60-mvp-fable` claimed this is met by
programming one oracle point per root. Codex's review showed that any
previously published authentication path under that root reveals the
honest top pair (the last sibling on the path), so the programmed point is
detectable as a second preimage. The claim is **retracted for any root with
a prior public opening**. What stands: for a root with no prior opening the
argument is unaffected, and the `/2` protocol's own pad budget means a
second opening of the same endpoint commitment is outside the protocol
anyway (the consuming API enforces one opening). The obligation therefore
reduces to stating the experiment for unopened roots and keeping one
opening per commitment; that restatement is the security owner's next
custom-line task, not a closed item.

**In practice.** No document says the external-root obligation is closed.
The joint-view tools and the attention construction remain valid
engineering; they do not establish whole-proof privacy.
Sources: `ZK60_JOINT_VIEW_REVIEW_20260918.md`; `ZK60_MVP_JOINT_VIEW.md`
§1.1 with its correction note.

## D11 — Technical correction to D8 and profile clarification (2026-09-18)

The historical D8 text is retained above, but its statement that one-use
ownership reduces the privacy experiment to unopened roots is not accepted.
An ordinary authentication path or root-child hash query can exist before
the sole accepted `finish`; the consuming API does not erase that history.
The general caller-fixed-root obligation stands unchanged.

Two native PCS openings at the actual endpoint geometry recover all 512
data words; fresh-owner controls do not. This confirms that consumption is
necessary for that opening design, not that the remaining one-use proof is
zero knowledge. A forced-challenge counterexample also refutes the new
budgeted simulator's universal per-use rank premise, without establishing
an efficient attack on randomly sampled challenges.
[Evidence and limits](ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md).

D7's phrase "a chain of blocks is checked by journal equality" is a proposed
integration description, not an implemented property. The block profile's
input/output roles are distinct, so its roots cannot be equated directly
across blocks. The next separate token-model guest recomputes both blocks
and their hidden seam inside one program; the public policy binds its
complete model and endpoints. This clarification changes no user ruling.

## D12 — How a complete private block is composed on the custom line (construction rule, 2026-09-19)

**In plain words.** A transformer block is attention followed by a
feed-forward part. Between them sit hidden values (the first residual
`xres1`, the second norm's output `nm`, the feed-forward output `z16`). The
tempting way to join the two existing components is to commit such a hidden
value once and let both proofs open that one commitment. That is exactly the
configuration D11 records as broken: at the actual endpoint geometry (7 rows
of 256 columns) two openings recover all 512 hidden words. This rule forbids
it and fixes the frame everything else is built in.

**The rule.**

1. **No commitment is opened more than once, anywhere in a composed block.**
   The double-opening configuration of
   `ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md` is not permitted as a seam,
   as a convenience, or as a test shortcut that could be mistaken for one.
2. **A block is one proof under one transcript with exactly two external
   endpoints**: its hidden input `x_in` and its hidden output `xres2`. Two
   separately finished component receipts glued by a shared root are not a
   block.
3. **Hidden intermediates never get a caller-fixed endpoint commitment shared
   by two proofs.** `xres1`, `nm` and `z16` live only on commitments the
   prover generates inside that one proof. How the two halves are tied
   together there (an equality between the two components' own commitments
   with reserved mask pairs and a seam slot, as
   `ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md` line 99 specifies, or a single
   shared layout with no seam at all) is settled in the block construction
   memo, with the simpler form built first and the other documented with
   what it is worth.
4. **The second norm must prove that its output is in the int8 class.** The
   feed-forward prover proves no range on its own input (verified in
   `hashline/src/layer.rs`: the lookup list covers the activation, the two
   int16 planes and the output, never the input plane), so without this the
   composed statement would admit an out-of-class feed-forward input.
5. **Declared endpoint scales must be tied to the approved calibration**
   before any seam compares them. Today the tag proves nothing, and the
   attention fixtures declare `(-3, -3)` where the calibration has
   `e_r = e_r1 = 0`; a tag-equality check would pass on a factor-of-8
   mismatch.

**What this does not do.** It is restrictive only. It does not discharge D8
or D11 for the block's two external endpoints, it accepts no privacy
property, and it makes no speed claim. The joint analysis for the extra seam
groups has never been done and remains owed at the block-scope privacy gate.
Source: `ZK60_PRIVATE_BLOCK_COMPOSITION_GAPS.md` on branch
`zk60-attention-compile` (`c2e010e`), sections 3, 4 and 5; the two code facts
in items 4 and 5 were re-checked by the security owner in the source.

**Follow-up, same day (03:01): the construction inside this rule is accepted
as the design to build.** Of the two forms item 3 left open, the simpler one
is built first: no seam at all, the attention construction grown into the
whole block in a new module, so every hidden intermediate sits on one proof's
own commitments. The other form (an equality between two components'
commitments) is deferred with its cost written down; it is what 8B will
probably need because it alone keeps the GPU feed-forward prover, and the two
measurements that would force it are named. The design was drafted and
independently checked by delegated agents, with the rank and slot tools run
on a paper description of the whole block (nothing disclosed, every negative
control fires) and 22 errata made binding. Still not a privacy acceptance.
Ruling and conditions:
`ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` on `zk60-attention-compile`
(`e5962d2`).

## D9 — `fp()` reduction bias (accepted as stated, 2026-09-19)

Challenge words are 128-bit draws reduced mod p, each within 2^-96 of
uniform; over a proof this is about 2^-75 at A00. Either accept the term
in the privacy bound or re-freeze fixtures with rejection sampling (a
byte-changing change). Not gating any current work.

**Ruling (Victor, Telegram, 2026-09-19 11:50): accept the term as stated.**
In plain words: the prover's random masks are very slightly uneven, and the
final privacy statement will read "indistinguishable up to about 2^-72" (one
part in 5 × 10^21 at the 8B shape; 2^-75 at the tiny shape, 2^-72.9 at 125M)
instead of being exact. Nothing is re-frozen. **Wording correction to the
entry above**, from the source it cites (`ZK60_FABLE_TRANSCRIPT_REVIEW.md`
§B.7): the term comes from every *mask and pad the prover draws*, not from
the challenges, which the verifier reduces identically in both worlds and
which contribute nothing; and it is a **privacy** term, not a soundness
term — it does not make a false proof easier to forge. The bound already
carries a larger residual of about 2^-62 at the same shape, which is why
removing this one would not have made the statement unconditional. If an
auditor ever requires it removed, the change is one line in `ZkRng::fp`
(rejection sampling) plus a re-freeze of the zero-knowledge fixtures, and it
should be done after any lane that leans on the two frozen zero-knowledge
digests has landed. Pages: `ZK60_RULINGS_FOR_VICTOR.md` §6.

## D10 — Compact-PCS proof-size lever (declined, 2026-09-19)

Drops a Mistral-7B layer's proof from 38.7 MB to 1.94 MB at 4.4x the prover
time and 95–98 bits instead of 106 (`START_HERE.md`, lane AF). A soundness
ruling for Victor; not compatible with the GPU path or zero knowledge yet.

**Ruling (Victor, Telegram, 2026-09-19 11:50): declined — keep the
Ligero-class commitment.** His message put it as a question ("5 seems to be
a no go?"); the recommendation in front of him was "no", it was confirmed
back to him the same minute, and he can reverse it with two words. In plain
words: the compact format would shrink an 8B proof from 1.23 GB to about
62 MB, but it **cannot run in private mode at all** (`--pcs compact --zk` is
refused by the prover), it does not live on the GPU, it multiplies proving
time by about 4.4, and it lowers soundness from 106 bits to 95–98. The
product is private (D1) and the goal is speed, so it pays on neither axis.
The proof-size budget in the target contract therefore stays unmet and
stays a recorded gap. **Correction, 2026-09-19 12:10 (security owner):** the
first version of this entry offered "capping the Merkle paths, about −29% of
bytes" as a free improvement. That figure was counted for the *compact*
commitment (157 queries across about ten trees,
`PROVING_CHANNEL_OPTIONS.md:244–248`); on the Ligero-class 1.23 GB proof the
Merkle paths are about **1%** of the bytes, so the cap is worth about 1%
[COUNTED, `ZK60_L4_FEWER_HASHED_BYTES_MEMO.md`]. There is no free lever on
proof size on this commitment; the ruling is unaffected, because its reason
is that the compact format cannot run privately. The
costed memo of D14 must say what its lever does to proof size as well as to
time. Pages: `ZK60_RULINGS_FOR_VICTOR.md` §5.

## D15 — "106 bits" is per opening; the whole 8B proof is about 94 (technical clarification, 2026-09-19)

**In plain words.** Each time the custom line's prover opens a commitment, a
cheating prover slips past the check with probability about 2^-106: that is
(3/4)^256, from 256 opened columns at encoding rate 1/4 under the proximity
rule the code assumes (`zkp-core/src/pcs.rs:17–19`; reproduced exactly by the
D14 memo). D3 above and several status pages quote that 106 as "hashline's
security level". **It is the level of one opening, not of a proof.** An 8B
proof makes about six openings per layer over 32 layers, and a forger needs
only one of them to fail, so the chances add up: the security owner's own
2026-09-08 projection puts the commitment term of the whole proof near
2^-98.7 and the lookup term near 2^-94.2 — **about 94 bits for the whole 8B
proof, before any cap from the hash** (`ZK60_FABLE_SECURITY_OBLIGATIONS.md`
§5, the deployment row; a PROJECTION of the same relations, not a measured
artifact). The tiny fixed block is a different object: about 2^-110 over its
two commitments, and that figure does not scale up.

**In practice.** Any statement of the custom line's security at model scale
quotes the whole-proof figure, labelled a projection, next to the zkVM
line's "about 97 bits conjectured" (D3): **at 8B both lines are below 100
bits today**, against a 128-bit target. Raising it is possible — more opened
columns, a lower rate, or batching openings across layers — and each costs
proof bytes or prover time; the D14 memo prices the first two.

**What is not decided here.** Whether the product's target is a per-opening
or a whole-proof figure, and how many bits, is Victor's ruling (the D14
memo's question G.0-2). It is not urgent for a tiny-block MVP; it becomes
binding before any byte freeze at model scale, and it decides whether the
rate half of the D14 lever is a gain or a net cost.

## D16 — The private block's norm before it is widened (construction rule, 2026-09-19)

**In plain words.** A norm divides by a square root. The proof does not
compute the square root; the prover supplies it (`D`) with two helper numbers,
and the verifier checks algebra that pins it. Over a prime field that algebra
has a second solution nobody intended — `D` replaced by `k + (p−1)/2` — unless
something forces `D` to be a small non-negative integer. In the project's
older public-IO attention prover nothing does (obligation R09): the alias is
excluded at the tiny profile only because its remainders happen not to fit
two 16-bit limbs, and **any profile with three remainder limbs — which is what
an int24 residual at width 4096 needs — accepts an all-zero norm output.**

**What was established today** (lane `zk60-private-norm-range`, pushed;
`ZK60_PRIVATE_NORM_RANGE_OBLIGATION.md`; test-only Rust, 41 tests pass, 5
new). The **private** block does not share that gap. It range-proves `D`
directly: `d = l0 + 256·l1 + 65536·l2` with every limb looked up in the 8-bit
table (`private_block/argument.rs:583–593`, `layout.rs:314–315`), for both
norms. The alias was built against this module's own relations and is
**refused by the verifier at the fixed profile by that range fact**, not by a
width: with honest limbs the zero-check slot rejects; with limbs made to
reconstruct the alias — so that every relation of all 23 slots holds in the
field — the byte lookup rejects. Both catches were predicted before they were
measured. Its remainders are proved in an exact window, so there is no
R10-style slack either.

**The rule, binding on any widening of the private block's geometry:**
1. `D` keeps a direct byte-limb range pin with `⌈log256(Dmax + 1)⌉` limbs:
   three today (Dmax 2^17) and at width 4096 with an int16 residual (2^21);
   **four at width 4096 with an int24 residual (2^29).**
2. The two isqrt witnesses `a1`, `a2` get the same treatment: their present
   exclusion **lapses at four limbs** (the alias's `a1` is about 2^30).
3. Never more than four limbs on any of them: `(2^32 − 1)² + (2^32 − 1) = p − 1`
   exactly, so four is the last count at which the square relation cannot wrap.
4. The remainder window stays exact and its coefficient is rewritten for the
   new width; the present window keeps about one bit of margin at int24 /
   4096 and less than a tenth of a bit at 8192, and `1 << (32 − NORM_WRHO)`
   (`layout.rs:321`) underflows above 32.
5. The audit that every committed value under a non-unit coefficient is
   independently range-proved is re-run on the widened layout, and the
   wraparound premise at `layout.rs:281–309` is re-derived.
6. The alias tamper tests of this lane travel with the module and must reject
   at every widened profile before it is used.
**Cost at the first widening:** 6 more claim sites, 12 more `A` rows
(455 → 467), 96 proof bytes, no new lookup, table, sumcheck or degree; a new
statement version. **Not covered:** the widened profile was analysed on paper
and by arithmetic tests, not run through the verifier, because reaching it
needs production changes this lane was not allowed to make; the public-IO
prover's R09 is unchanged and still owes the fix verified on 2026-09-08.

## D13 — What the first MVP must prove (decided 2026-09-19)

**Ruling (Victor, Telegram, 2026-09-19 11:50): the hidden transformer blocks
are enough for the first MVP; generating a token is the next milestone.** In
plain words: the first MVP is a private proof that the blocks of a model were
computed correctly on hidden inputs, with hidden outputs. It does not have to
go all the way to an emitted word — the embedding, the final norm, the output
head and the token selection are the milestone after. Why this was the
moment: the target contract's clock covers only the feed-forward blocks; only
the slow zkVM line has a token path at all (the two-block token model); and
the custom line's token path (task A10) is unbuilt, uncosted, and carries two
open design questions of its own. What it changes: A10 and everything
downstream of an emitted word leave the MVP's critical path; the MVP's
acceptance gates in `ZK60_MVP_COMPLETION_PLAN.md` §1.3 that concern
embedding, head and token selection become next-milestone gates. What it does
**not** change: P1 (D1) — inputs, outputs and activations hidden — and the
two-line structure (D2). Pages: `ZK60_RULINGS_FOR_VICTOR.md` §3.

## D14 — A costed memo for the fewer-hashed-bytes speed lever (commissioned 2026-09-19)

**Ruling (Victor, Telegram, 2026-09-19 11:50): write the memo. Paper only.**
In plain words: almost all of the prover's device time goes into encoding
and hashing committed data. Two changes would shrink that data: a
Reed–Solomon encoding rate of 1/2 instead of 1/4 or 1/8, and a 31–32-bit
field instead of the 64-bit Goldilocks field. It is the only recorded lever
that could take an RTX 5090 from 10–15 s per proof to 5–10 s [MODEL,
`ZK60_FIVE_SECOND_PLAN.md` §5 step 6]. It is also the most expensive change
the project could make: **it moves every frozen proof digest in the
repository and changes the soundness accounting** (a smaller field needs
extension-field challenges and more queries; a higher rate needs more
queries for the same proximity bound). The 2026-09-04 deferral rested on
"the 8B pass does not need it", which a 5-second target changes. This ruling
commissions the memo that turns "is 5 s possible" into a yes or a no with a
price: what changes, what it buys in seconds on the 4070 and the 5090, what
it costs in bits of soundness or in extra queries to keep them, what it does
to proof bytes, what must be re-frozen, how many weeks, and what could make
it fail. **Building it remains a separate ruling.** Pages:
`ZK60_RULINGS_FOR_VICTOR.md` §4.
