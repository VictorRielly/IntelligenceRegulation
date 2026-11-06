/-
D63, step L2: **the whole forward pass**, from the prompt's token ids to the next token (or the classifier's verdict),
as INSTANCES of the approved `CircuitIff` (`Statements.lean`): the first statement's literal form, "the proof is
accepted exactly when it attests the discretized model's output".

The run is the token-I/O run of DESIGN v3 (token_io.rs:7-24):

  [stage IN] → B_in → block 0 → B_1 → … → block L−1 → B_out → [stage OUT]

* stage IN / IN-C (`stage_in.rs`, `stage_in_c.rs`): the hidden token ids, sealed in the input token endpoint, are
  mapped to `B_in` through the public int16 embedding by ONE indexed LogUp lookup per position of the compressed row
  `(tok_t, x~(t, r_emb))` in the table `(v, E~(v, r_emb))` (`SI_QZC`, stage_in.rs:214-237; `SI_TZC`, :238-253), with
  BOS forced at position 0 by its own clause. IN-C adds the template clause (every template position holds its public
  id) and a third, public, tuple column: the control column `ctl(v) = [v < num_special]` in the table and
  `c(t) = ctl(κ(t))` at template positions, `0` at content positions, so a content position holding a control id
  matches no table entry (stage_in_c.rs:1-16). `in_iff`.
* the blocks: `run_iff` / `run_circuitIff` (CircuitBlock.lean), W16R2 blocks at their logical positions.
* stage OUT / OUT-C: `out_iff`, `outC_iff` (CircuitOut.lean), on `B_out`'s public row (`T − 1`, or the classifier's
  public verdict row `P0 + n + S − 1`, classify.rs:666-669).

Proved: `runOut_iff` (a run of blocks and stage OUT: the run-to-output iff), `tokenRun_iff` and
**`tokenRun_circuitIff : CircuitIff (tokenModel S R) (tokenArith S R)`**, and the classifier's `classifyRun_iff` and
**`classifyRun_circuitIff`**.

The premises are those of `BlockSat` and of the stages' relations: each relation is the constraint system at the
LOGICAL positions with the hosted sums and the lookups as L3's conclusions. For stage IN that is the compressed-row
lookup read as "the position's id `v` is below `V`, its `B_in` row IS `E[v]` and its control column is `ctl(v)`": the
step from the compressed tuple `(tok, x~(t, r))` to the whole row is L3's (a Schwartz–Zippel step over `r_emb`, counted
in the whole-run figure as `T·log d_pad`, run.rs:224-226), and the tuple's membership is LogUp's. The boundary planes
`B_in`, `B_k`, `B_out` are int16 word planes, as in `RunSat`.

Instance choices (written up, not changed in `Statements.lean`): `Weights := Unit` (P1, as for the block); the model's
input is the prompt's ids, and `Satisfies` asks them to be canonical field words (`< p`), as the endpoint commits field
words (`Fp::new(id)`, stage_in.rs:100); the next token is the hidden output part (sealed in the output token endpoint),
the classifier's verdict the PUBLIC output part (the statement absorbs it, stage_out_c.rs:20-21).
-/
import ZK60Formal.CircuitOut

namespace ZK60.TokenRun

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.Out

variable {S : BlockShape}

/-! ## Stage IN and IN-C -/

/-- The public data of the input stage (`TokenTables::emb`, token_io.rs:625-631; the classifier's template,
`Policy`, classify.rs:100-140): the vocabulary, BOS, the int16 embedding, the template positions and ids (none for the
next-token run), and the control-id class `[0, ns)` (`ns = 0` for the next-token run: no control column). -/
structure InPublic (S : BlockShape) where
  V : ℕ
  bos : ℕ
  emb : ℕ → S.Wid → ℤ
  isT : S.Tok → Bool
  kap : S.Tok → ℕ
  ns : ℕ

/-- The classes the doors admit: `2 ≤ V ≤ 2^17` (token_io.rs:489-490), BOS below `V` (:492-494), the embedding int16
(`TokenTables::emb : Vec<i16>`), the template ids below `V` (classify.rs:580-584) and `ns < V` (:586-588). -/
structure InPublic.Valid (P : InPublic S) : Prop where
  V1 : 2 ≤ P.V
  V2 : P.V ≤ 2 ^ 17
  bos : P.bos < P.V
  emb : ∀ v i, i16 (P.emb v i)
  kap : ∀ t, P.kap t < P.V
  ns : P.ns < P.V

/-- `ctl(v) = 1` exactly for the control ids `v < num_special` (classify.rs:107). -/
def ctl (P : InPublic S) (v : ℕ) : ℕ := if v < P.ns then 1 else 0

/-- The public control column of a position: `ctl(κ(t))` at a template position, `0` at a content position
(stage_in_c.rs:9-15). -/
def ctlPos (P : InPublic S) (t : S.Tok) : ℕ := if P.isT t = true then ctl P (P.kap t) else 0

/-- One position's embedding lookup, read at the logical level: the tuple `(tok, row, c)` is a table tuple
`(v, E[v], ctl(v))` for some `v < V`. -/
def EmbRow (P : InPublic S) (tok : GF) (row : S.Wid → GF) (c : GF) : Prop :=
  ∃ v : ℕ, v < P.V ∧ tok = (v : GF) ∧ (∀ i, row i = (P.emb v i : GF)) ∧ c = (ctl P v : GF)

/-- **The input stage's clauses** at the `T` prompt positions (`tok` = the input token endpoint's words, which `SI_IO`
equates with `A_TOK` on the support, stage_in.rs:200-211): the embedding lookup of every position (`SI_QZC`'s LogUp
clause), the BOS clause (`bos_c`, :232) and the template clause (IN-C). -/
structure InSat (P : InPublic S) (tok : S.Tok → GF) (X : S.Pos → GF) : Prop where
  lookup : ∀ t, EmbRow P (tok t) (fun i => X (t, i)) (ctlPos P t : GF)
  bos : ∀ t : S.Tok, (t : ℕ) = 0 → tok t = (P.bos : GF)
  template : ∀ t, P.isT t = true → tok t = (P.kap t : GF)

open Classical in
/-- **The input stage's integer semantics** (`honest_inputs`, stage_in.rs:72-106, stage_in_c.rs:72-104; `embedL`):
refused when an id is outside the vocabulary, position 0 is not BOS, a template position is not its public id or a
content position holds a control id; otherwise `B_in(t, i) = E[tok_t][i]`. -/
noncomputable def inSpec (P : InPublic S) (toks : S.Tok → ℕ) : Option (S.Pos → ℤ) :=
  if (∀ t, toks t < P.V) ∧ (∀ t : S.Tok, (t : ℕ) = 0 → toks t = P.bos) ∧ (∀ t, P.isT t = true → toks t = P.kap t) ∧
      (∀ t, P.isT t = false → ¬ toks t < P.ns)
  then some (fun p => P.emb (toks p.1) p.2) else none

theorem lt_gP_of_V {P : InPublic S} (hP : P.Valid) {v : ℕ} (hv : v < P.V) : v < gP :=
  lt_of_lt_of_le hv (le_trans hP.V2 (by norm_num))

theorem ctl_le (P : InPublic S) (v : ℕ) : ctl P v < gP := by
  unfold ctl; split_ifs <;> norm_num

theorem ctlPos_le (P : InPublic S) (t : S.Tok) : ctlPos P t < gP := by
  unfold ctlPos; split_ifs
  · exact ctl_le P _
  · norm_num

/-- **`CircuitIff` for the input stage**: for canonical endpoint words (`toks t < p`), the clauses hold with `B_in`
plane `X` exactly when the integer stage admits the prompt and `X` is the image of its embedding rows. -/
theorem in_iff (P : InPublic S) (hP : P.Valid) (toks : S.Tok → ℕ) (htoks : ∀ t, toks t < gP) (X : S.Pos → GF) :
    InSat P (fun t => (toks t : GF)) X ↔ ∃ x, inSpec P toks = some x ∧ ∀ p, X p = (x p : GF) := by
  constructor
  · rintro ⟨hl, hb, ht⟩
    have hv : ∀ t, toks t < P.V ∧ (∀ i, X (t, i) = (P.emb (toks t) i : GF)) ∧ ctlPos P t = ctl P (toks t) := by
      intro t
      obtain ⟨v, hvV, htv, hrow, hc⟩ := hl t
      have he : toks t = v := natCast_inj_lt (htoks t) (lt_gP_of_V hP hvV) htv
      subst he
      exact ⟨hvV, hrow, natCast_inj_lt (ctlPos_le P t) (ctl_le P _) hc⟩
    have hcond : (∀ t, toks t < P.V) ∧ (∀ t : S.Tok, (t : ℕ) = 0 → toks t = P.bos) ∧
        (∀ t, P.isT t = true → toks t = P.kap t) ∧ (∀ t, P.isT t = false → ¬ toks t < P.ns) := by
      refine ⟨fun t => (hv t).1, fun t h0 => ?_, fun t hT => ?_, fun t hT hlt => ?_⟩
      · exact natCast_inj_lt (htoks t) (lt_gP_of_V hP hP.bos) (hb t h0)
      · exact natCast_inj_lt (htoks t) (lt_gP_of_V hP (hP.kap t)) (ht t hT)
      · have h := (hv t).2.2
        unfold ctlPos at h
        rw [ite_eq_right (by rw [hT]; decide)] at h
        unfold ctl at h
        rw [ite_eq_left hlt] at h
        exact absurd h (by norm_num)
    refine ⟨fun p => P.emb (toks p.1) p.2, ?_, fun p => (hv p.1).2.1 p.2⟩
    unfold inSpec
    rw [ite_eq_left hcond]
  · rintro ⟨x, hx, hX⟩
    unfold inSpec at hx
    by_cases hcond : (∀ t, toks t < P.V) ∧ (∀ t : S.Tok, (t : ℕ) = 0 → toks t = P.bos) ∧
        (∀ t, P.isT t = true → toks t = P.kap t) ∧ (∀ t, P.isT t = false → ¬ toks t < P.ns)
    · rw [ite_eq_left hcond] at hx
      have hxe : (fun p : S.Pos => P.emb (toks p.1) p.2) = x := Option.some.inj hx
      obtain ⟨hV, hB, hT, hC⟩ := hcond
      refine ⟨fun t => ⟨toks t, hV t, rfl, fun i => by show X (t, i) = _; rw [hX, ← hxe], ?_⟩, fun t h0 => by rw [hB t h0],
        fun t h => by rw [hT t h]⟩
      unfold ctlPos
      by_cases hti : P.isT t = true
      · rw [ite_eq_left hti, hT t hti]
      · rw [ite_eq_right hti]
        have hf : P.isT t = false := by simpa using hti
        unfold ctl
        rw [ite_eq_right (hC t hf)]
    · rw [ite_eq_right hcond] at hx
      cases hx

theorem inSpec_some {P : InPublic S} {toks : S.Tok → ℕ} {x : S.Pos → ℤ} (h : inSpec P toks = some x) :
    (∀ t, toks t < P.V) ∧ x = fun p => P.emb (toks p.1) p.2 := by
  unfold inSpec at h
  split_ifs at h with hc
  exact ⟨hc.1, (Option.some.inj h).symm⟩

theorem inSpec_class {P : InPublic S} (hP : P.Valid) {toks : S.Tok → ℕ} {x : S.Pos → ℤ}
    (h : inSpec P toks = some x) (p : S.Pos) : i16 (x p) := by
  rw [(inSpec_some h).2]
  exact hP.emb _ _

/-! ## The run to its output -/

theorem outSpec_lt {n : ℕ} {P : OutPublic n} (hP : P.Valid) {x : Fin n → ℤ} {z : ℕ} (h : outSpec P x = some z) :
    z < P.V := by
  unfold outSpec at h
  obtain ⟨_, -, hz⟩ := Option.map_eq_some_iff.mp h
  rw [← hz]
  exact (argmaxN_spec _ P.V (le_trans (by norm_num) hP.V1)).1

/-- **The run-to-output iff**: a run of W16R2 blocks on int16 input words `x` followed by stage OUT on the last
block's public row: the constraint systems hold, through the boundary planes, for the committed token word `tok`
exactly when the integer run admits `x`, stage OUT admits its output row, and `tok` is the image of the greedy
token. -/
theorem runOut_iff (hS : S.Valid) (Ps : List (BlockPublic S)) (hPs : ∀ P ∈ Ps, P.Valid) (Q : OutPublic S.d)
    (hQ : Q.Valid) (row : S.Tok) (x : S.Pos → ℤ) (hx : ∀ p, i16 (x p)) (tok : GF) :
    (∃ y : S.Pos → ℤ, (∀ p, i16 (y p)) ∧ RunSat Ps x y ∧ OutSat Q (fun i => (y (row, i) : GF)) tok) ↔
      ∃ z, ((runSpec Ps x).bind fun y => outSpec Q fun i => y (row, i)) = some z ∧ tok = (z : GF) := by
  constructor
  · rintro ⟨y, hy, hr, ho⟩
    have hrun := (run_iff hS Ps hPs x y hx).mp hr
    obtain ⟨z, hz, htok⟩ := (out_iff hS.d_le Q hQ (fun i => y (row, i)) (fun i => hy _) tok).mp ho
    refine ⟨z, ?_, htok⟩
    rw [hrun, obind_some]
    exact hz
  · rintro ⟨z, hz, htok⟩
    obtain ⟨y, hy, hz'⟩ := obind_eq_some.mp hz
    have hyc := runSpec_class Ps x y hx hy
    exact ⟨y, hyc, (run_iff hS Ps hPs x y hx).mpr hy,
      (out_iff hS.d_le Q hQ (fun i => y (row, i)) (fun i => hyc _) tok).mpr ⟨z, hz', htok⟩⟩

/-! ## The next-token run -/

/-- The next-token run's public data: the input stage, the blocks, stage OUT, and the public row (`T − 1`). -/
structure TokenRunPublic (S : BlockShape) where
  inp : InPublic S
  Ps : List (BlockPublic S)
  out : OutPublic S.d
  row : S.Tok

structure TokenRunPublic.Valid (R : TokenRunPublic S) : Prop where
  inp : R.inp.Valid
  Ps : ∀ P ∈ R.Ps, P.Valid
  out : R.out.Valid

/-- **The integer model of the whole forward pass** (the next token): stage IN, the blocks, stage OUT. -/
noncomputable def tokenSpec (R : TokenRunPublic S) (toks : S.Tok → ℕ) : Option ℕ :=
  (inSpec R.inp toks).bind fun x => (runSpec R.Ps x).bind fun y => outSpec R.out fun i => y (R.row, i)

/-- **The whole run's constraint system**: stage IN's clauses on the endpoint words and `B_in`, the blocks through
their boundary planes (`RunSat`), stage OUT's clauses on `B_out`'s public row and the output token word. -/
def TokenRunSat (R : TokenRunPublic S) (toks : S.Tok → ℕ) (z : ℕ) : Prop :=
  ∃ x y : S.Pos → ℤ, (∀ p, i16 (x p)) ∧ (∀ p, i16 (y p)) ∧ InSat R.inp (fun t => (toks t : GF)) (fun p => (x p : GF)) ∧
    RunSat R.Ps x y ∧ OutSat R.out (fun i => (y (R.row, i) : GF)) (z : GF)

/-- **The forward-pass iff**: for canonical endpoint words, the whole run's constraint system holds with output token
`z` exactly when the integer model admits the prompt and `z` is its next token. -/
theorem tokenRun_iff (hS : S.Valid) (R : TokenRunPublic S) (hR : R.Valid) (toks : S.Tok → ℕ)
    (htoks : ∀ t, toks t < gP) (z : ℕ) (hz : z < gP) : TokenRunSat R toks z ↔ tokenSpec R toks = some z := by
  constructor
  · rintro ⟨x, y, hx, hy, hin, hr, ho⟩
    obtain ⟨x', hx', hX⟩ := (in_iff R.inp hR.inp toks htoks _).mp hin
    have hxx : x = x' := funext fun p => i16_eq_of_cast (hx p) (inSpec_class hR.inp hx' p) (hX p)
    rw [← hxx] at hx'
    obtain ⟨z', hz', hzz⟩ := (runOut_iff hS R.Ps hR.Ps R.out hR.out R.row x hx (z : GF)).mp ⟨y, hy, hr, ho⟩
    obtain ⟨_, -, hz''⟩ := obind_eq_some.mp hz'
    have hlt : z' < gP := lt_of_lt_of_le (outSpec_lt hR.out hz'') (le_trans hR.out.V2 (by norm_num))
    have he : z = z' := natCast_inj_lt hz hlt hzz
    rw [← he] at hz'
    unfold tokenSpec
    rw [hx', obind_some]
    exact hz'
  · intro h
    unfold tokenSpec at h
    obtain ⟨x, hx, h⟩ := obind_eq_some.mp h
    have hxc := inSpec_class hR.inp hx
    obtain ⟨y, hyc, hr, ho⟩ := (runOut_iff hS R.Ps hR.Ps R.out hR.out R.row x hxc (z : GF)).mpr ⟨z, h, rfl⟩
    exact ⟨x, y, hxc, hyc, (in_iff R.inp hR.inp toks htoks _).mpr ⟨x, hx, fun p => rfl⟩, hr, ho⟩

/-- The next-token run as an `IntModel`: the prompt's ids in, the next token out (hidden: sealed in the output token
endpoint, P1). -/
noncomputable def tokenModel (S : BlockShape) (R : TokenRunPublic S) : IntModel where
  Weights := Unit
  Input := S.Tok → ℕ
  Output := ℕ
  PubOut := Unit
  HidOut := ℕ
  admissible toks := ∃ z, tokenSpec R toks = some z
  forward _ toks := (tokenSpec R toks).getD 0
  publicPart _ := ()
  hiddenPart z := z

/-- What `tokenArith` asks: canonical endpoint words and the whole run's constraint system. -/
abbrev tokenSat (R : TokenRunPublic S) (toks : S.Tok → ℕ) (z : ℕ) : Prop :=
  (∀ t, toks t < gP) ∧ z < gP ∧ TokenRunSat R toks z

/-- The whole run's constraint system as an `Arith`: the endpoints are canonical field words. -/
def tokenArith (S : BlockShape) (R : TokenRunPublic S) : Arith (tokenModel S R) where
  Witness := Unit
  Satisfies _ toks z _ := tokenSat R toks z

theorem tokenSpec_lt {R : TokenRunPublic S} (hR : R.Valid) {toks : S.Tok → ℕ} {z : ℕ}
    (h : tokenSpec R toks = some z) : (∀ t, toks t < gP) ∧ z < gP := by
  unfold tokenSpec at h
  obtain ⟨x, hx, h⟩ := obind_eq_some.mp h
  obtain ⟨y, -, h⟩ := obind_eq_some.mp h
  exact ⟨fun t => lt_gP_of_V hR.inp ((inSpec_some hx).1 t),
    lt_of_lt_of_le (outSpec_lt hR.out h) (le_trans hR.out.V2 (by norm_num))⟩

/-- **D63 statement 1's deterministic lemma for the whole next-token forward pass**: the prompt's ids in, the next
token out, through stage IN, every W16R2 block and stage OUT. -/
theorem tokenRun_circuitIff (hS : S.Valid) (R : TokenRunPublic S) (hR : R.Valid) :
    CircuitIff (tokenModel S R) (tokenArith S R) := by
  intro _ toks z
  show (∃ _w : Unit, tokenSat R toks z) ↔
    (∃ z', tokenSpec R toks = some z') ∧ z = (tokenSpec R toks).getD 0
  constructor
  · rintro ⟨-, ht, hz, h⟩
    have hs := (tokenRun_iff hS R hR toks ht z hz).mp h
    refine ⟨⟨z, hs⟩, ?_⟩
    rw [hs]
    rfl
  · rintro ⟨⟨z', hz'⟩, hzd⟩
    have hzz : z = z' := by rw [hzd, hz']; rfl
    subst hzz
    obtain ⟨ht, hz⟩ := tokenSpec_lt hR hz'
    exact ⟨(), ht, hz, (tokenRun_iff hS R hR toks ht z hz).mpr hz'⟩

/-! ## The classifier run -/

/-- The classifier run's public data: the input stage (with its template), the blocks, stage OUT-C, and the public
verdict row `P0 + n + S − 1` (classify.rs:666-669). -/
structure ClassifyRunPublic (S : BlockShape) where
  inp : InPublic S
  Ps : List (BlockPublic S)
  out : OutCPublic S.d
  row : S.Tok

structure ClassifyRunPublic.Valid (R : ClassifyRunPublic S) : Prop where
  inp : R.inp.Valid
  Ps : ∀ P ∈ R.Ps, P.Valid
  out : R.out.Valid

/-- **The classifier's integer model**: stage IN-C, the blocks, stage OUT-C. -/
noncomputable def classifySpec (R : ClassifyRunPublic S) (toks : S.Tok → ℕ) : Option ℕ :=
  (inSpec R.inp toks).bind fun x => (runSpec R.Ps x).bind fun y => outCSpec R.out fun i => y (R.row, i)

/-- The classifier run's constraint system, for the published verdict bit `b`. -/
def ClassifyRunSat (R : ClassifyRunPublic S) (toks : S.Tok → ℕ) (b : ℕ) : Prop :=
  ∃ x y : S.Pos → ℤ, (∀ p, i16 (x p)) ∧ (∀ p, i16 (y p)) ∧ InSat R.inp (fun t => (toks t : GF)) (fun p => (x p : GF)) ∧
    RunSat R.Ps x y ∧ OutCSat R.out (fun i => (y (R.row, i) : GF)) b

theorem verdictOf_le (m c : ℤ) : verdictOf m c ≤ 1 := by
  unfold verdictOf; split_ifs <;> norm_num

theorem classifyRun_iff (hS : S.Valid) (R : ClassifyRunPublic S) (hR : R.Valid) (toks : S.Tok → ℕ)
    (htoks : ∀ t, toks t < gP) (b : ℕ) (hb : b ≤ 1) : ClassifyRunSat R toks b ↔ classifySpec R toks = some b := by
  constructor
  · rintro ⟨x, y, hx, hy, hin, hr, ho⟩
    obtain ⟨x', hx', hX⟩ := (in_iff R.inp hR.inp toks htoks _).mp hin
    have hxx : x = x' := funext fun p => i16_eq_of_cast (hx p) (inSpec_class hR.inp hx' p) (hX p)
    rw [← hxx] at hx'
    have hrun := (run_iff hS R.Ps hR.Ps x y hx).mp hr
    have hout := (outC_iff hS.d_le R.out hR.out (fun i => y (R.row, i)) (fun i => hy _) b hb).mp ho
    unfold classifySpec
    rw [hx', obind_some, hrun, obind_some]
    exact hout
  · intro h
    unfold classifySpec at h
    obtain ⟨x, hx, h⟩ := obind_eq_some.mp h
    obtain ⟨y, hy, h⟩ := obind_eq_some.mp h
    have hxc := inSpec_class hR.inp hx
    have hyc := runSpec_class R.Ps x y hxc hy
    exact ⟨x, y, hxc, hyc, (in_iff R.inp hR.inp toks htoks _).mpr ⟨x, hx, fun p => rfl⟩,
      (run_iff hS R.Ps hR.Ps x y hxc).mpr hy,
      (outC_iff hS.d_le R.out hR.out (fun i => y (R.row, i)) (fun i => hyc _) b hb).mpr h⟩

/-- The classifier run as an `IntModel`: the item's ids in, the verdict out, PUBLISHED (the statement absorbs it). -/
noncomputable def classifyModel (S : BlockShape) (R : ClassifyRunPublic S) : IntModel where
  Weights := Unit
  Input := S.Tok → ℕ
  Output := ℕ
  PubOut := ℕ
  HidOut := Unit
  admissible toks := ∃ b, classifySpec R toks = some b
  forward _ toks := (classifySpec R toks).getD 0
  publicPart b := b
  hiddenPart _ := ()

/-- What `classifyArith` asks: canonical endpoint words, the verdict one bit (classify.rs:957-958), and the classifier
run's constraint system. -/
abbrev classifySat (R : ClassifyRunPublic S) (toks : S.Tok → ℕ) (b : ℕ) : Prop :=
  (∀ t, toks t < gP) ∧ b ≤ 1 ∧ ClassifyRunSat R toks b

/-- The classifier run's constraint system as an `Arith`. -/
def classifyArith (S : BlockShape) (R : ClassifyRunPublic S) : Arith (classifyModel S R) where
  Witness := Unit
  Satisfies _ toks b _ := classifySat R toks b

/-- **D63 statement 1's deterministic lemma for the whole classifier forward pass**: the item's ids in, the published
verdict out, through stage IN-C, every W16R2 block and stage OUT-C. -/
theorem classifyRun_circuitIff (hS : S.Valid) (R : ClassifyRunPublic S) (hR : R.Valid) :
    CircuitIff (classifyModel S R) (classifyArith S R) := by
  intro _ toks b
  show (∃ _w : Unit, classifySat R toks b) ↔
    (∃ b', classifySpec R toks = some b') ∧ b = (classifySpec R toks).getD 0
  constructor
  · rintro ⟨-, ht, hb, h⟩
    have hs := (classifyRun_iff hS R hR toks ht b hb).mp h
    refine ⟨⟨b, hs⟩, ?_⟩
    rw [hs]
    rfl
  · rintro ⟨⟨b', hb'⟩, hbd⟩
    have hbb : b = b' := by rw [hbd, hb']; rfl
    rw [hbb]
    have ht : ∀ t, toks t < gP := by
      unfold classifySpec at hb'
      obtain ⟨x, hx, -⟩ := obind_eq_some.mp hb'
      exact fun t => lt_gP_of_V hR.inp ((inSpec_some hx).1 t)
    have hb1 : b' ≤ 1 := by
      unfold classifySpec at hb'
      obtain ⟨x, -, h⟩ := obind_eq_some.mp hb'
      obtain ⟨y, -, h⟩ := obind_eq_some.mp h
      unfold outCSpec at h
      obtain ⟨_, -, hv⟩ := Option.map_eq_some_iff.mp h
      rw [← hv]
      exact verdictOf_le _ _
    exact ⟨(), ht, hb1, (classifyRun_iff hS R hR toks ht b' hb1).mpr hb'⟩

end ZK60.TokenRun
