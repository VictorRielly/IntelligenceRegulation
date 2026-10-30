"""Independent source anchors, counter replay, patch application and artifacts."""
import hashlib,json,re,resource,time
from pathlib import Path
from collections import OrderedDict,Counter
HERE=Path(__file__).resolve().parent
start=time.monotonic();checks=0
def ck(v):
    global checks
    checks+=1
    assert v,checks
pins=json.loads((HERE/'native-pins.json').read_text())
for pin in pins:
    ck(hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'])
    ck(hashlib.sha256((HERE/pin['snapshot']).read_bytes()).hexdigest()==pin['sha256'])
arg=(HERE/'native/hashline__src__private_block__argument.rs').read_text()
shape=(HERE/'native/hashline__src__private_block__shape.rs').read_text()
layout=(HERE/'native/hashline__src__private_block__layout.rs').read_text()
mle=(HERE/'native/zkp-core__src__mle.rs').read_text()
anchors={
 'argument':[
 'Cm::A | Cm::H => sh.log_cols','_ => sh.endpoint_log_n',
 'let logm = p.log.min(log_n);','let eq = eq_table_msb(&point[p.log - logm..]);',
 'if p.log < log_n { p.slices[0].0 % n } else { 0 }',
 'self.a_at(plane, rho(0..log), 0)','coords: rho(0..log), mask_row, ext_round: 0',
 'b.a_slice(lay.limb_off(kk), lt, rho(0..lt), 0)',
 'b.a_slice(lay.limb_off_m(kk), lt, rho(0..lt), 0)',
 'let id = b.a_slice(lay.a_off[ids.at(A_D)], lt, rho(0..lt), 0)',
 'let idm = b.a_slice(lay.a_off[ids.at(A_DM)], lt, rho(0..lt), 0)',
 'cf[log - ldh] = Coord::Flip(log - ldh)',
 'let imx = b.a_slice(lay.a_off[ids.at(A_MX)], lht, rho(0..lht), 0)',
 'let isum = b.a_slice(lay.a_off[ids.at(A_SUM)], lht, rho(0..lht), 0)',
 'let mut cq = fixed(&r_t);','cq.extend(rho(0..lkv));','cq.extend(fixed(&r_hj));','cq.extend(tq);',
 'let mut ck = fixed(&r_j);','ck.extend(rho(0..lkv));','ck.extend(tk);',
 'let mut cp = rho(0..lkv);','cp.extend(fixed(&r_hj));','cp.extend(fixed(&r_t));','cp.extend(tp);',
 'cv.extend(rho(0..lkv));','cv.extend(fixed(&r_i));',
 'let iq = b.a_at(ids.at(A_QR8), cq, 0)','let ik = b.a_at(ids.at(A_KR8), ck, 1)',
 'let ip = b.a_at(ids.at(A_P), cp, 0)','let iv = b.a_at(ids.at(A_V8), cv, 1)',
 'coords.extend(rho(0..lg(inner)))','coords.extend(rho(0..if slot == SC_DMM { lf } else { ld }))',
 'for m in 0..ext','Tab::Priv(p) if p.ext_round == m',
 'cur.iter_mut().zip(exts.iter())','*v = masked_terminal(*v, *x, e)',
 ],
 'shape':['v.extend(vec![Dom::D; 4 + 2 * ln + 8 + 2 * ln + 7]);',
 'v.extend([Dom::Q; 7]);','v.extend([Dom::Kv; 6]);','v.extend([Dom::F; 11]);',
 'v.extend(vec![Dom::S; 5 + self.limbs_p() + 2 * self.limbs_sigma_s()]);',
 'v.extend([Dom::Tab; 3]);','let per_norm = 2 + 2 * (ln + top);',
 'Dom::S => 2 + 2 + (self.limbs_p() + 1) + 2 * (self.limbs_sigma_s() + 1),',
 'self.lookups_per_position(dom).div_ceil(2)',
 'profile, tokens, 4096, 14336, 32, 128, 8, log_cols, 4, f_e',
 'name, p, tokens, 2048, 5632, 32, 64, 4, lc, 4, f_e',
 ],
 'layout':['!matches!(self, Dom::T | Dom::Ht)','a_off.push(row * n);',
 'self.a_off[self.ids.at(A_LIMB)] + k * self.sh.t_pad',
 'self.a_off[self.ids.at(A_LIMBM)] + k * self.sh.t_pad',
 '2 * (self.a_prefix[slot] + k)','2 * (self.h_prefix[slot] + k)'],
 'mle':['let rev: Vec<Fp2> = r.iter().rev().copied().collect();','*b = e.mul(ri);','*a = e.mul(one_minus);']}
for name,text in [('argument',arg),('shape',shape),('layout',layout),('mle',mle)]:
    for token in anchors[name]:ck(token in text)
# Source-backed mutation sensitivity of the anchors, including tail/offset and
# extension sites. This audits invariants, not an execution of native Rust.
anchor_mutations=0
for name,text in [('argument',arg),('shape',shape),('layout',layout),('mle',mle)]:
    for token in anchors[name]:
        mutant=text.replace(token,'REMOVED_SOURCE_ANCHOR')
        ck(token not in mutant);anchor_mutations+=1

# Apply unified patch independently, in memory. Never invoke git or native code.
patch=(HERE/'mask-tail-weights.unapplied.patch').read_text().splitlines(True)
old=arg.splitlines(True);new=[];cursor=0;i=2
while i<len(patch):
    match=re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',patch[i]);ck(bool(match))
    at=int(match[1])-1;new.extend(old[cursor:at]);cursor=at;i+=1
    while i<len(patch) and not patch[i].startswith('@@ '):
        tag,line=patch[i][0],patch[i][1:]
        if tag in ' -':ck(old[cursor]==line);cursor+=1
        if tag in ' +':new.append(line)
        i+=1
new.extend(old[cursor:]);new=''.join(new)
ck(new==(HERE/'candidate-argument.rs').read_text())
ck(new.count('if n_priv > 1 { Some(MaskTailWeights::default()) } else { None }')==1)
original=arg.split('fn mask_eval(',1)[1].split('/// `cd * plane~',1)[0]
cached=new.split('fn mask_eval_cached(',1)[1].split('/// `cd * plane~',1)[0]
restored=cached.replace('point: &[Fp2], weights: &mut MaskTailWeights)','point: &[Fp2])',1).replace('weights.at(&point[p.log - logm..])','eq_table_msb(&point[p.log - logm..])',1)
ck(restored==original)
ck(new.count('let mut tail_weights =')==1)
ck('self.point.as_slice() != point' in new and 'self.eq = Vec::new();' in new)

import catalog
counts=json.loads((HERE/'counts.json').read_text())
for entry in counts:
    g=catalog.Geometry(**entry['geometry']);cats=catalog.catalog(g)
    observed=[]
    for s,ss in enumerate(cats):
        order=sorted(enumerate(ss),key=lambda x:(x[1].ext,x[0]));cache=OrderedDict()
        builds=0;cost=0;peak=0;reads=0;groups=set()
        for _,p in order:
            # Reference suffix selection uses ascending coordinate indices.
            key=tuple(p.coords[j] for j in range(max(0,p.log-p.row),p.log))
            ck(key==p.tail);groups.add(key)
            reads+=2*(1<<len(key))
            if key in cache:del cache[key]
            else:
                builds+=1;cost+=2*((1<<len(key))-1)
                if len(cache)==entry['capacity']:cache.popitem(last=False)
            cache[key]=1<<len(key);peak=max(peak,16*sum(cache.values()))
        row=entry['slots'][s]
        ck(builds==row['builds']);ck(cost==row['candidate_eq_mul']);ck(reads==row['private_base_word_reads'])
        ck(len(groups)==row['distinct_symbolic_tails'])
        ck(row['sites']==len(ss));observed.append(peak)
    entry['independent_peak_public_weight_payload_bytes']=max(observed)
    ck(sum(x['sites'] for x in entry['slots'])==entry['totals']['sites'])
    if g.t==128 and not g.dd:
        ck(entry['totals']['sites']==174)
        ck(entry['totals']['builds']==(33 if entry['capacity']==1 else 29))
        ck(entry['totals']['private_base_word_reads']==4872192)
        ck(max(observed)==(262144 if entry['capacity']==1 else 524288))

(HERE/'counts-audited.json').write_text(json.dumps(counts,indent=2)+'\n')
r=json.loads((HERE/'result.json').read_text());ck(r['status']=='PASS')
historical=json.loads((HERE/'startup/prior__historical-extension-accounting.json').read_text())
for name,x in historical.items():
    if name not in ('cpu','gpu'):continue
    ck(hashlib.sha256(Path(x['path']).read_bytes()).hexdigest()==x['sha256'])
    ck(abs(sum(x['by_slot_s'].values())-x['all_extension_inclusive_s'])<1e-8)
result={'status':'PASS','checks':checks,'source_anchor_mutations':anchor_mutations,'source_pins':len(pins),
 'elapsed_s':time.monotonic()-start,'max_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
 'patch_compiled':False,'patch_applied':False,'native_proofs':0,
 'limits':'Metadata model/source anchor audit. Native define/refusal/transcript/PCS/receipt/privacy gates remain.'}
(HERE/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
