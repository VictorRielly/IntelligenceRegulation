# O6 — the pending FFN input/output seam: a source inventory and requirements list

| | |
|---|---|
| Reviewer | **Opus 5**, independent reviewer, 2026-09-08 session |
| Task | `ZK60_OPUS_QUEUE.md` **O6 — pending FFN input/output seam review** (priority 0, read-only): "Codex's next implementation binds the repaired FFN's X and z16 to independently supplied endpoints. Inventory the exact source requirements … committed row offsets, input/output dimensions, required mask slots, transcript ownership, when randomness becomes unavailable, and when each endpoint is consumed. List the existing tests that would detect a wrong endpoint or second opening." |
| Implementation pin | `b41d036c4c1eb1ed9272494815d742d0ccf29934` (fresh paired-mask FFN PoC) |
| Wire pin | `29d3436` (bounded fresh FFN proofs and verification from saved bytes) |
| Worktree | `/home/victor/wt-zk60-fa`, branch `zk60-fable-review`, HEAD `53982e702d317611ea553dfe9927f9cb6813e805` (clean at read time) |
| Builds on | O3 `ZK60_OPUS_MASK_AUDIT.md` (implemented mask schedule, 12 gaps), O4 `ZK60_OPUS_ATTENTION_INVENTORY.md` (A3 seam endpoints, A4 residual seam), FA3 `ZK60_FABLE_MASK_REPAIR.md`, FA8 `ZK60_FABLE_TRANSCRIPT_REVIEW.md`, A03 `ZK60_PENDING_FFN.md`, `ZK60_PRIVATE_BLOCK.md`, `ZK60_BLOCK_CONTRACT.md`, S2 `ZK60_PRIVATE_SEAM.md` |
| Marker key | **implemented** = present in Rust at this pin · **design-note** = specified in a design document, no Rust · **absent** = neither |

**Scope and limits, stated first.** This is a *source inventory and requirements
list for a component that does not exist yet*. **No seam is implemented** between
the repaired FFN and any peer. Today `ffn-v3-mr1-fresh-poc/1` is self-contained:
it takes a whole `V3Witness` and a request context and returns a proof; nothing
external is bound to X or to z16, and there is no API parameter through which a
peer endpoint could be supplied. Nothing here is a privacy claim, no blocker is
closed, and no cryptographic construction is proposed — every missing
construction argument is handed to Codex in §8. I changed no Rust, ran no cargo,
and used no GPU.

---

## 0. Sources inspected, with digests

| File | sha256 |
|---|---|
| `hashline/src/zk_ffn_fresh_poc.rs` | `122519c1e90785b904651bfeeebec1326b50fd06e892330964e1b7244df464f3` |
| `hashline/src/zk_ffn_fresh_poc_tests.rs` | `9743aa968ae62c47464cab82e7f4302a7325398e1e43b7ff343f9267a7966c41` |
| `hashline/src/zk_ffn_fresh_wire.rs` | `360bb91e0f74f88f4d966d11c1e1624e101a7f647f45853f4f789aaab71d63bc` |
| `hashline/examples/zk60_fresh_ffn.rs` | `9fe8869d49a70c560f6ee0e3bdbaf253244ab73a7889a845193402410082929f` |
| `hashline/src/zk.rs` | `d80755acf7e47cc04f570942820332535420d90af3e597176081acea3041ecba` |
| `hashline/src/private_seam.rs` | `ae539c9cb7799d67e60d05e98377e64b701eae20e569df4f42f7f4fa0edcb435` |
| `hashline/src/chain.rs` | `dd6a902a91edf5ba878c9ad987e6c6750c46e2b919238487f17f65621e807180` |
| `hashline/src/public_block_oracle.rs` | `0cc821e8c8c30bf842ea11442845d3156a522fc3d8f3e82d6f9fdfa55a58a83f` |
| `hashline/src/public_block_receipt.rs` | `2f99ae965d0efb5a12579b4668573798c3d1b109f3b38d13cceeea624b0ba9e0` |
| `hashline/src/layer.rs` | `d66c385d87b86e95e3140422f6fa4f3156f2c25395a70a65794377d30807326f` |
| `hashline/src/attention.rs` | `c5ae80ddc909aae40b9ec6b9766e5634cf3dc13172e8902f8f2dc33c77cdf979` |
| `zkp-core/src/pcs.rs` | `2d9149564ff7f77482bcc314ad1949eef4e183d2a6c9b6b3f8ac7ac4cc72b24d` |
| `zkp-core/src/sumcheck.rs` | `56dbb8c742d970d3ffd851dd052fbfd4cc4a0a1ab0630258955ffd250e007d19` |
| `zkp-core/src/rng.rs` | `0d4a99abbc424286de60ec4bfbe1084dc2ccaa2db8c5380e5f4594157ccea9eb` |
| `zkp-core/src/ffn_v3/statement.rs` | `27e3e14e22485587600e59932ad62e20e982814bbac587682a2004b11728164d` |
| `hashline/src/export_v3.rs` | `e0394ab4113d150336ee91353d7ba26589d5e4dffcb3cb7d2ad0fea833842acb` |
| `hashline/src/zk_ffn_mask_diagnostic.rs` | `fc37d04f3810b2a3482a1bce101d0acbfc8f25e2a11afb152510ff28b60cbf1d` |
| `hashline/src/zk_cfs_safety_tests.rs` | `ee45a49cda7816c5c64290c69386cec46ff70eec64c7f4457465488aa045fefd` |
| `hashline/tests/zk60_private_seam.rs` | `6080ffe9ac9e451b5b26a0d6936f9f3b013b921ac93e6123bffaca6ad7ed20f1` |
| `hashline/tests/zk60_pending_layout.rs` | `ab41d87f356d715af913870d89ebf77795fa8dbb63e867928e4f477f78d62f91` |
| `hashline/tests/zk60_public_block.rs` | `3776dfdfea5aa25d8df0e44c03ffcce394b4c2db287632e601bc1767e32445e6` |
| `hashline/tests/zk60_public_receipt.rs` | `b9c617c02fe02d753707a3a54e34ac3b27f4b0fea638b580739298a273981e79` |
| `hashline/tests/zk60_public_chain.rs` | `a0bff3d3120b958e6b3cff908c2ffc74077d948235e7c6d5d9c4c13686422060` |
| `hashline/tests/zk60_mask_rank.rs` | `2913afeeb9047c6a449f462170e7e6112fd55c41ea89d0b16ee6c2305b78fa81` |

The design documents cited throughout carry their digests in the JSON's
`source_sha256` map. The JSON emitter's own digest is
`34299d3dbe1f8229813b95c2b88668a6643259ef18b0465f00e18aa512d32b26`; the
output is deterministic (two runs give byte-identical files, sha256
`fa9116639193c017cbcc6abe38aafdf25f84921bd905d9ee6184aaba9c368b17`).

Commands executed for this review, with exit codes, are in §9. **O3's line
numbers were pinned to `a8a1bc7`; `zk_ffn_fresh_poc.rs` gained the wire module
(`:10-12`) at `29d3436`, so its line numbers moved by about +6. Every citation
below is re-taken at HEAD `53982e7`.**

---

## 1. Committed row offsets — exactly which rows hold X and z16

### 1.1 How the layout computes them

The element offsets come from `zkp_core::ffn_v3::Layout::new`
(`zkp-core/src/ffn_v3/statement.rs:148-180`), re-exported into hashline as
`LayoutV3` (`hashline/src/layer.rs:51-54`). Ten planes are laid out end to end in
one buffer by the `vecn` closure (`:160`), in the fixed order
`g8, rg, a16, u16, ru, h16, rh` (each `nb_f` slices of `tfb = t_rows·fb` words),
then **`x`, `z`, `rd`** (each `nb_d` slices of `tdb = t_rows·db` words). The A
commitment's data length is `a_len = off` after those ten (`:164`).

The repaired ZK layout `ZkLayoutV3::with_masks` (`hashline/src/zk.rs:2000-2053`)
appends every mask row **after** the data rows: it starts its row cursor at
`r = lay.a_len / a_n` (`:2010`) and allocates `a_mf`, `a_md`, `a_mgu`, `a_mdd`,
`a_prox`, then the six table slots, then (function 2 only) the predicate rows.
With `mr1 = true` the allocation `width` is **2** — every single-row mask site is
an Fp2 **pair** (`:2001`, `:2055` `mask_range`). Data offsets therefore never
move: FA3 §5 requires exactly this (`ZK60_FABLE_MASK_REPAIR.md:303`).

### 1.2 The fixed profile, recomputed

`fresh_poc::PROFILE` fixes T32/d16/f16, `log_cols = 8`, `inv_rate = 8`, `Q = 256`,
function 1 (`hashline/src/zk_ffn_fresh_poc.rs:14`, `:46-52`, `:67-73`), giving
`nb_d = nb_f = 1`, `db = fb = 16`, `tdb = tfb = 512`, `a_n = 256`, `log_n = 8`,
`log_s = 16`. I recomputed the whole map with exact Python integers
(§9, exit 0) and got **A 698 rows, H 1326 rows, W 3 (P1) / 11 (P3)** — the counts
O1 checked in the captures and O3 recomputed independently.

| Plane | Elements | **A rows** | Slice `log_size` | Constructor |
|---|---:|---:|---:|---|
| `g8[0]` | 0 – 512 | 0 – 2 | 9 | `statement.rs:161-162` |
| `rg[0]` | 512 – 1024 | 2 – 4 | 9 | `statement.rs:161-162` |
| `a16[0]` | 1024 – 1536 | 4 – 6 | 9 | `statement.rs:161-162` |
| `u16[0]` | 1536 – 2048 | 6 – 8 | 9 | `statement.rs:161-162` |
| `ru[0]` | 2048 – 2560 | 8 – 10 | 9 | `statement.rs:162` |
| `h16[0]` | 2560 – 3072 | 10 – 12 | 9 | `statement.rs:162` |
| `rh[0]` | 3072 – 3584 | 12 – 14 | 9 | `statement.rs:162` |
| **`x[0]` (the FFN input X)** | **3584 – 4096** | **14 – 16** | **9** | `statement.rs:163` |
| **`z[0]` (the FFN output z16)** | **4096 – 4608** | **16 – 18** | **9** | `statement.rs:163` |
| `rd[0]` | 4608 – 5120 | 18 – 20 | 9 | `statement.rs:163` |

So, **implemented**: `Slice { offset: 3584, log_size: 9 }` is X and
`Slice { offset: 4096, log_size: 9 }` is z16 in the A commitment of every
`ffn-v3-mr1-fresh-poc/1` proof, and each occupies exactly **two** of A's 698
rows of 256 columns. The slice constructor is `lay.s_d(off)`
(`statement.rs:181`), used as `s_d` in `build_claims_zk_v3` (`zk.rs:3278`).

The block decomposition generalises as `nb_d = d / db` with
`db = 2^min(log2 d, 12)`; each `x[c]` / `z[c]` is one `tdb`-word block at
`log_t + log_db` variables (`statement.rs:150-156`, `:163`). A complete T×d plane
is one contiguous slice only when `nb_d = 1`; A03 warns against assuming
otherwise (`ZK60_PENDING_FFN.md:65-67`).

The witness source words are `V3Witness.x: Vec<i8>` (T×d) and
`V3Witness.z16: Vec<i32>` (t_rows×d, int16 class)
(`hashline/src/export_v3.rs:332`, `:343`), written into the A buffer row-major by
token then block column at `zk.rs:2416-2418` (X) and `zk.rs:2419-2424`
(z16, rd), each word lifted with `Fp::from_i64`.

### 1.3 Aliasing — every other claim that opens those same rows

This is the entry the queue asks for explicitly ("a seam claim on an aliased row
shares its mask"). At the fixed profile, function 1, P1 and P3:

| Rows | Claim | Point | Mask rows used | Group key | Source | Marker |
|---:|---|---|---|---|---|---|
| 14 – 15 (**X**) | zero-check D terminal | `rho_d` (9 vars) | `a_md[0]` pair = **34, 35** | `tail(rho_d)` | `zk.rs:3306`; terminal `zk.rs:3000`, ext `zk.rs:2993` | implemented |
| 14 – 15 (**X**) | g/u matmul block terminal | `p2 = r_i‖r_kp` | `a_mgu[0]` pair = **40, 41** | `tail(p2)` | `zk.rs:3316`; terminal `zk.rs:2729`, ext `zk.rs:2690` | implemented |
| 16 – 17 (**z16**) | zero-check D terminal | `rho_d` | `a_md[1]` pair = **36, 37** | `tail(rho_d)` | `zk.rs:3307` | implemented |
| 16 – 17 (**z16**) | predicate output claim (**function 2 only**; `pred = false` at this profile) | `rho_p` | `a_pmz` pair | `tail(rho_p)` | `zk.rs:3338`, allocation `zk.rs:2027` | implemented, not reachable at this profile |
| 14 – 17 (both) | the proximity row-combination — `rho[g]` touches **every** row with a random coefficient | — | `a_prox` pair = **44, 45** | prox vector | `zkp-core/src/pcs.rs:835-856`, `:889-891` | implemented |
| 14 – 17 (both) | the 256 sampled encoded columns carry one word of every row | — | pads (`q_pad ≥ Q = 256` per row) | — | `zkp-core/src/pcs.rs:892-894`, `zk.rs:2465-2467` | implemented |
| 14 – 15 (**X**) | proposed `a_sx[c]` seam pair — "the SAME rows as `a_md[3c]` / `a_mgu[c]`" | `rho_sx` | a **new** pair | `tail(rho_sx)` | `ZK60_FABLE_MASK_REPAIR.md:105` | **design-note** |
| 16 – 17 (**z16**) | proposed `a_sz[c]` seam pair — "the SAME rows as `a_md[3c+1]`" | `rho_sz` | a **new** pair | `tail(rho_sz)` | `ZK60_FABLE_MASK_REPAIR.md:106` | **design-note** |

Two consequences a seam implementation must carry:

1. **X is already opened twice, z16 once.** A seam adds a third tail on X's rows
   and a second on z16's. FA3's rank verdict for exactly this configuration is
   `whole_A_n4_*_seams` = **0 disclosed** ("X under three pairs at three tails",
   `ZK60_FABLE_MASK_REPAIR.md:105`, `:456`) — but it is a rank result in the
   linear model, not a construction argument (§8, U-2).
2. **A shared mask row across two tails leaks the difference.** The
   implementation already states the rule for W blocks — "a single shared row
   would leave the DIFFERENCES of two blocks' evaluations in the clear"
   (`zk.rs:1971-1974`) — and FA8's stable-W negative controls demonstrate it
   (`tests/test_zk60_fable_transcript_sim.py:80`, `:87`). This is why FA3
   reserves a **fresh** pair for the seam even though the seam opens rows that
   already carry `a_md` / `a_mgu` pairs.

### 1.4 One structural gift already in the code

The X plane is loaded as a table of zero-check D (`zk.rs:2983` on the host path,
`zk.rs:2943` on the device path) but the zero-check polynomial **does not read
it**: `zcd_poly` uses only `v[3+nb_d+c]` (z), `v[3+2·nb_d+c]` (rd) and
`v[3+3·nb_d+c]` (hz) (`zk.rs:2928-2937`), and the verifier's reconstruction is
the same (`zk.rs:3596-3609` — `let v = &proof.zc17_term;` then
`(z, rd, h) = (v[nb_d+c], v[2·nb_d+c], v[3·nb_d+c])`). The comment says so:
"the X evaluation folded no more: opened at p2" (`zk.rs:2919`). So
`zc17_term[0..nb_d]` is a **masked X evaluation at `rho_d` that the argument
itself never consumes** — the vestigial hook the P0 seam uses
(`public_block_oracle.rs:93-95` takes `ffn.zcd_term[..nb_d]` as `wx` and
`[nb_d..2nb_d]` as `wz`).

**It cannot be reused as-is under the repaired profile.** In the ZK path that
value is `masked_terminal(fin, ext, e_dz) = fin + e_dz·(ext − fin)`
(`zkp-core/src/sumcheck.rs:312-314`, applied at `zk.rs:3000`), i.e. it is blinded
by the `a_md[0]` pair. `ZK60_PRIVATE_BLOCK.md:69` states the rule: "The ZK FFN's
masked `zc17_term` is **not interchangeable** with P0 `zcd_term`; copying it into
the old comparison is incorrect." `ZK60_PENDING_FFN.md:71-74` repeats it. A
seam therefore needs its own sumcheck, not a comparison of the existing terminal.

---

## 2. Input/output dimensions, and what the peer must supply and consume

### 2.1 At the fixed profile

| | X (input) | z16 (output) |
|---|---|---|
| Logical shape | `t_rows × d` = **32 × 16 = 512** words | `t_rows × d` = **32 × 16 = 512** words |
| Witness field | `V3Witness.x: Vec<i8>` (`export_v3.rs:332`) | `V3Witness.z16: Vec<i32>` (`export_v3.rs:343`) |
| Integer class | signed INT8 | signed INT16 class (`chain.rs:14`, the `z` line) |
| Committed as | `Fp::from_i64` per word (`zk.rs:2417`) | `Fp::from_i64` per word (`zk.rs:2422`) |
| Packing | row-major, token major then block column, MSB-first MLE (`zk.rs:2416-2418`, `eq_table_msb`) | same (`zk.rs:2419-2424`) |
| Variables | `log_t + log_db = 5 + 4 = **9**` | 9 |
| A rows | 2 (rows 14–15) | 2 (rows 16–17) |
| A slice | `offset 3584, log_size 9` | `offset 4096, log_size 9` |
| Prover-side length gate | `w.x.len() == 512` (`zk_ffn_fresh_poc.rs:93-108`) | `w.z16.len() == 512` (same loop) |
| Declared physical scale | `V3Exps.e_x` (`export_v3.rs:69`) — `-3` in the synthetic fixture (`causal_oracle.rs:174`) | `V3Exps.e_z16` (`export_v3.rs:74`) — `0` (`causal_oracle.rs:179`) |

**Generalisation.** `tdb = t_rows · 2^min(log2 d, 12)` and `nb_d = d / db`
(`statement.rs:150-156`); X and z16 are each `nb_d` blocks of `tdb` words at
`log_t + log_db` variables. The layout refuses `d` not a multiple of its block
and `t_rows` not a power of two (`statement.rs:129-144`); the fresh PoC refuses
anything but (32, 16, 16) outright (`zk_ffn_fresh_poc.rs:69-72`).

### 2.2 What the neighbouring component must supply and consume

A03's mapping table (`ZK60_PENDING_FFN.md:59-63`) fixes the two endpoints:

- **X ← attention norm output.** The peer plane is attention's `xm8`; O4 pins it
  at offset **22528**, `log_size 9`, 2 data rows on the attention A commitment
  (`ZK60_OPUS_ATTENTION_INVENTORY.md:396`).
- **z16 → attention residual's copy.** The peer plane is attention's `z16c`,
  offset **26112**, `log_size 9`, 2 rows (`ZK60_OPUS_ATTENTION_INVENTORY.md:397`).
- The *cross-block* residual endpoint is a different object — attention
  class-plane reconstruction, not FFN X/z (`ZK60_PENDING_FFN.md:63`; O4 §5).

**The equality that must hold, in which domain, at which point.**

- **Relation.** `X_c(ρ_sx) = xm8_c(ρ_sx)` and `z_c(ρ_sz) = z16c_c(ρ_sz)` for every
  `c ∈ [0, nb_d)`, as multilinear extensions over the 9-variable cube, evaluated
  in **F_{p²}** with the plane values in the Goldilocks base field. FA3 §2.3
  item 4 batches the `nb_d` blocks with `λ_c` and runs S2's relation
  `F(x,e) = (1−e)·eq(τ,x)·[(1−e)(A−B) + e(R_A−R_B)]`
  (`ZK60_FABLE_MASK_REPAIR.md:136-142`; the implemented S2 form is
  `private_seam.rs:250-252`, `:456-462`).
- **Domain caveat.** This is *field-word* equality. `private_seam.rs:41-42` states
  it: "Equality here is field-word equality: range/representation facts are owed
  by the enclosing arguments, even though their declared scale is
  transcript-bound." The scale obligations are separate and named:
  `AttnConsts.e_xm == V3Exps.e_x` and FFN `e_z16 == FullConsts.e_z16`
  (`ZK60_PENDING_FFN.md:61-62`); `ZK60_PRIVATE_BLOCK.md:143-146` — "Equality of
  integer words is not equality of represented values if the scales differ."
- **Point.** `ρ_sx` / `ρ_sz` are the seam sumchecks' own challenge vectors of
  `log_t + log_db = 9` coordinates, **drawn after both A roots and both M roots
  are absorbed** (`ZK60_FABLE_MASK_REPAIR.md:135-137`), plus one extension
  coordinate `e_sx` (10 rounds total). FA3 §2.3 item 6 forbids attaching a claim
  at any point that is not a block-transcript challenge drawn after the target
  commitment's root was absorbed (`:145-147`).

**Today, absent.** `fresh_poc::prove(w, privacy, context)`
(`zk_ffn_fresh_poc.rs:87`) and `fresh_poc::verify(st, weights, proof, context)`
(`:137-142`) have **no parameter for a peer commitment, a peer slice, a role, or
a scale**; `verify_bytes` (`zk_ffn_fresh_wire.rs:244-252`) likewise. The wire
binding digest absorbs profile, statement, table values, request context and
weight policy only (`zk_ffn_fresh_wire.rs:144-159`) — there is no field in which
an endpoint could be named. The CLI's `prove` takes a context string and nothing
else (`hashline/examples/zk60_fresh_ffn.rs:100-114`).

---

## 3. Required mask slots — what each seam endpoint costs

FA3 §1's rule: every single-row mask site becomes an Fp2 pair carried as
`(k1, k1·u)`; "every mask row is drawn exactly once, before its commitment
exists, and consumed by exactly one opening"
(`ZK60_FABLE_MASK_REPAIR.md:47-52`).

### 3.1 Per-endpoint cost

| Endpoint | Mask kind | Commitment | Rows added | Fresh pair required? | Source | Marker |
|---|---|---|---:|---|---|---|
| FFN `a_sx[c]` (X) | **pair** (2 base rows, Fp2) | FFN A | `2·nb_d` = **2** | **Yes** — a new pair, even though the claim opens the same data rows as `a_md[3c]`/`a_mgu[c]` | `ZK60_FABLE_MASK_REPAIR.md:105`, rule `:47-52` | design-note |
| FFN `a_sz[c]` (z16) | **pair** | FFN A | `2·nb_d` = **2** | Yes | `ZK60_FABLE_MASK_REPAIR.md:106` | design-note |
| Attention `SeamXm8[c]` | pair | attention A | 2 | Yes | `ZK60_FABLE_MASK_REPAIR.md:622-624`; O4 `ZK60_OPUS_ATTENTION_INVENTORY.md:402-407` | design-note |
| Attention `SeamZ16c[c]` | pair | attention A | 2 | Yes | same | design-note |

**Can an existing pair serve?** No, and the reason is in the implementation's own
comment: one shared mask row across two opening groups leaves the *difference* of
the two evaluations in the clear (`zk.rs:1971-1974`), demonstrated by
`tests/test_zk60_fable_cfs_channel.py:250` (mask reuse across two sumchecks with
the same challenges yields `view1 − view2 = f1 − f2` exactly) and by
`tests/test_zk60_fable_joint_rank.py:157`. The seam's point `ρ_sx` differs from
`rho_d` and `p2`, so it is a distinct group with a distinct column tail
(grouping is first-occurrence by column tail — `zkp-core/src/pcs.rs:809-831`).

### 3.2 Commitment-row totals at the fixed profile

| Commitment | Today (repaired, function 1) | With both FFN seam pairs | Source |
|---|---:|---:|---|
| FFN A | **698** rows | **702** (+4) | recomputed in §9; FA3 §8 `ZK60_FABLE_MASK_REPAIR.md:418` gives 681 → 698 → 702 |
| FFN H | 1326 | 1326 (unchanged) | same |
| FFN W (P3) | 11 | 11 (unchanged) | same |
| Attention A | 108 (**no masks at all today** — §8 U-1) | +4 | O4 `ZK60_OPUS_ATTENTION_INVENTORY.md:282`, `:402-407` |

`ZK60_PENDING_FFN.md:214-215` states the same "+`4·nb_d` base rows" figure and
adds the warning that must travel with it: "**No existing A row is
unallocated.** … this is not the cost of a complete repaired profile."
`hashline/tests/zk60_pending_layout.rs:104-109` asserts exactly that (every A row
accounted for) and names the number: `proposed_extra_pair_rows == 4`.

### 3.3 CFS slots the seam sumchecks need

The CFS mask commitment holds `2·(number of slots) + 4` base rows of 4096 coset
positions (`zk.rs:430-472`, `n_base = 2·masks.len() + 4` at `:435`). Slot specs
come from `mask_specs_v3` (`zk.rs:2138-2168`).

| Slot | `(n_vars, degree)` at the fixed profile | `L = n_vars·degree + 2` | Marker |
|---|---|---:|---|
| `SC_GU` | (5, 2) P1 / (6, 2) P3 | 12 / 14 | implemented |
| `SC_D` | (5, 2) / (6, 2) | 12 / 14 | implemented |
| `SC_ZC20` (zero-check F) | (10, 4) | 42 | implemented |
| `SC_ZC17` (zero-check D) | (10, 4) | 42 | implemented |
| `SC_ZSUM` | (9, 2) | 20 | implemented |
| `SC_TAB` | (17, 3) | **53** (the binding slot) | implemented |
| `SC_PRED` (function 2 only) | (10, 3) | 32 | implemented, unreachable at this profile |
| **`SC_SEAM_X`** | **(log_t + log_db + 1, 2) = (10, 2)** | **22** | **design-note** |
| **`SC_SEAM_Z`** | **(10, 2)** | **22** | **design-note** |

Derivation of the seam slot: FA8 §C.2 states it as `(log_t + log_db + 1, 2)`
(`ZK60_FABLE_TRANSCRIPT_REVIEW.md:497-498`); S2's implemented analogue is
`(log_len + 1, DEGREE=2)` (`private_seam.rs:112-114`, `:32`), and for a 512-word
plane `log_len = 9`. `CfsMask::len(n_vars, degree) = n_vars·degree + 2`
(`zkp-core/src/sumcheck.rs:197-199`). The 8B block profile's values are
`SC_SEAM_X/Z = (18, 2)` (`tests/test_zk60_fable_cfs_channel.py:146`); the
fixed-profile values above are the T32/d16/f16 instance of the same formula and
are **not** pinned by any test today.

**Cross-check against the mask-commitment layout limit O4 measured.**
`mask_commit` asserts `part.len() + MASK_Q ≤ m` with `MASK_Q = 256` and
`m = 2^MASK_LOG_MSG = 512` (`zk.rs:373`, `:375`, `:442`), i.e. `L_s ≤ 256` — O4's
constraint (`ZK60_OPUS_ATTENTION_INVENTORY.md:355-358`). Both seam slots have
`L = 22`; the largest FFN slot stays `SC_TAB` at 53, leaving **203 coefficient
positions of headroom**. **The seam slots fit with room to spare at this
profile.** At 8B, `SC_ZC17` is `(18, 4)`, `L = 74`
(`tests/test_zk60_fable_cfs_channel.py:147`), still inside 256.

What does change:
- FFN M base rows **16 → 20** (`2·6+4 → 2·8+4`).
- FFN A opening groups **5 → 7** (two new column tails). FA3 §2.3 item 7 states
  the expected counts as "A: 5 standalone, 7 block profile"
  (`ZK60_FABLE_MASK_REPAIR.md:148-150`).
- Proof bytes: FA3 §8 costs it at two extra A group vectors
  (`2·(n+Q)·16 B` = 16 KB) plus 22 extra base words in each of 256 opened columns
  (≈45 KB) plus 128 KB on the CFS commitment
  (`ZK60_FABLE_MASK_REPAIR.md:427-435`).

### 3.4 The round-17 wire format is not extensible to a seam

Five fixed constants in `zk_ffn_fresh_wire.rs` collide with §3.3 (all
**implemented**, and each is a hard refusal):

| Constant | Value | What a seam does to it |
|---|---|---|
| `TERMINALS: [usize; 6] = [3, 2, 10, 4, 1, 12]` (`:10`), zipped over exactly six arguments (`:74-83`) | six sumchecks | seams make eight |
| `mask_open.columns … c.len() != 16` (`:129`) | 16 M base rows | seams make 20 |
| `hiding(&p.a_open, 5, self.rows[1])` (`:121`) | 5 A groups | seams make 7 |
| `rows[1] = zl.a_len / zl.a_n` (`:32`) | 698 | seams make 702 |
| `binding(...)` (`:144-159`) | profile, statement, table, context, weight policy | **no field for a peer root, slice, role or scale** |

FA3 §5 requires this to be handled by a new profile id, "never a silent change
under `ffn-v3-mr1`" (`ZK60_FABLE_MASK_REPAIR.md:312-314`); A03 says the same
("use a new transcript domain and proof envelope for the new profile",
`ZK60_PENDING_FFN.md:15-16`) and that "neither `LayerProofZk`'s current
serialized concatenation nor `HLSEAM01` describes this combined transcript"
(`:147-149`).

---

## 4. Transcript ownership

### 4.1 What the fresh API owns today (implemented)

`fresh_poc::transcript(context)` **constructs a new transcript from nothing**:
`Transcript::new(PROFILE)`, then `absorb(b"request-context", context)`, then
`absorb(b"fixed-parameters", b"T32/d16/f16/log_cols8/inv_rate8/Q256/function1")`
(`zk_ffn_fresh_poc.rs:75-83`). Both `prove` (`:129`) and `verify` (`:178`) call it
with `&mut transcript(context)` — a temporary. **No caller can pass a transcript
in, and no transcript comes out.** The absorb order inside
`prove_layer_zk_v3_inner` is:

| # | Transcript operation | Line |
|---:|---|---|
| 1 | `Transcript::new(PROFILE)`; `request-context`; `fixed-parameters` | `zk_ffn_fresh_poc.rs:76-82` |
| 2 | `absorb_statement_v3` (profile, layer, t_rows, d, f, signed shifts, act, table digest) | `zk.rs:2294`; `statement.rs:186-197` |
| 3 | `absorb(b"zk", mode.header_v3())` | `zk.rs:2298` |
| 4 | `absorb_com(b"W")` | `zk.rs:2401` |
| 5 | `absorb_com(b"A")` ← **X and z16 are frozen here** | `zk.rs:2472` |
| 6 | `absorb(b"M", mask_root)` | `zk.rs:2480` |
| 7 | β, γ, α | `zk.rs:2484-2486` |
| 8 | `absorb_com(b"H")` | `zk.rs:2638` |
| 9 | gu argument: challenges → `c_gu` → `gu-claim` → rounds → `gu-term` | `zk.rs:2650-2742` |
| 10 | d argument | `zk.rs:2746-2814` |
| 11 | zero-check F | `zk.rs:2822-2913` |
| 12 | zero-check D (`zcD-term` carries the masked X and z16 evaluations) | `zk.rs:2920-3001` |
| 13 | table zero-check | `zk.rs:3007-3095` |
| 14 | zero-sum | `zk.rs:3101-3112` |
| 15 | `mask_open` (one θ over all six slots) | `zk.rs:3192` |
| 16 | `open_zk` W (P3) → A → H, each dropped immediately | `zk.rs:3201-3226` |

### 4.2 Where that conflicts with a seam

1. **Ownership.** A seam needs one transcript spanning both components. A03:
   "An enclosing `PendingBlock` owns both the pending attention state and this
   FFN state… **The FFN-only lifecycle cannot finalize its peer.**"
   (`ZK60_PENDING_FFN.md:101-104`). FA3 §12.1: "no method on `FfnPending` binds a
   seam by itself: only the block can, with both peers"
   (`ZK60_FABLE_MASK_REPAIR.md:599`). Today the FFN *is* the owner: it makes the
   transcript at step 1 and destroys it at return. **Absent.**
2. **What must be absorbed before what.** FA3 §2.3 item 4: `ρ_sx` / `ρ_sz` may
   only be drawn **after both A roots and both M roots** are absorbed
   (`:135-137`). Today the FFN's A root is absorbed at step 5 and the peer's root
   is never absorbed at all. FA3 §2.3 item 6 forbids a claim at any point not
   drawn after its target's root (`:145-147`).
3. **Openings must come after the seam.** Steps 15–16 open and drop every
   commitment. A03 states the consequence plainly: do not append equality claims
   to the result of `prove_layer_zk_v3` — "It has already opened W, A and H and
   dropped their committed states." (`ZK60_PENDING_FFN.md:11-12`). And: "**Do not
   fork/clone a completed transcript to add extra private openings.**" (`:151`).

### 4.3 Which of FA3 §12.2's ordering steps the current implementation satisfies

FA3 §12.2 (`ZK60_FABLE_MASK_REPAIR.md:626-643`) has seven numbered steps:

| Step | FA3 §12.2 | Status at this pin |
|---:|---|---|
| 1 | Block header: `HL-ZK/2` fields, profile, transcript domain, approved-contract digest, request context, manifest digest, layer, (P3) slot | **partly**. `Transcript::new(PROFILE)` + `request-context` + `fixed-parameters` + `absorb_statement_v3` + `zk` header (`zk_ffn_fresh_poc.rs:76-82`, `zk.rs:2294-2298`) give profile, domain, context and layer/shape. **Absent**: approved-contract digest, manifest digest, `HL-ZK/2` framing, P3 slot. |
| 2 | Attention W/A/M roots, then FFN W/A/M roots | **half implemented**. The FFN's W, A, M are absorbed in exactly that order (`zk.rs:2401`, `:2472`, `:2480`). **Absent**: the attention half. |
| 3 | FFN β, γ, α → FFN H root; attention helpers likewise | **implemented for the FFN** (`zk.rs:2484-2486` then `:2638`). Attention half absent. |
| 4 | FFN arguments in the legacy order (gu, d, zcF, zcD, tab, zsum, [pred]) with **every masked claim and terminal absorbed before the next challenge** | **implemented** and verified by construction: each argument absorbs its `Γ`/claim before its rounds and its `*-term` before the next challenge (`zk.rs:2669/2742`, `:2758/2814`, `:2829/2913`, `:2926/3001`, `:3011/3095`, `:3103/3112`). This is FA8's condition **C3** for the FFN half (`ZK60_FABLE_TRANSCRIPT_REVIEW.md:474`). |
| 5 | Seam X: `τ_sx, c_sx → γ_sx →` masked rounds → masked terminals (FFN, attention) → `e_sx`; seam Z likewise | **absent** |
| 6 | FFN `mask_open` (all slots incl. the seams); attention `mask_open` | **half implemented**: one `mask_open` over one `MaskCommit` with one θ (`zk.rs:3192`) — FA8's condition **C6**, which it records as satisfied. The seam slots are absent. |
| 7 | Openings, one per owned commitment, fixed order FFN W (P3) → FFN A → FFN H → attention W → A → H | **half implemented**: `zk.rs:3201-3226` is exactly that order for the FFN three, each dropped immediately. Attention half absent. |

So step 4 is satisfied outright, and the FFN part of steps 2, 3, 6 and 7 is in
place; step 1 is partial, step 5 is absent, and every attention obligation is
missing.

---

## 5. When randomness becomes unavailable

### 5.1 The trace

| Event | Line | What is drawn |
|---|---|---|
| `ZkRng::from_os(PROFILE)` — the only creation; no caller seed, no reusable RNG | `zk_ffn_fresh_poc.rs:114`; `zkp-core/src/rng.rs:29-50` | 32 bytes of `/dev/urandom` keyed into a blake3 stream |
| moved into the prover by value | `zk.rs:2270` (`mut rng: ZkRng`) | — |
| W mask rows + prox pair (P3 only) | `zk.rs:2366-2371` | `w_n` words per row |
| W hiding commit (pads, salts) | `zk.rs:2391` | `commit_zk_owned` |
| **A mask rows + prox pair** | `zk.rs:2457-2462` | `n = 256` words per row |
| **A hiding commit (pads, salts)** — **the cut for any A-resident mask** | `zk.rs:2467` | `commit_zk_owned` |
| A root absorbed | `zk.rs:2472` | — |
| CFS masks, their 256 pads per row, `b`, `u`, 4096 salts — **the cut for any CFS slot** | `zk.rs:2478` → `zk.rs:430-472` | `mask_specs_v3` fixes the slot list at `zk.rs:2477` |
| M root absorbed | `zk.rs:2480` | — |
| H mask rows, then the two constrained zero-sum rows | `zk.rs:2597-2604` | |
| **H hiding commit — the last RNG use in the function** | `zk.rs:2626` (device) / `zk.rs:2632` (host) | `commit_zk_(device|owned)` |
| everything after | `zk.rs:2638`–`:3230` | transcript-derived only; `grep -n rng` returns nothing in the prover after `:2632` |

### 5.2 The precise point after which no further mask row can be drawn

Three cuts, in the order they bite:

1. **`zk.rs:2467` — `pcs::commit_zk_owned` for A.** The A buffer is moved into the
   commitment; its Merkle tree and coset encoding are built from exactly those
   rows. `a_cmz.mask_rows` is then set (`:2468-2469`) as *indices into an already
   committed matrix*. **After this line no row of A can be written, so no seam
   mask on X or z16 can be created.** One line later the root enters the
   transcript (`:2472`) and the binding is public.
2. **`zk.rs:2477-2478` — `mask_specs_v3` then `mask_commit`.** The CFS slot list
   is a fixed-length vector; `n_base = 2·masks.len() + 4` rows are encoded and
   Merkle-committed in one shot (`zk.rs:435-465`). **After `:2478` no eighth slot
   can be added**, and the root is absorbed at `:2480`.
3. **`zk.rs:2632` — the H commit.** The last RNG draw anywhere in the prover.
   After it the `ZkRng` is live but never used again, and it dies with the stack
   frame on return — including on every `?` path, so a discarded attempt takes
   its stream with it (O3 §3.2).

**This is what forces reserve-before-commit.** A seam claim raised later would
need (i) two fresh uniform A rows inside a commitment whose root is already
public, and (ii) a CFS slot inside a mask commitment whose root is already
public. Neither is possible without re-committing, and re-committing changes the
root the transcript has already absorbed, which invalidates every challenge drawn
since. The design documents say the same thing four times:
`ZK60_PENDING_FFN.md:13-14` ("every mask reserved before its commitment is
made"), `:117-118` (the manifest pins masks/CFS slots "before A/M roots"),
`ZK60_PRIVATE_BLOCK.md:174-176` ("do not append a new mask after the challenge"),
`ZK60_BLOCK_CONTRACT.md:138-139`, and FA3 §4.2 (`ZK60_FABLE_MASK_REPAIR.md:242-247`)
— "Reservation fixes, **before any root exists**: the ordered role list, each
role's row indices in A…, each role's mask kind, the CFS slot list, and the
transcript positions at which each role's terminal is absorbed."

**A late seam claim would need**, and cannot get: two unallocated uniform rows in
the committed A (there are none — `hashline/tests/zk60_pending_layout.rs:104-105`
asserts every A row is accounted for and contiguous), a CFS slot in the committed
M, and a transcript position before the challenges that already depend on both
roots. FA8 records this as condition **C1**, status "repaired: not implemented"
(`ZK60_FABLE_TRANSCRIPT_REVIEW.md:472`).

**One further prover-side consequence.** After `prove` returns, nothing can be
opened at all: `drop(a_cmz)` at `zk.rs:3221` and `drop(h_cmz)` at `:3226`
destroy the only copies of the data, pads and salts, and `fresh_poc::prove`
returns `Proof { inner: out.proof }` (`zk_ffn_fresh_poc.rs:133`), discarding
`ProveOutputZk.sites` and `.timings`. FA3 §4.3 relies on exactly this:
"A second opening of the same commitment is impossible without the dropped state"
(`ZK60_FABLE_MASK_REPAIR.md:255-261`).

---

## 6. When each endpoint is consumed

### 6.1 Where a one-shot marker would have to live

| Endpoint | Where the marker must live | What would enforce it | Status |
|---|---|---|---|
| X (`a_sx[c]`) | a `Role::SeamX { c, rows }` entry in a closed `FfnManifest`, marked in `FfnPending.consumed: RoleSet` when `bind_internal_seams` runs, checked at `finalize` | FA3 §12.1: `finalize` refuses when "consumed-role set ≠ manifest role set (a role never opened, or opened twice)" (`ZK60_FABLE_MASK_REPAIR.md:229`, `:580-581`, `:586`, `:614-621`) | **design-note** |
| z16 (`a_sz[c]`) | `Role::SeamZ { c, rows }`, same | same | **design-note** |
| peer `SeamXm8[c]` / `SeamZ16c[c]` | the attention manifest's mirror roles | same lifecycle (`ZK60_FABLE_MASK_REPAIR.md:622-624`) | **design-note**; O4: "nothing marks a seam role as consumed exactly once… FA3 §4.1's `bind_internal_seams` contract has no counterpart in `attention.rs`" (`ZK60_OPUS_ATTENTION_INVENTORY.md:420-423`) |

The consumption point is fixed by FA3 §12.1: `bind_internal_seams(self, tr)`
takes the FFN Pending **and** the attention Pending together, "consumes ffn role
`SeamX[c]` and attn role `SeamXm8[c]` for every c, exactly once, in one S2-form
sumcheck", and refuses "a role already consumed; a peer handle != the handle the
block absorbed; **any slice != `lay.x[c]` / `lay.z[c]`**"
(`ZK60_FABLE_MASK_REPAIR.md:605-609`). That last refusal is the copied-plane
defence: `ZK60_PENDING_FFN.md:25-28` ("A proof about copied X/Z planes needs a
further consistency relation to the actual arithmetic commitment and is **not an
acceptable substitute**") and `ZK60_PRIVATE_SEAM.md:34-36`.

### 6.2 What exists in Rust today that resembles it

| Mechanism | What it does | What it does **not** do | Source |
|---|---|---|---|
| `pcs::open_zk` takes `&CommittedZk` | opens a set of claims | takes an **immutable borrow**; the API "does not consume or enforce one-shot use" (`ZK60_PENDING_FFN.md:52-55`) | `zkp-core/src/pcs.rs:915` |
| `drop(a_cmz)` immediately after the single `open_zk` | makes a second opening impossible in practice | is a hand-written line, not a type invariant; nothing refuses a *missing* claim | `zk.rs:3219-3221` |
| `assert_mask_sites` | asserts every group's clear vector touches **at least one** mask row, and the prox ρ touches the reserved prox row | does **not** track per-row usage — a mask row may serve two groups and the assertion still passes; no data/mask disjointness check; `prox_mask_row` is one index, not a pair | `zkp-core/src/pcs.rs:881-896` |
| `fresh_poc::check_masks` | per claim, the masked coefficients must span F_{p²}; per group, λ ≠ 0; prox pair independent | does not mark any row consumed; does not know about roles | `zk_ffn_fresh_poc.rs:234-306`, called `zk.rs:3209/3218/3223` (prover) and `zk.rs:3695/3705/3711` (verifier) |
| `check_generated_rows` | panics on a constant mask row or two byte-identical mask rows | is `#[cfg(test)]` (`zk_ffn_fresh_poc.rs:188-200`), so it does not run in release | called `zk.rs:2373`, `:2464`, `:2607` |
| `private_seam::prove(spec, left, right, ntt)` | **consumes both `PreparedPlane`s by value**; `PreparedPlane` has no `Clone`, no data getter, no repeated-opening method | is a standalone gadget on **separately committed** planes, never wired to `lay.x[c]` | `private_seam.rs:142-147`, `:326-331`, `:11-13` |
| `attn_open_a(pend, …)` takes `AttnPending` by value; its doc comment names the deferral ("DEFERRED until every seam claim on this layer's planes has been made (the FFN's X/z16 seam, and the next layer's input seam)") | the attention A is opened once, after every seam claim | "nothing marks a seam role as consumed exactly once" (O4) | `attention.rs:3220-3223`; `ZK60_OPUS_ATTENTION_INVENTORY.md:417-423` |

**Verdict: absent.** There is no manifest, no role set, no `Discarded` state, and
no refusal for a missing or duplicated seam claim on either side.

---

## 7. Existing tests that would detect a wrong endpoint or a second opening

This list is a deliverable in its own right. Every entry is a test function that
exists at this pin. I did **not** run them (read-only review; the round-17 runs
are recorded in `results/zk60_round17_validation.json`).

### 7.1 Wrong endpoint

| Test | file:line | What it would catch |
|---|---|---|
| `proof_cannot_choose_its_endpoint_roots_or_replay_connection` | `hashline/tests/zk60_private_seam.rs:79` | The closest existing analogue of the whole O6 question. Substituting an independently prepared left commitment fails; **swapping left and right** fails; four mutated `SeamSpec`s (context digest, scale, the two slot labels swapped, shape) each fail; and rewriting the proof header to the newly expected root still fails. |
| `invalid_shapes_inputs_and_prepared_contexts_fail_closed` | `hashline/tests/zk60_private_seam.rs:192` | Prover-side mis-wiring: `prove(spec, Right-prepared, Left-prepared)` errors, and a `PreparedPlane` prepared under a *different* `SeamSpec` errors (`private_seam.rs:333-339`). |
| `unequal_recommitted_witnesses_fail_at_verifier_not_prover` | `hashline/tests/zk60_private_seam.rs:47` | Two genuinely unequal planes are rejected by the **verifier**, not by a prover assertion — the property `ZK60_PRIVATE_BLOCK.md:242-246` demands. |
| `equal_unweighted_sums_do_not_substitute_for_pointwise_equality` | `hashline/tests/zk60_private_seam.rs:61` | A seam that checked sums instead of the MLE at a random point. |
| `every_message_family_is_authenticated` | `hashline/tests/zk60_private_seam.rs:105` | 14 single-field mutations of the seam proof (mask root, γ, rounds, both terminals, mask eval, all three openings) each rejected. |
| `recommitted_correct_ffn_on_different_x_reaches_seam_refusal` | `hashline/tests/zk60_public_block.rs:240` | **The X endpoint, on the real block path**: an honest FFN half built on a *different* X, independently recommitted, produces `own[0] != ffn[0]` and the verifier returns exactly `Verification("internal seam")`. Public P0 only. |
| `recommitted_residual_with_wrong_z_copy_reaches_second_seam_refusal` | `hashline/tests/zk60_public_block.rs:256` | **The z16 endpoint**: `own[0] == ffn[0]` but `own[1] != ffn[1]`, same refusal. Public P0 only. |
| `freshly_committed_wrong_input_or_output_reaches_boundary_refusal_from_bytes` | `hashline/tests/zk60_public_receipt.rs:185` | The *external* public boundary (`bind_endpoints`, `public_block_receipt.rs:259-283`) after a byte round-trip. |
| `independent_context_input_output_and_approval_cannot_be_relabelled` | `hashline/tests/zk60_public_receipt.rs:97` | Context / input / output / approval each independently bound. |
| `freshly_recommitted_wrong_middle_reaches_both_actual_arithmetic_endpoint_refusals` | `hashline/tests/zk60_public_chain.rs:438` | The cross-block residual endpoint on both sides. |
| `individually_valid_b4_receipts_with_inconsistent_actual_seam_cannot_compose` | `hashline/tests/zk60_public_chain.rs:302` | Two individually valid receipts whose intermediate planes disagree cannot compose. |
| `repaired_fresh_poc_rejects_tampering_and_legacy_profiles` | `hashline/src/zk_ffn_fresh_poc_tests.rs:218` | The nearest thing on the repaired path: a proof made under `b"context-a"` fails under `b"context-b"`; a wrong public W root fails; **an extra `a_open.group_vecs` entry fails** (`:239-242`) — which is precisely the shape a seam claim at a new tail would have to today's verifier; a legacy `prove_layer_zk_v3` proof wrapped as a fresh proof fails; a failed verify publishes no observations. |
| `repaired_wire_roundtrip_and_adversarial_frames` | `hashline/src/zk_ffn_fresh_poc_tests.rs:12` | Statement/context/weight-policy binding through the bytes, and the encoder's refusal of moved sumcheck rounds and moved `a_open.group_vecs` coordinates. |
| `b3_and_b4_domains_are_not_interchangeable` | `hashline/tests/zk60_public_receipt.rs:332` | A receipt verified by the wrong verifier. |
| `test_seam_claims_open_xm8_and_z16c_at_the_same_point` | `tests/test_zk60_opus_attention_inventory.py:126` | **Python model only**: exactly two seam claims, offsets exactly `{xm8, z16c}`, both at the same point. The only place the two endpoint identities are asserted by name — and it is against a model, not the Rust layout. |
| `test_seam_rows_are_also_opened_by_the_D_zero_check` | `tests/test_zk60_opus_attention_inventory.py:132` | The aliasing of §1.3, in the model. |

### 7.2 Second opening / commitment reuse across attempts

| Test | file:line | What it would catch |
|---|---|---|
| `repaired_fresh_poc_verifies_twice_and_blocks_single_mask_recovery` | `hashline/src/zk_ffn_fresh_poc_tests.rs:169` | The core one for the repaired FFN: two attempts on the same witness must give **different** `activation_root`, `helper_root` and `mask_root`; different `weight_root` under P3, **equal** under P1 (`:199-207`). It also runs `check_pair_ambiguity` on `a_mgu[0]`, `a_mdd[0]`, `w_mdd[0]`. |
| `normal_calls_use_fresh_masks_and_changed_ntt_metadata_is_rejected` | `hashline/tests/zk60_private_seam.rs:224` | The seam gadget's analogue: `l.root != l2.root`, `r.root != r2.root`, `p.mask_root != p2.mask_root`, bytes differ, both verify. |
| `honest_independent_commitments_roundtrip_at_subrow_row_and_multirow_shapes` | `hashline/tests/zk60_private_seam.rs:26` | Identical left/right *values* must still give `l.root != r.root` — independent randomness per endpoint within one attempt. |
| `actual_ffn_fresh_os_singleton_rows_are_recovered_without_resampling` | `hashline/src/zk_ffn_mask_diagnostic.rs:760` | Two OS-fresh runs of the same witness give different commitment roots. |
| `fresh_os_proofs_verify_for_both_privacy_modes_with_reused_config` | `hashline/src/zk.rs:3761` | Two proofs from the same witness with a **reused `ZkConfig`**: bytes differ, `a_com.root` differs, `w_com.root` differs under P3, while `size_breakdown()` is equal. |
| `cloned_default_configs_never_reuse_a_mask_stream` | `hashline/src/zk.rs:1840` | A cloned config cannot replay a mask stream. |
| `zk_v3_p3_hides_the_weights_and_the_header_binds_the_claim` | `hashline/src/zk.rs:3814` | "no two openings repeat"; a P1 proof checked as P3 (and vice versa) is rejected. |
| `test_reused_slot_discloses_w` / `test_copied_slot_rows_disclose_w` / `test_distinct_slots_disclose_nothing_jointly` | `tests/test_zk60_fable_transcript_sim.py:80`, `:87`, `:73` | **Python model**: two proofs reusing the same stable-W slot (or copied slot rows) disclose W; distinct slots disclose nothing. This is the quantitative statement of why reuse is forbidden. |
| `a_fresh_uncached_p3_process_accepts_and_never_touches_a_cache` / `configure_is_once_per_process_so_a_cached_process_cannot_later_serve_p3` | `hashline/tests/zk60_gpu_cache.rs:685`, `:411` | The `--wcache` refusal that keeps a P3 weight commitment from being reused across proofs (the belt-and-braces stop is `zk.rs:2386-2389`, the API-level refusal `zk_ffn_fresh_poc.rs:90-92`). |

### 7.3 Mask-row reuse, a missing mask row, mask-row/data aliasing

| Test | file:line | What it would catch |
|---|---|---|
| `repaired_layout_and_degenerate_mask_controls` | `hashline/src/zk_ffn_fresh_poc_tests.rs:297` | For `log_cols ∈ {5, 8, 16}`: `a_mask_rows()` / `h_mask_rows()` / `w_mask_rows()` have **no duplicates** and are all in range; every table slot's mask rows are contained in `a_mask_rows()`. Then `check_masks` rejects two equal mask coefficients and all-zero coefficients, and `draw_mask_challenge` errors after exactly **one** draw. |
| `check_generated_rows` (a `#[cfg(test)]` helper, not a `#[test]`) | `hashline/src/zk_ffn_fresh_poc.rs:189`, called at `zk.rs:2373`, `:2464`, `:2607` | Panics on `"constant repaired mask row"` or `"reused repaired mask row values"` inside **every** `mr1` prove under test. The de-facto mask-row-reuse detector — **but only in test builds**. |
| `actual_boundary_slices_are_not_terminal_mask_rows` | `hashline/tests/zk60_pending_layout.rs:44` | Directly on point: at three real shapes, every X/Z boundary slice is row-aligned, in range and **pairwise non-overlapping**; each `a_md[3c]` / `a_md[3c+1]` lies beyond the data region and the two are distinct; and it pins `(log_t + log_db, log_n) == (9, 8)` for the tiny shape. |
| `legacy_reservations_have_no_free_terminal_or_histogram_rows` | `hashline/tests/zk60_pending_layout.rs:87` | Every A row accounted for, contiguous, with none free — and names the seam's `4` extra rows (`:108-109`). |
| `legacy_cfs_manifest_distinguishes_modes_and_has_no_seam_polynomials` | `hashline/tests/zk60_pending_layout.rs:114` | Pins `mask_specs_v3` to `[(5,2),(5,2),(10,4),(10,4),(9,2),(17,3)]` (P1) and `[(6,2),(6,2),…]` (P3) — an added seam slot fails here immediately. **These four tests use `ZkLayoutV3::new`, i.e. the legacy `mr1 = false` layout, not the repaired one.** |
| `known_interface_hazard_verified_single_base_mask_reveals_entire_private_row` / `independent_fp2_mask_pair_blocks_this_specific_coordinate_extractor` | `hashline/tests/zk60_mask_rank.rs:97`, `:103` | The negative/positive control pair: one base mask row lets a fully verified opening recover the whole private row; a pair blocks that extractor. |
| `diagnostic_refuses_degenerate_and_paired_mask_controls` | `hashline/src/zk_ffn_mask_diagnostic.rs:778` | The extractor errs on a paired claim and on degenerate coefficients. |
| `zero_mask_challenge_aborts_without_resampling` | `hashline/src/zk_cfs_safety_tests.rs:5` | A zero CFS challenge aborts after one draw; `mask_challenge` leaves the transcript byte-identical. |
| `test_prox_pair_is_required_not_optional` / `test_seam_only_pairs_do_not_repair_the_legacy_A` / `test_mask_reuse_same_challenges_reveals_the_data_difference` | `tests/test_zk60_fable_joint_rank.py:337`, `:342`, `tests/test_zk60_fable_cfs_channel.py:250` | **Python model**: the prox pair is required; seam-only pairs on a legacy A repair nothing (`disclosed = 2n+4`); mask reuse leaks the data difference exactly. |

### 7.4 Where nothing exists — stated plainly

1. **No test binds `private_seam` to a real FFN or attention plane.** All nine
   integration tests use synthetic `values()` under a synthetic `SeamSpec`
   (`hashline/tests/zk60_private_seam.rs:7-23`). Nothing asserts that the plane
   handed to `prepare` is `lay.x[c]` or `lay.z[c]`.
2. **No seam exists on the repaired path, so no test covers one.** The two
   seam-refusal tests (`zk60_public_block.rs:240`, `:256`) exercise the **public
   P0** `attn_seam`, where the terminals are clear values compared with `==`
   (`attention.rs:2905-2914`).
3. **No test swaps `wx` and `wz` into `attn_seam`.** The X/z slice split
   `zcd_term[..nb_d]` vs `[nb_d..2nb_d]` (`public_block_oracle.rs:93-95`,
   `public_block_receipt.rs:232-235`) is untested against transposition; a
   transposed slice would be caught only incidentally by a value mismatch.
4. **`zc17_term` (the repaired X/z16 terminals) has no binding test at all.** It
   appears in the size accountant and nowhere else.
5. **No test asserts that mask-row *values* differ between two attempts** — only
   roots and proof bytes (§7.2). A prover reusing identical mask rows while
   re-randomising pads and salts would produce different roots and pass every
   existing test.
6. **No test removes a mask row and asserts refusal on the real prover.** The
   only missing-mask evidence is the synthetic `zk60_mask_rank.rs:97` and the
   Python prox-pair test; neither goes through `fresh_poc::prove`.
7. **No test asserts a mask row is consumed by at most one group.**
   `assert_mask_sites` cannot detect it (§6.2).
8. **`prox_mask_row` disjointness from `mask_rows` is never asserted** — in
   `private_seam.rs:207-208` or anywhere else.
9. **No verifier-side second-opening detection test** — and by design there can be
   none: FA8 records "the verifier cannot detect reuse — true by design (FA4 G4)…
   enforcement is prover-side" (`ZK60_FABLE_TRANSCRIPT_REVIEW.md:823`).
10. **The four `zk60_pending_layout.rs` tests pin the legacy (`mr1 = false`)
    layout**, so they would not notice a change in the repaired one.

---

## 8. Unresolved items for Codex

Numbered; none is solved here. Each is a construction argument or an enforcement
mechanism that the seam makes load-bearing.

**U-1. The peer commitment is not hiding.** The attention half commits with the
plain `pcs::commit` and opens with `pcs::open` (`attention.rs:2871`, `:2874`,
`:2884`, `:3214`, `:3218`, `:3230`) — no mask rows, no proximity row, no pads
(`q_pad = 0`), no salts. O4 measured this (`ZK60_OPUS_ATTENTION_INVENTORY.md:277-278`).
A seam between a hiding FFN A and a non-hiding attention A binds the FFN's X to a
**public** value. Until A04–A06 land, the seam has no private peer to bind to.
This is FA8 blocker **A3** (`ZK60_FABLE_TRANSCRIPT_REVIEW.md:522`, `:546-550`).

**U-2. The joint-rank verdict for the seam configuration is a model result, not a
construction argument.** FA3's `whole_A_n4_*_seams` = 0 ("X under three pairs at
three tails", `ZK60_FABLE_MASK_REPAIR.md:456`) is computed in the linear model
that O2 also used. The linear model explicitly excludes pad/column leakage, the
CFS messages and repeated proofs (O2's stated exclusions). The seam adds two more
opening groups on the same physical rows and two more CFS slots, and no analysis
covers those jointly with the existing 5 groups.

**U-3. Nothing marks a seam endpoint consumed exactly once, on either side.**
§6. FA3 §12.1's `RoleSet` / `bind_internal_seams` / `finalize` contract
(`ZK60_FABLE_MASK_REPAIR.md:605-621`) has no counterpart in `zk.rs` or
`attention.rs`. `assert_mask_sites` (`zkp-core/src/pcs.rs:881-896`) requires only
that each group touch **some** mask row; it cannot detect a mask row serving two
groups, and it therefore cannot enforce the one-shot rule the seam depends on.

**U-4. The repaired FFN owns its transcript end to end and cannot be composed.**
§4. `fresh_poc::transcript` builds a fresh transcript inside `prove` and `verify`
(`zk_ffn_fresh_poc.rs:75-83`, `:129`, `:178`); the openings and drops at
`zk.rs:3192-3226` end it. A03 forbids the two obvious workarounds — appending to
a finished proof (`ZK60_PENDING_FFN.md:11-12`) and forking a completed transcript
(`:151`). A `PendingBlock` owner and a new profile id are required, and no part of
either exists.

**U-5. Where the seam's transcript steps sit relative to the FFN's is fixed on
paper only, and step 1 of FA3 §12.2 is unimplemented.** The block header (approved
contract digest, manifest digest, `HL-ZK/2` framing, P3 slot) has no
representation in the fresh profile's transcript, and FA8's condition **C3**
("the order of FA3 §12.2") is recorded as "repaired: to implement"
(`ZK60_FABLE_TRANSCRIPT_REVIEW.md:474`). FA8 §H item 1 asks for a test that the
recorded absorb sequence equals the schedule label by label (`:905`); no such
test exists.

**U-6. The round-17 wire format cannot carry a seam and there is no replacement.**
§3.4. Six fixed terminal counts, 16 M base rows, 5 A groups, 698 A rows, and a
binding digest with no endpoint field (`zk_ffn_fresh_wire.rs:10`, `:121`, `:129`,
`:32`, `:144-159`). A new profile id and a new bounded decoder are required
(`ZK60_PENDING_FFN.md:241-243`).

**U-7. The seam CFS slot values at the fixed profile are derived, not pinned.**
`(10, 2)`, `L = 22`, from FA8's formula (`ZK60_FABLE_TRANSCRIPT_REVIEW.md:497-498`)
and S2's implemented spec (`private_seam.rs:112-114`). The only pinned seam slot
values anywhere are the 8B block profile's `(18, 2)`
(`tests/test_zk60_fable_cfs_channel.py:146`). Codex should fix the fixed-profile
values in the manifest before any code depends on them.

**U-8. Field-word equality is not value equality; the scale/class binding is
unowned.** §2.2. `e_x`, `e_z16` (`export_v3.rs:69`, `:74`) are carried in the
witness and are absorbed nowhere in the fresh profile's transcript — the
statement absorbs `l, t_rows, d, f, shifts, act, table` and nothing else
(`statement.rs:186-197`). `ZK60_PRIVATE_BLOCK.md:143-146` and
`ZK60_BLOCK_CONTRACT.md:69-73` both say the physical scales are not carried by
`StatementV3` today and must be pinned by the contract.

**U-9. The copied-plane substitute has no structural defence in the repaired
code.** FA3's answer is that a seam terminal is *always* a claim on
`lay.x[c]` / `lay.z[c]` of the A the block owns, with "no parameter through which
a third commitment could be supplied" (`ZK60_FABLE_MASK_REPAIR.md:616-618`); the
adversarial row is AM10 (`:387`). Today there is no such type, and
`private_seam::prepare` will happily commit any 512 words a caller hands it
(`private_seam.rs:177-189`) — which is exactly the substitute
`ZK60_PRIVATE_SEAM.md:34-36` warns is not a connection to any FFN.

**U-10. O3 gap 8 becomes load-bearing.** `check_generated_rows` is `#[cfg(test)]`
(`zk_ffn_fresh_poc.rs:188`), so the "no constant, no duplicated mask row" gate
does not run in release. With four more mask rows whose whole purpose is to blind
the two endpoints, a release-build regression would be silent.

**U-11. O3 gap 7 becomes load-bearing.** `prox_mask_row` is a single index
(`zkp-core/src/pcs.rs:563`) while FA3 §2.4 requires a prox **pair**; the seam adds
two more groups whose row weights all ride the same single proximity vector.
Codex should confirm whether `check_masks` (`zk_ffn_fresh_poc.rs:301-304`) is the
intended replacement for the missing `assert_mask_sites` pair check.

**U-12. O3 gap 1 becomes load-bearing.** `check_table_point` aborts after
`tab_term` and `mask_open` are already in the transcript (`zk.rs:3195`, `:3684`).
Two seam sumchecks bring two more degeneracy refusals (`c_s = 0`, `e_s = 0` —
`private_seam.rs:358-360`, `:394-396`); FA3 §6 item 5 requires refusal without
resampling (`ZK60_FABLE_MASK_REPAIR.md:342-349`), and the placement question
recurs for each.

**U-13. O3 gap 10 / FA8 S1.** `ZkRng::new` and `ZkConfig::seed` remain
crate-public (`zkp-core/src/rng.rs:20`, `zk.rs:334-341`), so a seeded stream is
reachable from inside the crate. FA3 §3 requires the block API to take no seed
(`ZK60_FABLE_MASK_REPAIR.md:174-177`); FA8 §D.3 explains why a `u64` seed is not
a privacy mode at any value (`ZK60_FABLE_TRANSCRIPT_REVIEW.md:604-619`).

**U-14. Two `MaskCommit`s in one block are unanalysed.** FA3 §12.2 step 6 has the
FFN and the attention each run their own `mask_open` on their own M
(`ZK60_FABLE_MASK_REPAIR.md:638`; FA8 §C.2 "Two `mask_open`s… each honest on its
own M"). FA8's I5 argument is per component; the joint statement about two
product-form tests in one transcript, with the seam's `Γ_s` drawn from the FFN's
M, is not written.

**U-15. Whether the seam sumcheck can reuse `rho_d` instead of drawing its own
point is unanswered.** The X terminal at `rho_d` already exists and costs the
argument nothing (§1.4), and `rho_d` is drawn after the FFN A root — but *not*
after the peer's A root, which FA3 §2.3 items 4 and 6 both require
(`ZK60_FABLE_MASK_REPAIR.md:135-137`, `:145-147`). If the block absorbs both A
roots before the FFN's arguments begin (FA3 §12.2 step 2 does exactly that), the
question becomes live and worth a decision, because reusing `rho_d` would avoid
two new opening groups and their bytes. **I am not proposing it** — it changes
which mask blinds the seam terminal and needs the construction argument this
review is not authorised to make.

---

## 9. Commands run, with exit codes

All read-only. No cargo, no GPU, no proving.

| # | Command | Exit |
|---:|---|---:|
| 1 | `git --no-pager -C /home/victor/wt-zk60-fa log --oneline -8` | 0 |
| 2 | `git --no-pager -C /home/victor/wt-zk60-fa rev-parse HEAD` → `53982e702d317611ea553dfe9927f9cb6813e805` | 0 |
| 3 | `git --no-pager -C /home/victor/wt-zk60-fa log --oneline -1 b41d036` → `b41d036 Implement fresh paired-mask FFN proof of concept` | 0 |
| 4 | `git --no-pager -C /home/victor/wt-zk60-fa log --oneline -1 29d3436` → `29d3436 Add bounded fresh FFN proofs and verification from saved bytes` | 0 |
| 5 | `git --no-pager -C /home/victor/wt-zk60-fa merge-base --is-ancestor b41d036 HEAD` | 0 |
| 6 | `git --no-pager -C /home/victor/wt-zk60-fa status --porcelain` (empty) | 0 |
| 7 | `sha256sum` over the 15 primary sources of §0 | 0 |
| 8 | `python3 <scratchpad>/o6_layout.py` — independent recomputation of `Layout::new` + `ZkLayoutV3::with_masks` at T32/d16/f16, shifts (7,0,14,6), `mr1 = true`, exact integers; asserts A/H/W = 698/1326/11 and prints the plane→row map, the mask rows, the table slots, the CFS slot lengths and the hypothetical seam slot | 0 |
| 9 | `python3 <scratchpad>/o6_json.py` — emits `results/zk60_opus_o6_seam_inventory.json`; re-asserts the same row counts and hashes every source | 0 |
| 10 | `sha256sum` of the emitted JSON, twice across two runs — byte-identical (`fa911663…`) | 0 |
| 11 | `sed -n` / `grep -n` paging of the sources in §0 (read-only) | 0 |

Commands 8 and 9's assertion `(a_rows, h_rows, w_rows_p3) == (698, 1326, 11)` passed, and
its plane map reproduces §1.2 and O3 §1's row map exactly. The recomputation tool
is kept in the session scratchpad, not in the repository; its output is embedded
in `results/zk60_opus_o6_seam_inventory.json`.

---

## 10. Limits

- This is a **source inventory and requirements list for a component that does not
  exist**. **No seam is implemented** between the repaired FFN and any peer, on
  either side.
- **No privacy claim is made and no blocker is closed.** Neither B1, B2, B5, A3
  nor A4 moves. The rank verdicts quoted from FA3 and the slot verdicts quoted
  from FA6 are cited, not re-derived, and they live in a linear model whose
  exclusions O2 stated.
- **No cryptographic construction is proposed.** I did not design an
  arbitrary-opening API, publish a partial proof, reuse a commitment across
  attempts, or invent a masking construction. §8 hands every missing argument to
  Codex.
- **No code was changed and nothing was executed except read-only paging and one
  arithmetic recomputation** (§9). No cargo, no GPU, no proof.
- Line numbers are pinned to HEAD `53982e7`; they will move. O3's and O4's
  numbers were taken at `a8a1bc7` and differ by roughly +6 lines in
  `zk_ffn_fresh_poc.rs` after the wire module landed.
- Function 2, stable-weight P3, the attention argument's interior, and any shape
  other than T32/d16/f16 at `log_cols = 8` are outside this inventory.
- **Codex retains the cryptographic judgment.** A correct row map and a fitting
  mask budget are not a privacy verdict.
