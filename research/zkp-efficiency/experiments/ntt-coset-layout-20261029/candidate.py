"""Locally authored split-coset model; no native/GPU implementation."""
P = 2**64 - 2**32 + 1


def root(n):
    assert n > 0 and n & (n-1) == 0 and n <= 2**32
    return pow(7, (P-1)//n, P)


def transform(values, inverse=False):
    a = list(values)
    n = len(a)
    w = root(n)
    if inverse:
        w = pow(w, -1, P)
    bits = n.bit_length()-1
    for i in range(n):
        j = int(format(i, f'0{bits}b')[::-1], 2) if bits else 0
        if i < j:
            a[i], a[j] = a[j], a[i]
    width = 2
    while width <= n:
        step = pow(w, n//width, P)
        for start in range(0, n, width):
            tw = 1
            for j in range(width//2):
                u = a[start+j]
                v = a[start+j+width//2]*tw % P
                a[start+j] = (u+v) % P
                a[start+j+width//2] = (u-v) % P
                tw = tw*step % P
        width *= 2
    if inverse:
        invn = pow(n, -1, P)
        a = [v*invn % P for v in a]
    return a


def validate(msg, pad, rate, h):
    n = len(msg)
    assert n >= 2 and n & (n-1) == 0
    assert rate >= 2 and rate & (rate-1) == 0
    assert n+len(pad) <= n*rate and n*rate <= 2**32
    assert 0 < h < P and pow(h, n*rate, P) != 1
    assert all(0 <= x < P for x in msg+pad)


def materialized(msg, pad, rate, h):
    validate(msg, pad, rate, h)
    n = len(msg)
    out = transform(msg, True) + [0]*(n*rate-n)
    # Native CPU order correctly handles overlap: assign high term, then
    # later subtract any overlapping low term. GPU uses independent adds.
    for i, v in enumerate(pad):
        out[i] = (out[i]-v) % P
        out[n+i] = v
    return transform([v*pow(h, i, P) % P for i, v in enumerate(out)])


def split(msg, pad, rate, h, fault=None):
    validate(msg, pad, rate, h)
    n = len(msg)
    coeff = transform(msg, True)
    if fault == 'inverse_scale':
        coeff = [v*n % P for v in coeff]
    w = root(n*rate)
    out = [0]*(n*rate)
    for s in range(rate):
        a = h*pow(w, s, P) % P
        if fault == 'coset':
            a = pow(w, s, P)
        if fault == 'wrong_root':
            a = h*pow(root(n), s, P) % P
        A = pow(a, n, P)
        c = []
        for t, v in enumerate(coeff):
            folded = 0
            for i in range(t, len(pad), n):
                if fault == 'truncate_q' and i >= n:
                    continue
                factor = pow(A, i//n, P)
                if fault == 'fold_power':
                    factor = 1
                folded = (folded + pad[i]*factor) % P
            z = (v + (A-1)*folded) % P
            if fault == 'pad_sign':
                z = (v+(A+1)*folded) % P
            c.append(z*pow(a, t, P) % P)
        vals = transform(c)
        for j, v in enumerate(vals):
            k = s+rate*j
            if fault == 'output_order':
                k = s*n+j
            out[k] = v
    return out


def columns(rows, indices):
    # Canonical column-major byte strings, repeated requests remain repeated.
    return [b''.join(row[k].to_bytes(8, 'little') for row in rows) for k in indices]


def operation_counts(n, q, rate):
    """q<=n route only. Public preprocessing excluded and separately owed.

    Count one mul and two add/sub per literal radix2 butterfly, including
    unit twiddles/zero inputs. Inverse normalization is n mul in both arms.
    Candidate folds no high pad blocks on this guarded route. A=alpha**n
    and all alpha**t are assumed available PUBLIC tables; their preparation
    and loads are not free in a runtime claim.
    """
    assert 0 <= q <= n
    logn, logr = n.bit_length()-1, rate.bit_length()-1
    inv = n*logn//2
    bf_full = rate*n*(logn+logr)//2
    bf_split = rate*n*logn//2
    base_mul = inv+n+(n+q)+bf_full
    # For q=0 skip the absent pad multiply entirely.
    cand_mul = inv+n+rate*(n+q)+bf_split
    base_add = 2*inv+2*q+2*bf_full
    cand_add = 2*inv+rate*q+2*bf_split
    return dict(n=n,q=q,rate=rate,baseline_mul=base_mul,split_mul=cand_mul,
                mul_saved=base_mul-cand_mul,baseline_add=base_add,
                split_add=cand_add,add_saved=base_add-cand_add,
                mul_reduction=(base_mul-cand_mul)/base_mul,
                forward_butterflies_removed=bf_full-bf_split,
                extra_coef_reads_words=(rate-1)*n,
                extra_pad_reads_words=(rate-2)*q,
                candidate_power_reads=rate*n,
                baseline_power_reads=n+q,
                full_output_words=rate*n,
                baseline_compact_coef2_words=n+q,
                materialized_split_input_words=rate*n,
                custom_fused_input_kernel_required=True,
                inverse_pass_kernels=1+(logn>12),
                baseline_forward_kernels=1+(logn+logr>12),
                split_forward_kernels_if_cosets_batched=1+(logn>12))
