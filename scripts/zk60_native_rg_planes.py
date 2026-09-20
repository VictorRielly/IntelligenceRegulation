#!/usr/bin/env python3
"""`run.json["plane_index"]` — the PLANE INDEX TABLE of a run capture, read
and integrity-checked.

Stage 15 of the Rust lane (`hashline/src/private_block/plane_index.rs`) added
one member to `run.json`: for every committed `A` and `H` plane its id, name,
domain and row range, and per slot the ORDERED list of planes whose
evaluations that slot's `terminals` carries.  It is the field
`ZK60_NATIVE_RUN_GATE.md` §3 item 4 asked for and would not guess at, and it
is what the per-slot terminal identity needs at the run's shape.

**Everything here is PUBLIC**: a plane's name, domain and row range and a
slot's push order are functions of the public `Shape` and of nothing else.
No plane CONTENT is in the table — not a witness word, not a pad, not a mask
coefficient, not a salt.

WHAT THIS MODULE CHECKS (format document §3a, each one a refusal):

  * `A` tiles exactly.  The planes, sorted by `first_row`, cover
    `[0, a_data_rows)` with no gap and no overlap, and `offset` is
    `first_row * cols` for each.
  * `H` tiles exactly.  An `H` plane is `Fp2`-valued and therefore TWO equal
    runs of rows, `re` then `im`; both halves together tile
    `[0, h_data_rows)` with no gap and no overlap, and both offsets are
    `first_row * cols`.
  * the totals agree with the capture's OWN shape section: `a_data_rows`
    against the `A` opening's `data_rows`, `h_data_rows` against the `H`
    opening's (which counts the two zero-sum rows -- format §4c, this gate's
    finding 2), in every stage.
  * every id a slot names exists, and has the role the slot says;
    `Input` / `Output` carry `id: null` and the names `IO_IN` / `IO_OUT`.
  * every plane is read by at least one slot (no committed plane is
    unaccounted for).
  * `len(terminals) == len(planes)` per slot PER STAGE, and the `j`-th
    private table of `arguments[s].tables` has the role of the `j`-th entry.
  * the `j`-th private table's slice offsets lie inside the plane's own row
    range -- which is what makes the identification a CHECK and not a
    relabelling.

AN OLD BUNDLE (`run-a-tame`, `run-b-zero`, written at stage 14) has no
`plane_index`.  [`plane_index_of`] returns `None` for it with a reason
string, and nothing else about such a bundle changes: the schema string did
not move, because adding the table is a pure addition.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

# the nine domains of `private_block::shape::Dom`, in the order `ALL_DOMS`
# declares them (`pad.rs`); a name outside this set is a refusal
DOMAINS = ("T", "Ht", "L", "D", "Q", "Kv", "S", "F", "Tab")

IO_NAMES = {"Input": "IO_IN", "Output": "IO_OUT"}

NO_TABLE = (
    "run.json carries no `plane_index` member: this bundle predates stage 15 "
    "of the Rust lane (2026-09-20), which added the plane index table.  The "
    "schema string did not move because the addition is pure, so the bundle "
    "is read exactly as before and only the per-slot terminal identity is "
    "affected"
)


class PlaneIndexError(ValueError):
    """The table contradicts itself or the bundle it is in."""


class Plane:
    """One committed plane: where it lives and what it is called."""

    __slots__ = ("role", "id", "name", "domain", "log_size", "rows",
                 "first_row", "offset", "im_first_row", "im_offset")

    def __init__(self, role, d):
        self.role = role
        self.id = d["id"]
        self.name = d["name"]
        self.domain = d["domain"]
        self.log_size = d["log_size"]
        self.rows = d["rows"]
        if role == "A":
            self.first_row = d["first_row"]
            self.offset = d["offset"]
            self.im_first_row = None
            self.im_offset = None
        else:
            self.first_row = d["re_first_row"]
            self.offset = d["re_offset"]
            self.im_first_row = d["im_first_row"]
            self.im_offset = d["im_offset"]

    def covers(self, offset: int, cols: int) -> bool:
        """Is `offset` inside one of this plane's row runs?  A slot may read a
        plane on a SUB-SLICE (`SC_TZC`'s nine limb sub-planes) or at a flipped
        coordinate, so the test is containment, never equality."""
        span = self.rows * cols
        if self.offset <= offset < self.offset + span:
            return True
        if self.im_offset is not None and self.im_offset <= offset < self.im_offset + span:
            return True
        return False

    def as_dict(self) -> dict:
        return {"role": self.role, "id": self.id, "name": self.name,
                "domain": self.domain, "rows": self.rows,
                "first_row": self.first_row, "log_size": self.log_size}


def _tile(intervals, total, what, findings):
    """`intervals` = [(first_row, rows, label)]; they must tile [0, total)."""
    order = sorted(intervals, key=lambda iv: iv[0])
    at = 0
    for first, rows, label in order:
        if rows <= 0:
            findings.append(f"{what}: {label} claims {rows} rows")
            return False
        if first != at:
            findings.append(
                f"{what}: {label} starts at row {first}, not {at} -- "
                + ("a gap" if first > at else "an overlap")
            )
            return False
        at = first + rows
    if at != total:
        findings.append(f"{what}: the planes tile {at} rows, the table declares {total}")
        return False
    return True


class PlaneIndex:
    """`run.json["plane_index"]`, checked against the bundle it came from."""

    def __init__(self, bundle):
        table = bundle.run.get("plane_index")
        if table is None:
            raise PlaneIndexError(NO_TABLE)
        self.bundle = bundle
        self.raw = table
        cols = bundle.shape.cols
        self.cols = cols
        self.a_data_rows = table["a_data_rows"]
        self.h_data_rows = table["h_data_rows"]
        self.findings: list[str] = []
        f = self.findings

        self.a_planes = [Plane("A", d) for d in table["a_planes"]]
        self.h_planes = [Plane("H", d) for d in table["h_planes"]]
        for role, planes in (("A", self.a_planes), ("H", self.h_planes)):
            for i, p in enumerate(planes):
                if p.id != i:
                    f.append(f"{role} plane {i} declares id {p.id}")
                if p.domain not in DOMAINS:
                    f.append(f"{role} plane {i} ({p.name}) has domain {p.domain!r}")
                if p.offset != p.first_row * cols:
                    f.append(
                        f"{role} plane {i} ({p.name}): offset {p.offset} is not "
                        f"first_row {p.first_row} * cols {cols}"
                    )
                if p.im_offset is not None and p.im_offset != p.im_first_row * cols:
                    f.append(
                        f"H plane {i} ({p.name}): im_offset {p.im_offset} is not "
                        f"im_first_row {p.im_first_row} * cols {cols}"
                    )

        # ---------------------------------------------------- the two tilings
        self.a_tiles = _tile(
            [(p.first_row, p.rows, f"A plane {p.id} ({p.name})") for p in self.a_planes],
            self.a_data_rows, "the A planes", f,
        )
        halves = []
        for p in self.h_planes:
            halves.append((p.first_row, p.rows, f"H plane {p.id} ({p.name}) re"))
            halves.append((p.im_first_row, p.rows, f"H plane {p.id} ({p.name}) im"))
        self.h_tiles = _tile(halves, self.h_data_rows, "the H plane halves", f)

        # ------------------------------ one log per domain, read not ported
        self.domain_log: dict[str, int] = {}
        for p in self.a_planes + self.h_planes:
            prev = self.domain_log.setdefault(p.domain, p.log_size)
            if prev != p.log_size:
                f.append(
                    f"domain {p.domain}: plane {p.name} has log_size {p.log_size}, "
                    f"another plane of the same domain has {prev}"
                )

        # ------------------------------- the totals against the shape section
        for st in bundle.stages:
            for role_name, want in (("A", self.a_data_rows), ("H", self.h_data_rows)):
                r = st.role_or_none(role_name)
                if r is None:
                    f.append(f"stage {st.index}: no {role_name} opening")
                    continue
                if r["data_rows"] != want:
                    f.append(
                        f"stage {st.index} {role_name}: the opening declares "
                        f"data_rows {r['data_rows']}, the plane index table {want}"
                    )

        # ------------------------------------------------------ the 23 slots
        self.slot_planes: list[list[Plane]] = []
        seen_a, seen_h = set(), set()
        for entry in table["slot_planes"]:
            s = entry["slot"]
            row = []
            for j, p in enumerate(entry["planes"]):
                role = p["role"]
                if role == "A":
                    if not isinstance(p["id"], int) or not 0 <= p["id"] < len(self.a_planes):
                        f.append(f"slot {s} entry {j}: A id {p['id']!r} is not a plane")
                        row.append(None)
                        continue
                    pl = self.a_planes[p["id"]]
                    seen_a.add(p["id"])
                elif role == "H":
                    if not isinstance(p["id"], int) or not 0 <= p["id"] < len(self.h_planes):
                        f.append(f"slot {s} entry {j}: H id {p['id']!r} is not a plane")
                        row.append(None)
                        continue
                    pl = self.h_planes[p["id"]]
                    seen_h.add(p["id"])
                elif role in IO_NAMES:
                    if p["id"] is not None:
                        f.append(f"slot {s} entry {j}: an IO plane carries id {p['id']!r}, not null")
                    if p["name"] != IO_NAMES[role]:
                        f.append(
                            f"slot {s} entry {j}: role {role} carries name {p['name']!r}, "
                            f"not {IO_NAMES[role]!r}"
                        )
                    row.append(_IoPlane(role, p["name"]))
                    continue
                else:
                    f.append(f"slot {s} entry {j}: role {role!r} is not one of the four")
                    row.append(None)
                    continue
                if pl.name != p["name"]:
                    f.append(
                        f"slot {s} entry {j}: id {p['id']} is {pl.name!r}, the entry "
                        f"says {p['name']!r}"
                    )
                row.append(pl)
            self.slot_planes.append(row)
        if len(self.slot_planes) != bundle.shape.n_slots:
            f.append(
                f"the table lists {len(self.slot_planes)} slots for the shape's "
                f"{bundle.shape.n_slots}"
            )
        unread_a = sorted(set(range(len(self.a_planes))) - seen_a)
        unread_h = sorted(set(range(len(self.h_planes))) - seen_h)
        if unread_a:
            f.append(
                "A planes read by no slot: "
                + ", ".join(f"{i} ({self.a_planes[i].name})" for i in unread_a)
            )
        if unread_h:
            f.append(
                "H planes read by no slot: "
                + ", ".join(f"{i} ({self.h_planes[i].name})" for i in unread_h)
            )
        self.planes_read_by_a_slot = not unread_a and not unread_h

        # ----------------------- the table against every stage's own slot list
        self.per_stage = []
        for st in bundle.stages:
            row = {"stage": st.index, "slots": 0, "terminals": 0,
                   "private_tables": 0, "slice_offsets_inside_the_plane": 0,
                   "slice_offsets_checked": 0}
            for arg in st.slots:
                s = arg["slot"]
                if s >= len(self.slot_planes):
                    f.append(f"stage {st.index}: slot {s} is outside the table")
                    continue
                planes = self.slot_planes[s]
                privs = [t for t in arg["tables"] if t["kind"] == "private"]
                if len(arg["terminals"]) != len(planes):
                    f.append(
                        f"stage {st.index} slot {s}: {len(arg['terminals'])} terminals "
                        f"for {len(planes)} planes in the table"
                    )
                    continue
                if len(privs) != len(planes):
                    f.append(
                        f"stage {st.index} slot {s}: {len(privs)} private tables "
                        f"for {len(planes)} planes in the table"
                    )
                    continue
                row["slots"] += 1
                row["terminals"] += len(arg["terminals"])
                row["private_tables"] += len(privs)
                for j, (tab, pl) in enumerate(zip(privs, planes)):
                    if pl is None:
                        continue
                    if tab["role"] != pl.role:
                        f.append(
                            f"stage {st.index} slot {s} table {j}: role {tab['role']!r}, "
                            f"the table says {pl.role!r}"
                        )
                        continue
                    if isinstance(pl, _IoPlane):
                        continue
                    for off, _coef in [(sl["offset"], sl["coefficient"]) for sl in tab["slices"]]:
                        row["slice_offsets_checked"] += 1
                        if pl.covers(off, cols):
                            row["slice_offsets_inside_the_plane"] += 1
                        else:
                            f.append(
                                f"stage {st.index} slot {s} table {j}: slice offset "
                                f"{off} is outside plane {pl.id} ({pl.name}), rows "
                                f"{pl.first_row}..{pl.first_row + pl.rows}"
                            )
            self.per_stage.append(row)

    # ------------------------------------------------------------- accessors
    def log(self, domain: str) -> int:
        """The domain's log AT THIS SHAPE, read from the table and not ported."""
        return self.domain_log[domain]

    def names(self, slot: int) -> list[str]:
        return [p.name if p is not None else "?" for p in self.slot_planes[slot]]

    def summary(self) -> dict:
        return {
            "present": True,
            "a_planes": len(self.a_planes),
            "h_planes": len(self.h_planes),
            "a_data_rows": self.a_data_rows,
            "h_data_rows": self.h_data_rows,
            "a_planes_tile_exactly": self.a_tiles,
            "h_plane_halves_tile_exactly": self.h_tiles,
            "every_plane_is_read_by_a_slot": self.planes_read_by_a_slot,
            "domain_logs": dict(sorted(self.domain_log.items())),
            "slots": len(self.slot_planes),
            "per_stage": self.per_stage,
            "findings": self.findings,
            "ok": not self.findings,
            "what_it_is_not": "the table says WHERE a plane lives and what it is "
            "called; it carries no plane content and is a function of the public "
            "shape alone",
        }


class _IoPlane:
    """The two IO commitments have no plane id: the claim site IS the plane."""

    __slots__ = ("role", "name", "id", "domain", "log_size", "rows")

    def __init__(self, role, name):
        self.role = role
        self.name = name
        self.id = None
        self.domain = None
        self.log_size = None
        self.rows = None

    def covers(self, offset, cols):  # pragma: no cover - never called
        return True

    def as_dict(self):
        return {"role": self.role, "id": None, "name": self.name}


def plane_index_of(bundle):
    """`(PlaneIndex, None)` for a stage-15 bundle, `(None, reason)` for an old
    one.  A malformed table raises; an ABSENT one is not an error."""
    if bundle.run.get("plane_index") is None:
        return None, NO_TABLE
    return PlaneIndex(bundle), None
