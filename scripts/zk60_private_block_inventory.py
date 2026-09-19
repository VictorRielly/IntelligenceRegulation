#!/usr/bin/env python3
"""zk60_private_block_inventory.py -- the three committed leak-checking tools re-run on the REAL
Rust source of the private BLOCK (`hashline/src/private_block/`), not on a paper schedule.

WHY.  `docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` section 3, condition 4:

    "The tools are re-run on the real Rust, not on the paper schedule, before the module is
     called a block: the inventory tool re-derives every count of section 1.2 from the source,
     NOTE_EXPECT is updated, every group and both endpoints disclose 0, H's residual is exactly
     the public identity, every host group has kernel 3 and leaks 0, every slot satisfies
     L + 256 <= 512, and all 18 negative controls fire, plus the two owed ones (A_H16 sharing
     A_U16's pair; A_YM sharing A_Y's pair).  A control that stops firing is a stop."

Until now the block layout existed only as a description, and two PAPER drivers
(`results/zk60_private_block_construction/grow_and_run.py` and `..._whole_block.py`) fed that
description to the tools.  This driver feeds them the SOURCE.

WHAT IT DOES, in order.
  1. SELF-CHECK.  Runs the committed `scripts/zk60_attention_native_inventory.py` unmodified on
     `hashline/src/private_attention/` (the accepted component) via its own `build_all`, and
     requires its own 29 cross-checks to pass with `failures: []`.  If the rebinding below had
     broken anything in the imported tools, this control would move.
  2. THE REAL BLOCK SOURCE.  Parses `hashline/src/private_block/{layout,argument,protocol}.rs`
     with the committed tool's own `Layout`, `DefineParser` and `parse_logup_sum`, through four
     small, named adapters (see `ADAPTERS`) for the constructs the block's Rust uses and the
     accepted component's Rust does not.  NOTHING under `scripts/` is edited and NO Rust file is
     touched; every adapter is a subclass or a source-level normalisation driven by what
     `layout.rs` itself says.
  3. Derives the counts and cross-checks every one of them against `BLOCK_EXPECT` -- the DESIGN's
     numbers, taken from `ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2_CHECK.md` section 5.2 and the
     disposition.  A mismatch is a FINDING; the expectation is never edited to make it pass.
  4. Runs the committed rank tool (`zk60_attention_pair_schedule.py`) and the committed CFS tool
     (`zk60_attention_cfs_slots.py`) through the committed inventory module's own
     `run_rank_tool` / `run_cfs_tool`, so the adaptations R-1..R-9 and C-1..C-4 are exactly the
     accepted ones.
  5. Adds the TWO OWED negative controls as mutations of the DERIVED claim list (not of the
     Rust): `A_H16`'s `SC_FZC` site re-using `A_U16`'s reserved pair, and `A_YM`'s `SC_DZC` site
     re-using `A_Y`'s.  Each must make the rank tool's disclosed dimension rise above 0.
  6. Compares every count and every verdict, item by item, with the PAPER whole-block run under
     `results/zk60_private_block_construction/whole_block/`, and records every difference.

WHAT IT WRITES (under `results/zk60_private_block_tools/` by default):
  zk60_private_block_inventory.json      the inventory derived from the real source
  zk60_private_block_hosts.json          the host map for the CFS tool
  zk60_private_block_pair_schedule.json  the rank tool's record on the real source
  zk60_private_block_schedule.json       the site/row schedule the rank tool derives
  zk60_private_block_cfs_slots.json      the CFS tool's record on the real source
  zk60_private_block_summary.json        cross-checks, verdicts, the paper comparison, findings
  zk60_private_block_inventory.log       the printed run log
  zk60_private_block_inventory.done      the exit code
  accepted_selfcheck/                    the committed tool's own six records on the ACCEPTED
                                         attention layout (step 1's control)

WHAT A VERDICT HERE IS, AND IS NOT.  Every verdict below is a statement about a LINEAR-ALGEBRA
MODEL of the real schedule at seeded stand-in challenges.  The models exclude the sampled
columns, the salted Merkle paths, the CFS channel, transcript conditioning, integer-range side
information and correlation between `A` and `H`.  NOTHING here is a privacy property of the
construction.  The construction's own gate -- a zero-witness preimage with the same free
dimension as the real witness on every channel, on captured real receipts -- is unmet, and
D8 / D11 stay open for the block's two external endpoints.

Usage:
    python3 scripts/zk60_private_block_inventory.py \
        --repo /home/victor/wt-zk60-private-block \
        --out-dir results/zk60_private_block_tools [--seed N] [--skip-self-check]
Exit status is nonzero when a cross-check, a tool verdict or a negative control fails.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import sys
from typing import Dict, List, Optional, Sequence, Tuple

DEFAULT_REPO = "/home/victor/wt-zk60-private-block"
DEFAULT_OUT = "results/zk60_private_block_tools"
PAPER_WHOLE_BLOCK = "results/zk60_private_block_construction/whole_block"

CAVEAT = (
    "These verdicts are about a LINEAR-ALGEBRA MODEL of the real Rust schedule of "
    "hashline/src/private_block/, at seeded stand-in challenges. The models exclude the sampled "
    "columns, the salted Merkle paths, the CFS channel, transcript conditioning, integer-range "
    "side information and correlation between A and H -- exactly as on the accepted attention "
    "layout (ZK60_PRIVATE_ATTENTION_NATIVE.md:79). NOTHING here establishes a privacy property "
    "of the construction: the joint-view gate on captured receipts is unmet and D8 / D11 stay "
    "open for the block's two external endpoints x_in and xres2. What is new relative to the "
    "paper runs is only that the schedule is now READ OUT OF CODE instead of out of a memo."
)


def load_tool(path: str, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


# ---------------------------------------------------------------------------
# 1. the adapters
# ---------------------------------------------------------------------------

ADAPTERS = [
    "B-1  `Layout.limb_off_m` -- hashline/src/private_block/layout.rs:647 adds a second limb "
    "base (`a_off[A_LIMBM] + k * T`, norm_m's limbs) beside `limb_off`, and "
    "private_block/argument.rs:570 calls it inside a site: "
    "`b.a_slice(lay.limb_off_m(kk), 5, rho(0..5), 0)`.  The committed `Layout` class has no such "
    "method and the committed `DefineParser._int` substitutes only `lay.limb_off(..)`.  ADAPTER: "
    "`BlockLayout` (a subclass) adds `limb_off_m` with exactly layout.rs's arithmetic, and "
    "`BlockDefineParser._int` substitutes `lay.limb_off_m(k)` with it before delegating.  No "
    "value is assumed: the plane index and `T` come from the parsed consts.",

    "B-2  receiver-qualified `lay.helpers(..)` -- the accepted argument.rs calls the free "
    "function `helpers(Dom::D).1` (private_attention/argument.rs:613, :621, :652, :666, :691); "
    "the block calls the method `lay.helpers(Dom::D).1` "
    "(private_block/argument.rs:690, :701, :743, :783, :797, :822).  The committed "
    "`_int`/`_statement` regexes are anchored on the free-function spelling.  ADAPTER: "
    "`BlockDefineParser` rewrites the exact token `lay.helpers(` to `helpers(` in each statement "
    "and expression before delegating.  Nothing else named `lay.` is touched (the committed "
    "parser already handles `lay.a_off[..]` and `lay.limb_off(..)`), and `helpers(` never occurs "
    "inside a site call's argument list.",

    "B-3  `let <name> = if <cond> { <challenge> } else { <point>.clone() }` -- "
    "private_block/argument.rs:668, `let r_row = if slot == SC_DMM { tr.challenge_fp2_vec(5) } "
    "else { pts.r_tf.clone() };`, the one construct the feed-forward matmul arm needs and the "
    "accepted source never uses (the committed parser handles only the TUPLE form "
    "`let (a, b) = if flag {..} else {..}` and only with a bool local as the condition).  "
    "ADAPTER: `BlockDefineParser._statement` evaluates the condition with the committed "
    "`_cond`, takes the live branch and binds a challenge vector or a `pts.X` / `pts.X.clone()` "
    "vector; anything else falls through to the committed parser unchanged.  The bound symbols "
    "are `SC_DMM.r_row[i]` (the Rust local's own name), distinct from `SC_GMM.r_tf[i]`, which is "
    "what the PCS grouping keys on.",

    "B-4  `protocol.rs::logup_sum_claim` indirections -- the accepted source loops "
    "`for p in 0..N_H` and signs with `if p == H_GU8 || p == H_GEXP`; the block "
    "(private_block/protocol.rs:54-55) loops `for p in lay.h_planes()` and signs with "
    "`if h_is_table(p)`.  The committed `parse_logup_sum` refuses the first and silently reads "
    "an EMPTY negated set from the second.  ADAPTER: `normalise_logup_source` resolves BOTH "
    "indirections out of layout.rs itself -- `fn h_planes` must read `(0..N_H).collect()` "
    "(layout.rs:615-617) and `fn h_is_table` must read `matches!(plane, ...)` (layout.rs:255-257) "
    "-- and rewrites those two lines into the spelling the committed parser understands, so that "
    "all of its own assertions (`point: vec![]`, `value: Fp2::ZERO`, loop range == N_H) still "
    "run.  Both forms are asserted, not assumed; an unexpected body is a hard parse error.",

    "B-5  the two OWED negative controls re-use the committed rank tool with its accepted "
    "rebinding: after `INV.run_rank_tool` returns, the already-rebound module instance is taken "
    "from `sys.modules['zk60_attention_pair_schedule']` and its own `build_schedule` / "
    "`a_model_groups(share_mask=...)` / `build_model` / `analyze_fast` are called again.  No "
    "constant is rebound a second time and no tool function is redefined.",

    "B-6  the activation table's lookup total.  The committed `lookup_total` knows two tables "
    "(U8 by summing `lookups(dom)` over `LOOKUP_DOMS`, exp as `1 << Dom::S.log()`).  The block "
    "has a third, the activation table (private_block/argument.rs:766 `f_act`, one lookup per "
    "`Dom::F` element).  `block_lookup_totals` adds `act = 1 << Dom::F.log()` by exactly the "
    "committed tool's own convention for exp.  The U8 and exp totals are the committed "
    "function's, unchanged.",
]

AMBIGUITIES = [
    "A-1  layout.rs declares only the per-slot site COUNTS (`A_SITES` / `H_SITES`) and the "
    "hand-counted `A_GROUPS = 35` / `H_GROUPS = 9`.  The PCS column keys that DECIDE the group "
    "counts live in `argument.rs::define`.  This driver parses `define` and derives them, exactly "
    "as the committed tool does for the accepted layout.",
    "A-2  the PCS key of a sub-row slice is (point tail, c0, len), read from "
    "`zkp-core/src/pcs.rs::zpart_weights`, not from layout.rs.",
    "A-3  `WEIGHT_MATMUL_SECTIONS` is rebound by the committed `run_rank_tool` to the four "
    "attention matmul slots (SC_QMM / SC_KMM / SC_VMM / SC_WO) and therefore does not name the "
    "three feed-forward matmuls (SC_GMM / SC_UMM / SC_DMM).  Under P1 that constant only selects "
    "a COEFFICIENT-FORM STRING and a `p3` e-kind, neither of which is used in any P1 model, so "
    "the rank verdicts are unaffected.  The paper whole-block run has the same property, so the "
    "comparison is like for like.",
    "A-4  the two owed controls are mutations of the derived claim list inside the rank model.  "
    "The source's own runtime defence against a shared pair is "
    "`private_block/protocol.rs::audit_claims` (`a reserved pair is unused or shared between "
    "claims`); that refusal is a Rust test, not this driver's business, and is NOT exercised "
    "here.",
]


class BlockLayout:
    """`INV.Layout` for the block source, plus adapter B-1."""

    def __new__(cls, INV, src: str):
        lay = INV.Layout(src)
        lay.limb_off_m = _make_limb_off_m(lay)
        return lay


def _make_limb_off_m(lay):
    def limb_off_m(k: int) -> int:
        return lay.a_off[lay.consts["A_LIMBM"]] + k * lay.consts["T"]
    return limb_off_m


def make_block_define_parser(INV):
    """`INV.DefineParser` + adapters B-1, B-2, B-3.  Built inside a function so the committed
    module is imported by path exactly once, by the caller."""

    class BlockDefineParser(INV.DefineParser):
        def __init__(self, lay, src: str):
            super().__init__(lay, src)
            self.adapters_used: Dict[str, int] = {}

        def _note(self, key: str) -> None:
            self.adapters_used[key] = self.adapters_used.get(key, 0) + 1

        # ---- B-1 / B-2 ---------------------------------------------------
        def _int(self, expr, env):
            e = str(expr)
            if "lay.helpers(" in e:
                self._note("B-2")
                e = e.replace("lay.helpers(", "helpers(")
            if "lay.limb_off_m(" in e:
                self._note("B-1")
                merged = dict(self.lay.consts)
                merged.update({k: v for k, v in env.items()
                               if isinstance(v, int) and not isinstance(v, bool)})
                prev = None
                while prev != e:
                    prev = e
                    e = re.sub(r"lay\.limb_off_m\(([\w ]+)\)",
                               lambda m: str(self.lay.limb_off_m(INV.eval_int(m.group(1), merged))), e)
            return super()._int(e, env)

        # ---- B-2 / B-3 ---------------------------------------------------
        def _statement(self, s: str, env: Dict, slot: int, out: List):
            if "lay.helpers(" in s:
                self._note("B-2")
                s = s.replace("lay.helpers(", "helpers(")
            m = re.match(r"^let\s+(?:mut\s+)?(\w+)\s*=\s*if\s+(.+?)\s*\{(.+?)\}\s*else\s*\{(.+?)\}$",
                         s, re.S)
            if m and not INV.SITE_CALL_RE.search(s):
                name = m.group(1)
                taken = (m.group(3) if self._cond(m.group(2), env, slot)
                         else m.group(4)).strip().rstrip(";").strip()
                mc = re.match(r"^tr\.challenge_fp2_vec\((.+)\)$", taken)
                if mc:
                    self._note("B-3")
                    k = self._int(mc.group(1), env)
                    env[name] = [f"{self.lay.slot_name_of[slot]}.{name}[{i}]" for i in range(k)]
                    return None
                mc = re.match(r"^pts\.(\w+)(?:\.clone\(\))?$", taken)
                if mc:
                    self._note("B-3")
                    if mc.group(1) not in self.pts:
                        raise INV.RustParseError(f"pts.{mc.group(1)} read before assignment")
                    env[name] = list(self.pts[mc.group(1)])
                    return None
                # not a construct B-3 knows: fall through to the committed parser
            return super()._statement(s, env, slot, out)

    return BlockDefineParser


def normalise_logup_source(INV, protocol_src: str, layout_src: str) -> Tuple[str, dict]:
    """Adapter B-4: rewrite `logup_sum_claim`'s two indirections into the spelling the committed
    `parse_logup_sum` understands, resolving both out of layout.rs.  Returns (source, record)."""
    lsrc = INV.strip_comments(layout_src)
    psrc = INV.strip_comments(protocol_src)
    rec: Dict[str, object] = {}

    # --- `lay.h_planes()` : layout.rs must say `(0..N_H).collect()`
    body = INV.fn_body(lsrc, "h_planes").strip()
    m = re.match(r"^\(0\.\.(\w+)\)\.collect\(\)$", body)
    if not m:
        raise INV.RustParseError(f"layout.rs::h_planes has an unexpected body {body!r}; "
                                 "adapter B-4 refuses to guess the plane set")
    rec["h_planes_body"] = body
    rec["h_planes_range_const"] = m.group(1)

    # --- `h_is_table(p)` : layout.rs must say `matches!(plane, A | B | C)`
    body = INV.fn_body(lsrc, "h_is_table").strip()
    mm = re.match(r"^matches!\(\s*\w+\s*,\s*(.+?)\s*\)$", body, re.S)
    if not mm:
        raise INV.RustParseError(f"layout.rs::h_is_table has an unexpected body {body!r}; "
                                 "adapter B-4 refuses to guess the table planes")
    table_planes = [x.strip() for x in mm.group(1).split("|")]
    rec["h_is_table_body"] = body
    rec["h_is_table_planes"] = table_planes

    out = psrc
    old_loop = f"for p in lay.h_planes() {{"
    if old_loop not in out:
        raise INV.RustParseError("protocol.rs::logup_sum_claim: the `for p in lay.h_planes()` "
                                 "loop adapter B-4 expects was not found")
    out = out.replace(old_loop, f"for p in 0..{m.group(1)} {{", 1)
    old_sign = "if h_is_table(p)"
    if old_sign not in out:
        raise INV.RustParseError("protocol.rs::logup_sum_claim: the `if h_is_table(p)` sign "
                                 "adapter B-4 expects was not found")
    out = out.replace(old_sign, "if " + " || ".join(f"p == {x}" for x in table_planes), 1)
    rec["rewrote"] = [old_loop, old_sign]
    return out, rec


# ---------------------------------------------------------------------------
# 2. the design's numbers -- BLOCK_EXPECT (never edited to make a run pass)
# ---------------------------------------------------------------------------
#
# Source of every entry: ZK60_PRIVATE_BLOCK_CONSTRUCTION_TIER2_CHECK.md section 5.1 / 5.2 / 5.3
# and section 7.4, and the disposition's section 3 condition 4.  These are the DESIGN's values.

BLOCK_EXPECT = {
    "A_rows": 455, "A_data_rows": 213, "A_site_pair_rows": 240, "A_prox_rows": 2,
    "H_rows": 384, "H_data_rows": 280, "H_site_pair_rows": 102, "H_prox_rows": 2,
    "A_sites": 120, "H_sites": 51,
    "A_GROUPS": 35, "H_GROUPS": 9,
    "n_slots": 23, "n_hosts": 6,
    "slot_kinds": {"Private": 12, "Standalone": 5, "Host": 6},
    "M_ROWS": 50, "N_FUNCTIONALS": 34,
    "largest_L": 50, "largest_L_slot": "SC_SZC", "largest_L_headroom": 206,
    "U8_lookups": 61440, "exp_lookups": 2048, "act_lookups": 512,
    "main_rounds_total": 159, "ext_rounds_total": 25,
    "sum_main_ext_times_degree_plus_1": 721,
    "terminals": 173,
    "slots": [(9, 1, 3), (9, 1, 3), (5, 1, 3), (9, 1, 4), (11, 1, 3), (4, 1, 2), (4, 1, 2),
              (4, 1, 2), (3, 2, 2), (5, 2, 2), (4, 1, 2), (4, 1, 2), (4, 1, 2), (4, 1, 2),
              (9, 1, 4), (9, 1, 4), (8, 1, 4), (11, 1, 4), (9, 1, 4), (8, 1, 3), (8, 1, 2),
              (9, 1, 2), (9, 1, 2)],
    "hosts_by_index": {2: [0, 1], 14: [10, 13], 15: [5, 9], 16: [6, 7], 17: [4, 8], 18: [11, 12]},
    "sites_per_slot_A": {"SC_DZC": 37, "SC_FZC": 11, "SC_TAB": 3},
    "sites_per_slot_H": {"SC_DZC": 19, "SC_FZC": 6, "SC_TAB": 3},
    # CFS: host group rank criterion  rank = dim S = sum L - (k + 1),  kernel = k + 1 = 3
    "host_sum_L": {"SC_TZC": 84, "SC_DZC": 66, "SC_QZC": 70, "SC_KVZC": 62, "SC_SZC": 100,
                   "SC_FZC": 66},
    "host_rank": {"SC_TZC": 81, "SC_DZC": 63, "SC_QZC": 67, "SC_KVZC": 59, "SC_SZC": 97,
                  "SC_FZC": 63},
    "host_kernel": 3,
    # CFS: standalone criterion  rank = dim S = N d + 1 (TIER2-CHECK section 7.4)
    "standalone_dim_S": {"SC_SS": 31, "SC_SSM": 31, "SC_TZC": 19, "SC_LZC": 41, "SC_RS": 37,
                         "SC_QMM": 11, "SC_KMM": 11, "SC_VMM": 11, "SC_SCORE": 11, "SC_PV": 15,
                         "SC_WO": 11, "SC_GMM": 11, "SC_UMM": 11, "SC_DMM": 11, "SC_DZC": 41,
                         "SC_QZC": 41, "SC_KVZC": 37, "SC_SZC": 49, "SC_FZC": 41, "SC_TAB": 28,
                         "SC_ZS": 19, "SC_IO_IN": 21, "SC_IO_OUT": 21},
    "profile": "hashline-zk-mr1/private-block-t32-poc/1",
}


def block_lookup_totals(INV, lay) -> Dict[str, int]:
    """Adapter B-6: the committed `lookup_total` plus the activation table."""
    tot = dict(INV.lookup_total(lay))
    tot["act"] = 1 << lay.dom_logs["F"]
    return tot


def block_cross_checks(INV, lay, inv: dict, expect: dict) -> List[dict]:
    """Every derived count against the DESIGN.  Mirrors the committed `cross_checks`, with the
    block's own expectations and the counts the block adds."""
    out: List[dict] = []

    def chk(name: str, got, want, detail: str = "") -> None:
        out.append({"name": name, "derived": got, "design_says": want,
                    "pass": got == want, "detail": detail})

    n_a_sites, n_h_sites = sum(lay.a_sites), sum(lay.h_sites)
    chk("A rows", lay.a_rows, expect["A_rows"])
    chk("A data rows", lay.a_data_rows, expect["A_data_rows"])
    chk("A site-pair rows", 2 * n_a_sites, expect["A_site_pair_rows"])
    chk("A proximity rows", lay.a_rows - lay.a_prox, expect["A_prox_rows"])
    chk("H rows", lay.h_rows, expect["H_rows"])
    chk("H data rows (incl. u)", lay.h_data_rows, expect["H_data_rows"])
    chk("H site-pair rows (incl. u')", 2 * n_h_sites, expect["H_site_pair_rows"])
    chk("H proximity rows", lay.h_rows - lay.h_prox, expect["H_prox_rows"])
    chk("A claim sites declared in layout.rs A_SITES", n_a_sites, expect["A_sites"])
    chk("H claim sites declared in layout.rs H_SITES", n_h_sites, expect["H_sites"])
    chk("A claim sites found in argument.rs::define",
        inv["A1_schedule"]["claim_counts"]["A"], expect["A_sites"])
    chk("H claim sites found in argument.rs::define",
        inv["A1_schedule"]["claim_counts"]["H_eval"], expect["H_sites"])
    chk("A opening groups (derived from the PCS key rule)",
        inv["A1_schedule"]["group_counts"]["A"], expect["A_GROUPS"],
        "layout.rs A_GROUPS is a hand count; this is the derivation from argument.rs::define")
    chk("H opening groups (derived, incl. the sum group)",
        inv["A1_schedule"]["group_counts"]["H"], expect["H_GROUPS"])
    chk("A_GROUPS declared in layout.rs", lay.consts["A_GROUPS"], expect["A_GROUPS"])
    chk("H_GROUPS declared in layout.rs", lay.consts["H_GROUPS"], expect["H_GROUPS"])
    chk("CFS slots", lay.n_slots, expect["n_slots"])
    kinds = {k: sum(1 for x in lay.slot_kinds if x == k) for k in ("Private", "Standalone", "Host")}
    chk("slot kinds private / standalone / host", kinds, expect["slot_kinds"])
    chk("host groups", len(lay.hosts), expect["n_hosts"])
    chk("M rows", lay.consts["M_ROWS"], expect["M_ROWS"])
    chk("M rows = 2 * slots + 4", 2 * lay.n_slots + 4, expect["M_ROWS"])
    n_standalone = sum(1 for k in lay.slot_kinds if k == "Standalone")
    chk("functionals = slots + standalone Gammas + one batched Gamma per host",
        lay.n_slots + n_standalone + len(lay.hosts), expect["N_FUNCTIONALS"])
    chk("N_FUNCTIONALS declared in layout.rs", lay.consts["N_FUNCTIONALS"], expect["N_FUNCTIONALS"])
    chk(f"the {expect['n_slots']} (main, ext, degree) triples",
        [tuple(x) for x in lay.slots], [tuple(x) for x in expect["slots"]])
    lens = [(m + e) * d + 2 for (m, e, d) in lay.slots]
    chk("largest mask row L", max(lens), expect["largest_L"])
    chk("the slot with the largest L", lay.slot_name_of[lens.index(max(lens))],
        expect["largest_L_slot"])
    chk("largest slot's coefficient headroom (512 - 256 - L)",
        512 - 256 - max(lens), expect["largest_L_headroom"])
    chk("every slot L_s + 256 <= 512", all(L + 256 <= 512 for L in lens), True,
        json.dumps({lay.slot_name_of[s]: L + 256 for s, L in enumerate(lens)}))
    chk("total main rounds", sum(m for m, _, _ in lay.slots), expect["main_rounds_total"])
    chk("total extension rounds", sum(e for _, e, _ in lay.slots), expect["ext_rounds_total"])
    chk("sum (main + ext) * (degree + 1)",
        sum((m + e) * (d + 1) for m, e, d in lay.slots),
        expect["sum_main_ext_times_degree_plus_1"])
    chk("terminals (A sites + H sites + 2 endpoints)", n_a_sites + n_h_sites + 2,
        expect["terminals"])
    tot = block_lookup_totals(INV, lay)
    chk("U8 lookups", tot["U8"], expect["U8_lookups"])
    chk("exp lookups", tot["exp"], expect["exp_lookups"])
    chk("act lookups", tot["act"], expect["act_lookups"])
    chk("hosts (module slot indices)", {h: list(hs) for h, hs in lay.hosts},
        expect["hosts_by_index"])
    chk("host runs after every slot it hosts",
        all(s < h for h, hs in lay.hosts for s in hs), True)
    for c, n in sorted(expect["sites_per_slot_A"].items()):
        chk(f"A sites of {c}", lay.a_sites[lay.consts[c]], n)
    for c, n in sorted(expect["sites_per_slot_H"].items()):
        chk(f"H sites of {c}", lay.h_sites[lay.consts[c]], n)
    chk("helper planes cover the lookups pairwise",
        {d: (lay.lookup_counts[d] + 1) // 2 for d in lay.lookup_doms},
        {d: lay.helpers[d][1] for d in lay.lookup_doms})
    a_rows = sorted(c["mask_rows"][0] for c in inv["A1_schedule"]["claims"]
                    if c["commitment"] == "A")
    h_rows = sorted(c["mask_rows"][0] for c in inv["A1_schedule"]["claims"]
                    if c["commitment"] == "H" and not c["sum_claim"])
    chk("A reserved-pair first rows == layout.rs a_site(slot, k)",
        a_rows, list(range(lay.a_mask_base, lay.a_prox, 2)))
    chk("H reserved-pair first rows == layout.rs h_site(slot, k)",
        h_rows, list(range(lay.h_mask_base, lay.h_prox, 2)))
    return out


# ---------------------------------------------------------------------------
# 3. the two owed negative controls (adapter B-5)
# ---------------------------------------------------------------------------

OWED_CONTROLS = [
    # (key, slot const, the site that LOSES its pair, the site whose pair it takes, the memo)
    ("A_H16_shares_A_U16_pair", "SC_FZC", "A_H16", "A_U16",
     "TIER2 section G / the checker's owed control: give A_H16's SC_FZC site the same reserved "
     "mask pair as A_U16's; the two f-cube planes are near-duplicates and no accepted control "
     "covers them.  The rank tool's disclosed dimension must rise."),
    ("A_YM_shares_A_Y_pair", "SC_DZC", "A_YM", "A_Y",
     "TIER1 section G.2 lines 1210-1214, the `norm_m sharing norm_a's pairs` control: give "
     "A_YM's SC_DZC site the same reserved pair as A_Y's.  The two norms are structurally "
     "identical relations on the same domain, so this is the most likely implementation slip."),
]


def find_site(sched: dict, section: str, plane_name: str) -> dict:
    """The A site of `section` whose description names `plane_name` exactly."""
    want = f"A[{plane_name}]"
    hits = [s for s in sched["commitments"]["A"]["sites"]
            if s["section"] == section and s["site"].endswith(want)]
    if len(hits) != 1:
        raise SystemExit(f"owed control: {len(hits)} sites match {section!r} / {want!r}; "
                         "expected exactly one")
    return hits[0]


def run_owed_controls(INV, inv: dict, lay, seed: int, n_values: int = 4) -> Tuple[dict, List[str]]:
    """Adapter B-5.  Re-uses the rank tool instance `run_rank_tool` already rebound."""
    PS = sys.modules["zk60_attention_pair_schedule"]
    view = INV.tool_view_inventory(inv, lay)
    sched = PS.build_schedule(view, "block", endpoints="pair")
    INV._renumber_h(sched, lay)

    nc: Dict[str, dict] = {}
    failures: List[str] = []

    def rec(key: str, res: dict, ok: bool, argument: str, **extra) -> None:
        v = {**PS.summ(res), "argument": argument, "verdict": "PASS" if ok else "FAIL", **extra}
        nc[key] = v
        if not ok:
            failures.append(f"owed/{key}")

    for key, slot_const, taker, donor, memo in OWED_CONTROLS:
        section = lay.slot_names[lay.consts[slot_const]]
        a = find_site(sched, section, taker)
        b = find_site(sched, section, donor)
        gs = sorted({a["group"], b["group"]})
        model, _ = PS.build_model(
            f"{slot_const}: {taker} re-uses {donor}'s reserved pair",
            PS.a_model_groups(sched, only_groups=gs, include_tab=False,
                              share_mask={a["role"]: b["role"]}),
            n_values, PS.seed_for(seed, f"nc-share-{key}"), True)
        res = PS.analyze_fast(model)
        rec(f"{key}_with_values_n{n_values}", res, res["disclosed_dim"] >= 2, memo,
            groups=gs, taker=a["site"], donor=b["site"],
            taker_pair=b["mask_rows"], donor_pair=b["mask_rows"], expected_at_least=2)
        # the positive counterpart: with its OWN pair the same two groups disclose nothing
        model, _ = PS.build_model(
            f"{slot_const}: {taker} keeps its own reserved pair",
            PS.a_model_groups(sched, only_groups=gs, include_tab=False),
            n_values, PS.seed_for(seed, f"nc-own-{key}"), True)
        res = PS.analyze_fast(model)
        rec(f"{key.replace('shares', 'own_pair_not')}_with_values_n{n_values}", res,
            res["disclosed_dim"] == 0,
            "positive control: with its own pair the same groups disclose nothing", groups=gs)
    return nc, failures


# ---------------------------------------------------------------------------
# 4. the comparison against the PAPER whole-block run
# ---------------------------------------------------------------------------


def compare_with_paper(paper: Optional[dict], counts: dict, rank: dict, cfs: dict) -> dict:
    """Item by item: what the paper schedule said against what the real source says."""
    if paper is None:
        return {"available": False,
                "note": "the paper whole-block summary was not found; no comparison made"}
    diffs: List[dict] = []
    same: List[str] = []
    only_here: List[dict] = []

    def cmp(name: str, mine, theirs) -> None:
        if mine == theirs:
            same.append(name)
        else:
            diffs.append({"item": name, "real_source": mine, "paper_schedule": theirs})

    def cmp_optional(name: str, mine, theirs) -> None:
        """For items the PAPER run never had (the two owed controls and their positives):
        an absence in the memo is not a disagreement about a shared quantity."""
        if theirs is None:
            only_here.append({"item": name, "real_source": mine,
                              "paper_schedule": "not run (this is one of the OWED controls the "
                                                "paper runs could not wire)"})
        else:
            cmp(name, mine, theirs)

    pc = paper.get("whole_counts", {})
    for k in ("a_rows", "a_data_rows", "a_site_pair_rows", "h_rows", "h_data_rows",
              "h_site_pair_rows", "A_sites", "H_sites", "A_groups_derived", "H_groups_derived",
              "n_slots", "M_ROWS", "N_FUNCTIONALS", "largest_L", "U8_lookups", "exp_lookups",
              "main_rounds_total", "ext_rounds_total", "sum_main_ext_times_degree_plus_1",
              "terminals"):
        if k in pc and k in counts:
            cmp(f"count/{k}", counts[k], pc[k])
    if "hosts_by_index" in pc:
        cmp("count/hosts_by_index",
            {str(k): v for k, v in counts["hosts_by_index"].items()},
            {str(k): v for k, v in pc["hosts_by_index"].items()})
    if "slot_L" in pc:
        cmp("count/slot_L", counts["slot_L"], pc["slot_L"])

    pr = paper.get("rank", {})
    rv = rank["rank_verdicts"]
    mine_rank = {
        "whole_A_per_column": rv["whole_A_per_column"]["disclosed_dim"],
        "whole_A_with_values_n4": rv["whole_A_with_values_n4"]["disclosed_dim"],
        "whole_H_per_column": rv["whole_H_per_column"]["disclosed_dim"],
    }
    for k, v in mine_rank.items():
        if k in pr:
            cmp(f"rank/{k}", v, pr[k])
    if "whole_H_with_values" in pr:
        cmp("rank/whole_H_with_values",
            {k: v["disclosed_dim"] for k, v in rv.items() if k.startswith("whole_H_with_values")},
            pr["whole_H_with_values"])
    if "endpoints" in pr:
        cmp("rank/endpoints",
            {k: v["disclosed_dim"] for k, v in rv.items() if k.startswith("endpoint_")},
            pr["endpoints"])
    for side in ("A", "H"):
        key = f"groups_{side}"
        if key in pr:
            cmp(f"rank/{key}",
                {k: v["disclosed_dim"] for k, v in rv.items() if k.startswith(f"group_{side}_")},
                pr[key])
    if "singleton_groups" in pr:
        cmp("rank/singleton_groups", rank["singleton_groups"], pr["singleton_groups"])
    if "negative_controls" in pr:
        mine_nc = {k: v["disclosed_dim"] for k, v in rv["negative_controls"].items()}
        theirs_nc = {k: v["disclosed_dim"] for k, v in pr["negative_controls"].items()}
        for k in sorted(set(mine_nc) | set(theirs_nc)):
            cmp_optional(f"rank/negative_control/{k}", mine_nc.get(k), theirs_nc.get(k))

    pf = paper.get("cfs", {})
    if "hosts" in pf:
        for k, v in cfs["host_groups"].items():
            t = pf["hosts"].get(k)
            if t is None:
                diffs.append({"item": f"cfs/host/{k}", "real_source": "present",
                              "paper_schedule": "absent"})
                continue
            cmp(f"cfs/host/{k}", {"sum_L": v["sum_L"], "rank": v["rank_map"],
                                  "dim_S": v["dim_consistency_subspace"],
                                  "kernel": v["kernel_dim_fp2"], "leaked": v["leaked_dim_fp2"]},
                {"sum_L": t["sum_L"], "rank": t["rank"], "dim_S": t["dim_S"],
                 "kernel": t["kernel"], "leaked": t["leaked"]})
    if "standalone" in pf:
        for k, v in cfs["standalone"].items():
            t = pf["standalone"].get(k)
            if t is None:
                diffs.append({"item": f"cfs/standalone/{k}", "real_source": "present",
                              "paper_schedule": "absent"})
                continue
            cmp(f"cfs/standalone/{k}", {"rank": v["rank_map"],
                                        "dim_S": v["dim_consistency_subspace"],
                                        "kernel": v["kernel_dim_fp2"],
                                        "leaked": v["leaked_dim_fp2"]},
                {"rank": t["rank"], "dim_S": t["dim_S"], "kernel": t["kernel"],
                 "leaked": t["leaked"]})
    if "largest_slot" in pf:
        cmp("cfs/largest_slot", cfs["largest_slot"], pf["largest_slot"])
    for k in ("m_rows", "n_functionals"):
        if k in pf:
            cmp(f"cfs/{k}", cfs["m_layout"]["n_rows"] if k == "m_rows"
                else cfs["m_layout"]["n_functionals"], pf[k])
    if "negative_controls" in pf:
        mine_cn = {k: v.get("pass") for k, v in cfs["negative_controls"].items()
                   if isinstance(v, dict) and "pass" in v}
        cmp("cfs/negative_controls", mine_cn, pf["negative_controls"])

    return {"available": True, "n_items": len(same) + len(diffs), "n_agree": len(same),
            "differences": diffs, "agreeing_items": sorted(same),
            "only_in_this_run": only_here,
            "paper_source": f"{PAPER_WHOLE_BLOCK}/zk60_private_block_whole_summary.json",
            "note": "the paper run is a verdict on a MEMO; this run is a verdict on the Rust. "
                    "Any difference is a finding about one of the two, never a tolerance."}


# ---------------------------------------------------------------------------
# 5. the run
# ---------------------------------------------------------------------------


def self_check_accepted(INV, repo: str, out_dir: str, seed: int) -> dict:
    """Step 1: the committed tool, unmodified, on the ACCEPTED attention layout."""
    acc_dir = os.path.join(out_dir, "accepted_selfcheck")
    s = INV.build_all(repo, acc_dir, seed=seed)
    checks = s["derived_vs_note"]
    return {
        "ran": "scripts/zk60_attention_native_inventory.py::build_all on "
               "hashline/src/private_attention/ (no rebinding of ours in force)",
        "out_dir": acc_dir,
        "n_cross_checks": len(checks),
        "n_cross_checks_pass": sum(1 for c in checks if c["pass"]),
        "cross_checks_all_pass": all(c["pass"] for c in checks),
        "failures": s["failures"],
        "all_pass": s["all_pass"],
        "A_sites": s["derived_counts"]["A_sites"], "H_sites": s["derived_counts"]["H_sites"],
        "A_groups": s["derived_counts"]["A_groups_derived"],
        "H_groups": s["derived_counts"]["H_groups_derived"],
        "rank": s["rank_summary"]["negative_controls"],
        "expected": {"n_cross_checks": 29, "failures": []},
        "reproduced_the_accepted_verdict":
            len(checks) == 29 and all(c["pass"] for c in checks) and s["all_pass"]
            and not s["failures"],
    }


def build_all(repo: str, out_dir: str, seed: int = 2026, n_values: int = 4,
              expect: Optional[dict] = None, self_check: bool = True,
              log: Optional[List[str]] = None) -> dict:
    expect = BLOCK_EXPECT if expect is None else expect
    log = [] if log is None else log

    def say(line: str) -> None:
        log.append(line)
        print(line, flush=True)

    scripts_dir = os.path.join(repo, "scripts")
    INV = load_tool(os.path.join(scripts_dir, "zk60_attention_native_inventory.py"),
                    "zk60_attention_native_inventory")
    os.makedirs(out_dir, exist_ok=True)

    # ---- step 1: the self-check on the accepted layout ---------------------
    if self_check:
        sc = self_check_accepted(INV, repo, out_dir, seed)
        say(f"self-check (accepted attention, committed tool unmodified): "
            f"{sc['n_cross_checks_pass']}/{sc['n_cross_checks']} cross-checks, "
            f"failures {sc['failures'] or 'none'}, "
            f"reproduced={sc['reproduced_the_accepted_verdict']}")
    else:
        sc = {"skipped": True, "reproduced_the_accepted_verdict": None}

    # ---- step 2: the real block source -------------------------------------
    mod = os.path.join(repo, "hashline", "src", "private_block")
    with open(os.path.join(mod, "layout.rs")) as f:
        layout_src = f.read()
    with open(os.path.join(mod, "argument.rs")) as f:
        argument_src = f.read()
    with open(os.path.join(mod, "protocol.rs")) as f:
        protocol_src = f.read()

    lay = BlockLayout(INV, layout_src)
    parser = make_block_define_parser(INV)(lay, argument_src)
    sites = parser.parse()
    logup_src, logup_rec = normalise_logup_source(INV, protocol_src, layout_src)

    src_paths = ["hashline/src/private_block/layout.rs",
                 "hashline/src/private_block/argument.rs",
                 "hashline/src/private_block/protocol.rs",
                 "zkp-core/src/pcs.rs"]
    src_sha = {p: INV.sha256_file(os.path.join(repo, p)) for p in src_paths}

    inv = INV.build_inventory(lay, sites, src_sha, repo, protocol_src=logup_src)
    inv["task"] = ("disposition condition 4: the three committed leak-checking tools re-run on "
                   "the REAL Rust of hashline/src/private_block/")
    inv["tool"] = "scripts/zk60_private_block_inventory.py"
    inv["profile"] = {"name": expect["profile"],
                      "geometry": {k: lay.consts[k] for k in ("T", "D", "H", "DH", "KV", "F",
                                                              "LOG_N", "N")},
                      "privacy": "P1 (inputs / outputs / activations hidden; weights public, "
                                 "no W commitment)"}
    inv["source"] = {"layout.rs": src_paths[0], "argument.rs": src_paths[1],
                     "protocol.rs": src_paths[2],
                     "pcs.rs": "zkp-core/src/pcs.rs (zpart_weights / group_zclaims)"}
    inv["adapters"] = ADAPTERS
    inv["caveat"] = CAVEAT
    # the third LogUp table is in the source; the committed builder knows two (adapter B-6)
    tot = block_lookup_totals(INV, lay)
    inv["A1_schedule"]["logup_tables"].append(
        {"table": "act", "table_rows": lay.consts["N"], "required_total": tot["act"],
         "multiplicity_plane": "A_MACT", "helper_plane": "H_GACT",
         "mask_block_rows_if_hidden": 1,
         "mask_kind_under_FA3_rule": "pair (one row at width 256)",
         "note": "committed A row with its own claim site in slot SC_TAB; never published "
                 "(derived by adapter B-6; the committed lookup_total knows U8 and exp only)"})

    checks = block_cross_checks(INV, lay, inv, expect)
    bad = [c for c in checks if not c["pass"]]
    say(f"derived from the real Rust vs the design: "
        f"{len(checks) - len(bad)}/{len(checks)} agree"
        + ("" if not bad else "; MISMATCHES: " + ", ".join(c["name"] for c in bad)))
    for c in checks:
        say(f"  {'ok  ' if c['pass'] else 'FAIL'} {c['name']}: {c['derived']!r}"
            + ("" if c["pass"] else f"   (design: {c['design_says']!r})"))

    with open(os.path.join(out_dir, "zk60_private_block_inventory.json"), "w") as f:
        json.dump(inv, f, indent=1, sort_keys=True, default=str)
        f.write("\n")
    with open(os.path.join(out_dir, "zk60_private_block_hosts.json"), "w") as f:
        json.dump({"variant": "private_block/layout.rs HOSTS",
                   "hosts": inv["A2_cfs_slots"]["hosts"], "extra_slots": {}}, f, indent=1)
        f.write("\n")

    # ---- step 3: the two committed tools ------------------------------------
    rank, schedule, rank_failures = INV.run_rank_tool(inv, lay, scripts_dir, seed,
                                                      n_values=n_values)
    owed, owed_failures = run_owed_controls(INV, inv, lay, seed, n_values=n_values)
    rank["rank_verdicts"]["negative_controls"].update(owed)
    rank["owed_negative_controls"] = sorted(owed)
    rank["failures"] = list(rank["failures"]) + owed_failures
    rank_failures = list(rank_failures) + owed_failures
    cfs, cfs_failures = INV.run_cfs_tool(inv, lay, scripts_dir, out_dir, seed)

    for nm, obj in (("zk60_private_block_pair_schedule.json", rank),
                    ("zk60_private_block_schedule.json", schedule),
                    ("zk60_private_block_cfs_slots.json", cfs)):
        with open(os.path.join(out_dir, nm), "w") as f:
            json.dump(obj, f, indent=1, sort_keys=True, default=str)
            f.write("\n")

    rv = rank["rank_verdicts"]
    lens = [(m + e) * d + 2 for (m, e, d) in lay.slots]
    counts = {
        "a_rows": lay.a_rows, "a_data_rows": lay.a_data_rows,
        "a_site_pair_rows": 2 * sum(lay.a_sites),
        "h_rows": lay.h_rows, "h_data_rows": lay.h_data_rows,
        "h_site_pair_rows": 2 * sum(lay.h_sites),
        "A_sites": sum(lay.a_sites), "H_sites": sum(lay.h_sites),
        "A_groups_derived": inv["A1_schedule"]["group_counts"]["A"],
        "H_groups_derived": inv["A1_schedule"]["group_counts"]["H"],
        "A_GROUPS_declared": lay.consts["A_GROUPS"], "H_GROUPS_declared": lay.consts["H_GROUPS"],
        "n_slots": lay.n_slots, "n_hosts": len(lay.hosts),
        "M_ROWS": lay.consts["M_ROWS"], "N_FUNCTIONALS": lay.consts["N_FUNCTIONALS"],
        "largest_L": max(lens),
        "U8_lookups": tot["U8"], "exp_lookups": tot["exp"], "act_lookups": tot["act"],
        "main_rounds_total": sum(m for m, _e, _d in lay.slots),
        "ext_rounds_total": sum(e for _m, e, _d in lay.slots),
        "sum_main_ext_times_degree_plus_1": sum((m + e) * (d + 1) for m, e, d in lay.slots),
        "terminals": sum(lay.a_sites) + sum(lay.h_sites) + 2,
        "slot_L": {lay.slot_name_of[s]: L for s, L in enumerate(lens)},
        "slot_L_plus_256": {lay.slot_name_of[s]: L + 256 for s, L in enumerate(lens)},
        "hosts_by_index": {h: list(hs) for h, hs in lay.hosts},
        "slot_kinds": {k: sum(1 for x in lay.slot_kinds if x == k)
                       for k in ("Private", "Standalone", "Host")},
    }

    # ---- step 4: the verdict gates the disposition names --------------------
    gates: List[dict] = []

    def gate(name: str, ok: bool, detail) -> None:
        gates.append({"name": name, "pass": bool(ok), "detail": detail})

    a_groups = {k: v["disclosed_dim"] for k, v in rv.items() if k.startswith("group_A_")}
    h_groups = {k: v["disclosed_dim"] for k, v in rv.items() if k.startswith("group_H_")}
    eps = {k: v["disclosed_dim"] for k, v in rv.items() if k.startswith("endpoint_")}
    gate("every A opening group discloses 0", all(v == 0 for v in a_groups.values()),
         {"n_groups": len(a_groups), "nonzero": {k: v for k, v in a_groups.items() if v}})
    gate("every modelled H group discloses 0", all(v == 0 for v in h_groups.values()),
         {"n_groups": len(h_groups), "nonzero": {k: v for k, v in h_groups.items() if v}})
    gate("both endpoints disclose 0", len(eps) == 2 and all(v == 0 for v in eps.values()), eps)
    gate("whole A discloses 0 per column and with values",
         rv["whole_A_per_column"]["disclosed_dim"] == 0
         and rv[f"whole_A_with_values_n{n_values}"]["disclosed_dim"] == 0,
         {"per_column": rv["whole_A_per_column"]["disclosed_dim"],
          "with_values": rv[f"whole_A_with_values_n{n_values}"]["disclosed_dim"]})
    hwv = {k: v for k, v in rv.items() if k.startswith("whole_H_with_values")}
    gate("whole H's residual is EXACTLY the public LogUp identity and nothing more",
         all(v["disclosed_dim"] == 2 and v.get("residual_is_exactly_the_public_identity")
             for v in hwv.values()) and rv["whole_H_per_column"]["disclosed_dim"] == 0,
         {k: {"disclosed_dim": v["disclosed_dim"],
              "residual_is_exactly_the_public_identity":
                  v.get("residual_is_exactly_the_public_identity")} for k, v in hwv.items()})
    hosts_ok = all(v["kernel_dim_fp2"] == expect["host_kernel"] and v["leaked_dim_fp2"] == 0
                   and v["pass"] for v in cfs["host_groups"].values())
    gate(f"every host group has kernel {expect['host_kernel']} and leaks 0, "
         "rank = dim S = sum L - (k + 1)",
         hosts_ok and len(cfs["host_groups"]) == expect["n_hosts"],
         {k: {"sum_L": v["sum_L"], "rank": v["rank_map"],
              "dim_S": v["dim_consistency_subspace"], "kernel": v["kernel_dim_fp2"],
              "leaked": v["leaked_dim_fp2"], "pass": v["pass"]}
          for k, v in cfs["host_groups"].items()})
    gate("host sum L / rank match the design",
         {k: v["sum_L"] for k, v in cfs["host_groups"].items()} == expect["host_sum_L"]
         and {k: v["rank_map"] for k, v in cfs["host_groups"].items()} == expect["host_rank"],
         {"sum_L": {k: v["sum_L"] for k, v in cfs["host_groups"].items()},
          "rank": {k: v["rank_map"] for k, v in cfs["host_groups"].items()}})
    gate("every standalone slot: rank = dim S = N d + 1, leaked 0, kernel 1, and equals "
         "the design",
         all(v["pass"] and v["leaked_dim_fp2"] == 0 and v["kernel_dim_fp2"] == 1
             for v in cfs["standalone"].values())
         and {k: v["dim_consistency_subspace"] for k, v in cfs["standalone"].items()}
         == expect["standalone_dim_S"],
         {k: {"rank": v["rank_map"], "dim_S": v["dim_consistency_subspace"],
              "kernel": v["kernel_dim_fp2"], "leaked": v["leaked_dim_fp2"]}
          for k, v in cfs["standalone"].items()})
    gate("every slot L + 256 <= 512", all(L + 256 <= 512 for L in lens),
         counts["slot_L_plus_256"])
    rank_nc = rv["negative_controls"]
    cfs_nc = {k: v for k, v in cfs["negative_controls"].items()
              if isinstance(v, dict) and "pass" in v}
    nc_fail = ([k for k, v in rank_nc.items() if v["verdict"] != "PASS"]
               + [k for k, v in cfs_nc.items() if not v["pass"]])
    gate("EVERY negative control fires", not nc_fail,
         {"n_rank": len(rank_nc), "n_cfs": len(cfs_nc),
          "n_total": len(rank_nc) + len(cfs_nc), "failed": nc_fail,
          "owed_two": {k: rank_nc[k]["disclosed_dim"] for k in rank["owed_negative_controls"]
                       if k in rank_nc}})
    gate("the self-check reproduced the accepted attention verdict",
         bool(sc.get("reproduced_the_accepted_verdict")) or not self_check,
         sc)

    paper = None
    paper_path = os.path.join(repo, PAPER_WHOLE_BLOCK,
                              "zk60_private_block_whole_summary.json")
    if os.path.exists(paper_path):
        with open(paper_path) as f:
            paper = json.load(f)
    comparison = compare_with_paper(paper, counts, rank, cfs)

    summary = {
        "task": "disposition section 3 condition 4 -- the three committed tools on the REAL "
                "Rust of hashline/src/private_block/",
        "tool": "scripts/zk60_private_block_inventory.py",
        "seed": seed, "n_values": n_values,
        "source_sha256": src_sha,
        "self_check_accepted_attention": sc,
        "adapters": ADAPTERS,
        "adapters_used_by_the_define_parser": parser.adapters_used,
        "adapters_used_note": "how many times each adapter FIRED while interpreting "
                              "argument.rs::define, not how many source sites it covers (one "
                              "statement can be normalised once as a statement and again as an "
                              "integer expression).  B-1: private_block/argument.rs:570 (nine "
                              "loop iterations); B-2: :690, :701, :743, :783 (x2 slots), :797 "
                              "(x2 slots), :822; B-3: :668 (one arm, three slots).",
        "logup_adapter_record": logup_rec,
        "ambiguities": AMBIGUITIES,
        "derived_counts": counts,
        "derived_vs_design": checks,
        "gates": gates,
        "rank_summary": {
            "whole_A_per_column": rv["whole_A_per_column"]["disclosed_dim"],
            f"whole_A_with_values_n{n_values}":
                rv[f"whole_A_with_values_n{n_values}"]["disclosed_dim"],
            "whole_H_per_column": rv["whole_H_per_column"]["disclosed_dim"],
            "whole_H_with_values": {k: v["disclosed_dim"] for k, v in hwv.items()},
            "H_residual_is_exactly_the_public_identity":
                all(v.get("residual_is_exactly_the_public_identity") for v in hwv.values()),
            "endpoints": eps,
            "groups_A": a_groups, "groups_H": h_groups,
            "groups_with_nonzero_disclosure": {k: v for k, v in
                                               {**a_groups, **h_groups}.items() if v},
            "fa2_rank_mask_formula_all_pair_groups": {
                k: v["rank_mask_formula_2m+2n-2+2n"] for k, v in rv.items()
                if k.startswith("group_A_") and "rank_mask_formula_2m+2n-2+2n" in v},
            "n_groups_checked": {"A": len(a_groups), "H": len(h_groups)},
            "singleton_groups": rank["singleton_groups"],
            "schedule_coverage_checks": rank["schedule_coverage_checks"],
            "negative_controls": {k: {"disclosed_dim": v["disclosed_dim"],
                                      "verdict": v["verdict"]} for k, v in rank_nc.items()},
            "owed_negative_controls": rank["owed_negative_controls"],
            "failures": rank_failures,
        },
        "cfs_summary": {
            "n_slots": len(cfs["slot_table"]), "largest_slot": cfs["largest_slot"],
            "standalone": {k: {"rank": v["rank_map"], "dim_S": v["dim_consistency_subspace"],
                               "kernel": v["kernel_dim_fp2"], "leaked": v["leaked_dim_fp2"],
                               "pass": v["pass"]} for k, v in cfs["standalone"].items()},
            "hosts": {k: {"hosted": v["hosted"], "sum_L": v["sum_L"], "rank": v["rank_map"],
                          "dim_S": v["dim_consistency_subspace"],
                          "kernel": v["kernel_dim_fp2"],
                          "expected_kernel": v["expected_kernel_k_plus_1"],
                          "leaked": v["leaked_dim_fp2"], "pass": v["pass"]}
                      for k, v in cfs["host_groups"].items()},
            "m_rows": cfs["m_layout"]["n_rows"],
            "n_functionals": cfs["m_layout"]["n_functionals"],
            "negative_controls": {k: v["pass"] for k, v in cfs_nc.items()},
            "all_checks_pass": cfs["all_checks_pass"], "failures": cfs_failures,
        },
        "paper_comparison": comparison,
        "caveat": CAVEAT,
        "not_established": [
            "No privacy property.  Every verdict is about a linear-algebra model; the models "
            "exclude the sampled columns, the salted Merkle paths, the CFS channel, transcript "
            "conditioning, integer-range side information and A <-> H correlation.",
            "The construction's own gate -- a zero-witness preimage with the same free dimension "
            "as the real witness on every channel, on CAPTURED REAL RECEIPTS -- is unmet.",
            "D8 and D11 stay open for the block's two external endpoints x_in and xres2; D9 "
            "stays pending.",
            "Soundness is not checked here at all: these tools model what an opening DISCLOSES, "
            "not what it BINDS.  The tamper and tripwire tests are the source's own.",
            "The runtime refusal `audit_claims` (a shared reserved pair) is not exercised by the "
            "two owed controls: they mutate the model, not the prover.",
            "No completeness and no speed claim.",
        ],
    }
    summary["findings"] = block_findings(checks, gates, comparison, parser, rank_nc)
    summary["failures"] = ([f"count/{c['name']}" for c in checks if not c["pass"]]
                           + [f"gate/{g['name']}" for g in gates if not g["pass"]]
                           + [f"rank/{x}" for x in rank_failures]
                           + [f"cfs/{x}" for x in cfs_failures])
    summary["all_pass"] = not summary["failures"]
    summary["outputs"] = sorted([
        "accepted_selfcheck/", "zk60_private_block_cfs_slots.json",
        "zk60_private_block_hosts.json", "zk60_private_block_inventory.done",
        "zk60_private_block_inventory.json", "zk60_private_block_inventory.log",
        "zk60_private_block_pair_schedule.json", "zk60_private_block_schedule.json",
        "zk60_private_block_summary.json"])
    summary["outputs_note"] = ("the log and the .done marker are written by `main` after this "
                               "record, so they are named here rather than listed from disk")

    say("rank : " + json.dumps({k: summary["rank_summary"][k] for k in (
        "whole_A_per_column", f"whole_A_with_values_n{n_values}", "whole_H_per_column",
        "whole_H_with_values", "H_residual_is_exactly_the_public_identity", "endpoints",
        "groups_with_nonzero_disclosure", "n_groups_checked", "singleton_groups")},
        default=str))
    say("rank negative controls: " + json.dumps(
        {k: v["disclosed_dim"] for k, v in rank_nc.items()}, default=str))
    say("cfs  : " + json.dumps({"n_slots": len(cfs["slot_table"]),
                                "largest_slot": cfs["largest_slot"]["len"],
                                "m_rows": cfs["m_layout"]["n_rows"],
                                "n_functionals": cfs["m_layout"]["n_functionals"],
                                "hosts": {k: [v["sum_L"], v["rank_map"], v["kernel_dim_fp2"],
                                              v["leaked_dim_fp2"]]
                                          for k, v in cfs["host_groups"].items()},
                                "all_checks_pass": cfs["all_checks_pass"]}, default=str))
    say("cfs negative controls: " + json.dumps(
        {k: v["pass"] for k, v in cfs_nc.items()}, default=str))
    for g in gates:
        say(f"  {'ok  ' if g['pass'] else 'FAIL'} gate: {g['name']}")
    say(f"paper comparison: {comparison.get('n_agree')} of {comparison.get('n_items')} items "
        f"agree; differences: "
        f"{comparison.get('differences') if comparison.get('available') else 'n/a'}; "
        f"only in this run: "
        f"{[x['item'] for x in comparison.get('only_in_this_run', [])]}")
    say(f"adapters the define parser needed: {parser.adapters_used or 'none'}")
    say(f"failures: {summary['failures'] or 'none'}")
    say("CAVEAT: " + CAVEAT)

    with open(os.path.join(out_dir, "zk60_private_block_summary.json"), "w") as f:
        json.dump(summary, f, indent=1, sort_keys=True, default=str)
        f.write("\n")
    summary["log"] = log
    return summary


def block_findings(checks, gates, comparison, parser, rank_nc) -> List[dict]:
    out: List[dict] = []
    bad = [c for c in checks if not c["pass"]]
    out.append({
        "id": "B-F0", "severity": "none" if not bad else "MISMATCH",
        "title": "every derived count against the design "
                 "(TIER2_CHECK section 5.2 / the disposition)",
        "detail": f"{len(checks) - len(bad)} of {len(checks)} agree"
                  + ("" if not bad else "; mismatches: " + ", ".join(c["name"] for c in bad)),
        "mismatches": [{"name": c["name"], "derived_from_the_rust": c["derived"],
                        "design_says": c["design_says"]} for c in bad],
    })
    bg = [g for g in gates if not g["pass"]]
    out.append({
        "id": "B-F1", "severity": "none" if not bg else "BLOCKING",
        "title": "the verdict gates of disposition condition 4",
        "detail": f"{len(gates) - len(bg)} of {len(gates)} pass"
                  + ("" if not bg else "; failed: " + ", ".join(g["name"] for g in bg)),
        "failed": [g["name"] for g in bg],
    })
    out.append({
        "id": "B-F2",
        "severity": "none" if not comparison.get("differences") else "DIFFERENCE",
        "title": "the real Rust against the PAPER whole-block run",
        "detail": ("no difference: every compared item is identical to the memo's run"
                   if comparison.get("available") and not comparison.get("differences")
                   else f"{len(comparison.get('differences', []))} differences"
                   if comparison.get("available") else "the paper run was not found"),
        "differences": comparison.get("differences", []),
        "only_in_this_run": comparison.get("only_in_this_run", []),
    })
    out.append({
        "id": "B-F3", "severity": "parser",
        "title": "constructs of the block's Rust that the committed inventory parser does not "
                 "understand (design decision 14's warning, realised)",
        "detail": "each is handled by a named adapter in THIS driver; no committed script and no "
                  "Rust file was edited",
        "adapters_used": parser.adapters_used,
        "adapters": ADAPTERS,
    })
    owed = {k: v["disclosed_dim"] for k, v in rank_nc.items()
            if "shares" in k or "own_pair_not" in k}
    out.append({
        "id": "B-F4", "severity": "none",
        "title": "the two OWED negative controls (A_H16 sharing A_U16's pair; A_YM sharing "
                 "A_Y's pair) and their positive counterparts",
        "detail": "both sharing controls must disclose >= 2; both own-pair controls must "
                  "disclose 0",
        "measured": owed,
    })
    out.append({
        "id": "B-F5", "severity": "scope",
        "title": "what this run does NOT settle",
        "detail": "the tools are linear-algebraic models at seeded stand-in challenges.  "
                  "Outside them: the sampled columns, the salted Merkle paths, the CFS channel, "
                  "transcript conditioning, integer-range side information, A <-> H correlation, "
                  "the captured-receipt joint-view gate, and D8 / D11.  P3 is not modelled "
                  "because the module does not implement it.  Nothing here is a privacy "
                  "property, and nothing here is a soundness property.",
    })
    return out


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", default=DEFAULT_REPO)
    ap.add_argument("--out-dir", default=DEFAULT_OUT)
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--n-values", type=int, default=4)
    ap.add_argument("--skip-self-check", action="store_true",
                    help="skip step 1 (the accepted-attention control); for debugging only")
    args = ap.parse_args(argv)
    out_dir = args.out_dir if os.path.isabs(args.out_dir) else os.path.join(args.repo,
                                                                           args.out_dir)
    log: List[str] = []
    rc = 1
    try:
        s = build_all(args.repo, out_dir, seed=args.seed, n_values=args.n_values,
                      self_check=not args.skip_self_check, log=log)
        rc = 0 if s["all_pass"] else 1
    except Exception as exc:                                  # noqa: BLE001 - recorded, re-raised
        log.append(f"EXCEPTION: {type(exc).__name__}: {exc}")
        os.makedirs(out_dir, exist_ok=True)
        with open(os.path.join(out_dir, "zk60_private_block_inventory.log"), "w") as f:
            f.write("\n".join(log) + "\n")
        with open(os.path.join(out_dir, "zk60_private_block_inventory.done"), "w") as f:
            f.write("2\n")
        raise
    with open(os.path.join(out_dir, "zk60_private_block_inventory.log"), "w") as f:
        f.write("\n".join(log) + "\n")
    with open(os.path.join(out_dir, "zk60_private_block_inventory.done"), "w") as f:
        f.write(f"{rc}\n")
    return rc


if __name__ == "__main__":
    sys.exit(main())
