#!/usr/bin/env python3
"""zk60_attention_native_inventory.py -- the NATIVE private-attention layout, parsed from Rust,
turned into the inventory the two security tools eat, and both tools re-run on it (review R-1).

WHY.  `scripts/zk60_attention_pair_schedule.py` (FA2's rank model in repair form over the whole
A / H commitments) and `scripts/zk60_attention_cfs_slots.py` (FA6's criterion on the CFS slot
table with host batching) were run on `results/zk60_opus_attention_inventory.json`, which
describes the LEGACY `AttnLayout` (135 claim sites, 10 range tables with block masks, a W
commitment, both norm sites, residual 2, the FFN seams).  The delegated lane then implemented
the attention half natively and deviated: `hashline/src/private_attention/layout.rs` declares a
different geometry (50 A planes, 35 H planes, one 256-entry U8 table plus one exp table, no
block masks, 75 A sites / 35 H sites, 18 CFS slots, 5 hosts).  `ZK60_PRIVATE_ATTENTION_NATIVE.md`
section 6, R-1 asks exactly for the two tools to be re-run on THAT layout.  This script does it.

WHAT IT PARSES (statically; no cargo, no proof, no witness).
  * `hashline/src/private_attention/layout.rs`: the consts, the `Dom` logs, the `a_dom` / `h_dom`
    plane->domain maps, the `lookups` / `helpers` tables, `SLOT_NAMES` / `SLOTS` / `SLOT_KINDS` /
    `HOSTS` / `A_SITES` / `H_SITES` / `A_GROUPS` / `H_GROUPS` / `N_FUNCTIONALS` / `M_ROWS`, and it
    re-executes `Layout::new`'s row arithmetic in Python (a_off, h_off, the mask base, the
    proximity pair, the totals).
  * `hashline/src/private_attention/argument.rs`, function `define`: the ordered claim sites of
    every slot with their evaluation points.  layout.rs declares only the site COUNTS per slot;
    the evaluation-point tails -- i.e. the PCS column keys that decide `A_GROUPS` / `H_GROUPS` --
    exist only in `define`.  That is recorded as ambiguity A-1 below.  A tiny interpreter for the
    subset of Rust `define` uses (challenge vectors, `rho(..)` / `fixed(..)` / `Coord::Flip`,
    `b.a` / `b.a_at` / `b.a_slice` / `b.a_range` / `b.h` / `b.endpoint`, the two `for` loops and
    the three slot-dependent tuple lets) evaluates it; every site-creating call in every arm must
    be consumed or the parse fails loudly.
  * `hashline/src/private_attention/protocol.rs`: `logup_sum_claim` (the value-0 all-ones sum
    claim on H) is read for its plane set and signs.
  * the PCS grouping rule is `zkp-core/src/pcs.rs::zpart_weights` / `group_zclaims`: the key of a
    claim is (point tail, c0, len), c0 / len being the column window of a sub-row slice.

WHAT IT WRITES (under results/zk60_private_attention_native_evidence/rank_cfs/):
  zk60_attention_native_inventory.json   the derived inventory (A1_schedule.claims + layout +
                                         logup_tables + A2_cfs_slots.P1), tool-shaped
  zk60_attention_native_hosts.json       the host mapping for the CFS tool
  zk60_attention_native_pair_schedule.json  the rank tool's record on this layout
  zk60_attention_native_schedule.json    the site/row schedule the rank tool derives
  zk60_attention_native_cfs_slots.json   the CFS tool's record on this layout
  zk60_attention_native_summary.json     cross-checks against the note, findings, adaptations

ADAPTATIONS (both tools are imported by file path and NEVER edited; every adaptation is a
rebinding of a module-level constant or a filtered copy of the input, and each is listed in the
summary record under `adaptations`).  See `ADAPTATIONS` at the bottom of this module.

Usage:
    python3 scripts/zk60_attention_native_inventory.py \
        --repo /home/victor/wt-zk60-attention-compile \
        --out-dir results/zk60_private_attention_native_evidence/rank_cfs [--seed N]
Exit status is nonzero when a cross-check or a tool verdict fails.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import re
import sys
from typing import Dict, List, Optional, Sequence, Tuple

N_COLS = 256
LOG_N = 8
DEFAULT_SEED = 2026

# ---------------------------------------------------------------------------
# 0. tiny Rust-source helpers
# ---------------------------------------------------------------------------


class RustParseError(Exception):
    pass


def strip_comments(src: str) -> str:
    """Drop `//`-comments (there are no block comments in these files) but keep line structure."""
    out = []
    for line in src.splitlines():
        # never inside a string literal in these files except SLOT_NAMES / error messages,
        # which contain no `//`
        i = line.find("//")
        out.append(line[:i] if i >= 0 else line)
    return "\n".join(out)


def split_top(s: str, sep: str = ",") -> List[str]:
    """Split on `sep` at bracket depth 0."""
    parts, depth, cur = [], 0, []
    for ch in s:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == sep and depth == 0:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    parts.append("".join(cur))
    return [p.strip() for p in parts if p.strip() != ""]


def brace_block(src: str, start: int) -> Tuple[str, int]:
    """The `{...}` block starting at the brace index `start`; returns (inner, index after)."""
    assert src[start] == "{", src[start : start + 20]
    depth = 0
    for i in range(start, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return src[start + 1 : i], i + 1
    raise RustParseError("unbalanced braces")


def fn_body(src: str, name: str) -> str:
    m = re.search(r"fn\s+" + re.escape(name) + r"\s*(<[^>]*>)?\s*\(", src)
    if not m:
        raise RustParseError(f"function {name} not found")
    i = src.index("{", m.end())
    return brace_block(src, i)[0]


# ---------------------------------------------------------------------------
# 1. layout.rs
# ---------------------------------------------------------------------------

CONST_RE = re.compile(r"^\s*(?:pub\(crate\)\s+|pub\s+)?const\s+([A-Z][A-Z0-9_]*)\s*:\s*([^=]+?)\s*=\s*(.+?);\s*$", re.M)


def parse_scalar_consts(src: str) -> Dict[str, int]:
    """`const NAME: usize = <int expr>;` with int literals, other consts, `1 << k`, `X / Y`."""
    env: Dict[str, int] = {}
    for m in CONST_RE.finditer(src):
        name, ty, val = m.group(1), m.group(2).strip(), m.group(3).strip()
        if ty not in ("usize", "u32", "i64"):
            continue
        try:
            env[name] = eval_int(val, env)
        except RustParseError:
            continue
    return env


INT_RE = re.compile(r"^-?\d[\d_]*$")


def eval_int(expr: str, env: Dict[str, int]) -> int:
    """Evaluate the integer-expression subset used in these files."""
    e = expr.strip()
    while e.startswith("(") and e.endswith(")") and split_top(e[1:-1], "+") and _balanced(e[1:-1]):
        e = e[1:-1].strip()
    if INT_RE.match(e.replace("_", "")):
        return int(e.replace("_", ""))
    if e in env:
        return env[e]
    for op, fn in ((" << ", lambda a, b: a << b), (" >> ", lambda a, b: a >> b)):
        if op in e:
            a, b = e.split(op, 1)
            return fn(eval_int(a, env), eval_int(b, env))
    for op in (" + ", " - "):
        parts = split_top(e, op.strip())
        if len(parts) > 1 and op in e:
            acc = eval_int(parts[0], env)
            for p in parts[1:]:
                acc = acc + eval_int(p, env) if op == " + " else acc - eval_int(p, env)
            return acc
    for op, fn in ((" * ", lambda a, b: a * b), (" / ", lambda a, b: a // b)):
        if op in e:
            a, b = e.split(op, 1)
            return fn(eval_int(a, env), eval_int(b, env))
    m = re.match(r"^(\w+)\s+as\s+\w+$", e)
    if m:
        return eval_int(m.group(1), env)
    raise RustParseError(f"cannot evaluate integer expression {expr!r}")


def _balanced(s: str) -> bool:
    d = 0
    for ch in s:
        if ch in "([{":
            d += 1
        elif ch in ")]}":
            d -= 1
            if d < 0:
                return False
    return d == 0


def parse_dom_logs(src: str) -> Dict[str, int]:
    """`fn log(self)`'s match: `Dom::T => 5,` / `Dom::L | Dom::D | Dom::Q => 9,`."""
    body = fn_body(src, "log")
    i = body.index("{", body.index("match"))
    inner = brace_block(body, i)[0]
    out: Dict[str, int] = {}
    for arm in split_top(inner, ","):
        if "=>" not in arm:
            continue
        pat, val = arm.split("=>", 1)
        n = int(val.strip())
        for alt in pat.split("|"):
            alt = alt.strip()
            if alt.startswith("Dom::"):
                out[alt[5:]] = n
    return out


def parse_dom_map(src: str, fn_name: str, planes: Dict[str, int], n_planes: int) -> List[str]:
    """`a_dom` / `h_dom`: plane index -> domain name, via `A | B => Dom::X`, `A..=B => Dom::X`,
    `_ => Dom::X`."""
    body = fn_body(src, fn_name)
    i = body.index("{", body.index("match"))
    inner = brace_block(body, i)[0]
    out: List[Optional[str]] = [None] * n_planes
    default: Optional[str] = None
    for arm in split_top(inner, ","):
        if "=>" not in arm:
            continue
        pat, val = arm.split("=>", 1)
        dom = val.strip()
        if not dom.startswith("Dom::"):
            raise RustParseError(f"{fn_name}: arm value {dom!r}")
        dom = dom[5:]
        pat = pat.strip()
        if pat == "_":
            default = dom
            continue
        for alt in pat.split("|"):
            alt = alt.strip()
            if "..=" in alt:
                lo_s, hi_s = alt.split("..=")
                lo = planes.get(lo_s.strip(), None)
                hi = planes.get(hi_s.strip(), None)
                if lo is None:
                    lo = eval_int(lo_s, planes)
                if hi is None:
                    hi = eval_int(hi_s, planes)
                for p in range(lo, hi + 1):
                    out[p] = dom
            else:
                p = planes.get(alt, None)
                if p is None:
                    p = eval_int(alt, planes)
                out[p] = dom
    if default is None and any(x is None for x in out):
        raise RustParseError(f"{fn_name}: planes without a domain and no default arm")
    return [x if x is not None else default for x in out]


ARRAY_RE = re.compile(r"const\s+(\w+)\s*:\s*\[[^\]]*\]\s*=\s*\[", re.S)


def parse_array(src: str, name: str) -> List[str]:
    """The top-level elements of `const NAME: [...; N] = [ ... ];`."""
    m = re.search(r"const\s+" + re.escape(name) + r"\s*:\s*\[.*?\]\s*=\s*\[", src, re.S)
    if not m:
        raise RustParseError(f"array {name} not found")
    depth, start = 1, m.end()
    for i in range(start, len(src)):
        if src[i] == "[":
            depth += 1
        elif src[i] == "]":
            depth -= 1
            if depth == 0:
                return split_top(src[start:i], ",")
    raise RustParseError(f"array {name}: unbalanced")


def parse_lookup_counts(src: str, dom_logs: Dict[str, int]) -> Dict[str, int]:
    """`fn lookups(dom)`: the number of U8 lookups a domain declares."""
    body = fn_body(src, "lookups")
    i = body.index("{", body.index("match dom"))
    inner = brace_block(body, i)[0]
    counts: Dict[str, int] = {d: 0 for d in dom_logs}
    pos = 0
    while True:
        m = re.compile(r"(Dom::\w+(?:\s*\|\s*Dom::\w+)*)\s*=>\s*").search(inner, pos)
        if not m:
            break
        doms = [x.strip()[5:] for x in m.group(1).split("|")]
        rest = inner[m.end():]
        if rest.lstrip().startswith("{"):
            j = inner.index("{", m.end())
            arm, nxt = brace_block(inner, j)
        else:
            end = m.end()
            depth = 0
            while end < len(inner) and not (inner[end] == "," and depth == 0):
                if inner[end] in "([{":
                    depth += 1
                elif inner[end] in ")]}":
                    depth -= 1
                end += 1
            arm, nxt = inner[m.end():end], end + 1
        n = 0
        for stmt in split_top(arm, ";"):
            stmt = stmt.strip()
            if stmt.startswith("v.push("):
                n += 1
            elif stmt.startswith("v.extend("):
                n += _extend_count(stmt[len("v.extend("):].rstrip(")").strip())
            elif stmt == "":
                continue
            else:
                raise RustParseError(f"lookups: unhandled statement {stmt!r}")
        for d in doms:
            counts[d] = n
        pos = nxt
    return counts


def _extend_count(arg: str) -> int:
    arg = arg.strip()
    if arg.startswith("["):
        return len(split_top(arg[1:arg.rindex("]")], ","))
    if arg.startswith("sym("):
        return 2                       # `fn sym(p) -> [Lk; 2]`
    m = re.match(r"^\(0\.\.(\d+)\)\.map\(", arg)
    if m:
        return int(m.group(1))
    raise RustParseError(f"lookups: unhandled extend argument {arg!r}")


def parse_helpers(src: str) -> Dict[str, Tuple[str, int]]:
    """`fn helpers(dom)`: domain -> (first H helper plane name, helper count)."""
    body = fn_body(src, "helpers")
    i = body.index("{", body.index("match dom"))
    inner = brace_block(body, i)[0]
    out: Dict[str, Tuple[str, int]] = {}
    for arm in split_top(inner, ","):
        if "=>" not in arm:
            continue
        pat, val = arm.split("=>", 1)
        val = val.strip()
        if not (val.startswith("(") and val.endswith(")")):
            raise RustParseError(f"helpers: arm {val!r}")
        first, cnt = split_top(val[1:-1], ",")
        for alt in pat.split("|"):
            alt = alt.strip()
            if alt.startswith("Dom::"):
                out[alt[5:]] = (first.strip(), int(cnt))
    return out


class Layout:
    """`layout.rs` as Python: consts, plane domains, the `Layout::new` row arithmetic."""

    def __init__(self, src: str):
        self.src = strip_comments(src)
        self.consts = parse_scalar_consts(self.src)
        for k in ("N_A", "N_H", "N_SLOTS", "LOG_N", "N", "A_GROUPS", "H_GROUPS", "N_FUNCTIONALS", "M_ROWS", "N_LIMBS", "T"):
            if k not in self.consts:
                raise RustParseError(f"layout.rs: const {k} missing")
        self.n = self.consts["N"]
        self.n_a, self.n_h, self.n_slots = self.consts["N_A"], self.consts["N_H"], self.consts["N_SLOTS"]
        self.dom_logs = parse_dom_logs(self.src)
        self.a_planes = {k: v for k, v in self.consts.items() if k.startswith("A_") and v < self.n_a and k not in ("A_GROUPS",)}
        self.h_planes = {k: v for k, v in self.consts.items() if k.startswith("H_") and v < self.n_h and k not in ("H_GROUPS",)}
        self.a_dom = parse_dom_map(self.src, "a_dom", self.consts, self.n_a)
        self.h_dom = parse_dom_map(self.src, "h_dom", self.consts, self.n_h)
        self.slot_names = [x.strip().strip('"') for x in parse_array(self.src, "SLOT_NAMES")]
        self.slots = [tuple(int(y) for y in split_top(x.strip()[1:-1], ",")) for x in parse_array(self.src, "SLOTS")]
        self.slot_kinds = [x.strip().split("::")[-1] for x in parse_array(self.src, "SLOT_KINDS")]
        self.a_sites = [int(x) for x in parse_array(self.src, "A_SITES")]
        self.h_sites = [int(x) for x in parse_array(self.src, "H_SITES")]
        self.hosts: List[Tuple[int, List[int]]] = []
        for entry in parse_array(self.src, "HOSTS"):
            host_s, hosted_s = split_top(entry.strip()[1:-1], ",")
            hosted = [self.consts[x.strip()] for x in split_top(hosted_s.strip().lstrip("&").strip()[1:-1], ",")]
            self.hosts.append((self.consts[host_s.strip()], hosted))
        self.lookup_counts = parse_lookup_counts(self.src, self.dom_logs)
        self.helpers = parse_helpers(self.src)
        self.lookup_doms = [x.strip().split("::")[-1] for x in parse_array(self.src, "LOOKUP_DOMS")]
        # slot constant name -> index (SC_*)
        self.slot_const = {k: v for k, v in self.consts.items() if k.startswith("SC_") and v < self.n_slots}
        self.slot_name_of = {v: k for k, v in self.slot_const.items()}
        self._geometry()

    # ---- Layout::new ------------------------------------------------------
    def rows_of(self, log: int) -> int:
        return -((-(1 << log)) // self.n)

    def a_log(self, plane: int) -> int:
        return self.dom_logs[self.a_dom[plane]]

    def h_log(self, plane: int) -> int:
        return self.dom_logs[self.h_dom[plane]]

    def _geometry(self) -> None:
        row, self.a_off = 0, []
        for p in range(self.n_a):
            self.a_off.append(row * self.n)
            row += self.rows_of(self.a_log(p))
        self.a_data_rows = row
        self.a_prefix = [0]
        for s in range(self.n_slots):
            self.a_prefix.append(self.a_prefix[-1] + self.a_sites[s])
        self.h_prefix = [0]
        for s in range(self.n_slots):
            self.h_prefix.append(self.h_prefix[-1] + self.h_sites[s])
        self.a_mask_base = self.a_data_rows
        self.a_prox = self.a_mask_base + 2 * self.a_prefix[self.n_slots]
        self.a_rows = self.a_prox + 2
        row, self.h_off = 0, []
        for p in range(self.n_h):
            r = self.rows_of(self.h_log(p))
            self.h_off.append((row * self.n, (row + r) * self.n))
            row += 2 * r
        self.h_data_rows = row
        self.h_mask_base = self.h_data_rows
        self.h_prox = self.h_mask_base + 2 * self.h_prefix[self.n_slots]
        self.h_rows = self.h_prox + 2

    def a_site_row(self, slot: int, k: int) -> int:
        return self.a_mask_base + 2 * (self.a_prefix[slot] + k)

    def h_site_row(self, slot: int, k: int) -> int:
        return self.h_mask_base + 2 * (self.h_prefix[slot] + k)

    def limb_off(self, k: int) -> int:
        return self.a_off[self.consts["A_LIMB"]] + k * self.consts["T"]

    def h_u_rows(self) -> List[int]:
        re_, im_ = self.h_off[self.consts["H_U"]]
        return [re_ // self.n, im_ // self.n]


# ---------------------------------------------------------------------------
# 2. argument.rs::define -- the ordered claim sites with their points
# ---------------------------------------------------------------------------

SITE_CALL_RE = re.compile(r"\bb\.(a|a_at|a_slice|a_range|h|endpoint)\s*\(")


class Site:
    __slots__ = ("cm", "slot", "k", "plane", "offset", "log", "coords", "desc", "ext_round")

    def __init__(self, cm: str, slot: int, k: int, plane: Optional[int], offset, log: int, coords: List[str], desc: str, ext_round: int = 0):
        self.cm, self.slot, self.k, self.plane = cm, slot, k, plane
        self.offset, self.log, self.coords, self.desc, self.ext_round = offset, log, coords, desc, ext_round


class DefineParser:
    """A tiny interpreter for the Rust subset `argument::define` uses."""

    def __init__(self, lay: Layout, src: str):
        self.lay = lay
        self.src = strip_comments(src)
        self.pts: Dict[str, List[str]] = {}          # persists across slots (the `Points` struct)
        self.sites: Dict[int, List[Site]] = {}
        self.unconsumed: List[str] = []

    # ---- expression helpers ----------------------------------------------
    def _int(self, expr: str, env: Dict[str, int]) -> int:
        """Integer expressions, after substituting the layout calls `define` uses."""
        e = re.sub(r"\s+as\s+(usize|u32|i64)\b", "", expr.strip())
        merged = dict(self.lay.consts)
        merged.update({k: v for k, v in env.items() if isinstance(v, int) and not isinstance(v, bool)})

        def sub(pat: str, fn) -> None:
            nonlocal e
            prev = None
            while prev != e:
                prev = e
                e = re.sub(pat, lambda m: str(fn(m)), e)

        sub(r"helpers\(Dom::(\w+)\)\.1", lambda m: self.lay.helpers[m.group(1)][1])
        sub(r"a_dom\(([\w ]+)\)\.log\(\)", lambda m: self.lay.a_log(eval_int(m.group(1), merged)))
        sub(r"h_dom\(([\w ]+)\)\.log\(\)", lambda m: self.lay.h_log(eval_int(m.group(1), merged)))
        sub(r"Dom::(\w+)\.log\(\)", lambda m: self.lay.dom_logs[m.group(1)])
        sub(r"helpers\((\w+)\)\.1", lambda m: self.lay.helpers[self._dom_of(m.group(1), env)][1])
        sub(r"(?<![:\w])(\w+)\.log\(\)", lambda m: self.lay.dom_logs[self._dom_of(m.group(1), env)])
        sub(r"lay\.limb_off\(([\w ]+)\)", lambda m: self.lay.limb_off(eval_int(m.group(1), merged)))
        sub(r"lay\.a_off\[([\w ]+)\]", lambda m: self.lay.a_off[eval_int(m.group(1), merged)])
        sub(r"(\w+)\.trailing_zeros\(\)", lambda m: ((eval_int(m.group(1), merged) & -eval_int(m.group(1), merged)).bit_length() - 1))
        return eval_int(e, merged)

    def _dom_of(self, name: str, env: Dict) -> str:
        v = env.get(name)
        if isinstance(v, str) and v in self.lay.dom_logs:
            return v
        raise RustParseError(f"{name!r} is not a domain in scope")

    def _coord_vec(self, expr: str, env: Dict, slot: int) -> List[str]:
        """`rho(0..K)` / `fixed(&EXPR)` / a named local."""
        e = expr.strip()
        m = re.match(r"^rho\(0\.\.(.+)\)$", e)
        if m:
            k = self._int(m.group(1), env)
            return [f"rho_{self.lay.slot_name_of[slot]}[{i}]" for i in range(k)]
        m = re.match(r"^fixed\(&(.+)\)$", e)
        if m:
            return list(self._sym_vec(m.group(1), env))
        if e in env and isinstance(env[e], list):
            return list(env[e])
        raise RustParseError(f"coord vector {expr!r}")

    def _sym_vec(self, expr: str, env: Dict) -> List[str]:
        """A challenge vector expression: a local, `pts.X`, or `cat(&[&A, &B])`."""
        e = expr.strip()
        m = re.match(r"^cat\(&\[(.*)\]\)$", e)
        if m:
            out: List[str] = []
            for part in split_top(m.group(1), ","):
                out += self._sym_vec(part.strip().lstrip("&"), env)
            return out
        if e.startswith("pts."):
            key = e[4:]
            if key not in self.pts:
                raise RustParseError(f"pts.{key} read before assignment")
            return list(self.pts[key])
        if e in env and isinstance(env[e], list):
            return list(env[e])
        raise RustParseError(f"symbol vector {expr!r}")

    # ---- the arms ---------------------------------------------------------
    def parse(self) -> Dict[int, List[Site]]:
        body = fn_body(self.src, "define")
        i = body.index("{", body.index("match slot"))
        inner = brace_block(body, i)[0]
        pos = 0
        arm_re = re.compile(r"(?m)^\s{8}((?:SC_\w+(?:\s*\|\s*SC_\w+)*)|_)\s*=>\s*")
        arms: List[Tuple[List[str], str]] = []
        while True:
            m = arm_re.search(inner, pos)
            if not m:
                break
            pat = m.group(1)
            if inner[m.end():].lstrip().startswith("{"):
                j = inner.index("{", m.end())
                block, nxt = brace_block(inner, j)
            else:
                j = inner.index("\n", m.end())
                block, nxt = inner[m.end():j], j
            if pat != "_":
                arms.append(([x.strip() for x in pat.split("|")], block))
            pos = nxt
        for names, block in arms:
            for nm in names:
                slot = self.lay.slot_const[nm]
                self.sites[slot] = self._run_arm(slot, block)
        for s in range(self.lay.n_slots):
            self.sites.setdefault(s, [])
        return self.sites

    def _run_arm(self, slot: int, block: str) -> List[Site]:
        env: Dict[str, object] = {"slot": slot}
        out: List[Site] = []
        ak = hk = 0
        consumed = 0
        expected_calls = len(SITE_CALL_RE.findall(block))
        for stmt in self._statements(block):
            s = stmt.strip().rstrip(";").strip()
            if not s:
                continue
            handled_call = self._statement(s, env, slot, out)
            if handled_call is not None:
                consumed += handled_call
        # renumber the per-commitment site index k in call order
        for site in out:
            if site.cm == "A":
                site.k, ak = ak, ak + 1
            elif site.cm == "H":
                site.k, hk = hk, hk + 1
        if consumed != expected_calls:
            raise RustParseError(
                f"slot {slot} ({self.lay.slot_name_of[slot]}): {consumed} of {expected_calls} site calls consumed")
        return out

    @staticmethod
    def _statements(block: str) -> List[str]:
        """Top-level statements: split on `;` at depth 0, and after a depth-0 `}` that ends a
        block statement (`if ... {}`, `for ... {}`, `match ... {}`) -- i.e. one not followed by
        `else`, `.`, `,`, `;` or `)`."""
        out, depth, cur = [], 0, []
        n = len(block)
        for i, ch in enumerate(block):
            if ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth -= 1
            if ch == ";" and depth == 0:
                out.append("".join(cur))
                cur = []
                continue
            cur.append(ch)
            if ch == "}" and depth == 0:
                j = i + 1
                while j < n and block[j] in " \t\r\n":
                    j += 1
                if not (block[j:j + 4] == "else" or (j < n and block[j] in ".,;)")):
                    out.append("".join(cur))
                    cur = []
        tail = "".join(cur).strip()
        if tail:
            out.append(tail)
        return out

    def _cond(self, expr: str, env: Dict, slot: int) -> bool:
        e = expr.strip()
        if "||" in e:
            return any(self._cond(x, env, slot) for x in e.split("||"))
        if "&&" in e:
            return all(self._cond(x, env, slot) for x in e.split("&&"))
        m = re.match(r"^slot\s*==\s*(SC_\w+)$", e)
        if m:
            return self.lay.slot_const[m.group(1)] == slot
        if e in env and isinstance(env[e], bool):
            return bool(env[e])
        raise RustParseError(f"condition {expr!r}")

    def _statement(self, s: str, env: Dict, slot: int, out: List[Site]) -> Optional[int]:
        """Returns the number of site-creating calls the statement consumed, or None."""
        # --- challenges
        m = re.match(r"^let\s+(?:mut\s+)?(\w+)\s*=\s*tr\.challenge_fp2_vec\((.+)\)$", s)
        if m:
            k = self._int(m.group(2), env)
            env[m.group(1)] = [f"{self.lay.slot_name_of[slot]}.{m.group(1)}[{i}]" for i in range(k)]
            return None
        m = re.match(r"^pts\.(\w+)\s*=\s*tr\.challenge_fp2_vec\((.+)\)$", s)
        if m:
            k = self._int(m.group(2), env)
            self.pts[m.group(1)] = [f"{self.lay.slot_name_of[slot]}.{m.group(1)}[{i}]" for i in range(k)]
            return None
        m = re.match(r"^(?:let\s+(?:mut\s+)?(\w+)|pts\.(\w+))\s*=\s*tr\.challenge_fp2\(\)$", s)
        if m:
            name = m.group(1) or m.group(2)
            val = [f"{self.lay.slot_name_of[slot]}.{name}"]
            if m.group(1):
                env[name] = val
            else:
                self.pts[name] = val
            return None
        m = re.match(r"^(?:let\s+(?:mut\s+)?(\w+)|pts\.(\w+))\s*=\s*nonzero\(tr\.challenge_fp2_vec\((.+)\)\)\?$", s)
        if m:
            name = m.group(1) or m.group(2)
            k = self._int(m.group(3), env)
            env[name] = [f"{self.lay.slot_name_of[slot]}.{name}[{i}]" for i in range(k)]
            return None
        # --- slot-dependent tuple lets
        m = re.match(r"^let\s+\(([^)]*)\)\s*(?::\s*\([^)]*\)\s*)?=\s*match\s+slot\s*\{(.*)\}$", s, re.S)
        if m:
            names = [x.strip() for x in m.group(1).split(",")]
            chosen = None
            for arm in split_top(m.group(2), ","):
                if "=>" not in arm:
                    continue
                pat, val = arm.split("=>", 1)
                pat = pat.strip()
                names_ok = pat == "_" or any(self.lay.slot_const.get(p.strip()) == slot for p in pat.split("|"))
                if names_ok and (pat != "_" or chosen is None):
                    vals = split_top(val.strip().strip("()"), ",")
                    if pat != "_":
                        chosen = vals
                        break
                    chosen = vals
            if chosen is None:
                raise RustParseError(f"match slot: no arm for slot {slot}")
            for nm, v in zip(names, chosen):
                env[nm] = self._tuple_value(v, env)
            return None
        m = re.match(r"^let\s+\(([^)]*)\)\s*=\s*if\s+(\w+)\s*\{(.*?)\}\s*else\s*\{(.*)\}$", s, re.S)
        if m:
            names = [x.strip() for x in m.group(1).split(",")]
            cond = env.get(m.group(2))
            vals = split_top((m.group(3) if cond else m.group(4)).strip().strip("()"), ",")
            for nm, v in zip(names, vals):
                env[nm] = self._tuple_value(v, env)
            return None
        m = re.match(r"^let\s+(\w+)\s*=\s*slot\s*==\s*(SC_\w+)$", s)
        if m:
            env[m.group(1)] = self.lay.slot_const[m.group(2)] == slot
            return None
        m = re.match(r"^let\s+(\w+)\s*=\s*(helpers\(Dom::\w+\)\.1|\w+\.log\(\)|Dom::\w+\.log\(\))$", s)
        if m:
            env[m.group(1)] = self._int(m.group(2), env)
            return None
        # --- point bookkeeping (`pts.X = ...`), coord vectors
        m = re.match(r"^(?:let\s+(?:mut\s+)?(\w+)|pts\.(\w+))\s*=\s*(cat\(&\[.*\]\))$", s, re.S)
        if m:
            name = m.group(1) or m.group(2)
            vec = self._sym_vec(m.group(3), env)
            if m.group(1):
                env[name] = vec
            else:
                self.pts[name] = vec
            return None
        m = re.match(r"^let\s+mut\s+(\w+)\s*=\s*(fixed\(&.*\)|rho\(0\.\..*\))$", s, re.S)
        if m:
            env[m.group(1)] = self._coord_vec(m.group(2), env, slot)
            return None
        m = re.match(r"^(\w+)\.extend\((.*)\)$", s, re.S)
        if m and m.group(1) in env and isinstance(env[m.group(1)], list):
            env[m.group(1)] = list(env[m.group(1)]) + self._coord_vec(m.group(2), env, slot)
            return None
        m = re.match(r"^(\w+)\[(.+?)\]\s*=\s*Coord::Flip\((.+)\)$", s)
        if m:
            vec = list(env[m.group(1)])
            idx = self._int(m.group(2), env)
            kk = self._int(m.group(3), env)
            vec[idx] = f"1-rho_{self.lay.slot_name_of[slot]}[{kk}]"
            env[m.group(1)] = vec
            return None
        # --- plain `if` / `if ... else` block statements
        m = re.match(r"^if\s+(.+?)\s*\{(.*)\}\s*else\s*\{(.*)\}$", s, re.S)
        if m and not s.startswith("let"):
            body = m.group(2) if self._cond(m.group(1), env, slot) else m.group(3)
            n = len(SITE_CALL_RE.findall(m.group(2))) + len(SITE_CALL_RE.findall(m.group(3)))
            for inner_stmt in self._statements(body):
                self._statement(inner_stmt.strip().rstrip(";").strip(), env, slot, out)
            return n or None
        m = re.match(r"^if\s+(.+?)\s*\{(.*)\}$", s, re.S)
        if m and not s.startswith("let"):
            n = len(SITE_CALL_RE.findall(m.group(2)))
            if self._cond(m.group(1), env, slot):
                for inner_stmt in self._statements(m.group(2)):
                    self._statement(inner_stmt.strip().rstrip(";").strip(), env, slot, out)
            return n or None
        # --- loops around site calls
        m = re.match(r"^for\s+(\w+)\s+in\s+(.+?)\.\.(.+?)\s*\{(.*)\}$", s, re.S)
        if m:
            lo, hi = self._int(m.group(2), env), self._int(m.group(3), env)
            # the loop body's site calls are counted ONCE (textually), however many
            # iterations they run for
            n = len(SITE_CALL_RE.findall(m.group(4)))
            for it in range(lo, hi):
                env[m.group(1)] = it
                for inner_stmt in self._statements(m.group(4)):
                    self._statement(inner_stmt.strip().rstrip(";").strip(), env, slot, out)
            return n or None
        # --- site calls
        n = self._maybe_site(s, env, slot, out)
        if n:
            return n
        if SITE_CALL_RE.search(s):
            raise RustParseError(f"slot {slot}: unrecognised site statement {s[:120]!r}")
        return None

    def _tuple_value(self, v: str, env: Dict):
        v = v.strip()
        if v.startswith("Dom::"):
            return v[5:]
        if v in self.lay.consts:
            return self.lay.consts[v]
        return v

    def _maybe_site(self, s: str, env: Dict, slot: int, out: List[Site]) -> int:
        body = s
        m = re.match(r"^let\s+(\w+)\s*=\s*(.*)$", s, re.S)
        if m:
            body = m.group(2)
        body = body.strip().rstrip("?")
        sn = self.lay.slot_name_of[slot]

        m = re.match(r"^b\.a\((.+)\)$", body, re.S)
        if m:
            arg = m.group(1).strip()
            mi = re.match(r"^if\s+slot\s*==\s*(SC_\w+)\s*\{(.+?)\}\s*else\s*\{(.+?)\}$", arg, re.S)
            if mi:
                arg = (mi.group(2) if self.lay.slot_const[mi.group(1)] == slot else mi.group(3)).strip()
            p = self._int(arg, env)
            log = self.lay.a_log(p)
            out.append(Site("A", slot, -1, p, self.lay.a_off[p], log,
                            [f"rho_{sn}[{i}]" for i in range(log)], f"A[{self._a_name(p)}]"))
            return 1
        m = re.match(r"^b\.a_at\((.+)\)$", body, re.S)
        if m:
            args = split_top(m.group(1), ",")
            p = self._int(args[0], env)
            log = self.lay.a_log(p)
            coords = self._coord_vec(args[1], env, slot)
            ext = self._int(args[2], env)
            out.append(Site("A", slot, -1, p, self.lay.a_off[p], log, coords, f"A[{self._a_name(p)}] @ point", ext))
            return 1
        m = re.match(r"^b\.a_slice\((.+)\)$", body, re.S)
        if m:
            args = split_top(m.group(1), ",")
            off = self._int(args[0], env)
            log = self._int(args[1], env)
            coords = self._coord_vec(args[2], env, slot)
            ext = self._int(args[3], env)
            out.append(Site("A", slot, -1, None, off, log, coords, f"A[offset {off}, log {log}]", ext))
            return 1
        m = re.match(r"^b\.a_range\((.+)\)$", body, re.S)
        if m:
            first, last = [self._int(x, env) for x in split_top(m.group(1), ",")]
            for p in range(first, last + 1):
                log = self.lay.a_log(p)
                out.append(Site("A", slot, -1, p, self.lay.a_off[p], log,
                                [f"rho_{sn}[{i}]" for i in range(log)], f"A[{self._a_name(p)}]"))
            return 1
        m = re.match(r"^b\.h\((.+)\)$", body, re.S)
        if m:
            p = self._int(m.group(1), env)
            log = self.lay.h_log(p)
            out.append(Site("H", slot, -1, p, self.lay.h_off[p][0], log,
                            [f"rho_{sn}[{i}]" for i in range(log)], f"H[{self._h_name(p)}]"))
            return 1
        m = re.match(r"^b\.endpoint\((.+)\)$", body, re.S)
        if m:
            arg = m.group(1).strip()
            mi = re.match(r"^if\s+slot\s*==\s*(SC_\w+)\s*\{(.+?)\}\s*else\s*\{(.+?)\}$", arg, re.S)
            cm = (mi.group(2) if self.lay.slot_const[mi.group(1)] == slot else mi.group(3)).strip() if mi else arg
            cm = cm.split("::")[-1]
            out.append(Site(cm, slot, 0, None, 0, 9, [f"rho_{sn}[{i}]" for i in range(9)], f"endpoint {cm}"))
            return 1
        return 0

    def _a_name(self, p: int) -> str:
        for k, v in self.lay.a_planes.items():
            if v == p:
                return k
        return f"A#{p}"

    def _h_name(self, p: int) -> str:
        for k, v in self.lay.h_planes.items():
            if v == p:
                return k
        return f"H#{p}"


# ---------------------------------------------------------------------------
# 3. the PCS grouping rule (zkp-core::pcs::zpart_weights / group_zclaims)
# ---------------------------------------------------------------------------


def zkey(offset: int, log: int, coords: Sequence[str]) -> Tuple[Tuple[str, ...], int, int]:
    """(tail, c0, len): tail is the point's column tail; a sub-row slice keys on its window."""
    if log >= LOG_N:
        return (tuple(coords[log - LOG_N:]), 0, N_COLS)
    return (tuple(coords), offset % N_COLS, 1 << log)


def group_sites(sites: Sequence[dict]) -> List[dict]:
    """First-occurrence grouping by ZKey, per commitment (the PCS's own rule)."""
    keys: List[Tuple] = []
    groups: List[dict] = []
    for s in sites:
        k = s["zkey"]
        if k in keys:
            groups[keys.index(k)]["members"].append(s["index"])
        else:
            keys.append(k)
            groups.append({"group": len(groups), "key": list(k[0]), "c0": k[1], "len": k[2], "members": [s["index"]]})
    return groups


# ---------------------------------------------------------------------------
# 4. the inventory
# ---------------------------------------------------------------------------

SUB_ROW_NOTE = ("sub-row slice: the PCS keys it on (point, c0, len); the rank tool's row model has "
                "no sub-row granularity, so the claim is presented as a single-row claim (log_size 8, "
                "data_rows 1) with a synthetic tail that preserves key equality")


def sub_row_tail(coords: Sequence[str], c0: int, length: int) -> List[str]:
    tail = [f"#sub(c0={c0},len={length})"] + list(coords)
    while len(tail) < LOG_N:
        tail.append("#pad")
    if len(tail) != LOG_N:
        raise RustParseError(f"sub-row tail of length {len(tail)}")
    return tail


def parse_logup_sum(src: str, lay: "Layout") -> dict:
    """`protocol.rs::logup_sum_claim`: the planes the value-0 all-ones sum claim negates, its
    loop range, and that every part carries an EMPTY point (i.e. it really is a sum claim)."""
    body = fn_body(strip_comments(src), "logup_sum_claim")
    m = re.search(r"for\s+p\s+in\s+0\.\.(\w+)\s*\{", body)
    if not m:
        raise RustParseError("logup_sum_claim: the plane loop was not found")
    n = lay.consts.get(m.group(1))
    if n != lay.n_h:
        raise RustParseError(f"logup_sum_claim: loop range {m.group(1)} = {n} != N_H = {lay.n_h}")
    ms = re.search(r"let\s+sign\s*=\s*if\s+(.+?)\s*\{\s*Fp2::ONE\.neg\(\)\s*\}\s*else\s*\{\s*Fp2::ONE\s*\}", body, re.S)
    if not ms:
        raise RustParseError("logup_sum_claim: the sign expression was not found")
    neg = sorted(lay.consts[x] for x in re.findall(r"p\s*==\s*(\w+)", ms.group(1)))
    parts = len(re.findall(r"parts\.push\(", body))
    if "point: vec![]" not in body:
        raise RustParseError("logup_sum_claim: a part carries a point; it is not an all-ones sum claim")
    if "value: Fp2::ZERO" not in body:
        raise RustParseError("logup_sum_claim: the claimed value is not zero")
    return {"negated_planes": neg, "planes": lay.n_h, "parts_per_plane": parts, "value": 0}


def build_inventory(lay: Layout, sites: Dict[int, List[Site]], src_sha: Dict[str, str], repo: str,
                    protocol_src: Optional[str] = None) -> dict:
    claims: List[dict] = []
    a_site_rows: List[int] = []
    h_site_rows: List[int] = []
    endpoints: List[dict] = []
    idx = 0
    derived_a: List[dict] = []
    derived_h: List[dict] = []

    for slot in range(lay.n_slots):
        for site in sites[slot]:
            sn = lay.slot_name_of[slot]
            section = lay.slot_names[slot]
            if site.cm in ("In", "Out"):
                endpoints.append({"slot": slot, "slot_const": sn, "commitment": site.cm, "log_size": site.log,
                                  "point": list(site.coords), "data_rows": 2, "mask_rows": [2, 3],
                                  "prox_rows": [4, 5, 6], "rows": 7,
                                  "source": "private_attention/argument.rs::B::endpoint + protocol.rs::check_endpoint_opening"})
                continue
            if site.cm == "A":
                mask_row = lay.a_site_row(slot, site.k)
                a_site_rows.append(mask_row)
            else:
                mask_row = lay.h_site_row(slot, site.k)
                h_site_rows.append(mask_row)
            key = zkey(site.offset, site.log, site.coords)
            if site.log >= LOG_N:
                log_size, data_rows, offset = site.log, 1 << (site.log - LOG_N), site.offset
                point = list(site.coords)
                group_key = list(site.coords[site.log - LOG_N:])
                sub = None
            else:
                log_size, data_rows = LOG_N, 1
                offset = (site.offset // N_COLS) * N_COLS
                group_key = sub_row_tail(site.coords, key[1], key[2])
                point = list(group_key)
                sub = {"true_log_size": site.log, "c0": key[1], "len": key[2], "true_point": list(site.coords),
                       "element_offset": site.offset, "note": SUB_ROW_NOTE}
            claim = {
                "index": idx, "commitment": site.cm, "site": f"{sn}#{site.k} {site.desc}",
                "slot": slot, "slot_const": sn, "site_index_in_slot": site.k,
                "group_key": group_key, "point": point, "log_size": log_size, "data_rows": data_rows,
                "offset": offset, "parts": 3 if site.cm == "A" else 4, "role": "masked terminal (reserved pair)",
                "section": section, "sum_claim": False,
                "source": "hashline/src/private_attention/argument.rs::define + layout.rs",
                "mask_rows": [mask_row, mask_row + 1], "ext_round": site.ext_round,
                "plane": site.plane,
            }
            if sub:
                claim["sub_row"] = sub
            claims.append(claim)
            rec = dict(claim)
            rec["zkey"] = key
            (derived_a if site.cm == "A" else derived_h).append(rec)
            idx += 1

    # the LogUp identity: ONE value-0 all-ones sum claim on H (protocol.rs::logup_sum_claim)
    if protocol_src is not None:
        logup = parse_logup_sum(protocol_src, lay)
        negated = logup["negated_planes"]
    else:
        logup = None
        negated = sorted((lay.consts["H_GU8"], lay.consts["H_GEXP"]))
    sum_parts = []
    for p in range(lay.n_h):
        sign = -1 if p in negated else 1
        re_, im_ = lay.h_off[p]
        sum_parts.append({"plane": p, "sign": sign, "re_offset": re_, "im_offset": im_,
                          "log_size": lay.h_log(p), "rows": lay.rows_of(lay.h_log(p))})
    sum_claim = {
        "index": idx, "commitment": "H", "site": "LogUp identity (all-ones sum over every H plane)",
        "slot": lay.consts["SC_ZS"], "slot_const": "SC_ZS", "site_index_in_slot": None,
        "group_key": None, "point": [], "log_size": LOG_N, "data_rows": 1, "offset": 0, "parts": 2 * lay.n_h,
        "role": "value-0 sum claim (masked by the zero-sum pair u alone)", "section": lay.slot_names[lay.consts["SC_ZS"]],
        "sum_claim": True, "source": "hashline/src/private_attention/protocol.rs::logup_sum_claim",
        "mask_rows": lay.h_u_rows(), "sum_parts": sum_parts,
        "parsed_from_protocol_rs": logup,
    }
    claims.append(sum_claim)
    derived_h.append({**sum_claim, "zkey": ((), 0, N_COLS)})
    idx += 1

    a_groups = group_sites(derived_a)
    h_groups = group_sites([c for c in derived_h if not c["sum_claim"]])
    h_groups.append({"group": len(h_groups), "key": None, "c0": 0, "len": N_COLS, "sum_group": True,
                     "members": [sum_claim["index"]]})
    for g in a_groups:
        g["m"] = len(g["members"])
    for g in h_groups:
        g["m"] = len(g["members"])
        g.setdefault("sum_group", False)

    # the two committed histograms and the two table helpers: single-row tables, no block masks
    logup_tables = [
        {"table": "U8", "table_rows": N_COLS, "required_total": lookup_total(lay)["U8"],
         "multiplicity_plane": "A_MU8", "helper_plane": "H_GU8",
         "mask_block_rows_if_hidden": 1, "mask_kind_under_FA3_rule": "pair (one row at width 256)",
         "note": "committed A row with its own claim site in slot SC_TAB; never published"},
        {"table": "exp", "table_rows": N_COLS, "required_total": lookup_total(lay)["exp"],
         "multiplicity_plane": "A_MEXP", "helper_plane": "H_GEXP",
         "mask_block_rows_if_hidden": 1, "mask_kind_under_FA3_rule": "pair (one row at width 256)",
         "note": "committed A row with its own claim site in slot SC_TAB; never published"},
    ]

    cfs_p1 = []
    kinds = {"Private": "derived-from-claims (PRIVATE under a hiding profile)", "Host": "public-zero", "Standalone": "public-zero"}
    hosted_by = {s: h for h, hs in lay.hosts for s in hs}
    for s in range(lay.n_slots):
        main, ext, deg = lay.slots[s]
        cfs_p1.append({
            "slot": lay.slot_name_of[s], "slot_index": s, "name": lay.slot_names[s],
            "main_rounds": main, "ext_rounds": ext, "n_vars": main + ext, "degree": deg,
            "cfs_len": (main + ext) * deg + 2, "claimed_sum_form": kinds[lay.slot_kinds[s]],
            "kind": lay.slot_kinds[s], "section": lay.slot_names[s],
            "claimed_sum": ("one masked scalar s + c G (hosted by " + lay.slot_name_of[hosted_by[s]] + ")")
                           if lay.slot_kinds[s] == "Private" else "public 0",
            "A_sites": lay.a_sites[s], "H_sites": lay.h_sites[s],
            "ext_rationale": "a public factor (eq / a public table) extends to 0"
                             if ext == 1 else "two private factor families: one extension round per side",
            "source": "hashline/src/private_attention/layout.rs SLOTS / SLOT_KINDS / SLOT_NAMES",
        })

    inv = {
        "task": "R-1 -- the pair-schedule rank check and the CFS slot check re-run on the NATIVE layout",
        "tool": "scripts/zk60_attention_native_inventory.py",
        "profile": {"name": "hashline-zk-mr1/private-attention-t32-poc/1",
                    "geometry": {k: lay.consts[k] for k in ("T", "D", "H", "DH", "KV", "LOG_N", "N")},
                    "privacy": "P1 (inputs / outputs / activations hidden; weights public, no W commitment)"},
        "source": {"layout.rs": "hashline/src/private_attention/layout.rs",
                   "argument.rs": "hashline/src/private_attention/argument.rs",
                   "protocol.rs": "hashline/src/private_attention/protocol.rs",
                   "pcs.rs": "zkp-core/src/pcs.rs (zpart_weights / group_zclaims: the key rule)"},
        "source_sha256": src_sha,
        "layout": {
            "cols_log": LOG_N, "n_cols": N_COLS,
            "a_rows": lay.a_rows, "a_data_rows": lay.a_data_rows, "a_mask_base": lay.a_mask_base, "a_prox": lay.a_prox,
            "h_rows": lay.h_rows, "h_data_rows": lay.h_data_rows, "h_mask_base": lay.h_mask_base, "h_prox": lay.h_prox,
            "h_u_rows": lay.h_u_rows(),
            "n_a_planes": lay.n_a, "n_h_planes": lay.n_h,
            "a_plane_offsets": {name: lay.a_off[p] for name, p in sorted(lay.a_planes.items(), key=lambda kv: kv[1])},
            "a_plane_domains": {name: lay.a_dom[p] for name, p in sorted(lay.a_planes.items(), key=lambda kv: kv[1])},
            "h_plane_offsets": {name: lay.h_off[p] for name, p in sorted(lay.h_planes.items(), key=lambda kv: kv[1])},
            "h_plane_domains": {name: lay.h_dom[p] for name, p in sorted(lay.h_planes.items(), key=lambda kv: kv[1])},
            "dom_logs": lay.dom_logs,
            "lookup_counts_per_domain": lay.lookup_counts,
            "helpers_per_domain": {d: list(v) for d, v in lay.helpers.items()},
            "planes": {name: lay.a_off[p] for name, p in sorted(lay.a_planes.items(), key=lambda kv: kv[1])},
            "a_sites_per_slot": lay.a_sites, "h_sites_per_slot": lay.h_sites,
            "A_GROUPS_declared": lay.consts["A_GROUPS"], "H_GROUPS_declared": lay.consts["H_GROUPS"],
            "M_ROWS": lay.consts["M_ROWS"], "N_FUNCTIONALS": lay.consts["N_FUNCTIONALS"],
        },
        "A1_schedule": {
            "claims": claims,
            "logup_tables": logup_tables,
            "claim_counts": {"A": len(derived_a), "H_eval": len(derived_h) - 1, "H_sum": 1,
                             "total": len(claims)},
            "opening_groups": {"A": a_groups, "H": h_groups},
            "group_counts": {"A": len(a_groups), "H": len(h_groups)},
            "endpoint_commitments": endpoints,
            "zero_sum_construction": {
                "u_plane": "H_U", "u_rows": lay.h_u_rows(),
                "fresh_pair_u_prime_rows": [lay.h_site_row(lay.consts["SC_ZS"], 0), lay.h_site_row(lay.consts["SC_ZS"], 0) + 1],
                "zsum_claim": "the SC_ZS slot's evaluation claim on H_U at rho_SC_ZS, masked by the reserved pair u'",
                "note": "the rank tool builds this pair (h_u, h_up) itself (build_model h_special); the SC_ZS H site "
                        "is therefore NOT emitted in the tool view of the claim list -- see adaptation R-4",
            },
        },
        "A2_cfs_slots": {
            "P1": cfs_p1,
            "P3": None,
            "hosts": {lay.slot_name_of[h]: [lay.slot_name_of[x] for x in hs] for h, hs in lay.hosts},
            "transcript_order": [lay.slot_name_of[s] for s in range(lay.n_slots)],
            "m_rows": lay.consts["M_ROWS"], "n_functionals": lay.consts["N_FUNCTIONALS"],
            "note": "P3 is not implemented by this module (weights are public and uncommitted under P1)",
        },
    }
    return inv


def lookup_total(lay: Layout) -> Dict[str, int]:
    """Total U8 lookups (sum over domains of count * |domain|) and exp lookups (the S domain)."""
    u8 = 0
    for dom in lay.lookup_doms:
        u8 += lay.lookup_counts[dom] * (1 << lay.dom_logs[dom])
    return {"U8": u8, "exp": 1 << lay.dom_logs["S"]}


# ---------------------------------------------------------------------------
# 5. cross-checks against the delivery note
# ---------------------------------------------------------------------------

NOTE_EXPECT = {
    "A_rows": 306, "A_data_rows": 154, "A_site_pair_rows": 150, "A_prox_rows": 2,
    "H_rows": 290, "H_data_rows": 218, "H_site_pair_rows": 70, "H_prox_rows": 2,
    "A_sites": 75, "H_sites": 35, "A_GROUPS": 30, "H_GROUPS": 8,
    "M_ROWS": 40, "N_FUNCTIONALS": 28, "largest_L": 50,
    "U8_lookups": 47104, "exp_lookups": 2048,
    "main_rounds_total": 129, "ext_rounds_total": 20,
    "slots": [(9, 1, 3), (5, 1, 3), (9, 1, 3), (11, 1, 3), (4, 1, 2), (4, 1, 2), (4, 1, 2), (3, 2, 2),
              (5, 2, 2), (4, 1, 2), (9, 1, 4), (9, 1, 4), (8, 1, 4), (11, 1, 4), (8, 1, 3), (8, 1, 2),
              (9, 1, 2), (9, 1, 2)],
    "hosts_by_index": {1: [0], 10: [9], 11: [4, 8], 12: [5, 6], 13: [3, 7]},
}


def cross_checks(lay: Layout, inv: dict) -> List[dict]:
    out: List[dict] = []

    def chk(name: str, got, want, detail: str = "") -> None:
        out.append({"name": name, "got": got, "note_says": want, "pass": got == want, "detail": detail})

    n_a_sites = sum(lay.a_sites)
    n_h_sites = sum(lay.h_sites)
    chk("A rows (layout arithmetic vs note section 5)", lay.a_rows, NOTE_EXPECT["A_rows"])
    chk("A data rows", lay.a_data_rows, NOTE_EXPECT["A_data_rows"])
    chk("A site-pair rows", 2 * n_a_sites, NOTE_EXPECT["A_site_pair_rows"])
    chk("H rows", lay.h_rows, NOTE_EXPECT["H_rows"])
    chk("H data rows (incl. u)", lay.h_data_rows, NOTE_EXPECT["H_data_rows"])
    chk("H site-pair rows (incl. u')", 2 * n_h_sites, NOTE_EXPECT["H_site_pair_rows"])
    chk("A claim sites", n_a_sites, NOTE_EXPECT["A_sites"])
    chk("H claim sites", n_h_sites, NOTE_EXPECT["H_sites"])
    chk("A claim sites found in argument.rs::define", inv["A1_schedule"]["claim_counts"]["A"], NOTE_EXPECT["A_sites"])
    chk("H claim sites found in argument.rs::define", inv["A1_schedule"]["claim_counts"]["H_eval"], NOTE_EXPECT["H_sites"])
    chk("A opening groups (derived from the PCS key rule)", inv["A1_schedule"]["group_counts"]["A"], NOTE_EXPECT["A_GROUPS"],
        "layout.rs A_GROUPS is a hand count; this is the derivation")
    chk("H opening groups (derived, incl. the sum group)", inv["A1_schedule"]["group_counts"]["H"], NOTE_EXPECT["H_GROUPS"])
    chk("A_GROUPS declared in layout.rs", lay.consts["A_GROUPS"], NOTE_EXPECT["A_GROUPS"])
    chk("H_GROUPS declared in layout.rs", lay.consts["H_GROUPS"], NOTE_EXPECT["H_GROUPS"])
    chk("M rows", lay.consts["M_ROWS"], NOTE_EXPECT["M_ROWS"])
    chk("M rows = 2 * slots + 4", 2 * lay.n_slots + 4, NOTE_EXPECT["M_ROWS"])
    n_standalone = sum(1 for k in lay.slot_kinds if k == "Standalone")
    chk("functionals = slots + standalone Gammas + one batched Gamma per host",
        lay.n_slots + n_standalone + len(lay.hosts), NOTE_EXPECT["N_FUNCTIONALS"])
    chk("N_FUNCTIONALS declared", lay.consts["N_FUNCTIONALS"], NOTE_EXPECT["N_FUNCTIONALS"])
    chk("the 18 (main, ext, degree) triples", [tuple(x) for x in lay.slots], NOTE_EXPECT["slots"])
    lens = [(m + e) * d + 2 for (m, e, d) in lay.slots]
    chk("largest mask row L", max(lens), NOTE_EXPECT["largest_L"])
    chk("total main rounds", sum(m for m, _, _ in lay.slots), NOTE_EXPECT["main_rounds_total"])
    chk("total extension rounds", sum(e for _, e, _ in lay.slots), NOTE_EXPECT["ext_rounds_total"])
    tot = lookup_total(lay)
    chk("U8 lookups", tot["U8"], NOTE_EXPECT["U8_lookups"])
    chk("exp lookups", tot["exp"], NOTE_EXPECT["exp_lookups"])
    chk("hosts (module slot indices)", {h: list(hs) for h, hs in lay.hosts}, NOTE_EXPECT["hosts_by_index"])
    chk("every slot L_s + 256 <= 512", all(L + 256 <= 512 for L in lens), True)
    chk("helper planes cover the lookups pairwise",
        {d: (lay.lookup_counts[d] + 1) // 2 for d in lay.lookup_doms},
        {d: lay.helpers[d][1] for d in lay.lookup_doms})
    # the reserved pairs the parse produced must be exactly layout.rs's a_site / h_site ranges
    a_rows = sorted(c["mask_rows"][0] for c in inv["A1_schedule"]["claims"] if c["commitment"] == "A")
    h_rows = sorted(c["mask_rows"][0] for c in inv["A1_schedule"]["claims"] if c["commitment"] == "H" and not c["sum_claim"])
    chk("A reserved-pair first rows == layout.rs a_site(slot, k)",
        a_rows, list(range(lay.a_mask_base, lay.a_prox, 2)))
    chk("H reserved-pair first rows == layout.rs h_site(slot, k)",
        h_rows, list(range(lay.h_mask_base, lay.h_prox, 2)))
    return out


# ---------------------------------------------------------------------------
# 6. adapters: run the two tools (imported by path, never edited)
# ---------------------------------------------------------------------------


def load_tool(path: str, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def tool_view_inventory(inv: dict, lay: Layout) -> dict:
    """The rank tool's view: the SC_ZS H site removed (the tool builds the zsum claim and its
    fresh pair itself), claims re-indexed, the legacy `opening_groups_*` / `claim_counts_*` keys
    filled in from the derivation."""
    zs = lay.consts["SC_ZS"]
    claims = [dict(c) for c in inv["A1_schedule"]["claims"]
              if not (c["commitment"] == "H" and c["slot"] == zs and not c["sum_claim"])]
    for i, c in enumerate(claims):
        c["index"] = i
    view = {"A1_schedule": {"claims": claims,
                            "logup_tables": [],
                            "claim_counts_block_profile": {}, "claim_counts_receipt_profile": {},
                            "opening_groups_block_profile": {}, "opening_groups_receipt_profile": {}},
            "layout": inv["layout"], "A2_cfs_slots": inv["A2_cfs_slots"]}
    return view


def run_rank_tool(inv: dict, lay: Layout, scripts_dir: str, seed: int, n_values: int = 4) -> Tuple[dict, dict, List[str]]:
    """The pair-schedule tool on this layout.  Returns (results, schedule, failures)."""
    PS = load_tool(os.path.join(scripts_dir, "zk60_attention_pair_schedule.py"), "zk60_attention_pair_schedule")
    FA2 = PS.FA2
    view = tool_view_inventory(inv, lay)
    n_a = sum(1 for c in view["A1_schedule"]["claims"] if c["commitment"] == "A")
    n_all = len(view["A1_schedule"]["claims"])

    # --- the adapter: rebind module-level constants, never the file ---------
    PS.EXPECTED_CLAIMS = {"block": n_all, "receipt": n_all}
    PS.ROWS_TODAY = {"A": lay.a_data_rows, "H": lay.h_data_rows - 2, "W": 0}
    PS.BILINEAR_SECTIONS = (lay.slot_names[lay.consts["SC_SCORE"]], lay.slot_names[lay.consts["SC_PV"]])
    PS.WEIGHT_MATMUL_SECTIONS = tuple(lay.slot_names[s] for s in
                                      (lay.consts["SC_QMM"], lay.consts["SC_KMM"], lay.consts["SC_VMM"], lay.consts["SC_WO"]))
    PS.with_added = lambda claims, force_singletons=False: [dict(c) for c in claims]
    PS.tables_from_inventory = lambda inv_: []

    sched = PS.build_schedule(view, "block", endpoints="pair")
    _renumber_h(sched, lay)
    cov = PS.schedule_coverage_checks(sched)
    cost = PS.row_cost(sched)

    results: Dict[str, dict] = {}
    failures: List[str] = []

    def record(key: str, res: dict, expect: Optional[int], argument: str, **extra) -> dict:
        v = PS.verdict(res, expect, argument, **extra)
        results[key] = v
        if v["verdict"] == "FAIL":
            failures.append(key)
        return v

    # ---- (1) every A group alone (vector + values + prox pair) -------------
    for g in PS.a_model_groups(sched, include_tab=False):
        model, _ = PS.build_model(f"A {g['name']} alone", [g], n_values, PS.seed_for(seed, f"A-{g['name']}"), True)
        res = PS.analyze_fast(model)
        v = record(f"group_A_{g['name']}", res, 0,
                   f"all-pair group of m = {len(g['members'])} + prox pair (FA2 14.3)",
                   members=[m["name"] for m in g["members"]])
        if all(m["kind"] == "pair" for m in g["members"]):
            m_ = len(g["members"])
            v["rank_mask_formula_2m+2n-2+2n"] = res["rank_mask"] == 2 * m_ + 2 * n_values - 2 + 2 * n_values

    hg, helpers, tables = _h_groups(PS, sched, lay)
    for g in hg:
        model, _ = PS.build_model(f"H {g['name']} alone", [g], n_values, PS.seed_for(seed, f"H-{g['name']}"), True)
        record(f"group_H_{g['name']}", PS.analyze_fast(model), 0,
               "Fp2 helper planes with Fp2 mask pairs (FA2 14.3, H rows)",
               members=[m["name"] for m in g["members"]])

    # ---- (2) the whole commitments per column -----------------------------
    groups = PS.a_model_groups(sched, include_tab=False)
    model, ex = PS.build_model("whole A per column", groups, 1, PS.seed_for(seed, "A-col"), False)
    res = PS.analyze_fast(model)
    v = record("whole_A_per_column", res, 0,
               f"{len(groups)} groups + prox pair, every site its own reserved pair: joint rank full per column",
               groups=len(groups), rows_modelled=len(ex["rows"]))
    v["sparse_engine_equals_FA2_analyze"] = PS.engines_agree(model)["agree"]
    fa2m = FA2.per_column_commitment("FA2 whole A", PS.fa2_groups(groups), seed=PS.seed_for(seed, "A-fa2") % (2 ** 31), prox_pair=True)
    fres = FA2.analyze(fa2m)
    v["FA2_per_column_commitment_disclosed_dim"] = fres["disclosed_dim"]
    v["FA2_builder_agrees"] = fres["disclosed_dim"] == res["disclosed_dim"] == 0 and fres["rank_mask"] == res["rank_mask"]

    model, ex = PS.build_model("whole H per column", hg, 1, PS.seed_for(seed, "H-col"), False,
                               h_special={"helpers": helpers, "tables": tables, "u": True})
    res = PS.analyze_fast(model)
    v = record("whole_H_per_column", res, 0,
               "the helper groups + the TAB helpers + zsum (u masked by u') + the LogUp sum vector "
               "(u free per column; its zero sum is a cross-column constraint) + prox pair",
               groups=len(hg), rows_modelled=len(ex["rows"]))
    v["sparse_engine_equals_FA2_analyze"] = PS.engines_agree(model)["agree"]

    # ---- (3) the whole commitments with values ----------------------------
    groups = PS.a_model_groups(sched, include_tab=False)
    model, ex = PS.build_model(f"whole A with values n{n_values}", groups, n_values, PS.seed_for(seed, "A-val"), True)
    res = PS.analyze_fast(model)
    v = record(f"whole_A_with_values_n{n_values}", res, 0,
               "every group vector, every terminal value and the prox vector jointly",
               groups=len(groups), rows_modelled=len(ex["rows"]),
               trivial_identities=res["observation_functionals_killing_masks_but_not_data"])
    fa2m = FA2.commitment_with_values(f"FA2 whole A values", PS.fa2_groups(groups), n_values,
                                      seed=PS.seed_for(seed, "A-fa2val") % (2 ** 31), prox_pair=True)
    fres = PS.analyze_fast(fa2m)
    v["FA2_commitment_with_values_disclosed_dim"] = fres["disclosed_dim"]
    v["FA2_builder_agrees"] = fres["disclosed_dim"] == res["disclosed_dim"] == 0 and fres["rank_mask"] == res["rank_mask"]

    for n in sorted({n_values, 8}):
        hgn, helpn, tabn = _h_groups(PS, sched, lay)
        model, ex = PS.build_model(f"whole H with values n{n}", hgn, n, PS.seed_for(seed, f"H-val-{n}"), True,
                                   h_special={"helpers": helpn, "tables": tabn, "u": True})
        res = PS.analyze_fast(model)
        ic = PS.identity_check(res, model, ex["identity_rows"])
        v = PS.verdict(res, 2, "the ONE zero-sum construction over every helper column and the two g_T rows: "
                               "the two surviving base functionals span exactly the public LogUp identity", **ic)
        v["verdict"] = "PASS" if res["disclosed_dim"] == 2 and ic["residual_is_exactly_the_public_identity"] else "FAIL"
        results[f"whole_H_with_values_n{n}"] = v
        if v["verdict"] == "FAIL":
            failures.append(f"whole_H_with_values_n{n}")
        if n <= 4:
            v["sparse_engine_equals_FA2_analyze"] = PS.engines_agree(model)["agree"]

    # ---- (4) the two endpoint commitments ---------------------------------
    for ep in inv["A1_schedule"]["endpoint_commitments"]:
        cm = ep["commitment"]
        g = {"name": f"ep{cm}", "e_kind": "p1", "members": [
            {"name": f"endpoint {cm}", "kind": "pair", "data": [f"EP{cm}/r0", f"EP{cm}/r1"],
             "row_bits": [ep["point"][0]], "mask": [f"EP{cm}/m2", f"EP{cm}/m3"]}]}
        model, _ = PS.build_model(f"endpoint {cm}", [g], n_values, PS.seed_for(seed, f"EP-{cm}"), True)
        record(f"endpoint_{cm}_with_values_n{n_values}", PS.analyze_fast(model), 0,
               "one claim on a 2-row endpoint plane with its own pair (rows 2, 3) + a proximity pair "
               "(the real geometry has THREE proximity rows 4-6; modelling two is conservative)")

    # ---- (5) negative controls --------------------------------------------
    nc: Dict[str, dict] = {}

    def neg(key: str, res: dict, ok: bool, argument: str, **extra) -> None:
        v = {**PS.summ(res), "argument": argument, "verdict": "PASS" if ok else "FAIL", **extra}
        nc[key] = v
        if not ok:
            failures.append(f"negative/{key}")

    model, _ = PS.build_model("A per column, no masks at all", PS.a_model_groups(sched, kind_for=lambda s: "none", include_tab=False),
                              1, PS.seed_for(seed, "nc-nomask-A"), False, prox="none")
    res = PS.analyze_fast(model)
    neg("no_mask_A_per_column", res, res["disclosed_dim"] >= 30,
        "P0: every group vector entry is a public data functional", expected_at_least=30)

    model, _ = PS.build_model(f"A with values, no masks", PS.a_model_groups(sched, kind_for=lambda s: "none", include_tab=False),
                              n_values, PS.seed_for(seed, "nc-nomask-Aval"), True, prox="none")
    res = PS.analyze_fast(model)
    neg(f"no_mask_A_with_values_n{n_values}", res, res["disclosed_dim"] >= 2 * n_a,
        "P0 with the terminal values: large disclosure", expected_at_least=2 * n_a)

    model, _ = PS.build_model("A per column, one base mask row per claim", PS.a_model_groups(sched, kind_for=lambda s: "base1", include_tab=False),
                              1, PS.seed_for(seed, "nc-base1-A"), False, prox="pair")
    res = PS.analyze_fast(model)
    tool_exp = PS.singleton_leak_expectation(sched)
    exp = native_singleton_expectation(sched)
    neg("single_base_row_per_claim_A_per_column", res, res["disclosed_dim"] == exp["expected_disclosed_dim"],
        "FA2 14.1: each singleton group leaks one base functional per column under a single base mask "
        "row; two singletons opening the SAME multi-row plane at the same SYMBOLIC row bit leak "
        "independent base functionals (the surviving functional is Im(c) Re(a eq) - Re(c) Im(a eq), not "
        "a base multiple of eq), so a block of R rows saturates at R",
        expectation=exp, tool_singleton_leak_expectation=tool_exp,
        tools_helper_undercount=exp["expected_disclosed_dim"] - tool_exp["distinct_functionals"])

    singles = [g["group"] for g in sched["groups"]["A"] if g["singleton"]]
    if singles:
        g1 = singles[0]
        model, _ = PS.build_model("one pair claim + single prox row", PS.a_model_groups(sched, only_groups=[g1], include_tab=False),
                                  1, PS.seed_for(seed, "nc-prox1"), False, prox="single")
        res = PS.analyze_fast(model)
        neg("single_prox_row_singleton_pair_claim_per_column", res, res["disclosed_dim"] == 1,
            "FA3 9 / FA2 14.4: 3 mask unknowns against 4 base dims: the single prox row leaks one functional", group=g1)
        model, _ = PS.build_model("one pair claim + prox pair", PS.a_model_groups(sched, only_groups=[g1], include_tab=False),
                                  1, PS.seed_for(seed, "nc-prox2"), False, prox="pair")
        res = PS.analyze_fast(model)
        neg("prox_pair_singleton_pair_claim_per_column", res, res["disclosed_dim"] == 0,
            "4 against 4: the prox pair covers the prox vector by itself", group=g1)

    # the flipped RoPE claims (slots SC_QZC / SC_KVZC) sharing the unflipped pair
    for slot_const in ("SC_QZC", "SC_KVZC"):
        slot = lay.consts[slot_const]
        flipped = next((s for s in sched["commitments"]["A"]["sites"]
                        if any(x.startswith("1-") for x in (s["group_key"] or []))and s["section"] == lay.slot_names[slot]), None)
        if flipped is None:
            continue
        base = next(s for s in sched["commitments"]["A"]["sites"]
                    if s["section"] == lay.slot_names[slot] and s["group"] != flipped["group"])
        gs = [base["group"], flipped["group"]]
        model, _ = PS.build_model(f"{slot_const}: flipped claim re-uses the unflipped pair",
                                  PS.a_model_groups(sched, only_groups=gs, include_tab=False,
                                                    share_mask={flipped["role"]: base["role"]}),
                                  n_values, PS.seed_for(seed, f"nc-rope-{slot_const}"), True)
        res = PS.analyze_fast(model)
        neg(f"flipped_rope_{slot_const}_sharing_pair_with_values_n{n_values}", res, res["disclosed_dim"] >= 2,
            "FA3 2.3 item 6: a flipped-point claim needs its OWN reserved pair", groups=gs, expected_at_least=2)
        model, _ = PS.build_model(f"{slot_const}: flipped claim with its own pair",
                                  PS.a_model_groups(sched, only_groups=gs, include_tab=False),
                                  n_values, PS.seed_for(seed, f"nc-rope2-{slot_const}"), True)
        res = PS.analyze_fast(model)
        neg(f"flipped_rope_{slot_const}_own_pair_with_values_n{n_values}", res, res["disclosed_dim"] == 0,
            "own pair: covered", groups=gs)

    hgn, helpn, tabn = _h_groups(PS, sched, lay)
    model, ex = PS.build_model("H: u zero-sum pair but no fresh pair u'", hgn, n_values, PS.seed_for(seed, "nc-nofresh"), True,
                               h_special={"helpers": helpn, "tables": tabn, "u": True, "zsum_fresh_pair": False})
    res = PS.analyze_fast(model)
    neg(f"zero_sum_row_without_fresh_pair_n{n_values}", res, res["disclosed_dim"] > 2,
        "the zsum claim exposes u at rho_zs unmasked; the LogUp sum vector then discloses helper data "
        "beyond the identity", expected_more_than=2)

    hgn, helpn, tabn = _h_groups(PS, sched, lay)
    model, ex = PS.build_model("H: helper sums published individually (no u)", hgn, n_values, PS.seed_for(seed, "nc-sums"), True,
                               h_special={"helpers": helpn, "public_sums": True})
    res = PS.analyze_fast(model)
    S = ex["sum_rows"]
    rs = PS.rank_of(S, model.data)
    rfs = PS.rank_of(list(res["surviving_data_functionals"]) + S, model.data)
    neg(f"helper_sums_published_n{n_values}", res,
        rs == 2 * len(helpn) and rfs == res["disclosed_dim"] and res["disclosed_dim"] >= 2 * len(helpn),
        f"the {len(helpn)} helper sums published individually are {2 * len(helpn)} public base functionals "
        "of the helper columns, all surviving (the construction this layout does NOT use)",
        rank_of_the_sums=rs, rank_F=res["disclosed_dim"], rank_F_union_sums=rfs)

    results["negative_controls"] = nc
    out = {
        "tool": "scripts/zk60_attention_pair_schedule.py",
        "tool_sha256": sha256_file(os.path.join(scripts_dir, "zk60_attention_pair_schedule.py")),
        "fa2_engine_sha256": sha256_file(os.path.join(scripts_dir, "zk60_fable_joint_rank.py")),
        "seed": seed, "n_values": n_values,
        "schedule_coverage_checks": cov, "row_cost": cost,
        "group_counts": {cm: len(sched["groups"][cm]) for cm in ("A", "H")},
        "singleton_groups": {cm: sum(1 for g in sched["groups"][cm] if g["singleton"]) for cm in ("A", "H")},
        "rank_verdicts": results, "failures": failures,
        "assumptions": PS.ASSUMPTIONS,
        "adaptations": ADAPTATIONS["rank"],
    }
    if not cov["all_pass"]:
        failures.append("schedule_coverage_checks")
    schedule_out = {
        "A": {"regions": sched["commitments"]["A"]["regions"], "rows_total": sched["commitments"]["A"]["rows_total"],
              "sites": [PS.site_row(s) for s in sched["commitments"]["A"]["sites"]],
              "prox": sched["commitments"]["A"]["prox"],
              "groups": [{"group": g["group"], "key": g["key"], "m": g["m"], "sites": g["sites"],
                          "data_rows": g["data_rows"], "singleton": g["singleton"]} for g in sched["groups"]["A"]]},
        "H": {"regions": sched["commitments"]["H"]["regions"], "rows_total": sched["commitments"]["H"]["rows_total"],
              "sites": [PS.site_row(s) for s in sched["commitments"]["H"]["sites"]],
              "h_u": sched["commitments"]["H"]["h_u"], "h_up": sched["commitments"]["H"]["h_up"],
              "prox": sched["commitments"]["H"]["prox"],
              "replaced_sum_claims": sched["commitments"]["H"]["replaced_sum_claims"],
              "groups": [{"group": g["group"], "key": g["key"], "m": g["m"], "sites": g["sites"],
                          "sum_group": g["sum_group"]} for g in sched["groups"]["H"]]},
        "row_cost": cost,
        "note": "row indices are this layout's (layout.rs Layout::new); the H region was renumbered onto "
                "layout.rs's rows after the tool built it (adaptation R-5)",
    }
    return out, schedule_out, failures


def native_singleton_expectation(sched: dict) -> dict:
    """The disclosed dimension of the `one base mask row per claim` control on THIS layout.

    Under a single base mask row, a singleton group leaks exactly one BASE functional per column.
    If its row bits are constants it selects one row, and the functional is that row's unit
    vector: repeats coincide.  If its row bits are symbolic the functional is
    `Im(c) Re(a eq) - Re(c) Im(a eq)` over the plane's R rows -- generic in that R-dimensional
    space and independent of another singleton's on the same rows, so k singletons on one R-row
    block span min(k, R) dimensions (the tool's own `singleton_leak_expectation` collapses them
    to one, which is right only for constant row bits: finding F-1)."""
    sites = {s["claim_index"]: s for s in sched["commitments"]["A"]["sites"]}
    blocks: Dict[Tuple[int, ...], int] = {}
    consts: set = set()
    detail = []
    for g in sched["groups"]["A"]:
        if not g["singleton"]:
            continue
        s = sites[g["members"][0]]
        r0, r1 = s["data_row_range"]
        bits = s["row_bits"]
        if all(b in ("0", "1") for b in bits):
            sel = r0 + int("".join(bits) or "0", 2)
            consts.add(sel)
            detail.append({"group": g["group"], "site": s["site"], "kind": "constant row bits", "row": sel})
        else:
            key = tuple(range(r0, r1))
            blocks[key] = blocks.get(key, 0) + 1
            detail.append({"group": g["group"], "site": s["site"], "kind": "symbolic row bits", "rows": list(key)})
    dim, handled = 0, set()
    per_block = []
    for block, k in blocks.items():
        c = len(set(block) & consts)
        d = c + min(k, len(block) - c)
        per_block.append({"rows": list(block), "symbolic_singletons": k, "constant_rows": c, "dim": d})
        dim += d
        handled |= set(block)
    loose = sorted(consts - handled)
    dim += len(loose)
    return {"expected_disclosed_dim": dim, "per_block": per_block,
            "constant_only_rows": loose, "singleton_groups": len(detail), "singletons": detail}


def _renumber_h(sched: dict, lay: Layout) -> None:
    """The tool lays H out as [data | site pairs | u | u' | prox]; layout.rs lays it out as
    [data | u | site pairs | ... | u' | prox].  Rewrite the H row indices onto layout.rs's rows
    (a bijective relabelling: the rank model uses row NAMES, not positions)."""
    H = sched["commitments"]["H"]
    for i, s in enumerate(H["sites"]):
        s["mask_rows"] = [lay.h_mask_base + 2 * i, lay.h_mask_base + 2 * i + 1]
    H["h_u"]["mask_rows"] = lay.h_u_rows()
    zs = lay.consts["SC_ZS"]
    up = lay.h_site_row(zs, 0)
    H["h_up"]["mask_rows"] = [up, up + 1]
    H["prox"]["mask_rows"] = [lay.h_prox, lay.h_prox + 1]
    H["regions"] = {"data": [0, lay.h_data_rows], "u_zero_sum_pair": lay.h_u_rows(),
                    "helper_pairs": [lay.h_mask_base, lay.h_mask_base + 2 * len(H["sites"])],
                    "u_prime_pair": [up, up + 1], "prox_pair": [lay.h_prox, lay.h_prox + 1]}
    H["rows_total"] = lay.h_rows


def _h_groups(PS, sched: dict, lay: Layout):
    """h_model_groups + the sign split the LogUp identity needs: the two table helpers
    (H_GU8, H_GEXP) carry -1 in `logup_sum_claim`, so they must be the tool's `tables`."""
    hg, helpers, tables = PS.h_model_groups(sched, include_tab=False)
    tab_names = []
    for s in sched["commitments"]["H"]["sites"]:
        if s["section"] == lay.slot_names[lay.consts["SC_TAB"]]:
            tab_names.append(s["role"])
    tabs = [m for m in helpers if m["name"] in tab_names]
    helps = [m for m in helpers if m["name"] not in tab_names]
    return hg, helps, tabs


def run_cfs_tool(inv: dict, lay: Layout, scripts_dir: str, out_dir: str, seed: int) -> Tuple[dict, List[str]]:
    CF = load_tool(os.path.join(scripts_dir, "zk60_attention_cfs_slots.py"), "zk60_attention_cfs_slots")
    names = [lay.slot_name_of[s] for s in range(lay.n_slots)]
    hosts = {"variant": "layout.rs HOSTS",
             "note": "layout.rs `HOSTS`: every private slot hosted exactly once by a public-zero "
                     "zero-check that runs after it",
             "hosts": {lay.slot_name_of[h]: [lay.slot_name_of[x] for x in hs] for h, hs in lay.hosts},
             "extra_slots": {}}

    # --- the adapter: rebind module-level constants, never the file ---------
    CF.OPUS_TWELVE = names
    CF.SPLIT = {}
    CF.ADDED_SLOTS = []
    CF.TRANSCRIPT_ORDER = names
    CF.TWO_EXT = {n: (lay.slots[s][0] + lay.slots[s][1], lay.slots[s][2], lay.slots[s][1])
                  for s, n in enumerate(names) if lay.slots[s][1] >= 2}
    CF.DEFAULT_HOSTS = hosts
    qmm = lay.consts["SC_QMM"]
    CF.SPLIT_SHAPE = {"P1": (lay.slots[qmm][0] + lay.slots[qmm][1], lay.slots[qmm][2], lay.slots[qmm][1])}

    table = CF.build_slot_table(inv, "P1", hosts)
    rng = CF.Rng(seed)
    standalone = CF.standalone_report(table, rng)
    hg = CF.host_groups_report(table, hosts, rng)
    mlay = CF.m_layout(table, hosts)
    big = CF.largest_slot(table)
    r7 = CF.r7_extension_check(rng)

    # the QKV-unsplit control: its four slot names are hard-coded, so it is run on a
    # name-mapped COPY of this layout's table (adaptation C-3)
    alias = {lay.slot_name_of[lay.consts["SC_QZC"]]: "SC_ATTN_03",
             lay.slot_name_of[lay.consts["SC_KVZC"]]: "SC_ATTN_04",
             lay.slot_name_of[lay.consts["SC_QMM"]]: "SC_ATTN_08Q",
             lay.slot_name_of[lay.consts["SC_KMM"]]: "SC_ATTN_08K",
             lay.slot_name_of[lay.consts["SC_VMM"]]: "SC_ATTN_08V"}
    alias_table = [{**r, "slot": alias.get(r["slot"], r["slot"])} for r in table]
    orig_unsplit = CF.unsplit_qkv_models
    CF.unsplit_qkv_models = lambda t, mode, rng_: orig_unsplit(alias_table, mode, rng_)
    nc = CF.negative_controls(table, hosts, "P1", rng)
    CF.unsplit_qkv_models = orig_unsplit

    checks: List[dict] = []

    def chk(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "pass": bool(ok), "detail": detail})

    chk(f"{lay.n_slots} slots in layout.rs transcript order", [r["slot"] for r in table] == names, str(names))
    chk(f"every slot L_s + {CF.MASK_Q} <= {CF.MASK_M}; largest {big['slot']} L = {big['len']}",
        all(r["len"] + CF.MASK_Q <= CF.MASK_M for r in table))
    chk(f"FA6's criterion standalone on all {len(standalone)} slots (rank = dim S = N d + 1, image in S, leaked 0, kernel 1)",
        all(v["pass"] for v in standalone.values()),
        ", ".join(f"{k}:{v['rank_map']}/{v['dim_consistency_subspace']}" for k, v in standalone.items()))
    for host, g in hg["groups"].items():
        chk(f"host {host} <- {g['hosted']}: rank = dim S = sum L - (k+1) = {g['expected_dim_S_sum_L_minus_k_plus_1']}, "
            f"kernel {g['k'] + 1}, leaked 0, relabelling, f-part", g["pass"],
            f"rank {g['rank_map']} dim S {g['dim_consistency_subspace']} kernel {g['kernel_dim_fp2']} leaked {g['leaked_dim_fp2']}")
        chk(f"host {host}'s hosted slots all precede it in transcript order",
            not g["hosted_after_host_in_transcript"], str(g["hosted_after_host_in_transcript"]))
    for s, g in hg["public_standalone"].items():
        chk(f"public standalone {s}: rank = dim S, leaked 0, kernel 1", g["pass"])
    chk(f"M layout {mlay['n_rows']} rows = 2 * {len(table)} + 4, every row fits",
        mlay["n_rows"] == 2 * len(table) + 4 and mlay["every_row_fits"])
    chk(f"M rows match layout.rs M_ROWS = {lay.consts['M_ROWS']}", mlay["n_rows"] == lay.consts["M_ROWS"])
    chk(f"functionals match layout.rs N_FUNCTIONALS = {lay.consts['N_FUNCTIONALS']}",
        mlay["n_functionals"] == lay.consts["N_FUNCTIONALS"], str(mlay["n_functionals"]))
    evals = [f for f in mlay["mask_functionals"] if f["kind"] == "eval"]
    gb = [f for f in mlay["mask_functionals"] if f["kind"] == "gamma_batched"]
    gs = [f for f in mlay["mask_functionals"] if f["kind"] == "gamma"]
    privates = [r["slot"] for r in table if r["private"]]
    chk(f"one eval per slot ({len(evals)}), one batched Gamma per host ({len(gb)}), {len(gs)} standalone Gamma, "
        "every private slot in exactly one batched Gamma, no standalone Sigma for private/host slots",
        len(evals) == len(table) and len(gb) == len(hosts["hosts"])
        and all(sum(1 for f in gb if s in f["slots"][1:]) == 1 for s in privates)
        and all(f["slots"][0] not in privates and f["slots"][0] not in hosts["hosts"] for f in gs)
        and len(gs) == len(table) - len(privates) - len(hosts["hosts"]))
    chk("R7: one private family vanishes on the mask branch with a public factor extending to 0; two private "
        "families with the public factor == 1 do not in one round and do in two", r7["pass"])
    for k, v in nc.items():
        if isinstance(v, dict) and "pass" in v:
            chk(f"negative control {k}: {v.get('expect', '')}", v["pass"])

    report = {
        "tool": "scripts/zk60_attention_cfs_slots.py",
        "tool_sha256": sha256_file(os.path.join(scripts_dir, "zk60_attention_cfs_slots.py")),
        "cfs_channel_sha256": sha256_file(os.path.join(scripts_dir, "zk60_fable_cfs_channel.py")),
        "seed": seed, "constants": {"MASK_Q": CF.MASK_Q, "MASK_M": CF.MASK_M},
        "slot_table": table, "standalone": standalone, "host_groups": hg["groups"],
        "public_standalone": hg["public_standalone"], "m_layout": mlay, "largest_slot": big,
        "r7_extension_check": r7, "negative_controls": nc,
        "checks": checks, "n_checks": len(checks), "all_checks_pass": all(c["pass"] for c in checks),
        "mode": "P1 only (this module does not implement P3: weights are public and uncommitted)",
        "adaptations": ADAPTATIONS["cfs"],
    }
    failures = [c["name"] for c in checks if not c["pass"]]
    return report, failures


ADAPTATIONS = {
    "rank": [
        "R-1  `EXPECTED_CLAIMS` rebound from the legacy {block: 133, receipt: 135} to this layout's claim "
        "count; `load_inventory` is not called (its only job is that assertion plus index continuity, which "
        "this script guarantees by construction).",
        "R-2  `ROWS_TODAY` rebound to {A: a_data_rows, H: h_data_rows - 2, W: 0}: this layout commits its "
        "histograms and table helpers as ordinary planes inside the data rows, and its zero-sum row u is the "
        "last H data plane, which the tool models as the `h_u` mask pair.  With these values the tool's row "
        "arithmetic reproduces A = 306 and H = 290 exactly.",
        "R-3  `tables_from_inventory` rebound to return [] and `with_added` to the identity: the ten legacy "
        "range tables with block masks and the twelve added rho_2 sub-row sites do not exist here (one U8 "
        "table plus one exp table, each ONE row, each an ordinary claim site with its own reserved pair).",
        "R-4  the SC_ZS slot's H site (the u' pair on the u plane) is not emitted in the tool's view of the "
        "claim list, because the tool builds that claim itself (`Builder.add_zsum` with the fresh pair u'). "
        "The inventory record keeps it; the derived group counts (A 30 / H 8) include it.",
        "R-5  the H row indices the tool assigns are renumbered onto layout.rs's rows afterwards "
        "([data | u | site pairs | u' | prox] instead of [data | site pairs | u | u' | prox]).  A bijective "
        "relabelling: the rank model keys on row NAMES.",
        "R-6  `BILINEAR_SECTIONS` / `WEIGHT_MATMUL_SECTIONS` rebound to this layout's slot names so the "
        "score / PV terminals get the two-extension-round coefficient form.",
        "R-7  `run_all` / `run_positive` / `run_negative` / `cross_check_groups` are NOT called: their "
        "expectations are hard-coded to the legacy inventory (a W commitment, one 19-member H sum group, an "
        "A seam group at index 38, the sm/lm sub-block alternative, 10 histogram tables).  The battery this "
        "script runs uses the same imported model functions (Builder / build_model / a_model_groups / "
        "h_model_groups / analyze_fast / engines_agree / fa2_groups / identity_check / verdict) with this "
        "layout's own expectations.",
        "R-8  sub-row claim sites (the 32-entry T-domain and 64-entry Ht-domain slices: 14 A sites) are "
        "presented as single-row claims with a synthetic 8-symbol tail that preserves PCS key equality "
        "((point, c0, len)).  The tool's row model has no sub-row granularity; the true window is recorded "
        "in each claim's `sub_row` field.  The approximation is confined to the terminal's column weights, "
        "which the with-values models draw at random in any case.",
        "R-9  the two endpoint commitments are modelled separately (one claim, its own pair at rows 2-3, a "
        "proximity pair).  The real endpoint geometry has THREE proximity rows (4-6) of seven; modelling two "
        "is conservative (fewer mask rows can only disclose more).",
    ],
    "cfs": [
        "C-1  `OPUS_TWELVE` / `TRANSCRIPT_ORDER` rebound to this layout's eighteen slot constants in "
        "layout.rs order; `SPLIT` and `ADDED_SLOTS` emptied (this layout already has three separate matmul "
        "slots and already carries TAB / ZS / IO-in / IO-out); `TWO_EXT` rebound to the two bilinear slots "
        "(SC_SCORE, SC_PV); `DEFAULT_HOSTS` rebound to layout.rs's `HOSTS`.",
        "C-2  `build_report` / `main` are NOT called: two of their checks index the hard-coded split names "
        "SC_ATTN_08Q/K/V, which do not exist here.  The component functions (build_slot_table, "
        "standalone_report, host_groups_report, m_layout, largest_slot, r7_extension_check, "
        "negative_controls) are called unchanged and this script re-assembles the check list.",
        "C-3  the QKV-unsplit negative control hard-codes SC_ATTN_03 / 04 / 08Q / 08K / 08V.  It is run "
        "verbatim on a NAME-MAPPED copy of this layout's slot table (SC_QZC -> SC_ATTN_03, SC_KVZC -> "
        "SC_ATTN_04, SC_QMM/KMM/VMM -> SC_ATTN_08Q/K/V), so the shapes are this layout's.  The function body "
        "is untouched.",
        "C-4  P1 only.  `A2_cfs_slots.P3` is null: the module does not implement P3 (weights are public and "
        "there is no W commitment).",
    ],
}


# ---------------------------------------------------------------------------
# 7. main
# ---------------------------------------------------------------------------


def build_all(repo: str, out_dir: str, seed: int = DEFAULT_SEED, n_values: int = 4) -> dict:
    mod = os.path.join(repo, "hashline", "src", "private_attention")
    layout_path = os.path.join(mod, "layout.rs")
    argument_path = os.path.join(mod, "argument.rs")
    protocol_path = os.path.join(mod, "protocol.rs")
    scripts_dir = os.path.join(repo, "scripts")

    with open(layout_path) as f:
        lay = Layout(f.read())
    with open(argument_path) as f:
        sites = DefineParser(lay, f.read()).parse()
    with open(protocol_path) as f:
        protocol_src = f.read()
    src_sha = {p: sha256_file(os.path.join(repo, p)) for p in (
        "hashline/src/private_attention/layout.rs",
        "hashline/src/private_attention/argument.rs",
        "hashline/src/private_attention/protocol.rs",
        "zkp-core/src/pcs.rs")}
    inv = build_inventory(lay, sites, src_sha, repo, protocol_src=protocol_src)
    checks = cross_checks(lay, inv)

    os.makedirs(out_dir, exist_ok=True)
    inv_path = os.path.join(out_dir, "zk60_attention_native_inventory.json")
    with open(inv_path, "w") as f:
        json.dump(inv, f, indent=1, sort_keys=True, default=str)
        f.write("\n")
    hosts_path = os.path.join(out_dir, "zk60_attention_native_hosts.json")
    with open(hosts_path, "w") as f:
        json.dump({"variant": "layout.rs HOSTS",
                   "hosts": inv["A2_cfs_slots"]["hosts"], "extra_slots": {}}, f, indent=1)
        f.write("\n")

    rank, schedule, rank_failures = run_rank_tool(inv, lay, scripts_dir, seed, n_values=n_values)
    cfs, cfs_failures = run_cfs_tool(inv, lay, scripts_dir, out_dir, seed)

    with open(os.path.join(out_dir, "zk60_attention_native_pair_schedule.json"), "w") as f:
        json.dump(rank, f, indent=1, sort_keys=True, default=str)
        f.write("\n")
    with open(os.path.join(out_dir, "zk60_attention_native_schedule.json"), "w") as f:
        json.dump(schedule, f, indent=1, sort_keys=True, default=str)
        f.write("\n")
    with open(os.path.join(out_dir, "zk60_attention_native_cfs_slots.json"), "w") as f:
        json.dump(cfs, f, indent=1, sort_keys=True, default=str)
        f.write("\n")

    summary = {
        "task": "R-1: the pair-schedule rank check and the CFS slot check on the native layout",
        "layout_source": src_sha,
        "derived_vs_note": checks,
        "derived_counts": {
            "A_rows": lay.a_rows, "A_data_rows": lay.a_data_rows, "A_sites": sum(lay.a_sites),
            "H_rows": lay.h_rows, "H_data_rows": lay.h_data_rows, "H_sites": sum(lay.h_sites),
            "A_groups_derived": inv["A1_schedule"]["group_counts"]["A"],
            "H_groups_derived": inv["A1_schedule"]["group_counts"]["H"],
            "M_rows": lay.consts["M_ROWS"], "functionals": lay.consts["N_FUNCTIONALS"],
            "largest_L": max((m + e) * d + 2 for m, e, d in lay.slots),
            "U8_lookups": lookup_total(lay)["U8"], "exp_lookups": lookup_total(lay)["exp"],
        },
        "rank_summary": {
            "whole_A_per_column_disclosed_dim": rank["rank_verdicts"]["whole_A_per_column"]["disclosed_dim"],
            "whole_A_with_values_disclosed_dim": rank["rank_verdicts"][f"whole_A_with_values_n{n_values}"]["disclosed_dim"],
            "whole_H_per_column_disclosed_dim": rank["rank_verdicts"]["whole_H_per_column"]["disclosed_dim"],
            "whole_H_with_values_disclosed_dim": {
                k: v["disclosed_dim"] for k, v in rank["rank_verdicts"].items() if k.startswith("whole_H_with_values")},
            "H_residual_is_exactly_the_public_LogUp_identity": all(
                v.get("residual_is_exactly_the_public_identity") for k, v in rank["rank_verdicts"].items()
                if k.startswith("whole_H_with_values")),
            "groups_with_nonzero_disclosure": {k: v["disclosed_dim"] for k, v in rank["rank_verdicts"].items()
                                               if k.startswith("group_") and v.get("disclosed_dim")},
            "negative_controls": {k: {"disclosed_dim": v["disclosed_dim"], "verdict": v["verdict"]}
                                  for k, v in rank["rank_verdicts"]["negative_controls"].items()},
            "failures": rank_failures,
        },
        "cfs_summary": {
            "n_slots": len(cfs["slot_table"]), "largest_slot": cfs["largest_slot"],
            "standalone": {k: {"rank": v["rank_map"], "dim_S": v["dim_consistency_subspace"],
                               "kernel": v["kernel_dim_fp2"], "leaked": v["leaked_dim_fp2"], "pass": v["pass"]}
                           for k, v in cfs["standalone"].items()},
            "hosts": {k: {"hosted": v["hosted"], "sum_L": v["sum_L"], "rank": v["rank_map"],
                          "dim_S": v["dim_consistency_subspace"], "kernel": v["kernel_dim_fp2"],
                          "expected_kernel": v["expected_kernel_k_plus_1"], "leaked": v["leaked_dim_fp2"],
                          "pass": v["pass"]} for k, v in cfs["host_groups"].items()},
            "m_rows": cfs["m_layout"]["n_rows"], "n_functionals": cfs["m_layout"]["n_functionals"],
            "all_checks_pass": cfs["all_checks_pass"], "failures": cfs_failures,
        },
        "adaptations": ADAPTATIONS,
        "ambiguities": AMBIGUITIES,
        "outputs": sorted(os.path.join(out_dir, f) for f in os.listdir(out_dir)),
    }
    summary["findings"] = findings(lay, inv, rank, checks)
    summary["failures"] = ([c["name"] for c in checks if not c["pass"]]
                           + [f"rank/{x}" for x in rank_failures] + [f"cfs/{x}" for x in cfs_failures])
    summary["all_pass"] = not summary["failures"]
    with open(os.path.join(out_dir, "zk60_attention_native_summary.json"), "w") as f:
        json.dump(summary, f, indent=1, sort_keys=True, default=str)
        f.write("\n")
    return summary


def findings(lay: Layout, inv: dict, rank: dict, checks: List[dict]) -> List[dict]:
    """What the re-run turned up, mismatches first."""
    out: List[dict] = []
    bad = [c for c in checks if not c["pass"]]
    out.append({
        "id": "F-0", "severity": "none" if not bad else "mismatch",
        "title": "derived counts against ZK60_PRIVATE_ATTENTION_NATIVE.md section 3 / section 5",
        "detail": f"{len(checks) - len(bad)} of {len(checks)} cross-checks agree" +
                  ("" if not bad else "; mismatches: " + ", ".join(c["name"] for c in bad)),
        "mismatches": [{"name": c["name"], "derived": c["got"], "note": c["note_says"]} for c in bad],
    })
    nc = rank["rank_verdicts"]["negative_controls"].get("single_base_row_per_claim_A_per_column", {})
    if nc:
        out.append({
            "id": "F-1", "severity": "tool helper, not the delivery",
            "title": "the pair-schedule tool's `singleton_leak_expectation` under-counts this layout's "
                     "base1 control",
            "detail": f"the measured disclosure of the `one base mask row per claim` control is "
                      f"{nc['disclosed_dim']}; the tool's helper predicts "
                      f"{nc.get('tool_singleton_leak_expectation', {}).get('distinct_functionals')}. "
                      "The helper assumes two singleton groups with the same (rows, row-bit symbols) key "
                      "leak the SAME functional.  That holds when the row bits are constants (the leak is "
                      "a row's unit vector) but not when they are symbolic: the surviving base functional "
                      "is Im(c) Re(a eq) - Re(c) Im(a eq), which depends on the group's own e and lambda, "
                      "so k singleton groups on one R-row plane span min(k, R) dimensions.  Here "
                      "SC_QMM / SC_KMM / SC_VMM all open A_Y (rows 12-13) at the same symbolic row bit and "
                      "recover BOTH rows, and A_X (rows 6-7) is opened by SC_SS and SC_IO_IN.  This script "
                      "uses the corrected expectation (`native_singleton_expectation`).  It changes no "
                      "positive verdict: the delivery gives every site a pair, and the control's point "
                      "(a single base row leaks, the pair closes it) is unaffected.",
        })
    out.append({
        "id": "F-2", "severity": "ambiguity, resolved",
        "title": "A_GROUPS / H_GROUPS cannot be checked from layout.rs alone",
        "detail": "layout.rs declares A_GROUPS = 30 and H_GROUPS = 8 as hand counts with no derivation; "
                  "the PCS column keys that decide them are the evaluation points in "
                  "argument.rs::define.  Parsing define and applying zkp-core's ZKey rule "
                  "((point tail, c0, len), first occurrence) reproduces 30 and 8 exactly, so the two "
                  "constants the prover and verifier compare the PCS's real grouping against are right.",
        "derived": {"A": inv["A1_schedule"]["group_counts"]["A"], "H": inv["A1_schedule"]["group_counts"]["H"]},
    })
    tzc = [g for g in inv["A1_schedule"]["opening_groups"]["A"] if g["len"] < N_COLS]
    out.append({
        "id": "F-3", "severity": "note for the reviewer",
        "title": "the sub-row (c0, len) half of the PCS key carries 7 of the 30 A groups",
        "detail": "SC_TZC opens A_D, A_DSQ and the nine 32-entry limb sub-planes at ONE point.  Their "
                  "point tails are identical, so a reader who groups by the tail alone counts one group; "
                  "the PCS also keys on the column window (c0, len), which splits them into the c0 = 0 "
                  "group {A_D, A_DSQ, limb 0, limb 8} and seven singletons at c0 = 32..224.  Ignoring "
                  "(c0, len) would give A_GROUPS = 23 and the prover would refuse its own honest proof "
                  "with `N opening groups, the schedule declares M`.  The declared 30 is the value the "
                  "PCS actually produces.",
        "sub_row_groups": [{"group": g["group"], "c0": g["c0"], "len": g["len"], "m": g["m"]} for g in tzc],
    })
    out.append({
        "id": "F-4", "severity": "scope",
        "title": "what these two tools do NOT settle",
        "detail": "both are linear-algebraic models at seeded stand-in challenges.  Outside them: the "
                  "sampled columns and salted Merkle paths, transcript conditioning (no simulator), "
                  "integer-range side information, cross-commitment correlation (A <-> H share data, "
                  "never masks), the captured-receipt joint-view gate of the construction section 7, and "
                  "D8 / D11 (the endpoint-reuse premises the note itself leaves open).  P3 is not "
                  "modelled because the module does not implement it.",
    })
    return out


AMBIGUITIES = [
    "A-1  layout.rs declares only the site COUNTS per slot (`A_SITES` / `H_SITES`) and the hand-counted "
    "`A_GROUPS = 30` / `H_GROUPS = 8`.  The evaluation points -- the PCS column keys that DECIDE those two "
    "numbers -- live in `argument.rs::define`, not in layout.rs.  This script therefore parses `define` as "
    "well and derives the group counts from the PCS key rule; layout.rs alone cannot answer R-1.",
    "A-2  the PCS key of a sub-row slice is (point, c0, len), not the point tail alone (zkp-core "
    "pcs::zpart_weights).  layout.rs does not state this; it is read from the PCS source.  It matters: the "
    "eleven 32-entry sites of SC_TZC fall into 8 groups, not 1 and not 11.",
    "A-3  layout.rs's comment says 'the histograms are committed A rows' without saying they carry ordinary "
    "claim sites; `argument.rs::SC_TAB` settles it (`b.a(A_MU8)`, `b.a(A_MEXP)` each take a reserved pair).",
    "A-4  the note's `A = 306 rows (154 data + 150 site-pair + 2 proximity)` counts u inside H's data rows "
    "and u' inside H's site pairs.  The rank tool's H model counts u and u' as mask rows; the totals agree, "
    "the region boundaries are relabelled (adaptation R-5).",
]


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", default="/home/victor/wt-zk60-attention-compile")
    ap.add_argument("--out-dir", default="results/zk60_private_attention_native_evidence/rank_cfs")
    ap.add_argument("--seed", type=int, default=DEFAULT_SEED)
    ap.add_argument("--n-values", type=int, default=4)
    args = ap.parse_args(argv)
    out_dir = args.out_dir if os.path.isabs(args.out_dir) else os.path.join(args.repo, args.out_dir)
    s = build_all(args.repo, out_dir, seed=args.seed, n_values=args.n_values)
    print("derived vs the note:")
    for c in s["derived_vs_note"]:
        print(f"  {'ok  ' if c['pass'] else 'FAIL'} {c['name']}: {c['got']!r}" + ("" if c["pass"] else f"  (note: {c['note_says']!r})"))
    print("rank:", json.dumps(s["rank_summary"], default=str)[:1200])
    print("cfs :", json.dumps(s["cfs_summary"], default=str)[:1200])
    print("failures:", s["failures"] or "none")
    return 0 if s["all_pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
