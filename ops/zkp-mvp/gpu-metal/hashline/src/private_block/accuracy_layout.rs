//! R13 plane roles and byte lookups. Profile activation is a separate gate.
//! W16 (D54): the same roles at 16-bit limbs (`new_w16`, `lookups_w16`).
use super::accuracy_precision::{Precision, Stack};
use super::layout::*;
use super::range16::Fam;

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
    /// W16: the 16-bit limb layout (`new_w16`); false on every R13 allocation
    pub(crate) w16: bool,
    /// W16: the range families, in tag order, and the first of their `Dom::Tab`
    /// sub-planes (`usize::MAX` and empty on R13)
    pub(crate) fams: Vec<Fam>,
    pub(crate) first_range: usize,
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
    fn empty() -> Self {
        Self { map: vec![usize::MAX; N_A], doms: Vec::new(), groups: [(usize::MAX,0); GROUPS],
            names: Vec::new(), pdict: usize::MAX, mdd: usize::MAX, w16: false, fams: Vec::new(), first_range: usize::MAX }
    }
    pub(crate) fn new(stack: Stack, dd: bool, ls: usize) -> Result<Self, String> {
        if stack == Stack::Legacy || !(2..=3).contains(&ls) {
            return Err("R13 planes require an explicit LOW stack and two/three softmax remainder limbs".into());
        }
        let h24 = stack == Stack::LowH24;
        let mut x = Self::empty();
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

    /// **W16 (D54): the R13 roles at 16-bit limbs.** The 16-bit words have no
    /// limb plane (each is looked up directly as `word + 32768`); a remainder
    /// of `b` bits has `range16::limbs_of(b)` planes; the 24-bit product word
    /// keeps one committed top limb. No legacy LIMB id is mapped, so legacy
    /// code that reads a byte limb by its toy id cannot silently read a 16-bit
    /// one. The range families are collected from this allocation's own
    /// lookups and must equal the shape's independently counted set.
    pub(crate) fn new_w16(stack: Stack, dd: bool, p: &Precision, gate_shift: u32, wrho_s: u32, log_cols: usize) -> Result<Self, String> {
        use super::range16::{families, limbs_of, sub_planes, widths};
        if stack == Stack::Legacy || p.stack != stack || !(9..=24).contains(&wrho_s) || !(17..=24).contains(&gate_shift) {
            return Err("W16 planes require an explicit LOW stack, its precision, a softmax window in 9..=24 and a gate shift in 17..=24".into());
        }
        let h24 = stack == Stack::LowH24;
        let none = usize::MAX;
        let mut x = Self::empty();
        x.w16 = true;
        for (id,name) in [(A_D,"D"),(A_DSQ,"DSQ"),(A_DM,"DM"),(A_DSQM,"DSQM")] {x.word(Dom::T,id,name);}
        x.word(Dom::Ht,A_MX,"MX"); x.word(Dom::Ht,A_SUM,"SUM");
        x.word(Dom::L,A_LIMB,"LIMB"); x.word(Dom::L,A_LIMBM,"LIMBM");
        x.word(Dom::D,A_X,"X"); x.group(Dom::D,Limbs::X,"XL",0,none,0);
        x.word(Dom::D,A_Y,"Y"); x.group(Dom::D,Limbs::Y,"YL",0,none,0);
        x.group(Dom::D,Limbs::Nr,"NR",2,none,0); x.group(Dom::D,Limbs::Ns,"NS",2,none,0);
        x.word(Dom::D,A_AO,"AO"); x.group(Dom::D,Limbs::Ao,"AL",0,none,0);
        x.group(Dom::D,Limbs::Rao,"RAL",limbs_of(p.ao),none,0);
        x.word(Dom::D,A_X1,"X1"); x.group(Dom::D,Limbs::X1,"X1L",0,none,0);
        x.word(Dom::D,A_YM,"YM"); x.group(Dom::D,Limbs::Ym,"YML",0,none,0);
        x.group(Dom::D,Limbs::Mr,"MR",2,none,0); x.group(Dom::D,Limbs::Ms,"MS",2,none,0);
        x.word(Dom::D,A_Z16,"Z"); x.group(Dom::D,Limbs::Z,"ZL",0,none,0);
        x.group(Dom::D,Limbs::Rd,"RDL",limbs_of(p.down),none,0);
        x.word(Dom::D,A_X2,"X2"); x.group(Dom::D,Limbs::X2,"X2L",0,none,0);
        x.word(Dom::Q,A_Q8,"Q"); x.group(Dom::Q,Limbs::Q,"QL",0,none,0);
        x.group(Dom::Q,Limbs::Rq,"RQL",limbs_of(p.q),none,0);
        x.word(Dom::Q,A_QR8,"QR"); x.group(Dom::Q,Limbs::Qr,"QRL",0,none,0);
        x.group(Dom::Q,Limbs::Rqr,"RQRL",limbs_of(SH_ROPE),none,0);
        x.word(Dom::Q,A_O8,"O"); x.group(Dom::Q,Limbs::O,"OL",0,none,0);
        x.group(Dom::Q,Limbs::Ro,"RO",limbs_of(p.pv),none,0);
        x.word(Dom::Kv,A_K8,"K"); x.group(Dom::Kv,Limbs::K,"KL",0,none,0);
        x.group(Dom::Kv,Limbs::Rk,"RKL",limbs_of(p.k),none,0);
        x.word(Dom::Kv,A_V8,"V"); x.group(Dom::Kv,Limbs::V,"VL",0,none,0);
        x.group(Dom::Kv,Limbs::Rv,"RVL",limbs_of(p.v),none,0);
        x.word(Dom::Kv,A_KR8,"KR"); x.group(Dom::Kv,Limbs::Kr,"KRL",0,none,0);
        x.group(Dom::Kv,Limbs::Rkr,"RKRL",limbs_of(SH_ROPE),none,0);
        x.word(Dom::S,A_S8,"S"); x.group(Dom::S,Limbs::Rs,"RSL",limbs_of(p.score),none,0);
        x.word(Dom::S,A_ZSEL,"ZSEL"); x.word(Dom::S,A_E,"E"); x.word(Dom::S,A_P,"P");
        if !dd { x.division_w16(Dom::S,limbs_of(wrho_s)); }
        x.word(Dom::F,A_G8,"G"); x.group(Dom::F,Limbs::Rg,"RGL",limbs_of(gate_shift),none,0);
        x.word(Dom::F,A_A16,"A_SCALED"); x.word(Dom::F,A_U16,"U"); x.group(Dom::F,Limbs::Up,"UL",0,none,0);
        x.group(Dom::F,Limbs::Ru,"RU",limbs_of(p.up),none,0);
        x.word(Dom::F,A_H16,"H"); x.group(Dom::F,Limbs::H,"HT",usize::from(h24),none,0);
        x.group(Dom::F,Limbs::Rh,"RH",limbs_of(if h24 {16} else {24}),none,0);
        if dd {
            x.pdict=x.word(Dom::Dd,none,"PDICT"); x.division_w16(Dom::Dd,limbs_of(wrho_s));
            x.mdd=x.word(Dom::Dd,none,"MDD");
        }
        x.word(Dom::Tab,A_MU8,"MU8"); x.word(Dom::Tab,A_MEXP,"MEXP"); x.word(Dom::Tab,A_MACT,"MACT");
        if x.groups.iter().any(|&(first,_)| first==usize::MAX) {
            return Err("W16 planes: a limb role has no allocation".into());
        }
        // exactly the legacy WORD ids are mapped; no legacy limb id is
        let words=[A_D,A_DSQ,A_DM,A_DSQM,A_MX,A_SUM,A_LIMB,A_LIMBM,A_X,A_Y,A_AO,A_X1,A_YM,A_Z16,A_X2,
            A_Q8,A_QR8,A_O8,A_K8,A_V8,A_KR8,A_S8,A_ZSEL,A_E,A_P,A_G8,A_A16,A_U16,A_H16,A_MU8,A_MEXP,A_MACT];
        if x.map.iter().enumerate().any(|(id,&p)| (p!=usize::MAX)!=words.contains(&id)) {
            return Err("W16 planes: a legacy limb id was mapped or a word id was lost".into());
        }
        let mut seen=Vec::new();
        for dom in [Dom::L,Dom::D,Dom::Q,Dom::Kv,Dom::S,Dom::F,Dom::Dd] {
            if dom==Dom::Dd && !dd {continue;}
            for l in x.lookups_w16(dom,p,gate_shift,wrho_s)? {
                if let LkTag::Range(w)=l.tag {seen.push(w);}
            }
        }
        seen.sort_unstable(); seen.dedup();
        if seen!=widths(stack,p,gate_shift,wrho_s) {
            return Err("W16 planes: the lookups' range widths differ from the independently counted set".into());
        }
        x.fams=families(&seen,log_cols);
        x.first_range=x.doms.len();
        for (f,s) in sub_planes(&x.fams) {x.word(Dom::Tab,none,&format!("R{}_{s}",f.width));}
        Ok(x)
    }
    fn division(&mut self, dom: Dom, ls: usize) {
        self.group(dom,Limbs::P,"PL",2,A_PL0,LP_TOY);
        self.group(dom,Limbs::Sr,"SR",ls,A_SR0,LS_TOY);
        self.group(dom,Limbs::Sg,"SG",ls,A_SG0,LS_TOY);
    }
    fn division_w16(&mut self, dom: Dom, n: usize) {
        self.group(dom,Limbs::P,"PL",0,usize::MAX,0);
        self.group(dom,Limbs::Sr,"SR",n,usize::MAX,0);
        self.group(dom,Limbs::Sg,"SG",n,usize::MAX,0);
    }
    pub(crate) fn limb(&self, group: Limbs, k: usize) -> usize {
        let (first,len)=self.groups[group as usize];
        assert!(k<len,"R13 limb role out of bounds: {group:?}[{k}] of {len}");
        first+k
    }
    pub(crate) fn count(&self, group: Limbs) -> usize {self.groups[group as usize].1}
    /// every plane of a limb role, low limb first
    pub(crate) fn planes(&self, group: Limbs) -> Vec<usize> {(0..self.count(group)).map(|k| self.limb(group,k)).collect()}
    /// W16: every range sub-plane, in plane order: `(family, sub-plane, A plane id)`
    pub(crate) fn range_planes(&self) -> Vec<(Fam, usize, usize)> {
        super::range16::sub_planes(&self.fams).into_iter().enumerate().map(|(j,(f,s))| (f,s,self.first_range+j)).collect()
    }
    /// W16: the family of a range sub-plane (`None` for every other plane)
    pub(crate) fn range_fam_of(&self, plane: usize) -> Option<Fam> {
        if !self.w16 || plane<self.first_range {return None;}
        super::range16::sub_planes(&self.fams).get(plane-self.first_range).map(|(f,_)| *f)
    }

    /// Emit byte and exact top-bit pins from the allocated roles. All word
    /// decompositions are checked by the host relations; these lookups pin
    /// only the declared limb ranges. ACT separately pins the int12 gate.
    /// (W16: dispatches to [`AccuracyIds::lookups_w16`].)
    pub(crate) fn lookups(&self, dom: Dom, p: &Precision, gate_shift: u32, wrho_s: u32) -> Result<Vec<Lk>,String> {
        if self.w16 {return self.lookups_w16(dom,p,gate_shift,wrho_s);}
        let ls=self.count(Limbs::Sr);
        if p.stack==Stack::Legacy || p.f_p!=12 || p.product_bits!=if self.count(Limbs::H)==3 {24} else {16}
            || !(9..=24).contains(&wrho_s) || wrho_s.div_ceil(8) as usize!=ls {
            return Err("R13 lookups: precision or softmax context mismatch".into());
        }
        let mut v=Vec::new();
        let mut bytes=|g:Limbs,bits:Option<u32>| -> Result<(),String> {
            let count=self.count(g);
            for k in 0..count {v.push(Lk::u8(vec![(self.limb(g,k),1)],0));}
            if let Some(bits)=bits {
                if bits==0 || bits>8*count as u32 || bits<=8*(count as u32-1) {
                    return Err(format!("R13 lookups: {g:?} shift does not fit its counted limb window"));
                }
                v.push(Lk::u8(vec![(self.limb(g,count-1),1i64<<(8*count as u32-bits))],0));
            }
            Ok(())
        };
        match dom {
            Dom::L => {
                v.push(Lk::u8(vec![(self.map[A_LIMB],1)],0));
                v.push(Lk::u8(vec![(self.map[A_LIMBM],1)],0));
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
                    v.insert(0,Lk::u8(vec![(self.map[A_S8],-1)],127));
                    v.insert(0,Lk::u8(vec![(self.map[A_S8],1)],127));
                }
            }
            Dom::T|Dom::Ht|Dom::Tab => {}
        }
        if v.iter().flat_map(|l| &l.terms).any(|&(id,_)| id>=self.doms.len() || self.doms[id]!=dom) {
            return Err("R13 lookups: a lookup references an absent or cross-domain plane".into());
        }
        Ok(v)
    }

    /// **W16 (D54): the lookups of one domain at 16-bit limbs**, in plane
    /// order (helper `k` covers lookups `2k, 2k + 1`). Each 16-bit word is one
    /// width-16 query on `word + 32768`; each remainder is one query per limb
    /// at its own width (`range16::rem_lookups`); the 24-bit product word is a
    /// low expression and a top byte (`range16::word24`); the softmax quotient
    /// is one width-13 query on the word; the int8 score keeps its two
    /// symmetric byte queries; the isqrt limbs stay bytes.
    pub(crate) fn lookups_w16(&self, dom: Dom, p: &Precision, gate_shift: u32, wrho_s: u32) -> Result<Vec<Lk>,String> {
        use super::range16::{direct, rem_lookups, word16, word24};
        if !self.w16 || p.f_p!=12 || p.product_bits!=if p.stack==Stack::LowH24 {24} else {16} {
            return Err("W16 lookups: a W16 allocation and its precision are required".into());
        }
        let h24=p.stack==Stack::LowH24;
        let mut v=Vec::new();
        let rem=|v:&mut Vec<Lk>,g:Limbs,bits:u32| v.extend(rem_lookups(&self.planes(g),bits));
        let w=|v:&mut Vec<Lk>,old:usize| v.push(word16(self.map[old],32768));
        match dom {
            Dom::L => {
                v.push(Lk::u8(vec![(self.map[A_LIMB],1)],0));
                v.push(Lk::u8(vec![(self.map[A_LIMBM],1)],0));
            }
            Dom::D => {
                w(&mut v,A_X); w(&mut v,A_Y);
                rem(&mut v,Limbs::Nr,24); rem(&mut v,Limbs::Ns,24);
                w(&mut v,A_AO); rem(&mut v,Limbs::Rao,p.ao); w(&mut v,A_X1);
                w(&mut v,A_YM); rem(&mut v,Limbs::Mr,24); rem(&mut v,Limbs::Ms,24);
                w(&mut v,A_Z16); rem(&mut v,Limbs::Rd,p.down); w(&mut v,A_X2);
            }
            Dom::Q => {
                w(&mut v,A_Q8); rem(&mut v,Limbs::Rq,p.q);
                w(&mut v,A_QR8); rem(&mut v,Limbs::Rqr,SH_ROPE);
                w(&mut v,A_O8); rem(&mut v,Limbs::Ro,p.pv);
            }
            Dom::Kv => {
                w(&mut v,A_K8); rem(&mut v,Limbs::Rk,p.k);
                w(&mut v,A_V8); rem(&mut v,Limbs::Rv,p.v);
                w(&mut v,A_KR8); rem(&mut v,Limbs::Rkr,SH_ROPE);
            }
            Dom::F => {
                rem(&mut v,Limbs::Rg,gate_shift); w(&mut v,A_U16); rem(&mut v,Limbs::Ru,p.up);
                if h24 {v.extend(word24(self.map[A_H16],self.limb(Limbs::H,0),1i64<<(p.product_bits-1)));}
                else {v.push(word16(self.map[A_H16],1i64<<(p.product_bits-1)));}
                rem(&mut v,Limbs::Rh,if h24 {16} else {24});
            }
            Dom::S|Dom::Dd => {
                if dom==Dom::S {
                    v.push(Lk::u8(vec![(self.map[A_S8],1)],127));
                    v.push(Lk::u8(vec![(self.map[A_S8],-1)],127));
                    rem(&mut v,Limbs::Rs,p.score);
                }
                let division_dom=if self.pdict==usize::MAX {Dom::S} else {Dom::Dd};
                if dom==division_dom {
                    let quotient=if dom==Dom::S {self.map[A_P]} else {self.pdict};
                    v.push(direct(quotient,p.f_p+1)); rem(&mut v,Limbs::Sr,wrho_s); rem(&mut v,Limbs::Sg,wrho_s);
                }
            }
            Dom::T|Dom::Ht|Dom::Tab => {}
        }
        if v.iter().flat_map(|l| &l.terms).any(|&(id,_)| id>=self.doms.len() || self.doms[id]!=dom) {
            return Err("W16 lookups: a lookup references an absent or cross-domain plane".into());
        }
        Ok(v)
    }
}

#[cfg(test)]
#[path="accuracy_layout_tests.rs"]
mod tests;
