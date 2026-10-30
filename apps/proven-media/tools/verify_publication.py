#!/usr/bin/env python3
"""verify_publication: a third party's check of one published Proven Media post, from the PUBLIC
store alone (report §7 step 7, local-chain stub).

usage: verify_publication.py --post-id ID --category CAT [--chunk N] [--public-dir DIR] [--anchor-file FILE]
                             [--content-file FILE --salt HEX] [--run-verifier]
(one publication per (item, category) proof; see tools/verify_manifest.py for all of an item's labels)

Checks, in order: the manifest is in the store under its hash; it names this post and verdict
"safe"; the statement is in the store; the leaf hashes the manifest's fields; every receipt segment
is present with its listed size and SHA-256; the block file's hash chain; the anchor transaction
carries the AnchorRef's Merkle root; the Merkle path reaches it; the batch file agrees.
--content-file + --salt: the salted content commitment matches the text (a viewer's check).
--run-verifier: rebuilds the run directory from the store (segments + statement) and runs the pinned
zk60_token_io verifier with the manifest's model pins, through the project's resource guard.
Prints one JSON object {accepted, reasons, checks, ...}; exit 0 if accepted.
"""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from proven_media import config, records  # noqa: E402
from proven_media.publisher import AnchorRef, LocalChainPublisher, content_commitment, make_publisher  # noqa: E402


def run_verifier(pub: LocalChainPublisher, manifest: dict, post_id: str) -> dict:
    from proven_media import shieldstral_runtime as runtime
    real = manifest.get('verifier_id') == runtime.BINARY_SHA
    if manifest.get("verifier_id") != config.STUB_BIN_SHA256 and not real:
        return {"ok": False, "why": "no local binary for this verifier id"}
    if real:
        choices = {c['id']: c for c in runtime.categories()}
        category = choices.get(manifest.get('category'))
        if (category is None or manifest.get('model_id') != runtime.IDENTITY
                or manifest.get('verdict') not in ('yes', 'no')
                or manifest.get('profile_id') != runtime.PROFILE_SHA
                or manifest.get('policy_id') != category['sha256']
                or records.sha256_file(runtime.BINARY) != runtime.BINARY_SHA
                or records.sha256_file(runtime.VERIFIER_EXPORT/'profile.json') != runtime.PROFILE_SHA):
            return {'ok': False, 'why': 'real classifier publication differs from pinned deployment'}
    base = pub.store.parent / "verify-from-store" / f"{post_id[:16]}-c{manifest.get('chunk', 0)}-{int(time.time())}"
    run = base / "run"
    (run / "statement").mkdir(parents=True)
    for s in manifest["segments"]:
        os.link(pub._obj(s["sha256"]), run / s["file"])
    os.link(pub._obj(manifest["statement_sha256"]), run / "statement" / "statement.json")
    if manifest.get("segments_json_sha256"):
        os.link(pub._obj(manifest["segments_json_sha256"]), run / "statement" / "segments.json")
    v = config.STUB_VERIFIER_EXPORT
    d = config.GUARD_DECL["verify"]
    log, done, res = base / "verify.log", base / "verify.done", base / "verify.guard.json"
    cmd = ["python3", str(config.GUARD), "run", "--class", d["cls"], "--need-gib", str(d["need"]), "--cap-gib", str(d["cap"]),
           "--label", f"pm-verifypub-{post_id[:12]}", "--wait-secs", "3600", "--max-secs", str(d["max"]),
           "--log", str(log), "--done", str(done), "--result-json", str(res), "--",
           str(config.STUB_BIN), "verify", "--export", str(v), "--emb", str(v), "--head", str(config.STUB_HEAD),
           "--artifact", str(run), "--expect-statement", manifest["model_id"], "--expect-token-profile", manifest["profile_id"]]
    if real:
        need, cap, maximum = runtime.RESOURCES['verify']
        cmd = ['python3', str(config.GUARD), 'run', '--class', 'cpu', '--need-gib', str(need),
               '--cap-gib', str(cap), '--label', 'pm-verifypub-'+post_id[:12], '--wait-secs', '3600',
               '--max-secs', str(maximum), '--log', str(log), '--done', str(done), '--result-json', str(res), '--',
               '/usr/bin/env', 'RAYON_NUM_THREADS=2', 'OPENBLAS_NUM_THREADS=2', 'OMP_NUM_THREADS=2',
               str(runtime.BINARY), 'verify', '--export', str(runtime.VERIFIER_EXPORT),
               '--tables', str(runtime.VERIFIER_EXPORT/'token_io'), '--policy', category['policy_id'],
               '--label', 'zk60-classify-verdict', '--artifact', str(run),
               '--expect-statement', runtime.IDENTITY, '--min-bits', '95']
    rc = subprocess.run(cmd, capture_output=True, text=True).returncode
    ev = [json.loads(x) for x in log.read_text().splitlines() if x.startswith("{")] if log.exists() else []
    expected_event = 'classified' if real else 'verified'
    successes = [e for e in ev if e.get('event') == expected_event]
    verified = successes[0] if len(successes) == 1 else None
    valid = rc == 0 and verified is not None and not any(e.get('event') in ('refused','app-outcome') for e in ev)
    if real and valid:
        valid = (verified.get('trained_statement_identity') == runtime.IDENTITY
                 and verified.get('policy') == category['policy_id']
                 and verified.get('verdict') == ('flagged' if manifest['verdict'] == 'yes' else 'not-flagged')
                 and verified.get('whole_run_floor_bits', 0) >= 95)
    return {"ok": valid, "exit": rc, "verified": verified, "rebuilt_run": str(run),
            "guard": {k: json.loads(res.read_text()).get(k) for k in ("waited_s", "guard_wall_s", "peak_rss_gib")} if res.exists() else None}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--post-id", required=True)
    ap.add_argument("--category", required=True)
    ap.add_argument("--chunk", type=int, default=0)
    ap.add_argument("--public-dir", default=str(config.PUBLIC_DIR))
    ap.add_argument("--anchor-file")
    ap.add_argument("--sepolia-config", help="public RPC/contract pins; verification never reads a signing key")
    ap.add_argument("--content-file")
    ap.add_argument("--salt")
    ap.add_argument("--run-verifier", action="store_true")
    a = ap.parse_args()
    pub = make_publisher(Path(a.public_dir), mode="base-sepolia" if a.sepolia_config else "local",
                         config_path=a.sepolia_config, read_only=True)
    if a.anchor_file:
        anc = AnchorRef.from_dict(json.loads(Path(a.anchor_file).read_text()))
    else:
        anc = pub.anchor_of(a.post_id, a.category, a.chunk)
        if anc is None:
            print(json.dumps({"accepted": False, "reasons": ["no AnchorRef for this post"]}))
            return 1
    r = pub.verify_publication(anc)
    manifest = r.pop("manifest", None)
    if a.content_file and a.salt and manifest:
        text = Path(a.content_file).read_bytes()
        ok = content_commitment(bytes.fromhex(a.salt), text) == manifest["content_commitment"]
        r["checks"]["content_commitment"] = ok
        if not ok:
            r["accepted"] = False
            r["reasons"].append("content_commitment: the text and salt do not open the published commitment")
    if a.run_verifier and manifest:
        r["proof_verifier"] = run_verifier(pub, manifest, anc.post_id)
        r["checks"]["proof_verifier"] = r["proof_verifier"]["ok"]
        if not r["proof_verifier"]["ok"]:
            r["accepted"] = False
            r["reasons"].append("proof_verifier: the pinned verifier did not accept the receipt rebuilt from the store")
    r["anchor_ref"] = anc.to_dict()
    r["checked_at"] = records.now_iso()
    print(json.dumps(r, indent=1, sort_keys=True))
    return 0 if r["accepted"] else 1


if __name__ == "__main__":
    sys.exit(main())
