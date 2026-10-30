#!/usr/bin/env python3
"""**The hash layer, COMPUTED rather than argued** — every opened column of
every opening of every stage, re-hashed and re-authenticated in Python under
the rule the loader DERIVED for the bundle.

Rounds 1 and 2 of this gate computed no hash but the Fiat-Shamir transcript:
the Merkle roots, the leaf salts and the authentication paths were labelled
ARGUED, because the disclosure model is linear and a hash is not.  That
labelling stands for what it is about -- what an unopened leaf HIDES is still
a hash assumption (M-2, M-3) -- but it left one thing uncomputed that needs
no assumption at all: the verifier's own authentication of the columns it
DID open.  This module computes exactly that:

    leaf_j        = H_column(column j's little-endian Fp bytes)      pcs.rs:148
    salted_j      = H_leaf(leaf_j || salt_j)                          pcs.rs:691
    fold the path = H_node(left || right) at each level               merkle.rs:28
                  == the commitment's root

under the four keys of decision D19 on a tagged profile, and under the
unkeyed BLAKE3 on a legacy-rule one.  The path LENGTH is checked against the
tree's depth, which is `verify_zk_tagged`'s own first check (pcs.rs:1188) and
the thing that stops an inner node being presented as a salted leaf.

**Why this belongs in a round about the tag.**  Three of D19's four keys --
column, leaf and node -- never touch the transcript, so a gate that only
replayed Fiat-Shamir would exercise ONE key and take the other three on the
bundle's word.  Here they are computed against real bytes, and the built-in
CROSS-RULE PROBE shows the fold failing under the legacy rule and under every
role-permuted key set: evidence that the bundle's bytes were MADE under the
rule it declares, not merely that it declares it.

**What this is NOT.**  Not a privacy statement, and not a change to the
disclosure model: §2.3's figures are the same ranks of the same linear model.
Authenticating an opened column says nothing about what an unopened one
hides.
"""

from __future__ import annotations

import os
import sys
from array import array

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_rg_hashrule import ROLES, HashRule  # noqa: E402


def column_bytes(values) -> bytes:
    """A committed column as `hash_column` sees it: each `Fp` as eight
    little-endian bytes, in row order (pcs.rs:140)."""
    return array("Q", values).tobytes()


def _openings(stage, shape):
    """Every PCS opening of one stage, in the transcript's own opening order:
    the masking commitment `M` first, then the openings of `roles`.  The
    `M` opening carries no `params` of its own -- its geometry is
    `run.json["mask_domain"]` -- so its depth is read from there."""
    out = [
        {
            "name": "M",
            "kind": "masking",
            "root": stage.mask["root"],
            "rows": stage.mask["rows"],
            "columns": stage.mask["columns"],
            "enc_cols": 1 << shape.mask_log_dom,
            "checks": shape.mask_columns,
        }
    ]
    for r in stage.roles:
        p = r["params"]
        out.append(
            {
                "name": r["role"],
                "kind": r["commitment_kind"],
                "root": r["commitment"]["root"],
                "rows": r["commitment"]["rows"],
                "columns": r["columns"],
                "enc_cols": (1 << p["log_cols"]) * p["inv_rate"],
                "checks": p["num_col_checks"],
            }
        )
    return out


def check_hash_layer(bundle, rule=None, probe=True) -> dict:
    """Re-hash and re-authenticate every opened column of the whole run.

    `rule` overrides the bundle's own (a control uses it to show the fold
    failing under another rule); by default the rule is the one the LOADER
    derived from the profile, which is the only rule this gate ever computes
    an honest figure under.
    """
    r = rule if rule is not None else bundle.hash_rule
    out = {
        "what": "every opened column re-hashed and its Merkle path re-folded: "
        "leaf = H_column(column bytes), salted = H_leaf(leaf||salt), "
        "root = fold H_node(left||right) -- pcs.rs:148/:691, merkle.rs:28",
        "bundle": bundle.name,
        "hash_rule": None if r is None else r.name,
        "openings": 0,
        "columns_checked": 0,
        "columns_authenticated": 0,
        "distinct_salted_leaves": 0,
        "path_depth_checked": 0,
        "bytes_hashed": 0,
        "per_stage": [],
        "cross_rule_probe": None,
        "findings": [],
    }
    if r is None:
        out["findings"].append(
            "the hash rule was refused for this bundle, so no column was "
            "re-hashed: a fold under a rule the profile does not imply proves "
            "nothing"
        )
        out["ok"] = False
        return out

    salted_seen = set()
    for st in bundle.stages:
        row = {"stage": st.index, "openings": [], "columns": 0, "authenticated": 0}
        for op in _openings(st, bundle.shape):
            depth = (op["enc_cols"] - 1).bit_length()
            root = bytes(op["root"])
            n_ok = 0
            for c in op["columns"]:
                out["columns_checked"] += 1
                row["columns"] += 1
                if len(c["path"]) != depth:
                    out["findings"].append(
                        f"stage {st.index} {op['name']}: opened column {c['index']} "
                        f"carries a Merkle path of {len(c['path'])} entries; this "
                        f"commitment's tree is {depth} deep"
                    )
                    continue
                out["path_depth_checked"] += 1
                if not 0 <= c["index"] < op["enc_cols"]:
                    out["findings"].append(
                        f"stage {st.index} {op['name']}: column index {c['index']} "
                        f"is outside the encoded domain of {op['enc_cols']}"
                    )
                    continue
                if len(c["values"]) != op["rows"]:
                    out["findings"].append(
                        f"stage {st.index} {op['name']}: opened column {c['index']} "
                        f"has {len(c['values'])} entries for {op['rows']} rows"
                    )
                    continue
                cb = column_bytes(c["values"])
                out["bytes_hashed"] += len(cb)
                leaf = r.column_digest(cb)
                salted = r.salt_leaf(leaf, bytes(c["salt"]))
                salted_seen.add(salted)
                if r.verify_path(root, c["index"], salted, [bytes(x) for x in c["path"]]):
                    n_ok += 1
                    out["columns_authenticated"] += 1
                    row["authenticated"] += 1
                else:
                    out["findings"].append(
                        f"stage {st.index} {op['name']}: the Merkle path of column "
                        f"{c['index']} does not fold to the committed root"
                    )
            out["openings"] += 1
            row["openings"].append(
                {
                    "opening": op["name"],
                    "kind": op["kind"],
                    "rows": op["rows"],
                    "encoded_columns": op["enc_cols"],
                    "depth": depth,
                    "opened": len(op["columns"]),
                    "authenticated": n_ok,
                    "root": bytes(op["root"]).hex()[:16],
                }
            )
        out["per_stage"].append(row)
    out["distinct_salted_leaves"] = len(salted_seen)

    if probe:
        out["cross_rule_probe"] = cross_rule_probe(bundle, r)
        if out["cross_rule_probe"]["findings"]:
            out["findings"] += out["cross_rule_probe"]["findings"]
    out["ok"] = not out["findings"] and out["columns_authenticated"] == out["columns_checked"]
    return out


def _permuted(rule: HashRule, mapping: dict) -> HashRule:
    """The same key set with the ROLES permuted -- a tagged rule whose leaf
    key is used where the node key belongs, and so on.  It exists only to be
    refused."""
    return HashRule(rule.profile, {r: rule.keys[mapping[r]] for r in ROLES})


def cross_rule_probe(bundle, rule) -> dict:
    """**Did the bytes come from this rule, or does the bundle merely say so?**

    One opened column of one opening, folded under the derived rule and then
    under every WRONG rule available: the legacy (unkeyed) one, and three
    role-permuted key sets.  On a tagged bundle the honest fold must be the
    only one that reaches the root; on a legacy-rule bundle the keyed sets
    are the wrong ones instead.  This is `merkle.rs`'s isolated control and
    `pcs.rs`'s leaf/node control, computed on captured bytes.
    """
    out = {
        "what": "one opened column folded under the derived rule and under every "
        "wrong rule: only the derived one may reach the root",
        "column": None,
        "derived_rule": rule.name,
        "honest": None,
        "wrong_rules_tried": 0,
        "wrong_rules_that_reached_the_root": [],
        "findings": [],
    }
    st = bundle.stages[0]
    op = _openings(st, bundle.shape)[1]          # the `A` opening
    c = op["columns"][0]
    root = bytes(op["root"])
    path = [bytes(x) for x in c["path"]]
    salt = bytes(c["salt"])
    cb = column_bytes(c["values"])
    out["column"] = {"stage": st.index, "opening": op["name"], "index": c["index"]}

    def fold(rr):
        return rr.verify_path(root, c["index"], rr.salt_leaf(rr.column_digest(cb), salt), path)

    out["honest"] = fold(rule)
    if not out["honest"]:
        out["findings"].append(
            "the cross-rule probe's own column does not authenticate under the "
            "derived rule"
        )
    others = {}
    if not rule.is_legacy:
        others["legacy"] = HashRule.legacy()
        others["column-and-leaf-keys-swapped"] = _permuted(
            rule, {"transcript": "transcript", "column": "leaf", "leaf": "column", "node": "node"}
        )
        others["leaf-and-node-keys-swapped"] = _permuted(
            rule, {"transcript": "transcript", "column": "column", "leaf": "node", "node": "leaf"}
        )
        others["one-key-everywhere-the-transcript-key"] = HashRule(
            rule.profile, {r: rule.keys["transcript"] for r in ROLES}
        )
    else:
        others["the-rung-G-tag"] = HashRule.for_profile(
            "hashline-zk-mr1/private-block-rung-g-t24-dev/1"
        )
    for name, rr in others.items():
        out["wrong_rules_tried"] += 1
        if fold(rr):
            out["wrong_rules_that_reached_the_root"].append(name)
            out["findings"].append(
                f"a column folded to the committed root under the {name} rule as "
                "well as under the derived one"
            )
    out["ok"] = not out["findings"]
    return out
