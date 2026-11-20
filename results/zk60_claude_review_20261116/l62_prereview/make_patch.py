#!/usr/bin/env python3
"""L62 pre-review: unified diff from the original formal/ZK60Formal/RunBlkShieldInst.lean to the repaired scratch copy
(worktree agent-a8b5788916259e1b2, formal/ZK60Formal/L62Scratch2.lean), written to l62_fix.patch with the original's
sha256 in the header. The patch is a proposal; it is not applied anywhere.

usage: make_patch.py [scratch_path]
"""
import difflib
import hashlib
import sys

ORIG = '/Users/victorrielly/IntelligenceRegulation/formal/ZK60Formal/RunBlkShieldInst.lean'
SCR = (sys.argv[1] if len(sys.argv) > 1 else
       '/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a8b5788916259e1b2/formal/ZK60Formal/'
       'L62Scratch2.lean')
OUT = '/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l62_prereview/l62_fix.patch'
EXPECT = 'c68a7c490561a309924eb89984ea3701ef025d630b5fea36c3cb182701a4249c'

ob = open(ORIG, 'rb').read()
sb = open(SCR, 'rb').read()
oh, sh = hashlib.sha256(ob).hexdigest(), hashlib.sha256(sb).hexdigest()
if oh != EXPECT:
    print('WARNING: original changed since the pre-review started:', oh)
diff = difflib.unified_diff(ob.decode('utf-8').splitlines(keepends=True), sb.decode('utf-8').splitlines(keepends=True),
                            fromfile='a/formal/ZK60Formal/RunBlkShieldInst.lean',
                            tofile='b/formal/ZK60Formal/RunBlkShieldInst.lean')
with open(OUT, 'w', encoding='utf-8') as f:
    f.write('# L62 pre-review patch (Claude, 2026-11-16). Proposal only; not applied.\n')
    f.write('# original sha256 %s\n' % oh)
    f.write('# patched  sha256 %s (scratch copy %s)\n' % (sh, SCR.rsplit('/', 1)[1]))
    f.write('# apply from the repository root: git apply --check <this file>, then git apply\n')
    f.writelines(diff)
print('wrote', OUT, 'orig', oh, 'patched', sh)
