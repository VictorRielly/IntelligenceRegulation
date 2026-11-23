import ZK60Formal
/-! L63 leg 21 probe (from leg 19's probeTY19; untracked): dump the 23 tops' elaborated types (raw `Expr` text and hash, as
leg 17's probeTY), plus the 15 declarations of finding L68b-3 and the three contracts (type, and for the contracts the
value), pretty-printed, so the repair under ruling L63-10 can be compared before and after. OUTPATH below. -/
open Lean Meta Elab Command in
#eval show CommandElabM Unit from do
  let env ← getEnv
  let tops : List Name := [
    ``ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_blkAlive,
    ``ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_pinsHd,
    ``ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_dz,
    ``ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_pdz,
    ``ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_io,
    ``ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_trI,
    ``ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_trO,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_shieldInst,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_shieldJ,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_shieldLu,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkLu,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkIO,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkIOv,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkIOl,
    ``ZK60.ProtocolClassify.shd_hdinX_blk,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkIOd,
    ``ZK60.ProtocolClassify.RunShapeP.rc_productionReadyL_runChainP_some_range_cl,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkIOv_cl,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkLu_cl,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkIO_cl,
    ``ZK60.ProtocolClassify.cl_agree,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkCl,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkLO,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkOC,
    ``ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkEF,
    ``ZK60.ProtocolClassify.shdP_blkParams,
    ``ZK60.ProtocolClassify.shdP_slotKind]
  let mut out := ""
  for n in tops do
    let some ci := env.find? n | throwError "missing {n}"
    let ty := ci.type
    out := out ++ s!"### {n} hash {ty.hash} len {(toString ty).length}\n{toString ty}\n"
  IO.FS.writeFile "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a8b5788916259e1b2/results/zk60_lean_l63_20261116/tops_types_zg_after.txt" out
  logInfo m!"written after"
