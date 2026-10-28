#!/usr/bin/env python3
"""[GATE ROUND 7, 2026-10-19] The token-I/O stages' geometry, RE-DERIVED from
public parameters, for the privacy gate's items G-1..G-7
(`results/zk60_token_io_design_20261017/DESIGN.md` §4.2).

WHY THIS EXISTS.  A gate never takes a layout from a bundle (ruling T-7): it
re-derives every row count, domain and site row from the public statement and
COMPARES.  The token lane's stages IN and OUT have their own layout code
(`token_io.rs` `StageLayout::new`, `token_io/stage_in.rs` / `stage_out.rs`
`layout`, `TokenProfile` helpers, `Tier`); this module ports it.  Read at the
token tree's round 6 (`ops/zkp-mvp/token-io/hashline/`, manifest
`results/zk60_token_io_r1_20261017/manifest_final_r6.sha256`), line numbers
in the docstrings below.  The port is CHECKED against the token lane's own
counted layouts (DESIGN §6.5: R2 stage IN A 17 / H 28, stage OUT A 182 / H 110,
1,196,032 elements; R3 stage IN A 41 / H 76, stage OUT A 374 / H 302) by the
unit tests (`tests/test_v4_status_g10.py`, class TokenIoGeometry).

WHAT IS BUILT IN THE TOKEN TREE (READ, round 6 and round 7's wip): ONLY the
PUBLIC-ROW variant, mode (i) (`token_io/run.rs` `variant_is_built` refuses the
P and F variants: "D26's two-site endpoint is the next rung").  So the D26
two-site input endpoint, its SHIFT / IO-s claims (G-7) and the hidden-length
mode are NOT built and not in scope; this module describes their geometry
nowhere.

The static figures here are [COUNTED]; every receipt-level figure (ranks,
CFS, joint view) needs a capture (EV/token_io/CAPTURE_HOOK_REQUEST.md).

NOTHING HERE IS A PRIVACY RESULT.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass, field

# token_io.rs:253-269
MULT_BITS = 12
U8_LEN = 256
LIMBS_ISQRT = 3
NORM_LIMBS = 4
V_MAX = 1 << 17
MAX_DOM_LOG = 17
# token_io/stage_out.rs:22
TO_LOG = 1
# endpoint_g.rs:92
EP_MASK_ROWS = 5
# zk.rs:373-374
MASK_LOG_MSG = 9
MASK_LOG_DOM = 12


def clog2(v: int) -> int:
    """`token_io.rs:271` clog2: the ceiling log2 (0 for v <= 1)"""
    return max(0, (v - 1).bit_length())


def rows_of(log: int, log_n: int) -> int:
    """`token_io.rs:706`: `max(1, 2^log >> log_n)`"""
    return max(1, (1 << log) >> log_n)


@dataclass(frozen=True)
class Tier:
    """`token_io.rs` `Tier::R1_MVP` (the one registered tier, D27)"""
    name: str = "mvp-95-whole-run (D27)"
    opened_cols: int = 256
    stage_log_n: int = 12
    stage_inv_rate: int = 4
    ep_log_n: int = 8
    ep_inv_rate: int = 8
    lookup_ext_degree: int = 2


R1_MVP = Tier()


@dataclass
class Slot:
    name: str
    main: int
    ext: int
    degree: int
    kind: str          # Standalone | Private | Host
    a_sites: int
    h_sites: int
    io_sites: int


@dataclass
class StageLayout:
    """`token_io.rs:680-805` `StageLayout::new` and its accessors"""
    label: str
    log_n: int
    a_log: list
    h_log: list
    h_sign: list
    h_u: int
    slots: list
    hosts: list
    row_log: list           # [A, H, In, Out]
    a_off_rows: list = field(default_factory=list)
    a_data_rows: int = 0
    a_mask_base: int = 0
    a_prox: int = 0
    a_rows: int = 0
    h_off_rows: list = field(default_factory=list)   # (re_row, im_row)
    h_data_rows: int = 0
    h_mask_base: int = 0
    h_prox: int = 0
    h_rows: int = 0

    def __post_init__(self):
        row = 0
        for lg in self.a_log:
            self.a_off_rows.append(row)
            row += rows_of(lg, self.log_n)
        self.a_data_rows = row
        a_sites = sum(s.a_sites for s in self.slots)
        h_sites = sum(s.h_sites for s in self.slots)
        self.a_mask_base = self.a_data_rows
        self.a_prox = self.a_mask_base + 2 * a_sites
        self.a_rows = self.a_prox + 2
        row = 0
        for lg in self.h_log:
            r = rows_of(lg, self.log_n)
            self.h_off_rows.append((row, row + r))
            row += 2 * r
        self.h_data_rows = row
        self.h_mask_base = self.h_data_rows
        self.h_prox = self.h_mask_base + 2 * h_sites
        self.h_rows = self.h_prox + 2

    @property
    def n(self) -> int:
        return 1 << self.log_n

    def a_site_rows(self, slot: int) -> list:
        base = self.a_mask_base + 2 * sum(s.a_sites for s in self.slots[:slot])
        return [base + 2 * k for k in range(self.slots[slot].a_sites)]

    def h_site_rows(self, slot: int) -> list:
        base = self.h_mask_base + 2 * sum(s.h_sites for s in self.slots[:slot])
        return [base + 2 * k for k in range(self.slots[slot].h_sites)]

    def h_u_rows(self) -> list:
        re, im = self.h_off_rows[self.h_u]
        return [re, im]

    def m_rows(self) -> int:
        return 2 * len(self.slots) + 4

    def mask_specs(self) -> list:
        return [(s.main + s.ext, s.degree) for s in self.slots]

    def n_functionals(self) -> int:
        return sum(1 + (1 if s.kind == "Standalone" else 0) for s in self.slots) + len(self.hosts)

    def elems(self) -> int:
        return (self.a_rows + self.h_rows) * self.n

    def summary(self) -> dict:
        return {
            "label": self.label, "row_width_log": self.log_n,
            "A": {"rows": self.a_rows, "data_rows": self.a_data_rows,
                  "site_pairs": (self.a_prox - self.a_mask_base) // 2,
                  "prox_pair": [self.a_prox, self.a_prox + 1], "plane_logs": self.a_log},
            "H": {"rows": self.h_rows, "data_rows": self.h_data_rows,
                  "site_pairs": (self.h_prox - self.h_mask_base) // 2,
                  "zero_sum_pair": self.h_u_rows(),
                  "prox_pair": [self.h_prox, self.h_prox + 1], "plane_logs": self.h_log,
                  "signs": self.h_sign},
            "M": {"rows": self.m_rows(), "functionals": self.n_functionals(),
                  "mask_specs": self.mask_specs()},
            "row_log_A_H_In_Out": self.row_log,
            "committed_elements": self.elems(),
            "slots": [s.__dict__ for s in self.slots],
            "hosts": self.hosts,
        }


@dataclass
class TokenGeom:
    """`token_io.rs:335-480` `TokenProfile` (the parts the layout reads) at a
    registered shape, public-row variant, mode (i)."""
    name: str
    tokens: int
    t_pad: int
    d: int
    d_pad: int
    v: int
    block_log_n: int        # the block shape's endpoint row width (B_in / B_out)
    block_inv_rate: int
    tier: Tier = R1_MVP

    def __post_init__(self):
        if not (2 <= self.v <= V_MAX):
            raise ValueError(f"V = {self.v} outside 2..=2^17")
        self.v_pad = 1 << clog2(self.v)
        self.log_v = clog2(self.v_pad)
        top = ((2 * self.d * 127 * 127 * (1 << MULT_BITS)) << self.log_v) + (self.v - 1)
        self.window_bits = top.bit_length()
        self.limbs = -(-self.window_bits // 8)
        lt = self.tier.stage_log_n
        if clog2(max(self.t_pad, 1 << self.tier.ep_log_n)) > max(clog2(self.t_pad), lt):
            raise ValueError("the input token endpoint is wider than the position domain")

    # domains (token_io.rs:438-466): natural padded size lifted UP to the row width
    def ti_log(self): return max(clog2(self.t_pad), self.tier.stage_log_n)
    def voc_log(self): return max(self.log_v, self.tier.stage_log_n)
    def lo_log(self): return max(clog2(2 * 3 * LIMBS_ISQRT), self.tier.stage_log_n)
    def do_log(self): return max(clog2(self.d_pad), self.tier.stage_log_n)
    def vo_log(self): return max(self.log_v, self.tier.stage_log_n)
    def tab_log(self): return max(clog2(U8_LEN), self.tier.stage_log_n)
    def in_ep_words(self): return max(self.t_pad, 1 << self.tier.ep_log_n)
    def out_ep_words(self): return 1 << self.tier.ep_log_n

    def stage_in(self) -> StageLayout:
        """`token_io/stage_in.rs:38-59`"""
        lt = self.tier.stage_log_n
        lti, lvoc = self.ti_log(), self.voc_log()
        slots = [
            Slot("IN-00 IO-in", clog2(self.in_ep_words()), 1, 3, "Standalone", 1, 0, 1),
            Slot("IN-01 query zero-check", lti, 1, 4, "Standalone", 1, 1, 1),
            Slot("IN-02 table zero-check", lvoc, 1, 4, "Standalone", 1, 1, 0),
            Slot("IN-03 ZS zero-sum row", lt, 1, 2, "Standalone", 0, 1, 0),
        ]
        return StageLayout("stage IN", lt, [lti, lvoc], [lti, lvoc, lt], [1, -1, 1], 2,
                           slots, [], [lt, lt, self.tier.ep_log_n, self.block_log_n])

    def stage_out(self) -> StageLayout:
        """`token_io/stage_out.rs:77-120`"""
        lt = self.tier.stage_log_n
        llo, ldo, lvo, ltab = self.lo_log(), self.do_log(), self.vo_log(), self.tab_log()
        lmb = self.limbs
        vplanes = 1 + lmb
        h = -(-lmb // 2)
        d_bits = clog2(self.d_pad)
        slots = [
            Slot("OUT-00 IO-in", d_bits, 1, 2, "Standalone", 1, 0, 1),
            Slot("OUT-01 SS", ldo, 1, 4, "Private", 1, 0, 0),
            Slot("OUT-02 TZC", TO_LOG, 1, 3, "Host", 11, 0, 0),
            Slot("OUT-03 LZC", llo, 1, 4, "Standalone", 1, 1, 0),
            Slot("OUT-04 HEAD", d_bits, 1, 2, "Private", 1, 0, 0),
            Slot("OUT-05 DZC", ldo, 1, 5, "Standalone", 13, 6, 0),
            Slot("OUT-06 VZC", lvo, 1, 5, "Host", vplanes + 2, h, 0),
            Slot("OUT-07 RSEL", lvo, 1, 4, "Standalone", vplanes + 1, 0, 0),
            Slot("OUT-08 TAB", ltab, 1, 3, "Standalone", 1, 1, 0),
            Slot("OUT-09 ZS", lt, 1, 2, "Standalone", 0, 1, 0),
            Slot("OUT-10 IO-out", clog2(self.out_ep_words()), 1, 3, "Standalone", 1, 0, 1),
        ]
        a_log = [TO_LOG] * 4 + [llo] + [ldo] * 12 + [lvo] * vplanes + [ltab]
        n_h = 1 + 6 + h + 2
        h_sign = [1] * n_h
        h_sign[7 + h] = -1                     # h_gu8(l) = H_V0 + hv(l)
        h_log = [llo] + [ldo] * 6 + [lvo] * h + [ltab] + [lt]
        return StageLayout("stage OUT", lt, a_log, h_log, h_sign, 7 + h + 1, slots,
                           [[2, [1]], [6, [4]]], [lt, lt, self.block_log_n, self.tier.ep_log_n])

    def endpoint(self, words: int) -> dict:
        """`endpoint_g.rs` `EndpointSpecG` at one row: data rows ceil(words / 2^ep_log_n),
        commitment rows data + MASK_ROWS (5 = one reserved pair, its proximity
        pair and one more row: the generic endpoint's own rule)"""
        n = 1 << self.tier.ep_log_n
        data = -(-words // n)
        return {"words": words, "row_width_log": self.tier.ep_log_n,
                "inv_rate": self.tier.ep_inv_rate, "data_rows": data,
                "commitment_rows": data + EP_MASK_ROWS, "row_tail_words": data * n - words}

    def boundary(self) -> dict:
        """B_in / B_out: the block's boundary geometry, `data + 2*sites + 2`
        rows (ruling M-1) at the block shape's endpoint row width"""
        words = self.t_pad * self.d_pad
        data = -(-words // (1 << self.block_log_n))
        return {"plane": [self.t_pad, self.d_pad], "row_width_log": self.block_log_n,
                "inv_rate": self.block_inv_rate, "data_rows": data,
                "rows": data + 2 * 2 + 2, "sites": 2}

    # ------------------------------------------------------------ G-items, static
    def g5(self) -> dict:
        """G-5: the stage-23 invariant log(Tab) == row width for each new
        stage that looks up the byte table (stage OUT's U8 lookups; stage IN
        looks up only the embedding compression on Voc, no byte table)"""
        out = self.stage_out()
        return {"stage IN": {"byte_table": False, "holds": None,
                             "why": "stage IN has no byte-table lookup (its one LogUp table is the V-row embedding compression on Voc)"},
                "stage OUT": {"byte_table": True, "tab_log": self.tab_log(), "row_width_log": out.log_n,
                              "holds": self.tab_log() == out.log_n}}

    def g4(self) -> dict:
        """G-4, static half: the vocabulary domains' pad positions, the P-3
        lift of every small domain, and the token endpoints' pad words.  The
        pad-zero TERMS (present for m, h_tab, e, lambda, tok, h_q, s) and the
        IO slots' public support factors are read from a capture's slot
        definitions (needs the slot hook, 2.1(c) of the request)"""
        lt = self.tier.stage_log_n
        lifts = {}
        for dom, natural, log in [("Ti (tok, h_q)", self.t_pad, self.ti_log()),
                                  ("Voc (m, h_tab)", self.v_pad, self.voc_log()),
                                  ("Lo (isqrt limbs)", 2 * 3 * LIMBS_ISQRT, self.lo_log()),
                                  ("Do (x, y, norm limbs)", self.d_pad, self.do_log()),
                                  ("Vo (e, lambda limbs)", self.v_pad, self.vo_log()),
                                  ("Tab (byte table)", U8_LEN, self.tab_log())]:
            lifts[dom] = {"natural": natural, "domain": 1 << log,
                          "lifted_positions": (1 << log) - (1 << clog2(natural)),
                          "lifted": log > clog2(natural)}
        return {"vocabulary": {"V": self.v, "V_pad": self.v_pad, "pad_positions": self.v_pad - self.v},
                "p3_lift": lifts,
                "endpoints": {"input": self.endpoint(self.in_ep_words()) | {
                                  "true_words": self.tokens,
                                  "pad_words_in_plane": self.in_ep_words() - self.tokens},
                              "output": self.endpoint(self.out_ep_words()) | {
                                  "true_words": 1,
                                  "pad_words_in_plane": self.out_ep_words() - 1}},
                "row_width_log": lt}

    def g2(self) -> dict:
        """G-2, static half: B_out's stage-OUT claim fixes the row bits of
        token row T - 1 (public-row variant).  The B_out plane is (t, i)
        major, t_pad x d_pad words over rows of 2^block_log_n; of the
        log2(t_pad) fixed bits, those below the row width are COLUMN bits.
        B_in's stage-IN claim has the challenge-fixed column coordinate
        r_emb.  Whether the reserved pair still masks the claim is a capture
        check (needs the claim points, 2.1(c)/(d) of the request)"""
        tb, db, ln = clog2(self.t_pad), clog2(self.d_pad), self.block_log_n
        col_bits = [b for b in range(db, db + tb) if b < ln]
        row_bits = [b for b in range(db, db + tb) if b >= ln]
        return {"B_out": {"fixed_row": self.tokens - 1, "fixed_bits_total": tb,
                          "fixed_bits_in_the_column_coordinate": len(col_bits),
                          "fixed_bits_in_the_row_coordinate": len(row_bits),
                          "bit_positions": {"column": col_bits, "row": row_bits},
                          "plane_bits": db + tb, "row_width_log": ln},
                "B_in": {"fixed": "column coordinate r_emb (challenge-fixed, drawn after A_in and M_in)"}}

    def report(self) -> dict:
        si, so = self.stage_in(), self.stage_out()
        return {
            "geometry": self.name, "tokens": self.tokens, "d": self.d, "d_pad": self.d_pad,
            "V": self.v, "V_pad": self.v_pad, "log_V": self.log_v,
            "keyed_window_bits": self.window_bits, "byte_limbs": self.limbs,
            "tier": self.tier.__dict__,
            "stage_in": si.summary(), "stage_out": so.summary(),
            "input_endpoint": self.endpoint(self.in_ep_words()),
            "output_endpoint": self.endpoint(self.out_ep_words()),
            "b_in_b_out": self.boundary(),
            "G2_static": self.g2(), "G4_static": self.g4(), "G5": self.g5(),
            "not_built": ["D26 variant P (two-site input endpoint) and its SHIFT / IO-s claims (G-7)",
                          "variant F", "mode (ii)", "the hidden-length variant"],
            "privacy_acceptance": False,
        }


# the two geometries of gate round 7 (DESIGN §6.5; shape.rs at round 6)
R2_TINYLLAMA_T32 = dict(name="R2 TinyLlama-1.1B T32 (public row, mode i)", tokens=32, t_pad=32,
                        d=2048, d_pad=2048, v=32000, block_log_n=12, block_inv_rate=4)
R3_LLAMA3_8B_T32 = dict(name="R3 Llama-3-8B T32 (public row, mode i)", tokens=32, t_pad=32,
                        d=4096, d_pad=4096, v=128256, block_log_n=13, block_inv_rate=4)


def cross_check_plane_index(geom: TokenGeom, stage_kind: str, plane_index: dict) -> list:
    """For a CAPTURED stage (once the hook lands): compare the bundle's plane
    index of a stage IN / OUT with the re-derived layout.  Returns findings
    (empty = equal).  Field names follow the request (2.1(b))."""
    lay = geom.stage_in() if stage_kind == "IN" else geom.stage_out()
    want = {"a_rows": lay.a_rows, "a_data_rows": lay.a_data_rows, "a_mask_base": lay.a_mask_base,
            "a_prox": lay.a_prox, "h_rows": lay.h_rows, "h_data_rows": lay.h_data_rows,
            "h_mask_base": lay.h_mask_base, "h_prox": lay.h_prox, "h_u": lay.h_u,
            "h_u_rows": lay.h_u_rows(), "log_n": lay.log_n}
    out = []
    for k, v in want.items():
        got = plane_index.get(k)
        if got is None:
            out.append(f"stage {stage_kind}: the bundle's plane index has no `{k}`")
        elif got != v:
            out.append(f"stage {stage_kind}: `{k}` is {got} in the bundle, {v} re-derived")
    return out


def main(argv):
    out = {"what": "token-I/O stage geometry, re-derived (gate round 7); NOT a privacy result",
           "privacy_acceptance": False,
           "geometries": [TokenGeom(**R2_TINYLLAMA_T32).report(), TokenGeom(**R3_LLAMA3_8B_T32).report()]}
    s = json.dumps(out, indent=1, sort_keys=True)
    if len(argv) > 1:
        open(argv[1], "w").write(s + "\n")
    for g in out["geometries"]:
        si, so = g["stage_in"], g["stage_out"]
        print(f"{g['geometry']}: limbs {g['byte_limbs']} (window {g['keyed_window_bits']} bits); "
              f"stage IN A {si['A']['rows']} / H {si['H']['rows']} ({si['committed_elements']:,} elements); "
              f"stage OUT A {so['A']['rows']} / H {so['H']['rows']} ({so['committed_elements']:,}); "
              f"G-5 {g['G5']['stage OUT']['holds']}; V pads {g['G4_static']['vocabulary']['pad_positions']}; "
              f"B_out fixed bits col/row {g['G2_static']['B_out']['fixed_bits_in_the_column_coordinate']}/"
              f"{g['G2_static']['B_out']['fixed_bits_in_the_row_coordinate']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
