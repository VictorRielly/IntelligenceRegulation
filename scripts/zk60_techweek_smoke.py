#!/usr/bin/env python3
"""Exercise the local demo HTTP boundary with real retained proof verifiers."""
import argparse
import hashlib
import json
from pathlib import Path
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--native", action="store_true")
    args = parser.parse_args()
    if args.out.exists():
        parser.error("output already exists; use a new path")
    base = f"http://127.0.0.1:{args.port}"
    checks = []
    runs = []

    def request(path, data=None, headers=None):
        req = Request(base + path, data=None if data is None else json.dumps(data).encode(), headers=headers or {})
        try:
            with urlopen(req, timeout=10) as response:
                return response.status, response.read()
        except HTTPError as exc:
            return exc.code, exc.read()

    def check(name, passed):
        checks.append({"name": name, "passed": bool(passed)})
        if not passed:
            raise AssertionError(name)

    report = {"checks": checks, "runs": runs, "status": "failed", "real_verifiers": True}
    try:
        code, page = request("/")
        check("page_loaded", code == 200 and b"Keep the data private" in page)
        code, data = request("/api/status")
        check("status_loaded", code == 200)
        token = json.loads(data)["token"]
        headers = {"Content-Type": "application/json", "X-Demo-Token": token}
        check("foreign_host_refused", request("/api/status", headers={"Host": "attacker.example"})[0] == 403)
        check("missing_csrf_refused", request("/api/run", {"mode": "token"})[0] == 403)
        check("foreign_origin_refused", request("/api/run", {"mode": "token"}, dict(headers, Origin="https://attacker.example"))[0] == 403)
        check("unknown_mode_refused", request("/api/run", {"mode": "../../private"}, headers)[0] == 400)
        check("private_paths_unserved", request("/results/zk60_loop_20260918/")[0] == 404)
        for mode in (["token", "block", "native"] if args.native else ["token", "block"]):
            code, data = request("/api/run", {"mode": mode}, headers)
            check(mode + "_started", code == 202)
            job = json.loads(data)
            job_id = job["id"]
            deadline = time.monotonic() + 250
            while job["state"] == "running" and time.monotonic() < deadline:
                time.sleep(.2)
                code, data = request("/api/jobs/" + job_id)
                check(mode + "_poll", code == 200)
                job = json.loads(data)
            check(mode + "_complete", job["state"] == "complete")
            result = job["report"]
            runs.append({"job_id": job_id, "mode": mode, "report": result})
            check(mode + "_all_real_checks_passed", result["status"] == "passed" and all(c["passed"] for c in result["checks"]))
            for filename, digest_key in [("receipt.bin", "receipt_sha256"), ("policy.bin", "policy_sha256")]:
                code, artifact = request(f"/api/jobs/{job_id}/{filename}")
                check(mode + "_download_" + filename, code == 200 and hashlib.sha256(artifact).hexdigest() == result[digest_key])
            code, downloaded = request(f"/api/jobs/{job_id}/report.json")
            check(mode + "_report_download", code == 200 and json.loads(downloaded) == result)
            check(mode + "_private_log_unserved", request(f"/api/jobs/{job_id}/prove.log")[0] == 404)
        report["status"] = "passed"
    except Exception as exc:
        report["error"] = str(exc)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "checks": len(checks), "runs": len(runs), "evidence": str(args.out), "error": report.get("error")}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
