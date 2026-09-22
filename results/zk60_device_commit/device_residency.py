#!/usr/bin/env python3
"""Device residency of the hiding commitment, counted from the allocation
sites. [COUNTED] -- nothing here is measured and nothing runs on a device.

SOURCES (main repo /home/victor/IntelligenceRegulation at 78531ea unless
said otherwise; the lane worktree /home/victor/wt-zk60-block125m at a8e4939
for the shapes):

  hashline/src/gpu/cuda.rs
    :3602-3748  dev_commit_zk_from -- the hiding commit's device entry
    :3619-3626  the source's OWN peak formula, quoted below
    :3632-3634  chunked_now = rows*nn*8 > chunk_bytes()   [default 1 GiB]
    :3656-3657  the resident arm's two takes: rows*n and rows*nn
    :3708       the third take, rows*nn, while rows*nn is still live
    :1813-1857  commit_zk_chunked -- the CL1 arm's buffer sizes
    :2105-2113  chunk_rows(): HL_GPU_CHUNK_ROWS, default 128, floor 128
    :2116-2129  chunk_plan: every chunk but the last a multiple of 128 rows
    :2063-2066  chunk_bytes(): HL_GPU_CHUNK_BYTES, default 1 << 30
    :2130       B3_STATE_SLOTS = 8 * 24 + 1 = 193 u32 per column
    :1586-1610  DevCommit / ZkReenc -- what SURVIVES the commit

The source's own formula, verbatim from cuda.rs:3619-3626:

    The hiding commitment's peak is
      [rows*(n + q + 2*nn) + nn] * 8 bytes
    because BOTH `rows*nn` buffers are live across the expand NTT. At the
    Mistral W shape that is 12,142 MiB, and the single `rows*nn` take is
    5,387 MiB -- the allocation that died on 2026-09-04. [...] Chunked, the
    same shape peaks at ~1,563 MiB.

This script reproduces that formula at our shapes and adds the two things
it leaves out (the leaf buffer and the twiddle tables), then does the same
for the chunked arm, and finally says which arm each shape actually TAKES
under the default switches.
"""

import json
import os

LANE = "/home/victor/wt-zk60-block125m"
MODELS = os.path.join(LANE, "results/zk60_block125m_lane")

W = 8                      # bytes per Fp / u64
COL_CHECKS = 256
CHUNK_BYTES_DEFAULT = 1 << 30      # cuda.rs:2063-2066
CHUNK_ROWS_DEFAULT = 128           # cuda.rs:2105-2113
B3_STATE_SLOTS = 193               # cuda.rs:2130
CARD_8GB = 8188 * 1024 * 1024      # the laptop 4070's usable VRAM, as the
                                   # five-second plan's CL1 row records it
CARD_32GB = 32 * 1000 ** 3         # the 5090, BLACKWELL_5090_RUNBOOK.md:21
IR_ROUND_LOOP_TABLES = int(4.829 * 1024 ** 3)   # ZK60_SLOT_EXPRESSION_IR_
                                   # DESIGN_CHECK.md sec 10 [COUNTED there]


def twiddle_bytes(log_nn):
    """ensure_twiddles uploads two stage-major tables of (1<<ml)-1 entries."""
    return 2 * ((1 << log_nn) - 1) * W


def resident_peak(rows, n, nn, q):
    """cuda.rs:3619-3621's formula, plus the leaf buffer and the twiddles."""
    core = (rows * (n + q + 2 * nn) + nn) * W
    leaves = nn * 8 * 4
    return core + leaves + twiddle_bytes(nn.bit_length() - 1), core


def chunked_peak(rows, n, nn, q, rmax=CHUNK_ROWS_DEFAULT, compact_pad=False):
    """commit_zk_chunked's live set at its widest moment."""
    pw = (n + q) if compact_pad else nn          # zk_pad_width, cuda.rs:220
    persistent = (rows * n + rows * q + nn) * W  # d_data, d_pads, d_pows
    scratch = ((rmax * n) + (rmax * pw) + (rmax * nn)) * W
    state = B3_STATE_SLOTS * nn * 4
    leaves = nn * 8 * 4
    tw = twiddle_bytes(nn.bit_length() - 1)
    return dict(persistent=persistent, scratch=scratch, state=state,
                leaves=leaves, twiddles=tw,
                peak=persistent + scratch + state + leaves + tw)


def survives(rows, n, nn, q, chunked):
    """What DevCommit holds from the end of the commit until the opening.

    cuda.rs:1591-1602: `enc` is None for a chunked commitment -- the
    encoding was never resident and `dev_columns` re-encodes it chunk by
    chunk, which is why a chunked hiding commitment KEEPS the pads and the
    coset powers instead."""
    if chunked:
        return (rows * n + rows * q + nn) * W
    return (rows * n + rows * nn) * W


def gib(x):
    return x / 1024.0 ** 3


def mib(x):
    return x / 1024.0 ** 2


def load(fn):
    with open(os.path.join(MODELS, fn)) as f:
        return json.load(f)


def commitments_of(model):
    sh, rw, og = model["shape"], model["rows"], model["opening_groups"]
    n = 1 << sh["log_cols"]
    nn = n * sh["inv_rate"]
    e_n = 1 << sh["endpoint_log_n"]
    e_nn = e_n * sh["endpoint_inv_rate"]
    return [
        ("A", rw["a_rows"], n, nn),
        ("H", rw["h_rows"], n, nn),
        ("endpoint-in", sh["endpoint_rows"], e_n, e_nn),
        ("endpoint-out", sh["endpoint_rows"], e_n, e_nn),
    ]


def report(label, fn, out):
    model = load(fn)
    cms = commitments_of(model)
    q = COL_CHECKS
    print("=" * 78)
    print(f"{label}")
    print("=" * 78)
    rows_out = []
    held_total = 0
    peak_running = 0
    for name, rows, n, nn in cms:
        want = rows * nn * W
        chunked = want > CHUNK_BYTES_DEFAULT
        rp, rp_core = resident_peak(rows, n, nn, q)
        ch = chunked_peak(rows, n, nn, q)
        keep = survives(rows, n, nn, q, chunked)
        arm = "CHUNKED" if chunked else "resident"
        # the peak DURING this commit = everything earlier commitments still
        # hold, plus this commit's own peak
        this_peak = held_total + (ch["peak"] if chunked else rp)
        peak_running = max(peak_running, this_peak)
        held_total += keep
        print(f"\n  {name}: {rows:,} rows, n = {n:,}, nn = {nn:,}")
        print(f"    rows*nn*8 = {want:,} B  vs the 1 GiB chunk threshold "
              f"-> takes the {arm} arm by default")
        print(f"    resident-arm peak   {rp:>15,} B ({gib(rp):5.2f} GiB)"
              f"   [source formula core {rp_core:,} B]")
        print(f"    chunked-arm peak    {ch['peak']:>15,} B "
              f"({gib(ch['peak']):5.2f} GiB)")
        print(f"      = persistent {ch['persistent']:,} + scratch "
              f"{ch['scratch']:,} + blake3 state {ch['state']:,}"
              f" + leaves {ch['leaves']:,} + twiddles {ch['twiddles']:,}")
        print(f"    SURVIVES to the opening ({arm}) "
              f"{keep:>15,} B ({gib(keep):5.2f} GiB)")
        rows_out.append(dict(name=name, rows=rows, n=n, nn=nn, chunked=chunked,
                             resident_peak=rp, chunked_peak=ch["peak"],
                             chunked_parts=ch, survives=keep,
                             peak_at_this_commit=this_peak))
    print(f"\n  -- the four commitments, in prove order")
    print(f"     held from the last commit to the openings "
          f"{held_total:>14,} B ({gib(held_total):5.2f} GiB)")
    print(f"     PEAK across the commit phase             "
          f"{peak_running:>14,} B ({gib(peak_running):5.2f} GiB)")
    with_tables = held_total + IR_ROUND_LOOP_TABLES
    print(f"     + the round loop's own tables (4.83 GiB) "
          f"{with_tables:>14,} B ({gib(with_tables):5.2f} GiB)")
    for cname, cap in (("8 GB laptop card (8,188 MiB)", CARD_8GB),
                       ("32 GB card (5090)", CARD_32GB)):
        print(f"     {cname}: commit peak "
              f"{100.0 * peak_running / cap:5.1f}% of VRAM, "
              f"commit+round-loop {100.0 * with_tables / cap:5.1f}%")
    out[label] = dict(commitments=rows_out, held_total=held_total,
                      commit_phase_peak=peak_running,
                      plus_round_loop_tables=with_tables)
    print()


def main():
    out = {}
    report("125M, the four hiding commitments on the device", "model_m125.json", out)
    report("rung-W14, the four hiding commitments on the device", "model_rung_w14.json", out)

    print("=" * 78)
    print("THE TWO CARDS")
    print("=" * 78)
    for cname, cap in (("8 GB laptop card, 8,188 MiB usable", CARD_8GB),
                       ("32 GB card (RTX 5090), not yet installed", CARD_32GB)):
        print(f"\n  {cname}   = {cap:,} B")
        for label, d in out.items():
            print(f"    {label[:34]:<36} commit peak "
                  f"{gib(d['commit_phase_peak']):5.2f} GiB "
                  f"({100.0 * d['commit_phase_peak'] / cap:5.1f}%), "
                  f"held {gib(d['held_total']):5.2f} GiB "
                  f"({100.0 * d['held_total'] / cap:5.1f}%)")

    print("\n  -- the ALL-RESIDENT counterfactual at 125M (what CL1 avoids).")
    print("     CUMULATIVE: each commitment's own peak on top of what the")
    print("     earlier ones still hold (data + enc, because enc is Some on")
    print("     the resident arm -- cuda.rs:1591-1594).")
    m = load("model_m125.json")
    held = 0
    worst = 0
    for name, rows, n, nn in commitments_of(m):
        rp, _ = resident_peak(rows, n, nn, COL_CHECKS)
        at = held + rp
        worst = max(worst, at)
        keep = survives(rows, n, nn, COL_CHECKS, chunked=False)
        held += keep
        print(f"    {name:<14} own peak {rp:>15,} B, with earlier holdings "
              f"{at:>15,} B ({gib(at):6.2f} GiB)"
              f"  -- {'OVER' if at > CARD_8GB else 'under'} the 8 GB card")
    print(f"    all-resident commit-phase peak {worst:,} B "
          f"({gib(worst):.2f} GiB = {mib(worst):,.0f} MiB)"
          f"  -- {worst / CARD_8GB:.2f}x the 8 GB card, "
          f"{100.0 * worst / CARD_32GB:.0f}% of a 32 GB card")
    print(f"    the chunked arm's peak is {worst / out[list(out)[0]]['commit_phase_peak']:.1f}x smaller")
    out["125M all-resident counterfactual"] = dict(commit_phase_peak=worst)

    path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "residency.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=1, sort_keys=True)
    print(f"\nwrote {path}")


if __name__ == "__main__":
    main()
