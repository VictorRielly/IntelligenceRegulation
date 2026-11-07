import ZK60Formal.LinkW16Parse

-- D63 lane L22 scratch (not part of the library): the shape of `blockVerify` after the slot phase.
namespace ZK60.Exec.Link
open ZK60.Exec

example (H : HIn → Dig) (P : Block.BlockParams) (core : Block.Core) (t : Tr)
    (io : List Block.ZClaim × List Block.ZClaim) (t' : Tr) (h : Block.blockVerify H P core t = .ok (io, t')) :
    False := by
  unfold Block.blockVerify at h
  obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
  obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
  obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
  obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
  obtain ⟨⟨bga, rs, acc, tM⟩, hbs, h⟩ := Block.ex_bind_ok h
  dsimp only at h
  fail "state after the slot phase"

end ZK60.Exec.Link
