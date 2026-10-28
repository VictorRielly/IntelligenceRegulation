#!/usr/bin/env python3
"""[GATE ROUND 10, tools v12, 2026-10-20; privacy review round 4, PR4-9] The
CALIBRATION ATTRIBUTION of a token-I/O run capture: the run's absorbed
`calibration` word recomputed from the EXPORT and the named TABLE files, and
compared.

    python3 zk60_native_rg_tokencal.py --attribution <log of the PR4-9 Rust tests> \
        --bundle <token capture> [--bundle ...] --evidence <dir> --name <name>

NOTHING HERE IS A PRIVACY RESULT OR A PRIVACY ACCEPTANCE.

WHERE THE RECOMPUTATION COMES FROM.  The token run's header absorbs
    calibration = BLAKE3("hashline/token-io-calibration/v1" || I || D)
(`token_io/run.rs:303-308` [READ]) where I is the trained-model statement's
identity over the run's layers (`trained_statement.rs:665-755`: the export's
profile digest, every layer's manifest, word, table and source-tensor
digests, block digests, constants) and D the token profile's digest
(`token_io.rs:512-519`: V, BOS, the final-norm constants, the embedding and
head digests with the multipliers, the variant, the tier).  The gate's tk7
copy's test-only `pr4_9_calibration_words_*` (gr4_token_tests.rs) builds I
and D from the EXPORT directory and the named TABLE directories with the
production loaders -- the token capture test's own recipe, never a capture
-- and prints them with the composed word and the per-layer block digests.

WHAT IS CHECKED, per capture (a refusal by name each):
  A1  the capture's README names an export and a layer range, and an
      attribution line exists for exactly that export and range;
  A2  the word is RE-COMPOSED here in Python from (I, D) by the same BLAKE3
      rule and equals the Rust-composed word (the composition, checked twice);
  A3  that word equals the capture's absorbed `calibration` (`run.json`);
  A4  the token replay (`TokenRunReplay`) reproduces the run binding from
      the header words, so the compared word is the one the transcript
      absorbed;
  A5  the capture's `block_digests` equal the attribution's, block for block.

CONTROLS (failing-first: each must make the check fail):
  K1  one bit of I flipped: A2 / A3 fail;
  K2  the attribution of another layer range of the same export: A3 fails;
  K3  the attribution of another export (when given): A3 fails;
  K4  one bit of D flipped: A3 fails.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_tokengate as TG  # noqa: E402

DOMAIN = b"hashline/token-io-calibration/v1"
README_RE = re.compile(r"export `([^`]+)` \(variant ([^)]+)\), layers (\d+)\.\.(\d+)")


def _sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def compose(ident_hex: str, dig_hex: str) -> str:
    import blake3
    h = blake3.blake3()
    h.update(DOMAIN)
    h.update(bytes.fromhex(ident_hex))
    h.update(bytes.fromhex(dig_hex))
    return h.hexdigest()


def read_attributions(path):
    out = []
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if line.startswith("{") and '"pr4-9-attribution"' in line:
                out.append(json.loads(line))
    return out


def readme_facts(d):
    with open(os.path.join(d, "README.md")) as fh:
        txt = fh.read()
    m = README_RE.search(txt)
    if not m:
        return None
    return {"export": os.path.normpath(m.group(1)), "variant": m.group(2),
            "layers": list(range(int(m.group(3)), int(m.group(4)) + 1))}


def _flip(hexs):
    b = bytearray(bytes.fromhex(hexs))
    b[0] ^= 1
    return b.hex()


def check_one(bundle_dir, atts):
    rec = {"bundle": os.path.basename(bundle_dir), "findings": []}
    run = json.load(open(os.path.join(bundle_dir, "run.json")))
    word = bytes(run["calibration"]).hex()
    rec["absorbed_calibration"] = word
    facts = readme_facts(bundle_dir)
    rec["readme"] = facts
    if facts is None:
        rec["findings"].append("A1: the README names no export / layer range")
        rec["ok"] = False
        return rec
    match = [a for a in atts if os.path.normpath(a["export"]) == facts["export"] and a["layers"] == facts["layers"]]
    if len(match) != 1:
        rec["findings"].append(f"A1: {len(match)} attribution lines for {facts['export']} layers {facts['layers']}")
        rec["ok"] = False
        return rec
    a = match[0]
    rec["attribution"] = {k: a[k] for k in ("tag", "export", "emb_dir", "head_dir", "layers", "run_profile",
                                            "trained_statement_identity", "token_profile_digest",
                                            "calibration_word_composed", "statement_header_word_equal")}
    py = compose(a["trained_statement_identity"], a["token_profile_digest"])
    rec["A2_python_composition_equals_rust"] = py == a["calibration_word_composed"] and a["statement_header_word_equal"]
    rec["A3_word_equals_the_absorbed_calibration"] = py == word
    rec["A1_profile_matches"] = a["run_profile"] == run["profile"]
    b = TG.load(bundle_dir)
    rp = TG.TokenRunReplay(b).run().summary()
    rec["A4_replay_reproduces_the_binding"] = bool(rp["ok"] and rp["run_binding_reproduced"])
    caps = [bytes(x).hex() for x in run["block_digests"]]
    rec["A5_block_digests_equal"] = caps == a["block_digests"]
    for k in ("A1_profile_matches", "A2_python_composition_equals_rust", "A3_word_equals_the_absorbed_calibration",
              "A4_replay_reproduces_the_binding", "A5_block_digests_equal"):
        if not rec[k]:
            rec["findings"].append(f"{k} is false")
    # controls
    ctl = {}
    ctl["K1_identity_bit_flipped"] = {"fires": compose(_flip(a["trained_statement_identity"]), a["token_profile_digest"]) != word}
    ctl["K4_profile_digest_bit_flipped"] = {"fires": compose(a["trained_statement_identity"], _flip(a["token_profile_digest"])) != word}
    other = [x for x in atts if os.path.normpath(x["export"]) == facts["export"] and x["layers"] != facts["layers"]]
    ctl["K2_another_layer_range"] = ({"with": other[0]["tag"],
                                      "fires": compose(other[0]["trained_statement_identity"], other[0]["token_profile_digest"]) != word}
                                     if other else {"not_applicable": "no other range of this export"})
    foreign = [x for x in atts if os.path.normpath(x["export"]) != facts["export"]]
    ctl["K3_another_export"] = ({"with": foreign[0]["tag"],
                                 "fires": compose(foreign[0]["trained_statement_identity"], foreign[0]["token_profile_digest"]) != word}
                                if foreign else {"not_applicable": "no other export given"})
    rec["controls"] = ctl
    live = [v for v in ctl.values() if "fires" in v]
    rec["controls_ok"] = bool(live) and all(v["fires"] for v in live)
    rec["ok"] = not rec["findings"] and rec["controls_ok"]
    return rec


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    ap.add_argument("--attribution", required=True, action="append")
    ap.add_argument("--bundle", required=True, action="append")
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    a = ap.parse_args(argv)
    t0 = time.time()
    atts = []
    for p in a.attribution:
        atts.extend(read_attributions(p))
    rec = {"what": "PR4-9: the token captures' absorbed calibration words recomputed from the export and the "
                   "named tables; NOT a privacy result", "privacy_acceptance": False,
           "attribution_logs": {p: _sha(p) for p in a.attribution}, "attributions": len(atts),
           "captures": [check_one(d, atts) for d in a.bundle]}
    rec["ok"] = bool(rec["captures"]) and all(c["ok"] for c in rec["captures"])
    rec["status"] = "PASS" if rec["ok"] else "NOT-OK"
    rec["seconds"] = round(time.time() - t0, 1)
    rec["tool_sha256"] = {os.path.basename(__file__): _sha(os.path.abspath(__file__))}
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, f"{a.name}.json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True)
        fh.write("\n")
    for c in rec["captures"]:
        print(c["bundle"], "ok" if c["ok"] else "NOT OK", c["findings"])
    print(f"record: {path}  status {rec['status']}")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
