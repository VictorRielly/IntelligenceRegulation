#!/usr/bin/env python3
"""The GROUP FACTOR of the two bilinear attention slots, DERIVED from the
shape and the transcript and then COMPARED with what the bundle names.

WHY THIS FILE EXISTS.  Finding S19-F1 (the security owner's disposition,
`ZK60_BLOCK125M_S19F1_DISPOSITION.md`, 2026-09-20): under grouped-query
attention the two bilinear attention slots

    08  SC_SCORE   scores  = Q . K^T
    09  SC_PV      output  = P . V

took the key-value GROUP bits of the head challenge as FIXED coordinates of
BOTH private factors and summed only over the inner axis.  The multilinear
extension of a product that shares a variable is quadratic in that variable,
so the honest prover and the honest verifier computed two different
polynomials the moment two key-value groups carried different data: a
COMPLETENESS failure, invisible to every witness that is constant across
heads.  Stage 20 of the Rust lane repaired it: the group bits become
SUMCHECK VARIABLES `rho(0..lkv)` shared by both factors, with a PUBLIC
factor `eq(r_g, .)` over the LEADING `lkv` variables, where

    lkv = clog2(kv_heads)        r_g = r_h[..lkv]        r_hj = r_h[lkv..]

and `r_h` is the slot's own head challenge, the FIRST `lh` entries it draws.
The slot gains `lkv` main rounds and one degree.  `kv_heads == 1` gives
`lkv == 0`, no table, no variable, no degree: the frozen toy is untouched
byte for byte.

WHAT THIS MODULE DOES, AND THE ONE RULE IT KEEPS.  `eq(r_g, .)` is a
VERIFIER-COMPUTED table.  A gate that read its point out of the bundle would
be checking the prover's arithmetic against the prover's own claim about
which point it used.  So this module

  * derives `lkv`, `lh`, `lt`, `ldh` from `run.json["shape"]` alone;
  * derives each bilinear slot's `(main, extension, degree)` and its number
    of definition challenges from that geometry, and compares them with the
    slot's own declaration AND with the shape's `slots` array;
  * takes `r_h` from the RE-DERIVED definition challenges of the transcript
    replay (never from the capture, when a replay is given) and splits off
    `r_g = r_h[..lkv]`;
  * compares that derived point, entry by entry, with the `Tab::Eq` the
    bundle names -- and it is the DERIVED point that the terminal identity
    then evaluates.  **Re-derive, never consume** (ruling T-7, as round 3
    applied it to the hash keys);
  * re-derives both private factors' whole COORDINATE LISTS -- which axis is
    a summed `rho` and which is a fixed challenge, and WHICH challenge --
    and compares them with the capture's, so that "the polynomial is a
    product of two terminals" is backed by "and the two terminals are
    evaluations at the points the repaired schedule says".

BOTH DEFINITIONS LIVE HERE, AND THE BUNDLE'S OWN SOURCE PIN CHOOSES.  A
bundle written before stage 20 is the verifier's view of a run made under
the PRE-REPAIR definition.  Replaying it under the repaired one would
mis-replay it; refusing it by name would throw away three rounds of
evidence.  So the pre-repair schedule is kept, it is selected by the
`argument.rs` digest the bundle pins ITSELF (never by "does the bundle carry
an eq table", which would be consuming the prover's claim), and every record
says which definition was in force and that the pre-repair one is
SUPERSEDED -- exactly the treatment round 3 gave a pre-tag hash rule.

NOTHING HERE IS A PRIVACY STATEMENT.  This is the verifier's own view,
recomputed.
"""

from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_jv_field import (  # noqa: E402
    F2_ONE,
    f2_add,
    f2_from_list,
    f2_mul,
    f2_sub,
)

SC_SCORE, SC_PV = 8, 9
BILINEAR_SLOTS = (SC_SCORE, SC_PV)
SLOT_NAMES = {SC_SCORE: "SC_SCORE", SC_PV: "SC_PV"}
# the two private factors of each slot, in the prover's PUSH order
FACTORS = {SC_SCORE: ("A_QR8", "A_KR8"), SC_PV: ("A_P", "A_V8")}

REPAIRED = "repaired"
PRE_REPAIR = "pre-repair"

# ------------------------------------------------------- the definition pin
# Which definition of the two bilinear slots an `argument.rs` digest carries.
# This port has READ both arms; a digest outside this table is a refusal and
# makes every slot NOT CHECKED, never a silent re-read.
ARGUMENT_DEFINITIONS = {
    "909670c96562e7ff99b7ad37f6c3aae027574f3c0e9ab74f01a27e45058bf675": (
        PRE_REPAIR,
        "stages 14-18: the two bilinear slots fix the key-value group bits "
        "r_h[..lkv] as coordinates of BOTH private factors and sum only over "
        "the inner axis (`|v| v[0].mul(v[1])`).  This is the definition "
        "finding S19-F1 names as wrong for a generic witness; a bundle "
        "written under it is SUPERSEDED, and nothing measured on it is a "
        "statement about what the profile produces today",
    ),
    "dd8469cb0279281e1ea7fcc92c0d14ec23a29b8f6bed8a28b10b704bd15ff08f": (
        REPAIRED,
        "stage 20's repair of finding S19-F1: the group bits are sumcheck "
        "variables shared by both private factors, with a public "
        "`eq(r_g, .)` over the leading lkv variables and degree 3 "
        "(`|v| ig.at(v).mul(v[iq]).mul(v[ik])`).  Read at "
        "`argument.rs:1126-1187`; the whole diff against the stage-18 digest "
        "is these two slots, the `B::group_eq` helper and a #[cfg(test)] "
        "accessor -- no other slot's polynomial moved",
    ),
}


def clog2(v: int) -> int:
    """`shape.rs::clog2` (shape.rs:68)."""
    if v <= 0:
        raise ValueError("clog2 of zero")
    return (v - 1).bit_length() if v > 1 else 0


def lg(v: int) -> int:
    """`argument.rs::lg` (argument.rs:637): the log of a power-of-two axis."""
    if v <= 0 or (v & (v - 1)):
        raise ValueError(f"lg of {v}, which is not a power of two")
    return v.bit_length() - 1


def eq_point(r, s):
    """`eq_point` (zkp-core/src/mle.rs:54)."""
    if len(r) != len(s):
        raise ValueError("eq_point arity")
    acc = F2_ONE
    for a, b in zip(r, s):
        acc = f2_mul(acc, f2_add(f2_mul(a, b),
                                 f2_mul(f2_sub(F2_ONE, a), f2_sub(F2_ONE, b))))
    return acc


def definition_of_pin(digest: str):
    """`(name, reason)` for an `argument.rs` digest, or `(None, None)`."""
    return ARGUMENT_DEFINITIONS.get(digest, (None, None))


def argument_pin_of(bundle) -> str | None:
    for p in bundle.manifest.get("source_pins", []):
        if p["file"].endswith("argument.rs"):
            return p["sha256"]
    return None


def definition_in_force(bundle):
    """The definition the BUNDLE'S OWN source pin selects."""
    pin = argument_pin_of(bundle)
    if pin is None:
        return None, None, None
    name, why = definition_of_pin(pin)
    return name, why, pin


# =====================================================================
#  the geometry, derived from the shape and nothing else
# =====================================================================
class Geometry:
    """`(lt, lh, ldh) = (lg(t_pad), lg(h_pad), lg(head_dim))` and
    `lkv = clog2(kv_heads)` -- argument.rs:924-925, shape.rs's stage-20
    `lkv`.  Every number below is read from `run.json["shape"]`."""

    def __init__(self, shape_raw: dict):
        self.s = shape_raw
        self.lt = lg(shape_raw["t_pad"])
        self.lh = lg(shape_raw["h_pad"])
        self.ldh = lg(shape_raw["head_dim"])
        self.lkv = clog2(shape_raw["kv_heads"])

    def as_dict(self) -> dict:
        return {
            "lt = lg(t_pad)": self.lt,
            "lh = lg(h_pad)": self.lh,
            "ldh = lg(head_dim)": self.ldh,
            "lkv = clog2(kv_heads)": self.lkv,
            "q_heads": self.s["q_heads"],
            "kv_heads": self.s["kv_heads"],
            "h_pad": self.s["h_pad"],
            "head_dim": self.s["head_dim"],
            "t_pad": self.s["t_pad"],
        }

    # ----------------------------------------------- the definition draws
    def n_definition_challenges(self, slot: int) -> int:
        """`SC_SCORE` draws `r_h, r_t, r_j`; `SC_PV` draws `r_h, r_t, r_i`."""
        if slot == SC_SCORE:
            return self.lh + self.lt + self.lt
        return self.lh + self.lt + self.ldh

    def dims(self, slot: int, definition: str):
        """`(main, extension, degree)`, derived.  `shape.rs::slot_dims`:
        the bilinear slots' base degree is the table minimum 2, the group
        `eq` adds one, and it exists only when `lkv > 0`."""
        inner = self.ldh if slot == SC_SCORE else self.lt
        if definition == REPAIRED:
            return (self.lkv + inner, 2, 2 + (1 if self.lkv > 0 else 0))
        return (inner, 2, 2)

    def has_group_table(self, definition: str) -> bool:
        return definition == REPAIRED and self.lkv > 0

    # ------------------------------------------------ the coordinate lists
    def coordinate_schedule(self, slot: int, definition: str):
        """Both private factors' coordinate lists, as tokens.

        A token is `("rho", k)` -- the slot's `k`-th sumcheck variable -- or
        `("dc", i)` -- the slot's `i`-th definition challenge.  This is
        `argument.rs`'s `cq` / `ck` / `cp` / `cv`, written out.
        """
        lt, lh, ldh, lkv = self.lt, self.lh, self.ldh, self.lkv
        r_h = [("dc", i) for i in range(lh)]
        r_t = [("dc", lh + i) for i in range(lt)]
        r_g, r_hj = r_h[:lkv], r_h[lkv:]
        if slot == SC_SCORE:
            r_j = [("dc", lh + lt + i) for i in range(lt)]
            if definition == REPAIRED:
                # A_QR8 on Dom::Q = (t, head slot, c); the head slot is
                # (g, r_hj) -- the group SUMMED, the within-group head fixed
                qr = (r_t + [("rho", k) for k in range(lkv)] + r_hj
                      + [("rho", lkv + k) for k in range(ldh)])
                # A_KR8 on Dom::Kv = (j, group, c): the SAME summed group
                kr = (r_j + [("rho", k) for k in range(lkv)]
                      + [("rho", lkv + k) for k in range(ldh)])
            else:
                qr = r_t + r_h + [("rho", k) for k in range(ldh)]
                kr = r_j + r_g + [("rho", k) for k in range(ldh)]
            return [qr, kr]
        r_i = [("dc", lh + lt + i) for i in range(ldh)]
        if definition == REPAIRED:
            # A_P on Dom::S = (head slot, t, s)
            pp = ([("rho", k) for k in range(lkv)] + r_hj + r_t
                  + [("rho", lkv + k) for k in range(lt)])
            # A_V8 on Dom::Kv = (s, group, i)
            vv = ([("rho", lkv + k) for k in range(lt)]
                  + [("rho", k) for k in range(lkv)] + r_i)
        else:
            pp = r_h + r_t + [("rho", k) for k in range(lt)]
            vv = [("rho", k) for k in range(lt)] + r_g + r_i
        return [pp, vv]


# =====================================================================
#  the per-run check
# =====================================================================
class GroupFactors:
    """Every bilinear slot of every stage: the derived group point, the
    derived dimensions, the derived coordinate lists, and the comparison
    with the bundle.

    `points[(stage, slot)]` is what the terminal port evaluates.  A slot
    whose comparison FAILED has no entry, so the port refuses it rather than
    falling back to the capture's own point.
    """

    def __init__(self, bundle, replay=None, stage_docs=None,
                 definition=None, perturb_derived_point=None):
        self.bundle = bundle
        self.definition, self.why, self.pin = definition_in_force(bundle)
        self.forced = definition is not None
        if definition is not None:
            self.definition = definition
            self.why = (f"FORCED to {definition!r} by a control, not selected "
                        "by the bundle's own source pin")
        self.geom = Geometry(bundle.run["shape"])
        self.docs = (stage_docs if stage_docs is not None
                     else [st.doc for st in bundle.stages])
        self.replay = replay
        self.derived_from = ("the transcript replay's own re-derived "
                             "definition challenges" if replay is not None
                             else "the capture's definition_challenges "
                             "(no replay was given)")
        self.perturb = perturb_derived_point
        self.points: dict[tuple, list] = {}
        self.failures: list[str] = []
        self.refusals: list[str] = []
        self.rows: list[dict] = []
        self.counts = {
            "slots_examined": 0,
            "dimension_sets_derived_and_compared": 0,
            "definition_challenge_counts_compared": 0,
            "group_points_derived_and_compared": 0,
            "group_point_entries_compared": 0,
            "coordinate_lists_rederived_and_compared": 0,
            "coordinate_entries_compared": 0,
            "fixed_coordinates_compared_with_a_rederived_challenge": 0,
        }
        if self.definition is None:
            self.refusals.append(
                "the bundle pins an `argument.rs` this port has never read "
                f"({(self.pin or 'no pin')[:12]}), so neither definition of the "
                "bilinear slots can be said to be the one it was made under"
            )
        else:
            self._run()

    # ------------------------------------------------------------- helpers
    def _def_challenges(self, stage: int, slot: int):
        """The slot's definition challenges, RE-DERIVED where a replay is
        given.  The replay compares each of them with the capture's and
        fails loudly if they differ, so taking them from it is taking them
        from the transcript."""
        if self.replay is not None:
            got = self.replay.stages[stage].get("def_challenges", {}).get(slot)
            if got is not None:
                return list(got)
        return [f2_from_list(x) for x in
                self.docs[stage]["arguments"][slot]["definition_challenges"]]

    def _fail(self, what: str) -> None:
        self.failures.append(what)

    # ----------------------------------------------------------------- run
    def _run(self) -> None:
        for st in self.bundle.stages:
            for slot in BILINEAR_SLOTS:
                self._slot(st.index, slot)

    def _slot(self, stage: int, slot: int) -> None:
        g = self.geom
        arg = self.docs[stage]["arguments"][slot]
        tag = f"stage {stage} slot {slot} [{SLOT_NAMES[slot]}]"
        row = {"stage": stage, "slot": slot, "name": SLOT_NAMES[slot],
               "definition": self.definition}
        self.counts["slots_examined"] += 1

        # ---- the dimensions, derived from the shape and compared twice
        want = g.dims(slot, self.definition)
        got = (arg["main"], arg["extension"], arg["degree"])
        shape_says = tuple(self.bundle.run["shape"]["slots"][slot])
        row["derived_main_extension_degree"] = list(want)
        row["declared"] = list(got)
        row["the_shapes_own_slots_entry"] = list(shape_says)
        self.counts["dimension_sets_derived_and_compared"] += 1
        if got != want:
            self._fail(f"{tag}: declared (main, extension, degree) {got} is not the "
                       f"{want} this shape and definition derive")
        if shape_says != want:
            self._fail(f"{tag}: the shape's own slots entry {shape_says} is not the "
                       f"{want} this geometry derives")

        n_def = g.n_definition_challenges(slot)
        row["derived_definition_draws"] = n_def
        row["declared_definition_draws"] = len(arg["definition_challenges"])
        self.counts["definition_challenge_counts_compared"] += 1
        if len(arg["definition_challenges"]) != n_def:
            self._fail(f"{tag}: {len(arg['definition_challenges'])} definition "
                       f"challenges, {n_def} derived from the shape")
            self.rows.append(row)
            return

        dc = self._def_challenges(stage, slot)

        # ---- the public group table: derived, compared, never consumed
        eqs = [(i, t) for i, t in enumerate(arg["tables"]) if t["kind"] == "eq"]
        want_table = g.has_group_table(self.definition)
        row["group_table_expected"] = want_table
        row["group_tables_declared"] = len(eqs)
        if want_table:
            if len(eqs) != 1:
                self._fail(f"{tag}: the repaired definition has exactly one public "
                           f"eq table and the bundle declares {len(eqs)}")
            else:
                i, tab = eqs[0]
                r_g = [c for c in dc[:g.lkv]]
                if self.perturb == (stage, slot):
                    r_g = [f2_add(r_g[0], F2_ONE)] + r_g[1:]
                    row["derived_point_perturbed_by_a_control"] = True
                named = [f2_from_list(x) for x in tab["point"]]
                row["group_table_index"] = i
                row["start"] = tab["start"]
                row["derived_point_len"] = len(r_g)
                self.counts["group_points_derived_and_compared"] += 1
                bad = []
                if tab["start"] != 0:
                    self._fail(f"{tag}: the group eq reads from variable "
                               f"{tab['start']}, and the repair puts the group on "
                               "the LEADING variables (start 0)")
                if len(named) != g.lkv:
                    self._fail(f"{tag}: the declared group point has {len(named)} "
                               f"entries, lkv = {g.lkv}")
                else:
                    for j, (a, b) in enumerate(zip(r_g, named)):
                        self.counts["group_point_entries_compared"] += 1
                        if a != b:
                            bad.append(j)
                    if bad:
                        self._fail(
                            f"{tag}: the declared eq point is not r_g = r_h[..lkv] "
                            f"re-derived from the transcript (entries {bad} differ)"
                        )
                row["group_point_matches_the_rederived_r_g"] = not bad
                if not bad and tab["start"] == 0 and len(named) == g.lkv:
                    self.points[(stage, slot)] = r_g
        else:
            if eqs:
                self._fail(f"{tag}: this definition has no public group table and "
                           f"the bundle declares {len(eqs)}")
            row["group_point_matches_the_rederived_r_g"] = None

        # ---- both private factors' coordinate lists, re-derived
        sched = g.coordinate_schedule(slot, self.definition)
        privs = [t for t in arg["tables"] if t["kind"] == "private"]
        row["factors"] = []
        if len(privs) != 2:
            self._fail(f"{tag}: {len(privs)} private tables, and a bilinear slot has 2")
            self.rows.append(row)
            return
        for fi, (tab, tokens) in enumerate(zip(privs, sched)):
            self.counts["coordinate_lists_rederived_and_compared"] += 1
            coords = tab["coordinates"]
            frow = {"factor": FACTORS[slot][fi], "push_index": fi,
                    "derived_len": len(tokens), "declared_len": len(coords),
                    "extension_round": tab["extension_round"]}
            if len(coords) != len(tokens):
                self._fail(f"{tag} factor {fi} [{FACTORS[slot][fi]}]: "
                           f"{len(coords)} coordinates, {len(tokens)} derived")
                row["factors"].append(frow)
                continue
            bad = []
            for j, (c, tk) in enumerate(zip(coords, tokens)):
                self.counts["coordinate_entries_compared"] += 1
                if tk[0] == "rho":
                    if c.get("rho") != tk[1]:
                        bad.append((j, f"rho {tk[1]}", str(c)[:32]))
                else:
                    self.counts["fixed_coordinates_compared_with_a_rederived_challenge"] += 1
                    if "fixed" not in c or f2_from_list(c["fixed"]) != dc[tk[1]]:
                        bad.append((j, f"definition challenge {tk[1]}", str(c)[:32]))
            frow["matches"] = not bad
            if bad:
                frow["first_mismatch"] = list(bad[0])
                self._fail(f"{tag} factor {fi} [{FACTORS[slot][fi]}]: the coordinate "
                           f"list is not the one this schedule derives ({len(bad)} of "
                           f"{len(tokens)} entries differ, first at index {bad[0][0]}: "
                           f"derived {bad[0][1]})")
            row["factors"].append(frow)
        self.rows.append(row)

    # -------------------------------------------------------------- report
    def point(self, stage: int, slot: int):
        return self.points.get((stage, slot))

    def group_table_required(self) -> bool:
        """Whether a bilinear slot of THIS bundle, under the definition in
        force, must carry a public group table at all."""
        return bool(self.definition is not None
                    and self.geom.has_group_table(self.definition))

    def slots_with_a_derived_point(self) -> int:
        return len(self.points)

    def summary(self) -> dict:
        n_bil = len(BILINEAR_SLOTS) * self.bundle.blocks
        return {
            "what": "the two bilinear attention slots' GROUP FACTOR: lkv, the "
            "slot dimensions, the point r_g = r_h[..lkv] and both private "
            "factors' coordinate lists, all DERIVED from the shape and the "
            "replayed transcript and then compared with what the bundle "
            "declares.  The derived point is what the terminal identity "
            "evaluates; the declared one is only ever compared",
            "bundle": self.bundle.name,
            "finding": "S19-F1 (ZK60_BLOCK125M_S19F1_DISPOSITION.md)",
            "definition_in_force": self.definition,
            "definition_selected_by": (
                "a control, overriding the pin" if self.forced else
                f"the bundle's own source pin of argument.rs "
                f"({(self.pin or 'absent')[:12]})"),
            "definition_reason": self.why,
            "superseded": self.definition == PRE_REPAIR,
            "superseded_note": (
                "this bundle was made under the PRE-REPAIR definition of slots "
                "08 and 09, which finding S19-F1 names as wrong for a witness "
                "that varies across key-value groups.  It is replayed under "
                "that definition because that is what made its bytes; nothing "
                "measured on it is a statement about what the profile produces "
                "today" if self.definition == PRE_REPAIR else None),
            "geometry": self.geom.as_dict(),
            "group_point_derived_from": self.derived_from,
            "bilinear_slots_per_stage": len(BILINEAR_SLOTS),
            "stages": self.bundle.blocks,
            "slot_instances": n_bil,
            "counts": self.counts,
            "slots_with_a_derived_group_point": len(self.points),
            "per_slot": self.rows,
            "refusals": self.refusals,
            "failures": self.failures,
            "what_this_does_not_establish": (
                "that the private factors are the quantised query, key, "
                "probability and value planes of the statement.  No bundle "
                "carries a witness.  What is established is that the claim "
                "POINT and the slot's SCHEDULE are the ones the repaired "
                "construction derives from this shape, and that the group "
                "factor the verifier multiplies in is the one this tool "
                "computed for itself"
            ),
            "ok": not self.failures and not self.refusals,
        }
