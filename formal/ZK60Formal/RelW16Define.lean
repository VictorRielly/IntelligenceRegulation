/-
D63 lane L21 (2026-11-07), part 2: **the slots' `define` draws under Fiat–Shamir, on the block's real schedule, with
statements over the EXTRACTED tables** (L13 §5 item 1; the probabilistic half of `block_knowledge`'s `hRel`).

Each slot's `define` draws `P.draws k` challenges with `challenge_fp2_vec`, i.e. `P.draws k` squeezes with no absorb
between them (`ExecBlockFS.slotPreOps`), at a FIXED position of `verify_core`'s schedule: after the header, the roots'
ten operations and the whole slots before `k` (`defPos`). A slot's relation is a claim about the committed tables
(extracted from the prover's log, cut at the roots' first absorption, as `block_knowledge`'s `cutsOf`) and the earlier
slots' draws (`Hist`, what `define` reads). This file composes ANY such claims, one per slot of a list `ks`:

* `defOff`, `defPos`, `defLen`, `allOps`: the window of slot `k`'s draws and the block's operation count, functions of
  the verifier's shape only; `fullOps_append`, `fullOps_length`, `fullOps_fit`, `def_window`: on the verifier's trace,
  the header of slot `k`'s draws is the trace of the operations before them, and the entries after it start with the
  draws' squeezes;
* `tHistD`, **`tHistD_trace`**: the header reads as what `define` saw (the LogUp challenges and the earlier records'
  draws, `histOf`);
* `defSq`, `defSq_rbr`: slot `k`'s draws as a squeeze-run sub-protocol whose state is Schwartz–Zippel's for a
  polynomial `Φ (cuts) (roots) k (hist)` of the draws, of individual degree `≤ dg k`;
* `DefWin`: the slots accept, some slot `k ∈ ks` has a FALSE start claim `Gd` of the extracted data, and every slot
  `k ∈ ks` has `Φ = 0` at its drawn challenges (what an accepting block's identities give, by the instance's algebra);
* **`block_defines_fs_knowledge`**: for ANY block shape (`BlockParams`, A25), any claims `Gd` and polynomials `Φ` with
  `(Φ ≡ 0) → Gd` and degrees `≤ dmax`, a prover making `q` queries makes `DefWin` hold with probability at most
  `T·dmax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + defLen + 1` (L8's count, finding L16-1).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RelW16Chain

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The windows of the draws -/

section Pos

/-- The operations of `m` whole slots from slot `j`: per slot its draws, `pb-slot`, `c`, `pb-scalar`, two per round and
`pb-term`. -/
def defOff (P : BlockParams) : ℕ → ℕ → ℕ
  | _, 0 => 0
  | j, m + 1 => P.draws j + 4 + 2 * ((slotShape P j).1 + (slotShape P j).2.1) + defOff P (j + 1) m

/-- **The window of slot `k`'s draws**: after the header, the roots' ten operations and the whole slots before `k`. -/
def defPos (P : BlockParams) (hdrLen k : ℕ) : ℕ := hdrLen + 10 + defOff P 0 k

/-- The block's operation count (the header, the roots, every whole slot). -/
def defLen (P : BlockParams) (hdrLen : ℕ) : ℕ := hdrLen + 10 + defOff P 0 P.geom.slots.length

/-- The verifier's operations up to the end of the slot loop. -/
def allOps (P : BlockParams) (out : List Op × Core) : List Op := out.1 ++ rootOps P out.2 ++ fullOps P 0 out.2.slots

theorem rootOps_length (P : BlockParams) (core : Core) : (rootOps P core).length = 10 := rfl

theorem fullOps_append (P : BlockParams) : ∀ (j : ℕ) (a b : List SlotProof),
    fullOps P j (a ++ b) = fullOps P j a ++ fullOps P (j + a.length) b
  | j, [], b => by simp [fullOps]
  | j, sp :: a, b => by
    rw [List.cons_append, fullOps, fullOps, fullOps_append P (j + 1) a b, List.length_cons,
      show j + 1 + a.length = j + (a.length + 1) by omega]
    simp only [List.append_assoc]

theorem fullOps_length (P : BlockParams) : ∀ (j : ℕ) (sps : List SlotProof),
    (∀ i sp, sps[i]? = some sp → sp.rounds.length = (slotShape P (j + i)).1 + (slotShape P (j + i)).2.1) →
    (fullOps P j sps).length = defOff P j sps.length
  | _, [], _ => rfl
  | j, sp :: sps, h => by
    have h0 := h 0 sp rfl
    simp only [Nat.add_zero] at h0
    have ih := fullOps_length P (j + 1) sps (fun i q hq => by
      rw [h (i + 1) q (by simpa using hq), show j + (i + 1) = j + 1 + i by omega])
    rw [fullOps, List.length_append, List.length_append, List.length_append, slotPreOps_length, scOps_length, h0,
      List.length_singleton, ih, List.length_cons, defOff]
    omega

theorem fullOps_fit (P : BlockParams) (L : ℕ) : ∀ (j : ℕ) (sps : List SlotProof),
    (∀ i sp, sps[i]? = some sp → (∀ op ∈ slotPreOps P (j + i) sp, op.len ≤ L) ∧ (∀ op ∈ scOps sp.rounds, op.len ≤ L)
      ∧ (termOp sp).len ≤ L) → ∀ op ∈ fullOps P j sps, op.len ≤ L
  | _, [], _ => fun op hop => by simp [fullOps] at hop
  | j, sp :: sps, h => by
    intro op hop
    obtain ⟨h1, h2, h3⟩ := h 0 sp rfl
    simp only [Nat.add_zero] at h1
    rw [fullOps] at hop
    simp only [List.mem_append, List.mem_singleton] at hop
    rcases hop with ((hop | hop) | hop) | hop
    · exact h1 op hop
    · exact h2 op hop
    · rw [hop]
      exact h3
    · refine fullOps_fit P L (j + 1) sps (fun i q hq => ?_) op hop
      have := h (i + 1) q (by simpa using hq)
      rwa [show j + (i + 1) = j + 1 + i by omega] at this

/-- **Slot `k`'s draws on the verifier's trace**: the header of its window is the trace of the operations before it,
and the entries after it start with the trace of its `challenge_fp2_vec`, run on the transcript the whole slots before
it leave (`slotTr`). -/
theorem def_window (H : HIn → Dig) (P : BlockParams) (core : Core) (hdr : List Op) (t0 : Tr) (k : ℕ)
    (q : SlotProof) (hq : core.slots[k]? = some q)
    (hr : ∀ i q, core.slots[i]? = some q → q.rounds.length = (slotShape P i).1 + (slotShape P i).2.1) :
    (opTrace H t0 (hdr ++ rootOps P core ++ fullOps P 0 core.slots)).take (defPos P hdr.length k)
        = opTrace H t0 (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k))
      ∧ (∃ rest, (opTrace H t0 (hdr ++ rootOps P core ++ fullOps P 0 core.slots)).drop (defPos P hdr.length k)
        = opTrace H (slotTr H P (runOps H t0 (hdr ++ rootOps P core)) 0 core.slots k) (drawOps (P.draws k)) ++ rest)
      ∧ defPos P hdr.length k ≤ (opTrace H t0 (hdr ++ rootOps P core ++ fullOps P 0 core.slots)).length := by
  have hk : k < core.slots.length := (List.getElem?_eq_some_iff.mp hq).1
  have hqk : core.slots[k] = q := (List.getElem?_eq_some_iff.mp hq).2
  have hlenk : (core.slots.take k).length = k := by rw [List.length_take]; omega
  have hdrop : core.slots.drop k = q :: core.slots.drop (k + 1) := by rw [List.drop_eq_getElem_cons hk, hqk]
  obtain ⟨Y, hY⟩ : ∃ Y : List Op, Y = [.absorb labPbSlot (le64 (UInt64.ofNat k)), .squeeze,
      .absorb labPbScalar ([q.scalar].flatMap Fp2.toBytes)] ++ scOps q.rounds ++ [termOp q]
      ++ fullOps P (k + 1) (core.slots.drop (k + 1)) := ⟨_, rfl⟩
  have hfo : fullOps P 0 core.slots = fullOps P 0 (core.slots.take k) ++ (drawOps (P.draws k) ++ Y) := by
    rw [hY]
    conv_lhs => rw [← List.take_append_drop k core.slots]
    rw [fullOps_append, hlenk, Nat.zero_add, hdrop]
    simp only [fullOps, slotPreOps, List.append_assoc]
  obtain ⟨X, hXd⟩ : ∃ X, X = hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k) := ⟨_, rfl⟩
  have hlenX : (opTrace H t0 X).length = defPos P hdr.length k := by
    show _ = hdr.length + 10 + defOff P 0 k
    rw [opTrace_length, hXd, List.length_append, List.length_append, rootOps_length,
      fullOps_length P 0 _ (fun i sp hsp => by
        rw [Nat.zero_add]
        rw [List.getElem?_take] at hsp
        split_ifs at hsp
        exact hr i sp hsp), hlenk]
  have htr : opTrace H t0 (hdr ++ rootOps P core ++ fullOps P 0 core.slots)
      = opTrace H t0 X ++ (opTrace H (runOps H t0 X) (drawOps (P.draws k))
        ++ opTrace H (runOps H (runOps H t0 X) (drawOps (P.draws k))) Y) := by
    rw [hfo, ← List.append_assoc (hdr ++ rootOps P core), ← hXd, opTrace_append, opTrace_append]
  have hst : runOps H t0 X = slotTr H P (runOps H t0 (hdr ++ rootOps P core)) 0 core.slots k := by
    rw [hXd, runOps_append]
    rfl
  refine ⟨?_, ⟨opTrace H (runOps H (runOps H t0 X) (drawOps (P.draws k))) Y, ?_⟩, ?_⟩
  · rw [htr, ← hlenX, List.take_left' rfl, hXd]
  · rw [htr, ← hlenX, List.drop_left' rfl, hst]
  · rw [htr, List.length_append, hlenX]
    exact Nat.le_add_right _ _

end Pos

/-! ## What `define` saw, read off the header -/

section Hist

/-- **The reader of the header of slot `k`'s draws**: the LogUp challenges and the earlier slots' draws (`Hist`). -/
def tHistD (P : BlockParams) (hdrLen k : ℕ) : TRd Hist :=
  TRd.bnd (tRoot hdrLen) fun bga => TRd.bnd (tSlots P 0 k) fun vs => TRd.ret ⟨bga.1, bga.2.1, bga.2.2, vs.map (·.1)⟩

/-- **On the verifier's trace, the header reads as `define`'s history** (`histOf` of the records before `k`). -/
theorem tHistD_trace (H : HIn → Dig) (P : BlockParams) (core : Core) (hdr : List Op) (t0 : Tr) (k : ℕ)
    (hk : k ≤ core.slots.length)
    (hr : ∀ i q, core.slots[i]? = some q → q.rounds.length = (slotShape P i).1 + (slotShape P i).2.1)
    (rs : List SlotRec) (hrs : rs.length = core.slots.length)
    (hv : ∀ i q r, core.slots[i]? = some q → rs[i]? = some r →
      r.draws = (preVals H P (slotTr H P (runOps H t0 (hdr ++ rootOps P core)) 0 core.slots i) i q).1) :
    tHistD P hdr.length k (opTrace H t0 (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k)))
      = some (histOf ((runOps H t0 (hdr ++ rootOpsA P core)).challengeFp2 H).1
          (((runOps H t0 (hdr ++ rootOpsA P core)).challengeFp2 H).2.challengeFp2 H).1
          ((((runOps H t0 (hdr ++ rootOpsA P core)).challengeFp2 H).2.challengeFp2 H).2.challengeFp2 H).1
          (rs.take k), []) := by
  obtain ⟨t3, ht3⟩ : ∃ t3, t3 = runOps H t0 (hdr ++ rootOps P core) := ⟨_, rfl⟩
  have hlenk : (core.slots.take k).length = k := by rw [List.length_take]; omega
  have hsplit : opTrace H t0 (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k))
      = opTrace H t0 (hdr ++ rootOps P core) ++ opTrace H t3 (fullOps P 0 (core.slots.take k)) := by
    rw [ht3, opTrace_append]
  have hslots := tSlots_trace H P (core.slots.take k) 0 t3 []
    (fun i q hq => by
      rw [Nat.zero_add]
      rw [List.getElem?_take] at hq
      split_ifs at hq
      exact hr i q hq)
  rw [hlenk, List.append_nil] at hslots
  have hW : (walk H P t3 0 (core.slots.take k)).map (·.1) = (rs.take k).map SlotRec.draws := by
    apply List.ext_getElem?
    intro i
    rw [List.getElem?_map, List.getElem?_map]
    by_cases hik : i < k
    · obtain ⟨q, hq⟩ : ∃ q, core.slots[i]? = some q := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      obtain ⟨r, hr'⟩ : ∃ r, rs[i]? = some r := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have hq' : (core.slots.take k)[i]? = some q := by rw [List.getElem?_take_of_lt hik, hq]
      rw [walk_getElem?, hq', List.getElem?_take_of_lt hik, hr']
      simp only [Option.map_some, Option.some.injEq]
      rw [slotTr_take H P t3 0 core.slots i k hik.le, Nat.zero_add, hv i q r hq hr', ← ht3]
    · have hwl : (walk H P t3 0 (core.slots.take k)).length = k := by rw [walk_length, hlenk]
      have h1 : (walk H P t3 0 (core.slots.take k)).length ≤ i := by omega
      have h2 : (rs.take k).length ≤ i := by
        rw [List.length_take]
        omega
      rw [List.getElem?_eq_none_iff.mpr h1, List.getElem?_eq_none_iff.mpr h2]
      rfl
  unfold tHistD histOf
  rw [hsplit, TRd.bnd_def, tRoot_trace H P core hdr t0 _]
  dsimp only
  rw [TRd.bnd_def, hslots]
  dsimp only
  rw [TRd.ret_apply, hW]

end Hist

/-! ## The draws as squeeze-run sub-protocols, and the theorem -/

section Def

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **Slot `k`'s draws as a sub-protocol**: its window `defPos`, its `P.draws k` squeezes, and its state Schwartz–Zippel's
for the polynomial `Φ (cuts) (roots) k (hist)` of its challenges, the cuts the log's at the roots the header shows, the
history what the header shows (a header that does not parse is never doomed). -/
def defSq (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : Cuts3 L → RootsO → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (dg : ℕ → ℕ) (k : ℕ) : SqX K L where
  a := defPos P hdrLen k
  n := P.draws k
  e := dg k
  St Lg hdr τ :=
    match tHistD P hdrLen k hdr with
    | some (h, _) => szSt (Φ (cuts3 absOf Lg (rootsAt hdrLen hdr)) (rootsAt hdrLen hdr) k h) τ
    | none => True

variable [Fintype K] [DecidableEq K]

omit [Algebra GF K] in
/-- Its round condition: Schwartz–Zippel's, from the degree. -/
theorem defSq_rbr (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : Cuts3 L → RootsO → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (dg : ℕ → ℕ) (k : ℕ)
    (hdeg : ∀ cu rt h, IndDegLE (dg k) (Φ cu rt k h)) : (defSq P hdrLen absOf Φ dg k).Rbr := by
  intro Lg hdr τ m hτ hns
  simp only [defSq] at hns ⊢
  split at hns
  · exact szSt_escape _ (hdeg _ _ _) τ m hτ hns
  · exact absurd trivial hns

end Def

section Theorem

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The prover wins against the slots' draws**: the slots accept, some slot `k ∈ ks` has a FALSE start claim `Gd` of
the extracted data `cu` (the roots `rt`) and of what `define` saw, and every slot `k ∈ ks` has `Φ = 0` at its drawn
challenges. -/
def DefWin (U : K) (key : Option Dig) (domain : List UInt8) (P : BlockParams) (hdrLen : ℕ) (ks : List ℕ)
    (Gd : Cuts3 L → RootsO → ℕ → Hist → Prop) (Φ : Cuts3 L → RootsO → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K)
    (cu : Cuts3 L) (rt : RootsO) (G : QB L → Dig) (out : List Op × Core) : Prop :=
  ∃ bga rs acc, SlotsAcc key domain P hdrLen G out bga rs acc
    ∧ (∃ k ∈ ks, ¬ Gd cu rt k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)))
    ∧ ∀ k ∈ ks, ∀ r, rs[k]? = some r →
      Φ cu rt k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) (fun i => (r.draws.getD i.val Fp2.zero).toK U) = 0

theorem getD_map_toK (U : K) : ∀ (l : List Fp2) (i : ℕ), (l.map (Fp2.toK U)).getD i 0 = (l.getD i Fp2.zero).toK U
  | [], _ => by simp [Fp2.toK_zero U]
  | _ :: _, 0 => rfl
  | _ :: l, i + 1 => getD_map_toK U l i

/-- **A win against the draws is the composed event** on the verifier's trace (`fs_sq_knowledge`'s premise). -/
theorem defWin_event (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ) (ks : List ℕ)
    (hks : ∀ k ∈ ks, k < P.geom.slots.length) (Gd : Cuts3 L → RootsO → ℕ → Hist → Prop)
    (Φ : Cuts3 L → RootsO → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (dg : ℕ → ℕ)
    (hΦ : ∀ cu rt k h, k ∈ ks → (∀ x, Φ cu rt k h x = 0) → Gd cu rt k h)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L
      ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (out : List Op × Core)
    (hw : DefWin U key domain P hdrLen ks Gd Φ (cuts3 (absOfC (chainEncB key domain hs L hL)) Lg (rootsOf out.2))
      (rootsOf out.2) G out) :
    (∀ op ∈ allOps P out, op.len ≤ L) ∧ (allOps P out).length ≤ defLen P hdrLen
      ∧ (∃ sx ∈ ks.map (defSq P hdrLen (absOfC (chainEncB key domain hs L hL)) Φ dg),
          sx.a ≤ (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (allOps P out)).length
          ∧ ¬ sx.St Lg ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (allOps P out)).take sx.a) [])
      ∧ ∀ sx ∈ ks.map (defSq P hdrLen (absOfC (chainEncB key domain hs L hL)) Φ dg),
          ∃ (ks' : List UInt64) (ds : List Dig) (rest : List (TItem × Dig)), ks'.length = sx.n ∧ ds.length = sx.n
          ∧ (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (allOps P out)).drop sx.a
            = (ks'.map TItem.squeeze).zip ds ++ rest
          ∧ sx.St Lg ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (allOps P out)).take sx.a)
            (ds.map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U))) := by
  obtain ⟨hdr, core⟩ := out
  obtain ⟨bga, rs, acc, ⟨hhl, hhfit, -, hsh, t', hacc⟩, ⟨kf, hkf, hgf⟩, hzero⟩ := hw
  simp only at hhl hhfit hsh hacc hgf hzero
  have hslen : core.slots.length = P.geom.slots.length := hsh.1
  rw [blockSlots_eq] at hacc
  simp only [← runOps_append] at hacc
  split at hacc
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨hbga, hres⟩ := hacc
    subst hres
    subst hbga
    have hshape : ∀ i q, core.slots[i]? = some q → q.rounds.length = (slotShape P i).1 + (slotShape P i).2.1
        ∧ (∀ r ∈ q.rounds, r.length = (slotShape P i).2.2 + 1) ∧ q.terms.length = slotTerms P i := by
      intro i q hq
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs'⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      obtain ⟨h1, h2, h3⟩ := hsh.2.1 i q s tt hq hs' htt
      have e1 : slotShape P i = s := by rw [slotShape, List.getD_eq_getElem?_getD, hs', Option.getD_some]
      have e2 : slotTerms P i = tt := by rw [slotTerms, List.getD_eq_getElem?_getD, htt, Option.getD_some]
      rw [e1, e2]
      exact ⟨h1, h2, h3⟩
    have hround : ∀ i q, core.slots[i]? = some q → q.rounds.length = (slotShape P i).1 + (slotShape P i).2.1 :=
      fun i q hq => (hshape i q hq).1
    have hd1 : ∀ i, i < core.slots.length → 1 ≤ (slotShape P (0 + i)).2.2 := fun i hi => by
      rw [Nat.zero_add]
      exact (hgeom i (by omega)).1
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
    have hfit : ∀ op ∈ allOps P (hdr, core), op.len ≤ L := by
      intro op hop
      simp only [allOps, List.mem_append] at hop
      rcases hop with (hop | hop) | hop
      · exact hhfit op hop
      · exact rootOps_len P core L hL81 op hop
      · refine fullOps_fit P L 0 core.slots (fun i q hq => ?_) op hop
        obtain ⟨-, hrl, htl⟩ := hshape i q hq
        have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
        obtain ⟨-, hLr, hLt⟩ := hgeom i hi
        exact ⟨slotPreOps_len P (0 + i) q L hL81, scOps_len L _ hLr q.rounds hrl, termOp_len q _ L htl hLt⟩
    have hlenOps : (allOps P (hdr, core)).length = defLen P hdrLen := by
      simp only [allOps, defLen, List.length_append, rootOps_length]
      rw [fullOps_length P 0 core.slots (fun i sp hsp => by rw [Nat.zero_add]; exact hround i sp hsp), hslen, hhl]
    have hSt : ∀ k q, core.slots[k]? = some q → ∀ τr,
        (defSq P hdrLen (absOfC (chainEncB key domain hs L hL)) Φ dg k).St Lg
          ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (allOps P (hdr, core))).take
            (defSq P hdrLen (absOfC (chainEncB key domain hs L hL)) Φ dg k).a) τr
        ↔ szSt (Φ (cuts3 (absOfC (chainEncB key domain hs L hL)) Lg (rootsOf core)) (rootsOf core) k
            (histOf ((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)).challengeFp2
              (liftH G)).1
              (((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)).challengeFp2
                (liftH G)).2.challengeFp2 (liftH G)).1
              ((((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)).challengeFp2
                (liftH G)).2.challengeFp2 (liftH G)).2.challengeFp2 (liftH G)).1 (rs.take k))) τr := by
      intro k q hq τr
      have hk : k < core.slots.length := (List.getElem?_eq_some_iff.mp hq).1
      have hw1 := (def_window (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) k q hq hround).1
      rw [hhl] at hw1
      have hhist := tHistD_trace (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) k hk.le hround rs
        (by omega) hv
      rw [hhl] at hhist
      have hroots := rootsAt_trace (liftH G) P core hdr (fullOps P 0 (core.slots.take k))
        (Tr.newKeyed (liftH G) domain key)
      rw [hhl] at hroots
      have e1 : (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (allOps P (hdr, core))).take
          (defSq P hdrLen (absOfC (chainEncB key domain hs L hL)) Φ dg k).a
          = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k)) :=
        hw1
      rw [e1]
      simp only [defSq, hhist, hroots]
    refine ⟨hfit, le_of_eq hlenOps, ?_, ?_⟩
    · have hkf' : kf < core.slots.length := by rw [hslen]; exact hks kf hkf
      obtain ⟨q, hq⟩ : ∃ q, core.slots[kf]? = some q := ⟨_, List.getElem?_eq_getElem hkf'⟩
      refine ⟨defSq P hdrLen (absOfC (chainEncB key domain hs L hL)) Φ dg kf, List.mem_map.mpr ⟨kf, hkf, rfl⟩, ?_, ?_⟩
      · have hw3 := (def_window (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) kf q hq hround).2.2
        rw [hhl] at hw3
        exact hw3
      · rw [hSt kf q hq, szSt_nil]
        intro h0
        exact hgf (hΦ _ _ kf _ hkf h0)
    · intro sx hsx
      obtain ⟨k, hk, rfl⟩ := List.mem_map.mp hsx
      have hk' : k < core.slots.length := by rw [hslen]; exact hks k hk
      obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hk'⟩
      obtain ⟨r, hr⟩ : ∃ r, rs[k]? = some r := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      obtain ⟨rest, hw2⟩ := (def_window (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) k q hq hround).2.1
      rw [hhl] at hw2
      obtain ⟨ks', ds, h1, h2, h3, h4⟩ := opTrace_drawOps (liftH G) (P.draws k)
        (slotTr (liftH G) P (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core)) 0
          core.slots k)
      refine ⟨ks', ds, rest, h2, h3, ?_, ?_⟩
      · show (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ rootOps P core ++ fullOps P 0 core.slots)).drop (defPos P hdrLen k) = _
        rw [hw2, h1]
      · rw [hSt k q hq]
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
        exact hzero k hk r hr
  · cases hacc

omit [Algebra GF K] in
/-- The draws' states are frozen once the header up to the roots is logged (`cutO_stable`). -/
theorem defSq_stab (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (P : BlockParams) (hdrLen : ℕ) (ks : List ℕ)
    (Φ : Cuts3 L → RootsO → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (dg : ℕ → ℕ) {β : Type}
    (A : OC (QB L) Dig β) :
    ∀ (G : QB L → Dig) (P1 P1' : List (QB L × Dig)) (τ : List (ItB L × Dig)) (qs : List (QB L)),
      (chainEncB key domain hs L hL).Chain G τ qs → τ.length = hdrLen + 8 → (∀ y ∈ qs, y ∈ P1.map Prod.fst) →
      P1 <+: P1' → (∀ e ∈ P1', e.2 = G e.1) →
      ∀ sx ∈ ks.map (defSq P hdrLen (absOfC (chainEncB key domain hs L hL)) Φ dg), ∀ ext : List (TItem × Dig),
        sx.St (proverLog A P1) (τ.map entB ++ ext) = sx.St (proverLog A P1') (τ.map entB ++ ext) := by
  intro G P1 P1' τ qs hc hl hq hpre _ sx hsx ext
  obtain ⟨k, -, rfl⟩ := List.mem_map.mp hsx
  have hrt : rootsAt hdrLen (τ.map entB ++ ext) = rootsAt hdrLen (τ.map entB) :=
    rootsAt_append hdrLen _ ext (by rw [List.length_map, hl])
  have hcut : cuts3 (absOfC (chainEncB key domain hs L hL)) (proverLog A P1) (rootsAt hdrLen (τ.map entB))
      = cuts3 (absOfC (chainEncB key domain hs L hL)) (proverLog A P1') (rootsAt hdrLen (τ.map entB)) := by
    unfold cuts3 rootsAt
    simp only
    rw [cutO_stable _ G τ qs hc P1 P1' hq hpre A hdrLen, cutO_stable _ G τ qs hc P1 P1' hq hpre A (hdrLen + 3),
      cutO_stable _ G τ qs hc P1 P1' hq hpre A (hdrLen + 7)]
  simp only [defSq]
  rw [hrt, hcut]

/-- **The slots' draws under Fiat–Shamir, knowledge version** (D63 lane L21; L13 §5 item 1). For ANY block shape `P`,
any slots `ks`, any start claims `Gd` and polynomials `Φ` of the draws over the data extracted from the prover's log
(cut at the roots' first absorption, `cutsOf`) and of what `define` saw, with `(Φ ≡ 0) → Gd` and individual degrees
`≤ dg k ≤ dmax`: the probability that the slots accept, some slot's start claim is false and yet every slot's `Φ`
vanishes at its drawn challenges is at most `T·dmax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`,
`T = q + defLen + 1`. -/
theorem block_defines_fs_knowledge [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (ks : List ℕ) (hks : ∀ k ∈ ks, k < P.geom.slots.length) (Gd : Cuts3 L → RootsO → ℕ → Hist → Prop)
    (Φ : Cuts3 L → RootsO → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (dg : ℕ → ℕ) (dmax : ℕ)
    (hdg : ∀ k ∈ ks, dg k ≤ dmax) (hdeg : ∀ k ∈ ks, ∀ cu rt h, IndDegLE (dg k) (Φ cu rt k h))
    (hΦ : ∀ cu rt k h, k ∈ ks → (∀ x, Φ cu rt k h x = 0) → Gd cu rt k h)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L
      ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => DefWin U key domain P hdrLen ks Gd Φ (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2) G (A.run G))
      ≤ (((q + defLen P hdrLen + 1) * dmax : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + defLen P hdrLen + 1) Dig + collBound (q + defLen P hdrLen + 1 + 1) Dig := by
  have hmain := fs_sq_knowledge U hU hK2 key domain hs hL hL64
    (ks.map (defSq P hdrLen (absOfC (chainEncB key domain hs L hL)) Φ dg)) dmax
    (fun sx hsx => by
      obtain ⟨k, hk, rfl⟩ := List.mem_map.mp hsx
      exact defSq_rbr P hdrLen _ Φ dg k (hdeg k hk))
    (fun sx hsx => by
      obtain ⟨k, hk, rfl⟩ := List.mem_map.mp hsx
      exact hdg k hk)
    (allOps P) (defLen P hdrLen) (hdrLen + 8)
    (fun sx hsx => by
      obtain ⟨k, -, rfl⟩ := List.mem_map.mp hsx
      show hdrLen + 8 < hdrLen + 10 + defOff P 0 k
      omega)
    q A hA (defSq_stab key domain hs hL P hdrLen ks Φ dg A)
  refine le_trans (MeasureTheory.measure_mono ?_) hmain
  intro G hG
  rw [Set.mem_ofPred_eq] at hG ⊢
  exact defWin_event U key domain hs hL hL81 P hdrLen ks hks Gd Φ dg hΦ hgeom hgt G (A.runLog G).2 (A.run G) hG

end Theorem

end ZK60.Exec.Block
