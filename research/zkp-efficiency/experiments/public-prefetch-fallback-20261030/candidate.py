"""Research-only public file hints. No model, proof, or authentication cache."""
import hashlib
import os
import stat
import struct
from pathlib import Path


def ranges(specs, budget):
    if budget < 0:
        raise ValueError('negative budget')
    out = []
    for name, size in specs:
        if Path(name).name != name or name in ('', '.', '..') or size < 0:
            raise ValueError('public descriptor')
        take = min(size, budget)
        # A zero length means THROUGH EOF to fadvise, not zero work.
        if take:
            out.append((name, 0, take))
            budget -= take
    return out


def hint(directory, specs, budget, advise=None):
    advise = os.posix_fadvise if advise is None else advise
    sent = []
    errors = 0
    sizes = dict(specs)
    for name, offset, size in ranges(specs, budget):
        try:
            fd = os.open(directory / name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
            try:
                st = os.fstat(fd)
                if not stat.S_ISREG(st.st_mode) or st.st_size != sizes[name]:
                    raise ValueError('advice input is not the expected regular file')
                advise(fd, offset, size, os.POSIX_FADV_WILLNEED)
                sent.append((name, offset, size))
            finally:
                os.close(fd)
        except (OSError, ValueError):
            # A hint never authorizes acceptance or an early semantic refusal.
            errors += 1
    return sent, errors


def canonical(identity, specs, payloads):
    out = bytearray(b'research-public-loader-projection/v1\0')
    for part in identity:
        b = str(part).encode()
        out.extend(struct.pack('<Q', len(b)))
        out.extend(b)
    for (name, size), b in zip(specs, payloads):
        n = name.encode()
        out.extend(struct.pack('<Q', len(n)))
        out.extend(n)
        out.extend(struct.pack('<Q', size))
        out.extend(b)
    return bytes(out)


def demand(directory, identity, specs, pinned, raw_hashes=None):
    payloads = []
    for name, size in specs:
        if Path(name).name != name or name in ('', '.', '..'):
            raise ValueError('filename')
        fd = os.open(directory / name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        try:
            st = os.fstat(fd)
            if not stat.S_ISREG(st.st_mode) or st.st_size != size:
                raise ValueError('extent/type')
            chunks = []
            left = size + 1
            while left:
                b = os.read(fd, left)
                if not b:
                    break
                chunks.append(b)
                left -= len(b)
            b = b''.join(chunks)
            if len(b) != size:
                raise ValueError('read extent')
        finally:
            os.close(fd)
        if raw_hashes is not None and hashlib.sha256(b).hexdigest() != raw_hashes[name]:
            raise ValueError('raw sha')
        payloads.append(b)
    out = canonical(identity, specs, payloads)
    if hashlib.sha256(out).hexdigest() != pinned:
        raise ValueError('rebuilt block binding')
    return out
