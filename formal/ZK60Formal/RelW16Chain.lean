/-
D63 lane L21 (2026-11-07), part 1: **sub-protocols of single squeezes with no message, on the code's chain, with states
that read the prover's log** (the shape of a slot's `define` draws and of LogUp's `β, γ, α`).

L13 left the slots' `define` draws to be composed on the transcript (its §5 item 1); L16 left `hRel` and `hLk` as named
hypotheses of `block_knowledge`. Both need a sub-protocol whose rounds are SQUEEZES ONLY (no absorb between them: a
`challenge_fp2_vec(n)` is `n` squeezes, `ExecBlockFS.drawOps`), whose state may read the data EXTRACTED from the
prover's log. With every squeeze its own step (`W1`, as L9's block schedule), no counter premise is needed (L16-2 does
not arise). This file supplies that kind, generically:

* `szSt`, **`szSt_escape`**: **Schwartz–Zippel round by round**. For a function `Φ` of `n` variables of individual degree
  `≤ d`, the state "`Φ` vanishes on every point extending the challenges drawn so far" escapes a doomed reading in one
  coordinate for at most `d` challenge values (a nonzero univariate polynomial of degree `≤ d`); `szSt_nil` (the start
  state: `Φ ≡ 0`), `szSt_full` / `szSt_full_map` (after `n` rounds: `Φ` at the drawn point is `0`);
* `SqX`, `SqX.Rbr`, `sqR`, `sqSub`, **`sqSub_rbr`**: such a sub-protocol (its window `a`, its `n` rounds, its escape count
  `e`, its state reading the log and the header) as one of L8's `CSub`s, round-by-round sound with error
  `e·(⌊2^128/p⌋+1)²/|Dig|` (`rbrWide_of_rbrSound`, the code's `challenge_fp2`);
* `cRd_sq`, `chalTr_sq`, `opTrace_drawOps`: a run of squeezes is read as the rounds, with the run's digests; the trace of
  `challenge_fp2_vec(n)` is `n` squeezes whose `challenge_fp2` values are the vector's;
* `cChain_trace`: the chain of the verifier's operations is their executable trace (`slot_take` with nothing after);
* `allSt_sq_congr`: the schedule at two logs agrees wherever the states agree on their headers;
* **`fs_sq_knowledge`**: the knowledge version of L8's composition for any list of such sub-protocols on the chain of any
  list of verifier operations (a function of the prover's output): the probability that some sub-protocol enters its
  window with a false claim (`¬ St` of its header and no round) and yet every sub-protocol's squeeze run is in place
  and its state holds at its drawn challenges is at most `T·emax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`,
  `T = q + ℓ + 1`, `emax` the largest escape count.

Every statement is for any field `K` with `Fp2`'s reading (`toK`), any list of sub-protocols and any operation list: a
block of any shape (A25). Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.ExtractW16Block

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal
open Finset

/-! ## Schwartz–Zippel, one coordinate per round -/

section SZ

variable {K : Type} [Field K]

/-- **The Schwartz–Zippel state of a reading**: `Φ` vanishes at every point whose first coordinates are the challenges
read so far (the messages are ignored). -/
def szSt {M : Type} {n : ℕ} (Φ : (Fin n → K) → K) (τ : List (M × K)) : Prop :=
  ∀ y : Fin n → K, (∀ (i : Fin n) (h : i.val < τ.length), y i = (τ[i.val]'h).2) → Φ y = 0

/-- Before any challenge, the state is `Φ ≡ 0`. -/
theorem szSt_nil {M : Type} {n : ℕ} (Φ : (Fin n → K) → K) : szSt (M := M) Φ [] ↔ ∀ y, Φ y = 0 := by
  constructor
  · intro h y
    exact h y (fun i hi => absurd hi (Nat.not_lt_zero _))
  · intro h y _
    exact h y

/-- After all `n` challenges, the state is `Φ = 0` at the drawn point. -/
theorem szSt_full {M : Type} {n : ℕ} (Φ : (Fin n → K) → K) (τ : List (M × K)) (hl : τ.length = n) :
    szSt Φ τ ↔ Φ (fun i => (τ[i.val]'(by rw [hl]; exact i.isLt)).2) = 0 := by
  constructor
  · intro h
    exact h _ (fun i hi => rfl)
  · intro h y hy
    have hy' : y = (fun i => (τ[i.val]'(by rw [hl]; exact i.isLt)).2) :=
      funext (fun i => hy i (by rw [hl]; exact i.isLt))
    rw [hy']
    exact h

/-- The same for a reading of a list of challenges with one message each. -/
theorem szSt_full_map {M : Type} {n : ℕ} (Φ : (Fin n → K) → K) (m₀ : M) (cs : List K) (hl : cs.length = n) :
    szSt Φ (cs.map (fun c => (m₀, c))) ↔ Φ (fun i => cs.getD i.val 0) = 0 := by
  rw [szSt_full Φ _ (by rw [List.length_map, hl])]
  have e : (fun i : Fin n => ((cs.map (fun c => (m₀, c)))[i.val]'(by rw [List.length_map, hl]; exact i.isLt)).2)
      = (fun i : Fin n => cs.getD i.val 0) := by
    funext i
    rw [List.getElem_map, List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by rw [hl]; exact i.isLt),
      Option.getD_some]
  rw [e]

variable [Fintype K] [DecidableEq K]

/-- **Schwartz–Zippel, round by round**: from a doomed reading (some extension of the challenges so far has `Φ ≠ 0`),
the next coordinate's challenge keeps `Φ` vanishing on every extension for at most `d` values, `d` the individual
degree. -/
theorem szSt_escape {M : Type} {n d : ℕ} (Φ : (Fin n → K) → K) (hΦ : IndDegLE d Φ) (τ : List (M × K)) (m : M)
    (hτ : τ.length < n) (hns : ¬ szSt Φ τ) : EscapesWithin (fun c => szSt Φ (τ ++ [(m, c)])) d := by
  classical
  have hex : ∃ y0 : Fin n → K, (∀ (i : Fin n) (h : i.val < τ.length), y0 i = (τ[i.val]'h).2) ∧ Φ y0 ≠ 0 := by
    by_contra hc
    apply hns
    intro y hy
    by_contra hne
    exact hc ⟨y, hy, hne⟩
  obtain ⟨y0, hy0, hne⟩ := hex
  obtain ⟨p, hpd, hp⟩ := hΦ ⟨τ.length, hτ⟩ y0
  have hp0 : p ≠ 0 := by
    intro h0
    apply hne
    have h1 := hp (y0 ⟨τ.length, hτ⟩)
    rw [Function.update_eq_self] at h1
    rw [h1, h0, Polynomial.eval_zero]
  refine ⟨p.roots.toFinset, (Multiset.toFinset_card_le _).trans ((Polynomial.card_roots' p).trans hpd), ?_⟩
  intro c hc
  rw [Multiset.mem_toFinset, Polynomial.mem_roots hp0, Polynomial.IsRoot.def, ← hp c]
  apply hc
  intro i hi
  rw [List.length_append, List.length_singleton] at hi
  by_cases hlt : i.val < τ.length
  · have hne' : i ≠ ⟨τ.length, hτ⟩ := fun h => by
      rw [h] at hlt
      exact lt_irrefl _ hlt
    rw [Function.update_of_ne hne', hy0 i hlt, List.getElem_append_left hlt]
  · have heq : i = ⟨τ.length, hτ⟩ := Fin.ext (by simp only; omega)
    subst heq
    rw [Function.update_self, List.getElem_append_right (by simp)]
    simp

end SZ

/-! ## Sub-protocols of single squeezes on the code's chain -/

section Sq

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A sub-protocol of single squeezes with no message**: its window starts at entry `a` (a fixed position of the
schedule), it has `n` rounds of one squeeze each, at most `e` escaping challenges per round, and its state reads a log
(the prover's, for extracted data), the header (everything before the window) and the rounds read so far (each a
message, empty here, and its challenge in `K`). -/
structure SqX (K : Type) (L : ℕ) where
  a : ℕ
  n : ℕ
  e : ℕ
  St : List (QB L × Dig) → List (TItem × Dig) → List (List UInt8 × K) → Prop

/-- Its round condition: from a doomed state, at most `e` challenges escape. -/
def SqX.Rbr (sx : SqX K L) : Prop :=
  ∀ (Lg : List (QB L × Dig)) (hdr : List (TItem × Dig)) (τ : List (List UInt8 × K)) (m : List UInt8),
    τ.length < sx.n → ¬ sx.St Lg hdr τ → EscapesWithin (fun c => sx.St Lg hdr (τ ++ [(m, c)])) sx.e

/-- `n` rounds of one squeeze and no message. -/
def sqR (n : ℕ) : Rounds := ⟨n, fun _ => 1, fun _ => false, fun _ => []⟩

/-- **The sub-protocol as one of L8's `CSub`s** at the log `Lg`: the challenges read by the code's `challenge_fp2`;
never released. -/
noncomputable def sqSub (U : K) (sx : SqX K L) (Lg : List (QB L × Dig)) : CSub Dig where
  a := sx.a
  R := sqR sx.n
  ε := ((sx.e * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
  St hdr τ := sx.St Lg hdr (chalTr (fun dg => (challengeFp2Of dg).toK U) dig0 τ)
  rel _ := False

/-- **Round by round on digests**, with error `e·(⌊2^128/p⌋+1)²/|Dig|`. -/
theorem sqSub_rbr [Fintype K] [DecidableEq K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (sx : SqX K L) (hR : sx.Rbr) (Lg : List (QB L × Dig)) :
    RbrWide (sqSub U sx Lg).R.n (sqSub U sx Lg).R.w (sqSub U sx Lg).St (sqSub U sx Lg).ε := by
  have hS : RbrSound sx.n (fun hdr => sx.St Lg hdr []) (fun hdr τ (_ : Unit) => sx.St Lg hdr τ) (sx.St Lg) sx.e :=
    { start := fun _ h => h
      round := fun hdr τ m hτ hns => hR Lg hdr τ m hτ hns
      final := fun _ _ _ _ hns h => hns h }
  exact rbrWide_of_rbrSound hS (fun dg => (challengeFp2Of dg).toK U) fibC (card_chal_fiber_le U hbij) dig0

/-- **A run of squeezes is read as the rounds**: from a reading between rounds, each squeeze completes one round (its
digest the round's), and after the `n`-th the reading is frozen. -/
theorem cRd_sq (n : ℕ) : ∀ (ks : List UInt64) (ds : List Dig) (ptr : List (List UInt8 × List Dig))
    (rest : List (TItem × Dig)), ptr.length + ks.length = n → ks.length = ds.length →
    ((ks.map TItem.squeeze).zip ds ++ rest).foldl (cRdStep (sqR n) W1) (some (ptr, none, []))
      = some (ptr ++ ds.map (fun d => ([], [d])), none, [])
  | [], [], ptr, rest, hl, _ => by
    simp only [List.map_nil, List.zip_nil_left, List.nil_append, List.append_nil]
    exact foldl_cRdStep_frozen (sqR n) W1 (by simp only [sqR]; simp only [List.length_nil] at hl; omega) rest
  | [], _ :: _, _, _, _, h => by simp at h
  | _ :: _, [], _, _, _, h => by simp at h
  | k :: ks, d :: ds, ptr, rest, hl, h => by
    simp only [List.map_cons, List.zip_cons_cons, List.cons_append, List.foldl_cons]
    have hlt : ptr.length < n := by
      simp only [List.length_cons] at hl
      omega
    have hstep : cRdStep (sqR n) W1 (some (ptr, none, [])) (TItem.squeeze k, d)
        = some (ptr ++ [([], [d])], none, []) := by
      simp [cRdStep, sqR, W1, not_le.mpr hlt]
    rw [hstep, cRd_sq n ks ds (ptr ++ [([], [d])]) rest
      (by simp only [List.length_append, List.length_cons, List.length_nil] at hl ⊢; omega)
      (by simpa using h)]
    simp

/-- The digests of a squeeze run, read through `challenge_fp2`. -/
theorem chalTr_sq (U : K) (ds : List Dig) :
    chalTr (fun dg => (challengeFp2Of dg).toK U) dig0 (ds.map (fun d => (([] : List UInt8), [d])))
      = ds.map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U)) := by
  simp [chalTr, List.map_map, Function.comp_def]

/-- **The trace of `challenge_fp2_vec(n)`**: `n` squeezes, whose `challenge_fp2` values are the vector. -/
theorem opTrace_drawOps (H : HIn → Dig) : ∀ (n : ℕ) (t : Tr), ∃ (ks : List UInt64) (ds : List Dig),
    opTrace H t (Block.drawOps n) = (ks.map TItem.squeeze).zip ds ∧ ks.length = n ∧ ds.length = n
      ∧ ds.map challengeFp2Of = (t.challengeFp2Vec H n).1
  | 0, _ => ⟨[], [], rfl, rfl, rfl, rfl⟩
  | n + 1, t => by
    obtain ⟨ks, ds, h1, h2, h3, h4⟩ := opTrace_drawOps H n (t.squeeze H).2
    refine ⟨t.counter :: ks, (t.squeeze H).1 :: ds, ?_, by simp [h2], by simp [h3], ?_⟩
    · show (TItem.squeeze t.counter, (t.squeeze H).1) :: opTrace H (t.squeeze H).2 (Block.drawOps n) = _
      rw [h1]
      rfl
    · rw [List.map_cons, h4]
      rfl

/-- **The chain of the verifier's operations is their executable trace** (when every hash input fits in `L` bytes and
the operations number at most `ℓ`). -/
theorem cChain_trace (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (ops : List Op) (G : QB L → Dig)
    (hfit : ∀ op ∈ ops, op.len ≤ L) (ℓ : ℕ) (hl : ops.length ≤ ℓ) :
    cChain (chainEncB key domain hs L hL) (fun it => it.1) (stepsOne (ItB L)) G ((liftItems L (opItems 0 ops)).take ℓ)
      = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) ops := by
  have hfitI : ∀ it ∈ opItems 0 ops, it.Ok ∧ it.len ≤ L := opItems_fit L hL64 0 ops hfit
  have hlen : (liftItems L (opItems 0 ops)).length = ops.length := by
    have h := congrArg List.length (liftItems_val L _ hfitI)
    rw [List.length_map, opItems_length] at h
    exact h
  have hTE : (toTE (fun it : ItB L => it.1) : ItB L × Dig → TItem × Dig) = entB := rfl
  unfold cChain
  rw [List.take_of_length_le (by rw [hlen]; exact hl), flatMap_stepsOne, hTE]
  have hst := slot_take key domain hs L hL hL64 ops [] G hfit
  rw [List.append_nil] at hst
  have hcl : (((chainEncB key domain hs L hL).chainFrom G [] (liftItems L (opItems 0 ops))).map entB).length
      = ops.length := by
    rw [List.length_map, ChainEnc.chainFrom_length, List.length_nil, zero_add, hlen]
  rw [← hst.1, List.take_of_length_le (le_of_eq hcl)]

/-- **The schedule at two logs**: the combined states agree wherever each sub-protocol's state agrees on its header. -/
theorem allSt_sq_congr (U : K) (W : UInt64 → ℕ) (sxs : List (SqX K L)) (Lg Lg' : List (QB L × Dig))
    (τ : List (TItem × Dig)) (h : ∀ sx ∈ sxs, sx.St Lg (τ.take sx.a) = sx.St Lg' (τ.take sx.a)) :
    allSt W (sxs.map (fun sx => sqSub U sx Lg)) τ ↔ allSt W (sxs.map (fun sx => sqSub U sx Lg')) τ := by
  have hS : ∀ sx ∈ sxs, subSt W (sqSub U sx Lg) τ ↔ subSt W (sqSub U sx Lg') τ := by
    intro sx hsx
    refine subSt_congr W _ _ τ rfl rfl Iff.rfl ?_
    show (fun τr => sx.St Lg (τ.take sx.a) (chalTr (fun dg => (challengeFp2Of dg).toK U) dig0 τr))
      = (fun τr => sx.St Lg' (τ.take sx.a) (chalTr (fun dg => (challengeFp2Of dg).toK U) dig0 τr))
    rw [h sx hsx]
  constructor
  · intro hall k c hc
    rw [List.getElem?_map] at hc
    obtain ⟨sx, hsx, rfl⟩ := Option.map_eq_some_iff.mp hc
    have h1 := hall k (sqSub U sx Lg) (by rw [List.getElem?_map, hsx]; rfl)
    exact (hS sx (List.mem_of_getElem? hsx)).mp h1
  · intro hall k c hc
    rw [List.getElem?_map] at hc
    obtain ⟨sx, hsx, rfl⟩ := Option.map_eq_some_iff.mp hc
    have h1 := hall k (sqSub U sx Lg') (by rw [List.getElem?_map, hsx]; rfl)
    exact (hS sx (List.mem_of_getElem? hsx)).mpr h1

/-- **A squeeze-run sub-protocol alive on a trace**: when its `n` rounds' entries are squeezes and its state holds at
their challenges, it is alive (read alive, `W1`). -/
theorem sqSub_alive (U : K) (sx : SqX K L) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) (ks : List UInt64)
    (ds : List Dig) (rest : List (TItem × Dig)) (hk : ks.length = sx.n) (hd : ds.length = sx.n)
    (hτ : τ.drop sx.a = (ks.map TItem.squeeze).zip ds ++ rest)
    (hst : sx.St Lg (τ.take sx.a) (ds.map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U)))) :
    subSt W1 (sqSub U sx Lg) τ := by
  right
  left
  refine ⟨tRem_W1 _, ?_⟩
  show liftC (fun τr => sx.St Lg (τ.take sx.a) (chalTr (fun dg => (challengeFp2Of dg).toK U) dig0 τr))
    ((τ.drop sx.a).foldl (cRdStep (sqR sx.n) W1) (some ([], none, [])))
  rw [hτ, cRd_sq sx.n ks ds [] rest (by rw [List.length_nil, zero_add, hk]) (by rw [hk, hd]), List.nil_append,
    liftC_some, chalTr_sq]
  exact hst

/-- The schedule at the prover's log recovered (by replay) from a log `P`. -/
noncomputable def sqAt (U : K) (sxs : List (SqX K L)) {β : Type} (A : OC (QB L) Dig β) (P : List (QB L × Dig)) :
    List (CSub Dig) :=
  sxs.map (fun sx => sqSub U sx (proverLog A P))

/-- **The event on a trace is the composed event**: a sub-protocol entering its window with a false claim, and every
one alive at the end. -/
theorem sq_event (U : K) (sxs : List (SqX K L)) (Lg : List (QB L × Dig)) (τ0 τ : List (TItem × Dig)) (hτ : τ0 = τ)
    (h1 : ∃ sx ∈ sxs, sx.a ≤ τ.length ∧ ¬ sx.St Lg (τ.take sx.a) [])
    (h2 : ∀ sx ∈ sxs, ∃ (ks : List UInt64) (ds : List Dig) (rest : List (TItem × Dig)), ks.length = sx.n
      ∧ ds.length = sx.n ∧ τ.drop sx.a = (ks.map TItem.squeeze).zip ds ++ rest
      ∧ sx.St Lg (τ.take sx.a) (ds.map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U)))) :
    (∃ (k : ℕ) (c : CSub Dig), (sxs.map (fun sx => sqSub U sx Lg))[k]? = some c ∧ c.a ≤ τ0.length
        ∧ tRem W1 (τ0.take c.a) = some 0 ∧ ¬ c.St (τ0.take c.a) [] ∧ ¬ c.rel (τ0.take c.a))
      ∧ allSt W1 (sxs.map (fun sx => sqSub U sx Lg)) τ0 := by
  subst hτ
  obtain ⟨sx0, hsx0, ha0, hst0⟩ := h1
  obtain ⟨k0, hk0⟩ := List.mem_iff_getElem?.mp hsx0
  refine ⟨⟨k0, sqSub U sx0 Lg, by rw [List.getElem?_map, hk0]; rfl, ha0, tRem_W1 _, hst0, id⟩, ?_⟩
  intro k c hc
  rw [List.getElem?_map] at hc
  obtain ⟨sx, hsx, rfl⟩ := Option.map_eq_some_iff.mp hc
  obtain ⟨ks, ds, rest, hk, hd, hτ, hst⟩ := h2 sx (List.mem_of_getElem? hsx)
  exact sqSub_alive U sx Lg _ ks ds rest hk hd hτ hst

/-- **The knowledge version of L8's composition for squeeze-run sub-protocols**, on the chain of ANY list of verifier
operations `ops o` (a function of the prover's output `o`; each hash input within `L` bytes, at most `ℓ` of them).
Each sub-protocol's state may read the prover's log (recovered by replay), frozen once a chain's first `s` entries are
logged (`hstab`), every window after `s`. The probability that some sub-protocol enters its window with a false claim
and yet every one's squeeze run is in place with its state holding at its drawn challenges is at most
`T·emax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`. -/
theorem fs_sq_knowledge [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (sxs : List (SqX K L)) (emax : ℕ)
    (hR : ∀ sx ∈ sxs, sx.Rbr) (he : ∀ sx ∈ sxs, sx.e ≤ emax)
    {α : Type} (ops : α → List Op) (ℓ s : ℕ) (hwin : ∀ sx ∈ sxs, s < sx.a)
    (q : ℕ) (A : OC (QB L) Dig α) (hA : A.Bounded q)
    (hstab : ∀ (G : QB L → Dig) (P P' : List (QB L × Dig)) (τ : List (ItB L × Dig)) (qs : List (QB L)),
      (chainEncB key domain hs L hL).Chain G τ qs → τ.length = s → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' →
      (∀ e ∈ P', e.2 = G e.1) → ∀ sx ∈ sxs, ∀ ext : List (TItem × Dig),
        sx.St (proverLog A P) (τ.map entB ++ ext) = sx.St (proverLog A P') (τ.map entB ++ ext)) :
    prH (fun G : QB L → Dig => (∀ op ∈ ops (A.run G), op.len ≤ L) ∧ (ops (A.run G)).length ≤ ℓ
        ∧ (∃ sx ∈ sxs, sx.a ≤ (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (ops (A.run G))).length
            ∧ ¬ sx.St (A.runLog G).2
              ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (ops (A.run G))).take sx.a) [])
        ∧ ∀ sx ∈ sxs, ∃ (ks : List UInt64) (ds : List Dig) (rest : List (TItem × Dig)), ks.length = sx.n
            ∧ ds.length = sx.n
            ∧ (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (ops (A.run G))).drop sx.a
              = (ks.map TItem.squeeze).zip ds ++ rest
            ∧ sx.St (A.runLog G).2
              ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (ops (A.run G))).take sx.a)
              (ds.map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U))))
      ≤ (((q + ℓ + 1) * emax : ℕ) : ℝ≥0∞) / Fintype.card K * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig := by
  have : Nonempty K := ⟨0⟩
  have hbij := ZK60.Hiding.fp2_bijective hK2 hU seven_not_square
  have hF : Fintype.card K = gP ^ 2 := card_of_pairs gP (Equiv.ofBijective _ hbij)
  let A' : OC (QB L) Dig (List (ItB L)) := A.bind (fun o => .ret (liftItems L (opItems 0 (ops o))))
  have hA' : A'.Bounded q :=
    (hA.bind (fun o => (show (OC.ret (liftItems L (opItems 0 (ops o))) : OC (QB L) Dig (List (ItB L))).Bounded 0
      from trivial))).mono (by simp)
  have hrun : ∀ G, A'.run G = liftItems L (opItems 0 (ops (A.run G))) := fun G => by
    simp only [A', OC.run_bind]
    rfl
  have hlog : ∀ G, (A'.runLog G).2 = (A.runLog G).2 := fun G => by
    simp only [A']
    rw [OC.runLog_bind]
    simp [OC.runLog]
  have hRw : ∀ P, ∀ c ∈ sqAt U sxs A P, RbrWide c.R.n c.R.w c.St c.ε := by
    intro P c hc
    rw [sqAt] at hc
    obtain ⟨sx, hsx, rfl⟩ := List.mem_map.mp hc
    exact sqSub_rbr U hbij sx (hR sx hsx) _
  have hε : ∀ P, ∀ c ∈ sqAt U sxs A P, c.ε ≤ ((emax * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig := by
    intro P c hc
    rw [sqAt] at hc
    obtain ⟨sx, hsx, rfl⟩ := List.mem_map.mp hc
    exact ENNReal.div_le_div_right (Nat.cast_le.mpr (Nat.mul_le_mul_right _ (he sx hsx))) _
  have hframe : ∀ (P : List (QB L × Dig)) (k : ℕ) (c : CSub Dig) (τ : List (TItem × Dig)) (h : TItem)
      (ks : List UInt64) (ds : List Dig), (sqAt U sxs A P)[k]? = some c → tRem W1 τ = some 0 →
      ks.length + 1 = tWd W1 h → ds.length = ks.length + 1 → ¬ subSt W1 c τ → c.rel (τ ++ stE h ks ds) →
        ∃ k' c', k < k' ∧ (sqAt U sxs A P)[k']? = some c' ∧ ¬ subSt W1 c' τ := by
    intro P k c τ h ks ds hc _ _ _ _ hrel
    rw [sqAt, List.getElem?_map] at hc
    obtain ⟨sx, -, rfl⟩ := Option.map_eq_some_iff.mp hc
    exact absurd hrel id
  have hwin' : ∀ P, ∀ c ∈ sqAt U sxs A P, s < c.a := by
    intro P c hc
    rw [sqAt] at hc
    obtain ⟨sx, hsx, rfl⟩ := List.mem_map.mp hc
    exact hwin sx hsx
  have hstab' : ∀ (G : QB L → Dig) (P P' : List (QB L × Dig)) (τ : List (ItB L × Dig)) (qs : List (QB L)),
      (chainEncB key domain hs L hL).Chain G τ qs → τ.length = s → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' →
      (∀ e ∈ P', e.2 = G e.1) → ∀ ext : List (TItem × Dig),
        allSt W1 (sqAt U sxs A P) (τ.map (toTE (fun it : ItB L => it.1)) ++ ext)
          ↔ allSt W1 (sqAt U sxs A P') (τ.map (toTE (fun it : ItB L => it.1)) ++ ext) := by
    intro G P P' τ qs hc hl hq hpre hans ext
    rw [sqAt, sqAt]
    refine allSt_sq_congr U W1 sxs _ _ _ (fun sx hsx => ?_)
    have hlt := hwin sx hsx
    have hτl : (τ.map (toTE (fun it : ItB L => it.1))).length = s := by rw [List.length_map, hl]
    have e : (τ.map (toTE (fun it : ItB L => it.1)) ++ ext).take sx.a
        = τ.map (toTE (fun it : ItB L => it.1)) ++ ext.take (sx.a - s) := by
      rw [List.take_append, List.take_of_length_le (by omega), hτl]
    rw [e]
    exact hstab G P P' τ qs hc hl hq hpre hans sx hsx _
  have hmain := fs_code_chain_sound_sched_log W1 (fun _ => Nat.one_pos) (sqAt U sxs A) _ hRw hε hframe
    (chainEncB key domain hs L hL) (fun it => it.1) (stepsOne (ItB L)) (stepsOne_ok _)
    (fun l => l.take ℓ) ℓ
    (fun l => by
      show ((l.take ℓ).flatMap (stepsOne (ItB L)).items).length ≤ ℓ
      rw [flatMap_stepsOne, List.length_take]
      exact min_le_left _ _) s hwin'
    (fun o => by
      show (((o.take ℓ).take s).flatMap (stepsOne (ItB L)).items).length ≤ s
      rw [flatMap_stepsOne, List.length_take]
      exact min_le_left _ _) hstab' q A' hA'
  refine le_trans (MeasureTheory.measure_mono ?_) (hmain.trans ?_)
  · intro G hG
    rw [Set.mem_ofPred_eq] at hG ⊢
    obtain ⟨hfit, hlen, h1, h2⟩ := hG
    have hfull : proverLog A (((chainEncB key domain hs L hL).stepRun (stepsOne (ItB L))
        (fun l => l.take ℓ) A').runLog G).2 = (A.runLog G).2 := by
      rw [ChainEnc.stepRun, OC.runLog_bind, hlog]
      exact proverLog_runLog A G _
    rw [sqAt, hfull]
    exact sq_event U sxs (A.runLog G).2 _ _
      (by rw [hrun G]; exact cChain_trace key domain hs hL hL64 (ops (A.run G)) G hfit ℓ hlen) h1 h2
  · refine add_le_add (add_le_add ?_ le_rfl) le_rfl
    rw [← mul_div_assoc, ← Nat.cast_mul, ← mul_assoc]
    exact dig_bound_le gP hF _

end Sq

end ZK60.Exec
