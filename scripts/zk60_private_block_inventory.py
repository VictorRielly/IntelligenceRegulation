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
     with the committed tool's own `Layout`, `DefineParser` and `parse_logup_sum`, through ten
     small, named adapters (see `ADAPTERS`) for the constructs the block's Rust uses and the
     accepted component's Rust does not.  NOTHING under `scripts/` is edited and NO Rust file is
     touched; every adapter is a subclass or a source-level normalisation driven by what
     `layout.rs` itself says.

     STAGE 10 (2026-09-20).  The lane `zk60-private-block-125m` rewrote those three files over a
     `Shape`, and every construct the parser was anchored on moved: `Dom::log` and `lookups` are
     no longer matches, `define`'s axis logs moved into a preamble the committed parser does not
     run, its arms speak `ids.at(..)` / `hids.first_helper(..)` / `sh.log(..)`, and
     `logup_sum_claim` signs with `hids.is_table(p)`.  Adapters B-7..B-10 read the TOY PROFILE
     out of the shaped source and rewrite each construct into the spelling the committed parser
     reads; B-1..B-4 and B-6 are re-pinned to the new line numbers, with the old ones on record
     in their own entries.  Every number this driver prints for the toy is unchanged, key by
     key, against the record made before the lane -- that comparison is
     `results/zk60_block125m_lane/s10-evidence-comparison.txt`.  A twelfth gate compares the toy
     profile with the independent model `scripts/zk60_private_block_layout_model.py`.  The tool
     still speaks about the TOY alone; there is no `--shape` and the ledger says why.
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
    "B-1  `Layout.limb_off_m` -- hashline/src/private_block/layout.rs:1149-1151 adds a second "
    "limb base (`a_off[ids.at(A_LIMBM)] + k * sh.t_pad`, norm_m's limbs) beside `limb_off`, and "
    "private_block/argument.rs:935 calls it inside a site: "
    "`b.a_slice(lay.limb_off_m(kk), lt, rho(0..lt), 0)`.  The committed `Layout` class has no "
    "such method and the committed `DefineParser._int` substitutes only `lay.limb_off(..)`.  "
    "ADAPTER: `BlockLayout` (a subclass) adds `limb_off_m` with exactly layout.rs's arithmetic, "
    "and `BlockDefineParser._int` substitutes `lay.limb_off_m(k)` with it before delegating.  "
    "No value is assumed: the plane index comes from the parsed consts and `t_pad` from the "
    "toy profile B-7 derives.  [PIN re-read 2026-09-20 after the shape generalisation: "
    "layout.rs:647 -> :1149-1151, argument.rs:570 -> :935; the arithmetic is the same at the "
    "toy, where `ids.at` is the identity and `t_pad == T`.]",

    "B-2  receiver-qualified `lay.helpers(..)` -- the accepted argument.rs calls the free "
    "function `helpers(Dom::D).1` (private_attention/argument.rs:613, :621, :652, :666, :691); "
    "the block USED TO call the method `lay.helpers(Dom::D).1`.  ADAPTER: `BlockDefineParser` "
    "rewrites the exact token `lay.helpers(` to `helpers(` in each statement and expression "
    "before delegating.  [STATUS 2026-09-20: NOT EXERCISED any more, and kept only so that a "
    "revert would still parse.  The shape generalisation replaced every one of those calls "
    "with `sh.helpers(Dom::D)`, which returns the COUNT alone and is rewritten by B-9 instead; "
    "`lay.helpers(` occurs zero times in private_block/argument.rs.  `adapters_used` no longer "
    "reports B-2, and that is the evidence for this line.]",

    "B-3  `let <name> = if <cond> { <challenge> } else { <point>.clone() }` -- "
    "private_block/argument.rs:1084, `let r_row = if slot == SC_DMM { tr.challenge_fp2_vec(lt) "
    "} else { pts.r_tf.clone() };`, the one construct the feed-forward matmul arm needs and the "
    "accepted source never uses (the committed parser handles only the TUPLE form "
    "`let (a, b) = if flag {..} else {..}` and only with a bool local as the condition).  "
    "ADAPTER: `BlockDefineParser._statement` evaluates the condition with the committed "
    "`_cond`, takes the live branch and binds a challenge vector or a `pts.X` / `pts.X.clone()` "
    "vector; anything else falls through to the committed parser unchanged.  The bound symbols "
    "are `SC_DMM.r_row[i]` (the Rust local's own name), distinct from `SC_GMM.r_tf[i]`, which is "
    "what the PCS grouping keys on.",

    "B-4  `protocol.rs::logup_sum_claim` indirections -- the accepted source loops "
    "`for p in 0..N_H` and signs with `if p == H_GU8 || p == H_GEXP`; the block "
    "(private_block/protocol.rs:143-144) loops `for p in lay.h_planes()` and signs with "
    "`if hids.is_table(p)`.  The committed `parse_logup_sum` refuses the first and silently "
    "reads an EMPTY negated set from the second.  ADAPTER: `normalise_logup_source` resolves "
    "BOTH indirections out of layout.rs itself and rewrites those two lines into the spelling "
    "the committed parser understands, so that all of its own assertions (`point: vec![]`, "
    "`value: Fp2::ZERO`, loop range == N_H) still run.  Both forms are asserted, not assumed; "
    "an unexpected body is a hard parse error.  [PINS re-read 2026-09-20 after the shape "
    "generalisation.  protocol.rs:54-55 -> :143-144.  `fn h_planes` read `(0..N_H).collect()` "
    "at layout.rs:615-617 and now reads `(0..self.hids.n_h()).collect()` at :1117-1119, so the "
    "loop bound is taken as `N_H` on the strength of `Layout::new`'s own freeze gate "
    "`assert_eq!(lay.hids.n_h(), N_H, ..)` (layout.rs:985), which this adapter requires to be "
    "present and which grow_tests.rs:858 asserts again on `HIds::new(&Shape::toy())`.  The "
    "sign test moved from the free `h_is_table(p)` to the shape-driven `hids.is_table(p)`, "
    "whose body must read `(self.gu8..self.gu8 + 3).contains(&plane)` (layout.rs:549-551); the "
    "three PLANE NAMES are still read out of `fn h_is_table`'s `matches!(plane, ...)`, which "
    "survives at layout.rs:437-439, and grow_tests.rs:872 asserts the two agree on every plane "
    "at the toy.]",

    "B-5  the two OWED negative controls re-use the committed rank tool with its accepted "
    "rebinding: after `INV.run_rank_tool` returns, the already-rebound module instance is taken "
    "from `sys.modules['zk60_attention_pair_schedule']` and its own `build_schedule` / "
    "`a_model_groups(share_mask=...)` / `build_model` / `analyze_fast` are called again.  No "
    "constant is rebound a second time and no tool function is redefined.",

    "B-6  the activation table's lookup total.  The committed `lookup_total` knows two tables "
    "(U8 by summing `lookups(dom)` over `LOOKUP_DOMS`, exp as `1 << Dom::S.log()`).  The block "
    "has a third, the activation table (private_block/argument.rs:1216 `f_act`, one lookup per "
    "`Dom::F` element).  `block_lookup_totals` adds `act = 1 << Dom::F.log()` by exactly the "
    "committed tool's own convention for exp.  The U8 and exp totals are the committed "
    "function's, unchanged.  [PIN re-read 2026-09-20: argument.rs:766 -> :1216.]",

    "B-7  `Dom::log` no longer HOLDS the domain logs (step S6).  layout.rs:160-162 delegates to "
    "`domain_log_at(self.natural_log(), self.carries_h_planes(), LOG_N)`, and the committed "
    "`parse_dom_logs` reads a `match` that is no longer there -- this is the immediate cause of "
    "the nine errors finding S9-F6 reported.  ADAPTER: `normalise_layout_source` requires "
    "`Dom::log`'s body to be EXACTLY that call and `domain_log_at`'s body (layout.rs:136-142) "
    "to be exactly the ruling-P-3 lift `if carries_h_planes && natural < log_n { log_n } else "
    "{ natural }`; it then runs the COMMITTED arm parser on `natural_log`'s own match "
    "(layout.rs:146-155), reads the domains that carry no H plane out of `carries_h_planes`'s "
    "`!matches!(self, ..)` (layout.rs:157-159) and `LOG_N` out of the consts, applies the lift "
    "in Python and rewrites `Dom::log`'s body into the literal match the committed parser "
    "reads.  At the toy the lift moves nothing (`lifted_by_P3` is empty) and the nine logs are "
    "the nine the accepted run recorded.  The same function derives the TOY PROFILE that "
    "adapters B-1 and B-9 need -- the six axis logs, inverted from the nine natural logs by "
    "`shape.rs:390-404`'s rule, and the three byte-limb counts, by `shape.rs:372-386`'s rule "
    "on layout.rs's own `NORM_WRHO` / `WRHO_S` / `F_P`.  Ten cross-checks travel with it, and "
    "any of them failing is a hard parse error, not a warning: the three domains the inversion "
    "does not consume, the six frozen toy geometry constants `T` / `D` / `H` / `DH` / `F` / "
    "`KV`, which no longer drive anything in layout.rs and are now only a witness, and the "
    "pinned `LN_TOY` / `LS_TOY` / `LP_TOY` (layout.rs:281-283).",

    "B-8  `lookups(dom)` is now `lookups_at(&Shape::toy(), &Ids::toy(), dom)` (layout.rs:643-"
    "645), whose match arms are written over the shape: `(0..ln).map(..)` for a limb group and "
    "`if norm_top { .. }` for correction C-6's four droppable `scaled` lookups.  The committed "
    "`parse_lookup_counts` handles neither.  ADAPTER: `normalise_layout_source` requires "
    "`lookups`'s body to be exactly that call and `lookups_at` (layout.rs:667-742) to bind "
    "`let (ln, ls, lp) = (ids.ln, ids.ls, ids.lp);` and `let norm_top = "
    "!sh.norm_top_is_full_byte();`, substitutes the TOY's `ln` / `ls` / `lp` and resolves the "
    "`if norm_top` blocks (true at the toy, `NORM_WRHO = 29` against `8 * 4`), then hands the "
    "result to the COMMITTED counter, which still does all the counting "
    "(`v.push` = 1, `v.extend([..])` = the list's length, `sym(..)` = 2, `(0..k).map(..)` = k). "
    "An `else` branch or an unknown condition appearing in `lookups_at` is a hard parse error.",

    "B-9  the shaped spellings inside `argument::define`.  Nine kinds of expression changed "
    "their spelling without changing their value at the toy, and `normalise_define_source` "
    "rewrites each one, inside `define`'s body alone, into the spelling the committed "
    "`DefineParser` already reads: `ids.at(P)` -> `P` and `ids.nr(k)`..`ids.sg(k)` -> their "
    "toy base plus `k` (the toy's id map is the identity -- `Layout::new`'s freeze gate, "
    "layout.rs:987, `assert!((0..N_A).all(|p| lay.ids.at(p) == p))`); `hids.first_helper(D)`, "
    "`hids.helper(D, j)`, `hids.sexp()`, `hids.fact()`, `hids.u()` and `hids.table_helpers()` "
    "-> the literal helper planes of `fn helpers` and the `H_*` constants, which "
    "grow_tests.rs:855-877 asserts one by one on `HIds::new(&Shape::toy())`; `sh.helpers(D)` "
    "-> `helpers(D).1`; `sh.log(D)` -> `D.log()`; `sh.size(D)` -> `1 << D.log()`; "
    "`sh.limbs_*()` and the six `sh.<axis>` fields -> the toy profile's values; and `lg(v)` -> "
    "`v.trailing_zeros()` (argument.rs:592-595).  Four small evaluator extensions go with it, "
    "all of them forms the accepted source never uses: `helpers(D).0` (the FIRST helper plane; "
    "the committed `_int` substitutes only the pair's second member), a list-valued local "
    "indexed by a literal (`th[0]`), an `if` EXPRESSION in integer position "
    "(`rho(0..if slot == SC_DMM { lf } else { ld })`), a local sliced to a prefix "
    "(`fixed(&r_h[..lkv])`), an integer-valued `let`, and a tuple-match arm whose value is an "
    "integer expression.  Every substituted value is the toy's and comes from B-7's profile; "
    "no count, row or plane is assumed.",

    "B-10  `define`'s preamble is outside the parsed region.  The committed `parse()` runs the "
    "`match slot` arms only, and the shape generalisation moved the axis logs, the byte-limb "
    "counts and the pad-rule flags into a preamble above that match (argument.rs:873-891).  "
    "ADAPTER: `BlockDefineParser._statement` binds those eleven locals into each arm's "
    "environment at the toy's values before the first statement runs -- `lt` / `lh` / `ldh` / "
    "`ld` / `lf` / `lkv` from B-7's axis logs, `ln` / `ls` / `lp` from B-7's limb counts, and "
    "`pad_on = false` / `n_pad = 0`, which is what `Shape::toy()` gives: `pad.rs:365-368` "
    "returns no zero-rule plane unless `Shape::carries_pad_rule` (`shape.rs:360-362` is "
    "`!is_frozen_toy`, `shape.rs:367-369` is `profile == TOY_PROFILE`), so `define`'s "
    "`pad_doms` is empty, ruling P-1's pad term is absent and `B::supp` "
    "(argument.rs:543-547) returns `None` on every domain.  The pad branches this switches off "
    "contain no site call at all, so the committed `_run_arm`'s own "
    "`consumed == expected_calls` check still covers every site the arm makes.",
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


# ---------------------------------------------------------------------------
# 1b. the shaped source: paren-balanced call rewriting
# ---------------------------------------------------------------------------


def _match_paren(src: str, i: int) -> int:
    """Index of the `)` closing the `(` at `src[i]`."""
    depth = 0
    for j in range(i, len(src)):
        if src[j] in "([{":
            depth += 1
        elif src[j] in ")]}":
            depth -= 1
            if depth == 0:
                return j
    raise ValueError("unbalanced parenthesis")


def _rewrite_call(src: str, name: str, fmt) -> Tuple[str, int]:
    """Replace every call `name(<args>)` by `fmt(<args>)`, matching the parenthesis instead of a
    regex so that nested calls and `if .. {} else {}` arguments survive.  `name` must be preceded
    by a character that cannot continue an identifier (so `ids.at(` never matches `hids.at(`)."""
    out, n, i = src, 0, 0
    while True:
        j = out.find(name + "(", i)
        if j < 0:
            return out, n
        if j > 0 and (out[j - 1].isalnum() or out[j - 1] == "_"):
            i = j + 1
            continue
        k = _match_paren(out, j + len(name))
        rep = fmt(out[j + len(name) + 1:k])
        out = out[:j] + rep + out[k + 1:]
        i, n = j + len(rep), n + 1


def _fn_body_span(INV, src: str, name: str) -> Tuple[int, int, str]:
    """(index of the body's `{`, index after its `}`, the body) of `fn name`."""
    m = re.search(r"fn\s+" + re.escape(name) + r"\s*(<[^>]*>)?\s*\(", src)
    if not m:
        raise INV.RustParseError(f"function {name} not found")
    i = src.index("{", m.end())
    inner, end = INV.brace_block(src, i)
    return i, end, inner


# ---------------------------------------------------------------------------
# 1c. adapters B-7 / B-8: layout.rs over a Shape
# ---------------------------------------------------------------------------

# `Dom::log` delegates to these two, which must read EXACTLY this or the adapter refuses.
_LOG_BODY = "domain_log_at(self.natural_log(), self.carries_h_planes(), LOG_N)"
_LIFT_BODY = "if carries_h_planes && natural < log_n { log_n } else { natural }"
_LOOKUPS_BODY = "lookups_at(&super::shape::Shape::toy(), &Ids::toy(), dom)"


def toy_axis_logs(natural: Dict[str, int]) -> Dict[str, int]:
    """The toy's six AXIS logs, inverted from the nine domain logs.

    `shape.rs:390-404` gives every domain's natural log as `clog2` of a product of PADDED axes,
    and every padded axis is a power of two by construction (`shape.rs:147-148` pads `tokens`,
    `width`, `q_heads` and `hidden` up to a power of two; `shape.rs:151` refuses a `head_dim`
    that is not one; `shape.rs:175` refuses a `kv_heads` that does not divide the power-of-two
    `h_pad`, so it is one too).  The nine logs therefore SUM the axis logs exactly and the
    system inverts, with `Dom::L`, `Dom::S` and `Dom::Tab` left over as three checks."""
    lt = natural["T"]                        # clog2(t_pad)
    lh = natural["Ht"] - lt                  # clog2(h_pad * t_pad)
    ld = natural["D"] - lt                   # clog2(t_pad * d_pad)
    lf = natural["F"] - lt                   # clog2(t_pad * f_pad)
    ldh = natural["Q"] - lt - lh             # clog2(t_pad * h_pad * head_dim)
    lkv = natural["Kv"] - lt - ldh           # clog2(t_pad * kv_heads * head_dim)
    axes = {"lt": lt, "lh": lh, "ldh": ldh, "ld": ld, "lf": lf, "lkv": lkv}
    if any(v < 0 for v in axes.values()):
        raise ValueError(f"the toy's axis logs do not invert: {axes}")
    return axes


def block_toy_profile(INV, layout_src_stripped: str, consts: Dict[str, int],
                      natural: Dict[str, int]) -> dict:
    """Adapter B-7's record: everything `argument::define` reads off `Shape::toy()`, derived
    from layout.rs and cross-checked against the frozen toy constants."""
    axes = toy_axis_logs(natural)
    lt = axes["lt"]
    # the three byte-limb counts, by shape.rs:372-386's rule on layout.rs's own windows
    # (`NORM_WRHO` layout.rs:65, `WRHO_S` :74, `F_P` :72; grow_tests.rs:428 asserts that the
    # toy shape's own windows ARE these two module constants)
    ln = -(-consts["NORM_WRHO"] // 8)
    ls = -(-consts["WRHO_S"] // 8)
    lp = -(-(consts["F_P"] + 1) // 8)
    pinned = (consts["LN_TOY"], consts["LS_TOY"], consts["LP_TOY"])   # layout.rs:281-283
    if (ln, ls, lp) != pinned:
        raise INV.RustParseError(
            f"the toy's byte-limb counts derived from the windows {(ln, ls, lp)} differ from the "
            f"pinned LN_TOY / LS_TOY / LP_TOY {pinned}")
    checks = [
        # the three domains the axis inversion does not consume (shape.rs:392, :397, :400)
        ("Dom::L is 16 limb sub-planes of t_pad", natural["L"], 4 + lt),
        ("Dom::S is h_pad * t_pad * t_pad", natural["S"], axes["lh"] + 2 * lt),
        ("Dom::Tab is the byte class", natural["Tab"], (consts["U8_LEN"] - 1).bit_length()),
        # the frozen toy geometry constants, which no longer drive anything in layout.rs
        ("t_pad == T", 1 << lt, consts["T"]),
        ("d_pad == D", 1 << axes["ld"], consts["D"]),
        ("h_pad == H", 1 << axes["lh"], consts["H"]),
        ("head_dim == DH", 1 << axes["ldh"], consts["DH"]),
        ("f_pad == F", 1 << axes["lf"], consts["F"]),
        ("kv_heads * head_dim == KV", 1 << (axes["lkv"] + axes["ldh"]), consts["KV"]),
        ("norm_wrho fills no whole limb", consts["NORM_WRHO"] != 8 * ln, True),
    ]
    bad = [(n, g, w) for n, g, w in checks if g != w]
    if bad:
        raise INV.RustParseError(f"the toy profile derived from layout.rs is not the frozen "
                                 f"one: {bad}")
    # `pad_on` / `n_pad`: `pad.rs:365-368` returns NO zero-rule plane unless
    # `Shape::carries_pad_rule` (`shape.rs:360-362` = `!is_frozen_toy`, and
    # `shape.rs:367-369` is `profile == TOY_PROFILE`), so `define`'s `pad_doms` is empty and
    # `B::supp` (`argument.rs:543-547`) returns `None` at the toy, on every domain.  Those two
    # files are NOT among the three this driver parses, so the assumption is checked by its
    # OBSERVABLE CONSEQUENCE instead: a slot whose relation the support indicator gates gains
    # one degree, and `model_cross_check` compares layout.rs's own declared `SLOTS` degrees
    # with the model's, which carries no indicator at the toy.  A toy that had started to
    # carry the pad rule would fail that gate.
    return {"axis_logs": axes, "ln": ln, "ls": ls, "lp": lp,
            "norm_top": consts["NORM_WRHO"] != 8 * ln,
            "pad_on": False, "n_pad": 0,
            "cross_checks": [{"name": n, "derived": g, "declared": w} for n, g, w in checks]}


def normalise_layout_source(INV, layout_src: str) -> Tuple[str, dict]:
    """Adapters B-7 and B-8: rewrite the two shape-driven functions of `layout.rs` into the
    spelling the committed `Layout` understands, resolving both out of layout.rs itself.
    Returns (source, record)."""
    s = INV.strip_comments(layout_src)
    consts = INV.parse_scalar_consts(s)
    rec: Dict[str, object] = {}

    # --- B-7: `Dom::log` no longer holds the logs; it lifts `natural_log`'s.
    body = INV.fn_body(s, "log").strip()
    if body != _LOG_BODY:
        raise INV.RustParseError(f"layout.rs::Dom::log has an unexpected body {body!r}; "
                                 "adapter B-7 refuses to guess the domain logs")
    lift = " ".join(INV.fn_body(s, "domain_log_at").split())
    if lift != _LIFT_BODY:
        raise INV.RustParseError(f"layout.rs::domain_log_at has an unexpected body {lift!r}; "
                                 "adapter B-7 refuses to guess the P-3 lift")
    # the committed arm parser itself reads `natural_log`'s match, unchanged
    natural = INV.parse_dom_logs("fn log(self) -> usize {" + INV.fn_body(s, "natural_log") + "}")
    carries = INV.fn_body(s, "carries_h_planes").strip()
    mc = re.match(r"^!matches!\(\s*self\s*,\s*(.+?)\s*\)$", carries, re.S)
    if not mc:
        raise INV.RustParseError(f"layout.rs::carries_h_planes has an unexpected body "
                                 f"{carries!r}; adapter B-7 refuses to guess which domains "
                                 "carry H planes")
    no_h = [x.strip()[5:] for x in mc.group(1).split("|")]
    if any(d not in natural for d in no_h):
        raise INV.RustParseError(f"carries_h_planes names a domain natural_log does not: {no_h}")
    log_n = consts["LOG_N"]
    logs = {d: (log_n if (d not in no_h and v < log_n) else v) for d, v in natural.items()}
    rec["B-7"] = {"natural_logs": natural, "domains_without_h_planes": sorted(no_h),
                  "LOG_N": log_n, "logs": logs,
                  "lifted_by_P3": sorted(d for d in logs if logs[d] != natural[d])}
    i, end, _ = _fn_body_span(INV, s, "log")
    s = (s[:i] + "{ match self { "
         + " ".join(f"Dom::{d} => {v}," for d, v in logs.items()) + " } }" + s[end:])

    toy = block_toy_profile(INV, s, consts, natural)
    rec["B-7"]["toy_profile"] = toy

    # --- B-8: `lookups(dom)` is the same list at the TOY shape.
    body = INV.fn_body(s, "lookups").strip()
    if body != _LOOKUPS_BODY:
        raise INV.RustParseError(f"layout.rs::lookups has an unexpected body {body!r}; "
                                 "adapter B-8 refuses to guess the lookup list")
    at = INV.fn_body(s, "lookups_at")
    pre = " ".join(at[:at.index("match dom")].split())
    for want in ("let (ln, ls, lp) = (ids.ln, ids.ls, ids.lp);",
                 "let norm_top = !sh.norm_top_is_full_byte();"):
        if want not in pre:
            raise INV.RustParseError(f"layout.rs::lookups_at does not bind {want!r}; adapter "
                                     "B-8 refuses to guess what its locals mean")
    j = at.index("{", at.index("match dom"))
    inner = INV.brace_block(at, j)[0]
    env = {"norm_top": toy["norm_top"]}
    resolved = []
    while True:
        m = re.search(r"\bif\s+(\w+)\s*\{", inner)
        if not m:
            break
        blk, after = INV.brace_block(inner, m.end() - 1)
        if inner[after:].lstrip().startswith("else"):
            raise INV.RustParseError("adapter B-8: `lookups_at` grew an `else` branch")
        if m.group(1) not in env:
            raise INV.RustParseError(f"adapter B-8: unknown condition {m.group(1)!r} in "
                                     "`lookups_at`")
        resolved.append([m.group(1), env[m.group(1)]])
        inner = inner[:m.start()] + (blk if env[m.group(1)] else "") + inner[after:]
    for nm in ("ln", "ls", "lp"):
        inner = inner.replace(f"(0..{nm})", f"(0..{toy[nm]})")
    rec["B-8"] = {"limbs": {k: toy[k] for k in ("ln", "ls", "lp")},
                  "norm_top": toy["norm_top"], "conditions_resolved": resolved}
    i, end, _ = _fn_body_span(INV, s, "lookups")
    s = s[:i] + "{ match dom { " + inner + " } }" + s[end:]
    return s, rec


# ---------------------------------------------------------------------------
# 1d. adapter B-9: `argument::define` over a Shape
# ---------------------------------------------------------------------------


def normalise_define_source(INV, lay, argument_src: str) -> Tuple[str, dict]:
    """Adapter B-9: rewrite the shaped spellings inside `define`'s body into the ones the
    committed `DefineParser` reads.  Every value substituted is the TOY's, taken from the
    layout the parser has already read; nothing outside `define` is touched."""
    s = INV.strip_comments(argument_src)
    toy = lay.block_toy
    ax = toy["axis_logs"]
    i, end, body = _fn_body_span(INV, s, "define")
    rec: Dict[str, int] = {}

    def note(key: str, n: int) -> None:
        if n:
            rec[key] = rec.get(key, 0) + n

    def first_helper(dom: str) -> str:
        return lay.helpers[dom][0]

    # the id maps are the identity at the toy (`Layout::new`'s freeze gate, layout.rs:987:
    # `assert!((0..N_A).all(|p| lay.ids.at(p) == p))`), so `Ids::at` is a no-op and the six
    # growing groups start at their own toy constants (`Ids::nr`..`Ids::sg`, layout.rs:374-393)
    body, n = _rewrite_call(body, "ids.at", lambda a: a.strip())
    note("B-9/ids.at", n)
    for meth, base in (("nr", "A_NR0"), ("ns", "A_NS0"), ("mr", "A_MR0"), ("ms", "A_MS0"),
                       ("pl", "A_PL0"), ("sr", "A_SR0")):
        body, n = _rewrite_call(body, f"ids.{meth}", lambda a, b=base: f"({b} + {a})")
        note("B-9/ids.limb-group", n)
    body, n = _rewrite_call(body, "ids.sg",
                            lambda a: f"(A_SR0 + {toy['ls']} + {a})")
    note("B-9/ids.limb-group", n)

    # the H helper accessors (`HIds`, layout.rs:508-549).  At the toy each one is the literal
    # plane the accepted source named, asserted plane by plane in
    # grow_tests.rs:855-877 (`the_h_plane_ids_are_the_toys_at_the_toy_and_each_shapes_elsewhere`)
    body, n = _rewrite_call(body, "hids.first_helper", lambda a: f"helpers({a}).0")
    note("B-9/hids.first_helper", n)

    def _helper(args: str) -> str:
        dom, k = INV.split_top(args, ",")
        return f"(helpers({dom}).0 + {k})"

    body, n = _rewrite_call(body, "hids.helper", _helper)
    note("B-9/hids.helper", n)
    for meth, name in (("sexp", "H_SEXP"), ("fact", "H_FACT"), ("u", "H_U")):
        body, n = _rewrite_call(body, f"hids.{meth}", lambda a, nm=name: nm)
        note("B-9/hids.named-helper", n)
    body, n = _rewrite_call(body, "hids.table_helpers",
                            lambda a: "[H_GU8, H_GEXP, H_GACT]")
    note("B-9/hids.table_helpers", n)

    # the shape's own accessors
    body, n = _rewrite_call(body, "sh.helpers", lambda a: f"helpers({a}).1")
    note("B-9/sh.helpers", n)
    body, n = _rewrite_call(body, "sh.size", lambda a: f"(1 << {a}.log())")
    note("B-9/sh.size", n)
    body, n = _rewrite_call(body, "sh.log", lambda a: f"{a}.log()")
    note("B-9/sh.log", n)
    for meth, val in (("limbs_norm", toy["ln"]), ("limbs_sigma_s", toy["ls"]),
                      ("limbs_p", toy["lp"])):
        body, n = _rewrite_call(body, f"sh.{meth}", lambda a, v=val: str(v))
        note("B-9/sh.limbs", n)
    for field, lg in (("t_pad", ax["lt"]), ("d_pad", ax["ld"]), ("h_pad", ax["lh"]),
                      ("f_pad", ax["lf"]), ("head_dim", ax["ldh"]), ("kv_heads", ax["lkv"])):
        pat = re.compile(r"(?<![\w.])sh\." + field + r"\b")
        body, n = pat.subn(str(1 << lg), body)
        note("B-9/sh.axis", n)
    # `lg` is `trailing_zeros` (argument.rs:592-595), which the committed `_int` already knows
    body, n = _rewrite_call(body, "lg", lambda a: f"{a.strip()}.trailing_zeros()")
    note("B-9/lg", n)
    return s[:i] + "{" + body + "}" + s[end:], rec


class BlockLayout:
    """`INV.Layout` for the block source, plus adapters B-1, B-7 and B-8."""

    def __new__(cls, INV, src: str):
        normalised, rec = normalise_layout_source(INV, src)
        lay = INV.Layout(normalised)
        lay.block_toy = rec["B-7"]["toy_profile"]
        lay.block_layout_adapters = rec
        lay.limb_off_m = _make_limb_off_m(lay)
        return lay


def _make_limb_off_m(lay):
    # layout.rs:1149-1151: `self.a_off[self.ids.at(A_LIMBM)] + k * self.sh.t_pad`, which at the
    # toy is `a_off[A_LIMBM] + k * T` (the id map is the identity and `t_pad == T`, both
    # asserted in `block_toy_profile`).
    t_pad = 1 << lay.block_toy["axis_logs"]["lt"]

    def limb_off_m(k: int) -> int:
        return lay.a_off[lay.consts["A_LIMBM"]] + k * t_pad
    return limb_off_m


def make_block_define_parser(INV):
    """`INV.DefineParser` + adapters B-1, B-2, B-3, B-9 and B-10.  Built inside a function so
    the committed module is imported by path exactly once, by the caller."""

    class BlockDefineParser(INV.DefineParser):
        def __init__(self, lay, src: str):
            super().__init__(lay, src)
            self.adapters_used: Dict[str, int] = {}
            self.src, rewrites = normalise_define_source(INV, lay, self.src)
            self.rewrites = rewrites
            if rewrites:
                self.adapters_used["B-9"] = sum(rewrites.values())
            # B-10: `define`'s preamble (argument.rs:873-891) is OUTSIDE the `match slot` block
            # the committed `parse()` runs, so its locals are bound here instead, at the toy's
            # own values.  `pad_on` is false at the toy by pad.rs:365-368 (see
            # `block_toy_profile`), which is also why `B::supp` adds no table and the pad
            # branches carry no site call.
            ax = lay.block_toy["axis_logs"]
            self.preamble = {"lt": ax["lt"], "lh": ax["lh"], "ldh": ax["ldh"], "ld": ax["ld"],
                             "lf": ax["lf"], "lkv": ax["lkv"], "ln": lay.block_toy["ln"],
                             "ls": lay.block_toy["ls"], "lp": lay.block_toy["lp"],
                             "n_pad": lay.block_toy["n_pad"],
                             "pad_on": lay.block_toy["pad_on"]}

        def _note(self, key: str) -> None:
            self.adapters_used[key] = self.adapters_used.get(key, 0) + 1

        # ---- B-1 / B-2 / B-9 ---------------------------------------------
        def _int(self, expr, env):
            e = str(expr)
            # B-9: an `if` EXPRESSION in integer position (`rho(0..if slot == SC_DMM {..})`)
            mi = re.match(r"^if\s+(.+?)\s*\{\s*([^{}]+?)\s*\}\s*else\s*\{\s*([^{}]+?)\s*\}$",
                          e.strip(), re.S)
            if mi:
                self._note("B-9")
                e = (mi.group(2) if self._cond(mi.group(1), env, env.get("slot", -1))
                     else mi.group(3))
            # B-9: a list-valued local indexed by a literal (`th[0]`, the table helpers)
            def _idx(m):
                v = env.get(m.group(1))
                if isinstance(v, list) and all(isinstance(x, int) for x in v):
                    return str(v[int(m.group(2))])
                return m.group(0)
            e2 = re.sub(r"(?<![\w.\]])(\w+)\[(\d+)\]", _idx, e)
            if e2 != e:
                self._note("B-9")
                e = e2
            # B-9: `helpers(Dom::X).0` / `helpers(dom).0`, the FIRST helper plane of a domain.
            # The committed `_int` substitutes only the pair's second member, the count.
            def _first(m):
                dom = m.group(1)
                if dom.startswith("Dom::"):
                    dom = dom[5:]
                else:
                    dom = self._dom_of(dom, env)
                return str(self.lay.consts[self.lay.helpers[dom][0]])
            e2 = re.sub(r"helpers\((Dom::\w+|\w+)\)\.0", _first, e)
            if e2 != e:
                self._note("B-9")
                e = e2
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

        # ---- B-9: a local sliced to a prefix (`&r_h[..lkv]`) -------------
        def _sym_vec(self, expr: str, env: Dict):
            m = re.match(r"^(\w+)\[\.\.(.+)\]$", expr.strip())
            if m and isinstance(env.get(m.group(1)), list):
                self._note("B-9")
                return list(env[m.group(1)])[:self._int(m.group(2), env)]
            return super()._sym_vec(expr, env)

        # ---- B-9: a tuple-match value that is an integer expression ------
        def _tuple_value(self, v: str, env: Dict):
            e = v.strip()
            if not e.startswith("Dom::") and e not in self.lay.consts:
                merged = dict(self.lay.consts)
                merged.update({k: x for k, x in env.items()
                               if isinstance(x, int) and not isinstance(x, bool)})
                try:
                    return INV.eval_int(e, merged)
                except INV.RustParseError:
                    pass
            return super()._tuple_value(v, env)

        # ---- B-2 / B-3 / B-9 / B-10 --------------------------------------
        def _statement(self, s: str, env: Dict, slot: int, out: List):
            if "_B10" not in env:
                env.update(self.preamble)
                env["_B10"] = True
                self._note("B-10")
            # B-9: `let n_help = helpers(dom).1` -- the committed let-binder takes this form
            # only with a literal `Dom::X`
            m = re.match(r"^let\s+(\w+)\s*=\s*helpers\((\w+)\)\.1$", s)
            if m:
                self._note("B-9")
                env[m.group(1)] = self._int(f"helpers({m.group(2)}).1", env)
                return None
            # B-9: `let th = [H_GU8, H_GEXP, H_GACT]` (the table helpers, rewritten above)
            m = re.match(r"^let\s+(?:mut\s+)?(\w+)\s*=\s*\[([^\[\]]+)\]$", s)
            if m and all(x.strip() in self.lay.consts for x in INV.split_top(m.group(2), ",")):
                self._note("B-9")
                env[m.group(1)] = [self.lay.consts[x.strip()]
                                   for x in INV.split_top(m.group(2), ",")]
                return None
            # B-9: `let kvw = 1 * 8` -- an integer local the shape rewrite left arithmetic
            m = re.match(r"^let\s+(?:mut\s+)?(\w+)\s*=\s*([\d_ ()*+/<>-]+)$", s)
            if m:
                try:
                    v = INV.eval_int(m.group(2), {})
                except INV.RustParseError:
                    v = None
                if v is not None:
                    self._note("B-9")
                    env[m.group(1)] = v
                    return None
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

    # --- `lay.h_planes()` : layout.rs must say `(0..self.hids.n_h()).collect()`, and the toy's
    # `hids.n_h()` must be the declared `N_H` -- which is `Layout::new`'s own freeze gate
    # (layout.rs:985, `assert_eq!(lay.hids.n_h(), N_H)`; grow_tests.rs:858 asserts it again on
    # `HIds::new(&Shape::toy())`).  Re-pinned 2026-09-20: before the shape generalisation this
    # body read `(0..N_H).collect()` and named the constant itself.
    body = INV.fn_body(lsrc, "h_planes").strip()
    m = re.match(r"^\(0\.\.(\w+)\)\.collect\(\)$", body)
    if m:
        n_h_const = m.group(1)
    else:
        if body != "(0..self.hids.n_h()).collect()":
            raise INV.RustParseError(f"layout.rs::h_planes has an unexpected body {body!r}; "
                                     "adapter B-4 refuses to guess the plane set")
        if "assert_eq!(lay.hids.n_h(), N_H," not in " ".join(lsrc.split()):
            raise INV.RustParseError("layout.rs::Layout::new no longer asserts that the "
                                     "shape-driven H plane count is N_H; adapter B-4 refuses "
                                     "to guess the plane set")
        n_h_const = "N_H"
    rec["h_planes_body"] = body
    rec["h_planes_range_const"] = n_h_const

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
    out = out.replace(old_loop, f"for p in 0..{n_h_const} {{", 1)
    # Re-pinned 2026-09-20: the sign test moved from the free function `h_is_table(p)` to the
    # shape-driven `hids.is_table(p)`.  The two are asserted equal plane by plane at the toy
    # (grow_tests.rs:872), and `HIds::is_table` is the three consecutive table helpers
    # (layout.rs:547-549), which is what the free function still names; the three PLANES below
    # are still read out of `h_is_table`, so this adapter still refuses an unexpected body.
    old_sign = "if h_is_table(p)"
    if old_sign not in out:
        shaped = "if hids.is_table(p)"
        flag = " ".join(INV.fn_body(lsrc, "is_table").split())
        if shaped not in out or flag != "(self.gu8..self.gu8 + 3).contains(&plane)":
            raise INV.RustParseError("protocol.rs::logup_sum_claim: the `if h_is_table(p)` sign "
                                     "adapter B-4 expects was not found")
        rec["is_table_body"] = flag
        out = out.replace(shaped, old_sign, 1)
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


def model_cross_check(INV, lay, repo: str) -> dict:
    """The toy profile this driver READ OUT OF THE RUST, against the independent shape-driven
    model `scripts/zk60_private_block_layout_model.py`, which computes the same quantities from
    a shape alone and never opens a Rust file.  Nothing here is imported into the derivation:
    it is a second opinion on exactly the quantities adapters B-7 / B-8 had to compute because
    the source no longer states them as literals."""
    path = os.path.join(repo, "scripts", "zk60_private_block_layout_model.py")
    if not os.path.exists(path):
        return {"available": False, "rows": [], "differences": []}
    LM = load_tool(path, "zk60_private_block_layout_model")
    toy, ax = LM.TOY, lay.block_toy["axis_logs"]
    tot = block_lookup_totals(INV, lay)
    lk = LM.lookup_counts(toy)
    mrows = LM.rows(toy)
    rows = [("axis log lt (tokens)", ax["lt"], toy.t_pad.bit_length() - 1),
            ("axis log lh (query heads)", ax["lh"], toy.h_pad.bit_length() - 1),
            ("axis log ldh (head dim)", ax["ldh"], toy.head_dim.bit_length() - 1),
            ("axis log ld (width)", ax["ld"], toy.d_pad.bit_length() - 1),
            ("axis log lf (hidden)", ax["lf"], toy.f_pad.bit_length() - 1),
            ("axis log lkv (kv heads)", ax["lkv"], toy.kv_heads.bit_length() - 1),
            ("byte limbs of a norm remainder", lay.block_toy["ln"], toy.limbs_norm),
            ("byte limbs of a softmax remainder", lay.block_toy["ls"], toy.limbs_sigma_s),
            ("byte limbs of the softmax quotient", lay.block_toy["lp"], toy.limbs_p),
            ("the C-6 scaled lookups are emitted", lay.block_toy["norm_top"],
             not toy.norm_top_is_full_byte),
            ("A rows", lay.a_rows, mrows["a_rows"]),
            ("H rows", lay.h_rows, mrows["h_rows"]),
            ("A claim sites", sum(lay.a_sites), mrows["a_sites"]),
            ("H claim sites", sum(lay.h_sites), mrows["h_sites"]),
            ("U8 lookups", tot["U8"], LM.lookups(toy)["u8_total"]),
            ("exp lookups", tot["exp"], LM.lookups(toy)["exp_pairs"]),
            ("act lookups", tot["act"], LM.lookups(toy)["act_pairs"])]
    # The slot table is where the pad rule would SHOW: a slot whose relation the support
    # indicator gates gains one degree at a shape that pads and carries the rule.  The model
    # says no slot carries an indicator at the toy; layout.rs's declared `SLOTS` must agree,
    # and that is the observable consequence of adapter B-10's `pad_on = false`.
    msl = LM.slots(toy)
    rows.append(("no slot carries the support indicator (pad_on)",
                 lay.block_toy["pad_on"], any(s["carries_support_indicator"] for s in msl)))
    for s, m in enumerate(msl):
        rows.append((f"slot {lay.slot_name_of[s]} (main, ext, degree)", tuple(lay.slots[s]),
                     (m["main_rounds"], m["extension_rounds"], m["degree"])))
    rows += [(f"log of Dom::{d}", lay.dom_logs[d], toy.log(d)) for d in sorted(lay.dom_logs)]
    rows += [(f"U8 lookups per position of Dom::{d}", lay.lookup_counts[d], lk[d])
             for d in sorted(lk)]
    rows += [(f"LogUp helper planes of Dom::{d}", lay.helpers[d][1], v)
             for d, v in sorted(LM.helpers(toy).items())]
    out = [{"item": n, "read_from_the_rust": a, "model_says": b, "pass": a == b}
           for n, a, b in rows]
    return {"available": True, "model": "scripts/zk60_private_block_layout_model.py",
            "shape": toy.name, "n_items": len(out), "rows": out,
            "differences": [r for r in out if not r["pass"]]}


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
    mx = model_cross_check(INV, lay, repo)
    gate("the toy profile read out of the shaped Rust equals the independent layout model's",
         mx["available"] and not mx["differences"],
         {"available": mx["available"], "n_items": len(mx["rows"]),
          "differences": mx["differences"]})

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
                              "integer expression).  B-1: private_block/argument.rs:935 (nine "
                              "loop iterations); B-3: :1084 (one arm, three slots); B-9: the "
                              "source rewrites counted in `define_rewrites` plus the evaluator "
                              "extensions, as they fire; B-10: once per slot arm.  B-2 is "
                              "ABSENT because the spelling it adapts no longer occurs "
                              "(see the B-2 entry above).",
        "define_rewrites": parser.rewrites,
        "layout_adapter_record": lay.block_layout_adapters,
        "toy_profile_read_from_the_rust": lay.block_toy,
        "independent_model_cross_check": mx,
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
