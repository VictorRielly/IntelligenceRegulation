#!/usr/bin/env python3
"""Count the Lean development in formal/ZK60Formal by family (read-only).

Used by docs/zkmatrix-poc/ZK60_NEXT_PROTOCOL_CANDIDATES.md section 4.
Standard library only. Reads .lean files, writes nothing.

For each file it records: family (by name rule below), lines, whether the name
says R13 or W16, and a few dependency markers found by plain text search:
  helper   : mentions LogUp helper columns (helper / pairHelper / SoundLogUpBlock)
  gold     : mentions Goldilocks specifics (gP, Fp2, u^2 = 7, reduce128)
  rate     : mentions the code rate / opened-column geometry (QB, rs_proximity_half, 280, 2^14 rows)
  imports  : number of ZK60Formal imports
Run: python3 lean_families.py [repo_root]
"""
import os
import re
import sys
from collections import defaultdict

ROOT = sys.argv[1] if len(sys.argv) > 1 else "/Users/victorrielly/IntelligenceRegulation"
BASE = os.path.join(ROOT, "formal", "ZK60Formal")

FAMILIES = [
    ("F1 foundations: field, hash, transcript, Merkle, random oracle",
     ["Goldilocks", "ExecField", "ExecBlake3", "ExecTranscript", "ExecMerkle", "SoundRO", "SoundMerkle",
      "SoundExtract", "SoundSchwartzZippel", "FSChain", "FSChallenge", "FSWide", "L5Check", "L5Vectors",
      "ThirdParty/FlashProve/Prob/"],
     ["FSChainRbr", "FSWideRbr"]),
    ("F2 sumcheck, zero-check and Fiat-Shamir soundness",
     ["SoundSumcheck", "SoundMultilinear", "SoundZeroCheck", "FSRbr", "FSSumcheck", "FSChainRbr", "FSWideRbr",
      "FSCompose", "FSPath", "FSTree", "ExecMle", "ExecSumcheck", "ExecComposeFS", "ExecCfs", "L6Check",
      "ZoneCode"],
     ["FSComposeBlock", "FSPathBlock", "FSTreeD55"]),
    ("F3 commitment (Ligero/RS PCS), openings, M, binding",
     ["SoundColumnTest", "SoundProximity", "SoundOpening", "SoundGroups", "SoundMProduct", "FSOpening",
      "ExecOpening", "Binding", "OpeningR13", "OpenKnow", "HonestOpen", "ThirdParty/FlashProve/Code/"],
     []),
    ("F4 LogUp and lookup facts (helper-column LogUp, tables)",
     ["SoundLogUp", "FSLogUp", "LookupW16FS", "BlockLook", "BlockLk", "BlockR13Look", "BlockTab", "BlockAlgLk",
      "BlockHelperExportCheck", "CircuitHelpers"],
     []),
    ("F5 block slots, layout, block verifier and block soundness",
     ["Slot", "Layout", "Block", "ExecBlock", "CheckR13", "RelW16", "CoverW16", "CountW16", "ExtractW16",
      "ExtractInstW16", "LinkW16", "ShapeR13", "FSComposeBlock", "FSPathBlock", "L11Check"],
     []),
    ("F6 token stages (IN, IN-C, OUT, OUT-C)",
     ["Stage", "RunStg", "RunStageRd", "HonestRunStage"],
     []),
    ("F7 run chain, D55 tree, endpoints, bad-event budget, classify protocol",
     ["Run", "ProtocolClassify", "AssembleClassify", "HonestClassify", "HonestRun", "FSTreeD55"],
     []),
    ("F8 zero knowledge",
     ["Hiding", "ZK", "HonestOracle"],
     []),
    ("F9 integer model and CircuitIff",
     ["ModelInt", "ModelOut", "Circuit", "L1Check"],
     []),
    ("F10 approved statements and generic assembly",
     ["Statements", "Assembly", "CompleteSub"],
     []),
]


def family_of(rel):
    # first family whose prefix list matches and whose exclusion list does not
    stem = rel[:-5] if rel.endswith(".lean") else rel
    # exact-name matches first (so FSChainRbr goes to F2 not F1)
    for name, prefixes, _ in FAMILIES:
        for p in prefixes:
            if stem == p:
                return name
    for name, prefixes, excl in FAMILIES:
        if any(stem == e or stem.startswith(e) for e in excl):
            continue
        for p in prefixes:
            if stem.startswith(p):
                # keep "HonestRunStage" in F6 rather than F7
                return name
    return "UNCLASSIFIED"


MARKERS = {
    "helper": re.compile(r"helper|Helper|SoundLogUpBlock|pairHelper"),
    "gold": re.compile(r"\bgP\b|Fp2|reduce128|seven_not_square|\(u\s*\^\s*2|U\s*\^\s*2\s*=\s*7"),
    "logup": re.compile(r"[Ll]og[Uu]p|logup"),
    "w16": re.compile(r"W16"),
    "r13": re.compile(r"R13"),
}
IMPORT = re.compile(r"^import\s+ZK60Formal\.(\S+)", re.M)


def main():
    rows = []
    for dirpath, _, files in os.walk(BASE):
        for f in files:
            if not f.endswith(".lean"):
                continue
            full = os.path.join(dirpath, f)
            rel = os.path.relpath(full, BASE)
            with open(full, encoding="utf-8") as h:
                text = h.read()
            fam = family_of(rel)
            # HonestRunStage* belongs to F6 by its prefix order; enforce
            if rel.startswith("HonestRunStage"):
                fam = FAMILIES[5][0]
            rows.append({
                "file": rel, "fam": fam, "lines": text.count("\n") + (0 if text.endswith("\n") else 1),
                **{k: bool(rx.search(text)) for k, rx in MARKERS.items()},
                "imports": IMPORT.findall(text),
            })
    fams = defaultdict(list)
    for r in rows:
        fams[r["fam"]].append(r)
    total_files = len(rows)
    total_lines = sum(r["lines"] for r in rows)
    print(f"total files {total_files}, total lines {total_lines}")
    order = [f[0] for f in FAMILIES] + ["UNCLASSIFIED"]
    print("family | files | lines | share of lines | files naming R13 | files naming W16 | files mentioning LogUp | files mentioning helpers | files with Goldilocks specifics")
    for name in order:
        rs = fams.get(name, [])
        if not rs:
            continue
        ln = sum(r["lines"] for r in rs)
        print(f"{name} | {len(rs)} | {ln} | {100*ln/total_lines:.1f}% | "
              f"{sum('R13' in r['file'] for r in rs)} | {sum('W16' in r['file'] for r in rs)} | "
              f"{sum(r['logup'] for r in rs)} | {sum(r['helper'] for r in rs)} | {sum(r['gold'] for r in rs)}")
    if fams.get("UNCLASSIFIED"):
        print("unclassified:", [r["file"] for r in fams["UNCLASSIFIED"]])
    # transitive importers of the helper-column LogUp core
    by_mod = {r["file"][:-5].replace("/", "."): r for r in rows}
    rev = defaultdict(set)
    for m, r in by_mod.items():
        for i in r["imports"]:
            rev[i].add(m)
    for seed in ["SoundLogUpBlock", "SoundLogUp", "FSLogUp", "SoundProximityRS", "Goldilocks", "Statements"]:
        seen, stack = set(), [seed]
        while stack:
            x = stack.pop()
            for y in rev.get(x, ()):
                if y not in seen:
                    seen.add(y)
                    stack.append(y)
        print(f"modules transitively importing {seed}: {len(seen)} of {len(by_mod)}")
    if "--list" in sys.argv:
        for name in order:
            for r in sorted(fams.get(name, []), key=lambda r: r["file"]):
                print(f"{name[:3]}\t{r['lines']}\t{r['file']}")


if __name__ == "__main__":
    main()
