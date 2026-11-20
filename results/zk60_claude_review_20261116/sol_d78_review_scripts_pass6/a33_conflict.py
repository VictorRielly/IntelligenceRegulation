"""Pass-6 G: do 385's pins touch the six A33 working-tree paths, and how far have the snapshot source trees drifted from the working tree? (read-only)"""
import json, os, hashlib, collections
R = '/Users/victorrielly/IntelligenceRegulation'
B = R + '/results/zk60_sol_20261105_w16r3/b3/'
pins = json.load(open(B + 'D78_INDEPENDENT_INTEGRATION_REVIEW_385.json'))['pins']
WT = R + '/ops/zkp-mvp/gpu-metal/hashline/src/private_block/'
six = ['protocol.rs', 'trained_block.rs', 'witness.rs', 'witness_accuracy.rs', 'r6_tests.rs', 'run_fork_tests.rs']
sha = lambda p: hashlib.sha256(open(p, 'rb').read()).hexdigest()
# 1. any pin path inside the working tree?
inside = [k for k in pins if os.path.isabs(k) and '/ops/zkp-mvp/' in k]
print('absolute pins under ops/zkp-mvp:', inside[:5], len(inside))
rs_abs = [k for k in pins if os.path.isabs(k) and k.endswith('.rs')]
print('absolute .rs pins:', rs_abs[:5], len(rs_abs))
# 2. which pinned relative .rs files have a basename equal to the six, and where
for n in six:
    hits = [k for k in pins if k.endswith('/' + n) or k == n]
    print(n, 'pinned copies', len(hits), sorted(set(k.split('/')[0] for k in hits)))
# 3. drift: the latest source tree (363) vs the working tree, for the six and overall
root = B + 'source-d78-363/hashline/src/private_block/'
print('363 tree private_block exists', os.path.isdir(root))
for n in six:
    a, b = root + n, WT + n
    print(n, 'snapshot363', sha(a)[:12] if os.path.exists(a) else 'absent', 'working-tree', sha(b)[:12] if os.path.exists(b) else 'absent',
          'SAME' if os.path.exists(a) and os.path.exists(b) and sha(a) == sha(b) else 'DIFFERENT')
# overall drift of src/ tree
sroot = B + 'source-d78-363/hashline/src/'
wroot = R + '/ops/zkp-mvp/gpu-metal/hashline/src/'
diff = same = only_snap = 0
dl = []
for dp, _, fs in os.walk(sroot):
    for f in fs:
        a = os.path.join(dp, f); rel = os.path.relpath(a, sroot); b = wroot + rel
        if not os.path.exists(b): only_snap += 1; dl.append(('snapshot-only', rel)); continue
        if sha(a) == sha(b): same += 1
        else: diff += 1; dl.append(('differs', rel))
wt_only = [os.path.relpath(os.path.join(dp, f), wroot) for dp, _, fs in os.walk(wroot) for f in fs if not os.path.exists(sroot + os.path.relpath(os.path.join(dp, f), wroot))]
print('src/: same', same, 'differs', diff, 'snapshot-only', only_snap, 'working-tree-only', len(wt_only))
print([x for x in dl][:40])
print('wt-only', wt_only[:20])
