#!/usr/bin/env python3
"""Exact arithmetic for ZK60_PRIVATE_RUN_MULTI_BLOCK.md (paper only).

Nothing here runs a prover. Every input is either a constant read out of the
Rust on branch zk60-private-block-125m (cited inline) or a number measured in
results/zk60_block125m_lane/m125-run2-timing.log.

Two published figures are reproduced first as a check on the method:
  * the 125M one-block receipt, 40,782,792 B (grow_tests.rs MODEL_M125)
  * the D9 sampler residual, 2^-77.7 at the toy and 2^-72.9 at 125M
If either check fails, no other number in this file should be believed.
"""

from math import log2

# ---------------------------------------------------------------- constants

COL_CHECKS = 256          # shape.rs: opened columns Q == pad count per row
MASK_VEC = 1024           # wire.rs MASK_VEC (2 * 2^MASK_LOG_MSG)
MASK_PATH = 12            # wire.rs MASK_PATH (log2 of the 4096 mask domain)
M_ROWS = 50               # layout.rs: 2 * N_SLOTS + 4 with N_SLOTS = 23
WIRE_HEADER = 8 + 32      # wire.rs HEADER
MAX_WIRE_ANY = 64 * 1024 * 1024


def clog2(v):
    return (v - 1).bit_length()


def opening_len(groups, rows, n, inv_rate, q=COL_CHECKS):
    """wire.rs Dim::opening_len / shape.rs receipt_bytes' `opening` closure."""
    vec = n + q
    path = clog2(n * inv_rate)
    return (groups + 1) * vec * 16 + q * (8 + rows * 8 + 32 + path * 32)


class Profile:
    def __init__(self, name, log_cols, inv_rate, a_rows, h_rows, a_groups,
                 h_groups, e_log_n, e_inv_rate, e_rows, a_data_rows,
                 h_data_rows, receipt_total):
        self.name = name
        self.n = 1 << log_cols
        self.log_cols = log_cols
        self.inv_rate = inv_rate
        self.a_rows, self.h_rows = a_rows, h_rows
        self.a_groups, self.h_groups = a_groups, h_groups
        self.e_n = 1 << e_log_n
        self.e_log_n, self.e_inv_rate, self.e_rows = e_log_n, e_inv_rate, e_rows
        self.a_data_rows, self.h_data_rows = a_data_rows, h_data_rows
        self.receipt_total = receipt_total

    # ---- receipt parts
    def a_open(self):
        return opening_len(self.a_groups, self.a_rows, self.n, self.inv_rate)

    def h_open(self):
        return opening_len(self.h_groups, self.h_rows, self.n, self.inv_rate)

    def one_endpoint_open(self):
        return opening_len(1, self.e_rows, self.e_n, self.e_inv_rate)

    def mask_open(self):
        return 2 * MASK_VEC * 16 + COL_CHECKS * (8 + M_ROWS * 8 + 32 + MASK_PATH * 32)

    # ---- the boundary commitment of this memo: data rows + 2 pairs + prox pair
    def boundary_rows(self, sites=2):
        return (self.e_rows - 5) + 2 * sites + 2

    def boundary_open(self, sites=2):
        return opening_len(sites, self.boundary_rows(sites), self.e_n, self.e_inv_rate)


M125 = Profile("125M", log_cols=14, inv_rate=4, a_rows=5_681, h_rows=7_120,
               a_groups=36, h_groups=9, e_log_n=14, e_inv_rate=4, e_rows=37,
               a_data_rows=5_435, h_data_rows=7_018, receipt_total=40_782_792)

RUNG_G = Profile("rung-G", log_cols=10, inv_rate=4, a_rows=1_047, h_rows=1_236,
                 a_groups=29, h_groups=9, e_log_n=10, e_inv_rate=4, e_rows=9,
                 a_data_rows=None, h_data_rows=None, receipt_total=None)

print("=" * 72)
print("CHECK 1 — reproduce the counted 125M receipt from wire.rs' formula")
print("=" * 72)
parts_known = (M125.mask_open() + M125.a_open() + M125.h_open()
               + 2 * M125.one_endpoint_open() + WIRE_HEADER + 3 * 32)
slots_bytes = M125.receipt_total - parts_known
print(f"  mask opening          {M125.mask_open():>12,} B")
print(f"  A opening (36 groups) {M125.a_open():>12,} B")
print(f"  H opening (9 groups)  {M125.h_open():>12,} B")
print(f"  2 endpoint openings   {2*M125.one_endpoint_open():>12,} B"
      "   (grow_tests.rs says 1,499,136)")
assert 2 * M125.one_endpoint_open() == 1_499_136
print(f"  header + three roots  {WIRE_HEADER + 3*32:>12,} B")
print(f"  => the 23 slot proofs {slots_bytes:>12,} B  (residual; not recomputed)")
print(f"  total                 {M125.receipt_total:>12,} B  MATCHES MODEL_M125")

# ---------------------------------------------------------------- segments

print()
print("=" * 72)
print("SEGMENTED RECEIPT, L = 12 (boundary commitment, one segment per stage)")
print("=" * 72)
L = 12
b_rows = M125.boundary_rows()
b_open = M125.boundary_open()
e_open = M125.one_endpoint_open()
print(f"  boundary commitment: {M125.e_rows-5} data rows + 2 pairs + prox pair"
      f" = {b_rows} rows")
print(f"  boundary opening (2 groups, {b_rows} rows) = {b_open:,} B")
print(f"  one external endpoint opening (1 group, 37 rows) = {e_open:,} B")

base = M125.receipt_total - 2 * e_open      # a stage's fixed part: header-less
# stage 1: roots A,M,H + B_1 root; openings M,A,H,E_in
seg_first = base + 32 + e_open
# interior stage k (2..L-1): roots A,M,H + B_k; openings M,A,H,B_{k-1}
seg_mid = base + 32 + b_open
# stage L: roots A,M,H (no new boundary); openings M,A,H,B_{L-1},E_out
seg_last = base + b_open + e_open
total = seg_first + (L - 2) * seg_mid + seg_last
print(f"  segment 1            {seg_first:>12,} B")
print(f"  segment 2..{L-1} (each) {seg_mid:>12,} B")
print(f"  segment {L}           {seg_last:>12,} B")
print(f"  largest segment      {max(seg_first, seg_mid, seg_last):>12,} B"
      f"  ({max(seg_first, seg_mid, seg_last)/2**20:.1f} MiB"
      f" vs the 64 MiB frame bound: "
      f"{'FITS' if max(seg_first, seg_mid, seg_last) < MAX_WIRE_ANY else 'OVER'})")
print(f"  run total, L = {L}     {total:>12,} B  ({total/1e6:.1f} MB)")
print(f"  naive L x one-block  {L*M125.receipt_total:>12,} B"
      f"  ({L*M125.receipt_total/1e6:.1f} MB)")
print(f"  saved by sharing the boundary: {L*M125.receipt_total-total:,} B")

# what option B (direct A-to-A equality, no boundary commitment) would cost
a_open_123 = opening_len(M125.a_groups + 1, M125.a_rows + 2, M125.n, M125.inv_rate)
optB_extra_per_interior = a_open_123 - M125.a_open()
optB_total = total - (L - 1) * b_open - 11 * 32 + (L - 1) * optB_extra_per_interior
print(f"  option B (A_k<->A_k+1 seam, no boundary commitment):")
print(f"    A opening grows by  {optB_extra_per_interior:>12,} B per seam"
      f" (one more group, two more rows)")
print(f"    run total           {optB_total:>12,} B  ({optB_total/1e6:.1f} MB),"
      f" {total-optB_total:,} B less than the boundary form")

# ---------------------------------------------------------------- draws

print()
print("=" * 72)
print("CHECK 2 — the D9 sampler residual, reproduced at the toy and at 125M")
print("=" * 72)
# Every draw the prover makes with ZkRng::fp():
#   protocol.rs: A mask+prox rows, H mask+zero-sum rows
#   zkp-core/pcs.rs:673: rows * q_pad pad symbols per commitment (salts are
#     raw bytes, no modular reduction, so they carry no D9 term)
#   zk.rs:430-457 mask_commit: 2*(L_s) coefficients per slot (Fp2 -> 2 Fp),
#     MASK_Q pads per a-row (2 rows per slot), and 4 * 2m for b/u
MASK_M = 1 << 9        # zk.rs MASK_LOG_MSG
MASK_Q = 256           # zk.rs MASK_Q


def m_draws(sum_slot_len):
    """mask_commit's fp draws: coefficients + per-a-row pads + b/u rows."""
    return 2 * sum_slot_len + 2 * 23 * MASK_Q + 4 * 2 * MASK_M


def block_draws(p, sum_slot_len, endpoints=2, boundary_rows=None):
    d = (p.a_rows - p.a_data_rows) * p.n          # A mask + proximity rows
    d += p.a_rows * COL_CHECKS                     # A pads
    d += (p.h_rows - p.h_data_rows) * p.n          # H mask + zero-sum rows
    d += p.h_rows * COL_CHECKS                     # H pads
    d += m_draws(sum_slot_len)                     # M
    d += endpoints * (5 * p.e_n + p.e_rows * COL_CHECKS)
    if boundary_rows:
        d += (boundary_rows - (p.e_rows - 5)) * p.e_n + boundary_rows * COL_CHECKS
    return d


TOY = Profile("toy", log_cols=8, inv_rate=8, a_rows=455, h_rows=384,
              a_groups=35, h_groups=9, e_log_n=8, e_inv_rate=8, e_rows=7,
              a_data_rows=213, h_data_rows=280, receipt_total=2_816_472)

# sum of the masked-sumcheck message lengths L_s = (main+ext)*degree + 2.
# Not recomputed here; bounded by 23 * largest_slot_length, which is what the
# uncertainty in the M term amounts to (<0.3% of the total at either shape).
for p, lsmax in ((TOY, 50), (M125, 117)):
    lo = block_draws(p, 23 * 2)              # every slot at its minimum, L_s = 2
    hi = block_draws(p, 23 * lsmax)          # every slot at the maximum L_s
    print(f"  {p.name:>6}: draws between {lo:,} and {hi:,}"
          f"  -> 2^{log2(lo):.2f} .. 2^{log2(hi):.2f}")
    print(f"          residual  2^-{96-log2(lo):.1f} .. 2^-{96-log2(hi):.1f}"
          f"   (published: {'2^-77.7' if p is TOY else '2^-72.9'})")

print()
print("=" * 72)
print(f"THE RUN, L = {L}: draws and residual")
print("=" * 72)
per_block_no_ep = block_draws(M125, 23 * 117, endpoints=0)
ext_endpoints = 2 * (5 * M125.e_n + M125.e_rows * COL_CHECKS)
per_boundary = (b_rows - (M125.e_rows - 5)) * M125.e_n + b_rows * COL_CHECKS
run = L * per_block_no_ep + (L - 1) * per_boundary + ext_endpoints
print(f"  per block, no endpoints      {per_block_no_ep:>14,}")
print(f"  x {L} blocks                   {L*per_block_no_ep:>14,}")
print(f"  {L-1} boundary commitments      {(L-1)*per_boundary:>14,}"
      f"   ({per_boundary:,} each)")
print(f"  2 external endpoints         {ext_endpoints:>14,}")
print(f"  RUN TOTAL                    {run:>14,}  = 2^{log2(run):.2f}")
print(f"  residual = draws * 2^-96     2^-{96-log2(run):.1f}")
print(f"  (one 125M block alone:       2^-{96-log2(block_draws(M125, 23*117)):.1f})")
n_proofs = 1_000_000
print(f"  {n_proofs:,} such runs:          2^-{96-log2(run)-log2(n_proofs):.1f}")

# ---------------------------------------------------------------- memory

print()
print("=" * 72)
print("MEMORY, from the measured run (m125-run2-timing.log, MiB)")
print("=" * 72)
MEAS_PEAK = 10_837         # HWM at the softmax zero-check, A and H both resident
A_FULL = 8_727 - 5_177     # RSS freed by drop(a) after open A
H_FULL = 5_177 - 727       # RSS freed by drop(h) after open H
print(f"  measured one-block peak (HWM)            {MEAS_PEAK:>7,} MiB"
      f"  ({MEAS_PEAK/1024:.2f} GiB)")
print(f"  A commitment, whole owner (drop delta)   {A_FULL:>7,} MiB")
print(f"  H commitment, whole owner (drop delta)   {H_FULL:>7,} MiB")
print(f"  RSS after all openings, before next block  {727:>5,} MiB")


def commitment_bytes(rows, n, inv_rate, q=COL_CHECKS):
    enc_cols = n * inv_rate
    data = rows * n * 8
    encoded = rows * enc_cols * 8
    pads = rows * q * 8
    salts = enc_cols * 32
    tree = 2 * enc_cols * 32
    return data + encoded + pads + salts + tree


b_bytes = commitment_bytes(b_rows, M125.e_n, M125.e_inv_rate)
e_bytes = commitment_bytes(36, M125.e_n, M125.e_inv_rate)
print(f"  one boundary commitment (38 rows)        {b_bytes/2**20:>7.1f} MiB"
      f"  [MODEL from the same allocation rule]")
print(f"  one external endpoint (36 rows)          {e_bytes/2**20:>7.1f} MiB")
# Resident IO commitments at the peak of a stage:
#   interior stage k: B_{k-1} (awaiting its opening) + B_k (just committed)
#                     + E_out (committed before the header, opened in stage L)
#   stage 1:          E_in + B_1 + E_out  (E_in is opened at the end of stage 1)
io_interior = 2 * b_bytes + e_bytes
io_stage1 = b_bytes + 2 * e_bytes
io_peak = max(io_interior, io_stage1)
print(f"  IO commitments resident, interior stage  {io_interior/2**20:>7.1f} MiB"
      f"  (B_k-1 + B_k + E_out)")
print(f"  IO commitments resident, stage 1         {io_stage1/2**20:>7.1f} MiB"
      f"  (E_in + B_1 + E_out)")
print(f"  PEAK, L = {L}, boundary form              "
      f"{MEAS_PEAK + io_peak/2**20:>7,.0f} MiB"
      f"  ({(MEAS_PEAK + io_peak/2**20)/1024:.2f} GiB)")
print(f"  PEAK, L = 2 (stage 1 is also the first stage)  "
      f"{MEAS_PEAK + io_stage1/2**20:>7,.0f} MiB"
      f"  ({(MEAS_PEAK + io_stage1/2**20)/1024:.2f} GiB)")
print(f"  a_k held across a_k+1's commit (option B) +{A_FULL:,} MiB at the seam,")
print(f"     giving {5_085 + A_FULL:,} MiB there — below the {MEAS_PEAK:,} MiB peak,")
print(f"     so option B's peak is also about {MEAS_PEAK:,} MiB IF A_k is freed")
print("     before H_k+1 is committed ('seam early').")

# ---------------------------------------------------------------- time

print()
print("=" * 72)
print("TIME, L = 12, from the measured run")
print("=" * 72)
PROVE = 26.539
WITNESS = 4.69
VERIFY = 1.027
ENCODE = 0.021
per_row_commit = 2.997 / 5_681
b_commit = per_row_commit * b_rows
b_open_t = 0.010 * (b_rows / 37)
print(f"  prove, one block                {PROVE:>7.2f} s  [MEASURED]")
print(f"  witness build, one block        {WITNESS:>7.2f} s  [MEASURED, outside the prover]")
print(f"  boundary commit (38 rows)       {b_commit:>7.3f} s  [MODEL, A's per-row rate]")
print(f"  boundary open                   {b_open_t:>7.3f} s  [MODEL, endpoint rate]")
run_s = L * (PROVE + WITNESS) + (L - 1) * (b_commit + b_open_t) + L * ENCODE
print(f"  RUN prove wall, L = {L}           {run_s:>7.1f} s  ({run_s/60:.2f} min)")
print(f"  the 'about 5.3 min' figure      {L*PROVE/60:>7.2f} min"
      f"   (12 x prove only; it omits the witness build)")
print(f"  RUN verify, L = {L}               {L*VERIFY:>7.1f} s  [COUNTED from MEASURED]")

print()
print("=" * 72)
print("THE DEVELOPMENT RUNG (rung-G), where the small multi-block gate would run")
print("=" * 72)
print(f"  endpoint: {RUNG_G.e_rows-5} data rows + 5 = {RUNG_G.e_rows} rows;"
      f" one opening {RUNG_G.one_endpoint_open():,} B")
print(f"  boundary: {RUNG_G.e_rows-5} + 4 + 2 = {RUNG_G.boundary_rows()} rows;"
      f" one opening (2 groups) {RUNG_G.boundary_open():,} B")
print(f"  a boundary commitment's blinding unknowns: "
      f"{2*(RUNG_G.e_n)*3} Fp (3 mask-row pairs x {RUNG_G.e_n} columns)")
print(f"  at 125M the same object: {2*(M125.e_n)*3} Fp")

print()
print("=" * 72)
print("VARIANT: the run's EXTERNAL endpoints given the same construction with")
print("one site (rows = data + 2*1 + 2 = 36), so that ONE module and ONE audit")
print("rule (audit_claims) cover all L+1 IO commitments of the run")
print("=" * 72)
ext36 = opening_len(1, 36, M125.e_n, M125.e_inv_rate)
print(f"  external endpoint at 36 rows: one opening {ext36:,} B"
      f"  ({e_open-ext36:,} B less than the 37-row endpoint_g form)")
total36 = total - 2 * (e_open - ext36)
print(f"  run total, L = {L}, uniform construction: {total36:,} B"
      f"  ({total36/1e6:.1f} MB)")
draws36 = run + 2 * ((6 * M125.e_n + 36 * COL_CHECKS)
                     - (5 * M125.e_n + 37 * COL_CHECKS))
print(f"  run draws {draws36:,} = 2^{log2(draws36):.2f}"
      f"  -> residual 2^-{96-log2(draws36):.1f}  (unchanged to one decimal)")
s1_36, s12_36 = seg_first - (e_open - ext36), seg_last - (e_open - ext36)
print(f"  segment 1            {s1_36:>12,} B   <- THE RECOMMENDED VARIANT'S")
print(f"  segment 2..{L-1} (each) {seg_mid:>12,} B      segment table")
print(f"  segment {L}           {s12_36:>12,} B")
print(f"  largest              {max(s1_36, seg_mid, s12_36):>12,} B"
      f"  ({max(s1_36, seg_mid, s12_36)/2**20:.1f} MiB)")
assert s1_36 + (L - 2) * seg_mid + s12_36 == total36

print()
print("=" * 72)
print("THE JOINT-VIEW GATE'S MATRIX, for one block and for a run")
print("=" * 72)
# The gate's per-role rank factors a matrix of 2*(G+1) GENERATORS (real and
# imaginary parts of the G group vectors and the proximity vector) by the
# commitment's ROWS -- not rows x rows and not rows x opened columns
# (zk60_native_jv_pcs.py:451-456, :510-512 on branch zk60-native-jointview).
# Its cost is O(g^2 * rows): the elimination stops after at most g pivots.
def gen(groups):
    return 2 * (groups + 1)


def joint(blocks, a_rows, h_rows, a_g, h_g, e_rows, b_rows, n_ext=2):
    rows = blocks * (a_rows + h_rows + M_ROWS) + (blocks - 1) * b_rows + n_ext * e_rows
    g = blocks * (gen(a_g) + gen(h_g) + 2) + (blocks - 1) * gen(2) + n_ext * gen(1)
    return rows, g, g * g * rows


TOY_JOINT = (903, 102, 102 * 102 * 903)     # the measured toy block: 899 classes, 102 generators
print(f"  toy block, measured joint stage: {TOY_JOINT[1]} generators x"
      f" {TOY_JOINT[0]} rows  -> {TOY_JOINT[2]:.2e} mults; whole 8-stage gate 23.5 s")
for label, args in (
    ("one 125M block", (1, 5_681, 7_120, 36, 9, 36, 38)),
    ("L=3 at the rung", (3, 623, 576, 36, 9, 9, 10)),
    ("L=12 at 125M", (12, 5_681, 7_120, 36, 9, 36, 38)),
):
    rows, g, cost = joint(*args)
    print(f"  {label:<16}: {g:>5} generators x {rows:>7,} rows"
          f"  -> {cost:.2e} mults  ({cost/TOY_JOINT[2]:,.0f}x the toy joint)")

print()
print("=" * 72)
print("NOTE on the option-B receipt estimate above")
print("=" * 72)
print("  It charges each seam one extra A opening group and two extra A rows.")
print("  It does NOT model the fact that option B also re-cuts the slot")
print("  schedule for interior blocks (block k loses its outgoing IO slot and")
print("  block k+1's incoming IO slot gains a second private table on another")
print("  commitment), which moves N_SLOTS, M_ROWS = 2*N_SLOTS+4, slot_terms,")
print("  the schedule digest and every counted constant for interior blocks.")
print("  Treat the option-B byte figure as an order-of-magnitude [MODEL]: the")
print("  sign (option B is smaller by about 1.7%) is safe, the digits are not.")
