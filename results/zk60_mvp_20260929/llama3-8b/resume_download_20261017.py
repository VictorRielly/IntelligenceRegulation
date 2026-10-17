"""Resume the pinned Llama-3-8B shard downloads (2026-10-17, Claude).

Continues each missing shard from its `.partial` with an HTTP range request,
then admits it only if size and sha256 equal the pins in source.json (the
pins were recorded from the provider's metadata on 2026-09-29). A shard that
fails the pin keeps its `.partial` name and the run exits non-zero.
Writes `resume-20261017.json` beside this script; source.json is not edited.
"""
import hashlib, json, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DEST = os.path.join(REPO, "local-models", "zk60-llama3-8b")
SRC = json.load(open(os.path.join(HERE, "source.json")))
URL = "https://huggingface.co/{m}/resolve/{r}/{f}"
RECORD = os.path.join(HERE, "resume-20261017.json")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 22), b""):
            h.update(chunk)
    return h.hexdigest()


def save(rec):
    tmp = RECORD + ".tmp"
    with open(tmp, "w") as f:
        json.dump(rec, f, indent=1)
    os.replace(tmp, RECORD)


rec = {"model": SRC["model"], "revision": SRC["revision"], "shards": {},
       "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
ok = True
for name, pin in sorted(SRC["files"].items()):
    if not name.endswith(".safetensors"):
        continue
    final = os.path.join(DEST, name)
    part = final + ".partial"
    entry = {"pinned_size": pin["size"], "pinned_sha256": pin["sha256"]}
    if os.path.exists(final):
        entry["state"] = "present-before-resume"
        entry["size"] = os.path.getsize(final)
        rec["shards"][name] = entry
        save(rec)
        continue
    entry["resumed_from_bytes"] = os.path.getsize(part) if os.path.exists(part) else 0
    url = URL.format(m=SRC["model"], r=SRC["revision"], f=name)
    t0 = time.time()
    rc = subprocess.run(["curl", "-fL", "--retry", "8", "--retry-delay", "15",
                         "-C", "-", "-o", part, url]).returncode
    entry["curl_rc"] = rc
    entry["download_seconds"] = round(time.time() - t0, 1)
    size = os.path.getsize(part) if os.path.exists(part) else 0
    entry["size"] = size
    if rc == 0 and size == pin["size"]:
        digest = sha256(part)
        entry["sha256"] = digest
        if digest == pin["sha256"]:
            os.replace(part, final)
            entry["state"] = "verified"
        else:
            entry["state"] = "sha256-mismatch"
            ok = False
    else:
        entry["state"] = "incomplete"
        ok = False
    rec["shards"][name] = entry
    save(rec)

rec["finished_utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
rec["all_verified"] = ok
save(rec)
print(json.dumps(rec, indent=1))
sys.exit(0 if ok else 1)
