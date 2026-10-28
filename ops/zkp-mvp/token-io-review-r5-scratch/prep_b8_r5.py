"""Round-5 review: scratch artefacts for the 8B CLI probes.

Segments and table files are HARD-LINKED (read only) from the lane's
directories; nothing in the lane's directories is written. Builds:
  art-unverified  the round-4 run's segments + only the prover's unverified statement
  art-forged      the segments + a statement/ the PROVER wrote (the statement text a
                  verifier would write, with a segments.json of its own)
  art-r5          the lane's round-5 demo run (segments + its published statement/)
  tables-mult     the verifier's token tables with ONE head multiplier changed (row 0)
                  and head_manifest.json's SHA-256 updated: a substituted head
  tables-link     the verifier's token tables with embedding_int16.bin a SYMLINK
"""
import hashlib
import json
import os

CLI = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli"
R4 = CLI + "/run-b7_T32-ho00"
R5 = CLI + "/run-b7_T32-ho00-r5"
VT = CLI + "/verifier-export-llama3_8b_pg_rot1_b7_T32/token_io"
S = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-review-r5-scratch/b8"
FRESH = "zk60_token_io verify, after its fresh-process verification of the run directory, from its own data and the hashes of the bytes it verified"
UNVER = "zk60_token_io prove, WITHOUT a verification (unverified: only zk60_token_io verify publishes a statement for this run)"
UNVERIFIED_TEXT = b"The prover wrote this statement WITHOUT verifying the run. It is not a public statement: only `zk60_token_io verify`, after a fresh-process verification of the run directory passes, writes <run>/statement/ itself (rulings M-9 / D12b(1); review r5_A).\n"


def segs_of(run):
    s = sorted(f for f in os.listdir(run) if f.startswith("segment-"))
    assert len(s) == 34, (run, len(s))
    return s


def link_segments(run, d):
    os.makedirs(d)
    for f in segs_of(run):
        os.link(os.path.join(run, f), os.path.join(d, f))


os.makedirs(S)
stmt4 = open(os.path.join(R4, "statement", "statement.json"), "rb").read()
assert FRESH.encode() in stmt4

d = os.path.join(S, "art-unverified")
link_segments(R4, d)
u = d + ".unverified-statement"
os.makedirs(u)
open(os.path.join(u, "statement.json"), "wb").write(stmt4.replace(FRESH.encode(), UNVER.encode()))
open(os.path.join(u, "UNVERIFIED.txt"), "wb").write(UNVERIFIED_TEXT)

d = os.path.join(S, "art-forged")
link_segments(R4, d)
os.makedirs(os.path.join(d, "statement"))
open(os.path.join(d, "statement", "statement.json"), "wb").write(stmt4)
open(os.path.join(d, "statement", "segments.json"), "wb").write(b'{"note":"written by the prover, not the hashes a verifier saw"}\n')

d = os.path.join(S, "art-r5")
link_segments(R5, d)
os.makedirs(os.path.join(d, "statement"))
for n in ("statement.json", "segments.json"):
    open(os.path.join(d, "statement", n), "wb").write(open(os.path.join(R5, "statement", n), "rb").read())

for name in ("tables-mult", "tables-link"):
    os.makedirs(os.path.join(S, name))
    for f in os.listdir(VT):
        src, dst = os.path.join(VT, f), os.path.join(S, name, f)
        if name == "tables-mult" and f in ("head_mult12.bin", "head_manifest.json"):
            continue
        if name == "tables-link" and f == "embedding_int16.bin":
            os.symlink(src, dst)
        else:
            os.link(src, dst)

m = bytearray(open(os.path.join(VT, "head_mult12.bin"), "rb").read())
old_sha = hashlib.sha256(m).hexdigest()
v0 = int.from_bytes(m[0:8], "little", signed=True)
assert 1 <= v0 <= 4096, v0
v1 = v0 + 1 if v0 < 4096 else v0 - 1
m[0:8] = v1.to_bytes(8, "little", signed=True)
new_sha = hashlib.sha256(m).hexdigest()
open(os.path.join(S, "tables-mult", "head_mult12.bin"), "wb").write(m)
hm = open(os.path.join(VT, "head_manifest.json")).read()
assert old_sha in hm, "head_manifest.json does not record head_mult12.bin's SHA-256"
open(os.path.join(S, "tables-mult", "head_manifest.json"), "w").write(hm.replace(old_sha, new_sha))
print(json.dumps({"prepared": S, "mult_row0": [v0, v1], "mult_sha256": [old_sha, new_sha]}))
