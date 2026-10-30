"""The two Cargo manifests that decide whether a test-only feature can reach
a release build: pinned by digest AND asserted by content.

WHY THIS FILE EXISTS (finding P36-2, `ZK60_D22_CONDITION7_PREREAD_STAGE36.md`
section 7, 2026-09-22).  The stage-36 delta on the block lane adds a
test-only feature to `zkp-core/Cargo.toml`:

    [features]
    test-observers = []          # read-only accessors: ZkRng::consumed_bytes,
                                 # ZkRng::refills, Transcript::squeezes

and enables it from ONE place, `hashline/Cargo.toml`'s `[dev-dependencies]`:

    zkp-core = { path = "../zkp-core", features = ["test-observers"] }

After that delta the answer to "can a release build compile those accessors?"
is decided by those two files and by nothing else -- a one-word edit, `default
= ["test-observers"]` in the first, or that line moved into `[dependencies]`
in the second, puts the accessors into the production library with EVERY Rust
source, every `cfg` gate and every existing pin unchanged.  The pre-read found
that neither manifest was pinned by anything: not by
`zk60_native_mask_commit.SOURCE_PINS` / `PATH_PINS`, not by
`zk60_native_terminal_polys.SOURCE_PINS`, not by the Rust capture writer's
38-file list.  This module is that pin, and the toy gate's two entry points
(`zk60_native_privacy_gate.py`, `zk60_native_joint_view.py`) call it before
they analyse anything.

**Nothing here establishes a privacy property and nothing here is a privacy
acceptance.**  It is the same bookkeeping as every other pin on this lane: the
gate refuses to run, naming the file, when the bytes it was reasoned about
have moved.

WHY IT IS A SEPARATE FILE rather than two more rows in
`zk60_native_mask_commit.PATH_PINS`, which is where the Rust path pins live
(round 5, the security owner's ruling of 2026-09-20 22:06).  `mask_commit.py`
is named by 122 committed records' `tool_sha256` maps -- the whole RUN-gate
series over the real 125M bundles, not only the toy gate's three records --
and every one of those records is asserted equal to the tool bytes now in the
tree by its own test.  Changing one byte of `mask_commit.py` would therefore
turn ~115 records of the run gate stale and demand their re-take on bundles
this round has no business re-running.  The same is true of
`terminal_polys.py` (8 records, plus its own `port_sha256`).  Keeping the new
table here confines the re-pin to the three records of record the two gates
write, which is exactly the set round 9e re-took.  The two tables are held
together by the record guard (`tests/test_zk60_native_gate_record.py`), which
fails if a manifest is pinned in neither place or at disagreeing digests.

WHAT IS CHECKED, in order, for each manifest:

  1. THE DIGEST.  sha256 and git blob id against the pin of record, read from
     the integrator's main branch at `4751b93` -- the same commit the whole
     D22 pin set is read at.  A file outside the accepted set is a
     `ManifestPinError` NAMING THE FILE.

  2. THE CONTENT, whatever the digest said.  A digest alone would be silent
     the day somebody re-pins it without reading the file; these assertions
     are about the one property the pin exists for, so they refuse a manifest
     that ships the observers BY NAME even at an accepted digest:

       * `zkp-core/Cargo.toml`: `[features]`'s `default` must be absent or
         empty -- no feature at all may be on by default -- and the token
         `test-observers` may not appear in `[dependencies]`,
         `[build-dependencies]` or any `[target.*.dependencies]` section;
       * `hashline/Cargo.toml`: the token `test-observers` may appear ONLY
         inside a dev-dependency section (`[dev-dependencies]` or
         `[target.*.dev-dependencies]`).  Anywhere else -- `[dependencies]`,
         `[features]`, `[build-dependencies]`, `[package]` -- is a refusal.

     Python 3.10 on this box has no `tomllib` (3.11+) and no `tomli`/`toml`
     package, so the manifests are read by the small quote-aware section
     scanner below rather than by a TOML library.  It is deliberately strict:
     anything it cannot parse is a refusal, never a pass, and its own
     behaviour is tested (`tests/test_zk60_native_gate_record.py`).

WHAT IS NOT CHECKED HERE.  Cargo's feature RESOLVER version (pre-read finding
P36-3): under resolver v1 a dev-dependency's features unify into the normal
graph and the accessors would ship with both manifests otherwise unchanged.
The lane answers it in the manifests themselves (`resolver = "2"` written
explicitly under `[package]` at `a8e4939`), and the digest pin below covers
it: a manifest that dropped or lowered that key would not match its pin.  No
assertion is made on the key's VALUE, because at `4751b93` there is no such
key to assert and inventing one would refuse legitimate future manifests.

Run it directly to see what it reads:

    python3 scripts/zk60_native_manifest_pins.py [--root <tree>]
"""

from __future__ import annotations

import collections
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)


class ManifestPinError(RuntimeError):
    """A pinned Cargo manifest changed, or ships the test-only observers.

    Raised with a message that NAMES the file and says which of the two
    reasons it is, because that is what condition 7 of the toy profile's
    accepted privacy statement (register D22) asks of the gate.
    """


Pin = collections.namedtuple("Pin", "path sha256 blob why")

# The pins of record, read from the integrator's main branch at commit
# `4751b93` (`perf/zk-batch-optimizations`, "Integrate validated direct-plane
# uploads and private host reuse") -- the commit the rest of the D22 pin set
# is read at, and the bytes this lane's worktree also carries for both files.
#
#   git --no-pager -C <main tree> show 4751b93:zkp-core/Cargo.toml | sha256sum
#   git --no-pager -C <main tree> show 4751b93:hashline/Cargo.toml | sha256sum
#
# At these bytes the feature does not exist at all: `zkp-core/Cargo.toml` has
# no `[features]` table and `hashline/Cargo.toml` mentions no such feature.
# That is the state the four captures of 2026-09-19 were produced in.
MANIFEST_PINS = (
    Pin(
        "zkp-core/Cargo.toml",
        "b9038a52f34e0ee8313aa93eec656ff62ea29571a04b3df7f3db349d623ba842",
        "e3d46e4e2d52eda49a3ae10611345b538384f090",
        "finding P36-2: the crate's `[features]` table is where a "
        "`test-observers`-style feature would be declared and where `default` "
        "would switch it on for every build, including a release one. At "
        "4751b93 there is no `[features]` table at all",
    ),
    Pin(
        "hashline/Cargo.toml",
        "eaba50ecf1434ad8514feb83c6e610b0d662b8fd6d512f26bacdde69163b860a",
        "8a670755028ecc1c8d20086530cd9aa5d1d733fc",
        "finding P36-2: this is the ONLY place that enables a zkp-core "
        "feature, and whether it does so from `[dev-dependencies]` (test "
        "targets only) or from `[dependencies]` (the library and the binary) "
        "is the whole of the production-identity claim. At 4751b93 it enables "
        "no feature of zkp-core at all",
    ),
)

# A second accepted digest per path, same discipline as
# `zk60_native_mask_commit.ALSO_ACCEPTED`: only ever widened after the changed
# file has been READ, with the reading written down.  Empty today.
ALSO_ACCEPTED: dict = {}

# RECORDED, DELIBERATELY NOT ACCEPTED.  The block lane (`zk60-attention-
# compile`, tip `a8e4939`) already carries the stage-36 manifests, and they
# are the bytes the pins will move to WHEN THE INTEGRATOR MERGES -- at a
# re-pin of its own, against the integrator's tree, after those bytes have
# been read there.  They are written here so the next reader does not have to
# find them again, and so that a tree carrying them is refused TODAY with a
# message that says exactly what it is looking at.
EXPECTED_AFTER_INTEGRATION = {
    "zkp-core/Cargo.toml": {
        "sha256": "0c746b9d7dc46b0866638a6ea9cfc8932e3cf7d594dc97a77f2bff3130ea0d56",
        "git_blob": "a072befa17d15f1b9fbcb0dc58a0f6c583be5e43",
        "commit": "a8e4939 (lane zk60-attention-compile, 2026-09-22)",
        "what_it_adds": "the `[features]` table with `test-observers = []`, NOT "
        "in `default` and in no dependency, plus an explicit `resolver = \"2\"` "
        "under `[package]` (pre-read finding P36-3)",
        "would_the_content_assertion_accept_it": True,
    },
    "hashline/Cargo.toml": {
        "sha256": "10d99a63f465900ad6cad29f547a6d396b66c7a59320e0f8cb60ad3b3b721acf",
        "git_blob": "628f863e09933ebe6d427942f7bfff561a1a2a54",
        "commit": "a8e4939 (lane zk60-attention-compile, 2026-09-22)",
        "what_it_adds": "a second `zkp-core` entry in `[dev-dependencies]` with "
        "`features = [\"test-observers\"]`, the explicit `resolver = \"2\"`, and "
        "the `private-block-kernel-shaped` test-only path dependency",
        "would_the_content_assertion_accept_it": True,
    },
    "note": "the lane's own base (`fee1a8d`) already differs from main for "
    "`hashline/Cargo.toml`, and the stage-36 pre-read quotes a third pair of "
    "digests (90156d58… / 5633d1e4…) taken in the REVIEW worktree before "
    "P36-3 added the resolver line. Neither pair is accepted here: the pin "
    "moves once, against the integrator's merged tree.",
}

# The content assertion, as data.  `feature` is the token the toy profile's
# production-identity claim turns on; `allowed_sections` are the section kinds
# it may legitimately appear in; `default_must_be_empty` is the second rule,
# and it is asserted for zkp-core only -- hashline's `default` is its own
# business (it has none today, and a future `default = ["gpu-cuda"]` would be
# a legitimate change this gate has no business refusing).
Policy = collections.namedtuple(
    "Policy", "feature allowed_sections default_must_be_empty why")

MANIFEST_POLICY = {
    "zkp-core/Cargo.toml": Policy(
        feature="test-observers",
        allowed_sections=("features",),
        default_must_be_empty=True,
        why="the feature may be DECLARED here and nothing more: a `default` "
        "that switches any feature on, or the token inside a normal "
        "dependency section, would compile the observers into every build",
    ),
    "hashline/Cargo.toml": Policy(
        feature="test-observers",
        allowed_sections=("dev-dependencies",),
        default_must_be_empty=False,
        why="a dev-dependency reaches TEST targets only, so the feature may be "
        "enabled there and nowhere else; `cargo build --release` does not read "
        "that section",
    ),
}


# --------------------------------------------------------- a TOML scanner
# Small, quote-aware and strict.  It answers exactly two questions -- which
# section a line is in, and what the `default` key of `[features]` holds --
# and refuses anything it cannot read rather than guessing.
def _strip_comment(line: str) -> str:
    """Drop a `#` comment, honouring basic and literal strings.

    TOML's comment character is `#` unless it is inside a string; the
    manifests here carry both (`features = ["alloc"]  # note`).  A quote left
    open at the end of the line is a parse failure, not a pass.
    """
    out = []
    quote = None
    i = 0
    while i < len(line):
        ch = line[i]
        if quote is not None:
            out.append(ch)
            if ch == "\\" and quote == '"' and i + 1 < len(line):
                out.append(line[i + 1])
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
            out.append(ch)
        elif ch == "#":
            break
        else:
            out.append(ch)
        i += 1
    if quote is not None:
        raise ValueError(f"unterminated {quote} string: {line.strip()!r}")
    return "".join(out)


def _split_section_name(name: str):
    """`target.'cfg(unix)'.dev-dependencies` -> ['target', ..., 'dev-dependencies'].

    Dots inside quotes do not split; that is the only subtlety a Cargo
    section header has.
    """
    parts, cur, quote = [], [], None
    for ch in name:
        if quote is not None:
            if ch == quote:
                quote = None
            else:
                cur.append(ch)
        elif ch in "\"'":
            quote = ch
        elif ch == ".":
            parts.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    if quote is not None:
        raise ValueError(f"unterminated quote in section header [{name}]")
    parts.append("".join(cur).strip())
    return [p for p in parts if p != ""]


def section_kind(name: str) -> str:
    """The last component of a section header: what KIND of table it is.

    `[dependencies]`, `[target.'cfg(unix)'.dependencies]` and
    `[workspace.dependencies]` are all `dependencies`; `[dev-dependencies]`
    and `[target.….dev-dependencies]` are `dev-dependencies`.  The empty
    string is the implicit top-level table above the first header.
    """
    parts = _split_section_name(name)
    return parts[-1] if parts else ""


Entry = collections.namedtuple("Entry", "section kind key value line")


def read_manifest(text: str):
    """[(section, kind, key, value, line)] for every key of every table.

    Values that span lines (arrays, inline tables) are joined into one
    string; nothing is interpreted beyond that, because the two questions
    this module asks are answered by the section a key sits in and by the
    literal text of one array.  Anything unparsable raises `ValueError`, and
    the caller turns that into a refusal naming the file.
    """
    entries = []
    section = ""
    pending = None  # (key, text, first line, bracket depth)
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = _strip_comment(raw).strip()
        if not line:
            continue
        if pending is not None:
            key, acc, first, depth = pending
            acc = acc + " " + line
            depth += (line.count("[") + line.count("{")
                      - line.count("]") - line.count("}"))
            if depth <= 0:
                entries.append(Entry(section, section_kind(section), key,
                                     " ".join(acc.split()), first))
                pending = None
            else:
                pending = (key, acc, first, depth)
            continue
        if line.startswith("["):
            if not line.endswith("]"):
                raise ValueError(f"line {lineno}: unreadable section header "
                                 f"{line!r}")
            name = line.strip("[]").strip()
            if not name:
                raise ValueError(f"line {lineno}: empty section header")
            section = name
            continue
        if "=" not in line:
            raise ValueError(f"line {lineno}: neither a header nor a key "
                             f"({line!r})")
        key, value = line.split("=", 1)
        key = key.strip().strip("\"'")
        value = value.strip()
        depth = (value.count("[") + value.count("{")
                 - value.count("]") - value.count("}"))
        if depth > 0:
            pending = (key, value, lineno, depth)
        else:
            entries.append(Entry(section, section_kind(section), key,
                                 " ".join(value.split()), lineno))
    if pending is not None:
        raise ValueError(f"line {pending[2]}: value of {pending[0]!r} is never "
                         "closed")
    return entries


def _array_items(value: str):
    """The string items of a TOML array literal, `[]` -> []."""
    inner = value.strip()
    if not (inner.startswith("[") and inner.endswith("]")):
        raise ValueError(f"not an array: {value!r}")
    inner = inner[1:-1]
    items, cur, quote = [], [], None
    for ch in inner:
        if quote is not None:
            if ch == quote:
                quote = None
            else:
                cur.append(ch)
        elif ch in "\"'":
            quote = ch
        elif ch == ",":
            if "".join(cur).strip():
                items.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    if quote is not None:
        raise ValueError(f"unterminated quote in array {value!r}")
    if "".join(cur).strip():
        items.append("".join(cur).strip())
    return items


# ------------------------------------------------------ the two assertions
def assert_manifest_policy(rel_path: str, text: str, policy: Policy) -> dict:
    """The CONTENT assertion: refuse, by name, a manifest that ships the
    observers -- whatever its digest says.

    Returns a small record of what it read when the manifest passes.  Raises
    `ManifestPinError` naming the file, the section and the line when it does
    not, and also when the file cannot be parsed at all (a manifest this
    module cannot read is one it cannot vouch for).
    """
    try:
        entries = read_manifest(text)
    except ValueError as exc:
        raise ManifestPinError(
            f"manifest REFUSED: {rel_path} cannot be read as TOML by the "
            f"gate's own scanner -- {exc}. The gate does not pass a manifest "
            "it cannot read: fix the file, or teach the scanner and say so in "
            "the ledger."
        ) from None

    found = []
    for e in entries:
        if policy.feature in e.key or policy.feature in e.value:
            found.append(e)
    offending = [e for e in found if e.kind not in policy.allowed_sections]
    if offending:
        e = offending[0]
        raise ManifestPinError(
            f"manifest REFUSED: {rel_path} mentions the test-only feature "
            f"`{policy.feature}` in [{e.section}] (line {e.line}: "
            f"{e.key} = {e.value}).\n"
            f"  it may appear only in: "
            f"{', '.join('[' + s + ']' for s in policy.allowed_sections)}\n"
            f"  why this is a refusal: {policy.why}\n"
            "  finding P36-2 (ZK60_D22_CONDITION7_PREREAD_STAGE36.md section "
            "7): these two manifests decide whether the read-only test "
            "observers compile into a release build, and no Rust source, no "
            "`cfg` gate and no other pin would change if they did. Re-pinning "
            "the digest does NOT get past this check."
        )

    default = None
    for e in entries:
        if e.kind == "features" and e.key == "default":
            default = e
    if policy.default_must_be_empty and default is not None:
        try:
            items = _array_items(default.value)
        except ValueError as exc:
            raise ManifestPinError(
                f"manifest REFUSED: {rel_path}'s [{default.section}] `default` "
                f"is not an array this gate can read (line {default.line}: "
                f"{default.value}) -- {exc}"
            ) from None
        if items:
            raise ManifestPinError(
                f"manifest REFUSED: {rel_path} switches feature(s) on BY "
                f"DEFAULT -- [{default.section}] default = {default.value} "
                f"(line {default.line}).\n"
                "  a default feature is compiled into every build of this "
                "crate, including `cargo build --release` and including every "
                "dependent that does not ask for it.\n"
                f"  why this is a refusal: {policy.why}\n"
                "  finding P36-2: `default = [\"" + policy.feature + "\"]` is "
                "the one-word edit that would put the read-only test "
                "observers into the production library with every Rust source "
                "and every other pin unchanged."
            )

    return {
        "sections": len({e.section for e in entries}),
        "keys": len(entries),
        "features_default": ("absent" if default is None
                             else default.value),
        policy.feature: (
            "absent" if not found else
            "; ".join(f"[{e.section}] {e.key} (line {e.line})" for e in found)
        ),
        "verdict": "this manifest cannot put the test-only observers into a "
                   "release build",
    }


def _blob_id(raw: bytes) -> str:
    return hashlib.sha1(b"blob %d\0" % len(raw) + raw).hexdigest()


def check_manifest_pins(root: str | None = None, pins=MANIFEST_PINS,
                        also=None, policy=None) -> dict:
    """HARD ERROR if a pinned Cargo manifest moved, or ships the observers.

    Both checks run on every call, in this order: the digest first, so that a
    changed manifest is refused by the same rule as every Rust file on the
    path; then the content assertion on the same bytes, so that a manifest
    which SHIPS the test-only feature is refused BY NAME even at a digest
    somebody has re-pinned without reading it.

    The toy gate's two entry points call this before any analysis and exit 3
    on the refusal, writing no record.
    """
    root = root or REPO_ROOT
    also = ALSO_ACCEPTED if also is None else also
    policy = MANIFEST_POLICY if policy is None else policy
    out = {}
    for pin in pins:
        path = os.path.join(root, pin.path)
        if not os.path.exists(path):
            raise ManifestPinError(
                f"manifest pin: {pin.path} is missing under {root}. It decides "
                "whether the test-only observers can reach a release build "
                "(finding P36-2); the gate does not run without it."
            )
        with open(path, "rb") as fh:
            raw = fh.read()
        got = hashlib.sha256(raw).hexdigest()
        blob = _blob_id(raw)
        second = also.get(pin.path, {})
        if got != pin.sha256 and got not in second:
            expected = EXPECTED_AFTER_INTEGRATION.get(pin.path, {})
            recognised = ""
            if expected.get("sha256") == got:
                recognised = (
                    "  RECOGNISED: these are the bytes of "
                    f"{expected['commit']} -- {expected['what_it_adds']}. They "
                    "become the pin at the re-pin against the integrator's "
                    "merged tree, not before.\n"
                )
            raise ManifestPinError(
                f"manifest pin MISMATCH for {pin.path}:\n"
                f"  pinned sha256 {pin.sha256} (git blob {pin.blob})\n"
                + "".join(
                    f"  also accepted {d} (git blob {b}) -- {w}\n"
                    for d, (b, w) in second.items()
                )
                + f"  found  sha256 {got} (git blob {blob})\n"
                + recognised
                + f"  what it is: {pin.why}\n"
                "This manifest is pinned because it, and not any Rust source, "
                "decides whether the test-only observers compile into a "
                "release build (finding P36-2). Condition 7 of the toy "
                "profile's privacy statement (register D22) SUSPENDS step 3 "
                "until the file is re-read and re-pinned: read the diff, write "
                "the one-line reading in the ledger, and only then add the "
                "digest. Do NOT re-pin to make this pass."
            )
        rec = {
            "sha256": got,
            "git_blob": blob,
            "pin_kind": "cargo-manifest",
            "what_it_decides": pin.why,
        }
        if got != pin.sha256:
            rec["accepted_as"] = second[got][1]
            rec["pin_of_record"] = pin.sha256
        rec["content_assertion"] = assert_manifest_policy(
            pin.path, raw.decode("utf-8", "replace"), policy[pin.path])
        out[pin.path] = rec
    return out


def main(argv=None) -> int:
    import argparse
    import json

    ap = argparse.ArgumentParser(description="the two Cargo manifest pins")
    ap.add_argument("--root", default=REPO_ROOT)
    args = ap.parse_args(argv)
    try:
        out = check_manifest_pins(root=args.root)
    except ManifestPinError as exc:
        print(f"REFUSED (Cargo manifest pins): {exc}", file=sys.stderr)
        return 3
    print(json.dumps(out, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
