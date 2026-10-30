#!/usr/bin/env python3
"""[gate round 24] What the gate pins and what moved, token frozen-r17 -> r18 -> r19 -> r19b, verified
from the frozen trees themselves (not from the token lane's pin notes).

    python3 readings.py            -> round24/READINGS_R24.json, round24/readings/*.diff

1. every frozen tree r16b, r17, r18, r19, r19b re-hashed against its manifest (listed / moved / missing,
   and files on disk that the manifest does not list);
2. the moved paths per step and r17 -> r19b;
3. the 72 capture source pins: the three lists parsed from each tree's run_capture.rs, each file hashed
   in each tree; which pins move;
4. every moved path searched in the gate's frozen v23 tools (scripts + tests): where the tools name it;
5. derive.rs: its production text (comment lines dropped) r16b -> r19b, the lines that differ;
   classify_cli.rs: the `door` function's text r17 vs r19b; private_block.rs: the r17 -> r18 hunk;
6. the five classifier CLI binaries re-hashed against cli/binaries_r*.sha256, and whether any frozen v23
   tool names a binary digest;
7. on this box: the real Shieldstral export's tied_embeddings declaration and the default checkpoint file.

Read-only on the token trees; writes only under round24/.  NOT a privacy result.
"""
import hashlib
import json
import os
import re
import stat
import subprocess
import sys

REPO = "/home/victor/IntelligenceRegulation"
TOK = REPO + "/results/zk60_token_io_r1_20261017"
OUT = REPO + "/results/zk60_gate_tinyllama_20261017/round24"
GT = REPO + "/ops/zkp-mvp/gate-tinyllama"
TREES = {"r16b": "frozen-r16b", "r17": "frozen-r17", "r18": "frozen-r18", "r19": "frozen-r19", "r19b": "frozen-r19b"}
MANS = {"r16b": "manifest_final_r16b.sha256", "r17": "manifest_final_r17.sha256", "r18": "manifest_final_r18.sha256",
        "r19": "manifest_final_r19.sha256", "r19b": "manifest_final_r19b.sha256"}
BINS = {"r16b": "dfb8025e", "r17": "81bd8624", "r18": "110f0c53", "r19": "841ba983", "r19b": "6d65d32e"}


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for c in iter(lambda: fh.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def man(tag):
    d = {}
    with open(os.path.join(TOK, MANS[tag])) as fh:
        for ln in fh:
            h, p = ln.rstrip("\n").split("  ", 1)
            d[p] = h
    return d


def tree_check(tag):
    root = os.path.join(TOK, TREES[tag])
    m = man(tag)
    moved = [p for p, h in m.items() if not os.path.exists(os.path.join(root, p)) or sha(os.path.join(root, p)) != h]
    on_disk = set()
    for d, _dirs, files in os.walk(root):
        for f in files:
            on_disk.add(os.path.relpath(os.path.join(d, f), root))
    extra = sorted(on_disk - set(m))
    return {"tree": TREES[tag], "manifest": MANS[tag], "manifest_list_sha256": sha(os.path.join(TOK, MANS[tag])),
            "listed": len(m), "moved_or_missing": moved, "unlisted_on_disk": extra, "ok": not moved and not extra}


def capture_lists(tag):
    src = open(os.path.join(TOK, TREES[tag], "hashline/src/private_block/run_capture.rs")).read()
    out = {}
    for name in ("SHARED_SOURCE_FILES", "OWN_SOURCE_FILES", "CLASSIFY_SOURCE_FILES"):
        m = re.search(r"const " + name + r": \[&str; (\d+)\] = \[(.*?)\];", src, re.S)
        body = re.sub(r"//[^\n]*", "", m.group(2))
        items = re.findall(r'"([^"]+)"', body)
        if len(items) != int(m.group(1)):
            raise SystemExit(f"{tag} {name}: {len(items)} items, declared {m.group(1)}")
        out[name] = items
    return out


def pin_digest(tag, f):
    p = os.path.normpath(os.path.join(TOK, TREES[tag], "hashline", f))
    return sha(p) if os.path.exists(p) else None


def save_diff(a_tag, b_tag, rel, name):
    a = os.path.join(TOK, TREES[a_tag], rel)
    b = os.path.join(TOK, TREES[b_tag], rel)
    p = subprocess.run(["diff", "-u", a, b], capture_output=True)
    o = os.path.join(OUT, "readings", name)
    with open(o, "wb") as fh:
        fh.write(p.stdout)
    plus = sum(1 for ln in p.stdout.decode().splitlines() if ln.startswith("+") and not ln.startswith("+++"))
    minus = sum(1 for ln in p.stdout.decode().splitlines() if ln.startswith("-") and not ln.startswith("---"))
    return {"file": rel, "from": a_tag, "to": b_tag, "diff": os.path.relpath(o, REPO), "sha256": sha(o),
            "plus": plus, "minus": minus, "hunks": p.stdout.decode().count("\n@@")}


def production_lines(path, cut_tests=True):
    """the file's lines with comment-only lines dropped; up to the first `#[cfg(test)]\\nmod tests {`"""
    text = open(path).read()
    if cut_tests:
        i = text.find("\n#[cfg(test)]\nmod tests {")
        if i >= 0:
            text = text[:i]
    return [ln.rstrip() for ln in text.splitlines() if ln.strip() and not ln.strip().startswith("//")]


def fn_text(path, header):
    text = open(path).read()
    i = text.find(header)
    if i < 0:
        return None
    j = text.index("{", i)
    depth, k = 0, j
    while True:
        c = text[k]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[i:k + 1]
        k += 1


def main():
    rec = {"what": "gate round 24: what the gate pins and what moved, token frozen-r17 -> r19b (read from the trees)",
           "privacy_acceptance": False}
    rec["trees"] = {t: tree_check(t) for t in TREES}
    ms = {t: man(t) for t in TREES}
    steps = [("r16b", "r17"), ("r17", "r18"), ("r18", "r19"), ("r19", "r19b"), ("r17", "r19b")]
    rec["moved"] = {}
    for a, b in steps:
        ch = sorted(p for p in set(ms[a]) | set(ms[b]) if ms[a].get(p) != ms[b].get(p))
        rec["moved"][f"{a}->{b}"] = [{"path": p, a: ms[a].get(p), b: ms[b].get(p)} for p in ch]
    moved_r17_r19b = [x["path"] for x in rec["moved"]["r17->r19b"]]
    # 3. the 72 capture pins
    lists = {t: capture_lists(t) for t in ("r17", "r18", "r19", "r19b")}
    same = all(lists[t] == lists["r17"] for t in lists)
    pins = lists["r19b"]["OWN_SOURCE_FILES"] + lists["r19b"]["SHARED_SOURCE_FILES"] + lists["r19b"]["CLASSIFY_SOURCE_FILES"]
    dig = {t: {f: pin_digest(t, f) for f in pins} for t in ("r16b", "r17", "r18", "r19", "r19b")}
    pin_moves = []
    for f in pins:
        seq = [dig[t][f] for t in ("r17", "r18", "r19", "r19b")]
        if len(set(seq)) > 1:
            pin_moves.append({"file": f, "r16b": dig["r16b"][f], "r17": seq[0], "r18": seq[1], "r19": seq[2], "r19b": seq[3]})
    rec["capture_pins"] = {"lists_equal_r17_r18_r19_r19b": same,
                           "counts": {k: len(v) for k, v in lists["r19b"].items()}, "total": len(pins),
                           "missing_in_r19b": [f for f in pins if dig["r19b"][f] is None],
                           "moving_r17_to_r19b": pin_moves,
                           "r19b_digests": dig["r19b"]}
    moved_pinned = [m["file"] for m in pin_moves]
    # 4. the gate's tools: where a moved path is named
    names = {p: os.path.basename(p) for p in moved_r17_r19b}
    hits = {}
    for sub in ("frozen_v23/scripts", "frozen_v23/tests", "frozen_v23/counts"):
        d = os.path.join(GT, sub)
        for fn in sorted(os.listdir(d)):
            if not fn.endswith(".py"):
                continue
            for i, ln in enumerate(open(os.path.join(d, fn)), 1):
                for p, base in names.items():
                    stem = base[:-3] if base.endswith(".rs") else base
                    if base in ln or (stem not in ("private_block",) and re.search(r"\b" + re.escape(stem) + r"\b", ln)):
                        hits.setdefault(p, []).append(f"{sub}/{fn}:{i}: {ln.strip()[:160]}")
    rec["gate_tool_mentions_of_moved_paths"] = {p: hits.get(p, []) for p in moved_r17_r19b}
    # 5. readings
    D = "hashline/src/private_block/tied_tables/derive.rs"
    rec["diffs"] = [
        save_diff("r17", "r18", "hashline/src/private_block.rs", "tok-r17-r18-private_block.rs.diff"),
        save_diff("r17", "r18", D, "tok-r17-r18-derive.rs.diff"),
        save_diff("r18", "r19", D, "tok-r18-r19-derive.rs.diff"),
        save_diff("r19", "r19b", D, "tok-r19-r19b-derive.rs.diff"),
        save_diff("r16b", "r19b", D, "tok-r16b-r19b-derive.rs.diff"),
        save_diff("r17", "r18", "hashline/src/private_block/token_io/classify_cli.rs", "tok-r17-r18-classify_cli.rs.diff"),
        save_diff("r18", "r19b", "hashline/src/private_block/token_io/classify_cli.rs", "tok-r18-r19b-classify_cli.rs.diff"),
        save_diff("r17", "r18", "hashline/examples/zk60_classify.rs", "tok-r17-r18-examples_zk60_classify.rs.diff"),
    ]
    a = production_lines(os.path.join(TOK, TREES["r16b"], D))
    b = production_lines(os.path.join(TOK, TREES["r19b"], D))
    import difflib
    dl = [ln for ln in difflib.unified_diff(a, b, lineterm="", n=0) if ln[:1] in "+-" and ln[:3] not in ("+++", "---")]
    rec["derive_production_text_r16b_to_r19b"] = {"lines_r16b": len(a), "lines_r19b": len(b), "differing": dl,
                                                  "absorb_or_transcript_in_production_r19b":
                                                      [ln for ln in b if "absorb" in ln or "transcript" in ln or "blake3" in ln.lower()],
                                                  "sha256_new_count": [sum(ln.count("Sha256::new(") for ln in x) for x in (a, b)]}
    C = "hashline/src/private_block/token_io/classify_cli.rs"
    door17 = fn_text(os.path.join(TOK, TREES["r17"], C), "pub(super) fn door(")
    door19b = fn_text(os.path.join(TOK, TREES["r19b"], C), "pub(super) fn door(")

    def verify_half(tag):
        t = open(os.path.join(TOK, TREES[tag], C)).read()
        t = t[t.index("pub(super) fn door("):]
        return [ln.rstrip() for ln in t.splitlines() if ln.strip() and not ln.strip().startswith("//")]
    v17, v19b = verify_half("r17"), verify_half("r19b")
    rec["classify_cli_door_r17_equals_r19b"] = {"found": door17 is not None and door19b is not None,
                                                "door_text_equal": door17 == door19b,
                                                "door_sha256": [hashlib.sha256((x or "").encode()).hexdigest() for x in (door17, door19b)],
                                                "door_to_end_of_file_without_comment_lines_equal": v17 == v19b,
                                                "lines": [len(v17), len(v19b)]}
    # 6. binaries
    bins = {}
    for t, short in BINS.items():
        p = os.path.join(TOK, "cli", f"zk60_classify.{t}.release.bin")
        listed = open(os.path.join(TOK, "cli", f"binaries_{t}.sha256")).read().split()[0]
        got = sha(p)
        bins[t] = {"path": os.path.relpath(p, REPO), "sha256": got, "listed": listed, "equal": got == listed,
                   "starts": got.startswith(short)}
    rec["cli_binaries"] = bins
    tool_bin = []
    for sub in ("frozen_v23/scripts", "frozen_v23/tests", "frozen_v23/counts"):
        d = os.path.join(GT, sub)
        for fn in sorted(os.listdir(d)):
            if fn.endswith(".py"):
                t = open(os.path.join(d, fn)).read()
                for k, v in bins.items():
                    if v["sha256"][:8] in t:
                        tool_bin.append(f"{sub}/{fn}: {k}")
    rec["frozen_v23_tools_naming_a_classifier_binary"] = tool_bin
    # 7. on this box
    prof = json.load(open(REPO + "/results/zk60_shieldstral_export_20261026/native_low_h24_t128/profile.json"))
    c = "/home/victor/models/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors"
    st = os.lstat(c)
    rec["this_box"] = {"export_tied_embeddings": prof.get("tied_embeddings"),
                       "checkpoint_file_declared": "checkpoint_file" in prof.get("tied_embeddings", {}),
                       "ZK60_MODELS": os.environ.get("ZK60_MODELS"), "HOME": os.environ.get("HOME"),
                       "default_checkpoint": c, "regular_file": stat.S_ISREG(st.st_mode), "symlink": stat.S_ISLNK(st.st_mode),
                       "bytes": st.st_size, "links": st.st_nlink}
    rec["summary"] = {"trees_ok": all(v["ok"] for v in rec["trees"].values()),
                      "moved_r17_to_r19b": moved_r17_r19b, "moved_and_pinned": moved_pinned,
                      "moved_and_named_by_a_gate_tool": sorted(p for p, h in rec["gate_tool_mentions_of_moved_paths"].items() if h),
                      "binaries_equal_their_lists": all(v["equal"] for v in bins.values())}
    o = os.path.join(OUT, "READINGS_R24.json")
    with open(o, "w") as fh:
        json.dump(rec, fh, indent=1)
    print(json.dumps(rec["summary"], indent=1))
    print("capture pins moving:", [(m["file"], m["r17"][:8], m["r18"][:8], m["r19"][:8], m["r19b"][:8]) for m in pin_moves])
    print("derive production diff lines:", len(dl))
    print("door:", rec["classify_cli_door_r17_equals_r19b"])
    print(o, sha(o))
    return 0


if __name__ == "__main__":
    sys.exit(main())
