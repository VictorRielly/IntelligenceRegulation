/-
D63 lane L49 (2026-11-10), sub-agent `help`, part 4: **the helper layer's public-table premises at the lane's public
tables** `pubsR13L c Pb Lay B nG` (sub-agent `pub`'s `BlockR13HostPub.lean`), with `gL := gateLS c.sh`,
`exp := Pb.exp`, `act := Pb.act`.

* **`hrest19L`**, **`hrest20L`**: `helperR_formAt`'s `hrest19`, `hrest20` at any configuration (`pubsR13L_tab`);
* **`hgateL_rung`**, **`hgateL_shield`**: its `hgate` at the R13 rung and at every Shieldstral layer (symbolic in the
  layer), with `gL := gateLS c.sh` (`pubsR13L_three_getD`; `Dom::L` has `14` variables at both shapes).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13LookHelpR13
import ZK60Formal.BlockR13HostPub

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Help

open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Circuit (gP GF)
open ZK60.Layout

section Rest

variable (c : W16Cfg) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay) (nG : ℕ)

/-- **`hrest19` at the lane's public tables**: slot `19`'s tables are lane L47's `restR13`. -/
theorem hrest19L : ∀ hist dr i, Pub.pubsR13L c Pb Lay B nG 19 hist dr i = R13T.restR13 Pb.exp Pb.act nG 19 hist dr i :=
  fun hist dr i => Pub.pubsR13L_tab c Pb Lay B nG 19 (Or.inl rfl) hist dr i

/-- **`hrest20` at the lane's public tables**: slot `20`'s table is lane L47's all-ones table. -/
theorem hrest20L : ∀ hist dr, Pub.pubsR13L c Pb Lay B nG 20 hist dr 0 = R13T.restR13 Pb.exp Pb.act nG 20 hist dr 0 :=
  fun hist dr => Pub.pubsR13L_tab c Pb Lay B nG 20 (Or.inr rfl) hist dr 0

end Rest

section Gate

variable {K : Type} [Field K] [Algebra GF K] (U : K) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (nG : ℕ)

/-- **`hgate` at the R13 rung**, with `gL := gateLS` of the rung's shape (`supp(Dom::L)`). -/
theorem hgateL_rung
    (Lay : W16Layout S (CtR DefR13.cfgRungR13) (CwR DefR13.cfgRungR13) (CgR DefR13.cfgRungR13)
      (CjR DefR13.cfgRungR13) (CdR DefR13.cfgRungR13) (CfR DefR13.cfgRungR13)) (B : W16Pub S Pb Lay) :
    ∀ hist dr (b : Fin 14 → Bool),
      ((Pub.pubsR13L DefR13.cfgRungR13 Pb Lay B nG 3 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U
        = algebraMap GF K (Pub.gateLS DefR13.cfgRungR13.sh b) :=
  fun hist dr b => Pub.pubsR13L_three_getD DefR13.cfgRungR13 Pb Lay B nG U hist dr b

/-- **`hgate` at every Shieldstral layer** (symbolic in the layer), with `gL := gateLS` of the layer's shape. -/
theorem hgateL_shield (L : ZK60.RunShape.Shield.ShieldLayer)
    (Lay : W16Layout S (CtR (DefR13.cfgShieldR13 L)) (CwR (DefR13.cfgShieldR13 L)) (CgR (DefR13.cfgShieldR13 L))
      (CjR (DefR13.cfgShieldR13 L)) (CdR (DefR13.cfgShieldR13 L)) (CfR (DefR13.cfgShieldR13 L)))
    (B : W16Pub S Pb Lay) :
    ∀ hist dr (b : Fin 14 → Bool),
      ((Pub.pubsR13L (DefR13.cfgShieldR13 L) Pb Lay B nG 3 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U
        = algebraMap GF K (Pub.gateLS (DefR13.cfgShieldR13 L).sh b) :=
  fun hist dr b => Pub.pubsR13L_three_getD (DefR13.cfgShieldR13 L) Pb Lay B nG U hist dr b

end Gate

end ZK60.Exec.Block.Join.R13H.Help
