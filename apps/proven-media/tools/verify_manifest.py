#!/usr/bin/env python3
"""verify_manifest: check an item's signed ProofManifest (zk60.manifest/1) from public data alone.

usage: verify_manifest.py MANIFEST.json [--public-dir DIR] [--public-key HEX] [--rehash] [--run-verifier]
       verify_manifest.py MANIFEST.json --signature-only --public-key HEX

The second form needs only the downloaded manifest and a separately trusted publisher key.
It reports publisher_signature_only and performs no publication or model proof checks.

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
from proven_media.manifest import verify_manifest, verify_signature  # noqa: E402


def unique_fields(pairs):
    fields = {}
    for name, value in pairs:
        if name in fields:
            raise ValueError("duplicate manifest field")
        fields[name] = value
    return fields


def reject_constant(value):
    raise ValueError(f"unexpected JSON number {value}")


def verify_proofs(m, pub, report, run_verifier):
    runs = {}
    coverage = report.get('signed_post_coverage')
    for entry in m.get('entries', []):
        if entry.get('proof_status') != 'accepted':
            continue
        digest = entry.get('statement_sha256')
        if digest not in runs:
            post_id = m['item']['post_id']
            anchor = pub.anchor_of(post_id, entry['category'], entry.get('chunk', 0))
            publication = pub.resolve(anchor)['manifest'] if anchor else None
            runs[digest] = run_verifier(pub, publication, post_id) if publication else {'ok':False, 'why':'no anchor'}
        tag = f"c{entry.get('chunk', 0)}.{entry['category']}"
        native = runs[digest]
        report['checks'][f'{tag}.proof_verifier'] = native['ok']
        if not native['ok']:
            report['accepted'] = False
            report['reasons'].append(f'{tag}.proof_verifier: the pinned verifier did not accept the receipt')
        elif coverage is not None:
            same = (type(native.get('content_tokens')) is int and native['content_tokens'] == coverage['content_tokens']
                    and native.get('statement_sha256') == digest)
            report['checks'][f'{tag}.proved_post_extent'] = same
            if not same:
                report['accepted'] = False
                report['reasons'].append(f'{tag}.proved_post_extent: verified statement or total differs from the signed post')
    report['proof_verifier_runs'] = runs
    category_set = m.get('category_set')
    if coverage is not None or (isinstance(category_set, dict) and category_set.get('id') == config.W16R2_CATEGORY_SET_ID):
        complete = bool(coverage and report['accepted'] and len(runs) == coverage['planned_chunks'])
        report['checks']['complete_post_proof_replay'] = complete
        if not complete and report['accepted']:
            report['accepted'] = False
            report['reasons'].append('complete_post_proof_replay: the post has unproved chunks')


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("manifest")
    ap.add_argument("--public-dir")
    ap.add_argument("--public-key")
    ap.add_argument("--signature-only", action="store_true",
                    help="check the downloaded manifest against a separately trusted --public-key, offline")
    ap.add_argument("--sepolia-config", help="public RPC/contract pins, no signing key required")
    ap.add_argument("--rehash", action="store_true")
    ap.add_argument("--run-verifier", action="store_true")
    a = ap.parse_args()
    if a.signature_only and (not a.public_key or a.public_dir or a.sepolia_config or a.rehash or a.run_verifier):
        ap.error("--signature-only requires --public-key and accepts no store, ledger or proof options")
    try:
        m = json.loads(Path(a.manifest).read_bytes(), object_pairs_hook=unique_fields, parse_constant=reject_constant)
    except (OSError, ValueError, RecursionError) as exc:
        result = {"accepted": False, "reasons": [f"Cannot read manifest: {exc}"]}
        if a.signature_only:
            result["scope"] = "publisher_signature_only"
        print(json.dumps(result))
        return 1
    if a.signature_only:
        result = {"scope": "publisher_signature_only", **verify_signature(m, a.public_key)}
        print(json.dumps(result, indent=1, sort_keys=True))
        return 0 if result["accepted"] else 1
    from proven_media.publisher import make_publisher
    from verify_publication import run_verifier
    pub = make_publisher(Path(a.public_dir or config.PUBLIC_DIR), mode="base-sepolia" if a.sepolia_config else "local",
                         config_path=a.sepolia_config, read_only=True)
    r = verify_manifest(m, pub, expected_public_key=a.public_key, rehash_segments=a.rehash)
    if a.run_verifier and r["accepted"]:
        verify_proofs(m, pub, r, run_verifier)
    print(json.dumps(r, indent=1, sort_keys=True))
    return 0 if r["accepted"] else 1


if __name__ == "__main__":
    sys.exit(main())
