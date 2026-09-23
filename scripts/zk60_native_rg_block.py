"""**ROUND 9j: the run gate reads a STANDALONE shaped block receipt.**

Input: a bundle of schema `hashline-native-capture/5-block-shaped`, written
by `hashline/src/private_block/block_capture_shaped.rs` (lane
`zk60-private-block-125m`, stage 45; `#[cfg(test)]`, verifier-side).  A
bundle is a DIRECTORY -- `block.json` (the analogue of a run's `run.json`),
`observations.json` (a run STAGE file's members for the same objects, minus
the run's framing), `arrays.bin` (the `/5-run` array store), `receipt.bin`
(the canonical frame that was verified), `expected.bin` (the endpoint
policy), `README.md`, `manifest.json` (written LAST, 35 source pins) and
`validation.json` (written AFTER the manifest by a fresh process; not pinned
by it).

WHY A MODE OF THE RUN GATE AND NOT A NEW GATE.  The writer COPIED the run
capture's encoders so that "the Python gate's stage readers apply as they
are" (`block_capture_shaped.rs:43-52`), and its own test asserts every slot,
`M` and role object carries a one-block rung-G run capture's key sequence.
So every port of the run gate -- the per-commitment view, the joint system,
the terminal identity, the group factor, the hash layer, both preimage arms
and the mask port -- reads a standalone block through ONE adapter: this
module presents the bundle as a run of ONE stage with NO boundary
(`blocks = 1`, `boundaries = 0`, `stages = [the observations]`) and
`standalone = True`.  What a block does NOT share with a run stage lives
here, and only here:

  * the LOADER and its refusals (a run bundle is not a block and a block is
    not a stage -- each refused by name);
  * INTEGRITY: the manifest, the receipt and policy files, the block header
    against the observations, the external endpoints' geometry;
  * the REPLAY's header: `expected-IO`, `public-statement` (the block's own
    digest), `parameters` (the block profile's line), `calibration`,
    `schedule` under the BLOCK profile's domain; NO `run-shape`, NO
    `pb-run-stage` / `pb-run-block`, NO `B`, NO segment position tags;
  * the WRITER'S PIN (`block_capture_shaped.rs`), which is to a block what
    `run_capture.rs` is to a run, and the three run-layer files a standalone
    block never reaches, named with the reason rather than refused;
  * the run-control family's block analogues (stage 6) and the four
    run-only channels' block wording (stage 7).

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY, AND THIS IS NOT A PRIVACY
ACCEPTANCE.  `block.json` itself carries `privacy_review_complete: false`.
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
    ArrayRefused,
    ArrayStore,
    resolve_document,
)
from zk60_native_rg_bundle import RunBundle, Shape, Stage  # noqa: E402
from zk60_native_rg_hashrule import rule_for_bundle  # noqa: E402

# ---------------------------------------------------------------------------
# 0.  WHAT THE WRITER DECLARES (block_capture_shaped.rs at 37312d49...)
# ---------------------------------------------------------------------------
SCHEMA_BLOCK = "hashline-native-capture/5-block-shaped"        # :74
BLOCK_KIND = "zk60-block-verifier-observations"                # :1085
OBSERVATIONS_KIND = "zk60-block-observations"                  # :1022
BLOCK_MANIFEST_KIND = "zk60-block-capture-manifest"            # :1344
BLOCK_COVERAGE = "native-block-shaped-all-slots-v1"            # :1085
BLOCK_FILE = "block.json"                                      # :80
OBSERVATIONS_FILE = "observations.json"                        # :81
RECEIPT_FILE = "receipt.bin"                                   # :83
EXPECTED_FILE = "expected.bin"                                 # :84
# Written by a FRESH process after `manifest.json` (the lane's
# `reverify_a_shaped_block_bundle`), so the manifest cannot list it.  The
# loader names it rather than letting integrity call it an unlisted file.
VALIDATION_FILE = "validation.json"
ROLE_ORDER = ("A", "H", "Input", "Output")                     # :87
# `TRANSCRIPT_LABELS` (:1164-1180), 15 entries, verbatim.
EXPECTED_BLOCK_LABELS = (
    "expected-IO",
    "public-statement",
    "parameters",
    "calibration",
    "schedule",
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
# The four labels a run absorbs and a standalone block does not (:1161-1163).
RUN_ONLY_LABELS = ("run-shape", "pb-run-stage", "pb-run-block", "B")
# A run stage file's framing, which `write_observations` omits (:1015-1017).
RUN_FRAMING_KEYS = ("stage", "blocks", "segment_bytes", "segment_sha256",
                    "start_tag", "end_tag", "boundary_committed")
# `wire.rs:15`: a block receipt's frame opens with this magic and the header
# state (`block_binding`), 8 + 32 bytes, compared when the frame is decoded
# and outside the Fiat-Shamir chain (TRANSCRIPT_PROGRAM, the last entry).
FRAME_MAGIC = b"HLPBLOK1"
FRAME_ENVELOPE = 8 + 32
# `private_block.rs` `ExpectedIo::to_bytes`: the magic, the context, the two
# i32 scales little-endian, the two endpoint roots -- 112 bytes.
POLICY_MAGIC = b"HBLKEXP1"
POLICY_BYTES = 8 + 32 + 4 + 4 + 32 + 32


# ---------------------------------------------------------------------------
# 1.  THE LOADER
# ---------------------------------------------------------------------------
class BlockStage(Stage):
    """`observations.json`: a run stage file's members for ONE standalone
    block, with index 0 and none of the run's framing.

    The parent's accessors (`slots`, `mask`, `roles`, `role`, `key`) are
    used unchanged: a role's `commitment_kind` is `"block"` for `A` / `H`
    and `"external-endpoint"` for both IO roles, so `key` names them
    `A@0`, `H@0`, `E-Input`, `E-Output`, and `boundary_opening` is None.
    """

    def __init__(self, path: str, store=None, refusals=None):
        with open(path, "rb") as fh:
            raw = fh.read()
        self.path = path
        self.name = os.path.basename(path)
        self.sha256 = hashlib.sha256(raw).hexdigest()
        self.bytes = len(raw)
        self.doc = json.loads(raw)
        d = self.doc
        if d.get("schema") != SCHEMA_BLOCK:
            raise ValueError(f"{self.name}: schema {d.get('schema')!r} is not "
                             f"{SCHEMA_BLOCK!r}")
        self.arrays_resolved = 0
        if store is not None:
            self.arrays_resolved = resolve_document(
                d, store, self.name, refusals if refusals is not None else [])
        if d.get("kind") != OBSERVATIONS_KIND:
            raise ValueError(f"{self.name}: kind {d.get('kind')!r} is not "
                             f"{OBSERVATIONS_KIND!r}")
        framing = [k for k in RUN_FRAMING_KEYS if k in d]
        if framing:
            raise ValueError(
                f"{self.name}: carries a run's framing {framing} -- a run "
                "stage file is not a standalone block's observations")
        self.index = 0


class BlockBundle(RunBundle):
    """A standalone block bundle, presented as a run of ONE stage.

    `self.run` is `block.json`.  The name is kept because every port reads
    the header through `bundle.run[...]` -- `shape`, `mask_domain`,
    `plane_index`, `hash_tag`, `block_profile` -- and those members have the
    same names and meanings in `block.json` as in `run.json`
    (`write_block`, :1080-1159).  What a block does NOT have (`run_binding`,
    `run_shape_words`, `block_digests`, `internal_boundaries`,
    `boundary_scales`, `stage_files`) is absent, and every reader of those
    is a block-aware branch or never reached for a block.
    """

    standalone = True

    def __init__(self, directory: str):  # noqa: C901 -- one refusal per line
        self.dir = os.path.abspath(directory)
        path = os.path.join(self.dir, BLOCK_FILE)
        if not os.path.exists(path):
            raise ValueError(f"{self.dir}: no {BLOCK_FILE} -- not a standalone "
                             "block capture")
        with open(path, "rb") as fh:
            raw = fh.read()
        self.block_sha256 = hashlib.sha256(raw).hexdigest()
        self.block_bytes = len(raw)
        # the RunBundle attribute names, so that nothing downstream branches
        self.run_sha256, self.run_bytes = self.block_sha256, self.block_bytes
        self.run = json.loads(raw)
        d = self.run
        if d.get("schema") != SCHEMA_BLOCK:
            raise ValueError(f"{BLOCK_FILE}: schema {d.get('schema')!r} is not "
                             f"{SCHEMA_BLOCK!r} (a run bundle is read by "
                             "zk60_native_rg_bundle.RunBundle)")
        self.schema = SCHEMA_BLOCK
        if d.get("kind") != BLOCK_KIND:
            raise ValueError(f"{BLOCK_FILE}: kind {d.get('kind')!r} is not "
                             f"{BLOCK_KIND!r}")
        if d.get("coverage") != BLOCK_COVERAGE:
            raise ValueError(f"{BLOCK_FILE}: coverage {d.get('coverage')!r} is "
                             f"not {BLOCK_COVERAGE!r}")
        prof = d.get("profile")
        if not (prof == d.get("transcript_domain") == d.get("block_profile")
                == d.get("shape", {}).get("profile")):
            raise ValueError(
                f"{BLOCK_FILE}: a standalone block's transcript domain, block "
                "profile and shape profile are one string (TRANSCRIPT_PROGRAM "
                "entry 2), and these are not")
        if bytes(d["transcript_domain_bytes"]).decode() != prof:
            raise ValueError(f"{BLOCK_FILE}: transcript_domain_bytes are not the "
                             "profile string")
        self.profile = prof
        self.blocks = d["blocks"]
        if self.blocks != 1:
            raise ValueError(f"{BLOCK_FILE}: declares {self.blocks} blocks; a "
                             "standalone block is one")
        self.boundaries = 0
        self.shape = Shape(d["shape"], d["mask_domain"])
        with open(os.path.join(self.dir, "manifest.json"), "rb") as fh:
            self.manifest = json.loads(fh.read())
        self.array_refusals: list[str] = []
        self.store = None
        listed = {e["file"]: e for e in self.manifest.get("files", [])}
        e = listed.get(ARRAY_STORE_FILE, {})
        try:
            self.store = ArrayStore(
                os.path.join(self.dir, ARRAY_STORE_FILE),
                declared_bytes=e.get("bytes"),
                declared_sha256=e.get("sha256"),
            )
        except ArrayRefused as exc:
            self.array_refusals.append(str(exc))
        if d.get("observation_files") != [OBSERVATIONS_FILE]:
            raise ValueError(f"{BLOCK_FILE}: observation_files "
                             f"{d.get('observation_files')!r} is not "
                             f"[{OBSERVATIONS_FILE!r}]")
        self.stages = [BlockStage(os.path.join(self.dir, OBSERVATIONS_FILE),
                                  store=self.store,
                                  refusals=self.array_refusals)]
        if self.store is not None:
            self.run_arrays_resolved = resolve_document(
                self.run, self.store, BLOCK_FILE, self.array_refusals)
        else:
            self.run_arrays_resolved = 0
        # D19 / ruling T-7: the rule is DERIVED from the block profile and
        # compared with the declared tag, exactly as for a run.  One finding
        # the run's reader makes is about a RUN and is false of a block: that
        # the run profile equals the block profile.  A standalone block's
        # transcript domain IS its block profile (`protocol::transcript`, and
        # `begin_block` rebuilds it under `sh.profile`, :370), so the finding
        # is replaced by the fact, named, and no refusal is touched.
        rec = rule_for_bundle(self)
        dropped = [f for f in rec["findings"]
                   if f.startswith("run.json: the run profile equals the block "
                                   "profile")]
        rec["findings"] = [f for f in rec["findings"] if f not in dropped]
        if dropped:
            rec["standalone_block_note"] = (
                "a standalone block's transcript domain is its own block "
                "profile (TRANSCRIPT_PROGRAM entry 2; block_capture_shaped.rs "
                ":370 rebuilds the header under sh.profile), so the run "
                "reader's finding that the run profile equals the block "
                "profile does not apply and is not recorded")
        self.hash_rule_record = rec
        self.hash_rule = rec["rule"]
        self.public_tables_included = bool(d.get("public_tables_included", False))
        vpath = os.path.join(self.dir, VALIDATION_FILE)
        self.validation = None
        if os.path.exists(vpath):
            with open(vpath, "rb") as fh:
                self.validation_raw = fh.read()
            self.validation = json.loads(self.validation_raw)

    def boundary(self, k: int) -> dict:
        raise KeyError(f"{self.name}: a standalone block has no internal "
                       f"boundary (asked for boundary {k})")


def is_block_bundle(directory: str) -> bool:
    return os.path.exists(os.path.join(directory, BLOCK_FILE))


def load_bundle(directory: str):
    """A run bundle or a standalone block bundle, by what the directory
    holds.  A directory with BOTH files is refused: it is neither."""
    has_block = is_block_bundle(directory)
    has_run = os.path.exists(os.path.join(directory, "run.json"))
    if has_block and has_run:
        raise ValueError(f"{directory}: holds both {BLOCK_FILE} and run.json; a "
                         "bundle is one or the other")
    return BlockBundle(directory) if has_block else RunBundle(directory)
