#!/usr/bin/env python3
"""The draft's sec 7.3 item 5 says its absorb count (1,129 / 1,138 / 5,932) is
"validated by nothing".  This script validates it, by a route the draft did
not use: the CAPTURE BUNDLES' own `transcript_program` (a public field of
run.json, which is the recorder's transcription of run.rs's absorb sites),
the pinned layout models in grow_tests.rs, and the MEASURED per-role opening
group counts read out of the bundles.

The program (run-g-dense-s20/run.json, field `transcript_program`):

  header:  absorb run-shape, expected-IO, public-statement, parameters,
           calibration, schedule                                     -> 6
  stage k: absorb pb-run-stage, pb-run-block                         -> 2
           if k+1 < L: absorb B root, rows, log-cols                 -> 3
           absorb A root, rows, log-cols                             -> 3
           absorb M (mask root)                                      -> 1
           absorb H root, rows, log-cols                             -> 3
           per slot s in 0..22: absorb pb-slot, absorb pb-scalar,
             one absorb per sumcheck round, absorb pb-term
                                       -> 3*23 + (main + extension rounds)
           the M opening: absorb mask-q, absorb mask-prox            -> 2
           per PCS role after M: one absorb per group + absorb pcs-prox
                                       -> (groups + 1) per role
           roles: A, H, Input, and at k = L-1 also Output

Group counts, MEASURED on run-g-dense-s20 (stage-00/01/02.json, field
`roles[*].groups`):  A = 36, H = 9, external endpoint = 1, internal
boundary = 2.  a_groups / h_groups are also the pinned model's.

The same script also models the LIVE SQUEEZE channels and compares with the
gate's measured `final_counter`, to size the draft's unmodelled
"1,024 definition draws per stage" allowance at 125M (its sec 7.3 item 4).
"""
MODELS = {
    # main_rounds, extension_rounds, a_groups, h_groups, a_rows, h_rows,
    # a_claims (a_sites), h_claims (h_sites + 1 sum claim),
    # endpoint_rows, boundary_rows
    "rung-G":  dict(main=217, ext=25, ag=36, hg=9, arows=623, hrows=576,
                    aclaims=122, hclaims=53, erows=9, brows=10),
    "rung-K4": dict(main=220, ext=25, ag=36, hg=9, arows=727, hrows=720,
                    aclaims=122, hclaims=53, erows=9, brows=10),
    "125M":    dict(main=336, ext=25, ag=36, hg=9, arows=5681, hrows=7120,
                    aclaims=122, hclaims=51, erows=37, brows=38),
}
N_SLOTS = 23
G_EP, G_B = 1, 2           # MEASURED in the bundles
CLAIMS_EP, CLAIMS_B = 1, 2 # MEASURED in the bundles
IDX_SQUEEZES = 256 // 4    # challenge_indices: 4 indices per 32-byte squeeze
MASK_PROX = 2 * N_SLOTS + 2

def absorbs(m, L):
    rounds = m["main"] + m["ext"]
    slots = 3 * N_SLOTS + rounds
    total = 6                                   # the header
    for k in range(L):
        s = 2                                   # pb-run-stage, pb-run-block
        if k + 1 < L:
            s += 3                              # B root, rows, log-cols
        s += 3 + 1 + 3                          # A(3), M(1), H(3)
        s += slots
        s += 2                                  # mask-q, mask-prox
        s += (m["ag"] + 1) + (m["hg"] + 1)      # A and H openings
        s += (G_EP if k == 0 else G_B) + 1      # the Input role
        if k + 1 == L:
            s += G_EP + 1                       # the Output role
        total += s
    return total

def squeeze_channels(m, L, with_logup=True):
    """the squeeze channels the program names explicitly; the 23 slots' own
    DEFINITION draws (tau, mu, nu, zeta, r_*) are deliberately NOT modelled"""
    rounds = m["main"] + m["ext"]
    total = 0
    for k in range(L):
        s = 3 if with_logup else 0              # beta, gamma, alpha
        s += N_SLOTS                            # the CFS challenge c per slot
        s += rounds                             # one Fp2 per sumcheck round
        s += 1 + MASK_PROX + IDX_SQUEEZES       # the M opening
        s += m["aclaims"] + m["arows"] + IDX_SQUEEZES
        s += m["hclaims"] + m["hrows"] + IDX_SQUEEZES
        if k == 0:
            s += CLAIMS_EP + m["erows"] + IDX_SQUEEZES
        else:
            s += CLAIMS_B + m["brows"] + IDX_SQUEEZES
        if k + 1 == L:
            s += CLAIMS_EP + m["erows"] + IDX_SQUEEZES
        total += s
    return total

MEASURED = {"rung-G": 6924, "rung-K4": 7686, "125M": None}
DRAFT_ABSORBS = {"rung-G": 1129, "rung-K4": 1138, "125M": 5932}
DRAFT_CHANNELS_125M = 164560

print("=" * 76)
print("A. ABSORB COUNT  (the draft's sec 7.3 item 5, 'validated by nothing')")
print("=" * 76)
print(f"{'config':<10} {'L':>3} {'this script':>12} {'the draft':>11}  agree")
ok = True
for name, L in [("rung-G", 3), ("rung-K4", 3), ("125M", 12)]:
    a = absorbs(MODELS[name], L)
    agree = a == DRAFT_ABSORBS[name]
    ok &= agree
    print(f"{name:<10} {L:>3} {a:>12,} {DRAFT_ABSORBS[name]:>11,}  {'YES' if agree else 'NO'}")
print()
print("verdict:", "the draft's absorb count is REPRODUCED by an independent route"
      if ok else "MISMATCH")

print()
print("=" * 76)
print("B. LIVE SQUEEZES: the modelled channels against the gate's measurement")
print("=" * 76)
for name, L in [("rung-G", 3), ("rung-K4", 3), ("125M", 12)]:
    m = MODELS[name]
    ch = squeeze_channels(m, L)
    ch_nolog = squeeze_channels(m, L, with_logup=False)
    meas = MEASURED[name]
    if meas:
        print(f"{name:<10} modelled channels {ch:>8,} (without the 3 LogUp draws {ch_nolog:>8,}); "
              f"gate measured {meas:>8,};  unmodelled slot-definition draws = {meas - ch:>6,} "
              f"over {L} stages = {(meas - ch) / L:>6.1f} per stage")
    else:
        print(f"{name:<10} modelled channels {ch:>8,} (without the 3 LogUp draws {ch_nolog:>8,}); "
              f"the draft quotes {DRAFT_CHANNELS_125M:,} -> "
              f"{'matches the no-LogUp model exactly' if ch_nolog == DRAFT_CHANNELS_125M else 'differs by %d' % (ch_nolog - DRAFT_CHANNELS_125M)}")

print()
print("C. IS THE 125M ALLOWANCE OF 1,024 DEFINITION DRAWS PER STAGE GENEROUS?")
g = MODELS["rung-G"]; m = MODELS["125M"]
per_stage_rungg = (MEASURED["rung-G"] - squeeze_channels(g, 3)) / 3
scale = (m["main"] + m["ext"]) / (g["main"] + g["ext"])
print(f"  measured at rung-G: {per_stage_rungg:.1f} definition draws per stage")
print(f"  the slot variable count grows by {scale:.2f}x from rung-G to 125M")
print(f"  a linear extrapolation gives about {per_stage_rungg * scale:.0f} per stage at 125M,")
print(f"  against the draft's allowance of 1,024 -> the allowance is about "
      f"{1024 / (per_stage_rungg * scale):.1f}x generous.")
