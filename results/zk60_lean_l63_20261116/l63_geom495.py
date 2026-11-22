#!/usr/bin/env python3
"""D63 lane L63 leg 20 (2026-11-22): the Shield run's stage, endpoint, boundary and wire constants of the lane's Lean
instances (INST_CONSTANTS_20261121.md rows 22, 40-43, 45, 47, 49-52, 55-57) against Sol's receipt-checked geometry
(results/zk60_sol_20261105_w16r3/b3/SHIELD_CLASSIFIER_SCOPE_495.json: values read from the verifier-written public
statement of Astra's archived, freshly verified Shieldstral R13 receipt, and its 28 frame headers).

The Lean values are read from the Lean SOURCE (RunShieldInstP.lean, RunShieldBlkInst.lean) by fixed patterns, not
copied into this script; a pattern that no longer matches is a MISMATCH. Standard library only; read-only.

usage: python3 -I l63_geom495.py <worktree> <sol_json>
Prints one line per constant (OK or MISMATCH) and a total; exit code 0 only when every line is OK.
"""
import json
import re
import sys
from pathlib import Path

wt = Path(sys.argv[1])
sol = json.loads(Path(sys.argv[2]).read_text())
r = sol["r13_public_receipt"]
L = wt / "formal" / "ZK60Formal"
inst = (L / "RunShieldInstP.lean").read_text()
blk = (L / "RunShieldBlkInst.lean").read_text()
fails = 0
lines = 0


def one(pattern, src, what):
    m = re.findall(pattern, src, re.M)
    if len(m) != 1:
        raise ValueError("Lean pattern for " + what + " matched " + str(len(m)) + " times")
    return m[0]


def nat(s):
    """A Lean natural literal: `256`, `2 ^ 12`, `2 ^ 12 + 256`."""
    s = s.strip()
    if not re.fullmatch(r"[0-9 ^+]+", s):
        raise ValueError("not a literal: " + s)
    return sum(int(a) ** int(b) if b else int(a)
               for a, b in (re.fullmatch(r"\s*(\d+)\s*(?:\^\s*(\d+))?\s*", t).groups() for t in s.split("+")))


def report(row, name, lean, receipt, how):
    global fails, lines
    lines += 1
    ok = lean == receipt
    fails += 0 if ok else 1
    print(f"{'OK' if ok else 'MISMATCH':8} row {row:>2} {name}: Lean {lean} / 495 {receipt} ({how})")


def lg(n):
    if n <= 0 or n & (n - 1):
        raise ValueError("not a power of two: " + str(n))
    return n.bit_length() - 1


try:
    st, ep, bd = r["stage"], r["input_endpoint"], r["boundary"]
    # row 49: the stage Dim <Q, 2^lt + Q, N = 2^lt * rate, path = log2 N>, IN-C's lt
    sd = [nat(x) for x in one(r"^def shdP_stgDim : Exec\.Block\.Dim := ⟨([^,]+), ([^,]+), ([^,]+), ([^⟩]+)⟩", inst,
                             "shdP_stgDim")]
    lts = [int(x) for x in re.findall(r"^  lt := (\d+)$", inst, re.M)]
    if len(lts) != 2:
        raise ValueError("expected the two stage lt fields (shdP_incPub, shdP_outcPub), found " + str(len(lts)))
    report(49, "stage log_n (shdP_incPub.lt)", lts[0], st["log_n"], "statement parameter line")
    report(56, "stage log_n (shdP_outcPub.lt)", lts[1], st["log_n"], "statement parameter line")
    report(49, "stage opened columns (shdP_stgDim.Q)", sd[0], st["opened_columns"], "statement parameter line")
    report(49, "stage 2^log_n + Q (shdP_stgDim)", sd[1], 2 ** st["log_n"] + st["opened_columns"], "derived from receipt")
    report(49, "stage N = 2^log_n * rate (shdP_stgDim)", sd[2], 2 ** st["log_n"] * st["inverse_rate"], "derived")
    report(49, "stage path log2 N (shdP_stgDim)", sd[3], st["log_n"] + lg(st["inverse_rate"]), "derived")
    # row 50: the input endpoint Dim and epLogN; shdP_incV's lr, elr, q, eq
    ed = [nat(x) for x in one(r"^def shdP_epDim : Exec\.Block\.Dim := ⟨([^,]+), ([^,]+), ([^,]+), ([^⟩]+)⟩", inst,
                             "shdP_epDim")]
    eln = int(one(r"^  epLogN := (\d+)$", inst, "shdP_incPub.epLogN"))
    report(50, "endpoint log_n (shdP_incPub.epLogN)", eln, ep["log_n"], "statement parameter line")
    report(50, "endpoint words 2^epLogN", 2 ** eln, ep["words"], "statement parameter line")
    report(50, "endpoint opened columns (shdP_epDim.Q)", ed[0], ep["opened_columns"], "statement parameter line")
    report(50, "endpoint 2^log_n + Q (shdP_epDim)", ed[1], 2 ** ep["log_n"] + ep["opened_columns"], "derived")
    report(50, "endpoint N = 2^log_n * rate (shdP_epDim)", ed[2], 2 ** ep["log_n"] * ep["inverse_rate"], "derived")
    report(50, "endpoint path log2 N (shdP_epDim)", ed[3], ep["log_n"] + lg(ep["inverse_rate"]), "derived")
    iv = one(r"^  incVAt tag \(shdP_incPub Rp embDigest embFold\) \(shdP_incGeo bInRow\) shdP_stgDim shdP_epDim "
             r"(\d+) (\d+) (\d+) (\d+)$", inst, "shdP_incV arguments")
    iv = [int(x) for x in iv]
    report(49, "IN-C stage log2 rate (shdP_incV lr)", iv[0], lg(st["inverse_rate"]), "derived")
    report(50, "IN-C endpoint log2 rate (shdP_incV elr)", iv[1], lg(ep["inverse_rate"]), "derived")
    report(49, "IN-C stage q (shdP_incV q)", iv[2], st["opened_columns"], "statement parameter line")
    report(50, "IN-C endpoint q (shdP_incV eq)", iv[3], ep["opened_columns"], "statement parameter line")
    report(57, "endpoint decoding radius (2^11 - 2*256)/2", (ed[2] - 2 * ed[0]) // 2,
           (2 ** ep["log_n"] * ep["inverse_rate"] - 2 * ep["opened_columns"]) // 2, "derived")
    # rows 51-52: IN-C geometry <bLogN, bRows, bInRow, epDataRows, epRows>
    ig = one(r"^def shdP_incGeo \(bInRow : ℕ\) : IncGeo := ⟨(\d+), (\d+), bInRow, (\d+), (\d+)⟩", inst, "shdP_incGeo")
    ig = [int(x) for x in ig]
    report(52, "IN-C boundary log_n (shdP_incGeo)", ig[0], bd["log_n"], "statement parameter line")
    report(52, "IN-C boundary rows (shdP_incGeo)", ig[1], bd["rows"], "statement parameter line")
    report(51, "endpoint rows (shdP_incGeo epRows)", ig[3], ep["rows"], "statement parameter line")
    # row 55-56: OUT-C geometry <bLogN, bRows, dataRows, sites, bOutRow> and verifier arguments
    og = one(r"^def shdP_outcGeo \(bOutRow : ℕ\) : OutcGeo := ⟨(\d+), (\d+), (\d+), (\d+), bOutRow⟩", inst,
             "shdP_outcGeo")
    og = [int(x) for x in og]
    report(55, "OUT-C boundary log_n (shdP_outcGeo)", og[0], bd["log_n"], "statement parameter line")
    report(55, "OUT-C boundary rows (shdP_outcGeo)", og[1], bd["rows"], "statement parameter line")
    report(55, "OUT-C boundary sites (shdP_outcGeo)", og[3], bd["sites"], "statement parameter line")
    ov = one(r"^    shdP_stgDim Exec\.Block\.R13\.blkDim (\d+) (\d+) (\d+) (\d+) (\d+)$", inst, "shdP_outcV arguments")
    ov = [int(x) for x in ov]
    report(56, "OUT-C stage index (shdP_outcV)", ov[0], r["out_stage_index"], "frame headers")
    report(56, "OUT-C stage log2 rate (shdP_outcV lr)", ov[1], lg(st["inverse_rate"]), "derived")
    report(56, "OUT-C boundary log2 rate (shdP_outcV blr)", ov[2], lg(bd["inverse_rate"]), "derived")
    report(56, "OUT-C stage q (shdP_outcV q)", ov[3], st["opened_columns"], "statement parameter line")
    report(56, "OUT-C boundary q (shdP_outcV bq)", ov[4], bd["opened_columns"], "statement parameter line")
    # rows 40-41: the segment geometry <.., 0, segments, k + 1, boundary rows, sites>
    sg = one(r"Exec\.Block\.R13\.segGeom \(Pk k\)\.geom 0 (\d+) \(k \+ 1\) (\d+) (\d+)$", inst, "shdP_sgeom")
    sg = [int(x) for x in sg]
    report(41, "segments (shdP_sgeom l)", sg[0], r["segment_count"], "frame headers")
    fr = r["frames"]
    blocks = [f["index"] for f in fr if f["magic"] == "HLPRUNS1"]
    report(41, "block k at segment k + 1 (shdP_sgeom), k < 26", [k + 1 for k in range(26)], blocks, "frame headers")
    report(41, "IN-C frame at index 0", 0, [f["index"] for f in fr if f["magic"] == "HLPCLIN1"][0], "frame headers")
    report(40, "boundary rows (shdP_sgeom)", sg[1], bd["rows"], "statement parameter line")
    report(40, "boundary sites (shdP_sgeom)", sg[2], bd["sites"], "statement parameter line")
    # row 22 / 42: the block IO rows and the block profile's boundary opening
    cbo = sorted(set(int(x) for x in re.findall(r"cbBndOpen tag (\d+)", inst)))
    report(42, "block profile boundary rows (every cbBndOpen tag N)", cbo, [bd["rows"]], "statement parameter line")
    # row 43: run blocks
    nb = int(one(r"^    Rp\.blks\.length = (\d+) := by$", blk, "shdP_blks_length"))
    report(43, "run blocks (shdP_blks_length)", nb, len(blocks), "frame headers")
    report(43, "run layers 0..25 (R13 profile)", list(range(nb)), sol["profiles"]["r13"]["layers"], "hashed profile")
    report(43, "run layers 0..25 (W16R2 profile)", list(range(nb)), sol["profiles"]["w16r2"]["layers"], "hashed profile")
    # row 47: tokens
    report(47, "tokens (shdP_incPub.tokens)", int(one(r"^  tokens := (\d+)$", inst, "tokens")),
           sol["profiles"]["r13"]["T"], "hashed profile")
    # row 45: the run domain bytes
    dom = one(r"^def shdP_runDomain : List UInt8 :=\n  \[([0-9,\s]+)\]", inst, "shdP_runDomain")
    dom = bytes(int(x) for x in dom.replace("\n", " ").split(","))
    report(45, "run domain (shdP_runDomain)", dom.decode(), r["profile"], "statement run_profile")
except (ValueError, KeyError, IndexError) as e:
    fails += 1
    print("MISMATCH (the comparison itself failed):", e)
print(f"l63_geom495: {lines} constants compared, {fails} mismatches")
sys.exit(1 if fails else 0)
