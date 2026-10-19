"""Round-4 review: scratch artefact directories for the 8B CLI demo run.

Segments are HARD-LINKED (read only) from the lane's run directory; nothing
in the lane's directories is written. One tampered copy of one segment.
"""
import os

LANE = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli/run-b7_T32-ho00"
S = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-review-r4-scratch/b8"
FRESH = "zk60_token_io verify, after its fresh-process verification of the run directory, from its own data and the hashes of the bytes it verified"
UNVER = "zk60_token_io prove, WITHOUT a verification (unverified: only zk60_token_io verify publishes a statement for this run)"
UNVERIFIED_TEXT = b"The prover wrote this statement WITHOUT verifying the run. It is not a public statement: only `zk60_token_io verify`, after a fresh-process verification of the run directory passes, writes <run>/statement/ itself (rulings M-9 / D12b(1); review r5_A).\n"

segs = sorted(f for f in os.listdir(LANE) if f.startswith("segment-"))
assert len(segs) == 34, segs
stmt = open(os.path.join(LANE, "statement", "statement.json"), "rb").read()
segj = open(os.path.join(LANE, "statement", "segments.json"), "rb").read()
assert FRESH.encode() in stmt


def mk(name, tamper=None, statement="published"):
    d = os.path.join(S, name)
    os.makedirs(d)
    for f in segs:
        src, dst = os.path.join(LANE, f), os.path.join(d, f)
        if f == tamper:
            b = bytearray(open(src, "rb").read())
            b[len(b) // 2] ^= 1
            open(dst, "wb").write(b)
        else:
            os.link(src, dst)
    if statement == "published":
        os.makedirs(os.path.join(d, "statement"))
        open(os.path.join(d, "statement", "statement.json"), "wb").write(stmt)
        open(os.path.join(d, "statement", "segments.json"), "wb").write(segj)
    elif statement == "unverified":
        u = d + ".unverified-statement"
        os.makedirs(u)
        open(os.path.join(u, "statement.json"), "wb").write(stmt.replace(FRESH.encode(), UNVER.encode()))
        open(os.path.join(u, "UNVERIFIED.txt"), "wb").write(UNVERIFIED_TEXT)


os.makedirs(S, exist_ok=True)
mk("art-recheck")
mk("art-publish", statement="unverified")
mk("art-tamper", tamper="segment-020.bin")
print("prepared", S, len(segs), "segments each")
