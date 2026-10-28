"""Independent fresh-allocation message oracle; no lease model imports."""
import hashlib
import struct

def fresh_result(payload):
    # A constructor has zeroed the full mapped active range. The oracle waits
    # for the producer, writes every coordinate and returns exactly nv pairs.
    n = len(payload)
    memory = bytearray(8 * (n + 1))
    for i, value in enumerate(payload):
        struct.pack_into('<Q', memory, i * 8, value)
    struct.pack_into('<Q', memory, n * 8, 1)
    return tuple(struct.unpack_from('<Q', memory, i * 8)[0] for i in range(n))

def chain(previous, payload):
    return hashlib.sha256(previous + b''.join(struct.pack('<Q', x) for x in payload)).digest()

def fresh_count(attempts):
    allocations = mappings = words = 0
    for degree, support, tail_log, mapped in attempts:
        nv = degree + 1
        allocations += 1  # eager cached-read fallback
        words += 2 * nv
        if mapped:
            allocations += 1
            mappings += 1
            words += 2 * nv + 1
        if tail_log:
            allocations += 1
            words += (20 + int(support)) * (1 << tail_log) * 2
    return {'allocations': allocations, 'mapping_calls': mappings, 'cumulative_requested_bytes': words * 8}
