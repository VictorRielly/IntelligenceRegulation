"""Record the pinned Shieldstral snapshot: WEIGHTS.sha256, pins.json, small model files copied.

python3 -I record_pins.py HF_API_JSON
HF_API_JSON = saved response of https://huggingface.co/api/models/mistralai/Shieldstral-1.0-3B?blobs=true
For every file: sha256 (computed), git blob sha1 (computed) vs the API's blobId, LFS sha256 vs the API.
"""
import hashlib
import json
import os
import shutil
import sys

LANE = "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_prep_20261021"
SNAP = os.path.expanduser("~/models/shieldstral-1.0-3b/snapshot-003ec7e2")
SMALL = ["config.json", "params.json", "generation_config.json", "tokenizer_config.json",
         "processor_config.json", "chat_template.jinja", ".gitattributes", "README.md"]


def hashes(path):
    sha = hashlib.sha256()
    size = os.path.getsize(path)
    blob = hashlib.sha1(f"blob {size}\0".encode())
    with open(path, "rb") as f:
        while True:
            b = f.read(16 << 20)
            if not b:
                break
            sha.update(b)
            blob.update(b)
    return sha.hexdigest(), blob.hexdigest(), size


def main():
    api = json.load(open(sys.argv[1]))
    sib = {s["rfilename"]: s for s in api["siblings"]}
    rows, lines, ok = [], [], True
    for name in sorted(sib):
        path = os.path.join(SNAP, name)
        if not os.path.exists(path):
            rows.append({"file": name, "present": False})
            ok = False
            continue
        sha, blob, size = hashes(path)
        s = sib[name]
        lfs = (s.get("lfs") or {}).get("sha256")
        r = {"file": name, "present": True, "size": size, "size_api": s.get("size"), "sha256": sha,
             "git_blob_sha1": blob, "api_blobId": s.get("blobId"), "api_lfs_sha256": lfs}
        r["match"] = (size == s.get("size")) and ((lfs == sha) if lfs else (blob == s.get("blobId")))
        ok &= r["match"]
        rows.append(r)
        lines.append(f"{sha}  {name}")
        print(name, size, sha, "MATCH" if r["match"] else "MISMATCH", flush=True)
    hdr = (f"# mistralai/Shieldstral-1.0-3B revision {api['sha']} (lastModified {api['lastModified']})\n"
           f"# local snapshot: {SNAP}\n# sha256 computed locally; LFS files match the HF API lfs.sha256, "
           f"other files match the HF git blob id (see pins.json)\n")
    open(f"{LANE}/WEIGHTS.sha256", "w").write(hdr + "\n".join(lines) + "\n")
    json.dump({"repo": api["id"], "revision": api["sha"], "lastModified": api["lastModified"],
               "createdAt": api.get("createdAt"), "gated": api.get("gated"), "license_tags":
               [t for t in api.get("tags", []) if t.startswith("license")], "safetensors": api.get("safetensors"),
               "all_match": ok, "files": rows}, open(f"{LANE}/pins.json", "w"), indent=1)
    os.makedirs(f"{LANE}/model_files", exist_ok=True)
    for n in SMALL:
        shutil.copy2(os.path.join(SNAP, n), os.path.join(f"{LANE}/model_files", n))
    print("all_match", ok)


if __name__ == "__main__":
    main()
