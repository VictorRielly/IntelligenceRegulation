"""Independent operation-set reference; does not import the candidate.

Each token is an individual asynchronous use. Completion is an explicit set of
finished tokens. This reference neither uses stream counters nor accepts fences.
"""
def physically_safe(uses, finished, sealed, poisoned=False):
    return sealed and not poisoned and not (set(uses) - set(finished))


def reference_decision(uses, observed_completed, sealed, failed, poisoned):
    if not sealed:
        return "hold"
    if poisoned:
        return "quarantine"
    if set(uses).issubset(observed_completed):
        return "retire"
    return "quarantine" if failed else "hold"


def schedules(nodes, edges):
    """All topological orders via independent predecessor sets."""
    prior = {n: {a for a, b in edges if b == n} for n in nodes}
    def visit(prefix, left):
        if not left:
            yield tuple(prefix)
        for n in sorted(left):
            if prior[n].issubset(prefix):
                yield from visit(prefix + [n], left - {n})
    yield from visit([], set(nodes))
