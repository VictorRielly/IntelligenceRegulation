#!/usr/bin/env python3
"""Preserve uncommitted work as a commit on a snapshot branch.

Uses a temporary index: the working tree, the real index and the current
branch are never touched. Tree = HEAD plus every modified/untracked
(non-ignored) file up to LIMIT bytes, minus deleted files. Larger files are
left out and listed with size and sha256 in MANIFEST (a sha256 is reused from
the previous snapshot's manifest when the size matches and the file has not
been modified since that snapshot). The new commit's parent is the previous
snapshot commit, so the branch is a chain of snapshots.

usage: snapshot_uncommitted.py "<message>" [--push] [--dry-run]
"""
import hashlib
import json
import os
import subprocess
import sys
import tempfile

REPO = "/home/victor/IntelligenceRegulation"
BRANCH = "snapshot/20261017-uncommitted"
MANIFEST = "SNAPSHOT_20261017_EXCLUDED_LARGE_FILES.json"
LIMIT = 1 << 20


def git(*args, env=None, input=None):
    r = subprocess.run(["git", "--no-pager", *args], cwd=REPO, env=env,
                       input=input, capture_output=True)
    if r.returncode != 0:
        sys.exit(f"git {' '.join(args[:3])} failed ({r.returncode}): "
                 f"{r.stderr.decode('utf-8', 'replace')[:2000]}")
    return r.stdout


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 22), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    msg = sys.argv[1]
    push = "--push" in sys.argv
    dry = "--dry-run" in sys.argv
    prev = git("rev-parse", BRANCH).decode().strip()
    prev_time = int(git("show", "-s", "--format=%ct", prev).decode().strip())
    try:
        old = json.loads(git("show", f"{prev}:{MANIFEST}"))
        old_sha = {e["path"]: (e["bytes"], e["sha256"]) for e in old["excluded"]}
    except subprocess.CalledProcessError:
        old_sha = {}

    raw = git("status", "--porcelain=v1", "-z", "--untracked-files=all")
    entries = raw.split(b"\0")
    add, remove, skipped_dirs, skipped_build, skipped_private = [], [], [], [], []
    i = 0
    while i < len(entries):
        e = entries[i].decode("utf-8", "surrogateescape")
        i += 1
        if not e:
            continue
        xy, path = e[:2], e[3:]
        if xy[0] in "RC":          # rename/copy: next entry is the source
            i += 1
        if path.endswith("/"):     # nested repository shown as a directory
            skipped_dirs.append(path)
            continue
        if any(c == "target" or c.startswith("target-")
               for c in path.split("/")[:-1]):   # cargo build output
            skipped_build.append(path)
            continue
        # owner decommitments (token I/O `prove`) hold hidden prompt/output
        # values in clear: never retained in a snapshot (D21; review TR4-3)
        if any(c.endswith("owner-private") for c in path.split("/")[:-1]) \
                or path.endswith(".dec"):
            skipped_private.append(path)
            continue
        if "D" in xy and not os.path.lexists(os.path.join(REPO, path)):
            remove.append(path)
        else:
            add.append(path)

    small, excluded, reused = [], [], 0
    for p in add:
        full = os.path.join(REPO, p)
        if os.path.islink(full) or not os.path.isfile(full):
            small.append(p)
            continue
        st = os.stat(full)
        if st.st_size <= LIMIT:
            small.append(p)
            continue
        o = old_sha.get(p)
        if o and o[0] == st.st_size and st.st_mtime < prev_time:
            digest = o[1]
            reused += 1
        else:
            digest = sha256(full)
        excluded.append({"path": p, "bytes": st.st_size, "sha256": digest})
    excluded.sort(key=lambda e: e["path"])
    print(f"add {len(small)} small files, remove {len(remove)}, exclude "
          f"{len(excluded)} large ({reused} sha256 reused), "
          f"skipped nested repos {len(skipped_dirs)}, build outputs "
          f"{len(skipped_build)}, owner-private files {len(skipped_private)}")
    if dry:
        return

    with tempfile.TemporaryDirectory() as td:
        env = dict(os.environ, GIT_INDEX_FILE=os.path.join(td, "index"))
        git("read-tree", "HEAD", env=env)
        # lanes write and delete scratch files while this runs: re-check
        # existence right before the add, and ignore files that still vanish
        small = [p for p in small if os.path.lexists(os.path.join(REPO, p))]
        if small:
            git("add", "-f", "--ignore-errors", "--pathspec-from-file=-",
                "--pathspec-file-nul", env=env,
                input=b"\0".join(p.encode("utf-8", "surrogateescape")
                                 for p in small))
        if remove:
            git("update-index", "--remove", "-z", "--stdin", env=env,
                input=b"\0".join(p.encode("utf-8", "surrogateescape")
                                 for p in remove))
        body = json.dumps({"limit_bytes": LIMIT, "excluded": excluded},
                          indent=1).encode() + b"\n"
        blob = git("hash-object", "-w", "--stdin", input=body).decode().strip()
        git("update-index", "--add", "--cacheinfo",
            f"100644,{blob},{MANIFEST}", env=env)
        tree = git("write-tree", env=env).decode().strip()
    if tree == git("rev-parse", f"{prev}^{{tree}}").decode().strip():
        print("tree unchanged since the previous snapshot; nothing to do")
        return
    commit = git("commit-tree", tree, "-p", prev, "-m", msg).decode().strip()
    git("update-ref", f"refs/heads/{BRANCH}", commit, prev)
    print(f"{BRANCH}: {prev[:7]} -> {commit[:7]} (tree {tree[:7]})")
    if push:
        r = subprocess.run(["git", "push", "origin", BRANCH], cwd=REPO,
                           capture_output=True, text=True)
        print(r.stdout + r.stderr)
        sys.exit(r.returncode)


if __name__ == "__main__":
    main()
