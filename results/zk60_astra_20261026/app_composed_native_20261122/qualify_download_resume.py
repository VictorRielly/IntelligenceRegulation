"""Compare HTTP byte ranges of a retained public post with Python's USTAR writer."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile
from unittest.mock import Mock, patch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2]/'apps/proven-media'))
from fastapi.testclient import TestClient
from proven_media import app, manifest, public_store_download
from proven_media.publisher import LocalChainPublisher


class TarDigest:
    """tarfile pads to a 10 KiB record after the two standard end blocks."""
    def __init__(self, extent):
        self.remaining = extent
        self.digest = hashlib.sha256()

    def write(self, data):
        count = min(self.remaining, len(data))
        self.digest.update(memoryview(data)[:count])
        assert not any(memoryview(data)[count:]), 'nonzero trailing bytes in independent archive'
        self.remaining -= count
        return len(data)


def qualify(pilot):
    source = json.loads((pilot/'RESULT.json').read_bytes())
    assert source['public_fixture_only'] and source['author_native_rechecks_with_owner_binding'] == 3
    signed = json.loads((pilot/'manifest.json').read_bytes())
    key = json.loads((pilot/'publisher_public_key.json').read_bytes())['public_key']
    assert manifest.verify_signature(signed, key)['accepted']
    pid = signed['item']['post_id']
    public = Path(source['public_scratch'])
    assert all((public/path).is_dir() for path in ('bundle-store', 'chain/anchors'))
    publisher = LocalChainPublisher(public)
    members = public_store_download.store_members(publisher, pid, signed)
    post = {'status':'published', 'manifest':json.dumps(signed)}
    route = f'/api/posts/{pid}/verification-store.tar'
    with patch.object(app.S, 'store', Mock(post=Mock(return_value=post)), create=True), \
            patch.object(app.S, 'publisher', publisher, create=True):
        client = TestClient(app.app)
        try:
            head = client.head(route)
            head.raise_for_status()
            etag, size = head.headers['etag'], int(head.headers['content-length'])
            assert not head.content and head.headers['accept-ranges'] == 'bytes'
            assert size == source['downloaded_store_bytes'] and len(members) == source['downloaded_store_members']
            downloaded = hashlib.sha256()
            start, requests = 0, 0
            while start < size:
                # First break a TAR header. The later requests cross data,
                # padding and member boundaries at different offsets.
                stop = min(size, start + (511 if start == 0 else (16 << 20) + 3))
                response = client.get(route, headers={'Range':f'bytes={start}-{stop-1}', 'If-Range':etag})
                assert response.status_code == 206 and response.headers['etag'] == etag
                assert response.headers['content-range'] == f'bytes {start}-{stop-1}/{size}'
                assert int(response.headers['content-length']) == len(response.content) == stop-start
                downloaded.update(response.content)
                start, requests = stop, requests+1
            beyond = client.get(route, headers={'Range':f'bytes={size}-', 'If-Range':etag})
            assert beyond.status_code == 416 and beyond.headers['content-range'] == f'bytes */{size}'
        finally:
            client.close()

    reference = TarDigest(size)
    with tarfile.open(fileobj=reference, mode='w|', format=tarfile.USTAR_FORMAT) as archive:
        for name, src, length in members:
            info = tarfile.TarInfo(name)
            info.size = length
            with (io.BytesIO(src) if isinstance(src, bytes) else src.open('rb')) as payload:
                archive.addfile(info, payload)
    assert reference.remaining == 0 and downloaded.digest() == reference.digest.digest()
    return dict(passed=True, source_pilot=pilot.name, transport='in-process ASGI HTTP',
                bytes=size, files=len(members), partial_responses=requests, first_range_bytes=511,
                archive_sha256=downloaded.hexdigest(), independent_ustar_sha256=reference.digest.hexdigest(),
                etag=etag, unsatisfiable_status=beyond.status_code)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pilot', type=Path)
    args = parser.parse_args()
    if not __debug__:
        raise RuntimeError('Qualification requires enabled assertions')
    print(json.dumps(qualify(args.pilot.resolve()), indent=2))
