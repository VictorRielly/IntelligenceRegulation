"""Token round 18, crash resume (2026-10-30): before the pre-crash step-E outputs are deleted, keep the SHA-256 of the
two batch jobs that FINISHED before the crash (c0, c1: receipt dir, unverified statement, owner dir), in the same
shape as compare.py's digests.json ('batch-c<i>' -> {receipt, statement, owner}). After the rerun these are compared
with the rerun's batch digests: a cross-run check (same fixed public entropy, two separate processes on two boots).
Supplementary only, not a section 4.4 pass criterion (a crash could in principle have damaged these files).
Each file's page cache is dropped after hashing (posix_fadvise DONTNEED; the lean-memory rule).

usage: precrash_digests.py OUT.json
"""
import hashlib, json, os, sys

EQ = "/home/victor/zk60-artifacts/token-io/r18-a5-eq"
OWN = "/home/victor/zk60-owner-private/token-io/r18-a5-eq"


def tree(d):
    out = {}
    for root, _, files in os.walk(d):
        for f in files:
            p, h = os.path.join(root, f), hashlib.sha256()
            with open(p, "rb") as fh:
                for b in iter(lambda: fh.read(1 << 20), b""):
                    h.update(b)
                os.posix_fadvise(fh.fileno(), 0, 0, os.POSIX_FADV_DONTNEED)
            out[os.path.relpath(p, d)] = h.hexdigest()
    return out


def main():
    dig = {}
    for i in (0, 1):
        out, owner = f"{EQ}/batch/a5eq-c{i}", f"{OWN}/batch/owners/c{i}"
        dig[f"batch-c{i}"] = {"receipt": tree(out), "statement": tree(out + ".unverified-statement"), "owner": tree(owner)}
    note = ("SHA-256 of the two batch jobs finished before the 2026-10-30 crash (fixed PUBLIC entropy, test only; "
            "deleted right after this record)")
    json.dump({"note": note, "trees": dig}, open(sys.argv[1], "w"), indent=1, sort_keys=True)
    print(json.dumps({k: {p: len(v[p]) for p in v} for k, v in dig.items()}))


if __name__ == "__main__":
    main()
