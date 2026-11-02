#!/usr/bin/env python3
"""[v25 STAGING, 2026-11-02] D55 (the D60 prerequisite) and D59 condition (5):
the v25 W16 gate's items on a D55 "commit, fork, join" FORK-RUN capture.

    python3 -B zk60_native_rg_d55.py --bundle <dir> --evidence <dir> [--name N] [--no-controls]

WHY A NEW MODULE.  A D55 capture is a new schema
(`hashline-native-capture/8-d55-fork-run-prototype`): `L` fork stage files,
each its own transcript forked from `S0`, and one TAIL file that opens every
internal boundary ONCE (both of its claims) and both external endpoints after
`S1`.  The run loader (`zk60_native_rg_bundle.RunBundle`) refuses the schema by
name, and the run replay (`zk60_native_rg_replay.RunReplay`) is D12a's one
transcript.  This module is ADDITIVE: it imports the generic machinery
unchanged (the stage file reader, the array store, the hash rule, the per-slot
replay body, `RunRoleView`, the mask / CFS stage, the exclusivity controls and
the W16 port in `zk60_native_rg_w16`) and adds only what is new: the D55
loader, the D55 transcript (the header under the D55 profile, phase 1's roots
and `S0`, `fork(S0, k)`, the join and `S1`, the tail), and the tail's
commitments in the per-commitment rank.  No v24 module, table or test is
edited.  The bundle is written by the TEST-ONLY
`w16_privacy_gate_tests::d55_privacy_gate_write_the_fork_bundles`
(`run_capture::write_bundle` refuses a fork-run bundle by design).

WHAT IT RUNS (one record part each):

  D55-0  load and integrity: the manifest (schema, kind, profile, blocks, every
         file's bytes and SHA-256, nothing unlisted), Goldilocks, the policy
         digest, run_shape_words, the transcript labels = the D55 set; per fork
         stage: slots against the shape, M's rows / specs / columns, the opening
         order M, A, H and NO boundary committed or opened; the tail: L - 1
         internal boundaries in order then the input and output endpoints, each
         opening's geometry and claim sources against run.json; the boundary
         table (committed in the head, opened in the tail, sites (k, 22) and
         (k + 1, 21)); the external endpoints against the policy; the receipt
         head (binding, L, the roots the tail opens) and every fork frame
         against its stage file's segment pins; no root opened twice
  D55-1/2 the facts: the block profile is a W16-family profile, the run
         profile is the D55 prefix over its TEST-ONLY W16 run identity, the D55
         parameter line and the D55 schedule digest recomputed from run.json's
         own lines (`run_fork.rs::schedule_lines`), the calibration line, and
         the PCS geometry of every regular opening (forks' A / H and the tail's
         boundaries and endpoints) and every M (`zk60_native_rg_w16.pcs_geometry`)
  D55-3  the draw replay: the header -> run_binding; phase 1 -> S0 (the head's
         S0 tag); each fork from S0 (`pb-run-fork`, `pb-run-fork-block`) through
         RunReplay's own per-slot / M / PCS body, its start and end tags; the
         join from S0 with every fork's replayed end state and the claims the
         tail opens -> S1 (= the tail's recorded header); the tail's openings;
         its end tag.  Every challenge re-derived and compared
  W16-4  the W16 layout census (unchanged)
  W16-5  SC_TAB's public tables per fork (unchanged)
  W16-6  PER COMMITMENT (rank): every fork's A and H and M, and every tail
         commitment (each boundary, both endpoints), by RunRoleView exactly as
         `run_gate.stage3` ranks a D12a run's; the pad block's exact rank on
         boundary 0; the exclusivity clauses' negative controls on fork 0's A /
         H and the tail's input endpoint and boundary 0
  W16-7  MASK / CFS on every fork and the six mask controls on fork 0
  D55-C  replay controls: a joined claim value moved by one in the tail, and
         a fork replayed without its index (review F2's mutation), are each
         REFUSED by the replay
  PINS   classified as `zk60_native_rg_w16.classify_pins` does; the D55 writer
         adds `run_fork.rs`, `run_fork_wire.rs` and the test file (unread)

STATUS.  "D55-DEV-PASS" when every part is true but some pin is unread (the
figures are computed, NOT admissible evidence).  "D55-PASS" only when every pin
is read too (not reachable at this tree).  "NOT-OK" otherwise.  NOTHING HERE IS
A PRIVACY STATEMENT OR AN ACCEPTANCE.

NOT HERE (owed): the W16 items `zk60_native_rg_w16` lists as not here (T-0 of
the W16 slots, NL-1, the joint checks across A_k / B_k / A_{k+1}, TS-1, the
hash census, the pins); and for D55 the run-level joint rank over the three
commitments that hold each interior plane (the D12a joint stage has no D55 port).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_bundle as RB  # noqa: E402
import zk60_native_rg_w16 as W  # noqa: E402
import zk60_native_rg_r13slots as R  # noqa: E402
from zk60_native_jv_field import f2_bytes, f2_from_list  # noqa: E402
from zk60_native_rg_arrays import ARRAY_STORE_FILE, ArrayRefused, ArrayStore, resolve_document  # noqa: E402
from zk60_native_rg_hashrule import rule_for_bundle  # noqa: E402
from zk60_native_rg_replay import RunReplay  # noqa: E402

SCHEMA_D55 = "hashline-native-capture/8-d55-fork-run-prototype"
TAIL_FILE = "d55_tail.json"
TAIL_KIND = "zk60-d55-tail-observations"
# run_fork.rs D55_PROFILE_PREFIX, D12A_LINE_TAIL, D55_LINE_TAIL
D55_PREFIX = "d55-commit-fork-join-runs/opt-in-prototype-unregistered/test-only/v1/"
D12A_LINE_TAIL = "/one-run-one-transcript"
D55_LINE_TAIL = "/d55-commit-fork-join-prototype-unregistered"
# run_fork.rs schedule_lines: the schedule digest's domain literal
D55_SCHEDULE_DOMAIN = b"hashline/private-run-fork-schedule/d55-prototype/1"
# run_capture.rs D55_TRANSCRIPT_LABELS, in order
D55_LABELS = (
    "run-shape", "expected-IO", "public-statement", "parameters", "calibration", "schedule",
    "pb-fork-commit-root", "B", "pb-fork-s0", "pb-run-fork", "pb-run-fork-block",
    "A", "M", "H", "rows", "log-cols", "pb-slot", "pb-scalar", "pb-term", "mask-q", "mask-prox",
    "pb-join-fork", "pb-join-state", "pb-join-in-claims", "pb-join-out-claims", "pb-fork-s1",
)
# run_fork_wire.rs encode_head: magic (8), binding (32), L (8), the L - 1 roots, the S0 tag (32)
HEAD_FIXED = 8 + 32 + 8 + 32
SC_IO_IN, SC_IO_OUT = 21, 22


def _read(path: str) -> bytes:
    with open(path, "rb") as fh:
        return fh.read()


# ---------------------------------------------------------------- the loader
class TailStage:
    """`d55_tail.json`: the openings after S1.  `index` is L (the tail's
    transcript_sites name stage L); `key_at(i)` names its i-th opening as the
    run gate names a D12a run's (`B{k}`, `E-Input`, `E-Output`)."""

    def __init__(self, path: str, blocks: int, store, refusals):
        with open(path, "rb") as fh:
            raw = fh.read()
        self.path = path
        self.name = os.path.basename(path)
        self.sha256 = hashlib.sha256(raw).hexdigest()
        self.bytes = len(raw)
        self.doc = json.loads(raw)
        d = self.doc
        if d.get("schema") != SCHEMA_D55 or d.get("kind") != TAIL_KIND:
            raise ValueError(f"{self.name}: schema/kind {d.get('schema')!r}/{d.get('kind')!r} is not {SCHEMA_D55!r}/{TAIL_KIND!r}")
        if d.get("blocks") != blocks:
            raise ValueError(f"{self.name}: declares {d.get('blocks')} blocks, not {blocks}")
        self.arrays_resolved = resolve_document(d, store, self.name, refusals) if store is not None else 0
        self.index = blocks

    @property
    def roles(self):
        return self.doc["roles"]

    def key_at(self, i: int) -> str:
        r = self.doc["roles"][i]
        if r["commitment_kind"] == "internal-boundary":
            return f"B{r['boundary']}"
        return f"E-{r['role']}"


class D55Bundle:
    """A D55 fork-run capture: run.json, L fork stage files, the tail, the
    array store, the receipt frames, the manifest.  The same attributes the
    generic parts read from a RunBundle (`run`, `shape`, `stages`, `store`,
    `hash_rule`, `manifest`, ...), plus `tail` and `head`."""

    def __init__(self, directory: str):
        self.dir = os.path.abspath(directory)
        with open(os.path.join(self.dir, "run.json"), "rb") as fh:
            raw = fh.read()
        self.run_sha256 = hashlib.sha256(raw).hexdigest()
        self.run_bytes = len(raw)
        self.run = json.loads(raw)
        d = self.run
        if d.get("schema") != SCHEMA_D55:
            raise ValueError(f"run.json: schema {d.get('schema')!r} is not {SCHEMA_D55!r}")
        self.schema = SCHEMA_D55
        if d.get("kind") != RB.RUN_KIND or d.get("coverage") != RB.COVERAGE:
            raise ValueError("run.json: kind / coverage are not a run capture's")
        if d["profile"] != d["transcript_domain"] or bytes(d["transcript_domain_bytes"]).decode() != d["profile"]:
            raise ValueError("run.json: the transcript domain is not the profile")
        self.profile = d["profile"]
        self.blocks = d["blocks"]
        self.boundaries = d["boundaries"]
        if self.boundaries != self.blocks - 1:
            raise ValueError(f"run.json: {self.boundaries} boundaries for {self.blocks} blocks")
        self.shape = RB.Shape(d["shape"], d["mask_domain"])
        with open(os.path.join(self.dir, "manifest.json"), "rb") as fh:
            self.manifest = json.loads(fh.read())
        self.array_refusals: list[str] = []
        listed = {e["file"]: e for e in self.manifest.get("files", [])}
        e = listed.get(ARRAY_STORE_FILE, {})
        self.store = None
        try:
            self.store = ArrayStore(os.path.join(self.dir, ARRAY_STORE_FILE), declared_bytes=e.get("bytes"), declared_sha256=e.get("sha256"))
        except ArrayRefused as exc:
            self.array_refusals.append(str(exc))
        want_files = [f"stage-{k:02d}.json" for k in range(self.blocks)] + [TAIL_FILE]
        if d["stage_files"] != want_files:
            raise ValueError(f"run.json: stage_files {d['stage_files']} are not {want_files}")
        self.stages = [RB.Stage(os.path.join(self.dir, fn), k, self.blocks, schema=SCHEMA_D55, store=self.store, refusals=self.array_refusals)
                       for k, fn in enumerate(want_files[:-1])]
        self.tail = TailStage(os.path.join(self.dir, TAIL_FILE), self.blocks, self.store, self.array_refusals)
        self.run_arrays_resolved = resolve_document(self.run, self.store, "run.json", self.array_refusals) if self.store is not None else 0
        self.hash_rule_record = rule_for_bundle(self)
        self.hash_rule = self.hash_rule_record["rule"]
        self.public_tables_included = bool(d.get("public_tables_included", False))
        head = os.path.join(self.dir, "receipt", "head.bin")
        self.head = _read(head) if os.path.exists(head) else None

    @property
    def name(self) -> str:
        return os.path.basename(self.dir)

    def boundary(self, k: int) -> dict:
        return self.run["internal_boundaries"][k]

    def labels(self) -> dict:
        return {t["label"]: t["what"] for t in self.run["transcript_labels"]}

    def boundary_roots(self) -> list:
        return [bytes(r["commitment"]["root"]) for r in self.tail.roles if r["commitment_kind"] == "internal-boundary"]

    def head_parts(self):
        """(binding, L, roots, S0 tag) of receipt/head.bin, or None"""
        h = self.head
        if h is None or len(h) != HEAD_FIXED + 32 * self.boundaries:
            return None
        l = int.from_bytes(h[40:48], "little")
        roots = [h[48 + 32 * k: 80 + 32 * k] for k in range(self.boundaries)]
        return h[8:40], l, roots, h[48 + 32 * self.boundaries:]


# ---------------------------------------------------------------- D55-0: integrity
def d55_integrity(b: D55Bundle) -> dict:
    f: list[str] = []
    man = b.manifest
    if man.get("schema") != SCHEMA_D55 or man.get("kind") != RB.MANIFEST_KIND:
        f.append(f"manifest.json: schema/kind {man.get('schema')!r}/{man.get('kind')!r}")
    if man.get("profile") != b.profile or man.get("blocks") != b.blocks:
        f.append("manifest.json: profile / blocks differ from run.json's")
    f.extend(b.array_refusals)
    listed = {e["file"]: e for e in man.get("files", [])}
    for fn, e in sorted(listed.items()):
        path = os.path.join(b.dir, fn)
        if not os.path.exists(path):
            f.append(f"{fn}: in the manifest, absent")
            continue
        raw = _read(path)
        if len(raw) != e["bytes"] or hashlib.sha256(raw).hexdigest() != e["sha256"]:
            f.append(f"{fn}: bytes / sha256 on disk differ from the manifest's")
    on_disk = set()
    for root, _dirs, files in os.walk(b.dir):
        for fn in files:
            on_disk.add(os.path.relpath(os.path.join(root, fn), b.dir))
    for fn in sorted(on_disk - set(listed) - {"manifest.json"}):
        f.append(f"{fn}: on disk, not in the manifest")
    if man.get("total_bytes") != sum(e["bytes"] for e in listed.values()):
        f.append("manifest.json: total_bytes")
    sh, d = b.shape, b.run
    if d["field_modulus"] != 0xFFFFFFFF00000001 or d["extension_nonresidue"] != 7:
        f.append("run.json: not Goldilocks with nonresidue 7")
    if hashlib.sha256(bytes(d["expected_policy"])).hexdigest() != d["expected_policy_sha256"]:
        f.append("run.json: expected_policy_sha256")
    if d["run_shape_words"] != [b.blocks, sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim]:
        f.append("run.json: run_shape_words")
    if [t["label"] for t in d["transcript_labels"]] != list(D55_LABELS):
        f.append("run.json: the transcript labels are not the D55 set")
    if sh.endpoint_log_n != sh.log_cols:
        f.append("the port ranks every commitment at the block's column count; this shape's endpoint row width differs")
    # the fork stages: a block's body, no boundary, no endpoint
    for st in b.stages:
        doc = st.doc
        if doc["log_cols"] != sh.log_cols or len(doc["arguments"]) != sh.n_slots:
            f.append(f"{st.name}: log_cols / slot count")
        for s, arg in enumerate(doc["arguments"]):
            if arg["slot"] != s or (arg["main"], arg["extension"], arg["degree"]) != sh.slots[s]:
                f.append(f"{st.name} slot {s}: not the shape's (main, extension, degree)")
        if bytes(doc["block_digest"]) != bytes(d["block_digests"][st.index]):
            f.append(f"{st.name}: block_digest")
        m = doc["mask"]
        if m["rows"] != 2 * sh.n_slots + 4 or len(m["specs"]) != sh.n_slots or len(m["columns"]) != sh.mask_columns:
            f.append(f"{st.name}: M rows / specs / columns")
        if doc["opening_order"] != ["M", "A", "H"] or [r["role"] for r in doc["roles"]] != ["A", "H"]:
            f.append(f"{st.name}: a fork opens {doc['opening_order']}, not M, A, H")
        if doc["boundary_committed"] is not None:
            f.append(f"{st.name}: a fork commits a boundary (a D55 run commits every boundary in its head)")
        if any(r["commitment_kind"] != "block" for r in doc["roles"]):
            f.append(f"{st.name}: a fork opens a non-block commitment")
        for r in doc["roles"]:
            if len(r["row_roles"]) != r["commitment"]["rows"] or len(r["proximity_rhos"]) != r["commitment"]["rows"]:
                f.append(f"{st.name} {r['role']}: row_roles / proximity_rhos != rows")
            if [x["kind"] for x in r["row_roles"]].count("prox") != 2:
                f.append(f"{st.name} {r['role']}: not two proximity rows")
    # the tail: every boundary once (both claims), then the two endpoints
    roles = b.tail.roles
    want = [("Input", "internal-boundary", k) for k in range(b.boundaries)] + [("Input", "external-endpoint", None), ("Output", "external-endpoint", None)]
    got = [(r["role"], r["commitment_kind"], r["boundary"]) for r in roles]
    if got != want:
        f.append(f"{TAIL_FILE}: opens {got}, a {b.blocks}-fork run opens {want}")
    if b.tail.doc["opening_order"] != [r for r, _k, _b in want]:
        f.append(f"{TAIL_FILE}: opening_order")
    sites = b.tail.doc["transcript_sites"]
    if [s["site"] for s in sites] != [f"{r} opening" for r, _k, _b in want] or any(s["stage"] != b.blocks for s in sites):
        f.append(f"{TAIL_FILE}: transcript_sites are not its openings in order at stage L")
    ee = d["external_endpoints"]
    if list(ee["opened_at_stage"]) != [b.blocks, b.blocks]:
        f.append("run.json: external_endpoints are not opened in the tail (stage L)")
    for k in range(b.boundaries):
        bd = b.boundary(k)
        if (bd["boundary"], bd["index"], bd["sites"], bd["row_rule"]) != (k, k + 1, 2, "data + 2*sites + 2"):
            f.append(f"boundary {k}: (boundary, index, sites, row rule)")
        if bd["rows"] != bd["data_rows"] + 2 * bd["sites"] + 2 or bd["site_rows"] != list(range(bd["data_rows"], bd["data_rows"] + 4)) or bd["prox_row"] != bd["data_rows"] + 4:
            f.append(f"boundary {k}: the derived geometry")
        if (bd["committed_at_stage"], bd["opened_at_stage"], bd["opening_in_stage_file"]) != (0, b.blocks, b.blocks):
            f.append(f"boundary {k}: not committed in the head and opened in the tail")
        if [(s["stage"], s["slot"]) for s in bd["claim_sites"]] != [(k, SC_IO_OUT), (k + 1, SC_IO_IN)]:
            f.append(f"boundary {k}: claim_sites")
        if k < len(roles) and roles[k]["commitment_kind"] == "internal-boundary":
            r = roles[k]
            if r["commitment"]["rows"] != bd["rows"] or r["site_rows"] != bd["site_rows"] or r["prox_row"] != bd["prox_row"]:
                f.append(f"boundary {k}: the tail opening's rows differ from run.json's")
            if [(s["stage"], s["slot"]) for s in r["claim_sources"]] != [(k, SC_IO_OUT), (k + 1, SC_IO_IN)] or len(r["claims"]) != sum(s["claims"] for s in r["claim_sources"]):
                f.append(f"boundary {k}: the tail opening's claim sources")
    for i, (name, rk, src) in ((b.boundaries, ("Input", "input_root", (0, SC_IO_IN))), (b.boundaries + 1, ("Output", "output_root", (b.blocks - 1, SC_IO_OUT)))):
        if i >= len(roles):
            continue
        r = roles[i]
        if bytes(r["commitment"]["root"]) != bytes(ee[rk]) or r["commitment"]["rows"] != ee["rows"] or r.get("data_rows") != ee["data_rows"]:
            f.append(f"{TAIL_FILE} {name}: the opened endpoint is not run.json's external_endpoints {rk}")
        if [(s["stage"], s["slot"]) for s in r["claim_sources"]] != [src]:
            f.append(f"{TAIL_FILE} {name}: claim_sources")
    from zk60_native_rg_block import parse_policy
    pol = parse_policy(bytes(d["expected_policy"]))
    if pol is None or (pol["input_root"], pol["output_root"]) != (list(ee["input_root"]), list(ee["output_root"])) or pol["context"] != list(d["context"]):
        f.append("run.json: the policy's roots / context are not external_endpoints'")
    # the receipt: the head carries the binding, L and exactly the roots the tail opens
    hp = b.head_parts()
    if hp is None:
        f.append("receipt/head.bin: absent or not 8 + 32 + 8 + 32 (L - 1) + 32 bytes")
    else:
        binding, l, roots, _s0 = hp
        if list(binding) != d["run_binding"] or l != b.blocks or roots != b.boundary_roots():
            f.append("receipt/head.bin: its binding / L / roots are not run.json's and the tail's")
    for st in b.stages:
        path = os.path.join(b.dir, "receipt", f"fork-{st.index:02d}.bin")
        if not os.path.exists(path):
            f.append(f"receipt/fork-{st.index:02d}.bin: absent")
            continue
        raw = _read(path)
        if len(raw) != st.doc["segment_bytes"] or hashlib.sha256(raw).hexdigest() != st.doc["segment_sha256"]:
            f.append(f"receipt/fork-{st.index:02d}.bin: not the frame {st.name} pins")
    # opened exactly once over the whole run
    seen = {}
    for st in b.stages:
        for r in st.roles:
            seen.setdefault(bytes(r["commitment"]["root"]).hex(), []).append(f"{st.name} {r['role']}")
    for i, r in enumerate(roles):
        seen.setdefault(bytes(r["commitment"]["root"]).hex(), []).append(f"tail {b.tail.key_at(i)}")
    twice = {k: v for k, v in seen.items() if len(v) > 1}
    for k, v in twice.items():
        f.append(f"the commitment {k[:16]} is opened more than once: {v}")
    f.extend(b.hash_rule_record["refusals"])
    return {"bundle": b.name, "schema": SCHEMA_D55, "profile": b.profile, "block_profile": d["block_profile"], "blocks": b.blocks,
            "boundaries": b.boundaries, "manifest_files_checked": len(listed), "array_store": b.store.summary() if b.store is not None else None,
            "tail_openings": [b.tail.key_at(i) for i in range(len(roles))], "distinct_roots_opened": len(seen),
            "any_root_opened_twice": bool(twice), "hash_rule": {k: v for k, v in b.hash_rule_record.items() if k != "rule"},
            "source_pins": man.get("source_pins", []), "findings": f, "ok": not f}


# ---------------------------------------------------------------- D55-1/2: the facts
def d55_schedule_digest(run: dict) -> dict:
    """run_fork.rs `schedule_lines` / `schedule_digest`, from run.json's own lines"""
    import blake3
    l = run["blocks"]
    lines = [run["parameter_line"]] + list(run["layout_description"])
    lines.append(f"phase 1 (commit): boundaries 0..{max(l - 1, 0)} committed in order on the run transcript, each root absorbed (pb-fork-commit-root, B), then pb-fork-s0 = {l}")
    for k in range(l):
        lines.append(f"fork {k:02d}: S0 then pb-run-fork {k} and pb-run-fork-block; the stage body and IO geometry of D12a's [{run['stage_lines'][k]}]")
    lines.append(f"phase 3 (join): forks 0..{l - 1} in order (pb-join-fork, pb-join-state, pb-join-in-claims, pb-join-out-claims), then pb-fork-s1 = {l}; open boundaries 0..{max(l - 1, 0)} once each (block k slot 22, then block k+1 slot 21), then the external input endpoint, then the external output endpoint")
    h = blake3.blake3()
    h.update(D55_SCHEDULE_DOMAIN)
    for s in lines:
        bs = s.encode()
        h.update(len(bs).to_bytes(8, "little"))
        h.update(bs)
    return {"what": "blake3('hashline/private-run-fork-schedule/d55-prototype/1' + length-framed parameter line, layout lines, phase 1, one fork line per block, phase 3) -- run_fork.rs schedule_lines",
            "lines": len(lines), "recomputed": h.hexdigest(), "run_json": bytes(run["schedule_digest"]).hex(),
            "equal": h.hexdigest() == bytes(run["schedule_digest"]).hex()}


def d55_facts(b: D55Bundle) -> dict:
    run = b.run
    sh = run["shape"]
    block = sh["profile"]
    if not W.is_w16_block_profile(block) or run.get("block_profile") != block:
        raise ValueError(f"D55-1: the block profile {block!r} is not a W16-family profile")
    if not b.profile.startswith(D55_PREFIX):
        raise ValueError(f"D55-1: the run profile does not carry the D55 prefix {D55_PREFIX!r}")
    base = b.profile[len(D55_PREFIX):]
    if W.W16_TEST_RUN_PROFILES.get(base) != block:
        raise ValueError(f"D55-1: the D55 base {base!r} is not the test-only W16 run identity of {block!r}")
    if not run["parameter_line"].endswith(D55_LINE_TAIL) or D12A_LINE_TAIL in run["parameter_line"]:
        raise ValueError("D55-2: the parameter line is not the D55 one (D12a's one-transcript claim replaced)")
    sd = d55_schedule_digest(run)
    if not sd["equal"]:
        raise ValueError(f"D55-2: run.json's schedule digest does not recompute from its own lines ({sd})")
    cal = R.parse_calibration_line(run["layout_description"])
    stack = W.W16_BLOCK_PROFILES[block][1]
    if cal["stack"] != stack or not (17 <= cal["gate_common"] <= 24):
        raise ValueError("D55-2: the calibration line's stack / gate shift")
    geom = W.pcs_geometry(b, block)
    inv_rate, q = W.pcs_geometry_of(block)
    for i, r in enumerate(b.tail.roles):
        W.check_opening_geometry(sh, f"{TAIL_FILE} #{i}", r, inv_rate, q)
    geom["regular_openings_checked"] += len(b.tail.roles)
    geom["tail_openings_checked"] = len(b.tail.roles)
    return {"block_profile": block, "name": W.W16_BLOCK_PROFILES[block][0], "run_profile": b.profile, "d55_base_run_profile": base,
            "run_profile_is_test_only": True, "stack": stack, "registry": cal["registry"], "base": cal["base"],
            "gate_shift": cal["gate_common"], "precision": cal["precision"], "wrho_s": int(sh["wrho_s"]),
            "log_cols": int(sh["log_cols"]), "d55_schedule_digest": sd, "pcs_geometry": geom}


# ---------------------------------------------------------------- D55-3: the replay
def claim_bytes(claims) -> bytes:
    """run_fork.rs `claim_bytes`: count, then per claim its value and parts
    (slice offset, size, coefficient, point)"""
    out = bytearray(len(claims).to_bytes(8, "little"))
    for c in claims:
        out += f2_bytes(f2_from_list(c["value"]))
        out += len(c["parts"]).to_bytes(8, "little")
        for p in c["parts"]:
            out += int(p["offset"]).to_bytes(8, "little") + int(p["log_size"]).to_bytes(8, "little")
            out += f2_bytes(f2_from_list(p["coefficient"]))
            out += len(p["point"]).to_bytes(8, "little")
            for x in p["point"]:
                out += f2_bytes(f2_from_list(x))
    return bytes(out)


def joined_claims(b: D55Bundle):
    """per fork k, (its slot-21 claims, its slot-22 claims), from the tail's
    openings and their claim sources: boundary k holds fork k's slot-22 claims
    then fork k+1's slot-21 claims; the input endpoint fork 0's slot-21, the
    output endpoint fork L-1's slot-22"""
    l = b.blocks
    ins, outs = [None] * l, [None] * l
    for r in b.tail.roles:
        at = 0
        for s in r["claim_sources"]:
            part = list(r["claims"][at: at + s["claims"]])
            at += s["claims"]
            (ins if s["slot"] == SC_IO_IN else outs)[s["stage"]] = part
    if any(x is None for x in ins + outs):
        raise ValueError("a fork's IO claims are not all opened in the tail")
    return ins, outs


class D55Replay(RunReplay):
    """The D55 transcript, from public data only: RunReplay's per-stage body
    (every slot, the M opening, the A and H openings) on each fork, with the
    header, phase 1, the fork derivation, the join and the tail of
    `run_fork.rs`.  `drop_fork_index` replays review F2's mutation (a
    control: it must fail)."""

    def __init__(self, bundle, drop_fork_index=False):
        super().__init__(bundle)
        self.tail_acc = {"role_lambdas": {}, "role_prox_rhos": {}, "role_indices": {}}
        self.drop_fork_index = drop_fork_index
        self.s0_tag_ok = None
        self.head_roots_ok = None
        self.s1_ok = None
        self.tail_end_ok = None
        self.fork_ends = []

    def _open_stage(self, tr, st, doc, tag):
        """a fork: its start tag only (the fork words were absorbed on the
        clone of S0 before the stage header was compared)"""
        start = self._position_tag(tr)
        if start != doc["start_tag"]:
            self._fail(f"{tag}: the fork's start tag is not this transcript position")
        if doc["boundary_committed"] is not None:
            self._fail(f"{tag}: a fork commits a boundary")
        return start

    def _close_stage(self, tr, st, doc, tag, start):
        """a fork's end tag; forks do not chain"""
        end = self._position_tag(tr)
        if end != doc["end_tag"]:
            self._fail(f"{tag}: the fork's end tag is not this transcript position")
        self.position_tags.append({"stage": st.index, "start_tag_ok": start == doc["start_tag"], "end_tag_ok": end == doc["end_tag"]})

    def _opening(self, tr, role, key, acc, tag) -> None:
        """one PCS opening's draws, exactly as RunReplay._stage replays a role"""
        self._check_state(tr, role["before"], f"{tag} before")
        lams = []
        for gi, g in enumerate(role["groups"]):
            lam = tr.challenge_fp2_vec(len(g["members"]))
            for j, want in enumerate(g["lambdas"]):
                self._eq_f2(lam[j], want, f"{tag} group {gi} lambda {j}")
            lams.append(lam)
        acc["role_lambdas"][key] = lams
        prox = tr.challenge_fp2_vec(role["commitment"]["rows"])
        for i, want in enumerate(role["proximity_rhos"]):
            self._eq_f2(prox[i], want, f"{tag} proximity rho {i}")
        acc["role_prox_rhos"][key] = prox
        for g in role["groups"]:
            tr.absorb_fp2(b"pcs-vec", [f2_from_list(v) for v in g["vector"]])
        tr.absorb_fp2(b"pcs-prox", [f2_from_list(v) for v in role["proximity_vector"]])
        p = role["params"]
        idx = tr.challenge_indices(p["num_col_checks"], (1 << p["log_cols"]) * p["inv_rate"])
        if idx != [c["index"] for c in role["columns"]]:
            self._fail(f"{tag}: sampled column indices differ")
        acc["role_indices"][key] = idx
        self._check_state(tr, role["after"], f"{tag} after")

    def run(self) -> "D55Replay":
        b = self.b
        d = b.run
        rule = getattr(b, "hash_rule", None)
        if rule is None:
            self._fail("the hash rule was refused for this bundle, so no replay was attempted")
            return self
        self.rule_name = rule.name
        tr = rule.transcript(bytes(d["transcript_domain_bytes"]))
        tr.absorb(b"run-shape", b"".join(int(v).to_bytes(8, "little") for v in d["run_shape_words"]))
        tr.absorb(b"expected-IO", bytes(d["expected_policy"]))
        tr.absorb(b"public-statement", bytes(d["public_statement_digest"]))
        tr.absorb(b"parameters", d["parameter_line"].encode())
        tr.absorb(b"calibration", bytes(d["calibration"]))
        tr.absorb(b"schedule", bytes(d["schedule_digest"]))
        self.checkpoints += 1
        self.run_binding_ok = list(tr.state) == d["run_binding"]
        if not self.run_binding_ok:
            self._fail("run header: the state after the header is not run_binding")
        # ---- phase 1: every boundary root (the ones the tail opens), then S0
        roots = b.boundary_roots()
        if len(roots) != b.boundaries:
            self._fail("phase 1: the tail does not open every boundary")
        for k, root in enumerate(roots):
            bd = b.boundary(k)
            tr.absorb_u64(b"pb-fork-commit-root", k)
            self._absorb_root(tr, b"B", root, bd["rows"], bd["log_n"])
        tr.absorb_u64(b"pb-fork-s0", b.blocks)
        s0 = tr.clone()
        hp = b.head_parts()
        if hp is not None:
            self.s0_tag_ok = self._position_tag(s0) == list(hp[3])
            self.head_roots_ok = hp[2] == roots
            if not self.s0_tag_ok:
                self._fail("phase 1: the head's S0 tag is not this replay's S0")
            if not self.head_roots_ok:
                self._fail("phase 1: the head's roots are not the roots the tail opens")
        # ---- phase 2: each fork from S0
        for st in b.stages:
            f = s0.clone()
            if not self.drop_fork_index:
                f.absorb_u64(b"pb-run-fork", st.index)
            f.absorb(b"pb-run-fork-block", bytes(st.doc["block_digest"]))
            self._stage(f, st)
            self.fork_ends.append((bytes(f.state), f.counter))
        # ---- phase 3: the join on the run transcript (from S0), then S1
        try:
            ins, outs = joined_claims(b)
        except ValueError as exc:
            self._fail(f"join: {exc}")
            return self
        for k, (state, counter) in enumerate(self.fork_ends):
            tr.absorb_u64(b"pb-join-fork", k)
            tr.absorb(b"pb-join-state", state + int(counter).to_bytes(8, "little"))
            tr.absorb(b"pb-join-in-claims", claim_bytes(ins[k]))
            tr.absorb(b"pb-join-out-claims", claim_bytes(outs[k]))
        tr.absorb_u64(b"pb-fork-s1", b.blocks)
        before = len(self.failures)
        self._check_state(tr, b.tail.doc["header"], "S1 (the tail's header)")
        self.s1_ok = len(self.failures) == before
        # ---- the tail: every boundary once, then the two endpoints
        sites = b.tail.doc["transcript_sites"]
        for i, role in enumerate(b.tail.roles):
            key = b.tail.key_at(i)
            if i < len(sites) and (sites[i]["before"] != role["before"] or sites[i]["after"] != role["after"]):
                self._fail(f"tail {key}: the opening's site index differs from its positions")
            self._opening(tr, role, key, self.tail_acc, f"tail {key}")
        end = self._position_tag(tr)
        self.tail_end_ok = end == b.tail.doc["end_tag"]
        if not self.tail_end_ok:
            self._fail("tail: the end tag is not this transcript position")
        self.final_counter = tr.counter
        return self

    def summary(self) -> dict:
        s = super().summary()
        s.update({"what": "the D55 transcript re-derived: header -> run_binding, phase 1 -> S0, L forks from S0, the join -> S1, the tail",
                  "s0_tag_reproduced": self.s0_tag_ok, "head_roots_are_the_tail_roots": self.head_roots_ok,
                  "s1_reproduced": self.s1_ok, "tail_end_tag_reproduced": self.tail_end_ok,
                  "tail_openings_replayed": len(self.tail_acc["role_indices"]), "fork_index_dropped": self.drop_fork_index})
        return s


# ---------------------------------------------------------------- W16-6 at a D55 run
class _ControlStage:
    """fork 0's A and H with the tail's input endpoint, under the keys
    `exclusivity_controls` asks stage 0 for"""

    def __init__(self, st0):
        self.st0 = st0

    def key(self, name: str) -> str:
        return "E-Input" if name == "Input" else self.st0.key(name)


class _ControlBundle:
    def __init__(self, b):
        self.stages = [_ControlStage(b.stages[0])]


def d55_stage3(b: D55Bundle, rp: D55Replay, do_controls=True) -> dict:
    """`run_gate.stage3` at a D55 run: every fork's A and H, every tail
    commitment and every fork's M, ranked exactly as D12a's are"""
    from zk60_native_rg_exclusivity import exclusivity_controls
    from zk60_native_rg_joint import RunJointSystem, mask_block
    from zk60_native_rg_pcs import RunRoleView
    import zk60_native_run_gate as RG
    views, rows = {}, []

    def one(st, role, key, acc):
        v = RunRoleView(st, role, acc["role_prox_rhos"][key], b.shape, name=key)
        f = dict(v.run(acc["role_lambdas"][key]))
        views[key] = v
        f.pop("xi_vectors", None)
        f.pop("data_rows_index", None)
        f["site_role"] = role["role"]
        f["expected_disclosed_dimension"] = RG.expected_for(v)
        f["meets_expectation"] = f["disclosed_dimension"] == f["expected_disclosed_dimension"]
        rows.append(f)
    for st in b.stages:
        for role in st.roles:
            one(st, role, st.key(role["role"]), rp.stages[st.index])
    for i, role in enumerate(b.tail.roles):
        one(b.tail, role, b.tail.key_at(i), rp.tail_acc)
    masks = []
    for st in b.stages:
        blk = mask_block(st)
        dd = RunJointSystem([blk]).disclosed(msg_width=b.shape.cols)
        masks.append({"commitment": blk.name, "rows": blk.rows, "disclosed_dimension": dd["disclosed_fp"],
                      "expected_disclosed_dimension": RG.EXPECTED_DISCLOSED["M"], "opened_columns": len(st.mask["columns"]),
                      "meets_expectation": dd["disclosed_fp"] == RG.EXPECTED_DISCLOSED["M"]})
    pad = None
    if "B0" in views:
        t0 = time.time()
        r, dd = views["B0"].pad_block_rank()
        pad = {"commitment": "B0", "distinct_columns": dd, "pad_positions": views["B0"].pad_len,
               "exact_rank_of_the_pad_block": r, "full_rank": r == dd, "seconds": round(time.time() - t0, 1)}
    ok = all(
        r["findings"] == [] and all(r["reduction_hypotheses"].values()) and r["column_identity_failures"] == 0
        and r["group_claim_identity_failures"] == 0 and r["meets_expectation"]
        and r["certifying_minor"]["full_row_rank"] and r["certifying_minor"]["determinant_nonzero"]
        and r["distinct_opened_columns_within_pad_count"]
        for r in rows
    ) and all(m["meets_expectation"] for m in masks)
    xc = exclusivity_controls(_ControlBundle(b), views) if do_controls else {"skipped": "controls not requested", "ok": True}
    return {"per_commitment": rows, "masking_commitments": masks, "expected": RG.EXPECTED_DISCLOSED,
            "pad_block_exact_rank_cross_check": pad, "exclusivity_controls": xc,
            "per_slot_terminal_check": {"status": "the W16 slots' terminal identity is not ported (owed)"},
            "ok": ok and (pad is None or pad["full_rank"]) and xc["ok"]}


# ---------------------------------------------------------------- D55-C: replay controls
def replay_controls(b: D55Bundle) -> dict:
    out = {}
    # C1: one joined claim value moved by one in the tail: S1 must not reproduce
    claim = b.tail.roles[0]["claims"][0]
    old = claim["value"]
    claim["value"] = [(old[0] + 1) % W.P, old[1]]
    try:
        r1 = D55Replay(b).run()
    finally:
        claim["value"] = old
    out["C1 a joined claim value moved"] = {"replay_failures": len(r1.failures), "s1_reproduced": r1.s1_ok,
                                            "first": r1.failures[:2], "fires": bool(r1.failures) and r1.s1_ok is False}
    # C2: every fork replayed without its index (review F2's mutation)
    r2 = D55Replay(b, drop_fork_index=True).run()
    out["C2 the fork index dropped"] = {"replay_failures": len(r2.failures), "first": r2.failures[:2], "fires": bool(r2.failures)}
    out["ok"] = all(v["fires"] for v in out.values() if isinstance(v, dict))
    return out


# ---------------------------------------------------------------- the driver
def d55_gate(bundle_dir: str, controls=True, r19b_manifest=None) -> dict:
    import zk60_native_rg_mask as M
    from zk60_native_rg_mcontrols import mask_controls_at_shape
    t0 = time.time()
    b = D55Bundle(bundle_dir)
    rec = {"gate": "zk60-native-d55-gate", "version": 1, "staging": "v25", "privacy_property_established": False,
           "privacy_acceptance": False, "bundle": b.name, "bundle_dir": b.dir, "profile": b.profile,
           "what_this_is": "the v25 W16 gate's items on ONE D55 fork-run capture (test-only run identity, synthetic public "
                           "weights, unregistered prototype), at that run's real challenges; NOT a privacy statement"}
    parts = {}
    rec["D55-0 integrity"] = d55_integrity(b)
    parts["D55-0 integrity"] = rec["D55-0 integrity"]["ok"]
    try:
        facts = d55_facts(b)
        rec["D55-1/2 facts"] = facts
        parts["D55-1/2 facts"] = True
    except ValueError as exc:
        rec["D55-1/2 facts"] = {"refused": str(exc), "ok": False}
        rec.update({"status": "REFUSED", "parts": {**parts, "D55-1/2 facts": False}, "seconds": round(time.time() - t0, 1)})
        return rec
    rp = D55Replay(b).run()
    rec["D55-3 replay"] = rp.summary()
    parts["D55-3 replay"] = rec["D55-3 replay"]["ok"]
    rec["W16-4 layout"] = W.check_layout(b, facts)
    parts["W16-4 layout"] = rec["W16-4 layout"]["ok"]
    tabs = [W.check_tab_tables(b, facts, k) for k in range(b.blocks)]
    rec["W16-5 tab tables"] = {"per_fork": tabs, "ok": all(t["ok"] for t in tabs)}
    if controls:
        rec["W16-5 tab tables"]["control"] = W.tab_control(b, facts)
        rec["W16-5 tab tables"]["ok"] = rec["W16-5 tab tables"]["ok"] and rec["W16-5 tab tables"]["control"]["ok"]
    parts["W16-5 tab tables"] = rec["W16-5 tab tables"]["ok"]
    if parts["D55-3 replay"]:
        rec["W16-6 per commitment"] = d55_stage3(b, rp, do_controls=controls)
        parts["W16-6 per commitment"] = rec["W16-6 per commitment"]["ok"]
        stages = [M.mask_cfs_stage(b, rp, k) for k in range(b.blocks)]
        mc = {"per_fork": stages, "ok": all(s.get("ok") for s in stages),
              "entries_recomputed": sum((s.get("entries_recomputed") or {}).get("total", 0) for s in stages),
              "entries_differing": sum((s.get("entries_recomputed") or {}).get("differing", 0) for s in stages),
              "salted_leaves_authenticated": sum((s.get("entries_recomputed") or {}).get("salted_leaves_authenticated", 0) for s in stages)}
        if controls:
            mc["controls"] = mask_controls_at_shape(b, rp, k=0)
            mc["ok"] = bool(mc["ok"] and mc["controls"].get("ok", False))
        rec["W16-7 mask and CFS"] = mc
        parts["W16-7 mask and CFS"] = mc["ok"]
    else:
        parts["W16-6 per commitment"] = parts["W16-7 mask and CFS"] = False
    if controls:
        rec["D55-C replay controls"] = replay_controls(b)
        parts["D55-C replay controls"] = rec["D55-C replay controls"]["ok"]
    pins = W.classify_pins(b, r19b_manifest if r19b_manifest is not None else W.default_r19b_manifest())
    rec["PINS"] = pins
    rec["parts"] = parts
    all_true = all(parts.values())
    rec["status"] = "D55-PASS" if all_true and pins["ok"] else "D55-DEV-PASS" if all_true else "NOT-OK"
    rec["status_means"] = {"D55-PASS": "every part true and every pin read",
                           "D55-DEV-PASS": "every part true, but some pin is unread: computed figures, NOT admissible evidence",
                           "NOT-OK": "some part is false"}[rec["status"]]
    rec["not_here"] = ["T-0 terminal identity of the seven W16-redefined slots", "NL-1 S1-S5 on them",
                       "joint checks (D12a's joint stage, and for D55 the joint rank over A_k / B_k / A_{k+1})",
                       "TS-1 and the claim census", "full preimage", "hash census", "the reading of the unread pins"]
    rec["tool_sha256"] = W.tool_hashes()
    rec["seconds"] = round(time.time() - t0, 1)
    return rec


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name")
    ap.add_argument("--no-controls", action="store_true")
    ap.add_argument("--r19b-manifest")
    a = ap.parse_args(argv)
    rec = d55_gate(a.bundle, controls=not a.no_controls, r19b_manifest=a.r19b_manifest)
    os.makedirs(a.evidence, exist_ok=True)
    name = a.name or os.path.basename(os.path.normpath(a.bundle))
    path = os.path.join(a.evidence, f"d55-{name}.json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
    for kk, v in rec.get("parts", {}).items():
        print(f"{kk}: {'PASS' if v else 'FAIL'}")
    pins = rec.get("PINS", {})
    print(f"pins: {pins.get('pins')} declared, {pins.get('at_r19b')} at r19b, {len(pins.get('read_here', []))} read here, "
          f"{len(pins.get('unread', []))} UNREAD")
    print(f"status: {rec.get('status')} ({rec.get('seconds')} s) -> {path}")
    return 0 if rec.get("status") in ("D55-PASS", "D55-DEV-PASS") else 1


if __name__ == "__main__":
    raise SystemExit(main())
