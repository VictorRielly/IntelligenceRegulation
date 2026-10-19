"""Loader for a RUN CAPTURE bundle, schema `hashline-native-capture/4-run`
or `/5-run`.

Format: `docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md` on lane
`zk60-private-block-125m`; writer `hashline/src/private_block/run_capture.rs`.

A bundle is a DIRECTORY -- `run.json`, `stage-00.json` ... `stage-{L-1}.json`,
`manifest.json`, `README.md`, and under `/5-run` one `arrays.bin` -- and it
is the VERIFIER'S VIEW of one private run of L blocks under one transcript.
It carries no witness value, no pad, no mask coefficient, no unopened column
and no unmasked sumcheck round.

**`/5-run` (stage 27 of the Rust lane, ROUND 9).**  The only difference is
where a field-element array of at least 256 entries lives: in `/4-run` it is
a JSON list, in `/5-run` a reference `{"array", "elem", "len", "offset",
"bytes"}` into one `arrays.bin`.  `zk60_native_rg_arrays` resolves them into
objects that index, iterate and measure exactly like the lists they replace,
so nothing downstream of this loader knows which schema it is reading.  Every
resolution is checked (length, byte range, SHA-256 of the range, element
type, reduced values) and a failure is a named finding, never an exception.

TWO RULES THIS MODULE KEEPS.

* **Nothing is ported.** Every size is read from `run.json["shape"]` and
  every transcript label from `run.json["transcript_labels"]` (findings U-7
  and U-8 of the format document).  The toy loader's flat constants
  (`zk60_native_jv_capture.py:38-46`) are deliberately NOT imported.
* **It refuses anything else by name.** A single-block (schema 3) capture,
  a stage file read as a run file, a manifest hash that does not match the
  bytes on disk: each is an error naming the file and the field.

Nothing here re-derives a witness or prints bundle contents; callers report
counts, sizes, digests, indices and challenge-derived field elements only.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_rg_arrays import (  # noqa: E402
    ARRAY_STORE_FILE,
    SCHEMA_4,
    SCHEMA_5,
    SCHEMAS,
    ArrayRefused,
    ArrayStore,
    resolve_document,
)
from zk60_native_rg_hashrule import rule_for_bundle  # noqa: E402

SCHEMA = SCHEMA_4
RUN_KIND = "zk60-run-verifier-observations"
STAGE_KIND = "zk60-run-stage-observations"
MANIFEST_KIND = "zk60-run-capture-manifest"
COVERAGE = "native-run-all-stages-v1"

# Every label the run transcript uses, as the writer declares them.  The
# replay checks that the bundle's own `transcript_labels` array holds exactly
# these, so a label added or renamed in Rust is a refusal here, not a silent
# divergence.
EXPECTED_LABELS = (
    "run-shape",
    "expected-IO",
    "public-statement",
    "parameters",
    "calibration",
    "schedule",
    "pb-run-stage",
    "pb-run-block",
    "B",
    "A",
    "M",
    "H",
    "rows",
    "log-cols",
    "pb-slot",
    "pb-scalar",
    "pb-term",
    "mask-q",
    "mask-prox",
)
# Drawn inside the sumcheck and the two openings; not in the bundle's label
# array because they belong to zkp-core, not to the run header.
CORE_LABELS = ("sc-round", "pcs-vec", "pcs-prox")

ROLE_NAMES = ("A", "H", "Input", "Output")

# [ROUND 9m] lane stage 48's layout for the TWELVE-block 125M bundles: beside
# the `/5-run` capture files, `run/` holds the receipt's `L` segment files and
# the public run statement (D21), and `validation.json` records a FRESH
# process's re-verify.  The writer's README says why the manifest does not
# pin either: `validation.json` is written AFTER the manifest, and every stage
# file already pins its segment by `segment_bytes` / `segment_sha256`.  So
# both are READ and COMPARED with what IS pinned -- never trusted for a
# figure -- and a bundle that carries neither (every bundle before stage 48)
# gains no leaf in its record.
VALIDATION_FILE = "validation.json"
VALIDATION_KIND = "zk60-run-capture-validation"
VALIDATION_FLAGS = (
    "source_pins_match",
    "statement_rebuilt_from_its_file",
    "native_reverified",
    "segments_match_the_stage_pins",
    "canonical_capture_reproduced",
    "fresh_process",
)
RUN_DIR = "run"
STATEMENT_DIR = "statement"
STATEMENT_FILE = "run-statement.json"


def _sha256_of_file(path: str) -> tuple[str, int]:
    h = hashlib.sha256()
    n = 0
    with open(path, "rb") as fh:
        while True:
            chunk = fh.read(1 << 23)
            if not chunk:
                break
            h.update(chunk)
            n += len(chunk)
    return h.hexdigest(), n


def validation_and_run_directory(bundle) -> tuple:
    """[ROUND 9m] `validation.json` and `run/`, when a bundle carries them.

    Returns `(validation, run_directory, findings)`; each of the first two is
    None when the bundle does not carry it.  Every comparison is against a
    byte this gate already trusts: the manifest's own SHA-256, `run.json`'s
    source commit / profile / block count, and each stage file's
    `segment_bytes` / `segment_sha256`.  A flag the validation file reports
    false, a segment that is not the one its stage pins, a missing segment,
    or an entry of `run/` that is neither a segment nor the statement is a
    named finding."""
    f: list[str] = []
    v, vout = None, None
    vpath = os.path.join(bundle.dir, VALIDATION_FILE)
    if os.path.isfile(vpath):
        with open(vpath, "rb") as fh:
            raw = fh.read()
        vout = {
            "present": True,
            "bytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest(),
            "what": "written by a FRESH process AFTER the manifest (lane stage "
            "48), so the manifest does not pin it; read and compared with what "
            "IS pinned, never used for a figure",
        }
        try:
            v = json.loads(raw)
        except ValueError as exc:
            f.append(f"{VALIDATION_FILE}: not JSON ({exc})")
        if isinstance(v, dict):
            with open(os.path.join(bundle.dir, "manifest.json"), "rb") as fh:
                man_sha = hashlib.sha256(fh.read()).hexdigest()
            flags = {k: v.get(k) for k in VALIDATION_FLAGS}
            names = {
                "kind_matches": v.get("kind") == VALIDATION_KIND,
                "schema_matches": v.get("schema") == bundle.schema,
                "profile_matches": v.get("profile") == bundle.profile,
                "blocks_match": v.get("blocks") == bundle.blocks,
                "manifest_sha256_matches": v.get("manifest_sha256") == man_sha,
                "source_commit_matches":
                    v.get("source_commit") == bundle.run.get("source_commit"),
            }
            vout.update(names)
            vout["flags"] = flags
            vout["reverified_at_commit"] = v.get("reverified_at_commit")
            vout["receipt_bytes_declared"] = v.get("receipt_bytes")
            if not all(x is True for x in flags.values()):
                f.append(f"{VALIDATION_FILE}: a flag is not true: {flags}")
            if not all(names.values()):
                f.append(f"{VALIDATION_FILE}: does not name this bundle "
                         f"({[k for k, x in names.items() if not x]})")
        elif v is not None:
            f.append(f"{VALIDATION_FILE}: not a JSON object")
    rout = None
    rdir = os.path.join(bundle.dir, RUN_DIR)
    if os.path.isdir(rdir):
        want = {f"segment-{st.index:03d}.bin": st for st in bundle.stages}
        per, total, matching = [], 0, 0
        for fn, st in sorted(want.items()):
            path = os.path.join(rdir, fn)
            if not os.path.isfile(path):
                f.append(f"{RUN_DIR}/{fn}: absent, though {st.name} pins a segment")
                per.append({"file": fn, "present": False})
                continue
            digest, n = _sha256_of_file(path)
            ok = (n == st.doc.get("segment_bytes")
                  and digest == st.doc.get("segment_sha256"))
            total += n
            matching += ok
            per.append({"file": fn, "bytes": n, "matches_its_stage_pin": ok})
            if not ok:
                f.append(f"{RUN_DIR}/{fn}: {n} bytes / sha256 {digest[:12]} is "
                         f"not the segment {st.name} pins")
        unexpected = sorted(set(os.listdir(rdir)) - set(want) - {STATEMENT_DIR})
        for e in unexpected:
            f.append(f"{RUN_DIR}/{e}: neither a segment nor the statement")
        spath = os.path.join(rdir, STATEMENT_DIR, STATEMENT_FILE)
        statement = None
        if os.path.isdir(os.path.join(rdir, STATEMENT_DIR)):
            extra = sorted(set(os.listdir(os.path.join(rdir, STATEMENT_DIR)))
                           - {STATEMENT_FILE})
            for e in extra:
                f.append(f"{RUN_DIR}/{STATEMENT_DIR}/{e}: not the run statement")
        if os.path.isfile(spath):
            s_sha, s_n = _sha256_of_file(spath)
            statement = {"bytes": s_n, "sha256": s_sha}
            if isinstance(v, dict) and "run_statement_sha256" in v:
                statement["matches_validation"] = s_sha == v["run_statement_sha256"]
                if not statement["matches_validation"]:
                    f.append(f"{RUN_DIR}/{STATEMENT_DIR}/{STATEMENT_FILE}: its "
                             f"sha256 is not {VALIDATION_FILE}'s run_statement_sha256")
        rout = {
            "present": True,
            "segments_expected": len(want),
            "segments_matching_their_stage_pins": matching,
            "segment_bytes_total": total,
            "per_segment": per,
            "unexpected_entries": unexpected,
            "run_statement": statement,
            "what": "the receipt's segments and the public run statement, "
            "written beside the capture by lane stage 48; each segment is "
            "checked against the length and SHA-256 its stage file pins, which "
            "binds this verifier's view to the receipt bytes that were verified",
        }
    return vout, rout, f


class Stage:
    """One `stage-NN.json`: the per-proof content of the single-block schema
    plus the run's own locality words and commitment-kind fields."""

    def __init__(self, path: str, index: int, blocks: int,
                 schema: str = SCHEMA_4, store=None, refusals=None):
        with open(path, "rb") as fh:
            raw = fh.read()
        self.path = path
        self.name = os.path.basename(path)
        self.sha256 = hashlib.sha256(raw).hexdigest()
        self.bytes = len(raw)
        self.doc = json.loads(raw)
        d = self.doc
        if d.get("schema") != schema:
            raise ValueError(f"{self.name}: schema {d.get('schema')!r} is not {schema!r}")
        # [ROUND 9] `/5-run`: every array reference in this stage, resolved
        # into a checked zero-copy view.  A reference the store will not
        # resolve is a named finding on the bundle, not an exception here.
        self.arrays_resolved = 0
        if store is not None:
            self.arrays_resolved = resolve_document(
                d, store, self.name, refusals if refusals is not None else []
            )
        if d.get("kind") != STAGE_KIND:
            raise ValueError(f"{self.name}: kind {d.get('kind')!r} is not {STAGE_KIND!r}")
        if d.get("stage") != index:
            raise ValueError(f"{self.name}: declares stage {d.get('stage')}, not {index}")
        if d.get("blocks") != blocks:
            raise ValueError(f"{self.name}: declares {d.get('blocks')} blocks, not {blocks}")
        self.index = index

    # ------------------------------------------------------------ accessors
    @property
    def slots(self):
        return self.doc["arguments"]

    @property
    def mask(self):
        return self.doc["mask"]

    @property
    def roles(self):
        return self.doc["roles"]

    def role(self, name: str):
        for r in self.doc["roles"]:
            if r["role"] == name:
                return r
        raise KeyError(f"{self.name}: no {name} opening")

    def role_or_none(self, name: str):
        for r in self.doc["roles"]:
            if r["role"] == name:
                return r
        return None

    def boundary_opening(self):
        """The opening that discharges an internal boundary, or None."""
        for r in self.doc["roles"]:
            if r["commitment_kind"] == "internal-boundary":
                return r
        return None

    def key(self, role_name: str) -> str:
        """A name that separates an internal boundary from the external
        endpoint that shares its role name (format §9 item 5)."""
        r = self.role(role_name)
        if r["commitment_kind"] == "internal-boundary":
            return f"B{r['boundary']}"
        if r["commitment_kind"] == "external-endpoint":
            return f"E-{role_name}"
        return f"{role_name}@{self.index}"


class Shape:
    """`run.json["shape"]`, as attributes.  No value here is a literal."""

    def __init__(self, sh: dict, mask_domain: dict):
        self.raw = dict(sh)
        self.name = sh["name"]
        self.profile = sh["profile"]
        self.tokens = sh["tokens"]
        self.width = sh["width"]
        self.hidden = sh["hidden"]
        self.q_heads = sh["q_heads"]
        self.kv_heads = sh["kv_heads"]
        self.head_dim = sh["head_dim"]
        self.log_cols = sh["log_cols"]
        self.cols = sh["cols"]
        self.inv_rate = sh["inv_rate"]
        self.opened_cols = sh["opened_cols"]
        self.n_slots = sh["n_slots"]
        self.slots = [tuple(s) for s in sh["slots"]]
        self.a_groups = sh["a_groups"]
        self.h_groups = sh["h_groups"]
        self.endpoint_rows = sh["endpoint_rows"]
        self.endpoint_log_n = sh["endpoint_log_n"]
        self.endpoint_inv_rate = sh["endpoint_inv_rate"]
        self.mask_log_dom = mask_domain["log_dom"]
        self.mask_columns = mask_domain["columns"]
        if self.cols != 1 << self.log_cols:
            raise ValueError(f"shape: cols {self.cols} != 1 << log_cols {self.log_cols}")
        if len(self.slots) != self.n_slots:
            raise ValueError(
                f"shape: {len(self.slots)} slot triples for n_slots {self.n_slots}"
            )

    @property
    def enc_cols(self) -> int:
        return self.cols * self.inv_rate


class RunBundle:
    """A whole bundle: the run header, L stages, the manifest."""

    def __init__(self, directory: str):
        self.dir = os.path.abspath(directory)
        run_path = os.path.join(self.dir, "run.json")
        if not os.path.exists(run_path):
            raise ValueError(f"{self.dir}: no run.json -- not a run-capture bundle")
        with open(run_path, "rb") as fh:
            raw = fh.read()
        self.run_sha256 = hashlib.sha256(raw).hexdigest()
        self.run_bytes = len(raw)
        self.run = json.loads(raw)
        d = self.run
        if d.get("schema") not in SCHEMAS:
            raise ValueError(
                f"run.json: schema {d.get('schema')!r} is not one of {list(SCHEMAS)} "
                "(a schema-3 single-block capture must be read by "
                "zk60_native_jv_capture, not by this loader)"
            )
        self.schema = d["schema"]
        if d.get("kind") != RUN_KIND:
            raise ValueError(f"run.json: kind {d.get('kind')!r} is not {RUN_KIND!r}")
        if d.get("coverage") != COVERAGE:
            raise ValueError(f"run.json: coverage {d.get('coverage')!r} is not {COVERAGE!r}")
        if d["profile"] != d["transcript_domain"]:
            raise ValueError("run.json: the transcript domain differs from the profile")
        if bytes(d["transcript_domain_bytes"]).decode() != d["profile"]:
            raise ValueError("run.json: transcript_domain_bytes are not the profile string")
        self.profile = d["profile"]
        self.blocks = d["blocks"]
        self.boundaries = d["boundaries"]
        if self.boundaries != self.blocks - 1:
            raise ValueError(
                f"run.json: {self.boundaries} boundaries for {self.blocks} blocks"
            )
        self.shape = Shape(d["shape"], d["mask_domain"])
        with open(os.path.join(self.dir, "manifest.json"), "rb") as fh:
            self.manifest = json.loads(fh.read())
        # [ROUND 9] the binary array store, opened before any stage is read.
        # A `/4-run` bundle has none and must not have one; a `/5-run`
        # bundle must, and its length is checked against the manifest here
        # so that a truncated store is refused before a byte is resolved.
        self.array_refusals: list[str] = []
        self.store = None
        listed = {e["file"]: e for e in self.manifest.get("files", [])}
        if self.schema == SCHEMA_5:
            e = listed.get(ARRAY_STORE_FILE, {})
            try:
                self.store = ArrayStore(
                    os.path.join(self.dir, ARRAY_STORE_FILE),
                    declared_bytes=e.get("bytes"),
                    declared_sha256=e.get("sha256"),
                )
            except ArrayRefused as exc:
                self.array_refusals.append(str(exc))
        elif os.path.exists(os.path.join(self.dir, ARRAY_STORE_FILE)):
            self.array_refusals.append(
                f"{ARRAY_STORE_FILE}: present in a {SCHEMA_4} bundle, which "
                "never externalises an array"
            )
        self.stages = []
        for k, fn in enumerate(d["stage_files"]):
            self.stages.append(
                Stage(os.path.join(self.dir, fn), k, self.blocks,
                      schema=self.schema, store=self.store,
                      refusals=self.array_refusals)
            )
        if len(self.stages) != self.blocks:
            raise ValueError(f"run.json: {len(self.stages)} stage files for {self.blocks} blocks")
        # run.json itself carries no array of 256 entries today; the walk is
        # run over it all the same, so that a member that grew past the
        # threshold in a later writer is resolved rather than mis-read.
        if self.store is not None:
            self.run_arrays_resolved = resolve_document(
                self.run, self.store, "run.json", self.array_refusals
            )
        else:
            self.run_arrays_resolved = 0
        # STAGE 17 / decision D19: which BLAKE3 made these bytes.  The rule is
        # DERIVED from the block profile this bundle's shape names and then
        # compared with the declared `hash_tag`; it is never taken from it
        # (ruling T-7).  `hash_rule` is None when the comparison refused, and
        # a caller must not replay such a bundle.
        self.hash_rule_record = rule_for_bundle(self)
        self.hash_rule = self.hash_rule_record["rule"]
        # STAGE 18: whether each public table carries its `values`.
        self.public_tables_included = bool(d.get("public_tables_included", False))

    @property
    def name(self) -> str:
        return os.path.basename(self.dir)

    def boundary(self, k: int) -> dict:
        return self.run["internal_boundaries"][k]

    def labels(self) -> dict:
        return {t["label"]: t["what"] for t in self.run["transcript_labels"]}


# --------------------------------------------------------------- integrity
def integrity(bundle: RunBundle) -> dict:
    """Item 1 of the gate: hashes, schema strings, sizes against the shape.

    Every failure is a named string in `findings`; the caller decides.  The
    checks that need no arithmetic live here so that a bundle whose geometry
    contradicts its own shape never reaches a rank computation.
    """
    f: list[str] = []
    man = bundle.manifest
    if man.get("schema") != bundle.schema or man.get("kind") != MANIFEST_KIND:
        f.append(
            f"manifest.json: schema/kind {man.get('schema')!r}/{man.get('kind')!r} "
            f"is not {bundle.schema!r}/{MANIFEST_KIND!r}"
        )
    # [ROUND 9] every refusal the array store raised while the stages were
    # being read, by name.  A bundle with one of these is reported, not
    # crashed on.
    f.extend(bundle.array_refusals)
    if man.get("profile") != bundle.profile:
        f.append("manifest.json: profile differs from run.json's")
    if man.get("blocks") != bundle.blocks:
        f.append("manifest.json: block count differs from run.json's")

    listed = {e["file"]: e for e in man.get("files", [])}
    checked = 0
    for fn, e in sorted(listed.items()):
        path = os.path.join(bundle.dir, fn)
        if not os.path.exists(path):
            f.append(f"{fn}: in the manifest, absent from the directory")
            continue
        with open(path, "rb") as fh:
            raw = fh.read()
        checked += 1
        if len(raw) != e["bytes"]:
            f.append(f"{fn}: {len(raw)} bytes on disk, {e['bytes']} in the manifest")
        if hashlib.sha256(raw).hexdigest() != e["sha256"]:
            f.append(f"{fn}: sha256 on disk differs from the manifest's")
    on_disk = {
        fn
        for fn in os.listdir(bundle.dir)
        if os.path.isfile(os.path.join(bundle.dir, fn))
    }
    # [ROUND 9m] `validation.json` is the one unlisted file a bundle may
    # carry, and only because it is read and compared below
    validation, run_directory, vf = validation_and_run_directory(bundle)
    for fn in sorted(on_disk - set(listed) - {"manifest.json"}
                     - ({VALIDATION_FILE} if validation is not None else set())):
        f.append(f"{fn}: on disk, not in the manifest (the manifest does not list itself)")
    f.extend(vf)
    total = sum(e["bytes"] for e in listed.values())
    if man.get("total_bytes") not in (None, total):
        f.append(f"manifest.json: total_bytes {man.get('total_bytes')} != {total}")

    sh = bundle.shape
    if bundle.run["field_modulus"] != 0xFFFFFFFF00000001:
        f.append("run.json: field modulus is not Goldilocks")
    if bundle.run["extension_nonresidue"] != 7:
        f.append("run.json: the extension nonresidue is not 7")
    if hashlib.sha256(bytes(bundle.run["expected_policy"])).hexdigest() != bundle.run[
        "expected_policy_sha256"
    ]:
        f.append("run.json: expected_policy_sha256 differs from the policy bytes")
    words = bundle.run["run_shape_words"]
    want = [bundle.blocks, sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim]
    if words != want:
        f.append(f"run.json: run_shape_words {words} != the shape's {want}")
    got_labels = [t["label"] for t in bundle.run["transcript_labels"]]
    if got_labels != list(EXPECTED_LABELS):
        f.append(
            "run.json: the transcript labels are not the declared set "
            f"(got {got_labels})"
        )

    # sizes, per stage, against the shape and the boundary table
    for st in bundle.stages:
        d = st.doc
        if d["log_cols"] != sh.log_cols:
            f.append(f"{st.name}: log_cols {d['log_cols']} != the shape's {sh.log_cols}")
        if len(d["arguments"]) != sh.n_slots:
            f.append(f"{st.name}: {len(d['arguments'])} slots, the shape says {sh.n_slots}")
        for s, arg in enumerate(d["arguments"]):
            if arg["slot"] != s:
                f.append(f"{st.name}: argument {s} declares slot {arg['slot']}")
            main, ext, deg = sh.slots[s]
            if (arg["main"], arg["extension"], arg["degree"]) != (main, ext, deg):
                f.append(
                    f"{st.name} slot {s}: (main, extension, degree) "
                    f"{(arg['main'], arg['extension'], arg['degree'])} != the shape's "
                    f"{(main, ext, deg)}"
                )
        if bytes(d["block_digest"]) != bytes(bundle.run["block_digests"][st.index]):
            f.append(f"{st.name}: block_digest differs from run.json's")
        m = d["mask"]
        if m["rows"] != 2 * sh.n_slots + 4:
            f.append(f"{st.name}: M has {m['rows']} rows, not 2*slots+4")
        if len(m["specs"]) != sh.n_slots:
            f.append(f"{st.name}: M has {len(m['specs'])} specs for {sh.n_slots} slots")
        if len(m["columns"]) != sh.mask_columns:
            f.append(f"{st.name}: M opened {len(m['columns'])} columns, not {sh.mask_columns}")
        last = st.index == bundle.blocks - 1
        want_order = ["M", "A", "H", "Input"] + (["Output"] if last else [])
        if d["opening_order"] != want_order:
            f.append(f"{st.name}: opening_order {d['opening_order']} != {want_order}")
        if [r["role"] for r in d["roles"]] != want_order[1:]:
            f.append(f"{st.name}: the roles array does not follow opening_order")
        bc = d["boundary_committed"]
        if last:
            if bc is not None:
                f.append(f"{st.name}: the last stage commits a boundary")
        else:
            b = bundle.boundary(st.index)
            if bc is None:
                f.append(f"{st.name}: commits no boundary, run.json says boundary {st.index}")
            elif bc["boundary"] != st.index or bc["rows"] != b["rows"]:
                f.append(f"{st.name}: boundary_committed disagrees with run.json")
        for r in d["roles"]:
            p = r["params"]
            if p["log_cols"] != sh.log_cols or p["inv_rate"] != sh.inv_rate:
                f.append(f"{st.name} {r['role']}: PCS params differ from the shape")
            if p["num_col_checks"] != sh.opened_cols or len(r["columns"]) != sh.opened_cols:
                f.append(f"{st.name} {r['role']}: column-check count differs from the shape")
            if len(r["row_roles"]) != r["commitment"]["rows"]:
                f.append(f"{st.name} {r['role']}: row_roles shorter than the row count")
            if len(r["proximity_rhos"]) != r["commitment"]["rows"]:
                f.append(f"{st.name} {r['role']}: proximity_rhos != rows")
            kinds = [x["kind"] for x in r["row_roles"]]
            if kinds.count("prox") != 2:
                f.append(f"{st.name} {r['role']}: {kinds.count('prox')} proximity rows, not 2")
            if r["prox_row"] + 1 >= r["commitment"]["rows"]:
                f.append(f"{st.name} {r['role']}: the proximity pair runs off the end")
            if r["commitment_kind"] == "external-endpoint":
                if r["commitment"]["rows"] != sh.endpoint_rows:
                    f.append(f"{st.name} {r['role']}: endpoint rows != the shape's")

    # the boundary table, against the two stages that use it
    for k in range(bundle.boundaries):
        b = bundle.boundary(k)
        if b["boundary"] != k or b["index"] != k + 1:
            f.append(f"boundary {k}: boundary/index fields are not (k, k+1)")
        if b["sites"] != 2:
            f.append(f"boundary {k}: {b['sites']} claim sites, not 2")
        if b["row_rule"] != "data + 2*sites + 2":
            f.append(f"boundary {k}: row rule {b['row_rule']!r} is not the derived one")
        want_rows = b["data_rows"] + 2 * b["sites"] + 2
        if b["rows"] != want_rows:
            f.append(
                f"boundary {k}: {b['rows']} rows, the derived count is {want_rows} "
                "(ruling M-1: a single proximity row discloses 1)"
            )
        want_sites = list(range(b["data_rows"], b["data_rows"] + 2 * b["sites"]))
        if b["site_rows"] != want_sites:
            f.append(f"boundary {k}: site_rows {b['site_rows']} != {want_sites}")
        if b["prox_row"] != b["data_rows"] + 2 * b["sites"]:
            f.append(f"boundary {k}: prox_row is not the first row after the claim pairs")
        pairs = [tuple(b["site_rows"][2 * i : 2 * i + 2]) for i in range(b["sites"])]
        if len(set(pairs)) != len(pairs):
            f.append(f"boundary {k}: two claim sites share one reserved pair")
        if any(p[1] != p[0] + 1 for p in pairs):
            f.append(f"boundary {k}: a claim site's rows are not adjacent")
        if b["committed_at_stage"] != k or b["opened_at_stage"] != k + 1:
            f.append(f"boundary {k}: committed/opened at the wrong stage")
        if b["opening_in_stage_file"] != k + 1:
            f.append(f"boundary {k}: opening_in_stage_file is not k+1")
        sites = b["claim_sites"]
        if [s["stage"] for s in sites] != [k, k + 1] or [s["slot"] for s in sites] != [22, 21]:
            f.append(f"boundary {k}: claim_sites are not (stage k slot 22, stage k+1 slot 21)")
        op = bundle.stages[k + 1].boundary_opening()
        if op is None or op["boundary"] != k:
            f.append(f"boundary {k}: stage {k+1} has no opening for it")
        else:
            if op["commitment"]["rows"] != b["rows"]:
                f.append(f"boundary {k}: the opening's row count differs from run.json's")
            if op["site_rows"] != b["site_rows"] or op["prox_row"] != b["prox_row"]:
                f.append(f"boundary {k}: the opening's reserved rows differ from run.json's")
            if len(op["claims"]) != b["sites"]:
                f.append(f"boundary {k}: {len(op['claims'])} claims for {b['sites']} sites")
            got = [(s["stage"], s["slot"]) for s in op["claim_sources"]]
            if got != [(k, 22), (k + 1, 21)]:
                f.append(f"boundary {k}: claim_sources {got} are not the two claim sites")
        if bytes(bundle.stages[k].doc["boundary_committed"]["root"]) != bytes(
            op["commitment"]["root"]
        ):
            f.append(
                f"boundary {k}: the root committed in stage {k} is not the root opened "
                f"in stage {k+1}"
            )

    # [TINYLLAMA PORT, tools v4, finding G-10] the two EXTERNAL endpoints.
    # Until v4 the run pass compared every INTERNAL boundary's committed root
    # with the root opened one stage later, but never compared the
    # external-endpoint openings with run.json's `external_endpoints` -- the
    # comparison the standalone-block reader makes (`block_integrity`: the
    # policy's roots, and each opened root, against the declared roots).  So
    # control C5 at L = 1 (the only stage swapped for the other run's) was
    # refused by the replay alone.  Every retained bundle carries equal roots,
    # equal row counts and the policy's own roots / scales / context (checked
    # on all 30 run bundles on disk before this edit), so on an honest bundle
    # these lines add no finding and no record leaf.
    ee = bundle.run.get("external_endpoints")
    # [tools v5, review P-21] a missing member is a NAMED finding, never a
    # KeyError; and the three comparisons the block reader makes beyond v4's
    # (data rows, the endpoint commitment geometry, the approved scales)
    ee_keys = ("input_root", "output_root", "rows", "data_rows", "log_n",
               "inv_rate", "input_scale", "output_scale", "opened_at_stage")
    if isinstance(ee, dict) and any(k not in ee for k in ee_keys):
        f.append("run.json: external_endpoints lacks "
                 f"{[k for k in ee_keys if k not in ee]} (finding G-10)")
        ee = None
    if isinstance(ee, dict):
        if (ee["input_scale"], ee["output_scale"]) != (0, 0):
            f.append("run.json: external_endpoints scales "
                     f"{(ee['input_scale'], ee['output_scale'])} are not the "
                     "approved (0, 0) (finding G-10)")
        if (ee["log_n"], ee["inv_rate"]) != (sh.endpoint_log_n, sh.endpoint_inv_rate):
            f.append("run.json: external_endpoints log_n / inv_rate are not the "
                     "shape's endpoint geometry (finding G-10)")
    if not isinstance(ee, dict):
        if bundle.run.get("external_endpoints") is None:
            f.append("run.json: no external_endpoints table (finding G-10)")
    else:
        last = bundle.blocks - 1
        if list(ee.get("opened_at_stage") or []) != [0, last]:
            f.append(
                f"run.json: external_endpoints opened_at_stage "
                f"{ee.get('opened_at_stage')} is not [0, {last}] (finding G-10)"
            )
        for role_name, root_key, idx in (("Input", "input_root", 0),
                                         ("Output", "output_root", last)):
            st = bundle.stages[idx] if 0 <= idx < len(bundle.stages) else None
            r = st.role_or_none(role_name) if st is not None else None
            if r is None or r["commitment_kind"] != "external-endpoint":
                f.append(
                    f"stage {idx}: no external-endpoint {role_name} opening, "
                    f"run.json opens it there (finding G-10)"
                )
                continue
            if bytes(r["commitment"]["root"]) != bytes(ee[root_key]):
                f.append(
                    f"{st.name} {role_name}: the opened external-endpoint root is "
                    f"not run.json's external_endpoints {root_key} (finding G-10)"
                )
            if r["commitment"]["rows"] != ee["rows"]:
                f.append(
                    f"{st.name} {role_name}: endpoint rows "
                    f"{r['commitment']['rows']} != external_endpoints rows "
                    f"{ee['rows']} (finding G-10)"
                )
            if r.get("data_rows") != ee["data_rows"]:
                f.append(f"{st.name} {role_name}: endpoint data rows "
                         f"{r.get('data_rows')} != external_endpoints data_rows "
                         f"{ee['data_rows']} (finding G-10)")
            p = r.get("params") or {}
            if (p.get("log_cols"), p.get("inv_rate")) != (ee["log_n"], ee["inv_rate"]):
                f.append(f"{st.name} {role_name}: the opening's PCS parameters are "
                         "not external_endpoints' log_n / inv_rate (finding G-10)")
        # the policy the run header absorbs names the same roots and scales
        from zk60_native_rg_block import parse_policy  # (block imports this module)
        pol = parse_policy(bytes(bundle.run["expected_policy"]))
        if pol is None:
            f.append("run.json: expected_policy is not a 112-byte HBLKEXP1 frame "
                     "(finding G-10)")
        else:
            if (pol["input_root"], pol["output_root"]) != (
                    list(ee["input_root"]), list(ee["output_root"])):
                f.append("run.json: the policy's roots are not external_endpoints' "
                         "roots (finding G-10)")
            if (pol["input_scale"], pol["output_scale"]) != (
                    ee["input_scale"], ee["output_scale"]):
                f.append("run.json: the policy's scales are not external_endpoints' "
                         "scales (finding G-10)")
            if pol["context"] != list(bundle.run["context"]):
                f.append("run.json: the policy's context is not run.json's context "
                         "(finding G-10)")

    # opened exactly once: no two openings of the whole run share a root
    roots = {}
    for st in bundle.stages:
        for r in st.roles:
            key = bytes(r["commitment"]["root"]).hex()
            roots.setdefault(key, []).append(f"stage {st.index} {r['role']}")
    twice = {k: v for k, v in roots.items() if len(v) > 1}
    for k, v in twice.items():
        f.append(f"the commitment {k[:16]} is opened more than once: {v}")

    # STAGE 17 / D19: the declared hash tag against this tool's own derivation
    hr = bundle.hash_rule_record
    for r in hr["refusals"]:
        f.append(r)

    store = (
        bundle.store.summary()
        if bundle.store is not None
        else {
            "file": None,
            "what": f"schema {bundle.schema} keeps every array inline; there is "
            "no binary store to resolve",
            "ok": True,
        }
    )
    store["references_resolved_per_stage"] = {
        st.name: st.arrays_resolved for st in bundle.stages
    }
    store["references_resolved_in_run_json"] = bundle.run_arrays_resolved
    return {
        "bundle": bundle.name,
        "dir": bundle.dir,
        "schema": bundle.run["schema"],
        "array_store": store,
        "kind": bundle.run["kind"],
        "coverage": bundle.run["coverage"],
        "profile": bundle.profile,
        "block_profile": bundle.run["block_profile"],
        "blocks": bundle.blocks,
        "boundaries": bundle.boundaries,
        "source_commit": bundle.run["source_commit"],
        "fully_verified": bundle.run["fully_verified"],
        "privacy_review_complete": bundle.run["privacy_review_complete"],
        "weight_policy": bundle.run["weight_policy"],
        "public_tables_included": bundle.run["public_tables_included"],
        "hash_rule": {k: v for k, v in hr.items() if k != "rule"},
        "manifest_files_checked": checked,
        "manifest_total_bytes": total,
        "source_pins": man.get("source_pins", []),
        "shape": bundle.shape.raw,
        "mask_domain": bundle.run["mask_domain"],
        "distinct_roots_opened": len(roots),
        "any_root_opened_twice": bool(twice),
        # [ROUND 9m] present only when the bundle carries them, so that no
        # record of a bundle without them gains a leaf
        **({"validation_file": validation} if validation is not None else {}),
        **({"run_directory": run_directory} if run_directory is not None else {}),
        "findings": f,
        "ok": not f,
    }
