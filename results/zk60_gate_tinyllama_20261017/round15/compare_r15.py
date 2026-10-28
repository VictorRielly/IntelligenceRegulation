#!/usr/bin/env python3
"""[gate round 15] The DETERMINISTIC figures of the token gate on the
round-11 CLI-path capture (frozen-r11 tree, binary 0c9f247c..., tools v18)
against the round-9 CLI-path capture (frozen-r9 tree, binary b56f1b71...,
tools v14, gate round 10), plus the two bundles' randomness-free run facts
read directly: the absorbed calibration word, the block digests, the
parameter line, the schedule digest, the shape and the token facts.  The
figure set is `round12/compare_r12.py`'s (`gate_figures`), unchanged.  Reads
JSON only.

    python3 compare_r15.py <out.json>
"""
import importlib.util
import json
import sys

E = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
A = "/home/victor/zk60-artifacts"
R11 = f"{A}/token-io-r11-gate/captures/tinyllama-t32-L2-dense-pt1-cli-r11"
R9 = f"{A}/token-io/captures/tinyllama-t32-L2-dense-pt1-cli-r9"
REC11 = f"{E}/round15/gate/v18-tokengate-cli11.json"
REC9 = f"{E}/round10/cli9/v14-tokengate-cli9.json"
RUN_KEYS = ("profile", "block_profile", "calibration", "block_digests", "parameter_line",
            "schedule_digest", "run_shape_words", "shape", "token_io", "stage_lines",
            "layout_description", "transcript_domain", "hash_tag", "expected_policy_sha256",
            "boundary_scales", "field_modulus")


def L(p):
    with open(p) as fh:
        return json.load(fh)


def main(out):
    spec = importlib.util.spec_from_file_location("c12", f"{E}/round12/compare_r12.py")
    c12 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(c12)
    a, b = c12.gate_figures(L(REC11)), c12.gate_figures(L(REC9))
    d = c12.diff(a, b)
    ra, rb = L(f"{R11}/run.json"), L(f"{R9}/run.json")
    run_diff = {k: {"r11": ra.get(k), "r9": rb.get(k)} for k in RUN_KEYS if ra.get(k) != rb.get(k)}
    pins_a = {p["file"]: p["sha256"] for p in L(f"{R11}/manifest.json")["source_pins"]}
    pins_b = {p["file"]: p["sha256"] for p in L(f"{R9}/manifest.json")["source_pins"]}
    moved = {f: {"r9": pins_b.get(f), "r11": pins_a.get(f)}
             for f in sorted(set(pins_a) | set(pins_b)) if pins_a.get(f) != pins_b.get(f)}
    # NL-1 (v18 against v13 on the r9 capture) and the surjection (v18 against v12)
    nl_a, nl_b = L(f"{E}/round15/gate/v18-nl-cli11.json"), L(f"{E}/round10/cli9/v13-nl-cli9.json")
    nl_d = c12.diff(c12.nl_figures(nl_a), c12.nl_figures(nl_b))
    ts_a, ts_b = L(f"{E}/round15/gate/v18-ts-cli11.json"), L(f"{E}/round10/cli9/v12-ts-cli9.json")
    ts_d = c12.diff(c12.ts_figures(ts_a), c12.ts_figures(ts_b))
    doc = {"what": __doc__.strip().splitlines()[0], "privacy_acceptance": False,
           "nl1_equal": not nl_d, "nl1_differing": nl_d, "surjection_equal": not ts_d, "surjection_differing": ts_d,
           "records": {"r11": REC11, "r9": REC9}, "bundles": {"r11": R11, "r9": R9},
           "gate_figures_equal": not d, "gate_figures_differing": d,
           "run_facts_equal": not run_diff, "run_facts_differing": run_diff,
           "pins": {"r11": len(pins_a), "r9": len(pins_b), "moved": moved},
           "source_commit": {"r11": ra.get("source_commit"), "r9": rb.get("source_commit")},
           "r11_figures": a}
    with open(out, "w") as fh:
        json.dump(doc, fh, indent=1)
    print("gate figures equal:", not d, json.dumps(d)[:800])
    print("run facts equal:", not run_diff, list(run_diff)[:10])
    print("NL-1 equal:", not nl_d, "surjection equal:", not ts_d)
    print("pins", len(pins_a), len(pins_b), "moved", {f: (v["r9"] or "")[:8] + "->" + (v["r11"] or "")[:8]
                                                      for f, v in moved.items()})


if __name__ == "__main__":
    main(sys.argv[1])
