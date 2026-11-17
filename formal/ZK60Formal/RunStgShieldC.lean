/-
D63 lane L63 (2026-11-16), part 15: **the repair of finding L63-5: stage IN-C's slot polynomial at each slot's own IO
width** (`stgFRC`, `stgFstIC`) **and its terminal theorem** (`stgFR_termAtC`, the twin of L57's `stgFR_termAt`).
Written by `results/zk60_lean_l63_20261116/l63_mk_c.py` (the theorem's proof is L57's, copied with its three
width-dependent steps changed).

The code builds every IN-C claim at its commitment role's row width (`build_claim(sched.row_log[p.cm], …)`,
token_io.rs:1128; `row_log = [lt, lt, tier.ep_log_n, sh.endpoint_log_n]`, stage_in_c.rs:54), which L29's `IncV.slots`
models as each slot at `atLog P (incElog s)`. L57's `stgFstI` reads every slot at L15's one width. Here, beside it:

* `StageV.ssh_scl_ah`: a slot's `A` and `H` claims at width `e` are among its claims at `P`'s width;
* **`stgFRC`**, **`stgFstIC`**: the slot polynomial with slot `k`'s tables read at `atLog P (elog k)`;
* **`StgTrueAtC`**: L57's `StgTrueAt` with the claims part split: the `A`, `H` claims of the reading's accumulator
  (the same at both widths, `ssh_inc_claims_ah`), and each slot's IO claims AT THE CODE'S WIDTH (`slotClaimList` at
  `atLog (Pof ch) (elog k)`: the claims the code's openings check);
* **`stgFR_termAtC`**: `StgTrueAtC` gives `StgTermAtV` for `stgFRC`;
* `StgClaimsIOS`, **`ssh_trueAtC_of_split`**: the per-slot IO claims part alone, and `StgTrueAtC` from the reader, the
  `A`/`H` claims, the per-slot IO claims and `M`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldInAHRun

set_option autoImplicit false

namespace ZK60.Exec.StageV

open ZK60.Exec ZK60.Exec.Block

/-- **A slot's `A` and `H` claims at IO width `e` are among its claims at `P`'s width** (the IO width does not enter
them). -/
theorem ssh_scl_ah (P : BlockParams) (e : ℕ) (rho es terms : List Fp2) :
    ∀ (tabs : List Tab) (k : ℕ) (q : Block.Cm × Block.ZClaim), q ∈ slotClaimList (atLog P e) rho es terms tabs k →
      (q.1 = .a ∨ q.1 = .h) → q ∈ slotClaimList P rho es terms tabs k
  | [], _, _, h, _ => h
  | .priv p :: ts, k, q, h, hc => by
    rcases List.mem_cons.mp h with rfl | h
    · refine List.mem_cons.mpr (Or.inl ?_)
      have hp : p.cm = .a ∨ p.cm = .h := hc
      congr 1
      unfold buildClaim
      rcases hp with hp | hp <;> simp only [hp, rowLog]
    · exact List.mem_cons_of_mem _ (ssh_scl_ah P e rho es terms ts (k + 1) q h hc)
  | .eq _ _ :: ts, k, q, h, hc => ssh_scl_ah P e rho es terms ts k q h hc
  | .pub _ :: ts, k, q, h, hc => ssh_scl_ah P e rho es terms ts k q h hc

end ZK60.Exec.StageV

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

section Defs

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  {L : ℕ}

/-- **THE STAGE SLOT POLYNOMIAL AT EACH SLOT'S OWN IO WIDTH** (`stgFR` with slot `k`'s tables read at
`atLog (Pv v ch) (elogv v k)`). -/
noncomputable def stgFRC (P0 : Block.BlockParams) (Pv : StgVw L → List Fp2 → Block.BlockParams)
    (elogv : StgVw L → ℕ → ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (csv : StgVw L → Block.Cm → Block.ZClaim → K)
    (Rv : StgVw L → ℕ → ℕ → K) : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K :=
  fun v k sn x => stgPolyT U hbij (StageV.atLog (Pv v sn.1) (elogv v k)) (csv v) k (bgaOf sn.1, sn.2) x
    + ((sn.2.getD k ([], Fp2.zero, [])).2.1).toK U * maskPoly (Rv v) k (stgN P0 k) (Block.slotShape P0 k).2.2 x

variable (tag : MTag) (h64 : 64 ≤ L)

/-- **THE REAL `FstI`, REPAIRED** (finding L63-5): `stgFstI` with slot `k`'s IO commitment read at the code's width
`incElog` (the input endpoint's at INC-00, `B_in`'s at INC-01), as L29's `IncV.slots` and the code do. -/
noncomputable def stgFstIC (P0 : Block.BlockParams) (Win : List (TItem × Dig) → StageV.IncV) (n0 hdrLen m : ℕ)
    (lc h Q e rA rH S : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) :
    StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K :=
  stgFRC U hbij P0 (fun v ch => (Win (v.2.take n0)).bp (StageV.incCtx (Win (v.2.take n0)).pub ch))
    (fun v k => StageV.incElog (Win (v.2.take n0)).pub (Win (v.2.take n0)).geo.bLogN k)
    (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + m) csIO)
    (stgRv U tag h64 S (hdrLen + 3))

end Defs

section TrueC

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **L57's `StgTrueAt` with the claims at the code's widths**: at every reading and slot window, the reader reads the
reading's schedule; the reading's `A` and `H` claims are true; slot `k`'s IO claims, built at the code's width
`atLog (Pof ch) (elogv · k)`, are true; `M`'s functionals are true. -/
def StgTrueAtC (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (Pv : StgVw L → List Fp2 → Block.BlockParams) (elogv : StgVw L → ℕ → ℕ)
    (csv : StgVw L → Block.Cm → Block.ZClaim → K) (msv : StgVw L → List (ℕ × List Fp2) → K)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    ∀ acc t', StageFS.stageSlots (liftH G) (Pof ch) m bgaOf core
        (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t') →
    ∀ k q, core.slots[k]? = some q →
      Pv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q))) ch = Pof ch
      ∧ (∀ z ∈ acc.claims.a, csv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q))) .a z = z.value.toK U)
      ∧ (∀ z ∈ acc.claims.h, csv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q))) .h z = z.value.toK U)
      ∧ (∀ r df, rs[k]? = some r →
          (Pof ch).define k (Block.histOf (bgaOf ch).1 (bgaOf ch).2.1 (bgaOf ch).2.2 (rs.take k)) r.draws = .ok df →
          ∀ q' ∈ Block.slotClaimList (StageV.atLog (Pof ch) (elogv (stgVw absOf Lg (opTrace (liftH G)
              (Tr.newKeyed (liftH G) domain key) (hdr ++ StageFS.stageRootOps (Pof ch) core m
                ++ Block.fullOps (Pof ch) 0 (core.slots.take k) ++ Block.slotPreOps (Pof ch) k q))) k))
              r.rho r.es q.terms df.tabs 0,
            (q'.1 = .inp ∨ q'.1 = .out) →
            csv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
              (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
                ++ Block.slotPreOps (Pof ch) k q))) q'.1 q'.2 = q'.2.value.toK U)
      ∧ Block.MTrue U (msv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q)))) acc.fs

end TrueC

section Real

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  {L : ℕ}

/-- **THE REPAIRED POLYNOMIAL MEETS THE TERMINAL IDENTITIES AT EVERY READING** (`StgTermAtV` for `stgFRC`, from
`StgTrueAtC`; L57's proof with the table side read at slot `k`'s own IO width). -/
theorem stgFR_termAtC (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (P0 : Block.BlockParams) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (Pv : StgVw L → List Fp2 → Block.BlockParams) (elogv : StgVw L → ℕ → ℕ)
    (csv : StgVw L → Block.Cm → Block.ZClaim → K)
    (msv : StgVw L → List (ℕ × List Fp2) → K) (Rv : StgVw L → ℕ → ℕ → K) (Wd : ℕ)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hP : ∀ ch, StgSame P0 (Pof ch))
    (hd : ∀ ch k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (hN : ∀ k, k < P0.geom.slots.length → 0 < stgN P0 k ∧ stgN P0 k * (Block.slotShape P0 k).2.2 + 2 ≤ Wd)
    (hpolyC : ∀ ch k hist dr df, (Pof ch).define k hist dr = .ok df → ∀ vs, (df.poly vs).Canon)
    (hcs : ∀ v (cm : Block.Cm) (z : Block.ZClaim) (a : Fp2), csv v cm { z with value := a } = csv v cm z)
    (hlin0 : ∀ v, Block.MLin U (msv v) (Rv v) Wd)
    (htrue : StgTrueAtC U key domain Pof m hdrLen bgaOf absOf Pv elogv csv msv G Lg τ) :
    StgTermAtV U key domain P0 Pof m hdrLen bgaOf absOf (stgFRC U hbij P0 Pv elogv bgaOf csv Rv) G Lg τ := by
  intro hdr core ch rs hrd k q r hq hr
  obtain ⟨-, -, hcan, hsh, ⟨acc, t', hacc⟩, -, -, -⟩ := id hrd
  obtain ⟨hPv, hclA, hclH, hclIO, hm⟩ := htrue hdr core ch rs hrd acc t' hacc k q hq
  have hlin := hlin0 (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
    (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
      ++ Block.slotPreOps (Pof ch) k q)))
  have hslen : core.slots.length = (Pof ch).geom.slots.length := hsh.1
  have hk : k < core.slots.length := (List.getElem?_eq_some_iff.mp hq).1
  have hkP : k < (Pof ch).geom.slots.length := by rw [← hslen]; exact hk
  have hk0 : k < P0.geom.slots.length := by rw [(hP ch).2]; exact hkP
  rw [StageFS.stageSlots_eq] at hacc
  split at hacc
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨hch, hres⟩ := hacc
    subst hres
    rw [hch] at hloop
    obtain ⟨-, -, rs', hrs', -, hall⟩ := Block.slotsLoop_terminal (liftH G) (Pof ch) _ _ _ core.slots [] 0 {} _ rs
      acc t' hloop
    simp only [List.nil_append] at hrs'
    subst rs'
    obtain ⟨rs2, hrs2, -, hall2⟩ := Block.slotsLoop_ok (liftH G) (Pof ch) _ _ _ core.slots [] 0 {} _ rs acc t'
      (fun i hi => by
        rw [Nat.zero_add]
        exact hd ch i (by rw [← hslen]; exact hi)) hloop
    simp only [List.nil_append] at hrs2
    subst rs2
    obtain ⟨df, vals, rhoFull, hdf, hc0, hcc, -, hrho, hes, hvals, hev, hclk⟩ := hall k q r hq hr
    obtain ⟨-, -, ⟨df', -, hcl'⟩, hsv⟩ := hall2 k q r hq hr
    simp only [Nat.zero_add, List.nil_append] at hdf hrho hes hev hsv hclk hcl'
    have hqc : Block.SlotCanon q := hcan.1 q (List.mem_of_getElem? hq)
    have hclc : r.claimed.Canon := Block.hostedSum_canon _ q.scalar _ _ hqc.1 hcl'
    have hfinc : r.fin.Canon := Block.scVerify_fin_canon (liftH G) r.claimed hclc _ _ (hd ch k hkP) q.rounds _ r.fin
      (r.rho ++ r.es) hsv
    have hrf : rhoFull = r.rho ++ r.es := by rw [hrho, hes, List.take_append_drop]
    unfold scVerify at hsv
    split at hsv
    · simp at hsv
    · rename_i hlen'
      obtain ⟨-, hrs3, -⟩ := (scLoop_ok_iff (liftH G) _ (hd ch k hkP) q.rounds 0 r.claimed [] _ r.fin
        (r.rho ++ r.es)).mp hsv
      rw [List.nil_append] at hrs3
      have hNk : stgN P0 k = (Block.slotShape (Pof ch) k).1 + (Block.slotShape (Pof ch) k).2.1 := by
        rw [stg_stgN (hP ch)]
        rfl
      have hrl : rhoFull.length = stgN P0 k := by
        rw [hrf, hrs3, scChal_length, hNk]
        exact not_not.mp hlen'
      have hrc : ∀ x ∈ rhoFull, x.Canon := by
        rw [hrf, hrs3]
        exact scChal_canon (liftH G) _ _
      have htr : ∀ q' ∈ Block.slotClaimList (StageV.atLog (Pof ch) (elogv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
              ++ Block.slotPreOps (Pof ch) k q))) k)) r.rho r.es q.terms
          df.tabs 0, csv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
              ++ Block.slotPreOps (Pof ch) k q))) q'.1 q'.2 = q'.2.value.toK U := by
        intro q' hq'
        obtain ⟨c1, z1⟩ := q'
        have hdfk : (Pof ch).define k (Block.histOf (bgaOf ch).1 (bgaOf ch).2.1 (bgaOf ch).2.2 (rs.take k))
            r.draws = .ok df := hdf
        cases c1 with
        | a => exact hclA z1 (hclk (Block.Cm.a, z1) (StageV.ssh_scl_ah (Pof ch) _ r.rho r.es q.terms df.tabs 0 _ hq' (Or.inl rfl)))
        | h => exact hclH z1 (hclk (Block.Cm.h, z1) (StageV.ssh_scl_ah (Pof ch) _ r.rho r.es q.terms df.tabs 0 _ hq' (Or.inr rfl)))
        | inp => exact hclIO r df hr hdfk _ hq' (Or.inl rfl)
        | out => exact hclIO r df hr hdfk _ hq' (Or.inr rfl)
      have hpoly := stgPolyT_eval U hbij hU (StageV.atLog (Pof ch) (elogv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
              ++ Block.slotPreOps (Pof ch) k q))) k)) (csv (stgVw absOf Lg (opTrace (liftH G)
        (Tr.newKeyed (liftH G) domain key) (hdr ++ StageFS.stageRootOps (Pof ch) core m
          ++ Block.fullOps (Pof ch) 0 (core.slots.take k) ++ Block.slotPreOps (Pof ch) k q)))) (hcs _) (bgaOf ch) rs k r q
        df vals rhoFull hr hdf hrc hqc hrho hes hvals htr (stgN P0 k) hrl
      have hmk := hm _ hev
      simp only at hmk
      have hl := hlin [(k, Cfs.evalWeights rhoFull (Block.slotShape (Pof ch) k).2.2)]
      obtain ⟨hN0, hNW⟩ := hN k hk0
      have hd0 : (Block.slotShape P0 k).2.2 = (Block.slotShape (Pof ch) k).2.2 := by rw [stg_slotShape (hP ch)]
      have hmask : maskPoly (Rv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
              ++ Block.slotPreOps (Pof ch) k q)))) k (stgN P0 k) (Block.slotShape P0 k).2.2
            (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U)
          = ((r.fin.sub (df.poly vals)).mul r.c.inv).toK U := by
        rw [← hmk, hl]
        show _ = Block.mdot U _ Wd (k, Cfs.evalWeights rhoFull (Block.slotShape (Pof ch) k).2.2) + 0
        rw [add_zero, ← hd0, maskPoly_point U hU hbij _ Wd k (stgN P0 k) _ hN0 rhoFull hrl hNW, hrf]
      show r.fin.toK U = stgPolyT U hbij (StageV.atLog (Pv _ ch) (elogv _ k)) (csv _) k (bgaOf ch, ((rs.take (k + 1)).map
          (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes)))) _
        + ((((rs.take (k + 1)).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))).getD k
          ([], Fp2.zero, [])).2.1).toK U * maskPoly (Rv _) k (stgN P0 k) (Block.slotShape P0 k).2.2 _
      rw [hPv]
      have hc : (((rs.take (k + 1)).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))).getD k
          ([], Fp2.zero, [])).2.1 = r.c := Block.seenOf_c (bgaOf ch) rs k r hr
      rw [hc, hmask]
      have hp' : stgPolyT U hbij (StageV.atLog (Pof ch) (elogv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
              ++ Block.slotPreOps (Pof ch) k q))) k)) (csv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
              ++ Block.slotPreOps (Pof ch) k q)))) k (bgaOf ch, ((rs.take (k + 1)).map
            (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))))
            (fun i : Fin (stgN P0 k) => ((r.rho ++ r.es).getD i Fp2.zero).toK U) = (df.poly vals).toK U := hpoly
      rw [hp']
      exact Block.fin_identity U hU r.fin (df.poly vals) r.c hfinc (hpolyC ch k _ _ df hdf vals) hcc hc0
  · cases hacc

end Real

section Split

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The corrected IO claims part** (the premise that replaces L57's unmeetable one): at every reading and slot window,
slot `k`'s IO claims built at the code's width are true of the data. -/
def StgClaimsIOS (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8)) (elogv : StgVw L → ℕ → ℕ)
    (csv : StgVw L → Block.Cm → Block.ZClaim → K) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    ∀ k q, core.slots[k]? = some q →
      ∀ r df, rs[k]? = some r →
        (Pof ch).define k (Block.histOf (bgaOf ch).1 (bgaOf ch).2.1 (bgaOf ch).2.2 (rs.take k)) r.draws = .ok df →
        ∀ q' ∈ Block.slotClaimList (StageV.atLog (Pof ch) (elogv (stgVw absOf Lg (opTrace (liftH G)
            (Tr.newKeyed (liftH G) domain key) (hdr ++ StageFS.stageRootOps (Pof ch) core m
              ++ Block.fullOps (Pof ch) 0 (core.slots.take k) ++ Block.slotPreOps (Pof ch) k q))) k))
            r.rho r.es q.terms df.tabs 0,
          (q'.1 = .inp ∨ q'.1 = .out) →
          csv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
              ++ Block.slotPreOps (Pof ch) k q))) q'.1 q'.2 = q'.2.value.toK U

/-- **`StgTrueAtC` from its parts**: the reader, the `A`/`H` claims, the corrected IO claims and `M`. -/
theorem ssh_trueAtC_of_split (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (Pv : StgVw L → List Fp2 → Block.BlockParams) (elogv : StgVw L → ℕ → ℕ)
    (csv : StgVw L → Block.Cm → Block.ZClaim → K) (msv : StgVw L → List (ℕ × List Fp2) → K) (G : QB L → Dig)
    (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hR : StgReadAt key domain Pof m hdrLen bgaOf absOf Pv G Lg τ)
    (hAH : StgClaimsAH U key domain Pof m hdrLen bgaOf absOf csv G Lg τ)
    (hIO : StgClaimsIOS U key domain Pof m hdrLen bgaOf absOf elogv csv G Lg τ)
    (hM : StgMAt U key domain Pof m hdrLen bgaOf absOf msv G Lg τ) :
    StgTrueAtC U key domain Pof m hdrLen bgaOf absOf Pv elogv csv msv G Lg τ := by
  intro hdr core ch rs hrd acc t' hacc k q hq
  obtain ⟨hA, hH⟩ := hAH hdr core ch rs hrd acc t' hacc k q hq
  exact ⟨hR hdr core ch rs hrd k q hq, hA, hH, hIO hdr core ch rs hrd k q hq,
    fun mf hmf => hM hdr core ch rs hrd acc t' hacc k q hq mf (List.mem_append_left _ hmf)⟩

end Split

end ZK60.ProtocolClassify
