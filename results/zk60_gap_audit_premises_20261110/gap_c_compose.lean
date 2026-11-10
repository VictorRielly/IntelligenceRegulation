/-
Gap audit (premise register, 2026-11-10), scratch file C: the strongest statement the tree gives about the classify
run AT THE CODE'S VERIFIER SHAPE, by instantiation only: `rt_productionReady_r13` (L34) at
`V := classifyRunV … (d12aBlockProf …) …` (L29's executable stages, L18's D12a block profile) and
`Rn := rtRunClassify …` (L34's schedule at that verifier). No lane wrote this instantiation; it is checked here to type
without any new proof, and its remaining premises are printed. Never imported by the root.
-/
import ZK60Formal

set_option autoImplicit false
set_option pp.proofs false
set_option pp.maxSteps 10000000
set_option pp.deepTerms true
set_option pp.deepTerms.threshold 100000

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.ProtocolClassify
open ZK60.Exec.StageV (IncV OutcV StageGeom IncCtx classifyRunV)

section Compose

variable {S : ZK60.Block.BlockShape} {Hdr Salt Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra ZK60.Circuit.GF K]
variable (Rr dR : ℕ) {pos : S.Tok → Fin dR × Fin (2 ^ 14)} (hpos : Function.Injective pos)
  (place : Fin dR → Fin Rr) (msg : (S.Tok → ℕ) → Salt → Fin Rr → Fin (2 ^ 14) → ZK60.Circuit.GF)
  (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin Rr → Fin 256 → ZK60.Circuit.GF)
  (salt : Salt → Fin (2 ^ 16) → Dig) (path : Salt → Fin (2 ^ 16) → List Dig) (tagc : MTag)
  (Rp : ClassifyRunPublic S) (Lq : ℕ) (P : RunP Hdr (S.Tok → ℕ) Coins) (h64 : 64 ≤ Lq)
-- the code's run verifier: L29's executable stages and L18's D12a block profile
variable (L : ℕ) (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
  (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (Pk : ℕ → ZK60.Exec.Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → ZK60.Exec.Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → ZK60.Exec.Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List ZK60.Exec.Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List ZK60.Exec.Block.ZClaim → ZK60.Exec.Block.OpeningZk → Tr →
    Except String Tr)
-- L34's schedule premises at that verifier
variable (key : Option Dig) (domain : List UInt8) (hL20 : 2 ^ 20 ≤ Lq) (hdr : ClsStmt Hdr → List Op)
  (hdrLen hdrSq : ℕ)
  (hstart : ∀ (H : HIn → Dig) (s : ClsStmt Hdr), start H s = runOps H (Tr.newKeyed H domain key) (hdr s))
  (hhdr : ∀ s : ClsStmt Hdr, preA s.hdr = .ok () → preB s.hdr = .ok () →
    (hdr s).length = hdrLen ∧ ZK60.Exec.Link.sqN (hdr s) = hdrSq ∧ ∀ op ∈ hdr s, op.len ≤ Lq)
  (cx0 : IncCtx) (pin pout : RtPart) (I : RtInc Lq inc incG pin) (O : RtOutc Lq outc outcG pout) (pend : ℕ → ℕ)
  (hI : I.nOut = pend 1) (bp : ∀ k, RtBlk Lq (Pk k))
  (pX : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t)) (gX : ℕ → ℕ)
  (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom) (hgX : ∀ k s, (sgeom s k).incoming.1 = gX k)
  (hbp : ∀ k, (bp k).nOut = pend (k + 2)) (hO : pend (L + 1) + O.nIn + O.pX.rows = pout.wX)

/-- The run verifier of the code's shape. -/
abbrev gapV : RunV Hdr :=
  classifyRunV L preA preB start inc incG
    (ZK60.ProtocolClassify.d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG

/-- L34's schedule at that verifier. -/
noncomputable abbrev gapRn : RtRun (gapV L preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN
    bndCheck bndOpen) key domain Lq :=
  rtRunClassify L preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen key
    domain Lq hL20 hdr hdrLen hdrSq hstart hhdr cx0 pin pout I O pend hI bp pX gX hgeo hgX hbp hO

-- The top run theorem at the code's verifier shape and L34's schedule there: its type, with every premise still
-- left, as Lean prints it.
#check rt_productionReady_r13 (S := S) (Hdr := Hdr) (Salt := Salt) (Coins := Coins) (K := K) (Rr := Rr) (dR := dR)
  (hpos := hpos) (place := place) (msg := msg) (msg_place := msg_place) (pad := pad) (salt := salt) (path := path)
  (tagc := tagc) (Rp := Rp) (Lq := Lq)
  (V := gapV L preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen)
  (P := P) (h64 := h64) (key := key) (domain := domain)
  (Rn := gapRn Lq L preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen key
    domain hL20 hdr hdrLen hdrSq hstart hhdr cx0 pin pout I O pend hI bp pX gX hgeo hgX hbp hO)

#check @rtRunClassify

end Compose
