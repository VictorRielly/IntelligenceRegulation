# The D19 hash tag for new profiles — disposition of the scoping memo

By the interactive Claude Fable 5.1 session (the security owner), 2026-09-20,
14:14. It rules on `ZK60_D19_HASH_TAG_SCOPING.md` (a delegated Opus agent's
read-only memo of the same day; it ran nothing and says so). Decision D19
(Victor, 13:45) obliges a separating hash tag in every new profile; this page
says what the tag is, where it goes, who writes which part, and what I checked
myself.

## 1. What the memo established, and what I verified myself

- **The hashing sits in the integrator's files.** The transcript
  (`zkp-core/src/transcript.rs`), the Merkle tree (`zkp-core/src/merkle.rs`),
  column digests and salted leaves (`zkp-core/src/pcs.rs`) and the masking
  commitment's tree (`hashline/src/zk.rs`). The lane cannot tag anything
  without an additive change there. [memo, COUNTED]
- **The one length overlap is at every shape, not only the toy**: absorbing
  the word `log-cols` makes a 64-byte hash input (32 + 8 + 8 + 8 + 8) because
  that label has eight characters — the length of a Merkle node and of a
  salted leaf. No column digest meets a transcript length at any of the four
  shapes. [memo, COUNTED]
- **The lane's length guard is incomplete.** It refuses commitments of 5 or 8
  rows. With today's labels, 11, 12, 13, 15, 17 and 19 rows are dangerous too
  (and 6 at the 125M shape, 7 at the rung). The generalised endpoint has 9
  rows and the boundary 10, so the next geometry is near the gap. [memo,
  COUNTED]
- **`pcs::verify_zk` does not check the length of a Merkle path.** I read it
  myself: `zkp-core/src/pcs.rs:1019` hands the path to
  `MerkleTree::verify_path` (`merkle.rs:56-63`), which folds however many
  siblings it is given. **The private block cannot be reached through this**:
  I read `private_block/wire.rs:178-193` — the number of path entries is read
  from the layout, never from the receipt, so a shorter path cannot be
  written down. Whether the integrator's other wire formats fix it the same
  way, I have not looked.
- **Why that matters, concretely** [ARGUED by me, 14:14, checked by nobody]:
  a salted leaf is `blake3(column digest ‖ salt)` and an inner node is
  `blake3(left ‖ right)` — the same function on the same 64 bytes. So an inner
  node one level above the leaves verifies as the salted leaf of any column
  `c` whose digest is its left child, with its right child as the "salt",
  under a path one entry shorter, at the two column indices congruent to its
  position. I worked the 8-leaf case by hand and then ran it
  (`results/zk60_d19_hash_tag/short_path_demo.py`, a line-for-line mirror of
  `verify_path` with SHA-256 standing in for BLAKE3, since the point is the
  structure and not the hash) [MEASURED, 14:15]: column index 1 opens to its
  genuine column with a 3-entry path **and** to a planted alternative column
  with a 2-entry path; index 5 opens to the same alternative; index 2 can no
  longer be opened; with the length check both short openings are refused. A
  prover whose wire format lets it choose the path length
  can therefore plant alternative columns. My rough look at one family of
  attacks says this does **not** beat the accepted per-opening figure (each
  planted node makes another position unopenable, and I get at most about
  (2/3)^256 against the accounted (3/4)^256) — **but nobody has analysed it,
  and it is a binding gap in principle.** It disappears with a one-line check
  (`path.len() == log_cols`, which rejects no honest proof and moves no byte)
  or when leaves and nodes are hashed under different keys.

## 2. Rulings

**T-1 — the tag is BLAKE3's keyed mode, four keys per profile.** One fixed
public 32-byte key for each of: the Fiat–Shamir transcript, column digests,
salted leaves, Merkle inner nodes. Each key is
`blake3::derive_key(<context string>, <profile string>)`, with four distinct
context strings carrying the date of this ruling. Reasons: BLAKE3's own design
makes its modes separate functions; the key replaces the initial value, so a
64-byte node still costs one compression (a one-byte prefix would make it
two); the profile string is already unique per shape (D17), so two profiles
can never share a key and the obligation cannot be forgotten; the generator
already uses keyed mode, so it is an existing idiom. The legacy rule — no key
anywhere — is the literal present call and stays the default.

**T-2 — coverage.** The generalised rung, the 125M block and the multi-block
run are tagged completely. The **toy is never tagged** (byte-frozen; D19
records its deviation; D22 rests on those bytes). The **frozen-seam rung**
gets a keyed transcript and keyed `A`, `H` and masking commitments, and its
endpoint — committed inside `private_seam.rs`, which stays byte-identical to
`11c01b2` — keeps the legacy rule. That is the one named exception, and **that
profile is barred by name from any privacy statement**; the generalised rung
exists to replace it.

**T-3 — the length guard is completed on the lane now** (lane-only, no shared
file): the hard-coded set becomes a shape-driven check that rebuilds the
profile's transcript input lengths (constructor, label table, the 47-byte
squeeze, the generator's 40, the node/leaf 64) and refuses any commitment
whose column length lands on one, by name. It stays on for the toy, where it
is the only separation there is, and for tagged profiles as a second line.

**T-4 — the path length is checked on the lane's side as well, now**: before
any opening is verified, every path has exactly `log_cols` entries, with a
test that a receipt structure carrying a shorter path is refused. The finding
goes to the integrator for its own wire formats.

**T-5 — who writes the shared part.** The integrator's conditions of 00:26
allow a needed shared-file change as its own reviewable commit. The change is
purely additive: a new file `zkp-core/src/hashtag.rs`; one field and one
constructor on the transcript with two one-line substitutions; keyed variants
beside the Merkle, column, leaf, commit, verify and mask-commit functions.
**Tighter than the memo: the old functions keep their bodies, untouched — no
forwarding through the new ones** — so "old callers are byte-identical" stays
a fact about unchanged text, and a merge with the integrator's in-flight work
touches as few lines as possible. A tagged commitment declines the
accelerator (one line in the new function); `gpu/*` is not touched. The
proposal is put to the integrator first; if it would rather write it, it
writes it; if it agrees or is silent through the lane-only stage, the lane
writes it as separate commits and lists them at hand-back.

**T-6 — the tests of memo §6.4 are all required**, and the cross-rule
rejection in both directions is the one that matters most: it is what makes
the tag load-bearing rather than decorative. The key values are pinned as hex
literals so the Python tools can be checked against the same numbers. The
Python run gate must learn the rule before any tagged capture is judged; until
then tagged bundles are not gate evidence.

## 2a. Amendments after the integrator's review and the lane's stage 16 (15:01, 2026-09-20)

The integrator read the scoping memo and answered at 14:22: the lane may write
the additive change, the five shared files and the new `hashtag.rs` with its
`lib.rs` export included, as separate reviewable commits with the legacy
branches preserved; integration and the keyed CUDA path stay with it; **this
is engineering ownership, not its acceptance of the argument.** It made four
review points. I accept all four, and two of my rulings change because of
them.

**T-1, wording corrected.** "Two profiles can never share a key" was wrong:
key derivation is a hash, so distinct profiles or roles share a key with
negligible probability (a collision in `derive_key`), not never. **The model,
stated explicitly:** for a tagged profile, decision D19's random oracle is read
as a *family* of independent random functions indexed by BLAKE3's mode and
key — the four keyed functions of a profile, the generator's keyed function
under its secret key, and the unkeyed function the legacy rule uses. That is
BLAKE3's own design claim for its modes; it is an idealisation like the rest
of D19, and it is what "separating hash tag" means in that model. "No extra
compression" is a count, not a timing: the run time is re-measured.

**T-2, changed: no mixtures, so the frozen-seam rung stays entirely on the
legacy rule.** The integrator's point — never a partial mixture of legacy and
tagged modes — is right, and my earlier T-2 (keyed transcript and block
commitments, legacy endpoint) was exactly such a mixture. The frozen-seam
development rung therefore keeps the legacy rule as a whole. It is a
stepping-stone fixture, never a deliverable, **barred by name from any privacy
statement**, and the generalised rung replaces it. Recorded as a scoping note
under D19 in the register, and reported to the project owner as what it is: a
development fixture outside D19's obligation, not a tagged profile.

**T-3, changed: the completed length guard applies to legacy-rule profiles
only** (the toy, the frozen-seam rung). Stage 16 showed why (its finding
S16-F1): the completed guard refuses geometries the constructions really
reach — a generalised endpoint of 13 rows, a boundary of 12 — and the run's
own parameter line sits two bytes from a boundary column's length at the 125M
shape. On a tagged profile those coincidences are between *different
functions* and mean nothing, so the guard is not imposed there. It stays on
for the toy, whose accepted geometry it already passes.

**T-6, changed.** A full-profile mismatch may be refused by Fiat–Shamir
consistency before any Merkle check, so the cross-rule tests require
**rejection in both directions, whatever the first refusal is**, and the
layers are identified by **isolated controls**: a column digest, a salted
leaf and a Merkle node each computed under the right key, the wrong key and no
key, all pairwise different.

**T-7, new: the key set is never an input.** The tag type is opaque: it is
either the legacy rule or the complete key set of one profile, built only by
`legacy()` or `for_profile(<profile string>)` — no public fields, no partial
sets. The verifier derives it from the profile it trusts; nothing in a receipt
or a capture selects or carries keys (a capture may *name* the rule for the
Python tools, which re-derive the keys themselves and compare). The mode is
carried through every endpoint, boundary, masking tree and transcript clone,
**the run's position tags included**.

**T-8, new: the accelerator.** A tagged commitment declines the unkeyed device
hasher. That is a **temporary CPU fallback, recorded as such** — not a
performance result and not accelerator support; the keyed device path is the
integrator's, later.

**The path-length check (T-4) landed in stage 16** (`f67f3fc`, pushed; filter
208 passed, none failing; no shared file touched): before the fix a truncated
path was refused only deep inside the core verifier, as a Merkle mismatch
after hashing; now the lane refuses it by name before any hashing, from the
same single source of depth the wire format uses.

## 3. What this is not

Not a privacy or soundness acceptance of anything. It changes nothing in D22.
The tag moves the proof bytes of the rung, the generalised rung, the 125M
block and the run once; receipt sizes do not change (the wire format carries
no tag); the two run captures are re-taken afterwards. The 125M timing is not
expected to move (no extra compressions) and will be re-measured, not assumed.
