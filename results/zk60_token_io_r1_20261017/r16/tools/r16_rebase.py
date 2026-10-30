#!/usr/bin/env python3
"""Token round 16 (1): rebase frozen-r15 (token tree on native R12b) onto native R13.

Recipe (round 13's tools/r13_rebase.py, base and target moved):
  * DEST = a copy of the frozen-r15 copy (results/.../frozen-r15/, exactly manifest_final_r15's 259 files);
  * every native file changed R12b -> R13 that the token lane never touched (DEST == R12b) is copied as frozen
    R13; files added in R13 are copied; files removed in R13 and untouched by the token lane are removed;
  * every file both sides changed is merged with `diff3 -m DEST R12b R13`; conflicts are left marked and listed
    in the report for hand resolution.

Usage: r16_rebase.py plan|apply  (plan writes the report only; apply also writes DEST).
Report: results/zk60_token_io_r1_20261017/r16/rebase_{plan,applied}.json
"""
import hashlib, json, os, shutil, subprocess, sys, datetime

REPO = "/home/victor/IntelligenceRegulation"
SRC = f"{REPO}/results/zk60_token_io_r1_20261017/frozen-r15"  # the immutable frozen-r15 copy (== manifest_final_r15)
DEST = f"{REPO}/ops/zkp-mvp/token-io-r16"
NAT = f"{REPO}/results/zk60_1b_native_20261017"
BASE = f"{NAT}/r12b/frozen-tree"
NEW = f"{NAT}/r13/frozen-tree"
OUT = f"{REPO}/results/zk60_token_io_r1_20261017/r16"
FROZEN_R15 = f"{REPO}/results/zk60_token_io_r1_20261017/manifest_final_r15.sha256"
SKIP_DIRS = {"target"}


def tree(root, skip_pid_dirs=False):
    out = {}
    for d, ds, fs in os.walk(root):
        keep = []
        for x in sorted(ds):
            if x in SKIP_DIRS:
                continue
            rel = os.path.relpath(os.path.join(d, x), root)
            # native tests' pid-named evidence dirs (not source; excluded from every token manifest)
            if skip_pid_dirs and rel.startswith("hashline/results/") and (
                    x.startswith("r12-tied-") or x.startswith("r12b-")):
                continue
            keep.append(x)
        ds[:] = keep
        for f in fs:
            p = os.path.join(d, f)
            if os.path.islink(p) or not os.path.isfile(p):
                raise SystemExit(f"not a regular file: {p}")
            rel = os.path.relpath(p, root)
            if skip_pid_dirs and rel == "BASELINE.sha256":
                continue
            out[rel] = hashlib.sha256(open(p, "rb").read()).hexdigest()
    return out


def frozen_r15_files():
    out = {}
    for line in open(FROZEN_R15):
        line = line.rstrip("\n")
        if not line:
            continue
        h, p = line.split(None, 1)
        out[p.lstrip("*").lstrip("./")] = h
    return out


def main():
    mode = sys.argv[1]
    assert mode in ("plan", "apply")
    mb = json.load(open(f"{NAT}/r12b/manifest_frozen.json"))
    mn = json.load(open(f"{NAT}/r13/manifest_frozen.json"))
    tb, tn = tree(BASE), tree(NEW)
    assert tb == mb["files"], "R12b frozen tree does not match its manifest"
    assert tn == mn["files"], "R13 frozen tree does not match its manifest"
    tsrc_all = tree(SRC, skip_pid_dirs=True)
    fr15 = frozen_r15_files()
    # the source tree must be exactly frozen-r15's files
    diff = {f for f in set(fr15) | set(tsrc_all) if fr15.get(f) != tsrc_all.get(f)}
    if diff:
        raise SystemExit(f"the frozen-r15 copy differs from its manifest at {sorted(diff)[:10]} (+{max(0, len(diff) - 10)})")
    tsrc = tsrc_all
    native = sorted(set(tb) | set(tn))
    actions = {"copy_new": [], "add_new": [], "remove": [], "merge": [], "keep_token": [],
               "unchanged": [], "conflict_add": [], "conflict_remove": []}
    for f in native:
        a, b, s = tb.get(f), tn.get(f), tsrc.get(f)
        if a == b:
            actions["unchanged" if s == a else "keep_token"].append(f)
        elif a is None:  # added in R13
            if s is None:
                actions["add_new"].append(f)
            elif s == b:
                actions["unchanged"].append(f)
            else:
                actions["conflict_add"].append(f)
        elif b is None:  # removed in R13
            if s == a:
                actions["remove"].append(f)
            elif s is None:
                actions["unchanged"].append(f)
            else:
                actions["conflict_remove"].append(f)
        else:  # changed R12b -> R13
            if s == a:
                actions["copy_new"].append(f)
            elif s == b:
                actions["unchanged"].append(f)
            else:
                actions["merge"].append(f)
    token_only = sorted(set(tsrc) - set(native))
    os.makedirs(OUT, exist_ok=True)
    report = {
        "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "mode": mode, "src": SRC, "dest": DEST,
        "src_equals_frozen_r15": True, "src_files": len(tsrc),
        "base_tree_r12b": mb["tree_sha256"], "new_tree_r13": mn["tree_sha256"],
        "native_changed_r12b_to_r13": sum(1 for f in native if tb.get(f) != tn.get(f)),
        "token_only_files": len(token_only),
        "counts": {k: len(v) for k, v in actions.items()},
        "actions": {k: v for k, v in actions.items() if k != "unchanged"},
    }
    if mode == "apply":
        if os.path.exists(DEST):
            raise SystemExit(f"{DEST} exists; refusing to overwrite")
        os.makedirs(DEST)
        for f in sorted(tsrc):
            os.makedirs(os.path.dirname(f"{DEST}/{f}"), exist_ok=True)
            shutil.copyfile(f"{SRC}/{f}", f"{DEST}/{f}")
        assert tree(DEST) == tsrc
        merged = {}
        for f in actions["copy_new"] + actions["add_new"]:
            os.makedirs(os.path.dirname(f"{DEST}/{f}"), exist_ok=True)
            shutil.copyfile(f"{NEW}/{f}", f"{DEST}/{f}")
        for f in actions["remove"]:
            os.remove(f"{DEST}/{f}")
        for f in actions["merge"]:
            r = subprocess.run(["diff3", "-m", "-L", "token", "-L", "r12b", "-L", "r13",
                                f"{SRC}/{f}", f"{BASE}/{f}", f"{NEW}/{f}"],
                               capture_output=True)
            if r.returncode not in (0, 1):
                raise SystemExit(f"diff3 failed on {f}: {r.stderr!r}")
            open(f"{DEST}/{f}", "wb").write(r.stdout)
            merged[f] = {"conflicts": r.stdout.count(b"\n<<<<<<< token") + r.stdout.startswith(b"<<<<<<< token"),
                         "clean": r.returncode == 0}
        report["merged"] = merged
        report["dest_files"] = len(tree(DEST))
    name = "rebase_plan.json" if mode == "plan" else "rebase_applied.json"
    json.dump(report, open(f"{OUT}/{name}", "w"), indent=1)
    print(json.dumps({k: report[k] for k in report if k != "actions"}, indent=1))
    for k in ("merge", "conflict_add", "conflict_remove", "remove", "add_new", "keep_token"):
        print(k, actions[k])


if __name__ == "__main__":
    main()
