"""Tick 7 arithmetic: what a FlashProve-style contraction vector (U3) would add to the local schedule.
Standard library only, reads no file, under a second. Inputs are COUNTED figures cited in the handoff."""
import math

ROW = 1 << 14                # local row width, log_cols 14 (shape.rs, R13_8B / W16R2_8B profiles)
BLOCK_ROWS = 5103            # whole block today (cycle 6a)
A_DATA_ROWS = 2279           # tick 6
CELL_ROWS = 2256             # tick 6
SITES = 120                  # A claim sites per block (layout.rs:1203 asserts A_SITES at every shape; sum = 120)
tau = 128

print("rows of A data after B (tick 6):", "1,077 .. 1,532 of 2,279")
save_lo, save_hi = A_DATA_ROWS - 1532, A_DATA_ROWS - 1077
print("A data rows saved:", save_lo, save_hi)

for label, reads in (("all 120 sites are cell reads (bound)", 120), ("half of them (ASSUMED)", 60)):
    for k in (4096, 14336):
        u_words = reads * k * 2                 # Fp2 entries per column, 2 words each
        u_data_rows = math.ceil(u_words / ROW)
        u_mask_rows = 2 * reads                 # one reserved pair per claim (protocol.rs audit_claims)
        u_rows = u_data_rows + u_mask_rows + 2  # + proximity pair
        print(f"{label}, k={k}: U data rows {u_data_rows}, mask rows {u_mask_rows}, total {u_rows};"
              f" share of saving {u_rows/save_hi:.2f}..{u_rows/save_lo:.2f};"
              f" block change {u_rows/BLOCK_ROWS:+.3f}")

# whole block range with U added to tick 6's 0.76 .. 0.85 (before helper adjustment)
lo = 0.76 + (60 * 4096 * 2 // ROW + 120 + 2) / BLOCK_ROWS
hi = 0.85 + (120 * 14336 * 2 // ROW + 240 + 2 + 1) / BLOCK_ROWS
print(f"whole block with U: {lo:.2f} .. {hi:.2f} of today (tick 6 helper effect not added)")

# digit term at the local width
for k in (4096, 7168):
    cells = CELL_ROWS * ROW
    mz = cells / k
    zz = 2 * tau * mz
    print(f"k={k}: cell-matrix rows {mz:,.0f}, ZZ words {zz/1e6:.2f} M = {zz/ROW:.0f} local rows, {zz/cells:.4f} of cells")

# smallness-test union bound over columns (matrices <= 48 A planes, 32 blocks)
for k in (4096, 14336):
    cols = 48 * k * 32
    print(f"union over <= {cols:,} columns (2^{math.log2(cols):.1f}): {tau - math.log2(cols):.1f} bits at tau=128")
b_run = 97.3; extra = 2 ** (-(tau - math.log2(48 * 14336 * 32)))
print("whole-run bound 2^-97.3 plus worst smallness term: 2^-%.2f" % -math.log2(2 ** -97.3 + extra))

# verifier work for Theta's multilinear extension: tau x k ternary entries per distinct column point
for k in (4096, 7168):
    print(f"Theta table tau*k = {tau*k:,} entries per matrix point; x30 groups x32 blocks = {tau*k*30*32/1e9:.2f} G adds")
