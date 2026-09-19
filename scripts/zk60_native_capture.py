#!/usr/bin/env python3
"""Replay native schema-3 captures from saved public synthetic receipts.

An accepted capture must equal the bytes freshly emitted by a caller-pinned
Rust verifier test binary. A JSON 'fully_verified' flag is never evidence.
The public algebra checks reuse the archived field/CFS routines unchanged;
native slot counts and subrow PCS folding are handled here, never relabelled
as FFN. This is capture integrity and public-equation checking, not privacy.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

import zk60_fable_cfs_channel as C
import zk60_io_capture_preflight as pre

require = pre.require
PROFILES = {
    "hashline-zk-mr1/private-attention-t32-poc/1": {
        "module": "private_attention", "magic": b"HLPATTN\x01", "slots": 18,
        "functionals": 28, "rows": [306, 290, 7, 7], "groups": [30, 8, 1, 1],
    },
    "hashline-zk-mr1/private-block-t32-poc/1": {
        "module": "private_block", "magic": b"HLPBLOK1", "slots": 23,
        "functionals": 34, "rows": [455, 384, 7, 7], "groups": [35, 9, 1, 1],
    },
}


def bounded(path, maximum):
    with Path(path).open("rb") as f:
        value = f.read(maximum + 1)
    require(len(value) <= maximum, "artifact exceeds bound")
    return value


def sha(data):
    return hashlib.sha256(data).hexdigest()


def pin(value, size, name):
    require(isinstance(value, str) and re.fullmatch(f"[0-9a-f]{{{size}}}", value), name)


def product(values):
    out = C.ONE
    for value in values:
        out = C.f2_mul(out, value)
    return out


def pairs(values):
    return [list(x) for x in values]


def check_slots(capture):
    """Independently close slot -> terminal -> PCS and slot -> M aliases."""
    roles = {r["role"]: r for r in capture["roles"]}
    used, functionals, hosts, scalars, cs = set(), [], [], [], []
    specs = capture["mask"]["specs"]
    previous = None
    for s, a in enumerate(capture["arguments"]):
        require(a["slot"] == s and specs[s] == [a["main"] + a["extension"], a["degree"]], "slot/spec order")
        for key in ("before_definition", "before", "after"):
            pre.state(a[key])
        if previous is not None:
            require(previous == a["before_definition"], "slot transcript join")
        previous = a["after"]
        rho = pre.vec(a["rho"], sum((a["main"], a["extension"])))
        c, scalar = pre.old._fp2(a["c"], "c"), pre.old._fp2(a["scalar"], "scalar")
        require(c != C.ZERO, "zero CFS multiplier")
        es = rho[a["main"]:]
        require(all(e not in (C.ZERO, C.ONE) for e in es), "degenerate extension")
        claimed = scalar
        for h in a["hosted"]:
            pre.old._uint(h["slot"], "hosted slot", 0, s - 1)
            claimed = C.f2_add(claimed, C.f2_mul(tuple(h["coefficient"]), scalars[h["slot"]]))
        require(list(claimed) == a["claimed_sum"], "hosted scalar equation")
        require(len(a["rounds"]) == len(rho), "sumcheck round count")
        for round_values, challenge in zip(a["rounds"], rho):
            values = pre.vec(round_values, a["degree"] + 1)
            require(C.f2_add(values[0], values[1]) == claimed, "sumcheck sum equation")
            claimed = C.interp_eval(values, challenge)
        require(list(claimed) == a["sumcheck_final"], "sumcheck final")
        require(claimed == C.f2_add(tuple(a["terminal_polynomial"]), C.f2_mul(c, tuple(a["mask_eval"]))), "masked terminal equation")
        private = [t for t in a["tables"] if t["kind"] == "private"]
        require(len(private) == len(a["terminals"]), "terminal/table count")
        cd = product(C.f2_sub(C.ONE, e) for e in es)
        for t, terminal in zip(private, a["terminals"]):
            key = (t["role"], t["claim"])
            require(key not in used, "reused claim site")
            used.add(key)
            point = []
            for coord in t["coordinates"]:
                require(len(coord) == 1, "coordinate kind")
                if "rho" in coord:
                    point.append(rho[coord["rho"]])
                elif "flip" in coord:
                    point.append(C.f2_sub(C.ONE, rho[coord["flip"]]))
                else:
                    point.append(pre.old._fp2(coord["fixed"], "fixed coordinate"))
            require(len(point) == t["log_size"], "point arity")
            er = t["extension_round"]
            cm = C.f2_mul(es[er], product(C.f2_sub(C.ONE, e) for e in es[er + 1:]))
            parts = [{"offset": sl["offset"], "log_size": t["log_size"], "coefficient": list(C.f2_mul(tuple(sl["coefficient"]), cd)), "point": pairs(point)} for sl in t["slices"]]
            logm = min(t["log_size"], 8)
            offset = t["slices"][0]["offset"] % 256 if logm < 8 else 0
            for k, u in enumerate((C.ONE, C.U)):
                parts.append({"offset": (t["mask_row"] + k) * 256 + offset, "log_size": logm, "coefficient": list(C.f2_mul(cm, u)), "point": pairs(point[-logm:])})
            require(roles[t["role"]]["claims"][t["claim"]] == {"parts": parts, "value": terminal}, "terminal/PCS alias")
        sw = C.cfs_sum_weights(*specs[s])
        total = {"terms": [{"slot": s, "weights": pairs(C.f2_mul(c, w) for w in sw)}], "value": a["scalar"]}
        if a["kind"] == "Standalone":
            require(not a["hosted"], "standalone hosts")
            functionals.append(total)
        elif a["kind"] == "Host":
            require(a["hosted"], "empty host")
            for h in a["hosted"]:
                hs = h["slot"]
                factor = C.f2_neg(C.f2_mul(tuple(h["coefficient"]), cs[hs]))
                total["terms"].append({"slot": hs, "weights": pairs(C.f2_mul(factor, w) for w in C.cfs_sum_weights(*specs[hs]))})
            hosts.append(total)
        else:
            require(a["kind"] == "Private" and not a["hosted"], "slot kind")
        functionals.append({"terms": [{"slot": s, "weights": pairs(C.cfs_eval_weights(rho, a["degree"]))}], "value": a["mask_eval"]})
        scalars.append(scalar)
        cs.append(c)
    require(previous == capture["mask"]["before"], "slots/M join")
    require(functionals + hosts == capture["mask"]["functionals"], "slot/M functional aliases")
    expected = {(r["role"], i) for r in roles.values() for i in range(len(r["claims"]))}
    h_sum = ("H", len(roles["H"]["claims"]) - 1)
    require(used == expected - {h_sum}, "unaccounted PCS claims")
    h_claim = roles["H"]["claims"][-1]
    require(h_claim["value"] == [0, 0] and all(not p["point"] for p in h_claim["parts"]), "H sum claim")


def screen_bundle(path, source_commit):
    """Cheap screening only. check_bundle MUST also invoke native replay."""
    raw = bounded(path, 64 * 1024 * 1024)
    capture = json.loads(raw, object_pairs_hook=pre.no_duplicates, parse_float=pre.no_float, parse_constant=pre.no_float)
    require(capture["schema"] == 3 and type(capture["schema"]) is int, "schema")
    profile = PROFILES.get(capture["profile"])
    require(profile is not None, "unsupported native profile")
    pin(source_commit, 40, "source pin")
    require(capture["source_commit"] == source_commit, "source mismatch")
    require(capture["kind"] == "zk60-verifier-observations" and capture["coverage"] == "native-all-slots-v1", "capture coverage")
    require(capture["transcript_domain"] == capture["profile"], "transcript domain")
    require(capture["fully_verified"] is True and capture["privacy_review_complete"] is False, "capture status")
    require(capture["privacy"] == "P1" and capture["weight_policy"] == "public-statement", "privacy/weight profile")
    require(capture["field_modulus"] == C.P and capture["extension_nonresidue"] == C.NONRESIDUE, "field")
    digest = capture["proof_sha256"]
    pin(digest, 64, "receipt digest")
    require(Path(path).name == digest + ".json", "capture filename/digest")
    receipt_path, expected_path = Path(path).with_suffix(".receipt"), Path(path).with_suffix(".expected")
    receipt = bounded(receipt_path, 4 * 1024 * 1024)
    policy = bounded(expected_path, 112)
    require(sha(receipt) == digest and len(receipt) == capture["proof_bytes"], "receipt digest/size")
    require(receipt[:8] == profile["magic"] and list(receipt[8:40]) == capture["header"]["state"], "receipt header")
    require(len(policy) == 112 and list(policy) == capture["expected_policy"] and sha(policy) == capture["expected_policy_sha256"], "expected policy digest")
    require(sha(capture["layout_description"].encode()) == capture["layout_digest"], "layout digest")
    require(capture["opening_order"] == ["M", "A", "H", "Input", "Output"], "opening order")
    require(len(capture["arguments"]) == profile["slots"] and len(capture["mask"]["functionals"]) == profile["functionals"], "argument geometry")
    require(len(capture["mask"]["specs"]) == profile["slots"], "mask slot count")
    require([r["role"] for r in capture["roles"]] == ["A", "H", "Input", "Output"], "role order")
    previous = capture["mask"]["after"]
    for i, role in enumerate(capture["roles"]):
        require(role["commitment"]["rows"] == profile["rows"][i] and len(role["groups"]) == profile["groups"][i], "PCS geometry")
        require(role["params"] == {"log_cols": 8, "inv_rate": 8, "num_col_checks": 256} and role["q_pad"] == 256, "PCS parameters")
        require(previous == role["before"], "opening transcript join")
        previous = role["after"]
    check_slots(capture)
    return capture, profile, receipt_path, expected_path


def replay(path, capture, profile, receipt, expected, binary, binary_sha256, timeout=60):
    pin(binary_sha256, 64, "verifier binary pin")
    binary = Path(binary).resolve()
    require(sha(bounded(binary, 128 * 1024 * 1024)) == binary_sha256, "verifier binary digest")
    env = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}
    env.update(HL_TEST_SOURCE_COMMIT=capture["source_commit"], HL_TEST_NATIVE_RECEIPT=str(receipt.resolve()),
               HL_TEST_NATIVE_EXPECTED=str(expected.resolve()), HL_TEST_NATIVE_COMPARE=str(Path(path).resolve()), RAYON_NUM_THREADS="2")
    test = profile["module"] + "::capture::native_capture_saved_receipt"
    result = subprocess.run([str(binary), "--exact", test, "--ignored", "--nocapture"], env=env, capture_output=True, text=True, timeout=timeout)
    require(result.returncode == 0 and "1 passed; 0 failed; 0 ignored" in result.stdout and f"test {test} ... ok" in result.stdout,
            "native replay/canonical capture mismatch: " + (result.stdout + result.stderr)[-4000:])


def check_bundle(path, source_commit, binary, binary_sha256):
    capture, profile, receipt, expected = screen_bundle(path, source_commit)
    replay(path, capture, profile, receipt, expected, binary, binary_sha256)
    return {"profile": capture["profile"], "proof_sha256": capture["proof_sha256"],
            "source_commit": source_commit, "verifier_binary_sha256": binary_sha256,
            "native_reverified": True, "canonical_capture_reproduced": True,
            "slots": profile["slots"], "slot_pcs_and_mask_aliases_checked": True,
            "privacy_review_complete": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--verifier-test-bin", required=True, type=Path)
    parser.add_argument("--verifier-sha256", required=True)
    args = parser.parse_args()
    try:
        result = check_bundle(args.capture, args.source_commit, args.verifier_test_bin, args.verifier_sha256)
    except (ValueError, KeyError, IndexError, TypeError, OSError, subprocess.SubprocessError) as error:
        parser.exit(1, f"REJECT: {error}\n")
    print(json.dumps(result, sort_keys=True, indent=2))


if __name__ == "__main__":
    main()
