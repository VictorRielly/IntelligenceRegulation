#!/usr/bin/env python3
"""Local, dependency-free demonstration of real private-computation receipts."""
from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import hashlib
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import secrets
import stat
import threading
import uuid

if __package__:
    from scripts import zk60_techweek_demo as demo
else:
    import zk60_techweek_demo as demo

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / "web/techweek/index.html"
MODES = {"token", "block", "native"}
MAX_REQUESTS = 4
REQUEST_TIMEOUT_SECONDS = 10
MAX_ARTIFACT_BYTES = 64 * 1024 * 1024


class BoundedHTTPServer(ThreadingHTTPServer):
    """Bound memory and threads even when clients stall or download together."""
    daemon_threads = True

    def __init__(self, address, handler, *, max_requests=MAX_REQUESTS):
        if max_requests < 1:
            raise ValueError("The request limit must be positive.")
        self.request_slots = threading.BoundedSemaphore(max_requests)
        super().__init__(address, handler)

    def get_request(self):
        request, address = super().get_request()
        request.settimeout(REQUEST_TIMEOUT_SECONDS)
        return request, address

    def process_request(self, request, address):
        if not self.request_slots.acquire(blocking=False):
            body = b'{"error":"The demo is busy. Please retry."}\n'
            try:
                request.settimeout(1)
                request.sendall(b"HTTP/1.0 503 Service Unavailable\r\n"
                                b"Content-Type: application/json\r\n"
                                b"Connection: close\r\nRetry-After: 1\r\n"
                                + f"Content-Length: {len(body)}\r\n\r\n".encode() + body)
            except OSError:
                pass
            finally:
                self.shutdown_request(request)
            return
        try:
            super().process_request(request, address)
        except BaseException:
            self.request_slots.release()
            raise

    def process_request_thread(self, request, address):
        try:
            super().process_request_thread(request, address)
        finally:
            self.request_slots.release()


def verified_artifact(path: Path, digest: str, expected_size=None) -> bytes:
    """Refuse pipes, links and oversize files before allocating a download."""
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as artifact:
        info = os.fstat(artifact.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_size > MAX_ARTIFACT_BYTES
                or (expected_size is not None and info.st_size != expected_size)):
            raise ValueError("Artifact type or size changed after verification")
        data = artifact.read(MAX_ARTIFACT_BYTES + 1)
    if (len(data) > MAX_ARTIFACT_BYTES or len(data) != info.st_size
            or hashlib.sha256(data).hexdigest() != digest):
        raise ValueError("Artifact changed after verification")
    return data


class DemoState:
    def __init__(self, output: Path):
        self.output = output
        self.token = secrets.token_urlsafe(32)
        self.jobs: dict[str, dict] = {}
        self.lock = threading.Lock()
        self.pool = concurrent.futures.ThreadPoolExecutor(max_workers=1)
        self.active: str | None = None

    def start(self, mode: str) -> dict:
        if mode not in MODES:
            raise ValueError("Choose token, block, or native.")
        with self.lock:
            if self.active is not None:
                raise RuntimeError("A check is already running. Please let it finish.")
            job_id = uuid.uuid4().hex
            job = {"id": job_id, "mode": mode, "state": "running",
                   "started_at": dt.datetime.now(dt.timezone.utc).isoformat()}
            self.jobs[job_id] = job
            self.active = job_id
            while len(self.jobs) > 12:
                del self.jobs[next(iter(self.jobs))]
            try:
                self.pool.submit(self._run, job_id, mode)
            except RuntimeError:
                self.jobs[job_id].update(state="failed", error="The demo worker is unavailable.")
                self.active = None
                raise RuntimeError("The demo worker is unavailable.") from None
            return dict(job)

    def _run(self, job_id: str, mode: str) -> None:
        try:
            output = self.output / job_id
            report = (demo.run_native_demo(output) if mode == "native" else
                      demo.verify_saved_demo(output, profile=mode))
            with self.lock:
                self.jobs[job_id].update(state="complete", report=report)
        except Exception as exc:
            # Child process diagnostics stay in the local run directory.
            print(f"Demo job {job_id} failed: {exc}", flush=True)
            with self.lock:
                self.jobs[job_id].update(state="failed", error=
                    "The check could not complete. Inspect this run's local logs; no success is claimed.")
        finally:
            with self.lock:
                self.active = None

    def get(self, job_id: str) -> dict | None:
        with self.lock:
            job = self.jobs.get(job_id)
            return dict(job) if job is not None else None


def handler_for(state: DemoState):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            pass

        def send(self, code: int, body: bytes, mime: str, download: str | None = None):
            self.send_response(code)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.send_header("Content-Security-Policy",
                "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; "
                "connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
            if download:
                self.send_header("Content-Disposition", f'attachment; filename="{download}"')
            self.end_headers()
            self.wfile.write(body)

        def json(self, code: int, value: dict, download: str | None = None):
            self.send(code, (json.dumps(value, indent=2) + "\n").encode(), "application/json", download)

        def allowed_host(self) -> bool:
            port = self.server.server_address[1]
            return self.headers.get("Host") in {f"127.0.0.1:{port}", f"localhost:{port}"}

        def do_GET(self):
            if not self.allowed_host():
                self.json(403, {"error": "This demo is available on localhost only."})
                return
            if self.path == "/":
                self.send(200, PAGE.read_bytes(), "text/html; charset=utf-8")
            elif self.path == "/api/status":
                with state.lock:
                    self.json(200, {"active_job": state.active, "token": state.token})
            elif self.path.startswith("/api/jobs/"):
                parts = self.path.split("/")
                if len(parts) not in {4, 5} or (len(parts) == 5 and parts[4] not in {"report.json", "receipt.bin", "policy.bin"}):
                    self.json(404, {"error": "Not found"})
                    return
                job = state.get(parts[3])
                if job is None:
                    self.json(404, {"error": "Unknown run"})
                elif len(parts) == 5:
                    if "report" not in job:
                        self.json(409, {"error": "This run has no completed report."})
                    elif parts[4] == "report.json":
                        self.json(200, job["report"], "zk60-verification-report.json")
                    elif job["report"].get("status") != "passed":
                        self.json(409, {"error": "Artifacts are available only after verification passes."})
                    else:
                        filename = parts[4]
                        path = state.output / job["id"]
                        if job["mode"] == "native":
                            path = path / "artifacts" / ("block_receipt.bin" if filename == "receipt.bin" else "block_expected.bin")
                        else:
                            path /= filename
                        try:
                            digest = job["report"].get("receipt_sha256" if filename == "receipt.bin" else "policy_sha256")
                            expected_size = job["report"].get("receipt_bytes") if filename == "receipt.bin" else None
                            data = verified_artifact(path, digest, expected_size)
                        except (OSError, ValueError):
                            self.json(409, {"error": "Artifact unavailable or changed after verification."})
                            return
                        self.send(200, data, "application/octet-stream", filename)
                else:
                    self.json(200, job)
            else:
                self.json(404, {"error": "Not found"})

        def do_POST(self):
            if not self.allowed_host():
                self.json(403, {"error": "Invalid host"})
                return
            origin = self.headers.get("Origin")
            if (origin is not None and origin != f"http://{self.headers['Host']}") or not secrets.compare_digest(
                    self.headers.get("X-Demo-Token", ""), state.token):
                self.json(403, {"error": "Open the demo on localhost and try again."})
                return
            if self.path != "/api/run":
                self.json(404, {"error": "Not found"})
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 1024 or self.headers.get("Content-Type") != "application/json":
                    raise ValueError("Expected a small JSON request.")
                body = json.loads(self.rfile.read(length))
                if not isinstance(body, dict) or set(body) != {"mode"} or not isinstance(body["mode"], str):
                    raise ValueError("Expected a mode.")
                self.json(202, state.start(body["mode"]))
            except (ValueError, UnicodeError) as exc:
                self.json(400, {"error": str(exc)})
            except RuntimeError as exc:
                self.json(409, {"error": str(exc)})

    return Handler


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--output", type=Path, default=ROOT / "results/zk60_techweek_demo")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True, mode=0o700)
    state = DemoState(args.output.resolve())
    server = BoundedHTTPServer(("127.0.0.1", args.port), handler_for(state))
    print(f"Private AI computation demo: http://127.0.0.1:{server.server_address[1]}", flush=True)
    print(f"Local evidence: {state.output}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        state.pool.shutdown(wait=True)


if __name__ == "__main__":
    main()
