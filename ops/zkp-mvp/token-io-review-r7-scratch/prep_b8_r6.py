"""Review round 6: scratch artefacts for the 8B probes on the token lane's
round-7 demo run (b7voc0_T32) and its round-6 run (b7_T32, schema /1).

Segments are HARD-LINKED (read only) from the lane's run directories; nothing
in the lane's directories is written.
  art7          the r7 run: segments + its published statement/ (re-check)
  art7-fresh    the r7 run's segments + the prover's unverified statement
                rebuilt from the published one (writer line), for an
                independent publication by my binary
  art7-tamper   art7 with one byte of segment-002 (block 1, the layer with its
                own sh_s) flipped
  art7-schema1  art7 with the statement's schema set back to /1
  art7-owncal   art7 with layers_with_own_calibration emptied
  art7-owncal2  art7 with layer 1's own sh_s changed 7 -> 6
  art6          the r6 run (schema /1): segments + its published statement/
"""
import json
import os

R = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli"
R7 = R + "/run-llama3_8b_pg_rot1_b7voc0_T32-r7-ho00"
R6 = R + "/run-b7_T32-r6-ho00"
S = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-review-r7-scratch/b8"
FRESH = "zk60_token_io verify, after its fresh-process verification of the run directory, from its own data and the hashes of the bytes it verified"
UNVER = "zk60_token_io prove, WITHOUT a verification (unverified: only zk60_token_io verify publishes a statement for this run)"
UNVERIFIED_TEXT = b"The prover wrote this statement WITHOUT verifying the run. It is not a public statement: only `zk60_token_io verify`, after a fresh-process verification of the run directory passes, writes <run>/statement/ itself (rulings M-9 / D12b(1); review r5_A).\n"


def segs_of(run):
    s = sorted(f for f in os.listdir(run) if f.startswith("segment-"))
    assert len(s) == 34, (run, len(s))
    return s


def mk(name, run, statement=None, segj=None, tamper=None, unverified=None):
    d = os.path.join(S, name)
    os.makedirs(d)
    for f in segs_of(run):
        src, dst = os.path.join(run, f), os.path.join(d, f)
        if f == tamper:
            b = bytearray(open(src, "rb").read())
            b[len(b) // 2] ^= 1
            open(dst, "wb").write(b)
        else:
            os.link(src, dst)
    if statement is not None:
        os.makedirs(os.path.join(d, "statement"))
        open(os.path.join(d, "statement", "statement.json"), "wb").write(statement)
        open(os.path.join(d, "statement", "segments.json"), "wb").write(segj)
    if unverified is not None:
        u = d + ".unverified-statement"
        os.makedirs(u)
        open(os.path.join(u, "statement.json"), "wb").write(unverified)
        open(os.path.join(u, "UNVERIFIED.txt"), "wb").write(UNVERIFIED_TEXT)


os.makedirs(S)
st7 = open(os.path.join(R7, "statement", "statement.json"), "rb").read()
sj7 = open(os.path.join(R7, "statement", "segments.json"), "rb").read()
assert FRESH.encode() in st7 and b'"layers_with_own_calibration": [{"layer": 1, "sh_s": 7}]' in st7
mk("art7", R7, st7, sj7)
mk("art7-fresh", R7, unverified=st7.replace(FRESH.encode(), UNVER.encode()))
mk("art7-tamper", R7, st7, sj7, tamper="segment-002.bin")
mk("art7-schema1", R7, st7.replace(b'"zk60-token-io-run/2"', b'"zk60-token-io-run/1"'), sj7)
mk("art7-owncal", R7, st7.replace(b'"layers_with_own_calibration": [{"layer": 1, "sh_s": 7}]', b'"layers_with_own_calibration": []'), sj7)
mk("art7-owncal2", R7, st7.replace(b'{"layer": 1, "sh_s": 7}', b'{"layer": 1, "sh_s": 6}'), sj7)
st6 = open(os.path.join(R6, "statement", "statement.json"), "rb").read()
sj6 = open(os.path.join(R6, "statement", "segments.json"), "rb").read()
mk("art6", R6, st6, sj6)
print(json.dumps({"prepared": S, "dirs": sorted(os.listdir(S))}))
