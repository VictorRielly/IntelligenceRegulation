#!/usr/bin/env python3
"""PV-S1 — music-provenance statement spike (capture chain + Pi1 mixdown).

First runnable artifact of the provenance pillar
(docs/provenance/MUSIC_PROVENANCE_POC.md). Demonstrates, end to end at
toy scale, the STATEMENT CLASS the music PoC rests on:

    published master  =  (public mix gains) x (committed private takes)

proven with the repo's own lattice ZK code (zk_lattice protocol Pi1:
A public, B/C committed — exactly the P2-style split: edit parameters
public, source takes private), stapled to a simulated capture-
attestation chain (per-take frame hash-chain + device tag).

WHAT THIS SHOWS
  - the capture evidence format (frame hash-chain -> device tag) and
    its tamper behavior;
  - the mixdown claim proven/verified by Pi1 over committed takes,
    with tamper legs (wrong master, wrong gains) rejecting;
  - that an AI-generated master, however good, simply has no capture
    evidence to present (the registry leg).

WHAT THIS DOES NOT SHOW (stated per house honesty discipline)
  - real device attestation: the device tag is HMAC with a key this
    script holds — a stand-in for a secure-element signature + device
    PKI (C2PA-style). SIMULATED.
  - production security: toy_params_rect carries NO concrete lattice
    hardness (soundness ~= 2^-(r*(b-1)) = 2^-56 here, b = 8, r = 8;
    dimensions unvalidated). reference_params + estimator validation
    are required for any security claim (zk_lattice docstring).
  - anything beyond constant-gain integer mixdown: trims/automation
    (Hadamard class), dynamics/saturation (lookup class), rounding /
    fixed-point rescale (range class), perceptual codecs (outside the
    proof boundary) are all future gadgets — see the PoC doc.
  - the analog hole (a mic recording OF AI audio gets a genuine
    capture chain): NOT addressable by this layer at all; that is the
    classifier gate's job (PoC doc Section 5). No crypto claim is
    made there.

Run:  python3 scripts/music_provenance_spike.py   (repo root; stdlib only)
"""

import hashlib
import hmac
import json
import random
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from zk_lattice import commit_columns, expand_crs, toy_params_rect
from zk_lattice.protocol import matmul_mod, prove_pi1, verify_pi1
from zk_lattice.sampling import ternary_vector

N_TAKES = 4
N_SAMPLES = 1024          # samples per take in this toy session
FRAME = 256               # frame size of the capture hash-chain
GAINS = [3, 2, 1, 2]      # public integer mix gains (exact-integer mixdown)
R_REPS = 8                # Pi1 repetitions: toy soundness 2^-(8*(8-1)) = 2^-56

CHECKS = []


def ok(name, cond, detail=""):
    CHECKS.append((name, bool(cond)))
    tag = "OK " if cond else "FAIL"
    print(f"  [{tag}] {name}" + (f" — {detail}" if detail else ""))
    if not cond:
        raise SystemExit(f"spike check failed: {name}")


# ---------------------------------------------------------------- layer 1
# Simulated attested recorder: per-take frame hash-chain + device tag.

def synth_take(rng, kind):
    """Synthetic int16-range 'audio' (sine mixtures + noise), seeded."""
    import math
    out = []
    f1, f2 = rng.choice([(5, 13), (7, 11), (3, 17), (9, 19)])
    for t in range(N_SAMPLES):
        s = (
            9000 * math.sin(2 * math.pi * f1 * t / N_SAMPLES)
            + 5000 * math.sin(2 * math.pi * f2 * t / N_SAMPLES)
            + rng.randint(-800, 800)
        )
        out.append(max(-32768, min(32767, int(s))))
    return out


def frame_chain(samples, meta):
    """h_0 = H(meta); h_i = H(h_{i-1} || frame_i). Returns final digest."""
    h = hashlib.sha256(json.dumps(meta, sort_keys=True).encode()).digest()
    for start in range(0, len(samples), FRAME):
        frame = samples[start : start + FRAME]
        blob = b"".join(int(v).to_bytes(2, "little", signed=True) for v in frame)
        h = hashlib.sha256(h + blob).digest()
    return h


def device_tag(device_key, chain_digest, meta):
    """SIMULATED secure-element signature (HMAC stand-in; see header)."""
    msg = chain_digest + json.dumps(meta, sort_keys=True).encode()
    return hmac.new(device_key, msg, hashlib.sha256).digest()


def main():
    rng = random.Random(20260807)
    device_key = bytes(rng.randrange(256) for _ in range(32))

    takes, metas, tags = [], [], []
    for i in range(N_TAKES):
        meta = {"take": i, "device": "SIM-MIC-01", "session": "PV-S1",
                "t_start": f"2026-08-07T10:0{i}:00Z", "sr": 16000}
        samples = synth_take(rng, i)
        digest = frame_chain(samples, meta)
        takes.append(samples)
        metas.append(meta)
        tags.append(device_tag(device_key, digest, meta))

    # Registry of capture-attested take digests (layer-1 evidence store).
    registry = {frame_chain(t, m).hex() for t, m in zip(takes, metas)}

    # check 1: honest capture chains verify
    all_ok = all(
        hmac.compare_digest(
            device_tag(device_key, frame_chain(t, m), m), g
        )
        for t, m, g in zip(takes, metas, tags)
    )
    ok("capture chains verify (4 takes)", all_ok)

    # check 2: one flipped sample breaks its take's chain
    tampered = list(takes[2])
    tampered[300] ^= 1
    ok(
        "tampered frame breaks the chain",
        not hmac.compare_digest(
            device_tag(device_key, frame_chain(tampered, metas[2]), metas[2]),
            tags[2],
        ),
    )

    # check 3: forged tag under a wrong device key rejects
    wrong_key = bytes((device_key[0] ^ 1,)) + device_key[1:]
    ok(
        "forged device tag rejects",
        not hmac.compare_digest(
            device_tag(wrong_key, frame_chain(takes[0], metas[0]), metas[0]),
            tags[0],
        ),
    )

    # ------------------------------------------------------------ layer 2
    # Pi1: master = GAINS x takes, takes/master committed, gains public.
    params = toy_params_rect(rows=1, inner=N_TAKES, cols=N_SAMPLES, r=R_REPS)
    key = expand_crs(params)
    q = params.q

    a_rows = [[g % q for g in GAINS]]                      # public 1 x 4
    b_columns = [                                          # committed 4 x 1024
        [takes[t][s] % q for t in range(N_TAKES)] for s in range(N_SAMPLES)
    ]
    c_columns = matmul_mod(a_rows, b_columns, q)           # committed 1 x 1024
    # |master sample| <= sum|g|*2^15 = 2^18 << q = 2^61-1: integer-exact.

    rho_b = [ternary_vector(params.big_n) for _ in range(params.m)]
    tau_c = [ternary_vector(params.big_n) for _ in range(params.m)]
    t0 = time.perf_counter()
    tb = commit_columns(key, b_columns, rho_b)
    tc = commit_columns(key, c_columns, tau_c)
    t_commit = time.perf_counter() - t0

    t0 = time.perf_counter()
    proof = prove_pi1(key, a_rows, b_columns, rho_b, c_columns, tau_c, tb, tc)
    t_prove = time.perf_counter() - t0
    t0 = time.perf_counter()
    accepted = verify_pi1(key, a_rows, tb, tc, proof)
    t_verify = time.perf_counter() - t0

    # check 4: honest mixdown proof accepts
    ok("Pi1 mixdown proof ACCEPTS", accepted,
       f"commit {t_commit:.2f}s prove {t_prove:.2f}s verify {t_verify:.2f}s")

    # check 5: tampered master rejects (false statement, honest prover run)
    c_bad = [list(col) for col in c_columns]
    c_bad[100][0] = (c_bad[100][0] + 1) % q
    tc_bad = commit_columns(key, c_bad, tau_c)
    proof_bad = prove_pi1(key, a_rows, b_columns, rho_b, c_bad, tau_c, tb, tc_bad)
    ok("tampered master REJECTS", not verify_pi1(key, a_rows, tb, tc_bad, proof_bad))

    # check 6: verifying under different public gains rejects
    a_other = [[(GAINS[0] + 1) % q] + [g % q for g in GAINS[1:]]]
    ok("wrong public gains REJECT", not verify_pi1(key, a_other, tb, tc, proof))

    # ------------------------------------------------------------ layer 1+2
    # check 7: an AI-generated master has no capture evidence to present.
    ai_master = [rng.randint(-32768, 32767) for _ in range(N_SAMPLES)]
    ai_digest = frame_chain(ai_master, {"take": 0, "device": "?", "session": "?",
                                        "t_start": "?", "sr": 16000}).hex()
    ok("unchained AI master absent from capture registry", ai_digest not in registry,
       "no attested takes -> no layer-1 evidence; laundering via replay is the "
       "residual hole (classifier gate, PoC doc Section 5)")

    ints_per_rep = params.n + 2 * params.big_n + 1
    proof_bytes_est = R_REPS * ints_per_rep * 8
    print(f"\n  proof accounting [TOY-SHAPE]: {R_REPS} reps x "
          f"{ints_per_rep} ints x 8 B ~= {proof_bytes_est:,} B "
          f"(+ {2 * N_SAMPLES} column commitments)")
    print(f"  toy soundness bound 2^-{R_REPS * (params.b - 1)}; "
          "NO concrete lattice hardness at toy dims (see header)")

    n_ok = sum(1 for _, c in CHECKS if c)
    print(f"\nPV-S1: {n_ok}/{len(CHECKS)} OK")


if __name__ == "__main__":
    main()
