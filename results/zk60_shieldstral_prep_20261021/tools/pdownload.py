"""Resumable parallel HTTP range downloader with sha256 verification.

Usage:
  python3 pdownload.py --url URL --out PATH --size BYTES --sha256 HEX [--workers 8] [--chunk-mib 64]

Writes PATH.partial with os.pwrite, records finished chunks in PATH.chunks.json
(so a rerun resumes), verifies the full-file sha256 against --sha256 and only
then renames PATH.partial -> PATH.  Exit 0 on a verified file, 1 otherwise.
"""
import argparse
import hashlib
import json
import os
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--size", type=int, required=True)
    ap.add_argument("--sha256", required=True)
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--chunk-mib", type=int, default=64)
    a = ap.parse_args()

    part = a.out + ".partial"
    rec_path = a.out + ".chunks.json"
    if os.path.exists(a.out):
        print(f"{a.out} exists; verifying only", flush=True)
        return verify_and_finish(a.out, a.out, a.sha256)

    chunk = a.chunk_mib << 20
    n = (a.size + chunk - 1) // chunk
    done = set()
    if os.path.exists(rec_path) and os.path.exists(part):
        done = set(json.load(open(rec_path))["done"])
    fd = os.open(part, os.O_RDWR | os.O_CREAT, 0o644)
    os.ftruncate(fd, a.size)
    lock = threading.Lock()
    t0 = time.time()
    got = [0]

    def save():
        tmp = rec_path + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"size": a.size, "chunk": chunk, "done": sorted(done)}, f)
        os.replace(tmp, rec_path)

    def fetch(i):
        lo = i * chunk
        hi = min(a.size, lo + chunk) - 1
        for attempt in range(12):
            try:
                with requests.get(a.url, headers={"Range": f"bytes={lo}-{hi}"}, stream=True,
                                  timeout=(30, 120)) as r:
                    if r.status_code != 206:
                        raise RuntimeError(f"HTTP {r.status_code} for chunk {i}")
                    off = lo
                    for piece in r.iter_content(1 << 20):
                        os.pwrite(fd, piece, off)
                        off += len(piece)
                        with lock:
                            got[0] += len(piece)
                    if off != hi + 1:
                        raise RuntimeError(f"short chunk {i}: {off - lo} of {hi - lo + 1}")
                with lock:
                    done.add(i)
                    save()
                return i
            except Exception as e:  # noqa: BLE001
                print(f"chunk {i} attempt {attempt}: {e}", flush=True)
                time.sleep(min(60, 5 * (attempt + 1)))
        raise RuntimeError(f"chunk {i} failed after retries")

    todo = [i for i in range(n) if i not in done]
    print(f"{a.out}: {n} chunks of {a.chunk_mib} MiB, {len(todo)} to fetch, workers {a.workers}", flush=True)
    stop = threading.Event()

    def progress():
        while not stop.wait(60):
            el = time.time() - t0
            print(f"[{time.strftime('%H:%M:%S')}] {len(done)}/{n} chunks, {got[0]/2**20:.0f} MiB this run, "
                  f"{got[0]/2**20/max(el,1):.2f} MiB/s", flush=True)

    th = threading.Thread(target=progress, daemon=True)
    th.start()
    ok = True
    with ThreadPoolExecutor(a.workers) as ex:
        futs = [ex.submit(fetch, i) for i in todo]
        for f in as_completed(futs):
            try:
                f.result()
            except Exception as e:  # noqa: BLE001
                print(f"FAILED: {e}", flush=True)
                ok = False
    stop.set()
    os.fsync(fd)
    os.close(fd)
    if not ok or len(done) != n:
        print(f"FAILED: {len(done)}/{n} chunks done", flush=True)
        return 1
    return verify_and_finish(part, a.out, a.sha256)


def verify_and_finish(path, final, want):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(16 << 20)
            if not b:
                break
            h.update(b)
    got = h.hexdigest()
    print(f"sha256 {got} want {want}", flush=True)
    if got != want:
        print("FAILED: sha256 mismatch", flush=True)
        return 1
    if path != final:
        os.replace(path, final)
        rec = final + ".chunks.json"
        if os.path.exists(rec):
            os.remove(rec)
    print(f"OK {final}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
