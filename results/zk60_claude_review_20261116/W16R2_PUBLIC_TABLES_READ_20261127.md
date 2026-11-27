# W16R2_SHIELD_T128_H24: the public tables of the Lean statement against the Rust verifier's (independent read, 2026-11-27)

This is a read-only check of L3, the item the define read took on trust
(`W16R2_DEFINE_READ_20261127.md` §7). The question: do the Rust verifier's public tables satisfy the laws of
`W16Pub`, which `block_knowledge_w16r2_shieldU1` quantifies over? Are they handed to the slots as
`Tab.pubsU1` hands them? And which laws on `BlockPublic` does the code enforce? Nothing was built, compiled,
run or edited. There was no Git write.

Paths. `F/` = `formal/ZK60Formal/`. `pb/` = `ops/zkp-mvp/gpu-metal/hashline/src/private_block/`.
`pbr` = `ops/zkp-mvp/gpu-metal/hashline/src/private_block.rs`. `zc/` = `ops/zkp-mvp/gpu-metal/zkp-core/src/`.

## 0. Findings first

1. **No MISMATCH found in any part.** Part 1: 31 rows, 31 MATCH. Six of those are vacuous: the field is never
   read by `pubsU1`, the code has no table for it, and the constant `1` meets the law. Part 2: 23 rows: 19 MATCH,
   3 carried from the define read without re-reading, 1 NOT DETERMINED. Part 3: 25 rows: 24 ENFORCED,
   1 NOT DETERMINED.
2. **What a W16Pub law means here.** Every `W16Pub` law is an ASSUMPTION the theorem makes of `B`. `hdef`
   (`F/BlockW16U1Done.lean:70-71`) says the verifier's tables are exactly `Tab.pubsU1 Pb Lay B nG`. Suppose the
   code's table broke a law. Then no lawful `B` would make `hdef` true for the code's verifier, and the theorem
   would say nothing about that verifier. I found no such law. Each MATCH is relative to one choice of `Lay` and
   `Pb`, given in §1.0. The theorem lets the user choose both. It does not itself fix `Pb` to the model's data.
3. **The theorem takes no hypothesis on `Pb`.** The binders `F/BlockW16U1Done.lean:59-88` contain no
   `Pb.Valid`, no `hAct0`, no other law on `Pb`. A grep for `Pb.Valid`, `act 0 2048`, `hAct0`, `act0` and `hPb`
   over `F/BlockW16U1*.lean` returns nothing. `BlockPublic.Valid` is a premise of `block_circuitIff`
   (`F/CircuitBlock.lean:815`), the later step from `BlockSat` to the integer model.
4. **`Pb.act 0 2048 = 0` enters the U1 statement only through `hdef`.** Lean's TAB activation column has the pad
   row `(2048, tagAct, act 0 2048, 0)` (`F/BlockW16U1TabBase.lean:44`). Rust's is `2048 + tag`
   (`pb/accuracy_act.rs:19`). They are equal only if `act 0 2048 = 0`. The code refuses any group table whose word
   at 2048 is not zero (`pb/accuracy_act.rs:22`). That check is on the verifier's own path: `tab_w16` calls
   `accuracy_act::table` (`pb/argument_accuracy.rs:749`). So this is ENFORCED, closing the define read's open
   condition (its §3 row c).
5. **One link I could not close:** Lean's `nG = (shieldShape Ly).nG` (a per-layer constant,
   `F/RunShapeShield.lean:116`) against the code's `a.groups().len()`. The code bounds the count to 1..4 and checks
   every channel's id against its own count. I did not find where it pins the count to the layer's registered
   value. If the two differed, the TAB activation column would differ and `hdef` would fail for that layer
   (Part 2 row 20, Part 3 row 25).
6. **A reading note, not a mismatch.** `Wg_emb` asks `Wg = P.wg · P.mg`. The code folds `wg_t` with
   `a.folds().gate.multipliers`, not with `a.multipliers().g` (`pb/accuracy_fold.rs:32`). So the law holds when
   `Pb.mg` is read as the folded gate multipliers. That also fits the gate shift, which the code takes from
   `folds().gate.shift` (`pb/argument_accuracy.rs:22`). Whether that `Pb` is "the model" is outside this read.
7. **Which code path I read.** I read the verifier's path. The tables are materialised (`Tab::Pub`), because
   `pts.pub_gen_prove = prove_side && host_fast_on()` (`pb/argument.rs:4117`). The `PubGen` descriptors
   (`pb/argument.rs:2384, 2438-2441, 2454-2456, 2463-2483, 2584-2607`) are prover-only, and I did not compare them.
   Folds on the verifier always take `fold_with_mode(.., false)` (`pb/accuracy_fold.rs:1149-1150`).

## 1. Part 1: the laws of `W16Pub` (`F/LayoutW16.lean:226-283`)

### 1.0 The layout and public record the rows use

The cube types are `CtU1 … CfU1 = CtR c0 …` (`F/BlockW16U1Base.lean:57-62`). At this shape they are
`lt 7, lh 5, ldh 7, ld 12, lf 14, lkv 3` (`F/SlotW16R2.lean:321-329`, `shShield` `:346`).

A table is `cubeTab n g`: entry `idx` holds `g (msbBits n idx)` (`F/BlockHostPub.lean:45-46`), and `msbBits`
puts bit 0 at the top (`F/ExecMle.lean:419`). The splits are `t ++ w`, `t ++ (g ++ j) ++ c`, `t ++ g ++ c`,
`(g ++ j) ++ t ++ t'` and `t ++ f`, first part on top (`F/BlockR13HostBase.lean:292-327`). So Lean's
index is row-major with the first axis most significant.

The layout I use: every axis is the binary index. `hd.emb (b, k) = 64·b + k`, which meets `LayR.flip` (the top
bit, `F/BlockR13HostBase.lean:382`). The head slot of head `h` is `(h/4, h%4)`. This is the layout C-1 requires:
`shieldGrp h = h/4` (`F/RunShapeShield.lean:89`), and the code's `head_slot(h) = (h/group)·per + h%group`
with `per = group = 4` (`pb/shape.rs:2322-2325`). `LayR` asks tokens, head dimension, slots and groups to be
onto. They are: 128 = `t_pad`, 32 = `h_pad`, 128 = head dimension, 8 groups. Width 3072 and hidden 9216 pad.

`Pb` is the loaded arrays, before padding, read in the obvious way. One exception: the multipliers are the
code's `coefficients(sh, data, site)` (`pb/accuracy_fold.rs:16-37`), and `mg` is the gate fold's multipliers.

Rust side. The weights are padded by `pad_matrix` (`pb/trained_block.rs:1397-1407, 1509-1523`, zero-filled).
Wq's rows and Wo's columns are mapped through `head_slot`. The weights are folded at `pb/argument.rs:3218-3259`
and `3367-3400`. The folds are `fold_rows_i8` / `fold_cols_i8` (`zc/mle.rs:157-199`):
`out[col] = Σ_row w[row]·m[row,col]`, and the other way round for columns.

### 1.1 Rows

| # | Law | Rust table on the verifier's path | Verdict |
|---|---|---|---|
| 1 | `gT_one` | no table: `supp(Dom::T)` is `None`, since T does not pad (`pb/argument.rs:2581-2583`, `:3093`); `pubsU1` never reads `B.gT` | MATCH (vacuous) |
| 2 | `gD_one` | `supp(D)` = `indicator_table` = `closed_form_indicator`: factor `NotAllOne(bits 10,11)` on `x mod 4096`, token axis `Always` (`pb/pad.rs:169, 125-146, 354-358`), so 1 iff `x % 4096 < 3072`; tiled with `rep = 1` (`pb/argument.rs:2609-2611`) | MATCH |
| 3 | `gQ_one` | none (Q does not pad); field unread | MATCH (vacuous) |
| 4 | `gK_one` | none (Kv does not pad); field unread | MATCH (vacuous) |
| 5 | `gS_one` | none (`supp(S)` `None`, `pb/argument.rs:3173`, `pb/argument_accuracy.rs:600`); field unread | MATCH (vacuous) |
| 6 | `gHt_one` | none (`pb/argument_accuracy.rs:599`); field unread | MATCH (vacuous) |
| 7 | `gF_one` | `supp(F)`: no closed form (9216 and 7168 are not powers of two), so `support_indicator`. It is 1 at `t·f_pad + j`, `j < 9216` (`pb/pad.rs:48-53`, `pb/witness.rs:524-526, 581-586`) | MATCH |
| 8 | `gD_pad` | as row 2: 0 at every `x % 4096 ≥ 3072`, all rows | MATCH |
| 9 | `gS_pad` | vacuous: tokens are onto, so no column is a pad column | MATCH (vacuous) |
| 10 | `gamA_emb` | `repeat_vals(cube, gamma_a[..d_pad])` gives `gamma_a[x % d_pad]` (`pb/argument.rs:2458-2459`, `pb/argument_accuracy.rs:468`); value at `(t, i)` = `gamma_a[i]` | MATCH |
| 11 | `gamM_emb` | the same with `ff.gamma_m` (`pb/argument_accuracy.rs:469`) | MATCH |
| 12 | `cosT_emb` | `rope_tables_at(Q)`: `x = t·4096 + slot·128 + i`, `c = cos[t·64 + i%64]`, all slots live (`pb/argument.rs:2857-2874`, `slot_is_true_head` `pb/shape.rs:2327-2329`); this is `P.cos t k` at `c = (b, k)` | MATCH |
| 13 | `sinT_emb` (`ropeSgn`) | `s = −sin` if `i < 64`, `+sin` otherwise (`pb/argument.rs:2872`). `i < 64` means `b = false`, and `ropeSgn false = −1`, `true = 1` (`F/CircuitRopeAct.lean:53-55`) | MATCH |
| 14 | `cosK_emb` | `rope_tables_at(Kv)`: heads = `kv_heads`, `x = t·1024 + g·128 + i` | MATCH |
| 15 | `sinK_emb` | the same sign rule | MATCH |
| 16 | `mask_emb` | `causal_mask_at`: 1 iff `x % 128 ≤ (x/128) % 128`, i.e. `j ≤ t`, every slot (`pb/argument.rs:2828-2831`); `maskF t j = if j ≤ t then 1 else 0` (`F/CircuitStage.lean:274`) | MATCH |
| 17 | `grpCol_emb` | `group_column`: `out[t·f_pad + j] = group_ids[j]`, pad 0 (`pb/accuracy_act.rs:33-41`) | MATCH |
| 18 | `Wq_emb` | entry at input `i` = `Σ_y eq(r_j,y)·coef_Q[y]·wq_pad[y,i]`, with row `slot(h)·128 + c` = logical `h·128 + c` (`pb/trained_block.rs:1399-1401`, `pb/accuracy_fold.rs:20-25`); Lean's fold reads `Wq w y` | MATCH |
| 19 | `Wk_emb` | rows `g·128 + c`, coefficients `m.k` (`pb/accuracy_fold.rs:29`) | MATCH |
| 20 | `Wv_emb` | the same with `m.v` | MATCH |
| 21 | `Wo_emb` | `wo` (output `j`, input mapped by `head_slot`), fold over output `j` with `m.o` resized to `d_pad` (`pb/trained_block.rs:1404`, `pb/accuracy_fold.rs:31`) | MATCH |
| 22 | `Wg_emb` | `wg_t` (input `i`, output `f`), fold over columns with `folds().gate.multipliers` (`pb/accuracy_fold.rs:32`) | MATCH, with `Pb.mg` = the gate fold's multipliers (finding 6) |
| 23 | `Wu_emb` | `wu_t`, `m.u` (`:33`) | MATCH |
| 24 | `Wd_emb` | `wd_t` (input `f`, output `j`), `m.d` (`:34`) | MATCH |
| 25 | `Wq_pad` | input columns `≥ 3072` are zero: `pad_matrix` zero-fills them, and the verifier REFUSES otherwise (`weights_vanish_off_support`, `pbr:510-540, 635`) | MATCH (enforced) |
| 26 | `Wk_pad` | the same (`pbr:636`) | MATCH (enforced) |
| 27 | `Wv_pad` | the same (`pbr:637`) | MATCH (enforced) |
| 28 | `Wo_pad` | vacuous: slots are onto, so no pad input; the check also exists (`pbr:638`) | MATCH (vacuous, enforced) |
| 29 | `Wg_pad` | input rows `≥ 3072` are zero (`pbr:776`) | MATCH (enforced) |
| 30 | `Wu_pad` | the same (`pbr:777`) | MATCH (enforced) |
| 31 | `Wd_pad` | input rows `≥ 9216` are zero (`pbr:778`) | MATCH (enforced) |

**Totals, Part 1: 31 rows. MATCH 31, of which 6 are vacuous (rows 1, 3, 4, 5, 6, 9; row 28 is vacuous but
read). MISMATCH 0. NOT DETERMINED 0.**

The refusals at rows 25-31 run on the verifier: `verify_inner_at` calls `blk.check_for_shape(sh)`
(`pb/protocol.rs:4461`), which at an accuracy profile is `check_accuracy_for_shape` (`pbr:952-954, 918-940`).
That function re-runs both `check_words` (`pbr:923-924, 796-797`).

Where `W16Pub` is looser than the code. There is no law at pad positions for `gamA`, `gamM`, cos, sin,
`grpCol` or `gF`, and none at pad outputs of `Wo`, `Wg`, `Wu`, `Wd`. The code puts zero (or a zero-weighted
entry) there. That is harmless. Any value meets an absent law.

## 2. Part 2: how `Tab.pubsU1` hands the tables to the slots

`pubsU1 = pubsR13 c0 Pb Lay B (restU1 Pb nG)` (`F/BlockW16U1TabBase.lean:90-92`). Its body is at
`F/BlockR13HostPub.lean:58-92`. `restEU1` is at `F/BlockW16U1TabBase.lean:76-82`. `pubsW16` at
`F/BlockHostPub.lean:153` is the rung version (14-variable cubes). The U1 statement does not use it.

Each slot's `TabS.pub` entries are numbered in list order by `numTabs` (`F/BlockDefineW16.lean:521`). I compared
each slot's public list (count, order, position in the slot's table list) with the order of the code's
`b.public` / `b.supp` / `b.causal_mask` / `b.rope_tables` / `b.repeat_vals` / `b.group_col` / `b.const_one` calls.
Flattening is as in §1.0. On both sides the first named axis is most significant. Rust domain indices
(`pb/witness.rs:500-534`) are the same row-major products.

| # | Slot | Lean tables (index, cube) | Rust tables (order) | Verdict |
|---|---|---|---|---|
| 1 | 0 `SC_SS` | `[eq, x, pub 0]` (`F/BlockDefineW16.lean:320`); pub 0 = `gD` on `nD = 19` | `eq, a(A_X), supp(D)` (`pb/argument.rs:2984-2990`) | MATCH (cube 2^19 from the params read) |
| 2 | 1 `SC_SSM` | the same with `x1` | `:3024-3030` | MATCH |
| 3 | 2 `SC_TZC` | no pub (`supp c .T` false; `:326, 332`; `pubsR13` → `rest` → `[]`) | `supp(T)` `None` (`:3093`) | MATCH |
| 4 | 3 `SC_LZC` | `[eq, limb, limbm, h, pub 0]` (`:339`); `gateLU1` = `x/128 < 9` on 14 variables (`F/BlockW16U1TabBase.lean:56`, `F/BlockR13HostPub.lean:157`) | `eq, a_range, h, supp(L)` (`pb/argument.rs:3135-3150`); `support_indicator(L)`, `lix(k,t) = k·128 + t`, `k < 9` (`pb/witness.rs:532-534, 596-602`); closed form `None` (`pb/pad.rs:177`, 9 and 119 not powers of two) | MATCH |
| 5 | 4 `SC_RS` | `[eq, pub 0, e, zsel]` (`:344`); `mask` on `nS = 19`, `(g++j) ++ t ++ t'` | `eq, causal_mask, a(E), a(ZSEL)`, `supp(S)` `None` (`pb/argument.rs:3161-3173`) | MATCH |
| 6 | 5 `SC_QMM` | `[aTab, pub 0]` (`:350`); `foldTab 12 12 Wq (drSeg dr 7 12)` | `a_at`, `public(fold)`; draws `r_q` (7), then `r_j` (`lg q_pad = 12`); fold indexed by input (`pb/argument.rs:3219-3251`) | MATCH |
| 7 | 6 `SC_KMM` | `foldTab 12 10 Wk (drSeg dr 0 10)` | `r_j` of `lg 1024 = 10` is the slot's first draw | MATCH |
| 8 | 7 `SC_VMM` | `foldTab 12 10 Wv (drSeg dr 0 10)` | as KMM | MATCH |
| 9 | 8, 9 `SC_SCORE`, `SC_PV` | no pub (no `TabS.pub` in their arms; `pubsR13` → `[]`) | only `Eq` and private tables (`group_eq` pushes an `Eq`, `pb/argument.rs:2373-2378, 3299-3360`) | MATCH |
| 10 | 10 `SC_WO` | `foldTab 12 12 Wo (drSeg dr 7 12)`, indexed by input `(g++j)++c` | `r_q` (7), `r_j` (12); `(outer d_pad, inner q_pad)` (`:3234`) | MATCH |
| 11 | 11 `SC_GMM` | `[aTab, pub 0]` (`:355`); `foldTab 12 14 Wg (drSeg dr 7 14)` | `r_tf` (7), `r_j` (14); `fold_cols` (`:3368-3392`) | MATCH |
| 12 | 12 `SC_UMM` | `foldTab 12 14 Wu (drSeg dr 0 14)` | `r_row` reused; `r_j` (14) first | MATCH |
| 13 | 13 `SC_DMM` | `foldTab 14 12 Wd (drSeg dr 7 12)` | `r_row` (7), `r_j` (12) | MATCH |
| 14 | 14 `SC_DZC` | pubs 0, 1 = `gamA`, `gamM` (positions 4, 5); pub 2 = `gD`, last (`:386-388`); `nD = 19` | `repeat_vals ×2` after three `eq`; `supp(D)` last (`pb/argument_accuracy.rs:467-478`) | MATCH |
| 15 | 15 `SC_QZC` | pubs `cosT`, `sinT` on `nQ = 19` (`:413`) | `rope_tables(Q)` (`:544`), `x = t·4096 + slot·128 + i` | MATCH |
| 16 | 16 `SC_KVZC` | `cosK`, `sinK` on `nK = 17` | `rope_tables(Kv)` | MATCH |
| 17 | 17 `SC_SZC` | pub 0 = `mask` (`:439`); gates absent | `causal_mask` (`:584`); `supp` `None` | MATCH |
| 18 | 18 `SC_FZC` | pubs `grpCol`, `gF` on `nF = 21` (`:460-461`) | `group_col`, `supp(F)` (`:514-515`) | MATCH |
| 19 | 19 `SC_TAB` value columns | 16 columns `foldWd β γ (tabTupEU1 … k idx)`, plain index `idx < 2^14` | 16 `public` columns, plain index (`:754-758`) | CARRIED (define read §3: equal; I re-read `tab_w16`, `table_values_u8_at`, `table_values_exp_at` (`pb/argument.rs:2901-2909`) and `accuracy_act::table`, but not `foldWd` or `range16::table_column`) |
| 20 | 19 `SC_TAB` ACT column's extent | `i < nG·4096` with `nG = (shieldShape Ly).nG` | `entries = groups().len()·4096` (`pb/accuracy_act.rs:14-29`) | NOT DETERMINED (finding 5) |
| 21 | 19 `SC_TAB` gates | pubs 16-24: `x < 256`, `x < nG·4096`, 7 narrow supports | `supp(Tab)`, `act.support`, 7 `support_column` (`:768-776`) | CARRIED (define read §3) |
| 22 | 20 `SC_ZS` | `[pub 0, h]` (`:491`); all ones on 14 variables | `const_one(size(Tab))` (`pb/argument.rs:3933`, materialised `:2446-2451`) | MATCH |
| — | tuple packing | `foldWd β γ ⟨x, tag, y, z⟩ = x + γ·tag + β·y + β²·z` | `x + g_tag + β·y + β²·z` | CARRIED (define read §3 row c) |

Slots 21 and 22 (`SC_IO_IN`, `SC_IO_OUT`, `pb/layout.rs:998-999`): Lean hands them `[]`. I did not read their
Rust arms.

**Totals, Part 2: 23 rows (22 numbered plus the packing row). MATCH 19 (rows 1-18 and 22). CARRIED 3
(rows 19, 21 and the packing row). NOT DETERMINED 1 (row 20). MISMATCH 0.** Slots 21-22 were not read and are
not counted.

Draw order inside each fold. Lean folds with `eqTableMsb` of `drSeg dr off n`. Rust folds with
`eq_table_msb(r_j)` = `eq_table` of the reversed point (`zc/mle.rs:56-59`). I took it on trust that Lean's
`eqTableMsb` has the same index order. The name and `foldTab_getD`'s statement say it does
(`F/BlockHostPub.lean:124-127`).

## 3. Part 3: the laws on `BlockPublic`

**Where they are assumed.** `BlockPublic.Valid` (`F/CircuitBlock.lean:193-222`) is a premise of
`block_circuitIff` (`:815`). It is not a premise of `block_knowledge_w16r2_shieldU1` (finding 3). So for the U1
statement these laws are not needed. They become needed when `BlockSat Pb` is turned into the integer block.
Two facts about `Pb` are needed inside the U1 statement, implicitly, for `hdef` to hold of the code (rows 24-25).
For each row I give whether the code refuses data that breaks the law, on the verifier's path
(`verify_inner_at` → `check_for_shape`, `pb/protocol.rs:4461`, unless noted).

| # | Law | Rust | Verdict |
|---|---|---|---|
| 1 | `gA`: `|gA| ≤ 127` | i8 storage, and `i8::MIN` refused for `gamma_a` (`pbr:933-936`) | ENFORCED |
| 2 | `gM` | the same for `gamma_m` | ENFORCED |
| 3 | `wq` | the same for `wq`; also the fold refuses `i8::MIN` (`pb/accuracy_fold.rs:1073`) | ENFORCED |
| 4 | `wk` | as row 3 | ENFORCED |
| 5 | `wv` | as row 3 | ENFORCED |
| 6 | `wo` | as row 3 | ENFORCED |
| 7 | `wg` | as row 3 (`wg_t`) | ENFORCED |
| 8 | `wu` | as row 3 | ENFORCED |
| 9 | `wd` | as row 3 | ENFORCED |
| 10 | `mq ≤ 2^14` | fold refuses any coefficient `> 2^14` (`pb/accuracy_fold.rs:1058`), verifier fold `:1149-1150`; also `0 < m ≤ 2^bits` at construction (`pb/accuracy_public.rs:133-141`, bits not read) | ENFORCED |
| 11 | `mK` | as row 10 | ENFORCED |
| 12 | `mv` | as row 10 | ENFORCED |
| 13 | `mo` | as row 10 | ENFORCED |
| 14 | `mg` (gate fold's multipliers) | as row 10, the fold check | ENFORCED |
| 15 | `mu` | as row 10 | ENFORCED |
| 16 | `md` | as row 10 | ENFORCED |
| 17 | `cos`: `|cos| ≤ 2^7` | `[-2^F_RO, 2^F_RO]` with `F_RO = 7` (`pbr:643-650`, `pb/layout.rs:73`); also stricter: token 0 is `(2^7, 0)` | ENFORCED |
| 18 | `sin` | the same | ENFORCED |
| 19 | `exp0`: `0 ≤ exp` | `exp[i] ∈ [0, 2^f_e]`, `exp[0] = 2^f_e`, non-increasing (`pbr:651-652`); the loader also requires `exp == exp_member(..)` (`pb/trained_block.rs:1354-1357`) | ENFORCED on the 256 entries |
| 20 | `exp1`: `exp ≤ 2^fe` | as row 19 | ENFORCED on the 256 entries |
| 21 | `act`: `|act| ≤ 2^31` | scaled words refused above `32767·2^16` at Shieldstral (`pb/accuracy_aligned.rs:43-46`, `pb/accuracy_tables.rs:16`); recomputed by `check_for_registry` (`pb/accuracy_public.rs:270-286`, called from `pbr:927`) | ENFORCED on the code's groups × 4096 entries |
| 22 | `grpF k < nG` | refuses `id ≥ groups.len()` and unused groups (`pb/accuracy_groups.rs:44-46`, via `derive_aligned_for` `pb/accuracy_aligned.rs:32`) | ENFORCED against the data's own count (equality with `S.nG`: row 25) |
| 23 | `act0`: `act 0 2048 = 0` | `words[2048] != 0` refused for every group (`pb/accuracy_act.rs:22`), on the verifier's `tab_w16` (`pb/argument_accuracy.rs:749`) | ENFORCED |
| 24 | implicit in `hdef`: TAB ACT pad row needs `Pb.act 0 2048 = 0` | the same refusal | ENFORCED |
| 25 | implicit in `hdef`: Lean `nG` = code's `groups().len()` | count bounded 1..4 (`pb/accuracy_act.rs:15`); no pin to the layer's registered count found | NOT DETERMINED |

**Totals, Part 3: 25 rows. ENFORCED 24, SATISFIED BY DATA 0, NOT CHECKED 0, NOT DETERMINED 1.**

`Valid`'s `exp` and `act` quantify over every integer argument and every group. The code holds data only for
`exp` on `0..255` and for `act` on `g < groups`, `0..4095`. Lean's tables read `Pb.exp` and `Pb.act` only there
(`F/BlockW16U1TabBase.lean:39-44`). Off that range `Pb` is the user's choice (zero, say), and the law is met
by that choice. Rows 19-21 say ENFORCED only on the code's own entries.

## 4. What I took on trust

- That `eqTableMsb` (Lean) and `eq_table_msb` (`zc/mle.rs:56`) agree in index order (§2).
- The slot cube sizes (`1 << sh.slots()[slot].0`) for slots 0, 1, 3, 4, 17: that each equals the Lean cube
  (19, 19, 14, 19, 19), so `tile_rep = 1`. They come from the params read's schedule.
- The define read's §3 comparisons of the TAB columns, gates and the packing (Part 2 rows 19, 21 and the packing
  row).
- That `Lay` and `Pb` as in §1.0 are the ones intended. The theorem lets the user choose them. Whether this `Pb`
  (for example `mg` = the gate fold's multipliers) is the model the integer semantics describes is outside this
  read.
- That `Axis::supported` in `weights_vanish_off_support` means "index below the true width / hidden / query
  width". I read the loop, not the predicate.

## 5. What I did not read

- The prover-only `PubGen` descriptors and `direct_total` paths.
- `foldWd`, `tagW`/`tagExp`/`tagAct` values, `range16::table_column`/`g_range` (taken from the define read).
- `F/ExecMle.lean`'s `msbIndex` body and `eqTableMsb` (only `msbBits`, `:419`).
- The Rust arms of slots 21 and 22.
- Where (if anywhere) the code pins `groups().len()` to the layer's registered group count.
- Verifier entry points other than `verify_inner_at` (the other `check_for_shape` call sites
  `pb/protocol.rs:714, 747, 2543, 2870, 3234, 4332`).
- `pb/accuracy_fold.rs` beyond `:1-1162` (the verifier's fold path ends at `:1150`).

All three parts are complete within the rows listed. Part 2 stops at slot 20. Slots 21-22 were not read.
