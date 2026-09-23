# Adversarial check of `ZK60_HASH_LAYER_STANDALONE_TAGGED_BLOCK.md`

> **Independent check, written 2026-09-23 08:52–09:2x PDT** (`date` read at
> 08:52 and 09:15) by a delegated Opus 5.5 agent told to break the draft, not
> to agree with it. Under attack: the draft at `05b9525` / `f0a5695` and its
> script `results/zk60_hash_layer_standalone_block/`. Read-only: the lane
> `/home/victor/wt-zk60-block125m` at **`544fbaf`** (source tree clean), the
> gate branch `/home/victor/wt-zk60-jointview` (ledger §R9j), the four real
> standalone bundles. **Nothing was built, proved or benchmarked. Not a
> privacy acceptance and not a privacy claim** — D22 (the toy) is still the
> only statement in force.

| | |
|---|---|
| Method | one new exact-arithmetic script, `results/zk60_hash_layer_standalone_block_check/check_standalone_block.py` → `check_standalone_block.json` (exit 0). It **re-implements the block geometry from the Rust** (`shape.rs`, `layout.rs`, every `tr.challenge_*` in `argument.rs::define`) and never reads the draft's script or its pinned models; the draft's JSON is read only at the very end, for a figure-by-figure comparison |
| Controls that pass | **all six shapes of lane stage 36 reproduced exactly** from the code — block-stream `fp()` draws, salts, stream bytes, live squeezes, replay points, frame bytes, endpoint draws (toy, rung-K4, rung-P2, rung-C6, rung-W14, rung-E32) — plus the toy's 317 absorbs (row T3) and 327,052 draws (D9 / D22) |
| Real bytes read | the four `receipt.bin` / `block.json` / `expected.bin` of R9j.1: frame length, **every one of the 1,280 opened columns per bundle re-hashed and authenticated to its root under the profile's own keys** (Python `blake3`, keyed mode), the 40-byte envelope binding **recomputed from the public header words**, salts and indices compared across the five trees |
| Labels | **CONFIRMED** = re-derived here by a different route and it agrees; **CONFIRMED-WEAKLY** = read and reasoned, not re-derived; **REFUTED**; **UNVERIFIABLE** |

## 0. Endpoint verdict (first rank): no counterexample

**I found no way in which opening both external endpoints in one proof —
including in the all-zero world, where Input and Output commit identical
planes — correlates the two openings or lets the joint view tell the worlds
apart beyond the per-commitment argument.** S-3 is **CONFIRMED** as an
argument, conditional on exactly what the draft names (E-1 / J-2 for the
three OS reads, M-3 for the streams, D19b for the keyed functions). The
attack, item by item, at `544fbaf`:

| shared thing? | what the code does | evidence |
|---|---|---|
| the generator | each endpoint makes its OWN `ZkRng::from_os`, and the block stream is a third one; the three domains differ in the role byte **and** — at a block — in the spec digest too (Input's slots 41/42, Output's 43/44) | `endpoint_g.rs:269`, `:83-85`; `private_block.rs:956-957`, `:1075-1076`; `hash_domain.rs:207-213`, `:240-249`; `protocol.rs:813` |
| salts | drawn per commitment from that commitment's generator | `zkp-core/src/pcs.rs:778` via `endpoint_g.rs:280` |
| pads and reserved rows | per commitment, per row, from its own generator; the five reserved rows filled with fresh `fp()` | `endpoint_g.rs:276-278`; `pcs.rs:777` |
| reserved claim pair | each endpoint carries exactly ONE claim, on its OWN rows `(data, data+1)`; same row *index* in two different matrices, independent contents. (The run's shared-pair counterexample needs two claims on one commitment; a block never has that) | `protocol.rs:379-384`; `layout.rs:1139`; `argument.rs:751-753` |
| column / leaf / node keys | the SAME three public keys for all five trees, by design; Lemma H prices cross-tree coincidences inside `C(N_leaf,2)·2^-256` with `N_leaf` summed over all five trees | `hashtag.rs:92-101`; `pcs.rs:793-798` |
| any other blinding source | none; the only shared object is the public transcript (lambdas, proximity coefficients and indices of each opening) | `protocol.rs:820-827`; `pcs.rs:1023-1052` |

**Measured on the real receipts** (this check's parse, `bundles` in the
JSON): on all four bundles every published salt belongs to exactly one leaf
position (1,244 / 1,240 / 1,270 / 1,267 distinct salts = distinct positions,
**0** shared across positions or trees); where Input and Output happen to open
the same column index (23, 14, 0 and 2 indices) **no column and no reserved-row
segment is identical**; in the two all-zero bundles the opened data rows of
both endpoints carry **no zero field word** (1,960 and 16,352 words) — the
pads, not the plane, are what a verifier sees; Input root ≠ Output root on all
four. None of this is a proof; each is a place a real correlation would have
shown.

**Why identical planes do not matter to the hash layer.** Lemma H^run's
conclusion is conditioned on "the unopened columns themselves" (run memo §3.2):
the salted leaf `F_L(d ‖ s)` is fresh because `s` is, whatever `d` is. Two
trees committing the same data therefore look exactly like two trees
committing different data, off the salt-guessing and leaf-collision events.
**One structural remark the draft could add (F-10):** before stage 26 the two
endpoint generators had byte-identical domains, so a total E-1 failure
(identical OS reads) would have given **identical roots** in the all-zero
world — a perfect "input = output" distinguisher. At `544fbaf` the domains
differ in two fields, so equal roots would need a keyed-BLAKE3 collision.

**What gate round 9j covers here, and what it does not.** *Covers* (MEASURED,
at the bundle's fixed challenges, linear channels): each endpoint's own field
view discloses 0 (`rank_P1` 4, 5 non-data rows); the whole block's linear
system, **with each endpoint's 32 data rows identified with `A`'s IO plane
rows** (64 identified rows at 125M), discloses 2 = the sum (H's public LogUp
identity) — so no linear functional of the two openings together, or of an
opening together with `A`, reaches the witness; the full and joint preimage
arms re-hash the 1,024 / 1,280 opened leaves for an alternative witness
(Lemma H step 1 on real bytes); control C3b shows the joint figure would rise
if `A@0` and `E-Input` shared a blinding row. *Does not cover*: the hash
layer's hiding (unopened leaves, sibling digests, roots — Lemma H steps 2–4,
ARGUED; R9j.12 item 2 says so), whether the three generators' outputs are in
fact independent and uniform (the gate models distinct blinding symbols as
independent — E-1 / M-3 are assumptions, not measurements), the joint LAW
beyond linear rank (Theorem B's per-stage part), the dependence of the
challenges on the roots (Route A), refusals, timing (D20), and it never sees
a witness (R9j.12 item 3). There is **no C3b-style control for an
`E-Input` ↔ `E-Output` shared row** — the pair this attack is about (F-8).

## 1. Findings, ranked

No finding is blocking. No figure of the draft is refuted.

**F-1 — erratum (minor): S-5(b)'s reason for keeping D21 is incomplete.**
D21 forbids transmitting *rejected receipts*, not only refusals. The block
prover makes **no output-equality check**: "No equality precheck: an endpoint
committed to other values must fail the verifier's polynomial identity"
(`protocol.rs:770-771`); "`output` is whatever the owner fixes; a value other
than the block output makes every later proof fail verification"
(`private_block.rs:1053-1055`). So a mis-sealed Output endpoint yields an
*assembled* receipt that the verifier rejects, and whose view depends on the
hidden data: slot 22 is `Standalone` (`layout.rs:886-909`), its published
scalar asserts a zero sum, and its masked rounds are computed from tables whose
sum is `Σ eq(τ,·)(A_X2 − E_out) ≠ 0` — the round-one check fails by exactly
that amount. "A refusal returns before the `Receipt` is assembled"
(`protocol.rs:831-840`) does not cover that case. **Fix:** say that D21 is kept
by (a) — sealing both endpoints with the witness builder's own pass makes every
assembled honest receipt verify (completeness) — or by a verify-before-transmit
step at the production entry; drop "because a refusal returns …" as the reason.

**F-2 — erratum (minor, label): §3.1's "the number of transcript operations
… now MEASURED at 125M".** What is MEASURED dense = zero is the squeeze counter
(14,252 / 2,356), the challenges and the gate's 127 checkpoint positions.
Absorbs are not observable at all (lane finding S36-F1, ledger lines
11846-11854; `transcript.rs:198-203`); 495 / 376 are COUNTED. This check
re-derives them from the code (and reproduces the toy's 317), so the figure
stands; the word "MEASURED" should be limited to the squeezes.

**F-3 — note: the rung-K4 anchor row.** 765,388 is a SUM — 750,540 measured in
situ + 2 × 7,424 measured on the replica — which no earlier document carries
(§3 below). The draft's parenthesis says "endpoints on the replica"; label the
cell "sum of MEASURED parts".

**F-4 — note: one-sided and two-world figures side by side in §1.** H^blk's
2^-72.86 / 2^-76.58 is the distance to *a* witness-free view (one-sided, as
D9 / D22 state their figures). The distance between the real world and the
honest all-zero world is **twice** it, 2^-71.86 / 2^-75.58, by Route A's own
last hop (`G_8′ → G_0′`, "undo in the zero world — the same bounds"). The same
paragraph quotes the LogUp term in its **two-world** form (2^-117.4). The run
memo named this trap for S-4 (its B-12c); name it here for the sampler term
too. (Inherited, not the draft's: the run memo's displayed inequality in §5.2,
`d(view_w, view_0) ≤ 2·L·768/|Fp2| + ε_hash + ε_sampler`, carries
`ε_sampler` once for a two-world distance — one bit, no gap moves.)

**F-5 — note: S-1 understates the constructor's separation.** Both block
constructors (125M 48 B, rung-G 58 B) are **shorter than every absorb that
actually occurs on a block's path** — the shortest is `rows` at 60 B — so
inside `F_T` they are separated by length, not only by B10's content argument;
B10's 2^-128 remains a spare bound. (Other profiles differ: rung-W14 and
rung-E32 constructors are exactly 60 B, content-only there.)

**F-6 — note: the tag-key row's `m` is a convention.** 28 = 7 tagged
registered block profiles × 4 contexts is right (recomputed here with Python
`blake3`: pairwise distinct; also with rung-K8's four, and with the seven run
profiles' would-be sets — 60 keys, all distinct). But a test build admits
unregistered profile strings (`shape.rs:186-189`) and anyone can derive keys
for any string, so "keys in existence" has no canonical value; the row is
zero by test for the keys the product uses. The proposed register edit
(2^-251 → 2^-247.44) is cosmetic. Stale doc comment: `s24_tests.rs:151` still
says "twelve keys in this lane" (the assertion itself is registry-driven and
right).

**F-7 — note: N12's evidence and D20.** The 125M all-zero proof time the
draft cites (20.10 s) sits beside 28.12 s for the dense witness in the same
stage-45 table (lane ledger line 13766; one run each, unquiesced box). That is
a timing channel, excluded by H^blk (D20) — one clause would stop a reader
from taking "the ideal world is runnable" as "its cost is input-independent".

**F-8 — note, for the gate owner.** Add a C3b analogue that makes one reserved
row of `E-Input` and one of `E-Output` the same unknown. The honest code makes
it moot (separate generators), but it would show the joint figure's power on
exactly the pair the all-zero-world worry is about.

**F-9 — note, for the lane, outside this page.**
`s24_tests::no_registered_profiles_constructor_input_has_the_squeeze_length`
(`s24_tests.rs:354-398`) pins all nine block profiles but only three of the
seven run profiles; the other four are 57–58 B (computed here), so nothing
collides with 47, but they are not pinned.

**F-10 — note:** the structural backstop of §0 (pre-stage-26 identical
domains ⇒ identical all-zero roots under an E-1 failure) is worth one
sentence in S-3, which currently credits the role byte alone; at a block the
spec digests already differ.

## 2. Verdict per claim

| # | claim of the draft | verdict | how |
|---|---|---|---|
| 1 | per-proof `fp()` draws **9,212,588** (125M) / **701,876** (rung-G), COUNTED; `A` 5,484,800 / 411,392, `H` 3,526,654 / 258,046, `M` 18,350 / 17,590, each endpoint 91,392 / 7,424 | **CONFIRMED** independently | geometry re-implemented from `shape.rs` / `layout.rs`; the same model reproduces six stage-36 measured block streams exactly; the gate's per-commitment blinding unknowns and R9j.8 B11's 5,484,800 agree |
| 2 | `M`'s `ΣL_s` = 1,239 (125M) / 859 (rung-G), `H`'s two zero-sum rows `2(n−1)` | **CONFIRMED** from the Rust, not from the pinned identity | per slot `(main+ext)·degree + 2` from `Shape::slots` (degrees include the S19-F1 group `eq` and the pad indicators); largest `L_s` 117 at slot 17, as `shape.rs`'s C-4 comment says; `protocol.rs:1118-1126` |
| 3 | sampler term **2^-72.8648 / 2^-76.5791** (D9) | **CONFIRMED** | exact per-draw SD `r(p−r)/(p·2^128)` = 2^-96.0000000003 (< 2^-96), summed; D9's accepted reading (register lines 403-417) |
| 4 | salt guessing **2^-109.98 / 2^-113.68** the largest hash-layer term; gap **37.11 / 37.10** bits; every row of §3.3 | **CONFIRMED** (arithmetic); the term *list* **CONFIRMED-WEAKLY** | all ten rows recomputed exactly; the list is Lemma H^run's as ruled — I checked that a block adds no new input class to `F_T`, `F_C`, `F_L`, `F_N` or `F_U` (every unkeyed call site on the path grepped: calibration 30 B, spec digest 142 B, public digest, schedule digest, refill 40 B) and that the inner nodes need no term of their own (run memo §3.3 step 3: `T` is public once the leaves are uniform) |
| 5 | transcript queries **14,748** = 495 absorbs + 14,252 squeezes + 1 / **2,733** = 376 + 2,356 + 1 | **CONFIRMED** independently | squeezes re-derived from every `tr.challenge_*` of `argument.rs::define` (**446 / 325** slot-definition draws, per slot in the JSON), matching the gate's measured counter **exactly**; absorbs from the code (5 + 3 + 1 + 3 + 3·23 + rounds + 2 + groups + 6); the refusal replays (`protocol.rs:326`, `:388`) re-issue the live points exactly (a clone carries state, counter and key, `transcript.rs:156-162`), so they add no new point |
| 6 | 264,970 / 19,236 leaves hidden by their salts alone (dense), from 1,270 / 1,244 distinct opened | **CONFIRMED** | distinct opened columns counted from the parsed receipts: 1,270 / 1,267 / 1,244 / 1,240, the gate's figures |
| 7 | refusal on an admissible witness 2^-117.4 (two-world S-4), liveness 4/p = 2^-62.0 | **CONFIRMED** (arithmetic); the 768 bound **CONFIRMED-WEAKLY** | 4 determinant checks (`A`, `H`, two endpoints; `M` has none); 768 is ruling S-4's, not re-derived |
| 8 | tag-key collision 2^-247.44 with 28 keys at `544fbaf` | **CONFIRMED**, with F-6 | 28 keys recomputed with `blake3.derive_key`; the four contexts are `hashtag.rs:48-54`; distinct |
| 9 | the five-absorb header under the block profile; the 40-byte envelope = the `F_T` state after it, compared and never absorbed | **CONFIRMED** independently | the binding recomputed from the public header words on all four bundles and equal to `receipt.bin[8:40]`; my parameter line, calibration identity and schedule digest (from `layout_description`) equal the capture's; only the public-statement digest is taken from `block.json` |
| 10 | carries over (§2.2): Lemma H steps, N1/H-3, N5, N6, N7, N11, N12, the B-rows, C-R4 / C-R5 | **CONFIRMED** | every `file:line` of §2.1–2.2 read at `544fbaf` and found as cited |
| 11 | drops (§2.3): position tags, boundaries, GS-7, the run header's extra words, the run statement file, M-9 → D21, R-1, C-R3, J-5 | **CONFIRMED**, with F-1 on M-9 → D21 | the run header's `run-shape` (L and six dims, `run.rs:431-435`) is the only word a block lacks, and the block's `parameters` line binds the dims; nothing else the run header bound is needed at L = 1 |
| 12 | S-3, both endpoints in one proof | **CONFIRMED** | §0 |
| 13 | S-5, no production caller of the shaped entries | **CONFIRMED** | non-test callers of `prove_inner_at` / `verify_inner_at` are the toy's only (`protocol.rs:780`, `:1331`); `verify_bytes_at` / `to_bytes_at` are reached only from `#[cfg(test)]` modules (`block_capture_shaped` is itself `#[cfg(test)]`, `private_block.rs:326-327`) |
| 14 | §5, the exact dependence on D19b | **CONFIRMED-WEAKLY** | reasoned: publishing the envelope state adds nothing, because every `F_T` state is recomputable from the public view (this check recomputed one); D19b's use is the keyed functions under public keys, as stated |
| 15 | rung-K4 anchor 765,388 "MEASURED" | **CONFIRMED** as a sum, with F-3 | §3 |
| 16 | the §3.1 statement that the number of transcript operations is MEASURED equal dense / zero | **CONFIRMED** for squeezes, **REFUTED** as worded for absorbs | F-2 |

**The draft's own JSON, compared after the fact:** every figure I recomputed
(draws per commitment and per proof, salts, absorbs, squeezes, slot-definition
draws, `A`, sampler, salt guessing, gap) is **equal** at both shapes.

## 3. The 765,388 vs 750,540 discrepancy — resolved: two scopes, no conflict

* **750,540** is rung-K4's **block stream**: the `fp()` draws of the ONE
  generator `prove_inner_at` makes (`A` + `H` + `M`), MEASURED in situ by lane
  stage 36 (`z36-pinned.log`; ledger table at lines 11769-11772, "block stream
  B / `fp()` draws"). It is claim A-5's rung-K4 row (ledger lines 11797-11800)
  and ruling H-6's "per block 750,540" (run disposition §2).
* **765,388** = 750,540 + **2 × 7,424** = the **per-proof** count over all
  three generators. The endpoint part (14,848) was measured on a **replica**
  of `endpoint_g::prepare`'s draw sequence (finding S36-F2, ledger lines
  11856-11869), not in situ. The sum appears in no document before the draft.
* **It is not a different profile, tagging, stage or block-vs-run.** My model at
  `544fbaf` gives 750,540 exactly with the post-S19-F1 schedule (slots 08 / 09 at
  `lkv = 2` extra main rounds and degree 3); stage 36 (2026-09-22) is after the
  S19-F1 repair (stage 20), and the gate's reading of stages 38-45 found
  `argument.rs` +6/-0 (test hooks only) and `Shape::slots` untouched (R9j.6).
  The tag does not move a draw (`pcs.rs:756-758`).
* Figures: per proof 2^-76.4542 (the draft's), block stream alone 2^-76.4824.

## 4. What I did NOT check

1. Lemma H^run, Route A^run, Theorem B and ruling S-4's bound of 768 — taken as
   ruled; only their specialisation to L = 1 was attacked.
2. The field view (rank, CFS) — the gate's; I read its ledger, not its code.
3. The generators themselves at rung-G / 125M: my counts are derived from the
   code and validated on six other measured shapes, not measured at these two.
4. The public-statement digest (taken from `block.json`, so the envelope
   recomputation depends on that one word); the frozen seam's own draw code
   (`private_seam.rs`, the toy's endpoint 3,072 is taken as the control target).
5. D19b's model question (Victor's), timing / memory (D20), the device path.
6. Anything about witnesses: the bundles carry none.

## 5. Evidence

`python3 results/zk60_hash_layer_standalone_block_check/check_standalone_block.py > …/check_standalone_block.json`
— exit 0, `ALL_CONTROLS_AND_CROSS_CHECKS_PASS: true`, a short CPU-light
foreground run (it hashes the 1,280 opened columns of each of four receipts;
the 125M frames are 40.8 MB each). Needs the Python `blake3` module (1.0.9 here) for the hash checks;
without it the counts still run. **Not a privacy acceptance.**
