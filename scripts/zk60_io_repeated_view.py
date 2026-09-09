#!/usr/bin/env python3
"""Joint fixed-coefficient message model for two fresh proofs of one witness.

This extends O8's union of commitments, without changing the archived model.
A/W/endpoint DATA rows alias across proofs; randomness never aliases. H data
depends on each proof's beta/gamma/alpha and therefore stays proof-local.
No adaptive transcript, salted-Merkle, or whole-proof privacy claim follows.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path

import zk60_io_review_gate as gate
import zk60_opus_io_capture as O

ROOT = gate.ROOT
require = gate.require


def check_pair(captures):
    require(len(captures) == 2, "expected exactly two proofs")
    a, b = captures
    require(a.proof_sha256 != b.proof_sha256, "duplicate proof is not fresh evidence")
    require(a.privacy == b.privacy, "mixed privacy modes")
    for key in ("context", "input_scale", "output_scale"):
        require(a.expected_policy[key] == b.expected_policy[key], "different endpoint policy metadata")
    require(a.public_w == b.public_w, "different public weight policy")
    roots = [role.root for cap in captures for role in cap.roles]
    roots += [cap.mask["root"] for cap in captures]
    require(len(roots) == len(set(roots)), "reused private root outside fresh-owner model")


def model(captures, roles=None, share_data=True, ablate_first_input=False):
    """Return O8's unchanged JointModel plus the origin of every role/alias."""
    check_pair(captures)
    observations, origins, aliases = [], [], []
    for attempt, cap in enumerate(captures):
        for original in cap.roles:
            if roles is not None and original.role not in roles:
                continue
            obs = (O.ablate_endpoint_mask_pair(original)
                   if ablate_first_input and attempt == 0 and original.role == "Input"
                   else copy.copy(original))
            obs.role = f"{original.role}@{attempt}"
            observations.append(obs)
            origins.append((attempt, original))
        selected = {o.role for o in observations}
        for (left, a), (right, b) in O.ALIAS_PAIRS:
            if f"{left}@{attempt}" in selected and f"{right}@{attempt}" in selected:
                aliases.append(((f"{left}@{attempt}", a), (f"{right}@{attempt}", b)))
    if share_data:
        for first in observations:
            name, attempt = first.role.split("@")
            if attempt != "0" or name == "H":
                continue
            second = next(o for o in observations if o.role == name + "@1")
            require(first.rows == second.rows
                    and [r for r, k in enumerate(first.row_kind) if k == "data"]
                    == [r for r, k in enumerate(second.row_kind) if k == "data"],
                    "different repeated row geometry")
            for row, kind in enumerate(first.row_kind):
                if kind == "data":
                    aliases.append(((first.role, row), (second.role, row)))
    # Renaming H intentionally disables the archived model's exact-name hook.
    # Restore EACH H constraint explicitly, in the merged row coordinates.
    provisional = O.JointModel(observations, aliases, zero_sum=False)
    extras, identities = [], []
    for ci, (attempt, original) in enumerate(origins):
        if original.role != "H":
            continue
        re, im = original.layout["zero_sum_pair"]
        extras.append(dict(name=f"zero_sum(u)@{attempt}", commitment=f"H@{attempt}",
                           coefs={provisional.merged_of[(ci, re)]: O.ONE,
                                  provisional.merged_of[(ci, im)]: O.U}, public_value=O.ZERO,
                           source="this proof's zsum sumcheck"))
        identity = O.C.h_identity_extra(original)
        identities.append(dict(identity, commitment=f"H@{attempt}",
                               coefs={provisional.merged_of[(ci, r)]: value
                                      for r, value in identity["coefs"].items()}))
    result = O.JointModel(observations, aliases, zero_sum=False, extras=extras)
    return result, dict(observations=observations, aliases=aliases, extras=extras,
                        identities=identities)


def analyze_pair(captures):
    records = {}
    for name, selected, shared in (("io_shared", {"A", "Input", "Output"}, True),
                                    ("all_shared", None, True),
                                    ("all_unshared_control", None, False)):
        joint, meta = model(captures, selected, shared)
        result = joint.analyze(planes=False)
        explicit = joint.explicit_per_column()
        require(explicit["rank_mask"] == result["per_column"]["rank_mask"]
                and explicit["rank_joint"] == result["per_column"]["rank_joint"],
                "compressed/explicit per-column disagreement")
        result["explicit_per_column"] = explicit
        if meta["identities"]:
            augmented = O.JointModel(meta["observations"], meta["aliases"], zero_sum=False,
                                    extras=meta["extras"] + meta["identities"])
            without = O.JointModel(meta["observations"], meta["aliases"], zero_sum=False)
            result["without_H_zero_sum_disclosure"] = without.analyze(planes=False)["joint"]["disclosed_total"]
            result["public_H_identities_add_no_rank"] = (
                augmented.rank(augmented.all_gens())["rank"] == result["joint"]["rank_joint"])
            require(result["public_H_identities_add_no_rank"]
                    and result["without_H_zero_sum_disclosure"] == 0, "unidentified H residual")
        expected = 0 if selected else 4
        require(result["joint"]["disclosed_total"] == expected, "unexpected repeated-view disclosure")
        records[name] = result
    ablated, _ = model(captures, {"Input"}, ablate_first_input=True)
    leakage = ablated.analyze(planes=False)["joint"]["disclosed_total"]
    require(leakage > 0, "ablation failed to detect a known leaking channel")
    return dict(privacy=captures[0].privacy, proofs=[c.proof_sha256 for c in captures],
                models=records, single_mask_ablation_disclosure=leakage,
                shared_witness_basis="source-pinned honest fixture constructs one witness before its two-attempt loop",
                H_data_aliased_across_proofs=False, random_rows_aliased=False)


def run(directory, manifest):
    validation = json.loads((ROOT / "results/zk60_round22_validation.json").read_text())
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    require(sha(manifest) == validation["fresh_capture_manifest_sha256"], "unreviewed capture manifest")
    for group in ("source_sha256", "tools", "analysis_results"):
        for path, digest in validation[group].items():
            require(sha(ROOT / path) == digest, "changed round-22 dependency: " + path)
    prior = json.loads((ROOT / "results/zk60_round22_o8_analysis.json").read_text())
    expected = set(O.load_manifest(str(manifest))["entries"])
    gate.check_report(prior, expected)
    preflight = O.preflight(str(directory), str(manifest), log=lambda *a: None)
    require(preflight["pass"] and all(c["pass"] for c in preflight["checks"]), "failed preflight")
    loaded = [O.IoCapture(str(path)) for path in sorted(directory.glob("*.json"))]
    cases = [analyze_pair([c for c in loaded if c.privacy == privacy]) for privacy in ("P1", "P3")]
    return dict(schema=1, status="passed", source_commit=O.SOURCE_COMMIT, cases=cases,
                manifest_sha256=sha(manifest), prior_analysis_sha256=sha(ROOT / "results/zk60_round22_o8_analysis.json"),
                tools=dict(prior["tool_sha256"], **{Path(__file__).name: sha(Path(__file__))}),
                scope="two source-pinned fresh proofs of one synthetic witness; fixed-coefficient message/terminal/proximity model",
                full_privacy_review_complete=False, adaptive_transcript_simulation_performed=False,
                excluded=["CFS rounds", "pads", "encoded columns", "Merkle roots/paths", "nonlinear cross-proof H relations",
                          "adaptive transcript", "arbitrary repetition count", "reused commitment owners"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--captures", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    result = run(args.captures, args.manifest)
    with args.out.open("x") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")
    print("PASS: repeated P1/P3 joint views; only two public H identities per pair")


if __name__ == "__main__":
    main()
