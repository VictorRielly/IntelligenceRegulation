//! Values-free map plan. Rebuild fixed Eq, private values and mask dots each call.
use crate::{Coord,Priv,Fp,Fp2,eq_table_msb};
#[derive(Clone,Debug,PartialEq,Eq)]
enum Op {Rho(usize),Flip(usize),Fixed}
fn signature(p:&Priv)->Vec<Op> {p.coords.iter().map(|c|match c{Coord::Rho(k)=>Op::Rho(*k),Coord::Flip(k)=>Op::Flip(*k),Coord::Fixed(_)=>Op::Fixed}).collect()}
pub struct Plan {
    identity:u64,n_vars:usize,signature:Vec<Op>,used:usize,
    lo_len:usize,fixed_lo:usize,moving:usize,
    hi_map:Vec<(usize,usize)>,lo_map:Vec<(usize,usize)>,
}
impl Plan {
    pub fn new(identity:u64,p:&Priv,n_vars:usize)->Self {
        assert_eq!(p.log,p.coords.len());
        let sig=signature(p);let lo_len=p.log/2;let hi_len=p.log-lo_len;
        let fixed_lo=sig[hi_len..].iter().filter(|x|matches!(x,Op::Fixed)).count();
        let mut used=0;let mut moving=0;
        for x in &sig {if let Op::Rho(k)|Op::Flip(k)=x {assert!(*k<n_vars);used|=1<<(n_vars-1-*k);moving+=1;}}
        let map=|ops:&[Op]|->Vec<(usize,usize)> {
            (0..1usize<<ops.len()).map(|v|{
                let(mut x,mut z)=(0,0);
                for(j,c)in ops.iter().enumerate(){let b=(v>>(ops.len()-1-j))&1;match c{
                    Op::Rho(k)=>x|=b<<(n_vars-1-*k),
                    Op::Flip(k)=>x|=(1-b)<<(n_vars-1-*k),
                    Op::Fixed=>z=(z<<1)|b,
                }}(x,z)
            }).collect()
        };
        let hi_map=map(&sig[..hi_len]);let lo_map=map(&sig[hi_len..]);
        Self{identity,n_vars,signature:sig,used,lo_len,fixed_lo,moving,hi_map,lo_map}
    }
    pub fn payload_bytes(&self)->usize {(self.hi_map.len()+self.lo_map.len())*std::mem::size_of::<(usize,usize)>()}
    pub fn execute(&self,identity:u64,p:&Priv,data:&[Fp],n_vars:usize)->Result<Vec<Fp2>,&'static str>{
        if identity!=self.identity||n_vars!=self.n_vars||p.log!=p.coords.len()||self.signature!=signature(p){return Err("public geometry identity mismatch")}
        // No value cache: Coord::Fixed contains earlier transcript challenges.
        let fixed:Vec<Fp2>=p.coords.iter().filter_map(|c|if let Coord::Fixed(f)=c{Some(*f)}else{None}).collect();
        let eqf=eq_table_msb(&fixed);
        let simple=eqf.len()==1&&eqf[0]==Fp2::ONE&&self.used.count_ones()as usize==self.moving;
        let one_slice=if p.slices.len()==1&&p.slices[0].1==Fp2::ONE{Some(p.slices[0].0)}else{None};
        let mut out=vec![Fp2::ZERO;1usize<<n_vars];let lo_mask=(1usize<<self.lo_len)-1;
        for idx in 0..1usize<<p.log {
            let(xh,zh)=self.hi_map[idx>>self.lo_len];let(xl,zl)=self.lo_map[idx&lo_mask];
            let(x,z)=(xh|xl,(zh<<self.fixed_lo)|zl);
            let v=match one_slice{Some(off)=>Fp2::from_base(data[off+idx]),None=>p.slices.iter().fold(Fp2::ZERO,|a,(off,c)|a.add(c.mul_base(data[*off+idx])))};
            if simple{out[x]=v}else{out[x]=out[x].add(eqf[z].mul(v));}
        }
        if self.used!=(1usize<<n_vars)-1{for x in 0..out.len(){if x&!self.used!=0{out[x]=out[x&self.used];}}}
        Ok(out)
    }
}
