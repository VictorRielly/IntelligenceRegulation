#!/usr/bin/env python3
"""Bounded localhost overload/recovery check and real saved-receipt HTTP smoke."""
import argparse
import hashlib
import json
from pathlib import Path
import socket
import sys
import threading
import time
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from scripts import zk60_techweek_server as demo_server
from scripts import zk60_techweek_smoke as smoke


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--native', action='store_true', help='Also generate the bounded native toy proof')
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    checks = []
    report = {'status': 'failed', 'checks': checks, 'real_localhost_sockets': True,
              'model_scale_run': False, 'gpu_run': False, 'live_toy_proof': args.native}
    state = demo_server.DemoState(args.out / 'runs')
    state.output.mkdir()
    sockets = []
    http = None
    def check(name, passed):
        checks.append({'name': name, 'passed': bool(passed)})
        if not passed:
            raise AssertionError(name)
    try:
        ready = threading.Condition()
        entered = 0
        original = demo_server.handler_for(state)
        class Handler(original):
            def setup(self):
                nonlocal entered
                super().setup()
                with ready:
                    entered += 1
                    ready.notify_all()
        http = demo_server.BoundedHTTPServer(('127.0.0.1', 0), Handler)
        port = http.server_address[1]
        thread = threading.Thread(target=http.serve_forever, daemon=True)
        thread.start()
        # A short timeout verifies expiration rather than waiting ten seconds.
        with patch.object(demo_server, 'REQUEST_TIMEOUT_SECONDS', 1):
            for _ in range(demo_server.MAX_REQUESTS):
                client = socket.create_connection(('127.0.0.1', port), timeout=3)
                client.sendall(b'GET ')
                sockets.append(client)
            with ready:
                check('four_stalled_clients_admitted', ready.wait_for(
                    lambda: entered == demo_server.MAX_REQUESTS, timeout=3))
            try:
                urlopen(f'http://127.0.0.1:{port}/api/status', timeout=3)
            except HTTPError as exc:
                check('fifth_client_refused_with_503', exc.code == 503)
                exc.close()
            else:
                check('fifth_client_refused_with_503', False)
            deadline = time.monotonic() + 4
            while time.monotonic() < deadline:
                try:
                    with urlopen(f'http://127.0.0.1:{port}/api/status', timeout=2) as response:
                        value = json.loads(response.read())
                        check('stalled_clients_expire_and_service_recovers',
                              response.status == 200 and value['active_job'] is None)
                        break
                except HTTPError as exc:
                    if exc.code != 503:
                        raise
                    exc.close()
                    time.sleep(.05)
            else:
                check('stalled_clients_expire_and_service_recovers', False)
        for client in sockets:
            client.close()
        sockets.clear()
        smoke_argv = ['smoke', '--port', str(port), '--out', str(args.out / 'saved-smoke.json')]
        if args.native:
            smoke_argv.append('--native')
        with patch.object(sys, 'argv', smoke_argv):
            check('real_receipt_http_smoke', smoke.main() == 0)
        saved = json.loads((args.out / 'saved-smoke.json').read_text())
        report.update(saved_smoke_checks=len(saved['checks']),
                      saved_smoke_runs=len(saved['runs']), status='passed')
    except Exception as exc:
        report['error'] = str(exc)
    finally:
        for client in sockets:
            client.close()
        if http is not None:
            http.shutdown()
            http.server_close()
        state.pool.shutdown(wait=True)
    report['source_sha256'] = {
        str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in (ROOT / 'scripts/zk60_techweek_server.py', ROOT / 'scripts/zk60_techweek_demo.py')}
    (args.out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    (args.out / 'run.done').write_text('0\n' if report['status'] == 'passed' else '1\n')
    print(json.dumps(report, indent=2), flush=True)
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
