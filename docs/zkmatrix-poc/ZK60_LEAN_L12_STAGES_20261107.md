# D63 Lean lane L12: the token stages' knowledge-soundness parts (2026-11-07)

Lean lane L12 (Claude), on perf at 18d2e74c. Seven new library files, imported by the library root:
`formal/ZK60Formal/StageExtractCore.lean`, `StageInExtract.lean`, `StageInExtractSlots.lean`, `StageOutCExtract.lean`,
`StageOutCExtractSlots.lean`, `StageOutExtract.lean`, `StageRunExtract.lean`. `Statements.lean`, every existing Lean file and every production source are unchanged; no
Rust was added. Evidence: `results/zk60_lean_l12_20261107/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms at most `propext`, `Classical.choice`, `Quot.sound`), **CODE**
(read off the sources), **ESTIMATE** (arithmetic on the proved bounds, not proved in Lean).

## 1. In plain words, for Victor

**What this lane is.** The proof of a classifier verdict (and of a next token) has three parts around the blocks:
- stage IN-C (IN for the token run) turns the hidden token ids into the first block's input;
- the 26 blocks;
- stage OUT-C (OUT) turns the last block's output into the published verdict (the next token).

Earlier lanes proved the deterministic half for these stages (`classifyRun_circuitIff`, `tokenRun_circuitIff`): IF the
stages' constraints hold, the verdict is the integer model's. This lane proves the other half for the stages: **if
the stage verifier accepts, the constraints hold on the data the prover committed, except with a small stated
probability.** That is the token stages' share of statement 1's "only if" (ASSEMBLY §4.2 item e).

**What is now proved.**
- **Stage IN-C and IN, the embedding lookup** (`in_lookup_sound`). The code checks each position's embedding row in a
  compressed form: one random combination of the whole row, not the row itself. Lean now proves that a prover who
  passes the lookup with a wrong token id, a wrong control bit or ANY wrong entry of a row succeeds with probability at
  most `(T + 4V − 1 + T·log₂ d_pad)/|Fp2|`. At the classifier's shape (`V = 2^15`, `d_pad = 2^12`, `T = 512`) that is
  about `2^-111` [ESTIMATE]. The row-compression step is exactly the `T·log d_pad` term the code's whole-run figure
  already charges.
- **Stage IN-C as ONE theorem** (`inc_stage_sound`). The stage's slots are written exactly as the code writes them
  (the clauses on the committed tables, their pads, their degrees), and the whole stage is composed: the challenges,
  then the helpers the prover commits, then the three slots and the sum claim. For ANY prover, the stage accepts while
  the embedding rows, BOS or the template positions are wrong with probability at most the lookup's term plus the
  three slots' (about `2^-110.9` at the classifier's shape [ESTIMATE]).
- **Stage OUT-C, the margin and the verdict** (`outC_sat_of_clauses`, `byte_logup_sound`, `lzc_host_sum`). The checks
  the classifier's last stage runs (the final norm's isqrt and divisions, the hosted sum of squares, the hosted margin
  `Σ y_i·w_Δ(i)`, the byte lookups of every limb) imply the stage relation `OutCSat` of CircuitOut.lean, with the
  byte lookup's error at most `(N + 511)/|Fp2|` (`N` the looked bytes, about `2^15.7` here) [ESTIMATE: about
  `2^-112`]. The margin sumcheck itself is written as the code writes it (`margin_sound`): the private margin sum
  and its host pass with a wrong margin identity with probability at most `(2·12 + 62)/|Fp2|`, and the identity
  they certify is exactly the one the verdict relation needs (`margin_host_pd`).
- **Stage OUT, the head and the greedy token** (`out_sat_of_clauses`, `head_sz_prob`, `rsel_batch_sound`). The head's
  random-point identity is read as "every logit is right" except with probability `log₂ V_pad/|Fp2|`; the selector's
  three sums except with `1/|Fp2|`.
- **The slots themselves** (`zc_batched_sound`, `zc_pad_sound`, `host_sound`, `host_pad_sound`). Every stage slot is a
  zero-check, a private sum, or a host. Lean proves, for the code's exact forms (fresh batching coefficients, the pad
  fold with its own `ζ`, the host's `ν`), that a false clause or a false hosted sum passes with probability at most
  about `(n·(degree + 1) + a few)/|Fp2|` per slot.
- **The two links between the stages and the blocks** (`classify_run_link`, `token_run_link`). The run opens ONE
  commitment for `B_in` with both stage IN-C's claims and block 0's, so they are about one plane; the same holds for
  `B_out` and stage OUT-C, which reads the verdict row. With the blocks' conclusion as a hypothesis, the stages'
  conclusions assemble into the classifier's whole constraint system on the extractor's input.
- **The endpoints** (`classify_inner_of_stages`, `token_inner_of_stages`). The extractor reads the input ids off the
  input endpoint's extracted words, canonically (`ZMod.val`, so every id is below `p`). Given lane L10's opening
  relation as a hypothesis of a stated shape, the inner predicate of `IOPExtract` holds.

**What this does not do.** It is the interactive (uniform-challenge) form, as the other L3 lemmas are; the
Fiat–Shamir lift is L7/L8's generic composition. The openings (that each terminal value is the committed table's) are
lane L10's. The blocks are lanes L9/L11's. For stage IN-C the stage total is one theorem; for OUT-C, OUT and IN's
endpoint slot it is still the union of the proved per-step terms [ESTIMATE in §3] (§6).

**One finding needs no ruling but is worth knowing (L12-2).** The whole-run figure charges stage IN's lookup more than
the proof needs: the code adds `V·(2 + log d_pad)`, the proof needs `4V − 1`. The figure is conservative, not wrong.

## 2. What is proved

All PROVED (`results/zk60_lean_l12_20261107/`; the counts are in §7).

### 2.1 The generic core (`StageExtractCore.lean`)

| Theorem | Meaning |
|---|---|
| `pr`, `pr_mono`, `pr_or_le`, `pr_exists_le`, `pr_false`, `pr_le_of_not` | the uniform probability of `Statements.lean`, monotone, the union bound |
| `pr_prod_le`, `pr_prod_le_right`, `pr_fst_le`, `pr_snd_le` | a bound on every slice of one coordinate is a bound on the product; an event of one coordinate keeps its probability |
| **`two_phase_sound`** | challenges, then the prover's data (`H`), then the slots: (1) data passing the phase-1 relations while the goal fails is `≤ ε₁`; (2) data failing them passes the slots `≤ ε₂`; then accept-and-fail is `≤ ε₁ + ε₂` for ANY data function |
| `IndDegLE.wsum`, `IndDegLE.mono`, `IndDegLE.add` | the batched clause keeps the individual degree |
| `mleAt_sub`, **`mle_eq_prob`** | two different cube tables have equal multilinear extensions at a uniform point with probability `≤ n/|K|` |
| `zetaFold_prob` | a pad fold `Σ_{i<m} ζ^i·P_i` with some `P_i ≠ 0` vanishes everywhere for at most `m − 1` values of `ζ` |
| `single_root_prob` | `a + ν·δ = 0`, `δ ≠ 0`: one `ν` |
| **`zc_batched_sound`** | a standalone zero-check `eq(τ,·)·Σ_j μ_j W_j` on the claim 0, some clause nonzero on the cube: accepted `≤ (1 + n + n(d+1))/|K|`, any prover |
| **`zc_pad_sound`** | the same with the code's pad clause folded by its own `ζ` (`withPad`, `withPad_none`, `withPad_some`, `withPad_deg`): `≤ ((m − 1) + 1 + n + n(d+1))/|K|` |
| `cubeSum_add`, `cubeSum_smul` | cube sums are linear |
| **`host_sound`** | a host slot on the claim `ν·S` (token_io.rs:1070): a nonzero clause OR a hosted sum `Σ host ≠ S` passes `≤ (2 + n + n(d+1))/|K|` |
| **`host_pad_sound`** | a host slot with a pad clause (TZC, VZC): `≤ ((m − 1) + 2 + n + n(d+1))/|K|` |
| `cube_sum_of_pad` | a cube sum whose terms vanish off the logical positions is the logical sum (how the pads turn the whole-plane LogUp sum claim into the logical one) |

### 2.2 Stage IN and IN-C (`StageInExtract.lean`)

| Theorem | Meaning |
|---|---|
| `InData`, `qTup`, `tTup`, `inA`, `InGood`, `InChal`, `InLogUp` | the data committed before `β, γ, α, r_emb`; the compressed query `(tok, TAG_EMB, x~(t, r_emb), c(t))` and table `(v, TAG_EMB, E~(v, r_emb), ctl(v))` tuples, folded as the code folds them (`tok + γ·TAG + β·x~ + β²·c`, stage_in_c.rs:206; `tau_table`, :160-164); the goal: every position's id, WHOLE padded row and control bit are a table row's |
| `row_sz_prob`, `rows_sz_prob` | the Schwartz–Zippel step over `r_emb`: a row that differs from the table row its id names compresses equal with probability `≤ k/|K|` per position, `≤ T·k/|K|` in all (`d_pad = 2^k`) |
| **`in_lookup_sound`** | over uniform `((β, γ), α)` and `r_emb`: SOME helpers pass every LogUp relation while `InGood` fails with probability `≤ ((T + 4V − 1) + T·k)/|K|` (`logup_block_bound` at every `r_emb`, plus `rows_sz_prob`) |
| **`in_stage_sound`** | both phases: with the slots' bound `ε₂` on helpers failing the relations, accept-and-not-`InGood` `≤ ((T + 4V − 1) + T·k)/|K| + ε₂` |
| `InCube`, **`inCube_helperRel`** | the code's relations on the two lifted cubes (SIC_QZC's LogUp clause on the support and its pad off it, SIC_TZC's table relation and pad, the `H` sum claim, SIC_ZS) are exactly `HelperRel` at the logical positions |
| `inDataOf`, `inDataOf_vid_injective` | the stage's data from the extracted planes and the public tables (`GF`); the table ids `0 … V−1` are distinct words |
| **`in_inSat`** | `InGood` with the BOS and template clauses is `InSat` (CircuitTokenRun.lean), through the column layout map `col` |
| `in_pad_cols` | the lookup also pins the row's pad columns to zero |
| `in_endpoint_words` | SIC_IO's identity (`end − supp·tok`, stage_in_c.rs:174-185): the endpoint's support words are `A_TOK`'s, the others zero |
| `canonWord`, `canonWord_lt`, `canonWord_cast` | the extractor reads each endpoint word canonically: below `p`, and the word again |

Stage IN is the same theorem with `cq = 0`, `ctl = 0` (no control column, no template; stage_in.rs:185-253).

### 2.2b Stage IN-C's slots and the whole stage (`StageInExtractSlots.lean`)

| Theorem | Meaning |
|---|---|
| `IndDegLE.mul`, `IndDegLE.const`, `IndDegLE.sub`, `IndDegLE.cmul`, `mle_deg`, `mleAt_bitv` | the degree of a closure on multilinear tables; on the cube an extension is the table |
| `QzcClause`, `QzcTabs`, `qzcQ`, `qzcW`, `qzcPz`; `TzcTabs`, `tzcW`, `tzcPz` | SIC_QZC's three clauses (`h_q·(α − q) − supp`, `u0·(tok − bos)`, `π·(tok − κ)`, `q = tok + β·B(ρ_t, r_emb) + β²·[ctl_q] + γ·TAG_EMB`) and pad planes `(1 − supp)·tok`, `(1 − supp)·h_q`; SIC_TZC's `h_tab·(α − τ) − m` and pads (stage_in_c.rs:188-230) |
| `qzcQ_deg`, `qzcW_deg`, `pad2_deg`, `qzcPz_deg`, `tzcW_deg`, `tzcPz_deg` | each of individual degree `≤ 3`, the code's declared round degree 4 |
| `QzcHolds`, `TzcHolds`, `qzc_cube`, `tzc_cube` | the clauses vanish on the cube; there they are the tables' own values |
| `ZcChal`, `zcAcc`, **`zc_slot_sound`** | such a slot accepts a violated clause or pad with probability `≤ (1 + (1 + n + 4n))/|K|` |
| **`zs_sound`** | SIC_ZS (`1·u` on the claim 0) accepts a row with `Σu ≠ 0` with probability `≤ 2n/|K|` |
| `IncLayout`, `IncHelpers`, `incQ`, `incT`, `incHelpers`, `IncSum`, `IncBosTmpl`, `incLook_eq` | the public tables and layout map of the two cubes and the facts the code's tables satisfy at the logical positions; the committed helper planes; the `H` sum claim; the BOS and template facts |
| **`incCube`** | the slots' conclusions, the pads and the two sum claims give `InLogUp` (through `inCube_helperRel`), BOS and the template facts |
| `IncChal2`, `IncAcc`, **`inc_stage_sound`** | the whole stage: pre-`H` challenges, then ANY committed helpers, then the three slots' challenges and ANY sumcheck provers; accept-and-(not `InGood`, or a BOS or template fact false) `≤ ((T + 4V − 1) + T·k)/|K| + (1 + (1 + n + 4n))/|K| + (1 + (1 + nv + 4nv))/|K| + 2nu/|K|` |

With `in_inSat`, `InGood` and the BOS and template facts are `InSat`. SIC_IO (the endpoint slot) is not in
`inc_stage_sound`: it is `zc_batched_sound` on its own cube, and its conclusion is `in_endpoint_words`.

### 2.3 Stage OUT-C (`StageOutCExtract.lean`)

| Theorem | Meaning |
|---|---|
| `IsByte`, `byteLook`, `byteTab`, `AllBytes`, `ByteLogUp`, `byteLook_hit` | the byte lookups as the code makes them (singles on LZC's limb plane, DZC's six pair helpers, the shift `g = γ·TAG_U8`, `resolve`, stage_out_c.rs:273-275), the 256-row table `j + g` |
| **`byte_logup_sound`** | over uniform `(γ, α)`: SOME helpers pass the singles', pairs' and table's relations and the sum claim while a looked value is not a byte with probability `≤ (N + 2·256 − 1)/|K|`, `N` the lookups (the family tag is shared, so `γ` only shifts `α`: no fold-collision term) |
| **`byte_stage_sound`** | both phases, as `in_stage_sound` |
| `isByte_inRange` | a table byte of `GF` is `InRange 8` |
| `limbSum`, `l3`, `FNormClauses`, `l3_inRange`, `limbSum_byteLimbs` | the final norm's clauses at the logical positions (TZC's three and its hosted sum of squares, DZC's `c0`, `c1`, `c2`, every limb a byte), shared by OUT and OUT-C |
| **`fnormRel_of_clauses`** | they give `FNormRel` (CircuitOut.lean) |
| `OutCClauses`, **`outC_sat_of_clauses`** | with LZC's hosted margin `σ·δ + (b + c) = Σ_{i<d} y_i·w_Δ(i)` and the margin limbs bytes: `OutCSat` |
| `lzc_host_sum` | LZC's host term summed over the whole limb plane is `σ·δ + (b + c)` (stage_out_c.rs:356-366) |

### 2.3b Stage OUT-C's margin sumcheck as the code writes it (`StageOutCExtractSlots.lean`)

| Theorem | Meaning |
|---|---|
| `LzcClause`, `lzcW`, `lzcHost`, `LzcHolds` | LZC's clauses (the limb plane's single byte-lookup helper `h·(α − (limb + g)) − 1`, the pad `(1 − s)·limb`) and its host term `G·limb + u0·(b + c)` on the tables' extensions (stage_out_c.rs:349-370) |
| `lzcW_deg`, `lzcHost_deg`, `pd_sum`, `lzcHost_sum` | degrees `≤ 3` and `≤ 4` (LZC's declared round degree 4, PD's 2); on the cube the sums are the tables' |
| **`margin_sound`** | over PD's rounds, then LZC's `μ`, `ν`, `τ` and rounds, for ANY published scalar `S` and ANY provers: PD accepts `S`, LZC accepts `ν·S`, and yet the hosted identity `Σ_b y(b)·w(b) = Σ_z (G(z)·limb(z) + u0(z)·(b + c))` or an LZC clause fails, with probability `≤ 2·nd/|K| + (2 + nl + 4·nl)/|K|` |
| **`margin_host_pd`** | with the tables the base field's images through the layout maps, that identity on `K` is `OutCClauses.host_pd` on `GF`: `σ·δ + (b + c) = Σ_i y_i·w_Δ(i)` |

### 2.4 Stage OUT (`StageOutExtract.lean`)

| Theorem | Meaning |
|---|---|
| **`head_sz_prob`**, `head_tables_eq` | the head's Schwartz–Zippel step: `l*` (VZC's keyed values) and `l` (the head values), both functions of `A_out` and so fixed before `r_j`, differ somewhere yet agree at `r_j` with probability `≤ log₂ V_pad/|K|`; equal tables agree at every logical entry |
| `rselRes`, `rsel_cube_sum` | SO_RSEL's polynomial summed over the `Vo` cube is `c₁(Σe − 1) + c₂(Σ e·z − tok) + c₃·Σ e·δ` (stage_out.rs:503-506) |
| **`rsel_batch_sound`**, `rselRes_zero` | a nonzero residue survives the fresh `c` except with probability `1/|K|`; zero residues are the three identities |
| `OutClauses`, **`out_sat_of_clauses`** | the final norm's clauses, VZC's per-entry clauses (`e(1−e) = 0`, the keyed limbs bytes, `l*_z = l_z`) and the three identities give `OutSat` |
| `out_endpoint_word` | SO_IOOUT's identity: the output endpoint's word 0 is the token word, the others zero |

### 2.5 The run's links and the endpoints (`StageRunExtract.lean`)

| Theorem | Meaning |
|---|---|
| `RunOn` | the blocks' conclusion on the extracted boundary planes (a HYPOTHESIS: lanes L9 / L11 and the block's L3) |
| `RunFrame` | one extracted plane per boundary root, and the two root equalities the run's schedule makes (classify_run.rs:300, :333, :379) |
| **`classify_run_link`** | IN-C's `InSat` on `B_in`, `RunOn`, OUT-C's `OutCSat` with OUTC-00's `x_i = B_out(row, i)`, and SIC_IO's endpoint identity give `classifySat` on the canonical endpoint words |
| **`token_run_link`** | the same for the next-token run, with SO_IOOUT's output word |
| **`classify_inner_of_stages`**, **`token_inner_of_stages`** | with L10's openings as hypotheses (§4), the inner predicate of `IOPExtract` (Assembly.lean) for `(x, y, (), r, r')` |

## 3. How the code's checks map onto the theorems, and the stage errors [ESTIMATE]

Each slot's error below is the proved per-slot bound with one more round for the code's extension round
(`sumcheck_sound_extended`: `(n + 1)` rounds of the declared degree; the CFS mask leaves the bound unchanged,
`sumcheck_sound_masked`). Shapes: the R1 tier (`stage_log_n = 12`, CODE token_io.rs:190), the classifier's
`V = 2^15` (Mistral's vocabulary), `d_pad = 2^12`, `T = t_pad = 512`. `|Fp2| = p² ≈ 2^128`. The sum is a union bound
over the stage's steps. For stage IN-C the sum of the lookup, INC-01, INC-02 and INC-03 terms IS a Lean theorem
(`inc_stage_sound`, without the extension round's extra round); INC-00 is its own slot (`zc_batched_sound`). For
OUT-C each step is proved and the sum is arithmetic.

**Stage IN-C** (stage_in_c.rs:42-57; slots `main`, `degree` CODE):

| Step | Theorem | Numerator |
|---|---|---|
| the lookup: LogUp `(T + 4V − 1)` and the row compression `T·log d_pad` | `in_lookup_sound` | `512 + 131,071 + 6,144 = 137,727` |
| INC-00 IO-in (`n = 9` words of `max(t_pad, 256)`, degree 3, no pad) | `zc_batched_sound` | `1 + 9 + 10·3 = 40` |
| INC-01 QZC (`n = 12`, degree 4, pad of 2 planes) | `zc_pad_sound` | `1 + 1 + 12 + 13·4 = 66` |
| INC-02 TZC (`n = 15`, degree 4, pad of 2 planes) | `zc_pad_sound` | `1 + 1 + 15 + 16·4 = 81` |
| INC-03 ZS (`n = 12`, degree 2, the claim `Σu = 0`) | `sumcheck_sound` | `13·2 = 26` |
| total | | `≈ 137,940 ≈ 2^17.07`: about `2^-110.9` |

**Stage OUT-C** (stage_out_c.rs:71-102):

| Step | Theorem | Numerator |
|---|---|---|
| the byte LogUp, `N = |Lo| + 12·|Do| = 4,096 + 49,152` | `byte_logup_sound` | `53,248 + 511 = 53,759` |
| OUTC-00 IO-in (`n = 12`, degree 2) | `zc_batched_sound` | `1 + 12 + 13·2 = 39` |
| OUTC-01 SS, private (`n = 12`, degree 4) | `sumcheck_sound` | `13·4 = 52` |
| OUTC-02 TZC, host of SS (`n = 1`, degree 3, pad of 2 planes) | `host_pad_sound` | `1 + 2 + 1 + 2·3 = 10` |
| OUTC-03 PD, private: the margin (`n = 12`, degree 2) | `sumcheck_sound` (`margin_sound`) | `13·2 = 26` |
| OUTC-04 LZC, host of PD (`n = 12`, degree 4, its pad a plain clause) | `host_sound` (`margin_sound`) | `2 + 12 + 13·4 = 66` |
| OUTC-05 DZC (`n = 12`, degree 5, pad of 12 planes) | `zc_pad_sound` | `11 + 1 + 12 + 13·5 = 89` |
| OUTC-06 TAB (`n = 12`, degree 3, pad of 2 planes) | `zc_pad_sound` | `1 + 1 + 12 + 13·3 = 53` |
| OUTC-07 ZS | `sumcheck_sound` | `26` |
| total | | `≈ 54,120 ≈ 2^15.72`: about `2^-112.3` |

The slot terms (about 200 and 360) are below the whole-run figure's per-stage sumcheck allowance
(`SUMCHECK_PER_STAGE_LOG2 = −117.2`, a numerator of about `2^10.8 ≈ 1,780`, run.rs:109) [ESTIMATE]. At 8B
(`V = 128,256`, `V_pad = 2^17`) stage IN's lookup grows to about `2^19` and stage OUT's VZC slot (`n = 17`, degree 5,
a pad of `1 + limbs` planes, a host) to about `2 + 17 + 18·5 + 7 = 116`.

## 4. The hypothesis shapes lane L10's definitions must meet

The coordinator glues these to L10's `opensIn` / `opensOut` (ColCommit openings of the endpoint commitments):

1. **The extraction map of the boundary commitments** (`RunFrame.ext : Dg → S.Pos → GF`): ONE plane per root, the
   plane every accepted claim on that root is about (the opening extractor's output, `opening_sound_extracted` /
   `fs_opening_knowledge` per root). The two root equalities are the run's framing (CODE).
2. **The input endpoint**: with `epW : S.Tok → GF` the input endpoint's extracted words at the support positions (the
   same extraction, at the endpoint's geometry), the extractor's input is `x t = canonWord (epW t)`
   (`(epW t).val`), and L10 supplies `hopen : P.opensIn H s (fun t => canonWord (epW t)) r` with `r` the extracted
   opening data (salts, paths, mask rows). The decoding side of L10's `col_inj` (the endpoint's words determine `x`)
   is what makes this the input `Binding` speaks of.
3. **The output side**:
   - the classifier: `P.ypub s = b` (the verdict stage OUT-C was run with is the statement's: `st.verdict()`,
     classify_run.rs:382) and `P.opensOut H s () r'` (no output endpoint; `HidOut = Unit`, so L10 may define it as
     `True` or as the trivial `ColCommit`);
   - the token run: `P.opensOut H s (canonWord epO) r'`, `epO` the output token endpoint's extracted word 0.
4. **The blocks** (`RunOn R.Ps (ext rootBlock0In) (ext rootLastOut)`): int16 preimages of the extracted boundary
   planes satisfying `RunSat` — the block lanes' conclusion.

## 5. Findings

**L12-1 (Info): the verifier does not refuse `α` at a table value; the proof counts it.** Stage IN / IN-C's prover
refuses `α = τ(v)` (D66(3), stage_in_c.rs:329-331); the verifier does not. At such an `α` the table relation
`h_tab·0 = m` leaves `h_tab` free when `m = 0` (a "bad pole"). `logup_block_bound`'s `N + 4M − 1` already counts
these poles (`badPoles`), so `in_lookup_sound` needs no verifier check. The same holds for the byte table of OUT/OUT-C.

**L12-2 (Info): the whole-run figure's stage-IN term is larger than the proved bound.** The figure charges
`n_in + V·(2 + lg) + T·lg` (run.rs:224-226, `lg = log d_pad`, `n_in` the lifted position count `≥ T`); the proof needs
`(T + 4V − 1) + T·lg`. For `lg ≥ 2` and `n_in ≥ T` the figure is the larger [ESTIMATE: arithmetic]. Likewise stage
OUT's byte term `n + 3·256 − 1` against the proved `N + 2·256 − 1`: one family tag needs no fold-collision term.
Conservative; no change needed.

**L12-3 (Info): stage OUT-C's header says "u0·(σ b + c)"; the code uses `b + c`.** stage_out_c.rs:11-15 writes the host
constant as `σ b + c` and the identity as `Δ = σ(δ + b) + c`; the code's constant is `k(verdict) + k(c)` (:363). For
`b ∈ {0, 1}`, `σ·b = b`, so the two agree; `VerdictRel` and `outC_sat_of_clauses` use the code's `b + c`. A comment
nit only.

**L12-4 (Info): the masked claims rest on the mask commitment's functionals.** `host_sound` models the host's claim as
`ν·S` with `S` the private slot's UNMASKED sum. In the code the masked scalars cancel only if the `M` opening's
functionals (`host_fs`, the `Γ` values, token_io.rs:1114-1122) hold: that is the `M` opening's soundness, which ASSEMBLY
§4.2 item b already lists as assumed (`≤ 2^-106`). No new assumption; it is named here because every host slot uses it.

**L12-5 (Low): `IOPExtract`'s classifier instance needs `opensOut` for a `Unit` hidden output.** The classifier has no
output endpoint, yet the approved `Protocol` asks for `opensOut H s () r'`. L10 must give it a definition (`True`, or a
trivial commitment); `Binding`'s output half is then vacuous for the classifier. Not a change to the statements.

Optimization candidates (for a later profile; nothing changed here):
- **O1 (stage IN's figure)**: the whole-run figure could charge the proved `T + 4V − 1 + T·lg` instead of
  `n_in + V(2 + lg) + T·lg` (L12-2): at 8B about `V·(lg − 2) ≈ 1.3M` fewer counted units, a fraction of a bit of the
  figure. No protocol change.
- **O2 (the byte LogUp's tag)**: stage OUT/OUT-C's byte LogUp has one family, so the fold `x + γ·TAG_U8` gains nothing
  over `x`; `γ` could be dropped from these stages (one squeeze fewer). Needs a new stage layout (D36 pins stage OUT).

## 6. What is left

- **The stage-level total as ONE Lean theorem for OUT-C and OUT** (done for IN-C: `inc_stage_sound`). Each of their
  steps is proved and the byte LogUp's two phases compose (`byte_stage_sound`); writing DZC, LZC, TZC, VZC, RSEL
  and TAB as the code's closures (as `StageInExtractSlots.lean` does for SIC_QZC / SIC_TZC) and composing them is
  the same pattern, not yet done. Under Fiat–Shamir the composition is L8's (`fs_code_chain_sound_sched`), which
  needs each step's round-by-round form.
- **The layout facts.** `IncLayout`'s fields (where `supp`, `u0`, `π`, `τ` are 1 or the table's value) are the
  code's public tables at the layout map's positions; they are hypotheses here, finite checks for a concrete profile.
- **The pads in the clause hypotheses.** `InCube` and the `*Clauses` structures take the pad facts and the logical
  positions as given; their derivation from `supp`, `live_limb` and the lifted cubes is the layout map's.
- **Deliverable 4 (executable stage arithmetic and a corpus) was not started.** The stage verifiers are crate-private
  (`pub(crate)`), so the export must be a hashline unit-test module; a NEW test file there has to be registered by a
  `#[cfg(test)] #[path = …] mod …;` line in a production source (as `lean_l1_export_tests.rs` is, witness.rs:46),
  and this lane's brief allows new test files only. Either that one-line registration or a new test inside the
  already registered `lean_l1_export_tests.rs` needs the coordinator's word. The first half of the session was also
  lost to the guard (§7).
- Not modelled: DD, the sealed-selector variants, the classifier's chunked items (as before).

## 7. Checks

All in `results/zk60_lean_l12_20261107/`, each run as one job through the zk60 resource guard (class `cpu`,
`run_guarded.py`, detached with `start_new_session`):
- `file1.log` … `file8.log`: the new files while they were written (`stage.sh`: `lake env lean` on the core file, then
  `lake build ZK60Formal.StageRunExtract`, which builds five of them, then the two `*Slots` modules). The errors fixed on the way are in those logs: a
  binder type `∑ i, ζ ^ (i : ℕ)` read as `ℕ`, three deprecations (`finset_sum_coeff`, `if_true`, `if_pos`/`if_neg`), an
  unused hypothesis, a missing `DecidableEq`, and an elaboration timeout from unifying a `HelperRel` lambda (fixed by
  naming the relation, `ByteLogUp`, as `InLogUp` already was); in `file5.log` a `fold` that resolved to `Finset.fold`; in
  `file7.log` a `map_add` that rewrote the wrong sum. `file4.log`, `file6.log`, `file8.log`: rc 0, no message. Each run took 4–25 s at
  under 7 GiB.
- `check_final.log`: `check_l12.sh`, ONE guarded job on the final tree (`check_final.log.guard`: 49 s, peak RSS
  3.62 GiB), reported here. (`check.log` holds the two earlier runs, before `StageInExtractSlots.lean`: 3,459 jobs, 58
  theorems; and before `StageOutCExtractSlots.lean`: 3,460 jobs, 77 theorems; both green.)
  - the full `lake -d formal build` (`full.log`): **3,461 jobs, rc 0, 0 warnings, 0 errors, no `sorry`** (the rest
    replayed from the build copied from the main checkout);
  - the axiom audit (`gen_axioms.py` → `axioms_l12.lean` → `axioms.log`): **83 theorems**; 81 on
    `[propext, Classical.choice, Quot.sound]`, 1 on `[propext]` (`canonWord_lt`), 1 on none (`head_tables_eq`); no
    `sorryAx`, no `Lean.ofReduceBool`;
  - the source scan of the seven files for `sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`,
    `implemented_by`, `extern`, `bv_decide`, `ofReduceBool`: **none**;
  - the library root imports the seven files;
  - regressions: **`L6Check: 1206 checks, 0 failed`**, **`L5Check: 5553 checks, 0 failed`**, the fixture L1 check
    **`L1 TOTAL: 101956 checks, 0 failed`** (the arguments of `check_l8merge.sh`).
- No Rust was run: this lane adds no export (deliverable 4, §6).
- Guard history: the first job waited 50 minutes (the disk under the guard's 40 GiB floor until the coordinator pruned
  stale worktrees, then GPU jobs of another lane holding the heavy lock).
