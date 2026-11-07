"""Paths and constants of the Proven Media demo app (one place; nothing else hard-codes a path).

Two durable data roots (private state must be outside the repository):
  PRIVATE  ~/zk60-owner-private/proven-media   0700: the database (post text), 0600 prompt
           files, the prover-private sequence directories, the owners' decommitments, job logs
  PUBLIC   ~/zk60-artifacts/proven-media       the proofs (run directories), the verifier copy of
           the public model files, the local bundle store and ledger (the Publisher stub)
Both can be moved with PM_PRIVATE_DIR / PM_PUBLIC_DIR. Startup rejects volatile
paths and overlapping roots; public evidence may live under repository results/.
"""
from __future__ import annotations

import os
from pathlib import Path

APP_DIR = Path(__file__).resolve().parents[1]
REPO = APP_DIR.parents[1]
STATIC_DIR = APP_DIR / "static"
TOOLS_DIR = APP_DIR / "tools"
POLICY_DIR = APP_DIR / "policy"
LANE_RESULTS = REPO / "results" / "zk60_media_app_20261021"
# the coordinator pauses this lane's queue by creating this file (lane rules, 2026-10-19 addendum)
HOLD_FILE = LANE_RESULTS / "HOLD"

HOME = Path(os.environ.get("HOME", "/home/victor"))
PRIVATE_DIR = Path(os.environ.get("PM_PRIVATE_DIR", str(HOME / "zk60-owner-private" / "proven-media")))
PUBLIC_DIR = Path(os.environ.get("PM_PUBLIC_DIR", str(HOME / "zk60-artifacts" / "proven-media")))
DB_PATH = PRIVATE_DIR / "app.sqlite3"
JOBS_DIR = PRIVATE_DIR / "jobs"
MEDIA_DIR = PRIVATE_DIR / "media"          # image masters + canonical canvases (served only through the app's rules)
RUNS_DIR = PUBLIC_DIR / "runs"
STORE_DIR = PUBLIC_DIR / "bundle-store"    # content-addressed (Publisher stub)
LEDGER_PATH = PUBLIC_DIR / "ledger" / "ledger.jsonl"

GUARD = REPO / "scripts" / "zk60_resource_guard.py"

# ---- the stub prover: today's next-token CLI on TinyLlama-1.1B, 32 tokens (the fastest option)
TOKEN_IO = REPO / "results" / "zk60_token_io_r1_20261017"
STUB_BIN = TOKEN_IO / "cli" / "zk60_token_io.r11.release.bin"
STUB_BIN_SHA256 = "0c9f247c0f91162177f8ed90285f8664cc4dd36ebd8934dc650804bafe5c2c6b"
STUB_EXPORT = REPO / "results" / "zk60_1b_calibration_20260929" / "export" / "pg_rot1_b4_T32_cal128"
STUB_EXPORT_NAME = STUB_EXPORT.name
STUB_HEAD = TOKEN_IO / "r2_inputs"
STUB_APPROVAL = TOKEN_IO / "approvals" / f"token_profile_approval_{STUB_EXPORT_NAME}.json"
STUB_VERIFIER_EXPORT = PUBLIC_DIR / f"verifier-export-{STUB_EXPORT_NAME}"
STUB_MODEL_NAME = "TinyLlama-1.1B (integer export pg_rot1_b4_T32_cal128)"
STUB_T = 32
STUB_BOS = 1
STUB_PAD_ID = 13                      # "\n": pads a short post to the fixed public length T
STUB_MAX_CONTENT_TOKENS = STUB_T - 1  # BOS takes position 0
TINYLLAMA_TOKENIZER = Path(os.environ.get("PM_TINYLLAMA_TOKENIZER",
    str(HOME / "models/tinyllama-1.1b-chat-fe8a4ea1/tokenizer.model")))
SPM_BPE_DIR = REPO / "results" / "zk60_1b_calibration_20260929"   # spm_bpe.py, imported read-only
SYSTEM_PYTHON = "/usr/bin/python3"    # seqgen needs numpy + the calibration code (system site-packages)

# guard declarations: measured peak + margin (lane rules addendum 2026-10-19).
# TinyLlama T32 demo runs 2026-10-20 (guard history): prove peak RSS 1.28 GiB (cgroup 2.28 incl.
# page cache), verify / owner / input-owner 0.9 GiB. seqgen self-test 2026-10-21 02:49 UTC: peak
# RSS 0.53 GiB (cgroup 1.28 incl. page cache), 13.8 s single-threaded.
GUARD_DECL = {
    "seqgen": {"cls": "light", "need": 1.0, "cap": 2.5, "max": 900},
    "prove": {"cls": "cpu", "need": 1.8, "cap": 3.5, "max": 1800},
    "verify": {"cls": "cpu", "need": 1.4, "cap": 2.5, "max": 900},
    "owner": {"cls": "cpu", "need": 1.4, "cap": 2.5, "max": 900},
    "inowner": {"cls": "cpu", "need": 1.4, "cap": 2.5, "max": 900},
}
GUARD_WAIT_SECS = int(os.environ.get("PM_GUARD_WAIT_SECS", "7200"))

# ---- the classifier the MVP will prove (D38)
CLASSIFIER_NAME = "Shieldstral-1.0-3B"
CLASSIFIER_SOURCE = "mistralai/Shieldstral-1.0-3B (Apache 2.0); text decoder only for the MVP (D38 a)"
TAU = 0.5                             # Mistral's flag threshold on softmax(z_yes, z_no)
# z_yes - z_no > ln(tau / (1 - tau)) = 0 at tau = 0.5 (D38 b)

# design rule 2 (classifier check C-6) + the operating model (D37, latest): a FIXED, pre-registered list
# of categories (Victor confirmed the three below), each one fixed Shieldstral policy text with ONE
# threshold; each item is proved once per category at creation, never re-proved. The policy texts
# here are SHORT DESCRIPTIVE PLACEHOLDERS until the calibration prep lane's exact texts land
# (results/zk60_shieldstral_prep_20261021/); a new text is a new registered id, never an edit. The app
# refuses to start if a file differs from its pinned digest.
CATEGORY_SET_ID = "pm-cats-v0"
CATEGORIES = [
    {"id": "sexual", "name": "Sexual / explicit content", "short": "explicit", "policy_id": "pm-cat-sexual-v0",
     "file": POLICY_DIR / "pm-cat-sexual-v0.txt",
     "sha256": "3ceb86a4ff399db7e0ea14c8fda0d7d0362aeccf3a40208b8b5be1b0334fdbd5"},
    {"id": "violence", "name": "Graphic violence", "short": "violence", "policy_id": "pm-cat-violence-v0",
     "file": POLICY_DIR / "pm-cat-violence-v0.txt",
     "sha256": "fe7f041fe1e3f1222c8b0ad8d57c7f5c572ff2d3000c4d9b43a887e23461df10"},
    {"id": "hate", "name": "Hate / harassment", "short": "hate", "policy_id": "pm-cat-hate-v0",
     "file": POLICY_DIR / "pm-cat-hate-v0.txt",
     "sha256": "1d9d6915c4c9f41b3d3ab1163e69df081de1913c0e85ae22b564e31266992761"},
]
# audience profiles: a viewer receives an item only if every RESTRICTED category is proved "no"
# (an unproved category counts as "yes"). Adults may restrict further ("custom": per-viewer hides).
AUDIENCES = {
    "adult": {"name": "Adult", "restricted": [], "custom": True},
    "minor": {"name": "Minor (under 18)", "restricted": ["sexual", "violence", "hate"], "custom": False},
}

# the app's publisher signing key for the proof manifests (Ed25519, LOCAL DEV KEY, 0600; no real keys)
SIGNING_KEY = PRIVATE_DIR / "publisher-dev-ed25519.key"

# ---- limits of the demo
MAX_IMAGE_BYTES = 20 * 1024 * 1024
IMAGE_MIME = {"image/png": "png", "image/jpeg": "jpg", "image/webp": "webp", "image/gif": "gif"}


def prover_mode() -> str:
    """PM_PROVER=stub (default) | shieldstral (reviewed testnet demo) | fake (no proof)
    | shieldstral-fast (lane A24 development candidate: resident GPU servers; privacy pending)."""
    return os.environ.get("PM_PROVER", "stub")


def is_shieldstral_mode(mode: str | None = None) -> bool:
    """the real Shieldstral classifier modes (reviewed r16b, or the A24 candidate)"""
    return (mode or prover_mode()) in ('shieldstral', 'shieldstral-fast')


def registered_categories():
    if is_shieldstral_mode():
        from .shieldstral_runtime import categories
        return categories()
    return CATEGORIES


def category_set_id():
    if prover_mode() == 'shieldstral-fast':
        # the same registered policies (D61); a separate screening context, so a post screened
        # in one mode is never finalized by the other
        return 'shieldstral-moderate-fast-dev-v1'
    return 'shieldstral-moderate-testnet-v1' if prover_mode() == 'shieldstral' else CATEGORY_SET_ID


# ---- chunking (D41): chunk size and overlap per hardware profile, in deploy.json
DEPLOY_FILE = Path(os.environ.get("PM_DEPLOY_FILE", str(APP_DIR / "deploy.json")))


def deploy() -> dict:
    """the active hardware profile, with the effective chunking for the stub prover (its model proves at
    most STUB_MAX_CONTENT_TOKENS content tokens per run, so the configured size is capped there)"""
    import json

    if is_shieldstral_mode():
        from .shieldstral_runtime import templates
        ts = templates()
        geometry = {t.category: {'chunk_tokens': t.chunk_size, 'overlap_tokens': t.overlap,
                                'max_chunks': t.max_chunks} for t in ts}
        chunk = min(t.chunk_size for t in ts)
        overlap = ts[0].overlap
        maximum = min(t.chunk_size + (t.max_chunks - 1) * (t.chunk_size - t.overlap) for t in ts)
        fast = prover_mode() == 'shieldstral-fast'
        return {'profile': 'shieldstral-t128-fast' if fast else 'shieldstral-t128',
                'label': 'Shieldstral T128, resident GPU servers (A24 development candidate)' if fast
                         else 'Shieldstral T128 testnet demo',
                'note': 'Registered moderate templates; each category has its own chunk plan.',
                'chunk_tokens': chunk, 'overlap_tokens': overlap, 'max_chunks': min(t.max_chunks for t in ts),
                'effective_chunk_tokens': chunk, 'effective_overlap_tokens': overlap,
                'category_geometry': geometry, 'capped_by_prover': False,
                'max_content_tokens': maximum, 'profiles': {}, 'file': None}

    d = json.loads(DEPLOY_FILE.read_text())
    name = os.environ.get("PM_PROFILE", d["active_profile"])
    p = d["profiles"][name]
    chunk = int(p["chunk_tokens"])
    eff = min(chunk, STUB_MAX_CONTENT_TOKENS)
    ov = min(int(p["overlap_tokens"]), eff - 1)
    return {"profile": name, "label": p.get("label", name), "note": p.get("note", ""),
            "chunk_tokens": chunk, "overlap_tokens": int(p["overlap_tokens"]), "max_chunks": int(p["max_chunks"]),
            "effective_chunk_tokens": eff, "effective_overlap_tokens": ov,
            "capped_by_prover": eff < chunk,
            "max_content_tokens": eff + (int(p["max_chunks"]) - 1) * (eff - ov),
            "profiles": {k: {kk: v for kk, v in pp.items()} for k, pp in d["profiles"].items()},
            "file": str(DEPLOY_FILE)}
