"""Independent dense row-major oracle: no model imports or support-key use."""
def validate(sh, words, t):
    # Construct true query positions by forward mapping logical heads.
    slots = set()
    for h in range(sh.q_heads):
        group = h // (sh.q_heads // sh.kv_heads)
        local = h - group * (sh.q_heads // sh.kv_heads)
        physical = group * (sh.h_pad // sh.kv_heads) + local
        for j in range(sh.head_dim):
            slots.add(physical * sh.head_dim + j)
    dims = {'wq': (sh.h_pad * sh.head_dim, sh.d_pad),
            'wk': (sh.kv_heads * sh.head_dim, sh.d_pad),
            'wv': (sh.kv_heads * sh.head_dim, sh.d_pad),
            'wo': (sh.d_pad, sh.h_pad * sh.head_dim),
            'gamma_a': (1, sh.d_pad), 'gamma_m': (1, sh.d_pad),
            'wg_t': (sh.d_pad, sh.f_pad), 'wu_t': (sh.d_pad, sh.f_pad),
            'wd_t': (sh.f_pad, sh.d_pad)}
    halves = [('attention', ['wq','wk','wv','wo','gamma_a']),
              ('ffn', ['gamma_m','wg_t','wu_t','wd_t'])]
    for half, roles in halves:
        if any(len(words[r]) != dims[r][0] * dims[r][1] for r in roles):
            return half + ' weight shape'
        for r in roles:
            no, ni = dims[r]
            for index, value in enumerate(words[r]):
                if value == 0:
                    continue
                o, i = divmod(index, ni)
                outer_bad = (r == 'wq' and o not in slots) or (r in ['wo','wg_t','wu_t'] and o >= sh.width) or (r == 'wd_t' and o >= sh.hidden)
                inner_bad = (r == 'wo' and i not in slots) or (r in ['wq','wk','wv','gamma_a','gamma_m','wd_t'] and i >= sh.width) or (r in ['wg_t','wu_t'] and i >= sh.hidden)
                if outer_bad:
                    return half + ': ' + r + ': ' + ('head support' if r == 'wq' else 'width support')
                if inner_bad:
                    return half + ': ' + r + ': ' + ('head support' if r == 'wo' else 'width support')
        if half == 'attention':
            h = sh.head_dim // 2
            if (len(t['cos']),len(t['sin']),len(t['exp'])) != (sh.tokens*h,sh.tokens*h,256):
                return 'attention: attention table shape'
            for x in t['cos'] + t['sin']:
                if x < -16 or x > 16:
                    return 'attention: rope structure'
            for j in range(h):
                if t['cos'][j] != 16 or t['sin'][j] != 0:
                    return 'attention: rope structure'
            es=t['exp'];bound=2**sh.f_e
            if es[0] != bound:
                return 'attention: exp structure'
            for j,x in enumerate(es):
                if x < 0 or x > bound or (j and es[j-1] < x):
                    return 'attention: exp structure'
        else:
            if len(t['act']) != 256:
                return 'ffn: activation table shape'
            if sh.hidden != sh.f_pad and t['act'][128]:
                return 'ffn: activation pad zero'
    if sh.dd_cap:
        outputs={0}
        for e in t['exp']: outputs.add(e)
        if len(outputs) > sh.dd_cap: return 'DD capacity'
    return None
