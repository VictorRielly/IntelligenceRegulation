#!/usr/bin/env python3
"""dep_closure.py -- the intra-crate module dependency map of `hashline/`.

CL20 design-phase tool (2026-09-07). Standard library only; no cargo, no
network, no build. It reads every Rust source under `hashline/src`,
`hashline/src/bin`, `hashline/tests` and `hashline/examples`, and records:

  * one node per module (file), with its declaration site, its line counts
    (total / code / inside `#[cfg(test)]` / inside `#[cfg(feature =
    "gpu-cuda")]`), the external crates it names (blake3, rayon, sha2,
    cudarc; everything else is std-only) and the `std::env::var("...")`
    names it reads;
  * one edge per (module -> module) reference, found in `use crate::...`,
    inline `crate::x::...` paths, `super::...` at a file's top level, and
    `hashline::x::...` in the binary / tests / examples. Each edge carries
    the kinds under which it occurs -- `normal`, `gpu` (inside a
    `#[cfg(feature = "gpu-cuda")]` item or block), `not_gpu` (inside a
    `#[cfg(not(feature = "gpu-cuda"))]` item), `test` (inside a
    `#[cfg(test)]` item, module or `#[path]`-declared test file) -- with
    `file:line` evidence for each kind;
  * the transitive closure of a root set, three ways: the literal closure
    (normal + gpu + not_gpu edges: what the default *and* the GPU build
    pull in), the default-build closure (normal + not_gpu edges only) and
    the closure after a list of planned cuts (edges that the extraction
    design removes or redirects), so the map answers "what does the chosen
    profile really drag along" and "what would it drag along after the
    cuts", from the source rather than from memory.

The parser is a line scanner, not a Rust parser. It strips `//` comments
and `/* */` blocks, ignores string-literal contents when counting braces,
tracks brace depth to give a `#[cfg(...)]` attribute its item or block
extent, and treats a lifetime tick as ordinary text (character literals
containing braces are not used in this crate). Its output was checked by
hand against the source at integrator baseline 52a13d1 (see
`zkp-core/DESIGN.md`, "Verified edges").

Usage (from anywhere; paths are resolved relative to this file):

    python3 zkp-core/tools/dep_closure.py                 # JSON + Markdown to the defaults
    python3 zkp-core/tools/dep_closure.py --root layer --root tables_v3
    python3 zkp-core/tools/dep_closure.py --cut pcs:zk --cut layer:pcs_compact --no-default-cuts
    python3 zkp-core/tools/dep_closure.py --src other/crate/src --out /tmp/g.json --md -

Output ordering is deterministic (sorted keys, sorted node and edge lists),
so re-running after an extraction step produces a reviewable diff.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Declared classification (a design judgement, carried by the tool so the JSON
# and the Markdown table say it in one place; DESIGN.md explains each class).
# ---------------------------------------------------------------------------

CLASS = {
    # the maintained core of the chosen profile (the non-hiding v3 FFN layer proof)
    "field": "core",
    "ntt": "core",
    "merkle": "core",
    "transcript": "core",
    "mle": "core",
    "sumcheck": "core",
    "pcs": "core",
    "layer": "core (statement/layout/prove/verify; adapters mixed in)",
    "tables_v3": "core (table registry: the frozen statement digests)",
    # the randomness home is inside zk.rs today; the module as a whole is not core
    "zk": "application (ZK FFN paths) + primitive (ZkRng, to be moved to core `rng`)",
    # adapters
    "gpu": "adapter (device dispatch; stub without the feature)",
    "gpu::cuda": "adapter (cudarc backend; feature gpu-cuda)",
    "wcache": "adapter (per-model weight-commitment cache)",
    "export": "adapter (v2 125M export loader, fixed shapes)",
    "export_v3": "adapter (v3 export loader + witness derivation)",
    "chain": "adapter (v2 exact integer chain / witness)",
    "silu": "adapter (v2 SiLU table registry)",
    "phase_profile": "adapter (timing instrumentation)",
    "pcs_compact": "experiment (BaseFold-class compact PCS, `--pcs compact`)",
    "bin:hashline": "cli",
    # other applications / experiments
    "attention": "application (attention half of the layer)",
    "attention_schedule": "application (public execution metadata)",
    "norm": "application (RMSNorm gadget)",
    "tables_attn": "application (attention tables)",
    "causal_oracle": "application (fixed causal block oracle)",
    "public_block_oracle": "application (public P0 block)",
    "public_block_wire": "application (bounded public-block codec)",
    "public_block_receipt": "application (B3/B4 receipt)",
    "public_chain_receipt": "application (B5 two-block chain receipt)",
    "private_seam": "experiment (one-shot private equality gadget)",
    "private_block_contract": "application (P1 block metadata preflight)",
    "model_identity": "application (opt-in P1 approval boundary)",
    # test-only modules
    "zk::mask_diagnostic": "test-only (the FFN disclosure diagnostic; a LIMITATION test)",
    "wcache::atomic_tests": "test-only",
    "field::verifier_hardening_tests": "test-only",
}

# Planned cuts of the first extraction profile (DESIGN.md section 4). Each is an
# edge the design removes or redirects; the closure "after cuts" shows what the
# chosen root set pulls in once they are gone. `a:b` means "a no longer depends on b".
DEFAULT_CUTS = [
    "pcs:zk",              # ZkRng moves to a lower `rng` module; pcs imports that
    "sumcheck:zk",         # same (CfsMask::random takes &mut rng::ZkRng)
    "pcs:gpu",             # device dispatch becomes a Backend implemented outside the core
    "layer:gpu",           # same (dev_marks/dev_of/device H commit go with the backend)
    "layer:pcs_compact",   # the core calls pcs::commit directly (the selected-false branch)
    "layer:wcache",        # the caller may pass a pre-committed W; caching stays outside
    "layer:chain",         # v2 witness type: not part of the v3 profile
    "layer:export",        # v2 constants D/F: not part of the v3 profile
    "layer:export_v3",     # V3Witness becomes a core type; the loader stays an adapter
]

EXTERNAL_CRATES = ("blake3", "rayon", "sha2", "cudarc")

CFG_TEST = re.compile(r"#\s*\[\s*cfg\s*\(\s*test\s*\)\s*\]")
CFG_GPU = re.compile(r"#\s*\[\s*cfg\s*\(\s*feature\s*=\s*\"gpu-cuda\"\s*\)\s*\]")
CFG_NOT_GPU = re.compile(r"#\s*\[\s*cfg\s*\(\s*not\s*\(\s*feature\s*=\s*\"gpu-cuda\"\s*\)\s*\)\s*\]")
ATTR_LINE = re.compile(r"^\s*#\s*!?\s*\[")
PATH_ATTR = re.compile(r"#\s*\[\s*path\s*=\s*\"([^\"]+)\"\s*\]")
MOD_DECL = re.compile(r"^\s*(?:pub(?:\([^)]*\))?\s+)?mod\s+([A-Za-z_][A-Za-z0-9_]*)\s*;")
MOD_INLINE = re.compile(r"^\s*(?:pub(?:\([^)]*\))?\s+)?mod\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{")
USE_LINE = re.compile(r"^\s*(?:pub(?:\([^)]*\))?\s+)?use\s+(crate|super|hashline)\b(.*)$")
INLINE_PATH = re.compile(r"\b(crate|super|hashline)::([A-Za-z_][A-Za-z0-9_]*)")
EXT_USE = re.compile(r"\b(" + "|".join(EXTERNAL_CRATES) + r")\s*::")
EXT_USE_DECL = re.compile(r"^\s*use\s+(" + "|".join(EXTERNAL_CRATES) + r")\b")
ENV_VAR = re.compile(r"std::env::var\s*\(\s*\"([A-Za-z0-9_]+)\"")
IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def strip_strings_and_comments(line: str, in_block: bool) -> tuple[str, str, bool]:
    """Return (code_without_comments_or_string_contents, code_without_comments, in_block).

    The first form is used for brace counting (string contents blanked), the
    second for reference extraction (string contents kept, comments removed).
    """
    out_nostr: list[str] = []
    out_code: list[str] = []
    i = 0
    n = len(line)
    in_str = False
    while i < n:
        c = line[i]
        if in_block:
            j = line.find("*/", i)
            if j < 0:
                return "".join(out_nostr), "".join(out_code), True
            i = j + 2
            in_block = False
            continue
        if in_str:
            out_code.append(c)
            if c == "\\" and i + 1 < n:
                out_code.append(line[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
                out_nostr.append('"')
            i += 1
            continue
        if c == "/" and i + 1 < n and line[i + 1] == "/":
            break
        if c == "/" and i + 1 < n and line[i + 1] == "*":
            in_block = True
            i += 2
            continue
        if c == '"':
            # a byte-string prefix `b"` is fine: the b stays in the code text
            in_str = True
            out_nostr.append('"')
            out_code.append(c)
            i += 1
            continue
        out_nostr.append(c)
        out_code.append(c)
        i += 1
    return "".join(out_nostr), "".join(out_code), in_block


def split_use_targets(rest: str) -> list[str]:
    """First path segment(s) named by a `use crate<rest>` / `use hashline<rest>` line.

    `::a::b::{c, d}` -> [a]; `::{a, b::c}` -> [a, b]; `::a;` -> [a];
    `::pcs::{self, X}` -> [pcs]; `::attention as at;` -> [attention].
    """
    rest = rest.strip()
    if not rest.startswith("::"):
        return []
    rest = rest[2:]
    if rest.startswith("{"):
        body = rest[1:]
        depth = 0
        items: list[str] = []
        cur: list[str] = []
        for ch in body:
            if ch == "{":
                depth += 1
                cur.append(ch)
            elif ch == "}":
                if depth == 0:
                    items.append("".join(cur))
                    break
                depth -= 1
                cur.append(ch)
            elif ch == "," and depth == 0:
                items.append("".join(cur))
                cur = []
            else:
                cur.append(ch)
        out = []
        for it in items:
            seg = it.strip().split("::")[0].strip().split(" ")[0]
            if IDENT.match(seg) and seg not in ("self", "*"):
                out.append(seg)
        return out
    seg = re.split(r"[:;\s{]", rest, maxsplit=1)[0]
    return [seg] if IDENT.match(seg) and seg not in ("self", "*") else []


class Module:
    def __init__(self, name: str, path: Path, kind: str, parent: str | None, gate: str | None):
        self.name = name
        self.path = path
        self.kind = kind            # lib | bin | test | example
        self.parent = parent        # module that declares this file (for `super::`)
        self.gate = gate            # None | test | gpu (gate of the declaring `mod` item)
        self.declared_by: str | None = None
        self.lines_total = 0
        self.lines_code = 0
        self.lines_test = 0
        self.lines_gpu = 0
        self.externals: set[str] = set()
        self.env_vars: set[str] = set()
        self.tests = 0
        self.edges: dict[str, dict[str, list[str]]] = {}   # to -> kind -> evidence
        self.inline_mods: list[str] = []
        self.declares: list[dict] = []                       # file-module declarations found here

    def add_edge(self, to: str, kind: str, evidence: str) -> None:
        if to == self.name:
            return
        kinds = self.edges.setdefault(to, {})
        ev = kinds.setdefault(kind, [])
        if evidence not in ev:           # one entry per source line
            ev.append(evidence)


def brace_delta(text: str) -> int:
    return text.count("{") - text.count("}")


TRACE: set[str] = set()


def scan_file(mod: Module, rel: str) -> None:
    src = mod.path.read_text(encoding="utf-8", errors="replace").splitlines()
    mod.lines_total = len(src)
    depth = 0
    in_block = False
    pending: str | None = None            # gate waiting for its item
    pending_open = False                  # the gated item has started but is not yet terminated
    pending_path: str | None = None       # #[path = ...] waiting for its `mod x;`
    regions: list[tuple[str, int]] = []   # (gate, close_depth) stack
    inline_mod_depths: list[int] = []      # brace depth at which an inline `mod x {` opened
    module_gate = mod.gate
    trace = rel in TRACE or mod.name in TRACE

    for lineno, raw in enumerate(src, start=1):
        nostr, code, in_block = strip_strings_and_comments(raw, in_block)
        stripped = code.strip()
        if not stripped:
            continue
        mod.lines_code += 1

        # ---- attribute handling --------------------------------------------------
        is_attr = bool(ATTR_LINE.match(code)) and not pending_open
        after_attr = ""
        if is_attr:
            m = re.match(r"^\s*(#\s*!?\s*\[.*?\])(.*)$", code)
            if m:
                after_attr = m.group(2).strip()
            if CFG_TEST.search(code):
                pending = "test"
            elif CFG_GPU.search(code):
                pending = "gpu"
            elif CFG_NOT_GPU.search(code):
                pending = "not_gpu"
            pm = PATH_ATTR.search(code)
            if pm:
                pending_path = pm.group(1)
            if "#[test]" in code.replace(" ", ""):
                mod.tests += 1
            if not after_attr:
                continue
            code = after_attr
            nostr = after_attr
            stripped = code.strip()

        # ---- the gate in force on this line ---------------------------------------
        active: list[str] = [g for g, _ in regions]
        if module_gate:
            active.append(module_gate)
        if pending:
            active.append(pending)
        if "test" in active:
            mod.lines_test += 1
            kind = "test"
        elif "gpu" in active:
            mod.lines_gpu += 1
            kind = "gpu"
        elif "not_gpu" in active:
            kind = "not_gpu"
        else:
            kind = "normal"
        evidence = f"{rel}:{lineno}"

        # ---- declarations -----------------------------------------------------------
        md = MOD_DECL.match(code)
        if md:
            mod.declares.append({"name": md.group(1), "path_attr": pending_path, "gate": pending, "line": lineno})
            pending_path = None
        mi = MOD_INLINE.match(code)
        if mi:
            mod.inline_mods.append(mi.group(1))
            inline_mod_depths.append(depth)

        # ---- references -------------------------------------------------------------
        um = USE_LINE.match(code)
        if um:
            root, rest = um.group(1), um.group(2)
            for seg in split_use_targets(rest):
                target = resolve(mod, root, seg, bool(inline_mod_depths))
                if target:
                    mod.add_edge(target, kind, evidence)
        else:
            for root, seg in INLINE_PATH.findall(code):
                target = resolve(mod, root, seg, bool(inline_mod_depths))
                if target:
                    mod.add_edge(target, kind, evidence)
        for ext in EXT_USE.findall(code):
            mod.externals.add(ext)
        em = EXT_USE_DECL.match(code)
        if em:
            mod.externals.add(em.group(1))
        for name in ENV_VAR.findall(code):
            mod.env_vars.add(name)

        # ---- brace tracking / region extents --------------------------------------
        before = depth
        depth += brace_delta(nostr)
        if trace:
            print(f"trace {evidence} depth {before}->{depth} kind {kind} pending {pending} regions {regions}", file=sys.stderr)
        if pending:
            if depth > before:
                # the item opens a block: the gate lasts until the block closes
                regions.append((pending, before))
                pending = None
                pending_open = False
            elif depth < before:
                pending = None
                pending_open = False
            else:
                # a one-line item ends with `;` or `,` (a `use`, a `mod x;`, an enum
                # variant, a `let`); a multi-line statement keeps the gate until it does
                terminated = stripped.endswith(";") or stripped.endswith(",") or stripped.endswith("}")
                if terminated:
                    pending = None
                    pending_open = False
                else:
                    pending_open = True
        while regions and depth <= regions[-1][1]:
            regions.pop()
        while inline_mod_depths and depth <= inline_mod_depths[-1]:
            inline_mod_depths.pop()


def resolve(mod: Module, root: str, seg: str, in_inline_mod: bool) -> str | None:
    if root in ("crate", "hashline"):
        if root == "hashline" and mod.kind == "lib":
            return None
        if root == "crate" and mod.kind != "lib":
            return None
        return seg
    # super
    if in_inline_mod:
        return None                     # `super` inside an inline `mod tests {}` is this file
    if mod.parent is None:
        return None
    if seg in ("*", "self"):
        return mod.parent
    # `use super::{a, b}` names items of the parent module
    return mod.parent


def discover(src_root: Path) -> dict[str, Module]:
    """Find every module file and its identity.

    Identity comes from the declaring `mod` item: lib.rs declares `pub mod x;`
    -> src/x.rs or src/x/mod.rs; a `#[path = "..."] mod y;` inside src/x.rs ->
    module `x::y` at the named file (relative to src/ for a non-mod.rs
    declarer, as Rust resolves it); a plain `mod y;` inside src/x/mod.rs ->
    src/x/y.rs.
    """
    mods: dict[str, Module] = {}
    lib = src_root / "src" / "lib.rs"
    if not lib.exists():
        sys.exit(f"no lib.rs under {src_root}/src")
    root = Module("lib", lib, "lib", None, None)
    mods["lib"] = root
    pending = [root]
    while pending:
        m = pending.pop()
        scan_file(m, str(m.path.relative_to(src_root)))
        for d in m.declares:
            child_name = d["name"] if m.name == "lib" else f"{m.name}::{d['name']}"
            if d["path_attr"]:
                base = m.path.parent if m.path.name == "mod.rs" else m.path.parent
                child_path = (base / d["path_attr"]).resolve()
            elif m.path.name in ("mod.rs", "lib.rs"):
                cand = m.path.parent / f"{d['name']}.rs"
                child_path = cand if cand.exists() else m.path.parent / d["name"] / "mod.rs"
            else:
                cand = m.path.parent / m.path.stem / f"{d['name']}.rs"
                child_path = cand if cand.exists() else m.path.parent / m.path.stem / d["name"] / "mod.rs"
            if not child_path.exists():
                print(f"warning: {m.name} declares mod {d['name']} but {child_path} is missing", file=sys.stderr)
                continue
            parent = None if m.name == "lib" else m.name
            gate = d["gate"] if d["gate"] in ("test", "gpu") else None
            if parent and mods[parent].gate and not gate:
                gate = mods[parent].gate
            child = Module(child_name, child_path, "lib", parent, gate)
            child.declared_by = f"{m.path.relative_to(src_root)}:{d['line']}"
            mods[child_name] = child
            pending.append(child)
    # the binary, the integration tests and the examples: consumers of `hashline::`
    for sub, kind, prefix in (("src/bin", "bin", "bin:"), ("tests", "test", "test:"), ("examples", "example", "example:")):
        d = src_root / sub
        if not d.is_dir():
            continue
        for f in sorted(d.glob("*.rs")):
            m = Module(prefix + f.stem, f, kind, None, None)
            scan_file(m, str(f.relative_to(src_root)))
            mods[m.name] = m
    # files under src/ that no declaration reached (dead or misdeclared)
    known = {m.path.resolve() for m in mods.values()}
    for f in sorted((src_root / "src").rglob("*.rs")):
        if f.resolve() not in known and "bin" not in f.parts:
            print(f"warning: {f.relative_to(src_root)} is not declared by any module", file=sys.stderr)
    return mods


def closure(mods: dict[str, Module], roots: list[str], kinds: set[str], cuts: set[tuple[str, str]]) -> dict:
    seen: dict[str, str | None] = {}
    order: list[str] = []
    frontier = list(roots)
    for r in roots:
        seen[r] = None
    while frontier:
        cur = frontier.pop(0)
        order.append(cur)
        m = mods.get(cur)
        if not m:
            continue
        for to in sorted(m.edges):
            if (cur, to) in cuts or to not in mods:
                continue
            if not (set(m.edges[to]) & kinds):
                continue
            if to not in seen:
                seen[to] = cur
                frontier.append(to)
    members = sorted(seen)
    lines = sum(mods[x].lines_code for x in members if x in mods)
    tests = sum(mods[x].lines_test for x in members if x in mods)
    return {
        "roots": sorted(roots),
        "edge_kinds": sorted(kinds),
        "cuts": sorted(f"{a}:{b}" for a, b in cuts),
        "members": members,
        "module_count": len(members),
        "code_lines": lines,
        "code_lines_excluding_test": lines - tests,
        "entry_via": {x: seen[x] for x in members},
    }


def to_json(mods: dict[str, Module], src_root: Path, roots: list[str], cuts: set[tuple[str, str]], baseline: str) -> dict:
    nodes = {}
    edges = []
    for name in sorted(mods):
        m = mods[name]
        nodes[name] = {
            "file": str(m.path.relative_to(src_root)),
            "kind": m.kind,
            "class": CLASS.get(name, "unclassified"),
            "declared_by": m.declared_by,
            "gate": m.gate,
            "lines_total": m.lines_total,
            "lines_code": m.lines_code,
            "lines_test": m.lines_test,
            "lines_gpu_gated": m.lines_gpu,
            "tests": m.tests,
            "externals": sorted(m.externals) if m.externals else ["(std only)"],
            "env_vars": sorted(m.env_vars),
            "inline_mods": sorted(set(m.inline_mods)),
            "deps_normal": sorted(t for t, k in m.edges.items() if "normal" in k),
            "deps_gpu_only": sorted(t for t, k in m.edges.items() if "gpu" in k and "normal" not in k),
            "deps_test_only": sorted(t for t, k in m.edges.items() if set(k) <= {"test"}),
        }
        for to in sorted(m.edges):
            for kind in sorted(m.edges[to]):
                ev = m.edges[to][kind]
                edges.append({"from": name, "to": to, "kind": kind, "count": len(ev), "evidence": ev[:8]})
    lib_mods = [n for n, m in mods.items() if m.kind == "lib"]
    default_kinds = {"normal", "not_gpu"}
    literal_kinds = {"normal", "gpu", "not_gpu"}
    return {
        "generator": "zkp-core/tools/dep_closure.py",
        "baseline": baseline,
        "crate": str(src_root.name),
        "summary": {
            "library_modules": len(lib_mods),
            "library_code_lines": sum(mods[n].lines_code for n in lib_mods),
            "library_test_lines": sum(mods[n].lines_test for n in lib_mods),
            "library_gpu_gated_lines": sum(mods[n].lines_gpu for n in lib_mods),
            "binary_code_lines": sum(m.lines_code for m in mods.values() if m.kind == "bin"),
            "integration_test_files": sum(1 for m in mods.values() if m.kind == "test"),
            "example_files": sum(1 for m in mods.values() if m.kind == "example"),
        },
        "nodes": nodes,
        "edges": edges,
        "closures": {
            "literal": closure(mods, roots, literal_kinds, set()),
            "default_build": closure(mods, roots, default_kinds, set()),
            "after_cuts": closure(mods, roots, default_kinds, cuts),
        },
    }


def to_markdown(data: dict) -> str:
    rows = ["| module | class | code lines (test / gpu-gated) | externals | env vars | depends on (normal) | gpu-only | test-only |",
            "|---|---|---:|---|---|---|---|---|"]
    for name, n in data["nodes"].items():
        if n["kind"] != "lib" or name == "lib":
            continue
        rows.append("| `{}` | {} | {} ({} / {}) | {} | {} | {} | {} | {} |".format(
            name, n["class"], n["lines_code"], n["lines_test"], n["lines_gpu_gated"],
            ", ".join(n["externals"]), ", ".join(n["env_vars"]) or "-",
            ", ".join(f"`{d}`" for d in n["deps_normal"]) or "-",
            ", ".join(f"`{d}`" for d in n["deps_gpu_only"]) or "-",
            ", ".join(f"`{d}`" for d in n["deps_test_only"]) or "-"))
    out = ["## Module table (generated by dep_closure.py at {})".format(data["baseline"]), ""]
    out += rows
    out.append("")
    for key, title in (("literal", "Literal closure (normal + gpu + not_gpu edges)"),
                       ("default_build", "Default-build closure (normal + not_gpu edges; no gpu-cuda feature)"),
                       ("after_cuts", "Closure after the planned cuts")):
        c = data["closures"][key]
        out.append(f"### {title}")
        out.append("")
        out.append(f"roots: {', '.join(f'`{r}`' for r in c['roots'])}; cuts: {', '.join(f'`{x}`' for x in c['cuts']) or 'none'}")
        out.append("")
        out.append(f"{c['module_count']} modules, {c['code_lines']} code lines ({c['code_lines_excluding_test']} excluding `#[cfg(test)]`): "
                   + ", ".join(f"`{m}`" for m in c["members"]))
        out.append("")
    ext_rows = ["| consumer | uses |", "|---|---|"]
    for name, n in data["nodes"].items():
        if n["kind"] in ("bin", "test", "example"):
            ext_rows.append(f"| `{name}` | {', '.join(f'`{d}`' for d in n['deps_normal']) or '-'} |")
    out.append("### Binary, integration tests and examples: which library modules each one reaches")
    out.append("")
    out += ext_rows
    out.append("")
    return "\n".join(out)


def git_head(repo: Path) -> str:
    try:
        head = (repo / ".git")
        if head.is_file():
            gitdir = Path(head.read_text().split(":", 1)[1].strip())
            if not gitdir.is_absolute():
                gitdir = repo / gitdir
        else:
            gitdir = head
        ref = (gitdir / "HEAD").read_text().strip()
        if ref.startswith("ref:"):
            refpath = ref.split(" ", 1)[1]
            common = gitdir
            if (gitdir / "commondir").exists():
                common = (gitdir / (gitdir / "commondir").read_text().strip()).resolve()
            cand = common / refpath
            if cand.exists():
                return cand.read_text().strip()[:7] + f" ({refpath.rsplit('/', 1)[-1]})"
            packed = common / "packed-refs"
            if packed.exists():
                for line in packed.read_text().splitlines():
                    if line.endswith(" " + refpath):
                        return line.split(" ", 1)[0][:7] + f" ({refpath.rsplit('/', 1)[-1]})"
            return refpath
        return ref[:7]
    except OSError:
        return "unknown"


def main() -> int:
    here = Path(__file__).resolve()
    repo = here.parents[2]
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", default=str(repo / "hashline"), help="crate directory (contains src/lib.rs)")
    ap.add_argument("--out", default=str(repo / "zkp-core" / "dependency_graph.json"), help="JSON output path ('-' for stdout)")
    ap.add_argument("--md", default="-", help="Markdown table output path ('-' for stdout, '' to skip)")
    ap.add_argument("--root", action="append", default=[], help="root module for the closure (repeatable; default: layer, tables_v3)")
    ap.add_argument("--cut", action="append", default=[], help="edge to remove for the after-cuts closure, as from:to (repeatable)")
    ap.add_argument("--no-default-cuts", action="store_true", help="do not apply the design's default cut list")
    ap.add_argument("--trace", action="append", default=[], help="print the gate in force on every code line of this module or file (repeatable)")
    args = ap.parse_args()
    TRACE.update(args.trace)

    src_root = Path(args.src).resolve()
    mods = discover(src_root)
    roots = args.root or ["layer", "tables_v3"]
    for r in roots:
        if r not in mods:
            sys.exit(f"root {r!r} is not a module; known: {', '.join(sorted(mods))}")
    cuts_raw = ([] if args.no_default_cuts else list(DEFAULT_CUTS)) + args.cut
    cuts = set()
    for c in cuts_raw:
        a, _, b = c.partition(":")
        if not a or not b:
            sys.exit(f"bad --cut {c!r}; want from:to")
        cuts.add((a, b))
    data = to_json(mods, src_root, roots, cuts, git_head(repo))
    text = json.dumps(data, indent=2, sort_keys=True) + "\n"
    if args.out == "-":
        sys.stdout.write(text)
    else:
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out).write_text(text, encoding="utf-8")
        print(f"wrote {args.out} ({len(data['nodes'])} nodes, {len(data['edges'])} edge records)", file=sys.stderr)
    if args.md:
        md = to_markdown(data)
        if args.md == "-":
            sys.stdout.write(md)
        else:
            Path(args.md).write_text(md, encoding="utf-8")
            print(f"wrote {args.md}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
