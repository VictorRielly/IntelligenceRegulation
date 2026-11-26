"""Export the local ledger and public objects needed to check a single W16R2 post."""
from itertools import islice
import json
import re

from . import records
from .publisher import PublishError
from .w16r2_public_verifier import signed_post_coverage


def store_members(publisher, pid, signed):
    coverage = signed_post_coverage(signed)
    if (not coverage or coverage['accepted_chunks'] != coverage['planned_chunks']
            or signed['item']['post_id'] != pid or not re.fullmatch(r'[0-9a-f]{32}', pid)):
        raise PublishError('The published post needs its complete signed proof inventory.')

    # Copy only immutable objects reachable from this post and the block prefix
    # through its last anchor. Other posts may share a batch or a segment.
    members = []
    objects = set()
    anchors = []
    for entry in signed['entries']:
        category, chunk = entry['category'], entry['chunk']
        anchor = publisher.anchor_of(pid, category, chunk)
        if not anchor or anchor.status != 'anchored':
            raise PublishError('The post is waiting for its local ledger batch.')
        if ((anchor.post_id, anchor.category, anchor.chunk) != (pid, category, chunk)
                or anchor.manifest_sha256 != entry['bundle'].get('manifest_sha256')
                or anchor.leaf_hash != entry['anchor'].get('leaf_hash')
                or type(anchor.block_number) is not int or anchor.block_number < 0
                or not re.fullmatch(r'[0-9a-f]{64}', anchor.manifest_sha256)):
            raise PublishError('The local anchor differs from the signed post.')
        inventory = json.loads(publisher.get_bytes(anchor.manifest_sha256))
        if (inventory['post_id'], inventory['chunk'], inventory['category'], inventory['statement_sha256']) != (
                pid, chunk, category, entry['statement_sha256']):
            raise PublishError('The published inventory differs from the signed entry.')
        objects.update((anchor.manifest_sha256, inventory['statement_sha256']))
        objects.update(segment['sha256'] for segment in inventory['segments'])
        if inventory.get('segments_json_sha256'):
            objects.add(inventory['segments_json_sha256'])
        members.append((f'public-store/chain/anchors/{pid}.c{chunk}.{category}.json', records.canonical(anchor.to_dict())))
        anchors.append(anchor)

    count = max(a.block_number for a in anchors) + 1
    with publisher.blocks.open('rb') as stream:
        blocks = list(islice(stream, count))
    if len(blocks) != count:
        raise PublishError('A local anchor block is missing.')
    members.append(('public-store/chain/blocks.jsonl', b''.join(blocks)))
    for anchor in anchors:
        block = json.loads(blocks[anchor.block_number])
        tx = next((tx for tx in block['txs'] if tx['tx_hash'] == anchor.tx_hash), None)
        if not tx or tx['args']['root'] != anchor.merkle_root:
            raise PublishError('A local batch transaction is missing.')
        objects.add(tx['args']['batch_file_hash'])

    for digest in sorted(objects):
        if not re.fullmatch(r'[0-9a-f]{64}', digest):
            raise PublishError('Invalid public object address.')
        path = publisher._obj(digest)
        if not path.is_file() or path.resolve() != publisher.store.resolve() / path.relative_to(publisher.store):
            raise PublishError('A public receipt object is unavailable.')
        members.append((f'public-store/bundle-store/objects/{digest[:2]}/{digest}', path))

    instructions = f"""# Verify this published post

Unpack the archive in a new directory and open the extracted post directory.
Set GUEST_APP_DIR to the absolute path of the trusted reader's apps/proven-media directory.
Set PM_PUBLISHER_KEY to the publisher's Ed25519 public key obtained through a trusted channel.
Check the signature, whole-post labels, segment bytes and inclusion in the supplied local ledger.

    python "$GUEST_APP_DIR/tools/verify_manifest.py" {pid}.manifest.json --public-key "${{PM_PUBLISHER_KEY:?set the trusted publisher key}}" --public-dir public-store --rehash

For full proof replay on a qualified Mac, also set PM_W16R2_VERIFIER_KIT to the absolute
path of the received verifier kit and export it to child processes.

    export PM_W16R2_VERIFIER_KIT
    python "$GUEST_APP_DIR/tools/prepare_w16r2_verifier.py" --check "$PM_W16R2_VERIFIER_KIT"
    python "$GUEST_APP_DIR/tools/verify_manifest.py" {pid}.manifest.json --public-key "${{PM_PUBLISHER_KEY:?set the trusted publisher key}}" --public-dir public-store --rehash --run-verifier

Full replay requires an accepted result and complete_post_proof_replay set to true.
The publisher retains the opening used to check the displayed text. The supplied ledger
is a local publisher snapshot. Its hash chain and Merkle paths can be checked offline.
"""
    members.extend([(f'{pid}.manifest.json', records.canonical(signed)), ('VERIFY.md', instructions.encode())])
    root = f'proven-media-{pid}'
    return [(f'{root}/{name}', src, len(src) if isinstance(src, bytes) else src.stat().st_size)
            for name, src in members]
