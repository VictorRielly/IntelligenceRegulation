#!/usr/bin/env python3
"""verify_manifest: check an item's signed ProofManifest (zk60.manifest/1) from public data alone.

usage: verify_manifest.py MANIFEST.json [--public-dir DIR] [--public-key HEX] [--rehash] [--run-verifier]

1. the Ed25519 signature over the canonical manifest (against --public-key if given: pin the
   publisher's key; otherwise the key named in the manifest, which proves only self-consistency);
2. each entry with an accepted proof against the local ledger: its anchor's leaf, the publication
   manifest (label, statement hash, policy, model, salted commitment), the Merkle path and the block
   chain (--rehash also re-hashes every receipt segment); an "unproved" entry must name no anchor;
3. --run-verifier: for each distinct statement among the entries, rebuild the run from the store and
   run the pinned zk60_token_io verifier through the project's resource guard.
Prints one JSON object; exit 0 if accepted (anchoring may still be pending: see "pending_anchor").
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from proven_media import config  # noqa: E402
from proven_media.manifest import verify_manifest  # noqa: E402
from proven_media.publisher import make_publisher  # noqa: E402
from verify_publication import run_verifier  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("manifest")
    ap.add_argument("--public-dir", default=str(config.PUBLIC_DIR))
    ap.add_argument("--public-key")
    ap.add_argument("--sepolia-config", help="public RPC/contract pins, no signing key required")
    ap.add_argument("--rehash", action="store_true")
    ap.add_argument("--run-verifier", action="store_true")
    a = ap.parse_args()
    m = json.loads(Path(a.manifest).read_text())
    pub = make_publisher(Path(a.public_dir), mode="base-sepolia" if a.sepolia_config else "local",
                         config_path=a.sepolia_config, read_only=True)
    r = verify_manifest(m, pub, expected_public_key=a.public_key, rehash_segments=a.rehash)
    if a.run_verifier:
        done = {}
        for e in m.get("entries", []):
            if e.get("proof_status") != "accepted":
                continue
            st = e.get("statement_sha256")
            if st not in done:
                anc = pub.anchor_of(m["item"]["post_id"], e["category"], e.get("chunk", 0))
                man = pub.resolve(anc)["manifest"] if anc else None
                done[st] = run_verifier(pub, man, m["item"]["post_id"]) if man else {"ok": False, "why": "no anchor"}
            tag = f"c{e.get('chunk', 0)}.{e['category']}"
            r["checks"][f"{tag}.proof_verifier"] = done[st]["ok"]
            if not done[st]["ok"]:
                r["accepted"] = False
                r["reasons"].append(f"{tag}.proof_verifier: the pinned verifier did not accept the receipt")
        r["proof_verifier_runs"] = done
    print(json.dumps(r, indent=1, sort_keys=True))
    return 0 if r["accepted"] else 1


if __name__ == "__main__":
    sys.exit(main())
