#!/usr/bin/env python3
"""Shared loader for the stream GPU-phase analysis (standard library only, read-only).

Trace rows (HL_A27_GPU_TRACE, metal.rs trace_write): tag, detail, thread, queue, begin, committed,
gpu_start, gpu_end, done (host clock seconds, 7 decimals).  Logs: A22-AB REQ lines.

Per-request prover rows: the prove calls of successive requests do not overlap in time (one prover turn at a
time, trained_block.rs), so the non-wprod rows, sorted by begin, split into equal consecutive chunks of
N_PROVER rows, one chunk per request (cold request first).  The split is verified: every chunk has 32 A commits
(rows=2504) and 32 H commits (rows=2606) and no two chunks overlap in time.
"""
import gzip
import re
import statistics as st
from pathlib import Path

LOGDIR = Path("/Users/victorrielly/IntelligenceRegulation/results/zk60_batch7_sealing_lanes3_20261117")
T7 = Path("/Users/victorrielly/zk60-artifacts/batch7_traces_20261117")
T8 = Path("/Users/victorrielly/zk60-artifacts/batch8_traces_20261117")
ARMS = {
    # name: (trace, log, requests per pass, lanes)
    "serve1": (T7 / "serve1_6warm.15048.tsv.gz", LOGDIR / "batch7_serve1_6warm.log", 1, 2),
    "serve4": (T7 / "serve4_lanes2_6warm.15818.tsv.gz", LOGDIR / "batch7_serve4_lanes2_6warm.log", 4, 2),
    "serve6": (T7 / "serve6_lanes3_6warm.16734.tsv.gz", LOGDIR / "batch7_serve6_lanes3_6warm.log", 6, 3),
}
NPASS = 6

REQ = re.compile(
    r"A22-AB REQ \S+ L32 N6 \[(?P<arm>[^\]]+)\] (?:pass (?P<p>\d+) request (?P<q>\d+)|cold request (?P<cq>\d+)): "
    r"arrived (?P<arr>[0-9.]+), sealing turn (?P<turn>[0-9.]+), sealing side done (?P<sdone>[0-9.]+) \(sealing pass (?P<seal>[0-9.]+) s\), "
    r"prover (?P<ps>[0-9.]+)-(?P<pe>[0-9.]+) \(waited (?P<wait>[0-9.]+) s; prove call (?P<pc>[0-9.]+) s: "
    r"preflight (?P<pre>[0-9.]+), commit (?P<com>[0-9.]+), forks (?P<forks>[0-9.]+), join (?P<join>[0-9.]+)\), "
    r"receipt write (?P<wr>[0-9.]+) s \([^)]+\), result (?P<res>[0-9.]+);")


def q(v, p):
    s = sorted(v)
    pos = p * (len(s) - 1)
    lo = int(pos)
    hi = min(lo + 1, len(s) - 1)
    return s[lo] * (1 - (pos - lo)) + s[hi] * (pos - lo)


def med(v):
    return q(v, .5)


def iqr(v):
    return q(v, .75) - q(v, .25)


def load_trace(path):
    rows = []
    with gzip.open(path, "rt") as f:
        for line in f:
            p = line.rstrip("\n").split("\t")
            if p[0] == "tag" or len(p) != 9:
                continue
            kv = dict(tok.split("=", 1) for tok in p[1].split() if "=" in tok)
            rows.append(dict(tag=p[0], detail=p[1], th=int(p[2]), qu=int(p[3]), b=float(p[4]), c=float(p[5]),
                             gs=float(p[6]), ge=float(p[7]), d=float(p[8]), kv=kv))
    return rows


def parse_log(path):
    """{(pass, q) or ('cold', 0): dict of floats}"""
    out = {}
    for m in REQ.finditer(Path(path).read_text()):
        g = m.groupdict()
        key = ("cold", 0) if g["p"] is None else (int(g["p"]), int(g["q"]))
        out[key] = {k: float(g[k]) for k in ("arr", "turn", "sdone", "seal", "ps", "pe", "wait", "pc", "pre", "com", "forks", "join", "wr", "res")}
    return out


def merge(iv):
    """union of (a, b) intervals as a sorted list of disjoint intervals"""
    iv = sorted((a, b) for a, b in iv if b > a)
    out = []
    for a, b in iv:
        if out and a <= out[-1][1]:
            if b > out[-1][1]:
                out[-1][1] = b
        else:
            out.append([a, b])
    return out


def union_len(iv, lo=None, hi=None):
    if lo is not None:
        iv = [(max(a, lo), min(b, hi)) for a, b in iv]
    return sum(b - a for a, b in merge(iv))


def clip(iv, lo, hi):
    return [(max(a, lo), min(b, hi)) for a, b in iv if min(b, hi) > max(a, lo)]


def subtract_len(a_iv, b_iv):
    """length of union(a) minus union(b)"""
    ma, mb = merge(a_iv), merge(b_iv)
    tot = 0.0
    j = 0
    for a, b in ma:
        cur = a
        while j < len(mb) and mb[j][1] <= cur:
            j += 1
        k = j
        while k < len(mb) and mb[k][0] < b:
            if mb[k][0] > cur:
                tot += mb[k][0] - cur
            cur = max(cur, mb[k][1])
            k += 1
        if cur < b:
            tot += b - cur
    return tot


def intersect_len(a_iv, b_iv):
    return union_len(a_iv) - subtract_len(a_iv, b_iv)


def valid(r):
    return r["gs"] > 0 and r["ge"] >= r["gs"]


def span(r):
    return r["ge"] - r["gs"]


def slot_of(r):
    m = re.match(r"slot (\d+) \(([^)]*)\)", r["detail"])
    if m:
        return int(m.group(1))
    return None


def label_of(r):
    """phase label used in the tables"""
    t = r["tag"]
    if t == "commit":
        rows = int(r["kv"]["rows"])
        return {2504: "commit A (2504 rows)", 2606: "commit H (2606 rows)"}.get(rows, "commit small (%d rows)" % rows)
    if t == "gather":
        rows = int(r["kv"]["rows"])
        return {2504: "gather A (2504 rows)", 2606: "gather H (2606 rows)"}.get(rows, "gather small (%d rows)" % rows)
    if t == "batch":
        s = slot_of(r)
        name = re.match(r"slot \d+ \(([^)]*)\)", r["detail"]).group(1)
        return "slot %02d %s" % (s, name)
    return t


def split_prover(nonw, nreq):
    """Cut the begin-sorted non-wprod rows into nreq requests (prove calls do not overlap in time).
    Structure of one prove call, read from the trace (see REPORT section 2): a serial 'commit phase' of 31 small commits
    (rows=38, one per block, ~5.5 ms apart, GPU about 0.4 ms each), then the six forks (per block: A commit, H commit,
    sumcheck slot batches, A and H opening gathers), then a 'join' phase of 31 small gathers (rows=38) and two rows=37 gathers.
    Request k starts at the first of its 31 rows=38 commits: the (31k)-th such commit in begin order.  Everything before it
    (the previous request's join gathers) belongs to the previous request."""
    c38 = [i for i, r in enumerate(nonw) if r["tag"] == "commit" and r["kv"]["rows"] == "38"]
    assert len(c38) == 31 * nreq, (len(c38), nreq)
    cuts = [0] + [c38[31 * k] for k in range(1, nreq)] + [len(nonw)]
    return [nonw[cuts[i]:cuts[i + 1]] for i in range(nreq)]


def load_arm(arm):
    """returns dict: rows, log, requests: list over order [cold, (p,q)...] of dicts with prover rows and wprod rows,
    and per-pass anchor t0 (trace clock = t0 + log stream-clock)"""
    gz, lg, R, L = ARMS[arm]
    rows = load_trace(gz)
    log = parse_log(lg)
    order = [("cold", 0)] + [(p, k) for p in range(NPASS) for k in range(R)]
    wp = sorted([r for r in rows if r["tag"] == "wprod" and r["detail"].startswith("t=128")], key=lambda r: r["b"])
    extra = len(wp) - 224 * len(order)
    wp = wp[extra:]
    nonw = sorted([r for r in rows if r["tag"] != "wprod"], key=lambda r: r["b"])
    chunks = split_prover(nonw, len(order))
    reqs = []
    for i, key in enumerate(order):
        pr = chunks[i]
        w = sorted(wp[224 * i:224 * (i + 1)], key=lambda r: r["b"])
        na = sum(1 for r in pr if r["tag"] == "commit" and r["kv"]["rows"] == "2504")
        nh = sum(1 for r in pr if r["tag"] == "commit" and r["kv"]["rows"] == "2606")
        assert na == 32 and nh == 32, (arm, key, na, nh)
        reqs.append(dict(key=key, prover=pr, wprod=w, log=log[key]))
    for i in range(len(reqs) - 1):
        assert max(r["d"] for r in reqs[i]["prover"]) <= min(r["b"] for r in reqs[i + 1]["prover"]) + 1e-6, "prover chunks overlap"
    return dict(arm=arm, rows=rows, reqs=reqs, R=R, L=L, order=order)


def calibrate(arm_data):
    """Anchor between stream clock (log) and trace clock.  For each request the first prover command buffer begins after the
    prove call starts (preflight, then the commit phase).  We take, per request, a = first prover row begin - log prover start and
    return its distribution; the anchor of a pass is taken from request 0 of that pass (solo, no wait), t0 = a0 - mean_offset.
    Here offset is estimated on serve1 and applied to all arms (see anchor.py)."""
    pass


def windows(A):
    """Per request: S, E in trace clock (prove call = [S, E]); per pass t0 (stream clock zero in trace clock).
    S = first rows=38 commit begin minus the log's preflight; E = S + prove call (log).  Validated in anchor.py: the last
    buffer of the call ends 6 to 11 ms before E (host tail), the first begins 1 to 2 ms after S."""
    for rq in A["reqs"]:
        lg = rq["log"]
        c38 = min(r["b"] for r in rq["prover"] if r["tag"] == "commit" and r["kv"]["rows"] == "38")
        rq["S"] = c38 - lg["pre"]
        rq["E"] = rq["S"] + lg["pc"]
        rq["t0"] = rq["S"] - lg["ps"]
    return A


def all_prover(A):
    return [r for rq in A["reqs"] for r in rq["prover"] if valid(r)]


def all_wit(A):
    return [r for r in A["rows"] if r["tag"] == "wprod" and valid(r)]


def ivs(rows):
    return [(r["gs"], r["ge"]) for r in rows]


def depth_segments(intervals, lo, hi):
    """[(t_a, t_b, depth)] covering [lo, hi] exactly; depth = number of intervals covering the instant"""
    ev = []
    for a, b in intervals:
        a, b = max(a, lo), min(b, hi)
        if b > a:
            ev.append((a, 1))
            ev.append((b, -1))
    ev.sort()
    segs = []
    cur = lo
    d = 0
    for t, dl in ev:
        if t > cur:
            segs.append((cur, t, d))
            cur = t
        d += dl
    if hi > cur:
        segs.append((cur, hi, d))
    return segs


def rows_in(rows, lo, hi):
    """rows whose GPU span midpoint lies in [lo, hi]"""
    return [r for r in rows if lo <= 0.5 * (r["gs"] + r["ge"]) <= hi]
