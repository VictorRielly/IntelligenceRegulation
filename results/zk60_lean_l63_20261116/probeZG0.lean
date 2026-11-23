import ZK60Formal.RunStgShieldClTopEF

/-! L63 leg 21 probe: binder names and kinds of the chain theorems (e explicit, i implicit, c instance, s strict). -/

open Lean Meta in
#eval show MetaM Unit from do
  let ns : List Name := [
    `ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkLu_cl,
    `ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkIO_cl,
    `ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkIOv_cl,
    `ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkCl,
    `ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkLO,
    `ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkOC,
    `ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkEF,
    `ZK60.ProtocolClassify.shd_hdinX_blk,
    `ZK60.ProtocolClassify.sshC_productionReadyL_epP_shieldLu_cl]
  for n in ns do
    let ci ← getConstInfo n
    forallTelescope ci.type fun xs _ => do
      let mut s := ""
      for x in xs do
        let d ← x.fvarId!.getDecl
        let k := match d.binderInfo with
          | .default => "e" | .implicit => "i" | .instImplicit => "c" | .strictImplicit => "s"
        s := s ++ s!"{d.userName}:{k} "
      IO.println s!"SIG {n}: {s}"
