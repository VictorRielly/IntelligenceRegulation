/-
D63 lane L44 (2026-11-10), part 4: **`SC_FZC`'s named identity at the W16R2 rung** (lane L36's `FormAt` at host `18`),
with its hosted matmuls `SC_GMM` (slot 11) and `SC_UMM` (slot 12), by lane L41's `formAt_tzc` pattern on the shared tools
of `BlockHostBase.lean`.

* `tabsF`, **`slot18_eq`**, **`slot11_eq`**, **`slot12_eq`**: the three slots of L35's program at the rung, as explicit
  tables, IR and hosted list (by evaluation);
* `restF`, `valsF`: `SC_FZC`'s value list at a cube point from position `3` on (the nine `Dom::F` planes, the four LogUp
  helpers, the `fact` helper, the group column, the gate `supp(F)`), and the same list without the draws;
* **`xcFzc`**: the batch's entries past the product clause: entry `1` the ACT tuple's relation `fzcAct`, entries
  `2 … 5` LogUp's four helper relations (`lkRels`), read without the draws; **`pwFzc`**: the nine pad planes
  `(1 − supp(F))·plane_j`;
* **`fzc_vals`**: the value list the IR reads at a cube point with the zero extension;
* **`fzc_irEval`**, **`fzc_cube`**: the IR is L13's host terms; the slot's cube sum is `Σ_b hostPoly(…)(b)`;
* **`fzc_rel0`**, **`fzc_gh0`**, **`fzc_gh1`**: the gated product clause and the two gated requantization hosts ARE
  `W16Rels`' `relCl 18 0`, `relGh 18 0`, `relGh 18 1` of the extracted planes (constants from `RungS`);
* **`fzc_batch`**: the host's batch over the algebra data's tables IS the IR's zero-check sum (LogUp, ACT, pad, clause);
* **`gmm_sum`**, **`umm_sum`**: the hosted matmuls' cube sums are the multilinear extensions of `relMm 18 0`,
  `relMm 18 1` at their claim points (the folded weights `PubW16.wg`, `PubW16.wu`);
* **`formAt_fzc`**: lane L36's `FormAt` at host `18`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockHostBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Fzc

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched SlotPoly segAt)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.W16R2 (segLn segOff segSum shRungW16)
open ZK60.Exec.Slot.Build (Cst cstW hostTerms gV gV_some L16 reqV batchV fzcIr FzcR FzcK fzcClauses fzcAct
  fzcIr_eval padSem logupSem LkD mmIr mmIr_eval)
open ZK60.Exec.Slot.Compose (fzcIr_map mmIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## The three slots at the rung -/

/-- The draws `off … off + n − 1` of slot `s`, as expressions. -/
def drR (s off n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr s (off + i)

theorem drR_length (s off n : ℕ) : (drR s off n).length = n := by simp [drR]

theorem drR_getD (ev : Sym → Fp2) (s off n a : ℕ) (ha : a < n) :
    ((drR s off n).map ev).getD a Fp2.zero = ev (.dr s (off + a)) := by
  unfold drR
  rw [List.map_map, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range ha]
  rfl

theorem getD_app {α : Type} (l l' : List α) (d : α) (n : ℕ) (h : n < l.length) :
    (l ++ l').getD n d = l.getD n d := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_append_left h]

theorem getD_app_right {α : Type} (l l' : List α) (d : α) (n : ℕ) (h : l.length ≤ n) :
    (l ++ l').getD n d = l'.getD (n - l.length) d := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_append_right h]

/-- An `H` table on its own `15` coordinates. -/
def hT (re im m : ℕ) : TabS := .priv ⟨.h, [(re, false), (im, true)], 15, DefW16.rhoC 0 15, m, 0⟩

theorem hT_eval (ev : Sym → Fp2) (pub : ℕ → List Fp2) (re im m : ℕ) :
    TabS.eval ev pub (hT re im m) = .priv ⟨.h, [(re, Fp2.one), (im, fp2U)], 15, rhoAll 15, m, 0⟩ :=
  hTab_eval ev pub re im 15 m

/-- `SC_FZC`'s tables: `eq(τ)`, `eq(r_GMM)`, `eq(r_UMM)`, the nine `Dom::F` planes `G, rg₀, rg₁, A, U, ru, H, Htop, rh`,
the four LogUp helpers and the `fact` helper, the group column, the gate `supp(F)`. -/
def tabsF : List TabS :=
  [.eq (drR 18 10 15) 0, .eq (drR 11 0 15) 0, .eq (drR 11 0 5 ++ drR 12 0 10) 0,
    paT 901120 15 262, paT 933888 15 264, paT 966656 15 266, paT 999424 15 268, paT 1032192 15 270,
    paT 1064960 15 272, paT 1097728 15 274, paT 1130496 15 276, paT 1163264 15 278,
    hT 851968 884736 154, hT 917504 950272 156, hT 983040 1015808 158, hT 1048576 1081344 160,
    hT 1114112 1146880 162, .pub 0, .pub 1]

/-- `SC_FZC`'s plane-to-table map. -/
def shF (q : ℕ) : ℕ := 3 + (q - 49)

/-- `SC_FZC`'s table positions. -/
def rrF : FzcR := ⟨0, 1, 2, 3, 6, 7, 9, [4, 5], [8], [11], 12, 16, 17, some 18⟩

/-- The shifts: the product fold's `16`, the gate's `19`, the up projection's `12`. -/
def kF : FzcK := ⟨16, 19, 12⟩

/-- `α − 2048 − g_act`, `−β`, `−β²`. -/
def amqS : Sym := .sub (.sub .alpha (.base 2048)) (.gtag 134)
def nbS : Sym := .neg .beta
def nb2S : Sym := .neg (.mul .beta .beta)

/-- The pad group: the gate at table `18`, the nine `Dom::F` planes. -/
def grpF : List (ℕ × List ℕ) := [(18, [3, 4, 5, 6, 7, 8, 9, 10, 11])]

/-- `SC_FZC`'s IR at the rung. -/
def irF : ZK60.Exec.Slot.Ir Sym :=
  fzcIr DefW16.cstS rrF kF (lksS cfgRungW16 shF .F) (drR 18 0 7) (drR 18 7 2) amqS nbS nb2S
    (fun j => Sym.pow (.dr 18 9) j) grpF

theorem slot18_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 18 SlotS.empty
    = ⟨tabsF, irF, [(11, .dr 18 7), (12, .dr 18 8)], [.dr 18 7, .dr 18 8, .dr 18 9]⟩ := rfl

/-- `SC_GMM`'s `A` table: `YM` with its token coordinates fixed at `r_tf`. -/
def gmmA : TabS := .priv ⟨.a, [(294912, false)], 14, (drR 11 0 5).map CoordS.fixed ++ DefW16.rhoC 0 9, 162, 0⟩

/-- `SC_UMM`'s `A` table: `YM` with its token coordinates fixed at `SC_GMM`'s `r_tf`. -/
def ummA : TabS := .priv ⟨.a, [(294912, false)], 14, (drR 11 0 5).map CoordS.fixed ++ DefW16.rhoC 0 9, 164, 0⟩

theorem slot11_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 11 SlotS.empty
    = ⟨[gmmA, .pub 0], mmIr DefW16.cstS 0 1, [], []⟩ := rfl

theorem slot12_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 12 SlotS.empty
    = ⟨[ummA, .pub 0], mmIr DefW16.cstS 0 1, [], []⟩ := rfl

theorem lksF_length : (lksS cfgRungW16 shF .F).length = 7 := rfl

/-- The rung's slot shapes of slots `18`, `11`, `12`. -/
theorem slotShape_fzc (P : BlockParams) (hsl : P.geom.slots = W16R2.rungSlots) :
    slotShape P 18 = (15, 1, 5) ∧ slotShape P 11 = (9, 1, 2) ∧ slotShape P 12 = (9, 1, 2) := by
  simp only [slotShape, hsl]
  decide

/-! ## The value list -/

section Defs

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- **`SC_FZC`'s value list from position `3` on**, at a cube point. -/
noncomputable def restF (b : Fin 15 → Bool) : List K :=
  [aPl U P D 901120 15 b, aPl U P D 933888 15 b, aPl U P D 966656 15 b, aPl U P D 999424 15 b,
    aPl U P D 1032192 15 b, aPl U P D 1064960 15 b, aPl U P D 1097728 15 b, aPl U P D 1130496 15 b,
    aPl U P D 1163264 15 b,
    hPl U P D 851968 884736 15 b, hPl U P D 917504 950272 15 b, hPl U P D 983040 1015808 15 b,
    hPl U P D 1048576 1081344 15 b, hPl U P D 1114112 1146880 15 b,
    algebraMap GF K (B.grpCol (splitF b)), algebraMap GF K (B.gF (splitF b))]

/-- The value list without the draws: the `eq` entries `0`. -/
noncomputable def valsF (b : Fin 15 → Bool) : List K := 0 :: 0 :: 0 :: restF U P D Pb Lay B b

/-- The LogUp lookups read in the field at a history (they read only `α`, `γ`). -/
noncomputable def lksK (hist : Hist) (dr : List Fp2) : List (LkD K) :=
  ((lksS cfgRungW16 shF .F).map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 18 dr))).map
    (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U))

/-- **The batch's entries past the product clause**, read without the draws: entry `1` the ACT tuple's relation,
entries `2 … 5` LogUp's helper relations. -/
noncomputable def xcFzc (bga : Fp2 × Fp2 × Fp2) (κ : ℕ) (b : Fin 15 → Bool) : K :=
  if κ = 1 then
    fzcAct (valsF U P D Pb Lay B b) rrF ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] amqS).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] nbS).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] nb2S).toK U)
  else (lkRels (cstK U) (valsF U P D Pb Lay B b) 12 0 (lksK U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD (κ - 2) 0

/-- **The pad planes**: `(1 − supp(F))·plane_j`, `j < 9`. -/
noncomputable def pwFzc (j : ℕ) (b : Fin 15 → Bool) : K := (padPls (valsF U P D Pb Lay B b) grpF).getD j 0

/-- The IR's zero-check sum at a value list. -/
noncomputable def zIR (hist : Hist) (dr : List Fp2) (v : List K) : K :=
  logupSem (cstK U) v 12 (fun k => (((drR 18 0 7).map (Sym.eval hist 18 dr)).map (Fp2.toK U)).getD (2 + k) 0) 0
      (lksK U hist dr)
    + (((drR 18 0 7).map (Sym.eval hist 18 dr)).map (Fp2.toK U)).getD 1 0
      * fzcAct v rrF ((Sym.eval hist 18 dr amqS).toK U) ((Sym.eval hist 18 dr nbS).toK U)
        ((Sym.eval hist 18 dr nb2S).toK U)
    + padSem (cstK U) v ((((drR 18 0 7).map (Sym.eval hist 18 dr)).map (Fp2.toK U)).getD 6 0)
      (fun j => (Sym.eval hist 18 dr (Sym.pow (.dr 18 9) j)).toK U) 0 grpF
    + gV v (some 18) * batchV (((drR 18 0 7).map (Sym.eval hist 18 dr)).map (Fp2.toK U))
      (fzcClauses (cstK U) rrF kF v)

/-- The `eq` points of the three `eq` tables, read in the field. -/
noncomputable def tauF (ev : Sym → Fp2) : Fin 15 → K := fun a => (((drR 18 10 15).map ev).getD a Fp2.zero).toK U
noncomputable def p0F (ev : Sym → Fp2) : Fin 15 → K := fun a => (((drR 11 0 15).map ev).getD a Fp2.zero).toK U
noncomputable def p1F (ev : Sym → Fp2) : Fin 15 → K :=
  fun a => (((drR 11 0 5 ++ drR 12 0 10).map ev).getD a Fp2.zero).toK U

/-- **The value list `SC_FZC`'s IR reads at a cube point with the zero extension.** -/
noncomputable def vF (ev : Sym → Fp2) (b : Fin 15 → Bool) : List K :=
  eqPoly (tauF U ev) (fun a => bit (b a)) :: eqPoly (p0F U ev) (fun a => bit (b a))
    :: eqPoly (p1F U ev) (fun a => bit (b a)) :: restF U P D Pb Lay B b

end Defs

/-! ## Positions past the `eq` tables -/

theorem getD_cons3 {R : Type} [Zero R] (a b c a' b' c' : R) (L : List R) (i : ℕ) (hi : 3 ≤ i) :
    (a :: b :: c :: L).getD i 0 = (a' :: b' :: c' :: L).getD i 0 := by
  obtain ⟨j, rfl⟩ : ∃ j, i = j + 1 + 1 + 1 := ⟨i - 3, by omega⟩
  simp only [List.getD_cons_succ]

theorem lksK_pos {K : Type} [Field K] [Algebra GF K] (U : K) (hist : Hist) (dr : List Fp2) :
    ∀ l ∈ lksK U hist dr, ∀ t ∈ l.terms, 3 ≤ t.2 := by
  intro l hl t ht
  simp only [lksK, lksS, List.mem_map] at hl
  obtain ⟨l1, ⟨l0, ⟨lw, -, rfl⟩, rfl⟩, rfl⟩ := hl
  simp only [ZK60.Exec.Slot.Build.LkD.map, List.mem_map] at ht
  obtain ⟨t1, ⟨t0, ⟨tw, -, rfl⟩, rfl⟩, rfl⟩ := ht
  simp [shF]

/-! ## The value list at a cube point -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- **`SC_FZC`'s value list at a cube point with the zero extension.** -/
theorem fzc_vals (hrl : 0 < rowLog P .a) (e : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2)
    (hg0 : ∀ b : Fin 15 → Bool, ((pub 0).getD (msbIndex 15 b) Fp2.zero).toK U = algebraMap GF K (B.grpCol (splitF b)))
    (hg1 : ∀ b : Fin 15 → Bool, ((pub 1).getD (msbIndex 15 b) Fp2.zero).toK U = algebraMap GF K (B.gF (splitF b)))
    (b : Fin 15 → Bool) :
    (tabsF.map (TabS.eval ev pub)).map (tabK U P D 15 e (cpt 15 e b)) = vF U P D Pb Lay B ev b := by
  have hrlh : 0 < rowLog P .h := hrl
  have l1 : ((drR 18 10 15).map ev).length = 15 := by rw [List.length_map, drR_length]
  have l2 : ((drR 11 0 15).map ev).length = 15 := by rw [List.length_map, drR_length]
  have l3 : ((drR 11 0 5 ++ drR 12 0 10).map ev).length = 15 := by
    rw [List.length_map, List.length_append, drR_length, drR_length]
  simp only [tabsF, List.map_cons, List.map_nil, paT_eval, eqT_eval, pubT_eval, hT_eval]
  rw [tabK_eqFull_cpt U P D 15 e b _ l1, tabK_eqFull_cpt U P D 15 e b _ l2, tabK_eqFull_cpt U P D 15 e b _ l3]
  simp only [tabK_pa_cpt U P D hrl 15 e b 15 (by norm_num) rfl, tabK_ph_cpt U P D hrlh 15 e b 15 (by norm_num) rfl,
    tabK_pub_cpt, hg0, hg1, castB_rfl]
  rfl

/-- Off the zero extension the three `eq` entries are `0`. -/
theorem fzc_off (e : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) (b : Fin 15 → Bool) (y : Fin e → Bool)
    (hy : y ≠ fun _ => false) :
    ((tabsF.map (TabS.eval ev pub)).map (tabK U P D 15 e (bpt 15 e b y))).getD 0 0 = 0
      ∧ ((tabsF.map (TabS.eval ev pub)).map (tabK U P D 15 e (bpt 15 e b y))).getD 1 0 = 0
      ∧ ((tabsF.map (TabS.eval ev pub)).map (tabK U P D 15 e (bpt 15 e b y))).getD 2 0 = 0 := by
  simp only [tabsF, List.map_cons, eqT_eval, List.getD_cons_zero, List.getD_cons_succ]
  exact ⟨tabK_eq_off U P D 15 e b y hy _ _, tabK_eq_off U P D 15 e b y hy _ _, tabK_eq_off U P D 15 e b y hy _ _⟩

end Vals

/-! ## The IR and the slot's cube sum -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- **`SC_FZC`'s IR read in the field**: L13's host terms. -/
theorem fzc_irEval (hist : Hist) (dr : List Fp2) (v : List K) :
    irEval ((irF.map (Sym.eval hist 18 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 (some 18) (some 18) (((drR 18 7 2).map (Sym.eval hist 18 dr)).map (Fp2.toK U))
          (zIR U hist dr v) (reqV (cstK U) v 19 3 [4, 5]) (reqV (cstK U) v 12 7 [8]) := by
  unfold irF
  rw [fzcIr_map, fzcIr_map, cstS_map, fzcIr_eval _ (cstW_map_std U)]
  have hl : (((lksS cfgRungW16 shF .F).map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 18 dr))).map
      (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U))).length = 7 := by
    rw [List.length_map, List.length_map, lksF_length]
  simp only [hl]
  rfl

/-- **`SC_FZC`'s cube sum** (`n = 15` main variables). -/
theorem fzc_cube (hrl : 0 < rowLog P .a) (n e : ℕ) (hn : n = 15) (hist : Hist) (dr : List Fp2)
    (pub : ℕ → List Fp2)
    (hg0 : ∀ b : Fin 15 → Bool, ((pub 0).getD (msbIndex 15 b) Fp2.zero).toK U = algebraMap GF K (B.grpCol (splitF b)))
    (hg1 : ∀ b : Fin 15 → Bool, ((pub 1).getD (msbIndex 15 b) Fp2.zero).toK U = algebraMap GF K (B.gF (splitF b)))
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval ((irF.map (Sym.eval hist 18 dr)).map (Fp2.toK U))
      ((tabsF.map (TabS.eval (Sym.eval hist 18 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin 15 → Bool, hostPoly (tauF U (Sym.eval hist 18 dr))
      (fun b => zIR U hist dr (vF U P D Pb Lay B (Sym.eval hist 18 dr) b))
      ![(((drR 18 7 2).map (Sym.eval hist 18 dr)).map (Fp2.toK U)).getD 0 0,
        (((drR 18 7 2).map (Sym.eval hist 18 dr)).map (Fp2.toK U)).getD 1 0]
      ![p0F U (Sym.eval hist 18 dr), p1F U (Sym.eval hist 18 dr)] (fun _ => 1)
      (fun i b => if i = 0
        then gV (vF U P D Pb Lay B (Sym.eval hist 18 dr) b) (some 18)
          * reqV (cstK U) (vF U P D Pb Lay B (Sym.eval hist 18 dr) b) 19 3 [4, 5]
        else gV (vF U P D Pb Lay B (Sym.eval hist 18 dr) b) (some 18)
          * reqV (cstK U) (vF U P D Pb Lay B (Sym.eval hist 18 dr) b) 12 7 [8]) b := by
  subst hn
  have hv := fzc_vals U P D Pb Lay B hrl e (Sym.eval hist 18 dr) pub hg0 hg1
  rw [cubeSum_host 15 e (fun x => (tabsF.map (TabS.eval (Sym.eval hist 18 dr) pub)).map (tabK U P D 15 e x))
    0 1 2 (some 18) (some 18) (((drR 18 7 2).map (Sym.eval hist 18 dr)).map (Fp2.toK U)) (zIR U hist dr)
    (fun v => reqV (cstK U) v 19 3 [4, 5]) (fun v => reqV (cstK U) v 12 7 [8]) f
    (fun x => by rw [hf x, fzc_irEval U hist dr])
    (fun b y hy => fzc_off U P D e (Sym.eval hist 18 dr) pub b y hy)
    (tauF U (Sym.eval hist 18 dr)) ![p0F U (Sym.eval hist 18 dr), p1F U (Sym.eval hist 18 dr)]
    (fun b => (congrArg (fun l : List K => l.getD 0 0) (hv b)).trans rfl)
    (fun b => (congrArg (fun l : List K => l.getD 1 0) (hv b)).trans rfl)
    (fun b => (congrArg (fun l : List K => l.getD 2 0) (hv b)).trans rfl)]
  simp only [hv]

end Cube

/-! ## The clause and the hosted terms are the named relations -/

section Rels

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

theorem append_splitF (b : Fin 15 → Bool) : Fin.append (splitF b).1 (splitF b).2 = b := by
  funext i
  refine Fin.addCases (fun i5 => ?_) (fun i10 => ?_) i
  · rw [Fin.append_left]; rfl
  · rw [Fin.append_right]; rfl

include hX in
theorem alg_plF (off : ℕ) (b : Fin 15 → Bool) :
    algebraMap GF K (plF U P D off (splitF b)) = aPl U P D off 15 b := by
  unfold plF
  rw [aPl_alg U P D hX, append_splitF]

include hX in
/-- **The gated product clause IS `relCl 18 0`** (`K.r = 16 = S.sprod`, the product remainder one limb). -/
theorem fzc_rel0 (hS : RungS S) (b : Fin 15 → Bool) (e0 e1 e2 : K) (mu : List K) :
    gV (e0 :: e1 :: e2 :: restF U P D Pb Lay B b) (some 18)
        * batchV mu (fzcClauses (cstK U) rrF kF (e0 :: e1 :: e2 :: restF U P D Pb Lay B b))
      = mu.getD 0 0 * algebraMap GF K (relCl Pb Lay B (xtW U P D) 18 0 (.f (splitF b))) := by
  have hrel : relCl Pb Lay B (xtW U P D) 18 0 (.f (splitF b))
      = B.gF (splitF b) * (plF U P D 999424 (splitF b) * plF U P D 1032192 (splitF b)
        - 2 ^ 16 * plF U P D 1097728 (splitF b) - plF U P D 1163264 (splitF b) + 2 ^ 15) := by
    simp only [relCl, hS.sprod]
    rfl
  rw [hrel]
  simp (disch := norm_num) only [gV_some, batchV, fzcClauses, rrF, kF, L16, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_succ, List.getD_cons_zero, restF,
    add_zero, cstK_base U, cstK_p16 U, map_mul, map_add, map_sub, map_pow, map_ofNat, map_intCast,
    alg_plF U P D hX]
  push_cast
  ring

include hX in
/-- **The gated first requantization host IS `relGh 18 0`** (the gate's shift `19`, two limbs). -/
theorem fzc_gh0 (hS : RungS S) (b : Fin 15 → Bool) (e0 e1 e2 : K) :
    gV (e0 :: e1 :: e2 :: restF U P D Pb Lay B b) (some 18)
        * reqV (cstK U) (e0 :: e1 :: e2 :: restF U P D Pb Lay B b) 19 3 [4, 5]
      = algebraMap GF K (relGh Pb Lay B (xtW U P D) 18 0 (.f (splitF b))) := by
  have hrel : relGh Pb Lay B (xtW U P D) 18 0 (.f (splitF b))
      = B.gF (splitF b) * (2 ^ 19 * plF U P D 901120 (splitF b)
        + (plF U P D 933888 (splitF b) + 2 ^ 16 * plF U P D 966656 (splitF b)) - 2 ^ 18) := by
    simp only [relGh, hS.sgate]
    rfl
  rw [hrel]
  simp (disch := norm_num) only [gV_some, reqV, L16, List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.map_nil,
    List.sum_cons, List.sum_nil, List.getD_cons_succ, List.getD_cons_zero, restF, add_zero, cstK_base U,
    cstK_p16 U, map_mul, map_add, map_sub, map_pow, map_ofNat, map_intCast, alg_plF U P D hX]
  push_cast
  ring

include hX in
/-- **The gated second requantization host IS `relGh 18 1`** (the up projection's shift `12`, one limb). -/
theorem fzc_gh1 (hS : RungS S) (b : Fin 15 → Bool) (e0 e1 e2 : K) :
    gV (e0 :: e1 :: e2 :: restF U P D Pb Lay B b) (some 18)
        * reqV (cstK U) (e0 :: e1 :: e2 :: restF U P D Pb Lay B b) 12 7 [8]
      = algebraMap GF K (relGh Pb Lay B (xtW U P D) 18 1 (.f (splitF b))) := by
  have hrel : relGh Pb Lay B (xtW U P D) 18 1 (.f (splitF b))
      = B.gF (splitF b) * (2 ^ 12 * plF U P D 1032192 (splitF b) + plF U P D 1064960 (splitF b) - 2 ^ 11) := by
    simp only [relGh, hS.sup]
    rfl
  rw [hrel]
  simp (disch := norm_num) only [gV_some, reqV, L16, List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.map_nil,
    List.sum_cons, List.sum_nil, List.getD_cons_succ, List.getD_cons_zero, restF, add_zero, cstK_base U,
    cstK_p16 U, map_mul, map_add, map_sub, map_pow, map_ofNat, map_intCast, alg_plF U P D hX]
  push_cast
  ring

end Rels

/-! ## The host's batch -/

section Batch

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

theorem getD_map_toK (l : List Fp2) (k : ℕ) : (l.map (Fp2.toK U)).getD k 0 = (l.getD k Fp2.zero).toK U := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map]
  cases l[k]? with
  | none => simp [Fp2.toK_zero]
  | some y => rfl

/-- The batch weights `μ_k` the IR reads. -/
theorem muF_getD (hist : Hist) (dr : List Fp2) (k : ℕ) (hk : k < 7) :
    (((drR 18 0 7).map (Sym.eval hist 18 dr)).map (Fp2.toK U)).getD k 0 = (dr.getD k Fp2.zero).toK U := by
  rw [getD_map_toK, drR_getD _ 18 0 7 k hk, Nat.zero_add]
  rfl

omit [Algebra GF K] in
/-- The ACT relation reads only the positions past the `eq` tables. -/
theorem fzcAct_congr (v v' : List K) (h : ∀ i, 3 ≤ i → v.getD i 0 = v'.getD i 0) (a n n2 : K) :
    fzcAct v rrF a n n2 = fzcAct v' rrF a n n2 := by
  unfold fzcAct
  simp only [rrF]
  rw [h 16 (by norm_num), h 3 (by norm_num), h 6 (by norm_num), h 17 (by norm_num)]

include hU hX in
/-- **The host's batch over the algebra data's tables IS the IR's zero-check sum**: the product clause, the ACT
relation, LogUp's helper relations and the pad term, at the drawn weights. -/
theorem fzc_batch (hS : RungS S) {L : ℕ} (hdr : P.draws = W16R2.rungDraws)
    (dt : AlgData K L (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78)) (cu : Cuts3 L) (rt : RootsO)
    (bga : Fp2 × Fp2 × Fp2)
    (hcl : ∀ (κ : Fin 6) (b : Fin 15 → Bool), dt.cl 18 cu rt bga κ b
      = if (κ : ℕ) < 1 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 18 κ (.f (splitF b)))
        else xcFzc U P D Pb Lay B bga κ b)
    (hpw : ∀ (j : Fin 9) (b : Fin 15 → Bool), dt.pw 18 cu rt j b = pwFzc U P D Pb Lay B j b)
    (l : List SlotRec) (dr : List Fp2) (b : Fin 15 → Bool) (e0 e1 e2 : K)
    (ω : (K × K) × (Fin (segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 18) .mu
      - segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 18) .zeta) → K))
    (h1 : ω.1.1 = (dr.getD 9 Fp2.zero).toK U) (h2 : ω.1.2 = (dr.getD 6 Fp2.zero).toK U)
    (h3 : ∀ κ, ω.2 κ = (dr.getD κ Fp2.zero).toK U) :
    batched (dt.cl 18 cu rt bga) (dt.pw 18 cu rt) ω b
      = zIR U (histOf bga.1 bga.2.1 bga.2.2 l) dr (e0 :: e1 :: e2 :: restF U P D Pb Lay B b) := by
  have m_ : ∀ k, k < 7 → (((drR 18 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr)).map
      (Fp2.toK U)).getD k 0 = (dr.getD k Fp2.zero).toK U := fun k hk => muF_getD U _ dr k hk
  have hv : ∀ i, 3 ≤ i → (e0 :: e1 :: e2 :: restF U P D Pb Lay B b).getD i 0
      = (valsF U P D Pb Lay B b).getD i 0 := fun i hi => getD_cons3 _ _ _ _ _ _ _ i hi
  -- the host side, as sums over ranges
  have hA : (∑ k : Fin 6, ω.2 k * dt.cl 18 cu rt bga k b)
      = ∑ k ∈ Finset.range 6, (dr.getD k Fp2.zero).toK U
        * (if k < 1 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 18 k (.f (splitF b)))
          else xcFzc U P D Pb Lay B bga k b) := by
    rw [← Fin.sum_univ_eq_sum_range (fun k => (dr.getD k Fp2.zero).toK U
      * (if k < 1 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 18 k (.f (splitF b)))
        else xcFzc U P D Pb Lay B bga k b)) 6]
    refine Finset.sum_congr rfl (fun k _ => ?_)
    rw [h3 k, hcl k b]
  have hB : (∑ j : Fin 9, ω.1.1 ^ (j : ℕ) * dt.pw 18 cu rt j b)
      = ∑ j ∈ Finset.range 9, ((dr.getD 9 Fp2.zero).toK U) ^ j * pwFzc U P D Pb Lay B j b := by
    rw [← Fin.sum_univ_eq_sum_range (fun j => ((dr.getD 9 Fp2.zero).toK U) ^ j * pwFzc U P D Pb Lay B j b) 9]
    refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [h1, hpw j b]
  -- the IR side
  have hk : lksK U (histOf bga.1 bga.2.1 bga.2.2 l) dr = lksK U (histOf bga.1 bga.2.1 bga.2.2 []) [] := by
    unfold lksK
    rw [lksS_eval cfgRungW16 shF .F (histOf bga.1 bga.2.1 bga.2.2 l) (histOf bga.1 bga.2.1 bga.2.2 []) 18 18 dr []
      rfl rfl]
  have hlenL : (lkRels (cstK U) (valsF U P D Pb Lay B b) 12 0
      (lksK U (histOf bga.1 bga.2.1 bga.2.2 []) [])).length = 4 := by
    rw [lkRels_length]
    simp only [lksK, List.length_map, lksF_length]
  have hlog : logupSem (cstK U) (e0 :: e1 :: e2 :: restF U P D Pb Lay B b) 12
      (fun k => (((drR 18 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr)).map (Fp2.toK U)).getD (2 + k) 0)
      0 (lksK U (histOf bga.1 bga.2.1 bga.2.2 l) dr)
      = ∑ i ∈ Finset.range 4, (dr.getD (2 + i) Fp2.zero).toK U
        * (lkRels (cstK U) (valsF U P D Pb Lay B b) 12 0 (lksK U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD i 0 := by
    rw [logupSem_eq_wsum, hk, lkRels_congr (cstK U) _ (valsF U P D Pb Lay B b) 12 0 _
      (fun l hl t ht => hv t.2 (lksK_pos U _ [] l hl t ht)) (fun i _ => hv _ (by omega)), wsum_eq_sum]
    rw [Fin.sum_univ_eq_sum_range (fun i => (((drR 18 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr)).map
        (Fp2.toK U)).getD (2 + (0 + i)) 0
      * (lkRels (cstK U) (valsF U P D Pb Lay B b) 12 0 (lksK U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD i 0), hlenL]
    refine Finset.sum_congr rfl (fun i hi => ?_)
    have hi4 := Finset.mem_range.mp hi
    rw [m_ _ (by omega), Nat.zero_add]
  have hact : fzcAct (e0 :: e1 :: e2 :: restF U P D Pb Lay B b) rrF
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr amqS).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr nbS).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr nb2S).toK U) = xcFzc U P D Pb Lay B bga 1 b := by
    unfold xcFzc
    rw [ite_eq_left rfl]
    exact fzcAct_congr _ _ hv _ _ _
  have hlenP : (padPls (valsF U P D Pb Lay B b) grpF).length = 9 := by simp [padPls, grpF]
  have hgrp : ∀ g ∈ grpF, (e0 :: e1 :: e2 :: restF U P D Pb Lay B b).getD g.1 0 = (valsF U P D Pb Lay B b).getD g.1 0
      ∧ ∀ p ∈ g.2, (e0 :: e1 :: e2 :: restF U P D Pb Lay B b).getD p 0 = (valsF U P D Pb Lay B b).getD p 0 := by
    intro g hg
    simp only [grpF, List.mem_singleton] at hg
    subst hg
    refine ⟨hv 18 (by norm_num), fun p hp => hv p ?_⟩
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
    omega
  have hpad : padSem (cstK U) (e0 :: e1 :: e2 :: restF U P D Pb Lay B b)
      ((((drR 18 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr)).map (Fp2.toK U)).getD 6 0)
      (fun j => (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr (Sym.pow (.dr 18 9) j)).toK U) 0 grpF
      = (dr.getD 6 Fp2.zero).toK U
        * ∑ j ∈ Finset.range 9, ((dr.getD 9 Fp2.zero).toK U) ^ j * pwFzc U P D Pb Lay B j b := by
    rw [padSem_eq_wsum (cstK U) (cstW_map_std U), m_ 6 (by norm_num),
      padPls_congr _ (valsF U P D Pb Lay B b) grpF hgrp, wsum_eq_sum]
    congr 1
    rw [Fin.sum_univ_eq_sum_range (fun i => (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr
        (Sym.pow (.dr 18 9) (0 + i))).toK U * (padPls (valsF U P D Pb Lay B b) grpF).getD i 0), hlenP]
    refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [Nat.zero_add]
    show (zpowW (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr (.dr 18 9)) j).toK U * _ = _
    rw [toK_zpowW U hU]
    rfl
  have hcla : gV (e0 :: e1 :: e2 :: restF U P D Pb Lay B b) (some 18)
      * batchV (((drR 18 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr)).map (Fp2.toK U))
        (fzcClauses (cstK U) rrF kF (e0 :: e1 :: e2 :: restF U P D Pb Lay B b))
      = (dr.getD 0 Fp2.zero).toK U * algebraMap GF K (relCl Pb Lay B (xtW U P D) 18 0 (.f (splitF b))) := by
    rw [fzc_rel0 U P D hX Pb Lay B hS b e0 e1 e2, m_ 0 (by norm_num)]
  have hexp : ∑ k ∈ Finset.range 6, (dr.getD k Fp2.zero).toK U
        * (if k < 1 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 18 k (.f (splitF b)))
          else xcFzc U P D Pb Lay B bga k b)
      = (dr.getD 0 Fp2.zero).toK U * algebraMap GF K (relCl Pb Lay B (xtW U P D) 18 0 (.f (splitF b)))
        + (dr.getD 1 Fp2.zero).toK U * xcFzc U P D Pb Lay B bga 1 b
        + (dr.getD 2 Fp2.zero).toK U
          * (lkRels (cstK U) (valsF U P D Pb Lay B b) 12 0 (lksK U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD 0 0
        + (dr.getD 3 Fp2.zero).toK U
          * (lkRels (cstK U) (valsF U P D Pb Lay B b) 12 0 (lksK U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD 1 0
        + (dr.getD 4 Fp2.zero).toK U
          * (lkRels (cstK U) (valsF U P D Pb Lay B b) 12 0 (lksK U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD 2 0
        + (dr.getD 5 Fp2.zero).toK U
          * (lkRels (cstK U) (valsF U P D Pb Lay B b) 12 0 (lksK U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD 3 0 := by
    simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add]
    rfl
  -- assemble
  unfold batched
  show (∑ k : Fin 6, ω.2 k * dt.cl 18 cu rt bga k b)
      + ω.1.2 * (∑ j : Fin 9, ω.1.1 ^ (j : ℕ) * dt.pw 18 cu rt j b) = _
  rw [hA, hB, h2, hexp]
  unfold zIR
  rw [hlog, hact, hpad, hcla, m_ 1 (by norm_num)]
  simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add]
  ring

end Batch

/-! ## The hosted matmuls -/

section Mm

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- A hosted matmul slot's polynomial is its `A` table times its public table. -/
theorem mmSlot_eval (hist : Hist) (k : ℕ) (dr : List Fp2) (pub : ℕ → List Fp2) (n e : ℕ) (x : Fin (n + e) → K)
    (t : TabS) :
    irEval (((mmIr DefW16.cstS 0 1).map (Sym.eval hist k dr)).map (Fp2.toK U))
        (([t, TabS.pub 0].map (TabS.eval (Sym.eval hist k dr) pub)).map (tabK U P D n e x))
      = tabK U P D n e x (TabS.eval (Sym.eval hist k dr) pub t) * tabK U P D n e x (.pub (pub 0)) := by
  rw [mmIr_map, mmIr_map, cstS_map, mmIr_eval _ (cstW_map_std U)]
  rfl

include hX in
/-- The contraction of `SC_FZC`'s pairs, read through the plane `YM`. -/
theorem fzc_mmfun (y : Fin 15 → Bool) (W : CwW → CfW → GF) :
    (∑ c : Fin 9 → Bool, aPl U P D 294912 (5 + 9) (Fin.append (fun i => y (Fin.castAdd 10 i)) c)
      * algebraMap GF K (W c (fun i => y (Fin.natAdd 5 i))))
      = algebraMap GF K (∑ c, (xtW U P D).YM ((splitF y).1, c) * W c (splitF y).2) := by
  rw [map_sum]
  refine Finset.sum_congr rfl (fun c _ => ?_)
  rw [map_mul, show algebraMap GF K ((xtW U P D).YM ((splitF y).1, c))
    = aPl U P D 294912 14 (Fin.append (splitF y).1 c) from aPl_alg U P D hX 294912 14 _]
  rfl

include hX in
/-- **`SC_GMM`'s cube sum is the multilinear extension of `relMm 18 0` at its claim point.** -/
theorem gmm_sum (ioIn ioOut : ℕ) (pubs : PubTabs) (hpub : PubW16 U pubs Pb Lay B) (hrl : 0 < rowLog P .a)
    (hs11 : slotShape P 11 = (9, 1, 2)) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r11 : SlotRec)
    (hr11 : rs[11]? = some r11) (hc11 : ∀ x ∈ r11.draws, x.Canon) :
    cubeSum (polyS U P D (progW16 cfgRungW16 ioIn ioOut) pubs 11 (seenOf bga rs 11))
      = mleAt (fun y : Fin 15 → Bool => algebraMap GF K (relMm Pb Lay B (xtW U P D) 18 0 (.f (splitF y))))
          (fun t : Fin 15 => (r11.draws.getD t Fp2.zero).toK U) := by
  have hf : ∀ x, polyS U P D (progW16 cfgRungW16 ioIn ioOut) pubs 11 (seenOf bga rs 11) x
      = tabK U P D (slotShape P 11).1 (slotShape P 11).2.1 x
          (.priv ⟨.a, [(294912, Fp2.one)], 5 + 9, ((drR 11 0 5).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2
            (rs.take 11)) 11 r11.draws)).map Coord.fixed ++ rhoAll 9, 162, 0⟩)
        * tabK U P D (slotShape P 11).1 (slotShape P 11).2.1 x
          (.pub (pubs 11 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 11)) r11.draws 0)) := by
    intro x
    rw [polyS_seenOf U P D _ pubs bga rs 11 r11 hr11 x, slot11_eq]
    show irEval (((mmIr DefW16.cstS 0 1).map _).map (Fp2.toK U)) (([gmmA, TabS.pub 0].map (TabS.eval _ _)).map _) = _
    rw [mmSlot_eval, gmmA, aFx_eval]
  rw [mm_cube U P D hrl _ _ _ 5 9 (by rw [List.length_map, drR_length]) (by rw [hs11]) (by norm_num) 294912 162
    _ _ hf]
  simp only [hpub.wg (histOf bga.1 bga.2.1 bga.2.2 (rs.take 11)) r11.draws hc11, eqDr]
  rw [mm_fold]
  have hfun : ∀ y : Fin 15 → Bool, (∑ c : Fin 9 → Bool, aPl U P D 294912 (5 + 9)
      (Fin.append (fun i => y (Fin.castAdd 10 i)) c) * algebraMap GF K (B.Wg c (fun i => y (Fin.natAdd 5 i))))
      = algebraMap GF K (relMm Pb Lay B (xtW U P D) 18 0 (.f (splitF y))) := fun y =>
    fzc_mmfun U P D hX y B.Wg
  have hpt : ∀ t : Fin (5 + 10), Fin.append (fun i : Fin 5 => (((drR 11 0 5).map (Sym.eval (histOf bga.1 bga.2.1
      bga.2.2 (rs.take 11)) 11 r11.draws)).getD i Fp2.zero).toK U)
      (fun a : Fin 10 => (r11.draws.getD (5 + a) Fp2.zero).toK U) t = (r11.draws.getD t Fp2.zero).toK U := by
    intro t
    refine Fin.addCases (fun i => ?_) (fun a => ?_) t
    · rw [Fin.append_left, drR_getD _ 11 0 5 i i.isLt, Nat.zero_add]
      rfl
    · rw [Fin.append_right]
      rfl
  exact congr (congrArg mleAt (funext hfun)) (funext hpt)

include hX in
/-- **`SC_UMM`'s cube sum is the multilinear extension of `relMm 18 1` at its split claim point** (`SC_GMM`'s token
coordinates, then its own draws). -/
theorem umm_sum (ioIn ioOut : ℕ) (pubs : PubTabs) (hpub : PubW16 U pubs Pb Lay B) (hrl : 0 < rowLog P .a)
    (hs12 : slotShape P 12 = (9, 1, 2)) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r11 r12 : SlotRec)
    (hr11 : rs[11]? = some r11) (hr12 : rs[12]? = some r12) (hc12 : ∀ x ∈ r12.draws, x.Canon) :
    cubeSum (polyS U P D (progW16 cfgRungW16 ioIn ioOut) pubs 12 (seenOf bga rs 12))
      = mleAt (fun y : Fin 15 → Bool => algebraMap GF K (relMm Pb Lay B (xtW U P D) 18 1 (.f (splitF y))))
          (fun t : Fin 15 => if (t : ℕ) < 5 then (r11.draws.getD t Fp2.zero).toK U
            else (r12.draws.getD ((t : ℕ) - 5) Fp2.zero).toK U) := by
  have hf : ∀ x, polyS U P D (progW16 cfgRungW16 ioIn ioOut) pubs 12 (seenOf bga rs 12) x
      = tabK U P D (slotShape P 12).1 (slotShape P 12).2.1 x
          (.priv ⟨.a, [(294912, Fp2.one)], 5 + 9, ((drR 11 0 5).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2
            (rs.take 12)) 12 r12.draws)).map Coord.fixed ++ rhoAll 9, 164, 0⟩)
        * tabK U P D (slotShape P 12).1 (slotShape P 12).2.1 x
          (.pub (pubs 12 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 12)) r12.draws 0)) := by
    intro x
    rw [polyS_seenOf U P D _ pubs bga rs 12 r12 hr12 x, slot12_eq]
    show irEval (((mmIr DefW16.cstS 0 1).map _).map (Fp2.toK U)) (([ummA, TabS.pub 0].map (TabS.eval _ _)).map _) = _
    rw [mmSlot_eval, ummA, aFx_eval]
  rw [mm_cube U P D hrl _ _ _ 5 9 (by rw [List.length_map, drR_length]) (by rw [hs12]) (by norm_num) 294912 164
    _ _ hf]
  simp only [hpub.wu (histOf bga.1 bga.2.1 bga.2.2 (rs.take 12)) r12.draws hc12, eqDr]
  rw [mm_fold]
  have hfun : ∀ y : Fin 15 → Bool, (∑ c : Fin 9 → Bool, aPl U P D 294912 (5 + 9)
      (Fin.append (fun i => y (Fin.castAdd 10 i)) c) * algebraMap GF K (B.Wu c (fun i => y (Fin.natAdd 5 i))))
      = algebraMap GF K (relMm Pb Lay B (xtW U P D) 18 1 (.f (splitF y))) := fun y =>
    fzc_mmfun U P D hX y B.Wu
  have hpt : ∀ t : Fin (5 + 10), Fin.append (fun i : Fin 5 => (((drR 11 0 5).map (Sym.eval (histOf bga.1 bga.2.1
      bga.2.2 (rs.take 12)) 12 r12.draws)).getD i Fp2.zero).toK U)
      (fun a : Fin 10 => (r12.draws.getD (0 + a) Fp2.zero).toK U) t
      = if (t : ℕ) < 5 then (r11.draws.getD t Fp2.zero).toK U else (r12.draws.getD ((t : ℕ) - 5) Fp2.zero).toK U := by
    intro t
    refine Fin.addCases (fun i => ?_) (fun a => ?_) t
    · rw [Fin.append_left, drR_getD _ 11 0 5 i i.isLt, Nat.zero_add,
        ite_eq_left (show ((Fin.castAdd 10 i : Fin (5 + 10)) : ℕ) < 5 from i.isLt)]
      exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 12 11 i r11 (by norm_num) hr11
    · rw [Fin.append_right, ite_eq_right (show ¬ (((Fin.natAdd 5 a : Fin (5 + 10)) : ℕ) < 5) by simp)]
      simp
  exact congr (congrArg mleAt (funext hfun)) (funext hpt)

end Mm

/-! ## `SC_FZC`'s named identity -/

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]

/-- **Lane L36's `FormAt` at host `18` (`SC_FZC`)**: on every outcome whose verified slots are hosts exactly when their
definitions host slots, `SC_FZC`'s certified polynomial at the drawn challenges IS its unmasked residual
`Σ Poly₁₈ − (ν₀·Σ Poly₁₁ + ν₁·Σ Poly₁₂)`, for every algebra data whose host-`18` tables are the relation tables of
the extracted planes, the batch's other entries `xcFzc` and the pad planes `pwFzc`. -/
theorem formAt_fzc (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
    (B : W16Pub S Pb Lay)
    (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (hsl : P.geom.slots = W16R2.rungSlots)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : RungS S) (_hL : LayW16 Lay) (hpub : PubW16 U pubs Pb Lay B)
    (dt : AlgData K L (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga (κ : Fin 6) (b : Fin 15 → Bool), dt.cl 18 cu rt bga κ b
      = if (κ : ℕ) < 1 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 18 κ (.f (splitF b)))
        else xcFzc U P D Pb Lay B bga κ b)
    (hpw : ∀ (j : Fin 9) (b : Fin 15 → Bool), dt.pw 18 cu rt j b = pwFzc U P D Pb Lay B j b)
    (hgh : ∀ (i : Fin 2) (b : Fin 15 → Bool),
      dt.gh 18 cu rt i b = algebraMap GF K (relGh Pb Lay B (xtW U P D) 18 i (.f (splitF b))))
    (hmm : ∀ (i : Fin 2) (b : Fin 15 → Bool),
      dt.mm 18 cu rt i b = algebraMap GF K (relMm Pb Lay B (xtW U P D) 18 i (.f (splitF b))))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt hcard 0 cu rt k h).Φ) bga rs 18 := by
  obtain ⟨hs18, hs11, hs12⟩ := slotShape_fzc P hsl
  refine formAt_two U hcard P (progW16 cfgRungW16 ioIn ioOut) pubs hdef D
    (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt cu rt bga rs 18 (by decide) 11 12 (.dr 18 7) (.dr 18 8)
    (by rw [slot18_eq]) (by rw [slot11_eq]) (by rw [slot12_eq]) (by norm_num) (by norm_num) hslots
    (fun r hr => ?_)
  have hlen : 18 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r11, hr11⟩ : ∃ r11, rs[11]? = some r11 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r12, hr12⟩ : ∃ r12, rs[12]? = some r12 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  have hcanon : ∀ (j : ℕ) (rj : SlotRec), rs[j]? = some rj → ∀ x ∈ rj.draws, Fp2.Canon x := by
    intro j rj hrj
    obtain ⟨df, hdf, -⟩ := hslots j rj hrj
    have hdf' : defineS (progW16 cfgRungW16 ioIn ioOut) pubs j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) rj.draws
        = .ok df := hdef ▸ hdf
    exact (defineS_ok hdf').1.2.2.2
  -- the three slots' cube sums
  have hsp18 := fzc_cube U P D Pb Lay B hrl (slotShape P 18).1 (slotShape P 18).2.1 (by rw [hs18])
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) r.draws (pubs 18 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) r.draws)
    (hpub.fzcGrp _ _) (hpub.fzcGate _ _) (polyS U P D (progW16 cfgRungW16 ioIn ioOut) pubs 18 (seenOf bga rs 18))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 18 r hr x, slot18_eq])
  have hsp11 := gmm_sum U P D hX Pb Lay B ioIn ioOut pubs hpub hrl hs11 bga rs r11 hr11 (hcanon 11 r11 hr11)
  have hsp12 := umm_sum U P D hX Pb Lay B ioIn ioOut pubs hpub hrl hs12 bga rs r11 r12 hr11 hr12
    (hcanon 12 r12 hr12)
  have hz1 : segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 18) .zeta = 1 := rfl
  have hM : ∀ i : Fin 2, algM (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt 18 cu rt i
      = fun y => algebraMap GF K (relMm Pb Lay B (xtW U P D) 18 i (.f (splitF y))) := fun i => by
    rw [algM_mm (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt 18 cu rt i (fun h => absurd h.1 (by decide))]
    exact funext (hmm i)
  have hp0 : algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 18
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 0 = fun t => (r11.draws.getD t.val Fp2.zero).toK U := by
    funext t
    show algDrawAt U (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 11 t = _
    exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 11 t r11 (by norm_num) hr11
  have hp1 : algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 18
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 1 = fun t : Fin 15 => if (t : ℕ) < 5 then (r11.draws.getD t Fp2.zero).toK U
        else (r12.draws.getD ((t : ℕ) - 5) Fp2.zero).toK U := by
    funext t
    show (if (t : ℕ) < 5 then algDrawAt U (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 11 t
      else algDrawAt U (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 12 ((t : ℕ) - 5)) = _
    rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 11 t r11 (by norm_num) hr11,
      algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 12 _ r12 (by norm_num) hr12]
  rw [hostSp_Φ]
  unfold hostPhi
  unfold spSum
  rw [hsp18, hsp11, hsp12]
  refine congrArg₂ (fun x y : K => x - y) ?_ ?_
  · -- the host's sum
    refine Finset.sum_congr rfl (fun b _ => ?_)
    refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ b (fun a => ?_) ?_ (fun i => ?_) (fun i j => ?_) (fun i => ?_)
    · have ha : (a : ℕ) < 15 := a.isLt
      show segAt ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 18)
        (fun j => (fun i : Fin (P.draws 18) => (r.draws.getD i.val Fp2.zero).toK U)
          (Fin.cast ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).hsum 18 (by decide)) j)) .tau a = _
      unfold segAt
      rw [dite_eq_left (by show 10 + (a : ℕ) < 25; omega)]
      unfold tauF
      rw [drR_getD _ 18 10 15 a ha]
      rfl
    · refine fzc_batch U hU P D hX Pb Lay B hS hdr dt cu rt _ (fun κ b => hcl _ κ b) hpw (rs.take 18) r.draws b
        _ _ _ _ ?_ ?_ (fun κ => ?_)
      · dsimp only
        rw [ite_eq_left hz1]
        unfold segAt
        rw [dite_eq_left (by show 9 + 0 < 25; omega)]
        rfl
      · dsimp only
        rw [ite_eq_left hz1]
        unfold segAt
        rw [dite_eq_left (by show 0 + 6 < 25; omega)]
        rfl
      · have hκ : (κ : ℕ) < 6 := κ.isLt
        dsimp only
        unfold segAt
        rw [dite_eq_left (by show 0 + (κ : ℕ) < 25; omega)]
        simp only [Fin.val_cast]
        rw [show segOff ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 18) .mu = 0 from rfl, Nat.zero_add]
    · fin_cases i
      · dsimp only
        unfold segAt
        rw [dite_eq_left (by show 7 + 0 < 25; omega)]
        rfl
      · dsimp only
        unfold segAt
        rw [dite_eq_left (by show 7 + 1 < 25; omega)]
        rfl
    · have hj : (j : ℕ) < 15 := j.isLt
      fin_cases i
      · show algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 18
          (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 0 j = p0F U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2
            (rs.take 18)) 18 r.draws) j
        rw [hp0]
        show (r11.draws.getD j Fp2.zero).toK U = p0F U _ j
        unfold p0F
        rw [drR_getD _ 11 0 15 j hj, Nat.zero_add]
        exact (algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 11 j r11 (by norm_num) hr11).symm
      · show algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 18
          (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 1 j = p1F U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2
            (rs.take 18)) 18 r.draws) j
        rw [hp1]
        show (if (j : ℕ) < 5 then (r11.draws.getD j Fp2.zero).toK U
          else (r12.draws.getD ((j : ℕ) - 5) Fp2.zero).toK U) = p1F U _ j
        unfold p1F
        rw [List.map_append]
        have hl5 : ((drR 11 0 5).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws)).length = 5 := by
          rw [List.length_map, drR_length]
        by_cases h5 : (j : ℕ) < 5
        · rw [ite_eq_left h5, getD_app ((drR 11 0 5).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18
            r.draws)) ((drR 12 0 10).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws)) Fp2.zero j
            (by rw [hl5]; exact h5), drR_getD _ 11 0 5 j h5, Nat.zero_add]
          exact (algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 11 j r11 (by norm_num) hr11).symm
        · rw [ite_eq_right h5, getD_app_right ((drR 11 0 5).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18))
            18 r.draws)) ((drR 12 0 10).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws)) Fp2.zero j
            (by rw [hl5]; omega), hl5, drR_getD _ 12 0 10 ((j : ℕ) - 5) (by omega), Nat.zero_add]
          exact (algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 12 _ r12 (by norm_num) hr12).symm
    · rw [algH_gh U _ dt 18 cu rt _ i (fun h => absurd h.1 (by decide)), hgh i b]
      fin_cases i
      · exact (fzc_gh0 U P D hX Pb Lay B hS b _ _ _).symm
      · exact (fzc_gh1 U P D hX Pb Lay B hS b _ _ _).symm
  · -- the hosted sums
    rw [Fin.sum_univ_two, hM 0, hM 1, hp0, hp1]
    refine congrArg₂ (fun x y : K => x + y) (congrArg₂ (fun x y : K => x * y) ?_ ?_)
      (congrArg₂ (fun x y : K => x * y) ?_ ?_)
    · dsimp only
      unfold segAt
      rw [dite_eq_left (by show 7 + 0 < 25; omega)]
      rfl
    · rfl
    · dsimp only
      unfold segAt
      rw [dite_eq_left (by show 7 + 1 < 25; omega)]
      rfl
    · rfl

end Form

end ZK60.Exec.Block.Join.W16.Fzc
