"""Source drift guards and research-artifact validation, no native execution."""
from pathlib import Path
import hashlib, json, re, resource, time
H=Path(__file__).resolve().parent

def audit(src):
    checks=[]
    def require(label, cond):
        assert cond,label
        checks.append(label)
    names=['A_G8','A_RGL','A_A16','A_U16','A_UL0','A_UL1','A_H16','A_HL0','A_HL1','A_RH0','A_RH1']
    for tag in ['gpu','r9']:
        a=src[tag+'__private_block__argument.rs']
        p=src[tag+'__private_block__pad.rs']
        s=src[tag+'__private_block__shape.rs']
        l=src[tag+'__private_block__layout.rs']
        fzc=a.split('        SC_FZC => {',1)[1].split('        SC_',1)[0]
        require(tag+' nonzero zeta before construction','let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] }' in fzc)
        require(tag+' mu permits zero','let mu = tr.challenge_fp2_vec(4 + n_help + n_pad);' in fzc)
        require(tag+' refuses zero batching challenges','if v.iter().any(|x| x.is_zero())' in a and 'zero batching challenge; discard attempt' in a)
        require(tag+' sole F host','Dom::F => SC_FZC,' in p and len(re.findall(r'=> SC_FZC,',p))==1)
        require(tag+' F planes all eleven','v.extend([Dom::F; 11]);' in s)
        vals=[int(re.search(r'const '+n+r': usize = (\d+);',l)[1]) for n in names]
        require(tag+' contiguous toy plane identities',vals==list(range(vals[0],vals[0]+11)))
        require(tag+' E outside F',int(re.search(r'const A_E: usize = (\d+);',l)[1]) not in vals)
        ar=p.split('fn a_rule(',1)[1].split('\n}',1)[0]
        require(tag+' single named exemption',ar.count('Rule::Exempt')==1 and 'plane == ids.at(A_E)' in ar and 'Some(Rule::Zero)' in ar)
        require(tag+' per-profile pad gate','!self.is_frozen_toy()' in s)
        zr=p.split('fn zero_rule_a_planes(',1)[1].split('\n}',1)[0]
        require(tag+' zero-rule selection','!s.carries_pad_rule()' in zr and 'ids.dom(*p) == dom' in zr and 'Some(Rule::Zero)' in zr)
        pt=a.split('impl PadTerm {',1)[1].split('    fn eval(',1)[0]
        require(tag+' powers begin at zero','let mut p = Fp2::ONE;' in pt and 'g.push((*t, p));' in pt and 'p = p.mul(zeta);' in pt)
        require(tag+' F term constructed once',fzc.count('pz.add(gf.0, &planes, zeta);')==1)
        require(tag+' F true/padded geometry','Dom::F => self.tokens * self.hidden' in s and 'Dom::F => clog2(self.t_pad * self.f_pad)' in s)
    c=src['gpu__gpu__cuda.rs'];d=src['gpu__gpu__fzc.rs'];k=src['gpu__gpu__fzc_kernels.cu']
    for label,needle in [('BASE all A and support','let base_table = |t: usize| (3..=13).contains(&t) || (supp && t == 20);'),
                         ('BASE begins at split','let mut base = split;'),
                         ('raw fused guard','&& fzc_fused()'),('raw switch guard','&& fzc_raw()'),
                         ('raw n guard','&& n >= 3'),('raw tail strict boundary','&& n - 1 > tail_log'),
                         ('raw resident index guard','dev.is_some() || !(3..=19).contains(&t)'),
                         ('BASE first round only','let base = self.base && self.next == 0;'),
                         ('raw first round only','let raw = i32::from(self.raw && self.next == 0);')]:
        require(label,needle in c)
    require('helper and Eq disable BASE',c.count('if base_table(t) {\n                        base = false;')>=2)
    require('Host BASE full check','if base && base_table(t) && !v.par_iter().all(|x| x.c1.is_zero())' in c)
    require('Public BASE cached property','if base_table(t) && !cache[at].base' in c)
    require('fixed eleven coefficients','pub const N_A_F: usize = 11;' in d)
    require('FZ PADW two words each','pub const FZ_PADW: usize = 62;' in d and 'pub const FZ_LEN: usize = 84;' in d)
    require('params weights unscaled','put(&mut p, FZ_PADW + 2 * (*t - T_A), *w);' in d)
    require('params mupad empty behavior','if self.pad.is_empty() { Fp2::ZERO } else { self.mu_pad }' in d)
    require('preserve duplicate/out-of-range refusal','seen[*t - T_A]' in d and '*t < T_A || *t >= T_A + N_A_F' in d)
    require('phase1b raw only','if (raw && !FOLD)' in k)
    require('both endpoints derived','fzs_derived_at(sv, sd, lane, false, which, sp)' in k and 'fzs_derived_at(sv, sd, lane, true, which, sp)' in k)
    s=src['r9__private_block__shape.rs']
    require('8B T32 row width','const LLAMA3_8B_LOG_COLS: usize = 13;' in s)
    l8=s.split('fn llama3_8b_log_cols(',1)[1].split('\n}',1)[0]
    require('8B registered larger row widths','64 => Some(13)' in l8 and '128 => Some(14)' in l8)
    require('R9 DD and non-DD retain eleven F planes',s.count('v.extend([Dom::F; 11]);')==2)
    ntt=src['gpu__gpu__kernels.cu']
    p1=ntt.split('void k_ntt_p1(',1)[1].split('// [UPERF3-AO]',1)[0]
    require('NTT reversal already fused into input load','__brev((u32)x)' in p1 and 'sh[q] = (r < n_src) ? s[r] : 0ULL;' in p1)
    require('native source stride retains hiding-pad bound','src + (size_t)row * (size_t)n_src' in p1)
    field=src['gpu__zkp-core__field.rs']
    require('quadratic extension nonresidue','pub const NONRESIDUE: u64 = 7;' in field and 'u^2 - 7' in field)
    return checks

def main():
    start=time.perf_counter()
    rows=json.loads((H/'source-manifest.json').read_text());texts={};pins=0
    for x in rows:
        b=(H/x['snapshot']).read_bytes()
        assert hashlib.sha256(b).hexdigest()==x['sha256']
        assert hashlib.sha256(Path(x['path']).read_bytes()).hexdigest()==x['sha256']
        texts[Path(x['snapshot']).name]=b.decode();pins+=1
    checks=audit(texts)
    mutants=[('gpu__private_block__argument.rs','let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] }','let zeta = if pad_on { tr.challenge_fp2_vec(1)[0] }'),
             ('r9__private_block__shape.rs','v.extend([Dom::F; 11]);','v.extend([Dom::F; 8]);'),
             ('gpu__private_block__layout.rs','const A_RH1: usize = 77;','const A_RH1: usize = 78;'),
             ('gpu__gpu__cuda.rs','&& n - 1 > tail_log','&& n - 1 >= tail_log'),
             ('gpu__gpu__cuda.rs','self.base && self.next == 0','self.base'),
             ('gpu__gpu__fzc.rs','put(&mut p, FZ_PADW + 2 * (*t - T_A), *w);','put(&mut p, FZ_PADW + 2 * (*t - T_A), self.mu_pad.mul(*w));')]
    for path,old,new in mutants:
        assert old in texts[path]
        changed=dict(texts);changed[path]=texts[path].replace(old,new)
        try:audit(changed)
        except AssertionError:pass
        else:raise AssertionError('source mutation escaped '+path+old)
    res=json.loads((H/'result.json').read_text())
    census=json.loads((H/'census.json').read_text())
    assert res['full_stack']['positions']==0
    assert all(x['reachable_nonzero_pad_counts']==([11] if x['support'] else [0]) for x in census)
    assert [(x['context_tokens'],x['log_cols']) for x in census if x['name'].startswith('8B')]==[(32,13),(64,13),(128,14)]
    result=dict(status='PASS_SOURCE_AND_ARTIFACT_AUDIT_ONLY',source_checks=len(checks),
                source_pins_unchanged=pins,source_mutation_controls=len(mutants),
                native_execution=False,wall_seconds=time.perf_counter()-start,
                rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)
    (H/'source-audit.json').write_text(json.dumps(dict(checks=checks,result=result),indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
