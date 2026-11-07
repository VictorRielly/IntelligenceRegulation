# D63 lane L10: the W16R2 opening checks and `M`'s test in executable Lean, `M` under Fiat–Shamir, the L8-5 transfer, and `Binding` (2026-11-07)

Lean lane L10 (Claude), branched from perf at 18d2e74c; perf merged in at 2dfdc8a9 (L9, L11, L12: a merge, no
rebase) so that the adapters build against L9's `BlockParams` and L12's hypothesis shapes. Lean 4.34.1, Mathlib
v4.34.1, no new dependency. Six new library files, imported by the library root: `ExecOpeningCode.lean`,
`BindingW16.lean`, `ExecOpening.lean`, `ExecOpeningM.lean`, `ExecOpeningFS.lean`, `ExecOpeningBlock.lean`; one checker,
`ExecOpeningCheck.lean`, not imported (it defines `main`). One TEST-ONLY Rust file,
`ops/zkp-mvp/gpu-metal/hashline/src/lean_l10_export_tests.rs`, declared by three lines (a comment, a `#[path]`, a `mod`)
at the end of the existing test-only file `hashline/src/private_block/w16r2_tests.rs` (itself `#[cfg(test)]`); it lives
in `src/`, not `src/private_block/`, so `TEST_ONLY_FILES` (83 entries on perf) needs no new entry. No production
source changed. `Statements.lean` and every existing Lean file are unchanged. Evidence:
`results/zk60_lean_l10_20261107/`.

Labels: **PROVED** (a Lean theorem, no `sorry`, axioms `propext`, `Classical.choice`, `Quot.sound` only), **CODE**
(read off the sources), **TESTED** (the agreement corpus), **ESTIMATE**.

## 1. In plain words, for Victor

**What this lane is.** Your D63 gate has five per-profile parts. This lane did four pieces of them for the profile the
code runs today, W16R2 (the media app's Shieldstral classifier and the 8B stack), built so that W16R3's change of the
row encoder (B1) is a swap of one parameter, not a re-proof.

**1. The opening checks and `M`'s test now exist in executable Lean, proved equal to their models.**
- The block verifier checks each committed table by opening a few columns: it re-encodes the prover's clear vectors,
  compares them with the opened columns, and checks each column's Merkle path. `M`, the commitment that holds the
  sumcheck masks, is checked by its own "product" test. Before either, `check_opening` audits the claims' schedule.
- All three are now Lean programs, line by line in the code's order, on the field, hash, transcript and Merkle code of
  L5, plugged into L9's block verifier as its three fields (`maskField`, `checkField`, `pcsField`).
- PROVED: each accepts exactly when every check of the code holds (`pcsVerify_ok_iff`, `maskVerify_ok_iff`), each
  check is the field equation of the soundness model (`colEq_iff_K`, `opening_columns_K`, `mcol_iff_K`,
  `toK_combinedWeights`), and the two that move the transcript move it exactly as L9's block verifier expects
  (`maskField_transcript`, `pcsField_transcript`).
- The encoding step is computed differently from the code: the code runs a full inverse and forward NTT, the Lean
  verifier evaluates the polynomial only at the opened columns (the barycentric formula, PROVED correct). That the two
  give the same numbers is TESTED, not proved (finding L10-1).

**2. They agree with the Rust verifier on a real W16R2 receipt.**
- A test-only export proves the W16R2 development rung's block (public synthetic data) with the crate, replays the
  block verifier step by step (checked against the verifier itself), and records the `M`, `A` and `H` openings and the
  two schedule audits exactly as the block verifier sees them, honest and tampered: 28 records (9 of `M`, 13 of `A`
  and `H`, 6 of `check_opening`; 5 honest, 23 refused by the crate), from a 320-row `A` (36 groups), a 202-row `H`
  (9 groups) and an `M` of 23 masks and 34 functionals.
- TESTED: on every record the Lean field gives the crate's verdict, the same transcript after every acceptance, and
  the same refusal message character for character: **48 checks, 0 failed** (with the four NTT roots and the
  parameters). The honest `A` and `H` openings check all 280 opened columns, each against every clear vector (37 for
  `A`, 10 for `H`), so the Lean barycentric encoding agrees with the code's NTT encoding at 560 columns. The negative
  control (six single changes to the corpus) shows as exactly the eight failed checks it causes (§8).

**3. `M`'s opening is now proved under Fiat–Shamir.** Until today the 8B soundness count ASSUMED it, at `2^-106` per
round, waiting on the F12 fix. F12's fix is in the code (D65(1)). PROVED now: `M`'s three rounds are round-by-round
sound with the code's own challenge derivations, with error at most `2^-106` at `M`'s parameters (`mask_eps_W16R2_le`).
So the assumption in the 8B count is replaced by a theorem about `M`'s actual rounds (`maskSP_kind8B`), and `M` is a
sub-protocol of L8's composition on the code's own transcript (`maskCSub`, `maskCSub_rbr`).

**4. `Binding` is proved, at your proposed target.** The approved statement asks that no one can open a statement's
input commitment (or its hidden-output commitment) to two different values. PROVED for W16R2's endpoint commitments:
`Binding M P εsTarget`, i.e. at most `q·2^-100 + 2^-100` after `q` hash computations, for every `q`
(`binding_planes_target`); for the classifier, whose hidden output is empty (`Unit`, L12-5), the output half is
vacuous (`binding_classifier_target`). The definitions `opensIn` and `opensOut` fit L12's hypothesis shapes (§4).

**What this does not do yet.** L9's `BlockWin` has a premise "every slot's final value is its polynomial at the
point" that the openings are meant to discharge; that needs the openings' KNOWLEDGE version (the committed tables
extracted from the prover's hash log) composed with the slots' terminal identity, which is not done (finding L10-6).
The regular opening's composition on the code's chain needs one more piece of schedule plumbing (L10-3). The
`Protocol` instance does not exist. §7 lists what is left.

## 2. What is proved

148 theorems, every one on at most `propext`, `Classical.choice`, `Quot.sound` (the axiom audit, §8).

**The row code, parametrized for W16R3** (`ExecOpeningCode.lean`, 24 theorems).
- `RowForm F n`: a row's polynomial from its message (`poly : (Fin n → F) →ₗ[F] F[X]`, injective, degree `< n`).
  `lagForm` (W16R2: the interpolant on `G_n`, `lagForm_poly`) and `coefForm` (W16R3's B1: the coefficients,
  `coefPoly_coeff`, `coefPoly_injective`, `coefPoly_natDegree_lt`). The code, rate, domain and row form are parameters;
  W16R2's specifics are named definitions (`w16r2Prm`, `w16r2Form`, `w16r2Pts`, `w16r2OpenCheck`).
- `encPoly R d g = R.poly d + (X^n − 1)·Σ_k g_k X^k` (`encode_row_zk`), `encPoly_natDegree_lt`, `encPoly_inj`;
  `encWord_inj`: at `N ≥ n + Q` distinct points the word determines the message and the pad; `encLin`,
  `encLin_injective` (the linear encoder `SoundGroups.lean` takes).
- `bary_eval`: the barycentric formula `f(x) = (x^n − 1)/n · Σ_i W_i·ω^i/(x − ω^i)` off `G_n`.
- `rootGF_isPrimitiveRoot`: `7^((p−1)/2^k)` is a primitive `2^k`-th root (`seven_pow_half_ne_one`: 7 is a
  non-residue); `coset_pow_ne_one`: the coset `7·G_N` misses `G_n`; `cosetPts_injective`.

**The opening's verifier, executable** (`ExecOpening.lean`, 48 theorems). `pcsVerify` mirrors
`pcs::verify_zk_tagged` in the code's order (the parameters, the path depths first, `group_zclaims`, `zk_rhos`, each
group's length and `⟨v, c⟩` claim, the absorbs, the indices, then per column the index, the length, the salted leaf
and path, and every combination's word equality).
- `pcsVerify_ok_iff`: it returns `ok t'` EXACTLY when every listed check holds (`PcsOk`).
- `toK_encLag`, `toK_encCoef`, `colEncLag_spec`, `colEncCoef_spec`: the executable column evaluation (barycentric with
  ONE inversion per column, `batchInv_spec`; or the coefficients against the powers) IS `encPoly` at the point.
- `colEq_iff_K`, `opening_columns_K`: an accepted column satisfies `Σ_i ρ_i·col_i = encPoly(v)(η_j)` in `K`:
  `SoundGroups.lean`'s column checks for the encoder `encLin`.
- `rootFp_isPrimitiveRoot`, `w16r2_colEnc_spec`, `w16r2OpenCheck_ok_iff`: the W16R2 instance with the code's roots.

**`M`'s test, executable** (`ExecOpeningM.lean`, 27 theorems). `maskVerify` mirrors `zk::mask_verify_tagged`
(`θ`, `combined_weights` with the F12 fix `θ^(i+1)`, `q'`'s length and sum, the absorbs, the indices, per column the
index, the length, the path's depth and climb, the product test, the proximity test).
- `maskVerify_ok_iff`: it accepts EXACTLY when every check holds (`MaskOk`).
- `mcol_iff_K`, `sum_iff_K`, `toK_combinedWeights`: the checks are `SoundMProduct.lean`'s `MAccept` (offset `o = 1`)
  in `K`; `toK_combinedWeights` is the combined functional `Σ_i θ^(i+1)·wt_i`.
- `w16r2MCheck_ok_iff`: the W16R2 instance (`rootFp 9`, `rootFp 12`).

**`M` under Fiat–Shamir, and the L8-5 transfer** (`ExecOpeningFS.lean`, 25 theorems).
- `mask_round0`, `mask_round1`, `mask_round2`, `mask_rbrWide`: `M`'s three rounds are round-by-round sound for any
  derivations with bounded bias (Schwartz–Zippel on the residual, the affine proximity test, the column test).
- `mask_rbrWide_code`: with the code's derivations (`challenge_fp2`, `challenge_fp2_vec(2S + 2)`,
  `challenge_indices(256, 4096)`) on `Dg`; `mask_eps_W16R2_le`, `maskEps_le`: at `M`'s parameters the error is at most
  `2^-106`; `maskSP_kind8B`: `M`'s rounds ARE a sub-protocol of `FSComposeBlock.lean`'s `Kind8B` at that error.
- `RbrWide.mapDig`, `halvesEquiv`, `rbrWide_toCode`: a `Dg` sub-protocol is round-by-round sound on the code's raw
  rounds (`Dig`, absorbed bytes) with the same error: the `hR` premise of `fs_code_chain_sound_sched`.
  `maskCSub_rbr`: `M` on the code's chain (`decPoly_enc`: the messages decode from the code's `absorb_fp2` bytes).
- `opA_rbrWide`, `opB_rbrWide`: the regular opening's two rounds as two sub-protocols (L10-3).

**`Binding`** (`BindingW16.lean`, 15 theorems).
- `PlaneCommit.column_inj` (`col_inj`): the `N` columns determine an admissible value; `opens_iff_exec`: opening is
  the executable column check (`verifyColumn`) on every column.
- `PlaneCommit.binding`: opening one statement's commitment to two different values costs at most
  `collBound (q + 2(h + 2))` (`merkle_binding` at a differing column).
- `binding_planes`, `binding_planes_target`, `binding_classifier_target`: `Binding M P` for a protocol whose
  `opensIn` / `opensOut` are plane openings, at `collBound` and at the proposed target `εsTarget` for every `q`
  (`collBound_le_target` for `q ≤ 2^120`, `one_le_εsTarget` above).
- `posPlane_inj`: canonical token words placed at injective positions determine the words.

**The adapters** (`ExecOpeningBlock.lean`, 9 theorems).
- `maskField_transcript`: `maskField` accepting means L9's `maskTranscript` accepts with the same transcript.
- `pcsField_transcript`: `pcsField` accepting means L9's `pcsTranscript` (the claims' group member counts, `Q = 280`,
  `nn = 2^15`) accepts with the same transcript. `checkField` returns `Unit`: it cannot move the transcript.
- `token_ok_canon`, `posPlane_canon`: L12's extracted inputs `canonWord (epW t)` are admissible, and their plane holds
  exactly the extracted words.

## 3. The check functions for L9

`ExecOpeningBlock.lean` gives L9's three `BlockParams` fields at W16R2 (the `example` there checks the types):

```lean
-- maskVerify : (HIn → Dig) → Dig → List MaskFunctional → MaskOpening → Tr → Except String Tr
def maskField (tag : MTag) (S : ℕ) (H : HIn → Dig) (root : Dig) (fs : List Block.MaskFunctional)
    (mo : Block.MaskOpening) (t : Tr) : Except String Tr
-- checkOpening : (HIn → Dig) → Cm → List ZClaim → Tr → Except String Unit
def checkField (geomOf : Block.Cm → OpenGeom) (H : HIn → Dig) (cm : Block.Cm) (cl : List Block.ZClaim) (t : Tr) :
    Except String Unit
-- pcsVerify : (HIn → Dig) → Cm → Dig → List ZClaim → OpeningZk → Tr → Except String Tr
def pcsField (tag : MTag) (rowsOf : Block.Cm → ℕ) (H : HIn → Dig) (cm : Block.Cm) (root : Dig)
    (cl : List Block.ZClaim) (o : Block.OpeningZk) (t : Tr) : Except String Tr

structure OpenGeom where   -- one commitment's geometry for check_opening
  rows : ℕ                 -- lay.a_rows / lay.h_rows
  siteRows : List ℕ        -- lay.a_site_rows() / lay.h_site_rows()
  sumRows : Option (ℕ × ℕ) -- none / some lay.h_u_rows()
  prox : ℕ                 -- lay.a_prox / lay.h_prox
  groups : ℕ               -- sh.a_groups() / sh.h_groups()
```

So `P.maskVerify := maskField tag S` (`S = lay.mask_specs().len()`), `P.checkOpening := checkField geomOf`,
`P.pcsVerify := pcsField tag rowsOf`, with `tag` the profile's `HashTag` keys. The refusals are the code's messages
character for character (`mErrMsg`, `pcsErrMsg`; the corpus compares them whole); `verify_core`'s `"M: "`, `"A: "`,
`"H: "` prefixes are the caller's. The contracts:

```lean
theorem maskField_transcript (S) (H) (root) (fs) (mo) (t t' : Tr) (h : maskField tag S H root fs mo t = .ok t') :
    ∃ th rs idx, Block.maskTranscript H S mQ mDom mo t = .ok (th, rs, idx, t')
theorem pcsField_transcript (rowsOf) (H) (cm) (root) (cl) (o) (t t' : Tr)
    (h : pcsField tag rowsOf H cm root cl o t = .ok t') :
    ∃ lams rho idx, Block.pcsTranscript H ((groupZclaims (cl.map toZClaim) (rowsOf cm) 14).map (·.2.length))
      (rowsOf cm) w16r2Prm.nQ w16r2Prm.nn o t = .ok (lams, rho, idx, t')
```

`checkField` is `check_opening` on a clone: the schedule audit (`auditClaims`: `audit_claims` with
`zpart_row_weight`'s base-field determinants), the first-occurrence grouping (`openingGroupsAt`), the exact group
count, then L9's own `openingChallenges`; it returns `Unit`, so the transcript does not move. The underlying general
forms stay available: `pcsVerify H tag (prm : PcsPrm) (pt) (ev) root rows cmLogCols claims op t` (any parameters,
points and column evaluator; `w16r3OpenCheck` is the B1 swap) and `maskVerify H tag ω512 ω4096 root S fs op t`, with
their `_ok_iff` theorems (§2). L11-2 (the verify arm does not check the terminal identity; `g` goes to `M`'s functional
list) is consistent with this: `maskField`'s acceptance is `MaskOk`, whose product test is `MAccept` on exactly the
functionals L9 hands it.

## 4. `opensIn` and `opensOut` for L12

`BindingW16.lean`. A value `v` is committed as the data rows of a plane in the hiding PCS:

```lean
structure PlaneCommit (V St Salt : Type) where
  n Q N R dR : ℕ                                 -- message symbols, pads, columns, rows, data rows
  hn : 0 < n
  hNQ : n + Q ≤ N
  form : RowForm GF n                            -- W16R2: lagForm (interpolant on G_n); W16R3 (B1): coefForm
  pts : Fin N → GF                               -- W16R2: cosetPts 7 ω_N
  hpts : Function.Injective pts
  ok : V → Prop                                  -- the admissible values (token words: the canonical ones)
  plane : V → Fin dR → Fin n → GF                -- the layout's map of the value into the data rows
  plane_inj : ∀ v v', ok v → ok v' → plane v = plane v' → v = v'
  place : Fin dR → Fin R                         -- where the data rows sit
  msg : V → Salt → Fin R → Fin n → GF            -- every row's message (data rows from v, mask rows from r)
  msg_place : ∀ v r k, msg v r (place k) = plane v k
  pad : Salt → Fin R → Fin Q → GF                -- every row's pad
  salt : Salt → Fin N → Dig
  path : Salt → Fin N → List Dig
  root : St → Dig                                -- the statement's root (cin or cout)
  tag : MTag
  depth : ℕ

def opensIn  (Cin  : PlaneCommit M.Input  St Salt) (h64 : 64 ≤ L) (hr : 8 * Cin.R ≤ L)
    (G : QB L → Dig) (s : St) (x : M.Input) (r : Salt) : Prop := Cin.Opens L h64 hr G s x r
def opensOut (Cout : PlaneCommit M.HidOut St Salt) (h64 : 64 ≤ L) (hr : 8 * Cout.R ≤ L)
    (G : QB L → Dig) (s : St) (y : M.HidOut) (r : Salt) : Prop := Cout.Opens L h64 hr G s y r
def opensUnit (G : Q → D) (s : St) (y : Unit) (r : Salt) : Prop := True      -- the classifier's output (L12-5)
```

- `Opens` means: `v` is admissible and every one of the `N` columns of `v`'s encoded plane (with `r`'s mask rows,
  pads, salts and paths) passes the executable column check of `ExecMerkle.lean` against the statement's root
  (`opens_iff_exec`). `Salt` holds the salts, the paths, the mask rows and the pads, as §4.4 asked.
- `w16r2PlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag` fixes the code at W16R2's
  (`n = 2^14`, `Q = 280`, `N = 2^15`, the interpolant rows, the coset `7·G_{2^15}`, depth 15) and leaves the geometry,
  the admissible values and the plane map to the caller. W16R3 is the same with `form := coefForm`.
- **L12's shapes.** Input: `x t = canonWord (epW t)` (ℕ-valued words). Take `V = T → ℕ` and
  `w16r2TokenCommit R dR hpos place msg msg_place pad salt path root tag`: admissible = canonical (`x t < p`), plane =
  `posPlane pos x` (the words at the layout's injective positions `pos`). Then `P.opensIn H s x r` is
  `opensIn (w16r2TokenCommit …) …`; `token_ok_canon` gives admissibility of L12's `x` for free and `posPlane_canon`
  that the plane holds exactly `epW` at the token positions. Token-run output: `P.opensOut H s (canonWord epO) r'` is
  the same construction with `T = Unit` (one word, `epO`) on the output endpoint. Classifier output:
  `P.opensOut H s () r'` is `opensUnit` (`True`), and `binding_classifier_target` gives the whole `Binding` from the
  input half alone (`[Subsingleton M.HidOut]`).
- What L12 supplies: `pos` with its injectivity (the endpoint layout), the endpoint geometry (`R = endpoint_rows`, the
  data rows' placement, the terminal pair and proximity rows as the other rows) and `root` (the statement's `cin` /
  `cout`).

## 5. F12 and `M`'s Fiat–Shamir bound

**F12 is fixed in the code** (CODE, D65(1), 2026-11-04): `zk.rs`'s `combined_weights` starts the powers at `θ^1`, for
the prover and the verifier, on one code path; every `M`-carrying profile moved to a `/2` version string and the old
strings are refused by name. `ExecOpeningM.lean`'s `combinedWeights` mirrors `θ^(i+1)` (`toK_combinedWeights`), and the
corpus's honest `M` record, produced by the fixed code, is accepted by it (§8).

**The bound is proved on the code chain** (PROVED): `mask_rbrWide_code` with the code's derivations,
`mask_eps_W16R2_le` (`≤ 2^-106` at `N = 4096`, `K = 1023`, `m = 512`, `e = 1024`, `dd = 1534`, `Q = 256`, at most
`2^20` functionals and rows, `|E| = p²`), `maskSP_kind8B` (the sub-protocol `Kind8B.mask` assumed), and
`maskCSub_rbr` (on the code's raw rounds, through `rbrWide_toCode`). The three per-round terms: `θ`:
`k/|E|·(1 + p/2^128)²`; `r`: `(e + 1)/(|E| − 1)·(1 + p/2^128)^(2(2S+2))`; `J`: `max(((N − e − 1)/N)^256,
((e + dd)/N)^256)`. The largest of all is the far case of `J`, `(3071/4096)^256 ≈ 2^-106.4` (`mask_col_far_nat`:
`3071^256·2^106 ≤ 4096^256`), so `2^-106` is tight at `Q = 256`; the close case is `(2558/4096)^256 ≈ 2^-173.8`, the
other two rounds about `2^-108` (`θ`, at `k = 2^20` functionals) and `2^-118` (`r`) (ESTIMATE, from the proved
expressions).

This is the SOUNDNESS version (the committed rows are named by the statement, `dat`). The knowledge version, the rows
extracted from the prover's hash log as `FSOpening.lean` does for the regular opening, is not composed (L10-6).

## 6. Findings

- **L10-1 (Info).** The Lean verifier evaluates each opened column's encoding by the barycentric formula at the
  column's point, the code by `encode_row_zk` (inverse NTT, coset powers, forward NTT over all `2^15` points). The Lean
  side is PROVED equal to `encPoly` at the point; that the code's NTT computes the same polynomial's values is TESTED,
  not proved: all 280 opened columns of the honest `A` (37 vectors each) and `H` (10 vectors), 279 more of `H` in
  `h-collast`, `M`'s 256 columns (product and proximity tests) in `m-honest` and 255 in `m-collast`, and `h-coef0`'s
  refused column. No disagreement found.
- **L10-2 (Info).** The code's `group_zclaims` asserts the claims' shapes (a claim's parts agree on their column
  weights); the verifier's claims are its own, and `pcsVerify` does not mirror the assertion. `check_opening` refuses
  such a claim first (`openingGroupsAt`, "claim parts with different column weights"), and `checkField` mirrors that.
- **L10-3 (Low).** The code absorbs the regular opening's round-1 message as `G + 1` items (`"pcs-vec"` per group, then
  `"pcs-prox"`); L8's reader takes one absorb per round. The opening therefore enters the code's schedule as two
  sub-protocols (`opA`, `opB`, each PROVED round-by-round sound); their coupling is the schedule's (L9).
- **L10-4 (Info).** `audit_claims`'s `is_site` is a `binary_search` on `site_rows`, correct only on a sorted list;
  the Lean audit uses membership. They agree because the layout's site rows are ascending (TESTED on A and H); a
  layout with unsorted site rows would make the code's audit wrong, not the Lean one.
- **L10-5 (Info, L12-5).** The classifier's hidden output is `Unit`: there is no output endpoint, and `opensOut` is
  `opensUnit` (`True`). `Binding`'s output half is then vacuous (`binding_classifier_target`); the input half is the
  plane binding. No change to `Statements.lean`.
- **L10-6 (Medium, open).** L9's `BlockWin` takes as a PREMISE that every slot's final value is its polynomial at the
  point (`fin = f(ρ)`), "which `M` and the openings discharge". This lane does not discharge it. What it needs:
  (a) the openings' and `M`'s KNOWLEDGE versions (the committed tables and mask rows extracted from the prover's hash
  log, straight-line, as `FSOpening.lean` does for one opening), so that `f k` can be a function of the trace;
  (b) the slots' terminal identity (`fin = g(terms)`, L11-2: enforced only through `M`'s functionals and the claims);
  (c) the claims-to-tables map: each claim's value is the extracted table's multilinear extension at the slot's point
  (L12's stage lemmas take this shape). This lane supplies the pieces' executable checks and their `ok_iff` and field
  forms; the composition is open.
- **L10-7 (Info).** `maskCSub` takes its release predicate `rel` as a parameter (the schedule's choice; it does not
  enter the round-by-round bound).

## 7. What is left

1. **`BlockWin`'s terminal premise** (L10-6): the knowledge versions of `M` and the regular opening on the code's
   chain, and their composition with the slots' terminal identity and the claims-to-tables map.
2. **The regular opening's composition on the code's chain** (L10-3): `opA` / `opB`'s coupling in L9's schedule.
3. **The NTT equality** (L10-1): optional; a proof that `encode_row_zk` computes `encPoly`'s values would remove the
   one TESTED step. Not needed for soundness of the Lean verifier itself.
4. **The `Protocol` instance**: `opensIn` / `opensOut` are ready (§4); the instance (the statement type, the salt
   type, the roots) is the assembly's.
5. **W16R3**: the instance swap (`coefForm`, `w16r3OpenCheck`, `colEncCoef_spec`) is in place; the W16R3 corpus waits
   for W16R3 receipts.

## 8. Checks

All through the zk60 resource guard (class cpu, `run_guarded.py`), logs and `.done` markers in
`results/zk60_lean_l10_20261107/`.

- **The corpus export** (`export_corpus.sh`, inside `iter.sh`, job `lean-l10-iter`): `cargo test --release --offline
  --locked -j 2 --lib lean_l10_export`, 1 passed; the step-by-step replay ends at `verify_core`'s own transcript
  (asserted); 28 records, 191,941,509 bytes, written outside the repository (`corpus.sha256`:
  `0eedc99a74a903cf5b3191c75c8d44f8562c7b1f829d97f6756be9cf83b01608`); 160 s.
- **The agreement check** (`ExecOpeningCheck.lean` through `runchk.py`): reduced corpus (without the three openings
  whose every column is checked) **40 checks, 0 failed**, 235 s; full corpus **48 checks, 0 failed** (4 NTT roots;
  9 `M` verdicts and `L9`'s `maskTranscript` on the honest one; 13 PCS verdicts, 13 parameter checks and L9's
  `pcsTranscript` on the 2 honest ones; 6 `check_opening` verdicts), 1,277 s (`a-honest` 631 s, `h-honest` 193 s,
  `h-collast` 191 s), peak 4.1 GiB (`l10check_full.log`, `l10check.log`).
- **Negative control** (`negctl.py`, six single changes to the reduced corpus): **41 checks, 8 failed**, exactly the
  eight the changes cause (the root, `m-honest`'s transcript twice, `m-q0`'s verdict twice, `a-vec0`'s message,
  `chk-a`'s verdict, `chk-h-groups`' declared count) (`l10check_neg.log`).
- **The final check** (`check_l10.sh`, job `lean-l10-check`, 1,537 s; `check.log`, run 1 in `check_run1.log`): the
  full Lean build green, 3,486 jobs, no error, no `sorry` (run 2 after replacing the deprecated `if_pos`/`if_neg`/
  `dif_pos`/`Set.mem_setOf_eq`/`eval_finset_sum` by their new names and omitting unused section instances: 3 linter
  warnings left, removed by three `omit … in` lines; the build-only run 3, `check3.log`, on the final tree: build
  green, **0 warnings**, 0 errors, no `sorry`, the same audit and scan; no definition changed after run 2, so its
  regressions and checker runs stand); the axiom audit of
  all **148** theorems of the six library files: 114 on `[propext, Classical.choice, Quot.sound]`, 22 on
  `[propext, Quot.sound]`, 11 on `[propext]`, 1 on none (`Fp.one_canon`), no `sorryAx`, no `ofReduceBool`; the source scan (`sorry`,
  `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`, `implemented_by`, `extern`, `bv_decide`,
  `ofReduceBool`) of the seven L10 files: none; the root imports the six library files; regressions **L6Check 1,206
  checks, 0 failed**, **L5Check 5,553 checks, 0 failed**; the L10 checker and its negative control as above.
- Not run here: hashline's full test suite and the `r19b` census (the Rust file is outside `src/private_block/`, so
  `TEST_ONLY_FILES` is untouched; the merge's census is the coordinator's).
