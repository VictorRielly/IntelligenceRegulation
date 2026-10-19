"""Generate tiny Rust reference from read-only owner snapshots; no Cargo."""
import re
from pathlib import Path
H=Path(__file__).resolve().parent

def span(s,marker):
    start=s.index(marker); op=s.index('{',start); depth=0
    # Ignore braces in comments/string literals while preserving exact source.
    masked=re.sub(r'//[^\n]*|"(?:\\.|[^"\\])*"',lambda m:' '*len(m[0]),s)
    for i in range(op,len(s)):
        depth+=(masked[i]=='{')-(masked[i]=='}')
        if depth==0:return s[start:i+1]
    raise ValueError(marker)

def generate():
    a=(H/'native/hashline__src__private_block__argument.rs').read_text()
    l=(H/'native/hashline__src__private_block__layout.rs').read_text()
    s=(H/'native/hashline__src__private_block__shape.rs').read_text()
    consts='\n'.join('const '+n+':usize='+v+';' for n,v in re.findall(r'pub\(crate\) const (\w+): usize = (\d+);',l))
    ids=span(l,'pub(crate) struct Ids')+'\nimpl Ids {\n'
    for marker in ['pub(crate) fn new(sh:', 'pub(crate) fn at(', 'pub(crate) fn nr(', 'pub(crate) fn ns(', 'pub(crate) fn mr(', 'pub(crate) fn ms(', 'pub(crate) fn pl(', 'pub(crate) fn sr(', 'pub(crate) fn sg(', 'pub(crate) fn n_a(']:
        ids+=span(l,marker)+'\n'
    ids+='}\n'
    ids=ids.replace('super::shape::Shape','Shape')
    shape='''struct Shape {ln:usize,ls:usize,lp:usize,norm_wrho:u32,wrho_s:u32,sh_ao:u32,sh_z:u32,sh_g:u32,sh_h:u32,sh_qkv:u32,sh_o:u32,sh_s:u32}
impl Shape {
 fn limbs_norm(&self)->usize{self.ln} fn limbs_sigma_s(&self)->usize{self.ls} fn limbs_p(&self)->usize{self.lp}
 fn norm_top_is_full_byte(&self)->bool{self.norm_wrho==8*self.ln as u32}
'''+span(s,'pub(crate) fn a_plane_doms(')+'\n}\n'
    b='''struct Layout { ids:Ids } impl Layout {fn ids(&self)->&Ids{&self.ids}}
struct B<'a>{lay:&'a Layout,tabs:Vec<usize>,shaped:Vec<usize>}
impl<'a> B<'a> {fn a(&mut self,p:usize)->Result<usize,String>{self.tabs.push(p);Ok(self.tabs.len()-1)}
'''+span(a,'fn a_range(')+span(a,'fn tab(')+'\n}\n'
    lookups=span(l,'pub(crate) struct Lk')+'\n'
    for marker in ['fn byte(', 'fn scaled(', 'fn sym(', 'pub(crate) fn lookups_at(']:lookups+=span(l,marker)+'\n'
    lookups=lookups.replace('super::shape::Shape','Shape')
    cat='''#[no_mangle] pub unsafe extern "C" fn catalog(ln:usize,nw:u32,ls:usize,ao:u32,z:u32,out:*mut usize)->usize {
 let sh=Shape{ln,ls,lp:2,norm_wrho:nw,wrho_s:8*ls as u32-1,sh_ao:ao,sh_z:z,sh_g:8,sh_h:14,sh_qkv:8,sh_o:9,sh_s:6};
 let ids=Ids::new(&sh).unwrap();let lay=Layout{ids};let mut b=B{lay:&lay,tabs:vec![usize::MAX;5],shaped:vec![]};
 let idx=b.a_range(lay.ids.at(A_X),lay.ids.at(A_RDL)).unwrap();
 let mut v=vec![b.tabs.len()];v.extend(idx);v.push(b.shaped.len());v.extend(b.shaped);
 let lks=lookups_at(&sh,&lay.ids,Dom::D);v.push(lks.len());
 for q in lks {assert_eq!(q.terms.len(),1);v.extend([q.terms[0].0,q.terms[0].1 as usize,q.cst as usize]);}
 for (i,x) in v.iter().enumerate(){*out.add(i)=*x;}v.len()
}
'''
    # Exact native Fp2 operation semantics are replaced by u128 modular reference.
    old=H.parent/'dzc-affine-aggregate-20261018'
    field=(old/'shim.rs').read_text().split('include!("constants.rs.inc");')[0]
    gate=span(a,'struct Gate(') if False else 'struct Gate(Option<usize>);\n'+span(a,'impl Gate')
    pad=span(a,'struct PadTerm')+'\n'+span(a,'impl PadTerm')
    helper=span(a,'struct LkT')+'\n'+span(a,'fn helper_sum(')
    d=a[a.index('        SC_DZC => {'):a.index('        SC_FZC => {')]
    closure=span(d,'let poly = move |v: &[Fp2]|')
    (H/'native-full-closure.rs.inc').write_text(closure.removeprefix('let poly = ')+'\n')
    full='''#[no_mangle] pub unsafe extern "C" fn original(vp:*const u64,nt:usize,mp:*const u64,nm:usize,np:*const u64,cp:*const u64,ip:*const usize,sp:*const usize,wp:*const usize,lp:*const i64,nlk:usize,zp:*const u64,out:*mut u64){
 let v=std::slice::from_raw_parts(vp as *const Fp2,nt);let mu=std::slice::from_raw_parts(mp as *const Fp2,nm);let nu=std::slice::from_raw_parts(np as *const Fp2,2);
 let c=std::slice::from_raw_parts(cp,8);let idx=std::slice::from_raw_parts(ip,81);let sp=std::slice::from_raw_parts(sp,7);
 let (ig,igm,id,idm,h0,ln)=(sp[0],sp[1],sp[2],sp[3],sp[4],sp[5]);let gd=Gate(if sp[6]==usize::MAX{None}else{Some(sp[6])});
 let w=std::slice::from_raw_parts(wp,4*ln);let lw=|r:usize|->Vec<(usize,Fp)>{(0..ln).map(|j|(w[r*ln+j],(1u128<<(8*j)) as u64)).collect()};
 let (w_nr,w_ns,w_mr,w_ms)=(lw(0),lw(1),lw(2),lw(3));
 let ls=std::slice::from_raw_parts(lp,3*nlk);let lks:Vec<LkT>=(0..nlk).map(|j|LkT{terms:vec![(ls[3*j] as usize,k(ls[3*j+1]).a)],cst:k(ls[3*j+2]).add(k(19))}).collect();
 let alpha=Fp2{a:101,b:3};let zz=std::slice::from_raw_parts(zp as *const Fp2,1)[0];let mut pz=PadTerm::none();
 if gd.0.is_some(){pz.mu=mu[11+nlk.div_ceil(2)];pz.add(gd.0,&idx[A_X..=A_RDL],zz);}
 let (b_num,b_num_m,b_dv,b_den,b_p1)=(c[0],c[1],c[2],c[3],256u64);let (b_ao,b_z)=(c[4],c[6]);let (k_ao_half,k_z_half)=(Fp2{a:c[5],b:0},Fp2{a:c[7],b:0});
 let poly=include!("native-full-closure.rs.inc");let r=poly(v);*out=r.a;*out.add(1)=r.b;
}
'''
    # Padded generic extra limbs require the shaped pad list, not toy idx slice.
    full=full.replace('&idx[A_X..=A_RDL]','&(5..sp[2]).collect::<Vec<usize>>()')
    core=span(s,'pub(crate) fn derive_at_width(')
    dmax=next(l.strip() for l in core.splitlines() if l.strip().startswith('let d_max ='))
    wrho=next(l.strip() for l in core.splitlines() if l.strip().startswith('let wrho ='))
    norm=span(s,'fn isqrt_i128(')+span(s,'fn bit_length(')+'\nconst INT16_ABS:i128=32_768;\n'
    norm+='''#[no_mangle] pub unsafe extern "C" fn norm_window(width:usize,ceps:i64,tn:u32)->u32 {
 struct Cal{ceps:i64,tn:u32}impl Cal{fn derive(&self,width:usize)->u32{'''+dmax+wrho+'''wrho}}
 Cal{ceps,tn}.derive(width)}\n'''
    text=field+'\n'+consts+'\nconst F_P:u32=9;\n#[derive(Clone,Copy,Debug,PartialEq)]enum Dom{T,Ht,L,D,Q,Kv,S,F,Tab}\n'+shape+ids+b+lookups+cat+gate+pad+helper+full+norm
    (H/'shim.rs').write_text(text)
    return ['rustc','--edition=2021','--crate-type=cdylib','-C','codegen-units=1','-C','opt-level=0','shim.rs','-o','isolated.so']

if __name__=='__main__':print(generate())
