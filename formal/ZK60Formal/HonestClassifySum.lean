/-
D63 Lean lane L25 (2026-11-07), part 1: **the honest sumcheck prover, executable, and its completeness against the
code's verifier** (`zkp-core/src/sumcheck.rs` `prove` / `verify`, L6's `scVerify`).

The prover of a sumcheck in the code (`sumcheck::prove`, and the masked `--zk` arm of `run_slot`, argument.rs:1290-1420)
sends, in round `j`, the `d + 1` values `s_j(0), …, s_j(d)` of the round polynomial, absorbs them under `"sc-round"`
and squeezes the round's challenge, in exactly the verifier's order (the transcript is shared). Here:
* `WProver n`: a strategy of round WORDS (the code's `Fp2` values), the executable twin of `SoundSumcheck.lean`'s
  `Prover`: the first round's words and, for every challenge word, the rest;
* **`scProve`**: the prover's run on the transcript (absorb `"sc-round"`, squeeze, per round): its rounds and the
  transcript after them;
* `WHonest U d n p f`: the words, read in `K` (`toK U`), are the TRUE round polynomial's values of `f` at the nodes
  (`Complete.honestMsg`), canonical and `d + 1` per round, at every canonical challenge;
* `ofK`, **`honestW`**, **`honestW_honest`**: for every `f` such a strategy exists (the code's words are the canonical
  representatives of the field values, `toK` being a bijection on canonical words);
* **`scProve_accepts`**: the list transcript of the honest run against the transcript's own challenges is accepted by
  `FSSumcheck.lean`'s `scAccept` for the TRUE claim `cubeSum f` (`Complete.honestMsg_check`, `interpEval_honestMsg`);
* **`scVerify_honest`**: **the code's executable verifier accepts the honest prover's rounds at EVERY hash function
  and from EVERY transcript**, returns the transcript's challenges and a final value equal to `f` there, and leaves
  the transcript the prover left (`scVerify_accept_iff`, `scVerify_tr`, `scChal_runOps`). A sumcheck contributes
  nothing to the completeness error;
* **`scVerify_honest_masked`**: the same for the masked polynomial `f + c·g` and the claim `S + c·G` (the `--zk`
  arm; `IndDegLE.add_smul`, `cubeSum_add_smul`), for every mask `g` and every `c`;
* `scVerify_honest_exists`: with `honestW`, for every polynomial of individual degree `≤ d` there is an executable
  honest prover the code's verifier accepts.

Every premise is an explicit hypothesis.
-/
import ZK60Formal.ExecSumcheck
import ZK60Formal.CompleteSub

set_option autoImplicit false

namespace ZK60.HonestClassify

open ZK60 ZK60.Exec ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## The executable honest prover -/

/-- **A strategy of round words** (the executable twin of `SoundSumcheck.lean`'s `Prover`): the first round's words
and, for every challenge word, a strategy for the remaining rounds. -/
def WProver : ℕ → Type
  | 0 => PUnit
  | n + 1 => List Fp2 × (Fp2 → WProver n)

section Run

variable (H : HIn → Dig)

/-- **The honest prover's run** (`sumcheck::prove`'s transcript side): per round, the round's words absorbed under
`"sc-round"`, then the challenge squeezed; the next round's words are the strategy's at that challenge. Returns the
rounds and the transcript after them. -/
def scProve : (n : ℕ) → WProver n → Tr → List (List Fp2) × Tr
  | 0, _, t => ([], t)
  | n + 1, p, t =>
    let rt := (t.absorbFp2 H scLabel p.1).challengeFp2 H
    let r := scProve n (p.2 rt.1) rt.2
    (p.1 :: r.1, r.2)

theorem scProve_length : ∀ (n : ℕ) (p : WProver n) (t : Tr), (scProve H n p t).1.length = n
  | 0, _, _ => rfl
  | n + 1, p, t => by
    show ((scProve H n _ _).1).length + 1 = n + 1
    rw [scProve_length n]

/-- **The transcript the verifier's challenges move is the prover's**: on the honest rounds, `scChal` (absorb,
squeeze per round) ends where the prover's run ends. -/
theorem scChal_scProve : ∀ (n : ℕ) (p : WProver n) (t : Tr),
    (scChal H (scProve H n p t).1 t).2 = (scProve H n p t).2
  | 0, _, _ => rfl
  | n + 1, p, t => by
    show (scChal H (scProve H n _ _).1 _).2 = (scProve H n _ _).2
    exact scChal_scProve n _ _

end Run

/-! ## The honest strategy -/

section Honest

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The honest strategy for `f`**: every round's words are canonical, `d + 1` of them, and read in `K` they are the
TRUE round polynomial's values at the nodes (`Complete.honestMsg`), at every canonical challenge (the remaining rounds
are the honest strategy of `f` with its first variable fixed to the challenge). -/
def WHonest (d : ℕ) : (n : ℕ) → WProver n → ((Fin n → K) → K) → Prop
  | 0, _, _ => True
  | n + 1, p, f =>
    p.1.length = d + 1 ∧ (∀ a ∈ p.1, a.Canon) ∧ msgK U d p.1 = Complete.honestMsg d f
      ∧ ∀ r : Fp2, r.Canon → WHonest d n (p.2 r) (fun x => f (Fin.cons (r.toK U) x))

variable (H : HIn → Dig)

/-- The honest rounds are canonical and have `d + 1` words each. -/
theorem whonest_rounds (d : ℕ) : ∀ (n : ℕ) (p : WProver n) (f : (Fin n → K) → K) (t : Tr), WHonest U d n p f →
    ∀ s ∈ (scProve H n p t).1, s.length = d + 1 ∧ ∀ a ∈ s, a.Canon
  | 0, _, _, _, _ => by simp [scProve]
  | n + 1, p, f, t, hp => by
    obtain ⟨hl, hc, -, hrest⟩ := hp
    intro s hs
    have hs' : s ∈ p.1 :: (scProve H n (p.2 ((t.absorbFp2 H scLabel p.1).challengeFp2 H).1)
        ((t.absorbFp2 H scLabel p.1).challengeFp2 H).2).1 := hs
    rcases List.mem_cons.mp hs' with h | h
    · rw [h]
      exact ⟨hl, hc⟩
    · exact whonest_rounds d n _ _ _ (hrest _ (canon_challengeFp2Of _)) s h

/-- **The honest run is accepted by the list verifier for the TRUE claim**: the list transcript of the honest rounds
against the transcript's own challenges passes `scAccept` on the claim `cubeSum f`, for `f` of individual degree
`≤ d < char K`, whatever the hash function. -/
theorem scProve_accepts {d : ℕ} (hd : d < ringChar K) :
    ∀ (n : ℕ) (p : WProver n) (f : (Fin n → K) → K) (t : Tr), IndDegLE d f → WHonest U d n p f →
      scAccept (scTau U d (scProve H n p t).1 (scChal H (scProve H n p t).1 t).1) n f (cubeSum f)
  | 0, _, f, _, _, _ => by
    show scAccept [] 0 f (cubeSum f)
    exact cubeSum_zero f
  | n + 1, p, f, t, hf, hp => by
    obtain ⟨-, -, hmsg, hrest⟩ := hp
    have hr' : ((t.absorbFp2 H scLabel p.1).challengeFp2 H).1.Canon := canon_challengeFp2Of _
    have ih := scProve_accepts hd n (p.2 ((t.absorbFp2 H scLabel p.1).challengeFp2 H).1)
      (fun x => f (Fin.cons (((t.absorbFp2 H scLabel p.1).challengeFp2 H).1.toK U) x))
      ((t.absorbFp2 H scLabel p.1).challengeFp2 H).2 (hf.cons _) (hrest _ hr')
    show msgK U d p.1 0 + msgK U d p.1 1 = cubeSum f ∧
      scAccept (scTau U d (scProve H n (p.2 ((t.absorbFp2 H scLabel p.1).challengeFp2 H).1)
          ((t.absorbFp2 H scLabel p.1).challengeFp2 H).2).1
        (scChal H (scProve H n (p.2 ((t.absorbFp2 H scLabel p.1).challengeFp2 H).1)
          ((t.absorbFp2 H scLabel p.1).challengeFp2 H).2).1 ((t.absorbFp2 H scLabel p.1).challengeFp2 H).2).1) n
        (fun x => f (Fin.cons (((t.absorbFp2 H scLabel p.1).challengeFp2 H).1.toK U) x))
        (interpEval (msgK U d p.1) (((t.absorbFp2 H scLabel p.1).challengeFp2 H).1.toK U))
    refine ⟨?_, ?_⟩
    · rw [hmsg]
      exact Complete.honestMsg_check hd hf
    · rw [hmsg, Complete.interpEval_honestMsg hd hf]
      exact ih

variable (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **The code's sumcheck verifier accepts the honest prover** (completeness of `sumcheck::verify`, executable): for
`f` of individual degree `≤ d` (`1 ≤ d < p`), an honest strategy, and a canonical claimed sum whose value is the TRUE
sum `cubeSum f`, at EVERY hash function and from EVERY transcript `t`: `verify` returns `Ok (fin, rs)`, `rs` the
transcript's own challenges, `fin` equal (in `K`) to `f` at them (the caller's terminal identity), and leaves the
transcript the prover's run left. -/
theorem scVerify_honest {d : ℕ} (hd : 1 ≤ d) (hdp : d < gP) (n : ℕ) (p : WProver n) (f : (Fin n → K) → K)
    (hf : IndDegLE d f) (hp : WHonest U d n p f) (claimed : Fp2) (hc : claimed.Canon) (hcl : claimed.toK U = cubeSum f)
    (t : Tr) :
    ∃ fin, (scVerify H claimed d n (scProve H n p t).1 t).1 = .ok (fin, (scChal H (scProve H n p t).1 t).1)
      ∧ fin.toK U = f (fun i => (((scChal H (scProve H n p t).1 t).1).getD i Fp2.zero).toK U)
      ∧ (scVerify H claimed d n (scProve H n p t).1 t).2 = (scProve H n p t).2 := by
  have hdK : d < ringChar K := by rw [ringChar_eq_gP]; exact hdp
  have hr := whonest_rounds U H d n p f t hp
  obtain ⟨fin, h1, h2⟩ := (scVerify_accept_iff U H hU d n hd hdp claimed hc (scProve H n p t).1
    (fun s hs => (hr s hs).2) t f (scChal H (scProve H n p t).1 t).1).mpr
    ⟨fun s hs => (hr s hs).1, rfl, by rw [hcl]; exact scProve_accepts U H hdK n p f t hf hp⟩
  refine ⟨fin, h1, h2, ?_⟩
  rw [scVerify_tr H d n hd claimed _ t fin _ h1, ← scChal_runOps, scChal_scProve]

/-- **The masked (`--zk`) sumcheck, honest**: the honest prover of `f + c·g` on the claim `S + c·G` (`S = Σ f`,
`G = Σ g`: the code's published scalar for a private slot, argument.rs:1264) is accepted by the code's verifier, for
every mask `g` of individual degree `≤ d` and every `c`, at every hash function. -/
theorem scVerify_honest_masked {d : ℕ} (hd : 1 ≤ d) (hdp : d < gP) (n : ℕ) (f g : (Fin n → K) → K)
    (hf : IndDegLE d f) (hg : IndDegLE d g) (c : K) (p : WProver n) (hp : WHonest U d n p (fun x => f x + c * g x))
    (claimed : Fp2) (hc : claimed.Canon) (hcl : claimed.toK U = cubeSum f + c * cubeSum g) (t : Tr) :
    ∃ fin, (scVerify H claimed d n (scProve H n p t).1 t).1 = .ok (fin, (scChal H (scProve H n p t).1 t).1)
      ∧ fin.toK U = f (fun i => (((scChal H (scProve H n p t).1 t).1).getD i Fp2.zero).toK U)
          + c * g (fun i => (((scChal H (scProve H n p t).1 t).1).getD i Fp2.zero).toK U)
      ∧ (scVerify H claimed d n (scProve H n p t).1 t).2 = (scProve H n p t).2 :=
  scVerify_honest U H hU hd hdp n p _ (hf.add_smul hg c) hp claimed hc (by rw [hcl, cubeSum_add_smul]) t

end Honest

/-! ## The honest strategy exists -/

section Exists

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **The canonical word of a field value** (`toK U` is a bijection from canonical words onto `K` when `fp2 U` is). -/
noncomputable def ofK (z : K) : Fp2 :=
  ⟨Fp.ofGF (Function.surjInv hbij.2 z).1, Fp.ofGF (Function.surjInv hbij.2 z).2⟩

theorem ofK_canon (z : K) : (ofK U hbij z).Canon := ⟨Fp.ofGF_canon _, Fp.ofGF_canon _⟩

theorem toK_ofK (z : K) : (ofK U hbij z).toK U = z := by
  have h := Function.surjInv_eq hbij.2 z
  simp only [ofK, Fp2.toK, Fp.toGF_ofGF]
  exact h

/-- The words of one honest round: the canonical words of the true round polynomial's values at `0, …, d`. -/
noncomputable def honestWords (d : ℕ) {n : ℕ} (f : (Fin (n + 1) → K) → K) : List Fp2 :=
  List.ofFn (fun i : Fin (d + 1) => ofK U hbij (Complete.honestMsg d f i))

theorem honestWords_length (d : ℕ) {n : ℕ} (f : (Fin (n + 1) → K) → K) : (honestWords U hbij d f).length = d + 1 := by
  simp [honestWords]

theorem msgK_honestWords (d : ℕ) {n : ℕ} (f : (Fin (n + 1) → K) → K) :
    msgK U d (honestWords U hbij d f) = Complete.honestMsg d f := by
  funext i
  have e : (honestWords U hbij d f).getD (i : ℕ) Fp2.zero = ofK U hbij (Complete.honestMsg d f i) := by
    unfold honestWords
    rw [List.getD_eq_getElem?_getD, List.getElem?_ofFn]
    split
    · rfl
    · rename_i hn
      exact absurd i.isLt hn
  show ((honestWords U hbij d f).getD (i : ℕ) Fp2.zero).toK U = _
  rw [e]
  exact toK_ofK U hbij _

/-- **The honest strategy of `f`** (the code's `sumcheck::prove` read as words): each round's words are the canonical
words of the true round polynomial's values; at a challenge `r` the rest is the honest strategy of `f(r, ·)`. -/
noncomputable def honestW (d : ℕ) : (n : ℕ) → ((Fin n → K) → K) → WProver n
  | 0, _ => PUnit.unit
  | n + 1, f => (honestWords U hbij d f, fun r => honestW d n (fun x => f (Fin.cons (r.toK U) x)))

theorem honestW_honest (d : ℕ) : ∀ (n : ℕ) (f : (Fin n → K) → K), WHonest U d n (honestW U hbij d n f) f
  | 0, _ => trivial
  | n + 1, f => by
    refine ⟨honestWords_length U hbij d f, fun a ha => ?_, msgK_honestWords U hbij d f, fun r _ => honestW_honest d n _⟩
    have ha' : a ∈ List.ofFn (fun i : Fin (d + 1) => ofK U hbij (Complete.honestMsg d f i)) := ha
    obtain ⟨i, rfl⟩ := List.mem_ofFn.mp ha'
    exact ofK_canon U hbij _

/-- **For every polynomial of individual degree `≤ d` the code's verifier accepts an executable honest prover**, at
every hash function and from every transcript, on the canonical word of its true sum. -/
theorem scVerify_honest_exists (hU : U ^ 2 = algebraMap GF K 7) (H : HIn → Dig) {d : ℕ} (hd : 1 ≤ d) (hdp : d < gP)
    (n : ℕ) (f : (Fin n → K) → K) (hf : IndDegLE d f) (t : Tr) :
    ∃ fin, (scVerify H (ofK U hbij (cubeSum f)) d n (scProve H n (honestW U hbij d n f) t).1 t).1
        = .ok (fin, (scChal H (scProve H n (honestW U hbij d n f) t).1 t).1)
      ∧ fin.toK U = f (fun i => (((scChal H (scProve H n (honestW U hbij d n f) t).1 t).1).getD i Fp2.zero).toK U) := by
  obtain ⟨fin, h1, h2, -⟩ := scVerify_honest U H hU hd hdp n _ f hf (honestW_honest U hbij d n f)
    (ofK U hbij (cubeSum f)) (ofK_canon U hbij _) (toK_ofK U hbij _) t
  exact ⟨fin, h1, h2⟩

end Exists

end ZK60.HonestClassify
