#!/usr/bin/env python3
"""[GATE ROUND 17, tools v20, 2026-10-26] The privacy gate on a CLASSIFIER
run capture (schema `hashline-native-capture/7-classify-run`, coverage
`classify-run-all-stages-v1`): stage IN-C, the L block stages and stage
OUT-C under one transcript, ONE external endpoint (D40) and a public verdict.

    python3 zk60_native_rg_classgate.py --bundle <capture> --evidence <dir> --name <name>
        [--calibration-export <dir>] [--no-controls] [--no-full-preimage]

WHAT IT REUSES.  The token gate's machinery, unchanged: the generic
per-commitment model (`RunRoleView`), the masking block and its CFS port
(`mask_cfs_stage`), the hash layer, the full zero-data preimage
(`full_preimages`), the joint preimage, the boundary figures and the frozen
block-stage terminal port (`check_terminals`, through the token gate's
one-stage shim).  What is NEW here:

1. The loader (`ClassRunBundle`): schema 7, stage kinds IN-C / BLOCK /
   OUT-C, the `classify` facts, the re-derived classifier geometry
   (`zk60_native_rg_classify.ClassGeom`).
2. The replay (`ClassRunReplay`): the token replay with the classifier
   header -- after `schedule` it absorbs `classify-verdict` (the run.json
   verdict, one byte) and `classify-chunk` (D41's ChunkRef, seven u64 LE)
   from the CAPTURE'S OWN FACTS, so the run binding reproduces only if the
   recorded verdict and chunk are the ones the transcript bound
   (classify.rs:879-880) -- and the classifier stages' prefixes (IN-C draws
   beta, gamma, alpha and r_emb; OUT-C draws gamma, alpha) and opening
   orders (OUT-C: M, A-out, H-out, B-out; no output endpoint).
3. The role adapter with the classifier's declared groups (IN-C A 3 / H 4,
   OUT-C A 16 / H 5).
4. The classifier items: the 12 slots' terminal identity with every public
   table rebuilt from public data and the verdict (the one-public-bit check)
   and B-3 (`zk60_native_rg_classterminals`), NL-1 on them, D41's chunk
   checks, the classifier joint figure (no output endpoint), and controls on
   the capture.

The block stages' calibration: a classifier capture's shape carries no
calibration constants (as a token capture's), so they come from an export
(`--calibration-export`, the R12-based Shieldstral captures) or, at the
synthetic rung, from the fixture the capture test declares
(`trained_calib_tests.rs:55-58` rung_tc_calibration, READ at frozen-r12); the
terminal identity at those constants is then their check (a wrong constant
fails its slots: TL-2 / NC-1).

[v21, gate round 18, 2026-10-29] PORTED to token frozen-r14 (rungs R-C2 and
R-C3; statement schema `zk60-classify-run/3`; the capture schema is still
`7-classify-run`, its `classify` keys unchanged):

* the pins: `zk60_native_rg_classpins.classify_capture_pins_v21` (the five
  ported classifier files at r14, `classify_tied.rs` new; the native files the
  rebase onto R12b moved, chained to the block gate's native R9 readings);
* the profile text: every R-C2 / R-C3 field re-derived and checked
  (`item-length`, `pad-id`, `pad-positions`, `verdict-row`, `chunk-size` = the
  PLAN's size T - P0 - S, `short-content=...`, `margin-scale(-bits)`, the
  tied source, the D45 rulings sentence);
* D41 with the plan size (never n) and n == b - a; a SHORT item is ONE chunk
  [0, n) (`zk60_native_rg_classify.chunk_ranges`);
* B-3 with the tables DERIVED from the pinned tensor
  (`zk60_native_rg_classtied`): w_Delta and tau are rebuilt, none taken;
* OUTC-00 and the joint figure at the public verdict row P0 + n + S - 1, and
  B_out's OUTC-00 claim decoded to that row;
* gate item C-13 (short items): controls C13-1..C13-4 on the capture (a
  doctored pad position, a pad inside the content range, a shifted verdict
  row, a declared length that is not the actual one).

[v22, gate round 19, 2026-10-29] PORTED to token frozen-r16b on native R13
(the real Shieldstral-1.0-3B classifier; captures made through the gate's
capture tree `capture-tree-r16b` + the test-only patches H19-1..H19-4):

* the pins: `zk60_native_rg_classpins.classify_capture_pins_v22` (the five
  classifier files at r16b, the native R12b -> R13 and token r14 -> r16b
  readings of `zk60_native_rg_r13_pins`, the gate's own H19-3 / H19-4 patch
  readings; 72 pins on an r16b classifier capture);
* the R13 classifier run profiles (Shieldstral T128 / T256 and the test-only
  R13 h24 rung): their pad ids (11 / 2), overlaps (8 / 4), block profiles, the
  registered Shieldstral policy list (D45(2): the three moderate category
  policies; the card policy refused by name), and EVERY block stage line's
  R13 gate denominator (one per stage, in the class range [17, 24]; none at a
  legacy profile);
* B-3 at the real Shieldstral profile: the margin row and the embedding
  DERIVED by the gate from the pinned checkpoint (`--tied-export`,
  `zk60_native_rg_classtied.shieldstral_derive`) and tau rebuilt with the
  exact numpy fold;
* the block stages at an R13 shape: `zk60_native_rg_r13blocks.r13_block_terminals`
  (the block-port sub-lane's module: the 23 slots at each stage's own gate
  denominator and precision, R13's seven redefined slots, the R13 plane list).

NOTHING HERE IS A PRIVACY RESULT OR A PRIVACY ACCEPTANCE.
"""

from __future__ import annotations

import copy
import hashlib
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_classify as CL  # noqa: E402
import zk60_native_rg_classpins as CP  # noqa: E402
import zk60_native_rg_classterminals as CT  # noqa: E402
import zk60_native_rg_tokengate as TG  # noqa: E402
from zk60_native_rg_arrays import ARRAY_STORE_FILE, ArrayRefused, ArrayStore, resolve_document  # noqa: E402
from zk60_native_rg_bundle import MANIFEST_KIND, Shape, Stage  # noqa: E402
from zk60_native_rg_hashrule import rule_for_bundle  # noqa: E402

SCHEMA_7 = "hashline-native-capture/7-classify-run"
RUN_KIND = "zk60-run-verifier-observations"
STAGE_KIND = "zk60-run-stage-observations"
COVERAGE_7 = "classify-run-all-stages-v1"
STAGE_KINDS_7 = ("IN-C", "BLOCK", "OUT-C")
ORDER_7 = {"IN-C": ["M", "A-in", "H-in", "E-token-in"], "BLOCK": ["M", "A", "H", "Input"],
           "OUT-C": ["M", "A-out", "H-out", "B-out"]}
GROUPS_7 = {"A-in": CL.INC_A_GROUPS, "H-in": CL.INC_H_GROUPS, "A-out": CL.OUTC_A_GROUPS, "H-out": CL.OUTC_H_GROUPS}
CANON_7 = {"A-in": ("A", "stage-in"), "H-in": ("H", "stage-in"), "A-out": ("A", "stage-out"),
           "H-out": ("H", "stage-out"), "E-token-in": ("Input", "external-endpoint"),
           "B-out": ("Output", "internal-boundary")}
EXPECTED = TG.EXPECTED
# the rung's block calibration (READ: frozen-r12 trained_calib_tests.rs:55-58,
# `rung_tc_calibration`, the classifier capture test's `rung()`)
RUNG_FIXTURE_CALIBRATION = {"norm_tn": 10, "norm_cn_a": 1336, "norm_cn_m": 2158, "norm_ceps": 33554467,
                            "sh_ao": 6, "sh_qkv": 8, "sh_s": 5, "sh_o": 10, "sh_g": 8, "sh_h": 13, "sh_z": 5}
RUNG_BLOCK_PROFILE = "hashline-zk-mr1/private-block-rung-tc-t32-dev/1"


# ------------------------------------------------------------------ the loader
class ClassStage(Stage):
    def __init__(self, path, index, stages, store, refusals):
        with open(path, "rb") as fh:
            raw = fh.read()
        self.path, self.name = path, os.path.basename(path)
        self.sha256, self.bytes = hashlib.sha256(raw).hexdigest(), len(raw)
        self.doc = json.loads(raw)
        d = self.doc
        if d.get("schema") != SCHEMA_7:
            raise ValueError(f"{self.name}: schema {d.get('schema')!r} is not {SCHEMA_7!r}")
        self.arrays_resolved = resolve_document(d, store, self.name, refusals) if store else 0
        if d.get("kind") != STAGE_KIND:
            raise ValueError(f"{self.name}: kind {d.get('kind')!r}")
        if d.get("stage") != index or d.get("stages") != stages:
            raise ValueError(f"{self.name}: declares stage {d.get('stage')} of {d.get('stages')}, not {index} of {stages}")
        if d.get("stage_kind") not in STAGE_KINDS_7:
            raise ValueError(f"{self.name}: stage_kind {d.get('stage_kind')!r}")
        self.index = index
        self.kind = d["stage_kind"]

    key = TG.TokenStage.key


class ClassRunBundle:
    """A classifier capture: the run header, `classify`, L + 2 stages."""

    def __init__(self, directory: str):
        self.dir = os.path.abspath(directory)
        with open(os.path.join(self.dir, "run.json"), "rb") as fh:
            raw = fh.read()
        self.run_sha256, self.run_bytes = hashlib.sha256(raw).hexdigest(), len(raw)
        self.run = d = json.loads(raw)
        if d.get("schema") != SCHEMA_7:
            raise ValueError(f"run.json: schema {d.get('schema')!r} is not {SCHEMA_7!r}")
        self.schema = SCHEMA_7
        if d.get("kind") != RUN_KIND or d.get("coverage") != COVERAGE_7:
            raise ValueError("run.json: kind / coverage is not a classifier run's")
        if d["profile"] != d["transcript_domain"] or bytes(d["transcript_domain_bytes"]).decode() != d["profile"]:
            raise ValueError("run.json: the transcript domain is not the profile")
        if "token_io" in d or "classify" not in d:
            raise ValueError("run.json: a classifier run carries `classify` and no `token_io`")
        self.profile = d["profile"]
        self.l = d["blocks"]
        self.n_stages = d["stages"]
        if self.n_stages != self.l + 2 or d["boundaries"] != self.l + 1:
            raise ValueError("run.json: a classifier run has L + 2 stages and L + 1 boundaries")
        # [v21] finding F18-1 (capture format, token frozen-r14): the classifier
        # writer emits `sh.slots()` WHOLE (run_capture.rs:2717-2758 at ef9c54db;
        # MAX_SLOTS = 24 since native R9) while declaring n_slots = 23; the block
        # writer takes n_slots (:2229). Shape::slots is zero beyond n_slots
        # (shape.rs:2286-2288), so the extra triple is the unused SC_DD slot's
        # (0, 0, 0). Accepted only when EVERY extra triple is zero, recorded, and
        # stripped in memory (the bytes on disk are hashed as they are).
        sh_doc = d["shape"]
        extra = sh_doc.get("slots", [])[sh_doc.get("n_slots", 0):]
        self.shape_slot_note = None
        if extra:
            if any(list(x) != [0, 0, 0] for x in extra):
                raise ValueError(f"shape: {len(extra)} slot triples beyond n_slots {sh_doc.get('n_slots')} and not all zero")
            sh_doc = dict(sh_doc, slots=sh_doc["slots"][:sh_doc["n_slots"]])
            d["shape"] = sh_doc
            self.shape_slot_note = {"finding": "F18-1", "extra_zero_slot_triples_stripped": len(extra),
                                    "declared_n_slots": sh_doc["n_slots"],
                                    "why": "the classifier capture writer emits Shape::slots() (MAX_SLOTS) unclipped; "
                                           "the triples beyond n_slots are (0, 0, 0)"}
        self.shape = Shape(sh_doc, d["mask_domain"])
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
        self.stages = [ClassStage(os.path.join(self.dir, fn), k, self.n_stages, self.store, self.array_refusals)
                       for k, fn in enumerate(d["stage_files"])]
        for st in self.stages:
            if st.doc.get("blocks") != self.l:
                raise ValueError(f"{st.name}: declares {st.doc.get('blocks')} blocks, not {self.l}")
        self.run_arrays_resolved = resolve_document(self.run, self.store, "run.json", self.array_refusals) if self.store else 0
        self.hash_rule_record = rule_for_bundle(self)
        self.hash_rule = self.hash_rule_record["rule"]
        self.public_tables_included = bool(d.get("public_tables_included", False))
        self.blocks = self.n_stages
        cf = d["classify"]
        import zk60_native_rg_classtied as TD
        self.profile_fields = TD.profile_fields(cf.get("profile_text", ""))
        pad = self.profile_fields["pad_id"]
        self.geom = CL.ClassGeom(name=d["profile"], tokens=cf["T"], t_pad=cf["t_pad"], d=cf["d"], d_pad=cf["d_pad"],
                                 v=cf["V"], p0=cf["P0"], n=cf["n"], s=cf["S"], c=cf["policy"]["c"],
                                 num_special=cf["policy"]["num_special"], block_log_n=self.shape.endpoint_log_n,
                                 block_inv_rate=self.shape.endpoint_inv_rate, pad=pad if pad is not None else -1)

    @property
    def name(self) -> str:
        return os.path.basename(self.dir)

    def labels(self) -> dict:
        return {t["label"]: t["what"] for t in self.run["transcript_labels"]}

    boundary = TG._boundary_facts


def load(directory: str) -> ClassRunBundle:
    return ClassRunBundle(directory)


def chunk_word(cf: dict) -> bytes:
    ch = cf["chunk"]
    return CL.chunk_ref_bytes(ch["index"], ch["count"], ch["a"], ch["b"], ch["total"], ch["size"], ch["overlap"])


# ------------------------------------------------------------------ the replay
class ClassRunReplay(TG.TokenRunReplay):
    """`TokenRunReplay` with the classifier header and stage prefixes."""

    def run(self):
        b = self.b
        d = b.run
        rule = getattr(b, "hash_rule", None)
        if rule is None:
            self._fail("the hash rule was refused for this bundle; no replay")
            self.rule_name = None
            return self
        self.rule_name = rule.name
        tr = rule.transcript(bytes(d["transcript_domain_bytes"]))
        tr.absorb(b"run-shape", b"".join(int(v).to_bytes(8, "little") for v in d["run_shape_words"]))
        tr.absorb(b"expected-IO", bytes(d["expected_policy"]))
        tr.absorb(b"public-statement", bytes(d["public_statement_digest"]))
        tr.absorb(b"parameters", d["parameter_line"].encode())
        tr.absorb(b"calibration", bytes(d["calibration"]))
        tr.absorb(b"schedule", bytes(d["schedule_digest"]))
        # [CLASSIFY] the public verdict and the chunk, from the capture's facts
        cf = d["classify"]
        tr.absorb(b"classify-verdict", bytes([int(cf["verdict"])]))
        tr.absorb(b"classify-chunk", chunk_word(cf))
        self.run_binding_ok = list(tr.state) == d["run_binding"]
        self.checkpoints += 1
        if not self.run_binding_ok:
            self._fail("run header: the state after the header (verdict and chunk included) is not run_binding")
        for st in b.stages:
            self._stage(tr, st)
        self.final_counter = tr.counter
        return self

    def _stage(self, tr, st):  # noqa: C901 (the token replay's body, the kinds changed)
        from zk60_native_jv_field import f2_from_list
        sh = self.b.shape
        k, doc, acc = st.index, st.doc, self.stages[st.index]
        tag = f"stage {k} ({st.kind})"
        self._check_state(tr, doc["header"], f"{tag} header")
        start = self._open_stage(tr, st, doc, tag)
        self._absorb_root(tr, b"A", doc["a_root"], doc["a_rows"], doc["log_cols"])
        tr.absorb(b"M", bytes(doc["mask_root"]))
        want_n = {"IN-C": 3, "BLOCK": 3, "OUT-C": 2}[st.kind]
        if len(doc["logup_challenges"]) != want_n:
            self._fail(f"{tag}: {len(doc['logup_challenges'])} LogUp challenges recorded, the stage draws {want_n}")
        logup = tr.challenge_fp2_vec(want_n)
        for i, want in enumerate(doc["logup_challenges"][:want_n]):
            self._eq_f2(logup[i], want, f"{tag} LogUp challenge {i}")
        acc["logup"] = logup
        if st.kind == "IN-C":
            n_emb = CL.clog2(self.b.geom.d_pad)
            if doc.get("r_emb") is None or len(doc["r_emb"]) != n_emb:
                self._fail(f"{tag}: r_emb has the wrong length (the stage draws {n_emb})")
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
        if order != ORDER_7[st.kind]:
            self._fail(f"{tag}: opening_order {order} is not the {st.kind} stage's {ORDER_7[st.kind]}")
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


# ------------------------------------------------------------------ integrity
def _sha(path):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def class_integrity(b) -> dict:
    """Hashes, schema, pins, and every classifier fact against the
    RE-DERIVED geometry: the door's derived constants, the plane indexes of
    IN-C / OUT-C, the input endpoint, NO output endpoint, the boundaries,
    D41's chunk derivation."""
    f = []
    man = b.manifest
    if man.get("schema") != SCHEMA_7 or man.get("kind") != MANIFEST_KIND:
        f.append("manifest.json: schema / kind is not a classifier run's")
    for e in man.get("files", []):
        p = os.path.join(b.dir, e["file"])
        if not os.path.exists(p):
            f.append(f"manifest lists {e['file']}, which is absent")
        elif _sha(p) != e["sha256"]:
            f.append(f"{e['file']}: sha256 differs from the manifest")
    listed = {e["file"] for e in man.get("files", [])}
    for fn in b.run["stage_files"] + ["run.json", ARRAY_STORE_FILE]:
        if fn not in listed:
            f.append(f"{fn} is not in the manifest")
    f += [f"array store: {x}" for x in b.array_refusals]
    pins = CP.classify_capture_pins(man)
    f += [f"source pin: {x}" for x in pins["refusals"]]
    g, cf, L = b.geom, b.run["classify"], b.l
    f += [f"door: {x}" for x in g.door_findings]
    for k_, want in (("V_pad", g.v_pad), ("limbs", g.limbs), ("margin_window_bits", g.window_bits),
                     ("limbs_at_lo_entry", CL.LAM_BASE), ("r_emb_len", CL.clog2(g.d_pad))):
        if cf.get(k_) != want:
            f.append(f"classify.{k_} is {cf.get(k_)}, re-derived {want}")
    if cf.get("output_endpoint") is not None:
        f.append("classify.output_endpoint is not null (D40: no output endpoint)")
    if cf.get("verdict") not in (0, 1):
        f.append("classify.verdict is not one bit")
    if cf.get("run_profile") != b.profile:
        f.append("classify.run_profile is not the run profile")
    # the door's derived final-norm constants
    import math
    fn = cf["final_norm"]
    d_max = math.isqrt(fn["ceps"] + g.d * 32768 * 32768)
    if cf.get("d_max") != d_max or cf.get("wrho") != fn["tn"] + 1 + d_max.bit_length():
        f.append(f"classify d_max / wrho {cf.get('d_max')} / {cf.get('wrho')} are not the derived {d_max} / {fn['tn'] + 1 + d_max.bit_length()}")
    # the policy as the profile text names it, and its template digest
    td = CT.template_digest(cf["policy"]["prefix_ids"], cf["policy"]["suffix_ids"])
    if bytes(cf["policy"]["template_digest"]).hex() != td:
        f.append("classify.policy.template_digest is not the template ids' digest")
    pt = cf.get("profile_text", "")
    pf = b.profile_fields
    # [v21] the R-C2 / R-C3 profile text (classify.rs:578-622 at r14): every
    # length field RE-DERIVED from (T, P0, n, S) and the pad id the policy's
    rc3 = {"item_length": g.item_len(), "pad_positions": g.pad_positions(), "verdict_row": g.verdict_row(),
           "chunk_size": g.plan_size(), "T": g.tokens, "P0": g.p0, "n": g.n, "S": g.s}
    for key, want in rc3.items():
        if pf.get(key) != want:
            f.append(f"the profile text's {key} is {pf.get(key)!r}, re-derived {want}")
    if pf.get("pad_id") is None or not (0 <= pf["pad_id"] < g.v):
        f.append(f"the profile text's pad-id {pf.get('pad_id')!r} is not an id below V")
    elif pf["pad_id"] != CL.PAD_IDS.get(b.profile):
        f.append(f"the profile text's pad-id {pf['pad_id']} is not the registered policy's {CL.PAD_IDS.get(b.profile)!r}")
    for frag in (f"threshold c={cf['policy']['c']} ", f"yes={cf['policy']['yes']} no={cf['policy']['no']}",
                 f"ctl=ids<{cf['policy']['num_special']} ", f"template={td}",
                 f"{bytes(cf['margin_vector']['digest']).hex()}", f"byte-limbs={g.limbs} ",
                 f"P0={g.p0} n={g.n} S={g.s} ", "no-output-endpoint",
                 # [v21] R-C2 / R-C3 / D45
                 f"item-length={g.item_len()} pad-id={pf.get('pad_id')} pad-positions={g.pad_positions()} "
                 f"verdict-row={g.verdict_row()} ",
                 f"chunk-size={g.plan_size()} chunk-overlap={CL.CHUNK_OVERLAPS.get(b.profile)} chunk-split=end-aligned "
                 "short-content=one-chunk-of-its-length-pad-pinned ",
                 "margin-scale-bits=", "tied-source=",
                 "rulings: B-5 n-public=true B-6 fixed-policy-list=true B-8 binding=input-endpoint-root "
                 "B-4 fail-closed=true (accepted by Victor: D45, 2026-10-29)"):
        if frag not in pt:
            f.append(f"the profile text does not carry {frag.strip()[:60]!r}")
    if cf.get("profile_text", "") not in b.run["parameter_line"]:
        f.append("the profile text is not inside the absorbed parameter line")
    # [v21] the schedule's OUT-C stage line names the verdict row (classify.rs:974-979 at r14)
    want_line = f"= B_out at the fixed public row {g.verdict_row()} at pair row"
    if not any(want_line in ln for ln in b.run.get("stage_lines", [])):
        f.append(f"no stage line names B_out at the verdict row {g.verdict_row()}")
    # [v22] the R13 classifier run profiles: the block profile, every block
    # stage line's gate denominator (classify.rs `stage_lines` at r16b), the
    # registered Shieldstral policy list (D45(2))
    import re as _re
    gates = []
    for ln in b.run.get("stage_lines", []):
        m = _re.search(r"^stage (\d+) \(block (\d+)\):", ln)
        if not m:
            continue
        found = _re.findall(r"; R13 gate denominator (\d+) \(the layer record's accuracy-gate-layer\)", ln)
        gates.append({"stage": int(m.group(1)), "block": int(m.group(2)),
                      "gate": int(found[0]) if len(found) == 1 else None, "mentions": len(found)})
    r13 = b.profile in CL.R13_CLASSIFY_RUN_PROFILES
    if r13:
        if b.run["shape"].get("profile") != CL.R13_BLOCK_PROFILE_OF[b.profile]:
            f.append(f"the block profile {b.run['shape'].get('profile')!r} is not the R13 block profile "
                     f"{CL.R13_BLOCK_PROFILE_OF[b.profile]!r} of {b.profile}")
        if len(gates) != L or [g_["block"] for g_ in gates] != list(range(L)):
            f.append(f"the stage lines name {len(gates)} block stages, the run has {L}")
        for g_ in gates:
            if g_["mentions"] != 1 or g_["gate"] is None or not (17 <= g_["gate"] <= 24):
                f.append(f"stage {g_['stage']}: the stage line names {g_['mentions']} R13 gate denominator(s) "
                         f"{g_['gate']!r}, one in [17, 24] is required at an R13 profile")
        if b.profile != CL.RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST:
            f += [f"policy: {x}" for x in CL.shieldstral_policy_check(cf["policy"])]
    elif any(g_["mentions"] for g_ in gates):
        f.append("a legacy classifier profile's stage line names an R13 gate denominator")
    # D41: the chunk the header absorbs, re-derived from (total, index, the
    # PLAN: size T - P0 - S, the registered overlap); n == b - a [v21]
    ch = cf["chunk"]
    d41 = {"recorded": ch, "plan_size": g.plan_size(), "short_item": g.is_short()}
    try:
        rng = CL.chunk_ranges(ch["total"], ch["size"], ch["overlap"])
        d41["ranges"] = rng
        ok = (ch["size"] == g.plan_size() and ch["count"] == len(rng) and 0 <= ch["index"] < len(rng)
              and (ch["a"], ch["b"]) == rng[ch["index"]] and ch["b"] - ch["a"] == g.n
              and ch["overlap"] == CL.CHUNK_OVERLAPS.get(b.profile))
        if not ok:
            f.append(f"D41: the chunk {ch} is not the split's (plan size T - P0 - S = {g.plan_size()}, n = b - a = {g.n}, "
                     f"overlap {CL.CHUNK_OVERLAPS.get(b.profile)})")
        d41["ok"] = ok
    except ValueError as exc:
        f.append(f"D41: {exc}")
        d41["ok"] = False
    # the stage kinds and the two classifier stages' plane tables
    kinds = [st.kind for st in b.stages]
    if kinds != ["IN-C"] + ["BLOCK"] * L + ["OUT-C"]:
        f.append(f"stage kinds {kinds} are not IN-C, {L} x BLOCK, OUT-C")
    for st, kind in ((b.stages[0], "IN-C"), (b.stages[-1], "OUT-C")):
        spi = st.doc.get("stage_plane_index")
        if spi is None:
            f.append(f"stage {kind}: no stage_plane_index")
            continue
        want = CT.plane_index_c(g, kind)
        for key in ("a_rows", "a_data_rows", "a_mask_base", "a_prox", "h_rows", "h_data_rows", "h_mask_base",
                    "h_prox", "h_u", "h_u_rows", "log_n"):
            if spi.get(key) != want[key]:
                f.append(f"stage {kind}: `{key}` is {spi.get(key)!r} in the capture, {want[key]!r} re-derived")
        if [p["name"] for p in spi.get("a_planes", [])] != want["a_planes"]:
            f.append(f"stage {kind}: A plane names differ from the re-derived")
        if [p["name"] for p in spi.get("h_planes", [])] != want["h_planes"]:
            f.append(f"stage {kind}: H plane names differ from the re-derived")
        lay = g.stage_in_c() if kind == "IN-C" else g.stage_out_c()
        if [p["log_size"] for p in spi["a_planes"]] != lay.a_log or [p["log_size"] for p in spi["h_planes"]] != lay.h_log:
            f.append(f"stage {kind}: plane logs differ from the re-derived")
        if st.doc["a_rows"] != lay.a_rows or st.doc["h_rows"] != lay.h_rows:
            f.append(f"stage {kind}: committed rows {st.doc['a_rows']} / {st.doc['h_rows']} are not {lay.a_rows} / {lay.h_rows}")
        if [tuple(s) for s in st.mask["specs"]] != [tuple(s) for s in lay.mask_specs()]:
            f.append(f"stage {kind}: mask specs differ from the re-derived")
        got_planes = {row["slot"]: [p["name"] for p in row["planes"]] for row in spi.get("slot_planes", [])}
        for row in want["slots"]:
            names = [x.split(":", 1)[1] for x in row["planes"]]
            if got_planes.get(row["slot"]) is not None and got_planes[row["slot"]] != names:
                f.append(f"stage {kind} slot {row['slot']}: the capture's plane list differs from the port's")
    # the ONE external endpoint, and no other
    st0, stz = b.stages[0], b.stages[-1]
    r = st0.role_or_none("E-token-in")
    ep = g.endpoint()
    if r is None:
        f.append("E-token-in: no opening in stage IN-C")
    else:
        if r["commitment"]["root"] != cf["input_root"]:
            f.append("E-token-in: the opening's root is not classify.input_root")
        if (r["commitment"]["rows"], r["data_rows"], r["params"]["log_cols"], r["params"]["inv_rate"]) != (ep["commitment_rows"], ep["data_rows"], ep["row_width_log"], ep["inv_rate"]):
            f.append("E-token-in: rows / data / width / rate are not the re-derived")
        if r["site_rows"] != [ep["data_rows"], ep["data_rows"] + 1] or r["prox_row"] != ep["data_rows"] + 2:
            f.append("E-token-in: site rows / proximity row are not one site after the data row")
        if len(r["claims"]) != 1:
            f.append(f"E-token-in: {len(r['claims'])} claims, the public-row variant has one")
    if any(x["role"].startswith("E-token-out") for st in b.stages for x in st.roles):
        f.append("an output endpoint opening exists (D40: none)")
    # the boundaries: committed at stage k, opened at k + 1
    bf = g.boundary()
    for k in range(L + 1):
        tbd = b.run["token_boundaries"][k]
        fa = tbd["facts"]
        if (fa["rows"], fa["data_rows"], fa["sites"], fa["log_n"]) != (bf["rows"], bf["data_rows"], bf["sites"], bf["row_width_log"]):
            f.append(f"boundary {k}: geometry is not the derived")
        if tbd["committed_at_stage"] != k or tbd["opened_at_stage"] != k + 1:
            f.append(f"boundary {k}: committed / opened at the wrong stages")
        bc = b.stages[k].doc["boundary_committed"]
        opener = next((x for x in b.stages[k + 1].roles if x.get("boundary") == k), None)
        if bc is None or bc.get("boundary") != k:
            f.append(f"stage {k} does not commit boundary {k}")
        elif opener is None:
            f.append(f"boundary {k} has no opening in stage {k + 1}")
        else:
            if opener["commitment"]["root"] != bc["root"]:
                f.append(f"boundary {k}: the root opened is not the root committed")
            src = [(c["stage"], c["slot"]) for c in opener["claim_sources"]]
            want_src = [(k, CL.SIC_QZC if k == 0 else 22), (k + 1, 21 if k + 1 <= L else CL.SOC_IO)]
            if src != want_src:
                f.append(f"boundary {k}: claim sources {src}, expected {want_src}")
    if stz.doc["boundary_committed"] is not None:
        f.append("stage OUT-C commits a boundary")
    # [v21, R-C3] B_out's claim from OUTC-00 sits at the fixed public bits of
    # the verdict row P0 + n + S - 1 (stage_out_c.rs:302 at r14)
    vr = verdict_row_of_bout_claim(b)
    if vr.get("row") != g.verdict_row():
        f.append(f"B_out's OUTC-00 claim is at row {vr.get('row')!r}, the verdict row is {g.verdict_row()} ({vr.get('why')})")
    return {"findings": f, "ok": not f, "stages": len(b.stages), "blocks": L,
            "r13_profile": r13, "r13_stage_gates": [g_["gate"] for g_ in gates],
            "rc3_lengths_re_derived": rc3, "pad_id": pf.get("pad_id"), "bout_claim_row": vr,
            "source_pins": {k: pins[k] for k in ("pins", "refusals", "ok")},
            "source_pin_status": sorted({x["status"].split(":")[0] for x in pins["per_file"]}),
            "D41_chunk": d41,
            "re_derived": {"stage_in_c": CL.StageLayout.summary(g.stage_in_c()),
                           "stage_out_c": CL.StageLayout.summary(g.stage_out_c()),
                           "input_endpoint": ep, "output_endpoint": None, "boundary": bf}}


def verdict_row_of_bout_claim(b) -> dict:
    """[v21] the row of B_out's claim from OUTC-00, decoded from the claim
    point's leading (row) coordinates, which must be public bits (MSB
    first, as `fixed_bits`): `stage_out_c.rs:302` puts
    fixed_bits(verdict_row, t_bits) there"""
    from zk60_native_jv_field import f2_from_list
    L = b.l
    op = next((r for r in b.stages[L + 1].roles if r.get("boundary") == L), None)
    if op is None:
        return {"row": None, "why": "no B_out opening in stage OUT-C"}
    src = [(c["stage"], c["slot"]) for c in op["claim_sources"]]
    if (L + 1, CL.SOC_IO) not in src:
        return {"row": None, "why": f"B_out's claim sources {src} have no OUTC-00 claim"}
    ci = src.index((L + 1, CL.SOC_IO))
    c = op["claims"][ci]
    p0 = c["parts"][0]
    pt = [f2_from_list(x) for x in p0["point"]]
    t_bits = CL.clog2(b.geom.t_pad)
    # the B_out plane is (t_pad x d_pad) row-major: its leading t_bits
    # variables are the token row (MSB first), then the d_pad column bits
    bits = pt[:t_bits]
    if any(x not in ((0, 0), (1, 0)) for x in bits):
        return {"row": None, "why": "the claim's leading coordinates are not public bits"}
    row = 0
    for x in bits:
        row = 2 * row + x[0]
    return {"row": row, "claim_index": ci, "t_bits": t_bits, "why": "decoded"}


# ------------------------------------------------------------------ per commitment (G-1)
def role_view_c(b, st, role, replay, perturb=None):
    from zk60_native_rg_pcs import RunRoleView
    key = st.key(role["role"])
    nm = role["role"]
    a_g = GROUPS_7.get(nm) if nm.startswith("A-") else None
    h_g = GROUPS_7.get(nm) if nm.startswith("H-") else None
    pshape = TG.ParamShape(role["params"], b.shape, a_groups=a_g, h_groups=h_g)
    r = role
    if nm in CANON_7:
        r = copy.copy(role)
        r["role"], kind = CANON_7[nm]
        r["commitment_kind"] = kind
        r["original_role"] = nm
    elif role.get("commitment_kind") in ("B-in", "B-out"):
        r = copy.copy(role)
        r["commitment_kind"] = "internal-boundary"
        r["original_role"] = nm
    v = RunRoleView(st, r, replay.stages[st.index]["role_prox_rhos"][key], pshape, name=key, perturb=perturb)
    return key, v


def class_stage3(b, replay, pad_rank=True):
    from zk60_native_rg_joint import RunJointSystem, mask_block
    views, rows = {}, []
    for st in b.stages:
        for role in st.roles:
            key, v = role_view_c(b, st, role, replay)
            f = dict(v.run(replay.stages[st.index]["role_lambdas"][key]))
            views[key] = v
            f.pop("xi_vectors", None)
            f.pop("data_rows_index", None)
            f["site_role"] = role["role"]
            f["stage_kind"] = st.kind
            f["class"] = TG.role_class(role)
            f["expected_disclosed_dimension"] = EXPECTED[f["class"]]
            f["meets_expectation"] = f["disclosed_dimension"] == f["expected_disclosed_dimension"]
            rows.append(f)
    masks = []
    for st in b.stages:
        blk = mask_block(st)
        dd = RunJointSystem([blk]).disclosed(msg_width=b.shape.cols)
        masks.append({"commitment": blk.name, "stage_kind": st.kind, "rows": blk.rows,
                      "slots": len(st.mask["specs"]), "disclosed_dimension": dd["disclosed_fp"],
                      "expected_disclosed_dimension": 0, "meets_expectation": dd["disclosed_fp"] == 0})
    pad = None
    if pad_rank:
        t0 = time.time()
        r, dcols = views["B0"].pad_block_rank()
        pad = {"commitment": "B0 (B_in)", "distinct_columns": dcols, "exact_rank_of_the_pad_block": r,
               "full_rank": r == dcols, "seconds": round(time.time() - t0, 1)}
    ok = all(r["findings"] == [] and all(r["reduction_hypotheses"].values())
             and r["column_identity_failures"] == 0 and r["group_claim_identity_failures"] == 0
             and r["meets_expectation"] and r["certifying_minor"]["full_row_rank"]
             and r["certifying_minor"]["determinant_nonzero"] and r["distinct_opened_columns_within_pad_count"]
             for r in rows) and all(m["meets_expectation"] for m in masks) and (pad is None or pad["full_rank"])
    return {"per_commitment": rows, "masking_commitments": masks, "pad_block_exact_rank_cross_check": pad,
            "ok": ok}, views


# ------------------------------------------------------------------ G-3 (CFS)
def class_mask_cfs(b, replay) -> dict:
    from zk60_native_rg_mask import mask_cfs_stage
    g = b.geom
    per = []
    for st in b.stages:
        r = mask_cfs_stage(TG._ShimBundle(b, st), replay, st.index)
        lay = g.stage_in_c() if st.kind == "IN-C" else (g.stage_out_c() if st.kind == "OUT-C" else None)
        ent = r.get("entries_recomputed") or {}
        row = {"stage": st.index, "stage_kind": st.kind, "ok": r.get("ok"),
               "specs_ok": r["specs_against_the_shape"]["ok"], "domain_ok": r["mask_domain"]["ok"],
               "disclosed": r["disclosed"], "cfs_findings": r["cfs"].get("findings"),
               "entries_recomputed": ent.get("total"), "entries_differing": ent.get("differing"),
               "functional_values": ent.get("functional_values"),
               "salted_leaves_authenticated": ent.get("salted_leaves_authenticated")}
        if lay is not None:
            row["functionals_re_derived"] = lay.n_functionals()
            row["functionals_match"] = ent.get("functional_values") == lay.n_functionals()
        per.append(row)
    ok = bool(per) and all(p["ok"] and p.get("functionals_match", True) and p["entries_differing"] == 0 for p in per)
    return {"per_stage": per, "ok": ok}


def g5_tab_width_c(b) -> dict:
    spi = b.stages[-1].doc["stage_plane_index"]
    tab = [p for p in spi["a_planes"] + spi["h_planes"] if p["name"] in ("A_MU8", "H_GU8")]
    ln = spi["log_n"]
    return {"stage_out_c_row_width_log": ln, "tab_planes": [{"name": p["name"], "log_size": p["log_size"]} for p in tab],
            "ok": len(tab) == 2 and all(p["log_size"] == ln for p in tab) and b.geom.tab_log() == ln}


def g6_endpoint_c(rows, views) -> dict:
    r = next(x for x in rows if x["role"] == "E-token-in")
    rk, dcols = views["E-token-in"].pad_block_rank()
    out = {"disclosed_dimension": r["disclosed_dimension"], "k0": r["k0"],
           "exclusivity_ok": (r.get("exclusivity") or {}).get("ok"), "certifying_minor": r["certifying_minor"],
           "distinct_opened_columns": dcols, "pad_block_rank": rk, "pad_block_full_rank": rk == dcols}
    out["ok"] = r["disclosed_dimension"] == 0 and r["meets_expectation"] and rk == dcols
    return {"endpoints": {"E-token-in": out}, "no_output_endpoint": True, "ok": out["ok"]}


# ------------------------------------------------------------------ the joint figure (no output endpoint)
def class_joint_figure(b, views) -> dict:
    """`token_joint_figure` for a classifier run: the identifications tok
    (input; INC-00), B_in (slot 21 of block 0), B_out (slot 22 of block L-1)
    and B_out at the verdict row P0 + n + S - 1 (T - 1 without pad; v21)
    against A-out's x (OUTC-00); there is no output token."""
    from zk60_native_rg_joint import RunJointSystem, block_from_view
    L, g = b.l, b.geom
    st_in, st_out = b.stages[0], b.stages[-1]
    spi_in, spi_out = st_in.doc["stage_plane_index"], st_out.doc["stage_plane_index"]

    def plane_row(spi, name):
        return next(x for x in spi["a_planes"] if x["name"] == name)["first_row"]
    findings = []
    keys = {"A_in": "A-in@0", "E_in": "E-token-in", "B_in": "B0", "A_first": "A@1", "A_last": f"A@{L}",
            "B_out": f"B{L}", "A_out": f"A-out@{L + 1}"}
    width = {k: 1 << views[v].role["params"]["log_cols"] for k, v in keys.items()}
    edges = []
    tok_in = plane_row(spi_in, "A_TOK")
    for w in range(g.tokens):
        edges.append(((keys["A_in"], tok_in, w), (keys["E_in"], 0, w)))
    for nm, st, slot, bkey in (("B_in", b.stages[1], 21, keys["B_in"]), ("B_out", b.stages[L], 22, keys["B_out"])):
        op = next(r for s in b.stages for r in s.roles if s.key(r["role"]) == bkey)
        src = [(c["stage"], c["slot"]) for c in op["claim_sources"]]
        ci = src.index((st.index, slot))
        res = TG._slot_io_rows(st, slot, "A", (op, ci))
        if isinstance(res, str):
            findings.append(res)
            continue
        a_rows, b_rows = res
        akey = st.key("A")
        for ar, br in zip(a_rows, b_rows):
            for w in range(1 << op["params"]["log_cols"]):
                edges.append(((akey, ar, w), (bkey, br, w)))
    n_b = width["B_out"]
    # [v21, R-C3] A-out's x is B_out at the public verdict row P0 + n + S - 1
    base = g.verdict_row() * g.d_pad
    b_row, b_col = base // n_b, base % n_b
    x_row = plane_row(spi_out, "A_X")
    for w in range(g.d_pad):
        edges.append(((keys["A_out"], x_row, w), (keys["B_out"], b_row + (b_col + w) // n_b, (b_col + w) % n_b)))
    parent = {}

    def find(x):
        while parent.setdefault(x, x) != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    for (k1, _r1, w1), (k2, _r2, w2) in edges:
        a, c = find((k1, w1)), find((k2, w2))
        if a != c:
            parent[a] = c
    comp_edges, comp_nodes = {}, {}
    for e in edges:
        comp_edges.setdefault(find((e[0][0], e[0][2])), []).append(e)
    for node in list(parent):
        comp_nodes.setdefault(find(node), set()).add(node)
    blocks_alone = {}

    def alone(key):
        if key not in blocks_alone:
            blocks_alone[key] = RunJointSystem([block_from_view(views[key])]).disclosed(msg_width=1)
        return blocks_alone[key]
    sig_result, sig_count = {}, {}
    for root, nodes in comp_nodes.items():
        word_of = {}
        for (k, w) in nodes:
            word_of.setdefault(k, set()).add(w)
        if any(len(ws) > 1 for ws in word_of.values()):
            findings.append(f"a component holds one commitment at two word positions: {sorted(nodes)[:4]}")
            continue
        pairs = sorted({((e[0][0], e[0][1]), (e[1][0], e[1][1])) for e in comp_edges.get(root, [])})
        sig = (tuple(sorted(word_of)), tuple(pairs))
        sig_count[sig] = sig_count.get(sig, 0) + 1
        if sig not in sig_result:
            js = RunJointSystem([block_from_view(views[k]) for k in sig[0]], identifications=list(pairs))
            d = js.disclosed(msg_width=1)
            sig_result[sig] = {"commitments": list(sig[0]), "row_identifications": len(pairs),
                               "joint_disclosed_fp_per_word": d["disclosed_fp"], "k0": d["k0"],
                               "sum_of_parts_per_word": sum(alone(k)["disclosed_fp"] for k in sig[0]),
                               "identification_reaches_a_non_data_row": bool(js.mixed_classes),
                               "findings": list(js.findings)}
    comps, joint_total = [], 0
    for sig, res in sig_result.items():
        r = dict(res)
        r["word_positions"] = sig_count[sig]
        joint_total += res["joint_disclosed_fp_per_word"] * sig_count[sig]
        comps.append(r)
    covered = {}
    for nodes in comp_nodes.values():
        for (k, w) in nodes:
            covered.setdefault(k, set()).add(w)
    parts_total, alone_rows = 0, {}
    for k in set(keys.values()):
        n_k = 1 << views[k].role["params"]["log_cols"]
        a = alone(k)
        alone_rows[k] = {"disclosed_fp_per_word": a["disclosed_fp"], "k0": a["k0"], "words": n_k,
                         "words_in_an_identification": len(covered.get(k, ()))}
        parts_total += a["disclosed_fp"] * n_k
        joint_total += a["disclosed_fp"] * (n_k - len(covered.get(k, ())))
    out = {"what": "the joint figure over the classifier run's shared planes, computed at word level "
                   "(token_joint_figure's model; no output token)",
           "identified_word_pairs": len(edges), "components": comps, "commitments_alone": alone_rows,
           "joint_disclosed_fp": joint_total, "sum_of_parts_fp": parts_total,
           "joint_equals_sum_of_parts": joint_total == parts_total, "findings": findings,
           "ruling_R3": "joint == sum of parts is a consistency check, not evidence that the blinding is independent (G-R4)"}
    out["ok"] = (not findings and out["joint_equals_sum_of_parts"] and joint_total == 0
                 and not any(c["identification_reaches_a_non_data_row"] for c in comps))
    return out


# ------------------------------------------------------------------ the block stages
def class_block_terminals(b, rp, calibration=None, calibration_source=None, controls=True,
                          stage_calibrations=None) -> dict:
    """The frozen block-stage terminal identity on each block stage of a
    classifier capture, through the token gate's one-stage shim, at the
    block calibration (an export's -- per stage when its layers carry their
    own constants: `stage_calibrations` -- or the rung fixture's)."""
    import zk60_native_rg_terminals as T
    import zk60_native_rg_tokenblocks as TB
    from zk60_native_rg_planes import PlaneIndex
    from zk60_native_rg_tlcontrols import READS, _step
    t0 = time.time()
    L = b.l
    rec = {"what": "the frozen block-stage terminal identity on each block stage of ONE classifier capture",
           "blocks": L, "privacy_acceptance": False}
    if calibration is None:
        if b.run["shape"]["profile"] == RUNG_BLOCK_PROFILE:
            calibration = dict(RUNG_FIXTURE_CALIBRATION)
            calibration_source = ("the rung fixture: frozen-r12 trained_calib_tests.rs:55-58 rung_tc_calibration "
                                  "(the classifier capture test's rung())")
        else:
            rec.update({"refused": "no block calibration: give --calibration-export (the shape names none)",
                        "ok": False})
            return rec
    sh = b.run["shape"]
    d_max = TB.derive(calibration, sh["width"], sh["tokens"], sh["f_e"])
    if d_max["norm_wrho"] != sh["norm_wrho"]:
        rec.update({"refused": f"the calibration derives norm_wrho {d_max['norm_wrho']}, the shape says {sh['norm_wrho']}",
                    "ok": False})
        return rec
    stage_cals = stage_calibrations or [calibration] * L
    stage_extra = [{"norm_wrho": TB.derive(v, sh["width"], sh["tokens"], sh["f_e"])["norm_wrho"]} for v in stage_cals]
    rec["calibration"] = {"values": calibration, "source": calibration_source,
                          "derived_norm_wrho_equals_the_shape": True,
                          "per_stage": [{"stage": k + 1, "differs_from_the_run_on": sorted(kk for kk in v if v[kk] != calibration[kk])}
                                        for k, v in enumerate(stage_cals)]}
    extra = {"norm_wrho": sh["norm_wrho"]}
    per_stage, ctl = [], {}
    with TB.token_shape_reading(b.manifest) as pin_rec:
        rec["source_pin_adaptation"] = pin_rec
        full = TB.TokenBlockShim(b, calibration, extra=extra)
        index = PlaneIndex(full)
        pi = index.summary()
        rec["plane_index"] = {k: pi[k] for k in ("ok", "findings", "a_planes", "h_planes", "a_data_rows", "h_data_rows", "slots")}
        shims = [TB.TokenBlockShim(b, stage_cals[k], blocks=[k], extra=stage_extra[k]) for k in range(L)]
        views = [TB._ReplayView(rp, [k]) for k in range(L)]
        for k in range(L):
            r = T.check_terminals(shims[k], index, replay=views[k])
            row = r["per_stage"][0] if r["per_stage"] else {"checked": [], "equal": [], "not_checked": []}
            per_stage.append({"stage": k + 1, "block": k, "ok": r["ok"], "slot_checks_equal": len(row["equal"]),
                              "slot_checks_expected": r["slot_checks_expected"],
                              "checked_not_equal": sorted(set(row["checked"]) - set(row["equal"])),
                              "refused_or_open": [{"slot": e["slot"], "why": e["why"]} for e in row["not_checked"]],
                              "source_pins_ok": r["source_pins"]["ok"], "port_findings": r["findings"][:4],
                              "bilinear_group_factor_ok": r["bilinear_group_factor"]["ok"]})
        if controls:
            name = "sh_s"
            got, want = set(), set()
            for k in range(L):
                moved = dict(shims[k].run["shape"])
                moved[name] = _step(name, int(moved[name]))
                r1 = T.check_terminals(shims[k].with_shape(moved), index, replay=views[k])
                got |= {(k + 1, s) for s in TB._failing(r1)}
                want |= {(k + 1, s) for s in READS[name]}
            ctl["NC-1_constant_moved"] = {"perturbation": f"{name} moved by one in every block stage's shim",
                                          "predicted": sorted(list(x) for x in want), "failing": sorted(list(x) for x in got),
                                          "fires": bool(got) and got == want}
    rec["per_stage"] = per_stage
    rec["io_wiring"] = TB._io_wiring(b)
    rec["controls"] = ctl
    rec["seconds"] = round(time.time() - t0, 1)
    rec["ok"] = (all(p["ok"] for p in per_stage) and rec["plane_index"]["ok"] and rec["io_wiring"]["ok"]
                 and all(c["fires"] for c in ctl.values()))
    return rec


# ------------------------------------------------------------------ D41 over a set of chunk captures
def d41_item_check(bundles: list) -> dict:
    """D41's label rule over the chunk captures of ONE item and category
    (fail-closed, design §13.4): the ranges re-derived from (total, size,
    overlap), every index present once, the same policy and model."""
    if not bundles:
        return {"label": 1, "fail_closed_reasons": ["no chunk"], "ok": False}
    ch0 = bundles[0].run["classify"]["chunk"]
    chunks = []
    for b in bundles:
        cf = b.run["classify"]
        ch = cf["chunk"]
        chunks.append(dict(ch, verdict=cf["verdict"], policy=cf["policy"]["id"],
                           model=bytes(b.run["calibration"]).hex()))
    r = CL.check_item_chunks(chunks, total=ch0["total"], size=ch0["size"], overlap=ch0["overlap"])
    r["chunks_given"] = [(c["index"], c["a"], c["b"], c["verdict"]) for c in chunks]
    return r


# ------------------------------------------------------------------ controls on the capture
def class_controls(b, rp, terminals) -> dict:
    """Negative controls on a REAL classifier capture, each predicted to fire
    (in memory only; no captured byte is touched)."""
    from zk60_native_jv_field import f2_from_list
    out = {}
    L = b.l

    def replay_of(mutate):
        b2 = copy.copy(b)
        b2.run = copy.deepcopy(b.run)
        mutate(b2.run)
        return ClassRunReplay(b2).run().summary()
    # CC-1 the verdict flipped in the facts: the binding and LZC both refuse
    flipped = 1 - b.run["classify"]["verdict"]
    s1 = replay_of(lambda r: r["classify"].__setitem__("verdict", flipped))
    t1 = CT.check_classify_terminals(b, rp, facts_override={"verdict": flipped})
    bad1 = sorted({(r["stage"], r["slot"]) for r in t1["slots"] if not r["equal"]})
    out["CC-1_verdict_flipped"] = {"replay_binding_refused": not s1["run_binding_reproduced"],
                                   "terminal_slots_failing": bad1,
                                   "fires": (not s1["run_binding_reproduced"]) and bad1 == [("OUT-C", CL.SOC_LZC)]}
    # CC-2 the threshold c + 1 in the port's facts: LZC refuses
    t2 = CT.check_classify_terminals(b, rp, facts_override={"c": b.run["classify"]["policy"]["c"] + 1})
    bad2 = sorted({(r["stage"], r["slot"]) for r in t2["slots"] if not r["equal"]})
    out["CC-2_threshold_moved"] = {"terminal_slots_failing": bad2, "fires": bad2 == [("OUT-C", CL.SOC_LZC)]}
    # CC-3 one PD terminal + 1: PD alone refuses
    t3 = CT.check_classify_terminals(b, rp, terminal_delta={("OUT-C", CL.SOC_PD): (0, (1, 0))})
    bad3 = sorted({(r["stage"], r["slot"]) for r in t3["slots"] if not r["equal"]})
    out["CC-3_margin_terminal_moved"] = {"terminal_slots_failing": bad3, "fires": bad3 == [("OUT-C", CL.SOC_PD)]}
    # CC-4 the recorded margin vector moved by one entry: B-3 refuses
    pd_tabs = b.stages[-1].doc["arguments"][CL.SOC_PD]["tables"]
    wi = next(i for i, t in enumerate(pd_tabs) if t["kind"] == "public")
    t4 = CT.check_classify_terminals(b, rp, table_delta={("OUT-C", CL.SOC_PD): (wi, 0, (1, 0))}, check_digests=False)
    out["CC-4_margin_vector_entry_moved"] = {"B3_ok": t4["B3_margin_vector"]["ok"],
                                             "B3_findings": t4["B3_margin_vector"]["findings"][:2],
                                             "fires": not t4["B3_margin_vector"]["ok"]}
    # CC-5 a template id in the recorded kappa table: the rebuilt-vs-captured check refuses
    q_tabs = b.stages[0].doc["arguments"][CL.SIC_QZC]["tables"]
    pubs = [i for i, t in enumerate(q_tabs) if t["kind"] == "public"]
    ki = pubs[3]                      # supp, u0, pi, KAPPA, ctl_q (stage_in_c.rs:194-199)
    t5 = CT.check_classify_terminals(b, rp, table_delta={("IN-C", CL.SIC_QZC): (ki, 1, (1, 0))}, check_digests=False)
    bad5 = sorted({(r["stage"], r["slot"]) for r in t5["slots"] if not r["equal"]})
    out["CC-5_template_id_in_the_captured_kappa"] = {"terminal_slots_failing": bad5,
                                                    "fires": bad5 == [("IN-C", CL.SIC_QZC)]}
    # CC-6 the chunk's range moved in the facts: D41 and the binding refuse
    def mv_chunk(r):
        r["classify"]["chunk"]["a"] += 1
        r["classify"]["chunk"]["b"] += 1
    s6 = replay_of(mv_chunk)
    b6 = copy.copy(b)
    b6.run = copy.deepcopy(b.run)
    mv_chunk(b6.run)
    i6 = class_integrity(b6)
    out["CC-6_chunk_range_moved"] = {"replay_binding_refused": not s6["run_binding_reproduced"],
                                     "D41_refused": not i6["D41_chunk"]["ok"],
                                     "fires": (not s6["run_binding_reproduced"]) and not i6["D41_chunk"]["ok"]}
    # CC-7 the template clause dropped from the port (an extra term cancels it): INC-01 refuses
    # (the clause is load-bearing on the recorded terminals)
    _ = f2_from_list
    out.update(c13_controls(b, rp))
    out["not_fired"] = [k for k, v in out.items() if isinstance(v, dict) and v.get("fires") is False]
    out["ok"] = not out["not_fired"]
    return out


def _failing(t):
    return sorted({(r["stage"], r["slot"]) for r in t["slots"] if not r["equal"]})


def c13_controls(b, rp) -> dict:
    """[v21] GATE ITEM C-13 (short items, DESIGN v2.4 §15): negative controls
    on the REAL capture, in memory, each predicted:

    C13-1 a doctored PAD position (applicable when the item has pad
          positions): (a) the port's pad id + 1, (b) the captured kappa
          table's first pad entry + 1 -> exactly INC-01 refuses, both ways
          (the template clause pins the pad positions);
    C13-2 a pad INSIDE the content range: (a) the port pins the last content
          position P0 + n - 1 to the pad id (pi = 1, kappa = pad there) ->
          exactly INC-01 refuses; (b) the profile text claims one pad
          position more -> the integrity check refuses (item-length +
          pad-positions != T);
    C13-3 a SHIFTED verdict row: the port's OUTC-00 at verdict_row - 1 (and
          + 1 where it exists) -> exactly OUTC-00 refuses; and the integrity
          check refuses a recorded B_out claim decoded at another row;
    C13-4 a declared length that is not the actual one: (a) classify.n + 1
          in the facts (chunk and absorbed text unchanged) -> the integrity
          check refuses (n != b - a, the profile text's n / item-length) and
          INC-01 refuses (pi, kappa move); (b) the chunk declares one id more
          (b + 1, total + 1) -> the run binding and D41 refuse."""
    import zk60_native_rg_classtied as TD
    out = {}
    g = b.geom
    cf = b.run["classify"]
    inc01, outc00 = [("IN-C", CL.SIC_QZC)], [("OUT-C", CL.SOC_IO)]

    def replay_of(mutate):
        b2 = copy.copy(b)
        b2.run = copy.deepcopy(b.run)
        mutate(b2.run)
        return ClassRunReplay(b2).run().summary()

    def integrity_of(mutate):
        b2 = copy.copy(b)
        b2.run = copy.deepcopy(b.run)
        mutate(b2.run)
        b2.profile_fields = TD.profile_fields(b2.run["classify"].get("profile_text", ""))
        cf2 = b2.run["classify"]
        b2.geom = CL.ClassGeom(name=b2.run["profile"], tokens=cf2["T"], t_pad=cf2["t_pad"], d=cf2["d"],
                               d_pad=cf2["d_pad"], v=cf2["V"], p0=cf2["P0"], n=cf2["n"], s=cf2["S"],
                               c=cf2["policy"]["c"], num_special=cf2["policy"]["num_special"],
                               block_log_n=b.shape.endpoint_log_n, block_inv_rate=b.shape.endpoint_inv_rate,
                               pad=b2.profile_fields["pad_id"] if b2.profile_fields["pad_id"] is not None else -1)
        return class_integrity(b2), b2
    # C13-1
    if g.pad_positions() > 0:
        pad = b.profile_fields["pad_id"]
        ta = CT.check_classify_terminals(b, rp, facts_override={"pad": pad + 1})
        q_tabs = b.stages[0].doc["arguments"][CL.SIC_QZC]["tables"]
        ki = [i for i, t in enumerate(q_tabs) if t["kind"] == "public"][3]   # supp, u0, pi, KAPPA, ctl_q
        tb = CT.check_classify_terminals(b, rp, table_delta={("IN-C", CL.SIC_QZC): (ki, g.item_len(), (1, 0))},
                                         check_digests=False)
        out["C13-1_doctored_pad_position"] = {
            "pad_positions": g.pad_positions(), "first_pad_position": g.item_len(),
            "a_port_pad_id_plus_1_failing": _failing(ta), "b_captured_kappa_at_first_pad_plus_1_failing": _failing(tb),
            "fires": _failing(ta) == inc01 and _failing(tb) == inc01}
    else:
        out["C13-1_doctored_pad_position"] = {"applicable": False, "why": "a full-length item has no pad position",
                                              "fires": None}
    # C13-2
    t_in = g.p0 + g.n - 1
    tc = CT.check_classify_terminals(b, rp, facts_override={"extra_pad_positions": [t_in]})

    def more_pad(r):
        pt = r["classify"]["profile_text"]
        r["classify"]["profile_text"] = pt.replace(f" pad-positions={g.pad_positions()} ", f" pad-positions={g.pad_positions() + 1} ", 1)
        r["parameter_line"] = r["parameter_line"].replace(pt, r["classify"]["profile_text"], 1)
    i2, _ = integrity_of(more_pad)
    why2 = [x for x in i2["findings"] if "pad_positions" in x or "pad-positions" in x]
    out["C13-2_pad_inside_the_content_range"] = {
        "content_position_pinned_to_pad": t_in, "a_port_failing": _failing(tc),
        "b_profile_text_one_pad_more_integrity_refused": bool(why2), "b_findings": why2[:3],
        "fires": _failing(tc) == inc01 and bool(why2)}
    # C13-3
    vr = g.verdict_row()
    shifts = [x for x in (vr - 1, vr + 1) if 0 <= x < g.tokens]
    fails = {x: _failing(CT.check_classify_terminals(b, rp, facts_override={"verdict_row": x})) for x in shifts}

    gs = copy.copy(g)
    gs.verdict_row = lambda: vr - 1
    bs = copy.copy(b)
    bs.geom = gs
    i3 = class_integrity(bs)
    why3 = [x for x in i3["findings"] if x.startswith("B_out's OUTC-00 claim is at row")]
    out["C13-3_shifted_verdict_row"] = {
        "verdict_row": vr, "port_rows_tried": shifts, "failing_per_row": {str(k): v for k, v in fails.items()},
        "integrity_with_the_expected_row_moved_refused": bool(why3), "integrity_findings": why3[:2],
        "fires": all(v == outc00 for v in fails.values()) and bool(fails) and bool(why3)}
    # C13-4
    t4 = CT.check_classify_terminals(b, rp, facts_override={"n": g.n + 1})

    def n_up(r):
        r["classify"]["n"] = r["classify"]["n"] + 1
    i4, _ = integrity_of(n_up)

    def ch_up(r):
        r["classify"]["chunk"]["b"] += 1
        r["classify"]["chunk"]["total"] += 1
    s4 = replay_of(ch_up)
    i4b, _ = integrity_of(ch_up)
    why4 = [x for x in i4["findings"] if "the profile text's n " in x or "D41" in x or "item_length" in x]
    out["C13-4_declared_length_not_the_actual"] = {
        "a_facts_n_plus_1_integrity_refused": bool(why4), "a_findings": why4[:3],
        "a_port_failing": _failing(t4),
        "b_chunk_one_id_more_binding_refused": not s4["run_binding_reproduced"],
        "b_D41_refused": not i4b["D41_chunk"]["ok"],
        "fires": bool(why4) and _failing(t4) == inc01 and (not s4["run_binding_reproduced"])
        and not i4b["D41_chunk"]["ok"]}
    return out


# ------------------------------------------------------------------ the gate
def gate(directory: str, controls=True, full_preimage=True, calibration_export=None, preimage_names=None) -> dict:
    t0 = time.time()
    rec = {"what": "the privacy gate on ONE classifier run capture (D38 / D40 / D41 / D45; gate round 19, tools v22: "
                   "token frozen-r16b on native R13, the R13 h24 rung and the real Shieldstral-1.0-3B); NOT a privacy result",
           "privacy_acceptance": False, "privacy_property_established": False, "timings": {}}

    def tick(name, t):
        rec["timings"][name] = round(time.time() - t, 1)
    t = time.time()
    b = load(directory)
    rec["bundle"], rec["bundle_dir"], rec["profile"] = b.name, b.dir, b.profile
    rec["blocks"], rec["stages"] = b.l, len(b.stages)
    cf = b.run["classify"]
    rec["public_outputs"] = {"verdict": cf["verdict"], "chunk": cf["chunk"], "policy": cf["policy"]["id"],
                             "c": cf["policy"]["c"],
                             # [v21] D45(1): the content length is public, and with it the pad layout
                             "n": cf["n"], "item_length": b.geom.item_len(), "pad_positions": b.geom.pad_positions(),
                             "verdict_row": b.geom.verdict_row(), "pad_id": b.profile_fields["pad_id"],
                             "short_item": b.geom.is_short()}
    rec["integrity"] = class_integrity(b)
    rec["capture_format_notes"] = [x for x in (b.shape_slot_note,) if x]
    tick("load_and_integrity", t)
    t = time.time()
    rp = ClassRunReplay(b).run()
    rec["replay"] = rp.summary()
    tick("replay", t)
    t = time.time()
    from zk60_native_rg_hashlayer import check_hash_layer
    h = check_hash_layer(b)
    rec["hash_layer"] = {k: h[k] for k in ("ok", "columns_checked", "columns_authenticated", "bytes_hashed", "findings") if k in h}
    tick("hash_layer", t)
    t = time.time()
    s3, views = class_stage3(b, rp, pad_rank=True)
    rec["G1_per_commitment"] = s3
    tick("per_commitment", t)
    t = time.time()
    from zk60_native_rg_joint import boundary_reserved_figure
    rec["G1_G2_boundaries_reserved"] = {nm: boundary_reserved_figure(b, views[f"B{k}"], k)
                                        for nm, k in (("B_in", 0), ("B_out", b.l))}
    rec["G2_claim_points"] = TG.g2_claim_points(b)
    tick("boundaries_and_G2", t)
    t = time.time()
    rec["G3_mask_cfs"] = class_mask_cfs(b, rp)
    tick("G3", t)
    rec["G5_tab_width"] = g5_tab_width_c(b)
    rec["G6_endpoint"] = g6_endpoint_c(s3["per_commitment"], views)
    t = time.time()
    rec["G1_joint"] = class_joint_figure(b, views)
    tick("G1_joint", t)
    t = time.time()
    rec["terminals_classifier_slots"] = CT.check_classify_terminals(b, rp)
    rec["NL1_classifier_slots"] = CT.nl1_classify_slots(b, rp)
    tick("terminals_and_NL1", t)
    t = time.time()
    cal, cal_src, stage_cals = None, None, None
    if calibration_export and b.profile not in CL.R13_CLASSIFY_RUN_PROFILES:
        import zk60_native_rg_tokenblocks as TB
        exp = TB.load_export(calibration_export)
        ident = TB.identify_layers(b, exp, None)
        layers = [r["layer"] for r in ident["per_stage"]]
        if None not in layers:
            cals = TB.calibrations(exp, layers)
            cal, stage_cals = cals["run_values"], cals["stage_values"]
            cal_src = f"export {calibration_export}, layers {layers} (identified by their gains, X10)"
    if b.profile in CL.R13_CLASSIFY_RUN_PROFILES:
        # [v22] the block stages at an R13 shape: the block-port sub-lane's module
        try:
            import zk60_native_rg_r13blocks as RB
        except ImportError as exc:
            rec["terminals_block_stages"] = {"refused": f"no R13 block-stage port in these tools ({exc})", "ok": False}
        else:
            rec["terminals_block_stages"] = RB.r13_block_terminals(b, rp, calibration_export=calibration_export,
                                                                   controls=controls)
    else:
        rec["terminals_block_stages"] = class_block_terminals(b, rp, calibration=cal, calibration_source=cal_src,
                                                              controls=controls, stage_calibrations=stage_cals)
    tick("terminals_block_stages", t)
    # [v22] DECLARED LIMITS (never silent): a capture recorded with public tables as length + digest
    # (the real Shieldstral capture) leaves the block slots that need a captured table OPEN, by the
    # capture option (`zk60_native_rg_r13blocks`: `tables_absent_by_capture_option`); the block part
    # then counts as passed only on the slots it covers without tables, and the run's status says so
    tbs = rec["terminals_block_stages"]
    blocks_tables_open = bool(tbs.get("tables_absent_by_capture_option"))
    blocks_ok = tbs.get("ok") is True or (blocks_tables_open and tbs.get("ok_on_the_covered_slots") is True)
    rec["declared_limits"] = []
    if blocks_tables_open:
        rec["declared_limits"].append(
            f"block-stage terminals: slots {tbs.get('slots_open_without_tables')} open in every block stage (the "
            "capture carries public tables as length + digest only); covered without tables: "
            f"{tbs.get('slots_covered_without_tables')}, ok on them: {tbs.get('ok_on_the_covered_slots')}")
    if full_preimage:
        t = time.time()
        from zk60_native_rg_ahpreimage import full_preimages
        names = list(views) if preimage_names is None else [n for n in preimage_names if n in views]
        s11 = full_preimages(b, views, names=names)
        rec["full_preimage"] = {k: s11[k] for k in ("ok", "view_entries_compared", "view_entries_differing",
                                                    "salted_leaves_authenticated", "commitments") if k in s11}
        if preimage_names is not None:
            rec["full_preimage"]["sampled_commitments"] = names
            rec["full_preimage"]["not_evaluated"] = [n for n in views if n not in names]
            rec["declared_limits"].append(f"full preimage on a declared SAMPLE of {len(names)} of {len(views)} "
                                          f"commitments: {names}")
        tick("full_preimage", t)
        rec["joint_preimage"] = TG.token_joint_preimage(
            b, views, s11, rec["G3_mask_cfs"], rec["G1_joint"],
            {"classifier_slots": rec["terminals_classifier_slots"], "block_stages": rec["terminals_block_stages"],
             "ok": rec["terminals_classifier_slots"].get("ok") is True and blocks_ok})
    else:
        rec["full_preimage"] = {"skipped": "not requested", "ok": None}
        rec["joint_preimage"] = {"skipped": "needs the full preimage", "ok": None}
    tc = rec["terminals_classifier_slots"]
    rec["B3_margin_vector"] = tc.get("B3_margin_vector")
    rec["one_public_bit"] = dict(tc.get("one_public_bit") or {}, ok=bool((tc.get("one_public_bit") or {}).get(
        "rebuilt_public_tables_all_equal_the_capture")) and rec["G6_endpoint"]["no_output_endpoint"]
        and all(r["meets_expectation"] for r in s3["per_commitment"]))
    rec["D41"] = rec["integrity"]["D41_chunk"]
    if controls:
        t = time.time()
        rec["controls"] = class_controls(b, rp, tc)
        jc = TG.token_joint_controls(b, views)
        for k, v in jc["controls"].items():
            rec["controls"][k] = v
        if full_preimage:
            from zk60_native_rg_ahcontrols import ah_controls
            for nm, a_k, h_k in (("CC-8_preimage_controls_on_stage_IN_C", "A-in@0", "H-in@0"),
                                 ("CC-9_preimage_controls_on_stage_OUT_C", f"A-out@{b.l + 1}", f"H-out@{b.l + 1}")):
                ac = ah_controls(b, views, a_name=a_k, h_name=h_k)
                rec["controls"][nm] = {"fires": ac["ok"], "applicable": ac["controls_applicable"],
                                       "fired": ac["controls_that_fire"], "not_applicable": ac["not_applicable"]}
        live = {k: v for k, v in rec["controls"].items() if isinstance(v, dict) and v.get("fires") is not None}
        rec["controls"]["not_fired"] = [k for k, v in live.items() if not v["fires"]]
        rec["controls"]["ok"] = bool(live) and not rec["controls"]["not_fired"]
        tick("controls", t)
    else:
        rec["controls"] = {"skipped": "controls not requested", "ok": None}
    parts = ["integrity", "replay", "hash_layer", "G1_per_commitment", "G2_claim_points", "G3_mask_cfs", "G5_tab_width",
             "G6_endpoint", "G1_joint", "terminals_classifier_slots", "NL1_classifier_slots", "terminals_block_stages",
             "B3_margin_vector", "one_public_bit", "D41"]
    if full_preimage:
        parts += ["full_preimage", "joint_preimage"]
    bres = rec["G1_G2_boundaries_reserved"]
    rec["boundaries_ok"] = all(v["disclosed_on_the_reserved_block_fp"] == 0 and v["full_row_rank"]
                               and v["determinant_nonzero"] and v["row_rule"] == "data + 2*sites + 2" for v in bres.values())
    rec["false_parts"] = [p for p in parts if not (rec[p] or {}).get("ok")] + ([] if rec["boundaries_ok"] else ["boundaries"])
    if blocks_tables_open and blocks_ok and "terminals_block_stages" in rec["false_parts"]:
        rec["false_parts"].remove("terminals_block_stages")      # passed on its covered slots: a declared limit
    rec["ok"] = not rec["false_parts"] and (rec["controls"].get("ok") is True if controls else True)
    rec["status"] = "PASS" if rec["ok"] and controls else ("PASS-NO-CONTROLS" if rec["ok"] else "NOT-OK")
    if rec["status"] == "PASS" and rec["declared_limits"]:
        rec["status"] = "PASS-WITH-DECLARED-LIMITS"
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
    ap.add_argument("--no-full-preimage", action="store_true")
    ap.add_argument("--calibration-export", default=None)
    # [v22] the export whose profile.json / rotation signs / checkpoint
    # declaration B-3 derives the Shieldstral tables from
    ap.add_argument("--tied-export", default=None)
    # [v22] the full preimage on a declared sample of commitments (comma list of view names)
    ap.add_argument("--preimage-names", default=None)
    a = ap.parse_args(argv)
    if a.tied_export:
        import zk60_native_rg_classtied as TD
        TD.SHIELD_EXPORT = a.tied_export
    rec = gate(a.bundle, controls=not a.no_controls, full_preimage=not a.no_full_preimage,
               calibration_export=a.calibration_export,
               preimage_names=a.preimage_names.split(",") if a.preimage_names else None)
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, f"{a.name}.json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
    print(f"{a.name}: status {rec['status']}; false parts {rec['false_parts']}; controls not fired "
          f"{rec['controls'].get('not_fired')}; {rec['total_seconds']} s; record {path}")
    return 0 if rec["status"] in ("PASS", "PASS-WITH-DECLARED-LIMITS") else 1


if __name__ == "__main__":
    raise SystemExit(main())
