# W16R2_SHIELD_T128_H24: the six W16 slot definitions, Lean model against the Rust verifier (independent read, 2026-11-27)

Read-only fidelity check of the BODIES of slots 14 DZC, 15 QZC, 16 KVZC, 17 SZC, 18 FZC, 19 TAB: the Lean model
`defineS (DefW16.progW16 (cfgU1 ..) ioIn ioOut) (Tab.pubsU1 ..)` (premise `hdef`, `F/BlockW16U1Done.lean:72-73`)
against the code the verifier runs. Nothing was built, compiled or edited; no Git write. COUNTED = read at file:line;
DERIVED = unfolding or arithmetic shown (counts re-run in one `python3 -c`). Paths: `pb/` =
`ops/zkp-mvp/gpu-metal/hashline/src/private_block/`; `F/` = `formal/ZK60Formal/`.

**What "the Rust side" is.** The verifier evaluates each slot's terminal with the CLOSURE `def.poly` built in
`pb/argument_accuracy.rs` (`fin.sub((def.poly)(&vals))`, `pb/argument.rs:2275`; `vals` = eq tables and public MLEs
at `rho` times `sel`, private terms from the proof, `:2262-2274`), and its claimed sum is
`sp.scalar + Σ_hosted coef·acc.scalars[hs]` (`pb/argument.rs:2255`). COUNTED. The Lean builders say they port
the device IR `slot_ir_accuracy.rs` (`F/SlotW16Build.lean:8-16`), not the closure. This read compares the Lean IR
with the CLOSURE directly, which is what decides acceptance.

## 0. Findings first

1. **No MISMATCH in any component of the six slots.** All six slots are complete: 36 components, 36 MATCH, with
   the conditions listed in §7 (plane and helper ids, public-table contents and per-layer constants taken from Lean
   definitions or earlier reads, not re-derived from Rust layout code here).
2. **The draw ORDER and USE agree** for every slot (§1-§6, component a). DZC, QZC, KVZC, FZC draw
   `μ, ν, ζ, τ` (τ last); SZC and TAB draw `τ` first. The Lean `draws` (`F/SlotW16R2.lean:197-202`) and the code's
   call order (`pb/argument_accuracy.rs:464-467, 506-509, 540-543, 575-580, 746-748`) are the same sequences.
   Counts re-derived: 17+2+1+19 = 39, 4+2+0+19 = 25, 4+2+0+17 = 23, 19+9+2+0 = 30, 7+2+1+21 = 31, 14+17+1 = 32
   (DERIVED from 19, 6, 6, 7, 7 lookups, i.e. 10, 3, 3, 4, 4 helpers).
3. **The one parameter I expected to be loose is pinned.** FZC's product shift `r`: Lean fixes `fold := 16`
   for every layer (`F/RunShapeShieldU1.lean:119`, `F/BlockDefineW16Shield.lean:35-36`); Rust reads
   `data.folds().product.shift` (`pb/argument_accuracy.rs:522`). The public data's folds are `aligned.folds`
   (`pb/accuracy_public.rs:146-175`), whose product shift is the literal `16` at `Stack::LowH24`
   (`pb/accuracy_aligned.rs:25-29`, product `Folded { shift, .. }` `:50`), and `check_for_registry` recomputes the
   folds and refuses any difference (`pb/accuracy_public.rs:270-286`), called for every W16 slot
   (`pb/argument_accuracy.rs:19-21`). So `r = 16` in the code at this stack. DERIVED. The per-layer `sh_h ∈ [13,16]`
   (`F/RunShapeShieldU1.lean:79`) does not move it.
4. **The code is stricter than the model in several shape-only or data-only refusals** that the Lean `defineS`
   does not contain: the registry and gate-shift checks (`pb/argument_accuracy.rs:18-22`), `role`'s domain check
   (`:5-9`), `B::finish`'s site counts (`pb/argument.rs:2614-2616`), SZC's `Dom::Ht` zero-group equality
   (`pb/argument_accuracy.rs:602-604`), TAB's `rp.len() == rh.len()` (`:745`), `tab_group_is_declared` (`:765`),
   the ACT table's size and zero-row checks (`pb/accuracy_act.rs:15-23`), `tile_rep` in `supp`
   (`pb/argument.rs:2601-2608`). Each one only makes Rust reject where Lean would define. For soundness of the code
   this is the harmless direction (Lean accepts a superset). None of them depends on the prover's private values.
5. **Not compared (outside the six bodies, recorded in §7):** the generic consumer of a `SlotDef` on the Lean side
   (how `blockVerify` turns tables and hosted list into opening claims and the claimed sum), the Rust plane-id and
   helper-id allocation (`accuracy_layout.rs::new_w16`, `layout.rs::HIds::new`) against Lean's `idsW`/`hIdsN`, and
   whether the code's public tables satisfy the `W16Pub` fields that the theorem quantifies over.

## 1. Slot 14 DZC (`dzc_w16`, `pb/argument_accuracy.rs:461-501`; Lean `F/BlockDefineW16.lean:376-395`, `dzcIr`/`dzcPre`/`dzcPost` `F/SlotW16Build.lean:266-289`)

| | Lean | Rust | Verdict |
|---|---|---|---|
| a | `seg 0` = μ (6+nh+p = 17), `seg 1` = ν (2, nonzero), `seg 2` = ζ (p = 1, nonzero), `seg 3` = τ (19) (`:377-380,385`; draws `F/SlotW16R2.lean:197`). Use: μ0..5 clause batch, μ6..15 LogUp helpers, μ16 pad; ν host weights; ζ pad powers from ζ^0; τ eq point | `mu` (6+n_help+pad_on), `nu` nonzero, `zeta` nonzero if pad_on, `tau` (`:464-467`); `mu` zipped with 6 clauses (`:493`), `mu[6..6+n_help]` helpers (`:494`), `pz.mu = mu[6+n_help]` (`:480`), `PadTerm` powers from ONE (`pb/argument.rs:2756-2765`) | MATCH (COUNTED) |
| b | tables: eq τ, eq `claimPt WO`, eq `claimPt DMM`, pub, pub, `domPl D` planes, `d` slice (log lt, ρ0..lt), `dm` slice, nh helpers from `fh 1`, `supp D` if `g` (`:386-388`); `shaped q = 5+(q−8)` | eq τ, eq `p_a`, eq `p_z`, `ig`, `igm`, `a_range(D)` (inclusive end `range.end−1`, `pb/argument.rs:2510-2516`), `a_slice(A_D, lt, rho(0..lt))`, `A_DM` slice, helpers, `supp(D)` (`:468-479`). `p_a = r_q(WO)‖r_j` (`pb/argument.rs:3220,3236,3256`) = Lean `seg WO 0 ++ seg WO 1`; `p_z = r_row(DMM)‖r_j` (`:3377-3378,3392,3397`) = `seg DMM 0 ++ seg DMM 1` (`F/BlockDefineW16.lean:293`) | MATCH (COUNTED; ids on trust, §7) |
| c | pub 0 `B.gamA`, pub 1 `B.gamM`, pub 2 `B.gD` (`F/BlockR13HostPub.lean:78-81`), at the slot's ρ | `repeat_vals(gamma_a[..d_pad])`, `repeat_vals(gamma_m[..d_pad])`, `supp(D)` = `BoxSupp{rows tokens, cols width}` (`pb/argument.rs:2590`) | MATCH in identity and position; values §7 L3 |
| d | hosted `[(scWO, ν0), (scDMM, ν1)]` (`:395`); eq points from WO, DMM | `hosted = [(SC_WO,nu0),(SC_DMM,nu1)]` (`:484`) | MATCH (COUNTED) |
| e | see below | see below | MATCH (DERIVED) |
| f | nonzero `ν ++ ζ`; 21 A + 10 H private tables, claims at the slot point; hosted as in (d) | 21 `a_slice` + 10 `h` (finish checks the site counts); claimed sum `scalar + ν0·s_WO + ν1·s_DMM` | MATCH (slot-specific data; generic consumer §7 L1) |

(e) Rust closure (`:485-499`), with `kd = 2^(tn+1)·d`, `dv = 2^tn`, `num = 2·cn_a`:
`v0·[ Σ_k μ_{6+k}·LogUp_k + μ16·(1−gD)·Σ_j ζ^j·plane_j + gD·Σ_{i<6} μ_i·c_i ] + ν0·v1·gD·(2^ao·ao + L16(ral) − 2^(ao−1)) + ν1·v2·gD·(2^down·z + L16(rdl) − 2^(down−1))`,
`c0 = num·ig·x + dv·d − kd·y − L16(nr)`, `c1 = L16(nr)+L16(ns)+1−kd`, `c2 = x1−x−ao`,
`c3 = numM·igm·x1 + dv·dm − kdm·ym − L16(mr)`, `c4 = L16(mr)+L16(ms)+1−kdm`, `c5 = x2−x1−z`, `L16 = Σ 2^(16k)·t_k`
(`pb/argument.rs:2704-2706`). Lean nodes 4-9 (`F/SlotW16Build.lean:268-276`): `num·ig·x + dv·id − den·y·id − n0`,
`n0+n1+1−den·id`, `x1−x−ao`, `numM·igm·x1 + dv·idm − den·ym·idm − n2`, `n2+n3+1−den·idm`, `x2−x1−z`; node 10 =
`Σ μ_q·node_{4+q}`; `zcIr` Z = LogUp(μ_{6+k}) + pad(μ_{6+nh}) + `gate·n10`; hosts `reqB` = `2^s·x + limbs − 2^(s−1)`
(`:76-78`) at `o+2`, `o+4`; `threeTerms` = `1·τ·Z + ν0·eq_pa·gate·h1 + ν1·eq_pz·gate·h2` (`:86-89`). Constants
`⟨2cnA, 2cnM, 2^tn, 2^(tn+1), ao, down⟩` (`F/BlockDefineW16.lean:392`) = Rust's (`:483`). Term by term identical;
no clause, sign, limb weight or μ index differs. The LogUp term: Rust `den = α − (cst + g_of(tag) + Σ coef·v)`,
pair relation `h·d1·d2 − d1 − d2`, odd `h·d − 1` (`pb/argument.rs:2709-2724`); Lean `konst = α − (cst + γ·tagW)`,
terms `(−coef, t)` (`F/BlockDefineW16.lean:301-304`), same relations (`F/SlotW16Build.lean:101-108`).
`g_of(U8) = γ·133`, `g_of(Range w) = γ·133·(200+w)/133 = γ·(200+w)` (`pb/range16.rs:51-56,106-111`,
`pb/protocol.rs:3880`), Lean `tagW w = if w=8 then 133 else 200+w` (`F/CircuitRopeAct.lean:114`). The D lookup
list, in order, is the same on both sides (`pb/accuracy_layout.rs:303-309` vs `F/BlockDefineW16.lean:201-203`).

## 2. Slot 18 FZC (`fzc_w16`, `pb/argument_accuracy.rs:503-535`; Lean `:449-467`, `fzcIr` `F/SlotW16Build.lean:315-332`)

| | Lean | Rust | Verdict |
|---|---|---|---|
| a | μ (2+4+1 = 7), ν (2), ζ (1), τ (21) (`F/SlotW16R2.lean:201`); μ0 product clause, μ1 ACT tuple, μ2..5 helpers, μ6 pad | same calls (`:506-509`); `mu[0]·f0`, `mu[1]·fa`, `mu[2..2+n_help]`, `pz.mu = mu[2+n_help]` (`:518,529`) | MATCH |
| b | eq τ, eq `claimPt GMM`, eq `claimPt UMM`, F planes, helpers from `fh 6`, `fact` (`fh 7`), pub, `supp F` (`:455-457`); R = `⟨0,1,2,…,3+n, 3+n+nh, 4+n+nh, gi=5+n+nh⟩` | eq τ, eq `p_g`, eq `p_u`, `a_range(F)`, helpers, `h(fact)`, `group_col`, `supp(F)` (`:510-516`); `p_g = r_tf‖r_j`, `p_u = r_tf(GMM)‖r_j` (`pb/argument.rs:3375-3396`) = `claimPt` (`F/BlockDefineW16.lean:293-295`) | MATCH |
| c | pub 0 `B.grpCol`, pub 1 `B.gF` (`F/BlockR13HostPub.lean:89-91`) | `group_col` (`pb/accuracy_act.rs:33-41`), `supp(F)` BoxSupp (`pb/argument.rs:2591`) | MATCH (identity, position) |
| d | hosted `[(scGMM, ν0), (scUMM, ν1)]` | `[(SC_GMM,nu0),(SC_UMM,nu1)]` (`:521`) | MATCH |
| e | node1 `a·u − 2^r·h − L16(rh) + 2^(r−1)`; node2 `(α − 2048 − γ·134) − g − β·a − β²·grp`; node3 `fact·node2 − 1`; node4 `μ0·node1`; Z = LogUp(μ_{2+k}) + μ1·node3 + pad(μ_{2+nh}) + gate·node4; hosts `reqB gate g`, `reqB up u` (`F/SlotW16Build.lean:315-330`); K = `⟨fold 16, gate 20, up 12⟩` | `f0 = a·u − 2^r·h − L16(rh) + 2^(r−1)`; `fa = fact·(α − (g + 2048 + β·a + β²·grp + g_act)) − 1`, `g_act = γ·134` (`pb/protocol.rs:3882`); `zc = helper_sum + μ1·fa + pz + gf·μ0·f0`; hosts `2^gate·g + L16(rg) − 2^(gate−1)`, `2^up·u + L16(ru) − 2^(up−1)` (`:524-533`) | MATCH (DERIVED; `r = 16` by finding 3) |
| f | nonzero `ν ++ ζ`; `domPl F` = 9 A planes, 5 H (4 helpers + fact); claims at the slot point | 9 `a_range` + 5 `h`; claimed sum `scalar + ν0·s_GMM + ν1·s_UMM` | MATCH |

(f) counts: F planes 47..55 = 9 (`F/BlockDefineW16Shield.lean:46-48`: f0 = 47, t0 = 56), H = 4 + 1. The params read's
per-slot site lists (its row 2) give a = 21, 7, 7, 10, 9, 16 and h = 10, 3, 3, 5, 5, 16 for slots 14-19, equal to
the counts in §1-§5 (D 19 planes + 2 slices; Q, Kv 6 + flip; S 8 + 2 slices; Tab 16). DERIVED.
No `f1`/`f2` decomposition clause on either side (W16 drops them; `pb/argument_accuracy.rs:451-456`). The F lookup
list matches in order, including the 24-bit word `[(h,1),(ht,−2^16)], bias mod 2^16, 16` and `[(ht,1)], bias/2^16, 8`
(`pb/range16.rs:145-148` vs `F/BlockDefineW16.lean:209-212`; bias `2^23` > 0, so `&`/`>>` equal `%`/`/`).

## 3. Slot 19 TAB (`tab_w16`, `pb/argument_accuracy.rs:738-779`; Lean `:468-490`, `tabIr` `F/SlotW16Build.lean:214-228`)

| | Lean | Rust | Verdict |
|---|---|---|---|
| a | τ (14), μ (3+13+1 = 17), ζ (1) (`F/SlotW16R2.lean:202`); μ_k for triple k, μ16 pad | `tau`, `mu`, `zeta` (`:746-748`); `zip(triples, mu)` (`:775`), `pz.mu = mu[3+rp.len()]` (`:766`) | MATCH |
| b | eq τ; per k < 16: `aPlane (t0+k)`, `hTab (gu8+k)`, pub (`:485-486`) | eq τ; `(a(MU8), h(th0), pub)`, `(a(MEXP), h(th1), pub)`, `(a(MACT), h(th2), pub)`, then per range sub-plane `(a(plane), h(rh[j]), pub)` (`:752-758`) | MATCH (ids on trust, §7 L2) |
| c | 16 value columns `foldWd β γ tup` = `x + γ·tag + β·y + β²·z` (`F/BlockTabBase.lean:79-81`) with tuples: bytes `(i%256, 133)`, exp `(i%256, 129, exp)`, ACT `(i%4096, 134, act, grp)` below `nG·4096` else `(2048, 134, act 0 2048, 0)`, range `(s·2^14 + i % min(2^w,2^14), 200+w)` (`F/BlockW16U1TabBase.lean:35-45`); gates: `x < 256`, `x < nG·4096`, `x < supW w` for the 7 narrow sub-planes (`:61-66,75-80`) | `i%256 + g_u8`, `i%256 + β·exp + g_exp` (`pb/argument.rs:2901-2908`), ACT `gate + β·word + β²·group + tag`, else `2048 + tag` (`pb/accuracy_act.rs:19-28`), range `s·2^logcols + i % support + g_range` (`pb/range16.rs:217-236`); gates `BoxSupp{1, 256}` (`pb/argument.rs:2594`), `act.support`, `support_column` (`pb/range16.rs:239-242`) | MATCH, with one condition: the ACT pad row is `2048 + γ·134` in Rust and `2048 + γ·134 + β·act 0 2048` in Lean, equal because Rust refuses `words[2048] ≠ 0` (`pb/accuracy_act.rs:22`); that `Pb.act 0 2048 = 0` on the Lean side is taken on trust |
| d | none | none | MATCH |
| e | `Σ_k μ_k·(h_k·(α − t_k) − m_k)` + pad (μ16); groups: `(bytes,[m0,m1])`, `(bytes,[h0,h1])`, `(act,[m2])`, `(act,[h2])`, per narrow q `(sup_q,[m_{3+j}])`, `(sup_q,[h_{3+j}])`; ζ powers continue; term `1·τ·Z` | `rel = Σ μ_k·(v[h]·(α − v[t]) − v[m])`; `v0·(rel + pz)`; `pz.add` in the same order (`:767-772`) | MATCH (DERIVED) |
| f | nonzero `[ζ]`; 16 A + 16 H; no hosted | `nonzero(zeta)` only; 16 + 16 | MATCH |

Narrow sub-planes: Lean `fullW w 14 = 14 ≤ w` (`F/SlotW16BuildLayout.lean:91`), Rust `full = min(2^w,2^14) = 2^14`
(`pb/range16.rs:222-224`): the same predicate; `tabNarrowU1 = [0..6]` (`F/BlockW16U1TabBase.lean:59`).

## 4. Slots 15 QZC and 16 KVZC (`qzc_w16`, `pb/argument_accuracy.rs:537-568`; Lean `:396-423`, `qzcIr` `F/SlotW16Build.lean:357-372`)

| | Lean | Rust | Verdict |
|---|---|---|---|
| a | μ (1+3+0 = 4), ν (2), ζ (0), τ (19 / 17); μ0 RoPE clause, μ1..3 helpers | same calls (`:540-543`); `mu[0]·rope`, `mu[1..1+n_help]` (`:556`) | MATCH |
| b | eq τ, eq `claimPt QMM`/`KMM`, eq `claimPt PV`/`VMM`, pub, pub, domain planes, `src` with `flip` at `log − ldh`, helpers `fh 2`/`fh 3`, `supp` if pads (`:410-413`) | eq τ, eq `pq`/`pk`, eq `p_o`/`pv`, `rope_tables` (cos, sin), `a_range`, `a_at(source, cf)` with `cf[log − lg hd] = Flip`, helpers, `supp(dom)` (`:543-550`). `pq = r_q‖r_j`, `pk = pv = r_q(QMM)‖r_j` (`pb/argument.rs:3219-3255`), `p_o = r_t‖r_h‖r_i` (`:3336-3339`) = Lean `claimPt` (`F/BlockDefineW16.lean:293-297`) | MATCH |
| c | pub 0 `B.cosT`/`cosK`, pub 1 `B.sinT`/`sinK` (`F/BlockR13HostPub.lean:82-87`); no gate (Q, Kv do not pad) | `(ic, is) = rope_tables` (`pb/argument.rs:2440-2448`); `supp` returns `None` | MATCH (identity, position) |
| d | `[(QMM,ν0),(PV,ν1)]` / `[(KMM,ν0),(VMM,ν1)]` | same (`:553`) | MATCH |
| e | node1 `cos·src + sin·flip − 2^7·rot − L16(rr) + 2^6`; node2 `μ0·node1`; Z = LogUp + pad + gate·node2; hosts `reqB s1 src`, `reqB s2 oth`; K = `⟨7, 15, 12⟩` / `⟨7, 15, 16⟩` | `rope = ic·source + is·flip − 2^SH_ROPE·rotated − L16(rotrem) + 2^(SH_ROPE−1)`, `SH_ROPE = 7` (`pb/layout.rs:67`); hosts `2^s1·source + L16(r1) − 2^(s1−1)`, `2^s2·other + L16(r2) − 2^(s2−1)` with `(q, pv)` / `(k, v)` (`:554-561`) | MATCH (DERIVED) |
| f | nonzero `ν`; Q: 6+1 A, 3 H; Kv: 6+1 A, 3 H | same | MATCH |

Role mapping (Rust → Lean): source `A_Q8/A_K8` → `I.q/I.k`; rotated `A_QR8/A_KR8` → `I.qr/I.kr`; other `A_O8/A_V8`
→ `I.o/I.v`; `Rqr/Rkr` → `rqrl/rkrl`; `Rq/Rk` → `rql/rkl`; `Ro/Rv` → `ro/rvl` (`:545-548` vs Lean `:415-418`). The Q and
Kv lookup lists match in order (`pb/accuracy_layout.rs:310-319` vs `F/BlockDefineW16.lean:204-205`).

## 5. Slot 17 SZC (`szc_w16`, `pb/argument_accuracy.rs:570-641`; Lean `:424-448`, `szcIr` `F/SlotW16Build.lean:402-425`)

| | Lean | Rust | Verdict |
|---|---|---|---|
| a | τ (19) first, μ (4+4+1+0 = 9), ν (2), ζ (0) (`F/SlotW16R2.lean:200`); μ0..3 clauses, μ4..7 helpers, μ8 exp tuple, μ9 pad (absent); λ = `seg RS 1` | `tau`, `mu`, `nu`, `zeta` (`:577-581`); `lam = pts.lam_z` (RS, `pb/argument.rs:3158-3159`) | MATCH |
| b | eq τ, eq `claimPt RS`, eq `claimPt SCORE`, pub, S planes, `mx`/`sum` slices (log lht), helpers `fh 4`, `sexp` (`fh 5`), `supp Ht`?, `supp S`? (`:438-441`) | eq τ, eq `p_ht`, eq `p_s`, `causal_mask`, `a_range(S)`, `imx`, `isum`, helpers, `h(sexp)`, `supp(Ht)`, `supp(S)` (`:582-597`); `p_s = r_h‖r_t‖r_j` (`pb/argument.rs:3300-3303`) | MATCH |
| c | pub 0 `B.mask` (`F/BlockR13HostPub.lean:88`); gates absent (S, Ht do not pad) | `causal_mask`; `supp` `None` | MATCH (identity, position) |
| d | `[(RS, ν0·perRow), (SCORE, ν1)]` | `[(SC_RS, nu0·per_row), (SC_SCORE, nu1)]`, `per_row = size(S)/size(Ht)` (`:595-596`) | MATCH |
| e | see below | see below | MATCH (DERIVED) |
| f | nonzero `ν`; 8+2 A, 4+1 H | same; 10 A, 5 H | MATCH |

(e) Rust (`:611-638`): `poly = Σ_{g<3} v[g]·bracket(g)`; bracket 1 `ν0·gHt·(sum + λ)`; bracket 2
`ν1·gS·(2^score·s8 + L16(rsl) − half(score))`, `half(s) = 2^(s−1)` (`pb/witness.rs:417-421`); bracket 0
`helper_sum(μ4..) + μ8·cx + pz + gS·Σ_{i<4} μ_i·c_i` with `δ = mx − mask·(s8 + 127) + 127` (`MASK_SCORE = −127`,
`pb/layout.rs:75`), `c0 = zsel² − zsel`, `c1 = zsel·δ`, `c2 = 2^fp·mask·e − p·sum − L16(sr)`,
`c3 = L16(sg) + L16(sr) + 1 − sum`, `cx = hx·(α − (δ + β·e + γ·129)) − 1`. Lean (`F/SlotW16Build.lean:402-425`):
node0 `mx − mask·s8 − 127·mask + 127` (= Rust's δ expanded: `−mask·(s8+127)+127`), nodes 3-6 the same `c0..c3`,
node7 `(α − γ·129) − δ − β·e`, node8 `hx·node7 − 1`, node9 `Σ μ_q·node_{3+q}`; Z = LogUp(μ_{4+k}) + μ_{4+nh}·node8
+ pad(μ_{5+nh}) + gS·node9; terms `1·τ·Z`, `ν0·eq_pht·gHt·(sum+λ)`, `ν1·eq_ps·gS·reqB(score, s8)`. K =
`⟨127, 12, 19⟩`; Rust `f_p = 12`, score 19 (params read row 35). Identical. The verifier uses `def.poly`, not the
equality groups the prover uses (`pb/argument.rs:2275`). The S lookup list matches in order
(`pb/accuracy_layout.rs:328-335` vs `F/BlockDefineW16.lean:213-215`).

## 6. Points cross-checked (DERIVED lengths)

`claimPt` lengths equal the slot logs: WO 7+12 = 19, DMM 7+12 = 19, GMM/UMM 7+14 = 21, QMM 7+12 = 19,
PV 7+5+7 = 19, KMM/VMM 7+10 = 17, SCORE 5+7+7 = 19, `p_ht` 12; matching D 19, F 21, Q 19, Kv 17, S 19, Ht 12 (params read).

## 7. Limits (what was not read, what was taken on trust)

- **L1, generic consumer.** I compared each slot's `SlotDef` (tables, polynomial, hosted list, nonzero list). I did
  not read the Lean code that consumes a `SlotDef` (`F/ExecBlockVerify.lean`) to confirm that it opens each private
  table at the slot point in table order and uses `scalar + Σ hosted` as the claimed sum, as `pb/argument.rs:2243-2275` does.
- **L2, ids.** Plane ids (`idsW`, `F/BlockDefineW16.lean:113-145`, pinned at `F/BlockW16U1Base.lean:83-96`) and
  helper ids (`hIdsN`, `hDoms`, `:227-237`) were taken from Lean. I did not re-derive `accuracy_layout.rs::new_w16`,
  `range_planes`, `HIds::new`, `table_helpers`, `range_helpers`. Every table position above is MATCH conditional on them.
- **L3, public-table values.** The theorem quantifies over `B : W16Pub` (`F/LayoutW16.lean:226-276`), which fixes
  `gamA`, `gamM`, cos, sin, mask, `grpCol` and gates only at true positions (plus `gD_pad`, `gS_pad`). I did not check
  that the code's `repeat_vals`, `rope_tables_at`, `causal_mask_at`, `group_column`, `indicator_table` meet those fields,
  nor the `msbIndex`/`split*` orientation of `cubeTab` against the code's index order. TAB's tables are fully defined in Lean
  and were compared (§3), conditional on `Pb.exp`, `Pb.act`, `nG` being the code's `public.exp`, `scaled_tables`, group count.
- **L4, constants from the configuration.** `tn = 1`, `cnA`, `cnM`, `q,k,v,pv,ao,down,score,up,gate,fp` were taken from
  `precShieldW16U1` (`F/RunShapeShieldU1.lean:100-119`) and the params read (row 35), not re-derived; `fold = 16` and
  `SH_ROPE = 7` were checked here (finding 3; `pb/layout.rs:67`). `norm_tn = base − 8` (`pb/accuracy_precision.rs:71`) gives
  1 only if the calibration's base `norm_tn` is 9, as `F/RunShapeShieldU1.lean:10` types it.
- **L5, the IR port.** I did not compare the Lean IR with `slot_ir_accuracy.rs`; the comparison is with the closure,
  which is what the verifier evaluates. Field arithmetic order differs between the two but both are field expressions.
- **L6, dispatch.** That this profile reaches the `range16()` arm with `dd_cap = 0` (`pb/argument_accuracy.rs:24-33`) is
  from the params read, not re-derived.
