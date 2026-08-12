#!/usr/bin/env python3
"""PV-S2 — song-scale music provenance: real WAV sessions, session evidence
objects, block-chained Pi1 mixdown proof, reference-params measurement.

Second runnable artifact of the provenance pillar
(docs/provenance/MUSIC_PROVENANCE_POC.md, Section 7). Extends PV-S1
(scripts/music_provenance_spike.py) from a 1024-sample toy statement to a
real multi-track session at song scale:

  - REAL WAV I/O: a synthetic 4-take session (>= 60 s per take, 16 kHz
    mono int16) written to and re-read from actual PCM WAV files via the
    stdlib ``wave`` module (results/pv_s2_session/). The wavs are
    .gitignored; manifest.json + digests.txt are the committed export
    (the m125_ffn_export precedent).
  - SESSION EVIDENCE OBJECTS (PoC doc Section 2 upgrades): per-take frame
    hash-chain + HMAC device tag (PV-S1's simulated attestation), PLUS
    session-level cross-commitment — every take's device tag signs
    (take chain digest || session digest || take meta), so the session is
    ONE evidence object: dropping, substituting or splicing a take breaks
    every other take's tag — PLUS a transparency-log stand-in
    (session_log.jsonl) that the session digest and the final proof-chain
    digest are appended to, timestamped.
  - BLOCK-CHAINED Pi1 AT SONG SCALE: the mixdown statement
        master (public WAV)  =  gains (public, 1 x 4)  x  takes (committed, 4 x S)
    is proven over the full song in blocks of ``cols_per_block`` samples,
    each block a Pi1 instance at the toy parameter class, shape
    (rows=1, inner=4, cols=cols_per_block) — see ``toy_block_params``
    for why the toy_params_rect recipe is built directly here.

    BINDING RULE (the session-level Fiat-Shamir chain):
        chain_0 = H("pv2-chain0", session_digest, gains, n_blocks, cols_per_block)
        seed_k  = H("pv2-crs-seed", chain_{k-1}, k)
        stmt_k  = H("pv2-stmt", crs_hash_k, gains, T_B^k, T_C^k)
        chain_k = H("pv2-chain", chain_{k-1}, k, stmt_k)
    Block k is committed and proven under the CRS expanded from seed_k, and
    Pi1's own statement hash binds crs_hash_k — so block k's statement hash
    transitively includes block k-1's statement hash and, through chain_0,
    the layer-1 session digest. A block presented at the wrong position is
    verified under a CRS it was not proven under, and Pi1 itself rejects;
    an attacker who re-chains reordered statement hashes changes every
    subsequent CRS seed and cannot re-prove without the witnesses. The
    final link chain_{n-1} is appended to the transparency log.
  - PUBLISHED-MASTER BINDING: the master is public (a real WAV file), so
    the per-block C-commitment randomness tau_C is published and the
    verifier re-commits the published WAV's samples and compares against
    T_C — a full public opening of C (the master hides nothing), binding
    the Pi1-proven C to the actual published bytes. B (the takes) stays
    hidden; tau_C is independent of B's randomness and leaks nothing.

WHAT THIS DOES NOT SHOW (house honesty discipline; PV-S1 header applies):
  - real device attestation: the device tag is HMAC with a key this
    script holds — a stand-in for a secure-element signature + device
    PKI. SIMULATED, stated on every artifact.
  - concrete security at the default parameters: toy_params_rect carries
    NO concrete lattice hardness, and per-block Fiat-Shamir soundness is
    only ~2^-(r*(b-1)) = 2^-28 at r=4. The --reference mode runs the
    security-relevant parameter class (reference_params_pi1 constants
    q=2^54-33, b=8, r=37, N=6656, k=1728 at the block's rectangular
    shape); the report's C1/C2/C3/C4 design models hold there for
    cols <= 1024 (C3 caps the reference block width; see the check), and
    estimator validation is still required before any deployment claim
    (zk_lattice module docstring).
  - a ZK link between the layer-1 capture digests and the committed B
    columns: this demo's prover uses the same samples for both layers;
    proving that equality without revealing the takes is a PV-S3+
    statement-design item.
  - commitment randomness here is PRF-derived (HMAC-seeded PRNG) from a
    per-session prover secret so that commitments — and hence the block
    chain — are deterministic and re-derivable for the tamper legs; the
    prover's Sigma-protocol masks still come from OS entropy (`secrets`)
    inside zk_lattice.
  - edits beyond constant-gain integer mixdown (fades = Hadamard class,
    dynamics = lookup class, requantization = range class) and perceptual
    codecs (outside the proof boundary); the analog hole is layer 3's.

Run:
  python3 scripts/music_provenance_spike2.py               # full song, toy params (~6 min)
  python3 scripts/music_provenance_spike2.py --quick       # 4-block smoke run (~1 min)
  python3 scripts/music_provenance_spike2.py --reference   # one-time reference-params
      measurement (256-col sub-block + full 1024-col block; ~40 min — background it)
"""

import argparse
import hashlib
import hmac
import json
import math
import random
import sys
import tempfile
import time
import wave
from array import array
from dataclasses import dataclass, field, replace
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from zk_lattice import commit, commit_columns, expand_crs
from zk_lattice.params import LatticeParams
from zk_lattice.protocol import prove_pi1, verify_pi1
from zk_lattice.sampling import hash_digest

PC = time.perf_counter

CHECKS = []


def ok(name, cond, detail=""):
    CHECKS.append((name, bool(cond)))
    tag = "OK " if cond else "FAIL"
    print(f"  [{tag}] {name}" + (f" — {detail}" if detail else ""), flush=True)
    if not cond:
        raise SystemExit(f"spike check failed: {name}")


# ---------------------------------------------------------------- config


@dataclass(frozen=True)
class SpikeConfig:
    sr: int = 16000
    n_samples: int = 983040          # 61.44 s -> exactly 60 blocks of 16384
    n_takes: int = 4
    gains: tuple = (3, 2, 1, 2)      # public integer mix gains
    frame: int = 1024                # capture hash-chain frame (samples)
    cols_per_block: int = 16384      # Pi1 columns (= samples) per block
    reps: int = 4                    # Pi1 repetitions per block (toy)
    seed: int = 20260810
    session_id: str = "PV-S2-SESSION-01"
    device_id: str = "SIM-MIC-01"
    take_peak: int = 4000            # per-take peak so the mix is exact int16

    @property
    def n_blocks(self):
        return -(-self.n_samples // self.cols_per_block)


QUICK_SAMPLES = 65536  # 4 blocks of 16384 (~4.1 s of audio)


# ---------------------------------------------------------------- WAV I/O


def pcm_bytes(samples):
    """Canonical little-endian int16 PCM bytes for an array('h')."""
    if sys.byteorder == "big":
        swapped = array("h", samples)
        swapped.byteswap()
        return swapped.tobytes()
    return samples.tobytes()


def write_wav(path, samples, sr):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm_bytes(samples))


def read_wav(path):
    with wave.open(str(path), "rb") as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2
        sr = w.getframerate()
        raw = w.readframes(w.getnframes())
    out = array("h")
    out.frombytes(raw)
    if sys.byteorder == "big":
        out.byteswap()
    return out, sr


# ---------------------------------------------------------------- synthesis


def synth_takes(cfg):
    """Four seeded melodic/noise stems as array('h'), peak <= cfg.take_peak.

    Stems: pentatonic lead (vibrato + note envelope), square-ish bass,
    detuned pad, gated noise percussion. Peaks are capped so the public
    integer mix sum|g|*peak stays inside int16 — the mixdown is exact
    (no clip, no dither; requantization is a future range-class gadget).
    """
    rng = random.Random(cfg.seed)
    n, sr = cfg.n_samples, cfg.sr
    peak = cfg.take_peak
    two_pi = 2 * math.pi
    sin = math.sin
    penta = [0, 3, 5, 7, 10, 12]

    lead = array("h", bytes(2 * n))
    note_len = sr // 4
    ph = 0.0
    f = 220.0
    for t in range(n):
        if t % note_len == 0:
            f = 220.0 * 2 ** (rng.choice(penta) / 12.0)
        vib = 1.0 + 0.004 * sin(two_pi * 5.0 * t / sr)
        ph += two_pi * f * vib / sr
        env = 1.0 - (t % note_len) / (1.35 * note_len)
        lead[t] = int(peak * env * sin(ph))

    bass = array("h", bytes(2 * n))
    bar = sr  # one root note per second
    ph = 0.0
    f = 55.0
    for t in range(n):
        if t % bar == 0:
            f = 55.0 * 2 ** (rng.choice([0, 3, 5, 7]) / 12.0)
        ph += two_pi * f / sr
        bass[t] = peak - 1 if sin(ph) > 0 else -(peak - 1)

    pad = array("h", bytes(2 * n))
    ph1 = ph2 = 0.0
    f = 110.0
    for t in range(n):
        if t % (2 * sr) == 0:
            f = 110.0 * 2 ** (rng.choice(penta) / 12.0)
        ph1 += two_pi * f / sr
        ph2 += two_pi * f * 1.003 / sr
        pad[t] = int(0.5 * peak * (sin(ph1) + sin(ph2)) * 0.5 * 2)

    perc = array("h", bytes(2 * n))
    burst = sr // 8
    rr = rng.random
    for t in range(n):
        env = 1.0 - (t % burst) / (0.4 * burst)
        if env > 0:
            perc[t] = int(peak * env * (2.0 * rr() - 1.0))

    return [lead, bass, pad, perc][: cfg.n_takes]


def mix_master(cfg, takes):
    """Exact integer mixdown master[s] = sum_t gains[t] * take_t[s]."""
    n = cfg.n_samples
    acc = [0] * n
    for g, take in zip(cfg.gains, takes):
        for s in range(n):
            acc[s] += g * take[s]
    peak = max(max(acc), -min(acc))
    if peak >= 32768:
        raise SystemExit("mix overflows int16 — headroom bug")
    return array("h", acc), peak


# ------------------------------------------------- layer 1: session evidence


def take_meta(cfg, i):
    return {
        "take": i,
        "device": cfg.device_id,
        "session": cfg.session_id,
        "t_start": f"2026-08-10T09:0{i}:00Z",
        "sr": cfg.sr,
        "n_samples": cfg.n_samples,
        "format": "pcm_s16le",
    }


def canonical(meta):
    return json.dumps(meta, sort_keys=True).encode()


def frame_chain(samples, meta, frame):
    """h_0 = H(meta); h_i = H(h_{i-1} || frame_i) over LE-PCM frame bytes."""
    data = pcm_bytes(samples)
    h = hashlib.sha256(canonical(meta)).digest()
    step = 2 * frame
    for start in range(0, len(data), step):
        h = hashlib.sha256(h + data[start : start + step]).digest()
    return h


def session_digest_of(cfg, chain_digests):
    return hash_digest(
        "pv2-session", cfg.session_id, cfg.device_id, cfg.sr,
        cfg.n_takes, cfg.n_samples, list(chain_digests),
    )


def device_tag(device_key, chain_digest, session_digest, meta):
    """SIMULATED secure-element signature over (chain || session || meta).

    Covering the session digest is the Section-2 cross-commitment: one
    take cannot be dropped, substituted, or spliced in from another
    session without invalidating every take's tag.
    """
    msg = chain_digest + session_digest + canonical(meta)
    return hmac.new(device_key, msg, hashlib.sha256).digest()


def build_evidence(cfg, takes, device_key):
    metas = [take_meta(cfg, i) for i in range(cfg.n_takes)]
    chains = [frame_chain(t, m, cfg.frame) for t, m in zip(takes, metas)]
    sess = session_digest_of(cfg, chains)
    tags = [device_tag(device_key, c, sess, m) for c, m in zip(chains, metas)]
    return {
        "session": {"id": cfg.session_id, "device": cfg.device_id,
                    "sr": cfg.sr, "n_takes": cfg.n_takes,
                    "n_samples": cfg.n_samples},
        "session_digest": sess.hex(),
        "takes": [
            {"meta": m, "chain": c.hex(), "tag": g.hex()}
            for m, c, g in zip(metas, chains, tags)
        ],
    }


def verify_evidence(cfg, evidence, takes, device_key):
    """Recompute chains + session digest + tags; the session verifies as
    ONE object or not at all."""
    if len(evidence["takes"]) != len(takes):
        return False, "take count mismatch"
    chains = []
    for entry, samples in zip(evidence["takes"], takes):
        c = frame_chain(samples, entry["meta"], cfg.frame)
        if c.hex() != entry["chain"]:
            return False, f"take {entry['meta']['take']}: frame chain broken"
        chains.append(c)
    sess = session_digest_of(cfg, chains)
    if sess.hex() != evidence["session_digest"]:
        return False, "session cross-commitment broken"
    for entry, c in zip(evidence["takes"], chains):
        tag = device_tag(device_key, c, sess, entry["meta"])
        if not hmac.compare_digest(tag.hex(), entry["tag"]):
            return False, f"take {entry['meta']['take']}: device tag invalid"
    return True, "ok"


# ---------------------------------------- transparency-log stand-in


def log_append(path, kind, payload):
    entry = {"ts": datetime.now(timezone.utc).isoformat(), "kind": kind}
    entry.update(payload)
    with open(path, "a") as f:
        f.write(json.dumps(entry, sort_keys=True) + "\n")


def log_anchors(path, digest_hex):
    if not Path(path).exists():
        return False
    with open(path) as f:
        return any(digest_hex in line for line in f)


# ------------------------------------------------- layer 2: chained Pi1


def toy_block_params(cfg):
    """The toy_params_rect recipe at the block shape, completeness-gated on
    the constraints Pi1 actually uses (C0 + C2_pi1).

    toy_params_rect's own gate also requires C2_pi2 — a constraint of the
    never-run-here Pi2 protocol — which caps cols at 8192 under
    q = 2^61-1; the PV-S2 blocks are Pi1-only and C2_pi1 holds far beyond
    these widths, so the identical parameter set is built directly (same
    n, q, b, big_n, k as toy_params_rect) at the 16384-col block width."""
    n = max(1, cfg.n_takes)
    params = LatticeParams(
        n=n, m=cfg.cols_per_block, q=(1 << 61) - 1, b=8, r=cfg.reps,
        big_n=max(64, ((16 + n + 63) // 64) * 64), k=16, toy=True,
        rows=1, inner=cfg.n_takes,
    )
    checks = params.check_constraints()
    if not (checks["c0_prime"] and checks["c0_slack"] and checks["c2_pi1"]):
        raise SystemExit("toy block params violate Pi1 completeness")
    return params


def reference_block_params(cols, n_takes=4):
    """reference_params_pi1's class constants at the block's rect shape.

    q, b, r, N, k are the report's worked set B (the security-relevant
    class); only the message dimension n and the claim shape differ (n=4
    covers the 4-take columns — C4 hiding only improves with smaller n).
    Estimator validation is still required per the zk_lattice docstring.
    """
    return LatticeParams(
        n=n_takes, m=cols, q=(1 << 54) - 33, b=8, r=37,
        big_n=6656, k=1728, rows=1, inner=n_takes,
    )


def ref_constraints_ok(params):
    ck = params.check_constraints()
    need = ["c0_prime", "c0_slack", "c1_pi1", "c2_pi1", "c3_pi1", "c4_hiding"]
    return all(ck[name] for name in need), ck


def chain0(cfg, session_digest):
    return hash_digest("pv2-chain0", session_digest, list(cfg.gains),
                       cfg.n_blocks, cfg.cols_per_block)


def crs_seed(chain_prev, k):
    return hash_digest("pv2-crs-seed", chain_prev, k)


def stmt_hash(crs_hash, a_rows, tb, tc):
    return hash_digest("pv2-stmt", crs_hash, a_rows, list(tb), list(tc))


def chain_link(chain_prev, k, stmt):
    return hash_digest("pv2-chain", chain_prev, k, stmt)


def _ternary_from_rng(rng, length):
    """Seeded twin of zk_lattice.sampling.ternary_vector (same rejection
    rule, PRF-derived entropy — see the module docstring's honesty note)."""
    out = []
    while len(out) < length:
        byte = rng.getrandbits(8)
        for shift in (0, 2, 4, 6):
            trit = (byte >> shift) & 3
            if trit != 3:
                out.append(trit - 1)
                if len(out) == length:
                    break
    return out


def derive_randomness(session_key, tag, k, count, big_n):
    seed = hmac.new(session_key, f"pv2-rand|{tag}|{k}".encode(),
                    hashlib.sha256).digest()
    rng = random.Random(int.from_bytes(seed, "big"))
    return [_ternary_from_rng(rng, big_n) for _ in range(count)]


def block_columns(cfg, takes, master, k, q):
    """Committed B columns (per-sample take vectors) and C columns (master
    samples) for block k; samples beyond the song end are zero-padded and
    the statement stays true (gains x 0 = 0)."""
    base = k * cfg.cols_per_block
    n = cfg.n_samples
    b_cols, c_cols = [], []
    for s in range(base, base + cfg.cols_per_block):
        if s < n:
            b_cols.append([take[s] % q for take in takes])
            c_cols.append([master[s] % q])
        else:
            b_cols.append([0] * cfg.n_takes)
            c_cols.append([0])
    return b_cols, c_cols


def prove_block(key, a_rows, b_cols, c_cols, rho, tau):
    t0 = PC()
    tb = commit_columns(key, b_cols, rho)
    tc = commit_columns(key, c_cols, tau)
    t_commit = PC() - t0
    t0 = PC()
    proof = prove_pi1(key, a_rows, b_cols, rho, c_cols, tau, tb, tc)
    t_prove = PC() - t0
    return tb, tc, proof, t_commit, t_prove


def opening_check(key, c_cols, tau, tc):
    """Public opening of the committed master against published samples;
    returns the first mismatching column index, or None if all match."""
    for j, (col, r_j) in enumerate(zip(c_cols, tau)):
        if commit(key, col, r_j) != tc[j]:
            return j
    return None


@dataclass
class BlockLink:
    k: int
    seed: bytes
    stmt: bytes
    chain: bytes
    accepted: bool
    open_mismatch: object
    t_commit: float
    t_prove: float
    t_verify: float
    t_open: float


@dataclass
class BlockRecord:
    k: int
    params: LatticeParams
    key: object
    tb: list
    tc: list
    tau: list
    proof: object


@dataclass
class SongProof:
    chain_0: bytes
    links: list
    records: dict
    chain_final: bytes = b""
    retained_b: dict = field(default_factory=dict)


def prove_song(cfg, params_base, takes, master, session_digest, session_key,
               retain=(), progress=False):
    """Prove + verify the whole song block by block along the chain.

    Streaming: each block's commitments are dropped after its immediate
    verification + opening check (memory stays O(block)); full records
    are retained only for the indices in ``retain`` (tamper legs)."""
    q = params_base.q
    a_rows = [[g % q for g in cfg.gains]]
    song = SongProof(chain_0=chain0(cfg, session_digest), links=[], records={})
    chain_prev = song.chain_0
    for k in range(cfg.n_blocks):
        seed = crs_seed(chain_prev, k)
        params = replace(params_base, seed=seed)
        key = expand_crs(params)
        b_cols, c_cols = block_columns(cfg, takes, master, k, q)
        rho = derive_randomness(session_key, "B", k, len(b_cols), params.big_n)
        tau = derive_randomness(session_key, "C", k, len(c_cols), params.big_n)
        tb, tc, proof, t_commit, t_prove = prove_block(
            key, a_rows, b_cols, c_cols, rho, tau
        )
        t0 = PC()
        accepted = verify_pi1(key, a_rows, tb, tc, proof)
        t_verify = PC() - t0
        t0 = PC()
        mismatch = opening_check(key, c_cols, tau, tc)
        t_open = PC() - t0
        stmt = stmt_hash(key.crs_hash, a_rows, tb, tc)
        chain_k = chain_link(chain_prev, k, stmt)
        song.links.append(BlockLink(k, seed, stmt, chain_k, accepted, mismatch,
                                    t_commit, t_prove, t_verify, t_open))
        if k in retain:
            song.records[k] = BlockRecord(k, params, key, tb, tc, tau, proof)
            song.retained_b[k] = (b_cols, rho)
        chain_prev = chain_k
        if progress and (k % 10 == 9 or k == cfg.n_blocks - 1):
            done = k + 1
            print(f"    ... block {done}/{cfg.n_blocks} "
                  f"(commit {t_commit:.2f}s prove {t_prove:.2f}s "
                  f"verify {t_verify:.2f}s open {t_open:.2f}s)", flush=True)
    song.chain_final = chain_prev
    return song


def verify_block_at_position(cfg, params_base, chain_prev, k, record):
    """Verify a block record as if it sat at position k of the chain: the
    CRS is re-derived from the chain, so a transplanted block fails Pi1."""
    q = params_base.q
    a_rows = [[g % q for g in cfg.gains]]
    params = replace(params_base, seed=crs_seed(chain_prev, k))
    key = expand_crs(params)
    return verify_pi1(key, a_rows, record.tb, record.tc, record.proof)


def proof_ints(params):
    """Transmitted integers per Pi1 proof (z + zeta + xi + gamma per rep)."""
    return params.r * (params.n + 2 * params.big_n + 1)


# ---------------------------------------------------------------- reporting


def banner():
    print("\n  SECURITY BANNER")
    print("    toy_params_rect: NO concrete lattice hardness at toy dims; "
          "per-block Fiat-Shamir soundness ~2^-(r*(b-1)).")
    print("    reference class: reference_params_pi1 constants "
          "(q=2^54-33, b=8, r=37, N=6656, k=1728) — the report's worked "
          "set B; C1-C4 are design models and estimator validation is "
          "required before any security claim (zk_lattice docstring).")


def timing_summary(links):
    n = len(links)
    tot = {
        "commit": sum(l.t_commit for l in links),
        "prove": sum(l.t_prove for l in links),
        "verify": sum(l.t_verify for l in links),
        "open": sum(l.t_open for l in links),
    }
    per = {name: value / n for name, value in tot.items()}
    mx = {
        "commit": max(l.t_commit for l in links),
        "prove": max(l.t_prove for l in links),
        "verify": max(l.t_verify for l in links),
        "open": max(l.t_open for l in links),
    }
    return tot, per, mx


# ---------------------------------------------------------------- main modes


def run_spike(cfg, outdir, progress=True):
    t_wall = PC()
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    (outdir / ".gitignore").write_text("*.wav\n")
    log_path = outdir / "session_log.jsonl"
    log_path.write_text("")  # fresh run of the simulated session

    rng = random.Random(cfg.seed)
    device_key = bytes(rng.randrange(256) for _ in range(32))
    session_key = bytes(rng.randrange(256) for _ in range(32))

    # ---------------- WAV session (real files, real I/O) ----------------
    t0 = PC()
    takes = synth_takes(cfg)
    master, peak = mix_master(cfg, takes)
    t_synth = PC() - t0
    take_paths = [outdir / f"take{i}.wav" for i in range(cfg.n_takes)]
    master_path = outdir / "master.wav"
    t0 = PC()
    for path, take in zip(take_paths, takes):
        write_wav(path, take, cfg.sr)
    write_wav(master_path, master, cfg.sr)
    reread = [read_wav(p)[0] for p in take_paths]
    master_pub, master_sr = read_wav(master_path)
    t_io = PC() - t0

    ok("session WAVs written + re-read exactly "
       f"({cfg.n_takes} takes x {cfg.n_samples/cfg.sr:.2f} s @ {cfg.sr} Hz)",
       all(a == b for a, b in zip(reread, takes)) and master_sr == cfg.sr,
       f"synth {t_synth:.1f}s, wav io {t_io:.1f}s")
    ok("published master WAV exact (integer mixdown, no clip)",
       master_pub == master and peak < 32768,
       f"gains {list(cfg.gains)}, master peak {peak} < 32768")

    # ---------------- layer 1: session evidence object ----------------
    evidence = build_evidence(cfg, reread, device_key)
    session_digest = bytes.fromhex(evidence["session_digest"])
    registry = {t["chain"] for t in evidence["takes"]}
    log_append(log_path, "session-close",
               {"session": cfg.session_id,
                "session_digest": evidence["session_digest"]})

    good, why = verify_evidence(cfg, evidence, reread, device_key)
    ok(f"session evidence verifies as ONE object ({cfg.n_takes} takes, "
       "cross-committed)", good, why)
    ok("transparency log (stand-in) anchors the session digest",
       log_anchors(log_path, evidence["session_digest"]))

    tampered = array("h", reread[2])
    tampered[cfg.n_samples // 2] ^= 1
    bad_takes = list(reread)
    bad_takes[2] = tampered
    good, why = verify_evidence(cfg, evidence, bad_takes, device_key)
    ok("tampered frame breaks its take's chain", not good, why)

    wrong_key = bytes((device_key[0] ^ 1,)) + device_key[1:]
    good, why = verify_evidence(cfg, evidence, reread, wrong_key)
    ok("forged device tag rejects", not good, why)

    # splice: a take captured in ANOTHER session (valid there) swapped in
    other_cfg = replace_cfg(cfg, session_id="PV-S2-SESSION-02")
    other_evidence = build_evidence(other_cfg, reread, device_key)
    spliced = {
        "session": evidence["session"],
        "session_digest": evidence["session_digest"],
        "takes": [dict(t) for t in evidence["takes"]],
    }
    spliced["takes"][1] = other_evidence["takes"][1]
    good, why = verify_evidence(cfg, spliced, reread, device_key)
    ok("cross-session take splice rejects (session cross-commitment)",
       not good, why)

    # ---------------- layer 2: block-chained Pi1 over the song ----------------
    params_base = toy_block_params(cfg)
    mid = max(1, cfg.n_blocks // 2)
    retain = {0, mid - 1, mid}
    print(f"\n  proving {cfg.n_blocks} blocks x {cfg.cols_per_block} cols "
          f"(toy-class rect(1,{cfg.n_takes},{cfg.cols_per_block}), "
          f"r={cfg.reps}) ...", flush=True)
    song = prove_song(cfg, params_base, reread, master_pub, session_digest,
                      session_key, retain=retain, progress=progress)
    tot, per, mx = timing_summary(song.links)

    rejected = [l.index for l in song.links if not l.accepted]
    ok(f"all {cfg.n_blocks} blocks Pi1 ACCEPT along the chain",
       not rejected,
       f"whole-song prove {tot['prove']:.1f}s verify {tot['verify']:.1f}s "
       f"[MAC-BOX]" if not rejected
       else f"REJECTED blocks {rejected} of {cfg.n_blocks} "
            f"(prove {tot['prove']:.1f}s verify {tot['verify']:.1f}s)")
    ok("published-master opening matches T_C on every block",
       all(l.open_mismatch is None for l in song.links),
       f"opening pass {tot['open']:.1f}s [MAC-BOX]")

    log_append(log_path, "song-chain",
               {"session": cfg.session_id,
                "chain_final": song.chain_final.hex()})
    ok("proof chain final link anchored to the transparency log",
       log_anchors(log_path, song.chain_final.hex()))

    # tamper leg: one flipped sample in the PUBLISHED master, middle block
    q = params_base.q
    flip_col = min(7777, cfg.cols_per_block - 1)
    flip_idx = mid * cfg.cols_per_block + flip_col
    master_bad = array("h", master_pub)
    master_bad[flip_idx] ^= 1
    rec = song.records[mid]
    _, c_bad_cols = block_columns(cfg, reread, master_bad, mid, q)
    mism = opening_check(rec.key, c_bad_cols, rec.tau, rec.tc)
    rec0 = song.records[0]
    _, c0_cols = block_columns(cfg, reread, master_bad, 0, q)
    ok(f"flipped master sample REJECTS block {mid} (opening), col {mism}",
       mism == flip_col)
    ok("...and other blocks are unaffected (block 0 opening still clean)",
       opening_check(rec0.key, c0_cols, rec0.tau, rec0.tc) is None)

    # tamper leg: honest prover forced to prove the false mixdown statement
    b_cols_mid, rho_mid = song.retained_b[mid]
    _, c_cols_mid = block_columns(cfg, reread, master_pub, mid, q)
    c_false = [list(col) for col in c_cols_mid]
    c_false[flip_col][0] = (c_false[flip_col][0] + 1) % q
    tau_false = derive_randomness(session_key, "Cbad", mid,
                                  len(c_false), rec.params.big_n)
    a_rows = [[g % q for g in cfg.gains]]
    tc_false = commit_columns(rec.key, c_false, tau_false)
    proof_false = prove_pi1(rec.key, a_rows, b_cols_mid, rho_mid,
                            c_false, tau_false, rec.tb, tc_false)
    ok(f"false statement (master[{flip_idx}]+1) Pi1 REJECTS block {mid}",
       not verify_pi1(rec.key, a_rows, rec.tb, tc_false, proof_false))

    # tamper leg: block reordering — block `mid` presented at position mid-1
    chain_before = song.links[mid - 2].chain if mid - 1 > 0 else song.chain_0
    ok(f"block reorder REJECTS via the chain (block {mid} at position "
       f"{mid - 1}: wrong chained CRS)",
       not verify_block_at_position(cfg, params_base, chain_before,
                                    mid - 1, song.records[mid]))

    # tamper leg: wrong public gains
    a_wrong = [[(cfg.gains[0] + 1) % q] + [g % q for g in cfg.gains[1:]]]
    ok("wrong public gains REJECT",
       not verify_pi1(rec0.key, a_wrong, rec0.tb, rec0.tc, rec0.proof))

    # layer 1+2: an AI-generated master has no capture evidence at all
    ai_rng = random.Random(cfg.seed + 1)
    ai_master = array("h", (ai_rng.randrange(-32768, 32768)
                            for _ in range(cfg.n_samples)))
    ai_digest = frame_chain(ai_master, take_meta(cfg, 0), cfg.frame).hex()
    ok("unchained AI master absent from the capture registry",
       ai_digest not in registry,
       "no attested takes -> no layer-1 evidence; replay laundering stays "
       "the classifier gate's job (PoC doc Section 5)")

    # reference-class constraint status at the block shape (no proving here)
    ok_256, _ = ref_constraints_ok(reference_block_params(256, cfg.n_takes))
    ok_1024, _ = ref_constraints_ok(reference_block_params(1024, cfg.n_takes))
    ok_2048, _ = ref_constraints_ok(reference_block_params(2048, cfg.n_takes))
    ok("reference-class Pi1 constraints hold at block widths 256 and 1024",
       ok_256 and ok_1024,
       f"C3 caps the reference block width: cols=2048 -> "
       f"{'holds' if ok_2048 else 'FAILS'} (song at reference class = "
       f"{-(-cfg.n_samples // 1024)} blocks of 1024)")

    # ---------------- accounting + export ----------------
    p_ints = proof_ints(params_base)
    proof_bytes = p_ints * 8
    commit_ints = 2 * cfg.cols_per_block * (params_base.k + params_base.n)
    commit_bytes = commit_ints * 8
    tau_trits = cfg.cols_per_block * params_base.big_n
    print(f"\n  per-block bytes [TOY-SHAPE accounting, 8 B/int]: proof "
          f"{p_ints} ints ~= {proof_bytes:,} B; commitments T_B+T_C "
          f"{commit_ints} ints ~= {commit_bytes:,} B; published tau_C "
          f"{tau_trits} trits ({tau_trits // 4:,} B at 2 bit/trit)")
    print(f"  per-block times [MAC-BOX]: commit {per['commit']:.2f}s "
          f"prove {per['prove']:.2f}s verify {per['verify']:.2f}s "
          f"opening {per['open']:.2f}s (max {mx['commit']:.2f}/"
          f"{mx['prove']:.2f}/{mx['verify']:.2f}/{mx['open']:.2f})")
    print(f"  whole-song times [MAC-BOX]: commit {tot['commit']:.1f}s + "
          f"prove {tot['prove']:.1f}s + verify {tot['verify']:.1f}s + "
          f"opening {tot['open']:.1f}s")
    print(f"  toy soundness per block 2^-{cfg.reps * (params_base.b - 1)}; "
          "NO concrete lattice hardness at toy dims (see banner)")

    manifest = {
        "spike": "PV-S2",
        "generated": datetime.now(timezone.utc).isoformat(),
        "seed": cfg.seed,
        "session": evidence["session"],
        "session_digest": evidence["session_digest"],
        "gains": list(cfg.gains),
        "takes": [
            {"file": p.name,
             "sha256": hashlib.sha256(p.read_bytes()).hexdigest(),
             **entry}
            for p, entry in zip(take_paths, evidence["takes"])
        ],
        "master": {
            "file": master_path.name,
            "sha256": hashlib.sha256(master_path.read_bytes()).hexdigest(),
            "peak": peak,
        },
        "proof": {
            "params": f"toy-class rect(1,{cfg.n_takes},"
                      f"{cfg.cols_per_block}) r={cfg.reps} q=2^61-1 "
                      "(toy_params_rect recipe, Pi1-only completeness gate)",
            "binding_rule": "chain_0=H(session_digest,gains,n_blocks,cols); "
                            "seed_k=H(chain_{k-1},k); CRS_k=ExpandCRS(seed_k); "
                            "chain_k=H(chain_{k-1},k,stmt_k)",
            "n_blocks": cfg.n_blocks,
            "cols_per_block": cfg.cols_per_block,
            "chain_0": song.chain_0.hex(),
            "chain_final": song.chain_final.hex(),
            "proof_bytes_per_block": proof_bytes,
            "commitment_bytes_per_block": commit_bytes,
            "timing_seconds_mac_box": {
                "whole_song": {name: round(value, 2)
                               for name, value in tot.items()},
                "per_block_mean": {name: round(value, 3)
                                   for name, value in per.items()},
            },
        },
        "security": [
            "toy params: NO concrete lattice hardness; per-block FS "
            f"soundness ~2^-{cfg.reps * (params_base.b - 1)}",
            "device attestation SIMULATED (HMAC stand-in)",
            "reference-class measurement: reference_timing.json",
        ],
    }
    (outdir / "manifest.json").write_text(json.dumps(manifest, indent=1))
    digest_lines = [
        f"{entry['file']} {entry['sha256']}" for entry in manifest["takes"]
    ]
    digest_lines.append(f"master.wav {manifest['master']['sha256']}")
    digest_lines += [
        f"take{i}.chain {entry['chain']}"
        for i, entry in enumerate(manifest["takes"])
    ]
    digest_lines.append(f"session {evidence['session_digest']}")
    digest_lines.append(f"chain_final {song.chain_final.hex()}")
    (outdir / "digests.txt").write_text("\n".join(digest_lines) + "\n")

    banner()
    n_good = sum(1 for _, c in CHECKS if c)
    print(f"\n  session dir: {outdir} (wavs .gitignored; manifest.json + "
          f"digests.txt + session_log.jsonl committed)")
    print(f"  wall total {PC() - t_wall:.1f}s")
    print(f"\nPV-S2: {n_good}/{len(CHECKS)} OK")
    return song, manifest


def replace_cfg(cfg, **kw):
    fields = {name: getattr(cfg, name) for name in (
        "sr", "n_samples", "n_takes", "gains", "frame", "cols_per_block",
        "reps", "seed", "session_id", "device_id", "take_peak")}
    fields.update(kw)
    return SpikeConfig(**fields)


def run_reference(cfg, outdir, cols_list=(256, 1024)):
    """One-time reference-params measurement (background this: ~40 min).

    Runs single chained blocks over the session's real opening samples at
    the reference class. 256 cols is the largest sub-block that fits the
    ~15 min budget on this machine; 1024 cols is the report's own block
    width (C3 caps reference blocks at <= 1024 cols) and doubles as the
    check of the sub-block extrapolation."""
    t_wall = PC()
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    log_path = outdir / "session_log.jsonl"

    rng = random.Random(cfg.seed)
    device_key = bytes(rng.randrange(256) for _ in range(32))
    session_key = bytes(rng.randrange(256) for _ in range(32))
    print("  re-synthesizing the session deterministically ...", flush=True)
    takes = synth_takes(cfg)
    master, _ = mix_master(cfg, takes)
    evidence = build_evidence(cfg, takes, device_key)
    session_digest = bytes.fromhex(evidence["session_digest"])

    runs = []
    for cols in cols_list:
        ref_cfg = replace_cfg(cfg, cols_per_block=cols,
                              n_samples=min(cfg.n_samples, cols))
        params_base = reference_block_params(cols, cfg.n_takes)
        good, ck = ref_constraints_ok(params_base)
        ok(f"reference constraints hold at cols={cols}", good,
           " ".join(f"{name}={val}" for name, val in ck.items()
                    if name.endswith("pi1") or name in
                    ("c0_prime", "c0_slack", "c4_hiding")))
        params = replace(params_base,
                         seed=crs_seed(chain0(ref_cfg, session_digest), 0))
        t0 = PC()
        key = expand_crs(params)
        t_crs = PC() - t0
        q = params.q
        a_rows = [[g % q for g in cfg.gains]]
        b_cols, c_cols = block_columns(ref_cfg, takes, master, 0, q)
        t0 = PC()
        rho = derive_randomness(session_key, f"refB{cols}", 0, cols,
                                params.big_n)
        tau = derive_randomness(session_key, f"refC{cols}", 0, cols,
                                params.big_n)
        t_rand = PC() - t0
        print(f"  cols={cols}: CRS {t_crs:.1f}s, randomness {t_rand:.1f}s; "
              f"committing ...", flush=True)
        tb, tc, proof, t_commit, t_prove = prove_block(
            key, a_rows, b_cols, c_cols, rho, tau
        )
        print(f"  cols={cols}: commit {t_commit:.1f}s prove {t_prove:.1f}s; "
              f"verifying ...", flush=True)
        t0 = PC()
        accepted = verify_pi1(key, a_rows, tb, tc, proof)
        t_verify = PC() - t0
        t0 = PC()
        mismatch = opening_check(key, c_cols, tau, tc)
        t_open = PC() - t0
        ok(f"reference block ACCEPTS at cols={cols} "
           f"({cols / cfg.sr * 1000:.0f} ms of audio)", accepted,
           f"commit {t_commit:.1f}s prove {t_prove:.1f}s verify "
           f"{t_verify:.1f}s open {t_open:.1f}s [MAC-BOX]")
        ok(f"reference published-master opening clean at cols={cols}",
           mismatch is None)
        p_ints = proof_ints(params)
        runs.append({
            "cols": cols,
            "seconds_of_audio": cols / cfg.sr,
            "crs_seconds": round(t_crs, 2),
            "commit_seconds": round(t_commit, 2),
            "prove_seconds": round(t_prove, 2),
            "verify_seconds": round(t_verify, 2),
            "opening_seconds": round(t_open, 2),
            "proof_ints": p_ints,
            "proof_bytes_8B_int": p_ints * 8,
            "commitment_ints": 2 * cols * (params.k + params.n),
            "commitment_bytes_8B_int": 2 * cols * (params.k + params.n) * 8,
            "accepted": accepted,
        })

    # honest extrapolation: linear in cols for commit/opening; prove and
    # verify have a large cols-independent floor (r x [gaussian masks +
    # w/u commits x rejection restarts | 2 G1 matvecs]) plus a linear part
    # — fit both from the two measured widths.
    extrap = {}
    if len(runs) >= 2:
        lo, hi = runs[0], runs[-1]
        span = hi["cols"] - lo["cols"]
        fits = {}
        for name in ("commit_seconds", "prove_seconds", "verify_seconds",
                     "opening_seconds"):
            slope = (hi[name] - lo[name]) / span
            floor = max(0.0, lo[name] - slope * lo["cols"])
            fits[name] = (floor, slope)
        blocks_1024 = -(-cfg.n_samples // 1024)
        song_seconds = {
            name: blocks_1024 * (floor + slope * 1024)
            for name, (floor, slope) in fits.items()
        }
        extrap = {
            "model": "t(cols) = floor + slope*cols fit on the two measured "
                     "widths; whole song = n_blocks x t(1024) [MODEL]",
            "per_block_1024_fit_seconds": {
                name: round(floor + slope * 1024, 1)
                for name, (floor, slope) in fits.items()
            },
            "song_blocks_at_1024": blocks_1024,
            "song_hours_MODEL": {
                name: round(value / 3600, 1)
                for name, value in song_seconds.items()
            },
            "song_total_hours_MODEL": round(
                sum(song_seconds.values()) / 3600, 1),
        }
        print(f"\n  whole-song extrapolation at reference class [MODEL]: "
              f"{blocks_1024} blocks x 1024 cols -> "
              f"~{extrap['song_total_hours_MODEL']} h pure Python "
              f"(prove {extrap['song_hours_MODEL']['prove_seconds']} h, "
              f"verify {extrap['song_hours_MODEL']['verify_seconds']} h)")

    payload = {
        "spike": "PV-S2 --reference",
        "generated": datetime.now(timezone.utc).isoformat(),
        "params_class": "reference_params_pi1 constants at rect block shape: "
                        "q=2^54-33 b=8 r=37 N=6656 k=1728 rows=1 inner=4",
        "session_digest": evidence["session_digest"],
        "runs": runs,
        "extrapolation": extrap,
        "banner": "C1-C4 design models hold at cols<=1024 (C3 caps the "
                  "block width); estimator validation still required "
                  "(zk_lattice docstring). Times are [MAC-BOX] pure Python.",
    }
    (outdir / "reference_timing.json").write_text(json.dumps(payload, indent=1))
    if log_path.exists():
        log_append(log_path, "reference-run",
                   {"session": cfg.session_id,
                    "runs": [(r["cols"], r["prove_seconds"],
                              r["verify_seconds"]) for r in runs]})
    banner()
    n_good = sum(1 for _, c in CHECKS if c)
    print(f"\n  wrote {outdir / 'reference_timing.json'}; wall total "
          f"{(PC() - t_wall) / 60:.1f} min")
    print(f"\nPV-S2 (reference mode): {n_good}/{len(CHECKS)} OK")
    return runs, extrap


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--quick", action="store_true",
                        help="4-block smoke run into a temp dir")
    parser.add_argument("--reference", action="store_true",
                        help="one-time reference-params measurement "
                             "(~40 min; background it)")
    parser.add_argument("--ref-cols", type=int, nargs="*", default=None,
                        help="override reference block widths")
    parser.add_argument("--outdir", type=str, default=None)
    args = parser.parse_args()

    repo = Path(__file__).resolve().parent.parent
    cfg = SpikeConfig()
    if args.quick:
        cfg = replace_cfg(cfg, n_samples=QUICK_SAMPLES)
        outdir = args.outdir or tempfile.mkdtemp(prefix="pv_s2_quick_")
    else:
        outdir = args.outdir or (repo / "results" / "pv_s2_session")

    if args.reference:
        run_reference(cfg, outdir, cols_list=tuple(args.ref_cols or (256, 1024)))
    else:
        run_spike(cfg, outdir)


if __name__ == "__main__":
    main()
