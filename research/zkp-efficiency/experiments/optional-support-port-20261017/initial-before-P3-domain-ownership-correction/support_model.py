"""Research port of OPTIONAL public supports; not native execution.

The four algebraic presence combinations are useful tests. Construction has
an additional native refusal: pad_on with no Ht zero-rule group. Shape policy
also accounts for P3's minimum domain length, without allocating large tables.
"""
from field_support import F
from source_port import layout


def policy(hp, qh, tp, tokens, log_cols=0, frozen=False):
    if not (0 < qh <= hp and 0 < tokens <= tp):
        raise ValueError('true size')
    if hp & (hp-1) or tp & (tp-1) or log_cols < 0:
        raise ValueError('padded size')
    sizes = (max(hp*tp, 1 << log_cols), max(hp*tp*tp, 1 << log_cols))
    true = (qh*tokens, qh*tokens*tokens)
    present = tuple(a != b and not frozen for a,b in zip(sizes,true))
    return dict(supports=present, pad_on=any(present), domain_sizes=sizes,
                true_sizes=true, frozen=frozen)


def config(present, ls=3, lp=2, lookup_count=None):
    return layout(ls=ls, lp=lp, lookup_count=lookup_count,
                  padded=any(present), supports=tuple(present))


def construction_check(cfg):
    # argument.rs:1748: even if only S pads, the native builder compares
    # zero_rule_a_planes(Ht) with [A_MX,A_SUM] and refuses an empty vector.
    if cfg['padded'] and not cfg['supports'][0]:
        raise ValueError("private block: a Dom::Ht plane is outside SC_SZC's pad-zero group")


def padding_setup(cfg, zeta):
    """Literal PadTerm::add recurrence, including re-forming prior powers."""
    groups = []
    powers = []
    multiplications = 0
    for name, indices in [('ght',[cfg['index']['mx'],cfg['index']['sum']]),
                          ('gs',cfg['splanes'])]:
        if name not in cfg['index']: continue
        power = F(1)
        for _ in range(len(powers)):
            power *= zeta
            multiplications += 1
        group = []
        for i in indices:
            group.append((i,power)); powers.append(power)
            power *= zeta; multiplications += 1
        groups.append((name,group))
    return groups, powers, multiplications


def natural_tables(hp,kv,qh,tp,tokens):
    """Independent enumeration; no P3 lift, no candidate dependency formulas."""
    if hp % kv or qh % kv: raise ValueError('head grouping')
    true_heads = {(h//(qh//kv))*(hp//kv)+h%(qh//kv) for h in range(qh)}
    out = {n:[] for n in ('mask','ght','gs')}
    for h in range(hp):
        for t in range(tp):
            for j in range(tp):
                out['mask'].append(F(int(j <= t)))
                out['ght'].append(F(int(h in true_heads and t < tokens)))
                out['gs'].append(F(int(h in true_heads and t < tokens and j < tokens)))
    return out
