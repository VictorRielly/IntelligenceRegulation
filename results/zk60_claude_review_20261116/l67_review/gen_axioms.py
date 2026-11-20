import re
FM = '/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/'
OUTDIR = '/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l67_review/'
pat = re.compile(r'^(@\[[^\]]*\]\s*)?(private\s+|protected\s+)?(noncomputable\s+)?(theorem|lemma|def|abbrev|instance|structure|inductive|class|opaque|axiom)\s+([^\s({:\[]+)', re.M)
META = r'''
-- REVIEW APPENDIX (reviewer-generated; not in the original file): binder dump
section ReviewMeta
open Lean Meta Elab Command

def dumpSig (n : Name) (file : String) : MetaM Unit := do
  let ci ← getConstInfo n
  forallTelescope ci.type fun xs concl => do
    let mut s := s!"THEOREM {n} binders={xs.size}\n"
    for x in xs do
      let d ← x.fvarId!.getDecl
      let t ← ppExpr d.type
      s := s ++ s!"BINDER {d.userName} [{repr d.binderInfo}] :: {(toString t).replace "\n" " "}\n"
    let c ← ppExpr concl
    s := s ++ s!"CONCLUSION :: {(toString c).replace "\n" " "}\n"
    IO.FS.writeFile file s

run_cmd liftTermElabM do
  let D := "/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l67_review/"
  dumpSig `ZK60.ProtocolClassify.RunShapeP.sshC_productionReadyL_epP_pinsHd (D ++ "sig_pinsHd.txt")
  dumpSig `ZK60.ProtocolClassify.sshC_productionReadyL_epP_shieldInst (D ++ "sig_shieldInst.txt")

end ReviewMeta
'''
for fn, withmeta in (('RunShieldInstP', True), ('RunStgShieldLu', False)):
    src = FM + fn + '.lean'
    body = open(src).read()
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
    extra = META if withmeta else ''
    open(OUTDIR + fn + '_review_copy.lean', 'w').write(body[:idx] + '\n'.join(pr) + '\n' + extra + '\n' + body[idx:])
    open(OUTDIR + fn + '_decls.txt', 'w').write('\n'.join('%d %s %s%s' % (i, k, 'PRIVATE ' if p else '', n) for (i, k, p, n) in items) + '\n')
    thm = [x for x in items if x[1] in ('theorem', 'lemma')]
    print(fn, 'items', len(items), 'theorems', len(thm), 'public', sum(1 for x in items if not x[2]), 'private', sum(1 for x in items if x[2]))
