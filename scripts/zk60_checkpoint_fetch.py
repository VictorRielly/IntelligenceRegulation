#!/usr/bin/env python3
"""Fetch public Llama checkpoints at immutable revisions and verify provider pins."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import time
import urllib.parse
import urllib.request

INDEX_NAME = "model.safetensors.index.json"
SHARD_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*\.safetensors\Z")


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _json(data: bytes):
    return json.loads(data, object_pairs_hook=_unique_object)


def atomic_write(path: Path, data: bytes) -> None:
    """Publish complete evidence or keep the preceding record on failure."""
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def write_json(path: Path, record: dict) -> None:
    atomic_write(path, (json.dumps(record, indent=2) + "\n").encode())


def file_record(files: dict, name: str) -> dict:
    """Validate provider pins before selecting a file for download."""
    if name not in files:
        raise ValueError(f"checkpoint file is missing from provider metadata: {name}")
    item = files[name]
    if type(item.get("size")) is not int or item["size"] < 0:
        raise ValueError(f"invalid provider file size: {name}")
    if not isinstance(item.get("blobId"), str) or not re.fullmatch(r"[0-9a-f]{40}", item["blobId"]):
        raise ValueError(f"invalid provider git blob pin: {name}")
    lfs = item.get("lfs")
    if lfs is not None:
        if (not isinstance(lfs, dict) or not isinstance(lfs.get("sha256"), str)
                or not re.fullmatch(r"[0-9a-f]{64}", lfs["sha256"])
                or ("size" in lfs and (type(lfs["size"]) is not int or lfs["size"] != item["size"]))):
            raise ValueError(f"invalid provider LFS pin: {name}")
    return {"size": item["size"], "sha256": lfs["sha256"] if lfs is not None else None,
            "git_blob": item["blobId"]}


def selected_shards(index_bytes: bytes | None) -> list[str]:
    """Match the importer's exact shard set; unrelated weight files are ignored."""
    if index_bytes is None:
        return ["model.safetensors"]
    index = _json(index_bytes)
    if (not isinstance(index, dict) or set(index) != {"metadata", "weight_map"}
            or not isinstance(index["metadata"], dict)
            or type(index["metadata"].get("total_size")) is not int or index["metadata"]["total_size"] < 0
            or not isinstance(index["weight_map"], dict) or not index["weight_map"]):
        raise ValueError("invalid safetensors index")
    names = []
    for name in index["weight_map"].values():
        if not isinstance(name, str) or not SHARD_NAME.fullmatch(name):
            raise ValueError("unsafe or invalid shard name in safetensors index")
        names.append(name)
    return sorted(set(names))


def json_url(url: str) -> tuple[dict, bytes]:
    with urllib.request.urlopen(url, timeout=60) as response:
        raw = response.read(16 * 1024 * 1024 + 1)
    if len(raw) > 16 * 1024 * 1024:
        raise ValueError("metadata exceeds 16 MiB")
    return _json(raw), raw


def sha_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, destination: Path, item: dict) -> str:
    """Return the SHA-256 of bytes verified against the provider's source pin."""
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
        atomic_write(destination, data)
        return hashlib.sha256(data).hexdigest()
    expected_hash = lfs["sha256"]
    if destination.exists():
        if destination.stat().st_size == expected_size and sha_file(destination) == expected_hash:
            print(f"VERIFIED cached {destination.name}", flush=True)
            return expected_hash
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
    return expected_hash


def fetch(model: str, revision: str, output: Path, evidence: Path, metadata_only: bool) -> dict:
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("an immutable 40-character revision is required")
    if not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.-]*/[A-Za-z0-9_][A-Za-z0-9_.-]*", model):
        raise ValueError("invalid provider model identifier")
    metadata, raw = json_url(f"https://huggingface.co/api/models/{model}/revision/{revision}?blobs=true")
    if (not isinstance(metadata, dict) or metadata.get("sha") != revision
            or metadata.get("gated") or metadata.get("private") or metadata.get("disabled")):
        raise ValueError("checkpoint revision is not public/ungated/available")
    if not isinstance(metadata.get("siblings"), list):
        raise ValueError("provider file inventory must be a list")
    files = {}
    for item in metadata["siblings"]:
        if not isinstance(item, dict) or not isinstance(item.get("rfilename"), str):
            raise ValueError("invalid provider file inventory entry")
        name = item["rfilename"]
        if name in files:
            raise ValueError(f"duplicate provider filename: {name}")
        files[name] = item
    names = ["config.json"]
    if INDEX_NAME in files:
        names.append(INDEX_NAME)
    entries = {name: file_record(files, name) for name in names}
    output.mkdir(parents=True, exist_ok=True)
    evidence.mkdir(parents=True, exist_ok=True)
    atomic_write(evidence / "provider_metadata.json", raw)
    record = {"schema": "zk60-checkpoint-source/1", "model": model, "revision": revision,
              "provider_metadata_sha256": hashlib.sha256(raw).hexdigest(),
              "parameter_count": metadata.get("safetensors", {}).get("total"),
              "files": entries,
              "state": "metadata-pinned", "proof_ready": False, "proof_produced": False}
    manifest = evidence / "source.json"
    write_json(manifest, record)

    def fetch_file(name: str, *, copy_evidence: bool = False) -> None:
        print(f"START {model}/{name} {files[name]['size']} bytes", flush=True)
        record["files"][name]["sha256"] = download(
            f"https://huggingface.co/{model}/resolve/{revision}/{urllib.parse.quote(name)}?download=true",
            output / name, files[name])
        if copy_evidence:
            atomic_write(evidence / name, (output / name).read_bytes())
        record["files"][name]["local_verified"] = True
        write_json(manifest, record)

    # Authenticate the index before using its shard names. Do not infer a
    # model from every .safetensors file in a provider's repository.
    for name in names:
        fetch_file(name, copy_evidence=True)
    shards = selected_shards((evidence / INDEX_NAME).read_bytes() if INDEX_NAME in files else None)
    shard_entries = {name: file_record(files, name) for name in shards}
    record["files"].update(shard_entries)
    write_json(manifest, record)
    if not metadata_only:
        for name in shards:
            fetch_file(name)
        from zk60_1b_checkpoint import Checkpoint
        pins = {name: record["files"][name]["sha256"] for name in shards}
        checkpoint = Checkpoint(output, pins)
        inventory = checkpoint.identity
        write_json(evidence / "inventory.json", inventory)
        first = checkpoint.layer(0)["input_layernorm.weight"]
        tile = first.read_tile(0, min(first.end - first.start, 1024 * 1024))
        record.update(state="raw-checkpoint-verified", tensor_count=len(checkpoint.refs),
                      bounded_tile_bytes=len(tile), bounded_tile_sha256=hashlib.sha256(tile).hexdigest(),
                      inventory_sha256=sha_file(evidence / "inventory.json"))
    write_json(manifest, record)
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
        write_json(args.evidence / "fetch-failure.json", {"error": str(exc), "type": type(exc).__name__})
        raise
    print(json.dumps({key: value for key, value in record.items() if key != "files"}, indent=2))


if __name__ == "__main__":
    main()
