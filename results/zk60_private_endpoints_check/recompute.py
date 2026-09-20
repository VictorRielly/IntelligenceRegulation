#!/usr/bin/env python3
"""Independent recomputation of every COUNTED figure in
docs/zkmatrix-poc/ZK60_PRIVATE_ENDPOINTS_AT_SCALE.md.

Read-only arithmetic: nothing here builds, proves or measures. Every
formula is taken from the source file named beside it.
"""
from math import log2, ceil

out = []
def say(s=""):
    out.append(s)
    print(s)

# --------------------------------------------------------------------------
# 0. Layout arithmetic (zkp-core/src/ffn_v3/statement.rs:139-179)
# --------------------------------------------------------------------------
def layout(t, d, f):
    log_t = int(log2(t))
    log_db = min((d & -d).bit_length() - 1, 12)
    log_fb = min((f & -f).bit_length() - 1, 12)
    db, fb = 1 << log_db, 1 << log_fb
    nb_d, nb_f = d // db, f // fb
    tfb, tdb = t * fb, t * db
    a_len = 7 * nb_f * tfb + 3 * nb_d * tdb          # :161-164
    w_len = 3 * nb_d * nb_f * (db * fb)              # :165-170
    h_len = 2 * (3 * nb_f * tfb + nb_d * tdb)        # :171-174
    log_a_min = log_t + min(log_db, log_fb)          # :176
    return dict(log_t=log_t, log_db=log_db, nb_d=nb_d, log_fb=log_fb, nb_f=nb_f,
                tfb=tfb, tdb=tdb, a_len=a_len, w_len=w_len, h_len=h_len,
                log_a_min=log_a_min)

say("== 1. Layouts ==")
for name, (t, d, f) in [("tiny  T32/d16/f16", (32, 16, 16)),
                        ("125M  T512/d768/f2048", (512, 768, 2048)),
                        ("Mistral T512/d4096/f14336", (512, 4096, 14336)),
                        ("hypothetical d=8192", (512, 8192, 14336))]:
    L = layout(t, d, f)
    log_n = min(14, L["log_a_min"]) if t > 32 else min(8, L["log_a_min"])
    n = 1 << log_n
    say(f"{name}: nb_d={L['nb_d']} log_db={L['log_db']} nb_f={L['nb_f']} "
        f"log_fb={L['log_fb']} tdb={L['tdb']} T*d={t*d} log_a_min={L['log_a_min']} "
        f"log_n={log_n} A data rows={L['a_len']//n} W rows={L['w_len']//n} "
        f"H rows={L['h_len']//n}")
say()

# where a T*d-wide and a 2^ceil-wide slice at x[0] land (statement.rs:163)
say("== 2. What a single slice at lay.x[0] covers (125M) ==")
L = layout(512, 768, 2048)
x0 = 7 * L["nb_f"] * L["tfb"]
xs = [x0 + c * L["tdb"] for c in range(L["nb_d"])]
zs = [x0 + L["nb_d"] * L["tdb"] + c * L["tdb"] for c in range(L["nb_d"])]
rds = [x0 + 2 * L["nb_d"] * L["tdb"] + c * L["tdb"] for c in range(L["nb_d"])]
say(f"x blocks at {xs}; z blocks at {zs}; rd blocks at {rds}")
say(f"slice of tdb  = {L['tdb']:>7} covers [{x0}, {x0+L['tdb']}) -> x[0] only")
say(f"slice of T*d  = {512*768:>7} covers [{x0}, {x0+512*768}) -> x[0..2] exactly, "
    f"ends at z[0] = {zs[0]}")
p2 = 1 << ceil(log2(512 * 768))
say(f"slice of 2^19 = {p2:>7} covers [{x0}, {x0+p2}) -> x[0..2] + z[0]; "
    f"z[1] starts at {zs[1]} (NOT rd[0] = {rds[0]})")
say()

# --------------------------------------------------------------------------
# 3. CFS slot length (zkp-core/src/sumcheck.rs:197-199, zk.rs:2172, :373-375, :442)
# --------------------------------------------------------------------------
def cfs_len(n_vars, degree):
    return n_vars * degree + 2

say("== 3. Seam CFS slot ==")
for name, m in [("tiny (log_t+log_db=9)", 9), ("125M block (17)", 17),
                ("Mistral (21)", 21), ("2^40 plane", 40), ("binding", 126)]:
    n_vars = m + 1
    Lc = cfs_len(n_vars, 2)
    say(f"{name}: n_vars={n_vars} L={Lc} L+256={Lc+256} "
        f"{'OK' if Lc + 256 <= 512 else 'REFUSED'}")
say("mask_commit assert (zk.rs:442): L + MASK_Q(256) <= 2^MASK_LOG_MSG(512)"
    "  =>  L <= 256  =>  n_vars <= 127  =>  log2 N <= 126")
say("sum_weights (sumcheck.rs:223-224) '1u64 << n_vars'   => n_vars <= 63 => log2 N <= 62")
say("CfsMask::round (sumcheck.rs:266) '1u64 << (n-1-j)'   => n_vars <= 64 (weaker)")
say()

# --------------------------------------------------------------------------
# 4. Per-opening PCS soundness (pcs.rs:17-19 with the hiding message n+Q)
# --------------------------------------------------------------------------
def per_opening(n, inv_rate, Q=256, checks=256):
    nn = n * inv_rate
    rate = (n + Q) / nn
    delta = 1 - rate
    return checks * log2(1 - delta / 3), rate

say("== 4. Per opening, (1 - delta/3)^Q with delta = 1 - (n+Q)/nn ==")
for name, (n, ir) in [("tiny endpoint 8/8", (256, 8)),
                      ("A,H and scaled endpoint 14/4", (1 << 14, 4)),
                      ("non-hiding rate 1/inv_rate at ir=4", (None, None))]:
    if n is None:
        # the code comment's own version: delta = 1 - 1/inv_rate
        say(f"{name}: (3/4)^256 = 2^{256*log2(0.75):.3f}")
        continue
    b, rate = per_opening(n, ir)
    say(f"{name}: (n+Q)/nn = {rate:.6f} -> 2^{b:.3f}")
say()

# --------------------------------------------------------------------------
# 5. Whole proof (D15 / ZK60_FABLE_SECURITY_OBLIGATIONS.md section 5)
# --------------------------------------------------------------------------
def addb(*bits):
    """log2 of a sum of 2^b terms."""
    m = max(bits)
    return m + log2(sum(2 ** (b - m) for b in bits))

say("== 5. Whole proof ==")
tiny_b, _ = per_opening(256, 8)
scaled_b, _ = per_opening(1 << 14, 4)
lookup = -94.2
d15_commit = -98.7
say(f"D15 as published: commitment {d15_commit} + lookup {lookup} "
    f"= 2^{addb(d15_commit, lookup):.3f}")
ep64 = 6 + scaled_b
say(f"64 endpoint openings at 2^{scaled_b:.3f} = 2^{ep64:.3f}")
new_commit = addb(d15_commit, ep64)
say(f"new commitment term = 2^{new_commit:.3f}")
say(f"new whole proof     = 2^{addb(new_commit, lookup):.3f}  "
    f"(loss {addb(d15_commit, lookup) - addb(new_commit, lookup):.3f} bits)")
say()
say("-- the same, with the per-opening figure applied CONSISTENTLY --")
base192 = log2(192) + scaled_b
say(f"192 existing openings (32 layers x 6) at 2^{scaled_b:.3f} = 2^{base192:.3f}"
    f"   [D15's 2^-98.7 = 192 x 2^{tiny_b:.3f} = 2^{log2(192)+tiny_b:.3f}]")
say(f"whole proof before endpoints = 2^{addb(base192, lookup):.3f}")
say(f"whole proof after  endpoints = 2^{addb(addb(base192, ep64), lookup):.3f}")
say(f"loss = {addb(base192, lookup) - addb(addb(base192, ep64), lookup):.3f} bits")
say(f"dominant term: lookup 2^{lookup} vs commitment 2^{addb(base192, ep64):.3f} "
    f"(ratio {2**(addb(base192,ep64)-lookup):.4f})")
say()

# --------------------------------------------------------------------------
# 6. The seam relation's field error
# --------------------------------------------------------------------------
P = (1 << 64) - (1 << 32) + 1
FP2 = P * P
say("== 6. Seam relation, (m + 2(m+1))/|Fp2| ==")
for name, m in [("tiny", 9), ("125M block", 17), ("Mistral", 21)]:
    e = (m + 2 * (m + 1)) / FP2
    say(f"{name} m={m}: {m + 2*(m+1)}/|Fp2| = 2^{log2(e):.3f}")
say(f"64 seams at m=21: 2^{log2(64*(21+44)/FP2):.3f}")
say(f"one mu batching term 1/|Fp2| = 2^{log2(1/FP2):.4f}; "
    f"64 of them = 2^{log2(64/FP2):.3f}")
say()

# --------------------------------------------------------------------------
# 7. Endpoint opening bytes and the log_cols sweep
# --------------------------------------------------------------------------
def endpoint_open_bytes(plane_words, log_cols, inv_rate, mask_rows=5, checks=256, Q=256,
                        groups=1):
    n = 1 << log_cols
    rows = -(-plane_words // n) + mask_rows
    nn = n * inv_rate
    depth = int(log2(nn))
    vecs = (groups + 1) * (n + Q) * 16
    cols = checks * (8 + rows * 8 + 32 + depth * 32)
    return vecs + cols, rows, depth

say("== 7. Endpoint opening bytes ==")
for name, plane in [("Mistral 2^21", 1 << 21), ("125M 3*2^17", 3 * (1 << 17)),
                    ("tiny 512", 512)]:
    for lc, ir in [(8, 8), (12, 4), (13, 4), (14, 4)]:
        b, rows, depth = endpoint_open_bytes(plane, lc, ir)
        say(f"{name} log_cols {lc}/ir {ir}: rows={rows} depth={depth} "
            f"bytes={b:,} = {b/2**20:.4f} MiB")
    say()

say("== 7b. sweep minimum ==")
for name, plane in [("Mistral 2^21", 1 << 21), ("125M 3*2^17", 3 * (1 << 17))]:
    best = min(((endpoint_open_bytes(plane, lc, 4)[0], lc) for lc in range(8, 21)))
    at14 = endpoint_open_bytes(plane, 14, 4)[0]
    say(f"{name}: optimum log_cols {best[1]} at {best[0]/2**20:.4f} MiB; "
        f"log_cols 14 = {at14/2**20:.4f} MiB; cost of matching the layer "
        f"= {(at14-best[0])/2**20:.4f} MiB per endpoint")
say()

# --------------------------------------------------------------------------
# 8. Per-layer byte deltas
# --------------------------------------------------------------------------
def per_layer(plane_words, log_cols, inv_rate, rounds, nb_d, form):
    n = 1 << log_cols
    Q = 256
    if form == 2:
        sites = 1
        ep_groups = 1
        args = 2
    else:
        sites = nb_d
        ep_groups = nb_d
        args = 2 * nb_d
    mask_rows = 2 * sites + 3
    ep, rows, depth = endpoint_open_bytes(plane_words, log_cols, inv_rate,
                                          mask_rows=mask_rows, groups=ep_groups)
    a_groups_new = 2 * sites                      # one new A group per claim site per side
    a_group_bytes = a_groups_new * (n + Q) * 16
    a_rows = 4 * sites                            # a_io pairs: 2 rows per site per side
    a_row_bytes = 256 * a_rows * 8
    m_rows = 4 * sites
    m_row_bytes = 256 * m_rows * 8
    arg_bytes = args * (1 + rounds * 3 + 2 + 1) * 16
    total = 2 * ep + a_group_bytes + a_row_bytes + m_row_bytes + arg_bytes
    return dict(endpoint_rows=rows, ep_each=ep, a_group_bytes=a_group_bytes,
                a_row_bytes=a_row_bytes, m_row_bytes=m_row_bytes,
                arg_bytes=arg_bytes, total=total, mask_rows=mask_rows)

say("== 8. Per-layer byte delta ==")
mistral = per_layer(1 << 21, 14, 4, rounds=22, nb_d=1, form=2)
say(f"Mistral form 2: {mistral}")
legacy_layer = 1_285_578_368 / 32
say(f"  total {mistral['total']:,} B = {mistral['total']/2**20:.4f} MiB; "
    f"{100*mistral['total']/legacy_layer:.3f}% of {legacy_layer:,.0f} B")
say(f"  32 layers: +{32*mistral['total']:,} B; "
    f"{(1_285_578_368 + 32*mistral['total'])/2**30:.4f} GiB "
    f"(was {1_285_578_368/2**30:.4f} GiB)")
say(f"  rows: 2 endpoints {2*mistral['endpoint_rows']} + A 4 + M 4 = "
    f"{2*mistral['endpoint_rows']+8}")

m125_f2 = per_layer(3 << 17, 14, 4, rounds=18, nb_d=3, form=2)
m125_f1 = per_layer(3 << 17, 14, 4, rounds=18, nb_d=3, form=1)
base125 = 88_356_464 / 12
say(f"125M form 2: total {m125_f2['total']:,} B = {m125_f2['total']/2**20:.4f} MiB"
    f" = {100*m125_f2['total']/base125:.2f}% of {base125:,.1f} B/layer")
say(f"125M form 1: total {m125_f1['total']:,} B = {m125_f1['total']/2**20:.4f} MiB"
    f" = {100*m125_f1['total']/base125:.2f}%  (endpoint rows {m125_f1['endpoint_rows']},"
    f" MASK_ROWS {m125_f1['mask_rows']})")
say(f"ratio of relative costs 125M/Mistral = "
    f"{(m125_f2['total']/base125)/(mistral['total']/legacy_layer):.2f}x")
say()

# --------------------------------------------------------------------------
# 9. Memory / frame constants
# --------------------------------------------------------------------------
say("== 9. Frame constants (zk_ffn_fresh_io.rs:15-18) ==")
say(f"ENDPOINT_OPEN_BYTES = {2*512*16 + 256*(8+7*8+32+11*32):,}")
say(f"ARGUMENT_BYTES      = {16+10*3*16+2*16+16:,}")
say(f"EXTRA_BYTES         = {8+32+2*544+2*131072:,}")
say(f"EXPECTED_BYTES      = {8+32+4+4+2*32:,}")
say(f"MAX_WIRE_BYTES      = {32*1024*1024:,} vs one measured Mistral layer "
    f"40,186,228 B private / 38,688,700 B public")
say(f"seam transient 3 x 2^21 x 16 B = {3*(1<<21)*16:,} B = "
    f"{3*(1<<21)*16/2**20:.1f} MiB = {3*(1<<21)*16/1e6:.1f} MB")
say()

with open(__file__.replace("recompute.py", "recompute.out"), "w") as fh:
    fh.write("\n".join(out) + "\n")
