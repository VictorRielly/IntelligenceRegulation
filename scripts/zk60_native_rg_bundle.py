"""Loader for a RUN CAPTURE bundle, schema `hashline-native-capture/4-run`.

Format: `docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md` on lane
`zk60-private-block-125m`; writer `hashline/src/private_block/run_capture.rs`.

A bundle is a DIRECTORY -- `run.json`, `stage-00.json` ... `stage-{L-1}.json`,
`manifest.json`, `README.md` -- and it is the VERIFIER'S VIEW of one private
run of L blocks under one transcript.  It carries no witness value, no pad,
no mask coefficient, no unopened column and no unmasked sumcheck round.

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

from zk60_native_rg_hashrule import rule_for_bundle  # noqa: E402

SCHEMA = "hashline-native-capture/4-run"
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


class Stage:
    """One `stage-NN.json`: the per-proof content of the single-block schema
    plus the run's own locality words and commitment-kind fields."""

    def __init__(self, path: str, index: int, blocks: int):
        with open(path, "rb") as fh:
            raw = fh.read()
        self.path = path
        self.name = os.path.basename(path)
        self.sha256 = hashlib.sha256(raw).hexdigest()
        self.bytes = len(raw)
        self.doc = json.loads(raw)
        d = self.doc
        if d.get("schema") != SCHEMA:
            raise ValueError(f"{self.name}: schema {d.get('schema')!r} is not {SCHEMA!r}")
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
        if d.get("schema") != SCHEMA:
            raise ValueError(
                f"run.json: schema {d.get('schema')!r} is not {SCHEMA!r} "
                "(a schema-3 single-block capture must be read by "
                "zk60_native_jv_capture, not by this loader)"
            )
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
        self.stages = []
        for k, fn in enumerate(d["stage_files"]):
            self.stages.append(Stage(os.path.join(self.dir, fn), k, self.blocks))
        if len(self.stages) != self.blocks:
            raise ValueError(f"run.json: {len(self.stages)} stage files for {self.blocks} blocks")
        with open(os.path.join(self.dir, "manifest.json"), "rb") as fh:
            self.manifest = json.loads(fh.read())
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
    if man.get("schema") != SCHEMA or man.get("kind") != MANIFEST_KIND:
        f.append(
            f"manifest.json: schema/kind {man.get('schema')!r}/{man.get('kind')!r} "
            f"is not {SCHEMA!r}/{MANIFEST_KIND!r}"
        )
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
    for fn in sorted(on_disk - set(listed) - {"manifest.json"}):
        f.append(f"{fn}: on disk, not in the manifest (the manifest does not list itself)")
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

    return {
        "bundle": bundle.name,
        "dir": bundle.dir,
        "schema": bundle.run["schema"],
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
        "findings": f,
        "ok": not f,
    }
