#!/usr/bin/env python3
"""[GATE ROUND 7, 2026-10-19] The privacy gate on a TOKEN-I/O run capture
(schema `hashline-native-capture/6-token-run`): stage IN, the L block stages,
stage OUT, under one transcript.

WHAT IT REUSES, AND HOW.  Every rank, mask and hash computation is the gate's
existing, frozen machinery (`zk60_native_rg_pcs.RunRoleView`,
`zk60_native_run_gate.stage3`'s per-commitment model, `zk60_native_rg_joint`'s
mask block, `zk60_native_rg_mask`'s CFS port, `zk60_native_rg_hashlayer`).  Three
things are new and live here:

1. **The loader** (`TokenRunBundle`).  Schema 6, coverage
   `token-run-all-stages-v1`, `L + 2` stage files with `stage_kind` IN /
   BLOCK / OUT, boundaries in TOKEN numbering (0 = B_in, L = B_out), the
   `token_io` facts.  The array store is schema 5's.
2. **The replay** (`TokenRunReplay`).  `zk60_native_rg_replay.RunReplay` with
   the token stages' two prefixes (READ, `token_io/stage_in.rs:422-431`,
   `stage_out.rs` verify; `run.json["transcript_program"]`):
   * stage IN draws THREE LogUp challenges and then `clog2(d_pad)` more, the
     column point `r_emb`, before `H`;
   * stage OUT draws TWO (gamma, alpha), not three;
   * the slot sites of a new stage are ITS slots (4 / 11), not the block's
     23.
   Every challenge is re-derived and compared, as for a block run.
3. **The role adapter.**  The generic per-commitment model reads the row
   width from a SHAPE and the expected group count from a role NAME.  A new
   commitment is therefore handed to it with a per-opening shape built from
   that opening's own `params`, and with its canonical role:
   * `A-in` / `A-out` as an A, and `H-in` / `H-out` as an H, with the group
     counts the token code declares
     (`stage_in.rs` A_GROUPS 3 / H_GROUPS 4, `stage_out.rs` 18 / 6);
   * `E-token-*` as an external endpoint (one group);
   * `B-in` / `B-out` as internal boundaries (one group per site).

   The record keeps the original names.

NOTHING HERE IS A PRIVACY RESULT.
"""

from __future__ import annotations

import copy
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_rg_arrays import ARRAY_STORE_FILE, ArrayRefused, ArrayStore, resolve_document  # noqa: E402
from zk60_native_rg_bundle import Shape, Stage, MANIFEST_KIND  # noqa: E402
from zk60_native_rg_hashrule import rule_for_bundle  # noqa: E402
from zk60_native_rg_replay import RunReplay  # noqa: E402
import zk60_native_rg_tokenio as TIO  # noqa: E402

SCHEMA_6 = "hashline-native-capture/6-token-run"
RUN_KIND = "zk60-run-verifier-observations"
STAGE_KIND = "zk60-run-stage-observations"
COVERAGE_6 = "token-run-all-stages-v1"
STAGE_KINDS = ("IN", "BLOCK", "OUT")
# the opening order of each stage kind (READ, run.json transcript_program and
# the stage verifiers): a block stage opens M A H then the boundary before it
ORDER = {
    "IN": ["M", "A-in", "H-in", "E-token-in"],
    "BLOCK": ["M", "A", "H", "Input"],
    "OUT": ["M", "A-out", "H-out", "B-out", "E-token-out"],
}
# the token code's declared opening groups (distinct column keys)
GROUPS = {"A-in": 3, "H-in": 4, "A-out": 18, "H-out": 6}
CANON = {
    "A-in": ("A", "stage-in"), "H-in": ("H", "stage-in"),
    "A-out": ("A", "stage-out"), "H-out": ("H", "stage-out"),
    "E-token-in": ("Input", "external-endpoint"), "E-token-out": ("Output", "external-endpoint"),
    "B-out": ("Output", "internal-boundary"),
}
# expected disclosed dimension per CLASS (the block's values, EXPECTED_DISCLOSED):
# an A discloses 0, an H the 2 of its public LogUp identity, every endpoint and
# boundary 0
EXPECTED = {"A": 0, "H": 2, "endpoint": 0, "boundary": 0}


class TokenStage(Stage):
    """A token-run stage file: a block stage's content plus `stage_kind` and,
    for IN / OUT, its `stage_plane_index`."""

    def __init__(self, path, index, stages, store, refusals):
        # `Stage.__init__` checks `blocks` against its argument; a token stage
        # declares the run's L there, so the check is made against L below
        with open(path, "rb") as fh:
            raw = fh.read()
        self.path, self.name = path, os.path.basename(path)
        self.sha256, self.bytes = hashlib.sha256(raw).hexdigest(), len(raw)
        self.doc = json.loads(raw)
        d = self.doc
        if d.get("schema") != SCHEMA_6:
            raise ValueError(f"{self.name}: schema {d.get('schema')!r} is not {SCHEMA_6!r}")
        self.arrays_resolved = resolve_document(d, store, self.name, refusals) if store else 0
        if d.get("kind") != STAGE_KIND:
            raise ValueError(f"{self.name}: kind {d.get('kind')!r}")
        if d.get("stage") != index or d.get("stages") != stages:
            raise ValueError(f"{self.name}: declares stage {d.get('stage')} of {d.get('stages')}, not {index} of {stages}")
        if d.get("stage_kind") not in STAGE_KINDS:
            raise ValueError(f"{self.name}: stage_kind {d.get('stage_kind')!r}")
        self.index = index
        self.kind = d["stage_kind"]

    def key(self, role_name: str) -> str:
        """Commitment names.  Boundaries in TOKEN numbering: `B0` = B_in
        (opened at block 0's stage as `Input`), `B{L}` = B_out."""
        r = self.role(role_name)
        if r.get("boundary") is not None:
            return f"B{r['boundary']}"
        if role_name.startswith("E-token"):
            return role_name
        return f"{role_name}@{self.index}"


class TokenRunBundle:
    """A token-run capture: the run header, `token_io`, L + 2 stages."""

    def __init__(self, directory: str):
        self.dir = os.path.abspath(directory)
        with open(os.path.join(self.dir, "run.json"), "rb") as fh:
            raw = fh.read()
        self.run_sha256, self.run_bytes = hashlib.sha256(raw).hexdigest(), len(raw)
        self.run = d = json.loads(raw)
        if d.get("schema") != SCHEMA_6:
            raise ValueError(f"run.json: schema {d.get('schema')!r} is not {SCHEMA_6!r}")
        self.schema = SCHEMA_6
        if d.get("kind") != RUN_KIND or d.get("coverage") != COVERAGE_6:
            raise ValueError("run.json: kind / coverage is not a token run's")
        if d["profile"] != d["transcript_domain"] or bytes(d["transcript_domain_bytes"]).decode() != d["profile"]:
            raise ValueError("run.json: the transcript domain is not the profile")
        self.profile = d["profile"]
        self.l = d["blocks"]
        self.n_stages = d["stages"]
        if self.n_stages != self.l + 2:
            raise ValueError(f"run.json: {self.n_stages} stages for {self.l} blocks (a token run has L + 2)")
        if d["boundaries"] != self.l + 1:
            raise ValueError(f"run.json: {d['boundaries']} boundaries for L = {self.l} (a token run has L + 1: B_in .. B_out)")
        self.shape = Shape(d["shape"], d["mask_domain"])
        with open(os.path.join(self.dir, "manifest.json"), "rb") as fh:
            self.manifest = json.loads(fh.read())
        self.array_refusals: list[str] = []
        listed = {e["file"]: e for e in self.manifest.get("files", [])}
        e = listed.get(ARRAY_STORE_FILE, {})
        try:
            self.store = ArrayStore(os.path.join(self.dir, ARRAY_STORE_FILE),
                                    declared_bytes=e.get("bytes"), declared_sha256=e.get("sha256"))
        except ArrayRefused as exc:
            self.store = None
            self.array_refusals.append(str(exc))
        self.stages = [TokenStage(os.path.join(self.dir, fn), k, self.n_stages, self.store,
                                  self.array_refusals) for k, fn in enumerate(d["stage_files"])]
        for st in self.stages:
            if st.doc.get("blocks") != self.l:
                raise ValueError(f"{st.name}: declares {st.doc.get('blocks')} blocks, not {self.l}")
        self.run_arrays_resolved = resolve_document(self.run, self.store, "run.json",
                                                    self.array_refusals) if self.store else 0
        self.hash_rule_record = rule_for_bundle(self)
        self.hash_rule = self.hash_rule_record["rule"]
        self.public_tables_included = bool(d.get("public_tables_included", False))
        # the replay's per-stage accumulator is sized by `blocks`
        self.blocks = self.n_stages
        ti = d["token_io"]
        self.geom = TIO.TokenGeom(name=d["profile"], tokens=ti["T"], t_pad=ti["t_pad"], d=ti["d"],
                                  d_pad=ti["d_pad"], v=ti["V"], block_log_n=self.shape.endpoint_log_n,
                                  block_inv_rate=self.shape.endpoint_inv_rate)

    @property
    def name(self) -> str:
        return os.path.basename(self.dir)

    def labels(self) -> dict:
        return {t["label"]: t["what"] for t in self.run["transcript_labels"]}


# ------------------------------------------------------------------ replay
class TokenRunReplay(RunReplay):
    """`RunReplay` with the token stages' prefixes (see the module doc)."""

    def _stage(self, tr, st):  # noqa: C901 (the parent's body, three changes marked)
        from zk60_native_jv_field import f2_from_list
        sh = self.b.shape
        k, doc, acc = st.index, st.doc, self.stages[st.index]
        tag = f"stage {k} ({st.kind})"
        self._check_state(tr, doc["header"], f"{tag} header")
        start = self._open_stage(tr, st, doc, tag)
        self._absorb_root(tr, b"A", doc["a_root"], doc["a_rows"], doc["log_cols"])
        tr.absorb(b"M", bytes(doc["mask_root"]))
        # [TOKEN 1] the LogUp challenge count is the stage kind's: 3 for IN and
        # a block, 2 for OUT (`stage_out.rs`: gamma, alpha)
        want_n = {"IN": 3, "BLOCK": 3, "OUT": 2}[st.kind]
        if len(doc["logup_challenges"]) != want_n:
            self._fail(f"{tag}: {len(doc['logup_challenges'])} LogUp challenges recorded, the stage draws {want_n}")
        logup = tr.challenge_fp2_vec(want_n)
        for i, want in enumerate(doc["logup_challenges"][:want_n]):
            self._eq_f2(logup[i], want, f"{tag} LogUp challenge {i}")
        acc["logup"] = logup
        # [TOKEN 2] stage IN draws the column point r_emb (clog2(d_pad) Fp2)
        # BEFORE H (`stage_in.rs:429`)
        if st.kind == "IN":
            n_emb = TIO.clog2(self.b.geom.d_pad)
            if doc.get("r_emb") is None or len(doc["r_emb"]) != n_emb:
                self._fail(f"{tag}: r_emb has {None if doc.get('r_emb') is None else len(doc['r_emb'])} entries, the stage draws {n_emb}")
            r_emb = tr.challenge_fp2_vec(n_emb)
            for i, want in enumerate((doc.get("r_emb") or [])[:n_emb]):
                self._eq_f2(r_emb[i], want, f"{tag} r_emb {i}")
            acc["r_emb"] = r_emb
        elif doc.get("r_emb"):
            self._fail(f"{tag}: a {st.kind} stage records a non-empty r_emb")
        self._absorb_root(tr, b"H", doc["h_root"], doc["h_rows"], doc["log_cols"])
        sites = self._sites_of(doc, k, tag, n_slots=len(st.slots))
        for arg in st.slots:
            s = arg["slot"]
            site = sites.get((k, f"slot {s:02d}"))
            if site is None:
                self._fail(f"{tag}: slot {s} is not in the stage's transcript_sites index")
            else:
                self._check_state(tr, site["before"], f"{tag} slot {s} site before")
            self._check_state(tr, arg["before_definition"], f"{tag} slot {s} before_definition")
            drawn = []
            for i, want in enumerate(arg["definition_challenges"]):
                dv = tr.challenge_fp2()
                self._eq_f2(dv, want, f"{tag} slot {s} definition draw {i}")
                drawn.append(dv)
            acc["def_challenges"][s] = drawn
            self._check_state(tr, arg["before"], f"{tag} slot {s} before")
            tr.absorb_u64(b"pb-slot", s)
            c = tr.challenge_fp2()
            self._eq_f2(c, arg["c"], f"{tag} slot {s} mask challenge c")
            acc["slot_c"][s] = f2_from_list(arg["c"])
            tr.absorb_fp2(b"pb-scalar", [f2_from_list(arg["scalar"])])
            rhos = []
            for j, rnd in enumerate(arg["rounds"]):
                tr.absorb_fp2(b"sc-round", [f2_from_list(v) for v in rnd])
                r = tr.challenge_fp2()
                self._eq_f2(r, arg["rho"][j], f"{tag} slot {s} round {j} challenge")
                rhos.append(r)
            if len(rhos) != len(arg["rho"]):
                self._fail(f"{tag} slot {s}: {len(rhos)} rounds for {len(arg['rho'])} challenges")
            acc["rho"][s] = rhos
            tr.absorb_fp2(b"pb-term", [f2_from_list(v) for v in arg["terminals"]])
            self._check_state(tr, arg["after"], f"{tag} slot {s} after")
            if site is not None:
                self._check_state(tr, site["after"], f"{tag} slot {s} site after")
        m = st.mask
        m_site = sites.get((k, "M opening"))
        if m_site is None:
            self._fail(f"{tag}: the M opening is not in the transcript_sites index")
        elif m_site["before"] != m["before"] or m_site["after"] != m["after"]:
            self._fail(f"{tag}: the M opening's site index differs from its own positions")
        self._check_state(tr, m["before"], f"{tag} M before")
        theta = tr.challenge_fp2()
        self._eq_f2(theta, m["theta"], f"{tag} M theta")
        acc["theta"] = theta
        tr.absorb_fp2(b"mask-q", [f2_from_list(v) for v in m["q"]])
        rhos = tr.challenge_fp2_vec(2 * len(m["specs"]) + 2)
        for i, want in enumerate(m["proximity_rhos"]):
            self._eq_f2(rhos[i], want, f"{tag} M proximity rho {i}")
        acc["mask_prox_rhos"] = rhos
        tr.absorb_fp2(b"mask-prox", [f2_from_list(v) for v in m["prox"]])
        idx = tr.challenge_indices(sh.mask_columns, 1 << sh.mask_log_dom)
        if idx != [c["index"] for c in m["columns"]]:
            self._fail(f"{tag} M: sampled column indices differ")
        acc["mask_indices"] = idx
        self._check_state(tr, m["after"], f"{tag} M after")
        order = doc["opening_order"]
        # [TOKEN 3] the opening order is the stage kind's, checked by name
        if order != ORDER[st.kind]:
            self._fail(f"{tag}: opening_order {order} is not the {st.kind} stage's {ORDER[st.kind]}")
        if [r["role"] for r in st.roles] != order[1:]:
            self._fail(f"{tag}: the roles array does not follow opening_order")
        for role in st.roles:
            nm = role["role"]
            key = st.key(nm)
            r_site = sites.get((k, f"{nm} opening"))
            if r_site is None:
                self._fail(f"{tag}: the {nm} opening is not in the transcript_sites index")
            elif r_site["before"] != role["before"] or r_site["after"] != role["after"]:
                self._fail(f"{tag}: the {nm} opening's site index differs from its positions")
            self._check_state(tr, role["before"], f"{tag} {nm} before")
            lams = []
            for gi, g in enumerate(role["groups"]):
                lam = tr.challenge_fp2_vec(len(g["members"]))
                for j, want in enumerate(g["lambdas"]):
                    self._eq_f2(lam[j], want, f"{tag} {nm} group {gi} lambda {j}")
                lams.append(lam)
            acc["role_lambdas"][key] = lams
            prox = tr.challenge_fp2_vec(role["commitment"]["rows"])
            for i, want in enumerate(role["proximity_rhos"]):
                self._eq_f2(prox[i], want, f"{tag} {nm} proximity rho {i}")
            acc["role_prox_rhos"][key] = prox
            for g in role["groups"]:
                tr.absorb_fp2(b"pcs-vec", [f2_from_list(v) for v in g["vector"]])
            tr.absorb_fp2(b"pcs-prox", [f2_from_list(v) for v in role["proximity_vector"]])
            p = role["params"]
            idx = tr.challenge_indices(p["num_col_checks"], (1 << p["log_cols"]) * p["inv_rate"])
            if idx != [c["index"] for c in role["columns"]]:
                self._fail(f"{tag} {nm}: sampled column indices differ")
            acc["role_indices"][key] = idx
            self._check_state(tr, role["after"], f"{tag} {nm} after")
        self._close_stage(tr, st, doc, tag, start)

    def _sites_of(self, doc, k, tag, n_slots=None):
        sites = {(s["stage"], s["site"]): s for s in doc["transcript_sites"]}
        want = [f"slot {s:02d}" for s in range(n_slots)] + [f"{nm} opening" for nm in doc["opening_order"]]
        if [s["site"] for s in doc["transcript_sites"]] != want:
            self._fail(f"{tag}: the transcript_sites index is not the declared site order")
        if any(s["stage"] != k for s in doc["transcript_sites"]):
            self._fail(f"{tag}: a transcript site names another stage")
        return sites


def load(directory: str) -> TokenRunBundle:
    return TokenRunBundle(directory)




# ------------------------------------------------------- per-commitment (G-1 / G-2 / G-6)
class ParamShape:
    """The shape numbers the per-commitment model reads, taken from ONE
    opening's own `params` (a token endpoint is 2^8 wide at rate 1/8, a new
    stage's A / H 2^12 at rate 1/4), with the group count the token code
    declares for that commitment."""

    def __init__(self, params: dict, block_shape, a_groups=None, h_groups=None):
        self.log_cols = params["log_cols"]
        self.cols = 1 << self.log_cols
        self.inv_rate = params["inv_rate"]
        self.enc_cols = self.cols * self.inv_rate
        self.opened_cols = params["num_col_checks"]
        self.a_groups = block_shape.a_groups if a_groups is None else a_groups
        self.h_groups = block_shape.h_groups if h_groups is None else h_groups
        self.n_slots = block_shape.n_slots


def role_class(role: dict) -> str:
    nm = role["role"]
    if nm in ("A", "A-in", "A-out"):
        return "A"
    if nm in ("H", "H-in", "H-out"):
        return "H"
    if role.get("boundary") is not None:
        return "boundary"
    return "endpoint"


def canonical(role: dict) -> dict:
    """The role as the generic model reads it (see the module doc, item 3)."""
    nm = role["role"]
    if nm in CANON:
        r = copy.copy(role)
        r["role"], kind = CANON[nm]
        r["commitment_kind"] = kind
        r["original_role"] = nm
        return r
    if role.get("commitment_kind") == "B-in":
        r = copy.copy(role)
        r["commitment_kind"] = "internal-boundary"
        r["original_role"] = nm
        return r
    return role


def role_view(bundle, st, role, replay, perturb=None):
    from zk60_native_rg_pcs import RunRoleView
    key = st.key(role["role"])
    nm = role["role"]
    a_g = GROUPS.get(nm) if nm.startswith("A-") else None
    h_g = GROUPS.get(nm) if nm.startswith("H-") else None
    pshape = ParamShape(role["params"], bundle.shape, a_groups=a_g, h_groups=h_g)
    v = RunRoleView(st, canonical(role), replay.stages[st.index]["role_prox_rhos"][key], pshape,
                    name=key, perturb=perturb)
    return key, v


def token_stage3(bundle, replay, pad_rank=True):
    """Every commitment of every stage of the token run, ranked at its own
    opening's geometry (the block stages exactly as `stage3` ranks them)."""
    import time
    from zk60_native_rg_joint import RunJointSystem, mask_block
    views, rows = {}, []
    for st in bundle.stages:
        for role in st.roles:
            key, v = role_view(bundle, st, role, replay)
            f = dict(v.run(replay.stages[st.index]["role_lambdas"][key]))
            views[key] = v
            f.pop("xi_vectors", None)
            f.pop("data_rows_index", None)
            f["site_role"] = role["role"]
            f["stage_kind"] = st.kind
            f["class"] = role_class(role)
            f["expected_disclosed_dimension"] = EXPECTED[f["class"]]
            f["meets_expectation"] = f["disclosed_dimension"] == f["expected_disclosed_dimension"]
            rows.append(f)
    masks = []
    for st in bundle.stages:
        blk = mask_block(st)
        dd = RunJointSystem([blk]).disclosed(msg_width=bundle.shape.cols)
        masks.append({"commitment": blk.name, "stage_kind": st.kind, "rows": blk.rows,
                      "slots": len(st.mask["specs"]), "opened_columns": len(st.mask["columns"]),
                      "disclosed_dimension": dd["disclosed_fp"], "expected_disclosed_dimension": 0,
                      "meets_expectation": dd["disclosed_fp"] == 0})
    pad = None
    if pad_rank:
        t0 = time.time()
        r, dcols = views["B0"].pad_block_rank()
        pad = {"commitment": "B0 (B_in)", "distinct_columns": dcols, "exact_rank_of_the_pad_block": r,
               "full_rank": r == dcols, "seconds": round(time.time() - t0, 1)}
    ok = all(
        r["findings"] == [] and all(r["reduction_hypotheses"].values())
        and r["column_identity_failures"] == 0 and r["group_claim_identity_failures"] == 0
        and r["meets_expectation"] and r["certifying_minor"]["full_row_rank"]
        and r["certifying_minor"]["determinant_nonzero"]
        and r["distinct_opened_columns_within_pad_count"]
        for r in rows) and all(m["meets_expectation"] for m in masks) and (pad is None or pad["full_rank"])
    return {"per_commitment": rows, "masking_commitments": masks,
            "pad_block_exact_rank_cross_check": pad, "ok": ok}, views


def _boundary_facts(self, k):
    """`bundle.boundary(k)` for the generic boundary figures: TOKEN numbering
    (0 = B_in, L = B_out), from `run.json["token_boundaries"]`."""
    fa = dict(self.run["token_boundaries"][k]["facts"])
    # the derived row rule (ruling M-1), checked here rather than declared:
    # a token boundary's facts carry the counts, not the rule's name
    if fa["rows"] == fa["data_rows"] + 2 * fa["sites"] + 2:
        fa["row_rule"] = "data + 2*sites + 2"
    else:
        fa["row_rule"] = f"NOT the derived rule: rows {fa['rows']} != {fa['data_rows']} + 2*{fa['sites']} + 2"
    return fa


TokenRunBundle.boundary = _boundary_facts


# ------------------------------------------------------------------ pins (P-2 for a token run)
def token_pins(manifest: dict) -> dict:
    """Every `source_pins` entry of a token bundle, matched BY FILE NAME:
    accepted if it equals the R7 pin read in v8 for that file, or a digest
    `zk60_native_rg_tokenio_r7c_pins.TOKEN_R7C_READINGS` reads; refused
    otherwise.  A file of either set absent from the bundle is refused too.
    A refusal fails the token gate (no stage of a token bundle is read with
    an unread pin: every figure of the record is then NOT a pass)."""
    import zk60_native_rg_tokenio_r7c_pins as TP
    pins = {p["file"]: p["sha256"] for p in manifest.get("source_pins", [])}
    expected = set(TP.R7_PINS_READ_IN_V8) | set(TP.TOKEN_R7C_READINGS)
    per, refused = [], []
    for f in sorted(set(pins) | expected):
        got = pins.get(f)
        if got is None:
            refused.append(f"{f}: not pinned by this bundle")
            per.append({"file": f, "sha256": None, "status": "missing"})
            continue
        if got in TP.TOKEN_R7C_READINGS.get(f, {}):
            per.append({"file": f, "sha256": got, "status": "read (token r7c reading)"})
        elif TP.R7_PINS_READ_IN_V8.get(f) == got:
            per.append({"file": f, "sha256": got, "status": "read (the R7 pin, v8)"})
        else:
            refused.append(f"{f}: {got[:12]} has no reading")
            per.append({"file": f, "sha256": got, "status": "REFUSED"})
    return {"pins": len(pins), "per_file": per, "refusals": refused,
            "read_as_R7": sum(1 for x in per if x["status"] == "read (the R7 pin, v8)"),
            "read_as_token_r7c": sum(1 for x in per if x["status"] == "read (token r7c reading)"),
            "ok": not refused}


# ------------------------------------------------------------------ integrity
def _sha(path):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def token_integrity(bundle) -> dict:
    """Hashes, schema, and every token fact against the RE-DERIVED geometry
    (`zk60_native_rg_tokenio`): the stage plane indexes, the two token
    endpoints (roots, rows, sites, the stage that opens each), B_in / B_out
    (rows, sites, the stage that commits and the stage that opens each, the
    claims that discharge each)."""
    f = []
    man = bundle.manifest
    if man.get("schema") != SCHEMA_6 or man.get("kind") != MANIFEST_KIND:
        f.append("manifest.json: schema / kind is not a token run's")
    for e in man.get("files", []):
        p = os.path.join(bundle.dir, e["file"])
        if not os.path.exists(p):
            f.append(f"manifest lists {e['file']}, which is absent")
        elif _sha(p) != e["sha256"]:
            f.append(f"{e['file']}: sha256 differs from the manifest")
    listed = {e["file"] for e in man.get("files", [])}
    for fn in bundle.run["stage_files"] + ["run.json", ARRAY_STORE_FILE]:
        if fn not in listed:
            f.append(f"{fn} is not in the manifest")
    f += [f"array store: {x}" for x in bundle.array_refusals]
    pins = token_pins(man)
    f += [f"source pin: {x}" for x in pins["refusals"]]
    g, ti, L = bundle.geom, bundle.run["token_io"], bundle.l
    for k, want in (("V_pad", g.v_pad), ("limbs", g.limbs), ("window_bits", g.window_bits)):
        if ti.get(k) != want:
            f.append(f"token_io.{k} is {ti.get(k)}, re-derived {want}")
    if ti.get("variant") != "public-row" or ti.get("mode") != "i":
        f.append(f"variant / mode {ti.get('variant')} / {ti.get('mode')}: only the public row, mode (i), is built")
    # the stage kinds and the two new stages' plane indexes
    kinds = [st.kind for st in bundle.stages]
    if kinds != ["IN"] + ["BLOCK"] * L + ["OUT"]:
        f.append(f"stage kinds {kinds} are not IN, {L} x BLOCK, OUT")
    for st, kind in ((bundle.stages[0], "IN"), (bundle.stages[-1], "OUT")):
        spi = st.doc.get("stage_plane_index")
        if spi is None:
            f.append(f"stage {kind}: no stage_plane_index")
            continue
        f += TIO.cross_check_plane_index(g, kind, spi)
        lay = g.stage_in() if kind == "IN" else g.stage_out()
        if [p["log_size"] for p in spi["a_planes"]] != lay.a_log:
            f.append(f"stage {kind}: A plane logs {[p['log_size'] for p in spi['a_planes']]} are not {lay.a_log}")
        if [p["log_size"] for p in spi["h_planes"]] != lay.h_log:
            f.append(f"stage {kind}: H plane logs differ from the re-derived {lay.h_log}")
        if st.doc["a_rows"] != lay.a_rows or st.doc["h_rows"] != lay.h_rows:
            f.append(f"stage {kind}: committed rows {st.doc['a_rows']} / {st.doc['h_rows']} are not {lay.a_rows} / {lay.h_rows}")
        if len(st.slots) != len(lay.slots) or len(st.mask["specs"]) != len(lay.slots):
            f.append(f"stage {kind}: {len(st.slots)} slots / {len(st.mask['specs'])} mask specs, re-derived {len(lay.slots)}")
        elif [tuple(s) for s in st.mask["specs"]] != [tuple(s) for s in lay.mask_specs()]:
            f.append(f"stage {kind}: mask specs {st.mask['specs']} are not {lay.mask_specs()}")
    # the token endpoints
    for nm, st, words, root_key, at_key in (("E-token-in", bundle.stages[0], g.in_ep_words(), "input_root", "input_endpoint_opened_at_stage"),
                                            ("E-token-out", bundle.stages[-1], g.out_ep_words(), "output_root", "output_endpoint_opened_at_stage")):
        r = st.role_or_none(nm)
        ep = g.endpoint(words)
        if r is None:
            f.append(f"{nm}: no opening in stage {st.index}")
            continue
        if r["commitment"]["root"] != ti[root_key]:
            f.append(f"{nm}: the opening's root is not token_io.{root_key}")
        if ti[at_key] != st.index:
            f.append(f"{nm}: token_io says it is opened at stage {ti[at_key]}, it is opened at {st.index}")
        if (r["commitment"]["rows"], r["data_rows"], r["params"]["log_cols"], r["params"]["inv_rate"]) != (ep["commitment_rows"], ep["data_rows"], ep["row_width_log"], ep["inv_rate"]):
            f.append(f"{nm}: rows / data / width / rate {(r['commitment']['rows'], r['data_rows'], r['params']['log_cols'], r['params']['inv_rate'])} are not the re-derived {(ep['commitment_rows'], ep['data_rows'], ep['row_width_log'], ep['inv_rate'])}")
        if r["site_rows"] != [ep["data_rows"], ep["data_rows"] + 1] or r["prox_row"] != ep["data_rows"] + 2:
            f.append(f"{nm}: site rows {r['site_rows']} / prox {r['prox_row']} are not one site after the data row")
        if len(r["claims"]) != 1:
            f.append(f"{nm}: {len(r['claims'])} claims, the public-row variant has one")
    # B_in / B_out and the block boundaries: committed at stage k, opened at k + 1
    bf = g.boundary()
    for k in range(L + 1):
        tb = bundle.run["token_boundaries"][k]
        fa = tb["facts"]
        if (fa["rows"], fa["data_rows"], fa["sites"], fa["log_n"]) != (bf["rows"], bf["data_rows"], bf["sites"], bf["row_width_log"]):
            f.append(f"boundary {k}: rows / data / sites / width {(fa['rows'], fa['data_rows'], fa['sites'], fa['log_n'])} are not the derived {(bf['rows'], bf['data_rows'], bf['sites'], bf['row_width_log'])}")
        if tb["committed_at_stage"] != k or tb["opened_at_stage"] != k + 1:
            f.append(f"boundary {k}: committed at {tb['committed_at_stage']} / opened at {tb['opened_at_stage']}, not {k} / {k + 1}")
        bc = bundle.stages[k].doc["boundary_committed"]
        opener = None
        for r in bundle.stages[k + 1].roles:
            if r.get("boundary") == k:
                opener = r
        if bc is None or bc.get("boundary") != k:
            f.append(f"stage {k} does not commit boundary {k}")
        elif opener is None:
            f.append(f"boundary {k} has no opening in stage {k + 1}")
        else:
            if opener["commitment"]["root"] != bc["root"]:
                f.append(f"boundary {k}: the root stage {k + 1} opens is not the root stage {k} committed")
            src = [(c["stage"], c["slot"]) for c in opener["claim_sources"]]
            want = [(k, 1 if k == 0 else 22), (k + 1, 21 if k + 1 <= L else 0)]
            if src != want:
                f.append(f"boundary {k}: claim sources {src}, expected {want} (the outgoing claim, then the incoming)")
    if bundle.stages[-1].doc["boundary_committed"] is not None:
        f.append("stage OUT commits a boundary")
    return {"findings": f, "ok": not f, "stages": len(bundle.stages), "blocks": L, "source_pins": pins,
            "re_derived": {"stage_in": TIO.StageLayout.summary(g.stage_in()),
                           "stage_out": TIO.StageLayout.summary(g.stage_out()),
                           "input_endpoint": g.endpoint(g.in_ep_words()),
                           "output_endpoint": g.endpoint(g.out_ep_words()), "boundary": bf}}


# ------------------------------------------------------------------ G-2
PUBLIC_CONSTS = ([0, 0], [1, 0])


def g2_claim_points(bundle) -> dict:
    """G-2: the claims on B_in and B_out at partially FIXED points.  Each
    coordinate of each claim's evaluation point is classed as a public
    constant (0 or 1), an entry of stage IN's challenge-fixed column point
    `r_emb`, or other (a slot's own random point).  Row coordinates are the
    leading `log_size - log_cols`; the column coordinates are the claim's
    column key, which the two reserved-pair parts must share."""
    r_emb = [list(x) for x in bundle.stages[0].doc["r_emb"]]
    out = {}
    L = bundle.l
    for k, nm in ((0, "B_in"), (L, "B_out")):
        op = None
        for r in bundle.stages[k + 1].roles:
            if r.get("boundary") == k:
                op = r
        claims = []
        for ci, c in enumerate(op["claims"]):
            p0 = c["parts"][0]
            ln = op["params"]["log_cols"]
            nrow = p0["log_size"] - ln
            pt = [list(x) for x in p0["point"]]
            rows, cols = pt[:nrow], pt[nrow:]

            def cls(v):
                if v in PUBLIC_CONSTS:
                    return "public"
                if v in r_emb:
                    return f"r_emb[{r_emb.index(v)}]"
                return "random"
            mask_parts = c["parts"][1:]
            same_key = all([list(x) for x in mp["point"]] == cols for mp in mask_parts)
            src = op["claim_sources"][ci] if ci < len(op["claim_sources"]) else None
            claims.append({
                "claim": ci, "source": src,
                "row_coordinates": [cls(v) for v in rows],
                "column_coordinates": [cls(v) for v in cols],
                "public_bits": sum(cls(v) == "public" for v in pt),
                "public_column_bits": sum(cls(v) == "public" for v in cols),
                "r_emb_column_coordinates": sum(cls(v).startswith("r_emb") for v in cols),
                "mask_parts_share_the_column_key": same_key,
                "mask_rows": sorted({mp["offset"] // (1 << ln) for mp in mask_parts}),
            })
        out[nm] = {"boundary": k, "opened_at_stage": k + 1, "claims": claims}
    # the expected shape: B_in's stage-IN claim (claim 0) has clog2(d_pad)
    # r_emb column coordinates; B_out's stage-OUT claim (claim 1) has the
    # clog2(t_pad) public bits of row T - 1
    g = bundle.geom
    want_emb = TIO.clog2(g.d_pad)
    want_pub = TIO.clog2(g.t_pad)
    st = g.g2()["B_out"]
    bi, bo = out["B_in"]["claims"], out["B_out"]["claims"]
    checks = {
        "B_in_stage_IN_claim_has_r_emb_column_point": bi[0]["r_emb_column_coordinates"] == want_emb,
        "B_out_stage_OUT_claim_has_the_public_row_bits": bo[1]["public_bits"] == want_pub,
        "B_out_public_bits_split_as_re_derived": (
            bo[1]["public_column_bits"] == st["fixed_bits_in_the_column_coordinate"]),
        "every_claim_masked_on_its_own_pair": all(
            c["mask_parts_share_the_column_key"] for side in out.values() for c in side["claims"])
        and len({tuple(c["mask_rows"]) for c in bi}) == len(bi)
        and len({tuple(c["mask_rows"]) for c in bo}) == len(bo),
    }
    return {"claims": out, "checks": checks, "ok": all(checks.values())}


# ------------------------------------------------------------------ G-4
def _supp(n, size):
    return [1] * n + [0] * (size - n)


def g4_support_tables(bundle) -> dict:
    """G-4: every public table of stage IN / OUT is identified by its SHA-256
    against the support vectors the pad rule and the P-3 lift imply
    (computed here from the re-derived geometry, never read).  A slot that
    hosts a padded domain must carry that domain's support table."""
    from zk60_native_rg_terminals import table_digest
    g = bundle.geom
    lt = g.tier.stage_log_n
    cands = {
        f"supp(T={g.tokens}) over the 2^{g.tier.ep_log_n}-word input endpoint plane": _supp(g.tokens, g.in_ep_words()),
        f"supp(T={g.tokens}) over Ti = 2^{g.ti_log()}": _supp(g.tokens, 1 << g.ti_log()),
        f"supp(V={g.v}) over V_pad = 2^{g.voc_log()} (the vocabulary pads)": _supp(g.v, 1 << g.voc_log()),
        f"supp({2 * 3 * TIO.LIMBS_ISQRT}) over Lo = 2^{g.lo_log()}": _supp(2 * 3 * TIO.LIMBS_ISQRT, 1 << g.lo_log()),
        f"supp(d_pad={g.d_pad}) over Do = 2^{g.do_log()}": _supp(g.d_pad, 1 << g.do_log()),
        f"supp(256) over Tab = 2^{g.tab_log()}": _supp(256, 1 << g.tab_log()),
        "the one-hot u0 over the 2^8-word output endpoint plane": [1] + [0] * (g.out_ep_words() - 1),
        f"the BOS position indicator over Ti = 2^{g.ti_log()}": [1] + [0] * ((1 << g.ti_log()) - 1),
        f"supp(d={g.d}) over d_pad = {g.d_pad}": _supp(g.d, g.d_pad),
        "the all-ones vector over 2^{lt}".format(lt=lt): [1] * (1 << lt),
        f"supp(V={g.v}) over V_pad (Vo)": _supp(g.v, 1 << g.vo_log()),
        # `stage_out.rs:400`: the live isqrt limb positions, sub-plane k < 9 at
        # To entry 0 (index 2k), over Lo
        f"the live isqrt limb positions {{2k : k < {3 * TIO.LIMBS_ISQRT}}} over Lo = 2^{g.lo_log()}": [
            1 if (z % 2 == 0 and z // 2 < 3 * TIO.LIMBS_ISQRT) else 0 for z in range(1 << g.lo_log())],
        # `stage_out.rs:377`: To's entry-0 indicator, supp(1, 2^TO_LOG)
        "To's entry-0 indicator supp(1) over 2^1": _supp(1, 1 << TIO.TO_LOG),
    }
    by_digest = {}
    for name, vec in cands.items():
        by_digest.setdefault(table_digest(vec), name)
    per = []
    for st in (bundle.stages[0], bundle.stages[-1]):
        for a in st.slots:
            tabs = []
            for t in a["tables"]:
                if t.get("kind") != "public":
                    continue
                tabs.append({"len": t["len"], "sha256": t["sha256"],
                             "identified_as": by_digest.get(t["sha256"])})
            per.append({"stage": st.kind, "slot": a["slot"], "name": a["name"],
                        "definition_draws": len(a["definition_challenges"]),
                        "public_tables": tabs})
    # what must be present (DESIGN 4.2 G-4; stage_in.rs / stage_out.rs slot names)
    need = {
        ("IN", 0): f"supp(T={g.tokens}) over the 2^{g.tier.ep_log_n}-word input endpoint plane",
        ("IN", 1): f"supp(T={g.tokens}) over Ti = 2^{g.ti_log()}",
        ("IN", 2): f"supp(V={g.v}) over V_pad = 2^{g.voc_log()} (the vocabulary pads)",
        ("OUT", 2): "To's entry-0 indicator supp(1) over 2^1",
        ("OUT", 3): f"the live isqrt limb positions {{2k : k < {3 * TIO.LIMBS_ISQRT}}} over Lo = 2^{g.lo_log()}",
        ("OUT", 6): f"supp(V={g.v}) over V_pad = 2^{g.voc_log()} (the vocabulary pads)",
        ("OUT", 8): f"supp(256) over Tab = 2^{g.tab_log()}",
    }
    if g.do_log() > TIO.clog2(g.d_pad):
        need[("OUT", 5)] = f"supp(d_pad={g.d_pad}) over Do = 2^{g.do_log()}"
    present = {}
    for (kind, slot), want in need.items():
        row = next(r for r in per if r["stage"] == kind and r["slot"] == slot)
        present[f"{kind}-{slot:02d}"] = {"needs": want,
                                         "present": any(t["identified_as"] == want for t in row["public_tables"])}
    return {"per_slot": per, "required_support_tables": present,
            "vocabulary_pad_positions": g.v_pad - g.v,
            "ok": all(v["present"] for v in present.values())}


# ------------------------------------------------------------------ G-5
def g5_tab_width(bundle) -> dict:
    """G-5 on the CAPTURED stage OUT plane index: the byte-table helper and
    histogram sit on the Tab domain at the stage row width."""
    spi = bundle.stages[-1].doc["stage_plane_index"]
    tab = [p for p in spi["a_planes"] + spi["h_planes"] if "TAB" in p["name"].upper() or "U8" in p["name"].upper() or "GU8" in p["name"].upper()]
    ln = spi["log_n"]
    return {"stage_out_row_width_log": ln,
            "tab_planes": [{"name": p["name"], "log_size": p["log_size"]} for p in tab],
            "re_derived": bundle.geom.g5(),
            "ok": bool(tab) and all(p["log_size"] == ln for p in tab) and bundle.geom.g5()["stage OUT"]["holds"]}


# ------------------------------------------------------------------ G-3
class _ShimBundle:
    """The bundle as the frozen per-stage tools read it, with `run.shape.slots`
    replaced by ONE stage's own slot triples (a new stage's schedule, from
    its `stage_plane_index`), so the shape-driven spec check compares the
    stage with ITS schedule.  Nothing else changes."""

    def __init__(self, bundle, stage):
        self.__dict__.update(bundle.__dict__)
        self.run = dict(bundle.run)
        self.run["shape"] = dict(bundle.run["shape"])
        if stage.kind != "BLOCK":
            self.run["shape"]["slots"] = [[s["main"], s["extension"], s["degree"]]
                                          for s in stage.doc["stage_plane_index"]["sched"]["slots"]]

    @property
    def name(self):
        return os.path.basename(self.dir)


def token_mask_cfs(bundle, replay, kinds=("IN", "BLOCK", "OUT")) -> dict:
    """G-3: the masking commitment and the masked-sumcheck (CFS) channel of
    each new stage, by the frozen shape-driven port (`mask_cfs_stage`) run
    against the stage's own schedule; the re-derived schedule's functional
    count (`zk60_native_rg_tokenio`) is compared."""
    from zk60_native_rg_mask import mask_cfs_stage
    g = bundle.geom
    per = []
    for st in bundle.stages:
        if st.kind not in kinds:
            continue
        r = mask_cfs_stage(_ShimBundle(bundle, st), replay, st.index)
        lay = g.stage_in() if st.kind == "IN" else (g.stage_out() if st.kind == "OUT" else None)
        ent = r.get("entries_recomputed") or {}
        row = {"stage": st.index, "stage_kind": st.kind, "ok": r.get("ok"),
               "specs_ok": r["specs_against_the_shape"]["ok"], "domain_ok": r["mask_domain"]["ok"],
               "declared_order_ok": (r["declared_order"] or {}).get("ok") if isinstance(r["declared_order"], dict) else None,
               "disclosed": r["disclosed"], "cfs_findings": r["cfs"].get("findings"),
               "entries_recomputed": ent.get("total"), "entries_differing": ent.get("differing"),
               "functional_values": ent.get("functional_values"),
               "salted_leaves_authenticated": ent.get("salted_leaves_authenticated"),
               "seconds": r.get("seconds")}
        if lay is not None:
            row["functionals_re_derived"] = lay.n_functionals()
            row["functionals_match"] = ent.get("functional_values") == lay.n_functionals()
        per.append(row)
    ok = bool(per) and all(p["ok"] and p.get("functionals_match", True) and p["entries_differing"] == 0 for p in per)
    return {"per_stage": per, "ok": ok}


# ------------------------------------------------------------------ G-6 (endpoint figures)
def g6_endpoints(stage3_rows, views) -> dict:
    """G-6, the D17 hard gate at the 2^8-word token endpoints: the
    per-commitment view of each endpoint opening at its OWN geometry (2^8 at
    rate 1/8, one site), its exclusivity facts, and the H-pad rank over its
    distinct opened columns."""
    out = {}
    for nm in ("E-token-in", "E-token-out"):
        r = next(x for x in stage3_rows if x["role"] == nm)
        rk, dcols = views[nm].pad_block_rank()
        out[nm] = {"disclosed_dimension": r["disclosed_dimension"], "k0": r["k0"],
                   "exclusivity_ok": (r.get("exclusivity") or {}).get("ok"),
                   "certifying_minor": r["certifying_minor"],
                   "distinct_opened_columns": dcols, "pad_block_rank": rk,
                   "pad_block_full_rank": rk == dcols,
                   "ok": r["disclosed_dimension"] == 0 and r["meets_expectation"] and rk == dcols}
    return {"endpoints": out, "ok": all(v["ok"] for v in out.values())}


# ------------------------------------------------------------------ controls
class _ShimStage:
    """A stage whose `key("A" / "H" / "Input")` names a NEW stage's roles, so
    the frozen exclusivity controls run on them unchanged."""

    def __init__(self, stage, mapping):
        self._st, self._map = stage, mapping
        self.index = stage.index

    def key(self, role):
        return self._map[role]


def token_controls(bundle, replay, views) -> dict:
    """Negative controls on the NEW stages, each predicted to fire (every one
    perturbs an in-memory copy; no captured byte is touched)."""
    from zk60_native_rg_exclusivity import exclusivity_controls
    from zk60_native_rg_joint import boundary_reserved_figure
    L = bundle.l
    out = {}
    # TC-1 / TC-2: the exclusivity family (16 clauses) on stage IN's and stage OUT's openings
    for name, k, mp, bkey in (("TC-1_exclusivity_on_stage_IN", 0, {"A": "A-in@0", "H": "H-in@0", "Input": "E-token-in"}, "B0"),
                              ("TC-2_exclusivity_on_stage_OUT", L + 1, {"A": f"A-out@{L + 1}", "H": f"H-out@{L + 1}", "Input": "E-token-out"}, f"B{L}")):
        shim = type("S", (), {})()
        shim.stages = [_ShimStage(bundle.stages[k], mp)]
        v2 = dict(views)
        v2["B0"] = views[bkey]
        r = exclusivity_controls(shim, v2)
        out[name] = {"fires": r["ok"], "controls": len(r["control_names"]),
                     "fired": sum(1 for c in r["controls"].values() if c["fires"]),
                     "clauses_exercised": len(r["clauses_exercised"]),
                     "not_exercised": r["clauses_not_exercised"]}
    # TC-3 / TC-4: B_in and B_out, the shared-pair and single-proximity-row models
    for name, k in (("TC-3_B_in", 0), ("TC-4_B_out", L)):
        mp = boundary_reserved_figure(bundle, views[f"B{k}"], k, merge_pairs=True)
        dp = boundary_reserved_figure(bundle, views[f"B{k}"], k, drop_prox_row=True)
        out[name + "_shared_pair"] = {"fires": mp["disclosed_on_the_reserved_block_fp"] > 0,
                                      "disclosed": mp["disclosed_on_the_reserved_block_fp"]}
        out[name + "_single_proximity_row"] = {"fires": dp["disclosed_on_the_reserved_block_fp"] > 0,
                                               "disclosed": dp["disclosed_on_the_reserved_block_fp"]}

    # TC-5: the replay of the new stages' prefixes
    def replay_fails(mutate, what):
        b2 = copy.copy(bundle)
        b2.stages = [copy.copy(s) for s in bundle.stages]
        for s in b2.stages:
            s.doc = copy.copy(s.doc)
        mutate(b2)
        rp = TokenRunReplay(b2).run()
        return {"fires": not rp.summary()["ok"], "first_failure": (rp.failures or [None])[0], "what": what}

    def flip_r_emb(b2):
        d = b2.stages[0].doc
        d["r_emb"] = [list(x) for x in d["r_emb"]]
        d["r_emb"][0] = [(d["r_emb"][0][0] + 1) % 18446744069414584321, d["r_emb"][0][1]]
    out["TC-5a_r_emb_entry_moved"] = replay_fails(flip_r_emb, "stage IN's first r_emb entry moved by one")

    def extra_logup(b2):
        d = b2.stages[-1].doc
        d["logup_challenges"] = list(d["logup_challenges"]) + [d["logup_challenges"][0]]
    out["TC-5b_stage_OUT_three_LogUp_challenges"] = replay_fails(extra_logup, "stage OUT recorded with three LogUp challenges")

    def swap_order(b2):
        d = b2.stages[0].doc
        o = list(d["opening_order"])
        o[1], o[2] = o[2], o[1]
        d["opening_order"] = o
    out["TC-5c_stage_IN_opening_order_swapped"] = replay_fails(swap_order, "stage IN's A-in / H-in openings swapped in the declared order")

    # TC-6: integrity on the token facts
    def integrity_fires(mutate, what):
        b2 = copy.copy(bundle)
        b2.run = copy.deepcopy(bundle.run)
        b2.stages = [copy.copy(s) for s in bundle.stages]
        for s in b2.stages:
            s.doc = copy.copy(s.doc)
        mutate(b2)
        r = token_integrity(b2)
        return {"fires": not r["ok"], "first_finding": (r["findings"] or [None])[0], "what": what}

    def root_flip(b2):
        b2.run["token_io"]["input_root"] = list(b2.run["token_io"]["input_root"])
        b2.run["token_io"]["input_root"][0] ^= 1
    out["TC-6a_input_root_flipped"] = integrity_fires(root_flip, "token_io.input_root's first byte flipped")

    def bout_rows(b2):
        b2.run["token_boundaries"][L]["facts"]["rows"] += 1
    out["TC-6b_B_out_rows_moved"] = integrity_fires(bout_rows, "B_out's declared row count + 1")

    def spi_rows(b2):
        d = b2.stages[-1].doc
        d["stage_plane_index"] = dict(d["stage_plane_index"])
        d["stage_plane_index"]["a_rows"] += 2
    out["TC-6c_stage_OUT_plane_index_moved"] = integrity_fires(spi_rows, "stage OUT's plane index a_rows + 2")

    def ep_opened(b2):
        b2.run["token_io"]["output_endpoint_opened_at_stage"] = 0
    out["TC-6d_output_endpoint_opened_elsewhere"] = integrity_fires(ep_opened, "token_io says the output endpoint is opened at stage 0")

    # TC-10: the token pins (P-2's discipline on a token bundle)
    import zk60_native_rg_tokenio_r7c_pins as TP
    man = copy.deepcopy(bundle.manifest)
    for p in man["source_pins"]:
        if p["file"] == "src/private_block/token_io/stage_out.rs":
            p["sha256"] = "1" * 64
    r = token_pins(man)
    out["TC-10a_token_pin_moved"] = {"fires": not r["ok"], "refusals": r["refusals"][:2],
                                     "what": "stage_out.rs's pin moved to an unread digest"}
    man = copy.deepcopy(bundle.manifest)
    man["source_pins"] = [p for p in man["source_pins"] if p["file"] != "src/private_block/token_io/stage_in.rs"]
    r = token_pins(man)
    out["TC-10b_token_pin_dropped"] = {"fires": not r["ok"], "refusals": r["refusals"][:2],
                                       "what": "stage_in.rs's pin dropped from the bundle"}
    man = copy.deepcopy(bundle.manifest)
    for p in man["source_pins"]:
        if p["file"] == "src/private_block/run.rs":
            p["sha256"] = TP.R7_PINS_READ_IN_V8["src/private_block/run.rs"]
    r = token_pins(man)
    out["TC-10c_R7_run_rs_under_a_token_writer"] = {
        "fires": r["ok"], "what": "run.rs at R7's digest (read in v8) is ACCEPTED: the control "
        "shows the R7 basis is live (a pin at a read digest passes), the converse of TC-10a"}

    # TC-7: G-2's claim-point classes
    def g2_fires(mutate, what):
        b2 = copy.copy(bundle)
        b2.stages = [copy.copy(s) for s in bundle.stages]
        for s in b2.stages:
            s.doc = copy.deepcopy(s.doc)
        mutate(b2)
        r = g2_claim_points(b2)
        return {"fires": not r["ok"], "checks": r["checks"], "what": what}

    def bout_bit(b2):
        op = b2.stages[L + 1].role("B-out")
        op["claims"][1]["parts"][0]["point"][0] = [12345, 678]
    out["TC-7a_B_out_row_bit_unfixed"] = g2_fires(bout_bit, "B_out's stage-OUT claim: its first public row bit replaced by a random value")

    def bin_emb(b2):
        op = b2.stages[1].role("Input")
        p = op["claims"][0]["parts"][0]["point"]
        p[-1] = [987, 654]
    out["TC-7b_B_in_r_emb_coordinate_moved"] = g2_fires(bin_emb, "B_in's stage-IN claim: its last r_emb column coordinate replaced")

    def bin_same_pair(b2):
        op = b2.stages[1].role("Input")
        for pp, qq in zip(op["claims"][1]["parts"][1:], op["claims"][0]["parts"][1:]):
            pp["offset"] = qq["offset"]
    out["TC-7c_B_in_claims_on_one_pair"] = g2_fires(bin_same_pair, "B_in's two claims masked on the same reserved pair")

    # TC-8: G-4's required support tables
    def g4_fires(mutate, what):
        b2 = copy.copy(bundle)
        b2.stages = [copy.copy(s) for s in bundle.stages]
        for s in b2.stages:
            s.doc = copy.deepcopy(s.doc)
        mutate(b2)
        r = g4_support_tables(b2)
        return {"fires": not r["ok"], "missing": [k for k, v in r["required_support_tables"].items() if not v["present"]], "what": what}

    def voc_table(b2):
        for t in b2.stages[0].slots[2]["tables"]:
            if t.get("kind") == "public" and t["len"] == bundle.geom.v_pad:
                t["sha256"] = "0" * 64
                break
    out["TC-8a_vocabulary_support_table_replaced"] = g4_fires(voc_table, "stage IN's table zero-check: its vocabulary support table's digest replaced")

    def tab_table(b2):
        for t in b2.stages[-1].slots[8]["tables"]:
            if t.get("kind") == "public" and t["len"] == 1 << bundle.geom.tab_log():
                t["sha256"] = "0" * 64
                break
    out["TC-8b_byte_table_support_replaced"] = g4_fires(tab_table, "stage OUT's TAB slot: its Tab support table's digest replaced")
    # TC-9: round 8's six mask controls on M_in and M_out (the stage's own
    # schedule).  M4 targets the repaired BILINEAR slots (extension 2); a new
    # stage has none, so M4 is NOT APPLICABLE by name there, as C1-C4 are at L = 1.
    from zk60_native_rg_mcontrols import mask_controls_at_shape
    for k in (0, L + 1):
        st = bundle.stages[k]
        mc = mask_controls_at_shape(_ShimBundle(bundle, st), replay, k)
        bil = [s for s in st.doc["stage_plane_index"]["sched"]["slots"] if s["extension"] == 2]
        for n in mc["control_names"]:
            if n.startswith("M4") and not bil:
                out[f"TC-9_{st.kind}_{n}"] = {"fires": None, "not_applicable": "the stage has no bilinear "
                                              "(extension-2) slot, which is what M4 shortens"}
            else:
                out[f"TC-9_{st.kind}_{n}"] = {"fires": bool(mc[n].get("fires"))}
    live = {k: v for k, v in out.items() if v.get("fires") is not None}
    return {"controls": out, "all_fire": all(v["fires"] for v in live.values()),
            "not_applicable": [k for k, v in out.items() if v.get("fires") is None],
            "not_fired": [k for k, v in live.items() if not v["fires"]],
            "ok": bool(live) and all(v["fires"] for v in live.values())}


# ------------------------------------------------------------------ driver
def gate(directory: str, controls=True) -> dict:
    import time
    t0 = time.time()
    rec = {"what": "the privacy gate's token items (DESIGN 4.2 G-1..G-7) on ONE token-I/O run capture; "
                   "NOT a privacy result", "privacy_acceptance": False,
           "privacy_property_established": False, "timings": {}}

    def tick(name, t):
        rec["timings"][name] = round(time.time() - t, 1)
    t = time.time()
    b = load(directory)
    rec["bundle"], rec["bundle_dir"], rec["profile"] = b.name, b.dir, b.profile
    rec["blocks"], rec["stages"] = b.l, len(b.stages)
    rec["integrity"] = token_integrity(b)
    tick("load_and_integrity", t)
    t = time.time()
    rp = TokenRunReplay(b).run()
    rec["replay"] = rp.summary()
    tick("replay", t)
    t = time.time()
    from zk60_native_rg_hashlayer import check_hash_layer
    h = check_hash_layer(b)
    rec["hash_layer"] = {k: h[k] for k in ("ok", "columns_checked", "columns_authenticated", "bytes_hashed", "findings") if k in h}
    rec["hash_layer"]["wrong_rules_that_reached_the_root"] = h.get("cross_rule_probe", {}).get("wrong_rules_that_reached_the_root")
    tick("hash_layer", t)
    t = time.time()
    s3, views = token_stage3(b, rp, pad_rank=True)
    rec["G1_per_commitment"] = s3
    tick("per_commitment", t)
    t = time.time()
    from zk60_native_rg_joint import boundary_reserved_figure
    rec["G1_G2_boundaries_reserved"] = {nm: boundary_reserved_figure(b, views[f"B{k}"], k)
                                        for nm, k in (("B_in", 0), ("B_out", b.l))}
    rec["G2_claim_points"] = g2_claim_points(b)
    tick("boundaries_and_G2", t)
    t = time.time()
    rec["G3_mask_cfs"] = token_mask_cfs(b, rp)
    tick("G3", t)
    rec["G4_support_tables"] = g4_support_tables(b)
    rec["G4_static"] = b.geom.g4()
    rec["G5_tab_width"] = g5_tab_width(b)
    t = time.time()
    rec["G6_endpoints"] = g6_endpoints(s3["per_commitment"], views)
    tick("G6", t)
    rec["G7"] = {"in_scope": False, "why": "the D26 two-site input endpoint and its SHIFT / IO-s claims are not built "
                 "(token_io/run.rs variant_is_built refuses every variant but the public row)"}
    rec["G1_joint"] = {
        "computed": "per commitment (G1_per_commitment) and on each boundary's reserved block (G1_G2_boundaries_reserved)",
        "shared_planes": ["tok: A-in (Ti, positions 0..T-1) and E-token-in (words 0..T-1); words T..255 are the "
                          "public zeros IN-00's supp_T factor forces",
                          "B_in: the B0 commitment (claims from IN-01 and block 0's slot 21) and block 0's A (x)",
                          "B_out: the B_L commitment (claims from block L-1's slot 22 and OUT-00) and A-out's x "
                          "(row T-1 only)", "tok (output): A-out's To-domain tok and E-token-out (one word)"],
        "argument": "[ARGUED] every commitment's opened functionals are blinded by its OWN reserved rows, pads and "
                    "salts (one generator per run, distinct draws per commitment: G-R4, the stage-47 replay); a "
                    "combination of functionals of two commitments is blinding-free only if each part is, so the "
                    "joint blinding-free space restricted to the identified data coordinates has dimension at most "
                    "the sum of the per-commitment disclosed dimensions, which is 0 for every commitment holding a "
                    "new plane (A-in, E-token-in, B0, B_L, A-out, E-token-out) -- ruling R-3: joint = sum of parts "
                    "is a model consistency check, not independence (G-R4's job)",
        "ok": all(r["disclosed_dimension"] == 0 for r in s3["per_commitment"] if r["class"] in ("A", "endpoint", "boundary")),
    }
    if controls:
        t = time.time()
        rec["controls"] = token_controls(b, rp, views)
        tick("controls", t)
    else:
        rec["controls"] = {"skipped": "controls not requested", "ok": None}
    parts = ["integrity", "replay", "hash_layer", "G1_per_commitment", "G2_claim_points", "G3_mask_cfs",
             "G4_support_tables", "G5_tab_width", "G6_endpoints", "G1_joint"]
    bres = rec["G1_G2_boundaries_reserved"]
    rec["boundaries_ok"] = all(v["disclosed_on_the_reserved_block_fp"] == 0 and v["full_row_rank"]
                               and v["determinant_nonzero"] and v["row_rule"] == "data + 2*sites + 2"
                               for v in bres.values())
    rec["false_parts"] = [p for p in parts if rec[p].get("ok") is not True] + ([] if rec["boundaries_ok"] else ["boundaries"])
    rec["ok"] = not rec["false_parts"] and (rec["controls"].get("ok") is True if controls else True)
    rec["status"] = "PASS" if rec["ok"] and controls else ("PASS-NO-CONTROLS" if rec["ok"] else "NOT-OK")
    rec["total_seconds"] = round(time.time() - t0, 1)
    try:
        import resource
        rec["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
    except Exception:  # noqa: BLE001
        pass
    import zk60_native_run_gate as G
    rec["tool_sha256"] = G.tool_hashes()
    return rec


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--no-controls", action="store_true")
    a = ap.parse_args(argv)
    rec = gate(a.bundle, controls=not a.no_controls)
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, f"{a.name}.json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
    print(f"{a.name}: status {rec['status']}; false parts {rec['false_parts']}; "
          f"controls not fired {rec['controls'].get('not_fired')}; {rec['total_seconds']} s; record {path}")
    return 0 if rec["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
