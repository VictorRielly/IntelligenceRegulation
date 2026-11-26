"""Stream a USTAR download and seek within an immutable public verification store."""
import hashlib
from pathlib import Path
import re
import tarfile
import time

from fastapi.responses import Response, StreamingResponse


def _parts(members, mtime, validator):
    parts = []
    for name, source, size in members:
        info = tarfile.TarInfo(name)
        info.size, info.mtime, info.mode = size, mtime, 0o644
        header = info.tobuf(format=tarfile.USTAR_FORMAT)
        parts.extend(((header, len(header)), (source, size)))
        padding = -size % 512
        if padding:
            parts.append((bytes(padding), padding))
        if validator is not None:
            # store_members supplies immutable CAS paths named by their SHA-256.
            # This identifies every payload without opening gigabytes of proofs.
            digest = hashlib.sha256(source).digest() if isinstance(source, bytes) else bytes.fromhex(source.name)
            validator.update(header)
            validator.update(digest)
    parts.append((bytes(1024), 1024))
    return parts


def _stream(parts, start, stop):
    offset = 0
    for source, size in parts:
        end = offset + size
        lo, hi = max(start, offset) - offset, min(stop, end) - offset
        if lo < hi:
            if isinstance(source, Path):
                with source.open('rb') as stream:
                    stream.seek(lo)
                    remaining = hi - lo
                    while remaining:
                        block = stream.read(min(remaining, 1 << 20))
                        if not block:
                            raise OSError('Archive member ended before its declared size')
                        remaining -= len(block)
                        yield block
            else:
                yield source[lo:hi]
        if end >= stop:
            break
        offset = end


def _single_range(value, total):
    """Return a half-open interval, an empty interval for 416, or None for a full response."""
    match = re.fullmatch(r'bytes=([0-9]*)-([0-9]*)', value.strip(), re.IGNORECASE | re.ASCII)
    if not match or not any(match.groups()):
        return None
    first, last = match.groups()
    # HTTP byte positions can be arbitrarily long. Saturating beyond the end
    # handles long decimal strings without an unbounded integer conversion.
    def position(digits):
        digits = digits.lstrip('0') or '0'
        return total if len(digits) > len(str(total)) else min(int(digits), total)
    if not first:
        return total - position(last), total
    start = position(first)
    stop = min(total, position(last) + 1) if last else total
    return start, max(start, stop)


def tar_download(filename, members, *, store_request=None):
    """Only a content-addressed verification store has a stable resumable representation."""
    validator = hashlib.sha256(b'proven-media/verification-store/ustar-v1\0') if store_request is not None else None
    parts = _parts(members, 0 if validator else int(time.time()), validator)
    total = sum(size for _, size in parts)
    headers = {'Content-Disposition': f'attachment; filename="{filename}.tar"', 'Content-Length': str(total)}
    media_type = 'application/x-tar'
    start, stop, status = 0, total, 200
    if store_request is not None:
        etag = '"' + validator.hexdigest() + '"'
        headers.update({'ETag': etag, 'Accept-Ranges': 'bytes', 'Cache-Control': 'no-transform'})
        matches = [item.strip() for item in store_request.headers.get('if-match', '*').split(',')]
        if '*' not in matches and etag not in matches:
            return Response(status_code=412, headers={'ETag': etag})
        cached = [item.strip().removeprefix('W/') for item in store_request.headers.get('if-none-match', '').split(',')]
        if '*' in cached or etag in cached:
            return Response(status_code=304, headers={'ETag': etag, 'Cache-Control': 'no-transform'})
        if store_request.method == 'HEAD':
            return Response(media_type=media_type, headers=headers)
        if store_request.headers.get('if-range', etag) == etag:
            interval = _single_range(store_request.headers.get('range', ''), total)
            if interval is not None:
                start, stop = interval
                headers['Content-Length'] = str(stop - start)
                if stop == start:
                    headers['Content-Range'] = f'bytes */{total}'
                    return Response(status_code=416, headers=headers)
                headers['Content-Range'] = f'bytes {start}-{stop - 1}/{total}'
                status = 206
    return StreamingResponse(_stream(parts, start, stop), status_code=status, media_type=media_type, headers=headers)
