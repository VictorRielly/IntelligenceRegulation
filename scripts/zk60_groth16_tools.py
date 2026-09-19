#!/usr/bin/env python3
"""Fetch exact native tools from the pinned public RISC Zero CPU prover image.

No Docker daemon and no execution of downloaded files. Only listed regular
members are copied out after checking each compressed layer's SHA-256/length.
Run `launch` for the detached, shared-lock job; `status` reads its exit marker.
"""
from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tarfile
from urllib.request import Request, urlopen

REPOSITORY = "risczero/risc0-groth16-prover"
MANIFEST = "sha256:7f173963196570b7a71816ed70565a4579264c5d2e3e0ecb028102538ad0e331"
# Digest, compressed bytes, exact regular member. Skip the OS base image and
# metadata-only layers. This is a pinned linux/amd64 native extraction.
LAYERS = (
    ("adb5a1b1cc574f81df826f385326b036687a7f91da3d2a5f637ab338ff5c6f01", 6874397, "usr/local/bin/prover"),
    ("e735b5bcd9b5e9e50aab42375ea1f886c202106515dab8ca19b396a9aa5f4eb4", 96650569, "app/stark_verify.cs"),
    ("e09dc7fe7eae18a5d33fdd426135b97b0b46ebdaa29de89b68791c9e3401b402", 2230715073, "app/stark_verify_final.pk.dmp"),
    ("86045e485feb83f1667ae1da5e9320e093559d538fa787b0c57646b47a7d42e0", 27195745, "usr/local/bin/stark_verify"),
    ("b672a9635276f17423dc655a599458fa4a5ae88190ed00d1c3201447df63bc04", 9516489, "app/stark_verify.dat"),
    ("2aac0f1f99e8b1d2551231bb6d39ce0cbf205e2fe4bf2e9814ec22d4f38fa657", 599, "app/prover.sh"),
)
MAX_MEMBER = 6 * 1024**3


def write_new(path: Path, data: bytes, mode: int = 0o600) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
    with os.fdopen(fd, "wb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())


def digest_file(path: Path) -> str:
    if not stat.S_ISREG(path.lstat().st_mode):
        raise ValueError("artifact must be a regular file, not a symlink")
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def checked_layer(path: Path, sha256: str, size: int) -> None:
    if path.lstat().st_size != size or digest_file(path) != sha256:
        raise ValueError("compressed layer length/digest mismatch")


def extract_member(blob: Path, member_name: str, destination: Path) -> dict:
    """Never use extract/extractall: no archive path becomes a disk path."""
    if destination.exists() or destination.is_symlink():
        raise ValueError("destination already exists")
    matches = []
    with tarfile.open(blob, "r:gz") as archive:
        for entry in archive:
            name = entry.name[2:] if entry.name.startswith("./") else entry.name
            if name == member_name:
                matches.append(entry)
        if len(matches) != 1 or not matches[0].isfile() or not 0 <= matches[0].size <= MAX_MEMBER:
            raise ValueError("expected exactly one bounded regular member")
        # Inspection must finish before publication, including duplicate checks.
        source = archive.extractfile(matches[0])
        if source is None:
            raise ValueError("missing regular payload")
        temporary = destination.with_name(destination.name + ".partial")
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with source, os.fdopen(fd, "wb") as target:
            shutil.copyfileobj(source, target, 1024 * 1024)
            target.flush()
            os.fsync(target.fileno())
        if temporary.stat().st_size != matches[0].size:
            raise ValueError("truncated extracted payload")
        sha256 = digest_file(temporary)
        os.chmod(temporary, 0o755 if member_name.startswith("usr/local/bin/") else 0o644)
        # Hard-link publication refuses a racing existing destination atomically.
        os.link(temporary, destination, follow_symlinks=False)
        temporary.unlink()
    return {"file": destination.name, "bytes": destination.stat().st_size, "sha256": sha256}


def token() -> str:
    # Anonymous public registry token remains in memory and is never logged.
    url = f"https://auth.docker.io/token?service=registry.docker.io&scope=repository:{REPOSITORY}:pull"
    with urlopen(url, timeout=60) as response:
        return json.loads(response.read(1024 * 1024))["token"]


def fetch_blob(path: Path, sha256: str, size: int) -> None:
    req = Request(f"https://registry-1.docker.io/v2/{REPOSITORY}/blobs/sha256:{sha256}",
                  headers={"Authorization": "Bearer " + token()})
    partial = path.with_name(path.name + ".partial")
    fd = os.open(partial, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    count = 0
    with os.fdopen(fd, "wb") as target, urlopen(req, timeout=120) as response:
        while chunk := response.read(1024 * 1024):
            count += len(chunk)
            if count > size:
                raise ValueError("oversized compressed layer")
            target.write(chunk)
        target.flush()
        os.fsync(target.fileno())
    checked_layer(partial, sha256, size)
    os.link(partial, path, follow_symlinks=False)
    partial.unlink()


def work(output: Path, cache: Path | None) -> None:
    with open("/tmp/zk-heavy.lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        artifacts = output / "tools"
        artifacts.mkdir(mode=0o700)
        blobs = output / "layers"
        blobs.mkdir(mode=0o700)
        records = []
        for digest, size, member in LAYERS:
            name = digest + ".tar.gz"
            cached = cache / name if cache is not None else None
            if cached is not None and (cached.exists() or cached.is_symlink()):
                checked_layer(cached, digest, size)
                blob = cached
            else:
                blob = blobs / name
                print(f"Downloading {Path(member).name}: {size} compressed bytes", flush=True)
                fetch_blob(blob, digest, size)
            record = extract_member(blob, member, artifacts / Path(member).name)
            record["layer"] = "sha256:" + digest
            records.append(record)
            print(f"Verified {record['file']}", flush=True)
        write_new(output / "artifacts.json", (json.dumps({
            "image": REPOSITORY, "manifest": MANIFEST, "platform": "linux/amd64",
            "artifacts": records, "downloaded_code_executed": False,
        }, indent=2) + "\n").encode())


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["launch", "status", "_worker"])
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--cache", type=Path, help="Optional existing verified layer cache; read only")
    args = parser.parse_args(argv)
    output = args.out.absolute()
    if args.command == "status":
        marker = output / "download.done"
        print(json.dumps({"finished": marker.is_file(),
                          "exit_code": int(marker.read_text()) if marker.is_file() else None,
                          "artifacts_ready": marker.is_file() and marker.read_text().strip() == "0"}))
        return 0
    if args.command == "launch":
        output = output.parent.resolve(strict=True) / output.name
        output.mkdir(mode=0o700)  # existing paths, including broken symlinks, refuse
        log_fd = os.open(output / "download.log", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        command = [sys.executable, str(Path(__file__).resolve()), "_worker", "--out", str(output)]
        if args.cache is not None:
            command += ["--cache", str(args.cache.resolve(strict=True))]
        with os.fdopen(log_fd, "wb") as log:
            child = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=log,
                                     stderr=subprocess.STDOUT, start_new_session=True)
        write_new(output / "job.json", (json.dumps({"pid": child.pid}) + "\n").encode())
        print(json.dumps({"launched": True, "pid": child.pid, "out": str(output)}))
        return 0
    code = 0
    try:
        if output.is_symlink() or not output.is_dir() or output.stat().st_mode & 0o077:
            raise ValueError("worker requires an owner-only output directory")
        work(output, args.cache)
    except Exception as exc:
        # Avoid printing urllib exceptions that might contain request details.
        print(f"Tool preparation failed ({type(exc).__name__}); artifacts not ready", flush=True)
        code = 1
    finally:
        write_new(output / "download.done", f"{code}\n".encode())
    return code


if __name__ == "__main__":
    raise SystemExit(main())
