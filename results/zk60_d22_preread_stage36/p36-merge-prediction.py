#!/usr/bin/env python3
"""What a CLEAN THREE-WAY MERGE of the lane tip and main would put in each of
the six files stage 36 moves -- so the security owner has a digest to compare
the integrator's tree against, and knows which one is not predictable.

Bases: fork 3811e55 (the lane's merge base with main), main 4751b93 (the tree
D22 pins), lane base fee1a8d, lane tip 29cba9a.

For a file only one side moved, the merge result is that side's blob and the
digest is certain. For a file BOTH sides moved, the merge result is a new blob;
this program constructs it only where the two changes are textually disjoint,
and says so.
"""
import hashlib
import subprocess

WT = "/home/victor/wt-zk60-block125m-review"
FORK, MAIN, BASE, TIP = "3811e55", "4751b93", "fee1a8d", "29cba9a"
MOVED = [
    "zkp-core/src/rng.rs",
    "zkp-core/src/transcript.rs",
    "hashline/src/private_block/protocol.rs",
    "hashline/src/private_block.rs",
    "zkp-core/Cargo.toml",
    "hashline/Cargo.toml",
]


def blob(commit, path):
    r = subprocess.run(["git", "--no-pager", "-C", WT, "show", f"{commit}:{path}"],
                       capture_output=True)
    return None if r.returncode else r.stdout


def sha(b):
    return hashlib.sha256(b).hexdigest()


for p in MOVED:
    f, m, b, t = (blob(c, p) for c in (FORK, MAIN, BASE, TIP))
    main_moved, lane_moved = (m != f), (t != f)
    print(p)
    print(f"   fork {sha(f)[:16]}  main {sha(m)[:16]}  base {sha(b)[:16]}  tip {sha(t)[:16]}")
    if not main_moved:
        print(f"   main never moved it since the fork -> a clean merge IS the tip:")
        print(f"   PREDICTED {sha(t)}")
    else:
        # both moved: try the disjoint-insertion case
        fl, ml, tl = f.decode().split("\n"), m.decode().split("\n"), t.decode().split("\n")
        import difflib
        ops = [o for o in difflib.SequenceMatcher(None, fl, ml).get_opcodes() if o[0] != "equal"]
        print(f"   BOTH moved it; main's change is {len(ops)} hunk(s) against the fork")
        merged = None
        if len(ops) == 1 and ops[0][0] == "insert":
            _, i1, i2, j1, j2 = ops[0]
            anchor_before, anchor_after = fl[i1 - 3:i1], fl[i1:i1 + 3]
            # locate the same anchor in the lane tip
            hits = [k for k in range(len(tl) - 3)
                    if tl[k:k + 3] == anchor_after and tl[k - 3:k] == anchor_before]
            if len(hits) == 1:
                k = hits[0]
                merged = tl[:k] + ml[j1:j2] + tl[k:]
                print(f"   main inserts {j2-j1} line(s) at a point the lane did not touch;")
                print(f"   the merge is the tip with those lines at line {k+1}:")
                for line in ml[j1:j2]:
                    print(f"      + {line}")
                text = "\n".join(merged).encode()
                print(f"   PREDICTED {sha(text)}")
            else:
                # the other clean case: the lane ALREADY made main's change
                block = ml[j1:j2]
                nb = len(block)
                already = any(tl[k:k + nb] == block and tl[k + nb:k + nb + 3] == fl[i1:i1 + 3]
                              for k in range(len(tl)))
                if already:
                    print("   the lane's tip ALREADY carries main's inserted lines, at the")
                    print("   same place -- both sides made the same change, so the merge is")
                    print("   the tip unchanged:")
                    for line in block:
                        print(f"      = {line}")
                    print(f"   PREDICTED {sha(t)}")
                else:
                    print(f"   the insertion point is not unique in the tip ({len(hits)} matches):"
                          " NOT PREDICTED")
        else:
            print("   main's change is not a single insertion: NOT PREDICTED here")
    print()
print("Every digest above is a PREDICTION of a clean three-way merge. The")
print("integrator states it assembles the lane as a fixed snapshot rather than")
print("merging the branch, so the tree it produces must be hashed as it is.")
