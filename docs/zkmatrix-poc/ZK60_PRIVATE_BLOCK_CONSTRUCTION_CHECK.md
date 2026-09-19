# ZK60 — adversarial check of the private-block construction memo (C.1, C.3, C.4, D, E, F, G)

**Status: COMPLETE — 1 BLOCKING, 11 CORRECTIONS, 10 NOTES. The accepted counts
reproduce; every grown count in §C.3 is confirmed; the two `[ESTIMATE]` group
counts are now derived (31 / 8); the tools pass on the grown paper schedule;
the `A_Z16` soundness gap is confirmed and nothing in the draft prevents a
Tier-1 artifact from carrying the block profile.**

| | |
|---|---|
| Document under check | `docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_CONSTRUCTION.md` (1,401 lines), DRAFT of 2026-09-19 |
| Sections checked | C.1, C.3, C.4, D, E, F, G, plus decisions 6/7/8 of H.3 and the `A_Z16` question |
| Sections NOT checked | B, C.2, C.5, H.1, H.2, the other eleven H.3 decisions, §I (reviewed elsewhere or out of brief) |
| Worktree / branch | `/home/victor/wt-zk60-attention-compile`, `zk60-attention-compile` @ `0795c6c` |
| Evidence written | `results/zk60_private_block_construction/` (see §7) |
| Checker | independent Opus agent, adversarial brief, 2026-09-19 |

## 0. Scope, method and what a verdict here means

**Method.** Nothing in the draft was taken on trust. Every count in §C.3 was
re-derived from `hashline/src/private_attention/layout.rs` and `argument.rs`
with my own arithmetic, first for the ACCEPTED component (to prove the method,
not the memo) and then for the grown one. Every source citation the checked
sections make was opened. The two security tools were then run — first
unmodified on the accepted layout, to confirm I reproduce the accepted
verdicts, and then on a grown Tier-1 schedule description I built and drove
through the same code (§7).

**What a verdict here is not.** §7 reports what two linear-algebraic models say
about a **paper schedule**. No Rust implements the grown layout. A `disclosed_dim
= 0` there is evidence about that description under those models' stated
exclusions (sampled columns, salted Merkle paths, the CFS channel, transcript
conditioning, `A ↔ H` correlation), and it is not a privacy property of any
code. Nothing below establishes a privacy property of anything.

**No build, no proof.** No `cargo`, no test, no example, no receipt. Python was
used only to drive the three committed tools and for the arithmetic of §3/§4/§5.
No file outside this document and `results/zk60_private_block_construction/`
was created or changed.

**Reproduction of the accepted numbers — the precondition.** Running
`scripts/zk60_attention_native_inventory.py` unmodified against this worktree
(`results/zk60_private_block_construction/accepted_rerun/`, log
`accepted_rerun.log`) reproduces **all twenty-nine** accepted cross-checks:
A 306 = 154 + 150 + 2, H 290 = 218 + 70 + 2, A sites 75, H sites 35,
A groups 30, H groups 8, M 40, functionals 28, largest `L` 50, U8 47,104,
exp 2,048, rounds 129 + 20, the eighteen `SLOTS` triples and the host map
`{1:[0], 10:[9], 11:[4,8], 12:[5,6], 13:[3,7]}`; rank verdicts all 0 except
`whole_H_with_values = 2` with the residual exactly the public identity; all
CFS slots pass; `failures: none`. My own hand arithmetic (§4) reproduces the
same 154 / 218 / 75 / 35 / 18 / 40 / 28 / 50 / 47,104 independently of the tool.
**The accepted numbers reproduce, so the downstream work stands on them.**

## 1. Findings, ranked

### BLOCKING

**B-1 — A Tier-1 build carrying the block profile proves nothing about the
block's output.** Confirmed exactly as the security owner suspected; see §11.
In Tier 1 the plane `A_Z16` is constrained by one degree-1 term, `c9 = x2 − x1 −
z16` (draft line 408), and by nothing else: it takes no U8 lookup (the draft's
own lookup list, lines 380–388, gives limbs to `A_X2` and none to `A_Z16`), it
is read by no other relation, and no Tier-1 slot ties it to `A_YM`. Therefore
for **any** int16 `xres2` the prover chooses or is handed, a satisfying witness
exists (`z16 := xres2 − xres1`). Yet the draft fixes the block profile string
`hashline-zk-mr1/private-block-t32-poc/1` (line 700), the `BlockPublic` digest
carrying `Wg, Wu, Wd, act` (lines 721–722), and `SC_IO_OUT` binding `A_X2`
(lines 495–499, Decision 4 at line 1299) **in the Tier-1 section**, and nowhere
forbids a Tier-1 artifact from carrying them. The nearest guard, Decision 12
(line 1332), is about re-running the tools. A verifier holding that statement
would accept a receipt whose block output is chosen, not computed. Fix and
tripwire test in §11.

### CORRECTION

| # | What the draft says | Source | Correct statement |
|---|---|---|---|
| C-1 | line 430–433: "`A_X1` is thereby opened at **four** points in the block (`SC_DZC`'s `ρ_D`, `SC_SSM`'s point, `SC_IO_OUT`'s old site is gone, and residual 2 reads it inside `SC_DZC`)" | `argument.rs:618` (`a_range(A_X, A_X1L1)`, one site), `:637` (`c5` reads `x1` at the same point, no new site), `:757` (the `SC_IO_OUT` site that is removed) | **Two** points: `ρ_D` in `SC_DZC` and `SC_SSM`'s own point. `c5`/`c9` read `x1` inside `SC_DZC` at the site already counted, and a site that is *removed* is not one of the points. The site *table* (line 540–546) is right; only the prose is wrong. |
| C-2 | line 1226–1229 (H.1): "`norm_m`'s bounds are structurally the same as `norm_a`'s but its input is `xres1`, an int16 value **that can be twice as large as `x_in` at the extremes**, so `ss_m` … must be re-bounded" | `layout.rs:226` + `argument.rs:634` pin `x_in` to int16; `layout.rs:232` + `argument.rs:636` pin `xres1` to int16 by the *identical* two-limb, offset-32768 pattern | The enforced class of `xres1` is exactly the enforced class of `x_in`, `[−32768, 32767]`. Under R-2's own method (bounds taken over the ranges the verifier enforces, `…REVIEW_R2.md:33-41`) every `norm_m` bound is **bit-identical** to `norm_a`'s, worst case 562,949,886,312,450 < 2⁴⁹ — unchanged. §3 gives each bound. |
| C-3 | line 620–621 and §I(d) line 1374: the §C.4 byte model "is reverse-derived from four published figures and is **not read out of `pcs.rs`**" | `hashline/src/private_attention/wire.rs:28-36` (`opening_len`, `encoded_len`) | The model is in the module's own wire file, not in `pcs.rs`, and the draft did not read it (§I says so). `opening_len(groups, rows) = (groups+1)·512·16 + 256·(8 + rows·8 + 32 + 11·32)` is `wire.rs:28-29` verbatim; the arguments term is `wire.rs:33` verbatim. The grown total 2,517,496 is therefore **derived from source**, not modulo a guess. One sub-term is wrong in form (C-4). |
| C-4 | line 625: `mask_open(M_ROWS) = 512·16 + 256·(8 + M_ROWS·8 + 32 + 15·32)` | `wire.rs:23-25, 34`: `2·MASK_VEC·16 + 256·(8 + M_ROWS·8 + 32 + MASK_PATH·32)` with `MASK_VEC = 1024`, `MASK_PATH = 12` | The real terms are `2·1024·16 = 32,768` and `12·32 = 384`, not `8,192` and `480`. Both errors are constant in `M_ROWS` and cancel (`32,768 − 8,192 = 256·(480 − 384)`), so the accepted 223,232 and the grown 227,328 are both right **by coincidence**. Anyone who reuses the draft's model at a different `MASK_VEC`/`MASK_PATH` gets a wrong answer. |
| C-5 | §G.2 line 1076 and the rubric at line 1069–1071: `single_base_row_per_claim_A_per_column` "accepted 15 → **grows**", and "a *smaller or zero* number is a **stop**" | measured on the grown schedule: **13**, verdict PASS (`results/zk60_private_block_construction/zk60_private_block_grown_pair_schedule.json`) | It **falls**, and must. Growing `SC_TZC` turns its seven `c0 = 32…224` singleton groups into two-member groups (the `A_LIMBM` sub-slices land in the same eight column windows), so A singleton groups go 22 → 14 and the control's *derived* expectation goes 15 → 13. The control's pass criterion is equality with `native_singleton_expectation`, not growth. The draft's rubric would raise a false stop on a correct implementation. |
| C-6 | §G.2 line 1079: `helper_sums_published_n4` "70 → grows (~82 `[ESTIMATE]`)" | measured **84** | The value is exactly `2 × (number of H claim sites)`: 2 × 35 = 70 accepted, 2 × 42 = 84 grown. |
| C-7 | line 373–375: the alternative to Decision 7 ("give `A_LIMBM` its own slot at degree 3") "costs one more slot and two more `M` rows and **saves 10 bytes of proof**" | `wire.rs:33-34`; a second `Dom::L` slot needs a second `Dom::L` helper (`helper_sum` cannot be split across slots, `argument.rs:454-470`), hence +1 H plane (+4 H data rows) and +1 H site | The alternative **costs** about 16.9 kB, not saves 10 bytes: arguments +512 B (`Σ(m+e)(d+1)` 626 → 656, terminals 146 → 147, slots 19 → 20), `M` 42 → 44 rows (+4,096 B), `H` +6 rows (+12,288 B). Decision 7 is right; its stated cost comparison is inverted. |
| C-8 | §F.2 line 980–987: the proposed `SLOT_TAGS` table, offered as "the whole namespace", lists only 1/2, 3/4, 21/22, 23/24 as allocated | `hashline/examples/zk60_seam_receipt.rs:26` and `hashline/tests/zk60_private_seam.rs:8, 90-93, 219` all use `SeamSpec::new(…, 10, 11)` | **10 / 11 is in use** by the standalone `private_seam` example and test-suite fixtures and must appear in the table (and 1/2 also appears in negative fixtures at `zk60_private_seam.rs:193, 202-205`). 41–48 and 61/62 are genuinely free — a repo-wide grep of `SeamSpec::new` finds only {1,2,3,4}, {10,11}, {21,22,23,24}. |
| C-9 | Decision 10 (line 1321–1326) and §F.2 line 976: "**Nothing enumerates either namespace today**" | `hashline/src/tables_attn.rs:28-30, 45-80` | True for the endpoint slot ids, **false for the LogUp table tags**: `tables_attn.rs` enumerates the attention statement's tags (`TAG_U16 128`, `TAG_EXP 129`, `TAG_PROB 130`, `TAG_INT8A 131`, `TAG_INT16A 132`, `TAG_U8 133`, `tag_srem_a(w) = 256+w`, `tag_win_a(sh) = 320+sh+16`) and states they are "disjoint from the FFN's: TAG_SILU 1, TAG_INT8 2, TAG_ACT16 3, TAG_INT16 4, the v2 range tags 16+sh, the v3 window tags 64+sh+8". A `TAG_ACT` for the block should be allocated **into that table** (134 is free), not invented beside it. |
| C-10 | §D line 709–712: the order is written "at the granularity of the actual absorb calls, **because that is what the transcript-order gate compares** (`acc.order`, `argument.rs:255`, `:328`, `:335`)" | `argument.rs:255, 328, 335` push exactly three strings per slot (`"slot NN begin"`, `"slot NN scalar+rounds"`, `"slot NN terminals"`); nothing else writes to `acc.order` | The transcript-order gate compares 54 coarse strings (3 × 18 slots) and covers **nothing** outside the slot loop — not the header labels, not the roots, not `β/γ/α`, not the openings. It is not a per-absorb gate, and it cannot detect a reordering of steps 1–10 or 12–16. The order list in §D is still right (§8); the justification for its granularity is not. |
| C-11 | Decision 5 (line 1302–1305): renaming `pa-slot`/`pa-scalar`/`pa-term` to `pb-*` is "**cosmetic**" | `argument.rs:254, 274, 305, 334` are in `run_slot`, the single code path both sides use | The labels are hard-coded in shared code. Renaming them either (a) forks `run_slot`/`argument.rs` per profile, or (b) changes the *attention* component's transcript too, invalidating the accepted experimental receipt and the R-1/R-2 records that were taken against it. The draft's §B.1 change table (line 138–144) lists `argument.rs` as gaining "new arms in `define`" only. Not cosmetic — name the fork. |

### NOTE

| # | Note |
|---|---|
| N-1 | §C.3's `A` / `H` opening-group counts are marked `[ESTIMATE]` (lines 586–587, 646) and §I(a) says the grouping was not enumerated. **They are now derived: A = 31, H = 8** (§7). The `[ESTIMATE]` tags can be dropped, and `31` should go into `A_GROUPS`. |
| N-2 | Decision 6 presents "`SC_TZC`'s `k` going 1 → 2" as the price to weigh. `k = 2` already has **three precedents in the accepted layout** — `SC_QZC`, `SC_KVZC`, `SC_SZC` (`layout.rs:375-377`) — each passing the same `rank = ΣL − (k+1)`, `kernel = k+1` criterion in the accepted R-1 record. Decision 6 costs strictly less than the draft implies. |
| N-3 | §C.1 specifies the new `SC_TZC` host term as `ν1·eq(r_t2, x)·(…)` but never says that `SC_TZC` therefore gains a **second public `Tab::Eq`** (it has `eq(τ)` and `eq(r_t)` today, `argument.rs:526-527`) and never says where `r_t2` is drawn (it must be drawn inside `SC_SSM::define` and stored in `Points`, mirroring `pts.r_t` at `argument.rs:517`). Neither costs a site; both are load-bearing for the implementer. |
| N-4 | §C.1 does not mention that `Layout::limb_off` (`layout.rs:477-479`) is hard-coded to `A_LIMB` and needs a second accessor for `A_LIMBM`, nor that `N_WITNESS` (`layout.rs:138`, checked at `protocol.rs:258`) must go 48 → 64. |
| N-5 | Decision 7 dismisses repacking with "not possible without widening the domain". The widening is never priced, and it is competitive: `Dom::L` at log 10 (one 1,024-entry `A_LIMB`, 18 of 32 sub-planes used) keeps `SC_LZC` at degree 3 (`L = 11·3 + 2 = 35`), keeps one `Dom::L` lookup (still 1,024 U8 lookups), keeps one `A` site in `SC_LZC` instead of two, drops `Σ(m+e)(d+1)` by 6 and costs the same 4 `A` data rows; it pays 4 more `H` data rows (`H_L` at log 10). Decision 7 remains defensible; the comparison in the memo is not one. |
| N-6 | §C.4 never mentions `wire::MAX_WIRE_BYTES = 4 MiB` (`wire.rs:26`), enforced at `wire.rs:74` and `:145`. Grown Tier 1 (2,517,496 B) uses 60 % of it; the §C.5 Tier-2 estimate (~3.1 MB) uses ~74 %. Worth a line in §C.5, because the cap is a hard refusal, not a budget. |
| N-7 | §E's "already a hard refusal" is exactly true for the **150 `A` and 70 `H` site-pair rows** and no wider. `audit_claims` keys on `site_rows` (`protocol.rs:90, 124`); the zero-sum pair `u` sits in H's *data* region (`layout.rs:473-476`, rows 216–217 of 218) and is checked only by the sum-claim branch (`:106-112`), and the two endpoint commitments are checked by a different, shape-only test (`:186-198`). The draft's table says so correctly row by row; the summary sentence at line 852 is looser than the table. |
| N-8 | §D's domain-separation argument #2 (lines 808–811) says the slot index is absorbed "before the slot's mask challenge" — true for `c_s` — but `define(s)` draws `τ`, the `μ` and `ν` vectors and the published point vectors **before** `pa-slot` is absorbed (`argument.rs:770` then `:254`). Those challenges are separated by transcript position, not by the slot tag. |
| N-9 | In Tier 1 `A_YM` (`nm`) is proven and then **consumed by nothing**. It is the mirror image of B-1: the grown Tier-1 statement proves a correct second norm that feeds no relation, and a residual-2 addend that no relation produces. Both halves of the gap should be stated together. |
| N-10 | Citation drift, harmless: `layout.rs:265` for `helpers(Dom::D)` is `:266`; `protocol.rs:266` for `Transcript::new(PROFILE)` is the `transcript()` call site, the constructor is `:27`; `private_attention.rs:150-158` for `IoSpec::new` is `:149-159`; `private-block-kernel/src/lib.rs:57-59` for "deliberately not configurable" is `:57-60`. Everything else I opened (about sixty citations across `layout.rs`, `argument.rs`, `protocol.rs`, `private_seam.rs`, `causal_oracle.rs`, `zk.rs`, `layer.rs`, the kernel) is exact. |

## 2. C.1 — `norm_m`, plane for plane against `norm_a`

### 2.1 What `norm_a` actually is, read out of the source

`norm_a` is carried by three slots and one lookup list. I list every part so
the mirror can be checked for omissions rather than admired.

| Part | Source | Detail |
|---|---|---|
| Planes | `layout.rs:90-101` | `A_D` (`Dom::T`), `A_DSQ` (`Dom::T`), `A_LIMB` (`Dom::L`, sixteen 32-entry sub-planes, `N_LIMBS = 9` used: `0..3` = `D`'s byte limbs, `3..6` = `a1`, `6..9` = `a2`, `layout.rs:94, 139`), `A_Y` (`Dom::D`), `A_NR0..3` and `A_NS0..3` (`Dom::D`, the four byte limbs of `ρ` and of `σ`). Input `A_X` (`layout.rs:96`). |
| Claimed sum | `argument.rs:516-521` (`SC_SS`) | tables `eq(r_t, ·)` at start 0 and `A_X`; polynomial `v[0]·v[1]·v[1]`; shape `(9,1,3)`, Private, one `A` site. |
| `T`-domain zero-check + host | `argument.rs:522-540` (`SC_TZC`) | `τ(5)`, `μ(3)`, `ν(1)` nonzero-checked; tables `eq(τ)`, `eq(r_t)`, `A_D`, `A_DSQ`, nine 32-entry `A_LIMB` sub-slices at log 5 → **11 `A` sites**; terms `μ0(Dsq − D·D)`, `μ1(D − dl)`, `μ2(2D − a1 − a2)`; host term `ν·eq(r_t,x)·(Dsq + a1 − Ceps)`; shape `(5,1,3)`, `L = 20`. |
| Limb range | `layout.rs:224` + `argument.rs:541-548` (`SC_LZC`) | one lookup `byte(A_LIMB)`, one helper `H_L` in the **single-lookup** branch `h·d1 − 1` (`argument.rs:465`), degree 2 × `eq(τ)` = 3. |
| Per-element relation | `argument.rs:611-646` (`SC_DZC`), terms `c0`, `c1` at `:632-633` | `c0 = 2·Cn·γ_a(i)·x + 2^tn·D − 2^(tn+1)·y·D − ρ`; `c1 = σ + ρ + 1 − 2^(tn+1)·D`; `D` enters as a log-5 broadcast `a_slice` of `A_D` (`:619`). |
| Range lookups | `layout.rs:226-231` | `byte(A_XL0)`, `byte(A_XL1)`; `sym(A_Y)` (2); four `byte(A_NR0+k)` + `scaled(A_NR0+3, 8)`; four `byte(A_NS0+k)` + `scaled(A_NS0+3, 8)`. |
| Kernel semantics | `private-block-kernel/src/lib.rs:382-411` | `q = num.div_euclid(den)`, `ρ = num.rem_euclid(den)`, `σ = den − 1 − ρ`, refusals `q ∈ [−127,127]`, `ρ < 2^29`, `σ < 2^29`, with `num = 2·x·g·Cn + D·2^tn`, `den = D·2^(tn+1)`. |

### 2.2 The mirror: verdict

**The draft's `norm_m` mirrors `norm_a` plane for plane, term for term, and
lookup for lookup. I found no omitted plane, no duplicated plane and no wrong
term.** Specifically:

- Twelve new planes (`A_DM`, `A_DSQM`, `A_LIMBM`, `A_YM`, `A_MR0..3`,
  `A_MS0..3`), 22 new `A` data rows: correct, and correct per
  `rows_of` (`layout.rs:399-401`, `Dom::T` → 1, `Dom::L` → 2, `Dom::D` → 2).
- Seven free `A_LIMB` sub-planes against nine needed: correct (16 − 9 = 7).
- `Dom::D` 20 → 34 lookups, helpers `⌈34/2⌉ = 17`, "+7 `H` planes", "clean
  because 20 is even": all correct (`layout.rs:197-198`, `:263-272`).
- `Dom::L` 1 → 2 lookups moves `helper_sum` from the single-lookup branch
  (`h·d1 − 1`, degree 2) to the two-lookup branch (`h·d1·d2 − (d1+d2)`, degree
  3) at `argument.rs:460-466`, so `SC_LZC` goes degree 3 → 4 and `L = 10·4 + 2
  = 42`: correct. `mu = [Fp2::ONE]` at `argument.rs:547` still suffices, since
  the helper count stays 1.
- `c6`/`c7` are the exact images of `c0`/`c1` with `γ_m`, `x1`, `Dm`, `nm`,
  `ρm`, `σm`: correct against the kernel at `lib.rs:618` calling `rms_norm`
  with `&x1` and `&w.gamma_m`, shifts `tn = 11`, `Cn = 1024`, `Ceps = 1`,
  `wrho = 29` (`lib.rs:61-64`), rounding = floor-with-`+D·2^tn`-bias, i.e.
  round-half-up: all as the draft states.
- `SC_DZC` stays `(9,1,4)`: correct. `c6`'s highest monomial is `nm·Dm`
  (degree 2) × `eq(τ)` = 3; the two-lookup helper relation is already degree 3
  × `eq(τ)` = 4 and sets the slot degree, unchanged.
- `SC_TZC` stays `(5,1,3)` with `μ(6)`, `ν(2)` and +11 `A` sites: correct.
  New highest monomial `μ3(Dsqm − Dm·Dm)` × `eq(τ)` = 3; new host term
  `ν1·eq(r_t2)·(Dsqm + a1m − Ceps)` = 2.
- `SC_SSM` at `(9,1,3)`, tables `eq(r_t2, ·)` and `A_X1`, polynomial
  `v[0]·v[1]·v[1]`, one `A` site: correct mirror of `SC_SS`.
- `sym(A_YM)` discharges D12 item 4: correct, and the item's premise
  re-checks — the feed-forward helper specs are `g8`/`a16`, `u16`, `h16`,
  `z`/`rd` and nothing else (`zk.rs:2685-2690`, GPU mirror
  `layer.rs:1395-1400`), and `lay.x[c]` appears only in evaluation claims
  (`zk.rs:3350`, `:3360`).

### 2.3 What C.1 gets wrong or leaves out

1. **C-1 (correction):** `A_X1` is opened at **two** points in the grown block,
   not four. See §1.
2. **N-3, N-4 (notes):** the second `Tab::Eq` in `SC_TZC`, the place `r_t2` is
   drawn, `Layout::limb_off`, `N_WITNESS`.
3. **N-9 (note):** in Tier 1, `A_YM` is proven and consumed by nothing. C.1
   says `nm` is "the feed-forward's input" (line 382) without saying that in a
   Tier-1 artifact there is no feed-forward to consume it.
4. **Presentation, not an error:** the `byte(A_LIMBM)` lookup is counted in
   C.1's "Helper planes" bullet and again in C.3's U8 total, but is absent from
   C.1's "Range lookups added" table, which is headed "in the `Dom::D` list" and
   says "Fourteen lookups". Fifteen lookups are added in all; the totals are
   consistent.

## 3. No-wraparound bounds for `norm_m` and residual 2

### 3.1 The premise the draft left open, and why it closes trivially

The draft (line 1226–1229) says `norm_m`'s bounds "must be re-bounded, not
assumed" because `xres1` "can be twice as large as `x_in` at the extremes".
**That is wrong** (finding C-2). R-2's method is explicit
(`ZK60_PRIVATE_ATTENTION_NATIVE_REVIEW_R2.md:33-41`): a no-wraparound bound is
taken over the ranges *the verifier enforces*, for any witness it accepts. The
enforced class of `xres1` is established by the same construct as `x_in`'s:

- `x_in`: `byte(A_XL0)`, `byte(A_XL1)` (`layout.rs:226`) plus
  `c2 = x + 32768 − (XL0 + 256·XL1)` (`argument.rs:634`) ⇒ `x ∈ [−32768, 32767]`.
- `xres1`: `byte(A_X1L0)`, `byte(A_X1L1)` (`layout.rs:232`) plus
  `c4 = x1 + 32768 − (X1L0 + 256·X1L1)` (`argument.rs:636`) ⇒
  `x1 ∈ [−32768, 32767]`.

Same window, same exactness (R-2 §1.1: "int16 = `l0 + 256·l1 − 32768` …
EXACT"). **Confirmed from source, not assumed.** The honest-pipeline
observation that `xres1 = x + ao` is typically larger than `x` is true and
irrelevant: it is not a bound the verifier enforces, and a soundness argument
may not use it.

Consequently every `norm_m` bound equals the corresponding `norm_a` bound.

### 3.2 `norm_m` — each bound with its arithmetic

Enforced inputs: `xres1 ∈ [−32768, 32767]`; `γ_m` any `i8`, so `|γ_m| ≤ 128`
(the kernel accepts `−128`, `private-block-kernel/src/lib.rs:127-129`);
`D_m`, `a1_m`, `a2_m` each three plain byte limbs ⇒ `∈ [0, 2²⁴)`;
`ρ_m`, `σ_m` four byte limbs with `8·l3 ∈ U8` ⇒ `∈ [0, 2²⁹)` exactly;
`nm ∈ [−127, 127]` by `sym(A_YM)`; `Ceps = 1`, `tn = 11`, `Cn = 1024`.

| Expression | Where | Arithmetic | Bound | vs 2⁴⁹ |
|---|---|---|---:|---|
| `ss_m = Ceps + Σ_i xres1²` | the `SC_SSM` claimed sum | `1 + 16·32768²` | **17,179,869,185 < 2³⁵** | OK |
| `D_m` from `ss_m` (honest) | `isqrt(ss_m)` | `⌊√17,179,869,185⌋` | `131,072 = 2¹⁷` (far inside the enforced `2²⁴`) | OK |
| `Dsq_m − D_m·D_m` | `μ3` of `SC_TZC` | `2·(2²⁴−1)²` | **562,949,886,312,450 < 2⁴⁹** (= 562,949,953,421,312) — **the worst expression, identical to `norm_a`'s** | OK |
| `D_m² + a1_m − Ceps − Σ_i xres1²` | the `SC_TZC` host term vs `SC_SSM` | `(2²⁴−1)² + (2²⁴−1) + 1 + 16·32768²` | **281,492,139,802,625 < 2⁴⁹** | OK |
| `D_m − (l0 + 256·l1 + 65536·l2)` | `μ4` | `2·(2²⁴−1)` | 33,554,430 < 2²⁵ (= 33,554,432) | OK |
| `2·D_m − a1_m − a2_m` | `μ5` | `4·(2²⁴−1)` | 67,108,860 < 2²⁶ (= 67,108,864) | OK |
| `c6 = 2·Cn·γ_m·x1 + 2^tn·D_m − 2^(tn+1)·nm·D_m − ρ_m` | `SC_DZC` | `2·1024·128·32768 + 2¹¹·(2²⁴−1) + 2¹²·127·(2²⁴−1) + (2²⁹−1)` | **8,770,859,567,103 < 2⁴³** (= 8,796,093,022,208) | OK |
| `c7 = σ_m + ρ_m + 1 − 2^(tn+1)·D_m` | `SC_DZC` | `2·(2²⁹−1) + 1 + 2¹²·(2²⁴−1)` | 69,793,214,463 < 2³⁷ | OK |

Every figure equals R-2's for `norm_a` (`…REVIEW_R2.md:148-174`). **The
no-wraparound premise extends to `norm_m` unchanged; worst case 5.63·10¹⁴ < 2⁴⁹
≪ 2⁵² ≪ p/2.** The free gift R-2 noted also transfers: `c7` forces
`D_m·2¹² = σ_m + ρ_m + 1 ≤ 2³⁰ − 1`, so `D_m ≤ 262,143 < 2¹⁸`.

### 3.3 Residual 2 — each bound with its arithmetic

Kernel semantics: `SH_X2 = SH_Z2 = 0`, `SH_R2 = 0`
(`private-block-kernel/src/lib.rs:85-87`), and `requant(acc, 0) = acc`
(`lib.rs:298-300`, the `sh <= 0` branch is an exact up-scale by `2⁰`), so
`requant_all(x2, 0, I16)` is "identity, then refuse outside `[−32768, 32767]`"
(`lib.rs:312-322`) — exactly as the draft's C.2 says.

| Expression | Where | Enforcement chain | Bound |
|---|---|---|---:|
| `c8 = x2 + 32768 − (X2L0 + 256·X2L1)` | `SC_DZC`, new term | `byte(A_X2L0)`, `byte(A_X2L1)` ⇒ the limb side is an integer in `[0, 65536)`; the field identity therefore *defines* `x2` as an int16, exactly as `c2` defines `x_in` | `32767 + 32768 + 65535 = 131,070 < 2¹⁷` |
| `c9 = x2 − x1 − z16`, **Tier 1** (`z16` free) | `SC_DZC`, new term | `x2`, `x1` int16 by `c8`, `c4`; `c9 = 0` then *defines* `z16 = x2 − x1`, an integer in `[−65535, 65535]`, i.e. **int17, not int16** | `32768 + 32768 + 65535 = 131,071 < 2¹⁷` |
| `c9`, **Tier 2** (`z16` proven int16 by the FFN down-requant) | same | all three int16 | `3 · 32768 = 98,304 < 2¹⁷` |

Both are in the same class as residual 1's `xres1 − x − ao < 2¹⁷`
(R-2 line 163). **No new wraparound risk from residual 2**, in either tier.

Two things worth saying plainly, because the draft does not:

1. In Tier 1, `c9` is the **only** constraint on `z16`, and it bounds `z16`
   only to `[−65535, 65535]` — *derived from* `x2` and `x1`, not proved of the
   feed-forward's output. This is the arithmetic face of B-1 (§11).
2. The kernel's residual 2 refuses when `x1 + z16` leaves int16
   (`lib.rs:651`, `:653-656`); the proof refuses the same way, through `c8`'s
   two byte limbs. That much of C.2 is exact.

## 4. C.3 — the counts, recomputed independently

### 4.1 The accepted numbers, from the source, by hand

Before anything grows. `rows_of(log) = ⌈2^log / 256⌉` (`layout.rs:399-401`);
domain logs `T 5, Ht 6, L 9, D 9, Q 9, Kv 8, S 11, Tab 8` (`layout.rs:76-82`);
plane→domain from `a_dom` (`layout.rs:141-152`) and `h_dom` (`:167-176`).

```
A data rows  A_D,A_DSQ (T)        2x1 =  2
             A_MX,A_SUM (Ht)      2x1 =  2  ->   4
             A_LIMB (L)           1x2 =  2  ->   6
             A_X..A_X1L1 (D)     19x2 = 38  ->  44
             A_Q8..A_RO1 (Q)      7x2 = 14  ->  58
             A_K8..A_RKRL (Kv)    6x1 =  6  ->  64
             A_S8..A_SG1 (S)     11x8 = 88  -> 152
             A_MU8,A_MEXP (Tab)   2x1 =  2  -> 154     = layout.rs:527
H data rows  H_L (L)            2x(2x2) =   4
             H_D0..+9 (D)      10x(2x2) =  40  ->  44
             H_Q0..+6 (Q)       7x(2x2) =  28  ->  72
             H_KV0..+5 (Kv)     6x(1x2) =  12  ->  84
             H_S0..H_SEXP (S)   8x(8x2) = 128  -> 212
             H_GU8,H_GEXP,H_U   3x(1x2) =   6  -> 218  = layout.rs:528
A sites  sum(A_SITES) = 1+11+1+2+1+1+1+2+2+1+20+8+7+13+2+0+1+1 = 75
H sites  sum(H_SITES) = 1+10+7+6+8+2+1                          = 35
A rows   154 + 2*75 + 2 = 306      H rows  218 + 2*35 + 2 = 290
M rows   2*18 + 4 = 40             functionals  18 + 5 + 5 = 28
L_s      (main+ext)*degree + 2; largest SC_SZC (11,1,4) -> 12*4+2 = 50
U8       1*512 + 20*512 + 13*512 + 12*256 + 13*2048
       =   512 + 10240  +  6656  +  3072  + 26624 = 47,104
rounds   main 129, ext 20 (16 slots x1 + SC_SCORE 2 + SC_PV 2)
sum (main+ext)*(degree+1) over SLOTS = 576 ; terminals 75+35+2 = 112
```

All eight reproduce. The independent tool run reproduces the same set
(§0). **The accepted counts are confirmed; the method is sound.**

### 4.2 The grown Tier-1 counts

Grown declaration used (mine, matching the draft's §D slot order): 19 slots
with `SC_SSM` at index 1 and `SC_LZC` at degree 4; `A_SITES = [1, 1, 22, 2, 2,
1, 1, 1, 2, 2, 1, 34, 8, 7, 13, 2, 0, 1, 1]`, `H_SITES = [0, 0, 0, 1, 0, 0, 0,
0, 0, 0, 0, 17, 7, 6, 8, 2, 1, 0, 0]`; 66 `A` planes (32 on `Dom::D`), 42 `H`
planes (17 `Dom::D` helpers); `Dom::L` 2 lookups, `Dom::D` 34.

```
A data  T 4x1 = 4 ; Ht 2x1 = 2 ; L 2x2 = 4 ; D 32x2 = 64 ; Q 14 ; Kv 6 ; S 88 ; Tab 2
      = 4+2+4+64+14+6+88+2 = 184                       (154 + 30)
H data  L 4 ; D 17x4 = 68 ; Q 28 ; Kv 12 ; S 128 ; Tab 6 = 246   (218 + 28)
A sites 1+1+22+2+2+1+1+1+2+2+1+34+8+7+13+2+0+1+1 = 102  (75 + 1 + 11 + 1 + 14)
H sites 1+17+7+6+8+2+1 = 42                             (35 + 7)
A rows  184 + 204 + 2 = 390        H rows  246 + 84 + 2 = 332
M rows  2*19 + 4 = 42              functionals 19 + 5 + 5 = 29
U8      2*512 + 34*512 + 13*512 + 12*256 + 13*2048
      = 1024  + 17408  +  6656  +  3072  + 26624 = 54,784
rounds  main 138, ext 21 ; sum (m+e)(d+1) = 576 + 40 (SSM) + 10 (LZC 3->4) = 626
```

### 4.3 The table asked for

| Quantity | Draft value | My value | Agree |
|---|---:|---:|---|
| `A` data rows | 184 | 184 | yes |
| `A` site-pair rows | 204 | 204 | yes |
| **`A` rows** | **390** | **390** | **yes** |
| `H` data rows | 246 | 246 | yes |
| `H` site-pair rows | 84 | 84 | yes |
| **`H` rows** | **332** | **332** | **yes** |
| `A` sites | 102 | 102 | yes |
| `H` sites | 42 | 42 | yes |
| CFS slots | 19 | 19 | yes |
| slot kinds (private / standalone / host) | 9 / 5 / 5 | 9 / 5 / 5 | yes |
| host groups | 5 | 5 | yes |
| **`M` rows** | **42** | **42** | **yes** |
| **`M` functionals** | **29** | **29** | **yes** |
| largest CFS slot `L` | 50 (`SC_SZC`), headroom 206 | 50, headroom 206 | yes |
| `A` opening groups | 31 `[ESTIMATE]` | **31, derived** (§7) | yes — drop the estimate tag |
| `H` opening groups | 8 `[ESTIMATE]` | **8, derived** (§7) | yes — drop the estimate tag |
| U8 lookups | 54,784 | 54,784 | yes |
| exp lookups | 2,048 | 2,048 | yes |
| main + extension rounds | 138 + 21 | 138 + 21 | yes |
| `Σ (main+ext)(degree+1)` | 626 | 626 | yes |
| terminals | 146 | 146 | yes |
| `SC_TZC` `A` sites | 22 | 22 | yes |
| `SC_DZC` `A` sites | 34 | 34 | yes |
| `SC_DZC` `H` sites | 17 | 17 | yes |
| `SC_LZC` `A` sites | 2 | 2 | yes |
| `SC_LZC` shape / `L` | (9,1,4) / 42 | (9,1,4) / 42 | yes |
| `SC_SSM` shape / `L` | (9,1,3) / 32 | (9,1,3) / 32 | yes |
| `SC_TZC` shape / `L` | (5,1,3) / 20 | (5,1,3) / 20 | yes |
| grown host map | `{2:[0,1], 11:[10], 12:[5,9], 13:[6,7], 14:[4,8]}` | same | yes |

**No disagreement.** §C.3 is arithmetically clean; the only changes it needs
are the two `[ESTIMATE]` tags (now derived) and the prose error C-1.

### 4.4 Why the opening-group reasoning holds (the part C.3 hedged)

`A_GROUPS` depends on the PCS key `(point tail, c0, len)`
(`protocol.rs:62-67`). `SC_TZC`'s eleven accepted sites are `A_D` (element
offset 0), `A_DSQ` (256) and the nine `A_LIMB` sub-slices at
`1024 + 32k` — i.e. column windows `c0 ∈ {0, 32, …, 224}` for `k = 0..7` and
`c0 = 0` again for `k = 8` (offset 1280 is row 5, column 0). That gives one
4-member group at `c0 = 0` and seven singletons. The grown mirrors
(`A_DM`, `A_DSQM` at row-aligned log-5 offsets, so `c0 = 0`; `A_LIMBM`'s nine
sub-slices at `c0 = 32k mod 256`) land in exactly the same eight windows with
the same tail, so `SC_TZC` keeps **eight** groups, now `m = 8` at `c0 = 0` and
`m = 2` at each of `c0 = 32…224`. `A_LIMBM` in `SC_LZC` and the thirteen new
full-row `Dom::D` sites in `SC_DZC` share their slots' existing tails. Only
`SC_SSM` draws a fresh challenge vector: **+1 group, 31**. The derived listing
in §7 confirms this member for member. The draft's argument is right and its
caveat ("provided … row-aligned in the same pattern — which `Layout::new` does
automatically") is exactly the right caveat: it is automatic because `a_off` is
row-aligned at `layout.rs:425-426`.

## 5. C.4 — the receipt-byte model

The model does not have to be reverse-derived: it is in the module
(`hashline/src/private_attention/wire.rs:16-36`), which §I admits was not read.

```rust
const CHECKS: usize = 256;  const VEC: usize = 512;  const PATH: usize = 11;
const MASK_VEC: usize = 1024;  const MASK_PATH: usize = 12;
pub(crate) const HEADER: usize = 8 + 32;                              // :17

fn opening_len(groups, rows) = (groups + 1) * VEC * 16
                             + CHECKS * (8 + rows * 8 + 32 + PATH * 32)   // :28-30

encoded_len = HEADER + 3*32
            + sum_s (1 + (main+ext)*(degree+1) + slot_terms(s)) * 16
            + 2*MASK_VEC*16 + CHECKS*(8 + M_ROWS*8 + 32 + MASK_PATH*32)
            + opening_len(A_GROUPS, a_rows) + opening_len(H_GROUPS, h_rows)
            + 2 * opening_len(1, ENDPOINT_ROWS)                            // :32-36
```

- The draft's `opening(...)` and `arguments` formulas are `wire.rs:28-29` and
  `:33` **verbatim** — correct, and now sourced rather than fitted (C-3).
- The draft's `mask_open(...)` is **wrong in form** (C-4): `512·16 + … + 15·32`
  instead of `2·1024·16 + … + 12·32`. Both errors are `M_ROWS`-independent and
  cancel exactly (`24,576 = 256·96`), so the numbers survive.

Grown frame, recomputed from `wire.rs`:

| Part | Accepted | Grown | Arithmetic from `wire.rs` |
|---|---:|---:|---|
| envelope + roots | 136 | 136 | `40 + 3·32` |
| arguments | 11,296 | **12,656** | `16·(19 + 626 + 146)` |
| `M` opening | 223,232 | **227,328** | `32,768 + 256·(8 + 42·8 + 32 + 384)` |
| `A` opening | 980,992 | **1,161,216** | `opening_len(31, 390) = 32·8,192 + 256·3,512` |
| `H` opening | 768,000 | **854,016** | `opening_len(8, 332) = 9·8,192 + 256·3,048` |
| endpoints | 262,144 | 262,144 | `2 · opening_len(1, 7)` |
| **total** | **2,245,800** | **2,517,496** | **+12.098 %** |

**Every grown figure in the draft's table is correct**, and the `[ESTIMATE]`
on the `A` opening can be dropped now that `A_GROUPS = 31` is derived (§7).
Two things to add (N-6): `MAX_WIRE_BYTES = 4 MiB` (`wire.rs:26`) is a hard
refusal at `wire.rs:74` and `:145`; grown Tier 1 sits at 60 % of it and the
§C.5 Tier-2 estimate at ~74 %.

## 6. Decisions 6, 7 and 8 of H.3

All three change the structure the rank and slot checks depend on. I checked
each against the four questions asked, then ran the CFS tool on the result
(§7); the tool agrees with the paper answers in every case.

### 6.1 Decision 6 — `SC_TZC` hosts both sum-of-squares slots (`k = 1 → 2`)

| Question | Answer |
|---|---|
| Host-runs-after-hosted kept? | **Yes.** The invariant is `assert!(s < host, "a host runs after the slots it hosts")` at `layout.rs:540`, inside `declared_counts_are_self_consistent`. With `SC_SS = 0`, `SC_SSM = 1`, `SC_TZC = 2`: `0 < 2` and `1 < 2`. The runtime counterpart also holds: a host's scalar consumes `acc.cs[hs]` and `acc.scalars[hs]` (`argument.rs:272`, `:306`, `:353`), which exist only for slots already run. The CFS tool's own check `host SC_TZC's hosted slots all precede it in transcript order` passes on the grown table. |
| Is `rank = ΣL − (k+1)` the criterion the tools state? | **Yes, exactly.** `scripts/zk60_attention_cfs_slots.py`, `analyze_hosted`: `L_sum = sum(slots[x]["len"] for x in [host, *hosted])`, `expected_dim_S_sum_L_minus_k_plus_1 = L_sum − (k+1)`, `expected_kernel_k_plus_1 = k+1`, and `pass` additionally requires `image_inside_subspace`, `leaked_dim_fp2 == 0`, the relabelling check and the round-0 f-part check. Note `ΣL` **includes the host's own `L`**, which is how the draft's 84 = 20 + 32 + 32 is formed. |
| `L_s + 256 ≤ 512` for every slot? | **Yes.** The budget is `L + MASK_Q ≤ MASK_M` with `MASK_Q = 256`, `MASK_M = 512` (`zk60_attention_cfs_slots.py:85-86`, mirroring `layout.rs:549`), i.e. `L ≤ 256`. Grown maximum is `SC_SZC` at 50; `SC_TZC` stays at 20. Headroom 206. |
| Does `k = 2` have a precedent in the accepted checks? | **Yes — three.** `HOSTS` already contains `(SC_QZC, [SC_QMM, SC_PV])`, `(SC_KVZC, [SC_KMM, SC_VMM])`, `(SC_SZC, [SC_RS, SC_SCORE])` (`layout.rs:375-377`), and the accepted R-1 record passes them at `ΣL/rank/kernel = 70/67/3`, `62/59/3`, `100/97/3`. The generalisation to `k ≥ 1` is the tool's stated subject ("`system_batched_pair` generalised to `k >= 1` hosted private sums"). |

**Verdict: Decision 6 is sound and cheaper than the memo says (N-2).** Measured
on the grown schedule: `SC_TZC` → hosted `[SC_SS, SC_SSM]`, `ΣL = 84`,
`rank = dim S = 81`, `kernel = 3`, `leaked = 0`, **pass**. Exactly the draft's
numbers.

One implementation consequence the draft does not state: `nu` at
`argument.rs:525` becomes `nonzero(tr.challenge_fp2_vec(2))?` and `hosted`
becomes `vec![(SC_SS, nu[0]), (SC_SSM, nu[1])]`, matching the two-host pattern
already at `argument.rs:653`/`:671`.

### 6.2 Decision 7 — a second `Dom::L` plane, `SC_LZC` degree 3 → 4, `L` 32 → 42

| Question | Answer |
|---|---|
| Host invariant | Not applicable: `SC_LZC` is `Standalone` (`layout.rs:352`), hosts nothing and is hosted by nothing. |
| Degree rise correct? | **Yes.** `helper_sum` branches on `lks.get(2k+1)`: `Some` gives `h·d1·d2 − (d1+d2)` (degree 3), `None` gives `h·d1 − 1` (degree 2) (`argument.rs:460-466`). `SC_LZC`'s polynomial is `eq(τ) · helper_sum(...)` (`argument.rs:547`), so 3 → 4. `L = (9+1)·4 + 2 = 42`. `mu = [Fp2::ONE]` still has the right arity because `⌈2/2⌉ = 1` helper. |
| `L_s + 256 ≤ 512`? | **Yes**, 42 + 256 = 298 ≤ 512. |
| Precedent for the two-lookup branch at degree 4 | **Yes**: `SC_DZC`, `SC_QZC`, `SC_KVZC`, `SC_SZC` are all `(·,·,4)` for exactly this reason (`layout.rs:330-333`). The extension-round premise ("a public factor in every monomial", `argument.rs:18-22`) is untouched: `eq(τ)` multiplies the whole `helper_sum`. |
| Is `A_LIMB` really full? | **Yes**: `Dom::L` is 512 entries = sixteen 32-entry sub-planes (`layout.rs:60-61`, `:94`), `N_LIMBS = 9` used (`:139`), seven free, nine needed. |

**Verdict: Decision 7 is sound.** Measured: `SC_LZC` standalone
`rank = dim S = 41 = N·d + 1 = 10·4 + 1`, `kernel = 1`, `leaked = 0`, pass.
Two corrections to its justification: C-7 (the alternative costs ~16.9 kB, it
does not save 10 bytes) and N-5 (widening `Dom::L` to log 10 is a real, roughly
equal-cost option that avoids the degree rise and was dismissed unpriced).

### 6.3 Decision 8 — `SC_SSM` inserted at slot index 1

| Question | Answer |
|---|---|
| Host invariant | **Kept**, by construction: index 1 < 2 (`layout.rs:540`). Inserting after `SC_TZC` would break it; inserting at 0 or 1 does not. |
| Rank criterion | Applies to its host, covered in 6.1. `SC_SSM` standalone: `rank = dim S = 10·3 + 1 = 31`, `kernel = 1`, `leaked = 0`, pass. |
| `L_s + 256 ≤ 512`? | **Yes**, `L = 32`, 288 ≤ 512. |
| Knock-on effects the draft does not name | Renumbering shifts every `SC_*` constant from index 1 up, hence `A_SITES`, `H_SITES`, `SLOT_NAMES`, `SLOTS`, `SLOT_KINDS`, `HOSTS`, the `hosts_by_index` map and the inventory tool's `NOTE_EXPECT`. The draft's §G.1 already gives the corrected host map, which I confirm. `mask_specs()` (`layout.rs:395-397`) and `slot_terms` (`:391-393`) follow automatically; `slot >= SC_IO_IN` in `slot_terms` stays correct because both IO slots move together. |

**Verdict: Decision 8 is sound**, and the grown transcript order in §D
(`00 SS_a, 01 SS_m, 02 T-zc, 03 limb-zc, 04 row-sums, …, 18 IO-out`) is
consistent with it. All nineteen slots pass the standalone criterion and all
five host groups pass the batched criterion on the grown description (§7).

## 7. The tools on paper

### 7.1 Can they run on a description? Yes — with one qualification

- `scripts/zk60_attention_pair_schedule.py` takes `--inventory <json>` and
  reads a *description* (claims with commitment, symbolic point, group key,
  mask rows, data rows, role). It hard-codes no input path.
- `scripts/zk60_attention_cfs_slots.py` likewise takes `--inventory <json>`
  plus `--hosts`, and reads `A2_cfs_slots.P1` and the host map.
- `scripts/zk60_attention_native_inventory.py` is the **only** one that needs
  Rust: it parses `layout.rs`, `argument.rs::define` and
  `protocol.rs::logup_sum_claim` into that JSON, then imports the other two by
  path and rebinds their module-level constants.

**Qualification:** neither tool can be run by its own `main()` on a new
layout. The rank tool's `main`/`load_inventory` asserts the legacy claim count
`EXPECTED_CLAIMS = {block: 133, receipt: 135}`, and the CFS tool's
`build_report`/`main` index hard-coded split names `SC_ATTN_08Q/K/V`. That is
why the committed driver rebinds constants instead (its `ADAPTATIONS` R-1…R-9
and C-1…C-4). A new layout needs the same treatment.

### 7.2 What I ran

**No existing script was modified.** Two steps:

1. **The accepted layout, unmodified tool.**
   `python3 scripts/zk60_attention_native_inventory.py --repo <worktree>
   --out-dir results/zk60_private_block_construction/accepted_rerun`
   → `accepted_rerun.log`, `accepted_rerun.done` (exit 0), and the five JSON
   records. Every accepted verdict reproduces (§0). This is the control.

2. **The grown Tier-1 description.**
   `results/zk60_private_block_construction/grow_and_run.py` — a new driver,
   ~330 lines, that (a) imports `zk60_attention_native_inventory.py` by file
   path with the same `load_tool` mechanism that script uses on the other two;
   (b) parses the real `layout.rs`/`argument.rs`/`protocol.rs` into the
   accepted `Layout` and site list; (c) **re-emits the accepted inventory and
   asserts its claim list is identical to the record of step 1** — this
   self-check passes (`self_check_accepted_claims_identical: true`), which is
   what licenses the transformation; (d) patches a copy of that `Layout` into
   the grown Tier-1 layout and transforms the accepted site list into the grown
   one (every carried-over site keeps its symbolic coordinates verbatim; only
   plane indices and element offsets are re-based, and the new sites mirror
   accepted ones); (e) calls the inventory module's own `build_inventory`,
   `run_rank_tool` and `run_cfs_tool` unchanged.

   *What changed relative to the committed driver:* nothing inside it. The new
   file supplies a different `Layout` object and a different site list to the
   same functions, and does not call `cross_checks` (whose `NOTE_EXPECT` pins
   the accepted numbers) — my own expectations are in §4.3 instead. The grown
   layout's `A_GROUPS`/`H_GROUPS` are set from the derivation, exactly as the
   tool does for the accepted one.

Outputs, all under `results/zk60_private_block_construction/`:
`zk60_private_block_grown_inventory.json`, `…_hosts.json`,
`…_pair_schedule.json`, `…_schedule.json`, `…_cfs_slots.json`,
`…_summary.json`; plus `grow_and_run.py` and the `accepted_rerun/` control.

### 7.3 Disclosed dimension per group and per commitment

`failures: []` on both tools. Every number below is `disclosed_dim` under the
rank model at seed 2026, `n_values = 4` (and 8 for the H-with-values pair).

| Verdict | Grown result | Draft §G.2 expectation | Agree |
|---|---:|---|---|
| `whole_A_per_column` | **0** | 0 | yes |
| `whole_A_with_values_n4` | **0** | 0 | yes |
| `whole_H_per_column` | **0** | 0 | yes |
| `group_A_g0 … g30` (all **31**) | **0 each** | 0 each, "~31 groups" | yes |
| `group_H_h0 … h5` (all **6**) | **0 each** | 0 each, six modelled | yes |
| `endpoint_In_with_values_n4`, `endpoint_Out_with_values_n4` | **0**, **0** | 0 | yes |
| `whole_H_with_values_n4`, `…_n8` | **2**, **2**, `residual_is_exactly_the_public_identity = true` | exactly 2, identity true | yes |
| FA2 14.3 `rank_mask = 2m + 2n − 2 + 2n` on all-pair groups | holds for **all 31** A groups | must hold | yes |
| coverage | 144 claims, each covered exactly once; A mask rows 206 after 184 data; H mask rows 88 after 244 data | — | — |
| derived group counts | **A 31, H 8** (`H` = 7 evaluation + 1 sum; the tool models 6, dropping the `SC_ZS` site it builds itself) | 31 / 8 `[ESTIMATE]`, "tool sees one fewer" | yes — estimate now derived |
| singleton groups | A **14** (was 22), H 2 | not predicted | see C-5 |

### 7.4 Rank criterion per host group; slot-length criterion per slot (CFS)

`all_checks_pass: true`.

| Host | Hosted | `ΣL` | rank | dim S | kernel | leaked | pass | Draft |
|---|---|---:|---:|---:|---:|---:|---|---|
| `SC_TZC` | `SC_SS`, `SC_SSM` | **84** | **81** | 81 | **3** | 0 | yes | 84 / 81 / 3 — agrees |
| `SC_DZC` | `SC_WO` | 54 | 52 | 52 | 2 | 0 | yes | agrees |
| `SC_QZC` | `SC_QMM`, `SC_PV` | 70 | 67 | 67 | 3 | 0 | yes | agrees |
| `SC_KVZC` | `SC_KMM`, `SC_VMM` | 62 | 59 | 59 | 3 | 0 | yes | agrees |
| `SC_SZC` | `SC_RS`, `SC_SCORE` | 100 | 97 | 97 | 3 | 0 | yes | agrees |

Standalone (FA6, `rank = dim S = N·d + 1`, image in `S`, `leaked = 0`,
`kernel = 1`) passes on **all nineteen**: `SC_SS` 31, **`SC_SSM` 31**,
`SC_TZC` 19, **`SC_LZC` 41**, `SC_RS` 37, `SC_QMM`/`KMM`/`VMM` 11,
`SC_SCORE` 11, `SC_PV` 15, `SC_WO` 11, `SC_DZC` 41, `SC_QZC` 41,
`SC_KVZC` 37, `SC_SZC` 49, `SC_TAB` 28, `SC_ZS` 19, `SC_IO_IN` 21,
`SC_IO_OUT` 21 — **every one of the draft's §G.3 numbers, including the two it
said would change.** Row budget: largest `SC_SZC`, `L = 50`, headroom 206,
every slot fits. `M` layout: **42 rows = 2·19 + 4, 29 functionals**, one `eval`
per slot, one batched `Γ` per host, five standalone `Γ`, every private slot in
exactly one batched `Γ`, **no standalone `Σ` for any private or host slot**.

### 7.5 Which negative controls fire

All seven CFS controls fire: `nc_hosted_c_zero`, `nc_host_nu_zero`,
`nc_extension_degree_exceeds_mask`, `nc_qkv_unsplit`, `nc_row_budget_exceeded`,
`nc_sigma_functional_for_private_slot`, `nc_sigma_functional_for_host_slot`.
(The `Σ` controls run on the table as a whole, so `SC_SSM` is covered as a
private slot; the draft's §G.3 request to run it "against `SC_SSM` as well" is
satisfied structurally, not by a second named case.)

Rank controls, accepted → grown:

| Control | Accepted | Grown | Draft said | Verdict |
|---|---:|---:|---|---|
| `no_mask_A_per_column` | 37 | **43** | grows | PASS |
| `no_mask_A_with_values_n4` | 208 | **256** | grows | PASS |
| `single_base_row_per_claim_A_per_column` | 15 | **13** | "grows"; "smaller is a stop" | PASS — **the draft's rubric is wrong (C-5)** |
| `single_prox_row_singleton_pair_claim_per_column` | 1 | **1** | 1 | PASS |
| `prox_pair_singleton_pair_claim_per_column` (positive) | 0 | **0** | 0 | PASS |
| `helper_sums_published_n4` | 70 | **84** | ~82 `[ESTIMATE]` | PASS — **off by 2 (C-6)**; the rule is `2 × H sites` |
| `zero_sum_row_without_fresh_pair_n4` | 8 | **8** | ≥ 8 | PASS |
| `flipped_rope_SC_QZC_sharing_pair…` | 2 | **2** | 2 | PASS |
| `flipped_rope_SC_KVZC_sharing_pair…` | 2 | **2** | 2 | PASS |
| `flipped_rope_…_own_pair…` (positive) | 0 | **0**, **0** | 0 | PASS |

The draft's own suggested new control (§G.2 line 1085–1089: give `A_YM`'s
`SC_DZC` site the same reserved pair as `A_Y`'s and require the disclosed
dimension to rise) was **not implemented** — it needs a `share_mask` pair the
existing driver only wires for the RoPE case. I endorse it: the two existing
`flipped_rope_*_sharing_pair` controls (which measure 2) show the mechanism is
detectable, so the expected grown value is ≥ 2.

### 7.6 The caveat, stated where it belongs

Everything in §7.3–§7.5 is a verdict on a **paper schedule description** that
no Rust implements. It is evidence that the grown *declaration* satisfies the
two models' criteria — nothing more. The models' exclusions are unchanged:
sampled columns, salted Merkle paths, the CFS channel, transcript conditioning,
integer-range side information and `A ↔ H` correlation are outside them
(`ZK60_PRIVATE_ATTENTION_NATIVE.md:79`,
`…_DISPOSITION.md:35`). When the layout is written in Rust, the committed
inventory tool must re-derive all of this from the source, and its `NOTE_EXPECT`
must be updated to the §4.3 column — that is Decision 12, and it stands.

## 8. D — the joint transcript order, label by label

### 8.1 What `protocol.rs` absorbs today, in order

| # | Call | Source |
|---|---|---|
| 1 | `Transcript::new(PROFILE)` — `b"hashline-zk-mr1/private-attention-t32-poc/1"` | `protocol.rs:27`, `private_attention.rs:59` |
| 2 | `absorb b"expected-IO"` ← `ExpectedIo::to_bytes()` = `b"HATTEXP1"` ‖ context ‖ `input_scale` (LE i32) ‖ `output_scale` ‖ input root ‖ output root | `protocol.rs:28`, `private_attention.rs:180-190` |
| 3 | `absorb b"public-statement"` ← `AttentionPublic::digest()` | `protocol.rs:29` |
| 4 | `absorb b"parameters"` ← `b"T32/d16/H2/KV1/dh8/log_cols8/inv_rate8/Q256/P1/two-private-endpoints"` | `protocol.rs:30` |
| 5 | `absorb b"schedule"` ← `Layout::schedule_digest()` | `protocol.rs:31` |
| 6 | `absorb b"A"` ← `a_root`; `absorb_u64 b"rows"` ← 306; `absorb_u64 b"log-cols"` ← 8 | `protocol.rs:300` via `:35-39` |
| 7 | `absorb b"M"` ← `mask_root` (**no** `rows`, **no** `log-cols`) | `protocol.rs:306` |
| 8 | `challenge β`, `challenge γ`, `challenge α`, in that order | `protocol.rs:310-312` |
| 9 | `absorb b"H"` ← `h_root`; `b"rows"` ← 290; `b"log-cols"` ← 8 | `protocol.rs:350` |
| 10 | per slot `s = 0..18`: `define(s)` draws τ / μ / ν / point vectors **first** (`argument.rs:770`), then `absorb_u64 b"pa-slot"` ← `s`, `challenge c` (refuse zero), `absorb_fp2 b"pa-scalar"` ← the one scalar, masked rounds (`b"sc-round"` messages, `zk.rs:994`), `ext` extension rounds, refuse degenerate `e`, `absorb_fp2 b"pa-term"` ← terminals in table order | `argument.rs:254-258, 274, 276-293, 305-307, 331-334`, `:769-771` |
| 11 | `zk::mask_open` — absorbs `b"mask-q"`, `b"mask-prox"` | `protocol.rs:365`, `zk.rs:533, 542` |
| 12 | `check_opening(A)` (replay from a clone) then `pcs::open_zk(A)`, drop `A` | `protocol.rs:369-371`, replay at `:168-169` |
| 13 | same for `H` (its claim list ends with the value-0 sum claim) | `protocol.rs:372-374` |
| 14 | `check_endpoint_opening(In)` then `open_zk(In)`, drop | `protocol.rs:375-377`, replay at `:196-197` |
| 15 | same for `Out` | `protocol.rs:378-380` |

Verifier mirror: `protocol.rs:407-429`, same sequence.

### 8.2 The draft's §D against that

**No label is reordered, dropped or invented without saying so.** Item by item:

- Steps 1–4 and 6–10 of the draft match 1–4 and 6–10 above exactly, including
  the two details that are easy to get wrong: `"M"` carries **no** `rows`
  (draft step 8), and `define`'s challenges are drawn **before** the slot index
  is absorbed (draft step 11(a) then 11(b)).
- Step 5, `"calibration"`, is declared NEW and is placed before `"schedule"`
  and therefore before every challenge — **it binds**. No lateness.
- Steps 12–16 match 11–15 above, in the fixed order `M, A, H, In, Out`, each
  owner dropped after its single opening.
- Endpoint roots are inside `ExpectedIo`, absorbed at step 2, before any
  challenge — **they bind**.
- `pb-slot` / `pb-scalar` / `pb-term` are declared renames; the payload changes
  at steps 2, 3, 4 and 6 are declared. `"HBLKEXP1"` is a new magic beside the
  real `"HATTEXP1"` (`private_attention.rs:181`).
- No challenge is drawn before what it must depend on: `β, γ, α` follow both
  the `A` and `M` roots (the LogUp multiplicities are committed in `A` first,
  `protocol.rs:275-291`, the premise R-2 checked); the `H` root follows them;
  each slot's `c_s` follows the slot index; the opening challenges are replayed
  from a clone of the post-slot transcript.

Two problems, both about justification rather than content:

1. **C-10:** the claimed granularity ("what the transcript-order gate compares")
   is wrong. `acc.order` holds three strings per slot and nothing else
   (`argument.rs:255, 328, 335`); it covers none of steps 1–9 or 11–15. The
   §D list is *finer* than the gate, which is good, but the gate cannot police
   it. If §D's order is to be enforced, `acc.order` has to grow — which would
   be a worthwhile, cheap addition to Decision 5.
2. **C-11:** the per-slot rename is not cosmetic; the labels are in shared
   code.

Two further notes:

- **N-8:** domain-separation argument #2 over-claims. The slot index separates
  `c_s`, not the `define`-time challenges.
- The draft's §D omits `b"sc-round"`, `b"mask-q"` and `b"mask-prox"` from the
  list. That is a summarisation, not an error, but if §D is meant to be the
  document an implementer diffs a captured transcript against, those three
  should be in it.

**One substantive observation, which feeds §11.** Step 3 has
`BlockPublic::digest()` absorb `Wg, Wu, Wd` and the activation table (draft
lines 721–722). In a Tier-1 artifact those weights are in the *statement* and
in *no relation*. The transcript would therefore assert a feed-forward the
proof does not constrain. That is the clearest single symptom of B-1.

## 9. E — the reserved-pair lifecycle

**The draft's central claim in §E is TRUE.** `audit_claims`
(`protocol.rs:84-128`) does refuse both an unconsumed and a doubly consumed
reserved pair, and it runs on **both** sides. Verified line by line:

- `let mut uses = vec![0usize; rows]` (`:89`); `is_site` is a binary search in
  `site_rows` (`:90`).
- For every claim, every part's row range is taken (`:93-94`); a part that
  reaches `prox` or beyond is refused (`:95-97`); a zero coefficient on a site
  row is refused (`:99-101`).
- A non-sum claim must touch **exactly two adjacent rows, aligned to the pair
  grid**: `touched.len() != 2 || touched[1] != touched[0] + 1 ||
  (touched[0] - site_rows[0]) % 2 != 0` → `"a claim does not carry exactly its
  own reserved pair"` (`:113-117`).
- The sum claim must be last, pairless, and cover both `u` rows (`:106-112`).
- Finally `if site_rows.iter().any(|r| uses[*r] != 1)` → `"a reserved pair is
  unused or shared between claims"` (`:124-126`). `!= 1` catches **0**
  (never consumed) and **≥ 2** (consumed twice).

It is reached through `check_opening` (`:150-170`, which calls `audit_claims`
at `:151`), called by the **prover** at `:369` (A) and `:372` (H) and by the
**verifier** at `:422` (A) and `:424` (H). So the draft's correction to G8 is
right: consumed-exactly-once is already a hard refusal on both sides for the
150 `A` and 70 `H` site-pair rows, and what is missing is only that the check
is positional, not named.

Scope, stated more tightly than the draft's summary sentence (N-7):

| Region | Covered by | Not covered |
|---|---|---|
| `A` site pairs (`a_mask_base..a_prox`, 150 rows accepted / 204 grown) | `uses[r] == 1` | — |
| `H` site pairs (`h_mask_base..h_prox`, 70 / 84) | `uses[r] == 1` | — |
| `A`/`H` proximity pairs | "a claim reaches the proximity pair" (`:95-97`) + the determinant test in `check_opening_challenges` (`:143-145`) | — |
| zero-sum pair `u` (H data rows 216–217, `layout.rs:473-476`) | the sum-claim branch requires it *covered* (`:108-111`) | nothing forbids a **third** claim also reading those rows; the design relies on `SC_ZS` being the only other reader (`argument.rs:751`) |
| the two 7-row endpoint commitments | `check_endpoint_opening` (`:186-198`): exactly one claim, exactly three parts at rows `(0..2)`, `(2..3)`, `(3..4)`, all coefficients nonzero, plus the `(4,5)` independence replay | `audit_claims` is **not** run on them |

The rest of §E checks out: the two cuts are `commit_zk_owned`
(`protocol.rs:296`, moves `a_data`) and `mask_commit` (`:304`, consumes the
fixed-length `mask_specs()`); `PreparedPlane` has no `Clone` and no data getter
and `into_ffn_endpoint` consumes `self` (`private_seam.rs:143-161`); the
functional-count gate is `argument.rs:775-777`; the role counts for the grown
layout (102 `ASite`, 42 `HSite`, 19 `CfsSlot`) match §4.3. The one real hole
§E names — a slot contributing two `eval` functionals, or a standalone `Γ`
*and* an appearance in a host's batched `Γ` — is indeed only caught by arity
(`acc.fs.len() != N_FUNCTIONALS`), not by assignment. I confirm that: nothing
in `run_slot` (`argument.rs:348-360`) checks *which* slot a functional names.

## 10. F — endpoint scale binding and the slot-tag namespace

### 10.1 F.1 — every factual claim re-checks

- `SeamSpec` folds `scale` into its digest together with the context, shape,
  the two slot ids and the PCS constants: `private_seam.rs:115-133`
  (`DOMAIN`, `context`, `rows`, `cols`, `left_slot`, `right_slot`, `LOG_COLS`,
  `INV_RATE`, `CHECKS`, `MASK_ROWS`, then `scale`). Checked on consumption at
  `:156-161`. Travels in `ExpectedIo::to_bytes` (`private_attention.rs:181-190`)
  and is absorbed as `"expected-IO"` before any challenge (`protocol.rs:28`).
  **Transcript-bound: true.**
- Nothing compares the tag to anything: `IoSpec::new`
  (`private_attention.rs:150-153`) only calls `seams()`, whose only validation
  is `SeamSpec::new`'s context-nonzero / slots-distinct / power-of-two shape /
  `−31..=31` scale (`private_seam.rs:62-85`). **True.**
- The fixtures declare `(-3, -3)`: `hashline/tests/zk60_private_attention.rs:17`
  and `hashline/examples/zk60_private_attention.rs:36`. **True.**
- The calibration has `e_r = 0` for `x_in` (`causal_oracle.rs:116`),
  `e_r1 = 0` for `xres1` (`:118`), and — for the block's real output —
  `e_r2 = 0` (`:146`). **True.** Worth adding: `(-3, -3)` is not arbitrary, it
  is `e_xn` (`:117`) and `e_xm` (`:120`), the two **norm outputs** — i.e. the
  fixtures tagged the endpoints with the wrong pair of exponents from the same
  calibration, a factor of 2³ on each endpoint.
- No accessor for the scales on `IoSpec` (private fields, no getter,
  `private_attention.rs:143-159`), so the draft's second and third assertion
  lines do need one. **True.**
- `calibration_identity` exists at `causal_oracle.rs:194`. **True.**
- The three proposed actions (pin the constructor to `(0, 0)`, absorb the
  calibration digest, compare represented values not tags) are coherent and,
  under form (S), item 3 is indeed vacuous because `nm` and `z16` are single
  planes.

One caution on the proposed test: `assert!(IoSpec::new(ctx, -3, -3).is_err())`
cannot be added to the shared `IoSpec` without breaking the accepted attention
fixtures at the two lines above. The block needs its own constructor (or an
`IoSpec::for_block`), which is what "for this profile" must mean concretely.

### 10.2 F.2 — the slot tags, grepped repo-wide

Every `SeamSpec::new` call in the repository:

| Slots | Where | Status |
|---|---|---|
| 1 / 2, 3 / 4 | `hashline/src/zk_ffn_fresh_io.rs:40-41` | allocated, in use |
| 1 / 2 | `hashline/tests/zk60_private_seam.rs:193, 202-205` | negative fixtures |
| **10 / 11** | `hashline/examples/zk60_seam_receipt.rs:26`; `hashline/tests/zk60_private_seam.rs:8, 90-93, 219` | **in use — missing from the draft's table (C-8)** |
| 21 / 22, 23 / 24 | `hashline/src/private_attention.rs:157` | allocated, in use |

**41 / 42, 43 / 44, 45–48 and 61 / 62 are free.** No other definition of a seam
slot id exists (`SeamSpec` lives only in `hashline/src/private_seam.rs`).

**Is the `(-3,-3)` error today the only separator?** Between a *block* endpoint
and an *attention* endpoint **over the same context and the same `(T, D) =
(32, 16)` shape**, with slots reused: yes. The digest fields are
`DOMAIN ‖ context ‖ rows ‖ cols ‖ left_slot ‖ right_slot ‖ LOG_COLS ‖ INV_RATE
‖ CHECKS ‖ MASK_ROWS ‖ scale` (`private_seam.rs:115-133`); with everything but
`scale` equal, only `scale` separates them, and `into_ffn_endpoint`
(`:156-161`) compares nothing else but the digest and the side. **The draft's
claim is TRUE**, and its conclusion — allocate a fresh pair — follows.

Two qualifications the draft should carry:

- The `context` is caller-supplied and is documented as authenticating "the
  model/calibration and request" (`private_seam.rs:38-42`). A caller who
  varies the context per statement already separates them. The draft's claim
  is conditional on a shared context, which it does say ("over the same
  context", line 995) — worth keeping that clause prominent.
- Separation of *endpoint owners* is what is at stake, not of *receipts*: a
  block receipt could never be accepted by the attention verifier anyway,
  because the profile string (`Transcript::new(PROFILE)`) and the `ExpectedIo`
  magic differ. The hazard is that an owner prepared for one profile is
  presentable to the other prover.

**Finding C-9** applies to the second half of Decision 10: the LogUp table tag
namespace *is* enumerated, in `hashline/src/tables_attn.rs:28-30, 45-80`. A
block activation table should take a free value in that table (134 is free
among the attention-side tags ≥ 128; the FFN's own `TAG_ACT16 = 3`,
`zkp-core/src/ffn_v3/statement.rs:34`, is already disjoint from `TAG_U8 = 133`
and `TAG_EXP = 129` and could simply be reused). The mechanism the draft
describes — a public tag folded into the LogUp denominator, `g_t = γ·TAG`
(`protocol.rs:313-314`) — is correct.

## 11. The Tier-1 `A_Z16` soundness gap, and the tripwire test

### 11.1 CONFIRMED, and stronger than stated

The security owner's reading is right. In the draft's Tier-1 layout:

- `A_Z16` is a plane the prover fills. It takes **no range lookup** — the
  draft's own lookup list (lines 380–388) adds `sym(A_YM)`, the eight `ρm`/`σm`
  byte limbs, the two scaled tops and `byte(A_X2L0)`, `byte(A_X2L1)`, and
  nothing for `A_Z16`. §C.2 says so explicitly at line 501–506.
- It appears in exactly **one** relation, `c9 = x2 − x1 − z16` (line 408), a
  degree-1 term of `SC_DZC`.
- Nothing ties it to `A_YM`. The gate/up/down matmuls, the activation lookup
  and the product are all Tier 2 (§C.5, all `[ESTIMATE]`).

Therefore, for the block statement `(x_in hidden in, xres2 hidden out)`:
**given any int16 `xres2` whatever, a satisfying Tier-1 witness exists** — set
`z16 := xres2 − xres1`, `x2 := xres2`, recompute `A_X2L0`/`A_X2L1` from
`x2 + 32768`. `c8` holds, `c9` holds, both byte lookups hold, and every other
plane is untouched. The block's output is not computed; it is chosen. This is
worse than "the FFN's class is not proved": it is that **the block statement is
vacuous on its output**. §3.3 gives the arithmetic (`c9` bounds `z16` only to
`[−65535, 65535]`, and derives it from `x2` and `x1` rather than from anything
upstream). Its mirror image (N-9): `A_YM` is proved and consumed by nothing, so
the second norm is also dead weight in Tier 1.

### 11.2 Does anything in the draft prevent a Tier-1 artifact from carrying the block profile?

**No.** Searched for a guard and found none:

- The profile string `hashline-zk-mr1/private-block-t32-poc/1` is fixed in §D
  (line 700) and Decision 5 (line 1302), with no tier condition.
- `BlockPublic` with `Wg, Wu, Wd, act` is specified in §B.1 (line 141) and its
  digest in §D step 3 (lines 719–722), again with no tier condition.
- `SC_IO_OUT` binding `A_X2` is Tier 1 (§C.2 line 495–499) and Decision 4
  (line 1299) states it unconditionally.
- §C's tier split (lines 303–309) is about *which numbers are derived*, not
  about what may be shipped.
- §C.2 line 505–506 says the `z16` class obligation "moves into Tier 2 … it is
  listed as an open item, not as done" — the closest thing to a warning, and it
  understates the problem by describing it as a missing **range** proof rather
  than a missing **derivation**.
- Decision 12 ("before the component is called a block") is about re-running
  the tools.
- §H.2 item 7 proposes the right *shape* of negative test — present the receipt
  against an output endpoint committing `xres1` instead of `xres2` and require
  the verifier to reject — but that test passes trivially in Tier 1 and does
  not touch this gap.

**Required fix, stated as the draft should state it.** A Tier-1 build must not
be presentable as a block. Concretely: (a) the block profile string,
`BlockPublic` and the `SC_IO_OUT → A_X2` change land **in the same commit as
Tier 2**, not before; (b) until then a Tier-1 build keeps a distinct profile
(e.g. `…/private-attention-normm-t32-poc/1`) whose statement does **not**
include `Wg/Wu/Wd/act` and whose output endpoint keeps `xres1`, so the
statement it makes is the statement it proves; (c) the tripwire test below
ships in the same commit as Tier 2 and is required to pass there.

### 11.3 The tripwire test, precisely

**Name.** `block_output_cannot_be_chosen` (verifier-side; a prover assertion
does not count — `ZK60_PRIVATE_BLOCK.md:242-243`).

**Construction.**

1. Fix a public statement and a private `x_in`. Run the kernel
   (`private-block-kernel::block`) to get the honest trace: `xres1`, `nm`,
   `z16`, `xres2`.
2. Choose a tamper `δ ≠ 0` on the `z16` plane such that `xres1 + z16 + δ` stays
   in `[−32768, 32767]` everywhere (e.g. `δ = +1` at a single `(t, i)` where
   `xres2 < 32767`).
3. Build the witness with `z16' = z16 + δ` and `xres2' = xres2 + δ`, and
   recompute **only** `A_X2L0`, `A_X2L1` from `xres2' + 32768`. Leave every
   other plane — including `A_YM`, `A_DM`, `A_DSQM`, `A_LIMBM`, the `ρm`/`σm`
   limbs and the whole attention half — **untouched and honest**. This is the
   "tamper consistently" the brief asks for: `xres2' = xres1 + z16'` still
   holds and every class proof still passes.
4. Have the endpoint owner commit `xres2'` as the output endpoint (or, in the
   caller-fixed variant, hand the prover an arbitrary int16 `xres2'` and let it
   solve `z16' := xres2' − xres1` — the stronger form, and the one that shows
   the statement is vacuous rather than merely malleable).
5. Prove, then **verify against the honest public statement**.

**Required outcome:** the VERIFIER rejects.

**Expected outcome in a Tier-1-only build:** the verifier **accepts**. Every
zero-check term `c0…c9` is satisfied, every U8 lookup is satisfied, the LogUp
identity is satisfied, both endpoint equalities are satisfied, and the mask
schedule audit is satisfied. **The test must fail in Tier 1 — that is the
point, and that is the gate on calling the artifact a block.**

**What makes it pass in Tier 2:** the down matmul `z = h·Wd` requantized at
`SH_Z = 6` (`private-block-kernel/src/lib.rs:643-645`) becomes a claim on
`A_Z16` hosted by a zero-check, with its remainder limbs and int16 lookups;
`δ` then breaks that host relation at the random point. Tier 2's obligation is
therefore not only "prove `z16 ∈ int16`" (as §C.2 line 501–506 frames it) but
"**derive `z16` from `nm` through the three matmuls, the activation lookup and
the product**". The draft should say the second, because the first is
satisfiable by a range lookup that would leave this gap wide open.

## 12. What was not checked

**Sections.** B (the seam-form recommendation), C.2, C.5 (Tier 2) and the
eleven H.3 decisions other than 6, 7, 8 were outside the brief and are not
checked here, except where §C.2's residual-2 terms enter the C.3 counts (§4)
and the C.1 bounds (§3), and where C.5's Tier-2 obligation bears on §11. H.1
is touched only through finding C-2. §I was read but not audited.

**Not run.** No `cargo`, no build, no `cargo check`, no test, no example, no
proof, no benchmark, no git write. The only Python executed was the three
committed tools (driven as §7.2 describes) and the arithmetic of §3, §4, §5.

**Not derived.** (a) The grown layout's behaviour under the `helper_sums` and
`base1` controls was measured, not predicted from first principles — I report
the measurement and the tool's own derived expectation. (b) The draft's
proposed new control (`A_YM` sharing `A_Y`'s pair) was not implemented. (c) No
Tier-2 number was checked; §C.5 is untouched. (d) The row-alignment argument
of §4.4 was confirmed against the tool's derived grouping, not proved for every
possible plane ordering — a different `A` plane order that broke row alignment
of `A_LIMBM` would change `A_GROUPS`, and the implementer must re-run the
inventory tool rather than trust 31.

**Not verified.** (a) That the extension-round premise survives `SC_DZC`'s μ
vector growing 16 → 27 — I checked the *degree* argument (§2.2), not the full
monomial expansion R-2 did for the accepted layout; the draft flags this too
(§I(f)) and it remains open. (b) That `SC_LZC` at degree 4 satisfies the same
premise by exact expansion (it does by form — `eq(τ)` multiplies every
monomial — but the expansion was not written out). (c) Anything about
`pcs::open_zk` / `verify_zk` / `zk::mask_commit` internals. (d) Any Tier-2
claim. (e) The seam form's 8B arguments in §B.

**Not analysed.** No privacy analysis. No simulator. The §7 verdicts are model
outputs on a paper schedule, under exclusions restated in §7.6; they are not a
privacy property of the construction and not a property of any code. D8, D11
and D9 are untouched and remain open exactly as the draft's §H.1 says.

**Not reopened.** D1, D3, D4, D5, D12 stand as recorded. No ruling is proposed
here; the BLOCKING finding is a defect in the construction memo, not a request
to revisit a decision.
