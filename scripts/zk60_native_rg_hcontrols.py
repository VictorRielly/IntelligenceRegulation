#!/usr/bin/env python3
"""The negative controls of the HASH RULE channel (decision D19).

Each is shown to pass honest first and each is made to fail, in memory only:
the bundle's `run` dictionary is edited, the check is run, and the original
member is put back before the function returns -- a test asserts the
restoration, and **no captured file on disk is ever written**.

  CH-1  one of the four `keys_hex` altered      -> refused by name, because
        the gate DERIVED the key itself and compares.
  CH-2  one of the four `contexts` altered      -> refused by name against
        the context strings pinned in the tool's own source.
  CH-3  the tag's `profile` altered             -> refused by name against
        the profile the bundle's own SHAPE declares.
  CH-4  the rule renamed `legacy` on a TAGGED profile  -> refused by name;
        and, with the refusal bypassed so that the legacy rule is actually
        computed, the transcript replay fails at the run binding and NOT ONE
        opened column authenticates.  Both halves are reported: the second
        is the one that shows the bytes themselves were made under the tag.
  CH-5  the whole `hash_tag` member removed     -> the bundle reads as a
        PRE-TAG (legacy-era) one, which is the one path where the gate does
        not compare -- and the replay then fails, so the path cannot be used
        to smuggle a tagged bundle through it.
  CH-6  a legacy-rule bundle checked under the TAG -> the same in reverse:
        the columns of a pre-tag bundle do not authenticate under rung-G's
        keys.

NOTHING HERE IS A PRIVACY STATEMENT.  These controls are about which hash
function made the bytes, not about what the bytes disclose.
"""

from __future__ import annotations

import copy
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_rg_hashlayer import check_hash_layer  # noqa: E402
from zk60_native_rg_hashrule import HashRule, rule_for_bundle  # noqa: E402
from zk60_native_rg_replay import RunReplay  # noqa: E402


def _with_tag(bundle, mutate):
    """Run `rule_for_bundle` over a bundle whose `hash_tag` member has been
    mutated in memory, and put the original member back."""
    keep = bundle.run.get("hash_tag")
    try:
        tag = copy.deepcopy(keep) if keep is not None else None
        tag = mutate(tag)
        if tag is None:
            bundle.run.pop("hash_tag", None)
        else:
            bundle.run["hash_tag"] = tag
        return rule_for_bundle(bundle)
    finally:
        if keep is None:
            bundle.run.pop("hash_tag", None)
        else:
            bundle.run["hash_tag"] = keep


def _replay_under(bundle, rule):
    """The whole-run replay computed under `rule`, with the bundle's own
    rule restored afterwards."""
    keep = bundle.hash_rule
    bundle.hash_rule = rule
    try:
        return RunReplay(bundle).run().summary()
    finally:
        bundle.hash_rule = keep


def hash_rule_controls(bundle, legacy_bundle=None) -> dict:
    """The six controls, honest first."""
    honest = rule_for_bundle(bundle)
    out = {
        "what": "the hash rule the gate DERIVES, against every way a bundle "
        "could declare another one (D19, ruling T-7)",
        "bundle": bundle.name,
        "honest": {
            "rule": honest["derived_rule"],
            "era": honest["era"],
            "keys_compared": honest["keys_compared"],
            "contexts_compared": honest["contexts_compared"],
            "refusals": honest["refusals"],
        },
        "controls": [],
    }
    if honest["refusals"]:
        out["ok"] = False
        out["skipped"] = "the honest case is refused; a control would prove nothing"
        return out
    tagged = honest["derived_rule"] != "legacy" and honest["era"] == "tagged-schema"

    def add(name, what, rec, fires):
        rec = dict(rec)
        rec.update({"control": name, "what": what, "fires": bool(fires)})
        out["controls"].append(rec)

    if not tagged:
        out["controls"].append({
            "control": "CH-1..CH-5",
            "skipped": f"{bundle.name} is not a tagged-schema bundle "
                       f"(rule {honest['derived_rule']}, era {honest['era']}), "
                       "so there is no declared key set to perturb",
            "fires": False,
        })
    else:
        # --------------------------------------------------- CH-1: a key
        def bad_key(t):
            t["keys_hex"]["leaf"] = "00" * 32
            return t

        r = _with_tag(bundle, bad_key)
        add("CH-1", "the declared leaf key replaced by zeros",
            {"mechanism": "the gate's own derivation from the profile",
             "refusals": len(r["refusals"]),
             "refusal": (r["refusals"] or [""])[0][:200],
             "keys_that_still_compared": r["keys_compared"],
             "no_rule_is_returned": r["rule"] is None,
             "member_restored": bundle.run["hash_tag"]["keys_hex"]["leaf"]
             == honest["derived_keys_hex"]["leaf"]},
            r["rule"] is None and any("leaf key" in x for x in r["refusals"]))

        # ----------------------------------------------- CH-2: a context
        def bad_ctx(t):
            t["contexts"]["node"] = t["contexts"]["node"] + "s"
            return t

        r = _with_tag(bundle, bad_ctx)
        add("CH-2", "one character added to the declared node context string",
            {"mechanism": "the four context strings pinned in the tool's source",
             "refusals": len(r["refusals"]),
             "refusal": (r["refusals"] or [""])[0][:220],
             "contexts_that_still_compared": r["contexts_compared"],
             "no_rule_is_returned": r["rule"] is None},
            r["rule"] is None and any("context" in x for x in r["refusals"]))

        # ----------------------------------------------- CH-3: the profile
        def bad_profile(t):
            t["profile"] = "hashline-zk-mr1/private-block-m125/1"
            return t

        r = _with_tag(bundle, bad_profile)
        add("CH-3", "the tag's profile replaced by another TAGGED profile's "
                    "(the 125M shape's)",
            {"mechanism": "the profile the bundle's own shape declares",
             "refusals": len(r["refusals"]),
             "refusal": (r["refusals"] or [""])[0][:220],
             "no_rule_is_returned": r["rule"] is None},
            r["rule"] is None and any("profile" in x for x in r["refusals"]))

        # ------------------------------------------- CH-4: claiming legacy
        r = _with_tag(bundle, lambda _t: {"rule": "legacy"})
        forced = _replay_under(bundle, HashRule.legacy())
        hl = check_hash_layer(bundle, rule=HashRule.legacy(), probe=False)
        add("CH-4", "the bundle renamed `legacy` while its profile is tagged",
            {"mechanism": "the tool's own port of Shape::hash_tag, and then the "
                          "bytes themselves",
             "refusals": len(r["refusals"]),
             "refusal": (r["refusals"] or [""])[0][:220],
             "no_rule_is_returned": r["rule"] is None,
             "under_the_legacy_rule_the_run_binding_reproduces":
                 forced["run_binding_reproduced"],
             "replay_failures_under_the_legacy_rule": len(forced["failures"]),
             "first_replay_failure": (forced["failures"] or [""])[0][:160],
             "columns_authenticated_under_the_legacy_rule":
                 hl["columns_authenticated"],
             "of_columns": hl["columns_checked"]},
            (r["rule"] is None and not forced["run_binding_reproduced"]
             and hl["columns_authenticated"] == 0 and hl["columns_checked"] > 0))

        # --------------------------------------- CH-5: the member removed
        r = _with_tag(bundle, lambda _t: None)
        add("CH-5", "the whole `hash_tag` member removed, so the bundle reads "
                    "as a pre-tag one",
            {"mechanism": "the pre-tag path is legacy AND superseded, and the "
                          "replay then fails on the bytes",
             "era": r["era"],
             "marked_superseded": r["superseded"],
             "the_named_finding": (r["findings"] or [""])[0][:220],
             "replay_failures_under_that_reading": len(forced["failures"]),
             "columns_authenticated_under_that_reading":
                 hl["columns_authenticated"]},
            (r["era"] == "pre-tag" and r["superseded"]
             and len(forced["failures"]) > 0 and hl["columns_authenticated"] == 0))

    # ------------------------------------ CH-6: a legacy bundle under the tag
    ch6 = {"control": "CH-6",
           "what": "a LEGACY-rule bundle's columns checked under the rung-G tag"}
    if legacy_bundle is None:
        ch6.update({"skipped": "no legacy-rule bundle was supplied", "fires": False})
    elif not legacy_bundle.hash_rule.is_legacy:
        ch6.update({"skipped": f"{legacy_bundle.name} is not a legacy-rule bundle",
                    "fires": False})
    else:
        keyed = HashRule.for_profile(legacy_bundle.run["shape"]["profile"])
        good = check_hash_layer(legacy_bundle, probe=False)
        bad = check_hash_layer(legacy_bundle, rule=keyed, probe=False)
        ch6.update({
            "bundle": legacy_bundle.name,
            "mechanism": "the column, leaf and node keys, on real captured bytes",
            "authenticated_under_the_legacy_rule": good["columns_authenticated"],
            "authenticated_under_the_tag": bad["columns_authenticated"],
            "of_columns": good["columns_checked"],
            "fires": (good["columns_authenticated"] == good["columns_checked"]
                      and bad["columns_authenticated"] == 0),
        })
    out["controls"].append(ch6)

    # A SKIPPED control is not a failure -- it is a control this bundle
    # cannot have (a pre-tag bundle declares no key set to perturb).  It is
    # named, so a reader can see which ones did not run.
    live = [c for c in out["controls"] if "skipped" not in c]
    out["ok"] = bool(live) and all(c.get("fires") for c in live)
    out["controls_skipped"] = [
        {"control": c["control"], "why": c["skipped"]}
        for c in out["controls"] if "skipped" in c
    ]
    out["controls_that_did_not_fire"] = [
        c["control"] for c in live if not c.get("fires")
    ]
    return out
