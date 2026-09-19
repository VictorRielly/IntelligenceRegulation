# ZK60 — adversarial check of the Tier-2 (feed-forward) private-block construction

**Status: COMPLETE — 1 BLOCKING, 9 CORRECTIONS, 12 NOTES in Tier 2; the
consolidated errata for the security owner is 22 numbered items (2 BLOCKING,
20 CORRECTIONS). The Tier-1 tool
outputs reproduce byte for byte; every feed-forward plane is pinned and I could
not construct a consistent `z16` tamper; every count in §D is confirmed with no
disagreement; the whole-block tools pass with `failures: []`. The one BLOCKING
finding is that `a16`'s int16 class — which §E's worst bound rests on — is
enforced by nothing the design adds.**

| | |
|---|---|
| Document under check | `docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2.md` (1,344 lines), DRAFT of 2026-09-19 |
| Sections checked | A, B, C, D, E, F, G, H, I.1 (all fourteen decisions touched), I.2, I.3 |
| Worktree / branch | `/home/victor/wt-zk60-attention-compile`, `zk60-attention-compile` @ `498dd60` |
| Evidence written | `results/zk60_private_block_construction/grow_and_run_whole_block.py` and `results/zk60_private_block_construction/whole_block/` (§7) |
| Model for method | `ZK60_PRIVATE_BLOCK_CONSTRUCTION_CHECK.md` (the Tier-1 check), whose B-1 and eleven corrections are carried into the errata |
| Checker | independent Opus agent, adversarial brief, 2026-09-19 |

## 0. Scope, method and what a verdict here means

**Method.** Nothing in the draft was taken on trust. Every one of the five
relations was re-derived from `private-block-kernel/src/lib.rs` before the
draft's statement of it was read back; every count in §D was recomputed by hand
and then independently by the committed tools on a whole-block paper schedule I
built (§7); every source citation the draft makes in §A–§I was opened.

**What a verdict here is not.** §7 reports what two linear-algebraic models say
about a **paper schedule**. No Rust implements the whole-block layout. A
`disclosed_dim = 0` there is evidence about that description under those models'
stated exclusions (sampled columns, salted Merkle paths, the CFS channel,
transcript conditioning, integer-range side information, `A ↔ H` correlation),
and it is not a privacy property of any code. **Nothing below establishes a
privacy property of anything.** The Tier-1 check's caveat (`…_CHECK.md:29-34`,
`:592-602`) carries unchanged.

**No build, no proof.** No `cargo`, no test, no example, no receipt, no git
write. Python was used only to drive the three committed tools and for the
arithmetic of §5 and §6. No file outside this document and
`results/zk60_private_block_construction/{grow_and_run_whole_block.py,
whole_block/}` was created or changed; nothing already in that directory was
modified (verified by `cmp`, §7.1).

**Reproduction of the Tier-1 outputs — the precondition.** Re-running the
**unmodified** `results/zk60_private_block_construction/grow_and_run.py`
reproduces all six committed Tier-1 records **byte for byte**
(`zk60_private_block_grown_{inventory,hosts,pair_schedule,schedule,cfs_slots,
summary}.json`, `cmp` identical on every one), with
`self_check_accepted_claims_identical: true` and `failures: []`. The Tier-1
figures the Tier-2 draft adds to are therefore the ones the Tier-1 check
certified, and the downstream work stands on them.

## 1. Findings, ranked

### BLOCKING

**T-B1 — `a16`'s int16 class is enforced by nothing the design adds, and §E's
worst new bound rests on it.**

§E's enforced-range table (line 919) gives `a16 ∈ [−32768, 32767]`, "Enforced
by: the **public** table's `i16` entries (`lib.rs:182`)". That citation is the
*kernel's* field type (`act: [i16; 256]`,
`private-block-kernel/src/lib.rs:182`) — a different crate, which the proof
never runs and whose types do not constrain the proof's public statement. The
proof's own public statement is `AttentionPublic`/`BlockPublic`, and there the
analogous table is carried as **`exp: Vec<i64>`**
(`hashline/src/private_attention.rs:66`), with its value range enforced by an
explicit structural check — `exp.iter().any(|e| !(0..=one_e).contains(e))` at
`private_attention.rs:97-99`. R-2's own account of why `A_E` is bounded names
exactly that check as half the reason ("the two-column exp lookup `cx`
(`argument.rs:721`) **+ the public table validation** (`private_attention.rs:98-100`)",
`ZK60_PRIVATE_ATTENTION_NATIVE_REVIEW_R2.md:133`) — the line the draft cites in
§A.3 (line 171) for the opposite conclusion.

§F (lines 994-997) asks only for "an `act.len() == 256` **shape** check". With
that and nothing else, a verifier holding a public statement whose `act` words
lie outside int16 accepts a proof in which `a16` is an arbitrary field element.
Then §E item 5's `|a16·u16| ≤ 2³⁰` and item 6's `1,610,637,311 < 2³¹` are
unfounded, `f0` can wrap `p = 2⁶⁴ − 2³² + 1`, `h16` is no longer pinned by
`a16·u16`, and the chain from `nm` to `z16` breaks at R4 — the exact hole Tier 2
exists to close. The draft's §A.3 line 165-167 states the bound as "a property
of the *public, digested* table", which is true of the words the **caller**
supplies and is not a property the **verifier enforces**; R-2's method
(`…_REVIEW_R2.md:35-39`) forbids using it.

**Required fix** (three places, one line of Rust):
`BlockPublic::new` must validate `act.iter().all(|v| (-32768..=32767).contains(v))`
(or hold `act: [i16; 256]`), mirroring `private_attention.rs:97-99`; §E line 919's
"Enforced by" column must cite that check; §F line 996 must require the range
check, not only the length; §I.1 decision 7 (lines 1223-1225) must carry the
same condition. Until then §E's table is not a no-wraparound argument.

*Why BLOCKING and not CORRECTION.* The security owner may reason that the
kernel's doc comment already says "the caller … MUST authenticate the exact
table words" (`lib.rs:17-23`). The accepted module deliberately does **not**
accept that for `exp`: it validates. Accepting it for `act` would make this the
only LogUp table in the module whose value class is a caller promise, and would
silently invalidate §E. The fix is cheap; the premise as written is unsound.

### CORRECTION

| # | What the draft says | Source | Correct statement |
|---|---|---|---|
| T-C1 | line 857 (§D.3): `mask_open(M_ROWS) = 512*16 + 256*(8 + M_ROWS*8 + 32 + 15*32)` | `hashline/src/private_attention/wire.rs:23`, `:25`, `:34`: `2*MASK_VEC*16 + CHECKS*(8 + M_ROWS*8 + 32 + MASK_PATH*32)` with `MASK_VEC = 1024`, `MASK_PATH = 12` | Wrong in form, right in value — the Tier-1 check's C-4 recurring verbatim in Tier 2. The real terms are `2·1024·16 = 32,768` and `12·32 = 384`, not `8,192` and `480`; both errors are `M_ROWS`-independent and cancel (`24,576 = 256·96`), so 243,712 survives. Reuse at a different `MASK_VEC`/`MASK_PATH` gives a wrong answer. |
| T-C2 | lines 852 and 877 (§D.3): the byte model is "the Tier-1 memo's **reverse-derived** byte model" and "the model is not read out of `zkp-core/src/pcs.rs`" | `hashline/src/private_attention/wire.rs:28-36` (`opening_len`, `encoded_len`) | The Tier-1 check already sourced it (C-3). It is in the module's own wire file, verbatim. Replace both sentences with "read out of `hashline/src/private_attention/wire.rs:28-36`"; the total is derived, not fitted. |
| T-C3 | lines 805-806, 829-848, 870 (§D.2/§D.3): `A` opening groups **35 `[E]`**, `H` **9 `[E]`**, "I did **not** enumerate the grouping exhaustively" | derived by the committed inventory tool on the whole-block schedule: `results/zk60_private_block_construction/whole_block/zk60_private_block_whole_summary.json` | **35 and 9 exactly**, member for member (§7.3). The `[ESTIMATE]` tags can be dropped and `A_GROUPS = 35`, `H_GROUPS = 9` go into `layout.rs`. The draft's four-fresh-tails argument is right in every step. |
| T-C4 | line 576 (§C.1): `f_act = v[H_FACT]·( alpha − ( … ) ) − 1` | `argument.rs:706` (`let ihx = b.h(H_SEXP)?;`) and `:721` (`v[ihx]`) | `H_FACT` is a **plane** constant, not a **table index**. Written as given, the term reads the wrong table. It must be `let i_fact = b.h(H_FACT)?;` … `v[i_fact]`, i.e. table index 19 in the draft's own listing (line 565). The same applies to `h0 = 14` for `helper_sum`, which the draft never binds (line 577). |
| T-C5 | lines 965-976 (§E, "A correction to Tier 1's §H.1"): `xres1` and `x_in` are both int16 because "the witness builder takes `input: &[i16]` (`witness.rs:103`, `:108`), the calibration says `x_cls: Cls::Int16` (`causal_oracle.rs:115`)" | `layout.rs:226` + `argument.rs:634` for `x_in`; `layout.rs:232` + `argument.rs:636` for `xres1` | The **conclusion is right** (and duplicates the Tier-1 check's C-2), the **reasoning is inadmissible**: `witness.rs:103` is the honest prover's input type and `causal_oracle.rs:115` is a calibration declaration; neither is a range the verifier enforces, and R-2's method forbids using either (`…_REVIEW_R2.md:35-39`). The enforced class of both is `byte(·L0) ∧ byte(·L1)` plus `c2`/`c4`. Replace the citations. |
| T-C6 | line 1127 (§G.2, T-g1): "`rg` leaves `[0, 2^7)`, so **`scaled(A_RGL, 2)`** has no table row" | `layout.rs:185-191`; `rg ∈ [0, 2⁷)` so `rg − 2⁷ < 0` always | `byte(A_RGL)` fails too, and fails for the same reason — a negative value is `p − 128 + rg` in `Fp`, in neither lookup's table. Name both. |
| T-C7 | lines 1122-1124 (§G.2 rubric): "each isolates one relation … what the tamper recomputes so that no *other* check fires first" | the draft's own rows | **T-g1, T-h1, T-h2 and T-u2 each fire two or three independent catches**, so the table does not do what its rubric claims (§8.2). T-g1 also breaks the activation lookup (`a16` is not recomputed); T-h1 and T-h2 also break `SC_DZC`'s host term (`z16`/`rd` are not recomputed, but `SC_DMM`'s claim moves with `h16`); T-u2 also breaks `host2`. Either recompute the chain in each row or drop the "isolates one relation" claim; a test that can pass for three reasons cannot be used to confirm that one relation is present. |
| T-C8 | line 1096 (§G.1): the rejection message is quoted as ``slot 14 [03 D zero-check (hosts 12)]: …`` , and line 1117 asks for "a second assertion that the error string names slot 14" | `layout.rs:308` (`SLOT_NAMES[SC_DZC] = "03 D zero-check (hosts 12)"`), `argument.rs:307` (`format!("slot {s} [{}]: {e}", SLOT_NAMES[s])`) | The name string **must change** in the same commit, because `SC_DZC` now hosts two slots (§C.2 line 638). Quote the new string, or assert on the slot index alone. As written the draft pins a string that Tier 2 itself invalidates. |
| T-C9 | line 886 (§D.4): "new `H` helper planes | ~8 + 1 | **9** | the draft missed the `Dom::D` growth and the extra table helper, and over-counted `Dom::F`" | the Tier-1 estimate at `ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:674` is `~8 + 1` | `~8 + 1 = 9` and the derived value is 9: the two **agree**. The "why they differ" cell describes offsetting errors inside a total that does not differ. Say so, or drop the row. |

### NOTE

| # | Note |
|---|---|
| T-N1 | **Decision 5 is not merely elegant, it is load-bearing, and the draft under-argues it.** Wherever `u16(x) = 0`, `f0` reads `a16·u16 = 0` and pins nothing about `a16(x)`; `f0` is the only other relation `a16` appears in. So the rejected alternative — a class lookup on `g8` and a class lookup on `a16` — would leave `a16` (and with it `h16` and `z16`) **free at every index where the up matmul happens to be zero**. Add that sentence to §I.1 decision 5 (lines 1214-1217); it converts a style preference into a soundness requirement. |
| T-N2 | **The three-table LogUp soundness constant, which §I.3(c) leaves open.** Tags: `g_u8 = γ·133`, `g_exp = γ·129`, `g_act = γ·134` (`protocol.rs:313-314` pattern, `tables_attn.rs:70`, `:49`, and 134). Witness rows grow 49,152 → 63,488 (61,440 U8 + 2,048 exp + 512 act). Cross-family pole collisions need, e.g., `(i − i′) + β(E_i − act_{i′}) − 5γ = 0` with `β, γ` independently drawn at `protocol.rs:310-311` **after** the `A` root (`:300`): ≤ 256²/|Fp2| per family pair. Total soundness error stays ≈ 2⁻¹¹², i.e. the accepted component's, scaled by 1.3. **Sharing one `(β, γ, α)` draw across three tables weakens nothing.** |
| T-N3 | **The activation table is the first LogUp table in this module with NEGATIVE values** (`exp ∈ [0, 2⁹]`, `layout.rs:218`; `act` is a signed i16 table). `table_values_act` must embed them with `k()` = `Fp2::from_i64` (`argument.rs:479-481`), exactly as `lk_tables` does for the `sym()` constant `−1` coefficients (`argument.rs:449`). Prover and verifier build the table from the same words, so there is no divergence, but the draft should say which embedding, because D9 (the `fp()` reduction bias) sits next to this. |
| T-N4 | **§B.4 half-states the `layout.rs` surgery.** It says `protocol.rs:50`'s `p == H_GU8 \|\| p == H_GEXP` test "gains a third arm" (right), but not that `h_dom`'s hard-coded plane ranges (`layout.rs:170-174`, literal end-values like `H_D0..=10`) must be rewritten for the widened `Dom::D` block **and** for a new `Dom::F` range that must contain `H_FACT` — which is a `Dom::F` plane but not a `U8` helper, exactly as `H_SEXP` sits inside `H_S0..=H_SEXP` (`layout.rs:173`). |
| T-N5 | **`A_MACT` must be one of the last planes.** `protocol.rs:258` checks `wit.planes.len() != N_WITNESS` and `a_dom(p)` only for `p < N_WITNESS`, and `a_dom`'s fallback is `_ => Dom::Tab` (`layout.rs:150`), so the three derived histograms must occupy `N_WITNESS..N_A`. §B.2 (line 365) says `N_WITNESS` grows by 14 but not that `A_MU8`, `A_MEXP`, `A_MACT` must be the last three. |
| T-N6 | **`witness.rs`'s shared requantizer panics at `sh = 0`.** `fn requant(acc, sh: u32)` computes `1i64 << (sh - 1)` (`witness.rs:47`), which underflows at `sh = 0`; `quantize` (`:56-68`) calls it. §A.4's conclusion (no `ru` plane) is right, but the Tier-2 witness builder must not route the up matmul through `quantize` at all. Worth one line in §A.4. |
| T-N7 | **`Points` must gain four fields, and `r_tf` must be stored.** §C.1 draws `r_tf`, `p_g`, `p_u`, `p_z` but never says they are stored in `Points` (`argument.rs:121-133`), nor that `SC_GMM` must write `r_tf` there for `SC_UMM` to reuse it — the mirror of `pts.r_q = tr.challenge_fp2_vec(5)` at `argument.rs:561`. The Tier-1 check raised the same omission for `r_t2` (its N-3). |
| T-N8 | **`MAX_WIRE_BYTES` is a hard refusal and §D.3 never mentions it.** `wire.rs:26` caps the frame at 4 MiB, enforced at `:74` and `:145`. The derived whole-block total 2,816,472 B is **67.1 %** of it — better than the Tier-1 check's N-6 estimate of ~74 % for the memo's ~3.1 MB guess. Worth a line, because it is a refusal, not a budget. |
| T-N9 | **`Layout::describe()`'s calibration line does not carry the FFN shifts.** `layout.rs:489` prints the attention shifts only, so `schedule_digest` (`:502-510`) would not bind `SH_G/U/H/Z`. §F puts them in the `"parameters"` label instead (line 1000), which is absorbed at step 4, before every challenge — so nothing is late either way (§9). But the memo should say that `describe()` must grow too if the schedule digest is meant to cover the calibration. |
| T-N10 | **The Tier-1 check's C-6 rule does not extend to Tier 2.** C-6 gives `helper_sums_published_n4 = 2 × (H claim sites)` (70 accepted, 84 Tier 1); the whole block measures **100**, not `2 × 51 = 102`. The rule that holds on all three is `disclosed_dim = 2 × (modelled helper columns) + 6`, with `rank_of_the_sums = 2 × helpers` exactly: 64+6 = 70, 78+6 = 84, **94+6 = 100** (§7.5). The coincidence with `2 × H sites` broke because Tier 2 adds a third TAB table helper. |
| T-N11 | **Citation drift, harmless.** `argument.rs:581` for `pts.p_a = point` is `:580` (`:581` is the closing brace); `private_attention.rs:93-105` for the structural validation is `:83-99` (the `exp` value check is `:97-99`); `layer.rs:1202-1205` for the all-zero `ru` column is `:1204-1207`; `protocol.rs:84-127` for `audit_claims` is `:84-128`; `scripts/zk60_attention_native_inventory.py:1085-1100` for `NOTE_EXPECT` is `:1083-1094`; `causal_oracle.rs:199-200` for the weight-order comment is `:200-201`. (`lib.rs:127-129` for "(output, input)" **is** exact — the sentence ends on 129.) Everything else I opened (about seventy citations across the kernel, `layout.rs`, `argument.rs`, `protocol.rs`, `witness.rs`, `wire.rs`, `private_attention.rs`, `tables_attn.rs`, `mle.rs`, `layer.rs`, `zk.rs`, `export_v3.rs`, `causal_oracle.rs`, R-2) is exact — including the four the draft's whole argument turns on: `lib.rs:629` (`I8`), `:298-300` (`sh <= 0`), `argument.rs:679` (the biased host form) and `:505-507`/`:721` (the two-column lookup). |
| T-N12 | **§H's row-budget arithmetic checks out.** `L = (log T + log F + 1)·4 + 2 ≤ 256` gives `log T + log F ≤ 62` (line 1173), correct: `(n+1)·4 ≤ 254 ⇒ n ≤ 62.5 ⇒ n ≤ 62`. The rest of §H is a statement of what scales, and I found nothing wrong in it; the power-of-two obstacle it names is the real one and it is honestly labelled as out of scope. |

## 2. The five relations against the integer kernel

### 2.1 The requantization identity and its rounding bias

`requant` (`private-block-kernel/src/lib.rs:298-308`) is, for `sh > 0`,
`Ok(add(acc, 1i64 << (s - 1))? >> s)`. `>>` on `i64` is an arithmetic shift, so
`y = ⌊(acc + 2^(sh−1)) / 2^sh⌋` and, writing `r' = acc + 2^(sh−1) − y·2^sh`,

```
acc = 2^sh·y + r' − 2^(sh−1),     r' ∈ [0, 2^sh)      EXACT over Z
```

**Confirmed, including the bias.** The draft's §A.1 (lines 70-94) states this
identity correctly and — the part that matters — states correctly that **the
attention module commits the BIASED remainder `r'`, not the balanced `r`**:
`witness.rs:56-68`'s `quantize` pushes `rem + (1i64 << (sh - 1))`, and the
built host term at `argument.rs:679` is literally
`k(1 << SH_QKV).mul(at(A_Q8)).add(at(A_RQL)).sub(half)` with
`half = k(1 << (SH_QKV - 1))` (`:670`). The existing feed-forward prover uses
the balanced form (`export_v3.rs:296-305`, equivalence stated at
`layer.rs:1194-1201`); Tier 2 follows the module. Both citations are exact.

For `sh ≤ 0`, `requant` returns `shl(acc, |sh|)` (`lib.rs:299-300`), i.e.
`acc·2^{−sh}`, with **no remainder term at all**. At `SH_U = 0` this is the
identity map. Confirmed.

`requant_all` (`lib.rs:312-321`) refuses the whole site on any out-of-class
result — "NO clamping" (`lib.rs:27-28`). Each class below is therefore a
*refusal condition* the proof must reproduce as a range obligation, as the
draft says (lines 96-100).

### 2.2 R1–R5, each against the source

| # | Draft's identity | Kernel | Verdict |
|---|---|---|---|
| R1 | `gacc[t,j] = Σ_{i<16} nm[t,i]·Wg[i,j]`; `gacc = 2⁷·g8 + rg − 2⁶`, `g8 ∈ [−128,127]`, `rg ∈ [0,2⁷)` | `:627-629`: `matmul_in_out(&nm, &w.wg_t, D, F, &mut g)` (`:363-377`, `out[t,j] = Σ_i x[t,i]·w[i·outer+j]`) then `requant_all(&mut g, SH_G, I8, "FFN gate")`, `SH_G = 7` (`:81`) | **EXACT.** Including the `(input, output)` storage of `wg_t` (`:139`, comment `:127-128`). |
| R2 | `a16[t,j] = act[g8[t,j] + 128]` | `:633-637`: `usize::try_from(g[idx] + 128)` then `tab.act.get(slot)`, `act: [i16; 256]` (`:182`) | **EXACT.** Both refusals (`Range("FFN gate")` at `:635` and `:636`) are the same condition as `g8 ∉ [−128,127]`, as the draft says (lines 130-132). |
| R3 | `u16 = uacc` exactly, class int16, **no remainder** | `:630-632`: `requant_all(&mut u, SH_U, I16, "FFN up")`, `SH_U = 0` (`:82`), `requant(·,0) = shl(·,0)` (`:299-300`) | **EXACT.** `SH_U = 0` removes the plane, its limbs, its lookups, the `2^sh` coefficient and the `−2^(sh−1)` constant. Confirmed against `export_v3::requant_round`'s `sh <= 0` branch (`:297-299`, all-zero remainder vector). |
| R4 | `hacc = a16·u16`; `hacc = 2¹⁴·h16 + rh − 2¹³`, `h16 ∈ int16`, `rh ∈ [0,2¹⁴)` | `:638-642`: `hh[idx] = mul(a[idx], u[idx])` then `requant_all(&mut hh, SH_H, I16, "FFN product")`, `SH_H = 14` (`:83`) | **EXACT.** |
| R5 | `zacc[t,i] = Σ_{j<16} h16[t,j]·Wd[j,i]`; `zacc = 2⁶·z16 + rd − 2⁵`, `z16 ∈ int16`, `rd ∈ [0,2⁶)` | `:643-645`: `matmul_in_out(&hh, &w.wd_t, F, D, &mut z)` then `requant_all(&mut z, SH_Z, I16, "FFN down")`, `SH_Z = 6` (`:84`) | **EXACT.** `wd_t: [i8; F*D]` (`:141`), `(input, output)`. |

**The three claims the brief singles out.**

1. **"The gate output class is `I8 = [−128,127]`, not the symmetric `I8N`."**
   **CONFIRMED.** `requant_all(&mut g, SH_G, I8, "FFN gate")` at `lib.rs:629`
   passes `I8 = (-128, 127)` (`:95`); every attention quantity passes
   `I8N = (-127, 127)` (`:94`, used at `:534-536`, `:542-543`, `:560`, `:596`,
   and by `rms_norm` at `:403`). The module's `sym()` (`layout.rs:193-195`)
   proves `v + 127 ∈ U8 ∧ 127 − v ∈ U8`, i.e. exactly `[−127, 127]` (R-2
   brute-forced this, `…_REVIEW_R2.md:103`), so `sym(A_G8)` would make an
   honest `g8 = −128` unprovable. The draft's §A.2 (lines 122-128) and decision
   6 are right, and this is the one place where copying the attention idiom
   verbatim would be a completeness bug.

2. **"`SH_U = 0` removes the up remainder entirely."** **CONFIRMED** (R3 above).
   Note the existing feed-forward prover still commits a `ru` column
   (`layer.rs:1396`, `lay.ru[b]`, tagged `g_ru`) because it supports negative
   `sh_u` generally (`layer.rs:1204-1207`); at `SH_U = 0` exactly the column is
   identically zero and the module has no mechanism that needs it.

3. **"Weights are `i8` including `−128`."** **CONFIRMED.**
   `wg_t/wu_t/wd_t: [i8; …]` (`lib.rs:139-141`) and the doc comment
   "Any i8 word (including -128) is accepted; the caller must authenticate the
   words" (`lib.rs:129-130`). So `|W| ≤ 128`, which is what §E uses.

### 2.3 Is every feed-forward plane pinned? Plane by plane

The brief's central question. Starting from `nm = A_YM` (pinned in Tier 1 by
`norm_m`'s `c6`/`c7` and `sym(A_YM)`), and writing `~` for the multilinear
extension, each row below names the relation, the point at which it is
asserted, and why that determines the plane.

| Plane | Pinned by | Argument |
|---|---|---|
| `A_G8`, `A_RGL` | `SC_FZC`'s `host1 = 2⁷·g8 + rg − 2⁶` batched under `ν₀·eq(p_g, x)` against `SC_GMM`'s claimed sum | `Σ_x eq(p_g,x)·host1(x) = 2⁷·g8~(p_g) + rg~(p_g) − 2⁶` (`Σ_x eq(p,x) = 1`), and `SC_GMM`'s sum is `Σ_i nm~(r_tf,i)·Wgfold(i) = gacc~(p_g)` by the same factorisation R-2 verified for the four built matmuls (`…_REVIEW_R2.md:53-56`). `p_g` is drawn at slot 11, long after `A` is committed (`protocol.rs:296-300`), so the MLE identity at one random point forces it everywhere. With `rg ∈ [0,2⁷)` a complete residue system mod 2⁷, the pair `(g8, rg)` is then **unique** given `gacc`. |
| `A_A16` | `SC_FZC`'s `f_act` + the `SC_TAB` triple + the one value-0 sum claim on `H` | the pair `(g8 + 128, a16)` is forced onto one row of the public 256-row table (§3). Note this is the **only** relation that pins `a16` where `u16 = 0` (T-N1). |
| `A_U16` | `SC_FZC`'s `host2 = u16` under `ν₁·eq(p_u, x)` against `SC_UMM`'s claim | `u16~(p_u) = uacc~(p_u)` at a random point ⇒ `u16 = uacc` pointwise in `Fp`; both are integers below `2¹⁸` and `2¹⁵`, so equal over `Z`. |
| `A_UL0`, `A_UL1` | `f1 = u16 + 32768 − (UL0 + 256·UL1)` + `byte(A_UL0)`, `byte(A_UL1)` | R-2's exact int16 pattern (`…_REVIEW_R2.md:102`). |
| `A_H16` | `f0 = a16·u16 − 2¹⁴·h16 − rh + 2¹³` | given `hacc = a16·u16` and `rh ∈ [0,2¹⁴)`, `h16` is **unique**. |
| `A_HL0`, `A_HL1` | `f2` + two byte lookups | as `f1`. |
| `A_RH0`, `A_RH1` | `f0` + `byte`, `byte`, `scaled(·,4)` | `rh ∈ [0,2¹⁴)` exactly (§4). |
| `A_Z16`, `A_RDL` | `SC_DZC`'s `host2 = 2⁶·z16 + rd − 2⁵` under `ν₁·eq(p_z, x)` against `SC_DMM`'s claim `zacc~(p_z) = Σ_j h16~(r_td,j)·Wdfold(j)` | same argument as `host1`; with `rd ∈ [0,2⁶)` the pair `(z16, rd)` is unique given `zacc`. |
| `A_ZL0`, `A_ZL1` | `c10 = z16 + 32768 − (ZL0 + 256·ZL1)` + two byte lookups | `z16 ∈ int16`, the class Tier 1 defers (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:501-506`). |
| `A_X2` | Tier 1's `c8` (limbs) and `c9 = x2 − x1 − z16` | now that `z16` is derived rather than free, `c9` **produces** `x2` instead of defining `z16`. |
| `A_MACT` | the value-0 LogUp sum claim on `H` (`protocol.rs:47-57`) | multiplicities are field elements; they enter only field relations, exactly as `A_MU8`/`A_MEXP` (`…_REVIEW_R2.md:135`). |

**Verdict: no free plane.** Every zero-check term separates per entry because
`τ` is a fresh 9-variable challenge drawn inside the slot
(`argument.rs:526, 543, 615, 654, 695, 735, 756` for the built slots; the same
form for `SC_FZC`), and each host part separates through a nonzero-checked `ν`
(`argument.rs:472-477`) — R-2's §0 item 1, which transfers unchanged to the two
new host groups. The chain `x_in → … → nm → (g8, u16) → a16 → h16 → z16 → x2`
closes link by link, and §0's diagram (lines 36-43) is accurate.

**One structural condition the draft states and the implementer must honour**
(§C.2 lines 640-644): the `Dom::D` planes and the `Dom::F` planes must each be
a contiguous run of plane indices, because `a_dom` is a match on index ranges
(`layout.rs:141-152`) and `b.a_range(first, last)` walks `first..=last`
(`argument.rs:413-419`). My whole-block schedule (§7) places them that way and
the tools accept it; a different ordering is a build-time error, not a design
choice.

## 3. The activation lookup doing double duty

### 3.1 The construction is the exp table's, verbatim

`SC_TAB` today (`argument.rs:732-748`) is two identical
`(multiplicity, helper, public values)` triples batched under `mu[0]`, `mu[1]`,
each relation `v[helper]·(α − v[table]) − v[mult] = 0` (`:743-744`), times
`eq(τ)`. The exp table's public values are
`(0..N).map(|i| k(i) + β·k(public.exp[i]) + g_exp)` (`:505-507`) and its
witness-side value is `δ + β·E + g_exp` inside `cx` (`:721`). The draft's third
triple `(A_MACT, H_GACT, table_values_act)` under `mu[2]` with
`r2 = v[8]·(α − v[9]) − v[7]` is the exact image, and the table-index
arithmetic checks: with the six existing tables at 0..6 the new ones land at 7,
8, 9, which is what §C.1 line 607 uses. `mu` goes `challenge_fp2_vec(2)` →
`(3)` (`:734`, draft line 604). **Degree is unchanged**: `v[8]·v[9]` is
private × public = 2, times `eq(τ)` = 3, so `SLOTS[SC_TAB]` stays `(8, 1, 3)`,
`L = 9·3 + 2 = 29`. Confirmed, and the CFS tool agrees (`SC_TAB` standalone
rank 28 = `N·d + 1`, §7.4).

### 3.2 Is the combination challenge drawn after the commitments? Yes

`protocol.rs`: `a_data` receives the witness planes and the histograms
(`:270-292`), `commit_zk_owned` (`:296`), `absorb_root(b"A", …)` (`:300`),
`tr.absorb(b"M", …)` (`:306`), **then** `β = tr.challenge_fp2()`,
`γ`, `α` (`:310-312`), then `g_u8 = γ·TAG_U8`, `g_exp = γ·TAG_EXP` (`:313-314`;
verifier mirror `:410-414`), then `H` (`:346-350`). `A_MACT` is written in the
same block as `m_u8`/`m_exp` (`:289-292`) and so is inside the `A` root.
**The LogUp premise holds for the third table exactly as R-2 checked it for the
first two** (`…_REVIEW_R2.md:75-87`). The draft's §F step 9 (lines 1005-1013)
is right, and "nothing new is absorbed" (line 276) is right: the tag is a
compile-time constant of both sides.

### 3.3 Is tag 134 free? Yes, repo-wide

Every LogUp tag definition in the repository (`grep` for
`const TAG` / `fn tag_`):

| Where | Values |
|---|---|
| `hashline/src/layer.rs:33-37` | `TAG_SILU 1`, `TAG_INT8 2`, `tag_range(sh) = 16 + sh` |
| `zkp-core/src/ffn_v3/statement.rs:34-35, 47-49` | `TAG_ACT16 3`, `TAG_INT16 4`, `tag_rem_v3(sh) = 64 + sh + 8` ∈ 64..=88 |
| `hashline/src/tables_attn.rs:47-79` | `TAG_U16 128`, `TAG_EXP 129`, `TAG_PROB 130`, `TAG_INT8A 131`, `TAG_INT16A 132`, `TAG_U8 133`, `tag_srem(w) = 160 + w`, `tag_win(sh) = 192 + sh` ∈ 192..=216, `tag_srem_a(w) = 256 + w` ∈ 256..=296, `tag_win_a(sh) = 320 + sh + 16` ∈ 320..=376 |

**134 is in none of them**, and it is the next free scalar after `TAG_U8 = 133`
in the attention namespace. The draft's decision 4 is right, its refusal to
reuse `TAG_ACT16 = 3` is right (`tables_attn.rs:29` declares the namespaces
disjoint; `TAG_ACT16` is live at `zk.rs:2557`), and its line references
(`tables_attn.rs:47-70`, `:28-30`, `:29`) are exact. This also discharges the
Tier-1 check's C-9, which asked for the tag to be allocated *into*
`tables_attn.rs` rather than beside it — Tier 2 does exactly that.

### 3.4 Does sharing one `(β, γ, α)` draw across three tables weaken anything?

**No.** The identity is one rational function of `α`; a zero at a random `α`
forces every residue to cancel, and residues at distinct poles are independent.
Two families collide only when their denominators coincide, e.g.
`i + β·E_i + 129γ = i′ + β·act_{i′} + 134γ`, i.e.
`(i − i′) + β·(E_i − act_{i′}) − 5γ = 0`: for each of the ≤ 256² pairs this is
one equation in the independently drawn `(β, γ)`, so ≤ 2⁻¹²⁰ per family pair.
Within the act table, rows `i ≠ i′` collide only if `β = (i′ − i)/(act_i −
act_{i′})`, again a single value — the same argument the exp table already
needs, since `exp` is non-injective too (`lib.rs:207`'s monotone check permits
plateaus). The witness-row count grows 49,152 → 63,488, so the union bound
grows by a factor 1.3 and stays ≈ 2⁻¹¹². See T-N2.

**One thing that is genuinely new**: the act table is the first table in this
module whose *values* are signed (T-N3).

### 3.5 Does `a16`'s int16 class really follow from the table?

**In the kernel, yes; in the proof as the draft specifies it, no.** The table
row forces `a16(x) = act[i]` in `Fp` for some `i ∈ [0,256)`, so `a16`'s class is
*exactly* the value set of the public table. In the kernel that set is
`[−32768, 32767]` by construction (`act: [i16; 256]`, `lib.rs:182`). In the
proof, the public statement is the module's own struct and its analogue for
`exp` is a `Vec<i64>` whose range is enforced by an explicit check
(`private_attention.rs:66`, `:97-99`) — a check §F declines to add for `act`.
**This is finding T-B1.** Fix it and the draft's conclusion ("no separate range
proof is needed on `g8` or `a16`") becomes correct and well-founded.

The `g8` half of the conclusion needs no fix and is **confirmed**: the lookup
gives `g8 + 128 = i ∈ [0,256)`, i.e. `g8 ∈ [−128,127]` exactly — the right
window (`I8`), for free, and with no dependence on the table's *values*.

## 4. The sub-byte range proofs

The draft's three patterns, checked against the accepted module and against
R-2's brute force.

| Pattern | Draft | Accepted precedent | R-2 | Verdict |
|---|---|---|---|---|
| `rg ∈ [0, 2⁷)` | `byte(A_RGL)`, `scaled(A_RGL, 2)` (§B.3 rows 0-1) | `layout.rs:236`: `byte(A_RQL), scaled(A_RQL, 2)` — the QKV remainder at `SH_QKV = 7`; also `:232`, `:238`, `:245`, `:247`, `:248` | `…_REVIEW_R2.md:106`, EXACT | **Confirmed, cited line exact.** |
| `rd ∈ [0, 2⁶)` | `byte(A_RDL)`, `scaled(A_RDL, 4)` (§B.3) | `layout.rs:252`: `byte(A_RSL), scaled(A_RSL, 4)` — the score remainder at `SH_S = 6` | `…_REVIEW_R2.md:107`, EXACT | **Confirmed, cited line exact.** |
| `rh ∈ [0, 2¹⁴)` | `byte(A_RH0)`, `byte(A_RH1)`, `scaled(A_RH1, 4)` (§B.3 rows 6-8) | `layout.rs:254`: `byte(A_SR0), byte(A_SR1), scaled(A_SR1, 4)` — the softmax `ρ_s` at `WRHO_S = 14` | `…_REVIEW_R2.md:109`, EXACT | **Confirmed, cited line exact.** |

**Soundness, with the bound stated.** `byte(p)` puts `v` in the 256-row `U8`
table, so `v ∈ [0,256)` as an integer. `scaled(p, k)` constrains `k·v` **in
`Fp`**; with `v < 256` already forced, `k·v ≤ 255·4 = 1,020 ≪ p = 2⁶⁴ − 2³² +
1`, so there is no residue class other than the integer one and the field
constraint *is* the integer constraint. This is R-2's own observation
(`…_REVIEW_R2.md:118-121`) with `k ≤ 4` instead of `k ≤ 128`; the largest
`scaled` product anywhere in Tier 2 is 1,020 (§6 item 12). Exactness in both
directions — nothing inside the window unrepresentable, nothing outside it
representable — is R-2's brute force, and Tier 2 invents no new pattern, so the
draft's claim that "no new brute-force is owed — only a re-run of
`limb_windows.py` on the grown list" (lines 953-954) is right.

**One completeness point the draft does not make and should not need to**:
`rd ∈ [0, 2⁶)` is a 64-wide window and `2⁶·z16 + rd − 2⁵ = zacc` requires `rd`
to be a complete residue system mod 64 — it is, which is why `(z16, rd)` is
unique. Same for `rg` mod 128 and `rh` mod 2¹⁴.

## 5. Slots, hosts, sites, counts — recomputed

### 5.1 The arithmetic, independently

`rows_of(log) = ⌈2^log/256⌉` (`layout.rs:399-401`); `Dom::F` at log 9 → 2 rows
per `A` plane and 4 per `H` plane (`H` planes are Fp2: a `re` and an `im` slice,
`layout.rs:438-445`).

```
A data rows   T   4 x 1 =  4     (A_D, A_DSQ, A_DM, A_DSQM)
              Ht  2 x 1 =  2
              L   2 x 2 =  4
              D  35 x 2 = 70     (32 Tier-1 + A_ZL0, A_ZL1, A_RDL)
              F  11 x 2 = 22
              Q   7 x 2 = 14 ; Kv 6 x 1 = 6 ; S 11 x 8 = 88 ; Tab 3 x 1 = 3
                        = 213                      (184 + 29)
A sites   1+1+22+2+2+1+1+1+2+2+1+1+1+1+37+8+7+13+11+3+0+1+1 = 120   (102 + 18)
A rows    213 + 2*120 + 2 = 455
H data rows   L 1x4=4 ; D 19x4=76 ; Q 7x4=28 ; Kv 6x2=12 ; S 8x16=128 ;
              F 6x4=24 ; Tab 4x2=8            = 280                 (246 + 34)
H sites   1 + 19 + 7 + 6 + 8 + 6 + 3 + 1 = 51                       (42 + 9)
H rows    280 + 2*51 + 2 = 384
M rows    2*23 + 4 = 50        functionals 23 + 5 + 6 = 34
U8    2*512 + 38*512 + 9*512 + 13*512 + 12*256 + 13*2048
    = 1024  + 19456  + 4608  +  6656  +  3072  + 26624 = 61,440
rounds  main 159, ext 25 ;  sum (m+e)(d+1) = 626 + 3*15 + 50 = 721
terminals 120 + 51 + 2 = 173
```

`SC_DZC`'s 37 = 35 full-row `Dom::D` planes inside `a_range` + the `A_D`
broadcast slice + the `A_DM` broadcast slice (the accepted 20 is 19 + the `A_D`
slice, `argument.rs:618-619`); its `H` sites equal `helpers(Dom::D).1`
(`argument.rs:620-623`), so 19. `SC_FZC`'s 11 `A` sites are the `a_range`
planes, its 6 `H` sites the five `U8` helpers plus `H_FACT`, mirroring
`SC_SZC`'s 7 + `H_SEXP` = 8 (`argument.rs:702-706`, `H_SITES[SC_SZC] = 8`).

### 5.2 The table the brief asks for

| Quantity | Draft (§D.2 / §D.3) | My value | Tool (§7) | Agree |
|---|---:|---:|---:|---|
| `A` data rows | 213 | 213 | 213 | yes |
| `A` claim sites | 120 | 120 | 120 | yes |
| `A` site-pair rows | 240 | 240 | 240 | yes |
| **`A` rows** | **455** | **455** | **455** | **yes** |
| `H` data rows | 280 | 280 | 280 | yes |
| `H` claim sites | 51 | 51 | 51 | yes |
| `H` site-pair rows | 102 | 102 | 102 | yes |
| **`H` rows** | **384** | **384** | **384** | **yes** |
| CFS slots | 23 | 23 | 23 | yes |
| slot kinds priv/standalone/host | 12/5/6 | 12/5/6 | 12/5/6 | yes |
| host groups | 6 | 6 | 6 | yes |
| **`M` rows** | **50** | **50** | **50** | **yes** |
| **`M` functionals** | **34** | **34** | **34** | **yes** |
| largest `L` | 50 (`SC_SZC`), headroom 206 | 50 | 50, headroom 206 | yes |
| `A` opening groups | 35 `[E]` | 35 | **35, derived** | yes — drop the tag (T-C3) |
| `H` opening groups | 9 `[E]` | 9 | **9, derived** | yes — drop the tag (T-C3) |
| `U8` lookups | 61,440 | 61,440 | 61,440 | yes |
| exp / act lookups | 2,048 / 512 | 2,048 / 512 | 2,048 / — | yes |
| main + ext rounds | 159 + 25 | 159 + 25 | 159 + 25 | yes |
| `Σ (m+e)(d+1)` | 721 | 721 | 721 | yes |
| terminals | 173 | 173 | 173 | yes |
| `SC_DZC` `A`/`H` sites | 37 / 19 | 37 / 19 | 37 / 19 | yes |
| `SC_FZC` `A`/`H` sites | 11 / 6 | 11 / 6 | 11 / 6 | yes |
| `SC_TAB` `A`/`H` sites | 3 / 3 | 3 / 3 | 3 / 3 | yes |
| `hosts_by_index` | `{2:[0,1], 14:[10,13], 15:[5,9], 16:[6,7], 17:[4,8], 18:[11,12]}` | same | same | yes |
| receipt bytes | 2,816,472 | 2,816,472 | — | yes |

**No disagreement.** Every Tier-2 delta and every whole-block total in §D is
correct, and the two `[ESTIMATE]` tags are now derived (T-C3). The byte model
is right in value and wrong in form (T-C1, T-C2); recomputed from
`wire.rs:28-36`: `136 + 14,672 + 243,712 + 1,327,104 + 968,704 + 262,144 =
2,816,472`, i.e. `16·(23 + 721 + 173)`, `32,768 + 256·(8 + 400 + 32 + 384)`,
`opening_len(35, 455) = 36·8,192 + 256·4,032`, `opening_len(9, 384) =
10·8,192 + 256·3,464`, `2·opening_len(1, 7)`. That is **+25.4 %** on the
accepted component and **+11.9 %** on Tier 1, both as the draft says, and
**67.1 %** of `MAX_WIRE_BYTES` (T-N8).

### 5.3 Host-runs-after-hosted, slot lengths, the rank criterion

**Host-after-hosted** (`layout.rs:540`, `assert!(s < host)`): `0,1 < 2`;
`10,13 < 14`; `5,9 < 15`; `6,7 < 16`; `4,8 < 17`; `11,12 < 18`. **All six
hold**, and the CFS tool's own check ("host X's hosted slots all precede it in
transcript order") passes on all six (§7.4). The runtime counterpart also
holds: a host consumes `acc.cs[hs]` and `acc.scalars[hs]`
(`argument.rs:272`, `:306`, `:353`), which exist only for slots already run.
The softer constraint — a slot that *uses* a point runs after the slot that
publishes it — holds too: 14 uses `p_a` (from 10) and `p_z` (from 13); 18 uses
`p_g` (11) and `p_u` (12). See T-N7 for what `Points` must gain.

**`L_s + 256 ≤ 512`** (`layout.rs:548-550`, `n·d + 2 + 256 ≤ 512`): the maximum
over all 23 slots is `SC_SZC` at `L = 50`, `306 ≤ 512`, headroom 206. The three
new matmuls sit at 12 (268) and `SC_FZC` at 42 (298). **Every slot fits**, tool
confirmed for all 23 (§7.4).

**The rank criterion**, `rank = dim S = ΣL − (k+1)`, `kernel = k+1`
(`scripts/zk60_attention_cfs_slots.py`, `analyze_hosted`; `ΣL` includes the
host's own `L`):

| Host | hosted | `ΣL` | arithmetic | rank / kernel | draft | tool |
|---|---|---:|---|---|---|---|
| `SC_TZC` | `SC_SS`, `SC_SSM` | 84 | 20+32+32 | 81 / 3 | 81/3 | **81/3 pass** |
| `SC_DZC` | `SC_WO`, `SC_DMM` | 66 | 42+12+12 | 63 / 3 | 63/3 | **63/3 pass** |
| `SC_QZC` | `SC_QMM`, `SC_PV` | 70 | 42+12+16 | 67 / 3 | 67/3 | **67/3 pass** |
| `SC_KVZC` | `SC_KMM`, `SC_VMM` | 62 | 38+12+12 | 59 / 3 | 59/3 | **59/3 pass** |
| `SC_SZC` | `SC_RS`, `SC_SCORE` | 100 | 50+38+12 | 97 / 3 | 97/3 | **97/3 pass** |
| `SC_FZC` | `SC_GMM`, `SC_UMM` | 66 | 42+12+12 | 63 / 3 | 63/3 | **63/3 pass** |

`SC_DZC` going `k = 1 → 2` is the same move Tier 1 makes for `SC_TZC`, and
`k = 2` now has five precedents. Its `nu` becomes
`nonzero(tr.challenge_fp2_vec(2))?` and `hosted` becomes
`vec![(SC_WO, nu[0]), (SC_DMM, nu[1])]`, matching `argument.rs:653`/`:671`.

### 5.4 Does `Dom::F` really need to be a new variant? Yes

The draft's decision 1 is **confirmed**, and for a sharper reason than it gives.
`Dom` keys four things: `lookups(dom)` (`layout.rs:221`), `helpers(dom)`
(`:263`), `LOOKUP_DOMS` (`:274`), and — the one the draft does not name —
`lookup_values(wit, dom)` (`protocol.rs:203-208`), which enumerates
`0..dom.len()` and evaluates each lookup's `terms` against `wit.planes[p][x]`.
Putting the `f`-cube planes into `Dom::D` would make that loop read an `f`-cube
plane at a `d`-cube index — arithmetically defined only because `F = D = 16`,
and semantically conflating `(t, i)` with `(t, j)`. It would also force
`SC_DZC` to read `f`-cube planes at `ρ_D`, and the helper block
`H_D0..` would have to cover both cubes.

**`Dom::Q` is the precedent, exactly as the draft says**: `layout.rs:64-65`
declares it "(t, h, i') (9 vars) — **same flat index as `D`**", and it exists as
a separate variant solely because it has its own lookup list
(`layout.rs:234-241`), its own helper block (`H_Q0`, `:157`) and its own
zero-check (`SC_QZC`). So the Tier-1 memo's "at this geometry `F = D = 16`, so
`Dom::D` serves" (`ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:138`) and "**no new domain
is needed**" (`:666-667`) are both wrong about the *variant*, right about the
*size*.

## 6. No-wraparound bounds

### 6.1 The method, and why the batching coefficients do not enter

R-2's rule (`…_REVIEW_R2.md:33-39`): bound each constrained expression over the
ranges **the verifier enforces**, never over what an honest prover produces,
and compare against the accepted component's worst case
`562,949,886,312,450 < 2⁴⁹` (`:172-174`).

The brief asks for the grown `SC_DZC` and `SC_FZC` terms "under their batching
coefficients as that review treats them". **R-2 treats them by showing they do
not enter.** Its §0 item 1 establishes that each relation reduces to a
*per-entry integer equation*: a zero-check `Σ_x eq(τ,x)·zc(x)` with a fresh `τ`
gives `zc(x) = 0` at every boolean `x`, and each host part separates because
the `ν` are fresh and refused when zero (`argument.rs:472-477`). The `μ`
vector's only role is to batch the `zc` terms, and it is a field element. So
`SC_DZC`'s `μ` growing 16 → 27 (Tier 1) → **30** (Tier 2: `c0..c10` plus
`helpers(Dom::D).1 = 19`) and its `ν` going 1 → **2**, and `SC_FZC`'s `μ` of 9
(`3 + 1 + 5`) and `ν` of 2, **add no integer expression to bound**. Each new
`c_i`/`f_i`/`host_i` is bounded on its own below. That is the same treatment
R-2 gave `SC_SZC`'s `μ` of 13 and `SC_QZC`'s of 8.

### 6.2 Every new expression, recomputed

Enforced windows used (and only these): `nm ∈ [−127,127]` (`sym(A_YM)`, Tier 1);
`|Wg|, |Wu|, |Wd| ≤ 128` (`lib.rs:129-130`, `:139-141`); `g8 ∈ [−128,127]` (the
activation lookup, §3); `rg ∈ [0,2⁷)`; `a16 ∈ [−32768,32767]` **subject to
T-B1**; `u16, h16, z16 ∈ [−32768,32767]`; `rh ∈ [0,2¹⁴)`; `rd ∈ [0,2⁶)`; byte
limbs `∈ [0,256)`.

| # | Expression | Where | My arithmetic | Bound | Draft | vs 2⁴⁹ |
|---:|---|---|---|---:|---:|---|
| 1 | `gacc = Σ_{i<16} nm·Wg` | `SC_GMM` sum | `16·127·128` | **260,096** < 2¹⁸ | 260,096 | OK |
| 2 | `uacc = Σ_{i<16} nm·Wu` | `SC_UMM` sum | same | **260,096** | 260,096 | OK |
| 3 | `gacc − (2⁷g8 + rg − 2⁶)` | `SC_FZC` `host1` | `260,096 + 128·128 + 127 + 64` | **276,671** < 2¹⁹ | 276,671 | OK |
| 4 | `uacc − u16` | `SC_FZC` `host2` | `260,096 + 32,768` | **292,864** < 2¹⁹ | 292,864 | OK |
| 5 | `a16·u16` | `SC_FZC` `f0` | `32,768²` | **1,073,741,824** = 2³⁰ | 2³⁰ | OK |
| 6 | `a16·u16 − 2¹⁴h16 − rh + 2¹³` | `SC_FZC` `f0` | `2³⁰ + 2¹⁴·32,768 + 16,383 + 8,192` | **1,610,637,311** < 2³¹ | 1,610,637,311 | OK — **worst new** |
| 7 | `u16 + 32768 − (l0+256l1)` | `f1` | `32,768 + 32,768 + 65,535` | **131,071** < 2¹⁷ | 131,071 | OK |
| 8 | `h16 + 32768 − (l0+256l1)` | `f2` | same | **131,071** | 131,071 | OK |
| 9 | `zacc = Σ_{j<16} h16·Wd` | `SC_DMM` sum | `16·32,768·128` | **67,108,864** = 2²⁶ | 2²⁶ | OK |
| 10 | `zacc − (2⁶z16 + rd − 2⁵)` | `SC_DZC` `host2` | `2²⁶ + 2⁶·32,768 + 63 + 32` | **69,206,111** < 2²⁷ | 69,206,111 | OK |
| 11 | `z16 + 32768 − (l0+256l1)` | `SC_DZC` `c10` | as 7 | **131,071** | 131,071 | OK |
| 12 | `2·rg`, `4·l1(rh)`, `4·rd` in `Fp` | the `U8` lookups | `2·255`, `4·255`, `4·255` | **510 / 1,020 / 1,020** | same | OK |
| 13 | `U8` multiplicities | `A_MU8` | §5.1 | **61,440** | 61,440 | OK |
| 14 | act multiplicities | `A_MACT` | `T·F` | **512** | 512 | OK |

**Every figure in §E reproduces.** Worst new expression
**1,610,637,311 < 2³¹**, which is `2¹⁸` below R-2's limit, so the whole-block
worst case is unchanged at Tier 1's `Dsq_m − D_m·D_m` = `562,949,886,312,450 <
2⁴⁹` (identical to `norm_a`'s, as the Tier-1 check established in its §3.2).
The list is also **complete in kind**: the only other new expressions are the
`f_act` value and the `Dom::F` `helper_sum` denominators, which are field
expressions with random coefficients and belong to the LogUp argument, exactly
as R-2 treats the exp lookup (`…_REVIEW_R2.md:133`) — the draft's own first
bullet at lines 958-961 says so and is right.

**The one caveat**: item 5 and hence item 6 depend on `|a16| ≤ 32768`, which
**T-B1 shows is not enforced by anything the design adds**. With T-B1 fixed,
§E holds as written.

## 7. The tools on the whole-block paper schedule

### 7.1 Step 1 — the Tier-1 outputs reproduce byte for byte

The six committed Tier-1 records were copied out, the **unmodified**
`results/zk60_private_block_construction/grow_and_run.py` was re-run from its
own directory, and every output was compared with `cmp`:

```
IDENTICAL zk60_private_block_grown_cfs_slots.json
IDENTICAL zk60_private_block_grown_hosts.json
IDENTICAL zk60_private_block_grown_inventory.json
IDENTICAL zk60_private_block_grown_pair_schedule.json
IDENTICAL zk60_private_block_grown_schedule.json
IDENTICAL zk60_private_block_grown_summary.json
```

with `self_check_accepted_claims_identical: true`, `failures: []`, exit 0.
**All six reproduce byte for byte**, so nothing in that directory changed in
content and the Tier-1 baseline the Tier-2 draft builds on is the certified one.

### 7.2 Step 2 — the whole-block driver

`results/zk60_private_block_construction/grow_and_run_whole_block.py` (new, a
copy of `grow_and_run.py` extended), run detached, log and marker
`results/zk60_private_block_construction/whole_block/grow_and_run_whole_block.{log,done}`,
**exit code 0**. Outputs in `whole_block/`:
`zk60_private_block_whole_{inventory,hosts,pair_schedule,schedule,cfs_slots,summary}.json`.

The paper schedule is Tier 1 + Tier 2 exactly as §B/§C/§D specify: 81 `A`
planes (35 `Dom::D`, 11 `Dom::F`, 3 `Dom::Tab`), 51 `H` planes (19 `Dom::D`
helpers, 5 `Dom::F` helpers + `H_FACT`, 3 table helpers, `H_U`), 23 slots in
§C.3's order with §C.3's `HOSTS`, `A_SITES`/`H_SITES` as §5.1, `Dom::F` added
to `dom_logs` (log 9) and to `LOOKUP_DOMS`, `lookup_counts` `D 38 / F 9`,
`helpers` `D 19 / F 5`. The driver keeps `grow_and_run.py`'s self-check (the
re-emitted **accepted** claim list must be identical to the committed accepted
record — it is) and asserts the built site count against the declared
`A_SITES`/`H_SITES` for all 23 slots.

**Three checker corrections are carried into the schedule** (none changes a
count): `SLOT_NAMES[SC_DZC]` is updated to name both hosted slots (T-C8);
`H_GACT` is given the `−1` sign in the LogUp sum record, which the real
`protocol.rs::logup_sum_claim` cannot yet supply (T-N4 / §B.4); and the act
table is added to the inventory's `logup_tables`. The last two are record-only
— nothing downstream of `build_inventory` consumes them (`_h_groups` takes the
`SC_TAB` `H` sites as its `tables`), and the driver says so in place.

### 7.3 Disclosed dimension, group by group and endpoint by endpoint

`failures: []` on both tools, seed 2026, `n_values = 4` (and 8 for the
`H`-with-values pair).

| Verdict | Whole-block result | Draft expectation | Agree |
|---|---:|---|---|
| `whole_A_per_column` | **0** | 0 | yes |
| `whole_A_with_values_n4` | **0** | 0 | yes |
| `whole_H_per_column` | **0** | 0 | yes |
| `group_A_g0 … g34` (all **35**) | **0 each** | 0 on the four new groups | yes |
| `group_H_h0 … h6` (all **7** modelled) | **0 each** | 0 on the one new group | yes |
| `endpoint_In_with_values_n4`, `endpoint_Out_with_values_n4` | **0**, **0** | 0 | yes |
| `whole_H_with_values_n4`, `…_n8` | **2**, **2**, `residual_is_exactly_the_public_identity = true` | exactly 2, identity true | yes |
| FA2 14.3 `rank_mask = 2m + 2n − 2 + 2n` on all-pair groups | holds for **all 35** `A` groups | must hold | yes |
| coverage | `all_pass: true`; `A` 240 mask rows after 213 data, `H` 102 after 278 | — | — |
| derived group counts | **A 35, H 9** (`H` = 8 evaluation + 1 sum; the tool models 7, dropping the `SC_ZS` site it builds itself — the same offset of 2 as Tier 1) | 35 / 9 `[E]` | yes — **estimate now derived** |
| singleton groups | A **17** (Tier 1: 14), H 2 | not predicted | — |

**On whole `H`: the residual is still *exactly* the public identity.** The
answer the brief asks for is yes: `disclosed_dim = 2` at both `n = 4` and
`n = 8`, and `residual_is_exactly_the_public_identity: true`, over the grown
`1 + 19 + 5 + 1 + 7 + 6 + 7 + 1 = 47` witness helper columns and **3** table
helpers — which is precisely the count §I.2 (lines 1280-1282) predicts.

The `A` group listing confirms the draft's four-fresh-tails argument member for
member: `SC_GMM`, `SC_UMM` and `SC_DMM` are three singleton groups (each a
fresh `(tail, 0, 256)` key — `SC_GMM` and `SC_UMM` share `r_tf` but differ in
their own `ρ`), and `SC_FZC`'s eleven `A` sites form **one** group of `m = 11`
at `ρ_F`. `SC_DZC`'s three new sites join its `m = 35` group and `SC_TAB`'s
`A_MACT` joins its `m = 3` group, both at `+0`. On `H`, `SC_FZC`'s six helpers
form one group of `m = 6` and `H_GACT` joins `SC_TAB`'s `m = 3`: `+1`.

### 7.4 The CFS criteria: host groups, standalone slots, slot lengths

`all_checks_pass: true`, `failures: []`, 23 slots in the declared transcript
order, `M` 50 rows = `2·23 + 4`, 34 functionals (one `eval` per slot, one
batched `Γ` per host, five standalone `Γ`, every private slot in exactly one
batched `Γ`, no standalone `Σ` for any private or host slot).

**Host groups** — every one passes, with exactly the draft's numbers (§5.3
table above): `SC_TZC` 84/81/3, `SC_DZC` 66/63/3, `SC_QZC` 70/67/3,
`SC_KVZC` 62/59/3, `SC_SZC` 100/97/3, `SC_FZC` 66/63/3, all with
`leaked_dim_fp2 = 0` and `kernel = k+1 = 3`, and all six pass the
hosted-precede-host check.

**Standalone** (FA6: `rank = dim S = N·d + 1`, image in `S`, `leaked = 0`,
`kernel = 1`) passes on **all twenty-three**: `SC_SS` 31, `SC_SSM` 31,
`SC_TZC` 19, `SC_LZC` 41, `SC_RS` 37, `SC_QMM`/`KMM`/`VMM` 11, `SC_SCORE` 11,
`SC_PV` 15, `SC_WO` 11, **`SC_GMM` 11, `SC_UMM` 11, `SC_DMM` 11**,
`SC_DZC` 41, `SC_QZC` 41, `SC_KVZC` 37, `SC_SZC` 49, **`SC_FZC` 41**,
`SC_TAB` 28, `SC_ZS` 19, `SC_IO_IN` 21, `SC_IO_OUT` 21 — **every value §C.4
predicts, including the four new slots**.

**Slot lengths**: `L + 256 ≤ 512` on all 23, largest `SC_SZC` at `L = 50`
(`306`), headroom 206; the three matmuls at 268, `SC_FZC`/`SC_DZC`/`SC_QZC`/
`SC_LZC` at 298, `SC_TAB` 285, `SC_ZS`/`SC_TZC` 276, the endpoints 278,
`SC_KVZC`/`SC_RS` 294, `SC_SS`/`SC_SSM` 288, `SC_PV` 272, `SC_SCORE` 268.

### 7.5 Every negative control, fired or not

**All seven CFS controls fire**: `nc_hosted_c_zero`, `nc_host_nu_zero`,
`nc_extension_degree_exceeds_mask`, `nc_qkv_unsplit`, `nc_row_budget_exceeded`,
`nc_sigma_functional_for_private_slot`, `nc_sigma_functional_for_host_slot`.
(The two `Σ` controls run on the table as a whole, so `SC_GMM`/`SC_UMM`/
`SC_DMM` are covered as private slots — §I.2's request at lines 1283-1285 is
satisfied structurally, not by three named cases.)

**All eleven rank controls fire**, accepted → Tier 1 → whole block:

| Control | accepted | Tier 1 | **whole** | verdict |
|---|---:|---:|---:|---|
| `no_mask_A_per_column` | 37 | 43 | **49** | PASS (≥ 30) |
| `no_mask_A_with_values_n4` | 208 | 256 | **304** | PASS (≥ 2·120 = 240) |
| `single_base_row_per_claim_A_per_column` | 15 | 13 | **16** | PASS — equals the derived expectation 16 (17 singleton groups, tool undercount 2) |
| `single_prox_row_singleton_pair_claim_per_column` | 1 | 1 | **1** | PASS |
| `prox_pair_singleton_pair_claim_per_column` (positive) | 0 | 0 | **0** | PASS |
| `helper_sums_published_n4` | 70 | 84 | **100** | PASS (`rank_of_the_sums` 94 = 2·47 helpers; see T-N10) |
| `zero_sum_row_without_fresh_pair_n4` | 8 | 8 | **8** | PASS (> 2) |
| `flipped_rope_SC_QZC_sharing_pair…` | 2 | 2 | **2** | PASS (≥ 2) |
| `flipped_rope_SC_KVZC_sharing_pair…` | 2 | 2 | **2** | PASS |
| `flipped_rope_SC_QZC_own_pair…` (positive) | 0 | 0 | **0** | PASS |
| `flipped_rope_SC_KVZC_own_pair…` (positive) | 0 | 0 | **0** | PASS |

**No control stopped firing.** The one the Tier-1 check flagged (C-5,
`single_base_row_per_claim` *falling* 15 → 13 on a correct implementation)
rises again to 16 in Tier 2, because the three new matmul slots add three
singleton groups — which is exactly why the pass criterion must stay "equals
the derived expectation" and never "grows". The draft does not restate the
Tier-1 memo's wrong rubric, so nothing new is owed there; the erratum stands
against the Tier-1 memo.

**Controls not implemented**, and owed (both endorsed):
§G.2's `A_H16`-shares-`A_U16`'s-pair control (lines 1144-1150) and the Tier-1
memo's `A_YM`-shares-`A_Y`'s-pair control — both need a `share_mask` pair the
driver only wires for the RoPE case. The two `flipped_rope_*_sharing_pair`
controls measure 2, so the expected value for both is ≥ 2.

### 7.6 The caveat, stated where it belongs

Everything in §7.3–§7.5 is a verdict on a **paper schedule description** that
no Rust implements. It is evidence that the whole-block *declaration* satisfies
the two models' criteria — nothing more. The models' exclusions are unchanged:
sampled columns, salted Merkle paths, the CFS channel, transcript conditioning,
integer-range side information and `A ↔ H` correlation are outside them
(`ZK60_PRIVATE_ATTENTION_NATIVE.md:79`, `…_DISPOSITION.md:35`). **Nothing here
is a privacy property of the construction, and nothing here is a property of
code.** When the layout is written in Rust, the committed inventory tool must
re-derive all of it from the source and `NOTE_EXPECT`
(`scripts/zk60_attention_native_inventory.py:1083-1094`) must be updated to
§5.2's column — Decision 12 of the Tier-1 memo, which stands.

## 8. The tamper tests of section G

### 8.1 G.1, the `z16` tamper: correct, and the catch is at the verifier

The construction (lines 1073-1080) is consistent: `z16'[k] = z16[k] + 1`,
`A_ZL0`/`A_ZL1` recomputed, `xres2'[k] = xres1[k] + z16'[k]`,
`A_X2L0`/`A_X2L1` recomputed, everything upstream untouched, a fresh output
endpoint committed to `xres2'`. Under Tier 1 alone every check passes — that is
the Tier-1 check's B-1, restated correctly.

**The claimed catch is real and is at the verifier.** Slot 14's claimed sum is
`sp.scalar + Σ coef·acc.scalars[hs]` (`argument.rs:306`), and the polynomial
carries `ν₁·eq(p_z, x)·(2⁶·z16(x) + rd(x) − 2⁵)`. Tampering `z16` at one index
moves the host side by `ν₁·2⁶·Δ·eq(p_z, k)` while `claim_{SC_DMM}` is unchanged
(`h16` and `Wd` are unchanged), so `sumcheck::verify` rejects
(`argument.rs:307`) — **in `verify_inner`**, since `argument()` is driven from
the same code on both sides (`protocol.rs:418`). The three compensations the
draft rules out are all correctly ruled out: `rd` cannot absorb `−2⁶Δ` inside a
64-wide window; `h16` is pinned by `f0` → `a16` by the activation lookup and
`u16`/`g8` by `SC_FZC`'s two host terms → `nm` → `xres1` → `x_in`; and `p_z` is
Fiat–Shamir output drawn after the `A` commitment.

One thing the draft should add: the assertion at line 1115 should also require
that the **honest** proof verifies, otherwise the test passes on any build that
is broken for an unrelated reason.

### 8.2 G.2, the other tampers: each rejects, but they do not isolate

Every row does reject at the verifier, and each names a real relation. But the
"kept consistent" column claims each isolates one relation, and four do not
(finding T-C7):

| # | Draft's single catch | What actually fires |
|---|---|---|
| T-g1 | `rg` out of `[0,2⁷)` ⇒ `scaled(A_RGL, 2)` | **`byte(A_RGL)` too** — `rg − 2⁷ < 0` always, so the first lookup already has no row (T-C6) — **and the activation lookup**, because `a16` is not recomputed and `(g8+1+128, a16)` is not a row of `act`. Three catches. |
| T-g2 | `host1` vs `SC_GMM`'s claim at `p_g`, slot 18 | correct and clean, given `g8 ≠ 127` so the new gate value stays in `I8`. This is the test that `g` is bound to `nm`. |
| T-a1 | the activation LogUp, via the one value-0 sum claim on `H` | correct. Precisely: the prover *can* satisfy `f_act` pointwise by setting `H_FACT(x) = 1/(α − w′(x))` (H is committed after `α`), and it is the **sum claim** that then fails, which is what the draft says. |
| T-u1 | `host2` vs `SC_UMM`'s claim at `p_u`, slot 18 | correct and clean. The test that `u` is bound to `nm`. |
| T-u2 | `byte(A_UL1)` / `f1` | **`host2` too** (`u16` no longer equals `uacc`). Two catches. |
| T-h1 | `f0`, slot 18 | **slot 14 too** — `SC_DMM`'s claim moves with `h16` while `SC_DZC`'s `host2` does not. Two catches. |
| T-h2 | `scaled(A_RH1, 4)` | **`byte(A_RH0)`/`byte(A_RH1)`** (no valid limbs for a negative `rh`) **and slot 14**. Three catches. |
| T-h3 | `f0` | correct and clean — the point the draft makes (the product is pinned from both sides) is right. |
| T-z1 | `rd` out of window **and** `A_ZL1` out of `[0,256)` | correct, and the draft already says "two independent catches". |
| T-z2 | §G.1 | §8.1. |

Rank: **CORRECTION, not BLOCKING** — every test rejects, so the suite is sound
as a suite; what is wrong is the claim that each row isolates one relation, and
that matters because such a suite cannot be used to confirm that a particular
relation is *present*.

### 8.3 The question the brief asks: is there a consistent tamper the draft missed?

**I could not construct one, and §2.3 says why**: every feed-forward plane is
determined, and each determination is an MLE identity at a point drawn after
the `A` commitment. I tried, in order:

1. **Change `z16` and compensate in `rd`** — impossible, `rd`'s window is
   exactly 2⁶ wide and `2⁶` is the coefficient.
2. **Change `z16` and `h16` together** — `h16` moves `SC_DMM`'s claim, and
   `h16` is pinned by `f0` from `a16·u16`, which is pinned from `nm`.
3. **Change `a16` alone where `u16 = 0`** — this is the one place `f0`
   degenerates, and it is exactly where the activation lookup earns its keep
   (T-N1). With the pair binding, `a16` is still pinned. *Without* it — i.e.
   under the rejected two-separate-lookups alternative — this is a complete
   break: `a16`, hence `h16`, hence `z16` free at every zero of `u16`.
4. **Change `u16` and `a16` keeping `a16·u16` fixed** — `u16` is pinned to
   `uacc` by `host2` and `a16` to the table by `f_act`.
5. **Exploit the shared `r_tf`** between `SC_GMM` and `SC_UMM` — the two claim
   points differ through each slot's own `ρ`, both read the same committed
   plane `A_YM`, and the two host relations are independent random-point
   identities.
6. **Exploit `H`** — `H` is committed after `α` but before every slot
   challenge, and `H` planes enter only `helper_sum`, `f_act`, the `SC_TAB`
   relations and the sum claim; no `A`-plane relation (`f0`, `f1`, `f2`,
   `c10`, `host1`, `host2`) reads an `H` plane.
7. **Grind `p_z` / `p_g` / `p_u`** — the standard attack the transcript
   refusals already treat (`argument.rs:258-261`, `:331-333`), and the same
   exposure the accepted component already has.

**So Tier 2 does close the Tier-1 hole**, subject to T-B1, which is a different
hole in the same relation (`f0`) reached from the public statement rather than
from the witness.

## 9. The transcript

The Tier-1 memo's §D order, as the Tier-1 check verified it against
`protocol.rs` (`…_CHECK.md:606-626`), is:
`1 PROFILE · 2 "expected-IO" · 3 "public-statement" · 4 "parameters" ·
5 "calibration" (new) · 6 "schedule" · 7 "A"+rows+log-cols · 8 "M" ·
9 β, γ, α · 10 "H"+rows+log-cols · 11 the slot loop · 12 mask_open ·
13-16 M, A, H, In, Out openings`.

Tier 2 changes exactly three payloads and adds four slot iterations. **Nothing
that a challenge must depend on is absorbed after that challenge is drawn**:

| Challenge | Must depend on | Absorbed at | Verdict |
|---|---|---|---|
| `β, γ, α` (step 9) | the act table's words; the committed multiplicity `A_MACT`; the `U8`/exp tables | act inside `BlockPublic::digest` at step 3; `A_MACT` inside the `A` root at step 7 (`protocol.rs:289-292` then `:296`, `:300`) | **binds** |
| `r_jg`, `r_ju`, `r_id` (slots 11, 12, 13) | `Wg`, `Wu`, `Wd`, since the verifier folds them with `eq(r_j)` | step 3 | **binds** |
| `τ_F`, `μ`, `ν` of `SC_FZC` (slot 18) | `A` and `H` roots, `p_g`, `p_u` | steps 7, 10 and slots 11, 12 | **binds** |
| `p_z` (slot 13) | the `A` root | step 7 | **binds** |
| the PCS opening challenges | everything | replayed from a clone of the post-slot transcript (`protocol.rs:168-169`, `:196-197`) | **binds** |

So §F's three conclusions are right: the activation table belongs in
`"public-statement"` and **no separate absorb should be added** (lines 984-997);
the shifts in `"parameters"` are belt and braces (lines 999-1003); `(β, γ, α)`
is unchanged and sufficient (lines 1005-1013). Two additions:

* **T-N9**: if the schedule digest is meant to cover the calibration,
  `Layout::describe()`'s calibration line (`layout.rs:489`) must gain the FFN
  shifts; today it lists the attention shifts only. Either way they are bound,
  via `"parameters"`.
* The whole-block group counts **are** transcript-bound, through
  `describe()`'s `A-groups=… H-groups=…` line (`layout.rs:487`), and a
  mis-declaration is a hard refusal on both sides (`protocol.rs:164-166`,
  `:369`, `:422`). That is one more reason to replace the `[ESTIMATE]` tags
  with the derived 35 / 9 (T-C3).

The Tier-1 check's C-10 (the `acc.order` gate is three coarse strings per slot
and covers nothing outside the slot loop, `argument.rs:255, 328, 335`) and C-11
(the `pb-*` rename is not cosmetic, the labels are in shared code at
`argument.rs:254, 274, 305, 334`) both carry into Tier 2 unchanged; §F line
1016 says "Tier 2 adds no label", which is right and does not disturb either.

## 10. The three Tier-1 errors, adjudicated

**(a) "A new `Dom` variant IS needed."** **CONFIRMED** — §5.4. `Dom` keys
`lookups` (`layout.rs:221`), `helpers` (`:263`), `LOOKUP_DOMS` (`:274`) and
`lookup_values` (`protocol.rs:203-208`); `Dom::Q` is the precedent for two
variants at the same log (`layout.rs:64-65`, "same flat index as `D`"). The
Tier-1 memo's `:138` ("a new `Dom::F` … **if `F != D`** … so `Dom::D` serves")
and `:666-667` ("**no new domain is needed**") are wrong about the variant and
must change. The Tier-2 draft's own reason is correct as far as it goes; the
`lookup_values` point strengthens it.

**(b) "The Tier-1 estimate counts five new slots while naming four."**
**CONFIRMED.** `ZK60_PRIVATE_BLOCK_CONSTRUCTION.md:677` says "new slots | 5"
and its reasoning cell names exactly `SC_GMM`, `SC_UMM`, `SC_DMM`, `SC_FZC` —
four. The derived count is **4**, and the whole block is 23 slots, 50 `M` rows,
34 functionals (§5, tool-confirmed), against the memo's `24 / 52 / 37` at
`:680`. **Worse than the Tier-2 draft says**: 37 does not follow even from 24
slots, since `N_FUNCTIONALS = slots + standalone + hosts`
(`layout.rs:533`) would give `24 + 5 + 6 = 35`. All three figures at `:680` are
wrong, and `:678`/`:679` (`~510` / `~410` rows) are conservative rather than
wrong.

**(c) "`norm_m` needs no re-derived bounds; `xres1` and `x_in` are both
int16."** **CONFIRMED as to the conclusion, CORRECTED as to the reasoning**
(T-C5). The conclusion duplicates the Tier-1 check's own C-2, which reached it
first and from the right place: the *enforced* class of `x_in` is
`byte(A_XL0)`, `byte(A_XL1)` (`layout.rs:226`) plus `c2` (`argument.rs:634`),
and of `xres1` is `byte(A_X1L0)`, `byte(A_X1L1)` (`layout.rs:232`) plus `c4`
(`argument.rs:636`) — the identical pattern, hence the identical window, hence
every `norm_m` bound bit-identical to `norm_a`'s, worst case
`562,949,886,312,450 < 2⁴⁹`. The Tier-2 draft instead argues from
`witness.rs:103`/`:108` (the honest prover's input type) and
`causal_oracle.rs:115` (`x_cls: Cls::Int16`, a calibration declaration).
Neither is a verifier-enforced range, and R-2's method
(`…_REVIEW_R2.md:35-39`) explicitly forbids using them. Right answer, wrong
warrant; replace the citations.

## 11. What was not checked

**Not run.** No `cargo` of any kind — no build, no `cargo check`, no test, no
example, no proof, no benchmark. No git write. The only Python executed was the
three committed tools (driven as §7.2 describes) and the arithmetic of §5 and
§6.

**Not derived.** (a) Completeness: I argue each honest witness satisfies each
relation; no honest proof was run, and the draft's §I.2 already owns this.
(b) The extension-round premise by full monomial expansion for `SC_FZC`'s `μ`
of 9 and `SC_DZC`'s of 30 — I checked the *degree* argument (every monomial
carries `v[0]`, `v[1]` or `v[2]`, all public `Tab::Eq`; the ceiling is the
two-lookup helper relation at 3 × `eq(τ)` = 4) but not R-2's mechanical
expansion. The draft flags this too (§I.3(c)) and it remains open — as it does
for Tier 1 (`…_CHECK.md:929-934`). (c) The LogUp soundness *error* is bounded
in T-N2 by a union bound, not re-proved from Haböck. (d) The `helper_sums` and
`no_mask_*` control values were measured, not predicted from first principles.

**Not verified.** (a) Anything about `pcs::open_zk` / `verify_zk` /
`zk::mask_commit` internals. (b) That `blake3`-digesting 256 signed words in
`BlockPublic::digest` matches the existing `to_le_bytes` loop
(`private_attention.rs:118-124`) without an endianness question — the draft's
§I.3(b) owns this, and it is a real item once `act` is signed (T-N3).
(c) `fold_cols_i8`'s re-export chain: I confirmed the definition
(`zkp-core/src/mle.rs:136-149`) and both existing imports from `crate::mle`
(`layer.rs:23`, `zk.rs:609`), but not that `argument.rs`'s `use
crate::mle::{…}` (`:27`) resolves to the same re-export.

**Not analysed.** No privacy analysis. No simulator. The §7 verdicts are model
outputs on a paper schedule under the exclusions of §7.6; they are not a
privacy property of the construction and not a property of any code. D8, D11
and D9 are untouched and remain open exactly as §I.2 says. D1, D3, D4, D5 and
D12 stand as recorded; no ruling is proposed here.

**Out of scope.** The Tier-1 memo's sections B, C.1–C.4, D, E, F, G and the
eleven H.3 decisions other than 6/7/8 were checked by the Tier-1 check, not
re-opened here; its findings are carried into the errata verbatim so the
security owner has one list.

## ERRATA AND CONDITIONS FOR ACCEPTANCE

One numbered, de-duplicated list for the security owner: the Tier-1 check's
BLOCKING finding and its eleven corrections, the three Tier-1 errors as
adjudicated here, and every BLOCKING finding and CORRECTION found in Tier 2.
Short names: **T1** = `ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` (1,401 lines),
**T2** = `ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2.md` (1,344 lines).
Entries E-1 and E-2 are BLOCKING; E-3 … E-22 are CORRECTIONS. Where the
Tier-1 check and this check found the same thing, they are merged and both
origins are named.

| # | Rank | Document and line | Source (`file:line`) | What must change, and to what |
|---|---|---|---|---|
| **E-1** | **BLOCKING** | T1 §C.2 line 501-506, §D line 700 and 719-722, §C.2 line 495-499, Decision 4 line 1299, Decision 12 line 1332 (origin: Tier-1 check B-1) | `argument.rs` has no relation reading `A_Z16` but `c9`; T1's own lookup list lines 380-388 gives it none; `argument.rs:757` is the `SC_IO_OUT` site that moves to `A_X2` | **A Tier-1-only build must not be presentable as a block.** In a Tier-1 build `A_Z16` is constrained only by `c9 = x2 − x1 − z16`, so for any int16 `xres2` a satisfying witness exists and the block statement is **vacuous on its output**. Required: (a) the block profile string `hashline-zk-mr1/private-block-t32-poc/1`, `BlockPublic` with `Wg/Wu/Wd/act`, and the `SC_IO_OUT → A_X2` change land **in the same commit as Tier 2**, never before; (b) until then a Tier-1 build keeps a distinct profile whose statement excludes `Wg/Wu/Wd/act` and whose output endpoint keeps `xres1`; (c) the verifier-side tripwire `block_output_cannot_be_chosen` (Tier-1 check §11.3) ships in the Tier-2 commit and must pass there. T2 §0 lines 13-28 states the hole correctly and §G.1 gives the catch — E-1 is the *guard*, which neither memo carries. |
| **E-2** | **BLOCKING** | T2 §E line 919, §F lines 994-997, §A.3 lines 165-171, §I.1 decision 7 lines 1223-1225 (origin: this check, T-B1) | `hashline/src/private_attention.rs:66` (`exp: Vec<i64>`), `:86` (shape only), **`:97-99`** (the exp VALUE-RANGE check); `…_REVIEW_R2.md:133`; `private-block-kernel/src/lib.rs:182` is the kernel's type, not the proof's | **`a16`'s int16 class must be enforced by the proof's own public statement.** As written, §E's row cites the kernel's `[i16; 256]` and §F asks only for `act.len() == 256`; with `act` carried as `Vec<i64>` (the shape `digest`'s `to_le_bytes` loop at `private_attention.rs:118-124` implies) the class is a caller promise, §E items 5 and 6 (`2³⁰`, `1,610,637,311`) are unfounded, `f0` can wrap `p`, and `h16` is no longer pinned. Required: `BlockPublic::new` validates `act.iter().all(\|v\| (-32768..=32767).contains(v))` (or holds `[i16; 256]`), mirroring `:97-99`; §E line 919 cites **that** check; §F line 996 requires the range check, not only the length; decision 7 carries the condition. |
| E-3 | CORRECTION | T1 line 430-433 (Tier-1 check C-1) | `argument.rs:618`, `:637`, `:757` | "`A_X1` is opened at **four** points" → **two**: `ρ_D` in `SC_DZC` and `SC_SSM`'s own point. `c5`/`c9` read `x1` at the site already counted, and a site that is *removed* is not one of the points. The site table at line 540-546 is right; only the prose is wrong. |
| E-4 | CORRECTION | T1 §H.1 line 1226-1229 **and** T2 §E lines 965-976 / §I.1 decision 14(b) lines 1254-1257 (Tier-1 check C-2; T2 error (c); this check T-C5) | `layout.rs:226` + `argument.rs:634`; `layout.rs:232` + `argument.rs:636`; `…_REVIEW_R2.md:35-39` | **Merged.** T1's premise ("`xres1` … can be twice as large as `x_in`") is wrong: both are enforced int16 by the identical two-limb, offset-32768 pattern, so every `norm_m` bound is bit-identical to `norm_a`'s, worst case `562,949,886,312,450 < 2⁴⁹`. T1 must say "a re-run, not a re-derivation". **T2 reaches the right conclusion by an inadmissible route** — `witness.rs:103`/`:108` (the honest prover's input type) and `causal_oracle.rs:115` (a calibration declaration) are not verifier-enforced ranges and R-2's method forbids them. T2 must cite `layout.rs:226`/`:232` + `argument.rs:634`/`:636` instead. |
| E-5 | CORRECTION | T1 line 620-621 and §I(d) line 1374 **and** T2 §D.3 lines 852 and 877 (Tier-1 check C-3; this check T-C2) | `hashline/src/private_attention/wire.rs:28-36` | **Merged.** The receipt byte model is **not** reverse-derived and is **not** absent from source: `opening_len(groups, rows) = (groups+1)·512·16 + 256·(8 + rows·8 + 32 + 11·32)` is `wire.rs:28-29` verbatim and the arguments term is `wire.rs:33` verbatim. Both documents must say "read out of `hashline/src/private_attention/wire.rs:28-36`" and drop "reverse-derived" / "not read out of `zkp-core/src/pcs.rs`". |
| E-6 | CORRECTION | T1 line 625 **and** T2 §D.3 line 857 (Tier-1 check C-4; this check T-C1) | `wire.rs:23`, `:25`, `:34` | **Merged.** `mask_open(M_ROWS) = 512·16 + 256·(8 + M_ROWS·8 + 32 + 15·32)` is wrong in form in **both** documents. The real terms are `2·MASK_VEC·16 = 2·1024·16 = 32,768` and `MASK_PATH·32 = 12·32 = 384`. Both errors are `M_ROWS`-independent and cancel (`32,768 − 8,192 = 256·(480 − 384)`), so 223,232 / 227,328 / 243,712 all survive **by coincidence**; anyone reusing the model at a different `MASK_VEC`/`MASK_PATH` gets a wrong answer. |
| E-7 | CORRECTION | T1 §G.2 line 1076 and the rubric at line 1069-1071 (Tier-1 check C-5) | measured: Tier 1 **13**, whole block **16** (§7.5) | `single_base_row_per_claim_A_per_column` "accepted 15 → **grows**", and "a *smaller or zero* number is a **stop**" — wrong. The control's pass criterion is **equality with the derived `native_singleton_expectation`**, not growth: it falls to 13 in Tier 1 (`SC_TZC`'s singletons become two-member groups) and rises to 16 in Tier 2 (three new matmul singletons). The rubric as written would raise a false stop on a correct implementation. |
| E-8 | CORRECTION | T1 §G.2 line 1079 (Tier-1 check C-6, refined here by T-N10) | measured: Tier 1 **84**, whole block **100** with `rank_of_the_sums = 94` | `helper_sums_published_n4` "70 → grows (~82 `[ESTIMATE]`)" — the Tier-1 value is **84**. The Tier-1 check's rule "`2 × (H claim sites)`" is a coincidence that breaks in Tier 2 (`2 × 51 = 102 ≠ 100`). The rule that holds on all three layouts is **`disclosed_dim = 2 × (modelled helper columns) + 6`**, with `rank_of_the_sums = 2 × helpers` exactly: 64+6 = 70, 78+6 = 84, 94+6 = 100. State the criterion, not the number. |
| E-9 | CORRECTION | T1 line 373-375 (Tier-1 check C-7) | `wire.rs:33-34`; `argument.rs:454-470` (`helper_sum` cannot be split across slots) | The alternative to Decision 7 ("give `A_LIMBM` its own slot at degree 3") "costs one more slot and two more `M` rows and **saves 10 bytes**" — it **costs about 16.9 kB**: arguments +512 B, `M` 42 → 44 rows (+4,096 B), `H` +6 rows (+12,288 B). Decision 7 is right; its cost comparison is inverted. |
| E-10 | CORRECTION | T1 §F.2 line 980-987 (Tier-1 check C-8) | `hashline/examples/zk60_seam_receipt.rs:26`; `hashline/tests/zk60_private_seam.rs:8, 90-93, 219`, and `:193, 202-205` | The proposed `SLOT_TAGS` table, offered as "the whole namespace", omits **10 / 11**, which is in use by the standalone `private_seam` example and test fixtures (and 1/2 also appears in negative fixtures). Add both rows. 41-48 and 61/62 are genuinely free. |
| E-11 | CORRECTION | T1 Decision 10 line 1321-1326 and §F.2 line 976 (Tier-1 check C-9) | `hashline/src/tables_attn.rs:28-30`, `:47-79` | "**Nothing enumerates either namespace today**" is true for the endpoint slot ids and **false for the LogUp table tags**: `tables_attn.rs` enumerates them and declares them disjoint from the FFN's. A block activation tag must be allocated *into* that file. **T2 does exactly this** (decision 4, `TAG_ACT = 134`), and 134 is confirmed free repo-wide (§3.3), so E-11 is a T1-only wording fix. |
| E-12 | CORRECTION | T1 §D line 709-712 (Tier-1 check C-10) | `argument.rs:255`, `:328`, `:335` | The §D order is written "at the granularity of the actual absorb calls, **because that is what the transcript-order gate compares**" — the gate (`acc.order`) holds exactly three coarse strings per slot and covers **nothing** outside the slot loop. The §D list is right (§9 of this check); its justification is not. If §D is to be enforced, `acc.order` must grow. |
| E-13 | CORRECTION | T1 Decision 5 line 1302-1305 (Tier-1 check C-11) | `argument.rs:254`, `:274`, `:305`, `:334` (all inside `run_slot`, the shared path) | Renaming `pa-slot`/`pa-scalar`/`pa-term` to `pb-*` is **not** "cosmetic": the labels are hard-coded in shared code, so the rename either forks `run_slot` per profile or changes the *attention* component's transcript and invalidates the accepted receipt and the R-1/R-2 records. Name the fork. T1's §B.1 change table (line 138-144) must list `argument.rs` accordingly. T2 §F line 1016 ("Tier 2 adds no label") is correct and unaffected. |
| E-14 | CORRECTION | T1 line 138 and lines 666-667 (T2 error (a), confirmed here §5.4 / §10) | `layout.rs:221`, `:263`, `:274`, `:64-65`; `protocol.rs:203-208` | "a new `Dom::F` … **if `F != D`** (at this geometry `F = D = 16`, so `Dom::D` serves)" and "**no new domain is needed**" are wrong about the *variant*. `Dom` keys the lookup list, the helper block, `LOOKUP_DOMS` **and** `lookup_values`'s per-domain enumeration; `Dom::Q` is the precedent for two variants at the same log ("same flat index as `D`"). Replace with: a new `Dom::F` variant is required at every geometry; only its *log* coincides with `Dom::D`'s here. |
| E-15 | CORRECTION | T1 §C.5 line 677 and line 680 (T2 error (b), confirmed and extended here §10) | derived and tool-confirmed: 23 slots, 50 `M` rows, 34 functionals (§5.2, §7.4); `layout.rs:388`, `:533` | "new slots | **5**" while the reasoning cell names exactly four (`SC_GMM`, `SC_UMM`, `SC_DMM`, `SC_FZC`) → **4**. Line 680's `24 / 52 / 37` must become **`23 / 50 / 34`**. Note 37 does not follow even from 24 slots, since `N_FUNCTIONALS = slots + standalone + hosts = 24 + 5 + 6 = 35`: all three figures are wrong. |
| E-16 | CORRECTION | T2 §D.2 lines 805-806, §D.2 lines 829-848, §D.3 line 870 (this check T-C3) | `results/zk60_private_block_construction/whole_block/zk60_private_block_whole_summary.json`; `protocol.rs:62-67`, `:164-166` | The `[ESTIMATE]` tags on the opening-group counts can be **dropped**: the committed inventory tool derives **`A` 35 and `H` 9** on the whole-block schedule, member for member, and the draft's four-fresh-tails argument is right at every step. Put `A_GROUPS = 35`, `H_GROUPS = 9` into `layout.rs`; both are transcript-bound through `describe()` (`layout.rs:487`) and a mis-declaration is a hard refusal on both sides. |
| E-17 | CORRECTION | T2 §C.1 line 576 (and line 577) (this check T-C4) | `argument.rs:706` (`let ihx = b.h(H_SEXP)?;`), `:721` (`v[ihx]`) | `f_act = v[H_FACT]·(…)` indexes a **plane** constant where the module indexes a **table index**; as written the term reads the wrong table. Change to `let i_fact = b.h(H_FACT)?;` … `v[i_fact]` (table index 19 in the draft's own listing at line 565), and bind `h0 = 14` explicitly for the `helper_sum(v, &lks, h0, alpha, &mu[4..])` call. |
| E-18 | CORRECTION | T2 §G.2 line 1127 (this check T-C6) | `layout.rs:185-191`; `rg ∈ [0, 2⁷)` ⇒ `rg − 2⁷ < 0` | T-g1's catch is named as `scaled(A_RGL, 2)` alone. **`byte(A_RGL)` fails too and always** — a negative remainder is `p − 128 + rg` in `Fp`, in neither lookup's table. Name both. |
| E-19 | CORRECTION | T2 §G.2 lines 1122-1124 (the rubric) and rows T-g1, T-u2, T-h1, T-h2 (this check T-C7) | §8.2 of this check | "each isolates one relation … so that no *other* check fires first" is false for four rows: T-g1 also breaks the activation lookup (`a16` not recomputed); T-u2 also breaks `host2`; T-h1 and T-h2 also break slot 14 (`SC_DMM`'s claim moves with `h16` while `SC_DZC`'s `host2` does not). Either recompute the chain in each row or drop the isolation claim — a test that can pass for three reasons cannot confirm that one relation is present. |
| E-20 | CORRECTION | T2 §G.1 line 1096 and line 1117 (this check T-C8) | `layout.rs:308`; `argument.rs:307` | The quoted rejection message ``slot 14 [03 D zero-check (hosts 12)]`` uses a `SLOT_NAMES` string that Tier 2 itself invalidates (`SC_DZC` now hosts `SC_WO` **and** `SC_DMM`). Update the quoted string and assert on the slot **index**, not the name. Add to line 1115 the companion assertion that the *honest* proof verifies. |
| E-21 | CORRECTION | T2 §D.4 line 886 (this check T-C9) | T1 `:674` gives `~8 + 1` | The "new `H` helper planes" row says the estimate and the derived value differ and lists three offsetting errors, but `~8 + 1 = 9` **equals** the derived 9. Say "agrees", or drop the row. |
| E-22 | CORRECTION | T2 §I.1 decision 5, lines 1214-1217 (this check T-N1, raised to a condition) | §2.3 and §8.3 of this check | Decision 5 is stated as the only form that "proves index and value came from the same row" — true, but it understates what is at stake. **Wherever `u16(x) = 0`, `f0` pins nothing about `a16(x)`, and `f_act` is the only other relation `a16` appears in.** The rejected alternative (separate class lookups on `g8` and `a16`) is therefore not merely weaker: it leaves `a16`, `h16` and `z16` free at every zero of the up matmul. Add that sentence; it converts a style preference into a soundness requirement. |

**Conditions for acceptance, in order.** (1) E-1 and E-2 are discharged in the
commit that lands Tier 2, with the tripwire test of E-1 and the range check of
E-2 both present and passing. (2) E-3 … E-22 are applied to the two memos.
(3) The committed inventory tool re-derives every count from the Rust and
`NOTE_EXPECT` is updated to §5.2's column (Tier-1 Decision 12). (4) The two
owed negative controls (`A_H16` sharing `A_U16`'s pair; `A_YM` sharing `A_Y`'s
pair) are implemented and fire. (5) Nothing in this document, and nothing the
tools report, establishes a privacy property; the joint-view gate on captured
receipts (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:135`) remains unmet and
unaffected, and D8, D9 and D11 remain open.
