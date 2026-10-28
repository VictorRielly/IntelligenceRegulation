"""The three Rust files on the PRIVATE ATTENTION profile's path that no pin
table named: pinned by digest, at the integrator's `4751b93`.

WHY THIS FILE EXISTS (round 9g, `ZK60_NATIVE_RUN_GATE_PROGRESS.md` §R9g.8,
2026-09-22).  Condition 7 of the toy profile's accepted privacy statement
(register D22) says: *every Rust file the prover and the verifier reach is
pinned, and a change to any of them suspends step 3 until the file is re-read
and re-pinned.*  Round 5 widened the pin set to every file on the toy BLOCK
profile's path.  Round 9g read the tables out and found the attention
profile's own root and two of its modules in none of them:

    hashline/src/private_attention.rs
    hashline/src/private_attention/wire.rs
    hashline/src/private_attention/witness.rs

-- not in `zk60_native_mask_commit.SOURCE_PINS`, not in its `PATH_PINS`, not
in `zk60_native_terminal_polys.SOURCE_PINS`, not in any `zk60_native_rg_*`
table, and not in the Rust capture writer's 38-file list.  **Two of the four
toy captures of record are attention-profile receipts**
(`hashline-zk-mr1/private-attention-t32-poc/1`), so for those two the gates
read artifacts whose prover and verifier reach three files nothing compares:
a change to any of them would trip no gate.  The security owner ruled on
2026-09-22 that the three join the pin set; this module is that pin.

THAT THEY ARE ON THE PATH, at `4751b93`, by call site rather than by belief:

  * `hashline/src/private_attention.rs` is the profile's ROOT.
    `hashline/src/lib.rs:49` declares `pub mod private_attention;` with no
    `cfg` and no feature gate; the file declares `mod wire;` (line 45) and
    `mod witness;` (line 46) OUTSIDE any `cfg` -- `#[cfg(test)] mod tests;`
    is the line after them -- and holds the public statement type
    `AttentionPublic`, `IoSpec` / `prepare_endpoints` / `ExpectedIo`,
    `compute_output` (236), `prove` / `prove_with_stats` (270 / 274),
    `verify` (285), `verify_bytes` (311) and `Receipt::{to_bytes,
    from_bytes}` (298 / 303).  Every attention proof and every attention
    verification enters here.
  * `private_attention/witness.rs` is the PROVER's integer witness:
    `witness::build` is called at `private_attention.rs:277` inside
    `prove_with_stats` and at `:236` inside `compute_output`, and its
    `Witness` is the argument of `protocol::prove_inner`
    (`protocol.rs:12`, `:259`), which `lookup_values` (203) and
    `exp_deltas` (211) read.
  * `private_attention/wire.rs` is on BOTH sides: `wire::validate` is the
    first statement of `protocol::verify_inner` (`protocol.rs:419`), and
    `wire::encode` / `wire::decode` are what `Receipt::to_bytes` /
    `from_bytes` are (`private_attention.rs:298` / `:303`), so
    `verify_bytes` (311) decodes through it.  `encoded_len` (291) and the
    re-export `pub use wire::MAX_WIRE_BYTES` (60) are the same file.

None of the three is `#[cfg(test)]`, so none is excluded by the rule that
kept `private_block/{norm_alias,parity,refusals,tamper,tests}.rs` out.  The
attention profile's other three files -- `argument.rs`, `layout.rs`,
`protocol.rs` -- were already pinned (`zk60_native_terminal_polys.SOURCE_PINS`
pins all three; `zk60_native_mask_commit.SOURCE_PINS` pins `argument.rs`
again, at the same digest), so with this module the profile's six files are
complete.

WHY IT IS A SEPARATE FILE, and not two more tables elsewhere.  Round 9f's
reason, unchanged: `zk60_native_mask_commit.py` -- where the Rust path pins
live -- is named by **122** committed records' `tool_sha256` maps, the whole
RUN-gate series over the real 125M bundles, each asserted equal to the tool
bytes in the tree by its own test, so one byte changed there would stale
~115 records and demand their re-take on bundles this round has no business
re-running (`zk60_native_terminal_polys.py`: 8 records plus its own
`port_sha256`).  A new module confines the re-pin to the three records the
two toy gates write.  It is NOT folded into `zk60_native_manifest_pins.py`
either, although that module has the same shape and the same caller: that
file is about the two CARGO MANIFESTS and finding P36-2, its error type and
its refusal line say "Cargo manifest pins", and Rust source pins filed under
a name that says "manifest" would mislead the next reader at the moment they
most need to know which kind of pin refused.  The record guard
(`tests/test_zk60_native_gate_record.py`) holds the tables together: it fails
if one of the three is unpinned, if any Rust pin table ever names one at a
different digest, or if a gate stops calling this check.

IT IS UNCONDITIONAL, not gated on the capture's profile.  Both toy gates run
over a capture DIRECTORY, and the directory of record holds all four captures
-- two block receipts and two attention ones -- so a per-profile branch would
never be taken differently in any run of record.  And for a block run these
three are simply files that must not have moved either: they are inside the
same source tree the manifest cross-check compares a bundle against (the
delivered bundle's `source_hashes` carries all three, at exactly the digests
below).  One rule, no branch, nothing to get wrong.

WHAT IS CHECKED: the digest, and only the digest.  Round 9f's manifests also
carry a CONTENT assertion because a Cargo manifest can be re-pinned blind and
still ship a test-only feature -- the property there is a fact about the
file's meaning.  The property here is the one the pin set is for: *these are
the bytes the four captures of record were produced and verified by*, and a
sha256 is exactly that property.  A future reader who re-pins without reading
the diff is the same hazard every other Rust pin has, and the same answer
applies: the refusal below says to read the diff and write the reading in the
ledger first.

Run it directly to see what it reads:

    python3 scripts/zk60_native_profile_pins.py [--root <tree>]
"""

from __future__ import annotations

import collections
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)


class ProfilePinError(RuntimeError):
    """A pinned file on the private-attention profile's path changed.

    Raised with a message that NAMES the file, because that is what condition
    7 of the toy profile's accepted privacy statement (register D22) asks of
    the gate.
    """


Pin = collections.namedtuple("Pin", "path sha256 blob why")

# The pins of record, read from the integrator's main branch at commit
# `4751b93` (`perf/zk-batch-optimizations`) -- the commit the rest of the D22
# pin set is read at:
#
#   git --no-pager -C <main tree> show 4751b93:<path> | sha256sum
#   git --no-pager -C <main tree> rev-parse 4751b93:<path>
#
# The same bytes are in this lane's worktree, in the block lane's tip
# `a8e4939` (see `LANE_DIGESTS` below: all three identical, so unlike the two
# Cargo manifests there is nothing here for the integrator's re-pin to move),
# and in the delivered new-tree bundle's `source_hashes`
# (`results/zk60_native_d22_replay_20260922/bundle/validation.json`, 132
# entries, all three present at these digests).
PROFILE_PINS = (
    Pin(
        "hashline/src/private_attention.rs",
        "dfc02d91356974b0cf4c6c0c672ec14660aa4b90b808236de81486272f010923",
        "1bc8f8911f91ff66709f8186393774e3845ad3d7",
        "REAL LOGIC, and the attention profile's own root: PROFILE, the "
        "public statement (AttentionPublic and its refusals), IoSpec / "
        "ExpectedIo / prepare_endpoints and the by-value Endpoints, "
        "compute_output, prove / prove_with_stats, verify, verify_bytes, "
        "Receipt::{to_bytes, from_bytes} and encoded_len. It also DECLARES "
        "`mod wire;` and `mod witness;` outside any cfg (lines 45-46), so it "
        "is the file a reader checks to know those two are not test-only",
    ),
    Pin(
        "hashline/src/private_attention/wire.rs",
        "a35a468cf19eb672e5428c3286a3ece15f73e96e20291a220cf38dd4104dbdff",
        "26e2166984b7164743683b0a2fb34cf3d732644f",
        "the frame, on BOTH sides: `validate` is the first statement of "
        "protocol::verify_inner (protocol.rs:419) and decides the receipt's "
        "shape, hiding widths and group counts before anything is read; "
        "`encode` / `decode` are Receipt::to_bytes / from_bytes, so "
        "verify_bytes decodes through this file; HEADER and encoded_len fix "
        "the frame length the toy captures' proof_bytes are measured against",
    ),
    Pin(
        "hashline/src/private_attention/witness.rs",
        "795cf6292e366bc48d1c1987b9a3173f9a19e266de537f72a9e738bdb5133ee0",
        "0c9f7b60847e913ef81034bea7f62ed72db050e6",
        "the PROVER's integer witness: `build` (called at "
        "private_attention.rs:277 in prove_with_stats and :236 in "
        "compute_output) computes every hidden plane the proof commits to -- "
        "quantize / requant / matmul / rotate / isqrt / limbs -- and the "
        "Witness it returns is what protocol::prove_inner, lookup_values and "
        "exp_deltas read",
    ),
)

# A second accepted digest per path, same discipline as
# `zk60_native_mask_commit.ALSO_ACCEPTED` and
# `zk60_native_manifest_pins.ALSO_ACCEPTED`: only ever widened after the
# changed file has been READ, with the reading written down in the ledger.
# Empty today, and there is nothing pending -- see `LANE_DIGESTS`.
ALSO_ACCEPTED: dict = {}

# RECORDED, for the integrator.  The block lane (`zk60-attention-compile`,
# tip `a8e4939`, the tree the stage-36 delta was written in) carries these
# three files BYTE-IDENTICAL to main at `4751b93`.  Round 9f had to record
# `EXPECTED_AFTER_INTEGRATION` digests for the two Cargo manifests because
# the lane had changed them; here there is no such move to expect, and the
# guard asserts the equality rather than leaving it as prose.
LANE_DIGESTS = {
    "commit": "a8e4939 (lane zk60-attention-compile, 2026-09-22)",
    "identical_to_main": True,
    "digests": {
        "hashline/src/private_attention.rs":
            "dfc02d91356974b0cf4c6c0c672ec14660aa4b90b808236de81486272f010923",
        "hashline/src/private_attention/wire.rs":
            "a35a468cf19eb672e5428c3286a3ece15f73e96e20291a220cf38dd4104dbdff",
        "hashline/src/private_attention/witness.rs":
            "795cf6292e366bc48d1c1987b9a3173f9a19e266de537f72a9e738bdb5133ee0",
    },
    "note": "the stage-36 delta touched the two Cargo manifests, "
    "`zkp-core/src/{rng,transcript}.rs` and the block profile's tests; it "
    "does not touch the attention profile's files, so these three pins are "
    "expected to survive the integration unchanged. If they do not, the "
    "refusal below is the intended behaviour: read the diff first.",
}

# Where the profile's OTHER three files are pinned, so that "the six are
# complete" can be checked rather than asserted.  The digests are not
# duplicated here -- duplicating them is how two tables come to disagree --
# and the record guard reads the tables themselves.
ALREADY_PINNED_ELSEWHERE = {
    "hashline/src/private_attention/argument.rs":
        "zk60_native_terminal_polys.SOURCE_PINS and "
        "zk60_native_mask_commit.SOURCE_PINS (the declared functional order "
        "of the profile's 18 slots)",
    "hashline/src/private_attention/layout.rs":
        "zk60_native_terminal_polys.SOURCE_PINS (the slot geometry the "
        "joint-view port transcribes)",
    "hashline/src/private_attention/protocol.rs":
        "zk60_native_terminal_polys.SOURCE_PINS (the transcript order and "
        "the opening checks)",
}


def _blob_id(raw: bytes) -> str:
    return hashlib.sha1(b"blob %d\0" % len(raw) + raw).hexdigest()


def check_profile_pins(root: str | None = None, pins=PROFILE_PINS,
                       also=None) -> dict:
    """HARD ERROR if a pinned private-attention file moved.

    The toy gate's two entry points call this before any analysis and exit 3
    on the refusal, writing no record.  It is deliberately the same shape as
    `zk60_native_mask_commit.check_source_pins`: a digest, a git blob id, and
    a message that names the file and says what it is.
    """
    root = root or REPO_ROOT
    also = ALSO_ACCEPTED if also is None else also
    out = {}
    for pin in pins:
        path = os.path.join(root, pin.path)
        if not os.path.exists(path):
            raise ProfilePinError(
                f"profile pin: {pin.path} is missing under {root}. It is on "
                "the PRIVATE ATTENTION profile's proving and verifying path "
                "(round 9h, ledger §R9h), and two of the four toy captures of "
                "record are attention receipts; the gate does not run without "
                "it."
            )
        with open(path, "rb") as fh:
            raw = fh.read()
        got = hashlib.sha256(raw).hexdigest()
        blob = _blob_id(raw)
        second = also.get(pin.path, {})
        if got != pin.sha256 and got not in second:
            raise ProfilePinError(
                f"profile pin MISMATCH for {pin.path}:\n"
                f"  pinned sha256 {pin.sha256} (git blob {pin.blob})\n"
                + "".join(
                    f"  also accepted {d} (git blob {b}) -- {w}\n"
                    for d, (b, w) in second.items()
                )
                + f"  found  sha256 {got} (git blob {blob})\n"
                + f"  what it is: {pin.why}\n"
                "This file is ON THE PRIVATE ATTENTION PROFILE'S PATH and two "
                "of the four toy captures of record are attention receipts "
                "(round 9h). Condition 7 of the toy profile's privacy "
                "statement (register D22) SUSPENDS step 3 until the file is "
                "re-read and re-pinned: read the diff, write the one-line "
                "reading in the ledger, and only then add the digest. Do NOT "
                "re-pin to make this pass."
            )
        rec = {
            "sha256": got,
            "git_blob": blob,
            "pin_kind": "on-the-attention-path",
            "what_it_is": pin.why,
        }
        if got != pin.sha256:
            rec["accepted_as"] = second[got][1]
            rec["pin_of_record"] = pin.sha256
        out[pin.path] = rec
    return out


def main(argv=None) -> int:
    import argparse
    import json

    ap = argparse.ArgumentParser(
        description="the private-attention profile's three path pins")
    ap.add_argument("--root", default=REPO_ROOT)
    args = ap.parse_args(argv)
    try:
        out = check_profile_pins(root=args.root)
    except ProfilePinError as exc:
        print(f"REFUSED (attention profile pins): {exc}", file=sys.stderr)
        return 3
    print(json.dumps(out, indent=1, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
