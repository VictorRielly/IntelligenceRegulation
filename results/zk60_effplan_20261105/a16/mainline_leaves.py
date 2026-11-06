import collections, sys
sys.path.insert(0, sys.argv[2])
import sample_summary as ss
want = sys.argv[3]  # e.g. "assign" or "build"
kindw = sys.argv[4]  # serial / par
RAYON = ("rayon::iter::plumbing", "rayon_core::join", "rayon_core::registry::in_worker", "rayon::slice", "rayon::iter")
GPU = ("wait_done", "waitUntilCompleted", "wait_until_completed")
cnt = collections.Counter()
for header, nodes in ss.parse(sys.argv[1]):
    for st, c in ss.self_samples(nodes):
        if not any("witness::build_accuracy" in n for n in st):
            continue
        i = max(i for i, n in enumerate(st) if "witness::build_accuracy" in n)
        below = st[i + 1:]
        proj = [n for n in below if n.startswith(ss.PROJECT)]
        if not proj or not proj[0].endswith("accuracy::" + want):
            continue
        par = any(n.startswith(RAYON) for n in below)
        gpu = any(g in n for n in below for g in GPU)
        kind = "gpu" if gpu else ("par" if par else "serial")
        if kind != kindw:
            continue
        # the frames below the first project frame, compressed
        j = below.index(proj[0])
        tail = [n.split("::")[-1][:40] if n.startswith(ss.PROJECT) else n[:50] for n in below[j + 1:]]
        cnt[" > ".join(tail[-4:]) or "(self)"] += c
for k, c in cnt.most_common(30):
    print(f"{c*0.002:6.3f}  {k}")
