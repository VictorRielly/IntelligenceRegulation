//! R13 plane roles and byte lookups. Profile activation is a separate gate.
use super::accuracy_precision::{Precision, Stack};
use super::layout::*;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(usize)]
pub(crate) enum Limbs {
    X, Y, Nr, Ns, Ao, Rao, X1, Ym, Mr, Ms, Z, Rd, X2,
    Q, Rq, Qr, Rqr, O, Ro, K, Rk, V, Rv, Kr, Rkr,
    Rs, P, Sr, Sg, Rg, Up, Ru, H, Rh,
}
const GROUPS: usize = Limbs::Rh as usize + 1;

pub(crate) struct AccuracyIds {
    pub(crate) map: Vec<usize>,
    pub(crate) doms: Vec<Dom>,
    groups: [(usize, usize); GROUPS],
    pub(crate) names: Vec<String>,
    pub(crate) pdict: usize,
    pub(crate) mdd: usize,
}

impl AccuracyIds {
    fn word(&mut self, dom: Dom, old: usize, name: &str) -> usize {
        let index = self.doms.len();
        if old != usize::MAX { self.map[old] = index; }
        self.doms.push(dom);
        self.names.push(name.to_string());
        index
    }
    fn group(&mut self, dom: Dom, role: Limbs, name: &str, count: usize, old: usize, old_count: usize) {
        let first = self.doms.len();
        self.groups[role as usize] = (first, count);
        for k in 0..count {
            let label=if count==1 {name.to_string()} else {format!("{name}{k}")};
            self.word(dom, if k < old_count {old+k} else {usize::MAX}, &label);
        }
    }
    pub(crate) fn new(stack: Stack, dd: bool, ls: usize) -> Result<Self, String> {
        if stack == Stack::Legacy || !(2..=3).contains(&ls) {
            return Err("R13 planes require an explicit LOW stack and two/three softmax remainder limbs".into());
        }
        let h24 = stack == Stack::LowH24;
        let mut x = Self { map: vec![usize::MAX; N_A], doms: Vec::new(), groups: [(usize::MAX,0); GROUPS],
            names: Vec::new(), pdict: usize::MAX, mdd: usize::MAX };
        for (id,name) in [(A_D,"D"),(A_DSQ,"DSQ"),(A_DM,"DM"),(A_DSQM,"DSQM")] {x.word(Dom::T,id,name);}
        x.word(Dom::Ht,A_MX,"MX"); x.word(Dom::Ht,A_SUM,"SUM");
        x.word(Dom::L,A_LIMB,"LIMB"); x.word(Dom::L,A_LIMBM,"LIMBM");
        x.word(Dom::D,A_X,"X"); x.group(Dom::D,Limbs::X,"XL",2,A_XL0,2);
        x.word(Dom::D,A_Y,"Y"); x.group(Dom::D,Limbs::Y,"YL",2,usize::MAX,0);
        x.group(Dom::D,Limbs::Nr,"NR",3,A_NR0,LN_TOY); x.group(Dom::D,Limbs::Ns,"NS",3,A_NS0,LN_TOY);
        x.word(Dom::D,A_AO,"AO"); x.group(Dom::D,Limbs::Ao,"AL",2,A_AL0,2);
        x.group(Dom::D,Limbs::Rao,"RAL",3,A_RAL,1);
        x.word(Dom::D,A_X1,"X1"); x.group(Dom::D,Limbs::X1,"X1L",2,A_X1L0,2);
        x.word(Dom::D,A_YM,"YM"); x.group(Dom::D,Limbs::Ym,"YML",2,usize::MAX,0);
        x.group(Dom::D,Limbs::Mr,"MR",3,A_MR0,LN_TOY); x.group(Dom::D,Limbs::Ms,"MS",3,A_MS0,LN_TOY);
        x.word(Dom::D,A_Z16,"Z"); x.group(Dom::D,Limbs::Z,"ZL",2,A_ZL0,2);
        x.group(Dom::D,Limbs::Rd,"RDL",if h24 {3} else {2},A_RDL,1);
        x.word(Dom::D,A_X2,"X2"); x.group(Dom::D,Limbs::X2,"X2L",2,A_X2L0,2);
        x.word(Dom::Q,A_Q8,"Q"); x.group(Dom::Q,Limbs::Q,"QL",2,usize::MAX,0);
        x.group(Dom::Q,Limbs::Rq,"RQL",2,A_RQL,1);
        x.word(Dom::Q,A_QR8,"QR"); x.group(Dom::Q,Limbs::Qr,"QRL",2,usize::MAX,0);
        x.group(Dom::Q,Limbs::Rqr,"RQRL",1,A_RQRL,1);
        x.word(Dom::Q,A_O8,"O"); x.group(Dom::Q,Limbs::O,"OL",2,usize::MAX,0);
        x.group(Dom::Q,Limbs::Ro,"RO",2,A_RO0,2);
        x.word(Dom::Kv,A_K8,"K"); x.group(Dom::Kv,Limbs::K,"KL",2,usize::MAX,0);
        x.group(Dom::Kv,Limbs::Rk,"RKL",2,A_RKL,1);
        x.word(Dom::Kv,A_V8,"V"); x.group(Dom::Kv,Limbs::V,"VL",2,usize::MAX,0);
        x.group(Dom::Kv,Limbs::Rv,"RVL",2,A_RVL,1);
        x.word(Dom::Kv,A_KR8,"KR"); x.group(Dom::Kv,Limbs::Kr,"KRL",2,usize::MAX,0);
        x.group(Dom::Kv,Limbs::Rkr,"RKRL",1,A_RKRL,1);
        x.word(Dom::S,A_S8,"S"); x.group(Dom::S,Limbs::Rs,"RSL",3,A_RSL,1);
        x.word(Dom::S,A_ZSEL,"ZSEL"); x.word(Dom::S,A_E,"E"); x.word(Dom::S,A_P,"P");
        if !dd { x.division(Dom::S,ls); }
        x.word(Dom::F,A_G8,"G"); x.group(Dom::F,Limbs::Rg,"RGL",3,A_RGL,1);
        x.word(Dom::F,A_A16,"A_SCALED"); x.word(Dom::F,A_U16,"U"); x.group(Dom::F,Limbs::Up,"UL",2,A_UL0,2);
        x.group(Dom::F,Limbs::Ru,"RU",2,usize::MAX,0);
        x.word(Dom::F,A_H16,"H"); x.group(Dom::F,Limbs::H,"HL",if h24 {3} else {2},A_HL0,2);
        x.group(Dom::F,Limbs::Rh,"RH",if h24 {2} else {3},A_RH0,2);
        if dd {
            x.pdict=x.word(Dom::Dd,usize::MAX,"PDICT"); x.division(Dom::Dd,ls);
            x.mdd=x.word(Dom::Dd,usize::MAX,"MDD");
        }
        x.word(Dom::Tab,A_MU8,"MU8"); x.word(Dom::Tab,A_MEXP,"MEXP"); x.word(Dom::Tab,A_MACT,"MACT");
        let absent=[A_NR0+3,A_NS0+3,A_MR0+3,A_MS0+3];
        if x.map.iter().enumerate().any(|(id,&p)| (p==usize::MAX)!=absent.contains(&id)) {
            return Err("R13 planes: a legacy role was lost or an absent norm limb was aliased".into());
        }
        if x.groups.iter().any(|&(first,len)| first==usize::MAX || len==0) {
            return Err("R13 planes: a limb role has no allocation".into());
        }
        Ok(x)
    }
    fn division(&mut self, dom: Dom, ls: usize) {
        self.group(dom,Limbs::P,"PL",2,A_PL0,LP_TOY);
        self.group(dom,Limbs::Sr,"SR",ls,A_SR0,LS_TOY);
        self.group(dom,Limbs::Sg,"SG",ls,A_SG0,LS_TOY);
    }
    pub(crate) fn limb(&self, group: Limbs, k: usize) -> usize {
        let (first,len)=self.groups[group as usize];
        assert!(k<len,"R13 limb role out of bounds: {group:?}[{k}] of {len}");
        first+k
    }
    pub(crate) fn count(&self, group: Limbs) -> usize {self.groups[group as usize].1}

    /// Emit byte and exact top-bit pins from the allocated roles. All word
    /// decompositions are checked by the host relations; these lookups pin
    /// only the declared limb ranges. ACT separately pins the int12 gate.
    pub(crate) fn lookups(&self, dom: Dom, p: &Precision, gate_shift: u32, wrho_s: u32) -> Result<Vec<Lk>,String> {
        let ls=self.count(Limbs::Sr);
        if p.stack==Stack::Legacy || p.f_p!=12 || p.product_bits!=if self.count(Limbs::H)==3 {24} else {16}
            || !(9..=24).contains(&wrho_s) || wrho_s.div_ceil(8) as usize!=ls {
            return Err("R13 lookups: precision or softmax context mismatch".into());
        }
        let mut v=Vec::new();
        let mut bytes=|g:Limbs,bits:Option<u32>| -> Result<(),String> {
            let count=self.count(g);
            for k in 0..count {v.push(Lk{terms:vec![(self.limb(g,k),1)],cst:0});}
            if let Some(bits)=bits {
                if bits==0 || bits>8*count as u32 || bits<=8*(count as u32-1) {
                    return Err(format!("R13 lookups: {g:?} shift does not fit its counted limb window"));
                }
                v.push(Lk{terms:vec![(self.limb(g,count-1),1i64<<(8*count as u32-bits))],cst:0});
            }
            Ok(())
        };
        match dom {
            Dom::L => {
                v.push(Lk{terms:vec![(self.map[A_LIMB],1)],cst:0});
                v.push(Lk{terms:vec![(self.map[A_LIMBM],1)],cst:0});
            }
            Dom::D => {
                bytes(Limbs::X,None)?; bytes(Limbs::Y,None)?;
                bytes(Limbs::Nr,None)?; bytes(Limbs::Ns,None)?;
                bytes(Limbs::Ao,None)?; bytes(Limbs::Rao,Some(p.ao))?; bytes(Limbs::X1,None)?;
                bytes(Limbs::Ym,None)?; bytes(Limbs::Mr,None)?; bytes(Limbs::Ms,None)?;
                bytes(Limbs::Z,None)?; bytes(Limbs::Rd,Some(p.down))?; bytes(Limbs::X2,None)?;
            }
            Dom::Q => {
                bytes(Limbs::Q,None)?; bytes(Limbs::Rq,Some(p.q))?;
                bytes(Limbs::Qr,None)?; bytes(Limbs::Rqr,Some(SH_ROPE))?;
                bytes(Limbs::O,None)?; bytes(Limbs::Ro,Some(p.pv))?;
            }
            Dom::Kv => {
                bytes(Limbs::K,None)?; bytes(Limbs::Rk,Some(p.k))?;
                bytes(Limbs::V,None)?; bytes(Limbs::Rv,Some(p.v))?;
                bytes(Limbs::Kr,None)?; bytes(Limbs::Rkr,Some(SH_ROPE))?;
            }
            Dom::F => {
                bytes(Limbs::Rg,Some(gate_shift))?; bytes(Limbs::Up,None)?;
                bytes(Limbs::Ru,Some(p.up))?; bytes(Limbs::H,None)?; bytes(Limbs::Rh,None)?;
            }
            Dom::S|Dom::Dd => {
                if dom==Dom::S {bytes(Limbs::Rs,Some(p.score))?;}
                let division_dom=if self.pdict==usize::MAX {Dom::S} else {Dom::Dd};
                if dom==division_dom {
                    bytes(Limbs::P,Some(p.f_p+1))?; bytes(Limbs::Sr,Some(wrho_s))?; bytes(Limbs::Sg,Some(wrho_s))?;
                }
                if dom==Dom::S {
                    v.insert(0,Lk{terms:vec![(self.map[A_S8],-1)],cst:127});
                    v.insert(0,Lk{terms:vec![(self.map[A_S8],1)],cst:127});
                }
            }
            Dom::T|Dom::Ht|Dom::Tab => {}
        }
        if v.iter().flat_map(|l| &l.terms).any(|&(id,_)| id>=self.doms.len() || self.doms[id]!=dom) {
            return Err("R13 lookups: a lookup references an absent or cross-domain plane".into());
        }
        Ok(v)
    }
}
