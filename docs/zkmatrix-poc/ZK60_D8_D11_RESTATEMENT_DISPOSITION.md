# Disposition of the D8/D11 restatement — security owner, 2026-09-19

Written by the interactive Claude Fable 5.1 session (the security owner) at
22:11 on 2026-09-19. It rules on two delegated documents:

| Short name | Document | What it is |
|---|---|---|
| R | `ZK60_D8_D11_RESTATEMENT.md` | a draft restating the open endpoint obligation as a game, counting the hash layer, costing five candidate closures and recommending one |
| R-check | `ZK60_D8_D11_RESTATEMENT_CHECK.md` | an independent adversarial check of R, told that the last confident closure of this obligation was retracted within days: 10 holes, 11 corrections, 7 conditions; counts under `results/zk60_d8_d11_check/` |

| Verdict | **R is NOT accepted as the project's position, and D8 and D11 stand exactly as written.** R's recommended route — restrict the obligation to roots first published together with the consuming proof, plus a written theorem — **cannot be adopted as written**: its central reduction is circular. What survives, and it is a great deal, is recorded in §2. What the check exposes is **a product question that only Victor can answer** (§3). |
|---|---|

## 1. Why the recommended route fails as written

1. **"The case of a root with prior history but one opening is empty" is
   circular** (hole 1). A previously published path under a root *is* an
   opening, by definition; every other kind of history is excluded by the
   theorem's own restrictions, and restriction R2 literally states the
   conclusion ("neither root's honest top pair has reached the distinguisher
   by any route"). D11 and the reuse disposition refused exactly this
   reduction twice already. It is an enumeration of what R2 assumes, not a
   result.
2. **The party who fixed the root is excluded from ever being the adversary**
   (hole 2). R1 hides the commitment's randomness from the distinguisher.
   Whoever holds the salts can rebuild the tree and detect the simulator's
   programmed top pair with probability 1. So the theorem protects a hidden
   input against everyone **except the party who committed it** — and a
   regulator who supplied *and committed* an input is precisely that party.
   The notion is new and project-specific; the citation offered for it
   (hole 3) maps, in the draft's own source, to the *other* game, in which the
   simulator produces the commitments.
3. **The advantage expression is not a bound** (hole 6): its field-layer term
   is "whatever the discharge of U-3 contributes", and U-3 is open. Two
   sentences a reader would quote are wrong as samplers (holes 7, 8): a
   commitment to the all-zero plane does not have the right law once the
   verifier's two linear identities condition it, and the 256 salts come from
   the same keyed stream as the plane's secret mask rows and pads, so "same
   law in both worlds" needs a stated generator assumption.
4. **The enumeration of histories was not exhaustive** (hole 10): a receipt
   that the verifier *rejects* is still emitted with 256 genuine paths under
   the root (`zk_ffn_fresh_io.rs:256–257`, no equality precheck), and retained
   captures write complete receipts to disk (`native_capture.rs:275–281`).
   Both are published path sets.

## 2. What stands, and is now on the record

1. **The obligation, stated as a game with its three cases kept apart** — (a)
   no history, one opening; (b) prior history, one opening; (c) more than one
   opening — and the fact that (c) is dead at this geometry by a proved
   recovery, so every widening, chain and retry path must keep one opening per
   commitment, **which a verifier cannot check from the bytes**.
2. **In today's code the committer is the prover.** `Endpoints` cannot leave
   the process (`zk_ffn_fresh_io.rs:103–120`); an owner is non-`Clone`,
   consumed by value, never built from a seed, never imported or serialised;
   three `compile_fail` doctests guard it; the check confirmed this on every
   code path. **So for every artifact that exists today the caller-fixed-root
   scenario does not physically arise**: the right game for them is the
   standard one in which the simulator produces the commitments, and the
   joint-view evidence of 2026-09-19 speaks to that game. D8/D11 bite the
   *product configuration* in which someone other than the prover fixes a
   root.
3. **The two-point simulator has no ordering problem** (correction 21, in the
   draft's favour): the programmed point is the tree's top node, independent of
   the 256 column indices, which are drawn only after the group and proximity
   vectors are absorbed (`pcs.rs:922–928`). That is the clearest reason to
   prefer this shape over the round-23 free-handle construction.
4. **The hash layer counted, and reproduced exactly by the check**: at 2,048
   leaves, 240.7 distinct opened leaves and 1,654.8 of 4,095 nodes revealed;
   at 65,536 leaves, 255.5 and 4,154.7 of 131,071; one programmed point per
   endpoint root; the top pair revealed with probability `1 − 2^-255`.
5. **Separately finished private proofs cannot be chained through a
   commitment root** (check §5.5): the upstream receipt already contains a full
   opening of its output commitment, so a downstream proof consuming the same
   root is a second opening (case c, D12 item 1), is also prior history, and is
   unimplementable today. **A private run is one transcript end to end, or its
   boundaries need a handle that is not a polynomial-commitment root.** This
   binds the block-chaining design (`ZK60_PRIVATE_BLOCK_FORM_E.md`, under its
   own check): runs of blocks under one transcript are fine *inside* the run;
   the boundary *between* two runs is exactly the forbidden root.
6. **The priced alternative: a caller-fixed salted handle** (closure ii) — the
   caller fixes a salted hash of the plane, as the zkVM line does under D7;
   the proof's own commitment is fresh and prover-generated; the proof shows
   the two agree. It closes all three cases. Cost, corrected by the check
   (correction 11): **about +5.5% on the public pass and +12.6% on the private
   one** [COUNTED, a factor-two band, no gadget exists yet] — a relative cost
   that scales with the pass, not "60–160% of the 5-second budget". No cheap
   algebraic handle is known, but the two impossibility arguments offered were
   wrong as reasoning and are withdrawn (corrections 12, 13).
7. **A concrete hazard for any future proof** (hole 5): the Fiat–Shamir
   transcript and the Merkle and leaf hashes **share one untagged 64-byte
   BLAKE3 input domain** (`transcript.rs:44–52`; `absorb_u64(b"log-cols", …)`
   is a 64-byte input, at `private_seam.rs:253`, `private_block/protocol.rs:43`,
   `private_attention/protocol.rs:38`). No attack follows and the bound does
   not move (`2^-256` per candidate point), but an argument that programs the
   oracle for privacy must be composed with the soundness reduction over that
   same table. Domain separation would move every digest, so it belongs to the
   next statement version, not to a patch.
8. **Code-level invariants worth asserting** (condition 28), for Codex:
   a seam commitment's row count is never 5 or 8 (today it is always one of
   6, 7, 9, 13, 21); no deployment-path commitment is reproducible from a
   seed; and **no new accessor may expose `PreparedPlane`'s `CommittedZk`,
   whose `data`, `pads` and `salts` fields are `pub`** (`pcs.rs:551–564`).
9. **D9's figures stand** (correction 19, confirmed independently): total
   statistical distance `2^-96` per draw, relative per-outcome bias `2^-64`;
   the document that states it wrongly is O10's finding F10.4, and the two
   source comments (`rng.rs:72`, `transcript.rs:96`) should say both numbers.

## 3. The question this turns into, for Victor

**Who fixes the commitment to a hidden input — the prover, at the moment it
proves, or someone else, in advance?**

- **If the prover does** (what every artifact does today): the commitments are
  first published with the proof that consumes them. The privacy notion is the
  standard one; D8/D11's scenario is excluded by the design of the product,
  not by a theorem; and what a regulator holds is a receipt saying "the
  approved model ran on *some* hidden input and produced *some* hidden output,
  both sealed here". Anyone later given the input and its randomness can check
  it against the seal.
- **If someone else does** (a regulator seals an input today and asks for a
  proof about it tomorrow): that party holds the randomness, the simulation
  argument excludes them, and the sealed handle must not be a
  polynomial-commitment root. The salted-handle route of §2.6 is the known way
  to do it, at roughly +13% on the private pass, and it needs a hashing gadget
  that does not exist yet.

My recommendation: **the prover fixes them for the first MVP** — it is what is
built, it needs nothing new, and D13 already scopes the MVP to the hidden
blocks — **and the sealed-in-advance case is recorded as the next milestone's
requirement**, with the salted handle as its construction. The same handle is
what chaining separately finished proofs would need. This does **not** close
D8 or D11; it says which product they bind.

## 4. What I reviewed myself, and what was delegated

I read the check's hand-back report, its chaining section (§5.5) and its
complete table of holes, corrections and conditions, and the draft's hand-back
report. I verified the D9 arithmetic myself with exact integers before the
check confirmed it. I did not re-derive the simulator, the hash-layer counts or
the enforcement audit. Both documents were produced by delegated Opus agents,
the second instructed to assume the first had a hole. **Nothing here
establishes a privacy property**, and even with every listed item fixed the
following stay open: D8 and D11 themselves; the joint conditional field sampler
and the joint hypothesis (U-3); a whole-view bound that will always be a
computational, programmable-random-oracle statement with a five-item assumption
list; one opening per commitment at model scale; and everything outside the
hash and linear-field layers — the nonlinear cross-channel link, integer-range
side information, timing, the adaptive and distributional lift.

## 5. Next steps

1. Put the question of §3 to Victor as a one-page ruling (proposed D18).
2. Apply the check's 11 corrections to R and re-title it as what it is: a
   statement of the obligation and a costed survey of closures, not a
   recommendation — holes 1–10 recorded in place.
3. Carry §2.5 into the disposition of the form-E draft when its own check
   reports.
4. For Codex, when convenient: the invariants of §2.8 and the two source
   comments of §2.9.
