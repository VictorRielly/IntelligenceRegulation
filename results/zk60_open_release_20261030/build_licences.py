#!/usr/bin/env python3
"""Third-party licence inventory for the open release (offline, read-only).

Rust: every Cargo.lock of the candidate tree; each registry crate's licence is read from
~/.cargo/registry/src/*/<name>-<version>/Cargo.toml (git sources from ~/.cargo/git/checkouts).
Python: the app's venv dist-info METADATA, plus the system interpreter's metadata for the
third-party modules the scripts / tests import.
Writes rust_licences.tsv, python_licences.tsv and licence_summary.json next to this file.
"""
import glob
import importlib.metadata as md
import json
import os
import re
import time

ROOT = "/home/victor/IntelligenceRegulation"
OUT = os.path.dirname(os.path.abspath(__file__))
R16B = "results/zk60_token_io_r1_20261017/frozen-r16b"
LOCKS = {
    "hashline (r16b)": R16B + "/hashline/Cargo.lock",
    "zkp-core (r16b)": R16B + "/zkp-core/Cargo.lock",
    "private-block-kernel-shaped (r16b)": R16B + "/private-block-kernel-shaped/Cargo.lock",
    "private-block-kernel": "private-block-kernel/Cargo.lock",
    "private-model-kernel": "private-model-kernel/Cargo.lock",
    "zkmatrix-rs": "zkmatrix-rs/Cargo.lock",
    "zkvm-block": "zkvm-block/Cargo.lock",
    "zkvm-block guest": "zkvm-block/methods/guest/Cargo.lock",
    "zkvm-model": "zkvm-model/Cargo.lock",
    "zkvm-model guest": "zkvm-model/methods/guest/Cargo.lock",
    "zkvm-native-tools": "zkvm-native-tools/Cargo.lock",
}
REG = glob.glob(os.path.expanduser("~/.cargo/registry/src/*"))
GITCO = os.path.expanduser("~/.cargo/git/checkouts")
COPYLEFT = re.compile(r"\b(A?GPL|LGPL|MPL|EPL|CDDL|EUPL|OSL|SSPL|CC-BY-SA|CC-BY-NC)", re.I)
PERMISSIVE = re.compile(r"^(MIT|Apache-2\.0|BSD-[23]-Clause|ISC|Zlib|Unlicense|0BSD|CC0-1\.0|BSL-1\.0|"
                        r"Unicode-DFS-2016|Unicode-3\.0|MIT-0|Apache-2\.0 WITH LLVM-exception|CDLA-Permissive-2\.0)$")


def parse_lock(path):
    pk, cur = [], None
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line == "[[package]]":
            cur = {}
            pk.append(cur)
        elif cur is not None:
            m = re.match(r'^(name|version|source)\s*=\s*"(.*)"$', line)
            if m:
                cur[m.group(1)] = m.group(2)
    return pk


def crate_toml(name, ver, source):
    if source and source.startswith("registry+"):
        for r in REG:
            p = os.path.join(r, f"{name}-{ver}", "Cargo.toml")
            if os.path.isfile(p):
                return p
    if source and source.startswith("git+"):
        for p in glob.glob(os.path.join(GITCO, "*", "*", "**", "Cargo.toml"), recursive=True):
            try:
                t = open(p, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            if re.search(r'(?m)^name\s*=\s*"%s"' % re.escape(name), t) and \
               re.search(r'(?m)^version\s*=\s*"%s"' % re.escape(ver), t):
                return p
    return None


def licence_of(toml_path):
    t = open(toml_path, encoding="utf-8", errors="replace").read()
    sec = re.split(r"(?m)^\[(?!package\])", t)[0]
    m = re.search(r'(?m)^license\s*=\s*"([^"]*)"', sec)
    if m:
        return m.group(1), ""
    m = re.search(r'(?m)^license-file\s*=\s*"([^"]*)"', sec)
    if m:
        lf = os.path.join(os.path.dirname(toml_path), m.group(1))
        head = ""
        try:
            head = open(lf, encoding="utf-8", errors="replace").read(400).replace("\n", " ")[:120]
        except OSError:
            pass
        return "license-file:" + m.group(1), head
    if re.search(r'(?m)^license\.workspace\s*=\s*true', sec):
        return "workspace-inherited", ""
    return "UNKNOWN", ""


def classify(lic):
    if lic.startswith("license-file") or lic in ("UNKNOWN", "workspace-inherited", "NOT-IN-LOCAL-REGISTRY"):
        return "unknown"
    parts = [p.strip("() ") for p in re.split(r"\s+OR\s+|/", lic)]
    if any(PERMISSIVE.match(p) for p in parts):
        if COPYLEFT.search(lic) and not any(PERMISSIVE.match(p) for p in parts):
            return "copyleft"
        return "permissive"
    if COPYLEFT.search(lic):
        return "copyleft"
    andparts = [p.strip("() ") for p in re.split(r"\s+AND\s+", lic)]
    if all(PERMISSIVE.match(p) or re.match(r"^(MIT|Apache-2\.0)\s+OR\s+", p) for p in andparts):
        return "permissive"
    return "review"


def main():
    crates = {}
    for label, rel in LOCKS.items():
        p = os.path.join(ROOT, rel)
        if not os.path.isfile(p):
            continue
        for pk in parse_lock(p):
            key = (pk.get("name"), pk.get("version"), pk.get("source", ""))
            crates.setdefault(key, set()).add(label)
    rows = []
    for (name, ver, src), users in sorted(crates.items()):
        if not src:
            rows.append((name, ver, "path (this project)", "ours", "first-party", "", sorted(users)))
            continue
        tp = crate_toml(name, ver, src)
        if not tp:
            rows.append((name, ver, src.split("#")[0], "NOT-IN-LOCAL-REGISTRY", "unknown", "", sorted(users)))
            continue
        lic, note = licence_of(tp)
        rows.append((name, ver, src.split("#")[0], lic, classify(lic), note, sorted(users)))
    with open(os.path.join(OUT, "rust_licences.tsv"), "w") as f:
        f.write("crate\tversion\tsource\tlicense\tclass\tnote\tused_by\n")
        for r in rows:
            f.write("\t".join([r[0], r[1], r[2], r[3], r[4], r[5].replace("\t", " "), ",".join(r[6])]) + "\n")

    # Python
    py = []
    venv = glob.glob(ROOT + "/apps/proven-media/.venv/lib/python*/site-packages/*.dist-info")
    for d in sorted(venv):
        meta = os.path.join(d, "METADATA")
        if not os.path.isfile(meta):
            continue
        t = open(meta, encoding="utf-8", errors="replace").read().split("\n\n")[0]
        name = re.search(r"(?m)^Name:\s*(.+)$", t)
        ver = re.search(r"(?m)^Version:\s*(.+)$", t)
        le = re.search(r"(?m)^License-Expression:\s*(.+)$", t)
        lc = re.search(r"(?m)^License:\s*(.+)$", t)
        cls = re.findall(r"(?m)^Classifier:\s*License :: (.+)$", t)
        lct = lc.group(1).strip() if lc else ""
        if lct.lower().startswith(("copyright", "the ")) or len(lct) > 120:
            lct = ""                     # full licence text pasted into License:, use classifiers
        lic = (le.group(1) if le else lct) or "; ".join(cls)
        py.append(("app-venv", name.group(1).strip() if name else d, ver.group(1).strip() if ver else "", lic.strip(), "; ".join(cls)))
    sysmods = ["numpy", "mlx", "jax", "jaxlib", "torch", "matplotlib", "scipy", "tokenizers", "sentencepiece",
               "mistral_common", "safetensors", "transformers", "huggingface_hub", "pillow", "eth-account", "fastapi"]
    for m in sysmods:
        try:
            meta = md.metadata(m)
        except md.PackageNotFoundError:
            py.append(("system-python", m, "", "NOT INSTALLED in system python3", ""))
            continue
        le = meta.get("License-Expression") or ""
        lc = meta.get("License") or ""
        cls = [c.split("License :: ", 1)[1] for c in (meta.get_all("Classifier") or []) if c.startswith("License ::")]
        if lc.lower().startswith(("copyright", "the ")) or len(lc) > 120:
            lc = ""
        lic = le or lc or "; ".join(cls)
        py.append(("system-python", meta.get("Name", m), meta.get("Version", ""), lic.strip(), "; ".join(cls)))
    with open(os.path.join(OUT, "python_licences.tsv"), "w") as f:
        f.write("env\tpackage\tversion\tlicense\tclassifiers\n")
        for r in py:
            f.write("\t".join(x.replace("\t", " ").replace("\n", " ") for x in r) + "\n")

    by_class, by_lic = {}, {}
    for r in rows:
        by_class[r[4]] = by_class.get(r[4], 0) + 1
        by_lic[r[3]] = by_lic.get(r[3], 0) + 1
    flagged = [dict(crate=r[0], version=r[1], license=r[3], cls=r[4], note=r[5], used_by=r[6])
               for r in rows if r[4] in ("copyleft", "unknown", "review")]
    risc0 = [dict(crate=r[0], version=r[1], license=r[3]) for r in rows if r[0].startswith("risc0")]
    summ = {
        "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "lockfiles": LOCKS, "registry_dirs": REG,
        "rust_crates_distinct": len(rows), "rust_by_class": by_class,
        "rust_by_license": dict(sorted(by_lic.items(), key=lambda kv: -kv[1])),
        "rust_flagged": flagged, "risc0_crates": risc0,
        "python_packages": len(py),
        "python_flagged": [dict(env=r[0], package=r[1], version=r[2], license=r[3]) for r in py
                           if COPYLEFT.search(r[3] + r[4]) or not r[3]],
        "note": "Dependencies are not vendored into the public tree (Cargo / pip fetch them), so their "
                "licences bind redistributors of binaries, not the source release itself.",
    }
    with open(os.path.join(OUT, "licence_summary.json"), "w") as f:
        json.dump(summ, f, indent=1)
    print(json.dumps({"crates": len(rows), "by_class": by_class, "flagged": len(flagged), "python": len(py)}))


if __name__ == "__main__":
    main()
