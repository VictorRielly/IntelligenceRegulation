# The law of the blinding (gap G-R4) — disposition

By the interactive Claude session acting as security owner (Opus 5.5,
continuing the Fable 5.1 lane), 2026-09-23, 16:38 PDT. It rules on
`ZK60_BLINDING_LAW_GR4.md` (a delegated agent's draft, `0ae7d61`) after
`ZK60_BLINDING_LAW_GR4_CHECK.md` (an independent agent told to break it;
review branch `zk60-private-block-125m-review` at `cfcf7cd`, with Rust
mutation runs and a new test-only check `gr4_check_tests.rs`).

**Not a privacy acceptance of anything.** D22 (the toy) stays in force; §3
says what the check's F-1 means for the toy's wording and what is owed to
confirm it.

## 1. What survived the attack

- **The draw discipline** (ARGUED, independently re-scanned): 17 draw lines,
  every enclosing bound a shape / layout / spec constant or the run's k and
  L; no draw under a loop whose trip count depends on hidden data. **No
  refusal after the first generator draw reads a drawn value**; the
  dependent-proximity refusal (`protocol.rs:305-310`) reads challenges from
  a transcript clone (`:326-327`), not generator draws.
- **The residuals** recomputed exactly by counting preimages: 2^-77.680839
  (toy), 2^-72.864825 (125M proof), 2^-69.290633 (125M run, L = 12); the D9
  reading is right.
- **The draft's §5.7 finding is real on the Rust:** stage 36's assertion-6
  value scan skips `*x = rng.fp();` lines and never sees α, so three
  mutations the checker put into production source in its worktree (m1 A's
  reserved rows copied, m2 into H, m4 an α coefficient copied between slots
  inside `zk::mask_commit_tagged`) all left the lane's assertion-6 test, the
  six-shape count test and the toy / rung-G receipt checks GREEN (restored
  afterwards; `git diff` empty; nothing mutated committed).
- **The strengthened check exists and works** (`gr4_check_tests.rs`, review
  branch): it runs `prove_core` on a seeded generator, rebuilds A, M and H
  from the witness and the eleven predicted stream segments WITHOUT calling
  the commit functions, and requires the three roots and the byte count to
  match — green on honest code at the toy, rung-G and the run boundary under
  both hash rules; it fails on m1 (A root), m2 (H root), m4 (M root); it also
  MEASURES the draw order inside a block (measured nowhere before). The
  endpoints (not seedable) are checked in situ: all drawn values distinct.

## 2. Rulings

**LW-1 (F-1, blocking for the draft's wording) — restate the law.** The public
statement contains the two endpoint roots (`private_block.rs:1083`, absorbed
first at `protocol.rs:116` / `run.rs:436`), and each root is a hash of that
endpoint's draws; so "Ω independent of the public statement" is false as
written for the endpoint blinding, and `check_endpoints`
(`protocol.rs:761-762`) is a refusal reading those roots (certain to pass for
an honest caller — not a leak). **The law is restated over the public
statement WITHOUT the endpoint roots; the roots are part of the view and are
handled by the hash-layer assumption (H6)**, as the commitment roots of A, H
and M already are. The draft is revised accordingly (with F-3…F-8).

**LW-2 (F-2) — the strengthened check moves into the lane** as a test-only
stage: `gr4_check_tests.rs` with its three mutation proofs recorded; the
stage-36 assertion-6 scan is kept but documented as blind to `*x = rng.fp()`
lines and to α.

**LW-3 — cross-proof independence is a named assumption X-1**, stated beside
E-1 wherever a many-proof figure appears: every `from_os` entropy read in any
process is independent (no snapshot, restore or post-derivation fork of a
seeded state); M-3 holds for many instances (3K·ε_M3 over K proofs, one term
per generator — F-4: the per-proof generator term is 3·ε_M3, not ε_M3); each
hidden input is fixed before its generators are created; refused attempts
publish nothing. Without X-1 one repeated entropy read gives two proofs the
same blinding and the advantage is up to 1. X-1 is the standard assumption on
an operating-system RNG; it is recorded, not sent to Victor as a new ruling,
because D22's own scope note already assumes separate OS reads independent
("the generator means the proof's three generators jointly") — X-1 names the
many-proof extension of that sentence.

**LW-4 (F-6) — for the integrator:** `CfsMask` is `Clone` and `CommittedZk`'s
fields are `pub` (both in its files): a clone of a mask or a written
commitment field is a way to reuse blinding that no test forbids. Offered as a
note in the handoff, as the lane made `ZkRng` non-Clone.

## 3. What F-1 means for the toy (D22)

The checker notes that the toy memo's (H5) carries the same wording. The toy
is accepted as an argument whose steps each survived an attack; if its
hash-layer lemma (H6, `ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md`) already
counts the two endpoint roots among the hashed values it covers, the fix is
wording only. **Owed, before this page says so: a reading that confirms H6's
coverage of the endpoint roots at the toy** — done by the revision agent
dispatched with this ruling; until it reports, D22 stands as accepted and
this section makes no claim either way.

## 4. What stays open

The revision of the draft (LW-1, F-3…F-8); LW-2 in the lane; the §3 reading;
m3 on the Rust, anything at 125M, a `prove_run` replay and a seeded endpoint
replay (not checked).

## 5. The §3 reading (2026-09-23 16:52)

`ZK60_BLINDING_LAW_GR4_TOY_READING.md` (`bd04fde`): **verdict (i), covered —
wording only.** The toy's hash-layer lemma counts all five roots, both
endpoint trees included (`ZK60_HASH_LAYER_AND_FS_LIFT.md` §2.1 l.423,
`N_leaf = 12,288` l.561, the proof building every root from salted leaves
§2.3), and the lift puts the roots in the view (§3.1, §5.2 l.1311-1313). The
composition memo's "P includes the whole policy" and "three roots" (l.107,
l.1437) are wrong wording; a dated note on that memo points to T-1…T-8. The
run case was already written right (Lemma H^run's `4L + 1` roots). **D22's
sentence, figures and conditions are unchanged.** The reading also surfaced
that the privacy case's hypothesis **O-2** (an accepted receipt's endpoint
roots never registered or referred to by a later artifact; ask R-9) was never
listed in D22's statement nor put to Victor: now carried in the statement §6
as a hypothesis and proposed to Victor as **D23**. The G-R4 draft is revised
per LW-1…LW-3 (`bd04fde`); lane stage 47 brought the root-rebuild check in
(gates closing).
