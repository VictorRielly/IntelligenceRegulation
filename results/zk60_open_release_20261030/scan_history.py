#!/usr/bin/env python3
"""Bounded, redacted secret search over the private repository's git history (all refs).

Pass A: every path outside results/, ops/ and research/ (source and docs).
Pass B: results/, ops/ and research/, small text types only (md, txt, py, sh, toml, yaml,
        env, cfg, ini, key, pem, js, html): the bulky json / log / bin blobs are skipped.
Both use `git log --all --pickaxe-regex -S <one alternation>`: a commit is listed when the
number of matches in a file changes. Each listed commit is then attributed per pattern kind
with `git grep -c` (counts only). No matched value is printed or stored.
Also: every path ever committed whose NAME looks sensitive (from `git log --all --name-only`).
Writes history_scan.json next to this file.
"""
import json
import os
import re
import subprocess
import sys
import time

ROOT = "/home/victor/IntelligenceRegulation"
OUT = os.path.dirname(os.path.abspath(__file__))
KINDS = {
    "pem-private-key": r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----",
    "github-token": r"gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50}",
    "anthropic-key": r"sk-ant-[A-Za-z0-9_-]{20}",
    "openai-key": r"sk-proj-[A-Za-z0-9_-]{20}",
    "aws-key-id": r"AKIA[0-9A-Z]{16}",
    "slack-token": r"xox[bp]-[0-9A-Za-z-]{10}",
    "hf-token": r"hf_[A-Za-z0-9]{30}",
    "telegram-bot-token": r"[0-9]{8,10}:AA[A-Za-z0-9_-]{33}",
    "telegram-bot-url": r"api\.telegram\.org/bot",
    "hex-private-key-assignment": r"(PRIVATE_KEY|private_key|privateKey|secret_key|SECRET_KEY)[\"' :=]+(0x)?[0-9a-fA-F]{64}",
    "mnemonic-assignment": r"(mnemonic|MNEMONIC|seed_phrase)[\"' :=]+[a-z]+ [a-z]+ [a-z]+ [a-z]+",
    "ssh-private-key-name": r"OPENSSH PRIVATE KEY",
}
ALT = "|".join("(%s)" % v for v in KINDS.values())
TEXT_GLOBS = ["*.md", "*.txt", "*.py", "*.sh", "*.toml", "*.yaml", "*.yml", "*.env", "*.cfg", "*.ini",
              "*.key", "*.pem", "*.js", "*.html", ".env*", "*.sol"]
SENSITIVE_NAME = re.compile(
    r"(?i)(^|/)(\.env[^/]*|[^/]*\.pem|[^/]*\.key|id_rsa[^/]*|id_ed25519[^/]*|[^/]*\.p12|[^/]*\.pfx|"
    r"[^/]*\.sqlite3?|[^/]*sepolia-key[^/]*|[^/]*owner-private[^/]*|[^/]*\.dec|[^/]*credential[^/]*|"
    r"[^/]*keystore[^/]*|\.npmrc|\.pypirc|\.netrc|settings\.local\.json)$|/\.claude/|/\.testnet-private/|"
    r"(?i)funding|patent|resume\.(pdf|docx?|md)")


def git(*args):
    r = subprocess.run(["git", "--no-pager", *args], cwd=ROOT, capture_output=True)
    return r.returncode, r.stdout.decode("utf-8", "replace"), r.stderr.decode("utf-8", "replace")[-2000:]


def pickaxe(pathspec):
    t = time.time()
    rc, out, err = git("log", "--all", "--format=%h %cI", "--pickaxe-regex", "-S", ALT, "--", *pathspec)
    commits = [l.split() for l in out.splitlines() if l.strip()]
    return dict(rc=rc, seconds=round(time.time() - t, 1), commits=commits, stderr_tail=err[-300:])


def attribute(commit, pathspec):
    rc, names, _ = git("diff-tree", "--no-commit-id", "--name-only", "-r", "--root", commit, "--", *pathspec)
    files = [n for n in names.splitlines() if n]
    found = []
    for kind, rx in KINDS.items():
        if not files:
            break
        rc, out, _ = git("grep", "-c", "-E", rx, commit, "--", *files)
        for line in out.splitlines():
            # format: <commit>:<path>:<count>
            parts = line.rsplit(":", 1)
            if len(parts) == 2:
                path = parts[0].split(":", 1)[1] if ":" in parts[0] else parts[0]
                found.append(dict(kind=kind, path=path, count=int(parts[1])))
    rc, br, _ = git("branch", "-a", "--contains", commit, "--format=%(refname:short)")
    return dict(commit=commit, files_changed=len(files), matches=found,
                in_refs=sorted(br.split())[:20], note="a deletion commit can also be listed (count went to 0)")


def main():
    t0 = time.time()
    res = {"generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "redaction": "counts and paths only, never a matched value", "kinds": KINDS}
    rc, out, _ = git("log", "--all", "--oneline")
    res["commits_all_refs"] = len(out.splitlines())
    rc, out, _ = git("for-each-ref", "--format=%(refname:short)")
    res["refs"] = out.split()
    rc, out, _ = git("log", "--all", "--name-only", "--format=")
    paths = sorted(set(l for l in out.splitlines() if l))
    res["paths_ever_committed"] = len(paths)
    tops = {}
    for p in paths:
        tops[p.split("/")[0] if "/" in p else "(root files)"] = tops.get(p.split("/")[0] if "/" in p else "(root files)", 0) + 1
    res["paths_by_top"] = dict(sorted(tops.items(), key=lambda kv: -kv[1]))
    res["sensitive_names_ever_committed"] = [p for p in paths if SENSITIVE_NAME.search("/" + p)]
    passes = {
        "A_source_docs": [":(exclude)results", ":(exclude)ops", ":(exclude)research", "."],
        "B_results_ops_research_text": [f":(glob){top}/**/{g}" for top in ("results", "ops", "research") for g in TEXT_GLOBS],
    }
    res["passes"] = {}
    for name, spec in passes.items():
        p = pickaxe(spec)
        p["pathspec"] = spec if len(spec) < 8 else spec[:4] + [f"... {len(spec)} globs"]
        p["attributed"] = [attribute(c[0], spec) for c in p["commits"][:60]]
        res["passes"][name] = p
        print(name, "rc", p["rc"], "commits", len(p["commits"]), "s", p["seconds"], file=sys.stderr)
    res["not_covered"] = ("json / jsonl / log / tsv / csv / bin blobs under results/, ops/ and research/ "
                          "(bulk evidence; 23 GB of blobs in history) were not content-searched")
    res["elapsed_s"] = round(time.time() - t0, 1)
    with open(os.path.join(OUT, "history_scan.json"), "w") as f:
        json.dump(res, f, indent=1)
    print(json.dumps({k: (len(v["commits"]) if isinstance(v, dict) else v) for k, v in res["passes"].items()}))


if __name__ == "__main__":
    main()
