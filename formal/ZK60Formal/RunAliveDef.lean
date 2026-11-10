/-
D63 lane L50 (2026-11-10), part 3: **a block's define draws and its LogUp run are alive at the end of any transcript
that extends the block's verifier trace**, given their states at the drawn challenges (the alive halves of L21's
`defWin_event` and `lkWin_event`, without their false start claims).

* **`ra_def_blk`**: on a block whose slot phase accepted (`SlotsAcc`), slot `k`'s define draw (`defSq`, its window
  `defPos`) is alive at the end of the trace of the block's operations followed by ANY operations, when its polynomial
  `Φ` vanishes at the outcome's drawn challenges (the outcome's history `histOf bga (rs.take k)`, the cuts at the core's
  roots): the run's transcript shows the draws as squeezes from the window (`def_window`, `opTrace_drawOps`), the header
  reads as the outcome's history (`tHistD_trace`) and the roots as the core's (`rootsAt_trace`);
* **`ra_lk_blk`**: LogUp's run (`lkSq`, window `hdrLen + 4`, three squeezes) likewise, when helpers meet LogUp's
  relations at the outcome's `β, γ, α` for the lookups read at the `A` root's cut (`lkSt3`'s last state).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunAliveSl

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

section DefAlive

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A BLOCK'S DEFINE DRAW IS ALIVE AT THE END OF ANY EXTENSION OF ITS TRACE.** When the block's slot phase accepted on
the code's transcript after the header `hdr` (`SlotsAcc`), slot `k`'s define draw (`defSq P hdrLen absOf Φ dg k`) is alive
at the end of the trace of the block's operations followed by any operations `T`, provided its polynomial vanishes at
the outcome's drawn challenges (`hzero`). -/
theorem ra_def_blk (U : K) (key : Option Dig) (domain : List UInt8) (P : BlockParams) (hdrLen : ℕ)
    (absOf : QB L → Option (List UInt8))
    (Φ : Cuts3 L → RootsO → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (dg : ℕ → ℕ)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (hdr : List Op) (core : Core) (bga : Fp2 × Fp2 × Fp2)
    (rs : List SlotRec) (acc : Acc) (hacc : SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc) (T : List Op)
    (k : ℕ) (r : SlotRec) (hr : rs[k]? = some r)
    (hzero : Φ (cuts3 absOf Lg (rootsOf core)) (rootsOf core) k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k))
      (fun i => (r.draws.getD i.val Fp2.zero).toK U) = 0) :
    subSt W1 (sqSub U (defSq P hdrLen absOf Φ dg k) Lg)
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (allOps P (hdr, core) ++ T)) := by
  obtain ⟨hhl, -, -, hsh, t', hbs⟩ := hacc
  simp only at hhl hsh hbs
  have hslen : core.slots.length = P.geom.slots.length := hsh.1
  rw [blockSlots_eq] at hbs
  simp only [← runOps_append] at hbs
  split at hbs
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hbs
    obtain ⟨hbga, hres⟩ := hbs
    subst hres
    subst hbga
    have hround : ∀ i q, core.slots[i]? = some q → q.rounds.length = (slotShape P i).1 + (slotShape P i).2.1 := by
      intro i q hq
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs'⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have := (hsh.2.1 i q s tt hq hs' htt).1
      rw [this, slotShape, List.getD_eq_getElem?_getD, hs', Option.getD_some]
    have hd1 : ∀ i, i < core.slots.length → 1 ≤ (slotShape P (0 + i)).2.2 := fun i hi => by
      rw [Nat.zero_add]
      exact hgeom i (by omega)
    obtain ⟨rs', hrs', hlen, hall⟩ := slotsLoop_ok (liftH G) P _ _ _ core.slots [] 0 {} _ rs acc t' hd1 hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    have hv : ∀ i q r, core.slots[i]? = some q → rs[i]? = some r →
        r.draws = (preVals (liftH G) P (slotTr (liftH G) P (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ rootOps P core)) 0 core.slots i) i q).1 := by
      intro i q r hq hr
      have h1 := congrArg Prod.fst (hall i q r hq hr).1
      rw [Nat.zero_add] at h1
      exact h1
    have hk : k < core.slots.length := by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hr).1
    obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hk⟩
    obtain ⟨hw1, ⟨rest, hw2⟩, hw3⟩ := def_window (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) k q hq
      hround
    rw [hhl] at hw1
    rw [hhl] at hw2
    rw [hhl] at hw3
    have hhist := tHistD_trace (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) k hk.le hround rs
      (by omega) hv
    rw [hhl] at hhist
    have hroots := rootsAt_trace (liftH G) P core hdr (fullOps P 0 (core.slots.take k))
      (Tr.newKeyed (liftH G) domain key)
    rw [hhl] at hroots
    obtain ⟨ks', ds, h1, h2, h3, h4⟩ := opTrace_drawOps (liftH G) (P.draws k)
      (slotTr (liftH G) P (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core)) 0
        core.slots k)
    have hext : opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (allOps P (hdr, core) ++ T)
        = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core ++ fullOps P 0 core.slots)
          ++ opTrace (liftH G) (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ rootOps P core ++ fullOps P 0 core.slots)) T :=
      opTrace_append (liftH G) _ _ _
    rw [hext]
    refine ZK60.ProtocolClassify.ra_sq_end U _ Lg _ ks' ds (rest ++ opTrace (liftH G) (runOps (liftH G)
      (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core ++ fullOps P 0 core.slots)) T) h2 (by rw [h2, h3]) ?_ ?_
    · show (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core ++ fullOps P 0 core.slots)
          ++ _).drop (defPos P hdrLen k) = _
      rw [List.drop_append_of_le_length hw3, hw2, h1, List.append_assoc]
    · show (defSq P hdrLen absOf Φ dg k).St Lg
        ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core ++ fullOps P 0 core.slots)
          ++ _).take (defPos P hdrLen k)) _
      rw [List.take_append_of_le_length hw3, hw1]
      simp only [defSq, hhist, hroots]
      have h4' : ds.map challengeFp2Of = r.draws := by
        rw [hv k q r hq hr]
        exact h4
      have hm : ds.map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U))
          = (r.draws.map (Fp2.toK U)).map (fun c => (([] : List UInt8), c)) := by
        rw [← h4']
        simp only [List.map_map, Function.comp_def]
      have hlenr : (r.draws.map (Fp2.toK U)).length = P.draws k := by
        rw [List.length_map, ← h4', List.length_map, h3]
      rw [hm, szSt_full_map _ _ _ hlenr]
      have hf : (fun i : Fin (P.draws k) => (r.draws.map (Fp2.toK U)).getD i.val 0)
          = (fun i : Fin (P.draws k) => (r.draws.getD i.val Fp2.zero).toK U) :=
        funext (fun i => getD_map_toK U _ _)
      rw [hf]
      exact hzero
  · cases hbs

/-- **A BLOCK'S LOGUP RUN IS ALIVE AT THE END OF ANY EXTENSION OF ITS TRACE.** When the block's slot phase accepted
(`SlotsAcc`), LogUp's run (`lkSq hdrLen absOf Alk T mlk`) is alive at the end of the trace of the block's operations
followed by any operations `T'`, provided some helpers meet LogUp's relations at the outcome's `β, γ, α` for the lookups
and multiplicities read at the `A` root's cut (`hH`). -/
theorem ra_lk_blk [DecidableEq K] {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ] (U : K) (key : Option Dig)
    (domain : List UInt8) (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (hdr : List Op) (core : Core) (bga : Fp2 × Fp2 × Fp2)
    (rs : List SlotRec) (acc : Acc) (hacc : SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc) (T' : List Op)
    (hH : ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutO absOf (some core.aRoot.toList) Lg) l))
      (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutO absOf (some core.aRoot.toList) Lg))
      (bga.2.2.toK U) Hh) :
    subSt W1 (sqSub U (lkSq hdrLen absOf Alk T mlk) Lg)
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (allOps P (hdr, core) ++ T')) := by
  obtain ⟨hhl, -, -, -, t', hbs⟩ := hacc
  simp only at hhl hbs
  have hbga : bga = (((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)).challengeFp2
      (liftH G)).1,
      (((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)).challengeFp2
        (liftH G)).2.challengeFp2 (liftH G)).1,
      ((((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)).challengeFp2
        (liftH G)).2.challengeFp2 (liftH G)).2.challengeFp2 (liftH G)).1) := by
    rw [blockSlots_eq] at hbs
    simp only [← runOps_append] at hbs
    split at hbs
    · simp only [Except.ok.injEq, Prod.mk.injEq] at hbs
      exact hbs.1.symm
    · cases hbs
  obtain ⟨Hh, hHr⟩ := hH
  have hops : allOps P (hdr, core) ++ T' = (hdr ++ rootOpsA P core)
      ++ (drawOps 3 ++ (rootOpsH P core ++ fullOps P 0 core.slots ++ T')) := by
    simp only [allOps, rootOps, List.append_assoc]
    rfl
  have hlA : (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)).length
      = hdrLen + 4 := by
    rw [opTrace_length, List.length_append, hhl]
    rfl
  obtain ⟨ks', ds, h1, h2, h3, h4⟩ := opTrace_drawOps (liftH G) 3
    (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core))
  obtain ⟨d1, d2, d3, rfl⟩ := List.length_eq_three.mp h3
  rw [challengeFp2Vec_three] at h4
  simp only [List.map_cons, List.map_nil] at h4
  obtain ⟨e1, h4⟩ := List.cons.inj h4
  obtain ⟨e2, h4⟩ := List.cons.inj h4
  obtain ⟨e3, -⟩ := List.cons.inj h4
  have hb1 : (challengeFp2Of d1).toK U = bga.1.toK U := by rw [hbga]; exact congrArg (Fp2.toK U) e1
  have hb2 : (challengeFp2Of d2).toK U = bga.2.1.toK U := by rw [hbga]; exact congrArg (Fp2.toK U) e2
  have hb3 : (challengeFp2Of d3).toK U = bga.2.2.toK U := by rw [hbga]; exact congrArg (Fp2.toK U) e3
  have hroot : absAt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)) hdrLen
      = some core.aRoot.toList := by
    rw [← hhl]
    exact absAt_rootsA (liftH G) P core hdr _
  rw [hops, opTrace_append, opTrace_append (liftH G) _ (drawOps 3)]
  refine ZK60.ProtocolClassify.ra_sq_end U _ Lg _ ks' [d1, d2, d3]
    (opTrace (liftH G) (runOps (liftH G) (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
      (hdr ++ rootOpsA P core)) (drawOps 3)) (rootOpsH P core ++ fullOps P 0 core.slots ++ T')) h2 (by simp [h2])
    ?_ ?_
  · show (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core) ++ _).drop (hdrLen + 4) = _
    rw [← hlA, List.drop_left' rfl, h1]
  · show lkSt3 (Alk (cutO absOf (absAt ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ rootOpsA P core) ++ _).take (hdrLen + 4)) hdrLen) Lg)) T
      (mlk (cutO absOf (absAt ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ rootOpsA P core) ++ _).take (hdrLen + 4)) hdrLen) Lg))
      ([d1, d2, d3].map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U)))
    rw [← hlA, List.take_left' rfl, hroot]
    simp only [List.map_cons, List.map_nil, lkSt3]
    rw [hb1, hb2, hb3]
    exact ⟨Hh, hHr⟩

end DefAlive

end ZK60.Exec.Block
