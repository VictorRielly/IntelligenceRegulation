"""Synthetic support-only certificate contract. Not a native security capability."""
from dataclasses import dataclass

ORDER = ('wq', 'wk', 'wv', 'wo', 'gamma_a', 'gamma_m', 'wg_t', 'wu_t', 'wd_t')

@dataclass(frozen=True)
class Shape:
    width: int
    hidden: int
    q_heads: int
    kv_heads: int
    head_dim: int
    d_pad: int
    f_pad: int
    h_pad: int
    tokens: int = 2
    f_e: int = 8
    dd_cap: int = 0

def axis(sh, role):
    d = tuple(i < sh.width for i in range(sh.d_pad))
    f = tuple(i < sh.hidden for i in range(sh.f_pad))
    q = tuple((i // sh.head_dim) % (sh.h_pad // sh.kv_heads) < sh.q_heads // sh.kv_heads
              for i in range(sh.h_pad * sh.head_dim))
    kv = (True,) * (sh.kv_heads * sh.head_dim)
    return {'wq': (q, d), 'wk': (kv, d), 'wv': (kv, d), 'wo': (d, q),
            'gamma_a': ((True,), d), 'gamma_m': ((True,), d),
            'wg_t': (d, f), 'wu_t': (d, f), 'wd_t': (f, d)}[role]

def support_key(sh, role):
    # Minimal support predicate rather than full Shape. Tables are NEVER cached.
    a, b = axis(sh, role)
    return role, a, b

def support_error(role, a, b, o, i):
    q_outer = role == 'wq'
    q_inner = role == 'wo'
    if not a[o]:
        return 'head support' if q_outer else 'width support'
    if not b[i]:
        return 'head support' if q_inner else 'width support'
    return None

def scan(sh, role, words, stats):
    a, b = axis(sh, role)
    off = [i for i, ok in enumerate(b) if not ok]
    violation = False
    for o, ok in enumerate(a):
        stats['rows'] += 1
        for i in (off if ok else range(len(b))):
            stats['support_reads'] += 1
            if words[o * len(b) + i]:
                violation = True
                break
        if violation:
            break
    if not violation:
        return None
    # Native first-error sequential fallback; count separately from honest reads.
    for o in range(len(a)):
        for i in range(len(b)):
            stats['fallback_reads'] += 1
            if words[o * len(b) + i]:
                e = support_error(role, a, b, o, i)
                if e:
                    return e
    raise AssertionError('violation must have a first error')

def tables(sh, t, half):
    if half == 'attention':
        hd = sh.head_dim // 2
        if len(t['cos']) != sh.tokens * hd or len(t['sin']) != sh.tokens * hd or len(t['exp']) != 256:
            return 'attention table shape'
        if any(not -16 <= x <= 16 for x in t['cos'] + t['sin']) or t['cos'][:hd] != (16,) * hd or t['sin'][:hd] != (0,) * hd:
            return 'rope structure'
        e = t['exp']; top = 1 << sh.f_e
        if e[0] != top or any(not 0 <= x <= top for x in e) or any(x < y for x, y in zip(e, e[1:])):
            return 'exp structure'
    else:
        if len(t['act']) != 256:
            return 'activation table shape'
        if sh.hidden < sh.f_pad and t['act'][128] != 0:
            return 'activation pad zero'
    return None

def validate(sh, words, t, keys=None):
    stats = dict(rows=0, support_reads=0, fallback_reads=0, cache_hits=0)
    for roles, half in [(ORDER[:5], 'attention'), (ORDER[5:], 'ffn')]:
        if any(len(words[r]) != len(axis(sh, r)[0]) * len(axis(sh, r)[1]) for r in roles):
            return half + ' weight shape', stats
        for r in roles:
            if keys is not None and keys[r] == support_key(sh, r):
                stats['cache_hits'] += 1
            else:
                e = scan(sh, r, words[r], stats)
                if e:
                    return (half + ': ' + r + ': ' + e), stats
        e = tables(sh, t, half)
        if e:
            return half + ': ' + e, stats
    if sh.dd_cap and len(set(t['exp']) | {0}) > sh.dd_cap:
        return 'DD capacity', stats
    return None, stats

class CheckedWeights:
    """Own immutable copied bytes; no external certificate parameter.

    Python privacy is conventional, not an unforgeable Rust capability.
    Native child-module encapsulation and mutation audit are still required.
    """
    __slots__ = ('__words', '__keys')
    def __init__(self, sh, words, t):
        frozen = {r: bytes(words[r]) for r in ORDER}
        e, _ = validate(sh, frozen, t)
        if e:
            raise ValueError(e)
        self.__words = frozen
        self.__keys = {r: support_key(sh, r) for r in ORDER}
    def check(self, sh, t):
        return validate(sh, self.__words, t, self.__keys)
    def words(self):
        return self.__words.copy()

def table_fixture(sh):
    hd = sh.head_dim // 2
    return dict(cos=(16,) * (sh.tokens * hd), sin=(0,) * (sh.tokens * hd),
                exp=tuple((1 << sh.f_e) - min(i, 1 << sh.f_e) for i in range(256)),
                act=(0,) * 256)
