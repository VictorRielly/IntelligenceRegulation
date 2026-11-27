# W16R2 Shieldstral T128: plane and helper numbering, and how a slot definition is consumed (read-only)

Date: 2026-11-27. Reader: an independent agent. No file was changed, nothing was built or run.
This report checks two of the three things the define read
(`W16R2_DEFINE_READ_20261127.md` §7) took on trust: L2 (ids and placement) and L1 (the generic consumer).

Paths. `F/` = `formal/ZK60Formal/`. `pb/` = `ops/zkp-mvp/gpu-metal/hashline/src/private_block/`.
`zc/` = `ops/zkp-mvp/gpu-metal/zkp-core/src/` (the path `pb/../../Cargo.toml:33` names).

## 0. Which configuration the statement uses

`block_knowledge_w16r2_shieldU1` (`F/BlockW16U1Done.lean:59`) takes
`hdef : P.define = defineS (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut) …` (`:70-71`).
`cfgU1 = cfgShieldU1` (`F/BlockW16U1Base.lean:48`), and
`cfgShieldU1 cnA cnM = ⟨shShieldW16U1, precShieldU1 cnA cnM, famsShieldW16U1, 14⟩` (`F/BlockDefineW16Shield.lean:40-41`).

- Precision (`F/BlockDefineW16Shield.lean:34-37`): h24, ao 21, down 22, q 15, k 15, v 16, score 19, pv 12,
  gate 20, up 12, fp 12, wrho 16, rope 7.
- Limb counts by `limbsOf b = if b ≤ 16 then 1 else 2` (`F/SlotW16BuildLayout.lean:71`):
  la 2, ld 2, lq 1, lr 1, lpv 1, lk 1, lv 1, lsc 2, lw 1, lg 2, lu 1, lht 1, lrh 1 (`rhWidth true = 16`, `:65`).
- Range families (`F/RunShapeShieldU1.lean:125-126`): (3,1) (4,1) (5,1) (6,1) (7,1) (12,1) (13,1) (15,2) (16,4).
  So `nRange = 13`.
- Shape `shShieldW16U1` (`F/BlockInstW16Shield.lean:65-69`, on `shShield` and `sh8B`, `F/SlotW16R2.lean:321-352`).
  Its domain logs are T 7, Ht 12, L 14, D 19, Q 19, Kv 17, S 19, F 21, Tab 14. Pads: L, D, F, Tab. `padRule` true.

On the Rust side: the profile row at `pb/shape.rs:301` (tokens 128, width 3072, hidden 9216, 32 query heads of
128, 8 kv heads, log_cols 14, stack LowH24). The pads come from `pb/shape.rs:1036-1037`: t 128, d 4096, h 32, f 16384.

I evaluated every Lean definition below by hand. My values agree with the `decide` lemmas at
`F/BlockW16U1Base.lean:79-100` and `F/BlockDefineW16Shield.lean:50-75`. I did not take my values from those lemmas.

## Part A. Numbering and placement

### A.1 Rust inputs that fix the limb counts

`AccuracyIds::new_w16` (`pb/accuracy_layout.rs:113-185`) sizes each remainder group with `range16::limbs_of`
(`pb/range16.rs:114-121`: 1 if `bits ≤ 16`, else 2). For this LowH24 stack, `accuracy_precision::derive` refuses
any calibration outside these windows (`pb/accuracy_precision.rs:84-89`):

- q, k, v, pv, up in 9..=16, so 1 limb each;
- score, ao in 17..=24, so 2 limbs each;
- down in 17..=24, so 2 limbs.

`new_w16` refuses a gate shift outside 17..=24 (`:115`), so the gate has 2 limbs. `SH_ROPE = 7` (`pb/layout.rs:67`),
so rope has 1 limb. Every limb count is therefore forced by the code, except one: the softmax window `wrho_s`. It
is `clog2(T) + f_e` (`pb/shape.rs:1125`) with `f_e ∈ 9..=16` (`:398`). That is 16, giving 1 limb, only when
`f_e = 9`. I did not find this profile's `f_e` in code. It comes from the calibration. That is input row A29.

### A.2 Plane ids (A commitment)

Rust ids are positions in `new_w16`'s push order (`word` and `group`, `pb/accuracy_layout.rs:32-46`).
Lean ids are `idsW` (`F/BlockDefineW16.lean:116-145`). † means the row depends on input A29.

| # | planes | Lean (`F/BlockDefineW16.lean`) | Rust (`pb/accuracy_layout.rs`) | verdict |
|---|---|---|---|---|
| A1 | T: d, dsq, dm, dsqm | 0,1,2,3 (`:135`) | 0..3 (`:122`) | MATCH |
| A2 | Ht: mx, sum | 4, 5 (`:135`) | 4, 5 (`:123`) | MATCH |
| A3 | L: limb, limbm | 6, 7 (`:135`) | 6, 7 (`:124`) | MATCH |
| A4 | D: x, y | 8, 9 (`:135`) | X 8, XL empty, Y 9, YL empty (`:125-126`) | MATCH |
| A5 | nr, ns | [10,11], [12,13] (`:135-136`) | NR 2, NS 2 (`:127`) | MATCH |
| A6 | ao, ral | 14, `range' 15 la` = [15,16] (`:136`) | AO 14, RAL `limbs_of(ao)` = 2 (`:128-129`) | MATCH |
| A7 | x1, ym | 17, 18 (`:136`) | X1 17, YM 18 (`:130-131`) | MATCH |
| A8 | mr, ms | [19,20], [21,22] (`:136-137`) | MR 2, MS 2 (`:132`) | MATCH |
| A9 | z, rdl, x2 | 23, [24,25], 26 (`:137`) | Z 23, RDL `limbs_of(down)` = 2, X2 26 (`:133-135`) | MATCH |
| A10 | Q: q, rql, qr, rqrl, o, ro | q0 = 23+la+ld = 27; 28; 29; 30; 31; 32 (`:130,137-139`) | Q 27, RQL 1, QR 29, RQRL `limbs_of(7)` = 1, O 31, RO 1 (`:136-141`) | MATCH |
| A11 | Kv: k, rkl, v, rvl, kr, rkrl | k0 = 33; 34; 35; 36; 37; 38 (`:131,139-140`) | K 33, RKL 1, V 35, RVL 1, KR 37, RKRL 1 (`:142-147`) | MATCH |
| A12 | S: s, rsl, zsel, e, pp | s0 = 39; [40,41]; 42; 43; 44 (`:132,140-141`) | S 39, RSL 2, ZSEL 42, E 43, P 44 (`:148-149`) | MATCH |
| A13 | sr, sg | [45], [46] (`lw = 1`) (`:142`) | `division_w16(S, limbs_of(wrho_s))`: PL empty, SR, SG (`:150,191-195`) | MATCH† |
| A14 | F: g, rgl, a, u, ru | f0 = 47; [48,49]; 50; 51; [52] (`:133,142-143`) | G 47, RGL `limbs_of(gate_shift)` = 2, A_SCALED 50, U 51, UL empty, RU 1 (`:151-153`) | MATCH† |
| A15 | h, ht, rh | 53, [54], [55] (`:144`) | H 53, HT `from(h24)` = 1, RH `limbs_of(16)` = 1 (`:154-155`) | MATCH† |
| A16 | Tab: MU8, MEXP, MACT | t0 = 56, 57, 58 (`:134`; `domPl Tab`, `:171`) | 56, 57, 58 (`:160`) | MATCH† |
| A17 | range sub-planes | t0+3+j for j < 13, width `subW[j]`, families in list order (`:158,488`) | `first_range + j` over `sub_planes(families(seen))`: widths ascending, s ascending (`:181-183,205-207`; `pb/range16.rs:207-214`); sub = `max(1, 2^w >> 14)` | MATCH† |
| A18 | domain bounds | 0,4,6,8,27,33,39,47,56,72 (`:160-168`) | T 4, Ht 2, L 2, D 19, Q 6, Kv 6, S 8, F 9, Tab 16 planes (`pb/shape.rs:2477-2482`, with `w16_windows` `:881-888`). `Ids::new` refuses if they differ from `new_w16`'s (`pb/layout.rs:371`). `domain_range` refuses non-contiguity (`:511-516`) | MATCH† |

### A.3 Helper ids (H commitment)

Lean: `nHelp d = ⌈|lookupsN d| / 2⌉` (`F/BlockDefineW16.lean:219`), `hIdsN` (`:222-231`), `hDoms` (`:236-239`).
Lookup counts: L 2, D 19, Q 6, Kv 6, F 7, S 7 (from `:196-216` at this precision).

Rust: `helpers = ⌈lookups_per_position / 2⌉` (`pb/shape.rs:2563-2565`). The counts per position are
L 2, D 19, Q 6, Kv 6, F 7, S 7 (`:2527-2530`). `Layout::for_shape` refuses when they differ from the real lookup
lists (`pb/layout.rs:1375-1380`). Ids are given by `HIds::new` (`pb/layout.rs:623-654`).

I compared the two lookup lists term by term: Lean `:200-215` against Rust `pb/accuracy_layout.rs:299-337`. Same
order, same widths, same planes.

| # | helpers | Lean | Rust | verdict |
|---|---|---|---|---|
| A19 | L | 1 helper, id `fh 0` = 0 | `first_l` = 0, 1 helper (`:636`) | MATCH |
| A20 | D | 10, from `fh 1` = 1 (ids 1..10) | `first_d` = 1, 10 (`:637`) | MATCH |
| A21 | Q | 3, from `fh 2` = 11 | `first_q` = 11 (`:638`) | MATCH |
| A22 | Kv | 3, from `fh 3` = 14 | `first_kv` = 14 (`:639`) | MATCH |
| A23 | S + exp pair | 4 from `fh 4` = 17; `sexp` = `fh 5` = 21 | `first_s` = 17; `sexp` = 21 (`:640-641`); no tuple helper (dd 0, `:643`) | MATCH† |
| A24 | F + act pair | 4 from `fh 6` = 22; `fact` = `fh 7` = 26 | `first_f` = 22; `fact` = 26 (`:644-645`) | MATCH† |
| A25 | table helpers | `gu8` = `fh 8` = 27, 28, 29 (`:488`) | `table_helpers` = gu8..gu8+2 = 27..29 (`:648,683-685`) | MATCH† |
| A26 | range helpers | `gu8 + 3 + j` = 30..42, paired with plane t0+3+j (`:488`) | `range_helpers` = 30..42, paired j-to-j with `range_planes` (`:688-690`; `pb/argument_accuracy.rs:744-758`) | MATCH† |
| A27 | u | `fh 10` = gu8+3+13 = 43 (`:231,491`) | `u` = 43 (`:649`); `SC_ZS` uses `hids.u()` (`pb/argument.rs:3934`) | MATCH† |
| A28 | limb counts | `limbsOf` of the Lean precision (`:117-129`) | forced by `derive` and `new_w16` refusals (§A.1), except `wrho_s` | MATCH |
| A29 | exact inputs | wrho 16; exact values ao 21, down 22, q 15, k 15, v 16, score 19, pv 12, up 12, gate 20, fp 12 (these fix the range widths) | `wrho_s = 7 + f_e`; the exact shifts come from the calibration (`pb/accuracy_precision.rs:71-83`) | NOT DETERMINED |

Uses of these ids in the slot arms (A tables by plane; helpers by role) were read on the Rust side at:
`pb/argument.rs:2985, 3025, 3073-3083, 3136-3137, 3163-3168, 3231-3234, 3325-3358, 3375-3377, 3934, 4015-4016`, and
`pb/argument_accuracy.rs:470-476, 510-513, 545-552, 585-592, 744-758`. Each matches the Lean `rawSlot` arm
(`F/BlockDefineW16.lean:318-494`) on plane id and helper id. Examples: QMM/KMM/VMM read `y`, WO reads `o`, GMM/UMM
read `ym`, DMM reads `h`, SCORE reads `qr`/`kr`, PV reads `pp`/`v`, RS reads `e` then `zsel`, IO reads `x` / `x2`.

### A.4 Placement (rows)

Rust places planes in plane order with a running row count (`pb/layout.rs:1323-1328` for A, `:1343-1349` for H).
Lean uses domain starts (`domRow`, `aOff`, `F/BlockDefineW16.lean:180-185`) and a prefix sum for H (`hOff`,
`:242-245`). The two forms agree because, on both sides, the planes are contiguous per domain and in `ALL_DOMS`
order (`pb/layout.rs:973`; Lean `allDoms`, `:148`). I checked that in A18.

Rows per plane: Lean `max 1 (2^log / 2^14)` (`:177`); Rust `max(1, size >> log_cols)` (`pb/shape.rs:2455-2457`).
Rust logs are `domain_log_at(natural_log, carries_h_planes, 14)` (`pb/shape.rs:2415-2451`, `pb/layout.rs:175-200`).
Only T and Ht are not lifted.

| # | item | Lean | Rust | verdict |
|---|---|---|---|---|
| P1 | domain logs | T 7, Ht 12, L 14, D 19, Q 19, Kv 17, S 19, F 21, Tab 14 (`F/SlotW16R2.lean:333-334`) | clog2: T 128 → 7; Ht 32·128 → 12; L 16·128 → 11, lifted to 14; D 128·4096 → 19; Q 128·32·128 → 19; Kv 128·8·128 → 17; S 32·128·128 → 19; F 128·16384 → 21; Tab 256 → 8, lifted to 14 | MATCH |
| P2 | rows per plane | T 1, Ht 1, L 1, D 32, Q 32, Kv 8, S 32, F 128, Tab 1 | same formula and logs | MATCH |
| P3 | A domain order | `allDoms` T, Ht, L, D, Q, Kv, S, F, Tab | `a_plane_doms` the same order (`pb/shape.rs:2477-2482`) | MATCH |
| P4 | A first rows | T 0, Ht 4, L 6, D 8, Q 616, Kv 808, S 856, F 1112, Tab 2264 (`domRow`) | the running sum gives the same rows | MATCH† |
| P5 | A plane offset | `(domRow + (q − start)·rows)·2^14`. Examples: y 40, x2 584, o 744, kr 840, pp 1016, h 1880 (rows) | `a_off[q] = row·n` | MATCH† |
| P6 | A data rows | 4+2+2+608+192+48+256+1152+16 = 2280 (`aDataRows`, `:188`) | `a_data_rows = row` after the loop (`pb/layout.rs:1329`): same terms | MATCH† |
| P7 | H plane order | L1, D10, Q3, Kv3, S4+1, F4+1, Tab 3+13+1 = 44 (`hDoms`) | `h_plane_doms` (`pb/shape.rs:2568-2589`); `HIds::new` refuses if different (`pb/layout.rs:650`) | MATCH† |
| P8 | H first rows | L 0, D 2, Q 642, Kv 834, S 882 (sexp 1138), F 1202 (fact 2226), Tab 2482, u 2514 | same running sum | MATCH† |
| P9 | H halves | `(row·n, (row + rows)·n)`, then `row += 2·rows` (`:243-245`) | `(row·n, (row + r)·n)`, then `row += 2r` (`pb/layout.rs:1346-1348`). Slices `[(re, 1), (im, U)]` on both sides (`pb/argument.rs:2536`; Lean `hTab`, `:271-273`) | MATCH |
| P10 | H data rows | 2 + 640 + 192 + 48 + 320 + 1280 + 34 = 2516 (`hDataRows`, `:248`) | `h_data_rows` (`pb/layout.rs:1350`) | MATCH† |
| P11 | A sites | `aBase + 2·ak`, aBase = 2280; per slot `cmCountS .a` = `aCntW16Shield` (sum 111) | `a_site = a_mask_base + 2(prefix + k)` (`pb/layout.rs:1496-1501`). `claim_sites` gives 1,1,22,2,2,1,1,1,2,2,1,1,1,1,21,7,7,10,9,16,0,1,1 (`pb/shape.rs:2597-2643`), sum 111. Sites 2280..2501, proximity pair 2502-2503, rows 2504 | MATCH† |
| P12 | H sites | `hBase + 2·hk`, hBase = 2516; `hCntW16Shield` (sum 44) | `h_site` (`:1502-1507`). h counts: LZC 1, DZC 10, QZC 3, KVZC 3, SZC 5, FZC 5, TAB 16, ZS 1 = 44. Sites 2516..2603, proximity 2604-2605, rows 2606 | MATCH† |
| P13 | site index within a slot | `ak`/`hk` count private tables of that commitment, in table order, through the block (`numTabs`/`numProg`, `:515-533`) | `B::new` starts `ak = hk = 0` per slot (`pb/argument.rs:2351`). `a_slice` and `h` take the site and increment (`:2488-2492, 2531-2537`) | MATCH |
| P14 | L limb sub-slices | `aOff limb + k·2^lt`, k < 9 (`:329,331`) | `limb_off(k) = a_off[LIMB] + k·t_pad` (`pb/layout.rs:1520-1525`), `N_LIMBS = 9` (`:297`), `t_pad = 2^7` | MATCH |
| P15 | endpoint pair | `ioIn` / `ioOut` are free in the theorem (`F/BlockW16U1Done.lean:69`) | `io_mask_row = endpoint_rows − MASK_ROWS` for a single block (`pb/layout.rs:1407,1427-1429`) | MATCH (Lean covers every value) |
| P16 | pads and zero-rule planes | `pads` L, D, F, Tab. `zeroPl`: all planes except E and the full-width sub-planes, `fullW = 14 ≤ w` (`:252-257`) | `pads = size ≠ true_size` (`pb/shape.rs:2460-2462`) gives L, D, F, Tab. `a_rule`: full family exempt, E exempt (`pb/pad.rs:294-315`). `carries_pad_rule` = not the toy (`pb/shape.rs:2344-2346`) | MATCH |
| P17 | terminals per slot | `shieldTerms` (`F/BlockInstW16Shield.lean:37-38`) | `slot_terms = a + h + [IO]` (`pb/shape.rs:2646-2653`): the same 23 values from the counts in P11 and P12 | MATCH† |

### A.5 Part A totals

I counted the rows of the three tables above. A.2 has 18 rows, A.3 has 11, A.4 has 17: 46 rows read on both
sides.

- MATCH: 45. Of these, 20 are marked †: they hold given input row A29.
- NOT DETERMINED: 1 (A29).
- MISMATCH: 0.

A29 matters in two ways. If `f_e ≠ 9`, Rust would allocate 2 SR and 2 SG limbs where Lean has 1. If an exact
shift differed, the set of range widths, and so `nRange`, could differ. Both are calibration facts, not code.
The Rust side refuses internal inconsistency in either case (`pb/layout.rs:368,371,650,1375-1380`).

## Part B. How a slot definition is consumed

### B.1 How the two sides line up

Lean `slotStep` (`F/ExecBlockVerify.lean:327-354`) corresponds to Rust's `define` (`pb/argument.rs:4156`) plus
`run_slot_with`'s common prefix and its Verify arm (`pb/argument.rs:1849-1894, 2249-2320`). Lean `slotDefChecks`
(`:287-298`) is Rust's checks at `:1854-1879`. Lean `slotAcc` (`:302-319`) is Rust's claim and functional code at
`:2287-2313`. The block level is Lean `blockSlots` / `blockVerify` (`:378-410`) against Rust `verify_core`
(`pb/protocol.rs:4325-4438`) and `argument_with` (`pb/argument.rs:4106-4216`).

The line numbers in the Lean header (`argument.rs` 1143-1503, 1033) are stale. The code now sits at the lines
above.

### B.2 Step-by-step comparison

| # | step | Lean | Rust | verdict |
|---|---|---|---|---|
| B1 | shape, layout and statement checks | `P.preChecks` (abstract) (`:391`) | `check_constructed`, `check_is_for_shape`, `check_for_shape` (`pb/protocol.rs:4329-4332`) | NOT DETERMINED (abstracted) |
| B2 | T-4 path depths A, H, M, before any absorb | `pathsDepth` × 3 (`:392-394`) | `paths_are_the_tree_depth` × 3 (`:4347-4349`) | MATCH (order; depth values not checked here) |
| B3 | absorb A root, `rows`, `log-cols` | `absorbRoot labA aRows logCols` (`:379,207-208`) | `absorb_root(b"A", a_rows, log_cols)` (`:4350,154-158`) | MATCH |
| B4 | absorb M root | `:380` | `:4351` | MATCH |
| B5 | draw β, γ, α in that order | `:381-383` | `:4352-4354` | MATCH |
| B6 | absorb H root, rows, log-cols | `:384` | `:4358` | MATCH |
| B7 | slot count | loops over the decoded list, whose length is fixed to `geom.slots` by `rdSlots` (`F/ExecBlockWire.lean:192,239`) | `for slot in 0..n_slots` with "missing slot" refusal (`pb/argument.rs:4145,2250`) | NOT DETERMINED (Rust decoder not read) |
| B8 | define's draws and refusals | draws first, then `P.define` refuses (`:333-334`; stated at `:29-31`) | draws interleaved with `nonzero(...)?` | NOT DETERMINED (`defineS` not read) |
| B9 | schedule check: slot index, private count = terms, host-ness | `:290-292` | `:1855-1857` | MATCH |
| B10 | table shape: `ext_round ≥ e` or coords ≠ log | `:293-295` | `:1858-1860` | MATCH |
| B11 | verifier received PubGen descriptors | no counterpart | `:1861-1863` | MISMATCH, Rust stricter (harmless; `pub_gen_on` is false on verify, `:4117`) |
| B12 | public table length = 2^n | `:296-297` | verify path `v.len() != 1 << n` (`:1871-1879`) | MATCH |
| B13 | absorb `pb-slot` u64 s | `:337` | `:1887` | MATCH |
| B14 | draw c; refuse zero | `:338-340` | `:1891-1894` | MATCH |
| B15 | terminal count = private count | `:341` | `:2251-2253` | MATCH |
| B16 | absorb `pb-scalar` [scalar] | `:342` | `:2254` | MATCH |
| B17 | claimed = scalar + Σ coef·scalars[hs], in hosted order | `hostedSum` (`:279-283`); out of range is an error | fold (`:2255`); out of range is a panic | MATCH (both reject) |
| B18 | sumcheck over n+e rounds of degree d: count, d+1 values, s0+s1 = claim, absorb `sc-round`, draw, interpolate | `scVerify` (`F/ExecSumcheck.lean:121-138`) | `sumcheck::verify` (`zc/sumcheck.rs:140-165`), call at `pb/argument.rs:2256` | MATCH (interpolation body not re-read) |
| B19 | ρ = first n, es = the rest, sel = Π(1−e) | `:347-350,240` | `:2257-2259` | MATCH |
| B20 | eq table value | `sel · eqPoint(point, ρ[start..])`; out of range is an error (`:244-249`) | `sel · eq_point(point, ρ[start..start+len])`; out of range is a panic (`:2267`) | MATCH |
| B21 | public table value | `sel · evalMleExt v ρ` (`:250-253`) | `sel · eval_mle_ext`, or `SplitEq::eval_ext` when A26 is on (`:2262,2268`) | NOT DETERMINED (A26 path not read) |
| B22 | private terminal | `terms[k]`, k counts private tables (`:254`) | `sp.terms[k−1]` after `k += 1` (`:2269-2272`) | MATCH |
| B23 | terminal value | `gVal = (fin − poly(vals))·c⁻¹` (`:351`) | `:2275` | MATCH |
| B24 | refuse e = 0 or e = 1 | after gVal, before `pb-term` (`:352`) | `:2282-2284`, same place | MATCH |
| B25 | absorb `pb-term` terms | `:353` | `:2285` | MATCH |
| B26 | claim coefficients | `cd = Π(1−e)`; `cm = es[r]·Π_{i>r}(1−e_i)` (`:273-274,267`) | `:2287,2291` | MATCH |
| B27 | claim point | `rho.getD k 0`, `1 − rho.getD k 0`, fixed (`:219-223`) | `rho[k]` (panics if out of range), `1 − rho[k]`, fixed (`:467-476`) | MISMATCH, Rust stricter on an out-of-range index (harmless; the definition chooses the indices) |
| B28 | `build_claim` | data parts `(off, log, coef·cd, point)`, then `(maskRow·n + c0, logm, cm·1, tail)` and `((maskRow+1)·n + c0, logm, cm·U, tail)`. `c0` and `tail` as in Rust (`:226-234`) | `:1725-1739`; `row_log` (`:1624-1629`); `U = (0, 1)` (`zc/field.rs:146`) | MATCH |
| B29 | claim order and target | pushed to `claims[cm]` in table order (`:270-276`) | `acc.claims[p.cm]` in table order (`:2289-2295`) | MATCH |
| B30 | standalone Γ | `(s, sumWeights(n+e, d)·c)`, value scalar (`:310-313`) | `sum_weights` (`:1785-1788`, `zc/sumcheck.rs:227-232`), `:2300` | MATCH |
| B31 | host Γ, after the slots | `(s, sw·c)` plus per hosted `(hs, sw_hs·(coef·c_hs)).neg` (`:314-317`) | `(hs, sw_hs·(−(coef·c_hs)))` (`:2301-2307`) | MATCH (field-equal) |
| B32 | evaluation functional | `(s, evalWeights(ρ‖es, d))`, value gVal, after Γ (`:319`; `F/ExecCfs.lean:84-85`) | `:2311`; `zc/sumcheck.rs:235-248` | MATCH |
| B33 | after the slots: `fs ++ hostFs`, count = `nFunctionals` | `:396-397` | `:4211-4215` | MATCH |
| B34 | M test | `P.maskVerify` on fs (`:398-400`) | `mask_verify_tagged` (`pb/protocol.rs:4370`) | MATCH (position; internals abstract) |
| B35 | H closed by the LogUp sum claim | `hc = h ++ [logupSumClaim]` (`:401`). Under `hls` this is `logupSumW16`: per H plane `(re, log, ±1, [])`, `(im, log, ±U, [])`, sign −1 on 27..42, value 0 (`F/BlockDefineW16.lean:599-603`) | `finish_claims` and `logup_sum_claim` (`pb/protocol.rs:340-344,171-188`): the same parts, `is_table` = gu8..gu8+3+13 | MATCH |
| B36 | A: check_opening, then pcs | `:402-405` | `:4378,4383` | MATCH (order) |
| B37 | H: check_opening, then pcs | `:406-409` | `:4408,4413` | MATCH (order) |
| B38 | opening challenge refusals on a clone | `openingChallenges` (`:445-449`) | `check_opening_challenges` (`pb/protocol.rs:312-323`) | MATCH (both read; whether `P.checkOpening` contains it is not fixed here) |
| B39 | schedule audit and group count (36 / 9) | inside `P.checkOpening` (abstract) | `audit_claims`, `opening_groups_at` (`:249-304,210-223,327-337`) | NOT DETERMINED (Lean abstract) |
| B40 | result | `(claims.inp, claims.out)` (`:410`) | `([ic, oc], order)` (`:4438`) | MATCH |

### B.3 Part B totals

I counted 40 rows.

- MATCH: 33.
- MISMATCH: 2 (B11, B27). Both are Rust stricter, which is harmless for soundness.
- NOT DETERMINED: 5 (B1, B7, B8, B21, B39).

### B.4 Notes

- **Batching scalars.** The group member coefficients and the proximity ρ belong to `pcsVerify` /
  `checkOpening` on the Lean side, which are parameters. Only their refusal schedule (B38) was compared.
- **Free row counts.** `IsShieldW16` (`F/BlockInstW16Shield.lean:140-150`) pins `rowsOf` for the PCS but not
  `P.aRows` / `P.hRows`, which the header absorbs (B3, B6). The theorem holds for every value, so the code's value
  is covered. A reader should not take those two fields as checked.
- **Slot kinds.** `P.kind` is fixed by the statement only at slots 3, 19 and 20 (`F/BlockW16U1Done.lean:73-74`).
  Rust reads the constant `SLOT_KINDS`. The Lean step takes any kind, so this is not a mismatch.
- **Equality groups.** The Rust `SlotDef` carries equality groups (`def.groups`, set in
  `pb/argument_accuracy.rs:639`). The verify arm never reads them, so their absence from the Lean `SlotDef`
  (`F/ExecBlockVerify.lean:93-96`) is not a gap.

## What I took on trust

1. Input row A29: this profile's `f_e = 9` (so `wrho_s = 16`) and the exact calibrated shifts
   (ao 21, down 22, q 15, k 15, v 16, score 19, pv 12, up 12, gate 20). The code forces every limb count except
   the softmax one. It does not force the exact values, which fix the range widths. 20 Part A rows are conditional
   on this.
2. That the slot schedule `(n, e, d)` and draw counts equal `shieldSlots` and `shieldDraws` (the parameters read).
3. That `interpolate_eval` matches `interpolateEval`, `eq_point` matches `eqPoint`, and `eval_mle_ext` matches
   `evalMleExt` (earlier L6 work). Also that `Fp2` equality, `is_zero` and `inv` agree with the Lean word
   operations.

## What I did not read

- Lean `defineS` (how a `SlotS` becomes a `SlotDef`, including its `nonzero` refusals) and `progOKb` / `tabOKb`.
  These are relevant to B8 and to whether B27 can ever trigger.
- The Rust wire decoder (B7) and the A26 `SplitEq` path (B21).
- The bodies of `pcs::verify_zk_tagged` and `zk::mask_verify_tagged`, and `pcsField` / `maskField`.
- The Rust SS/SSM arm bodies beyond their plane id (`pb/argument.rs:2985, 3025`).
- `SLOT_KINDS`.
- Where this profile's calibration (`f_e`, base shifts) is stored.

## Where Part B stopped

Part B is complete at the level of the slot consumer and the block verifier's order of operations. It stops at
the boundary of the four abstract parameters (`preChecks`, `maskVerify`, `checkOpening`, `pcsVerify`). Their
internals, including the batching scalars inside the PCS, were not compared.
