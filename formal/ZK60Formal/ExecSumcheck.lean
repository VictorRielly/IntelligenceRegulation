/-
D63 step L6 (the executable verifier): the GENERIC sumcheck verifier `zkp-core/src/sumcheck.rs::verify`, executable, on
L5's transcript (`ExecTranscript.lean`) and L6's interpolation (`ExecMle.lean`), and proved to be `FSSumcheck.lean`'s
list verifier `scAccept` with the transcript chain's challenges.

What is mirrored (`sumcheck.rs`, read 2026-11-06; nothing there is changed): `verify(claimed_sum, degree, n_rounds,
proof, tr)`
* refuses unless `proof.rounds.len() == n_rounds` (`ScErr.rounds`, the code's message `ScErr.msg`);
* for each round `j` in order: refuses unless `s.len() == degree + 1` (`ScErr.len`); reads `s[0]`, `s[1]` (for
  `degree = 0` a round has one value and `s[1]` is out of bounds: the code panics, `ScErr.panic`; finding L6-1);
  refuses unless the WORD equality `s[0].add(s[1]) == claim` holds (`ScErr.sum`); then `absorb_fp2("sc-round", s)`,
  `r = challenge_fp2()`, `claim = interpolate_eval(s, r)`;
* returns `(claim, challenges)`; on a refusal the transcript keeps the absorbs and squeezes of the rounds before it
  (the corpus records that state too). The terminal check `claim == poly(terminal values)` is the CALLER's.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`), for EVERY hash function `H`, under `toK U` into any
field `K ⊇ GF` with `U² = 7`, for round degree `1 ≤ d < p`, a canonical claimed sum and canonical round values (the
decoder's refusal of non-canonical words, finding L5-2):
* `scAccept_iff`: `scAccept τ n f C` is "`|τ| = n`, every round check, and the final claim equals `f` at the
  challenges" (`scChecks`, `scFinal`);
* `scLoop_ok_iff`, `scExecOk_iff`, `toK_scFinalExec`: the program's run is exactly those checks on the WORDS, and they
  are the field's checks;
* **`scVerify_accept_iff`**: `verify` returns `Ok (fin, rs)` with `fin = f(rs)` (the caller's terminal check, read in
  `K`) EXACTLY WHEN every round has `d + 1` values, `rs` is the transcript's challenge sequence (`scChal`) and
  `scAccept (scTau rounds rs) n f claimed` holds;
* `scVerify_tr`, `scChal_runOps`: an accepting run leaves the transcript `runOps` of `absorb sc-round`, `squeeze` per
  round;
* **`scChal_chain`**: those challenges are `challenge_fp2` of the squeeze digests of `FSChain.lean`'s chain of the
  run's items (L5's `chainEnc`), and (`challengeFp2Of_toGF`) each is `fp2Chal gP (2^128)` of its digest's halves;
* **`scVerify_fs`**: the two together from `new` / `new_tagged` after any header operations: the program accepts
  exactly when `scAccept` holds on the transcript whose challenges are the chain's, the form `fs_sumcheck_chain_sound`
  bounds (what is left to apply it is the per-profile item map, §8.5 of the assembly report).
What the caller must still check, and this file does not: the terminal identity `fin = poly(terminal values)` (here the
hypothesis `fin.toK U = f(rs)`, with `f` the statement's polynomial), that `claimed` is the claim the statement makes,
and that the terminal values are the openings' (the PCS and `M`).
-/
import ZK60Formal.ExecMle
import ZK60Formal.ExecTranscript
import ZK60Formal.FSChainRbr

namespace ZK60.Exec

open ZK60.Circuit (gP GF)
open ZK60.Sound

/-! ## The model side: `scAccept` as checks and a final claim -/

section Model

variable {F : Type} [Field F]

/-- The round checks of a list transcript from the claim `C`. -/
def scChecks {d : ℕ} : List ((Fin (d + 1) → F) × F) → F → Prop
  | [], _ => True
  | (s, r) :: τ, C => s 0 + s 1 = C ∧ scChecks τ (interpEval s r)

/-- The final claim of a list transcript from the claim `C`. -/
def scFinal {d : ℕ} : List ((Fin (d + 1) → F) × F) → F → F
  | [], C => C
  | (s, r) :: τ, _ => scFinal τ (interpEval s r)

/-- **`scAccept` is the round checks plus the terminal check**: exactly `n` rounds, every round check, and the final
claim equal to `f` at the challenge vector. -/
theorem scAccept_iff {d : ℕ} :
    ∀ (τ : List ((Fin (d + 1) → F) × F)) (n : ℕ) (f : (Fin n → F) → F) (C : F),
      scAccept τ n f C ↔ τ.length = n ∧ scChecks τ C ∧ scFinal τ C = f (fun i => (τ.map Prod.snd).getD i 0)
  | [], 0, f, C => by
    simp only [scAccept, List.length_nil, scChecks, scFinal, true_and]
    constructor
    · intro h
      rw [h]
      congr 1
      funext i
      exact i.elim0
    · intro h
      rw [h]
      congr 1
      funext i
      exact i.elim0
  | [], n + 1, f, C => by simp [scAccept]
  | _ :: _, 0, f, C => by simp [scAccept]
  | (s, r) :: τ, n + 1, f, C => by
    simp only [scAccept, List.length_cons, add_left_inj, scChecks, scFinal]
    rw [scAccept_iff τ n (fun x => f (Fin.cons r x)) (interpEval s r)]
    have hv : (Fin.cons r (fun i : Fin n => (τ.map Prod.snd).getD (i : ℕ) 0) : Fin (n + 1) → F)
        = fun i : Fin (n + 1) => ((((s, r) :: τ).map Prod.snd).getD (i : ℕ) 0) := by
      funext i
      refine Fin.cases ?_ (fun k => ?_) i
      · simp
      · simp
    rw [hv]
    tauto

end Model

/-! ## The program -/

/-- `b"sc-round"` (`L6Check.lean` checks it is `ascii "sc-round"`). -/
def scLabel : List UInt8 := [115, 99, 45, 114, 111, 117, 110, 100]

/-- `verify`'s refusals, and the panic of `s[1]` on a one-value round. -/
inductive ScErr
  | rounds (expected got : ℕ)
  | len (j degree got : ℕ)
  | sum (j : ℕ)
  | panic (j : ℕ)
  deriving DecidableEq, Repr

/-- The code's `Err` strings (`format!` of `verify`); a panic has no `Err`. -/
def ScErr.msg : ScErr → String
  | .rounds e g => s!"sumcheck: expected {e} rounds, got {g}"
  | .len j d g => s!"sumcheck round {j}: expected degree {d}, got {g} values"
  | .sum j => s!"sumcheck round {j}: s(0) + s(1) != claim"
  | .panic j => s!"panic: index 1 out of bounds in round {j}"

section Program

variable (H : HIn → Dig)

/-- `verify`'s loop from round `j`, with the running claim and the challenges so far. -/
def scLoop (degree : ℕ) : ℕ → Fp2 → List Fp2 → List (List Fp2) → Tr → Except ScErr (Fp2 × List Fp2) × Tr
  | _, claim, chs, [], t => (.ok (claim, chs), t)
  | j, claim, chs, s :: ss, t =>
    if s.length ≠ degree + 1 then (.error (.len j degree s.length), t)
    else
      match s[0]?, s[1]? with
      | some s0, some s1 =>
        if s0.add s1 ≠ claim then (.error (.sum j), t)
        else
          let rt := (t.absorbFp2 H scLabel s).challengeFp2 H
          scLoop degree (j + 1) (interpolateEval s rt.1) (chs ++ [rt.1]) ss rt.2
      | _, _ => (.error (.panic j), t)

/-- **`sumcheck::verify`**: the verdict and the transcript after the call. -/
def scVerify (claimed : Fp2) (degree nRounds : ℕ) (rounds : List (List Fp2)) (t : Tr) :
    Except ScErr (Fp2 × List Fp2) × Tr :=
  if rounds.length ≠ nRounds then (.error (.rounds nRounds rounds.length), t)
  else scLoop H degree 0 claimed [] rounds t

/-- The transcript's challenges for the rounds (absorb, then squeeze, per round), whatever the checks say. -/
def scChal : List (List Fp2) → Tr → List Fp2 × Tr
  | [], t => ([], t)
  | s :: ss, t =>
    let rt := (t.absorbFp2 H scLabel s).challengeFp2 H
    let rest := scChal ss rt.2
    (rt.1 :: rest.1, rest.2)

/-- The transcript operations of the rounds. -/
def scOps (rounds : List (List Fp2)) : List Op :=
  rounds.flatMap (fun s => [Op.absorb scLabel (s.flatMap Fp2.toBytes), Op.squeeze])

/-- The program's checks on the words: each round has `degree + 1` values and `s[0].add(s[1])` is the running claim. -/
def scExecOk (degree : ℕ) : List (List Fp2) → List Fp2 → Fp2 → Prop
  | [], [], _ => True
  | s :: ss, r :: rs, C =>
    s.length = degree + 1 ∧ (s.getD 0 Fp2.zero).add (s.getD 1 Fp2.zero) = C ∧ scExecOk degree ss rs (interpolateEval s r)
  | _, _, _ => False

/-- The program's final claim. -/
def scFinalExec : List (List Fp2) → List Fp2 → Fp2 → Fp2
  | s :: ss, r :: rs, _ => scFinalExec ss rs (interpolateEval s r)
  | _, _, C => C

theorem scChal_length : ∀ (ss : List (List Fp2)) (t : Tr), (scChal H ss t).1.length = ss.length
  | [], _ => rfl
  | s :: ss, t => by
    simp only [scChal, List.length_cons]
    rw [scChal_length ss]

theorem canon_challengeFp2Of (d : Dig) : (challengeFp2Of d).Canon := ⟨Fp.reduce128_canon _, Fp.reduce128_canon _⟩

theorem scChal_canon : ∀ (ss : List (List Fp2)) (t : Tr), ∀ r ∈ (scChal H ss t).1, r.Canon
  | [], _ => by simp [scChal]
  | s :: ss, t => by
    intro r hr
    simp only [scChal, List.mem_cons] at hr
    rcases hr with h | h
    · rw [h]
      exact canon_challengeFp2Of _
    · exact scChal_canon ss _ r h

theorem scChal_runOps : ∀ (ss : List (List Fp2)) (t : Tr), (scChal H ss t).2 = runOps H t (scOps ss)
  | [], _ => rfl
  | s :: ss, t => by
    simp only [scChal, scOps, List.flatMap_cons, List.cons_append, List.nil_append]
    rw [scChal_runOps ss]
    rfl

theorem getD_zero_some (s : List Fp2) (h : 0 < s.length) : s[0]? = some (s.getD 0 Fp2.zero) :=
  List.getElem?_eq_some_iff.mpr ⟨h, (getD_eq_get s 0 _ h).symm⟩

theorem getD_one_some (s : List Fp2) (h : 1 < s.length) : s[1]? = some (s.getD 1 Fp2.zero) :=
  List.getElem?_eq_some_iff.mpr ⟨h, (getD_eq_get s 1 _ h).symm⟩

/-- **The program's run is the word checks**: `verify`'s loop returns `Ok (fin, rs)` exactly when every round passes
its length and sum checks along the transcript's challenges, `rs` is those challenges and `fin` the final claim. -/
theorem scLoop_ok_iff (degree : ℕ) (hd : 1 ≤ degree) :
    ∀ (ss : List (List Fp2)) (j : ℕ) (claim : Fp2) (chs : List Fp2) (t : Tr) (fin : Fp2) (rs : List Fp2),
      (scLoop H degree j claim chs ss t).1 = .ok (fin, rs) ↔
        scExecOk degree ss (scChal H ss t).1 claim ∧ rs = chs ++ (scChal H ss t).1
          ∧ fin = scFinalExec ss (scChal H ss t).1 claim
  | [], j, claim, chs, t, fin, rs => by
    simp only [scLoop, scChal, scExecOk, scFinalExec, List.append_nil, true_and, Except.ok.injEq, Prod.mk.injEq]
    constructor
    · rintro ⟨h1, h2⟩
      exact ⟨h2.symm, h1.symm⟩
    · rintro ⟨h1, h2⟩
      exact ⟨h2.symm, h1.symm⟩
  | s :: ss, j, claim, chs, t, fin, rs => by
    by_cases hl : s.length = degree + 1
    · have h0 := getD_zero_some s (by omega)
      have h1 := getD_one_some s (by omega)
      by_cases hs : (s.getD 0 Fp2.zero).add (s.getD 1 Fp2.zero) = claim
      · simp only [scLoop, hl, ne_eq, not_true_eq_false, ↓reduceIte, h0, h1, hs]
        rw [scLoop_ok_iff degree hd ss]
        simp only [scChal, scExecOk, scFinalExec, hl, hs, true_and, List.append_assoc, List.singleton_append]
      · simp only [scLoop, hl, ne_eq, not_true_eq_false, ↓reduceIte, h0, h1, hs, not_false_eq_true,
          reduceCtorEq, scChal, scExecOk, true_and, false_and]
    · simp only [scLoop, ne_eq, hl, not_false_eq_true, ↓reduceIte, reduceCtorEq, scChal, scExecOk, false_and]

/-- An accepting run leaves the transcript of its rounds. -/
theorem scLoop_tr (degree : ℕ) (hd : 1 ≤ degree) :
    ∀ (ss : List (List Fp2)) (j : ℕ) (claim : Fp2) (chs : List Fp2) (t : Tr) (fin : Fp2) (rs : List Fp2),
      (scLoop H degree j claim chs ss t).1 = .ok (fin, rs) → (scLoop H degree j claim chs ss t).2 = (scChal H ss t).2
  | [], _, _, _, _, _, _, _ => rfl
  | s :: ss, j, claim, chs, t, fin, rs, h => by
    by_cases hl : s.length = degree + 1
    · have h0 := getD_zero_some s (by omega)
      have h1 := getD_one_some s (by omega)
      by_cases hs : (s.getD 0 Fp2.zero).add (s.getD 1 Fp2.zero) = claim
      · simp only [scLoop, hl, ne_eq, not_true_eq_false, ↓reduceIte, h0, h1, hs] at h ⊢
        simp only [scChal]
        exact scLoop_tr degree hd ss _ _ _ _ _ _ h
      · simp only [scLoop, hl, ne_eq, not_true_eq_false, ↓reduceIte, h0, h1, hs, not_false_eq_true,
          reduceCtorEq] at h
    · simp only [scLoop, ne_eq, hl, not_false_eq_true, ↓reduceIte, reduceCtorEq] at h

end Program

/-! ## The program's checks are the field's -/

section K

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- A round message read in `K`: its values at `X = 0, …, d`. -/
def msgK (d : ℕ) (s : List Fp2) : Fin (d + 1) → K := fun i => (s.getD i Fp2.zero).toK U

/-- **The list transcript of a run**: each round's values and its challenge, read in `K`. -/
def scTau (d : ℕ) (ss : List (List Fp2)) (rs : List Fp2) : List ((Fin (d + 1) → K) × K) :=
  (ss.zip rs).map (fun p => (msgK U d p.1, p.2.toK U))

theorem canon_scFinalExec : ∀ (ss : List (List Fp2)) (rs : List Fp2) (C : Fp2), C.Canon → (scFinalExec ss rs C).Canon
  | [], _, _, h => by
    simp only [scFinalExec]
    exact h
  | _ :: _, [], _, h => by
    simp only [scFinalExec]
    exact h
  | s :: ss, r :: rs, C, _ => by
    simp only [scFinalExec]
    exact canon_scFinalExec ss rs _ (canon_interpolateEval s r)

theorem msgK_one (d : ℕ) (hd : 1 ≤ d) (s : List Fp2) : msgK U d s 1 = (s.getD 1 Fp2.zero).toK U := by
  unfold msgK
  rw [Fin.val_one', Nat.mod_eq_of_lt (by omega)]

/-- **The word checks are the field's checks**, for canonical values and challenges. -/
theorem scExecOk_iff (hU : U ^ 2 = algebraMap GF K 7) (degree : ℕ) (hd : 1 ≤ degree) (hdp : degree < gP) :
    ∀ (ss : List (List Fp2)) (rs : List Fp2) (C : Fp2), C.Canon → (∀ s ∈ ss, ∀ a ∈ s, a.Canon) →
      (∀ r ∈ rs, r.Canon) →
      (scExecOk degree ss rs C ↔
        ss.length = rs.length ∧ (∀ s ∈ ss, s.length = degree + 1) ∧ scChecks (scTau U degree ss rs) (C.toK U))
  | [], [], C, _, _, _ => by simp [scExecOk, scTau, scChecks]
  | [], r :: rs, C, _, _, _ => by simp [scExecOk]
  | s :: ss, [], C, _, _, _ => by simp [scExecOk]
  | s :: ss, r :: rs, C, hC, hss, hrs => by
    have hsc : ∀ a ∈ s, a.Canon := hss s List.mem_cons_self
    have hr : r.Canon := hrs r List.mem_cons_self
    simp only [scExecOk, List.length_cons, add_left_inj, List.forall_mem_cons, scTau, List.zip_cons_cons,
      List.map_cons, scChecks]
    by_cases hl : s.length = degree + 1
    · rw [scExecOk_iff hU degree hd hdp ss rs _ (canon_interpolateEval s r)
        (fun s' hs' => hss s' (List.mem_cons_of_mem _ hs')) (fun r' hr' => hrs r' (List.mem_cons_of_mem _ hr')),
        Fp2.eq_iff_toK U hU (Fp2.canon_add _ _) hC,
        Fp2.toK_add U _ _ (Fp2.canon_getD hsc 0) (Fp2.canon_getD hsc 1),
        toK_interpolateEval U hU degree hdp s hl r hr, msgK_one U degree hd]
      simp only [scTau, hl, true_and]
      constructor
      · rintro ⟨h1, h2, h3, h4⟩
        exact ⟨h2, h3, h1, h4⟩
      · rintro ⟨h2, h3, h1, h4⟩
        exact ⟨h1, h2, h3, h4⟩
    · simp only [hl, false_and, and_false]

/-- **The program's final claim is the list transcript's.** -/
theorem toK_scFinalExec (hU : U ^ 2 = algebraMap GF K 7) (degree : ℕ) (hdp : degree < gP) :
    ∀ (ss : List (List Fp2)) (rs : List Fp2) (C : Fp2), C.Canon → (∀ s ∈ ss, s.length = degree + 1) →
      (∀ r ∈ rs, r.Canon) → (scFinalExec ss rs C).toK U = scFinal (scTau U degree ss rs) (C.toK U)
  | [], _, C, _, _, _ => by simp [scFinalExec, scTau, scFinal]
  | _ :: _, [], C, _, _, _ => by simp [scFinalExec, scTau, scFinal]
  | s :: ss, r :: rs, C, _, hl, hrs => by
    have hr : r.Canon := hrs r List.mem_cons_self
    simp only [scFinalExec, scTau, List.zip_cons_cons, List.map_cons, scFinal]
    rw [toK_scFinalExec hU degree hdp ss rs _ (canon_interpolateEval s r)
      (fun s' hs' => hl s' (List.mem_cons_of_mem _ hs')) (fun r' hr' => hrs r' (List.mem_cons_of_mem _ hr')),
      toK_interpolateEval U hU degree hdp s (hl s List.mem_cons_self) r hr]
    rfl

theorem getD_map_toK : ∀ (l : List Fp2) (i : ℕ), (l.map (Fp2.toK U)).getD i 0 = (l.getD i Fp2.zero).toK U
  | [], i => by simp [Fp2.toK_zero]
  | a :: l, 0 => by simp
  | a :: l, i + 1 => by
    simp only [List.map_cons, List.getD_cons_succ]
    exact getD_map_toK l i

theorem scTau_snd (d : ℕ) (ss : List (List Fp2)) (rs : List Fp2) (h : ss.length = rs.length) :
    (scTau U d ss rs).map Prod.snd = rs.map (Fp2.toK U) := by
  unfold scTau
  rw [List.map_map]
  have : (Prod.snd ∘ fun p : List Fp2 × Fp2 => (msgK U d p.1, p.2.toK U)) = Fp2.toK U ∘ Prod.snd := rfl
  rw [this, ← List.map_map, List.map_snd_zip (by omega)]

theorem scTau_length (d : ℕ) (ss : List (List Fp2)) (rs : List Fp2) :
    (scTau U d ss rs).length = min ss.length rs.length := by
  simp [scTau]

variable (H : HIn → Dig)

/-- **The executable sumcheck verifier is `FSSumcheck.lean`'s `scAccept`.** For round degree `1 ≤ d < p`, a canonical
claimed sum and canonical round values: `verify` returns `Ok (fin, rs)` and the caller's terminal check
`fin = f(rs)` holds (in `K`) EXACTLY WHEN every round has `d + 1` values, `rs` is the transcript's challenge sequence,
and `scAccept` holds on the list transcript of the rounds and those challenges. -/
theorem scVerify_accept_iff (hU : U ^ 2 = algebraMap GF K 7) (d n : ℕ) (hd : 1 ≤ d) (hdp : d < gP) (claimed : Fp2)
    (hc : claimed.Canon) (rounds : List (List Fp2)) (hr : ∀ s ∈ rounds, ∀ a ∈ s, a.Canon) (t : Tr)
    (f : (Fin n → K) → K) (rs : List Fp2) :
    (∃ fin, (scVerify H claimed d n rounds t).1 = .ok (fin, rs) ∧ fin.toK U = f (fun i => (rs.getD i Fp2.zero).toK U))
      ↔ (∀ s ∈ rounds, s.length = d + 1) ∧ rs = (scChal H rounds t).1
        ∧ scAccept (scTau U d rounds rs) n f (claimed.toK U) := by
  have hcl := scChal_length H rounds t
  have hcc := scChal_canon H rounds t
  by_cases hn : rounds.length = n
  · simp only [scVerify, hn, ne_eq, not_true_eq_false, ↓reduceIte]
    constructor
    · rintro ⟨fin, h1, h2⟩
      obtain ⟨hok, hrs, hfin⟩ := (scLoop_ok_iff H d hd rounds 0 claimed [] t fin rs).mp h1
      rw [List.nil_append] at hrs
      subst hrs
      obtain ⟨hlen, hls, hch⟩ := (scExecOk_iff U hU d hd hdp rounds _ claimed hc hr hcc).mp hok
      refine ⟨hls, rfl, (scAccept_iff _ n f _).mpr ⟨?_, hch, ?_⟩⟩
      · rw [scTau_length, ← hlen, min_self, hn]
      · rw [← toK_scFinalExec U hU d hdp rounds _ claimed hc hls hcc, ← hfin, h2, scTau_snd U d rounds _ hlen]
        congr 1
        funext i
        rw [getD_map_toK]
    · rintro ⟨hls, hrs, hacc⟩
      subst hrs
      obtain ⟨_, hch, hfin⟩ := (scAccept_iff _ n f _).mp hacc
      refine ⟨scFinalExec rounds (scChal H rounds t).1 claimed,
        (scLoop_ok_iff H d hd rounds 0 claimed [] t _ _).mpr
          ⟨(scExecOk_iff U hU d hd hdp rounds _ claimed hc hr hcc).mpr ⟨hcl.symm, hls, hch⟩, by simp, rfl⟩, ?_⟩
      rw [toK_scFinalExec U hU d hdp rounds _ claimed hc hls hcc, hfin, scTau_snd U d rounds _ hcl.symm]
      congr 1
      funext i
      rw [getD_map_toK]
  · simp only [scVerify, ne_eq, hn, not_false_eq_true, ↓reduceIte, reduceCtorEq, false_and, exists_false,
      false_iff, not_and]
    intro _ hrs hacc
    have := scAccept_length _ _ _ _ hacc
    rw [scTau_length, hrs, hcl, min_self] at this
    exact hn this

/-- An accepting run leaves the transcript `runOps` of its rounds' operations. -/
theorem scVerify_tr (d n : ℕ) (hd : 1 ≤ d) (claimed : Fp2) (rounds : List (List Fp2)) (t : Tr) (fin : Fp2)
    (rs : List Fp2) (h : (scVerify H claimed d n rounds t).1 = .ok (fin, rs)) :
    (scVerify H claimed d n rounds t).2 = runOps H t (scOps rounds) := by
  by_cases hn : rounds.length = n
  · simp only [scVerify, hn, ne_eq, not_true_eq_false, ↓reduceIte] at h ⊢
    rw [scLoop_tr H d hd rounds 0 claimed [] t fin rs h, scChal_runOps]
  · simp [scVerify, hn] at h

end K

/-! ## The challenges are the transcript chain's -/

/-- The digests of a chain transcript's squeeze entries, in order. -/
def sqDigests (l : List (It × Dig)) : List Dig :=
  l.filterMap (fun e => match e.1.1 with
    | .squeeze _ => some e.2
    | .absorb _ _ => none)

section Chain

variable (H : HIn → Dig)

theorem runOps_key : ∀ (ops : List Op) (t : Tr), (runOps H t ops).key = t.key
  | [], _ => rfl
  | .absorb _ _ :: ops, _ => (runOps_key ops _).trans rfl
  | .squeeze :: ops, _ => (runOps_key ops _).trans rfl

/-- **The challenges of the program are `challenge_fp2` of the chain's squeeze digests**: for every hash function, if
`τ`'s last digest is the transcript's state and `its` are the items of the rounds' operations (the code's counters),
the challenge sequence is `challengeFp2Of` of the squeeze digests of `chainFrom H τ its` after `τ`. -/
theorem scChal_chain (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) :
    ∀ (ss : List (List Fp2)) (t : Tr) (τ : List (It × Dig)) (its : List It), t.key = key →
      (chainEnc key domain hs).lastD H τ = t.state → its.map Subtype.val = opItems t.counter (scOps ss) →
      (scChal H ss t).1
        = (sqDigests (((chainEnc key domain hs).chainFrom H τ its).drop τ.length)).map challengeFp2Of
  | [], t, τ, its, _, _, hits => by
    cases its with
    | nil => simp [scChal, ChainEnc.chainFrom, sqDigests]
    | cons it its => simp [scOps, opItems] at hits
  | s :: ss, t, τ, its, hk, hτ, hits => by
    have hops : scOps (s :: ss) = Op.absorb scLabel (s.flatMap Fp2.toBytes) :: Op.squeeze :: scOps ss := by
      simp [scOps]
    rw [hops] at hits
    match its, hits with
    | [], h => simp [opItems] at h
    | [_], h => simp [opItems] at h
    | it1 :: it2 :: its', hits =>
      simp only [opItems, List.map_cons, List.cons.injEq] at hits
      obtain ⟨h1, h2, h3⟩ := hits
      set C := chainEnc key domain hs
      set d1 := H (C.link (C.lastD H τ) it1)
      set d2 := H (C.link d1 it2)
      have hch : C.chainFrom H τ (it1 :: it2 :: its') = C.chainFrom H ((τ ++ [(it1, d1)]) ++ [(it2, d2)]) its' := by
        simp only [ChainEnc.chainFrom, C.lastD_snoc]
        rfl
      obtain ⟨ext, hext, -⟩ := C.chainFrom_eq_append H its' ((τ ++ [(it1, d1)]) ++ [(it2, d2)])
      have hdrop : (C.chainFrom H τ (it1 :: it2 :: its')).drop τ.length = (it1, d1) :: (it2, d2) :: ext := by
        rw [hch, hext, List.append_assoc, List.append_assoc, List.drop_left' rfl]
        rfl
      have hd1 : d1 = (t.absorbFp2 H scLabel s).state := by
        show H ⟨key, it1.1.msg (C.lastD H τ)⟩ = _
        rw [h1, hτ, ← hk]
        rfl
      have hd2 : d2 = ((t.absorbFp2 H scLabel s).squeeze H).1 := by
        show H ⟨key, it2.1.msg d1⟩ = _
        rw [h2, hd1, ← hk]
        rfl
      have hsq1 : sqDigests ((it1, d1) :: (it2, d2) :: ext) = d2 :: sqDigests ext := by
        simp [sqDigests, h1, h2]
      rw [hdrop, hsq1, List.map_cons]
      simp only [scChal]
      have hrest := scChal_chain key domain hs ss ((t.absorbFp2 H scLabel s).squeeze H).2
        ((τ ++ [(it1, d1)]) ++ [(it2, d2)]) its' hk (by rw [C.lastD_snoc]; exact hd2) (by rw [h3]; rfl)
      rw [hext, List.drop_left' rfl] at hrest
      rw [hd2]
      exact congrArg _ hrest

/-- **The program's sumcheck under Fiat–Shamir, as `FSChainRbr.lean` reads it.** From `new` / `new_tagged` (`key`) of a
domain with the start premise, after any header operations `ops0` (items `its0`), with `its` the items of the rounds'
operations: `verify` accepts with the caller's terminal check EXACTLY WHEN every round has `d + 1` values and
`scAccept` holds on the transcript whose challenges are `challenge_fp2` of the chain's squeeze digests (each the
`fp2Chal gP (2^128)` of its halves, `challengeFp2Of_toGF`). -/
theorem scVerify_fs {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (ops0 : List Op) (its0 : List It) (hits0 : its0.map Subtype.val = opItems 0 ops0)
    (d n : ℕ) (hd : 1 ≤ d) (hdp : d < gP) (claimed : Fp2) (hc : claimed.Canon) (rounds : List (List Fp2))
    (hr : ∀ s ∈ rounds, ∀ a ∈ s, a.Canon) (its : List It)
    (hits : its.map Subtype.val = opItems (runOps H (Tr.newKeyed H domain key) ops0).counter (scOps rounds))
    (f : (Fin n → K) → K) (rs : List Fp2) :
    (∃ fin, (scVerify H claimed d n rounds (runOps H (Tr.newKeyed H domain key) ops0)).1 = .ok (fin, rs)
        ∧ fin.toK U = f (fun i => (rs.getD i Fp2.zero).toK U))
      ↔ (∀ s ∈ rounds, s.length = d + 1)
        ∧ rs = (sqDigests (((chainEnc key domain hs).chainFrom H ((chainEnc key domain hs).chainFrom H [] its0)
            its).drop its0.length)).map challengeFp2Of
        ∧ scAccept (scTau U d rounds rs) n f (claimed.toK U) := by
  have hst := runOps_chain H key domain hs ops0 its0 hits0
  have hkey : (runOps H (Tr.newKeyed H domain key) ops0).key = key := runOps_key H ops0 _
  have hlen : ((chainEnc key domain hs).chainFrom H [] its0).length = its0.length := by
    rw [ChainEnc.chainFrom_length, List.length_nil, zero_add]
  have hchal := scChal_chain H key domain hs rounds (runOps H (Tr.newKeyed H domain key) ops0)
    ((chainEnc key domain hs).chainFrom H [] its0) its hkey hst.symm hits
  rw [hlen] at hchal
  rw [scVerify_accept_iff U H hU d n hd hdp claimed hc rounds hr _ f rs, hchal]

end Chain

end ZK60.Exec
