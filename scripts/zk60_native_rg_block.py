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


# ---------------------------------------------------------------------------
# 2.  THE BLOCK LAYER'S OWN PINS
# ---------------------------------------------------------------------------
# The discipline is round 6's (`zk60_native_rg_runpins`): a digest is in the
# table below only because the file was READ at that commit against the port
# that depends on it, and the mechanism is BUNDLE-SIDE.  Three files, because
# this module transcribes something from each:
#
#   * `block_capture_shaped.rs` -- THE WRITER, to a block what
#     `run_capture.rs` is to a run;
#   * `wire.rs` -- the frame's 40-byte envelope, which `block_integrity`
#     compares with `receipt.bin` (the run gate never decoded a frame, so it
#     never pinned this file; the block layer does, so it must);
#   * `private_block.rs` -- `ExpectedIo::to_bytes`'s 112-byte policy frame,
#     which `block_integrity` parses, and `ENDPOINT_SCALES`, which the
#     endpoint-scale channel names.
DEPENDS = {
    "src/private_block/block_capture_shaped.rs": (
        ("zk60_native_rg_block", "THE WRITER: `SCHEMA`, the three kinds, the "
         "coverage string, the five file names, `ROLE_ORDER`, "
         "`TRANSCRIPT_LABELS` (15, transcribed as `EXPECTED_BLOCK_LABELS`), "
         "`write_observations`' member set (a run stage file's minus its "
         "framing) and `write_block`'s (the header, `external_endpoints`, "
         "`observation_files`, `mask_domain`)", "BlockBundle, BlockStage, "
         "block_integrity"),
        ("zk60_native_rg_block", "`begin_block`: the header program -- "
         "`tagged_transcript(sh, sh.profile)`, then `expected-IO`, "
         "`public-statement` (the block's digest), `parameters`, "
         "`calibration`, `schedule`; the state there is `block_binding` -- "
         "and the prefix A, M, three LogUp draws, H", "BlockReplay.run"),
        ("zk60_native_rg_block", "`endpoint_pcs`: both external endpoints at "
         "the shape's endpoint geometry, `site_rows = [data, data + 1]`, "
         "`claim_sources = [(21 or 22, claims)]` written with stage 0, "
         "`boundary` null", "block_integrity, block_controls"),
        ("zk60_native_rg_terminals, zk60_native_rg_planes, "
         "zk60_native_rg_hashrule, zk60_native_rg_hashlayer, "
         "zk60_native_rg_pcs, zk60_native_rg_mask", "the per-slot, `M` and "
         "role records (the run capture's encoders COPIED, :43-52), the plane "
         "index member, the `hash_tag` member and the opened columns as "
         "recorded -- the same fields each port reads in a run stage file",
         "every port, unchanged"),
    ),
    "src/private_block/wire.rs": (
        ("zk60_native_rg_block", "`MAGIC = b\"HLPBLOK1\"` (:15), "
         "`HEADER = 8 + 32` (:16), and `encode` writing the magic then the "
         "header state (:145-146), which `decode` compares (:218, :221)",
         "block_integrity (the envelope)"),
    ),
    "src/private_block.rs": (
        ("zk60_native_rg_block", "`EXPECTED_BYTES = 8 + 32 + 4 + 4 + 2 * 32` "
         "(:357), `ExpectedIo::to_bytes` (:998-1007: `HBLKEXP1`, the context, "
         "the input and output scales as little-endian i32, the two roots), "
         "and `ENDPOINT_SCALES = (0, 0)` (:371), the approved calibration's "
         "scales that `IoSpec::new` and ruling CS-8 pin", "block_integrity "
         "(the policy frame), the endpoint-scale channel"),
    ),
}

FEAE674 = "feae674dbd5c5a3e7646da9e33bc423e76b8ab32"
C19F06BF = "19f06bfde4a1e4fcb0f39acc19da1f6654d66f9c"
BLOCK_BUNDLES = ("rung-g-dense", "rung-g-zero", "m125-dense", "m125-zero")

# path -> sha256 -> (git blob, the capture commits, the bundles, bytes)
BLOCK_LAYER_PINS = {
    "src/private_block/block_capture_shaped.rs": {
        "37312d49ccea469dbea25936d11e1a54943274328efdf8759e39a0eef640fd8f": {
            "blob": "5aa90aba52b0ea0e2228a03ee80112ad43bc03b7",
            "commits": (FEAE674, C19F06BF),
            "bundles": BLOCK_BUNDLES,
            "bytes": 64364,
        },
    },
    "src/private_block/wire.rs": {
        "99e69b5c92154ed2ba44c6c568d14704ecd66ae2ee85b13ae337b6501bffc8a1": {
            "blob": "31b95b0b2f54a7df3457ad605e6a4b51b0b16990",
            "commits": (FEAE674, C19F06BF),
            "bundles": BLOCK_BUNDLES,
            "bytes": 20801,
        },
    },
    "src/private_block.rs": {
        "58a73b4004ce11c6dd0d0cc2bbef9bce4f180e08797388883753d50c7ba1be1f": {
            "blob": "c7f7a2bb09fb8ae3ccfb6420f2882d1efec026ed",
            "commits": (FEAE674, C19F06BF),
            "bundles": BLOCK_BUNDLES,
            "bytes": 61852,
        },
    },
}

READINGS = {
    ("src/private_block/block_capture_shaped.rs",
     "37312d49ccea469dbea25936d11e1a54943274328efdf8759e39a0eef640fd8f"):
        "BASE (lane stage 45, `feae674`; byte-identical at `19f06bf` and "
        "`544fbaf`, blob 5aa90aba).  READ WHOLE on 2026-09-23 (round 9j), all "
        "1,369 lines, against this module.  `SCHEMA` (:74), the three kinds "
        "(:1022, :1085, :1344), `coverage` (:1085), the file names "
        "(:80-84), `ROLE_ORDER` (:87), `TRANSCRIPT_LABELS` (:1164-1180, 15 "
        "entries, equal entry for entry to `EXPECTED_BLOCK_LABELS`) and "
        "`TRANSCRIPT_PROGRAM` (:1183-1193), which no port reads.  "
        "`begin_block` (:359-430) rebuilds the header under "
        "`protocol::tagged_transcript(sh, sh.profile)` in exactly "
        "`BlockReplay.run`'s order, takes the state there as `block_binding`, "
        "and replays A / M / three LogUp / H from the receipt's roots.  The "
        "slot, `M` and PCS records (:447-605, :608-665, :924-999) are the "
        "run capture's encoders COPIED, with the key sequences asserted "
        "against a one-block run capture in the lane's own test; "
        "`endpoint_pcs` (:705-733) gives each external endpoint "
        "`site_rows = [data, data + 1]`, `claim_sources = [(slot 21 or 22, "
        "claims)]`, written with stage 0 and `boundary: null` (:944-951).  "
        "`write_observations` (:1018-1051) omits the run's framing; "
        "`write_block` (:1080-1159) writes `external_endpoints`, "
        "`observation_files`, `mask_domain` = (`MASK_LOG_DOM`, "
        "`opened_cols`) and the plane index.  `take` (:818-839) refuses "
        "unless the verifier ACCEPTED; `write_bundle` (:1317-1364) writes "
        "`manifest.json` last with 35 pins (`OWN_SOURCE_FILES` 12 + the run "
        "capture's 23 shared).  It reaches `run_capture.rs` for three "
        "CONSTANTS only -- `ARRAY_MIN` (a threshold the array reader does not "
        "depend on), `SHARED_SOURCE_FILES` (names whose digests ARE in the "
        "bundle) and `ALLOWED_KEYS` (the lane's allow-list test) -- none of "
        "which this gate transcribes, which is why a block bundle may leave "
        "`run_capture.rs` unpinned (NOT_ON_A_STANDALONE_BLOCKS_PATH)",
    ("src/private_block/wire.rs",
     "99e69b5c92154ed2ba44c6c568d14704ecd66ae2ee85b13ae337b6501bffc8a1"):
        "BASE for the block layer (the run gate never decoded a frame, so it "
        "never read this file against a port; the digest is the one every "
        "`/5-run` bundle since `f4697f9` has pinned, byte-identical from "
        "`99a8de8` to `19f06bf`).  READ 2026-09-23 for what `block_integrity` "
        "transcribes and nothing else: `MAGIC = b\"HLPBLOK1\"` (:15), "
        "`HEADER = 8 + 32` (:16), `encode` writing the magic then the "
        "binding (:145-146) and `decode` comparing both (:218, :221).  The "
        "segment codec (`RUN_MAGIC`, :250-) is a run's and is not read",
    ("src/private_block.rs",
     "58a73b4004ce11c6dd0d0cc2bbef9bce4f180e08797388883753d50c7ba1be1f"):
        "BASE for the block layer (the run gate names this file only in "
        "`NEWLY_PINNED_OWN_FILES`, compared by no table -- R9i.11 item 1).  "
        "READ 2026-09-23 for what `block_integrity` and the endpoint-scale "
        "channel transcribe: `EXPECTED_BYTES` (:357), `ENDPOINT_SCALES = "
        "(0, 0)` (:371), `ExpectedIo::to_bytes` / `from_bytes` "
        "(:998-1013).  And the whole diff from the last digest any round "
        "read (`7a9b31ac`, rung-K8's `99a8de8`) was read hunk by hunk: "
        "**+220 / -12**, stages 38-45 -- eight `#[cfg(test)] mod` lines "
        "(stages 38, 40-45) with their comments; ruling CS-4's and CS-1's "
        "`check_words` (the constructors' own checks lifted into one "
        "function, same order, same messages -- the 12 removed lines are "
        "the two constructors' bodies re-emitted after it) and their "
        "`check_for_shape` re-checks; ruling S38-F1(a)'s refusal of "
        "`act[128] != 0` where `Dom::F` pads; `BlockPublic::check_for_shape`; "
        "`IoSpec::check_for_shape` (CS-4) and `scales_are_the_approved_ones` "
        "(CS-8), called by `validate`; and the CS-1 / CS-4 / CS-8 re-checks "
        "at `verify_bytes_at` / `verify_bytes`.  Every addition is a REFUSAL "
        "or a test module.  `BlockPublic::digest`, `absorb_into`, "
        "`ExpectedIo::to_bytes` and `calibration_identity` are outside every "
        "hunk: nothing absorbed moves",
}

# Run-layer files a STANDALONE block never reaches, named with the reason,
# because a block bundle does not pin them and must not be refused for it.
NOT_ON_A_STANDALONE_BLOCKS_PATH = {
    "src/private_block/run.rs": "the run prover and verifier; "
    "`protocol::verify_inner_at` never reaches it (the writer's own "
    "`NOT_ON_THE_BLOCKS_PATH`, block_capture_shaped.rs:115-120)",
    "src/private_block/boundary.rs": "an internal boundary exists only "
    "between two blocks of a run",
    "src/private_block/run_capture.rs": "the RUN writer.  The block writer "
    "COPIED its encoders and reads three of its constants (see the reading "
    "of block_capture_shaped.rs), none transcribed by this gate",
}

AFFECTED_STAGES = {
    "src/private_block/block_capture_shaped.rs": (
        None,  # every stage
        "the WRITER decides which fields a block bundle has and what each "
        "one means, and `begin_block` is the header program the replay "
        "transcribes",
    ),
    "src/private_block/wire.rs": (
        ("stage1_integrity", "stage7_channels"),
        "the frame envelope `block_integrity` compares with receipt.bin",
    ),
    "src/private_block.rs": (
        ("stage1_integrity", "stage7_channels"),
        "the policy frame `block_integrity` parses and the approved scales "
        "the endpoint-scale channel names",
    ),
}


def check_block_layer_pins(bundle) -> dict:
    """The block bundle's own `source_pins` for the BLOCK LAYER against the
    digests this gate has READ.  The same contract as
    `zk60_native_rg_runpins.check_run_layer_pins` -- same keys, a moved or
    missing pin suspends the affected stages BY NAME -- plus the three
    run-layer files named as off a standalone block's path, and the 23
    shared files through the run gate's own `check_shared_pins`."""
    from zk60_native_rg_runpins import ALL_STAGES, check_shared_pins
    pins = {p["file"]: p["sha256"]
            for p in bundle.manifest.get("source_pins", [])}
    accepted, moved, missing, detail = [], [], [], []
    for path in sorted(BLOCK_LAYER_PINS):
        table = BLOCK_LAYER_PINS[path]
        got = pins.get(path)
        if got is None:
            missing.append(f"{path}: the bundle declares no digest for it, and "
                           "this gate does not read the Rust tree, so the file "
                           "is unchecked")
            detail.append({"file": path, "declared": None, "read": False})
            continue
        entry = table.get(got)
        if entry is None:
            moved.append(f"{path}: the bundle pins {got[:12]}, which is not one "
                         f"of the {len(table)} digests this gate has read "
                         f"({', '.join(sorted(d[:12] for d in table))})")
            detail.append({"file": path, "declared": got, "read": False})
            continue
        accepted.append(f"{path}: {got[:12]} -- read at "
                        f"{', '.join(c[:7] for c in entry['commits'])}")
        detail.append({"file": path, "declared": got, "read": True,
                       "git_blob": entry["blob"],
                       "lane_commits": list(entry["commits"]),
                       "bundles_written_at_them": list(entry["bundles"]),
                       "bytes": entry["bytes"],
                       "reading": READINGS[(path, got)]})
    run_layer_declared = sorted(f for f in NOT_ON_A_STANDALONE_BLOCKS_PATH
                                if f in pins)
    ok = not moved and not missing
    suspended: dict = {}
    for line in moved + missing:
        path = line.split(":", 1)[0]
        stages, why = AFFECTED_STAGES[path]
        for s in (stages or ALL_STAGES):
            suspended.setdefault(s, []).append(f"{path}: {why}")
    return {
        "what": "the BLOCK-LAYER files a standalone block bundle pins -- the "
                "block writer, the frame envelope and the policy frame -- "
                "against the digests this gate has READ (round 9j)",
        "files_checked": sorted(BLOCK_LAYER_PINS),
        "run_layer_files_not_on_a_standalone_blocks_path":
            NOT_ON_A_STANDALONE_BLOCKS_PATH,
        "run_layer_files_the_bundle_declares_anyway": run_layer_declared,
        "shared_files": check_shared_pins(bundle),
        "per_file": detail,
        "pins_at_a_read_digest": accepted,
        "pins_that_moved": moved,
        "pins_missing_from_the_bundle": missing,
        "stages_not_checked": {k: sorted(set(v)) for k, v in suspended.items()},
        "ok": ok and not run_layer_declared,
    }


# ---------------------------------------------------------------------------
# 3.  INTEGRITY
# ---------------------------------------------------------------------------
def parse_policy(raw: bytes) -> dict | None:
    """`ExpectedIo::to_bytes` (private_block.rs:998-1007), or None."""
    if len(raw) != POLICY_BYTES or raw[:8] != POLICY_MAGIC:
        return None
    return {
        "context": list(raw[8:40]),
        "input_scale": int.from_bytes(raw[40:44], "little", signed=True),
        "output_scale": int.from_bytes(raw[44:48], "little", signed=True),
        "input_root": list(raw[48:80]),
        "output_root": list(raw[80:112]),
    }


# `private_block.rs:371`, read at 58a73b40: the approved calibration's scales
ENDPOINT_SCALES = (0, 0)


def block_integrity(bundle) -> dict:  # noqa: C901 -- one finding per line
    """Stage 1 for a standalone block.  Every failure is a named string."""
    f: list[str] = []
    man = bundle.manifest
    d = bundle.run
    if man.get("schema") != SCHEMA_BLOCK or man.get("kind") != BLOCK_MANIFEST_KIND:
        f.append(f"manifest.json: schema/kind {man.get('schema')!r}/"
                 f"{man.get('kind')!r} is not {SCHEMA_BLOCK!r}/"
                 f"{BLOCK_MANIFEST_KIND!r}")
    f.extend(bundle.array_refusals)
    if man.get("profile") != bundle.profile:
        f.append("manifest.json: profile differs from block.json's")
    if man.get("blocks") != 1:
        f.append("manifest.json: a block manifest declares one block")
    if man.get("source_commit") != d.get("source_commit"):
        f.append("manifest.json: source_commit differs from block.json's")
    listed = {e["file"]: e for e in man.get("files", [])}
    checked = 0
    for fn, e in sorted(listed.items()):
        path = os.path.join(bundle.dir, fn)
        if not os.path.exists(path):
            f.append(f"{fn}: in the manifest, absent from the directory")
            continue
        h = hashlib.sha256()
        n = 0
        with open(path, "rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 22), b""):
                h.update(chunk)
                n += len(chunk)
        checked += 1
        if n != e["bytes"]:
            f.append(f"{fn}: {n} bytes on disk, {e['bytes']} in the manifest")
        if h.hexdigest() != e["sha256"]:
            f.append(f"{fn}: sha256 on disk differs from the manifest's")
    want_files = {BLOCK_FILE, OBSERVATIONS_FILE, ARRAY_STORE_FILE, RECEIPT_FILE,
                  EXPECTED_FILE, "README.md"}
    if set(listed) != want_files:
        f.append(f"manifest.json: lists {sorted(listed)}, the writer writes "
                 f"{sorted(want_files)}")
    on_disk = {fn for fn in os.listdir(bundle.dir)
               if os.path.isfile(os.path.join(bundle.dir, fn))}
    for fn in sorted(on_disk - set(listed) - {"manifest.json", VALIDATION_FILE}):
        f.append(f"{fn}: on disk, not in the manifest")
    total = sum(e["bytes"] for e in listed.values())
    if man.get("total_bytes") not in (None, total):
        f.append(f"manifest.json: total_bytes {man.get('total_bytes')} != {total}")

    if d["field_modulus"] != 0xFFFFFFFF00000001:
        f.append("block.json: field modulus is not Goldilocks")
    if d["extension_nonresidue"] != 7:
        f.append("block.json: the extension nonresidue is not 7")
    policy_raw = bytes(d["expected_policy"])
    if hashlib.sha256(policy_raw).hexdigest() != d["expected_policy_sha256"]:
        f.append("block.json: expected_policy_sha256 differs from the policy bytes")
    # the two binary files the writer puts beside the JSON
    with open(os.path.join(bundle.dir, EXPECTED_FILE), "rb") as fh:
        expected_bin = fh.read()
    if expected_bin != policy_raw:
        f.append(f"{EXPECTED_FILE}: not the policy bytes block.json absorbs")
    with open(os.path.join(bundle.dir, RECEIPT_FILE), "rb") as fh:
        receipt = fh.read()
    if len(receipt) != d["proof_bytes"]:
        f.append(f"{RECEIPT_FILE}: {len(receipt)} bytes, block.json declares "
                 f"{d['proof_bytes']}")
    if hashlib.sha256(receipt).hexdigest() != d["proof_sha256"]:
        f.append(f"{RECEIPT_FILE}: sha256 is not block.json's proof_sha256")
    obs = bundle.stages[0].doc
    if (obs.get("proof_bytes"), obs.get("proof_sha256")) != (
            d["proof_bytes"], d["proof_sha256"]):
        f.append("observations.json: the receipt pin differs from block.json's")
    envelope_ok = (receipt[:8] == FRAME_MAGIC
                   and list(receipt[8:FRAME_ENVELOPE]) == d["block_binding"])
    if not envelope_ok:
        f.append(f"{RECEIPT_FILE}: the frame's 40-byte envelope is not "
                 "HLPBLOK1 followed by block_binding (wire.rs:15, :145-146)")
    pol = parse_policy(policy_raw)
    ee = d["external_endpoints"]
    if pol is None:
        f.append("block.json: expected_policy is not a 112-byte HBLKEXP1 frame "
                 "(ExpectedIo::to_bytes)")
    else:
        if pol["context"] != d["context"]:
            f.append("the policy's context is not block.json's")
        if (pol["input_scale"], pol["output_scale"]) != (
                ee["input_scale"], ee["output_scale"]):
            f.append("the policy's scales are not the declared endpoint scales")
        if (pol["input_root"], pol["output_root"]) != (
                ee["input_root"], ee["output_root"]):
            f.append("the policy's roots are not the declared endpoint roots")
    got_labels = [t["label"] for t in d["transcript_labels"]]
    if got_labels != list(EXPECTED_BLOCK_LABELS):
        f.append(f"block.json: the transcript labels are not the declared "
                 f"block set (got {got_labels})")
    if any(lab in got_labels for lab in RUN_ONLY_LABELS):
        f.append("block.json: a run-only label is declared for a block")

    sh = bundle.shape
    st = bundle.stages[0]
    o = st.doc
    if o["log_cols"] != sh.log_cols:
        f.append(f"{st.name}: log_cols {o['log_cols']} != the shape's {sh.log_cols}")
    if len(o["arguments"]) != sh.n_slots:
        f.append(f"{st.name}: {len(o['arguments'])} slots, the shape says {sh.n_slots}")
    for s, arg in enumerate(o["arguments"]):
        if arg["slot"] != s:
            f.append(f"{st.name}: argument {s} declares slot {arg['slot']}")
        if (arg["main"], arg["extension"], arg["degree"]) != sh.slots[s]:
            f.append(f"{st.name} slot {s}: (main, extension, degree) differ "
                     "from the shape's")
    if bytes(o["block_digest"]) != bytes(d["public_statement_digest"]):
        f.append(f"{st.name}: block_digest is not block.json's public statement "
                 "(a block absorbs its OWN digest)")
    if o["layout_digest"] != d["schedule_digest"]:
        f.append(f"{st.name}: layout_digest is not block.json's schedule_digest")
    if o["header"]["state"] != d["block_binding"]:
        f.append(f"{st.name}: the header state is not block_binding")
    m = o["mask"]
    if m["rows"] != 2 * sh.n_slots + 4:
        f.append(f"{st.name}: M has {m['rows']} rows, not 2*slots+4")
    if len(m["specs"]) != sh.n_slots:
        f.append(f"{st.name}: M has {len(m['specs'])} specs for {sh.n_slots} slots")
    if len(m["columns"]) != sh.mask_columns:
        f.append(f"{st.name}: M opened {len(m['columns'])} columns, not "
                 f"{sh.mask_columns}")
    if bytes(m["root"]) != bytes(o["mask_root"]):
        f.append(f"{st.name}: the M opening's root is not mask_root")
    want_order = ["M", *ROLE_ORDER]
    if o["opening_order"] != want_order:
        f.append(f"{st.name}: opening_order {o['opening_order']} != {want_order}")
    if [r["role"] for r in o["roles"]] != list(ROLE_ORDER):
        f.append(f"{st.name}: the roles array does not follow opening_order")
    if any("stage" in s for s in o["transcript_sites"]):
        f.append(f"{st.name}: a transcript site carries a stage (a run's framing)")
    for r in o["roles"]:
        p = r["params"]
        nm = r["role"]
        if len(r["row_roles"]) != r["commitment"]["rows"]:
            f.append(f"{st.name} {nm}: row_roles shorter than the row count")
        if len(r["proximity_rhos"]) != r["commitment"]["rows"]:
            f.append(f"{st.name} {nm}: proximity_rhos != rows")
        kinds = [x["kind"] for x in r["row_roles"]]
        if kinds.count("prox") != 2:
            f.append(f"{st.name} {nm}: {kinds.count('prox')} proximity rows, not 2")
        if p["num_col_checks"] != sh.opened_cols or len(r["columns"]) != sh.opened_cols:
            f.append(f"{st.name} {nm}: column-check count differs from the shape")
        if r["boundary"] is not None:
            f.append(f"{st.name} {nm}: names a boundary; a block has none")
        if nm in ("A", "H"):
            if r["commitment_kind"] != "block":
                f.append(f"{st.name} {nm}: commitment_kind {r['commitment_kind']!r}")
            if (p["log_cols"], p["inv_rate"]) != (sh.log_cols, sh.inv_rate):
                f.append(f"{st.name} {nm}: PCS params differ from the shape")
            if r["claim_sources"] != []:
                f.append(f"{st.name} {nm}: claim_sources on a block commitment")
            root = o["a_root"] if nm == "A" else o["h_root"]
            rows = o["a_rows"] if nm == "A" else o["h_rows"]
            if bytes(r["commitment"]["root"]) != bytes(root) or r["commitment"]["rows"] != rows:
                f.append(f"{st.name} {nm}: root / rows differ from the header's")
            continue
        # the two EXTERNAL endpoints, both in this one proof
        slot = 21 if nm == "Input" else 22
        if r["commitment_kind"] != "external-endpoint":
            f.append(f"{st.name} {nm}: commitment_kind {r['commitment_kind']!r}, "
                     "not external-endpoint")
        if (p["log_cols"], p["inv_rate"]) != (sh.endpoint_log_n, sh.endpoint_inv_rate):
            f.append(f"{st.name} {nm}: PCS params are not the endpoint geometry")
        if r["commitment"]["rows"] != sh.endpoint_rows or r["commitment"]["rows"] != ee["rows"]:
            f.append(f"{st.name} {nm}: endpoint rows != the shape's")
        if (r["data_rows"], r["site_rows"], r["prox_row"]) != (
                ee["data_rows"], ee["site_rows"], ee["prox_row"]):
            f.append(f"{st.name} {nm}: data / site / proximity rows differ from "
                     "external_endpoints")
        if r["site_rows"] != [r["data_rows"], r["data_rows"] + 1]:
            f.append(f"{st.name} {nm}: the reserved pair is not the first two "
                     "rows after the data")
        got = [(s["stage"], s["slot"], s["claims"]) for s in r["claim_sources"]]
        if got != [(0, slot, 1)]:
            f.append(f"{st.name} {nm}: claim_sources {got} are not "
                     f"[(0, {slot}, 1)] -- a standalone block's {nm} claim comes "
                     f"from slot {slot} alone")
        want_root = ee["input_root"] if nm == "Input" else ee["output_root"]
        if list(r["commitment"]["root"]) != want_root:
            f.append(f"{st.name} {nm}: the opened root is not the declared "
                     "endpoint root")
    roots: dict = {}
    for r in o["roles"]:
        roots.setdefault(bytes(r["commitment"]["root"]).hex(), []).append(r["role"])
    twice = {k: v for k, v in roots.items() if len(v) > 1}
    for k, v in twice.items():
        f.append(f"the commitment {k[:16]} is opened more than once: {v}")
    hr = bundle.hash_rule_record
    f.extend(hr["refusals"])

    # validation.json: the fresh-process re-verify the writer's lane ran.
    # NOT pinned by the manifest (written after it), so it is READ, compared
    # with what IS pinned, and reported -- never trusted for a figure.
    v = bundle.validation
    vout = {"present": v is not None}
    if v is not None:
        with open(os.path.join(bundle.dir, "manifest.json"), "rb") as fh:
            man_sha = hashlib.sha256(fh.read()).hexdigest()
        flags = {k: v.get(k) for k in ("native_reverified",
                                       "canonical_capture_reproduced",
                                       "source_pins_match",
                                       "values_match_the_decoded_receipt",
                                       "fresh_process")}
        vout.update({
            "flags": flags,
            "manifest_sha256_matches": v.get("manifest_sha256") == man_sha,
            "proof_sha256_matches": v.get("proof_sha256") == d["proof_sha256"],
            "source_commit_matches": v.get("source_commit") == d["source_commit"],
            "what": "written by a fresh process AFTER the manifest, so the "
            "manifest does not pin it; read and compared, never used for a "
            "figure",
        })
        if not all(flags.values()):
            f.append(f"{VALIDATION_FILE}: a flag is false: {flags}")
        if not (vout["manifest_sha256_matches"] and vout["proof_sha256_matches"]
                and vout["source_commit_matches"]):
            f.append(f"{VALIDATION_FILE}: does not name this bundle's manifest, "
                     "proof or source commit")
    store = bundle.store.summary() if bundle.store is not None else {"ok": False}
    store["references_resolved_per_stage"] = {st.name: st.arrays_resolved}
    store["references_resolved_in_run_json"] = bundle.run_arrays_resolved
    return {
        "bundle": bundle.name,
        "dir": bundle.dir,
        "schema": d["schema"],
        "standalone_block": True,
        "array_store": store,
        "kind": d["kind"],
        "coverage": d["coverage"],
        "profile": bundle.profile,
        "block_profile": d["block_profile"],
        "blocks": 1,
        "boundaries": 0,
        "source_commit": d["source_commit"],
        "fully_verified": d["fully_verified"],
        "privacy_review_complete": d["privacy_review_complete"],
        "weight_policy": d["weight_policy"],
        "public_tables_included": d["public_tables_included"],
        "hash_rule": {k: v for k, v in hr.items() if k != "rule"},
        "manifest_files_checked": checked,
        "manifest_total_bytes": total,
        "source_pins": man.get("source_pins", []),
        "shape": bundle.shape.raw,
        "mask_domain": d["mask_domain"],
        "receipt": {"bytes": len(receipt), "sha256": d["proof_sha256"],
                    "envelope_is_the_magic_and_block_binding": envelope_ok},
        "endpoint_policy": {
            "bytes": len(policy_raw),
            "parsed": pol is not None,
            "scales": None if pol is None else [pol["input_scale"],
                                                pol["output_scale"]],
            "scales_are_the_approved_calibrations": (
                pol is not None
                and (pol["input_scale"], pol["output_scale"]) == ENDPOINT_SCALES),
        },
        "validation_file": vout,
        "distinct_roots_opened": len(roots),
        "any_root_opened_twice": bool(twice),
        "findings": f,
        "ok": not f,
    }


# ---------------------------------------------------------------------------
# 4.  THE REPLAY
# ---------------------------------------------------------------------------
from zk60_native_rg_replay import RunReplay  # noqa: E402


class BlockReplay(RunReplay):
    """`RunReplay` with the BLOCK header and without the run's three stage
    additions (the hooks `_open_stage`, `_sites_of`, `_close_stage`).
    Everything between -- the A / M / LogUp / H prefix, every slot, the `M`
    opening, the four PCS openings -- is the run replay's own code."""

    def __init__(self, bundle):
        super().__init__(bundle)
        self.block_binding_ok = None

    def run(self) -> "BlockReplay":
        b = self.b
        d = b.run
        rule = getattr(b, "hash_rule", None)
        if rule is None:
            self._fail("the hash rule was refused for this bundle, so no replay "
                       "was attempted")
            return self
        self.rule_name = rule.name
        tr = rule.transcript(bytes(d["transcript_domain_bytes"]))
        # begin_block (block_capture_shaped.rs:370-376) = protocol::transcript
        tr.absorb(b"expected-IO", bytes(d["expected_policy"]))
        tr.absorb(b"public-statement", bytes(d["public_statement_digest"]))
        tr.absorb(b"parameters", d["parameter_line"].encode())
        tr.absorb(b"calibration", bytes(d["calibration"]))
        tr.absorb(b"schedule", bytes(d["schedule_digest"]))
        self.block_binding_ok = list(tr.state) == d["block_binding"]
        self.checkpoints += 1
        if not self.block_binding_ok:
            self._fail("block header: the state after the header is not "
                       "block_binding")
        for st in b.stages:
            self._stage(tr, st)
        self.final_counter = tr.counter
        return self

    def _open_stage(self, tr, st, doc, tag):
        return None      # no position tag, no stage word, no boundary root

    def _sites_of(self, doc, k, tag):
        sh = self.b.shape
        if any("stage" in s for s in doc["transcript_sites"]):
            self._fail(f"{tag}: a transcript site carries a stage -- a run's "
                       "framing, which a standalone block does not write")
        sites = {(0, s["site"]): s for s in doc["transcript_sites"]}
        want = [f"slot {s:02d}" for s in range(sh.n_slots)] + [
            f"{nm} opening" for nm in doc["opening_order"]]
        if [s["site"] for s in doc["transcript_sites"]] != want:
            self._fail(f"{tag}: the transcript_sites index is not the declared "
                       "site order")
        return sites

    def _close_stage(self, tr, st, doc, tag, start):
        return None      # no segment, so no end tag

    def summary(self) -> dict:
        out = super().summary()
        out.pop("run_binding_reproduced", None)
        out["block_binding_reproduced"] = self.block_binding_ok
        out["header"] = (
            "the BLOCK header: expected-IO, public-statement (this block's own "
            "digest), parameters (the block profile's line), calibration, "
            "schedule, under the block profile's domain -- no run-shape, no "
            "pb-run-stage / pb-run-block, no boundary root, no position tag")
        return out


def binding_reproduced(summary: dict):
    """The header binding of a replay summary, run or block."""
    if "run_binding_reproduced" in summary:
        return summary["run_binding_reproduced"]
    return summary.get("block_binding_reproduced")


# ---------------------------------------------------------------------------
# 5.  THE RUN-CONTROL FAMILY'S BLOCK ANALOGUES (stage 6)
# ---------------------------------------------------------------------------
def block_controls(bundle, other_bundle, views, replay, shared) -> dict:
    """Stage 6 for a standalone block.  The run family (C1-C6,
    `zk60_native_rg_controls`) perturbs a BOUNDARY; a block has none, so
    each control that can have an analogue is re-aimed at the one
    cross-commitment structure a block does have -- an external endpoint,
    whose data plane is also `A@0`'s IO plane -- and C1, which cannot, is
    named.  Every control records the honest figure beside the perturbed
    one; no captured file is written."""
    import copy

    from zk60_native_rg_joint import discover_shared_planes, run_wide_figure
    from zk60_native_rg_pcs import RunRoleView

    out = {}
    st = bundle.stages[0]
    not_applicable = {
        "C1_two_claims_share_one_reserved_pair": "no commitment of a "
        "standalone block carries two claim sites: each external endpoint "
        "carries ONE (slot 21 or slot 22), A's and H's claim pairs are "
        "per claim, and a boundary -- the one commitment with two sites -- "
        "does not exist",
    }

    # ------------------------------------------------------------- C2b
    ev = views["E-Input"]
    role = st.role("Input")
    sites = list(role["site_rows"])
    p = role["prox_row"]
    honest = ev.reserved_row_rank(sites + [p, p + 1])
    single = ev.reserved_row_rank(sites + [p])
    out["C2b_an_external_endpoint_with_a_single_proximity_row"] = {
        "what": f"E-Input's reserved block -- its claim pair {sites} and the "
        f"proximity pair ({p}, {p + 1}) -- modelled with ONE proximity row",
        "mirrors": "C2 (ruling M-1's reason for deriving the row count)",
        "honest": {"rank": honest["rank_on_reserved_rows"],
                   "of": honest["generators"],
                   "disclosed_fp": honest["disclosed_on_the_reserved_block_fp"],
                   "determinant_nonzero": honest["determinant_nonzero"]},
        "perturbed": {"rank": single["rank_on_reserved_rows"],
                      "of": single["generators"],
                      "disclosed_fp": single["disclosed_on_the_reserved_block_fp"]},
        "fires": (single["disclosed_on_the_reserved_block_fp"] > 0
                  and honest["disclosed_on_the_reserved_block_fp"] == 0),
    }

    # ------------------------------------------------------------- C3b
    pair = ["A@0", "E-Input"]
    h3 = run_wide_figure(bundle, views, shared, include_mask=False,
                         subset=pair, label="A@0 and E-Input")
    a_row = st.role("A")["site_rows"][0]
    e_row = sites[0]
    p3 = run_wide_figure(bundle, views, shared, include_mask=False,
                         subset=pair, label="A@0 and E-Input, one row shared",
                         extra_identifications=[(("A@0", a_row),
                                                 ("E-Input", e_row))])
    out["C3b_a_blinding_row_shared_between_an_endpoint_and_A"] = {
        "what": f"A@0[{a_row}] and E-Input[{e_row}] -- one reserved mask row "
        "of each -- made the SAME unknown; the two commitments already share "
        "E-Input's data plane with A@0's IO plane",
        "mirrors": "C3 (a blinding row shared with an adjacent commitment)",
        "honest": {"parts_fp": h3["parts_fp"], "sum_of_parts_fp": h3["sum_of_parts_fp"],
                   "joint_fp": h3["joint_fp"], "identified_rows": h3["identified_rows"],
                   "block_diagonal": h3["non_data_block_is_block_diagonal_by_role"]},
        "perturbed": {"parts_fp": p3["parts_fp"], "sum_of_parts_fp": p3["sum_of_parts_fp"],
                      "joint_fp": p3["joint_fp"],
                      "block_diagonal": p3["non_data_block_is_block_diagonal_by_role"]},
        "marginals_unchanged": p3["parts_fp"] == h3["parts_fp"],
        "fires": (h3["ok"] and not p3["ok"]
                  and p3["joint_fp"] > p3["sum_of_parts_fp"]),
    }

    # ------------------------------------------------------------- C4b
    ri, ro = st.role("Input"), st.role("Output")
    si, so = copy.deepcopy(ri["claim_sources"]), copy.deepcopy(ro["claim_sources"])
    ri["claim_sources"], ro["claim_sources"] = so, si
    try:
        swapped_int = block_integrity(bundle)
        swapped_shared = discover_shared_planes(bundle)
    finally:
        ri["claim_sources"], ro["claim_sources"] = si, so
    honest_int = block_integrity(bundle)
    out["C4b_the_two_endpoints_claim_sources_swapped"] = {
        "what": "E-Input's claim attributed to slot 22 and E-Output's to "
        "slot 21",
        "mirrors": "C4 (a claim whose source stage is wrong)",
        "honest": {"integrity_ok": honest_int["ok"],
                   "discovery_findings": len(shared["findings"]),
                   "identified_row_pairs": len(shared["pairs"])},
        "perturbed": {"integrity_ok": swapped_int["ok"],
                      "integrity_findings": swapped_int["findings"][:4],
                      "discovery_findings": swapped_shared["findings"][:4],
                      "identified_row_pairs": len(swapped_shared["pairs"])},
        "why_it_fires": "both endpoints use the same reserved pair, so the "
        "pair check cannot see the swap -- the claim POINT can: slot 21's "
        "tau is not slot 22's, so the A claim and the endpoint claim are "
        "not one evaluation and the planes are not identified",
        "fires": (not swapped_int["ok"]) and bool(swapped_shared["findings"]),
    }

    # ------------------------------------------------------------- C5b
    if other_bundle is None:
        out["C5b_observations_swapped_between_the_two_bundles"] = {
            "skipped": "needs a second block bundle of the same shape (--other)",
            "fires": False,
        }
    else:
        saved = bundle.stages[0]
        bundle.stages[0] = BlockStage(other_bundle.stages[0].path,
                                      store=other_bundle.store, refusals=[])
        try:
            sw_replay = BlockReplay(bundle).run().summary()
            sw_int = block_integrity(bundle)
        finally:
            bundle.stages[0] = saved
        out["C5b_observations_swapped_between_the_two_bundles"] = {
            "what": f"{bundle.name}'s observations.json replaced by "
            f"{other_bundle.name}'s (the same shape, another proof)",
            "mirrors": "C5 (a stage file swapped between two bundles)",
            "honest": {"replay_ok": replay.summary()["ok"],
                       "challenges_checked": replay.summary()["challenges_checked"]},
            "perturbed": {"replay_ok": sw_replay["ok"],
                          "first_failure": (sw_replay["failures"] or ["<none>"])[0],
                          "failures": len(sw_replay["failures"]),
                          "integrity_ok": sw_int["ok"],
                          "integrity_first_finding": (sw_int["findings"] or ["<none>"])[0]},
            "fires": (not sw_replay["ok"]) and (not sw_int["ok"]),
        }

    # -------------------------------------------------------------- C6
    hview = views["H@0"]
    d = hview.facts["distinct_columns"]
    tight = RunRoleView(st, st.role("H"),
                        replay.stages[0]["role_prox_rhos"]["H@0"], bundle.shape,
                        q_pad=d - 1, name="H@0")
    tf = tight.run(replay.stages[0]["role_lambdas"]["H@0"])
    out["C6_one_pad_fewer_than_the_distinct_opened_columns"] = {
        "what": f"H@0's pad budget set to {d - 1} against {d} distinct opened "
        "columns",
        "mirrors": "C6, unchanged",
        "honest": {"H-pad": hview.facts["reduction_hypotheses"]["H-pad"],
                   "distinct_columns": d,
                   "pad_count": hview.facts["pad_count"]},
        "perturbed": {"H-pad": tf["reduction_hypotheses"]["H-pad"],
                      "findings": tf["findings"][:2]},
        "fires": not tf["reduction_hypotheses"]["H-pad"],
    }

    names = list(out)
    out["not_applicable"] = not_applicable
    out["all_fire"] = all(out[n]["fires"] for n in names)
    out["controls"] = names
    out["ok"] = out["all_fire"]
    return out


# ---------------------------------------------------------------------------
# 6.  THE FOUR RUN-ONLY CHANNELS, FOR A BLOCK (stage 7)
# ---------------------------------------------------------------------------
RUN_ONLY_CHANNELS = (
    "the sequencing surface: the number of segments, their byte lengths and "
    "their position tags",
    "the cross-block joint law beyond the linear rank",
    "the preimage construction for a RUN (one randomness reproducing the "
    "whole run's view under a fixed input)",
    "the boundary scale tags and the one calibration identity",
)
BOUNDARY_WORDS = {
    "opening-group and proximity vectors, message half (the internal "
    "boundaries and the two external endpoints)":
        "opening-group and proximity vectors, message half (the two external "
        "endpoints)",
    "claim values (the internal boundaries and the two external endpoints)":
        "claim values (the two external endpoints)",
    "the Merkle roots (A, H, M per stage, the L-1 boundary roots, the two "
    "endpoint roots)":
        "the Merkle roots (A, H, M and the two endpoint roots)",
}


def block_channel_table(ch, bundle, record) -> list:
    """The run's channel list re-worded for a standalone block: the three
    channels that name a boundary lose the word, and each of the four
    run-only channels is replaced, IN ITS POSITION, by its block
    counterpart.  Every other channel -- and every figure a channel carries
    -- is the run table's own entry, unchanged."""
    s1 = record["stage1_integrity"]
    s2 = record["stage2_transcript_replay"]
    s13 = record.get("stage13_joint_run_preimage") or {}
    joint_ok = bool(s13.get("requested") and s13.get("ok")
                    and s13.get("entries_differing") == 0)
    pol = s1.get("endpoint_policy", {})
    rec = s1.get("receipt", {})
    out = []
    for c in ch:
        name = c["channel"]
        if name in BOUNDARY_WORDS:
            c = dict(c)
            c["channel"] = BOUNDARY_WORDS[name]
            out.append(c)
            continue
        if name == RUN_ONLY_CHANNELS[0]:
            out.append({
                "channel": "the receipt frame: its one length and its 40-byte "
                "envelope",
                "section": "block (replaces the run's sequencing surface)",
                "status": "argued",
                "assumption": "shape facts",
                "preimage_exhibited": None,
                "model_assumption": "a standalone block's receipt is ONE frame, "
                "with no segment and no position tag.  Its length is the "
                "shape's counted receipt length, a function of the shape and "
                "not of the witness -- EVIDENCE, not proof: the dense and the "
                "all-zero bundles' frames have the same length.  Its 40-byte "
                "envelope is the magic HLPBLOK1 and block_binding "
                "(wire.rs:15, :145-146), compared by stage 1 with the binding "
                "stage 2 RECOMPUTES from the public header words, and outside "
                "the Fiat-Shamir chain",
                "frame_bytes": rec.get("bytes"),
                "envelope_is_the_magic_and_the_recomputed_binding":
                    bool(rec.get("envelope_is_the_magic_and_block_binding"))
                    and bool(s2.get("block_binding_reproduced")),
            })
        elif name == RUN_ONLY_CHANNELS[1]:
            out.append({
                "channel": "the joint law of the block's view beyond the linear "
                "rank",
                "section": "block (replaces the run's cross-block joint law)",
                "status": "open",
                "assumption": None,
                "preimage_exhibited": None,
                "reason": "what is computed here is a RANK of a linear model "
                "over the block's five commitments.  The joint LAW of one "
                "shaped block's view is Theorem B's per-stage part -- the toy "
                "theorem at a shaped layout -- written and accepted as a "
                "REDUCTION (joint-law composition disposition, 2026-09-20 "
                "17:58, section 1), conditional on G-R1, G-R2 and G-R4.  The "
                "draw accounting ruling R-3 asked for is machine-asserted on "
                "single-block proofs at six shapes (lane stage 36), not at "
                "125M",
                "ruling_R3": _ruling_r3(),
                "ruling_R3_as_of_2026_09_23": R3_STATUS_20260923,
            })
        elif name == RUN_ONLY_CHANNELS[2]:
            e = dict(c)
            e["channel"] = ("the preimage construction for the BLOCK (one "
                            "randomness reproducing the whole block's view "
                            "under a fixed input)")
            e["section"] = "block (replaces the run's preimage for a RUN)"
            if joint_ok:
                e["how"] = (
                    "the product of round 7's per-commitment blinding and "
                    "round 8's mask coefficients and M blinding, over a data "
                    "block that is zero in EVERY commitment.  It is joint "
                    "because the only coordinates two commitments of a block "
                    "share are the two external endpoints' DATA planes, each "
                    "also A@0's IO plane, checked row by row to be data rows "
                    "on both sides and zero on both sides")
            out.append(e)
        elif name == RUN_ONLY_CHANNELS[3]:
            out.append({
                "channel": "the endpoint scales and the one calibration identity",
                "section": "block (replaces the run's boundary scale tags)",
                "status": "argued",
                "assumption": "D12 item 5 as pinned: IoSpec::new and ruling "
                "CS-8 refuse any endpoint scale pair but ENDPOINT_SCALES",
                "preimage_exhibited": None,
                "model_assumption": "a standalone block has no boundary and "
                "no interior scale.  Its two endpoint scales are words of the "
                "endpoint policy, a CONSTANT of the approved calibration "
                "(private_block.rs:371, ENDPOINT_SCALES = (0, 0); IoSpec::new "
                "refuses any other pair and ruling CS-8 re-checks it at every "
                "entry), so they carry nothing about the hidden input.  What "
                "the gate COMPUTES: the policy bytes the header absorbs "
                "(expected-IO) are parsed and carry exactly the declared "
                "context, scales and roots, the scales are the approved "
                "pair, and the ONE calibration identity is absorbed -- the "
                "header binding reproduces over it",
                "endpoint_scales": pol.get("scales"),
                "scales_are_the_approved_calibrations":
                    pol.get("scales_are_the_approved_calibrations"),
                "one_calibration_identity": bool(s2.get("block_binding_reproduced")),
            })
        elif name == REFUSAL_CHANNEL:
            e = dict(c)
            e.pop("corrected", None)
            e["reason"] = (
                "the refusal channel is inside the game (ruling C-2); a "
                "capture exists only when the block was accepted.  Its "
                "ENTROPY side is three fail-closed operating-system reads per "
                "proof: the block prover's one generator in prove_inner_at "
                "('ONE OS stream per attempt; entropy failure aborts before "
                "anything public exists', seeded from "
                "hash_domain::single_block_seed_domain) and one in each of the "
                "two endpoint owners (endpoint_g.rs:269) -- lane stage 36's "
                "clarification 5, asserted as a source fact, and J-2.  A "
                "lookup miss is ONE named refusal before the first commitment "
                "(ruling CS-3), whose text names only the table family")
            out.append(e)
        elif name == TIMING_CHANNEL:
            e = dict(c)
            e["reason"] = (
                "declared out of scope for the first MVP (M-5, ruling C-2).  "
                "A block's prover and verifier have their own wall clock and "
                "high-water mark; no field of the capture bears on it")
            out.append(e)
        else:
            out.append(c)
    return out


REFUSAL_CHANNEL = "whether a proof attempt produced a receipt (refusal events)"
TIMING_CHANNEL = "timing, memory, power"


# Ruling R-3's own text (`zk60_native_rg_joint.RULING_R3`) is a quote of the
# ruling as written on 2026-09-20 and is kept verbatim wherever a record
# carries it.  Its instruction -- "is to be machine-asserted elsewhere" -- has
# since been carried out for single blocks; this is that status, dated, for
# the channels that used to append the quote as their reason (status page
# row 28).
R3_STATUS_20260923 = (
    "2026-09-23 (round 9j): the draw-accounting test ruling R-3 asked for "
    "EXISTS -- lane stage 36, the seven assertions of "
    "ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES.md section 3.1, MEASURED on "
    "single-block proofs at six shapes (toy, rung-K4, rung-P2, rung-C6, "
    "rung-W14, rung-E32).  Not at 125M, where the per-block draw total is a "
    "count, and not at run scope (J-5's widened assertion 2 over 11L + "
    "3(L-1) segments is unmeasured).  `joint == sum` in this gate remains a "
    "consistency check of the model, as the ruling says"
)


def _ruling_r3():
    from zk60_native_rg_joint import RULING_R3
    return RULING_R3
