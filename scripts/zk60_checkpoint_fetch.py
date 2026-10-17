#!/usr/bin/env python3
"""Fetch public Llama checkpoints at immutable revisions and verify provider pins."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import time
import urllib.parse
import urllib.request


def json_url(url: str) -> tuple[dict, bytes]:
    with urllib.request.urlopen(url, timeout=60) as response:
        raw = response.read(16 * 1024 * 1024 + 1)
    if len(raw) > 16 * 1024 * 1024:
        raise ValueError("metadata exceeds 16 MiB")
    return json.loads(raw), raw


def sha_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, destination: Path, item: dict) -> None:
    expected_size = item["size"]
    lfs = item.get("lfs")
    if not lfs:
        with urllib.request.urlopen(url, timeout=60) as response:
            data = response.read(expected_size + 1)
        if len(data) != expected_size:
            raise ValueError(f"wrong size: {destination.name}")
        git_digest = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        if git_digest != item["blobId"]:
            raise ValueError(f"provider git blob pin differs: {destination.name}")
        destination.write_bytes(data)
        return
    expected_hash = lfs["sha256"]
    if destination.exists():
        if destination.stat().st_size == expected_size and sha_file(destination) == expected_hash:
            print(f"VERIFIED cached {destination.name}", flush=True)
            return
        raise ValueError(f"existing final file differs: {destination}")
    partial = destination.with_name(destination.name + ".partial")
    for attempt in range(3):
        offset = partial.stat().st_size if partial.exists() else 0
        if offset > expected_size:
            raise ValueError(f"oversized partial: {partial}")
        if offset == expected_size:
            break
        # A fresh query prevents an expired cached signed CDN redirect.
        fresh = url + ("&" if "?" in url else "?") + "zk60_attempt=" + str(time.time_ns())
        request = urllib.request.Request(fresh, headers={"Range": f"bytes={offset}-"} if offset else {})
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                if offset and (response.status != 206 or not response.headers.get("Content-Range", "").startswith(f"bytes {offset}-")):
                    raise ValueError(f"server did not honor resume offset: {destination.name}")
                if offset == 0 and response.status not in (200, 206):
                    raise ValueError(f"unexpected download status: {response.status}")
                with partial.open("ab" if offset else "wb") as target:
                    received = offset
                    last_report = time.monotonic()
                    while chunk := response.read(4 * 1024 * 1024):
                        received += len(chunk)
                        if received > expected_size:
                            raise ValueError(f"download exceeds provider length: {destination.name}")
                        target.write(chunk)
                        if time.monotonic() - last_report > 30:
                            print(f"DOWNLOAD {destination.name} {received}/{expected_size} bytes", flush=True)
                            last_report = time.monotonic()
            if partial.stat().st_size != expected_size:
                raise IOError(f"incomplete response for {destination.name}")
            break
        except (OSError, TimeoutError) as exc:
            print(f"RETRY {destination.name}: {type(exc).__name__}: {exc}", flush=True)
            if attempt == 2:
                raise
    if partial.stat().st_size != expected_size or sha_file(partial) != expected_hash:
        raise ValueError(f"download hash/length differs: {destination.name}")
    partial.rename(destination)
    print(f"VERIFIED {destination.name} SHA256={expected_hash}", flush=True)


def fetch(model: str, revision: str, output: Path, evidence: Path, metadata_only: bool) -> dict:
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("an immutable 40-character revision is required")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", model):
        raise ValueError("invalid provider model identifier")
    metadata, raw = json_url(f"https://huggingface.co/api/models/{model}/revision/{revision}?blobs=true")
    if metadata["sha"] != revision or metadata.get("gated") or metadata.get("private") or metadata.get("disabled"):
        raise ValueError("checkpoint revision is not public/ungated/available")
    output.mkdir(parents=True, exist_ok=True)
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / "provider_metadata.json").write_bytes(raw)
    files = {item["rfilename"]: item for item in metadata["siblings"]}
    names = ["config.json"]
    if "model.safetensors.index.json" in files:
        names.append("model.safetensors.index.json")
    names += sorted(name for name in files if name.endswith(".safetensors") and "/" not in name)
    if not any(name.endswith(".safetensors") for name in names):
        raise ValueError("checkpoint has no root safetensors weights")
    record = {"schema": "zk60-checkpoint-source/1", "model": model, "revision": revision,
              "provider_metadata_sha256": hashlib.sha256(raw).hexdigest(),
              "parameter_count": metadata.get("safetensors", {}).get("total"),
              "files": {name: {"size": files[name]["size"],
                               "sha256": files[name].get("lfs", {}).get("sha256"),
                               "git_blob": files[name]["blobId"]} for name in names},
              "state": "metadata-pinned", "proof_ready": False, "proof_produced": False}
    manifest = evidence / "source.json"
    manifest.write_text(json.dumps(record, indent=2) + "\n")
    for name in names:
        if metadata_only and name.endswith(".safetensors"):
            continue
        print(f"START {model}/{name} {files[name]['size']} bytes", flush=True)
        download(f"https://huggingface.co/{model}/resolve/{revision}/{urllib.parse.quote(name)}?download=true",
                 output / name, files[name])
        if not name.endswith(".safetensors"):
            record["files"][name]["sha256"] = sha_file(output / name)
            (evidence / name).write_bytes((output / name).read_bytes())
        record["files"][name]["local_verified"] = True
        manifest.write_text(json.dumps(record, indent=2) + "\n")
    if not metadata_only:
        from zk60_1b_checkpoint import Checkpoint
        pins = {name: item["sha256"] for name, item in record["files"].items() if name.endswith(".safetensors")}
        checkpoint = Checkpoint(output, pins)
        inventory = checkpoint.identity
        (evidence / "inventory.json").write_text(json.dumps(inventory, indent=2) + "\n")
        first = checkpoint.layer(0)["input_layernorm.weight"]
        tile = first.read_tile(0, min(first.end - first.start, 1024 * 1024))
        record.update(state="raw-checkpoint-verified", tensor_count=len(checkpoint.refs),
                      bounded_tile_bytes=len(tile), bounded_tile_sha256=hashlib.sha256(tile).hexdigest(),
                      inventory_sha256=sha_file(evidence / "inventory.json"))
    manifest.write_text(json.dumps(record, indent=2) + "\n")
    return record


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model")
    parser.add_argument("revision")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--metadata-only", action="store_true")
    args = parser.parse_args()
    try:
        record = fetch(args.model, args.revision, args.output, args.evidence, args.metadata_only)
    except Exception as exc:
        args.evidence.mkdir(parents=True, exist_ok=True)
        (args.evidence / "fetch-failure.json").write_text(json.dumps({"error": str(exc), "type": type(exc).__name__}) + "\n")
        raise
    print(json.dumps({key: value for key, value in record.items() if key != "files"}, indent=2))


if __name__ == "__main__":
    main()
