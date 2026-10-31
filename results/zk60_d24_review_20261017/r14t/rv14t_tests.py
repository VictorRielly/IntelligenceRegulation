"""D24 review R14-tier: run the reviewer-built test binary (scratch copy of
Sol's final source + one reviewer test module) on unit tests and on Sol's
retained v1/v2 frames, read-only. Usage: rv14t_tests.py BINARY OUTDIR"""
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

REPO = Path("/Users/victorrielly/IntelligenceRegulation")
TIER = REPO / "results/zk60_sol_20261031/r14-security-tier"
OLD = REPO / "results/zk60_sol_20261031/r14-followup/artifacts"
BASE_ENV = dict(os.environ, RAYON_NUM_THREADS="2", VECLIB_MAXIMUM_THREADS="1", OPENBLAS_NUM_THREADS="1")


def main(binary, out):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=False)
    binary = str(Path(binary).resolve())
    rec = {"binary": binary, "binary_sha256": hashlib.sha256(Path(binary).read_bytes()).hexdigest(), "runs": []}

    def run(label, args, env=None, expect_ok=True, needle=None):
        t = time.time()
        r = subprocess.run([binary, *args, "--nocapture", "--test-threads=1"], cwd=REPO, env=dict(BASE_ENV, **(env or {})),
                           text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (out / (label + ".log")).write_text(r.stdout)
        summary = [l for l in r.stdout.splitlines() if l.startswith("test result:")]
        ok = (r.returncode == 0) if expect_ok else (r.returncode != 0 and (needle in r.stdout))
        rec["runs"].append({"label": label, "returncode": r.returncode, "seconds": round(time.time() - t, 2),
                            "summary": summary, "expected": "pass" if expect_ok else needle, "as_expected": ok})
        print(json.dumps(rec["runs"][-1]), flush=True)

    run("unit-security", ["split_security"])
    run("unit-cli-policy", ["split_cli_tiered_policy"])
    run("unit-cli-policy-v1", ["split_cli_policy_is_versioned"])
    run("unit-publisher-liveness", ["review_n_r6_b"])
    T = "private_block::argument::split_security_tests::"
    for dd in (0, 1):
        inp = str(TIER / "artifacts" / f"dense-{dd}")
        run(f"rv14t-library-minimum-{dd}", [T + "rv14t::rv14t_retained_frame_library_minimum", "--exact", "--ignored"],
            {"HL_R14_DD": str(dd), "HL_R14_TIER_INPUT": inp})
        run(f"sol-fresh-95-{dd}", [T + "split_security_native_fresh_verify", "--exact", "--ignored"],
            {"HL_R14_DD": str(dd), "HL_R14_TIER_INPUT": inp, "HL_R14_MIN_TIER": "95"})
        run(f"sol-fresh-100-{dd}", [T + "split_security_native_fresh_verify", "--exact", "--ignored"],
            {"HL_R14_DD": str(dd), "HL_R14_TIER_INPUT": inp, "HL_R14_MIN_TIER": "100"}, False,
            "receipt tier is below the verifier minimum")
    for name in ("dictionary-alias", "dense-receipt-0", "dense-receipt-1"):
        run("legacy-" + name, ["private_block::argument::split_attack_tests::split_accepted_control_fresh_process_verify",
                               "--exact", "--ignored"], {"HL_R14_REPLAY_INPUT": str(OLD / name)})
    rec["all_as_expected"] = all(r["as_expected"] for r in rec["runs"])
    (out / "RESULT.json").write_text(json.dumps(rec, indent=1) + "\n")
    print(json.dumps({"all_as_expected": rec["all_as_expected"]}), flush=True)
    sys.exit(0 if rec["all_as_expected"] else 3)


if __name__ == "__main__":
    main(*sys.argv[1:3])
