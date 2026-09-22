#!/usr/bin/env python3
"""Three-way digest table: main 4751b93 vs lane base fee1a8d vs lane tip 29cba9a.

Independent of the lane's own scripts: it asks git for each blob and hashes it
here.  The pin set is read from the PINNED tools in the joint-view worktree.
"""
import hashlib
import subprocess
import sys

WT = "/home/victor/wt-zk60-block125m-review"
MAIN, BASE, TIP = "4751b93", "fee1a8d", "29cba9a"

sys.path.insert(0, "/home/victor/wt-zk60-jointview/scripts")
import zk60_native_mask_commit as mc  # noqa: E402
import zk60_native_terminal_polys as tp  # noqa: E402


def paths(pins):
    out = []
    for p in pins:
        out.append(p[0] if isinstance(p, (tuple, list)) else p)
    return out


def blob(commit, path):
    r = subprocess.run(["git", "--no-pager", "-C", WT, "show", f"{commit}:{path}"],
                       capture_output=True)
    if r.returncode != 0:
        return None
    return r.stdout


def dig(b):
    return "-" * 8 if b is None else hashlib.sha256(b).hexdigest()


mask_source = paths(mc.SOURCE_PINS)
mask_path = paths(mc.PATH_PINS)
term = paths(tp.SOURCE_PINS)
pinned = []
for p in mask_source + mask_path + term:
    if p not in pinned:
        pinned.append(p)

extra = ["zkp-core/Cargo.toml", "hashline/Cargo.toml",
         "hashline/src/private_block/endpoint_g.rs",
         "hashline/src/private_block/s25_tests.rs",
         "hashline/src/private_block/draw_observer.rs",
         "hashline/src/private_block/s36_tests.rs"]

print(f"pinned paths: {len(pinned)} (mask SOURCE {len(mask_source)} + PATH {len(mask_path)} "
      f"+ terminal {len(term)} deduped)")
print()
hdr = f"{'path':52} {'main 4751b93':16} {'base fee1a8d':16} {'tip 29cba9a':16}  verdict"
print(hdr)
print("-" * len(hdr))
rows = []
for p in pinned + extra:
    bm, bb, bt = blob(MAIN, p), blob(BASE, p), blob(TIP, p)
    dm, db, dt = dig(bm), dig(bb), dig(bt)
    tag = "PINNED" if p in pinned else "unpinned"
    if db == dt:
        moved = "unchanged by delta"
    else:
        moved = "MOVED BY DELTA"
    if dm == db:
        base = "base==main"
    else:
        base = "base!=main"
    rows.append((p, dm, db, dt, tag, moved, base))
    print(f"{p:52} {dm[:16]} {db[:16]} {dt[:16]}  {tag} / {base} / {moved}")

print()
print("summary")
print("  pinned files moved by the delta :",
      sum(1 for r in rows if r[4] == "PINNED" and r[5] == "MOVED BY DELTA"))
print("  pinned files whose lane base differs from main 4751b93 :",
      sum(1 for r in rows if r[4] == "PINNED" and r[6] == "base!=main"))
for r in rows:
    if r[4] == "PINNED" and r[6] == "base!=main":
        print("     base!=main:", r[0])
print("  ALSO_ACCEPTED entries:", list(mc.ALSO_ACCEPTED))
