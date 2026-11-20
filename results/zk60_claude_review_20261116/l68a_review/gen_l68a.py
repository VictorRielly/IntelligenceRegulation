import re
SRC = '/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/RunShieldBlkInst.lean'
OUTDIR = '/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l68a_review/'
pat = re.compile(r'^(@\[[^\]]*\]\s*)?(private\s+|protected\s+)?(noncomputable\s+)?(theorem|lemma|def|abbrev|instance|structure|inductive|class|opaque|axiom)\s+([^\s({:\[]+)', re.M)
META = r'''
-- REVIEW APPENDIX (reviewer-generated; not in the original file)
section ReviewMeta
open Lean Meta Elab Command

def dumpSigP (n : Name) (file : String) : MetaM Unit := do
  let ci ← getConstInfo n
  forallTelescope ci.type fun xs concl => do
    let mut s := s!"THEOREM {n} binders={xs.size}\n"
    for x in xs do
      let d ← x.fvarId!.getDecl
      let t ← ppExpr d.type
      let isP ← isProp d.type
      s := s ++ s!"BINDER {d.userName} [{repr d.binderInfo}] prop={isP} :: {(toString t).replace "\n" " "}\n"
    let c ← ppExpr concl
    s := s ++ s!"CONCLUSION :: {(toString c).replace "\n" " "}\n"
    IO.FS.writeFile file s

run_cmd liftTermElabM do
  let D := "/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l68a_review/"
  let P := `ZK60.ProtocolClassify
  dumpSigP (P ++ `sshC_productionReadyL_epP_shieldLu) (D ++ "sigp_shieldLu.txt")
  dumpSigP (P ++ `sshC_productionReadyL_epP_blkLu) (D ++ "sigp_blkLu.txt")
  dumpSigP (P ++ `shdP_hzk) (D ++ "sigp_shdP_hzk.txt")
  dumpSigP (P ++ `shdP_shieldRunAtD) (D ++ "sigp_shdP_shieldRunAtD.txt")
  dumpSigP (P ++ `shdP_bitLay) (D ++ "sigp_shdP_bitLay.txt")
  dumpSigP (P ++ `shdP_hbij) (D ++ "sigp_shdP_hbij.txt")
  dumpSigP (P ++ `shdP_hU) (D ++ "sigp_shdP_hU.txt")
  dumpSigP (P ++ `shdP_clampPk_Pk0) (D ++ "sigp_shdP_clampPk_Pk0.txt")
  dumpSigP `ZK60.ZKHonest.runK_ref_cap_110 (D ++ "sigp_runK_ref_cap_110.txt")
  dumpSigP `ZK60.RunShape.Shield.shield_run_exists (D ++ "sigp_shield_run_exists.txt")
  let mut s := ""
  for n in [`shdP_Pk0, `shdP_bitLay, `shdP_w16Pub, `shdP_blkParams, `shdP_K, `shdP_U, `shdP_K_decidableEq, `shdP_K_fintype, `shdP_rowsOf, `shdP_slotKind, `shdP_clampPk, `shdP_runDomain, `shdP_rtRun, `shdP_wDelta] do
    let nm := P ++ n
    let st ← getReducibilityStatus nm
    s := s ++ s!"{nm} : {repr st}\n"
  IO.FS.writeFile (D ++ "reducibility.txt") s

end ReviewMeta
#check @ZK60.RunShape.Shield.shield_run_exists
#print ZK60.RunShape.Shield.ShieldRun
#print ZK60.Exec.msbBits
#print ZK60.Layout.W16Layout.dPos
#print ZK60.ProtocolClassify.shieldDPos0
#print ZK60.ProtocolClassify.shdP_clampPk
#print axioms ZK60.RunShape.Shield.shield_run_exists
#print axioms ZK60.ZKHonest.runK_ref_cap_110
#print axioms ZK60.ProtocolClassify.sshC_productionReadyL_epP_shieldLu
'''
body = open(SRC).read()
lines = body.split('\n')
items = []
for i, l in enumerate(lines, 1):
    m = pat.match(l)
    if m:
        items.append((i, m.group(4), bool(m.group(2) and 'private' in m.group(2)), 'ZK60.ProtocolClassify.' + m.group(5)))
idx = body.rindex('end ZK60.ProtocolClassify')
pr = ['', '-- REVIEW APPENDIX (reviewer-generated)']
for (i, k, p, n) in items:
    pr.append('#print axioms %s' % n)
open(OUTDIR + 'RunShieldBlkInst_review_copy.lean', 'w').write(body[:idx] + '\n'.join(pr) + '\n' + META + '\n' + body[idx:])
open(OUTDIR + 'RunShieldBlkInst_decls.txt', 'w').write('\n'.join('%d %s %s%s' % (i, k, 'PRIVATE ' if p else '', n) for (i, k, p, n) in items) + '\n')
print('items', len(items), 'public', sum(1 for x in items if not x[2]), 'private', sum(1 for x in items if x[2]))
for x in items: print(x)
