#![allow(dead_code)]
mod extracted {
 pub mod accuracy_precision {#[derive(Clone,Copy,PartialEq,Eq)] pub enum Stack {Legacy,Low,LowH24}}
 pub mod shape {
 use super::accuracy_precision::Stack;
 #[derive(Clone,Copy,Debug,PartialEq,Eq)] pub enum Dom {T,Ht,L,D,Q,Kv,S,F,Tab,Dd}
 const LIMBS_ISQRT:usize=3;
pub(crate) const SC_SS: usize = 0;
pub(crate) const SC_SSM: usize = 1;
pub(crate) const SC_TZC: usize = 2;
pub(crate) const SC_LZC: usize = 3;
pub(crate) const SC_RS: usize = 4;
pub(crate) const SC_QMM: usize = 5;
pub(crate) const SC_KMM: usize = 6;
pub(crate) const SC_VMM: usize = 7;
pub(crate) const SC_SCORE: usize = 8;
pub(crate) const SC_PV: usize = 9;
pub(crate) const SC_WO: usize = 10;
pub(crate) const SC_GMM: usize = 11;
pub(crate) const SC_UMM: usize = 12;
pub(crate) const SC_DMM: usize = 13;
pub(crate) const SC_DZC: usize = 14;
pub(crate) const SC_QZC: usize = 15;
pub(crate) const SC_KVZC: usize = 16;
pub(crate) const SC_SZC: usize = 17;
pub(crate) const SC_FZC: usize = 18;
pub(crate) const SC_TAB: usize = 19;
pub(crate) const SC_ZS: usize = 20;
pub(crate) const SC_IO_IN: usize = 21;
pub(crate) const SC_IO_OUT: usize = 22;
pub(crate) const SC_DD: usize = 23;
pub(crate) const MAX_SLOTS: usize = 24;
pub struct Shape {pub h24:bool,pub dd_cap:usize,pub ls:usize}
impl Shape {
 fn accuracy_stack(&self)->Stack {if self.h24 {Stack::LowH24} else {Stack::Low}}
 fn limbs_norm(&self)->usize {3}
 fn limbs_p(&self)->usize {2}
 fn limbs_sigma_s(&self)->usize {self.ls}
 fn norm_top_is_full_byte(&self)->bool {true}
    pub(crate) fn a_plane_doms(&self) -> Vec<Dom> {
        if self.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {
            let h24=self.accuracy_stack()==super::accuracy_precision::Stack::LowH24;
            let mut v=vec![Dom::T;4];v.extend([Dom::Ht;2]);v.extend([Dom::L;2]);
            v.extend(vec![Dom::D;if h24 {39} else {38}]);v.extend([Dom::Q;14]);v.extend([Dom::Kv;14]);
            v.extend(vec![Dom::S;if self.dd_cap>0 {7} else {9+2*self.limbs_sigma_s()}]);v.extend([Dom::F;16]);
            if self.dd_cap>0 {v.extend(vec![Dom::Dd;4+2*self.limbs_sigma_s()]);}
            v.extend([Dom::Tab;3]);return v;
        }

        let ln = self.limbs_norm();
        let mut v = vec![Dom::T; 4];
        v.extend([Dom::Ht; 2]);
        v.extend([Dom::L; 2]);
        // Dom::D: x, its two limbs, y; norm_a's rho and sigma limbs; the
        // attention output and residual 1 with their limbs; norm_m's rho and
        // sigma limbs; z16, residual 2 and the down-projection remainder
        v.extend(vec![Dom::D; 4 + 2 * ln + 8 + 2 * ln + 7]);
        v.extend([Dom::Q; 7]);
        v.extend([Dom::Kv; 6]);
        if self.dd_cap > 0 {
            // NATIVE R9 (D30): a score entry keeps S8, RSL, ZSEL, E and P and
            // drops its own quotient / remainder limbs; the dictionary carries
            // them, per slot, with the quotient itself and the multiplicity —
            // committed in `A`, before every LogUp challenge (B-2), and BELOW
            // the three histograms (CHECK.md E-1)
            v.extend([Dom::S; 5]);
            v.extend([Dom::F; 11]);
            v.extend(vec![Dom::Dd; 2 + self.limbs_p() + 2 * self.limbs_sigma_s()]);
        } else {
            v.extend(vec![Dom::S; 5 + self.limbs_p() + 2 * self.limbs_sigma_s()]);
            v.extend([Dom::F; 11]);
        }
        v.extend([Dom::Tab; 3]);
        v
    }
    pub(crate) fn lookups_per_position(&self, dom: Dom) -> usize {
        if self.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {
            return match dom {Dom::L=>2,Dom::D=>if self.accuracy_stack()==super::accuracy_precision::Stack::LowH24 {34} else {33},
                Dom::Q|Dom::Kv|Dom::F=>14,Dom::S=>if self.dd_cap>0 {6} else {11+2*self.limbs_sigma_s()},
                Dom::Dd if self.dd_cap>0=>5+2*self.limbs_sigma_s(),_=>0};
        }

        let ln = self.limbs_norm();
        let top = usize::from(!self.norm_top_is_full_byte());
        // sym(y) + rho limbs (+ the scaled top) + sigma limbs (+ the scaled top)
        let per_norm = 2 + 2 * (ln + top);
        match dom {
            Dom::L => 2,
            // the two `x` limbs; norm_a; ao/a-limbs/ral/scaled(ral)/x1 limbs;
            // norm_m; the two `x2` limbs; the down-projection's four
            Dom::D => 2 + per_norm + 6 + per_norm + 2 + 4,
            Dom::F => 9,
            Dom::Q => 13,
            Dom::Kv => 12,
            // sym(s8); rsl + scaled; p limbs + scaled top; rho_s and sigma_s
            // limbs, each with a scaled top. NATIVE R9: on a DD profile the
            // last three groups move to the dictionary (D30)
            Dom::S if self.dd_cap > 0 => 2 + 2,
            Dom::S => 2 + 2 + (self.limbs_p() + 1) + 2 * (self.limbs_sigma_s() + 1),
            // NATIVE R9 (D30, B-1): at EVERY dictionary slot, the quotient's
            // limbs + scaled top and rho_s / sigma_s limbs, each with a scaled
            // top — today's division limbs, verbatim
            Dom::Dd if self.dd_cap > 0 => (self.limbs_p() + 1) + 2 * (self.limbs_sigma_s() + 1),
            Dom::T | Dom::Ht | Dom::Tab | Dom::Dd => 0,
        }
    }
    pub(crate) fn helpers(&self, dom: Dom) -> usize {
        self.lookups_per_position(dom).div_ceil(2)
    }
    pub(crate) fn h_plane_doms(&self) -> Vec<Dom> {
        let mut v = vec![Dom::L; self.helpers(Dom::L)];
        v.extend(vec![Dom::D; self.helpers(Dom::D)]);
        v.extend(vec![Dom::Q; self.helpers(Dom::Q)]);
        v.extend(vec![Dom::Kv; self.helpers(Dom::Kv)]);
        // the `Dom::S` helpers plus the exponential pair's own helper
        // (NATIVE R9: plus, on a DD profile, the score entry's single tuple
        // helper into its row's dictionary)
        v.extend(vec![Dom::S; self.helpers(Dom::S) + 1 + usize::from(self.dd_cap > 0)]);
        // the `Dom::F` helpers plus the activation pair's own helper
        v.extend(vec![Dom::F; self.helpers(Dom::F) + 1]);
        // NATIVE R9 (D30): the dictionary's byte-lookup helpers and its TABLE
        // helper (which enters the value-0 sum claim with sign -1)
        if self.dd_cap > 0 {
            v.extend(vec![Dom::Dd; self.helpers(Dom::Dd) + 1]);
        }
        // the three table helpers and the zero-sum pair `u` (P-3 / P-6: `u`
        // stays the last plane, on `Dom::Tab`)
        v.extend([Dom::Tab; 4]);
        v
    }
    fn a_planes_on(&self, dom: Dom) -> usize {
        self.a_plane_doms().iter().filter(|d| **d == dom).count()
    }
    pub(crate) fn claim_sites(&self) -> ([usize; MAX_SLOTS], [usize; MAX_SLOTS]) {
        let mut a = [0usize; MAX_SLOTS];
        let mut h = [0usize; MAX_SLOTS];
        a[SC_SS] = 1;
        a[SC_SSM] = 1;
        // the four `Dom::T` planes, plus nine limb sub-slices per norm
        a[SC_TZC] = 4 + 2 * (3 * LIMBS_ISQRT);
        a[SC_LZC] = self.a_planes_on(Dom::L);
        h[SC_LZC] = self.helpers(Dom::L);
        a[SC_RS] = 2;
        for s in [SC_QMM, SC_KMM, SC_VMM, SC_WO, SC_GMM, SC_UMM, SC_DMM] {
            a[s] = 1;
        }
        a[SC_SCORE] = 2;
        a[SC_PV] = 2;
        // + the two `Dom::T` denominators
        a[SC_DZC] = self.a_planes_on(Dom::D) + 2;
        h[SC_DZC] = self.helpers(Dom::D);
        // + the flipped RoPE partner
        a[SC_QZC] = self.a_planes_on(Dom::Q) + 1;
        h[SC_QZC] = self.helpers(Dom::Q);
        a[SC_KVZC] = self.a_planes_on(Dom::Kv) + 1;
        h[SC_KVZC] = self.helpers(Dom::Kv);
        // + A_MX and A_SUM; + H_SEXP (NATIVE R9: + the tuple helper on a DD
        // profile, whose `Dom::S` block is five planes)
        a[SC_SZC] = self.a_planes_on(Dom::S) + 2;
        h[SC_SZC] = self.helpers(Dom::S) + 1 + usize::from(self.dd_cap > 0);
        // + H_FACT
        a[SC_FZC] = self.a_planes_on(Dom::F);
        h[SC_FZC] = self.helpers(Dom::F) + 1;
        a[SC_TAB] = 3;
        h[SC_TAB] = 3;
        h[SC_ZS] = 1;
        a[SC_IO_IN] = 1;
        a[SC_IO_OUT] = 1;
        // NATIVE R9 (D30): the dictionary zero-check — every `Dom::Dd` plane
        // on its own cube, plus `A_SUM` read on the leading (h, t) variables
        // (B-4: a claim site of this slot); its byte helpers plus the table
        // helper. Each plane is opened only at its own reserved site.
        if self.dd_cap > 0 {
            a[SC_DD] = self.a_planes_on(Dom::Dd) + 1;
            h[SC_DD] = self.helpers(Dom::Dd) + 1;
        }
        (a, h)
    }
}}}
fn main() {
 use extracted::shape::{Shape,Dom};
 let doms=[Dom::T,Dom::Ht,Dom::L,Dom::D,Dom::Q,Dom::Kv,Dom::S,Dom::F,Dom::Tab,Dom::Dd];
 for h24 in [false,true] {for dd in [0,32] {for ls in [2,3] {
 let sh=Shape{h24,dd_cap:dd,ls};let(a,h)=sh.claim_sites();let ap=sh.a_plane_doms();let hp=sh.h_plane_doms();
 let ac:Vec<_>=doms.iter().map(|d|ap.iter().filter(|x|*x==d).count()).collect();
 let hc:Vec<_>=doms.iter().map(|d|hp.iter().filter(|x|*x==d).count()).collect();
 let look:Vec<_>=doms.iter().map(|d|sh.lookups_per_position(*d)).collect();
 println!("{}|{}|{}|{:?}|{:?}|{:?}|{:?}|{:?}",u8::from(h24),dd,ls,a,h,ac,hc,look);
 }}}
}
