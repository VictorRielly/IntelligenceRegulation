# O7 — the implemented FFN input/output binding, reviewed at `137b109`

| | |
|---|---|
| Reviewer | **Opus 5**, independent reviewer, 2026-09-08 session |
| Task | `ZK60_OPUS_QUEUE.md` O7 — implementation review of the consuming IO profile, read-only, eight concrete checks |
| Implementation pin | `137b109296d9a4cc9a05792bfdbd91aa45850abe` — "Reserve FFN equality masks in one commitment before all challenges", profile **`ffn-v3-mr1-fresh-io-poc/2`**, magic `HFFNIO\0\x02` |
| Superseded | `e8d4261` (`.../1`): same construction with the two equality CFS slots in a **second** mask commitment created during finalization. Its validation numbers describe that draft and are never used here to describe `/2` |
| Worktree | `/home/victor/wt-zk60-fa`, branch `zk60-fable-review`, HEAD `137b109296d9a4cc9a05792bfdbd91aa45850abe`, clean apart from my three new files |
| Baseline | O6 `ZK60_OPUS_SEAM_REVIEW.md` (`d130de6`, predictions made from source before this code existed), O5 `ZK60_OPUS_WIRE_REVIEW.md` (F1–F8), O3 `ZK60_OPUS_MASK_AUDIT.md` (twelve gaps), FA3, FA8, A03 |
| Verdict key | **pass** = the stated property holds in source at this pin · **unresolved** = not established here, needs Codex · **fail** = does not hold |

**Provenance of each verdict.** I reviewed `/1` first and then re-read every
changed file at `/2`. §2, §3, §5 and §7 were established on `/1` and
**re-verified line by line on `/2`**. §4 (the mask schedule) and §6 (the public
observations) are **new work on `/2`** — the draft's answer to both was
different. §8 (Codex's fixes to my O5 findings) is new. The only substantive
defect I found in `/1` — the second mask commitment — is the thing `/2` fixes,
so this review reports no open defect in the schedule.

## 0. Limits, stated first

- **Implementation review at one commit, not acceptance.** Codex owns the
  cryptographic judgment and the acceptance decision.
- **No privacy theorem is derived and no blocker is closed.** B1, B2, B5, A3,
  A4 are unmoved. O2's round-17 linear analysis covers
  `ffn-v3-mr1-fresh-poc/1` only; **it does not cover this profile**, and I did
  not extend the inherited rank model.
- §6 is an **enumeration of new public observations for a future analysis**. No
  IO capture and no joint IO analysis exists. It is not a disclosure verdict.
- Validation: the `/2` combined run's own marker
  (`/tmp/zk60-round18-final/validation.done`) now reports complete with every
  stage at its expected exit (§10). I report that as observed evidence, not as
  acceptance, and I state plainly where my own runs stop.
- No Rust was changed. Every test in §9 is a proposal.
- Function 2, stable-weight P3, attention, shapes other than T32/d16/f16 at
  `log_cols = 8`, and the provenance of the endpoint planes are out of scope.

## 1. Sources reviewed at this pin, with digests

| File | SHA-256 |
|---|---|
| `hashline/src/zk_ffn_fresh_io.rs` | `007affdb4ddfe68aaa1b9e880d663921d995ea03a9a08dab936ab65039631183` |
| `hashline/src/zk_ffn_fresh_io_tests.rs` | `2bfd11c709d5f349099ed76e9b99993282d07eb5653655bd484b3cefcccdeda4` |
| `hashline/src/zk.rs` | `7ed74f35734c6c19e233defdf4960c5179070fa7b95752e2c0cbb34a666a420d` |
| `hashline/src/zk_ffn_fresh_wire.rs` | `359fdcf6a02087d346848dc4459d180fc38c55d906a69182faf8e42746925375` |
| `hashline/src/zk_ffn_fresh_poc.rs` | `de86a47b067f950ff780c93e85b3dba28292603f8db581ec9c9c77bbd24f70ba` |
| `hashline/src/zk_ffn_fresh_poc_tests.rs` | `1e2f53c2eb1490486a604fd9dfb3bdac939642afdc43cb7fc748012596f6441e` |
| `hashline/src/private_seam.rs` | `2f36c779e79c4d7a45538fb1d596a83e6eef9fe18f1b5e138b7d72afd3ee8cf5` |
| `hashline/examples/zk60_bound_ffn.rs` | `26d8d4029c7f42b99c21271c8762ffb934fe94854677141c88f3d1ec9107777e` |
| `scripts/zk60_bound_ffn_process_check.py` | `220aebccb744dd8d68e3a6a8b5618f524a2720d6865e2239305117ef68b6c592` |
| `zkp-core/src/pcs.rs` | `2d9149564ff7f77482bcc314ad1949eef4e183d2a6c9b6b3f8ac7ac4cc72b24d` |
| `zkp-core/src/sumcheck.rs` | `56dbb8c742d970d3ffd851dd052fbfd4cc4a0a1ab0630258955ffd250e007d19` |
| `zkp-core/src/ffn_v3/statement.rs` | `27e3e14e22485587600e59932ad62e20e982814bbac587682a2004b11728164d` |
| `docs/zkmatrix-poc/ZK60_ROUND18.md` | `ab7ae484986db4aa91be6465c1e3b8b696a165d76cac136d148ecf071bc8acc4` |
| `docs/zkmatrix-poc/ZK60_ROUND18_O6_REVIEW.md` | `ae4155b80ada8f8a42debb88be65795c71ff5340d2252abe538b6dcd53edbcb7` |

The same list is in `results/zk60_opus_o6_io_review.json` → `sources`.
`private_seam.rs`, `pcs.rs`, `sumcheck.rs` and `statement.rs` are byte-identical
to what I read at `e8d4261`, so §2's, §3's and §5's endpoint reasoning carries
over unchanged; the other nine files were re-read in full at this pin.

---

## 2. Check 1 — transcript order, caller-supplied policy, the CLI — **pass**

**Both roots, the context and both scales enter first.** `transcript()`
(`zk_ffn_fresh_io.rs:138-146`) is `Transcript::new(PROFILE)` then
`absorb(b"expected-IO", &expected.to_bytes())` then a fixed parameter label.
`to_bytes` (`:76-85`) emits exactly
`HFFNEXP1 ‖ context ‖ input_scale ‖ output_scale ‖ input_root ‖ output_root`,
112 bytes. `prepare` (`:148-181`) builds that transcript and hands it to
`prepare_layer_zk_v3_inner`, whose first transcript act is
`absorb_statement_v3` (`zk.rs:2364`); the first challenge (β) is not drawn
until `zk.rs:2554`, after the W, A and M roots. The policy therefore precedes
**every** FFN commitment as well as every challenge.

**The policy is a caller parameter on both sides.** `verify(st, weights,
expected, receipt)` (`:408-413`) takes it by reference and verifies the endpoint
openings against `[&expected.input, &expected.output]` (`:448`), never against
anything in the receipt. `Receipt` (`:191-196`) is `{ffn, arguments,
endpoint_open}` — no root, no context, no scale. The 32-byte frame binding is
recomputed from the caller's policy (`:465-486`, enforced at `:547`), so a
receipt cannot supply its own. `ExpectedIo::from_roots` is deliberately public
and the doc comment states the boundary: reading a policy from an untrusted
producer does not authorize it (`:46-47`).

**CLI (`hashline/examples/zk60_bound_ffn.rs`).** `prove` creates both artifacts
with `create_new` (`:81-82`), commits the endpoints (`:92`), **saves the policy
at `:93`**, and only then calls `io::prepare` at `:96`. The `verify` branch
(`:105-124`) constructs **no** witness, weights, oracle or commitment: it never
touches `public_synthetic_fixture` or `FixedCausalOracle`, reads the policy
file, rebuilds `ExpectedIo` from the *caller's* context and the file's roots,
and refuses unless `expected.to_bytes() == policy_bytes` (`:118`) — so a
relabelled context or scale inside the file is rejected before verification.
P1 takes the W root from argv (`:108`); P3 requires the literal `fresh` and
says registered model identity is not proved (`:110`).

Two observations, neither a defect: the endpoint **shapes** (`rows = 7`,
`log_cols = 8`) are constants in `from_roots` (`:58-67`) rather than
transcript-bound fields — safe because both sides build the `Commitment` from
the same constants; and the CLI hard-codes the scales `-3, 0` in both branches
(`:80`, `:112`), so the scale field is bound but never varied.

## 3. Check 2 — `ZkLayoutV3::with_io` — **pass, confirmed by recomputation**

`with_io` (`zk.rs:2057-2063`) calls `with_masks(..., pred = false, mr1 = true)`,
takes `first = a_len / a_n` **after** every existing site is allocated, sets
`a_io = Some([first, first + 2])`, and extends `a_len` by `4 * a_n`.

I re-derived the entire A row map from `Layout::new`
(`zkp-core/src/ffn_v3/statement.rs:148-180`) and the `with_masks` cursor
(`zk.rs:2010-2049`) in `scripts/zk60_opus_io_layout.py`, allocating one site at
a time and asserting the trace is **disjoint and complete**:

| Recomputed | Value |
|---|---|
| A rows before `with_io` | **698** (last site `tab[5].a_mask` occupies 696–697) |
| A rows after | **702** |
| IO mask pairs | **698/699** and **700/701** |
| Aliasing | the four IO rows intersect **no** data row, terminal-mask row, `a_prox` pair, table row or table-mask row |
| Completeness | rows 0–701 are each covered exactly once |
| `lay.x[0]` / `lay.z[0]` | offset **3584** / **4096**, `log_size` 9 — A data rows 14–15 and 16–17 |
| A opening groups | **5 → 7**, over 18 → 20 claims |

**Independent fill.** `a_mask_rows()` includes the IO pairs (`zk.rs:2090`) and
the fill loop draws `rng.fp_vec(n)` **per row** from the OS-seeded stream
(`zk.rs:2527-2532`), so each of the four rows gets 256 independent field
elements, written before `commit_zk_owned` (`zk.rs:2537`) — inside the
reserve-before-commit window O6 §5 identified.

**Real slices, not copies.** The prover's left table is
`self.pending.a.data[offsets[i]..offsets[i] + 512]` with
`offsets = [lay.x[0], lay.z[0]]` (`zk_ffn_fresh_io.rs:284`, `:301-305`) — the
committed A buffer itself — and the attached claim uses the same offset
(`:345`). The verifier recomputes `offsets` from the layout (`:378`). No
parameter exists through which a third commitment could stand in for X or z16.

**Byte-level cross-check.** My independent frame model gives **5 029 244** (P1)
and **5 066 204** (P3). Both match, byte for byte, the receipts the `/2`
process check wrote (`/tmp/zk60-round18-final/bound-process/result.json`) and
the `bytes=` lines my own test run printed (§10). The same model reproduces the
superseded `/1` draft's **5 178 780** / **5 215 740**, and the difference
(`149 536` bytes) is exactly the draft's second mask root and opening minus the
four extra base rows in the FFN M's 256 sampled columns — i.e. the two frames
differ by precisely the schedule change and nothing else.

## 4. Check 3 — `PendingProof::finish` and the eight-slot M — **pass**

**Reservation before the FFN challenges.** `mask_specs_v3`
(`zk.rs:2149-2174`) now appends `[( log_t + log_db + 1, 2 ); 2]` — i.e. two
`(10, 2)` slots — whenever `zl.a_io.is_some()` (`:2172`). That list is built at
`zk.rs:2547`, committed by `mask_commit` at `:2548`, and its root absorbed at
`:2550` — **before** β, γ, α (`:2554-2556`) and therefore before every FFN
challenge, every FFN argument and the H commitment. `finish` cannot introduce
randomness or a commitment: it borrows `&self.pending.mc` (`:281`) and the
comment says so (`:279-280`). The slots are indices **6 and 7**
(`FIRST_IO_SLOT`, `:14`), unambiguous because `with_io` forces function 1, so
no predicate slot can occupy index 6; the guard is
`prepare_layer_zk_v3_inner`'s "IO requires the fresh function-1 schedule"
(`zk.rs:2353`) and the honest test pins `mc.specs.len() == 8` and
`mc.specs[6..] == [(10,2); 2]` (`zk_ffn_fresh_io_tests.rs:50-51`).
M therefore has `2·8 + 4 = 20` base rows (`zk.rs:435`), asserted as
`mc.encoded.len() == 20 * 4096` (`io_tests:52`). Each slot's 22 coefficients
plus 256 pads fit the 512-position mask row with 234 to spare (`zk.rs:442`).

**Public zero claimed sum plus its mask.** `gamma = c · masks[6+i].total()`
(`:294-297`). The honest sum of `eq(τ, x)·(A_slice(x) − Endpoint(x))` over the
10-variable cube is `(A − E)~(τ)`, zero exactly when the two multilinear
extensions agree at τ. `gamma` is never compared directly; it is pinned by the
first mask functional (`sum_weights(10,2)·c` against `a.gamma`, `:236-245`)
inside the single M opening.

**The verifier's terminal equation** (`:387-399`):
`fin == (1 − e)·eq(τ, ρ)·(t₀ − t₁) + c·mask_eval` with `e = ρ[9]`, refusing
`e = 0` first. This matches the prover exactly: the `eq` table extends to
`Fp2::ZERO` (`exts[0]`, `:321`), so the `eq` factor carries the `(1 − e)`
selector, while each private table extends to its own precommitted pair — A's
IO pair via `mask_value(&self.pending.a, rows[i], &rho)` and the endpoint's
rows 2/3 via `mask_value(&endpoints[i], 2, &rho)` (`:320-324`). Only the two
masked terminals `(1−e)·f(ρ) + e·R(tail ρ)` are sent (`:339-342`).

**The exact order — all openings now follow both equalities.**

| # | Step | Site |
|---:|---|---|
| 1 | *(prepare)* statement, `zk` header, W root, **A root**, **M root (8 slots)**, β/γ/α, H root, the six FFN arguments (each absorbing its terminals before the next challenge), claims built with no transcript write | `zk.rs:2364`–`:3272` |
| 2 | side 0: `io-side`, τ(9), `c`, `io-gamma`, 9 masked rounds, extension → `e`, terminals, `io-terminals`/`io-mask-eval` | `zk_ffn_fresh_io.rs:290-355` |
| 3 | side 1: the same, with side 0's terminals already absorbed | same loop |
| 4 | **one** `mask_open` over all eight slots (one θ), then `drop(mc)` | `zk.rs:2309-2310` |
| 5 | W opening (public, or hiding preceded by `check_masks`) | `zk.rs:2313-2321` |
| 6 | `check_masks` over the **combined 20** A claims, one `open_zk`, `drop` | `zk.rs:2322-2326` |
| 7 | `check_masks` on H, one `open_zk`, `drop` | `zk.rs:2327-2331` |
| 8 | endpoint 0 then endpoint 1: `check_masks(…, 7, 8, &[2,3], 4)`, `open_zk` | `zk_ffn_fresh_io.rs:357-362` |

The verifier reproduces it: `before_openings` (the two equality arguments) at
`zk.rs:3739`, `mask_verify` at `:3740`, W at `:3748`/`:3751`, A at `:3759`,
H at `:3765`, then both endpoints at `zk_ffn_fresh_io.rs:448-461`. The honest
test proves step ordering directly rather than by inspection: at the moment
`prepare` returns, `mask_open.q`, `w_open.columns`, `w_open_zk.columns`,
`a_open.columns` and `h_open.columns` are **all empty**
(`io_tests:54-58`).

**Legacy order preserved.** For the non-IO path the deferral is a pure code
move: `prove_layer_zk_v3_inner` now calls `PendingV3::finish`, which performs
`mask_open → W → A → H` — the same sequence, in the same order, that
`prepare_layer_zk_v3_inner` used to perform inline; the verifier's
`before_openings` is a no-op closure there and `mask_verify` still precedes W.
So old transcripts are byte-identical, which is what the frozen-proof gates
must confirm (they did, §10).

**Consumption on success and failure — pass.** `finish(mut self, endpoints:
Endpoints)` takes both owners by value (`:276`). `check_endpoints` consumes
`Endpoints` (`:258-271`); the endpoint `CommittedZk`s are consumed by
`endpoints.into_iter()` (`:358`) and dropped per iteration; `self.pending` is
moved into `PendingV3::finish` (`:356`), which drops M after its opening
(`zk.rs:2310`), then A and H after theirs (`:2326`, `:2331`). Every `?` on every path — root
mismatch, missing allocation, `c = 0`, `e = 0`, any `check_masks` refusal —
returns while `self` is owned, so the owners die with the frame.
`PreparedPlane` has no `Clone`, no data getter and no repeated-opening method
(`private_seam.rs:143-155`); `into_ffn_endpoint` is `pub(crate)` and consuming.

**API surface — pass.** `PendingProof` and `Endpoints` have private fields, no
`Clone`, no `Debug`, no accessor. `Receipt`'s fields are private; only
`to_bytes`/`from_bytes` are public. No seed, RNG, config or prepared-commitment
parameter exists in the profile — the only randomness is
`ZkRng::from_os(PROFILE)` at `:164`, and `/2` removed the second one. No
arbitrary-opening entry point. There is no equality precheck (`:274-275`), so
an unequal pair fails at the verifier, not at a prover assertion.

On the queue's caution — I am **not** asking for a `RoleSet`. Fixed slot
indices, fixed row offsets, private non-`Clone` owners and a consuming `finish`
enforce single use for this fixed two-endpoint API as strongly as a dynamic
role set would. The residual enforcement gaps I can actually name are in §9
(P1, P3, P6), and none of them is "add a type".

## 5. Check 4 — wrong-plane tests and the test inventory — **pass on the tests; unresolved inventory**

`wrong_plane(side)` (`zk_ffn_fresh_io_tests.rs:104-124`) mutates one word of one
plane and then calls `prepare_endpoints` on the mutated planes, so the endpoint
is **fully recommitted and its real root becomes the expected policy** (`:114`).
The receipt encodes, `Receipt::from_bytes` **succeeds** (`:121`), and only then
does `verify_bytes` fail with a message asserted to start with
`IO {side} sumcheck:` (`:122-123`). That prefix is produced only by
`sumcheck::verify` (`zk_ffn_fresh_io.rs:387-388`); the terminal-equation failure
carries a different string (`IO {i}: equality terminal`, `:398`), and no root
mismatch is possible because the policy holds the real root. The refusal is the
equality sumcheck itself: the prover's honest rounds sum to
`(A − E)~(τ) + c·g` while the claimed `gamma` is `c·g`, so round 0 fails. Both
sides are covered separately (`:125-132`).

Coverage by the queue's five categories:

| Category | Test | Verdict |
|---|---|---|
| Substituted endpoint owner | `bound_ffn_consumes_mismatched_owner_and_checks_slot:168-174` — a second, independently prepared pair of the *same values* fails with `root mismatch` | present |
| Stale root in the policy | `bound_ffn_adversarial_receipt_and_relabelled_policy:250-264` — input root, output root, context, output scale and **swapped roots**, each rejected against the original bytes *and* re-encoded under the new policy | present |
| Role swap | `:175-177` — `std::mem::swap(input, output)` then `check_endpoints(...).is_err()`, refused by `PreparedPlane`'s spec-digest check (`private_seam.rs:156-163`) | present, but only `is_err()`; the reason is unpinned |
| Relabelled context / scales | above, plus the process check's file-level flips of context, both roots and a scale byte (`zk60_bound_ffn_process_check.py:76-84`) | present; `input_scale` is never relabelled |
| Missing endpoint | — | **missing** |
| Second finalization | the `compile_fail` doctest (`zk_ffn_fresh_io.rs:125-131`) | present but weak (§9 P2) |

New at `/2` and worth recording, because it answers two of my own proposals
before I made them: the honest test now runs **two attempts per privacy mode**
and compares the **actual reserved row values** across attempts — the four A IO
mask rows read out of `held.a.data[row*256..]` and the four CFS coefficient rows
`held.mc.a_coefs[12..16]` (slots 6 and 7) — asserting each differs
(`io_tests:59-69`). That is a mask-**value** control, not a root comparison, and
it is the first one in the repaired code.

Also present: profile separation both ways (`:265-267`), truncation/extension
and 14 single-bit rejections (`:194-248`), shape and canonicality overflows
(`:205-215`), column-index bounds (`:224-228`), typed group-vector tampering
(`:268-277`), the IO capture-suppression control
(`zk_ffn_fresh_poc_tests.rs:323-346`), and 31 separate-process cases including
no-overwrite of an existing artifact (`process_check:93-94`).

## 6. Check 5 — every NEW public observation — enumeration (no disclosure verdict)

Relative to `ffn-v3-mr1-fresh-poc/1`, which is what O2's linear model covered.
The old FFN capture publication is **disabled for this profile**
(`zk.rs:3746`, `:3757`, `:3763`, `:3769`: `if io { None }` on all three roles
and `if !io { publish }`), and an IO receipt cannot publish an archived
FFN-only observation even when only the final endpoint fails
(`zk_ffn_fresh_poc_tests.rs:337-345`). **No IO capture and no joint IO analysis
exists.** This is the list a future capture must cover.

**A (698 → 702 rows, 5 → 7 groups)**

1. Two new group clear vectors `a_open.group_vecs[5..7]`, 512 `Fp2` each (256
   message + 256 pad), each a fresh random combination of **all 702 rows**,
   including all 20 data rows.
2. `a_open.prox_vec` now combines 702 rows instead of 698.
3. Each of the 256 sampled columns carries 702 base words instead of 698 —
   1024 new base-field words, the coset entries of the four IO mask rows.
4. Two new masked terminals `arguments[i].terminals[0]` =
   `(1−e)·P~(ρ) + e·(R~ + u·R'~)(tail ρ)` for `P ∈ {X, z16}`.
5. **Shared data-row aliases.** Rows 14–15 (X) are now opened under **three**
   column tails (ρ_D, p2, ρ_io0) and rows 16–17 (z16) under **two** (ρ_D,
   ρ_io1), each with its own fresh mask pair. FA3 costs exactly this
   configuration in the linear model; nothing at this pin analyses it jointly
   with the five base groups.

**Each endpoint (2 of them; 7 rows, 256 columns, inverse rate 8, Q = 256)**

6. Its root — public by construction, in the 112-byte policy.
7. One group clear vector, 512 `Fp2`, a random combination of all 7 rows
   (2 data, 2 terminal masks, 3 proximity budget — of which row 6 is filled but
   never referenced by a claim, a `mask_row` or `prox_mask_row`).
8. Its proximity vector, 512 `Fp2`.
9. 256 sampled columns × (index < 2048, 7 base words, salt, 11-digest path).
10. The masked terminal `arguments[i].terminals[1]`.
11. Structural: exactly one claim, offset 0, `log_size` 9 — the whole plane is
    the opened slice.

**The FFN mask commitment (16 → 20 base rows) — changed, not added**

12. The two extra slots widen every one of the 256 sampled M columns from 16 to
    20 base words: **1024 new base-field words**, the coset entries of slots 6
    and 7's `(re, im)` rows.
13. `mask_open.q` and `mask_open.prox` are still 1024 `Fp2` each, but they are
    now the θ-combination over **eight** slots rather than six — the same
    number of published elements carrying a larger linear functional of the
    mask coefficients.
14. Per argument: `gamma`, `mask_eval`, and 10 round polynomials of 3 `Fp2`
    (34 `Fp2` per side, 68 in total).
15. `proof.mask_root` still commits one commitment, now of 20 rows. **The `/1`
    draft's second mask root and second mask opening no longer exist** — that
    is the observation set this profile removes.

**Transcript and framing**

16. The 112-byte policy: context digest, two `i32` scales, two roots.
17. The 32-byte statement binding in the frame, and the `HFFNIO\0\x02` label
    that distinguishes an IO receipt from a round-17 one and from the draft.
18. **Joint sampling.** One transcript now derives the sampled columns of A, H,
    W, M and both endpoints. The correlation between the endpoints' column sets
    and A's is a new object with no counterpart in the round-17 analysis.

## 7. Check 6 — Codex's response to O3 — table guard **closed**; of the twelve gaps, three closed, four partly, five open

**The guard's new placement precedes every dependent value — verified.**
Prover: `check_table_point(&zl, &rho_tab)` sits at `zk.rs:3153`, immediately
after the block that produces `rho_tab` and **before** `exts` (the table
mask-row evaluations), before `e_tab`, before `proof.tab_term`, before the
`tab-term` absorb and before `mask_open`. Verifier: the same at `zk.rs:3671`,
before `e_tab`, `g_tab_val` and the `tab-term` absorb. O3's late-abort finding
is answered: nothing derived from a degenerate coordinate is formed, absorbed
or emitted. The masked sumcheck rounds already in the transcript are not a
dependent value in O3's sense.

| O3 gap | Status at `137b109` | Evidence |
|---|---|---|
| 1 late `check_table_point` | **closed** | `zk.rs:3153`, `:3671`; every table row coordinate of every multi-row slot now has a negative control (`zk_ffn_fresh_poc_tests.rs:385-391`) |
| 2 no AM14 hook (`c_s = 0` inside a real mr1 proof) | **open** | still only the injectable unit test (`zk_cfs_safety_tests.rs:5`) |
| 3 no AM15/AM22 negative control | **closed** | `zk_ffn_fresh_poc_tests.rs:416-437`: a zero group coefficient refused after exactly **one** draw, three dependent prox pairs refused with no further draw, one positive control. Exercised through the injectable `check_opening_challenges`, not a real proof |
| 4 H untested at the pair level | **partly closed** | `:196-224` runs `check_masks` on 10 of the 12 actual H claims from a real proof and asserts failure when the reserved coefficients are zeroed. Claims 4 (the constrained `h_u`/`h_up` zero-sum pair) and 11 (the value-0 LogUp identity) are excluded by the `(0..4).chain(5..11)` range, undocumented — exactly the two claims O3's caveat named |
| 5 table claims untested at rank level | **partly closed** | every table *coordinate* is now controlled; the six A-side table claims still have no realised-coefficient assertion (the new loop is on H) |
| 6 `a_mf`/`a_md`/`w_mgu` pairs unasserted | **open** | `check_pair_ambiguity` still covers only `a_mgu[0]`, `a_mdd[0]`, `w_mdd[0]` |
| 7 `assert_mask_sites` / disjointness / single `prox_mask_row` | **partly closed** | `check_masks` is confirmed as the production guard and now covers the combined A, H, P3 W **and both endpoints** (`zk_ffn_fresh_io.rs:360`, `:450`). `prox_mask_row` remains a single index; `check_opening_challenges` treats `(prox, prox+1)` as the pair (`zk_ffn_fresh_poc.rs:337`). No data/mask disjointness tripwire |
| 8 `check_generated_rows` is `#[cfg(test)]` | **open**, but materially narrowed: the honest IO test now compares actual mask-row and CFS-coefficient **values** across two attempts (`io_tests:59-69`), which is the check O3 said root comparison could not give. Release builds still run no gate |
| 9 no zeroization | **open** |
| 10 `ZkRng::new` / `ZkConfig::seed` crate-public | **open** for the crate; the IO API accepts none |
| 11 untested minor paths | **partly** | endpoint length/canonicality, the frame bound and now the context bound (`zk_ffn_fresh_poc_tests.rs:132-141`) are tested; the P3 `--wcache` refusal and the `from_os` failure path are not |
| 12 no proof bytes | **closed** | the `HFFNIO` envelope and `verify_bytes` |

## 8. Codex's fixes to my O5 findings — F1, F2, F4 all **closed**

| O5 finding | Fix at `137b109` | Verdict |
|---|---|---|
| **F1** — `Proof::from_bytes` returned a parsed `Proof` whose `weight_root()` was unchecked attacker bytes under `WeightStatement::Public(root)` | `Proof::from_bytes` now compares the decoded `w_com.root` to the caller's root and refuses (`zk_ffn_fresh_wire.rs:217-222`). The test performs my exact concrete input — zero bytes `41..73` of a valid P1 frame — and requires the decode error to mention `public W root` (`zk_ffn_fresh_poc_tests.rs:105-113`); it also now requires `to_bytes` under a wrong root to be an `Err` rather than producing a relabelled frame | **closed** for the identity hazard. Residual, correctly documented rather than removed: under `FreshPrivate` there is no expected root to compare, and `activation_root()` / `helper_root()` are still parse-time values — the new doc comment "Parsing and reading roots do not establish validity" (`zk_ffn_fresh_poc.rs:28-29`) is the mitigation. The IO profile is immune by construction: `Receipt` exposes no accessor at all |
| **F2** — `Shape::len`/`validate` zipped `specs` against a 6-element `TERMINALS` with a literal mask width of 16, silently dropping a 7th slot | `Shape::new` refuses `specs.len() != TERMINALS.len()` ("unsupported slot count", `:30-33`) and derives `mask_rows = 2 * specs.len() + 4` (`:41`), used in `len()` (`:60`), `validate` (`:137`) and `decode_layer` (`:279`); `io_shape` adds `+4` for the two equality slots (`:232`) | **closed**, exactly the proposed fix. It is also what makes the `/2` frame arithmetic self-consistent |
| **F4** — the in-memory API accepted a context the wire refused, so a proof could verify in memory and be impossible to serialize | `check_context` enforces `MAX_CONTEXT_BYTES` in both `fresh_poc::prove` (`:93`) and `fresh_poc::verify` (`:161`); the test proves a full-length context round-trips and that `MAX + 1` is refused by both (`zk_ffn_fresh_poc_tests.rs:132-141`) | **closed**. The IO profile has no analogue: `IoSpec.context` is a fixed 32-byte digest |
| **F3** — the demo creates its output artifacts before proving, so a failed attempt leaves a zero-byte file that blocks retry at that path | unchanged, and the bound-FFN demo inherits the pattern (`zk60_bound_ffn.rs:81-82`) | **open, bounded follow-up.** Note the same behaviour is deliberately relied on for the good half: the process check's `{mode}_overwrite` case requires a second `prove` to the same paths to fail with both files intact (`process_check:93-94`) |
| **F5** — the fixed group/row counts have only ever been produced at shifts `(7, 0, 14, 6)` | unchanged | **open, coverage** |

None of F1–F5 implied that a verifier would accept an invalid proof, and none
does now; F1 and F2 were API/robustness hazards and F4 a domain mismatch.

Honest old frames are preserved: the `/2` run's `retained_round17_p1` and
`retained_round17_p3` stages verify the round-17 receipts unchanged, and the
four frozen-proof stages pass (§10).

## 9. Proposed missing tests (proposals for Codex; no Rust changed here)

- **P1 — the IO layout has no direct control.**
  `repaired_layout_and_degenerate_mask_controls`
  (`zk_ffn_fresh_poc_tests.rs:361-392`) builds `ZkLayoutV3::with_masks` only, so
  its uniqueness and in-range assertions never see `a_io`. Extend the loop to
  `with_io` and assert `a_mask_rows()` has no duplicates, every row is
  `< a_len / a_n`, and `min(a_io)` equals the base layout's `a_len / a_n` —
  the aliasing property, not merely membership.
- **P2 — the double-`finish` doctest can pass for the wrong reason.** A
  `compile_fail` block succeeds on *any* compile error, a renamed path
  included. Pin it: ` ```compile_fail,E0382 `.
- **P3 — no missing or mismatched endpoint-opening test.** Decode a receipt,
  swap `endpoint_open[0]` with `endpoint_open[1]`, re-encode, verify: must
  fail. Likewise a receipt whose second endpoint opening duplicates the first.
- **P4 — `right[i]` is unchecked.** `verify` indexes `right`
  (`zk_ffn_fresh_io.rs:449`) assuming the closure ran and pushed two claims. It
  always does on the `Ok` path, but `if right.len() != 2 { return Err(...) }`
  turns a future refactor's panic into a refusal.
- **P5 — the endpoint's mask geometry is restated at the call site.**
  `check_masks(claims, 7, 8, &[2, 3], 4, …)` (`:360`, `:450`), `data[..512]`
  (`:306`), `mask_value(…, 2, …)` (`:323`) and `claim(0, 2, …)` (`:346`) all
  hard-code `private_seam`'s layout. Assert once that a `PreparedPlane` at this
  `SeamSpec` has `commitment_rows == 7`, `mask_rows == [2, 3]` and
  `prox_mask_row == 4`, so a change to `MASK_ROWS` fails loudly.
- **P6 — the codec's `+4` / `7` / `+4` are literals independent of the layout.**
  `io_shape` mutates a `Shape` built from `with_masks`
  (`zk_ffn_fresh_wire.rs:228-234`); nothing ties its three adjustments to
  `with_io` or to `mask_specs_v3`. Assert
  `io_shape(...).rows[1] == ZkLayoutV3::with_io(st, params).a_len / a_n` and
  `io_shape(...).mask_rows == 2 * mask_specs_v3(&with_io(...), p3).len() + 4`.
- **P7 — pin the role-swap refusal reason.** `io_tests:177` asserts only
  `is_err()`; assert the message names the endpoint context/side mismatch, so a
  future root-equality coincidence cannot mask a lost check.
- **P8 — relabelled `input_scale`.** The policy mutation list flips
  `output_scale` only (`io_tests:254`).
- **P9 — the label-by-label schedule test** (O6 U-5, FA8 §H item 1) is still
  missing and is now more valuable: record one IO proof's absorb sequence and
  compare it label by label to the declared schedule. It is the only thing that
  would catch a silent reordering of §4's eight steps.
- **P10 — a second shift tuple end to end** (my O5 F5), which would also pin
  the seven-group count against a claim-builder change.

## 10. Commands run, with exit codes

| # | Command | Exit |
|---:|---|---:|
| 1 | `git --no-pager -C /home/victor/wt-zk60-fa log --oneline -3` / `rev-parse HEAD` → `137b109296d9a4cc9a05792bfdbd91aa45850abe` | 0 |
| 2 | `git --no-pager -C /home/victor/wt-zk60-fa status --short` — only my three new files | 0 |
| 3 | `git --no-pager -C /home/victor/wt-zk60-fa diff 5083797 137b109 -- <the six changed sources>` | 0 |
| 4 | `sha256sum` over the reviewed sources (recorded in the result JSON) | 0 |
| 5 | `sed -n` / `grep -n` paging of those sources (read-only) | 0 |
| 6 | `python3 /home/victor/wt-zk60-fa/scripts/zk60_opus_io_layout.py` — the §3 recomputation | 0 |
| 7 | `python3 -m unittest discover -s /home/victor/wt-zk60-fa/tests -p 'test_zk60_opus_io_layout.py'` — 17 tests | 0 |
| 8 | `python3 -m unittest discover -s /home/victor/wt-zk60-fa/tests -p 'test_zk60_opus_*.py'` — 100 tests | 0 |
| 9 | `flock /tmp/zk-heavy.lock env -u HL_GPU -u HL_GPU_REQUIRED -u HL_ZK_CHUNK -u HL_TIMING CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 cargo test --release --locked --offline --manifest-path /home/victor/wt-zk60-fa/hashline/Cargo.toml --lib bound_ffn -- --test-threads=2 --nocapture` — **6 passed, 0 failed**, detached, `HL_*` cleared (`env | grep '^HL_'` empty) | 0 |

Command 9 printed, for all four attempts:
`BOUND_FFN privacy=P1 attempt=0|1 bytes=5029244 A_rows=702 A_groups=7 M_rows=20`
and `privacy=P3 … bytes=5066204 …` — the numbers my model derives independently
in §3. That is my own evidence, at this pin, on this box.

**Codex's `/2` combined run.** `/tmp/zk60-round18-final/validation.done` holds
`0` and `summary.json` records `source_commit = 137b109` with sixteen stages,
each at its **expected** exit: fourteen at 0 (storage-enabled Rust suite, CPU
build, both process checks, the two retained round-17 proofs, the Opus and
legacy joint Python suites, affected Python, four CPU frozen proofs, native
freeze-check) and two at 1 by design — `refuse_io_draft_p1` and
`refuse_io_draft_p3`, which require the `/2` verifier to **refuse the `/1`
draft's saved receipts**. I record this as observed evidence about the run, not
as acceptance; Codex owns that decision, and the round-18 note still describes
validation as pending.

The pre-existing failure I hit on `/1` — `test_zk60_opus_attention_inventory`
hashing today's `private_seam.rs` — is fixed at this pin: the archive-integrity
test now hashes the recorded commit through `git show` (O4's archived result
unchanged), and my run of the full Opus suite is green at 100 tests (83 before
my file, 17 in it).

## 11. Predictions (O6, `d130de6`) versus the implementation

| O6 prediction | `/2` at `137b109` | Held? |
|---|---|---|
| A fresh mask **pair per endpoint**, never a shared row (§3.1; `zk.rs:1971`'s difference-leak rule) | two independent pairs, rows 698/699 and 700/701, filled by separate `rng.fp_vec` draws | **yes** |
| A rows **698 → 702** (`+4·nb_d`) | 702, recomputed §3 | **yes** |
| H unchanged at 1326; W 3 (P1) / 11 (P3) | unchanged | **yes** |
| A opening groups **5 → 7** | 7, pinned in the codec and asserted in the honest test | **yes** |
| Two CFS slots of **(10, 2)**, `L = 22`, fitting the 256-coefficient budget with room | exactly that, 234 positions spare | **yes** |
| …**reserved in the FFN M before its root**, one commitment with **20 base rows**, the equality arguments before its single opening and before W/A/H | exactly that (`zk.rs:2172`, `:2547-2550`; `PendingV3::finish`) | **yes** — this is the prediction the `/1` draft missed and `/2` meets |
| Three randomness cut-offs force reserve-before-commit (A commit, M commit, H commit) | all three respected; `finish` holds no RNG at all | **yes** |
| The seam needs its own sumcheck; the vestigial `zc17_term` X evaluation cannot be reused (§1.4, U-15) | an independent 10-round sumcheck per endpoint; `zc17_term` untouched | **yes** |
| A new profile id and bounded envelope are required (§3.4, U-6) | `/2` profile string, `HFFNIO\0\x02`, `io_shape` with the three derived adjustments | **yes** |
| Endpoint claims must open `lay.x[c]` / `lay.z[c]` of the FFN's own A, not a copy (U-9) | they do (`:284`, `:301-305`, `:345`) | **yes** |
| A one-shot marker per endpoint (U-3) | achieved by ownership rather than a `RoleSet`: consuming `finish`, consuming `into_ffn_endpoint`, no `Clone` | **yes, for this fixed two-endpoint API** |
| Peer plane shape: 512 words, 9 variables, INT8 in / INT16-class out | `SeamSpec(32, 16)`, `log_len = 9`, scales `-3` / `0` as declared `i32`s | **yes** |
| Field-word equality is not value equality; the scale/class binding is unowned (U-8) | scales are transcript-bound; their meaning is explicitly a caller obligation (`zk_ffn_fresh_io.rs:20-22`) | **yes — still open** |

Twelve of thirteen predictions held on the first implementation; the
thirteenth holds on `/2`.

## 12. Status of O6's fifteen unresolved items at `137b109`

Codex's disposition table (`ZK60_ROUND18_O6_REVIEW.md`) was written against the
draft; this column is my own check against `/2`.

| Item | Status |
|---|---|
| U-1 non-hiding attention peer | **open, unchanged.** Two synthetic hiding planes are not attention; nothing proves an endpoint came from any peer computation. Codex's disposition says the same |
| U-2 joint-rank verdict for the seam configuration | **open, load-bearing.** 5 → 7 groups on shared data rows, two endpoint openings, and an M that is now 20 rows wide. No analysis covers any of it |
| U-3 one-shot endpoint consumption | **closed for this API** by ownership (§4); no general block `RoleSet` exists, and I am not asking for one |
| U-4 the FFN owns its transcript end to end | **partly closed.** A `PendingProof` now spans the FFN and two endpoints and retains M/W/A/H to the end; it still cannot span attention |
| U-5 transcript order / block header | **partly closed.** New domain, roots, context and scales are bound, and the order is now the one FA3 §12.2 describes for the FFN half. Absent: approved-contract digest, manifest digest, `HL-ZK/2` framing, P3 slot — and the label-by-label test (§9 P9) |
| U-6 the round-17 wire format cannot carry a seam | **closed**: new profile, envelope, decoder, external policy file, and a derived rather than literal mask width |
| U-7 the seam CFS slot values are derived, not pinned | **closed**: `(10, 2)` twice, `L = 22`, pinned in `mask_specs_v3`, in the honest test's `mc.specs[6..]`, in the frame arithmetic, and now in `tests/test_zk60_opus_io_layout.py` |
| U-8 field-word ≠ value equality; scale/class unowned | **open, unchanged**, now explicit in the API contract |
| U-9 copied-plane substitute | **closed on the FFN side**: the claims are on the real A's `lay.x[0]` / `lay.z[0]`. Not closed on the endpoint side — nothing ties a policy root to any computation |
| U-10 `check_generated_rows` is test-only | **open**, but narrowed: cross-attempt mask-**value** controls now exist for the four IO rows and the two IO CFS slots (§5). Release builds still run no gate, and the other mask rows have no value control |
| U-11 single-index `prox_mask_row` | **partly closed**: `check_masks` confirmed as the production guard, now applied to both endpoints; the pair is still `(prox, prox+1)` by convention. Per-group role exclusivity is still unenforced |
| U-12 late degeneracy aborts | **closed** for the table guard (§7), and satisfied by construction for both new arguments: `c = 0` (`zk_ffn_fresh_io.rs:293`) and `e = 0` (`:336-338`) refuse before any terminal is formed, with no redraw, consuming the owners |
| U-13 crate-public seeded APIs | **open** for the crate; the IO API accepts no seed, config or RNG, and `/2` removed its second `from_os` call |
| U-14 two `MaskCommit`s in one transcript | **closed.** One commitment, eight slots, 20 base rows, reserved before every FFN challenge. This was the `/1` draft's one substantive miss |
| U-15 reusing `rho_d` instead of a fresh point | **not selected**, correctly: both arguments draw their own τ after every root is bound |

## 13. What Codex still owes, in priority order

1. **U-2 / §6.** No IO capture exists and the round-17 linear model does not
   cover the seven-group A, the twenty-row M or the endpoints. A joint IO
   capture and its analysis must precede any privacy statement about this
   profile. This is the one item that blocks the round's conclusion.
2. **O3 gaps 2, 6, 8 and 9**, plus documenting the two H-claim exclusions
   (§7 gap 4) so the exclusion is a stated argument rather than a range literal.
3. **§9's proposals**, of which P1, P3, P6 and P9 are the ones that would catch
   a real regression.
4. **F3 and F5** from O5, as bounded follow-ups.
5. **U-1, U-4, U-5, U-8** remain exactly as open as before: no private
   attention peer, no block owner spanning two components, no
   approved-contract/manifest header, and no authority for what the declared
   scales mean.

**Codex retains the cryptographic judgment.** A correct row map, two reproduced
frame lengths and six passing tests are not a privacy result.
