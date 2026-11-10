/- D63 lane L39 probe C (scratch): the definitions with binds and loops. -/
import ZK60Formal.StageVerifyExecInC
import ZK60Formal.StageVerifyExecOutC
import ZK60Formal.BlockInstRead
import ZK60Formal.ProtocolClassify

set_option autoImplicit false

open ZK60 ZK60.Exec ZK60.Exec.StageV ZK60.ProtocolClassify

def pcntC (df : Block.SlotDef) : ℕ × ℕ × ℕ × ℕ :=
  (Block.cmCount .a df.tabs, Block.cmCount .h df.tabs, Block.cmCount .inp df.tabs, Block.cmCount .out df.tabs)

theorem pc_of_map {x : Except String Block.SlotDef} {df : Block.SlotDef} {v : ℕ × ℕ × ℕ × ℕ} (h : x = .ok df)
    (hv : x.map pcntC = .ok v) : pcntC df = v := by
  subst h
  exact Except.ok.inj hv

set_option profiler true in
theorem pC_qzc (I : IncPub) (G : IncGeo) (cx : IncCtx) (dr : List Fp2) (df : Block.SlotDef)
    (h : incDefQZC I G cx dr = .ok df) : pcntC df = (1, 1, 0, 1) := by
  unfold incDefQZC at h
  obtain ⟨mu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨zeta, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  exact pc_of_map h rfl

set_option profiler true in
theorem pC_tzc_out (O : OutcPub) (G : OutcGeo) (dr : List Fp2) (df : Block.SlotDef)
    (h : outcDefTZC O G dr = .ok df) : pcntC df = (11, 0, 0, 0) := by
  unfold outcDefTZC at h
  obtain ⟨mu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨nu, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  obtain ⟨zeta, -, h⟩ := (ex_bind_ok_iff _ _ _).mp h
  exact pc_of_map h rfl
