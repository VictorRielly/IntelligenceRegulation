"""Tick 8 arithmetic: cell-plane claim sites per block and what the contraction vectors U cost.
Standard library only, reads no file, under a second. Inputs are COUNTED figures cited in the handoff
(plane counts from results/zk60_effplan_20261105/census.log, site rules from shape.rs claim_sites 2597-2643,
slot bodies in argument.rs 2016-2943)."""
import math

ROW = 1 << 14
BLOCK_ROWS = 5103
A_ROWS, A_DATA = 2501, 2279

# --- sites per slot for the W16R2_8B profile, from claim_sites() with the census plane counts
planes = dict(D=19, Q=6, Kv=6, S=8, F=9, Ht=2, L=2, T=4, Tab=15)
n_range = planes["Tab"] - 3
sites = {
    "SS": 1, "SSM": 1, "TZC": 4 + 2 * 9, "LZC": planes["L"], "RS": 2, "QMM": 1, "KMM": 1, "VMM": 1, "WO": 1,
    "GMM": 1, "UMM": 1, "DMM": 1, "SCORE": 2, "PV": 2,
    "DZC": planes["D"] + 2, "QZC": planes["Q"] + 1, "KVZC": planes["Kv"] + 1, "SZC": planes["S"] + 2,
    "FZC": planes["F"], "TAB": 3 + n_range, "IO_IN": 1, "IO_OUT": 1,
}
total = sum(sites.values())
print("W16R2_8B A claim sites:", total, "(a_rows check:", A_DATA + 2 * total + 2, "vs census 2501)")

# domain of the plane each site reads (argument.rs lines cited in the handoff)
reads = {  # cell-domain reads per domain
    "D": 1 + 1 + 2 + 3 + 2 + planes["D"],        # SS, SSM, IO_IN, IO_OUT, QMM/KMM/VMM (A_Y), GMM/UMM (A_YM), DZC range
    "Q": planes["Q"] + 1 + 1 + 1,                # QZC range + flipped partner, WO (A_O8), SCORE (A_QR8)
    "Kv": planes["Kv"] + 1 + 1 + 1,              # KVZC range + flip, SCORE (A_KR8), PV (A_V8)
    "S": planes["S"] + 2 + 1,                    # SZC range, RS (E, ZSEL), PV (A_P)
    "F": planes["F"] + 1,                        # FZC range, DMM (A_H16)
}
cell = sum(reads.values())
noncell = total - cell
print("cell reads by domain:", reads, "total", cell, "| non-cell sites:", noncell,
      "(TZC 22, LZC 2, DZC 2 T-slices, SZC 2 Ht, TAB", 3 + n_range, ")")
assert noncell == 22 + 2 + 2 + 2 + 3 + n_range

# R13_8B shape for comparison (census planes D39 Q14 Kv14 S13 F16 Tab3)
p13 = dict(D=39, Q=14, Kv=14, S=13, F=16, Tab=3)
t13 = 1 + 1 + 22 + 2 + 2 + 7 + 2 + 2 + (p13["D"] + 2) + (p13["Q"] + 1) + (p13["Kv"] + 1) + (p13["S"] + 2) + p13["F"] + p13["Tab"] + 2
c13 = (1 + 1 + 2 + 3 + 2 + 39) + (14 + 3) + (14 + 3) + (13 + 3) + (16 + 1)
print("R13_8B sites", t13, "cell reads", c13)
print("toy A_SITES sum = 120 (layout.rs:1118, 1628): the toy count, not an 8B count")

# --- U size per read: k entries of Fp2 = 2k words
def k_of(dom, s_k):
    return {"D": 4096, "Q": 4096, "Kv": 1024, "F": 14336, "S": s_k}[dom]

def u_rows(rd, s_k, mask_pairs=True):
    entries = sum(n * k_of(d, s_k) for d, n in rd.items())
    n_reads = sum(rd.values())
    data = math.ceil(2 * entries / ROW)
    return n_reads, entries, data, data + 2 * n_reads + 2

# extra reads when a plane is split into two byte planes and each part needs its own U
split = {
    "C": {"D": 6, "S": 1, "F": 2},                 # NR NS MR MS RAL RDL | RSL | RGL RH   (480 rows)
    "M": {"Q": 2, "Kv": 2, "F": 1, "S": 2},        # RQL RO | RKL RVL | RU | SR SG        (272 rows)
    "W": {"D": 17, "F": 3, "S": 4},                # ~24 reads on the 15 int16-word planes (ESTIMATE from named list)
}
rows_check = 6 * 32 + 32 + 2 * 128, 2 * 32 + 2 * 8 + 128 + 2 * 32
print("class C rows", rows_check[0], "class M rows", rows_check[1], "(tick 6: 480, 272)")

# saved A data rows (tick 6 table): scenario -> (rows after, S k, extra read classes)
scen = [
    ("no split (hypothetical, 67 reads)", 4096, "", 0),
    ("C only, S one 4,096 matrix", 4096, "C", 1077),
    ("C only, S unpacked (k=128)", 128, "C", 1219),
    ("C+M, S 4,096", 4096, "CM", 1185),
    ("C+M+W, S 4,096", 4096, "CMW", 1440),
    ("C+M+W, S unpacked", 128, "CMW", 1532),
]
for name, s_k, cls, after in scen:
    rd = dict(reads)
    for c in cls:
        for d, n in split[c].items():
            rd[d] += n
    n_reads, ent, data, tot = u_rows(rd, s_k)
    saved = A_DATA - after if after else None
    s = f" saved {saved}: U share {tot/saved:.1%}" if saved else ""
    print(f"{name}: reads {n_reads}, entries {ent:,}, U data rows {data}, total with 2/read + 2: {tot}{s}"
          f"; block {tot/BLOCK_ROWS:+.3f}")

# upper bound: every read doubled
rd2 = {d: 2 * n for d, n in reads.items()}
n2, e2, d2, t2 = u_rows(rd2, 4096)
print(f"every read doubled (bound): reads {n2}, U data rows {d2}, total {t2}; vs saved 747..839: {t2/839:.1%} .. {t2/747:.1%}")

# credit accounting: today's A pairs at the cell sites are 2 rows each; they go if the packed A has no per-site claim
print("today's A mask pairs at the 67 cell sites:", 2 * cell, "rows (assumed released); tie claims keep 2 rows each")
for ties in (10, 48, 67):
    print(f"  with {ties} tie claims on packed A: credit {2*cell - 2*ties} rows")

# distinct contraction vectors: QMM/KMM/VMM share A_Y at one row point; GMM/UMM share A_YM at r_tf
print("distinct (plane, row point) vectors:", cell - 2 - 1)
