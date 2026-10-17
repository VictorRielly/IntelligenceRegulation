#!/usr/bin/env python3
"""Independent integer norm checker. No prover/imports/model witness involved."""
import hashlib
import json
import math
from pathlib import Path

P = 2**64 - 2**32 + 1
TN = 11
W = 2**32
ROOT = Path(__file__).resolve().parents[2]


def norm(row, gamma, cn=1024, eps=1, bits=32):
    ss = eps + sum(x*x for x in row)
    d = math.isqrt(ss)
    den = d * 4096
    assert den > 0
    out = []
    for x, g in zip(row, gamma):
        n = 2*cn*g*x + d*2048
        q, r = divmod(n, den)
        s = den-1-r
        # Independently reconstruct relation and establish quotient uniqueness
        # by its defining inequalities, rather than comparing two divmods.
        assert q*den <= n < (q+1)*den
        assert 2*cn*g*x + d*2048 - q*den-r == 0
        assert r+s+1 == den
        out.append((q, r, s))
    return {'d': d, 'ss': ss, 'den': den,
            'max_rho': max(v[1] for v in out),
            'max_sigma': max(v[2] for v in out),
            'output_in_range': all(-127 <= v[0] <= 127 for v in out),
            'window_pass': all(0 <= v[1] < 2**bits and 0 <= v[2] < 2**bits for v in out)}


def check():
    cases = []
    for width in (2048, 4096):
        for x in (32767, -32768):
            for gain in (0, 1, 127, -128):
                n = norm([x]*width, [gain]*width)
                cases.append(dict(width=width, x=x, gain=gain, **n))
    # Counterexample to D>2^20 => no four-limb proof: gamma 0 yields
    # centered remainders and passes, without violating signed byte gain.
    centered = norm([32767]*2048, [0]*2048)
    assert centered['d'] > 2**20 and centered['window_pass']
    # Full signed-int16 extreme: rho+sigma sum already impossible in 4 limbs.
    extreme = norm([-32768]*4096, [0]*4096)
    assert extreme['d'] == 2**21 and not extreme['window_pass']
    assert extreme['den']-1 > 2*(W-1)
    # Locate a legal nonzero gain where individual remainder fails even though
    # den <= 2W-1 (so a possible pair exists). This is a concrete completeness
    # failure, distinct from the above impossibility theorem.
    uncentered = next(c for c in cases if c['den'] <= 2*W-1 and not c['window_pass'])
    # Sharp denominator boundaries, independently enumerate all residues for a
    # small analogous window; proves necessary/sufficient pair condition and
    # guaranteed-all-residues threshold, not just one honest witness.
    for window in (2, 4, 8, 16, 32):
        for den in range(1, 2*window+3):
            accepted = [r for r in range(den) if r < window and den-1-r < window]
            assert bool(accepted) == (den <= 2*window-1)
            assert (len(accepted) == den) == (den <= window)
    # Exactly rounded norm restriction includes epsilon: isqrt(ss)<=2^20
    # iff ss < (2^20+1)^2. ||x||<=2^20 is sufficient only with an epsilon cap.
    boundary = norm([-32768]*1024, [0]*1024, eps=2**21+1)
    assert boundary['d'] == 2**20+1
    # Signed Euclidean rounding differs from truncation and rounds half upward.
    assert (-3)//2 == -2 and int(-3/2) == -1
    for d in (1, 2**20, 2**20+1, 2**21-1, 2**21):
        den=d*4096
        for q in (-127, -1, 0, 1, 127):
            for r in (0, den-1):
                n=q*den+r
                assert q*den <= n < (q+1)*den
                # Wrong quotient cannot preserve c0 with a legal remainder.
                assert not (0 <= n-(q+1)*den < den)
                assert not (0 <= n-(q-1)*den < den)
    bounds=[]
    # Soundness requires bounding adversarial legal limb values, not only
    # honest D_max; isqrt constraints first promote D to the honest bound.
    for width in (2048,4096):
        for eps in (1,1342,2684):
            dmax=math.isqrt(width*32768**2+eps)
            bits=TN+1+dmax.bit_length()
            assert (dmax*4096-1) < 2**bits
            assert 2*dmax < 2**24
            for cn in (1024, 65536):
                # gamma permits -128 (public int8), x permits -32768.
                norm_bound=2*cn*128*32768 + 2048*dmax + 4096*127*dmax + (2**bits-1)
                # Before promoting isqrt: D,d2,a1,a2 are 24-bit limbs.
                sqrt_sum_bound=(2**24-1)**2+(2**24-1)+width*32768**2+eps
                sqrt_window_bound=4*(2**24-1)
                pair_bound=2*(2**bits-1)+1+4096*(2**24-1)
                assert max(norm_bound,sqrt_sum_bound,sqrt_window_bound,pair_bound) < P
                bounds.append(dict(width=width, eps=eps, cn=cn,dmax=dmax,
                    norm_bits=bits,norm_limbs=(bits+7)//8,
                    norm_clause_absolute_bound=norm_bound,
                    isqrt_clause_absolute_bound=sqrt_sum_bound,
                    remainder_pair_absolute_bound=pair_bound))
    # Construct a modular equality that is not an integer equality: this
    # demonstrates why coefficient-domain restrictions are required.
    cn_bad=(P-1)//2
    assert cn_bad < 2**63
    fake=2*cn_bad*1*1 + 2048*1 - 0*4096 - 2047
    assert fake != 0 and fake % P == 0
    refs=['shape.rs','layout.rs','witness.rs','slot_ir.rs','argument.rs']
    paths=[ROOT/'ops/zkp-mvp/candidate/hashline/src/private_block'/r for r in refs]
    paths += [ROOT/'ops/zkp-mvp/candidate/private-block-kernel-shaped/src/lib.rs']
    sites={}
    for path in paths:
        sites[str(path.relative_to(ROOT))]=[
            {'line':i,'text':line.strip()} for i,line in enumerate(path.read_text().splitlines(),1)
            if any(s in line for s in ('NORM_CN','NORM_CEPS','NORM_TN'))]
    return {'schema':'zk60-trained-norm-contract-review/1','privacy_acceptance':False,
        'trained_execution_or_proof':False,'checks':'all assertions passed',
        'cases':cases,'counterexamples':{'four_limb_pass_above_claimed_cutoff':centered,
            'four_limb_individual_window_failure':uncentered,
            'signed_int16_endpoint_pair_impossible':extreme,
            'epsilon_changes_sufficient_row_bound':boundary,
            'unbounded_coefficient_field_alias':{'cn':cn_bad,'integer_residual':fake,'field_residual':fake%P}},
        'exact_obligations':{'full_domain':'use 32768 absolute signed-int16 bound; 8B wrho=34 at eps=1, TinyLlama wrho=33; both require 5 limbs',
            'four_limb_actual_acceptance':'max(rho,sigma)<2^32 for every channel of both norms; D<=2^20 sufficient, not necessary',
            'pair_possible':'den<=2*(2^32)-1 necessary and sufficient for some remainder pair',
            'all_remainders_fit':'den<=2^32 necessary and sufficient for every legal remainder',
            'restricted_row_bound':'sum(x^2)+Ceps < (2^20+1)^2 sufficient for all remainder pairs at tn=11',
            'no_wrap':'reported absolute bounds < Goldilocks p, for cn<=65536 and eps in tested positive range; arbitrary coefficients not accepted'},
        'bounds':bounds,'parameter_sites':sites,
        'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}


if __name__=='__main__':
    evidence=check()
    target=Path(__file__).with_name('evidence.json')
    target.write_text(json.dumps(evidence,indent=2)+'\n')
    print('PASS: exact boundary, adversarial integer, limb-window and coefficient checks; '+str(target))
