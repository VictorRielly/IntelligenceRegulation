# O5 — independent wire-boundary review of the fresh FFN proof format

**Reviewer:** Opus 5 (independent reviewer; no Rust changed).
**Source pin under review:** `29d34362f54a8539799a6f7a74211dd43aed15cc`
("Add bounded fresh FFN proofs and verification from saved bytes").
**Worktree:** `/home/victor/wt-zk60-fa`, branch `zk60-fable-review`,
commit `53982e702d317611ea553dfe9927f9cb6813e805` (Codex round-17 tip merged).
**Date:** 2026-09-08.

**Scope, stated up front.** This is a **bounded transport-format review**. It
covers the encoded length, the parse/verify split, canonicality and bounds
checking, complete consumption, the caller-supplied mode/root policy, and the
example binary's `verify` branch. It is **not** a cryptographic verdict, **not**
a soundness proof, and **not** a privacy or zero-knowledge verdict. Nothing here
says the underlying argument is sound; it says the bytes in and out of it are
framed the way round 17 claims. No proving transcript changed: this review added
no Rust and proposes no change that would alter proof bytes.

---

## 1. Files reviewed, with digests

Every hash below is of the file in the review worktree at `53982e7`. The nine
sources that `results/zk60_round17_validation.json` pins under `source_sha256`
match it **byte for byte**, so the worktree copies are the pinned `29d3436`
implementation source.

| File | sha256 | matches round-17 pin |
| --- | --- | --- |
| `hashline/src/zk_ffn_fresh_wire.rs` | `360bb91e0f74f88f4d966d11c1e1624e101a7f647f45853f4f789aaab71d63bc` | yes |
| `hashline/src/zk_ffn_fresh_poc.rs` | `122519c1e90785b904651bfeeebec1326b50fd06e892330964e1b7244df464f3` | yes |
| `hashline/src/zk_ffn_fresh_poc_tests.rs` | `9743aa968ae62c47464cab82e7f4302a7325398e1e43b7ff343f9267a7966c41` | yes |
| `hashline/examples/zk60_fresh_ffn.rs` | `9fe8869d49a70c560f6ee0e3bdbaf253244ab73a7889a845193402410082929f` | yes |
| `scripts/zk60_fresh_ffn_process_check.py` | `5f448f1f17531f82dc27db09e3b9015467bb8dbc58238797f7fd5382b1173620` | yes |
| `hashline/src/zk.rs` | `d80755acf7e47cc04f570942820332535420d90af3e597176081acea3041ecba` | yes |
| `zkp-core/src/pcs.rs` | `2d9149564ff7f77482bcc314ad1949eef4e183d2a6c9b6b3f8ac7ac4cc72b24d` | yes |
| `zkp-core/src/sumcheck.rs` | `56dbb8c742d970d3ffd851dd052fbfd4cc4a0a1ab0630258955ffd250e007d19` | yes |
| `zkp-core/src/transcript.rs` | `31ce3c9a72da3bd3d6dcc9203c9ed7a51963cde462b59a66186467b4cb733da8` | yes |
| `zkp-core/src/ffn_v3/statement.rs` | `27e3e14e22485587600e59932ad62e20e982814bbac587682a2004b11728164d` | not pinned |
| `zkp-core/src/merkle.rs` | `77bc5f51e5f11f150bec0813a2a810dd77d3dff3d1d4963e43a8923d106e4f62` | not pinned |
| `results/zk60_round17_validation.json` | `709eeb1996b35ec0d47f885887f4c0f1f8e39e5cae2177327c6df7134be31c76` | (the record itself) |
| `docs/zkmatrix-poc/ZK60_ROUND17.md` | `89240736e71af8a111bdca98a77ceb7d4170ab6d912bbf7521695b04361df549` | (the claim under review) |

Written by this review (not committed by me; the orchestrator commits):

| File | sha256 |
| --- | --- |
| `scripts/zk60_opus_wire_length.py` | `6c5de133fa4a85939ff5d46bb0b1a4494366c02ec8282c6bd7c89fa1c8608e5a` |
| `tests/test_zk60_opus_wire_length.py` | `20eecd048af19083828cfdbee688936ac8a689915e7789358a11347ade331223` |
| `docs/zkmatrix-poc/ZK60_OPUS_WIRE_REVIEW.md` | this file |
| `results/zk60_opus_o5_wire_review.json` | `d100bde983157b5683fc563db073c38265e637914abd84305c70993ae368081e` |

---

## 2. Findings, ordered by severity

No defect was found in the length calculation, the bounds checking, the
canonicality checking, complete consumption, the caller-supplied policy, or the
CLI verify branch. The findings below are an API hazard, two latent-robustness
items, one domain mismatch, and coverage gaps.

| # | Sev | Finding | Reference | Concrete failing / missing input |
| --- | --- | --- | --- | --- |
| **F1** | Medium | `Proof::from_bytes` is public and hands back a fully-formed `Proof` whose `weight_root()` / `activation_root()` / `helper_root()` / `payload_size()` accessors are immediately usable with **nothing verified**. Under `WeightStatement::Public(root)` the parse never compares the file's `w_com.root` to the caller's `root`, even though the caller supplied it and the envelope digest already committed to it. A caller that reads a file, parses it, and displays `weight_root()` as the model identity is displaying attacker bytes. | `zk_ffn_fresh_wire.rs:191` (`from_bytes`), `:289` (`commitment`, root unchecked), `zk_ffn_fresh_poc.rs:31-43` (accessors), root actually checked only at `zk_ffn_fresh_poc.rs:146` | Take a valid `p1.proof` and overwrite bytes `41..73` (the W commitment root) with 32 arbitrary bytes. The envelope digest at bytes `9..41` is unchanged and still matches (it binds the *expected* root, not the file's), so `Proof::from_bytes(&st, Public(prepared_root), &bytes, ctx)` **succeeds** and `p.weight_root()` returns the attacker's bytes. `verify_bytes` on the same frame correctly fails with "public weight root mismatch" — the format is fail-closed; the hazard is the API shape. |
| **F2** | Low | `Shape::len` and `Shape::validate` `zip` `self.specs` against the 6-element `TERMINALS`, and the mask column width is the literal `16`. Nothing asserts `specs.len() == 6`. Today `Shape::new` hardcodes `pred = false`, so this holds; if the fresh profile ever admits function 2 both zips would **silently drop the 7th sumcheck** and `columns(16, 12)` would mis-parse every mask column, with no error and a wrong frame length. | `zk_ffn_fresh_wire.rs:27` (`with_masks(..., false, true)`), `:50` (`.zip(TERMINALS)`), `:83` (same zip in `validate`), `:227` (`r.columns(16, 12)`); the 7th spec is `zk.rs:2159`, the extra mask pair `zk.rs:435` (`n_base = 2 * masks.len() + 4`) | Set `pred = true` in `Shape::new` (or reach the fresh API with `OutputClaim::BinaryAcceptable`): the frame length is then short by `2 * (1 + rounds*(degree+1) + 2) * 16` argument bytes plus `256 * 2 * 8` mask-column bytes, and no check fires. Proposal: reject `specs.len() != TERMINALS.len()` in `Shape::new`, and derive the mask column width as `2 * specs.len() + 4`. |
| **F3** | Low | The example's `prove` branch creates the output artifact with `create_new(true)` **before** any proving work. Any later failure — a degeneracy discard, an OS-entropy failure in `ZkRng::from_os`, a short or failed `write_all` — leaves a zero-byte or partial file that makes every retry at the same path fail with "create new proof artifact: File exists". | `zk60_fresh_ffn.rs:103-111`; the discard paths are `zk_ffn_fresh_poc.rs:211` ("zero CFS mask challenge"), `:224` ("degenerate table mask row coordinate"), `:284`/`:286`/`:303` (`check_masks`), and the randomness path `:114` | Any run where `fresh_poc::prove` returns `Err`. Fail-closed for verification (a partial file fails the exact-length check), but it permanently blocks the documented three-command flow at that path. Proposal: write to a sibling temp path and `rename`, or unlink on error. |
| **F4** | Low | The accepted context domain differs between the in-memory API and the wire. `fresh_poc::prove` / `fresh_poc::verify` accept a context of any length; `binding` refuses one over `MAX_CONTEXT_BYTES`. A proof can therefore verify in memory and be impossible to serialize. | bound at `zk_ffn_fresh_wire.rs:145`; no bound at `zk_ffn_fresh_poc.rs:75-83`, `:87`, `:137` | `fresh_poc::prove(&w, ZkPrivacy::P1, &vec![b'a'; 4097])` succeeds, `fresh_poc::verify(...)` accepts it, then `proof.to_bytes(&st, weights, &vec![b'a'; 4097])` fails with "request context too long". Proposal: enforce `MAX_CONTEXT_BYTES` in `prove`/`verify` too, so the in-memory and on-wire statements share one domain. |
| **F5** | Low (coverage) | The fixed opening group counts (W 2, A 5, H 5) and the A/H row counts have only ever been produced by a **real prover** at shifts `(7, 0, 14, 6)`. The maximum-shape test decodes a synthetic all-zero frame and expects `verify_bytes` to fail. I derived the group counts analytically (§4.3) and they are shift-independent for T32/d16/f16, so this is a coverage gap, not a suspected defect — but nothing in the suite would catch it if the claim builder changed. | fixture shifts `zk_ffn_mask_diagnostic.rs:402`; synthetic max frame `zk_ffn_fresh_wire.rs:389-399`; hardcoded counts `zk_ffn_fresh_wire.rs:109`, `:112`, `:121-122` | No test calls `prove` + `to_bytes` + `verify_bytes` at any second shift tuple. Cheap proposal: assert `pcs::zk_groups_for_record` (or `group_zclaims(...).len()`) is 2/5/5 for a sample of shift tuples; one full prove/encode/verify at `(0, 0, 0, 0)` costs about the current fixture. |
| **F6** | Info | The 32 MiB `MAX_WIRE_BYTES` cap is **unreachable** at this profile: the largest frame `preflight` admits is 16,523,677 bytes, under half the cap, so `Shape::len`'s bound never fires for any statement the API accepts. It is correct defense in depth — computed before any allocation, against the expected length, with every allocation driven by that same checked quantity — but it is not the bound that makes the format safe. The real bound is `preflight` plus the fixed profile. | `zk_ffn_fresh_wire.rs:11`, `:61`; `preflight` at `zk_ffn_fresh_poc.rs:67`; `Statement::check` at `ffn_v3/statement.rs:92` | — (documentation accuracy; do not cite the cap as the live protection) |
| **F7** | Info | The frame-length check precedes the magic check, so **any** non-fresh-FFN file reports "wrong frame length" rather than "wrong profile"; and the version byte is folded into the 8-byte `MAGIC`, so a version bump reports "wrong profile or weight mode". Cosmetic; there is no version-negotiation surface to get wrong. | `zk_ffn_fresh_wire.rs:198` before `:202`; `MAGIC` at `:7` | — |
| **F8** | Info | Three of the 21 executed process cases do not test what their names suggest. `p3_wrong_policy` is refused by the CLI's argument parser before a byte is read; `p1_wrong_policy` and `p1_wrong_context` are refused by the **envelope digest**, which round 17 itself calls "not authentication", and never reach the cryptographic verifier. The round-17 claim that a *relabelled* envelope is caught by the actual verifier rests solely on the Rust test — the process boundary has no such case and cannot construct one, because only `prove` can re-encode. | `zk60_fresh_ffn_process_check.py:70-71`; CLI refusal at `zk60_fresh_ffn.rs:120`; the actual relabel test at `zk_ffn_fresh_poc_tests.rs:103-110`; recorded stderr in `results/zk60_round17_validation.json` (`p3_wrong_policy`: "p3 requires explicit 'fresh' weight policy") | — (report accuracy; the claim itself holds, see §5) |

---

## 3. Verdict on the length calculation (the core of the task)

I built an **independent** model in `scripts/zk60_opus_wire_length.py` — stdlib
only, exact integers, importing nothing from the crate or from the other review
scripts — with **three separate transcriptions** of the same quantity:

- `shape_len` — the closed form of `Shape::len` (`zk_ffn_fresh_wire.rs:39`).
- `writer_len` — what the payload writer actually emits, field by field:
  `LayerProofZk::to_bytes` (`zk.rs:814`), `SumcheckProof::write_bytes`
  (`zkp-core/src/sumcheck.rs:27`), `MaskOpening::write_bytes` (`zk.rs:411`),
  `Opening::write_bytes` (`zkp-core/src/pcs.rs:116`) and
  `OpeningZk::write_bytes` (`zkp-core/src/pcs.rs:582`).
- `reader_len` — the byte cursor of the decoder's call sequence
  (`zk_ffn_fresh_wire.rs:191`, `Reader` at `:254`).

The committed row counts driving all three are re-derived from
`zkp_core::ffn_v3::Layout::new` (`ffn_v3/statement.rs:148`) and
`ZkLayoutV3::with_masks` (`zk.rs:2000`) with `mr1 = true, pred = false` — not
taken from any recorded value.

**Result: no discrepancy.** `shape_len == writer_len == reader_len` for **all
25⁴ = 390,625 allowed shift tuples in both weight modes (781,250 cases)**, and
for the 682 distinct committed-row shapes those tuples produce. There is nothing
to attribute to one of the three.

### 3.1 Term-by-term comparison

All figures are bytes, taken from the writer transcription; the closed form
(`Shape::len`) and the decoder cursor (`from_bytes`) agree on every block total
and on the grand total.

| Term | Writer source | P1 formula | P1 (7,0,14,6) | P1 max | P3 formula | P3 (7,0,14,6) | P3 max |
| --- | --- | --- | ---: | ---: | --- | ---: | ---: |
| envelope | `zk_ffn_fresh_wire.rs:179-181` | `8 + 1 + 32` | 41 | 41 | same | 41 | 41 |
| W/A/H commitments + mask root | `zk.rs:822-825` | `3*(32+8+4) + 32` | 164 | 164 | same | 164 | 164 |
| `gu` argument | `zk.rs:827` | `(1 + 5*3 + 3)*16` | 304 | 304 | `(1 + 6*3 + 3)*16` | 352 | 352 |
| `d` argument | `zk.rs:828` | `(1 + 5*3 + 2)*16` | 288 | 288 | `(1 + 6*3 + 2)*16` | 336 | 336 |
| `zc20` argument | `zk.rs:829` | `(1 + 10*5 + 10)*16` | 976 | 976 | same | 976 | 976 |
| `zc17` argument | `zk.rs:830` | `(1 + 10*5 + 4)*16` | 880 | 880 | same | 880 | 880 |
| `zs` argument | `zk.rs:831` | `(1 + 9*3 + 1)*16` | 464 | 464 | same | 464 | 464 |
| `tab` argument | `zk.rs:832` | `(1 + 17*4 + 12)*16` | 1296 | 1296 | same | 1296 | 1296 |
| *(arguments subtotal)* | | | **4208** | **4208** | | **4304** | **4304** |
| mask opening | `zk.rs:411`, `:833` | `2*1024*16 + 256*(8 + 16*8 + 32 + 12*32)` | 174080 | 174080 | same | 174080 | 174080 |
| W opening | `pcs.rs:116` / `:582`, `zk.rs:834-835` | `3*256*16 + 256*(8 + 3*8 + 11*32)` | 110592 | 110592 | `3*512*16 + 256*(8 + 11*8 + 32 + 11*32)` | 147456 | 147456 |
| A opening | `pcs.rs:582`, `zk.rs:836` | `6*512*16 + 256*(8 + A*8 + 32 + 11*32)` | 1579008 | 5492736 | same | 1579008 | 5492736 |
| H opening | `pcs.rs:582`, `zk.rs:837` | `6*512*16 + 256*(8 + H*8 + 32 + 11*32)` | 2865152 | 10704896 | same | 2865152 | 10704896 |
| predicate gadget | `zk.rs:838` | function 1 → `None` → 0 | 0 | 0 | same | 0 | 0 |
| **total** | | | **4,733,245** | **16,486,717** | | **4,770,205** | **16,523,677** |

Rows used: `(7,0,14,6)` → W 3 (P1) / 11 (P3), A 698, H 1326.
`(16,16,16,16)` → W 3 / 11, **A 2609, H 5154**.

### 3.2 The two stated maxima, reproduced

| Quantity | Round 17 states | This model | Match |
| --- | ---: | ---: | --- |
| A rows, four shift-16 remainder tables | 2609 | 2609 | exact |
| H rows, same shape | 5154 | 5154 | exact |
| P1 frame at the largest allowed shape | 16,486,717 | 16,486,717 | exact |
| P3 frame at the largest allowed shape | 16,523,677 | 16,523,677 | exact |

The maximum genuinely uses **all four** shift-16 remainder tables: the six table
slots at `(16,16,16,16)` have row counts `[1, 256, 256, 256, 256, 256]` — ACT16
(256 entries, one row), INT16 (2¹⁶, 256 rows) and four remainder windows of 2¹⁶
each. A-row arithmetic: `20` data rows `+ 14 + 6 + 2 + 2 + 2` mask rows `= 46`,
then `+3` (ACT16: 1 data + 2 paired mask) `+512` (INT16) `+ 4 × 512 = 2609`.
H-row arithmetic: `16 + 6 + 2 + 2 + 2 + 2 = 30`, then `+4 +1024 + 4 × 1024 =
5154`. Both are monotone in each shift, so the all-16 tuple bounds every mixed
combination — confirmed exhaustively, not argued.

The model also reproduces the two frames the round-17 process run actually
wrote, **4,733,245 (P1)** and **4,770,205 (P3)**, each exactly 41 bytes above
its logical payload.

### 3.3 Overflow and the 32 MiB cap

`Shape::len` is reachable only through `Shape::new`, which runs `preflight`
first (`zk_ffn_fresh_wire.rs:22`): `Statement::check` bounds `t_rows`, `d`, `f`
at 2²⁴ and every shift to `-8..=16` (`ffn_v3/statement.rs:92`), and the fresh
profile then pins the dimensions to exactly T32/d16/f16
(`zk_ffn_fresh_poc.rs:69`). The layout is built from the **literals** `32, 16,
16` (`zk_ffn_fresh_wire.rs:27`), not from the statement, so only the shifts can
vary and every term is bounded by the table above. The largest sum is
16,523,677 — no `usize` overflow is possible on a 64- or 32-bit target.

The cap is compared against **the computed expected frame length, before any
allocation and before any parsing**: `Shape::len` returns `Err` above the cap
(`:61`), `to_bytes` sizes its `Vec` from that checked value (`:178`), and
`from_bytes` requires `bytes.len()` to *equal* it before reading a single byte
(`:198`). The cap is therefore applied to the right quantity — and is inert
today (F6). The decoder never takes a length from the file: the only
length-shaped fields in the frame are each commitment's `rows: u64` and
`log_cols: u32`, and both are **compared** to values derived from the statement
rather than used as bounds (`:289-300`), which is exactly the property round 17
claims.

### 3.4 Self-checking property worth recording

`Shape::len` (a closed form) and the `Reader` (a cursor) are two independent
implementations of the same length, and `to_bytes` runs `Self::from_bytes` on
its own output before returning (`zk_ffn_fresh_wire.rs:185`). If the closed
form ever drifted from the writer, encoding would fail immediately with "wrong
frame length" or "truncated frame" rather than emitting a bad artifact. That is
a good design property and it is why the three-model agreement in §3 is a check
on the format rather than on my transcription alone.

---

## 4. Bounds, canonicality, fixed counts, complete consumption

### 4.1 What the decoder enforces

| Property | Where | Verdict |
| --- | --- | --- |
| Every field limb strictly below the modulus | `zk_ffn_fresh_wire.rs:276-282` (`fp`), used by `fp2`, `fp2_vec`, `column` | enforced on **every** `Fp` in the frame: claims, round messages, terminals, mask `q`/`prox`, group and proximity vectors, and every opened column entry |
| Commitment shape | `:289-300` | `rows` must equal the statement-derived count, `log_cols` must be 8 |
| Column index in its domain | `:313-317` | `j < 2^depth`: 2048 for the depth-11 ordinary/hiding trees, 4096 for the depth-12 mask tree |
| Exactly 256 columns per opening | `:331` (`CHECKS`) | fixed, never read from the file |
| Fixed round / degree widths | `:215-223` via `shape.specs` | mirror `sumcheck::verify` (`zkp-core/src/sumcheck.rs:142`, `:148`) exactly |
| Fixed terminal counts 3, 2, 10, 4, 1, 12 | `:10` | independently re-derived from the layout in §4.2 |
| Fixed group counts W 2, A 5, H 5 | `:109`, `:112`, `:121-122` | independently derived in §4.3 |
| Vector widths 256 (ordinary), 512 (hiding, 256 of them pads), 1024 (CFS) | `:338-346`, `:347-359`, `:224-228` | match `pcs::verify` (`pcs.rs:453`), `pcs::verify_zk` (`pcs.rs:974`, `:985`) and `mask_verify` (`zk.rs:558`, `:564`) |
| PCS path depth 11 ordinary/hiding, 12 CFS | `:344`, `:357`, `:227` | `enc_cols = 2^8 * 8 = 2048` → depth 11; mask domain `2^12` → depth 12 |
| Context ≤ 4096 bytes, table-digest label ≤ 256 bytes | `:145`, `:23` | enforced (boundary values untested — §6) |
| Function-2 gadget absent | `:119` (`p.pred.is_some()`) in the encoder; the decoder leaves `pred: None` by construction | enforced |
| Unused W opening empty | `:102-118` in the encoder; `Default` in the decoder; re-checked cryptographically at `zk_ffn_fresh_poc.rs:149`, `:159` | enforced twice |
| **Complete consumption** | `:198` (exact length) **and** `:236` (`r.pos != bytes.len()`) | enforced twice; trailing bytes are refused by the length precondition before the cursor even runs, and the tail check is the redundant second gate |

`from_bytes` does not call `Shape::validate`, and it does not need to: I walked
every clause of `validate` and each is enforced by construction in the decoder
(counts are loop bounds, widths are literals, the unused opening is `Default`,
`pred` is `None`). `validate` is the *encoder's* gate on a caller-built
`LayerProofZk`; the decoder's gate is its own fixed shape.

Truncation at a structural boundary can never reach the cursor's "truncated
frame" path, because the exact-length precondition rejects it first with "wrong
frame length" — which is the stronger check. That is also what the recorded
process cases show (`p1_truncated`, `p1_trailing` → "wrong frame length").

### 4.2 Terminal counts re-derived

The wire's `TERMINALS = [3, 2, 10, 4, 1, 12]` are not magic: with `nb_d = nb_f =
1` and six table slots they follow from the v3 verifier's own checks —
`nb_d + 2·nb_d·nb_f = 3` (`zk.rs:3500`), `nb_f + nb_f·nb_d = 2` (`:3538`),
`10·nb_f = 10` (`:3563`), `4·nb_d = 4` (`:3596`), a single `Fp2` for the
zero-sum, and `2 × 6 = 12` (`:3620`). `terminal_counts()` in the model
recomputes them and the test pins the equality.

### 4.3 Group counts re-derived (resolves the obvious completeness worry)

The wire hardcodes 2 groups for W and 5 each for A and H. Groups are formed by
identical **column-weight keys** (`group_zclaims`, `zkp-core/src/pcs.rs:809`;
key from `zpart_weights`, `:752`). For T32/d16/f16 the A claims
(`zk.rs:3296-3329`) fall into keys `tail(rho_f)`, `tail(rho_d)`, `tail(p2)`,
`tail(p5)` and `rho_tab[8..]`. The last one is the important case: a table slot
of `log_size = L` contributes a claim at point `rho_tab[16-L..]` on a slice of
size `L`, so its key tail is `rho_tab[16-L + L-8 ..] = rho_tab[8..]` — **the
same 8 coordinates for every slot, independent of the table size**. All six
table claims therefore share one group at every shift tuple, giving member
counts `[7, 3, 1, 1, 6]`. H similarly gives `[3, 1, 1, 6, 1]` (the LogUp
identity's empty-point sum claim is its own key, `pcs.rs:764`), and W gives
`[2, 1]` (`zk.rs:3238-3294`). These are exactly the member counts the round-16
capture record reports, and the derivation shows the **counts** are
shift-invariant. Two distinct keys could in principle collide (independent
transcript challenges agreeing), which would produce a 4-group opening the
encoder refuses; that is a negligible-probability completeness event, not a
soundness one.

This is why F5 is a coverage gap rather than a suspected defect.

---

## 5. Caller-supplied mode and roots; what the digest binds vs what the verifier checks

**Mode.** The weight mode is computed from the caller's `WeightStatement`
(`mode()`, `zk_ffn_fresh_wire.rs:137`) and the file's byte must **equal** it
(`:202`). The file's mode byte never selects a branch: `shape.private` comes
from the caller (`:26`) and drives both the row counts and the W-opening branch
(`:229-233`). A file cannot talk the decoder into the other mode.

**Root.** `WeightStatement::Public(root)` carries the caller's root; the file's
`w_com.root` is read but never trusted at parse time, and the real check is the
equality in `fresh_poc::verify` (`zk_ffn_fresh_poc.rs:146`). See F1 for the one
place this ordering is a hazard.

**What the envelope digest binds** (`binding`, `zk_ffn_fresh_wire.rs:144-159`),
over the separate `fresh-ffn-wire/1` transcript: the profile constant, the full
public statement via `absorb_statement_v3` (layer, `t_rows`, `d`, `f`, the four
signed shifts, the activation spec name, the table-digest **string**), the 512
bytes of **actual table values**, the request context, the weight-policy byte,
and — under `Public` — the caller's expected W root. Every absorb is
length-prefixed on both label and data (`zkp-core/src/transcript.rs:44`), so
there is no field-boundary ambiguity. The digest is entirely recomputable by
anyone, so it is a routing check and nothing more; the code says so at `:1-3`
and round 17 says so too.

**What actually binds each of those things** (this is the part that matters):

| Bound value | Real mechanism | Reference |
| --- | --- | --- |
| Request context | absorbed into the Fiat-Shamir transcript before any challenge | `zk_ffn_fresh_poc.rs:77` |
| Privacy mode (P1 vs P3) | the statement header is absorbed into the FS transcript, so a P1 proof diverges at the first challenge under a P3 header | `zk.rs:3455` |
| Public statement (`l`, dims, shifts, act, table digest) | absorbed into the FS transcript by the verifier | `zk.rs:3449` |
| **Table values** | they enter the verifier's algebra directly (`tval_v3` in the table argument), and at the CLI they are not attacker-supplied at all — `int16out_member` regenerates a frozen registry member and asserts its digest against the pin | `zk.rs:3626`; `zkp-core/src/tables.rs:143` |
| Expected public W root | explicit equality against the proof's W commitment | `zk_ffn_fresh_poc.rs:146` |
| Committed row counts | the verifier recomputes them from the layout and refuses a mismatch | `zk.rs:3462-3466` |
| Opened column indices | compared against the transcript-derived sample | `zkp-core/src/pcs.rs:1013`, `zk.rs:574` |

**Round-17's relabelling claim is confirmed.** Re-encoding a valid proof for a
different context and then verifying under that context fails at the
cryptographic verifier, not at the digest, because the context is in the FS
domain (`zk_ffn_fresh_poc_tests.rs:103-104`). Re-encoding for a different
expected root and verifying under it fails at the explicit root equality
(`zk_ffn_fresh_poc_tests.rs:105-110`). Note that the *process* cases do **not**
demonstrate this — they are stopped by the digest (F8).

One scope statement the CLI implies: under P1 the proof binds "the FFN used
weights whose Ligero root is R", and the verifier learns R by running `prepare`
on the same binary, which recomputes it from the hardcoded public synthetic
fixture. That is honest for a demonstration; it is not an external model
identity, and round 17 already says P3's `fresh` policy authorises no named
model.

---

## 6. Parse versus verify

- `Proof::from_bytes` (`zk_ffn_fresh_wire.rs:191`) **only parses**. It performs
  representation checks (length, magic/version, mode, digest, shapes, indices,
  canonicality, complete consumption) and returns a `Proof`. It makes no
  acceptance claim, and the doc comment says so at `:189-190`.
- `verify_bytes` (`:244`) parses **and** verifies: `from_bytes` then
  `fresh_poc::verify`, which runs `preflight`, the weight-policy checks and
  `verify_layer_zk_v3_inner`.
- **What the encoder validates** (`to_bytes`, `:169`): statement admissibility
  and the table-digest label bound (via `Shape::new`); the context bound (via
  `binding`); the typed proof shape (`validate`, `:67`); and then full
  canonicality plus exact length by round-tripping its own output through
  `from_bytes` (`:185`). It explicitly does **not** validate that the proof
  verifies (`:167-168`), which is correct — the encoder is not an oracle.
- **The one path where parse could be mistaken for verification** is F1. It is
  not reachable through `verify_bytes` or through the example binary; it needs a
  caller that uses `Proof::from_bytes` directly and then reads an accessor.

---

## 7. The CLI verification branch

`hashline/examples/zk60_fresh_ffn.rs:115-131`. Following every call the branch
makes:

| Call | What it touches | Fixture / witness / oracle / proving? |
| --- | --- | --- |
| `privacy(&args[2])` (`:43`) | string match | no |
| `root(&args[3])` (`:51`) | 64 hex characters → `[u8; 32]` | no |
| `context(&args[4])` (`:62`) | length bound, `&str` → `&[u8]` | no |
| `expected_statement()` (`:10`) | `int16out_member(Silu, -3, -11)` — regenerates a **frozen** public table and asserts its digest against the pin (`zkp-core/src/tables.rs:143`), then fills in the fixed T32/d16/f16 statement with public constants | no |
| `fresh_poc::encoded_len(&st, weights)` (`:124`) | pure arithmetic over the checked statement | no |
| `File::open` + `take(max as u64 + 1).read_to_end` (`:125-127`) | **bounded** read: at most one byte more than the largest legal frame | no |
| `fresh_poc::verify_bytes(...)` (`:128`) | decode + verify | no |

**Verdict: clean.** The `verify` branch has no path into `fixture()`,
`public_synthetic_fixture()`, `FixedCausalOracle`, commitment construction or
`fresh_poc::prove` — `fixture()` is called only from `demo()` (`:70`) and the
`prove` branch (`:105`). The read is bounded before parsing, so a hostile
multi-gigabyte file costs at most ~16.5 MB of memory and then fails the exact
length check. `run()` also refuses to do anything if `HL_GPU` is set or the
`gpu-cuda` feature is on (`:87-89`).

Two notes that are not defects: `prepare` **does** construct the public
synthetic fixture (weights included) to print its root — it runs no oracle and
no prover, and it is a separate command from `verify`. And the branch's printed
`"proving_executed":false` is a claim in the output, corroborated by the call
graph above rather than by instrumentation.

---

## 8. Missing adversarial cases

These are the cases the format implies that are **not** covered by
`zk_ffn_fresh_poc_tests.rs`, the wire unit test, or the 21 executed process
cases in `results/zk60_round17_validation.json`. Each is a concrete input, not a
category. None duplicates an existing runner.

### 8.1 Decoder / format (Rust level)

| # | Missing input | Expected | Why it matters |
| --- | --- | --- | --- |
| M1 | Overwrite the 8-byte column index of `a_open.columns[0]` (or `h_open`, or the P1 `w_open`) with `2048` or `u64::MAX` | "fresh FFN wire: column index out of bounds" | The **depth-11** bound (`:316`) and `validate`'s `*j < 2048` (`:100`, `:117`) are untested; only the depth-12 mask index (4096) is exercised (`tests:65`) |
| M2 | Write `9u32` over a commitment's `log_cols`: bytes `81..85` (W), `125..129` (A), `201..205` (H) | "fresh FFN wire: commitment shape" | Only the `rows` field is corrupted today (`tests:46-50`); the `log_cols != 8` clause has no test |
| M3 | Set a limb inside an **opened column** to `P` — e.g. the first `Fp` of `a_open.columns[0].1` | "fresh FFN wire: noncanonical field word" | The `fp()` call inside `plain`/`hiding` columns is untested; only `gu_claim`'s two limbs and one mask-column limb are (`tests:52-56`, `:67-69`) |
| M4 | Set a limb inside a sumcheck **round message** (not the claim) and inside a **terminal vector** to `P` through the decoder | same | Terminals are tested only through the *encoder* (`tests:124-128`); round messages are tested nowhere |
| M5 | Splice a P1 envelope (bytes `0..41`) onto a P3 payload and verify as `p3 fresh` | "fresh FFN wire: wrong profile or weight mode" | The mode byte is currently only exercised by a single-bit flip; a same-length cross-mode frame cannot arise naturally because P1 and P3 frames always differ by 36,960 bytes, so the check has never been exercised on a length-valid frame |
| M6 | Boundary values: a `table_digest` of exactly 256 bytes and a context of exactly 4096 bytes | **accept** | Only 257 and 4097 are tested (`wire.rs:408`, `:418`); an off-by-one in either bound would be invisible |
| M7 | `prove` + `to_bytes` + `verify_bytes` at a second shift tuple, e.g. `(0,0,0,0)`; and `group_zclaims(...).len() == 2/5/5` asserted over a sample of tuples | accept / 2,5,5 | The fixed group counts and the whole encode path have only ever seen `(7,0,14,6)` from a real prover (F5) |
| M8 | Two proofs of the same statement, mode and context: assert the frames **differ** and both verify | differ, both accept | "Fresh commitments on every attempt" is the format's core claim; a regression to a seeded or reused RNG would leave every existing wire test green (the in-memory test at `tests:199-208` compares roots, but nothing compares two *encoded frames*) |

### 8.2 Process boundary (`scripts/zk60_fresh_ffn_process_check.py`)

| # | Missing invocation | Expected |
| --- | --- | --- |
| M9 | `prove p1 <4097-character context> NEW` and `verify p1 ROOT <4097-character context> PROOF` | exit 1, "request context too long" — the CLI bound at `:62-67` is untested |
| M10 | The empty context `""` through `prove` and `verify` | accept — the boundary the Rust wire test uses (`b""`) has never gone through the CLI |
| M11 | The valid proof followed by 1 MiB of zeros | exit 1, "wrong frame length" — confirms the bounded `take(max+1)` read; only a 1-byte tail is tested |
| M12 | A zero-byte proof file, and a file of exactly 41 bytes (envelope only) | exit 1, "wrong frame length" |
| M13 | `verify p1 <63-hex> …`, `verify p1 <65-hex> …`, `verify p1 <64 non-hex> …`, and `verify p1 fresh …` | exit 1, "expected public root must be 64 hexadecimal characters" — `root()` (`:51`) has no process-level test |
| M14 | Corrupt a byte **inside the envelope** at the process level: the version byte (offset 7), the mode byte (offset 8), and one digest byte (offset 9) | exit 1 with the three distinct envelope errors; the script only corrupts the last byte and the W row count |
| M15 | A second `prove` of the same mode/context into a **new** path, then verify both and compare bytes | both accept, frames differ (see M8) |
| M16 | `verify` on a path that is a directory or does not exist | exit 1, "open proof: …" |

---

## 9. Commands run

All read-only analysis plus the new Python model. No `cargo` was run: every
`HL_*`-sensitive path was reviewed by reading source, and the round-17 Rust and
process evidence was taken from `results/zk60_round17_validation.json` rather
than re-executed (per the dispatch's "prefer analysis over re-running what is
already recorded").

| Command | Exit | Result |
| --- | ---: | --- |
| `python3 /home/victor/wt-zk60-fa/scripts/zk60_opus_wire_length.py --sweep` | 0 | 781,250 tuple/mode cases, 682 distinct row shapes, all three models agree; max frames 16,486,717 / 16,523,677 |
| `python3 -m unittest discover -s /home/victor/wt-zk60-fa/tests -p 'test_zk60_opus_wire_length.py'` | 0 | 14 tests pass |
| `python3 -m unittest discover -s /home/victor/wt-zk60-fa/tests -p 'test_zk60_opus_*.py'` | 0 | **83** tests pass (the 69 existing Opus tests plus these 14), no skips |

## 10. Deliverable digests

| File | sha256 |
| --- | --- |
| `scripts/zk60_opus_wire_length.py` | `6c5de133fa4a85939ff5d46bb0b1a4494366c02ec8282c6bd7c89fa1c8608e5a` |
| `tests/test_zk60_opus_wire_length.py` | `20eecd048af19083828cfdbee688936ac8a689915e7789358a11347ade331223` |
| `results/zk60_opus_o5_wire_review.json` | `d100bde983157b5683fc563db073c38265e637914abd84305c70993ae368081e` |

The digest of this document is not listed here for the obvious reason; the
orchestrator records it at commit time. Note that `results/zk60_opus_o5_wire_review.json`
carries the same findings, models and missing-case list in machine-readable form.

---

## 11. Limits of this review

- **Bounded format review only.** No claim is made about the soundness or
  zero-knowledge of the underlying argument, about the mask schedule, about
  repeated proofs, or about what the 256 opened columns reveal. A frame that
  parses and verifies is not evidence of a private proof.
- **No Rust was executed.** The Rust and process evidence cited is the recorded
  round-17 evidence, whose source digests I confirmed match the worktree.
- **No Rust was changed**, and nothing proposed here changes proof bytes: F1,
  F2 and F4 add refusals, F3 changes only file handling, and F5/M1–M16 are
  tests. The proving transcript is untouched.
- **Function 1, T32/d16/f16 only.** The model asserts nothing about function 2,
  other dimensions, attention, the input/output seam, or a registered private
  model identity.
- The group-count derivation in §4.3 is an argument from the claim builders, not
  an executed check; M7 is the cheap way to make it executed.
