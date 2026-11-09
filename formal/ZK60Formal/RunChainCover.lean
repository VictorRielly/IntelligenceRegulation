/-
D63 lane L27 (2026-11-07), part 4: **the deterministic covers on the classify run's chain** (deliverable 2): the run's
one cover (`classify_productionReady_joint_target`'s `hcover`) from per-part covers, the blocks' parts reading the
boundary planes `B_k` and `B_{k+1}`, and the transfer of a block's chain events to the run's chain.

* `cChain_prefix`, `entD_of_prefix`, `rdAlive_of_prefix`, **`subSt_of_prefix`**: a block's view of the run (its chain:
  the run's chain up to the block's end, every earlier operation its header) is a PREFIX of the run's chain; a
  sub-protocol that entered its window doomed there entered doomed on the run's chain, and one whose rounds are all read
  there (its reader frozen) and alive there is alive at the end of the run's chain. This is how L20/L21/L22/L23's
  per-block deterministic links (`hexec`, `hsem`, `hcoverR`, `hcoverH`, `hsplit`, stated on a block's chain with its
  header) become statements about the run's chain;
* **`cover3_of_runParts`**: the cover of stage IN-C, the blocks and stage OUT-C from the parts, with NO premise about
  the input endpoint: on acceptance, outside the extraction failure, (alive) every kind's sub-protocols of every part
  alive at the end of the run's chain, and (doom) stage IN-C's conclusion failing, block `k`'s `BlockOn` on the planes
  `B_k`, `B_{k+1}` failing, or stage OUT-C's failing each making some kind's sub-protocol of that part enter its window
  doomed: then `¬ (InOk ∧ BlocksOk ∧ OutOk)` lies in the extraction failure or in some kind's event
  (`KindRun.ev_of_parts`), the kinds taken in any list holding them. Generic in the protocol: this is the form the
  gate with the endpoint discharged separately consumes (lane L26's `classifyProtocolU`, its premise `h3`);
* **`jointCover_of_runParts`**: the run's cover of all four parts, the endpoint's failing also making some kind's
  sub-protocol enter doomed (`hdep`): then `¬ JointOk` lies in the extraction failure or in some kind's event;
* **`block_doom_w16`**, **`block_doom_r13`**: block `k`'s doom premise from the block's own case analysis (L21's
  `block_knowledge_acc_mt`: the openings' claims and `M`'s functionals (`OpenTrue`), the slots' claimed sums, the slot
  relations, the lookups) with `B_k` and `B_{k+1}` the block's extracted input and output planes: `BlockOn` fails only
  if one of the four checks' links fires (L16's `blockSat_of_slots`, L17's `blockSat_of_slots_r13`, L18's
  `blockOn_of_blockSat`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunChainSched
import ZK60Formal.RunExtractClassify
import ZK60Formal.ProtocolClassifyR13
import ZK60Formal.LayoutR13

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)

/-! ## A block's chain is a prefix of the run's chain -/

section Prefix

variable {D : Type}

/-- **The chain of a run's first heads is a prefix of the run's chain** (a block's view: the run's heads up to the
block's end). -/
theorem cChain_prefix {It' Q : Type} (C : ChainEnc It' Q D) (toT : It' → TItem) (S : Steps It') (H : Q → D)
    (hs₁ hs₂ : List It') : cChain C toT S H hs₁ <+: cChain C toT S H (hs₁ ++ hs₂) := by
  unfold cChain
  refine List.IsPrefix.map _ ?_
  rw [List.flatMap_append]
  have h := C.chainFrom_take H (hs₁.flatMap S.items ++ hs₂.flatMap S.items) (hs₁.flatMap S.items).length
    (by rw [List.length_append]; omega)
  rw [List.take_left' rfl] at h
  rw [← h]
  exact List.take_prefix _ _

/-- **Entered doomed on a prefix, entered doomed on the run's chain.** -/
theorem entD_of_prefix (W : UInt64 → ℕ) (c : CSub D) (τb τ : List (TItem × D)) (hp : τb <+: τ)
    (h : EntD W c τb) : EntD W c τ := by
  obtain ⟨ext, rfl⟩ := hp
  exact (entD_append W c τb ext h.1).mpr h

/-- **Read alive and frozen on a prefix, read alive on the run's chain**: once the sub-protocol's `n` rounds are read,
later items do not change its reading. -/
theorem rdAlive_of_prefix (W : UInt64 → ℕ) (c : CSub D) (τb τ : List (TItem × D)) (hp : τb <+: τ)
    (ha : c.a ≤ τb.length)
    (hfz : ∃ ptr pm ds, cRd c.R W (τb.drop c.a) = some (ptr, pm, ds) ∧ c.R.n ≤ ptr.length)
    (h : rdAlive W c τb) : rdAlive W c τ := by
  obtain ⟨ext, rfl⟩ := hp
  obtain ⟨ptr, pm, ds, hrd, hn⟩ := hfz
  unfold rdAlive at h ⊢
  obtain ⟨h1, h2⟩ := h
  have hrd' : cRd c.R W ((τb ++ ext).drop c.a) = some (ptr, pm, ds) := by
    have hfold : cRd c.R W (τb.drop c.a ++ ext) = ext.foldl (cRdStep c.R W) (cRd c.R W (τb.drop c.a)) := by
      unfold cRd
      rw [List.foldl_append]
    rw [List.drop_append_of_le_length ha, hfold, hrd]
    exact foldl_cRdStep_frozen c.R W hn ext
  refine ⟨by rw [List.take_append_of_le_length ha]; exact h1, ?_⟩
  rw [List.take_append_of_le_length ha, hrd']
  rw [hrd] at h2
  exact h2

/-- **Alive and frozen on a prefix (no release), alive at the end of the run's chain.** -/
theorem subSt_of_prefix (W : UInt64 → ℕ) (c : CSub D) (τb τ : List (TItem × D)) (hp : τb <+: τ)
    (ha : c.a ≤ τb.length)
    (hfz : ∃ ptr pm ds, cRd c.R W (τb.drop c.a) = some (ptr, pm, ds) ∧ c.R.n ≤ ptr.length)
    (hnorel : ∀ τ', ¬ c.rel τ') (h : subSt W c τb) : subSt W c τ := by
  unfold subSt at h ⊢
  rcases h with h1 | h1 | h1
  · exact absurd h1 (not_lt.mpr ha)
  · exact Or.inr (Or.inl (rdAlive_of_prefix W c τb τ hp ha hfz h1))
  · exact absurd h1 (hnorel _)

/-- **A part alive on its block's chain is alive on the run's chain** (`halive` from a block's view): every
sub-protocol of the part has its window and all its rounds inside the prefix, is never released, and is alive there. -/
theorem allSt_of_prefix (W : UInt64 → ℕ) (cs : List (CSub D)) (τb τ : List (TItem × D)) (hp : τb <+: τ)
    (h : ∀ c ∈ cs, c.a ≤ τb.length
      ∧ (∃ ptr pm ds, cRd c.R W (τb.drop c.a) = some (ptr, pm, ds) ∧ c.R.n ≤ ptr.length)
      ∧ (∀ τ', ¬ c.rel τ') ∧ subSt W c τb) : allSt W cs τ :=
  (allSt_iff_mem W cs τ).mpr (fun c hc =>
    subSt_of_prefix W c τb τ hp (h c hc).1 (h c hc).2.1 (h c hc).2.2.1 (h c hc).2.2.2)

/-- **A part's doom on its block's chain is a doom on the run's chain.** -/
theorem exists_entD_of_prefix (W : UInt64 → ℕ) (cs : List (CSub D)) (τb τ : List (TItem × D)) (hp : τb <+: τ)
    (h : ∃ c ∈ cs, EntD W c τb) : ∃ c ∈ cs, EntD W c τ := by
  obtain ⟨c, hc, he⟩ := h
  exact ⟨c, hc, entD_of_prefix W c τb τ hp he⟩

end Prefix

/-! ## The run's cover from the parts -/

section Cover

variable {S : BlockShape} {Lq : ℕ} {Coins : Type}

/-- **The cover of stage IN-C, the blocks and stage OUT-C from per-part covers, without the endpoint** (D63 lane
L27). The run's parts: stage IN-C is part `0`, block `k` part `k + 1`, stage OUT-C part `L + 1` (D12a). On an accepted
receipt outside the extraction failure `Ex`: (`halive`) every kind's sub-protocols of every part are alive at the end
of the run's chain; (`hdin`, `hdblk`, `hdout`) if stage IN-C's conclusion, block `k`'s `BlockOn` on the extracted planes
`B_k` and `B_{k+1}`, or stage OUT-C's conclusion for the statement's verdict fails, some kind's sub-protocol of that
part entered its window doomed on the run's chain. Then an accepted receipt on which one of the three conclusions fails
lies in `Ex` or in the event of one of the kinds, read in any list `Ls` that holds them (`hsub`: the run's kinds may
sit beside others, such as the endpoint's own). No premise mentions the input endpoint, and the protocol is any
`Protocol` on the classify model. -/
theorem cover3_of_runParts (R : ClassifyRunPublic S) (P : Protocol (QB Lq) Dig Coins (classifyModel S R))
    (E : List (QB Lq × Dig) → P.Stmt → P.Receipt → RunExt S P.Salt)
    (tr : (QB Lq → Dig) → P.Stmt × P.Receipt → List (TItem × Dig))
    (Ks : List (KindRun tr)) (hnp : ∀ K ∈ Ks, K.np = R.Ps.length + 2)
    (Ls : List (FirstKind Lq (P.Stmt × P.Receipt))) (hsub : ∀ K ∈ Ks, K.toFirstKind ∈ Ls)
    (Ex : OC (QB Lq) Dig (P.Stmt × P.Receipt) → (QB Lq → Dig) → Prop)
    (halive : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ∀ K ∈ Ks, ∀ i, i < R.Ps.length + 2 → allSt K.RC.W (K.cs i (A.runLog G).2) (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ Ks, ∃ c ∈ K.cs 0 (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K ∈ Ks, ∃ c ∈ K.cs (k + 1) (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ Ks, ∃ c ∈ K.cs (R.Ps.length + 1) (A.runLog G).2, EntD K.RC.W c (tr G (A.run G))) :
    ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
          ∧ BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
          ∧ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) →
        Ex A G ∨ ∃ K ∈ Ls, K.Ev A G := by
  intro A G hv hbad
  by_cases hx : Ex A G
  · exact Or.inl hx
  · right
    have hev : ∀ K ∈ Ks, ∀ i, i < R.Ps.length + 2 → (∃ c ∈ K.cs i (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
        → ∃ K' ∈ Ls, K'.Ev A G := by
      intro K hK i hi hc
      refine ⟨K.toFirstKind, hsub K hK, K.ev_of_parts A G ⟨i, by rw [hnp K hK]; exact hi, hc⟩
        (fun j hj => halive A G hv hx K hK j (by rw [← hnp K hK]; exact hj))⟩
    by_cases hin : InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
    · by_cases hblk : BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
      · have hout : ¬ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) :=
          fun h => hbad ⟨hin, hblk, h⟩
        obtain ⟨K, hK, hc⟩ := hdout A G hv hx hout
        exact hev K hK _ (by omega) hc
      · unfold BlocksOk at hblk
        simp only [not_forall] at hblk
        obtain ⟨k, hk, hk'⟩ := hblk
        obtain ⟨K, hK, hc⟩ := hdblk A G k hk hv hx hk'
        exact hev K hK _ (by omega) hc
    · obtain ⟨K, hK, hc⟩ := hdin A G hv hx hin
      exact hev K hK 0 (by omega) hc

/-- **The classify run's ONE cover from per-part covers** (D63 lane L27). The run's parts: stage IN-C is part `0`,
block `k` part `k + 1`, stage OUT-C part `L + 1` (D12a). On an accepted receipt outside the extraction failure `Ex`:
(`halive`) every kind's sub-protocols of every part are alive at the end of the run's chain; (`hdin`, `hdblk`, `hdout`,
`hdep`) if stage IN-C's conclusion, block `k`'s `BlockOn` on the extracted planes `B_k` and `B_{k+1}`, stage OUT-C's
conclusion for the statement's verdict, or the input endpoint's opening fails, some kind's sub-protocol of that part
(of some part, for the endpoint) entered its window doomed on the run's chain. Then `¬ JointOk` on an accepted receipt
lies in `Ex` or in some kind's event: `classify_productionReady_joint_target`'s `hcover`. (Named `jointCover_of_parts`
until 2026-11-09; renamed because lane L26's `ProtocolClassifyU.lean` declares that name in this namespace, L27-6.) -/
theorem jointCover_of_runParts (R : ClassifyRunPublic S) (P : Protocol (QB Lq) Dig Coins (classifyModel S R))
    (E : List (QB Lq × Dig) → P.Stmt → P.Receipt → RunExt S P.Salt)
    (tr : (QB Lq → Dig) → P.Stmt × P.Receipt → List (TItem × Dig))
    (Ks : List (KindRun tr)) (hnp : ∀ K ∈ Ks, K.np = R.Ps.length + 2)
    (Ex : OC (QB Lq) Dig (P.Stmt × P.Receipt) → (QB Lq → Dig) → Prop)
    (halive : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ∀ K ∈ Ks, ∀ i, i < R.Ps.length + 2 → allSt K.RC.W (K.cs i (A.runLog G).2) (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ Ks, ∃ c ∈ K.cs 0 (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K ∈ Ks, ∃ c ∈ K.cs (k + 1) (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ Ks, ∃ c ∈ K.cs (R.Ps.length + 1) (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
    (hdep : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ EpOk P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ Ks, ∃ i, i < R.Ps.length + 2 ∧ ∃ c ∈ K.cs i (A.runLog G).2, EntD K.RC.W c (tr G (A.run G))) :
    ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ JointOk R P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
        Ex A G ∨ ∃ K ∈ Ks.map KindRun.toFirstKind, K.Ev A G := by
  intro A G hv hbad
  by_cases hx : Ex A G
  · exact Or.inl hx
  · right
    have hev : ∀ K ∈ Ks, ∀ i, i < R.Ps.length + 2 → (∃ c ∈ K.cs i (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
        → ∃ K' ∈ Ks.map KindRun.toFirstKind, K'.Ev A G := by
      intro K hK i hi hc
      refine ⟨K.toFirstKind, List.mem_map_of_mem hK, K.ev_of_parts A G ⟨i, by rw [hnp K hK]; exact hi, hc⟩
        (fun j hj => halive A G hv hx K hK j (by rw [← hnp K hK]; exact hj))⟩
    unfold JointOk at hbad
    by_cases hin : InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
    · by_cases hblk : BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
      · by_cases hout : OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
        · have hep : ¬ EpOk P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) :=
            fun h => hbad ⟨hin, hblk, hout, h⟩
          obtain ⟨K, hK, i, hi, hc⟩ := hdep A G hv hx hep
          exact hev K hK i hi hc
        · obtain ⟨K, hK, hc⟩ := hdout A G hv hx hout
          exact hev K hK _ (by omega) hc
      · unfold BlocksOk at hblk
        simp only [not_forall] at hblk
        obtain ⟨k, hk, hk'⟩ := hblk
        obtain ⟨K, hK, hc⟩ := hdblk A G k hk hv hx hk'
        exact hev K hK _ (by omega) hc
    · obtain ⟨K, hK, hc⟩ := hdin A G hv hx hin
      exact hev K hK 0 (by omega) hc

end Cover

/-! ## A block's doom from its own case analysis, on the boundary planes -/

section BlockDoom

variable {S : BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **Block `k`'s doom premise at W16R2 from the block's own case analysis** (L21's `block_knowledge_acc_mt`, on the run's
chain): block `k` reads boundary `k`'s plane `Xin` and boundary `k + 1`'s `Xout` as its extracted input and output planes
(`hin`, `hout`: the run's extractor's planes are the block's). If the openings' and `M`'s claims (`Op`, L21's `OpenTrue`)
fail, or they hold and the slots' claimed sums (`Cl`) fail, or both hold and the slot relations fail, or all three hold
and the lookups fail, each case's link gives the doom (`Doom`: some kind's sub-protocol of block `k` entered its window
doomed on the run's chain). Then `BlockOn` failing gives the doom. -/
theorem block_doom_w16 (Pb : BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf)
    (B : ZK60.Layout.W16Pub S Pb Lay) (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams)
    (hW : ZK60.Layout.W16Widths S fams) (h24 : S.h24 = true) (xt : ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (Xin Xout : S.Pos → GF) (hin : Xin = fun p => xt.X (Lay.dPos p)) (hout : Xout = fun p => xt.X2 (Lay.dPos p))
    {Op Cl Doom : Prop} (h1 : ¬ Op → Doom) (h2 : Op → ¬ Cl → Doom)
    (h3 : Op → Cl → ¬ ZK60.Layout.W16Rels S Pb Lay B xt → Doom)
    (h4 : Op → Cl → ZK60.Layout.W16Rels S Pb Lay B xt → ¬ ZK60.Layout.W16Lookups S Pb Lay B xt fams → Doom) :
    ¬ BlockOn Pb Xin Xout → Doom := by
  intro hno
  by_contra hD
  have hop : Op := Classical.byContradiction fun h => hD (h1 h)
  have hcl : Cl := Classical.byContradiction fun h => hD (h2 hop h)
  have hrel : ZK60.Layout.W16Rels S Pb Lay B xt := Classical.byContradiction fun h => hD (h3 hop hcl h)
  have hlk : ZK60.Layout.W16Lookups S Pb Lay B xt fams := Classical.byContradiction fun h => hD (h4 hop hcl hrel h)
  apply hno
  rw [hin, hout]
  exact blockOn_of_blockSat Pb _ _ _ (ZK60.Layout.blockSat_of_slots Pb Lay B xt fams hF hW h24 hrel hlk)

/-- **Block `k`'s doom premise at R13 (the app's profile)**: the same with L17's R13 relations and lookups
(`blockSat_of_slots_r13`). -/
theorem block_doom_r13 (Pb : BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf)
    (B : ZK60.Layout.W16Pub S Pb Lay) {ls : ℕ} (xt : ZK60.Layout.R13.R13Data Ct Cw Cg Cj Cd Cf ls)
    (hWr : ZK60.Layout.R13.R13Windows S ls) (h24 : S.h24 = true)
    (Xin Xout : S.Pos → GF) (hin : Xin = fun p => xt.X (Lay.dPos p)) (hout : Xout = fun p => xt.X2 (Lay.dPos p))
    {Op Cl Doom : Prop} (h1 : ¬ Op → Doom) (h2 : Op → ¬ Cl → Doom)
    (h3 : Op → Cl → ¬ ZK60.Layout.R13.R13Rels S Pb Lay B xt → Doom)
    (h4 : Op → Cl → ZK60.Layout.R13.R13Rels S Pb Lay B xt → ¬ ZK60.Layout.R13.R13Lookups S Pb Lay B xt → Doom) :
    ¬ BlockOn Pb Xin Xout → Doom := by
  intro hno
  by_contra hD
  have hop : Op := Classical.byContradiction fun h => hD (h1 h)
  have hcl : Cl := Classical.byContradiction fun h => hD (h2 hop h)
  have hrel : ZK60.Layout.R13.R13Rels S Pb Lay B xt := Classical.byContradiction fun h => hD (h3 hop hcl h)
  have hlk : ZK60.Layout.R13.R13Lookups S Pb Lay B xt := Classical.byContradiction fun h => hD (h4 hop hcl hrel h)
  apply hno
  rw [hin, hout]
  exact blockOn_of_blockSat Pb _ _ _ (ZK60.Layout.R13.blockSat_of_slots_r13 Pb Lay B xt hWr h24 hrel hlk)

end BlockDoom

end ZK60.ProtocolClassify
