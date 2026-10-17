"""Fresh proof-local plan, bounded batch fallback, direct split-plane writer."""
from dataclasses import dataclass
from field_model import P, ZERO, REFUSAL, batch, den

@dataclass(frozen=True)
class Plan:
    table: tuple
    alpha: tuple
    beta: tuple
    tag: tuple
    reciprocals: tuple

def prepare(table, alpha, beta, tag, c):
    table = tuple(table)
    if not table:
        raise ValueError('public table must be nonempty')
    ds = [den(i, v, alpha, beta, tag) for i, v in enumerate(table)]
    c['denominators'] += len(ds)
    c['cache_entries'] += len(ds)
    nonzero = iter(batch([d for d in ds if d != ZERO], c))
    # A zero at an unused public row MUST NOT refuse the occurrence phase.
    rs = tuple(None if d == ZERO else next(nonzero) for d in ds)
    return Plan(table, alpha, beta, tag, rs)

def write_into(pairs, table, alpha, beta, tag, chunk, lo, hi, offset, c,
               plan=None, force_cache=False):
    if chunk <= 0:
        raise ValueError('chunk must be positive')
    if offset < 0 or offset+len(pairs) > min(len(lo), len(hi)):
        raise ValueError('destination outside owned helper plane')
    if not table:
        raise ValueError('public table must be nonempty')
    # Single owned interface constructs the plan. A research-supplied plan is
    # checked in O(table size), never by inspecting private values.
    if plan is not None and (plan.table, plan.alpha, plan.beta, plan.tag) != (
            tuple(table), alpha, beta, tag):
        raise ValueError('stale public/challenge plan')
    use_cache = force_cache or len(pairs) >= len(table)
    if use_cache and plan is None:
        plan = prepare(table, alpha, beta, tag, c)
    if not use_cache:
        c['short_bypass'] += 1
    def put(j, v):
        lo[offset+j], hi[offset+j] = v
        c['destination_writes'] += 1
    for start in range(0, len(pairs), chunk):
        c['chunks'] += 1
        ds, positions = [], []
        for j in range(start, min(start+chunk, len(pairs))):
            i, value = pairs[j]
            in_range = use_cache and 0 <= i < len(table)
            if in_range:
                c['value_comparisons'] += 1
            if in_range and value == table[i]:
                c['cache_hits'] += 1
                v = plan.reciprocals[i]
                if v is None:
                    raise ZeroDivisionError(REFUSAL)
                put(j, v)
            else:
                c['fallback'] += 1
                c['denominators'] += 1
                ds.append(den(i, value, alpha, beta, tag))
                positions.append(j)
        c['max_fallback_words'] = max(c['max_fallback_words'], len(ds))
        if ds:
            c['fallback_chunks'] += 1
        for j, v in zip(positions, batch(ds, c)):
            put(j, v)
    return plan

def hybrid(pairs, table, alpha, beta, tag, chunk, c, **kw):
    sentinel = P-17
    lo, hi = [sentinel]*(len(pairs)+7), [sentinel]*(len(pairs)+11)
    write_into(pairs, table, alpha, beta, tag, chunk, lo, hi, 3, c, **kw)
    assert lo[:3]+lo[3+len(pairs):] == [sentinel]*7
    assert hi[:3]+hi[3+len(pairs):] == [sentinel]*11
    return list(zip(lo[3:3+len(pairs)], hi[3:3+len(pairs)]))
