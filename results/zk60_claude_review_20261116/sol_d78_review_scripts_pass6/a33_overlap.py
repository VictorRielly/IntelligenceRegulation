"""Pass-6 G: for the six A33 files, compare snapshot 188 (Sol's base), snapshot 363 (Sol's latest) and the working tree. (read-only)"""
import hashlib, os, difflib
R = '/Users/victorrielly/IntelligenceRegulation'
B = R + '/results/zk60_sol_20261105_w16r3/b3/'
WT = R + '/ops/zkp-mvp/gpu-metal/hashline/src/private_block/'
S = lambda t: B + f'source-d78-{t}/hashline/src/private_block/'
def lines(p): return open(p, errors='replace').read().splitlines()
for n in ['protocol.rs', 'trained_block.rs', 'witness.rs', 'witness_accuracy.rs', 'r6_tests.rs', 'run_fork_tests.rs']:
    a, c, w = lines(S('188') + n), lines(S('363') + n), lines(WT + n)
    def ndiff(x, y): return sum(1 for l in difflib.unified_diff(x, y, lineterm='', n=0) if l[:1] in '+-' and l[:3] not in ('+++', '---'))
    print(n, 'lines 188/363/wt', len(a), len(c), len(w), '| changed lines: Sol(188->363)', ndiff(a, c), '| main(188->wt)', ndiff(a, w), '| 363->wt', ndiff(c, w))
