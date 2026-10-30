#!/usr/bin/env python3
"""Token round 16: what the candidate r16A changes against frozen-r15, and which native R13 files the token tree
differs in (with diff line counts). Writes r16/r16A_vs_frozen_r15.txt and r16/token_vs_native_r13.txt (+ unified
diffs .diff)."""
import difflib, json, os
R = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017"
T = R + "/r16"
TREE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r16"
F15 = R + "/frozen-r15"
N13 = "/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/frozen-tree"


def load(p):
    m = {}
    for line in open(p):
        line = line.rstrip("\n")
        if line:
            d, rel = line.split("  ", 1)
            m[rel] = d
    return m


def udiff(a_path, b_path, rel, la, lb):
    a = open(a_path, encoding="utf-8", errors="replace").read().splitlines(keepends=True) if a_path else []
    b = open(b_path, encoding="utf-8", errors="replace").read().splitlines(keepends=True) if b_path else []
    d = list(difflib.unified_diff(a, b, f"{la}/{rel}", f"{lb}/{rel}"))
    plus = sum(1 for x in d if x.startswith("+") and not x.startswith("+++"))
    minus = sum(1 for x in d if x.startswith("-") and not x.startswith("---"))
    return d, plus, minus


def main():
    a = load(R + "/manifest_final_r15.sha256")
    b = load(T + "/manifest_r16A.sha256")
    out, diff = [], []
    for rel in sorted(set(a) | set(b)):
        if a.get(rel) == b.get(rel):
            continue
        kind = "added" if rel not in a else "removed" if rel not in b else "changed"
        if rel.endswith((".rs", ".toml", ".json", ".md", ".tsv", ".txt")):
            d, p, m = udiff(F15 + "/" + rel if rel in a else None, TREE + "/" + rel if rel in b else None, rel, "frozen-r15", "r16A")
            diff.extend(d)
            out.append(f"{kind:8s} +{p:<5d} -{m:<5d} {rel}")
        else:
            out.append(f"{kind:8s} (binary) {rel}")
    open(T + "/r16A_vs_frozen_r15.txt", "w").write(f"r16A vs frozen-r15: {len(out)} paths\n" + "\n".join(out) + "\n")
    open(T + "/r16A_vs_frozen_r15.diff", "w").writelines(diff)
    nm = json.load(open("/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/manifest_frozen.json"))["files"]
    out, diff = [], []
    for rel in sorted(nm):
        if b.get(rel) != nm[rel]:
            d, p, m = udiff(N13 + "/" + rel, TREE + "/" + rel if rel in b else None, rel, "native-r13", "token-r16A")
            diff.extend(d)
            out.append(f"+{p:<5d} -{m:<5d} {rel}")
    token_only = sorted(set(b) - set(nm))
    open(T + "/token_vs_native_r13.txt", "w").write(f"native R13 files the token tree differs in: {len(out)}\n" + "\n".join(out) + f"\ntoken-only files: {len(token_only)}\n" + "\n".join(token_only) + "\n")
    open(T + "/token_vs_native_r13.diff", "w").writelines(diff)
    print(open(T + "/r16A_vs_frozen_r15.txt").read())
    print(open(T + "/token_vs_native_r13.txt").read().split("token-only")[0])


if __name__ == "__main__":
    main()
