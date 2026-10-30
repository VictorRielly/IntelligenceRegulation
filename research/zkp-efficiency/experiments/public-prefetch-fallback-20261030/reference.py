"""Independent whole-file reference; imports no candidate implementation."""
import hashlib
import stat


def load(directory, identity, descriptors, expected_digest, full_hashes=None):
    data = b'research-public-loader-projection/v1\0'
    for item in identity:
        encoded = str(item).encode('utf-8')
        data += len(encoded).to_bytes(8, 'little') + encoded
    for filename, extent in descriptors:
        p = directory / filename
        if '/' in filename or filename in ['', '.', '..']:
            raise ValueError('filename')
        info = p.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_size != extent:
            raise ValueError('file kind/length')
        body = p.read_bytes()
        if len(body) != extent:
            raise ValueError('read length')
        if full_hashes is not None and hashlib.sha256(body).hexdigest() != full_hashes[filename]:
            raise ValueError('raw sha')
        key = filename.encode('utf-8')
        data += len(key).to_bytes(8, 'little') + key + extent.to_bytes(8, 'little') + body
    if hashlib.sha256(data).hexdigest() != expected_digest:
        raise ValueError('bound identity/bytes')
    return data


def logical_buffers(d, f, qh, kh, hd, dp, fp, qp, t):
    # Explicit named arrays independently summed; no large buffers constructed.
    raw = {'wq': qh*hd*d, 'wk': kh*hd*d, 'wv': kh*hd*d, 'wo': d*qh*hd,
           'gamma_a': d, 'gamma_m': d, 'wg_t': d*f, 'wu_t': d*f, 'wd_t': f*d,
           'exp': 256*8, 'act': 256*2}
    pad = {'wq': qp*dp, 'wk': kh*hd*dp, 'wv': kh*hd*dp, 'wo': dp*qp,
           'gamma_a': dp, 'gamma_m': dp, 'wg_t': dp*fp, 'wu_t': dp*fp, 'wd_t': fp*dp}
    tables = {'cos': t*(hd//2)*8, 'sin': t*(hd//2)*8, 'exp': 256*8, 'act': 256*2}
    result = sum(pad.values()) + sum(tables.values())
    return {'raw11': sum(raw.values()), 'padded9': sum(pad.values()), 'returned': result,
            'known_loader_payload': sum(raw.values()) + sum(pad.values()) + result,
            'arrays': raw, 'padded_arrays': pad, 'tables': tables}
