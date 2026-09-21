#!/usr/bin/env python3
"""Every BLAKE3 query kind on the TOY private block's path, re-derived from the
MAIN tree's code at commit 4751b93, with exact lengths, and the length-coincidence
and one-byte-margin analysis.

Nothing here is read from a memo. Every constant below carries the source line
it was read from, at `4751b93` in /home/victor/IntelligenceRegulation.

Reviewer: independent adversarial checker, 2026-09-21.
"""

from itertools import combinations
import json

# ---------------------------------------------------------------- geometry
# hashline/src/private_block/layout.rs
T, D, H_HEADS, DH, HALF, KV, F = 32, 16, 2, 8, 4, 8, 16
LOG_N, N = 8, 256                       # layout.rs:48-49
A_ROWS, H_ROWS, M_ROWS = 455, 384, 50   # layout.rs:523-524, :519
A_DATA_ROWS, H_DATA_ROWS = 213, 280     # layout.rs:525-526
ENDPOINT_ROWS = 7                       # private_block/protocol.rs:184
N_SLOTS = 23                            # layout.rs:386
INV_RATE = 8                            # protocol.rs:22
NUM_COL_CHECKS = 256                    # protocol.rs:22
Q_PAD = NUM_COL_CHECKS                  # pcs.rs:542-543 ZkOpts::standard
NN = N * INV_RATE                       # 2048 encoded columns per 256-col commitment
MASK_LOG_MSG, MASK_LOG_DOM, MASK_Q = 9, 12, 256   # hashline/src/zk.rs:373-375
MASK_DOM = 1 << MASK_LOG_DOM            # 4096

# layout.rs:438-462  SLOTS = (main rounds, extension rounds, degree)
SLOTS = [(9,1,3),(9,1,3),(5,1,3),(9,1,4),(11,1,3),(4,1,2),(4,1,2),(4,1,2),
         (3,2,2),(5,2,2),(4,1,2),(4,1,2),(4,1,2),(4,1,2),(9,1,4),(9,1,4),
         (8,1,4),(11,1,4),(9,1,4),(8,1,3),(8,1,2),(9,1,2),(9,1,2)]
# layout.rs:512-513
A_SITES = [1,1,22,2,2,1,1,1,2,2,1,1,1,1,37,8,7,13,11,3,0,1,1]
H_SITES = [0,0,0,1,0,0,0,0,0,0,0,0,0,0,19,7,6,8,6,3,1,0,0]
SC_IO_IN = 21
A_GROUPS, H_GROUPS, N_FUNCTIONALS = 35, 9, 34   # layout.rs:516-518

def slot_terms(s):                      # layout.rs:529-531
    return A_SITES[s] + H_SITES[s] + (1 if s >= SC_IO_IN else 0)

# ---------------------------------------------------------------- literals
PROFILE = b"hashline-zk-mr1/private-block-t32-poc/1"            # private_block.rs:86
SEAM_DOMAIN = b"experimental-private-seam/v1"                   # private_seam.rs:26
TR_PREFIX = b"hashline-v1/"                                     # transcript.rs:27
OS_RNG_CTX = b"hashline-zk-os-rng/v1/"                          # rng.rs:48
PARAMETERS = (b"T32/d16/f16/H2/KV1/dh8/log_cols8/inv_rate8/Q256/P1/"
              b"sh-g7-u0-h14-z6/two-private-endpoints/one-proof-one-transcript")  # protocol.rs:33
CALIB_LIT = b"B3 public fixed calibration v1"                   # private_block.rs:97
BLOCKPUBLIC_LIT = b"hashline/private-block-public/1"            # private_block.rs:262
SCHEDULE_LIT = b"hashline/private-block-schedule/1"             # layout.rs:680
EXPECTED_BYTES = 8 + 32 + 4 + 4 + 2 * 32                        # private_block.rs:88  = 112

def absorb(label: bytes, data_len: int) -> int:
    """transcript.rs:44-52  state(32) || le64(|label|) || label || le64(|data|) || data"""
    return 32 + 8 + len(label) + 8 + data_len

SQUEEZE = 32 + len(b"squeeze") + 8            # transcript.rs:85-94  -> 47

# ---------------------------------------------------------------- the query table
# Each row: (id, kind, mode, key, input layout, length(s), count per proof, secret?)
rows = []

def add(qid, kind, mode, layout, lengths, count, secret, site):
    rows.append(dict(id=qid, kind=kind, mode=mode, layout=layout,
                     lengths=lengths, count=count, secret=secret, site=site))

# --- transcript ------------------------------------------------------------
add("T1", "transcript constructor", "unkeyed",
    '"hashline-v1/"(12) || PROFILE(39)', [len(TR_PREFIX) + len(PROFILE)], 1, False,
    "zkp-core/src/transcript.rs:25-30 via private_block/protocol.rs:30")

header_absorbs = [
    (b"expected-IO",      EXPECTED_BYTES,  "private_block/protocol.rs:31"),
    (b"public-statement", 32,              "protocol.rs:32"),
    (b"parameters",       len(PARAMETERS), "protocol.rs:33"),
    (b"calibration",      32,              "protocol.rs:35"),
    (b"schedule",         32,              "protocol.rs:36"),
]
for lab, dl, site in header_absorbs:
    add("T3", f'absorb "{lab.decode()}"', "unkeyed",
        f'state(32)||le64||{lab.decode()}||le64||data({dl})', [absorb(lab, dl)], 1, False, site)

# absorb_root: A (:320), H (:377); M root absorbed alone (:326)
add("T3", 'absorb "A" / "H" / "M" (a 32-byte root)', "unkeyed",
    'state||le64(1)||label||le64(32)||root', [absorb(b"A", 32)], 3, False,
    "protocol.rs:40-44 (:320, :377), :326")
add("T3", 'absorb_u64 "rows"', "unkeyed", 'state||le64(4)||"rows"||le64(8)||le64(rows)',
    [absorb(b"rows", 8)], 2, False, "protocol.rs:42")
add("T3", 'absorb_u64 "log-cols"', "unkeyed",
    'state||le64(8)||"log-cols"||le64(8)||le64(8)', [absorb(b"log-cols", 8)], 2, False,
    "protocol.rs:43  <-- the 64-byte absorb")

add("T3", 'absorb_u64 "pb-slot"', "unkeyed", 'state||le64(7)||"pb-slot"||le64(8)||le64(s)',
    [absorb(b"pb-slot", 8)], N_SLOTS, False, "private_block/argument.rs:270")
add("T3", 'absorb_fp2 "pb-scalar" (1 Fp2)', "unkeyed", 'state||...||16 bytes',
    [absorb(b"pb-scalar", 16)], N_SLOTS, False, "argument.rs:290, :321")
sc_round_lengths = sorted({absorb(b"sc-round", 16 * (d + 1)) for (_, _, d) in SLOTS})
n_sc_round = sum(n + e for (n, e, _) in SLOTS)
add("T3", 'absorb_fp2 "sc-round" (d+1 Fp2)', "unkeyed", 'state||...||16(d+1) bytes',
    sc_round_lengths, n_sc_round, False, "sumcheck/zk.rs:994 and the masked rounds")
pb_term_lengths = sorted({absorb(b"pb-term", 16 * slot_terms(s)) for s in range(N_SLOTS)})
add("T3", 'absorb_fp2 "pb-term" (slot_terms Fp2)', "unkeyed", 'state||...||16k bytes',
    pb_term_lengths, N_SLOTS, False, "argument.rs:350")

add("T3", 'absorb_fp2 "mask-q" (1024 Fp2)', "unkeyed", 'state||...||16384 bytes',
    [absorb(b"mask-q", 16 * 2 * (1 << MASK_LOG_MSG))], 1, False, "hashline/src/zk.rs:533, :562")
add("T3", 'absorb_fp2 "mask-prox" (1024 Fp2)', "unkeyed", 'state||...||16384 bytes',
    [absorb(b"mask-prox", 16 * 2 * (1 << MASK_LOG_MSG))], 1, False, "zk.rs:542, :565")

pcs_vec_data = 16 * (N + Q_PAD)     # n message + Q pad entries, Fp2
n_pcs_vec = A_GROUPS + H_GROUPS + 1 + 1        # A, H, in, out group vectors
add("T3", 'absorb_fp2 "pcs-vec"', "unkeyed", f'state||...||{pcs_vec_data} bytes',
    [absorb(b"pcs-vec", pcs_vec_data)], n_pcs_vec, False, "zkp-core/src/pcs.rs:924-926, :981-983")
add("T3", 'absorb_fp2 "pcs-prox"', "unkeyed", f'state||...||{pcs_vec_data} bytes',
    [absorb(b"pcs-prox", pcs_vec_data)], 4, False, "pcs.rs:927, :987")

# --- squeezes --------------------------------------------------------------
# definition challenges per slot, read from argument.rs:543-911
DEF_CH = [5, 5, 5+6+2, 9, 6+1, 5+4, 3, 3, 1+5+5, 1+5+3, 5+4, 5+4, 4, 5+4,
          9+(11+19)+2, 9+(1+7)+2, 8+(1+6)+2, 11+(5+7+1)+2, 9+(4+5)+2, 8+3, 0, 9, 9]
assert len(DEF_CH) == N_SLOTS
slot_squeezes = sum(DEF_CH) + N_SLOTS + sum(n + e for (n, e, _) in SLOTS)
n_a_claims, n_h_claims = sum(A_SITES), sum(H_SITES) + 1      # + the LogUp sum claim
idx_squeezes = lambda n_idx: (n_idx + 3) // 4                 # 4 indices per 32-byte squeeze
mask_squeezes = 1 + (2 * N_SLOTS + 2) + idx_squeezes(MASK_Q)
a_open_sq = n_a_claims + A_ROWS + idx_squeezes(NUM_COL_CHECKS)
h_open_sq = n_h_claims + H_ROWS + idx_squeezes(NUM_COL_CHECKS)
ep_open_sq = 1 + ENDPOINT_ROWS + idx_squeezes(NUM_COL_CHECKS)
live_squeezes = 3 + slot_squeezes + mask_squeezes + a_open_sq + h_open_sq + 2 * ep_open_sq
replay_squeezes = (n_a_claims + A_ROWS) + (n_h_claims + H_ROWS) + 2 * (1 + ENDPOINT_ROWS)

add("T4a", "transcript squeeze, live chain", "unkeyed",
    'state(32)||"squeeze"(7)||le64(counter)(8)', [SQUEEZE], live_squeezes, False,
    "transcript.rs:85-94")
add("T4c", "squeeze off a clone: the REFUSAL REPLAY (same points as T4a)", "unkeyed",
    'identical to T4a', [SQUEEZE], replay_squeezes, False,
    "protocol.rs:173-174 (check_opening), :201-202 (endpoints); pcs.rs:835-855")

# --- commitment layer ------------------------------------------------------
col_digest = {"A": 8 * A_ROWS, "H": 8 * H_ROWS, "M": 8 * M_ROWS,
              "endpoint": 8 * ENDPOINT_ROWS}
add("P1/P2", "column digest (A / H / M / endpoint)", "unkeyed",
    "the column's `rows` words, LE, no tag, no length prefix",
    sorted(set(col_digest.values())), 4 * NN + MASK_DOM, True,
    "pcs.rs:137-143, :147-166; hashline/src/zk.rs:592-595")
N_LEAF = 4 * NN + MASK_DOM
add("P3", "salted leaf  blake3(digest(32) || salt(32))", "unkeyed", "64 untagged bytes",
    [64], N_LEAF, True, "pcs.rs:640-645 (:689), zk.rs:464")
N_NODE = 4 * (NN - 1) + (MASK_DOM - 1)
add("P4", "Merkle inner node  blake3(left(32) || right(32))", "unkeyed", "64 untagged bytes",
    [64], N_NODE, True, "zkp-core/src/merkle.rs:14-19")

# --- generator -------------------------------------------------------------
add("R1", "generator seed derivation (block)", "KEYED, key = 32 B /dev/urandom",
    '"hashline-zk-os-rng/v1/"(22) || PROFILE(39)', [len(OS_RNG_CTX) + len(PROFILE)], 1, True,
    "rng.rs:44-51 via protocol.rs:275")
add("R1", "generator seed derivation (each endpoint)", "KEYED, key = 32 B /dev/urandom",
    '"hashline-zk-os-rng/v1/"(22) || seam domain(28)',
    [len(OS_RNG_CTX) + len(SEAM_DOMAIN)], 2, True, "rng.rs:44-51 via private_seam.rs:196")
add("R2", "generator refill (XOF -> 8192 B)", "unkeyed XOF",
    "key(32) || le64(counter)(8)", [40], None, True, "rng.rs:53-61")

# --- public digests --------------------------------------------------------
add("D1", "calibration identity", "unkeyed", 'b"B3 public fixed calibration v1"',
    [len(CALIB_LIT)], 2, False, "private_block.rs:96-98 (prover and verifier)")

def blockpublic_digest_len():
    """private_block.rs:155-166 + :221-231 + :260-266"""
    n = len(BLOCKPUBLIC_LIT)
    for w in (D*D, KV*D, KV*D, D*D, D):            # wq wk wv wo gamma_a  (i8)
        n += 8 + w
    for t in (T*HALF, T*HALF, 256):                # rope_cos rope_sin exp (i64)
        n += 8 + 8*t
    for w in (D, D*F, D*F, F*D):                   # gamma_m wg_t wu_t wd_t (i8)
        n += 8 + w
    n += 8 + 2*256                                 # act (i16)
    return n

add("D2", "block public-statement digest", "unkeyed",
    'b"hashline/private-block-public/1"(31) || length-framed public words',
    [blockpublic_digest_len()], 2, False, "private_block.rs:260-266")

def schedule_digest_len():
    """layout.rs:652-686 -- the exact describe() lines of the toy."""
    SLOT_NAMES = [
        "01 SS row sums norm_a (private)", "01m SS row sums norm_m (private)",
        "02 norm squares zero-check (hosts 01, 01m)", "08 limb zero-check",
        "07 masked row sums + selector (private)", "09Q matmul (private)",
        "09K matmul (private)", "09V matmul (private)",
        "10 score matmul (private, bilinear)", "11 PV matmul (private, bilinear)",
        "12 Wo matmul (private)", "13G gate matmul (private)", "13U up matmul (private)",
        "13D down matmul (private)", "03 D zero-check (hosts 12, 13D)",
        "04 Q zero-check (hosts 09Q, 11)", "05 KV zero-check (hosts 09K, 09V)",
        "06 softmax zero-check (hosts 07, 10)", "14 F zero-check (hosts 13G, 13U)",
        "TAB table helper zero-check", "ZS zero-sum row", "IO-in endpoint equality",
        "IO-out endpoint equality"]
    KINDS = (["Private"]*2 + ["Host", "Standalone", "Private"] + ["Private"]*9
             + ["Host"]*5 + ["Standalone"]*4)
    # re-order exactly as SLOT_KINDS in layout.rs:474-498
    KINDS = ["Private","Private","Host","Standalone","Private","Private","Private",
             "Private","Private","Private","Private","Private","Private","Private",
             "Host","Host","Host","Host","Host","Standalone","Standalone",
             "Standalone","Standalone"]
    a_prefix = sum(A_SITES); h_prefix = sum(H_SITES)
    a_mask_base, h_mask_base = A_DATA_ROWS, H_DATA_ROWS
    a_prox = a_mask_base + 2*a_prefix; h_prox = h_mask_base + 2*h_prefix
    h_u = [26*N//N, 0]          # placeholder, replaced below
    # h_off[H_U]: H_U = 50 is a Dom::Tab plane (log 8 -> 1 row each for re, im).
    # rows before it: sum over planes 0..49 of 2*rows_of(dom.log())
    def rows_of(log): return ((1 << log) + N - 1)//N
    def h_dom_log(p):
        if p == 0: return 9                       # H_L  Dom::L
        if 1 <= p <= 19: return 9                 # Dom::D
        if 20 <= p <= 26: return 9                # Dom::Q
        if 27 <= p <= 32: return 8                # Dom::Kv
        if 33 <= p <= 40: return 11               # Dom::S
        if 41 <= p <= 46: return 9                # Dom::F
        return 8                                  # Dom::Tab
    row = 0
    for p in range(50):
        row += 2*rows_of(h_dom_log(p))
    h_u = [row, row + rows_of(8)]
    lines = [
        f"private-block-t32/1: T{T} d{D} H{H_HEADS} KV1 dh{DH} F{F}; n={N} inv_rate=8 Q=256; "
        f"P1 (weights public, no W commitment); whole block (attention, norm_m, feed-forward, residual 2)",
        f"A rows={A_ROWS} data={A_DATA_ROWS} site-pairs={a_prefix} prox-pair=({a_prox},{a_prox+1})",
        f"H rows={H_ROWS} data={H_DATA_ROWS} site-pairs={h_prefix} zero-sum-pair={h_u} prox-pair=({h_prox},{h_prox+1})",
        f"M rows={M_ROWS} functionals={N_FUNCTIONALS} A-groups={A_GROUPS} H-groups={H_GROUPS} collapse=0",
        "calibration: norm tn=11 cn=1024 ceps=1 wrho=29; shifts qkv=7 rope=7 score=6 o=9 ao=7 "
        "residual=0; fE=9 fP=9 fRo=7 wrhoS=14 mask=-127; classes int8=[-127,127] int16; tables U8 + exp",
        "feed-forward: F=16 shifts gate=7 up=0 product=14 down=6 residual2=0; gate class int8=[-128,127]; "
        "tables U8 + exp + act",
    ]
    for s in range(N_SLOTS):
        n_, e_, d_ = SLOTS[s]
        lines.append(f"slot {s:02} [{SLOT_NAMES[s]}] main={n_} ext={e_} degree={d_} "
                     f"kind={KINDS[s]} A-sites={A_SITES[s]} H-sites={H_SITES[s]}")
    HOSTS = [(2, [0, 1]), (14, [10, 13]), (15, [5, 9]), (16, [6, 7]), (17, [4, 8]), (18, [11, 12])]
    for host, hosted in HOSTS:
        lines.append(f"host {host:02} <- {hosted}")
    n = len(SCHEDULE_LIT)
    for line in lines:
        n += 8 + len(line.encode())
    return n, len(lines)

sched_len, sched_lines = schedule_digest_len()
add("D3", "block schedule digest", "unkeyed",
    'b"hashline/private-block-schedule/1"(33) || sum(le64(len)||line)',
    [sched_len], 2, False, f"layout.rs:678-686 ({sched_lines} lines; RUST-STRING-DEPENDENT)")

add("D8", "frozen-seam spec digest", "unkeyed",
    'DOMAIN(28) || ctx(32) || 8 x u64 || i32',
    [len(SEAM_DOMAIN) + 32 + 8*8 + 4], 6, False, "private_seam.rs:115-133")

# ---------------------------------------------------------------- analysis
def report():
    out = []
    out.append("=" * 78)
    out.append("THE TOY'S BLAKE3 QUERY TABLE, RE-DERIVED FROM MAIN AT 4751b93")
    out.append("=" * 78)
    for r in rows:
        out.append(f"[{r['id']:7s}] {r['kind']}")
        out.append(f"          mode={r['mode']}  lengths={r['lengths']}  "
                   f"count/proof={r['count']}  secret={r['secret']}")
        out.append(f"          {r['site']}")
    # length coincidences over the UNKEYED family (the legacy rule: one function)
    unkeyed = {}
    for r in rows:
        if r["mode"].startswith("KEYED"):
            continue
        for L in r["lengths"]:
            unkeyed.setdefault(L, []).append(f"{r['id']} {r['kind']}")
    out.append("")
    out.append("-" * 78)
    out.append("LENGTH COINCIDENCES inside the ONE unkeyed function (legacy rule)")
    out.append("-" * 78)
    clashes = {L: v for L, v in unkeyed.items() if len(v) > 1}
    for L in sorted(clashes):
        out.append(f"  {L:>7} bytes : {len(clashes[L])} kinds")
        for k in clashes[L]:
            out.append(f"            - {k}")
    out.append(f"  TOTAL distinct unkeyed lengths: {len(unkeyed)};  clashing lengths: {len(clashes)}")
    out.append("")
    out.append(f"  47 (squeeze) occupied by anything else?  "
               f"{'YES' if len(unkeyed.get(47, [])) > 1 else 'NO'}")
    out.append(f"  40 (refill)  occupied by anything else?  "
               f"{'YES' if len(unkeyed.get(40, [])) > 1 else 'NO'}")
    # one-byte margins
    out.append("")
    out.append("-" * 78)
    out.append("ONE-BYTE MARGINS between unkeyed input kinds on the toy's path")
    out.append("-" * 78)
    ls = sorted(unkeyed)
    for a, b in zip(ls, ls[1:]):
        if b - a == 1:
            out.append(f"  {a} vs {b}: {unkeyed[a]}  |  {unkeyed[b]}")
    # keyed family (R1) versus the unkeyed lengths - separated by MODE, not length
    out.append("")
    out.append("  (keyed R1 inputs, separated by mode not length: "
               f"{[r['lengths'] for r in rows if r['mode'].startswith('KEYED')]})")
    for r in rows:
        if r["mode"].startswith("KEYED"):
            for L in r["lengths"]:
                near = [x for x in ls if abs(x - L) <= 1]
                if near:
                    out.append(f"  R1 at {L} B is within one byte of unkeyed "
                               f"{near} -> {[unkeyed[x] for x in near]}")
    # counts
    out.append("")
    out.append("-" * 78)
    out.append("COUNTS PER PROOF")
    out.append("-" * 78)
    n_absorb = sum(r["count"] for r in rows
                   if r["id"] == "T3" and r["count"] is not None)
    out.append(f"  absorbs                          : {n_absorb}")
    out.append(f"  live squeezes (distinct points)  : {live_squeezes}")
    out.append(f"    slots {slot_squeezes}  (definition {sum(DEF_CH)} + c {N_SLOTS} "
               f"+ rounds {sum(n+e for (n,e,_) in SLOTS)})")
    out.append(f"    logup 3, mask {mask_squeezes}, A {a_open_sq}, H {h_open_sq}, "
               f"endpoints {2*ep_open_sq}")
    out.append(f"  refusal-replay squeezes (DUPLICATE points): {replay_squeezes}")
    out.append(f"  A := absorbs + distinct squeeze points = {n_absorb + live_squeezes}")
    out.append(f"  A including the replay's repeated CALLS  = "
               f"{n_absorb + live_squeezes + replay_squeezes}")
    out.append(f"  the memo's bound A <= 4000 holds: "
               f"{n_absorb + live_squeezes + replay_squeezes <= 4000}")
    out.append(f"  encoded columns / salts drawn N_leaf = {N_LEAF}")
    out.append(f"  internal nodes              N_node = {N_NODE}")
    out.append(f"  N_overlap = N_leaf + N_node        = {N_LEAF + N_NODE}")
    out.append(f"  A claims {n_a_claims} in {A_GROUPS} groups; H claims {n_h_claims} "
               f"in {H_GROUPS} groups")
    return "\n".join(out), dict(
        n_absorb=n_absorb, live_squeezes=live_squeezes, replay_squeezes=replay_squeezes,
        N_leaf=N_LEAF, N_node=N_NODE, N_overlap=N_LEAF + N_NODE,
        clashes={str(k): v for k, v in clashes.items()},
        lengths=sorted(unkeyed), n_a_claims=n_a_claims, n_h_claims=n_h_claims,
        blockpublic_digest_len=blockpublic_digest_len(), schedule_digest_len=sched_len,
        parameters_literal=len(PARAMETERS),
        absorb_parameters=absorb(b"parameters", len(PARAMETERS)),
        absorb_expected_io=absorb(b"expected-IO", EXPECTED_BYTES),
        sc_round_lengths=sc_round_lengths, pb_term_lengths=pb_term_lengths,
    )

if __name__ == "__main__":
    text, data = report()
    print(text)
    with open(__file__.rsplit("/", 1)[0] + "/toy_query_table.json", "w") as f:
        json.dump(data, f, indent=1, sort_keys=True)
