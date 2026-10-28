"""Cost arithmetic for REPORT.md (chain publication feasibility, 2026-10-21).

Pure arithmetic over the price snapshot in prices_20261021.json; no network,
no wallets. Run: python3 costs.py
"""
import json, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
P = json.load(open(os.path.join(HERE, "prices_20261021.json")))
usd = P["token_usd"]
GIB = 1024 ** 3

# ---- bundle sizes [ESTIMATE] ----
BUNDLES_GB = {"text post (central)": 0.5, "text post (high)": 1.0, "image post": 1.5}

def storage_rows(gb):
    b = gb * 1e9
    gib = b / GIB
    ar_native = P["arweave_winston_per_gib"] / 1e12 * usd["arweave"] * gib
    ar_turbo = P["turbo_usd_per_gib"] * gib
    walrus_mo = (4.5 * gb + 0.064) * P["walrus_usd_per_encoded_gb_month"]
    foc_mo = P["foc_usd_per_tib_month_per_copy"] * 2 * b / 1024 ** 4
    r2_mo = P["r2_usd_per_gb_month"] * gb
    s3_mo = P["s3_usd_per_gb_month"] * gb
    s3_egress = P["s3_egress_usd_per_gb"] * gb
    celestia = P["celestia_usd_per_mb"] * gb * 1000
    eigenda = P["eigenda_usd_per_mb"] * gb * 1000
    return {
        "arweave_native_once": ar_native,
        "arweave_turbo_once": ar_turbo,
        "walrus_per_year": walrus_mo * 12,
        "filecoin_foc_2copies_per_year": foc_mo * 12,
        "r2_per_year": r2_mo * 12,
        "s3_per_year": s3_mo * 12,
        "s3_egress_per_download": s3_egress,
        "celestia_once_ephemeral": celestia,
        "eigenda_once_ephemeral": eigenda,
    }

# ---- anchoring tx cost at measured gas prices ----
ANCHOR_GAS = 60_000       # [ESTIMATE] root -> storage slot (22.1k) + event + calldata + base 21k
GROTH16_GAS = 300_000     # [ESTIMATE] ~250k pairing verify (RISC Zero blog) + router/journal overhead

def evm_cost(gas, gwei, token_usd, l1_fee_wei=0):
    return (gas * gwei * 1e9 + l1_fee_wei) / 1e18 * token_usd

def anchor_rows(gas):
    g = P["gas_gwei"]
    rows = {
        "ethereum_l1": evm_cost(gas, g["ethereum"], usd["ethereum"]),
        "base": evm_cost(gas, g["base"], usd["ethereum"], P["base_l1_fee_upper_250B_wei"]),
        "op_mainnet": evm_cost(gas, g["optimism"], usd["ethereum"], P["op_l1_fee_upper_250B_wei"]),
        "arbitrum_one": evm_cost(gas, g["arbitrum"], usd["ethereum"]),
        "polygon_pos": evm_cost(gas, g["polygon"], usd["polygon-ecosystem-token"]),
    }
    lam = 1e-9 * usd["solana"]
    rows["solana_event_only"] = P["solana_fee_lamports_per_sig"] * lam
    rows["solana_80B_in_account_state"] = (P["solana_fee_lamports_per_sig"] + 80 * P["solana_rent_lamports_per_byte"]) * lam
    return rows

# ---- zkVM wrapper estimate ----
def zkvm_cycles(params_b, receipt_gb, weight_hash="blake3"):
    # weight side
    folds = params_b * 1e9 * 15, params_b * 1e9 * 30  # int8 x Fp2 MAC, cycles
    c_per_b = {"blake3": (18, 25), "accel_sha256": (2, 3)}[weight_hash]
    w_hash = params_b * 1e9 * c_per_b[0], params_b * 1e9 * c_per_b[1]
    # proof side, scaled from the 8B T32 receipt (466 MB): column mults, NTT butterflies
    s = receipt_gb / 0.466
    col = 0.66e9 * s * 60, 0.66e9 * s * 90
    ntt = 3.3e3 * 245_760 * s * 40, 3.3e3 * 245_760 * s * 60
    p_hash = receipt_gb * 1e9 * 18, receipt_gb * 1e9 * 25
    merkle = 0.6e6 * s * 1200, 0.6e6 * s * 1600
    lo = folds[0] + w_hash[0] + col[0] + ntt[0] + p_hash[0] + merkle[0]
    hi = folds[1] + w_hash[1] + col[1] + ntt[1] + p_hash[1] + merkle[1]
    proof_side = (col[0] + ntt[0] + p_hash[0] + merkle[0], col[1] + ntt[1] + p_hash[1] + merkle[1])
    return lo, hi, proof_side

def fmt(x):
    if x == 0: return "0"
    if x < 0.01: return f"{x:.5f}"
    if x < 1: return f"{x:.4f}"
    if x < 100: return f"{x:.2f}"
    return f"{x:,.0f}"

if __name__ == "__main__":
    print("== storage per post (USD) ==")
    for name, gb in BUNDLES_GB.items():
        r = storage_rows(gb)
        print(name, gb, "GB:", {k: fmt(v) for k, v in r.items()})
        print("   x10k posts:", {k: fmt(v * 1e4) for k, v in r.items()})
    print("== anchor tx (USD), 60k gas ==")
    a = anchor_rows(ANCHOR_GAS)
    print({k: fmt(v) for k, v in a.items()})
    print("   per post at 1000 posts/batch:", {k: fmt(v / 1000) for k, v in a.items()})
    print("   per post at 100 posts/batch:", {k: fmt(v / 100) for k, v in a.items()})
    print("== Groth16 verify tx (USD), 300k gas ==")
    print({k: fmt(v) for k, v in anchor_rows(GROTH16_GAS).items() if not k.startswith("solana")})
    print("== Ethereum L1 anchor at stressed gas ==")
    for gw in (1, 10, 50):
        print(gw, "gwei:", fmt(evm_cost(ANCHOR_GAS, gw, usd["ethereum"])))
    print("== zkVM wrapper ==")
    for label, params, rgb, wh in [("Shieldstral text, BLAKE3 weights", 3.4, 0.5, "blake3"),
                                   ("Shieldstral text, accel weight hash", 3.4, 0.5, "accel_sha256"),
                                   ("Llama-3-8B T32", 7.0, 0.466, "blake3")]:
        lo, hi, ps = zkvm_cycles(params, rgb, wh)
        print(label, f"cycles {lo:.2e}..{hi:.2e} (proof side {ps[0]:.1e}..{ps[1]:.1e})")
        for mhz in (5, 10):
            print(f"   @{mhz} MHz/GPU: {lo/mhz/1e6/3600:.1f}..{hi/mhz/1e6/3600:.1f} GPU-h;"
                  f" rental $0.40-1.00/h: ${lo/mhz/1e6/3600*0.4:.2f}..${hi/mhz/1e6/3600*1.0:.2f}")
        print(f"   prover market ${P['boundless_usd_per_bcycle']}/Bcycle: ${lo/1e9*P['boundless_usd_per_bcycle']:.2f}..${hi/1e9*P['boundless_usd_per_bcycle']:.2f}")
        print(f"   laptop CPU at measured 1.75 kHz: {lo/1750/86400/365:.1f}..{hi/1750/86400/365:.1f} years")
    # redesigned verifier: weight commitment opened instead of folding raw weights; proof side only, /3 by precompiles
    print("redesign (no O(params) work, Goldilocks/BLAKE3 accel ~3-5x):")
    _, _, ps = zkvm_cycles(3.4, 0.5)
    for f in (3, 5):
        c = ps[0] / f, ps[1] / f
        print(f"  /{f}: {c[0]:.1e}..{c[1]:.1e} cycles; @5-10 MHz {c[0]/10e6/3600:.2f}..{c[1]/5e6/3600:.2f} GPU-h")
    # direct on-chain: calldata / storage of the raw receipt
    print("== direct on-chain receipt (0.5 GB) ==")
    b = 0.5e9
    print("EVM calldata gas (16/byte nonzero):", f"{b*16:.1e}", "vs block gas limit 60M ->", f"{b*16/60e6:,.0f} blocks")
    print("Solana tx size limit 1232 B ->", f"{b/1232:,.0f} txs; rent-exempt state:", fmt(b * P['solana_rent_lamports_per_byte'] * 1e-9 * usd['solana']), "USD")
    print("Ethereum blobs 128 KiB each ->", f"{b/131072:,.0f} blobs (pruned after ~18 days)")
