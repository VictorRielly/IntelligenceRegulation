#!/usr/bin/env python3
"""Start the Proven Media demo server.

    /home/victor/IntelligenceRegulation/apps/proven-media/.venv/bin/python \
        /home/victor/IntelligenceRegulation/apps/proven-media/serve.py [--port 8765] [--host 127.0.0.1]

Stop it by creating the stop file (no signals needed; a running proof job is NOT affected, it is
detached and the next server start re-attaches to it):

    touch ~/zk60-owner-private/proven-media/STOP-SERVER

Environment: PM_PROVER=stub (default) | shieldstral (explicit testnet demo) | fake (no proof);
PM_PRIVATE_DIR / PM_PUBLIC_DIR move the data roots; PM_NO_WORKER=1 serves without the queue worker.
"""
import argparse
import logging
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import uvicorn  # noqa: E402

from proven_media import config  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8765)
    a = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")
    stop = config.PRIVATE_DIR / "STOP-SERVER"
    stop.unlink(missing_ok=True)
    server = uvicorn.Server(uvicorn.Config("proven_media.app:app", host=a.host, port=a.port, log_level="info",
                                           access_log=False))

    def watch():
        while not server.should_exit:
            if stop.exists():
                logging.info("stop file %s found: shutting down", stop)
                stop.unlink(missing_ok=True)
                server.should_exit = True
            time.sleep(2)

    threading.Thread(target=watch, daemon=True).start()
    server.run()


if __name__ == "__main__":
    main()
