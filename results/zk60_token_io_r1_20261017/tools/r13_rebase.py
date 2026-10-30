#!/usr/bin/env python3
"""Token round 13 (A): rebase the R-C1 working tree onto native R12b.

Recipe (round 12's rebase probe, recorded in PROGRESS.md 2026-10-26 18:20):
  * DEST = a copy of the R-C1 working tree (ops/zkp-mvp/token-io/) without target dirs;
  * every native file changed R8 -> R12b that the token lane never touched (DEST == R8)
    is copied as frozen R12b; files added in R12b are copied; files removed in R12b
    and untouched by the token lane are removed;
  * every file both sides changed is merged with `diff3 -m DEST R8 R12b`; conflicts are
    left marked and listed in the report for hand resolution.

Usage: r13_rebase.py plan|apply  (plan writes the report only; apply also writes DEST).
Report: results/zk60_token_io_r1_20261017/r13/rebase_{plan,applied}.json
"""
import hashlib, json, os, shutil, subprocess, sys, datetime

REPO = "/home/victor/IntelligenceRegulation"
SRC = f"{REPO}/ops/zkp-mvp/token-io"
DEST = f"{REPO}/ops/zkp-mvp/token-io-r12b"
NAT = f"{REPO}/results/zk60_1b_native_20261017"
R8 = f"{NAT}/r8/frozen-tree"
R12B = f"{NAT}/r12b/frozen-tree"
OUT = f"{REPO}/results/zk60_token_io_r1_20261017/r13"


def tree(root):
    out = {}
    for d, ds, fs in os.walk(root):
        ds[:] = sorted(x for x in ds if x != "target")
        for f in fs:
            p = os.path.join(d, f)
            if os.path.islink(p) or not os.path.isfile(p):
                raise SystemExit(f"not a regular file: {p}")
            out[os.path.relpath(p, root)] = hashlib.sha256(open(p, "rb").read()).hexdigest()
    return out


def main():
    mode = sys.argv[1]
    assert mode in ("plan", "apply")
    m8 = json.load(open(f"{NAT}/r8/manifest_frozen.json"))["files"]
    m12b = json.load(open(f"{NAT}/r12b/manifest_frozen.json"))["files"]
    t8, t12b, tsrc = tree(R8), tree(R12B), tree(SRC)
    assert t8 == m8, "R8 frozen tree does not match its manifest"
    assert t12b == m12b, "R12b frozen tree does not match its manifest"
    native = sorted(set(t8) | set(t12b))
    actions = {"copy_r12b": [], "add_r12b": [], "remove": [], "merge": [], "keep_token": [],
               "unchanged": [], "conflict_add": [], "conflict_remove": []}
    for f in native:
        a, b, s = t8.get(f), t12b.get(f), tsrc.get(f)
        if a == b:
            actions["unchanged" if s == a else "keep_token"].append(f)
        elif a is None:  # added in R12b
            if s is None:
                actions["add_r12b"].append(f)
            elif s == b:
                actions["unchanged"].append(f)
            else:
                actions["conflict_add"].append(f)
        elif b is None:  # removed in R12b
            if s == a:
                actions["remove"].append(f)
            elif s is None:
                actions["unchanged"].append(f)
            else:
                actions["conflict_remove"].append(f)
        else:  # changed R8 -> R12b
            if s == a:
                actions["copy_r12b"].append(f)
            elif s == b:
                actions["unchanged"].append(f)
            else:
                actions["merge"].append(f)
    token_only = sorted(set(tsrc) - set(native))
    os.makedirs(OUT, exist_ok=True)
    report = {
        "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "mode": mode, "src": SRC, "dest": DEST,
        "r8_tree": "7f64276a… (r8/manifest_frozen.json)",
        "r12b_tree": json.load(open(f"{NAT}/r12b/manifest_frozen.json"))["tree_sha256"],
        "native_changed_r8_to_r12b": sum(1 for f in native if t8.get(f) != t12b.get(f)),
        "token_files": len(tsrc), "token_only_files": len(token_only),
        "counts": {k: len(v) for k, v in actions.items()},
        "actions": {k: v for k, v in actions.items() if k != "unchanged"},
    }
    if mode == "apply":
        if os.path.exists(DEST):
            raise SystemExit(f"{DEST} exists; refusing to overwrite")
        shutil.copytree(SRC, DEST, symlinks=False,
                        ignore=shutil.ignore_patterns("target"))
        assert tree(DEST) == tsrc
        merged = {}
        for f in actions["copy_r12b"] + actions["add_r12b"]:
            os.makedirs(os.path.dirname(f"{DEST}/{f}"), exist_ok=True)
            shutil.copyfile(f"{R12B}/{f}", f"{DEST}/{f}")
        for f in actions["remove"]:
            os.remove(f"{DEST}/{f}")
        for f in actions["merge"]:
            r = subprocess.run(["diff3", "-m", "-L", "token", "-L", "r8", "-L", "r12b",
                                f"{SRC}/{f}", f"{R8}/{f}", f"{R12B}/{f}"],
                               capture_output=True)
            if r.returncode not in (0, 1):
                raise SystemExit(f"diff3 failed on {f}: {r.stderr!r}")
            open(f"{DEST}/{f}", "wb").write(r.stdout)
            merged[f] = {"conflicts": r.stdout.count(b"\n<<<<<<< token"),
                         "clean": r.returncode == 0}
        report["merged"] = merged
        report["dest_files"] = len(tree(DEST))
    name = "rebase_plan.json" if mode == "plan" else "rebase_applied.json"
    json.dump(report, open(f"{OUT}/{name}", "w"), indent=1)
    print(json.dumps({k: report[k] for k in report if k != "actions"}, indent=1))
    for k in ("merge", "conflict_add", "conflict_remove", "remove", "add_r12b", "keep_token"):
        print(k, actions[k])


if __name__ == "__main__":
    main()
